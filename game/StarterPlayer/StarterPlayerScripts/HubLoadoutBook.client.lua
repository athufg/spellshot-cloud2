--[[
	HubLoadoutBook (LocalScript, StarterPlayerScripts) -- (2026-10-27) the Loadout lectern's book, rebuilt in Blender.

	The book is now a real model with real leaves, not a fake turn over the merged pages: hub/loadout_book_2026_10_27/
	book_build.py models it (wine boards on a navy spine, gold corner caps, spine bands and clasp, a page block each side
	with a gutter, stacked edges, faint text rows and a head glyph) and animates Data.Leaves separate leaves, each a
	3-segment hinged chain turning about the spine: a leaf lifts fore-edge first, arcs over and lands flat on the left,
	trailing edge last; one every Data.Every seconds, a seamless loop (a landed leaf sinks into the left block while the
	next is in the air, and rises out of the right block while the one before it is in the air; every leaf's lines match
	the block's lines under it, so nothing pops). Data: ReplicatedStorage.Spellshot.HubLoadoutBookData (generated).

	It sits exactly where the merged book is (OBS_Decor_Parchment_01 / OBS_Decor_Wine_01 / the text lines in
	OBS_Iron_Dark_01), and its envelope CONTAINS that book, so the merged one is hidden inside it -- and stays as the
	fallback if a mesh cannot be built (EditableMesh budget). The leaves stop at the page heads' lower third: the desk
	lamp's shade hangs over the head of the spine and a full-height leaf would sweep through it.
	Also: a subtle gold-to-cyan shimmer and cyan motes drifting over the book, a few sparkles where each leaf lands,
	and the lamp's light retuned onto the new pages (the SpotLight in ArcaneObservatoryHub.LoadoutDressing.BookLampLight,
	LoadoutDressingBuild) plus a soft warm fill under the shade.
	One BulkMoveTo a frame; the leaves freeze and the air stops while the camera is far (HubLife.Close, Tuning.FarAway).

	(2026-10-27) THE IMPORTED MODEL: the book is also a real model in the place, visible in Edit --
	ArcaneObservatoryHub.LoadoutDressing.LoadoutBook (hub/loadout_book_2026_10_27/import: LoadoutBook.obj through Import 3D,
	then install_book.lua), book.blend's frame 0 as its rest pose. When it is there and matches HubLoadoutBookData, THOSE
	parts are animated, with the same baked tracks: a leaf part (attributes Leaf 0-based, Seg, Rest = its CFrame relative
	to the book, SegRest = its segment's book-space CFrame at rest) sits at book * Seg[k](frame) * SegRest:Inverse() * Rest,
	and the book frame is read off the model's own static parts (move the model in Studio and the leaves, air and light
	follow). No EditableMesh is built then. Without the model -- or if it does not match the data (a rebuilt Blender book
	needs a new import; this client then hides it) -- the book is built from the data at run time as before.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end
local Data = require(spell:WaitForChild("HubLoadoutBookData"))

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	-- the merged book's frame, measured 2026-10-27 from its triangles (the Blender model's origin and axes): Across runs
	-- from the spine to the right-hand page (the reader stands north, +Z, looking down-slope), Normal out of the pages
	Centre = Vector3.new(7933.43, 3.45, 7999.62),
	Across = Vector3.new(0.985, -0.001, -0.170),
	Normal = Vector3.new(0.080, 0.883, 0.462),
	Lamp = { Brightness = 4.2, Range = 3.8, Angle = 115 },   -- the BookLampLight SpotLight (built at 3 / 3.1 / 100)
	Fill = { At = Vector3.new(0, 0.6, -0.35), Color = Color3.fromRGB(255, 205, 150), Brightness = 0.7, Range = 2.6 },
	Sparkle = { Rate = 2.5, From = Color3.fromRGB(255, 211, 66), To = Color3.fromRGB(120, 232, 240) },
	Mote = { Rate = 2, Color = Color3.fromRGB(130, 226, 236) },
	Land = 5,                   -- sparkles where a leaf lands
	FarAway = 90,               -- studs from the book: nothing moves past this
}

local N = Tuning.Normal.Unit
local W = (Tuning.Across - N * Tuning.Across:Dot(N)).Unit
-- book space: +X across, +Y out of the pages, -Z to the heads ((2026-10-27) the imported model's own frame when it is used)
local bookCF = CFrame.fromMatrix(Tuning.Centre, W, N)

local function nums(s)
	local t = string.split(s, ",")
	for i, v in ipairs(t) do t[i] = tonumber(v) end
	return t
end
--- a segment's track: Frames CFrames in book space
local function track(s)
	local n, out = nums(s), table.create(Data.Frames)
	for f = 0, Data.Frames - 1 do
		local i = f * 7
		local w, x, y, z = n[i + 4], n[i + 5], n[i + 6], n[i + 7]
		local m = math.sqrt(w * w + x * x + y * y + z * z)
		out[f + 1] = CFrame.new(n[i + 1] / 1000, n[i + 2] / 1000, n[i + 3] / 1000, x / m, y / m, z / m, w / m)
	end
	return out
end
--- (2026-10-27) the box (centre, size) of a piece's vertices placed by `cf` (HubLife.DataMesh centres a mesh on its box,
--- and Import 3D lands a part on its box the same way)
local function box(V, cf)
	local n = nums(V)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for i = 1, #n - 2, 3 do
		local p = cf * (Vector3.new(n[i], n[i + 1], n[i + 2]) / 1000)
		lo, hi = lo:Min(p), hi:Max(p)
	end
	return (lo + hi) / 2, hi - lo
end

local folder = Instance.new("Folder")
folder.Name = "HubLoadoutBook"
local leaves = {}          -- [i] = { Parts, Seg, Off, Shown, Last }: leaf i plays the cycle (i - 1) * Every behind
local dressing = hub:WaitForChild("LoadoutDressing", 10)

---------------------------------------------------------------------------------------------------- the imported model
--- (2026-10-27) the leaves from ArcaneObservatoryHub.LoadoutDressing.LoadoutBook (install_book.lua). -> true, or false
--- and why (why = nil: there is no model)
local function fromModel(model)
	if not model then return false end
	local function get(name)
		local p = model:FindFirstChild(name) or model:WaitForChild(name, 3)
		if not (p and p:IsA("BasePart")) then return nil, "no part " .. name end
		return p
	end
	--- the part's mesh is the data's piece `pc` placed by `cf`: its Rest centre and its size say so
	local function same(p, pc, cf, rest)
		local c, s = box(pc.V, cf)
		local d = p.Size - s
		return (rest.Position - c).Magnitude < 0.01 and math.max(math.abs(d.X), math.abs(d.Y), math.abs(d.Z)) < 0.01
	end
	-- the book frame, read off the static parts (each sits at book * Rest)
	local book = nil
	for _, pc in ipairs(Data.Static) do
		local p, why = get("Static_" .. pc.Name)
		if not p then return false, why end
		local rest = p:GetAttribute("Rest")
		if typeof(rest) ~= "CFrame" then return false, p.Name .. " has no Rest attribute" end
		if not same(p, pc, CFrame.identity, rest) then return false, p.Name .. " is not the data's " .. pc.Name end
		local b = p.CFrame * rest:Inverse()
		if book and (b.Position - book.Position).Magnitude > 0.01 then return false, p.Name .. " has moved off the book" end
		book = book or b
	end
	local built = {}
	for i = 1, Data.Leaves do
		local L = { Parts = {}, Seg = {}, Off = {}, Shown = true, Last = nil }
		for j, pc in ipairs(Data.Leaf) do
			local p, why = get(string.format("Leaf%d_%s", i - 1, pc.Name))
			if not p then return false, why end
			local rest, segRest = p:GetAttribute("Rest"), p:GetAttribute("SegRest")
			if typeof(rest) ~= "CFrame" or typeof(segRest) ~= "CFrame" or p:GetAttribute("Seg") ~= pc.Seg
				or p:GetAttribute("Leaf") ~= i - 1 then
				return false, p.Name .. "'s Leaf / Seg / Rest / SegRest attributes do not fit the data"
			end
			if not same(p, pc, segRest, rest) then return false, p.Name .. " is not the data's " .. pc.Name end
			L.Parts[j], L.Seg[j], L.Off[j] = p, pc.Seg, segRest:Inverse() * rest
		end
		built[i] = L
	end
	local count, want = 0, #Data.Static + Data.Leaves * #Data.Leaf
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then count += 1 end
	end
	if count ~= want then return false, string.format("it has %d parts, the data %d", count, want) end
	bookCF, leaves = book, built
	return true
end

---------------------------------------------------------------------------------------------------- the data (fallback)
local made = {}
local function piece(pc)
	local m, err = HubLife.DataMesh(pc.V, pc.T)
	if not m then return nil, err end
	made[#made + 1] = m
	m.Part.Name = pc.Name
	m.Part.Color = Color3.fromHex(Data.Colors[pc.Color])
	return m
end
--- the book built at run time from the data (as before the import). -> true, or false and the error
local function fromData()
	HubLife.WaitBudget()
	for _, pc in ipairs(Data.Static) do
		local m, err = piece(pc)
		if not m then return false, err end
		m.Part.CFrame = bookCF * CFrame.new(m.Off)
		m.Part.Parent = folder
	end
	-- the leaves: each piece built once, cloned per leaf
	local templates = {}
	for _, pc in ipairs(Data.Leaf) do
		local m, err = piece(pc)
		if not m then return false, err end
		templates[#templates + 1] = { Part = m.Part, Seg = pc.Seg, Off = CFrame.new(m.Off) }
	end
	for i = 1, Data.Leaves do
		local L = { Parts = {}, Seg = {}, Off = {}, Shown = true, Last = nil }
		for j, t in ipairs(templates) do
			local p = (i == 1) and t.Part or t.Part:Clone()
			p.Name = string.format("Leaf%d_%s", i, t.Part.Name)
			p.CFrame = bookCF
			p.Parent = folder
			L.Parts[j], L.Seg[j], L.Off[j] = p, t.Seg, t.Off
		end
		leaves[i] = L
	end
	return true
end

local model = dressing and dressing:WaitForChild("LoadoutBook", 2)
local okModel, why = fromModel(model)
if not okModel then
	--- a model that does not fit the data is hidden on this client while the data book stands in (shown again if that fails)
	local function showModel(on)
		if not (why and model) then return end
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = on and 0 or 1 end
		end
	end
	if why then
		warn("[HubLoadoutBook] LoadoutDressing.LoadoutBook does not fit HubLoadoutBookData (" .. why
			.. ") -- hiding it and building the book from the data (re-import it: hub/loadout_book_2026_10_27/import)")
		showModel(false)
	end
	leaves = {}
	local ok, err = fromData()
	if not ok then
		warn("[HubLoadoutBook] " .. tostring(err) .. " -- keeping the merged book")
		for _, m in ipairs(made) do HubLife.Release(m) end
		folder:Destroy()
		showModel(true)
		return
	end
end
local C = bookCF.Position
folder.Parent = workspace

local segs = { track(Data.Seg[1]), track(Data.Seg[2]), track(Data.Seg[3]) }
local show = nums(Data.Show)
local LOOP = Data.Frames / Data.Fps

---------------------------------------------------------------------------------------------------- light + air
do
	local lamp = dressing and dressing:FindFirstChild("BookLampLight")
	local spot = lamp and lamp:FindFirstChildWhichIsA("SpotLight")
	if spot then
		spot.Brightness, spot.Range, spot.Angle = Tuning.Lamp.Brightness, Tuning.Lamp.Range, Tuning.Lamp.Angle
	end
end

local function holder(name, size, cf)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Parent = folder
	return p
end
local function sequence(pairs_)
	local kp = {}
	for _, p in ipairs(pairs_) do kp[#kp + 1] = NumberSequenceKeypoint.new(p[1], p[2]) end
	return NumberSequence.new(kp)
end

local fill = Instance.new("PointLight")
fill.Color, fill.Brightness, fill.Range, fill.Shadows = Tuning.Fill.Color, Tuning.Fill.Brightness, Tuning.Fill.Range, false
fill.Parent = holder("BookFill", Vector3.one * 0.1, bookCF * CFrame.new(Tuning.Fill.At))

-- the air over the book (its +Y out of the pages) and the landing spot on the left-hand page
local air = holder("BookAir", Vector3.new(2.3, 0.6, 1.6), bookCF * CFrame.new(0, 0.45, 0))
local landAt = holder("BookLand", Vector3.new(0.6, 0.05, 0.7), bookCF * CFrame.new(-0.5, 0.2, 0.18))

local sparkle = Instance.new("ParticleEmitter")
sparkle.Name = "Sparkle"
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Shape, sparkle.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
sparkle.EmissionDirection = Enum.NormalId.Top
sparkle.Lifetime, sparkle.Speed, sparkle.SpreadAngle = NumberRange.new(2.0, 3.4), NumberRange.new(0.06, 0.2), Vector2.new(70, 70)
sparkle.Drag, sparkle.Acceleration = 0.5, Vector3.new(0, 0.1, 0)
sparkle.Size = sequence({ { 0, 0 }, { 0.25, 0.13 }, { 0.6, 0.09 }, { 1, 0 } })
sparkle.Transparency = sequence({ { 0, 1 }, { 0.2, 0.1 }, { 0.75, 0.3 }, { 1, 1 } })
sparkle.Color = ColorSequence.new(Tuning.Sparkle.From, Tuning.Sparkle.To)
sparkle.LightEmission, sparkle.LightInfluence = 1, 0
sparkle.Rotation, sparkle.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-60, 60)
sparkle.Parent = air

local mote = Instance.new("ParticleEmitter")
mote.Name = "Mote"
mote.Texture = "rbxasset://textures/particles/smoke_main.dds"
mote.Shape, mote.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
mote.EmissionDirection = Enum.NormalId.Top
mote.Lifetime, mote.Speed, mote.SpreadAngle = NumberRange.new(2.6, 4.0), NumberRange.new(0.05, 0.15), Vector2.new(90, 90)
mote.Drag, mote.Acceleration = 0.6, Vector3.new(0, 0.06, 0)
mote.Size = sequence({ { 0, 0 }, { 0.3, 0.09 }, { 1, 0 } })
mote.Transparency = sequence({ { 0, 1 }, { 0.3, 0.25 }, { 1, 1 } })
mote.Color = ColorSequence.new(Tuning.Mote.Color)
mote.LightEmission, mote.LightInfluence = 1, 0
mote.Parent = air

local burst = Instance.new("ParticleEmitter")
burst.Name = "Land"
burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
burst.Shape, burst.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
burst.EmissionDirection = Enum.NormalId.Top
burst.Rate = 0
burst.Lifetime, burst.Speed, burst.SpreadAngle = NumberRange.new(0.7, 1.2), NumberRange.new(0.3, 0.7), Vector2.new(35, 35)
burst.Drag = 2.5
burst.Size = sequence({ { 0, 0 }, { 0.2, 0.14 }, { 1, 0 } })
burst.Transparency = sequence({ { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } })
burst.Color = ColorSequence.new(Tuning.Sparkle.From, Tuning.Sparkle.To)
burst.LightEmission, burst.LightInfluence = 1, 0
burst.Rotation, burst.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-90, 90)
burst.Parent = landAt

local airOn = true
local function setAir(on)
	if on == airOn then return end
	airOn = on
	sparkle.Enabled, mote.Enabled = on, on
end
HubLife.OnSettings(function()
	sparkle.Rate = Tuning.Sparkle.Rate * HubLife.Density()
	mote.Rate = Tuning.Mote.Rate * HubLife.Density()
end)

---------------------------------------------------------------------------------------------------- the leaves
local parts, cfs, segCF = {}, {}, {}
--- every leaf at its place in the loop at `now`
local function pose(now)
	table.clear(parts)
	table.clear(cfs)
	for i, L in ipairs(leaves) do
		local x = ((now - (i - 1) * Data.Every) % LOOP) * Data.Fps
		local f0 = math.floor(x) % Data.Frames
		local f1, a = (f0 + 1) % Data.Frames, x - math.floor(x)
		local vis = show[f0 + 1] == 1
		if vis ~= L.Shown then
			L.Shown = vis
			for _, p in ipairs(L.Parts) do p.Transparency = vis and 0 or 1 end
		end
		if vis then
			for k = 1, 3 do segCF[k] = bookCF * segs[k][f0 + 1]:Lerp(segs[k][f1 + 1], a) end
			for j, p in ipairs(L.Parts) do
				parts[#parts + 1] = p
				cfs[#cfs + 1] = segCF[L.Seg[j]] * L.Off[j]
			end
		end
		if L.Last and L.Last < Data.Land and f0 >= Data.Land then burst:Emit(Tuning.Land) end
		L.Last = f0
	end
	if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end
pose(os.clock())

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not (cam and HubLife.Close() and (cam.CFrame.Position - C).Magnitude < Tuning.FarAway) then
		setAir(false)
		return
	end
	setAir(true)
	pose(os.clock())
end)
