--[[
	PixelPotionKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/PixelPotionKit

	Toxin's PIXEL POTION skin (2026-10-20; an UNCOMMON Element skin, FrostbladeKit's tier: one object family on the
	Default's own beats, no particle layer, no added glow, no HUD set, no kill effect). Every Toxin piece is one blocky,
	Minecraft-style voxel POTION BOTTLE, the same three-part shape everywhere, only its size and count change:
	  Liquid   the potion inside: a rounded, octagonal voxel body (a 16-pixel bottle's rows), shaded in Toxin's own
	           greens -- deep at the base and the right, lit at the upper left, one pale glint pixel on the front
	  Glass    a pale blue-white voxel shell (Glass material) round the liquid, and the distinctly narrower neck
	  Cork     a tan wooden stopper on the neck, a little wider than it (Wood: its own material, not the glass's)
	Liquid and Glass are EditableMesh MeshParts built ONCE per client (about 1,000 triangles in all: faces of real
	voxels, flat-shaded, colours in the vertices), then cloned for every piece: three parts a bottle. Until they are
	built, or if the build fails, the same silhouette stands in as four plain Parts (the liquid's octagon as two crossed
	blocks, the neck, the cork). ToxinFX draws the bottles on the Default's own beats, gated on On(); its particle
	emitters, lights and Virulence glow stay the Default's, untouched (the Default shapes are only hidden on this client,
	LocalTransparencyModifier = 1, so their emitters still run).
	  On(character)         whether that body wears it: its player's Element is Toxin and SkinCatalog's ElementSkin_Toxin
	                        is "PixelPotion". Studio only: a body with the attribute StudioSkin = "PixelPotion" stands in
	                        (the checkpoint stage); never live. A true answer starts the mesh build (Prepare).
	  Tier(density, thin)   1 / 2 / 3, the kits' shared rule (unused by the build: the Default's own counts carry it)
	  Look                  ToxinFX's display colours ({ Liquid, LiquidDeep, LiquidHi, Glint }); set before the build
	  New(kind, parent, look) -> o     Place(o, cf, size)     Fade(o, f)     Drop(o)     Gas(parent)     Voxelize(model, body, G)
	  OnRelease(fn) / ReleaseNow()   (2026-10-26) the give-back: worn by nobody here and idle 10 s, it lets go of its meshes
	                        (MeshBudget's Optional; ReleaseNow skips the idle wait); Built mirrors the build's state
	Only the M1 and the pieces that come as several (drops, splats, thread heads, the rain) are bottles; the cloud-type
	pieces -- Patient Zero's whole cloud and its mark too -- are blocky voxel GAS in their own lobes' shape and colour (Gas);
	the Vent's mask is the Default's own, voxelized (Voxelize).
	LIVE in SkinCatalog.ElementSkins.Toxin (Toxin's SKINS page): approved by the owner 2026-10-20.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local PP = {}
PP.Id = "PixelPotion"
PP.Look = nil

local GLASS = Color3.fromRGB(196, 228, 240)      -- pale blue-white glass (the reference's)
local CORK = Color3.fromRGB(214, 168, 110)       -- tan cork (Wood darkens and reddens it in the place's light)
local GLASS_T = 0.5                              -- (Glass material: a crisp blue outline, the liquid's own green inside)
local SQUASH = 0.25                              -- how much of a caller's squash the bottle takes (0: none, 1: all of it)
-- (only when ToxinFX gave no Look: Toxin's locked source hexes, ToxinTuning.Color)
local FALLBACK_LOOK = { Liquid = Color3.fromRGB(107, 122, 30), LiquidDeep = Color3.fromRGB(61, 70, 16),
	LiquidHi = Color3.fromRGB(201, 224, 119), Glint = Color3.fromRGB(232, 242, 160) }

function PP.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

----------------------------------------------------------------------------------------------------
-- THE VOXEL BOTTLE, in voxels (1 = 1/15 of the bottle's height; x and z run -h .. h-1 round the axis, y up)
--   rows 0-8   the body: each row an octagon of half-width h (corners cut where |x|+|z| > 1.5 h - 1/2); the liquid fills
--              rows 1-6 one voxel in from the shell, the glass is the rest
--   rows 9-11  the neck: 2 x 2 glass
--   rows 12-14 the cork: 3 x 3 x 3, its own Part
----------------------------------------------------------------------------------------------------
local BODY_H = { [0] = 2, 3, 4, 4, 4, 4, 4, 3, 2 }
local NECK_ROWS, NECK_H = { 9, 10, 11 }, 1
local LIQUID_ROWS = { 1, 6 }
local HEIGHT = 15
local CORK_BOX = { Centre = Vector3.new(0, 13.5, 0), Size = Vector3.new(3, 3, 3) }

local function inOct(x, z, h)
	local cx, cz = math.abs(x + 0.5), math.abs(z + 0.5)
	return cx <= h and cz <= h and cx + cz <= 1.5 * h - 0.5          -- (stair-cut corners: the body reads round)
end

local function key(x, y, z) return x .. "," .. y .. "," .. z end

-- the two voxel sets: liquid[key] = { x, y, z }, glass[key] = { x, y, z }
local function voxels()
	local liquid, glass = {}, {}
	for y = 0, 8 do
		local h = BODY_H[y]
		for x = -h, h - 1 do
			for z = -h, h - 1 do
				if inOct(x, z, h) then
					local wet = y >= LIQUID_ROWS[1] and y <= LIQUID_ROWS[2] and inOct(x, z, h - 1)
					local set = wet and liquid or glass
					set[key(x, y, z)] = { x, y, z }
				end
			end
		end
	end
	for _, y in ipairs(NECK_ROWS) do
		for x = -NECK_H, NECK_H - 1 do
			for z = -NECK_H, NECK_H - 1 do glass[key(x, y, z)] = { x, y, z } end
		end
	end
	return liquid, glass
end

-- a liquid voxel's colour: the pale glint pixel, the lit upper left, the deep base and right side, else the body
local function liquidColour(v, L)
	local x, y, z = v[1], v[2], v[3]
	if x == -2 and y == 5 and z == -3 then return L.Glint end
	if x <= -2 and y >= 4 then return L.LiquidHi end
	if y <= 1 or x >= 2 then return L.LiquidDeep end
	return L.Liquid
end

-- DIFFERENT POTIONS: a Compact bottle's liquid takes one of these tints ({ hue, saturation, value } shifts of Toxin's own
-- greens, all four shades alike); the first is the M1 bubble's own liquid, untouched. Glass and cork never change.
local VARIANTS = { { 0, 0, 0 }, { 0.045, 0.12, 0.05 }, { -0.04, 0.18, 0.1 }, { 0.02, -0.12, -0.18 }, { 0.085, 0.05, 0.02 } }
local function tint(c, v)
	local h, s, val = c:ToHSV()
	return Color3.fromHSV((h + v[1]) % 1, math.clamp(s * (1 + v[2]), 0, 1), math.clamp(val * (1 + v[3]), 0, 1))
end

-- THE VOXEL GAS CHUNK (the cloud-type pieces: Corrosive Cloud, Patient Zero's wave and mass, Acid Rain's cloud and hold, the
-- pop's puff -- never bottles): a blocky ball 5 voxels across, uncoloured (each lobe's own colour, material and
-- transparency go on it)
local function gasVoxels()
	local set = {}
	for x = 0, 4 do
		for y = 0, 4 do
			for z = 0, 4 do
				if (x - 2) ^ 2 + (y - 2) ^ 2 + (z - 2) ^ 2 <= 6.8 then set[key(x, y, z)] = { x, y, z } end
			end
		end
	end
	return set
end

-- THE VENT'S MASK: the Default's own pieces, voxelized -- its domes as a finer voxel ball (9 across: the silhouette
-- stays the Default's), its cylinders as a pixel disc (7 across, the axis on X like a Roblox cylinder); uncoloured
local function ballVoxels(n)
	local set, c, r2 = {}, (n - 1) / 2, (n / 2 + 0.1) ^ 2
	for x = 0, n - 1 do
		for y = 0, n - 1 do
			for z = 0, n - 1 do
				if (x - c) ^ 2 + (y - c) ^ 2 + (z - c) ^ 2 <= r2 then set[key(x, y, z)] = { x, y, z } end
			end
		end
	end
	return set
end
-- (the lens rims: a thin pixel RING round each lens, so the Default's rim glow reads as two eye-piece lights)
local function ringVoxels(n)
	local set, c, r2 = {}, (n - 1) / 2, (n / 2 - 0.1) ^ 2
	for x = 0, 1 do
		for y = 0, n - 1 do
			for z = 0, n - 1 do
				local d2 = (y - c) ^ 2 + (z - c) ^ 2
				if d2 <= r2 and d2 > 5 then set[key(x, y, z)] = { x, y, z } end
			end
		end
	end
	return set
end
local function discVoxels(n)
	local set, c, r2 = {}, (n - 1) / 2, (n / 2 - 0.1) ^ 2
	for x = 0, 1 do
		for y = 0, n - 1 do
			for z = 0, n - 1 do
				if (y - c) ^ 2 + (z - c) ^ 2 <= r2 then set[key(x, y, z)] = { x, y, z } end
			end
		end
	end
	return set
end

local DIRS = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }

-- the four corners of the face of voxel (x, y, z) toward `n`, in voxel space
local function faceCorners(x, y, z, n)
	local o = Vector3.new(x, y, z)
	local c = o + Vector3.new(0.5, 0.5, 0.5) + n * 0.5                   -- the face's centre
	local u = (math.abs(n.X) > 0.5) and Vector3.yAxis or Vector3.xAxis
	local w = n:Cross(u)
	u, w = u * 0.5, w * 0.5
	return c - u - w, c + u - w, c + u + w, c - u + w
end

local MeshBudget = nil
local function budget()
	if MeshBudget == nil then
		local m = script.Parent:FindFirstChild("MeshBudget")
		local ok, b = pcall(function() return m and require(m) end)
		MeshBudget = (ok and type(b) == "table") and b or false
	end
	return MeshBudget or nil
end

local function retry(make)
	for i = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		local b = budget()
		if b and i % 8 == 1 then b.MakeRoom() end               -- (refused: the optional holders let go of what they can)
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}              -- the fixed-size meshes the templates show
-- one MeshPart of voxel set `set` (skipping faces against `solid` too), each face coloured colourOf(v); and the
-- centre and size of its box in voxels. Leaks nothing on failure.
local function meshOf(set, solid, colourOf)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, v in pairs(set) do
		local p = Vector3.new(v[1], v[2], v[3])
		lo, hi = lo:Min(p), hi:Max(p + Vector3.one)
	end
	local centre, size = (lo + hi) / 2, hi - lo
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local cols, norms = {}, {}
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		for _, v in pairs(set) do
			local col = colourOf and colourOf(v)
			local ci = col and cols[col:ToHex()]
			if col and not ci then ci = em:AddColor(col, 1) cols[col:ToHex()] = ci end
			for _, n in ipairs(DIRS) do
				local nk = key(v[1] + n.X, v[2] + n.Y, v[3] + n.Z)
				if not set[nk] and not (solid and solid[nk]) then           -- an exposed face
					local a, b, c, d = faceCorners(v[1], v[2], v[3], n)
					if (b - a):Cross(c - a):Dot(n) < 0 then b, d = d, b end   -- (wound so its front faces out)
					local nk2 = string.format("%d,%d,%d", n.X, n.Y, n.Z)
					local ni = norms[nk2]
					if not ni then ni = em:AddNormal(n) norms[nk2] = ni end
					local va, vb, vc, vd = em:AddVertex(a - centre), em:AddVertex(b - centre), em:AddVertex(c - centre), em:AddVertex(d - centre)
					for _, tri in ipairs({ { va, vb, vc }, { va, vc, vd } }) do
						local f = em:AddTriangle(tri[1], tri[2], tri[3])
						if ci then em:SetFaceColors(f, { ci, ci, ci }) end
						em:SetFaceNormals(f, { ni, ni, ni })
						if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
					end
				end
			end
		end
	end)
	if not okB then
		em:Destroy()
		error(errB, 0)
	end
	local okF, fixed = pcall(retry, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	em:Destroy()
	if not okF then error(fixed, 0) end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise })
	end)
	if not ok then
		local ok2, mp2 = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
		if not ok2 then
			fixed:Destroy()
			error(mp2, 0)
		end
		mp = mp2
	end
	keep[#keep + 1] = fixed
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Material, mp.Reflectance, mp.Color = Enum.Material.SmoothPlastic, 0, Color3.new(1, 1, 1)   -- (the colours are the vertices')
	return mp, centre, size
end

-- the unit box a piece's spec lives in: the whole bottle is HEIGHT voxels tall, centred at half of it
local MID = Vector3.new(0, HEIGHT / 2, 0)
local function spec(name, template, centre, size, t)
	return { Name = name, Template = template, At = (centre - MID) / HEIGHT, Size = size / HEIGHT, T = t }
end

local function corkPart()
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material, p.Reflectance, p.Color = Enum.Material.Wood, 0, CORK
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

-- THE STAND-IN (until the meshes are built, or if they fail): the same silhouette in four plain Parts
local FALLBACK = {
	{ Name = "Liquid", At = Vector3.new(0, -0.2, 0), Size = Vector3.new(0.53, 0.6, 0.33), Look = "Liquid", T = 0 },
	{ Name = "Liquid", At = Vector3.new(0, -0.2, 0), Size = Vector3.new(0.33, 0.6, 0.53), Look = "Liquid", T = 0 },
	{ Name = "Glass", At = Vector3.new(0, 0.2, 0), Size = Vector3.new(0.14, 0.2, 0.14), Look = "Glass", T = GLASS_T },
	{ Name = "Cork", At = Vector3.new(0, 0.4, 0), Size = Vector3.new(0.2, 0.2, 0.2), Look = "Cork", T = 0 },
}

local built = nil            -- { specs } once built | false (failed) | nil (not started / building / given back)
local building = false
PP.Built = false             -- (2026-10-26) the meshes are ready (the other kits' flag; `built` above stays the truth)
local usedAt = 0             -- (2026-10-26) the last bottle, gas chunk or mask made, or bottle placed (an unworn kit lets go)
local releaseHooks = {}      -- (2026-10-26) the pools of this kit's pieces elsewhere (OnRelease): emptied with it
--- (2026-10-26) `fn()` runs when the kit lets go of its meshes (no module pools its pieces today); never yields
function PP.OnRelease(fn) releaseHooks[#releaseHooks + 1] = fn end

--- Build the meshes (once, in the background: five liquids, the glass, the gas chunk, the mask's ball and disc; the
--- stand-ins draw meanwhile).
function PP.Prepare()
	if built ~= nil or building or not RunService:IsClient() then return end
	building = true
	local b = budget()
	if b then b.Essential(PP.Id, true) end
	task.spawn(function()
		local L = PP.Look or FALLBACK_LOOK
		local ok, res = pcall(function()
			local liquid, glass = voxels()
			local liquids = {}
			for i, v in ipairs(VARIANTS) do
				local Lv = { Liquid = tint(L.Liquid, v), LiquidDeep = tint(L.LiquidDeep, v), LiquidHi = tint(L.LiquidHi, v),
					Glint = tint(L.Glint, v) }
				local lm, lc, ls = meshOf(liquid, nil, function(q) return liquidColour(q, Lv) end)
				liquids[i] = spec("Liquid", lm, lc, ls, 0)
			end
			local gm, gc, gs = meshOf(glass, liquid, function() return GLASS end)
			gm.Material = Enum.Material.Glass
			local gas = meshOf(gasVoxels(), nil, nil)
			local ball = meshOf(ballVoxels(9), nil, nil)
			local disc = meshOf(discVoxels(7), nil, nil)
			local ring = meshOf(ringVoxels(7), nil, nil)
			return { Liquid = liquids, Glass = spec("Glass", gm, gc, gs, GLASS_T),
				Cork = spec("Cork", corkPart(), CORK_BOX.Centre, CORK_BOX.Size, 0), Gas = gas, Ball = ball, Disc = disc, Ring = ring }
		end)
		if ok then
			built = res
			PP.Built = true                                       -- (2026-10-26)
		else
			built = false
			warn("[PixelPotionKit] the bottle's meshes did not build (" .. tostring(res) .. "); the four-part stand-in draws")
			for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
			table.clear(keep)
		end
		building = false
		if b then b.Essential(PP.Id, false) end
	end)
end

-- (2026-10-26) THE SHOWCASE CONVENTION: a client-only model no player owns, with the attribute ShowcaseSkin = "<SkinId>"
-- (the Loadout Altar's dummies, the pedestal's held M1), wears that skin -- live and in Studio. Every such model asked
-- about (On) or seen entering the workspace (below) is kept here wherever it sits (the showcases parent theirs in their
-- own folders), so the build starts for it.
local showcase = {}
--- whether `m` is a showcase stand-in wearing Pixel Potion (one wearing any skin is kept)
function PP.Showcase(m)
	local id = typeof(m) == "Instance" and m:GetAttribute("ShowcaseSkin")
	if type(id) ~= "string" or Players:GetPlayerFromCharacter(m) then return false end
	-- (2026-10-26) pruned on insert (strong keys): a stand-in that left the workspace goes when the next new one is kept
	if not showcase[m] then
		for k in pairs(showcase) do if not k:IsDescendantOf(workspace) then showcase[k] = nil end end
		showcase[m] = true
	end
	return id == PP.Id
end
--- the showcase stand-ins in the workspace wearing Pixel Potion now
function PP.Showcased()
	local out = {}
	for m in pairs(showcase) do
		if not m:IsDescendantOf(workspace) then
			showcase[m] = nil
		elseif m:GetAttribute("ShowcaseSkin") == PP.Id then
			out[#out + 1] = m
		end
	end
	return out
end

function PP.On(character)
	if typeof(character) ~= "Instance" then return false end
	local on
	if RunService:IsStudio() and character:GetAttribute("StudioSkin") == PP.Id then
		on = true
	elseif PP.Showcase(character) then                             -- (2026-10-26) a showcase stand-in, live too
		on = true
	else
		local plr = Players:GetPlayerFromCharacter(character)
		on = plr ~= nil and plr:GetAttribute("Element") == "Toxin"           -- (a borrowed Toxin Technique: the Default)
			and SkinCatalog.ElementSkin(plr, "Toxin") == PP.Id
	end
	if on then PP.Prepare() end
	return on
end
-- (2026-10-26) no watcher here for a showcase stand-in: the bottle bakes ToxinFX's liquid look (PP.Look, set when ToxinFX
-- loads this kit), so its build starts from ToxinFX's first On for the stand-in, as for a player

-- (2026-10-26) THE GIVE-BACK (FrostbladeKit's, for MeshBudget): a built kit nobody here wears right now -- no player is
-- Toxin in this skin (On's own rule; a wearer between bodies, dead or respawning, counts too), no Studio stand-in in the
-- workspace or the training dummies, no showcase stand-in -- and that made or placed nothing for 10 s lets go of every
-- mesh (the five liquids, the glass, the gas chunk, the mask's ball / disc / ring, their fixed meshes; the cork part).
-- `built` goes nil first, so every piece asked for from now on is the four-part stand-in, and the next New / Gas /
-- Voxelize (a wearer's) builds it again (Prepare, with the PP.Look ToxinFX set). Nothing pools the bottles (ToxinFX makes
-- and drops them per piece); pieces already out keep placing on their own specs, their meshes gone.
local function wornByPlayer(plr)
	if plr.Character and PP.On(plr.Character) then return true end
	local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Toxin")
	return ok and id == PP.Id and plr:GetAttribute("Element") == "Toxin"
end
local function releaseKit()
	if building or not built or os.clock() - usedAt < 10 then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if wornByPlayer(plr) then return end
	end
	if RunService:IsStudio() then
		local tg = workspace:FindFirstChild("TrainingGround")
		local dm = tg and tg:FindFirstChild("Dummies")
		for _, list in ipairs({ workspace:GetChildren(), dm and dm:GetChildren() or {} }) do
			for _, m in ipairs(list) do
				if m:IsA("Model") and m:GetAttribute("StudioSkin") == PP.Id then return end
			end
		end
	end
	if #PP.Showcased() > 0 then return end
	local b = built
	built, PP.Built = nil, false
	for _, fn in ipairs(releaseHooks) do pcall(fn) end
	local parts = { b.Glass.Template, b.Cork.Template, b.Gas, b.Ball, b.Disc, b.Ring }
	for _, s in ipairs(b.Liquid) do parts[#parts + 1] = s.Template end
	for _, p in ipairs(parts) do pcall(function() p:Destroy() end) end
	for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
	table.clear(keep)
end
--- (2026-10-26) the same let-go without the 10 s idle wait: the Altar showcase calls it on a swap, once the piece that
--- showed this skin is gone (still nothing if a player wears it, a stand-in still shows it, or it is building)
function PP.ReleaseNow()
	usedAt = 0
	releaseKit()
end
if RunService:IsClient() then
	task.spawn(function()
		-- (registered once MeshBudget is there: the lazy getter would otherwise remember it missing for good)
		if script.Parent:WaitForChild("MeshBudget", 10) then
			local b = budget()
			if b then b.Optional(releaseKit) end
		end
	end)
end

local function newPart(s, look, parent)
	local p = Instance.new("Part")
	p.Name = "PixelPotion" .. s.Name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material = (s.Look == "Cork" and Enum.Material.Wood) or (s.Look == "Glass" and Enum.Material.Glass) or Enum.Material.SmoothPlastic
	p.Reflectance = 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Color = (s.Look == "Glass" and GLASS) or (s.Look == "Cork" and CORK) or (look and look.Liquid) or FALLBACK_LOOK.Liquid
	p.Transparency = s.T
	p.Size = s.Size
	p.Parent = parent
	return p
end

--- A bottle under `parent`: "Full" (the M1 bubble) keeps the base liquid, "Compact" takes a random tint. Hidden until
--- first Placed.
function PP.New(kind, parent, look)
	if look and not PP.Look then PP.Look = look end
	PP.Prepare()
	usedAt = os.clock()                                           -- (2026-10-26)
	local o = { Parts = {}, S = nil, F = -1, Hidden = true }
	local vi = (kind == "Full") and 1 or math.random(1, #VARIANTS)   -- (the M1 bubble's own liquid; the rest: different potions)
	if built then
		for i, s in ipairs({ built.Liquid[vi], built.Glass, built.Cork }) do
			local p = s.Template:Clone()
			p.Name = "PixelPotion" .. s.Name
			p.Transparency = 1
			p.Parent = parent
			o.Parts[i] = { Part = p, Spec = s }
		end
	else
		for i, s in ipairs(FALLBACK) do
			local p = newPart(s, look, parent)
			if s.Look == "Liquid" then p.Color = tint(p.Color, VARIANTS[vi]) end
			p.Transparency = 1
			o.Parts[i] = { Part = p, Spec = s }
		end
	end
	return o
end

-- Roblox draws no see-through part behind Glass material: while a bottle fades, its glass is plain plastic, so the
-- fading liquid still shows through it; solid again, it is Glass
local function show(o, f)
	for _, q in ipairs(o.Parts) do
		q.Part.Transparency = q.Spec.T + (1 - q.Spec.T) * f
		if q.Spec.Name == "Glass" then q.Part.Material = (f > 0.02) and Enum.Material.SmoothPlastic or Enum.Material.Glass end
	end
end

--- The bottle at `cf` filling a box of `size` (a Vector3, or a number for a cube). A squashed box keeps only SQUASH of
--- its squash (same volume): a bottle stays bottle-shaped where the Default's sac or puff flattens.
function PP.Place(o, cf, size)
	usedAt = os.clock()                                           -- (2026-10-26)
	local s
	if typeof(size) == "Vector3" then
		local m = math.max(1e-3, size.X * size.Y * size.Z) ^ (1 / 3)
		s = Vector3.new(m * (math.max(1e-3, size.X) / m) ^ SQUASH, m * (math.max(1e-3, size.Y) / m) ^ SQUASH,
			m * (math.max(1e-3, size.Z) / m) ^ SQUASH)
	else
		s = Vector3.new(size or 1, size or 1, size or 1)
	end
	local resize = s ~= o.S
	o.S = s
	for _, q in ipairs(o.Parts) do
		local p = q.Part
		if resize then p.Size = q.Spec.Size * s end
		p.CFrame = cf * CFrame.new(q.Spec.At * s)
	end
	if o.Hidden then                                              -- (the first placing shows it, at its current fade)
		o.Hidden = false
		show(o, math.max(o.F, 0))
	end
end

--- 0 = as built, 1 = gone.
function PP.Fade(o, f)
	f = math.clamp(f or 0, 0, 1)
	if math.abs(f - o.F) < 1e-3 then return end
	o.F = f
	if o.Hidden then return end                                   -- (not placed yet: Place shows it at this fade)
	show(o, f)
end

function PP.Drop(o)
	if not o then return end
	for _, q in ipairs(o.Parts) do pcall(function() q.Part:Destroy() end) end
	table.clear(o.Parts)
end

--- One voxel gas chunk under `parent`, hidden: the caller puts its lobe's colour, material, transparency and size on it,
--- axis-aligned like terrain blocks. A plain block until the mesh is built.
function PP.Gas(parent)
	PP.Prepare()
	usedAt = os.clock()                                           -- (2026-10-26)
	local p
	if built then
		p = built.Gas:Clone()
	else
		p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	end
	p.Name = "PixelPotionGas"
	p.Transparency = 1
	p.Parent = parent
	return p
end

--- One cubical pixel raindrop (ACID RAIN) under `parent`, hidden: the caller puts the Default drop's colour, place and
--- size on it.
function PP.RainDrop(parent)
	local p = Instance.new("Part")
	p.Name = "PixelRainDrop"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material, p.Reflectance = Enum.Material.SmoothPlastic, 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Transparency = 1
	p.Parent = parent
	return p
end

--- ANTITOXIN VENT: the Default's own gas mask (ToxinFX.buildMask's model, body, G), voxelized in place -- each dome
--- becomes the voxel ball, each cylinder the pixel disc (the lens rims a thin pixel ring), at the same size, colour and
--- material; the eye pieces and the canister group sit a little forward of the dome; the straps are blocks already. Returns the new body and G (the same keys, pointing at the new parts), so the Default's own animation
--- (rims, lenses, grille pulse, canister light) runs on them unchanged. Until the meshes are built: the Default's.
function PP.Voxelize(model, body, G)
	PP.Prepare()
	usedAt = os.clock()                                           -- (2026-10-26)
	if not (built and built.Ball and built.Disc and built.Ring) then return body, G end
	-- the details stand clear of the voxel dome's stepped face (flush, they z-fought it in a jagged glow): forward along the
	-- seat's -Z by a share of the head's height (s: buildMask's body is 0.95 s tall)
	local s = body.Size.Y / 0.95
	local lift = {}
	for _, p in ipairs(G.Rims or {}) do lift[p] = 0.07 * s end
	for _, p in ipairs(G.Lenses or {}) do lift[p] = 0.09 * s end
	for _, p in ipairs(G.Ribs or {}) do lift[p] = 0.06 * s end
	for _, p in ipairs({ G.Canister, G.Grille }) do if p then lift[p] = 0.06 * s end end
	local rim = {}
	for _, p in ipairs(G.Rims or {}) do rim[p] = true end
	local swap = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("Part") then
			local sm = p:FindFirstChildOfClass("SpecialMesh")
			local tpl = (rim[p] and built.Ring) or (sm and sm.MeshType == Enum.MeshType.Sphere and built.Ball)
				or (p.Shape == Enum.PartType.Cylinder and built.Disc) or (p.Shape == Enum.PartType.Ball and built.Ball) or nil
			if tpl then
				local q = tpl:Clone()
				q.Name = p.Name
				q.Size = p.Size
				q.Color, q.Material, q.Transparency, q.Reflectance = p.Color, p.Material, p.Transparency, p.Reflectance
				q.Anchored, q.Massless, q.CanCollide, q.CanQuery, q.CanTouch = p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch
				q.CastShadow = p.CastShadow
				for k, v in pairs(p:GetAttributes()) do q:SetAttribute(k, v) end
				local off = q:GetAttribute("Offset")
				if lift[p] and typeof(off) == "CFrame" then q:SetAttribute("Offset", CFrame.new(0, 0, -lift[p]) * off) end
				for _, c in ipairs(p:GetChildren()) do
					if not c:IsA("SpecialMesh") then c.Parent = q end
				end
				q.Parent = model
				p:Destroy()
				swap[p] = q
			end
		end
	end
	local function m(x) return swap[x] or x end
	local G2 = {}
	for k, v in pairs(G) do
		if type(v) == "table" then
			local t = {}
			for n, x in ipairs(v) do t[n] = m(x) end
			G2[k] = t
		else
			G2[k] = m(v)
		end
	end
	-- the air vent: three dark pixel slats across the filter grille's face (the grille's own pulse shows between them),
	-- laid flat in the grille's plane, a hair in front of it
	local gr = G2.Grille
	local goff = gr and gr:GetAttribute("Offset")
	if typeof(goff) == "CFrame" then
		local axis = goff.XVector                                   -- (a cylinder's axis: out of the canister's front)
		local up = Vector3.yAxis - axis * axis:Dot(Vector3.yAxis)
		up = (up.Magnitude > 1e-3) and up.Unit or goff.YVector
		local right = up:Cross(axis).Unit
		for _, k in ipairs({ -1, 0, 1 }) do
			local slat = Instance.new("Part")
			slat.Name = "VentSlat"
			slat.Anchored, slat.Massless, slat.CanCollide, slat.CanQuery, slat.CanTouch, slat.CastShadow = false, true, false, false, false, false
			slat.Material, slat.Reflectance = Enum.Material.SmoothPlastic, 0
			slat.Color = (G2.Canister and G2.Canister.Color) or gr.Color
			slat.Size = Vector3.new(((k == 0) and 0.24 or 0.18) * s, 0.035 * s, 0.02 * s)
			local pos = goff.Position + axis * (gr.Size.X * 0.5 + 0.012 * s) + up * (k * 0.075 * s)
			slat:SetAttribute("Offset", CFrame.fromMatrix(pos, right, up))
			slat.Parent = model
		end
	end
	local b = m(body)
	model.PrimaryPart = b
	return b, G2
end

return PP
