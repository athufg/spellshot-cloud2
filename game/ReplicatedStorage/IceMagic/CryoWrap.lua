--[[
	CryoWrap  (ModuleScript)  ->  ReplicatedStorage/IceMagic/CryoWrap

	Cryo's colour WRAPS (2026-10-15; the first: Mint Rime, Uncommon). A wrap recolours the DEFAULT Cryo shapes only: no
	geometry, particle count, timing or gameplay value changes, and the skins (Frostblade, Frost Lotus, Snow Globe) are
	never touched. A wrap is one data entry in SkinCatalog.Skins: { Wrap = "Cryo", Rarity, Palette = { Main, Shadow,
	Highlight, Accent } }.

	How it draws: today's Default Cryo draws every crystal through a SpecialMesh (CryoFX kitPart, VFXLibrary ffKitPart),
	which ignores the meshes' baked bands, so every colour on screen comes from a palette table in code. A wrap is
	therefore a palette swap, not a mesh or texture swap:
	  CONTEXT  while a wrapped caster's effect runs -- its entry call, each frame of its stepper, its deferred callbacks --
	           the Default palette tables (CryoTuning.Look, CryoFX's COL / STYLE / burst KINDS, CryoTuning.Blizzard,
	           VFXLibrary's FF2 / IS2) hold the wrap's colours, and are put back the moment it returns.
	  MAP      each Default colour goes to the wrap's ramp at the same lightness (IceDeep -> Shadow, IceMid -> Main,
	           IceLight -> Highlight, white stays white); the Frost Line takes Main, its flash Main-to-Highlight, the line
	           at rest and the soft cracks Accent. Near-greys stay. The frozen-body status colours stay Default.
	  POOLS    a pooled look (the shard, the Flash Freeze set, the burst rig) is kept per wrap, so a pooled piece never
	           carries one caster's colours to another's cast.
	For(caster): the wrap that caster's Cryo draws in -- nil unless their Element is Cryo (a borrowed Cryo Technique
	stays Default) and their Cryo skin is Default. Studio only: a WrapStudio attribute on a test dummy.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local W = { Active = nil }
local AUR                                                  -- CryoAurora (the Mythic wrap's own pieces), on first need
local function aurora()
	if AUR == nil then
		local ok, m = pcall(require, script.Parent:FindFirstChild("CryoAurora"))
		AUR = (ok and type(m) == "table") and m or false
		if AUR then AUR.Init(W) end
	end
	return AUR or nil
end

-- the Default ramp the map reads lightness against (VFXLibrary.Config.Colors)
local DEEP, MID, LIGHT = Color3.fromRGB(14, 79, 168), Color3.fromRGB(63, 182, 240), Color3.fromRGB(214, 246, 255)
local WHITE = Color3.new(1, 1, 1)
local function lum(c) return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end
local Y0, Y1, Y2 = lum(DEEP), lum(MID), lum(LIGHT)

-- colours that keep a role whichever table holds them (the Frost Line, its flash, the line at rest)
local BY_HEX = { ["3fe0ff"] = "Line", ["8df3ff"] = "Hot", ["245f9a"] = "Rest",
	-- the near-white ground fills, glows and haze tint over pale art (Vortex, Gust, the floor discs): toward Main, so a
	-- wrap's zones and storms are not carried by white; the storm's powder haze in Main
	["d5e7f3"] = "ArtTint", ["ecf6fc"] = "ArtTint", ["aacde6"] = "ArtTint", ["f6fbfe"] = "ArtTint", ["e2f3fc"] = "ArtTint",
	["ebf6fc"] = "ArtTint", ["a8cde6"] = "Haze", ["73d6ff"] = "Glow", ["cde4f4"] = "Haze" }
-- the ground discs' tints: a Rare wrap draws its own radial core-to-edge disc art (Art.FrostDisc), so its tint is white
for _, h in ipairs({ "aacde6", "f6fbfe", "e2f3fc", "ebf6fc" }) do BY_HEX[h] = "DiscTint" end
-- table paths with a role of their own
local BY_PATH = { ["STYLE.Crack.2"] = "Accent", ["STYLE.HotCrack.2"] = "Accent", ["STYLE.Flare.2"] = "Highlight",
	["KINDS.Glints.Props.Color"] = "Highlight", ["Look.Cage.PanelColor"] = "PanelTint", ["STYLE.Tip.2"] = "Highlight",
	["IS2.LineHot"] = "HotTip", ["IS2.Line"] = "TrailGlow",
	["IS2.Tip"] = "TipIfEdge", ["IS2.Glint"] = "GlowAccent",
	-- the Rare wraps' glassy glint edges (Highlight on rims and edges) and a shard body light enough to read (Edge tone)
	["Look.Cage.RimColor"] = "Rim", ["STYLE.Edge.2"] = "Glint", ["FF2.Frost"] = "Body", ["Look.FrozenFill"] = "FrozenFill", ["Look.FrozenShade"] = "FrozenShade", ["Look.FrozenRim"] = "FrozenRim", ["FF2.Spike"] = "SpikeTone", ["IS2.Body"] = "EdgeMain", ["STYLE.Panel.2"] = "DarkGlass" }   -- the shard: a Highlight head, an Accent trail, its glint white   -- (ArtTint: a white tint over pale-blue art)
-- never swapped: the frozen-body status colours, and the reflection cards' render setup
-- (the frozen body's own colours DO follow the wrap now -- owner, 2026-10-16: "make this blue part depend on the wrap")
local SKIP = { InkColor = true, Ambient = true, LightColor = true }

-- Uncommon = ONE FLAT palette: every Default colour snaps to one of the wrap's four by its lightness band (Default's own
-- shadow / mid / light split), so the wrap keeps Cryo's big shadow-to-mid gap; only pure whites and greys stay
local function ramp(c, P)
	if math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B) < 0.015 then return c end
	local y = lum(c)
	if y < 0.60 then return P.Shadow end
	if y < 0.885 then return P.Main end
	return P.Highlight
end

-- a multiply tint for a white-coloured mesh whose own colours are in its vertices or art (the skins' bodies, the cage's
-- panel art): Main, a little lifted, normalised so its brightest channel is 1
local function artTint(P)
	local t = (P.Edge and P.Edge.Main or P.Main):Lerp(P.Highlight, 0.3)
	local m = math.max(t.R, t.G, t.B)
	return Color3.new(t.R / m, t.G / m, t.B / m)
end

local NEUTRAL_ART = Color3.new(0.94, 0.89, 0.85)
-- a Glow wrap's tint over the pale-blue art (discs, panels, haze): cancels the art's blue cast and the blue ambient
local function warm(c) return Color3.new(c.R, c.G * 0.92, c.B * 0.86) end

local function colour(c, P, role)
	role = role or BY_HEX[string.lower(c:ToHex())]
	if P.Tints and role and P.Tints[role] then return P.Tints[role] end      -- (a wrap's own tint for a role: Aurora)
	-- a SOLID wrap (Black Ice): the cage rims and the Flash Freeze frost collars are bodies too -- glossy black
	if role == "Rim" then return P.Solid and P.Solid.Color or (P.Edge and (P.Silver or P.Edge.Main) or ramp(c, P)) end
	if role == "Body" then return P.Solid and P.Solid.Color or ramp(c, P) end
	-- the frozen body (a Glow wrap: a pink frozen tint, light-pink fill, pink rim)
	if role == "FrozenFill" then return (P.Glow and P.Main) or ramp(c, P) end
	if role == "FrozenShade" then return (P.Glow and P.Main) or ramp(c, P) end
	if role == "FrozenRim" then return (P.Glow and P.Main) or ramp(c, P) end
	if role == "SpikeTone" then return (P.Glow and P.Main) or ramp(c, P) end   -- (a Glow wrap: pink spikes, not white)
	if role == "Line" then return P.Edge and P.Accent or P.Main end   -- (a Rare wrap's Frost Line: a pale ice vein)
	if role == "Core" then return P.Edge and P.Main or ramp(c, P) end
	if role == "Glow" then return P.Edge and (P.Silver or P.Edge.Main) or ramp(c, P) end           -- (lights stay bright)
	if role == "TrailGlow" then return P.Edge and (P.Silver or P.Edge.Main) or P.Accent end
	if role == "DarkGlass" then return P.Edge and (P.Solid and P.Solid.Color or P.Main:Lerp(P.Shadow, 0.3)) or ramp(c, P) end   -- (not graded: not a core hex)
	if role == "PanelTint" then
		if P.Solid then return P.Solid.Color end
		if P.Glow then return warm(P.Main:Lerp(P.Edge.Main, 0.75)) end   -- (lighter: deep pink read as Sparks magenta)                -- (behind the black plate; alone at low quality)
		return P.Edge and P.Main:Lerp(P.Edge.Main, 0.3) or artTint(P)
	end
	if role == "Glint" then return P.Edge and (P.Silver or P.Edge.Main) or ramp(c, P) end
	if role == "TipIfEdge" then return P.Edge and (P.Edge.Tip or P.Highlight) or ramp(c, P) end
	if role == "HotTip" then return P.Edge and (P.Edge.Tip or P.Highlight) or P.Highlight end
	if role == "GlowAccent" then return P.Edge and P.Accent or c end
	if role == "EdgeMain" then return P.Edge and P.Edge.Main or ramp(c, P) end
	if role == "Haze" then return P.Edge and (P.Silver or P.Main:Lerp(P.Edge.Main, 0.5)) or P.Main end
	if role == "DiscTint" and P.Glow then return Color3.new(1.75, 0.62, 0.85) end   -- (over the pale-blue art: bright pink; decals take > 1)
	if role == "DiscTint" then
		if P.Edge and P.Art and P.Art.FrostDisc then return WHITE end
		if P.Solid then return P.Solid.Color end                 -- (no disc art yet: the Default art, near-black)
		return artTint(P)
	end
	if role == "Hot" or role == "Highlight" then return P.Highlight end
	if role == "Main" then return P.Main end
	if role == "Accent" then return P.Accent end
	if role == "Rest" then return P[P.Rest or "Accent"] end     -- the Frost Line at rest: the wrap's pick (Palette.Rest)
	if role == "ArtTint" then return (P.Glow and Color3.new(1.5, 0.66, 0.88)) or (P.Silver and NEUTRAL_ART) or artTint(P) end
	return ramp(c, P)
end

local function value(v, P, role)
	if typeof(v) == "Color3" then return colour(v, P, role) end
	if P._flowCS and not role then return P._flowCS end                -- (a Mythic wrap: its stops over the particle's life)
	if P.Life and not role then         -- (a Rare wrap's animated particles: dark -> a bright glint -> its luminous end)
		local L = P.Life
		return ColorSequence.new({ ColorSequenceKeypoint.new(0, L[1]), ColorSequenceKeypoint.new(L.At or 0.35, L[2]), ColorSequenceKeypoint.new(1, L[3]) })
	end
	if P.Edge and not role then          -- a Rare wrap's particles glint and darken: Highlight -> Edge -> Core over their life
		return ColorSequence.new(P.Edge.Tip or P.Highlight, P.Silver or P.Edge.Main)   -- (never ends dark)
	end
	local kps = {}
	for i, k in ipairs(v.Keypoints) do kps[i] = ColorSequenceKeypoint.new(k.Time, colour(k.Value, P, role)) end
	return ColorSequence.new(kps)
end

----------------------------------------------------------------------------------------------------
-- the registered palette tables, and the swap
----------------------------------------------------------------------------------------------------
local entries = {}                -- { T, K, O (the Default value), Role }
local arts = {}                   -- { T, K, O, Art }: a sprite id a wrap replaces with its own copy (SkinCatalog Art)
local registered = {}
local mapped = {}                 -- [palette Id] = { [entry] = its value }

local function register(t, path, depth)
	if registered[t] or depth > 3 then return end
	registered[t] = true
	for k, v in pairs(t) do
		if not SKIP[k] then
			local p = path .. "." .. tostring(k)
			local ty = typeof(v)
			if ty == "Color3" or ty == "ColorSequence" then
				entries[#entries + 1] = { T = t, K = k, O = v, Role = BY_PATH[p] }
			elseif ty == "table" then
				register(v, p, depth + 1)
			end
		end
	end
end

local depth, current = 0, nil

-- A wrap with Palette.Solid (Black Ice only, owner-approved): its SOLID bodies -- spike bases, slabs, the encasing mass,
-- the cage's panels, the Flash Freeze bases, the shot's body -- take a rough material and a wet Reflectance as well as the
-- near-black colour (their transparency stays Default's: hit-honest). Low Graphics Quality keeps only the colour.
local solidSaved, rimSaved, kindSaved = {}, nil, {}
local function solidOn(P)
	local q = 10
	pcall(function() q = UserSettings().GameSettings.SavedQualityLevel.Value end)
	return P.Solid and (q == 0 or q >= 4)                  -- (0: Automatic)
end
-- the material and Reflectance a solid piece takes: the pick, or at low Graphics Quality plain smooth black (no material
-- texture, a faint sheen)
local function solidMat(P)
	if solidOn(P) then return Enum.Material[P.Solid.Material], P.Solid.Reflectance end
	return Enum.Material.SmoothPlastic, 0                   -- (no Reflectance: on black it only adds the blue sky)
end
-- EVERY style a piece is dressed in (CryoFX STYLE: { Material, Color, Transparency, Reflectance }), by its colour in the
-- wrap: a dark one is a glossy black BODY (the solid material, no Reflectance: on the SpecialMesh pieces it mirrors the
-- blue sky); a light one GLOWS (Neon: self-lit, so it stays neutral -- every lit white turns blue in this game's light).
-- Transparency stays Default's (hit-honest). The burst kinds' particles take no scene light either (KINDS Props).
-- a wrap's own NUMBERS while it draws (Palette.Over "Table.Key" = value; OpaqueStyles: those STYLEs' default
-- transparency down to OpaqueT), put back after, like the colours
local overSaved = {}
local function overSwap(P, on)
	if not (P.Over or P.OpaqueStyles or P.StyleT) then return end
	if on then
		table.clear(overSaved)
		for path, v in pairs(P.Over or {}) do
			local tn, k = string.match(path, "^(%w+)%.(%w+)$")
			local t = W._T and W._T[tn]
			if t and t[k] ~= nil then overSaved[#overSaved + 1] = { t, k, t[k] } t[k] = v end
		end
		local S = W._STYLE
		for _, name in ipairs(P.OpaqueStyles or {}) do
			local s = S and S[name]
			if s and type(s[3]) == "number" then overSaved[#overSaved + 1] = { s, 3, s[3] } s[3] = math.min(s[3], P.OpaqueT or 0.06) end
		end
		for name, tv in pairs(P.StyleT or {}) do
			local s = S and S[name]
			if s and type(s[3]) == "number" then overSaved[#overSaved + 1] = { s, 3, s[3] } s[3] = tv end
		end
	else
		for i = #overSaved, 1, -1 do local e = overSaved[i] e[1][e[2]] = e[3] end
		table.clear(overSaved)
	end
end

local function solidSwap(P, on)
	if not (P.Solid or P.Glow) then return end
	local S = W._STYLE
	if S then
		for name, s in pairs(S) do
			if type(s) == "table" and typeof(s[2]) == "Color3" then
				if on then
					solidSaved[name] = { s[1], s[4] }
					local c = s[2]
					if P.Glow then
						if s[1] ~= Enum.Material.Neon then s[1], s[4] = Enum.Material.Neon, 0 end   -- (a Glow wrap: every piece self-lit)
						-- (no darkening here: these kit pieces are SpecialMeshes, which Neon does not brighten)
					elseif s[1] ~= Enum.Material.Neon then
						-- only the light LINES glow (SmoothPlastic: edges, cracks, ripples, the line at rest); every ice and
						-- frost style -- coats, crusts, prints, mounds -- is a glossy black body
						if math.max(c.R, c.G, c.B) > 0.45 and s[1] == Enum.Material.SmoothPlastic then
							s[1], s[4] = Enum.Material.Neon, 0
						else
							s[1], s[4] = solidMat(P)
							s[2] = P.Solid.Color
						end
					end
				elseif solidSaved[name] then
					s[1], s[4] = solidSaved[name][1], solidSaved[name][2]
				end
			end
		end
	end
	local K = W._KINDS
	if K then
		for kind, spec in pairs(K) do
			local pr = type(spec) == "table" and spec.Props
			if type(pr) == "table" and pr.LightInfluence then
				if on then kindSaved[kind] = pr.LightInfluence pr.LightInfluence = 0
				elseif kindSaved[kind] then pr.LightInfluence = kindSaved[kind] end
			end
		end
	end
	-- the cage's rims are opaque black bodies (Default: frosted glass at RimT 0.35, which let the blue sky through)
	local cg = W._LOOK and W._LOOK.Cage
	if cg and (P.Solid or P.Glow) then
		if on then rimSaved = cg.RimT cg.RimT = (P.Solid and P.Solid.RimT) or 0
		elseif rimSaved then cg.RimT = rimSaved end
	end
end
-- the PBR MaterialVariant (Palette.Solid.Variant), when it exists in MaterialService: plain box Parts only
local MaterialService = game:GetService("MaterialService")
local function variantFor(P, p)
	local v = P.Solid.Variant
	if not (v and solidOn(P)) or p:IsA("MeshPart") or p:FindFirstChildOfClass("SpecialMesh") then return nil end
	return MaterialService:FindFirstChild(v, true) and v or nil
end
--- an emitter / beam / trail made while a SOLID wrap (Black Ice) is drawing: it takes no scene light. This game's
--- ambient is blue (#6C7D9D / #7083A6) and its grade adds +0.35 saturation, so any LIT white or silver renders blue
--- (measured in Play: a lit #F2F4F7 renders #A1B7D5, the same colour self-lit #F1F3F5) -- the wrap's whites must glow
function W.Lit(e)
	local P = W.Active
	if P and (P.Solid or P.Glow) and typeof(e) == "Instance" then pcall(function()
		e.LightInfluence = 0
		if P.Glow then e.LightEmission = math.max(e.LightEmission, 0.6) end      -- (a soft bloom)
	end) end
	return e
end

--- a light piece in a solid wrap GLOWS (Neon: self-lit, so neutral) -- the shot's white head
function W.Glow(p)
	local P = W.Active
	if P and (P.Solid or P.Glow) and typeof(p) == "Instance" and p:IsA("BasePart") then p.Material, p.Reflectance = Enum.Material.Neon, 0 end
end

--- one part in the active wrap's solid look (the shot's body; the Flash Freeze crystals; graded body pieces)
function W.Solidify(p, P)
	P = P or W.Active
	if P and P.Glow and typeof(p) == "Instance" and p:IsA("BasePart") then      -- (a Glow wrap: the body glows instead)
		if p.Material ~= Enum.Material.Neon then
			local k = P.NeonK or 0.62
			local c = P.Main:Lerp(P.Edge.Main, 0.3)       -- (the approved panel pink)
			if p:FindFirstChildOfClass("SpecialMesh") then k = 1 end
			p.Material, p.Reflectance, p.Color = Enum.Material.Neon, 0, Color3.new(c.R * k, c.G * k, c.B * k)
		end
		return
	end
	if not (P and P.Solid and typeof(p) == "Instance" and p:IsA("BasePart")) then return end
	if p.Color ~= P.Solid.Color then p.Color = P.Solid.Color end
	local m, r = solidMat(P)
	if p.Material ~= m then p.Material = m end
	if p.Reflectance ~= r then p.Reflectance = r end
	local v = variantFor(P, p)
	if v and p.MaterialVariant ~= v then p.MaterialVariant = v end
end

-- THE CAGE PLATES (Black Ice): the Default panel is a Decal on an invisible box -- no material can show on it -- so a
-- solid wrap gives each panel a real plate cut to the panel art's own outline (Look.PanelPoly, the same polygon the rims
-- trace), 90 % of the panel's thickness inside the box (the outline, cracks, glare and reflections draw on the box's faces,
-- in front of it). Built once per client as EditableMeshes (4 variants, fixed-size copies: the resizable cap is 8), with
-- planar UVs (one tile per panel) for the PBR set. The plate's opacity follows the art's (~0.84 at full): hit-honest.
local plates = nil                 -- [var] = { T = template MeshPart, W, H (unit bbox), O (unit offset) } | false (failed)
local function buildPlates()
	local AS = game:GetService("AssetService")
	local polys = W._LOOK and W._LOOK.PanelPoly
	if not polys then plates = false return end
	local out = {}
	for var, poly in ipairs(polys) do
		local ok, res = pcall(function()
			local em
			for _ = 1, 30 do
				em = AS:CreateEditableMesh()
				if em then break end
				task.wait(1)                                 -- (the EditableMesh memory budget is full: wait it out)
			end
			assert(em, "no EditableMesh budget")
			local n = #poly
			local pts, x0, x1, y0, y1 = {}, math.huge, -math.huge, math.huge, -math.huge
			for i, a in ipairs(poly) do
				pts[i] = Vector2.new(-a[1], a[2])                   -- (the art's x runs along the part's -X)
				x0, x1, y0, y1 = math.min(x0, -a[1]), math.max(x1, -a[1]), math.min(y0, a[2]), math.max(y1, a[2])
			end
			local vcol = {}                                     -- (white vertex colours of its own: a Mythic wrap paints a blend)
			local function col(v)
				local id = vcol[v]
				if not id then id = em:AddColor(Color3.new(1, 1, 1), 1) vcol[v] = id end
				return id
			end
			local function face(a, b, c, nrm, uvs)
				local f = em:AddTriangle(a, b, c)
				em:SetFaceColors(f, { col(a), col(b), col(c) })
				local nid = em:AddNormal(nrm)
				em:SetFaceNormals(f, { nid, nid, nid })
				if uvs then em:SetFaceUVs(f, { em:AddUV(uvs[1]), em:AddUV(uvs[2]), em:AddUV(uvs[3]) }) end
			end
			local function uv(p) return Vector2.new((p.X - x0) / (x1 - x0), 1 - (p.Y - y0) / (y1 - y0)) end
			local area = 0
			for i = 1, n do local a, b = pts[i], pts[i % n + 1] area += a.X * b.Y - b.X * a.Y end
			local ccw = area > 0                                -- (the mirrored outline normally runs clockwise)
			local inner = {}                                    -- (the centre and an inset ring: a thin edge band outside it)
			local mid = Vector2.new((x0 + x1) / 2, (y0 + y1) / 2)
			for _, z in ipairs({ 0.5, -0.5 }) do
				local c = em:AddVertex(Vector3.new(mid.X, mid.Y, z))
				inner[#inner + 1] = c
				local cu = Vector2.new(0.5, 0.5)
				local vs, ws, wp = {}, {}, {}
				for i, p in ipairs(pts) do
					vs[i] = em:AddVertex(Vector3.new(p.X, p.Y, z))
					wp[i] = mid:Lerp(p, 0.88)
					ws[i] = em:AddVertex(Vector3.new(wp[i].X, wp[i].Y, z))
					inner[#inner + 1] = ws[i]
				end
				local nz = z > 0 and Vector3.zAxis or -Vector3.zAxis
				for i = 1, n do
					local j = i % n + 1
					-- counter-clockwise seen from outside: the +Z cap in the outline's CCW order, the -Z cap reversed
					local i1, j1 = i, j
					if (z > 0) ~= ccw then i1, j1 = j, i end
					face(c, ws[i1], ws[j1], nz, { cu, uv(wp[i1]), uv(wp[j1]) })
					face(ws[i1], vs[i1], vs[j1], nz, { uv(wp[i1]), uv(pts[i1]), uv(pts[j1]) })
					face(ws[i1], vs[j1], ws[j1], nz, { uv(wp[i1]), uv(pts[j1]), uv(wp[j1]) })
				end
			end
			for i = 1, n do
				local j = i % n + 1
				local a, b = pts[i], pts[j]
				local e = (b - a).Unit
				local nrm = Vector3.new(-e.Y, e.X, 0)
				if nrm.X * (a.X + b.X) + nrm.Y * (a.Y + b.Y) < 0 then nrm = -nrm end   -- (outward)
				local v1, v2 = em:AddVertex(Vector3.new(a.X, a.Y, 0.5)), em:AddVertex(Vector3.new(b.X, b.Y, 0.5))
				local v3, v4 = em:AddVertex(Vector3.new(b.X, b.Y, -0.5)), em:AddVertex(Vector3.new(a.X, a.Y, -0.5))
				-- wind each side so its normal faces out
				local cr = (Vector3.new(b.X, b.Y, 0.5) - Vector3.new(a.X, a.Y, 0.5)):Cross(Vector3.new(b.X, b.Y, -0.5) - Vector3.new(a.X, a.Y, 0.5))
				if cr:Dot(nrm) > 0 then face(v1, v2, v3, nrm) face(v1, v3, v4, nrm)
				else face(v1, v3, v2, nrm) face(v1, v4, v3, nrm) end
			end
			local fixed = AS:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
			-- a second copy for a Mythic wrap to paint (a copy of a FixedSize mesh drops the caps: copied from em here), its
			-- inner part grey so the wrap can tell it from the edge
			for _, v in ipairs(inner) do pcall(em.SetColor, em, vcol[v], Color3.new(0.5, 0.5, 0.5)) end
			local gfixed = AS:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
			local gmp = gfixed and AS:CreateMeshPartAsync(Content.fromObject(gfixed))
			em:Destroy()
			local mp = AS:CreateMeshPartAsync(Content.fromObject(fixed))
			mp.Name = "CagePlate"
			mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
			if gmp then gmp.Name = "CagePlate" gmp.Anchored, gmp.CanCollide, gmp.CanQuery, gmp.CanTouch, gmp.CastShadow, gmp.Massless = true, false, false, false, false, true end
			return { T = mp, Mesh = fixed, G = gmp, GMesh = gfixed, W = x1 - x0, H = y1 - y0, O = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, 0) }
		end)
		if not ok then warn("[CryoWrap] cage plate " .. var .. ": " .. tostring(res)) plates = false return end
		out[var] = res
	end
	plates = out
end

--- a cage panel's plate in the active solid wrap, or nil (no solid wrap, low Graphics Quality, plates not built):
--- { P = the MeshPart, W, H, O, T = thickness factor }; CryoFX places it with the panel (cf * O * R * scale)
function W.Plate(var, R, parent, thick)
	local P = W.Active
	if not plates and P and (P.Solid or P.Glow) and os.clock() > (W._plateRetry or 0) then   -- (a build that gave up: again)
		W._plateRetry = os.clock() + 30
		task.spawn(buildPlates)
	end
	if not (P and (P.Solid or P.Glow) and plates and plates[var] and (P.Glow or solidOn(P))) then return nil end
	local t = plates[var]
	local p = (P.Grad and aurora() and aurora().PlateCopy(P, var, t)) or t.T:Clone()   -- (Mythic: a blend across the face)
	if P.Glow and p:GetAttribute("AuroraGrad") then
		p.Material, p.Reflectance, p.Transparency = Enum.Material.Neon, 0, 1
	elseif P.Glow then
		local c, k = P.Main:Lerp(P.Edge.Main, 0.55), P.NeonK or 0.62
		p.Color, p.Material, p.Reflectance, p.Transparency = Color3.new(c.R * k, c.G * k, c.B * k), Enum.Material.Neon, 0, 1
	else
		p.Color = P.Solid.Color
		local m, r = solidMat(P)
		p.Material, p.Reflectance, p.Transparency = m, r, 1
	end
	-- the PBR set once uploaded: a SurfaceAppearance template (IceMagic.<Solid.Surface>) or the MaterialVariant
	local sa = P.Solid and P.Solid.Surface and script.Parent:FindFirstChild(P.Solid.Surface)
	if sa and sa:IsA("SurfaceAppearance") then sa:Clone().Parent = p
	elseif P.Solid and P.Solid.Variant and MaterialService:FindFirstChild(P.Solid.Variant, true) then p.MaterialVariant = P.Solid.Variant end
	p.Size = Vector3.new(t.W * R, t.H * R, 0.9 * thick)
	p.Parent = parent
	return { P = p, W = t.W, H = t.H, O = t.O, T = 0.9 * thick }
end

local function begin(P)
	if depth > 0 then
		if current ~= P then return false end
		depth += 1
		return true
	end
	local m = mapped[P.Id]
	if not m then
		m = {}
		for i, e in ipairs(entries) do m[i] = value(e.O, P, e.Role) end
		mapped[P.Id] = m
	end
	for i, e in ipairs(entries) do e.T[e.K] = m[i] end
	solidSwap(P, true)
	overSwap(P, true)
	for _, a in ipairs(arts) do if P.Art and P.Art[a.Art] then a.T[a.K] = P.Art[a.Art] end end   -- painted sprites: the wrap's copy
	depth, current, W.Active = 1, P, P
	return true
end

local function finish()
	depth -= 1
	if depth > 0 then return end
	if current then overSwap(current, false) solidSwap(current, false) end
	for _, e in ipairs(entries) do e.T[e.K] = e.O end
	for _, a in ipairs(arts) do a.T[a.K] = a.O end
	current, W.Active = nil, nil
end

-- fn in palette P with the effect context ctx ({ O = origin, R = radius }: a Rare wrap's gradient); errors still put the
-- Default back
local function runIn(P, ctx, fn, ...)
	local on = begin(P)
	local prev = W.Ctx
	W.Ctx = ctx
	local r = table.pack(pcall(fn, ...))
	W.Ctx = prev
	if on then finish() end
	if not r[1] then error(r[2], 0) end
	return table.unpack(r, 2, r.n)
end

--- fn(...) drawn in palette P (nil: as it is).
function W.Run(P, fn, ...)
	if not P then return fn(...) end
	return runIn(P, W.Ctx, fn, ...)
end

-- A RARE wrap's two-tone GRADIENT: a piece drawn in the core tone (Main / Shadow) is blended toward the Edge tone by its
-- distance from the effect's origin, in eighths (gradeSet remembers what this did, so a re-dressed piece is noticed)
local gradeBand, gradeSet = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local function grade(p, pos, P, ctx)
	if typeof(p) ~= "Instance" or not p:IsA("BasePart") or typeof(pos) ~= "Vector3" then return end
	if p:GetAttribute("AuroraGrad") or p:GetAttribute("AuroraSlab") then return end   -- (a Mythic copy: its colours are its own)
	local hx = p.Color:ToHex()
	local b
	if hx == P._mainHex then b = "Main" elseif hx == P._shadowHex then b = "Shadow" elseif hx == gradeSet[p] then b = gradeBand[p] end
	if P.Glow and p.Material ~= Enum.Material.Neon then p.Material, p.Reflectance = Enum.Material.Neon, 0 end   -- (hidden pieces too: they grow in)
	if not b then gradeBand[p] = nil return end
	if P.Solid then
		if p.Material == Enum.Material.Neon then
			local c = P.Silver or P.Highlight
			gradeBand[p], gradeSet[p] = b, c:ToHex()
			if hx ~= gradeSet[p] then p.Color = c end
		else
			gradeBand[p], gradeSet[p] = b, P.Solid.Color:ToHex()
			W.Solidify(p, P)
		end
		return
	end
	local t = math.floor(math.clamp((pos - ctx.O).Magnitude / ctx.R, 0, 1) * 10 + 0.5) / 10
	local c
	if b == "Main" and P.Edge.Tip and t > 0.6 then
		c = P.Edge.Main:Lerp(P.Edge.Tip, (t - 0.6) / 0.4)              -- the third stop: a bright rim
	else
		c = P[b]:Lerp(P.Edge[b], math.min(1, t / 0.6))                 -- the full Edge tone by 60 % of the radius
	end
	if P.Glow and p:FindFirstChildOfClass("SpecialMesh") then          -- (the crystals: lit kit meshes)
		local cr = P.Crystal
		local k = cr and ((b == "Shadow") and cr.Base or cr.Body:Lerp(cr.Tip, math.clamp((t - 0.3) / 0.7, 0, 1))) or P[b]
		c = Color3.new(k.R, k.G * (cr and cr.WarmG or 0.95), k.B * (cr and cr.WarmB or 0.78))
	end   -- (lit kit meshes: the blue ambient turns pink violet -- hold a warmer core pink)
	if P.Flow and W._flowPart then c = W._flowPart(P, p, pos, ctx, b)    -- (the Mythic flow, in the gradient's own pass)
	elseif P.Pulse and W._tone then c = W._tone(P, c) end               -- (the Epic pulse, in the gradient's own pass)
	if P.Glow and not p:FindFirstChildOfClass("SpecialMesh") then local k = P.NeonK or 0.62 c = Color3.new(c.R * k, c.G * k, c.B * k) end   -- (Neon brightens MeshParts, not SpecialMeshes)
	gradeBand[p], gradeSet[p] = b, c:ToHex()
	if hx ~= gradeSet[p] then p.Color = c end
end

--- fn, carrying the palette (and the effect context) active now into wherever it runs later (a stepper, a delay). A
--- CryoFX stepper's pieces (the parts it moves this frame) are graded after it. Never wrap a function that yields.
function W.Bind(fn)
	local P, ctx = W.Active, W.Ctx
	if not P then return fn end
	return function(...)
		local parts, cfs = select(3, ...)
		local n0 = (P.Edge and ctx and type(parts) == "table" and type(cfs) == "table") and #parts or nil
		local r = table.pack(runIn(P, ctx, fn, ...))
		if n0 then
			for i = n0 + 1, #parts do
				local cf = cfs[i]
				grade(parts[i], cf and cf.Position, P, ctx)
			end
		end
		return table.unpack(r, 1, r.n)
	end
end

--- a Rare wrap's haze emitters near the effect, graded once as it starts (their hosts sit still): slate at the middle, the
--- Edge tip at the rim
function W.GradeHaze(P, ctx)
	local fx = W.FXName and workspace:FindFirstChild(W.FXName)
	if not (fx and P._hazeHex) then return end
	local core = (P.Glow and P.Main) or (P.Silver and P.Silver:Lerp(P.Edge.Main, 0.35)) or P.Main:Lerp(P.Edge.Main, 0.35)
	local rim = (P.Glow and P.Edge.Main) or P.Edge.Tip or P.Edge.Main
	for _, e in ipairs(fx:GetDescendants()) do
		if e:IsA("ParticleEmitter") and e.Parent:IsA("BasePart") and e.Color.Keypoints[1].Value:ToHex() == P._hazeHex then
			local t = math.clamp((e.Parent.Position - ctx.O).Magnitude / (0.6 * ctx.R), 0, 1)
			e.Color = ColorSequence.new(core:Lerp(rim, t))
			if P.Pulse and W._pulse then W._pulse(e, "emitter", P) end
		end
	end
end

--- every piece under `root` graded in the active Rare wrap (VFXLibrary's Flash Freeze set, each frame)
function W.Grade(root)
	local P, ctx = W.Active, W.Ctx
	if not (P and P.Edge and ctx and typeof(root) == "Instance") then return end
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") then grade(p, p.Position, P, ctx) end
	end
end

--- a literal Default colour, in the active palette
local lit = {}
function W.C(c)
	local P = W.Active
	if not P then return c end
	local m = lit[P.Id]
	if not m then m = {} lit[P.Id] = m end
	local key = c:ToHex()                       -- (a Color3 is a userdata: it keys by reference, not by value)
	local v = m[key]
	if not v then v = colour(c, P) m[key] = v end
	return v
end

--- a particle ColorSequence from Default colours (c0 -> c1) in the active wrap: a Rare wrap's particles glint and stay
--- luminous (Tip -> Silver / Edge), an Uncommon wrap's take its colours
--- a skin's own literal Shard sprite (its art is pale blue, so a pink tint reads lavender) under a Glow wrap: the
--- wrap's Art.Shard, as the Default's Config.Textures.Shard is swapped
function W.Shard(tex)
	local P = W.Active
	return (P and P.Glow and P.Art and P.Art.Shard) or tex
end

function W.CS(c0, c1)
	local cs = ColorSequence.new(c0, c1 or c0)
	local P = W.Active
	if not P then return cs end
	return value(cs, P)
end

--- the pool to use for `default` under the active palette
local pools = setmetatable({}, { __mode = "k" })
--- a gradient copy of a crystal kit piece for the active (Mythic) wrap, or nil: the builder draws its own
function W.KitCopy(template)
	local P = W.Active
	if not (P and P.Grad and RunService:IsClient()) then return nil end
	local A = aurora()
	return A and A.KitCopy(P, template) or nil
end
function W.KitTake(name, style, dress, template)
	local P = W.Active
	if not (P and P.Grad and RunService:IsClient()) then return nil end
	local A = aurora()
	return A and A.KitTake(P, name, style, dress, template) or nil
end

--- the wrap's pooled looks go (its gradient copies became ready, or were released): the next cast builds fresh ones
function W._dropPools(P)
	for _, byP in pairs(pools) do byP[P.Id] = nil end
end

function W.Pool(default)
	local P = W.Active
	if not P then return default end
	local byP = pools[default]
	if not byP then byP = {} pools[default] = byP end
	local p = byP[P.Id]
	if not p then p = {} byP[P.Id] = p end
	return p
end

--- CryoFX's shared burst rig, one per palette (its emitters' colours are live, so a shared one would repaint particles
--- already in the air): built exactly as CryoFX's own, from its KINDS (swapped while this runs)
local rigs = {}
function W.Rig(kinds, host, folder)
	local P = W.Active
	local r = rigs[P.Id]
	if r and r.Host.Parent then return r.Host, r.Em end
	local h = host(CFrame.new(), folder())
	h.Name = "CryoBurstRig_" .. P.Id
	local em = {}
	for kind, spec in pairs(kinds) do
		local e = Instance.new("ParticleEmitter")
		e.Name = kind
		for k, v in pairs(spec.Props) do e[k] = v end
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 0
		e.Enabled = false
		W.Lit(e)
		e.Parent = h
		em[kind] = e
	end
	rigs[P.Id] = { Host = h, Em = em }
	return h, em
end

----------------------------------------------------------------------------------------------------
-- a Glow wrap over a kit mesh whose colours are BAKED in its vertices (the skins' bodies: blue, and a pink multiply over
-- blue reads violet): the part wears a copy of its mesh with the vertex colours run through the wrap's crystal ramp
-- (a FixedSize copy -- the 8-resizable-mesh cap never applies), one per mesh and wrap, built on first sight (it
-- yields, so the first piece glows in the plain tint until it is ready); ApplyMesh puts the part's own mesh back
----------------------------------------------------------------------------------------------------
local AssetService = game:GetService("AssetService")
local vtxBase = setmetatable({}, { __mode = "k" })     -- [part] = its own mesh, while it wears a wrap's copy
local vtxPend = setmetatable({}, { __mode = "k" })     -- [part] = { P, Tint } it waits for
local vtxHold = setmetatable({}, { __mode = "k" })     -- [own mesh] = a MeshPart carrying it (to put a part back)
local vtxSet = {}                                      -- [wrap id][own mesh] = { Holder, Mesh } | retry time (failed) | true (building)
local vtxNeed = setmetatable({}, { __mode = "k" })     -- [own mesh] = any ice-blue vertex (else the part's tint alone does it)
local vtxIn = setmetatable({}, { __mode = "k" })       -- [own mesh] = { Id = the wrap it is recoloured IN PLACE to, Orig }
W._vtx = { Built = 0, Worn = 0, Failed = 0 }

local function vtxColour(c, P, white)
	local h, s = c:ToHSV()
	local l = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
	-- white and frost on a white-bodied piece (the kunai's ring and tang, the globe's lit faces): the panel pink they
	-- showed under the plain tint; blue ice runs the crystal ramp; outlines, greys and any non-ice hue stay
	if s < 0.1 and l > 0.9 then return white and P.Main:Lerp(P.Edge.Main, 0.3) or c end
	if s < 0.05 or h < 0.42 or h > 0.8 then return c end
	local C = P.Crystal or { Base = P.Main, Body = P.Edge.Main, Tip = P.Edge.Tip or P.Highlight }
	local stops = { { 0.25, P.Shadow }, { 0.55, C.Base }, { 0.78, C.Body }, { 0.95, C.Tip } }
	if l <= stops[1][1] then return stops[1][2] end
	for i = 2, #stops do
		local a, b = stops[i - 1], stops[i]
		if l <= b[1] then return a[2]:Lerp(b[2], (l - a[1]) / (b[1] - a[1])) end
	end
	return stops[#stops][2]
end

local function vtxOwn(p)
	if vtxBase[p] then return vtxBase[p] end
	local ok, mc = pcall(function() return p.MeshContent end)
	local o = ok and mc and mc.Object
	return (o and o:IsA("EditableMesh")) and o or nil
end

local function vtxPut(p, holder)
	local sz = p.Size
	local ok = pcall(p.ApplyMesh, p, holder)
	if p.Size ~= sz then p.Size = sz end
	return ok
end

local function vtxWear(p, h, tint)
	local own = vtxOwn(p)
	if not vtxHold[own] then return false end                     -- (no way back: never swap)
	if p.MeshContent.Object ~= h.Mesh then
		if not vtxPut(p, h.Holder) then W._vtx.Failed += 1 return false end
		W._vtx.Worn += 1
	end
	vtxBase[p] = own
	p.Color, p.Material, p.Reflectance = tint, Enum.Material.Neon, 0
	return true
end

--- no copy (still building, or the mesh memory budget is full): the kit's OWN mesh recoloured in place to `P` (nil: its
--- own colours back) -- no memory, but shared by every piece of that kind on this client: the last painter wins
local function vtxInPlace(own, P, white)
	local st = vtxIn[own]
	local want = P and P.Id or nil
	if (st and st.Id) == want then return true end
	if not st then
		if not P then return true end
		st = { Orig = {} }
		if not pcall(function() for _, id in ipairs(own:GetColors()) do st.Orig[id] = own:GetColor(id) end end) then return false end
		vtxIn[own] = st
	end
	local ok = pcall(function()
		for id, c in pairs(st.Orig) do own:SetColor(id, P and vtxColour(c, P, white) or c) end
	end)
	if ok then st.Id = want end
	return ok
end

--- `p` back in its own mesh, in its own colours (no wrap, or a wrap without the swap)
local function vtxBack(p)
	vtxPend[p] = nil
	local own = vtxBase[p]
	if own then
		vtxBase[p] = nil
		local holder = vtxHold[own]
		if holder then vtxPut(p, holder) end
	else
		own = p:IsA("MeshPart") and vtxOwn(p)
	end
	if own and vtxIn[own] and vtxIn[own].Id then vtxInPlace(own, nil) end
end

--- true when `p` now glows in the wrap: a mesh with ice-blue vertices wears the wrap's copy (in `tint`); one with only
--- white / grey vertices needs no copy -- the part's own colour carries it (a white body: the panel pink)
local function vtxSwap(p, P, tint, white)
	if not p:IsA("MeshPart") then return false end
	local own = vtxOwn(p)
	if not own then return false end
	if vtxNeed[own] == nil then
		local need = false
		pcall(function()
			for _, id in ipairs(own:GetColors()) do
				local c = own:GetColor(id)
				if vtxColour(c, P, false) ~= c then need = true break end
			end
		end)
		vtxNeed[own] = need
	end
	if not vtxNeed[own] then
		vtxBack(p)
		local c = white and P.Main:Lerp(P.Edge.Main, 0.3)
		local k = P.NeonK or 0.62
		p.Color, p.Material, p.Reflectance = c and Color3.new(c.R * k, c.G * k, c.B * k) or tint, Enum.Material.Neon, 0
		return true
	end
	local byP = vtxSet[P.Id] or {}
	vtxSet[P.Id] = byP
	local h = byP[own]
	if type(h) == "table" then vtxPend[p] = nil return vtxWear(p, h, tint) end
	if type(h) == "number" and os.clock() >= h then h = nil byP[own] = nil end   -- (a failed copy: tried again later)
	if h == nil then
		byP[own] = true
		task.spawn(function()
			local ok, copy = pcall(function() return AssetService:CreateEditableMeshAsync(Content.fromObject(own), { FixedSize = true }) end)
			local holder
			if ok and copy then
				pcall(function() for _, id in ipairs(copy:GetColors()) do copy:SetColor(id, vtxColour(copy:GetColor(id), P, white)) end end)
				local ok2, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(copy)) end)
				local ok3, mo = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(own)) end)
				if ok2 and mp and ok3 and mo then holder = mp vtxHold[own] = vtxHold[own] or mo end
			end
			byP[own] = holder and { Holder = holder, Mesh = copy } or (os.clock() + 30)
			if not holder then W._vtx.Failed += 1 return end
			W._vtx.Built += 1
			for part, w in pairs(vtxPend) do                         -- (the pieces painted in place move onto the copy)
				if w.P == P and vtxOwn(part) == own then
					vtxPend[part] = nil
					if part.Parent then vtxWear(part, byP[own], w.Tint) end
				end
			end
			if vtxIn[own] and vtxIn[own].Id == P.Id then vtxInPlace(own, nil) end
		end)
	end
	if vtxInPlace(own, P, white) then                             -- (meanwhile, or for good when the budget is full)
		vtxPend[p] = { P = P, Tint = tint }
		p.Color, p.Material, p.Reflectance = tint, Enum.Material.Neon, 0
		return true
	end
	return false
end

--- a SKIN kit piece (FrostLotusKit / FrostbladeKit / SnowGlobeKit object, or a shot look made of one) in the active wrap,
--- or put back to its own colours when there is none (a pooled piece can come back to a Default caster): a white
--- mesh body (its colours in the vertices) takes the multiply tint, everything else snaps through the band map
local KIT_PARTS = { "Body", "Tip", "Heart", "Core", "Line" }
function W.PaintKit(o)
	if type(o) ~= "table" then return end
	local P = W.Active
	local list = o.P or {}
	if not o.P then for _, k in ipairs(KIT_PARTS) do if typeof(o[k]) == "Instance" then list[#list + 1] = o[k] end end end
	if not o.P and P and (P.Solid or P.Glow) and typeof(o.Edge) == "Instance" then list[#list + 1] = o.Edge end   -- (Snow Globe's shot face)
	for _, p in ipairs(list) do
		if p:IsA("BasePart") then
			local base = p:GetAttribute("WrapBase")
			if typeof(base) ~= "Color3" and P then
				base = p.Color
				p:SetAttribute("WrapBase", base)
				p:SetAttribute("WrapBaseMat", p.Material.Name)
				p:SetAttribute("WrapBaseRefl", p.Reflectance)
			end
			local bm = p:GetAttribute("WrapBaseMat")
			local mat = bm and Enum.Material[bm] or p.Material
			local k = (p:IsA("MeshPart") and (P and P.NeonK or 0.62)) or 1
			local grey = Color3.new(k, k, k)
			local white = typeof(base) == "Color3" and math.min(base.R, base.G, base.B) > 0.97
			local pink = P and P.Glow and P.Main:Lerp(P.Edge.Main, 0.5)
			local glowTint                                                  -- (a Glow wrap: what the piece glows in)
			if pink then
				if white then glowTint = grey
				elseif mat == Enum.Material.Neon then
					glowTint = colour(base, P)
					if math.min(glowTint.R, glowTint.G, glowTint.B) > 0.85 then   -- (a near-white glow on a mesh blows out white:
						local c = P.Main:Lerp(P.Edge.Main, 0.3)                    -- the panel pink, at the mesh's Neon strength)
						glowTint = Color3.new(c.R * k, c.G * k, c.B * k)
					end
				else glowTint = Color3.new(pink.R * k, pink.G * k, pink.B * k) end
			end
			if P and P.Glow and not p:GetAttribute("CryoFrost") and vtxSwap(p, P, glowTint, white) then
				-- (a mesh with its colours in the vertices now wears the wrap's copy: the part glows neutral, the vertices pink)
			elseif P and P.Glow and mat ~= Enum.Material.Neon then          -- (a Glow wrap: kit pieces glow pink, like the panels)
				p.Color, p.Material, p.Reflectance = Color3.new(pink.R * k, pink.G * k, pink.B * k), Enum.Material.Neon, 0
				-- (the frozen crust: blue baked into its vertex colours, which no tint undoes -- hidden; the pink fill shows the freeze)
				if p:GetAttribute("CryoFrost") then p.LocalTransparencyModifier = 1 end
			elseif P and P.Solid then
				vtxBack(p)
				-- a solid wrap (Black Ice): the white mesh bodies (their colours in the vertices) and every dark piece are
				-- glossy black; a light piece GLOWS (Neon: lit whites render blue in this game)
				if mat == Enum.Material.Neon then
					p.Color, p.Material, p.Reflectance = colour(base, P), Enum.Material.Neon, 0
				else
					W.Solidify(p, P)
				end
			else
				if not (P and P.Glow) then vtxBack(p) end                     -- (a Glow piece may wait for its copy)
				if bm and p.Material ~= mat then p.Material = mat end              -- (back from a solid wrap)
				if p:GetAttribute("CryoFrost") and p.LocalTransparencyModifier == 1 then p.LocalTransparencyModifier = 0 end
				local rf = p:GetAttribute("WrapBaseRefl")
				if type(rf) == "number" and p.Reflectance ~= rf then p.Reflectance = rf end
				if P and P.Glow and mat == Enum.Material.Neon and not white then
					p.Color = glowTint                                          -- (a Glow piece waiting for its copy)
				elseif P then
					local white = math.min(base.R, base.G, base.B) > 0.97 and mat ~= Enum.Material.Neon
					p.Color = white and artTint(P) or colour(base, P)
				elseif typeof(base) == "Color3" and p.Color ~= base then
					p.Color = base
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- who draws in which wrap
----------------------------------------------------------------------------------------------------
local palettes = {}
local function palette(id)
	if type(id) ~= "string" then return nil end
	local P = palettes[id]
	if P then return P end
	local s = SkinCatalog.Skins[id]
	if not (s and s.Wrap == "Cryo" and s.Palette) then return nil end
	P = { Id = id, Main = s.Palette.Main, Shadow = s.Palette.Shadow, Highlight = s.Palette.Highlight, Accent = s.Palette.Accent, Rest = s.Palette.Rest, Art = s.Art }
	if s.Palette.Edge then          -- a Rare wrap: Main / Shadow are the core tone, Edge the rim's
		P.Edge = { Main = s.Palette.Edge.Main, Shadow = s.Palette.Edge.Shadow, Tip = s.Palette.Edge.Tip }
		P.Solid, P.Silver = s.Palette.Solid, s.Palette.Silver
		P.Pulse, P.Motes, P.Glow = s.Palette.Pulse, s.Palette.Motes, s.Palette.Glow
		P.Over, P.OpaqueStyles, P.OpaqueT, P.Twin = s.Palette.Over, s.Palette.OpaqueStyles, s.Palette.OpaqueT, s.Palette.Twin
		P.StyleT, P.Crystal = s.Palette.StyleT, s.Palette.Crystal
		P.Life = s.Palette.Life
		P.Flow, P.Tints, P.Curtains, P.Grad, P.Floor = s.Palette.Flow, s.Palette.Tints, s.Palette.Curtains, s.Palette.Grad, s.Palette.Floor
		if P.Glow then
			P._disc = (P.Tints and P.Tints.DiscTint) or warm(P.Main:Lerp(P.Edge.Main, 0.5))
			P._allHex = {}
			for _, c in ipairs({ P.Main, P.Shadow, P.Highlight, P.Accent, P.Edge.Main, P.Edge.Shadow, P.Edge.Tip }) do P._allHex[c:ToHex()] = true end
		end
		if P.Pulse then
			P._pulseHex = {}
			for _, c in ipairs({ P.Accent, P.Highlight, P.Edge.Main, P.Edge.Tip }) do P._pulseHex[c:ToHex()] = true end
		end
		if P.Flow and W._flowInit then W._flowInit(P) end
		if P.Grad and RunService:IsClient() and aurora() then task.defer(aurora().Prepare, P) end   -- (warm the copies)
		P._mainHex, P._shadowHex = P.Main:ToHex(), P.Shadow:ToHex()
		P._hazeHex = (P.Silver or P.Main:Lerp(P.Edge.Main, 0.5)):ToHex()
	end
	palettes[id] = P
	return P
end
W.Palette = palette

--- fn(...) in the wrap of whoever froze `model` (a wrapped effect tags its victims, CryoWrapBy) -- the frozen look
function W.RunFor(model, fn, ...)
	local id = typeof(model) == "Instance" and model:GetAttribute("CryoWrapBy")
	local P = id and palette(id)
	if not P then return fn(...) end
	return runIn(P, nil, fn, ...)
end

--- a skin piece made OUTSIDE an effect (Frost Lotus's held lotus, third person and first) in `character`'s wrap
function W.PaintFor(o, character)
	local P = W.For and W.For(character)
	if not P then W.PaintKit(o) return end
	runIn(P, nil, W.PaintKit, o)
end

function W.For(caster)
	if typeof(caster) ~= "Instance" then return nil end
	if RunService:IsStudio() and caster:GetAttribute("WrapStudio") then return palette(caster:GetAttribute("WrapStudio")) end
	local plr = Players:GetPlayerFromCharacter(caster)
	if not plr then return nil end
	if (plr:GetAttribute("Element") or "Cryo") ~= "Cryo" then return nil end       -- a borrowed Cryo Technique: Default
	-- (a wrap goes over a Cryo skin too: the skin keeps its shapes, the wrap gives the colours -- PaintKit)
	return palette(SkinCatalog.ElementWrap and SkinCatalog.ElementWrap(plr, "Cryo"))
end

----------------------------------------------------------------------------------------------------
-- installing: the palette tables, and the entry points (each names its caster: an argument, or "d" = the payload's
-- Caster / Character)
----------------------------------------------------------------------------------------------------
local CRYOFX = { Shatter = 3, ShardImpact = 4, ColdMomentumMark = 1, Blizzard = "d", BlizzardEnd = "d",
	DeepFreezeArmed = "me", DeepFreezeGone = "me", DeepFreeze = "d",            -- (the trap's arming goes to its owner alone)
	MirrorCage = "d", MirrorCageEnd = "d", MirrorCageFree = "d",
	ChillStacks = "c" }                -- (the M1's chill on its target: the SHOOTER's wrap, never the victim's)
local VFX = { FireIcicleShard = 6, CastFlashFreeze = 3 }
-- where each effect's gradient is measured from (its origin, the radius its edge sits at)
local ORIGIN = {
	MirrorCage = function(a) return a[1].Center, 20 end,
	Blizzard = function(a) return a[1].Center, a[1].Radius or 32 end,
	DeepFreeze = function(a) return a[1].At or a[1].Position, 8 end,
	Shatter = function(a) local r = a[1]:FindFirstChild("HumanoidRootPart") return r and r.Position, 6 end,
	ShardImpact = function(a) return a[1].Position, 4 end,
	ColdMomentumMark = function(a) return a[2].Position, 3 end,
	ChillStacks = function(a) local r = a[1].Character and a[1].Character:FindFirstChild("HumanoidRootPart") return r and r.Position, 3 end,
	FireIcicleShard = function(a) return a[1], 30 end,
	-- a[4]: the aimed centre (2026-10-18), else the caster's root as before
	CastFlashFreeze = function(a) return typeof(a[4]) == "Vector3" and a[4] or a[1].Position, 20 end,
}

-- the bodies an effect freezes (tagged with the caster's wrap for the frozen look)
local TAG = {
	MirrorCage = function(a) local t = {} for _, v in ipairs(a[1].Victims or {}) do t[#t + 1] = v.Model end return t end,
	Shatter = function(a) return { a[1] } end,
	DeepFreeze = function(a) return { a[1].Victim } end,
	ChillStacks = function(a) return { a[1].Character } end,
}

local function hook(M, name, how)
	local f = M[name]
	if type(f) ~= "function" then return end
	M[name] = function(...)
		local a = table.pack(...)
		local c
		if how == "me" then
			c = Players.LocalPlayer and Players.LocalPlayer.Character
		elseif how == "d" then
			c = type(a[1]) == "table" and (a[1].Caster or a[1].Character) or nil
		elseif how == "c" then
			c = type(a[1]) == "table" and a[1].Caster or nil
		else
			c = a[how]
		end
		local P = W.For(c)
		if TAG[name] then                                      -- (its victims' frozen look in this caster's wrap)
			pcall(function()
				for _, m in ipairs(TAG[name](a)) do
					if typeof(m) == "Instance" then m:SetAttribute("CryoWrapBy", P and P.Id or nil) end
				end
			end)
		end
		if not P then return f(...) end
		local ctx
		if P.Edge and ORIGIN[name] then
			local ok, O, R = pcall(ORIGIN[name], a)
			if ok and typeof(O) == "Vector3" then ctx = { O = O, R = R or 10 } end
		end
		if not ctx then return runIn(P, ctx, f, ...) end
		local r = table.pack(runIn(P, ctx, f, ...))
		pcall(W.GradeHaze, P, ctx)
		if (P.Pulse or P.Motes) and W.Epic then pcall(W.Epic, P, ctx, name, a, c) end
		return table.unpack(r, 1, r.n)
	end
end

----------------------------------------------------------------------------------------------------
-- EPIC extras (Palette.Pulse / Palette.Motes -- Sakura Frost). PULSE: the wrap's own glow pieces (Neon parts and lights in
-- its light hexes, its graded haze) breathe -- a sine of +-Amp brightness every Period s, drifting toward Tip at the peak;
-- held at mid under Reduce Flashing; one RenderStepped loop, alive only while pieces are (each expires after 15 s or
-- when re-dressed). MOTES: a few Highlight glints (the built-in sparkle Frost Lotus uses) through VFXLibrary.Emitter
-- (= emitter(): density, Reduce Enemy VFX) at the M1 impact, the hands on cast, and along the Flash Freeze edge.
----------------------------------------------------------------------------------------------------
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local pulseItems, pulseConn = {}, nil
local function setting(k)
	local ok, v = pcall(function()
		local s = require(game:GetService("ReplicatedStorage").Spellshot.SpellshotSettings)
		if k == "Density" then return s.EffectDensity or 1 end
		return s.Get and s.Get(k)
	end)
	return ok and v or nil
end
local function pulseStep()
	local now, hold, any = os.clock(), setting("ReduceFlashing") == true, false
	for inst, it in pairs(pulseItems) do
		if not inst.Parent or now > it.Until then
			pulseItems[inst] = nil
		else
			any = true
			local pu = it.P.Pulse
			local s = hold and 0 or math.sin(2 * math.pi * now / pu.Period)
			local k, w, tip = 1 + pu.Amp * s, math.max(0, s) * pu.TipDrift, it.P.Edge.Tip
			local function tone(c)
				c = c:Lerp(tip, w)
				return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
			end
			if it.Kind == "flow" then W._flowStep(inst, it)
			elseif it.Kind == "twin" then
				local src = it.Src
				if not src.Parent then inst:Destroy() pulseItems[inst] = nil
				else inst.Transparency, inst.Color3 = src.Transparency, src.Color3 end
			elseif it.Kind == "part" then
				if inst.Color ~= it.Last then pulseItems[inst] = nil      -- (re-dressed by somebody else)
				else inst.Color = tone(it.Base) it.Last = inst.Color end
			elseif it.Kind == "emitter" then
				local kps = {}
				for i, kp in ipairs(it.Base.Keypoints) do kps[i] = ColorSequenceKeypoint.new(kp.Time, tone(kp.Value)) end
				inst.Color = ColorSequence.new(kps)
			else
				inst.Brightness = it.Base * k
			end
		end
	end
	if AUR and AUR._acc then AUR._acc("flow", os.clock() - now) end
	if not any and pulseConn then pulseConn:Disconnect() pulseConn = nil end
end
function W._pulse(inst, kind, P)
	if pulseItems[inst] then return end
	local base = (kind == "light") and inst.Brightness or inst.Color
	pulseItems[inst] = { Kind = kind, Base = base, Last = (kind == "part") and inst.Color or nil, P = P, Until = os.clock() + 15 }
	if not pulseConn then pulseConn = RunService.RenderStepped:Connect(pulseStep) end
end
local function pulseScan(P)
	local fx = W.FXName and workspace:FindFirstChild(W.FXName)
	if not (fx and P._pulseHex) then return end
	for _, d in ipairs(fx:GetDescendants()) do
		if P.Glow and P._allHex and d:IsA("BasePart") and d.Material ~= Enum.Material.Neon and P._allHex[d.Color:ToHex()] then
			local sm = d:FindFirstChildOfClass("SpecialMesh")   -- (a piece the gradient pass never sees)
			local k = sm and 1 or P.NeonK or 0.62
			d.Material, d.Reflectance, d.Color = Enum.Material.Neon, 0, Color3.new(d.Color.R * k, d.Color.G * k * (sm and 0.95 or 1), d.Color.B * k * (sm and 0.78 or 1))
		end
		if not pulseItems[d] and not (d.Parent and string.match(d.Parent.Name, "^CryoBurstRig")) then
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Transparency < 1 and P._pulseHex[d.Color:ToHex()] then
				W._pulse(d, "part", P)
			elseif d:IsA("PointLight") and P._pulseHex[d.Color:ToHex()] then
				W._pulse(d, "light", P)
			end
		end
	end
end
--- the pulse tone for colour `c` now (graded pieces: called in the gradient pass each frame); held at mid under Reduce
--- Flashing (the setting read once a second)
local toneT, toneS, rfT, rfOn = -1, 0, -10, false
function W._tone(P, c)
	local now = os.clock()
	if now - rfT > 1 then rfT, rfOn = now, setting("ReduceFlashing") == true end
	if now ~= toneT then toneT, toneS = now, math.sin(2 * math.pi * now / P.Pulse.Period) end
	local s = rfOn and 0 or toneS
	local k, w = 1 + P.Pulse.Amp * s, math.max(0, s) * P.Pulse.TipDrift
	c = c:Lerp(P.Edge.Tip, w)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

W.PulseCount = function() local n = 0 for _ in pairs(pulseItems) do n += 1 end return n end
local moteEm = {}
local function moteHost(pos, name)
	local fx = W.FXName and workspace:FindFirstChild(W.FXName)
	local h = Instance.new("Part")
	h.Name, h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.Transparency = name, true, false, false, false, 1
	h.Size, h.CFrame = Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos)
	h.Parent = fx or workspace
	return h
end
local function moteProps(P, rate)
	return { Texture = SPARKLE, Color = P._twinkleCS or ColorSequence.new(P.Accent, P.Highlight), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (P.Motes and P.Motes.Size) or 0.32), NumberSequenceKeypoint.new(1, 0.1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), Drag = 1, Acceleration = Vector3.new(0.6, -1.2, 0.3),
		Rate = rate or 0 }
end
local function motes(P, pos, n, caster)
	if not (W._VFX and W._VFX.Emitter and typeof(pos) == "Vector3" and n and n > 0) then return end
	local e = moteEm[P.Id]
	if not (e and e.Parent and e.Parent.Parent) then
		e = W._VFX.Emitter(moteHost(pos, "EpicMotes_" .. P.Id), moteProps(P))
		moteEm[P.Id] = e
	end
	local d = setting("Density") or 1
	if setting("ReduceFlashing") == true then d *= 0.5 end
	if setting("ThinEnemyVFX") == true and caster ~= (Players.LocalPlayer and Players.LocalPlayer.Character) then d *= 0.5 end
	local k = math.floor(n * d + 0.5)
	if k <= 0 then return end
	e.Parent.CFrame = CFrame.new(pos)
	e:Emit(k)
end
local function twinDiscs(P)
	local fx = W.FXName and workspace:FindFirstChild(W.FXName)
	if not (fx and P._disc) then return end
	for _, d in ipairs(fx:GetDescendants()) do
		if d:IsA("Decal") and d.Name ~= "EpicTwin" and not d:GetAttribute("EpicTwinned") then
			local c = d.Color3
			if math.abs(c.R - P._disc.R) + math.abs(c.G - P._disc.G) + math.abs(c.B - P._disc.B) < 0.03 then
				d:SetAttribute("EpicTwinned", true)
				for _ = 1, 2 do
					local t = d:Clone()
					t.Name = "EpicTwin"
					t.Parent = d.Parent
					pulseItems[t] = { Kind = "twin", Src = d, P = P, Until = os.clock() + 30 }
				end
				if not pulseConn then pulseConn = RunService.RenderStepped:Connect(pulseStep) end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- MYTHIC extras (Palette.Flow / Palette.Curtains -- Aurora). FLOW: the wrap's five stops mixed in OKLab (no grey middle),
-- read at a travelling phase -- a ping-pong through the stops every Flow.Period s, offset by each piece's place in the
-- effect (out from the centre on discs and rings, up the dome on the cage, base to tip on spikes, which weigh height
-- more), so three or four stops show at once and move; held at Flow.Hold (all five showing, still) under Reduce
-- Flashing. Graded pieces take it in the gradient pass (W._flowPart); everything else of the effect that wears the
-- wrap's colours -- parts, lights, decals, particles, trails, beams -- rides the pulse loop as a "flow" item (tagged
-- AuroraFlow so a pooled piece is picked up again). CURTAINS: tall squashed soft-smoke streaks rising from a ring,
-- coloured base to top through the stops, with sparse twinkles, through VFXLibrary.Emitter (= emitter()); Cold Momentum:
-- a thin aurora ribbon Trail behind the runner (gated like emitter(): density, Reduce Enemy VFX).
----------------------------------------------------------------------------------------------------
do
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	local N = 48
	local P_SPAN = 1.1                                                 -- (set from the wrap: Flow.Span)
	local function toLin(x) return x <= 0.04045 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4 end
	local function toSrgb(x) x = math.clamp(x, 0, 1) return x <= 0.0031308 and x * 12.92 or 1.055 * x ^ (1 / 2.4) - 0.055 end
	local function oklab(c)
		local r, g, b = toLin(c.R), toLin(c.G), toLin(c.B)
		local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
		local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
		local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
		return { 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s }
	end
	local function fromOklab(L, a, b)
		local l = (L + 0.3963377774 * a + 0.2158037573 * b) ^ 3
		local m = (L - 0.1055613458 * a - 0.0638541728 * b) ^ 3
		local s = (L - 0.0894841775 * a - 1.2914855480 * b) ^ 3
		return Color3.new(toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
			toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s), toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
	end

	--- the wrap's flow table (N + 1 colours through the stops), its particle sequence and the hexes its pieces wear
	function W._flowInit(P)
		local st = P.Flow.Stops
		P_SPAN = P.Flow.Span
		local labs = {}
		for i, c in ipairs(st) do labs[i] = oklab(c) end
		P._lut = {}
		local pos = P.Flow.Pos                                       -- (where each stop sits on the ramp: a short teal-to-violet
		for i = 0, N do                                              -- leg keeps the azure middle, Default's hue, brief)
			local u, k = i / N, 1
			while k < #st - 1 and u > (pos and pos[k + 1] or k / (#st - 1)) do k += 1 end
			local a0, a1 = pos and pos[k] or (k - 1) / (#st - 1), pos and pos[k + 1] or k / (#st - 1)
			local f, A, B = math.clamp((u - a0) / (a1 - a0), 0, 1), labs[k], labs[k + 1]
			P._lut[i] = fromOklab(A[1] + (B[1] - A[1]) * f, A[2] + (B[2] - A[2]) * f, A[3] + (B[3] - A[3]) * f)
		end
		local kps = {}
		for i, c in ipairs(st) do kps[i] = ColorSequenceKeypoint.new((i - 1) / (#st - 1) * 0.85, c) end
		kps[#kps + 1] = ColorSequenceKeypoint.new(1, st[#st]:Lerp(P.Highlight, 0.4))        -- (airborne: never ends dark)
		P._flowCS = ColorSequence.new(kps)
		P._twinkleCS = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.Highlight), ColorSequenceKeypoint.new(0.4, st[2]),
			ColorSequenceKeypoint.new(0.75, st[4]), ColorSequenceKeypoint.new(1, st[5]) })
		local k = P.NeonK or 0.62
		P._flowHex = {}
		-- (as worn: plain, at the Neon strength of a MeshPart, and as pulseScan warms a crystal -- G x0.95, B x0.78)
		local function add(c, v)
			for _, m in ipairs({ { 1, 1, 1 }, { k, k, k }, { 1, 0.95, 0.78 } }) do
				local r, g, b = c.R * m[1] * 255, c.G * m[2] * 255, c.B * m[3] * 255     -- (a part keeps 8 bits: rounded or cut)
				P._flowHex[string.format("%02x%02x%02x", math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))] = v or true
				P._flowHex[string.format("%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))] = v or true
			end
		end
		for _, c in ipairs({ P.Main, P.Edge.Main, P.Edge.Shadow }) do add(c) end   -- (v6: the pale pieces -- cracks, tips -- stay pale)
		for _, f in ipairs({ 0.3, 0.5, 0.55, 0.75 }) do add(P.Main:Lerp(P.Edge.Main, f)) end
		add(P.Shadow, "Shadow")                                      -- (the spikes' bases: they flow, a little deeper)
		for _, c in pairs(P.Tints or {}) do if math.max(c.R, c.G, c.B) <= 1 then add(c) end end
	end

	local rfT, rfOn = -10, false
	local function phase(P)
		local now = os.clock()
		if now - rfT > 1 then                                        -- (Studio: StudioReduceFlashing stands in for the setting)
			rfT, rfOn = now, setting("ReduceFlashing") == true or (RunService:IsStudio() and workspace:GetAttribute("StudioReduceFlashing") == true)
		end
		return rfOn and P.Flow.Hold or now / P.Flow.Period, rfOn
	end
	local function flowAt(P, t, ph)
		if t < 0 then                                                -- (the cage: -1 - h, h = its height 0..1)
			local h = -1 - t
			local u = math.clamp(0.05 + 0.85 * h + 0.16 * math.sin(2 * math.pi * (ph - 0.5 * h)), 0, 1)
			return P._lut[math.floor(u * N + 0.5)]
		end
		local x = (t * P.Flow.Span - ph) % 1
		return P._lut[math.floor((1 - math.abs(2 * x - 1)) * N + 0.5)]
	end
	W._flowAt = function(P, t, ph) return flowAt(P, t, ph or phase(P)) end   -- (CryoAurora's copies and curtains)
	local function metric(pos, it, crystal)
		local d = pos - it.O
		local up = math.max(0, pos.Y - (it.G or it.O.Y))
		if it.Mode == "height" then return -1 - math.clamp(up / it.H + (crystal and 0.15 or 0), 0, 1) end
		-- out from the centre (height weighs more on a crystal: base to tip), plus one whole cycle round the ring
		local ang = (math.atan2(d.Z, d.X) / (2 * math.pi)) % 1
		return (Vector3.new(d.X, 0, d.Z).Magnitude + (crystal and 2.5 or 1) * up) / it.R + ang / P_SPAN
	end
	local function lift(P, c, t) return c:Lerp(P.Highlight, t < 0 and 0.1 or math.clamp(t - 0.55, 0, 0.3)) end   -- (crystal tips: white-hot)
	local function bright(P, c, hold)
		local pu = P.Pulse
		if not pu or hold then return c end
		local k = 1 + pu.Amp * math.sin(2 * math.pi * os.clock() / pu.Period)
		return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
	end

	--- a graded piece's colour (the gradient pass, each frame it moves)
	function W._flowPart(P, p, pos, ctx, b)
		local crystal = p:FindFirstChildOfClass("SpecialMesh") ~= nil
		local ph, hold = phase(P)
		local t = metric(pos, ctx, crystal)
		local c = flowAt(P, t, ph)
		if crystal then c = lift(P, c, t) elseif b == "Shadow" then c = c:Lerp(P.Shadow, 0.22) end
		return bright(P, c, hold)
	end

	--- one flow item, each frame (the pulse loop); a piece re-dressed by anybody else is let go
	function W._flowStep(inst, it)
		local P = it.P
		local S = AUR and AUR.Sample                                   -- (v7: one continuous field for every surface)
		if S then                                                      -- (each piece every other frame: steps under a level)
			it.Odd = not it.Odd
			if it.Odd then return end
		end
		if it.Is == "grad" then
			if AUR then AUR.FieldTint(inst) end
			return
		end
		local ph, hold = phase(P)
		if it.Is == "part" then
			if inst.Color ~= it.Last then pulseItems[inst] = nil return end
			local c
			if S then
				local q = inst.Position
				c = S(q.X, q.Z, q.Y)
				if it.Shadow then c = c:Lerp(P.Shadow, 0.3) end
			else
				local t = metric(inst.Position, it, it.Crystal)
				c = flowAt(P, t, ph)
				if it.Shadow then c = c:Lerp(P.Shadow, 0.3) elseif it.Crystal then c = lift(P, c, t) end
				c = bright(P, c, hold)
			end
			local k = it.K
			if k ~= 1 then c = Color3.new(c.R * k, c.G * k, c.B * k) end
			inst.Color = c
			it.Last = inst.Color
		elseif it.Is == "light" then
			if inst.Color ~= it.Last then pulseItems[inst] = nil return end
			local pp = inst.Parent
			local q = pp and (pp:IsA("BasePart") and pp.Position or (pp:IsA("Attachment") and pp.WorldPosition))
			inst.Color = (S and q) and S(q.X, q.Z, q.Y) or flowAt(P, it.T, ph)
			it.Last = inst.Color
		elseif it.Is == "decal" then                                 -- (held: an effect re-tinting its disc each frame is overruled)
			-- (v8: the disc art under the floor: the floor look's own calm colour; the storm's swirl layers: the field)
			local pp = inst.Parent
			local q = (pp and pp:IsA("BasePart")) and pp.Position or Vector3.zero
			local c
			if S and not it.Swirl and AUR.DiscColour then c = AUR.DiscColour(P)
			elseif S then c = S(q.X + it.T * 40, q.Z - it.T * 25, 0)
			else
				local u = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(2 * math.pi * (ph + it.T)))
				c = P._lut[math.floor(u * 48 + 0.5)]
				if not it.Swirl then c = c:Lerp(P.Highlight, 0.45) end
			end
			local g = it.Swirl and 1 or (P.Flow.DiscGain or 1)
			inst.Color3 = Color3.new(c.R * g, c.G * g, c.B * g)
			it.Last = inst.Color3
		else                                                         -- particles, trails, beams: 15 a second
			if inst.Color ~= it.Last then pulseItems[inst] = nil return end
			local now = os.clock()
			if it.Next and now < it.Next then return end
			it.Next = now + 1 / 15
			local pp = inst.Parent
			local q = pp and (pp:IsA("BasePart") and pp.Position or (pp:IsA("Attachment") and pp.WorldPosition)) or Vector3.zero
			local kps = {}
			for i = 0, 4 do
				kps[i + 1] = ColorSequenceKeypoint.new(i / 4, S and S(q.X + i * 3 + it.T * 30, q.Z - i * 2, 0) or flowAt(P, it.T + i * 0.3, ph))
			end
			if it.Bright then kps[5] = ColorSequenceKeypoint.new(1, kps[5].Value:Lerp(P.Highlight, 0.4)) end
			inst.Color = ColorSequence.new(kps)
			it.Last = inst.Color
		end
	end

	local function reg(inst, it)
		it.Kind, it.Until = "flow", os.clock() + 20
		inst:SetAttribute("AuroraFlow", true)
		pulseItems[inst] = it
		if not pulseConn then pulseConn = RunService.RenderStepped:Connect(pulseStep) end
	end
	local function seqWrap(P, cs)
		for _, kp in ipairs(cs.Keypoints) do if P._flowHex[kp.Value:ToHex()] then return true end end
		return false
	end

	--- every piece of the effect near ctx that wears the wrap's colours joins the flow
	local function scan(P, ctx)
		local fx = W.FXName and workspace:FindFirstChild(W.FXName)
		if not (fx and ctx) then return end
		local far = ctx.R * 1.6 + 8
		for _, d in ipairs(fx:GetDescendants()) do
			local cur = pulseItems[d]
			if not (cur and cur.Kind == "flow") and d.Name ~= "EpicTwin" then
				local tagged = d:GetAttribute("AuroraFlow")
				local base = { P = P, O = ctx.O, R = ctx.R, G = ctx.G, H = ctx.H, Mode = ctx.Mode }
				if d:IsA("BasePart") and d:GetAttribute("AuroraGrad") then
					local dv = d.Position - ctx.O
					if dv.Magnitude < far then
						if AUR then AUR.Assign(d, math.atan2(dv.Z, dv.X) / (2 * math.pi)) end   -- (the wave's phase round the zone)
						if d.Transparency < 1 then base.Is = "grad" reg(d, base) end
					end
				elseif d:IsA("BasePart") then
					local hx = d.Color:ToHex()
					if d.Transparency < 1 and (tagged or P._flowHex[hx] or gradeSet[d] == hx) and (d.Position - ctx.O).Magnitude < far then
						base.Is, base.Last, base.Crystal = "part", d.Color, d:FindFirstChildOfClass("SpecialMesh") ~= nil
						base.Shadow = P._flowHex[hx] == "Shadow"
						if P.Glow and d.Material ~= Enum.Material.Neon then d.Material, d.Reflectance = Enum.Material.Neon, 0 end   -- (late pieces: self-lit too)
						base.K = (d:IsA("MeshPart") and d.Material == Enum.Material.Neon) and (P.NeonK or 0.62) or 1
						reg(d, base)
					end
				elseif d:IsA("Light") then
					if tagged or P._flowHex[d.Color:ToHex()] then
						local pp = d.Parent
						local pos = pp and (pp:IsA("BasePart") and pp.Position or (pp:IsA("Attachment") and pp.WorldPosition))
						base.Is, base.Last, base.T = "light", d.Color, pos and metric(pos, base) or 0
						reg(d, base)
					end
				elseif d:IsA("Decal") then
					local c, tc, ta = d.Color3, P.Tints and P.Tints.DiscTint, P.Tints and P.Tints.ArtTint
					local function near(t) return t and math.abs(c.R - t.R) + math.abs(c.G - t.G) + math.abs(c.B - t.B) < 0.05 end
					if tagged or near(tc) or near(ta) then                       -- (the discs and the storm's swirl layers)
						local pp = d.Parent
						base.Is, base.Last, base.T = "decal", c, ((pp and pp:IsA("BasePart")) and metric(pp.Position, base) or 0)
							+ (near(ta) and ((table.find(d.Parent:GetChildren(), d) or 0) % 6) * 0.17 or 0)
						base.Swirl = near(ta)
						reg(d, base)
					end
				elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
					if tagged or seqWrap(P, d.Color) then
						base.Is, base.Last, base.T, base.Bright = "seq", d.Color, 0, d:IsA("ParticleEmitter")
						reg(d, base)
					end
				end
			end
		end
	end

	--- Cold Momentum: a thin aurora ribbon behind the runner while its marks keep coming
	local ribbons = setmetatable({}, { __mode = "k" })
	local function ribbon(P, ch)
		local root = typeof(ch) == "Instance" and ch:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local mine = Players.LocalPlayer and ch == Players.LocalPlayer.Character
		if (setting("Density") or 1) < 0.6 or (not mine and setting("ThinEnemyVFX") == true) then return end
		local r = ribbons[ch]
		if not (r and r.T.Parent) then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name, a0.Position, a1.Position = "AuroraRibbon0", "AuroraRibbon1", Vector3.new(0, -2.2, 0.3), Vector3.new(0, -0.6, 0.3)
			a0.Parent, a1.Parent = root, root
			local t = Instance.new("Trail")
			t.Name, t.Attachment0, t.Attachment1, t.Lifetime, t.MinLength = "AuroraRibbon", a0, a1, 0.55, 0.1
			t.LightEmission, t.LightInfluence, t.FaceCamera, t.Color = 1, 0, false, P._flowCS
			t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.4) })
			t.Parent = root
			r = { T = t }
			ribbons[ch] = r
		end
		r.Until = os.clock() + 1
		r.T.Enabled = true
		if not (pulseItems[r.T] and pulseItems[r.T].Kind == "flow") then reg(r.T, { P = P, Is = "seq", Last = r.T.Color, T = 0 }) end
		pulseItems[r.T].Until = os.clock() + 20
		task.delay(1.1, function() if ribbons[ch] == r and os.clock() >= r.Until then r.T.Enabled = false end end)
	end

	--- the Mythic extras of one wrapped entry call (W.Epic)
	function W._aurora(P, ctx, name, a, caster)
		local C = P.Curtains
		if name == "ColdMomentumMark" then ribbon(P, caster) return end
		if not ctx then return end
		if not ctx.G then                                                -- (the ground: past the bodies and the effect itself)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			local ex = { W.FXName and workspace:FindFirstChild(W.FXName) or nil }
			for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then ex[#ex + 1] = pl.Character end end
			if typeof(caster) == "Instance" then ex[#ex + 1] = caster end
			rp.FilterDescendantsInstances = ex
			local ray = workspace:Raycast(ctx.O + Vector3.new(0, 2, 0), Vector3.new(0, -16, 0), rp)
			ctx.G = ray and ray.Position.Y or (ctx.O.Y - 3)
		end
		if name == "MirrorCage" then ctx.Mode, ctx.H = "height", ctx.R * 0.6 end
		scan(P, ctx)
		local quick = name == "FireIcicleShard" or name == "ShardImpact"            -- (the M1: one more look, it is quick)
		for _, dt in ipairs(quick and { 0.08 } or { 0.15, 0.6, 1.5, 2.5, 4, 5.3, 6.5 }) do task.delay(dt, scan, P, ctx) end
		local g = Vector3.new(ctx.O.X, ctx.G + 0.2, ctx.O.Z)
		local A = RunService:IsClient() and aurora()
		if not A then return end
		A.Touch()
		if A.TakePending(P) then W._dropPools(P) end                       -- (the gradient copies are ready: fresh looks)
		if name == "CastFlashFreeze" then
			A.Curtains(P, g, ctx.R * C.FFR, C.Life, caster)
			A.Patches(P, g + Vector3.new(0, 0.7, 0), ctx.R * C.FFDisc, C.Patches, C.Life)
		elseif name == "Blizzard" then
			A.Curtains(P, g, ctx.R * C.BZR, C.BZLife, caster)
			A.Patches(P, g + Vector3.new(0, 0.7, 0), ctx.R * C.BZDisc, C.Patches + 2, C.BZLife)
		elseif name == "MirrorCage" then
			A.Curtains(P, g, ctx.R * C.CageR, C.Life, caster)
			A.Patches(P, g + Vector3.new(0, 0.7, 0), ctx.R * C.MCDisc, C.Patches - 2, C.Life)
		end
		if name == "CastFlashFreeze" or name == "Blizzard" or name == "MirrorCage" then
			A.Field(P, ctx, name == "Blizzard" and C.BZLife + 4 or C.Life + 6)          -- (the floor: aurora laid on the ground)
			A.Stars(P, g, ctx.R * (name == "MirrorCage" and C.MCDisc or name == "Blizzard" and C.BZDisc or C.FFDisc), name == "Blizzard" and C.BZLife or C.Life)
		end
		if name == "CastFlashFreeze" then
			A.Halos(P, g, ctx.R * 0.93, C.Life)                                       -- (the glow round the crystal ring)
			A.WatchShards(P, ctx, C.Life + 3)                                         -- (the shatter: wave phases, glints)
		elseif name == "DeepFreeze" then
			A.Patches(P, g + Vector3.new(0, 0.4, 0), 6, 4, 4)                         -- (its haze)
		end
	end
end

function W.Epic(P, ctx, name, a, caster)
	if P.Flow and W._aurora then pcall(W._aurora, P, ctx, name, a, caster) end
	if P.Twin then
		twinDiscs(P)
		task.delay(0.5, twinDiscs, P)
	end
	if P.Pulse then
		pulseScan(P)
		task.delay(0.6, pulseScan, P)
		task.delay(1.5, pulseScan, P)
		task.delay(2.5, pulseScan, P)
		task.delay(4, pulseScan, P)
	end
	local M = P.Motes
	if not M then return end
	if P.Flow and setting("ReduceFlashing") == true then return end          -- (Mythic: no twinkles under Reduce Flashing)
	if name == "ShardImpact" and typeof(a[1]) == "RaycastResult" then
		motes(P, a[1].Position, M.Impact, caster)
	elseif name == "FireIcicleShard" then
		motes(P, typeof(a[4]) == "Vector3" and a[4] or a[1], M.Cast, caster)
	elseif (name == "MirrorCage" or name == "Blizzard") and ctx and M.Zone then
		local ray = workspace:Raycast(ctx.O + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0))
		local g = ray and ray.Position or ctx.O
		local R = ctx.R * (name == "MirrorCage" and 0.45 or 0.9)
		local h = moteHost(g + Vector3.new(0, 4, 0), "EpicZone_" .. P.Id)
		h.Size = Vector3.new(6, 2 * R, 2 * R)
		h.CFrame = CFrame.new(h.Position) * CFrame.Angles(0, 0, math.rad(90))
		local props = moteProps(P, M.Zone)
		props.Shape, props.ShapeStyle = Enum.ParticleEmitterShape.Cylinder, Enum.ParticleEmitterShapeStyle.Volume
		local e = W._VFX.Emitter(h, props)
		task.delay(M.ZoneLife, function() if e then e.Rate = 0 end end)
		task.delay(M.ZoneLife + 2, function() h:Destroy() end)
	elseif name == "CastFlashFreeze" and ctx then
		for _, hn in ipairs({ "RightHand", "LeftHand" }) do
			local h = typeof(caster) == "Instance" and caster:FindFirstChild(hn)
			if h then motes(P, h.Position, math.ceil(M.Cast / 2), caster) end
		end
		-- the zone's edge: a thin ring host, sparse glints over the zone's life
		local ray = workspace:Raycast(ctx.O, Vector3.new(0, -12, 0))
		local g = ray and ray.Position or (ctx.O - Vector3.new(0, 3, 0))
		local R = ctx.R * 0.92
		local h = moteHost(g + Vector3.new(0, 0.3, 0), "EpicEdge_" .. P.Id)
		h.Size = Vector3.new(0.4, 2 * R, 2 * R)
		h.CFrame = CFrame.new(h.Position) * CFrame.Angles(0, 0, math.rad(90))
		local props = moteProps(P, M.Edge)
		props.Shape, props.ShapeStyle = Enum.ParticleEmitterShape.Cylinder, Enum.ParticleEmitterShapeStyle.Surface
		props.Speed, props.Acceleration = NumberRange.new(0.3, 1), Vector3.new(0, 1.5, 0)
		local e = W._VFX.Emitter(h, props)
		task.delay(M.EdgeLife, function() if e then e.Rate = 0 end end)
		task.delay(M.EdgeLife + 1.5, function() h:Destroy() end)
	end
end

--- mods = { CryoFX = , VFXLibrary = , Tables = { { table, "Name" }, ... } }; once per module copy
function W.Install(mods)
	if mods.CryoFX.WrapInstalled then return end
	mods.CryoFX.WrapInstalled = true
	for _, t in ipairs(mods.Tables) do
		if t[1] then register(t[1], t[2], 0) end
		if t[2] == "STYLE" then W._STYLE = t[1] end
		if t[2] == "Look" then W._LOOK = t[1] end
		if t[2] == "KINDS" then W._KINDS = t[1] end
		W._T = W._T or {}
		W._T[t[2]] = t[1]
	end
	for _, kit in ipairs(mods.Kits or {}) do         -- the skins: their pieces painted as they are made or taken from a pool
		if type(kit) == "table" and not kit.WrapHooked then
			kit.WrapHooked = true
			for _, fn in ipairs({ "New", "Get" }) do
				local f = kit[fn]
				if type(f) == "function" then
					kit[fn] = function(...)
						local o = f(...)
						if o then W.PaintKit(o) end
						return o
					end
				end
			end
			if type(kit.Emitter) == "function" then
				local f = kit.Emitter
				kit.Emitter = function(...) return W.Lit(f(...)) end
			end
			if type(kit.TrailSnow) == "function" then     -- (Snow Globe's shot snow: a preset of literal colours)
				local f = kit.TrailSnow
				kit.TrailSnow = function(...)
					local t = f(...)
					local P = W.Active
					if P and (P.Solid or P.Glow) and type(t) == "table" and typeof(t.Color) == "ColorSequence" then t.Color = value(t.Color, P) end
					if P and P.Glow and type(t) == "table" and t.Texture then t.Texture = W.Shard(t.Texture) end
					return t
				end
			end
			if type(kit.Ride) == "function" then          -- (Frost Lotus: the dart's motes are made after its look is painted)
				local f = kit.Ride
				kit.Ride = function(look, ...)
					local r = f(look, ...)
					if type(look) == "table" and type(look.Motes) == "table" then W.PaintKit({ P = look.Motes }) end
					return r
				end
			end
			if type(kit.Look) == "table" then register(kit.Look, "SkinLook", 1) end
		end
	end
	for _, a in ipairs(mods.Art or {}) do
		if a[1] then arts[#arts + 1] = { T = a[1], K = a[2], O = a[1][a[2]], Art = a[3] } end
	end
	for name, how in pairs(CRYOFX) do hook(mods.CryoFX, name, how) end
	-- a solid wrap's cage plates, built once in the background (only if the catalog has a solid wrap)
	for _, s in pairs(SkinCatalog.Skins) do
		if type(s) == "table" and s.Wrap == "Cryo" and s.Palette and s.Palette.Solid then task.spawn(buildPlates) break end
	end
	if mods.VFXLibrary then
		for name, how in pairs(VFX) do hook(mods.VFXLibrary, name, how) end
		mods.VFXLibrary.Wrap = W
		W._VFX = mods.VFXLibrary
		W.FXName = mods.VFXLibrary.Config and mods.VFXLibrary.Config.FXFolderName
	end
end

return W
