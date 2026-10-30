--[[
	FrostDragonFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/FrostDragonFX

	Cryo's FROST DRAGON skin (the Mythic, 2026-10-15), the piece logic; the meshes are FrostDragonKit's (from
	FrostDragonData, cut by vfx_blocking/cryo/cryo_frostdragon_skin_2026_10_15/fd_export.py). Kept OUT of CryoFX (it sits at
	Luau's 200 top-level locals): CryoFX hands this module its helpers once (Init: CryoFX._H) and calls in from the Mirror
	Cage's hooks -- the same calls as FrostLotusFX -- for a caster who wears the skin (CryoFX's FBX.DragonOn).
	  Cage*   Mirror Cage (stage 1): one dragon of glowing ice curled round the cage (centred on the target, like Frost
	          Lotus's bloom): its coils rise out of the floor chest first, the tail sweeping round last; the neck rears and
	          swings over, the wings unfold. Every bolt leaves from one of its 29 crystal plates (the back's 14 first, the
	          side facing the caster first, then the wings' 10, the crest's 5 last), each plate shrinking per bolt and spent
	          on its last; whatever is unspent sheds at the volley's end. On the kill it roars (the jaw drops, a white-cyan
	          ring puffs from the mouth); on the impact the whole body shatters into shards.
	The flight's path and TIME stay the Default's (TimeFrom; a straight line). KEYHOLE: on each client, any piece between
	this camera and a player near the dragon (or a trapped one anywhere) fades to a ghost; the pieces nearest a camera
	inside the coil fade by distance (RegisterProximityFade's curve, folded into each piece's own fade so its Neon stays
	whole-or-hidden).
]]

local Players = game:GetService("Players")

local DFX = {}
local H, FD                                       -- CryoFX's helpers (Init), FrostDragonKit
local rng = Random.new()

function DFX.Init(helpers, kit)
	H, FD = helpers, kit
	if kit and kit.OnRelease then kit.OnRelease(function() DFX._release() end) end   -- (2026-10-19, MeshBudget)
	DFX.Kit = kit                                 -- what CryoFX drops a finished bolt through
	-- dress styles in CryoFX's STYLE table (H.STYLE), read by name like its own:
	--   DragonGlow   the ground's soft pale-cyan glow (the cage's crystal spikes, their thrown tops, the shatter's
	--                splinters): OPAQUE Neon #8FEFFF (a transparent Neon loses its emission, which left the spikes
	--                mid-blue glass; measured in game 2026-10-16: on these SpecialMesh crystals the input shows as itself,
	--                not brightened -- a dim input read dark teal; they also do not glow on a dark map)
	--   DragonShard  the shatter's chunks: pale smooth crystal (not the Default's chunky teal)
	if H.STYLE then
		H.STYLE.DragonGlow = H.STYLE.DragonGlow or { Enum.Material.Neon, Color3.fromHex("#8FEFFF"), 0, 0 }
		H.STYLE.DragonShard = H.STYLE.DragonShard or { Enum.Material.SmoothPlastic, Color3.fromHex("#CDEBFB"), 0.15, 0.04 }
	end
end

--- the cage's ground for this skin (CryoFX reads lfk.Ground): the frost disc's sparse art tinted soft pale cyan and kept
--- faint (a decal cannot glow: kept light, it never reads as a slab), the floor and lock rings drawn as a thin bright
--- pale-cyan Neon line, the crystal clusters' feet pale ice (no deep-blue chunks) and their spikes -- and so the crystal
--- burst's thrown tops -- a glowing pale cyan
DFX.Ground = { Tex = "FrostDiscLight", Tint = Color3.fromHex("#8FEFFF"), T = 0.8, Glow = 2, Base = "Tip", Spike = "DragonGlow" }

-- the keyhole: Ghost the fade a piece takes while it hides a player (its Neon goes, its ice nearly clear), Hold how long a
-- hit keeps it ghosted (so a body at a capsule's edge doesn't make it blink)
local KEY = { Every = 3, Ghost = 0.9, Rate = 9, Hold = 0.3, Rows = { 0.7, 1.8, 2.9, 4.0, 4.9 }, Cols = { -0.9, 0, 0.9 } }
-- the near fade (VFXLibrary.RegisterProximityFade's, folded into each piece's own fade so all its groups fade as one and
-- the Neon stays whole-or-hidden): from Near studs (past the piece's reach) it starts, by Near + Span it is gone
local PROX = { Near = 4.5, Span = 4.5, Reach = 0.35 }
local KEEPOUT = 4                                  -- the shatter throws no chunk from within this of the trapped body's column
-- the coil: each segment rises from RISE studs under the floor, chest (seg10) first, the tail tip (seg01) last
local COIL = { Start = 0.1, Step = 0.05, Dur = 0.38, Rise = 7 }
local NECK = { Start = 0.1, Dur = 0.42, Rise = 9, SwingAt = 0.5, SwingDur = 0.5, Swing = math.rad(-62), Bob = 0.025 }
local WING = { At = 0.55, Dur = 0.5, FoldO = math.rad(-78), FoldI = math.rad(-58) }
local ROAR = { Open = math.rad(22), Rear = math.rad(-7), In = 0.14, PuffAt = 0.06, JawSign = 1 }
local SPEND, SHED = 0.14, 0.7
local BREAK = { Dur = 0.42, Drift = 3.2, Drop = 2.2 }

local function rot(piv, axis, ang)
	if ang == 0 then return CFrame.identity end
	return CFrame.new(piv) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-piv)
end
local function v3(t) return Vector3.new(t[1], t[2], t[3]) end
local warned = false
local function warnOnce(err)
	if warned then return end
	warned = true
	warn("[FrostDragonFX] " .. tostring(err))
end

----------------------------------------------------------------------------------------------------
-- MIRROR CAGE
----------------------------------------------------------------------------------------------------
function DFX.CageSetup(cage, aimAt, thin, center, gy)
	local data = FD.Data
	if not (data and FD.Built and FD.Kind("head") and FD.Kind("Plate")) then return end        -- still building: Default
	local C = Vector3.new(center.X, gy, center.Z)                      -- under the target: the cage's centre, on its floor
	local croot = typeof(cage.Caster) == "Instance" and cage.Caster:FindFirstChild("HumanoidRootPart")
	local toward = croot and H.flat(croot.Position - C) or Vector3.zero
	toward = toward.Magnitude > 1e-3 and toward.Unit or Vector3.zAxis
	-- the dragon's frame: +Z toward the caster (the data's convention), +Y up
	local F = CFrame.lookAt(C, C - toward)
	local L = { C = C, F = F, Pieces = {}, List = {}, Plates = {}, Order = {}, Shot = 0, Total = 0, Frame = 0, Age = 0,
		Tangent = v3(data.Tangent).Unit, JawAxis = v3(data.JawAxis).Unit, Thin = thin, Volley = 0, Puffed = false,
		Dens = H.density(cage.Caster) }
	for name, d in pairs(data.Pieces) do
		local o = FD.New(name, cage.Folder)
		if o then
			if thin then FD.HideGroup(o, "Core") end                -- (the low tier: no inner glow)
			FD.Fade(o, 1)
			local pc = { Name = name, O = o, Piv = v3(d.Pivot), M = CFrame.identity, KF = 0, KT = 0, Form = 1 }
			if d.Caps then
				pc.Caps = {}
				for _, c in ipairs(d.Caps) do
					local r = c[7] * ((name == "head") and 1.5 or 1.08)
					pc.Caps[#pc.Caps + 1] = { Vector3.new(c[1], c[2], c[3]), Vector3.new(c[4], c[5], c[6]), r }
				end
			end
			if d.Tris then
				pc.Tris, pc.Sphere = {}, Vector3.zero
				local n = 0
				for _, t in ipairs(d.Tris) do
					local a, b, c = Vector3.new(t[1], t[2], t[3]), Vector3.new(t[4], t[5], t[6]), Vector3.new(t[7], t[8], t[9])
					pc.Tris[#pc.Tris + 1] = { a, b, c }
					pc.Sphere += a + b + c
					n += 3
				end
				pc.Sphere /= math.max(n, 1)
				pc.R = 0
				for _, t in ipairs(pc.Tris) do
					for k = 1, 3 do pc.R = math.max(pc.R, (t[k] - pc.Sphere).Magnitude) end
				end
			end
			local seg = tonumber(name:match("^seg(%d+)$"))
			if seg then pc.Start = COIL.Start + COIL.Step * (10 - seg) end
			-- the near fade's reach: the union of the piece's parts (pivot-relative)
			local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
			for _, p in ipairs(o.Parts) do
				lo, hi = lo:Min(p.Off - p.Size / 2), hi:Max(p.Off + p.Size / 2)
			end
			pc.Mid, pc.Reach = (lo + hi) / 2, PROX.Reach * (hi - lo).Magnitude
			pc.Prox = 0
			L.Pieces[name] = pc
			L.List[#L.List + 1] = pc
		end
	end
	for _, d in ipairs(data.Plates) do
		local o = FD.New("Plate", cage.Folder)
		if o then
			FD.Fade(o, 1)
			local U = v3(d.U).Unit
			local N = v3(d.N)
			N = (N - U * N:Dot(U)).Unit                         -- (an orthonormal frame, whatever the data says)
			local K = CFrame.fromMatrix(v3(d.C), U, N)
			L.Plates[#L.Plates + 1] = { O = o, K = K, Follow = d.Follow, Tier = d.Tier, Sz = Vector3.new(d.L, d.T, d.W), S = 1,
				Face = d.C[3], Hot = 0, G = -1 }
		end
	end
	L.Order = table.clone(L.Plates)
	table.sort(L.Order, function(p, q)
		if p.Tier ~= q.Tier then return p.Tier < q.Tier end
		return p.Face > q.Face
	end)
	for _, pn in ipairs(cage.Panels) do
		pn.Dragon = L
		L.Total += #pn.Fires
		for _, f in ipairs(pn.Fires) do L.Volley = math.max(L.Volley, f) end
	end
	cage.Dragon = L
	cage.Blooms = {}                     -- (CryoFX steps, bursts and drops the skin's cage look while this is set)
end

-- the keyhole's geometry: the least distance between segments p1 -> q1 and p2 -> q2; does the segment o -> o + d cross
-- the triangle p0 p1 p2
local function segSeg(p1, q1, p2, q2)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a < 1e-9 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		local b = d1:Dot(d2)
		local den = a * e - b * b
		s = (den > 1e-9) and math.clamp((b * f - c * e) / den, 0, 1) or 0
		t = (b * s + f) / e
		if t < 0 then
			t, s = 0, math.clamp(-c / a, 0, 1)
		elseif t > 1 then
			t, s = 1, math.clamp((b - c) / a, 0, 1)
		end
	end
	return ((p1 + d1 * s) - (p2 + d2 * t)).Magnitude
end
local function nearSeg(a, d, c, r)
	local t = math.clamp((c - a):Dot(d) / d:Dot(d), 0, 1)
	return (a + d * t - c).Magnitude < r
end
local function crosses(o, d, p0, p1, p2)
	local e1, e2 = p1 - p0, p2 - p0
	local h = d:Cross(e2)
	local det = e1:Dot(h)
	if math.abs(det) < 1e-9 then return false end
	local f = 1 / det
	local s = o - p0
	local u = f * s:Dot(h)
	if u < 0 or u > 1 then return false end
	local q = s:Cross(e1)
	local v = f * d:Dot(q)
	if v < 0 or u + v > 1 then return false end
	local t = f * e2:Dot(q)
	return t > 0 and t < 0.995
end

local function keyhole(L, cage)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local E, camRight = cam.CFrame.Position, cam.CFrame.RightVector
	for _, pc in ipairs(L.List) do pc.KT = 0 end         -- (a recent hit's Hold keeps it ghosted: below)
	-- this frame's proxies, in the world
	local live = {}
	for _, pc in ipairs(L.List) do
		if pc.Form < 1 and (pc.Caps or pc.Tris) then
			local W = L.F * pc.M
			local px = { P = pc }
			if pc.Caps then
				px.Caps = {}
				for _, c in ipairs(pc.Caps) do px.Caps[#px.Caps + 1] = { W * c[1], W * c[2], c[3] } end
			else
				px.At, px.R, px.W = W * pc.Sphere, pc.R, W
			end
			live[#live + 1] = px
		end
	end
	local seen = {}
	local function check(m, anywhere)
		if typeof(m) ~= "Instance" or not m.Parent or seen[m] then return end
		seen[m] = true
		local root = m:FindFirstChild("HumanoidRootPart")
		if not root or (not anywhere and H.flat(root.Position - L.C).Magnitude > 27) then return end
		local hum = m:FindFirstChildOfClass("Humanoid")
		local feet = root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 2)
		for _, y in ipairs(KEY.Rows) do
			for _, x in ipairs(KEY.Cols) do
				local P = Vector3.new(root.Position.X, feet + y, root.Position.Z) + camRight * x
				local d = P - E
				for _, px in ipairs(live) do
					local pc = px.P
					if pc.KT == 0 then
						if px.Caps then
							for _, c in ipairs(px.Caps) do
								if segSeg(E, P, c[1], c[2]) < c[3] then pc.KT = KEY.Ghost break end
							end
						elseif nearSeg(E, d, px.At, px.R) then
							for _, t in ipairs(pc.Tris) do
								if crosses(E, d, px.W * t[1], px.W * t[2], px.W * t[3]) then pc.KT = KEY.Ghost break end
							end
						end
					end
				end
			end
		end
	end
	for _, v in ipairs(cage.Victims or {}) do check(v.Model, true) end
	check(cage.Caster, false)
	for _, plr in ipairs(Players:GetPlayers()) do check(plr.Character, false) end
	-- the head and jaw ghost together (each has its own proxies; either one's hit takes both)
	local hd, jw = L.Pieces.head, L.Pieces.jaw
	if hd and jw then
		local k = math.max(hd.KT, jw.KT)
		hd.KT, jw.KT = k, k
	end
	-- a hit latches for KEY.Hold, so a body at the edge of a proxy doesn't make the piece blink
	for _, pc in ipairs(L.List) do
		if pc.KT > 0 then
			pc.KHold = L.Age + KEY.Hold
		elseif pc.KHold and L.Age < pc.KHold then
			pc.KT = KEY.Ghost
		end
	end
end

--- the near fade of piece `pc` for this camera (0 far .. 1 at the camera)
local function nearFade(L, pc, camPos)
	if not camPos then return 0 end
	local d = ((L.F * pc.M * CFrame.new(pc.Piv)) * pc.Mid - camPos).Magnitude - pc.Reach
	return 1 - math.clamp((d - PROX.Near) / PROX.Span, 0, 1)
end

local function ease(x, dt)
	if x.KF ~= x.KT then
		local step = KEY.Rate * dt
		x.KF = (x.KF < x.KT) and math.min(x.KT, x.KF + step) or math.max(x.KT, x.KF - step)
	end
end

--- every piece's pose at `age` (cage space, about its own pivot; the data's pose is the coil set)
local function pose(L, age, cage)
	local T, P = L.Tangent, L.Pieces
	local roar = 0
	if cage.KillAt and age >= cage.KillAt then roar = H.easeOut((age - cage.KillAt) / ROAR.In) end
	L.Roar = roar
	for _, pc in ipairs(L.List) do
		if pc.Start then
			local u = (age - pc.Start) / COIL.Dur
			local e = H.easeOut(math.clamp(u, 0, 1))
			pc.M = CFrame.new(0, -COIL.Rise * (1 - e), 0)
			pc.Form = (u <= 0) and 1 or math.max(0, 1 - u * 3)
		end
	end
	local nu = (age - NECK.Start) / NECK.Dur
	local ne = H.easeOut(math.clamp(nu, 0, 1))
	local lift = CFrame.new(0, -NECK.Rise * (1 - ne), 0)
	local nform = (nu <= 0) and 1 or math.max(0, 1 - nu * 3)
	local sw = H.easeOut(math.clamp((age - NECK.SwingAt) / NECK.SwingDur, 0, 1))
	local a = NECK.Swing * (1 - sw) + NECK.Bob * math.sin(age * 2.3) * sw + ROAR.Rear * roar
	if P.neck then
		local Mh = lift * rot(P.neck.Piv, T, a)
		P.neck.M, P.neck.Form = Mh, nform
		if P.head then P.head.M, P.head.Form = Mh, nform end
		if P.jaw then
			P.jaw.M = Mh * rot(P.jaw.Piv, L.JawAxis, ROAR.JawSign * ROAR.Open * roar)
			P.jaw.Form = nform
		end
	end
	local wu = (age - WING.At) / WING.Dur
	local we = H.easeOut(math.clamp(wu, 0, 1))
	local wform = (wu <= 0) and 1 or math.max(0, 1 - wu * 4)
	local flap = math.rad(6) * roar
	if P.wingO then P.wingO.M, P.wingO.Form = lift * rot(P.wingO.Piv, T, WING.FoldO * (1 - we) - flap), wform end
	if P.wingI then P.wingI.M, P.wingI.Form = lift * rot(P.wingI.Piv, T, WING.FoldI * (1 - we) - flap), wform end
end

local function plateCF(L, p)
	local pc = L.Pieces[p.Follow]
	return L.F * (pc and pc.M or CFrame.identity) * p.K, pc
end

local function step(cage, age, parts, cframes)
	local L = cage.Dragon
	local dt = math.clamp(age - L.Age, 0, 0.1)
	L.Age = age
	L.Frame += 1
	pose(L, age, cage)
	if L.Frame % KEY.Every == 1 then keyhole(L, cage) end
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	for _, pc in ipairs(L.List) do
		ease(pc, dt)
		pc.Prox = nearFade(L, pc, camPos)
		FD.Fade(pc.O, math.max(pc.KF, pc.Form, pc.Prox))
		-- (a piece that has not moved since the last frame -- the risen coil, the spread wings -- is not moved again)
		local cf = L.F * pc.M * CFrame.new(pc.Piv)
		if cf ~= pc.Last then
			pc.Last = cf
			FD.Place(pc.O, cf, parts, cframes)
		end
	end
	-- the roar's ring: a white-cyan puff out of the mouth
	if not L.Puffed and L.Roar > 0 and cage.KillAt and age >= cage.KillAt + ROAR.PuffAt then
		L.Puffed = true
		local hd = L.Pieces.head
		local cap = hd and hd.Caps and hd.Caps[1]
		if cap then
			local W = L.F * hd.M
			local back, tip = W * cap[1], W * cap[2]
			local dir = (tip - back).Unit
			local at = tip + dir * 0.6
			local cf = CFrame.fromMatrix(at, dir:Cross(Vector3.yAxis).Magnitude > 1e-3 and dir:Cross(Vector3.yAxis).Unit or Vector3.xAxis, dir)
			pcall(H.ripple, cf, 0.6, 7, 0.45, 0.2)
			pcall(H.ripple, cf * CFrame.new(0, 1.2, 0), 0.3, 4.5, 0.38, 0.35)
			if not L.Thin then H.burst(at, dir, { Powder = 3, Glints = 3 }, L.Dens, 1.3) end
			pcall(H.flashAt, at, 2.5, 18, 0.3)
		end
	end
	-- the plates: ride their piece, glow on their bolt, shrink per bolt, spent on the last; the unspent shed at the end
	local shedAt = math.min(L.Volley + 0.12, cage.KillAt or math.huge)
	for _, p in ipairs(L.Plates) do
		if not p.Gone then
			local K, pc = plateCF(L, p)
			if age >= shedAt and not p.SpentAt and not p.Shed then
				p.Shed = { At = age, K = K, Out = H.flat(K.Position - L.C).Unit, Spin = rng:NextNumber(-1.2, 1.2) }
				if not L.Thin and rng:NextNumber() < 0.4 then H.burst(K.Position, K.UpVector, { Glints = 1 }, L.Dens, 0.8) end
			end
			if p.Shed then
				local e = math.clamp((age - p.Shed.At) / SHED, 0, 1)
				if e >= 1 then
					FD.Drop(p.O)
					p.Gone = true
				else
					local s = p.Shed
					local W = CFrame.new(s.Out * (2.2 * e) - Vector3.new(0, 4.5 * e * e, 0)) * s.K * CFrame.Angles(s.Spin * e, 0, 0.9 * e)
					FD.Fade(p.O, math.max(pc and pc.KF or 0, pc and pc.Prox or 0, H.smooth((e - 0.3) / 0.7)))
					FD.Place(p.O, W, parts, cframes, p.Sz * p.S)
				end
			else
				local spend = p.SpentAt and math.clamp((age - p.SpentAt) / SPEND, 0, 1) or 0
				if spend >= 1 then
					FD.Drop(p.O)
					p.Gone = true
				else
					p.Hot = math.max(0, p.Hot - dt / 0.18)
					local g = math.floor(4 * p.Hot + 0.5) / 4
					if g ~= p.G then
						p.G = g
						FD.PlateGlow(p.O, g)                          -- soft pale glow at rest, white-hot on its bolt
					end
					local form = pc and pc.Form or 0
					FD.Fade(p.O, math.max(pc and pc.KF or 0, pc and pc.Prox or 0, form, spend))
					p.Now = K
					FD.Place(p.O, K, parts, cframes, p.Sz * math.max(0.02, p.S * (1 - spend)))
				end
			end
		end
	end
end

function DFX.CageStep(cage, age, parts, cframes)
	if not cage.Dragon then return end
	local ok, err = pcall(step, cage, age, parts, cframes)
	if not ok then warnOnce(err) end
end

--- where a bolt leaves: the tip of the next plate in the firing order (it shrinks; on its last bolt it is spent)
function DFX.BoltFrom(pn, aimAt)
	local L = pn.Dragon
	if not (L and #L.Order > 0) then
		return pn.Pos + (aimAt - pn.Pos).Unit * 1.2
	end
	L.Shot += 1
	local n, total = #L.Order, math.max(L.Total, 1)
	local i = math.min(n, math.floor((L.Shot - 1) * n / total) + 1)
	local p = L.Order[i]
	if p.Gone or p.SpentAt or p.Shed then                    -- (more bolts than planned) any plate still on the dragon
		p = nil
		for _, q in ipairs(L.Order) do
			if not (q.Gone or q.SpentAt or q.Shed) then p = q break end
		end
		if not p then return L.C + Vector3.new(0, 4, 0) end
	end
	p.S = math.max(0.5, p.S - 0.13)
	p.Hot = 1
	if math.floor(L.Shot * n / total) + 1 > i or L.Shot >= total then p.SpentAt = L.Age end
	local K = p.Now or plateCF(L, p)
	return K * Vector3.new(0, p.Sz.Y * p.S * 0.7, 0)
end

--- the Default's start, for the flight's time (CryoFX: Dur from here, so every bolt still lands on its beat)
function DFX.TimeFrom(pn, aimAt)
	return pn.Pos + (aimAt - pn.Pos).Unit * 1.2
end

function DFX.NewBolt(folder)
	local o = FD.New("Bolt", folder)
	if o then FD.Fade(o, 0) end
	return o
end

function DFX.Peel(pos) end                         -- (CryoFX's own glint at the plate is the peel)
--- a bolt's strike (CryoFX passes the cage's low tier and density: Graphics Quality / Reduce Enemy VFX)
function DFX.Strike(pos, thin, dens)
	if thin then return end
	H.burst(pos, Vector3.yAxis, { Glints = 2, Powder = 1 }, dens, 0.9)
end

--- the bolt at flight fraction u: the Default's straight line, its tip on the line
function DFX.PlaceBolt(fly, u, parts, cframes)
	local d = fly.To - fly.From
	local dir = d.Magnitude > 1e-4 and d.Unit or Vector3.zAxis
	local tip = fly.From + d * u
	FD.Place(fly.O, FD.Frame(tip - dir * (FD.BoltL / 2), dir, Vector3.yAxis), parts, cframes)
end

--- the impact: the whole body shatters -- every piece drifts out, turns and fades while pale crystal shards and glowing
--- splinters fly out from it (never from the trapped body's column: KEEPOUT); any plate still on it goes with it
function DFX.CageBurst(cage, aimAt, gy, thin)
	local L = cage.Dragon
	cage.Dragon, cage.Blooms = nil, nil
	if not L then return end
	local dens = L.Dens or H.density(cage.Caster)
	local CH = { "CK_Chunk_1", "CK_Chunk_2", "CK_Chunk_3", "CK_Chunk_4" }
	local SP = { "CK_IS_Splinter_1", "CK_IS_Splinter_2", "CK_IS_Splinter_3" }
	local shard = (H.STYLE and H.STYLE.DragonShard) and "DragonShard" or "Tip"
	local glow = (H.STYLE and H.STYLE.DragonGlow) and "DragonGlow" or "Tip"
	local bits = {}
	for i, pc in ipairs(L.List) do
		local W = L.F * pc.M * CFrame.new(pc.Piv)
		local mid = W * pc.Mid
		local out = H.flat(mid - L.C)
		out = out.Magnitude > 1e-3 and out.Unit or Vector3.xAxis
		bits[#bits + 1] = { P = pc, W = W, Out = out, Delay = (i % 4) * 0.025,
			Spin = Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)) }
		local n = thin and 1 or ((pc.Name == "head" or pc.Name:match("^wing")) and 3 or 2)
		for k = 1, n do
			local name = (k % 2 == 1) and CH[rng:NextInteger(1, #CH)] or SP[rng:NextInteger(1, #SP)]
			local at = mid + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 2), rng:NextNumber(-1.5, 1.5))
			local fl = H.flat(at - L.C)
			if fl.Magnitude < KEEPOUT then                    -- out of the trapped body's column
				at += ((fl.Magnitude > 1e-3) and fl.Unit or out) * (KEEPOUT - fl.Magnitude)
			end
			pcall(H.throw, name, CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), 0),
				(out * rng:NextNumber(0.6, 1) + Vector3.new(0, rng:NextNumber(0.4, 1.1), 0)) * rng:NextNumber(7, 13),
				Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 8, rng:NextNumber(0.9, 1.4),
				Vector3.one * rng:NextNumber(0.7, 1.25), gy, (k % 2 == 1) and shard or glow)
		end
		if not thin or i % 2 == 0 then H.burst(mid, out + Vector3.yAxis * 0.5, { Powder = 2, Glints = 1 }, dens, 1.1) end
	end
	for _, p in ipairs(L.Plates) do
		if not p.Gone then
			local K = p.Now or plateCF(L, p)
			bits[#bits + 1] = { Plate = p, W = K, Out = H.flat(K.Position - L.C).Unit, Delay = 0,
				Spin = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) }
		end
	end
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		local alive = false
		for _, b in ipairs(bits) do
			local o = b.P and b.P.O or b.Plate.O
			if not b.Done then
				local e = math.clamp((t - b.Delay) / BREAK.Dur, 0, 1)
				if e >= 1 then
					FD.Drop(o)
					b.Done = true
				else
					alive = true
					local W = CFrame.new(b.Out * (BREAK.Drift * e) - Vector3.new(0, BREAK.Drop * e * e, 0)) * b.W
						* CFrame.Angles(b.Spin.X * e, b.Spin.Y * e, b.Spin.Z * e)
					FD.Fade(o, math.max(b.P and b.P.KF or 0, b.P and b.P.Prox or 0, H.smooth(e / 0.85)))
					if b.Plate then
						FD.Place(o, W, parts, cframes, b.Plate.Sz * b.Plate.S)
					else
						FD.Place(o, W, parts, cframes)
					end
				end
			end
		end
		return alive
	end)
end

----------------------------------------------------------------------------------------------------
-- M1 (stage 2): the Frost Wyrmling flies as VFXLibrary's shot (FrostDragonKit.ShotLook / Ride). Its hit (CryoFX.ShardImpact
-- -> HitBloom): a Wyrmling head at the impact, its jaws SNAP shut on the point (a crack of glints), then it shatters into
-- angular crystal shards with a small white-cyan ring puff. One pooled head per hit (up to 3 a second).
----------------------------------------------------------------------------------------------------
local SNAP = { Close = 0.06, Hold = 0.04, Back = 0.15 }
local snapPool = {}
function DFX.HitBloom(hit, dir, thin)
	if not (FD and FD.Built and FD.Kind("WyrmHead")) then return end
	local pos = (typeof(hit) == "Vector3") and hit or hit.Position          -- (CryoFX hands over the raycast result)
	dir = (dir and dir.Magnitude > 1e-3) and dir.Unit or Vector3.zAxis
	local s = table.remove(snapPool)
	if not s then s = { Head = FD.New("WyrmHead"), Jaw = FD.New("WyrmJaw") } end
	local folder = H.fxFolder()
	FD.Parent(s.Head, folder)
	FD.Parent(s.Jaw, folder)
	FD.Fade(s.Head, 0)
	FD.Fade(s.Jaw, 0)
	local up = (math.abs(dir.Y) < 0.95) and Vector3.yAxis or Vector3.zAxis
	local cf = CFrame.fromMatrix(pos - dir * SNAP.Back, up:Cross(dir).Unit, dir)
	local hinge = FD.Wyrm.Hinge
	local t0, cracked, broke = os.clock(), false, false
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		local u = math.clamp(t / SNAP.Close, 0, 1)
		local jaw = cf * CFrame.new(hinge) * CFrame.Angles(FD.Wyrm.Close * u * u, 0, 0) * CFrame.new(-hinge)
		if u >= 1 and not cracked then
			cracked = true
			H.burst(pos, -dir, { Glints = 4 }, nil, 1)                  -- the crack: a flash on the teeth
			-- (2026-10-19, audit P5A-09) no second flash on top of the Default's impact flash under Reduce Flashing
			if not (H.Settings.Get and H.Settings.Get("ReduceFlashing")) then pcall(H.flashAt, pos, 2.5, 8, 0.12) end
		end
		if t >= SNAP.Close + SNAP.Hold and not broke then
			broke = true
			FD.Parent(s.Head, nil)
			FD.Parent(s.Jaw, nil)
			if #snapPool < 4 then snapPool[#snapPool + 1] = s else FD.Drop(s.Head) FD.Drop(s.Jaw) end
			-- the shatter: angular shards out and back, a small white-cyan ring puff facing the shot
			local side = up:Cross(dir).Unit
			for k = 1, thin and 3 or 8 do
				local a = 2 * math.pi * k / 5 + rng:NextNumber(-0.3, 0.3)
				local out = (side * math.cos(a) + up * math.sin(a)) * rng:NextNumber(4, 7) - dir * rng:NextNumber(2, 4)
				pcall(H.throw, (k % 2 == 1) and "CK_IS_Splinter_1" or "CK_Chunk_2",
					CFrame.new(pos - dir * 0.3) * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), 0), out,
					Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 14, rng:NextNumber(0.35, 0.55),
					Vector3.one * rng:NextNumber(0.22, 0.4), pos.Y - 30, (k % 2 == 1) and "DragonGlow" or "DragonShard")
			end
			pcall(H.ripple, CFrame.fromMatrix(pos - dir * 0.2, side, -dir), 0.3, 3.4, 0.22, 0.05)
			pcall(H.ripple, CFrame.fromMatrix(pos - dir * 0.25, side, -dir), 0.2, 1.8, 0.16, 0)
			return false
		end
		FD.Place(s.Head, cf, parts, cframes)
		FD.Place(s.Jaw, jaw, parts, cframes)
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- FLASH FREEZE (stage 2): the CLAW SLAM (VFXLibrary.CastFlashFreeze -> CryoFX.LotusField -> Field). A dragon claw drops
-- onto the zone's origin on the cast beat (leadIn) and holds there, sinking, while a ring of tall crystal SPINES (a spine
-- ridge) rises round the rim across the expand time, leaning out; puffs of glowing snow rise behind the front. On the
-- rim's wave (breakTime) the spines shatter outward as spinning shards. Ring only: nothing over a rooted target. The
-- floor, the Frost Line and the rooted body's freeze stay the Default's.
----------------------------------------------------------------------------------------------------
-- FLASH FREEZE, pass 4 (2026-10-16): the dragon's own forefoot (FrostDragonData "claw", built at R = 10 in the Stage 1
-- style) scaled so its talon tips land on the zone's rim. Times after the cast (leadIn = the Default's trigger):
--   telegraph   0 .. leadIn: the claw's faint frost shadow on the zone
--   drop        leadIn - CLAW.Drop .. leadIn: the claw falls out of the sky, fast
--   impact      leadIn: the talons flash (soft under Reduce Flashing), a white-hot shockwave sweeps centre -> rim in
--               CLAW.Wave s; each player it passes is frosted over (FROSTOVER, cosmetic: the server still roots after
--               LingerToRoot); the spikes erupt as a ripple behind it
--   exit        leadIn + CLAW.Hold: the claw shatters into scale chips and mist
local CLAW = { Drop = 0.16, From = 40, Wave = 0.15, Base = 10 }
local FROSTOVER = true                -- (flagged: a cosmetic frost-over at the shockwave, ahead of the real root)
local SPINES = { [1] = 22, [2] = 16, [3] = 10 }

-- (2026-10-19, audit P5A-04) the frost-over goes (its 0.3 s shrink) as soon as the body leaves the spot it was frosted
-- on, or when the server's root (IceFrozenState) has not come by LingerToRoot + a grace: a body that walked out, or one
-- the server never roots, no longer wears a fake freeze. Thinned (`thin`): 7 spines, not 14 (audit P5A-12).
local function frostOver(model, folder, dens, life, thin)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + (hum and hum.HipHeight or 2), 0)
	local plant = root.Position
	local FFT = H.VFXLibrary.Tuning and H.VFXLibrary.Tuning.FlashFreeze
	local grace = ((FFT and FFT.LingerToRoot) or 1) + 0.4
	local list = {}
	local n = thin and 7 or 14
	for q = 1, n do
		local a = 2 * math.pi * q / n + rng:NextNumber(-0.15, 0.15)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local hi = (q % 3 == 0)
		local o = FD.New("Spine", folder)
		if o then
			FD.Fade(o, 0)
			local base = feet + out * (hi and 0.75 or 0.95) + Vector3.new(0, hi and 2.2 or 0, 0)
			list[#list + 1] = { O = o, K = CFrame.fromMatrix(base, out:Cross(Vector3.yAxis), Vector3.yAxis) * CFrame.Angles(math.rad(14), 0, 0),
				S = hi and 0.3 or rng:NextNumber(0.36, 0.5) }
		end
	end
	H.burst(feet + Vector3.new(0, 1.2, 0), Vector3.yAxis, { Powder = 3 }, dens, 0.6)
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		if life > t then
			local r = model.Parent and model:FindFirstChild("HumanoidRootPart")
			if not r or H.flat(r.Position - plant).Magnitude > 1.5 or (t > grace and not model:FindFirstChild("IceFrozenState")) then
				life = t
			end
		end
		local grow = H.easeOut(math.clamp(t / 0.12, 0, 1)) * (1 - H.smooth(math.clamp((t - life) / 0.3, 0, 1)))
		if t > life + 0.3 or not folder.Parent then
			for _, c in ipairs(list) do FD.Drop(c.O) end
			return false
		end
		for _, c in ipairs(list) do FD.Place(c.O, c.K, parts, cframes, math.max(0.01, c.S * grow)) end
		return true
	end)
end

function DFX.Field(ground, R, leadIn, expand, breakTime, wave, caster)
	if not (FD and FD.Built and FD.Kind("claw") and FD.Kind("Spine")) then return end
	local folder = Instance.new("Folder")
	folder.Name = "FrostDragonField"
	folder.Parent = H.fxFolder()
	local c = ground.Position
	local dens = H.density(caster)
	local calm = H.Settings.Get and H.Settings.Get("ReduceFlashing")
	local tier = FD.Tier(dens, false)
	local croot = typeof(caster) == "Instance" and caster:FindFirstChild("HumanoidRootPart")
	local fwd = croot and H.flat(croot.CFrame.LookVector) or Vector3.zAxis
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
	local s = R / CLAW.Base
	local clawK = CFrame.fromMatrix(c, fwd, Vector3.yAxis)          -- (its toes forward, the forearm rising behind)
	local claw = FD.New("claw", folder)
	local shadow = FD.New("claw", folder)
	if claw then
		FD.Fade(claw, 1)
		-- (the claw is one mesh per material, so a per-part proximity fade would fade it for every camera near the zone; it is
		-- drawn 60% clear instead -- 2026-10-19, audit P5A-03: on EVERY client, not the caster's alone, so the trapped zone
		-- reads the same to the wearer, their opponents and teammates)
		for _, p in ipairs(claw.Parts) do p.Part.LocalTransparencyModifier = 0.6 end
	end
	if shadow then FD.Fade(shadow, 1) end
	-- the spikes: a rim ring and (above the low tier) an inner ring, erupting behind the shockwave
	local spines = {}
	local function ring(n, r, size, at0, at1)
		for i = 1, n do
			local a = 2 * math.pi * (i - 1) / n + rng:NextNumber(-0.06, 0.06)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local o = FD.New("Spine", folder)
			if o then
				FD.Fade(o, 1)
				local tall = ((i % 2 == 1) and rng:NextNumber(1.35, 1.6) or rng:NextNumber(0.85, 1.1)) * size
				local K = CFrame.fromMatrix(c + out * r, out:Cross(Vector3.yAxis), Vector3.yAxis) * CFrame.Angles(-math.rad(rng:NextNumber(10, 20)), 0, 0)
				spines[#spines + 1] = { O = o, K = K, S = tall, Out = out, Rise = at0 + (at1 - at0) * rng:NextNumber(0, 1) }
			end
		end
	end
	-- (2026-10-19, audit P5A-22) the spines' feet on the zone's edge (the Frost Line), not 1.6 studs outside it: the solid
	-- ring reads as where the root ends (they lean out above it)
	ring(SPINES[tier] or 16, R, 1, leadIn + CLAW.Wave + 0.02, leadIn + CLAW.Wave + 0.22)
	-- who stands in the zone (players, and Studio dummies), for the frost-over
	-- (2026-10-19, audit P5A-04) only a body the caster may hurt (Config.MayHurt): never a teammate, or anyone in the Hub
	local inside = {}
	if FROSTOVER then
		local okC, Config = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
		end)
		local cp = typeof(caster) == "Instance" and Players:GetPlayerFromCharacter(caster) or nil
		for _, m in ipairs(workspace:GetChildren()) do
			local r = m:IsA("Model") and m ~= caster and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart")
			local vp = r and Players:GetPlayerFromCharacter(m)
			if r and cp and vp and okC and type(Config.MayHurt) == "function" then
				local ok, may = pcall(Config.MayHurt, cp, vp)
				if ok and may == false then r = nil end
			end
			if r then
				local d = H.flat(r.Position - c).Magnitude
				if d <= R then inside[#inside + 1] = { M = m, At = leadIn + CLAW.Wave * d / R } end
			end
		end
	end
	local t0 = os.clock()
	local slammed, gone, shattered = false, false, false
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		if not folder.Parent then return false end
		-- the telegraph: the claw's faint frost shadow
		if shadow then
			if t < leadIn then
				FD.Fade(shadow, 1 - 0.2 * math.clamp(t / math.max(leadIn - 0.05, 0.1), 0, 1))
				FD.Place(shadow, clawK + Vector3.new(0, 0.05, 0), parts, cframes, Vector3.new(s, 0.02, s))
			else
				FD.Drop(shadow)
				shadow = nil
			end
		end
		-- the claw: out of the sky in CLAW.Drop s, lands on the trigger frame, shatters CLAW.Hold s later
		if claw and not gone then
			local u = math.clamp((t - (leadIn - CLAW.Drop)) / CLAW.Drop, 0, 1)
			if u > 0 then
				FD.Fade(claw, 0)
				FD.Place(claw, clawK + Vector3.new(0, CLAW.From * (1 - u * u), 0), parts, cframes, s)
				if rng:NextNumber() < 0.3 then                             -- the forearm rising into mist
					H.burst(clawK * Vector3.new(-3.6 * s, 15.5 * s + CLAW.From * (1 - u * u), 0), Vector3.yAxis, { Powder = 1 }, dens, 0.6)
				end
			end
			if u >= 1 and not slammed then
				slammed = true
				if not calm then pcall(H.flashAt, c + Vector3.new(0, 2, 0), 2.5, R, 0.2) end
				pcall(H.ripple, CFrame.new(c + Vector3.new(0, 0.08, 0)), 0.8, R * 1.02, CLAW.Wave, calm and 0.5 or 0.05)   -- the shockwave
				pcall(H.ripple, CFrame.new(c + Vector3.new(0, 0.1, 0)), 0.6, R * 0.9, 0.45, calm and 0.6 or 0.25)
				for q = 0, 4 do                                              -- the talons strike: white-hot glints, chips
					local a = ({ -66, -22, 22, 66, 180 })[q + 1]
					local d = clawK:VectorToWorldSpace(Vector3.new(math.cos(math.rad(a)), 0, -math.sin(math.rad(a))))
					H.burst(c + d * R * 0.95 + Vector3.new(0, 0.4, 0), Vector3.yAxis, { Glints = calm and 1 or 3, Chips = 3, Powder = 2 }, dens, 1.2)
				end
				H.burst(c + Vector3.new(0, 0.5, 0), Vector3.yAxis, { Powder = 5, Flakes = 8 }, dens, 1.4)
			end
			-- the hold: a slow crackle over the foot, until the zone breaks (or the caster dies)
			if slammed and rng:NextNumber() < dt * 3 then
				local a = rng:NextNumber(0, 2 * math.pi)
				H.burst(c + Vector3.new(math.cos(a), 0, math.sin(a)) * R * rng:NextNumber(0.2, 0.9) + Vector3.new(0, rng:NextNumber(1, 4), 0),
					Vector3.yAxis, { Glints = 1, Powder = 1 }, dens, 0.5)
			end
			local hum = typeof(caster) == "Instance" and caster:FindFirstChildOfClass("Humanoid")
			if slammed and (t >= breakTime + wave - 0.05 or (hum and hum.Health <= 0)) then
				gone = true
				for q = 1, (tier < 3) and 10 or 5 do
					local a = 2 * math.pi * q / 10
					local out = Vector3.new(math.cos(a), 0, math.sin(a))
					local at = c + out * R * rng:NextNumber(0.2, 0.85) + Vector3.new(0, rng:NextNumber(2, 9), 0)
					pcall(H.throw, (q % 2 == 1) and "CK_IS_Splinter_1" or "CK_Chunk_2",
						CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 6.3), 0, rng:NextNumber(0, 6.3)),
						out * rng:NextNumber(4, 8) + Vector3.new(0, rng:NextNumber(2, 5), 0),
						Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 10, rng:NextNumber(0.6, 0.9),
						Vector3.one * rng:NextNumber(0.5, 0.9), c.Y, (q % 2 == 1) and "DragonGlow" or "DragonShard")
					if q % 2 == 0 then H.burst(at, Vector3.yAxis, { Powder = 2 }, dens, 0.8) end
				end
				FD.Drop(claw)
				claw = nil
			end
		end
		-- the frost-over: each player as the shockwave reaches them (held a little past the root's own beat)
		for _, v in ipairs(inside) do
			if not v.Done and t >= v.At then
				v.Done = true
				if v.M.Parent then frostOver(v.M, folder, dens, math.max(0.5, breakTime + wave - t), H.thinFor(caster)) end
			end
		end
		-- the spikes: erupt, hold, shatter outward on the rim's wave
		if t >= breakTime + wave and not shattered then
			shattered = true
			for _, sp in ipairs(spines) do
				if sp.Up then
					local top = sp.K * Vector3.new(0, 4.6 * sp.S * 0.6, 0)
					pcall(H.throw, "CK_IS_Splinter_2", CFrame.new(top) * CFrame.Angles(rng:NextNumber(0, 6.3), 0, rng:NextNumber(0, 6.3)),
						(sp.Out * rng:NextNumber(6, 10) + Vector3.new(0, rng:NextNumber(3, 6), 0)),
						Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 12, rng:NextNumber(0.7, 1.1),
						Vector3.one * rng:NextNumber(0.35, 0.6), c.Y, "DragonGlow")
				end
				FD.Drop(sp.O)
			end
			H.burst(c + Vector3.new(0, 1, 0), Vector3.yAxis, { Flakes = 10, Powder = 4 }, dens, 1.1)
			if claw then FD.Drop(claw) end
			folder:Destroy()
			return false
		end
		for _, sp in ipairs(spines) do
			local u = math.clamp((t - sp.Rise) / 0.18, 0, 1)
			if u > 0 then
				if not sp.Up then
					sp.Up = true
					FD.Fade(sp.O, 0)
				end
				FD.Place(sp.O, sp.K + Vector3.new(0, -4.6 * sp.S * (1 - H.easeOut(u)), 0), parts, cframes, sp.S)
			end
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- BLIZZARD (stage 3, rev 3 2026-10-16): two Frost Dragons stand just outside the Frost Line, left and right of the
-- caster's view, facing in. Their bodies hold the standing pose (they fade in, hold and fade out where they stand),
-- rising and sinking as one rigid piece with the beat (BZ.Bob: up on the downstroke, down on the upstroke); the wings
-- work: opened from the model's folded rest to its full span (FrostDragonData "bzw<side>_A/B/C", hinged at the
-- shoulder, elbow and wrist) and beating slowly and hard -- BZ.Rate a second, a BZ.Stroke sweep at the shoulder, up and
-- back, then down and forward, the elbow and wrist lagging so the membrane follows. Each downbeat throws the storm off
-- the wings: crescent wind streaks and driven snow from the membrane and the tips, travelling inward along the sweep,
-- meeting in the middle and churning up into a cloud. The Default's wall keeps its rate and is cut only in a narrow
-- pocket where it would pass in front of a dragon, so both dragons stand in clear air (2026-10-19, audit P5A-05).
----------------------------------------------------------------------------------------------------
local BZ = { Rate = 1.2, Down = 0.42, Stroke = math.rad(75), Mid = math.rad(7.5), Sweep = math.rad(16), Elbow = 0.25,
	Wrist = 0.3, LagE = 0.07, LagW = 0.13, Back = math.rad(15), Elev = math.rad(5), Speed = 27, Life = 1.05, Beams = 16,
	Pocket = math.rad(15), WallKeep = 1, InnerKeep = 1, Snow = 7,   -- (2026-10-19, audit P5A-05: was 45 deg, 0.4, 0.6) Powder = 1.5, Meet = { Powder = 6, Flakes = 5 },
	Bob = 0.125, BobH = 12.97 }                       -- (the heavy hover: a share of the body's height, 12.97 studs at 1x)
local WSEG = { "A", "B", "C" }
local TIP = Vector3.new(-2.18, 1.27, -1.29)          -- the open wing's outermost point, from the wrist (R side; L mirrored)
local TRAIL = Vector3.new(-6.02, -3.63, 0.68)        -- its trailing tip
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

--- the stroke: +1 at the top, -1 at the bottom; the downstroke (the first BZ.Down of a beat) quicker than the upstroke
local function wave(p)
	p = p % 1
	if p < BZ.Down then return math.cos(math.pi * p / BZ.Down) end
	return -math.cos(math.pi * (p - BZ.Down) / (1 - BZ.Down))
end

--- the folded wing laid open: its arm (shoulder -> wrist) out to the side, BZ.Back swept back and BZ.Elev up, the
--- membrane's top face (inward-facing while folded) turned up. `sg` +1 for the R wing (-Z), -1 for the L
local function spreadRot(S, W, sg)
	local d0 = (W - S).Unit
	local n0 = Vector3.new(-0.19, 0.49, 0.85 * sg)
	n0 = (n0 - d0 * n0:Dot(d0)).Unit
	local d1 = Vector3.new(-math.sin(BZ.Back) * math.cos(BZ.Elev), math.sin(BZ.Elev), -sg * math.cos(BZ.Back) * math.cos(BZ.Elev)).Unit
	local n1 = (Vector3.yAxis - d1 * d1.Y).Unit
	return CFrame.fromMatrix(Vector3.zero, d1, n1, d1:Cross(n1)) * CFrame.fromMatrix(Vector3.zero, d0, n0, d0:Cross(n0)):Inverse()
end

function DFX.Storm(s, c, R, form, caster)
	if not (FD and FD.Built and FD.Kind("bzbody") and FD.Kind("bzwR_A")) then return end
	local root = caster and caster:FindFirstChild("HumanoidRootPart")
	local look = root and H.flat(root.CFrame.LookVector) or Vector3.zAxis
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
	local side = look:Cross(Vector3.yAxis).Unit
	local sc = math.clamp(R / 36, 0.5, 1.4)
	local dens = H.density(caster)
	local open = math.max(form, 0.4)
	local NS, NK, NR = NumberSequence.new, NumberSequenceKeypoint.new, NumberRange.new
	local bp = FD.Kind("bzbody").Pivot
	-- each wing's hinges in the body's frame (its pivot at the feet, +X the nose, +Y up), unscaled
	local J = {}
	for _, sd in ipairs({ "R", "L" }) do
		local a, b, w = FD.Kind("bzw" .. sd .. "_A").Pivot, FD.Kind("bzw" .. sd .. "_B").Pivot, FD.Kind("bzw" .. sd .. "_C").Pivot
		local sg = (sd == "R") and 1 or -1
		J[sd] = { S = a - bp, E = b - bp, W = w - bp, Sign = sg, Rs = spreadRot(a, w, sg),
			Tip = Vector3.new(TIP.X, TIP.Y, TIP.Z * sg), Trail = Vector3.new(TRAIL.X, TRAIL.Y, TRAIL.Z * sg) }
	end
	--- a wing's pose: { shoulder, its turn, elbow, its turn, wrist, its turn } in the body's frame. `sp` how far open
	--- (0 folded, 1 open); lA / lB / lC the arm's, forearm's and hand's lift (rad, about the body's long axis: + = up);
	--- `sw` the sweep (rad, + = back)
	local function wingPose(j, sp, lA, lB, lC, sw)
		local sg = j.Sign
		local rs = CFrame.new():Lerp(j.Rs, sp)
		local yaw = CFrame.Angles(0, sg * sw, 0)
		local mA = yaw * CFrame.Angles(sg * lA, 0, 0) * rs
		local mB = yaw * CFrame.Angles(sg * lB, 0, 0) * rs
		local mC = CFrame.Angles(0, sg * sw * 1.3, 0) * CFrame.Angles(sg * lC, 0, 0) * rs
		local e = j.S + mA:VectorToWorldSpace(j.E - j.S)
		local w = e + mB:VectorToWorldSpace(j.W - j.E)
		return { j.S, mA, e, mB, w, mC }
	end
	local function newDragon(pos, inward, folder)
		local d = { Body = FD.New("bzbody", folder), W = {}, K = CFrame.fromMatrix(pos, inward, Vector3.yAxis), In = inward,
			Pose = {}, Ref = {} }
		FD.Fade(d.Body, 1)
		for _, sd in ipairs({ "R", "L" }) do
			d.W[sd] = {}
			for i, g in ipairs(WSEG) do
				d.W[sd][i] = FD.New("bzw" .. sd .. "_" .. g, folder)
				FD.Fade(d.W[sd][i], 1)
			end
		end
		return d
	end
	local function placeWings(d, K, poses, fade, parts, cframes, ss)
		for _, sd in ipairs({ "R", "L" }) do
			local pose = poses[sd]
			for i = 1, 3 do
				FD.Fade(d.W[sd][i], fade)
				FD.Place(d.W[sd][i], K * CFrame.new(pose[2 * i - 1] * ss) * pose[2 * i], parts, cframes, ss)
			end
		end
	end
	-- (Studio only: a still, folded copy for the model-overlay check, when the test asks for one)
	local RunService = game:GetService("RunService")
	local pt = RunService:IsStudio() and workspace:GetAttribute("FDPoseTest")
	if typeof(pt) == "Vector3" then
		local still = newDragon(pt, Vector3.xAxis, s.Folder)
		local parts, cframes = {}, {}
		FD.Fade(still.Body, 0)
		FD.Place(still.Body, still.K, parts, cframes, 1)
		placeWings(still, still.K, { R = wingPose(J.R, 0, 0, 0, 0, 0), L = wingPose(J.L, 0, 0, 0, 0, 0) }, 0, parts, cframes, 1)
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- the Default's wall cut out only where it would stream in front of a dragon (a narrow pocket of clear air round each,
	-- BZ.Pocket); its inside snow shortened so none drifts out over a dragon; its sweeping gust lines off (the wings make
	-- the wind now). (2026-10-19, audit P5A-05) the wall used to be thinned to 40% and cut over half the ring, so the
	-- zone hid far less than the Default's: the manual's "a skin never changes effect intensity" (655). The rest of the
	-- wall now keeps the Default's rate, so DragonLive (Folder attributes, for the test) runs above DefaultLive.
	local before, after = 0, 0
	for _, b in ipairs(s.Folder:GetDescendants()) do
		if b:IsA("Beam") then b.Enabled = false end
	end
	for _, em in ipairs(s.Emitters or {}) do
		before += em.Rate * em.Life
		local hp = em.E.Parent
		local at = hp and hp:IsA("BasePart") and H.flat(hp.Position - c)
		if at and at.Magnitude > R * 0.55 then
			local cut = at.Unit:Dot(side) > math.cos(BZ.Pocket) or at.Unit:Dot(-side) > math.cos(BZ.Pocket)
			em.Rate *= cut and 0 or BZ.WallKeep
		elseif at then
			em.Rate *= BZ.InnerKeep
			em.E.Lifetime = NR(math.min(em.E.Lifetime.Min, 1.0), math.min(em.E.Lifetime.Max, 1.4))
			em.Life = math.min(em.Life, 1.2)
		end
		after += em.Rate * em.Life
	end
	local perBeat = 4 * 3 * (BZ.Snow * BZ.Life + BZ.Powder * 1.4) + BZ.Meet.Powder * 1.25 + BZ.Meet.Flakes * 1.4
	s.Folder:SetAttribute("DefaultLive", math.floor(before + 0.5))
	s.Folder:SetAttribute("DragonLive", math.floor(after + perBeat * BZ.Rate * dens + 0.5))

	local pair = {}
	for k, sg in ipairs({ 1, -1 }) do
		local pos = c + side * sg * (R + 3)
		pair[k] = newDragon(Vector3.new(pos.X, c.Y, pos.Z), -side * sg, s.Folder)
	end
	local hostP = H.host(CFrame.new(c), s.Folder)
	-- the wings' own emitters (Emit only, the counts through `dens`): driven snow streaks and a little soft powder,
	-- one pair per wing on an attachment moved to each point of the membrane it throws from
	local SHARD = (H.VFXLibrary and H.VFXLibrary.Config and H.VFXLibrary.Config.Textures and H.VFXLibrary.Config.Textures.Shard) or SPARK
	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.Rate, e.Enabled = 0, false
		e.EmissionDirection = Enum.NormalId.Top
		for k, v in pairs(props) do e[k] = v end
		e.Parent = parent
		return e
	end
	for _, d in ipairs(pair) do
		d.Att, d.Snow, d.Pow = {}, {}, {}
		for _, sd in ipairs({ "R", "L" }) do
			local a = Instance.new("Attachment")
			a.Parent = hostP
			d.Att[sd] = a
			d.Snow[sd] = emitter(a, { Texture = SHARD, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NS(1.8),
				Color = ColorSequence.new(Color3.fromHex("#F2FBFF"), Color3.fromHex("#CFEFFF")), LightEmission = 0.5, LightInfluence = 0.3,
				Size = NS({ NK(0, 0.34), NK(1, 0.14) }), Transparency = NS({ NK(0, 0.15), NK(0.75, 0.35), NK(1, 1) }),
				Lifetime = NR(0.9, 1.2), Speed = NR(24, 31), Drag = 0.5, SpreadAngle = Vector2.new(10, 18),
				Acceleration = Vector3.new(0, -2, 0) })
			d.Pow[sd] = emitter(a, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#EAF6FD")), LightEmission = 0.05,
				LightInfluence = 1, Size = NS({ NK(0, 0.8), NK(1, 3.0) }), Transparency = NS({ NK(0, 0.55), NK(0.4, 0.62), NK(1, 1) }),
				Lifetime = NR(1.2, 1.6), Speed = NR(16, 22), Drag = 1.4, SpreadAngle = Vector2.new(20, 20),
				RotSpeed = NR(-60, 60), Rotation = NR(0, 360), Acceleration = Vector3.new(0, 0.8, 0) })
		end
	end
	-- the crescent wind streaks: a pool of curved ribbons standing up, bowed along their flight, growing as they go
	local beams = {}
	for i = 1, BZ.Beams do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = hostP, hostP
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera, b.Segments = true, 12
		b.Width0, b.Width1 = 0.9 * sc, 0.9 * sc
		b.Color = ColorSequence.new(Color3.fromHex("#EEF9FF"))
		b.LightEmission, b.LightInfluence = 0.7, 0.15
		b.Transparency = NS(1)
		b.Enabled = false
		b.Parent = hostP
		beams[i] = { B = b, A0 = a0, A1 = a1, T0 = -1 }
	end
	local function aim(pos, dir)
		return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	local function streak(p0, v, g, age)
		for _, bm in ipairs(beams) do
			if bm.T0 < 0 then
				bm.T0, bm.P0, bm.V, bm.G = age, p0, v, g
				bm.L = (Vector3.yAxis - v.Unit * v.Unit.Y).Unit          -- (a standing wavefront: it reads from every side)
				bm.B.Enabled = true
				return
			end
		end
	end
	local into = c + Vector3.new(0, 2.5, 0)
	--- a downbeat's gust off one dragon: from the inner wing, the outermost point and the trailing tip of each wing
	local function gust(d, g, age)
		for _, sd in ipairs({ "R", "L" }) do
			local j, pose = J[sd], d.Pose[sd]
			local pts = { pose[3], pose[5] + pose[6]:VectorToWorldSpace(j.Tip), pose[5] + pose[6]:VectorToWorldSpace(j.Trail) }
			for k, lp in ipairs(pts) do
				local wp = d.Kb:PointToWorldSpace(lp * sc)
				local dir = ((into - wp).Unit * 0.65 + d.In * 0.35).Unit
				d.Att[sd].WorldCFrame = aim(wp + dir * 0.6, dir)
				local n = math.floor(BZ.Snow * g * dens + 0.5)
				if n > 0 then d.Snow[sd]:Emit(n) end
				local m = (k > 1) and math.floor(BZ.Powder * g * dens + 0.5) or 0
				if m > 0 then d.Pow[sd]:Emit(m) end
				streak(wp + dir * 0.8, dir * BZ.Speed * rng:NextNumber(0.92, 1.08), g, age)
			end
		end
	end

	local ph, lastGust, misted, faded = 0, -1, false, false
	local meets = {}
	local stats = { Move = 0, Turn = 0, LoY = 0, HiY = 0, LoA = 1e9, HiA = -1e9, LoTip = 1e9, HiTip = -1e9 }
	H.run(function(now, dt, parts, cframes)
		if not s.Folder.Parent then return false end
		local age = H.serverNow() - s.T0
		if age < 0 then return true end
		local thinAt = s.Ended and s.EndAge or (s.Duration - 1.8)
		local sp = H.easeOut(math.clamp(age / open, 0, 1))
		local settle = H.smooth(math.clamp((age - thinAt) / 1.4, 0, 1))
		local fade = math.clamp(1 - H.smooth(math.clamp(age / open, 0, 1)) + settle, 0, 1)
		if not misted then                                             -- they condense out of a breath of frost (no roar)
			misted = true
			for _, d in ipairs(pair) do H.burst(d.K.Position + Vector3.new(0, 0.4, 0), Vector3.yAxis, { Powder = 3 }, dens, 0.6) end
		end
		if settle >= 1 then
			for _, d in ipairs(pair) do
				FD.Drop(d.Body)
				for _, sd in ipairs({ "R", "L" }) do for _, o in ipairs(d.W[sd]) do FD.Drop(o) end end
			end
			for _, bm in ipairs(beams) do bm.B.Enabled = false end
			s.Folder:SetAttribute("BodyMove", stats.Move)
			s.Folder:SetAttribute("BodyTurn", stats.Turn)
			return false
		end
		-- the beat: full, slow strokes once open; slowing and shallowing as the storm clears
		if age >= open then ph += dt * BZ.Rate * (1 - 0.6 * settle) end
		local amp = (1 - 0.6 * settle) * BZ.Stroke / 2
		local u = (age < open) and 1 or wave(ph)
		local uE = (age < open) and 1 or wave(ph - BZ.LagE)
		local uW = (age < open) and 1 or wave(ph - BZ.LagW)
		local lA = sp * (BZ.Mid + amp * u)
		local lB = sp * (BZ.Mid + amp * (1 + BZ.Elbow) * uE)
		local lC = sp * (BZ.Mid + amp * (1 + BZ.Elbow + BZ.Wrist) * uW)
		local sw = sp * BZ.Sweep * u * (1 - 0.6 * settle)
		-- the bob: the whole dragon lifts as the wings drive down and settles back as they rise (0 = standing height)
		local bob = sp * BZ.Bob * BZ.BobH * sc * (1 - u) / 2 * (1 - 0.6 * settle)
		for _, d in ipairs(pair) do
			-- the body: the standing pose, only lifted by the bob (and faded); measured, for the test
			local n0 = #parts
			d.Kb = d.K + Vector3.new(0, bob, 0)
			FD.Fade(d.Body, fade)
			FD.Place(d.Body, d.Kb, parts, cframes, sc)
			for i = n0 + 1, #parts do
				local ref = d.Ref[i - n0]
				if not ref then d.Ref[i - n0] = cframes[i] else
					local dp = cframes[i].Position - ref.Position
					local _, ang = (ref.Rotation:Inverse() * cframes[i].Rotation):ToAxisAngle()
					stats.Move = math.max(stats.Move, Vector2.new(dp.X, dp.Z).Magnitude)
					stats.Turn = math.max(stats.Turn, math.deg(math.abs(ang)))
					stats.LoY, stats.HiY = math.min(stats.LoY, dp.Y), math.max(stats.HiY, dp.Y)
				end
			end
			d.Pose.R = wingPose(J.R, sp, lA, lB, lC, sw)
			d.Pose.L = wingPose(J.L, sp, lA, lB, lC, sw)
			placeWings(d, d.Kb, d.Pose, fade, parts, cframes, sc)
		end
		if age >= open and settle <= 0 then
			stats.LoA, stats.HiA = math.min(stats.LoA, math.deg(lA)), math.max(stats.HiA, math.deg(lA))
			local tip = pair[1].K:PointToWorldSpace((pair[1].Pose.R[5] + pair[1].Pose.R[6]:VectorToWorldSpace(J.R.Tip)) * sc)
			stats.LoTip, stats.HiTip = math.min(stats.LoTip, tip.Y), math.max(stats.HiTip, tip.Y)
			s.Folder:SetAttribute("Stroke", math.floor(stats.HiA - stats.LoA + 0.5))
			s.Folder:SetAttribute("TipTravel", math.floor((stats.HiTip - stats.LoTip) * 10 + 0.5) / 10)
			s.Folder:SetAttribute("BodyMove", stats.Move)
			s.Folder:SetAttribute("BodyTurn", stats.Turn)
			s.Folder:SetAttribute("Bob", stats.HiY - stats.LoY)
		end
		-- each downbeat (mid-stroke, the wing at its fastest): the gust, building over the first second of beats
		local gi = math.floor(ph - BZ.Down / 2)
		if age >= open and gi ~= lastGust then
			lastGust = gi
			local g = math.clamp(0.35 + 0.65 * (age - open), 0, 1) * (1 - math.clamp(settle * 1.6, 0, 1))
			if g > 0.05 then
				for _, d in ipairs(pair) do gust(d, g, age) end
				meets[#meets + 1] = { At = age + (R + 3) / BZ.Speed * 0.95, G = g }
			end
		end
		-- the streaks in flight
		for _, bm in ipairs(beams) do
			if bm.T0 >= 0 then
				local t = age - bm.T0
				if t >= BZ.Life or t < 0 then
					bm.T0 = -1
					bm.B.Enabled = false
				else
					local ctr = bm.P0 + bm.V * t
					local hl = (1.6 + 2.0 * t / BZ.Life) * sc
					local vx = bm.V.Unit
					local vy = (Vector3.yAxis - vx * vx.Y).Unit
					bm.A0.WorldCFrame = CFrame.fromMatrix(ctr - bm.L * hl, vx, vy)
					bm.A1.WorldCFrame = CFrame.fromMatrix(ctr + bm.L * hl, vx, vy)
					bm.B.CurveSize0, bm.B.CurveSize1 = hl * 0.7, -hl * 0.7
					local e = math.sin(math.pi * t / BZ.Life) * bm.G            -- (smooth in and out: no strobing)
					bm.B.Transparency = NS({ NK(0, 1), NK(0.2, 1 - 0.7 * e), NK(0.5, 1 - 0.85 * e), NK(0.8, 1 - 0.7 * e), NK(1, 1) })
				end
			end
		end
		-- where the two gusts meet: the snow churns up into a cloud in the middle
		for i = #meets, 1, -1 do
			if age >= meets[i].At then
				local g = meets[i].G
				table.remove(meets, i)
				for q = -1, 1, 2 do
					H.burst(c + look * (2 * q) + Vector3.new(0, 1.6, 0), Vector3.yAxis,
						{ Powder = BZ.Meet.Powder * g / 2, Flakes = BZ.Meet.Flakes * g / 2 }, dens, 1.3)
				end
			end
		end
		-- as they fade the wings shed a little frost
		if not faded and settle > 0.5 then
			faded = true
			for _, d in ipairs(pair) do
				for _, sd in ipairs({ "R", "L" }) do
					local tip = d.Kb:PointToWorldSpace((d.Pose[sd][5] + d.Pose[sd][6]:VectorToWorldSpace(J[sd].Tip)) * sc)
					H.burst(tip, Vector3.yAxis, { Flakes = 3 }, dens, 0.6)
				end
			end
		end
		return true
	end)
end

--- the wall's flecks: pale white-cyan glitter (the Default's motion kept)
function DFX.StormFleck(props)
	props.Color = ColorSequence.new(Color3.fromHex("#F2FBFF"), Color3.fromHex("#BFE6FF"))
	props.LightEmission = 0.6
	props.LightInfluence = 0.3
end

----------------------------------------------------------------------------------------------------
-- COLD MOMENTUM (stage 3): on the Default's print (its frame: +Y the ground's normal), a frosted claw print fading with
-- it, and two scale chips dropping beside it, tumbling and fading. Low count, pooled.
----------------------------------------------------------------------------------------------------
local printPool, chipPool = {}, {}
function DFX.Print(cf, PR, thin)
	if not (FD and FD.Built and FD.Kind("Print") and FD.Kind("Plate")) then return end
	local folder = H.fxFolder()
	local o = table.remove(printPool) or FD.New("Print")
	if not o then return end
	FD.Parent(o, folder)
	FD.Fade(o, 0)
	local K = cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
	local chips = {}
	for q = 1, (thin and 0 or 2) do                          -- (2026-10-19, audit P5A-12) thinned: the print only
		local ch = table.remove(chipPool) or FD.New("Plate")
		if ch then
			FD.Parent(ch, folder)
			FD.Fade(ch, 0)
			FD.PlateGlow(ch, 0)
			local side = cf.RightVector * (q == 1 and 0.5 or -0.5)
			chips[#chips + 1] = { O = ch, P = cf.Position + side + cf.UpVector * rng:NextNumber(1.0, 1.5),
				Spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)) }
		end
	end
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local age = now - t0
		if age >= PR.Life then
			FD.Fade(o, 1)
			FD.Parent(o, nil)
			if #printPool < 8 then table.insert(printPool, o) else FD.Drop(o) end
			for _, ch in ipairs(chips) do
				FD.Parent(ch.O, nil)
				if #chipPool < 12 then table.insert(chipPool, ch.O) else FD.Drop(ch.O) end
			end
			return false
		end
		local k = (age < PR.Pop) and (0.6 + 0.4 * H.easeOut(age / PR.Pop)) or 1
		FD.Fade(o, H.smooth((age - PR.Hold) / (PR.Life - PR.Hold)))
		FD.Place(o, K, parts, cframes, 0.62 * k)
		for _, ch in ipairs(chips) do
			local f = math.clamp(age / 0.45, 0, 1)
			local p = ch.P - cf.UpVector * ((ch.P - cf.Position):Dot(cf.UpVector) - 0.05) * f * f
			FD.Fade(ch.O, (age > PR.Life * 0.7) and 1 or 0)
			FD.Place(ch.O, CFrame.new(p) * CFrame.Angles(ch.Spin.X * age * (1 - f * 0.8), ch.Spin.Y * age, ch.Spin.Z * age * (1 - f * 0.8)),
				parts, cframes, Vector3.new(0.32, 0.12, 0.24))
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- DEEP FREEZE (stage 4): the dragon's frost breath wraps the victim in crystal scales -- the Plate (a hexagonal crystal)
-- flattened into a scale, laid over the body pointing down like a dragon's, glassy and see-through so who is inside and
-- the Default's frozen-body colour still read; a wave from the feet up, riding the body parts. CryoFX's encase draws them
-- (o.FB "DragonDF") through this adapter, which speaks its kit language (Tier / New / Fade / Place / Drop / Kind /
-- ShatterChunks); the break is the Default's chunks and ripple. Never on the victim's own client (CryoFX skips it there).
----------------------------------------------------------------------------------------------------
local EK = { ScaleCount = { 34, 24, 14 }, ShatterChunks = { 8, 6, 4 }, ScaleT = 0.42, Size = 1.55 }
DFX.EncaseKit = EK
function EK.Tier(density, thin) return FD.Tier(density, thin) end
function EK.New(kind, parent)
	local o = FD.New(kind, parent)
	if o then
		for _, p in ipairs(o.Parts) do
			if p.Group == "PlateBody" then p.Base = EK.ScaleT end      -- (see-through: the body inside reads)
		end
	end
	return o
end
function EK.Fade(o, f) FD.Fade(o, f) end
function EK.Place(o, cf, parts, cframes, s) FD.Place(o, cf, parts, cframes, s) end
function EK.Drop(o) FD.Drop(o) end
function EK.Kind() return nil end
--- the scales: spread over the body's upright faces by area, each on its part (so they move with it), pointing down
--- and lifted at the tip; plus the breath that lays them on, from the caster's side
function EK.Scales(model, at, tier, caster)
	local spots, list, area = {}, {}, 0
	local feet, top = math.huge, -math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 and not p:FindFirstAncestorWhichIsA("Accessory") then
			local s = p.Size
			area += 2 * (s.X + s.Z) * s.Y
			list[#list + 1] = { P = p, A = area }
			feet = math.min(feet, p.Position.Y - s.Y / 2)
			top = math.max(top, p.Position.Y + s.Y / 2)
		end
	end
	if #list == 0 then return spots end
	local AX = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	for _ = 1, EK.ScaleCount[tier] or 12 do
		local r, e = rng:NextNumber(0, area), list[#list]
		for _, q in ipairs(list) do if r <= q.A then e = q break end end
		local p, s = e.P, e.P.Size
		local face = rng:NextInteger(1, 4)
		local nL = AX[face]
		local half, wide = (face <= 2) and s.X / 2 or s.Z / 2, (face <= 2) and s.Z or s.X
		local loc = nL * (half + 0.1) + Vector3.new(0, rng:NextNumber(-0.42, 0.42) * s.Y, 0)
			+ nL:Cross(Vector3.yAxis) * rng:NextNumber(-0.4, 0.4) * wide
		local Y = -Vector3.yAxis
		local rel = CFrame.fromMatrix(loc, Y:Cross(nL), Y, nL) * CFrame.Angles(-0.3, 0, rng:NextNumber(-0.25, 0.25))
		local h = math.clamp((p.Position.Y + loc.Y - feet) / math.max(1, top - feet), 0, 1)
		spots[#spots + 1] = { Kind = "Plate", Part = p, Rel = rel, K = p.CFrame * rel, Grow = true,
			S = Vector3.new(1.3, 1.0, 0.36) * EK.Size * rng:NextNumber(0.85, 1.2), Delay = 0.05 + 0.35 * h, Dur = 0.2 }
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local from = caster and caster:FindFirstChild("HumanoidRootPart")
	local dir = (root and from) and H.flat(root.Position - from.Position) or Vector3.zero
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.zAxis
	if root then H.burst(root.Position - dir * 1.5, dir, { Breath = 8, Powder = 3 }, H.density(caster), 1.2) end
	return spots
end

function DFX.CageDrop(cage)
	local L = cage.Dragon
	cage.Dragon, cage.Blooms = nil, nil
	if not L then return end
	for _, pc in ipairs(L.List) do FD.Drop(pc.O) end
	for _, p in ipairs(L.Plates) do
		if not p.Gone then FD.Drop(p.O) p.Gone = true end
	end
	L.List, L.Plates = {}, {}
end

--- the kit let go of its meshes (2026-10-19, MeshBudget): every pooled piece here goes with it
function DFX._release()
	for _, s in ipairs(snapPool) do FD.Drop(s.Head) FD.Drop(s.Jaw) end
	for _, o in ipairs(printPool) do FD.Drop(o) end
	for _, o in ipairs(chipPool) do FD.Drop(o) end
	table.clear(snapPool)
	table.clear(printPool)
	table.clear(chipPool)
end

return DFX
