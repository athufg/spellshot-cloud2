--[[
	WitchsBrewKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/WitchsBrewKit

	Toxin's WITCH'S BREW (2026-10-20; an EPIC Element skin -- SkinCatalog's tier; promoted from the Rare plan when the
	worn cauldron outgrew Rare's rules). The forms; WitchsBrewFX draws them on the Default's beats, gated on On().
	One related family of pieces, each with its own size/variant tiers:
	  Cauldron   the hero piece: a lathed iron pot (one EditableMesh, built once per client, uncoloured so a variant is
	             only a colour/material change), a glowing brew surface (Neon: its self-lit core), three feet, two lugs,
	             a ladle. Tiers: Back (worn, 1.0), Flight (the Ultimate's, 1.5). Variant: Husk (the same mesh, faded,
	             emptied, no glow) -- worn while the full one is away.
	  Glob       the flung brew: a Neon core inside a see-through brew skin. Tiers: M1 (the splash), Arc (Acid Rain's
	             fountain), Drop (Acid Rain's rain, the siphon's droplet: one Neon part).
	  Bubble     a translucent brew skin round a glowing Neon heart, with a shine (Acid Rain's flung bubbles, the
	             cauldron's surface; Soft: the Primary cloud's big bubbles, a bigger heart and a faint shine).
	  Satchel    the ward-herb bag: a soft flat cloth pouch with a violet fold-over flap (two curved grid meshes), the
	             glowing crescent ward on the flap and a glowing brew bead as its clasp; it hangs on the cauldron's side on a
	             strap, and the Vent opens its flap. (Never worn: the owner dropped the hat, the round sack and the face bag.)
	  Herb       the ward herb the Vent tosses into the brew: a plain plant (a brown stem, a few green leaves), no glow.
	  Tex()      the kit's painted images (EditableImages, built once): Star, Crescent, Dot, Spiral, Rune, Ward, Ring,
	             Ribbon -- the shared glint shapes and the witch marks.
	  Straps     the backpack's two shoulder straps (the one flagged avatar-reaching exception: the worn backpack).
	  (The steam tether and the siphon line are Beams, drawn by WitchsBrewFX.)
	  On(character)       its player is Toxin and SkinCatalog's ElementSkin_Toxin is "WitchsBrew"; Studio only: a body with
	                      StudioSkin = "WitchsBrew" stands in (never live). A true answer starts the build (Prepare).
	  Built               the cauldron mesh is ready (until then a plain cylinder stands in; FX draws nothing before it)
	  Tier(density, thin) 1 / 2 / 3, the kits' shared rule
	  SparklesOn()        the glint/mote layer's own switch: ReplicatedStorage.IceMagic attribute WitchsBrewSparkles
	                      (absent or true: on; false: off)
	  Palette()           "Olive" (default) or "Purple" (Studio preview of the purple brew-smoke accent proposal:
	                      IceMagic attribute WitchsBrewPalette = "Purple") -- an OPEN FLAG for the owner, not decided
	  OnRelease(fn) / ReleaseNow()   (2026-10-26) the give-back: worn by nobody here and idle 10 s, it lets go of its meshes
	                      (MeshBudget's Optional; ReleaseNow skips the idle wait); OnRelease's fns empty the pools elsewhere
	NOT in SkinCatalog.ElementSkins.Toxin until the owner approves the checkpoint (2026-10-20).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local WB = {}
WB.Id = "WitchsBrew"
WB.Built = false
WB.Failed = false

-- the colours: the kit's own, all purple over black iron (owner, round 4); WB.WrapPalette repaints the Default gas
WB.Look = {
	Iron = Color3.fromRGB(30, 28, 36), IronEdge = Color3.fromRGB(62, 58, 72),
	Brew = Color3.fromRGB(90, 45, 255),          -- (Neon: the self-lit core. Measured on screen: Neon + the place grade push
	                                             -- red up -- (126,70,255) shows as magenta (240,48,240); this one shows purple)
	BrewSkin = Color3.fromRGB(118, 56, 190), Steam = Color3.fromRGB(172, 140, 214),
	Leather = Color3.fromRGB(46, 30, 58), Herb = Color3.fromRGB(160, 118, 255),
	Wood = Color3.fromRGB(70, 48, 40), Husk = Color3.fromRGB(80, 78, 88), Cloth = Color3.fromRGB(44, 26, 64),
	HatBand = Color3.fromRGB(112, 54, 172), Flap = Color3.fromRGB(100, 56, 150), Ember = Color3.fromRGB(176, 128, 255), Glint = Color3.fromRGB(242, 220, 255),
	Accent = Color3.fromRGB(126, 78, 160),
}
-- THE DEFAULT PIECES' PALETTE (ToxinWrap draws a Witch's Brew wearer's Default Toxin pieces in it -- petals, drops,
-- strands, the eruption's wave and flash -- so nothing of the kit stays green). Source colours, then the measured display
-- inputs (Nightshade's measured mapping carried onto these sources). Clear of Toxin's shipped identity hexes.
local function hx(h) return Color3.fromHex(h) end
WB.WrapPalette = {
	Color = { Gas = hx("#5E3590"), GasLit = hx("#7E49BD"), GasShadow = hx("#38205A"), GasCore = hx("#1F1236"),
		Liquid = hx("#8E44D6"), LiquidDeep = hx("#2E1650"), LiquidSpec = hx("#F0E2FF"),
		Membrane = hx("#A35FE6"), MembraneHi = hx("#DCC2FB"), Virulence = hx("#C77DFF") },
	Display = {
		Lobe = { GasCore = Color3.fromRGB(112, 94, 128), GasShadow = Color3.fromRGB(138, 108, 164), Gas = Color3.fromRGB(187, 135, 230), GasLit = Color3.fromRGB(217, 153, 255) },
		Particle = { GasCore = Color3.fromRGB(66, 55, 84), GasShadow = Color3.fromRGB(82, 61, 111), Gas = Color3.fromRGB(113, 77, 162), GasLit = Color3.fromRGB(134, 88, 197) },
		Solid = { Liquid = Color3.fromRGB(181, 116, 243), LiquidDeep = Color3.fromRGB(92, 71, 106), LiquidSpec = Color3.fromRGB(249, 246, 255), Membrane = Color3.fromRGB(186, 123, 241), MembraneHi = Color3.fromRGB(194, 178, 210) },
		Neon = { Virulence = Color3.fromRGB(92, 52, 200) },          -- (bluer than it looks: Neon blooms red)
		Glow = { Virulence = Color3.fromRGB(150, 105, 255) },
	},
}

function WB.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

local function folderAttr(name)
	local f = ReplicatedStorage:FindFirstChild("IceMagic")
	return f and f:GetAttribute(name)
end
function WB.SparklesOn() return folderAttr("WitchsBrewSparkles") ~= false end
function WB.Palette() return (folderAttr("WitchsBrewPalette") == "Purple") and "Purple" or "Olive" end

----------------------------------------------------------------------------------------------------
-- THE CAULDRON MESHES: two lathes. A profile runs so that each edge's visible side is its right-hand normal
-- (dy, -dr); units are the pot's height, axis on Y, base at 0.
--   BODY  up the outside to the neck, across the top of the neck and down the inside to the brew line
--   RIM   the lip: a closed ring round the neck, its own part (a lighter iron band: the cauldron reads at rest)
----------------------------------------------------------------------------------------------------
local BODY = {
	{ 0.00, 0.00 }, { 0.20, 0.00 }, { 0.36, 0.05 }, { 0.47, 0.17 }, { 0.53, 0.33 }, { 0.53, 0.48 }, { 0.49, 0.62 },
	{ 0.42, 0.72 }, { 0.42, 0.80 }, { 0.39, 0.80 }, { 0.37, 0.74 }, { 0.00, 0.74 },   -- (an inner floor: the husk is a pot)
}
local RIM = {
	{ 0.43, 0.795 }, { 0.51, 0.795 }, { 0.565, 0.85 }, { 0.52, 0.925 }, { 0.43, 0.925 }, { 0.395, 0.86 }, { 0.43, 0.795 },
}
local SEGS = 18
local MIDY = 0.40                       -- (the body mesh's centre: every piece is placed in the body's space)
WB.BrewLine = 0.86                      -- the brew dome's centre height (it swells to just under the rim's top)
WB.BrewRadius = 0.385
WB.Tris = 0

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
		if b and i % 8 == 1 then b.MakeRoom() end
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}
-- a lathed MeshPart of `profile` (smooth ring normals, no vertex colours: the part's Color and Material show); returns
-- the part and its bounds' centre height and size (pot units), since a MeshPart centres its mesh
local function latheMesh(profile)
	local lo, hi, rmax = math.huge, -math.huge, 0
	for _, q in ipairs(profile) do
		lo, hi, rmax = math.min(lo, q[2]), math.max(hi, q[2]), math.max(rmax, q[1])
	end
	local cy = (lo + hi) / 2
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local n = #profile
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		for i = 1, n - 1 do
			local p0, p1 = profile[i], profile[i + 1]
			local dr, dy = p1[1] - p0[1], p1[2] - p0[2]
			local l = math.sqrt(dr * dr + dy * dy)
			local nA = { dy / l, -dr / l }
			for k = 0, SEGS - 1 do
				local a0, a1 = (k / SEGS) * 2 * math.pi, ((k + 1) / SEGS) * 2 * math.pi
				local function at(q, a) return Vector3.new(q[1] * math.cos(a), q[2] - cy, q[1] * math.sin(a)) end
				local am = (a0 + a1) / 2
				local want = Vector3.new(nA[1] * math.cos(am), nA[2], nA[1] * math.sin(am))
				local A, B, C, D = at(p0, a0), at(p0, a1), at(p1, a1), at(p1, a0)
				for _, t in ipairs({ { A, B, C }, { A, C, D } }) do
					local x, y, z = t[1], t[2], t[3]
					local fn = (y - x):Cross(z - x)
					if fn.Magnitude > 1e-9 then
						if fn:Dot(want) < 0 then y, z = z, y end
						local f = em:AddTriangle(em:AddVertex(x), em:AddVertex(y), em:AddVertex(z))
						local nx = em:AddNormal(want.Unit)
						em:SetFaceNormals(f, { nx, nx, nx })
						if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
						WB.Tris += 1
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
	mp.Material, mp.Reflectance = Enum.Material.Metal, 0.05
	return { Part = mp, CY = cy, Size = Vector3.new(2 * rmax, hi - lo, 2 * rmax) }
end

-- a closed mesh from a surface P(u, v) (u: 0..1 pole to pole, v: 0..1 round; shared vertices, smooth normals from the
-- grid's own tangents); its points are centred on their bounds (a MeshPart centres its mesh). Returns { Part, Off (the
-- bounds' centre, design units), Size }
local function sp(t, e) return (t < 0 and -1 or 1) * math.abs(t) ^ e end
local function gridMesh(P, nu, nv)
	local pts = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i = 0, nu do
		pts[i] = {}
		for j = 0, nv - 1 do
			local p = P(i / nu, j / nv)
			pts[i][j] = p
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
	local off = (lo + hi) / 2
	local function tangentN(i, j)
		local du = pts[math.min(nu, i + 1)][j] - pts[math.max(0, i - 1)][j]
		local dv = pts[i][(j + 1) % nv] - pts[i][(j - 1) % nv]
		return du:Cross(dv)
	end
	-- which way round the grid's normal points: out, at the front of its middle (the front is -Z)
	local flip = (tangentN(math.floor(nu / 2), math.floor(nv * 0.75)):Dot(Vector3.new(0, 0, -1)) < 0) and -1 or 1
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		local vid, nid, nrm = {}, {}, {}
		for i = 0, nu do
			vid[i], nid[i], nrm[i] = {}, {}, {}
			for j = 0, nv - 1 do
				vid[i][j] = em:AddVertex(pts[i][j] - off)
				local n = tangentN(i, j) * flip
				if n.Magnitude < 1e-7 then n = Vector3.new(0, (i == 0) and -1 or 1, 0) end   -- (a pole)
				nrm[i][j] = n.Unit
				nid[i][j] = em:AddNormal(n.Unit)
			end
		end
		for i = 0, nu - 1 do
			for j = 0, nv - 1 do
				local j2 = (j + 1) % nv
				local quad = { { i, j }, { i, j2 }, { i + 1, j2 }, { i + 1, j } }
				for _, t in ipairs({ { 1, 2, 3 }, { 1, 3, 4 } }) do
					local a, b, c = quad[t[1]], quad[t[2]], quad[t[3]]
					local A, B, C = pts[a[1]][a[2]], pts[b[1]][b[2]], pts[c[1]][c[2]]
					local fn = (B - A):Cross(C - A)
					if fn.Magnitude > 1e-9 then
						local want = nrm[a[1]][a[2]] + nrm[b[1]][b[2]] + nrm[c[1]][c[2]]
						if fn:Dot(want) < 0 then b, c = c, b end
						local f = em:AddTriangle(vid[a[1]][a[2]], vid[b[1]][b[2]], vid[c[1]][c[2]])
						em:SetFaceNormals(f, { nid[a[1]][a[2]], nid[b[1]][b[2]], nid[c[1]][c[2]] })
						if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
						WB.Tris += 1
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
	mp.Material, mp.Reflectance = Enum.Material.Fabric, 0
	return { Part = mp, Off = off, Size = hi - lo }
end

-- THE SATCHEL (the Vent; it hangs from the cauldron's rim at rest): a soft, flat pouch -- a rounded box (a superellipsoid),
-- a touch wider at the bottom where it sags, fuller low and pinched at the top like a stuffed bag -- and a fold-over flap
-- across its top front; both curved round an upright axis behind them, so it hugs a face (design units: its width is 1)
local POUCH_A, POUCH_B, POUCH_C, BEND = 0.5, 0.32, 0.13, 1.05   -- (a gentle curve: it hangs in front as a bag)
local FLAP_A, FLAP_B, FLAP_C, FLAP_Y = 0.53, 0.18, 0.03, 0.16
local FLAP_Z = -(POUCH_C * 0.86 + FLAP_C - 0.008)
local function bend(p)
	local rho = BEND - p.Z
	local a = p.X / BEND
	return Vector3.new(rho * math.sin(a), p.Y, BEND - rho * math.cos(a))
end
local function pouchAt(u, v)
	local th, ph = -math.pi / 2 + u * math.pi, v * 2 * math.pi
	local ct = sp(math.cos(th), 0.35)
	local y = POUCH_B * sp(math.sin(th), 0.35)
	local k = y / POUCH_B
	local x = POUCH_A * ct * sp(math.cos(ph), 0.3) * (1 - 0.07 * k)
	local z = POUCH_C * ct * sp(math.sin(ph), 0.3) * (1 - 0.16 * k) * (1 - 0.3 * math.max(0, k) ^ 2)
	return bend(Vector3.new(x, y, z))
end
local function flapAt(u, v)
	local th, ph = -math.pi / 2 + u * math.pi, v * 2 * math.pi
	local ct = sp(math.cos(th), 0.45)
	local y = FLAP_B * sp(math.sin(th), 0.45)
	local x = FLAP_A * ct * sp(math.cos(ph), 0.25) * (1 - 0.07 * ((y + FLAP_Y) / POUCH_B))
	local z = FLAP_C * ct * sp(math.sin(ph), 0.25) + 0.03 * math.max(0, y / FLAP_B)   -- (its top folds back over the bag)
	return bend(Vector3.new(x, y + FLAP_Y, z + FLAP_Z))
end

local template = nil                    -- { Body, Rim = lathes; Pouch, Flap = grid meshes }
local building = false
local usedAt = 0                        -- (2026-10-26) the last cauldron or satchel made (an unworn kit lets go of its meshes)
local releaseHooks = {}                 -- (2026-10-26) the pools of this kit's pieces elsewhere (OnRelease): emptied with it
--- (2026-10-26) `fn()` runs when the kit lets go of its meshes (WitchsBrewFX: its worn cauldrons go with them); never yields
function WB.OnRelease(fn) releaseHooks[#releaseHooks + 1] = fn end
function WB.Prepare()
	if WB.Built or building or not RunService:IsClient() then return end
	building = true
	local b = budget()
	if b then b.Essential(WB.Id, true) end
	task.spawn(function()
		WB.Tris = 0
		local ok, res = pcall(function()
			return { Body = latheMesh(BODY), Rim = latheMesh(RIM), Pouch = gridMesh(pouchAt, 14, 28), Flap = gridMesh(flapAt, 10, 28) }
		end)
		if ok then
			template = res
			pcall(WB.BuildTex)                                    -- (the painted textures; built-in sparkles stand in if they fail)
			WB.Built = true
		else
			WB.Failed = true
			warn("[WitchsBrewKit] the cauldron meshes did not build (" .. tostring(res) .. "); the Default draws")
			for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
			table.clear(keep)
		end
		building = false
		if b then b.Essential(WB.Id, false) end
	end)
end

----------------------------------------------------------------------------------------------------
-- THE KIT'S PAINTED TEXTURES (EditableImages painted once per client; their Content goes on particles, beams and surface
-- images): the SHARED GLINT SHAPES -- a five-point STAR and a CRESCENT moon; every sparkle in the kit is one of the two --
-- a soft DOT (droplets, embers), a two-arm SPIRAL (the M1's captured vortex), the RUNE circle (every cast's tell), the WARD
-- glyph (the Vent), a shimmer RING (Acid Rain's impact) and the siphon's RIBBON. Painted white: tinted where they are used.
----------------------------------------------------------------------------------------------------
local function smooth01(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1) return t * t * (3 - 2 * t) end
local function paint(w, h, fn)
	local im = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	local buf = buffer.create(w * h * 4)
	local px = 2 / w
	for y = 0, h - 1 do
		local v = (y + 0.5) / h * 2 - 1
		for x = 0, w - 1 do
			local u = (x + 0.5) / w * 2 - 1
			local a = math.clamp(fn(u, v, px), 0, 1)
			local o = (y * w + x) * 4
			buffer.writeu8(buf, o, 255)
			buffer.writeu8(buf, o + 1, 255)
			buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
		end
		if y % 48 == 47 then task.wait() end                   -- (spread over frames: no hitch)
	end
	im:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	return im
end
-- coverage of a signed distance (negative inside), anti-aliased over a pixel, with a soft glow outside
local function cover(sd, px, glow, reach)
	local c = math.clamp(0.5 - sd / px, 0, 1)
	if glow and sd > 0 then c = math.max(c, glow * math.exp(-sd / reach)) end
	return c
end
local function segDist(x, y, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local t = math.clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)
	local qx, qy = ax + dx * t - x, ay + dy * t - y
	return math.sqrt(qx * qx + qy * qy)
end
local STAR_PTS = {}
for i = 0, 9 do
	local a = -math.pi / 2 + i * math.pi / 5
	local r = (i % 2 == 0) and 0.86 or 0.36
	STAR_PTS[i + 1] = { math.cos(a) * r, math.sin(a) * r }
end
local function starSD(u, v)
	local d, inside = math.huge, false
	local n = #STAR_PTS
	for i = 1, n do
		local a, b = STAR_PTS[i], STAR_PTS[i % n + 1]
		d = math.min(d, segDist(u, v, a[1], a[2], b[1], b[2]))
		if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then inside = not inside end
	end
	return inside and -d or d
end
local function crescentSD(u, v, r1, ox, oy, r2)
	local d1 = math.sqrt(u * u + v * v) - r1
	local d2 = math.sqrt((u - ox) ^ 2 + (v - oy) ^ 2) - r2
	return math.max(d1, -d2)
end
local function ringSD(u, v, r, w) return math.abs(math.sqrt(u * u + v * v) - r) - w end

local TEX = nil
function WB.Tex() return TEX or nil end
function WB.BuildTex()
	if TEX ~= nil or not RunService:IsClient() then return end
	TEX = false
	local ok, res = pcall(function()
		local t = {}
		t.Star = paint(64, 64, function(u, v, px) return cover(starSD(u, v), px, 0.45, 0.12) end)
		t.Crescent = paint(64, 64, function(u, v, px) return cover(crescentSD(u, v, 0.8, 0.34, -0.22, 0.7), px, 0.45, 0.12) end)
		t.Dot = paint(32, 32, function(u, v) return 1 - smooth01(0.15, 1, math.sqrt(u * u + v * v)) end)
		t.Spiral = paint(128, 128, function(u, v)
			local r, th = math.sqrt(u * u + v * v), math.atan2(v, u)
			local arm = math.cos(2 * (th + r * 5))
			return smooth01(0.45, 0.95, arm) * (1 - smooth01(0.6, 0.98, r)) + 0.8 * math.exp(-r * 9)
		end)
		t.Rune = paint(256, 256, function(u, v, px)
			local th = math.atan2(v, u)
			local sd = math.min(ringSD(u, v, 0.93, 0.016), ringSD(u, v, 0.79, 0.011), ringSD(u, v, 0.44, 0.011))
			local k = math.floor((th / (2 * math.pi)) * 16 + 0.5)          -- (16 marks between the outer rings)
			local a = k / 16 * 2 * math.pi
			local cx, cy = math.cos(a), math.sin(a)
			if k % 2 == 0 then
				sd = math.min(sd, segDist(u, v, cx * 0.82, cy * 0.82, cx * 0.9, cy * 0.9) - 0.012)
			else
				sd = math.min(sd, math.sqrt((u - cx * 0.86) ^ 2 + (v - cy * 0.86) ^ 2) - 0.022)
			end
			for i = 0, 3 do                                          -- (four small crescents on the diagonals)
				local b = math.pi / 4 + i * math.pi / 2
				local lu, lv = u - math.cos(b) * 0.62, v - math.sin(b) * 0.62
				local cu, cv = lu * math.cos(-b) - lv * math.sin(-b), lu * math.sin(-b) + lv * math.cos(-b)
				sd = math.min(sd, crescentSD(cu, cv, 0.085, 0.035, 0, 0.07))
			end
			local dia = math.min(math.abs(u) / 0.36 + math.abs(v) / 0.05, math.abs(v) / 0.36 + math.abs(u) / 0.05) - 1
			sd = math.min(sd, dia * 0.04)                            -- (the centre: a four-point star)
			return cover(sd, px, 0.3, 0.03)
		end)
		t.Ward = paint(128, 128, function(u, v, px)
			local sd = ringSD(u, v, 0.84, 0.03)
			sd = math.min(sd, segDist(u, v, 0, -0.62, 0, 0.62) - 0.03)
			sd = math.min(sd, crescentSD(u, v - 0.05, 0.4, 0, -0.2, 0.38))   -- (a crescent cup, opening up)
			for i = -1, 1 do sd = math.min(sd, math.sqrt((u - i * 0.22) ^ 2 + (v + 0.66) ^ 2) - 0.05) end
			return cover(sd, px, 0.35, 0.05)
		end)
		t.Ring = paint(128, 128, function(u, v, px)
			local sd = ringSD(u, v, 0.78, 0.03)
			local a = math.clamp(0.5 - sd / px, 0, 1)
			local sparkle = 0
			for i = 0, 9 do
				local b = i / 10 * 2 * math.pi + 0.3
				local d = math.sqrt((u - math.cos(b) * 0.78) ^ 2 + (v - math.sin(b) * 0.78) ^ 2)
				sparkle = math.max(sparkle, math.exp(-d / 0.05))
			end
			return math.max(a, sparkle, 0.35 * math.exp(-math.max(0, sd) / 0.08))
		end)
		t.Ribbon = paint(128, 32, function(u, v)
			local band = math.exp(-(v / 0.38) ^ 2) * 0.55
			local bx = ((u + 1) * 64) % 32 - 16                      -- (a bead every 32 px: it tiles along the beam)
			return math.max(band, math.exp(-((bx / 6) ^ 2 + (v / 0.45) ^ 2)))
		end)
		local out = { Images = t }
		for k2, im in pairs(t) do out[k2] = Content.fromObject(im) end
		return out
	end)
	if ok then TEX = res else warn("[WitchsBrewKit] painted textures failed (" .. tostring(res) .. "); built-in sparkles stand in") end
end

-- (2026-10-26) THE SHOWCASE CONVENTION: a client-only model no player owns, with the attribute ShowcaseSkin = "<SkinId>"
-- (the Loadout Altar's dummies, the pedestal's held M1), wears that skin -- live and in Studio. Every such model asked
-- about (On) or seen entering the workspace (below) is kept here wherever it sits (the showcases parent theirs in their
-- own folders), so the build starts for it and WitchsBrewFX's manager finds it until it leaves the workspace.
local showcase = {}
--- whether `m` is a showcase stand-in wearing Witch's Brew (one wearing any skin is kept)
function WB.Showcase(m)
	local id = typeof(m) == "Instance" and m:GetAttribute("ShowcaseSkin")
	if type(id) ~= "string" or Players:GetPlayerFromCharacter(m) then return false end
	-- (2026-10-26) pruned on insert (strong keys): a stand-in that left the workspace goes when the next new one is kept
	if not showcase[m] then
		for k in pairs(showcase) do if not k:IsDescendantOf(workspace) then showcase[k] = nil end end
		showcase[m] = true
	end
	return id == WB.Id
end
--- the showcase stand-ins in the workspace wearing Witch's Brew now
function WB.Showcased()
	local out = {}
	for m in pairs(showcase) do
		if not m:IsDescendantOf(workspace) then
			showcase[m] = nil
		elseif m:GetAttribute("ShowcaseSkin") == WB.Id then
			out[#out + 1] = m
		end
	end
	return out
end

function WB.On(character)
	if typeof(character) ~= "Instance" then return false end
	local on
	if RunService:IsStudio() and character:GetAttribute("StudioSkin") == WB.Id then
		on = true
	elseif WB.Showcase(character) then                             -- (2026-10-26) a showcase stand-in, live too
		on = true
	else
		local plr = Players:GetPlayerFromCharacter(character)
		on = plr ~= nil and plr:GetAttribute("Element") == "Toxin"           -- (a borrowed Toxin Technique: the Default)
			and SkinCatalog.ElementSkin(plr, "Toxin") == WB.Id
	end
	if on and not WB.Failed then WB.Prepare() end
	return on
end
-- (2026-10-26) a showcase stand-in (ShowcaseSkin, live and in Studio) starts the build too, wherever in the workspace it is
if RunService:IsClient() then
	workspace.DescendantAdded:Connect(function(m)
		if m:IsA("Model") then task.defer(function() if m.Parent and WB.Showcase(m) then WB.On(m) end end) end
	end)
end

-- (2026-10-26) THE GIVE-BACK (FrostbladeKit's, for MeshBudget): a built kit nobody here wears right now -- no player is
-- Toxin in this skin (On's own rule; a wearer between bodies, dead or respawning, counts too), no Studio stand-in where
-- WitchsBrewFX's manager looks, no showcase stand-in -- and that made no cauldron or satchel for 10 s lets go of every
-- mesh (the four templates and their fixed meshes), so another skin or wrap that someone does wear can have the budget.
-- Built goes false first, so whatever asks from now on draws the Default; WitchsBrewFX drops its worn cauldrons with it
-- (OnRelease). The next On() that is true builds it again (Prepare). The painted textures (EditableImages) stay.
local function wornByPlayer(plr)
	if plr.Character and WB.On(plr.Character) then return true end
	local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Toxin")
	return ok and id == WB.Id and plr:GetAttribute("Element") == "Toxin"
end
local function releaseKit()
	if building or not WB.Built or os.clock() - usedAt < 10 then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if wornByPlayer(plr) then return end
	end
	if RunService:IsStudio() then
		local tg = workspace:FindFirstChild("TrainingGround")
		local dm = tg and tg:FindFirstChild("Dummies")
		for _, list in ipairs({ workspace:GetChildren(), dm and dm:GetChildren() or {} }) do
			for _, m in ipairs(list) do
				if m:IsA("Model") and m:GetAttribute("StudioSkin") == WB.Id then return end
			end
		end
	end
	if #WB.Showcased() > 0 then return end
	WB.Built = false
	for _, fn in ipairs(releaseHooks) do pcall(fn) end
	for _, t in pairs(template or {}) do pcall(function() t.Part:Destroy() end) end
	for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
	template = nil
	table.clear(keep)
end
--- (2026-10-26) the same let-go without the 10 s idle wait: the Altar showcase calls it on a swap, once the piece that
--- showed this skin is gone (still nothing if a player wears it, a stand-in still shows it, or it is building)
function WB.ReleaseNow()
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

----------------------------------------------------------------------------------------------------
-- PIECES. Every piece is a Model whose parts are welded to its root ("Root"); the caller anchors and moves the root
-- (a flight) or welds it to a body (the worn backpack). Sizes are in studs at scale 1.
----------------------------------------------------------------------------------------------------
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function weldTo(root, p, rel)
	p.CFrame = root.CFrame * rel
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = root, p, rel
	w.Parent = p
	p:SetAttribute("Rel", rel)
	return w
end
local function sphere(p, scale)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	if scale then m.Scale = scale end
	m.Parent = p
	return m
end

--- THE CAULDRON at `scale` (1 = worn: 1.15 studs tall). Returns { Model, Root (= Body), Body, Rim, Brew, Ladle, Feet,
--- Drips, Light, Scale, H (height), Mouth (the brew centre, relative to Root) }. Brew is the self-lit core: a glowing dome
--- that swells just under the rim's top, so the cauldron reads full and lit at rest from any side; Light glows it.
--- (Brew is a sphere-meshed Part turned so its local +X points up: emitters on it use NormalId.Right, its attachments'
--- Axis is up.)
function WB.Cauldron(scale, parent)
	if not template then return nil end                         -- (FX draws nothing until the meshes are built)
	usedAt = os.clock()                                           -- (2026-10-26)
	local L = WB.Look
	local s = (scale or 1) * 1.15
	local model = Instance.new("Model")
	model.Name = "WitchsBrewCauldron"
	local TB, TR = template.Body, template.Rim
	local body = TB.Part:Clone()
	body.Name = "Body"
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch, body.CastShadow, body.Massless = true, false, false, false, false, true
	body.Color, body.Material = L.Iron, Enum.Material.Metal
	body.Size = TB.Size * s
	body.Parent = model
	model.PrimaryPart = body
	local function y(v) return (v - TB.CY) * s end                -- (pot height v, in the body's space)
	local rim = TR.Part:Clone()
	rim.Name = "Rim"
	rim.Anchored, rim.CanCollide, rim.CanQuery, rim.CanTouch, rim.CastShadow, rim.Massless = false, false, false, false, false, true
	rim.Color, rim.Material, rim.Reflectance = L.IronEdge, Enum.Material.Metal, 0.15
	rim.Size = TR.Size * s
	rim.Parent = model
	weldTo(body, rim, CFrame.new(0, y(TR.CY), 0))
	local R = WB.BrewRadius * s
	local brew = part({ Name = "Brew", Material = Enum.Material.Neon, Color = L.Brew, Size = Vector3.new(0.17 * s, 2 * R, 2 * R),
		Transparency = 0.02 }, model)
	sphere(brew)
	local brewY = y(WB.BrewLine)
	weldTo(body, brew, CFrame.new(0, brewY, 0) * CFrame.Angles(0, 0, math.pi / 2))
	local feet = {}
	for i = 1, 3 do
		local a = (i / 3) * 2 * math.pi + math.pi / 6
		local f = part({ Name = "Foot", Color = L.Iron, Material = Enum.Material.Metal, Size = Vector3.new(0.12, 0.17, 0.12) * s }, model)
		weldTo(body, f, CFrame.new(math.cos(a) * 0.3 * s, y(-0.03), math.sin(a) * 0.3 * s))
		feet[i] = f
	end
	for _, x in ipairs({ -1, 1 }) do
		local lug = part({ Name = "Lug", Shape = Enum.PartType.Cylinder, Color = L.IronEdge, Material = Enum.Material.Metal,
			Size = Vector3.new(0.08 * s, 0.16 * s, 0.16 * s) }, model)
		weldTo(body, lug, CFrame.new(x * 0.44 * s, y(0.7), 0))
	end
	-- three runs of brew down the outside from the lip (glowing: they carry the brew's colour round the back)
	local drips = {}
	for i, a in ipairs({ 0.4, 2.3, 4.3 }) do
		local len = (i == 2) and 0.2 or 0.13
		local dr = part({ Name = "Drip", Material = Enum.Material.Neon, Color = L.Brew, Transparency = 0.1,
			Size = Vector3.new(0.05, len, 0.05) * s }, model)
		local r = 0.5
		weldTo(body, dr, CFrame.new(math.cos(a) * r * s, y(0.79 - len / 2), math.sin(a) * r * s) * CFrame.Angles(0, -a, 0.12))
		drips[i] = dr
	end
	-- the ladle: its handle leans out of the brew (the Ultimate stirs with it)
	local ladle = part({ Name = "Ladle", Color = L.Wood, Material = Enum.Material.Wood,
		Size = Vector3.new(0.06 * s, 0.8 * s, 0.06 * s) }, model)
	local ladleRel = CFrame.new(0.12 * s, brewY + 0.2 * s, 0.05 * s) * CFrame.Angles(0, 0, math.rad(-22))
	weldTo(body, ladle, ladleRel)
	-- its BOWL (2026-10-23: the M1 throws with the ladle): black iron at the handle's lower end, down in the brew at rest,
	-- and the scoop of brew it carries (Neon, shown only while loaded). Welded to the handle, so it goes where the handle goes.
	local bowl = part({ Name = "LadleBowl", Color = L.Iron, Material = Enum.Material.Metal,
		Size = Vector3.new(0.24 * s, 0.11 * s, 0.24 * s) }, model)
	sphere(bowl)
	weldTo(ladle, bowl, CFrame.new(0, -0.42 * s, 0))
	local fill = part({ Name = "LadleFill", Material = Enum.Material.Neon, Color = L.Brew, Transparency = 1,
		Size = Vector3.new(0.17 * s, 0.03 * s, 0.17 * s) }, model)
	sphere(fill)
	weldTo(ladle, fill, CFrame.new(0, -0.39 * s, 0))
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = L.Brew, 6 * (scale or 1), 0.9, false
	light.Parent = brew
	if parent then model.Parent = parent end
	return { Model = model, Root = body, Body = body, Rim = rim, Brew = brew, Ladle = ladle, LadleRel = ladleRel, LadleBowl = bowl,
		LadleFill = fill, Feet = feet,
		Drips = drips, Light = light, Scale = scale or 1, H = s, Mouth = CFrame.new(0, brewY, 0), Husk = false }
end

--- The HUSK variant of the same cauldron: faded and emptied (the same meshes, a colour/material change; no glow).
function WB.Husk(c, on)
	if c.Husk == on then return end
	c.Husk = on
	local L = WB.Look
	c.Body.Color = on and L.Husk or L.Iron
	c.Body.Material = on and Enum.Material.Slate or Enum.Material.Metal
	c.Body.Transparency = on and 0.35 or 0
	c.Rim.Color = on and L.Husk or L.IronEdge
	c.Rim.Transparency = on and 0.35 or 0
	c.Brew.Transparency = on and 1 or 0.02
	c.Ladle.Transparency = on and 1 or 0
	if c.LadleBowl then c.LadleBowl.Transparency = on and 1 or 0 end
	c.Light.Enabled = not on
	for _, f in ipairs(c.Feet) do f.Transparency = on and 0.35 or 0 end
	for _, d in ipairs(c.Drips) do d.Transparency = on and 1 or 0.1 end
end

--- THE GLOB at `tier` ("M1" | "Arc"): { Model, Root (= Core), Core (Neon), Skin, Drips }. "Drop" is one Neon part.
function WB.Glob(tier, parent)
	local L = WB.Look
	local model = Instance.new("Model")
	model.Name = "WitchsBrewGlob"
	local core = part({ Name = "Core", Material = Enum.Material.Neon, Color = L.Brew, Anchored = true, Size = Vector3.new(1, 1, 1) }, model)
	sphere(core)
	model.PrimaryPart = core
	-- (SmoothPlastic, not Glass: Roblox draws nothing see-through behind Glass, and the core must show through)
	local skin = part({ Name = "Skin", Material = Enum.Material.SmoothPlastic, Color = L.BrewSkin, Transparency = 0.45, Anchored = true,
		Size = Vector3.new(1, 1, 1), Reflectance = 0.1 }, model)
	sphere(skin)
	local drips, mottles, shine = {}, {}, nil
	if tier == "M1" then
		for i = 1, 3 do                                       -- (dark swirls of brew inside: the glob is mottled, not flat)
			local mt = part({ Name = "Mottle", Material = Enum.Material.SmoothPlastic, Color = L.BrewSkin:Lerp(Color3.new(), 0.45),
				Anchored = true, Transparency = 0.3, Size = Vector3.new(1, 1, 1) }, model)
			sphere(mt)
			mottles[i] = mt
		end
		shine = part({ Name = "Shine", Material = Enum.Material.Neon, Color = Color3.fromRGB(240, 255, 225), Anchored = true,
			Transparency = 0.15, Size = Vector3.new(1, 1, 1) }, model)
		sphere(shine)
	end
	if parent then model.Parent = parent end
	return { Model = model, Root = core, Core = core, Skin = skin, Drips = drips, Mottles = mottles, Shine = shine, Tier = tier,
		Trail = {}, Seed = math.random() * 10 }
end
function WB.Drop(parent)
	local p = part({ Name = "WitchsBrewDrop", Material = Enum.Material.Neon, Color = WB.Look.Brew, Anchored = true,
		Size = Vector3.new(0.2, 0.3, 0.2), Transparency = 0.1 }, parent)
	sphere(p)
	return p
end

--- Place a glob at `cf` in a box of `size` (the Default sac's box); `fade` 0..1. The core rides inside the skin.
function WB.PlaceGlob(g, cf, size, fade, lag)
	local f = math.clamp(fade or 0, 0, 1)
	g.Skin.CFrame, g.Skin.Size = cf, size
	g.Core.CFrame, g.Core.Size = cf, size * 0.55
	g.Skin.Transparency = 0.45 + 0.55 * f
	g.Core.Transparency = 0.95 * f
	local cam = workspace.CurrentCamera
	if g.Shine and cam then                                      -- (a shine on the camera side, upper left: wet, not flat)
		local pos = cf.Position
		local toCam = (cam.CFrame.Position - pos)
		toCam = toCam.Magnitude > 1e-3 and toCam.Unit or Vector3.zAxis
		local rv = toCam:Cross(Vector3.yAxis)
		rv = rv.Magnitude > 1e-3 and rv.Unit or Vector3.xAxis
		local r = size.X * 0.5
		local sp = pos + (toCam * 0.78 + Vector3.yAxis * 0.42 - rv * 0.3) * r
		g.Shine.CFrame = CFrame.lookAt(sp, sp + toCam) * CFrame.Angles(0, 0, math.rad(-35))
		g.Shine.Size = Vector3.new(0.36, 0.18, 0.06) * size.X
		g.Shine.Transparency = 0.15 + 0.85 * f
	end
	if #g.Mottles > 0 then                                       -- (the swirls turn slowly inside the skin)
		local t = os.clock() * 0.9 + g.Seed
		for i, mt in ipairs(g.Mottles) do
			local a = t + i * 2.1
			mt.CFrame = cf * CFrame.new(math.cos(a) * 0.2 * size.X, math.sin(a * 1.3) * 0.16 * size.Y, math.sin(a) * 0.2 * size.Z)
			mt.Size = size * (0.28 + 0.06 * i)
			mt.Transparency = 0.3 + 0.7 * f
		end
	end
	local moving = lag ~= nil and lag.Magnitude > 1e-3
	for i, dp in ipairs(g.Drips) do                              -- (the drips trail only a glob in flight)
		if moving then
			dp.CFrame = cf + lag.Unit * (size.Magnitude * (0.35 + 0.28 * i))
			dp.Size = Vector3.one * size.X * (0.32 - 0.08 * i)
		end
		dp.Transparency = moving and (0.1 + 0.9 * f) or 1
	end
end

--- THE BUBBLE (Acid Rain's projectiles, the cauldron's surface): a translucent, faintly brew-tinted skin with a faint
--- glowing heart and two shine highlights on the camera side. { Model, Skin, Core, Shine, Shine2 }; PlaceBubble draws it.
function WB.Bubble(parent)
	local L = WB.Look
	local model = Instance.new("Model")
	model.Name = "WitchsBrewBubble"
	local skin = part({ Name = "Skin", Material = Enum.Material.SmoothPlastic, Color = L.Brew:Lerp(Color3.new(1, 1, 1), 0.55),
		Anchored = true, Transparency = 0.5, Reflectance = 0.35, Size = Vector3.new(1, 1, 1) }, model)
	sphere(skin)
	local core = part({ Name = "Core", Material = Enum.Material.Neon, Color = L.Brew, Anchored = true, Transparency = 0.4,
		Size = Vector3.new(1, 1, 1) }, model)
	sphere(core)
	local shine = part({ Name = "Shine", Material = Enum.Material.Neon, Color = Color3.fromRGB(245, 255, 240), Anchored = true,
		Transparency = 0.05, Size = Vector3.new(1, 1, 1) }, model)
	sphere(shine)
	local shine2 = part({ Name = "Shine2", Material = Enum.Material.Neon, Color = Color3.fromRGB(245, 255, 240), Anchored = true,
		Transparency = 0.25, Size = Vector3.new(1, 1, 1) }, model)
	sphere(shine2)
	model.PrimaryPart = skin
	if parent then model.Parent = parent end
	return { Model = model, Skin = skin, Core = core, Shine = shine, Shine2 = shine2 }
end
--- `soft` (the cloud's big bubbles): a bigger glowing heart and a small, faint shine -- a lit pot, not a soap bubble
function WB.PlaceBubble(b, pos, d, fade, soft)
	local f = math.clamp(fade or 0, 0, 1)
	b.Skin.CFrame, b.Skin.Size = CFrame.new(pos), Vector3.new(d, d, d)
	b.Core.CFrame, b.Core.Size = CFrame.new(pos), Vector3.new(d, d, d) * (soft and 0.5 or 0.32)
	b.Skin.Transparency = 0.5 + 0.5 * f
	b.Core.Transparency = 0.4 + 0.6 * f
	local cam = workspace.CurrentCamera
	local toCam = cam and (cam.CFrame.Position - pos) or Vector3.zAxis
	toCam = toCam.Magnitude > 1e-3 and toCam.Unit or Vector3.zAxis
	local rv = toCam:Cross(Vector3.yAxis)
	rv = rv.Magnitude > 1e-3 and rv.Unit or Vector3.xAxis
	local r = d * 0.5
	local s1 = pos + (toCam * 0.8 + Vector3.yAxis * 0.4 - rv * 0.32) * r
	b.Shine.CFrame = CFrame.lookAt(s1, s1 + toCam) * CFrame.Angles(0, 0, math.rad(-35))
	b.Shine.Size = Vector3.new(0.34, 0.15, 0.05) * d * (soft and 0.45 or 1)
	b.Shine.Transparency = soft and (0.45 + 0.55 * f) or (0.05 + 0.95 * f)
	local s2 = pos + (toCam * 0.85 - Vector3.yAxis * 0.32 + rv * 0.28) * r
	b.Shine2.CFrame = CFrame.new(s2)
	b.Shine2.Size = Vector3.new(0.08, 0.08, 0.08) * d
	b.Shine2.Transparency = 0.25 + 0.75 * f
end

--- THE SATCHEL (the Vent's ward-herb bag; owner round 5b: a real bag, not a ball): a soft, flat cloth pouch (rounded box,
--- sagging wider at the bottom, pinched at the top, curved to hug a face) with a violet FOLD-OVER FLAP across its top front.
--- On the flap: the glowing CRESCENT WARD (a self-lit image) and, at the flap's tip, a glowing brew BEAD as its clasp (a
--- soft halo and a small light), both riding on the flap. `scale` = twice its width. It hangs on the cauldron's side on
--- a strap (FX); the Vent pops the flap open about Hinge (FlapWeld.C0 from FlapRel) and takes a herb out. Everything is
--- welded to the Pouch (Root). Returns { Model, Root (= Pouch), Pouch, Flap, FlapWeld, FlapRel, Hinge, Bead, BeadLight,
--- Rune, Halo, Glows, Depth, Height, TopY, BackZ, FrontZ, S }, or nil until the meshes are
--- built. TopY / BackZ / FrontZ: its top edge, the middle of its back, and its front-most point (the clasp), in the
--- pouch's space. Glows: the pieces LocalTransparencyModifier can't hide (the ward image, the bead's light and halo).
WB.HaloSize, WB.HaloLift = 0.32, 0.06                         -- (the clasp's halo, x its width: a user scaling the bag reads these)
function WB.Satchel(scale, parent)
	if not (template and template.Pouch and template.Flap) then return nil end
	usedAt = os.clock()                                           -- (2026-10-26)
	local L = WB.Look
	local s = (scale or 1) * 0.5                                  -- (its width, studs)
	local model = Instance.new("Model")
	model.Name = "WitchsBrewSatchel"
	local TP, TF = template.Pouch, template.Flap
	local function at(p) return (p - TP.Off) * s end              -- (a design point, in the pouch's space)
	local pouch = TP.Part:Clone()
	pouch.Name = "Pouch"
	pouch.Anchored, pouch.CanCollide, pouch.CanQuery, pouch.CanTouch, pouch.CastShadow, pouch.Massless = true, false, false, false, false, true
	pouch.Material, pouch.Color, pouch.Reflectance = Enum.Material.Fabric, L.Cloth, 0
	pouch.Size = TP.Size * s
	pouch.Parent = model
	model.PrimaryPart = pouch
	local flap = TF.Part:Clone()
	flap.Name = "Flap"
	flap.Anchored, flap.CanCollide, flap.CanQuery, flap.CanTouch, flap.CastShadow, flap.Massless = false, false, false, false, false, true
	flap.Material, flap.Color, flap.Reflectance = Enum.Material.Fabric, L.Flap, 0
	flap.Size = TF.Size * s
	flap.Parent = model
	local flapRel = CFrame.new(at(TF.Off))
	local flapWeld = weldTo(pouch, flap, flapRel)
	local hinge = at(Vector3.new(0, FLAP_Y + FLAP_B - 0.012, FLAP_Z + FLAP_C))   -- (the flap's top back edge: it opens about it)
	local flapFront = FLAP_Z - FLAP_C                             -- (the flap's face, at its middle)
	-- THE CLASP: a glowing brew bead at the flap's tip (its core), with a soft halo and a little light
	local bead = part({ Name = "Bead", Material = Enum.Material.Neon, Color = L.Brew, Size = Vector3.new(0.075, 0.075, 0.075) * s }, model)
	sphere(bead)
	weldTo(flap, bead, flapRel:Inverse() * CFrame.new(at(Vector3.new(0, FLAP_Y - FLAP_B + 0.035, flapFront - 0.018))))
	local beadLight = Instance.new("PointLight")
	beadLight.Color, beadLight.Range, beadLight.Brightness, beadLight.Shadows = L.Brew, 3 * s, 0.9, false
	beadLight.Parent = bead
	local glows = { beadLight }
	local halo = nil
	if TEX and TEX.Dot then
		local bg = Instance.new("BillboardGui")
		bg.LightInfluence, bg.Brightness = 0, 1.4
		bg.Size = UDim2.new(WB.HaloSize * s, 0, WB.HaloSize * s, 0)
		bg.StudsOffset = Vector3.new(0, 0, WB.HaloLift * s)        -- (in front of the flap)
		bg.Adornee = bead
		bg.Parent = bead
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency, im.Size, im.ImageContent, im.ImageColor3, im.ImageTransparency =
			1, UDim2.fromScale(1, 1), TEX.Dot, L.Brew, 0.35
		im.Parent = bg
		glows[#glows + 1] = bg
		halo = bg
	end
	-- THE CRESCENT WARD on the flap (a self-lit image on an unseen Glass host: ToxinFX's dropMask leaves Glass alone)
	local rune = part({ Name = "Rune", Material = Enum.Material.Glass, Transparency = 1, Size = Vector3.new(0.26 * s, 0.26 * s, 0.01) }, model)
	weldTo(flap, rune, flapRel:Inverse() * CFrame.new(at(Vector3.new(0, FLAP_Y + 0.03, flapFront - 0.006))))
	if TEX and TEX.Ward then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.LightInfluence, sg.Brightness = 0, 2.2
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(128, 128)
		sg.Parent = rune
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency, im.Size, im.ImageContent, im.ImageColor3 = 1, UDim2.fromScale(1, 1), TEX.Ward, L.Herb
		im.Parent = sg
		glows[#glows + 1] = sg
	end
	if parent then model.Parent = parent end
	return { Model = model, Root = pouch, Pouch = pouch, Flap = flap, FlapWeld = flapWeld, FlapRel = flapRel, Hinge = hinge,
		Bead = bead, BeadLight = beadLight, Rune = rune, Halo = halo,
		Glows = glows, Depth = TP.Size.Z * s, Height = TP.Size.Y * s, TopY = at(Vector3.new(0, POUCH_B, 0)).Y,
		BackZ = at(Vector3.new(0, 0, POUCH_C)).Z, FrontZ = at(Vector3.new(0, 0, flapFront - 0.06)).Z, S = s }
end

--- THE HERB (the Vent's ward herb, tossed into the brew): a plain plant -- a woody brown stem and a few green leaf planes,
--- no glow (it is a plant, not a spell). Low-part and static (it is on screen for under a second). `len` = its length,
--- studs. { Model, Root (= the stem, anchored; the leaves are welded to it) }
function WB.Herb(len, parent)
	local model = Instance.new("Model")
	model.Name = "WitchsBrewHerb"
	local stem = part({ Name = "Stem", Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 42), Anchored = true,
		Size = Vector3.new(0.05 * len, len, 0.05 * len) }, model)
	model.PrimaryPart = stem
	local LEAVES = {                                              -- { height along the stem, side, yaw, size }
		{ -0.18, 1, 0, 1 }, { 0.02, -1, 40, 1.1 }, { 0.2, 1, -30, 1 }, { 0.36, -1, 70, 0.85 }, { 0.5, 1, 10, 0.75 },
	}
	for i, lf in ipairs(LEAVES) do
		local leaf = part({ Name = "Leaf", Material = Enum.Material.SmoothPlastic,
			Color = (i % 2 == 0) and Color3.fromRGB(98, 150, 66) or Color3.fromRGB(78, 128, 54),
			Size = Vector3.new(0.36 * len, 0.02 * len, 0.17 * len) * lf[4] }, model)
		sphere(leaf)
		weldTo(stem, leaf, CFrame.new(0, lf[1] * len, 0) * CFrame.Angles(0, math.rad(lf[3]), 0)
			* CFrame.new(lf[2] * 0.17 * len * lf[4], 0, 0) * CFrame.Angles(0, 0, lf[2] * math.rad(28)))
	end
	if parent then model.Parent = parent end
	return { Model = model, Root = stem }
end

--- THE STRAPS on `torso`: two shoulder straps (welded to the torso). Returns the parts.
function WB.Straps(torso, parent)
	local L = WB.Look
	local sx, sy, sz = torso.Size.X, torso.Size.Y, torso.Size.Z
	local out = {}
	for _, x in ipairs({ -0.27, 0.27 }) do
		local front = part({ Name = "Strap", Material = Enum.Material.Fabric, Color = L.Leather,
			Size = Vector3.new(0.16, sy * 0.78, 0.05) }, parent)
		weldTo(torso, front, CFrame.new(x * sx, sy * 0.06, -sz * 0.5 - 0.03))
		local top = part({ Name = "Strap", Material = Enum.Material.Fabric, Color = L.Leather,
			Size = Vector3.new(0.16, 0.05, sz + 0.1) }, parent)
		weldTo(torso, top, CFrame.new(x * sx, sy * 0.5 + 0.02, 0))
		out[#out + 1], out[#out + 1] = front, top
	end
	return out
end

return WB
