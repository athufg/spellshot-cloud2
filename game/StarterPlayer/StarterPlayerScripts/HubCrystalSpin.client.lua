--[[
	HubCrystalSpin (LocalScript, StarterPlayerScripts) -- 2026-10-15, on request: the Arcane Observatory hub's centre
	crystal turns slowly, and its gold ring and the rocks riding the ring turn with it.

	The hub was imported merged BY MATERIAL, so the crystal, ring and rocks were only triangles inside six of its
	meshes. They were cut out once, offline (hub/observatory_2026_10_07/crystal_spin: tools/pull_studio_meshes.py ->
	split_crystal.py -> Import 3D -> install_crystal_spin.lua), into ArcaneObservatoryHub.CrystalSpin (a Persistent
	model, so streaming never takes it away): parts with the attribute Spin = "Core" (the crystal and its ink outline)
	and Spin = "Orbit" (the ring and its rocks). The six hub meshes were swapped for copies without them.
	(A runtime cut was tried first: an asset mesh is fixed-size in-experience and full copies of six hub meshes run past
	the EditableMesh memory budget.)

	This only moves those parts, on this client: one BulkMoveTo a frame, and none while the camera is far away.
]]

local RunService = game:GetService("RunService")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Axis = Vector3.new(8000, 0, 8000),   -- the crystal's vertical axis (Lights.Light_Crystal stands on it)
	CoreSpeed = 0.12,                    -- radians a second (about 52 s a turn)
	OrbitSpeed = -0.2,                   -- the ring and the rocks, the other way round (about 31 s a turn)
	Bob = 0.35, BobHz = 0.12,            -- the crystal's slow float, studs and cycles a second
	FarAway = 700,                       -- no updates while the camera is further than this from the axis
}

local hub = workspace:WaitForChild(Tuning.Hub, 60)
local spin = hub and hub:WaitForChild("CrystalSpin", 60)
if not spin then return end

local parts, rel, kinds, cfs = {}, {}, {}, {}
local function gather()
	table.clear(parts); table.clear(rel); table.clear(kinds)
	for _, p in ipairs(spin:GetDescendants()) do
		local kind = p:IsA("BasePart") and p:GetAttribute("Spin")
		if kind == "Core" or kind == "Orbit" then
			parts[#parts + 1] = p
			-- where it stands at rest, from the axis (the server never moves it, so this is always the rest pose)
			rel[#parts] = CFrame.new(Tuning.Axis):ToObjectSpace(p:GetAttribute("RestCFrame") or p.CFrame)
			kinds[#parts] = kind
		end
	end
end
gather()
spin.DescendantAdded:Connect(function(d) if d:IsA("BasePart") then task.defer(gather) end end)

local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if #parts == 0 then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - Tuning.Axis).Magnitude > Tuning.FarAway then return end
	local t = os.clock() - t0
	local core = CFrame.new(Tuning.Axis + Vector3.new(0, Tuning.Bob * math.sin(2 * math.pi * Tuning.BobHz * t), 0))
		* CFrame.Angles(0, Tuning.CoreSpeed * t, 0)
	local orbit = CFrame.new(Tuning.Axis) * CFrame.Angles(0, Tuning.OrbitSpeed * t, 0)
	for i = 1, #parts do
		cfs[i] = (kinds[i] == "Core" and core or orbit) * rel[i]
	end
	for i = #parts + 1, #cfs do cfs[i] = nil end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
