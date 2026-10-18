--[[
	ZephyrGustPad  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrGustPad          Zephyr v6 import, 2026-10-06

	GUST PAD, the Technique pool's Defense half (it REPLACES Deflect Gust: the owner's decision, ROBLOX_IMPORT_PLAN §0).
	Press it and a flat open spiral of air is pressed into the ground at your crosshair; whoever steps on it -- friend or
	foe, the caster too, training dummies too -- is coiled, then launched straight up a column of wind.

	ONE SHARED MODULE, TWO SIDES (the plan's client contract, §5):
	  .Tuning      every number, gameplay and look. ServerScriptService.ZephyrGustPadServer requires this module for it
	               (so the module is INERT on the server: nothing client-side is touched, waited on or bound at require;
	               every other module is found lazily, on first use, and every call into one is pcall-guarded).
	  .Handlers    the broadcasts this piece receives, ("VFX", kind, data) on IceAbilityRemote via AbilityFX (which copies
	               the table once, at load -- it is filled synchronously below):
	                 GustPad       { Caster (character), Position (the pad's floor point), T0 (server time of the press),
	                                 Life, Pad (id), Radius }            the pad: its look starts, the body's press plays
	                 GustPadStep   { Pad, Character, T0, At }            something stepped on: the ripple and the coil
	                                                                     (At = the launch it is coiled toward)
	                 GustPadLaunch { Pad, Character, T0 }                the column, to everyone
	                 GustPadEnd    { Pad, Reason, T0 }                   replaced / spent / expired / cleared: it unwinds
	                 GustPadKnock  { Pad, Speed, Hold, T0 }              to the launched PLAYER alone: their own client
	                                                                     throws their own body (the existing knock pattern:
	                                                                     AbilityFX's AftershockKnock, AquaClient's AquaKnock,
	                                                                     ZephyrHandler's CyclonePull -- the owner moves it)
	  .LocalCast   { GustPad = fn } the keypress, first person: the viewmodel's palm-down press (Viewmodel.Clips.GustPad),
	               and the press's answer wait (below). SpellshotInput calls it as localCast(character, role); the plan
	               wrote (role, character, ability) -- both orders are accepted.
	  .Init(b)     (alias .Bind) SpellshotInput's bindings { Flash, CanCast, AimPoint, BlockedByMovement }: Flash is used
	               to say "refused" on the slot.
	  .Demo(character, opts)   the test harness (ZephyrTestHarness): the v6 reel's WHOLE hero choreography, 1:1 with
	               zs6v_gust_pad.mp4 (gust_pad_bl HERO): the press (CastPose.Clips.GustPad, the kneel) puts the pad 6
	               studs ahead of the caster; a range dummy (a local, client-only blocky figure) walks on, steps on at
	               2.30, coils, is launched at 2.85 and drifts off to land; the caster runs on at 4.99, hops on at 5.57
	               (CastPose.Clips.GustPadRun), is launched at 5.83, lands and is put back where it stood. No server:
	               the caster's own root is anchored and carried for the demo only. The clock honours ZD.TimeScale()
	               (VFXLibrary's ShotTimeScale: the slow-motion capture) or opts.Scale. opts.Freeze = clip seconds
	               holds that one frame (dummy and caster posed there too). Returns { Stop = fn } (.StopDemo() too).
	  .IsActive() / .Interrupt(reason)   ZephyrClient's body contract: true while the launch holds YOUR body
	               (the grab and the rise to the apex); Interrupt lets it go (a Cyclone pull or an Aftershock knock took
	               the body).

	THE PRESS. The row is Targeted (SpellshotInput's generic path sends { Target = aimPoint(Range) }) with Precheck: the
	server snaps the aimed spot to the floor and refuses -- at no cost, in silence -- if there is none. So the press is
	PROVISIONAL here until the server's own GustPad broadcast comes back for this body (Aftershock's arrangement in
	SpellshotInput): left unanswered past max(AnswerWait, 2 x ping + 0.3) the viewmodel clip is let go and the slot
	flashes.

	THE LOOK (blender_scripts/zephyr/aqua/gust_pad_v6.py -> v5 -> v4; the clock, spin and coil are the reviewed spring
	build's Timeline, spring/gust_pad_bl.py: contact 0.14, bloom 0.26). Drawn on IceMagic.ZephyrDraw (the RadiantDraw
	fork, plan §3) on ONE canvas per pad, every frame from the pad's clip clock t = serverNow - T0 (t = 0 is the press,
	as in Blender). The Blender stage is the pad's: its centre C on the floor, +Z up; a pad point (x, y, z) is
	C + (x, z, -y) in Roblox (= ZD.FromStage(CFrame.new(C), x, y, z): a proper rotation, so the kit's counter-clockwise
	spin seen from above stays counter-clockwise). Layers, each the Blender function it ports:
	  v4 pad()        the open spiral: one white-hot core arm + three teal glow arms, flat on the floor, each sweeping
	                  250 degrees out from the eye, blooming out of the centre with an overshoot (form) and spinning on
	                  the integrated spin (theta); the coil pulls them in 38 % and spins them up. 6 pointed arcs whirl
	                  over the eye. A faint vapor ripple breathes out every 1.6 s.
	  v5 pad()        16 tick marks rotating slowly round the rim; the faint shimmer COLUMN over the idle pad (14 studs,
	                  readable from far away) that dips away through a launch; the raised rim of lifted dust.
	  v6 pad()        the idle PULSE ring breathing out every 1.6 s; the step RIPPLE (2 rings, 0.6 s); the second, bigger
	                  and higher vapor ring at each launch; the 8 ribbons PEELING up the column; slowly rising glints.
	  v4 column()     at each launch: the white-hot core line shooting to 18 studs in 0.22 s, 4 glow streaks spiralling
	                  up it, 2 wide vapor sleeves, 10 arcs climbing with it, a vapor ring at its foot (+ v5's bigger one).
	  particles       v4 idle dust circling / puffs drifting up / sparks; v5 rim dust; v6 glints; at each launch v4's
	                  blast (26 dust, 14 chips, 20 sparks, 30 specks) + v5's 18 chips + v6's 16 chips and 18-puff skirt.
	  the light       v6 draw(): one aqua PointLight 1.3 studs over the pad, idle 150-260 W breathing with the pulse,
	                  +380 W on a step (tau 0.2), +1900 W on a launch (tau 0.25), flicker 0.1, range 12.
	The Ribbon/RingK/Sheet/Burst/Light calls are ZephyrDraw's (its header); spans are thinned per element to Look.Spans
	so a pad stays inside Gust Pad's 220-Beam budget at its peak (a launch over an armed pad).

	OWN VIEW (first person). The pad is usually far off, so it is drawn as for everyone, with three own-view rules:
	  * the column's white-hot core line is skipped while the camera is within OwnClearR of the pad's axis (no ribbon
	    down the view axis when you are launched up it);
	  * the shimmer column fades out as the camera comes inside it (OwnColumnFade), so a pad under your feet is not a
	    tube of vapor round your eyes;
	  * your own launch (GustPadKnock) rolls the camera as gust_pad_bl's first-person clip does (0.05 rad at 0.8 Hz,
	    eased in over 0.3 s) through ZD.CameraKick (Camera Shake setting / Reduce Flashing aware).

	NOT LIKE BLENDER. The flow field (Timeline.air) that carries every speck is not run: dust is thrown with a swirl
	velocity and drag instead (it drifts round the rim and settles, it does not orbit). Particles are ParticleEmitter
	bursts (not deterministic), one emitter per particle LOOK (ZephyrDraw allows 10 a canvas): each stream's life and
	size are its emitter's ranges, so the two dust streams share one look and the three launch chip bursts another.
	The pad arcs' spin-up is integrated (Blender multiplied the CLOCK by the speed-up, which whirls them faster the
	later a launch comes; in a 10 s pad that runs away). The shimmer column (v5 Shell 14 x 18, mat_shell) is drawn as
	the shell LOOKS, not as its mesh: a closed emissive shell reads by its two layers and its grazing-angle density, so
	its silhouette edges are its brightest part -- flat Beam bands do the opposite (seen edge-on they thin away; the
	first import's 10-band Sheet vanished in daylight). So: one camera-facing vapor body as wide as the column, and its
	two silhouette edges as thin camera-facing glow lines, each faded at the shell's foot and rim (8 % / 14 %) -- 9
	Beams instead of 30. The pad
	ends (the life, a new pad, eight launches) with a 0.4 s fade -- Blender's clip never ends a pad. The look's clock is
	not slowed by VFXLibrary.ShotTimeScale: the step and launch events are real server seconds.

	EVERY NUMBER IS PROVISIONAL (v6 import). Nothing here has been seen in Play.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZephyrGustPad = {}
ZephyrGustPad.Handlers = {}
ZephyrGustPad.LocalCast = {}

local sin, cos, exp, sqrt, abs, floor, min, max, pi = math.sin, math.cos, math.exp, math.sqrt, math.abs, math.floor,
	math.min, math.max, math.pi
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)

----------------------------------------------------------------------------------------------------
-- TUNING (shared with ZephyrGustPadServer)
----------------------------------------------------------------------------------------------------
local T = {
	-- THE GAMEPLAY (the server's). The row (VFXLibrary: Cooldown 14, ManaCost 20, Targeted, Range 40, Precheck) is
	-- INTEGRATION's; the server reads the row's Range first and falls back to Range here.
	Range = 40,                 -- PROVISIONAL (v6 import) -- studs from the caster's root to the aimed spot
	RangeSlack = 4,             -- PROVISIONAL (v6 import) -- the server's copy of the root trails the client's a little
	FloorUp = 2,                -- the floor ray starts this far over the aimed spot (Cyclone's groundUnder rule)
	FloorDrop = 40,             -- PROVISIONAL (v6 import) -- and looks this far down for a floor: none = refused, no cost
	MinFloorUp = 0.55,          -- PROVISIONAL (v6 import) -- a floor's Normal.Y at least this (~57 degree slope at most)
	ArmTime = 0.26,             -- PROVISIONAL (v6 import) -- the bloom (gust_pad_bl HERO bloom 0.26): armed this long after the press
	Life = 10,                  -- PROVISIONAL (v6 import) -- seconds from the press
	Radius = 3.4,               -- PROVISIONAL (v6 import) -- RP: an R15 footprint is ~2 x 1, so a step from any side lands on it
	StepAbove = 3,              -- PROVISIONAL (v6 import) -- a body's FEET at most this high over the pad's floor...
	StepBelow = 1.5,            -- PROVISIONAL (v6 import) -- ...and at most this far under it (a pad pressed onto a lip)
	Coil = 0.26,                -- PROVISIONAL (v6 import) -- step -> launch: the pull in (0.16) + the hold (0.10), the caster's
	                            --   hop-on in gust_pad_bl (land2 5.57 -> launch2 5.83). 0 = launched on the step
	CoilSlack = 4,              -- PROVISIONAL (v6 import) -- further than Radius + this from the centre at the launch = escaped
	                            --   (a dash out of the coil); anything walking or jumping is still thrown
	ApexHeight = 19,            -- PROVISIONAL (fixed 2026-10-07) -- studs a launch rises: the showcase's straight-up pop of ~4 body
	                            --   heights. The launch SPEED is derived from this and workspace.Gravity (LaunchSpeed below),
	                            --   never written as studs/s: the v6 import's fixed 85 studs/s was tuned for 196.2 but this
	                            --   place's Gravity is 64, so it threw the playtest's caster ~60 studs up (a dummy 56) and hung
	                            --   them ~2.7 s -- long enough for a held W to carry them ~95 studs on.
	GrabTime = 0.05,            -- PROVISIONAL (v6 import) -- s the launched body's mover holds the speed (the air grabbing it,
	                            --   so the Humanoid's floor hold cannot eat the first frames); LaunchSpeed allows for it
	KeepFlat = 1 / 3,           -- PROVISIONAL (fixed 2026-10-07) -- the share of the horizontal velocity a launch keeps...
	MaxFlat = 8,                -- PROVISIONAL (fixed 2026-10-07) -- ...and never more than this, studs/s. The pop barely drifts
	                            --   in the showcase; keeping a sprint's 25 (or a slide jump's 70) whole is what flung bodies
	                            --   across the map. A launched PLAYER is held to MaxFlat through the RISE as well (their air
	                            --   steering works inside it), and is theirs again from the apex (see THE KNOCK).
	KnockForcePerMass = 2000,   -- PROVISIONAL (v6 import) -- the mover's force per unit of mass (Aqua / Terra hold 1400)
	Lockout = 1.0,              -- PROVISIONAL (v6 import; fixed 2026-10-07) -- s a body stands on the pad before it is launched
	                            --   again, counted from its LANDING (the server's estimate: LaunchSpeed's flight time). From the
	                            --   launch, as before, it ran out mid-air (a flight is ~1.6 s) and did nothing at all: a body
	                            --   came down on the pad and was thrown again with no breather to step off.
	MaxLaunches = 8,            -- PROVISIONAL (v6 import) -- then the pad is spent
	ScanInterval = 1 / 30,      -- s between the server's checks for bodies on a pad
	AnswerWait = 0.6,           -- s: the press waits max(this, 2 x ping + 0.3) for its GustPad before it is called refused

	-- THE LOOK (gust_pad_v4/v5/v6.py; numbers quoted as the kit has them)
	Look = {
		Contact = 0.14,           -- the palm meets the floor (the press clips' Trigger)
		Bloom = 0.26,             -- the pad whirls out of its eye (= ArmTime)
		Theta0 = 0.9,             -- the spiral's angle at the bloom (Timeline: th starts at 0.9)
		FadeOut = 0.4,            -- s the idle layers take to unwind at the pad's end (not in Blender)
		Pulse = 1.6,              -- PER: the idle pulse period (v6) and the floor ripple's (v4)
		ArmSweep = math.rad(250), -- each spiral arm's sweep from the eye to the rim
		ArmLift = 0.06,           -- the core arm over the floor (each glow arm +0.02)
		CoreW = 0.16,             -- the core arm's width (v4; the spring build's 0.34 was the white-only pass)
		-- Beam spans per element. The peak (a launch over an armed pad, a step ripple still running) is about
		-- arms 4x6 + pad arcs 6x3 + ticks 16 + column 3x3 + col streaks 4x6 + sleeves 2x4 + col arcs 10x2 + peel 8x6
		-- + core 1 + 6 rings (the engine's spans) ~ 195-210 Beams, inside Gust Pad's 220 (the peel's 220-degree helices need 6).
		Spans = { Arm = 6, PadArc = 3, ColArc = 2, Streak = 6, Sleeve = 4, Peel = 6 },
		-- the shimmer column (v5: r = 1.5 + 0.04 z up to 14 studs, its foot fading in over 8 % and its rim out over the top
		-- 14 %, mat_shell alpha 0.2): a camera-facing body + its two silhouette edges (see NOT LIKE BLENDER)
		Column = { Height = 14, R0 = 1.5, Rk = 0.04, Rows = { 0, 0.08, 0.86, 1 },
			BodyKind = "vapor", BodyAlpha = 0.3, BodyGlow = 0.45,
			EdgeKind = "glow", EdgeW = 0.32, EdgeAlpha = 0.35, EdgeGlow = 0.6 },
		StreakKind = "glow",      -- the column's 4 spiralling streaks (gust_pad_v4 col_g: mat_wind("glow"))
		PeelN = 8,                -- NPEEL
		OwnClearR = 1.6,          -- own view: the column's core line is skipped this close to its axis
		OwnColumnFade = { 1.0, 2.6 },   -- own view: the shimmer column fades in from this flat distance to that
		-- own view: your own launch rolls the camera as gust_pad_bl's fp clip does -- 0.05 sin(2 pi 0.8 (t - L)), eased in
		-- over 0.3 s, to the clip's end (L + 0.76)
		OwnLaunchKick = { roll = 0.05, osc = 2 * math.pi * 0.8, phase = 0, rise = 0.3, hold = 0.46, decay = 0.3 },
		Light = { Lift = 1.3, Idle = 150, Breath = 110, Step = 380, StepTau = 0.2, Launch = 1900, LaunchTau = 0.25,
			Flicker = 0.1, Range = 12 },
		-- particles: the kit's emission (period s, from s), spawn and throw; the flow field becomes Swirl / Inflow / Lift
		-- (studs/s at the spawn) + Drag. ONE LOOK PER STREAM: ZephyrDraw gives a canvas Config.MaxEmitters (10) emitters,
		-- one per particle look (kind, Life range, Size range, Drag...), and each particle's life and size are drawn from
		-- its emitter's ranges. So the two dust streams share one look (life 0.7-1.5: v4's idle 0.9-1.5 and v5's rim
		-- 0.7-1.1 together) and the three launch chip bursts another (0.8-1.5) -- 9 emitters a pad in all.
		DustLook = { Life = { 0.7, 1.5 }, Size = { 0.5, 0.9 }, Drag = 2.5 },
		IdleDust = { Period = 0.12, From = 0.3, R = { 0.6, 1.0 }, Y = 0.15, Swirl = 3.5, Inflow = 0.8, Lift = 1.6 },
		RimDust = { Period = 0.08, From = 0.35, R = { 1.0, 1.15 }, Y = 0.15, Rise = 1.6, Swirl = 3.0 },
		IdlePuff = { Chance = 0.5, Sigma = 0.8, Y = 0.3, Rise = 1.4, Swirl = 1.0,
			Look = { Life = { 0.8, 1.4 }, Size = { 0.35, 0.7 }, Drag = 0.5 } },
		IdleSpark = { Chance = 0.3, Sigma = 1.2, Y = { 0.3, 1.5 }, Rise = 1.0,
			Look = { Life = { 0.5, 0.5 }, Size = { 0.4, 0.7 } } },                  -- Drag nil: the kind's own (za KINDS)
		Glint = { Kind = "spark", Period = 0.11, From = 0.4, R = { 0.2, 1.4 }, Y = { 0.2, 1.5 }, Drift = 0.3,
			Rise = { 1.2, 2.4 }, Look = { Life = { 1.8, 3.0 }, Size = { 0.25, 0.45 } } },  -- v6 P4("glint", "spark")
		-- each launch: { kind, at height, count, speed, life, up, size }
		LaunchBursts = {
			{ "dust", 0.3, 26, { 10, 20 }, { 0.8, 1.5 }, 0.03, { 0.9, 1.7 } },     -- v4 blast
			{ "chip", 0.3, 14, { 7, 14 }, { 0.8, 1.5 }, 0.7 },                     -- v4 (life 0.8-1.3: one chip look)
			{ "spark", 1.5, 20, { 6, 15 }, { 0.3, 0.8 }, 0.8 },                    -- v4
			{ "speck", 0.2, 30, { 12, 22 }, { 0.3, 0.6 }, 0.05 },                  -- v4
			{ "chip", 0.3, 18, { 9, 18 }, { 0.8, 1.5 }, 0.6 },                     -- v5 chip2 (life 0.8-1.4)
			{ "chip", 0.3, 16, { 10, 20 }, { 0.8, 1.5 }, 0.7 },                    -- v6 chip6
			{ "puff", 0.4, 18, { 5, 9 }, { 0.5, 0.9 }, -0.25, { 1.2, 2.0 } },      -- v6 puff skirt
		},
		MaxTicksPerFrame = 6,     -- a hitch never floods a stream
		-- THE DEMO: gust_pad_bl HERO (the v6 reel's clip), stage studs from the caster's feet, the caster facing +Y
		Demo = {
			C = { 0, 6 },                         -- the pad, 6 studs ahead of the caster
			Step1 = 2.30, Launch1 = 2.85,         -- the range dummy steps on, coils (a 0.45 s pull + a 0.10 s hold), is launched
			Run0 = 4.99, Takeoff = 5.39, Land2 = 5.57, Launch2 = 5.83,   -- the caster runs on, hops on, is launched
			RunClip = 4.69,                       -- CastPose.Clips.GustPadRun's t = 0 (Run0 - 0.3, Caster.run's first key)
			V0 = 30, G = 28.6, Tau = 0.035,       -- gust_pad_bl flight(): apex ~15.7 studs (three body heights) at ~1.05 s
			Restore = 8.7,                        -- the caster has landed (~7.9) and stood: it is put back where it was
			Life = 10,
			Dummy = {
				RootT = { 1.52, 1.78, 2.04, 2.30, 2.55 },     -- hero_rig's walk-on (root keys)
				RootXY = { { 0.9, 12.7 }, { 0.75, 11.3 }, { 0.6, 9.8 }, { 0.42, 8.1 }, { 0.25, 6.7 } },
				Drift = 4.6,                      -- studs/s it drifts on, away from the caster, once airborne (softplus)
				Color = Color3.fromRGB(234, 221, 184),        -- zk DUMMY #EADDB8
				Thigh = 0.92, Shin = 1.04, Arm = 2.3,         -- zk SEG (the shin carries the 0.12 ankle: hip 1.96)
			},
		},
	},
}
ZephyrGustPad.Tuning = T

-- THE LAUNCH'S ARITHMETIC, shared: the server sizes every launch with it and estimates the landing; a client damps its
-- own body with KeptFlat. Plain math on workspace.Gravity, so it is safe at require on either side.

--- studs/s straight up for an apex of ApexHeight at this place's gravity. The mover holds the speed for GrabTime first
--- (it rises speed x GrabTime), then the body coasts up speed^2 / 2g: speed x h + speed^2 / 2g = A, solved for speed.
function ZephyrGustPad.LaunchSpeed()
	local g, h, A = workspace.Gravity, T.GrabTime or 0, T.ApexHeight
	if not (g > 0 and A > 0) then return 50 end              -- a zero-gravity test place: a sane pop, not a divide
	return g * (math.sqrt(h * h + 2 * A / g) - h)
end

--- seconds from the launch to landing back at the pad's height (the hold, the rise, the fall from the apex)
function ZephyrGustPad.FlightTime(speed)
	local g, h = workspace.Gravity, T.GrabTime or 0
	if not (g > 0) then return 2 end
	local apex = speed * h + speed * speed / (2 * g)
	return h + speed / g + math.sqrt(2 * apex / g)
end

--- the horizontal velocity a launch keeps of `v`: KeepFlat of it, at most MaxFlat (a straight-up pop, not a fling)
function ZephyrGustPad.KeptFlat(v)
	local flat = Vector3.new(v.X, 0, v.Z) * T.KeepFlat
	if flat.Magnitude > T.MaxFlat then flat = flat.Unit * T.MaxFlat end
	return flat
end
local LK = T.Look

----------------------------------------------------------------------------------------------------
-- MATHS (pyro_kit / zk / gust_pad_bl curves, identical)
----------------------------------------------------------------------------------------------------
local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function ease(u)                   -- smoothstep
	u = clamp01(u)
	return u * u * (3 - 2 * u)
end

local function ease_out(u)               -- cubic out
	u = clamp01(u)
	return 1 - (1 - u) ^ 3
end

local function span(t, a, b)
	if b > a then return clamp01((t - a) / (b - a)) end
	return (t >= b) and 1 or 0
end

local function smoothR(x, a, b)          -- zk.smooth(x, a, b): smoothstep over [a, b]
	local u = clamp01((x - a) / (b - a))
	return u * u * (3 - 2 * u)
end

local function back(u, s)                -- zk.back: ease out with overshoot
	s = s or 1.70158
	u = clamp01(u) - 1
	return u * u * ((s + 1) * u + s) + 1
end

--- a point on the pad's stage: polar (r, a) in the floor plane, y up, round the centre C (Blender (r cos a, r sin a, y))
local function at(C, r, a, y)
	return C + Vector3.new(r * cos(a), y, -r * sin(a))
end

--- RANDOMNESS: RadiantDraw's integer hash (lowbias32), copied -- identical on every client, no Random objects
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
local function rand(a, b, c, k)
	local h = mix(mix(mix(floor(a) % TWO32) + floor(b) % TWO32) + floor(c) % TWO32)
	return mix(h + (k or 1) * 0x9E3779B9) / TWO32
end
local function uni(lo, hi, a, b, c, k)
	return lo + (hi - lo) * rand(a, b, c, k)
end
local function gauss(sigma, a, b, c, k)  -- Box-Muller
	local u1 = max(rand(a, b, c, k), 1e-9)
	local u2 = rand(a, b, c, k + 7919)
	return sigma * sqrt(-2 * math.log(u1)) * cos(TAU * u2)
end

local function perpAny(v)                -- RadiantDraw basis()'s rule
	local a = (abs(v.Y) < 0.9) and UP or Vector3.new(-1, 0, 0)
	return v:Cross(a).Unit
end

----------------------------------------------------------------------------------------------------
-- MODULES, found lazily (never at require: this module is required on the server for its Tuning)
----------------------------------------------------------------------------------------------------
local iceFolder = script.Parent
local mods = {}
local function need(name)
	if mods[name] ~= nil then return mods[name] or nil end
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = (iceFolder and iceFolder:FindFirstChild(name)) or (spell and spell:FindFirstChild(name))
	if not m then return nil end                       -- not there YET (ZephyrDraw is pushed separately): ask again later
	local ok, mod = pcall(require, m)
	mods[name] = (ok and mod) or false
	if not ok then warn("[ZephyrGustPad] " .. name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrGustPad] " .. tostring(msg))
end

--- module.fn(...), guarded: a missing module or function, or an error in it, does nothing
local function call(modName, fn, ...)
	local M = need(modName)
	local f = M and M[fn]
	if type(f) ~= "function" then return nil end
	local ok, res = pcall(f, ...)
	if not ok then
		warnOnce(modName .. ":" .. fn, modName .. "." .. fn .. " failed: " .. tostring(res))
		return nil
	end
	return res
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function validNumber(x)
	return type(x) == "number" and x == x and abs(x) < 1e12
end

----------------------------------------------------------------------------------------------------
-- THE PAD'S CLOCK (gust_pad_bl.Timeline, per pad: its events arrive as broadcasts)
----------------------------------------------------------------------------------------------------
-- pad.Steps = { { S, L } }  clip seconds: a body stepped on at S and is coiled toward a launch at L (= S + Coil)
-- pad.Launches = { L }       clip seconds of the launches that happened, ascending

--- the bloom's radius scale: whirls out from the eye with an overshoot, then settles (follow-through)
local function form(t)
	if t <= LK.Bloom then return 0.14 end
	return 0.14 + 0.86 * back(span(t, LK.Bloom, LK.Bloom + 0.62), 1.5)
end

--- the anticipation hold at the end of the coil (0.10 s; less on a short hop-on)
local function holdLen(S, L)
	return min(0.10, 0.4 * (L - S))
end

--- 1 = armed. Each launch spends the pad (its air goes up the column); it re-arms ~1.7 s later.
local function charge(pad, t)
	local c = 1
	for _, L in ipairs(pad.Launches) do
		if t >= L - 0.02 then
			local dip = ease(span(t, L - 0.02, L + 0.16)) * (1 - ease(span(t, L + 0.95, L + 1.75)))
			c = min(c, 1 - 0.78 * dip)
		end
	end
	return c
end

--- the coil: a visible inward pull (ease over the step's window less the hold), then let go at the launch. Several
--- bodies coiling at once take the strongest (Blender pairs them in order: one at a time).
local function tight(pad, t)
	local best = 0
	for _, e in ipairs(pad.Steps) do
		local S, L = e[1], e[2]
		local v = 0
		if S <= t and t < L then
			v = ease(span(t, S, L - holdLen(S, L)))
		elseif L <= t and t < L + 0.10 then
			v = 1 - ease(span(t, L, L + 0.10))
		end
		if v > best then best = v end
	end
	return best
end

--- 1 during the anticipation hold: the spin stalls (the coil before the launch)
local function hold(pad, t)
	local best = 0
	for _, e in ipairs(pad.Steps) do
		local S, L = e[1], e[2]
		if S <= t and t < L + 0.03 then
			local h0 = L - holdLen(S, L)
			local v = ease(span(t, h0 - 0.03, h0 + 0.03)) * (1 - ease(span(t, L - 0.005, L + 0.03)))
			if v > best then best = v end
		end
	end
	return best
end

--- the pad's spin, rad/s, counter-clockwise from above
local function omega(pad, t)
	if t < LK.Bloom - 0.06 then return 0 end
	local rev = 0.40 + 1.7 * exp(-max(0, t - LK.Bloom) / 0.30)
	rev += 1.6 * tight(pad, t) * (1 - 0.5 * hold(pad, t))
	for _, L in ipairs(pad.Launches) do
		if t >= L then rev += 1.4 * exp(-(t - L) / 0.35) end
	end
	return TAU * rev * (0.45 + 0.55 * charge(pad, t))
end

-- theta (the spiral's angle) and the pad arcs' phase are INTEGRALS of the spin. They are integrated here at a fixed
-- 240 Hz from the bloom on, with a checkpoint every CK_EVERY s; an event that arrives for a time already passed (a
-- broadcast is a ping late) rewinds to the last checkpoint before it and integrates again from there -- so every client
-- lands on the same angle whatever its frame rate or latency, and a launch costs ~0.3 s of re-integration, not 10 s.
local INT_H = 1 / 240
local CK_EVERY = 0.25

--- an event changes the spin from `t` on (a step at S, a launch from L - 0.02): rewind there on the next frame
local function dirtyFrom(pad, t)
	pad.DirtyFrom = min(pad.DirtyFrom or math.huge, t)
end

--- back to the last checkpoint at or before `t` (the ones after it are dropped)
local function rewind(pad, t)
	local ck = pad.Ck
	local k = #ck
	while k > 1 and ck[k][1] > t do
		ck[k] = nil
		k -= 1
	end
	pad.IntT, pad.Th, pad.ArcPh = ck[k][1], ck[k][2], ck[k][3]
end
local function advance(pad, t)
	local t0 = LK.Bloom - 0.06
	if pad.Ck == nil then
		pad.Ck = { { t0, LK.Theta0, t0 } }
		pad.IntT, pad.Th, pad.ArcPh = t0, LK.Theta0, t0
	end
	local df = pad.DirtyFrom
	if df then
		pad.DirtyFrom = nil
		if df < pad.IntT then rewind(pad, df) end
	end
	if t < pad.IntT then rewind(pad, t) end                  -- a clock that went back (a demo frozen earlier)
	if t <= t0 then
		pad.ThNow, pad.ArcNow = LK.Theta0, t
		return
	end
	local n = 0
	while pad.IntT + INT_H <= t and n < 4000 do
		local m = pad.IntT + INT_H * 0.5
		pad.Th += omega(pad, m) * INT_H
		pad.ArcPh += (1 + 2 * tight(pad, m)) * INT_H        -- the pad arcs spin up 3x with the coil
		pad.IntT += INT_H
		n += 1
		local ck = pad.Ck
		if pad.IntT - ck[#ck][1] >= CK_EVERY - 1e-9 then ck[#ck + 1] = { pad.IntT, pad.Th, pad.ArcPh } end
	end
	local rem = max(0, t - pad.IntT)
	local m = pad.IntT + rem * 0.5
	pad.ThNow = pad.Th + omega(pad, m) * rem
	pad.ArcNow = pad.ArcPh + (1 + 2 * tight(pad, m)) * rem
end

--- the latest launch whose window [L + a, L + b] holds t, or nil
local function launchIn(pad, t, a, b)
	local L = pad.Launches
	for i = #L, 1, -1 do
		if L[i] + a <= t and t <= L[i] + b then return L[i] end
	end
	return nil
end

--- the idle tell's presence: it dips away through each launch (its air goes up the column), v6 idle_k
local function idleK(pad, t)
	local L = launchIn(pad, t, -0.2, 1.2)
	local k = min(1, form(t))
	if L then k *= 1 - sin(pi * clamp01((t - L + 0.2) / 1.4)) end
	return k
end

----------------------------------------------------------------------------------------------------
-- THE LOOK
----------------------------------------------------------------------------------------------------
-- Per-pad scratch (points, widths, side vectors, option tables) is kept on the pad and refilled each frame, one set per
-- element, so a frame allocates only its Vector3s and no element can see another's arrays.
-- the element keys, made once (a key built per frame would be a string per element per frame)
local function keys(prefix, n)
	local out = {}
	for i = 0, n - 1 do out[i] = prefix .. i end
	return out
end
local ARM_KEYS, TICK_KEYS, SRIP_KEYS = keys("arm", 4), keys("tick", 16), keys("srip", 2)
local COLG_KEYS, COLV_KEYS, PEEL_KEYS = keys("colg", 4), keys("colv", 2), keys("peel", 16)

local function buf(pad, key, n)
	local b = pad.Buf[key]
	if not b then
		b = { P = table.create(n), W = table.create(n), S = table.create(n), A = table.create(n), O = {} }
		pad.Buf[key] = b
	end
	return b
end

--- za.Arcs(n, seed, r, span, w, speed, tilt): each arc's own radius, span, speed, width, glow and phase (hashed)
local function makeArcs(seed, padSeed, n, r, spanDeg, w, speed, tilt)
	local out = {}
	local b0 = perpAny(UP)
	local b1 = UP:Cross(b0)
	for i = 1, n do
		local function u(lo, hi, k) return uni(lo, hi, seed, padSeed, i, k) end
		local choice = rand(seed, padSeed, i, 4)
		local t0, t1 = gauss(tilt, seed, padSeed, i, 6), gauss(tilt, seed, padSeed, i, 8)
		local N = (UP + b0 * t0 + b1 * t1).Unit
		local d0 = perpAny(N)
		out[i] = {
			R = u(r[1], r[2], 1), Span = math.rad(u(spanDeg[1], spanDeg[2], 2)),
			W = u(w[1], w[2], 3) * ((choice < 2 / 3) and 1 or 1.7),
			Spd = u(speed[1], speed[2], 5), Ph = u(0, TAU, 9),
			Glow = u(0.7, 1.5, 10), Alpha = u(0.35, 0.8, 11), Flick = u(0, TAU, 12), Rise = u(-0.25, 0.25, 13),
			N = N, D0 = d0, D1 = N:Cross(d0),
			BP = {}, BW = {}, BO = {},                    -- this arc's own scratch (W is its width)
		}
	end
	return out
end

--- za.Arcs.draw (axis up, spin +1): the head leads, the tail trails behind; `phase` is the spin clock
local function drawArcs(cv, arcs, t, phase, c, fade, scale, spans)
	if fade <= 0.003 then return end
	local n = spans + 1
	for i, a in ipairs(arcs) do
		local P, W, o = a.BP, a.BW, a.BO
		local a0 = a.Ph + a.Spd * phase
		local R = a.R * scale
		for j = 1, n do
			local s = (j - 1) / (n - 1)
			local ang = a0 - a.Span * s
			P[j] = c + (a.D0 * cos(ang) + a.D1 * sin(ang)) * R + a.N * (s * a.Rise * R)
			W[j] = a.W * scale * sin(pi * clamp01(s * 0.92 + 0.04)) ^ 0.7 * (1 - 0.65 * s)
		end
		o.fade = fade * (0.75 + 0.25 * sin(t * 9 + a.Flick))
		o.glow, o.alpha, o.tail, o.maxSpans = a.Glow, a.Alpha, 0.55, spans
		cv:Ribbon(P, W, "arc", o)
	end
end

--- za.ring: a closed flat ring in the floor plane (RingK; a closed flat Ribbon if the engine has none)
local function ring(pad, cv, key, c, r, width, kind, fade, alpha, glow, tt)
	if fade <= 0.003 or r <= 0 then return end
	local b = buf(pad, key, 17)
	local o = b.O
	o.fade, o.alpha, o.glow, o.t = fade, alpha, glow, tt     -- tt: za's t + phase (nil: the canvas clock)
	if cv.RingK then
		cv:RingK(c, r, UP, width, kind, o)
		return
	end
	local P, S = b.P, b.S
	for j = 1, 17 do
		local a = (j - 1) / 16 * TAU
		local d = Vector3.new(cos(a), 0, -sin(a))
		P[j], S[j] = c + d * r, d
	end
	o.side, o.maxSpans = S, 8
	cv:Ribbon(P, width, kind, o)
end

--- particles and the light are guarded one by one: a kind the engine refuses must not take the ribbons down with it
--- (the driver ends an effect whose frame errors)
local function burst(cv, kind, pos, n, o)
	if not cv.Burst then return end
	local ok, err = pcall(cv.Burst, cv, kind, pos, n, o)
	if not ok then warnOnce("burst:" .. kind, "cv:Burst(" .. kind .. ") failed: " .. tostring(err)) end
end

--- A continuous kit emission (one spawn every `period` s from `from` until the pad's end) fired as single bursts: fn(i)
--- for every tick crossed since the last frame (capped, so a hitch never floods).
local function stream(pad, name, t, from, period, untilT, fn)
	local upto = floor((min(t, untilT) - from) / period)
	local last = pad.Ticks[name]
	if last == nil then last = upto - 1 end              -- a late join starts here, it does not replay the past
	if upto <= last then return end
	if upto - last > LK.MaxTicksPerFrame then last = upto - LK.MaxTicksPerFrame end
	for i = last + 1, upto do
		if i >= 0 then fn(i) end
	end
	pad.Ticks[name] = upto
end

--- one particle thrown with a velocity (the flow field's swirl at its spawn, then drag)
--- one stream's options: its LOOK (life / size ranges, drag: one emitter) fixed, its throw set per particle
local function streamOpt(pad, name, look)
	local o = pad.SO[name]
	if not o then
		o = { life = look.Life, size = look.Size, drag = look.Drag, cone = 0, up = 0, speed = { 0, 0 } }
		pad.SO[name] = o                                      -- (drag nil = the kind's own: za's KINDS)
	end
	return o
end

local function throw(cv, kind, pos, v, o, id)
	local sp = v.Magnitude
	o.dir = sp > 1e-4 and v / sp or UP
	o.speed[1], o.speed[2] = sp, sp
	o.id = id
	burst(cv, kind, pos, 1, o)
end

--- the swirl / inflow / lift of the pad's air at a floor point (CCW from above), studs/s
local function airAt(C, p, swirl, inflow, lift)
	local d = Vector3.new(p.X - C.X, 0, p.Z - C.Z)
	local r = d.Magnitude
	if r < 1e-4 then return UP * lift end
	local radial = d / r
	local tangent = Vector3.new(radial.Z, 0, -radial.X)   -- (-sin, cos) in the pad's plane = counter-clockwise
	return tangent * swirl - radial * inflow + UP * lift
end

local function drawPad(pad, cv, t)
	local C, RP = pad.C, pad.Radius
	advance(pad, t)
	local th = pad.ThNow
	local fRaw = form(t)
	local endK = 1 - span(t, pad.EndT, pad.EndT + LK.FadeOut)
	local f = min(1, fRaw) * endK
	local ti = tight(pad, t)
	local cam = workspace.CurrentCamera
	local camFlat = math.huge
	local camSide = Vector3.new(1, 0, 0)                  -- flat, across the view: where the column's silhouette edges sit
	if cam then
		local d = cam.CFrame.Position - C
		camFlat = sqrt(d.X * d.X + d.Z * d.Z)
		if camFlat > 1e-3 then camSide = Vector3.new(-d.Z / camFlat, 0, d.X / camFlat) end
	end

	------------------------------------------------------------------ v4 pad(): the open spiral
	if f > 0.01 then
		local sq = 1 - 0.38 * ti                            -- the coil pulls the arms in
		local shrink = 0.6 + 0.4 * endK                     -- ...and the end draws them back to the eye
		local n = LK.Spans.Arm + 1
		for i = 0, 3 do
			local b = buf(pad, ARM_KEYS[i], n)
			local P, W, S, o = b.P, b.W, b.S, b.O
			local a0 = th + (i > 0 and i * TAU / 3 or 0.4)
			local rOut = RP * (1 - 0.05 * i)
			local y = LK.ArmLift + 0.02 * i
			for j = 1, n do
				local s = (j - 1) / (n - 1)
				local ang = a0 - LK.ArmSweep * s
				local rr = (0.35 + (rOut - 0.35) * s) * fRaw * sq * shrink
				local ca, sa = cos(ang), sin(ang)
				P[j] = C + Vector3.new(rr * ca, y, -rr * sa)
				S[j] = Vector3.new(ca, 0, -sa)                  -- flat on the floor, the width radial
				W[j] = 0.35 + 0.75 * s
			end
			o.side = S
			o.maxSpans = LK.Spans.Arm
			if i == 0 then
				o.fade, o.glow, o.tail, o.alpha = f, 1 + 0.6 * ti, 0.5, nil
				cv:Ribbon(P, LK.CoreW, "core", o)
			else
				o.fade, o.alpha, o.glow, o.tail, o.t = f * 0.85, 0.6, 0.9 + 0.5 * ti, 0.55, t + i
				cv:Ribbon(P, W, "glow", o)
			end
		end
		-- the pointed arcs whirling over the eye (spun up 3x by the coil: the integrated phase)
		drawArcs(cv, pad.PadArcs, t, pad.ArcNow, C + UP * 0.35, f * 0.8, sq, LK.Spans.PadArc)
		-- the faint floor ripple, calm and slow
		local k = ((t - 0.3) % LK.Pulse) / LK.Pulse
		ring(pad, cv, "rip", C + UP * 0.03, RP * (0.9 + 0.5 * k), 0.25, "vapor", (1 - k) * 0.35 * f, 0.4, 1)

		------------------------------------------------------------------ v5 pad(): the ticks
		local th2 = 0.35 * t
		for i = 0, 15 do
			local b = buf(pad, TICK_KEYS[i], 2)
			local P, o = b.P, b.O
			local a = th2 + i * TAU / 16
			P[1] = at(C, RP * 1.18, a, 0.05)
			P[2] = at(C, RP * 1.02, a, 0.05)
			o.side = Vector3.new(-sin(a), 0, -cos(a))         -- across the tick: round the rim
			o.fade, o.alpha, o.glow, o.tail, o.maxSpans = f * 0.8, 0.7, 1.1, 0.3, 1
			cv:Ribbon(P, 0.16, "glow", o)
		end
	end

	------------------------------------------------------------------ v5 pad(): the shimmer column over the idle pad
	do
		local L = launchIn(pad, t, -0.2, 1.0)
		local cf = f
		if L then cf *= 1 - sin(pi * clamp01((t - L + 0.2) / 1.2)) end
		cf *= smoothR(camFlat, LK.OwnColumnFade[1], LK.OwnColumnFade[2])     -- own view: not a tube round the eye
		if cf > 0.01 then
			local CL = LK.Column
			local body, e0, e1 = buf(pad, "colB", 4), buf(pad, "colE0", 4), buf(pad, "colE1", 4)
			for i, sa in ipairs(CL.Rows) do
				local z = sa * CL.Height
				local r = CL.R0 + CL.Rk * z
				local fa = smoothR(sa, 0, 0.08) * (1 - smoothR(sa, 0.86, 1))   -- mat_shell's foot and rim fades
				local c = C + UP * (z + 0.05)
				body.P[i], body.W[i], body.A[i] = c, 2 * r, CL.BodyAlpha * fa
				e0.P[i], e1.P[i], e0.A[i] = c + camSide * r, c - camSide * r, CL.EdgeAlpha * fa
			end
			local o = body.O                                  -- the body: camera-facing, as wide as the column
			o.fade, o.alpha, o.glow, o.head, o.tail, o.maxSpans, o.t = cf, body.A, CL.BodyGlow, 0, 0, 3, t
			cv:Ribbon(body.P, body.W, CL.BodyKind, o)
			for k = 0, 1 do                                   -- its silhouette edges (the grazing-angle density)
				local e = (k == 0) and e0 or e1
				local oe = e.O
				oe.fade, oe.alpha, oe.glow, oe.head, oe.tail, oe.maxSpans, oe.t = cf, e0.A, CL.EdgeGlow, 0, 0, 3, t
				cv:Ribbon(e.P, CL.EdgeW, CL.EdgeKind, oe)
			end
		end
	end

	------------------------------------------------------------------ v6 pad(): the idle pulse, the step ripple
	do
		local fi = idleK(pad, t) * endK
		local u = (t % LK.Pulse) / LK.Pulse
		if fi > 0.01 then
			ring(pad, cv, "ipulse", C + UP * 0.06, RP * (0.25 + 0.95 * ease_out(u)), 0.22 * (1 - u) + 0.05, "glow",
				fi * sin(pi * u) ^ 1.5 * 0.6, 0.55, 1.0)
		end
		local S = nil
		for i = #pad.Steps, 1, -1 do
			local s0 = pad.Steps[i][1]
			if s0 - 0.01 <= t and t <= s0 + 0.7 then S = s0 break end
		end
		if S then
			for i = 0, 1 do
				local k = span(t, S + 0.08 * i, S + 0.6 + 0.08 * i)
				if k > 0 and k < 1 then
					ring(pad, cv, SRIP_KEYS[i], C + UP * (0.05 + 0.02 * i), RP * (0.35 + 1.25 * ease_out(k)),
						(i == 0 and 0.12 or 0.45) * (1 - k) + 0.04, i == 0 and "glow" or "vapor",
						(1 - k) ^ 1.3 * (i == 0 and 0.9 or 0.6), 0.6, i == 0 and 1.2 or 0.9, t + i)
				end
			end
		end
	end

	------------------------------------------------------------------ v4 column(): the launch column
	do
		local L = launchIn(pad, t, -0.05, 0.9)
		if L then
			local u = t - L
			local Hc = 18 * ease_out(clamp01(u / 0.22))
			local fd = smoothR(u, -0.05, 0.02) * (1 - smoothR(u, 0.35, 0.9))
			local top = max(Hc, 0.5)
			if fd > 0.003 then
				-- the white-hot core line up the axis (own view: not while the camera rides it)
				if camFlat > LK.OwnClearR then
					local b = buf(pad, "colc", 2)
					b.P[1], b.P[2] = C + UP * top, C + UP * 0.1
					b.O.fade, b.O.glow, b.O.tail, b.O.maxSpans = fd, 1.3, 0.4, 1
					cv:Ribbon(b.P, 0.22, "core", b.O)
				end
				-- 4 streaks spiralling up it
				local n = LK.Spans.Streak + 1
				for i = 0, 3 do
					local b = buf(pad, COLG_KEYS[i], n)
					for j = 1, n do
						local zz = top + (0.1 - top) * (j - 1) / (n - 1)
						b.P[j] = at(C, 1.1 + 0.05 * zz, i * pi / 2 + 9 * u - zz * 0.35, zz)
					end
					b.O.fade, b.O.alpha, b.O.glow, b.O.tail, b.O.maxSpans = fd * 0.8, 0.55, 1.0, 0.45, LK.Spans.Streak
					b.O.t = t + i
					cv:Ribbon(b.P, 0.7, LK.StreakKind, b.O)
				end
				-- 2 wide vapor sleeves
				n = LK.Spans.Sleeve + 1
				local topV = max(Hc * 0.9, 0.5)
				for i = 0, 1 do
					local b = buf(pad, COLV_KEYS[i], n)
					for j = 1, n do
						local zz = topV + (0.1 - topV) * (j - 1) / (n - 1)
						b.P[j] = at(C, 2.0 + 0.08 * zz, i * pi + 4 * u + zz * 0.2, zz)
					end
					b.O.fade, b.O.alpha, b.O.tail, b.O.maxSpans = fd * 0.7, 0.4, 0.6, LK.Spans.Sleeve
					cv:Ribbon(b.P, 2.2, "vapor", b.O)
				end
				-- the arcs climbing with it (they spin on the plain clock)
				drawArcs(cv, pad.ColArcs, t, t, C + UP * (Hc * 0.45), fd, 1 + 0.6 * u, LK.Spans.ColArc)
			end
			-- the soft vapor ring at its foot
			local k = span(u, 0, 0.6)
			if k > 0 and k < 1 then
				ring(pad, cv, "vring", C + UP * 0.4, 1.5 + 4.5 * ease_out(k), 1.0 * (1 - k) + 0.2, "vapor", (1 - k) * 0.6, 0.5, 1)
			end
		end
		-- v5: the bigger launch vapor ring
		L = launchIn(pad, t, -0.02, 0.9)
		if L then
			local k = span(t, L, L + 0.8)
			if k > 0 and k < 1 then
				ring(pad, cv, "vbig", C + UP * 0.5, 2.5 + 8.0 * ease_out(k), 1.6 * (1 - k) + 0.3, "vapor", (1 - k) * 0.65, 0.5, 1)
			end
		end
		-- v6: a second, bigger vapor ring, a beat later and higher; and the ribbons peeling up the column
		L = launchIn(pad, t, -0.02, 1.1)
		if L then
			local k2 = span(t, L + 0.06, L + 0.95)
			if k2 > 0 and k2 < 1 then
				ring(pad, cv, "vbig2", C + UP * (1.6 + 1.2 * k2), 3.0 + 10.5 * ease_out(k2), 2.0 * (1 - k2) + 0.4, "vapor",
					(1 - k2) ^ 1.4 * 0.55, 0.45, 1, t + 2)
			end
			local k = span(t, L, L + 0.9)
			if k > 0 and k < 1 then
				local n = LK.Spans.Peel + 1
				local zh = 2.0 + 17.0 * ease_out(k)
				local fadeP = (1 - k) ^ 1.2 * smoothR(k, 0, 0.06)
				for i, pp in ipairs(pad.Peel) do
					local b = buf(pad, PEEL_KEYS[i - 1], n)
					local P, W, o = b.P, b.W, b.O
					for j = 1, n do
						local s = (j - 1) / (n - 1)
						local z = max(zh - pp.Len * 9.0 * (1 - s) * (0.4 + 0.6 * k), 0.2)
						local ang = pp.A0 + 0.55 * z + 4.0 * k
						local r = RP * pp.Rk * (0.7 + 0.03 * z) + 3.5 * k * (z / 19.0) ^ 2 + pp.Pitch * z
						P[j] = at(C, r, ang, z)
						W[j] = (0.25 + 0.5 * s) * (1 - 0.5 * k) * sin(pi * clamp01(s * 0.94 + 0.03)) ^ 0.5
					end
					o.fade, o.alpha, o.glow, o.tail, o.maxSpans, o.t = fadeP, 0.65, 1.2, 0.5, LK.Spans.Peel, t + pp.A0
					cv:Ribbon(P, W, (i - 1) % 3 == 0 and "core" or "glow", o)    -- mg if i % 3 else mc (0-based)
				end
			end
		end
	end

	------------------------------------------------------------------ particles
	if cv.Burst then
		local stopAt = pad.EndT
		-- v4 idle: dust circling the inner pad; half the ticks a glow puff drifting up, a third a spark
		local D, PF, SK = LK.IdleDust, LK.IdlePuff, LK.IdleSpark
		local oDust = streamOpt(pad, "dust", LK.DustLook)
		local oPuff, oSpark = streamOpt(pad, "puff", PF.Look), streamOpt(pad, "spark", SK.Look)
		stream(pad, "idle", t, D.From, D.Period, stopAt, function(i)
			local s = pad.Seed
			local a, r = uni(0, TAU, s, 101, i, 1), RP * uni(D.R[1], D.R[2], s, 101, i, 2)
			local p = at(C, r, a, D.Y)
			throw(cv, "dust", p, airAt(C, p, D.Swirl, D.Inflow, D.Lift), oDust, "id" .. i)
			if rand(s, 102, i, 1) < PF.Chance then
				local q = C + Vector3.new(gauss(PF.Sigma, s, 102, i, 2), PF.Y, gauss(PF.Sigma, s, 102, i, 4))
				throw(cv, "puff", q, airAt(C, q, PF.Swirl, 0, PF.Rise), oPuff, "ip" .. i)
			end
			if rand(s, 103, i, 1) < SK.Chance then
				local q = C + Vector3.new(gauss(SK.Sigma, s, 103, i, 2), uni(SK.Y[1], SK.Y[2], s, 103, i, 3),
					gauss(SK.Sigma, s, 103, i, 4))
				throw(cv, "spark", q, UP * SK.Rise, oSpark, "is" .. i)
			end
		end)
		-- v5: the raised rim of lifted dust (the idle dust's look)
		local RM = LK.RimDust
		stream(pad, "rim", t, RM.From, RM.Period, stopAt, function(i)
			local s = pad.Seed
			local p = at(C, RP * uni(RM.R[1], RM.R[2], s, 104, i, 1), uni(0, TAU, s, 104, i, 2), RM.Y)
			throw(cv, "dust", p, airAt(C, p, RM.Swirl, 0, RM.Rise), oDust, "rd" .. i)
		end)
		-- v6: slowly rising glints in the shimmer column (no flow field: their own drift, the spark's drag)
		local G = LK.Glint
		local oGlint = streamOpt(pad, "glint", G.Look)
		stream(pad, "glint", t, G.From, G.Period, stopAt, function(i)
			local s = pad.Seed
			local a, r = uni(0, TAU, s, 105, i, 1), uni(G.R[1], G.R[2], s, 105, i, 2)
			local p = at(C, r, a, uni(G.Y[1], G.Y[2], s, 105, i, 3))
			local v = Vector3.new(G.Drift * cos(a + 1.6), uni(G.Rise[1], G.Rise[2], s, 105, i, 4), -G.Drift * sin(a + 1.6))
			throw(cv, G.Kind, p, v, oGlint, "gl" .. i)
		end)
		-- each launch's blast, once (and not at all for a launch heard more than half a second late)
		for _, L in ipairs(pad.Launches) do
			if t >= L and t < L + 0.5 and not pad.Fired[L] then
				pad.Fired[L] = true
				for j, bspec in ipairs(LK.LaunchBursts) do
					local o = pad.LBO[j]
					if not o then
						o = { speed = bspec[4], life = bspec[5], up = bspec[6], size = bspec[7] }
						pad.LBO[j] = o
					end
					o.id = "L" .. floor(L * 1000) .. ":" .. j
					o.seed = pad.Seed * 31 + j + floor(L * 7)
					burst(cv, bspec[1], C + UP * bspec[2], bspec[3], o)
				end
			end
		end
	end

	------------------------------------------------------------------ v6 draw(): the pad light
	if cv.Light then
		local LT = LK.Light
		local u = (t % LK.Pulse) / LK.Pulse
		local e = idleK(pad, t) * endK * (LT.Idle + LT.Breath * sin(pi * u) ^ 2)
		for _, L in ipairs(pad.Launches) do
			if t >= L - 0.01 then e += LT.Launch * exp(-max(0, t - L) / LT.LaunchTau) end
		end
		for _, st in ipairs(pad.Steps) do
			if t >= st[1] then e += LT.Step * exp(-(t - st[1]) / LT.StepTau) end
		end
		if e > 1 then
			local o = pad.LO
			o.range, o.flicker = LT.Range, LT.Flicker
			local ok, err = pcall(cv.Light, cv, C + UP * LT.Lift, e, o)
			if not ok then warnOnce("light", "cv:Light failed: " .. tostring(err)) end
		end
	end

	-- the end: the idle layers are gone and every launch's column has run out
	if pad.Freeze then return true end
	local lastL = pad.Launches[#pad.Launches] or -1e9
	local lastS = -1e9
	for _, st in ipairs(pad.Steps) do lastS = max(lastS, st[2]) end
	return not (t > pad.EndT + LK.FadeOut and t > lastL + 1.3 and t > lastS + 0.8)
end

----------------------------------------------------------------------------------------------------
-- PADS (client): one canvas each, by the server's pad id
----------------------------------------------------------------------------------------------------
local pads = {}          -- [id] = pad
local byCaster = setmetatable({}, { __mode = "k" })     -- [character] = pad (its newest)

local function newPad(id, C, radius, life, seed)
	local pad = {
		Id = id, C = C, Radius = radius or T.Radius, EndT = life or T.Life, Seed = seed or 0,
		Steps = {}, Launches = {}, Fired = {}, Ticks = {}, Buf = {},
		Ck = nil, DirtyFrom = nil, IntT = 0, Th = LK.Theta0, ArcPh = 0, ThNow = LK.Theta0, ArcNow = 0,
		SO = {}, LBO = {},                                   -- the particle streams' and launch bursts' options
		LO = {},
	}
	pad.PadArcs = makeArcs(42, pad.Seed, 6, { 0.6, 1.2 }, { 60, 140 }, { 0.04, 0.12 }, { 3, 6 }, 0.08)
	pad.ColArcs = makeArcs(41, pad.Seed, 10, { 1.3, 2.2 }, { 50, 120 }, { 0.06, 0.2 }, { 6, 11 }, 0.2)
	pad.Peel = {}
	for i = 1, LK.PeelN do                               -- rng(64): a0, rk, pitch, ln
		pad.Peel[i] = { A0 = uni(0, 6.28, 64, pad.Seed, i, 1), Rk = uni(0.8, 1.15, 64, pad.Seed, i, 2),
			Pitch = uni(-0.08, 0.1, 64, pad.Seed, i, 3), Len = uni(0.35, 0.8, 64, pad.Seed, i, 4) }
	end
	return pad
end

local function addStep(pad, S, L)
	table.insert(pad.Steps, { S, L })
	dirtyFrom(pad, S - 0.01)                               -- the coil (tight, hold) starts at S
end

local function addLaunch(pad, L)
	local list = pad.Launches
	local i = #list
	while i >= 1 and list[i] > L do i -= 1 end
	table.insert(list, i + 1, L)
	dirtyFrom(pad, L - 0.03)                               -- the spend (charge) starts at L - 0.02
end

--- Starts drawing a pad. clock() -> clip seconds. Draws nothing (and returns the pad, inert) without ZephyrDraw.
local function startPad(pad, clock, freeze)
	local ZD = need("ZephyrDraw")
	if not ZD then
		warnOnce("nodraw", "IceMagic.ZephyrDraw is not there: Gust Pad draws nothing (the mechanic is unaffected)")
		return pad
	end
	local function frameFn(cv, t)
		return drawPad(pad, cv, t)
	end
	local function onEnd()
		if pads[pad.Id] == pad then pads[pad.Id] = nil end
	end
	local ok, handle
	if freeze then
		pad.Freeze = true
		if type(ZD.Demo) == "function" then
			ok, handle = pcall(ZD.Demo, "GustPad", frameFn, { Freeze = freeze, OnEnd = onEnd, Budget = "GustPad",
				Own = pad.Own })
		else
			ok, handle = pcall(ZD.Play, "GustPad", frameFn, { Clock = function() return freeze end, MaxLife = 3600,
				OnEnd = onEnd, Budget = "GustPad", Own = pad.Own })
		end
	else
		-- Budget: ZD.Budgets.GustPad (220 Beams, 1 light); Own: your own pad keeps full density under Reduce Enemy VFX
		ok, handle = pcall(ZD.Play, "GustPad", frameFn, { Clock = clock, MaxLife = pad.EndT + 8, OnEnd = onEnd,
			Budget = "GustPad", Own = pad.Own })
	end
	if ok then
		pad.Handle = handle
	else
		warnOnce("play", "ZephyrDraw.Play failed: " .. tostring(handle))
	end
	return pad
end

local function stopPad(pad)
	if pad and pad.Handle and type(pad.Handle.Stop) == "function" then pcall(pad.Handle.Stop, pad.Handle) end
	if pad and pads[pad.Id] == pad then pads[pad.Id] = nil end
end

--- The pad's end on the server's word (or a newer pad of the same caster): its idle layers unwind from clip time `t`.
local function endPadAt(pad, t)
	if pad and t < pad.EndT then pad.EndT = max(0, t) end
end

----------------------------------------------------------------------------------------------------
-- THE PRESS (own): the answer wait
----------------------------------------------------------------------------------------------------
local bindings = {}
local pressSeq, heardSeq = 0, 0

local function localPlayer()
	return Players.LocalPlayer
end

--- SpellshotInput's bindings (once, client): Flash says "refused" on the slot
function ZephyrGustPad.Init(b)
	bindings = type(b) == "table" and b or {}
end
ZephyrGustPad.Bind = ZephyrGustPad.Init

local function flash(role)
	local f = bindings.Flash
	if type(f) == "function" then pcall(f, role, true) end
end

ZephyrGustPad.LocalCast.GustPad = function(a, b)
	-- SpellshotInput's generic path calls (character, role); the plan's contract wrote (role, character, ability)
	local character, role = a, b
	if type(a) == "string" then character, role = b, a end
	if type(role) ~= "string" then
		local V = need("VFXLibrary")
		role = (V and type(V.TechniqueSlot) == "function" and V.TechniqueSlot(localPlayer(), "GustPad")) or "Defense"
	end
	-- the palm comes up and presses flat (Viewmodel.Clips.GustPad: contact at 0.14, home by 0.52)
	call("Viewmodel", "Play", "GustPad")
	pressSeq += 1
	local seq = pressSeq
	local player = localPlayer()
	local ping = 0
	if player then
		local ok, p = pcall(player.GetNetworkPing, player)
		if ok and type(p) == "number" then ping = p end
	end
	-- a high ping is not a refusal: twice the round trip on top (Aftershock's wait)
	task.delay(max(T.AnswerWait, 2 * ping + 0.3), function()
		if heardSeq >= seq or pressSeq ~= seq then return end
		local V = need("Viewmodel")
		if V and type(V.CurrentClip) == "function" and V.CurrentClip() == "GustPad" then call("Viewmodel", "Stop") end
		flash(role)
	end)
	return true
end

----------------------------------------------------------------------------------------------------
-- HANDLERS (every client, through AbilityFX)
----------------------------------------------------------------------------------------------------
local H = ZephyrGustPad.Handlers

-- { Caster, Position, T0, Life, Pad, Radius }: a pad pressed into the floor
H.GustPad = function(d)
	if type(d) ~= "table" or typeof(d.Position) ~= "Vector3" or not validNumber(d.T0) then return end
	local caster = typeof(d.Caster) == "Instance" and d.Caster or nil
	local player = localPlayer()
	local own = caster ~= nil and player ~= nil and caster == player.Character
	if own then heardSeq = pressSeq end                   -- the server took this client's press
	-- the body's press, for everyone (the caster's own client too: nobody sees their own body in first person)
	if caster and caster.Parent then call("CastPose", "Play", caster, "GustPad") end
	local id = validNumber(d.Pad) and d.Pad or d.T0
	if pads[id] then return end
	-- one pad per caster: the old one unwinds (the server also says so, GustPadEnd)
	local old = caster and byCaster[caster]
	if old then endPadAt(old, serverNow() - old.T0) end
	local life = validNumber(d.Life) and d.Life or T.Life
	local radius = validNumber(d.Radius) and d.Radius or T.Radius
	local pad = newPad(id, d.Position, radius, life, floor(id) % 9973)
	pad.T0, pad.Caster, pad.Own = d.T0, caster, own
	pads[id] = pad
	if caster then byCaster[caster] = pad end
	local t0 = d.T0
	startPad(pad, function() return workspace:GetServerTimeNow() - t0 end)
end

-- { Pad, Character, T0, At }: a body stepped on -- the step ripple, the coil toward At
H.GustPadStep = function(d)
	local pad = type(d) == "table" and pads[d.Pad]
	if not pad then return end
	local s0 = validNumber(d.T0) and d.T0 or serverNow()
	local S = s0 - pad.T0
	local L = validNumber(d.At) and (d.At - pad.T0) or (S + T.Coil)
	addStep(pad, S, max(S, L))
	-- the body on it coils and is thrown up in the showcase's clean ascent (CastPose.Clips.GustPadLaunch, on the step's
	-- server clock so the snap lands on the launch). Player characters only: CastPose would keep posing a dummy for good.
	local ch = typeof(d.Character) == "Instance" and d.Character or nil
	if ch and ch.Parent and Players:GetPlayerFromCharacter(ch) then
		call("CastPose", "PlayClocked", ch, "GustPadLaunch", function() return serverNow() - s0 end)
	end
end

-- { Pad, Character, T0 }: the launch column
H.GustPadLaunch = function(d)
	local pad = type(d) == "table" and pads[d.Pad]
	if not pad then return end
	addLaunch(pad, (validNumber(d.T0) and d.T0 or serverNow()) - pad.T0)
end

-- { Pad, Reason, T0 }: replaced, spent, expired or cleared -- the idle layers unwind, a launch in the air runs out
H.GustPadEnd = function(d)
	local pad = type(d) == "table" and pads[d.Pad]
	if not pad then return end
	endPadAt(pad, (validNumber(d.T0) and d.T0 or serverNow()) - pad.T0)
end

----------------------------------------------------------------------------------------------------
-- THE KNOCK (sent to the launched player alone): this client throws its own body
----------------------------------------------------------------------------------------------------
-- A player's body is its own client's to move, so the server SENDS the launch (AbilityFX's AftershockKnock pattern):
-- a dash under way lets go first, the root's vertical speed is set at once and its horizontal cut to KeptFlat (a third,
-- at most MaxFlat), and a Line LinearVelocity holds the vertical for the hold -- so the Humanoid's floor hold cannot eat
-- the first frames -- then physics carries the body. A newer launch replaces an older one. Nothing checks that a client
-- obeys (as for Aftershock).
-- THE RISE IS THE COLUMN'S (fixed 2026-10-07). Until the apex the flat speed is held to MaxFlat every frame (air steering
-- still works inside it) and IsActive is true, so MovementController's air momentum keeper stands down: it had carried
-- the speed you came onto the pad with (a hop-on is already airborne, so its "carried" pace outlived the launch and was
-- written straight back over the cut), and a held W rebuilt a sprint's 25 studs/s in the air -- with the old 2.7 s hang
-- that was the playtest's ~95-stud fling. From the apex you are yours again: the keeper samples the capped pace, double
-- jump and wall run come back. A dash, a Skyrider ride, a landing or something else taking the body ends the hold early.
-- The hold is timed from THIS client's receipt, not the server's clock: `Until` (server time) had already passed by the
-- time a knock a ping late arrived, so the mover was dropped on the first frame.
local launched = nil     -- { Attachment, Conn }

local function dropLaunch()
	local k = launched
	if not k then return end
	launched = nil
	if k.Conn then k.Conn:Disconnect() end
	if k.Attachment then k.Attachment:Destroy() end
end

--- something else drives the body now: a dash (DashMotor) or a Skyrider ride
local function bodyTaken()
	for _, name in ipairs({ "DashMotor", "ZephyrSkyrider" }) do
		local M = need(name)
		if M and type(M.IsActive) == "function" then
			local ok, on = pcall(M.IsActive)
			if ok and on then return true end
		end
	end
	return false
end

-- { Pad, Speed, Hold, T0 } (Until, the first build's field, is read as Hold = Until - T0)
H.GustPadKnock = function(d)
	if type(d) ~= "table" then return end
	local player = localPlayer()
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = d.Speed
	if not (root and humanoid and humanoid.Health > 0 and validNumber(speed) and speed > 0 and speed <= 400) then
		return
	end
	local hold = validNumber(d.Hold) and d.Hold
		or (validNumber(d.Until) and validNumber(d.T0) and d.Until - d.T0) or T.GrabTime
	hold = math.clamp(hold, 0, 0.5)
	dropLaunch()
	-- whatever else was moving the body lets go of it
	local DM = need("DashMotor")
	if DM and type(DM.IsActive) == "function" and type(DM.Cancel) == "function" then
		local ok, active = pcall(DM.IsActive)
		if ok and active then pcall(DM.Cancel, "GustPad") end
	end
	root.AssemblyLinearVelocity = ZephyrGustPad.KeptFlat(root.AssemblyLinearVelocity) + UP * speed
	pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Freefall)
	local attachment = Instance.new("Attachment")
	attachment.Name = "GustPadLaunchAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "GustPadLaunch"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Line      -- only the vertical: the flat is capped below
	mover.LineDirection = UP
	mover.LineVelocity = speed
	mover.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	mover.MaxForce = root.AssemblyMass * T.KnockForcePerMass
	mover.Parent = attachment
	attachment.Parent = root
	local k = { Attachment = attachment }
	launched = k
	local t0 = os.clock()
	local g = workspace.Gravity
	local apexAt = hold + (g > 0 and speed / g or 1)
	k.Conn = RunService.Heartbeat:Connect(function()
		if launched ~= k then return end
		local t = os.clock() - t0
		if player.Character ~= character or not root.Parent or humanoid.Health <= 0 or t >= apexAt then
			dropLaunch()
			return
		end
		if k.Attachment and t >= hold then                    -- the air lets go: physics carries the rise
			k.Attachment:Destroy()
			k.Attachment = nil
		end
		local v = root.AssemblyLinearVelocity
		if bodyTaken() or (t > hold + 0.1 and (v.Y <= 0 or humanoid.FloorMaterial ~= Enum.Material.Air)) then
			dropLaunch()                                      -- a dash, a ride, a ceiling, a ledge: the rise is over
			return
		end
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > T.MaxFlat then
			flat = flat.Unit * T.MaxFlat
			root.AssemblyLinearVelocity = Vector3.new(flat.X, v.Y, flat.Z)
		end
	end)
	-- own view: the small roll as the column takes you (drawing: guarded, never in the way of the throw)
	call("ZephyrDraw", "CameraKick", LK.OwnLaunchKick)
end

--- ZephyrClient's body contract: true while the launch holds your body -- the grab and the rise to the apex (~0.8 s at
--- this place's gravity). MovementController keeps its double jump, wall run and air momentum keeper off for that long,
--- no longer: from the apex you are yours again.
function ZephyrGustPad.IsActive()
	return launched ~= nil
end

--- ...and something else takes your body (a Cyclone pull, an Aftershock knock: AbilityFX through ZephyrClient): the
--- launch's mover lets go at once (the speed it already gave is kept).
function ZephyrGustPad.Interrupt(_reason)
	dropLaunch()
end

----------------------------------------------------------------------------------------------------
-- DEMO (the test harness: ZephyrTestHarness, Studio only)
----------------------------------------------------------------------------------------------------
local demoPad, demoFinish = nil, nil     -- the demo's pad, and what puts its dummy away and its caster back

--- the floor under p (through every body and the FX folder), or nil
local function floorUnder(p, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = {}
	for _, x in ipairs(ignore) do list[#list + 1] = x end
	params.FilterDescendantsInstances = list
	for _ = 1, 6 do
		local hit = workspace:Raycast(p + UP * T.FloorUp, Vector3.new(0, -(T.FloorUp + T.FloorDrop), 0), params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit.Position end
		params:AddToFilter(model)
	end
	return nil
end

--- gust_pad_bl flight(): the height of a launched body `a` s after its launch (a smooth start: the air takes ~2 frames
--- to grab it). The DEMO's bodies fly the showcase's arc (the real launch is LaunchSpeed(): ApexHeight at this place's
--- gravity).
local function flight(a)
	local D = LK.Demo
	if a <= 0 then return 0 end
	return max(0, D.V0 * a - 0.5 * D.G * a * a - D.V0 * D.Tau * (1 - exp(-a / D.Tau)))
end

local aLand = nil
--- gust_pad_bl A_LAND: a launched body is back on the floor this long after its launch (~2.06 s)
local function landTime()
	if not aLand then
		local a = 0.5
		while flight(a + 0.001) > 0 and a < 10 do a += 0.001 end
		aLand = a
	end
	return aLand
end

local function softplus(x, w)
	if x / w >= 30 then return x end
	return w * math.log(1 + exp(x / w))
end

--- a two-bone leg whose foot sits right under its hip, `d` studs down: the thigh's forward swing and the knee's bend (deg)
local function legIK(d)
	local DD = LK.Demo.Dummy
	local l1, l2 = DD.Thigh, DD.Shin
	d = math.clamp(d, abs(l1 - l2) + 0.05, l1 + l2 - 1e-4)
	local hs = math.acos(math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1))
	local kIn = math.acos(math.clamp((l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2), -1, 1))
	return math.deg(hs), 180 - math.deg(kIn)
end

-- Dummy.air (the launched dummy's PoseTrack), read off its joint keys: a = s after the launch; hip height; spine lean
-- (deg, + forward); the arms' raise out to the side (abd, deg: 0 hanging, 90 level, 180 overhead) and forward swing;
-- the legs' forward swing and knee bend (none = standing: legIK). snap = ease out into the key (Blender "snap").
local airKeys = nil
local function getAirKeys()
	if airKeys then return airKeys end
	local AL = landTime()
	airKeys = {
		{ a = 0.00, hip = 1.75, lean = 7, abd = 25, fwd = 10, hs = 18, kb = 36 },
		{ a = 0.10, hip = 2.00, lean = -5, abd = 174, fwd = 6, hs = 0, kb = 4, snap = true },  -- flung straight up
		{ a = 0.62, hip = 2.00, lean = -3, abd = 168, fwd = 6, hs = 2, kb = 6 },
		{ a = 1.05, hip = 2.00, lean = 9, abd = 78, fwd = 6, hs = 28, kb = 50 },               -- the apex: it flails
		{ a = 1.75, hip = 2.00, lean = 3, abd = 112, fwd = 8, hs = 25, kb = 42 },
		{ a = AL - 0.04, hip = 2.00, lean = 3, abd = 102, fwd = 8, hs = 24, kb = 36 },
		{ a = AL + 0.09, hip = 1.22, lean = 26, abd = 28, fwd = 45, snap = true },             -- landed: the buckle
		{ a = AL + 0.60, hip = 1.95, lean = 5, abd = 14, fwd = 8 },                            -- recovered
	}
	return airKeys
end

local function lerp(a, b, u)
	return a + (b - a) * u
end

local function airPose(a, q)
	local K = getAirKeys()
	local k0, k1, u = K[#K], K[#K], 1
	for i = 1, #K - 1 do
		if a < K[i + 1].a then
			k0, k1 = K[i], K[i + 1]
			u = clamp01((a - k0.a) / (k1.a - k0.a))
			break
		end
	end
	local e = k1.snap and ease_out(u) or ease(u)
	local hs0, kb0 = k0.hs, k0.kb
	if not hs0 then hs0, kb0 = legIK(k0.hip) end
	local hs1, kb1 = k1.hs, k1.kb
	if not hs1 then hs1, kb1 = legIK(k1.hip) end
	q.hip, q.lean = lerp(k0.hip, k1.hip, e), lerp(k0.lean, k1.lean, e)
	q.abdR = lerp(k0.abd, k1.abd, e)
	q.abdL = q.abdR
	q.fwdR = lerp(k0.fwd, k1.fwd, e)
	q.fwdL = q.fwdR
	q.hsR = lerp(hs0, hs1, e)
	q.hsL = q.hsR
	q.kbR = lerp(kb0, kb1, e)
	q.kbL = q.kbR
end

--- the range dummy at clip time t (gust_pad_bl Dummy.at): walks on facing the caster, the pad grabs it (a knee-dip and
--- a tremble as it tightens), launched straight up in a clean line, flails at the apex, drifts on and lands off the pad
local function dummyPose(pad, t, q)
	local D, DD = LK.Demo, LK.Demo.Dummy
	local RT, RXY = DD.RootT, DD.RootXY
	if t < D.Launch1 then
		local x, y = RXY[1][1], RXY[1][2]
		if t >= RT[#RT] then
			x, y = RXY[#RXY][1], RXY[#RXY][2]
		elseif t > RT[1] then
			for i = 1, #RT - 1 do
				if t < RT[i + 1] then
					local u = (t - RT[i]) / (RT[i + 1] - RT[i])
					x, y = lerp(RXY[i][1], RXY[i + 1][1], u), lerp(RXY[i][2], RXY[i + 1][2], u)
					break
				end
			end
		end
		local walking = t > RT[1] and t < RT[#RT]
		local ph = (t - RT[1]) / 0.25
		local sw = walking and sin(pi * ph) or 0
		local lift = walking and cos(pi * ph) or 0
		local ti, hk = tight(pad, t), hold(pad, t)
		q.x, q.y, q.z, q.yaw = x, y, 0, pi                  -- yaw pi: facing the caster
		q.hip = 1.96 - (walking and 0.09 * abs(cos(pi * ph)) or 0) - 0.36 * ti - 0.08 * hk
		q.lean = 3.4 + 9.2 * ti + 2.9 * hk                  -- spine 0.06 + 0.16 ti + 0.05 hk rad
		local tr = (0.035 * ti + 0.015 * hk) * 25            -- the 11 Hz tremble: studs at the hand -> degrees
		q.abdR = 14 + 26 * ti + tr * sin(t * 69.1)
		q.abdL = 14 + 26 * ti + tr * sin(t * 56.1 + 2)
		q.fwdR = 6 - 18 * sw * (1 - ti) + 12 * ti
		q.fwdL = 6 + 18 * sw * (1 - ti) + 12 * ti
		local hs, kb = legIK(q.hip)
		q.hsR, q.hsL = hs + 24 * sw, hs - 24 * sw
		q.kbR, q.kbL = kb + 30 * max(0, lift), kb + 30 * max(0, -lift)
		return q
	end
	local a = t - D.Launch1
	local AL = landTime()
	local sx, sy = RXY[#RXY][1], RXY[#RXY][2]
	local pull = ease(span(a, 0, 0.3))                       -- the column draws it over the centre...
	q.x = sx + (D.C[1] - sx) * pull * 0.8
	q.y = sy + (D.C[2] - sy) * pull * 0.8 + DD.Drift * softplus(min(a, AL) - 0.5, 0.12)   -- ...then it drifts on
	q.z = (a < AL) and flight(a) or 0
	q.yaw = pi + 0.32 * TAU * ease_out(span(a, 0, 1.7))
	airPose(a, q)
	if a < AL then                                           -- the flail
		local w = sin(pi * min(1, a / AL))
		q.abdR += 7 * w * sin(TAU * 1.6 * a)
		q.abdL += 7 * w * sin(TAU * 1.6 * a + 1.9)
		q.fwdR += 5 * w * sin(TAU * 1.1 * a)
		q.fwdL += 5 * w * sin(TAU * 1.1 * a + 1.9)
		q.hsR += 5 * w * sin(TAU * 1.3 * a + 0.7)
		q.hsL += 5 * w * sin(TAU * 1.3 * a + 2.6)
	end
	return q
end

--- the range dummy: a local, client-only blocky figure (zk DUMMY's colour and proportions), anchored, never collides,
--- never queried, never replicated -- it exists only for the demo
local function buildDummy()
	local DD = LK.Demo.Dummy
	local m = Instance.new("Model")
	m.Name = "GustPadDemoDummy"
	local parts = { Model = m }
	local sizes = {
		Torso = Vector3.new(2, 1.9, 1), Head = Vector3.new(1.15, 1.15, 1.15),
		ArmR = Vector3.new(0.85, DD.Arm, 0.85), ArmL = Vector3.new(0.85, DD.Arm, 0.85),
		ThighR = Vector3.new(0.9, DD.Thigh, 0.9), ThighL = Vector3.new(0.9, DD.Thigh, 0.9),
		ShinR = Vector3.new(0.9, DD.Shin, 0.9), ShinL = Vector3.new(0.9, DD.Shin, 0.9),
	}
	for name, size in pairs(sizes) do
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, DD.Color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		parts[name] = p
	end
	m.Parent = workspace
	return parts
end

local function placeDummy(parts, stageCF, q)
	local DD = LK.Demo.Dummy
	local rad = math.rad
	local H = stageCF * CFrame.new(q.x, q.z, -q.y) * CFrame.Angles(0, q.yaw, 0) * CFrame.new(0, q.hip, 0)
	local Tq = H * CFrame.Angles(-rad(q.lean), 0, 0)         -- the torso leans forward over the hips
	parts.Torso.CFrame = Tq * CFrame.new(0, 0.95, 0)
	parts.Head.CFrame = Tq * CFrame.new(0, 2.5, 0)
	for s = -1, 1, 2 do
		local R = s > 0
		local sh = Tq * CFrame.new(s * 1.45, 1.75, 0)
		parts[R and "ArmR" or "ArmL"].CFrame = sh * CFrame.Angles(rad(R and q.fwdR or q.fwdL), 0, 0)
			* CFrame.Angles(0, 0, s * rad(R and q.abdR or q.abdL)) * CFrame.new(0, 0.15 - DD.Arm / 2, 0)
		local hp = H * CFrame.new(s * 0.5, 0, 0) * CFrame.Angles(rad(R and q.hsR or q.hsL), 0, 0)
		parts[R and "ThighR" or "ThighL"].CFrame = hp * CFrame.new(0, -DD.Thigh / 2, 0)
		parts[R and "ShinR" or "ShinL"].CFrame = hp * CFrame.new(0, -DD.Thigh, 0)
			* CFrame.Angles(-rad(R and q.kbR or q.kbL), 0, 0) * CFrame.new(0, -DD.Shin / 2, 0)
	end
end

--- the caster's root over where it stood (gust_pad_bl Caster.run): forward (stage y) to the pad's centre by the landing,
--- the hop between take-off and landing, then the launch's flight (0 again once it has landed)
local function casterOffset(t)
	local D = LK.Demo
	local fwd, up = 0, 0
	if t > D.Run0 then fwd = D.C[2] * span(t, D.Run0 + 0.08, D.Land2) ^ 1.15 end
	if t > D.Takeoff and t < D.Land2 then up = 1.1 * sin(pi * (t - D.Takeoff) / (D.Land2 - D.Takeoff)) end
	if t > D.Launch2 then up += flight(t - D.Launch2) end
	return fwd, up
end

--- Plays the v6 reel's whole Gust Pad hero clip on `character` without the server (see the header's .Demo).
--- opts: Freeze (clip s: hold that frame), Scale (the clock's speed; default ZD.TimeScale()), MoveCaster (false: the
--- caster's root is not carried through the run-on and launch). Returns { Pad, Stop = fn }.
function ZephyrGustPad.Demo(character, opts)
	opts = type(opts) == "table" and opts or {}
	ZephyrGustPad.StopDemo()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return { Stop = function() end } end
	local D = LK.Demo
	local ZD = need("ZephyrDraw")
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	-- the stage: the caster's flat facing frame at floor level; the pad 6 studs ahead of it, on the floor
	local stageCF = nil
	if ZD and type(ZD.StageCF) == "function" then
		local ok, cf = pcall(ZD.StageCF, root)
		if ok and typeof(cf) == "CFrame" then stageCF = cf end
	end
	local feet = root.Position - UP * 3
	stageCF = stageCF or CFrame.lookAt(feet, feet + look)
	local fx = workspace:FindFirstChild("IceMagicFX")
	local ignore = { character }
	if fx then ignore[#ignore + 1] = fx end
	local aim = (stageCF * CFrame.new(D.C[1], 0, -D.C[2])).Position
	local C = floorUnder(aim, ignore) or aim
	-- the clip clock: real seconds x the shot time scale (the slow-motion capture), or one frozen frame
	local scale = 1
	if validNumber(opts.Scale) and opts.Scale > 0 then
		scale = opts.Scale
	elseif ZD and type(ZD.TimeScale) == "function" then
		local ok, s = pcall(ZD.TimeScale)
		if ok and validNumber(s) and s > 0 then scale = s end
	end
	local freeze = validNumber(opts.Freeze) and opts.Freeze or nil
	local start = os.clock()
	local clock = freeze and function() return freeze end or function() return (os.clock() - start) * scale end
	local player = localPlayer()
	local own = player ~= nil and character == player.Character
	-- the press: the body's kneel on the demo's clock (every client's look), the arms when it is this client's own
	call("CastPose", "PlayClocked", character, "GustPad", clock)
	if own and not freeze then call("Viewmodel", "Play", "GustPad", clock) end
	local pad = newPad(-1, C, T.Radius, D.Life, 7)
	pad.T0, pad.Caster, pad.Demo, pad.Own = 0, character, true, own
	addStep(pad, D.Step1, D.Launch1)
	addLaunch(pad, D.Launch1)
	addStep(pad, D.Land2, D.Launch2)
	addLaunch(pad, D.Launch2)
	startPad(pad, clock, freeze)
	-- the second actor and the caster's run-on, posed every frame from the same clock
	local okD, dummy = pcall(buildDummy)
	if not okD then
		warnOnce("dummy", "the demo dummy failed: " .. tostring(dummy))
		dummy = nil
	end
	local q = {}
	local moveCaster = own and opts.MoveCaster ~= false
	local startCF, wasAnchored = root.CFrame, root.Anchored
	local flat = CFrame.lookAt(root.Position, root.Position + look)
	if moveCaster then root.Anchored = true end             -- carried by the demo, not by physics or the controls
	local ranClip, restored, conn = false, false, nil
	local function restore()
		if restored then return end
		restored = true
		if moveCaster and root.Parent then
			root.CFrame = startCF
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = wasAnchored
		end
	end
	local function step()
		local t = clock()
		if dummy then
			local ok, err = pcall(function() placeDummy(dummy, stageCF, dummyPose(pad, t, q)) end)
			if not ok then warnOnce("dummypose", "the demo dummy's pose failed: " .. tostring(err)) end
		end
		if t >= D.RunClip and not ranClip then              -- the run-on, the hop, the coil, the ascent
			ranClip = true
			call("CastPose", "PlayClocked", character, "GustPadRun", function() return clock() - D.RunClip end)
		end
		if moveCaster and not restored then
			if t >= D.Restore and not freeze then
				restore()
			elseif root.Parent then
				local fwd, up = casterOffset(t)
				root.CFrame = flat * CFrame.new(0, up, -fwd)
			end
		end
	end
	local function finish()
		if conn then conn:Disconnect() conn = nil end
		restore()
		if dummy then dummy.Model:Destroy() dummy = nil end    -- the demo's own client-only figure
	end
	conn = RunService.RenderStepped:Connect(function()
		step()
		if not freeze and clock() > D.Life + LK.FadeOut + 0.2 then finish() end
	end)
	step()
	demoPad, demoFinish = pad, finish
	return {
		Pad = pad,
		Stop = function()
			stopPad(pad)
			finish()
			if demoPad == pad then demoPad, demoFinish = nil, nil end
		end,
	}
end

--- the harness's other way to stop a demo (it calls the handle's Stop first)
function ZephyrGustPad.StopDemo()
	if demoPad then
		stopPad(demoPad)
		demoPad = nil
	end
	if demoFinish then
		local f = demoFinish
		demoFinish = nil
		f()
	end
end

--- the clip functions, for anything that wants to draw in step with a pad (read-only)
ZephyrGustPad.Form = form

return ZephyrGustPad
