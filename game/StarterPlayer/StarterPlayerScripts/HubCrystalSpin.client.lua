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
local HubLife = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("HubLife"))

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Axis = Vector3.new(8000, 0, 8000),   -- the crystal's vertical axis (Lights.Light_Crystal stands on it)
	CoreSpeed = 0.12,                    -- radians a second (about 52 s a turn)
	OrbitSpeed = -0.2,                   -- the ring and the rocks, the other way round (about 31 s a turn)
	Bob = 0.35, BobHz = 0.12,            -- the crystal's slow float, studs and cycles a second
	FarAway = 700,                       -- no updates while the camera is further than this from the axis
	-- (2026-10-26, the owner) the crystal breathes light from within, inside a soft round corona: one slow cycle drives
	-- a white fill on its own parts, the light inside it and the corona; Low/High = the cycle's two ends
	Glow = { Period = 5, Colour = Color3.fromRGB(226, 234, 255),
		Fill = { 0.86, 0.66 }, Rim = { 0.8, 0.5 },        -- Highlight Fill/Outline transparency
		Light = { 0.5, 1.6 }, Range = 20,                  -- the light inside (Brightness)
		Corona = { W = 15, H = 25, Alpha = { 0.62, 0.38 }, Res = 256 } },
	-- (2026-10-26, the owner) the rocks one by one: each bobs (studs, cycles a second) and tumbles (radians a second, at
	-- most) on its own; Extra more rocks (copies of the ring's own, turned to new places) at Scale of their size
	Rocks = { Bob = { 0.25, 0.7 }, BobHz = { 0.1, 0.28 }, Turn = { 0.5, 1.3 },   -- (Turn: each rock's own spin, radians a second)
		 Extra = 12, Scale = { 0.6, 1.1 } },
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

-- THE GLOW: a soft white Highlight fill on each of the crystal's own parts (its facets glow from within, no material
-- changes), the light inside it (CrystalGlow), and a camera-facing corona -- a smooth radial bloom painted once
local G = Tuning.Glow
local glow = { Fills = {}, Light = nil, Corona = nil }
local function buildGlow()
	local main = nil
	for _, p in ipairs(spin:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Spin") == "Core" then
			local h = Instance.new("Highlight")
			h.Name = "HubCrystalGlow"
			h.Adornee = p
			h.FillColor, h.OutlineColor = G.Colour, G.Colour
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = p
			glow.Fills[#glow.Fills + 1] = h
			if not main or p.Size.Magnitude > main.Size.Magnitude then main = p end
		end
	end
	if not main then return end
	glow.Light = main:FindFirstChild("CrystalGlow")
	if glow.Light then glow.Light.Range, glow.Light.Color = G.Range, G.Colour end
	local C = G.Corona
	local ok, im = pcall(function() return game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(C.Res, C.Res) }) end)
	if not ok or not im then return end
	local buf = buffer.create(C.Res * C.Res * 4)
	for y = 0, C.Res - 1 do
		for x = 0, C.Res - 1 do
			local dx, dy = (x + 0.5) / C.Res * 2 - 1, (y + 0.5) / C.Res * 2 - 1
			local r2 = dx * dx + dy * dy
			local o = (y * C.Res + x) * 4
			buffer.writeu8(buf, o, 255)
			buffer.writeu8(buf, o + 1, 255)
			buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, r2 < 1 and math.floor((1 - r2) ^ 2.4 * 255 + 0.5) or 0)
		end
	end
	im:WritePixelsBuffer(Vector2.zero, im.Size, buf)
	local bb = Instance.new("BillboardGui")
	bb.Name = "HubCrystalCorona"
	bb.Adornee, bb.Size, bb.LightInfluence, bb.MaxDistance = main, UDim2.fromScale(C.W, C.H), 0, Tuning.FarAway
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency, img.Size, img.ImageColor3 = 1, UDim2.fromScale(1, 1), G.Colour
	img.ImageContent = Content.fromObject(im)
	img.Parent = bb
	bb.Parent = main
	glow.Corona = img
end
pcall(buildGlow)

-- THE ROCKS, ONE BY ONE: each merged rock set (Spin = Orbit, "Stone" in its name) is split on this client into its
-- separate rocks (connected pieces) and hidden locally; every rock rides the orbit with its own bob and tumble, and
-- Extra copies (new angles, varied size) fill the ring out. No room for the meshes, or any failure: the sets stay.
local R = Tuning.Rocks
local rng = Random.new(20261026)
local rocks, rockParts, rockCFs, rockMeshes, rockSets = {}, {}, {}, {}, {}
local rockFolder = nil
local function between(r) return r[1] + (r[2] - r[1]) * rng:NextNumber() end
local function splitSet(set)
	local em = game:GetService("AssetService"):CreateEditableMeshAsync(set.MeshContent)
	local scale = set.Size / set.MeshSize
	local pos, key, parent, tris = {}, {}, {}, {}
	local function find(a)
		while parent[a] ~= a do parent[a] = parent[parent[a]] a = parent[a] end
		return a
	end
	for _, f in ipairs(em:GetFaces()) do
		local vs = em:GetFaceVertices(f)
		if #vs == 3 then
			for _, v in ipairs(vs) do
				if not pos[v] then
					local p = em:GetPosition(v) * scale
					pos[v] = p
					key[v] = string.format("%.3f,%.3f,%.3f", p.X, p.Y, p.Z)
					parent[key[v]] = parent[key[v]] or key[v]
				end
			end
			local r1 = find(key[vs[1]])
			for i = 2, 3 do
				local r = find(key[vs[i]])
				if r ~= r1 then parent[r] = r1 end
			end
			tris[#tris + 1] = vs
		end
	end
	local groups, list = {}, {}
	for _, t in ipairs(tris) do
		local root = find(key[t[1]])
		local g = groups[root]
		if not g then
			g = { V = {}, T = {}, Index = {} }
			groups[root] = g
			list[#list + 1] = g
		end
		for _, v in ipairs(t) do
			local k = key[v]
			if not g.Index[k] then
				local p = pos[v]
				g.V[#g.V + 1] = string.format("%d,%d,%d", math.round(p.X * 1000), math.round(p.Y * 1000), math.round(p.Z * 1000))
				g.Index[k] = #g.V - 1
			end
			g.T[#g.T + 1] = g.Index[k]
		end
	end
	em:Destroy()
	return list
end
local function addRock(set, rel, g, turn, size)
	local m = HubLife.DataMesh(table.concat(g.V, ","), table.concat(g.T, ","))
	if not m then return end
	rockMeshes[#rockMeshes + 1] = m
	local p = m.Part
	p.Name = "HubCrystalRock"
	p.Color, p.Material, p.MaterialVariant = set.Color, set.Material, set.MaterialVariant
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, set.CastShadow
	if size ~= 1 then p.Size *= size end
	p.Parent = rockFolder
	local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	rocks[#rocks + 1] = { Rel = CFrame.Angles(0, turn, 0) * rel * CFrame.new(m.Off), Amp = between(R.Bob), Hz = between(R.BobHz),
		Phase = rng:NextNumber(0, 2 * math.pi), Axis = (axis.Magnitude > 0.05 and axis.Unit or Vector3.yAxis),
		Turn = between(R.Turn) * (rng:NextNumber() < 0.5 and -1 or 1) }
	rockParts[#rockParts + 1] = p
end
local function giveBackRocks()
	table.clear(rocks)
	table.clear(rockParts)
	table.clear(rockCFs)
	for _, m in ipairs(rockMeshes) do pcall(HubLife.Release, m) end
	table.clear(rockMeshes)
	if rockFolder then rockFolder:Destroy() rockFolder = nil end
	for _, s in ipairs(rockSets) do s.LocalTransparencyModifier = 0 end
end
task.spawn(function()
	local ok, err = pcall(function()
		HubLife.WaitBudget()
		rockFolder = Instance.new("Folder")
		rockFolder.Name = "HubCrystalRocks"
		rockFolder.Parent = workspace
		local all = {}
		for i, p in ipairs(parts) do
			if kinds[i] == "Orbit" and p:IsA("MeshPart") and string.find(p.Name, "Stone") then
				local list = splitSet(p)
				for _, g in ipairs(list) do
					addRock(p, rel[i], g, 0, 1)
					all[#all + 1] = { Set = p, Rel = rel[i], G = g }
				end
				rockSets[#rockSets + 1] = p
				p.LocalTransparencyModifier = 1
			end
		end
		for _ = 1, math.min(R.Extra, #all) do
			local pick = all[rng:NextInteger(1, #all)]
			addRock(pick.Set, pick.Rel, pick.G, rng:NextNumber(0.25, 0.75) * math.pi * (rng:NextNumber() < 0.5 and -1 or 1), between(R.Scale))
		end
	end)
	if not ok then
		warn("[HubCrystalSpin] the rocks stay merged: " .. tostring(err))
		giveBackRocks()
	end
end)
-- (2026-10-27, the owner: "only 3 rocks") the rocks no longer give way to MeshBudget: the first skin or wrap build anywhere
-- released them for the session and only the merged originals came back. The room comes from the big optional sets instead.
if false then pcall(function()
	local m = game:GetService("ReplicatedStorage"):FindFirstChild("IceMagic")
	m = m and m:FindFirstChild("MeshBudget")
	if m then require(m).Optional(giveBackRocks) end
end) end

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
	-- every rock: the orbit, its own bob (world Y) and its own spin about its own axis
	if #rockParts > 0 then
		for i, r in ipairs(rocks) do
			rockCFs[i] = CFrame.new(0, r.Amp * math.sin(2 * math.pi * r.Hz * t + r.Phase), 0) * orbit * r.Rel
				* CFrame.fromAxisAngle(r.Axis, r.Turn * t)
		end
		workspace:BulkMoveTo(rockParts, rockCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- the glow breathes: one smooth cycle for the fill, the light inside and the corona
	local k = 0.5 - 0.5 * math.cos(2 * math.pi * t / G.Period)
	for _, h in ipairs(glow.Fills) do
		h.FillTransparency = G.Fill[1] + (G.Fill[2] - G.Fill[1]) * k
		h.OutlineTransparency = G.Rim[1] + (G.Rim[2] - G.Rim[1]) * k
	end
	if glow.Light then glow.Light.Brightness = G.Light[1] + (G.Light[2] - G.Light[1]) * k end
	if glow.Corona then glow.Corona.ImageTransparency = G.Corona.Alpha[1] + (G.Corona.Alpha[2] - G.Corona.Alpha[1]) * k end
end)
