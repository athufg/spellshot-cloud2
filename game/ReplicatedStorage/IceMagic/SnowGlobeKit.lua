--[[
	SnowGlobeKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/SnowGlobeKit

	Cryo's SNOW GLOBE skin (an Epic Element Skin, 2026-10-15; designed in Blender: vfx_blocking/cryo/
	cryo_snowglobe_skin_2026_10_15, kit/sg.py -- the approved checkpoint 2). "Shake, swirl, settle": a glass snow globe on
	a base disc. The meshes are sg.py's geometry ported (lathes, crystal spikes, flat fans), built once per client at load
	from EditableMeshes and copied into fixed-size ones -- the FrostLotusKit pattern, nothing to upload. The palette: a
	darker base body (navy -> deep blue) with a glowing cyan edge (Neon), glass with a glowing outline, snow pure white; no
	warm accent. Cosmetic only: every part Anchored, Massless, CanCollide / CanQuery / CanTouch false. SnowGlobeFX does the
	pieces; CryoFX / VFXLibrary call in for a caster who wears it.

	  On(character)            whether that body's player wears it (SkinCatalog: ElementSkin_Cryo = "SnowGlobe", on Cryo)
	  New / Get / Put / Place / Fade / Drop   a piece of one of the kinds (several layers: body / glass / glow / snow)
	  ShotLook()               the M1's mini globe for VFXLibrary's shot (its disc and glass ride the shot; the band and
	                           the glass's outline ride them: Ride)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local SG = {}
SG.Id = "SnowGlobe"

--- Whether `character`'s player wears Snow Globe (their Cryo skin, while Cryo is their Element).
function SG.On(character)
	if typeof(character) ~= "Instance" then return false end
	local plr = Players:GetPlayerFromCharacter(character)
	-- Studio only: a dummy with StudioSkin stands in for a caster (the skins' side-by-side test); never live
	if not plr then return RunService:IsStudio() and character:GetAttribute("StudioSkin") == SG.Id end
	if (plr:GetAttribute("Element") or "Cryo") ~= "Cryo" then return false end
	return SkinCatalog.ElementSkin(plr, "Cryo") == SG.Id
end

-- the counts, by Graphics Quality: high / medium / low (low also = Reduce Enemy VFX on somebody else's)
SG.Pines = { 6, 4, 2 }           -- Blizzard: pines round the rim, tall and short (snow-capped) alternating
SG.HeroFlakes = { 6, 4, 3 }       -- Mirror Cage: big flakes billowing up inside the globe, settling into the plinth
SG.RimFlakes = { 6, 6, 3 }        -- Flash Freeze: big flakes standing up on the rim
SG.BodyLotus = { 14, 10, 7 }      -- Flash Freeze: small flakes over a rooted body (CryoFX's freeze plumbing, "GlobeFF")
SG.BodyCrowdAt, SG.BodyLotusCrowd = 6, 4   -- ...fewer once many bodies are frozen in view
SG.ShatterPiece = "SG_Mote"         -- the hard-edged shard CryoFX throws at the shatter
SG.ShatterChunks = { 8, 5, 3 }
SG.Slabs = { 3, 2, 2 }            -- M1's hit: thin glass slabs flying out
SG.RefR = 20                      -- rims, plinth and dome are built at radius 20 and set to each ability's own
function SG.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

if not RunService:IsClient() then
	return SG                       -- the server only asks On(); nothing below is built there
end

local function hex(h) return Color3.fromHex(h) end
local NAVY, DEEP, LINE, GLASS = hex("#0F3459"), hex("#1D6FB8"), hex("#3FE0FF"), hex("#DDF3FD")
local SOFT = hex("#E4EEF8")
local WHITE = Color3.new(1, 1, 1)
SG.Look = { Snow = "rbxassetid://122832312371920", Line = LINE, White = WHITE }   -- Snow: Cryo's own snow sprite

-- the layer looks: { material, transparency, reflectance }; the shading is in the vertex colours
local MATS = {
	ice = { Enum.Material.Ice, 0.1, 0.1 },              -- the darker base bodies
	glass = { Enum.Material.SmoothPlastic, 0.62, 0.25 }, -- the mini globe's glass (no refraction)
	dome = { Enum.Material.SmoothPlastic, 0.88, 0.08 },  -- the giant globe: very thin, very clear
	line = { Enum.Material.Neon, 0, 0 },                 -- the glowing cyan edge, the glass outlines
	snow = { Enum.Material.SmoothPlastic, 0, 0 },        -- pure white
	soft = { Enum.Material.Neon, 0.5, 0 },               -- puffs, drifts, the pile, floating snow: a soft glow, not rock
	flake = { Enum.Material.Neon, 0.15, 0 },             -- the darts' glowing point and snowflake fletching (one part): carries far
	glint = { Enum.Material.Neon, 0.35, 0 },
	toon = { Enum.Material.SmoothPlastic, 0, 0 },     -- pass 3: bands + ink hull in one opaque mesh
}

----------------------------------------------------------------------------------------------------
-- geometry (sg.py, ported): triangle lists { a, b, c, ca, cb, cc, normal, group }; the normal is the face's outside
-- (meshPart winds each triangle to it); group 1 = smooth, any other number = flat
----------------------------------------------------------------------------------------------------
local flatN = 0
local function add(list, a, b, c, ca, cb, cc, smooth, want)
	local n = (b - a):Cross(c - a)
	if n.Magnitude < 1e-9 then return end
	n = n.Unit
	if want and n:Dot(want) < 0 then n = -n end
	local g = 1
	if not smooth then
		flatN += 1
		g = -flatN
	end
	list[#list + 1] = { a, b, c, ca, cb or ca, cc or ca, n, g }
end

--- the profile { {r, y}, ... } (clockwise in r-y: outward faces) swept round +Y; `span` (radians): an open arc
local function lathe(list, prof, seg, col, phase, span, smooth)
	phase = phase or 0
	local steps = span and (seg + 1) or seg
	local rings = {}
	for i, rp in ipairs(prof) do
		local ring = {}
		for k = 0, steps - 1 do
			local a = phase + (span and (span * k / seg) or (2 * math.pi * k / seg))
			ring[k] = Vector3.new(rp[1] * math.cos(a), rp[2], rp[1] * math.sin(a))
		end
		rings[i] = ring
	end
	for i = 1, #prof - 1 do
		local A, B = rings[i], rings[i + 1]
		local ca, cb = col(i - 1), col(i)
		for k = 0, seg - 1 do
			local k2 = span and (k + 1) or ((k + 1) % steps)
			add(list, A[k], B[k], A[k2], ca, cb, ca, smooth)
			add(list, A[k2], B[k], B[k2], ca, cb, cb, smooth)
		end
	end
end

--- a crystal spike from `base` to `tip`, widest at fraction f: w across (along `side`), t thick, m-sided
local function bipyramid(list, base, tip, w, t, f, side, cb, ct, ce, m)
	m = m or 4
	local ax = tip - base
	local L = ax.Magnitude
	ax = ax / L
	local sd = side - ax * side:Dot(ax)
	if sd.Magnitude < 1e-6 then sd = ax:Cross(math.abs(ax.X) < 0.9 and Vector3.xAxis or Vector3.zAxis) end
	sd = sd.Unit
	local nz = ax:Cross(sd)
	local mid = base + ax * L * f
	local eq = {}
	for j = 0, m - 1 do
		local a = 2 * math.pi * j / m
		eq[j] = mid + sd * (math.cos(a) * w / 2) + nz * (math.sin(a) * t / 2)
	end
	for j = 0, m - 1 do
		local e0, e1 = eq[j], eq[(j + 1) % m]
		add(list, base, e0, e1, cb, ce, ce, false, (base + e0 + e1) / 3 - mid)
		add(list, tip, e0, e1, ct, ce, ce, false, (tip + e0 + e1) / 3 - mid)
	end
end

--- a flat ring (or arc) in the XY plane round `c`, facing `want`
local function annulus(list, c, r0, r1, seg, col, a0, a1, want)
	a0, a1 = a0 or 0, a1 or 2 * math.pi
	local open = a1 - a0 < 2 * math.pi - 1e-6
	local n = open and seg + 1 or seg
	local ins, outs = {}, {}
	for k = 0, n - 1 do
		local a = a0 + (a1 - a0) * k / seg
		ins[k] = c + Vector3.new(r0 * math.cos(a), r0 * math.sin(a), 0)
		outs[k] = c + Vector3.new(r1 * math.cos(a), r1 * math.sin(a), 0)
	end
	for k = 0, seg - 1 do
		local k2 = open and k + 1 or (k + 1) % n
		add(list, ins[k], outs[k], outs[k2], col, col, col, false, want)
		add(list, ins[k], outs[k2], ins[k2], col, col, col, false, want)
	end
end

local function frameFrom(up)
	up = up.Unit
	local h = (math.abs(up.Y) < 0.95) and Vector3.yAxis or Vector3.xAxis
	local r = h:Cross(up).Unit
	return r, up, r:Cross(up)
end

--- a snowflake of `n` crystal arms round `hub`, in the plane square to `normal`
local function flakeArms(list, hub, normal, n, L, w, t, bAt, bL, cHub, cTip, both, phase)
	local r, _, b = frameFrom(normal)
	local s60, c60 = math.sin(math.pi / 3), math.cos(math.pi / 3)
	for k = 0, n - 1 do
		local a = (phase or 0) + 2 * math.pi * k / n
		local d = r * math.cos(a) + b * math.sin(a)
		local sd = -r * math.sin(a) + b * math.cos(a)
		bipyramid(list, hub, hub + d * L, w, t, 0.3, sd, cHub, cTip, cHub, 3)
		if bL > 0 then
			local base = hub + d * (L * bAt)
			for _, sg in ipairs(both and { 1, -1 } or { 1 }) do
				local e = d * c60 + sd * (sg * s60)
				local es = -d * (sg * s60) + sd * c60
				bipyramid(list, base, base + e * bL, w * 0.7, t * 0.8, 0.35, es, cHub, cTip, cHub, 3)
			end
		end
	end
end

--- copy triangles from `src` into `dst` through `xf` (a function of a point), each re-wound to its own outside
local function bake(dst, src, xf)
	for _, t in ipairs(src) do
		local a, b, c, cb, cc = t[1], t[2], t[3], t[5], t[6]
		if (b - a):Cross(c - a):Dot(t[7]) < 0 then b, c, cb, cc = c, b, cc, cb end
		local A, B, C = xf(a), xf(b), xf(c)
		local n = (B - A):Cross(C - A)
		if n.Magnitude > 1e-9 then dst[#dst + 1] = { A, B, C, t[4], cb, cc, n.Unit, t[8] } end
	end
end

----------------------------------------------------------------------------------------------------
-- the kinds (sg.py's models; checkpoint 2 plus the build notes: the Flash Freeze rim and the cage plinth taller)
----------------------------------------------------------------------------------------------------
local K = {}


----------------------------------------------------------------------------------------------------
-- building (the TerraWrap / FrostLotusKit pattern): one resizable EditableMesh at a time, copied into a fixed-size one
----------------------------------------------------------------------------------------------------
local function vkey(v)
	return string.format("%d,%d,%d", math.floor(v.X * 4000 + 0.5), math.floor(v.Y * 4000 + 0.5), math.floor(v.Z * 4000 + 0.5))
end

local function retry(make)
	for _ = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}
--- A MeshPart of `tris`, centred on its box (smooth normals within each surface group); and the box's centre.
local function meshPart(tris)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, t in ipairs(tris) do
		for k = 1, 3 do lo, hi = lo:Min(t[k]), hi:Max(t[k]) end
	end
	local c = (lo + hi) / 2
	local acc = {}
	for _, t in ipairs(tris) do
		local area = (t[2] - t[1]):Cross(t[3] - t[1]).Magnitude
		for k = 1, 3 do
			local key = vkey(t[k]) .. "#" .. t[8]
			acc[key] = (acc[key] or Vector3.zero) + t[7] * area
		end
	end
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local verts, cols, norms = {}, {}, {}
	local uv = nil
	pcall(function() uv = em:AddUV(Vector2.zero) end)
	local function vtx(p)
		local k = vkey(p)
		local id = verts[k]
		if not id then id = em:AddVertex(p) verts[k] = id end
		return id
	end
	local function col(cl)
		local k = cl:ToHex()
		local id = cols[k]
		if not id then id = em:AddColor(cl, 1) cols[k] = id end
		return id
	end
	local function nrm(n)
		local k = vkey(n)
		local id = norms[k]
		if not id then id = em:AddNormal(n) norms[k] = id end
		return id
	end
	for _, t in ipairs(tris) do
		local P = { t[1], t[2], t[3] }
		local Cc = { t[4], t[5], t[6] }
		local Nx = t[10]                                  -- a smooth piece's own corner normals (else its group's mean)
		if (P[2] - P[1]):Cross(P[3] - P[1]):Dot(t[7]) < 0 then
			P[2], P[3], Cc[2], Cc[3] = P[3], P[2], Cc[3], Cc[2]
			if Nx then Nx = { Nx[1], Nx[3], Nx[2] } end
		end
		local f = em:AddTriangle(vtx(P[1] - c), vtx(P[2] - c), vtx(P[3] - c))
		em:SetFaceColors(f, { col(Cc[1]), col(Cc[2]), col(Cc[3]) })
		local ns = {}
		for k = 1, 3 do
			if Nx then
				ns[k] = nrm(Nx[k])
			else
				local a = acc[vkey(P[k]) .. "#" .. t[8]]
				ns[k] = nrm((a and a.Magnitude > 1e-9) and a.Unit or t[7])
			end
		end
		em:SetFaceNormals(f, ns)
		if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
	end
	local fixed = retry(function() return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true }) end)
	em:Destroy()
	keep[#keep + 1] = fixed
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok then mp = AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Color = WHITE
	pcall(function() mp.DoubleSided = false end)      -- back faces culled: the ink hull shows only past the edge
	return mp, c, #tris
end

----------------------------------------------------------------------------------------------------
-- PASS 3 (2026-10-15, "build the effects from the HUD icons"; Blender: kit/sg3.py): the pop-art comic pieces. Each is ONE
-- part: its faces in the three flat tone bands (VFXLibrary.Config.Colors, by the face's normal against one light: IceDeep
-- shadow, IceMid, IceLight lit; Rim white for the stripes), its ink an inverted hull (an inflated, inside-out copy in the
-- Outline colour) and any halftone dots, all in a single SmoothPlastic mesh, white, back faces culled, never transparent
-- (a piece goes by sinking or shrinking). Angular and six-armed throughout: Cryo's snowflake with its hexagonal core.
--
-- SMOOTHING (2026-10-15, the review: "the base disc looks octagonal, the glass faceted, the dome lumpy"): the ROUND,
-- MANUFACTURED pieces -- the M1's globe and disc, the cage's ribs / rings / outline, the curb family (plinth, Flash
-- Freeze's ring, Blizzard's rim) -- are smooth, a deliberate exception to "faceted, never round"; the ice (flakes, shards,
-- slabs, darts, pines) stays angular. A smooth face carries its own corner normals (t[10]). A tube's six section corners
-- sit ON the tone bands' boundaries (bands from the smooth normal), so its bands end in clean curves at no extra
-- triangles; the hull rides the smooth normals, mitred to one width round a real corner (the curb's top, the disc's rims).
----------------------------------------------------------------------------------------------------
local DEEP3, MID3, LIGHT3, RIM3, INK3 = hex("#0E4FA8"), hex("#3FB6F0"), hex("#D6F6FF"), hex("#FFFFFF"), hex("#080E1A")
local LIGHTV = Vector3.new(-0.35, 0.85, 0.4).Unit
local function bandOf(n)
	local d = n:Dot(LIGHTV)
	return d > 0.45 and LIGHT3 or (d > -0.55 and MID3 or DEEP3)     -- IceDeep only for undersides and shadow sides
end

--- a convex polygon (a fan), its outside away from `centre` (or along `want`); its colour its tone band unless given
local function tface(list, pts, centre, col, noHull, want)
	local n = (pts[2] - pts[1]):Cross(pts[3] - pts[1])
	if n.Magnitude < 1e-9 then return end
	n = n.Unit
	if want then
		if n:Dot(want) < 0 then n = -n end
	elseif n:Dot((pts[1] + pts[2] + pts[3]) / 3 - centre) < 0 then
		n = -n
	end
	local c = col or bandOf(n)
	for k = 2, #pts - 1 do
		flatN += 1
		list[#list + 1] = { pts[1], pts[k], pts[k + 1], c, c, c, n, -flatN, noHull }
	end
end

--- a convex 2D polygon { {x, y} } in the frame o / ux / uy (n its face), extruded `thick` along n (centred)
local function tprism(list, poly, o, ux, uy, n, thick, col)
	local top, bot = {}, {}
	local cx, cy = 0, 0
	for i, p in ipairs(poly) do
		local q = o + ux * p[1] + uy * p[2]
		top[i], bot[i] = q + n * (thick / 2), q - n * (thick / 2)
		cx, cy = cx + p[1] / #poly, cy + p[2] / #poly
	end
	local cen = o + ux * cx + uy * cy
	tface(list, top, cen, col)
	tface(list, bot, cen, col)
	for i = 1, #poly do
		local j = i % #poly + 1
		tface(list, { bot[i], bot[j], top[j], top[i] }, cen, col)
	end
end

--- a faceted rib of radius r along a polyline (a `sides`-gon section), its ends capped unless closed
local function ttube(list, pts, r, sides, closed, col)
	local n = #pts
	local rings = {}
	for i = 1, n do
		local a = (closed or i > 1) and pts[(i - 2) % n + 1] or pts[i]
		local b = (closed or i < n) and pts[i % n + 1] or pts[i]
		local t = (b - a).Unit
		local h = math.abs(t.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
		local u = t:Cross(h).Unit
		local w = t:Cross(u)
		local ring = {}
		for k = 0, sides - 1 do
			local ang = 2 * math.pi * k / sides
			ring[k] = pts[i] + u * (r * math.cos(ang)) + w * (r * math.sin(ang))
		end
		rings[i] = ring
	end
	for i = 1, closed and n or n - 1 do
		local A, B = rings[i], rings[i % n + 1]
		local mid = (pts[i] + pts[i % n + 1]) / 2
		for k = 0, sides - 1 do
			local k2 = (k + 1) % sides
			tface(list, { A[k], A[k2], B[k2], B[k] }, mid, col)
		end
	end
	if not closed then
		local c0, c1 = {}, {}
		for k = 0, sides - 1 do c0[k + 1], c1[k + 1] = rings[1][k], rings[n][k] end
		tface(list, c0, pts[2], col)
		tface(list, c1, pts[n - 1], col)
	end
end

--- a halftone patch: flat hexagonal dots on a face (frame o / ux / uy, facing n), shrinking along uy; no ink
local function thexdots(list, o, ux, uy, n, cols, rows, pitch, rmax, rmin)
	for j = 0, rows - 1 do
		local r = rmax + (rmin - rmax) * (j / math.max(1, rows - 1))
		for i = 0, cols - 1 do
			local x = (i - (cols - 1) / 2) * pitch + ((j % 2 == 1) and pitch / 2 or 0)
			local c = o + ux * x + uy * (j * pitch * 0.87) + n * 0.015
			local pts = {}
			for k = 0, 5 do pts[k + 1] = c + ux * (r * math.cos(math.pi / 3 * k)) + uy * (r * math.sin(math.pi / 3 * k)) end
			tface(list, pts, c, DEEP3, true, n)
		end
	end
end

--- the snowflake (the logo's): a hexagonal core, six arms with a chevron of barbs and a pointed tip; radius R in the
--- plane of ux / uy, `thick` along n. `plain`: no barbs (the small ones on a body)
local function tflake(list, o, ux, uy, n, R, thick, plain)
	local core = {}
	for k = 0, 5 do
		local a = math.pi / 3 * k + math.pi / 6
		core[k + 1] = { 0.28 * R * math.cos(a), 0.28 * R * math.sin(a) }
	end
	tprism(list, core, o, ux, uy, n, thick)
	for k = 0, 5 do
		local a = math.pi / 2 + k * math.pi / 3
		local d = { math.cos(a), math.sin(a) }
		local s = { -d[2], d[1] }
		local function P2(r, w) return { (d[1] * r + s[1] * w) * R, (d[2] * r + s[2] * w) * R } end
		tprism(list, { P2(0.2, -0.085), P2(0.78, -0.085), P2(0.78, 0.085), P2(0.2, 0.085) }, o, ux, uy, n, thick)
		tprism(list, { P2(0.76, -0.14), P2(1.0, 0), P2(0.76, 0.14) }, o, ux, uy, n, thick)
		if not plain then
			for _, sg in ipairs({ 1, -1 }) do
				local b = a + sg * math.rad(48)
				local e, es = { math.cos(b), math.sin(b) }, { -math.sin(b), math.cos(b) }
				local bx, by = d[1] * 0.48, d[2] * 0.48
				local function Q(t, w) return { (bx + e[1] * t + es[1] * w) * R, (by + e[2] * t + es[2] * w) * R } end
				tprism(list, { Q(0, -0.06), Q(0.26, -0.06), Q(0.26, 0.06), Q(0, 0.06) }, o, ux, uy, n, thick)
			end
		end
	end
end

--- the dart (the icon's arrow): two crossed kite plates, tail at the origin, +Y the point
local function tdart(list, L, W, T)
	local kite = { { 0, 1.0 }, { 0.5, 0.4 }, { 0, 0.06 }, { -0.5, 0.4 } }
	for _, ux in ipairs({ Vector3.xAxis, Vector3.zAxis }) do
		local poly = {}
		for i, p in ipairs(kite) do poly[i] = { p[1] * W, p[2] * L } end
		tprism(list, poly, Vector3.zero, ux, Vector3.yAxis, ux:Cross(Vector3.yAxis), T)
	end
end

--- the inverted hull: each inked triangle again, pushed out by `ink` along its corner's averaged normal, facing in. A
--- smooth piece's corners go along their smooth normals, mitred (1 / the corner's least cos) so the line keeps one width
--- round a real corner, and the hull takes those normals turned in
local function addHull(list, ink)
	local smooth = false
	for _, t in ipairs(list) do
		if t[10] then
			smooth = true
			break
		end
	end
	local acc = {}
	for _, t in ipairs(list) do
		if not t[9] then
			local area = smooth and 1 or (t[2] - t[1]):Cross(t[3] - t[1]).Magnitude
			for k = 1, 3 do
				local key = vkey(t[k])
				acc[key] = (acc[key] or Vector3.zero) + (t[10] and t[10][k] or t[7]) * area
			end
		end
	end
	local least = {}
	if smooth then
		for _, t in ipairs(list) do
			if not t[9] then
				for k = 1, 3 do
					local key = vkey(t[k])
					local a = acc[key]
					if a and a.Magnitude > 1e-9 then
						least[key] = math.min(least[key] or 1, a.Unit:Dot(t[10] and t[10][k] or t[7]))
					end
				end
			end
		end
	end
	for i = 1, #list do
		local t = list[i]
		if not t[9] then
			local P, Nn = {}, {}
			for k = 1, 3 do
				local key = vkey(t[k])
				local a = acc[key]
				local d = (a and a.Magnitude > 1e-9) and a.Unit or t[7]
				P[k] = t[k] + d * (ink / math.max(0.6, least[key] or 1))
				Nn[k] = -d
			end
			flatN += 1
			list[#list + 1] = { P[1], P[2], P[3], INK3, INK3, INK3, -t[7], -flatN, true, smooth and Nn or nil }
		end
	end
end

-- THE SMOOTH HELPERS. sface: a convex polygon (a fan) with its own corner normals `ns`, coloured `col` or the tone band of
-- its middle (the corners' mean normal); cfan: a fan from a centre round a closed ring; stube: a smooth tube; sweep: a
-- smooth lathe
local function sface(list, pts, ns, col, noHull)
	local avg = Vector3.zero
	for _, n in ipairs(ns) do avg += n end
	if avg.Magnitude < 1e-9 then return end
	avg = avg.Unit
	local c = col or bandOf(avg)
	for k = 2, #pts - 1 do
		local a, b, d = pts[1], pts[k], pts[k + 1]
		local fn = (b - a):Cross(d - a)
		if fn.Magnitude > 1e-9 then
			fn = fn.Unit
			if fn:Dot(avg) < 0 then fn = -fn end
			flatN += 1
			list[#list + 1] = { a, b, d, c, c, c, fn, -flatN, noHull, { ns[1], ns[k], ns[k + 1] } }
		end
	end
end

local function cfan(list, c, nc, ring, nring, col, noHull)
	for i = 1, #ring do
		local j = i % #ring + 1
		sface(list, { c, ring[i], ring[j] }, { nc, nring[i], nring[j] }, col, noHull)
	end
end

--- where a tube's tone bands change round its section (angles from its lit side; m = the light's part across the tube):
--- IceLight within aL, IceDeep beyond pi - aD; a band the tube never shows gets a filler corner instead
local function isoAngles(m)
	local aL = (m > 0.45) and math.acos(0.45 / m) or math.rad(45)
	local aD = (m > 0.55) and math.acos(0.55 / m) or math.rad(50)
	return math.max(aL, math.rad(15)), math.max(aD, math.rad(15))
end

--- a smooth rib of radius r along a polyline: six section corners, ON the bands' boundaries (and one mid-light, one
--- mid-shadow), so each face is one band and the bands end in clean curves along the tube; open ends (they sit in the
--- curb, the hub, the feet)
local function stube(list, pts, r, closed, col)
	local n = #pts
	local rings, norms = {}, {}
	for i = 1, n do
		local a = (closed or i > 1) and pts[(i - 2) % n + 1] or pts[i]
		local b = (closed or i < n) and pts[i % n + 1] or pts[i]
		local t = (b - a).Unit
		local lp = LIGHTV - t * LIGHTV:Dot(t)
		local m = lp.Magnitude
		local e1 = (m > 1e-3) and lp / m or t:Cross(math.abs(t.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis).Unit
		local e2 = t:Cross(e1)
		local aL, aD = isoAngles(m)
		local ring, nr = {}, {}
		for j, phi in ipairs({ 0, aL, math.pi - aD, math.pi, math.pi + aD, 2 * math.pi - aL }) do
			local d = e1 * math.cos(phi) + e2 * math.sin(phi)
			ring[j], nr[j] = pts[i] + d * r, d
		end
		rings[i], norms[i] = ring, nr
	end
	for i = 1, closed and n or n - 1 do
		local i2 = i % n + 1
		local A, B, NA, NB = rings[i], rings[i2], norms[i], norms[i2]
		for j = 1, 6 do
			local j2 = j % 6 + 1
			sface(list, { A[j], A[j2], B[j2], B[j] }, { NA[j], NA[j2], NB[j2], NB[j] }, col)
		end
	end
end

local function corner(R, a) return Vector3.new(R * math.cos(a), 0, R * math.sin(a)) end

--- the profile { {dr, y} } swept round +Y over faces f0..f1-1 of N (corners at (R + dr) * k); strip s coloured cols[s]
--- (nil: its tone band); strips of one smooth run share their joint's normal, any other joint is a hard edge (c2: a
--- point inside the profile, to face the strips out)
local function sweep(list, R, k, f0, f1, N, prof, cols, runs, c2)
	local n2 = {}
	for s = 1, #prof - 1 do
		local p, q = prof[s], prof[s + 1]
		local v = Vector2.new(q[2] - p[2], p[1] - q[1]).Unit
		if v:Dot(Vector2.new((p[1] + q[1]) / 2, (p[2] + q[2]) / 2) - c2) < 0 then v = -v end
		n2[s] = v
	end
	local function vn(s, o)
		return (n2[s + o] and runs[s + o] == runs[s]) and (n2[s] + n2[s + o]).Unit or n2[s]
	end
	local function P(dr, y, a) return corner((R + dr) * k, a) + Vector3.new(0, y, 0) end
	local function N3(v, a) return Vector3.new(v.X * math.cos(a), v.Y, v.X * math.sin(a)) end
	for f = f0, f1 - 1 do
		local a0, a1 = 2 * math.pi * f / N, 2 * math.pi * (f + 1) / N
		for s = 1, #prof - 1 do
			local p, q = prof[s], prof[s + 1]
			local u, v = vn(s, -1), vn(s, 1)
			sface(list, { P(p[1], p[2], a0), P(p[1], p[2], a1), P(q[1], q[2], a1), P(q[1], q[2], a0) },
				{ N3(u, a0), N3(u, a1), N3(v, a1), N3(v, a0) }, cols[s])
		end
	end
end

-- THE BASE FAMILY, round 3 (smoothed): a LOW CURB, knee high (1.05), round -- 36 faces (Blizzard's rim 32), smooth round
-- its circle, hard only at the top's two corners -- banded like the HUD icon's plinth: a white snow top with low lumps
-- (one every other face), an IceMid band with a halftone patch, the white stripe, an IceDeep band, the cyan foot strip.
-- (Round 2's 0.1 bevels at the top's edges are gone: the edges are the corners now.) One part is faces f0..f1-1 of the
-- ring, built where it sits (lit as the world sees it). The cage's plinth is 6 parts of it, Flash Freeze's ring 12
-- (narrower), Blizzard's rim 12 (no lumps, no dots).
local CURB_N, BZ_N = 36, 32
local LUMP_L = SG.RefR * (2 * math.pi / 24) * 0.42       -- a lump's half length (round 2's: the snow reads the same)
local function curbPart(list, R, f0, f1, N, width, H, lumpEvery, dots)
	local w, h = width, H
	-- the profile { dr, y }: inside foot, inside top, outside top, the stripe's top and foot, the deep band's foot, the foot
	local prof = { { 0, 0 }, { 0, h }, { w, h }, { w, h * 0.62 }, { w + 0.03, h * 0.47 }, { w + 0.07, h * 0.24 }, { w + 0.2, 0 } }
	sweep(list, R, 1 / math.cos(math.pi / N), f0, f1, N, prof, { nil, RIM3, MID3, RIM3, DEEP3, MID3 }, { 1, 2, 3, 3, 3, 3 },
		Vector2.new(w / 2, h / 2))
	for f = f0, f1 - 1 do
		local am = 2 * math.pi * (f + 0.5) / N
		local out = Vector3.new(math.cos(am), 0, math.sin(am))
		-- snow on the top: a low lump on every other face (no higher than 0.18), in two staggered rows
		if lumpEvery and f % lumpEvery == 0 then
			local c = corner(R + w * ((f % (2 * lumpEvery) == 0) and 0.35 or 0.65), am) + Vector3.new(0, h, 0)
			local t = Vector3.new(-math.sin(am), 0, math.cos(am))
			bipyramid(list, c - t * LUMP_L, c + t * LUMP_L, w * 0.44, 0.36, 0.5, out, RIM3, RIM3, RIM3, 4)
		end
		-- the halftone patch on the IceMid band (one face in six)
		if dots and f % 6 == 0 then
			local ux = Vector3.new(-out.Z, 0, out.X)
			thexdots(list, out * (R + w + 0.005) + Vector3.new(0, h * 0.67, 0), ux, Vector3.yAxis, out, 9, 2, 0.2, 0.07, 0.05)
		end
	end
end
SG.PlinthH, SG.RimH = 1.05, 1.0
for f = 0, 5 do K["Plinth" .. (f + 1)] = function(L) curbPart(L("toon"), SG.RefR, f * 6, f * 6 + 6, CURB_N, 2.0, 1.05, 2, true) end end
for f = 0, 11 do K["Rim" .. (f + 1)] = function(L) curbPart(L("toon"), SG.RefR, f * 3, f * 3 + 3, CURB_N, 1.6, 1.0, 2, true) end end

-- THE GLOBE, round 3 (smoothed): clean geometry -- one sphere (radius 20, centred the code's Look.Cage DomeY over the
-- floor) standing on the curb's top; six evenly spaced meridians (the six-arm snowflake) from the curb into a hexagonal hub,
-- three latitude rings level with the base (the first ON the curb: the round base outline; the middle one the icon's white
-- ring), every rib the same radius: smooth tubes on clean arcs, 12 segments up each meridian, 32 / 28 / 16 round the rings;
-- a white snow cap on the hub. (Round 2's lumpy snow ridges along the ribs are gone: they made the silhouette lumpy.)
-- Faces open: see and shoot through.
SG.DomeY = 2.6
local RIB = 0.42
K.Ribs = function(L)
	local list, R = L("toon"), SG.RefR
	local cen = Vector3.new(0, SG.DomeY, 0)
	local e0 = math.asin((SG.PlinthH - SG.DomeY) / R)          -- the frame stands on the curb's top
	local hubR = 1.6
	local e1 = math.acos(hubR / R)
	local eIn = math.acos(1.2 / R)                             -- the meridians run on into the hub: their ends inside it
	local function onSphere(e, az) return cen + Vector3.new(R * math.cos(e) * math.cos(az), R * math.sin(e), R * math.cos(e) * math.sin(az)) end
	for k = 0, 5 do
		local az = math.pi / 6 + k * math.pi / 3
		local pts = {}
		for i = 0, 12 do pts[#pts + 1] = onSphere(e0 + (eIn - e0) * i / 12, az) end
		stube(list, pts, RIB)
	end
	for _, lat in ipairs({ { e0, 32, false }, { math.rad(30), 28, true }, { math.rad(60), 16, false } }) do
		local pts = {}
		for i = 0, lat[2] - 1 do pts[#pts + 1] = onSphere(lat[1], 2 * math.pi * i / lat[2]) end
		stube(list, pts, RIB, true, lat[3] and RIM3 or nil)
	end
	local hub = {}
	for k = 0, 5 do hub[k + 1] = { hubR * math.cos(math.pi / 3 * k), hubR * math.sin(math.pi / 3 * k) } end
	tprism(list, hub, cen + Vector3.new(0, R * math.sin(e1), 0), Vector3.xAxis, Vector3.zAxis, Vector3.yAxis, RIB * 2)
	local cap = {}
	for k = 0, 5 do cap[k + 1] = { 1.1 * math.cos(math.pi / 3 * k + 0.3), 1.1 * math.sin(math.pi / 3 * k + 0.3) } end
	tprism(list, cap, cen + Vector3.new(0, R * math.sin(e1) + RIB * 1.2, 0), Vector3.xAxis, Vector3.zAxis, Vector3.yAxis, RIB * 0.8, RIM3)
end
-- the globe's outline (one tidy hemisphere edge, the ribs' radius: a smooth tube, 24 segments over the top) and its GLOSS:
-- two thin curved white crescents on the glass where the highlight falls (the icon's upper left), all turned to the camera
-- every frame (built facing -Z, in the XY plane, centred on the sphere's centre; the near surface is -Z)
K.Outline = function(L)
	local list, R = L("toon"), SG.RefR
	local e0 = math.asin((SG.PlinthH - SG.DomeY) / R)
	local pts = {}
	for i = 0, 24 do
		local a = e0 + (math.pi - 2 * e0) * (i / 24)           -- from the right foot over the top to the left foot
		pts[#pts + 1] = Vector3.new(R * math.cos(a), R * math.sin(a), 0)
	end
	stube(list, pts, RIB)
	for _, g in ipairs({ { 0.8, 0.92, 108, 156 }, { 0.68, 0.77, 116, 144 } }) do     -- (widened on review)
		local inner, outer = {}, {}
		for i = 0, 10 do
			local a = math.rad(g[3] + (g[4] - g[3]) * i / 10)
			local taper = math.sin(math.pi * i / 10)
			local r0, r1 = R * g[1], R * (g[1] + (g[2] - g[1]) * math.max(0.15, taper))
			local function onGlass(r)
				local x, y = r * math.cos(a), r * math.sin(a)
				return Vector3.new(x, y, -math.sqrt(math.max(0, R * R - x * x - y * y)) - 0.15)
			end
			inner[i], outer[i] = onGlass(r0), onGlass(r1)
		end
		for i = 0, 9 do                                        -- the camera's side only (the far copy never showed), no ink
			tface(list, { inner[i], outer[i], outer[i + 1], inner[i + 1] }, nil, RIM3, true, Vector3.new(0, 0, -1))
		end
	end
end
-- a low snow drift for the inner edge (an angular mound, 0.6 high, 4.4 long; white top, light sides)
K.Drift3 = function(L)
	local list = L("toon")
	local base, top = {}, {}
	for k = 0, 5 do
		local a = math.pi / 3 * k
		base[k + 1] = Vector3.new(2.2 * math.cos(a), 0, 0.8 * math.sin(a))
		top[k + 1] = Vector3.new(1.3 * math.cos(a), 0.6, 0.35 * math.sin(a))
	end
	local cen = Vector3.new(0, 0.2, 0)
	tface(list, top, cen, RIM3)
	for k = 1, 6 do
		local j = k % 6 + 1
		tface(list, { base[k], base[j], top[j], top[k] }, cen, LIGHT3)
	end
end
-- a big flake (radius 1, flat in the XZ plane, +Y its face): the cage's hero flakes (x2.6), Flash Freeze's upright ones
K.Hero = function(L) tflake(L("toon"), Vector3.zero, Vector3.xAxis, Vector3.zAxis, Vector3.yAxis, 1, 0.16) end
-- a small plain flake for a frozen body (radius 1, placed ~0.5)
K.BodyFlake = function(L) tflake(L("toon"), Vector3.zero, Vector3.xAxis, Vector3.zAxis, Vector3.yAxis, 1, 0.22, true) end
-- the cage's dart, chunky: 3.2 long, 1.1 wide
K.Dart3 = function(L) tdart(L("toon"), 3.2, 1.1, 0.34) end
SG.Dart3L = 3.2
-- a hard-edged shard (the shatter's pieces): a hexagonal crystal
K.Mote = function(L) bipyramid(L("toon"), Vector3.new(0, -0.5, 0), Vector3.new(0, 0.5, 0), 0.42, 0.42, 0.4, Vector3.xAxis, MID3, LIGHT3, DEEP3, 6) end
-- Flash Freeze's flat halftone ground patch: rings of hexagonal dots, biggest at the rim (no ink)
K.Dots = function(L)
	local list, R = L("toon"), SG.RefR
	for j = 0, 3 do
		local rr, r = R - 1.3 - j * 1.35, 0.5 - j * 0.09
		local cnt = math.floor(2 * math.pi * rr / 1.55)
		for i = 0, cnt - 1 do
			local a = 2 * math.pi * (i + 0.5 * (j % 2)) / cnt
			local c = Vector3.new(rr * math.cos(a), 0.03, rr * math.sin(a))
			local pts = {}
			for k = 0, 5 do pts[k + 1] = c + Vector3.new(r * math.cos(math.pi / 3 * k + a), 0, r * math.sin(math.pi / 3 * k + a)) end
			tface(list, pts, c, DEEP3, true, Vector3.yAxis)
		end
	end
end
-- STAGE 2 (pass 3): M1 and Cold Momentum, from their icons
-- a toon lathe: the profile { {r, y} } swept round +Y (n sides), each face's colour colAt(centroid y, normal) or its band
local function tlathe(list, prof, n, phase, colAt)
	local rings = {}
	for i, p in ipairs(prof) do
		local ring = {}
		for k = 0, n - 1 do
			local a = phase + 2 * math.pi * k / n
			ring[k] = Vector3.new(p[1] * math.cos(a), p[2], p[1] * math.sin(a))
		end
		rings[i] = ring
	end
	local my = 0
	for _, p in ipairs(prof) do my += p[2] / #prof end
	for i = 1, #prof - 1 do
		local A, B = rings[i], rings[i + 1]
		for k = 0, n - 1 do
			local k2 = (k + 1) % n
			local pts = { A[k], B[k], B[k2], A[k2] }
			if (A[k] - A[k2]).Magnitude < 1e-6 then pts = { A[k], B[k], B[k2] } elseif (B[k] - B[k2]).Magnitude < 1e-6 then pts = { A[k], B[k], A[k2] } end
			local c = Vector3.zero
			for _, q in ipairs(pts) do c += q / #pts end
			local nrm = (pts[2] - pts[1]):Cross(pts[3] - pts[1])
			tface(list, pts, Vector3.new(0, my, 0), colAt and colAt(c.Y, nrm) or nil)
		end
	end
end

--- a flat star (pts points) in the XY plane at depth z, facing -Z, over a dark copy (its ink) just behind
local function tstar(list, c, r, pts, inner, z, col)
	for _, layer in ipairs({ { 1.2, INK3, z + 0.004 }, { 1.0, col, z } }) do
		local ring = {}
		for k = 0, 2 * pts - 1 do
			local rr = r * layer[1] * ((k % 2 == 0) and 1 or inner)
			local a = math.pi / 2 + math.pi * k / pts
			ring[#ring + 1] = Vector3.new(c.X + rr * math.cos(a), c.Y + rr * math.sin(a), layer[3])
		end
		local o = Vector3.new(c.X, c.Y, layer[3])
		for k = 1, #ring do
			tface(list, { o, ring[k], ring[k % #ring + 1] }, nil, layer[2], true, Vector3.new(0, 0, -1))
		end
	end
end

--- a flat disc / ellipse fan (n sides) in a frame: centre o, axes ux (rx) and uy (ry), facing `want`
local function tellipse(list, o, ux, uy, rx, ry, n, col, want, keep)
	local pts = {}
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / n
		local p = o + ux * (rx * math.cos(a)) + uy * (ry * math.sin(a))
		if not keep or keep(p) then pts[#pts + 1] = p end
	end
	for k = 2, #pts - 1 do tface(list, { pts[1], pts[k], pts[k + 1] }, nil, col, true, want) end
end

-- M1: the mini globe's base disc -- round (12 faces, smooth round its side, hard only at its rims): a snow-white top, an
-- IceDeep band, the cyan foot; +Y the flight, the face (below) leading. (Round 2's snow cone on the top is gone: the globe
-- hid it, and its triangles pay for the round side.)
K.M1Body = function(L)
	local list, n = L("toon"), 12
	sweep(list, 0, 1, 0, n, n, { { 0.52, 0.32 }, { 0.57, 0.17 }, { 0.5, 0 } }, { DEEP3, MID3 }, { 1, 1 }, Vector2.new(0, 0.16))
	local top, bot, up, dn = {}, {}, {}, {}
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / n
		top[k + 1], bot[n - k] = corner(0.52, a) + Vector3.new(0, 0.32, 0), corner(0.5, a)
		up[k + 1], dn[k + 1] = Vector3.yAxis, -Vector3.yAxis
	end
	sface(list, top, up, RIM3)
	sface(list, bot, dn, MID3)
end
-- ...and the globe itself as the icon draws it, turned to the camera (built in the XY plane facing -Z, centred on the
-- globe's centre): a round IceMid ball -- its middle bulging toward the camera with a sphere's normals, so it shades round
-- -- on an ink disc, its lower part filled with white snow, a big six-point star, a small four-point one and a white gloss
-- crescent laid on its curve (no ink of their own). Opaque, and only a stud across: 16 round its rim.
K.M1Face = function(L)
	local list, F = L("toon"), Vector3.new(0, 0, -1)
	local R, y0, LIFT = 0.48, -0.05, 0.025
	local function S(x, y, lift) return Vector3.new(x, y, -math.sqrt(math.max(0, R * R - x * x - y * y)) - (lift or 0)) end
	local function N(p) return Vector3.new(p.X, p.Y, -math.sqrt(math.max(0, R * R - p.X * p.X - p.Y * p.Y))).Unit end
	local function normals(ring)
		local o = {}
		for i, p in ipairs(ring) do o[i] = N(p) end
		return o
	end
	tellipse(list, Vector3.new(0, 0, 0.012), Vector3.xAxis, Vector3.yAxis, 0.54, 0.54, 16, INK3, F)
	local aR = math.asin(y0 / R)                              -- the snow line meets the rim here and at pi - aR
	local up, lo = {}, {}
	for i = 0, 9 do
		local a = aR + (math.pi - 2 * aR) * i / 9
		up[#up + 1] = Vector3.new(R * math.cos(a), R * math.sin(a), 0)
	end
	for i = 0, 7 do
		local a = math.pi - aR + (math.pi + 2 * aR) * i / 7
		lo[#lo + 1] = Vector3.new(R * math.cos(a), R * math.sin(a), 0)
	end
	up[#up + 1], lo[#lo + 1] = S(0, y0), S(0, y0)              -- the snow line's middle, on the ball's curve
	local cu, cl = S(0, 0.2), S(0, -0.28)
	cfan(list, cu, N(cu), up, normals(up), MID3, true)
	cfan(list, cl, N(cl), lo, normals(lo), RIM3, true)
	local function star(cx, cy, r, pts, inner)
		local ring = {}
		for k = 0, 2 * pts - 1 do
			local rr = r * ((k % 2 == 0) and 1 or inner)
			local a = math.pi / 2 + math.pi * k / pts
			ring[#ring + 1] = S(cx + rr * math.cos(a), cy + rr * math.sin(a), LIFT)
		end
		local o = S(cx, cy, LIFT)
		cfan(list, o, N(o), ring, normals(ring), RIM3, true)
	end
	star(-0.06, 0.13, 0.2, 6, 0.45)
	star(0.22, 0.27, 0.085, 4, 0.35)
	local inner, outer = {}, {}
	for k = 0, 4 do
		local a = math.rad(118 + 34 * k / 4)
		local t = math.max(0.2, math.sin(math.pi * k / 4))
		outer[k] = S(0.42 * math.cos(a), 0.42 * math.sin(a), LIFT)
		inner[k] = S((0.42 - 0.08 * t) * math.cos(a), (0.42 - 0.08 * t) * math.sin(a), LIFT)
	end
	for k = 0, 3 do
		sface(list, { outer[k], outer[k + 1], inner[k + 1], inner[k] }, { N(outer[k]), N(outer[k + 1]), N(inner[k + 1]), N(inner[k]) }, RIM3, true)
	end
end
SG.GlobeTop = 0.78 + 0.54                                  -- the face's crown leads: the shot point

-- M1's hit: a thin triangular glass slab (its top the bright glint), and the small snow pile that settles
K.Slab3 = function(L)
	local list = L("toon")
	local a, b, h = 0.34, 0.26, 0.04
	local loc = { Vector3.new(0, 0, 0), Vector3.new(a, 0.06, 0), Vector3.new(0.3 * a, b, 0) }
	local top, bot = {}, {}
	for i, p in ipairs(loc) do top[i], bot[i] = p + Vector3.new(0, 0, h), p - Vector3.new(0, 0, h) end
	local cen = Vector3.new(0.43 * a, 0.35 * b, 0)
	tface(list, top, cen, RIM3)
	tface(list, bot, cen, LIGHT3)
	for i = 1, 3 do
		local j = i % 3 + 1
		tface(list, { bot[i], bot[j], top[j], top[i] }, cen)
	end
end
K.Pile3 = function(L)
	local list = L("toon")
	local top = Vector3.new(0, 0.26, 0)
	for k = 0, 5 do
		local p0 = Vector3.new(0.42 * math.cos(math.pi / 3 * k), 0, 0.42 * math.sin(math.pi / 3 * k))
		local p1 = Vector3.new(0.42 * math.cos(math.pi / 3 * (k + 1)), 0, 0.42 * math.sin(math.pi / 3 * (k + 1)))
		tface(list, { p0, p1, top }, Vector3.new(0, 0.05, 0), (k % 2 == 0) and RIM3 or LIGHT3)
	end
end

-- Cold Momentum, the icon's print: a white footprint -- an oval sole with a blue snowflake stamped in it and a small oval
-- heel -- each on a dark copy for its ink. Flat on the ground (+Y up), the toe toward -Z (the print frame's look)
K.Print3 = function(L)
	local list, U = L("toon"), Vector3.yAxis
	for _, lay in ipairs({ { 1.15, INK3, 0 }, { 1.0, RIM3, 0.006 } }) do
		tellipse(list, Vector3.new(0, lay[3], -0.2), Vector3.xAxis, Vector3.zAxis, 0.3 * lay[1], 0.6 * lay[1], 14, lay[2], U)
		tellipse(list, Vector3.new(0, lay[3], 0.78), Vector3.xAxis, Vector3.zAxis, 0.23 * lay[1], 0.2 * lay[1], 10, lay[2], U)
	end
	local c = Vector3.new(0, 0.012, -0.24)
	local core = {}
	for k = 0, 5 do core[k + 1] = c + Vector3.new(0.07 * math.cos(math.pi / 3 * k), 0, 0.07 * math.sin(math.pi / 3 * k)) end
	tface(list, core, nil, MID3, true, U)
	for k = 0, 5 do
		local a = math.pi / 3 * k + math.pi / 6
		local d, s = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
		tface(list, { c + d * 0.05 - s * 0.03, c + d * 0.2 - s * 0.03, c + d * 0.26, c + d * 0.2 + s * 0.03, c + d * 0.05 + s * 0.03 }, nil, DEEP3, true, U)
	end
end

-- STAGE 3 (pass 3): Blizzard, from the Q icon -- the rim (the curb, light: no lumps, no dots), big inked pines (tall and
-- short, each tier's upper half snow), and the flurry: wide white crescent streaks in banked tiers round the storm, heavier
-- toward the edge, none in the middle -- closed concentric arcs, never a spiral (Zephyr's shape)
for f = 0, 11 do
	K["BzRim" .. (f + 1)] = function(L)
		curbPart(L("toon"), SG.RefR, math.floor(f * BZ_N / 12), math.floor((f + 1) * BZ_N / 12), BZ_N, 1.6, 1.0)
	end
end
local function tpine(list, tiers, trunk)
	local function ring(r, y)
		local out = {}
		for k = 0, 5 do out[k + 1] = Vector3.new(r * math.cos(math.pi / 3 * k), y, r * math.sin(math.pi / 3 * k)) end
		return out
	end
	local b, t = ring(trunk[1], 0), ring(trunk[1], trunk[2])
	for k = 1, 6 do tface(list, { b[k], b[k % 6 + 1], t[k % 6 + 1], t[k] }, Vector3.new(0, trunk[2] / 2, 0), DEEP3) end
	for _, tr in ipairs(tiers) do
		local r, h, y = tr[1], tr[2], tr[3]
		local base, mid, apex = ring(r, y), ring(r * 0.5, y + h * 0.5), Vector3.new(0, y + h, 0)
		local c = Vector3.new(0, y + h * 0.3, 0)
		for k = 1, 6 do
			local j = k % 6 + 1
			tface(list, { base[k], base[j], mid[j], mid[k] }, c)
			tface(list, { mid[k], mid[j], apex }, c, RIM3)
		end
		tface(list, base, Vector3.new(0, y + 1, 0), DEEP3)
	end
end
K.PineT = function(L) tpine(L("toon"), { { 1.8, 2.0, 0.7 }, { 1.4, 1.8, 1.9 }, { 1.0, 1.6, 3.0 } }, { 0.24, 0.9 }) end
K.PineS = function(L) tpine(L("toon"), { { 1.5, 1.6, 0.6 }, { 1.1, 1.4, 1.6 } }, { 0.2, 0.7 }) end
SG.BzR = 32                                               -- the flurry is built at Blizzard's radius (CryoTuning.Blizzard.Radius)
K.Flurry = function(L)
	local list, R = L("toon"), SG.BzR
	local rnd = Random.new(9)
	for _, c in ipairs({ { 0.93, 2.6, 85, 0.55 }, { 0.88, 5.2, 80, 0.5 }, { 0.82, 7.8, 75, 0.45 }, { 0.95, 4.0, 70, 0.5 },
		{ 0.78, 10.2, 70, 0.4 }, { 0.9, 9.0, 72, 0.45 } }) do
		local a0 = rnd:NextNumber(0, 2 * math.pi)
		local bank = math.rad(28)
		local inner, outer = {}, {}
		for k = 0, 9 do
			local a = a0 + math.rad(c[3]) * k / 9
			local w = c[4] * math.max(0.12, math.sin(math.pi * k / 9))
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local mid = d * (R * c[1]) + Vector3.new(0, c[2], 0)
			local o = (d * math.cos(bank) + Vector3.new(0, math.sin(bank), 0))
			inner[k], outer[k] = mid - o * w, mid + o * w
		end
		for k = 0, 8 do
			local q = { inner[k], outer[k], outer[k + 1], inner[k + 1] }
			local n = (q[2] - q[1]):Cross(q[4] - q[1]).Unit
			tface(list, q, nil, RIM3, nil, n)
			tface(list, { q[1], q[4], q[3], q[2] }, nil, RIM3, nil, -n)
		end
	end
end

-- each toon kind's ink, in studs at scale 1 (as heavy as the icons' line at the 1v1 size). The M1's slab and pile have
-- none since the smoothing: a 0.03 line on a third of a stud was hairline, and its triangles pay for the round globe
local INK = { Ribs = 0.22, Outline = 0.22, Hero = 0.07, BodyFlake = 0.07, Dart3 = 0.1, Mote = 0.06, Dots = 0, Drift3 = 0.08,
	M1Body = 0.035, M1Face = 0, Slab3 = 0, Pile3 = 0, Print3 = 0, PineT = 0.1, PineS = 0.09, Flurry = 0.07 }
for f = 1, 12 do INK["BzRim" .. f] = 0.14 end
for f = 1, 6 do INK["Plinth" .. f] = 0.16 end
for f = 1, 12 do INK["Rim" .. f] = 0.14 end

local kinds = {}            -- [name] = { Layers = { { Mat, Part, Off, Size, T } ... }, Tris }
local LAYER_ORDER = { "toon", "ice", "glass", "dome", "snow", "soft", "flake", "line", "glint" }
SG.Tris = {}

local function buildKind(name)
	local lists = {}
	K[name](function(mat)
		lists[mat] = lists[mat] or {}
		return lists[mat]
	end)
	local k = { Layers = {}, Tris = 0 }
	for _, mat in ipairs(LAYER_ORDER) do
		local list = lists[mat]
		if list and #list > 0 then
			if mat == "toon" and (INK[name] or 0.1) > 0 then addHull(list, INK[name] or 0.1) end
			local p, off, n = meshPart(list)
			local m = MATS[mat]
			p.Name = "SnowGlobe" .. name
			p.Material, p.Transparency, p.Reflectance = m[1], m[2], m[3]
			k.Layers[#k.Layers + 1] = { Mat = mat, Part = p, Off = off, Size = p.Size, T = m[2] }
			k.Tris += n
		end
	end
	SG.Tris[name] = k.Tris
	kinds[name] = k
end

local ORDER = { "Ribs", "Outline", "Hero", "Dart3", "BodyFlake", "Mote", "Dots", "Drift3", "M1Body", "M1Face", "Slab3", "Pile3", "Print3", "Plinth1", "Plinth2", "Plinth3", "Plinth4",
	"Plinth5", "Plinth6", "Rim1", "Rim2", "Rim3", "Rim4", "Rim5", "Rim6", "Rim7", "Rim8", "Rim9", "Rim10", "Rim11", "Rim12", "PineT", "PineS", "Flurry", "BzRim1", "BzRim2", "BzRim3", "BzRim4", "BzRim5", "BzRim6",
	"BzRim7", "BzRim8", "BzRim9", "BzRim10", "BzRim11", "BzRim12" }
local building = false
function SG.Build()
	if building then return end
	building = true
	task.spawn(function()
		local t0 = os.clock()
		for _, name in ipairs(ORDER) do
			local ok, err = pcall(buildKind, name)
			if not ok then warn("[SnowGlobeKit] " .. name .. ": " .. tostring(err)) end
			task.wait()
		end
		SG.BuildTime = os.clock() - t0
		SG.Built = true
	end)
end

function SG.Kind(name)
	return kinds[name]
end

----------------------------------------------------------------------------------------------------
-- a piece: New(kind) -> { Kind, P = { layer parts } }; Place it at frame K, scale s (sy: an extra factor on Y);
-- Get / Put: the same through a per-kind pool (what spawns over and over: the M1's slabs and piles, prints, darts)
----------------------------------------------------------------------------------------------------
function SG.New(name, parent)
	local k = kinds[name]
	if not k then return nil end
	local o = { Kind = k, Name = name, P = {}, S = 1, SY = 1, F = -1 }
	for i, l in ipairs(k.Layers) do
		o.P[i] = l.Part:Clone()
		if parent then o.P[i].Parent = parent end
	end
	o.Body = o.P[1]                               -- the first layer: what CryoFX hangs a bolt's trail on
	return o
end

local pools = {}
local POOL_MAX = 40
function SG.Get(name, parent)
	local pool = pools[name]
	local o = pool and table.remove(pool)
	if o then
		for _, p in ipairs(o.P) do p.Parent = parent end
		return o
	end
	return SG.New(name, parent)
end
function SG.Put(o)
	if not o then return end
	local pool = pools[o.Name] or {}
	pools[o.Name] = pool
	if #pool >= POOL_MAX or not o.P[1] or not pcall(function() for _, p in ipairs(o.P) do p.Parent = nil end end) then
		SG.Drop(o)
		return
	end
	SG.Fade(o, 1)
	pool[#pool + 1] = o
end

function SG.Drop(o)
	if not o then return end
	for _, p in ipairs(o.P) do pcall(function() p:Destroy() end) end
	o.P = {}
end

--- 0 = as built, 1 = gone
function SG.Fade(o, f)
	if f == o.F then return end
	o.F = f
	for i, l in ipairs(o.Kind.Layers) do
		local p = o.P[i]
		if p then
			if l.Mat == "toon" then
				p.Transparency = (f >= 1) and 1 or 0       -- opaque: a toon piece goes by sinking or shrinking
			else
				p.Transparency = (f >= 1) and 1 or (l.T + (1 - l.T) * f)
			end
		end
	end
end

function SG.Place(o, K0, parts, cframes, s, sy)
	s, sy = s or 1, sy or 1
	local sv = Vector3.new(s, s * sy, s)
	local resize = s ~= o.S or sy ~= o.SY
	o.S, o.SY = s, sy
	for i, l in ipairs(o.Kind.Layers) do
		local p = o.P[i]
		if p then
			if resize then p.Size = l.Size * sv end
			parts[#parts + 1] = p
			cframes[#cframes + 1] = K0 * CFrame.new(l.Off * sv)
		end
	end
end

--- A kunai-style frame: base at `tail`, +Y along `dir`, X along `side` (made square to `dir`).
function SG.Frame(tail, dir, side)
	dir = dir.Unit
	local sd = side - dir * side:Dot(dir)
	if sd.Magnitude < 1e-3 then
		sd = Vector3.yAxis - dir * dir.Y
		if sd.Magnitude < 1e-3 then sd = Vector3.xAxis - dir * dir.X end
	end
	return CFrame.fromMatrix(tail, sd.Unit, dir)
end


----------------------------------------------------------------------------------------------------
-- Flash Freeze's rooted body (the developer, 2026-10-15: "snowflakes get over the body and it freezes you"): small flakes
-- all over it in a wave from the feet up, riding the body (CryoFX's freeze plumbing, "GlobeFF": the same spots and beat
-- as Frost Lotus's mini blooms); none on the head; the victim's own client draws none
----------------------------------------------------------------------------------------------------
local R6 = { UpperTorso = "Torso", LowerTorso = "Torso", RightUpperArm = "Right Arm", LeftUpperArm = "Left Arm",
	RightUpperLeg = "Right Leg", LeftUpperLeg = "Left Leg", RightLowerLeg = "Right Leg", LeftLowerLeg = "Left Leg" }
local function bodyPart(model, name)
	local p = model:FindFirstChild(name) or (R6[name] and model:FindFirstChild(R6[name]))
	return (p and p:IsA("BasePart")) and p or nil
end
local SPOTS = {
	{ "UpperTorso", "fw", 0.72, 0.25, 0.44 }, { "UpperTorso", "-fw", 0.0, 0.3, 0.5 }, { "RightUpperLeg", "fw", 0.1, 0.25, 0.4 },
	{ "LeftUpperArm", "fw", 0.0, 0.2, 0.38 }, { "UpperTorso", "fw", -0.72, 0.1, 0.44 }, { "LeftLowerLeg", "-fw", 0.0, 0.1, 0.34 },
	{ "RightUpperArm", "fw", 0.0, 0.1, 0.38 }, { "LowerTorso", "fw", 0.55, 0.0, 0.38 }, { "UpperTorso", "-fw", -0.55, -0.45, 0.4 },
	{ "LeftUpperLeg", "fw", -0.1, -0.1, 0.38 }, { "UpperTorso", "up", 0.78, 0.0, 0.36 }, { "LeftUpperLeg", "-rt", 0.0, 0.2, 0.38 },
	{ "RightLowerLeg", "fw", 0.0, 0.0, 0.32 }, { "UpperTorso", "up", -0.78, 0.0, 0.36 }, { "RightUpperArm", "rt", 0.0, 0.2, 0.34 },
	{ "LowerTorso", "-fw", 0.3, 0.0, 0.36 }, { "RightUpperLeg", "-fw", 0.0, -0.1, 0.34 }, { "LeftUpperArm", "-rt", 0.0, 0.0, 0.32 },
}
--- A flat frame: centre `c`, its face along `up`.
function SG.BloomFrame(c, up, yaw)
	up = up.Unit
	local x = up:Cross(math.abs(up.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis).Unit
	local f = CFrame.fromMatrix(c, x, up)
	return yaw and (f * CFrame.Angles(0, yaw, 0)) or f
end
function SG.BodyBlooms(model, n, t0)
	local torso = bodyPart(model, "UpperTorso")
	if not torso or n <= 0 then return {} end
	local head = model:FindFirstChild("Head")
	local Rc = torso.CFrame
	local W = { rt = Rc.RightVector, ["-rt"] = -Rc.RightVector, fw = Rc.LookVector, ["-fw"] = -Rc.LookVector, up = Rc.UpVector }
	local root = model:FindFirstChild("HumanoidRootPart")
	local feetY = root and (root.Position.Y - 3) or (torso.Position.Y - 3)
	local out = {}
	for _, sp in ipairs(SPOTS) do
		if #out >= n then break end
		local p = bodyPart(model, sp[1])
		if p then
			local cf, hs = p.CFrame, p.Size / 2
			local ax = { cf.RightVector * hs.X, cf.UpVector * hs.Y, cf.LookVector * -hs.Z }
			local want = W[sp[2]]
			local k, best = 1, -1
			for j = 1, 3 do
				local dd = math.abs(ax[j].Unit:Dot(want))
				if dd > best then k, best = j, dd end
			end
			local sg = (ax[k]:Dot(want) > 0) and 1 or -1
			local nrm = ax[k].Unit * sg
			local pt = cf.Position + ax[k] * sg
			for j = 1, 3 do
				if j ~= k then
					local rr, uu = ax[j]:Dot(W.rt), ax[j]:Dot(W.up)
					if math.abs(rr) >= math.abs(uu) then
						pt += ax[j] * (sp[3] * ((rr > 0) and 1 or -1))
					else
						pt += ax[j] * (sp[4] * ((uu > 0) and 1 or -1))
					end
				end
			end
			local R = sp[5] * 1.2
			if not head or (pt - head.Position).Magnitude >= 0.8 + R then
				local K0 = SG.BloomFrame(pt + nrm * 0.04, nrm, 0.5 * #out)
				out[#out + 1] = { Kind = "BodyFlake", Part = p, Rel = p.CFrame:ToObjectSpace(K0), S = R, Grow = true,
					Delay = (t0 or 0) + 0.03 + 0.3 * math.clamp((pt.Y - feetY) / 4.2, 0, 1), Dur = 0.2 }
			end
		end
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- THE M1's MINI GLOBE (VFXLibrary's shot): the disc is the shot's Body and the glass its Tip, placed by the shot; the
-- glowing band and the glass's camera-facing outline ride them here, after the shot has moved for the frame
----------------------------------------------------------------------------------------------------
local GLOBE_TOP = 0.98                 -- the glass's crown leads: the shot point
function SG.ShotLook()
	local b, f = kinds.M1Body, kinds.M1Face
	if not (b and f) then return nil end
	local bl, fl = b.Layers[1], f.Layers[1]
	local body, face = bl.Part:Clone(), fl.Part:Clone()
	local tip = Instance.new("Part")                  -- an invisible holder on the globe's centre (the glint rides it)
	tip.Size, tip.Transparency, tip.Anchored = Vector3.new(0.05, 0.05, 0.05), 1, true
	tip.CanCollide, tip.CanQuery, tip.CanTouch, tip.CastShadow, tip.Massless = false, false, false, false, true
	body.Name, tip.Name, face.Name = "IcicleShard", "IcicleShardTip", "SnowGlobeFace"
	local top = Vector3.new(0, SG.GlobeTop, 0)
	return {
		Body = body, Tip = tip, BodyT = 0, TipT = 1, BodyCentre = bl.Off - top, TipCentre = Vector3.new(0, 0.78, 0) - top,
		Edge = face, EdgeSize = fl.Size, EdgeOff = fl.Off, Length = SG.GlobeTop,
	}
end

--- the trail behind the globe (VFXLibrary's flecks emitter, these props in place of the shard's): short, hard-edged shards
function SG.TrailSnow()
	return {
		Texture = "rbxassetid://98211061341574", Color = ColorSequence.new(RIM3, LIGHT3), LightEmission = 0.1, LightInfluence = 0.5,
		Size = NumberSequence.new(0.22, 0.1),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.2, 0.32), Rate = 14, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -4, 0), Drag = 2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
		LockedToPart = false, Enabled = false,
	}
end

local riders = setmetatable({}, { __mode = "k" })
local riding = false
--- keep a shot look's band and outline on it (registered once; a pooled look keeps its riders)
function SG.Ride(look)
	riders[look] = true
	if riding then return end
	riding = true
	RunService:BindToRenderStep("SnowGlobeRiders", Enum.RenderPriority.Last.Value, function()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		for lk in pairs(riders) do
			local body, tip, face = lk.Body, lk.Tip, lk.Edge
			local live = body and body.Parent and tip and tip.Parent and body.Transparency < 1
			if live and face then
				local s = body.Size.X / lk.BodySize.X
				if face.Parent ~= body.Parent then face.Parent = body.Parent end
				face.Size = lk.EdgeSize * s
				face.Transparency = 0
				if camPos then face.CFrame = CFrame.lookAt(tip.Position, camPos) * CFrame.new((lk.EdgeOff or Vector3.zero) * s) end
			elseif face and face.Parent then
				face.Parent = nil
			end
		end
	end)
end

-- LAZY build (2026-10-17, as FrostDragonKit): only once a player in the server wears this skin, or -- in Studio -- a test
-- dummy stands in for it (StudioSkin). Every Cryo skin and wrap shares one EditableMesh budget per client; a kit nobody
-- in the server wears takes none of it (eager builds of all four overran it, and the worn skin fell back to the Default).
do
	local lazyStarted = false
	local function go()
		if lazyStarted then return end
		lazyStarted = true
		SG.Build()
	end
	local attr = SkinCatalog.ElementSkinAttr("Cryo")
	local function check(plr)
		if lazyStarted then return end
		local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Cryo")
		if ok and id == SG.Id then go() end
	end
	local function watch(plr)
		check(plr)
		plr:GetAttributeChangedSignal(attr):Connect(function() check(plr) end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
	Players.PlayerAdded:Connect(watch)
	if RunService:IsStudio() then
		local function dummy(m) if m:IsA("Model") and m:GetAttribute("StudioSkin") == SG.Id then go() end end
		for _, m in ipairs(workspace:GetChildren()) do dummy(m) end
		workspace.ChildAdded:Connect(function(m) task.defer(dummy, m) end)
	end
end
return SG
