--[[
	ScorpionFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ScorpionFX

	Toxin's SCORPION (2026-10-20; a RARE Element skin): the pieces, drawn on the Default's own beats. ToxinFX calls in
	through its skin table (BREW: Init once, then one call per hook, each pcall-wrapped there), gated on ScorpionKit.On +
	Built; until then, or on any fault, the Default draws. Every number it times itself by is read from ToxinTuning.
	THE TAIL (the one flagged avatar piece: the owner's one-off exception at Rare, not a precedent): a segmented chitin
	tail with a barbed stinger, at the lower back of every body that wears the skin, glowing only at its joint seams. It
	idles with a slow sway and bob, and it PERFORMS IN EXACTLY THREE ABILITIES -- the Ultimate (its sting: the tail's form
	at 4.2x, out of the ground behind the target), Acid Rain and the Vent -- never in the M1, the Primary or the
	Passive (the owner's cap: more would read as a performed creature, Mythic's trait). Authored motion arc, per ability:
	  M1 Toxic Bubbles        LOB, SETTLE, CRACK: a venom-glass gland (a dark barb inside) tumbles down the Default's
	                          arc, settles where it rests, and cracks open along its glowing seam -- on a hit, a
	                          conversion or its rest expiring -- spilling venom (never the Default's pop)
	  Primary Corrosive Cloud ERUPT, ETCH, SETTLE: the Default's olive miasma, chitin dust drifting through it; the ground
	                          under it etches out from the centre and bubbles while it sits, then fades (the expiry tell)
	  Passive Symbiosis       ARC AND FADE: a thin glowing venom thread arcs from the afflicted enemy to the caster's
	                          hand and dissolves from the enemy's end (the Default's strands are hidden)
	  Ultimate Patient Zero   STING AND COUNTDOWN (owner, 2026-10-21: one tail action, at the start): on the cast the
	                          tail bursts out of the ground behind the target, rears over them and lashes down, its barb
	                          hooking into their back (0.28 s) -- the hit delivers the mark: a glyph stamped on the wound
	                          hinges down and
	                          spreads into the sigil ring on the ground, which beats with the Default's gears (0.6 -> 1.8
	                          -> 4.6 Hz, timed from the cast) by scale and spin, never brightness, then draws in and holds
	                          for the fuse; the Default's mark drips from the wound. At the burst no tail: the Default's
	                          wave and cloud burst (etched and dusted like the Primary's); its flash stays out
	  Antitoxin Vent          ASSEMBLE AND HOLD: the tail curls over the shoulder (AssembleTime) and its stinger end
	                          covers the mouth for the whole Duration, breathing a faint venom vapor, then uncurls home --
	                          nothing else is worn
	  Acid Rain               RISE, FIRE, RAIN: inside the GatherTime the tail rears and fires venom pellets up into the
	                          Default's cloud over the area; they come down from it as thin barbed spines (in
	                          place of the Default's drops) on the Default's rain window, each
	                          sticking, sizzling and corroding the ground; a struck enemy shows faint glowing chitin cracks
	                          that track their Corroded stacks and fade as they lapse
	Glow is edges and seams only (the tail's joints, the gland's seam, the sigil's and cracks' lines, the thin thread).
	Particles: the BASE layer (steam, dust puffs) scales with Graphics Quality; the RARE layer ("Fleck": chitin dust,
	venom droplets, glass chips) sits on its own switch (ScorpionKit.FlecksOn) and scales the same way. No glints, motes,
	luminous cores, HUD set or kill effect: those belong to Epic and above. FX.Stats counts both layers.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FX = {}
FX.Stats = { Base = 0, Fleck = 0 }
local H, K, T = nil, nil, nil
local tails = {}                              -- [character] = the worn tail
local live = setmetatable({}, { __mode = "k" }) -- [emitter] = layer (continuous ones, integrated per frame)
local TAU = math.pi * 2
local started = false

local function now() return H.fxNow() end
local function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function easeIn(k) return k * k end
local function smooth(k) k = math.clamp(k, 0, 1) return k * k * (3 - 2 * k) end
local function backOut(k) local c = 1.7 return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2 end

-- an emitter on `parent`: the BASE layer always (scaled by Graphics Quality), the RARE "Fleck" layer only while its switch
-- is on (scaled the same way). Shapes: "Flake" (chitin), "Dot" (droplets); else the Default smoke
local function emitter(parent, layer, o)
	if layer == "Fleck" and not K.FlecksOn() then return nil end
	local e = Instance.new("ParticleEmitter")
	e.Name = "SC_" .. layer
	local tx = K.Tex()
	if tx and o.Shape and tx[o.Shape] then e.TextureContent = tx[o.Shape] else e.Texture = o.Texture or H.SMOKE end
	e.Color = ColorSequence.new(o.Color or K.Look.Dust)
	e.LightInfluence = o.LightInfluence or 1
	e.LightEmission = o.LightEmission or 0
	e.Size = o.Size or NumberSequence.new(0.2)
	e.Transparency = o.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = o.Life or NumberRange.new(0.6, 1)
	e.Speed = o.Speed or NumberRange.new(0.5, 1)
	e.SpreadAngle = o.Spread or Vector2.new(25, 25)
	e.Acceleration = o.Accel or Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = o.RotSpeed or NumberRange.new(-60, 60)
	e.EmissionDirection = o.Dir or Enum.NormalId.Top
	e.LockedToPart = o.Locked or false
	if o.Drag then e.Drag = o.Drag end
	local d = H.density()
	e.Rate = (o.Rate or 0) * d
	e:SetAttribute("Density", d)
	e:SetAttribute("Layer", layer)
	e.Parent = parent
	if e.Rate > 0 then live[e] = layer end
	return e
end
local function emit(e, n)
	if not (e and n and n > 0) then return end
	local k = math.max(1, math.floor(n * (e:GetAttribute("Density") or 1) + 0.5))
	e:Emit(k)
	local layer = e:GetAttribute("Layer") or "Base"
	FX.Stats[layer] = (FX.Stats[layer] or 0) + k
end

local function part2(props, parent)                             -- (an anchored, non-colliding piece)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or H.fxFolder()
	return p
end
local function anchoredHost(cf, parent)
	local p = part2({ Name = "SC_Host", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) }, parent)
	p.CFrame = cf
	return p
end
-- a one-shot puff at `cf`: Rare droplets/chips (Fleck) and a little Base steam
-- a puff source: one host, re-aimed before each burst, with its droplet (Rare layer) and steam (Base) emitters made on
-- first use -- a piece that puffs many times (the cloud's beads, the rain's spines) keeps two emitters, not two a puff.
-- p.At(cf, fleck, steam, spread, speed) bursts; p.Done() lets the last particles finish, then clears it.
local function puffer(color)
	local h = anchoredHost(CFrame.new())
	local fl, st
	local p = {}
	function p.At(cf, fleck, steam, spread, speed)
		h.CFrame = cf
		if fleck and fleck > 0 then
			fl = fl or emitter(h, "Fleck", { Shape = "Dot", Color = color or K.Look.Venom, LightInfluence = 0.6,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0.03) }),
				Life = NumberRange.new(0.35, 0.6), Accel = Vector3.new(0, -26, 0) })
			if fl then
				fl.Speed = speed or NumberRange.new(4, 8)
				fl.SpreadAngle = Vector2.new(spread or 55, spread or 55)
				emit(fl, fleck)
			end
		end
		if steam and steam > 0 then
			st = st or emitter(h, "Base", { Color = K.Look.Dust:Lerp(Color3.fromRGB(150, 150, 110), 0.5), LightInfluence = 0.8,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.0) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
				Life = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.8, 2), Spread = Vector2.new(30, 30) })
			emit(st, steam)
		end
	end
	function p.Done() task.delay(2, function() h:Destroy() end) end
	return p
end
local function puffAt(cf, fleck, steam, color, spread, speed)
	local p = puffer(color)
	p.At(cf, fleck, steam, spread, speed)
	p.Done()
end
-- chitin chips flung from `cf` (the Rare layer)
local function chipsAt(cf, n, speed, spread)
	local h = anchoredHost(cf)
	local e = emitter(h, "Fleck", { Shape = "Flake", Color = K.Look.Chitin:Lerp(K.Look.ChitinEdge, 0.4), LightInfluence = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.12) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(0.6, 1.0), Speed = speed or NumberRange.new(6, 12), Spread = Vector2.new(spread or 60, spread or 60),
		Accel = Vector3.new(0, -34, 0), RotSpeed = NumberRange.new(-360, 360) })
	emit(e, n)
	task.delay(2, function() h:Destroy() end)
end

-- the floor under `pos` (characters and the effects ignored; `skip` too, and then the ray starts at `pos`)
local rayParams = nil
local function groundAt(pos, skip)
	if not rayParams then
		rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	local ex = { H.fxFolder(), workspace.CurrentCamera }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then ex[#ex + 1] = plr.Character end end
	if skip then ex[#ex + 1] = skip end
	rayParams.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, skip and 0 or 6, 0), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position.Y or (pos.Y - 3)
end
-- a self-lit painted image on `host`'s `face` (its lines glow: LightInfluence 0)
local function surfaceImage(host, face, content, color, canvas, brightness)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence, sg.Brightness = 0, brightness or 1.5
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(canvas or 256, canvas or 256)
	sg.Parent = host
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency, im.Size, im.ImageContent, im.ImageColor3 = 1, UDim2.fromScale(1, 1), content, color
	im.AnchorPoint, im.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	im.Parent = sg
	return im, sg
end
local function torsoOf(c) return c and (c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")) end
local function nearCam(pos, r)
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < (r or 1.6)
end
local function setLTM(parts, v) for _, p in ipairs(parts) do p.LocalTransparencyModifier = v end end
-- a uniform Catmull-Rom curve through `P` (s 0..1, end to end)
local function catmull(P)
	local n = #P
	return function(s)
		local f = math.clamp(s, 0, 1) * (n - 1)
		local i = math.min(n - 1, math.floor(f) + 1)
		local t = f - (i - 1)
		local p0, p1, p2, p3 = P[math.max(1, i - 1)], P[i], P[i + 1], P[math.min(n, i + 2)]
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end
end

----------------------------------------------------------------------------------------------------
-- THE WORN TAIL: posed each frame as a curve through five points (the lower back to the stinger); a pose change blends
-- the old pose's points into the new one's. Poses: Idle (the arch, swaying), Vent (over the shoulder, across the mouth)
-- and Fire (reared, aimed at the sky over Acid Rain's area).
----------------------------------------------------------------------------------------------------
local function basis(r)
	local cf = r.LT.CFrame
	return cf, -cf.LookVector, cf.UpVector, cf.RightVector       -- (back, up, right)
end
local POSES = {}
function POSES.Idle(r, tau)
	local cf, back, up, right = basis(r)
	local sway = math.sin(tau * 0.9 + r.Seed) * 0.16
	local bob = math.sin(tau * 1.3 + r.Seed) * 0.07
	local hp, up2 = r.Head.Position, r.UT.Position
	return {
		r.Attach(),
		cf.Position + back * 1.35 + up * 0.15,
		up2 + back * 2.05 + up * 0.85 + right * sway * 0.5,
		hp + back * 1.45 + up * (1.45 + bob) + right * sway,
		hp + back * 0.3 + up * (1.3 + bob) + right * sway * 1.2,
	}
end
function POSES.Vent(r)
	local _, back, _, _ = basis(r)
	local hc = r.Head.CFrame
	local hp, hr, hl, hu = hc.Position, hc.RightVector, hc.LookVector, hc.UpVector
	local s = r.Head.Size.Y / 1.2
	return {
		r.Attach(),
		r.UT.Position + back * 0.95 + hr * 0.3 - hu * 0.1,
		hp + hr * 0.85 * s - hl * 0.35 * s + hu * 0.15 * s,
		hp + hr * 0.12 * s + hl * 0.7 * s - hu * 0.26 * s,        -- (the bulb lands over the mouth, against the face:
		hp - hr * 0.62 * s + hl * 0.62 * s - hu * 0.3 * s,         --  measured at about (0.05, -0.27, -0.72) in head space)
	}
end
function POSES.Fire(r, tau)
	local cf, back, up, _ = basis(r)
	local hp = r.Head.Position
	local p3 = hp + back * 0.75 + up * 2.7
	local aim = r.Aim and (r.Aim - p3) or up
	aim = aim.Magnitude > 1e-3 and aim.Unit or up
	local kick = r.FireAt and math.max(0, 1 - (now() - r.FireAt) / 0.18) or 0
	return {
		r.Attach(),
		cf.Position + back * 1.0 + up * 0.6,
		r.UT.Position + back * 1.25 + up * 2.0,
		p3 - aim * 0.3 * kick,
		p3 + aim * (1.15 - 0.45 * kick),
	}
end

--- Sets the worn tail on `char` to `pose` (blending `dur` seconds); returns the tail, or nil.
local function tailPose(char, pose, dur)
	local r = tails[char]
	if not r then return nil end
	local t = now()
	r.From = { Name = r.Pose, T0 = r.PoseT0, Pts = nil }
	r.Pose, r.PoseT0, r.BlendT0, r.BlendDur = pose, t, t, dur or 0.3
	return r
end

local function dropTail(char)
	local r = tails[char]
	if not r then return end
	tails[char] = nil
	H.updaters[r] = nil
	pcall(function() r.Tail.Model:Destroy() end)
end

local function buildTail(char)
	local lt = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	local ut = char:FindFirstChild("UpperTorso") or lt
	local head = char:FindFirstChild("Head")
	if not (lt and head) then return nil end
	local t = K.Tail(1, H.fxFolder())
	if not t then return nil end
	local r = { Char = char, LT = lt, UT = ut, Head = head, Tail = t, Pose = "Idle", PoseT0 = now(), BlendT0 = 0, BlendDur = 0.3,
		Seed = math.random() * 10, Shown = nil }
	function r.Attach() return (lt.CFrame * CFrame.new(0, 0.05, lt.Size.Z * 0.5 + 0.02)).Position end
	local parts, cfs = {}, {}
	H.updaters[r] = function()
		if not (char.Parent and lt.Parent and head.Parent and t.Model.Parent) then
			dropTail(char)
			return false
		end
		local tn = now()
		local fn = POSES[r.Pose] or POSES.Idle
		local P = fn(r, tn - r.PoseT0)
		local w = math.clamp((tn - r.BlendT0) / math.max(0.01, r.BlendDur), 0, 1)
		if r.From and w < 1 then
			local Q = (POSES[r.From.Name] or POSES.Idle)(r, tn - r.From.T0)
			local e = smooth(w)
			for i = 1, #P do P[i] = Q[i]:Lerp(P[i], e) end
		elseif w >= 1 then
			r.From = nil
		end
		if r.Pose == "Fire" and r.FireUntil and tn > r.FireUntil then r.FireUntil = nil tailPose(char, "Idle", 0.3) end
		table.clear(parts)
		table.clear(cfs)
		K.PlaceTail(t, catmull(P), r.LT.CFrame.RightVector, parts, cfs)
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		r.Tip = cfs[#cfs] and cfs[#cfs].Position or P[5]
		-- the wearer's own first-person camera sits inside it: hidden for them alone
		local near = char == Players.LocalPlayer.Character and nearCam(head.Position, 1.8)
		if near ~= r.Shown then
			r.Shown = near
			setLTM(t.Parts, near and 1 or 0)
		end
		return true
	end
	return r
end

--- The worn-tail manager: every wearer (players, and in Studio the StudioSkin stand-ins) gets one.
function FX.Start()
	if started or not RunService:IsClient() then return end
	started = true
	-- (2026-10-26) the kit let go of its meshes (MeshBudget / the Altar's ReleaseNow: nobody here wears it): every worn tail
	-- goes with them, so none keeps drawing a destroyed mesh; the manager builds them again once it is rebuilt
	if K.OnRelease then K.OnRelease(function() for char in pairs(tails) do dropTail(char) end end) end
	task.spawn(function()
		while true do
			local seen = {}
			local function consider(m)
				if typeof(m) == "Instance" and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
					seen[m] = true
					local on = K.On(m)
					if on and K.Built and not tails[m] then
						local ok, r = pcall(buildTail, m)
						if ok and r then tails[m] = r end
					elseif not on and tails[m] then
						dropTail(m)
					end
				end
			end
			for _, plr in ipairs(Players:GetPlayers()) do consider(plr.Character) end
			if RunService:IsStudio() then
				for _, m in ipairs(workspace:GetChildren()) do if m:GetAttribute("StudioSkin") == K.Id then consider(m) end end
				local tg = workspace:FindFirstChild("TrainingGround")
				local dm = tg and tg:FindFirstChild("Dummies")
				if dm then for _, m in ipairs(dm:GetChildren()) do if m:GetAttribute("StudioSkin") == K.Id then consider(m) end end end
			end
			-- (2026-10-26) the showcase stand-ins (ShowcaseSkin, live and in Studio), wherever in the workspace they are
			if K.Showcased then for _, m in ipairs(K.Showcased()) do consider(m) end end
			for char in pairs(tails) do if not seen[char] then dropTail(char) end end
			task.wait(0.5)
		end
	end)
	-- the layer counts for the checkpoint (continuous emitters: rate x time), published on the fx folder
	local shown = 0
	H.updaters[FX.Stats] = function(dt, t)
		for e, layer in pairs(live) do
			if e.Parent and e.Enabled then FX.Stats[layer] = (FX.Stats[layer] or 0) + e.Rate * dt end
		end
		if t - shown > 0.25 then
			shown = t
			local f = H.fxFolder()
			f:SetAttribute("SC_StatBase", math.floor(FX.Stats.Base + 0.5))
			f:SetAttribute("SC_StatFleck", math.floor((FX.Stats.Fleck or 0) + 0.5))
		end
		return true
	end
end

function FX.Init(helpers, kit)
	H, K = helpers, kit
	local m = script.Parent:FindFirstChild("ToxinTuning")
	T = m and require(m) or nil
	FX.Start()
end
local function tune(group, key, fallback)
	local g = T and T[group]
	local v = g and g[key]
	return (type(v) == "number") and v or fallback
end
function FX.Tail(char) return tails[char] end                   -- (the stage reads it)
FX.Poses = POSES                                                  -- (the stage tunes them)

----------------------------------------------------------------------------------------------------
-- M1 TOXIC BUBBLES: the venom gland -- lob, settle, crack
----------------------------------------------------------------------------------------------------
local function crackGland(w, cf, len, big)
	if w.Cracked then return end
	w.Cracked = true
	local g = w.G
	local t0 = now()
	local key = {}
	local parts, cfs = {}, {}
	-- the spill: venom droplets out of the seam, a glass chip or two, a puddle spreading where it lands
	puffAt(cf, big and 10 or 7, big and 3 or 1, K.Look.Venom, 70, NumberRange.new(3, 7))
	chipsAt(cf, big and 5 or 3, NumberRange.new(3, 7), 80)
	local fy = groundAt(cf.Position)
	local puddle = part2({ Name = "SC_Puddle", Color = K.Look.VenomDeep, Transparency = 1, Reflectance = 0.2,
		Size = Vector3.new(0.05, 0.2, 0.2), Shape = Enum.PartType.Cylinder })
	puddle.CFrame = CFrame.new(cf.Position.X, fy + 0.04, cf.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	H.updaters[key] = function()
		local t = now() - t0
		local open = easeOut(math.clamp(t / 0.28, 0, 1))
		local fade = math.clamp((t - 0.45) / 0.5, 0, 1)
		table.clear(parts)
		table.clear(cfs)
		if g.Model.Parent then
			K.PlaceGland(g, cf * CFrame.new(0, -0.6 * easeIn(math.clamp((t - 0.2) / 0.6, 0, 1)), 0), len, open, fade, parts, cfs)
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		local pk = math.clamp(t / 0.4, 0, 1)
		local pd = (big and 2.4 or 1.5) * easeOut(pk)
		puddle.Size = Vector3.new(0.05, pd, pd * 0.8)
		puddle.Transparency = 0.25 + 0.75 * math.clamp((t - 0.9) / 0.8, 0, 1)
		if t >= 1.8 then
			pcall(function() g.Model:Destroy() puddle:Destroy() end)
			return false
		end
		return true
	end
end

function FX.BubbleStart(b, caster, origin)
	local g = K.Gland(H.fxFolder())
	if not g then return end
	b.WB = { G = g, Ang = math.random() * TAU, Spin = 0, Last = now(), OwnBurst = true, Len = 1.45 }
	-- a bubble cleared without a hit, a conversion or an expiry (a round reset): its gland goes with it
	local w, key = b.WB, {}
	H.updaters[key] = function()
		if w.Cracked then return false end
		if b.Model and b.Model.Parent then return true end
		w.GoneAt = w.GoneAt or now()
		if now() - w.GoneAt > 0.12 then pcall(function() g.Model:Destroy() end) return false end
		return true
	end
	-- a few venom droplets trail it in flight (the Rare layer)
	b.WB.Trail = emitter(g.Bottom, "Fleck", { Shape = "Dot", Color = K.Look.Venom, LightInfluence = 0.6, Rate = 9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) }),
		Life = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(0.2, 0.8), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -14, 0) })
end

function FX.BubbleDraw(b, cf, size, fade, look)
	local w = b.WB
	if not (w and w.G and not w.Cracked) then return end
	local tn = now()
	local dt = math.clamp(tn - (w.Last or tn), 0, 0.1)
	w.Last = tn
	-- LOB: it tumbles end over end in flight; at rest it settles on its side and its dark heart turns
	w.Ang += dt * (w.Rest and 0 or 5.2)
	w.Spin += dt * (w.Rest and 0.6 or 2.4)
	local len = w.Len * math.clamp(size.X / 2, 0.6, 1.1)          -- (no wider than the hit: the sac's own size)
	local o
	if w.Rest then
		local s = math.clamp((tn - (w.RestAt or tn)) / 0.3, 0, 1)
		local settle = 1 + 0.12 * math.sin(s * math.pi) * (1 - s) -- (a little squash as it lands)
		len *= settle
		o = CFrame.new(cf.Position) * CFrame.Angles(0, w.Spin * 0.15, math.rad(78))
	elseif look and look.Magnitude > 1e-3 then
		o = CFrame.lookAt(cf.Position, cf.Position + look) * CFrame.Angles(-math.pi / 2 + w.Ang, 0, 0) * CFrame.Angles(0, w.Spin, 0)
	else
		o = cf * CFrame.Angles(w.Ang, w.Spin, 0)
	end
	w.CF, w.L = o, len
	local parts, cfs = {}, {}
	K.PlaceGland(w.G, o, len, 0, fade, parts, cfs)
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if w.Trail then w.Trail.Enabled = not w.Rest and fade < 0.5 end
end

function FX.BubbleRest(b)
	local w = b.WB
	if not w then return end
	w.Rest, w.RestAt = true, now()
	if w.CF then puffAt(w.CF, 3, 0, K.Look.Venom, 70, NumberRange.new(1, 3)) end
end

-- the gland cracks at a hit or a conversion (ToxinFX passes the bubble last) ...
function FX.Splash(pos, normal, big, b)
	local w = b and b.WB
	if not (w and w.G) then return end
	crackGland(w, w.CF or CFrame.new(pos), w.L or w.Len, big)
end
-- ... or as its rest runs out (the expiry tell)
function FX.BubbleExpire(b)
	local w = b and b.WB
	if not (w and w.G) then return end
	crackGland(w, w.CF or CFrame.new(b.Pos or Vector3.zero), w.L or w.Len, false)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY CORROSIVE CLOUD: erupt, etch, settle
----------------------------------------------------------------------------------------------------
function FX.Cloud(c, caster, center, form, etchK)
	if not (c and c.Folder) then return end
	etchK = etchK or 1.95                                         -- (the etch's width over the cloud's radius)
	local R = c.R or tune("Cloud", "Radius", 9)
	form = form or tune("Cloud", "FormTime", 0.6)
	local tx = K.Tex()
	local fy = groundAt(center)
	-- the etch: corroded ground spreading out from the centre under the gas
	local etch = part2({ Name = "SC_Etch", Transparency = 1, Size = Vector3.new(0.4, 0.05, 0.4) }, c.Folder)
	etch.CFrame = CFrame.new(center.X, fy + 0.03, center.Z) * CFrame.Angles(0, math.random() * TAU, 0)
	local decal = nil
	if tx and tx.Etch then
		decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.TextureContent = tx.Etch
		decal.Color3 = K.Look.Etch
		decal.Transparency = 1
		decal.Parent = etch
	end
	-- chitin dust drifting through the gas (the Rare layer)
	local dustHost = anchoredHost(CFrame.new(center + Vector3.new(0, 1.6, 0)), c.Folder)
	dustHost.Size = Vector3.new(R * 1.3, 2.6, R * 1.3)
	local dust = emitter(dustHost, "Fleck", { Shape = "Flake", Color = K.Look.Dust, LightInfluence = 1, Rate = 14,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.18), NumberSequenceKeypoint.new(1, 0.08) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(2.2, 3.4), Speed = NumberRange.new(0.2, 0.6), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 0.15, 0),
		RotSpeed = NumberRange.new(-120, 120), Drag = 0.6 })
	chipsAt(CFrame.new(center + Vector3.new(0, 0.6, 0)), 8, NumberRange.new(4, 9), 70)  -- (the eruption)
	-- the bubbling: venom beads swell out of the etch and pop
	local beads = {}
	local pops = puffer(K.Look.Venom)                             -- (every bead's pop shares one puff source)
	local nextBead = now() + form * 0.6
	local t0 = now()
	local key = {}
	local dn = H.density()
	H.updaters[key] = function()
		local t = now() - t0
		local gone = not c.Folder.Parent
		local ending = gone or c.EndAt ~= nil
		local fade = ending and (gone and 1 or math.clamp((now() - c.EndAt) / math.max(0.3, c.Fade or 1.3), 0, 1)) or 0
		local spread = easeOut(math.clamp(t / (form * 1.2), 0, 1))
		local d = R * etchK * spread
		etch.Size = Vector3.new(math.max(0.4, d), 0.05, math.max(0.4, d))
		if decal then decal.Transparency = 0.12 + 0.88 * math.max(1 - math.min(1, t / 0.25), fade) end
		if dust then dust.Enabled = not ending end
		if not ending and now() >= nextBead then
			nextBead = now() + (0.18 + math.random() * 0.22) / math.max(0.3, dn)
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R * 0.85 * spread
			local p = Vector3.new(center.X + math.cos(a) * rr, fy, center.Z + math.sin(a) * rr)
			local bd = part2({ Name = "SC_Bead", Color = K.Look.Venom, Transparency = 0.3, Reflectance = 0.15, Size = Vector3.new(0.05, 0.05, 0.05) }, c.Folder)
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = bd
			beads[#beads + 1] = { P = bd, Pos = p, T0 = now(), Life = 0.35 + math.random() * 0.3, D = 0.22 + math.random() * 0.22 }
		end
		for i = #beads, 1, -1 do
			local q = beads[i]
			local u = (now() - q.T0) / q.Life
			if u >= 1 or gone then
				if not gone then pops.At(CFrame.new(q.Pos + Vector3.new(0, q.D * 0.4, 0)), 2, 1, 70, NumberRange.new(1.5, 3)) end
				pcall(function() q.P:Destroy() end)
				table.remove(beads, i)
			else
				local dd = q.D * easeOut(u)
				q.P.Size = Vector3.new(dd, dd * 0.8, dd)
				q.P.CFrame = CFrame.new(q.Pos + Vector3.new(0, dd * 0.3, 0))
			end
		end
		if (gone or fade >= 1) and #beads == 0 then
			pcall(function() etch:Destroy() dustHost:Destroy() end)
			pops.Done()
			return false
		end
		return true
	end
end

--- The Ultimate's mass (ToxinFX's cloud hook on it, the one Witch's Brew bubbles): the same etch, dust and beads.
function FX.Bubblify(c)
	if not (c and c.Folder and c.CF) then return end
	FX.Cloud(c, nil, c.CF.Position, 0.4, 1.2)                     -- (a tighter etch: the mass is wide)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE SYMBIOSIS: a thin venom thread -- arc and fade
----------------------------------------------------------------------------------------------------
function FX.Siphon(caster, victimPart)
	if not (caster and victimPart and victimPart.Parent) then return end
	local hand = caster:FindFirstChild("RightHand") or caster:FindFirstChild("Right Arm") or torsoOf(caster)
	if not hand then return end
	local hostA = anchoredHost(victimPart.CFrame)
	local hostB = anchoredHost(hand.CFrame)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Axis = Vector3.yAxis
	a1.Axis = Vector3.yAxis
	a0.Parent, a1.Parent = hostA, hostB
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = ColorSequence.new(K.Look.Seam)
	b.LightInfluence, b.LightEmission = 0, 1
	b.Width0, b.Width1 = 0.07, 0.05
	b.FaceCamera = true
	b.Segments = 16
	b.CurveSize0, b.CurveSize1 = 1.4, -0.6
	b.Transparency = NumberSequence.new(1)
	b.Parent = hostA
	local t0 = now()
	local key = {}
	local arrived = false
	H.updaters[key] = function()
		local t = now() - t0
		if t >= 0.8 or not (victimPart.Parent and hand.Parent) then
			pcall(function() hostA:Destroy() hostB:Destroy() end)
			return false
		end
		hostA.CFrame = victimPart.CFrame
		hostB.CFrame = hand.CFrame
		-- the head runs out to the hand (0.22 s); the thread then dissolves from the enemy's end (0.35 -> 0.75 s)
		local head = easeOut(math.clamp(t / 0.22, 0, 1))
		local tail = smooth((t - 0.35) / 0.4)
		local kp = { NumberSequenceKeypoint.new(0, 1) }
		local function add(x, v) if x > kp[#kp].Time + 1e-3 and x < 1 then kp[#kp + 1] = NumberSequenceKeypoint.new(x, v) end end
		add(math.max(0.002, tail * 0.98), 1)
		add(math.max(0.004, tail * 0.98 + 0.01), 0.2)
		add(math.max(0.006, head - 0.01), 0.2)
		add(math.max(0.008, head), 1)
		kp[#kp + 1] = NumberSequenceKeypoint.new(1, head >= 0.999 and (tail < 0.98 and 0.2 or 1) or 1)
		b.Transparency = NumberSequence.new(kp)
		if head >= 1 and not arrived then
			arrived = true
			puffAt(hand.CFrame, 2, 0, K.Look.Venom, 90, NumberRange.new(0.5, 1.5))
		end
		return true
	end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE PATIENT ZERO: sting and countdown -- on the cast the tail stings the target's back; the sigil spreads from
-- the wound to the ground and beats with the Default's gears into the fuse; the Default's cloud bursts at the end
----------------------------------------------------------------------------------------------------
local function gearHz(k)
	if k < 0.36 then return tune("PatientZero", "PulseFrom", 0.6) end
	if k < 0.7 then return 1.8 end
	return tune("PatientZero", "PulseTo", 4.6)
end

-- THE STING (the cast; the one tail action in the Ultimate, owner 2026-10-21): the tail the burst used to raise -- the
-- worn tail's form, glass-droplet bulb and barb, at the same 4.2x -- bursts out of the ground behind the target, rears
-- over them and lashes down; its barb hooks into their upper back. The hit is what delivers the mark: the sigil starts
-- there. Then it draws out and sinks back. Times from the cast, in seconds.
local STING = {
	Scale = 4.2,         -- (the size the burst's tail was)
	Behind = 4.4,        -- (studs behind the target it comes up -- less where a wall is nearer)
	Rise = 0.14,         -- (out of the ground, reared: 0 -> 0.14)
	Hit = 0.28,          -- (the barb lands in the back: the sigil starts here)
	Hold = 0.16,         -- (it stays in the wound)
	Out = 0.5,           -- (it draws out and sinks back: gone at 0.94)
	Spread = 0.35,       -- (the sigil: a glyph on the wound, dropping and opening into the ring on the ground)
}
FX.Sting = STING
local function flatUnit(v, fb) v = Vector3.new(v.X, 0, v.Z) return v.Magnitude > 1e-3 and v.Unit or fb end

--- The wound, in the torso's own space: the upper back, a little under the skin (the barb's point aims here); and the
--- same spot on the skin (where the glyph is stamped and the drips fall from). +Z is out of the back.
local function woundSpots(torso)
	local s = torso.Size
	return Vector3.new(0, s.Y * 0.3, s.Z * 0.5 - 0.15), Vector3.new(0, s.Y * 0.3, s.Z * 0.5 + 0.06)
end

--- Starts the sting on `target` (torso `torso`). Its direction is fixed at the cast (`back0`, out of their back then),
--- so it never swings round them as they turn; its root follows where they stand, its point follows the wound on their
--- body. `onHit()` runs once as the barb lands -- even if a long frame skipped past it -- unless it was cut short first.
--- Returns { Cut(), Failed } (Failed: no tail could be made; the caller delivers the mark itself).
local function sting(target, torso, back0, onHit)
	local tail = K.Tail(STING.Scale, H.fxFolder())
	local st = { Cut = function() end, Failed = tail == nil }
	if not tail then return st end
	local t0 = now()
	local hitDone, cutAt = false, nil
	function st.Cut() if not cutAt then cutAt = now() end end
	local up, tw0 = Vector3.yAxis, -back0
	local side = up:Cross(back0)                                  -- (the target's right at the cast: the keel outside the arch,
	                                                              --  the barb hooking under, as on the worn tail)
	local inLocal = woundSpots(torso)
	local g = STING.Scale / 3.4                                   -- (the poses were drawn for a 3.4x tail)
	-- the root's distance behind them: STING.Behind, or short of a wall there
	local behind = STING.Behind
	do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { H.fxFolder(), target }
		for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then skip[#skip + 1] = plr.Character end end
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(torso.Position, back0 * (STING.Behind + 1), params)
		if hit then behind = math.max(1.2, hit.Distance - 1) end
	end
	local function spots()
		local p = torso.Position
		local gb = p + back0 * behind
		gb = Vector3.new(gb.X, groundAt(gb, target), gb.Z)
		return gb, (torso.CFrame * CFrame.new(inLocal)).Position
	end
	-- the two poses: REARED (an arch up out of the ground behind them, its end over their head) and STRUCK (a scorpion's
	-- J: the tail comes down behind them, its end rises forward at shoulder-blade height and the barb's hook curls down
	-- into the back -- never over the head). Heights from the wound, so a jumping target is still struck from above.
	local function reared(gb, wound)
		local h = wound.Y - gb.Y
		return { gb - up * 5 * g, gb + up * 1.5 * g + back0 * 0.25 * g, gb + up * (h + 2.6 * g) + back0 * 0.5 * g,
			gb + up * (h + 5.2 * g) + tw0 * 0.9 * g, gb + up * (h + 4.6 * g) + tw0 * 3.2 * g }
	end
	local function struck(gb, wound)
		local h = wound.Y - gb.Y
		return { gb - up * 5 * g, gb + up * 1.5 * g + back0 * 0.25 * g, gb + up * (h + 2.2 * g) + tw0 * 0.1 * g,
			wound + back0 * 2.4 * g - up * 0.3 * g, wound + back0 * 0.4 * g + up * 0.9 * g }
	end
	-- out of the ground (lift -12g -> 0 over Rise), then the lash (0 -> 1, accelerating, Rise -> Hit)
	local deep = -12 * g
	local function riseAt(tt) return tt < STING.Rise and deep * (1 - easeOut(tt / STING.Rise)) or 0 end
	local function lashAt(tt)
		if tt < STING.Rise then return 0 end
		return easeIn(math.clamp((tt - STING.Rise) / (STING.Hit - STING.Rise), 0, 1))
	end
	local parts, cfs = {}, {}
	local surfaced = false
	-- (keyed by the tail record: if this updater ever faults, the host clears its model with it)
	H.updaters[tail] = function()
		local t = now() - t0
		if not (target.Parent and torso.Parent) then
			pcall(function() tail.Model:Destroy() end)
			return false
		end
		local gb, wound = spots()
		-- THE HIT: the mark is delivered here, whatever the frame rate did
		if not hitDone and not cutAt and t >= STING.Hit then
			hitDone = true
			local woundCF = CFrame.lookAt(wound, wound + back0)
			puffAt(woundCF + back0 * 0.35, 8, 2, K.Look.Venom, 70, NumberRange.new(3, 6))   -- (venom spat back out of it)
			pcall(onHit)
		end
		local outAt = math.min(cutAt and (cutAt - t0) or math.huge, STING.Hit + STING.Hold)
		if t >= outAt + STING.Out then
			pcall(function() tail.Model:Destroy() end)
			return false
		end
		local lift, k
		if t < outAt then
			lift, k = riseAt(t), lashAt(t)
		else
			local u = math.clamp((t - outAt) / STING.Out, 0, 1)      -- (it draws the barb out -- part way, never a second
			local l0 = riseAt(outAt)                                  --  rear -- and sinks from where it was)
			lift, k = l0 + (deep - l0) * easeIn(u), lashAt(outAt) * (1 - 0.45 * smooth(u / 0.35))
		end
		if not surfaced then
			surfaced = true
			chipsAt(CFrame.new(gb + up * 0.3), 8, NumberRange.new(5, 10), 45)       -- (the ground breaks behind them)
			puffAt(CFrame.new(gb + up * 0.4), 0, 4, nil, 50)
		end
		local A, B = reared(gb, wound), struck(gb, wound)
		local P = {}
		for i = 1, 5 do P[i] = A[i]:Lerp(B[i], k) + up * lift end
		table.clear(parts)
		table.clear(cfs)
		K.PlaceTail(tail, catmull(P), side, parts, cfs)
		-- the barb is rigid and hooked: carry the end of the curve until its POINT is in the wound (twice: the shift
		-- changes the curve's length a little), weighted by the lash so the reared pose is untouched
		if k > 0.01 then
			for _ = 1, 2 do
				local miss = (wound - K.BarbTip(tail, cfs[#cfs])) * k
				P[3] += miss * 0.3
				P[4] += miss * 0.85
				P[5] += miss
				table.clear(parts)
				table.clear(cfs)
				K.PlaceTail(tail, catmull(P), side, parts, cfs)
			end
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		-- in the target's own first-person camera it would fill the view: hidden for them alone
		local mine = target == Players.LocalPlayer.Character and nearCam(torso.Position, 3)
		setLTM(tail.Parts, mine and 1 or 0)
		return true
	end
	return st
end

function FX.Mark(caster, target, telegraph, fuse)
	local torso = torsoOf(target)
	local tx = K.Tex()
	if not (torso and tx and tx.Sigil) then return nil end
	telegraph = telegraph or tune("PatientZero", "Telegraph", 3.5)
	fuse = fuse or tune("PatientZero", "Fuse", 0.35)
	local pulseEnd = math.max(0.1, telegraph - fuse)
	local D = 9.5                                                 -- (the sigil's width, studs)
	local host = part2({ Name = "SC_Sigil", Transparency = 1, Size = Vector3.new(0.2, 0.05, 0.2) })
	local outer = surfaceImage(host, Enum.NormalId.Top, tx.Sigil, K.Look.Seam, 512, 1.4)
	local sg = outer.Parent
	local inner = Instance.new("ImageLabel")
	inner.BackgroundTransparency, inner.ImageContent, inner.ImageColor3 = 1, tx.Sigil, K.Look.Venom
	inner.AnchorPoint, inner.Position, inner.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.44, 0.44)
	inner.Parent = sg
	outer.ImageTransparency, inner.ImageTransparency = 1, 1
	local calm = H.calm()
	local t0 = now()
	local phase, spin = 0, 0
	local rec = { HideCore = true }
	local endAt, burst = nil, false
	-- the sting delivers the mark: the sigil exists from its hit on. Its direction is fixed now, at the cast.
	local back0 = flatUnit(-torso.CFrame.LookVector, Vector3.zAxis)
	local _, skinLocal = woundSpots(torso)
	local hitAt, backHit, axis = nil, nil, nil                    -- (at the hit: out of their back, and the glyph's hinge --
	local function deliver()                                      --  their right)
		if hitAt then return end
		hitAt = now()
		backHit = flatUnit(-torso.CFrame.LookVector, back0)
		axis = Vector3.yAxis:Cross(backHit)
	end
	local st = sting(target, torso, back0, deliver)
	local lastS = 0.2                                             -- (the ring's size as last drawn: a cancel shrinks it from there)
	function rec.End(didBurst)
		if endAt then return end
		endAt, burst = now(), didBurst and true or false
		st.Cut()
	end
	--- (ToxinFX) where the Default's mark drips from: the wound in the back, on the skin, once the sting has landed
	function rec.DripAt()
		if not (hitAt and torso.Parent) then return nil end
		return (torso.CFrame * CFrame.new(skinLocal + Vector3.new(0, 0, 0.12))).Position - Vector3.new(0, 0.25, 0)
	end
	local key = {}
	H.updaters[key] = function(dt)
		local t = now() - t0
		local alive = target.Parent and torso.Parent
		if endAt then
			-- burst: the ring flies outward and is gone in 0.3 s; cancelled: it shrinks away from where it was over 0.5 s
			local k = math.clamp((now() - endAt) / (burst and 0.3 or 0.5), 0, 1)
			if hitAt then                                         -- (no ring before the sting landed: nothing to clear)
				local s = burst and D * (1 + 0.5 * easeOut(k)) or lastS * (1 - 0.3 * k)
				host.Size = Vector3.new(math.max(0.2, s), 0.05, math.max(0.2, s))
				local a = math.max(outer.ImageTransparency, k)
				outer.ImageTransparency, inner.ImageTransparency = a, a
			end
			if k >= 1 then host:Destroy() return false end
			return true
		end
		if not alive then rec.End(false) return true end
		-- the BEAT keeps the Default's gears from the cast (0.6 -> 1.8 -> 4.6 Hz over the telegraph less the fuse) -- by
		-- scale and spin, never brightness -- whether or not the ring has spread yet; then the solid fuse
		local beat = 0
		if t < pulseEnd then
			local k = math.clamp(t / pulseEnd, 0, 1)
			local hz = calm and math.min(gearHz(k), 1) or gearHz(k)
			phase += TAU * hz * dt
			beat = math.max(0, math.cos(phase)) ^ 6 * (calm and 0.4 or 1)
			spin += dt * (0.25 + 0.9 * k)
		end
		-- (if the sting could not be made, or never landed, the mark is delivered on its beat anyway)
		if not hitAt and (st.Failed or t > STING.Hit + 0.25) then deliver() end
		if not hitAt then return true end                         -- (nothing shows until the sting lands)
		local p = torso.Position
		local fy = groundAt(p, target)
		-- SPREAD (0.35 s): a small glyph stamped on the wound, facing out of the back; it hinges down about the target's
		-- right, drops and opens out into the ring on the ground (it grows once it has left the body)
		local ks = math.clamp((now() - hitAt) / STING.Spread, 0, 1)
		local skin = (torso.CFrame * CFrame.new(skinLocal)).Position
		local from = CFrame.fromMatrix(skin, axis, backHit)      -- (+Y out of the back; X the hinge)
		local to = CFrame.fromMatrix(Vector3.new(p.X, fy + 0.06, p.Z), axis, Vector3.yAxis)
		local rot = (from - from.Position):Lerp(to - to.Position, easeOut(math.min(1, ks * 1.5)))
		local place = CFrame.new(from.Position:Lerp(to.Position, smooth(ks))) * rot
		local bloom = 0.06 + 0.94 * backOut(math.clamp((ks - 0.2) / 0.8, 0, 1))
		local fuseK = (t >= pulseEnd) and easeOut(math.clamp((t - pulseEnd) / 0.12, 0, 1)) or 0   -- (draws in tight, holds)
		local s = D * bloom * (1 + 0.07 * beat) * (1 - 0.22 * fuseK)
		host.Size = Vector3.new(math.max(0.2, s), 0.05, math.max(0.2, s))
		host.CFrame = place
		lastS = math.max(0.2, s)
		outer.Rotation = math.deg(spin)
		inner.Rotation = -math.deg(spin * 2.2)
		inner.Size = UDim2.fromScale(0.44 * (1 + 0.12 * beat), 0.44 * (1 + 0.12 * beat))
		outer.ImageTransparency = 1 - math.min(1, (now() - hitAt) / 0.08)
		inner.ImageTransparency = outer.ImageTransparency
		return true
	end
	return rec
end

--- The burst (ToxinFX's PZBurst hook): the tail struck at the cast, so nothing more is drawn here -- the Default's wave
--- and its mass (etched and dusted by FX.Bubblify) are the ending. True keeps the Default's light-crack flash out.
function FX.PZBurst(caster, target, pos, center, R)
	return true
end

----------------------------------------------------------------------------------------------------
-- ANTITOXIN VENT: the tail over the mouth -- assemble and hold (nothing else is worn)
----------------------------------------------------------------------------------------------------
function FX.Vent(caster, duration)
	local r = tails[caster]
	if not r then return nil end                                  -- (no tail yet: the Default mask draws)
	local assemble = tune("Vent", "AssembleTime", 0.35)
	r.VentGen = (r.VentGen or 0) + 1
	tailPose(caster, "Vent", assemble)
	-- the hold: the bulb over the mouth breathes a faint venom vapor (never in the wearer's own first-person view)
	local gen, nextPuff, key = r.VentGen, now() + assemble + 0.2, {}
	local breath = puffer(K.Look.Venom)
	H.updaters[key] = function()
		if tails[caster] ~= r or r.VentGen ~= gen or r.Pose ~= "Vent" then breath.Done() return false end
		if now() >= nextPuff then
			nextPuff = now() + 0.6 + math.random() * 0.25
			local mine = caster == Players.LocalPlayer.Character and nearCam(r.Head.Position, 1.8)
			if not mine and r.Tail.Bulb.Parent then
				breath.At(CFrame.new(r.Tail.Bulb.Position), 1, 1, 40, NumberRange.new(0.5, 1.2))
			end
		end
		return true
	end
	return {
		Mouth = function()                                        -- (the cleanse threads end on the stinger's bulb)
			return (r.Tail.Bulb.Parent and r.Tail.Bulb.Position) or nil
		end,
		Arrive = function()
			if r.Tail.Bulb.Parent then puffAt(r.Tail.Bulb.CFrame, 2, 0, K.Look.Venom, 120, NumberRange.new(0.5, 1.2)) end
		end,
		Colors = { K.Look.VenomDeep, K.Look.Venom },
	}
end
--- The Vent is over: the tail uncurls home (fast on a re-cast or a clear).
function FX.VentEnd(caster, fast)
	local r = tails[caster]
	if not r or r.Pose ~= "Vent" then return end
	tailPose(caster, "Idle", fast and 0.22 or tune("Vent", "AssembleTime", 0.35))
end

----------------------------------------------------------------------------------------------------
-- ACID RAIN: rise, fire, rain -- the tail's flourish inside the GatherTime; the spines on the Default's rain window
----------------------------------------------------------------------------------------------------
local RAIN = {
	Rise = 0.2,          -- (the tail rears: 0 -> 0.2 s)
	Fire = 0.24,         -- (the volley leaves the stinger)
	Flight = 0.22,       -- (the pellets reach the sky: 0.46 s -- inside the 0.7 s GatherTime)
	Hold = 0.4,          -- (the tail holds its aim, then settles home over 0.3 s: home at 0.7 s, the whole flourish
	                     --  inside the GatherTime)
	Spines = 26,         -- (a second, at full density: about 100 over the rain, under the Default's ~600 parts)
	Fall = 0.3,
}
FX.RainTiming = RAIN

function FX.AcidRain(caster, center, height, R, gather, rainTime, t0)
	local r = tails[caster]
	if not r then return nil end                                  -- (no tail yet: the Default rain draws)
	gather = gather or tune("AcidRain", "GatherTime", 0.7)
	rainTime = rainTime or tune("AcidRain", "RainTime", 4)
	t0 = t0 or now()
	local sky = center + Vector3.new(0, height, 0)
	r.Aim = sky
	r.FireAt = nil
	r.FireUntil = t0 + RAIN.Hold
	tailPose(caster, "Fire", RAIN.Rise)
	local dn = H.density()
	local pellets, spines = {}, {}
	local sizzle = puffer(K.Look.Venom)                           -- (every spine's sizzle shares one puff source)
	local fired, burst = false, false
	local nextLand = t0 + math.max(gather * 0.8, RAIN.Fire + RAIN.Flight + RAIN.Fall)
	local lastLand = t0 + gather + rainTime
	local key = {}
	local parts, cfs = {}, {}
	H.updaters[key] = function()
		local tn = now()
		local t = tn - t0
		-- FIRE: a volley of venom pellets leaves the stinger for the sky over the area
		if not fired and t >= RAIN.Fire then
			fired = true
			r.FireAt = tn
			local from = r.Tip or (torsoOf(caster) and torsoOf(caster).Position) or sky
			puffAt(CFrame.new(from), 3, 1, K.Look.Venom, 40, NumberRange.new(2, 4))
			for i = 1, 7 do
				local pl = K.Pellet(H.fxFolder())
				local a, rr = math.random() * TAU, math.sqrt(math.random()) * R * 0.5
				pellets[i] = { P = pl, From = from, To = sky + Vector3.new(math.cos(a) * rr, (math.random() - 0.5) * 2, math.sin(a) * rr),
					T0 = tn + (i - 1) * 0.012 }
			end
		end
		for i = #pellets, 1, -1 do
			local q = pellets[i]
			local u = math.clamp((tn - q.T0) / RAIN.Flight, 0, 1)
			local pos = q.From:Lerp(q.To, easeOut(u))
			local dir = (q.To - q.From).Unit
			q.P.Part.CFrame = CFrame.lookAt(pos, pos + dir)
			q.P.Seam.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
			if u >= 1 then
				if not burst then
					burst = true
					puffAt(CFrame.new(sky), 6, 4, K.Look.Venom, 180, NumberRange.new(2, 5))   -- (they burst into a spray up there)
				end
				pcall(function() q.P.Part:Destroy() q.P.Seam:Destroy() end)
				table.remove(pellets, i)
			end
		end
		-- RAIN: thin barbed spines, each planned by when it LANDS inside the Default rain's window, falling point-first
		while fired and nextLand <= lastLand and nextLand - RAIN.Fall <= tn do
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R
			local land = center + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
			land = Vector3.new(land.X, groundAt(land), land.Z)
			local from = Vector3.new(land.X + (math.random() - 0.5) * 2, sky.Y, land.Z + (math.random() - 0.5) * 2)
			local sp = K.Barb(1.2, 0.42, H.fxFolder(), true)
			if sp then
				spines[#spines + 1] = { S = sp, From = from, To = land, T0 = math.max(tn, nextLand - RAIN.Fall), Land = nextLand,
					Roll = math.random() * TAU }
			end
			nextLand += 1 / (RAIN.Spines * math.max(0.3, dn))
		end
		for i = #spines, 1, -1 do
			local q = spines[i]
			local u = (tn - q.T0) / math.max(0.05, q.Land - q.T0)
			if u < 1 then
				local tip = q.From:Lerp(q.To, easeIn(math.clamp(u, 0, 1)))
				local dir = (q.To - q.From).Unit
				local back = tip - dir * 1.1                        -- (point first: the barb's base trails its tip)
				local base = CFrame.lookAt(back, back + dir) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, q.Roll)
				q.S.Part.CFrame = K.BarbCF(q.S, base)             -- (base's +Z runs down the barb to its tip)
				if q.S.Seam then
					q.S.Seam.Size = Vector3.new(0.03, 0.18, 0.18)
					q.S.Seam.CFrame = CFrame.lookAt(back, back + dir) * CFrame.Angles(0, math.pi / 2, 0)
				end
			else
				-- STICK: it holds in the ground, sizzling; a corrode mark spreads under it; then it is gone
				if not q.Stuck then
					q.Stuck = tn
					sizzle.At(CFrame.new(q.To + Vector3.new(0, 0.1, 0)), 2, 1, 70, NumberRange.new(1.5, 3))
					local tx = K.Tex()
					if tx and tx.Etch then
						local m = part2({ Name = "SC_Mark", Transparency = 1, Size = Vector3.new(1.7, 0.05, 1.7) })
						m.CFrame = CFrame.new(q.To + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, math.random() * TAU, 0)
						local dc = Instance.new("Decal")
						dc.Face, dc.TextureContent, dc.Color3, dc.Transparency = Enum.NormalId.Top, tx.Etch, K.Look.Etch, 0.25
						dc.Parent = m
						q.Mark, q.Decal = m, dc
					end
				end
				local s = tn - q.Stuck
				if q.Decal then q.Decal.Transparency = 0.25 + 0.75 * math.clamp((s - 0.4) / 1.1, 0, 1) end
				local fade = math.clamp((s - 0.45) / 0.3, 0, 1)
				q.S.Part.Transparency = fade
				if q.S.Seam then q.S.Seam.Transparency = fade end
				if s >= 1.6 then
					pcall(function() q.S.Part:Destroy() end)
					if q.S.Seam then pcall(function() q.S.Seam:Destroy() end) end
					if q.Mark then pcall(function() q.Mark:Destroy() end) end
					table.remove(spines, i)
				end
			end
		end
		local alive = (nextLand <= lastLand) or #spines > 0 or #pellets > 0 or not fired
		if not alive then sizzle.Done() end
		return alive
	end
	return "drops"                                                -- (the spines are the drops: the Default's cloud overhead
end                                                               --  stays, marking the area, and the volley bursts into it)

--- CORRODED (ToxinFX's acid tick, per body caught): faint glowing chitin cracks over the body that track the Corroded
--- stacks (ToxinVuln, while ToxinVulnUntil holds) and fade as they lapse; true = the Default glaze is not drawn.
local cracked = setmetatable({}, { __mode = "k" })
function FX.Corrode(model)
	local tx = K.Tex()
	if not (tx and tx.Crack) then return nil end
	if cracked[model] then return true end
	local maxS = tune("AcidRain", "VulnMaxStacks", 4)
	local guis = {}
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "Head", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local im, sg = surfaceImage(p, face, tx.Crack, K.Look.Seam, 128, 1.1)
				im.ImageTransparency = 1
				im.Rotation = math.random(0, 3) * 90
				guis[#guis + 1] = { Im = im, Sg = sg }
			end
		end
	end
	if #guis == 0 then return nil end
	local rec = { Cover = 0 }
	cracked[model] = rec
	local key = {}
	H.updaters[key] = function(dt)
		local untilT = model.Parent and model:GetAttribute("ToxinVulnUntil")
		local stacks = model.Parent and model:GetAttribute("ToxinVuln") or 0
		local liveS = untilT and workspace:GetServerTimeNow() <= untilT and stacks > 0
		local want = liveS and math.clamp(stacks / maxS, 0, 1) or 0
		rec.Cover += (want - rec.Cover) * math.min(1, dt * (liveS and 4 or 2.5))
		local mine = model == Players.LocalPlayer.Character and nearCam((model:FindFirstChild("Head") or model:GetPivot()).Position, 2)
		for _, g in ipairs(guis) do
			g.Im.ImageTransparency = 1 - 0.6 * rec.Cover
			g.Sg.Enabled = not mine
		end
		if (not liveS and rec.Cover < 0.02) or not model.Parent then
			for _, g in ipairs(guis) do pcall(function() g.Sg:Destroy() end) end
			cracked[model] = nil
			return false
		end
		return true
	end
	return true
end

return FX
