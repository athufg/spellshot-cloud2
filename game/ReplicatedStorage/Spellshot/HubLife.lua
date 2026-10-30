--[[
	HubLife  (ModuleScript)  ->  ReplicatedStorage/Spellshot/HubLife

	THE HUB, ALIVE (2026-10-25, the owner's hub-rebuild brief): the one switch and the shared numbers for the scripts that
	bring the Arcane Observatory to life:
	  HubWingLife   (client)  each wing's own moving decor: Pyro's torches, Aqua's falls, Zephyr's crescents, Terra's new
	                          cracked arch (HubTerraArchData)
	  HubAmbient    (client)  a light pool and a wisp per archway, the centre crystal's Reaction cycle, the entry chevrons
	  HubNPCs       (client)  the Loadout Keeper and the Shop Merchant (HubNPCData: Blender-made accessories and clips),
	                          and (2026-10-27) seven ambient NPCs in the Training, Duels and Store wings (Idle loops only)
	  HubShowcase   (client)  the rotating wrap pedestal by the Store
	  HubBoards     (client)  the TOP DUELISTS board and the duel pads' VS card
	  HubLifeServer (server)  moves the Loadout altar's prompt onto the Keeper

	NOT LIVE. Until the owner has reviewed it, On() is true in Studio only (a Studio play test), so a published server
	and every player's client run none of it and the hub stays exactly as it was. Going live is Live = true here.
	Nothing here is selectable: the pedestal only shows wraps, it never equips one.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLife = {}

HubLife.Live = true           -- (2026-10-26, the owner: live)

function HubLife.On()
	return HubLife.Live or RunService:IsStudio()
end

HubLife.Hub = "ArcaneObservatoryHub"
HubLife.Centre = Vector3.new(8000, 0, 8000)
HubLife.Near = 260            -- studs from the centre: further than this (the Arena is thousands away) nothing animates

local function hex(s) return Color3.fromHex(s) end

-- the four wings' Elements, in the owner's colours (Base / Light / Dark). Aqua's are the ones AquaWrap guards:
-- SpellshotConfig.Elements.Aqua.
HubLife.Wing = {
	Pyro = { Base = hex("F25C0D"), Light = hex("FFC74D"), Dark = hex("6B1708") },
	Terra = { Base = hex("826B24"), Light = hex("CCBA5C"), Dark = hex("33210D") },
	Zephyr = { Base = hex("4FD1C5"), Light = hex("FFFFFF"), Dark = hex("125C59") },
	Aqua = { Base = hex("268CB0"), Light = hex("3CE8E0"), Dark = hex("0E3A50") },
}
do
	local ok, el = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig")).Elements.Aqua
	end)
	if ok and el and el.Base and el.Light and el.Dark then
		HubLife.Wing.Aqua = { Base = el.Base, Light = el.Light, Dark = el.Dark }
	end
end

-- each archway: its Element, the floor point in the middle of its mouth, the way into the plaza (In), the opening's width
-- and height (measured 2026-10-25 from the hub's El_<Element> neon frames)
HubLife.Arch = {
	Duels = { Element = "Zephyr", At = Vector3.new(8000, 0, 8042), In = Vector3.new(0, 0, -1), Width = 48, Height = 22 },
	Loadout = { Element = "Terra", At = Vector3.new(7957, 0, 8007.5), In = Vector3.new(1, 0, 0), Width = 44, Height = 22 },
	Training = { Element = "Aqua", At = Vector3.new(8037, 0, 8011), In = Vector3.new(-1, 0, 0), Width = 42, Height = 10 },
	Store = { Element = "Pyro", At = Vector3.new(8021.5, 0, 7961.5), In = Vector3.new(-0.49, 0, 0.87).Unit, Width = 8, Height = 10 },
}

-- the ceiling trim's yellow (OBS_Gold_Trim_01..03)
HubLife.TrimYellow = hex("FFD342")

-- THE TWO NPCs' marks: the HumanoidRootPart's CFrame and where their prompt hangs. Posed by the Motor6D chain the
-- mannequin's feet are 3.192 below its root (Roblox's own HipHeight 2.192 + half the root), so a root stands 3.192 over
-- its floor; the Merchant's is set against the counter instead (his feet are hidden behind it).
--   Keeper    on the Loadout room's floor in FRONT of the altar (the altar's top, 4.25, is above a mannequin's
--             shoulders: behind it he would show only his head), facing the archway (+X); the altar stays as dressing.
--   Merchant  behind the Store's counter (top 15.5, 3.5 over the Store floor at 12), its near edge 1.5 in front of
--             him at z 8013, facing the Store's way in (-X); the counter stays as dressing.
-- PromptAt is relative to the root: where the prompt sits (its reach is measured from it); its balloon hangs over the actual head (HubNPCs BubbleAt).
HubLife.NPC = {
	Keeper = { CFrame = CFrame.lookAt(Vector3.new(7942.8, 3.192, 8011.4), Vector3.new(7952.8, 3.192, 8011.4)),
		PromptAt = CFrame.new(0, 2.42, 0), Greet = 18, Leave = 24 },
	Merchant = { CFrame = CFrame.lookAt(Vector3.new(8075.5, 15.006, 8013), Vector3.new(8065.5, 15.006, 8013)),
		PromptAt = CFrame.new(0, 2.72, -0.35), Greet = 14, Leave = 19 },
}

-- (2026-10-27) THE SEVEN AMBIENT NPCs' marks (HubNPCData Ambient = true: one looping Idle each, no prompt, no greet, no
-- look-at, nothing reacting to players). Measured 2026-10-27 from the hub's own mesh triangles (floor heights, the
-- pillar's and the stair wall's faces). A root stands 3.192 over its floor. Phase = where in its loop each one starts
-- (a share of the loop), so the pairs never move in step.
--   TrainingDrill   in target T_a's lane (the south-outer target), 11 studs out along its face normal, square to it
--   TrainingWatch   his left shoulder on the Training entrance's south jamb (the pillar's north face), facing along it
--                   toward the lanes; his design puts that face at local x = -0.95 (normal +X: his body stands ~1.45 to
--                   his right of the root), so the root is set 0.95 off the measured face along its normal
--   DuelsWatchA/B   on the Duels terrace step (y 0.75, r 39.6-41.4 about the room's centre) behind pad P3, both watching it
--   StoreTalk / StoreListen   (2026-10-27, the owner: moved) a pair upstairs in the Store gallery, in front of the round
--                   star-chart table (floor y 12), 4 apart face to face; the table, telescope and shelves on StoreTalk's right
--   StoreLean       his back and right sole on the stair's plaza-facing wall (the parapet face, r 40 about the centre) at
--                   its tall end; his design puts the wall at local z = +0.75 (behind him), so the root is 0.75 off the
--                   face along its normal, facing out along it; he stands on the trough's centre ridge (y -0.4) at its foot
--- a root flush on a measured vertical face: `on` a point of the face, `n` its outward normal, `near` about where the
--- root goes (only its place ALONG the face is kept), `off` the design's root-to-face distance, `y` the root's height,
--- `look` its facing
local function onFace(on, n, near, off, y, look)
	n = Vector3.new(n.X, 0, n.Z).Unit
	local p = near - n * (near - on):Dot(n) + n * off
	p = Vector3.new(p.X, y, p.Z)
	return CFrame.lookAt(p, p + Vector3.new(look.X, 0, look.Z).Unit)
end
do
	local function level(at, to) return CFrame.lookAt(at, Vector3.new(to.X, at.Y, to.Z)) end
	local pillarN = Vector3.new(0.2292, 0, 0.9734).Unit           -- the pillar's north face (outward)
	local wallN = Vector3.new(-0.8788, 0, 0.4772).Unit            -- the stair wall at -28.5 deg (outward, to the centre)
	local A = {
		TrainingDrill = { CFrame = level(Vector3.new(8065.577, 3.192, 7995.22), Vector3.new(8076.41, 3.192, 7997.13)), Phase = 0.15 },
		-- facing = up x n: his right (+X) is the face's normal, his left (-X) goes into the pillar
		TrainingWatch = { CFrame = onFace(Vector3.new(8045.5, 0, 7989.265), pillarN, Vector3.new(8045.718, 0, 7990.19), 0.95, 3.192,
			Vector3.yAxis:Cross(pillarN)), Phase = 0.6 },
		DuelsWatchA = { CFrame = level(Vector3.new(8039.21, 3.942, 8091.18), Vector3.new(8025.7, 3.942, 8089.1)), Phase = 0 },
		DuelsWatchB = { CFrame = level(Vector3.new(8037.935, 3.942, 8095.223), Vector3.new(8025.7, 3.942, 8089.1)), Phase = 0.42 },
		-- (2026-10-30, the owner's mark) by the north window, left of the hero display, clear of it and of the walk-in lane
		StoreTalk = { CFrame = level(Vector3.new(8057.65, 15.192, 7981.43), Vector3.new(8061.03, 15.192, 7981.01)), Phase = 0 },
		StoreListen = { CFrame = level(Vector3.new(8061.03, 15.192, 7981.01), Vector3.new(8057.65, 15.192, 7981.43)), Phase = 0.55 },
		-- facing = n: local +Z (behind him) goes into the wall
		StoreLean = { CFrame = onFace(Vector3.new(8035.153, 0, 7980.914), wallN, Vector3.new(8034.494, 0, 7981.272), 0.75, 2.792, wallN),
			Phase = 0.3 },
	}
	for name, s in pairs(A) do
		s.Ambient = true
		HubLife.NPC[name] = s
	end
end

----------------------------------------------------------------------------------------------------
-- RIGS (client): the R15 mannequin (ReplicatedStorage.Spellshot.HubLifeMannequin, a default HumanoidDescription body
-- with plain Motor6Ds) posed by forward kinematics, every part anchored: Part1 = Part0 * C0 * Transform * C1^-1.
-- No physics, no Humanoid, no Animator: the clips are Blender's (HubNPCData), sampled here.
----------------------------------------------------------------------------------------------------
--- a fresh, anchored copy of the mannequin and its joints in parent-first order: { Model, Root, Order, Joints }
function HubLife.Mannequin()
	local spell = ReplicatedStorage:WaitForChild("Spellshot")
	local src = spell:WaitForChild("HubLifeMannequin", 30)
	if not src then return nil end
	local model = src:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	local byChild = {}
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			byChild[m.Part1] = { Name = m.Name, P0 = m.Part0, P1 = m.Part1, C0 = m.C0, C1inv = m.C1:Inverse() }
		end
	end
	local order, seen, grew = {}, { [root] = true }, true
	while grew do
		grew = false
		for p1, j in pairs(byChild) do
			if not seen[p1] and seen[j.P0] then
				order[#order + 1] = j
				seen[p1], grew = true, true
			end
		end
	end
	local joints = {}
	for _, j in ipairs(order) do joints[j.Name] = j end
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") then m:Destroy() end
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		end
	end
	-- a mannequin has no face: the default head's texture (eyes, mouth) goes, leaving the head in the body colour
	local head = model:FindFirstChild("Head")
	if head and head:IsA("MeshPart") then pcall(function() head.TextureID = "" end) end
	return { Model = model, Root = root, Order = order, Joints = joints }
end

--- pose a rig: rootCF for the HumanoidRootPart, T[jointName] = Transform (or nil = rest). Appends every part and its
--- CFrame to parts / cfs (for one BulkMoveTo) and returns the [part] = CFrame map.
function HubLife.Pose(rig, rootCF, T, parts, cfs)
	local cf = { [rig.Root] = rootCF }
	parts[#parts + 1], cfs[#cfs + 1] = rig.Root, rootCF
	for _, j in ipairs(rig.Order) do
		local c = cf[j.P0] * j.C0 * (T[j.Name] or CFrame.identity) * j.C1inv
		cf[j.P1] = c
		parts[#parts + 1], cfs[#cfs + 1] = j.P1, c
	end
	return cf
end

----------------------------------------------------------------------------------------------------
-- graphics settings (client): Graphics Quality's effect density, as SettingsRuntime sets it (LOW 45% .. ULTRA 115%),
-- and Reduce Flashing (no fast flashes: pulses go slow and soft)
----------------------------------------------------------------------------------------------------
local DENSITY = { 0.45, 0.75, 1.0, 1.15 }
local Settings = nil
local function settings()
	if Settings == nil then
		local ok, m = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
		end)
		Settings = ok and m or false
	end
	return Settings or nil
end
HubLife.Settings = settings

function HubLife.Density()
	local s = settings()
	local q = s and s.Get("GraphicsQuality")
	return DENSITY[q or 3] or 1
end

function HubLife.Quality()
	local s = settings()
	return (s and s.Get("GraphicsQuality")) or 3
end

function HubLife.Calm()
	local s = settings()
	return (s and s.Get("ReduceFlashing")) == true
end

--- fn() now and whenever Graphics Quality or Reduce Flashing changes
function HubLife.OnSettings(fn)
	local s = settings()
	if s then
		s.OnChange("GraphicsQuality", fn)
		s.OnChange("ReduceFlashing", fn)
	end
	fn()
end

--- a count scaled by the effect density, at least `min`
function HubLife.Count(n, min)
	return math.max(min or 0, math.floor(n * HubLife.Density() + 0.5))
end

--- whether this client's camera is near the hub (nothing need animate otherwise)
function HubLife.Close()
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - HubLife.Centre).Magnitude < HubLife.Near
end

----------------------------------------------------------------------------------------------------
-- a mesh from Blender data (HubNPCData / HubTerraArchData): unique vertices (thousandths of a stud, Roblox axes) and
-- triangles (0-based), flat-shaded (a normal per face), centred on its bounds. Returns { Part, Off, Size } or nil, err.
-- The same build as HydraKit's dataMesh. Client only.
----------------------------------------------------------------------------------------------------
local AssetService = game:GetService("AssetService")
local keep = {}
HubLife.Tris = 0

local function retry(fn)
	local last
	for i = 1, 3 do
		local ok, r = pcall(fn)
		if ok then return r end
		last = r
		task.wait(0.2 * i)
	end
	error(last, 0)
end

function HubLife.DataMesh(V, T)
	local vs, ts = string.split(V, ","), string.split(T, ",")
	local pts = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 1, #vs - 2, 3 do
		local p = Vector3.new(tonumber(vs[i]), tonumber(vs[i + 1]), tonumber(vs[i + 2])) / 1000
		pts[#pts + 1] = p
		lo, hi = lo:Min(p), hi:Max(p)
	end
	if #pts < 3 then return nil, "no vertices" end
	local off = (lo + hi) / 2
	local okE, em = pcall(retry, function() return AssetService:CreateEditableMesh() end)
	if not okE then return nil, em end
	local okB, errB = pcall(function()
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		local vid = {}
		for i, p in ipairs(pts) do vid[i] = em:AddVertex(p - off) end
		for i = 1, #ts - 2, 3 do
			local a, b, c = tonumber(ts[i]) + 1, tonumber(ts[i + 1]) + 1, tonumber(ts[i + 2]) + 1
			local n = (pts[b] - pts[a]):Cross(pts[c] - pts[a])
			if n.Magnitude > 1e-9 then
				local f = em:AddTriangle(vid[a], vid[b], vid[c])
				local nid = em:AddNormal(n.Unit)
				em:SetFaceNormals(f, { nid, nid, nid })
				if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
				HubLife.Tris += 1
			end
		end
	end)
	if not okB then
		em:Destroy()
		return nil, errB
	end
	local okF, fixed = pcall(retry, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	em:Destroy()
	if not okF then return nil, fixed end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise })
	end)
	if not ok then
		local ok2, mp2 = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
		if not ok2 then
			fixed:Destroy()
			return nil, mp2
		end
		mp = mp2
	end
	keep[fixed] = true
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Material, mp.Reflectance = Enum.Material.SmoothPlastic, 0
	return { Part = mp, Off = off, Size = hi - lo, Fixed = fixed }
end

--- let go of a DataMesh's mesh (its part is destroyed by the caller)
function HubLife.Release(m)
	if m and m.Fixed then
		keep[m.Fixed] = nil
		pcall(function() m.Fixed:Destroy() end)
		m.Fixed = nil
	end
end

--- a flat ring (annulus) mesh in the XZ plane, 1 stud across its outer edge, `inner` the hole's share of that, built
--- once and cloned (ripple rings, the crystal's halo pieces)
local ringTemplates = {}
function HubLife.Ring(inner, segments)
	local key = string.format("%.3f/%d", inner, segments)
	local t = ringTemplates[key]
	if t == nil then
		-- two layers 0.02 apart (a flat mesh would have no height to scale), each wound both ways: seen from above or
		-- below, whichever winding Roblox culls, one face shows
		local V, T = {}, {}
		for _, y in ipairs({ 10, -10 }) do
			for i = 0, segments - 1 do
				local a = i / segments * math.pi * 2
				local cx, cz = math.cos(a), math.sin(a)
				table.insert(V, string.format("%d,%d,%d", math.round(cx * 500), y, math.round(cz * 500)))
				table.insert(V, string.format("%d,%d,%d", math.round(cx * 500 * inner), y, math.round(cz * 500 * inner)))
			end
		end
		for layer = 0, 1 do
			local base = layer * segments * 2
			for i = 0, segments - 1 do
				local o0, i0 = base + i * 2, base + i * 2 + 1
				local o1, i1 = base + ((i + 1) % segments) * 2, base + ((i + 1) % segments) * 2 + 1
				table.insert(T, string.format("%d,%d,%d,%d,%d,%d", o0, i0, o1, o1, i0, i1))
				table.insert(T, string.format("%d,%d,%d,%d,%d,%d", o0, o1, i0, o1, i1, i0))
			end
		end
		local m = HubLife.DataMesh(table.concat(V, ","), table.concat(T, ","))
		t = m and m.Part or nil
		ringTemplates[key] = t                 -- (a failed build is not remembered: the next call tries again)
	end
	return t and t:Clone() or nil
end

----------------------------------------------------------------------------------------------------
-- the shared EditableMesh budget (ReplicatedStorage.IceMagic.MeshBudget): the hub's meshes are OPTIONAL -- they start
-- only while no worn skin's essential build runs, and give their meshes back when one needs the room
----------------------------------------------------------------------------------------------------
local budget = nil
function HubLife.Budget()
	if budget == nil then
		local ok, m = pcall(function()
			local ice = ReplicatedStorage:FindFirstChild("IceMagic")
			local mod = ice and ice:FindFirstChild("MeshBudget")
			return mod and require(mod) or nil
		end)
		budget = (ok and m) or false
	end
	return budget or nil
end

--- yield while an essential (skin) mesh build runs
function HubLife.WaitBudget()
	local b = HubLife.Budget()
	while b and b.Busy() do task.wait(0.5) end
end

return HubLife
