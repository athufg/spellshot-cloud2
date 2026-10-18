--[[
	HubLanternFlicker (LocalScript, StarterPlayerScripts) -- 2026-10-15, on request: the Arcane Observatory hub's lanterns
	flicker like flames.

	Every lantern is two things in the hub: its glowing panes (triangles in the merged Neon mesh
	Visual.OBS_Lantern_Glow_01, 772 of them for the whole hub) and a PointLight on a part in Lights (Light_Lantern*).
	On this client:
	  * the glow mesh is split once at runtime into one MeshPart per lantern (each triangle goes to the nearest lantern
	    light; a triangle with none near goes to its own 3-stud cell) and the merged original is hidden locally. The
	    mesh is small, so this stays far inside the EditableMesh limits (build resizable, copy fixed; one resizable at
	    a time);
	  * every lantern then flickers slowly on its own clock and tempo -- a slow waver, a gentle drift and now and then a
	    soft gutter -- its
	    panes' Neon brightness and its PointLight's Brightness moving together.
	If the split fails the lights still flicker and the panes stay as they were. Nothing changes on the server.
]]

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Glow = "OBS_Lantern_Glow_01",
	Centre = Vector3.new(8000, 0, 8000),
	FarAway = 500,                       -- no updates while the camera is further than this
	Near = 3.5,                          -- studs: a pane triangle belongs to a lantern light this close
	Cell = 3,                            -- studs: panes with no light near are grouped in cells this size
	-- 2026-10-15, owner: "too fast -- every lantern should flick slowly and randomly". All noise now (no regular sine),
	-- slow, and each lantern on its own tempo (Tempo: a per-lantern multiplier picked from this range)
	Waver = { Hz = 0.45, Amount = 0.14 },
	Drift = { Hz = 1.1, Amount = 0.05 },                -- a gentler, quicker layer on top, still smooth
	Sputter = { Hz = 0.08, From = 0.34, Dip = 0.3 },    -- now and then (when the slowest noise passes From) it gutters
	Tempo = { 0.6, 1.4 },
	PaneMax = 1.35,                      -- the panes' brightest, as a multiple of their colour
}

local hub = workspace:WaitForChild(Tuning.Hub, 60)
if not hub then return end
local visual = hub:WaitForChild("Visual", 60)
local lightsFolder = hub:WaitForChild("Lights", 60)
if not (visual and lightsFolder) then return end

local folder = Instance.new("Folder")
folder.Name = "HubLanternFlicker"
folder.Parent = workspace

local function seed(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
	return h / 1000003 * 100
end

-- the lantern lights: [part] = { Light, Brightness, Phase }
local lanterns = {}
local function addLight(part)
	if lanterns[part] or not part:IsA("BasePart") or not part.Name:find("Lantern") then return end
	local light = part:FindFirstChildWhichIsA("Light")
	if not light then return end
	lanterns[part] = { Light = light, Brightness = light.Brightness, Phase = seed(part.Name), Panes = {} }
end
for _, p in ipairs(lightsFolder:GetChildren()) do addLight(p) end
lightsFolder.ChildAdded:Connect(function(p) task.defer(addLight, p) end)

-- the panes: one MeshPart per lantern (or per cell), built from the merged glow mesh
local panes = {}   -- { Part, Colour, Owner (a lantern entry or a phase holder) }
local keep = {}
local hiddenGlow = false

local function hideGlow(part)
	if hiddenGlow and part.Name == Tuning.Glow then part.Transparency = 1 end
end

local function split(source)
	local src = AssetService:CreateEditableMeshAsync(source.MeshContent)
	local cf, scale = source.CFrame, source.Size / source.MeshSize
	local groups, order = {}, {}
	for _, f in ipairs(src:GetFaces()) do
		local vs = src:GetFaceVertices(f)
		local c = Vector3.zero
		for _, v in ipairs(vs) do c += src:GetPosition(v) end
		c = cf:PointToWorldSpace(c / #vs * scale)
		local owner, best = nil, Tuning.Near
		for part in pairs(lanterns) do
			local d = (part.Position - c).Magnitude
			if d < best then owner, best = part, d end
		end
		local key = owner or ("cell" .. math.floor(c.X / Tuning.Cell) .. "," .. math.floor(c.Y / Tuning.Cell) .. ","
			.. math.floor(c.Z / Tuning.Cell))
		local g = groups[key]
		if not g then
			g = { Faces = {} }
			groups[key] = g
			order[#order + 1] = key
		end
		table.insert(g.Faces, f)
	end
	local built = {}
	for _, key in ipairs(order) do
		local g = groups[key]
		-- the group's box centre: the mesh is written around it, so the part sits there whichever way a MeshPart
		-- centres an EditableMesh
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, f in ipairs(g.Faces) do
			for _, v in ipairs(src:GetFaceVertices(f)) do
				local p = cf:PointToWorldSpace(src:GetPosition(v) * scale)
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
		local centre = (lo + hi) / 2
		local em = AssetService:CreateEditableMesh()
		local vmap, nmap = {}, {}
		for _, f in ipairs(g.Faces) do
			local vs, ns = src:GetFaceVertices(f), src:GetFaceNormals(f)
			if #vs == 3 then
				local ids = table.create(3)
				for i, v in ipairs(vs) do
					local id = vmap[v]
					if not id then
						id = em:AddVertex(cf:PointToWorldSpace(src:GetPosition(v) * scale) - centre)
						vmap[v] = id
					end
					ids[i] = id
				end
				local nf = em:AddTriangle(ids[1], ids[2], ids[3])
				if #ns == 3 then
					local nids = table.create(3)
					for i, n in ipairs(ns) do
						local id = nmap[n]
						if not id then
							id = em:AddNormal(cf:VectorToWorldSpace(src:GetNormal(n)))
							nmap[n] = id
						end
						nids[i] = id
					end
					em:SetFaceNormals(nf, nids)
				end
			end
		end
		local fixed = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
		em:Destroy()
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(fixed))
		keep[#keep + 1] = fixed
		part.Name = "Panes"
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
		part.Material, part.Color, part.Transparency = source.Material, source.Color, source.Transparency
		part.CFrame = CFrame.new(centre)
		built[#built + 1] = { Part = part, Key = key }
	end
	src:Destroy()
	return built
end

task.spawn(function()
	local source = visual:WaitForChild(Tuning.Glow, 120)
	if not (source and source:IsA("MeshPart")) then return end
	task.wait(1)   -- let the lantern lights stream in first
	local ok, built = pcall(split, source)
	if not ok then
		warn("[HubLanternFlicker] could not split the lantern panes (the lights still flicker): " .. tostring(built))
		for _, em in ipairs(keep) do em:Destroy() end
		return
	end
	for _, b in ipairs(built) do
		local owner = typeof(b.Key) == "Instance" and lanterns[b.Key] or { Phase = seed(tostring(b.Key)) }
		b.Part.Parent = folder
		table.insert(panes, { Part = b.Part, Colour = b.Part.Color, Owner = owner })
	end
	hiddenGlow = true
	hideGlow(source)
	visual.ChildAdded:Connect(hideGlow)   -- streaming may bring the merged original back
end)

local noise = math.noise
local function level(phase, t)
	local W, D, P = Tuning.Waver, Tuning.Drift, Tuning.Sputter
	-- this lantern's own tempo, fixed by its phase (so a lantern and its panes always agree)
	local lo, hi = Tuning.Tempo[1], Tuning.Tempo[2]
	t *= lo + (hi - lo) * ((phase * 7.31) % 1)
	local b = 1 + W.Amount * 2 * noise(t * W.Hz, phase) + D.Amount * 2 * noise(t * D.Hz, phase + 25)
	local slow = noise(t * P.Hz, phase + 50)
	if slow > P.From then b -= P.Dip * math.min((slow - P.From) / 0.15, 1) end
	return math.max(b, 0.35)
end

local t0 = os.clock()
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - Tuning.Centre).Magnitude > Tuning.FarAway then return end
	local t = os.clock() - t0
	for part, l in pairs(lanterns) do
		if part.Parent then
			l.Level = level(l.Phase, t)
			l.Light.Brightness = l.Brightness * l.Level
		else
			lanterns[part] = nil
		end
	end
	for _, p in ipairs(panes) do
		local b = math.min(p.Owner.Level or level(p.Owner.Phase, t), Tuning.PaneMax)
		local c = p.Colour
		p.Part.Color = Color3.new(math.min(c.R * b, 1), math.min(c.G * b, 1), math.min(c.B * b, 1))
	end
end)
