--[[
	HubFireFlicker (LocalScript, StarterPlayerScripts) -- 2026-10-15, on request: the Arcane Observatory hub's brazier
	fires move like fire instead of standing still.

	The hub's flames were one merged mesh per layer; they were split offline into one part per flame and layer
	(hub/observatory_2026_10_07/fire_flicker: tools/pull_studio_meshes.py -> split_flames.py -> Import 3D ->
	install_flames.lua) into ArcaneObservatoryHub.Fires, each part carrying Flame, Layer ("Outer" / "Core"), Base (the
	flame's bottom centre), RestCFrame and RestSize.

	On this client, every flame, on its own clock:
	  * licks: stretches up and thins (and back) on layered noise, the core faster and harder than the outer flame;
	  * sways: leans a few degrees about its base, the core following the outer;
	  * breathes: its Neon colour brightens and dims a touch;
	  * sheds a few embers that rise and die (a ParticleEmitter on the outer flame, the built-in sparkle texture).
	Everything scales about the flame's BASE, so it never lifts off its brazier. No updates while the camera is far.
]]

local RunService = game:GetService("RunService")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Centre = Vector3.new(8000, 0, 8000),
	FarAway = 700,
	Outer = { Hz = 1.6, Stretch = 0.16, Thin = 0.07, Lean = 5, Bright = 0.10 },   -- Lean in degrees
	Core = { Hz = 2.6, Stretch = 0.24, Thin = 0.10, Lean = 3.5, Bright = 0.14 },
	Flick = 0.05, FlickHz = 9,          -- a fast small tremble on top of the slow licks
	Embers = { Rate = 3, Life = { 0.7, 1.3 }, Speed = { 2.5, 5 }, Size = 0.22, Spread = 18 },
	EmberColour = { Color3.fromRGB(255, 196, 80), Color3.fromRGB(255, 90, 20) },
}

local hub = workspace:WaitForChild(Tuning.Hub, 60)
local fires = hub and hub:WaitForChild("Fires", 60)
if not fires then return end

local entries, parts, cfs = {}, {}, {}

local function seed(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
	return h / 1000003 * 100
end

local function addEmbers(part)
	if part:FindFirstChild("HubEmbers") then return end
	local E = Tuning.Embers
	local a = Instance.new("Attachment")
	a.Name = "HubEmbers"
	a.Position = Vector3.new(0, part.Size.Y * 0.15, 0)
	a.Parent = part
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = E.Rate
	pe.Lifetime = NumberRange.new(E.Life[1], E.Life[2])
	pe.Speed = NumberRange.new(E.Speed[1], E.Speed[2])
	pe.SpreadAngle = Vector2.new(E.Spread, E.Spread)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, E.Size), NumberSequenceKeypoint.new(1, 0) })
	pe.Color = ColorSequence.new(Tuning.EmberColour[1], Tuning.EmberColour[2])
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1) })
	pe.LightEmission = 1
	pe.Drag = 1.5
	pe.Acceleration = Vector3.new(0, 1.5, 0)
	pe.Parent = a
end

local function gather()
	table.clear(entries); table.clear(parts)
	for _, p in ipairs(fires:GetChildren()) do
		local layer, base = p:GetAttribute("Layer"), p:GetAttribute("Base")
		local rest, size = p:GetAttribute("RestCFrame"), p:GetAttribute("RestSize")
		if p:IsA("BasePart") and (layer == "Outer" or layer == "Core") and base and rest and size then
			parts[#parts + 1] = p
			entries[#parts] = {
				Part = p, T = Tuning[layer], Base = base, Size = size, Colour = p.Color,
				Off = rest.Position - base, Rot = rest.Rotation, Phase = seed(p:GetAttribute("Flame") or p.Name),
			}
			if layer == "Outer" then addEmbers(p) end
		end
	end
end
gather()
fires.ChildAdded:Connect(function() task.defer(gather) end)

local noise = math.noise
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if #parts == 0 then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - Tuning.Centre).Magnitude > Tuning.FarAway then return end
	local t = os.clock() - t0
	for i, e in ipairs(entries) do
		local T, ph = e.T, e.Phase
		-- slow licks (two octaves) plus a fast tremble; the lean shares the flame's phase so both layers sway together
		local lick = noise(t * T.Hz, ph) * 1.4 + noise(t * T.Hz * 2.3, ph + 7) * 0.6
		local tremble = math.sin(t * Tuning.FlickHz * 2 * math.pi + ph) * Tuning.Flick
		local sy = 1 + T.Stretch * lick + tremble
		local sxz = 1 - T.Thin * lick
		local lean = math.rad(T.Lean)
		local ax = noise(t * 0.7, ph + 20) * 2 * lean
		local az = noise(t * 0.7, ph + 40) * 2 * lean
		local p = e.Part
		p.Size = e.Size * Vector3.new(sxz, sy, sxz)
		local off = Vector3.new(e.Off.X * sxz, e.Off.Y * sy, e.Off.Z * sxz)
		cfs[i] = CFrame.new(e.Base) * CFrame.Angles(ax, 0, az) * CFrame.new(off) * e.Rot
		local b = 1 + T.Bright * lick
		local c = e.Colour
		p.Color = Color3.new(math.min(c.R * b, 1), math.min(c.G * b, 1), math.min(c.B * b, 1))
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
