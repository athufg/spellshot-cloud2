--[[
	TerraWrap  (ModuleScript)  ->  ReplicatedStorage/IceMagic/TerraWrap

	Terra's colour-only wraps (SkinCatalog), 2026-10-10: Obsidian Magma on Boulder Shot. Built once per client per wrap
	and CrackGlow, off the render loop, out of the kit's own meshes (EditableMesh -- needs Security "Allow Mesh / Image
	APIs"; without it every cast simply draws Default):
	  STONE     each cell and pebble recoloured into the wrap's three flat bands (by the kit's own baked bands), a thin
	            pale highlight along its sharpest real facet edges, and an ink hull -- all baked into the SAME mesh, so
	            no part is added
	  FISSURES  one Neon mesh per cell: branching, tapering fissures over its outer faces, three hard layers from the
	            outside in and a soft halo faded into the rock by vertex colour (Neon takes vertex colour, not vertex
	            alpha). One mesh per intensity stage (Low / Mid / Max), all the same box, swapped with ApplyMesh.
	The fissures are seeded per cell, so every rock -- and every CrackGlow -- carries the same crack pattern.
	CrackGlow: the SkinCatalog ModuleScript's "CrackGlow" attribute (0..1), or the wrap's own 0.6 when it is unset.

	(2026-10-25) THE LADDER (Sandstone / Rusted Iron Ore / Amethyst Geode / Meteorite Core): each lever below is built
	only for a skin that carries its field -- Obsidian Magma carries none, so its meshes are made exactly as before:
	  VEINS     (Veins) painted ore veins in every stone mesh above (cells, pebbles, plates and halves): flat strips on
	            the outer faces, written before the ink, and (Streak) short runs bleeding DOWN the rock -- no part, no mesh
	  FACETS    (Facets, Rare) per cell one small mesh: its best faces (big, facing up) copied, inset and lifted, flat
	            metal (set.Cells[i].Facet, placed like the Fissure)
	  CRYSTALS  (Crystals, Epic) Variants Neon cluster meshes built once per set and shared (set.Crystal[v]), placed on
	            each cell (set.Cells[i].Crystals) and each whole plate (set.PlateCrystals[v], pivoted like its seam)
	...and, for TerraFX, ChargedRock and the Wall / Tomb kits, the live helpers: Density / Calm (the settings), PulseK /
	FlowMul / GlowMul / HasGlowFx (the breath and the flow), LayerEmitter / LayerSet / LayerRates / LayerBurst (the added
	particle layers, each a share of the Default effect's own count or rate), and Particles' Dust kinds.
	(2026-10-25, fix pass) ...and the baked kits' tier layers, each only for a skin with its field:
	  CrystalTemplates(skin)              (Crystals) the wrap's shared cluster templates for the Wall / Tomb / Aftershock
	                                      pieces -- a built set's own set.Crystal, else the same builder run once per skin
	  Shatter(skin, cf, thin)             (Shatter, Epic) crystal shards flung off the Boulder impact, gone by Life
	  Shockwave(skin, cf, radius, thin)   (Shock, Mythic) an expanding flat Neon ring on the ground (at most 4 alive)
	  DriftSet(skin, host, thin)          (Drift, Mythic) the ambient star-ember emitter on a standing piece
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MeshBudget = require(script.Parent:WaitForChild("MeshBudget"))   -- (2026-10-19) the shared EditableMesh budget's order

local TerraWrap = {}

local catalogScript = ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog")
local Catalog = require(catalogScript)

local LIFT = 0.012        -- studs the fissures sit off the stone (full-size rock)
local STEP = 0.21         -- studs between a fissure's kinks (the mesh budget: 0.16 ran three CrackGlow sets out of it)
-- (2026-10-25) the ladder's geometry (see the header): lifts off the stone, a vein's triangle cap per stone (the mesh
-- budget: a vein is 2 or 6 triangles a step), a crystal cluster's cap, and the cell size a cluster's Size is relative to
-- (lifts kept apart, so nothing crossing is coplanar: a facet's own part at 0.004, the highlight at 0.006, a streak
-- over it but under the vein it bleeds from, a vein over both, the fissures at LIFT over everything -- 0.002 apart at
-- the least: a streak 0.001 over the facet PART, another mesh, z-fought on depth alone)
local VEIN_LIFT, STREAK_LIFT, FACET_LIFT = 0.010, 0.008, 0.004
local VEIN_CAP = { Cell = 240, Plate = 160, Pebble = 72 }
local FACET_INSET = 0.92  -- a facet copy drawn in toward its middle: a sliver of the stone's own band rims it
local CRYSTAL_TRIS = 160  -- a cluster's triangles at most (5 x Sides per prism: root, body, tip)
local CELL_REF = 2.2      -- studs: the kit cells' size (the mean of their two longest sides' geometric means)
local WHITE = Color3.new(1, 1, 1)
local DUST_LIGHT, DUST_DARK = Color3.fromRGB(179, 158, 125), Color3.fromRGB(117, 97, 69)   -- VFXLibrary BOULDER_DUST / _DARK
local built = { Fails = {} }   -- ["<id>@<glow step>"] = set | "building" | false (failed); Fails[key] = failures so far
-- 2026-10-23: a kit mesh this place may not copy (another account's upload: "no permission to load asset" / "not allowed
-- to be forked") is refused for the session: no retries, one warning naming the ids, and the wrap draws Default
local denied, deniedSaid = {}, 0      -- [MeshId] = true; deniedSaid = how many of them the last warning named
local function isDenied(e)
	e = string.lower(tostring(e))
	return string.find(e, "permission", 1, true) ~= nil or string.find(e, "not allowed", 1, true) ~= nil
		or string.find(e, "fork", 1, true) ~= nil
end

--- The wrap `id` of Terra's `ability` (its catalog data), or nil for Default.
function TerraWrap.Skin(ability, id)
	local s = Catalog.Resolve("Terra", ability, id)
	return (type(s) == "table" and s.Stages) and s or nil
end

--- CrackGlow, times CrackGlowOwn (0.8) for the caster's own view: they see a little less glow than everyone else.
function TerraWrap.Glow(skin, own)
	local g = catalogScript:GetAttribute("CrackGlow")
	if type(g) ~= "number" then g = skin and skin.CrackGlow or 0.6 end
	if own then
		local k = catalogScript:GetAttribute("CrackGlowOwn")
		if type(k) ~= "number" then k = skin and skin.CrackGlowOwn or 0.8 end
		g *= math.clamp(k, 0, 1)
	end
	return math.clamp(g, 0, 1)
end

----------------------------------------------------------------------------------------------------
-- mesh plumbing
----------------------------------------------------------------------------------------------------
local function key(v)
	return string.format("%d,%d,%d", math.floor(v.X * 2000 + 0.5), math.floor(v.Y * 2000 + 0.5), math.floor(v.Z * 2000 + 0.5))
end

local function closestOnTri(p, a, b, c)
	local ab, ac, ap = b - a, c - a, p - a
	local d1, d2 = ab:Dot(ap), ac:Dot(ap)
	if d1 <= 0 and d2 <= 0 then return a end
	local bp = p - b
	local d3, d4 = ab:Dot(bp), ac:Dot(bp)
	if d3 >= 0 and d4 <= d3 then return b end
	local vc = d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0 then return a + ab * (d1 / (d1 - d3)) end
	local cp = p - c
	local d5, d6 = ab:Dot(cp), ac:Dot(cp)
	if d6 >= 0 and d5 <= d6 then return c end
	local vb = d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0 then return a + ac * (d2 / (d2 - d6)) end
	local va = d3 * d6 - d5 * d4
	if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	end
	local den = 1 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)
end

local function bbox(em)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, v in ipairs(em:GetVertices()) do
		local p = em:GetPosition(v)
		lo, hi = lo:Min(p), hi:Max(p)
	end
	return lo, hi
end

--- Adds triangles to `em`, turned so their front faces `n` (`front`: the mesh's own winding, true = the cross product
--- of its edges points out of the front), sharing vertices, colours and normals by value.
local function writer(em, front)
	local W, verts, cols, norms = {}, {}, {}, {}
	local uv = nil
	pcall(function() uv = em:AddUV(Vector2.zero) end)
	local function vtx(p)
		local k = key(p)
		local id = verts[k]
		if not id then id = em:AddVertex(p) verts[k] = id end
		return id
	end
	local function col(c)
		local k = c:ToHex()
		local id = cols[k]
		if not id then id = em:AddColor(c, 1) cols[k] = id end
		return id
	end
	local function nrm(n)
		local k = key(n)
		local id = norms[k]
		if not id then id = em:AddNormal(n) norms[k] = id end
		return id
	end
	W.Col = col
	function W.Tri(a, b, c, ca, cb, cc, n)
		local cr = (b - a):Cross(c - a)
		if cr.Magnitude < 1e-10 then return end
		if (cr:Dot(n) > 0) ~= front then b, c, cb, cc = c, b, cc, cb end
		local f = em:AddTriangle(vtx(a), vtx(b), vtx(c))
		em:SetFaceColors(f, { col(ca), col(cb), col(cc) })
		local ni = nrm(n)
		em:SetFaceNormals(f, { ni, ni, ni })
		if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
	end
	-- `a` toward the line, `b` away from it: cA on a's edge, cB on b's
	function W.Quad(a0, b0, a1, b1, cA, cB, n)
		W.Tri(a0, b0, b1, cA, cB, cB, n)
		W.Tri(a0, b1, a1, cA, cB, cA, n)
	end
	return W
end

-- Only a handful of RESIZABLE meshes may exist at once in-experience (8, measured in Play 2026-10-10; fixed-size ones
-- are cheap -- 200 and counting), so each mesh is built resizable, copied into a fixed-size one and let go.
-- ...and the builds run side by side (2026-10-10: one at a time took ~25 s, and a first cast in that time drew
-- Default), each mesh under construction holding one of SLOTS: every build on this client together stays under the 8.
local SLOTS = 3   -- (6 ran out of budget with a second build alive; under pressure retry() waits it out)
local free, held = SLOTS, {}
local function acquire()
	while free <= 0 do task.wait() end
	free -= 1
	local co = coroutine.running()
	held[co] = (held[co] or 0) + 1
end
local function release()
	free += 1
	local co = coroutine.running()
	held[co] = (held[co] or 1) - 1
end
--- fn(i) for i = 1..n side by side; returns when all are done (raising the first error), every slot given back.
-- (2026-10-25, the ladder) [thread] = the list a set's fixed meshes go into while that set builds (TerraWrap.Get sets it,
-- parallel() hands it on to the threads it spawns), so ONE set can be let go with its own meshes -- see dropUnworn
local sinkOf = setmetatable({}, { __mode = "k" })
local dropUnworn, wornNow          -- (defined with MakeRoom, below; wornNow: the ids worn at the last worn ask)
-- (2026-10-25, fix pass) the baked kits' tier layers (defined at the end): adoptCrystals keeps a dropped set's crystal
-- templates that a Wall / Tomb / Aftershock piece was handed (CrystalTemplates) alive for the session; ringKick builds a
-- Mythic's shock ring meshes. fixedOf[part] = the fixed mesh makePart made it from (so one template can outlive its set).
local adoptCrystals, ringKick
local fixedOf = setmetatable({}, { __mode = "k" })
local function parallel(n, fn)
	local left, err = n, nil
	local sink = sinkOf[coroutine.running()]
	for i = 1, n do
		task.spawn(function()
			sinkOf[coroutine.running()] = sink
			local ok, e = pcall(fn, i)
			local co = coroutine.running()
			free += held[co] or 0
			held[co] = nil
			if not ok and err == nil then err = e end
			left -= 1
		end)
	end
	while left > 0 do task.wait() end
	if err ~= nil then error(err, 0) end
end

--- `make()` until it gives a mesh: under memory pressure the engine hands back nil, so wait and try again (~10 s).
local essential = 0       -- worn wraps' builds running now (2026-10-19, MeshBudget)
local function retry(make, asset)
	if asset and denied[asset] then error("DENIED " .. asset, 0) end
	for i = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		if not ok and isDenied(m) then         -- (2026-10-23) a refusal is final: not 40 tries, and no MakeRoom for it
			if asset then denied[asset] = true end
			error("DENIED " .. tostring(asset or m), 0)
		end
		if essential > 0 and i % 8 == 1 then
			MeshBudget.MakeRoom()                                        -- (a worn wrap: a skin nobody wears makes way)
			if wornNow then dropUnworn(wornNow) end                     -- (2026-10-25: ...and a Terra wrap nobody wears now)
		end
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

-- (2026-10-29) THE KIT'S GEOMETRY AS DATA (TerraWrapGeo, generated in Studio by the meshes' uploader): the source
-- meshes rebuilt with AssetService:CreateEditableMesh(), which needs no asset permission. CreateEditableMeshAsync on a
-- kit mesh is refused when the place's owner did not upload it -- every other player (a co-developer in Team Test,
-- everyone on a live server) then drew a worn wrap as Default. A mesh missing from the data loads from its asset.
local geoData = nil
local function geoOf(meshId)
	if geoData == nil then
		geoData = {}
		local folder = script.Parent:FindFirstChild("TerraWrapGeo")
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:IsA("ModuleScript") then
				local ok, t = pcall(require, m)
				if ok and type(t) == "table" then for k, v in pairs(t) do geoData[k] = v end end
			end
		end
	end
	return geoData[meshId]
end
local function geoNums(s)
	local t = {}
	for x in string.gmatch(s, "[^,;]+") do t[#t + 1] = tonumber(x) end
	return t
end
--- Kit mesh `meshId` rebuilt from TerraWrapGeo as a resizable EditableMesh (positions, faces, normals, colours, UVs as
--- the asset has them, faces in the asset's order), or nil when the data has no such mesh.
local function geoMesh(meshId)
	local s = geoOf(meshId)
	if type(s) ~= "string" then return nil end
	local vs, ns, cs, us, fs = string.match(s, "^V(.-)|N(.-)|C(.-)|U(.-)|F(.*)$")
	if not vs then return nil end
	local em = retry(function() return AssetService:CreateEditableMesh({ FixedSize = false }) end)
	local ok, err = pcall(function()
		local V, N, C, U = {}, {}, {}, {}
		local p = geoNums(vs)
		for i = 1, #p, 3 do V[#V + 1] = em:AddVertex(Vector3.new(p[i], p[i + 1], p[i + 2])) end
		p = geoNums(ns)
		for i = 1, #p, 3 do N[#N + 1] = em:AddNormal(Vector3.new(p[i], p[i + 1], p[i + 2])) end
		p = geoNums(cs)
		for i = 1, #p, 4 do C[#C + 1] = em:AddColor(Color3.fromRGB(p[i], p[i + 1], p[i + 2]), p[i + 3]) end
		p = geoNums(us)
		for i = 1, #p, 2 do U[#U + 1] = em:AddUV(Vector2.new(p[i], p[i + 1])) end
		p = geoNums(fs)
		for i = 1, #p, 12 do
			local f = em:AddTriangle(V[p[i]], V[p[i + 1]], V[p[i + 2]])
			if p[i + 3] > 0 then em:SetFaceNormals(f, { N[p[i + 3]], N[p[i + 4]], N[p[i + 5]] }) end
			if p[i + 6] > 0 then em:SetFaceColors(f, { C[p[i + 6]], C[p[i + 7]], C[p[i + 8]] }) end
			if p[i + 9] > 0 then em:SetFaceUVs(f, { U[p[i + 9]], U[p[i + 10]], U[p[i + 11]] }) end
		end
	end)
	if not ok then
		em:Destroy()
		error(err, 0)
	end
	return em
end

local keep = {}
local function makePart(em)
	-- (2026-10-19, audit GB-01) the resizable mesh is let go whether or not its fixed copy is made: when retry() gave up,
	-- the error used to skip em:Destroy(), and the mesh held its share of the ~8 for the session (FrostDragonKit's rule)
	local okF, fixed = pcall(retry, function() return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true }) end)
	em:Destroy()
	release()
	if not okF then error(fixed, 0) end
	local sink = sinkOf[coroutine.running()]
	if sink then sink[#sink + 1] = fixed else keep[#keep + 1] = fixed end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok then mp = AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch = true, false, false, false
	fixedOf[mp] = fixed       -- (2026-10-25, fix pass: see adoptCrystals)
	return mp
end

----------------------------------------------------------------------------------------------------
-- the stone: bands, highlight, ink
----------------------------------------------------------------------------------------------------
local paintVeins          -- (2026-10-25: the skin's Veins, defined with the fissures below -- it walks the same way)

--- One kit stone re-made in the wrap. `rel`: its frame in the rock (identity for a pebble). Returns the template, the
--- offset of its new box from the old one, the old box's centre, its triangles (mesh space, Outer marked), and the winding.
--- (2026-10-25) `vseed` / `vkind` ("Cell" / "Pebble" / "Plate"): the stone's index and kind for its Veins (only read
--- when the skin has Veins).
local function buildStone(src, rel, skin, edges, toon, vseed, vkind)
	-- resizable: an asset mesh is fixed-size in-experience by default, and the highlight and the ink are added to it
	acquire()
	-- (2026-10-29) from the kit's geometry data when it has the mesh (no asset permission: everyone sees the wrap, not
	-- only the meshes' uploader), else from its asset as before
	local em = geoMesh(src.MeshId)
		or retry(function() return AssetService:CreateEditableMeshAsync(Content.fromUri(src.MeshId), { FixedSize = false }) end, src.MeshId)
	-- (2026-10-19, audit GB-01) the writes below can raise (a vertex or face limit, a bad colour): the resizable mesh is
	-- destroyed then too, not kept for the session; the error goes on to the build (which draws Default)
	local function body()
		local front, tris = nil, {}
		for _, f in ipairs(em:GetFaces()) do
			local vs = em:GetFaceVertices(f)
			local a, b, c = em:GetPosition(vs[1]), em:GetPosition(vs[2]), em:GetPosition(vs[3])
			local cr = (b - a):Cross(c - a)
			if front == nil then
				local ok, ns = pcall(em.GetFaceNormals, em, f)
				local sn = ok and ns and ns[1] and em:GetNormal(ns[1]) or nil
				front = not sn or cr:Dot(sn) >= 0
			end
			local cl = em:GetColor(em:GetFaceColors(f)[1]) or Color3.new(0.5, 0.5, 0.5)
			tris[#tris + 1] = { F = f, P = { a, b, c }, N = cr.Magnitude > 1e-10 and cr.Unit or Vector3.yAxis,
				Area = cr.Magnitude / 2, Lum = 0.3 * cl.R + 0.59 * cl.G + 0.11 * cl.B }
		end
		front = front ~= false
		local W = writer(em, front)
		local lo0, hi0 = bbox(em)
		local c0 = (lo0 + hi0) / 2
		local R, tint = skin.Rock, skin.RockTint
		local function shade(c) return Color3.new(c.R * tint.R, c.G * tint.G, c.B * tint.B) end
		local lk = skin.LitTint or tint.R
		local bands = { W.Col(shade(R.Shadow)), W.Col(shade(R.Mid)), W.Col(Color3.new(R.Lit.R * lk, R.Lit.G * lk, R.Lit.B * lk)) }
		local inkId = W.Col(skin.Ink)
		for _, t in ipairs(tris) do
			local cen = (t.P[1] + t.P[2] + t.P[3]) / 3
			local rp = rel * (cen - c0)
			local nr = rel.Rotation * t.N
			t.Cen = cen
			t.Up = nr.Y
			local id
			if toon then
				-- a toon kit mesh (a plate): its ink hull (~0.06) stays ink, its Dark / Base / Light bands keep their places;
				-- outer = facing the plate's outside (its pivot's LookVector)
				t.Ink = t.Lum < 0.09
				t.Outer = not t.Ink and nr:Dot(Vector3.new(0, 0, -1)) > 0.5
				id = t.Ink and inkId or bands[(t.Lum < 0.25 and 1) or (t.Lum < 0.55 and 2) or 3]
			else
				-- the boulder: the top-facing facets take the lit band (owner, checkpoint 2: so the dark rock reads faceted,
				-- not a flat block), the underside and the deep cuts the shadow band
				t.Outer = nr:Dot(rp.Magnitude > 1e-3 and rp.Unit or nr) > 0.25
				id = bands[(t.Up > 0.45 and 3) or ((t.Lum < 0.08 or t.Up < -0.4) and 1) or 2]
			end
			em:SetFaceColors(t.F, { id, id, id })
		end
		-- THE HIGHLIGHT: a thin pale strip on the lit side of the sharpest edges between two outer facets
		local byEdge = {}
		for i, t in ipairs(tris) do
			for k = 1, 3 do
				local p, q = t.P[k], t.P[k % 3 + 1]
				local ka, kb = key(p), key(q)
				local ek = ka < kb and (ka .. "|" .. kb) or (kb .. "|" .. ka)
				local e = byEdge[ek]
				if not e then
					e = { P = p, Q = q, T = {} }
					byEdge[ek] = e
				end
				table.insert(e.T, i)
			end
		end
		local cands = {}
		for _, e in pairs(byEdge) do
			local t1, t2 = tris[e.T[1]], tris[e.T[2]]
			local ok = #e.T == 2 and (toon and not (t1.Ink or t2.Ink) and (t1.Outer or t2.Outer) or (t1.Outer and t2.Outer))
			if ok then
				local ang = math.acos(math.clamp(t1.N:Dot(t2.N), -1, 1))
				local len = (e.Q - e.P).Magnitude
				if ang > 0.5 and len > 0.3 then
					local lit = ((t1.Up >= t2.Up or not t2.Outer) and t1.Outer) and t1 or t2
					cands[#cands + 1] = { E = e, T = lit, Score = len * ang * (1.2 + lit.Up) }
				end
			end
		end
		table.sort(cands, function(x, y) return x.Score > y.Score end)
		local hl, hw = skin.Highlight, skin.HighlightWidth
		for n = 1, math.min(edges, #cands) do
			local cd = cands[n]
			local p, q, t = cd.E.P, cd.E.Q, cd.T
			local inn = t.N:Cross((q - p).Unit)
			if inn:Dot(t.Cen - (p + q) / 2) < 0 then inn = -inn end
			local a, b = p + (q - p) * 0.06, q - (q - p) * 0.06
			local up = t.N * 0.006
			W.Tri(a + up, b + up, b + inn * hw * 0.5 + up, hl, hl, hl, t.N)
			W.Tri(a + up, b + inn * hw * 0.5 + up, (a + b) / 2 + inn * hw + up, hl, hl, hl, t.N)
		end
		-- (2026-10-25) THE VEINS (a skin with Veins only): painted on the outer faces, before the ink
		if skin.Veins then
			local n = paintVeins(W, tris, rel, skin.Veins, vseed or 0, vkind or "Pebble")
			TerraWrap.ExtraTris = TerraWrap.ExtraTris or { Veins = 0, Facets = 0, Crystals = 0 }
			TerraWrap.ExtraTris.Veins += n
		end
		-- THE INK: an inverted hull, pushed out along the smoothed normals so it stays closed over the hard edges
		-- (a toon kit mesh has its own)
		local hullTris = toon and {} or tris
		local sn = {}
		for _, t in ipairs(hullTris) do
			for k = 1, 3 do
				local kk = key(t.P[k])
				sn[kk] = (sn[kk] or Vector3.zero) + t.N * t.Area
			end
		end
		local ink, th = skin.Ink, skin.InkWidth
		for _, t in ipairs(hullTris) do
			local q = {}
			for k = 1, 3 do
				local v = sn[key(t.P[k])]
				q[k] = t.P[k] + ((v and v.Magnitude > 1e-8) and v.Unit or t.N) * th
			end
			W.Tri(q[1], q[2], q[3], ink, ink, ink, -t.N)
		end
		local lo, hi = bbox(em)
		local c1 = (lo + hi) / 2
		for _, v in ipairs(em:GetVertices()) do em:SetPosition(v, em:GetPosition(v) - c1) end
		return makePart(em), CFrame.new(c1 - c0), c0, tris, front
	end
	local res = table.pack(pcall(body))
	if not res[1] then
		pcall(function() em:Destroy() end)
		error(res[2], 0)
	end
	return table.unpack(res, 2, res.n)
end

----------------------------------------------------------------------------------------------------
-- the fissures
----------------------------------------------------------------------------------------------------
local function project(outer, p)
	local best, bq, bt = math.huge, p, outer[1]
	for _, t in ipairs(outer) do
		local q = closestOnTri(p, t.P[1], t.P[2], t.P[3])
		local d = (q - p).Magnitude
		if d < best then best, bq, bt = d, q, t end
	end
	return bq, bt, best
end

local function tangent(v, n)
	local d = v - n * v:Dot(n)
	return d.Magnitude > 1e-4 and d.Unit or nil
end

--- The cell's fissures: polylines of { P, N } on its outer faces, each with a width per point (0..1).
local function fissureLines(outer, rng)
	local area = 0
	for _, t in ipairs(outer) do area += t.Area end
	local starts, lines = {}, {}
	local function pick()
		local bp, bt, bd = nil, nil, -1
		for _ = 1, 10 do
			local r = rng:NextNumber() * area
			local t = outer[#outer]
			for _, tt in ipairs(outer) do
				r -= tt.Area
				if r <= 0 then t = tt break end
			end
			local u, v = rng:NextNumber(), rng:NextNumber()
			if u + v > 1 then u, v = 1 - u, 1 - v end
			local p = t.P[1] + (t.P[2] - t.P[1]) * u + (t.P[3] - t.P[1]) * v
			local dmin = 1e9
			for _, s in ipairs(starts) do dmin = math.min(dmin, (s - p).Magnitude) end
			if dmin > bd then bp, bt, bd = p, t, dmin end
		end
		starts[#starts + 1] = bp
		return bp, bt
	end
	-- a jagged walk: kinks alternate about a heading that drifts; across an edge a point is put on the edge itself
	local function walk(p, t, dir, steps)
		local pts = { { P = p, N = t.N, T = t } }
		local kink = rng:NextNumber() < 0.5 and 1 or -1
		for _ = 1, steps do
			local last = pts[#pts]
			dir = tangent(dir, last.N)
			if not dir then break end
			local side = last.N:Cross(dir)
			-- irregular, not a regular zigzag (a regular one reads as a lightning bolt -- Voltaic's)
			if rng:NextNumber() < 0.7 then kink = -kink end
			local turn = kink * rng:NextNumber(0.12, 0.5) + rng:NextNumber(-0.1, 0.1)
			local want = last.P + (dir * math.cos(turn) + side * math.sin(turn)) * (STEP * rng:NextNumber(0.75, 1.25))
			local q, qt, dist = project(outer, want)
			if dist > STEP * 0.6 or (q - last.P).Magnitude < STEP * 0.3 then break end
			if qt ~= last.T then
				local m, mt = project(outer, (last.P + q) / 2)
				local n2 = last.T.N + qt.N
				pts[#pts + 1] = { P = m, N = n2.Magnitude > 1e-3 and n2.Unit or mt.N, T = mt }
			end
			pts[#pts + 1] = { P = q, N = qt.N, T = qt }
			dir = (dir + side * rng:NextNumber(-0.25, 0.25)).Unit
		end
		return pts
	end
	local count = math.clamp(math.floor(area / 2.2 + 0.5), 1, 3)
	for _ = 1, count do
		local p, t = pick()
		local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local dir = tangent(r, t.N) or tangent(Vector3.xAxis, t.N) or Vector3.zAxis
		local fwd = walk(p, t, dir, rng:NextInteger(4, 6))
		local back = walk(p, t, -dir, rng:NextInteger(3, 5))
		local pts = {}
		for i = #back, 2, -1 do pts[#pts + 1] = back[i] end
		for _, q in ipairs(fwd) do pts[#pts + 1] = q end
		if #pts >= 3 then
			local w = {}
			for i = 1, #pts do
				local s = (i - 1) / (#pts - 1)
				w[i] = (i == 1 or i == #pts) and 0.12 or (0.3 + 0.7 * math.sin(math.pi * s) ^ 0.6)
			end
			lines[#lines + 1] = { Pts = pts, W = w }
			-- a branch or two off the middle, thinner, tapering to nothing
			for _ = 1, (rng:NextNumber() < 0.8 and 1 or 0) + (rng:NextNumber() < 0.3 and 1 or 0) do
				local j = rng:NextInteger(math.max(2, math.floor(#pts * 0.3)), math.max(2, math.floor(#pts * 0.7)))
				local at = pts[j]
				local d0 = tangent(pts[math.min(#pts, j + 1)].P - pts[j - 1].P, at.N)
				if d0 then
					local a = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.55, 1.0)
					local bdir = d0 * math.cos(a) + at.N:Cross(d0) * math.sin(a)
					local br = walk(at.P, at.T, bdir, rng:NextInteger(2, 4))
					if #br >= 3 then
						local bw = {}
						for i = 1, #br do bw[i] = w[j] * 0.7 * (1 - (i - 1) / (#br - 1)) ^ 0.8 + 0.06 end
						lines[#lines + 1] = { Pts = br, W = bw }
					end
				end
			end
		end
	end
	return lines
end

--- The triangles of every fissure at one stage: the stage's hard bands from the centre out, then the halo -- from its
--- colour (stronger with CrackGlow) to the dark rock -- widening with CrackGlow. { a, b, c, ca, cb, cc, n } each.
local function stageTris(lines, prof, glow, skin)
	local out = {}
	local edges, cols = { 0 }, {}
	for i, b in ipairs(prof.Bands) do
		edges[i + 1] = b[1]
		cols[i] = b[2]
	end
	local hw = prof.Halo[1] + prof.Halo[2] * glow
	local dark = skin.HaloEdge
	-- two steps out to the dark rock, the outer one faint: Neon lights even a dull red brightly, so a single straight
	-- blend read as a solid orange band, not a halo
	local haloIn = dark:Lerp(prof.HaloCol, math.clamp(0.35 + 0.65 * glow, 0, 1))
	local haloMid = dark:Lerp(prof.HaloCol, math.clamp(0.3 * glow, 0, 1))
	local function quad(a0, b0, a1, b1, cA, cB, n)
		out[#out + 1] = { a0, b0, b1, cA, cB, cB, n }
		out[#out + 1] = { a0, b1, a1, cA, cB, cA, n }
	end
	for _, L in ipairs(lines) do
		local pts, w = L.Pts, L.W
		local n = #pts
		local S = {}
		for i = 1, n do
			local tg = pts[math.min(n, i + 1)].P - pts[math.max(1, i - 1)].P
			tg = tg.Magnitude > 1e-6 and tg.Unit or Vector3.xAxis
			local s = pts[i].N:Cross(tg)
			S[i] = s.Magnitude > 1e-6 and s.Unit or Vector3.yAxis
		end
		local function at(i, off) return pts[i].P + S[i] * (off * w[i]) + pts[i].N * LIFT end
		for i = 1, n - 1 do
			local nn = pts[i].N + pts[i + 1].N
			nn = nn.Magnitude > 1e-6 and nn.Unit or pts[i].N
			for side = -1, 1, 2 do
				for k = 1, #cols do
					local o0, o1 = edges[k] * side, edges[k + 1] * side
					quad(at(i, o0), at(i, o1), at(i + 1, o0), at(i + 1, o1), cols[k], cols[k], nn)
				end
				local e0 = edges[#edges]
				local o0, om, o1 = e0 * side, (e0 + 0.35 * hw) * side, (e0 + hw) * side
				quad(at(i, o0), at(i, om), at(i + 1, o0), at(i + 1, om), haloIn, haloMid, nn)
				quad(at(i, om), at(i, o1), at(i + 1, om), at(i + 1, o1), haloMid, dark, nn)
			end
		end
	end
	return out
end

--- One cell's three stage meshes, all in the same box (a speck of dark at each corner), so ApplyMesh swaps them in place.
local function buildFissures(tris, front, c0, rel, cellIndex, skin, glow)
	local outer = {}
	for _, t in ipairs(tris) do
		if t.Outer then outer[#outer + 1] = t end
	end
	if #outer == 0 then return nil end
	local lines = fissureLines(outer, Random.new(7919 * cellIndex))
	if #lines == 0 then return nil end
	local sets, lo, hi = {}, Vector3.one * 1e9, -Vector3.one * 1e9
	for _, stage in ipairs({ "Low", "Mid", "Max" }) do
		local list = stageTris(lines, skin.Stages[stage], glow, skin)
		for _, tr in ipairs(list) do
			for k = 1, 3 do lo, hi = lo:Min(tr[k]), hi:Max(tr[k]) end
		end
		sets[stage] = list
	end
	local c = (lo + hi) / 2
	local out = { Rel = rel * CFrame.new(c - c0), C = c, C0 = c0 }
	local speck, e = skin.HaloEdge, 1e-3
	for stage, list in pairs(sets) do
		acquire()
		local em = retry(function() return AssetService:CreateEditableMesh() end)
		local okW, errW = pcall(function()                      -- (2026-10-19, audit GB-01) a failed write frees the mesh
			local W = writer(em, front)
			for _, tr in ipairs(list) do W.Tri(tr[1] - c, tr[2] - c, tr[3] - c, tr[4], tr[5], tr[6], tr[7]) end
			W.Tri(lo - c, lo - c + Vector3.new(e, 0, 0), lo - c + Vector3.new(0, e, 0), speck, speck, speck, Vector3.zAxis)
			W.Tri(hi - c, hi - c - Vector3.new(e, 0, 0), hi - c - Vector3.new(0, e, 0), speck, speck, speck, -Vector3.zAxis)
		end)
		if not okW then
			pcall(function() em:Destroy() end)
			error(errW, 0)
		end
		local mp = makePart(em)
		mp.Material = Enum.Material.Neon
		TerraWrap.Tris = (TerraWrap.Tris or 0) + #list
		out[stage] = mp
		out.Size = mp.Size
		task.wait()
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- (2026-10-25) the ladder's stone work: veins, facets, crystals (each only for a skin with its field)
----------------------------------------------------------------------------------------------------
local function c3(c, default) return typeof(c) == "Color3" and c or default end
--- A number from `r` ({ a, b } or a number) by `rng`, `a`..`b` when it is missing; the ends in either order.
local function between(rng, r, a, b)
	if type(r) == "number" then return r end
	if type(r) == "table" then a, b = tonumber(r[1]) or a, tonumber(r[2] or r[1]) or b end
	return rng:NextNumber(math.min(a, b), math.max(a, b))
end

--- A flat strip along the polyline `pts` ({ P, N, T } on the stone), `half` studs either side of it times w[i], lifted
--- `lift` off the faces: one band of `core`, or with `edge` the middle third `core` and the outer thirds `edge` -- hard
--- steps, written with the stone's writer. Returns the triangles it asked for.
local function veinStrip(W, pts, w, half, core, edge, lift)
	local n = #pts
	if n < 2 then return 0 end
	local S = {}
	for i = 1, n do
		local tg = pts[math.min(n, i + 1)].P - pts[math.max(1, i - 1)].P
		tg = tg.Magnitude > 1e-6 and tg.Unit or Vector3.xAxis
		local s = pts[i].N:Cross(tg)
		S[i] = s.Magnitude > 1e-6 and s.Unit or Vector3.yAxis
	end
	local function at(i, off) return pts[i].P + S[i] * (off * w[i]) + pts[i].N * lift end
	local cuts = edge and { -half, -half / 3, half / 3, half } or { -half, half }
	local cols = edge and { edge, core, edge } or { core }
	for i = 1, n - 1 do
		local nn = pts[i].N + pts[i + 1].N
		nn = nn.Magnitude > 1e-6 and nn.Unit or pts[i].N
		for k = 1, #cols do
			W.Quad(at(i, cuts[k]), at(i, cuts[k + 1]), at(i + 1, cuts[k]), at(i + 1, cuts[k + 1]), cols[k], cols[k], nn)
		end
	end
	return (n - 1) * #cols * 2
end

--- VEINS: the skin's ore veins painted on one stone's outer faces with its own writer `W` (so nothing is added but
--- triangles): PerArea lines a stud^2 (at least one on a cell; a pebble may get none), each walked like a fissure but
--- with its turns scaled by Kink (1 = the fissure's jag, 0.1 = an etched straight line) and Steps steps, a thinner
--- branch at Branch, and -- Streak -- short runs bleeding DOWN the rock from points along it: `rel`'s -Y (the rock's
--- down; for a plate its own frame) laid on the faces, stopping on a flat top. Seeded by Seed and the stone's index;
--- capped at VEIN_CAP[kind] triangles. Returns the triangles written.
function paintVeins(W, tris, rel, V, vseed, vkind)
	local outer, area = {}, 0
	for _, t in ipairs(tris) do
		if t.Outer then
			outer[#outer + 1] = t
			area += t.Area
		end
	end
	local per = tonumber(V.PerArea) or 0
	if #outer == 0 or per <= 0 or area <= 0 then return 0 end
	local rng = Random.new((math.floor(tonumber(V.Seed) or 0) + 7919 * vseed) % 2147483647)
	local x = area * per
	local count = math.floor(x) + ((rng:NextNumber() < x - math.floor(x)) and 1 or 0)
	if vkind == "Cell" then count = math.max(count, 1) end
	if count <= 0 then return 0 end
	local cap = VEIN_CAP[vkind] or VEIN_CAP.Pebble
	local kinkK = math.clamp(tonumber(V.Kink) or 1, 0, 1)
	local steps = type(V.Steps) == "table" and V.Steps or { 4, 6 }
	local s0 = math.max(2, math.floor(tonumber(steps[1]) or 4))
	local s1 = math.max(s0, math.floor(tonumber(steps[2]) or s0))
	local half = (tonumber(V.Width) or 0.05) / 2
	local core, edge = c3(V.Core, WHITE), c3(V.Edge, nil)
	local branch = tonumber(V.Branch) or 0
	local SK = type(V.Streak) == "table" and V.Streak or nil
	local down = rel:VectorToObjectSpace(Vector3.new(0, -1, 0))
	local written, starts = 0, {}
	-- a start spread from the others (the fissures' pick: the farthest of ten area-weighted tries)
	local function pick()
		local bp, bt, bd = nil, nil, -1
		for _ = 1, 10 do
			local r = rng:NextNumber() * area
			local t = outer[#outer]
			for _, tt in ipairs(outer) do
				r -= tt.Area
				if r <= 0 then t = tt break end
			end
			local u, v = rng:NextNumber(), rng:NextNumber()
			if u + v > 1 then u, v = 1 - u, 1 - v end
			local p = t.P[1] + (t.P[2] - t.P[1]) * u + (t.P[3] - t.P[1]) * v
			local dmin = 1e9
			for _, s in ipairs(starts) do dmin = math.min(dmin, (s - p).Magnitude) end
			if dmin > bd then bp, bt, bd = p, t, dmin end
		end
		starts[#starts + 1] = bp
		return bp, bt
	end
	-- the fissures' walk, its kinks and its drift scaled by Kink
	local function walk(p, t, dir, n)
		local pts = { { P = p, N = t.N, T = t } }
		local kink = rng:NextNumber() < 0.5 and 1 or -1
		for _ = 1, n do
			local last = pts[#pts]
			dir = tangent(dir, last.N)
			if not dir then break end
			local side = last.N:Cross(dir)
			if rng:NextNumber() < 0.7 then kink = -kink end
			local turn = (kink * rng:NextNumber(0.12, 0.5) + rng:NextNumber(-0.1, 0.1)) * kinkK
			local want = last.P + (dir * math.cos(turn) + side * math.sin(turn)) * (STEP * rng:NextNumber(0.75, 1.25))
			local q, qt, dist = project(outer, want)
			if dist > STEP * 0.6 or (q - last.P).Magnitude < STEP * 0.3 then break end
			if qt ~= last.T then
				local m, mt = project(outer, (last.P + q) / 2)
				local n2 = last.T.N + qt.N
				pts[#pts + 1] = { P = m, N = n2.Magnitude > 1e-3 and n2.Unit or mt.N, T = mt }
			end
			pts[#pts + 1] = { P = q, N = qt.N, T = qt }
			local d2 = dir + side * (rng:NextNumber(-0.25, 0.25) * kinkK)
			dir = d2.Magnitude > 1e-6 and d2.Unit or dir
		end
		return pts
	end
	-- a rust run from vein point `at`: down the faces in short steps, tapering
	local function streak(at)
		local len = between(rng, SK.Length, 0.25, 0.6)
		local sp, gone, stepL = { at }, 0, 0.09
		for _ = 1, 10 do
			if gone >= len then break end
			local last = sp[#sp]
			local d = down - last.N * down:Dot(last.N)
			if d.Magnitude < 0.3 then break end         -- a flat top: the rust has nowhere to run
			local q, qt, dist = project(outer, last.P + d.Unit * stepL)
			if dist > stepL * 0.6 or (q - last.P).Magnitude < stepL * 0.3 then break end
			if qt ~= last.T then
				local m, mt = project(outer, (last.P + q) / 2)
				local n2 = last.T.N + qt.N
				sp[#sp + 1] = { P = m, N = n2.Magnitude > 1e-3 and n2.Unit or mt.N, T = mt }
			end
			sp[#sp + 1] = { P = q, N = qt.N, T = qt }
			gone += (q - last.P).Magnitude
		end
		if #sp < 2 then return 0 end
		local w = {}
		for i = 1, #sp do w[i] = 1 - 0.75 * (i - 1) / (#sp - 1) end
		return veinStrip(W, sp, w, (tonumber(SK.Width) or 0.035) / 2, c3(SK.Core, core), c3(SK.Edge, nil), STREAK_LIFT)
	end
	for _ = 1, count do
		if written >= cap then break end
		local p, t = pick()
		local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local dir = tangent(r, t.N) or tangent(Vector3.xAxis, t.N) or Vector3.zAxis
		local total = rng:NextInteger(s0, s1)
		local nf = math.ceil(total * 0.55)
		local fwd = walk(p, t, dir, nf)
		local back = walk(p, t, -dir, math.max(1, total - nf))
		local pts = {}
		for i = #back, 2, -1 do pts[#pts + 1] = back[i] end
		for _, q in ipairs(fwd) do pts[#pts + 1] = q end
		if #pts >= 2 then
			local w = {}
			for i = 1, #pts do
				local s = (i - 1) / (#pts - 1)
				w[i] = (i == 1 or i == #pts) and 0.35 or (0.6 + 0.4 * math.sin(math.pi * s) ^ 0.6)
			end
			written += veinStrip(W, pts, w, half, core, edge, VEIN_LIFT)
			-- a branch (now and then two) off the middle, thinner, tapering
			local nb = ((rng:NextNumber() < branch) and 1 or 0) + ((rng:NextNumber() < branch * 0.35) and 1 or 0)
			for _ = 1, nb do
				if #pts >= 3 and written < cap then
					local j = rng:NextInteger(math.max(2, math.floor(#pts * 0.3)), math.max(2, math.min(#pts - 1, math.floor(#pts * 0.7))))
					local at = pts[j]
					local d0 = tangent(pts[j + 1].P - pts[j - 1].P, at.N)
					if d0 then
						local a = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.55, 1.0)
						local br = walk(at.P, at.T, d0 * math.cos(a) + at.N:Cross(d0) * math.sin(a), math.max(2, math.floor(total * 0.45)))
						if #br >= 2 then
							local bw = {}
							for i = 1, #br do bw[i] = w[j] * 0.75 * (1 - (i - 1) / (#br - 1)) ^ 0.8 + 0.15 end
							written += veinStrip(W, br, bw, half, core, edge, VEIN_LIFT)
						end
					end
				end
			end
			-- the rust bleeding from it (one run at Chance, a second at half that)
			if SK then
				for m = 1, 2 do
					if written < cap and rng:NextNumber() < (tonumber(SK.Chance) or 0) * (m == 1 and 1 or 0.5) then
						written += streak(pts[rng:NextInteger(1, #pts)])
					end
				end
			end
		end
	end
	return written
end

--- A stone's outer faces grouped into its flat facets (outer triangles sharing an edge and, near enough, a plane): each
--- { Tris, Area, N (mesh space), Cen (its area centre, mesh space), NR / RP (the normal / centre in `rel`'s space) }.
local function facetsOf(tris, rel, c0)
	local outer = {}
	for _, t in ipairs(tris) do
		if t.Outer then outer[#outer + 1] = t end
	end
	local up = {}
	for i = 1, #outer do up[i] = i end
	local function root(i)
		while up[i] ~= i do
			up[i] = up[up[i]]
			i = up[i]
		end
		return i
	end
	local byEdge = {}
	for i, t in ipairs(outer) do
		for k = 1, 3 do
			local ka, kb = key(t.P[k]), key(t.P[k % 3 + 1])
			local ek = ka < kb and (ka .. "|" .. kb) or (kb .. "|" .. ka)
			local j = byEdge[ek]
			if j == nil then
				byEdge[ek] = i
			elseif outer[j].N:Dot(t.N) > 0.995 then
				local a, b = root(i), root(j)
				if a ~= b then up[a] = b end
			end
		end
	end
	local groups, list = {}, {}
	for i, t in ipairs(outer) do
		local r = root(i)
		local g = groups[r]
		if not g then
			g = { Tris = {}, Area = 0, Ns = Vector3.zero, Cs = Vector3.zero }
			groups[r] = g
			list[#list + 1] = g
		end
		g.Tris[#g.Tris + 1] = t
		g.Area += t.Area
		g.Ns += t.N * t.Area
		g.Cs += t.Cen * t.Area
	end
	for _, g in ipairs(list) do
		g.N = g.Ns.Magnitude > 1e-8 and g.Ns.Unit or g.Tris[1].N
		g.Cen = g.Area > 1e-8 and g.Cs / g.Area or g.Tris[1].Cen
		g.NR = rel.Rotation * g.N
		g.RP = rel * (g.Cen - c0)
	end
	return list
end

--- A stone's size for its crystals: the geometric mean of its box's two longest sides (studs).
local function extentOf(tris)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, t in ipairs(tris) do
		for k = 1, 3 do lo, hi = lo:Min(t.P[k]), hi:Max(t.P[k]) end
	end
	local d = { hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z }
	table.sort(d)
	return math.sqrt(math.max(d[2], 0) * math.max(d[3], 0))
end

--- FACETS (Rare): one cell's raw-metal facets -- its F.Count best outer facets (big, and facing up in the rock) copied
--- into one small mesh, each drawn in a little toward its middle (FACET_INSET) and lifted FACET_LIFT off the stone, flat
--- F.Color baked in (Part.Color stays white). { Source, Rel, Size } in the Fissure's convention, or nil. The box gets a
--- speck at each corner (a flat facet's box would be flat).
local function buildFacet(tris, front, c0, rel, F)
	local groups = facetsOf(tris, rel, c0)
	if #groups == 0 then return nil end
	for _, g in ipairs(groups) do g.Score = g.Area * (0.35 + 0.65 * math.clamp(g.NR.Y, 0, 1)) end
	table.sort(groups, function(a, b) return a.Score > b.Score end)
	local col = c3(F.Color, Color3.new(0.66, 0.69, 0.72))
	-- (2026-10-25, checkpoint 5) Facets.Inset: how far each copy is drawn in toward its face's middle -- at the 0.92 default
	-- the facets covered the cells' biggest top faces whole and the rock read as sheet metal; a small patch reads as a glint
	local inset = math.clamp(tonumber(F.Inset) or FACET_INSET, 0.1, 1)
	local list, lo, hi = {}, Vector3.one * 1e9, -Vector3.one * 1e9
	for n = 1, math.min(math.max(1, math.floor(tonumber(F.Count) or 1)), #groups) do
		local g = groups[n]
		local lift = g.N * FACET_LIFT
		for _, t in ipairs(g.Tris) do
			local q = {}
			for k = 1, 3 do
				q[k] = g.Cen + (t.P[k] - g.Cen) * inset + lift
				lo, hi = lo:Min(q[k]), hi:Max(q[k])
			end
			list[#list + 1] = { q[1], q[2], q[3], g.N }
		end
	end
	if #list == 0 then return nil end
	lo, hi = lo - Vector3.one * 0.005, hi + Vector3.one * 0.005
	local c, e = (lo + hi) / 2, 1e-3
	acquire()
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okW, errW = pcall(function()
		local W = writer(em, front)
		for _, tr in ipairs(list) do W.Tri(tr[1] - c, tr[2] - c, tr[3] - c, col, col, col, tr[4]) end
		W.Tri(lo - c, lo - c + Vector3.new(e, 0, 0), lo - c + Vector3.new(0, e, 0), col, col, col, Vector3.zAxis)
		W.Tri(hi - c, hi - c - Vector3.new(e, 0, 0), hi - c - Vector3.new(0, e, 0), col, col, col, -Vector3.zAxis)
	end)
	if not okW then
		pcall(function() em:Destroy() end)
		error(errW, 0)
	end
	local mp = makePart(em)
	TerraWrap.ExtraTris = TerraWrap.ExtraTris or { Veins = 0, Facets = 0, Crystals = 0 }
	TerraWrap.ExtraTris.Facets += #list + 2
	return { Source = mp, Rel = rel * CFrame.new(c - c0), Size = mp.Size }
end

--- A turn taking +Y to `n`, then `twist` about it.
local function axisFrame(n, twist)
	local a = tangent(Vector3.xAxis, n) or tangent(Vector3.zAxis, n)
	return CFrame.fromMatrix(Vector3.zero, a, n) * CFrame.Angles(0, twist, 0)
end

--- CRYSTALS (Epic): cluster `v` of the skin's Crystals `C` -- Prisms Sides-sided prisms splayed (up to Splay) about +Y from
--- a root at the origin, each sunk Sink of its own length below y = 0 (the face it bursts from), in hard flat faces: a
--- root band (Base) to just above the face, the body's faces alternating Body / BodyLit, a pyramid tip (Tip). Neon, the
--- colours baked at full glow (its Part.Color, a grey, dims it); no cap (the root is in the stone). Deterministic per v.
--- Returns the template, its box centre in the cluster's frame (the root at the origin) and its triangles.
local function crystalTemplate(C, v, front)
	local rng = Random.new(6007 * v + 13)
	local sides = math.clamp(math.floor(tonumber(C.Sides) or 6), 3, 8)
	local most = math.max(1, math.floor(CRYSTAL_TRIS / (5 * sides)))
	local pr = type(C.Prisms) == "table" and C.Prisms or { 3, 5 }
	local p0 = math.clamp(math.floor(tonumber(pr[1]) or 3), 1, most)
	local n = rng:NextInteger(p0, math.clamp(math.floor(tonumber(pr[2]) or p0), p0, most))
	local Lr = type(C.Length) == "table" and C.Length or { 0.35, 0.8 }
	local Rr = type(C.Radius) == "table" and C.Radius or { 0.06, 0.13 }
	local L0, L1 = tonumber(Lr[1]) or 0.35, tonumber(Lr[2] or Lr[1]) or 0.8
	local R0, R1 = tonumber(Rr[1]) or 0.06, tonumber(Rr[2] or Rr[1]) or 0.13
	L0, L1 = math.min(L0, L1), math.max(L0, L1)
	R0, R1 = math.min(R0, R1), math.max(R0, R1)
	local splay = tonumber(C.Splay) or 0.5
	local sink = math.clamp(tonumber(C.Sink) or 0.3, 0, 0.85)
	local cBase = c3(C.Base, c3(C.Body, WHITE))
	local cBody = c3(C.Body, cBase)
	local cLit = c3(C.BodyLit, cBody)
	local cTip = c3(C.Tip, cLit)
	local list, lo, hi = {}, Vector3.one * 1e9, -Vector3.one * 1e9
	-- a face, its normal turned to `out` (away from its prism's axis)
	local function tri(a, b, c, col, out)
		local nn = (b - a):Cross(c - a)
		if nn.Magnitude < 1e-10 then return end
		nn = nn.Unit
		if nn:Dot(out) < 0 then nn = -nn end
		list[#list + 1] = { a, b, c, col, nn }
		lo, hi = lo:Min(a):Min(b):Min(c), hi:Max(a):Max(b):Max(c)
	end
	local az0 = rng:NextNumber(0, 2 * math.pi)
	for i = 1, n do
		-- the first prism the cluster's spine (the longest, near upright); the rest round it, shorter, leaning out
		local L, r, tilt
		if i == 1 then
			L, r, tilt = L1 * rng:NextNumber(0.88, 1), R1 * rng:NextNumber(0.88, 1), splay * rng:NextNumber(0, 0.2)
		else
			L = L0 + (L1 - L0) * rng:NextNumber(0, 0.75)
			r = R0 + (R1 - R0) * rng:NextNumber(0, 0.85)
			tilt = splay * rng:NextNumber(0.5, 1)
		end
		local az = az0 + (i - 1) * 2 * math.pi / math.max(1, n - 1) + rng:NextNumber(-0.35, 0.35)
		local hd = Vector3.new(math.cos(az), 0, math.sin(az))
		local dir = Vector3.yAxis * math.cos(tilt) + hd * math.sin(tilt)
		local foot = (i == 1) and Vector3.zero or hd * (R1 * rng:NextNumber(0.5, 1.1))
		local u = tangent(Vector3.xAxis, dir) or tangent(Vector3.zAxis, dir)
		local w = dir:Cross(u)
		local tw = rng:NextNumber(0, 2 * math.pi / sides)
		local h0 = -sink * L                                    -- the root, in the stone
		local h1 = math.max(0.1 * L, h0 + 0.06 * L)              -- the root band's top, just out of it
		local h3 = (1 - sink) * L                               -- the apex
		local h2 = math.max(h3 - math.clamp(1.6 * r, 0.14 * L, 0.4 * L), h1 + 0.05 * L)   -- the tip's base
		local function ring(h, rr, j)
			local th = tw + 2 * math.pi * j / sides
			return foot + dir * h + (u * math.cos(th) + w * math.sin(th)) * rr
		end
		local apex = foot + dir * h3
		for j = 0, sides - 1 do
			local th = tw + 2 * math.pi * (j + 0.5) / sides
			local out = u * math.cos(th) + w * math.sin(th)
			local a0, a1 = ring(h0, r * 0.9, j), ring(h0, r * 0.9, j + 1)
			local b0, b1 = ring(h1, r, j), ring(h1, r, j + 1)
			local t0, t1 = ring(h2, r * 0.92, j), ring(h2, r * 0.92, j + 1)
			tri(a0, a1, b1, cBase, out)
			tri(a0, b1, b0, cBase, out)
			local body = (j % 2 == 0) and cBody or cLit
			tri(b0, b1, t1, body, out)
			tri(b0, t1, t0, body, out)
			tri(t0, t1, apex, cTip, out)
		end
	end
	local ctr = (lo + hi) / 2
	acquire()
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okW, errW = pcall(function()
		local W = writer(em, front)
		for _, t in ipairs(list) do W.Tri(t[1] - ctr, t[2] - ctr, t[3] - ctr, t[4], t[4], t[4], t[5]) end
	end)
	if not okW then
		pcall(function() em:Destroy() end)
		error(errW, 0)
	end
	local mp = makePart(em)
	mp.Material = Enum.Material.Neon
	return mp, ctr, #list
end

--- Where a stone's `count` crystal clusters go: its best facets by `score` (one cluster each, round again when it has
--- fewer), a point toward each one's middle, its normal, a random twist, a variant (1..nv) and the scale `k`.
local function crystalSpots(groups, score, count, k, nv, rng)
	local out = {}
	if #groups == 0 or count <= 0 or nv <= 0 then return out end
	for _, g in ipairs(groups) do g.Score = score(g) end
	table.sort(groups, function(a, b) return a.Score > b.Score end)
	for j = 1, count do
		local g = groups[(j - 1) % #groups + 1]
		local t = g.Tris[rng:NextInteger(1, #g.Tris)]
		local u, w = rng:NextNumber(), rng:NextNumber()
		if u + w > 1 then u, w = 1 - u, 1 - w end
		local q = t.P[1] + (t.P[2] - t.P[1]) * u + (t.P[3] - t.P[1]) * w
		out[j] = { V = rng:NextInteger(1, nv), P = g.Cen:Lerp(q, 0.3), N = g.N, Twist = rng:NextNumber(0, 2 * math.pi), K = k }
	end
	return out
end

--- A placed cluster's frame in its stone's part frame (the stone's box centre `c0`, mesh axes): the template's box centre
--- `ctr` (scaled by the spot's K) carried from the spot's root, turned so the cluster's +Y is the face's normal.
local function crystalFrame(spot, c0, ctr)
	return CFrame.new(spot.P - c0) * axisFrame(spot.N, spot.Twist) * CFrame.new(ctr * spot.K)
end

----------------------------------------------------------------------------------------------------
-- the set
----------------------------------------------------------------------------------------------------
-- (2026-10-25, fix pass) the winding a set's crystal clusters were built in (the cells'), for CrystalTemplates' own
-- build when no set exists and for the shock rings; nil until a set is built (a fresh mesh's front: true).
-- (review) taken from ANY set's first cell, not only a Crystals set's: Meteorite (the rings' only wrap) has no
-- Crystals, so its rings were always built on the assumed winding even after its own set had read the real one
local seenFront = nil
local function build(skin, kit, glow)
	local set = { Skin = skin, Glow = glow, Cells = {}, Pebbles = {} }
	-- (2026-10-25) EPIC: a skin's Crystals (nil: none, as before) -- each cell's spots are found with its stone; they are
	-- placed once the shared cluster meshes exist (built after the cells, in the cells' own winding)
	local C = type(skin.Crystals) == "table" and skin.Crystals or nil
	local perCell = C and math.floor(tonumber(C.PerCell) or 0) or 0
	local perPlate = C and math.floor(tonumber(C.PerPlate) or 0) or 0
	if perCell <= 0 and perPlate <= 0 then C = nil end
	local nv = C and math.clamp(math.floor(tonumber(C.Variants) or 3), 1, 6) or 0
	local spots, ctrs, front0 = {}, {}, nil
	parallel(#kit.Cells, function(i)
		local cell = kit.Cells[i]
		local entry = nil
		for _, e in ipairs(cell.Parts) do
			if e.Kind == "Cell" and e.Source then entry = e end
		end
		if entry then
			local mp, off, c0, tris, front = buildStone(entry.Source, entry.Rel, skin, skin.HighlightEdges, nil, i, "Cell")
			if seenFront == nil then seenFront = front end   -- (2026-10-25, fix pass: see seenFront)
			set.Cells[i] = {
				Stone = { Source = mp, Rel = entry.Rel * off, Size = mp.Size },
				Fissure = buildFissures(tris, front, c0, entry.Rel, i, skin, glow),
			}
			-- (2026-10-25) RARE: the cell's raw-metal facets (a skin with Facets only)
			if type(skin.Facets) == "table" then
				set.Cells[i].Facet = buildFacet(tris, front, c0, entry.Rel, skin.Facets)
			end
			-- (2026-10-25) EPIC: where its clusters go -- its most outward large faces, scaled with the cell
			if C then
				if front0 == nil then front0 = front end
				if perCell > 0 then
					local k = (tonumber(C.Size) or 1) * math.clamp(extentOf(tris) / CELL_REF, 0.5, 1.4)
					local function outward(g) return g.Area * math.max(0.05, g.NR:Dot(g.RP.Magnitude > 1e-3 and g.RP.Unit or g.NR)) end
					spots[i] = { Rel = entry.Rel, C0 = c0,
						List = crystalSpots(facetsOf(tris, entry.Rel, c0), outward, perCell, k, nv, Random.new(9157 * i + 41)) }
				end
			end
		end
	end)
	-- (2026-10-25) EPIC: the shared crystal clusters (set.Crystal[v], Neon), then each cell's placed on its spots:
	-- { Source, Rel, Size } -- Rel the template's box centre and turn in the rock, Size its own times the spot's scale
	if C then
		set.Crystal = {}
		set.CrystalCtr = ctrs       -- (2026-10-25, fix pass: each template's box centre from its root, for CrystalTemplates)
		if front0 ~= nil then seenFront = front0 end
		parallel(nv, function(v)
			local mp, ctr, n = crystalTemplate(C, v, front0 ~= false)
			set.Crystal[v], ctrs[v] = mp, ctr
			TerraWrap.ExtraTris = TerraWrap.ExtraTris or { Veins = 0, Facets = 0, Crystals = 0 }
			TerraWrap.ExtraTris.Crystals += n
		end)
		for i, sp in pairs(spots) do
			local list = {}
			for _, p in ipairs(sp.List) do
				local tpl = set.Crystal[p.V]
				list[#list + 1] = { Source = tpl, Rel = sp.Rel * crystalFrame(p, sp.C0, ctrs[p.V]), Size = tpl.Size * p.K }
			end
			set.Cells[i].Crystals = list
		end
	end
	parallel(#kit.Pebbles, function(i)
		local pb = kit.Pebbles[i]
		if pb.Source then
			local mp = buildStone(pb.Source, CFrame.new(), skin, 1, nil, 100 + i, "Pebble")
			set.Pebbles[i] = { Source = mp, Size = mp.Size / math.max(mp.Size.X, mp.Size.Y, mp.Size.Z) }
		end
	end)
	-- BULWARK CHARGE'S ARMOUR AND BEDROCK'S SHELL: the kit's plates and their broken halves, recoloured on the same
	-- mesh (the clone keeps the kit's size and pivot), and on each whole plate one Neon magma seam per stage -- its
	-- pivot set so it lands on the plate wherever the plate is put
	set.Kit, set.PlateCracks = {}, {}
	if C and perPlate > 0 then set.PlateCrystals = {} end   -- (2026-10-25) EPIC: [variant] = its clusters
	local folder = ReplicatedStorage:FindFirstChild("EarthMagicMeshes")
	local jobs = {}
	for v = 1, 4 do
		for _, suffix in ipairs({ "", "_A", "_B" }) do jobs[#jobs + 1] = { v, suffix } end
	end
	parallel(#jobs, function(j)
		local v, suffix = jobs[j][1], jobs[j][2]
		do
			local name = ("TR_Plate_%02d%s"):format(v, suffix)
			local src = folder and folder:FindFirstChild(name, true)
			if src and src:IsA("MeshPart") then
				local mp, _, c0, tris, front = buildStone(src, src.PivotOffset:Inverse(), skin, suffix == "" and 2 or 1, true,
					200 + j, "Plate")
				local tpl = src:Clone()
				tpl:ApplyMesh(mp)
				tpl.Size = src.Size
				set.Kit[name] = tpl
				if suffix == "" then
					local f = buildFissures(tris, front, c0, CFrame.new(), 100 + v, skin, glow)
					if f then
						for _, st in ipairs({ "Low", "Mid", "Max" }) do
							f[st].PivotOffset = CFrame.new(c0 - f.C) * src.PivotOffset
						end
						set.PlateCracks[v] = f
					end
					-- (2026-10-25) EPIC: the plate's crystal clusters on its outer face (facing the pivot's -Z, as Outer does),
					-- each pivoted like the seam above: a clone of set.Crystal[n] with this PivotOffset, PivotTo'd to the
					-- plate's pivot, lands where it was placed on the plate. Size = the template's times the spot's scale.
					if set.PlateCrystals and set.Crystal then
						local k = (tonumber(C.Size) or 1) * math.clamp(extentOf(tris) / CELL_REF, 0.45, 1.4)
						local function facing(g) return g.Area * math.max(0.05, -g.NR.Z) end
						local list = {}
						for _, p in ipairs(crystalSpots(facetsOf(tris, src.PivotOffset:Inverse(), c0), facing, perPlate, k, nv,
							Random.new(4447 * v + 3))) do
							local tpl = set.Crystal[p.V]
							list[#list + 1] = { Source = tpl, Size = tpl.Size * p.K,
								PivotOffset = crystalFrame(p, c0, ctrs[p.V]):Inverse() * src.PivotOffset }
						end
						set.PlateCrystals[v] = list
					end
				end
			end
		end
	end)
	return set
end

--- The built wrap `id` for Boulder Shot's kit `kit` at CrackGlow `glow` (the live attribute when nil), or nil -- while it
--- is being built (the cast draws Default meanwhile), for Default, or when the mesh APIs are off.
function TerraWrap.Get(id, kit, glow, own)
	local skin = TerraWrap.Skin("BoulderShot", id)
	if not (skin and kit and kit.Mesh) then return nil end
	local live = glow == nil      -- (a cast's ask; a review sheet passes its own glow)
	glow = glow or TerraWrap.Glow(skin, own)
	local k = skin.Id .. "@" .. math.floor(glow * 20 + 0.5)
	local got = built[k]
	if type(got) == "table" then got.UsedAt = os.clock() return got end   -- (UsedAt: MakeRoom leaves a set in use alone)
	if got ~= nil then return nil end
	-- (2026-10-29) the same wrap at the other CrackGlow (the caster's own view draws 0.8 of it) is used, or waited for,
	-- rather than built twice: a set is ~12 of the ~14 EditableMesh units a client has free, so a Terra player wearing
	-- the wrap another Terra player wore drew that player's as Default (the two glows are a brightness step apart)
	for k2, v in pairs(live and built or {}) do
		if k2 ~= "Fails" and type(v) == "table" and v.Skin and v.Skin.Id == skin.Id then
			v.UsedAt = os.clock()
			return v
		end
		if v == "building" and string.sub(k2, 1, #skin.Id + 1) == skin.Id .. "@" then return nil end
	end
	-- worn: a player who is Terra right now has it on (else a prewarm, which never asks a skin to make way)
	local worn, wornIds = false, {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("Element") == "Terra" then
			local id = Catalog.Chosen(pl, "BoulderShot")   -- (2026-10-25: ElementWrap_Terra, was Skin_*)
			if type(id) == "string" then wornIds[id] = true end
			if id == skin.Id then worn = true end
		end
	end
	if not worn and MeshBudget.Busy() then return nil end -- (a worn skin's kit is building: the next ask starts this one)
	-- (2026-10-25, the ladder) a worn wrap's build first lets go of every set nobody wears now (a wrap switched away from):
	-- one set is ~12 of the ~14 free units, so the old one left standing kept the new one Default for the session
	if worn then wornNow = wornIds dropUnworn(wornIds) end
	built[k] = "building"
	task.spawn(function()
		if worn then essential += 1 MeshBudget.Essential("TerraWrap:" .. k, true) end
		local sink = {}
		sinkOf[coroutine.running()] = sink
		local ok, set = pcall(build, skin, kit, glow)
		sinkOf[coroutine.running()] = nil
		if worn then essential -= 1 MeshBudget.Essential("TerraWrap:" .. k, false) end
		if ok then
			set.Keep = sink
		else
			for _, m in ipairs(sink) do pcall(function() m:Destroy() end) end   -- (a failed build's meshes go with it)
		end
		built[k] = ok and set or false
		-- (2026-10-25, fix pass) MYTHIC: a wrap with a Shock gets its ring meshes now, so its first impact rings
		if ok and type(skin.Shock) == "table" and ringKick then pcall(ringKick, skin) end
		if not ok and string.sub(tostring(set), 1, 7) == "DENIED " then
			-- 2026-10-23: a refused mesh is final for the session (built[k] stays false: Default), one warning naming them
			local ids = {}
			for a in pairs(denied) do ids[#ids + 1] = string.match(a, "%d+") or a end
			table.sort(ids)
			if deniedSaid == 0 or #ids > deniedSaid then
				deniedSaid = math.max(#ids, 1)
				warn("[TerraWrap] " .. skin.Id .. ": no permission to copy kit mesh(es) "
					.. (#ids > 0 and table.concat(ids, ", ") or tostring(set))
					.. " -- drawing Default; re-upload them under the place owner's account")
			end
		elseif not ok then
			warn("[TerraWrap] " .. skin.Id .. ": " .. tostring(set))
			-- a failure is not for the session: the next ask after a pause builds it again. (2026-10-19, audit P5B-20)
			-- the pause doubles with each failure of the same build (5, 10, 20 ... 160 s): a budget that stays full no
			-- longer has a full rebuild started every 5 s for the whole session
			local n = (built.Fails[k] or 0) + 1
			built.Fails[k] = n
			task.delay(math.min(5 * 2 ^ (n - 1), 160), function() if built[k] == false then built[k] = nil end end)
		else
			built.Fails[k] = nil
		end
	end)
	return nil
end

--- MeshBudget's Optional (2026-10-19): every built set goes while no Terra player has a Terra wrap on (a wrap draws only
--- on a Terra cast; a Cryo player's leftover Skin_ pick does not count) and none was drawn in the last 6 s. The caster's own prewarm
--- (TerraFX.WatchWraps builds their worn Terra wrap the moment they are Terra -- 2026-10-25: it used to build every Terra
--- wrap) holds most of a client's EditableMesh budget for a wrap that may not be drawn for a while, and a worn skin's kit
--- (a Frost Dragon) could then never build. A set in use, or a build still running, is never freed; the next ask (a
--- pick, the next prewarm) builds it again.
local function dropAll(t, seen)
	if seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		-- (2026-10-25, fix pass: an Instance in `seen` -- a crystal template adoptCrystals kept -- is left standing)
		if typeof(v) == "Instance" then
			if not seen[v] then pcall(function() v:Destroy() end) end
		elseif type(v) == "table" and k ~= "Skin" then dropAll(v, seen) end
	end
end
-- (2026-10-25, the ladder) every built set no Terra player wears (`wornIds`) and none drew in the last 6 s goes, with its
-- own fixed meshes (set.Keep); a rock thrown just before a switch may still be flying, hence the 6 s
dropUnworn = function(wornIds)
	for k, set in pairs(built) do
		if k ~= "Fails" and type(set) == "table" and not wornIds[set.Skin.Id] and os.clock() - (set.UsedAt or 0) >= 6 then
			built[k] = nil
			dropAll(set, adoptCrystals(set))   -- (2026-10-25, fix pass: {} unless its crystals were ever handed out)
			for _, m in ipairs(set.Keep or {}) do pcall(function() m:Destroy() end) end
		end
	end
end
function TerraWrap.MakeRoom()
	for k, v in pairs(built) do
		if k ~= "Fails" and v == "building" then return end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("Element") == "Terra" then
			local id = Catalog.Chosen(pl, "BoulderShot")              -- (2026-10-25: ElementWrap_Terra, was Skin_*)
			if type(id) == "string" and id ~= "Default" then return end
		end
	end
	for k, set in pairs(built) do                          -- (a rock thrown just before a switch may still be flying)
		if k ~= "Fails" and type(set) == "table" and os.clock() - (set.UsedAt or 0) < 6 then return end
	end
	local freed = false
	for k, set in pairs(built) do
		if k ~= "Fails" and type(set) == "table" then
			dropAll(set, adoptCrystals(set))   -- (2026-10-25, fix pass: {} unless its crystals were ever handed out)
			for _, m in ipairs(set.Keep or {}) do pcall(function() m:Destroy() end) end   -- (2026-10-25: its own meshes)
			built[k] = nil
			freed = true
		end
	end
	if freed then
		for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
		table.clear(keep)
	end
end
MeshBudget.Optional(TerraWrap.MakeRoom)

--- The particles a wrap recolours (`extra` for VFXLibrary's Boulder emitters), by kind; nil keeps Default's.
function TerraWrap.Particles(set, kind)
	local s = set and set.Skin
	if not s then return nil end
	if kind == "Spark" or kind == "Ember" then return { Color = ColorSequence.new(s.Ember, s.Crack.Outer) } end
	if kind == "KickGrit" or kind == "GatherGrit" then return { Color = ColorSequence.new(s.Grit[1], s.Grit[2]) } end
	if kind == "Flash" then return { Color = ColorSequence.new(s.HitFlash) } end
	-- Terra's toon debris (Bulwark Charge's knockdown, Bedrock's clink): obsidian chunks, the fine grit and the chips as
	-- embers cooling to obsidian
	if kind == "Chunks" then return { Color = ColorSequence.new(s.Grit[1], s.Grit[2]) } end
	if kind == "Grit" or kind == "Chips" then
		return { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, s.Ember), ColorSequenceKeypoint.new(0.4, s.Crack.Outer),
			ColorSequenceKeypoint.new(1, s.Grit[2]) }) }
	end
	-- (2026-10-25) a wrap's Dust (Uncommon up; Obsidian Magma has none, so its dust stays Terra's tan): Default's dust
	-- ROLES recoloured, each kind keeping its Default sequence's shape (VFXLibrary BOULDER_KIT): BOULDER_DUST -> Light,
	-- BOULDER_DUST_DARK -> Dark. CloudDark = TerraFX's hard-coded dark impact cloud (the dark role alone). A role the
	-- skin leaves out keeps Default's colour.
	local D = s.Dust
	if type(D) == "table" then
		local light = c3(D.Light, DUST_LIGHT)
		local dark = c3(D.Dark, DUST_DARK)
		if kind == "Kick" or kind == "Merge" or kind == "Ring" or kind == "Settle" or kind == "Landing" or kind == "Cloud" then
			return { Color = ColorSequence.new(light) }
		end
		if kind == "Gather" then return { Color = ColorSequence.new(dark, light) } end
		if kind == "Trail" then return { Color = ColorSequence.new(light, dark) } end
		if kind == "CloudDark" then return { Color = ColorSequence.new(dark) } end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- (2026-10-25) THE LIVE HELPERS: the settings, the breath and the flow, the added particle layers. TerraFX (Boulder
-- Shot, the plates, Aftershock), ChargedRock and the Wall / Tomb kits call these only for a skin with the field they
-- serve, so Default and Obsidian Magma never reach them.
----------------------------------------------------------------------------------------------------
local settingsMod = nil   -- SpellshotSettings, once it has been required
local function settings()
	if settingsMod then return settingsMod end
	local ok, m = pcall(function()
		local sp = ReplicatedStorage:FindFirstChild("Spellshot")
		local s = sp and sp:FindFirstChild("SpellshotSettings")
		return s and require(s)
	end)
	if ok and type(m) == "table" then settingsMod = m end
	return settingsMod
end

--- The scalar for a wrap's ADDED layers: the game's Graphics Quality (SpellshotSettings.EffectDensity: LOW 0.45, MEDIUM
--- 0.75, HIGH 1, ULTRA 1.15; 1 when it cannot be read), halved for `thin` (somebody else's effect, an enemy's) under
--- Reduce Enemy VFX (the plain ThinEnemyVFX field, never Get()), and 0 below `minQ` (CryoWrap's solidOn: 0.75 = MEDIUM up).
function TerraWrap.Density(thin, minQ)
	local S = settings()
	local d = (S and type(S.EffectDensity) == "number") and S.EffectDensity or 1
	if type(minQ) == "number" and d < minQ then return 0 end
	if thin and S and S.ThinEnemyVFX == true then d *= 0.5 end
	return d
end

--- Reduce Flashing (Settings "ReduceFlashing"), read at most once a second; in Studio the workspace attribute
--- StudioReduceFlashing = true turns it on too (to check the held look without the menu).
local calmAt, calmOn = -10, false
function TerraWrap.Calm()
	local now = os.clock()
	if now - calmAt >= 1 then
		calmAt = now
		local S = settings()
		local ok, on = pcall(function() return S and S.Get and S.Get("ReduceFlashing") end)
		calmOn = ok and on == true
		if not calmOn and RunService:IsStudio() then calmOn = workspace:GetAttribute("StudioReduceFlashing") == true end
	end
	return calmOn
end

--- The wrap's breath now: 1 - Pulse.Amp x (1 - sin(2 pi t / Pulse.Period)) on os.clock(), so 1 - 2 Amp .. 1; 1 with no
--- Pulse or under Reduce Flashing. Amp is the INPUT (a Neon body swings ~2.6x that on screen).
--- (2026-10-25, integration) the breath runs DOWN from the baked colour, never up: its peak is the stage's own look. A
--- 1 + Amp x sin breath was cut in half -- the baked Neon meshes (fissures, plate seams, crystals) are multiplied by a
--- Part.Color that cannot pass white, so the bright half clamped away and only the dip showed. Same 2 x Amp swing.
function TerraWrap.PulseK(skin)
	local P = skin and skin.Pulse
	if type(P) ~= "table" or TerraWrap.Calm() then return 1 end
	local period = tonumber(P.Period) or 2.25
	if period <= 0 then return 1 end
	return 1 - (tonumber(P.Amp) or 0) * (1 - math.sin(2 * math.pi * os.clock() / period))
end

--- The wrap's Flow at `pos`: ONE field (neighbours correlate) drifting at Speed, Flow.A:Lerp(Flow.B, u) with u in Steps
--- (24: ~4% a step, under the 6% frame rule); held still (phase = Hold) under Reduce Flashing. WHITE with no Flow.
function TerraWrap.FlowMul(skin, pos)
	local F = skin and skin.Flow
	if type(F) ~= "table" or typeof(F.A) ~= "Color3" or typeof(F.B) ~= "Color3" then return WHITE end
	if typeof(pos) ~= "Vector3" then pos = Vector3.zero end
	local ph = TerraWrap.Calm() and (tonumber(F.Hold) or 0) or os.clock() * (tonumber(F.Speed) or 0.6)
	local u = 0.5 + 0.5 * math.sin((pos.X * 0.83 + pos.Z * 0.57 + pos.Y * 0.35) * (tonumber(F.Scale) or 0.12) - ph)
	local n = math.max(1, math.floor(tonumber(F.Steps) or 24))
	u = math.floor(u * n + 0.5) / n
	return F.A:Lerp(F.B, u)
end

local function q255(x) return math.floor(math.clamp(x, 0, 1) * 255 + 0.5) / 255 end
--- `base` (default WHITE) x FlowMul(pos) x PulseK, each channel clamped to 1 and quantised to 1/255 -- so a caller can
--- compare it with what it wrote last and write only on a change.
function TerraWrap.GlowMul(skin, pos, base)
	base = typeof(base) == "Color3" and base or WHITE
	local m, k = TerraWrap.FlowMul(skin, pos), TerraWrap.PulseK(skin)
	return Color3.new(q255(base.R * m.R * k), q255(base.G * m.G * k), q255(base.B * m.B * k))
end

--- Whether the wrap breathes or flows at all.
function TerraWrap.HasGlowFx(skin)
	return type(skin) == "table" and (skin.Pulse ~= nil or skin.Flow ~= nil)
end

-- THE ADDED LAYERS (skin.Layers: Rare up): { Name, Kind = "Fleck" | "Mote" | "Twinkle", Texture = "Sparkle" | "Grit",
-- Color (over life), Size, Life, Speed, Drag, Accel, LightEmission, LightInfluence, Shape = "Sphere", Surface, Share }.
-- Built-in textures only (an EditableImage TextureContent renders nothing): the crisp sparkle, or Boulder Shot's grit chip.
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GRIT = "rbxassetid://82803520621527"     -- VFXLibrary's BOULDER_GRIT (TR_M1_Grit): KickGrit / GatherGrit's chip
local NK = NumberSequenceKeypoint.new
-- a twinkle's flicker (PyroDraw's Void Flame), a mote's soft in and out, a fleck's hard chip
local TWINKLE_T = NumberSequence.new({ NK(0, 1), NK(0.12, 0), NK(0.3, 0.75), NK(0.45, 0.05), NK(0.65, 0.8), NK(0.8, 0.2), NK(1, 1) })
local MOTE_T = NumberSequence.new({ NK(0, 0.6), NK(0.15, 0.05), NK(0.7, 0.15), NK(1, 1) })
local FLECK_T = NumberSequence.new({ NK(0, 0), NK(0.8, 0), NK(1, 1) })

local function layerColors(cols)
	if typeof(cols) == "Color3" then return ColorSequence.new(cols) end
	local list = {}
	if type(cols) == "table" then
		for _, c in ipairs(cols) do
			if typeof(c) == "Color3" then list[#list + 1] = c end
		end
	end
	if #list == 0 then return ColorSequence.new(WHITE) end
	if #list == 1 then return ColorSequence.new(list[1]) end
	local kp = {}
	for i, c in ipairs(list) do kp[i] = ColorSequenceKeypoint.new((i - 1) / (#list - 1), c) end
	return ColorSequence.new(kp)
end
local function layerRange(r, a, b)
	if type(r) == "number" then return NumberRange.new(r) end
	if type(r) == "table" then a, b = tonumber(r[1]) or a, tonumber(r[2] or r[1]) or b end
	return NumberRange.new(math.min(a, b), math.max(a, b))
end
local function share(L, site)
	return type(L) == "table" and type(L.Share) == "table" and tonumber(L.Share[site]) or 0
end

--- A continuous emitter for layer `L` on `parent` (Rate 0: LayerRates rates it), or nil when the layer is off -- a
--- Twinkle under Reduce Flashing (nothing spawns), or below its own MinQ if it has one. Attribute WrapLayer = L.Name, so
--- a Default-rate sum can leave it out.
function TerraWrap.LayerEmitter(parent, L, thin)
	if type(L) ~= "table" then return nil end
	local kind = L.Kind or "Mote"
	if kind == "Twinkle" and TerraWrap.Calm() then return nil end
	if type(L.MinQ) == "number" and TerraWrap.Density(thin, L.MinQ) <= 0 then return nil end
	local fleck = kind == "Fleck"
	local e = Instance.new("ParticleEmitter")
	e.Name = "WrapLayer_" .. tostring(L.Name)
	e.Texture = (L.Texture == "Grit" and GRIT) or (L.Texture == "Sparkle" and SPARKLE) or (fleck and GRIT or SPARKLE)
	e.Color = layerColors(L.Color)
	e.LightEmission = tonumber(L.LightEmission) or (fleck and 0 or 1)
	e.LightInfluence = tonumber(L.LightInfluence) or (fleck and 1 or 0)
	local sz = type(L.Size) == "table" and L.Size or { 0.2, 0.05 }
	e.Size = NumberSequence.new(tonumber(sz[1]) or 0.2, tonumber(sz[2] or sz[1]) or 0.05)
	e.Transparency = (kind == "Twinkle" and TWINKLE_T) or (fleck and FLECK_T) or MOTE_T
	e.Lifetime = layerRange(L.Life, 0.6, 1.2)
	e.Speed = layerRange(L.Speed, 0.5, 2)
	e.Drag = tonumber(L.Drag) or 2
	e.Acceleration = typeof(L.Accel) == "Vector3" and L.Accel or Vector3.zero
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = fleck and Vector2.new(70, 70) or Vector2.new(180, 180)   -- (flecks thrown out along the host's up)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = fleck and NumberRange.new(-400, 400) or NumberRange.new(-60, 60)
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	if L.Shape == "Sphere" then
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = L.Surface and Enum.ParticleEmitterShapeStyle.Surface or Enum.ParticleEmitterShapeStyle.Volume
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	end
	e.Rate = 0
	e:SetAttribute("WrapLayer", tostring(L.Name))
	e.Parent = parent
	return e
end

--- One LayerEmitter per layer of the skin on `parent`: { [L.Name] = emitter } (an off layer left out), or nil when the
--- skin has no Layers.
function TerraWrap.LayerSet(skin, parent, thin)
	local Ls = skin and skin.Layers
	if type(Ls) ~= "table" then return nil end
	local out = {}
	for _, L in ipairs(Ls) do
		if type(L) == "table" and L.Name ~= nil then
			local e = TerraWrap.LayerEmitter(parent, L, thin)
			if e then out[L.Name] = e end
		end
	end
	return out
end

--- Rates a LayerSet at `site` ("Hold", "Flight", "Aftershock" ...): each emitter's Rate = defaultRate / (scaled or 1) x
--- its layer's Share[site] x Density(thin) -- `defaultRate` the Default effect's own rate there, `scaled` the density it
--- already carries (divided out: density is applied once). 0 for a layer with no share there, and for a Twinkle under
--- Reduce Flashing. Written only on a change.
local rateOf = setmetatable({}, { __mode = "k" })
function TerraWrap.LayerRates(skin, site, set, defaultRate, scaled, thin)
	if not (type(skin) == "table" and type(skin.Layers) == "table" and type(set) == "table") then return end
	local base = (tonumber(defaultRate) or 0) / ((type(scaled) == "number" and scaled > 0) and scaled or 1)
	local d, calm = TerraWrap.Density(thin), nil
	for _, L in ipairs(skin.Layers) do
		local e = type(L) == "table" and L.Name ~= nil and set[L.Name] or nil
		if e then
			local sh = share(L, site)
			if sh > 0 and L.Kind == "Twinkle" then
				if calm == nil then calm = TerraWrap.Calm() end
				if calm then sh = 0 end
			end
			local r = math.max(0, base * sh * d)
			if rateOf[e] ~= r then
				rateOf[e] = r
				e.Rate = r
			end
		end
	end
end

--- One-shot: for each layer with a Share at `site` ("Impact", "Plate", "Wall", "Tomb", "Aftershock" ...), emits
--- defaultCount / (scaled or 1) x share x Density(thin) -- rounded stochastically, so a small share of a small burst still
--- averages right -- from a pooled, anchored, invisible host moved to `at` (a Vector3, or a CFrame whose UpVector the
--- layer is thrown along). One host and emitter per skin and layer, in workspace.TerraWrapFX; nothing for a Twinkle under
--- Reduce Flashing. Returns how many it emitted.
local pool, poolFolder = {}, nil   -- ["<skin.Id>/<layer>"] = its emitter
local function layerFolder()
	if poolFolder and poolFolder.Parent then return poolFolder end
	poolFolder = workspace:FindFirstChild("TerraWrapFX")
	if not poolFolder then
		poolFolder = Instance.new("Folder")
		poolFolder.Name = "TerraWrapFX"
		poolFolder.Archivable = false
		poolFolder.Parent = workspace
	end
	return poolFolder
end
function TerraWrap.LayerBurst(skin, site, defaultCount, scaled, at, thin)
	if not (type(skin) == "table" and type(skin.Layers) == "table") then return 0 end
	local count = (tonumber(defaultCount) or 0) / ((type(scaled) == "number" and scaled > 0) and scaled or 1)
	local cf = (typeof(at) == "CFrame" and at) or (typeof(at) == "Vector3" and CFrame.new(at)) or nil
	if count <= 0 or not cf then return 0 end
	local d, calm, total = TerraWrap.Density(thin), nil, 0
	for _, L in ipairs(skin.Layers) do
		local sh = share(L, site)
		if sh > 0 and L.Kind == "Twinkle" then
			if calm == nil then calm = TerraWrap.Calm() end
			if calm then sh = 0 end
		end
		-- (a layer below its own MinQ makes no emitter: skipped here, not a host made and thrown away every burst)
		if sh > 0 and type(L.MinQ) == "number" and TerraWrap.Density(thin, L.MinQ) <= 0 then sh = 0 end
		local x = count * sh * d
		local n = math.floor(x)
		if math.random() < x - n then n += 1 end
		if n > 0 and L.Name ~= nil then
			local k = tostring(skin.Id) .. "/" .. tostring(L.Name)
			local e = pool[k]
			if not (e and e.Parent and e.Parent.Parent) then
				local h = Instance.new("Part")
				h.Name = "TerraWrapLayer_" .. k
				h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.CastShadow = true, false, false, false, false
				h.Transparency = 1
				h.Size = Vector3.one * (L.Shape == "Sphere" and 1.6 or 0.3)
				h.CFrame = cf
				h.Parent = layerFolder()
				e = TerraWrap.LayerEmitter(h, L, thin)
				if not e then h:Destroy() end
				pool[k] = e
			end
			if e then
				e.Parent.CFrame = cf
				e:Emit(n)
				total += n
			end
		end
	end
	return total
end

----------------------------------------------------------------------------------------------------
-- (2026-10-25, fix pass) THE BAKED KITS' TIER LAYERS: the crystal templates the Wall / Tomb / Aftershock pieces grow
-- (CrystalsBaked, Epic) and the Boulder impact's shards (Shatter, Epic); the shock rings (Shock, Mythic) and the star
-- drift (Drift, Mythic). Each is reached only for a skin with its field -- Default and Obsidian Magma carry none. The
-- meshes here are MeshBudget Optional: none is started while a worn skin's kit builds, and the idle ones are let go
-- under pressure (freeExtras).
-- (review) ...except a crystal template once handed out: ChargedRock pools a Wall / Tomb piece WITH its crystal clone
-- for the session (crystalFor reuses it, never asking again), and a clone draws nothing once its template's fixed mesh
-- is destroyed -- so a handed-out template (and its mesh) is kept for the session, as ChargedRock keeps a grey copy it
-- lent out (3 clusters of <= 160 triangles a wrap). Only a cached build nobody was handed is let go.
----------------------------------------------------------------------------------------------------
local CRYSTAL_HOLD = 45   -- s a cached crystal build nobody was handed is kept after it is made / last asked for
local crystalCache, crystalFails = {}, {}   -- [skin.Id] = { Templates, Ctr, Keep, UsedAt, Handed } | "building" | false
local orphans = {}        -- a dropped set's handed-out templates, kept for the session: { Templates, Keep, UsedAt }

--- The attribute CrystalRoot on each template (copied to every clone): the cluster's root -- the point it bursts from,
--- its +Y the way it grows -- in the template's own frame, at the template's size (a clone scaled by k: times k).
local function markRoots(list, ctrs)
	for v, tpl in pairs(list) do
		local c = type(ctrs) == "table" and ctrs[v] or nil
		if typeof(c) == "Vector3" and tpl:GetAttribute("CrystalRoot") == nil then
			pcall(tpl.SetAttribute, tpl, "CrystalRoot", -c)
		end
	end
end

local function dropEntry(e)
	for _, tpl in pairs(e.Templates or {}) do pcall(function() tpl:Destroy() end) end
	for _, m in ipairs(e.Keep or {}) do pcall(function() m:Destroy() end) end
end

--- The wrap's shared crystal cluster templates (Neon, the faces' colours baked at full glow: a clone's Part.Color, a
--- grey, is its brightness), or nil -- while they build (the first ask starts it: the piece goes without), or when the
--- skin has no Crystals. A built Boulder Shot set of the wrap hands out its own set.Crystal; else the same builder makes
--- the Variants clusters once per skin Id (Optional: not while a worn skin's kit builds). Clone the entries, never
--- change them; each carries the attribute CrystalRoot (markRoots). Once handed out they stay for the session (above).
function TerraWrap.CrystalTemplates(skin)
	local C = type(skin) == "table" and skin.Crystals or nil
	if type(C) ~= "table" then return nil end
	local id = skin.Id or tostring(skin)
	local now = os.clock()
	local got = crystalCache[id]
	if type(got) == "table" then
		got.UsedAt, got.Handed = now, true
		return got.Templates
	end
	-- a built set of this wrap (the one drawn last): its own clusters, so the boulder and the kits match exactly
	local best = nil
	for k, set in pairs(built) do
		if k ~= "Fails" and type(set) == "table" and set.Skin and set.Skin.Id == skin.Id and type(set.Crystal) == "table"
			and #set.Crystal > 0 and (best == nil or (set.UsedAt or 0) > (best.UsedAt or 0)) then
			best = set
		end
	end
	if best then
		best.CrystalAskedAt = now   -- (its templates now outlive the set: adoptCrystals)
		markRoots(best.Crystal, best.CrystalCtr)
		return best.Crystal
	end
	if got ~= nil then return nil end            -- building, or failed and pausing
	if MeshBudget.Busy() then return nil end     -- (a worn skin's kit is building: the next ask starts this)
	crystalCache[id] = "building"
	task.spawn(function()
		local sink, list, ctrs = {}, {}, {}
		sinkOf[coroutine.running()] = sink
		local nv = math.clamp(math.floor(tonumber(C.Variants) or 3), 1, 6)
		local ok, err = pcall(parallel, nv, function(v)
			local mp, ctr = crystalTemplate(C, v, seenFront ~= false)
			list[v], ctrs[v] = mp, ctr
		end)
		sinkOf[coroutine.running()] = nil
		if ok and #list == nv then
			markRoots(list, ctrs)
			crystalCache[id] = { Templates = list, Ctr = ctrs, Keep = sink, UsedAt = os.clock() }
			crystalFails[id] = nil
		else
			dropEntry({ Templates = list, Keep = sink })   -- (a failed build's meshes go with it)
			crystalCache[id] = false
			warn("[TerraWrap] " .. tostring(id) .. " crystal templates: " .. tostring(err))
			local n = (crystalFails[id] or 0) + 1        -- (the pause doubles, as TerraWrap.Get's: 5, 10 ... 160 s)
			crystalFails[id] = n
			task.delay(math.min(5 * 2 ^ (n - 1), 160), function() if crystalCache[id] == false then crystalCache[id] = nil end end)
		end
	end)
	return nil
end

--- A set being dropped whose crystal templates were ever handed out (CrystalTemplates) keeps them (and their fixed
--- meshes, taken out of set.Keep): a standing Wall's clusters, and every pooled piece's, are clones of them. They become
--- the wrap's cached templates (or, with one already cached or building, an orphan kept for the session). Returns the
--- `seen` table for dropAll, the kept templates marked in it -- {} for any other set, so it drops exactly as before.
adoptCrystals = function(set)
	local seen = {}
	local list = type(set) == "table" and set.Crystal or nil
	if type(list) ~= "table" or type(set.CrystalAskedAt) ~= "number" then
		return seen
	end
	local mine, isMine = {}, {}
	for _, tpl in pairs(list) do
		seen[tpl] = true
		local f = fixedOf[tpl]
		if f then
			mine[#mine + 1] = f
			isMine[f] = true
		end
	end
	if type(set.Keep) == "table" then
		local rest = {}
		for _, m in ipairs(set.Keep) do
			if not isMine[m] then rest[#rest + 1] = m end
		end
		set.Keep = rest
	end
	local entry = { Templates = list, Ctr = set.CrystalCtr, Keep = mine, UsedAt = set.CrystalAskedAt, Handed = true }
	local id = set.Skin and set.Skin.Id
	local cur = id ~= nil and crystalCache[id] or nil
	if id ~= nil and (cur == nil or cur == false) then
		crystalCache[id] = entry
	else
		orphans[#orphans + 1] = entry
	end
	return seen
end

-- THE SHOCK RING (Shock, Mythic): a flat annulus mesh (RING_SEG segments, 2 triangles each), outer radius 1 stud, Neon
-- in white vertex colour (Part.Color is the ring's colour), its band an inner-radius fraction: a clone scaled up in X / Z
-- keeps that fraction, so the ring is built per fraction step (RING_Q steps of the radius), one per site radius the
-- skin's Shock.Radius names, and a site's ring is exactly Shock.Width wide at its full radius. Shared by every wrap and
-- cast, cloned per ring, the clones pooled; never more than RING_MAX alive on a client (a fifth retires the oldest).
local RING_SEG, RING_Q, RING_MAX = 32, 25, 4
local RING_LIFT = 0.06    -- studs over the ground point: off the floor and its scuff decals
local rings = { Tpl = {}, Keep = {}, Idle = {}, Alive = {}, Fails = {}, UsedAt = -math.huge }
-- Tpl[q] = the template for fraction q / RING_Q | "building" | false (failed, pausing); Idle[q] = pooled clones
local fxConn, fxLast = nil, nil   -- the one Heartbeat stepping the rings and the shards, while any are alive
local wakeFx                      -- (below)

local function ringWidth(S) return math.max(0.05, tonumber(S.Width) or 0.6) end
local function ringStep(r, w) return math.clamp(math.floor((1 - w / r) * RING_Q + 0.5), 13, RING_Q - 1) end

--- One ring template: the annulus between fr and 1 on y = +0.02, facing up, and a speck under its band at y = -0.02 so
--- the box has height (a flat box does not scale). The box is 2 x 0.04 x 2, centred: a clone's Size.X / 2 is its radius.
local function ringMesh(fr)
	acquire()
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okW, errW = pcall(function()
		local W = writer(em, seenFront ~= false)
		for j = 0, RING_SEG - 1 do
			local a0, a1 = 2 * math.pi * j / RING_SEG, 2 * math.pi * (j + 1) / RING_SEG
			local d0, d1 = Vector3.new(math.cos(a0), 0, math.sin(a0)), Vector3.new(math.cos(a1), 0, math.sin(a1))
			local y = Vector3.new(0, 0.02, 0)
			W.Quad(d0 * fr + y, d0 + y, d1 * fr + y, d1 + y, WHITE, WHITE, Vector3.yAxis)
		end
		local s, e = Vector3.new((1 + fr) / 2, -0.02, 0), 1e-3
		W.Tri(s, s + Vector3.new(e, 0, 0), s + Vector3.new(0, 0, e), WHITE, WHITE, WHITE, -Vector3.yAxis)
	end)
	if not okW then
		pcall(function() em:Destroy() end)
		error(errW, 0)
	end
	local mp = makePart(em)
	mp.Material = Enum.Material.Neon
	mp.CastShadow = false
	mp.Name = "TerraShockRing"
	return mp
end

--- Builds (in the background) the ring templates the skin's Shock needs -- one per site radius in Shock.Radius, plus
--- step `extra` -- that are not built or building. Optional: nothing starts while a worn skin's kit builds.
ringKick = function(skin, extra)
	local S = type(skin) == "table" and skin.Shock or nil
	if type(S) ~= "table" or MeshBudget.Busy() then return end
	local w, want, list = ringWidth(S), {}, {}
	local function add(q)
		if type(q) == "number" and rings.Tpl[q] == nil and not want[q] then
			want[q] = true
			list[#list + 1] = q
		end
	end
	if type(S.Radius) == "table" then
		for _, r in pairs(S.Radius) do
			r = tonumber(r)
			if r and r > 0.2 then add(ringStep(r, w)) end
		end
	end
	add(extra)
	if #list == 0 then return end
	for _, q in ipairs(list) do rings.Tpl[q] = "building" end
	task.spawn(function()
		local sink, made = {}, {}
		sinkOf[coroutine.running()] = sink
		local ok, err = pcall(parallel, #list, function(i) made[i] = ringMesh(list[i] / RING_Q) end)
		sinkOf[coroutine.running()] = nil
		for _, m in ipairs(sink) do rings.Keep[#rings.Keep + 1] = m end
		for i, q in ipairs(list) do
			if made[i] then
				rings.Tpl[q] = made[i]
				rings.Fails[q] = nil
			else
				rings.Tpl[q] = false
				local n = (rings.Fails[q] or 0) + 1            -- (the pause doubles: 5, 10 ... 160 s)
				rings.Fails[q] = n
				task.delay(math.min(5 * 2 ^ (n - 1), 160), function() if rings.Tpl[q] == false then rings.Tpl[q] = nil end end)
			end
		end
		if not ok then warn("[TerraWrap] shock ring: " .. tostring(err)) end
	end)
end

--- A ring leaves: back to its pool (unparented), or destroyed -- when the pool is full, its template was let go, or the
--- part was taken out from under it (the TerraWrapFX folder gone: its Parent is locked then, never pooled).
local function retireRing(i)
	local R = table.remove(rings.Alive, i)
	if not R then return end
	if R.Part.Parent == nil then
		pcall(function() R.Part:Destroy() end)
		return
	end
	local idle = rings.Idle[R.Q]
	if not idle then
		idle = {}
		rings.Idle[R.Q] = idle
	end
	if #idle < RING_MAX and rings.Tpl[R.Q] == R.Tpl then
		R.Part.Parent = nil
		idle[#idle + 1] = R.Part
	else
		pcall(function() R.Part:Destroy() end)
	end
end

--- One ring at `cf` (the ground point, its UpVector the ring's normal: Y up), growing 0.15 x radius -> radius over
--- Shock.Life on an ease-out, Shock.Colors[1] -> [2], fading by Transparency. Graphics Quality (Density(thin)): full at
--- HIGH / ULTRA, half alpha at MEDIUM (or an enemy's at HIGH under Reduce Enemy VFX); at LOW the caster's own ring is
--- kept at half alpha and everyone else's (thin) is off. Reduce Flashing (Calm): no bright start -- the ring fades IN
--- from the middle of its colour ramp, dimmer. The first ring of a site whose mesh is not built yet starts the build and
--- is skipped.
function TerraWrap.Shockwave(skin, cf, radius, thin)
	local S = type(skin) == "table" and skin.Shock or nil
	if type(S) ~= "table" then return nil end
	cf = (typeof(cf) == "CFrame" and cf) or (typeof(cf) == "Vector3" and CFrame.new(cf)) or nil
	local r = tonumber(radius) or 6
	if not cf or r <= 0.2 then return nil end
	local d = TerraWrap.Density(thin)
	local alpha
	if d >= 0.95 then alpha = 1
	elseif d >= 0.5 or not thin then alpha = 0.5
	else return nil end
	local q = ringStep(r, ringWidth(S))
	local tpl = rings.Tpl[q]
	rings.UsedAt = os.clock()
	if typeof(tpl) ~= "Instance" then
		if tpl == nil then ringKick(skin, q) end
		return nil
	end
	if #rings.Alive >= RING_MAX then retireRing(1) end
	local idle = rings.Idle[q]
	local p = idle and table.remove(idle) or nil
	if not p then
		p = tpl:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
	end
	local cols = type(S.Colors) == "table" and S.Colors or {}
	local c0 = c3(cols[1], WHITE)
	local c1 = c3(cols[2], c0)
	local calm = TerraWrap.Calm()
	if calm then c0 = c0:Lerp(c1, 0.5) end
	-- (the template's radius is 1: a clone Size.X = tpl.Size.X x its radius)
	local R = { Part = p, Tpl = tpl, Q = q, Born = os.clock(), Life = math.max(0.1, tonumber(S.Life) or 0.6), R = r,
		SX = tpl.Size.X, SY = tpl.Size.Y, C0 = c0, C1 = c1, Calm = calm, Peak = calm and 0.6 * alpha or alpha }
	p.Size = Vector3.new(R.SX * r * 0.15, R.SY, R.SX * r * 0.15)
	p.CFrame = cf * CFrame.new(0, RING_LIFT, 0)
	p.Color = c0
	p.Transparency = calm and 1 or 1 - R.Peak
	p.Parent = layerFolder()
	rings.Alive[#rings.Alive + 1] = R
	wakeFx()
	return nil
end

-- THE SHARDS (Shatter, Epic): clones of the crystal templates flown like TerraFX's break debris (DebrisGravity, its
-- bounce and slide off the floor found under the hit), shrinking and fading over the last 40% of their life
local SHARD_MAX, SHARD_GRAV, SHARD_BOUNCE, SHARD_SLIDE = 40, 35, 0.25, 0.6
local shards = {}         -- { Part, P, V, W, Q, Born, Life, Size, Floor }
local shardParams = RaycastParams.new()
shardParams.FilterType = Enum.RaycastFilterType.Exclude
shardParams.RespectCanCollide = true

--- `n` shards from the hit at `cf` (its UpVector the struck face's normal; a Vector3: Y up): Shatter.Count x Density(thin)
--- of them (rounded stochastically; at most SHARD_MAX alive on a client), each a crystal template clone at Shatter.Size
--- of its size, thrown into the hemisphere off the face at the break chunks' speeds and gone by Shatter.Life. Lit at the
--- wrap's Crystals.Glow.Max. Nothing while the templates build (the first ask starts them) or for a skin without them.
function TerraWrap.Shatter(skin, cf, thin)
	local Sh = type(skin) == "table" and skin.Shatter or nil
	if type(Sh) ~= "table" then return nil end
	cf = (typeof(cf) == "CFrame" and cf) or (typeof(cf) == "Vector3" and CFrame.new(cf)) or nil
	if not cf then return nil end
	local list = TerraWrap.CrystalTemplates(skin)
	if type(list) ~= "table" or #list == 0 then return nil end
	local x = math.max(0, tonumber(Sh.Count) or 8) * TerraWrap.Density(thin)
	local n = math.floor(x)
	if math.random() < x - n then n += 1 end
	n = math.min(n, SHARD_MAX - #shards)
	if n <= 0 then return nil end
	local k = math.max(0.05, tonumber(Sh.Size) or 0.5)
	local life = math.max(0.2, tonumber(Sh.Life) or 1.2)
	local G = type(skin.Crystals) == "table" and type(skin.Crystals.Glow) == "table" and skin.Crystals.Glow or nil
	local g = math.clamp((G and tonumber(G.Max)) or 1, 0, 1)
	local col = Color3.new(g, g, g)
	local origin, up = cf.Position, cf.UpVector
	-- the floor under the hit: one ray, solid parts only, no player's body
	local floorY = nil
	pcall(function()
		local ex = { layerFolder() }
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character then ex[#ex + 1] = pl.Character end
		end
		shardParams.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(origin + Vector3.new(0, 0.5, 0), Vector3.new(0, -12, 0), shardParams)
		if hit then floorY = hit.Position.Y end
	end)
	local rng, now, folder = Random.new(), os.clock(), layerFolder()
	for _ = 1, n do
		local tpl = list[rng:NextInteger(1, #list)]
		local p = tpl:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = col
		p.Transparency = 0
		local size = tpl.Size * (k * rng:NextNumber(0.7, 1.15))
		p.Size = size
		local dir = rng:NextUnitVector()
		local dn = dir:Dot(up)
		if dn < 0 then dir -= up * (2 * dn) end            -- (into the hemisphere off the struck face)
		dir = (dir + up * 0.35).Unit
		local at = origin + dir * rng:NextNumber(0.2, 0.6)
		local q = CFrame.fromAxisAngle(rng:NextUnitVector(), rng:NextNumber(0, 2 * math.pi))
		p.CFrame = CFrame.new(at) * q
		p.Parent = folder
		shards[#shards + 1] = { Part = p, P = at, V = dir * rng:NextNumber(8, 14) + Vector3.new(0, rng:NextNumber(2.5, 6), 0),
			W = rng:NextUnitVector() * rng:NextNumber(6, 16), Q = q, Born = now, Life = life * rng:NextNumber(0.8, 1), Size = size,
			Floor = floorY and floorY + 0.3 * math.max(size.X, size.Y, size.Z) or nil }
	end
	wakeFx()
	return nil
end

--- One step of every ring and shard alive (the Heartbeat wakeFx connects; it lets go once none is left).
local function stepFx()
	local now = os.clock()
	local dt = math.min(now - (fxLast or now), 1 / 20)
	fxLast = now
	for i = #rings.Alive, 1, -1 do
		local R = rings.Alive[i]
		local u = (now - R.Born) / R.Life
		if u >= 1 or not R.Part.Parent then
			retireRing(i)
		else
			local rc = R.R * (0.15 + 0.85 * (1 - (1 - u) ^ 2.2))
			R.Part.Size = Vector3.new(R.SX * rc, R.SY, R.SX * rc)
			-- the bright start at full Peak, fading out; held calm: fading in over the first fifth, no flash
			local op = R.Calm and R.Peak * math.min(1, u / 0.2) * (1 - u) ^ 1.4 or R.Peak * (1 - u) ^ 1.6
			R.Part.Transparency = 1 - op
			R.Part.Color = R.C0:Lerp(R.C1, u ^ 0.7)
		end
	end
	local parts, cfs = nil, nil
	for i = #shards, 1, -1 do
		local s = shards[i]
		local u = (now - s.Born) / s.Life
		if u >= 1 or not s.Part.Parent then
			pcall(function() s.Part:Destroy() end)
			table.remove(shards, i)
		else
			local v = s.V - Vector3.new(0, SHARD_GRAV * dt, 0)
			local p = s.P + v * dt
			if s.Floor and p.Y < s.Floor and v.Y < 0 then
				p = Vector3.new(p.X, s.Floor, p.Z)
				v = Vector3.new(v.X * SHARD_SLIDE, -v.Y * SHARD_BOUNCE, v.Z * SHARD_SLIDE)
				s.W *= SHARD_SLIDE
			end
			s.P, s.V = p, v
			local wm = s.W.Magnitude
			if wm > 1e-3 then s.Q = CFrame.fromAxisAngle(s.W / wm, wm * dt) * s.Q end
			parts, cfs = parts or {}, cfs or {}
			parts[#parts + 1] = s.Part
			cfs[#cfs + 1] = CFrame.new(p) * s.Q
			if u > 0.6 then
				local f = (u - 0.6) / 0.4
				s.Part.Transparency = f
				s.Part.Size = s.Size * (1 - 0.65 * f)
			end
		end
	end
	if parts then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

wakeFx = function()
	if fxConn then return end
	fxLast = os.clock()
	fxConn = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(stepFx)
		if not ok then
			-- (a broken step clears what it flies, not an error every frame)
			warn("[TerraWrap] fx step: " .. tostring(err))
			for i = #rings.Alive, 1, -1 do
				local R = table.remove(rings.Alive, i)
				pcall(function() R.Part:Destroy() end)
			end
			for i = #shards, 1, -1 do
				local s = table.remove(shards, i)
				pcall(function() s.Part:Destroy() end)
			end
		end
		if #rings.Alive == 0 and #shards == 0 and fxConn then
			fxConn:Disconnect()
			fxConn = nil
		end
	end)
end

--- THE DRIFT (Drift, Mythic): an ambient emitter of star embers drifting up off `host` (a BasePart or an Attachment: a
--- standing Wall piece, a risen Tomb pillar, the Aftershock scar), Rate = Drift.Rate x Density(thin) -- made enabled at
--- that rate (also kept in its attribute WrapRate); the caller enables / zeroes / destroys it with its host. Sparkle,
--- self-lit, Drift.Colors over life, Drift.Size start -> end, Drift.Life its lifetime. They twinkle (unless Drift.Kind =
--- "Mote"), so under Reduce Flashing there is none: nil. Attribute WrapLayer = "Drift" (a Default-rate sum leaves it out).
--- A skin with a Shock gets its ring meshes started here too (its drift stands before its first ring).
function TerraWrap.DriftSet(skin, host, thin)
	local D = type(skin) == "table" and skin.Drift or nil
	if type(D) ~= "table" or typeof(host) ~= "Instance" or not (host:IsA("BasePart") or host:IsA("Attachment")) then
		return nil
	end
	local twinkle = D.Kind ~= "Mote"
	if twinkle and TerraWrap.Calm() then return nil end
	if type(skin.Shock) == "table" then pcall(ringKick, skin) end
	local e = Instance.new("ParticleEmitter")
	e.Name = "WrapDrift"
	e.Texture = SPARKLE
	e.Color = layerColors(D.Colors)
	e.LightEmission = tonumber(D.LightEmission) or 1
	e.LightInfluence = tonumber(D.LightInfluence) or 0
	local sz = type(D.Size) == "table" and D.Size or { 0.24, 0.06 }
	e.Size = NumberSequence.new(tonumber(sz[1]) or 0.24, tonumber(sz[2] or sz[1]) or 0.06)
	e.Transparency = twinkle and TWINKLE_T or MOTE_T
	e.Lifetime = layerRange(D.Life, 1.2, 2.4)
	e.Speed = layerRange(D.Speed, 0.4, 1.4)
	e.Drag = tonumber(D.Drag) or 0.6
	e.Acceleration = typeof(D.Accel) == "Vector3" and D.Accel or Vector3.new(0, 0.8, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(30, 30)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	local rate = math.max(0, (tonumber(D.Rate) or 0) * TerraWrap.Density(thin))
	e.Rate = rate
	e:SetAttribute("WrapLayer", "Drift")
	e:SetAttribute("WrapRate", rate)
	e.Parent = host
	return e
end

--- MeshBudget's Optional for this section: a cached crystal build nobody was handed (never a handed-out one: pooled
--- pieces wear clones of it) idle CRYSTAL_HOLD seconds, and -- with no ring alive and none asked for in 3 s -- the ring
--- templates, their pooled clones and meshes. Never yields; anything building is left alone; the next ask builds it again.
local function freeExtras()
	local now = os.clock()
	for id, e in pairs(crystalCache) do
		if type(e) == "table" and not e.Handed and now - (e.UsedAt or 0) >= CRYSTAL_HOLD then
			crystalCache[id] = nil
			dropEntry(e)
		end
	end
	if #rings.Alive == 0 and now - rings.UsedAt >= 3 then
		for q, t in pairs(rings.Tpl) do
			if typeof(t) == "Instance" then
				pcall(function() t:Destroy() end)
				rings.Tpl[q] = nil
			end
		end
		for _, idle in pairs(rings.Idle) do
			for _, p in ipairs(idle) do pcall(function() p:Destroy() end) end
		end
		table.clear(rings.Idle)
		for _, m in ipairs(rings.Keep) do pcall(function() m:Destroy() end) end
		table.clear(rings.Keep)
	end
end
MeshBudget.Optional(freeExtras)

return TerraWrap
