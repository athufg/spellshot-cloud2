--[[
	RadiantDevilForge  (ReplicatedStorage.IceMagic.RadiantDevilForge, ModuleScript, CLIENT ONLY)   Devil skin, 2026-10-13

	The DEVIL SKIN's forged forms -- the solid black-iron and stone shapes of the approved Blender look
	(radiant_devil_skin_2026_10_12/kit/devil_look.py: horns, bat wings, the horn dome, carved plates, chains, the maw,
	Benediction's torn pit and the column from hell), built as MeshParts on EditableMeshes, plus the devil glyphs the
	same file draws as strokes (pentagram, thorn star, the devil bond / heal), which go through RadiantDraw. Drawn ONLY
	for a caster whose Radiant palette is the Devil skin (Forge.IsDevil(pal)); Default and Rainbow never come here.
	A WRAP worn OVER the skin (SkinCatalog "Devil+Rainbow": pal.Wrap) recolours every form exactly as normal Radiant
	wears that wrap (owner, 2026-10-14: the bare model, then the wrap, one to one): the wrap's bands run ALONG each form the
	way RadiantDraw runs them along a stroke -- SkinSpan studs end to end and back, each form from its own point of the
	cycle -- over the plain base (none of the iron / stone / membrane darkness) and over its glow (THE WRAP BANDS).
	Each form follows its Python call for call (the active definition: the LAST def of a name, the pass-1 devil_heaven
	tell with the pass-4 ground), in Roblox world space: Blender (x, y, z) -> Roblox (-x, z, y) (RadiantDraw.B), the
	kit's horizontal angle a -> RD.B(1,0,0) cos a + RD.B(0,1,0) sin a, ZUP -> UP. Callers pass Roblox points.

	THE MESH SYSTEM (the kit's _PB + part_mesh, immediate mode, pooled)
	  A FORM = one handle owning two MeshParts: the SOLID part (SmoothPlastic, vertex colours: iron, stone, membrane)
	  and the GLOW part (Neon, vertex colours: the ember seams and inlays -- Neon shows vertex colour, ignores alpha).
	  Each sits on a FIXED-size EditableMesh of `cap` separate triangles (a triangle soup: every face owns its three
	  vertices, so its automatic normal is the flat face normal, like the kit's use_smooth False). A frame moves the
	  vertices (SetPosition / SetColor, written only where they changed) and collapses the unused triangles to a point;
	  the topology never changes, so nothing is rebuilt per frame. A degenerate bounds-anchor triangle at
	  (-B,-B,-B),(B,B,B),(B,B,B) pins the mesh bounds, so the part's Size is 2B and its CFrame is the frame's origin:
	  vertices are part-local studs, and Size can stretch a form (a scale) without touching a vertex.
	  A layer is (re)built only when a frame needs more triangles (or a bigger box) than it has: off the render loop,
	  RESIZABLE mesh -> fixed copy (CreateEditableMeshAsync FixedSize) -> the resizable one destroyed at once, at most
	  Config.MaxBuilds at a time (the engine allows 8 resizable meshes per experience), retrying while memory is tight.
	  Until a build lands the old mesh shows what fits (a brand-new form shows a frame or two late: Prewarm).
	  The slots of a soup triangle are found again in the fixed copy by position (each is built at a distinct x), so
	  no assumption is made about the copy's face order.
	  Parts live in workspace.<FX folder>.RadiantDevil (the folder RadiantDraw uses; the Staff's raycasts exclude it),
	  anchored, no collision / query / touch / shadow.

	API  (Forge = require(IceMagic.RadiantDevilForge); every vector Roblox world unless it says local)
	  scopes (the kit's fx_clear: a form not drawn in a frame is hidden at End)
	    sc = Forge.Scope(name)              one per effect instance
	    sc:Begin(cv?, tag?)                 each frame; cv = the effect's RadiantDraw canvas: pieces count into it
	                                        (cv:Count, one per MeshPart shown), and the forms' embers go on it
	    sc:End() -> pieces                  hides this scope's forms not drawn since Begin
	    sc:Destroy()                        hides them and hands them to the pool (Config.PoolKeep per kind)
	  forms by key (the raw handle)
	    h = Forge.form(key, opts?)          the global handle `key` (pooled by key); opts.Bound = the box half-size
	    h:Begin(origin?, isLocal?)          a frame's geometry: origin = the part's CFrame (nil: the first vertex, no
	                                        rotation); isLocal = builder points are origin-local studs
	    ...builder calls...                 (below)
	    h:Finish(scale?) -> parts           writes what changed, places (Size = 2B x scale, number or Vector3), shows
	    h:Place(origin, scale?) -> parts    moves / stretches the last geometry, writes no vertex (rigid forms)
	    h:Edit(origin, isLocal?) / h:Seek(sTri, gTri) / h:Pad(sTo, gTo) / h:SetCount(nS, nG)   slot editing (chains)
	    h:Same(...) -> bool                 true when every argument equals the last call's (and geometry exists):
	                                        the caller may Place instead of re-emitting
	    h:GlowLevel(k)                      the Neon part's Color = grey k (a seam level without re-emitting)
	    h:Hide()  h:Destroy()
	  builders (the kit's _PB; colours: LINEAR Vector3 as the kit mixes them -- Forge.lin("#hex"); glow k: SEAM x k)
	    h:Tri(a, b, c, colA, colB?, colC?)                  solid
	    h:GTri(a, b, c, kA, kB?, kC?)                       Neon
	    h:Quad(a, b, c, d, colA..colD, kA..kD, orient?, route?)   the kit's pface for 4 corners: col false = NOGLOW;
	                                        route nil = a seam (all cols false) or glow >= Config.NeonFrom -> Neon,
	                                        else solid with the glow added as colour; "s" / "g" force it;
	                                        orient nil = as given (front = (b-a)x(c-a)), true = both sides,
	                                        Vector3 = turned to face it
	    h:Tube(pts, m, radii, ref, col, glow, n=6, tip?, caps=true)   the kit's _PB.tube: an n-sided tapered tube,
	                                        ring vertex 0 toward `ref`; col = a linear colour or {A, B, Pow, Band} or
	                                        {Fn = f(u, k) -> linear}; glow = nil or {Ridges = {0, ..}, Lo, Hi, K}:
	                                        an ember seam strip just proud of ridge i where Lo < u < Hi
	    h:Face3(a, b, c, colA..colC, kA..kC, orient?, route?)    the kit's pface for a triangle (as Quad)
	    h:Knob(c, r, col)  h:Ico(c, r, col, below?, k?)      an icosahedron (corners under -below x r glow k)
	    h:Xf(pivot, s)                      every following point scaled by s about pivot (the kit's vertex grow)
	    h:Stamp(tpl, off)                   copy a capture (one link, forged once) at off: chains stamp their links
	  the forms (every form function takes the scope first and returns the MeshParts it shows; ids separate copies)
	    Forge.Horns(sc, headCF, g)                          Halo: the two horns on the head (head-local, grown by g)
	    Forge.BatWing(sc, side, ws, ga, sp, grow, out?)     Halo: one bat wing on RadiantFX_Staff's wing frame ws
	                                        {A, o, U, n, fx, ca, sa}; ga = arm grow, sp = spread, grow[1..4] = the
	                                        fingers' feather_grow(t, 2k) (Staff's feather k = 2k+1); out[k] = {Q = 6
	                                        world points base -> tip, G = grow} for the finger glints
	    Forge.HornDome(sc, F, level, u, t, frag?)           Blessing / Overflow: 7 horns round the ally (F = the
	                                        Seal frame {x, z, fy, turn, s, pivot, top?}); frag < 1 crumbles them
	    Forge.CarvedPlate(sc, id, c, R, rot, glowK, th?, normal?)   a carved pentagram plate (floor, or any normal)
	    Forge.SealPlate(sc, F, s, level)                    Blessing's ground: the plate under the seal
	    Forge.ChestBrand(sc, p, normal, g, t, t0, R?)       Overflow: the plate on the ally's chest
	    Forge.PactSeal(sc, id, floorP, ls, k)               Benediction: the pact seal under a bonded ally
	    Forge.DevilChain(sc, tip, d, a, b, L, r, t)         Light Lance: the barbed chain gaining links + the hook
	    Forge.HitHorns(sc, hit, d, u, big)                  Light Lance: the horn spikes at the target
	    Forge.Maw(sc, id, c, t)                             Position Trade: the fanged maw (7 teeth) + 3 claws (clip t)
	    Forge.HellGround(sc, t, ctx)                        Benediction: the torn pit (pass 4) and everything round it
	    Forge.HellCracks(sc, t, uc, ctx)                    Benediction: the 7 jagged cracks (2 to the allies)
	    Forge.HellColumn(sc, base, top, t, surges, wfun?)   Benediction: the column from the pit to the gate
	    Forge.SpiralChains(sc, base, top, t)                Benediction: the two barbed chains wound up it (pass 1)
	    Forge.Gate(sc, skyC, R1, g, pe, t)                  Benediction: the carved gate facing down + two horns
	    Forge.ShaftSurge(sc, butt, tip, t, arr, travel?)    Benediction: a short chain racing up the staff per pulse
	    Forge.ChainBond(sc, id, src, dst, u, t)             Benediction: the ember chain sliding to an ally
	  the strokes (RadiantDraw, on the caller's canvas -- its palette makes them crimson)
	    Forge.Pentagram(cv, c, normal, R, level, o?)        o {rot, inverted=true, u=1, w, tag}       2 pieces
	    Forge.ThornStar(cv, c, normal, rOut, level, o?)     o {rot, n_pts=5, inner=0.42, w, tag}      1 piece
	    Forge.EmberBrand(cv, p, normal, t, t0, R?, tag?)    a pentagram flashing hot, cooling to an ember
	    Forge.DevilBond(cv, src, dst, u, level, o?)         THE DEVIL BOND (kit bond's place): iron thread, barbed
	                                        chevrons gliding to dst, embers, a pentagram at src / dst -> lead point
	    Forge.DevilHeal(cv, src, dst, u, t, th, o?)         a heal carried to an ally (devil_heal)
	    Forge.ClaspHorns(cv, c, axis, o?)                   the two horns the devil clasp grows (after cv:Clasp)
	  the rest
	    Forge.IsDevil(pal) -> bool         Forge.lin(hex) -> linear colour     Forge.Prewarm(kind, sTris, gTris, bound?)
	    Forge.PrewarmPiece(name)           "LightLance" | "Halo" | "Blessing" | "Overflow" | "Trade" | "Benediction"
	    Forge.Stats() -> {Forms, Building, Pooled}         Forge.DestroyAll()

	THE HEALS read by SHAPE and MOTION, never gold: Benediction's threads are forged (ChainBond: links sliding to the
	ally); Halo's heal and the Bond are RadiantDraw strokes (DevilHeal / DevilBond: a thread with barbed chevrons
	gliding to the ally, embers rising) -- cheap, camera-facing like the kit's, and crimson through the canvas palette.

	NOT LIKE BLENDER: the floor cannot be cut, so Benediction's pit is drawn ON the floor -- its sloped walls as
	concentric bands flattened just over it (stone at the rim to near-black at the throat, the glow growing inward,
	Neon from Config.NeonFrom), the throat a Neon disc, the torn lip, fangs, claws, slabs and rubble raised round it --
	and the rock spur is a stump the trident stands in (its butt 0.30 under the floor). The column's bright crimson
	EDGES (Blender's facing term) become three Neon seam strips on its vein crests, the veins themselves vertex colour.
	The veins turn with the PART (its CFrame spins -3 rad/s about the axis), the spiral chains with theirs (+0.6), so
	the meshes stay still. Light Lance's chain: links per Config.ChainMaxLinks (a beam longer than ~35 studs at full
	ramp gets longer links), re-forged when the pitch moves 12% (~6 ms for 30 studs of chain) and stretched by Size
	between. ChainBond's links keep their orientation as they slide (the Python flips every link at each wrap). The
	chain links are forged ONCE per shape and stamped (copied) into their slots. Randomness is RadiantDraw's hash
	(the same statistics, not the renders' exact rocks). Emission is colour: a solid face with glow below
	Config.NeonFrom is lit by colour + SEAM x glow x Config.EmitGain; above, it goes Neon. Seam strips keep the kit's
	widths (Config.SeamWidth). UNCALIBRATED in Play: SeamNeon (the Neon input for SEAM x 1; Neon roughly doubles and
	clips, this place's grade crushes the green), EmitGain, VeinGain -- measure on screen against the checkpoints.
]]

local AssetService = game:GetService("AssetService")

local RD = require(script.Parent:WaitForChild("RadiantDraw"))

local Forge = {}

----------------------------------------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------------------------------------
local Config = {
	FolderName = "RadiantDevil",          -- workspace.<FX folder>.RadiantDevil
	MaxBuilds = 2,                        -- meshes under construction at once (each holds a RESIZABLE mesh: cap 8)
	MaxTris = 19000,                      -- per layer (an EditableMesh holds 60,000 vertices; a soup triangle owns 3)
	CapStep = 64, CapGrow = 1.3,          -- a layer is built for ceil(need x CapGrow / CapStep) x CapStep triangles
	BuildChunk = 800,                     -- a build yields every this many triangles (~1-2 ms of mesh calls each)
	BoundPad = 1.25,                      -- a layer's box: the first frame's extent x this (+0.5), or the form's own
	PoolKeep = 2,                         -- released forms kept per kind (their meshes are the cost)
	IdleLife = 120,                       -- s: a hidden Forge.form handle unused this long is destroyed
	CastShadow = false,

	-- the look (the kit's paint inputs are below as hex; on-screen targets: iron #1A1416..#2E2326, seam ~#FF4A3A)
	SeamNeon = Color3.fromHex("#80251D"), -- Neon input for SEAM x 1 (UNCALIBRATED: Neon ~doubles and clips)
	NeonFrom = 0.5,                       -- a face with colour AND glow goes Neon from this glow (kit SEAM units)
	EmitGain = 0.5,                       -- below it: colour + SEAM x glow x this (linear)
	VeinGain = 0.8,                       -- the column's veins (vertex colour on the solid column)
	SeamWidth = 1.0,                      -- x the kit's seam strip half-width (0.006..0.016 studs)
	FloorLift = 0.03,                     -- flat floor forms sit this far over the floor (the kit's 0.006..0.018 z-fight)
	PitBands = { 0.012, 0.02, 0.028 },    -- the pit's flattened wall rings over FloorLift (rim -> throat); throat +0.036

	ChainMaxLinks = 96,                   -- Light Lance: pitch >= L / this (a long beam gets longer links, not more)
	ChainPitchStep = 1.12,                -- the chain is re-forged when its pitch moves 12% (Size stretches it between:
	                                      --   a link at most 6% long or short along the chain; ~6 ms per 30 studs)
	BondMaxLen = 30,                      -- ChainBond: the longest thread the slots cover (Benediction Radius 25)
	SpurTop = 0.25,                       -- Benediction: the rock stump's top over the floor
}
Forge.Config = Config

----------------------------------------------------------------------------------------------------
-- MATHS
----------------------------------------------------------------------------------------------------
local sin, cos, abs, max, min, floor, ceil, sqrt, pi, rad, atan2, exp, log = math.sin, math.cos, math.abs, math.max,
	math.min, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.atan2, math.exp, math.log
local TAU = 2 * pi
local HUGE = math.huge
local UP = RD.UP
local ZERO = Vector3.zero
local EX, EY = RD.B(1, 0, 0), RD.B(0, 1, 0)      -- the kit's horizontal basis: Vector((cos a, sin a, 0)) = hdir(a)
local clamp, smooth, ramp, ease = RD.clamp, RD.smooth, RD.ramp, RD.ease

local function up01(t, t0, t1)
	return clamp((t - t0) / max(t1 - t0, 1e-6), 0, 1)
end

local function hdir(a)
	return EX * cos(a) + EY * sin(a)
end

local function unit(v, fb)
	local m = v.Magnitude
	if m > 1e-9 then return v / m end
	return fb
end

--- a unit vector perpendicular to d (mathutils' orthogonal())
local function ortho(d)
	local a = (abs(d.X) < 0.6) and Vector3.xAxis or ((abs(d.Y) < 0.6) and UP or Vector3.zAxis)
	return d:Cross(a).Unit
end

local function bez3(p0, p1, p2, p3, u)
	local v = 1 - u
	return p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u) + p3 * (u * u * u)
end

--- the kit's random.uniform, as RadiantDraw's hash: identical on every client
local function uni(seed, i, k, lo, hi)
	return lo + (hi - lo) * RD.Rand(seed, i, k, 3)
end

--- a CFrame turning UP onto axis (the shortest way)
local function upTo(axis)
	local c = UP:Cross(axis)
	local s = c.Magnitude
	if s < 1e-6 then
		return (axis.Y >= 0) and CFrame.identity or CFrame.Angles(pi, 0, 0)
	end
	return CFrame.fromAxisAngle(c / s, math.acos(clamp(UP:Dot(axis), -1, 1)))
end

-- the camera (read once per scope frame / stroke call: the kit's _cam_dir)
local camP = Vector3.new(0, 0, 10)
local function camRefresh()
	local cam = workspace.CurrentCamera
	if cam then camP = cam.CFrame.Position end
end
local function camDir(p)
	local d = camP - p
	local m = d.Magnitude
	if m > 1e-6 then return d / m end
	return Vector3.new(0, 0, -1)
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[RadiantDevilForge] " .. msg)
end

----------------------------------------------------------------------------------------------------
-- COLOURS (devil_look.py mixes in linear light, _lin = sRGB ^ 2.2; a part shows display colour)
----------------------------------------------------------------------------------------------------
local G22 = 1 / 2.2
local function lin(h)
	local c = Color3.fromHex(h)
	return Vector3.new(c.R ^ 2.2, c.G ^ 2.2, c.B ^ 2.2)
end
Forge.lin = lin

local function disp(v)
	return Color3.new(clamp(v.X, 0, 1) ^ G22, clamp(v.Y, 0, 1) ^ G22, clamp(v.Z, 0, 1) ^ G22)
end

local IRON, IRON_HI, BLOOD, MEMB, MEMB_HI = lin("#1E1A1C"), lin("#262022"), lin("#8A1420"), lin("#24060A"),
	lin("#4A0A12")
local STONE, STONE_HI, ASH = lin("#24181A"), lin("#3A2A2A"), lin("#120508")
local SEAM = lin("#FF4A4C") * 0.95                 -- the kit's ember seam emission (every glow is SEAM x k)
local NOCOL = ZERO
Forge.Colors = { IRON = IRON, IRON_HI = IRON_HI, BLOOD = BLOOD, MEMB = MEMB, MEMB_HI = MEMB_HI, STONE = STONE,
	STONE_HI = STONE_HI, ASH = ASH, SEAM = SEAM }

local function mixl(a, b, u)
	return a + (b - a) * u
end

--- emission as colour on the solid part
local function emitCol(cl, k)
	if k <= 0 then return disp(cl) end
	return disp(cl + SEAM * (k * Config.EmitGain))
end

local GLOW_Q = 64
local glowCache = {}
-- THE GLOW HUE (2026-10-14, wraps over skins): the Neon layer's vertex colours are GREY levels and its part Color carries
-- the hue (the part colour multiplies the vertex colour, as GlowLevel already relies on). The default hue is
-- Config.SeamNeon scaled to its brightest channel (HUE_M), so vertex x part = SeamNeon x k exactly as before; a caster
-- wearing a wrap over the skin gives each form a hue from the wrap's palette (Scope:Get), with no vertex rewritten.
local DEF_HUE, HUE_M = nil, 1
local function seamHue()
	local b = Config.SeamNeon
	HUE_M = math.max(b.R, b.G, b.B, 1e-3)
	DEF_HUE = Color3.new(b.R / HUE_M, b.G / HUE_M, b.B / HUE_M)
end
seamHue()

--- the Neon vertex colour of SEAM x k: a grey level (quantized to 1/64: a smaller change writes nothing)
local function glowCol(k)
	local q = floor(clamp(k, 0, 2) * GLOW_Q + 0.5)
	local c = glowCache[q]
	if not c then
		local g = min(1, HUE_M * q / GLOW_Q)
		c = Color3.new(g, g, g)
		glowCache[q] = c
	end
	return c
end

--- a glow part's Color: its tint level x its hue (the handle's, or the default)
local function tintHue(t, hue)
	hue = hue or DEF_HUE
	return Color3.new(t.R * hue.R, t.G * hue.G, t.B * hue.B)
end

--- after changing Config.SeamNeon
function Forge.ClearCache()
	table.clear(glowCache)
	seamHue()
end

local WHITE = Color3.new(1, 1, 1)

----------------------------------------------------------------------------------------------------
-- THE MESH SYSTEM: building a layer
----------------------------------------------------------------------------------------------------
local folderRef = nil
local function folder()
	if folderRef and folderRef.Parent and folderRef.Parent.Parent then return folderRef end
	local name = RD.Config.FXFolderName
	local mod = script.Parent:FindFirstChild("VFXLibrary")
	if mod then
		local ok, lib = pcall(require, mod)
		if ok and type(lib) == "table" and type(lib.Config) == "table" and type(lib.Config.FXFolderName) == "string" then
			name = lib.Config.FXFolderName
		end
	end
	local fx = workspace:FindFirstChild(name)
	if not fx then
		fx = Instance.new("Folder")
		fx.Name = name
		fx.Parent = workspace
	end
	local f = fx:FindFirstChild(Config.FolderName)
	if not f then
		f = Instance.new("Folder")
		f.Name = Config.FolderName
		f.Parent = fx
	end
	folderRef = f
	return f
end

local building = 0
local function acquire()
	while building >= Config.MaxBuilds do task.wait() end
	building += 1
end

local free = {}               -- kind -> released handles (the pool; here so a build under memory pressure can thin it)

--- Memory pressure: the least recently used SPARE (a pooled form, built, not building) is destroyed and its meshes
--- freed. The EditableMesh budget (~200k vertices in Studio, 2026-10-13) does not hold every Devil piece's forms at
--- once, so spares give way to the forms a cast needs now. -> true when one went.
local function evictSpare()
	local pool, at, oldest = nil, nil, HUGE
	for _, p in pairs(free) do
		for i, h in ipairs(p) do
			if not (h.Dead or h.S.Building or h.G.Building) and h.UsedT < oldest then
				pool, at, oldest = p, i, h.UsedT
			end
		end
	end
	if not pool then return false end
	table.remove(pool, at):Destroy()
	return true
end

--- `make()` until it gives a mesh: under memory pressure the engine hands back nil (TerraWrap's retry, ~10 s), and
--- a spare is evicted before each wait
local function retry(make)
	for _ = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		if evictSpare() then task.wait() else task.wait(0.25) end
	end
	error("EditableMesh budget: gave up", 0)
end

--- A fixed soup of `cap` triangles in the box +-B, every vertex collapsed to the origin, and its MeshPart.
--- -> fixed mesh, part, V (vertex ids, 3 per triangle in slot order), C (their colour ids)
local function buildMesh(cap, B)
	acquire()
	local em, held, fxOut = nil, true, nil
	local ok, fixed, part, V, C = pcall(function()
		em = retry(function() return AssetService:CreateEditableMesh() end)
		em:AddTriangle(em:AddVertex(Vector3.new(-B, -B, -B)), em:AddVertex(Vector3.new(B, B, B)),
			em:AddVertex(Vector3.new(B, B, B)))                    -- the bounds anchor
		local step, hb = 2 * B / (cap + 1), B * 0.5
		for s = 1, cap do                                      -- slot s: a triangle at x = -B + s x step
			local x = -B + s * step
			em:AddTriangle(em:AddVertex(Vector3.new(x, -hb, 0)), em:AddVertex(Vector3.new(x, hb, 0)),
				em:AddVertex(Vector3.new(x, 0, hb)))
			if s % Config.BuildChunk == 0 then task.wait() end
		end
		local fx = retry(function()
			return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
		end)
		fxOut = fx
		em:Destroy()
		em = nil
		building -= 1
		held = false
		local Vv, Cc, got = table.create(cap * 3), table.create(cap * 3), 0
		for n, f in ipairs(fx:GetFaces()) do
			local vs = fx:GetFaceVertices(f)
			local p1 = fx:GetPosition(vs[1])
			if p1.X > -B + step * 0.5 then
				local s = floor((p1.X + B) / step + 0.5)
				local cs = fx:GetFaceColors(f)
				for k = 1, 3 do
					local p = fx:GetPosition(vs[k])
					local corner = (p.Z > hb * 0.5) and 3 or ((p.Y > 0) and 2 or 1)
					local i = 3 * s - 3 + corner
					Vv[i], Cc[i] = vs[k], cs[k]
					fx:SetPosition(vs[k], ZERO)
				end
				got += 1
			end
			if n % Config.BuildChunk == 0 then task.wait() end
		end
		if got ~= cap then error(string.format("fixed copy kept %d of %d triangles", got, cap), 0) end
		local mp = retry(function()
			local okp, p = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromObject(fx), { CollisionFidelity = Enum.CollisionFidelity.Box })
			end)
			if okp then return p end
			return AssetService:CreateMeshPartAsync(Content.fromObject(fx))
		end)
		return fx, mp, Vv, Cc
	end)
	if em then em:Destroy() end
	if held then building -= 1 end
	if not ok then
		if fxOut then fxOut:Destroy() end
		error(fixed, 0)
	end
	return fixed, part, V, C
end

----------------------------------------------------------------------------------------------------
-- THE HANDLE: two layers (S solid, G glow), frame buffers, write-if-changed
----------------------------------------------------------------------------------------------------
local Handle = {}
Handle.__index = Handle

local live = setmetatable({}, { __mode = "k" })       -- every handle alive (stats, DestroyAll)

local function newLayer(glow)
	return { Glow = glow, Cap = 0, B = 0, WantCap = 0, WantB = 0, Building = false, FailT = -1e9,
		Mesh = nil, Part = nil, V = nil, C = nil,
		FP = {}, FC = {}, PP = {}, PC = {},                -- frame / last-written positions and colours, per vertex
		N = 0, Cur = 0, Lo = HUGE, Hi = 0, NLast = 0, Flush = false, Shown = false, MaxAbs = 0,
		Tint = WHITE, PartCF = nil, PartSize = nil }
end

local function newHandle(kind, key)
	local h = setmetatable({ Kind = kind, Key = key, S = newLayer(false), G = newLayer(true),
		CF = CFrame.identity, Inv = CFrame.identity, Local = false, Auto = false, Scale = 1, XP = ZERO, XS = 1,
		Visible = false, Dead = false, Valid = false, Sig = { n = 0 }, SlotSig = {}, BoundHint = nil,
		UsedT = os.clock(), Frame = -1, Mode = "frame" }, Handle)
	live[h] = true
	return h
end

--- a layer's triangle capacity for `need`; `exact` (a slot form, its count fixed by SetCount) takes no CapGrow headroom
local function capFor(need, exact)
	return min(Config.MaxTris, ceil(need * (exact and 1 or Config.CapGrow) / Config.CapStep) * Config.CapStep)
end

local function sizeOf(L, scale)
	return Vector3.one * (2 * L.B) * scale
end

local function placeLayer(h, L)
	local p = L.Part
	if not p then return end
	local cf, size = h.CF, sizeOf(L, h.Scale)
	if L.PartCF ~= cf then
		p.CFrame = cf
		L.PartCF = cf
	end
	if L.PartSize ~= size then
		p.Size = size
		L.PartSize = size
	end
end

local function showLayer(h, L)
	local on = h.Visible and L.NLast > 0 and L.Part ~= nil
	if on ~= L.Shown then
		L.Shown = on
		if L.Part then L.Part.Transparency = on and 0 or 1 end
	end
end

--- THE WRAP BANDS: under a wrap worn over the skin, a vertex takes the wrap's colour by where it sits along its form --
--- RadiantDraw's rule for a stroke: the bands run SkinSpan studs end to end and back (pingPong: red .. violet .. red),
--- each form from its own point of the cycle (WrapD0). The solid layer takes the band colour itself on the plain base (the
--- forged colours are ignored: no black iron, no dark membrane); the glow layer the band colour at full strength x the
--- seam's grey level (its part Color is then the plain tint: Hue WHITE).
local SPAN = (RD.Config and RD.Config.SkinSpan) or 6
local function pingPong(x)
	x = x % 2
	return (x <= 1) and x or (2 - x)
end

local function wrapCol(h, glow, c, p)
	local d = (p and h.WrapAx) and (p:Dot(h.WrapAx) - h.WrapLo) or 0
	local pc = h.WrapPal.At(pingPong((h.WrapD0 + d) / SPAN))
	if not glow then return pc end
	local g = c.R / math.max(pc.R, pc.G, pc.B, 1e-3)
	return Color3.new(min(1, pc.R * g), min(1, pc.G * g), min(1, pc.B * g))
end

--- a wrapped form's axis: its longest extent (part-local, this frame's vertices) and where it starts along it
local function wrapAxis(h)
	local L = (h.S.N > 0) and h.S or h.G
	local FP, n = L.FP, min(L.N, L.Cap) * 3
	local lo, hi = Vector3.new(HUGE, HUGE, HUGE), Vector3.new(-HUGE, -HUGE, -HUGE)
	for i = 1, n do
		local p = FP[i]
		if p then lo, hi = lo:Min(p), hi:Max(p) end
	end
	if lo.X > hi.X then
		h.WrapAx, h.WrapLo = nil, 0
		return
	end
	local e = hi - lo
	local ax = (e.X >= e.Y and e.X >= e.Z) and Vector3.xAxis or ((e.Y >= e.Z) and Vector3.yAxis or Vector3.zAxis)
	h.WrapAx, h.WrapLo = ax, lo:Dot(ax)
end

--- write the frame buffers into the mesh (only the dirty range, only what changed)
local function writeLayer(h, L)
	local mesh = L.Mesh
	if not mesh then return end
	local n = min(L.N, L.Cap)
	local FP, FC, PP, PC, V, C = L.FP, L.FC, L.PP, L.PC, L.V, L.C
	local lo, hi
	if L.Flush then
		lo, hi = 1, n
		L.Flush = false
	else
		lo, hi = L.Lo, min(L.Hi, n)
	end
	local B = L.B * 0.999
	local over = L.MaxAbs > B
	local wrap, glow = h.WrapPal ~= nil, L.Glow                  -- a wrap over the skin: THE WRAP BANDS
	for tri = lo, hi do
		local i0 = 3 * tri - 2
		for i = i0, i0 + 2 do
			local p = FP[i]
			if p and p ~= PP[i] then
				if over then p = Vector3.new(clamp(p.X, -B, B), clamp(p.Y, -B, B), clamp(p.Z, -B, B)) end
				mesh:SetPosition(V[i], p)
				PP[i] = FP[i]
			end
			local c = FC[i]
			if c and wrap then c = wrapCol(h, glow, c, FP[i]) end
			if c and c ~= PC[i] then
				mesh:SetColor(C[i], c)
				PC[i] = c
			end
		end
	end
	for i = 3 * n + 1, 3 * L.NLast do                       -- collapse what was shown past the new count
		if PP[i] ~= ZERO then
			mesh:SetPosition(V[i], ZERO)
			PP[i] = ZERO
		end
	end
	L.NLast = n
	L.Lo, L.Hi = HUGE, 0
end

local requestBuild
--- capacity / box check: a build when the frame needs more than the layer has
local function ensure(h, L)
	if L.N <= 0 then return end
	local wantB = L.B
	if L.B == 0 or L.MaxAbs > L.B * 0.999 then
		wantB = ceil(L.MaxAbs * Config.BoundPad + 0.5)
		if h.BoundHint then wantB = max(wantB, h.BoundHint) end
	end
	if L.N > L.Cap or wantB > L.B then
		if L.N > Config.MaxTris then
			warnOnce("cap" .. h.Kind, string.format("%s needs %d triangles (cap %d): truncated", h.Kind, L.N, Config.MaxTris))
		end
		L.WantCap = max(L.WantCap, capFor(L.N, h.Exact), L.Cap)
		L.WantB = max(L.WantB, wantB, L.B)
		requestBuild(h, L)
	end
end

requestBuild = function(h, L)
	if L.Building or h.Dead or os.clock() - L.FailT < 5 then return end
	L.Building = true
	local cap, B = max(L.WantCap, Config.CapStep), max(L.WantB, 1)
	task.defer(function()                                      -- never inside the render step that asked
		local ok, fixed, part, V, C = pcall(buildMesh, cap, B)
		L.Building = false
		if not ok then
			L.FailT = os.clock()
			warnOnce("build" .. h.Kind, "build failed (" .. h.Kind .. "): " .. tostring(fixed))
			return
		end
		if h.Dead then
			part:Destroy()
			fixed:Destroy()
			return
		end
		local oldP, oldM = L.Part, L.Mesh
		part.Name = "RadDevil_" .. h.Kind .. (L.Glow and "_Glow" or "")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.CastShadow = Config.CastShadow
		part.Material = L.Glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.Color = L.Glow and tintHue(L.Tint, h.Hue) or L.Tint
		part.Transparency = 1
		L.Part, L.Mesh, L.V, L.C, L.Cap, L.B = part, fixed, V, C, cap, B
		table.clear(L.PP)
		table.clear(L.PC)
		L.Flush, L.NLast, L.Shown, L.PartCF, L.PartSize = true, 0, false, nil, nil
		placeLayer(h, L)
		writeLayer(h, L)                                       -- the buffers as they stand (a rigid form may only Place)
		part.Parent = folder()
		if oldP then oldP:Destroy() end
		if oldM then oldM:Destroy() end
		showLayer(h, L)
		if L.WantCap > L.Cap or L.WantB > L.B then requestBuild(h, L) end
	end)
end

--- One triangle into layer L (points as given to the builder; colours final Color3 per corner).
local function put(h, L, a, b, c, ca, cb, cc)
	local tri = L.Cur + 1
	L.Cur = tri
	if h.XS ~= 1 then
		local X, s = h.XP, h.XS
		a, b, c = X + (a - X) * s, X + (b - X) * s, X + (c - X) * s
	end
	if h.Auto == true then                                  -- no origin given: the first vertex, unrotated
		h.CF, h.Inv, h.Auto = CFrame.new(a), CFrame.new(-a), "set"
	end
	if not h.Local then
		local I = h.Inv
		a, b, c = I * a, I * b, I * c
	end
	local m = L.MaxAbs
	m = max(m, abs(a.X), abs(a.Y), abs(a.Z), abs(b.X), abs(b.Y), abs(b.Z), abs(c.X), abs(c.Y), abs(c.Z))
	L.MaxAbs = m
	local i = 3 * tri - 2
	local FP, FC = L.FP, L.FC
	FP[i], FP[i + 1], FP[i + 2] = a, b, c
	FC[i], FC[i + 1], FC[i + 2] = ca, cb, cc
	if tri < L.Lo then L.Lo = tri end
	if tri > L.Hi then L.Hi = tri end
end

--- collapse layer L's triangles Cur+1 .. upto (a slot's unused tail)
local function pad(L, upto)
	local FP = L.FP
	for tri = L.Cur + 1, upto do
		local i = 3 * tri - 2
		FP[i], FP[i + 1], FP[i + 2] = ZERO, ZERO, ZERO
		if tri < L.Lo then L.Lo = tri end
		if tri > L.Hi then L.Hi = tri end
	end
	if upto > L.Cur then L.Cur = upto end
end

function Handle:Begin(origin, isLocal)
	self.Mode = "frame"
	self.Local = isLocal == true
	if origin then
		self.CF, self.Inv, self.Auto = origin, origin:Inverse(), false
	else
		self.Auto = true
	end
	self.XS = 1
	local S, G = self.S, self.G
	S.Cur, G.Cur, S.MaxAbs, G.MaxAbs = 0, 0, 0, 0
	self.UsedT = os.clock()
end

--- incremental editing (slots): N and the buffers are kept; Seek before emitting, Pad to close a slot
function Handle:Edit(origin, isLocal)
	self.Mode = "edit"
	self.Local = isLocal == true
	self.CF, self.Inv, self.Auto = origin, origin:Inverse(), false
	self.XS = 1
	self.UsedT = os.clock()
end

function Handle:Seek(sTri, gTri)
	self.S.Cur, self.G.Cur = sTri, gTri
end

function Handle:Pad(sTo, gTo)
	pad(self.S, sTo)
	pad(self.G, gTo)
end

function Handle:SetCount(nS, nG)
	self.S.N, self.G.N = nS, nG
	self.Exact = true                                        -- a slot form: its capacity is exactly this
end

--- a uniform scale about pivot applied to every following point (the Seal's X(); horns grown about their base)
function Handle:Xf(pivot, s)
	self.XP, self.XS = pivot or ZERO, s or 1
end

-- (2026-10-19, audit P5C-02) forms asked to show but with nothing to show it with: a layer holding triangles and no
-- part yet (its first build still running, or failed and waiting out FailT). Counted by parts(); Forge.Drawn reads it.
local unbuilt = 0

local function parts(h)
	local S, G = h.S, h.G
	if (S.N > 0 and not S.Part) or (G.N > 0 and not G.Part) then unbuilt += 1 end
	return ((S.N > 0) and 1 or 0) + ((G.N > 0) and 1 or 0)
end

--- (2026-10-19, audit P5C-02) form(...) (any Forge form, or a caller's function drawing several) -> true when every
--- form it showed has its mesh built, false when one is still building or failed. A forged form replaces a Default
--- telegraph (the lance's beam, the halo, the column, the arches, the cages), so a caller draws the Default strokes
--- when this is false: a pending or failed build must not leave the opponent with no tell at all.
function Forge.Drawn(form, ...)
	local u = unbuilt
	form(...)
	return unbuilt == u
end

function Handle:Finish(scale)
	local S, G = self.S, self.G
	if self.Mode == "frame" then
		S.N, G.N = S.Cur, G.Cur
	end
	self.Scale = scale or 1
	self.Visible = true
	self.Valid = true
	ensure(self, S)
	ensure(self, G)
	if self.WrapPal then                                     -- the bands follow the form: a moved start rewrites them all
		local ax0, lo0 = self.WrapAx, self.WrapLo
		wrapAxis(self)
		if ax0 ~= self.WrapAx or math.abs((lo0 or 0) - self.WrapLo) > 0.05 then S.Flush, G.Flush = true, true end
	end
	placeLayer(self, S)
	placeLayer(self, G)
	writeLayer(self, S)
	writeLayer(self, G)
	showLayer(self, S)
	showLayer(self, G)
	self.XS = 1
	return parts(self)
end

function Handle:Place(origin, scale)
	self.CF = origin
	self.Scale = scale or 1
	self.Visible = true
	self.UsedT = os.clock()
	local S, G = self.S, self.G
	placeLayer(self, S)
	placeLayer(self, G)
	showLayer(self, S)
	showLayer(self, G)
	return parts(self)
end

function Handle:Hide()
	if not self.Visible then return end
	self.Visible = false
	showLayer(self, self.S)
	showLayer(self, self.G)
end

--- true when every argument equals the last call's and the geometry exists (then Place, do not re-emit)
function Handle:Same(...)
	local s, n = self.Sig, select("#", ...)
	local same = (s.n == n)
	for i = 1, n do
		local v = select(i, ...)
		if s[i] ~= v then
			same = false
			s[i] = v
		end
	end
	s.n = n
	return same and self.Valid
end

function Handle:GlowLevel(k)
	local q = floor(clamp(k, 0, 1) * 64 + 0.5) / 64
	local c = Color3.new(q, q, q)
	local G = self.G
	if G.Tint ~= c then
		G.Tint = c
		if G.Part then G.Part.Color = tintHue(c, self.Hue) end
	end
end

--- the handle's wrap (THE WRAP BANDS): pal = the wrapped palette (nil = the skin's own colours), d0 = its start in the
--- band cycle; repaints only on a change (the Neon part's Color; both layers rewritten whole, rigid forms included)
function Handle:SetWrap(pal, d0)
	local hue = pal and WHITE or nil
	if self.Hue ~= hue then
		self.Hue = hue
		local G = self.G
		if G.Part then G.Part.Color = tintHue(G.Tint, hue) end
	end
	if self.WrapPal ~= pal or self.WrapD0 ~= d0 then
		self.WrapPal, self.WrapD0 = pal, d0
		if pal then wrapAxis(self) end
		for _, L in ipairs({ self.S, self.G }) do
			L.Flush = true
			if L.Mesh then writeLayer(self, L) end
		end
	end
end

function Handle:Destroy()
	if self.Dead then return end
	self.Dead = true
	self.Visible = false
	for _, L in ipairs({ self.S, self.G }) do
		if L.Part then L.Part:Destroy() end
		if L.Mesh then L.Mesh:Destroy() end
		L.Part, L.Mesh = nil, nil
		table.clear(L.FP)
		table.clear(L.FC)
		table.clear(L.PP)
		table.clear(L.PC)
	end
	live[self] = nil
end

--- back to a fresh state for its next owner (the meshes stay)
local function resetHandle(h)
	h:Hide()
	h.Sig.n = 0
	h.Valid = false
	table.clear(h.SlotSig)
	h.Mode, h.Auto, h.XS = "frame", false, 1
	for _, L in ipairs({ h.S, h.G }) do
		local mesh, PP, V = L.Mesh, L.PP, L.V
		if mesh then                                          -- collapse what it showed (a slot form refills from scratch)
			for i = 1, 3 * L.NLast do
				if PP[i] ~= ZERO then
					mesh:SetPosition(V[i], ZERO)
					PP[i] = ZERO
				end
			end
		end
		L.Cur, L.N, L.MaxAbs, L.NLast = 0, 0, 0, 0
		L.Lo, L.Hi = HUGE, 0
		table.clear(L.FP)
		table.clear(L.FC)
	end
	h:GlowLevel(1)
end

----------------------------------------------------------------------------------------------------
-- BUILDERS (the kit's _PB)
----------------------------------------------------------------------------------------------------
function Handle:Tri(a, b, c, ca, cb, cc)
	local A = disp(ca)
	put(self, self.S, a, b, c, A, cb and disp(cb) or A, cc and disp(cc) or A)
end

function Handle:GTri(a, b, c, ka, kb, kc)
	put(self, self.G, a, b, c, glowCol(ka), glowCol(kb or ka), glowCol(kc or ka))
end

--- a quad's corners (a, b, c, d) as two triangles into L, oriented per `orient`
local function quadInto(h, L, a, b, c, d, ca, cb, cc, cd, orient)
	if orient == true then
		put(h, L, a, b, c, ca, cb, cc)
		put(h, L, a, c, d, ca, cc, cd)
		put(h, L, a, c, b, ca, cc, cb)
		put(h, L, a, d, c, ca, cd, cc)
		return
	end
	if orient and (b - a):Cross(c - a):Dot(orient) < 0 then
		b, d, cb, cd = d, b, cd, cb
	end
	put(h, L, a, b, c, ca, cb, cc)
	put(h, L, a, c, d, ca, cc, cd)
end

local function triInto(h, L, a, b, c, ca, cb, cc, orient)
	if orient == true then
		put(h, L, a, b, c, ca, cb, cc)
		put(h, L, a, c, b, ca, cc, cb)
		return
	end
	if orient and (b - a):Cross(c - a):Dot(orient) < 0 then
		b, c, cb, cc = c, b, cc, cb
	end
	put(h, L, a, b, c, ca, cb, cc)
end

--- the kit's pface for a quad: cols linear or false (NOGLOW), glows k; route nil (auto) / "s" / "g"
function Handle:Quad(a, b, c, d, la, lb, lc, ld, ka, kb, kc, kd, orient, route)
	ka, kb, kc, kd = ka or 0, kb or 0, kc or 0, kd or 0
	if not route then
		if not (la or lb or lc or ld) or max(ka, kb, kc, kd) >= Config.NeonFrom then route = "g" else route = "s" end
	end
	if route == "g" then
		quadInto(self, self.G, a, b, c, d, glowCol(ka), glowCol(kb), glowCol(kc), glowCol(kd), orient)
	else
		quadInto(self, self.S, a, b, c, d, emitCol(la or NOCOL, ka), emitCol(lb or NOCOL, kb), emitCol(lc or NOCOL, kc),
			emitCol(ld or NOCOL, kd), orient)
	end
end

--- the kit's pface for a triangle
function Handle:Face3(a, b, c, la, lb, lc, ka, kb, kc, orient, route)
	ka, kb, kc = ka or 0, kb or 0, kc or 0
	if not route then
		if not (la or lb or lc) or max(ka, kb, kc) >= Config.NeonFrom then route = "g" else route = "s" end
	end
	if route == "g" then
		triInto(self, self.G, a, b, c, glowCol(ka), glowCol(kb), glowCol(kc), orient)
	else
		triInto(self, self.S, a, b, c, emitCol(la or NOCOL, ka), emitCol(lb or NOCOL, kb), emitCol(lc or NOCOL, kc), orient)
	end
end

--- a solid quad of one display colour (as given)
local function squad(h, a, b, c, d, col)
	put(h, h.S, a, b, c, col, col, col)
	put(h, h.S, a, c, d, col, col, col)
end

--- a Neon quad of one strength (as given)
local function gquad(h, a, b, c, d, k)
	local g = glowCol(k)
	put(h, h.G, a, b, c, g, g, g)
	put(h, h.G, a, c, d, g, g, g)
end

--- a convex polygon pts[1..n] as a fan, one display colour; rev = the kit's reversed() (the other face)
local function polyFan(h, pts, n, col, rev)
	if rev then
		for i = n - 1, 2, -1 do put(h, h.S, pts[n], pts[i], pts[i - 1], col, col, col) end
	else
		for i = 2, n - 1 do put(h, h.S, pts[1], pts[i], pts[i + 1], col, col, col) end
	end
end

-- colour specs: a linear Vector3, {A, B, Pow, Band} (mix(A, B, min(1, u ^ Pow)), x Band on odd rings) or {Fn}
local function colLin(spec, u, k)
	if typeof(spec) == "Vector3" then return spec end
	if spec.Fn then return spec.Fn(u, k) end
	local f = u
	if spec.Pow and spec.Pow ~= 1 then f = (u > 0) and u ^ spec.Pow or 0 end
	if f > 1 then f = 1 end
	local v = spec.A + (spec.B - spec.A) * f
	if spec.Band and k % 2 == 1 then v = v * spec.Band end
	return v
end

local function glowAt(spec, u, i)
	if not spec then return 0 end
	local R = spec.Ridges
	if (i == R[1] or i == R[2]) and u > spec.Lo and u < spec.Hi then return spec.K end
	return 0
end

local TRIG = {}
local function trig(n)
	local t = TRIG[n]
	if not t then
		t = { c = {}, s = {} }
		for i = 0, n - 1 do
			t.c[i + 1], t.s[i + 1] = cos(TAU * i / n), sin(TAU * i / n)
		end
		TRIG[n] = t
	end
	return t
end

local RING, TAN, UU, RAD, CC = {}, {}, {}, {}, {}

--- the kit's _PB.tube: an n-sided tapered tube along pts[1..m]; ring vertex 0 faces `ref` (its ridge);
--- col(u, k) per ring, an ember seam strip just proud of ridge i where the glow spec says; a closing cap (or a tip)
function Handle:Tube(pts, m, radii, ref, col, glow, n, tip, caps)
	m = m or #pts
	n = n or 6
	if m < 2 then return end
	local tg = trig(n)
	local cosT, sinT = tg.c, tg.s
	local num = type(radii) == "number"
	for k = 1, m do
		local p = pts[k]
		local t = unit(pts[min(k + 1, m)] - pts[max(k - 1, 1)], UP)
		TAN[k] = t
		local u = ref - t * ref:Dot(t)
		if u.Magnitude > 1e-6 then u = u.Unit else u = ortho(t) end
		local w = t:Cross(u)
		local r = num and radii or radii[k]
		RAD[k] = r
		local ring = RING[k]
		if not ring then
			ring = {}
			RING[k] = ring
		end
		for i = 1, n do ring[i] = p + (u * cosT[i] + w * sinT[i]) * r end
		local uk = (k - 1) / max(m - 1, 1)
		UU[k] = uk
		CC[k] = disp(colLin(col, uk, k - 1))
	end
	local S = self.S
	for k = 1, m - 1 do
		local ra, rb, ca, cb = RING[k], RING[k + 1], CC[k], CC[k + 1]
		for i = 1, n do
			local j = i % n + 1
			put(self, S, ra[i], ra[j], rb[j], ca, ca, cb)
			put(self, S, ra[i], rb[j], rb[i], ca, cb, cb)
		end
	end
	if glow then                                             -- the ember seams
		local sw = Config.SeamWidth
		for ri = 1, #glow.Ridges do
			local ridge = glow.Ridges[ri]
			if ridge and ridge < n then
				local i = ridge + 1
				local pl, pr = nil, nil
				for k = 1, m do
					local uk = UU[k]
					if uk > glow.Lo and uk < glow.Hi then
						local p, r = pts[k], RAD[k]
						local d = unit(RING[k][i] - p, UP)
						local sd = unit(TAN[k]:Cross(d), ortho(d))
						local q = p + d * (r + 0.004)
						local hw = max(0.006, min(0.016, r * 0.22)) * sw
						local L_, R_ = q - sd * hw, q + sd * hw
						if pl then gquad(self, pl, pr, R_, L_, glow.K) end
						pl, pr = L_, R_
					end
				end
			end
		end
	end
	if caps ~= false then polyFan(self, RING[1], n, disp(colLin(col, 0, 0)), true) end
	local rm = RING[m]
	if tip then
		local cl = colLin(col, 1, m)
		local cm = disp(cl)
		for i = 1, n do
			local j = i % n + 1
			local gi, gj = glowAt(glow, 1, i - 1), glowAt(glow, 1, j - 1)
			if gi > 0 or gj > 0 then
				put(self, S, rm[i], rm[j], tip, emitCol(cl, gi), emitCol(cl, gj), cm)
			else
				put(self, S, rm[i], rm[j], tip, cm, cm, cm)
			end
		end
	elseif caps ~= false then
		polyFan(self, rm, n, disp(colLin(col, 1, m)), false)
	end
end

-- the icosahedron (bmesh create_icosphere subdivisions=1: 12 vertices, 20 faces, a vertex at the top)
local ICO_V, ICO_F = {}, {}
do
	local yr, rr = 1 / sqrt(5), 2 / sqrt(5)
	ICO_V[1] = UP
	for k = 0, 4 do ICO_V[2 + k] = Vector3.new(rr * cos(TAU * k / 5), yr, rr * sin(TAU * k / 5)) end
	for k = 0, 4 do ICO_V[7 + k] = Vector3.new(rr * cos(TAU * k / 5 + pi / 5), -yr, rr * sin(TAU * k / 5 + pi / 5)) end
	ICO_V[12] = -UP
	for k = 0, 4 do
		local u0, u1, l0, l1 = 2 + k, 2 + (k + 1) % 5, 7 + k, 7 + (k + 1) % 5
		ICO_F[#ICO_F + 1] = { 1, u0, u1 }
		ICO_F[#ICO_F + 1] = { u0, l0, u1 }
		ICO_F[#ICO_F + 1] = { u1, l0, l1 }
		ICO_F[#ICO_F + 1] = { 12, l1, l0 }
	end
	for _, f in ipairs(ICO_F) do                           -- outward winding
		local a, b, c = ICO_V[f[1]], ICO_V[f[2]], ICO_V[f[3]]
		if (b - a):Cross(c - a):Dot(a + b + c) < 0 then f[2], f[3] = f[3], f[2] end
	end
end

--- the kit's knob: an icosphere of one colour
function Handle:Knob(c, r, col)
	local cd = disp(col)
	for _, f in ipairs(ICO_F) do
		put(self, self.S, c + ICO_V[f[1]] * r, c + ICO_V[f[2]] * r, c + ICO_V[f[3]] * r, cd, cd, cd)
	end
end

--- an icosphere whose corners under (centre - r x below) glow k (the rubble: lit from the pit)
function Handle:Ico(c, r, col, below, k)
	local cd, ce = disp(col), emitCol(col, k or 0)
	for _, f in ipairs(ICO_F) do
		local a, b, d = ICO_V[f[1]], ICO_V[f[2]], ICO_V[f[3]]
		put(self, self.S, c + a * r, c + b * r, c + d * r, (below and a.Y < -below) and ce or cd,
			(below and b.Y < -below) and ce or cd, (below and d.Y < -below) and ce or cd)
	end
end

----------------------------------------------------------------------------------------------------
-- POOL AND SCOPES
----------------------------------------------------------------------------------------------------
local globals = {}            -- Forge.form handles by key (the pool, `free`, is declared over evictSpare)
local lastSweep = os.clock()

local function sweep()
	local now = os.clock()
	if now - lastSweep < 10 then return end
	lastSweep = now
	for key, h in pairs(globals) do
		if h.Dead then
			globals[key] = nil
		elseif not h.Visible and now - h.UsedT > Config.IdleLife then
			h:Destroy()
			globals[key] = nil
		end
	end
end

--- (2026-10-26) MeshBudget's Optional: when a worn skin's essential build asks for room, every spare in the pool and every
--- hidden form unused for 2 s lets go of its meshes (the next Devil cast builds them again). Before, spares waited out
--- IdleLife (120 s) and starved the Cryo skin kits after a Devil preview at the Loadout Altar.
do
	local mod = script.Parent:FindFirstChild("MeshBudget")
	local ok, MB = pcall(function() return mod and require(mod) end)
	if ok and type(MB) == "table" and MB.Optional then
		MB.Optional(function()
			while evictSpare() do end
			local now = os.clock()
			for key, h in pairs(globals) do
				if h.Dead then
					globals[key] = nil
				elseif not h.Visible and now - h.UsedT > 2 then
					h:Destroy()
					globals[key] = nil
				end
			end
		end)
	end
end

function Forge.form(key, opts)
	sweep()
	local h = globals[key]
	if not h or h.Dead then
		h = newHandle(tostring(key), key)
		globals[key] = h
	end
	if opts and opts.Bound then h.BoundHint = opts.Bound end
	h.UsedT = os.clock()
	return h
end

function Forge.Release(key)
	local h = globals[key]
	if h then
		h:Destroy()
		globals[key] = nil
	end
end

local Scope = {}
Scope.__index = Scope
local scopes = setmetatable({}, { __mode = "k" })

function Forge.Scope(name)
	local sc = setmetatable({ Name = name or "devil", H = {}, Frame = 0, Cv = nil, Tag = nil, Pieces = 0 }, Scope)
	scopes[sc] = true
	return sc
end

--- a form's wrap (pal.Wrap: SkinCatalog's "<Skin>+<Wrap>" palette) -> (palette, its start in the band cycle: fixed per
--- form (kind, copy), as RadiantDraw starts each stroke at its own point); nil, nil = the skin's own colours
local wrapD0 = {}
local function wrapFor(pal, kind, id)
	if not (type(pal) == "table" and pal.Wrap and pal.At) then return nil, nil end
	local key = tostring(kind) .. "#" .. tostring(id)
	local d0 = wrapD0[key]
	if not d0 then
		local h = 0
		for i = 1, #key do h = (h * 31 + string.byte(key, i)) % 1000003 end
		d0 = ((h * 0.6180339887) % 1) * 2 * SPAN
		wrapD0[key] = d0
	end
	return pal, d0
end

function Scope:Begin(cv, tag)
	self.Frame += 1
	self.Cv, self.Tag, self.Pieces = cv, tag, 0
	camRefresh()
end

--- the scope's form `kind` (copy `id`): this frame's, from the pool, or new
function Scope:Get(kind, id, bound)
	local byKind = self.H[kind]
	if not byKind then
		byKind = {}
		self.H[kind] = byKind
	end
	id = id or 1
	local h = byKind[id]
	if not h or h.Dead then
		local pool = free[kind]
		h = pool and table.remove(pool)
		while h and h.Dead do h = table.remove(pool) end
		h = h or newHandle(kind, kind)
		byKind[id] = h
	end
	if bound then h.BoundHint = bound end
	h.Frame = self.Frame
	h:SetWrap(wrapFor(self.Cv and self.Cv.Palette, kind, id))
	return h
end

function Scope:Add(n)
	if n and n > 0 then
		self.Pieces += n
		if self.Cv then self.Cv:Count(n, self.Tag) end
	end
	return n or 0
end

function Scope:End()
	local f = self.Frame
	for _, byKind in pairs(self.H) do
		for _, h in pairs(byKind) do
			if h.Frame ~= f then h:Hide() end
		end
	end
	return self.Pieces
end

function Scope:Destroy()
	for kind, byKind in pairs(self.H) do
		for _, h in pairs(byKind) do
			if not h.Dead then
				local pool = free[kind]
				if not pool then
					pool = {}
					free[kind] = pool
				end
				if #pool < Config.PoolKeep then
					resetHandle(h)
					table.insert(pool, h)
				else
					h:Destroy()
				end
			end
		end
	end
	table.clear(self.H)
	scopes[self] = nil
end

function Forge.Stats()
	local n, pooled = 0, 0
	for _ in pairs(live) do n += 1 end
	for _, p in pairs(free) do pooled += #p end
	return { Forms = n, Building = building, Pooled = pooled }
end

function Forge.DestroyAll()
	for sc in pairs(scopes) do sc:Destroy() end
	for h in pairs(live) do h:Destroy() end
	table.clear(globals)
	table.clear(free)
end

local SLOT_KINDS = { LanceChain = true, ColumnChains = true, PactChain = true }   -- SetCount forms: exact capacity

--- a handle of `kind` built ahead for sTris solid / gTris Neon triangles in a box +-bound, waiting in the pool
function Forge.Prewarm(kind, sTris, gTris, bound)
	local pool = free[kind]
	if not pool then
		pool = {}
		free[kind] = pool
	end
	if #pool >= Config.PoolKeep then return end
	local h = newHandle(kind, kind)
	h.BoundHint = bound
	h.Exact = SLOT_KINDS[kind] == true
	for _, L in ipairs({ { h.S, sTris }, { h.G, gTris } }) do
		local lay, n = L[1], L[2]
		if n and n > 0 then
			lay.WantCap, lay.WantB = capFor(n, h.Exact), bound or 8
			requestBuild(h, lay)
		end
	end
	table.insert(pool, h)
end

function Forge.IsDevil(pal)
	return type(pal) == "table" and pal.Id == "Devil"
end

----------------------------------------------------------------------------------------------------
-- shared colour / glow specs (hoisted; the varying K is written before each Tube)
----------------------------------------------------------------------------------------------------
local function boneFn(u, _k)
	return mixl(IRON, IRON_HI, 0.5 + 0.5 * sin(3 * u))
end
local C_HORN = { A = IRON, B = BLOOD, Pow = 2.6, Band = 0.78 }
local C_DOME = { A = IRON, B = BLOOD, Pow = 2.4, Band = 0.8 }
local C_BONE = { Fn = boneFn }
local C_IB1 = { A = IRON, B = BLOOD, Pow = 1 }
local C_IB2 = { A = IRON, B = BLOOD, Pow = 2 }
local C_IB15 = { A = IRON, B = BLOOD, Pow = 1.5 }
local C_IB3 = { A = IRON, B = BLOOD, Pow = 3 }
local G_HORN = { Ridges = { 0 }, Lo = 0.12, Hi = 0.92, K = 1 }
local G_BAT = { Ridges = { 0, 3 }, Lo = 0.08, Hi = 0.9, K = 1 }
local G_DOME = { Ridges = { 0 }, Lo = 0.05, Hi = 0.9, K = 1 }
local G_R0 = { Ridges = { 0 }, Lo = -1, Hi = 2, K = 1 }       -- ridge 0, the whole length (+ the tip)
local G_LINK = { Ridges = { 0, 2 }, Lo = -1, Hi = 2, K = 1 }  -- a chain link: both flat faces
local G_CLAW = { Ridges = { 0 }, Lo = 0.1, Hi = 0.8, K = 0.7 }
local G_BCLAW = { Ridges = { 0 }, Lo = -1, Hi = 0.7, K = 0.5 }
local G_SEAM4 = { Ridges = { 0, 1, 2, 3 }, Lo = -1, Hi = 2, K = 0.85 }   -- (fb1) the column chains' seam: all 4 faces lit
local EMBER_DIM = lin("#C8141C") * 0.32           -- (fb1) the dim crimson glow inside the floor cracks (not SEAM x k)
local CRACK_IN = lin("#160709")                   -- (fb1) the cracks' broken band (was STONE)

local PTS, PTS2, RADS = {}, {}, {}

--- the kit's _link: one chain link, a stadium loop along d in the plane of d and ax (11 points), seams on both faces
local LOOP = {}
local function link(h, ctr, d, ax, hl, hw, rr, k, col)
	for m = 0, 10 do
		LOOP[m + 1] = ctr + d * (hl * cos(TAU * m / 10)) + ax * (hw * sin(TAU * m / 10))
	end
	G_LINK.K = k
	h:Tube(LOOP, 11, rr, ax:Cross(d), col or IRON, G_LINK, 4)
end
local LINK_S, LINK_G = 84, 40                     -- a link's triangles: 10 x 4 quads + 2 caps / 2 seam strips
local BARB_S = 28                                 -- two barbs (1 x 4 quads + cap + 4-tip each)
local LINK_SLOT_S, LINK_SLOT_G = LINK_S + BARB_S, LINK_G   -- a barbed link's slot

--- a chain's frame at p along d: X = d x up, Y = up (d's vertical made perpendicular), Z = -d (links along -Z)
local function chainFrame(p, d)
	local up = unit(UP - d * d:Dot(UP), ortho(d))
	local s2 = d:Cross(up).Unit
	return CFrame.fromMatrix(p, s2, up, -d), up, s2
end

--- A STAMP: what build(th) emits into a scratch handle (local studs, no parts), to be copied many times by
--- Handle:Stamp (a chain's links are all one shape: forging each one is the cost, copying it is not)
local function capture(build)
	local th = setmetatable({ S = newLayer(false), G = newLayer(true), Local = true, Auto = false, XS = 1, XP = ZERO,
		CF = CFrame.identity, Inv = CFrame.identity }, Handle)
	build(th)
	local S, G = th.S, th.G
	return { SP = S.FP, SC = S.FC, SN = S.Cur, SM = S.MaxAbs, GP = G.FP, GC = G.FC, GN = G.Cur, GM = G.MaxAbs }
end

local function stampLayer(L, P, C, n, off, m)
	if n <= 0 then return end
	local base = L.Cur
	local FP, FC = L.FP, L.FC
	local i0 = 3 * base
	for i = 1, 3 * n do
		FP[i0 + i] = P[i] + off
		FC[i0 + i] = C[i]
	end
	if base + 1 < L.Lo then L.Lo = base + 1 end
	if base + n > L.Hi then L.Hi = base + n end
	L.Cur = base + n
	local o = max(abs(off.X), abs(off.Y), abs(off.Z)) + m
	if o > L.MaxAbs then L.MaxAbs = o end
end

--- a stamp's triangles at the write position, moved by off (local)
function Handle:Stamp(tpl, off)
	stampLayer(self.S, tpl.SP, tpl.SC, tpl.SN, off, tpl.SM)
	stampLayer(self.G, tpl.GP, tpl.GC, tpl.GN, off, tpl.GM)
end

--- slot idx (perS solid / perG Neon triangles) holds `tpl` at `off` when want ~= 0, nothing when 0; it is rewritten
--- only when want changes (a never-filled slot is already collapsed)
local function slotFill(h, idx, perS, perG, want, tpl, off)
	local SS = h.SlotSig
	local had = SS[idx]
	if had == want then return end
	SS[idx] = want
	if had == nil and want == 0 then return end
	local s0, g0 = (idx - 1) * perS, (idx - 1) * perG
	h:Seek(s0, g0)
	if want ~= 0 then h:Stamp(tpl, off) end
	h:Pad(s0 + perS, g0 + perG)
end

--- two backswept barbs on a link (every 3rd), out along ax
local BARB = {}
local function barbs(h, ctr, d, ax, hw, s)
	s = s or 1
	for sg = 1, -1, -2 do
		local q0 = ctr + ax * (hw * sg)
		BARB[1], BARB[2] = q0, q0 + (ax * (0.06 * sg) - d * 0.05) * s
		RADS[1], RADS[2] = 0.035 * s, 0.022 * s
		h:Tube(BARB, 2, RADS, ax, IRON, nil, 4, q0 + (ax * (0.13 * sg) - d * 0.16) * s)
	end
end

----------------------------------------------------------------------------------------------------
-- HORNS (horns_at: on the head, replacing the halo)
----------------------------------------------------------------------------------------------------
do
	-- the kit's control points are HEAD-LOCAL Roblox studs (x right, y up, -z forward): from the top-front of the head,
	-- out, then curling in
	local HORN_P = {}
	for si, s in ipairs({ 1, -1 }) do
		HORN_P[si] = { Vector3.new(s * 0.26, 0.50, -0.14), Vector3.new(s * 0.60, 0.70, -0.10),
			Vector3.new(s * 0.68, 1.16, 0.04), Vector3.new(s * 0.50, 1.58, 0.16) }
	end

	--- Halo: both horns on the head (headCF = the Head part's CFrame), grown by g about each base:
	--- g = ease("Back", up01(t, LOCK + 0.04, LOCK + 0.46)) x (1 - ease("Quad", up01(t, DROP0, DROP1))). 2 parts.
	function Forge.Horns(sc, headCF, g)
		if g < 0.01 then return 0 end
		local h = sc:Get("Horns")
		if h:Same(g) then return sc:Add(h:Place(headCF)) end
		h:Begin(headCF, true)
		for si = 1, 2 do
			local s = (si == 1) and 1 or -1
			local P = HORN_P[si]
			for k = 0, 11 do
				PTS[k + 1] = bez3(P[1], P[2], P[3], P[4], k / 12)
				RADS[k + 1] = 0.155 * (1 - k / 12) ^ 0.85 * (1 + 0.07 * (k % 2))
			end
			h:Xf(P[1], g)
			h:Tube(PTS, 12, RADS, Vector3.new(s, 0.25, 0), C_HORN, G_HORN, 7, P[4] + (P[4] - P[3]).Unit * 0.05)
		end
		return sc:Add(h:Finish())
	end

end

----------------------------------------------------------------------------------------------------
-- BAT WINGS (bat_geo / draw_bat, on the original wing tracks)
----------------------------------------------------------------------------------------------------
do
	local S_W = 0.8                                  -- halo_r2's wing scale
	local BAT_K = 1.12
	local BAT_E, BAT_WR = Vector3.new(0.95 * BAT_K, 0.95 * BAT_K, 0), Vector3.new(2.05 * BAT_K, 1.40 * BAT_K, 0)
	local BAT_F = { { -18.0, 1.75 * BAT_K }, { -55.0, 1.95 * BAT_K }, { -85.0, 2.05 * BAT_K }, { -112.0, 2.0 * BAT_K } }
	local BAT_THUMB = { 70.0, 0.34 }
	local BAT_BODY = Vector3.new(0.10, -1.20 * BAT_K, 0)
	local BF_MEAN = (-18 - 55 - 85 - 112) / 4
	local BAT_R1 = { 0.095, 0.088, 0.08, 0.075 }
	local BAT_R2 = { 0.075, 0.07, 0.066, 0.062 }
	local BAT_RF = { 0.055, 0.05, 0.044, 0.036, 0.028 }
	local ARM2, ARM3, FING2, FING3, FG = {}, {}, { {}, {}, {}, {} }, { {}, {}, {}, {} }, {}
	local Q3 = {}

	--- Halo: one bat wing (side +1 right / -1 left) on RadiantFX_Staff's wing frame ws {A, o, U, n, fx, ca, sa} (the
	--- original tracks' alpha / beta / fx, the idle flap included), ga = arm grow, sp = spread, grow[1..4] = the fingers'
	--- feather_grow(t, 2k). The wing is forged in its own plane: alpha turns the PART and fx stretches it (Size), so a
	--- flap writes no vertex. out[k] = {Q = 6 world points base -> tip, G = grow} (filled, reused): the glints. 2 parts.
	function Forge.BatWing(sc, side, ws, ga, sp, grow, out)
		if ga < 0.02 then return 0 end
		local s = (side >= 0) and 1 or -1
		local h = sc:Get("BatWing", s)
		local Xw = ws.o * ws.ca + ws.U * ws.sa
		local Yw = ws.U * ws.ca - ws.o * ws.sa
		local cf = CFrame.fromMatrix(ws.A, Xw, Yw, ws.n)
		local fx = ws.fx
		-- the fingers (2D, before S_W)
		local fe = smooth(clamp((ga - 0.85) / 0.15, 0, 1))
		for k = 1, 4 do FG[k] = (grow[k] or 0) * fe end
		local same = h:Same(ga, sp, FG[1], FG[2], FG[3], FG[4])
		local fxb = same and h.Fxb or fx
		local function W(p) return Vector3.new(S_W * p.X * fxb, S_W * p.Y, 0) end
		-- the arm: shoulder -> elbow -> wrist, unfolding from the shoulder
		for k = 0, 2 do ARM2[k + 1] = BAT_E * (k / 3) end
		for k = 0, 3 do ARM2[k + 4] = BAT_E:Lerp(BAT_WR, k / 3) end
		if ga < 1 then
			for i = 1, 7 do ARM2[i] = ARM2[i] * ga end
		end
		local wr2 = ARM2[7]
		for k = 1, 4 do
			local a0, L0 = BAT_F[k][1], BAT_F[k][2]
			local a = rad(BF_MEAN + (a0 - BF_MEAN) * sp)
			local d = Vector3.new(cos(a), sin(a), 0)
			local pdir = (d.Y > 0) and Vector3.new(d.Y, -d.X, 0) or Vector3.new(-d.Y, d.X, 0)   -- bows toward the tip
			local L = L0 * max(FG[k], 0)
			local q = FING2[k]
			for m = 0, 5 do
				local u = m / 5
				q[m + 1] = wr2 + d * (L * u) + pdir * (0.07 * L * u * u)
			end
		end
		if out then                                              -- the live fingers in world space (this frame's fx)
			for k = 1, 4 do
				local o = out[k]
				if not o then
					o = { Q = {}, G = 0 }
					out[k] = o
				end
				o.G = FG[k]
				for m = 1, 6 do
					local p = FING2[k][m]
					o.Q[m] = cf:PointToWorldSpace(Vector3.new(S_W * p.X * fx, S_W * p.Y, 0))
				end
			end
		end
		if same then return sc:Add(h:Place(cf, Vector3.new(fx / fxb, 1, 1))) end
		h.Fxb = fxb
		h:Begin(cf, true)
		local nw = Vector3.zAxis
		for i = 1, 7 do ARM3[i] = W(ARM2[i]) end
		h:Tube(ARM3, 4, BAT_R1, nw, C_BONE, G_BAT, 6)
		for i = 1, 4 do PTS[i] = ARM3[i + 3] end
		h:Tube(PTS, 4, BAT_R2, nw, C_BONE, G_BAT, 6)
		h:Knob(ARM3[4], 0.105, IRON_HI)
		h:Knob(ARM3[7], 0.11, IRON_HI)
		if ga > 0.9 then                                         -- the thumb claw: a short hooked spike off the wrist
			local a = rad(BAT_THUMB[1])
			local e = Vector3.new(cos(a), sin(a), 0)
			local t1, t2, t3 = wr2, wr2 + e * (BAT_THUMB[2] * 0.5), wr2 + e * BAT_THUMB[2] + Vector3.new(0.08, -0.04, 0)
			PTS[1], PTS[2], PTS[3] = W(t1), W(t2), W(t3)
			RADS[1], RADS[2], RADS[3] = 0.05, 0.035, 0.02
			h:Tube(PTS, 3, RADS, nw, C_IB1, nil, 5, W(t3 + Vector3.new(0.06, -0.07, 0)))
		end
		for k = 1, 4 do
			local q2 = FING2[k]
			if FG[k] > 0.02 then
				local q3 = FING3[k]
				for m = 1, 6 do q3[m] = W(q2[m]) end
				h:Tube(q3, 5, BAT_RF, nw, C_BONE, G_BAT, 6, q3[6])
				local d2 = unit(q2[6] - q2[5], Vector3.xAxis)        -- a claw hook off the tip, 60 deg to the trailing edge
				local hk = Vector3.new(d2.X * 0.5 + d2.Y * 0.866, -d2.X * 0.866 + d2.Y * 0.5, 0)
				if hk.Y > d2.Y then hk = Vector3.new(d2.X * 0.5 - d2.Y * 0.866, d2.X * 0.866 + d2.Y * 0.5, 0) end
				PTS2[1], PTS2[2] = W(q2[6] - d2 * 0.04), W(q2[6] + d2 * 0.12)
				RADS[1], RADS[2] = 0.034, 0.026
				h:Tube(PTS2, 2, RADS, nw, BLOOD, nil, 5, W(q2[6] + d2 * 0.17 + hk * 0.11))
				Q3[k] = q3
			else
				Q3[k] = false
			end
		end
		-- the membrane (both sides): bays between neighbouring fingers, scalloped; the arm-to-flank panel
		local m3, m5, m25 = MEMB:Lerp(MEMB_HI, 0.3), MEMB:Lerp(MEMB_HI, 0.5), MEMB:Lerp(MEMB_HI, 0.25)
		for j = 1, 3 do
			local P, Q = Q3[j], Q3[j + 1]
			if P and Q then
				for k = 1, 4 do h:Quad(P[k], P[k + 1], Q[k + 1], Q[k], m3, m3, m3, m3, 0, 0, 0, 0, true, "s") end
				local deep = (s < 0 and j == 2) and 0.48 or 0.36
				local inner = P[3]:Lerp(Q[3], 0.5)
				local m1 = P[6]:Lerp(Q[6], 0.27):Lerp(inner, deep)
				local spk = P[6]:Lerp(Q[6], 0.5):Lerp(inner, 0.1)          -- a jag between two scallops
				local m2 = P[6]:Lerp(Q[6], 0.73):Lerp(inner, deep * 0.85)
				h:Face3(P[5], P[6], m1, m5, m5, m5, 0, 0, 0, true, "s")
				h:Face3(P[5], m1, spk, m5, m5, m5, 0, 0, 0, true, "s")
				h:Face3(P[5], spk, Q[5], m5, m5, m5, 0, 0, 0, true, "s")
				h:Face3(Q[5], spk, m2, m5, m5, m5, 0, 0, 0, true, "s")
				h:Face3(Q[5], m2, Q[6], m5, m5, m5, 0, 0, 0, true, "s")
			end
		end
		local last = Q3[4]
		if last then
			local body = W(BAT_BODY)
			local arm6, low = PTS, PTS2
			for k = 0, 5 do
				arm6[k + 1] = ARM3[min(floor(k * 6 / 5 + 0.5), 6) + 1]
				local u = k / 5
				local p = body:Lerp(last[6], u)
				low[k + 1] = p + (arm6[k + 1] - p) * (0.16 * sin(pi * u))   -- the trailing edge bows up toward the arm
			end
			for k = 1, 5 do h:Quad(arm6[k], arm6[k + 1], low[k + 1], low[k], m25, m25, m25, m25, 0, 0, 0, 0, true, "s") end
		end
		return sc:Add(h:Finish())
	end

end

----------------------------------------------------------------------------------------------------
-- THE HORN DOME (Blessing's shield; Overflow crumbles it) and the CARVED PLATES
----------------------------------------------------------------------------------------------------
do
	local S_TOP = 5.645                       -- hand_r2 Seal.top over the floor (the demo ally: head top + 0.45)
	local CRUMBLE = { { 7, 11 }, { 3, 8 }, { 0, 4 } }     -- the tips crumble first (Python slices pts[i0:i1])
	local DOME_P = {}

	--- Blessing: n big black-iron horns rooted round the ally, rising out of the floor with u and arching in over the
	--- head; their seams follow the seal's level. F = the Seal frame {x, z, fy, turn (deg), s, pivot, top?}. frag < 1
	--- (Overflow): the horns crumble, tips first, to ash. 2 parts (the kit counts one per horn).
	function Forge.HornDome(sc, F, level, u, t, frag, n)
		if u <= 0.01 then return 0 end
		n, frag = n or 7, frag or 1
		local h = sc:Get("HornDome")
		local k = clamp((level - 0.1) / 0.55, 0.2, 1)
		local s = F.s or 1
		local top = F.top or S_TOP
		local sink = (1 - ease("Quint", clamp(u, 0, 1))) * (top + 0.6)
		local base = Vector3.new(F.x, F.fy, F.z)
		local turn = rad(F.turn or 0) * 0.25
		local rigid = (s == 1 and frag >= 0.999)
		h:GlowLevel(k)
		local cf = CFrame.new(base - UP * (sink * s)) * CFrame.Angles(0, turn, 0)
		if rigid and h:Same(n, top, 1) then return sc:Add(h:Place(cf)) end
		if not rigid then h:Same(n, top, s, frag) end
		-- rigid: the dome at turn 0, sink 0 in its own frame (the part turns and sinks); else: the Python, in world
		-- (seal.X on the centre line and the tip, the radii 0.15 x s as given: (fb1) thinner ribs, was 0.23)
		local R0 = 2.35 * s
		local o, pv
		if rigid then
			h:Begin(cf, true)
			o, pv = ZERO, ZERO
		else
			h:Begin(CFrame.new(base), false)
			o, pv = base, F.pivot or (base + UP * 3.35)
		end
		for j = 0, n - 1 do
			local a = TAU * j / n + (rigid and 0 or turn) + 0.2
			local e = hdir(a)
			local sk = rigid and 0 or sink
			local P1, P2 = o + e * R0 + UP * (-0.2 - sk), o + e * (R0 * 1.1) + UP * (1.8 - sk)
			local P3, P4 = o + e * (R0 * 0.78) + UP * (top + 0.3 - sk), o + e * 0.34 + UP * (top + 0.05 - sk)
			for m = 0, 10 do
				local p = bez3(P1, P2, P3, P4, m / 11)
				PTS[m + 1] = (s == 1) and p or pv + (p - pv) * s
				RADS[m + 1] = 0.15 * s * (1 - m / 11) ^ 0.8 * (1 + 0.06 * (m % 2))
			end
			if frag >= 0.999 then
				G_DOME.K = 1
				local tp = P4 + (P4 - P3).Unit * 0.08
				h:Tube(PTS, 11, RADS, e, C_DOME, G_DOME, 7, (s == 1) and tp or pv + (tp - pv) * s)
			else
				local ash = mixl(mixl(IRON, MEMB, 0.5), ASH, 1 - frag)
				G_R0.K = frag
				for ci, rg in ipairs(CRUMBLE) do
					local i0, i1 = rg[1], rg[2]
					local sc_ = clamp((frag - 0.18 * (ci - 1)) / (1 - 0.18 * (ci - 1)), 0, 1) ^ 0.7
					if sc_ >= 0.06 then
						local cnt = i1 - i0
						local mc = ZERO
						for q = i0 + 1, i1 do mc += PTS[q] end
						mc /= cnt
						for q = 1, cnt do
							PTS2[q] = mc + (PTS[i0 + q] - mc) * sc_
							DOME_P[q] = RADS[i0 + q] * sc_
						end
						h:Tube(PTS2, cnt, DOME_P, e, ash, G_R0, 7)
					end
				end
				G_R0.K = 1
			end
		end
		return sc:Add(h:Finish())
	end

	local PLATE_N = 32

	--- the carved bar (box) p0 -> p1 in plate coords (x, y in the plane, z up the normal), z0..z1, an inlay along its top
	local function plateBar(h, p0, p1, wdt, z0, z1, col, k)
		local ax = Vector3.new(p1.X - p0.X, p1.Y - p0.Y, 0)
		ax = unit(ax, Vector3.xAxis)
		local sd = Vector3.new(-ax.Y, ax.X, 0) * (wdt / 2)
		local c1, c2, c3, c4 = p0 - sd, p1 - sd, p1 + sd, p0 + sd
		-- plate (x, y, z) -> part local (x, z, -y): a proper rotation (winding kept)
		local function M(q, z) return Vector3.new(q.X, z, -q.Y) end
		local lo1, lo2, lo3, lo4 = M(c1, z0), M(c2, z0), M(c3, z0), M(c4, z0)
		local hi1, hi2, hi3, hi4 = M(c1, z1), M(c2, z1), M(c3, z1), M(c4, z1)
		local cd = disp(col)
		squad(h, lo1, lo2, hi2, hi1, cd)
		squad(h, lo2, lo3, hi3, hi2, cd)
		squad(h, lo3, lo4, hi4, hi3, cd)
		squad(h, lo4, lo1, hi1, hi4, cd)
		squad(h, hi1, hi2, hi3, hi4, cd)
		if k > 0 then
			local f = 0.28
			local zg = z1 + 0.004
			gquad(h, M(p0 - sd * f, zg), M(p1 - sd * f, zg), M(p1 + sd * f, zg), M(p0 + sd * f, zg), k)
		end
	end

	local PL_TOP, PL_BOT, PL_RIM = {}, {}, {}
	--- the unit plate (R = 1) in part-local coords: Y = the normal; the part's Size stretches it to R in the plane
	local function plateGeo(h, th)
		local n = PLATE_N
		for k = 0, n - 1 do
			local a = TAU * k / n
			PL_RIM[k + 1] = Vector3.new(cos(a), sin(a), 0)
			PL_TOP[k + 1] = Vector3.new(cos(a), th, -sin(a))
			PL_BOT[k + 1] = Vector3.new(cos(a), -0.02, -sin(a))
		end
		local ci = disp(IRON)
		for k = 1, n do
			local j = k % n + 1
			squad(h, PL_BOT[k], PL_BOT[j], PL_TOP[j], PL_TOP[k], ci)
		end
		polyFan(h, PL_TOP, n, disp(mixl(IRON, MEMB, 0.4)), false)
		for k = 1, n do                                          -- the raised rim, an inlay ring along its top
			local j = k % n + 1
			plateBar(h, PL_RIM[k] * 0.93, PL_RIM[j] * 0.93, 0.09, th, th + 0.05, IRON_HI, 1)
		end
		local V5 = {}
		for k = 0, 4 do
			local a = pi * 1.5 + TAU * k / 5
			V5[k + 1] = Vector3.new(cos(a), sin(a), 0) * 0.84
		end
		for i = 0, 4 do plateBar(h, V5[i + 1], V5[(i + 2) % 5 + 1], 0.075, th, th + 0.06, IRON_HI, 1) end
	end

	--- a carved pentagram plate: a thick black-iron disc, a raised rim, five raised star bars, crimson inlays (glowK);
	--- on the floor at c (normal nil) or centred on c facing `normal`; rot turns it in its plane. The plate is forged once
	--- per thickness and stretched to R by its Size. 2 parts.
	function Forge.CarvedPlate(sc, id, c, R, rot, glowK, th, normal)
		if R < 0.01 then return 0 end
		th = th or 0.12
		local h = sc:Get("Plate", id)
		local ux, vx, nn
		if normal then
			ux, vx, nn = RD.basis(normal)
		else
			ux, vx, nn = EX, EY, UP
		end
		local cf = CFrame.fromMatrix(c, ux, nn, -vx) * CFrame.Angles(0, rot or 0, 0)
		local scale = Vector3.new(R, 1, R)
		h:GlowLevel(glowK)
		if h:Same(th) then return sc:Add(h:Place(cf, scale)) end
		h:Begin(cf, true)
		plateGeo(h, th)
		return sc:Add(h:Finish(scale))
	end

	--- Blessing's ground (Seal.ground): the carved plate under the seal (s = the ground's draw-on scale)
	function Forge.SealPlate(sc, F, s, level)
		if s <= 0.01 then return 0 end
		return Forge.CarvedPlate(sc, "Seal", Vector3.new(F.x, F.fy, F.z), 2.0 * s * (F.s or 1), rad(F.turn or 0) * 0.25,
			clamp((level - 0.1) / 0.5, 0.25, 1), 0.12)
	end

	--- Overflow's heal: the plate on the ally's chest (p = chest + forward x 0.5, normal = forward); flares at t0 (the
	--- heal lands, T_IN 1.04) and cools to a dull ember
	function Forge.ChestBrand(sc, p, normal, g, t, t0, R)
		if g <= 0.01 then return 0 end
		local k = 0.45 + 0.55 * (1 - ramp(t, t0 + 0.12, 0.8))
		return Forge.CarvedPlate(sc, "Chest", p, (R or 0.3) * g, 0, k, 0.05, normal)
	end

	--- Benediction: the pact seal stamped under a bonded ally (floorP = the floor under its root); flares with ls
	function Forge.PactSeal(sc, id, floorP, ls, k)
		if k <= 0.01 then return 0 end
		return Forge.CarvedPlate(sc, "Pact" .. tostring(id), floorP, 0.95 * k, 0, clamp(ls, 0.3, 1), 0.08)
	end

end

----------------------------------------------------------------------------------------------------
-- LIGHT LANCE: the chain, the hook, the hit horns
----------------------------------------------------------------------------------------------------
do
	local lanceTpl = { Sig = nil }                    -- [parity x 2 + (1 plain | 2 barbed)] = the link stamps of a pitch

	--- Light Lance: a taut chain of black-iron links from the staff tip along d, a..b drawn (studs), L to the target, the
	--- ramp r: the chain GAINS LINKS (pitch 0.83 -> 0.36, interlocked), every 3rd with two barbs, a brighter seam; a
	--- spade-tipped hook at the target once b reaches it. Links are forged in slots along the part's -Z and the part's
	--- Size stretches them to the live pitch; a link is rewritten only when it appears, goes, or the pitch moves 12%.
	--- 4 parts (the chain, the hook; solid + Neon each).
	function Forge.DevilChain(sc, tip, d, a, b, L, r, t)
		if b - a < 0.05 then return 0 end
		local nMax = Config.ChainMaxLinks
		local pitch = max(0.36 + 0.47 * (1 - r), L / nMax)
		local q = floor(log(pitch / 0.36) / log(Config.ChainPitchStep) + 0.5)
		local pb = 0.36 * Config.ChainPitchStep ^ q
		local rq = floor(clamp(r, 0, 1) * 4 + 0.5)
		local rr = 0.045 + 0.02 * rq / 4
		local sig = q * 8 + rq + 1
		local cf = chainFrame(tip, d)
		local hookAt = min(b, L - 0.25)
		local h = sc:Get("LanceChain", nil, nMax * 0.83 * Config.ChainPitchStep + 2)
		h:GlowLevel(0.4 + 0.6 * r)
		h:Edit(cf, true)
		local DL = Vector3.new(0, 0, -1)
		if lanceTpl.Sig ~= sig then                               -- the four links of this pitch, forged once
			local hl, hw = pb * 0.68, 0.17
			lanceTpl.Sig = sig
			for par = 0, 1 do
				local ax = (par == 0) and Vector3.yAxis or Vector3.xAxis
				lanceTpl[par * 2 + 1] = capture(function(th)
					link(th, ZERO, DL, ax, hl, hw, rr, 1, IRON)
				end)
				lanceTpl[par * 2 + 2] = capture(function(th)
					link(th, ZERO, DL, ax, hl, hw, rr, 1, IRON)
					barbs(th, ZERO, DL, ax, hw)
				end)
			end
		end
		for j = 0, nMax do
			local sj = j * pitch
			local want = (sj >= a and sj <= hookAt - 0.1) and sig or 0
			slotFill(h, j + 1, LINK_SLOT_S, LINK_SLOT_G, want, lanceTpl[(j % 2) * 2 + ((j % 3 == 1) and 2 or 1)],
				DL * (j * pb))
		end
		h:SetCount((nMax + 1) * LINK_SLOT_S, (nMax + 1) * LINK_SLOT_G)
		local n = sc:Add(h:Finish(Vector3.new(1, 1, pitch / pb)))
		if b >= L - 0.3 then                                      -- the hook and its spade, at the target
			local hk = sc:Get("LanceHook")
			hk:GlowLevel(0.4 + 0.6 * r)
			local hcf = chainFrame(tip + d * hookAt, d)
			if hk:Same(1) then return n + sc:Add(hk:Place(hcf)) end
			hk:Begin(hcf, true)
			local dl, upl, s2l = Vector3.new(0, 0, -1), Vector3.yAxis, Vector3.xAxis
			PTS[1], PTS[2], PTS[3] = ZERO, dl * 0.18, dl * 0.30 - upl * 0.12
			PTS[4], PTS[5] = dl * 0.26 - upl * 0.32, dl * 0.10 - upl * 0.42
			RADS[1], RADS[2], RADS[3], RADS[4], RADS[5] = 0.06, 0.06, 0.055, 0.05, 0.045
			G_R0.K = 1
			hk:Tube(PTS, 5, RADS, s2l, C_IB1, G_R0, 6)
			local e0 = PTS[5]
			local dv = (PTS[5] - PTS[4]).Unit
			local sd = dv:Cross(s2l).Unit
			local ol = { e0 + dv * 0.34, e0 - sd * 0.17 - dv * 0.06, e0 - sd * 0.05 + dv * 0.04, e0 + sd * 0.05 + dv * 0.04,
				e0 + sd * 0.17 - dv * 0.06 }
			for sgn = 1, -1, -2 do
				local ap = e0 + dv * 0.12 + s2l * (0.03 * sgn)
				for i = 1, 5 do
					local jj = i % 5 + 1
					if sgn > 0 then
						hk:Face3(ol[i], ol[jj], ap, BLOOD, BLOOD, IRON, 0.7, 0.7, 0, nil, "s")
					else
						hk:Face3(ol[jj], ol[i], ap, BLOOD, BLOOD, IRON, 0.7, 0.7, 0, nil, "s")
					end
				end
			end
			n += sc:Add(hk:Finish())
		end
		return n
	end

	--- Light Lance's impact: five short horn spikes erupt from the target round the hit, curving back toward the caster;
	--- longer at the full-ramp payoff (big 0..1). 2 parts (the kit counts 5).
	function Forge.HitHorns(sc, hit, d, u, big)
		if u <= 0.01 then return 0 end
		local h = sc:Get("HitHorns")
		local cf = chainFrame(hit, d)
		h:GlowLevel(0.5 + 0.5 * big)
		local uq = floor(clamp(u, 0, 1) * 128 + 0.5) / 128
		if h:Same(uq, big) then return sc:Add(h:Place(cf)) end
		h:Begin(cf, true)
		local dl, upl, s2l = Vector3.new(0, 0, -1), Vector3.yAxis, Vector3.xAxis
		local L_ = (0.55 + 0.4 * big) * ease("Back", uq)
		G_R0.K = 1
		for j = 0, 4 do
			local a = TAU * j / 5 + 0.35
			local e = upl * cos(a) + s2l * sin(a)
			local b0 = -dl * 0.12 + e * 0.22
			PTS[1], PTS[2], PTS[3] = b0, b0 + e * (L_ * 0.55) - dl * (L_ * 0.35), b0 + e * (L_ * 0.8) - dl * (L_ * 0.8)
			RADS[1], RADS[2], RADS[3] = 0.11, 0.07, 0.035
			h:Tube(PTS, 3, RADS, e, C_IB1, G_R0, 6, b0 + e * (L_ * 0.9) - dl * (L_ * 1.15))
		end
		return sc:Add(h:Finish())
	end

end

----------------------------------------------------------------------------------------------------
-- POSITION TRADE: the maw
----------------------------------------------------------------------------------------------------
do
	local T_CAGE0, T_CAGE1, D0, T_SWAP, R1 = 0.10, 0.13, 0.24, 0.36, 0.48
	local T_DIS0, T_DIS1 = R1 + 0.03, 0.32
	local MAW_RIM = {}
	local SPARK_MAW = { n = 4, seed = 41, level = 1.0, size = 0.1, life = 0.5, t0 = D0, t1 = R1, drift = UP * 1.4,
		tag = nil }

	--- Position Trade: a FANGED MAW on the floor under a body (c = the floor point; t = the Trade's clip time, the
	--- Blender seconds) -- a jagged pit glowing crimson inside, 7 low teeth (fb1) -- and three claws (fb1) that rise round the
	--- body, close on it at the flash (0.24), sink with it, rise at the swapped spot, open to release it (0.48) and sink;
	--- the maw closes (0.51-0.83). Embers boil up out of it while the bodies are in it (on sc's canvas). 2 parts.
	function Forge.Maw(sc, id, c, t)
		local u = ramp(t, T_CAGE0, T_CAGE1 + 0.06)
		local cl = ramp(t, T_DIS0, T_DIS1)
		if u <= 0 or cl >= 1 then return 0 end
		local k = u * (1 - cl)
		local R = 1.45 * k
		local hh, curl
		if t < D0 then
			hh, curl = ramp(t, 0.08, D0 - 0.08), 0.3 + 0.7 * ramp(t, D0 - 0.06, 0.06)
		elseif t < T_SWAP then
			hh, curl = 1 - ramp(t, D0, T_SWAP - D0), 1
		elseif t < R1 then
			hh, curl = ramp(t, T_SWAP, R1 - T_SWAP), 1
		else
			hh, curl = 1 - ramp(t, R1 + 0.12, 0.25), 1 - 0.8 * ramp(t, R1, 0.1)
		end
		local seed = (type(id) == "number") and id or #tostring(id) * 31 + string.byte(tostring(id), -1)
		local h = sc:Get("Maw", id)
		h:Begin(CFrame.new(c), false)
		local lift = UP * Config.FloorLift
		local n = 18
		for i = 0, n - 1 do
			local jag = 1 + 0.14 * uni(seed, i, 1, -1, 1)
			MAW_RIM[i + 1] = c + hdir(TAU * i / n) * (R * jag) + lift
		end
		local cen = c + lift
		for i = 1, n do
			local j = i % n + 1
			h:Face3(cen, MAW_RIM[i], MAW_RIM[j], ASH, ASH, ASH, 0.6, 0, 0, UP)
		end
		for i = 0, 6 do                                             -- the teeth ((fb1) 14 -> 7, one low height)
			local e = hdir(TAU * i / 7 + 0.1)
			local b0 = c + e * (R * 1.02)
			local th = 0.3 * k
			PTS[1], PTS[2] = b0 - UP * 0.05, b0 - e * (R * 0.06) + UP * (th * 0.45)
			RADS[1], RADS[2] = 0.13 * k, 0.08 * k
			h:Tube(PTS, 2, RADS, e, C_IB1, nil, 5, b0 - e * (R * 0.2) + UP * th)
		end
		if hh > 0.02 then                                           -- the claws
			for j = 0, 2 do                                         -- (fb1) 4 -> 3 claws, thinner (0.21 -> 0.14)
				local e = hdir(TAU * j / 3 + 0.4)
				local zo = -(1 - hh) * 1.2
				local P1, P2 = c + e * 1.35 + UP * (-0.5 + zo), c + e * 1.7 + UP * (2.0 * hh + zo)
				local P3 = c + e * (1.6 - 0.5 * curl) + UP * (3.6 * hh + zo)
				local P4 = c + e * (1.25 - 0.8 * curl) + UP * ((4.3 - 0.4 * curl) * hh + zo)
				for m = 0, 8 do
					PTS[m + 1] = bez3(P1, P2, P3, P4, m / 8)
					RADS[m + 1] = 0.14 * (1 - m / 9) ^ 0.7
				end
				h:Tube(PTS, 9, RADS, e, C_IB2, G_CLAW, 6, P4 + (P4 - P3).Unit * 0.18)
			end
		end
		if sc.Cv and t >= D0 and t <= R1 + 0.1 then                -- embers boil up out of the maw while the bodies are in it
			SPARK_MAW.seed, SPARK_MAW.tag = 41 + seed, sc.Tag
			sc.Cv:Sparkles(c + UP * 0.4, 0.7, t, SPARK_MAW)
		end
		return sc:Add(h:Finish())
	end

end

----------------------------------------------------------------------------------------------------
-- BENEDICTION: the ground (hell_ground, pass 4), the cracks, the column, its chains, the gate, the threads
----------------------------------------------------------------------------------------------------
do
	local B_PLANT, B_RET, B_TRAVEL = 0.44, 0.32, 0.15      -- benediction_r3's T_PLANT, RET, TRAVEL
	-- (owner, 2026-10-13: "scale down the lower part") the ground -- pit, claws, slabs, rubble, chips, the caster's horn
	-- ring -- drawn at this size about the plant (the horns about the caster); the cracks start at the smaller rim and still
	-- run out to the allies' feet. One number to tune.
	local BENE_GROUND_SCALE = 0.7
	local PIT_N = 30
	local PIT_RIM, PIT_RIM0, PIT_W = {}, {}, {}
	local PIT_RINGS = { {}, {}, {} }
	local PIT_F = { { 0.82 }, { 0.6 }, { 0.42 } }

	--- _pit_shape: the torn rim -- an uneven radius all round, pulled in toward the kneeling caster (they keep solid
	--- ground) -> PIT_RIM0 (on the floor), PIT_W (the pull, 0 away from the caster .. 1 toward)
	local function pitShape(c, caster, R0)
		local dc = caster - c
		local thc = atan2(dc:Dot(EY), dc:Dot(EX))
		for i = 0, PIT_N - 1 do
			local jag = 1 + 0.22 * uni(77, i, 1, -1, 1)
			if i % 3 == 1 then jag *= 1.18 end                         -- torn spurs
			local a = TAU * i / PIT_N
			local w = max(0, cos(a - thc)) ^ 2
			PIT_RIM0[i + 1] = c + hdir(a) * (R0 * jag * (1 - 0.86 * w))
			PIT_W[i + 1] = w
		end
		return thc
	end

	local SLAB_F = { { 0, 1, 3, 2 }, { 4, 6, 7, 5 }, { 0, 4, 5, 1 }, { 2, 3, 7, 6 }, { 1, 5, 7, 3 }, { 0, 2, 6, 4 } }
	local SLAB_C = {}
	local SPARK_SHAFT = { n = 3, seed = 171, level = 1.0, size = 0.09, life = 0.35, t0 = 0, t1 = 0, drift = UP * 3.0,
		region = nil, tag = nil }

	--- Benediction's ground (pass 4): the floor TORN OPEN round the planted trident -- a jagged pit ~2.3 studs, its
	--- sloped walls (drawn flattened on the floor: the floor cannot be cut), crimson glow at the bottom, a torn lip with
	--- large fangs (none on the caster's side), the rock stump under the staff; five black-iron claws gripping the rim
	--- from below; broken slabs heaved up round it; rubble bursting out, landing and settling; ember chips streaking up
	--- off the rim; 8 horn spikes round the caster. It all drops back and the pit seals at the end.
	--- ctx {Plant = the floor point under the staff, Caster = the floor under the caster, TOff = the channel's end (clip
	--- s; 1e6 while held), TPlant = 0.44, Ret = 0.32}. Up to 10 parts (the kit counts 34).
	function Forge.HellGround(sc, t, ctx)
		local c, caster = ctx.Plant, ctx.Caster or ctx.Plant
		local TP, OFF, RET = ctx.TPlant or B_PLANT, ctx.TOff or 1e6, ctx.Ret or B_RET
		local op = ramp(t, TP, 0.16, "Linear") * (1 - ramp(t, OFF + RET - 0.05, 0.3))
		if op <= 0.01 then return 0 end
		local GS = ctx.Scale or BENE_GROUND_SCALE         -- every ground piece below is drawn at this size about its origin
		local R0 = 2.3 * ease("Quint", op)
		local thc = pitShape(c, caster, R0)
		local n = PIT_N
		local k = op
		local fang = ease("Back", clamp(op * 1.2, 0, 1))
		local cf0 = CFrame.new(c)
		local total = 0
		-- the pit: funnel bands, the throat, the torn lip, the fangs, the stump
		local h = sc:Get("BenePit")
		if h:Same(op, fang, c.X, c.Y, c.Z, thc) then
			total += sc:Add(h:Place(cf0, GS))
		else
			h:Begin(cf0, false)
			local lift = Config.FloorLift
			for i = 1, n do PIT_RIM[i] = PIT_RIM0[i] + UP * lift end
			for li = 1, 3 do
				local f, z = PIT_F[li][1], lift + Config.PitBands[li]
				local ring = PIT_RINGS[li]
				for i = 1, n do ring[i] = c + (PIT_RIM0[i] - c) * f + UP * z end
			end
			local bot = c + UP * (lift + 0.036)
			local prev = PIT_RIM
			for li = 0, 2 do
				local ring = PIT_RINGS[li + 1]
				-- (fb1) the red ring a little brighter at the top of the walls (0.12 -> 0.24; the throat unchanged)
				local g0, g1 = 0.24 + 0.26 * li, min(1, 0.24 + 0.26 * (li + 1))
				for i = 1, n do
					local j = i % n + 1
					h:Quad(prev[i], prev[j], ring[j], ring[i], STONE, STONE, ASH, ASH, g0, g0, g1, g1, UP)
				end
				prev = ring
			end
			for i = 1, n do
				local j = i % n + 1
				h:Face3(prev[i], prev[j], bot, ASH, ASH, ASH, 1, 1, 1, UP)
			end
			for i = 0, n - 1 do                                      -- the torn lip, outside the rim
				local j = (i + 1) % n
				local ri, rj = PIT_RIM0[i + 1], PIT_RIM0[j + 1]
				local ei, ej = unit(ri - c, EX), unit(rj - c, EX)
				local hi = 0.28 + 0.22 * ((i * 7) % 5) / 4
				local hj = 0.28 + 0.22 * ((j * 7) % 5) / 4
				local ci, cj = ri + ei * 0.25 + UP * (hi * k), rj + ej * 0.25 + UP * (hj * k)
				local fi, fj = ri + ei * 0.75, rj + ej * 0.75
				h:Quad(PIT_RIM[i + 1], PIT_RIM[j + 1], cj, ci, STONE, STONE, STONE, STONE, 0, 0, 0, 0, UP, "s")
				h:Quad(ci, cj, fj, fi, STONE_HI, STONE_HI, STONE_HI, STONE_HI, 0, 0, 0, 0, UP, "s")
			end
			G_R0.K = 0.6
			for i = 0, n - 1, 2 do                                   -- the fangs on the lip (none on the caster's side)
				if PIT_W[i + 1] <= 0.25 then
					local ri = PIT_RIM0[i + 1]
					local e = unit(ri - c, EX)
					local b0 = ri + e * 0.2 + UP * (0.2 * k)
					local H = ((floor(i / 2) % 2 == 1) and 2.4 or 1.7) * fang
					PTS[1], PTS[2], PTS[3] = b0 - UP * 0.4, b0 - e * (0.1 * H) + UP * (H * 0.45), b0 - e * (0.32 * H) + UP * (H * 0.8)
					RADS[1], RADS[2], RADS[3] = 0.3, 0.2, 0.11
					h:Tube(PTS, 3, RADS, e, C_IB15, G_R0, 6, b0 - e * (0.5 * H) + UP * H)
				end
			end
			G_R0.K = 1
			PTS[1], PTS[2] = c - UP * 0.3, c + UP * Config.SpurTop        -- the rock the trident stands on
			RADS[1], RADS[2] = 0.42, 0.2
			h:Tube(PTS, 2, RADS, EX, STONE, nil, 6)
			total += sc:Add(h:Finish(GS))
		end
		-- the claws: five black-iron hands gripping the rim from below (three talons each)
		local gr = ease("Back", ramp(t, TP + 0.12, 0.3)) * (1 - ramp(t, OFF, 0.25))
		if gr > 0.02 then
			local hc = sc:Get("BeneClaws")
			if hc:Same(gr, op, c.X, c.Y, c.Z, thc) then
				total += sc:Add(hc:Place(cf0, GS))
			else
				hc:Begin(cf0, false)
				local done = 0
				for i = 1, n - 1, 6 do
					if PIT_W[i + 1] <= 0.2 and done < 5 then
						done += 1
						local ri = PIT_RIM0[i + 1]
						local e = unit(ri - c, EX)
						local tg = UP:Cross(e)
						local kn = ri - e * 0.55 - UP * 1.1
						for f_ = -1, 1 do
							local o = tg * (0.26 * f_)
							local P1, P2 = kn + o * 0.6, ri + o - e * 0.1 + UP * (0.15 + 0.3 * gr)
							local P3 = ri + o + e * (0.25 * gr) + UP * (0.42 * gr)
							local P4 = ri + o + e * (0.25 + 0.35 * gr) + UP * 0.03
							for m = 0, 7 do
								PTS[m + 1] = bez3(P1, P2, P3, P4, m / 7)
								RADS[m + 1] = 0.16 * (1 - m / 8) ^ 0.6
							end
							hc:Tube(PTS, 8, RADS, e, C_IB3, G_BCLAW, 6, P4 + (P4 - P3).Unit * 0.16)
						end
					end
				end
				total += sc:Add(hc:Finish(GS))
			end
		end
		-- the slabs: broken plates heaved up and tilted outward round the pit (none on the caster's side)
		local hv = ease("Back", ramp(t, TP + 0.02, 0.22)) * (1 - ramp(t, OFF + RET, 0.3))
		if hv > 0.02 then
			local hs = sc:Get("BeneSlabs")
			if hs:Same(hv, op, c.X, c.Y, c.Z, thc) then
				total += sc:Add(hs:Place(cf0, GS))
			else
				hs:Begin(cf0, false)
				local m_ = 0
				for i = 0, n - 1, 3 do
					if PIT_W[i + 1] <= 0.15 and m_ < 9 then
						m_ += 1
						local ri = PIT_RIM0[i + 1]
						local e = unit(ri - c, EX)
						local tg = UP:Cross(e)
						local tilt = rad(26 + 24 * ((i * 37) % 5) / 4) * hv
						local ce = ri + e * 1.15 + UP * (0.22 * hv - 0.18)
						local up_ = UP * cos(tilt) - e * sin(tilt)
						local fw = e * cos(tilt) + UP * sin(tilt)
						local w_, l_, h_ = 0.7 + 0.15 * (i % 3), 0.6 + 0.1 * (i % 2), 0.17
						local q = 0
						for sz = -1, 1, 2 do
							for sy = -1, 1, 2 do
								for sx = -1, 1, 2 do
									SLAB_C[q] = ce + tg * (sx * w_) + fw * (sy * l_) + up_ * (sz * h_)
									q += 1
								end
							end
						end
						for fi, f in ipairs(SLAB_F) do
							local col = (fi == 2) and STONE_HI or STONE
							local g = (fi == 3) and 0.55 or 0
							hs:Quad(SLAB_C[f[1]], SLAB_C[f[2]], SLAB_C[f[3]], SLAB_C[f[4]], col, col, col, col, g, g, g, g)
						end
					end
				end
				total += sc:Add(hs:Finish(GS))
			end
		end
		-- rubble: bursts out on the eruption (ballistic, g = 70), lands and settles; sinks away at the end
		local tr = t - TP
		local sinkR = ramp(t, OFF + RET, 0.3)
		if tr > 0 and sinkR < 1 then
			local hr = sc:Get("BeneRubble")
			local trq = min(tr, 0.56)
			if hr:Same(trq, sinkR, op, c.X, c.Y, c.Z) then
				total += sc:Add(hr:Place(cf0, GS))
			else
				hr:Begin(cf0, false)
				for i = 0, 9 do
					local e = hdir(uni(5, i, 1, 0, TAU))
					local vOut, vUp, sz = uni(5, i, 2, 4, 9), uni(5, i, 3, 11, 17), uni(5, i, 4, 0.22, 0.42)
					local tLand = (vUp + sqrt(vUp * vUp + 4 * 35 * 0.5)) / 70
					local tt = min(tr, tLand)
					local p = c + e * (R0 + 0.3 + vOut * tt) + UP * (max(sz * 0.8, 0.5 + vUp * tt - 35 * tt * tt) - sz * 1.6 * sinkR)
					hr:Ico(p, sz, STONE, 0.4, 0.4)
				end
				total += sc:Add(hr:Finish(GS))
			end
		end
		-- ember chips streaking up off the rim (pieces, not sparkles: the kit's sparkle budget is spent)
		if t > TP and t < OFF + 0.2 then
			local hp = sc:Get("BeneChips")
			hp:Begin(cf0, false)
			for i = 0, 7 do
				local j = floor(uni(9, i, 1, 0, n - 1e-6))
				if PIT_W[j + 1] > 0.3 then j = (j + floor(n / 2)) % n end
				local u = (uni(9, i, 2, 0, 1) + (t - TP) * 1.5) % 1
				local rj = PIT_RIM0[j + 1]
				local p = rj + unit(rj - c, EX) * (0.15 * u) + UP * (5 * u ^ 0.65)
				local L = 0.35 + 0.5 * (1 - u)
				local sd = unit(UP:Cross(camDir(p)), EX) * 0.06
				local hot = 1.2 - u
				hp:Face3(p - sd, p + sd, p + UP * (L * 0.15), BLOOD, BLOOD, BLOOD, hot, hot, hot, true, "g")
				hp:Face3(p - sd, p + UP * L, p + sd, ASH, ASH, ASH, hot, 0, hot, true, "g")
			end
			total += sc:Add(hp:Finish(GS))
		end
		-- 8 horn spikes round the caster
		local hk = ease("Back", ramp(t, TP, 0.25)) * (1 - ramp(t, OFF + 0.1, 0.3))
		if hk > 0.02 then
			local hh = sc:Get("BeneHorns")
			local cfc = CFrame.new(caster)
			if hh:Same(hk, caster.X, caster.Y, caster.Z) then
				total += sc:Add(hh:Place(cfc, GS))
			else
				hh:Begin(cfc, false)
				G_R0.K = 0.8
				for j = 0, 7 do
					local e = hdir(TAU * j / 8 + 0.2)
					local b0 = caster + e * 4.6 - UP * 0.1
					local H = ((j % 2 == 1) and 1.5 or 1.1) * hk
					PTS[1], PTS[2] = b0, b0 + e * (0.15 * H) + UP * (H * 0.55)
					RADS[1], RADS[2] = 0.2 * hk, 0.12 * hk
					hh:Tube(PTS, 2, RADS, e, C_IB1, G_R0, 6, b0 + e * (0.45 * H) + UP * H)
				end
				G_R0.K = 1
				total += sc:Add(hh:Finish(GS))
			end
		end
		return total
	end

	--- _crack_paths (pass 4): 7 jagged cracks out of the pit; one runs to each bonded ally's feet (up to 7), the rest
	--- round them. Seeded, cached per plant + allies.
	-- (2026-10-19, audit P5C-18) one entry PER PLANT (up to 4, newest first), compared without building a string: two
	-- Devil Benedictions at once (2v2, Squad Clash) no longer rebuild both crack sets every frame
	local crackCache = {}                                -- { { C, G, A = ally points, Paths } }
	local function crackPaths(c, allies, gs)
		for _, e in ipairs(crackCache) do
			if e.C == c and e.G == gs and #e.A == #allies then
				local same = true
				for i, a in ipairs(allies) do
					local b = e.A[i]
					if abs(a.X - b.X) > 0.05 or abs(a.Z - b.Z) > 0.05 then
						same = false
						break
					end
				end
				if same then return e.Paths end
			end
		end
		local out = {}
		local nA = min(#allies, 7)
		for k = 1, 7 do
			local a0, da
			if k <= nA then
				local v = allies[k] - c
				a0, da = atan2(v:Dot(EY), v:Dot(EX)), Vector3.new(v.X, 0, v.Z).Magnitude
			else
				a0 = uni(19, k, 1, 0, TAU)
			end
			local r0 = 2.2 * gs                                                    -- the (scaled) rim
			local L = da and (da - 0.6 - r0) or uni(19, k, 2, 4.5, 8.5) * gs
			local nseg = (L >= 0) and floor(L / 0.7) or -floor(-L / 0.7)          -- int(): toward zero
			local pts, a = {}, a0
			for m = 0, nseg + 1 do
				local dist = r0 + m * 0.7
				a += uni(19, k, 10 + m, -0.16, 0.16) * (da and 0.35 or 1)
				pts[#pts + 1] = { c + hdir(a) * dist, dist }
			end
			out[k] = pts
		end
		table.insert(crackCache, 1, { C = c, G = gs, A = table.clone(allies), Paths = out })
		crackCache[5] = nil
		return out
	end

	--- Benediction: jagged cracks across the floor out of the pit -- a broken band glowing dim crimson inside (fb1; was
	--- plain stone) with a crimson seam (Neon); on
	--- each pulse a flare runs out along them toward the allies (24 studs/s); they fade and close at the end.
	--- uc = the frame's crack draw (benediction: ramp(t, T_PLANT, 0.09, "Linear") x (1 - ramp(t, OFF + 0.1, 0.22))).
	--- ctx {Plant, Allies = floor points of the bonded allies, TOff, Ret = 0.32, Arr = pulse arrival clip times,
	--- Travel = 0.15}. 2 parts (the kit counts 1).
	function Forge.HellCracks(sc, t, uc, ctx)
		if uc <= 0.01 then return 0 end
		local OFF, RET, TRAVEL = ctx.TOff or 1e6, ctx.Ret or B_RET, ctx.Travel or B_TRAVEL
		local seal = 1 - ramp(t, OFF + RET, 0.3)
		if seal <= 0.01 then return 0 end
		local c = ctx.Plant
		local gs = ctx.Scale or BENE_GROUND_SCALE
		local paths = crackPaths(c, ctx.Allies or {}, gs)
		local arr = ctx.Arr or {}
		local h = sc:Get("BeneCracks")
		h:Begin(CFrame.new(c), false)
		local lift = Config.FloorLift
		local cIn = disp(CRACK_IN + EMBER_DIM * Config.EmitGain)       -- (fb1) the band glows dim crimson inside
		for _, path in ipairs(paths) do
			local np = #path
			local reach = 2.4 * gs + (path[np][2] - 2.4 * gs) * uc
			for i = 1, np - 1 do
				local A, Bp = path[i], path[i + 1]
				if Bp[2] > reach then break end
				local a, b, da = A[1], Bp[1], A[2]
				local dv = unit(b - a, EX)
				local sd = UP:Cross(dv)
				local taper = max(0.18, 1.25 - da / 9) * seal
				local fl = 0.6                                          -- (fb1) base 0.45 -> 0.6
				for _, ta in ipairs(arr) do
					local w = (t - (ta - TRAVEL)) * 24
					if w > 0 and w < 40 then fl += 1.4 * exp(-((da - w) / 1.4) ^ 2) end
				end
				local w1, w2 = 0.24 * taper, 0.1 * taper                -- (fb1) the inner seam wider (0.08 -> 0.1)
				local z1, z2 = UP * (lift + 0.012), UP * (lift + 0.018)
				squad(h, a - sd * w1 + z1, b - sd * w1 + z1, b + sd * w1 + z1, a + sd * w1 + z1, cIn)
				gquad(h, a - sd * w2 + z2, b - sd * w2 + z2, b + sd * w2 + z2, a + sd * w2 + z2, min(1.6, fl))
			end
		end
		return sc:Add(h:Finish())
	end

	-- the column (hell_column, the pass-1 tell's width) and its frame
	local COL_Z = { -0.3, 0.0, 0.4, 0.9, 1.5, 2.3, 3.3, 4.6, 6.2, 8.5, 12.0, 18.0, 30.0, 50.0, 80.0, 115.0, 150.0 }
	local COL_N = 16
	local colRings, colZs, colK = {}, {}, {}

	local function colWidth(z)                       -- the pass-1 tell: col_w(z) x 1.35 x 2.6 (a diameter)
		return (0.14 + 0.0065 * max(0, z)) * 1.35 * 2.6
	end

	--- the frame the column's forms draw in: origin base, Y up the base -> top axis, turned `spin` about it
	local function columnCF(base, top, spin)
		local axis = unit(top - base, UP)
		return CFrame.new(base) * upTo(axis) * CFrame.Angles(0, spin, 0)
	end

	--- a horizontal direction in the column frame (local), the kit's angle convention
	local function lhdir(a)
		return EX * cos(a) + EY * sin(a)
	end

	local function surgeAt(z, surges)
		local s = 0
		if surges then
			for _, zc in ipairs(surges) do s += 1.3 * exp(-((z - zc) / 7) ^ 2) end
		end
		return s
	end

	--- Benediction's column (hell_column): a solid near-black column from the pit's depths (base, PIT_D under the
	--- floor) to the gate (top), thick at the base, widening up to the gate; crimson veins climbing and twisting up it,
	--- densest and brightest over the pit (vertex colours); its vein crests three Neon seam strips; surges (heights over
	--- the floor: up01(t, tp - 0.45, tp) ^ 1.6 x top height, per pulse) brighten a band climbing it. The veins turn with
	--- the part (-3 rad/s about the axis). wfun(z) = the diameter at z over the base (default the pass-1 tell's). 2 parts.
	function Forge.HellColumn(sc, base, top, t, surges, wfun)
		local H = top.Y - base.Y
		if H < 0.3 then return 0 end
		wfun = wfun or colWidth
		local h = sc:Get("Column", nil, 210)
		local cf = columnCF(base, top, -3 * t)
		h:Begin(cf, true)
		local ratio = (top - base).Magnitude / H
		local nz = 0
		for _, z in ipairs(COL_Z) do
			if z < H - 0.2 then
				nz += 1
				colZs[nz] = z
			end
		end
		nz += 1
		colZs[nz] = H
		local vg = Config.VeinGain
		for r = 1, nz do
			local z = colZs[r]
			local w = wfun(z) * 0.5
			local y = (z >= 0) and z * ratio or z
			local ring = colRings[r]
			if not ring then
				ring = {}
				colRings[r] = ring
			end
			local kc = colK[r]
			if not kc then
				kc = {}
				colK[r] = kc
			end
			local near = 0.12 + 0.95 * exp(-max(z, 0) / 4)
			local sg = surgeAt(z, surges)
			for i = 0, COL_N - 1 do
				local th = TAU * i / COL_N
				ring[i + 1] = lhdir(th) * w + Vector3.new(0, y, 0)
				local vein = max(0, cos(3 * (th - 0.12 * z))) ^ 6
				local kk = min(1.4, vein * near + 0.02 + 0.5 * sg * (0.4 + vein))
				kc[i + 1] = disp(ASH + SEAM * (kk * vg))
			end
		end
		for r = 1, nz - 1 do
			local ra, rb, ka, kb = colRings[r], colRings[r + 1], colK[r], colK[r + 1]
			for i = 1, COL_N do
				local j = i % COL_N + 1
				put(h, h.S, ra[i], ra[j], rb[j], ka[i], ka[j], kb[j])
				put(h, h.S, ra[i], rb[j], rb[i], ka[i], kb[j], kb[i])
			end
		end
		-- the vein crests as Neon seams: local angle 0.12 z + 2 pi m / 3, sampled finely enough for the twist
		for m = 0, 2 do
			local pl, pr = nil, nil
			local z = -0.3
			while true do
				local w = wfun(z) * 0.5
				local y = (z >= 0) and z * ratio or z
				local th = 0.12 * z + TAU * m / 3
				local e = lhdir(th)
				local tgd = lhdir(th + pi / 2)
				local q = e * (w * 1.015) + Vector3.new(0, y, 0)
				local hw = max(0.02, w * 0.07)
				local L_, R_ = q - tgd * hw, q + tgd * hw
				local near = 0.12 + 0.95 * exp(-max(z, 0) / 4)
				local kk = min(1.4, near + 0.02 + 0.7 * surgeAt(z, surges))
				if pl then
					local g0, g1 = glowCol(pl.k), glowCol(kk)
					put(h, h.G, pl.L, pl.R, R_, g0, g0, g1)
					put(h, h.G, pl.L, R_, L_, g0, g1, g1)
				else
					pl = {}
				end
				pl.L, pl.R, pl.k = L_, R_, kk
				if z >= H then break end
				z = min(H, z + ((z < 12) and 0.6 or 2.5))
			end
		end
		return sc:Add(h:Finish())
	end

	-- the spiral chains (pass 1, static): the links' local geometry once, then slots shown as the column grows
	local SPIRAL = nil
	local function colR(z) return 0.40 + 0.024 * max(0, z) end
	local function spiralPt(z, ph)
		local a = ph + ((z < 20) and TAU * z / 7 or TAU * (20 / 7 + (z - 20) / 30))
		return lhdir(a) * (colR(z) * 1.25 + 0.3) + Vector3.new(0, z, 0)
	end
	local function spiralLinks()
		if SPIRAL then return SPIRAL end
		SPIRAL = { {}, {} }
		for k = 0, 1 do
			local ph = pi * k
			local z, j = 0.4, 0
			while z < 14.0 do
				local p = spiralPt(z, ph)
				local tg = (spiralPt(z + 0.05, ph) - spiralPt(z - 0.05, ph)).Unit
				local ax = (j % 2 == 1) and tg:Cross(UP).Unit or (UP - tg * tg:Dot(UP)).Unit
				table.insert(SPIRAL[k + 1], { Z = z, P = p, T = tg, A = ax, J = j })
				z += 0.55 * max(0.15, abs(tg.Y))
				j += 1
			end
		end
		return SPIRAL
	end
	local SPIRAL_MAX = 40
	local SEAM_PTS = {}

	--- (fb1) the ember seam's point at height z on chain phase ph (column frame; camL = the camera in it): through the
	--- links' holes up to 12 studs, easing out by 14 onto the cable's viewer-facing face (0.85 x its radius)
	local function seamPt(z, ph, camL)
		local p = spiralPt(z, ph)
		local off = (0.1 + 0.005 * z) * 0.85 * clamp((z - 12) / 2, 0, 1)
		if off <= 0 then return p end
		return p + unit(camL - p, EX) * off
	end

	--- Benediction: two barbed chains spiralling up the column (pass 1: static links from 0.4 to 14 studs over the base,
	--- a heavy chain cable above); the PART turns with the chains (+0.6 rad/s), links appear as the column rises past
	--- them. (fb1) A thin crimson EMBER SEAM threads through the links and up the cable's viewer-facing face (all four
	--- faces lit), and 4 ember motes a chain rise along it. 7 parts (the kit: 2 chain-textured Beams).
	function Forge.SpiralChains(sc, base, top, t)
		local H = top.Y - base.Y
		if H < 0.5 then return 0 end
		local cf = columnCF(base, top, 0.6 * t)
		local camL = cf:PointToObjectSpace(camP)
		local SP = spiralLinks()
		local h = sc:Get("ColumnChains", nil, 18)
		h:Edit(cf, true)
		local lim = min(14.0, H - 0.3)
		for k = 1, 2 do
			for j = 1, SPIRAL_MAX do
				local L = SP[k][j]
				local want = (L and L.Z < lim) and 1 or 0
				local slot = (k - 1) * SPIRAL_MAX + j
				local had = h.SlotSig[slot]
				if had ~= want then
					h.SlotSig[slot] = want
				end
				if had ~= want and not (had == nil and want == 0) then
					local s0, g0 = (slot - 1) * LINK_SLOT_S, (slot - 1) * LINK_SLOT_G
					h:Seek(s0, g0)
					if want ~= 0 then
						link(h, L.P, L.T, L.A, 0.37, 0.15, 0.05, 0.6, IRON)
						if L.J % 3 == 1 then barbs(h, L.P, L.T, L.A, 0.15, 1) end
					end
					h:Pad(s0 + LINK_SLOT_S, g0 + LINK_SLOT_G)
				end
			end
		end
		h:SetCount(2 * SPIRAL_MAX * LINK_SLOT_S, 2 * SPIRAL_MAX * LINK_SLOT_G)
		local n = sc:Add(h:Finish())
		-- (fb1) the ember motes rising along the seam (4 a chain, camera-facing kites; their own small form: up to 120
		-- studs, past the links' box)
		local hm = sc:Get("ColumnMotes", nil, 155)
		hm:Begin(cf, true)
		local Hm = min(H, 120)
		for k = 0, 1 do
			for m = 0, 3 do
				local u = ((m + 0.37 * k) / 4 + t * 0.35) % 1
				local z = 0.6 + (Hm - 1) * u ^ 1.6
				if z <= H - 0.5 then
					local p = seamPt(z, pi * k, camL)
					local s = 0.07 + 0.006 * z
					local sd = unit(UP:Cross(unit(camL - p, EX)), EX) * s
					local hot = 0.85 * (1 - 0.45 * u)
					hm:Quad(p - UP * s, p + sd, p + UP * (s * 2.6), p - sd, ASH, ASH, ASH, ASH, hot, hot, hot, hot, true)
				end
			end
		end
		n += sc:Add(hm:Finish())
		-- the cable above (H > 14.5) and (fb1) the seam: one form, re-forged as H moves, or (the seam over 12 studs
		-- rides the side facing the camera) once the camera has swung ~8 deg round the column in its turning frame
		local Hq = floor(H * 4 + 0.5) / 4
		local cab = H > 14.5
		local q = min(13.6, Hq - 0.8) / 0.35
		local nz = (q >= 0) and floor(q) or 0                    -- the seam's link-zone points 0..nz (the kit's int())
		if not cab and nz < 1 then return n end
		local hc = sc:Get("ColumnCable", nil, 200)
		local camOK = true
		if Hq > 12 then
			local ref = hc.SeamCam
			local d = (camL - Vector3.new(0, clamp(camL.Y, 0, Hq), 0)).Magnitude
			camOK = ref ~= nil and (camL - ref).Magnitude <= max(0.3, 0.14 * d)
		end
		if hc:Same(Hq, cab) and camOK then return n + sc:Add(hc:Place(cf)) end
		hc.SeamCam = camL
		hc:Begin(cf, true)
		local mz = floor(max(0, Hq - 14) / 3)
		if cab then
			G_R0.K = 0.6
			for k = 0, 1 do
				local cnt = 0
				for m = 0, mz do
					cnt += 1
					local z = 14 + 3 * m
					PTS[cnt], RADS[cnt] = spiralPt(z, pi * k), 0.1 + 0.005 * z
				end
				if Hq - (14 + 3 * mz) > 1e-3 then
					cnt += 1
					PTS[cnt], RADS[cnt] = spiralPt(Hq, pi * k), 0.1 + 0.005 * Hq
				end
				hc:Tube(PTS, cnt, RADS, UP, IRON, G_R0, 5)
			end
			G_R0.K = 1
		end
		local zl = 0.4 + 0.35 * nz
		for k = 0, 1 do                                              -- (fb1) the seam: a dark thread, 4 lit faces
			local cnt = 0
			for m = 0, nz do
				local z = 0.4 + 0.35 * m
				cnt += 1
				SEAM_PTS[cnt], RADS[cnt] = seamPt(z, pi * k, camL), 0.034 + 0.0026 * max(0, z - 12)
			end
			if cab then
				for m = 0, mz do
					local z = 14 + 3 * m
					if z > zl + 0.2 then
						cnt += 1
						SEAM_PTS[cnt], RADS[cnt] = seamPt(z, pi * k, camL), 0.034 + 0.0026 * (z - 12)
					end
				end
				if Hq - (14 + 3 * mz) > 1e-3 then
					cnt += 1
					SEAM_PTS[cnt], RADS[cnt] = seamPt(Hq, pi * k, camL), 0.034 + 0.0026 * (Hq - 12)
				end
			end
			if cnt > 1 then hc:Tube(SEAM_PTS, cnt, RADS, UP, ASH, G_SEAM4, 4) end
		end
		return n + sc:Add(hc:Finish())
	end

	--- Benediction's gate: the horned inverted-pentagram plate H_SKY up, facing down (R1 = SKY_R1 12, g = its open,
	--- pe = the pulse flare), turning 0.15 rad/s, and two great horns sweeping up off it. 4 parts.
	function Forge.Gate(sc, skyC, R1, g, pe, t)
		if g <= 0.01 then return 0 end
		local n = Forge.CarvedPlate(sc, "Gate", skyC, R1 * g, 0.15 * t, 0.5 + 0.5 * pe, 1.2, -UP)
		local h = sc:Get("GateHorns")
		h:GlowLevel(0.5 + 0.5 * pe)
		local cf = CFrame.new(skyC)
		if h:Same(R1) then return n + sc:Add(h:Place(cf, g)) end
		h:Begin(cf, true)
		G_R0.K = 1
		local R = R1
		for sg = 1, -1, -2 do
			local b0 = EX * (sg * R * 0.72)
			local P1, P2 = b0, b0 + EX * (sg * R * 0.45) + UP * (R * 0.55)
			local P3, P4 = b0 + EX * (sg * R * 0.30) + UP * (R * 1.25), b0 + EX * (-sg * R * 0.05) + UP * (R * 1.55)
			for m = 0, 8 do
				PTS[m + 1] = bez3(P1, P2, P3, P4, m / 8)
				RADS[m + 1] = 1.7 * (1 - m / 9) ^ 0.8
			end
			h:Tube(PTS, 9, RADS, EX * sg, C_IB2, G_R0, 7, P4 + (P4 - P3).Unit * 2.0)
		end
		return n + sc:Add(h:Finish(g))
	end

	--- Benediction: on each pulse a short barbed chain (4 links) and embers race up the planted staff's shaft into the
	--- head: butt / tip of the staff, arr = the pulses' arrival clip times (T_ARR), travel = 0.15. 2 parts.
	function Forge.ShaftSurge(sc, butt, tip, t, arr, travel)
		travel = travel or B_TRAVEL
		local ax = tip - butt
		local Ls = ax.Magnitude
		if Ls < 0.1 then return 0 end
		local d = ax / Ls
		local side = (abs(d.Y) < 0.99) and d:Cross(UP).Unit or EX
		local h = nil
		for _, ta in ipairs(arr) do
			local a_ = up01(t, ta - travel - 0.3, ta - travel)
			if a_ > 0 and a_ < 1 then
				if not h then
					h = sc:Get("ShaftChain")
					h:Begin(CFrame.new(butt), false)
				end
				local s0 = a_ * Ls
				for j = 0, 3 do
					local sj = s0 - j * 0.34
					if sj > 0 and sj < Ls then
						link(h, butt + d * sj + side * 0.14, d, (j % 2 == 1) and side or d:Cross(side), 0.24, 0.1, 0.03, 1.0, BLOOD)
					end
				end
				if sc.Cv then
					SPARK_SHAFT.t0, SPARK_SHAFT.t1, SPARK_SHAFT.tag = ta - travel - 0.3, ta - travel, sc.Tag
					SPARK_SHAFT.region = function(rnd) return butt + d * (s0 * (0.6 + 0.4 * rnd())) end
					sc.Cv:Sparkles(ZERO, 0, t, SPARK_SHAFT)
				end
			end
		end
		if not h then return 0 end
		return sc:Add(h:Finish())
	end

	local bondTpl = {}                               -- the bond link's two orientations (pitch 0.45)
	local SPARK_BOND = { n = 2, seed = 3, level = 1.0, size = 0.08, life = 0.6, t0 = 0, t1 = 1e9, drift = UP * 0.8,
		region = nil, tag = nil }

	--- Benediction's thread to an ally (chain_bond): a taut ember chain from the staff head (src) to the ally (dst),
	--- drawn on by u, its links SLIDING toward the ally at 3 studs/s (the heal travels to them); embers rise off it.
	--- The part slides (mod two links) and links show / hide at the ends. 2 parts (the kit: a scrolling chain Beam).
	function Forge.ChainBond(sc, id, src, dst, u, t)
		local lead = src:Lerp(dst, u)
		local L = (lead - src).Magnitude
		if L < 0.1 then return 0 end
		local d = unit(dst - src, UP)
		local pitch = 0.45
		local adv = t * 3
		local off = adv % pitch
		local off2 = adv % (2 * pitch)
		local cf = chainFrame(src + d * off2, d)
		local kMax = ceil(Config.BondMaxLen / pitch) + 1
		local h = sc:Get("PactChain", id, Config.BondMaxLen + 2)
		h:Edit(cf, true)
		local DL = Vector3.new(0, 0, -1)
		if not bondTpl[1] then
			for par = 0, 1 do
				local ax = (par == 0) and Vector3.yAxis or Vector3.xAxis
				bondTpl[par + 1] = capture(function(th)
					link(th, ZERO, DL, ax, pitch * 0.66, 0.1, 0.03, 0.85, mixl(IRON, BLOOD, 0.5))
				end)
			end
		end
		local kFirst = (off2 >= pitch) and -1 or 0
		for k = -1, kMax do
			local s = off2 + 0.2 + k * pitch
			local want = (k >= kFirst and s < L - 0.2) and 1 or 0
			slotFill(h, k + 2, LINK_S, LINK_G, want, bondTpl[(k % 2) + 1], DL * (0.2 + k * pitch))
		end
		h:SetCount((kMax + 2) * LINK_S, (kMax + 2) * LINK_G)
		if sc.Cv then
			SPARK_BOND.seed = 3 + (type(id) == "number" and id * 7 or 0)
			SPARK_BOND.tag = sc.Tag
			SPARK_BOND.region = function(rnd) return src:Lerp(lead, rnd()) end
			sc.Cv:Sparkles(ZERO, 0, t, SPARK_BOND)
		end
		return sc:Add(h:Finish())
	end

end

----------------------------------------------------------------------------------------------------
-- THE STROKES (RadiantDraw): pentagram, thorn star, ember brand, the devil bond, the heal, the clasp horns
----------------------------------------------------------------------------------------------------
do
	local CUT = {}
	--- the kit's _cut: the first fraction u (by length) of pts[1..n] into CUT -> count
	local function cut(pts, n, u)
		if u >= 1 then
			for i = 1, n do CUT[i] = pts[i] end
			return n
		end
		if u <= 0 then return 0 end
		local tot = 0
		for i = 2, n do tot += (pts[i] - pts[i - 1]).Magnitude end
		local goal, acc = tot * u, 0
		CUT[1] = pts[1]
		local k = 1
		for i = 2, n do
			local l = (pts[i] - pts[i - 1]).Magnitude
			if acc + l < goal then
				k += 1
				CUT[k] = pts[i]
				acc += l
			else
				k += 1
				CUT[k] = pts[i - 1]:Lerp(pts[i], (goal - acc) / max(l, 1e-9))
				break
			end
		end
		return k
	end

	local function trimTo(t, n)
		for i = #t, n + 1, -1 do t[i] = nil end
	end

	local STAR, STARQ = {}, {}
	local PENT_ORDER = { 1, 3, 5, 2, 4, 1 }            -- the kit's one stroke 0-2-4-1-3-0
	local O_PENT = { w = 0, n = UP, pieces = 2, tag = nil }
	local O_THORN = { w = 0, n = UP, pieces = 1, tag = nil }

	--- a five-point star (one continuous stroke 0-2-4-1-3-0), point down when inverted; draws on with u. 2 pieces.
	function Forge.Pentagram(cv, c, normal, R, level, o)
		local u = (o and o.u) or 1
		if u <= 0.01 or R < 0.02 then return end
		local ux, vx, nn = RD.basis(normal)
		local inv = not (o and o.inverted == false)
		local a0 = ((o and o.rot) or 0) + (inv and pi * 1.5 or pi * 0.5)
		for k = 0, 4 do STAR[k + 1] = c + (ux * cos(a0 + TAU * k / 5) + vx * sin(a0 + TAU * k / 5)) * R end
		for i = 1, 6 do STARQ[i] = STAR[PENT_ORDER[i]] end
		local n = cut(STARQ, 6, u)
		if n < 2 then return end
		trimTo(CUT, n)
		O_PENT.w = (o and o.w) or RD.lw(level)
		O_PENT.n, O_PENT.tag = nn, o and o.tag or nil
		cv:Stroke(CUT, level, O_PENT)
	end

	--- a crown of thorns (spikes, never a ring): one closed zigzag stroke. 1 piece.
	function Forge.ThornStar(cv, c, normal, rOut, level, o)
		if rOut < 0.02 then return end
		local ux, vx, nn = RD.basis(normal)
		local np, inner, rot = (o and o.n_pts) or 5, (o and o.inner) or 0.42, (o and o.rot) or 0
		for k = 0, 2 * np do
			local a = rot + pi * k / np
			local rr = (k % 2 == 0) and rOut or rOut * inner
			STARQ[k + 1] = c + (ux * cos(a) + vx * sin(a)) * rr
		end
		trimTo(STARQ, 2 * np + 1)
		O_THORN.w = (o and o.w) or RD.lw(level) * 0.9
		O_THORN.n, O_THORN.tag = nn, o and o.tag or nil
		cv:Stroke(STARQ, level, O_THORN)
	end

	local O_BRAND = { u = 1, tag = nil }
	--- a brand burned onto a body: an inverted pentagram flashes hot at t0 and cools to an ember
	function Forge.EmberBrand(cv, p, normal, t, t0, R, tag)
		local u = ramp(t, t0, 0.12, "Linear")
		if u <= 0 then return end
		local lv = 0.35 + 0.65 * (1 - ramp(t, t0 + 0.1, 0.8))
		O_BRAND.u, O_BRAND.tag = u, tag
		local nn = normal.Unit
		Forge.Pentagram(cv, p + nn * 0.03, nn, R or 0.3, lv, O_BRAND)
	end

	local BPATH, CHEV = {}, {}
	local O_THREAD = { w = 0.035, n = UP, tag = nil }
	local O_CHEV = { w = 0.05, n = UP, pieces = 1, tag = nil }
	local O_HCHEV = { w = 0.05, taper = { 0.0, 0.03 }, lo = { 0.0, 0.4 }, n = UP, pieces = 1, tag = nil }
	local O_SIG = { rot = 0, tag = nil }
	local SPARK_DB = { n = 2, seed = 0, level = 1.0, size = 0.08, life = 0.7, drift = UP * 0.7, region = nil, tag = nil }
	local SPARK_DH = { n = 6, seed = 91, level = 1.0, size = 0.08, life = 0.7, t0 = 0, t1 = 0, drift = UP * 0.7,
		region = nil, tag = nil }

	local function pathAt(f)
		local x = clamp(f, 0, 1) * 8
		local i = min(floor(x), 7)
		return BPATH[i + 1]:Lerp(BPATH[i + 2], x - i), unit(BPATH[i + 2] - BPATH[i + 1], UP)
	end

	--- THE DEVIL BOND (the kit bond's place): a dark iron thread drawn on from src by u; barbed chevrons (pointing at
	--- dst) glide along it toward dst at 2.6 studs/s; embers rise off it; a small inverted pentagram at the source
	--- (src_sigil) and a brand at dst (seal). A heal thread (pulse) sags a little; a taut one is a contract line.
	--- o {w, src_sigil=true, seal=true, pulse=true, max_chev=6, tag}. Pieces: 1 + 1 per chevron (+2 sigil, +2 seal).
	function Forge.DevilBond(cv, src, dst, u, level, o)
		camRefresh()
		local L = (dst - src).Magnitude
		if u <= 0 or L < 1e-3 then return src end
		local T = cv.T or 0
		local tag = o and o.tag or nil
		local lead = src:Lerp(dst, u)
		local sag = (o and o.pulse == false) and 0 or 0.3
		for k = 0, 8 do BPATH[k + 1] = src:Lerp(lead, k / 8) - UP * (sag * u * sin(pi * k / 8)) end
		local cd = camDir(BPATH[5])
		O_THREAD.w, O_THREAD.n, O_THREAD.tag = (o and o.w) or 0.035, cd, tag
		cv:Stroke(BPATH, max(0.12, level * 0.4), O_THREAD)
		local nc = max(2, min(((o and o.max_chev) or 6) - 1, floor(L * u / 1.6) + 1))
		for j = 0, nc - 1 do
			local f = ((T * 2.6) / max(L * u, 1e-3) + j / nc) % 1
			local p, d = pathAt(f)
			local k = sin(pi * f) ^ 0.5 * min(1, u * 4)
			if k >= 0.08 then
				local cp = camDir(p)
				local sd = unit(d:Cross(cp), ortho(d))
				local a, wd, bb = 0.30 * k, 0.20 * k, 0.09 * k
				CHEV[1] = p - d * a + sd * wd + d * (bb * 0.4) - sd * bb
				CHEV[2] = p - d * a + sd * wd
				CHEV[3] = p
				CHEV[4] = p - d * a - sd * wd
				CHEV[5] = p - d * a - sd * wd + d * (bb * 0.4) + sd * bb
				O_CHEV.n, O_CHEV.tag = cp, tag
				cv:Stroke(CHEV, min(1, 0.75 + 0.25 * level), O_CHEV)
			end
		end
		SPARK_DB.seed = floor(abs(src.X * 7 + dst.Z * 13)) % 997
		SPARK_DB.tag = tag
		SPARK_DB.region = function(rnd) return (pathAt(rnd() * u)) end
		cv:Sparkles(ZERO, 0, T, SPARK_DB)
		if not (o and o.src_sigil == false) then
			O_SIG.rot, O_SIG.tag = T, tag
			Forge.Pentagram(cv, src + cd * 0.05, cd, 0.16 * min(1, u * 5), 0.9, O_SIG)
		end
		if not (o and o.seal == false) and u > 0.9 then
			O_SIG.rot, O_SIG.tag = -T, tag
			Forge.Pentagram(cv, dst + cd * 0.05, cd, 0.2 * (u - 0.9) / 0.1, 0.9, O_SIG)
		end
		return lead
	end

	--- A heal carried to an ally (devil_heal): a dark iron thread sagging from src to dst; barbed chevrons (pointing at
	--- the ally) glide along it at `speed` studs/s, growing in at src and closing at dst; embers rise off it (th = the
	--- heal's start). o {n_chev=4, speed=2.6, tag}. Pieces: 1 + 2 per chevron; the embers are sparkles.
	function Forge.DevilHeal(cv, src, dst, u, t, th, o)
		camRefresh()
		local L = (dst - src).Magnitude
		if L < 1e-3 then return end
		local tag = o and o.tag or nil
		for k = 0, 8 do BPATH[k + 1] = src:Lerp(dst, k / 8) - UP * (0.35 * sin(pi * k / 8)) end
		O_THREAD.w, O_THREAD.n, O_THREAD.tag = 0.035, camDir(BPATH[5]), tag
		cv:Stroke(BPATH, 0.22 * u, O_THREAD)
		local nch, speed = (o and o.n_chev) or 4, (o and o.speed) or 2.6
		for j = 0, nch - 1 do
			local f = ((t - th) * speed / max(L, 1e-3) + j / nch) % 1
			local p, d = pathAt(f)
			local k = u * sin(pi * f) ^ 0.5
			if k >= 0.05 then
				local cp = camDir(p)
				local sd = unit(d:Cross(cp), ortho(d))
				local a, wd, bb = 0.30 * k, 0.20 * k, 0.09 * k
				for sg = 1, -1, -2 do                               -- each arm: tip -> arm end -> a barb hooking back in
					local arm = p - d * a + sd * (wd * sg)
					CHEV[1], CHEV[2], CHEV[3] = p, arm, arm + d * (bb * 0.4) - sd * (bb * sg)
					trimTo(CHEV, 3)
					O_HCHEV.n, O_HCHEV.tag = cp, tag
					cv:Stroke(CHEV, 0.85, O_HCHEV)
				end
			end
		end
		SPARK_DH.seed, SPARK_DH.t0, SPARK_DH.t1, SPARK_DH.tag = 91 + floor(th * 10), th, th + 0.4, tag
		SPARK_DH.region = function(rnd) return (pathAt(rnd())) end
		cv:Sparkles(ZERO, 0, t, SPARK_DH)
	end

	local CLH = {}
	local O_CLH = { w = 0.06, taper = { 0.0, 0 }, lo = { 1.0, 0.0 }, n = UP, pieces = 1, tag = nil }
	--- the devil clasp's two small curved horns sweeping up off its sides (draw after cv:Clasp). +2 pieces.
	--- o {r=0.2, level=0.6, u=1, front, tag}
	function Forge.ClaspHorns(cv, c, axis, o)
		local u = (o and o.u) or 1
		if u <= 0.3 then return end
		camRefresh()
		local r, level = (o and o.r) or 0.2, (o and o.level) or 0.6
		local f = (o and o.front) and o.front.Unit or camDir(c)
		local sd = unit(axis.Unit:Cross(f), ortho(f))
		local g = min(1, (u - 0.3) / 0.5)
		for sg = 1, -1, -2 do
			local b = c + sd * (sg * r * 0.9) + f * 0.04
			CLH[1] = b
			CLH[2] = b + sd * (sg * 0.10 * g) + UP * (0.10 * g)
			CLH[3] = b + sd * (sg * 0.12 * g) + UP * (0.26 * g)
			CLH[4] = b + sd * (sg * 0.04 * g) + UP * (0.36 * g)
			O_CLH.taper[2], O_CLH.n, O_CLH.tag = 0.3 * g, f, o and o.tag or nil
			cv:Stroke(CLH, level, O_CLH)
		end
	end

end

----------------------------------------------------------------------------------------------------
-- PREWARM (capacities measured in Studio from the demo inputs, x CapGrow when built)
----------------------------------------------------------------------------------------------------
do
	-- {kind, solid triangles, Neon triangles, box half-size}: measured in Studio (2026-10-13) on the Blender demo inputs
	-- (fb1: Maw, BenePit, ColumnCable + seam and ColumnMotes counted from the forms)
	local PIECE_FORMS = {
		LightLance = { { "LanceChain", 10864, 3880, 92 }, { "LanceHook", 66, 8, 2 }, { "HitHorns", 170, 20, 3 } },
		Halo = { { "Horns", 332, 32, 3 }, { "BatWing", 558, 40, 6 }, { "BatWing", 558, 40, 6 } },
		Blessing = { { "HornDome", 1190, 140, 8 }, { "Plate", 464, 74, 3 } },
		Overflow = { { "HornDome", 1190, 140, 8 }, { "Plate", 464, 74, 3 } },
		Trade = { { "Maw", 444, 48, 6 }, { "Maw", 444, 48, 6 } },
		Benediction = { { "BenePit", 480, 250, 6 }, { "BeneClaws", 846, 72, 6 }, { "BeneSlabs", 100, 20, 6 },
			{ "BeneRubble", 200, 0, 11 }, { "BeneChips", 0, 32, 8 }, { "BeneHorns", 176, 16, 7 },
			{ "BeneCracks", 150, 150, 32 }, { "Column", 544, 540, 229 }, { "ColumnChains", 8960, 3200, 19 },
			{ "ColumnCable", 2696, 1764, 230 }, { "ColumnMotes", 32, 32, 155 }, { "GateHorns", 248, 32, 26 }, { "Plate", 464, 74, 3 }, { "Plate", 464, 74, 3 },
			{ "ShaftChain", 336, 160, 8 }, { "PactChain", 5880, 2800, 32 }, { "PactChain", 5880, 2800, 32 } },
	}

	--- build the forms a piece uses ahead of its first cast (call once the caster's skin is Devil)
	function Forge.PrewarmPiece(name)
		local list = PIECE_FORMS[name]
		if not list then return end
		for _, f in ipairs(list) do Forge.Prewarm(f[1], f[2], f[3], f[4]) end
	end
end

return Forge
