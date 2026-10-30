--[[
	FrostLotusKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/FrostLotusKit

	Cryo's FROST LOTUS skin (an Epic Element Skin, 2026-10-15 -- SkinCatalog's tier; audit P5A-23, 2026-10-19: this said
	Rare; designed and rendered in Blender:
	vfx_blocking/cryo/cryo_frostlotus_skin_2026_10_14, the contract is its HANDOFF_SPEC.md). Every Cryo piece remodelled
	as soft, curved ice LOTUS PETALS -- broad, rounded-shouldered, cupped, an S-curve, a soft tip -- in the shipped v2 ice:
	a deep-blue heart, a pale body, white tips, the Frost Line along the outer petals' edges, a glowing cyan-white heart in
	every bloom. The Rare layer: dew glints and ice glitter (Sparkles(), switchable on their own).

	  On(character)        whether that body's player wears it (SkinCatalog: ElementSkin_Cryo = "FrostLotus", on Cryo)
	  New(kind) / Place    a piece of one of the KINDS below (its Body, and Heart / Line where it has them), and where its
	                       parts go for a frame K (a petal: its base at K's origin, +Y to the tip, X across; a bloom: its
	                       centre at K's origin, +Y the way its face opens), scale `s`
	  BodyBlooms(model, n) the mini blooms grown all over a rooted body (Flash Freeze, Deep Freeze)
	  Field(n, R)          the zone's blooms (Flash Freeze)
	  M1(state, pose, dt)  the hold-and-pluck's held lotus arm (CastPose calls it every frame, for every body)
	The meshes are built once per client, at load, from EditableMeshes (the port of the kit's petal / lotus, kit/fl.py and
	kit/fl_field.py), one resizable mesh at a time, copied into fixed-size ones. Until they are built, Default draws.
	Who draws what: VFXLibrary the dart in flight; FrostLotusFX (through CryoFX's hooks) everything else; CastPose and
	Viewmodel the M1 hold.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local FL = {}
FL.Id = "FrostLotus"

-- (2026-10-26) THE SHOWCASE CONVENTION: a client-only model no player owns, with the attribute ShowcaseSkin = "<SkinId>"
-- (the Loadout Altar's dummies, the pedestal's held M1), wears that skin -- live and in Studio. Every such model asked
-- about (On) or seen entering the workspace (the lazy block below) is kept here wherever it sits (the showcases parent
-- theirs in their own folders), so the lazy build and its release count it until it leaves the workspace.
local showcase = {}
--- whether `m` is a showcase stand-in wearing Frost Lotus (one wearing any skin is kept)
function FL.Showcase(m)
	local id = typeof(m) == "Instance" and m:GetAttribute("ShowcaseSkin")
	if type(id) ~= "string" or Players:GetPlayerFromCharacter(m) then return false end
	if not showcase[m] then                            -- (2026-10-26) pruned on insert: destroyed stand-ins don't pile up
		for k in pairs(showcase) do
			if not k:IsDescendantOf(workspace) then showcase[k] = nil end
		end
		showcase[m] = true
	end
	return id == FL.Id
end
--- the showcase stand-ins in the workspace wearing Frost Lotus now
function FL.Showcased()
	local out = {}
	for m in pairs(showcase) do
		if not m:IsDescendantOf(workspace) then
			showcase[m] = nil
		elseif m:GetAttribute("ShowcaseSkin") == FL.Id then
			out[#out + 1] = m
		end
	end
	return out
end

--- Whether `character`'s player wears Frost Lotus (their Cryo skin, while Cryo is their Element).
function FL.On(character)
	if typeof(character) ~= "Instance" then return false end
	local plr = Players:GetPlayerFromCharacter(character)
	-- (2026-10-26) a showcase stand-in (ShowcaseSkin), live too; it starts the build (FL.Build: one at a time)
	if not plr and FL.Showcase(character) then
		if not (FL.Built or FL.Failed) then FL.Build() end
		return true
	end
	-- Studio only: a dummy with StudioSkin stands in for a caster (the skins' side-by-side test); never live
	if not plr then return RunService:IsStudio() and character:GetAttribute("StudioSkin") == FL.Id end
	if (plr:GetAttribute("Element") or "Cryo") ~= "Cryo" then return false end
	return SkinCatalog.ElementSkin(plr, "Cryo") == FL.Id
end

-- the counts (HANDOFF_SPEC) and their scale-down: high / medium / low (low also = Reduce Enemy VFX on somebody else's)
FL.ZoneLotus = { 9, 6, 4 }               -- ZONE_LOTUS: Flash Freeze's field
FL.BodyLotus = { 20, 14, 10 }            -- BODY_LOTUS: the mini blooms on a rooted body (the cap: 20)
FL.BodyLotusCrowd = 5                    -- ...once 6 frozen targets are in view, each new one
FL.BodyCrowdAt = 6
FL.DomeTier = { Big = 4.2, Medium = 3.2, Small = 2.4 }   -- Mirror Cage's bloom radius by ring (top / middle / outer)
FL.StormPetals = { 24, 16, 8 }           -- (the Rare swirl's count)
FL.StormStreaks = { 36, 24, 12 }         -- Blizzard (Epic): petal streaks blowing one way (+ the wall's flecks to glitter)
FL.ShatterPiece = "FL_Mote"              -- the falling petal CryoFX throws at a shatter
FL.ShatterChunks = { 8, 5, 3 }           -- (2026-10-19, audit P5A-07) the shatter's chunk counts (CryoFX FBX.Shatter read nil)
function FL.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

if not RunService:IsClient() then
	return FL                       -- the server only asks On(); nothing below is built there
end

----------------------------------------------------------------------------------------------------
-- the look: the shipped real ice (a translucent Ice part) with the petal's colour in its vertex colours -- a deep-blue
-- heart, a pale body, white tips; Neon for the glowing heart and the Frost Line edge
----------------------------------------------------------------------------------------------------
local function hex(h) return Color3.fromHex(h) end
local HEART, MID, BODY, TIP = hex("#2F80C8"), hex("#8FCBEE"), hex("#C6E8F8"), hex("#EEF9FE")
local WHITE = Color3.new(1, 1, 1)
local DEEP = hex("#0E4FA8")                 -- Cryo's IceDeep (VFXLibrary's palette): the Epic petals' undersides
local SHADE = DEEP:Lerp(Color3.new(0, 0, 0), 0.4)   -- their contact shadows
FL.Look = {
	IceT = 0.25, Reflect = 0.15,
	Heart = hex("#C8F6FF"), HeartT = 0.05,
	PodT = 0.22,                     -- the giant pod / stamens: LineHot, a softer glow (a whiter one blew out)
	Line = hex("#3FE0FF"), LineHot = hex("#8DF3FF"),
	Dew = hex("#E6F7FF"), Glitter = hex("#D6F1FF"), IceBlue = MID,
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

local function petalColour(u, v)
	local c
	if u < 0.3 then c = HEART:Lerp(MID, u / 0.3)
	elseif u < 0.75 then c = MID:Lerp(BODY, (u - 0.3) / 0.45)
	else c = BODY:Lerp(TIP, (u - 0.75) / 0.25) end
	return c:Lerp(TIP, math.clamp(math.abs(v) - 0.6, 0, 0.4))      -- the thin edges paler
end

----------------------------------------------------------------------------------------------------
-- the petal (kit/fl.py petal): a solid lens-section volume -- rounded shoulders widest at `Wmax` of its length, a soft
-- pointed tip, cupped (its edges raised toward n = the frame's +Z, the cup's inside), an S-curve, `Twist` radians of
-- spiral; Nv = 1: a thin double-faced petal. Frame F: base at its origin, +Y to the tip, X across.
-- out.Body / out.Line: triangle lists { a, b, c, ca, cb, cc, normal, group }; `line`: the Frost Line strips on the rims
-- from `line` of the length on (nil: none).
----------------------------------------------------------------------------------------------------
local function tri(list, a, b, c, ca, cb, cc, want, grp)
	local n = (b - a):Cross(c - a)
	if n.Magnitude < 1e-9 then return end
	n = n.Unit
	if n:Dot(want) < 0 then n = -n end
	list[#list + 1] = { a, b, c, ca, cb, cc, n, grp or 0 }
end

local function petal(out, F, o, line)
	local L, W, T = o.L, o.W, o.T
	local cup, sc, twist = o.Cup or 0.3, o.S or 0.1, o.Twist or 0
	local nu, nv, wmax = o.Nu or 5, o.Nv or 2, o.Wmax or 0.56
	local u0, s0 = F.UpVector, F.RightVector
	local n0 = u0:Cross(s0)                                       -- the cup's inside: length x width, as the kit's
	local O = F.Position
	local us = {}
	if nu == 5 then us = { 0, 0.22, 0.5, 0.74, 0.9, 1 } else
		for i = 0, nu do us[#us + 1] = (i / nu) ^ 0.92 end
	end
	local pw = math.log(0.5) / math.log(wmax)
	local function hw(u)
		local f = math.max(0, math.sin(math.pi * math.min(u, 1) ^ pw)) ^ 0.7
		local c = 0.16 * (1 - u) ^ 2
		return W / 2 * (c + (1 - c) * f)
	end
	local function fr(u)
		local a = twist * u
		return s0 * math.cos(a) + n0 * math.sin(a), n0 * math.cos(a) - s0 * math.sin(a)
	end
	local function zc(u)
		return L * sc * (4 * u * (1 - u) - 0.9 * math.max(0, u - 0.65) ^ 2 / 0.1225)
	end
	local vs = {}
	for j = 0, nv do vs[#vs + 1] = -1 + 2 * j / nv end
	local rows = {}
	for i, u in ipairs(us) do
		local s, n = fr(u)
		local c = O + u0 * (u * L) + n * zc(u)
		if i == #us then
			rows[i] = { Tip = c, U = u, N = n, S = s }
		else
			local h = hw(u)
			local top, bot, cl = {}, {}, {}
			for j, v in ipairs(vs) do
				local mid = c + s * (v * h) + n * (cup * h * v * v)
				local half = 0.5 * T * math.sqrt(math.max(0, 1 - v * v)) * (1 - 0.55 * u)
				top[j], bot[j], cl[j] = mid + n * half, mid - n * half, petalColour(u, v)
			end
			rows[i] = { Top = top, Bot = bot, Col = cl, U = u, N = n, S = s }
		end
	end
	for i = 1, #rows - 1 do
		local r, q = rows[i], rows[i + 1]
		for j = 1, nv do
			if q.Tip then
				tri(out.Body, r.Top[j], r.Top[j + 1], q.Tip, r.Col[j], r.Col[j + 1], TIP, r.N, 1)
				tri(out.Body, r.Bot[j], r.Bot[j + 1], q.Tip, r.Col[j], r.Col[j + 1], TIP, -r.N, 2)
			else
				tri(out.Body, r.Top[j], r.Top[j + 1], q.Top[j + 1], r.Col[j], r.Col[j + 1], q.Col[j + 1], r.N, 1)
				tri(out.Body, r.Top[j], q.Top[j + 1], q.Top[j], r.Col[j], q.Col[j + 1], q.Col[j], r.N, 1)
				tri(out.Body, r.Bot[j], r.Bot[j + 1], q.Bot[j + 1], r.Col[j], r.Col[j + 1], q.Col[j + 1], -r.N, 2)
				tri(out.Body, r.Bot[j], q.Bot[j + 1], q.Bot[j], r.Col[j], q.Col[j + 1], q.Col[j], -r.N, 2)
			end
		end
	end
	if line and out.Line then                                     -- the Frost Line along both rims, from `line` of it out
		local w = math.max(0.02, W * 0.06)
		for i = 1, #rows - 1 do
			local r, q = rows[i], rows[i + 1]
			if r.U >= line - 1e-3 then
				for _, e in ipairs({ 1, nv + 1 }) do
					local inward = (e == 1) and 1 or -1
					local a, b = r.Top[e], q.Tip or q.Top[e]
					local sa, sb = r.S * (w * inward), (q.S or r.S) * (w * inward * (q.Tip and 0.3 or 1))
					local qd = { a, b, b + sb, a + sa }
					tri(out.Line, qd[1], qd[2], qd[3], WHITE, WHITE, WHITE, r.N, 3)
					tri(out.Line, qd[1], qd[3], qd[4], WHITE, WHITE, WHITE, r.N, 3)
					tri(out.Line, qd[1], qd[2], qd[3], WHITE, WHITE, WHITE, -r.N, 4)
					tri(out.Line, qd[1], qd[3], qd[4], WHITE, WHITE, WHITE, -r.N, 4)
				end
			end
		end
	end
end

--- the glowing heart: a flat-topped pod and `n` thin stamens (cyan-white, never gold); frame: centre, +Y up
local function heart(out, C, U, r, n, h)
	local X = U:Cross(math.abs(U.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis).Unit
	local Y = U:Cross(X)
	local ring0, ring1 = {}, {}
	for k = 0, 7 do
		local a = 2 * math.pi * k / 8
		local d = X * math.cos(a) + Y * math.sin(a)
		ring0[k], ring1[k] = C + d * r, C + d * r * 0.95 + U * h * 0.5
	end
	local top = C + U * h * 0.52
	for k = 0, 7 do
		local j = (k + 1) % 8
		local o = (ring0[k] + ring0[j]) / 2 - C
		tri(out.Heart, ring0[k], ring0[j], ring1[j], WHITE, WHITE, WHITE, o, 5)
		tri(out.Heart, ring0[k], ring1[j], ring1[k], WHITE, WHITE, WHITE, o, 5)
		tri(out.Heart, ring1[k], ring1[j], top, WHITE, WHITE, WHITE, U, 6)
	end
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / math.max(n, 1)
		local d = X * math.cos(a) + Y * math.sin(a)
		local b = C + d * r * 1.05
		local ax = (U + d * 0.5).Unit
		local s1 = ax:Cross(d).Unit * (r * 0.12)
		local tip = b + ax * h
		tri(out.Heart, b - s1, b + s1, tip, WHITE, WHITE, WHITE, d, 7)
		tri(out.Heart, b + s1, b - s1, tip, WHITE, WHITE, WHITE, -d, 8)
	end
end

--- a bloom of radius R (the outer tips ~R out) at frame F (its centre, +Y = the way its face opens): `spec` petal rings
--- { count, length, width (x length), tilt } per unit radius, outer first; the outer ring's rims carry the Frost Line
--- (`line`), the heart `stamens` thin stamens (nil: no heart). skip: { [ring .. ":" .. k] = true }.
local function bloom(out, F, R, spec, o)
	o = o or {}
	local C, U = F.Position, F.UpVector
	local X, Y = F.RightVector, -F.LookVector
	for ti, t in ipairs(spec) do
		local cnt, Lk, Wk, tilt = t[1], t[2], t[3], t[4] * (o.Open or 1)
		for k = 0, cnt - 1 do
			if not (o.Skip and o.Skip[ti .. ":" .. k]) then
				local a = (o.Yaw or 0) + 2 * math.pi * k / cnt + ((ti % 2 == 0) and math.pi / cnt or 0)
				local rad = X * math.cos(a) + Y * math.sin(a)
				local ax = U * math.cos(tilt) + rad * math.sin(tilt)
				local sd = U:Cross(rad)
				local L, W = R * Lk, R * Lk * Wk
				local base = C + rad * (0.08 * R)
				-- the petal frame: +Y along ax, X across (sd), +Z (its cup) inward: fromMatrix(pos, X, Y) gives Z = X x Y
				local Fp = CFrame.fromMatrix(base, sd, ax)
				petal(out, Fp, { L = L, W = W, T = math.max(0.02, W * 0.3), Cup = 0.42, S = 0.08, Nu = o.Nu or 5, Nv = o.Nv or 2 },
					(ti == 1 and o.Line) and 0.5 or nil)
			end
		end
	end
	if o.Stamens and out.Heart then heart(out, C + U * (0.02 * R), U, 0.11 * R, o.Stamens, 0.22 * R) end
end

-- the kinds (sizes from the kit: fl_cp.py / fl_m1.py / fl_field.py / fl_final.py). A petal kind: L = its length.
local BLOOM3 = { { 8, 1.05, 0.62, 1.15 }, { 7, 0.8, 0.6, 0.7 }, { 5, 0.55, 0.5, 0.3 } }
local MINI = { { 6, 1.05, 0.62, 1.12 }, { 4, 0.75, 0.6, 0.55 } }
local SPECS = {
	DartRare = function(out) petal(out, CFrame.identity, { L = 1.3, W = 0.36, T = 0.11, Cup = 0.4, S = 0.1, Wmax = 0.64 }) end,
	HandPetal = function(out) petal(out, CFrame.identity, { L = 0.75, W = 0.26, T = 0.08, Cup = 0.4, S = 0.1, Wmax = 0.64 }) end,
	Lance = function(out) petal(out, CFrame.identity, { L = 2.6, W = 0.19, T = 0.05, Cup = 0.12, S = 0.05, Twist = math.pi, Nu = 8, Wmax = 0.45 }, 0.5) end,
	Mote = function(out) petal(out, CFrame.new(0, -0.5, 0), { L = 1, W = 0.62, T = 0.12, Cup = 0.45, S = 0.12 }) end,
	MiniBloom = function(out) bloom(out, CFrame.identity, 1, MINI, { Nv = 1, Stamens = 0 }) end,
	FieldBloom = function(out) bloom(out, CFrame.identity, 1, BLOOM3, { Line = true, Stamens = 6 }) end,
	DomeSmall = function(out) bloom(out, CFrame.identity, 1, { { 6, 1.05, 0.62, 1.15 }, { 4, 0.75, 0.6, 0.6 } }, { Nu = 4, Line = true, Stamens = 3 }) end,
	DomeMedium = function(out) bloom(out, CFrame.identity, 1, { { 7, 1.05, 0.62, 1.15 }, { 5, 0.8, 0.6, 0.7 } }, { Nu = 4, Line = true, Stamens = 6 }) end,
	DomeBig = function(out) bloom(out, CFrame.identity, 1, BLOOM3, { Line = true, Stamens = 6 }) end,
	-- (no Frost Line strips: the Default print under it has its own rim; up to 14 alive)
	PrintBloom = function(out) bloom(out, CFrame.identity, 1, { { 6, 1.05, 0.62, 1.38 }, { 5, 0.75, 0.6, 0.95 } }, { Nu = 4, Stamens = 0 }) end,
	TrapBloom = function(out) bloom(out, CFrame.identity, 1, { BLOOM3[1], BLOOM3[2] }, { Open = 0.95, Line = true }) end,
	HeldLotus = function(out) bloom(out, CFrame.identity, 1, { { 6, 0.78, 0.72, 1.0 }, { 5, 0.62, 0.74, 0.45 } }, { Skip = { ["1:0"] = true }, Stamens = 6 }) end,
	HeldSlot = function(out)
		local a = 0
		local rad = Vector3.new(math.cos(a), 0, math.sin(a))
		local ax = Vector3.yAxis * math.cos(1.0) + rad * math.sin(1.0)
		petal(out, CFrame.fromMatrix(rad * 0.08, Vector3.yAxis:Cross(rad), ax), { L = 0.78, W = 0.56, T = 0.17, Cup = 0.42, S = 0.08 })
	end,
}
local LENGTH = { Dart = 3.0, HandPetal = 0.75, Lance = 2.6, Mote = 1 }
FL.Kinds = { Dart = { L = 3.0 }, Lance = { L = 2.6, W = 0.19 }, HandPetal = { L = 0.75 }, Mote = { L = 1 } }

----------------------------------------------------------------------------------------------------
-- THE EPIC MIRROR CAGE: one giant lotus under the target (concept B, approved 2026-10-15:
-- vfx_blocking/cryo/cryo_frostlotus_skin_2026_10_14/fl_epic_cpb.py). 14 / 10 / 5 cupped pointed-oval petals in a shallow
-- bowl -- the outer near-flat, tips curling down; the middle 50 -> 34 deg; the inner 72 -> 58 deg on a ring wide of the
-- player -- a flat-topped glowing pod with bumps, 64 stamens in 16 sectors. Each petal: hard facets, a saturated tip
-- fading to a pale base, faint radial veins, the Frost Line on its outer rims. Petal frame: base at the origin, +X out
-- along the ground, +Y up, Z across (the hinge it opens on). Extra per kind: Mid (where its bolt leaves), Sphere and
-- Proxy (16 coarse triangles: FrostLotusFX's keyhole tests the sightlines to the players against them).
----------------------------------------------------------------------------------------------------
FL.Giant = {
	Tiers = {
		{ Kind = "GiantOuter", N = 14, Off = 90 + 360 / 28, R0 = 3.2, Y0 = 0.12, Lift = 0.12, Open = 0.35 },
		{ Kind = "GiantMiddle", N = 10, Off = 108, R0 = 3.4, Y0 = 0.30, Lift = 0, Open = 0.5 },
		{ Kind = "GiantInner", N = 5, Off = 90, R0 = 3.9, Y0 = 0.38, Lift = 0, Open = 0.65 },
	},
	Sectors = 16, PodTop = 0.6, R = 20,
}
local GIANT = {
	GiantOuter = { L = 17.0, W = 17.0 * 0.38, Cup = 0.12, Prof = function(u) return 14 - 32 * u * u end },
	GiantMiddle = { L = 14.2, W = 14.2 * 0.46, Cup = 0.30,        -- (middle + inner x1.35, approved: a ~10-stud bowl)
		Prof = function(u) return 50 - 16 * u * u end },
	GiantInner = { L = 9.7, W = 9.7 * 0.46, Cup = 0.40, Prof = function(u) return 72 - 14 * u * u end },
}

--- the Epic gradient: pale (near white) at the base to a saturated icy blue at the tip; odd columns a shade deeper (veins)
local function giantColour(u, j)
	local c
	if u < 0.4 then c = TIP:Lerp(BODY, u / 0.4)
	elseif u < 0.75 then c = BODY:Lerp(MID, (u - 0.4) / 0.35)
	else c = MID:Lerp(HEART, 0.7 * (u - 0.75) / 0.25) end
	if j % 2 == 1 and u > 0.08 and u < 0.85 then c = c:Lerp(MID, 0.28) end
	return c
end

--- (o.F: the petal's frame, default the giant's; o.N / o.M sections / columns; o.Line = false: no Frost Line; o.LineW
--- its width; o.Proxy: the keyhole's data into out.Extra; o.Flat: one colour; o.Deep: an IceDeep underside; o.WhiteTip:
--- white tips; o.Shadow: a dark contact shadow on the frame's ground, o.Shadow below its origin)
local function giantPetal(out, o)
	local N, M = o.N or 8, o.M or 6
	local L, W, cup = o.L, o.W, o.Cup
	local F = o.F or CFrame.identity
	local d, up, sd = F.RightVector, F.UpVector, -F.LookVector
	local pos = F.Position
	local rows = {}
	for k = 0, N do
		local u = k / N
		local t = math.rad(o.Prof(u))
		local n = up * math.cos(t) - d * math.sin(t)
		local hw = W / 2 * math.max(math.abs(math.sin(math.pi * u ^ 1.16)) ^ 0.75, 0.2 * (1 - u))
		local th = 0.3 * (1 - 0.75 * u)
		local top, bot, col = {}, {}, {}
		for j = 0, M do
			local x = 2 * j / M - 1
			local p = pos + sd * (x * hw) + n * (cup * hw * x * x)
			local cl = o.Flat or giantColour(u, j)
			if o.WhiteTip and u > 0.8 then cl = cl:Lerp(WHITE, 0.9 * (u - 0.8) / 0.2) end
			top[j], bot[j], col[j] = p, p - n * th, cl
		end
		local bc = col
		if o.Deep then
			bc = {}
			for j = 0, M do bc[j] = col[j]:Lerp(DEEP, 0.78) end
		end
		rows[k] = { Top = top, Bot = bot, Col = col, BCol = bc, N = n, C = pos, HW = hw }
		if k < N then pos += (d * math.cos(t) + up * math.sin(t)) * (L / N) end
	end
	local g = (o.G or 0) + 10                             -- a group per quad: hard facets
	for k = 0, N - 1 do
		local r, q = rows[k], rows[k + 1]
		for j = 0, M - 1 do
			g += 1
			tri(out.Body, r.Top[j], r.Top[j + 1], q.Top[j + 1], r.Col[j], r.Col[j + 1], q.Col[j + 1], r.N, g)
			tri(out.Body, r.Top[j], q.Top[j + 1], q.Top[j], r.Col[j], q.Col[j + 1], q.Col[j], r.N, g)
			g += 1
			tri(out.Body, r.Bot[j], r.Bot[j + 1], q.Bot[j + 1], r.BCol[j], r.BCol[j + 1], q.BCol[j + 1], -r.N, g)
			tri(out.Body, r.Bot[j], q.Bot[j + 1], q.Bot[j], r.BCol[j], q.BCol[j + 1], q.BCol[j], -r.N, g)
		end
		for _, j in ipairs({ 0, M }) do
			local w = (j == 0) and -sd or sd
			g += 1
			tri(out.Body, r.Top[j], q.Top[j], q.Bot[j], r.Col[j], q.Col[j], q.Col[j], w, g)
			tri(out.Body, r.Top[j], q.Bot[j], r.Bot[j], r.Col[j], q.Col[j], r.Col[j], w, g)
		end
		if o.Line ~= false and k >= N / 2 then             -- the Frost Line on both rims, the outer half
			local lw = o.LineW or (0.16 + W * 0.015)
			for _, j in ipairs({ 0, M }) do
				local inw = (j == 0) and sd or -sd
				local a, b = r.Top[j], q.Top[j]
				local qd = { a, b, b + inw * (lw * (k == N - 1 and 0.3 or 1)), a + inw * lw }
				for side = 3, 4 do
					local nn = (side == 3) and r.N or -r.N
					tri(out.Line, qd[1], qd[2], qd[3], WHITE, WHITE, WHITE, nn, side)
					tri(out.Line, qd[1], qd[3], qd[4], WHITE, WHITE, WHITE, nn, side)
				end
			end
		end
	end
	local r0 = rows[0]
	g += 1
	for j = 0, M - 1 do
		tri(out.Body, r0.Top[j], r0.Top[j + 1], r0.Bot[j + 1], r0.Col[j], r0.Col[j + 1], r0.Col[j + 1], -d, g)
		tri(out.Body, r0.Top[j], r0.Bot[j + 1], r0.Bot[j], r0.Col[j], r0.Col[j + 1], r0.Col[j], -d, g)
	end
	if o.Shadow then                                      -- the contact shadow: the petal's outline pressed onto the ground
		local function flat(v) return v - up * ((v - F.Position):Dot(up) + o.Shadow) end
		g += 1
		for k = 0, N - 1 do
			local r, q = rows[k], rows[k + 1]
			local a, b = flat(r.Top[0] - sd * 0.12), flat(r.Top[M] + sd * 0.12)
			local c, e = flat(q.Top[M] + sd * 0.12), flat(q.Top[0] - sd * 0.12)
			tri(out.Body, a, b, c, SHADE, SHADE, SHADE, up, g)
			tri(out.Body, a, c, e, SHADE, SHADE, SHADE, up, g)
		end
	end
	o.G = g
	if not o.Proxy then return end
	-- the keyhole's proxy: the top surface at u = 0.1 .. 0.9 x (edge, middle, edge)
	local P = {}
	for i, k in ipairs({ 1, 2, 4, 6, 7 }) do
		local r = rows[k]
		P[i] = { r.Top[0], r.Top[M / 2], r.Top[M] }
	end
	local proxy, lo, hi = {}, Vector3.one * 1e9, -Vector3.one * 1e9
	for i = 1, #P - 1 do
		for c = 1, 2 do
			proxy[#proxy + 1] = { P[i][c], P[i][c + 1], P[i + 1][c + 1] }
			proxy[#proxy + 1] = { P[i][c], P[i + 1][c + 1], P[i + 1][c] }
		end
	end
	for _, r in pairs(rows) do
		for j = 0, M do lo, hi = lo:Min(r.Top[j]):Min(r.Bot[j]), hi:Max(r.Top[j]):Max(r.Bot[j]) end
	end
	out.Extra = { Mid = rows[N / 2].Top[M / 2], Proxy = proxy, Sphere = (lo + hi) / 2, Radius = (hi - lo).Magnitude / 2,
		Closed = math.rad(80 - o.Prof(0)) }
end

--- the pod: an inverted 12-sided frustum, its flat top at PodTop, 18 faceted bumps (glowing; frame: its centre on the ground)
local function giantPod(out)
	local S, top = 12, FL.Giant.PodTop
	local up, dn = {}, {}
	for k = 0, S - 1 do
		local a = 2 * math.pi * (k + 0.5) / S
		up[k], dn[k] = Vector3.new(3.4 * math.cos(a), top, 3.4 * math.sin(a)), Vector3.new(2.6 * math.cos(a), -0.5, 2.6 * math.sin(a))
	end
	local c = Vector3.new(0, top, 0)
	for k = 0, S - 1 do
		local j = (k + 1) % S
		tri(out.Body, c, up[k], up[j], WHITE, WHITE, WHITE, Vector3.yAxis, 1)
		local o = (up[k] + up[j]) / 2 - c
		tri(out.Body, up[k], up[j], dn[j], WHITE, WHITE, WHITE, o, 10 + k)
		tri(out.Body, up[k], dn[j], dn[k], WHITE, WHITE, WHITE, o, 10 + k)
	end
	local g = 40
	for _, ring in ipairs({ { 1.4, 6, 0 }, { 2.5, 12, 0.5 } }) do
		for k = 0, ring[2] - 1 do
			local a = 2 * math.pi * (k + ring[3]) / ring[2]
			local cx, cz = ring[1] * math.cos(a), ring[1] * math.sin(a)
			local apex = Vector3.new(cx, top + 0.24, cz)
			for j = 0, 5 do
				local b1 = Vector3.new(cx + 0.36 * math.cos(math.pi * j / 3), top + 0.01, cz + 0.36 * math.sin(math.pi * j / 3))
				local b2 = Vector3.new(cx + 0.36 * math.cos(math.pi * (j + 1) / 3), top + 0.01, cz + 0.36 * math.sin(math.pi * (j + 1) / 3))
				g += 1
				tri(out.Body, b1, b2, apex, WHITE, WHITE, WHITE, (b1 + b2) / 2 - Vector3.new(cx, top - 0.3, cz), g)
			end
		end
	end
end

--- one sector of the stamen fringe: 2 + 2 stems (an inner row more upright) with anthers (glowing; frame: the pod's)
local function giantStamens(out)
	local g = 0
	local z = FL.Giant.PodTop - 0.05
	for _, s in ipairs({ { 0, 3.15, 16, 1.75 }, { 0.5, 3.35, 30, 1.55 }, { 1, 3.15, 16, 1.75 }, { 1.5, 3.35, 30, 1.55 } }) do
		local a = 2 * math.pi * s[1] / 32
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local sd = Vector3.new(-math.sin(a), 0, math.cos(a))
		local ax = d * math.sin(math.rad(s[3])) + Vector3.yAxis * math.cos(math.rad(s[3]))
		local n = ax:Cross(sd).Unit
		local base = d * s[2] + Vector3.new(0, z, 0)
		local tip = base + ax * s[4]
		local w = 0.07
		local cs = { sd * w + n * w, -sd * w + n * w, -sd * w - n * w, sd * w - n * w }
		for j = 1, 4 do
			local j2 = j % 4 + 1
			g += 1
			local o = (cs[j] + cs[j2]) / 2
			tri(out.Body, base + cs[j], base + cs[j2], tip + cs[j2], WHITE, WHITE, WHITE, o, g)
			tri(out.Body, base + cs[j], tip + cs[j2], tip + cs[j], WHITE, WHITE, WHITE, o, g)
		end
		local b0, b1 = tip - ax * 0.05, tip + ax * 0.65
		local m = b0 + (b1 - b0) * 0.45
		local e = {}
		for j = 1, 4 do
			local q = math.pi / 2 * j + math.pi / 4
			e[j] = m + sd * (0.17 * math.cos(q)) + n * (0.17 * math.sin(q))
		end
		for j = 1, 4 do
			local j2 = j % 4 + 1
			g += 1
			tri(out.Body, b0, e[j], e[j2], WHITE, WHITE, WHITE, (e[j] + e[j2]) / 2 - m - ax * 0.2, g)
			g += 1
			tri(out.Body, b1, e[j2], e[j], WHITE, WHITE, WHITE, (e[j] + e[j2]) / 2 - m + ax * 0.2, g)
		end
	end
	out.Extra = { Sphere = Vector3.new(3.6 * math.cos(math.pi / 16), 1.6, 3.6 * math.sin(math.pi / 16)), Radius = 1.4 }
end

for name, o in pairs(GIANT) do
	SPECS[name] = function(out) o.Proxy = true giantPetal(out, o) end
end
SPECS.GiantPod = function(out) giantPod(out) out.NeonBody = true end

----------------------------------------------------------------------------------------------------
-- EPIC stage 2. FLASH FREEZE's field lotus: three upright rings (8 / 7 / 5 faceted petals, unit radius, each ring its own
-- part so they open one after another) and a glowing heart (pod + 6 stamens); only the outer ring carries the Frost
-- Line. The M1: the DART is one glowing petal blade (Neon, the Epic gradient), three hard-edged BladeMotes trailing it
-- (Ride).
----------------------------------------------------------------------------------------------------
local FIELD = {
	FieldRing1 = { N = 8, R0 = 0.08, L = 1.0, W = 0.42, Cup = 0.3, Prof = function(u) return 58 - 22 * u * u end, Line = true },
	FieldRing2 = { N = 7, R0 = 0.06, L = 0.8, W = 0.4, Cup = 0.35, Prof = function(u) return 70 - 16 * u * u end, Off = 0.5 },
	FieldRing3 = { N = 5, R0 = 0.04, L = 0.55, W = 0.36, Cup = 0.4, Prof = function(u) return 80 - 10 * u * u end },
}
for name, r in pairs(FIELD) do
	SPECS[name] = function(out)
		local o = { L = r.L, W = r.W, Cup = r.Cup, Prof = r.Prof, N = 4, M = 2, Line = r.Line == true }
		for k = 0, r.N - 1 do
			local a = 2 * math.pi * (k + (r.Off or 0)) / r.N
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			o.F = CFrame.fromMatrix(dir * r.R0, dir, Vector3.yAxis)
			giantPetal(out, o)
		end
	end
end
SPECS.FieldHeart = function(out)
	heart(out, Vector3.new(0, 0.03, 0), Vector3.yAxis, 0.13, 6, 0.26)
	out.Body, out.Heart = out.Heart, {}
	out.NeonBody = true
end
SPECS.Dart = function(out)            -- (+Y along the flight, the tip at L, 3 long; the Rare Ice dart: DartRare)
	giantPetal(out, { L = 3.0, W = 0.8, Cup = 0.25, Prof = function() return 0 end, N = 4, M = 2, Line = false, Flat = WHITE,
		F = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis) })
	out.NeonBody, out.BodyT = true, 0.02
end
SPECS.BladeMote = function(out)
	giantPetal(out, { L = 0.72, W = 0.36, Cup = 0.3, Prof = function() return 0 end, N = 2, M = 2, Line = false, Flat = WHITE,
		F = CFrame.fromMatrix(Vector3.new(0, -0.36, 0), Vector3.yAxis, Vector3.zAxis) })
	out.NeonBody, out.BodyT = true, 0.08
end

----------------------------------------------------------------------------------------------------
-- EPIC stage 2, revision (2026-10-15): FLASH FREEZE as ONE ground lotus. A mandala of four concentric petal rings lying
-- low (8 / 12 / 16 / 20, alternating, sized for the zone's radius 20 -- FrostLotusFX scales them by R / 20), a boundary
-- of 48 large touching upright petals on the zone's edge (16 sectors of 3, so a sector near a body can sink) with a
-- bright wide Frost Line, and 6 taller hero petals spaced round it. Every petal: an IceDeep underside, a white tip, a
-- dark contact shadow. Flutter: the petal that peels off at the shed (with a glint trail, FrostLotusFX); FlutterS the
-- M1 hit's. HitLotus / HitRing: the M1 hit (6 petals; the thin ring flash).
----------------------------------------------------------------------------------------------------
local MANDALA = {
	FieldMandalaA = { N = 8, R0 = 1.2, L = 4.6, W = 2.2, Prof = function(u) return 22 - 14 * u * u end, Off = 0 },
	FieldMandalaB = { N = 12, R0 = 4.6, L = 5.0, W = 2.8, Prof = function(u) return 18 - 14 * u * u end, Off = 0.5 },
	FieldMandalaC = { N = 16, R0 = 8.4, L = 5.2, W = 3.2, Prof = function(u) return 16 - 14 * u * u end, Off = 0 },
	FieldMandalaD = { N = 20, R0 = 12.2, L = 6.2, W = 3.6, Prof = function(u) return 14 - 14 * u * u end, Off = 0.5 },
}
for name, r in pairs(MANDALA) do
	SPECS[name] = function(out)
		local o = { L = r.L, W = r.W, Cup = 0.3, Prof = r.Prof, N = 5, M = 4, Line = false, Deep = true, WhiteTip = true,
			Shadow = 0.04 }
		for k = 0, r.N - 1 do
			local a = 2 * math.pi * (k + r.Off) / r.N
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			o.F = CFrame.fromMatrix(dir * r.R0 + Vector3.new(0, 0.12, 0), dir, Vector3.yAxis)
			giantPetal(out, o)
		end
	end
end
FL.Edge = { Sectors = 16, PerSector = 3, Heroes = 6 }
SPECS.FieldEdge = function(out)        -- one sector (22.5 deg) of the boundary: 3 petals
	local o = { L = 2.7, W = 2.75, Cup = 0.35, Prof = function(u) return 74 - 10 * u * u end, N = 4, M = 2, LineW = 0.32,
		Deep = true, WhiteTip = true, Shadow = 0.04 }
	for k = 0, 2 do
		local a = 2 * math.pi * (k + 0.5) / 48
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		o.F = CFrame.fromMatrix(dir * 18.7 + Vector3.new(0, 0.12, 0), dir, Vector3.yAxis)
		giantPetal(out, o)
	end
end
SPECS.FieldHero = function(out)        -- one hero petal, its base at the origin, opening along +X
	giantPetal(out, { L = 4.0, W = 3.2, Cup = 0.4, Prof = function(u) return 80 - 16 * u * u end, N = 6, M = 2, LineW = 0.34,
		Deep = true, WhiteTip = true, Shadow = 0.04, F = CFrame.fromMatrix(Vector3.new(0, 0.12, 0), Vector3.xAxis, Vector3.yAxis) })
end
for name, n in pairs({ Flutter = 4, FlutterS = 2 }) do   -- a loose petal, centred, +Y along it, +Z its face
	SPECS[name] = function(out)
		giantPetal(out, { L = 1, W = 0.5, Cup = 0.35, Prof = function() return 0 end, N = n, M = 2, Line = name == "Flutter",
			LineW = 0.06, Deep = true, WhiteTip = true, F = CFrame.fromMatrix(Vector3.new(0, -0.5, 0), Vector3.yAxis, Vector3.zAxis) })
	end
end
SPECS.HitLotus = function(out)         -- 6 open petals, unit radius, +Y the way it faces
	local o = { L = 1, W = 0.5, Cup = 0.35, Prof = function(u) return 35 - 15 * u * u end, N = 2, M = 2, Line = false,
		Deep = true, WhiteTip = true }
	for k = 0, 5 do
		local a = math.pi * k / 3
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		o.F = CFrame.fromMatrix(dir * 0.06, dir, Vector3.yAxis)
		giantPetal(out, o)
	end
end
SPECS.Streak = function(out)           -- the Blizzard's petal streak (Epic stage 3): long and thin, centred, +Y along it;
	-- a pale white-cyan face and a glowing Frost Line edge (no dark underside: it has to read bright against the snow)
	giantPetal(out, { L = 2.4, W = 0.42, Cup = 0.2, Prof = function() return 0 end, N = 2, M = 2, Line = true, LineW = 0.06,
		Flat = FL.Look.Dew, WhiteTip = true, F = CFrame.fromMatrix(Vector3.new(0, -1.2, 0), Vector3.yAxis, Vector3.zAxis) })
end
SPECS.HitRing = function(out)          -- a thin flat ring, unit radius, both faces (glowing)
	local n = 20
	for k = 0, n - 1 do
		local a, b = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
		local o0, o1 = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(math.cos(b), 0, math.sin(b))
		for _, nn in ipairs({ Vector3.yAxis, -Vector3.yAxis }) do
			tri(out.Body, o0 * 0.92, o0, o1, WHITE, WHITE, WHITE, nn, nn.Y > 0 and 1 or 2)
			tri(out.Body, o0 * 0.92, o1, o1 * 0.92, WHITE, WHITE, WHITE, nn, nn.Y > 0 and 1 or 2)
		end
	end
	out.NeonBody, out.BodyT = true, 0.05
end
SPECS.GiantStamens = function(out) giantStamens(out) out.NeonBody = true end

----------------------------------------------------------------------------------------------------
-- building (the TerraWrap / FrostbladeKit pattern): one resizable EditableMesh at a time, copied into a fixed-size one
----------------------------------------------------------------------------------------------------
local function vkey(v)
	return string.format("%d,%d,%d", math.floor(v.X * 4000 + 0.5), math.floor(v.Y * 4000 + 0.5), math.floor(v.Z * 4000 + 0.5))
end

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
	-- (2026-10-19, audit GB-01) the writes and the fixed copy guarded, FrostDragonKit's way: the resizable mesh is freed
	-- on every path, not left allocated (and the shared budget lowered) when a step raises
	local okB, errB = pcall(function()
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
			if (P[2] - P[1]):Cross(P[3] - P[1]):Dot(t[7]) < 0 then
				P[2], P[3], Cc[2], Cc[3] = P[3], P[2], Cc[3], Cc[2]
			end
			local f = em:AddTriangle(vtx(P[1] - c), vtx(P[2] - c), vtx(P[3] - c))
			em:SetFaceColors(f, { col(Cc[1]), col(Cc[2]), col(Cc[3]) })
			local ns = {}
			for k = 1, 3 do
				local a = acc[vkey(P[k]) .. "#" .. t[8]]
				ns[k] = nrm((a and a.Magnitude > 1e-9) and a.Unit or t[7])
			end
			em:SetFaceNormals(f, ns)
			if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
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
	keep[#keep + 1] = fixed
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok then mp = AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Color = WHITE
	return mp, c, #tris
end

local kinds = {}            -- [name] = { Body, BodyOff, Heart?, HeartOff, Line?, LineOff, Size, Tris, L }
local building = false
FL.Tris = {}

local function buildKind(name)
	local out = { Body = {}, Heart = {}, Line = {} }
	SPECS[name](out)
	local k = { L = LENGTH[name] or 1 }
	local body, off, nt = meshPart(out.Body)
	body.Name = "FrostLotus" .. name
	body.Material, body.Transparency, body.Reflectance = Enum.Material.Ice, FL.Look.IceT, FL.Look.Reflect
	if out.NeonBody then                                  -- the giant lotus's pod and stamens: the glowing heart's look
		k.BodyT = out.BodyT or FL.Look.PodT
		body.Material, body.Color, body.Transparency, body.Reflectance = Enum.Material.Neon, FL.Look.LineHot, k.BodyT, 0
	end
	k.Body, k.BodyOff, k.Size = body, off, body.Size
	for key, v in pairs(out.Extra or {}) do k[key] = v end
	local total = nt
	if #out.Heart > 0 then
		local p, c, t = meshPart(out.Heart)
		p.Name = "FrostLotusHeart"
		p.Material, p.Color, p.Transparency = Enum.Material.Neon, FL.Look.Heart, FL.Look.HeartT
		k.Heart, k.HeartOff, total = p, c, total + t
	end
	if #out.Line > 0 then
		local p, c, t = meshPart(out.Line)
		p.Name = "FrostLotusLine"
		p.Material, p.Color, p.Transparency = Enum.Material.Neon, FL.Look.Line, 0
		k.Line, k.LineOff, total = p, c, total + t
	end
	k.Tris = total
	FL.Tris[name] = total
	kinds[name] = k
end

-- (kept in SPECS, not built: DomeSmall / DomeMedium / DomeBig, DartRare, FieldRing1-3, and the Epic Flash Freeze's
-- FieldMandalaA-D / FieldEdge / FieldHero / FieldHeart / Flutter -- Flash Freeze is the Rare FieldBloom again, 2026-10-15)
local ORDER = { "Dart", "BladeMote", "HitLotus", "HitRing", "FlutterS", "Lance", "Mote", "MiniBloom", "FieldBloom", "Streak",
	"PrintBloom", "TrapBloom", "HandPetal", "HeldLotus", "HeldSlot", "GiantOuter", "GiantMiddle", "GiantInner", "GiantPod",
	"GiantStamens" }
local attempts = 0                -- builds tried: a failed one is tried again later, a few times
local usedAt = 0                  -- the last New / Place / Get (a kit nobody wears lets go of its meshes, below)
local releaseHooks = {}           -- the pools of this kit's pieces elsewhere (OnRelease): emptied with it
function FL.OnRelease(fn) releaseHooks[#releaseHooks + 1] = fn end
local wanted = function() return true end   -- whether anybody here still wears the skin (the lazy block's, below)
function FL.Build()
	if building or FL.Built then return end
	building = true
	FL.Failed = nil
	attempts += 1
	MeshBudget.Essential(FL.Id, true)         -- (while it builds, no optional mesh starts)
	task.spawn(function()
		-- (2026-10-19, audit P5A-08) all or nothing, FrostDragonKit's rule: Built only when every kind built; else Failed,
		-- the templates and meshes freed, and On() stays false so every piece draws the Default (as the header promises)
		local failed = false
		for _, name in ipairs(ORDER) do
			local ok, err = pcall(buildKind, name)
			if not ok then
				failed = true
				warn("[FrostLotusKit] " .. name .. ": " .. tostring(err))
				break                                       -- (the rest would only wait on the same budget)
			end
			task.wait()
		end
		if failed then
			for _, k in pairs(kinds) do
				for _, key in ipairs({ "Body", "Heart", "Line" }) do
					local mp = k[key]
					if mp then pcall(function() mp:Destroy() end) end
				end
			end
			for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
			table.clear(kinds)
			table.clear(keep)
			FL.Failed = true
			MeshBudget.Essential(FL.Id, false)
			-- not for good (2026-10-19): the budget frees as wraps and other effects let go of theirs, so the build is tried
			-- again while somebody still wears the skin -- after 15, 30, 60 and 120 s -- before the Default stays
			building = false
			if attempts < 5 then
				task.delay(15 * 2 ^ (attempts - 1), function() if wanted() then FL.Build() end end)
			end
			return
		end
		FL.Built = true
		building = false                          -- (2026-10-27) left true, releaseKit never let a built kit go: the Loadout's
		                                          -- browsed skins held their meshes all session and starved every later build
		MeshBudget.Essential(FL.Id, false)
	end)
end

--- The template of `name` (nil until it is built).
function FL.Kind(name)
	return kinds[name]
end

----------------------------------------------------------------------------------------------------
-- a piece in the world: New(kind) -> { Body, Heart?, Line? }; Place it at frame K, scale `s`
----------------------------------------------------------------------------------------------------
function FL.New(name, parent)
	usedAt = os.clock()
	local k = kinds[name]
	if not k then return nil end
	local o = { Kind = k, Body = k.Body:Clone(), S = 1, SY = 1, F = -1 }
	if k.Heart then o.Heart = k.Heart:Clone() end
	if k.Line then o.Line = k.Line:Clone() end
	if parent then FL.Parent(o, parent) end
	return o
end

function FL.Parent(o, parent)
	o.Body.Parent = parent
	if o.Heart then o.Heart.Parent = parent end
	if o.Line then o.Line.Parent = parent end
end

function FL.Drop(o)
	if not o then return end
	for _, key in ipairs({ "Body", "Heart", "Line" }) do
		local p = o[key]
		if p then pcall(function() p:Destroy() end) end
	end
end

--- 0 = as built, 1 = gone
function FL.Fade(o, f)
	if f == o.F then return end
	o.F = f
	local L = FL.Look
	local bt = o.Kind.BodyT or L.IceT
	o.Body.Transparency = (f >= 1) and 1 or (bt + (1 - bt) * f)
	if o.Heart then o.Heart.Transparency = (f >= 1) and 1 or (L.HeartT + (1 - L.HeartT) * f) end
	if o.Line then o.Line.Transparency = f end
end

function FL.Place(o, K, parts, cframes, s, sy)
	usedAt = os.clock()
	s, sy = s or 1, sy or 1
	local k = o.Kind
	local sv = Vector3.new(s, s * sy, s)
	if s ~= o.S or sy ~= o.SY then
		o.S, o.SY = s, sy
		o.Body.Size = k.Size * sv
		if o.Heart then o.Heart.Size = k.Heart.Size * sv end
		if o.Line then o.Line.Size = k.Line.Size * sv end
	end
	parts[#parts + 1] = o.Body
	cframes[#cframes + 1] = K * CFrame.new(k.BodyOff * sv)
	if o.Heart then
		parts[#parts + 1] = o.Heart
		cframes[#cframes + 1] = K * CFrame.new(k.HeartOff * sv)
	end
	if o.Line then
		parts[#parts + 1] = o.Line
		cframes[#cframes + 1] = K * CFrame.new(k.LineOff * sv)
	end
end

--- The M1 blade's trail (VFXLibrary hands over each lotus shot look once): five hard-edged petal motes strung out at
--- fixed distances behind the blade's tail along the path it flew (MOTES), smaller and paler down the line, spinning;
--- hidden with the blade. Each look keeps its own five (pooled with it).
local MOTES = { 0.4, 1.45, 2.5, 3.55, 4.6 }
local riders, riding = {}, false
function FL.Ride(look)
	local mk = kinds.BladeMote
	if not mk or riders[look] then return end
	look.Motes, look.Hist = {}, {}
	for i = 1, #MOTES do
		local m = mk.Body:Clone()
		m.Size = mk.Size * (1.05 - 0.12 * i)
		m.Transparency = mk.BodyT + 0.1 * (i - 1)
		look.Motes[i] = m
	end
	riders[look] = true
	if riding then return end
	riding = true
	RunService:BindToRenderStep("FrostLotusRiders", Enum.RenderPriority.Last.Value, function()
		local now = os.clock()
		for lk in pairs(riders) do
			local body = lk.Body
			if body and body.Parent and body.Transparency < 1 then
				local h = lk.Hist
				if not h[1] or (h[1] - body.Position).Magnitude > 0.05 then
					table.insert(h, 1, body.Position)
					if #h > 24 then h[#h] = nil end
				end
				local back = body.Size.Y * 0.5
				local rot = body.CFrame.Rotation
				for i, m in ipairs(lk.Motes) do
					local want, acc, at = back + MOTES[i], 0, nil
					local p0 = body.Position
					for j = 1, #h do
						local seg = (h[j] - p0).Magnitude
						if seg > 1e-4 and acc + seg >= want then
							at = p0 + (h[j] - p0) * ((want - acc) / seg)
							break
						end
						acc += seg
						p0 = h[j]
					end
					if at then
						if m.Parent ~= body.Parent then m.Parent = body.Parent end
						m.CFrame = CFrame.new(at) * rot * CFrame.Angles(now * 11 + i * 2.1, now * 7 + i, 0)
					elseif m.Parent then
						m.Parent = nil
					end
				end
			elseif #lk.Hist > 0 or (lk.Motes[1] and lk.Motes[1].Parent) then
				table.clear(lk.Hist)
				for _, m in ipairs(lk.Motes) do m.Parent = nil end
			end
		end
	end)
end

--- A petal frame: base at `tail`, pointing along `dir`, the width along `side` (made square to `dir`).
function FL.Frame(tail, dir, side)
	dir = dir.Unit
	local sd = side - dir * side:Dot(dir)
	if sd.Magnitude < 1e-3 then
		sd = Vector3.yAxis - dir * dir.Y
		if sd.Magnitude < 1e-3 then sd = Vector3.xAxis - dir * dir.X end
	end
	return CFrame.fromMatrix(tail, sd.Unit, dir)
end

--- A bloom frame: centre `c`, its face opening along `up`.
function FL.BloomFrame(c, up, yaw)
	up = up.Unit
	local x = up:Cross(math.abs(up.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis).Unit
	local f = CFrame.fromMatrix(c, x, up)
	return yaw and (f * CFrame.Angles(0, yaw, 0)) or f
end

----------------------------------------------------------------------------------------------------
-- the rooted body blossoms (kit/fl_field.py body_ice): mini blooms all over -- shoulders, upper arms, back, chest sides,
-- hips, thighs, calves; front, back and sides alternating, so any count reads as the whole body; never the head, the
-- face or the middle of the chest. Each: a body part, the bloom's frame relative to it, its radius, its sprout delay
-- (a quick wave from the feet up).
----------------------------------------------------------------------------------------------------
local R6 = { UpperTorso = "Torso", LowerTorso = "Torso", RightUpperArm = "Right Arm", LeftUpperArm = "Left Arm",
	RightUpperLeg = "Right Leg", LeftUpperLeg = "Left Leg", RightLowerLeg = "Right Leg", LeftLowerLeg = "Left Leg" }
local function bodyPart(model, name)
	local p = model:FindFirstChild(name) or (R6[name] and model:FindFirstChild(R6[name]))
	return (p and p:IsA("BasePart")) and p or nil
end
-- (the kit's zk parts -> R15: torso_hi UpperTorso, torso_lo LowerTorso, uarm RightUpperArm, thigh RightUpperLeg, shin
-- RightLowerLeg); offsets along the body's right / up, in the part's half-extents
local SPOTS = {
	{ "UpperTorso", "fw", 0.72, 0.25, 0.44 }, { "UpperTorso", "-fw", 0.0, 0.3, 0.5 }, { "RightUpperLeg", "fw", 0.1, 0.25, 0.4 },
	{ "LeftUpperArm", "fw", 0.0, 0.2, 0.38 }, { "UpperTorso", "fw", -0.72, 0.1, 0.44 }, { "LeftLowerLeg", "-fw", 0.0, 0.1, 0.34 },
	{ "RightUpperArm", "fw", 0.0, 0.1, 0.38 }, { "LowerTorso", "fw", 0.55, 0.0, 0.38 }, { "UpperTorso", "-fw", -0.55, -0.45, 0.4 },
	{ "LeftUpperLeg", "fw", -0.1, -0.1, 0.38 }, { "UpperTorso", "up", 0.78, 0.0, 0.36 }, { "LeftUpperLeg", "-rt", 0.0, 0.2, 0.38 },
	{ "RightLowerLeg", "fw", 0.0, 0.0, 0.32 }, { "UpperTorso", "up", -0.78, 0.0, 0.36 }, { "RightUpperArm", "rt", 0.0, 0.2, 0.34 },
	{ "LowerTorso", "-fw", 0.3, 0.0, 0.36 }, { "RightUpperLeg", "-fw", 0.0, -0.1, 0.34 }, { "LeftUpperArm", "-rt", 0.0, 0.0, 0.32 },
	{ "UpperTorso", "-fw", 0.55, -0.5, 0.36 }, { "LeftLowerLeg", "fw", 0.0, -0.2, 0.3 }, { "LowerTorso", "-rt", 0.0, 0.0, 0.32 },
	{ "RightLowerLeg", "-fw", 0.0, 0.2, 0.32 }, { "UpperTorso", "rt", 0.0, -0.3, 0.34 }, { "UpperTorso", "-rt", 0.0, -0.2, 0.34 },
}
function FL.BodyBlooms(model, n, t0)
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
			local R = sp[5]
			if not head or (pt - head.Position).Magnitude >= 0.8 + R then
				local K = FL.BloomFrame(pt + nrm * 0.02, nrm, 1.3 * #out)
				out[#out + 1] = { Kind = "MiniBloom", Part = p, Rel = p.CFrame:ToObjectSpace(K), S = R, Grow = true,
					Delay = (t0 or 0) + 0.03 + 0.3 * math.clamp((pt.Y - feetY) / 4.2, 0, 1), Dur = 0.22 }
			end
		end
	end
	return out
end

--- Flash Freeze's field: n blooms of different sizes on a zone of radius R -- about half on the rim (their outer petal
--- tips on the Frost Line ring), the rest inside, none on `avoid` (zone-local x, z). -> { { X, Z, R } }, deterministic.
function FL.Field(n, R, seed, avoid)
	local rng = Random.new(seed or 7)
	local k = R / 6                                                    -- the Blender zone is 6 studs; the game's R
	local out = {}
	local nr = math.max(3, math.floor(n * 0.5 + 0.5))
	for i = 0, nr - 1 do
		local r = rng:NextNumber(0.95, 1.5) * k
		local a = 2 * math.pi * i / nr + rng:NextNumber(-0.15, 0.15) + 0.3
		out[#out + 1] = { X = math.cos(a) * (R - r), Z = math.sin(a) * (R - r), R = r }
	end
	local tries = 0
	while #out < n and tries < 5000 do
		tries += 1
		local r = rng:NextNumber(0.7, 1.35) * k
		local d = math.sqrt(rng:NextNumber()) * (R - r - 0.8 * k)
		local a = rng:NextNumber(0, 2 * math.pi)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local ok = not (avoid and math.sqrt((x - avoid.X) ^ 2 + (z - avoid.Y) ^ 2) < r + 1.25 * k)
		for _, b in ipairs(out) do
			if ok and math.sqrt((x - b.X) ^ 2 + (z - b.Z) ^ 2) < (r + b.R) * 0.95 then ok = false end
		end
		if ok then out[#out + 1] = { X = x, Z = z, R = r } end
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- the Rare layer: dew glints (a soft four-point star) and ice glitter (a fine mote). Never a hard flash: in over 0.3 s,
-- out over 0.35 s and more; pale white-cyan, under the Frost Line; Reduce Flashing: a steady soft glow. Sparkles.On:
-- the layer's own switch (the IceMagic folder's attribute FrostLotusSparkles = false turns it off).
----------------------------------------------------------------------------------------------------
local function NS(a, b) return NumberSequence.new(a, b) end
--- the M1 hold-and-pluck's own switch (the IceMagic folder's attribute FrostLotusPluck = false: the Default's alternating
--- throw, with the petal dart still the shot)
function FL.PluckOn()
	local f = ReplicatedStorage:FindFirstChild("IceMagic")
	return not (f and f:GetAttribute("FrostLotusPluck") == false)
end
function FL.SparklesOn()
	local f = ReplicatedStorage:FindFirstChild("IceMagic")
	return not (f and f:GetAttribute("FrostLotusSparkles") == false)
end

function FL.Emitter(kind, parent, calm)
	local e = Instance.new("ParticleEmitter")
	e.Texture = FL.Look.Sparkle
	local dew = kind == "dew"
	e.Color = ColorSequence.new(dew and FL.Look.Dew or FL.Look.Glitter)
	e.LightEmission = calm and 0.25 or (dew and 0.6 or 0.4)
	e.LightInfluence = 0.2
	e.Size = dew and NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.4, 0.28),
		NumberSequenceKeypoint.new(1, 0.05) }) or NS(0.07, 0.03)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, calm and 0.45 or 0.15),
		NumberSequenceKeypoint.new(0.65, calm and 0.45 or 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(dew and 0.8 or 0.9, dew and 1.1 or 1.4)
	e.Speed = NumberRange.new(0.2, 0.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(calm and 0 or -40, calm and 0 or 40)
	e.Drag = 2
	e.Acceleration = Vector3.new(0, dew and 0.2 or -0.3, 0)
	e.Rate = 0
	e.LockedToPart = false
	e.Parent = parent
	return e
end

----------------------------------------------------------------------------------------------------
-- THE M1 HOLD-AND-PLUCK, third person (the developer's request): while a Frost Lotus caster is throwing (FrostLotusHold
-- on the character: the server time the hold ends -- the last shot + 1 s, set by AbilityFX on each shot), the LEFT
-- hand holds the lotus low in front (CastPose layers the arm here; the throwing clip is the right hand's, every shot),
-- and the lotus rides the left hand; a petal rides the right hand from the pluck to the release. Not on this client's own
-- body in first person (the viewmodel's own hold: FrostLotusFX.ViewmodelHold).
----------------------------------------------------------------------------------------------------
local HOLD_ARM = { Arm = 42, Elbow = 78, In = 26, Wrist = -18 }
local holds = setmetatable({}, { __mode = "k" })     -- [character] = { W, Lotus, Slot, Petal }

local function firstPerson(character)
	if character ~= Players.LocalPlayer.Character then return false end
	local cam, head = workspace.CurrentCamera, character:FindFirstChild("Head")
	return cam ~= nil and head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.5
end
FL.FirstPerson = firstPerson

local function dropHold(h)
	for _, key in ipairs({ "Lotus", "Slot", "Petal" }) do
		if h[key] then FL.Drop(h[key]) h[key] = nil end
	end
	if h.Conn then h.Conn:Disconnect() h.Conn = nil end
end

function FL.M1(state, pose, dt)
	local character = state.Character
	local untilT = character:GetAttribute("FrostLotusHold")
	local h = holds[character]
	local now = workspace:GetServerTimeNow()
	-- any other cast lets the lotus go at once (it is never carried into another ability)
	local on = type(untilT) == "number" and now < untilT and not firstPerson(character)
		and not (state.Clip and state.ClipName ~= "IcicleShardLotus")
	if not on and not h then return end
	if not h then
		h = { W = 0 }
		holds[character] = h
	end
	h.W = on and math.min(1, h.W + dt / 0.1) or math.max(0, h.W - dt / 0.3)
	if h.W > 0 then
		local L = pose.L
		for ch, v in pairs(HOLD_ARM) do L[ch] = L[ch] + (v - L[ch]) * h.W end
	end
	local hand = character:FindFirstChild("LeftHand")
	if h.W > 0.02 and hand and kinds.HeldLotus then
		if not h.Lotus then
			h.Lotus, h.Slot = FL.New("HeldLotus"), FL.New("HeldSlot")
			local okW, W = pcall(require, script.Parent:FindFirstChild("CryoWrap"))      -- (the wearer's colour wrap)
			if okW and W and W.PaintFor then W.PaintFor(h.Lotus, character) W.PaintFor(h.Slot, character) end
			for _, o in ipairs({ h.Lotus, h.Slot }) do
				for _, p in ipairs({ o.Body, o.Heart, o.Line }) do
					if p then p.Parent = workspace end
				end
			end
			-- (2026-10-19, audit P5A-14) the pieces live in workspace, and FL.M1 is never called again once the body
			-- leaves (CastPose drops its state): the hold goes with the character (respawn, leaving, streamed out)
			h.Conn = character.AncestryChanged:Connect(function(_, parent)
				if parent ~= nil then return end
				dropHold(h)
				if holds[character] == h then holds[character] = nil end
			end)
		end
		-- on the palm, opening up and a little forward; it unfurls with the first shot, folds away at the end
		local K = hand.CFrame * CFrame.new(0, -0.15, -0.35) * CFrame.Angles(math.rad(-20), 0, 0)
		local parts, cframes = {}, {}
		local s = 0.9 * h.W
		FL.Place(h.Lotus, K, parts, cframes, s)
		local pk = character:GetAttribute("FrostLotusPluck")
		local r = 1
		if type(pk) == "number" then
			local a = now - pk
			if a >= 0 and a < 0.16 then r = (a < 0.04) and 0.001 or math.min(1, (a - 0.04) / 0.12) end
		end
		FL.Place(h.Slot, K, parts, cframes, s * r)
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	elseif h.W <= 0.02 then
		dropHold(h)
		if not on then holds[character] = nil end
	end
end

----------------------------------------------------------------------------------------------------
-- THE M1 HOLD-AND-PLUCK, first person: the lotus on the viewmodel's left fist (low in the frame, never over the
-- crosshair), the plucked slot regrowing at once, the petal riding the right fist from the pluck to the release (the
-- Default's 0.107 s); it folds away 1 s after the last shot and `onFold` lets the left arm go. The arms stay bare skin.
----------------------------------------------------------------------------------------------------
local view = { Until = 0, Pluck = -1 }
local function viewDrop()
	for _, key in ipairs({ "Lotus", "Slot", "Petal" }) do
		if view[key] then FL.Drop(view[key]) view[key] = nil end
	end
end

function FL.ViewShot(getFist, onFold)
	local now = os.clock()
	if now > view.Until then view.Start = now end
	view.Until, view.Pluck, view.GetFist, view.OnFold = now + 0.453 + 1.0, now, getFist, onFold
	if view.Bound then return end
	view.Bound = true
	RunService:BindToRenderStep("FrostLotusView", Enum.RenderPriority.Camera.Value + 4, function()
		local t = os.clock()
		local fistL = view.GetFist and view.GetFist("L")
		if t > view.Until or not kinds.HeldLotus then
			viewDrop()
			view.Bound = false
			RunService:UnbindFromRenderStep("FrostLotusView")
			if view.OnFold then task.spawn(view.OnFold) end
			return
		end
		if not fistL then
			viewDrop()
			return
		end
		if not view.Lotus then
			view.Lotus, view.Slot, view.Petal = FL.New("HeldLotus", workspace), FL.New("HeldSlot", workspace), FL.New("HandPetal", workspace)
			local okW, W = pcall(require, script.Parent:FindFirstChild("CryoWrap"))      -- (the wearer's colour wrap)
			if okW and W and W.PaintFor then
				local me = game:GetService("Players").LocalPlayer.Character
				for _, o in ipairs({ view.Lotus, view.Slot, view.Petal }) do W.PaintFor(o, me) end
			end
		end
		local cam = workspace.CurrentCamera
		local up = (cam.CFrame.UpVector * 0.85 - cam.CFrame.LookVector * 0.35).Unit
		local K = FL.BloomFrame(fistL.Position + fistL.UpVector * 0.1, up)
		local g = math.clamp((t - (view.Start or t)) / 0.1, 0, 1) * (1 - math.clamp((t - (view.Until - 0.3)) / 0.3, 0, 1))
		local s = 0.4 * math.max(0.001, g)
		local parts, cframes = {}, {}
		FL.Place(view.Lotus, K, parts, cframes, s)
		local a = t - view.Pluck
		local r = (a >= 0 and a < 0.16) and ((a < 0.04) and 0.001 or math.min(1, (a - 0.04) / 0.12)) or 1
		FL.Place(view.Slot, K, parts, cframes, s * r)
		local fistR = view.GetFist("R")
		if fistR and a >= 0.02 and a < 0.107 then                    -- the petal in the right hand, from the pluck to the release
			FL.Fade(view.Petal, 0)
			FL.Place(view.Petal, FL.Frame(fistR.Position, fistR.LookVector, fistR.RightVector), parts, cframes, 0.6)
		else
			FL.Fade(view.Petal, 1)
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

-- LAZY build (2026-10-17, as FrostDragonKit): only once a player in the server wears this skin, or -- in Studio -- a test
-- dummy stands in for it (StudioSkin). Every Cryo skin and wrap shares one EditableMesh budget per client; a kit nobody
-- in the server wears takes none of it (eager builds of all four overran it, and the worn skin fell back to the Default).
--- MeshBudget's Optional (2026-10-19): a built kit nobody here wears right now -- no player is Cryo in this skin, no Studio
--- stand-in -- and that placed no piece for 10 s lets go of every mesh, so another Element's worn wrap (Terra's Obsidian
--- Magma) can have the budget; the next player to be Cryo in the skin builds it again. Its pooled pieces elsewhere go
--- with it (OnRelease). Built goes false first, so whatever asks from now on draws the Default.
local function releaseKit()
	if building or not FL.Built or os.clock() - usedAt < 10 then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character and FL.On(plr.Character) then return end
	end
	if RunService:IsStudio() then
		for _, m in ipairs(workspace:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("StudioSkin") == FL.Id then return end
		end
	end
	if #FL.Showcased() > 0 then return end              -- (2026-10-26) a showcase stand-in wears it, live and in Studio
	FL.Built = false
	for _, fn in ipairs(releaseHooks) do pcall(fn) end
	for _, k in pairs(kinds) do
		for _, key in ipairs({ "Body", "Heart", "Line" }) do
			local mp = k[key]
			if mp then pcall(function() mp:Destroy() end) end
		end
	end
	for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
	table.clear(kinds)
	table.clear(keep)
	attempts = 0
end
MeshBudget.Optional(releaseKit)
--- (2026-10-26) the same let-go without the 10 s idle wait: the Altar showcase calls it on a swap, once the piece that
--- showed this skin is gone (still nothing if a player wears it, a stand-in still shows it, or it is building)
function FL.ReleaseNow()
	usedAt = 0
	releaseKit()
end

do
	-- (2026-10-19) one build at a time; after a failed one, the next player to put the skin on starts another
	local function go()
		FL.Build()
	end
	local attr = SkinCatalog.ElementSkinAttr("Cryo")
	local function check(plr)
		if FL.Built then return end
		local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Cryo")
		if ok and id == FL.Id and (plr:GetAttribute("Element") or "Cryo") == "Cryo" then go() end
	end
	wanted = function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Cryo")
			if ok and id == FL.Id and (plr:GetAttribute("Element") or "Cryo") == "Cryo" then return true end
		end
		if RunService:IsStudio() then
			for _, m in ipairs(workspace:GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("StudioSkin") == FL.Id then return true end
			end
		end
		return #FL.Showcased() > 0                         -- (2026-10-26) a showcase stand-in, live and in Studio
	end
	local function watch(plr)
		check(plr)
		plr:GetAttributeChangedSignal(attr):Connect(function() check(plr) end)
		plr:GetAttributeChangedSignal("Element"):Connect(function() check(plr) end)   -- (back to Cryo: a released kit again)
	end
	for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
	Players.PlayerAdded:Connect(watch)
	if RunService:IsStudio() then
		local function dummy(m) if m:IsA("Model") and m:GetAttribute("StudioSkin") == FL.Id then go() end end
		for _, m in ipairs(workspace:GetChildren()) do dummy(m) end
		workspace.ChildAdded:Connect(function(m) task.defer(dummy, m) end)
	end
	-- (2026-10-26) a showcase stand-in (ShowcaseSkin, live and in Studio) builds it too, wherever in the workspace it is put
	if RunService:IsClient() then
		local function stand(m) if m.Parent and FL.Showcase(m) then go() end end
		workspace.DescendantAdded:Connect(function(m) if m:IsA("Model") then task.defer(stand, m) end end)
	end
end
return FL
