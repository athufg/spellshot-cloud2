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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")

local TerraWrap = {}

local catalogScript = ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog")
local Catalog = require(catalogScript)

local LIFT = 0.012        -- studs the fissures sit off the stone (full-size rock)
local STEP = 0.21         -- studs between a fissure's kinks (the mesh budget: 0.16 ran three CrackGlow sets out of it)
local built = {}          -- ["<id>@<glow step>"] = set | "building" | false (failed)

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
local function parallel(n, fn)
	local left, err = n, nil
	for i = 1, n do
		task.spawn(function()
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
local function retry(make)
	for _ = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}
local function makePart(em)
	local fixed = retry(function() return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true }) end)
	em:Destroy()
	release()
	keep[#keep + 1] = fixed
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok then mp = AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch = true, false, false, false
	return mp
end

----------------------------------------------------------------------------------------------------
-- the stone: bands, highlight, ink
----------------------------------------------------------------------------------------------------
--- One kit stone re-made in the wrap. `rel`: its frame in the rock (identity for a pebble). Returns the template, the
--- offset of its new box from the old one, the old box's centre, its triangles (mesh space, Outer marked), and the winding.
local function buildStone(src, rel, skin, edges, toon)
	-- resizable: an asset mesh is fixed-size in-experience by default, and the highlight and the ink are added to it
	acquire()
	local em = retry(function() return AssetService:CreateEditableMeshAsync(Content.fromUri(src.MeshId), { FixedSize = false }) end)
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
		local W = writer(em, front)
		for _, tr in ipairs(list) do W.Tri(tr[1] - c, tr[2] - c, tr[3] - c, tr[4], tr[5], tr[6], tr[7]) end
		W.Tri(lo - c, lo - c + Vector3.new(e, 0, 0), lo - c + Vector3.new(0, e, 0), speck, speck, speck, Vector3.zAxis)
		W.Tri(hi - c, hi - c - Vector3.new(e, 0, 0), hi - c - Vector3.new(0, e, 0), speck, speck, speck, -Vector3.zAxis)
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
-- the set
----------------------------------------------------------------------------------------------------
local function build(skin, kit, glow)
	local set = { Skin = skin, Glow = glow, Cells = {}, Pebbles = {} }
	parallel(#kit.Cells, function(i)
		local cell = kit.Cells[i]
		local entry = nil
		for _, e in ipairs(cell.Parts) do
			if e.Kind == "Cell" and e.Source then entry = e end
		end
		if entry then
			local mp, off, c0, tris, front = buildStone(entry.Source, entry.Rel, skin, skin.HighlightEdges)
			set.Cells[i] = {
				Stone = { Source = mp, Rel = entry.Rel * off, Size = mp.Size },
				Fissure = buildFissures(tris, front, c0, entry.Rel, i, skin, glow),
			}
		end
	end)
	parallel(#kit.Pebbles, function(i)
		local pb = kit.Pebbles[i]
		if pb.Source then
			local mp = buildStone(pb.Source, CFrame.new(), skin, 1)
			set.Pebbles[i] = { Source = mp, Size = mp.Size / math.max(mp.Size.X, mp.Size.Y, mp.Size.Z) }
		end
	end)
	-- BULWARK CHARGE'S ARMOUR AND BEDROCK'S SHELL: the kit's plates and their broken halves, recoloured on the same
	-- mesh (the clone keeps the kit's size and pivot), and on each whole plate one Neon magma seam per stage -- its
	-- pivot set so it lands on the plate wherever the plate is put
	set.Kit, set.PlateCracks = {}, {}
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
				local mp, _, c0, tris, front = buildStone(src, src.PivotOffset:Inverse(), skin, suffix == "" and 2 or 1, true)
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
	glow = glow or TerraWrap.Glow(skin, own)
	local k = skin.Id .. "@" .. math.floor(glow * 20 + 0.5)
	local got = built[k]
	if got ~= nil then return type(got) == "table" and got or nil end
	built[k] = "building"
	task.spawn(function()
		local ok, set = pcall(build, skin, kit, glow)
		built[k] = ok and set or false
		if not ok then
			warn("[TerraWrap] " .. skin.Id .. ": " .. tostring(set))
			-- a failure is not for the session: the next ask after a pause builds it again
			task.delay(5, function() if built[k] == false then built[k] = nil end end)
		end
	end)
	return nil
end

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
	return nil
end

return TerraWrap
