--[[
	RadiantDraw  (ReplicatedStorage.IceMagic.RadiantDraw, ModuleScript, CLIENT ONLY)   Radiant Phase 5, 2026-09-29

	The Luau port of the Phase 4 Blender FX kit's drawing primitives (vmarm/radiant/phase4/lib/rad_anim.py, ROUND-3
	glow constants), so each piece's Blender frame_fn(t) ports almost line by line:

	    Blender                                         Luau
	    fx_tag("halo")                                  cv:Tag("halo")
	    ring(c, 1.2, ZUP, lv, a0=ph, u=u, ticks=12)     cv:Ring(c, 1.2, UP, lv, { a0 = ph, u = u, ticks = 12 })
	    glint(p, 0.3, 1.0, 0.4 * t, short=0.45)         cv:Glint(p, 0.3, 1.0, 0.4 * t, nil, 0.45)
	    ramp(t, 0.3, 0.2, "Quad") / env(t, a, b)        RD.ramp(t, 0.3, 0.2, "Quad") / RD.env(t, a, b)

	Keyword arguments become ONE options table with the kit's own snake_case names (a0, u, tick_len, long_every,
	src_sigil, glint_size ...); tuples become arrays (tick_len = {short, long}, taper = {tail_m, head_m}). Options are
	only read, never kept, so hoist constant tables out of the frame function and overwrite their varying fields
	(OPT.u = u) to keep a frame allocation-free. Lists that held None use false (Motes trails).

	COORDINATES. Every argument is a Roblox world Vector3 (studs). Blender +Z up / a figure faces -Y; Roblox +Y up /
	faces -Z (LookVector). One rule, a proper rotation (it keeps cross products, so every basis/angle convention of
	the kit carries over):   Roblox (x, y, z) = Blender (-x, z, y)   ->  RD.B(x, y, z)  (ZUP -> RD.UP).
	Body-frame offsets (the kit's from_body (right, up, forward)) -> RD.Body(cf, right, up, fwd). A point from the
	Blender scene itself -> RD.FromScene(rootCF, at_x, at_y, facing_deg, pB) (the kit's figure root is 3.0 over the
	floor, like an R15 HumanoidRootPart). Angle 0 of a ring/spiral/sigil = the kit's (the rotated Blender basis:
	world +Z for a horizontal ring) -- pass ref = a body direction to lock it to the caster instead.

	THE RENDERER (immediate mode, pooled). A canvas per effect instance: cv:Begin(t) ... draw calls ... cv:End().
	Pooled slots are handed out in draw order; End() disables the ones not drawn this frame. Nothing is created per
	frame after warm-up (new slots only when a frame draws more than any before) and nothing is destroyed until
	cv:Destroy(), which returns the slots to a shared free list (capped by Config.PoolKeep). Every property write is
	skipped when the value did not change, so a still sigil costs no writes. All instances live in
	workspace.<FX folder>.RadiantDraw: Beams in the folder, their Attachments (and PointLights) on one anchored,
	invisible, non-colliding, non-querying, shadowless Part at the origin (so no moving Parts exist: BulkMoveTo is not
	needed).
	  a STROKE (seg, polyline, arc, spiral, spoke, tick, ray, chevron arm, trail, star spike) = one span per knot pair,
	    each span = TWO Beams on the same two Attachments: the cream CORE (level_look, ZOffset in front) and the GOLD
	    SLEEVE sleeve_w(level) x wider (glow_look). Curves: the Attachment Axis rides the tangent, CurveSize0/1 = the
	    Bezier handles (an arc = one span per <= 90 deg with (4/3) r tan(d/4): exact to 0.03%; Catmull-Rom strokes are
	    exact). n == nil -> FaceCamera true (the kit's camera-facing strokes); n given -> a flat strip in the plane with
	    normal n (FaceCamera false; rings, sigils, ground linework).
	  a GLINT / MOTE = a textured camera-facing Beam sprite (built-in texture), gold halo + cream core: deterministic
	    per frame (a ParticleEmitter is not), 1 Beam + 2 Attachments each.
	  a LIGHT = a PointLight on a pooled Attachment.
	Budget counters follow the kit's own counting (a <= 90 deg arc = 1 piece, a complete rigid rosette = 1, a star = 1,
	glints/motes-as-particles = glints, lights) per canvas per frame, per Tag too; End() warns once per canvas when a
	frame passes Config.Budget (80 pieces / 40 glints / 3 lights). cv:Budget() also reports the real Beam count.

	THE DRIVER. RD.Play(name, frameFn, opts) runs frameFn(cv, t, dt, handle) every render frame between Begin/End on
	ONE shared RenderStep (Config.RenderPriority = Character + 3: after the Viewmodel (Camera + 2), CastPose
	(Character + 1) and RadiantAnim's staff (Character + 2), so palm/staff anchors read THIS frame's pose), bound only while an effect lives. Return false to
	end; errors end the effect (warned once). t comes from RD.Clock: server time, so every client draws the same phase.

	API  (RD = require(IceMagic.RadiantDraw); cv = a canvas; every vector is Roblox world)
	  timing / maths (the kit's names, identical curves)
	    RD.clamp(x,a,b) RD.lerp(a,b,t) RD.smooth(u) RD.ease_out_back(u,s=1.70158) RD.ease(style,u)  ease-OUT styles
	    RD.ramp(t, t0, dur, style="InOut") -> 0..1      RD.env(t, t0, t1, fin=0.15, fout=0.25, style="InOut") -> 0..1
	    RD.level_look(l) / RD.glow_look(l) / RD.staff_look(l) -> Color3, kit emission strength;  RD.lw(l), RD.sleeve_w(l)
	    RD.basis(n, ref?) -> u, v, n        RD.trail_fn(posFn, t, span=0.25, n=10, t_min?, out?) -> history (reuses out)
	    RD.Rand(a, b, c, k) -> 0..1          integer-hash random: identical on every client, allocation-free
	  clocks
	    RD.ServerNow()                       workspace:GetServerTimeNow()
	    RD.TimeScale()                       VFXLibrary.ShotTimeScale() (the filming slow-down), 1 if unavailable
	    RD.Clock(t0Server?, offset=0, scale=TimeScale()) -> fn()   clip seconds = (serverNow - t0) * scale + offset
	                                         (t0 nil: from now, local). Benediction: RD.Clock(T0, 0.44) (clip 0.44 = T0)
	  coordinates
	    RD.UP; RD.B(x,y,z | v) -> Vector3    Blender vector/offset -> Roblox
	    RD.Body(cf, right, up, fwd) / RD.BodyDir(...) / RD.ToBody(cf, w) -> right, up, fwd
	    RD.FromScene(rootCF, at_x, at_y, facing_deg, pB)   a Blender scene point relative to a figure -> world
	    RD.Palm(handCF) -> centre, normal    RD.ReceivePoint(chest, src, lift=0.15, skin=0.62)   (kit palm/receive_point)
	  canvases and the driver
	    RD.new(name, prewarm?) -> cv         prewarm = {Spans=, Sprites=, Lights=} slots created now (no first-frame hitch)
	    cv:Begin(t) / cv:End() -> pieces, glints, lights / cv:Destroy() / cv:Clear() (hide all, keep the pool)
	    cv:Tag(name)                         the kit's fx_tag: the following pieces count under name
	    cv:Count(n, tag?) / cv:CountGlints(n, tag?)        the kit's _count for custom helpers (e.g. vbeam)
	    cv:Budget() -> {Pieces, Glints, Lights, Beams, Peak = {...}, Tags = {...}}   (allocates: diagnostics only)
	    RD.Play(name, frameFn, opts?) -> handle {Canvas, Stop()}   opts: T0, Offset, Scale, Clock, Until (clip s),
	                                         MaxLife (s), Prewarm, OnEnd(handle)
	    RD.StopAll()   RD.SetFolder(instance | fn)   RD.Stats()   RD.ClearLookCache() (after changing Config looks)
	  drawing (the kit's signatures; o = options table; returns as the kit)
	    cv:Line(pts, level, w?, n?, bezel=true, prof?, smooth=false)      the kit's _line: one stroke, NOT counted
	    cv:Seg(p0, p1, level=0.5, w?, n?, bezel=true, tag?)
	    cv:Polyline(pts, level=0.5, o{u, closed, w, n, rigid, bezel, tag}) -> lead point
	    cv:Ring(c, r, n=UP, level=0.5, o{a0, a1, u, ticks, long_every, tick_len, tick_in, dashes, duty, ref, w, rigid, tag, face})
	        face = true: camera-facing strips on the ring's circle (visible edge-on, like the kit's round lines)
	                                         -> end point
	    cv:Spiral(c, n, r0, r1, turns, u=1, level=0.5, o{a0, tail, grow, cw, ref, w, tag}) -> end point, end angle
	    cv:Rosette(c, n, r, level=0.5, o{spokes=8, s_in=1.22, s_out=1.72, phase, u, ref, w, rigid=true, grow, tag})
	    cv:Sigil(c, r, level=0.5, o{u, spokes=24, inner=0.8, n=UP, flat=true, rigid, tag})   lifted Config.FloorLift
	    cv:Chevron(p, d, level=0.5, o{size=0.2, spread=0.75, n, w, tag})
	    cv:Bond(src, dst, u=1, level=0.5, o{ph, n, w, src_sigil, seal, pulse, spacing=0.9, max_chev=6, period=0.7, tag})
	                                         -> lead point (the pulse runs on cv.T, the t given to Begin)
	    cv:Motes(points, level=1, o{size=0.07, sizes, trails, trail_len=0.4, as_particles, tag})
	    cv:Mote(p, size, level, dir?, trail_len=0, as_particle=false, tag?)   one mote (no list)
	    cv:Stroke(pts, level=0.5, o{w, taper={tail,head}, lo={tail,head}, n, smooth_k, sleeve=true, pieces=1, tag})
	    cv:Trail(history, level=0.8, o{w, lo=0, n, tag})
	    cv:Glint(p, size=0.12, level=1, rot=0, n?, short=0, tag?)
	    cv:Sparkles(c | c(t), radius, t, o{n=10, seed=7, level=1, size=0.1, life=0.8, t0, t1, drift=UP*0.25,
	                region="sphere"|"shell"|"disc"|"ring"|fn(rand), normal=UP, spin=0.8, tag})
	    cv:HolyRays(c, u, o{n=13, r0=0.3, length=1.8, width=0.18, normal, axis, fan=2pi, level=1, seed=3,
	                stagger=0.3, jitter=0.25, v=0, t, breathe=0.06, short=0.62, tag})
	    cv:Flare(p, u, o{size=0.8, level=1, points=8, rot=0, n, shock=true, tag})
	    cv:LightPool(p, level=1, o{energy, color (Color3), range, tag}) -> PointLight | nil
	    cv:MoteField(c | c(t), radius, t, o{n=10, seed=11, level=0.8, size=0.055, rise=0.9, life=1.4, t0, t1, sink,
	                sway=0.12, trail_len=0.22, height=0.3, tag})
	    cv:Gather(p, u, o{radius=0.9, n=8, level=0.9, seed=5, size=0.05, turns=0.6, glint_size=0.3, t=0, tag})
	    cv:StarStud(p, normal?, size=0.07, level=0.8, points=4, rot=0, tag?)
	    cv:Clasp(c, axis, o{r=0.2, width=0.12, level=0.6, u=1, front, stud=true, th=0.035, tag})
	    cv:StaffAura(p, level, t, o{light=true, sparkle=true, seed=17, tag})   (the kit's staff_aura at point p)
	  the staff
	    RD.StaffGlow(lineParts, level)       the kit's staff_glow: idle engraving (SmoothPlastic LINE_IDLE) .. Neon gold

	NOT LIKE THE KIT (Beams, not Blender meshes): no thickness (a flat strip seen edge-on vanishes; `flat`/`th` only
	matter as the kit's normals), widths are linear between knots (the kit's smoothstep tapers become linear ramps
	between inserted knots), a glint/mote is a built-in texture sprite (sparkles_main: 8 points, no crisp 4-point
	star; a mote is a round dot, not a faceted gem), randomness is a hash (same statistics, not the renders' exact
	positions), light_pool's floor disc is not drawn, the glow is Beam Brightness + LightEmission (UNCALIBRATED
	against Bloom Threshold 1.6: tune Config.BrightScale / LightEmission against <piece>_game.png in Play), and three
	Beam conventions are unverified in Studio (Config.CurveSize1Sign, WidthOnSecondaryAxis, the sprite texture scale).
]]

local RunService = game:GetService("RunService")

local RadiantDraw = {}

----------------------------------------------------------------------------------------------------
-- CONFIG (everything tunable in one place; the kit's round-3 constants are quoted as the kit names them)
----------------------------------------------------------------------------------------------------
local Config = {
	FXFolderName = "IceMagicFX",          -- fallback; VFXLibrary.Config.FXFolderName wins when readable
	SubFolderName = "RadiantDraw",
	RenderPriority = Enum.RenderPriority.Character.Value + 3,   -- Phase 5: after RadiantAnim's staff step (+2), so tips are this frame's
	MaxLife = 30,                         -- a Play()ed effect is ended this long (os.clock s) after it began

	-- the glow (UNCALIBRATED: Bloom Threshold 1.6, Intensity 0.6, Size 24 in both zone lightings)
	SkinCoreLift = 0.55,                  -- a skin's core: its palette colour this far toward white (white-hot, tinted)
	SkinSpan = 6,                         -- a skin's bands (SkinCatalog): studs of stroke from the first colour to the last
	LightEmission = 1,                    -- the brief: additive. 0 = opaque layering (core truly covers the sleeve)
	BrightScale = 1 / 8,                  -- Beam Brightness = 1 + BrightScale x the kit's emission strength (round-3 ratios kept).
	                                      --   Phase 5 Play calibration (2026-09-29): 1/2.6 and 1/5 blew the cream cores to white
	                                      --   under Bloom 1.6 / 0.6 / 24; 1/8 is closer to the gold of <piece>_game.png
	CoreZOffset = 0.02,                   -- the cream core draws in front of its gold sleeve
	MinWidthPerStud = 0.0012,             -- width floor per stud of camera distance (~1 px at 1080p / FOV 70); 0 = off

	-- Beam conventions (Studio checks: each is a one-number fix, same as UmbraTuning.FX.Engine)
	CurveSize1Sign = 1,                   -- -1 if a curve bows the wrong way at its Attachment1 end
	WidthOnSecondaryAxis = true,          -- false if a flat strip (rings, sigils) shows edge-on
	CurveSegments = 12,                   -- Segments of a curved span (<= 90 deg); straight spans use 1

	-- sprites (built-in textures only)
	GlintTexture4 = "rbxasset://textures/particles/sparkles_main.dds",   -- short == 0 (the kit's 4-point glint)
	GlintTexture8 = "rbxasset://textures/particles/sparkles_main.dds",   -- short > 0 (+ diagonal spikes)
	GlintScale = 1.0,                     -- sprite half-size / the kit's spike length (texture reach: check in Play)
	GlintSleeve = true,                   -- the gold star behind the cream one (2 Beams per glint; false = 1)
	MoteTexture = "rbxasset://textures/whiteCircle.png",
	MoteScale = 1.0,

	-- lights (the kit: "Roblox: a PointLight, Brightness ~ 3 x level, Range ~ 14")
	LightBrightness = 0.5,                -- Phase 5 Play calibration: 3 (and 1.2) lit the whole floor and every dummy gold
	LightRange = 10,                      -- Phase 5 Play calibration (was 14): the r3 warm pool stays near the effect
	LightW = 252.0,                       -- the kit's LIGHT_W (r3): energy= is relative to it

	FloorLift = 0.04,                     -- Sigil lifts flat ground linework this far (the kit's FLOOR_Z)
	RootHeight = 3.0,                     -- the kit's ROOT_H: a figure root over the floor
	StaffNeonFrom = 0.25,                 -- StaffGlow: Neon from this level (below: matte, colour lerping)

	Budget = { Pieces = 80, Glints = 40, Lights = 3 },
	PoolKeep = { Spans = 288, Sprites = 128, Lights = 8 },   -- Spans 256 -> 288 (review fix 2026-09-29): Benediction peaks at ~276

	-- rad_anim r3 constants (Q_STRENGTH, P_STRENGTH, G_BASE, G_PAY, S_BASE, S_PAY, W_QUIET, W_PAYOFF, SLEEVE_W, HEAD_TAPER)
	Q_STRENGTH = 2.6, P_STRENGTH = 13.0,
	G_BASE = 1.92, G_PAY = 9.6,
	S_BASE = 2.04, S_PAY = 8.4,
	W_QUIET = 0.05, W_PAYOFF = 0.07,
	SLEEVE_W0 = 1.75, SLEEVE_W1 = 2.9,
	HEAD_TAPER = 0.3,
}
RadiantDraw.Config = Config

----------------------------------------------------------------------------------------------------
-- MATHS (rad_anim / cryoclip_lib, identical curves)
----------------------------------------------------------------------------------------------------
local sin, cos, tan, abs, floor, ceil, max, min, sqrt, pi = math.sin, math.cos, math.tan, math.abs, math.floor,
	math.ceil, math.max, math.min, math.sqrt, math.pi
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)
local XAX = Vector3.new(1, 0, 0)
local NEGX = Vector3.new(-1, 0, 0)
local FWD_DEFAULT = Vector3.new(0, 0, -1)       -- the kit's no-camera fallback (0, -1, 0) in Roblox axes
RadiantDraw.UP = UP

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smooth(u)
	u = clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function ease_out_back(u, s)
	s = s or 1.70158
	u = clamp(u, 0, 1) - 1
	return u * u * ((s + 1) * u + s) + 1
end

--- The kit's ease(style, u): TweenService-style OUT curves.
local function ease(style, u)
	u = clamp(u, 0, 1)
	if style == "Quad" then return 1 - (1 - u) ^ 2 end
	if style == "Quint" then return 1 - (1 - u) ^ 5 end
	if style == "Sine" then return sin(u * pi / 2) end
	if style == "Back" then return ease_out_back(u) end
	return u
end

--- 0 before t0, 1 after t0 + dur; "InOut" = sine in-out (the default), or any ease() style.
local function ramp(t, t0, dur, style)
	if dur <= 0 then return (t >= t0) and 1 or 0 end
	local u = clamp((t - t0) / dur, 0, 1)
	if style == nil or style == "InOut" then return 0.5 - 0.5 * cos(pi * u) end
	return ease(style, u)
end

--- 0 at t0, eases up over fin, holds, eases back to 0 over the fout that end at t1.
local function env(t, t0, t1, fin, fout, style)
	if t <= t0 or t >= t1 then return 0 end
	return min(ramp(t, t0, fin or 0.15, style), 1 - ramp(t, t1 - (fout or 0.25), fout or 0.25, style))
end

RadiantDraw.clamp, RadiantDraw.lerp, RadiantDraw.smooth = clamp, lerp, smooth
RadiantDraw.ease_out_back, RadiantDraw.ease, RadiantDraw.ramp, RadiantDraw.env = ease_out_back, ease, ramp, env

--- u, v, n of a plane (angle 0 = ref projected in, else the kit's rule rotated into Roblox axes).
local function basis(n, ref)
	n = n.Unit
	if ref then
		local u = ref - n * ref:Dot(n)
		if u.Magnitude > 1e-6 then
			u = u.Unit
			return u, n:Cross(u).Unit, n
		end
	end
	local a = (abs(n.Y) < 0.9) and UP or NEGX     -- Blender: ZUP if |n.z| < 0.9 else (1, 0, 0)  ->  B(1,0,0) = -X
	local u = n:Cross(a).Unit
	return u, n:Cross(u).Unit, n
end
RadiantDraw.basis = basis

--- a unit vector perpendicular to d
local function ortho(d)
	local a = (abs(d.X) < 0.6) and XAX or ((abs(d.Y) < 0.6) and UP or Vector3.new(0, 0, 1))
	return d:Cross(a).Unit
end

--- v rotated about the unit axis by ang (right-handed, as mathutils.Quaternion)
local function rotAbout(v, axis, ang)
	local c, s = cos(ang), sin(ang)
	return v * c + axis:Cross(v) * s + axis * (axis:Dot(v) * (1 - c))
end

----------------------------------------------------------------------------------------------------
-- COLOURS AND LOOKS
----------------------------------------------------------------------------------------------------
local function hex(h)
	return Color3.fromRGB(tonumber(string.sub(h, 2, 3), 16), tonumber(string.sub(h, 4, 5), 16),
		tonumber(string.sub(h, 6, 7), 16))
end

local C = {
	QUIET = hex("#FFF1C4"),       -- the 0.5 core: warm cream
	ANCHOR = hex("#FFF7D6"),      -- the payoff core (RAD anchor)
	GOLD = hex("#F5C230"),        -- the glow sleeve / rays / clasps
	LIGHT = hex("#FFCB4F"),       -- PointLights
	EDGE = hex("#70520A"),        -- the idle bezel (RAD dark)
	LINE_IDLE = hex("#B9A46A"),   -- the unlit engraving
	INLAY_HOT = hex("#FFE7A0"),   -- the staff inlay at payoff
}
RadiantDraw.Colors = C

local function mix3(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

--- the CORE: 0 idle engraving (no emission) | 0.5 cream #FFF1C4 | 1 payoff #FFF7D6
local function level_look(level)
	local l = clamp(level, 0, 1)
	if l <= 0.5 then
		local f = l / 0.5
		return mix3(C.LINE_IDLE, C.QUIET, f), Config.Q_STRENGTH * f
	end
	local f = (l - 0.5) / 0.5
	return mix3(C.QUIET, C.ANCHOR, f), Config.Q_STRENGTH + (Config.P_STRENGTH - Config.Q_STRENGTH) * f
end

--- the gold SLEEVE: 0 dark bezel | 0.5 gold at G_BASE | 1 gold at G_PAY
local function glow_look(level)
	local l = clamp(level, 0, 1)
	if l <= 0.5 then
		local f = l / 0.5
		return mix3(C.EDGE, C.GOLD, f), Config.G_BASE * f
	end
	local f = (l - 0.5) / 0.5
	return C.GOLD, Config.G_BASE + (Config.G_PAY - Config.G_BASE) * f
end

--- the staff inlays: 0 idle engraving | 0.5 gold | 1 gold-cream hot
local function staff_look(level)
	local l = clamp(level, 0, 1)
	if l <= 0.5 then
		local f = l / 0.5
		return mix3(C.LINE_IDLE, C.GOLD, f), Config.S_BASE * f
	end
	local f = (l - 0.5) / 0.5
	return mix3(C.GOLD, C.INLAY_HOT, f), Config.S_BASE + (Config.S_PAY - Config.S_BASE) * f
end

local function lw(level)
	local l = clamp(level, 0, 1)
	if l <= 0.5 then return Config.W_QUIET end
	return Config.W_QUIET + (Config.W_PAYOFF - Config.W_QUIET) * (l - 0.5) / 0.5
end

local function sleeve_w(level)
	return Config.SLEEVE_W0 + (Config.SLEEVE_W1 - Config.SLEEVE_W0) * clamp(level, 0, 1)
end

RadiantDraw.level_look, RadiantDraw.glow_look, RadiantDraw.staff_look = level_look, glow_look, staff_look
RadiantDraw.lw, RadiantDraw.sleeve_w = lw, sleeve_w

-- Beam looks cached per level step (1/64): no Color3 / ColorSequence churn in the hot path
local LOOK_CORE, LOOK_GOLD = 1, 2
local LEVEL_Q = 128
local lookCache = { {}, {} }

local function lookEntry(look, level)
	local q = floor(clamp(level, 0, 1) * LEVEL_Q + 0.5)
	local cache = lookCache[look]
	local e = cache[q]
	if e then return e end
	local l = q / LEVEL_Q
	local col, s
	if look == LOOK_CORE then col, s = level_look(l) else col, s = glow_look(l) end
	e = {
		Key = look * 1000 + q,
		Color = col,
		Seq = ColorSequence.new(col),
		Bright = 1 + Config.BrightScale * s,
		LE = Config.LightEmission * min(1, l / 0.5),   -- below 0.5 the kit's line is unlit: blend in normally
	}
	cache[q] = e
	return e
end

function RadiantDraw.ClearLookCache()
	lookCache = { {}, {} }
end

-- SKINS (2026-10-10, SkinCatalog): a canvas with a Palette draws its GOLD -- the sleeve, the gold strokes, the gold motes
-- -- in the palette's colours, by where the span sits along its stroke; the cream core stays (the identity anchor).
-- Colour only: no span, sprite or light is added. A Flat palette is drawn alpha-blended (LightEmission 0, Brightness 1),
-- so it keeps its saturation in daylight. No Palette = exactly as before.
local WHITE = Color3.new(1, 1, 1)
local HUGE_BRIGHT = math.huge
-- RECOLOUR ONLY (the owner, 2026-10-10): a skin entry keeps its Default entry's Brightness and LightEmission -- the same
-- glow and blend at every level -- and swaps the colour alone; the core stays white-hot, tinted (SkinCoreLift)
local function skinEntry(pal, u0, u1, core, base)
	local seq, key = pal.Seq(u0, u1)
	local all = pal._rd
	if not all then
		all = {}
		pal._rd = all
	end
	local cache = all[base.Key]
	if not cache then
		cache = {}
		all[base.Key] = cache
	end
	local k = key * 2 + (core and 1 or 0)
	local e = cache[k]
	if not e then
		if core then
			local kp = {}
			for i, p in ipairs(seq.Keypoints) do
				kp[i] = ColorSequenceKeypoint.new(p.Time, p.Value:Lerp(WHITE, (pal and pal.CoreLift) or Config.SkinCoreLift))
			end
			seq = ColorSequence.new(kp)
		end
		-- (2026-10-13) a dark skin (Devil) caps both: a red at Brightness > ~1.3, or added on itself, clips its red
		-- channel first and climbs to pink, then white -- the rework is red and black, never pink
		e = { Key = -(1 + k + base.Key * 1000000), Seq = seq, Bright = min(base.Bright, pal.MaxBright or HUGE_BRIGHT),
			LE = base.LE * (pal.LEScale or 1) }
		cache[k] = e
	end
	return e
end

local function pingPong(x)
	local ph = x % 2
	return ph <= 1 and ph or 2 - ph
end

-- the palette the next RadiantDraw.Play's canvas takes (set by WithPalette round a synchronous start)
local pendingPalette = nil

--- fn(...) with `palette` handed to every effect it starts (RadiantDraw.Play) -- nil = Default.
function RadiantDraw.WithPalette(palette, fn, ...)
	local prev = pendingPalette
	pendingPalette = palette
	local res = table.pack(pcall(fn, ...))
	pendingPalette = prev
	if not res[1] then error(res[2], 0) end
	return table.unpack(res, 2, res.n)
end

----------------------------------------------------------------------------------------------------
-- COORDINATES
----------------------------------------------------------------------------------------------------
--- A Blender vector (numbers or a Vector3 holding Blender components) in Roblox axes: (x, y, z) -> (-x, z, y).
function RadiantDraw.B(x, y, z)
	if typeof(x) == "Vector3" then return Vector3.new(-x.X, x.Z, x.Y) end
	return Vector3.new(-(x or 0), z or 0, y or 0)
end

--- the kit's from_body: a point at (right, up, forward) in cf's frame
function RadiantDraw.Body(cf, right, up, fwd)
	return cf.Position + cf.RightVector * (right or 0) + cf.UpVector * (up or 0) + cf.LookVector * (fwd or 0)
end

--- the same as a direction (no position)
function RadiantDraw.BodyDir(cf, right, up, fwd)
	return cf.RightVector * (right or 0) + cf.UpVector * (up or 0) + cf.LookVector * (fwd or 0)
end

--- the kit's to_body: a world vector as (right, up, forward) in cf's frame
function RadiantDraw.ToBody(cf, w)
	return w:Dot(cf.RightVector), w:Dot(cf.UpVector), w:Dot(cf.LookVector)
end

--- A point pB of the Blender scene (Blender components) where a figure stood at (at_x, at_y) facing facing_deg, placed
--- the same way relative to rootCF (the live HumanoidRootPart CFrame, or any frame standing in for the kit's root).
function RadiantDraw.FromScene(rootCF, at_x, at_y, facing_deg, pB)
	local sceneRoot = CFrame.new(-at_x, Config.RootHeight, at_y) * CFrame.Angles(0, math.rad(facing_deg or 0), 0)
	return rootCF:PointToWorldSpace(sceneRoot:PointToObjectSpace(RadiantDraw.B(pB)))
end

--- the kit's palm(fig, side): the hand block's end face centre and its outward normal (hand -Y)
function RadiantDraw.Palm(handCF)
	return handCF:PointToWorldSpace(Vector3.new(0, -0.15, 0)), -handCF.UpVector
end

--- the kit's receive_point: where a Bond from src enters a body (aimed at the chest, stopped at the skin)
function RadiantDraw.ReceivePoint(chest, src, lift, skin)
	local aimP = chest + UP * (lift or 0.15)
	local d = aimP - src
	d = (d.Magnitude > 1e-6) and d.Unit or UP
	return aimP - d * (skin or 0.62)
end

----------------------------------------------------------------------------------------------------
-- RANDOMNESS: an integer hash (lowbias32), identical on every client, no Random objects per frame
----------------------------------------------------------------------------------------------------
local TWO32 = 4294967296
local bxor, rshift = bit32.bxor, bit32.rshift

local function mul32(a, b)
	local ah, al = a // 65536, a % 65536
	return ((ah * b) % 65536 * 65536 + al * b) % TWO32
end

local function mix(h)
	h = h % TWO32
	h = bxor(h, rshift(h, 16))
	h = mul32(h, 0x7FEB352D)
	h = bxor(h, rshift(h, 15))
	h = mul32(h, 0x846CA68B)
	h = bxor(h, rshift(h, 16))
	return h
end

local function key3(a, b, c)
	return mix(mix(mix(floor(a) % TWO32) + floor(b) % TWO32) + floor(c) % TWO32)
end

--- a stream: rsSeed(a, b, c) then rsNext() ... (module state: drawing is synchronous)
local RS_KEY, RS_K = 0, 0
local function rsSeed(a, b, c)
	RS_KEY, RS_K = key3(a, b, c), 0
end
local function rsNext()
	RS_K += 1
	return mix(RS_KEY + RS_K * 0x9E3779B9) / TWO32
end

function RadiantDraw.Rand(a, b, c, k)
	return mix(key3(a, b or 0, c or 0) + (k or 1) * 0x9E3779B9) / TWO32
end

local function randDir()
	local z = rsNext() * 2 - 1
	local ph = rsNext() * TAU
	local rr = sqrt(max(0, 1 - z * z))
	return Vector3.new(rr * cos(ph), z, rr * sin(ph))
end

----------------------------------------------------------------------------------------------------
-- CLOCKS
----------------------------------------------------------------------------------------------------
local vfxLib = nil
local function timeScale()
	if vfxLib == nil then
		vfxLib = false
		local parent = script and script.Parent
		local mod = parent and parent:FindFirstChild("VFXLibrary")
		if mod then
			local ok, lib = pcall(require, mod)
			if ok and type(lib) == "table" then vfxLib = lib end
		end
	end
	if vfxLib and type(vfxLib.ShotTimeScale) == "function" then
		local ok, s = pcall(vfxLib.ShotTimeScale)
		if ok and type(s) == "number" and s > 0 then return s end
	end
	return 1
end
RadiantDraw.TimeScale = timeScale

function RadiantDraw.ServerNow()
	return workspace:GetServerTimeNow()
end

--- clip seconds: (serverNow - t0) * scale + offset; t0 nil = a local clock from now
function RadiantDraw.Clock(t0, offset, scale)
	offset = offset or 0
	scale = scale or timeScale()
	if t0 == nil then
		local o = os.clock()
		return function() return (os.clock() - o) * scale + offset end
	end
	return function() return (workspace:GetServerTimeNow() - t0) * scale + offset end
end

--- the kit's trail_fn: posFn sampled n times over [t - span, t] (not before t_min); fills and returns out
function RadiantDraw.trail_fn(posFn, t, span, n, t_min, out)
	span, n, out = span or 0.25, n or 10, out or {}
	local a = t - span
	if t_min and t_min > a then a = t_min end
	local cnt
	if t - a < 1e-5 then
		out[1] = posFn(t)
		cnt = 1
	else
		for j = 0, n - 1 do out[j + 1] = posFn(a + (t - a) * j / (n - 1)) end
		cnt = n
	end
	for k = #out, cnt + 1, -1 do out[k] = nil end
	return out
end

----------------------------------------------------------------------------------------------------
-- THE CAMERA (read once per Begin)
----------------------------------------------------------------------------------------------------
local camPos, camUp, camRight = Vector3.new(0, 0, 10), UP, XAX

local function camRefresh()
	local c = workspace.CurrentCamera
	if c then
		local cf = c.CFrame
		camPos, camUp, camRight = cf.Position, cf.UpVector, cf.RightVector
	end
end

--- the kit's _cam_dir: from p toward the camera
local function camDir(p)
	local d = camPos - p
	local m = d.Magnitude
	if m > 1e-6 then return d / m end
	return FWD_DEFAULT
end

----------------------------------------------------------------------------------------------------
-- THE POOL: one folder + one anchor Part; slots are reused across canvases
----------------------------------------------------------------------------------------------------
local root = { Folder = nil, Anchor = nil, Gen = 0 }
local freeSpans, freeSprites, freeLights = {}, {}, {}
local folderSource = nil
local OPAQUE = nil
local warned = {}

local function warnOnce(key, msg)
	if not warned[key] then
		warned[key] = true
		warn("[RadiantDraw] " .. msg)
	end
end

function RadiantDraw.SetFolder(src)
	folderSource = src
end

local function fxParent()
	if folderSource then
		if typeof(folderSource) == "Instance" and folderSource.Parent then return folderSource end
		if type(folderSource) == "function" then
			local ok, f = pcall(folderSource)
			if ok and typeof(f) == "Instance" then return f end
		end
	end
	local name = Config.FXFolderName
	timeScale()                                         -- loads VFXLibrary once (guarded)
	if vfxLib and type(vfxLib.Config) == "table" and type(vfxLib.Config.FXFolderName) == "string" then
		name = vfxLib.Config.FXFolderName
	end
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function ensureRoot()
	local a, f = root.Anchor, root.Folder
	if a and f and a.Parent == f and f.Parent ~= nil then return end
	-- (re)build: whatever the old folder held went with it; drop every reference to it
	root.Gen += 1
	table.clear(freeSpans)
	table.clear(freeSprites)
	table.clear(freeLights)
	if f and f.Parent ~= nil then f:Destroy() end       -- our own runtime folder, half-broken
	OPAQUE = OPAQUE or NumberSequence.new(0)
	f = Instance.new("Folder")
	f.Name = Config.SubFolderName
	a = Instance.new("Part")
	a.Name = "RadiantDrawAnchor"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.Transparency = 1
	a.Size = Vector3.new(0.05, 0.05, 0.05)
	a.CFrame = CFrame.new()                            -- identity: Attachment.CFrame == world CFrame
	a.Parent = f
	f.Parent = fxParent()
	root.Folder, root.Anchor = f, a
end

local function newAtt()
	local at = Instance.new("Attachment")
	at.Name = "RadiantKnot"
	at.Parent = root.Anchor
	return at
end

local function newBeam(a0, a1, z)
	local b = Instance.new("Beam")
	b.Name = "RadiantBeam"
	b.Enabled = false
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.LightInfluence = 0
	b.LightEmission = Config.LightEmission
	b.Brightness = 1
	b.Transparency = OPAQUE
	b.Segments = 1
	b.Width0, b.Width1 = 0, 0
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.ZOffset = z
	b.Texture = ""
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.Parent = root.Folder
	return b
end

-- a beam's last-written state (write-if-changed); `face` starts true, `seg` 1, `z` as created
local function beamState(z)
	return { on = false, key = -1, face = true, w0 = 0, w1 = 0, c0 = 0, c1 = 0, seg = 1, z = z, tex = "" }
end

local function newSpan()
	local a0, a1 = newAtt(), newAtt()
	return { A0 = a0, A1 = a1, Core = newBeam(a0, a1, Config.CoreZOffset), Sleeve = newBeam(a0, a1, 0),
		CS = beamState(Config.CoreZOffset), SS = beamState(0) }
end

local function newSprite()
	local a0, a1 = newAtt(), newAtt()
	return { A0 = a0, A1 = a1, B = newBeam(a0, a1, 0), ST = beamState(0) }
end

local function newLight()
	local at = newAtt()
	local l = Instance.new("PointLight")
	l.Enabled = false
	l.Shadows = false
	l.Color = C.LIGHT
	l.Range = Config.LightRange
	l.Brightness = 0
	l.Parent = at
	return { Att = at, L = l, on = false, b = 0, r = Config.LightRange, c = C.LIGHT }
end

local function beamOff(b, st)
	if st.on then
		st.on = false
		b.Enabled = false
	end
end

local function beamWrite(b, st, e, face, w0, w1, c0, c1, seg, z, tex)
	if st.key ~= e.Key then
		st.key = e.Key
		b.Color = e.Seq
		b.Brightness = e.Bright
		b.LightEmission = e.LE
	end
	if st.face ~= face then st.face = face; b.FaceCamera = face end
	if st.w0 ~= w0 then st.w0 = w0; b.Width0 = w0 end
	if st.w1 ~= w1 then st.w1 = w1; b.Width1 = w1 end
	if st.c0 ~= c0 then st.c0 = c0; b.CurveSize0 = c0 end
	if st.c1 ~= c1 then st.c1 = c1; b.CurveSize1 = c1 end
	if st.seg ~= seg then st.seg = seg; b.Segments = seg end
	if st.z ~= z then st.z = z; b.ZOffset = z end
	if tex and st.tex ~= tex then st.tex = tex; b.Texture = tex end
	if not st.on then st.on = true; b.Enabled = true end
end

local function place0(s, p, x, y)
	if s.p0 ~= p or s.x0 ~= x or s.y0 ~= y then
		s.p0, s.x0, s.y0 = p, x, y
		s.A0.CFrame = CFrame.fromMatrix(p, x, y)
	end
end

local function place1(s, p, x, y)
	if s.p1 ~= p or s.x1 ~= x or s.y1 ~= y then
		s.p1, s.x1, s.y1 = p, x, y
		s.A1.CFrame = CFrame.fromMatrix(p, x, y)
	end
end

local function spanOff(s)
	beamOff(s.Core, s.CS)
	beamOff(s.Sleeve, s.SS)
end

local function spriteOff(s)
	beamOff(s.B, s.ST)
end

local function lightOff(s)
	if s.on then
		s.on = false
		s.L.Enabled = false
	end
end

local SLOT_PARTS = { "Core", "Sleeve", "B", "L", "A0", "A1", "Att" }
local function destroySlot(s)
	for _, k in ipairs(SLOT_PARTS) do
		local inst = s[k]
		if inst then inst:Destroy() end
	end
end

----------------------------------------------------------------------------------------------------
-- THE KNOT CHAIN: one stroke at a time (module scratch arrays, reused: no per-frame tables)
--   KP position, KT unit tangent (the Attachment Axis), KH0/KH1 Bezier handle lengths behind/ahead, KM width multiplier
----------------------------------------------------------------------------------------------------
local KP, KT, KH0, KH1, KM, KY, KW, SL, KS, KSP = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local KN = 0

local function kpush(p, t, h0, h1, m)
	KN += 1
	KP[KN], KT[KN], KH0[KN], KH1[KN], KM[KN] = p, t, h0, h1, m
end

--- a straight 2-knot stroke a -> b
local function kStraight(a, b)
	KN = 0
	local d = b - a
	local m = d.Magnitude
	if m < 1e-6 then return end
	local t = d / m
	kpush(a, t, 0, 0, 1)
	kpush(b, t, 0, 0, 1)
end

--- knots through pts (duplicates within eps dropped); smoothC: Catmull-Rom handles (exactly rad_anim._catmull's
--- curve), else straight spans (tangents by central difference, as rad_anim._band orients its bands)
local function kPoints(pts, smoothC, eps, closed)
	eps = eps or 1e-5
	KN = 0
	local last = nil
	for i = 1, #pts do
		local p = pts[i]
		if last == nil or (p - last).Magnitude > eps then
			KN += 1
			KP[KN], KM[KN] = p, 1
			last = p
		end
	end
	if closed and KN >= 2 and (KP[1] - KP[KN]).Magnitude > eps then
		KN += 1
		KP[KN], KM[KN] = KP[1], 1
	end
	if KN < 2 then
		KN = 0
		return
	end
	for i = 1, KN do
		local m = (KP[min(i + 1, KN)] - KP[max(i - 1, 1)]) * 0.5
		local mm = m.Magnitude
		KT[i] = (mm > 1e-9) and (m / mm) or UP
		if smoothC then
			KH0[i], KH1[i] = mm / 3, mm / 3
		else
			KH0[i], KH1[i] = 0, 0
		end
	end
end

--- an arc of radius r from angle b0 to b1 in the (ux, vx) plane round c: one span per <= 90 deg, exact handles
local function kArc(c, ux, vx, r, b0, b1)
	KN = 0
	local sweep = b1 - b0
	local k = max(1, ceil(abs(sweep) / (pi / 2) - 1e-6))
	local d = sweep / k
	local h = (4 / 3) * r * tan(abs(d) / 4)
	local sg = (sweep >= 0) and 1 or -1
	for j = 0, k do
		local a = b0 + j * d
		local ca, sa = cos(a), sin(a)
		kpush(c + (ux * ca + vx * sa) * r, (vx * ca - ux * sa) * sg, h, h, 1)
	end
end

local function kLengths()
	local tot = 0
	for i = 1, KN - 1 do
		local p0, p3 = KP[i], KP[i + 1]
		local l
		if KH1[i] <= 1e-9 and KH0[i + 1] <= 1e-9 then
			l = (p3 - p0).Magnitude
		else
			local c1, c2 = p0 + KT[i] * KH1[i], p3 - KT[i + 1] * KH0[i + 1]
			l = ((p3 - p0).Magnitude + (c1 - p0).Magnitude + (c2 - c1).Magnitude + (p3 - c2).Magnitude) * 0.5
		end
		SL[i] = l
		tot += l
	end
	return tot
end

--- insert a knot inside span i at parameter f (de Casteljau: the curve is unchanged)
local function ksplit(i, f)
	local p0, p3 = KP[i], KP[i + 1]
	local pos, t, h0n, h1n
	if KH1[i] <= 1e-9 and KH0[i + 1] <= 1e-9 then
		pos = p0 + (p3 - p0) * f
		local d = p3 - p0
		local m = d.Magnitude
		t = (m > 1e-9) and (d / m) or KT[i]
		h0n, h1n = 0, 0
	else
		local c1, c2 = p0 + KT[i] * KH1[i], p3 - KT[i + 1] * KH0[i + 1]
		local g = 1 - f
		pos = p0 * (g * g * g) + c1 * (3 * g * g * f) + c2 * (3 * g * f * f) + p3 * (f * f * f)
		local d = (c1 - p0) * (3 * g * g) + (c2 - c1) * (6 * g * f) + (p3 - c2) * (3 * f * f)
		local sp = d.Magnitude
		t = (sp > 1e-9) and (d / sp) or KT[i]
		h0n, h1n = sp * f / 3, sp * g / 3
		KH1[i] *= f
		KH0[i + 1] *= g
	end
	local m = KM[i] + (KM[i + 1] - KM[i]) * f
	for j = KN, i + 1, -1 do
		KP[j + 1], KT[j + 1], KH0[j + 1], KH1[j + 1], KM[j + 1] = KP[j], KT[j], KH0[j], KH1[j], KM[j]
	end
	KN += 1
	KP[i + 1], KT[i + 1], KH0[i + 1], KH1[i + 1], KM[i + 1] = pos, t, h0n, h1n, m
end

--- the kit's _cut: keep the first fraction u (by length)
local function kCut(u)
	if u >= 1 - 1e-9 then return end
	if u <= 0 or KN < 2 then
		KN = 0
		return
	end
	local goal = kLengths() * u
	local acc = 0
	for i = 1, KN - 1 do
		local l = SL[i]
		if acc + l >= goal then
			local f = (l > 1e-9) and ((goal - acc) / l) or 1
			if f >= 1 - 1e-6 then
				KN = i + 1
			elseif f <= 1e-6 then
				KN = i
			else
				ksplit(i, f)
				KN = i + 1
			end
			if KN < 2 then KN = 0 end
			return
		end
		acc += l
	end
end

local function kInsertAt(len)
	local acc = 0
	for i = 1, KN - 1 do
		local l = SL[i]
		if len > acc + 1e-4 and len < acc + l - 1e-4 then
			ksplit(i, (len - acc) / l)
			return
		end
		acc += l
	end
end

--- the kit's _taper: widths ease to lo_head over the last `head` and from lo_tail over the first `tail`
local function kTaper(head, tail, loHead, loTail)
	if KN < 2 or (head <= 0 and tail <= 0) then return end
	local tot = kLengths()
	head, tail = min(head, tot * 0.5), min(tail, tot * 0.5)
	if tail > 1e-4 then
		kInsertAt(tail)
		kLengths()
	end
	if head > 1e-4 then
		kInsertAt(tot - head)
	end
	tot = kLengths()
	local s = 0
	for i = 1, KN do
		local m = 1
		if head > 0 and s > tot - head - 1e-6 then m *= loHead + (1 - loHead) * smooth((tot - s) / head) end
		if tail > 0 and s < tail + 1e-6 then m *= loTail + (1 - loTail) * smooth(s / tail) end
		KM[i] *= m
		if i < KN then s += SL[i] end
	end
end

--- the kit's _head: a stroke still drawing on (u < 1) eases to 35% over its last HEAD_TAPER studs
local function kHead(drawing)
	if not drawing or KN < 2 then return end
	local L = kLengths()
	kTaper(min(Config.HEAD_TAPER, L * 0.3), 0, 0.35, 0)
end

----------------------------------------------------------------------------------------------------
-- EMISSION
----------------------------------------------------------------------------------------------------
--- the Attachment SecondaryAxis for tangent t: camera-facing (any perpendicular), across wdir, or n x t (flat)
local function orientY(t, n, wdir, face)
	local y
	if face then
		local up = (abs(t.Y) < 0.99) and UP or XAX
		y = up - t * up:Dot(t)
	elseif wdir then
		y = wdir - t * wdir:Dot(t)
	else
		y = n:Cross(t)
	end
	local m = y.Magnitude
	if m < 1e-6 then
		local up = (abs(t.Y) < 0.99) and UP or XAX
		y = up - t * up:Dot(t)
		m = y.Magnitude
	end
	y = y / m
	if not face and not Config.WidthOnSecondaryAxis then y = t:Cross(y) end
	return y
end

local Canvas = {}
Canvas.__index = Canvas

local function takeSpan(cv)
	local k = cv.nSpan + 1
	cv.nSpan = k
	local s = cv.spans[k]
	if s == nil then
		s = table.remove(freeSpans) or newSpan()
		cv.spans[k] = s
	end
	return s
end

local function takeSprite(cv)
	local k = cv.nSprite + 1
	cv.nSprite = k
	local s = cv.sprites[k]
	if s == nil then
		s = table.remove(freeSprites) or newSprite()
		cv.sprites[k] = s
	end
	return s
end

local function takeLight(cv)
	local k = cv.nLight + 1
	cv.nLight = k
	local s = cv.lights[k]
	if s == nil then
		s = table.remove(freeLights) or newLight()
		cv.lights[k] = s
	end
	return s
end

--- draw the current chain: core look (or gold), width w x KM, camera-facing when n and wdir are nil, a flat strip
--- in the plane n (width n x t) or across wdir otherwise; bezel adds the gold sleeve. Returns true if drawn.
local function emitChain(cv, level, w, n, wdir, bezel, look, zc)
	if KN < 2 then return false end
	look = look or LOOK_CORE
	local e = lookEntry(look, level)
	local eg = bezel and lookEntry(LOOK_GOLD, level) or nil
	local sw = sleeve_w(level)
	local face = (n == nil and wdir == nil)
	local fk = Config.MinWidthPerStud
	local sign = Config.CurveSize1Sign
	local segC = Config.CurveSegments
	zc = zc or ((look == LOOK_GOLD) and 0 or Config.CoreZOffset)
	for i = 1, KN do
		KY[i] = orientY(KT[i], n, wdir, face)
		local wi = w
		if fk > 0 then
			local wf = (KP[i] - camPos).Magnitude * fk
			if wf > wi then wi = wf end
		end
		KW[i] = wi * KM[i]
	end
	local pal = cv.Palette
	local d0 = 0
	if pal then
		-- the bands run SkinSpan studs end to end and back (red .. violet .. red: violet never blends into red), so a
		-- long beam shows every colour wherever you look along it; each stroke starts at its own point of that cycle,
		-- by its order in the frame (the same every frame), so short rays and clasps are not all one colour
		cv.SkinC = (cv.SkinC or 0) + 1
		d0 = ((cv.SkinC * 0.618034) % 1) * 2 * Config.SkinSpan
	end
	local run = 0
	for i = 1, KN - 1 do
		local s = takeSpan(cv)
		place0(s, KP[i], KT[i], KY[i])
		place1(s, KP[i + 1], KT[i + 1], KY[i + 1])
		local c0, c1 = KH1[i], KH0[i + 1] * sign
		local seg = (c0 > 1e-4 or abs(c1) > 1e-4) and segC or 1
		local ec, es = e, eg
		if pal then
			local len = (KP[i + 1] - KP[i]).Magnitude
			local u0 = pingPong((d0 + run) / Config.SkinSpan)
			run += len
			local u1 = pingPong((d0 + run) / Config.SkinSpan)
			es = eg and skinEntry(pal, u0, u1, false, eg) or nil
			ec = skinEntry(pal, u0, u1, look ~= LOOK_GOLD, e)
		end
		beamWrite(s.Core, s.CS, ec, face, KW[i], KW[i + 1], c0, c1, seg, zc, nil)
		if eg then
			beamWrite(s.Sleeve, s.SS, es, face, KW[i] * sw, KW[i + 1] * sw, c0, c1, seg, 0, nil)
		else
			beamOff(s.Sleeve, s.SS)
		end
	end
	cv.Beams += (KN - 1) * (eg and 2 or 1)
	return true
end

--- a camera-facing (n nil) or flat (plane n) textured square of half-size `half` at p, turned by rot
--- (rot 0 = a spike pointing screen-up, counter-clockwise, as the kit's _star)
local function emitSprite(cv, p, half, look, level, rot, n, tex, z)
	if half <= 1e-4 then return end
	local u, v, nn
	if n == nil then
		nn = camDir(p)
		u = camUp - nn * camUp:Dot(nn)
		local m = u.Magnitude
		u = (m > 1e-6) and (u / m) or camRight
		v = nn:Cross(u)
	else
		u, v, nn = basis(n, camUp)
	end
	local d = u * cos(rot) + v * sin(rot)
	local s = takeSprite(cv)
	local y = (n == nil) and orientY(d, nil, nil, true) or orientY(d, nn, nil, false)
	place0(s, p - d * half, d, y)
	place1(s, p + d * half, d, y)
	local le = lookEntry(look, level)
	if cv.Palette then
		-- a mote or glint takes one palette colour, by its order in the frame (the same order every frame: no flicker)
		cv.SkinN = (cv.SkinN or 0) + 1
		local u = (cv.SkinN * 0.618034) % 1
		le = skinEntry(cv.Palette, u, u, look ~= LOOK_GOLD, le)
	end
	beamWrite(s.B, s.ST, le, n == nil, 2 * half, 2 * half, 0, 0, 1, z, tex)
	cv.Beams += 1
end

----------------------------------------------------------------------------------------------------
-- COUNTING
----------------------------------------------------------------------------------------------------
local function countP(cv, k, tag)
	if k == 0 then return end
	tag = tag or cv.CurTag
	cv.Pieces += k
	cv.TagPieces[tag] = (cv.TagPieces[tag] or 0) + k
end

local function countG(cv, k, tag)
	if k == 0 then return end
	tag = tag or cv.CurTag
	cv.Glints += k
	cv.TagGlints[tag] = (cv.TagGlints[tag] or 0) + k
end

local function countL(cv, k, tag)
	tag = tag or cv.CurTag
	cv.Lights += k
	cv.TagLights[tag] = (cv.TagLights[tag] or 0) + k
end

function Canvas:Count(n, tag) countP(self, n, tag) end
function Canvas:CountGlints(n, tag) countG(self, n, tag) end

function Canvas:Tag(name)
	self.CurTag = name or self.Name
end

local function opt(o, k, d)
	if o == nil then return d end
	local v = o[k]
	if v == nil then return d end
	return v
end

----------------------------------------------------------------------------------------------------
-- CANVAS LIFE
----------------------------------------------------------------------------------------------------
function RadiantDraw.new(name, prewarm, palette)
	ensureRoot()
	local cv = setmetatable({
		Name = name or "fx", CurTag = name or "fx", T = 0, gen = root.Gen,
		spans = {}, sprites = {}, lights = {},
		nSpan = 0, nSprite = 0, nLight = 0, uSpan = 0, uSprite = 0, uLight = 0,
		Pieces = 0, Glints = 0, Lights = 0, Beams = 0,
		TagPieces = {}, TagGlints = {}, TagLights = {},
		Peak = { Pieces = 0, PiecesT = 0, Glints = 0, GlintsT = 0, Lights = 0, LightsT = 0, Beams = 0 },
		warnedP = false, warnedG = false, warnedL = false, Dead = false,
		Palette = palette, SkinN = 0,          -- a skin's palette (SkinCatalog), nil = Default
	}, Canvas)
	if prewarm then
		for i = 1, prewarm.Spans or 0 do cv.spans[i] = table.remove(freeSpans) or newSpan() end
		for i = 1, prewarm.Sprites or 0 do cv.sprites[i] = table.remove(freeSprites) or newSprite() end
		for i = 1, prewarm.Lights or 0 do cv.lights[i] = table.remove(freeLights) or newLight() end
	end
	return cv
end

function Canvas:Begin(t)
	ensureRoot()
	self.SkinN, self.SkinC, self.SkinL = 0, 0, 0
	if self.gen ~= root.Gen then                         -- the folder was rebuilt: our old slots are gone
		self.gen = root.Gen
		table.clear(self.spans)
		table.clear(self.sprites)
		table.clear(self.lights)
		self.uSpan, self.uSprite, self.uLight = 0, 0, 0
	end
	camRefresh()
	self.T = t or 0
	self.nSpan, self.nSprite, self.nLight = 0, 0, 0
	self.Pieces, self.Glints, self.Lights, self.Beams = 0, 0, 0, 0
	for k in pairs(self.TagPieces) do self.TagPieces[k] = 0 end
	for k in pairs(self.TagGlints) do self.TagGlints[k] = 0 end
	for k in pairs(self.TagLights) do self.TagLights[k] = 0 end
	self.CurTag = self.Name
end

function Canvas:End()
	local spans, sprites, lights = self.spans, self.sprites, self.lights
	for i = self.nSpan + 1, self.uSpan do spanOff(spans[i]) end
	for i = self.nSprite + 1, self.uSprite do spriteOff(sprites[i]) end
	for i = self.nLight + 1, self.uLight do lightOff(lights[i]) end
	self.uSpan, self.uSprite, self.uLight = self.nSpan, self.nSprite, self.nLight
	local P, B = self.Peak, Config.Budget
	if self.Pieces > P.Pieces then P.Pieces, P.PiecesT = self.Pieces, self.T end
	if self.Glints > P.Glints then P.Glints, P.GlintsT = self.Glints, self.T end
	if self.Lights > P.Lights then P.Lights, P.LightsT = self.Lights, self.T end
	if self.Beams > P.Beams then P.Beams = self.Beams end
	if self.Pieces > B.Pieces and not self.warnedP then
		self.warnedP = true
		warn(string.format("[RadiantDraw] %s: %d pieces at t=%.2f (budget %d)", self.Name, self.Pieces, self.T, B.Pieces))
	end
	if self.Glints > B.Glints and not self.warnedG then
		self.warnedG = true
		warn(string.format("[RadiantDraw] %s: %d glints at t=%.2f (budget %d)", self.Name, self.Glints, self.T, B.Glints))
	end
	if self.Lights > B.Lights and not self.warnedL then
		self.warnedL = true
		warn(string.format("[RadiantDraw] %s: %d lights at t=%.2f (budget %d)", self.Name, self.Lights, self.T, B.Lights))
	end
	return self.Pieces, self.Glints, self.Lights
end

--- hide everything this canvas drew (keeps the pool)
function Canvas:Clear()
	self:Begin(self.T)
	self:End()
end

function Canvas:Budget()
	local tags = {}
	for k, v in pairs(self.TagPieces) do tags[k] = { Pieces = v, Glints = 0, Lights = 0 } end
	for k, v in pairs(self.TagGlints) do
		tags[k] = tags[k] or { Pieces = 0, Glints = 0, Lights = 0 }
		tags[k].Glints = v
	end
	for k, v in pairs(self.TagLights) do
		tags[k] = tags[k] or { Pieces = 0, Glints = 0, Lights = 0 }
		tags[k].Lights = v
	end
	local P = self.Peak
	return {
		Pieces = self.Pieces, Glints = self.Glints, Lights = self.Lights, Beams = self.Beams,
		Peak = { Pieces = P.Pieces, PiecesT = P.PiecesT, Glints = P.Glints, GlintsT = P.GlintsT,
			Lights = P.Lights, LightsT = P.LightsT, Beams = P.Beams },
		Tags = tags,
		Slots = { Spans = #self.spans, Sprites = #self.sprites, Lights = #self.lights },
	}
end

function Canvas:Destroy()
	if self.Dead then return end
	self.Dead = true
	local keep = Config.PoolKeep
	local alive = (self.gen == root.Gen)
	for _, s in ipairs(self.spans) do
		spanOff(s)
		if alive and #freeSpans < keep.Spans then table.insert(freeSpans, s) else destroySlot(s) end
	end
	for _, s in ipairs(self.sprites) do
		spriteOff(s)
		if alive and #freeSprites < keep.Sprites then table.insert(freeSprites, s) else destroySlot(s) end
	end
	for _, s in ipairs(self.lights) do
		lightOff(s)
		if alive and #freeLights < keep.Lights then table.insert(freeLights, s) else destroySlot(s) end
	end
	table.clear(self.spans)
	table.clear(self.sprites)
	table.clear(self.lights)
	self.uSpan, self.uSprite, self.uLight = 0, 0, 0
end

function RadiantDraw.Stats()
	return { FreeSpans = #freeSpans, FreeSprites = #freeSprites, FreeLights = #freeLights, Generation = root.Gen }
end

----------------------------------------------------------------------------------------------------
-- STROKES
----------------------------------------------------------------------------------------------------
--- the kit's _line: one stroke through pts (prof = per-point width multipliers), not counted
function Canvas:Line(pts, level, w, n, bezel, prof, smoothC)
	level = level or 0.5
	kPoints(pts, smoothC, 1e-5, false)
	if KN < 2 then return false end
	if prof then
		-- prof is per INPUT point; exact when no duplicates were dropped
		for i = 1, KN do KM[i] = prof[i] or 1 end
	end
	return emitChain(self, level, w or lw(level), n, nil, bezel ~= false, LOOK_CORE)
end

local function segCore(cv, p0, p1, level, w, n, bezel)
	kStraight(p0, p1)
	return emitChain(cv, level, w or lw(level), n, nil, bezel ~= false, LOOK_CORE)
end

function Canvas:Seg(p0, p1, level, w, n, bezel, tag)
	level = level or 0.5
	if segCore(self, p0, p1, level, w, n, bezel) then countP(self, 1, tag) end
end

function Canvas:Polyline(pts, level, o)
	level = level or 0.5
	local u = opt(o, "u", 1)
	kPoints(pts, false, 1e-9, opt(o, "closed", false))
	local first = (KN > 0) and KP[1] or nil
	kCut(u)
	if KN < 2 then return (u > 0) and first or nil end
	local segs = KN - 1
	kHead(u < 1 - 1e-6)
	if emitChain(self, level, opt(o, "w", nil) or lw(level), opt(o, "n", nil), nil, opt(o, "bezel", true), LOOK_CORE) then
		countP(self, opt(o, "rigid", false) and 1 or segs, opt(o, "tag", nil))
	end
	return KP[KN]
end

local function arcStrokes(cv, c, ux, vx, nn, r, b0, b1, head, level, w)
	kArc(c, ux, vx, r, b0, b1)
	kHead(head)
	if emitChain(cv, level, w or lw(level), nn, nil, true, LOOK_CORE) then
		return max(1, ceil(abs(b1 - b0) / (pi / 2) - 1e-6))
	end
	return 0
end

local function ringCore(cv, c, r, n, level, a0, a1, u, ticks, long_every, tlS, tlL, tick_in, dashes, duty, ref, w, face)
	local ux, vx, nn = basis(n, ref)
	if face then nn = nil end                          -- Phase 5: FaceCamera strips (a ring seen edge-on stays visible)
	local sweep = (a1 - a0) * clamp(u, 0, 1)
	if abs(sweep) < 1e-6 then return 0, c + (ux * cos(a0) + vx * sin(a0)) * r end
	local drawing = u < 1 - 1e-6
	local strokes = 0
	if dashes and dashes > 0 then
		local D = (a1 - a0) / dashes
		for j = 0, dashes - 1 do
			local d0 = a0 + j * D
			if abs(d0 - a0) >= abs(sweep) then break end
			local d1 = d0 + D * duty
			local head = drawing and abs(d1 - a0) > abs(sweep)
			if abs(d1 - a0) > abs(sweep) then d1 = a0 + sweep end
			strokes += arcStrokes(cv, c, ux, vx, nn, r, d0, d1, head, level, w)
		end
	else
		strokes += arcStrokes(cv, c, ux, vx, nn, r, a0, a0 + sweep, drawing, level, w)
	end
	if ticks and ticks > 0 then
		local t0 = tlS or max(0.1, 0.064 * r)
		local t1 = tlL or max(0.18, 0.136 * r)
		local sg = tick_in and -1 or 1
		local dir = (sweep >= 0) and 1 or -1
		for j = 0, ticks - 1 do
			local a = a0 + dir * j * TAU / ticks
			if abs(a - a0) > abs(sweep) + 1e-9 then break end
			local g = drawing and smooth((abs(sweep) - abs(a - a0)) / 0.35) or 1
			if g >= 0.03 then
				local ln = ((j % long_every == 0) and t1 or t0) * g
				local e = ux * cos(a) + vx * sin(a)
				kStraight(c + e * (r + 0.02 * sg), c + e * (r + max(ln, 0.03) * sg))
				if emitChain(cv, level, (w or lw(level)) * 0.9 * (0.5 + 0.5 * g), nn, nil, true, LOOK_CORE) then
					strokes += 1
				end
			end
		end
	end
	return strokes, c + (ux * cos(a0 + sweep) + vx * sin(a0 + sweep)) * r
end

function Canvas:Ring(c, r, n, level, o)
	n, level = n or UP, level or 0.5
	local tl = opt(o, "tick_len", nil)
	local strokes, endP = ringCore(self, c, r, n, level, opt(o, "a0", 0), opt(o, "a1", TAU), opt(o, "u", 1),
		opt(o, "ticks", 0), opt(o, "long_every", 6), tl and tl[1], tl and tl[2], opt(o, "tick_in", false),
		opt(o, "dashes", 0), opt(o, "duty", 0.55), opt(o, "ref", nil), opt(o, "w", nil), opt(o, "face", false))
	countP(self, (opt(o, "rigid", false) and strokes > 0) and 1 or strokes, opt(o, "tag", nil))
	return endP
end

local function spiralPD(c, ux, vx, a0, sgn, turns, r0, r1, grow, s)
	local a = a0 + sgn * TAU * turns * s
	local ca, sa = cos(a), sin(a)
	local rr = r0 + (r1 - r0) * (s ^ grow)
	local e = ux * ca + vx * sa
	local te = (vx * ca - ux * sa) * sgn
	local dr = (r1 - r0) * grow * max(s, 1e-4) ^ (grow - 1)
	return c + e * rr, e * dr + te * (rr * TAU * turns)
end

local function spiralPush(c, ux, vx, a0, sgn, turns, r0, r1, grow, s)
	local p, d = spiralPD(c, ux, vx, a0, sgn, turns, r0, r1, grow, s)
	local sp = d.Magnitude
	KN += 1
	KP[KN], KT[KN], KM[KN], KS[KN], KSP[KN] = p, (sp > 1e-9) and (d / sp) or UP, 1, s, sp
end

function Canvas:Spiral(c, n, r0, r1, turns, u, level, o)
	u, level = clamp(u or 1, 0, 1), level or 0.5
	local a0, tail, grow = opt(o, "a0", 0), opt(o, "tail", nil), opt(o, "grow", 1)
	local sgn = opt(o, "cw", false) and -1 or 1
	local ux, vx, nn = basis(n, opt(o, "ref", nil))
	local s0 = tail and max(0, u - tail) or 0
	if u > s0 then
		KN = 0
		local ds = 1 / max(1, 4 * turns)                   -- a knot every quarter turn: one curved Beam per <= 90 deg
		spiralPush(c, ux, vx, a0, sgn, turns, r0, r1, grow, s0)
		local j = floor(s0 / ds) + 1
		while j * ds < u - 1e-9 do
			spiralPush(c, ux, vx, a0, sgn, turns, r0, r1, grow, j * ds)
			j += 1
		end
		spiralPush(c, ux, vx, a0, sgn, turns, r0, r1, grow, u)
		KH0[1] = 0
		KH1[KN] = 0
		for i = 1, KN - 1 do
			local dsI = KS[i + 1] - KS[i]
			local dth = TAU * turns * dsI
			local k = (dth > 1e-4) and (4 * tan(dth / 4) / dth) or 1   -- circle-exact Hermite handles
			KH1[i] = KSP[i] * dsI / 3 * k
			KH0[i + 1] = KSP[i + 1] * dsI / 3 * k
		end
		if tail then
			local L = kLengths()
			kTaper(min(Config.HEAD_TAPER, L * 0.3), L * 0.6, 0.35, 0)
		else
			kHead(u < 1 - 1e-6)
		end
		if emitChain(self, level, opt(o, "w", nil) or lw(level), nn, nil, true, LOOK_CORE) then
			countP(self, max(1, ceil(turns * (u - s0) * 4 - 1e-6)), opt(o, "tag", nil))
		end
	end
	local pEnd = spiralPD(c, ux, vx, a0, sgn, turns, r0, r1, grow, u)
	return pEnd, a0 + sgn * TAU * turns * u
end

local function rosetteCore(cv, c, n, r, level, spokes, s_in, s_out, phase, u, ref, w, grow)
	if u <= 0 then return 0 end
	local ux, vx, nn = basis(n, ref)
	w = w or lw(level)
	if grow then
		local g = min(u, 1)
		r, w, u = r * g, w * g, 1
	end
	local ph = phase or ((spokes == 8) and (pi / spokes) or 0)
	local strokes = ringCore(cv, c, r, n, level, 0, TAU, u, 0, 6, nil, nil, false, 0, 0.55, ref, w)
	for j = 0, spokes - 1 do
		local a = ph + j * TAU / spokes
		if a > TAU * u + 1e-9 then break end
		local g = (u >= 1 - 1e-6) and 1 or smooth((TAU * u - a) / 0.5)
		if g >= 0.03 then
			local e = ux * cos(a) + vx * sin(a)
			kStraight(c + e * (r * s_in), c + e * (r * (s_in + (s_out - s_in) * g)))
			if emitChain(cv, level, w * 0.9 * (0.5 + 0.5 * g), nn, nil, true, LOOK_CORE) then strokes += 1 end
		end
	end
	return strokes
end

function Canvas:Rosette(c, n, r, level, o)
	level = level or 0.5
	local u, grow = opt(o, "u", 1), opt(o, "grow", false)
	if u <= 0 then return end
	local strokes = rosetteCore(self, c, n, r, level, opt(o, "spokes", 8), opt(o, "s_in", 1.22), opt(o, "s_out", 1.72),
		opt(o, "phase", nil), u, opt(o, "ref", nil), opt(o, "w", nil), grow)
	local whole = (opt(o, "rigid", true) or grow) and (grow or u >= 1 - 1e-6)
	countP(self, whole and 1 or strokes, opt(o, "tag", nil))
end

function Canvas:Sigil(c, r, level, o)
	level = level or 0.5
	local u, spokes, inner = opt(o, "u", 1), opt(o, "spokes", 24), opt(o, "inner", 0.8)
	local n = opt(o, "n", UP)
	if opt(o, "flat", true) then c = c + n.Unit * Config.FloorLift end
	local strokes = ringCore(self, c, r * 0.98, n, level, 0, TAU, u, 0, 6, nil, nil, false, 0, 0.55, nil, nil)
	strokes += ringCore(self, c, r * inner, n, level, 0, TAU, u, 0, 6, nil, nil, false, 0, 0.55, nil, nil)
	local ux, vx, nn = basis(n)
	for j = 0, spokes - 1 do
		local a = j * TAU / spokes + pi / spokes
		if a > TAU * u + 1e-9 then break end
		local g = (u >= 1 - 1e-6) and 1 or smooth((TAU * u - a) / 0.4)
		if g >= 0.03 then
			local e = ux * cos(a) + vx * sin(a)
			kStraight(c + e * (r * inner), c + e * (r * (inner + (0.98 - inner) * g)))
			if emitChain(self, level, lw(level) * 0.9 * (0.5 + 0.5 * g), nn, nil, true, LOOK_CORE) then
				strokes += 1
			end
		end
	end
	countP(self, (opt(o, "rigid", false) and u >= 1 - 1e-6) and 1 or strokes, opt(o, "tag", nil))
end

local function chevronCore(cv, p, d, level, size, spread, n, w)
	d = d.Unit
	local s = (n or camDir(p)):Cross(d)
	if s.Magnitude < 1e-6 then s = ortho(d) else s = s.Unit end
	w = (w or lw(level)) * 0.9
	local ok = false
	kStraight(p - d * size + s * (size * spread), p)
	ok = emitChain(cv, level, w, n, nil, true, LOOK_CORE) or ok
	kStraight(p - d * size - s * (size * spread), p)
	ok = emitChain(cv, level, w, n, nil, true, LOOK_CORE) or ok
	return ok
end

function Canvas:Chevron(p, d, level, o)
	level = level or 0.5
	if chevronCore(self, p, d, level, opt(o, "size", 0.2), opt(o, "spread", 0.75), opt(o, "n", nil), opt(o, "w", nil)) then
		countP(self, 1, opt(o, "tag", nil))
	end
end

function Canvas:Bond(src, dst, u, level, o)
	u, level = clamp(u or 1, 0, 1), level or 0.5
	local tag = opt(o, "tag", nil)
	local D = dst - src
	local L = D.Magnitude
	local d = D / max(L, 1e-9)
	local n = opt(o, "n", nil)
	local w = opt(o, "w", nil) or lw(level) * 0.78
	if opt(o, "src_sigil", true) and u > 0 then
		rosetteCore(self, src, d, 0.36, level, 8, 1.22, 1.72, nil, clamp(u / 0.15, 0, 1), nil, w, true)
		countP(self, 1, tag)
	end
	local lead = src + d * (L * u)
	if u <= 0 then return lead end
	if segCore(self, src, lead, level, w, n, true) then countP(self, 1, tag) end
	local t = 1.0
	local step = max(opt(o, "spacing", 0.9), (L - 1.45) / max(1, opt(o, "max_chev", 6)))
	while t < L - 0.45 and t <= L * u do
		local g = (u >= 1 - 1e-6) and 1 or smooth((L * u - t) / 0.35)
		if g > 0.03 and chevronCore(self, src + d * t, d, level, 0.2 * g, 0.75, n, w * (0.5 + 0.5 * g)) then
			countP(self, 1, tag)
		end
		t += step
	end
	if opt(o, "pulse", true) then
		local cpos
		if u < 1 then
			cpos = max(0.3, L * u - 0.3)
		else
			local ph = opt(o, "ph", nil)
			cpos = L * (ph or ((self.T / opt(o, "period", 0.7)) % 1))
		end
		local a, b = max(0, cpos - 0.275), min(L * u, cpos + 0.275)
		if b - a > 0.05 and segCore(self, src + d * a, src + d * b, min(1, level + 0.15), w * 1.7, n, false) then
			countP(self, 1, tag)
		end
	end
	if opt(o, "seal", true) and u > 0.9 then
		rosetteCore(self, dst, d, 0.28, level, 6, 1.21, 1.79, 0, min(1, (u - 0.9) / 0.1), nil, w, true)
		countP(self, 1, tag)
	end
	return lead
end

function Canvas:Stroke(pts, level, o)
	level = level or 0.5
	kPoints(pts, opt(o, "smooth_k", 0) > 0, 1e-5, false)
	if KN < 2 then return end
	local taper, lo = opt(o, "taper", nil), opt(o, "lo", nil)
	local tt, th = taper and taper[1] or 0, taper and taper[2] or 0
	if tt > 0 or th > 0 then kTaper(th, tt, lo and lo[2] or 0, lo and lo[1] or 0) end
	if emitChain(self, level, opt(o, "w", nil) or lw(level), opt(o, "n", nil), nil, opt(o, "sleeve", true), LOOK_CORE) then
		countP(self, opt(o, "pieces", 1), opt(o, "tag", nil))
	end
end

function Canvas:Trail(history, level, o)
	level = level or 0.8
	kPoints(history, true, 1e-4, false)
	if KN < 2 then return end
	local tot = kLengths()
	if tot < 0.01 then return end
	local lo = opt(o, "lo", 0)
	local s = 0
	for i = 1, KN do
		KM[i] = lo + (1 - lo) * (s / tot) ^ 1.4
		if i < KN then s += SL[i] end
	end
	if emitChain(self, level, opt(o, "w", nil) or lw(level), opt(o, "n", nil), nil, true, LOOK_CORE) then
		countP(self, 1, opt(o, "tag", nil))
	end
end

----------------------------------------------------------------------------------------------------
-- STARS, GLINTS, MOTES
----------------------------------------------------------------------------------------------------
--- half-width at the centre of a spike Beam (centre -> tip) whose edge passes the kit's inner star vertex
local function spikeHalf(L, rIn, m)
	local xi, yi = rIn * cos(pi / m), rIn * sin(pi / m)
	if L <= xi + 1e-6 then return yi end
	return yi / (1 - xi / L)
end

--- the kit's _star: m spikes (even j long, odd j short), cream core + gold star behind (sleeveMul longer)
local function starCore(cv, c, m, Llong, Lshort, rIn, level, rot, n, ref, sleeveMul)
	local nrm = n and n.Unit or camDir(c)
	local ux, vx = basis(nrm, ref or camUp)
	for pass = 1, 2 do
		local gold = (pass == 1)
		if not gold or (sleeveMul and sleeveMul > 0) then
			for j = 0, m - 1 do
				local a = rot + j * TAU / m
				local e = ux * cos(a) + vx * sin(a)
				local L, ri = ((j % 2 == 0) and Llong or Lshort), rIn
				if gold then L, ri = L * sleeveMul + 0.012, rIn * 1.9 + 0.01 end
				KN = 0
				kpush(c, e, 0, 0, 1)
				kpush(c + e * L, e, 0, 0, 0)
				emitChain(cv, level, 2 * spikeHalf(L, ri, m), n and nrm or nil, nil, false,
					gold and LOOK_GOLD or LOOK_CORE, gold and 0 or Config.CoreZOffset)
			end
		end
	end
end

local function glintCore(cv, p, size, level, rot, n, short, tag)
	if size <= 1e-3 then return end
	local tex = (short and short > 0) and Config.GlintTexture8 or Config.GlintTexture4
	local k = Config.GlintScale
	if Config.GlintSleeve then emitSprite(cv, p, (size * 1.35 + 0.012) * k, LOOK_GOLD, level, rot, n, tex, 0) end
	emitSprite(cv, p, size * k, LOOK_CORE, level, rot, n, tex, Config.CoreZOffset)
	countG(cv, 1, tag)
end

function Canvas:Glint(p, size, level, rot, n, short, tag)
	glintCore(self, p, size or 0.12, level or 1, rot or 0, n, short or 0, tag)
end

--- one mote: a gold dot + cream core, with a tapered trail behind it along -dir. Returns true if a trail was drawn.
local function moteCore(cv, p, s, level, dir, tl, nominal)
	local k = Config.MoteScale
	emitSprite(cv, p, s * k, LOOK_GOLD, level, 0, nil, Config.MoteTexture, 0)
	emitSprite(cv, p, s * 0.55 * k, LOOK_CORE, level, 0, nil, Config.MoteTexture, Config.CoreZOffset)
	if dir and tl > 0 and s > 0.006 then
		local dm = dir.Magnitude
		if dm > 1e-6 then
			local dv = dir / dm
			local L = tl * min(1, s / max(nominal, 1e-6))
			KN = 0
			kpush(p - dv * (s * 0.6), -dv, 0, 0, 1)
			kpush(p - dv * (s * 0.6 + L), -dv, 0, 0, 0)
			return emitChain(cv, level, s * 0.6, nil, nil, true, LOOK_CORE)
		end
	end
	return false
end

function Canvas:Mote(p, size, level, dir, trail_len, as_particle, tag)
	if size <= 0 then return end
	local tr = moteCore(self, p, size, level or 1, dir, trail_len or 0, size)
	if as_particle then countG(self, 1, tag) else countP(self, tr and 2 or 1, tag) end
end

function Canvas:Motes(points, level, o)
	level = level or 1
	local size, sizes, trails = opt(o, "size", 0.07), opt(o, "sizes", nil), opt(o, "trails", nil)
	local tl, asP = opt(o, "trail_len", 0.4), opt(o, "as_particles", false)
	local k = 0
	for i = 1, #points do
		local s = sizes and sizes[i] or size
		if s > 0 then
			k += 1
			local tr = trails and trails[i] or nil
			if moteCore(self, points[i], s, level, tr or nil, tr and tl or 0, size) and not asP then k += 1 end
		end
	end
	if asP then countG(self, k, opt(o, "tag", nil)) else countP(self, k, opt(o, "tag", nil)) end
end

--- the kit's _cycles for particle i: (age 0..1, birth time) or nil; seeds the stream for this particle's cycle
local function cycleAt(t, i, life, t0, t1, seed)
	local ph = RadiantDraw.Rand(seed, i, 0x51, 1) * life
	local since = t - t0 - ph
	if since < 0 then return nil end
	local cyc = floor(since / life)
	local born = t0 + ph + cyc * life
	if born > t1 then
		cyc -= 1
		born -= life
		if cyc < 0 or t - born >= life then return nil end
	end
	rsSeed(seed * 7919 + i * 131, cyc, 17)
	return (t - born) / life, born
end

local function regionPoint(region, radius, normal)
	if type(region) == "function" then return region(rsNext) end
	if region == "ring" or region == "disc" then
		local ux, vx, n = basis(normal)
		local a = rsNext() * TAU
		local rr
		if region == "ring" then rr = radius * (1 + (rsNext() * 0.16 - 0.08)) else rr = radius * sqrt(rsNext()) end
		return (ux * cos(a) + vx * sin(a)) * rr + n * ((rsNext() * 0.1 - 0.05) * radius)
	end
	local d = randDir()
	return d * (radius * ((region == "shell") and 1 or rsNext() ^ (1 / 3)))
end

local DRIFT = UP * 0.25

function Canvas:Sparkles(c, radius, t, o)
	local n, seed, level, size = opt(o, "n", 10), opt(o, "seed", 7), opt(o, "level", 1), opt(o, "size", 0.1)
	local life, t0, t1 = opt(o, "life", 0.8), opt(o, "t0", 0), opt(o, "t1", 1e9)
	local drift, region, normal, spin = opt(o, "drift", DRIFT), opt(o, "region", "sphere"), opt(o, "normal", UP),
		opt(o, "spin", 0.8)
	local tag = opt(o, "tag", nil)
	local cfn = type(c) == "function"
	for i = 0, n - 1 do
		local age, born = cycleAt(t, i, life, t0, t1, seed)
		if age then
			local cc = cfn and c(born) or c
			local p = cc + regionPoint(region, radius, normal) + drift * (age * life)
			local k = sin(pi * age) ^ 0.7 * (0.82 + 0.18 * sin(TAU * (age * life * 3 + rsNext())))
			local sz = size * (0.55 + 0.45 * rsNext()) * k
			local rot = rsNext() * (pi / 2) + spin * age * life
			local short = (rsNext() < 0.7) and 0 or 0.45
			glintCore(self, p, sz, level, rot, nil, short, tag)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- HOLY RAYS, FLARE, LIGHT
----------------------------------------------------------------------------------------------------
function Canvas:HolyRays(c, u, o)
	local n, r0, length, width = opt(o, "n", 13), opt(o, "r0", 0.3), opt(o, "length", 1.8), opt(o, "width", 0.18)
	local normal, axis, fan, level = opt(o, "normal", nil), opt(o, "axis", nil), opt(o, "fan", TAU), opt(o, "level", 1)
	local seed, stagger, jitter = opt(o, "seed", 3), opt(o, "stagger", 0.3), opt(o, "jitter", 0.25)
	local v, t, breathe, short = opt(o, "v", 0), opt(o, "t", nil), opt(o, "breathe", 0.06), opt(o, "short", 0.62)
	local nrm = normal and normal.Unit or camDir(c)
	local ax = axis and axis.Unit or UP
	local ux, vx, nn = basis(nrm, ax)
	if abs(nn:Dot(ax)) > 0.999 then ux, vx, nn = basis(nrm) end
	local flatN = normal and nn or nil                     -- nil: rays in the camera plane (FaceCamera)
	local vv = ramp(v, 0, 1)
	local sw = sleeve_w(level)
	local k = 0
	for j = 0, n - 1 do
		local dly = RadiantDraw.Rand(seed, j, 1) * stagger
		local jit = (RadiantDraw.Rand(seed, j, 2) * 2 - 1) * jitter
		local ph = RadiantDraw.Rand(seed, j, 3)
		local a = (fan >= TAU - 1e-6) and (j * TAU / n) or ((j / max(1, n - 1) - 0.5) * fan)
		local uj = clamp((u - dly) / max(1e-6, 1 - stagger), 0, 1)
		if uj > 0 then
			local long = (j % 2 == 0)
			local L = length * (long and 1 or short) * (1 + jit) * ease_out_back(uj, 1.4)
			if t and breathe ~= 0 then L *= 1 + breathe * sin(TAU * (t * 0.7 + ph)) end
			L *= 1 - vv
			if L >= 0.02 then
				local e = ux * cos(a) + vx * sin(a)
				local p0 = c + e * r0
				local wj = width * (long and 1 or 0.8) * (1 - 0.5 * vv) * (0.6 + 0.4 * smooth(uj / 0.4))
				-- the kit's 5-point blade profile [.75, 1, .72, .4, 0] at [0, .2, .45, .7, 1] as 2 linear spans
				KN = 0
				kpush(p0, e, 0, 0, 0.75)
				kpush(p0 + e * (0.2 * L), e, 0, 0, 1)
				kpush(p0 + e * L, e, 0, 0, 0)
				if emitChain(self, level, wj / sw, flatN, nil, true, LOOK_CORE) then k += 1 end
			end
		end
	end
	countP(self, k, opt(o, "tag", nil))
end

function Canvas:Flare(p, u, o)
	if u <= 0 or u >= 1 then return end
	local size, level, points = opt(o, "size", 0.8), opt(o, "level", 1), opt(o, "points", 8)
	local rot, n, tag = opt(o, "rot", 0), opt(o, "n", nil), opt(o, "tag", nil)
	local grow = ease_out_back(clamp(u / 0.22, 0, 1), 1.6)
	local dec = 1 - smooth((u - 0.22) / 0.78)
	local s = size * grow * (0.35 + 0.65 * dec) * dec ^ 0.35
	if s > 0.01 then
		local lv = min(1, level * (0.55 + 0.45 * dec))
		starCore(self, p, max(4, points), s, s * 0.52, s * 0.15 * (0.55 + 0.45 * dec), lv, rot + math.rad(20) * u, n,
			nil, 1.35)
		countP(self, 1, tag)
	end
	if opt(o, "shock", true) and dec > 0.04 then
		local nn = n or camDir(p)
		local st = ringCore(self, p, size * (0.3 + 0.95 * ease("Quad", u)), nn, min(1, level * dec), 0, TAU, 1, 0, 6,
			nil, nil, false, 0, 0.55, nil, lw(level) * (0.35 + 0.85 * dec))
		countP(self, st, tag)
	end
	glintCore(self, p + camDir(p) * 0.02, size * 0.42 * grow * dec, min(1, level), rot + 0.3, n, 0, tag)
end

function Canvas:LightPool(p, level, o)
	local lvl = max(0, level or 1)
	if lvl <= 1e-3 then return nil end
	local energy, col, range = opt(o, "energy", nil), opt(o, "color", C.LIGHT), opt(o, "range", Config.LightRange)
	if self.Palette then   -- a skin: each light one palette colour, by its order in the frame
		self.SkinL = (self.SkinL or 0) + 1
		col = self.Palette.At((self.SkinL * 0.381966) % 1)
	end
	local s = takeLight(self)
	if s.p ~= p then s.p = p; s.Att.Position = p end
	local b = Config.LightBrightness * lvl * ((energy or Config.LightW) / Config.LightW)
	if s.b ~= b then s.b = b; s.L.Brightness = b end
	if s.r ~= range then s.r = range; s.L.Range = range end
	if s.c ~= col then s.c = col; s.L.Color = col end
	if not s.on then s.on = true; s.L.Enabled = true end
	countL(self, 1, opt(o, "tag", nil))
	return s.L
end

----------------------------------------------------------------------------------------------------
-- MOTE FIELD, GATHER, ORNAMENTS, STAFF AURA
----------------------------------------------------------------------------------------------------
function Canvas:MoteField(c, radius, t, o)
	local n, seed, level, size = opt(o, "n", 10), opt(o, "seed", 11), opt(o, "level", 0.8), opt(o, "size", 0.055)
	local rise, life, t0, t1 = opt(o, "rise", 0.9), opt(o, "life", 1.4), opt(o, "t0", 0), opt(o, "t1", 1e9)
	local sink, sway, tl, height = opt(o, "sink", false), opt(o, "sway", 0.12), opt(o, "trail_len", 0.22),
		opt(o, "height", 0.3)
	local tag = opt(o, "tag", nil)
	local cfn = type(c) == "function"
	local dirv = sink and -UP or UP
	local k = 0
	for i = 0, n - 1 do
		local age, born = cycleAt(t, i, life, t0, t1, seed)
		if age then
			local cc = cfn and c(born) or c
			local a, rr = rsNext() * TAU, radius * sqrt(rsNext())
			local z0 = rsNext() * height + (sink and rise * life or 0)
			local dz = (sink and -1 or 1) * rise * age * life
			local ph = rsNext() * 6.28
			local sw = sway * sin(ph + age * life * 3)
			-- Blender (x, y, z) offsets -> Roblox (-x, z, y)
			local p = cc + Vector3.new(-(cos(a) * rr + sw * cos(ph)), z0 + dz, sin(a) * rr + sw * sin(ph))
			local s = size * (0.6 + 0.4 * rsNext()) * sin(pi * age) ^ 0.6
			if s > 0 then
				moteCore(self, p, s, level, dirv, tl, size)
				k += 1
			end
		end
	end
	countG(self, k, tag)
end

local function gatherPos(p, d, ax, turns, r0, e)
	return p + rotAbout(d, ax, turns * TAU * e) * (r0 * (1 - e) ^ 1.2)
end

function Canvas:Gather(p, u, o)
	if u <= 0 then return end
	local radius, n, level, seed = opt(o, "radius", 0.9), opt(o, "n", 8), opt(o, "level", 0.9), opt(o, "seed", 5)
	local size, turns, gsize, t = opt(o, "size", 0.05), opt(o, "turns", 0.6), opt(o, "glint_size", 0.3), opt(o, "t", 0)
	local tag = opt(o, "tag", nil)
	local k = 0
	for i = 0, n - 1 do
		rsSeed(seed, i, 0x6A7)
		local d = randDir()
		local ax = rotAbout(ortho(d), d, rsNext() * TAU)
		local dly, r0 = rsNext() * 0.35, radius * (0.65 + 0.35 * rsNext())
		local e = (u < 1) and ease("Quad", clamp((u - dly) / 0.65, 0, 1)) or 1
		if e > 0 and e < 0.995 then
			local cur = gatherPos(p, d, ax, turns, r0, e)
			local prev = gatherPos(p, d, ax, turns, r0, max(0, e - 0.08))
			local s = size * smooth(e / 0.15) * (1 - smooth((e - 0.7) / 0.3))
			if s > 0 then
				moteCore(self, cur, s, level, cur - prev, 0.18, size)
				k += 1
			end
		end
	end
	countG(self, k, tag)
	local g = ramp(u, 0, 1)
	glintCore(self, p + camDir(p) * 0.03, gsize * g * (1 + 0.1 * sin(TAU * 2.2 * t)), min(1, level * (0.6 + 0.4 * g)),
		0.4 * t, nil, 0.45, tag)
end

local function starStudCore(cv, p, normal, size, level, points, rot)
	starCore(cv, p, points, size, (points <= 4) and size or size * 0.55, size * 0.3, level, rot, normal, nil, 1.3)
end

function Canvas:StarStud(p, normal, size, level, points, rot, tag)
	starStudCore(self, p, normal, size or 0.07, level or 0.8, points or 4, rot or 0)
	countP(self, 1, tag)
end

function Canvas:Clasp(c, axis, o)
	local u = opt(o, "u", 1)
	if u <= 0 then return end
	local r, width, level = opt(o, "r", 0.2), opt(o, "width", 0.12), opt(o, "level", 0.6)
	local th = opt(o, "th", 0.035)
	local s = ease_out_back(clamp(u, 0, 1), 1.5)
	local ax = axis.Unit
	local ux, vx = basis(ax)
	local rr, hw, tt = r * s, width * s / 2, th * s
	local lv = clamp(level, 0, 1)
	-- the band: a cylindrical gold strip, its width along the axis
	kArc(c, ux, vx, rr + tt / 2, 0, TAU)
	emitChain(self, lv, 2 * hw, nil, ax, false, LOOK_GOLD, 0)
	-- cream rims: the band's edges catch the light
	for sg = 1, -1, -2 do
		ringCore(self, c + ax * (hw * sg), rr + tt / 2 + 0.002, ax, min(1, lv + 0.1), 0, TAU, 1, 0, 6, nil, nil, false,
			0, 0.55, nil, 0.012 + 0.01 * s)
	end
	if opt(o, "stud", true) then
		local f = opt(o, "front", nil) or camDir(c)
		f = f - ax * f:Dot(ax)
		f = (f.Magnitude > 1e-6) and f.Unit or ux
		starStudCore(self, c + f * (rr + tt / 2 + 0.006), f, max(0.035, width * 0.62 * s), min(1, lv + 0.2), 4, 0)
	end
	countP(self, 1, opt(o, "tag", nil))
end

local AURA_DRIFT = UP * 0.12
local AURA_OPT = { n = 6, seed = 17, level = 1, size = 0.1, life = 0.9, drift = AURA_DRIFT, tag = nil }
local AURA_LIGHT = { tag = nil }

function Canvas:StaffAura(p, level, t, o)
	local l = clamp(level, 0, 1)
	if l <= 0.02 then return end
	local tag = opt(o, "tag", nil)
	glintCore(self, p, (0.1 + 0.22 * l) * (1 + 0.08 * sin(TAU * 1.3 * t)), min(1, 0.45 + 0.55 * l), 0.25 * t, nil,
		0.4, tag)
	if opt(o, "sparkle", true) then
		AURA_OPT.seed, AURA_OPT.level, AURA_OPT.size, AURA_OPT.tag = opt(o, "seed", 17), min(1, 0.5 + 0.5 * l),
			0.1 * l, tag
		self:Sparkles(p, 0.3 + 0.2 * l, t, AURA_OPT)
	end
	if opt(o, "light", true) then
		AURA_LIGHT.tag = tag
		self:LightPool(p, 0.6 * l, AURA_LIGHT)
	end
end

----------------------------------------------------------------------------------------------------
-- THE STAFF'S ENGRAVING (the kit's staff_glow)
----------------------------------------------------------------------------------------------------
local staffQ = setmetatable({}, { __mode = "k" })
local staffPal = setmetatable({}, { __mode = "k" })   -- the palette each engraving part was last painted with

function RadiantDraw.StaffGlow(parts, level, palette)
	local q = floor(clamp(level, 0, 1) * LEVEL_Q + 0.5)
	local col = nil
	local key = palette and (q + 100000) or q
	for _, part in ipairs(parts) do
		if staffQ[part] ~= key or staffPal[part] ~= palette then   -- (the palette too: a wrap swapped at the same level)
			staffQ[part], staffPal[part] = key, palette
			-- a skin: the engraving runs through the palette as it charges (the idle staff shows its first colour)
			col = col or (palette and palette.At(q / LEVEL_Q)) or staff_look(q / LEVEL_Q)
			part.Material = (q / LEVEL_Q >= Config.StaffNeonFrom) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			part.Color = col
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE DRIVER: one RenderStep for every live effect, bound only while one lives
----------------------------------------------------------------------------------------------------
local STEP = "RadiantDraw"
local live = {}
local bound = false

local Effect = {}
Effect.__index = Effect

function Effect:Stop()
	self.Dead = true
end

local function finish(e)
	e.Dead = true
	if e.OnEnd then
		local ok, err = pcall(e.OnEnd, e)
		if not ok then warnOnce("onend:" .. e.Name, e.Name .. " OnEnd: " .. tostring(err)) end
	end
	e.Canvas:Destroy()
end

local function driver(dt)
	local i = 1
	while i <= #live do
		local e = live[i]
		local keep = not e.Dead
		if keep then
			local t = e.Clock()
			if (e.Until and t > e.Until) or (os.clock() - e.Born > e.MaxLife) then
				keep = false
			else
				local cv = e.Canvas
				cv:Begin(t)
				local ok, res = pcall(e.Fn, cv, t, dt, e)
				cv:End()
				if not ok then
					warnOnce("err:" .. e.Name, e.Name .. ": " .. tostring(res))
					keep = false
				elseif res == false then
					keep = false
				end
			end
		end
		if keep then
			i += 1
		else
			live[i] = live[#live]
			live[#live] = nil
			finish(e)
		end
	end
	if #live == 0 and bound then
		bound = false
		RunService:UnbindFromRenderStep(STEP)
	end
end

--- frameFn(cv, t, dt, handle) each render frame; return false to end. opts: T0 (server), Offset, Scale, Clock,
--- Until (clip s), MaxLife (s), Prewarm {Spans, Sprites, Lights}, OnEnd(handle)
function RadiantDraw.Play(name, frameFn, opts)
	opts = opts or {}
	local e = setmetatable({
		Name = name or "fx", Fn = frameFn, Canvas = RadiantDraw.new(name, opts.Prewarm, opts.Palette or pendingPalette),
		Clock = opts.Clock or RadiantDraw.Clock(opts.T0, opts.Offset, opts.Scale),
		Until = opts.Until, MaxLife = opts.MaxLife or Config.MaxLife, Born = os.clock(), OnEnd = opts.OnEnd,
		Dead = false,
	}, Effect)
	live[#live + 1] = e
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP, Config.RenderPriority, driver)
	end
	return e
end

function RadiantDraw.StopAll()
	for _, e in ipairs(live) do e.Dead = true end
end

return RadiantDraw
