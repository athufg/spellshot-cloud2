--[[
	FrostDragonKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/FrostDragonKit

	Cryo's FROST DRAGON skin (the Mythic, 2026-10-15; designed in Blender: vfx_blocking/cryo/cryo_frostdragon_skin_2026_10_15,
	fd_cp0.py -- one lean western dragon of glowing ice crystal across the kit, in Frost Lotus's luminous style). This module
	holds its meshes; FrostDragonFX the piece logic (through CryoFX's hooks, FBX.Dragon).
	  On(character)      whether that body's player wears it (SkinCatalog: ElementSkin_Cryo = "FrostDragon")
	  Pieces             the Mirror Cage dragon, cut into animatable pieces (FrostDragonData, exported by fd_export.py as
	                     outward-wound POLYGONS with a class each), built here into one MeshPart per material group:
	    Spine    the deep-blue spine row, the throat behind the trapped player, the dark crevices (sockets, the wings' rim
	             band): opaque, so the silhouette holds against a bright sky and the trapped body has a dark backdrop
	    Shell    the pale ice body (flanks to belly), see-through enough that the inner core glows from within; every
	             facet keeps flat light/dark bands and an inset rim on its HARD edges (white on the lit side, deep blue
	             on the shadow side)
	    Crystal  horns, spires, fangs, talons: pale crystal with the same rims
	    Mem      the wings' membranes: pale, translucent, both faces
	    Glow     Neon: the white-hot edge ribbons on the hard edges, the glowing joint bands, the bones, the veins and the
	             wings' snowflake etch, the eyes, the mouth, the forehead gem
	    Core     Neon, opaque, inside the Shell: the inner glow (bright toward the belly and the seams, dark under the spine)
	  New / Place / Fade / Drop   a piece (or the Plate / Bolt) in the world, as FrostLotusKit's
	Built per client from EditableMeshes, one at a time, copied into fixed-size ones -- LAZILY: once a player in the server
	wears the skin (always in Studio, for the test stage). Until built (or if the build fails), the Default draws.
	(Colour pass, 2026-10-16: pale luminous ice dominant, deep blue only on the spine, the throat and as shadow; SmoothPlastic,
	no Ice material -- its projected grain read as rough rock.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local FD = {}
FD.Id = "FrostDragon"

-- (2026-10-26) THE SHOWCASE CONVENTION: a client-only model no player owns, with the attribute ShowcaseSkin = "<SkinId>"
-- (the Loadout Altar's dummies, the pedestal's held M1), wears that skin -- live and in Studio. Every such model asked
-- about (On) or seen entering the workspace (the lazy block below) is kept here wherever it sits (the showcases parent
-- theirs in their own folders), so the lazy build, its release and the kill effect's watch count it until it leaves the
-- workspace.
local showcase = {}
--- whether `m` is a showcase stand-in wearing Frost Dragon (one wearing any skin is kept)
function FD.Showcase(m)
	local id = typeof(m) == "Instance" and m:GetAttribute("ShowcaseSkin")
	if type(id) ~= "string" or Players:GetPlayerFromCharacter(m) then return false end
	if not showcase[m] then                            -- (2026-10-26) pruned on insert: destroyed stand-ins don't pile up
		for k in pairs(showcase) do
			if not k:IsDescendantOf(workspace) then showcase[k] = nil end
		end
		showcase[m] = true
	end
	return id == FD.Id
end
--- the showcase stand-ins in the workspace wearing Frost Dragon now
function FD.Showcased()
	local out = {}
	for m in pairs(showcase) do
		if not m:IsDescendantOf(workspace) then
			showcase[m] = nil
		elseif m:GetAttribute("ShowcaseSkin") == FD.Id then
			out[#out + 1] = m
		end
	end
	return out
end

--- Whether `character`'s player wears Frost Dragon (their Cryo skin, while Cryo is their Element).
function FD.On(character)
	if typeof(character) ~= "Instance" then return false end
	local plr = Players:GetPlayerFromCharacter(character)
	-- (2026-10-26) a showcase stand-in (ShowcaseSkin), live too; it starts the build (FD.Build: one at a time)
	if not plr and FD.Showcase(character) then
		if not (FD.Built or FD.Failed) then FD.Build() end
		return true
	end
	-- Studio only: a dummy with StudioSkin stands in for a caster (the skins' side-by-side test); never live
	if not plr then return RunService:IsStudio() and character:GetAttribute("StudioSkin") == FD.Id end
	if (plr:GetAttribute("Element") or "Cryo") ~= "Cryo" then return false end
	return SkinCatalog.ElementSkin(plr, "Cryo") == FD.Id
end

function FD.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

if not RunService:IsClient() then
	return FD
end

----------------------------------------------------------------------------------------------------
-- the look: the shipped Cryo colours only (no gold, no pink, no pure #00FFFF). The Neon inputs are DIMMER than what
-- shows: Neon roughly doubles a colour and lifts its strongest channel (the repo's Azure Flame calibration), so a grey-blue
-- input shows as a pale white-cyan glow.
----------------------------------------------------------------------------------------------------
local function hex(h) return Color3.fromHex(h) end
FD.Look = {
	-- the body bands, by face class and light (lit / mid / shade)
	Spine = { hex("#2F7FD0"), hex("#2A72BC"), hex("#24609F") },
	Flank = { hex("#A9D8F8"), hex("#94CCF4"), hex("#7FBFF0") },
	Belly = { hex("#EEF9FF"), hex("#DFF4FF"), hex("#CBEAFB") },
	-- the head and jaw (seen against the sky): the same pale flanks, a deeper shadow band
	HeadFlank = { hex("#A9D8F8"), hex("#8CC6F2"), hex("#62A8E2") },
	Crystal = { hex("#EAF8FF"), hex("#CDEBFB"), hex("#A9D8F8") },
	SeamLift = hex("#F2FBFF"),                               -- a facet touching a joint, lifted toward white-hot
	-- the inset rims on the hard facet edges: white on the lit side, deep blue on the shadow side (the dark lines that hold
	-- the silhouette against a bright sky), a paler blue round the spine row
	Rim = hex("#F2FBFF"), ShadeRim = hex("#1F5A9E"), HeadShadeRim = hex("#14407F"), CrystalShadeRim = hex("#2F7FD0"),
	SpineRim = hex("#8FC4EE"),
	Crevice = hex("#14407F"), Membrane = hex("#CFEAFB"), WingBand = hex("#2F7FD0"),
	-- Neon inputs
	Edge = hex("#B4C4CC"), Joint = hex("#B8C8D0"), Bone = hex("#8A9CA8"), Vein = hex("#8A9CA8"), Etch = hex("#C4C8CC"),
	Eye = hex("#E0E0E0"), Mouth = hex("#8A9CA8"), Gem = hex("#B4C4CC"),
	CoreBelly = hex("#A8BCC6"), CoreFlank = hex("#7E98A4"), CoreSpine = hex("#22384A"), CoreSeam = hex("#B8C8D0"),
	-- the plates: self-lit pale crystal (Neon, a dim input that shows a soft pale white-cyan) with a brighter rim on both
	-- faces; white-hot on their bolt
	PlateRest = hex("#6E8A98"), PlateRim = hex("#B4C4CC"), PlateHot = hex("#C4C8CC"),
	-- (FX colours kept for the bolts and bursts)
	Line = hex("#3FE0FF"), LineHot = hex("#8DF3FF"), Glow = hex("#C8F6FF"),
	-- the material groups: Material, Transparency, Reflectance
	G = {
		Spine = { Enum.Material.SmoothPlastic, 0, 0.02 },
		Shell = { Enum.Material.SmoothPlastic, 0.3, 0.04 },
		Crystal = { Enum.Material.SmoothPlastic, 0.05, 0.06 },
		Mem = { Enum.Material.SmoothPlastic, 0.45, 0 },
		Glow = { Enum.Material.Neon, 0, 0 },
		Core = { Enum.Material.Neon, 0, 0 },
		PlateBody = { Enum.Material.Neon, 0, 0 },
		PlateRim = { Enum.Material.Neon, 0, 0 },
		Bolt = { Enum.Material.Neon, 0, 0 },
		-- stage 2: the M1 Wyrmling (the head and jaw reused from the cage dragon, small), Flash Freeze's claw and spines
		-- (self-lit: Neon over the banded vertex colours, Part.Color the dimming tint -- a spectral glow, not lit ice)
		WyrmBody = { Enum.Material.Neon, 0, 0 },
		WyrmGlow = { Enum.Material.Neon, 0, 0 },
		Crys = { Enum.Material.Neon, 0, 0 },
		Frost = { Enum.Material.SmoothPlastic, 0.15, 0.05 },          -- (Cold Momentum's claw prints)
	},
	-- per-piece transparency overrides: the head has no core behind its shell, so its translucency only showed sky
	PieceT = { head = { Shell = 0.12 }, jaw = { Shell = 0.12 },
		-- Flash Freeze's foot: glass-clear (players sealed inside it stay readable)
		claw = { Shell = 0.55, Spine = 0.5, Crystal = 0.3 } },
}
local L = FD.Look
local GROUPS = { "Spine", "Shell", "Crystal", "Mem", "Glow", "Core" }
-- the Neon groups never sit at a fractional transparency (see Fade)
local OPAQUE_GLOW = { Glow = true, Core = true, PlateBody = true, PlateRim = true, Bolt = true, WyrmGlow = true, WyrmBody = true,
	Crys = true }
local TINT = { WyrmBody = Color3.fromHex("#B4C4CC"), Crys = Color3.fromHex("#A4B6C0") }   -- (white-hot head; pale spines)   -- (Neon's dimming multipliers)
-- the build's knobs (studs). The bands' key light is from the SIDE (cage space: +Z toward the caster), so the faces the
-- caster sees split into lit, mid and shade bands instead of all reading lit.
local K = Vector3.new(-0.55, 0.75, 0.35).Unit
-- the inset facet rim: width, at most this share of the facet's inradius, only on HARD edges (a crease of at least this
-- angle, or an open end) -- the tube's nearly flat ring-to-ring seams get none, so the body reads as long crystal facets
local RIM = { W = 0.11, MaxFrac = 0.22, Cos = math.cos(math.rad(25)) }
local EDGE = { Cos = math.cos(math.rad(40)), Min = 0.6, MinHead = 1.2, W = 0.08, Lift = 0.02 }
local JOINT = { W = 0.13, Lift = 0.025 }          -- the glowing band round each open end (the seams between pieces)
local CORE = { Inset = 0.35, MaxFrac = 0.4, Pieces = { neck = true, head = true, jaw = true } }
local WINGBAND = 0.22
-- the throat: the far-side pieces' faces turned toward the caster (cage +Z) go deep blue and opaque -- the dark backdrop
-- behind the trapped player from the caster's eye (the pale throat had left a frozen body nothing to stand out against)
local THROAT = { Pieces = { neck = true, seg10 = true, seg01 = true }, Z = 0.4 }
-- the exported classes: 0 spine row, 1 flank, 2 lower flank / belly, 3 crystal, 4 bone, 5 socket, 6 membrane, 7 eye,
-- 8 vein, 9 mouth, 10 gem, 12 the wings' snowflake etch
local ICE = { [0] = true, [1] = true, [2] = true }
local FACETED = { [0] = true, [1] = true, [2] = true, [3] = true }

----------------------------------------------------------------------------------------------------
-- building: one resizable EditableMesh at a time, copied into a fixed-size one (FrostLotusKit's pattern); hard facets
----------------------------------------------------------------------------------------------------
-- (2026-10-19) the shared EditableMesh budget's order: this kit's meshes come first (MeshBudget)
local MeshBudget = require(script.Parent:WaitForChild("MeshBudget"))

local function retry(make)
	for i = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		if i % 8 == 1 then MeshBudget.MakeRoom() end       -- (refused: the optional holders let go of what they can;
		                                                  -- asked again every 2 s, as one still in use may be free by then)
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}
local templates = {}       -- every template MeshPart built (dropped with `keep` if the build fails)
--- a MeshPart of `tris` ({ a, b, c, colour }), centred on its box; and the box's centre. Leaks nothing on failure.
local function meshPart(tris)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, t in ipairs(tris) do
		for k = 1, 3 do lo, hi = lo:Min(t[k]), hi:Max(t[k]) end
	end
	local c = (lo + hi) / 2
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local cols, norms = {}, {}
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		for _, t in ipairs(tris) do
			local n = (t[2] - t[1]):Cross(t[3] - t[1])
			if n.Magnitude > 1e-9 then
				n = n.Unit
				local f = em:AddTriangle(em:AddVertex(t[1] - c), em:AddVertex(t[2] - c), em:AddVertex(t[3] - c))
				local key = t[4]:ToHex()
				local ci = cols[key]
				if not ci then ci = em:AddColor(t[4], 1) cols[key] = ci end
				em:SetFaceColors(f, { ci, ci, ci })
				local nk = string.format("%.3f,%.3f,%.3f", n.X, n.Y, n.Z)
				local ni = norms[nk]
				if not ni then ni = em:AddNormal(n) norms[nk] = ni end
				em:SetFaceNormals(f, { ni, ni, ni })
				if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
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
	em:Destroy()                                         -- (the resizable one, always: the project works under its cap)
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
	templates[#templates + 1] = mp
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Color = Color3.new(1, 1, 1)
	return mp, c
end

local function dress(mp, group, base)
	local m = L.G[group]
	mp.Material, mp.Transparency, mp.Reflectance = m[1], base or m[2], m[3]
	mp.Name = "FrostDragon" .. group
	if TINT[group] then mp.Color = TINT[group] end
end

local kinds = {}          -- [name] = { Parts = { { Part, Off, Group, Base } }, Pivot, ... }
FD.Tris = {}

--- a polygon's (Newell) normal and centroid
local function newell(ps)
	local n, c = Vector3.zero, Vector3.zero
	for i, a in ipairs(ps) do
		local b = ps[i % #ps + 1]
		n += Vector3.new((a.Y - b.Y) * (a.Z + b.Z), (a.Z - b.Z) * (a.X + b.X), (a.X - b.X) * (a.Y + b.Y))
		c += a
	end
	return n, c / #ps
end

local function band(set, d, odd)
	local col = (d >= 0.55) and set[1] or ((d >= 0.15) and set[2] or set[3])
	return odd and col:Lerp(set[3], 0.08) or col
end

local function ekey(a, b)
	return (a < b) and (a * 65536 + b) or (b * 65536 + a)
end

--- a flat ribbon along the edge a -> b, `w` wide into the polygon p (its normal p.N, centroid p.C), lifted off it
local function ribbon(put, g, a, b, p, w, lift, col)
	local ed = b - a
	if ed.Magnitude < 1e-6 then return end
	local t = p.N:Cross(ed.Unit)
	if t:Dot(p.C - a) < 0 then t = -t end
	local up = p.N * lift
	local A, B = a + up, b + up
	local C, D = b + t * w + up, a + t * w + up
	if (B - A):Cross(C - A):Dot(p.N) >= 0 then
		put(g, A, B, C, col)
		put(g, A, C, D, col)
	else
		put(g, A, C, B, col)
		put(g, A, D, C, col)
	end
end

local function buildPiece(name, d)
	local V, F, P = d.V, d.F, d.P
	local piv = Vector3.new(d.Pivot[1], d.Pivot[2], d.Pivot[3])
	local function vtx(i)
		local j = (i - 1) * 3
		return Vector3.new(V[j + 1], V[j + 2], V[j + 3])
	end
	-- the polygons
	local polys = {}
	do
		local i, k = 1, 1
		while i <= #F do
			local n = F[i]
			local idx = table.create(n)
			for q = 1, n do idx[q] = F[i + q] end
			local ps = table.create(n)
			for q = 1, n do ps[q] = vtx(idx[q]) end
			local nrm, c = newell(ps)
			polys[k] = { I = idx, Pts = ps, N = (nrm.Magnitude > 1e-9) and nrm.Unit or Vector3.yAxis, Area = nrm.Magnitude / 2,
				C = c, Cls = P[k] }
			i += n + 1
			k += 1
		end
	end
	local by = {}
	local function put(g, a, b, c, col)
		by[g] = by[g] or {}
		table.insert(by[g], { a, b, c, col })
	end
	local function fan(g, ps, col)
		for q = 2, #ps - 1 do put(g, ps[1], ps[q], ps[q + 1], col) end
	end
	-- the edges: which polygons share them (the faceted classes only; the membrane's two faces share vertices)
	local edges = {}
	for pi, p in ipairs(polys) do
		if FACETED[p.Cls] then
			for q = 1, #p.I do
				local a, b = p.I[q], p.I[q % #p.I + 1]
				local key = ekey(a, b)
				local e = edges[key]
				if not e then e = { A = a, B = b, Polys = {} } edges[key] = e end
				table.insert(e.Polys, pi)
			end
		end
	end
	local boundary = {}                                     -- vertices on an open end of the ICE mesh: the seams
	for _, e in pairs(edges) do
		if #e.Polys == 1 and ICE[polys[e.Polys[1]].Cls] then boundary[e.A], boundary[e.B] = true, true end
	end
	local isHead = (name == "head" or name == "jaw")
	local throat = THROAT.Pieces[name]
	local plain = (name == "claw")                       -- (Flash Freeze's foot: clear ice, no facet rims or edge lines but on its talons)
	-- the faces: banded colours, an inset rim on every HARD facet edge
	for pi, p in ipairs(polys) do
		local cls, ps = p.Cls, p.Pts
		local dl = p.N:Dot(K)
		local odd = (pi % 2 == 0)
		if FACETED[cls] then
			local deep = (cls == 0) or (throat and ICE[cls] and p.N.Z > THROAT.Z)
			local set, g, rimCol
			if cls == 3 then
				set, g = L.Crystal, "Crystal"
				rimCol = (dl < 0.15) and L.CrystalShadeRim or L.Rim
			elseif deep then
				set, g, rimCol = L.Spine, "Spine", L.SpineRim
			else
				set = (cls == 1) and (isHead and L.HeadFlank or L.Flank) or L.Belly
				g = "Shell"
				rimCol = (dl < 0.15) and (isHead and L.HeadShadeRim or L.ShadeRim) or L.Rim
			end
			local col = band(set, dl, odd)
			if g == "Shell" then                             -- a facet at a joint glows a little brighter
				for _, i in ipairs(p.I) do
					if boundary[i] then col = col:Lerp(L.SeamLift, 0.35) break end
				end
			end
			-- the inradius (from the centroid), so the rim never eats a small facet
			local rin = math.huge
			for q = 1, #ps do
				local a, b = ps[q], ps[q % #ps + 1]
				local e = b - a
				if e.Magnitude > 1e-6 then
					local t = math.clamp((p.C - a):Dot(e) / e:Dot(e), 0, 1)
					rin = math.min(rin, (a + e * t - p.C).Magnitude)
				end
			end
			local w = plain and 0 or math.min(RIM.W, RIM.MaxFrac * rin)
			-- each edge's rim width: w on a hard edge (a crease of RIM.Cos or more, or an open end), 0 on a soft one
			local ws, any = table.create(#ps), false
			for q = 1, #ps do
				local e = edges[ekey(p.I[q], p.I[q % #ps + 1])]
				local hard = true
				if e and #e.Polys == 2 then
					local o = polys[(e.Polys[1] == pi) and e.Polys[2] or e.Polys[1]]
					hard = p.N:Dot(o.N) <= RIM.Cos or (FACETED[o.Cls] and (o.Cls == 3) ~= (cls == 3))
				end
				ws[q] = hard and w or 0
				any = any or hard
			end
			local inner, okInset = nil, any and w >= 0.015
			if okInset then
				inner = table.create(#ps)
				for q = 1, #ps do
					local qp = (q - 2) % #ps + 1
					local prev, cur, nxt = ps[qp], ps[q], ps[q % #ps + 1]
					local e1, e2 = cur - prev, nxt - cur
					if e1.Magnitude < 1e-6 or e2.Magnitude < 1e-6 then okInset = false break end
					local in1, in2 = p.N:Cross(e1.Unit), p.N:Cross(e2.Unit)
					local w1, w2 = ws[qp], ws[q]
					local c = in1:Dot(in2)
					local dv
					if 1 - c * c < 1e-4 then
						dv = in1 * math.max(w1, w2)
					else
						-- the offset meeting both edges' rims: d.in1 = w1, d.in2 = w2
						dv = in1 * ((w1 - c * w2) / (1 - c * c)) + in2 * ((w2 - c * w1) / (1 - c * c))
					end
					if dv.Magnitude > 4 * w then okInset = false break end
					inner[q] = cur + dv
				end
			end
			if okInset then
				fan(g, inner, col)
				for q = 1, #ps do
					if ws[q] > 0 then
						local q2 = q % #ps + 1
						put(g, ps[q], ps[q2], inner[q2], rimCol)
						put(g, ps[q], inner[q2], inner[q], rimCol)
					end
				end
			else
				fan(g, ps, col)
			end
		elseif cls == 4 then
			fan("Glow", ps, L.Bone)
		elseif cls == 5 then
			fan("Spine", ps, L.Crevice)
		elseif cls == 6 then
			fan("Mem", ps, L.Membrane)
		elseif cls == 7 then
			fan("Glow", ps, L.Eye)
		elseif cls == 8 then
			fan("Glow", ps, L.Vein)
		elseif cls == 9 then
			fan("Glow", ps, L.Mouth)
		elseif cls == 10 then
			fan("Glow", ps, L.Gem)
		elseif cls == 12 then
			fan("Glow", ps, L.Etch)
		else
			fan("Shell", ps, L.Flank[2])
		end
	end
	-- the white-hot edges: a V of Neon ribbon along every hard edge between two ice facets or two crystal facets
	local minLen = isHead and EDGE.MinHead or EDGE.Min
	local nEdge = 0
	for _, e in pairs(edges) do
		if #e.Polys == 2 then
			local p1, p2 = polys[e.Polys[1]], polys[e.Polys[2]]
			local same = (ICE[p1.Cls] and ICE[p2.Cls]) or (p1.Cls == 3 and p2.Cls == 3)
			if same and p1.N:Dot(p2.N) <= EDGE.Cos and not (plain and p1.Cls ~= 3) then
				local a, b = vtx(e.A), vtx(e.B)
				if (b - a).Magnitude >= minLen then
					nEdge += 1
					ribbon(put, "Glow", a, b, p1, EDGE.W, EDGE.Lift, L.Edge)
					ribbon(put, "Glow", a, b, p2, EDGE.W, EDGE.Lift, L.Edge)
				end
			end
		elseif #e.Polys == 1 and ICE[polys[e.Polys[1]].Cls] then
			-- an open end: the joint to the next piece, a glowing band round it (the seams glow from within)
			ribbon(put, "Glow", vtx(e.A), vtx(e.B), polys[e.Polys[1]], JOINT.W, JOINT.Lift, L.Joint)
		end
	end
	-- the inner core: the ICE body pulled in along its vertex normals, Neon. The inset never passes 40% of the way to
	-- the piece's axis (its keyhole capsules), so a thin tail tip keeps its core inside.
	if name:match("^seg%d+$") or CORE.Pieces[name] then
		local caps = {}
		for _, c in ipairs(d.Caps or {}) do
			caps[#caps + 1] = { Vector3.new(c[1], c[2], c[3]) - piv, Vector3.new(c[4], c[5], c[6]) - piv }
		end
		local function axisDist(v)
			local best = math.huge
			for _, c in ipairs(caps) do
				local ab = c[2] - c[1]
				local t = (ab:Dot(ab) > 1e-9) and math.clamp((v - c[1]):Dot(ab) / ab:Dot(ab), 0, 1) or 0
				best = math.min(best, (c[1] + ab * t - v).Magnitude)
			end
			return best
		end
		local vn = {}
		for _, p in ipairs(polys) do
			if ICE[p.Cls] then
				for _, i in ipairs(p.I) do vn[i] = (vn[i] or Vector3.zero) + p.N * p.Area end
			end
		end
		local moved = {}
		for _, p in ipairs(polys) do
			if ICE[p.Cls] and not (throat and p.N.Z > THROAT.Z) then
				local seam = false
				local ps = table.create(#p.I)
				for q, i in ipairs(p.I) do
					local cv = moved[i]
					if not cv then
						local v = vtx(i)
						local n = vn[i]
						local inset = math.min(CORE.Inset, CORE.MaxFrac * axisDist(v))
						cv = v - ((n and n.Magnitude > 1e-6) and n.Unit or p.N) * inset
						moved[i] = cv
					end
					ps[q] = cv
					if boundary[i] then seam = true end
				end
				local col = (p.Cls == 0) and L.CoreSpine or ((p.Cls == 1) and L.CoreFlank or L.CoreBelly)
				if seam then col = col:Lerp(L.CoreSeam, 0.35) end
				fan("Core", ps, col)
			end
		end
	end
	-- the wings: a deep-blue band round the membrane's outline (both faces), so the wing holds against the sky
	if name == "wingO" or name == "wingI" then
		local mem = {}
		for _, p in ipairs(polys) do if p.Cls == 6 then mem[#mem + 1] = p end end
		local use = {}
		for _, p in ipairs(mem) do
			for q = 1, #p.I do
				local key = ekey(p.I[q], p.I[q % #p.I + 1])
				use[key] = (use[key] or 0) + 1
			end
		end
		for _, p in ipairs(mem) do
			for q = 1, #p.I do
				local a, b = p.I[q], p.I[q % #p.I + 1]
				if use[ekey(a, b)] == 2 then              -- (each face of the two-sided membrane uses an outline edge once)
					ribbon(put, "Spine", vtx(a), vtx(b), p, WINGBAND, 0.03, L.WingBand)
				end
			end
		end
	end
	local k = { Parts = {}, Pivot = piv, Caps = d.Caps, Tris = d.Tris, Edges = nEdge }
	local total = 0
	local over = L.PieceT[name] or {}
	for _, g in ipairs(GROUPS) do
		if by[g] then
			local mp, c = meshPart(by[g])
			local base = over[g] or L.G[g][2]
			dress(mp, g, base)
			k.Parts[#k.Parts + 1] = { Part = mp, Off = c, Group = g, Size = mp.Size, Base = base }
			total += #by[g]
		end
	end
	FD.Tris[name] = total
	kinds[name] = k
end

--- the plate: a hexagonal crystal plate, unit length (X), width (Z) and height (Y, its point up): a self-lit pale body
--- (Neon; white vertex colours both sides, so Part.Color is its one tint) and a brighter rim band on BOTH faces, so the
--- rim reads from the caster's low angle too
local function buildPlate()
	local rim = {}
	for k = 0, 5 do
		local a = math.pi * k / 3
		rim[k] = Vector3.new(0.5 * math.cos(a), 0, 0.5 * math.sin(a))
	end
	local top, bot = Vector3.new(0, 1, 0), Vector3.new(0, -0.35, 0)
	local white = Color3.new(1, 1, 1)
	local body, ring = {}, {}
	for k = 0, 5 do
		local j = (k + 1) % 6
		body[#body + 1] = { rim[k], top, rim[j], white }
		body[#body + 1] = { rim[j], bot, rim[k], white }
		for _, apex in ipairs({ top, bot }) do
			local a0, b0 = (apex == top) and rim[k] or rim[j], (apex == top) and rim[j] or rim[k]
			local n = (apex - a0):Cross(b0 - a0).Unit
			local lift = n * 0.012
			local a, b = a0 + lift, b0 + lift
			local c, dd = b0:Lerp(apex, 0.18) + lift, a0:Lerp(apex, 0.18) + lift
			ring[#ring + 1] = { a, c, b, white }
			ring[#ring + 1] = { a, dd, c, white }
		end
	end
	local mb, cb = meshPart(body)
	dress(mb, "PlateBody")
	mb.Color = L.PlateRest
	local mr, cr = meshPart(ring)
	dress(mr, "PlateRim")
	mr.Color = L.PlateRim
	kinds.Plate = { Parts = { { Part = mb, Off = cb, Group = "PlateBody", Size = mb.Size, Base = 0 },
		{ Part = mr, Off = cr, Group = "PlateRim", Size = mr.Size, Base = 0 } }, Pivot = Vector3.zero }
	FD.Tris.Plate = #body + #ring
end

local function buildBolt()
	-- a long narrow crystal along +Y, white-hot
	local rim = {}
	for k = 0, 5 do
		local a = math.pi * k / 3
		rim[k] = Vector3.new(0.225 * math.sin(a), 0.9 * math.cos(a), 0)
	end
	local f, b = Vector3.new(0, 0, 0.15), Vector3.new(0, 0, -0.1)
	local tris = {}
	for k = 0, 5 do
		local j = (k + 1) % 6
		tris[#tris + 1] = { rim[k], f, rim[j], Color3.new(1, 1, 1) }
		tris[#tris + 1] = { rim[j], b, rim[k], hex("#C0D0DC") }
	end
	local mp, c = meshPart(tris)
	dress(mp, "Bolt")
	mp.Color = L.PlateRest:Lerp(L.PlateHot, 0.6)
	kinds.Bolt = { Parts = { { Part = mp, Off = c, Group = "Bolt", Size = mp.Size, Base = 0 } }, Pivot = Vector3.zero }
	FD.Tris.Bolt = #tris
end

----------------------------------------------------------------------------------------------------
-- STAGE 2 pieces (2026-10-16)
--   WyrmHead / WyrmJaw   the M1 Frost Wyrmling: the cage dragon's own head and jaw (FrostDragonData), shrunk to
--                        WYRM.Len studs and stripped of their tiny polygons (the teeth, the small scales: invisible at
--                        that size; ~520 tris). Local frame: the snout tip at the origin, +Y forward, +X the jaw's hinge
--                        axis, -Z up. The jaw is built open (the cage pose); WYRM.Close shuts it.
--   WyrmSeg              a body segment: a long hex crystal along +Y
--   Claw                 Flash Freeze's slam: a palm and four curved talons, +Y up, talons reaching -Z
--   Spine                a tall hex crystal spire along +Y, its foot at the origin
----------------------------------------------------------------------------------------------------
FD.Wyrm = { Len = 2.8, Close = math.rad(-26), Open = math.rad(18), OpenAt = 0.11, MinArea = 1.0 }
local GLOWCLS = { [7] = L.Eye, [8] = L.Vein, [9] = L.Mouth, [10] = L.Gem }

local function wyrmPart(name, polys, frame, s, glowToo)
	-- polys: { { Pts (cage), Cls } }; frame: the head's local frame in cage space; s: the scale
	local body, glow = {}, {}
	for _, p in ipairs(polys) do
		local ps = {}
		for q, v in ipairs(p.Pts) do ps[q] = frame:PointToObjectSpace(v) * s end
		local n = newell(ps)
		if n.Magnitude > 1e-9 then
			n = n.Unit
			local dl = frame:VectorToWorldSpace(n):Dot(K)
			local col = GLOWCLS[p.Cls]
			local into = body
			if col and glowToo then
				into = glow
			elseif col then
				col = L.Glow
			elseif p.Cls == 3 then
				col = band(L.Crystal, dl, false)
			elseif p.Cls == 5 then
				col = L.Crevice
			elseif p.Cls == 0 then
				col = band(L.Spine, dl, false)
			else
				col = band((p.Cls == 1) and L.HeadFlank or L.Belly, dl, false)
			end
			for q = 2, #ps - 1 do into[#into + 1] = { ps[1], ps[q], ps[q + 1], col } end
		end
	end
	local parts = {}
	local mb, cb = meshPart(body)
	dress(mb, "WyrmBody")
	parts[1] = { Part = mb, Off = cb, Group = "WyrmBody", Size = mb.Size, Base = 0 }
	if #glow > 0 then
		local mg, cg = meshPart(glow)
		dress(mg, "WyrmGlow")
		parts[2] = { Part = mg, Off = cg, Group = "WyrmGlow", Size = mg.Size, Base = 0 }
	end
	kinds[name] = { Parts = parts, Pivot = Vector3.zero }
	FD.Tris[name] = #body + #glow
end

--- a crystal along +Y: `sides` around, through `rings` = { { y, r } ... } (r 0 = a point); bands lit on the +X/-Z
local function crystal(sides, rings, flat, set)
	local tris = {}
	local function at(y, r, k)
		local a = 2 * math.pi * k / sides
		return Vector3.new(r * math.cos(a), y, r * math.sin(a) * (flat or 1))
	end
	for i = 1, #rings - 1 do
		local y0, r0, y1, r1 = rings[i][1], rings[i][2], rings[i + 1][1], rings[i + 1][2]
		for k = 0, sides - 1 do
			local a, b, c, d = at(y0, r0, k), at(y0, r0, k + 1), at(y1, r1, k + 1), at(y1, r1, k)
			local n = (c - a):Cross(b - a)
			local col = band(set, (n.Magnitude > 1e-9 and n.Unit or Vector3.yAxis):Dot(K), k % 2 == 1)
			if r0 > 0 then tris[#tris + 1] = { a, c, b, col } end
			if r1 > 0 then tris[#tris + 1] = { a, d, c, col } end
		end
	end
	return tris
end

local function buildStage2(data)
	-- the head's frame (cage space): origin the snout tip, +Y forward (the head capsule, back to tip), +X the hinge axis
	local hp, jp = data.Pieces.head, data.Pieces.jaw
	local cap = hp.Caps[1]
	local back, tip = Vector3.new(cap[1], cap[2], cap[3]), Vector3.new(cap[4], cap[5], cap[6])
	local fwd = (tip - back).Unit
	local ax = Vector3.new(data.JawAxis[1], data.JawAxis[2], data.JawAxis[3])
	ax = (ax - fwd * ax:Dot(fwd)).Unit
	local function polysOf(d)
		local piv = Vector3.new(d.Pivot[1], d.Pivot[2], d.Pivot[3])
		local out, i, k = {}, 1, 1
		while i <= #d.F do
			local n = d.F[i]
			local ps = {}
			for q = 1, n do
				local j = (d.F[i + q] - 1) * 3
				ps[q] = Vector3.new(d.V[j + 1], d.V[j + 2], d.V[j + 3]) + piv
			end
			local nn = newell(ps)
			if nn.Magnitude / 2 >= FD.Wyrm.MinArea or GLOWCLS[d.P[k]] then out[#out + 1] = { Pts = ps, Cls = d.P[k] } end
			i += n + 1
			k += 1
		end
		return out
	end
	local hpolys, jpolys = polysOf(hp), polysOf(jp)
	-- the snout's furthest point along fwd is the tip
	local far = -math.huge
	for _, p in ipairs(hpolys) do for _, v in ipairs(p.Pts) do far = math.max(far, (v - back):Dot(fwd)) end end
	local near = math.huge
	for _, p in ipairs(hpolys) do for _, v in ipairs(p.Pts) do near = math.min(near, (v - back):Dot(fwd)) end end
	local frame = CFrame.fromMatrix(back + fwd * far, ax, fwd)
	local s = FD.Wyrm.Len / math.max(far - near, 1e-3)
	wyrmPart("WyrmHead", hpolys, frame, s, true)
	wyrmPart("WyrmJaw", jpolys, frame, s, false)
	FD.Wyrm.Hinge = frame:PointToObjectSpace(Vector3.new(jp.Pivot[1], jp.Pivot[2], jp.Pivot[3])) * s
	-- a body segment, the claw, the spine
	local seg = crystal(6, { { -0.36, 0 }, { -0.14, 0.24 }, { 0.16, 0.21 }, { 0.36, 0 } }, 0.8, L.Flank)
	local m, c = meshPart(seg)
	dress(m, "WyrmBody")
	kinds.WyrmSeg = { Parts = { { Part = m, Off = c, Group = "WyrmBody", Size = m.Size, Base = 0 } }, Pivot = Vector3.zero }
	FD.Tris.WyrmSeg = #seg
	local claw = crystal(6, { { 0.2, 0.7 }, { 0.6, 1.1 }, { 1.2, 0.95 }, { 1.6, 0 } }, 0.55, L.Flank)
	for t = 0, 3 do
		local a = math.rad(-66 + 44 * t)
		local root = CFrame.new(0.95 * math.sin(a), 0.75, -0.95 * math.cos(a)) * CFrame.Angles(0, -a, 0)
		local tal = crystal(5, { { 0, 0.3 }, { 1.1, 0.24 }, { 2.2, 0.14 }, { 3.0, 0 } }, 1, L.Crystal)
		for _, tr in ipairs(tal) do
			-- each talon reaches out (-Z) and curves down onto the ground: bend by its length
			local function bend(v)
				local h = math.max(v.Y, 0)
				local bent = CFrame.Angles(-math.rad(62) - h * 0.36, 0, 0) * Vector3.new(v.X, v.Y, v.Z)
				return root * bent
			end
			claw[#claw + 1] = { bend(tr[1]), bend(tr[2]), bend(tr[3]), tr[4] }
		end
	end
	-- a short stretch of forearm above the palm (its open top end fades into mist: the FX)
	for _, tr in ipairs(crystal(6, { { 1.4, 0.9 }, { 3.0, 0.78 }, { 4.6, 0.62 } }, 0.6, L.Flank)) do claw[#claw + 1] = tr end
	m, c = meshPart(claw)
	dress(m, "Crys")
	kinds.Claw = { Parts = { { Part = m, Off = c, Group = "Crys", Size = m.Size, Base = L.G.Crys[2] } }, Pivot = Vector3.zero }
	FD.Tris.Claw = #claw
	local spine = crystal(6, { { 0, 0.5 }, { 0.35, 0.55 }, { 2.4, 0.3 }, { 4.2, 0.08 }, { 4.6, 0 } }, 1, L.Crystal)
	for _, tr in ipairs(spine) do                                   -- (its tip white-hot)
		if (tr[1].Y + tr[2].Y + tr[3].Y) / 3 > 2.9 then tr[4] = L.Rim end
	end
	m, c = meshPart(spine)
	dress(m, "Crys")
	kinds.Spine = { Parts = { { Part = m, Off = c, Group = "Crys", Size = m.Size, Base = L.G.Crys[2] } }, Pivot = Vector3.zero }
	FD.Tris.Spine = #spine
end

--- Cold Momentum's claw print: three talon gouges fanned forward (+Z) and a pad, flat on the ground (+Y up)
local function buildPrint()
	local tris = {}
	local pale, edge = L.Belly[1], L.SpineRim
	for i = -1, 1 do
		local a = math.rad(24 * i)
		local f, r = Vector3.new(math.sin(a), 0, math.cos(a)), Vector3.new(math.cos(a), 0, -math.sin(a))
		local b, m, t = f * 0.35, f * 0.85, f * 1.35
		local y = Vector3.new(0, 0.04, 0)
		local L1, R1 = m - r * 0.12 + y, m + r * 0.12 + y
		tris[#tris + 1] = { b + y, R1, L1, edge }
		tris[#tris + 1] = { L1, R1, t + y, pale }
	end
	for k = 0, 5 do
		local a0, a1 = math.pi * k / 3, math.pi * (k + 1) / 3
		tris[#tris + 1] = { Vector3.new(0, 0.05, 0), Vector3.new(0.3 * math.cos(a1), 0.03, 0.3 * math.sin(a1)),
			Vector3.new(0.3 * math.cos(a0), 0.03, 0.3 * math.sin(a0)), pale }
	end
	local m, c = meshPart(tris)
	dress(m, "Frost")
	kinds.Print = { Parts = { { Part = m, Off = c, Group = "Frost", Size = m.Size, Base = L.G.Frost[2] } }, Pivot = Vector3.zero }
	FD.Tris.Print = #tris
end

--- the trail's scale chips (VFXLibrary.emitter props): a few small pale angular chips shed behind the Wyrmling
function FD.TrailChips()
	return {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(L.Rim, L.Flank[1]),
		LightEmission = 0.4, LightInfluence = 0.4, Size = NumberSequence.new(0.14, 0.04),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.3),
			NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.18, 0.3), Rate = 10, Speed = NumberRange.new(0.4, 1.2), SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, -3, 0), Drag = 2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260),
		LockedToPart = false, Enabled = false,
	}
end

--- the M1 shot's look (VFXLibrary's acquireShardLook, "dragon"): an invisible holder Body at the point and an invisible
--- Tip (VFXLibrary moves them and hangs the trail, glint, wake and chips on them); the Wyrmling itself rides them (Ride)
function FD.ShotLook()
	if not (FD.Built and kinds.WyrmHead) then return nil end
	local function holder(name)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Transparency = name, Vector3.new(0.05, 0.05, 0.05), 0.99
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
		return p
	end
	return { Body = holder("IcicleShard"), Tip = holder("IcicleShardTip"), BodyT = 0.99, TipT = 1,
		BodyCentre = Vector3.zero, TipCentre = Vector3.zero }
end

-- the riders: every live Wyrmling's head, jaw and segments, placed each frame from its holder (the head along the flight,
-- level; the segments along the holder's recent path, undulating)
local riders = setmetatable({}, { __mode = "k" })
local riding = false
local SEG = { N = 4, Gap = 0.8, Scale = { 1.3, 1.12, 0.94, 0.74 }, Sway = 0.22 }
function FD.Ride(look)
	if riders[look] or not kinds.WyrmHead then return end
	look.Wyrm = { Head = FD.New("WyrmHead"), Jaw = FD.New("WyrmJaw"), Segs = {}, Hist = {} }
	for i = 1, SEG.N do look.Wyrm.Segs[i] = FD.New("WyrmSeg") end
	riders[look] = true
	if riding then return end
	riding = true
	RunService:BindToRenderStep("FrostDragonRiders", Enum.RenderPriority.Last.Value, function()
		local now = os.clock()
		local parts, cfs = {}, {}
		for lk in pairs(riders) do
			local w, body = lk.Wyrm, lk.Body
			local alive = body and body.Parent and body.Transparency < 1
			local all = { w.Head, w.Jaw, table.unpack(w.Segs) }
			if alive then
				if w.Head.Parts[1].Part.Parent ~= body.Parent then
					for _, o in ipairs(all) do FD.Parent(o, body.Parent) end
				end
				local h = w.Hist
				if not h[1] or (h[1] - body.Position).Magnitude > 0.04 then
					table.insert(h, 1, body.Position)
					if #h > 40 then h[#h] = nil end
				end
				local fw = body.CFrame.UpVector
				local up = (math.abs(fw.Y) < 0.95) and Vector3.yAxis or body.CFrame.LookVector
				local rt = up:Cross(fw).Unit
				local cf = CFrame.fromMatrix(body.Position, rt, fw)
				FD.Place(w.Head, cf, parts, cfs)
				if not w.Born then                       -- a new flight: a longer, brighter trail, white-hot to ice cyan
					w.Born = now
					pcall(function()
						lk.Trail.Lifetime, lk.Trail.Color = 0.3, ColorSequence.new(Color3.new(1, 1, 1), L.LineHot)
						lk.Trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
						lk.A0.Position = Vector3.new(0.32, -FD.Wyrm.Len * 0.6, 0)
						lk.A1.Position = Vector3.new(-0.32, -FD.Wyrm.Len * 0.6, 0)
					end)
				end
				-- the jaw: nearly shut, then wide open for the last third of the flight (HitBloom snaps it shut)
				local open = math.clamp((now - w.Born - FD.Wyrm.OpenAt) / 0.05, 0, 1)
				local jawA = FD.Wyrm.Close * 0.6 * (1 - open) + FD.Wyrm.Open * open
				local hinge = FD.Wyrm.Hinge
				FD.Place(w.Jaw, cf * CFrame.new(hinge) * CFrame.Angles(jawA, 0, 0) * CFrame.new(-hinge), parts, cfs)
				-- the segments: along the path, behind the head, swaying side to side
				for i, o in ipairs(w.Segs) do
					local want, acc, at, dirv = FD.Wyrm.Len * 0.85 + SEG.Gap * i, 0, nil, fw
					local p0 = body.Position
					for j = 1, #h do
						local d = (h[j] - p0).Magnitude
						if d > 1e-4 and acc + d >= want then
							at = p0 + (h[j] - p0) * ((want - acc) / d)
							dirv = (p0 - h[j]).Unit
							break
						end
						acc += d
						p0 = h[j]
					end
					if at then
						local sway = rt * (math.sin(now * 18 - i * 1.4) * SEG.Sway * (0.6 + 0.2 * i))
						local srt = up:Cross(dirv)
						srt = (srt.Magnitude > 1e-3) and srt.Unit or rt
						FD.Place(o, CFrame.fromMatrix(at + sway, srt, dirv), parts, cfs, SEG.Scale[i])
						FD.Fade(o, 0)
					else
						FD.Fade(o, 1)
					end
				end
				FD.Fade(w.Head, 0)
				FD.Fade(w.Jaw, 0)
			elseif w.Head.Parts[1].Part.Parent then
				w.Born = nil
				table.clear(w.Hist)
				for _, o in ipairs(all) do FD.Parent(o, nil) end
			end
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	end)
end

--- Flash Freeze's Default floor, ring and cracks lifted to the pale palette (VFXLibrary calls this each frame for a Frost
--- Dragon caster): saturated blues / cyans move toward pale ice, Neon lines toward white-hot. Cached, so it never compounds.
local graded = setmetatable({}, { __mode = "k" })
local PALE, WHITE = hex("#DFF4FF"), Color3.new(1, 1, 1)
function FD.GradeFF(folder)
	for _, p in ipairs(folder:GetDescendants()) do
		local isPart, isDecal = p:IsA("BasePart"), p:IsA("Decal")
		if (isPart and not p.Name:find("^FrostDragon")) or isDecal then
			local c = isPart and p.Color or p.Color3
			local g = graded[p]
			if not g or c ~= g.Set then
				-- (2026-10-19) a wrap's glow can tint a decal past 1 (Sakura Frost): read the hue of it clamped, so ToHSV does not warn
				local h, s = Color3.new(math.min(c.R, 1), math.min(c.G, 1), math.min(c.B, 1)):ToHSV()
				local set = c
				if s > 0.25 and h > 0.45 and h < 0.7 then          -- a saturated blue / cyan
					set = c:Lerp((isPart and p.Material == Enum.Material.Neon) and WHITE or PALE, isDecal and 0.5 or 0.65)
				end
				graded[p] = { Set = set }
				if set ~= c then
					if isPart then p.Color = set else p.Color3 = set end
				end
			end
		end
	end
end

local building = false
local attempts = 0                -- builds tried: a failed one is tried again later, a few times
local usedAt = 0                  -- the last New / Place / Get (a kit nobody wears lets go of its meshes, below)
local releaseHooks = {}           -- the pools of this kit's pieces elsewhere (OnRelease): emptied with it
function FD.OnRelease(fn) releaseHooks[#releaseHooks + 1] = fn end
local wanted = function() return true end   -- whether anybody here still wears the skin (the lazy block's, below)
function FD.Build()
	if building or FD.Built then return end
	building = true
	FD.Failed = nil
	attempts += 1
	MeshBudget.Essential(FD.Id, true)         -- (while it builds, no optional mesh starts)
	task.spawn(function()
		local ok, data = pcall(function() return require(script.Parent:WaitForChild("FrostDragonData", 10)) end)
		if not ok or type(data) ~= "table" then
			warn("[FrostDragonKit] no FrostDragonData: " .. tostring(data))
			FD.Failed = true
			MeshBudget.Essential(FD.Id, false)
			return
		end
		FD.Data = data
		local failed = false
		for name, d in pairs(data.Pieces) do
			local ok2, err = pcall(buildPiece, name, d)
			if not ok2 then
				failed = true
				warn("[FrostDragonKit] " .. name .. ": " .. tostring(err))
				break                                       -- (the rest would only wait on the same budget)
			end
			task.wait()
		end
		if not failed then
			local okP, errP = pcall(buildPlate)
			if not okP then failed = true warn("[FrostDragonKit] Plate: " .. tostring(errP)) end
		end
		if not failed then
			local okB, errB = pcall(buildBolt)
			if not okB then failed = true warn("[FrostDragonKit] Bolt: " .. tostring(errB)) end
		end
		if not failed then
			local ok2, err2 = pcall(function() buildStage2(data) buildPrint() end)
			if not ok2 then failed = true warn("[FrostDragonKit] stage 2: " .. tostring(err2)) end
		end
		FD.BoltL = 1.8
		if failed then
			-- a partial dragon would draw an empty or broken cage: free the budget and leave the Default drawing
			for _, mp in ipairs(templates) do pcall(function() mp:Destroy() end) end
			for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
			table.clear(templates)
			table.clear(keep)
			table.clear(kinds)
			FD.Failed = true
			MeshBudget.Essential(FD.Id, false)
			-- not for good (2026-10-19): the budget frees as wraps and other effects let go of theirs, so the build is tried
			-- again while somebody still wears the skin -- after 15, 30, 60 and 120 s -- before the Default stays
			building = false
			if attempts < 5 then
				task.delay(15 * 2 ^ (attempts - 1), function() if wanted() then FD.Build() end end)
			end
			return
		end
		FD.Built = true
		building = false                          -- (2026-10-27) left true, releaseKit never let a built kit go: the Loadout's
		                                          -- browsed skins held their meshes all session and starved every later build
		MeshBudget.Essential(FD.Id, false)
	end)
end

function FD.Kind(name)
	return kinds[name]
end

function FD.New(name, parent)
	usedAt = os.clock()
	local k = kinds[name]
	if not k then return nil end
	local o = { Kind = k, Parts = {}, F = -1, S = 1 }
	for i, p in ipairs(k.Parts) do
		o.Parts[i] = { Part = p.Part:Clone(), Off = p.Off, Group = p.Group, Size = p.Size, Base = p.Base }
		if parent then o.Parts[i].Part.Parent = parent end
		if p.Group == "PlateRim" then o.Rim = o.Parts[i].Part end
	end
	o.P = {}                                            -- (every part: CryoWrap.PaintKit paints the whole piece)
	for i, q in ipairs(o.Parts) do o.P[i] = q.Part end
	o.Body = o.Parts[1] and o.Parts[1].Part            -- (CryoFX's bolt trail rides the Body)
	return o
end

function FD.Parent(o, parent)
	for _, p in ipairs(o.Parts) do p.Part.Parent = parent end
end

function FD.Drop(o)
	if not o then return end
	for _, p in ipairs(o.Parts) do pcall(function() p.Part:Destroy() end) end
end

--- 0 = as built, 1 = gone. The Neon groups never sit at a fractional transparency (a transparent core and its shell
--- share a centre, so their draw order flips with the camera): they show whole or not at all -- off past 0.25, back on
--- below 0.05 (a little hysteresis, so a piece at the edge of the keyhole doesn't blink).
function FD.Fade(o, f)
	if f == o.F then return end
	o.F = f
	for _, p in ipairs(o.Parts) do
		local base = p.Base or L.G[p.Group][2]
		if p.Hide then
			p.Part.Transparency = 1
		elseif OPAQUE_GLOW[p.Group] then
			if p.Dark then p.Dark = f > 0.05 else p.Dark = f > 0.25 end
			if f >= 1 then p.Dark = true end
			p.Part.Transparency = p.Dark and 1 or base
		else
			p.Part.Transparency = (f >= 1) and 1 or (base + (1 - base) * f)
		end
	end
end

--- hide one material group of a piece for good (the low tier drops the Core)
function FD.HideGroup(o, group)
	for _, p in ipairs(o.Parts) do
		if p.Group == group then
			p.Hide = true
			p.Part.Transparency = 1
		end
	end
end

--- a plate's glow, 0 (at rest: a soft self-lit pale crystal, a brighter rim) to 1 (white-hot, on its bolt)
function FD.PlateGlow(o, g)
	if g == o.G then return end
	o.G = g
	if o.Body then o.Body.Color = L.PlateRest:Lerp(L.PlateHot, g) end
	if o.Rim then o.Rim.Color = L.PlateRim:Lerp(L.PlateHot, g) end
end

--- place piece `o` with its pivot at `cf`, scale `s` (a Vector3 for the plate's L / T / W, or a number)
function FD.Place(o, cf, parts, cframes, s)
	usedAt = os.clock()
	s = s or 1
	local sv = typeof(s) == "Vector3" and s or Vector3.new(s, s, s)
	if sv ~= o.S then
		o.S = sv
		for _, p in ipairs(o.Parts) do p.Part.Size = p.Size * sv end
	end
	for _, p in ipairs(o.Parts) do
		parts[#parts + 1] = p.Part
		cframes[#cframes + 1] = cf * CFrame.new(p.Off * sv)
	end
end

--- the bolt's frame: its tail at `tail`, along `dir` (FrostLotusKit.Frame's)
function FD.Frame(tail, dir, side)
	dir = dir.Unit
	local sd = side - dir * side:Dot(dir)
	if sd.Magnitude < 1e-3 then
		sd = Vector3.yAxis - dir * dir.Y
		if sd.Magnitude < 1e-3 then sd = Vector3.xAxis - dir * dir.X end
	end
	return CFrame.fromMatrix(tail, sd.Unit, dir)
end

-- LAZY build (2026-10-17, as FrostDragonKit): only once a player in the server wears this skin, or -- in Studio -- a test
-- dummy stands in for it (StudioSkin). Every Cryo skin and wrap shares one EditableMesh budget per client; a kit nobody
-- in the server wears takes none of it (eager builds of all four overran it, and the worn skin fell back to the Default).
--- MeshBudget's Optional (2026-10-19): a built kit nobody here wears right now -- no player is Cryo in this skin, no Studio
--- stand-in -- and that placed no piece for 10 s lets go of every mesh, so another Element's worn wrap (Terra's Obsidian
--- Magma) can have the budget; the next player to be Cryo in the skin builds it again. Its pooled pieces elsewhere go
--- with it (OnRelease). Built goes false first, so whatever asks from now on draws the Default.
local function releaseKit()
	if building or not FD.Built or os.clock() - usedAt < 10 then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character and FD.On(plr.Character) then return end
	end
	if RunService:IsStudio() then
		for _, m in ipairs(workspace:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("StudioSkin") == FD.Id then return end
		end
	end
	if #FD.Showcased() > 0 then return end              -- (2026-10-26) a showcase stand-in wears it, live and in Studio
	FD.Built = false
	for _, fn in ipairs(releaseHooks) do pcall(fn) end
	for _, mp in ipairs(templates) do pcall(function() mp:Destroy() end) end
	for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
	table.clear(templates)
	table.clear(keep)
	table.clear(kinds)
	attempts = 0
end
MeshBudget.Optional(releaseKit)
--- (2026-10-26) the same let-go without the 10 s idle wait: the Altar showcase calls it on a swap, once the piece that
--- showed this skin is gone (still nothing if a player wears it, a stand-in still shows it, or it is building)
function FD.ReleaseNow()
	usedAt = 0
	releaseKit()
end

do
	-- (2026-10-19) one build at a time; after a failed one, the next player to put the skin on starts another
	local function go()
		FD.Build()
	end
	local attr = SkinCatalog.ElementSkinAttr("Cryo")
	local function check(plr)
		if FD.Built then return end
		local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Cryo")
		if ok and id == FD.Id and (plr:GetAttribute("Element") or "Cryo") == "Cryo" then go() end
	end
	wanted = function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Cryo")
			if ok and id == FD.Id and (plr:GetAttribute("Element") or "Cryo") == "Cryo" then return true end
		end
		if RunService:IsStudio() then
			for _, m in ipairs(workspace:GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("StudioSkin") == FD.Id then return true end
			end
		end
		return #FD.Showcased() > 0                         -- (2026-10-26) a showcase stand-in, live and in Studio
	end
	local function watch(plr)
		check(plr)
		plr:GetAttributeChangedSignal(attr):Connect(function() check(plr) end)
		plr:GetAttributeChangedSignal("Element"):Connect(function() check(plr) end)   -- (back to Cryo: a released kit again)
	end
	for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
	Players.PlayerAdded:Connect(watch)
	if RunService:IsStudio() then
		local function dummy(m) if m:IsA("Model") and m:GetAttribute("StudioSkin") == FD.Id then go() end end
		for _, m in ipairs(workspace:GetChildren()) do dummy(m) end
		workspace.ChildAdded:Connect(function(m) task.defer(dummy, m) end)
	end
	-- (2026-10-26) a showcase stand-in (ShowcaseSkin, live and in Studio) builds it too, wherever in the workspace it is put
	if RunService:IsClient() then
		local function stand(m) if m.Parent and FD.Showcase(m) then go() end end
		workspace.DescendantAdded:Connect(function(m) if m:IsA("Model") then task.defer(stand, m) end end)
	end
end
return FD
