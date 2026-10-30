--[[
	FrostDragonKillFX -- the Cryo "Frost Dragon" (Mythic) kill effect, "Dragon's Pass" (client, cosmetic only).

	On a kill by a Frost Dragon caster, the Blizzard's ghost dragon (FrostDragonData "bzbody" + the hinged wings
	"bzw<side>_A/B/C", the Blizzard wing rig, the Blizzard's ghost look exactly), body 5x the victim's height,
	swoops across the killer's view on one smooth U, left to right, in the vertical plane through the victim square to
	the killer's line of sight: in from above the top-left of that view (any pitch), down a long curve to a strike on the
	victim's torso without a stop, and on out up a rising curve to the top-right, drifting away and dissolving. Banked
	toward the killer so the spread wings read broadside. The victim freezes at the strike into a glowing crystal statue
	in their own silhouette (scale plates over glassy ice round a bright core; their body hidden on this client only,
	LocalTransparencyModifier), holds, cracks white-hot and breaks into the cage's scale plates and CryoFX's jagged ice
	chunks, flung out and up and dragged after the dragon. About 1.9 s; nothing persists. Timeline (s):
	  0.00-0.55  cold light, a frost ring, the dragon's shadow racing in along the ground; the descent
	  0.55       the strike, flown straight through: a frost burst at the claws, a white-hot ring, the statue sealing (0.1 s)
	  0.55-1.18  the climb-out with one powerful downstroke, dissolving into cloud-white; the statue holds, then cracks
	  1.13-1.90  the break: plates and chunks out, up and along the dragon's exit, tumbling, falling; a faint frost ring
	Triggered by the killer's character attributes KillFX (server time) + KillFXVictim (the victim model's name), the
	way Pyro's kill visual rides PassiveProc. Settings: Reduce Flashing (no light rings, fewer glints, a dimmer light),
	Reduce Enemy VFX (no dragon, fewer shards; the dragon flies on the killer's and the victim's clients only, 2026-10-19), the killer's colour wrap (CryoWrap: pieces, bursts, light), Graphics Quality (FrostDragonKit.Tier: plates 64 / 44 / 23, chunks
	28 / 18 / 9). Everything pooled (the chunks by CryoFX's own debris pool).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local iceFolder = script.Parent

local KFX = {}
local FD, H, W                                        -- (W: CryoWrap, the killer's colour wrap)
local rng = Random.new()

local P = { Scale = 5.0, Span = 30, Bank = 55, Hit = 0.55, Hold = 0, Climb = 0.5, Seal = 0.1, Break = 1.13, Gone = 1.18,
	End = 1.9, Glide = math.rad(7.5), Elbow = 0.25, Wrist = 0.3, Back = math.rad(15), Elev = math.rad(5), Edge = 0.1, Fill = 0.85,
	Shards = { 48, 34, 18 }, Extra = { 16, 10, 5 }, Chunks = { 28, 18, 9 }, Cracks = { 8, 6, 3 }, Beams = 10 }
local CHUNKS = { "CK_Chunk_1", "CK_Chunk_2", "CK_Chunk_3", "CK_Chunk_4" }   -- (CryoFX's jagged ice chunks)
local ICE, CORE = Color3.fromHex("#A8DDF2"), Color3.fromHex("#57D9FF")   -- (icy blue round a cyan glow: not a white puff)

--- the Blizzard wing rig (FrostDragonFX): the folded wing laid open, arm out, membrane face up
local function spreadRot(S, W, sg)
	local d0 = (W - S).Unit
	local n0 = Vector3.new(-0.19, 0.49, 0.85 * sg)
	n0 = (n0 - d0 * n0:Dot(d0)).Unit
	local d1 = Vector3.new(-math.sin(P.Back) * math.cos(P.Elev), math.sin(P.Elev), -sg * math.cos(P.Back) * math.cos(P.Elev)).Unit
	local n1 = (Vector3.yAxis - d1 * d1.Y).Unit
	return CFrame.fromMatrix(Vector3.zero, d1, n1, d1:Cross(n1)) * CFrame.fromMatrix(Vector3.zero, d0, n0, d0:Cross(n0)):Inverse()
end
local function rig()
	if KFX.J then return KFX.J end
	local bp = FD.Kind("bzbody").Pivot
	local J = {}
	for _, sd in ipairs({ "R", "L" }) do
		local a, b, w = FD.Kind("bzw" .. sd .. "_A").Pivot, FD.Kind("bzw" .. sd .. "_B").Pivot, FD.Kind("bzw" .. sd .. "_C").Pivot
		local sg = (sd == "R") and 1 or -1
		J[sd] = { S = a - bp, E = b - bp, W = w - bp, Sign = sg, Rs = spreadRot(a, w, sg) }
	end
	KFX.J = J
	return J
end
local function wingPose(j, lA, lB, lC, sw)
	local sg = j.Sign
	local yaw = CFrame.Angles(0, sg * sw, 0)
	local mA = yaw * CFrame.Angles(sg * lA, 0, 0) * j.Rs
	local mB = yaw * CFrame.Angles(sg * lB, 0, 0) * j.Rs
	local mC = CFrame.Angles(0, sg * sw * 1.3, 0) * CFrame.Angles(sg * lC, 0, 0) * j.Rs
	local e = j.S + mA:VectorToWorldSpace(j.E - j.S)
	local w = e + mB:VectorToWorldSpace(j.W - j.E)
	return { j.S, mA, e, mB, w, mC }
end
--- the one downstroke: +1 up, -1 down; a glide, the stroke across the crossing, a recovery
local function stroke(t)
	if t < 0.2 then return 0.6 + 2 * t end
	if t < 0.5 then return math.cos(math.pi * (t - 0.2) / 0.3) end
	return math.min(0, -1 + (t - 0.5) / 0.15)
end

-- the pool: dragons, plates, plain parts and the crescent beams live here between kills
local pool = { Dragons = {}, Plates = {}, Parts = {}, Beams = nil }
local poolFolder
local function hold()
	if not (poolFolder and poolFolder.Parent) then
		poolFolder = Instance.new("Folder")
		poolFolder.Name = "FrostDragonKillPool"
		poolFolder.Parent = H.fxFolder()
		pool.Dragons, pool.Plates, pool.Parts, pool.Beams = {}, {}, {}, nil
	end
	return poolFolder
end
local function takeDragon()
	local d = table.remove(pool.Dragons)
	if d then return d end
	local model = Instance.new("Model")
	model.Name = "FrostDragonKillDragon"
	model.Parent = hold()
	d = { Body = FD.New("bzbody", model), W = { R = {}, L = {} }, Model = model }
	d.All = { d.Body }
	for _, sd in ipairs({ "R", "L" }) do
		for i, g in ipairs({ "A", "B", "C" }) do
			d.W[sd][i] = FD.New("bzw" .. sd .. "_" .. g, model)
			d.All[#d.All + 1] = d.W[sd][i]
		end
	end
	for _, o in ipairs(d.All) do
		FD.Fade(o, 1)
		for _, p in ipairs(o.Parts) do H.VFXLibrary.RegisterProximityFade(p.Part) end
	end
	return d
end
local function takePlate()
	local o = table.remove(pool.Plates) or FD.New("Plate", hold())
	if o then
		for _, p in ipairs(o.Parts) do                                  -- (the statue's scales: icy blue, cyan-rimmed)
			if p.Group == "PlateBody" then p.Base, p.Part.Color = 0.2, Color3.fromHex("#8FD3F0") end
			if p.Group == "PlateRim" then p.Part.Color = Color3.fromHex("#57D9FF") end
		end
		o.F = -1
		FD.Fade(o, 1)
	end
	return o
end
local function takePart()
	local p = table.remove(pool.Parts)
	if not p then
		p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Transparency = 1
		p.Parent = hold()
	end
	return p
end
local function beams()
	if pool.Beams then return pool.Beams end
	local host = H.host(CFrame.new(), hold())
	local list = {}
	for i = 1, P.Beams do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = host, host
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera, b.Segments = true, 12
		b.Color = ColorSequence.new(Color3.fromHex("#EEF9FF"))
		b.LightEmission, b.LightInfluence = 0.7, 0.15
		b.Transparency = NumberSequence.new(1)
		b.Enabled = false
		b.Parent = host
		list[i] = { B = b, A0 = a0, A1 = a1, T0 = -1 }
	end
	pool.Beams = list
	return list
end

--- the swoop: in the killer's view a smooth U across the screen, left to right -- s along the screen's right
--- (studs from the victim), the height a parabola in s (level at the strike), drifting away from the killer on the climb
local function swoop(t, S, Hin, Hout)
	if t < P.Hit then
		local u = t / P.Hit
		local s = -S * (1 - u)
		return s, Hin * (s / S) ^ 2, 0, S / P.Hit, 2 * Hin * s / S ^ 2
	end
	-- out at the speed it struck at: it carries straight through the victim, no stop
	local s = (t - P.Hit) * S / P.Hit
	local v = s / S
	return s, Hout * v ^ 2, 14 * v * v, S / P.Hit, 2 * Hout * s / S ^ 2, 28 * v / P.Hit
end

--- Dragon's Pass at `victim` for `killer` (stamp = the kill's server time), drawn in the killer's colour wrap if any.
local function why(msg) if RunService:IsStudio() then warn("[FrostDragonKillFX] skipped: " .. msg) end end
local function play(killer, victim, stamp, waited)
	if not (FD and FD.Built and FD.Kind("bzbody") and FD.Kind("Plate")) then return why("the dragon kit is not built") end
	if typeof(victim) ~= "Instance" then return why("no victim") end
	local age0 = stamp and math.max(0, H.serverNow() - stamp) or 0
	if waited then age0 = 0 end                                        -- (waited on the kit: play it from the start)
	if age0 > 0.8 then return why("late by " .. math.floor(age0 * 10) / 10 .. " s") end   -- (late: never a stale effect)
	local thin = H.thinFor(killer)
	local dens = H.density(killer)
	local calm = H.Settings.Get and H.Settings.Get("ReduceFlashing")
	local tier = FD.Tier(H.Settings.EffectDensity, thin)
	-- the body as this client has it now: its parts and frames (the statue holds this pose), its feet and height
	local body, hide = {}, {}
	local feet, top = math.huge, -math.huge
	for _, p in ipairs(victim:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
			hide[#hide + 1] = p
			if not p:FindFirstAncestorWhichIsA("Accessory") then
				body[#body + 1] = { P = p, CF = p.CFrame, Size = p.Size }
				feet = math.min(feet, p.Position.Y - p.Size.Y / 2)
				top = math.max(top, p.Position.Y + p.Size.Y / 2)
			end
		elseif p:IsA("Decal") then
			hide[#hide + 1] = p
		end
	end
	if #body == 0 then return why("the victim has no visible body") end
	local hV = math.clamp(top - feet, 3, 8)
	local root = victim:FindFirstChild("HumanoidRootPart")
	local at = Vector3.new(root and root.Position.X or body[1].CF.X, feet, root and root.Position.Z or body[1].CF.Z)
	local chest = at + Vector3.new(0, hV * 0.62, 0)
	local contact = at + Vector3.new(0, hV * 0.6, 0)                 -- (the claws strike the torso)
	-- the killer's camera: this client's own when it is the killer, else the killer's eye looking at the victim
	local kr = killer and killer:FindFirstChild("HumanoidRootPart")
	local eye, pitch, halfV, aspect = (kr and kr.Position or at - Vector3.zAxis * 34) + Vector3.new(0, 1.5, 0), 0, math.rad(35), 16 / 9
	local cam = workspace.CurrentCamera
	if killer == (Players.LocalPlayer and Players.LocalPlayer.Character) and cam then
		eye, pitch, halfV = cam.CFrame.Position, math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)), math.rad(cam.FieldOfView / 2)
		aspect = cam.ViewportSize.X / math.max(1, cam.ViewportSize.Y)
	else
		pitch = math.atan2(chest.Y - eye.Y, math.max(1, H.flat(chest - eye).Magnitude))
	end
	local view = H.flat(at - eye)
	local dist = math.max(view.Magnitude, 8)
	view = view.Magnitude > 1e-3 and view.Unit or Vector3.zAxis
	local right = view:Cross(Vector3.yAxis).Unit                      -- the killer's screen right, in the victim's plane
	local sc = P.Scale * hV / 29.5                                     -- (the body about 5x the victim's height long)
	local len = 29.5 * sc
	-- the swoop's size: it starts and ends above the top of the killer's view (any pitch), the dragon whole outside it
	local topY = eye.Y + dist * math.tan(math.min(pitch + halfV, math.rad(80)))
	local hitAt = contact + Vector3.new(0, 0.3, 0)                     -- (its pivot = the feet: the claws at the torso)
	local Hin = math.max(24, topY - hitAt.Y + len * 0.55)
	local S = math.max(P.Span, dist * math.tan(math.atan(math.tan(halfV) * aspect)) * 0.55)
	local Hout = Hin * 1.1
	local folder = Instance.new("Folder")
	folder.Name = "FrostDragonKill"
	folder.Parent = H.fxFolder()

	-- the statue: each body part in glassy crystal round a bright core, in the pose it had
	local statue = {}
	for _, b in ipairs(body) do
		local sh, core = takePart(), takePart()
		for _, q in ipairs({ sh, core }) do
			local m = q:FindFirstChild("Ell") if m then m:Destroy() end
			for _, a in ipairs({ "WrapBase", "WrapBaseMat", "WrapBaseRefl" }) do q:SetAttribute(a, nil) end   -- (a pooled part: fresh)
		end
		sh.Material, sh.Color, sh.Size, sh.CFrame = Enum.Material.Glass, ICE, b.Size * 1.08, b.CF
		core.Material, core.Color, core.Size, core.CFrame = Enum.Material.Neon, CORE, b.Size * 0.82, b.CF
		if W then W.PaintKit({ P = { sh, core } }) end                     -- (in the wrap: its colours, or the Default back)
		statue[#statue + 1] = { Sh = sh, Core = core, B = b, D = (b.CF.Position - contact).Magnitude / hV, On = false }
	end
	-- its scales (the cage's plate): over the body by area, pointing down; the extras burst out of its inside
	local spots, list, area = {}, {}, 0
	for _, b in ipairs(body) do
		area += 2 * (b.Size.X + b.Size.Z) * b.Size.Y
		list[#list + 1] = { B = b, A = area }
	end
	local AX = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	local ss = math.clamp(hV / 5, 0.7, 1.3) * 2.8
	local exitDir = (right * 1 + Vector3.new(0, 0.7, 0)).Unit           -- the slipstream: the dragon's way out
	for i = 1, P.Shards[tier] + P.Extra[tier] do
		local r, e = rng:NextNumber(0, area), list[#list]
		for _, q in ipairs(list) do if r <= q.A then e = q break end end
		local b = e.B
		local face = rng:NextInteger(1, 4)
		local nL = AX[face]
		local half, wide = (face <= 2) and b.Size.X / 2 or b.Size.Z / 2, (face <= 2) and b.Size.Z or b.Size.X
		local inner = i > P.Shards[tier]
		local loc = nL * (inner and 0 or half + 0.1) + Vector3.new(0, rng:NextNumber(-0.42, 0.42) * b.Size.Y, 0)
			+ nL:Cross(Vector3.yAxis) * rng:NextNumber(-0.4, 0.4) * wide
		local Y = -Vector3.yAxis
		local cf = b.CF * CFrame.fromMatrix(loc, Y:Cross(nL), Y, nL) * CFrame.Angles(-0.3, 0, rng:NextNumber(-0.25, 0.25))
		local o = takePlate()
		if o and W then W.PaintKit(o) end
		if o then
			local out = H.flat(cf.Position - chest)
			out = out.Magnitude > 1e-3 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
			spots[#spots + 1] = { O = o, CF = cf, Inner = inner, D = (cf.Position - contact).Magnitude / hV,
				S = Vector3.new(1.3, 1.0, 0.36) * ss * rng:NextNumber(0.7, 1.3),
				V = out * rng:NextNumber(4, 9) + exitDir * rng:NextNumber(6, 14) + Vector3.new(0, rng:NextNumber(5, 10), 0),
				Axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit,
				Spin = rng:NextNumber(3, 7) * (rng:NextNumber() < 0.5 and -1 or 1) }
		end
	end
	-- (2026-10-19, audit P5A-21) the swoop (a dragon 5x the victim's height, framed on the killer's view) flies only on
	-- the killer's and the victim's clients: everyone else in a live fight sees the kill on the body (the statue, its
	-- break, the frost ring), as the manual asks (kill effects "stay on the body, stay short")
	local me = Players.LocalPlayer and Players.LocalPlayer.Character
	local flies = (not thin) and me ~= nil and (killer == me or victim == me)
	local dragon = flies and takeDragon() or nil
	if dragon and W then for _, o in ipairs(dragon.All) do W.PaintKit(o) end end
	local J = dragon and rig()
	local bms = flies and beams() or {}
	local cracks = {}
	local function crescent(p0, v, life, g)
		for _, bm in ipairs(bms) do
			if bm.T0 < 0 then
				bm.T0, bm.P0, bm.V, bm.Life, bm.G = -2, p0, v, life, g
				local l = Vector3.yAxis - v.Unit * v.Unit.Y
				bm.L = l.Magnitude > 1e-3 and l.Unit or view
				local c = Color3.fromHex("#EEF9FF")
				bm.B.Color = W and W.CS(c, c) or ColorSequence.new(c)
				bm.B.Enabled = true
				return bm
			end
		end
	end
	-- the shadow it casts (a dragon-shaped cross of two dark ellipses racing along the ground) and the cold light
	local shB, shW = takePart(), takePart()
	for _, sp in ipairs({ shB, shW }) do
		sp.Material, sp.Color, sp.Size = Enum.Material.SmoothPlastic, Color3.fromHex("#22303C"), Vector3.one
		local m = sp:FindFirstChild("Ell") or Instance.new("SpecialMesh")
		m.Name, m.MeshType = "Ell", Enum.MeshType.Sphere
		m.Parent = sp
	end
	local lightHost = H.host(CFrame.new(chest), folder)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = (W and W.C(CORE)) or CORE, 18, 0, false
	light.Parent = lightHost

	H.ripple(CFrame.new(at + Vector3.new(0, 0.06, 0)), 0.5, 5, 0.6)       -- the frost ring under the victim
	local c0 = os.clock()
	local sealed, shattered, hit, misted, lastWake, settled, faded, stroked = false, false, false, false, -1, false, false, false
	local function frame(now, dt, parts, cframes)
		local t = age0 + (os.clock() - c0)
		-- THE DRAGON: the long descending curve in, the strike and its hold, the rising curve out, gone
		local dpos, dfwd
		if dragon then
			if t < P.Gone then
				local s, y, z, ds, dyds, dz = swoop(t, S, Hin, Hout)
				dpos = hitAt + right * s + Vector3.new(0, y, 0) + view * z
				local tan = right + Vector3.new(0, dyds, 0) + view * ((dz or 0) / math.max(ds, 1e-3))
				dfwd = (ds > 0) and tan.Unit or right
				local up = (Vector3.yAxis - dfwd * dfwd.Y).Unit
				-- banked toward the killer (its back to them), so the spread wings show broadside, not edge-on
				local bank = math.rad(P.Bank)
				local upB = (up * math.cos(bank) - view * math.sin(bank))
				upB = (upB - dfwd * upB:Dot(dfwd)).Unit
				local K = CFrame.fromMatrix(dpos, dfwd, upB)
				local f = (t < 0.1) and (1 - H.smooth(t / 0.1)) or H.smooth((t - (P.Gone - 0.25)) / 0.25)
				-- the wings: spread and gliding in, flared at the strike, one powerful downstroke on the climb
				local lA, sw
				local tc = t - P.Hit
				if tc < -0.1 then lA, sw = P.Glide, math.rad(8)
				elseif tc < P.Hold then
					local u = H.smooth((tc + 0.1) / (0.1 + P.Hold))
					lA, sw = P.Glide + math.rad(34) * u, math.rad(8) - math.rad(18) * u
				elseif tc < P.Hold + 0.22 then
					local u = H.smooth((tc - P.Hold) / 0.22)
					lA, sw = P.Glide + math.rad(34) - math.rad(76) * u, math.rad(-10) + math.rad(20) * u
				else
					local u = H.smooth((tc - P.Hold - 0.22) / 0.3)
					lA, sw = math.rad(-34) + math.rad(41) * u, math.rad(10)
				end
				local lB = P.Glide + (lA - P.Glide) * (1 + P.Elbow)
				local lC = P.Glide + (lA - P.Glide) * (1 + P.Elbow + P.Wrist)
				FD.Fade(dragon.Body, f)
				FD.Place(dragon.Body, K, parts, cframes, sc)
				for _, sd in ipairs({ "R", "L" }) do
					local pose = wingPose(J[sd], lA, lB, lC, sw)
					for i = 1, 3 do
						FD.Fade(dragon.W[sd][i], f)
						FD.Place(dragon.W[sd][i], K * CFrame.new(pose[2 * i - 1] * sc) * pose[2 * i], parts, cframes, sc)
					end
				end
				if not misted then                                     -- it condenses out of cloud-white frost mist
					misted = true
					H.burst(dpos, dfwd, { Powder = 6, Breath = 6 }, dens, 1.0)
				end
				if t - lastWake > 0.05 then                            -- the wake: mist off the tail, crescents off the wings
					lastWake = t
					local tail = K:PointToWorldSpace(Vector3.new(-14, 5, 0) * sc)
					if H.flat(tail - at).Magnitude > 12 then                -- (no mist over the statue: it must read)
						H.burst(tail, -dfwd, { Powder = 2, Flakes = 2 }, dens, 0.6)
					end
					if (t > 0.2 and t < P.Hit) or (t > P.Hit + P.Hold + 0.05 and t < P.Hit + P.Hold + 0.3) then
						crescent(K:PointToWorldSpace(Vector3.new(-4, 7, 0) * sc), dfwd * 18, 0.4, 0.8)
					end
				end
				if not stroked and tc > P.Hold + 0.08 then              -- the downstroke's gust, pushed off the wings
					stroked = true
					H.burst(K:PointToWorldSpace(Vector3.new(0, 4, 0) * sc), -Vector3.yAxis, { Flakes = 8 }, dens, 1.2)
				end
				if t >= P.Gone - 0.25 and not faded then               -- dissolving into cloud-white
					faded = true
					H.burst(dpos + Vector3.new(0, 4 * sc, 0), dfwd, { Powder = 8, Flakes = 4 }, dens, 0.8)
				end
			elseif not dragon.Off then
				dragon.Off = true
				for _, o in ipairs(dragon.All) do FD.Fade(o, 1) end
			end
		end
		-- the shadow: racing along the ground under the dragon, darkest as it nears the strike, gone as it climbs
		do
			local k = (t < P.Hit) and (t / P.Hit) ^ 1.3 or math.max(0, 1 - (t - P.Hit - P.Hold) / 0.4)
			if dpos and k > 0.02 then
				local g = Vector3.new(dpos.X, at.Y + 0.08, dpos.Z) + right * 3
				local f2 = dfwd and H.flat(dfwd) or right
				f2 = f2.Magnitude > 1e-3 and f2.Unit or right
				local cf = CFrame.fromMatrix(g, f2, Vector3.yAxis)
				shB.Ell.Scale, shW.Ell.Scale = Vector3.new(len * 0.8, 0.05, len * 0.18), Vector3.new(len * 0.3, 0.05, len * 0.7)
				shB.CFrame, shW.CFrame = cf, cf * CFrame.new(len * 0.05, 0, 0)
				shB.Transparency, shW.Transparency = 1 - 0.5 * k, 1 - 0.45 * k
			else
				shB.Transparency, shW.Transparency = 1, 1
			end
			light.Brightness = (calm and 1.5 or 3.2) * ((t < P.Hit) and H.smooth(t / P.Hit) or math.max(0, 1 - (t - P.Hit) / 0.7))
		end
		-- the crescents in flight: thick and bright where they start, thinning as they go (a smooth rise: no strobe)
		for _, bm in ipairs(bms) do
			if bm.T0 ~= -1 then
				if bm.T0 == -2 then bm.T0 = t end
				local tt = t - bm.T0
				if tt >= bm.Life then
					bm.T0 = -1
					bm.B.Enabled = false
				else
					local u1 = tt / bm.Life
					local ctr = bm.P0 + bm.V * tt
					local hl = (1.6 + 1.8 * u1) * math.max(1, hV / 4)
					local vx = bm.V.Unit
					local vy = (math.abs(vx.Y) < 0.95) and (Vector3.yAxis - vx * vx.Y).Unit or view
					bm.A0.WorldCFrame = CFrame.fromMatrix(ctr - bm.L * hl, vx, vy)
					bm.A1.WorldCFrame = CFrame.fromMatrix(ctr + bm.L * hl, vx, vy)
					bm.B.CurveSize0, bm.B.CurveSize1 = hl * 0.7, -hl * 0.7
					bm.B.Width0 = 1.4 * (1 - 0.6 * u1)
					bm.B.Width1 = bm.B.Width0
					local e = H.smooth(math.clamp(tt / 0.08, 0, 1)) * (1 - u1) ^ 1.2 * bm.G
					bm.B.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 1 - 0.7 * e),
						NumberSequenceKeypoint.new(0.5, 1 - 0.85 * e), NumberSequenceKeypoint.new(0.8, 1 - 0.7 * e), NumberSequenceKeypoint.new(1, 1) })
				end
			end
		end
		-- THE STRIKE: the frost burst at the claws, the white-hot ring, the statue sealing outward from the contact
		if t >= P.Hit and not hit then
			hit = true
			H.burst(contact, right, { Glints = calm and 3 or 6, Chips = 14, Flakes = 6 }, dens, 1.3)
			H.ripple(CFrame.new(at + Vector3.new(0, 0.07, 0)), 0.5, 7.5, 0.35)
			if not calm then H.ripple(CFrame.new(at + Vector3.new(0, 0.09, 0)), 0.3, 4.5, 0.22) end
		end
		if t >= P.Hit and not shattered then
			local front = math.clamp((t - P.Hit) / P.Seal, 0, 1) * 1.3
			for _, st in ipairs(statue) do
				if not st.On and st.D <= front then
					st.On = true
					st.Sh.Transparency, st.Core.Transparency = 0.15, 0
					st.B.P.LocalTransparencyModifier = 1
				end
			end
			for _, sp in ipairs(spots) do
				if not sp.Inner and sp.D <= front then
					local g = math.clamp((t - P.Hit - sp.D / 1.3 * P.Seal) / 0.06, 0.02, 1)
					FD.Fade(sp.O, 0)
					FD.Place(sp.O, sp.CF, parts, cframes, sp.S * H.easeOut(g))
				end
			end
			if not sealed and front >= 1.3 then
				sealed = true
				for _, x in ipairs(hide) do x.LocalTransparencyModifier = 1 end
			end
			-- white-hot cracks racing across the biggest pieces, along the scale lines, while the dragon climbs away
			if t >= P.Break - 0.18 and #cracks == 0 then
				table.sort(statue, function(a, b) return a.B.Size.Magnitude > b.B.Size.Magnitude end)
				for i = 1, math.min(#statue, P.Cracks[tier]) do
					local st = statue[i]
					local ok, p = pcall(H.take, "@Block", "HotCrack")
					if ok and p then
						local sz = st.B.Size
						local face = (i % 2 == 0) and 1 or -1
						p.Size = Vector3.new(0.11, math.min(sz.Y, 1.9) * rng:NextNumber(0.75, 1.0), 0.07)
						p.CFrame = st.B.CF * CFrame.new(0, 0, face * sz.Z * 0.56) * CFrame.Angles(0, 0, rng:NextNumber(-0.9, 0.9))
						p.Transparency = 1
						p.Parent = folder
						cracks[#cracks + 1] = { P = p, T0 = t + i * 0.015 }
					end
				end
			end
			for _, ck in ipairs(cracks) do ck.P.Transparency = 1 - H.smooth(math.clamp((t - ck.T0) / 0.08, 0, 1)) end
		end
		-- THE BREAK: plates and jagged chunks thrown out and up and dragged after the dragon, tumbling, falling, fading
		if t >= P.Break then
			if not shattered then
				shattered = true
				for _, st in ipairs(statue) do st.Sh.Transparency, st.Core.Transparency = 1, 1 end
				for _, ck in ipairs(cracks) do ck.P.Transparency = 1 end
				H.burst(chest, exitDir, { Glints = calm and 6 or 14, Flakes = 16, Powder = 2 }, dens, 1.3)
				if not calm then H.ripple(CFrame.new(chest), 0.8, 6, 0.4) end        -- a soft ring of light (no flash)
				for _ = 1, P.Chunks[tier] do
					local o = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-1, 1)) * Vector3.new(0.7, hV * 0.4, 0.7)
					local out = H.flat(o)
					out = out.Magnitude > 1e-3 and out.Unit or right
					pcall(H.throw, CHUNKS[rng:NextInteger(1, #CHUNKS)], CFrame.new(chest + o) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
						out * rng:NextNumber(4, 9) + exitDir * rng:NextNumber(5, 12) + Vector3.new(0, rng:NextNumber(4, 9), 0),
						Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * rng:NextNumber(4, 10),
						rng:NextNumber(0.9, 1.2), Vector3.one * rng:NextNumber(0.9, 2.4) * math.clamp(hV / 5, 0.7, 1.3), feet, "Chunk")
				end
			end
			local tt = t - P.Break
			local f = H.smooth(math.clamp((t - (P.End - 0.5)) / 0.4, 0, 1))
			for _, sp in ipairs(spots) do
				FD.Fade(sp.O, f)
				if f < 1 then
					local pos = sp.CF.Position + sp.V * tt + Vector3.new(0, -16 * tt * tt, 0)
					pos = Vector3.new(pos.X, math.max(pos.Y, feet + 0.25), pos.Z)
					FD.Place(sp.O, CFrame.new(pos) * sp.CF.Rotation * CFrame.fromAxisAngle(sp.Axis, sp.Spin * tt), parts, cframes, sp.S)
				end
			end
			if t >= P.End - 0.6 and not settled then
				settled = true
				H.burst(chest, Vector3.yAxis, { Powder = 2, Flakes = 4 }, dens, 0.5)
				H.ripple(CFrame.new(at + Vector3.new(0, 0.06, 0)), 3, 6.5, 0.45)      -- the faint frost ring
			end
		end
		-- the end: everything back in the pool; a body that is still alive (a training dummy) shows again
		if t >= P.End then
			for _, st in ipairs(statue) do
				st.Sh.Transparency, st.Core.Transparency = 1, 1
				pool.Parts[#pool.Parts + 1] = st.Sh
				pool.Parts[#pool.Parts + 1] = st.Core
			end
			shB.Transparency, shW.Transparency = 1, 1
			pool.Parts[#pool.Parts + 1] = shB
			pool.Parts[#pool.Parts + 1] = shW
			for _, sp in ipairs(spots) do FD.Fade(sp.O, 1) pool.Plates[#pool.Plates + 1] = sp.O end
			for _, ck in ipairs(cracks) do pcall(H.give, ck.P) end
			for _, bm in ipairs(bms) do bm.T0 = -1 bm.B.Enabled = false end
			if dragon then
				for _, o in ipairs(dragon.All) do FD.Fade(o, 1) end
				dragon.Off = nil
				pool.Dragons[#pool.Dragons + 1] = dragon
			end
			-- a body still alive shows again; a training dummy (KO'd, then refilled) shows again once it is back up
			local hum = victim:FindFirstChildOfClass("Humanoid")
			if hum and (hum.Health > 0 or victim:GetAttribute("TrainingDummy") ~= nil) then
				task.spawn(function()
					local t = os.clock()
					while hum.Parent and hum.Health <= 0 and os.clock() - t < 8 do task.wait(0.1) end
					for _, x in ipairs(hide) do if x.Parent then x.LocalTransparencyModifier = 0 end end
				end)
			end
			folder:Destroy()
			return false
		end
		return true
	end
	-- (2026-10-19, audit P5A-21) a frame that errors ends the effect cleanly: the hidden body shows again (a living
	-- dummy used to stay invisible), the crescents switch off and the folder goes
	H.run(((W and W.Bind) or function(f) return f end)(function(now, dt, parts, cframes)      -- (each frame in the wrap)
		local ok, keep = pcall(frame, now, dt, parts, cframes)
		if ok then return keep end
		why("a frame failed: " .. tostring(keep))
		for _, x in ipairs(hide) do if x.Parent then x.LocalTransparencyModifier = 0 end end
		for _, bm in ipairs(bms) do pcall(function() bm.T0 = -1 bm.B.Enabled = false end) end
		folder:Destroy()
		return false
	end))
end
function KFX.Play(killer, victim, stamp)
	-- the kit builds when a wearer joins; a kill in the first moments may find it still building: wait a little for it.
	-- (2026-10-19, audit P5A-16) the wait is here, before W.Run: CryoWrap swaps every shared palette for the length of the
	-- call, so a wrapped function must never yield ("Never wrap a function that yields")
	local tw = os.clock()
	while FD and not FD.Built and not FD.Failed and os.clock() - tw < 2 do task.wait(0.1) end
	local waited = os.clock() - tw > 0.05
	local P = W and W.For and W.For(killer)
	if P then return W.Run(P, play, killer, victim, stamp, waited) end
	return play(killer, victim, stamp, waited)
end

--- Watch every character for a Frost Dragon kill (KillFX + KillFXVictim, set by the server's kill hook).
function KFX.Start()
	if KFX.Started then return end
	KFX.Started = true
	H = require(iceFolder:WaitForChild("CryoFX"))._H
	local okW, w = pcall(function() return require(iceFolder:WaitForChild("CryoWrap")) end)
	W = okW and w or nil
	FD = require(iceFolder:WaitForChild("FrostDragonKit"))
	if FD.OnRelease then                                -- (2026-10-19, MeshBudget) the kit let go: its pooled pieces go too
		FD.OnRelease(function()
			for _, d in ipairs(pool.Dragons) do
				for _, o in ipairs(d.All) do FD.Drop(o) end
				pcall(function() d.Model:Destroy() end)
			end
			for _, o in ipairs(pool.Plates) do FD.Drop(o) end
			pool.Dragons, pool.Plates = {}, {}
		end)
	end
	local seen = setmetatable({}, { __mode = "k" })
	local function watch(character)
		if seen[character] then return end
		seen[character] = true
		character:GetAttributeChangedSignal("KillFX"):Connect(function()
			local stamp, name = character:GetAttribute("KillFX"), character:GetAttribute("KillFXVictim")
			if typeof(stamp) ~= "number" or type(name) ~= "string" then return end
			if not FD.On(character) then return why("the killer is not wearing Frost Dragon") end
			task.spawn(function()
				-- the victim by reference (KillFXVictimRef: a dummy lives inside workspace.TrainingGround, and names
				-- repeat); its value can land a moment after the stamp, so wait a little; else by name
				local ref = character:FindFirstChild("KillFXVictimRef")
				local t = os.clock()
				while ref and not (ref.Value and ref.Value.Parent) and os.clock() - t < 0.3 do task.wait() end
				local victim = (ref and ref.Value and ref.Value.Parent and ref.Value) or workspace:FindFirstChild(name)
					or workspace:FindFirstChild(name, true)
				if victim and victim:IsA("Model") then KFX.Play(character, victim, stamp) else why("victim not found: " .. name) end
			end)
		end)
	end
	local function onPlayer(plr)
		if plr.Character then watch(plr.Character) end
		plr.CharacterAdded:Connect(watch)
	end
	for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
	Players.PlayerAdded:Connect(onPlayer)
	if RunService:IsStudio() then                                      -- (Studio: the skin test's stand-in casters)
		local function dummy(m) if m:IsA("Model") and m:GetAttribute("StudioSkin") then watch(m) end end
		for _, m in ipairs(workspace:GetChildren()) do dummy(m) end
		workspace.ChildAdded:Connect(function(m) task.defer(dummy, m) end)
	end
	-- (2026-10-26) the showcase stand-ins (ShowcaseSkin = "FrostDragon", live and in Studio), wherever in the workspace
	if FD.Showcased then
		task.spawn(function()
			while true do
				for _, m in ipairs(FD.Showcased()) do watch(m) end
				task.wait(1)
			end
		end)
	end
end

return KFX
