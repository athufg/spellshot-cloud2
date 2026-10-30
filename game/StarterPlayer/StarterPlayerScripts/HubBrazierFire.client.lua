--[[
	HubBrazierFire (LocalScript, StarterPlayerScripts) -- 2026-10-27, the owner's brief: the Store wing's brazier flames
	were one flat teardrop each; they burn in Pyro's own fire language now (PyroDraw, the kit's comic flame):
	  * a layered standing flame per brazier (PyroDraw.standing_flame, three layers: dark licking outer tongues round a
	    bright core), breathing and swaying on its own clock;
	  * a few flame wisps licking off its tip, embers rising (PyroDraw's ember emitter), a faint smoke wisp above;
	  * the old teardrop parts (ArcaneObservatoryHub.Fires: Flame_01..09, every brazier in the Store's Pyro quadrant)
	    are hidden on this client; the bowls and their glow stay as they are.
	(2026-10-27, edge to edge) THE FIRE FILLS EACH BOWL TO ITS INNER LIP, so no bare rim shows from any angle (the old
	teardrop's wide base had been the bed; with it hidden only the narrow central flame stood in the bowl). Per bowl,
	every size a multiple of its inner-lip radius R (Bowls):
	  * the BED: a squat Bulb (the burst's torn shells) across the bowl, widest at the lip, a bright Core dome in it;
	  * a Hoop of flame lobes lying on the lip, turning slowly;
	  * a RING of 8-9 shorter tongues (standing_flame, 2 layers) round the inner lip at ~0.88 R: roots sunk so their
	    bellies sit at the lip, wide enough to overlap, varied heights and phases, leaning a little outward;
	  * the tall central flame (3 layers) and a shorter twin turned square to it;
	  * wisps off the tip, embers RISING off the bed (an ember_field disc, buoyant: the old spray fell back under its
	    gravity), the smoke wisp above; a small warm ground_glow in the bowls the hub gives no light (stairs, counter).
	One canvas per bowl: about 16 parts, 1 emitter, 0-1 light each, far under Config.MaxParts (260 x density) /
	MaxEmitters (6) / MaxLights (4); the one canvas for all nine ran out of ember emitters at the seventh bowl.
	Supersedes HubFireFlicker. Default Pyro meshes only (asset meshes: no EditableMesh budget), default palette (no
	wrap). Nothing drawn while the camera is far (HubLife.Close).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Height = 2.15,          -- x the old teardrop's rest height (the big entrance pair: ~3.1 studs; the stair / counter ones ~1.5-2)
	Sway = { 0.07, 0.8 },   -- lean (fraction of the height) and its rate (Hz)
	-- (2026-10-27, edge to edge) every length below is x the bowl's inner-lip radius R unless it says otherwise
	Twin = { Height = 0.68, Width = 0.56, Off = 0.16 },   -- the central twin: x the tall flame's height; width x its own height; root off the axis
	Ring = {
		Count = { 6, 9 }, PerR = 4.4,   -- tongues: 5 + PerR x R (studs), clamped (the gate pedestals 9, the rest 8); 2 fewer under density 0.75
		At = { 0.86, 0.90 },            -- distance off the axis: close to the lip, so a thin tongue reaches it without spilling far over the rim
		Height = { 1.0, 1.6 },
		Overlap = 1.6,                  -- belly width / the spacing round the ring (no gap even at the narrowest phase)
		Flat = 0.6,                     -- thickness / width (the radial depth)
		Sink = 0.15,                    -- root under the lip, x the tongue's height (its belly at the lip)
		Lean = 0.12, Sway = 0.05, Jitter = 0.08,   -- outward lean; tangential sway (0.7 Hz); angular jitter (x the spacing)
	},
	Bed = { Height = 0.62, Width = 2.1, Core = { 0.7, 1.5 } },   -- the Bulb's height / width (widest at the lip); the Core dome's
	Hoop = { Radius = 0.88, Thick = 1.3, Spin = 0.5 },           -- lying on the lip; Thick x its radius (the lobes' height); rad/s
	Wisps = { Rate = 5, Life = 0.45, Scale = 0.22 },   -- Scale x the flame height
	Embers = 7,             -- per brazier, alive at once (about)
	Rise = { Up = { 1.2, 3 }, Buoy = 2.5, Life = { 0.7, 1.5 }, Size = { 0.05, 0.11 } },   -- (2026-10-27) x R / 1.22 (the gate bowls = 1; Size x its root)
	Glow = { Radius = 3, Level = 1.5 },   -- (2026-10-27) the unlit bowls' ground_glow: Brightness ~0.5, as the gate bowls' own lights
	Smoke = { Rate = 1.4, Life = { 2.6, 3.6 }, Size = { 0.35, 1.5 }, Colour = Color3.fromRGB(70, 66, 72), Alpha = 0.8 },
}

-- (2026-10-27) each bowl's inner lip: its radius R and its height over the flame's Base (the bowl floor's centre), measured
-- off the merged hub stone (OBS_Stone_Dark_01 / 02) round each Fires axis; Glow = the hub has no light of its own for it
local Bowls = {
	Flame_01 = { R = 1.22, Lip = 0.30 }, Flame_03 = { R = 1.22, Lip = 0.30 },                     -- A the Store gate's pedestals
	Flame_02 = { R = 0.64, Lip = 0.12 }, Flame_04 = { R = 0.64, Lip = 0.12 },                     -- B the gate's pillar tops
	Flame_05 = { R = 0.575, Lip = 0.108, Glow = true }, Flame_06 = { R = 0.575, Lip = 0.108, Glow = true },
	Flame_07 = { R = 0.575, Lip = 0.108, Glow = true },                                           -- C the stairs
	Flame_08 = { R = 0.767, Lip = 0.144, Glow = true }, Flame_09 = { R = 0.767, Lip = 0.144, Glow = true },   -- D the Store counter
}

local hub = workspace:WaitForChild(HubLife.Hub, 60)
local fires = hub and hub:WaitForChild("Fires", 60)
if not fires then return end
local ice = ReplicatedStorage:WaitForChild("IceMagic")
local okP, PD = pcall(require, ice:WaitForChild("PyroDraw"))
if not okP then
	warn("[HubBrazierFire] PyroDraw unavailable: " .. tostring(PD))
	return
end

local smokeFolder = Instance.new("Folder")
smokeFolder.Name = "HubBrazierSmoke"
smokeFolder.Parent = workspace

local function seq(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end

----------------------------------------------------------------------------------------------------
-- THE LAYOUT (2026-10-27, edge to edge): one bowl's fire, every size from its lip radius R
----------------------------------------------------------------------------------------------------
local UP, TAU = Vector3.yAxis, 2 * math.pi

--- a bowl's record: where its pieces stand (static) and their option tables (reused every frame)
local function bowlOf(name, seed, base, rest)
	local bowl = Bowls[name] or { R = 0.545 * rest.X, Lip = 0.109 * rest.X }   -- (an unknown bowl: the survey's ratios to the old teardrop)
	local R, h = bowl.R, rest.Y * Tuning.Height
	local a = PD.Rand(seed, 0, 2) * TAU
	local side = Vector3.new(math.cos(a), 0, math.sin(a))
	local off = Vector3.new(math.cos(a + 2.2), 0, math.sin(a + 2.2))
	local tw = Tuning.Twin
	local k = R / 1.22
	local rs = Tuning.Rise
	return {
		Name = name, Seed = seed, Base = base, H = h, R = R, Lip = bowl.Lip, Glow = bowl.Glow == true,
		LipAt = base + UP * bowl.Lip,
		BedRoot = base + UP * (bowl.Lip - 0.2 * Tuning.Bed.Height * R),      -- the Bulb is widest a fifth of the way up: at the lip
		HoopAt = base + UP * (bowl.Lip + 0.03 * R),
		TwinRoot = base + off * (tw.Off * R), TwinLean = off * 0.06,
		Main = { ph = PD.Rand(seed * 131, 4, 7) * TAU, layers = 3, side = side, lean = Vector3.zero },
		Twin = { ph = PD.Rand(seed * 131 + 50, 4, 7) * TAU, layers = 3, side = Vector3.new(-side.Z, 0, side.X),
			width = tw.Width * tw.Height * h, lean = Vector3.zero },
		BedOpt = { ph = PD.Rand(seed, 5, 1) * TAU }, CoreOpt = { ph = PD.Rand(seed, 5, 2) * TAU },
		HoopOpt = { ph = PD.Rand(seed, 5, 3) * TAU, thick = Tuning.Hoop.Thick * Tuning.Hoop.Radius * R, spin = 0 },
		WispOpt = { seed = 40 + seed, rate = Tuning.Wisps.Rate, life = Tuning.Wisps.Life, scale = Tuning.Wisps.Scale * h, buoy = 6 },
		EmberOpt = { id = "bed", count = Tuning.Embers, inner = 0, life = rs.Life, up = { rs.Up[1] * k, rs.Up[2] * k }, g = -rs.Buoy * k,
			kd = 1, cone = 16, size = { rs.Size[1] * math.sqrt(k), rs.Size[2] * math.sqrt(k) }, lift = bowl.Lip + 0.1 * R },
		Ring = {},
	}
end

--- the ring of tongues round a bowl's inner lip (static: their places, heights, widths, phases)
local function ringOf(b, density)
	local rg = Tuning.Ring
	local R = b.R
	local n = math.clamp(math.floor(5 + rg.PerR * R + 0.5), rg.Count[1], rg.Count[2])
	if density < 0.75 then n = math.max(rg.Count[1], n - 2) end
	local s = b.Seed * 31 + 7
	local a0 = PD.Rand(b.Seed, 0, 1) * TAU
	local list = table.create(n)
	for j = 0, n - 1 do
		local a = a0 + (j + (PD.Rand(s, j, 1) * 2 - 1) * rg.Jitter) * TAU / n
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local rho = R * (rg.At[1] + (rg.At[2] - rg.At[1]) * PD.Rand(s, j, 2))
		local h = R * (rg.Height[1] + (rg.Height[2] - rg.Height[1]) * PD.Rand(s, j, 3))
		list[j + 1] = {
			Root = b.Base + out * rho + UP * (b.Lip - rg.Sink * h), Out = out, Tan = Vector3.new(-out.Z, 0, out.X),
			H = h, W = rg.Overlap * TAU * rho / n, Ph = PD.Rand(s, j, 4) * TAU,
		}
	end
	return list
end

local RING_OPT = { ph = 0, layers = 2, side = UP, width = 1, flat = Tuning.Ring.Flat, lean = Vector3.zero }

--- one bowl's fire, centre out (what matters first): the tall flame + its twin, the bed, the hoop, the ring, the wisps,
--- the rising embers, the glow
local function drawBowl(cv, b, t)
	local R, H = b.R, b.H
	local sw, hz = Tuning.Sway[1], Tuning.Sway[2]
	local lean = Vector3.new(math.sin(t * hz * TAU + b.Seed * 1.7) * sw, 0, math.cos(t * hz * 1.4 * math.pi + b.Seed) * sw)
	local o = b.Main
	o.lean = lean
	local tip = cv:standing_flame(b.Base, H, t, o)
	o = b.Twin
	o.lean = lean * 1.2 + b.TwinLean
	cv:standing_flame(b.TwinRoot, H * Tuning.Twin.Height, t, o)
	local bd = Tuning.Bed
	cv:bulb(b.BedRoot, UP, bd.Height * R, bd.Width * R, b.BedOpt)
	cv:core(b.BedRoot, UP, bd.Core[1] * R, bd.Core[2] * R, b.CoreOpt)
	o = b.HoopOpt
	o.spin = b.Seed + Tuning.Hoop.Spin * t
	cv:hoop(b.HoopAt, Tuning.Hoop.Radius * R, t, o)
	local rg = Tuning.Ring
	local half = lean * 0.5
	for _, g in ipairs(b.Ring) do
		RING_OPT.ph, RING_OPT.side, RING_OPT.width = g.Ph, g.Tan, g.W
		RING_OPT.lean = g.Out * rg.Lean + g.Tan * (rg.Sway * math.sin(TAU * 0.7 * t + g.Ph)) + half
		cv:standing_flame(g.Root, g.H, t, RING_OPT)
	end
	cv:wisps(tip - UP * H * 0.25, t, 0, math.huge, b.WispOpt)
	cv:ember_field(b.Base, 0.8 * R, t, b.EmberOpt)
	if b.Glow then cv:ground_glow(b.LipAt, Tuning.Glow.Radius * R, Tuning.Glow.Level, t, b.Seed) end
end

-- one entry per brazier (the old Outer layer carries Base and RestSize); every old flame part hidden here
local braziers = {}
local function hideOld()
	for _, p in ipairs(fires:GetDescendants()) do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end
		if p:IsA("ParticleEmitter") then p.Enabled = false end
	end
end
for _, p in ipairs(fires:GetChildren()) do
	if p:IsA("BasePart") and p:GetAttribute("Layer") == "Outer" then
		local base = p:GetAttribute("Base") or (p.Position - Vector3.new(0, p.Size.Y / 2, 0))
		local rest = p:GetAttribute("RestSize") or p.Size
		local h = rest.Y * Tuning.Height
		local i = #braziers + 1
		local name = tostring(p:GetAttribute("Flame") or p.Name)
		local smoke = Instance.new("Part")
		smoke.Name = "Smoke_" .. name
		smoke.Anchored, smoke.CanCollide, smoke.CanQuery, smoke.CanTouch, smoke.Transparency = true, false, false, false, 1
		smoke.Size = Vector3.new(0.4, 0.2, 0.4)
		smoke.CFrame = CFrame.new(base + Vector3.new(0, h * 1.05, 0))
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate, e.Lifetime, e.Speed = Tuning.Smoke.Rate, NumberRange.new(Tuning.Smoke.Life[1], Tuning.Smoke.Life[2]), NumberRange.new(0.7, 1.3)
		e.SpreadAngle, e.Acceleration, e.Drag = Vector2.new(10, 10), Vector3.new(0.12, 0.35, 0), 0.4
		e.Size = seq(Tuning.Smoke.Size[1] * h / 3, Tuning.Smoke.Size[2] * h / 3)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, Tuning.Smoke.Alpha),
			NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Tuning.Smoke.Colour)
		e.LightInfluence, e.Rotation, e.RotSpeed = 0.6, NumberRange.new(0, 360), NumberRange.new(-20, 20)
		e.Parent = smoke
		smoke.Parent = smokeFolder
		local b = bowlOf(name, tonumber(string.match(name, "%d+")) or i, base, rest)   -- (2026-10-27) seeded by its number
		b.Smoke = e
		braziers[i] = b
	end
end
if #braziers == 0 then return end
hideOld()
fires.DescendantAdded:Connect(function(d) task.defer(hideOld) end)

-- wait for the flame meshes, then a canvas per bowl (2026-10-27: was one for all nine)
task.spawn(function()
	local t0 = os.clock()
	while not PD.Ready() do
		if os.clock() - t0 > 60 then warn("[HubBrazierFire] flame meshes not in the place") return end
		task.wait(1)
	end
	for _, b in ipairs(braziers) do
		b.Cv = PD.new("HubBrazier_" .. b.Name, { own = true })
		b.Ring = ringOf(b, b.Cv.Density)
	end
	local shown = true
	RunService.RenderStepped:Connect(function()
		local close = HubLife.Close()
		if not close then
			if shown then
				shown = false
				local t = os.clock()
				for _, b in ipairs(braziers) do
					b.Cv:Begin(t)
					b.Cv:End()
					b.Smoke.Enabled = false
				end
			end
			return
		end
		if not shown then
			shown = true
			for _, b in ipairs(braziers) do b.Smoke.Enabled = true end
		end
		local t = os.clock()
		for _, b in ipairs(braziers) do
			local cv = b.Cv
			cv:Begin(t)
			drawBowl(cv, b, t)
			cv:End()
		end
	end)
end)
