--[[
	HubWaterfall  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubWaterfall

	THE TRAINING WING's WATERFALLS AS REAL WATER (2026-10-25, the owner: "still a static glow column with painted droplet
	decals, not moving water"). Client only, runs only while HubLife.On() (Studio until the owner's review).

	The four falls (the two at the Training entrance, the two by the portal) were baked into the hub's merged
	OBS_Water_Lit_01 mesh: four glowing streaks per fall, painted teardrops and two still rings in each basin. On this
	client that mesh is hidden and redrawn WITHOUT the falls (its other pieces -- the Training room's two small fountains
	and the floor channels, and each fall's top lip -- are copied as they were); the dark recess panels and the basin pools
	are another mesh and stay. Then each fall gets:
	  * THE WATER (rebuilt 2026-10-26, the owner: the old vertex-colour sheet read as soft blotchy noise): each fall is a
	    curved, unlit sheet ON the old sheet's own curve (SurfaceGui strips, lip to basin, over the recess panel), layered like a stylized-water
	    shader -- a deep-to-Aqua base, FLOW (long soft streaks, the direction) in two depths, RIPPLES (finer crisp-edged
	    wavy crests) on top, GLINTS (sharp white highlight streaks) over all, darker side edges, white over the lip and
	    where it lands. Every layer is a tile painted once per client (EditableImage) and scrolls down at its own speed.
	  * AT THE BASE: foam boiling up where the sheet lands, splash droplets thrown out in arcs, a low mist, a white churn
	    ring, and RIPPLE RINGS spreading across the basin.
	HubWaterFlow's beads, drips and splashes (2026-10-15) are switched off on this client for these falls -- this replaces
	them. Graphics Quality scales the particles and the ripple rate (the water's layers scroll every frame at every setting);
	nothing flashes. The meshes are OPTIONAL (MeshBudget): if a worn skin's build needs the room, the falls go back to
	the baked look and HubWaterFlow comes back on.
	Measured 2026-10-25 from OBS_Water_Deep_01 (the recess panels) and OBS_Water_Lit_01 (the basins' rings).
]]

local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end

local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end
local A = HubLife.Wing.Aqua

-- EVERY NUMBER HERE IS A PROPOSAL
-- each fall: the front face of its recess panel (a point on it at floor height), the way it faces the hub (N), the
-- panel's width, the top of the water, the basin's water surface and the basin's radius
local FALLS = {
	{ Front = Vector3.new(8033.272, 0, 8033.845), N = Vector3.new(-0.7004, 0.0387, -0.7127), D = 0.016, Lat = 0, Width = 1.36, Top = 8.75, Basin = 1.45, Radius = 1.43 },
	{ Front = Vector3.new(8035.766, 0, 7988.254), N = Vector3.new(-0.9489, 0.0365, 0.3135), D = -0.063, Lat = 0.075, Width = 1.53, Top = 11.0, Basin = 1.67, Radius = 1.65 },
	{ Front = Vector3.new(8096.885, 0, 8004.396), N = Vector3.new(-0.9799, 0.0369, 0.1958), D = -0.048, Lat = 0.05, Width = 1.12, Top = 8.06, Basin = 1.23, Radius = 1.20 },
	{ Front = Vector3.new(8092.575, 0, 8029.072), N = Vector3.new(-0.8538, 0.0391, -0.5191), D = 0.003, Lat = 0, Width = 1.15, Top = 7.40, Basin = 1.23, Radius = 1.22 },
}
local Tuning = {
	Sheet = { Inset = 0.03, Arc = 0, Curl = 0, Spread = 0.08, Waver = 0, Speed = 9, Near = 75 },   -- (Arc/Curl 0: flat on the panel, no gap)   -- (the plane's line; Near: scrolls)
	-- the layers: tile W x H px (PPS px a stud, x Scale), Speed x Sheet.Speed, tinted Tint at Transparency
	Water = { PPS = 48, Brightness = 1.2, Segments = 8, Cover = 1.14,   -- (Segments: strips down the curve; Cover: x the sheet width, over the whole recess panel)
		Layers = {
			{ Tile = "Flow", W = 96, H = 256, Speed = 0.35, Scale = 1.6, Tint = "Deep", Transparency = 0.15, X = 37 },
			{ Tile = "Flow", W = 96, H = 256, Speed = 0.6, Scale = 1, Tint = "Light", Transparency = 0.2, X = 0 },
			{ Tile = "Ripple", W = 64, H = 96, Speed = 0.8, Scale = 1, Tint = "Crest", Transparency = 0.35, X = 11 },
			{ Tile = "Glint", W = 96, H = 256, Speed = 1.05, Scale = 1, Tint = "Foam", Transparency = 0, X = 23 },
		} },
	-- the sheet is Neon, so its colour IS its glow: mostly deep water, Aqua's light only on the streaks' crests
	Colours = { Deep = A.Base:Lerp(Color3.new(0, 0, 0), 0.62), Base = A.Base:Lerp(Color3.new(0, 0, 0), 0.15), Light = A.Light,
		Foam = Color3.fromHex("E6FAFF") },
	Foam = { Rate = 26, Life = { 0.35, 0.7 }, Speed = { 1.2, 2.6 }, Size = { 0.32, 0.85 }, Spread = 75 },
	Splash = { Rate = 22, Life = { 0.35, 0.6 }, Speed = { 4, 7 }, Size = { 0.12, 0.05 }, Spread = 55, Gravity = 30 },
	Mist = { Rate = 3, Life = { 1.2, 1.8 }, Size = { 1.0, 2.2 }, Transparency = 0.8 },
	Lip = { Rate = 6 },
	Churn = { Radius = { 0.55, 0.8 }, Hz = 3.2, Transparency = 0.5 },
	Ripple = { Every = 0.45, Life = 1.4, From = 0.35, Transparency = 0.12, Inner = 0.87, Pool = 5 },
	Near = 130,                        -- studs from the Training wing: nothing animates further away
	Wing = Vector3.new(8062, 0, 8011),
}

local folder = Instance.new("Folder")
folder.Name = "HubLife_Waterfalls"
folder.Parent = workspace

local density, quality = HubLife.Density(), HubLife.Quality()
local emitters = {}
local function rateOf(pe, base)
	emitters[#emitters + 1] = { pe, base }
	pe.Rate = base * density
end
HubLife.OnSettings(function()
	density, quality = HubLife.Density(), HubLife.Quality()
	for _, e in ipairs(emitters) do e[1].Rate = e[2] * density end
end)

local function smooth(a, b, x)
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

----------------------------------------------------------------------------------------------------
-- the baked falls go: OBS_Water_Lit_01 hidden, its other pieces redrawn
----------------------------------------------------------------------------------------------------
local visual = hub:WaitForChild("Visual", 30)
local lit = visual and visual:WaitForChild("OBS_Water_Lit_01", 30)
local litCopy, litMesh, given = nil, nil, false
local waterFlowOff = {}            -- [instance] = Enabled before

local function nearFall(p)
	for _, f in ipairs(FALLS) do
		local d = Vector3.new(p.X - f.Front.X, 0, p.Z - f.Front.Z).Magnitude
		if d < 3.5 then return f end
	end
	return nil
end

-- the triangles of OBS_Water_Lit_01 that are NOT a fall (the fountains, the floor channels),
-- in world space, grouped into connected pieces first so a piece is kept or dropped whole
local function litWithoutFalls()
	local okE, em = pcall(function() return AssetService:CreateEditableMeshAsync(lit.MeshContent) end)
	if not okE then return nil, em end
	local scale = lit.Size / lit.MeshSize
	local cf = lit.CFrame
	local faces = em:GetFaces()
	local world, key = {}, {}
	local parent = {}
	local function find(a)
		while parent[a] ~= a do
			parent[a] = parent[parent[a]]
			a = parent[a]
		end
		return a
	end
	local tris = {}
	for _, f in ipairs(faces) do
		local vs = em:GetFaceVertices(f)
		local t = {}
		for i, v in ipairs(vs) do
			local w = world[v]
			if not w then
				w = cf:PointToWorldSpace(em:GetPosition(v) * scale)
				world[v] = w
				local k = string.format("%.2f,%.2f,%.2f", w.X, w.Y, w.Z)
				key[v] = k
				parent[k] = parent[k] or k
			end
			t[i] = v
		end
		if #t == 3 then
			tris[#tris + 1] = t
			local r1 = find(key[t[1]])
			for i = 2, 3 do
				local r = find(key[t[i]])
				if r ~= r1 then parent[r] = r1 end
			end
		end
	end
	-- each piece's height range
	local lo, hi = {}, {}
	for _, t in ipairs(tris) do
		local r = find(key[t[1]])
		for _, v in ipairs(t) do
			local y = world[v].Y
			lo[r] = math.min(lo[r] or math.huge, y)
			hi[r] = math.max(hi[r] or -math.huge, y)
		end
	end
	local keep = {}
	for _, t in ipairs(tris) do
		local r = find(key[t[1]])
		local f = nearFall(world[t[1]])
		-- every piece of a fall is dropped (streaks, teardrops, the basin's still rings, and -- 2026-10-26, the owner -- the
		-- glowing lip block at its top: the new water itself comes out of the ledge there)
		if not f then
			keep[#keep + 1] = { world[t[1]], world[t[2]], world[t[3]] }
		end
	end
	em:Destroy()
	return keep
end

local function hideLit()
	if lit and lit.Transparency < 1 then lit.Transparency = 1 end
end

----------------------------------------------------------------------------------------------------
-- HubWaterFlow's beads, drips and splashes: off on this client (this replaces them)
----------------------------------------------------------------------------------------------------
local function quietWaterFlow(d)
	if d:IsA("Beam") or d:IsA("ParticleEmitter") then
		if waterFlowOff[d] == nil then waterFlowOff[d] = d.Enabled end
		d.Enabled = false
	end
end
task.spawn(function()
	local wf = workspace:WaitForChild("HubWaterFlow", 30)
	if not wf or given then return end
	for _, d in ipairs(wf:GetDescendants()) do quietWaterFlow(d) end
	wf.DescendantAdded:Connect(function(d) if not given then quietWaterFlow(d) end end)
end)

----------------------------------------------------------------------------------------------------
-- the sheets: one live mesh for all four
----------------------------------------------------------------------------------------------------
local S = Tuning.Sheet
local water, waterImages = nil, {}           -- (water: the falls' planes are up)
local function sheetPoint(f, u, v, t, i, j)
	local n = f.N.Unit
	local nh = Vector3.new(n.X, 0, n.Z).Unit
	local tan = nh:Cross(Vector3.yAxis).Unit
	local H = f.Top - f.Basin
	local y = f.Top - v * H
	local waver = S.Waver * math.sin(t * 9 + j * 0.7 + f.Seed) * (1 - math.abs(u) * 1.4) * math.min(1, v * 8)
	local depth = S.Inset + S.Arc * v * v + waver
	local lateral = u * f.Width * 0.98 * (1 + S.Spread * v) + 0.015 * math.sin(t * 6.3 + j * 0.9 + f.Seed)
	if v < 0.06 then depth += S.Curl * (1 - v / 0.06) end          -- the curl over the lip
	-- on the recess panel's own face (n . (p - Front) = D, measured off OBS_Water_Deep_01 2026-10-26: it leans back a
	-- touch), depth in front of it: the water lies ON the old panel, no gap
	local q = f.Front + tan * (lateral + (f.Lat or 0)) + Vector3.new(0, y, 0)
	return q + nh * (((f.D or 0) + depth - n:Dot(q - f.Front)) / n:Dot(nh))
end
-- the layer tiles: painted once per client, white (each layer tints its own), every one wrapping both ways
local TAU = 2 * math.pi
local Tiles = {}
-- FLOW: long soft streaks running down, of varied widths, broken into lengths
function Tiles.Flow(x, y, w, h)
	local u, v = x / w, y / h
	local col = 0.5 + 0.5 * math.sin(TAU * 4 * u + 2 * math.sin(TAU * u))
	local len = 0.5 + 0.5 * math.sin(TAU * 2 * v + 3 * math.sin(TAU * 2 * u) + 1.7 * math.sin(TAU * 5 * u))
	return smooth(0.4, 0.95, col * (0.5 + 0.5 * len)) * 0.85
end
-- RIPPLE: thin crisp crests across the fall, wavy, broken into dashes
function Tiles.Ripple(x, y, w, h)
	local u = x / w
	local P = h / 3                                          -- (three crests a tile)
	local yy = y + 5 * math.sin(TAU * 2 * u) + 3 * math.sin(TAU * 3 * u + 1)
	local g = (yy / P) % 1
	local line = math.clamp(1.6 - math.min(g, 1 - g) * P, 0, 1)
	local dash = smooth(0.15, 0.55, math.sin(TAU * 3 * u + (math.floor(yy / P) % 3) * 2.4))
	return line * dash
end
-- GLINT: a few sharp highlight streaks, pointed at both ends: a bright core and a faint halo
local GLINTS = { { 0.12, 0.05, 46 }, { 0.31, 0.42, 30 }, { 0.47, 0.18, 58 }, { 0.63, 0.66, 38 }, { 0.78, 0.31, 26 },
	{ 0.9, 0.84, 50 }, { 0.22, 0.75, 34 }, { 0.55, 0.92, 22 }, { 0.04, 0.58, 28 } }      -- { x, y (of the tile), length px }
function Tiles.Glint(x, y, w, h)
	local a = 0
	for _, g in ipairs(GLINTS) do
		local dx, dy = x - g[1] * w, y - g[2] * h
		dx -= w * math.floor(dx / w + 0.5)
		dy -= h * math.floor(dy / h + 0.5)
		local k = math.abs(dy) / (g[3] / 2)
		if k < 1 then
			local d = math.abs(dx) - 1.3 * math.sqrt(1 - k * k)
			a = math.max(a, math.clamp(0.5 - d, 0, 1), 0.35 * math.exp(-math.max(d, 0) / 1.5) * (1 - k))
		end
	end
	return a
end
local function paintTile(name, w, h)
	local im = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	waterImages[#waterImages + 1] = im
	local buf = buffer.create(w * h * 4)
	local fn = Tiles[name]
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local o = (y * w + x) * 4
			buffer.writeu8(buf, o, 255)
			buffer.writeu8(buf, o + 1, 255)
			buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, math.floor(math.clamp(fn(x + 0.5, y + 0.5, w, h), 0, 1) * 255 + 0.5))
		end
	end
	im:WritePixelsBuffer(Vector2.zero, im.Size, buf)
	return im
end

local function gradient(parent, rotation, keys)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	local seq = {}
	for _, k in ipairs(keys) do seq[#seq + 1] = NumberSequenceKeypoint.new(k[1], k[2]) end
	g.Transparency = NumberSequence.new(seq)
	g.Parent = parent
	return g
end
local function sheetFrame(parent, colour, pos, size, z)
	local fr = Instance.new("Frame")
	fr.BackgroundColor3, fr.BorderSizePixel, fr.Position, fr.Size, fr.ZIndex = colour, 0, pos, size, z
	fr.Parent = parent
	return fr
end

--- each fall's plane through the sheet's line (lip to basin), its SurfaceGui, the base, the layers, the edges
local function buildWater()
	local C, W = Tuning.Colours, Tuning.Water
	local tiles = {}
	for _, L in ipairs(W.Layers) do
		local key = L.Tile .. L.W .. "x" .. L.H
		tiles[key] = tiles[key] or paintTile(L.Tile, L.W, L.H)
	end
	local function baseColour(v)                             -- deep at the lip, Aqua lower down
		if v < 0.35 then return C.Deep:Lerp(C.Base, v / 0.35) end
		return C.Base:Lerp(C.Base:Lerp(C.Light, 0.3), (v - 0.35) / 0.65)
	end
	local function foamT(v)                                  -- white over the lip and where it lands
		if v < 0.07 then return 0.15 + 0.85 * v / 0.07 end
		if v > 0.8 then return 1 - 0.75 * (v - 0.8) / 0.2 end
		return 1
	end
	for fi, f in ipairs(FALLS) do
		f.Seed = fi * 3.7
		local n = f.N.Unit
		local layers = {}
		local run = 0                                        -- px down the fall so far: the layers run on across the strips
		for si = 1, W.Segments do
			local v0, v1 = (si - 1) / W.Segments, si / W.Segments
			local vm = (v0 + v1) / 2
			local top, bottom = sheetPoint(f, 0, v0, 0, 0, 0), sheetPoint(f, 0, v1, 0, 0, 0)
			local width = (sheetPoint(f, 0.5, vm, 0, 0, 0) - sheetPoint(f, -0.5, vm, 0, 0, 0)).Magnitude * W.Cover
			local len = (top - bottom).Magnitude
			local up = (top - bottom).Unit
			local back = -(n - up * n:Dot(up)).Unit             -- (the Front face looks into the hall)
			local part = Instance.new("Part")
			part.Name = "HubLife_Water"
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
			part.Transparency = 1
			part.Size = Vector3.new(width, len + 0.01, 0.05)
			part.CFrame = CFrame.fromMatrix((top + bottom) / 2, up:Cross(back), up, back)
			part.Parent = folder
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = W.PPS
			sg.LightInfluence = 0
			sg.Brightness = W.Brightness
			sg.ClipsDescendants = true
			sg.Parent = part
			local base = sheetFrame(sg, Color3.new(1, 1, 1), UDim2.new(), UDim2.fromScale(1, 1), 1)
			local bg = Instance.new("UIGradient")
			bg.Rotation = 90
			bg.Color = ColorSequence.new(baseColour(v0), baseColour(v1))
			bg.Parent = base
			for li, L in ipairs(W.Layers) do
				local tw, th = L.W * L.Scale, L.H * L.Scale
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.ImageContent = Content.fromObject(tiles[L.Tile .. L.W .. "x" .. L.H])
				img.ImageColor3 = (L.Tint == "Crest") and C.Light:Lerp(Color3.new(1, 1, 1), 0.35) or C[L.Tint]
				img.ImageTransparency = L.Transparency
				img.ScaleType = Enum.ScaleType.Tile
				img.TileSize = UDim2.fromOffset(tw, th)
				img.Size = UDim2.new(1, tw, 1, th)
				img.ZIndex = 1 + li
				img.Parent = sg
				layers[#layers + 1] = { Label = img, H = th, X = -((L.X + fi * 13) % tw), Px = S.Speed * L.Speed * W.PPS, Run = run }
			end
			-- the side edges darker (a body of water, not a lit panel); the foam
			gradient(sheetFrame(sg, C.Deep, UDim2.new(), UDim2.fromScale(1, 1), 10), 0,
				{ { 0, 0.2 }, { 0.16, 1 }, { 0.84, 1 }, { 1, 0.2 } })
			local keys = {}
			for k = 0, 4 do keys[#keys + 1] = { k / 4, foamT(v0 + (v1 - v0) * k / 4) } end
			gradient(sheetFrame(sg, C.Foam, UDim2.new(), UDim2.fromScale(1, 1), 11), 90, keys)
			run += len * W.PPS
		end
		f.Water = { Centre = sheetPoint(f, 0, 0.5, 0, 0, 0), Layers = layers }
	end
	water = true
end

----------------------------------------------------------------------------------------------------
-- the base of each fall: foam, splash, mist, churn ring, ripples
----------------------------------------------------------------------------------------------------
local bases = {}
local function landing(f)
	local n = f.N.Unit
	return f.Front + n * (S.Inset + S.Arc) + Vector3.new(0, f.Basin + 0.06, 0)
end
local function emitter(parent, props, base)
	local pe = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do pe[k] = v end
	pe.Parent = parent
	rateOf(pe, base)
	return pe
end
local function buildBases()
	local C = Tuning.Colours
	for _, f in ipairs(FALLS) do
		local at = landing(f)
		local n = f.N.Unit
		local holder = Instance.new("Part")
		holder.Name = "HubLife_FallBase"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(at)                                   -- (its Top face is the water's up)
		holder.Parent = folder
		local a = Instance.new("Attachment")
		a.Parent = holder
		local F, SP, M = Tuning.Foam, Tuning.Splash, Tuning.Mist
		emitter(a, { Name = "HubLifeFoam", Texture = "rbxasset://textures/particles/smoke_main.dds",
			Lifetime = NumberRange.new(F.Life[1], F.Life[2]), Speed = NumberRange.new(F.Speed[1], F.Speed[2]),
			SpreadAngle = Vector2.new(F.Spread, F.Spread), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -6, 0),
			Drag = 2.5, RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, F.Size[1]), NumberSequenceKeypoint.new(1, F.Size[2]) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(C.Foam, C.Light), LightEmission = 0.2, LightInfluence = 0.5 }, F.Rate)
		emitter(a, { Name = "HubLifeSplash", Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Lifetime = NumberRange.new(SP.Life[1], SP.Life[2]), Speed = NumberRange.new(SP.Speed[1], SP.Speed[2]),
			SpreadAngle = Vector2.new(SP.Spread, SP.Spread), EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -SP.Gravity, 0), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = NumberSequence.new(1.4),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, SP.Size[1]), NumberSequenceKeypoint.new(1, SP.Size[2]) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) }),
			Color = ColorSequence.new(C.Foam, C.Light), LightEmission = 1, LightInfluence = 0 }, SP.Rate)
		emitter(a, { Name = "HubLifeMist", Texture = "rbxasset://textures/particles/smoke_main.dds",
			Lifetime = NumberRange.new(M.Life[1], M.Life[2]), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, M.Size[1]), NumberSequenceKeypoint.new(1, M.Size[2]) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, M.Transparency),
				NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(C.Foam), LightEmission = 0.3, LightInfluence = 0.5 }, M.Rate)
		-- a few drops spilling off the lip
		local lipAt = f.Front + n * (S.Inset + 0.12) + Vector3.new(0, f.Top - 0.15, 0)
		local lipHolder = Instance.new("Part")
		lipHolder.Name = "HubLife_FallLip"
		lipHolder.Anchored, lipHolder.CanCollide, lipHolder.CanQuery, lipHolder.CanTouch, lipHolder.Transparency = true, false, false, false, 1
		lipHolder.Size = Vector3.new(f.Width * 0.9, 0.1, 0.1)
		lipHolder.CFrame = CFrame.lookAt(lipAt, lipAt + n)
		lipHolder.Parent = folder
		emitter(lipHolder, { Name = "HubLifeLipDrops", Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.6, 1.4), SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -26, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(1.6),
			Size = NumberSequence.new(0.08, 0.05), Transparency = NumberSequence.new(0.1, 0.7),
			Color = ColorSequence.new(C.Foam, C.Light), LightEmission = 1, LightInfluence = 0 }, Tuning.Lip.Rate)
		bases[#bases + 1] = { Fall = f, At = at, Rings = {}, Next = #bases * 0.13, Churn = nil }
	end
end
local function buildRings()
	local R = Tuning.Ripple
	for _, b in ipairs(bases) do
		local churn = HubLife.Ring(0.55, 28)
		if churn then
			churn.Name = "HubLife_FallChurn"
			churn.Material = Enum.Material.Neon
			churn.Color = Tuning.Colours.Foam
			churn.Transparency = Tuning.Churn.Transparency
			churn.Parent = folder
			b.Churn = churn
		end
		for _ = 1, R.Pool do
			local p = HubLife.Ring(R.Inner, 36)
			if not p then break end
			p.Name = "HubLife_Ripple"
			p.Material = Enum.Material.Neon
			p.Color = Tuning.Colours.Light
			p.Transparency = 1
			p.CFrame = CFrame.new(b.At)
			p.Parent = folder
			table.insert(b.Rings, { Part = p })
		end
	end
end

----------------------------------------------------------------------------------------------------
-- giving the room back (MeshBudget): the baked look and HubWaterFlow return
----------------------------------------------------------------------------------------------------
local function giveBack()
	if given then return end
	given = true
	pcall(function() folder:Destroy() end)
	for _, im in ipairs(waterImages) do pcall(function() im:Destroy() end) end
	table.clear(waterImages)
	if litMesh then HubLife.Release(litMesh) end
	if lit then lit.Transparency = 0 end
	for d, was in pairs(waterFlowOff) do
		if d.Parent then d.Enabled = was end
	end
	table.clear(waterFlowOff)
end
local B = HubLife.Budget()
if false and B then B.Optional(giveBack) end   -- (2026-10-27) stays: the first skin / wrap build released it for the session

----------------------------------------------------------------------------------------------------
-- build, then run
----------------------------------------------------------------------------------------------------
task.spawn(function()
	HubLife.WaitBudget()
	if given or not lit then return end
	-- the rest of the baked water first, so hiding the original never leaves the fountains bare
	local keep, err = litWithoutFalls()
	if not keep then
		warn("[HubWaterfall] could not read OBS_Water_Lit_01: " .. tostring(err) .. " -- the falls stay as they were")
		giveBack()
		return
	end
	if #keep > 0 then
		local c = Vector3.zero
		for _, t in ipairs(keep) do c += (t[1] + t[2] + t[3]) / 3 end
		c /= #keep
		local V, T = table.create(#keep * 3), table.create(#keep * 3)
		for i, t in ipairs(keep) do
			for k = 1, 3 do
				local q = (t[k] - c) * 1000
				V[(i - 1) * 3 + k] = string.format("%d,%d,%d", math.round(q.X), math.round(q.Y), math.round(q.Z))
				T[(i - 1) * 3 + k] = tostring((i - 1) * 3 + k - 1)
			end
		end
		HubLife.WaitBudget()
		local m = HubLife.DataMesh(table.concat(V, ","), table.concat(T, ","))
		if not m then
			giveBack()
			return
		end
		litMesh = m
		litCopy = m.Part
		litCopy.Name = "HubLife_WaterLitCopy"
		litCopy.Material = lit.Material
		litCopy.Color = lit.Color
		litCopy.Transparency = 0
		litCopy.CFrame = CFrame.new(c + m.Off)
		litCopy.Parent = folder
	end
	if given then return end
	local okS, errS = pcall(buildWater)
	if not okS then
		warn("[HubWaterfall] the water did not build: " .. tostring(errS))
		giveBack()
		return
	end
	hideLit()
	task.spawn(function()
		while not given and folder.Parent do
			task.wait(3)
			if not given then hideLit() end           -- (streaming can send the original back)
		end
	end)
	buildBases()
	buildRings()
	folder:SetAttribute("Falls", #FALLS)
	folder:SetAttribute("KeptLitTris", #keep)
	folder:SetAttribute("Ready", true)
end)

local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if given or not water or not HubLife.Close() then return end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - Tuning.Wing).Magnitude > Tuning.Near then return end
	local t = os.clock() - t0
	-- the water: every layer of every near fall scrolls down
	local camPos = cam.CFrame.Position
	for _, f in ipairs(FALLS) do
		local w = f.Water
		if w and (camPos - w.Centre).Magnitude < S.Near then
			for _, L in ipairs(w.Layers) do
				L.Label.Position = UDim2.fromOffset(L.X, -L.H + (t * L.Px - L.Run) % L.H)
			end
		end
	end
	-- the base: churn ring wobbles, ripples spread
	local R = Tuning.Ripple
	local every = R.Every / math.max(0.3, density)
	for _, b in ipairs(bases) do
		if b.Churn then
			local CH = Tuning.Churn
			local r = CH.Radius[1] + (CH.Radius[2] - CH.Radius[1]) * (0.5 + 0.5 * math.sin(t * CH.Hz * math.pi * 2 + b.Fall.Seed))
			b.Churn.Size = Vector3.new(r * 2, 0.02, r * 2)
			b.Churn.CFrame = CFrame.new(b.At + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, t * 1.7, 0)
		end
		if t >= b.Next and #b.Rings > 0 then
			b.Next = t + every * (0.8 + math.random() * 0.4)
			for _, x in ipairs(b.Rings) do
				if not x.Live then
					x.Live, x.T0 = true, t
					break
				end
			end
		end
		for _, x in ipairs(b.Rings) do
			if x.Live then
				local k = (t - x.T0) / R.Life
				if k >= 1 then
					x.Live = false
					x.Part.Transparency = 1
				else
					local d = R.From + (b.Fall.Radius * 1.9 - R.From) * (1 - (1 - k) ^ 2)
					x.Part.Size = Vector3.new(d, 0.02, d)
					x.Part.CFrame = CFrame.new(b.At)
					x.Part.Transparency = R.Transparency + (1 - R.Transparency) * k
				end
			end
		end
	end
end)
