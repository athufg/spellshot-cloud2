--[[
	HubAmbient  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubAmbient

	THE HUB, ALIVE: the ambient layer (2026-10-25, the owner's hub-rebuild brief, step 2). Client only, runs only while
	HubLife.On() (Studio until the owner's review), scales with Graphics Quality's effect density, and Reduce Flashing turns
	every flash into a slow swell.

	  LIGHT POOLS  under each archway, in its wing's colour: a SpotLight from the arch's top onto the floor that breathes
	               slowly. (The stepped Neon discs that drew a pool on the floor were removed on 2026-10-25: the owner read
	               them as stray glowing circles -- at the Training mouth, along the Store's path, over the Duels chevrons.)
	  WISPS        one idle wisp per archway, drifting through the mouth on its own slow loop, in the wing's colours, with a
	               trail and a few Element motes (Pyro sparks, Aqua drips, Terra dust, Zephyr streaks).
	  CHEVRONS     pulsing floor arrows in the ceiling trim's yellow down the main entry corridor: from the spawn dais,
	               the way the spawn faces, through the Duels archway; a wave of light runs along them toward Duels.
	(The centre crystal's Reaction cycle -- its glow, halo and burst rings, and the Reaction word over it -- was removed on
	2026-10-26 at the owner's word: the crystal keeps its own look.)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end

local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end
local W = HubLife.Wing

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Pool = { Out = 5.5, Breathe = 0.04, Hz = 0.18,
		Spot = { Angle = 75, Range = 26, Brightness = 1.1 } },
	Wisp = { Size = 0.34, Height = 7, LowArch = 5.2, Side = 0.3, Rise = 2, Depth = 1.6, Period = { 9, 13 }, Light = { Range = 7, Brightness = 0.9 } },
	Chevrons = { From = Vector3.new(8000, 0.04, 8027), Step = Vector3.new(0, 0, 4), Count = 9, Arm = 1.55, Width = 0.34, Angle = 42,
		Period = 1.8, Dim = 0.78, Lit = 0.05 },
}

local folder = Instance.new("Folder")
folder.Name = "HubLife_Ambient"
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	if not props.Parent then p.Parent = folder end
	return p
end

local calm, density = HubLife.Calm(), HubLife.Density()
local emitters = {}
local function rateOf(pe, base)
	emitters[#emitters + 1] = { pe, base }
	pe.Rate = base * density
end
local quality = HubLife.Quality()
local onQuality = {}
HubLife.OnSettings(function()
	calm, density, quality = HubLife.Calm(), HubLife.Density(), HubLife.Quality()
	for _, e in ipairs(emitters) do e[1].Rate = e[2] * density end
	for _, fn in ipairs(onQuality) do fn() end
end)

local tickers = {}
local function onTick(fn) tickers[#tickers + 1] = fn end

----------------------------------------------------------------------------------------------------
-- LIGHT POOLS and WISPS
----------------------------------------------------------------------------------------------------
local pools, wisps = {}, {}
for name, A in pairs(HubLife.Arch) do
	local col = W[A.Element]
	local P = Tuning.Pool
	local top = part({ Name = "HubLife_PoolLight_" .. name, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(A.At + A.In * (P.Out * 0.4) + Vector3.new(0, math.min(A.Height, 16), 0)) })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle, spot.Range, spot.Brightness, spot.Shadows = P.Spot.Angle, P.Spot.Range, P.Spot.Brightness, false
	spot.Color = col.Light:Lerp(col.Base, 0.4)
	spot.Parent = top
	pools[#pools + 1] = { Spot = spot, Seed = #pools * 1.7 }

	-- the wisp
	local WS = Tuning.Wisp
	local h = (A.Height <= 12) and WS.LowArch or WS.Height
	local orb = part({ Name = "HubLife_Wisp_" .. name, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
		Color = col.Light, Size = Vector3.new(WS.Size, WS.Size, WS.Size), CFrame = CFrame.new(A.At + Vector3.new(0, h, 0)) })
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, WS.Size * 0.4, 0), Vector3.new(0, -WS.Size * 0.4, 0)
	a0.Parent, a1.Parent = orb, orb
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = (A.Element == "Zephyr") and 0.9 or 0.55
	tr.FaceCamera = true
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Color = ColorSequence.new(col.Light, col.Base)
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = orb
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = col.Light, WS.Light.Range, WS.Light.Brightness, false
	light.Parent = orb
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "HubLifeMotes"
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.Color = ColorSequence.new(col.Light, col.Base)
	if A.Element == "Pyro" then
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Lifetime, pe.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(0.6, 1.4)
		pe.Acceleration = Vector3.new(0, 2.5, 0)
		pe.Size = NumberSequence.new(0.12, 0.02)
		rateOf(pe, 6)
	elseif A.Element == "Aqua" then
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Lifetime, pe.Speed = NumberRange.new(0.5, 0.8), NumberRange.new(0.2, 0.6)
		pe.Acceleration = Vector3.new(0, -9, 0)
		pe.Size = NumberSequence.new(0.1, 0.04)
		rateOf(pe, 5)
	elseif A.Element == "Terra" then
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Lifetime, pe.Speed = NumberRange.new(0.9, 1.4), NumberRange.new(0.1, 0.4)
		pe.Acceleration = Vector3.new(0, -0.6, 0)
		pe.Size = NumberSequence.new(0.09, 0.03)
		rateOf(pe, 4)
	else
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Lifetime, pe.Speed = NumberRange.new(0.4, 0.7), NumberRange.new(1.5, 2.5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.08, 0.02)
		rateOf(pe, 4)
	end
	pe.Transparency = NumberSequence.new(0.1, 1)
	pe.Parent = orb
	local width = A.Width
	wisps[#wisps + 1] = { Part = orb, Centre = A.At + A.In * 1.5 + Vector3.new(0, h, 0), Across = A.In:Cross(Vector3.yAxis).Unit,
		In = A.In, Span = width * Tuning.Wisp.Side, Period = WS.Period[1] + (#wisps % 3) * (WS.Period[2] - WS.Period[1]) / 2, Seed = #wisps * 2.3,
		Rise = (A.Height <= 12) and 1.2 or WS.Rise }
end
local moveParts, moveCFs = {}, {}
onTick(function(t)
	local P = Tuning.Pool
	for _, pl in ipairs(pools) do
		local b = math.sin(t * P.Hz * math.pi * 2 + pl.Seed) * P.Breathe
		pl.Spot.Brightness = P.Spot.Brightness * (1 + b * 2)
	end
	table.clear(moveParts)
	table.clear(moveCFs)
	for _, w in ipairs(wisps) do
		local th = (t / w.Period) * math.pi * 2 + w.Seed
		local pos = w.Centre + w.Across * (math.sin(th) * w.Span) + Vector3.yAxis * (math.sin(th * 2 + 0.7) * w.Rise)
			+ w.In * (math.cos(th * 1.5) * Tuning.Wisp.Depth)
		moveParts[#moveParts + 1] = w.Part
		moveCFs[#moveCFs + 1] = CFrame.new(pos)
	end
	workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
end)

----------------------------------------------------------------------------------------------------
-- CHEVRONS down the entry corridor
----------------------------------------------------------------------------------------------------
do
	local CH = Tuning.Chevrons
	local chevrons = {}
	for i = 1, CH.Count do
		local at = CH.From + CH.Step * (i - 1)
		local fwd = CH.Step.Unit
		local arms = {}
		for s = -1, 1, 2 do
			-- each arm runs from the tip back and out: the V points the way to Duels
			local dir = CFrame.Angles(0, math.rad(CH.Angle) * s, 0):VectorToWorldSpace(-fwd)
			local centre = at + dir * (CH.Arm / 2)
			local p = part({ Name = "HubLife_Chevron", Material = Enum.Material.Neon, Color = HubLife.TrimYellow,
				Size = Vector3.new(CH.Width, 0.03, CH.Arm), CFrame = CFrame.lookAt(centre, centre + dir), Transparency = CH.Dim })
			arms[#arms + 1] = p
		end
		chevrons[i] = arms
	end
	onTick(function(t)
		local per = calm and CH.Period * 2 or CH.Period
		for i, arms in ipairs(chevrons) do
			local ph = ((t / per) - (i - 1) / CH.Count) % 1
			local k = math.max(0, 1 - math.abs(ph - 0.12) / 0.22)
			k = k * k * (3 - 2 * k)
			if calm then k = k * 0.5 end
			local tr = CH.Dim + (CH.Lit - CH.Dim) * k
			for _, p in ipairs(arms) do p.Transparency = tr end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- the clock
----------------------------------------------------------------------------------------------------
local t0 = os.clock()
local broken = {}
RunService.RenderStepped:Connect(function()
	if not HubLife.Close() then return end
	local t = os.clock() - t0
	for i, fn in ipairs(tickers) do
		if not broken[i] then
			local ok, err = pcall(fn, t)
			if not ok then
				broken[i] = true
				warn("[HubAmbient] " .. tostring(err))
			end
		end
	end
end)
folder:SetAttribute("Ready", true)
