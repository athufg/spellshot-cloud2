--[[
	ZephyrDraw  (ReplicatedStorage.IceMagic.ZephyrDraw, ModuleScript, CLIENT ONLY)          Zephyr v6 import, 2026-10-06

	The drawing engine of the Zephyr v6 kit: the Luau side of the Blender kit's air (blender_scripts/zephyr/aqua/za.py
	mat_wind / ring / path_ribbon / Arcs / burst, za5.py Sheet / Shell / mat_surf / mat_shell / mat_feather5 / spline /
	aqua_light / light_set, spring/zk.py Ribbon / Particles / arc_pts and the maths), so a piece's v6 frame function
	ports almost line by line. It is a FORK of RadiantDraw (IceMagic.RadiantDraw): the same immediate-mode pooled Beam
	renderer, the same driver and clocks, the same maths and the whole RadiantDraw drawing API with its argument
	conventions -- the gold/cream look replaced by the Zephyr look KINDS, the folder workspace.<FX folder>.ZephyrDraw,
	plus the v6 additions (ribbons, sheets, particles, lights, the camera kick and the screen glare).

	WHO CALLS IT: ZephyrFX_WindBlade, ZephyrFX_CrossSlash, ZephyrFX_Cyclone, ZephyrUpdraft, ZephyrGustPad and
	ZephyrFX_Skyrider (their client halves), each through ZD.Play / ZD.Demo. INERT ON THE SERVER: requiring it builds
	nothing and binds nothing; the RenderSteps are bound only while an effect / a kick / a glare is alive, and every
	frame function runs inside a pcall (an error ends that effect with one warning, never a mechanic).

	    Blender (za / za5 / zk)                              Luau (ZD = this module, cv = a canvas)
	    rb.set(pts, w, t=t, fade=f, alpha=.6, glow=1.1)      cv:Ribbon(pts, w, "glow", { fade = f, alpha = 0.6, glow = 1.1 })
	    core + glow ribbons on the same path                 cv:CoreGlow(pts, wCore, wGlow, { fade = f, core = { glow = 1.5 } })
	    rb.set(P, w, side=S, ...)    (a flat strip)          cv:Ribbon(P, w, kind, { side = S })   (S: Vector3 or array)
	    ring(rb, c, normal, r, w, t, fade=..)                cv:RingK(c, r, normal, w, kind, { fade = .. })
	    path_ribbon(rb, fn, t, dur, (w0, w1), ..)            cv:PathRibbon(ZD.trail_fn(fn, t, dur, n), { w0, w1 }, kind, o)
	    Sheet(nu, nv, mat_surf(e0=..)).set(P, fa=FA, ..)     cv:Sheet(P, nu, nv, "surf", { fa = FA, e0 = .., e1 = .., a0 = .. })
	    Shell(...).set(P, ...)                               cv:Sheet(P, nu, nv, "shell", { closed = true, ... })
	    Arcs(sc, nm, n, seed, r=..).draw(t, c, axis, fade)   cv:Arcs(t, c, axis, { n = n, seed = seed, r = {..}, fade = f })
	    burst(ps, t0, c, n, speed=, life=, up=, normal=, ..) cv:Burst("puff", c, n, { id = "x", t0 = t0, speed = {a, b},
	                                                             life = {a, b}, up = .., dir = normal, cone = .., size = {a, b} })
	    light_set(L, pos, watts, t, fl)                      cv:Light(pos, watts, { flicker = fl })
	    smooth(x, a, b) / span(t, a, b) / ease / back        ZD.sst(x, a, b) / ZD.span(t, a, b) / ZD.ease_io / ZD.back
	    arc_pts(c, axis, d0, r, a0, a1, n, rise, r1)         ZD.arc_pts(c, axis, d0, r, a0, a1, n, rise, r1)  (world vectors)
	    za5.spline(P, n)                                     ZD.spline(P, n)
	Keyword arguments become ONE options table with the kit's own names. Options are only read, never kept: hoist
	constant tables out of the frame function and overwrite their varying fields to keep a frame allocation-free.

	COORDINATES. Every argument is a Roblox world Vector3 (studs). The v6 scenes stand the caster at the ORIGIN ON THE
	FLOOR facing +Y, +X = the caster's right, +Z up, in studs (1:1). ZD.StageCF(root) is that frame in the world (the
	caster's flat facing frame at floor level) and ZD.FromStage(stageCF, x, y, z) = (stageCF * CFrame.new(x, z, -y))
	.Position puts any Blender stage point in the world (ZD.DirStage for directions, ZD.ToStage back). The mapping
	(x, y, z) -> (x, z, -y) is a proper rotation, so every cross product, basis and angle convention of the kit carries
	over (zk.perp_any(a) = a x Z-up is ZD.perp_any(a) = a x Roblox UP). RadiantDraw's own scene mapping (its figures face
	-Y) stays available as ZD.B / ZD.FromScene for anything ported from the Radiant kit.

	THE KINDS (za.mat_wind's kinds, za5's surfaces). A kind is a textured Beam look: Texture (a generated strip, shape
	and alpha only), Color (the palette, picked per knot from the kit's own heat ramp deep #125C59 -> shadow #1F6F6A ->
	edge #2FB5A8 -> main #4FD1C5 -> light #9CE6DF -> core #EFFFFB, interpolated in linear light like Blender's
	ColorRamp), LightEmission, Brightness (from the kit's emission strength), Transparency (per knot) and ZOffset
	(core in front of glow in front of vapor). Config.Kinds holds every number:
	    kind        texture        heat (tail..head)   emission e0 + e1 h^2   alpha a0   LE    BS   Z      tile (studs)
	    core        zd_core        0.94                3.2 + 2.8 h^2          1.00       0.90  1.5  0.030  3
	    glow        zd_glow        0.50 .. 0.70        0.75 + 1.55 h^2        1.00       0.30  1    0.010  6
	    arc         zd_arc         0.60 .. 0.80        0.80 + 1.70 h^2        1.00       0.55  1    0.020  3
	    blade       zd_blade       0.48 .. 0.68        0.90 + 3.00 h^2        1.00       0.30  1    0.015  8   + an INNER white-hot
	                               strip (kind "bladecore", zd_bladecore, 0.40 x the width, heat 0.95, LE 0.8, BS 1.5)
	    vapor       zd_vapor       0.74 .. 0.78        0.45 + 0.35 h^2        0.45       0.12  1    0.000  10
	    ring        zd_ring        0.72                0.70 + 2.20 h^2        1.00       0.45  1    0.012  6   (za "ring": a shock
	                               front, its sharp edge outward -- Config.RingFlip if Play shows it inward)
	    scuff       zd_scuff       #0B1416 (dark)      none                   0.55       0     1    0.000  4   + an INNER dim
	                               teal centre line (kind "scuffline", #2FB5A8, 0.3 x the width)
	    surf        zd_surf        za5 mat_surf's heat (see Sheet)  0.55 + 1.5 h^2   0.80  0.25  0.005  5
	    shell       zd_shell       za5 mat_shell's heat (see Sheet) 0.50 + 1.6 h^2   0.62  0.20  0.004  6
	    feather     zd_feather     0.50 .. 0.90 root   0.60 + 1.40 h^2        0.95       0.30  1    0.008  FIT (root -> tip)
	(Calibrated 2026-10-07 against the v6 sheets: see the comment over Config.Kinds for why each number moved.)
	o.glow multiplies the emission (za's glow prop); o.alpha is za's zk_alpha: 0.5 = the kind's nominal opacity a0 (the
	default), 1.0 doubles it (clamped at opaque) -- port the Blender values as they are; an ARRAY o.alpha (or o.alphas)
	is per-point alpha (za's `alpha=` array). o.fade (0..1) is the overall presence (0 = nothing drawn). o.head / o.tail
	(fractions of the length) fade toward the FIRST / the LAST point: head default 0.05 (za's soft head), tail default 0.6
	(za's zk_tail default -- the fraying tail; 0 = no tail fade). o.heat adds to the heat (hotter / cooler, colour and
	emission), o.color (Color3) replaces the colour, o.e0 / o.e1 / o.a0 replace the kind's emission / opacity constants
	(za5's per-material mat_surf(e0=, e1=, a0=)), o.scroll is the streak scroll (studs/s along the ribbon, toward the
	tail; default per kind), o.t the streak clock (za's t prop; default cv.T: pass t + phase like the kit's t=t + i),
	o.z adds to the ZOffset, o.inner = false drops a kind's inner strip, o.u0 / o.u1 = za's u range, o.le replaces the
	kind's LightEmission for this strand only (o.core.le the inner's; the Cyclone's daylight blades, 2026-10-07).

	THE RENDERER (immediate mode, pooled -- RadiantDraw's). A canvas per effect instance: cv:Begin(t) ... cv:End().
	Pooled slots are handed out in draw order; End() disables the ones not drawn this frame; nothing is created per
	frame after warm-up and nothing destroyed until cv:Destroy() (slots back to a shared free list, capped by
	Config.PoolKeep). Every property write is skipped when the value did not change. All instances live in
	workspace.<FX folder>.ZephyrDraw: Beams in the folder, their Attachments, PointLights and ParticleEmitters on one
	anchored, invisible, non-colliding, non-querying, shadowless Part at the origin.
	  a RIBBON (Ribbon / Core / Glow / CoreGlow / RingK / PathRibbon / a Sheet band) = one SPAN per knot pair; a span =
	    two Attachments + one Beam per strand (the outer kind; a second Beam on the same Attachments for an inner strand:
	    CoreGlow's core, the blade's white-hot centre, the scuff's line). Knots: the points are thinned to <= o.maxSpans
	    (default Config.MaxSpans = 8) spans at even arc length (always on the given points), joined by Hermite curves
	    (the Attachment Axis rides the tangent, CurveSize0/1 = the handles); width, alpha and colour are LINEAR between
	    knots (Width0/1, a 2-key Transparency and a 2-key ColorSequence per Beam). The texture tiles along the ribbon
	    (TextureMode.Wrap, Kinds[k].Tile studs per repeat) and Beam:SetTextureOffset keeps it continuous from span to
	    span and scrolls it (za's streaks scroll along the ribbon at o.scroll studs/s).
	  a SHEET = bands: each band a flat ribbon between two neighbouring rows of the grid, as wide as their gap, its
	    width direction the gap (so the band's normal is the local surface normal); o.bands resamples the rows to fewer
	    bands, o.along = "v" runs the bands the other way (rings round a dome / a funnel instead of meridians).
	  a GLINT / MOTE (RadiantDraw's) = a camera-facing textured Beam sprite (the spark / dot / puff textures).
	  a LIGHT = a PointLight on a pooled Attachment, Color (140, 255, 235), Shadows off.
	  a BURST / STREAM = a pooled ParticleEmitter on an Attachment (:Emit for a burst -- one call per particle, so each
	    gets za.burst's exact direction -- Rate for a stream). NOT deterministic (that is fine: particles are not in
	    the parity sheets); counts x the effect density (Settings.EffectDensity, x Config.EnemyThin for other players'
	    effects under Reduce Enemy VFX -- PyroDraw's rule: pass Own = true in Play's opts for your own).
	Budgets are counted in real Beams and Lights per canvas per frame (the plan's table: ZD.Budgets); End() warns once
	per canvas past its Budget (Play opts.Budget = a ZD.Budgets entry or its name, else Config.Budget). Prefer fewer,
	wider, textured ribbons over many thin ones: a ribbon costs one Beam per span (two with an inner strand).

	THE GLOW CALIBRATION (read-only from the place, 2026-10-06; RE-CALIBRATED 2026-10-07 against the v6 sheets).
	Lighting: Brightness 1.7, ClockTime 12.56 (noon), Ambient (0.42, 0.49, 0.62), ExposureCompensation 0.12; Bloom
	Intensity 0.6, Size 24, THRESHOLD 1.6; ColorCorrection (tint 0.98/0.99/1) and SkylineGrade (Saturation +0.35,
	Contrast +0.06). The kit renders under EEVEE bloom threshold 0.9 / strength 0.42 on a dark stage. The kit's
	emission is an alpha-OVER of an emissive colour (Mix(Transparent, Emission, alpha)), so the beams are unlit
	(LightInfluence 0) and mostly alpha-blended. A Beam has ONE colour across its width, so a sleeve kind's colour is
	the kit's ALPHA-WEIGHTED MEAN heat across its width (glow: 0.47 tail .. 0.67 head = edge #2FB5A8 .. main
	#4FD1C5: saturated teal), not its centre heat (0.62 .. 0.86 read pale aqua / grey in daylight); the hot-centre /
	cool-edge split is the strip's luminance, and the white-hot centre is a second strand (CoreGlow's core, the blade's
	bladecore). LightEmission is LOW on the bodies (glow / blade 0.3, vapor 0.12, surf 0.25, shell 0.2): additive
	light on the bright noon sky / floor washes a teal toward white, while an alpha-blended body keeps its colour (the
	plan's "soft, opaque-ish"); the cores keep LE 0.8 - 0.9 (they add light). Brightness = 1 + BrightScale x BS x glow x
	(e0 + e1 h^2), BrightScale 1/8 (RadiantDraw's Play-calibrated scale under the SAME Bloom; 1/2.6 and 1/5 blew its
	cores to white), BS = the kind's own scale (1; the white-hot strands core / bladecore 1.5). That puts the core
	thread at ~2.06 x #EFFFFB: the ONLY thing over Threshold 1.6 on its own, so the cores bloom softly round a white
	thread; the teal sleeves sit at ~1.1-1.3 x teal, under it, so the edges feather instead of glowing (the v6 rule:
	the hot centre blooms, the edges feather). Config.MaxBrightness 3 caps a stacked glow. The +0.35 saturation grade
	makes the teal read stronger than in the renders. NOT NEON: no sleeve kind sits over heat 0.74; if Play shows
	cyan-neon, lower a kind's heat or LightEmission, not its alpha; if it is pale / grey, lower its LE or raise its A0.
	The main session can still trim BrightScale / Kinds[k].LE / BS / A0 in Play.

	LIGHTS (za5.aqua_light / light_set): cv:Light(p, watts, o) = a PointLight, Brightness = watts / Config.LightWatts
	(600: the handoff's W -> Brightness) capped at Config.LightMax (6), x Config.LightScale, Range o.range (default
	12), o.color (default (140, 255, 235)), x the kit's flicker (1 - f + f sin(29 t) sin(17.7 t + 1.3)), f = o.flicker
	(0.15), t = o.t (cv.T). Reduce Flashing: no flicker, x Config.CalmLight.

	THE CAMERA (own view). ZD.CameraKick(o) is an impulse on the LOCAL camera that stacks with every other live kick and
	decays: o.fov = a lens kick (tan(FOV / 2) x (1 + fov): the Blender `lens /= 1 + fov` exactly; +0.3 at FOV 90 is
	104.8 deg; the X's 10 % zoom jolt `lens *= 1.1` is fov = -0.0909), o.pitch / o.roll (rad; + pitch looks up, + roll
	as the kit's Rotation(rl, "Z")), o.osc (rad/s) and o.phase make pitch / roll oscillate (the Wind Blade's
	sin(120 tau + 0.6)), o.rise (s, the attack), o.hold (s at full: math.huge holds until handle:Release()), o.decay (s,
	the exp time constant), o.shake (studs) goes to the EXISTING camera-shake hook, Viewmodel.Shake(shake, o.shakeDecay
	or o.decay) (translation on Humanoid.CameraOffset: the Camera Shake setting scales it, Reduce Flashing removes it).
	FirstPersonController / VFXLibrary have no rotation or FOV hook (Viewmodel.Shake is translation only, by design),
	so the pitch / roll / FOV ride ZephyrDraw's own RenderStep at Camera + 1, bound only while a kick lives, and the
	rotation is UNDONE at Camera - 2 the next frame before the camera script reads the view back (so a kick never
	drifts the aim, and SettingsRuntime's look step sees its own view). Camera Shake setting scales all of it; Reduce
	Flashing drops pitch / roll / shake and keeps Config.Kick.CalmFov of the FOV kick. Returns a handle {Release(),
	Stop()}. ZD.ScreenGlare(level, o) = the Cyclone's first-person edge glare: a white-aqua radial vignette (a
	ScreenGui ImageLabel), level 0..1 for THIS frame (call it every frame you want it; it is gone the frame you stop),
	o.flicker / o.hz (pass the flicker here, not inside level, so Reduce Flashing can drop it), o.color. ImageTransparency
	= 1 - Config.Glare.Max x level.

	API  (ZD = require(IceMagic.ZephyrDraw); cv = a canvas; every vector is Roblox world; o = options, all optional)
	  the palette, kinds, budgets
	    ZD.Palette = { Core, Light, Main, Edge, Shadow, Deep, Glint }  (Color3)   ZD.Colors (the same + Light3 aqua light)
	    ZD.Kinds (= Config.Kinds)   ZD.ParticleKinds (= Config.Particles)   ZD.Budgets.{WindBlade, CrossSlash, Cyclone,
	    Updraft, GustPad, Skyrider} = { Beams, Lights }   ZD.heat_color(h) -> Color3 (the kit's ramp)
	  maths (RadiantDraw's + the kit's)
	    ZD.clamp(x,a,b) ZD.lerp(a,b,t) ZD.smooth(u) ZD.ease_out_back(u,s) ZD.ease(style,u)   (RadiantDraw's, unchanged)
	    ZD.ramp(t, t0, dur, style="InOut") ZD.env(t, t0, t1, fin=0.15, fout=0.25, style)  ZD.basis(n, ref?) -> u, v, n
	    ZD.sst(x, a, b) (= zk.smooth: smoothstep a..b)  ZD.span(t, a, b)  ZD.ease_io(u)  ZD.ease_out3(u)  ZD.ease_in3(u)
	    ZD.back(u, s=1.70158)  ZD.rad(deg)  ZD.flicker(t, f=0.15, hz=29)  ZD.hitstop(t, t_hit, frames=2, fps=30)
	    ZD.perp_any(v)  ZD.rot_about(v, axis, ang)  ZD.Rand(a, b, c, k) -> 0..1 (hash: the same on every client)
	    ZD.trail_fn(posFn, t, span=0.25, n=10, t_min?, out?) -> history (OLDEST first, RadiantDraw's)
	    ZD.arc_pts(c, axis, startDir, r, a0, a1, n, rise=0, r1=r, out?) -> points (zk.arc_pts)
	    ZD.spline(P, n, sigma=1.2, out?) -> points (za5.spline: Catmull-Rom resample + Gaussian smoothing, ends kept)
	  clocks
	    ZD.ServerNow()  ZD.TimeScale()  ZD.Clock(t0Server?, offset=0, scale=TimeScale()) -> fn()   (RadiantDraw's)
	  coordinates
	    ZD.StageCF(rootPart | CFrame, floorY?) -> CFrame   the caster's flat facing frame AT FLOOR LEVEL (a part: its
	        Humanoid's HipHeight + half the root; a CFrame: floorY or 3 studs under it, Config.RootHeight)
	    ZD.FromStage(stageCF, x, y, z) -> Vector3   ZD.DirStage(stageCF, x, y, z) -> Vector3   ZD.ToStage(stageCF, p) -> x, y, z
	    ZD.UP   ZD.B(x,y,z | v)   ZD.Body(cf, right, up, fwd)   ZD.BodyDir(..)   ZD.ToBody(cf, w)
	    ZD.FromScene(rootCF, at_x, at_y, facing_deg, pB)   ZD.Palm(handCF)   ZD.ReceivePoint(chest, src, lift, skin)
	  views
	    ZD.FirstPerson() -> bool (the local camera is the first-person viewmodel view)   ZD.IsLocal(character) -> bool
	    ZD.Calm() -> bool (Reduce Flashing)   ZD.Density(own) -> number   ZD.CameraCF() -> CFrame
	    ZD.Friendly(character) -> bool (not an enemy's: pass as Own so a teammate's effect is not thinned; audit P5F-06)
	  canvases and the driver
	    ZD.new(name, prewarm?{Spans, Sprites, Lights, Emitters}, opts?{Own, Budget}) -> cv
	    cv:Begin(t) / cv:End() -> beams, lights / cv:Clear() / cv:Destroy() / cv:Tag(name) / cv:Count(n) /
	    cv:CountGlints(n) / cv:Budget() -> {Beams, Lights, Particles (emitted so far), Pieces, Glints, Peak = {...},
	    Tags, Slots, Limits}
	    cv.T (the t given to Begin)  cv.Density  cv.Own  cv.Beams  cv.CamPos  cv.CamLook
	    ZD.Play(name, frameFn(cv, t, dt, handle), opts?) -> handle {Canvas, Stop()}   opts: T0 (server time), Offset,
	        Scale, Clock (fn -> clip s), Until (clip s), MaxLife (s), Prewarm, OnEnd(handle), Own, Budget, Freeze
	        (clip s: draw that one frame and hold it until handle:Stop())   return false from frameFn to end
	    ZD.Demo(name, frameFn, opts) = ZD.Play with opts.Freeze honoured (the test harness / screenshots)
	    ZD.StopAll()   ZD.SetFolder(instance | fn)   ZD.Stats()   ZD.ClearLookCache()
	  THE ZEPHYR DRAWING (the v6 kit)
	    cv:Ribbon(pts, widths, kind, o) -> beams   pts = array of Vector3 (>= 2), pts[1] = the HEAD; widths = number or
	        array per point (full width, studs). o: n (Vector3 | array: a FLAT strip, width along n x tangent), side
	        (Vector3 | array: the width direction itself, za's side=), neither = camera-facing; fade, alpha (number |
	        array), alphas, glow, head, tail, heat, color, e0, e1, a0, scroll, t, z, u0, u1, inner (false), inner_w
	        (number | array: the inner strip's width; default Kinds[k].InnerWidth x width), core (table: overrides for
	        the inner strand), maxSpans, closed, straight (no curves), tag
	    cv:Core(pts, widths, o) / cv:Glow(pts, widths, o) / cv:Blade(pts, widths, o) / cv:Vapor(pts, widths, o)
	    cv:CoreGlow(pts, wCore, wGlow, o)   the kit's standard pair on ONE set of knots: the glow sleeve (o) and the
	        white-hot core on top (o.core = {fade, alpha, glow, head, tail, heat, ...}: overrides; missing fields fall
	        back to o). 2 Beams per span.
	    cv:RingK(c, r, n, width, kind, o) -> beams   za.ring: a closed flat ring (width radial, in the plane normal to
	        n), one span per <= 90 deg (exact). o: a0, a1 (an arc, rad), u (0..1 of the sweep drawn), ref (angle 0
	        toward ref), face (camera-facing strips), flip, fade, alpha, glow, heat, color, scroll, t, z, taper (true:
	        apply head / tail like a ribbon; za's rings have none), tag
	    cv:PathRibbon(history, widths, kind, o) -> beams   za.path_ribbon: history = ZD.trail_fn(...) output (OLDEST
	        first: the newest point is the head); widths = number, {w_head, w_tail} or an array per history point; x
	        the kit's sin(pi s)^0.35 profile. kind "coreglow": the pair (o.core for the core, widths for the glow,
	        o.core_w = {w_head, w_tail} for the core)
	    cv:Sheet(P, nu, nv, kind="surf", o) -> beams   za5.Sheet / Shell: P = flat array of nu * nv Vector3, row-major
	        (index (i-1) * nv + j, i along u = "sa", j along v = "ch"). o: closed (wrap v: tubes, funnels, domes), fa
	        (per-vertex fade: a flat nu * nv array or a number), along ("u" default: bands run along u, one per gap
	        between v rows; "v": bands run round v, one per gap between u rows), bands (fewer bands: rows resampled),
	        maxSpans, fade, alpha, glow, heat, color, e0, e1, a0, scroll, t, z, tag. kind "surf" = mat_surf (the
	        trailing ch edge and the sa tip feathered, the leading edge hot, denser at grazing angles, the side facing
	        the sun hotter), "shell" = mat_shell (a soft foot and rim, hotter up the height), or any ribbon kind.
	    cv:Arcs(t, c, axis, o) -> beams   za.Arcs.draw: o.n (14), seed, r {1.2, 3}, span {50, 140} (deg), w {0.05,
	        0.22}, speed {3, 9}, tilt 0.55, npts 18, fade, spin (+1), scale, speed_mul, glow, maxSpans (4)
	    cv:Sprite(p, size, o) -> 1 | 0   one deterministic textured sprite, size = half-width: o.tex ("Puff" | "Dot" |
	        "Spark" | "Dust" | ...), opacity (a PLAIN 0..1 multiplier), fade, heat (0.85), color, glow, e0 (1), e1
	        (1.6), le (0.7), rot, n (flat), z -- the cyclone's white core blob, eyes, a soft glow behind a hit
	    cv:Burst(kind, pos, n, o) -> fired   za.burst as ParticleEmitter:Emit. kind: "puff" | "dust" | "mist" | "spark" |
	        "speck" | "chip" | "glint". o: speed {a, b} (6, 16), life {a, b} (0.4, 1.0), size {a, b} (x the kind's base
	        size; 0.6, 1.4), dir (Vector3: the cone axis = za's normal), cone (0..: spread, 1), up (added to the
	        direction's Y, 0.3), drag (1/s, the kind's), accel (Vector3; default the kind's gravity factor x the kit's
	        G 28.6 studs/s^2), grow (size x (1 + grow) at death, 0), stretch (velocity-stretched sprites), alpha
	        (opacity x), color (Color3), seed, id (fires ONCE per canvas per id: call it every frame), t0 (fire once
	        cv.T >= t0, not after t0 + o.late (0.25 s); a t0 without an id is its own id). Without id or t0 it fires
	        on EVERY call.
	    cv:Stream(kind, pos, rate, o)   a continuous emitter at pos while drawn this frame (particles/s; o as Burst; its
	        look (kind, size, life, drag, accel, grow, alpha, color) is read when the stream starts, rate / pos / dir /
	        cone / speed live). o.id names it (default: the kind).
	    cv:Light(p, watts, o) -> PointLight | nil   o: range (12), flicker (0.15), hz (29), t (cv.T), color, tag
	  RADIANTDRAW'S DRAWING (unchanged signatures; level 0..1 = 0 a dim unlit line, 0.5 glowing, 1 white-hot)
	    cv:Line(pts, level, w?, n?, bezel=true, prof?, smooth=false)   cv:Seg(p0, p1, level=0.5, w?, n?, bezel=true, tag?)
	    cv:Polyline(pts, level, o{u, closed, w, n, rigid, bezel, tag}) -> lead
	    cv:Ring(c, r, n=UP, level, o{a0, a1, u, ticks, long_every, tick_len, tick_in, dashes, duty, ref, w, rigid, tag, face})
	    cv:Spiral(c, n, r0, r1, turns, u=1, level, o{a0, tail, grow, cw, ref, w, tag}) -> end point, end angle
	    cv:Rosette(c, n, r, level, o)  cv:Sigil(c, r, level, o)  cv:Chevron(p, d, level, o)  cv:Bond(src, dst, u, level, o)
	    cv:Motes(points, level, o)  cv:Mote(p, size, level, dir?, trail_len, as_particle, tag?)
	    cv:Stroke(pts, level, o{w, taper, lo, n, smooth_k, sleeve, pieces, tag})  cv:Trail(history, level, o{w, lo, n, tag})
	    cv:Glint(p, size=0.12, level=1, rot=0, n?, short=0, tag?)   (a four-point spark star in a soft aqua halo)
	    cv:Sparkles(c | c(t), radius, t, o)  cv:HolyRays(c, u, o)  cv:Flare(p, u, o)  cv:LightPool(p, level, o)
	    cv:MoteField(c, radius, t, o)  cv:Gather(p, u, o)  cv:StarStud(p, normal, size, level, points, rot, tag)
	    cv:Clasp(c, axis, o)  cv:StaffAura(p, level, t, o)  ZD.StaffGlow(parts, level) (colour only: never Neon)
	    ZD.level_look(l) / ZD.glow_look(l) / ZD.staff_look(l) -> Color3, emission   ZD.lw(l)  ZD.sleeve_w(l)
	  the camera (own view only)
	    ZD.CameraKick(o{fov, pitch, roll, osc, phase, rise, hold, decay=0.12, shake, shakeDecay}) -> {Release(), Stop()}
	    ZD.ScreenGlare(level, o{flicker, hz=19, color})

	NOT LIKE THE KIT (Beams, not Blender meshes): a ribbon has no thickness or cup (a flat strip seen edge-on thins
	away: the kit's flat rings do too); one Beam has ONE colour across its width (the hot centre / cool edge split is
	the texture's luminance, the white-hot centre of a blade / the CoreGlow pair is a second Beam; za's `lit` side
	heat is not drawn); width, alpha and colour are linear between knots (8 spans by default instead of the kit's
	12-72 points; the very first / last span of a short head / tail fade approximates its curve); the streak noise is
	a baked tiling texture scrolled along the ribbon (not 4D noise boiling in time); a Sheet is flat bands between rows
	(no subdivision; o.bands trades smoothness for Beams); the layer-weight 'thickness' and the key light use the
	camera and the place's sun; particles are ParticleEmitters (not the kit's per-frame flow-field sim: they get the
	kit's drag, gravity factor, spin, size, life and fade, not the swirl of a flow field); randomness is a hash or
	Random (same statistics, not the renders' positions).
	UNVERIFIED IN STUDIO (each a one-value fix in Config): Beam:SetTextureOffset's unit and direction
	(TexOffsetInStuds, TexOffsetSign -- verify streaks run head -> tail with no seam at knots), the flat-strip width
	axis (WidthOnSecondaryAxis) and CurveSize1Sign (both RadiantDraw's, also unconfirmed there), which edge of the
	"ring" strip lands outward (RingFlip), ParticleEmitter Drag's unit (DragK: 1/ln 2 if Drag is half-lives per
	second), an Attachment emitter's Top = the Attachment's +Y, particle Size = full width (ParticleSize), the
	velocity-stretch Squash, and that two RenderSteps bound at the same priority run in bind order (the kick binds
	after SettingsRuntime's look step and MovementController's slide roll). Nothing here was seen in Play.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local ZephyrDraw = {}

----------------------------------------------------------------------------------------------------
-- MATHS (RadiantDraw's / rad_anim's identical curves, plus the Zephyr kit's zk / pyro_kit helpers)
----------------------------------------------------------------------------------------------------
local sin, cos, tan, abs, floor, ceil, max, min, sqrt, pi, exp = math.sin, math.cos, math.tan, math.abs, math.floor,
	math.ceil, math.max, math.min, math.sqrt, math.pi, math.exp
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)
local XAX = Vector3.new(1, 0, 0)
local NEGX = Vector3.new(-1, 0, 0)
local ZERO = Vector3.new(0, 0, 0)
local FWD_DEFAULT = Vector3.new(0, 0, -1)
ZephyrDraw.UP = UP

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

--- RadiantDraw's ease(style, u): TweenService-style OUT curves.
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

--- zk.smooth(x, a, b): smoothstep from a to b (the kit's most used curve -- NOT RadiantDraw's 1-argument smooth)
local function sst(x, a, b)
	if b == a then return (x >= b) and 1 or 0 end
	local u = (x - a) / (b - a)
	if u <= 0 then return 0 end
	if u >= 1 then return 1 end
	return u * u * (3 - 2 * u)
end

--- pyro_kit.span(t, a, b): linear 0..1
local function span(t, a, b)
	if b > a then return clamp((t - a) / (b - a), 0, 1) end
	return (t >= b) and 1 or 0
end

ZephyrDraw.clamp, ZephyrDraw.lerp, ZephyrDraw.smooth = clamp, lerp, smooth
ZephyrDraw.ease_out_back, ZephyrDraw.ease, ZephyrDraw.ramp, ZephyrDraw.env = ease_out_back, ease, ramp, env
ZephyrDraw.sst, ZephyrDraw.span = sst, span
ZephyrDraw.ease_io = smooth                                       -- pyro_kit.ease: smoothstep
function ZephyrDraw.ease_out3(u) u = clamp(u, 0, 1) return 1 - (1 - u) ^ 3 end
function ZephyrDraw.ease_in3(u) u = clamp(u, 0, 1) return u * u * u end
ZephyrDraw.back = ease_out_back                                   -- zk.back(u, s=1.70158)
function ZephyrDraw.rad(d) return d * pi / 180 end

--- za5.light_set's flicker factor: 1 - f + f sin(t hz) sin(0.61 t hz + 1.3)
function ZephyrDraw.flicker(t, f, hz)
	f, hz = f or 0.15, hz or 29.0
	return 1 - f + f * sin(t * hz) * sin(t * hz * 0.61 + 1.3)
end

--- za.hitstop: the animation clock with a hit-stop (actors freeze `frames` frames at t_hit; effects keep running)
function ZephyrDraw.hitstop(t, t_hit, frames, fps)
	local h = (frames or 2) / (fps or 30)
	if t < t_hit then return t end
	if t < t_hit + h then return t_hit end
	return t - h
end

--- u, v, n of a plane (angle 0 = ref projected in, else RadiantDraw's rule)
local function basis(n, ref)
	n = n.Unit
	if ref then
		local u = ref - n * ref:Dot(n)
		if u.Magnitude > 1e-6 then
			u = u.Unit
			return u, n:Cross(u).Unit, n
		end
	end
	local a = (abs(n.Y) < 0.9) and UP or NEGX
	local u = n:Cross(a).Unit
	return u, n:Cross(u).Unit, n
end
ZephyrDraw.basis = basis

--- a unit vector perpendicular to d
local function ortho(d)
	local a = (abs(d.X) < 0.6) and XAX or ((abs(d.Y) < 0.6) and UP or Vector3.new(0, 0, 1))
	return d:Cross(a).Unit
end

--- zk/pyro_kit perp_any: a x Z-up (Blender) = a x UP (the stage mapping is a proper rotation), else a x X
local function perp_any(a)
	local p = a:Cross(UP)
	if p.Magnitude < 1e-4 then p = a:Cross(XAX) end
	if p.Magnitude < 1e-9 then return XAX end
	return p.Unit
end
ZephyrDraw.perp_any = perp_any

--- v rotated about the unit axis by ang (right-handed, as mathutils.Quaternion)
local function rotAbout(v, axis, ang)
	local c, s = cos(ang), sin(ang)
	return v * c + axis:Cross(v) * s + axis * (axis:Dot(v) * (1 - c))
end
ZephyrDraw.rot_about = rotAbout

----------------------------------------------------------------------------------------------------
-- THE PALETTE AND THE KIT'S HEAT RAMP
----------------------------------------------------------------------------------------------------
local function hex(h)
	return Color3.fromRGB(tonumber(string.sub(h, 2, 3), 16), tonumber(string.sub(h, 4, 5), 16),
		tonumber(string.sub(h, 6, 7), 16))
end

-- the owner's palette, EXACTLY (ROBLOX_IMPORT_PLAN.md section 1; za.PAL4)
local PAL = {
	Core = hex("#EFFFFB"), Light = hex("#9CE6DF"), Main = hex("#4FD1C5"), Edge = hex("#2FB5A8"),
	Shadow = hex("#1F6F6A"), Deep = hex("#125C59"), Glint = hex("#FFF3C4"),
}
ZephyrDraw.Palette = PAL

local C = {
	Core = PAL.Core, Light = PAL.Light, Main = PAL.Main, Edge = PAL.Edge, Shadow = PAL.Shadow, Deep = PAL.Deep,
	Glint = PAL.Glint,
	Light3 = Color3.fromRGB(140, 255, 235),   -- every effect light (za5.aqua_light (0.55, 1, 0.92), the plan's (140, 255, 235))
	ScuffDark = hex("#0B1416"),               -- za mat_wind("scuff"): the dark streak
	Dust = hex("#8FA3A7"), Speck = hex("#BFD6D5"), Mist = hex("#DDF5F2"),   -- za _mat_debris4
	Chip = hex("#323B40"), ChipDark = hex("#262E32"),
	LineIdle = hex("#1F6F6A"),                -- RadiantDraw's level 0 (the unlit engraving) -> the shadow teal
}
ZephyrDraw.Colors = C

local function mix3(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function toLin(c)
	if c <= 0.04045 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function toSRGB(c)
	c = clamp(c, 0, 1)
	if c <= 0.0031308 then return c * 12.92 end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

-- za._ramp: deep 0.00, shadow 0.18, edge 0.40, main 0.60, light 0.80, core 0.97 -- LINEAR interpolation of the
-- scene-linear stops (Blender's ColorRamp), shown as sRGB
local RAMP = {}
for _, s in ipairs({ { 0.00, PAL.Deep }, { 0.18, PAL.Shadow }, { 0.40, PAL.Edge }, { 0.60, PAL.Main },
	{ 0.80, PAL.Light }, { 0.97, PAL.Core } }) do
	RAMP[#RAMP + 1] = { t = s[1], r = toLin(s[2].R), g = toLin(s[2].G), b = toLin(s[2].B) }
end

local function heatColor(h)
	h = clamp(h, 0, 1)
	local a = RAMP[1]
	if h <= a.t then return Color3.new(toSRGB(a.r), toSRGB(a.g), toSRGB(a.b)) end
	for i = 2, #RAMP do
		local b = RAMP[i]
		if h <= b.t then
			local f = (h - a.t) / (b.t - a.t)
			return Color3.new(toSRGB(a.r + (b.r - a.r) * f), toSRGB(a.g + (b.g - a.g) * f), toSRGB(a.b + (b.b - a.b) * f))
		end
		a = b
	end
	return Color3.new(toSRGB(a.r), toSRGB(a.g), toSRGB(a.b))
end
ZephyrDraw.heat_color = heatColor

----------------------------------------------------------------------------------------------------
-- CONFIG (everything tunable in one place)
----------------------------------------------------------------------------------------------------
local Config = {
	FXFolderName = "IceMagicFX",          -- fallback; VFXLibrary.Config.FXFolderName wins when readable
	SubFolderName = "ZephyrDraw",
	RenderPriority = Enum.RenderPriority.Character.Value + 3,   -- after the Viewmodel (Camera + 2) and CastPose
	                                      -- (Character + 1): hand / wrist anchors read THIS frame's pose
	MaxLife = 30,                         -- a Play()ed effect is ended this long (os.clock s) after it began

	-- THE GLOW (see the header: Bloom 0.6 / 24 / Threshold 1.6, SkylineGrade +0.35 saturation). UNTUNED IN PLAY.
	BrightScale = 1 / 8,                  -- Beam Brightness = 1 + BrightScale x glow x (e0 + e1 heat^2): RadiantDraw's
	                                      -- Play-calibrated scale under this same Bloom (1/2.6 and 1/5 blew cores white)
	MaxBrightness = 3.0,                  -- a stacked glow (glow = 1.9 surges) never passes this
	MinWidthPerStud = 0.0018,             -- width floor per stud of camera distance (~1.5 px at 1080p / FOV 90; 0 = off):
	                                      -- at 1 px a core thread's alpha-shaped strip never reached white
	MaxSpans = 8,                         -- a ribbon's default knot budget (o.maxSpans): Beams per strand
	SheetOverlap = 1.06,                  -- a Sheet band is this x its row gap wide: neighbours overlap, no hairline gaps
	HeadDefault = 0.05,                   -- za: smoothstep(u, 0, 0.05), the soft head
	TailDefault = 0.6,                    -- za: zk_tail = 0.6, the fraying tail
	TailFray = 0.55,                      -- za's fib inside the tail: (1 - fray) + fray x streaks (their mean ~0.55)
	AlphaEps = 1 / 80,                    -- a span whose both ends are under this opacity is not drawn

	-- Beam conventions (Studio checks: each is a one-value fix, as RadiantDraw / UmbraTuning.FX.Engine)
	CurveSize1Sign = 1,                   -- -1 if a curve bows the wrong way at its Attachment1 end
	WidthOnSecondaryAxis = true,          -- false if a flat strip (rings, sheets, floor marks) shows edge-on
	CurveSegments = 10,                   -- Segments of a curved span; straight spans use 1
	TexOffset = true,                     -- keep U continuous across spans + scroll with Beam:SetTextureOffset;
	                                      -- false = no offsets (a seam at each knot), TextureSpeed scrolls instead
	TexOffsetSign = 1,                    -- -1 if the streaks run tail -> head / jump at every knot
	TexOffsetInStuds = false,             -- true if SetTextureOffset takes studs rather than texture repeats
	RingFlip = false,                     -- true if the "ring" kind's sharp shock front lands on the inside

	-- THE TEXTURES (tools/zephyr_textures.py -> D:/voltkit_scratch/zephyr_textures, uploaded 2026-10-06 through the
	-- Studio MCP upload_image; the source file of each is named). Greyscale shape + alpha: the colour is Beam.Color.
	-- 2026-10-08: six of the uploads (blade, bladecore, ring, shell, feather, glare) are approved (their thumbnails
	-- render) but never load as rbxassetid textures in this place, so the Wind Blade's body / core drew NOTHING. They
	-- are served through the thumbnail CDN instead (rbxthumb, 420x420: a Beam's UVs are normalised, so the square
	-- resample only softens them slightly). Original ids: blade 71204903916003, bladecore 98602701341724, ring
	-- 113594728745620, shell 93005732999515, feather 101480931773797, glare 131476303693794 -- put them back if they
	-- ever load (ContentProvider:PreloadAsync in a Play test).
	Textures = {
		Core = "rbxassetid://75433400371450",        -- zd_core.png       256x64   a sharp bright centre line, soft falloff
		Glow = "rbxassetid://106734156496981",       -- zd_glow.png       256x64   the soft teal sleeve, noisy edge
		Blade = "rbxthumb://type=Asset&id=71204903916003&w=420&h=420",       -- zd_blade.png      512x128  white-hot centre -> edges, streaky breakup
		BladeCore = "rbxthumb://type=Asset&id=98602701341724&w=420&h=420",   -- zd_bladecore.png  256x64   the blade's inner white-hot strip
		Vapor = "rbxassetid://76368683592187",       -- zd_vapor.png      512x128  soft, wide, tileable wisps
		Arc = "rbxassetid://137386924882401",        -- zd_arc.png        256x32   a thin bright line
		Ring = "rbxthumb://type=Asset&id=113594728745620&w=420&h=420",       -- zd_ring.png       256x64   a shock front, sharp at the bottom (+v)
		Scuff = "rbxassetid://72285422096895",       -- zd_scuff.png      256x64   a dim broken streak
		Surf = "rbxassetid://98589236048676",        -- zd_surf.png       256x64   Sheet bands: near-uniform across, streaks along
		Shell = "rbxthumb://type=Asset&id=93005732999515&w=420&h=420",       -- zd_shell.png      256x64   funnel / dome bands
		Feather = "rbxthumb://type=Asset&id=101480931773797&w=420&h=420",    -- zd_feather.png    256x64   root -> tip (FIT): vein, barbs, frayed tip
		Puff = "rbxassetid://107428983925561",       -- zd_puff.png       128x128  (1 - r)^2.2 soft puff
		Dust = "rbxassetid://87532889306823",        -- zd_dust.png       128x128  (1 - r)^1.6, lumpy
		Spark = "rbxassetid://89196691661195",       -- zd_spark.png      128x128  the four-point star
		Dot = "rbxassetid://97401877165222",         -- zd_dot.png        64x64    (1 - r)^1.4
		Chip = "rbxassetid://101073447922561",       -- zd_chip.png       64x64    an angular flake, two-tone facets
		Glare = "rbxthumb://type=Asset&id=131476303693794&w=420&h=420",      -- zd_glare.png      512x512  the first-person edge glare vignette
	},

	-- THE KINDS. HeatC = the heat at the tail, HeatU = added toward the head (x (1 - u)); E0 + E1 h^2 = the kit's
	-- emission; A0 = the kit's base alpha; LE = LightEmission; Z = ZOffset; Tile = studs per texture repeat (Fit: one
	-- copy over the whole ribbon); Scroll = the default streak scroll (studs/s); Inner = a second strand on the same
	-- knots (InnerWidth x the width); Sheet = the za5 surface profile it follows inside cv:Sheet.
	Kinds = {
		-- CALIBRATED 2026-10-07 against the v6 sheets (zs6v_*_sheet.png) vs the in-game daylight takes (zcine/cmp_*):
		-- in game every kind read PALE / GREY / see-through (no pixel of any core over 235; the sleeves a pale-aqua
		-- wash on the sky). Why: one Beam has ONE colour across its width, and that colour was the Blender sleeve's
		-- CENTRE heat (0.62 .. 0.86: main -> light, the pale steps), while Blender's sleeve is centre-hot, edge-cool
		-- (its alpha-weighted mean heat is 0.47 tail .. 0.67 head: edge #2FB5A8 .. main #4FD1C5); and a high
		-- LightEmission adds the pale colour onto the bright noon sky / floor, washing it toward white. So: the
		-- sleeves sit at the kit's MEAN heat (saturated teal), LightEmission is low on bodies (they read as an
		-- opaque-ish teal body in daylight, not an additive wash), A0 is at full (the strip's own alpha shape --
		-- mean 0.44 for glow -- keeps the feathered edge), and the white-hot cores carry their own brightness (BS:
		-- x Config.BrightScale) so ONLY they pass Bloom's threshold 1.6 and bloom. NOT NEON: no kind's sleeve sits
		-- over heat 0.74, every sleeve's Brightness stays ~1.1-1.3 (under the threshold).
		-- core: za core heat 0.86 + 0.14 (1 - |v|) -> white #EFFFFB; Brightness 1 + 1.5/8 x (3.2 + 2.8 h^2) ~ 2.06:
		-- the only kind over the threshold on its own -> a soft bloom round a white thread (was 1.71: no bloom)
		core = { Tex = "Core", Tile = 3, HeatC = 0.94, HeatU = 0.0, E0 = 3.2, E1 = 2.8, A0 = 1.0, LE = 0.90, BS = 1.5,
			Z = 0.030, Scroll = 5 },
		-- glow: the teal SLEEVE. za glow's alpha-weighted heat 0.47 + 0.2 (1 - u) -> #40C4B7 (tail) .. #7CDCD2 (head);
		-- was 0.62 + 0.2 (main -> light: pale); LE 0.45 -> 0.30, A0 0.80 -> 1.0 (opaque-ish, saturated in daylight)
		glow = { Tex = "Glow", Tile = 6, HeatC = 0.50, HeatU = 0.2, E0 = 0.75, E1 = 1.55, A0 = 1.0, LE = 0.30, Z = 0.010,
			Scroll = 6 },
		-- arc: a thin line reads as its centre (za arc centre heat 0.63 + 0.2 (1 - u)); was 0.66; A0 0.85 -> 1.0
		arc = { Tex = "Arc", Tile = 3, HeatC = 0.60, HeatU = 0.2, E0 = 0.8, E1 = 1.7, A0 = 1.0, LE = 0.55, Z = 0.020,
			Scroll = 6 },
		-- blade: a THICK opaque-ish teal body (the sleeve's mean heat, LE 0.3) round a WIDER white-hot inner strip
		-- (bladecore 0.40 x the width, was 0.34; BS 1.5 so it blooms like a core)
		blade = { Tex = "Blade", Tile = 8, HeatC = 0.48, HeatU = 0.2, E0 = 0.9, E1 = 3.0, A0 = 1.0, LE = 0.16, Z = 0.015,   -- LE 0.30 -> 0.16 (2026-10-07): saturated aqua in daylight, not white
			Scroll = 6, Inner = "bladecore", InnerWidth = 0.22 },   -- 0.40 -> 0.22: a thin white-hot centre, as the Blender
		bladecore = { Tex = "BladeCore", Tile = 8, HeatC = 0.95, HeatU = 0.02, E0 = 0.9, E1 = 3.0, A0 = 1.0, LE = 0.80,
			BS = 1.5, Z = 0.024, Scroll = 6 },
		-- vapor: a SOFT PALE AQUA haze (za vapor's mean heat 0.62 + 0.22 x 0.7 = 0.77 -> 0.74: #8ADFD6-ish); LE 0.25
		-- -> 0.12 (additive vapor on the noon sky read white-grey), A0 0.32 -> 0.45 (it read as nothing on the floor)
		vapor = { Tex = "Vapor", Tile = 10, HeatC = 0.74, HeatU = 0.04, E0 = 0.45, E1 = 0.35, A0 = 0.45, LE = 0.12,
			Z = 0.0, Scroll = 4 },
		-- ring: za ring's heat 0.92 ss(v, -1, 0.85) under its alpha (peak at v 0.2 .. 0.55) averages ~0.7, was 0.86
		-- (pale white hoops); the strip's luminance keeps the hot front / cool trailing side; A0 0.85 -> 1.0
		ring = { Tex = "Ring", Tile = 6, HeatC = 0.72, HeatU = 0.0, E0 = 0.7, E1 = 2.2, A0 = 1.0, LE = 0.45, Z = 0.012,
			Scroll = 3 },
		scuff = { Tex = "Scuff", Tile = 4, Color = C.ScuffDark, HeatC = 0, HeatU = 0, E0 = 0, E1 = 0, A0 = 0.55, LE = 0,
			Z = 0.0, Scroll = 0, Inner = "scuffline", InnerWidth = 0.3 },
		scuffline = { Tex = "Arc", Tile = 4, Color = PAL.Edge, HeatC = 0, HeatU = 0, E0 = 0.8, E1 = 0, A0 = 0.5, LE = 0.6,
			Z = 0.004, Scroll = 0 },
		-- surf / shell: their heat is za5's own per-vertex profile (cv:Sheet); only the body's opacity / emission
		-- change: surf A0 0.60 -> 0.80, LE 0.35 -> 0.25; shell A0 0.50 -> 0.62, LE 0.30 -> 0.20 (both read as a
		-- faint pale film on the sky)
		surf = { Tex = "Surf", Tile = 5, Sheet = "surf", HeatC = 0.6, HeatU = 0.1, E0 = 0.55, E1 = 1.5, A0 = 0.80,
			LE = 0.25, Z = 0.005, Scroll = 2 },
		shell = { Tex = "Shell", Tile = 6, Sheet = "shell", HeatC = 0.5, HeatU = 0.0, E0 = 0.5, E1 = 1.6, A0 = 0.62,
			LE = 0.20, Z = 0.004, Scroll = 3 },
		-- feather: za5 mat_feather5 heat 0.86 - 0.42 fu (+ the vein): root 0.90, tip 0.50 (was 1.0 .. 0.56: a white
		-- root, pale vanes); A0 0.78 -> 0.95, LE 0.45 -> 0.30
		feather = { Tex = "Feather", Fit = true, HeatC = 0.50, HeatU = 0.40, E0 = 0.6, E1 = 1.4, A0 = 0.95, LE = 0.30,
			Z = 0.008, Scroll = 0, Head = 0.06, Tail = 0 },
	},

	-- PARTICLES (za KINDS / _mat_debris4: drag 1/s, gravity factor (x G; negative rises), spin rad/s, base size
	-- studs, peak alpha, emission strength (-> Brightness as the beams), colour birth -> death, lit or self-lit)
	Particles = {
		-- puff: za's tint ramp edge -> main -> light averages MAIN: birth main -> death edge (was light -> main), LE
		-- 0.6 -> 0.35 (stacked puffs read as a white ball in daylight)
		puff = { Tex = "Puff", Color = { PAL.Main, PAL.Edge }, LE = 0.35, LI = 0, Emit = 1.7, Alpha = 0.6, Drag = 4.0,
			Grav = -0.05, Spin = 0.4, Size = 0.6 },
		spark = { Tex = "Spark", Color = { PAL.Core, PAL.Glint }, LE = 1.0, LI = 0, Emit = 5.0, Alpha = 1.0, Drag = 5.0,
			Grav = 0.0, Spin = 2.5, Size = 0.36, Twinkle = true },
		speck = { Tex = "Dot", Color = { C.Speck, C.Speck }, LE = 0.5, LI = 0, Emit = 0.8, Alpha = 0.9, Drag = 7.0,
			Grav = 0.3, Spin = 0.0, Size = 0.07 },
		chip = { Tex = "Chip", Color = { C.Chip, PAL.Shadow }, LE = 0.0, LI = 1, Emit = 0, Alpha = 1.0, Drag = 0.8,
			Grav = 1.0, Spin = 16.0, Size = 0.17 },
		dust = { Tex = "Dust", Color = { C.Dust, C.Dust }, LE = 0.0, LI = 1, Emit = 0, Alpha = 0.42, Drag = 5.0,
			Grav = -0.02, Spin = 0.5, Size = 1.1 },
		mist = { Tex = "Puff", Color = { C.Mist, C.Mist }, LE = 0.3, LI = 0, Emit = 0.9, Alpha = 0.22, Drag = 8.0,
			Grav = -0.06, Spin = 0.3, Size = 1.0 },
		glint = { Tex = "Spark", Color = { PAL.Core, PAL.Core }, LE = 1.0, LI = 0, Emit = 0.9, Alpha = 1.0, Drag = 14.0,
			Grav = 0.0, Spin = 0.0, Size = 0.09 },
	},
	G = 9.81 * 5.25 / 1.8,                -- zk.G: real gravity in studs/s^2 (1 stud = 1.8 / 5.25 m)
	DragK = 1 / math.log(2),              -- ASSUMED: Roblox Drag = half-lives per second; the kit's drag is e-folds/s
	ParticleSize = 1.0,                   -- Roblox Size per stud of the kit's sprite width
	StretchSquash = 0.35,                 -- o.stretch > 0: VelocityParallel sprites squashed by this (PyroDraw's embers: 0.4)
	BurstLate = 0.25,                     -- a burst with o.t0 joined later than this is skipped (a late joiner)
	BurstJitter = 3,                      -- degrees of spread round each particle's exact direction
	MaxBurst = 96,                        -- particles one Burst call emits at most
	MaxEmitters = 24,                     -- ParticleEmitters per canvas. 10 -> 24 (2026-10-08): a burst takes one per LOOK
	                                      -- (kind, size and life ranges: cfgSig) and a stream one per id, and a Cross-Slash
	                                      -- asks for 16 on a tap, 20 held -- at 10 the X's sparks, puffs, specks, mist and
	                                      -- chips were dropped, with a warning every cast. 24 is PoolKeep.Emitters
	EnemyThin = 0.6,                      -- density x this for other players' effects under Settings.ThinEnemyVFX

	-- LIGHTS (the handoff section 3: Blender W -> Brightness ~ W / 600, capped at 6)
	LightWatts = 600,
	LightMax = 6,
	LightScale = 0.5,                     -- a global trim (RadiantDraw had to go to a sixth): 1.0 lit a hard cyan disk
	                                      -- on the noon floor under every effect; Blender's floor tint is a soft pool
	LightRange = 12,
	LightFlicker = 0.15, LightHz = 29.0,
	CalmLight = 0.6,                      -- Reduce Flashing: light brightness x this, no flicker
	-- RadiantDraw's LightPool (level-based) keeps its own numbers
	LightBrightness = 0.5, LightPoolRange = 10, LightW = 252.0,

	-- sprites (RadiantDraw's glints / motes)
	GlintScale = 1.0,                     -- sprite half-size / the kit's spike length
	GlintHalo = true,                     -- a soft aqua halo (the puff) behind the star (2 Beams per glint; false = 1)
	GlintHaloScale = 1.7,
	MoteScale = 1.0,

	-- the camera kick and the glare
	Kick = { CalmFov = 0.35, MaxFov = 120, MinFov = 1, DefaultDecay = 0.12, MaxPitch = 0.15 },
	Glare = { Max = 0.7, Color = Color3.new(0.9, 1.0, 0.98), DisplayOrder = -5, Calm = 0.6, Hz = 19 },

	FloorLift = 0.04,                     -- Sigil lifts flat ground linework this far
	RootHeight = 3.0,                     -- a R15 HumanoidRootPart over the floor (StageCF of a bare CFrame)
	StaffNeonFrom = 2,                    -- StaffGlow never goes Neon (NOT NEON): above 1 = never

	Budget = { Beams = 420, Lights = 2, Pieces = 400, Glints = 80 },
	PoolKeep = { Spans = 640, Sprites = 128, Lights = 8, Emitters = 24 },

	-- RadiantDraw's widths for the level-based strokes (rad_anim r3 W_QUIET / W_PAYOFF / SLEEVE_W / HEAD_TAPER)
	W_QUIET = 0.05, W_PAYOFF = 0.07,
	SLEEVE_W0 = 1.75, SLEEVE_W1 = 2.9,
	HEAD_TAPER = 0.3,
}
ZephyrDraw.Config = Config
ZephyrDraw.Kinds = Config.Kinds
ZephyrDraw.ParticleKinds = Config.Particles

-- the plan's budget table (ROBLOX_IMPORT_PLAN.md section 3): pass one as Play's opts.Budget (or its name)
ZephyrDraw.Budgets = {
	WindBlade = { Beams = 45, Lights = 1 },       -- per blade in flight (pooled, up to 5); the light is shared
	CrossSlash = { Beams = 260, Lights = 1 },
	Cyclone = { Beams = 640, Lights = 1 },   -- 380 -> 640 (2026-10-07): 72 blades, as the Blender
	Updraft = { Beams = 110, Lights = 1 },
	GustPad = { Beams = 220, Lights = 1 },
	Skyrider = { Beams = 420, Lights = 1 },       -- the bird plus the gust
}

local function TEX(name)
	return Config.Textures[name] or ""
end

-- kinds resolved by name (a table passes through: a custom kind built like Config.Kinds' entries)
local KIND_IX = 0
local function kindOf(k)
	local K
	if type(k) == "table" then K = k else K = Config.Kinds[k or "glow"] or Config.Kinds.glow end
	if K._ix == nil then
		KIND_IX += 1
		K._ix = KIND_IX
	end
	return K
end

----------------------------------------------------------------------------------------------------
-- RADIANTDRAW'S LEVEL LOOKS, RECOLOURED (0 a dim unlit shadow-teal line | 0.5 glowing | 1 white-hot)
----------------------------------------------------------------------------------------------------
--- the CORE strand at a level: heat 0.30 -> 0.97 (shadow teal -> main -> core white), emission x min(1, l / 0.5)
local function level_look(level)
	local l = clamp(level, 0, 1)
	local K = Config.Kinds.core
	local h = 0.30 + 0.67 * l
	local f = min(1, l / 0.5)
	return heatColor(h), f * (K.E0 + K.E1 * h * h)
end

--- the SLEEVE at a level: heat 0.20 -> 0.80 (deep -> edge -> light), the glow kind's emission
local function glow_look(level)
	local l = clamp(level, 0, 1)
	local K = Config.Kinds.glow
	local h = 0.20 + 0.60 * l
	local f = min(1, l / 0.5)
	return heatColor(h), f * (K.E0 + K.E1 * h * h)
end

--- StaffGlow's parts: the shadow teal (idle) -> main -> light
local function staff_look(level)
	local l = clamp(level, 0, 1)
	return heatColor(0.18 + 0.62 * l), l * 2
end

local function lw(level)
	local l = clamp(level, 0, 1)
	if l <= 0.5 then return Config.W_QUIET end
	return Config.W_QUIET + (Config.W_PAYOFF - Config.W_QUIET) * (l - 0.5) / 0.5
end

local function sleeve_w(level)
	return Config.SLEEVE_W0 + (Config.SLEEVE_W1 - Config.SLEEVE_W0) * clamp(level, 0, 1)
end

ZephyrDraw.level_look, ZephyrDraw.glow_look, ZephyrDraw.staff_look = level_look, glow_look, staff_look
ZephyrDraw.lw, ZephyrDraw.sleeve_w = lw, sleeve_w

----------------------------------------------------------------------------------------------------
-- LOOK CACHES: no Color3 / ColorSequence / NumberSequence churn in the hot path
----------------------------------------------------------------------------------------------------
local HQ = 48                                       -- heat steps
local AQ = 40                                       -- opacity steps
local HEATC = {}                                    -- q -> Color3
local HSEQ = {}                                     -- q0 * 64 + q1 -> ColorSequence
local TSEQ = {}                                     -- q0 * 64 + q1 -> NumberSequence (Transparency)
local FIXSEQ = {}                                   -- key -> ColorSequence of one colour
local OPAQUE = NumberSequence.new(0)

local function heatSeq(h0, h1)
	local q0 = floor(clamp(h0, 0, 1) * HQ + 0.5)
	local q1 = floor(clamp(h1, 0, 1) * HQ + 0.5)
	local key = q0 * 64 + q1
	local s = HSEQ[key]
	if s then return key, s end
	local c0 = HEATC[q0]
	if not c0 then c0 = heatColor(q0 / HQ); HEATC[q0] = c0 end
	local c1 = HEATC[q1]
	if not c1 then c1 = heatColor(q1 / HQ); HEATC[q1] = c1 end
	s = (q0 == q1) and ColorSequence.new(c0) or ColorSequence.new(c0, c1)
	HSEQ[key] = s
	return key, s
end

local function transSeq(a0, a1)
	local q0 = floor(clamp(a0, 0, 1) * AQ + 0.5)
	local q1 = floor(clamp(a1, 0, 1) * AQ + 0.5)
	local key = q0 * 64 + q1
	local s = TSEQ[key]
	if s then return key, s end
	s = (q0 == q1) and NumberSequence.new(1 - q0 / AQ) or NumberSequence.new(1 - q0 / AQ, 1 - q1 / AQ)
	TSEQ[key] = s
	return key, s
end

--- one colour as a (key, ColorSequence): kind colours 20000 + ix, Color3 overrides 1e6 + rgb
local function fixedSeq(col, kindIx)
	local key
	if kindIx then
		key = 20000 + kindIx
	else
		key = 1000000 + floor(col.R * 255 + 0.5) * 65536 + floor(col.G * 255 + 0.5) * 256 + floor(col.B * 255 + 0.5)
	end
	local s = FIXSEQ[key]
	if not s then
		s = ColorSequence.new(col)
		FIXSEQ[key] = s
	end
	return key, s
end

-- RadiantDraw's level looks (strokes, glints, motes), cached per level step
local LOOK_CORE, LOOK_GOLD = 1, 2
local LEVEL_Q = 128
local lookCache = { {}, {} }

local function lookEntry(look, level)
	local q = floor(clamp(level, 0, 1) * LEVEL_Q + 0.5)
	local cache = lookCache[look]
	local e = cache[q]
	if e then return e end
	local l = q / LEVEL_Q
	local K = (look == LOOK_CORE) and Config.Kinds.core or Config.Kinds.glow
	local col, s
	if look == LOOK_CORE then col, s = level_look(l) else col, s = glow_look(l) end
	local f = min(1, l / 0.5)
	local op = K.A0 * (0.4 + 0.6 * f)
	local tk, ts = transSeq(op, op)
	e = {
		Key = 50000 + look * 1000 + q,
		Color = col,
		Seq = ColorSequence.new(col),
		Bright = min(Config.MaxBrightness, 1 + Config.BrightScale * (K.BS or 1) * s),
		LE = K.LE * f,                                   -- below 0.5 the line is unlit: it blends in normally
		TKey = tk, TSeq = ts,
		Tex = TEX(K.Tex), Tile = K.Tile,
	}
	cache[q] = e
	return e
end

function ZephyrDraw.ClearLookCache()
	lookCache = { {}, {} }
	table.clear(HEATC)
	table.clear(HSEQ)
	table.clear(TSEQ)
	table.clear(FIXSEQ)
end

----------------------------------------------------------------------------------------------------
-- COORDINATES
----------------------------------------------------------------------------------------------------
--- RadiantDraw's Blender mapping (its figures face -Y): (x, y, z) -> (-x, z, y)
function ZephyrDraw.B(x, y, z)
	if typeof(x) == "Vector3" then return Vector3.new(-x.X, x.Z, x.Y) end
	return Vector3.new(-(x or 0), z or 0, y or 0)
end

function ZephyrDraw.Body(cf, right, up, fwd)
	return cf.Position + cf.RightVector * (right or 0) + cf.UpVector * (up or 0) + cf.LookVector * (fwd or 0)
end

function ZephyrDraw.BodyDir(cf, right, up, fwd)
	return cf.RightVector * (right or 0) + cf.UpVector * (up or 0) + cf.LookVector * (fwd or 0)
end

function ZephyrDraw.ToBody(cf, w)
	return w:Dot(cf.RightVector), w:Dot(cf.UpVector), w:Dot(cf.LookVector)
end

function ZephyrDraw.FromScene(rootCF, at_x, at_y, facing_deg, pB)
	local sceneRoot = CFrame.new(-at_x, Config.RootHeight, at_y) * CFrame.Angles(0, math.rad(facing_deg or 0), 0)
	return rootCF:PointToWorldSpace(sceneRoot:PointToObjectSpace(ZephyrDraw.B(pB)))
end

function ZephyrDraw.Palm(handCF)
	return handCF:PointToWorldSpace(Vector3.new(0, -0.15, 0)), -handCF.UpVector
end

function ZephyrDraw.ReceivePoint(chest, src, lift, skin)
	local aimP = chest + UP * (lift or 0.15)
	local d = aimP - src
	d = (d.Magnitude > 1e-6) and d.Unit or UP
	return aimP - d * (skin or 0.62)
end

--- THE ZEPHYR STAGE: the caster at the origin on the floor facing +Y, +X right, +Z up (studs). Given the root part
--- (or any CFrame standing in for it) -> the flat facing frame at floor level: LookVector = the flattened look,
--- RightVector = its right, UpVector = world up.
function ZephyrDraw.StageCF(src, floorY)
	local cf, fy
	if typeof(src) == "CFrame" then
		cf = src
		fy = floorY or (cf.Position.Y - Config.RootHeight)
	elseif typeof(src) == "Instance" and src:IsA("BasePart") then
		cf = src.CFrame
		if floorY then
			fy = floorY
		else
			local hum = src.Parent and src.Parent:FindFirstChildOfClass("Humanoid")
			if hum and hum.RigType == Enum.HumanoidRigType.R15 then
				fy = cf.Position.Y - src.Size.Y * 0.5 - hum.HipHeight
			else
				fy = cf.Position.Y - Config.RootHeight
			end
		end
	else
		error("ZephyrDraw.StageCF: a BasePart or a CFrame, got " .. typeof(src))
	end
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		local u = -cf.UpVector * math.sign(look.Y)
		flat = Vector3.new(u.X, 0, u.Z)
		if flat.Magnitude < 1e-3 then flat = FWD_DEFAULT end
	end
	flat = flat.Unit
	local p = Vector3.new(cf.Position.X, fy, cf.Position.Z)
	return CFrame.lookAt(p, p + flat, UP)
end

--- a Blender stage point (x right, y forward, z up) in the world: (stageCF * CFrame.new(x, z, -y)).Position
function ZephyrDraw.FromStage(stageCF, x, y, z)
	return stageCF:PointToWorldSpace(Vector3.new(x or 0, z or 0, -(y or 0)))
end

--- the same for a direction
function ZephyrDraw.DirStage(stageCF, x, y, z)
	return stageCF:VectorToWorldSpace(Vector3.new(x or 0, z or 0, -(y or 0)))
end

--- a world point back in stage coordinates -> x, y, z
function ZephyrDraw.ToStage(stageCF, p)
	local l = stageCF:PointToObjectSpace(p)
	return l.X, -l.Z, l.Y
end

--- zk.arc_pts: n points along a (spiral) arc round `axis` through c, radius r -> r1, angle a0 -> a1 (rad) measured
--- from startDir (projected into the plane), climbing `rise` along the axis. Fills and returns out (or a new table).
function ZephyrDraw.arc_pts(c, axis, startDir, r, a0, a1, n, rise, r1, out)
	out = out or {}
	local ax = axis.Unit
	local d0 = startDir - ax * startDir:Dot(ax)
	d0 = (d0.Magnitude > 1e-9) and d0.Unit or perp_any(ax)
	local d1 = ax:Cross(d0)
	r1 = r1 or r
	rise = rise or 0
	for k = 0, n - 1 do
		local s = (n > 1) and k / (n - 1) or 0
		local a = a0 + (a1 - a0) * s
		local rr = r + (r1 - r) * s
		out[k + 1] = c + (d0 * cos(a) + d1 * sin(a)) * rr + ax * (rise * s)
	end
	for k = #out, n + 1, -1 do out[k] = nil end
	return out
end

--- za5.spline: uniform Catmull-Rom through P resampled to n points, then a light Gaussian smoothing (ends kept)
local SPL_A, SPL_B = {}, {}
function ZephyrDraw.spline(P, n, sigma, out)
	out = out or {}
	sigma = sigma or 1.2
	local k = #P
	if k < 2 then
		for i = 1, n do out[i] = P[1] end
		return out
	end
	local A = SPL_A
	for i = 1, n do
		local s = (k - 1) * (i - 1) / max(1, n - 1)
		local j = clamp(floor(s), 0, k - 2)
		local u = s - j
		local p1, p2 = P[j + 1], P[j + 2]
		local p0 = (j >= 1) and P[j] or (p1 * 2 - p2)
		local p3 = (j + 3 <= k) and P[j + 3] or (p2 * 2 - p1)
		local u2, u3 = u * u, u * u * u
		A[i] = (p1 * 2 + (p2 - p0) * u + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 + (p1 * 3 - p0 - p2 * 3 + p3) * u3) * 0.5
	end
	if sigma > 0 and n > 2 then
		local r = floor(3 * sigma)
		local W = SPL_B
		local tot = 0
		for q = -r, r do
			local w = exp(-0.5 * (q / sigma) ^ 2)
			W[q + r + 1] = w
			tot += w
		end
		for i = 1, n do
			local acc = ZERO
			for q = -r, r do
				acc += A[clamp(i + q, 1, n)] * (W[q + r + 1] / tot)
			end
			out[i] = acc
		end
		out[1], out[n] = A[1], A[n]
	else
		for i = 1, n do out[i] = A[i] end
	end
	for i = #out, n + 1, -1 do out[i] = nil end
	return out
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

local RS_KEY, RS_K = 0, 0
local function rsSeed(a, b, c)
	RS_KEY, RS_K = key3(a, b, c), 0
end
local function rsNext()
	RS_K += 1
	return mix(RS_KEY + RS_K * 0x9E3779B9) / TWO32
end

function ZephyrDraw.Rand(a, b, c, k)
	return mix(key3(a, b or 0, c or 0) + (k or 1) * 0x9E3779B9) / TWO32
end

local function randDir()
	local z = rsNext() * 2 - 1
	local ph = rsNext() * TAU
	local rr = sqrt(max(0, 1 - z * z))
	return Vector3.new(rr * cos(ph), z, rr * sin(ph))
end

----------------------------------------------------------------------------------------------------
-- CLOCKS AND SETTINGS (lazy: nothing is required at load)
----------------------------------------------------------------------------------------------------
local vfxLib, settingsLib, viewmodelLib = nil, nil, nil
local function loadLibs()
	if vfxLib == nil then
		vfxLib = false
		local parent = script and script.Parent
		local mod = parent and parent:FindFirstChild("VFXLibrary")
		if mod then
			local ok, lib = pcall(require, mod)
			if ok and type(lib) == "table" then vfxLib = lib end
		end
	end
	if settingsLib == nil then
		settingsLib = false
		local sp = ReplicatedStorage:FindFirstChild("Spellshot")
		local mod = sp and sp:FindFirstChild("SpellshotSettings")
		if mod then
			local ok, lib = pcall(require, mod)
			if ok and type(lib) == "table" then settingsLib = lib end
		end
	end
end

local function timeScale()
	loadLibs()
	if vfxLib and type(vfxLib.ShotTimeScale) == "function" then
		local ok, s = pcall(vfxLib.ShotTimeScale)
		if ok and type(s) == "number" and s > 0 then return s end
	end
	return 1
end
ZephyrDraw.TimeScale = timeScale

function ZephyrDraw.ServerNow()
	return workspace:GetServerTimeNow()
end

--- clip seconds: (serverNow - t0) * scale + offset; t0 nil = a local clock from now
function ZephyrDraw.Clock(t0, offset, scale)
	offset = offset or 0
	scale = scale or timeScale()
	if t0 == nil then
		local o = os.clock()
		return function() return (os.clock() - o) * scale + offset end
	end
	return function() return (workspace:GetServerTimeNow() - t0) * scale + offset end
end

--- RadiantDraw's trail_fn: posFn sampled n times over [t - span, t] (not before t_min), OLDEST FIRST; fills out
function ZephyrDraw.trail_fn(posFn, t, span_, n, t_min, out)
	span_, n, out = span_ or 0.25, n or 10, out or {}
	local a = t - span_
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

--- Reduce Flashing is on
local function calm()
	loadLibs()
	if settingsLib and type(settingsLib.Get) == "function" then
		local ok, v = pcall(settingsLib.Get, "ReduceFlashing")
		if ok then return v == true end
	end
	return false
end
ZephyrDraw.Calm = calm

--- the Camera Shake setting as 0..1 (100 = 1)
local function shakeScale()
	loadLibs()
	if settingsLib and type(settingsLib.Scale) == "function" then
		local ok, v = pcall(settingsLib.Scale, "CameraShake")
		if ok and type(v) == "number" then return clamp(v, 0, 2) end
	end
	return 1
end

--- how much of an effect to draw: Settings.EffectDensity (0.45 .. 1.15), thinned for other players' effects
function ZephyrDraw.Density(own)
	loadLibs()
	local d = 1
	if settingsLib then
		local e = settingsLib.EffectDensity
		if type(e) == "number" and e > 0 then d = e end
		if settingsLib.ThinEnemyVFX and not own then d *= Config.EnemyThin end
	end
	return d
end

--- the local camera is the first-person viewmodel view (FirstPersonController's one fact: Player.CameraMode)
function ZephyrDraw.FirstPerson()
	local p = Players.LocalPlayer
	return p ~= nil and p.CameraMode == Enum.CameraMode.LockFirstPerson
end

--- this character is the local player's
function ZephyrDraw.IsLocal(character)
	local p = Players.LocalPlayer
	return p ~= nil and character ~= nil and p.Character == character
end

--- (2026-10-19, audit P5F-06) this character is NOT an enemy of the local player (VFXLibrary.IsEnemy: yours, a teammate's
--- in your match, an ally dummy's): what Reduce Enemy VFX spares. A caller passes it as Play's / new's Own -- Own reads
--- nothing here but Density -- for a teammate's effect, so only an enemy's is thinned. Not a character: false.
function ZephyrDraw.Friendly(character)
	if typeof(character) ~= "Instance" then return false end
	if ZephyrDraw.IsLocal(character) then return true end
	loadLibs()
	if vfxLib and type(vfxLib.IsEnemy) == "function" then
		local ok, enemy = pcall(vfxLib.IsEnemy, character)
		if ok then return enemy ~= true end
	end
	return false
end

function ZephyrDraw.CameraCF()
	local c = workspace.CurrentCamera
	return c and c.CFrame or CFrame.new()
end

----------------------------------------------------------------------------------------------------
-- THE CAMERA AND THE SUN (read once per Begin)
----------------------------------------------------------------------------------------------------
local camPos, camUp, camRight, camLook = Vector3.new(0, 0, 10), UP, XAX, FWD_DEFAULT
local sunDir = Vector3.new(0.3, 0.9, 0.3).Unit

local function camRefresh()
	local c = workspace.CurrentCamera
	if c then
		local cf = c.CFrame
		camPos, camUp, camRight, camLook = cf.Position, cf.UpVector, cf.RightVector, cf.LookVector
	end
	local ok, s = pcall(Lighting.GetSunDirection, Lighting)
	if ok and typeof(s) == "Vector3" and s.Magnitude > 1e-6 then sunDir = s.Unit end
end

--- RadiantDraw's _cam_dir: from p toward the camera
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
local freeSpans, freeSprites, freeLights, freeEmit = {}, {}, {}, {}
local folderSource = nil
local warned = {}
local HAS_OFFSET = nil                              -- Beam:SetTextureOffset is callable (checked on the first beam)

local function warnOnce(key, msg)
	if not warned[key] then
		warned[key] = true
		warn("[ZephyrDraw] " .. msg)
	end
end

function ZephyrDraw.SetFolder(src)
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
	loadLibs()
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
	table.clear(freeEmit)
	if f and f.Parent ~= nil then f:Destroy() end       -- our own runtime folder, half-broken
	f = Instance.new("Folder")
	f.Name = Config.SubFolderName
	a = Instance.new("Part")
	a.Name = "ZephyrDrawAnchor"
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

local function newAtt(name)
	local at = Instance.new("Attachment")
	at.Name = name or "ZephyrKnot"
	at.Parent = root.Anchor
	return at
end

local function newBeam(a0, a1, z, stretch)
	local b = Instance.new("Beam")
	b.Name = "ZephyrBeam"
	b.Enabled = false
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.LightInfluence = 0
	b.LightEmission = 1
	b.Brightness = 1
	b.Transparency = OPAQUE
	b.Segments = 1
	b.Width0, b.Width1 = 0, 0
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.ZOffset = z
	b.Texture = ""
	b.TextureMode = stretch and Enum.TextureMode.Stretch or Enum.TextureMode.Wrap
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.Parent = root.Folder
	if HAS_OFFSET == nil then
		HAS_OFFSET = pcall(function() b:SetTextureOffset(0) end)
		if not HAS_OFFSET then warnOnce("nooffset", "Beam:SetTextureOffset is unavailable: ribbons seam at their knots") end
	end
	return b
end

-- a beam's last-written state (write-if-changed)
local function beamState(z)
	return { on = false, ck = -1, br = -1, le = -1, tk = -1, face = true, w0 = 0, w1 = 0, c0 = 0, c1 = 0, seg = 1,
		z = z, tex = "", tl = 1, off = 0, spd = 0 }
end

-- a span: two Attachments; B1 = the outer strand (always), B2 = the inner strand (made on first use)
local function newSpan()
	local a0, a1 = newAtt(), newAtt()
	return { A0 = a0, A1 = a1, B1 = newBeam(a0, a1, 0, false), S1 = beamState(0), B2 = nil, S2 = nil }
end

local function spanB2(s)
	if not s.B2 then
		s.B2 = newBeam(s.A0, s.A1, 0, false)
		s.S2 = beamState(0)
	end
	return s.B2, s.S2
end

local function newSprite()
	local a0, a1 = newAtt(), newAtt()
	return { A0 = a0, A1 = a1, B = newBeam(a0, a1, 0, true), ST = beamState(0) }
end

local function newLight()
	local at = newAtt("ZephyrLight")
	local l = Instance.new("PointLight")
	l.Enabled = false
	l.Shadows = false
	l.Color = C.Light3
	l.Range = Config.LightRange
	l.Brightness = 0
	l.Parent = at
	return { Att = at, L = l, on = false, b = 0, r = Config.LightRange, c = C.Light3 }
end

local function beamOff(b, st)
	if st and st.on then
		st.on = false
		b.Enabled = false
	end
end

local function beamWrite(b, st, ck, cseq, br, le, tk, tseq, face, w0, w1, c0, c1, seg, z, tex, tl)
	if st.ck ~= ck then st.ck = ck; b.Color = cseq end
	if st.br ~= br then st.br = br; b.Brightness = br end
	if st.le ~= le then st.le = le; b.LightEmission = le end
	if st.tk ~= tk then st.tk = tk; b.Transparency = tseq end
	if st.face ~= face then st.face = face; b.FaceCamera = face end
	if st.w0 ~= w0 then st.w0 = w0; b.Width0 = w0 end
	if st.w1 ~= w1 then st.w1 = w1; b.Width1 = w1 end
	if st.c0 ~= c0 then st.c0 = c0; b.CurveSize0 = c0 end
	if st.c1 ~= c1 then st.c1 = c1; b.CurveSize1 = c1 end
	if st.seg ~= seg then st.seg = seg; b.Segments = seg end
	if st.z ~= z then st.z = z; b.ZOffset = z end
	if tex and st.tex ~= tex then st.tex = tex; b.Texture = tex end
	if tl and abs(st.tl - tl) > 1e-3 then st.tl = tl; b.TextureLength = tl end
	if not st.on then st.on = true; b.Enabled = true end
end

--- U continuity / scroll: off in texture repeats (Config.TexOffset), else a TextureSpeed scroll
local function beamUV(b, st, off, tiles_per_s)
	if Config.TexOffset and HAS_OFFSET then
		off = (off * Config.TexOffsetSign) % 1
		if abs(off - st.off) > 1e-3 then
			st.off = off
			b:SetTextureOffset(Config.TexOffsetInStuds and off * st.tl or off)
		end
	elseif st.spd ~= tiles_per_s then
		st.spd = tiles_per_s
		b.TextureSpeed = tiles_per_s
	end
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
	beamOff(s.B1, s.S1)
	if s.B2 then beamOff(s.B2, s.S2) end
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

local SLOT_PARTS = { "B1", "B2", "B", "L", "E", "A0", "A1", "Att" }
local function destroySlot(s)
	for _, k in ipairs(SLOT_PARTS) do
		local inst = s[k]
		if inst then inst:Destroy() end
	end
end

----------------------------------------------------------------------------------------------------
-- THE KNOT CHAIN: one stroke at a time (module scratch arrays, reused: no per-frame tables)
--   RadiantDraw's: KP position, KT unit tangent (the Attachment Axis), KH0/KH1 handle lengths behind/ahead, KM width
--   multiplier, KY secondary axis, KW width, SL span lengths. The Zephyr ribbons add per knot: KIX the source point,
--   KSS studs along the source path (texture U), KUU u (0 head .. 1 tail), KWO / KWI outer / inner width, KAO / KAI
--   opacity, KHO / KHI heat, KNN plane normal, KWD width direction.
----------------------------------------------------------------------------------------------------
local KP, KT, KH0, KH1, KM, KY, KW, SL, KS, KSP = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local KIX, KSS, KUU, KWO, KWI, KAO, KAI, KHO, KHI, KNN, KWD = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local CUM = {}
local KN = 0

local function kpush(p, t, h0, h1, m)
	KN += 1
	KP[KN], KT[KN], KH0[KN], KH1[KN], KM[KN] = p, t, h0, h1, m
end

local function kStraight(a, b)
	KN = 0
	local d = b - a
	local m = d.Magnitude
	if m < 1e-6 then return end
	local t = d / m
	kpush(a, t, 0, 0, 1)
	kpush(b, t, 0, 0, 1)
end

--- RadiantDraw's knots through pts (duplicates within eps dropped); smoothC: Catmull-Rom handles
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

--- a stroke still drawing on (u < 1) eases to 35% over its last HEAD_TAPER studs
local function kHead(drawing)
	if not drawing or KN < 2 then return end
	local L = kLengths()
	kTaper(min(Config.HEAD_TAPER, L * 0.3), 0, 0.35, 0)
end

--- THE ZEPHYR CHAIN: knots ON the given points, <= maxSpans spans at even arc length, Hermite handles (the tangent
--- through the neighbours, each handle a third of its own chord: no overshoot where spacing is uneven). Fills KP, KT,
--- KH0, KH1, KIX (source index; n + 1 = the wrap knot of a closed chain), KSS; returns the source path's length.
local function zChain(pts, n, closed, maxSpans, smoothC)
	KN = 0
	if n < 2 then return 0 end
	CUM[1] = 0
	for i = 2, n do CUM[i] = CUM[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	local L = CUM[n]
	local total = n
	if closed then
		L += (pts[1] - pts[n]).Magnitude
		total = n + 1
		CUM[total] = L
	end
	if L < 1e-5 then return 0 end
	local segs = total - 1
	local spans = min(segs, max(1, maxSpans or Config.MaxSpans))
	if spans >= segs then
		for i = 1, total do KIX[i] = i end
		KN = total
	else
		KN = 1
		KIX[1] = 1
		for k = 1, spans - 1 do
			local goal = L * k / spans
			local lim = total - (spans - k)          -- leave a source point for every knot still to place
			local best = KIX[KN] + 1
			while best < lim and CUM[best + 1] <= goal do best += 1 end
			if best + 1 <= lim and abs(CUM[best + 1] - goal) < abs(CUM[best] - goal) then best += 1 end
			KN += 1
			KIX[KN] = best
		end
		KN += 1
		KIX[KN] = total
	end
	for k = 1, KN do
		local ix = KIX[k]
		KP[k] = (ix > n) and pts[1] or pts[ix]
		KSS[k] = CUM[ix]
	end
	for k = 1, KN do
		local pPrev, pNext
		if closed then
			pPrev = (k == 1) and KP[KN - 1] or KP[k - 1]
			pNext = (k == KN) and KP[2] or KP[k + 1]
		else
			pPrev = KP[max(k - 1, 1)]
			pNext = KP[min(k + 1, KN)]
		end
		local d = pNext - pPrev
		local dm = d.Magnitude
		if dm > 1e-9 then
			KT[k] = d / dm
		else
			local e = KP[min(k + 1, KN)] - KP[max(k - 1, 1)]
			KT[k] = (e.Magnitude > 1e-9) and e.Unit or UP
		end
		if smoothC then
			KH0[k] = (KP[k] - pPrev).Magnitude / 3
			KH1[k] = (pNext - KP[k]).Magnitude / 3
		else
			KH0[k], KH1[k] = 0, 0
		end
		KM[k] = 1
	end
	return L
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
	elseif n then
		y = n:Cross(t)
	else
		y = UP - t * UP:Dot(t)
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

--- RadiantDraw's emitChain (the level-based strokes): the Zephyr CORE strand (B1, in front) and the GLOW sleeve
--- (B2, sleeve_w(level) x wider) when bezel; camera-facing when n and wdir are nil, flat otherwise
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
	zc = zc or ((look == LOOK_GOLD) and Config.Kinds.glow.Z or Config.Kinds.core.Z)
	for i = 1, KN do
		KY[i] = orientY(KT[i], n, wdir, face)
		local wi = w
		if fk > 0 then
			local wf = (KP[i] - camPos).Magnitude * fk
			if wf > wi then wi = wf end
		end
		KW[i] = wi * KM[i]
	end
	kLengths()
	local acc = 0
	local nb = 0
	for i = 1, KN - 1 do
		local s = takeSpan(cv)
		place0(s, KP[i], KT[i], KY[i])
		place1(s, KP[i + 1], KT[i + 1], KY[i + 1])
		local c0, c1 = KH1[i], KH0[i + 1] * sign
		local seg = (c0 > 1e-4 or abs(c1) > 1e-4) and segC or 1
		beamWrite(s.B1, s.S1, e.Key, e.Seq, e.Bright, e.LE, e.TKey, e.TSeq, face, KW[i], KW[i + 1], c0, c1, seg, zc,
			e.Tex, e.Tile)
		beamUV(s.B1, s.S1, acc / e.Tile, 0)
		nb += 1
		if eg then
			local b2, s2 = spanB2(s)
			beamWrite(b2, s2, eg.Key, eg.Seq, eg.Bright, eg.LE, eg.TKey, eg.TSeq, face, KW[i] * sw, KW[i + 1] * sw, c0, c1,
				seg, Config.Kinds.glow.Z, eg.Tex, eg.Tile)
			beamUV(b2, s2, acc / eg.Tile, 0)
			nb += 1
		elseif s.B2 then
			beamOff(s.B2, s.S2)
		end
		acc += SL[i]
	end
	cv.Beams += nb
	return true
end

--- a camera-facing (n nil) or flat (plane n) textured square of half-size `half` at p, turned by rot
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
	local e = lookEntry(look, level)
	beamWrite(s.B, s.ST, e.Key, e.Seq, e.Bright, e.LE, e.TKey, e.TSeq, n == nil, 2 * half, 2 * half, 0, 0, 1, z, tex, nil)
	cv.Beams += 1
end

-- THE ZEPHYR STRANDS: what one Beam of a span draws (module scratch, filled per call: no per-frame tables)
local STRAND_O = {}
local STRAND_I = {}

--- o[k], else base[k], else d (an inner strand's options fall back to its outer strand's)
local function pick(o, base, k, d)
	local v = o and o[k]
	if v == nil and base then v = base[k] end
	if v == nil then return d end
	return v
end

local function strandFrom(S, K, o, base, clockT)
	-- o = this strand's options; base = the fallback for what a pair shares (glow, scroll, t, z: CoreGlow's o for its
	-- core); the colour, heat and emission constants are always the strand's own; clockT = cv.T
	S.K = K
	S.Glow = pick(o, base, "glow", 1)
	S.E0 = pick(o, nil, "e0", K.E0)
	S.E1 = pick(o, nil, "e1", K.E1)
	S.LE = pick(o, nil, "le", K.LE)                      -- o.le: one call's own LightEmission (default: the kind's)
	S.BS = Config.BrightScale * (K.BS or 1)              -- a kind's own brightness scale (the white-hot cores)
	S.Z = K.Z + pick(o, base, "z", 0)
	S.Tex = TEX(K.Tex)
	S.Tile = K.Tile or 4
	S.Fit = K.Fit == true
	S.Scroll = pick(o, base, "scroll", K.Scroll or 0)
	S.Clock = pick(o, base, "t", clockT)
	local col = pick(o, nil, "color", nil)
	if col then
		S.ColKey, S.ColSeq = fixedSeq(col, nil)
	elseif K.Color then
		S.ColKey, S.ColSeq = fixedSeq(K.Color, K._ix)
	else
		S.ColKey, S.ColSeq = nil, nil
	end
	return S
end

local AEPS = Config.AlphaEps

local function writeStrand(b, st, S, i, KAa, KHa, KWa, face, c0, c1, seg, Lc)
	local tk, tseq = transSeq(KAa[i], KAa[i + 1])
	local ck, cseq
	local h0, h1 = KHa[i], KHa[i + 1]
	if S.ColKey then ck, cseq = S.ColKey, S.ColSeq else ck, cseq = heatSeq(h0, h1) end
	local hm = clamp((h0 + h1) * 0.5, 0, 1)
	local br = 1 + S.BS * S.Glow * (S.E0 + S.E1 * hm * hm)
	if br > Config.MaxBrightness then br = Config.MaxBrightness end
	if br < 0 then br = 0 end
	br = floor(br * 64 + 0.5) / 64
	local tile = S.Fit and max(Lc, 0.05) or S.Tile
	beamWrite(b, st, ck, cseq, br, S.LE, tk, tseq, face, KWa[i], KWa[i + 1], c0, c1, seg, S.Z, S.Tex, tile)
	if S.Fit then
		beamUV(b, st, KSS[i] / tile, 0)
	else
		beamUV(b, st, (KSS[i] - S.Scroll * S.Clock) / tile, S.Scroll / tile)
	end
end

--- emit the current Zephyr chain: the outer strand STRAND_O (KWO, KAO, KHO) and, when inner, STRAND_I (KWI, KAI, KHI)
--- on the same knots. Per knot: KNN / KWD (flat) or face. Returns the Beams drawn.
local function emitZ(cv, face, inner, Lc)
	if KN < 2 then return 0 end
	local fk = Config.MinWidthPerStud
	local sign = Config.CurveSize1Sign
	local segC = Config.CurveSegments
	for i = 1, KN do
		KY[i] = orientY(KT[i], KNN[i], KWD[i], face)
		if fk > 0 then
			local fl = (KP[i] - camPos).Magnitude * fk
			if KWO[i] > 0 and KWO[i] < fl then KWO[i] = fl end
			if inner and KWI[i] > 0 and KWI[i] < fl then KWI[i] = fl end
		end
	end
	local nb = 0
	for i = 1, KN - 1 do
		local drawO = (KAO[i] > AEPS or KAO[i + 1] > AEPS) and (KWO[i] > 0 or KWO[i + 1] > 0)
		local drawI = inner and (KAI[i] > AEPS or KAI[i + 1] > AEPS) and (KWI[i] > 0 or KWI[i + 1] > 0)
		if drawO or drawI then
			local s = takeSpan(cv)
			place0(s, KP[i], KT[i], KY[i])
			place1(s, KP[i + 1], KT[i + 1], KY[i + 1])
			local c0, c1 = KH1[i], KH0[i + 1] * sign
			if c0 > 1e-4 or abs(c1) > 1e-4 then
				-- a span whose end tangents both lie along its chord is straight: no curve, one segment
				local ch = KP[i + 1] - KP[i]
				local cm = ch.Magnitude
				if cm < 1e-6 or (KT[i]:Dot(ch) > 0.99995 * cm and KT[i + 1]:Dot(ch) > 0.99995 * cm) then
					c0, c1 = 0, 0
				end
			end
			local seg = (c0 > 1e-4 or abs(c1) > 1e-4) and segC or 1
			if drawO then
				writeStrand(s.B1, s.S1, STRAND_O, i, KAO, KHO, KWO, face, c0, c1, seg, Lc)
				nb += 1
			else
				beamOff(s.B1, s.S1)
			end
			if drawI then
				local b2, s2 = spanB2(s)
				writeStrand(b2, s2, STRAND_I, i, KAI, KHI, KWI, face, c0, c1, seg, Lc)
				nb += 1
			elseif s.B2 then
				beamOff(s.B2, s.S2)
			end
		end
	end
	cv.Beams += nb
	return nb
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
local function resolveBudget(b)
	if type(b) == "string" then return ZephyrDraw.Budgets[b] or Config.Budget end
	if type(b) == "table" then return b end
	return Config.Budget
end

function ZephyrDraw.new(name, prewarm, opts)
	ensureRoot()
	local own = opts and opts.Own or false
	local cv = setmetatable({
		Name = name or "fx", CurTag = name or "fx", T = 0, gen = root.Gen,
		spans = {}, sprites = {}, lights = {},
		nSpan = 0, nSprite = 0, nLight = 0, uSpan = 0, uSprite = 0, uLight = 0,
		Pieces = 0, Glints = 0, Lights = 0, Beams = 0, Particles = 0,
		TagPieces = {}, TagGlints = {}, TagLights = {},
		Peak = { Pieces = 0, PiecesT = 0, Glints = 0, GlintsT = 0, Lights = 0, LightsT = 0, Beams = 0, BeamsT = 0 },
		warnedP = false, warnedG = false, warnedL = false, warnedB = false, warnedE = false, Dead = false,
		Own = own, Density = ZephyrDraw.Density(own), Limits = resolveBudget(opts and opts.Budget),
		-- particles: every emitter slot this canvas holds, by look signature (bursts) and by stream id
		eslots = {}, esig = {}, estream = {}, fired = {}, frame = 0,
		CamPos = camPos, CamLook = camLook,
	}, Canvas)
	if prewarm then
		for i = 1, prewarm.Spans or 0 do cv.spans[i] = table.remove(freeSpans) or newSpan() end
		for i = 1, prewarm.Sprites or 0 do cv.sprites[i] = table.remove(freeSprites) or newSprite() end
		for i = 1, prewarm.Lights or 0 do cv.lights[i] = table.remove(freeLights) or newLight() end
		for _ = 1, prewarm.Emitters or 0 do
			if #freeEmit < Config.PoolKeep.Emitters then
				local at = newAtt("ZephyrEmit")
				local e = Instance.new("ParticleEmitter")
				e.Enabled = false
				e.Rate = 0
				e.Parent = at
				table.insert(freeEmit, { Att = at, E = e, sig = nil, freeAt = 0, on = false, rate = -1, life = 1 })
			end
		end
	end
	return cv
end

function Canvas:Begin(t)
	ensureRoot()
	if self.gen ~= root.Gen then                         -- the folder was rebuilt: our old slots are gone
		self.gen = root.Gen
		table.clear(self.spans)
		table.clear(self.sprites)
		table.clear(self.lights)
		table.clear(self.eslots)
		table.clear(self.esig)
		table.clear(self.estream)
		self.uSpan, self.uSprite, self.uLight = 0, 0, 0
	end
	camRefresh()
	self.CamPos, self.CamLook = camPos, camLook
	self.T = t or 0
	self.frame += 1
	-- (2026-10-19, audit P5E-06) the settings re-read every 30 frames, not only at new(): a long-lived canvas (Wind
	-- Blade's shared bursts) follows a Graphics Quality or Reduce Enemy VFX change mid-session
	if self.frame % 30 == 1 then
		self.Density = ZephyrDraw.Density(self.Own)
		-- (2026-10-19, audit P5E-22) Graphics Quality ALONE (never the enemy factor, so no hazard is thinned by it):
		-- every ribbon's span budget x this (LOW halves the Beams of a ribbon; rings keep their exact 90-degree arcs)
		self.SpanK = clamp(ZephyrDraw.Density(true), 0.5, 1)
	end
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
	-- streams not drawn this frame stop emitting (their particles fly on)
	for _, s in pairs(self.estream) do
		if s.on and s.drawn ~= self.frame then
			s.on = false
			s.E.Enabled = false
		end
	end
	local P, B = self.Peak, self.Limits
	if self.Pieces > P.Pieces then P.Pieces, P.PiecesT = self.Pieces, self.T end
	if self.Glints > P.Glints then P.Glints, P.GlintsT = self.Glints, self.T end
	if self.Lights > P.Lights then P.Lights, P.LightsT = self.Lights, self.T end
	if self.Beams > P.Beams then P.Beams, P.BeamsT = self.Beams, self.T end
	if B.Beams and self.Beams > B.Beams and not self.warnedB then
		self.warnedB = true
		warn(string.format("[ZephyrDraw] %s: %d Beams at t=%.2f (budget %d)", self.Name, self.Beams, self.T, B.Beams))
	end
	if B.Lights and self.Lights > B.Lights and not self.warnedL then
		self.warnedL = true
		warn(string.format("[ZephyrDraw] %s: %d lights at t=%.2f (budget %d)", self.Name, self.Lights, self.T, B.Lights))
	end
	if B.Pieces and self.Pieces > B.Pieces and not self.warnedP then
		self.warnedP = true
		warn(string.format("[ZephyrDraw] %s: %d pieces at t=%.2f (budget %d)", self.Name, self.Pieces, self.T, B.Pieces))
	end
	if B.Glints and self.Glints > B.Glints and not self.warnedG then
		self.warnedG = true
		warn(string.format("[ZephyrDraw] %s: %d glints at t=%.2f (budget %d)", self.Name, self.Glints, self.T, B.Glints))
	end
	return self.Beams, self.Lights
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
		Beams = self.Beams, Lights = self.Lights, Particles = self.Particles, Pieces = self.Pieces, Glints = self.Glints,
		Peak = { Beams = P.Beams, BeamsT = P.BeamsT, Pieces = P.Pieces, PiecesT = P.PiecesT, Glints = P.Glints,
			GlintsT = P.GlintsT, Lights = P.Lights, LightsT = P.LightsT },
		Tags = tags,
		Slots = { Spans = #self.spans, Sprites = #self.sprites, Lights = #self.lights, Emitters = #self.eslots },
		Limits = self.Limits,
	}
end

local function releaseEmitter(s)
	s.on = false
	s.E.Enabled = false
	s.E.Rate = 0
	local rest = max(s.freeAt - os.clock(), 0)
	if #freeEmit < Config.PoolKeep.Emitters then
		freeEmit[#freeEmit + 1] = s
	else
		-- over the pool: let its particles finish, then go
		task.delay(rest + 0.1, function()
			if s.Att then s.Att:Destroy() end
		end)
	end
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
	for _, s in ipairs(self.eslots) do
		if alive then releaseEmitter(s) else destroySlot(s) end
	end
	table.clear(self.spans)
	table.clear(self.sprites)
	table.clear(self.lights)
	table.clear(self.eslots)
	table.clear(self.esig)
	table.clear(self.estream)
	self.uSpan, self.uSprite, self.uLight = 0, 0, 0
end

function ZephyrDraw.Stats()
	return { FreeSpans = #freeSpans, FreeSprites = #freeSprites, FreeLights = #freeLights, FreeEmitters = #freeEmit,
		Generation = root.Gen }
end

----------------------------------------------------------------------------------------------------
-- THE ZEPHYR RIBBONS (za.Ribbon.set / ring / path_ribbon, za5.Sheet / Shell)
----------------------------------------------------------------------------------------------------
do -- (a block: its locals stay out of the module top level, which Luau caps at 200 registers)
--- za mat_wind's alpha along u: the soft head smoothstep(u, 0, head), the tail ((1 - u) / tail)^1.2 fraying
local function taperAt(u, head, tail)
	local a = 1
	if head > 1e-4 then a = sst(u, 0, head) end
	if tail > 1e-4 then
		local tp = clamp((1 - u) / max(tail, 0.02), 0, 1)
		local fray = 1 - tp
		a *= tp ^ 1.2 * (1 - fray + fray * Config.TailFray)
	end
	return a
end

-- the first / last span of a chain is linear in alpha: a head / tail fade much shorter than it would smear over the
-- whole span (a too-soft head). The end knot takes the opacity that keeps the faded area about the kit's.
local function endFix(KA, head, tail)
	if KN < 2 then return end
	if head > 1e-4 then
		local du = KUU[2] - KUU[1]
		if du > head and KUU[1] < head then
			KA[1] = max(KA[1], KA[2] * clamp(1 - 2 * (head - KUU[1]) / du, 0, 1))
		end
	end
	if tail > 1e-4 then
		local du = KUU[KN] - KUU[KN - 1]
		if du > tail and KUU[KN] > 1 - tail then
			KA[KN] = max(KA[KN], KA[KN - 1] * clamp(1 - 2 * (KUU[KN] - (1 - tail)) / du, 0, 1))
		end
	end
end

local function sampleArr(arr, ix, n)
	local v = arr[(ix > n) and 1 or ix]
	return v
end

--- the ribbon core: pts (head first), the outer kind Ko (widths wO), an inner kind Ki (widths wI | InnerWidth x wO),
--- o for the outer strand, oi (o.core) for the inner (missing fields fall back to o)
local function ribbonCore(cv, pts, wO, Ko, Ki, wI, o, oi)
	local n = #pts
	if n < 2 then return 0 end
	local fadeO = opt(o, "fade", 1)
	if fadeO <= 0 and not Ki then return 0 end
	local closed = opt(o, "closed", false)
	local ms = opt(o, "maxSpans", Config.MaxSpans)
	if (cv.SpanK or 1) < 1 then ms = max(1, floor(ms * cv.SpanK + 0.5)) end   -- (2026-10-19, audit P5E-22)
	local L = zChain(pts, n, closed, ms, not opt(o, "straight", false))
	if KN < 2 then return 0 end
	local nO, sO = opt(o, "n", nil), opt(o, "side", nil)
	local face = (nO == nil and sO == nil)
	local nIsV, sIsV = typeof(nO) == "Vector3", typeof(sO) == "Vector3"
	local u0, u1 = opt(o, "u0", 0), opt(o, "u1", 1)
	-- the outer strand
	local alO = opt(o, "alpha", 0.5)
	local arrA = opt(o, "alphas", nil)
	if type(alO) == "table" then arrA, alO = alO, 0.5 end
	local mulO = fadeO * (alO / 0.5) * opt(o, "a0", Ko.A0)
	local headO = opt(o, "head", Ko.Head or Config.HeadDefault)
	local tailO = opt(o, "tail", Ko.Tail or Config.TailDefault)
	local heatO = opt(o, "heat", 0)
	strandFrom(STRAND_O, Ko, o, nil, cv.T)
	-- the inner strand
	local mulI, headI, tailI, heatI, wIarr, wIn, ratio = 0, 0, 0, 0, nil, nil, 0
	if Ki then
		local fadeI = pick(oi, o, "fade", 1)
		local alI = (oi and oi.alpha) or 0.5                   -- the inner strand's own zk_alpha (the kit's default)
		if type(alI) == "table" then alI = 0.5 end
		mulI = fadeI * (alI / 0.5) * ((oi and oi.a0) or Ki.A0)
		headI = pick(oi, o, "head", Ki.Head or Config.HeadDefault)
		tailI = pick(oi, o, "tail", Ki.Tail or Config.TailDefault)
		heatI = (oi and oi.heat) or 0
		strandFrom(STRAND_I, Ki, oi, o, cv.T)
		if type(wI) == "table" then wIarr = wI elseif type(wI) == "number" then wIn = wI end
		ratio = Ko.InnerWidth or 0.34
	end
	if mulO <= AEPS and (not Ki or mulI <= AEPS) then
		KN = 0
		return 0
	end
	local wArr = (type(wO) == "table") and wO or nil
	local wNum = (type(wO) == "number") and wO or 0
	local invL = 1 / L
	for k = 1, KN do
		local ix = KIX[k]
		local u = u0 + (u1 - u0) * (KSS[k] * invL)
		KUU[k] = u
		local w = wArr and (sampleArr(wArr, ix, n) or 0) or wNum
		KWO[k] = w
		local pp = arrA and (sampleArr(arrA, ix, n) or 1) or 1
		KAO[k] = clamp(taperAt(u, headO, tailO) * pp * mulO, 0, 1)
		KHO[k] = Ko.HeatC + Ko.HeatU * (1 - u) + heatO
		if Ki then
			local wi
			if wIarr then wi = sampleArr(wIarr, ix, n) or 0 elseif wIn then wi = wIn else wi = w * ratio end
			KWI[k] = wi
			KAI[k] = clamp(taperAt(u, headI, tailI) * pp * mulI, 0, 1)
			KHI[k] = Ki.HeatC + Ki.HeatU * (1 - u) + heatI
		end
		if face then
			KNN[k], KWD[k] = nil, nil
		elseif sO ~= nil then
			KNN[k], KWD[k] = nil, sIsV and sO or sampleArr(sO, ix, n)
		else
			KNN[k], KWD[k] = nIsV and nO or sampleArr(nO, ix, n), nil
		end
	end
	if fadeO <= 0 then for k = 1, KN do KAO[k] = 0 end end
	endFix(KAO, headO, tailO)
	if Ki then endFix(KAI, headI, tailI) end
	local nb = emitZ(cv, face, Ki ~= nil, L)
	countP(cv, nb > 0 and 1 or 0, opt(o, "tag", nil))
	return nb
end

local function innerOf(K, o)
	if K.Inner and opt(o, "inner", true) ~= false then return kindOf(K.Inner) end
	return nil
end

--- THE WORKHORSE (za.Ribbon.set): a smooth ribbon of `kind` through pts (pts[1] = the head)
function Canvas:Ribbon(pts, widths, kind, o)
	local K = kindOf(kind)
	local Ki = innerOf(K, o)
	return ribbonCore(self, pts, widths, K, Ki, opt(o, "inner_w", nil), o, opt(o, "core", nil))
end

function Canvas:Core(pts, widths, o)
	return ribbonCore(self, pts, widths, kindOf("core"), nil, nil, o, nil)
end

function Canvas:Glow(pts, widths, o)
	return ribbonCore(self, pts, widths, kindOf("glow"), nil, nil, o, nil)
end

function Canvas:Blade(pts, widths, o)
	return self:Ribbon(pts, widths, "blade", o)
end

function Canvas:Vapor(pts, widths, o)
	return ribbonCore(self, pts, widths, kindOf("vapor"), nil, nil, o, nil)
end

--- the kit's standard pair: the glow sleeve (wGlow, o) with the white-hot core (wCore, o.core) on top, one knot set
function Canvas:CoreGlow(pts, wCore, wGlow, o)
	return ribbonCore(self, pts, wGlow, kindOf("glow"), kindOf("core"), wCore, o, opt(o, "core", nil))
end

--- za.ring: a closed flat ring of `kind` (width radial, in the plane normal to n); o.a0 / o.a1 for an arc
function Canvas:RingK(c, r, n, width, kind, o)
	local K = kindOf(kind)
	local fade = opt(o, "fade", 1)
	if fade <= 0 or r <= 1e-4 or width <= 0 then return 0 end
	local a0, a1 = opt(o, "a0", 0), opt(o, "a1", TAU)
	local u = clamp(opt(o, "u", 1), 0, 1)
	a1 = a0 + (a1 - a0) * u
	if abs(a1 - a0) < 1e-4 then return 0 end
	local ux, vx, nn = basis(n or UP, opt(o, "ref", nil))
	kArc(c, ux, vx, r, a0, a1)
	if KN < 2 then return 0 end
	local face = opt(o, "face", false)
	local flip = (opt(o, "flip", false) ~= Config.RingFlip) and -1 or 1
	local al = opt(o, "alpha", 0.5)
	if type(al) ~= "number" then al = 0.5 end
	local mul = fade * (al / 0.5) * K.A0                            -- (o.a0 is the arc's start angle here)
	local taper = opt(o, "taper", false)
	local head, tail = opt(o, "head", K.Head or Config.HeadDefault), opt(o, "tail", K.Tail or Config.TailDefault)
	local heat = K.HeatC + K.HeatU * 0.5 + opt(o, "heat", 0)
	strandFrom(STRAND_O, K, o, nil, self.T)
	local sweep = abs(a1 - a0)
	local L = r * sweep
	local d = (a1 - a0) / (KN - 1)
	for k = 1, KN do
		local a = a0 + d * (k - 1)
		KIX[k] = k
		KSS[k] = r * abs(a - a0)
		local uu = (k - 1) / (KN - 1)
		KUU[k] = uu
		KWO[k] = width
		KAO[k] = clamp((taper and taperAt(uu, head, tail) or 1) * mul, 0, 1)
		KHO[k] = heat
		if face then
			KNN[k], KWD[k] = nil, nil
		else
			-- the width runs radially in the ring's plane; the outward radial is +SecondaryAxis (the strip's +v edge)
			KNN[k], KWD[k] = nil, (ux * cos(a) + vx * sin(a)) * flip
		end
	end
	if taper then endFix(KAO, head, tail) end
	local nb = emitZ(self, face, false, L)
	countP(self, nb > 0 and 1 or 0, opt(o, "tag", nil))
	return nb
end

-- PathRibbon scratch: the history reversed (head = newest), its widths
local PR, PW, PWC = {}, {}, {}

local function pathWidths(widths, n, out)
	for i = 1, n do
		local s = (n > 1) and (i - 1) / (n - 1) or 0               -- 0 head .. 1 tail
		local w
		if type(widths) == "table" then
			if #widths == n and n ~= 2 then
				w = widths[n + 1 - i] or 0                          -- per history point (oldest first)
			else
				w = lerp(widths[1] or 0, widths[2] or widths[1] or 0, s)
			end
		else
			w = widths or 0
		end
		out[i] = w * sin(pi * clamp(0.02 + 0.96 * s, 0, 1)) ^ 0.35   -- za.path_ribbon's profile
	end
	for i = #out, n + 1, -1 do out[i] = nil end
	return out
end

--- za.path_ribbon: a ribbon along a moving source's own recent path. history = ZD.trail_fn(...) (oldest first)
function Canvas:PathRibbon(history, widths, kind, o)
	local n = #history
	if n < 2 then return 0 end
	for i = 1, n do PR[i] = history[n + 1 - i] end
	for i = #PR, n + 1, -1 do PR[i] = nil end
	pathWidths(widths, n, PW)
	if kind == "coreglow" then
		pathWidths(opt(o, "core_w", nil) or widths, n, PWC)
		for i = 1, n do PWC[i] = PWC[i] * ((opt(o, "core_w", nil) == nil) and 0.25 or 1) end
		return ribbonCore(self, PR, PW, kindOf("glow"), kindOf("core"), PWC, o, opt(o, "core", nil))
	end
	local K = kindOf(kind)
	local Ki = innerOf(K, o)
	return ribbonCore(self, PR, PW, K, Ki, nil, o, opt(o, "core", nil))
end

-- Sheet scratch (one band at a time)
local BP, BW, BWD, BFA = {}, {}, {}, {}

local function gridAt(P, nv, alongV, a, b)
	if alongV then return P[(b - 1) * nv + a] end
	return P[(a - 1) * nv + b]
end

-- the Sheet being drawn (module scratch: one sheet at a time, no closures per call)
local SH = { P = nil, nu = 0, nv = 0, alongV = false, nr = 0, closedRows = false, closed = false, fa = nil, faNum = nil }

local function shRow(b)
	if SH.closedRows then return (b - 1) % SH.nr + 1 end
	return clamp(b, 1, SH.nr)
end

--- the point at band position a on the (fractional) row r
local function shPt(a, r)
	local r0 = floor(r)
	local f = r - r0
	local p0 = gridAt(SH.P, SH.nv, SH.alongV, a, shRow(r0))
	if f < 1e-6 then return p0 end
	return p0:Lerp(gridAt(SH.P, SH.nv, SH.alongV, a, shRow(r0 + 1)), f)
end

--- the per-vertex fade there (o.fa: a flat nu * nv array or a number)
local function shFa(a, r)
	if SH.faNum then return SH.faNum end
	local fa = SH.fa
	if type(fa) ~= "table" then return 1 end
	local r0 = floor(r)
	local f = r - r0
	local b0, b1 = shRow(r0), shRow(r0 + 1)
	local nv = SH.nv
	local i0 = SH.alongV and ((b0 - 1) * nv + a) or ((a - 1) * nv + b0)
	local i1 = SH.alongV and ((b1 - 1) * nv + a) or ((a - 1) * nv + b1)
	return lerp(fa[i0] or 1, fa[i1] or 1, f)
end

--- za5.Sheet's ch at a (fractional, 1-based) v position: open 0..1; closed 0.5 - 0.5 sin(2 pi j / nv)
local function shCh(x)
	if SH.closed then return 0.5 - 0.5 * sin(TAU * (x - 1) / SH.nv) end
	return (x - 1) / max(1, SH.nv - 1)
end

--- za5.Sheet / Shell as bands between neighbouring rows (see the header)
function Canvas:Sheet(P, nu, nv, kind, o)
	local K = kindOf(kind or "surf")
	local fade = opt(o, "fade", 1)
	if fade <= 0 or nu < 2 or nv < 2 or #P < nu * nv then return 0 end
	local closed = opt(o, "closed", false)
	local alongV = opt(o, "along", "u") == "v"
	local na = alongV and nv or nu                                 -- points along a band
	local nr = alongV and nu or nv                                 -- rows across the bands
	local closedRows = closed and not alongV                       -- the rows wrap (bands along u round a tube)
	local closedBand = closed and alongV                           -- each band is a closed loop
	local natural = closedRows and nr or (nr - 1)
	local nb = clamp(opt(o, "bands", natural), 1, natural)
	local fa = opt(o, "fa", nil)
	local al = opt(o, "alpha", 0.5)
	if type(al) ~= "number" then al = 0.5 end
	local mul = fade * (al / 0.5) * opt(o, "a0", K.A0)
	if mul <= AEPS then return 0 end
	local heatAdd = opt(o, "heat", 0)
	local maxSpans = opt(o, "maxSpans", Config.MaxSpans)
	local overlap = Config.SheetOverlap
	local prof = K.Sheet
	strandFrom(STRAND_O, K, o, nil, self.T)
	SH.P, SH.nu, SH.nv, SH.alongV, SH.nr, SH.closedRows, SH.closed = P, nu, nv, alongV, nr, closedRows, closed
	SH.fa, SH.faNum = fa, (type(fa) == "number") and fa or nil

	local total = 0
	for band = 1, nb do
		local r0 = 1 + (band - 1) * natural / nb
		local r1 = 1 + band * natural / nb
		local prevD = nil
		for a = 1, na do
			local p0, p1 = shPt(a, r0), shPt(a, r1)
			BP[a] = (p0 + p1) * 0.5
			local d = p1 - p0
			local dm = d.Magnitude
			BW[a] = dm * overlap
			if dm > 1e-6 then
				prevD = d / dm
				BWD[a] = prevD
			else
				BWD[a] = prevD or UP
			end
			BFA[a] = (shFa(a, r0) + shFa(a, r1)) * 0.5
		end
		for a = #BP, na + 1, -1 do BP[a] = nil end
		local L = zChain(BP, na, closedBand, maxSpans, true)
		if KN >= 2 then
			local rm = (r0 + r1) * 0.5
			for k = 1, KN do
				local ix = KIX[k]
				local src = (ix > na) and 1 or ix
				local sa, ch
				if alongV then
					sa = (rm - 1) / max(1, nu - 1)
					ch = shCh(src)
				else
					sa = (src - 1) / max(1, nu - 1)
					ch = shCh(rm)
				end
				local wd = BWD[src]
				local nrm = KT[k]:Cross(wd)
				local nm = nrm.Magnitude
				nrm = (nm > 1e-6) and nrm / nm or UP
				local aP, heat = 1, 0
				if prof == "surf" then
					local view = (KP[k] - camPos)
					local vm = view.Magnitude
					local facing = (vm > 1e-6) and (1 - abs(nrm:Dot(view / vm))) ^ 0.7 or 0
					local lt = 0.5 + 0.5 * abs(nrm:Dot(sunDir))
					aP = (1 - sst(ch, 0.62, 1.0)) * (1 - sst(sa, 0.86, 1.02)) * (0.5 + 0.6 * facing)
					heat = 0.55 * (1 - ch) + 0.30 * lt + 0.10 * (1 - sa)
				elseif prof == "shell" then
					local view = (KP[k] - camPos)
					local vm = view.Magnitude
					local facing = (vm > 1e-6) and (1 - abs(nrm:Dot(view / vm))) ^ 0.6 or 0
					local lt = 0.5 + 0.5 * abs(nrm:Dot(sunDir))
					aP = sst(sa, 0, 0.08) * (1 - sst(sa, 0.86, 1.0)) * (0.35 + 0.9 * facing)
					heat = 0.18 + 0.45 * sa + 0.25 * lt
				else
					heat = K.HeatC + K.HeatU * (1 - sa)
				end
				KUU[k] = alongV and ch or sa
				KWO[k] = BW[src]
				KAO[k] = clamp(aP * BFA[src] * mul, 0, 1)
				KHO[k] = heat + heatAdd
				KNN[k], KWD[k] = nil, wd
			end
			total += emitZ(self, false, false, L)
		end
	end
	countP(self, total > 0 and 1 or 0, opt(o, "tag", nil))
	return total
end

--- ONE deterministic textured sprite (a camera-facing -- or flat, o.n -- square Beam): the cyclone's white core blob,
--- the bird's eyes, a soft glow behind a hit. size = half the width (studs). o: tex (a Config.Textures name: "Puff"
--- default, "Dot", "Spark", "Dust", "Glare" ...), opacity (0..1, a PLAIN multiplier here), fade, heat (0.85: the colour
--- off the kit's ramp), color (Color3 instead), glow, e0 (1.0), e1 (1.6), le (LightEmission, 0.7), rot (rad), n, z.
--- Returns 1 if drawn.
function Canvas:Sprite(p, size, o)
	if size <= 1e-4 then return 0 end
	local op = clamp(opt(o, "fade", 1) * opt(o, "opacity", 1), 0, 1)
	if op <= AEPS then return 0 end
	local n = opt(o, "n", nil)
	local rot = opt(o, "rot", 0)
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
	local heat = opt(o, "heat", 0.85)
	local col = opt(o, "color", nil)
	local ck, cseq
	if col then ck, cseq = fixedSeq(col, nil) else ck, cseq = heatSeq(heat, heat) end
	local h = clamp(heat, 0, 1)
	local br = 1 + Config.BrightScale * opt(o, "glow", 1) * (opt(o, "e0", 1.0) + opt(o, "e1", 1.6) * h * h)
	br = floor(min(Config.MaxBrightness, br) * 64 + 0.5) / 64
	local tk, ts = transSeq(op, op)
	local s = takeSprite(self)
	local y = (n == nil) and orientY(d, nil, nil, true) or orientY(d, nn, nil, false)
	place0(s, p - d * size, d, y)
	place1(s, p + d * size, d, y)
	beamWrite(s.B, s.ST, ck, cseq, br, opt(o, "le", 0.7), tk, ts, n == nil, 2 * size, 2 * size, 0, 0, 1,
		Config.Kinds.glow.Z + opt(o, "z", 0), TEX(opt(o, "tex", "Puff")), nil)
	self.Beams += 1
	return 1
end

--- za.Arcs.draw: many pointed thick-to-thin arcs orbiting c on varied planes, each its own radius, span, angular
--- speed, width, glow and phase (deterministic per seed: the hash, not numpy's generator)
local ARC_PTS = {}
local ARC_W = {}
local ARC_O = { fade = 1, glow = 1, alpha = 0.5, tail = 0.55, maxSpans = 4, t = 0 }
function Canvas:Arcs(t, c, axis, o)
	local n = opt(o, "n", 14)
	local seed = opt(o, "seed", 1)
	local rr, spn, ww, spd = opt(o, "r", nil), opt(o, "span", nil), opt(o, "w", nil), opt(o, "speed", nil)
	local rA, rB = rr and rr[1] or 1.2, rr and rr[2] or 3.0
	local sA, sB = spn and spn[1] or 50, spn and spn[2] or 140
	local wA, wB = ww and ww[1] or 0.05, ww and ww[2] or 0.22
	local vA, vB = spd and spd[1] or 3.0, spd and spd[2] or 9.0
	local tilt = opt(o, "tilt", 0.55)
	local npts = opt(o, "npts", 18)
	local fade = opt(o, "fade", 1)
	local spin = opt(o, "spin", 1)
	local scale = opt(o, "scale", 1)
	local smul = opt(o, "speed_mul", 1)
	local glow = opt(o, "glow", 1)
	if fade <= 0.003 then return 0 end
	local ax = axis.Unit
	local b0 = perp_any(ax)
	local b1 = ax:Cross(b0)
	local R = ZephyrDraw.Rand
	local nbeams = 0
	ARC_O.maxSpans = opt(o, "maxSpans", 4)
	ARC_O.tag = opt(o, "tag", nil)
	ARC_O.t = t
	for i = 1, n do
		local r = (rA + (rB - rA) * R(seed, i, 1)) * scale
		local sp = math.rad(sA + (sB - sA) * R(seed, i, 2))
		local wk = R(seed, i, 3) < 1 / 3 and 1.7 or 1.0               -- rs.choice([1, 1, 1.7])
		local w = (wA + (wB - wA) * R(seed, i, 4)) * wk * scale
		local v = vA + (vB - vA) * R(seed, i, 5)
		local ph = R(seed, i, 6) * TAU
		-- rs.normal(0, tilt) via Box-Muller on two hashes
		local g1 = sqrt(-2 * math.log(max(1e-9, R(seed, i, 7)))) * cos(TAU * R(seed, i, 8)) * tilt
		local g2 = sqrt(-2 * math.log(max(1e-9, R(seed, i, 9)))) * cos(TAU * R(seed, i, 10)) * tilt
		local gl = 0.7 + 0.8 * R(seed, i, 11)
		local alpha = 0.35 + 0.45 * R(seed, i, 12)
		local flick = R(seed, i, 13) * TAU
		local rise = -0.25 + 0.5 * R(seed, i, 14)
		local nv = (ax + b0 * g1 + b1 * g2).Unit
		local d0 = perp_any(nv)
		local d1 = nv:Cross(d0)
		local a0 = ph + spin * v * smul * t
		for k = 1, npts do
			local s = (k - 1) / (npts - 1)
			local ang = a0 - spin * sp * s                             -- the head leads, the tail trails
			ARC_PTS[k] = c + (d0 * cos(ang) + d1 * sin(ang)) * r + nv * (s * rise * r)
			ARC_W[k] = w * sin(pi * clamp(s * 0.92 + 0.04, 0, 1)) ^ 0.7 * (1 - 0.65 * s)
		end
		for k = #ARC_PTS, npts + 1, -1 do
			ARC_PTS[k] = nil
			ARC_W[k] = nil
		end
		local fl = 0.75 + 0.25 * sin(t * 9.0 + flick)
		ARC_O.fade, ARC_O.glow, ARC_O.alpha = fade * fl, gl * glow, alpha
		nbeams += ribbonCore(self, ARC_PTS, ARC_W, kindOf("arc"), nil, nil, ARC_O, nil)
	end
	return nbeams
end
end

----------------------------------------------------------------------------------------------------
-- LIGHTS (za5.aqua_light / light_set, and RadiantDraw's LightPool)
----------------------------------------------------------------------------------------------------
-- (2026-10-19, audit P5E-14) a block, like the strokes' below: lightWrite and the calm cache stay out of the module top
-- level. The strokes' block held exactly 200 declared locals; now 177 top-level + 20 = 197 (the module's peak is 198, in
-- the block above). luau-compile, which folds constant locals, found 6 spare registers there before and 9 now.
-- calmNow alone stays top-level (the Light pieces further down read it), declared here and filled in inside the block.
local calmNow
do
local function lightWrite(s, p, b, range, col)
	if s.p ~= p then s.p = p; s.Att.Position = p end
	if s.b ~= b then s.b = b; s.L.Brightness = b end
	if s.r ~= range then s.r = range; s.L.Range = range end
	if s.c ~= col then s.c = col; s.L.Color = col end
	if not s.on then s.on = true; s.L.Enabled = true end
end

--- RadiantDraw's LightPool (level-based), the aqua light colour
function Canvas:LightPool(p, level, o)
	local lvl = max(0, level or 1)
	if lvl <= 1e-3 then return nil end
	local energy, col, range = opt(o, "energy", nil), opt(o, "color", C.Light3), opt(o, "range", Config.LightPoolRange)
	local s = takeLight(self)
	lightWrite(s, p, Config.LightBrightness * lvl * ((energy or Config.LightW) / Config.LightW), range, col)
	countL(self, 1, opt(o, "tag", nil))
	return s.L
end

--- za5.aqua_light + light_set: a soft aqua PointLight of `watts` (the kit's energy) with the two-sine flicker
local CALM_T, CALM_V = -1, false
calmNow = function()
	local now = os.clock()
	if now - CALM_T > 0.5 then                                      -- the setting read at most twice a second
		CALM_T, CALM_V = now, calm()
	end
	return CALM_V
end

function Canvas:Light(p, watts, o)
	local w = watts or 0
	if w <= 1 then return nil end
	local quiet = calmNow()
	local f = quiet and 0 or opt(o, "flicker", Config.LightFlicker)
	local hz = opt(o, "hz", Config.LightHz)
	local tt = opt(o, "t", self.T)
	local fl = 1 - f + f * sin(tt * hz) * sin(tt * hz * 0.61 + 1.3)
	local b = min(Config.LightMax, w / Config.LightWatts) * fl * Config.LightScale * (quiet and Config.CalmLight or 1)
	b = floor(b * 256 + 0.5) / 256
	local s = takeLight(self)
	lightWrite(s, p, b, opt(o, "range", Config.LightRange), opt(o, "color", C.Light3))
	countL(self, 1, opt(o, "tag", nil))
	return s.L
end
end

----------------------------------------------------------------------------------------------------
-- RADIANTDRAW'S STROKES (the level-based API, recoloured: the Zephyr core strand + the glow sleeve)
----------------------------------------------------------------------------------------------------
do -- (a block: its locals stay out of the module top level, which Luau caps at 200 registers)
function Canvas:Line(pts, level, w, n, bezel, prof, smoothC)
	level = level or 0.5
	kPoints(pts, smoothC, 1e-5, false)
	if KN < 2 then return false end
	if prof then
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
	if face then nn = nil end
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
		local ds = 1 / max(1, 4 * turns)
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
			local k = (dth > 1e-4) and (4 * tan(dth / 4) / dth) or 1
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
-- STARS, GLINTS, MOTES (RadiantDraw's: the spark star in a soft aqua halo, motes as dots)
----------------------------------------------------------------------------------------------------
local function spikeHalf(L, rIn, m)
	local xi, yi = rIn * cos(pi / m), rIn * sin(pi / m)
	if L <= xi + 1e-6 then return yi end
	return yi / (1 - xi / L)
end

--- the kit's _star: m spikes (even j long, odd j short), the core strand + the glow star behind (sleeveMul longer)
local function starCore(cv, c, m, Llong, Lshort, rIn, level, rot, n, ref, sleeveMul)
	local nrm = n and n.Unit or camDir(c)
	local ux, vx = basis(nrm, ref or camUp)
	for pass = 1, 2 do
		local glow = (pass == 1)
		if not glow or (sleeveMul and sleeveMul > 0) then
			for j = 0, m - 1 do
				local a = rot + j * TAU / m
				local e = ux * cos(a) + vx * sin(a)
				local L, ri = ((j % 2 == 0) and Llong or Lshort), rIn
				if glow then L, ri = L * sleeveMul + 0.012, rIn * 1.9 + 0.01 end
				KN = 0
				kpush(c, e, 0, 0, 1)
				kpush(c + e * L, e, 0, 0, 0)
				emitChain(cv, level, 2 * spikeHalf(L, ri, m), n and nrm or nil, nil, false,
					glow and LOOK_GOLD or LOOK_CORE, glow and Config.Kinds.glow.Z or Config.Kinds.core.Z)
			end
		end
	end
end

local function glintCore(cv, p, size, level, rot, n, short, tag)
	if size <= 1e-3 then return end
	local k = Config.GlintScale
	if Config.GlintHalo then
		emitSprite(cv, p, (size * Config.GlintHaloScale + 0.012) * k, LOOK_GOLD, level, rot, n, TEX("Puff"),
			Config.Kinds.glow.Z)
	end
	emitSprite(cv, p, size * k * ((short and short > 0) and 1.1 or 1), LOOK_CORE, level, rot, n, TEX("Spark"),
		Config.Kinds.core.Z)
	countG(cv, 1, tag)
end

function Canvas:Glint(p, size, level, rot, n, short, tag)
	glintCore(self, p, size or 0.12, level or 1, rot or 0, n, short or 0, tag)
end

--- one mote: a glow dot + a core dot, with a tapered trail behind it along -dir
local function moteCore(cv, p, s, level, dir, tl, nominal)
	local k = Config.MoteScale
	emitSprite(cv, p, s * k, LOOK_GOLD, level, 0, nil, TEX("Dot"), Config.Kinds.glow.Z)
	emitSprite(cv, p, s * 0.55 * k, LOOK_CORE, level, 0, nil, TEX("Dot"), Config.Kinds.core.Z)
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

local function cycleAt(t, i, life, t0, t1, seed)
	local ph = ZephyrDraw.Rand(seed, i, 0x51, 1) * life
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
-- HOLY RAYS, FLARE, LIGHTS
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
	local flatN = normal and nn or nil
	local vv = ramp(v, 0, 1)
	local sw = sleeve_w(level)
	local k = 0
	for j = 0, n - 1 do
		local dly = ZephyrDraw.Rand(seed, j, 1) * stagger
		local jit = (ZephyrDraw.Rand(seed, j, 2) * 2 - 1) * jitter
		local ph = ZephyrDraw.Rand(seed, j, 3)
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


----------------------------------------------------------------------------------------------------
-- MOTE FIELD, GATHER, ORNAMENTS, STAFF AURA (RadiantDraw's)
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
	kArc(c, ux, vx, rr + tt / 2, 0, TAU)
	emitChain(self, lv, 2 * hw, nil, ax, false, LOOK_GOLD, Config.Kinds.glow.Z)
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

--- RadiantDraw's staff_glow, recoloured: the parts' Color lerps shadow teal -> light. NEVER Neon (NOT NEON).
local staffQ = setmetatable({}, { __mode = "k" })
function ZephyrDraw.StaffGlow(parts, level)
	local q = floor(clamp(level, 0, 1) * LEVEL_Q + 0.5)
	local col = nil
	for _, part in ipairs(parts) do
		if staffQ[part] ~= q then
			staffQ[part] = q
			col = col or staff_look(q / LEVEL_Q)
			part.Material = (q / LEVEL_Q >= Config.StaffNeonFrom) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			part.Color = col
		end
	end
end
end

----------------------------------------------------------------------------------------------------
-- PARTICLES (za.burst / zk.Particles as pooled ParticleEmitters)
----------------------------------------------------------------------------------------------------
do -- (a block: its locals stay out of the module top level, which Luau caps at 200 registers)
local CFG = {}                                     -- the look being asked for (scratch)

local function particleCfg(P, o)
	local sz, lf = opt(o, "size", nil), opt(o, "life", nil)
	CFG.P = P
	CFG.sA, CFG.sB = sz and sz[1] or 0.6, sz and (sz[2] or sz[1]) or 1.4
	CFG.lA, CFG.lB = lf and lf[1] or 0.4, lf and (lf[2] or lf[1]) or 1.0
	CFG.grow = opt(o, "grow", 0)
	CFG.alpha = opt(o, "alpha", 1)
	CFG.drag = opt(o, "drag", P.Drag)
	CFG.accel = opt(o, "accel", nil) or Vector3.new(0, -Config.G * P.Grav, 0)
	CFG.stretch = opt(o, "stretch", 0)
	CFG.color = opt(o, "color", nil)
	return CFG
end

local function cfgSig(c)
	local col = c.color and string.format("%.3f,%.3f,%.3f", c.color.R, c.color.G, c.color.B) or "-"
	return string.format("%s|%.3f|%.3f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f,%.2f,%.2f|%.2f|%s", c.P.Tex, c.sA, c.sB, c.lA, c.lB,
		c.grow, c.alpha, c.drag, c.accel.X, c.accel.Y, c.accel.Z, c.stretch, col) .. "|" .. tostring(c.P)
end

local function configure(slot, c)
	local P = c.P
	local e = slot.E
	local base = P.Size * Config.ParticleSize
	local mid, envl = (c.sA + c.sB) * 0.5 * base, (c.sB - c.sA) * 0.5 * base
	local g = 1 + c.grow
	e.Texture = TEX(P.Tex)
	if c.color then
		e.Color = ColorSequence.new(c.color)
	else
		e.Color = ColorSequence.new(P.Color[1], P.Color[2])
	end
	e.LightEmission = P.LE
	e.LightInfluence = P.LI
	e.Brightness = (P.LI >= 1) and 1 or min(Config.MaxBrightness, 1 + Config.BrightScale * P.Emit)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, mid, envl), NumberSequenceKeypoint.new(1, mid * g, envl * g) })
	-- the kit's fade: in over 0.06 s, out over the last 35 % of the life (zk.Particles.draw), x the peak alpha
	local amax = clamp(P.Alpha * c.alpha, 0, 1)
	local lm = max(0.05, (c.lA + c.lB) * 0.5)
	local fin = clamp(0.06 / lm, 0.01, 0.3)
	local kps = {}
	if P.Twinkle then
		-- za spark: x max(0, 0.45 + 0.55 sin(23 t + phase)): a twinkle sampled into the sequence
		local N = 9
		for k = 0, N do
			local tau = k / N
			local fade = clamp(tau / fin, 0, 1) * clamp((1 - tau) / 0.35, 0, 1)
			local tw = max(0, 0.45 + 0.55 * sin(23 * tau * lm + 1.0))
			kps[#kps + 1] = NumberSequenceKeypoint.new(tau, 1 - amax * fade * (0.35 + 0.65 * tw))
		end
	else
		kps[1] = NumberSequenceKeypoint.new(0, 1)
		kps[2] = NumberSequenceKeypoint.new(fin, 1 - amax)
		kps[3] = NumberSequenceKeypoint.new(max(0.65, fin + 0.01), 1 - amax)
		kps[4] = NumberSequenceKeypoint.new(1, 1)
	end
	e.Transparency = NumberSequence.new(kps)
	e.Lifetime = NumberRange.new(c.lA, max(c.lA, c.lB))
	e.Drag = c.drag * Config.DragK
	e.Acceleration = c.accel
	local spin = math.deg(P.Spin)
	e.RotSpeed = NumberRange.new(-spin, spin)
	e.Rotation = NumberRange.new(0, 360)
	if c.stretch > 0 then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(Config.StretchSquash)
	else
		e.Orientation = Enum.ParticleOrientation.FacingCamera
		e.Squash = NumberSequence.new(0)
	end
	e.SpreadAngle = Vector2.new(Config.BurstJitter, Config.BurstJitter)
	e.EmissionDirection = Enum.NormalId.Top
	e.LockedToPart = false
	e.ZOffset = 0
	slot.life = max(c.lA, c.lB)
end

local function acquireEmitter(cv, sig, c)
	if #cv.eslots >= Config.MaxEmitters then
		if not cv.warnedE then
			cv.warnedE = true
			warn(string.format("[ZephyrDraw] %s: more than %d particle emitters", cv.Name, Config.MaxEmitters))
		end
		return nil
	end
	local now = os.clock()
	local pick, pickI = nil, nil
	for i = #freeEmit, 1, -1 do
		local s = freeEmit[i]
		if s.freeAt <= now then
			if s.sig == sig then
				pick, pickI = s, i
				break
			elseif not pick then
				pick, pickI = s, i
			end
		end
	end
	local s
	if pick then
		s = table.remove(freeEmit, pickI)
	else
		local at = newAtt("ZephyrEmit")
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Rate = 0
		e.Parent = at
		s = { Att = at, E = e, sig = nil, freeAt = 0, on = false, rate = -1, life = 1 }
	end
	if s.sig ~= sig then
		configure(s, c)
		s.sig = sig
	end
	-- a slot comes back as a burst emitter; a stream re-aims and re-rates it itself (its caches start clean)
	s.rate, s.spread, s.spA, s.spB, s.drawn = -1, nil, nil, nil, nil
	s.E.SpreadAngle = Vector2.new(Config.BurstJitter, Config.BurstJitter)
	s.on = false
	s.E.Enabled = false
	s.E.Rate = 0
	cv.eslots[#cv.eslots + 1] = s
	return s
end

local function densityCount(cv, n)
	if n <= 0 then return 0 end
	local d = cv.Density or 1
	local k = floor(n * d + 0.5)
	if k < 1 and d >= 0.3 then k = 1 end
	return min(k, Config.MaxBurst)
end

--- za.burst: n particles from pos, thrown radially (or into a cone round o.dir), + o.up on the direction's Y
function Canvas:Burst(kind, pos, n, o)
	local t0 = opt(o, "t0", nil)
	local id = opt(o, "id", nil)
	if id == nil then id = t0 end                                  -- a timed burst without an id is keyed by its t0
	if id ~= nil and self.fired[id] then return 0 end
	if t0 then
		if self.T < t0 then return 0 end
		if self.T - t0 > opt(o, "late", Config.BurstLate) then
			if id ~= nil then self.fired[id] = true end
			return 0
		end
	end
	if id ~= nil then self.fired[id] = true end
	local P = Config.Particles[kind] or Config.Particles.puff
	local k = densityCount(self, n or 0)
	if k <= 0 then return 0 end
	local c = particleCfg(P, o)
	local sig = cfgSig(c)
	local slot = self.esig[sig]
	if not slot then
		slot = acquireEmitter(self, sig, c)
		if not slot then return 0 end
		self.esig[sig] = slot
	end
	local sp = opt(o, "speed", nil)
	local spA, spB = sp and sp[1] or 6, sp and (sp[2] or sp[1]) or 16
	local dir = opt(o, "dir", nil)
	local dirU = (dir and dir.Magnitude > 1e-6) and dir.Unit or nil
	local cone = opt(o, "cone", 1)
	local up = opt(o, "up", 0.3)
	local seed = opt(o, "seed", nil)
	local rng = seed and Random.new(seed) or Random.new()
	local e, at = slot.E, slot.Att
	-- the particles keep the shot clock too (ShotTimeScale slow motion): a burst at 0.08 x lives 12x longer
	local ts = math.clamp(timeScale(), 0.01, 1)
	if e.TimeScale ~= ts then e.TimeScale = ts end
	for _ = 1, k do
		local d = rng:NextUnitVector()
		if dirU then
			d = dirU + d * cone
			local m = d.Magnitude
			d = (m > 1e-6) and d / m or dirU
		end
		d = d + UP * up
		local m = d.Magnitude
		local du = (m > 1e-6) and d / m or UP
		at.CFrame = CFrame.fromMatrix(pos + d * 0.2, perp_any(du), du)
		e.Speed = NumberRange.new(spA * m, spB * m)
		e:Emit(1)
	end
	slot.freeAt = max(slot.freeAt, os.clock() + slot.life / ts + 0.1)
	self.Particles += k
	return k
end

--- a continuous emitter at pos while drawn this frame (o as Burst; o.id names it)
function Canvas:Stream(kind, pos, rate, o)
	local key = opt(o, "id", nil) or kind
	local slot = self.estream[key]
	local P = Config.Particles[kind] or Config.Particles.puff
	if not slot then
		local c = particleCfg(P, o)
		slot = acquireEmitter(self, cfgSig(c), c)
		if not slot then return end
		self.estream[key] = slot
	end
	slot.drawn = self.frame
	local dir = opt(o, "dir", nil)
	local up = opt(o, "up", 0)
	local d = (dir and dir.Magnitude > 1e-6) and dir.Unit or UP
	if dir then d = d + UP * up end
	local du = (d.Magnitude > 1e-6) and d.Unit or UP
	slot.Att.CFrame = CFrame.fromMatrix(pos, perp_any(du), du)
	local spread = dir and math.deg(math.atan(opt(o, "cone", 1))) or 180
	if slot.spread ~= spread then
		slot.spread = spread
		slot.E.SpreadAngle = Vector2.new(spread, spread)
	end
	local sp = opt(o, "speed", nil)
	local spA, spB = sp and sp[1] or 6, sp and (sp[2] or sp[1]) or 16
	if slot.spA ~= spA or slot.spB ~= spB then
		slot.spA, slot.spB = spA, spB
		slot.E.Speed = NumberRange.new(spA, spB)
	end
	local r = (rate or 0) * (self.Density or 1)
	r = floor(r * 4 + 0.5) / 4
	if slot.rate ~= r then
		slot.rate = r
		slot.E.Rate = r
	end
	if r > 0 and not slot.on then
		slot.on = true
		slot.E.Enabled = true
	elseif r <= 0 and slot.on then
		slot.on = false
		slot.E.Enabled = false
	end
	slot.freeAt = os.clock() + slot.life + 0.1
end
end

----------------------------------------------------------------------------------------------------
-- THE DRIVER: one RenderStep for every live effect, bound only while one lives
----------------------------------------------------------------------------------------------------
do -- (a block: its locals stay out of the module top level, which Luau caps at 200 registers)
local STEP = "ZephyrDraw"
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
			local okc, t = pcall(e.Clock)
			if not okc or type(t) ~= "number" then
				warnOnce("clock:" .. e.Name, e.Name .. ": clock " .. tostring(t))
				keep = false
			elseif (e.Until and t > e.Until) or (os.clock() - e.Born > e.MaxLife) then
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
			local ok, err = pcall(finish, e)
			if not ok then warnOnce("fin:" .. e.Name, e.Name .. " finish: " .. tostring(err)) end
		end
	end
	if #live == 0 and bound then
		bound = false
		RunService:UnbindFromRenderStep(STEP)
	end
end

--- frameFn(cv, t, dt, handle) each render frame; return false to end. opts: T0 (server), Offset, Scale, Clock,
--- Until (clip s), MaxLife (s), Prewarm {Spans, Sprites, Lights, Emitters}, OnEnd(handle), Own, Budget, Freeze
function ZephyrDraw.Play(name, frameFn, opts)
	opts = opts or {}
	if not RunService:IsClient() then
		warnOnce("server", "Play called on the server: ZephyrDraw is client only (nothing drawn)")
		return setmetatable({ Name = name or "fx", Dead = true, Canvas = nil }, Effect)
	end
	local clock = opts.Clock or ZephyrDraw.Clock(opts.T0, opts.Offset, opts.Scale)
	local maxLife = opts.MaxLife or Config.MaxLife
	local untilT = opts.Until
	if opts.Freeze ~= nil then
		local f = opts.Freeze
		clock = function() return f end
		untilT = nil
		maxLife = math.huge
	end
	local e = setmetatable({
		Name = name or "fx", Fn = frameFn,
		Canvas = ZephyrDraw.new(name, opts.Prewarm, { Own = opts.Own, Budget = opts.Budget }),
		Clock = clock, Until = untilT, MaxLife = maxLife, Born = os.clock(), OnEnd = opts.OnEnd, Dead = false,
	}, Effect)
	live[#live + 1] = e
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP, Config.RenderPriority, driver)
	end
	return e
end

--- the test harness's player: ZD.Play, with opts.Freeze = clip seconds holding that one frame until handle:Stop()
function ZephyrDraw.Demo(name, frameFn, opts)
	opts = opts or {}
	return ZephyrDraw.Play(name, frameFn, opts)
end

function ZephyrDraw.StopAll()
	for _, e in ipairs(live) do e.Dead = true end
end
end

----------------------------------------------------------------------------------------------------
-- THE CAMERA KICK (own view): FOV / pitch / roll impulses on our own RenderStep, the shake on Viewmodel.Shake
----------------------------------------------------------------------------------------------------
do -- (a block: its locals stay out of the module top level, which Luau caps at 200 registers)
local KICK_STEP, KICK_BASE_STEP = "ZephyrDrawKick", "ZephyrDrawKickBase"
local kicks = {}
local kickBound = false
local kickState = { cam = nil, base = nil, applied = nil, fovBase = nil, fovWritten = nil }

local function viewmodel()
	if viewmodelLib == nil then
		viewmodelLib = false
		local parent = script and script.Parent
		local mod = parent and parent:FindFirstChild("Viewmodel")
		if mod then
			local ok, lib = pcall(require, mod)
			if ok and type(lib) == "table" then viewmodelLib = lib end
		end
	end
	return viewmodelLib or nil
end

local function kickValue(k, now)
	local age = now - k.T0
	if age < 0 then return 0, false end
	local a = 1
	if k.Rise > 0 and age < k.Rise then a = smooth(age / k.Rise) end
	local relAt = k.ReleasedAt and (k.ReleasedAt - k.T0) or (k.Rise + k.Hold)
	local holdEnd = min(k.Rise + k.Hold, relAt)
	if age > holdEnd then
		a *= exp(-(age - holdEnd) / k.Decay)
		if a < 1e-3 then return 0, true end
	end
	return a, false
end

-- before the camera script: take last frame's pitch / roll back out. Whatever a later step composed on top of the
-- kicked view (the slide roll, a look-scaling step: q = applied^-1 * now) is kept, only the kick goes; a view that
-- something SET since (a big jump: a move turning you to face a spot) is left alone.
local function kickRestore()
	local st = kickState
	if st.applied and st.cam and st.cam == workspace.CurrentCamera then
		local cf = st.cam.CFrame
		local q = st.applied:ToObjectSpace(cf)
		local _, ang = q:ToAxisAngle()
		if q.Position.Magnitude < 0.05 and abs(ang) < 0.3 then
			st.cam.CFrame = st.base * q
		end
	end
	st.applied, st.base = nil, nil
end

local function kickUnbind()
	if kickBound then
		kickBound = false
		pcall(RunService.UnbindFromRenderStep, RunService, KICK_STEP)
		pcall(RunService.UnbindFromRenderStep, RunService, KICK_BASE_STEP)
	end
end

local function kickStep()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local now = os.clock()
	local quiet = calmNow()
	local sk = shakeScale()
	local pitch, roll, fov = 0, 0, 0
	local i = 1
	while i <= #kicks do
		local k = kicks[i]
		local a, done = kickValue(k, now)
		if done or k.Dead then
			table.remove(kicks, i)
		else
			local osc = 1
			if k.Osc ~= 0 then osc = sin(k.Osc * (now - k.T0) + k.Phase) end
			pitch += k.Pitch * a * osc
			roll += k.Roll * a * osc
			fov += k.Fov * a
			i += 1
		end
	end
	if quiet then
		pitch, roll = 0, 0
		fov *= Config.Kick.CalmFov
	end
	pitch, roll, fov = pitch * sk, roll * sk, fov * sk
	local mp = Config.Kick.MaxPitch
	pitch, roll = clamp(pitch, -mp, mp), clamp(roll, -mp, mp)
	-- the lens: tan(FOV / 2) x (1 + fov); whatever else wrote FieldOfView since our last write is the new base
	local st = kickState
	local cur = cam.FieldOfView
	if st.fovWritten == nil or abs(cur - st.fovWritten) > 1e-3 then st.fovBase = cur end
	if abs(fov) > 1e-4 or st.fovWritten ~= nil then
		local base = st.fovBase or cur
		local f = base
		if abs(fov) > 1e-4 then
			f = 2 * math.deg(math.atan(tan(math.rad(base) * 0.5) * max(0.05, 1 + fov)))
			f = clamp(f, Config.Kick.MinFov, Config.Kick.MaxFov)
		end
		cam.FieldOfView = f
		st.fovWritten = (abs(fov) > 1e-4) and f or nil
	end
	-- the rotation: applied after the camera, taken back out before it next frame (kickRestore)
	if abs(pitch) > 1e-6 or abs(roll) > 1e-6 then
		local base = cam.CFrame
		local ap = base * CFrame.Angles(pitch, 0, roll)
		cam.CFrame = ap
		st.cam, st.base, st.applied = cam, base, ap
	end
	if #kicks == 0 then
		if st.fovWritten ~= nil and st.fovBase then cam.FieldOfView = st.fovBase end
		st.fovWritten = nil
		if not st.applied then kickUnbind() end
	end
end

local function kickBind()
	if kickBound then return end
	kickBound = true
	-- bound fresh every time a kick starts, so it runs after SettingsRuntime's look step and the slide roll, which
	-- share Camera + 1 and were bound at startup
	RunService:BindToRenderStep(KICK_BASE_STEP, Enum.RenderPriority.Camera.Value - 2, function()
		local ok, err = pcall(kickRestore)
		if not ok then warnOnce("kickbase", "kick restore: " .. tostring(err)) end
		if #kicks == 0 and not kickState.applied and kickState.fovWritten == nil then kickUnbind() end
	end)
	RunService:BindToRenderStep(KICK_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local ok, err = pcall(kickStep)
		if not ok then
			warnOnce("kick", "camera kick: " .. tostring(err))
			table.clear(kicks)
		end
	end)
end

local KickHandle = {}
KickHandle.__index = KickHandle
function KickHandle:Release()
	if not self.K.ReleasedAt then self.K.ReleasedAt = os.clock() end
end
function KickHandle:Stop()
	self.K.Dead = true
end

--- OWN VIEW ONLY: an impulse on the local camera (see the header). Returns {Release(), Stop()}.
function ZephyrDraw.CameraKick(o)
	o = o or {}
	local k = {
		T0 = os.clock(), Fov = o.fov or 0, Pitch = o.pitch or 0, Roll = o.roll or 0, Osc = o.osc or 0,
		Phase = o.phase or 0, Rise = max(0, o.rise or 0), Hold = max(0, o.hold or 0),
		Decay = max(1e-3, o.decay or Config.Kick.DefaultDecay), ReleasedAt = nil, Dead = false,
	}
	local h = setmetatable({ K = k }, KickHandle)
	if not RunService:IsClient() then return h end
	if (o.shake or 0) > 0 then
		local vm = viewmodel()
		if vm and type(vm.Shake) == "function" then
			pcall(vm.Shake, o.shake, o.shakeDecay or o.decay or Config.Kick.DefaultDecay)
		end
	end
	if k.Fov ~= 0 or k.Pitch ~= 0 or k.Roll ~= 0 then
		kicks[#kicks + 1] = k
		kickBind()
	end
	return h
end
end

----------------------------------------------------------------------------------------------------
-- THE SCREEN GLARE (own view): a white-aqua radial edge vignette, immediate mode (this frame's level)
----------------------------------------------------------------------------------------------------
do -- (a block: its locals stay out of the module top level, which Luau caps at 200 registers)
local GLARE_STEP = "ZephyrDrawGlare"
local glare = { Gui = nil, Img = nil, pending = 0, flick = 0, hz = 19, col = nil, bound = false, idle = 0, shown = -1 }

local function glareEnsure()
	if glare.Img and glare.Img.Parent and glare.Gui and glare.Gui.Parent then return true end
	local p = Players.LocalPlayer
	local pg = p and p:FindFirstChildOfClass("PlayerGui")
	if not pg then return false end
	local g = Instance.new("ScreenGui")
	g.Name = "ZephyrGlare"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = Config.Glare.DisplayOrder
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local img = Instance.new("ImageLabel")
	img.Name = "Glare"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX("Glare")
	img.ImageColor3 = Config.Glare.Color
	img.ImageTransparency = 1
	img.ScaleType = Enum.ScaleType.Stretch
	img.Visible = false
	img.Parent = g
	g.Parent = pg
	glare.Gui, glare.Img, glare.shown = g, img, -1
	return true
end

local function glareStep()
	local lv = glare.pending
	glare.pending = 0
	local img = glare.Img
	if not img then return end
	if lv > 0 then
		glare.idle = 0
		local quiet = calmNow()
		local f = quiet and 0 or glare.flick
		if f > 0 then lv *= 1 - f + f * sin(os.clock() * glare.hz) end
		if quiet then lv *= Config.Glare.Calm end
		local tr = 1 - clamp(Config.Glare.Max * lv, 0, 1)
		tr = floor(tr * 200 + 0.5) / 200
		if glare.shown ~= tr then
			glare.shown = tr
			img.ImageTransparency = tr
		end
		local want = glare.col or Config.Glare.Color
		if img.ImageColor3 ~= want then img.ImageColor3 = want end
		if not img.Visible then img.Visible = true end
	else
		if img.Visible then img.Visible = false end
		glare.shown = -1
		glare.idle += 1
		if glare.idle > 30 and glare.bound then
			glare.bound = false
			RunService:UnbindFromRenderStep(GLARE_STEP)
		end
	end
	glare.flick, glare.col = 0, nil
end

--- OWN VIEW: the edge glare at `level` (0..1) for THIS frame; o.flicker (depth) / o.hz (19), o.color
function ZephyrDraw.ScreenGlare(level, o)
	if not RunService:IsClient() then return end
	level = clamp(level or 0, 0, 1)
	if level <= 0.002 then return end
	if not glareEnsure() then return end
	if level > glare.pending then glare.pending = level end
	local f = o and o.flicker or 0
	if f > glare.flick then glare.flick = f end
	glare.hz = (o and o.hz) or Config.Glare.Hz
	glare.col = o and o.color or nil
	if not glare.bound then
		glare.bound = true
		glare.idle = 0
		RunService:BindToRenderStep(GLARE_STEP, Enum.RenderPriority.Last.Value, function()
			local ok, err = pcall(glareStep)
			if not ok then warnOnce("glare", "screen glare: " .. tostring(err)) end
		end)
	end
end
end

return ZephyrDraw
