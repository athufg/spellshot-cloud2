--[[
	PyroDraw  (ReplicatedStorage.IceMagic.PyroDraw, ModuleScript, CLIENT)          Pyro Phase 3, 2026-10-05

	The Roblox side of Pyro's V1 "Layered blaze+" kit (vmarm/pyro/vis2026/kit/pyro_kit.py): flames only, opaque Neon
	MeshParts, PointLights, embers. The Blender kit grows every flame per frame; here every effect is COMPOSED BY
	INSTANCING a library of 45 small rigid flame meshes (ReplicatedStorage.FireMagicMeshes.Flame, "PF_<Family>_<phase>"):

	    Flame2 x4   a standing flame, core + shell          Ball x4     the Fireball's head (core + 2 shells, skirt)
	    Flame3 x4   the same with the light core            Tail x4     the streaming tail (length 1, radius 0.92)
	    Spire x4    a tall slender flame with an S-curve    Bulb x3     the burst's body (2 shells, torn crown)
	    Lick x3     a curling tongue (wisps, licks)         Column x3   one tier of a column of fire (radius 1)
	    Core x3     the light core alone                    Hoop x2     a closed ring of flame (radius 1)
	    RowA x4, RowB x4   an arc piece of a line of fire (4 flames + bed, 6 studs)
	    Strip x1    the burning line on the ground          Link x2     one link of the whip's rope

	Every flame family is 1 tall and 1 wide at the belly: Size = the height and width you want. A flame taller than
	Config.Slender x its width is drawn with the Spire (shaped for those proportions), whatever kind was asked.

	ONE MESH = ALL ITS NESTED LAYERS (the core's faces outward, the shells inverted hulls; DoubleSided must stay off),
	its ramp baked into the vertex colours, so a flame is ONE part. The FLICKER is the mesh's 3-4 loop phases swapped
	at Config.FPS (12.5 / s, each instance on its own offset); the FLOW is instances scrolled along paths (tiers
	rising up a column, lobes sliding down a tail) and each instance's own breathing / lean / sway every frame.
	Part.Color is a free multiplier on the baked ramp: Config.Tint.Normal (the approved ramp), white = HOT, darker =
	cooled (the kit's cool= / hshift).

	THE RENDERER (immediate mode, pooled; the structure of RadiantDraw). A canvas per effect instance:
	    cv:Begin(t) ... draw calls ... cv:End()
	A flame is identified by its place in its family's draw order (keep the order stable from frame to frame) and
	holds ONE part at a time: when its phase swaps it gives that part back to the mesh's shared pool and takes one of
	the next mesh (one Size write per swap; its 2.5 Hz breathing is stepped with the swaps, so there is none in
	between). End() moves every drawn part with ONE workspace:BulkMoveTo, hides (LocalTransparencyModifier 1) the
	parts nobody took again and switches off unused lights and emitters. Nothing is created per frame after warm-up
	(PyroDraw.Prewarm, or the first loop), Size / Color / visibility are written only when they change, nothing is
	destroyed until the pool is over Config.PoolKeep. Parts live in workspace.<FX folder>.PyroDraw, so every raycast
	that excludes the FX folder excludes them. Everything is a function of the t you pass: give every client the same
	clock (PyroDraw.Clock(T0) = server time) and they draw the same phases.

	CAPS AND THINNING. A canvas never shows more than cv.MaxParts parts (Config.MaxParts 260 x its density, density
	capped at 1) - what is drawn LAST in a frame is dropped first (cv.Dropped; one warning), so draw what matters
	first - nor more than Config.MaxLights lights / Config.MaxEmitters emitters. Density = SpellshotSettings.
	EffectDensity (0.45 / 0.75 / 1 / 1.15), x Config.EnemyThin when Settings.ThinEnemyVFX and the canvas is not `own`
	(PD.new(name, {own = true}) for the local player's effects): the builders thin wisps, licks, side tongues, tall
	tongues, streamers, wildfire spacing, column tiers, embers and lights by it. cv.Density is there for your own
	pieces. Measured headless (harness/life_test.luau): fire_line + big_blast at radius 17.5 peak at 123 parts
	(density 1), 108 (0.75), 83 (0.45); the Ring r2 piece replayed flame for flame peaks at 245.

	COORDINATES. Roblox world Vector3s. The kit is Blender (+Z up): Roblox (x, y, z) = Blender (-x, z, y) ->
	PyroDraw.B(x, y, z). Kit keyword arguments become ONE options table with the kit's names.

	API   (PD = require(IceMagic.PyroDraw); cv = a canvas; t = seconds; o = options, all optional)
	  PD.new(name, o{own, hot, maxParts, density}) -> cv      cv:Begin(t) / cv:End() -> parts / cv:Clear() / cv:Destroy()
	  cv:SetHot(on)                        the kit's set_hot: the default of every builder's hot=
	  PD.Play(name, frameFn(cv, t, dt, handle), o{T0, Offset, Scale, Clock, Until, MaxLife, OnEnd, own, hot}) -> handle{Canvas, Stop()}
	  PD.Clock(t0Server?, offset?, scale?) -> fn()   PD.ServerNow()   PD.TimeScale()   PD.Density(own) -> number
	  PD.Prewarm(n | {Family = n})   PD.SetMeshFolder(inst)   PD.SetFolder(inst | fn)   PD.StopAll()   PD.Stats()
	  PD.Ready() -> ok, {names missing / wrong size}, count      the WHOLE library is in the mesh folder (the look switch's gate)
	  PD.Rand(a, b, c, k) -> 0..1   PD.flick(t, ph)   PD.sst / eback / equint / clamp   PD.B(x, y, z)   PD.UP
	 the kit's builders (same argument meanings)
	  cv:fire_ball(pos | fn(t), t, o{hot, scale=1, span=0.135, t_min, rise=9, tail=1, streamers, light=true, seed})
	        -> centre, forward, tail length.   Ball + Tail + 3 streamers (HOT 5): 5 parts (HOT 7), 2 lights
	  cv:fire_tail(pos | fn(t), t, o{width=1, hot, span=0.2, t_min, rise=9, seed, light=false, segs})
	        -> head, forward, length.   Tail lobes along the path it took (segs: 1 straight .. 4 for a swing) + a Core
	  cv:wisps(fn(t), t, t0, t1, o{rate=50, life=0.4, hot, scale=1, seed=12, kd=6, buoy=16, out=0.85, cool=0.3}) -> alive
	  cv:standing_flame(pos, height, t, o{seed, ph, lean, width, hot, layers=2|3|"ball"|"cool", grow=1, side, flat=0.62,
	        cool=0, up}) -> tip.   ONE flame, 1 part (call it per flame)
	  cv:fire_line(pts, t, o{height=3.5, grow=1, seed=7, hot, lean, wind=1, strip=1.3, closed, vary=1, tall=1})
	        pts about 1.5 studs apart; height / grow / lean / tall = a value, an array per point or fn(i). One Row per 4
	        points + its Strip + the odd tall tongue: a 73-point Ring = 18 + 18 + about 9 parts
	  cv:ground_strip(pts, o{width=1.3, hot, grow=1, closed, step=4})
	  cv:hand_flame(pos | fn(t), t, o{size=1, hot, seed=13, tongues=5, lag=0.014, light=true, vel}) -> base.  1 + tongues parts
	  cv:burst(center, u, o{size=3, t, hot, seed=700, back=UP, flash=true, light=true, sparks}) -> alive
	        u 0..1.85 (keep calling). Bulb + Core + 11 licks (HOT 14) + up to 14 wisps (HOT 20): <= 27 parts (HOT 36)
	  cv:pillar(base, tp, t, o{height=36, radius=8, hot, seed=60, torn=11, foot=22, rise=0.3, light=true})   about 25 parts
	  cv:wildfire(center, radius, tp, t, o{hot, seed=90, spread=0.45, height=7, spacing=4, inner=0, hold, fade=0.4,
	        entrain=0.22, lights=5, strip=true}) -> front radius, flames lit
	  cv:big_blast(center, tp, t, o{ring_radius=17.5, height=36, hot, seed=60, pillar_share=0.46, fill=0.92, spread=0.45,
	        hold, embers=true}) -> front, lit           pillar + wildfire + embers: about 65 parts at 17.5
	  cv:embers(source | fn(t), t, o{id, count=45, life={0.22,0.6}, out={2,10}, up={1,7}, spread=0.5, g=36, kd=4.5,
	        size={0.06,0.15}, hot})               one ParticleEmitter, on while you call it
	  cv:ember_burst(center, tau, o{id, count=72, speed={9,33}, bias, hemi, g=38, kd=3.2, life={0.35,0.85}, size, hot})
	  cv:ember_gather(pos | fn(t), t, t0, t1, o{id, rate=75, radius=2, life=0.22, size=0.09, hot})
	  cv:ember_field(center, radius, t, o{id, inner=0..1, count=60, life={0.5,1}, up={5,14}, g=-5, kd=2.2, size, normal})
	        NOT the kit's (pts): a disc / an annulus of rising embers (the Ring's line: inner = 0.92)
	  cv:pillar_embers(base, tp, o{id, count=110, height=36, radius=8})
	  cv:fire_light(p, watts, o{t, ph, range}) / cv:ground_glow(p, radius=6, level=1, t, ph)       capped, pooled
	 the pieces themselves (for the piece ports: walls, towers, crowns, the whip)
	  cv:flame(kind 2|3|"lick", root, axis, height, width, o{flat=1, side, lean, curl_to, ph, cool, hot, t})   1 part
	  cv:row(center, tangent, o{length=6, height=3.5, thick, variant=1|2, flip, up, ph, cool, hot, t})          1 part
	  cv:column(base, radius, height, t, o{grow=1, gx=1, tiers, speed, flare=0.45, cool, hot, seed, sway=1})    tiers parts
	  cv:hoop(c, radius, t, o{normal=UP, spin=0, thick, ph, cool, hot})                                         1 part
	  cv:chain(pts, width, t, o{n, scroll=0, taper, cool, hot, seed})          one Link per pair of points
	  cv:bulb(root, axis, length, width, o{ph, cool, hot, t}) / cv:core(root, axis, length, width, o) / cv:strip(a, b, width, o)
	  cv:piece(name, originCFrame, sx, sy, sz, o{cool, hot})    any library mesh: scale factors about its design origin
	  cv:piece_axes(family, phase, pos, vx, vy, sx, sy, sz, o{cool, hot})    the same without the name parse or the CFrame

	NOT LIKE THE KIT (rigid instances, not per-frame geometry): a flame leans by TILTING (it cannot bend), a line's
	flames are baked four to a piece (two variants, turned and scaled; per-flame grow becomes per-piece), the layers
	of one mesh scale together (only the burst's core is a part of its own), a column is a stack of rising tiers
	(no single helical surface), a slender lick is a curved blade (wider in the plane it curls in), the flicker is
	3-4 phases, randomness is an integer hash (same statistics, not the renders' positions), embers are
	ParticleEmitters (not deterministic, not in the Blender parity sheets), fire_line returns no tips.
	UNCALIBRATED in Studio: Config.Tint and the baked ramp (against the Neon curve: meshes/neon_solve.json), the
	light watts -> Brightness / Range mapping, the ember look (size, texture, brightness).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PyroDraw = {}

----------------------------------------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------------------------------------
local Config = {
	FXFolderName = "IceMagicFX",          -- fallback; VFXLibrary.Config.FXFolderName wins when readable
	SubFolderName = "PyroDraw",
	MeshFolderName = "FireMagicMeshes.Flame",   -- ReplicatedStorage.<this> (a dotted path), flat, the 45 PF_ MeshParts (PyroDraw.SetMeshFolder)
	RenderPriority = Enum.RenderPriority.Camera.Value + 4,     -- PyroFX's own step: after Viewmodel.Update (Camera + 2)
	MaxLife = 30,                         -- a Play()ed effect is ended this long (os.clock s) after it began

	FPS = 12.5,                           -- phase swaps per second (4 phases = a 0.32 s loop)
	Material = Enum.Material.Neon,
	-- Part.Color multiplies the baked ramp. The library is baked so that Normal shows the approved ramp and white
	-- the HOT one; every Tint.CoolStep of the kit's cool= multiplies by Tint.Cool once more. UNCALIBRATED.
	Tint = { Normal = 0.88, Hot = 1.0, CoolStep = 0.2, Cool = { 0.90, 0.87, 0.85 } },

	MaxParts = 260,                       -- per canvas at density 1 (the Ring's peak)
	MaxLights = 4,                        -- per canvas (2 when thinned below 0.75)
	MaxEmitters = 6,                      -- per canvas
	EnemyThin = 0.6,                      -- density x this for other players' effects under Settings.ThinEnemyVFX
	PoolKeep = 96,                        -- hidden parts kept per mesh
	EmitterKeep = 12,                     -- idle ember emitters kept (a freed one rests 2 s: its sparks are still in the air)
	SizeEps = 0.03,                       -- a part is resized only when a side changes by more than this share
	MinSize = 0.02,                       -- a piece smaller than this (studs, any design axis x scale) is not drawn

	FloorLift = 0.06,                     -- ground strips sit this far over their points
	LeanK = 0.8,                          -- a kit lean (tip offset / height) becomes a tilt of this much
	Slender = 2.6,                        -- height / width from which a flame is drawn with the Spire
	LickBend = 0.4,                       -- a lick is at least this x its height across in the plane it curls in
	RowYaw = 0.14, RowShift = 0.3,        -- fire_line: each Row piece turned (rad) / shifted across the line (studs) x vary
	RowFlames = 4,                        -- points (1.5 studs apart) per Row piece
	RowLen = 6.0, RowH = 3.5,             -- the Row meshes' design length / line height (lib_meta.json)
	RowOverlap = 1.06,
	RowLean = 0.9,
	ColumnTiers = 8, ColumnRush = 0.6,    -- tiers of a column; their rise = this x the kit's 50 studs/s
	ColumnFat = 1.22, ColumnTilt = 0.09,  -- a tier's radius x this (its tongues draw in); each tier tipped this much (rad)
	TailLen = 8.8,

	LightColor = Color3.fromRGB(255, 138, 60),          -- the kit's FIRE_LIGHT_HEX
	LightBrightness = 1.6, LightRange = 14, LightWatts = 1500,     -- the Fireball's light = 1500 W in the kit
	LightBrightnessMax = 6, LightRangeMax = 60,

	EmberTexture = "rbxasset://textures/particles/sparkles_main.dds",
	EmberLightEmission = 0.8, EmberBrightness = 3, EmberSize = 2.6, EmberSquash = 0.4,
}
PyroDraw.Config = Config

----------------------------------------------------------------------------------------------------
-- THE LIBRARY (generated by phase3/gen/pl_gen.py from the meshes: Size and the bounding-box Center of every
-- mesh relative to its design origin, Roblox axes; a MeshPart's pivot is that centre)
----------------------------------------------------------------------------------------------------
local LIB = {
	Flame2 = { -- a standing flame, 2 layers (core + shell): 1 tall, 1 wide at the belly, round (flatten it with Size.Z)
		{ Name = "PF_Flame2_1", Size = Vector3.new(0.9478, 1.0000, 0.9490), Center = Vector3.new(-0.0046, 0.5000, 0.0077) },
		{ Name = "PF_Flame2_2", Size = Vector3.new(1.1164, 1.0000, 1.1194), Center = Vector3.new(-0.0081, 0.5000, 0.0154) },
		{ Name = "PF_Flame2_3", Size = Vector3.new(1.1828, 1.0000, 1.1820), Center = Vector3.new(0.0066, 0.5000, -0.0112) },
		{ Name = "PF_Flame2_4", Size = Vector3.new(1.0688, 1.0000, 1.0690), Center = Vector3.new(0.0076, 0.5000, -0.0310) },
	},
	Flame3 = { -- a standing flame, 3 layers (light core + 2 shells): big / close flames, flames on a hit target
		{ Name = "PF_Flame3_1", Size = Vector3.new(1.1828, 1.0000, 1.1891), Center = Vector3.new(0.0171, 0.5000, -0.0204) },
		{ Name = "PF_Flame3_2", Size = Vector3.new(1.0860, 1.0000, 1.0496), Center = Vector3.new(0.0271, 0.5000, -0.0281) },
		{ Name = "PF_Flame3_3", Size = Vector3.new(0.8736, 1.0000, 0.8978), Center = Vector3.new(0.0334, 0.5000, 0.0154) },
		{ Name = "PF_Flame3_4", Size = Vector3.new(1.1186, 1.0000, 1.1529), Center = Vector3.new(0.0205, 0.5000, 0.0128) },
	},
	Spire = { -- a tall slender flame, 3 layers, an S-curve in it: spires, wall tongues, streamers, the odd tall tongue (height > 2.6 x width)
		{ Name = "PF_Spire_1", Size = Vector3.new(1.1871, 1.0000, 1.2425), Center = Vector3.new(-0.0103, 0.5000, 0.0110) },
		{ Name = "PF_Spire_2", Size = Vector3.new(1.1836, 1.0000, 1.1572), Center = Vector3.new(-0.0688, 0.5000, 0.0008) },
		{ Name = "PF_Spire_3", Size = Vector3.new(1.0152, 1.0000, 0.9210), Center = Vector3.new(-0.1084, 0.5000, -0.0406) },
		{ Name = "PF_Spire_4", Size = Vector3.new(1.1245, 1.0000, 1.1843), Center = Vector3.new(-0.0205, 0.5000, -0.0100) },
	},
	Lick = { -- a curling tongue (it bends toward Roblox -X): the burst's licks, wisps, side tongues, torn tongues
		{ Name = "PF_Lick_1", Size = Vector3.new(1.1359, 1.0000, 1.0748), Center = Vector3.new(-0.1157, 0.5000, 0.0821) },
		{ Name = "PF_Lick_2", Size = Vector3.new(1.1222, 1.0000, 1.0073), Center = Vector3.new(-0.1152, 0.5000, 0.0127) },
		{ Name = "PF_Lick_3", Size = Vector3.new(1.2076, 1.0000, 1.1503), Center = Vector3.new(-0.0554, 0.5000, 0.0362) },
	},
	Core = { -- the light core alone (front faces): the burst's flash and cooling core, a tail's core
		{ Name = "PF_Core_1", Size = Vector3.new(0.9019, 1.0000, 0.8741), Center = Vector3.new(-0.0052, 0.5000, -0.0132) },
		{ Name = "PF_Core_2", Size = Vector3.new(0.9465, 1.0000, 1.0637), Center = Vector3.new(0.0229, 0.5000, -0.0080) },
		{ Name = "PF_Core_3", Size = Vector3.new(1.1177, 1.0000, 1.0757), Center = Vector3.new(0.0159, 0.5000, 0.0495) },
	},
	Ball = { -- the Fireball's head: light core + 2 flame shells with a ragged skirt; the 2-stud ball
		{ Name = "PF_Ball_1", Size = Vector3.new(2.0688, 1.9402, 3.9000), Center = Vector3.new(-0.0109, -0.0250, 0.9500) },
		{ Name = "PF_Ball_2", Size = Vector3.new(2.0401, 2.0035, 3.9000), Center = Vector3.new(-0.0250, 0.0169, 0.9500) },
		{ Name = "PF_Ball_3", Size = Vector3.new(1.9935, 2.0591, 3.9000), Center = Vector3.new(-0.0144, 0.0250, 0.9500) },
		{ Name = "PF_Ball_4", Size = Vector3.new(1.9590, 2.0826, 3.9000), Center = Vector3.new(0.0250, 0.0089, 0.9500) },
	},
	Tail = { -- the streaming tail (2 shells, no nose; its front hides inside the Ball / the source): radius 0.92, length 1
		{ Name = "PF_Tail_1", Size = Vector3.new(2.1041, 1.9700, 1.0089), Center = Vector3.new(-0.0200, -0.0240, 0.4956) },
		{ Name = "PF_Tail_2", Size = Vector3.new(2.1170, 1.9867, 1.0049), Center = Vector3.new(0.0224, 0.0312, 0.4976) },
		{ Name = "PF_Tail_3", Size = Vector3.new(2.1957, 1.9573, 1.0087), Center = Vector3.new(0.0789, 0.0406, 0.4957) },
		{ Name = "PF_Tail_4", Size = Vector3.new(1.9197, 2.0844, 1.0043), Center = Vector3.new(0.1064, 0.0402, 0.4978) },
	},
	Bulb = { -- the burst's body: 2 flame shells blown open into a bulb with a torn licking crown: 1 long, 1 across
		{ Name = "PF_Bulb_1", Size = Vector3.new(1.0294, 1.0000, 1.1292), Center = Vector3.new(0.0598, 0.5000, 0.0060) },
		{ Name = "PF_Bulb_2", Size = Vector3.new(1.1994, 1.0000, 0.9423), Center = Vector3.new(-0.0267, 0.5000, -0.0032) },
		{ Name = "PF_Bulb_3", Size = Vector3.new(0.9896, 1.0000, 1.2017), Center = Vector3.new(-0.0203, 0.5000, -0.0902) },
	},
	Column = { -- one tier of a column of fire (3 layers, a tulip torn into five tongues): radius 1, 2.4 tall
		{ Name = "PF_Column_1", Size = Vector3.new(1.9655, 2.4140, 1.9646), Center = Vector3.new(0.0638, 1.1930, -0.0247) },
		{ Name = "PF_Column_2", Size = Vector3.new(2.1316, 2.4172, 1.8128), Center = Vector3.new(-0.0299, 1.1914, 0.0010) },
		{ Name = "PF_Column_3", Size = Vector3.new(1.9242, 2.4141, 1.9942), Center = Vector3.new(-0.0261, 1.1929, -0.0530) },
	},
	RowA = { -- an arc piece of a line of fire: 4 flames + a bed of 4 low licks, 6 studs long, 3.5-stud line; a tall tongue in it
		{ Name = "PF_RowA_1", Size = Vector3.new(7.2345, 5.2500, 1.7630), Center = Vector3.new(-0.1168, 2.6250, 0.0120) },
		{ Name = "PF_RowA_2", Size = Vector3.new(7.6817, 5.2500, 1.9060), Center = Vector3.new(-0.1867, 2.6250, 0.0039) },
		{ Name = "PF_RowA_3", Size = Vector3.new(7.7770, 5.2500, 1.7611), Center = Vector3.new(-0.2438, 2.6250, 0.0086) },
		{ Name = "PF_RowA_4", Size = Vector3.new(7.4624, 5.2500, 1.6783), Center = Vector3.new(-0.1566, 2.6250, 0.0005) },
	},
	RowB = { -- an arc piece of a line of fire, the saddle: 4 flames (one a low gap) + bed
		{ Name = "PF_RowB_1", Size = Vector3.new(7.0599, 4.2000, 1.8624), Center = Vector3.new(-0.3518, 2.1000, 0.0104) },
		{ Name = "PF_RowB_2", Size = Vector3.new(7.3801, 4.2000, 1.8946), Center = Vector3.new(-0.4765, 2.1000, 0.0037) },
		{ Name = "PF_RowB_3", Size = Vector3.new(7.6006, 4.2000, 1.8723), Center = Vector3.new(-0.4129, 2.1000, 0.0125) },
		{ Name = "PF_RowB_4", Size = Vector3.new(7.5174, 4.2000, 1.7357), Center = Vector3.new(-0.3301, 2.1000, 0.0094) },
	},
	Strip = { -- the burning line on the ground: 1 x 1, flat
		{ Name = "PF_Strip_1", Size = Vector3.new(1.0000, 0.0400, 1.0000), Center = Vector3.new(-0.0000, 0.0200, 0.0000) },
	},
	Hoop = { -- a closed ring of flame, radius 1 (Detonate's circlet, Ember Refund's hoop)
		{ Name = "PF_Hoop_1", Size = Vector3.new(2.2264, 0.4751, 2.2371), Center = Vector3.new(-0.0206, 0.0174, -0.0144) },
		{ Name = "PF_Hoop_2", Size = Vector3.new(2.2266, 0.4751, 2.2371), Center = Vector3.new(0.0211, 0.0174, 0.0146) },
	},
	Link = { -- one link of the whip's rope: length 1, 1 across
		{ Name = "PF_Link_1", Size = Vector3.new(0.9863, 0.9018, 1.3000), Center = Vector3.new(0.0275, -0.0000, -0.5000) },
		{ Name = "PF_Link_2", Size = Vector3.new(1.2351, 1.0930, 1.3000), Center = Vector3.new(0.0135, 0.0000, -0.5000) },
	},
}

----------------------------------------------------------------------------------------------------
-- MATHS (m_geom.py's curves)
----------------------------------------------------------------------------------------------------
local sin, cos, abs, floor, ceil, max, min, sqrt, exp, pi = math.sin, math.cos, math.abs, math.floor, math.ceil,
	math.max, math.min, math.sqrt, math.exp, math.pi
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)
local XAX = Vector3.new(1, 0, 0)
local ZERO = Vector3.new(0, 0, 0)
local NONE = table.freeze({})
local GOLDEN = 2.39996323
local LIGHT_OPT = { t = nil, ph = nil, range = nil }
local EM_LIFE, EM_OUT, EM_UP, EM_SIZE = { 0.22, 0.6 }, { 2, 10 }, { 1, 7 }, { 0.06, 0.15 }
local EB_LIFE, EB_SPEED, EB_SIZE = { 0.35, 0.85 }, { 9, 33 }, { 0.07, 0.17 }
local EF_LIFE, EF_UP, EF_SIZE = { 0.5, 1.0 }, { 5, 14 }, { 0.12, 0.3 }
local PE_OPT = { id = nil, count = 0, inner = 0, life = { 0.8, 1.6 }, up = { 34, 56 }, size = { 0.3, 0.7 }, g = 0, kd = 0.9, lift = 2 }

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

--- smoothstep a -> b
local function sst(a, b, x)
	local d = b - a
	if d < 1e-9 then d = 1e-9 end
	local u = clamp((x - a) / d, 0, 1)
	return u * u * (3 - 2 * u)
end

local function sm(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

--- ease-out Back (overshoots), the kit's eback
local function eback(u, s)
	s = s or 1.4
	u = clamp(u, 0, 1) - 1
	return u * u * ((s + 1) * u + s) + 1
end

local function equint(u)
	return 1 - (1 - clamp(u, 0, 1)) ^ 5
end

--- a fire light's flicker, about +-15 % at 10 and 7.5 Hz
local function flick(t, ph)
	ph = ph or 0
	return 1 + 0.10 * sin(TAU * 10.0 * t + ph) + 0.07 * sin(TAU * 7.5 * t + 1.3 + ph * 2)
end

--- Blender (x, y, z-up) -> Roblox
local function B(x, y, z)
	return Vector3.new(-x, z, y)
end

local function unit(v, fallback)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return fallback or UP
end

--- any unit vector perpendicular to d
local function perp(d)
	return unit(d:Cross(abs(d.Y) < 0.9 and UP or XAX), XAX)
end

PyroDraw.clamp, PyroDraw.sst, PyroDraw.sm, PyroDraw.eback, PyroDraw.equint, PyroDraw.flick = clamp, sst, sm, eback, equint, flick
PyroDraw.B, PyroDraw.UP = B, UP

----------------------------------------------------------------------------------------------------
-- RANDOMNESS: an integer hash (lowbias32), identical on every client, allocation-free
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

--- the kit's rr(k, col, seed): uniform [0, 1) for (seed, id, column)
local function rnd(seed, k, col)
	return mix(mix(mix(floor(seed) % TWO32) + floor(k) % TWO32) + (floor(col or 0) + 1) * 0x9E3779B9) / TWO32
end

--- the kit's runit: a unit vector per id
local function runit(k, seed, c0)
	local z = rnd(seed, k, c0) * 2 - 1
	local a = rnd(seed, k, c0 + 1) * TAU
	local r = sqrt(max(0, 1 - z * z))
	return Vector3.new(-r * cos(a), z, r * sin(a))
end

function PyroDraw.Rand(a, b, c)
	return rnd(a or 0, b or 0, c or 0)
end

----------------------------------------------------------------------------------------------------
-- CLOCKS, SETTINGS
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if not warned[key] then
		warned[key] = true
		warn("[PyroDraw] " .. msg)
	end
end

local vfxLib, settingsLib = nil, nil
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
PyroDraw.TimeScale = timeScale

function PyroDraw.ServerNow()
	return workspace:GetServerTimeNow()
end

--- clip seconds: (serverNow - t0) * scale + offset; t0 nil = a local clock from now
function PyroDraw.Clock(t0, offset, scale)
	offset = offset or 0
	scale = scale or timeScale()
	if t0 == nil then
		local o = os.clock()
		return function() return (os.clock() - o) * scale + offset end
	end
	return function() return (workspace:GetServerTimeNow() - t0) * scale + offset end
end

--- how much of an effect to draw: Settings.EffectDensity (0.45 .. 1.15), thinned for other players' effects
function PyroDraw.Density(own)
	loadLibs()
	local d = 1
	if settingsLib then
		local e = settingsLib.EffectDensity
		if type(e) == "number" and e > 0 then d = e end
		if settingsLib.ThinEnemyVFX and not own then d = d * Config.EnemyThin end
	end
	return d
end

----------------------------------------------------------------------------------------------------
-- THE POOL: one folder; a part per slot, kept hidden between uses
----------------------------------------------------------------------------------------------------
local root = { Folder = nil, Anchor = nil, Gen = 0 }
local freeParts = {}                      -- mesh name -> { slot }
local freeLights, freeEmitters = {}, {}
local folderSource, meshFolder = nil, nil
local MESH = {}                           -- mesh name -> { Name, Template, bx, by, bz, cx, cy, cz } | false
local FAM = {}                            -- family -> { n = phases, [1..n] = mesh record }
local TINTS = {}

function PyroDraw.SetFolder(src)
	folderSource = src
end

--- The folder the PF_ meshes are read from: SetMeshFolder's, else ReplicatedStorage.<Config.MeshFolderName>; nil when
--- the place does not have it.
function PyroDraw.MeshFolder()
	if meshFolder then return meshFolder end
	local at = ReplicatedStorage
	for _, name in ipairs(string.split(Config.MeshFolderName, ".")) do
		at = at and at:FindFirstChild(name)
	end
	return at
end

function PyroDraw.SetMeshFolder(inst)
	meshFolder = inst
	table.clear(MESH)
	for _, f in pairs(FAM) do
		for i = 1, f.n do f[i] = nil end
	end
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

local function inert(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

local function ensureRoot()
	local a, f = root.Anchor, root.Folder
	if a and f and a.Parent == f and f.Parent ~= nil then return end
	root.Gen += 1                                       -- whatever the old folder held went with it
	table.clear(freeParts)
	table.clear(freeLights)
	table.clear(freeEmitters)
	if f and f.Parent ~= nil then f:Destroy() end
	f = Instance.new("Folder")
	f.Name = Config.SubFolderName
	a = Instance.new("Part")
	a.Name = "PyroDrawAnchor"
	inert(a)
	a.Transparency = 1
	a.Size = Vector3.new(0.05, 0.05, 0.05)
	a.CFrame = CFrame.new()                             -- identity: Attachment.Position == world position
	a.Parent = f
	f.Parent = fxParent()
	root.Folder, root.Anchor = f, a
end

--- the mesh record of a library name: its template and the design numbers scaled to the template's real Size
local function meshRec(def)
	local rec = MESH[def.Name]
	if rec ~= nil then return rec end
	local folder = PyroDraw.MeshFolder()
	local src = folder and folder:FindFirstChild(def.Name)
	if not (src and src:IsA("BasePart")) then
		warnOnce("mesh:" .. def.Name, ("mesh '%s' not found in ReplicatedStorage.%s"):format(def.Name, Config.MeshFolderName))
		MESH[def.Name] = false
		return false
	end
	local base, want = src.Size, def.Size
	local kx, ky, kz = base.X / want.X, base.Y / want.Y, base.Z / want.Z
	if abs(kx - 1) > 0.02 or abs(ky - 1) > 0.02 or abs(kz - 1) > 0.02 then
		warnOnce("size:" .. def.Name, ("'%s' is %.3f x %.3f x %.3f, the library says %.3f x %.3f x %.3f (import scale?)"):format(
			def.Name, base.X, base.Y, base.Z, want.X, want.Y, want.Z))
	end
	rec = { Name = def.Name, Template = src, bx = base.X, by = base.Y, bz = base.Z,
		cx = def.Center.X * kx, cy = def.Center.Y * ky, cz = def.Center.Z * kz }
	MESH[def.Name] = rec
	return rec
end

--- Whether the WHOLE library is in the mesh folder: every name a MeshPart of the library's Size (within 2 %, the check
--- meshRec warns on). -> ok, { the names that are missing, not a MeshPart or the wrong size; sorted }, the library's
--- count. THE LOOK SWITCH'S GATE (PyroFX's flameLibs): emit() draws nothing for a mesh that is not there and nothing
--- throws, so on a partial import a piece would be invisible with no toon fallback. 45 FindFirstChild: not for a frame.
function PyroDraw.Ready()
	local folder = PyroDraw.MeshFolder()
	local bad, total = {}, 0
	for _, list in pairs(LIB) do
		for _, def in ipairs(list) do
			total += 1
			local src = folder and folder:FindFirstChild(def.Name)
			if not (src and src:IsA("MeshPart")) then
				bad[#bad + 1] = def.Name
			else
				local base, want = src.Size, def.Size
				if abs(base.X / want.X - 1) > 0.02 or abs(base.Y / want.Y - 1) > 0.02 or abs(base.Z / want.Z - 1) > 0.02 then
					bad[#bad + 1] = def.Name .. " (size)"
				end
			end
		end
	end
	table.sort(bad)
	return #bad == 0, bad, total
end

for fam, list in pairs(LIB) do
	FAM[fam] = { n = #list, defs = list }
end

--- the mesh record of a family's phase (1-based), false when the place does not have it
local function famMesh(fam, k)
	local m = fam[k]
	if m == nil then
		m = meshRec(fam.defs[k])
		if m then m.Fam = fam end
		fam[k] = m
	end
	return m
end

local F2, F3, SPIRE, LICK, CORE, BALL, TAIL, BULB, COLUMN, ROWA, ROWB, STRIP, HOOP, LINK =
	FAM.Flame2, FAM.Flame3, FAM.Spire, FAM.Lick, FAM.Core, FAM.Ball, FAM.Tail, FAM.Bulb, FAM.Column, FAM.RowA, FAM.RowB,
	FAM.Strip, FAM.Hoop, FAM.Link

-- WRAPS (SkinCatalog, 2026-10-10): a canvas made under PyroDraw.WithWrap(wrap, fn) -- or inside a frame of a canvas
-- that has one -- draws every flame from a recoloured copy of its mesh (the wrap's bands remapped onto the baked ramp:
-- built once per client per mesh, fixed-size, nothing added, so the parts and their counts are Default's) and its
-- lights in the wrap's colour. A copy still building draws Default for that flame.
local pendingWrap = nil
function PyroDraw.WithWrap(wrap, fn, ...)
	local prev = pendingWrap
	pendingWrap = wrap
	local r = table.pack(pcall(fn, ...))
	pendingWrap = prev
	if not r[1] then error(r[2], 0) end
	return table.unpack(r, 2, r.n)
end
--- The wrap a canvas made right now would wear (to hand to one made later, outside any frame: an impact).
function PyroDraw.CurrentWrap() return pendingWrap end
-- a wrap's embers: hard steps, white-hot to azure (no smooth blend)
local wrapEmbers = {}
local function wrapEmberSeq(w)
	local s = wrapEmbers[w.Id]
	if not s then
		local c = w.Embers or { Color3.new(1, 1, 1), Color3.fromHex("#C4F4FF"), Color3.fromHex("#4FD6EE"), Color3.fromHex("#1C6FD8") }
		local kp, n = {}, #c
		for i, col in ipairs(c) do
			local a, b = (i - 1) / n, i / n
			kp[#kp + 1] = ColorSequenceKeypoint.new(a, col)
			kp[#kp + 1] = ColorSequenceKeypoint.new(i == n and 1 or b - 0.001, col)
		end
		s = ColorSequence.new(kp)
		wrapEmbers[w.Id] = s
	end
	return s
end
local wrapRecs, wrapKeep = {}, {}
local function wrapBand(c, F)
	local u = ((0.3 * c.R + 0.59 * c.G + 0.11 * c.B) - F.Lo) / (F.Hi - F.Lo)
	local s = F.Steps
	return (u < s[1] and F.Azure) or (u < s[2] and F.Sky) or (u < s[3] and F.Pale) or F.White
end
local function wrapRec(m, w)
	local byId = wrapRecs[w.Id]
	if not byId then
		byId = {}
		wrapRecs[w.Id] = byId
	end
	local r = byId[m.Name]
	if r ~= nil then return r or m end
	byId[m.Name] = false
	task.spawn(function()
		local ok, tpl = pcall(function()
			local AS = game:GetService("AssetService")
			local em = AS:CreateEditableMeshAsync(Content.fromUri(m.Template.MeshId))
			for _, id in ipairs(em:GetColors()) do em:SetColor(id, wrapBand(em:GetColor(id), w.Flame)) end
			local mp = AS:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
			wrapKeep[#wrapKeep + 1] = em
			local t = m.Template:Clone()
			t:ApplyMesh(mp)
			t.Size = m.Template.Size
			return t
		end)
		if ok then
			local d = table.clone(m)
			d.Name, d.Template = m.Name .. "@" .. w.Id, tpl
			byId[m.Name] = d
		else
			warnOnce("wrap:" .. m.Name, "wrap mesh " .. m.Name .. ": " .. tostring(tpl))
		end
	end)
	return m
end

--- Builds every flame mesh's copy for `wrap` now (in the background), so its first cast is already wrapped.
function PyroDraw.PrewarmWrap(wrap)
	if type(wrap) ~= "table" or not wrap.Flame then return end
	for _, fam in pairs(FAM) do
		for k = 1, fam.n do
			local m = famMesh(fam, k)
			if m then wrapRec(m, wrap) end
		end
	end
end

local function newSlot(rec)
	local p = rec.Template:Clone()
	inert(p)
	p.Material = Config.Material
	p.LocalTransparencyModifier = 1
	p.Parent = root.Folder
	return { Part = p, shown = false, x = -1, y = -1, z = -1, tint = -1, free = true }
end

local function takeSlot(rec)
	local list = freeParts[rec.Name]
	local s = list and table.remove(list)
	s = s or newSlot(rec)
	s.free = false
	return s
end

--- back to its mesh's pool. It is NOT hidden here: another flame swapping to this phase in the same frame takes it as
--- it is; whatever is still free at End() is hidden then
local function releaseSlot(rec, s, released)
	local list = freeParts[rec.Name]
	if not list then
		list = {}
		freeParts[rec.Name] = list
	end
	if #list < Config.PoolKeep then
		s.free = true
		list[#list + 1] = s
		if released and s.shown then released[#released + 1] = s end
	else
		s.Part:Destroy()
	end
end

--- Color = tint(hot, cool): cached per (hot, cool step of 0.04)
local COOL_Q = 0.04
local function tintKey(hot, cool)
	local c = cool and floor(cool / COOL_Q + 0.5) or 0
	if c < 0 then c = 0 elseif c > 40 then c = 40 end
	return (hot and 64 or 0) + c
end

local function tintColor(key)
	local c = TINTS[key]
	if not c then
		local T = Config.Tint
		local base = key >= 64 and T.Hot or T.Normal
		local k = (key % 64) * COOL_Q / T.CoolStep
		c = Color3.new(min(1, base * T.Cool[1] ^ k), min(1, base * T.Cool[2] ^ k), min(1, base * T.Cool[3] ^ k))
		TINTS[key] = c
	end
	return c
end

function PyroDraw.ClearTints()
	table.clear(TINTS)
end

--- create hidden parts ahead of the first effect: n per mesh, or { Family = n }
function PyroDraw.Prewarm(n)
	ensureRoot()
	for famName, fam in pairs(FAM) do
		local want = type(n) == "table" and (n[famName] or 0) or (n or 0)
		for k = 1, fam.n do
			local rec = famMesh(fam, k)
			if rec then
				local list = freeParts[rec.Name]
				if not list then
					list = {}
					freeParts[rec.Name] = list
				end
				for _ = #list + 1, min(want, Config.PoolKeep) do list[#list + 1] = newSlot(rec) end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE CANVAS
----------------------------------------------------------------------------------------------------
local Canvas = {}
Canvas.__index = Canvas

function PyroDraw.new(name, o)
	o = o or NONE
	ensureRoot()
	local d = o.density or PyroDraw.Density(o.own)
	local cv = setmetatable({
		Name = name or "fx", T = 0, gen = root.Gen, Hot = o.hot or false, Density = d,
		MaxParts = floor((o.maxParts or Config.MaxParts) * clamp(d, 0.3, 1) + 0.5),
		MaxLights = d < 0.75 and min(2, Config.MaxLights) or Config.MaxLights,
		recs = {}, recList = {}, released = {}, mvParts = {}, mvCF = {}, nMove = 0,
		lights = {}, nLight = 0, uLight = 0,
		emitters = {}, nEmit = 0, uEmit = 0, fired = {},
		Parts = 0, Dropped = 0, Peak = 0, PeakT = 0, PeakDropped = 0, Dead = false, Wrap = o.wrap or pendingWrap,
	}, Canvas)
	return cv
end

function Canvas:SetHot(on)
	self.Hot = on and true or false
end

function Canvas:Begin(t)
	ensureRoot()
	if self.gen ~= root.Gen then                        -- the folder was rebuilt: our old slots are gone
		self.gen = root.Gen
		table.clear(self.recs)
		table.clear(self.recList)
		table.clear(self.lights)
		table.clear(self.emitters)
		self.uLight, self.uEmit = 0, 0
	end
	self.T = t or 0
	self.Parts, self.Dropped, self.nMove, self.nLight, self.nEmit = 0, 0, 0, 0, 0
	local list = self.recList
	for i = 1, #list do list[i].n = 0 end
end

local function lightOff(s)
	if s.on then
		s.on = false
		s.Light.Enabled = false
	end
end

local function emitterOff(s)
	if s.on then
		s.on = false
		s.Emitter.Enabled = false
	end
end

function Canvas:End()
	local parts, cfs, n = self.mvParts, self.mvCF, self.nMove
	for i = #parts, n + 1, -1 do
		parts[i] = nil
		cfs[i] = nil
	end
	if n > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	local list = self.recList
	local released = self.released
	for i = 1, #list do
		local r = list[i]
		local items = r.items
		for k = r.n + 1, r.u do                             -- flames that were not drawn this frame give their part back
			local it = items[k]
			if it.slot then
				releaseSlot(it.mesh, it.slot, released)
				it.slot, it.mesh = nil, nil
			end
		end
		r.u = r.n
	end
	for i = #released, 1, -1 do                             -- parts nobody took again: hide them
		local s = released[i]
		if s.free and s.shown then
			s.shown = false
			s.Part.LocalTransparencyModifier = 1
		end
		released[i] = nil
	end
	for i = self.nLight + 1, self.uLight do lightOff(self.lights[i]) end
	self.uLight = self.nLight
	for i = self.nEmit + 1, self.uEmit do emitterOff(self.emitters[i]) end
	self.uEmit = self.nEmit
	if self.Parts > self.Peak then self.Peak, self.PeakT = self.Parts, self.T end
	if self.Dropped > self.PeakDropped then
		if self.PeakDropped == 0 then
			warnOnce("cap:" .. self.Name, ("%s: %d parts over the cap of %d at t=%.2f"):format(self.Name, self.Dropped, self.MaxParts, self.T))
		end
		self.PeakDropped = self.Dropped
	end
	return self.Parts
end

--- hide everything this canvas drew (keeps its slots)
function Canvas:Clear()
	self:Begin(self.T)
	self:End()
end

function Canvas:Destroy()
	if self.Dead then return end
	self.Dead = true
	local alive = (self.gen == root.Gen)
	local now = os.clock()
	for _, r in ipairs(self.recList) do
		for _, it in ipairs(r.items) do
			local s = it.slot
			if s then
				if s.shown then
					s.shown = false
					s.Part.LocalTransparencyModifier = 1
				end
				if alive then releaseSlot(it.mesh, s, nil) else s.Part:Destroy() end
				it.slot, it.mesh = nil, nil
			end
		end
	end
	table.clear(self.released)
	for _, s in ipairs(self.lights) do
		lightOff(s)
		if alive then freeLights[#freeLights + 1] = s else s.Att:Destroy() end
	end
	for _, s in ipairs(self.emitters) do
		emitterOff(s)
		s.site = nil
		s.rate = nil
		s.freeAt = now + 2.0                            -- its last sparks are still in the air
		if alive and #freeEmitters < Config.EmitterKeep then
			freeEmitters[#freeEmitters + 1] = s
		else
			local part = s.Part
			task.delay(2.5, function() part:Destroy() end)
		end
	end
	table.clear(self.recs)
	table.clear(self.recList)
	table.clear(self.lights)
	table.clear(self.emitters)
	table.clear(self.mvParts)
	table.clear(self.mvCF)
end

function PyroDraw.Stats()
	local n = 0
	for _, list in pairs(freeParts) do n += #list end
	return { FreeParts = n, FreeLights = #freeLights, FreeEmitters = #freeEmitters, Generation = root.Gen }
end

local function hotOf(cv, hot)
	if hot == nil then return cv.Hot end
	return hot
end

----------------------------------------------------------------------------------------------------
-- EMISSION: one library mesh at its design origin `pos`, axes (vx, vy, vz = vx x vy), scale factors
----------------------------------------------------------------------------------------------------
local function emit(cv, m, pos, vx, vy, vz, sx, sy, sz, tint)
	if not m then return end
	local bx, by, bz = m.bx * sx, m.by * sy, m.bz * sz
	local lo = Config.MinSize
	if bx < lo or by < lo * 0.1 or bz < lo then return end
	if cv.Parts >= cv.MaxParts then
		cv.Dropped += 1
		return
	end
	-- a flame keeps its identity (its place in its FAMILY's draw order) from frame to frame, and one part at a time:
	-- when its phase swaps it gives that part back and takes one of the new mesh
	local fam = m.Fam
	if cv.Wrap then m = wrapRec(m, cv.Wrap) end
	local r = cv.recs[fam]
	if not r then
		r = { items = {}, n = 0, u = 0 }
		cv.recs[fam] = r
		cv.recList[#cv.recList + 1] = r
	end
	local n = r.n + 1
	r.n = n
	if n > r.u then r.u = n end
	local it = r.items[n]
	if not it then
		it = { slot = nil, mesh = nil }
		r.items[n] = it
	end
	local s = it.slot
	if it.mesh ~= m then
		if s then releaseSlot(it.mesh, s, cv.released) end
		s = takeSlot(m)
		it.slot, it.mesh = s, m
	end
	local part = s.Part
	local eps = Config.SizeEps
	if abs(bx - s.x) > eps * s.x or abs(by - s.y) > eps * s.y or abs(bz - s.z) > eps * s.z then
		s.x, s.y, s.z = bx, by, bz
		part.Size = Vector3.new(bx, by, bz)
	end
	if s.tint ~= tint then
		s.tint = tint
		part.Color = tintColor(tint)
	end
	if not s.shown then
		s.shown = true
		part.LocalTransparencyModifier = 0
	end
	local k = cv.nMove + 1
	cv.nMove = k
	cv.mvParts[k] = part
	local cf = CFrame.fromMatrix(pos + vx * (m.cx * sx) + vy * (m.cy * sy) + vz * (m.cz * sz), vx, vy, vz)
	cv.mvCF[k] = cf
	cv.Parts += 1
	local tap = PyroDraw._tap
	if tap then tap(m.Name, cf, bx, by, bz, tint) end
end

local function phaseOf(fam, t, ph)
	return floor(t * Config.FPS + ph / TAU * fam.n) % fam.n + 1
end

--- a flame's 2.5 Hz breathing, STEPPED with its own phase swaps (a 4-phase mesh): its Size then changes when its mesh
--- does (12.5 times a second), not every frame
local function breath(t, ph)
	local off = ph / TAU * 4
	return sin(TAU * 2.5 * ((floor(t * Config.FPS + off) - off) / Config.FPS) + ph)
end

--- a nested flame: root p, axis d (unit), the wide axis `side` (nil: turned by its own phase), height h, belly width
--- w, thickness w x flat; lean = the kit's lean (tip offset / height): a tilt
local function emitFlame(cv, fam, p, d, side, h, w, flat, ph, tint, t, lean)
	if h < 0.02 or w < 0.01 then return end
	if lean then d = unit(d + lean * Config.LeanK, d) end
	local x
	if side then
		x = side - d * side:Dot(d)
		if x.Magnitude < 1e-4 then side = nil else x = x.Unit end
	end
	if not side then
		local a = perp(d)
		local b = d:Cross(a)
		x = a * cos(ph * 1.7) + b * sin(ph * 1.7)
	end
	if h > Config.Slender * w then
		fam = SPIRE
		if floor(ph * 7) % 2 == 1 then x = -x end       -- its S-curve the other way round
	end
	emit(cv, famMesh(fam, phaseOf(fam, t, ph)), p, x, d, x:Cross(d), w, h, w * flat, tint)
end

--- a curling tongue: it bends toward curlTo (any vector; its part across d is used)
local function emitLick(cv, p, d, curlTo, h, w, flat, ph, tint, t)
	if h < 0.02 or w < 0.01 then return end
	local c = curlTo - d * curlTo:Dot(d)
	local x
	if c.Magnitude < 1e-4 then x = perp(d) else x = -c.Unit end      -- the mesh bends toward its -X
	-- a slender lick keeps its curl: the bend is a share of the mesh's WIDTH, so it is never narrower than that in
	-- the plane it curls in (a curved blade, w x flat thick)
	emit(cv, famMesh(LICK, phaseOf(LICK, t, ph)), p, x, d, x:Cross(d), max(w, Config.LickBend * h), h, w * flat, tint)
end

--- a piece grown along `axis` from `root` and round about it (Core, Bulb): across = its width, len = its length
local function emitAxial(cv, fam, rootP, axis, across, len, ph, tint, t)
	if len < 0.02 or across < 0.02 then return end
	local a = perp(axis)
	local b = axis:Cross(a)
	local x = a * cos(ph) + b * sin(ph)
	emit(cv, famMesh(fam, phaseOf(fam, t, ph)), rootP, x, axis, x:Cross(axis), across, len, across, tint)
end

--- an arc piece of a line: centre on the ground, tangent, its up axis (tilted across the line only)
local function emitRow(cv, fam, flip, center, tg, upV, sLen, sH, sThick, ph, tint, t)
	local x = flip and -tg or tg
	local y = upV - x * upV:Dot(x)
	y = unit(y, UP)
	emit(cv, famMesh(fam, phaseOf(fam, t, ph)), center, x, y, x:Cross(y), sLen, sH, sThick, tint)
end

local function emitStrip(cv, a, b, width, tint, lift)
	local dv = b - a
	local len = dv.Magnitude
	if len < 0.05 or width < 0.03 then return end
	local z = dv / len
	local y = unit(UP - z * UP:Dot(z), UP)
	emit(cv, famMesh(STRIP, 1), (a + b) * 0.5 + UP * (lift or Config.FloorLift), y:Cross(z), y, z, width, 1, len * 1.04, tint)
end

--- the comet pieces: `back` = the unit vector from the head toward its tail
local function emitBall(cv, c, back, s, sLen, ph, tint, t)
	local x = unit(UP:Cross(back), XAX)
	emit(cv, famMesh(BALL, phaseOf(BALL, t, ph)), c, x, back:Cross(x), back, s, s, s * sLen, tint)
end

local function emitTail(cv, front, back, r, len, ph, tint, t)
	if len < 0.05 or r < 0.02 then return end
	local a = unit(UP:Cross(back), XAX)
	local b = back:Cross(a)
	local x = a * cos(ph) + b * sin(ph)
	emit(cv, famMesh(TAIL, phaseOf(TAIL, t, ph)), front, x, back:Cross(x), back, r, r, len, tint)
end

----------------------------------------------------------------------------------------------------
-- LIGHTS (PointLights on pooled Attachments of the anchor part) AND EMBERS (pooled ParticleEmitters)
----------------------------------------------------------------------------------------------------
local function newLight()
	local at = Instance.new("Attachment")
	at.Name = "PyroLight"
	at.Parent = root.Anchor
	local l = Instance.new("PointLight")
	l.Color = Config.LightColor
	l.Shadows = false
	l.Enabled = false
	l.Parent = at
	return { Att = at, Light = l, on = false, b = -1, r = -1 }
end

--- THE WARM PointLight. watts as the kit's (the ball 1500, a fist flame 420); o.t flickers it; o.range overrides
function Canvas:fire_light(p, watts, o)
	o = o or NONE
	if o.t then watts = watts * flick(o.t, o.ph) end
	if watts <= 1e-3 then return end
	if self.nLight >= self.MaxLights then return end
	local n = self.nLight + 1
	self.nLight = n
	local s = self.lights[n]
	if not s then
		s = table.remove(freeLights) or newLight()
		self.lights[n] = s
	end
	if n > self.uLight then self.uLight = n end
	local k = watts / Config.LightWatts
	local b = min(Config.LightBrightness * k ^ 0.5, Config.LightBrightnessMax)
	local r = min(o.range or Config.LightRange * k ^ 0.3, Config.LightRangeMax)
	s.Att.Position = p
	if abs(b - s.b) > 0.04 * s.b or s.b < 0 then
		s.b = b
		s.Light.Brightness = b
	end
	if abs(r - s.r) > 0.04 * s.r or s.r < 0 then
		s.r = r
		s.Light.Range = r
	end
	if not s.on then
		s.on = true
		s.Light.Enabled = true
	end
	local lc = self.Wrap and self.Wrap.Light or Config.LightColor
	if s.Light.Color ~= lc then s.Light.Color = lc end
	local tap = PyroDraw._tapLight
	if tap then tap(p, b, r) end
end

--- a pool of warm light on the floor under p, about `radius` studs wide
function Canvas:ground_glow(p, radius, level, t, ph)
	radius, level = radius or 6, level or 1
	local h = clamp(0.3 * radius, 0.8, 6)
	LIGHT_OPT.t, LIGHT_OPT.ph, LIGHT_OPT.range = t, ph, min(radius * 1.5 + h, Config.LightRangeMax)
	self:fire_light(Vector3.new(p.X, p.Y + h, p.Z), 165 * level * h * h, LIGHT_OPT)
end

local EMBER_SEQ = nil
local function emberColor()
	if not EMBER_SEQ then
		EMBER_SEQ = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 231, 176)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 177, 74)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(242, 106, 20)), ColorSequenceKeypoint.new(0.78, Color3.fromRGB(179, 40, 12)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 20, 8)),
		})
	end
	return EMBER_SEQ
end

local function newEmitter()
	local p = Instance.new("Part")
	p.Name = "PyroEmber"
	inert(p)
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = root.Folder
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.Texture = Config.EmberTexture
	e.Color = emberColor()
	e.LightEmission = Config.EmberLightEmission
	e.Brightness = Config.EmberBrightness
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(Config.EmberSquash)
	e.Transparency = NumberSequence.new(0)
	e.Rotation = NumberRange.new(0)
	e.LockedToPart = false
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	return { Part = p, Emitter = e, on = false, site = nil, freeAt = 0 }
end

--- an emitter slot for a call site; cfg(e, part) runs once per (slot, site)
local function emitterSlot(cv, site, cfg, a, b, c, d)
	if cv.nEmit >= Config.MaxEmitters then return nil end
	local n = cv.nEmit + 1
	cv.nEmit = n
	local s = cv.emitters[n]
	if not s then
		local now = os.clock()
		for i = #freeEmitters, 1, -1 do
			if freeEmitters[i].freeAt <= now then
				s = table.remove(freeEmitters, i)
				break
			end
		end
		s = s or newEmitter()
		cv.emitters[n] = s
	end
	if n > cv.uEmit then cv.uEmit = n end
	if s.site ~= site then
		-- re-dressed for another call site: cfg may write Rate itself (cfgBurst: 0), so the cached rate is void. Without
		-- this a trail spray handed an emitter that a burst had used stayed at Rate 0 (its rate equalled the stale cache)
		s.site = site
		s.rate = nil
		s.Emitter.Enabled = false
		s.on = false
		cfg(s.Emitter, s.Part, a, b, c, d)
		s.ec = nil
	end
	-- a wrapped canvas's embers take the wrap's colours (Immolate's crown, the bursts); Default's stay as cfg left them
	if cv.Wrap and s.ec ~= cv.Wrap.Id then
		s.ec = cv.Wrap.Id
		s.Emitter.Color = wrapEmberSeq(cv.Wrap)
	elseif not cv.Wrap and s.ec then
		s.ec = nil
		s.Emitter.Color = emberColor()
	end
	return s
end

local function sizeSeq(s0, s1)
	local k = Config.EmberSize
	local mid, env = (s0 + s1) * 0.5 * k, (s1 - s0) * 0.5 * k
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, mid, env), NumberSequenceKeypoint.new(0.6, mid * 0.6, env * 0.6),
		NumberSequenceKeypoint.new(1, 0.02) })
end

--- the part's +Y (the emission direction) along `dir`
local function aimPart(part, p, dir)
	local y = unit(dir, UP)
	local x = perp(y)
	part.CFrame = CFrame.fromMatrix(p, x, y, x:Cross(y))
end

local function cfgSpray(e, part, o, hot)
	local life, out, upR, size = o.life or EM_LIFE, o.out or EM_OUT, o.up or EM_UP, o.size or EM_SIZE
	local om, um = (out[1] + out[2]) * 0.5, (upR[1] + upR[2]) * 0.5
	local sp = clamp((o.spread or 0.5) * 2, 0.2, 60)
	part.Size = Vector3.new(sp, sp, sp)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Lifetime = NumberRange.new(life[1], life[2])
	e.Speed = NumberRange.new(max(0.5, min(out[1], upR[1])), sqrt(out[2] * out[2] + upR[2] * upR[2]))
	local ang = clamp(math.deg(math.atan2(om, max(um, 0.01))) * 1.6, 15, 180)
	e.SpreadAngle = Vector2.new(ang, ang)
	e.Acceleration = Vector3.new(0, -(o.g or 36), 0)
	e.Drag = o.kd or 4.5
	e.Size = sizeSeq(size[1], size[2])
end

--- EMBERS THROWN OFF A SOURCE while you keep calling it: gravity + drag, cooling, shrinking. One ParticleEmitter.
function Canvas:embers(source, t, o)
	o = o or NONE
	if o.t0 and t < o.t0 or o.t1 and t > o.t1 then return end
	local hot = hotOf(self, o.hot)
	local s = emitterSlot(self, o.id or "embers", cfgSpray, o, hot)
	if not s then return end
	local life = o.life or EM_LIFE
	local rate = (o.count or 45) / (0.5 * (life[1] + life[2])) * (hot and 1.7 or 1) * clamp(self.Density, 0.3, 1)
	local p = type(source) == "function" and source(t) or source
	aimPart(s.Part, p, UP)
	if s.rate ~= rate then
		s.rate = rate
		s.Emitter.Rate = rate
	end
	if not s.on then
		s.on = true
		s.Emitter.Enabled = true
	end
end

local function cfgBurst(e, part, o, hot)
	local life, speed, size = o.life or EB_LIFE, o.speed or EB_SPEED, o.size or EB_SIZE
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Lifetime = NumberRange.new(life[1], life[2])
	e.Speed = NumberRange.new(speed[1] * 0.5, speed[2])
	local ang = o.hemi and 80 or 180
	e.SpreadAngle = Vector2.new(ang, ang)
	e.Acceleration = Vector3.new(0, -(o.g or 38), 0)
	e.Drag = o.kd or 3.2
	e.Size = sizeSeq(size[1], size[2])
	e.Rate = 0
end

--- A ONE-SHOT EMBER BURST: fired once per canvas per id, the first time tau >= 0 (not after tau > 0.15: too late)
function Canvas:ember_burst(center, tau, o)
	o = o or NONE
	local life = o.life or EB_LIFE
	if tau < 0 or tau > life[2] then return end
	local id = o.id or "ember_burst"
	local hot = hotOf(self, o.hot)
	local s = emitterSlot(self, id, cfgBurst, o, hot)
	if not s then return end
	if not self.fired[id] then
		self.fired[id] = true
		if tau <= 0.15 then
			local dir = o.hemi or o.bias or UP
			if o.hemi and o.bias then dir = o.hemi + o.bias end
			aimPart(s.Part, center, dir)
			local n = floor((o.count or 72) * (hot and 1.5 or 1) * clamp(self.Density, 0.3, 1) + 0.5)
			s.Emitter:Emit(n)
			local tap = PyroDraw._tapEmit
			if tap then tap(id, center, n) end
		end
	end
end

local function cfgGather(e, part, o, hot)
	local r, life = o.radius or 2, o.life or 0.22
	part.Size = Vector3.new(2 * r, 2 * r, 2 * r)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.Lifetime = NumberRange.new(life * 0.8, life)
	e.Speed = NumberRange.new(r / life * 0.8, r / life)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = ZERO
	e.Drag = 0
	local sz = (o.size or 0.09) * Config.EmberSize
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sz * 0.5), NumberSequenceKeypoint.new(1, sz) })
end

--- ANTICIPATION: sparks drawn IN to pos between t0 and t1 (a charge)
function Canvas:ember_gather(pos, t, t0, t1, o)
	o = o or NONE
	if t < t0 or t > t1 then return end
	local hot = hotOf(self, o.hot)
	local s = emitterSlot(self, o.id or "ember_gather", cfgGather, o, hot)
	if not s then return end
	local rate = (o.rate or 75) * (hot and 1.6 or 1) * clamp(self.Density, 0.3, 1)
	aimPart(s.Part, type(pos) == "function" and pos(t) or pos, UP)
	if s.rate ~= rate then
		s.rate = rate
		s.Emitter.Rate = rate
	end
	if not s.on then
		s.on = true
		s.Emitter.Enabled = true
	end
end

local function cfgField(e, part, o, radius)
	local life, upR, size = o.life or EF_LIFE, o.up or EF_UP, o.size or EF_SIZE
	part.Size = Vector3.new(2 * radius, 0.4, 2 * radius)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.ShapePartial = clamp(o.inner or 0, 0, 1)
	e.Lifetime = NumberRange.new(life[1], life[2])
	e.Speed = NumberRange.new(upR[1], upR[2])
	e.SpreadAngle = Vector2.new(o.cone or 14, o.cone or 14)
	e.Acceleration = Vector3.new(0, -(o.g or -5), 0)
	e.Drag = o.kd or 2.2
	e.Size = sizeSeq(size[1], size[2])
end

--- EMBERS RISING OFF A BURNING DISC (inner = 0) or annulus (the Ring's line: inner 0.92) while you keep calling it
function Canvas:ember_field(center, radius, t, o)
	o = o or NONE
	if o.t0 and t < o.t0 or o.t1 and t > o.t1 then return end
	local s = emitterSlot(self, o.id or "ember_field", cfgField, o, radius)
	if not s then return end
	local life = o.life or EF_LIFE
	local rate = (o.count or 60) / (0.5 * (life[1] + life[2])) * clamp(self.Density, 0.3, 1)
	aimPart(s.Part, center + UP * (o.lift or 1.5), o.normal or UP)
	if s.rate ~= rate then
		s.rate = rate
		s.Emitter.Rate = rate
	end
	if not s.on then
		s.on = true
		s.Emitter.Enabled = true
	end
end

--- embers carried UP the pillar (34-56 studs/s)
function Canvas:pillar_embers(base, tp, o)
	o = o or NONE
	if tp <= 0 then return end
	local kh, kr = (o.height or 36) / 36, (o.radius or 8) / 8
	PE_OPT.id, PE_OPT.count, PE_OPT.inner = o.id or "pillar_embers", (o.count or 110) * 1.3, 0
	PE_OPT.up[1], PE_OPT.up[2] = 34 * kh, 56 * kh
	PE_OPT.size[1], PE_OPT.size[2] = 0.3, 0.7
	self:ember_field(base, 5.5 * kr, tp, PE_OPT)
end

----------------------------------------------------------------------------------------------------
-- THE PIECES (public): one library instance each
----------------------------------------------------------------------------------------------------
--- any library mesh by name at its design origin CFrame, scaled (sx, sy, sz) about that origin
function Canvas:piece(name, origin, sx, sy, sz, o)
	o = o or NONE
	local fam, k = string.match(name, "^PF_(%a+%d?)_(%d+)$")
	local f = fam and FAM[fam]
	if not f then
		warnOnce("piece:" .. tostring(name), "no library mesh '" .. tostring(name) .. "'")
		return
	end
	sy = sy or sx
	sz = sz or sx
	emit(self, famMesh(f, clamp(tonumber(k) or 1, 1, f.n)), origin.Position, origin.XVector, origin.YVector, origin.ZVector, sx, sy, sz,
		tintKey(hotOf(self, o.hot), o.cool))
end

--- the same by FAMILY name ("Flame2", "Spire", ...) and phase (1-based, clamped), at the design origin `pos` on the axes
--- vx, vy (unit, square to each other; vz = vx x vy): no name to parse and no CFrame for the caller to build. For a
--- piece that places hundreds of flames a frame (the Ring).
function Canvas:piece_axes(family, k, pos, vx, vy, sx, sy, sz, o)
	o = o or NONE
	local f = FAM[family]
	if not f then
		warnOnce("piece:" .. tostring(family), "no library family '" .. tostring(family) .. "'")
		return
	end
	sy = sy or sx
	sz = sz or sx
	emit(self, famMesh(f, clamp(k, 1, f.n)), pos, vx, vy, vx:Cross(vy), sx, sy, sz, tintKey(hotOf(self, o.hot), o.cool))
end

--- ONE NESTED FLAME (the kit's flame_nest for one tongue): kind 2 | 3 | "lick"; root, axis (unit), height, belly width
function Canvas:flame(kind, rootP, axis, height, width, o)
	o = o or NONE
	local tint = tintKey(hotOf(self, o.hot), o.cool)
	local t = o.t or self.T
	local ph = o.ph or 0
	if kind == "lick" then
		local d = axis
		if o.lean then d = unit(d + o.lean * Config.LeanK, d) end
		emitLick(self, rootP, d, o.curl_to or o.lean or UP, height, width, o.flat or 1, ph, tint, t)
	else
		emitFlame(self, kind == 3 and F3 or F2, rootP, axis, o.side, height, width, o.flat or 1, ph, tint, t, o.lean)
	end
end

--- ONE ARC PIECE OF A LINE (4 flames + bed): walls, fronts, foot rings. length / height in studs (6 x 3.5 = the mesh)
function Canvas:row(center, tangent, o)
	o = o or NONE
	local h = o.height or Config.RowH
	local sy = h / Config.RowH
	emitRow(self, (o.variant == 2) and ROWB or ROWA, o.flip or false, center, unit(tangent, XAX), o.up or UP,
		(o.length or Config.RowLen) / Config.RowLen, sy, o.thick or sy ^ 0.7, o.ph or 0, tintKey(hotOf(self, o.hot), o.cool), o.t or self.T)
end

function Canvas:strip(a, b, width, o)
	o = o or NONE
	emitStrip(self, a, b, width or 1.3, tintKey(hotOf(self, o.hot), o.cool), o.lift)
end

function Canvas:bulb(rootP, axis, length, width, o)
	o = o or NONE
	emitAxial(self, BULB, rootP, axis, width, length, o.ph or 0, tintKey(hotOf(self, o.hot), o.cool), o.t or self.T)
end

function Canvas:core(rootP, axis, length, width, o)
	o = o or NONE
	emitAxial(self, CORE, rootP, axis, width, length, o.ph or 0, tintKey(hotOf(self, o.hot), o.cool), o.t or self.T)
end

--- A CLOSED RING OF FLAME of `radius` round c (Detonate's circlet, Ember Refund's hoop). thick: its tube's scale
--- (default = radius: the mesh's 0.13 tube); spin (radians) turns its lobes round
function Canvas:hoop(c, radius, t, o)
	o = o or NONE
	local n = o.normal or UP
	local a = perp(n)
	local b = n:Cross(a)
	local sp = o.spin or 0
	local x = a * cos(sp) + b * sin(sp)
	emit(self, famMesh(HOOP, phaseOf(HOOP, t, o.ph or 0)), c, x, n, x:Cross(n), radius, o.thick or radius, radius,
		tintKey(hotOf(self, o.hot), o.cool))
end

--- A ROPE OF FLAME through pts (the whip): one Link per pair of points, `width` across (a number, or fn(i, n) for a
--- taper); the two phases march along the chain (scroll shifts them: t x a rate)
function Canvas:chain(pts, width, t, o)
	o = o or NONE
	local n = #pts
	local tint = tintKey(hotOf(self, o.hot), o.cool)
	local tick = floor(t * Config.FPS + (o.scroll or 0))
	local wfn = type(width) == "function" and width or nil
	for i = 1, n - 1 do
		local a, b = pts[i], pts[i + 1]
		local dv = b - a
		local len = dv.Magnitude
		if len > 0.02 then
			local w = wfn and wfn(i, n) or width
			local z = -dv / len                             -- the Link runs toward its -Z
			local x = perp(z)
			emit(self, famMesh(LINK, (i + tick) % LINK.n + 1), a, x, z:Cross(x), z, w, w, len, tint)
		end
	end
end

--- A COLUMN OF FIRE: tiers that RISE from the base and shrink with the kit's column profile (a flared foot, a top
--- drawn to a point). radius / height: the outer column's. grow: its height 0..1 (the rise), gx: its width
function Canvas:column(base, radius, height, t, o)
	o = o or NONE
	local grow, gx = o.grow or 1, o.gx or 1
	if grow <= 0.02 or radius <= 0.02 then return end
	local K = o.tiers or max(4, floor(Config.ColumnTiers * clamp(self.Density, 0.5, 1) + 0.5))
	local speed = o.speed or 50 * height / 36
	local seed = o.seed or 60
	local flare = o.flare or 0.45
	local sway = o.sway or 1
	local hot = hotOf(self, o.hot)
	local cool0 = o.cool or 0
	local scroll = (t * speed * Config.ColumnRush / height) % 1
	for k = 0, K - 1 do
		local u = (k / K + scroll) % 1
		local rb = radius * gx * max(0, 1 - u ^ 1.8) ^ 0.75
		-- a tier is 2.4 x sy tall and widest a third of the way up: it takes the column's radius THERE
		local sy = (0.6 * rb + 0.25 * radius * gx) * sst(0, 0.5 / K, u)
		local ue = min(1, u + 0.3 * 2.4 * sy / max(height * grow, 1e-3))
		local r = radius * gx * (1 + flare * exp(-u / 0.045)) * max(0, 1 - ue ^ 1.8) ^ 0.75 * Config.ColumnFat
		if r > 0.04 * radius and sy > 0.02 then
			local swa = 0.028 * height * sway * u ^ 1.3
			local ph = rnd(seed, k, 3) * TAU
			local q = TAU * (height * u / (speed / 2.5) - 2.5 * t) + seed
			local p = base + Vector3.new(-swa * sin(q), height * grow * u, swa * cos(q * 0.8 + 0.4))
			local yaw = rnd(seed, k, 5) * TAU + 0.9 * t
			local x = Vector3.new(cos(yaw), 0, sin(yaw))
			local y = unit(UP + x * (Config.ColumnTilt * (rnd(seed, k, 6) * 2 - 1)))
			x = unit(x - y * x:Dot(y), XAX)
			emit(self, famMesh(COLUMN, phaseOf(COLUMN, t, ph)), p, x, y, x:Cross(y), r, sy, r, tintKey(hot, cool0 + 0.45 * u ^ 0.9))
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE KIT'S BUILDERS
----------------------------------------------------------------------------------------------------
--- A FLAME STANDING ON A POINT: breathes at 2.5 Hz, leans (o.lean x its height at the tip), grows with o.grow
function Canvas:standing_flame(pos, height, t, o)
	o = o or NONE
	local g = clamp(o.grow or 1, 0, 1.3)
	if g <= 0.02 or height <= 0.02 then return pos end
	local ph = o.ph or rnd((o.seed or 0) * 131, 4, 7) * TAU
	local W0 = o.width or 0.52 * height
	local H = height * g * (0.82 + 0.18 * breath(t, ph))
	local W = W0 * (0.6 + 0.4 * min(g, 1))
	local layers = o.layers or 2
	local cool = o.cool or 0
	if layers == "cool" then cool += 0.25 end
	local d = o.up or UP
	emitFlame(self, (layers == 2 or layers == "cool") and F2 or F3, pos, d, o.side, H, W, o.flat or 0.62, ph,
		tintKey(hotOf(self, o.hot), cool), t, o.lean)
	return pos + (d + (o.lean or ZERO)) * H
end

local function ptAt(pts, x, n, closed)
	if closed then
		local i = floor(x)
		local f = x - i
		local a, b = pts[(i - 1) % n + 1], pts[i % n + 1]
		return a + (b - a) * f
	end
	x = clamp(x, 1, n)
	local i = min(floor(x), n - 1)
	if i < 1 then return pts[1] end
	return pts[i] + (pts[i + 1] - pts[i]) * (x - i)
end

--- a number | an array per point | fn(i) at the fractional index x
local function valAt(v, x, n, closed, default)
	if v == nil then return default end
	local tv = type(v)
	if tv == "number" then return v end
	local i = floor(x)
	local f = x - i
	local i0, i1
	if closed then
		i0, i1 = (i - 1) % n + 1, i % n + 1
	else
		i0, i1 = clamp(i, 1, n), clamp(i + 1, 1, n)
	end
	local a, b
	if tv == "function" then a, b = v(i0), v(i1) else a, b = v[i0], v[i1] end
	return a + (b - a) * f
end

--- A LINE OF FIRE along pts (about 1.5 studs apart): one Row piece per Config.RowFlames points (two variants, turned
--- and scaled per piece: clumps and saddles), tilted across the line by a travelling wind + lean, the odd tall tongue
--- standing in it, over a burning ground strip. height / grow / lean / tall: a value, an array per point or fn(i).
function Canvas:fire_line(pts, t, o)
	o = o or NONE
	local n = #pts
	if n == 0 then return end
	local closed = o.closed or false
	local height, grow, lean = o.height, o.grow, o.lean
	local seed = o.seed or 7
	local hot = hotOf(self, o.hot)
	local tint = tintKey(hot, o.cool)
	local wind = o.wind or 1
	local vary = o.vary
	if vary == nil then vary = 1 end
	local stripW = o.strip
	if stripW == nil then stripW = 1.3 end
	local tallK = o.tall                       -- the tall tongues' share, 0..1 (a value, an array per point or fn(i)); nil = 1
	if n == 1 then
		self:standing_flame(pts[1], valAt(height, 1, 1, false, 3.5), t, o)
		return
	end
	local span = closed and n or (n - 1)
	local nC = max(1, floor(span / Config.RowFlames + 0.5))
	local kA, kB = max(2, floor(n / 11 + 0.5)), max(3, floor(n / 4.7 + 0.5))
	local phA, phB = rnd(seed + 17, 1, 5) * TAU, rnd(seed + 17, 2, 5) * TAU
	local v1 = min(vary, 1)
	local tall = vary > 0 and self.Density >= 0.75
	for c = 0, nC - 1 do
		local x0, x1 = 1 + span * c / nC, 1 + span * (c + 1) / nC
		local xm = (x0 + x1) * 0.5
		local A, Bp = ptAt(pts, x0, n, closed), ptAt(pts, x1, n, closed)
		local chord = Bp - A
		local len = chord.Magnitude
		if len > 1e-3 then
			local tg = chord / len
			local sd = unit(UP:Cross(tg), XAX)
			local g = clamp((valAt(grow, x0, n, closed, 1) + 2 * valAt(grow, xm, n, closed, 1) + valAt(grow, x1, n, closed, 1)) * 0.25, 0, 1.3)
			local h = valAt(height, xm, n, closed, 3.5)
			if g > 0.02 and h > 0.02 then
				local s = (xm - 1) / n * TAU
				local across = wind * 0.10 * sin(3 * s + TAU * 1.25 * t + 2.0)
				local lv = lean and valAt(lean, xm, n, closed, ZERO) or nil
				if lv then across += lv:Dot(sd) end
				local hm = 1
				if vary > 0 then
					hm = 1 + vary * (0.22 * (0.62 * sin(kA * s + phA) + 0.38 * sin(kB * s + phB)) + 0.10 * (rnd(seed, c, 6) * 2 - 1))
				end
				local ph = rnd(seed, c, 4) * TAU
				local sy = h * hm * g * (0.9 + 0.1 * breath(t, ph)) / Config.RowH
				local fam = (vary > 0 and rnd(seed, c, 9) < 0.5) and ROWB or ROWA
				local rtg, rc = tg, (A + Bp) * 0.25 + ptAt(pts, xm, n, closed) * 0.5
				if vary > 0 then                                                    -- no two pieces stand quite alike
					local yaw = (rnd(seed, c, 15) * 2 - 1) * Config.RowYaw * v1
					rtg = tg * cos(yaw) + sd * sin(yaw)
					rc += sd * ((rnd(seed, c, 8) * 2 - 1) * Config.RowShift * v1)
				end
				emitRow(self, fam, vary > 0 and rnd(seed, c, 10) < 0.5, rc, rtg, UP + sd * (across * Config.RowLean),
					len / Config.RowLen * Config.RowOverlap, sy, (0.6 + 0.4 * min(g, 1)) * (h / Config.RowH) ^ 0.7, ph, tint, t)
				if tall and g > 0.5 and rnd(seed, c, 11) < 0.5 * v1 then           -- the odd tall tongue
					local q = rnd(seed, c, 12)
					local xt = x0 + (x1 - x0) * rnd(seed, c, 13)
					local H = h * (1.45 + 0.5 * q) * g * (0.82 + 0.18 * breath(t, ph * 1.3))
					-- o.tall: the tongue's own share WHERE IT STANDS (the row's height is read at the row's middle)
					if tallK then H = H * clamp(valAt(tallK, xt, n, closed, 1), 0, 1) end
					local wt = wind * (0.26 * sin(2 * s + TAU * 1.25 * t) + 0.12 * sin(5 * s - TAU * 2.5 * t + 1.0))
					local lt = vary * (0.19 * (rnd(seed, c, 14) * 2 - 1) + 0.07 * sin(TAU * 1.25 * t + ph))
					emitFlame(self, q > 0.5 and F3 or F2, ptAt(pts, xt, n, closed), UP, tg, H,
						H * 0.3 + 0.3, 0.62, ph * 1.3, tint, t, tg * (wt + lt) + sd * across)
				end
				if stripW > 0 then emitStrip(self, A, Bp, stripW * min(g, 1), tint, Config.FloorLift + 0.02 * (c % 2)) end
			end
		end
	end
end

--- THE BURNING LINE ON THE GROUND along pts: one Strip per o.step points
function Canvas:ground_strip(pts, o)
	o = o or NONE
	local n = #pts
	if n < 2 then return end
	local closed = o.closed or false
	local width, grow = o.width or 1.3, o.grow
	local tint = tintKey(hotOf(self, o.hot), o.cool)
	local span = closed and n or (n - 1)
	local nC = max(1, floor(span / (o.step or Config.RowFlames) + 0.5))
	for c = 0, nC - 1 do
		local x0, x1 = 1 + span * c / nC, 1 + span * (c + 1) / nC
		local g = clamp(valAt(grow, (x0 + x1) * 0.5, n, closed, 1), 0, 1)
		if g > 0.02 then
			emitStrip(self, ptAt(pts, x0, n, closed), ptAt(pts, x1, n, closed), width * g, tint, Config.FloorLift + 0.02 * (c % 2))
		end
	end
end

--- the source's place `a` seconds ago with the flame's buoyant rise added (the kit's _history)
local function histAt(pos, isFn, t, a, rise, ref)
	local p = isFn and pos(t - a) or pos
	return p + UP * (rise * a * (0.4 + 0.6 * a / ref))
end

--- THE FIREBALL: the Ball (light core + 2 shells), its Tail along the path it took, 3 streamers (HOT 5), 2 lights
function Canvas:fire_ball(pos, t, o)
	o = o or NONE
	local hot = hotOf(self, o.hot)
	local scale = o.scale or 1
	local seed = o.seed or 0
	local span = (o.span or 0.135) * max(o.tail or 1, 0.02) * (hot and 1.3 or 1)
	local sp = max(span, 1e-4)
	if o.t_min then sp = min(sp, max(t - o.t_min, 1e-4)) end
	local isFn = type(pos) == "function"
	local c = isFn and pos(t) or pos
	local dv = histAt(pos, isFn, t, sp, (o.rise or 9) * scale, max(span, 1e-4)) - c
	local L = dv.Magnitude
	local back = L > 1e-4 and dv / L or UP
	if L < 1.2 * scale then L = 1.2 * scale end
	local tint = tintKey(hot, o.cool)
	local ph = seed * 1.3
	local s = scale * (hot and 1.06 or 1)
	emitBall(self, c, back, s, clamp(L / (2.9 * scale), 0.45, 1), ph, tint, t)
	if L > 2.4 * scale then emitTail(self, c + back * (0.3 * scale), back, s, L - 0.3 * scale, ph + 1.9, tint, t) end
	local F = -back
	local streamers = o.streamers
	if streamers == nil then streamers = L > 3 * scale and self.Density >= 0.75 end
	if streamers then
		local nS = hot and 5 or 3
		local sd = unit(F:Cross(UP), XAX)
		local ud = sd:Cross(F)
		local Lk = L / Config.TailLen
		for j = 0, nS - 1 do
			local a = j * TAU / nS + 0.6 + 2.5 * t
			local od = sd * cos(a) + ud * sin(a)
			emitFlame(self, F3, c - F * (0.25 * scale) + od * (0.42 * scale), unit(od * 0.1 - F), nil,
				(5.6 + 1.5 * rnd(seed + 11, j, 0)) * Lk, (0.95 + 0.2 * rnd(seed + 11, j, 1)) * scale, 0.8, rnd(seed + 11, j, 2) * TAU,
				tint, t, UP * 0.07)
		end
	end
	if o.light ~= false then
		local Hh = (hot and 1.45 or 1) * scale * scale
		self:fire_light(c - UP * 0.3, 1500 * Hh * flick(t, seed))
		if L > 3 then self:fire_light(c - F * min(3.5, L * 0.5) - UP * 0.4, 650 * Hh * flick(t, 1 + seed)) end
	end
	return c, F, L
end

--- STREAMING LOBES behind a moving source with no ball (a fist, a whip tip, a dash, an orbiting mote): Tail pieces
--- along the path it took over the last o.span s + a light Core at the head. o.segs: 1 (a straight flight) .. 4 (a
--- swing: the chain bends with the path); default 1 under 20 degrees of turn, else 3
function Canvas:fire_tail(pos, t, o)
	o = o or NONE
	local hot = hotOf(self, o.hot)
	local width = o.width or 1
	local scale = width * 0.5
	local seed = o.seed or 0
	local span = (o.span or 0.2) * (hot and 1.3 or 1)
	local sp = max(span, 1e-4)
	if o.t_min then sp = min(sp, max(t - o.t_min, 1e-4)) end
	local isFn = type(pos) == "function"
	local rise, ref = o.rise or 9, max(span, 1e-4)
	local c = isFn and pos(t) or pos
	local pe = histAt(pos, isFn, t, sp, rise, ref)
	local dv = pe - c
	local L = dv.Magnitude
	local back = L > 1e-4 and dv / L or UP
	local tint = tintKey(hot, o.cool)
	local ph = seed * 1.3
	local K = o.segs
	if not K then
		K = 1
		if isFn and L > 1.2 * scale then
			local pm = histAt(pos, isFn, t, sp * 0.5, rise, ref)
			local d1, d2 = pm - c, pe - pm
			if d1.Magnitude > 1e-3 and d2.Magnitude > 1e-3 and d1.Unit:Dot(d2.Unit) < 0.94 then K = 3 end
		end
	end
	if L < 1.2 * scale then
		L = 1.2 * scale
		K = 1
		pe = c + back * L
	end
	local r0 = scale / 0.92
	if K <= 1 then
		emitTail(self, c - back * (0.1 * L), back, r0, L * 1.1, ph + 1.9, tint, t)
	else
		local a = c
		for k = 1, K do
			local b = histAt(pos, isFn, t, sp * k / K, rise, ref)
			local seg = b - a
			local len = seg.Magnitude
			if len > 1e-3 then
				local dir = seg / len
				emitTail(self, a - dir * (0.2 * len), dir, r0 * (1 - (k - 1) / K) ^ 0.8, len * (k == K and 1.2 or 2.0), ph + 1.9 * k, tint, t)
			end
			a = b
		end
	end
	emitAxial(self, CORE, c - back * (0.25 * scale), back, 1.15 * scale, max(0.55 * L, 1.3 * scale), ph, tint, t)
	if o.light then self:fire_light(c, 420 * (hot and 1.6 or 1) * width * flick(t, seed)) end
	return c, -back, L
end

--- TONGUES THAT PEEL OFF a moving source between t0 and t1 (o.rate per s): left behind, rising, cooling, shrinking
function Canvas:wisps(pos, t, t0, t1, o)
	o = o or NONE
	local hot = hotOf(self, o.hot)
	local life, scale, seed = o.life or 0.4, o.scale or 1, o.seed or 12
	local kd, buoy, out, cool = o.kd or 6, o.buoy or 16, o.out or 0.85, o.cool or 0.3
	local rate = (o.rate or 50) * (hot and 1.6 or 1) * clamp(self.Density, 0.3, 1)
	local lo, hi = max(t0, t - life), min(t, t1)
	if hi < lo or rate <= 0 then return 0 end
	local alive = 0
	local isFn = type(pos) == "function"
	for k = ceil((lo - t0) * rate - 1e-9), floor((hi - t0) * rate + 1e-9) do
		local tb = t0 + k / rate
		local age = t - tb
		local lf = life * (0.55 + 0.45 * rnd(seed, k, 0))
		if age < lf then
			local pb = isFn and pos(tb) or pos
			local vb = isFn and (pb - pos(tb - 1 / 120)) * 120 or ZERO
			local spd = vb.Magnitude
			local Fd = spd > 1e-3 and vb / spd or UP
			local sd = unit(Fd:Cross(UP), XAX)
			local ud = sd:Cross(Fd)
			local a = rnd(seed, k, 1) * TAU
			local od = sd * cos(a) + ud * sin(a)
			local p0 = pb + od * (out * scale * (0.7 + 0.4 * rnd(seed, k, 2))) - Fd * (scale * (0.2 + 0.7 * rnd(seed, k, 3)))
			local v0 = vb * (0.3 + 0.25 * rnd(seed, k, 4)) + od * (3 + 6 * rnd(seed, k, 5)) + UP * (0.5 + 2 * rnd(seed, k, 6))
			local e = 1 - exp(-kd * age)
			local p = p0 + v0 * (e / kd) + UP * ((buoy / kd) * age - (buoy / (kd * kd)) * e)
			local f = age / lf
			local sc = (1 - f) ^ 0.7 * (0.7 + 0.5 * rnd(seed, k, 7)) * scale
			emitLick(self, p, unit(od * 0.5 - Fd + UP * (0.3 + 4 * age)), UP, 1.5 * sc * (1 + 0.6 * f), 0.62 * sc, 1,
				rnd(seed, k, 8) * TAU, tintKey(hot, cool * f), t)
			alive += 1
		end
	end
	return alive
end

--- THE FLAME ON A FIST / PALM: a 3-layer flame that leans against the hand's velocity + small side tongues
function Canvas:hand_flame(pos, t, o)
	o = o or NONE
	local hot = hotOf(self, o.hot)
	local seed = o.seed or 13
	local lag = o.lag or 0.014
	local isFn = type(pos) == "function"
	local c = isFn and pos(t) or pos
	local vel = o.vel or (isFn and (c - pos(t - 0.02)) / 0.02 or ZERO)
	local size = o.size or 1
	local s = max(size, 0.02) * (hot and 1.2 or 1)
	local D0 = unit(UP - vel * 0.02)
	local tint = tintKey(hot, o.cool)
	emitFlame(self, F3, c - D0 * (0.3 * s), D0, nil, 2.9 * s, 1.45 * s, 0.9, 0.7 + seed, tint, t, vel * -lag)
	local nT = floor((o.tongues or 5) * clamp(self.Density, 0.4, 1) + 0.5)
	for j = 0, nT - 1 do
		local od = unit(D0:Cross(runit(j, seed, 0)), XAX)
		emitLick(self, c + od * (0.28 * s), unit(D0 + od * 0.45 - vel * (lag * 2 * Config.LeanK)), UP, (1.0 + 0.7 * rnd(seed, j, 2)) * s, 0.5 * s, 1,
			rnd(seed, j, 3) * TAU, tint, t)
	end
	if o.light ~= false then self:fire_light(c + UP * 0.3, 420 * (hot and 1.6 or 1) * min(size, 1.5) * flick(t, seed)) end
	return c
end

local BURST_SPARKS = { id = nil, seed = 0, count = 0, speed = { 0, 0 }, bias = ZERO, hemi = UP, g = 34, kd = 3.4, life = { 0.2, 0.5 },
	size = { 0.05, 0.13 }, hot = false }

--- THE ROLLING FIREBALL BURST (the kit's r2 burst): the Bulb blown open along `back` then turning upward, the light
--- Core swelling (the flash) then cooling away, 11 licks (HOT 14) thrown round it and swirling one way, torn wisps
--- left rising, a spray of sparks, 2 lights. u = its life 0..1 (0.5 s; keep calling to 1.85). Every length is size / 3.
function Canvas:burst(center, u, o)
	o = o or NONE
	if u < 0 or u > 1.85 then return false end
	local hot = hotOf(self, o.hot)
	local size, seed = o.size or 3, o.seed or 700
	local k = size / 3
	local hk = (hot and 1.14 or 1) * k
	local tau = u * 0.5
	local tw = o.t or tau
	local bdir = unit(o.back or UP)
	local g = eback(tau / 0.09, 1.7)                                       -- the pop (it overshoots)
	local up = sst(0.04, 0.36, tau)                                        -- thrown along `back` first, then upward
	local lift = UP * ((2.4 * tau + 4.0 * tau * tau) * hk)
	local fl = (o.flash ~= false) and equint(tau / 0.035) * (1 - sst(0.05, 0.17, tau)) or 0
	local core_cool = 0.42 * sst(0.05, 0.40, tau)
	local inner = 1 - 0.8 * sst(0.14, 0.42, tau)
	local shell_cool = 0.10 * sst(0.20, 0.50, tau)
	local dens = clamp(self.Density, 0.4, 1)
	-- the body
	local body = g * (1 - sst(0.22, 0.54, tau))
	if body > 0.03 then
		local ax = unit(bdir * (1 - up) + UP * (1.25 * up))
		local Hb = 2.7 * hk * g * (1 + 1.1 * up) * (1 - 0.4 * sst(0.32, 0.54, tau))
		local Rb = 1.4 * hk * body * (1 - 0.2 * up)
		local b0 = center + lift - ax * (0.26 * Hb)
		local ph0 = seed * 1.3
		emitAxial(self, BULB, b0, ax, 2 * Rb, Hb, ph0 + 3.1, tintKey(hot, shell_cool), tw)
		local rk = inner * (1 + 0.5 * fl)
		if Rb * 0.47 * rk > 0.02 * hk then
			emitAxial(self, CORE, b0, ax, 2 * Rb * 0.47 * rk, Hb * 0.58, ph0, tintKey(hot, core_cool), tw)
		end
	end
	-- the licks: a corona thrown out along the surface + a crown thrown along `back`, all swirling one way round
	local nL = hot and 14 or 11
	nL = max(5, floor(nL * dens + 0.5))
	local sd_ = seed + (hot and 9 or 0)
	local ax0 = unit(bdir * (1 - up) + UP * up)
	local f1 = perp(bdir)
	local f2 = bdir:Cross(f1)
	local thr = 1 - exp(-tau / 0.035)
	for j = 0, nL - 1 do
		local az = j * GOLDEN + (rnd(sd_, j, 0) - 0.5) * 1.7 + seed * 0.37
		local crown = j % 3 == 2
		local r1 = rnd(sd_, j, 1)
		local el = crown and (0.85 + 0.45 * r1) or (0.12 + 0.42 * r1)
		local dd = f1 * (cos(az) * cos(el)) + f2 * (sin(az) * cos(el)) + bdir * sin(el)
		local kk = 0.8 + 0.3 * rnd(sd_, j, 2)
		local q, q2 = rnd(sd_, j, 4), rnd(sd_, j, 5)
		local shr = 1 - sst(0.15 + 0.11 * q, 0.38 + 0.15 * q, tau)
		local dz = dd.Y
		local Hh = (crown and (1.5 + 0.9 * q2) or (1.3 + 1.3 * q2 ^ 1.4)) * (1 + 0.3 * dz) * kk * thr * (1 + 0.45 * up) * (0.4 + 0.6 * shr) * hk
		local Wd = (crown and 1.45 or 1.3) * (1 + 0.15 * dz) * kk * min(g, 1.12) * shr ^ 0.8 * (1 - 0.3 * up) * hk
		Wd = min(Wd, 0.62 * Hh)
		if Wd > 0.04 * hk then
			local sw = ax0:Cross(dd)
			local m = sw.Magnitude
			sw = m > 1e-3 and sw / m or sw * 1000
			local D0 = unit(dd * (1 - 0.8 * up) + UP * (0.15 + 0.8 * up) + sw * (0.45 * (1 - 0.6 * up)))
			local P0 = center + dd * (0.42 * kk * min(g, 1.1) * hk) + lift * (0.5 + 0.8 * q)
			emitLick(self, P0, D0, sw * 0.26 + UP * (0.08 + 0.3 * up), Hh, Wd, 0.8, rnd(sd_, j, 3) * TAU,
				tintKey(hot, shell_cool + 0.5 * core_cool * (0.5 + 0.5 * q)), tw)
		end
	end
	-- torn wisps, left hanging and rising
	local nW = floor((hot and 20 or 14) * dens + 0.5)
	local s2 = seed + 20
	for j = 0, nW - 1 do
		local q = rnd(s2, j, 4)
		local kk = 0.75 + 0.35 * rnd(s2, j, 2)
		local age = tau - (0.07 + 0.25 * q)
		local life = 0.32 + 0.24 * kk
		if age > 0 and age < life then
			local dd = runit(j, s2, 0) + bdir * 0.55 + UP * 0.15
			local al = dd:Dot(bdir)
			if al < 0.08 then dd = dd + bdir * ((abs(al) * 0.4 + 0.08) - al) end
			dd = unit(dd)
			local f = age / life
			local P0 = center + dd * ((1.0 + 1.8 * q + 1.2 * age) * hk) + UP * ((0.6 + 3.2 * age + 4 * age * age) * hk)
			local sc = 0.85 * kk * max(0, sin(pi * min(1, f * 1.15 + 0.12))) ^ 0.8 * hk
			emitLick(self, P0, unit(UP + dd * 0.35), dd, 1.4 * sc * (1 + 0.6 * f), 0.6 * sc, 1, rnd(s2, j, 3) * TAU, tintKey(hot, 0.16 * f), tw)
		end
	end
	local ns = o.sparks or floor(16 * k + 0.5)
	if ns > 0 and tau < 0.5 then
		local zk = clamp(sqrt(k), 0.6, 1.7)
		local S = BURST_SPARKS
		S.id, S.count, S.hot = "burst_sparks" .. seed, min(ns, 80), hot
		S.speed[1], S.speed[2], S.g = 6 * hk, 22 * hk, 34 * k
		S.size[1], S.size[2] = 0.05 * zk, 0.13 * zk
		S.bias, S.hemi = bdir * 0.45 + UP * 0.3, bdir
		self:ember_burst(center + bdir * (0.3 * hk), tau, S)
	end
	if o.light ~= false then
		local Hh = (hot and 1.4 or 1) * k * k
		self:fire_light(center + bdir * (1.6 * k) + UP * 0.4, (520 * exp(-tau / 0.12) + 230 * exp(-tau / 0.4)) * Hh * flick(tw))
		local q = center + bdir * (2.2 * k)
		self:fire_light(Vector3.new(q.X, center.Y - k, q.Z), (800 * exp(-tau / 0.15) + 380 * exp(-tau / 0.45)) * Hh)
	end
	return true
end

local function pil_g(tp, delay, dur)
	local x = tp - delay
	if x <= 0 then return 0 end
	return eback(x / dur, 1.2)
end

local COL_OPT = { grow = 1, gx = 1, seed = 60, hot = false, speed = 50, cool = 0 }

--- THE PILLAR (V1's structure): a column of rising tiers, `torn` tongues carried up and inward round it, a ring of
--- foot flames thrown out at the eruption. tp = seconds since the eruption, t = the wave clock.
function Canvas:pillar(base, tp, t, o)
	o = o or NONE
	if tp <= 0 then return end
	local hot = hotOf(self, o.hot)
	local height, radius, seed, rise = o.height or 36, o.radius or 8, o.seed or 60, o.rise or 0.3
	local kh, kr = height / 36, radius / 8
	local tint = tintKey(hot, o.cool)
	local dens = clamp(self.Density, 0.4, 1)
	local g = pil_g(tp, 0.03, rise)
	if g > 0.02 then
		COL_OPT.grow, COL_OPT.gx, COL_OPT.seed, COL_OPT.hot, COL_OPT.speed, COL_OPT.cool = g, 0.55 + 0.45 * min(g, 1), seed, hot, 50 * kh, o.cool or 0
		self:column(base, radius, height, t, COL_OPT)
	end
	local torn = floor((o.torn or 11) * dens + 0.5)
	for j = 0, torn - 1 do
		local f = (tp * (0.9 + 0.5 * rnd(seed, j, 0)) + rnd(seed, j, 1)) % 1
		if tp > f * 0.8 + 0.12 then
			local a = rnd(seed, j, 2) * TAU + 1.3 * tp
			local rad = (5.5 + 3.5 * rnd(seed, j, 3)) * (1 - 0.5 * f) * kr
			local sc = max(0, sin(pi * f)) ^ 0.7
			emitLick(self, base + B(cos(a) * rad, sin(a) * rad, (3.0 + 35.0 * f ^ 0.9) * kh),
				unit(B(cos(a) * 0.2 - sin(a) * 0.3, sin(a) * 0.2 + cos(a) * 0.3, 1)), B(-cos(a), -sin(a), 0),
				(5.5 + 3.5 * rnd(seed, j, 4)) * sc * kh, (2.4 + 0.9 * rnd(seed, j, 5)) * sc * kr, 1, rnd(seed, j, 6) * TAU,
				tintKey(hot, (o.cool or 0) + 0.2 * f), t)
		end
	end
	local foot = o.foot or 22
	if foot > 0 then
		local rb = (7.5 + 6.5 * equint(tp / 0.5)) * kr
		local sc = 1.5 * eback(tp / 0.14, 1.5) * (0.5 + 0.5 * exp(-tp / 0.3)) * kr
		local nR = max(3, floor(foot / Config.RowFlames + 0.5))
		local seg = TAU * rb / nR
		for j = 0, nR - 1 do
			local a = (j + 0.5) * TAU / nR + 0.14 * sin(j * 2.3)
			local rd, tg = B(cos(a), sin(a), 0), B(-sin(a), cos(a), 0)
			local ph = j * 1.9
			emitRow(self, j % 2 == 0 and ROWA or ROWB, rnd(seed + 3, j, 10) < 0.5, base + rd * (rb + 0.6 * sin(j * 1.9)) + UP * 0.05, tg,
				UP + rd * 0.55, seg / Config.RowLen * Config.RowOverlap, 3.9 * sc * (0.85 + 0.15 * breath(t, j * 2.2)) / Config.RowH,
				max(0.4, sc), ph, tint, t)
		end
	end
	if o.light ~= false then
		local gg = min(pil_g(tp, 0, rise), 1.15) * kr * kh
		self:fire_light(base + UP * (4.5 * kh), 17000 * gg * flick(t, 4.5))
		self:fire_light(base + UP * (15 * kh), 12000 * gg * flick(t, 15))
		self:fire_light(base + UP * (27 * kh), 8000 * gg * flick(t, 27))
	end
end

--- A WILDFIRE SPREADING ACROSS A DISC: a front races out from the centre (at `radius` after o.spread s); every flame
--- it passes pops up, stands tall and blown outward, then settles, breathes and leans with a shared wind. One flame
--- per part (one in four a big 3-layer one). -> the front's radius now, flames lit
function Canvas:wildfire(center, radius, tp, t, o)
	o = o or NONE
	if tp <= 0 then return 0, 0 end
	local hot = hotOf(self, o.hot)
	local seed, spread, height = o.seed or 90, o.spread or 0.45, o.height or 7
	local spacing = (o.spacing or 4) / sqrt(clamp(self.Density, 0.35, 1))
	local inner, hold, fade, entrain = o.inner or 0, o.hold, o.fade or 0.4, o.entrain or 0.22
	local N = max(6, floor(pi * radius * radius / (spacing * spacing) + 0.5))
	local front = radius * (1 - (1 - clamp(tp / spread, 0, 1)) ^ 2)
	local tint = tintKey(hot, o.cool)
	local lit = 0
	for i = 0, N - 1 do
		local rad = radius * sqrt((i + 0.5) / N) * (1 + (rnd(seed, i, 1) - 0.5) * 0.14)
		if rad >= inner then
			local rn = clamp(rad / radius, 0, 1)
			local age = tp - spread * (1 - sqrt(1 - rn))
			if age > 0 then
				local g = eback(age / 0.16, 1.5)
				if hold then g = g * (1 - sst(0, fade, tp - hold - fade * 0.8 * (1 - rn))) end
				if g > 0.02 then
					local a = i * GOLDEN + (rnd(seed, i, 0) - 0.5) * 0.6
					local surge = 1 + 0.7 * exp(-age / 0.18)
					local big = i % 4 == 0
					local Hh = height * (0.55 + 0.75 * (1 - rn) ^ 1.2) * (0.78 + 0.44 * rnd(seed, i, 2)) * surge * (big and 1.45 or 1)
					local W = Hh / surge * (0.46 + 0.14 * rnd(seed, i, 3)) * (big and 1.1 or 1)
					local wt = 0.2 * sin(2 * a + TAU * 1.25 * t + rn * 3.0) + 0.1 * sin(5 * a - TAU * 2.5 * t + 1.0)
					local wr = 0.42 * exp(-age / 0.22) - entrain * sst(0.2, 0.6, age) + 0.08 * sin(3 * a + TAU * 1.25 * t + 2.0)
					local rd, tg = B(cos(a), sin(a), 0), B(-sin(a), cos(a), 0)
					local ph = rnd(seed * 977 + i, 4, 7) * TAU
					local gg = min(g, 1.3)
					emitFlame(self, big and F3 or F2, center + rd * rad + UP * 0.05, UP, tg, Hh * gg * (0.82 + 0.18 * breath(t, ph)),
						W * (0.6 + 0.4 * min(gg, 1)), 0.72, ph, tint, t, tg * wt + rd * wr)
					lit += 1
				end
			end
		end
	end
	if o.strip ~= false and tp < spread + 0.12 and front > 0.5 then
		local nS = clamp(ceil(TAU * front / Config.RowLen), 6, 20)
		local w = 1.6 * (1 - sm((tp - spread) / 0.12))
		local a0 = center + B(front, 0, 0.05)
		for k = 1, nS do
			local a = k * TAU / nS
			local a1 = center + B(cos(a) * front, sin(a) * front, 0.05)
			emitStrip(self, a0, a1, w, tint, Config.FloorLift + 0.02 * (k % 2))
			a0 = a1
		end
	end
	local lights = o.lights or 5
	if lights > 0 then
		local lv = sm(tp / max(spread, 1e-3))
		if hold then lv = lv * (1 - sm((tp - hold) / max(fade * 1.8, 1e-3))) end
		self:ground_glow(center, 0.5 * radius, 1.6 * lv, t, 0.3)
		for q = 0, lights - 2 do
			local aq = q * TAU / max(lights - 1, 1) + 0.4
			self:ground_glow(center + B(cos(aq), sin(aq), 0) * (0.6 * radius), 0.45 * radius,
				1.2 * lv * sm((tp - 0.4 * spread) / (0.5 * spread)), t, 1.0 + q)
		end
	end
	return front, lit
end

local BB_PIL = { height = 36, radius = 8, hot = false, seed = 60 }
local BB_WF = { hot = false, seed = 90, spread = 0.45, inner = 0, hold = nil, height = 9, spacing = 4.2 }
local BB_PE = { id = "blast_pillar", height = 36, radius = 8 }
local BB_EF = { id = "blast_field", count = 70, inner = 0 }

--- THE RING OF FIRE'S ERUPTION, sized to the ring: the pillar + a wildfire from its foot out to fill x ring_radius +
--- embers. tp = seconds since the eruption. -> the wildfire's front radius, flames lit
function Canvas:big_blast(center, tp, t, o)
	o = o or NONE
	local R, height, seed = o.ring_radius or 17.5, o.height or 36, o.seed or 60
	local hot = hotOf(self, o.hot)
	local pr = (o.pillar_share or 0.46) * R
	BB_PIL.height, BB_PIL.radius, BB_PIL.hot, BB_PIL.seed = height, pr, hot, seed
	self:pillar(center, tp, t, BB_PIL)
	BB_WF.hot, BB_WF.seed, BB_WF.spread, BB_WF.inner, BB_WF.hold, BB_WF.height = hot, seed + 30, o.spread or 0.45, 0.55 * pr, o.hold, 0.25 * height
	local front, lit = self:wildfire(center, (o.fill or 0.92) * R, tp, t, BB_WF)
	if o.embers ~= false and tp > 0 then
		BB_PE.height, BB_PE.radius = height, pr
		self:pillar_embers(center, tp, BB_PE)
		if lit > 0 then self:ember_field(center, front, tp, BB_EF) end
	end
	return front, lit
end

----------------------------------------------------------------------------------------------------
-- THE DRIVER: one RenderStep for every Play()ed effect, bound only while one lives
----------------------------------------------------------------------------------------------------
local STEP = "SpellshotPyroDraw"
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
				local prevWrap = pendingWrap
				pendingWrap = cv.Wrap            -- a canvas made inside a frame wears its parent's wrap
				local ok, res = pcall(e.Fn, cv, t, dt, e)
				pendingWrap = prevWrap
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

--- frameFn(cv, t, dt, handle) each render frame between Begin / End; return false to end. o: T0 (server time),
--- Offset, Scale, Clock (your own fn), Until (clip s), MaxLife (s), OnEnd(handle), own, hot, maxParts
function PyroDraw.Play(name, frameFn, o)
	o = o or NONE
	local e = setmetatable({
		Name = name or "fx", Fn = frameFn, Canvas = PyroDraw.new(name, o),
		Clock = o.Clock or PyroDraw.Clock(o.T0, o.Offset, o.Scale),
		Until = o.Until, MaxLife = o.MaxLife or Config.MaxLife, Born = os.clock(), OnEnd = o.OnEnd, Dead = false,
	}, Effect)
	live[#live + 1] = e
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP, Config.RenderPriority, driver)
	end
	return e
end

function PyroDraw.StopAll()
	for _, e in ipairs(live) do e.Dead = true end
end

PyroDraw.Lib = LIB

return PyroDraw
