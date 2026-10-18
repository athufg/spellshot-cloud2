--[[
	FrostbladeKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/FrostbladeKit

	Cryo's FROSTBLADE skin (an Uncommon Element Skin, 2026-10-14; designed and rendered in Blender:
	vfx_blocking/cryo/cryo_frostblade_skin_2026_10_14, the contract is its HANDOFF_SPEC.md). Every Cryo piece is remodelled
	as an ICE KUNAI -- a leaf blade with a centre ridge, a short tang, a small ring at the tail -- in the shipped v2 real ice;
	the Frost Line stays the Default's thin line. Cosmetic only: damage, hitboxes, timing and beats are the Default's.

	  On(character)        whether that body's player wears it (SkinCatalog: ElementSkin_Cryo = "Frostblade", on Cryo)
	  New(kind) / Place    a kunai of one of the KINDS below (its Body, and the Core / Line where the kind has them), and
	                       where its parts go for a kunai frame K: the tail at K's origin, +Y to the tip, X across the blade
	  Pierce / Stuck / Trap  where the kunai go on a frozen body (Flash Freeze's pierce, Deep Freeze's trap)
	  Naruto(state, pose)  Cold Momentum's run (CastPose calls it every frame, for every body)

	The meshes are built once per client, at load, from EditableMeshes (the port of the kit's kunai_lp, kit/fb.py) and
	copied into fixed-size ones (only 8 RESIZABLE meshes may live at once; TerraWrap holds up to 3 of them, this builds one
	at a time). Until they are built, and on any failure, every piece simply draws Default.
	Who draws what: VFXLibrary the shard in flight; CryoFX everything else; CastPose the run.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local FB = {}
FB.Id = "Frostblade"

--- Whether `character`'s player wears Frostblade (their Cryo skin, while Cryo is their Element).
function FB.On(character)
	if typeof(character) ~= "Instance" then return false end
	local plr = Players:GetPlayerFromCharacter(character)
	-- Studio only: a dummy with StudioSkin stands in for a caster (the skins' side-by-side test); never live
	if not plr then return game:GetService("RunService"):IsStudio() and character:GetAttribute("StudioSkin") == FB.Id end
	if (plr:GetAttribute("Element") or "Cryo") ~= "Cryo" then return false end
	return SkinCatalog.ElementSkin(plr, "Cryo") == FB.Id
end

-- the counts (HANDOFF_SPEC), and their Graphics Quality scale-down: high / medium / low
FB.PierceBig = { 3, 2, 1 }
FB.StuckSmall = { 6, 3, 0 }
FB.TrapBlades = { 8, 6, 4 }
FB.TrapStuck = { 4, 2, 0 }
FB.RingBlades = { 16, 10, 6 }
FB.EdgeBlades = 6
-- (2026-10-15 tuning, the developer: "more kunai and bigger in Flash Freeze, larger trapping kunai in Flash Freeze and
-- Deep Freeze") -- 1 = the approved build. Flash Freeze's field round the rim, high / medium / low (was EdgeBlades 6),
-- and each blade's size; the step up of Flash Freeze's big pierce and of Deep Freeze's trap blades. Lodged ones as built.
FB.FieldBlades = { 12, 10, 6 }
FB.FieldScale = 1.4
FB.PierceScale = 1.7
FB.TrapScale = 1.6
FB.CloneScale = 0.55
FB.ShatterChunks = { 8, 5, 3 }
--- 1 high, 2 medium, 3 low (Graphics Quality); `thin` (Reduce Enemy VFX on somebody else's) counts as low
function FB.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

if not RunService:IsClient() then
	return FB                       -- the server only asks On(); nothing below is built there
end

----------------------------------------------------------------------------------------------------
-- the look: the shipped v2 ice (a translucent Ice part), its thickness in the vertex colours -- pale at the thin edges,
-- deeper down the ridge -- frost on the ring and the tang, the cold-silver bevel on the blade's edges
----------------------------------------------------------------------------------------------------
local function hex(h) return Color3.fromHex(h) end
local EDGE, RIDGE, ROOT, TIP = hex("#C4E8FA"), hex("#7FC3EC"), hex("#5BB0E2"), hex("#DDF3FD")
local FROST, SILVER, WHITE = hex("#EAF7FD"), hex("#CFDCE6"), Color3.new(1, 1, 1)
FB.Look = {
	IceT = 0.25, Reflect = 0.15,                 -- the shipped real ice
	Core = hex("#9FE6FF"), CoreT = 0.2,          -- the inner glow (big blades only)
	Line = hex("#3FE0FF"), LineHot = hex("#8DF3FF"),
	Clone = hex("#BDEBFA"), CloneT = 0.3,        -- Mirror Cage's ice clones of the caster
	Nick = hex("#2F7EC2"), NickT = 0.15,         -- Cold Momentum's crossed nicks: deep glassy ice
}

----------------------------------------------------------------------------------------------------
-- the kunai (kit/fb.py kunai_lp): a flat 6-segment ring in the blade plane (both faces: a mesh here is one-sided), a
-- 4-sided tang, a leaf blade as a ridged bipyramid widest 40 % up, the bevel bands on its edge facets, an optional inner
-- core. Built in the frame F: tail at F's origin, +Y to the tip, X across the blade, Z through it.
----------------------------------------------------------------------------------------------------
local function tri(list, a, b, c, ca, cb, cc, ref)
	local n = (b - a):Cross(c - a)
	if n.Magnitude < 1e-9 then return end
	n = n.Unit
	if n:Dot((a + b + c) / 3 - ref) < 0 then n = -n end
	list[#list + 1] = { a, b, c, ca, cb, cc, n }
end

local function quad(list, p, cs, ref)
	tri(list, p[1], p[2], p[3], cs[1], cs[2], cs[3], ref)
	tri(list, p[1], p[3], p[4], cs[1], cs[3], cs[4], ref)
end

local function kunai(out, F, o)
	local L, W, T = o.L, o.W, o.T
	local u, s, n = F.UpVector, F.RightVector, -F.LookVector
	local O = F.Position
	local ro = o.RingRo or W * 0.5
	local R = W / 2
	local y0 = 0
	if o.Ring ~= false then
		local C0 = O + u * ro
		local ri = ro * 0.55
		local P = {}
		for i = 0, 5 do
			local a = 2 * math.pi * i / 6
			local d = u * math.cos(a) + s * math.sin(a)
			P[i] = { C0 + d * ro, C0 + d * ri }
		end
		local fr = { FROST, FROST, FROST, FROST }
		for i = 0, 5 do
			local j = (i + 1) % 6
			local q = { P[i][1], P[j][1], P[j][2], P[i][2] }
			quad(out.Body, q, fr, C0 - n * 0.01)
			quad(out.Body, q, fr, C0 + n * 0.01)
		end
		y0 = 2 * ro - (ro - ri) * 0.5
	end
	local Lb = L * o.Blade
	local tw = (o.Tang or 0) / 2
	if tw > 0 then
		local y1 = L - Lb + 0.02
		local function sec(y)
			local c = O + u * y
			return { c + s * tw, c + n * tw, c - s * tw, c - n * tw }
		end
		local A, B = sec(y0), sec(y1)
		local mid = O + u * ((y0 + y1) / 2)
		local fr = { FROST, FROST, FROST, FROST }
		for j = 1, 4 do
			local k = j % 4 + 1
			quad(out.Body, { A[j], A[k], B[k], B[j] }, fr, mid)
		end
	end
	local yb = L - Lb
	local b0 = O + u * yb
	local cm = O + u * (yb + 0.4 * Lb)
	local M = { cm + s * R, cm + n * (T / 2), cm - s * R, cm - n * (T / 2) }
	local tip = O + u * L
	local MC = { EDGE, RIDGE, EDGE, RIDGE }
	for j = 1, 4 do
		local k = j % 4 + 1
		tri(out.Body, b0, M[k], M[j], ROOT, MC[k], MC[j], cm)
		tri(out.Body, M[j], M[k], tip, MC[j], MC[k], TIP, cm)
	end
	if o.Core then
		local cr = T * 0.22
		local c0, c1 = b0 + u * (Lb * 0.06), b0 + u * (Lb * 0.86)
		local q0 = { c0 + s * cr, c0 + n * cr, c0 - s * cr, c0 - n * cr }
		local q1 = { c1 + s * cr * 0.5, c1 + n * cr * 0.5, c1 - s * cr * 0.5, c1 - n * cr * 0.5 }
		local wc = { WHITE, WHITE, WHITE, WHITE }
		for j = 1, 4 do
			local k = j % 4 + 1
			quad(out.Core, { q0[j], q0[k], q1[k], q1[j] }, wc, (c0 + c1) / 2)
		end
	end
	if (o.Bevel or 0) > 0 then
		local list = o.EdgeLine and out.Line or out.Body
		local col = o.EdgeLine and WHITE or SILVER
		local cs = { col, col, col, col }
		for _, e in ipairs({ 1, 3 }) do
			for _, r in ipairs({ 2, 4 }) do
				local segs = o.EdgeFront and { { M[e], tip } } or { { b0, M[e] }, { M[e], tip } }
				local nn = ((M[e] - cm).Unit + (M[r] - cm).Unit).Unit * 0.004
				for _, sg in ipairs(segs) do
					local a, b = sg[1], sg[2]
					local inA = a + (M[r] - M[e]) * o.Bevel * ((a == b0 or a == tip) and 0 or 1)
					local inB = b + (M[r] - M[e]) * o.Bevel * ((b == b0 or b == tip) and 0 or 1)
					quad(list, { a + nn, b + nn, inB + nn, inA + nn }, cs, cm)
				end
			end
		end
	end
end

-- the kinds (sizes from the kit: fb_final / fb_ff / fb_mc / fb_df / fb_bz / fb_cm)
local KINDS = {
	Shard = { L = 3.6, W = 0.34, T = 0.11, Blade = 0.5, Tang = 0.08, RingRo = 0.17, Bevel = 0.07 },             -- 44 tris
	Big = { L = 3.4, W = 0.9, T = 0.28, Blade = 0.5, Tang = 0.22, RingRo = 0.36, Bevel = 0.1, Core = true },    -- the pierce
	Small = { L = 1.0, W = 0.24, T = 0.07, Blade = 0.5, Tang = 0.05, RingRo = 0.1, Bevel = 0 },                 -- lodged
	Edge = { L = 2.4, W = 0.34, T = 0.11, Blade = 0.5, Tang = 0.08, RingRo = 0.17, Bevel = 0.07 },              -- the zone edge
	Bolt = { L = 1.8, W = 0.24, T = 0.07, Blade = 0.5, Tang = 0.05, RingRo = 0.11, Bevel = 0.1,
		EdgeFront = true, EdgeLine = true },                                                                    -- Mirror Cage
	Hand = { L = 0.85, W = 0.13, T = 0.045, Blade = 0.5, Tang = 0.035, RingRo = 0.075, Bevel = 0 },             -- the run's props
	Frag = { L = 1.0, W = 0.3, T = 0.1, Blade = 0.55, Tang = 0.07, RingRo = 0.12, Bevel = 0 },                  -- shatter pieces
	Trap = { L = 3.0, W = 0.62, T = 0.18, Blade = 0.55, Tang = 0.13, RingRo = 0.27, Bevel = 0.08 },             -- Deep Freeze
	Tiny = { L = 0.95, W = 0.2, T = 0.07, Blade = 0.5, Tang = 0.05, RingRo = 0.1, Bevel = 0 },                  -- its bloom
	Ring = { L = 9.0, W = 2.0, T = 0.6, Blade = 0.52, Tang = 0.48, RingRo = 0.85, Bevel = 0.07, Core = true },  -- Blizzard
	Nick = { Nick = true },                                                                                     -- Cold Momentum
}
FB.Kinds = KINDS

local function nickTris(out)
	-- two crossed blade nicks (0.72 long), lying flat in the print (Y = its normal, X its long axis), 32 degrees off it
	for _, sg in ipairs({ 1, -1 }) do
		local a = math.rad(32) * sg
		local dv = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-math.sin(a), 0, math.cos(a))
		local tail = -dv * 0.36 + Vector3.new(0, 0.015, 0)
		kunai(out, CFrame.fromMatrix(tail, side, dv), { L = 0.72, W = 0.13, T = 0.03, Blade = 1.0, Tang = 0, Ring = false, Bevel = 0 })
	end
end

----------------------------------------------------------------------------------------------------
-- building (the TerraWrap pattern)
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
--- A MeshPart of `tris`, centred on its box; and the box's centre in the frame the tris were given in.
local function meshPart(tris)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, t in ipairs(tris) do
		for k = 1, 3 do lo, hi = lo:Min(t[k]), hi:Max(t[k]) end
	end
	local c = (lo + hi) / 2
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
		local a, b, cc = t[1] - c, t[2] - c, t[3] - c
		local ca, cb, ccl, n = t[4], t[5], t[6], t[7]
		-- a front face's corners run counter-clockwise seen from outside (its edges' cross product points out)
		if (b - a):Cross(cc - a):Dot(n) < 0 then b, cc, cb, ccl = cc, b, ccl, cb end
		local f = em:AddTriangle(vtx(a), vtx(b), vtx(cc))
		em:SetFaceColors(f, { col(ca), col(cb), col(ccl) })
		local ni = nrm(n)
		em:SetFaceNormals(f, { ni, ni, ni })
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
	return mp, c, #tris
end

local kinds = {}            -- [name] = { Body, BodyOff, Core?, CoreOff, Line?, LineOff, L, Size, Tris }
local building = false
FB.Tris = {}

local function buildKind(name)
	local o = KINDS[name]
	local out = { Body = {}, Core = {}, Line = {} }
	if o.Nick then nickTris(out) else kunai(out, CFrame.identity, o) end
	local k = { L = o.L or 1 }
	local body, off, nt = meshPart(out.Body)
	body.Name = "Frostblade" .. name
	body.Material = Enum.Material.Ice
	body.Transparency = FB.Look.IceT
	body.Reflectance = FB.Look.Reflect
	if o.Nick then
		body.Color = FB.Look.Nick
		body.Transparency = FB.Look.NickT
	end
	k.Body, k.BodyOff, k.Size = body, off, body.Size
	local total = nt
	if #out.Core > 0 then
		local p, c, t = meshPart(out.Core)
		p.Name = "FrostbladeCore"
		p.Material, p.Color, p.Transparency = Enum.Material.Neon, FB.Look.Core, FB.Look.CoreT
		k.Core, k.CoreOff, total = p, c, total + t
	end
	if #out.Line > 0 then
		local p, c, t = meshPart(out.Line)
		p.Name = "FrostbladeLine"
		p.Material, p.Color, p.Transparency = Enum.Material.Neon, FB.Look.Line, 0
		k.Line, k.LineOff, total = p, c, total + t
	end
	k.Tris = total
	FB.Tris[name] = total
	kinds[name] = k
end

local ORDER = { "Shard", "Bolt", "Big", "Small", "Edge", "Frag", "Nick", "Hand", "Trap", "Tiny", "Ring" }
function FB.Build()
	if building then return end
	building = true
	task.spawn(function()
		for _, name in ipairs(ORDER) do
			local ok, err = pcall(buildKind, name)
			if not ok then warn("[FrostbladeKit] " .. name .. ": " .. tostring(err)) end
			task.wait()
		end
		FB.Built = true
	end)
end

--- The template of `name` (nil until it is built): { Body, BodyOff, Core, CoreOff, Line, LineOff, L, Size, Tris }.
function FB.Kind(name)
	return kinds[name]
end

----------------------------------------------------------------------------------------------------
-- a kunai in the world: New(kind) -> { Body, Core?, Line? }; Place it at its frame K (scale `s`, `sy` along its length)
----------------------------------------------------------------------------------------------------
function FB.New(name, parent)
	local k = kinds[name]
	if not k then return nil end
	local o = { Kind = k, Body = k.Body:Clone(), S = 1, SY = 1, F = -1 }
	if k.Core then o.Core = k.Core:Clone() end
	if k.Line then o.Line = k.Line:Clone() end
	if parent then FB.Parent(o, parent) end
	return o
end

function FB.Parent(o, parent)
	o.Body.Parent = parent
	if o.Core then o.Core.Parent = parent end
	if o.Line then o.Line.Parent = parent end
end

function FB.Drop(o)
	if not o then return end
	for _, key in ipairs({ "Body", "Core", "Line" }) do
		local p = o[key]
		if p then pcall(function() p:Destroy() end) end
	end
end

--- 0 = as built, 1 = gone (the ice clears, the glow and the line with it)
function FB.Fade(o, f)
	if f == o.F then return end
	o.F = f
	local L = FB.Look
	local base = (o.Kind == kinds.Nick) and L.NickT or L.IceT
	o.Body.Transparency = (f >= 1) and 1 or (base + (1 - base) * f)
	if o.Core then o.Core.Transparency = (f >= 1) and 1 or (L.CoreT + (1 - L.CoreT) * f) end
	if o.Line then o.Line.Transparency = f end
end

function FB.Place(o, K, parts, cframes, s, sy)
	s, sy = s or 1, sy or 1
	local k = o.Kind
	local sv = Vector3.new(s, s * sy, s)
	if s ~= o.S or sy ~= o.SY then
		o.S, o.SY = s, sy
		o.Body.Size = k.Size * sv
		if o.Core then o.Core.Size = k.Core.Size * sv end
		if o.Line then o.Line.Size = k.Line.Size * sv end
	end
	parts[#parts + 1] = o.Body
	cframes[#cframes + 1] = K * CFrame.new(k.BodyOff * sv)
	if o.Core then
		parts[#parts + 1] = o.Core
		cframes[#cframes + 1] = K * CFrame.new(k.CoreOff * sv)
	end
	if o.Line then
		parts[#parts + 1] = o.Line
		cframes[#cframes + 1] = K * CFrame.new(k.LineOff * sv)
	end
end

--- A kunai frame: tail at `tail`, pointing along `dir`, the blade's width along `side` (made square to `dir`).
function FB.Frame(tail, dir, side)
	dir = dir.Unit
	local sd = side - dir * side:Dot(dir)
	if sd.Magnitude < 1e-3 then
		sd = Vector3.yAxis - dir * dir.Y
		if sd.Magnitude < 1e-3 then sd = Vector3.xAxis - dir * dir.X end
	end
	return CFrame.fromMatrix(tail, sd.Unit, dir)
end

----------------------------------------------------------------------------------------------------
-- where the kunai go on a frozen body (kit/fb_ff.py big_kunai / stuck_kunai, kit/fb_df.py trap_kunai). Every spot is a
-- body part and the kunai's frame relative to it, so they ride the body; none comes within 0.95 studs of the head.
----------------------------------------------------------------------------------------------------
local R6 = { UpperTorso = "Torso", LowerTorso = "Torso", RightUpperArm = "Right Arm", LeftUpperArm = "Left Arm",
	LeftLowerArm = "Left Arm", RightUpperLeg = "Right Leg", LeftUpperLeg = "Left Leg" }
local function part(model, name)
	local p = model:FindFirstChild(name) or (R6[name] and model:FindFirstChild(R6[name]))
	return (p and p:IsA("BasePart")) and p or nil
end

local function segDist(a, b, p)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-9), 0, 1)
	return (a + ab * t - p).Magnitude
end

--- `n` big kunai diagonally through the torso (half sideways, half front-to-back), tip and ring both outside.
function FB.Pierce(model, n)
	local torso = part(model, "UpperTorso")
	if not torso then return {} end
	local lower = part(model, "LowerTorso") or torso
	local head = model:FindFirstChild("Head")
	local R = torso.CFrame
	local rt, fw, up = R.RightVector, R.LookVector, R.UpVector
	local ch = torso.Position
	local pv = (lower ~= torso) and lower.Position or (ch - up * 0.8)
	local H = head and head.Position or (ch + up * 1.5)
	local paths = {
		{ ch - up * 0.45, rt * 0.75 + fw * 0.45 + up * 0.35 },     -- in at the back left low, out the right front
		{ pv + up * 0.7, -rt * 0.8 + fw * 0.4 + up * 0.3 },        -- in at the back right, out the left front
		{ ch - up * 0.75, -rt * 0.65 - fw * 0.5 + up * 0.5 },      -- in at the right thigh front, out the left back
		{ pv + up * 0.5, rt * 0.6 - fw * 0.65 + up * 0.15 },       -- in at the left hip front, out the right back
	}
	local L = KINDS.Big.L * FB.PierceScale
	local out = {}
	for i = 1, math.min(n, #paths) do
		local P, d = paths[i][1], paths[i][2].Unit
		for _ = 1, 8 do
			if segDist(P - d * L * 0.5, P + d * L * 0.5, H) >= 0.95 then break end
			d = (d - up * 0.12).Unit
		end
		local K = FB.Frame(P - d * (L * 0.5), d, up)
		out[#out + 1] = { Kind = "Big", Part = torso, Rel = torso.CFrame:ToObjectSpace(K), Delay = 0.07 * (i - 1), Dur = 0.12, L = L,
			S = FB.PierceScale }
	end
	return out
end

local SPOTS = {
	{ "RightUpperArm", "rt", 0.2, 0.3 }, { "LeftUpperArm", "-rt", -0.2, 0.2 }, { "UpperTorso", "-fw", 0.45, 0.35 },
	{ "RightUpperLeg", "rt", 0.1, -0.2 }, { "UpperTorso", "up", 0.6, 0.1 }, { "LeftUpperLeg", "-rt", -0.1, 0.2 },
	{ "LowerTorso", "-fw", -0.35, 0 }, { "LeftLowerArm", "-rt", 0, 0.3 },
}
--- `n` small kunai lodged in the body's surface: a third of each blade buried, tang and ring out, tilted off the surface.
function FB.Stuck(model, n, t0, seed)
	local torso = part(model, "UpperTorso")
	if not torso or n <= 0 then return {} end
	local R = torso.CFrame
	local W = { rt = R.RightVector, ["-rt"] = -R.RightVector, fw = R.LookVector, ["-fw"] = -R.LookVector, up = R.UpVector }
	local rng = Random.new(seed or 5)
	local L, embed = KINDS.Small.L, 0.32
	local out = {}
	for i = 1, n do
		local spot = SPOTS[(i - 1) % #SPOTS + 1]
		local p = part(model, spot[1])
		if p then
			local cf, hs = p.CFrame, p.Size / 2
			local ax = { cf.RightVector * hs.X, cf.UpVector * hs.Y, cf.LookVector * -hs.Z }
			local want = W[spot[2]]
			local k, best = 1, -1
			for j = 1, 3 do
				local dd = math.abs(ax[j].Unit:Dot(want))
				if dd > best then k, best = j, dd end
			end
			local sg = (ax[k]:Dot(want) > 0) and 1 or -1
			local nrm = ax[k].Unit * sg
			local o1, o2 = ax[(k % 3) + 1], ax[((k + 1) % 3) + 1]
			local pt = cf.Position + ax[k] * sg + o1 * (spot[3] * 0.6) + o2 * (spot[4] * 0.6)
			local tilt = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			local tp = tilt - nrm * tilt:Dot(nrm)
			local nn = (tp.Magnitude > 1e-3) and (nrm + tp.Unit * 0.35).Unit or nrm
			local tip = pt - nn * embed
			local K = FB.Frame(tip + nn * L, -nn, W.up)
			out[#out + 1] = { Kind = "Small", Part = p, Rel = p.CFrame:ToObjectSpace(K), Delay = (t0 or 0.2) + 0.04 * (i - 1),
				Dur = 0.08, L = L }
		end
	end
	return out
end

--- Deep Freeze's trap: `n` kunai springing up from a ring round the feet (`at`, the floor under them), ring pommels by
--- the floor, leaning in so their blades cross round the legs and the waist like jaws. World frames (the floor's), built
--- round the body where THIS client draws it and marked Slide: a moving victim is drawn a replication delay behind the
--- server's stop point (the walking dummy ~2 studs at 16 studs/s), so CryoFX slides them across the floor with the body
--- (its flat position only, never its turn) and they stay round the legs instead of being left behind (2026-10-15).
function FB.Trap(model, at, n)
	local head = model:FindFirstChild("Head")
	local lower = part(model, "LowerTorso")
	local base = lower and Vector3.new(lower.Position.X, at.Y, lower.Position.Z) or at
	local H = head and head.Position or (base + Vector3.new(0, 4.6, 0))
	local out = {}
	local HS = { 1.3, 2.3, 1.7, 2.7 }
	for i = 0, n - 1 do
		local a = 2 * math.pi * i / n + 0.2
		local rad = Vector3.new(math.cos(a), 0, math.sin(a))
		local perp = Vector3.new(-math.sin(a), 0, math.cos(a))
		local S = base + rad * (1.7 + 0.15 * (FB.TrapScale - 1)) + Vector3.new(0, 0.12, 0)
		local T = base - rad * 0.3 + perp * ((i % 2 == 1) and 0.35 or -0.35) + Vector3.new(0, HS[i % 4 + 1], 0)
		local d = (T - S).Unit
		local L = (T - S).Magnitude + 0.8
		for _ = 1, 6 do
			if segDist(S, S + d * L, H) >= 0.95 then break end
			L -= 0.25
		end
		out[#out + 1] = { Kind = "Trap", K = FB.Frame(S, d, Vector3.yAxis), Slide = true, Delay = 0.025 * i, Dur = 0.1,
			L = L, S = FB.TrapScale, SY = L / (KINDS.Trap.L * FB.TrapScale) }
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- COLD MOMENTUM: THE NARUTO RUN (the developer's change, kit/fb_cm.py). While the +10 % window is on (PassiveActive),
-- a Frostblade runner leans into the run with both arms swept straight back, a small kunai in each hand. Only when
-- moving within ~45 degrees of facing; in and out over 0.15 s; legs, stride and footfalls are the stance's own.
-- Casting wins: a two-arm cast takes the body; a one-arm M1 throw takes only the throwing arm (its kunai hides) and the
-- other stays swept back -- the window opens on a landed hit, so a runner is usually still firing (2026-10-15). A clip
-- that is RELEASING is no longer a cast (CastPose.IsPlaying's own test): CastPose clears it only once the arms settle
-- within 0.25 degrees of a stance that never stops cycling while you run, so gating on it hid the run as long as you
-- kept moving after any cast.
-- FIRST PERSON (2026-10-15, the developer: "make the naruto run show in first person too"): on your own body in first
-- person the view-model shows it instead -- Viewmodel.SetNaruto drops the fists back to the bottom corners, stops the
-- stride's pump and leans the view in as the head leans -- with a hand kunai on each fist that is not throwing.
-- CastPose calls this every frame with the stance it is about to blend to.
----------------------------------------------------------------------------------------------------
FB.NarutoBlend = 0.15
local NARUTO_ARM = { Arm = -72, Elbow = 6, In = -10, Wrist = -12 }
local NARUTO_WAIST = -17                    -- the spine's 17 degrees (+5 over the sprint's own pitch)
local ONE_ARM = { IcicleShardR = "R", IcicleShardL = "L" }    -- the M1's one-arm throws: [clip] = the throwing arm
local runs = setmetatable({}, { __mode = "k" })     -- [character] = { W, FW, Props }
local view = { W = 0, Props = nil, Bound = false }  -- the first-person run: its weight, and the kunai on the fists
local vmodel = nil

--- The view-model module (client only; nil anywhere it cannot load).
local function viewmodel()
	if vmodel == nil then
		local m = script.Parent:FindFirstChild("Viewmodel")
		local ok, mod = pcall(function()
			return m and require(m)
		end)
		vmodel = (ok and type(mod) == "table" and mod.SetNaruto) and mod or false
	end
	return vmodel or nil
end

local function firstPerson(character)
	if character ~= Players.LocalPlayer.Character then return false end
	local cam, head = workspace.CurrentCamera, character:FindFirstChild("Head")
	return cam ~= nil and head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.5
end

local function dropProps(r)
	for _, o in ipairs(r.Props or {}) do FB.Drop(o) end
	r.Props = nil
end

local function addProps(r, character)
	if r.Props or not kinds.Hand then return end
	r.Props = {}
	for _, name in ipairs({ "RightHand", "LeftHand" }) do
		local hand = character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			local o = FB.New("Hand")
			o.Side = (name == "RightHand") and "R" or "L"
			local b = o.Body
			b.Anchored, b.Massless = false, true
			b.Transparency = 1
			-- the ring over the finger, the blade trailing on along the forearm (the hand's -Y)
			local w = Instance.new("Weld")
			w.Part0, w.Part1 = hand, b
			w.C0 = CFrame.Angles(math.pi, 0, 0) * CFrame.new(0, -0.075, 0) * CFrame.new(o.Kind.BodyOff)
			w.Parent = b
			b.Parent = hand
			r.Props[#r.Props + 1] = o
		end
	end
end

local function viewDrop()
	for _, o in pairs(view.Props or {}) do FB.Drop(o) end
	view.Props = nil
end

-- the first-person kunai's blade direction off the fist (out to the side, back along the forearm, down) and its scale
FB.ViewKunai = { Out = 0.85, Back = 0.5, Down = 0.15, Scale = 0.85 }

--- The first-person run's kunai: one on each fist that is not throwing, the ring over the fist and the blade trailing
--- back and out past the frame's corner. Placed after the view-model's own step, so they ride the arm on screen.
local function viewBind()
	if view.Bound then return end
	view.Bound = true
	RunService:BindToRenderStep("FrostbladeNarutoView", Enum.RenderPriority.Camera.Value + 4, function()
		local vm = viewmodel()
		if view.W <= 0 or not vm or not kinds.Hand then
			viewDrop()
			view.Bound = false
			RunService:UnbindFromRenderStep("FrostbladeNarutoView")
			return
		end
		view.Props = view.Props or { R = FB.New("Hand", workspace), L = FB.New("Hand", workspace) }
		local parts, cframes = {}, {}
		local K = FB.ViewKunai
		for side, o in pairs(view.Props) do
			local fist = vm.GetFistCFrame(side)
			if fist and view.W > 0.5 and not vm.ArmBusy(side) then
				FB.Fade(o, 0)
				local out = (side == "R") and fist.RightVector or -fist.RightVector
				local dir = out * K.Out - fist.LookVector * K.Back - fist.UpVector * K.Down
				FB.Place(o, FB.Frame(fist.Position + out * 0.12, dir, fist.UpVector), parts, cframes, K.Scale)
			else
				FB.Fade(o, 1)
			end
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged) end
	end)
end

function FB.Naruto(state, pose, dt)
	local character = state.Character
	local r = runs[character]
	local window = character:GetAttribute("PassiveActive") == true and FB.On(character)
	if not window and not r then
		-- a fresh body (a respawn) with no window: make sure the view-model was handed back
		if view.W > 0 and character == Players.LocalPlayer.Character then
			view.W = 0
			local vm = viewmodel()
			if vm then vm.SetNaruto(0) end
		end
		return
	end
	if not r then
		r = { W = 0, FW = 0 }
		runs[character] = r
	end
	local fp = firstPerson(character)
	local casting = state.Clip ~= nil and not state.Releasing
	local throwing = casting and ONE_ARM[state.ClipName] or nil
	local forward = false
	local ms = character:GetAttribute("MoveState")
	if window and state.Moving and ms ~= "Slide" and ms ~= "Crouch" then
		local root = state.Humanoid and state.Humanoid.RootPart
		if root then
			local v = root.AssemblyLinearVelocity
			local f = root.CFrame.LookVector
			local vf, ff = Vector3.new(v.X, 0, v.Z), Vector3.new(f.X, 0, f.Z)
			forward = vf.Magnitude > 2 and ff.Magnitude > 1e-3 and vf.Unit:Dot(ff.Unit) > 0.707
		end
	end
	local step = dt / FB.NarutoBlend
	local want = (forward and not fp and (throwing ~= nil or not casting)) and 1 or 0
	r.W = (want > r.W) and math.min(want, r.W + step) or math.max(want, r.W - step)
	-- first person: the view-model's run (a two-arm view-model clip takes the arms, as any cast does)
	if character == Players.LocalPlayer.Character then
		local vm = viewmodel()
		local fwant = (forward and fp and not (vm and vm.IsPlaying())) and 1 or 0
		r.FW = (fwant > r.FW) and math.min(fwant, r.FW + step) or math.max(fwant, r.FW - step)
		view.W = r.FW
		if vm then vm.SetNaruto(r.FW) end
		if r.FW > 0 then viewBind() end
	end
	-- the props come with the window (third person) and go with it; a throwing hand's hides, as do both under a cast
	if window and not fp then addProps(r, character) else dropProps(r) end
	if r.Props then
		for _, o in ipairs(r.Props) do
			local t = (r.W > 0.5 and not (casting and (throwing == nil or throwing == o.Side))) and FB.Look.IceT or 1
			if o.Body.Transparency ~= t then o.Body.Transparency = t end
		end
	end
	local w = r.W
	if w > 0 then
		for _, side in ipairs({ "R", "L" }) do
			if side ~= throwing then
				local limb = pose[side]
				for ch, v in pairs(NARUTO_ARM) do limb[ch] = limb[ch] + (v - limb[ch]) * w end
			end
		end
		if not casting then pose.Waist = pose.Waist + (NARUTO_WAIST - pose.Waist) * w end
	end
	if not window and w <= 0 and r.FW <= 0 then
		dropProps(r)
		runs[character] = nil
	end
end

-- LAZY build (2026-10-17, as FrostDragonKit): only once a player in the server wears this skin, or -- in Studio -- a test
-- dummy stands in for it (StudioSkin). Every Cryo skin and wrap shares one EditableMesh budget per client; a kit nobody
-- in the server wears takes none of it (eager builds of all four overran it, and the worn skin fell back to the Default).
do
	local lazyStarted = false
	local function go()
		if lazyStarted then return end
		lazyStarted = true
		FB.Build()
	end
	local attr = SkinCatalog.ElementSkinAttr("Cryo")
	local function check(plr)
		if lazyStarted then return end
		local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Cryo")
		if ok and id == FB.Id then go() end
	end
	local function watch(plr)
		check(plr)
		plr:GetAttributeChangedSignal(attr):Connect(function() check(plr) end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
	Players.PlayerAdded:Connect(watch)
	if RunService:IsStudio() then
		local function dummy(m) if m:IsA("Model") and m:GetAttribute("StudioSkin") == FB.Id then go() end end
		for _, m in ipairs(workspace:GetChildren()) do dummy(m) end
		workspace.ChildAdded:Connect(function(m) task.defer(dummy, m) end)
	end
end
return FB
