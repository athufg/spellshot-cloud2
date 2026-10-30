--[[
	ZephyrFX_WindBlade  (ReplicatedStorage.IceMagic.ZephyrFX_WindBlade, ModuleScript, CLIENT ONLY)   Zephyr v6, 2026-10-06

	WIND BLADE, the Zephyr M1, in the v6 GLOW look. The owner's call (ROBLOX_IMPORT_PLAN.md section 0): the glow replaces
	the toon-ink look outright, and the gameplay stays exactly as it was. This module IS the blade: its flight down the
	crosshair and the hit sweep that decides what it cuts (moved here VERBATIM from ZephyrFX on 2026-10-06 -- the sphere
	of HitRadius for bodies, the hairline for the world, Pierce bodies, onHit before anything cosmetic, the WB_ probe
	counts), plus everything it draws, on IceMagic.ZephyrDraw (pooled textured Beams, soft aqua PointLights, the NOT NEON
	palette: a white-hot core inside a teal sleeve, never neon lime, never a blown-out blob).

	WHO CALLS IT
	  ZephyrFX.FireWindBlade / ZephyrFX.WindBladeSwirl are thin stubs with their old signatures that hand straight over:
	    SpellshotInput  your own blade, on the viewmodel slash's release, with onHit (the shot is reported to the server)
	    AbilityFX       everybody else's, Trigger after their WindBlade broadcast, from their hand, no onHit
	  ZephyrFX.Tuning.WindBlade stays in ZephyrFX (ZephyrHandler, the server, reads its gameplay numbers); this module
	  reads Speed, Range, Pierce, Trigger, Merge, HitRadius and the own-view rules (OwnTrail, OwnFarScale, OwnShrinkFrom,
	  OwnShrinkOver) from there. The look's numbers are this module's own Tuning. StarterPlayerScripts.ZephyrTestHarness
	  calls Demo.

	THE SOURCE (ported frame function by frame function; the Blender numbers are kept, named in Tuning)
	  blender_scripts/zephyr/aqua/wind_blade_v6.py   the per-hand arc, the cut line, the release puff, the micro-shake, the
	                                                light riding the newest blade
	    <- wind_blade_v5.py   the lens sliver, the spiral wake, the floor scratches
	    <- wind_blade_v4.py   the core thread, the teal rim, 2 accent arcs, the vapor wake, the ripple ring, the impact
	                          ring, the hand swirl, the debris
	    <- spring/wind_blade_bl.py   the shots (8 a second, hands alternating, the release Trigger after the press), the aim
	                          line and the merge off the hand
	    za.py / za5.py        the materials (mat_wind kinds -> ZephyrDraw kinds), path_ribbon, ring, burst, aqua_light
	  SPACE. The Blender stage's +Y (forward) is the shot's Dir, +X its Right (Dir x Up), +Z its Up (world up wherever it
	  can be, as ZephyrFX always built it), 1 stud = 1 stud. A blade's centre is Origin + Dir x Dist, plus the hand offset
	  easing out: the kit's blade_pos easing off the hand onto the aim line (over the kit's 9 studs, Tuning.Merge; your
	  own over ZephyrFX's Merge seconds).
	  TIME. A blade's clock is t = (os.clock() - its release) x ShotTimeScale, as ZephyrFX's always was; t = 0 is the
	  release. The kit's blade flies at 150 studs/s (slowed for its camera) and the game's at 240 (gameplay, untouched), so
	  what the kit sized in SECONDS OF FLIGHT behind the blade (the wake, the spiral wake) keeps the kit's length in
	  STUDS, and everything else keeps the kit's seconds.

	WHAT ONE BLADE DRAWS (the kit's 15 pieces; Tuning.Knots keeps the Beam count down)
	  HAND     the SWIRL: an open spiral, white-hot core in a teal sleeve, winding into the palm (270 deg, radius 0.75 ->
	           0.22) before the release; the RELEASE PUFF (3 puffs) as the blade leaves
	  FLIGHT   the LENS SLIVER (a Sheet: thick in the middle, bright on its leading face) under the CORE thread on that
	           leading face and the teal RIM; 2 ACCENT arcs; the VAPOR WAKE (18 studs) and the 2-arc SPIRAL WAKE (10.5
	           studs); a RIPPLE RING left in the air 3 studs out. The crescent squashes and stretches at the release
	           and thins out from 26 to 70 studs of flight. Per hand: right R 1.55 / 122 deg / tilt 62 deg ("/" seen
	           from behind), left R 1.40 / 136 deg / 48 deg ("\"). An Up stroke is its Down stroke turned half round
	           the flight (head and tail swapped), as the toon kit's four crescents were
	  PIERCE   per body: the CUT LINE across it along the blade's span (3.2 -> 4.2 studs, flashes in 0.012 s, fades tau
	           0.09 s), a small IMPACT vapor ring; on the first body 3 radial SCRATCH marks on the floor under it (when
	           there is floor within Scratch.Reach), dust 3 + chips 2 + sparks 3; later bodies dust 2. A blade the
	           world stops gets the impact ring and 2 dust on the wall
	  DEBRIS   a speck and two dust puffs kicked off the floor under the path (when there is floor under it)
	  LIGHT    ONE soft aqua PointLight shared by every blade, riding the newest (your own first): 140 W on the swirl,
	           300 W at the release fading out over 0.4 s, +300 W (tau 0.07 s) on each pierce, +380 W (tau 0.05 s) on
	           the first hit of a burst (v4's impact flash, folded into the one light), Range 8, flicker 0.15
	  Particles per shot 14 (dust 5, speck 1, chips 2, sparks 3, puffs 3) before ZephyrDraw thins them: Graphics
	  Quality (EffectDensity) for everybody's, Reduce Enemy VFX (its Config.EnemyThin) for anybody else's.

	THE HAND SWIRL'S CLOCK. The kit winds it over the 0.14 s before the release; in the game nothing reaches this module
	before the release but WindBladeSwirl. Called at the press (Trigger = 0.06 s ahead of the release), the swirl
	winds over that lead and hands over to its blade; not called, FireWindBlade plays it over Swirl.Late after the
	release instead (the old SwirlGap rule decides which). Either way it is the kit's swirl shape at the same k.

	YOUR OWN VIEW (the game is first person). Your own blade keeps ZephyrFX's rules: it leaves the viewmodel hand (a
	touch ahead of it, HandLead, so it sits clear of the arm) and eases onto the crosshair line over Merge, it shrinks to
	OwnFarScale once it is well away, and its trail -- the wake and the spiral wake, ribbons down the view axis -- is not
	drawn (OwnTrail). Your own swirl and puff are drawn at OwnHandScale, HandToward nearer the camera. Each of your
	shots gives the camera the kit's micro-shake through ZephyrDraw.CameraKick: e^(-tau / 0.035) x sin(120 tau + 0.6)
	x (pitch 0.010 rad, roll +-0.006 by hand) -- a small recoil buzz, which the engine drops under Reduce Flashing and
	scales by the Camera Shake setting. Somebody else's blade meeting YOU draws no hit on you (it would sit on your
	camera).

	BUDGET (ZephyrDraw.Budgets.WindBlade: 45 Beams per blade in flight, 1 shared light). A blade's flight is <= 41
	Beams (the lens 4 bands x 4 spans, core 4, rim 4, accents 2 x 2, wake 3, spiral wake 2 x 3, ripple ring 4); your
	own <= 32 (no trail). Its pierces draw on a canvas of their own under the same budget (per body: impact ring 4, cut
	core + glow 2 x 2; under the first, 3 scratches x 1 span x 2 Beams, the scuff's dark strip and its teal line). The
	swirls (12 Beams each) and the light share one HANDS canvas; the bursts go on two burst canvases (your own, and
	everybody else's: ZephyrDraw thins those under Reduce Enemy VFX). At most MaxDrawn blades are drawn at once: the
	oldest beyond that still fly and hit, undrawn.

	GUARDS. Inert on the server (lazy requires; the RenderStep binds on the first shot, client only). The flight and the
	sweep never wait on the look: every call into drawing is pcall-guarded, and without ZephyrDraw a blade still flies
	and hits, undrawn (one warning).

	API (the ZephyrFX stubs pass the first seven arguments; anything after them is this module's own)
	  WindBlade.FireWindBlade(origin, dir, exclude, visualFrom, onHit, side, stroke, opts?)
	      exactly ZephyrFX's: origin along dir is the shot; visualFrom is where it is SEEN to leave (the viewmodel hand);
	      onHit(result) for every character it passes through and for what finally stops it (which makes it your own
	      shot); side "L" / "R" is the slashing hand, stroke "Down" / "Up" its direction. opts.Own overrides own-ness
	      (the demo: your own rules with nothing reported)
	  WindBlade.WindBladeSwirl(position, side, stroke, dir?)   the swirl at a hand, ahead of that hand's release.
	      position: a Vector3, or a BasePart / Attachment that is followed while it winds; dir: the aim (else the
	      camera's look for a hand near the camera, the body's facing otherwise)
	  WindBlade.Demo(character, opts?) -> handle {Stop}   the reel's whole hero take (2026-10-07) at the training dummy
	      the character faces: the guard rises (CastPose WindBladeRise), 15 blades from the right hand first, then 10
	      from the left at 2.70 s, 8 a second, each press playing the body's flick (CastPose; the viewmodel's too in
	      first person), its swirl, its blade on the release, and every dummy cut leaning back and sliding away as the
	      kit's do (locally, put back after). Third person is the kit's exactly (the body's hands, the aim from the
	      chest, the trail); first person is your own view. Nothing is reported to the server. opts.Freeze = clip
	      seconds from the first press draws that one frame and holds it until Stop; opts.Shots = one burst of that
	      many; opts.NoPose / opts.NoReact drop the clips / the dummies' reaction
	  WindBlade.StopDemo()
	  WindBlade.Tuning

	NOT LIKE BLENDER: ZephyrDraw's Beams have no thickness (the lens is a Sheet of flat bands, edge-on from straight
	behind, as the kit's mesh is), knots replace the kit's 11-30 points per ribbon (Tuning.Knots), particles are
	ParticleEmitter bursts (not the kit's simulated paths in its flow field), a hit's time is the sweep's contact (the
	hit sphere's front edge, a few ms before the kit's centre-on-the-dummy), the kit's anticipating flash rise cannot
	start before the hit, the swirl winds over the press-to-release lead (0.06 s) rather than 0.14 s, the dummy's
	knockback is the server's (ZephyrHandler), and the world-stop puff is new (the kit's blade never meets a wall).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WindBlade = {}

----------------------------------------------------------------------------------------------------
-- TUNING (the LOOK; the shot's gameplay numbers are ZephyrFX.Tuning.WindBlade). Every number is the Blender kit's
-- (wind_blade_v6 / v5 / v4) unless its comment says ASSUMED or PROVISIONAL.
----------------------------------------------------------------------------------------------------
local Tuning = {
	-- THE CRESCENT (v6 ARC; the v4 blade() it calls). Seen from behind, its span axis leans Tilt deg off the shot's up
	-- toward the slashing hand ("/" right hand, "\" left); its horns sweep back along the flight.
	Arc = {
		R = { Radius = 1.55, Span = 122 },   -- the right hand: tighter, steeper
		L = { Radius = 1.40, Span = 136 },   -- the left: rounder
	},
	Tilt = 62,                               -- deg, x HandSign
	HandSign = { R = 1, L = -0.78 },         -- the kit's sg; v6 flattens the left hand's to x0.78 (62 -> 48 deg)
	Back = 0.55,                             -- the horns sweep back (1 - cos a) x Radius x Back
	Stretch = 0.35, StretchTau = 0.05,       -- the release squash-stretch: the sweep-back x (1 + 0.35 e^(-t / 0.05))
	FadeFrom = 26, FadeTo = 70,              -- studs of flight over which the blade thins out (smoothstep)
	WidthPower = 0.8,                        -- the crescent's width along its arc: sin(pi (s + 0.5))^0.8
	Core = { Width = 0.11, Min = 0.01, Lead = 0.12, Glow = 1.6, Fray = 0.4 },   -- Glow 1.2 -> 1.6 (2026-10-09: daylight)   -- the white-hot thread, on the leading face
	Rim = { Width = 0.50, Min = 0.02, Fade = 0.9, Alpha = 0.8, Glow = 1.35, Fray = 0.6 },   -- Alpha 0.62 -> 0.8, Glow 1.0 -> 1.35 (2026-10-09)   -- the teal sleeve (v6 WMAX)
	-- THE LENS SLIVER (v5): compressed air with a body, ZephyrDraw's "surf" Sheet (za5 mat_surf("za5_lens", e0 = 0.65,
	-- e1 = 1.7, a0 = 0.75): it feathers the back of its rows and its tail horn and runs hot on the leading face itself).
	-- Rows run from the leading face (Lead x thick ahead of the arc) to the back (Tail x thick behind it); the core
	-- thread rides that leading face.
	Lens = { Thick = 0.62, Power = 0.8, Lead = 0.12, Tail = -1.0, Glow = 1.1, Alpha = 0.9, E0 = 0.65, E1 = 1.7, A0 = 0.75,
		Min = 0.02 },                        -- ASSUMED: studs of thickness kept at the horns (no zero-width band ends)
	-- THE ACCENT ARCS (v4 a1 / a2): thin bright arcs flanking the crescent, a little behind it
	Accents = {
		{ Radius = 1.45, Offset = 0.6 },     -- Offset: rad along the arc, toward the tail horn ...
		{ Radius = 1.10, Offset = -0.5 },    -- ... and toward the head horn
	},
	Accent = { Share = 0.55, Back = 0.6, Drop = 0.35, Width = 0.07, W0 = 0.1, W1 = 3.0, Power = 0.7,
		Fade = 0.8, Alpha = 0.6, Glow = 0.9, Fray = 0.6 },
	-- THE VAPOR WAKE (v4 path_ribbon over the blade's own path): 0.12 s of the kit's flight = 18 studs
	Wake = { Studs = 18, Head = 0.5, Tail = 1.2, Power = 0.35, Fade = 0.7, Alpha = 0.4, Fray = 0.8, MinStuds = 0.3 },
	-- THE SPIRAL WAKE (v5): two arcs half a turn apart corkscrewing behind, 0.07 s of the kit's flight = 10.5 studs;
	-- the angle and the radius run on the kit's "seconds behind" (studs / BlenderSpeed)
	Spiral = { Studs = 10.5, Twist = 60, R0 = 0.15, Grow = 2.2, Width = 0.06, Fade = 0.8, Alpha = 0.6, Glow = 0.9,
		Fray = 0.6 },
	BlenderSpeed = 150,                      -- the kit's blade speed (studs/s): converts its flight time into studs
	-- THE RIPPLE RING (v4 rip) left in the air RippleAt studs down the path
	Ripple = { At = 3.0, Time = 0.32, R0 = 0.3, Grow = 0.6, Width = 0.22, Min = 0.04, Fade = 0.45, Alpha = 0.4 },
	-- THE HIT (v4 imp, v6 cut, v5 scr). Placements against the contact are ASSUMED: the kit's dummy face sits
	-- 0.4-0.8 studs in front of its centre, the game's contact is on the body's surface
	Impact = { Time = 0.30, R0 = 0.4, Grow = 0.8, Width = 0.3, Min = 0.06, Fade = 0.6, Alpha = 0.5, Glow = 1.1,
		Toward = 0.2,                        -- ASSUMED: studs toward the shooter from the contact
		WallFade = 0.6 },                    -- ASSUMED: the ring on a wall, this much of a body's
	Cut = { Time = 0.32, Half = 1.6, Grow = 0.5, GrowTime = 0.05, Rise = 0.012, Tau = 0.09,
		Core = 0.07, CoreLoss = 0.04, Glow = 0.34, Power = 0.6, CoreGlow = 1.5, GlowGlow = 1.1, GlowFade = 0.8,
		GlowAlpha = 0.55, Fray = 0.1,
		Toward = 0.25 },                     -- ASSUMED: studs toward the shooter from the contact
	Scratch = { Count = 3, Grow = 0.08, R0 = 0.3, Length = 1.2, Width = 0.22, FadeFrom = 0.3, FadeTo = 0.55, Glow = 0.6,
		Fray = 0.3, Back = 1.0, Spin = 0.9, Step = 2.1, Lift = 0.05,
		Reach = 6 },                         -- PROVISIONAL: a hit this high over the floor or lower scratches it (the
		                                     -- kit's hit is 3.3 studs up on a smaller figure)
	HitLife = 0.55,                          -- s a hit's pieces can last (the scratches' fade ends here)
	-- THE HAND SWIRL (v4, tau < 0)
	Swirl = {
		On = true,                           -- v6 draws it (the toon kit's own swirl had been switched off)
		Time = 0.14,                         -- the kit's swirl length (s): k's Blender clock
		Late = 0.06,                         -- ASSUMED: not called at the press, it plays over this long after the release
		Gap = 0.15,                          -- a swirl started on that hand this recently is the press's (ZephyrFX SwirlGap)
		Near = 4,                            -- ASSUMED: ... if the release is within this many studs of it
		Linger = 0.10,                       -- ASSUMED: a press swirl whose release never comes ends this long after its lead
		Ahead = 0.25,                        -- studs in front of the palm (the kit's (0, 0.25, 0))
		Axis = { 0.5, 0.6, 0.62 },           -- its axis: (right x sg, forward, up), normalised
		R0 = 0.75, Shrink = 0.55, R1 = 0.22, Turn = 270, Spin = 30, Phase = 3,
		Core = { 0.07, 0.03 }, Glow = { 0.30, 0.12 },   -- widths, palm end -> outer end
		FadeIn = 0.3, CoreGlow = 0.9, GlowFade = 0.8, GlowAlpha = 0.6, Fray = 0.6,
		CoreFray = 0.4,                      -- the core thread frays over its outer 40% only (the kit's slot core tail)
	},
	-- THE RELEASE PUFF (v6 rp)
	Puff = { Count = 3, Ahead = 0.45, Speed = { 1.5, 3.5 }, Life = { 0.25, 0.45 }, Up = 0.1, Cone = 1.3, Size = { 0.4, 0.75 },
		Grow = 1 },                          -- 2x by death (the kit's P4 grow 1.0)
	-- THE DEBRIS (v4: per shot dust 5, speck 1, chips 2, sparks 3)
	Debris = {
		First = {                            -- the first body a blade cuts
			{ Kind = "dust", Count = 3, Speed = { 3, 7 }, Life = { 0.4, 0.8 }, Size = { 0.5, 0.9 }, Grow = 1 },
			{ Kind = "chip", Count = 2, Speed = { 4, 8 }, Life = { 0.5, 0.9 }, Size = { 0.6, 1.4 }, Lift = 0.3, Cone = 0.8 },
			{ Kind = "spark", Count = 3, Speed = { 5, 12 }, Life = { 0.2, 0.45 }, Size = { 0.4, 0.8 } },
		},
		Later = {                            -- every body after it (the kit's second dummy)
			{ Kind = "dust", Count = 2, Speed = { 2, 5 }, Life = { 0.4, 0.7 }, Size = { 0.6, 1.4 }, Grow = 1 },
		},
		Wall = {                             -- ASSUMED: what the world stopped (the kit has no wall)
			{ Kind = "dust", Count = 2, Speed = { 2, 5 }, Life = { 0.4, 0.7 }, Size = { 0.6, 1.4 }, Grow = 1 },
		},
		Up = 0.3,                            -- the kit's burst default, added to a throw's vertical
		Toward = 0.1,                        -- ASSUMED: studs toward the shooter from the contact
		Floor = {                            -- kicked off the floor under the path as the blade passes At studs
			{ At = 4, Kind = "speck", Count = 1, Speed = { 13, 15 }, Life = { 0.4, 0.4 }, Size = { 0.6, 1.4 }, Cone = 0.15, Up = 0.1 },
			{ At = 5, Kind = "dust", Count = 1, Speed = { 6, 6.5 }, Life = { 0.6, 0.6 }, Size = { 0.6, 0.6 }, Cone = 0.33, Up = 0.1, Grow = 1 },
			{ At = 9, Kind = "dust", Count = 1, Speed = { 6, 6.5 }, Life = { 0.6, 0.6 }, Size = { 0.6, 0.6 }, Cone = 0.33, Up = 0.1, Grow = 1 },
		},
		FloorReach = 6.5,                    -- PROVISIONAL: studs under the path the floor must be within (the kit flies
		                                     -- at 3.35 over its floor; a standing Roblox eye is about 4.5-5 up)
		FloorLift = 0.12,
	},
	WallPuff = true,                         -- ASSUMED: the world-stop ring and dust (false: a wall shows nothing)
	-- THE LIGHT (v6: one aqua light riding the newest blade; W -> Brightness is ZephyrDraw's, W / 600)
	Light = { Swirl = 140, Flight = 300, FlightTime = 0.4, Pierce = 300, PierceTau = 0.07, First = 380, FirstTau = 0.05,
		Range = 8, Flicker = 0.15, Drop = 0.3, Short = 1.5, Lead = 0.6,
		BurstGap = 0.3 },                    -- ASSUMED: a blade with none from its caster this long before starts a burst
	-- YOUR OWN VIEW
	HandLead = 0.6,                          -- studs down the shot from the viewmodel hand to your crescent's centre (the
	                                         -- kit's 0.6: the arc's horns then trail back past the hand, not into it)
	HandToward = 0.15,                       -- studs nearer the camera than a near hand, so the swirl / puff sit off the arm
	OwnNear = 6,                             -- a hand nearer the camera than this is drawn as your own (ZephyrFX FlashNear)
	OwnHandScale = 1.0,                      -- 2026-10-08: full size, as the kit draws them (was 0.6) (the kit draws them full
	                                         -- size at its viewmodel; check in Play that they do not cover the view)
	-- the per-shot micro-shake, your own only: e^(-tau / Decay) x sin(Osc tau + Phase) x (Pitch, +-Roll by hand), rad
	Kick = { Pitch = 0.010, Roll = 0.006, Decay = 0.035, Osc = 120, Phase = 0.6 },
	ReduceFlashing = { CutRise = 0.05, CutScale = 0.6, LightScale = 0.5 },   -- ASSUMED: the cut eases in, softer; the
	                                         -- pierce / first-hit light bumps halved
	WipeTime = 0.06,                         -- s a stopped crescent takes to go (ZephyrFX's WipeTime)
	-- KNOTS per piece (one Beam per span = knots - 1). The kit samples 11-30 points; these hold the budget above.
	Knots = { Lens = 5, LensRows = 5, Core = 5, Rim = 5, Accent = 3, Wake = 4, Spiral = 4, Swirl = 7, Cut = 3, Scratch = 2 },
	MaxDrawn = 16,                           -- blades drawn at once, by priority (drawFrame; the rest fly and hit, undrawn)
	CanvasKeep = 8,                          -- idle canvases kept per pool
	MaxLife = 3,                             -- s: a blade's look is dropped this long after its release, whatever it is doing
	-- studs over which a blade that leaves a hand off its line (the demo's third person) eases onto it: the kit's MERGE
	-- (blade_pos). Your own keeps ZephyrFX's Merge SECONDS (the own-view rule: off the viewmodel hand to the crosshair)
	Merge = 9,
	-- THE DEMO: the reel's whole hero take (spring/wind_blade_bl.py HERO_BURSTS, MACRO, dummy(); v5 knockback x1.5)
	Demo = {
		Bursts = {                           -- each burst's first press (clip s), its count and its opening hand
			{ At = 0.00, Count = 15, Hand = "R" },
			{ At = 2.70, Count = 10, Hand = "L" },
		},
		Rate = 0.125,                        -- the kit's 8 a second
		Lead = 0.80,                         -- the guard rises (CastPose WindBladeRise) this long before each burst
		Tail = 3.0,                          -- s after the last release the dummies take to settle (then put back exactly)
		AimCone = 40,                        -- dummies within this many deg of the facing
		AimUp = 0.3,                         -- studs above the dummy's root: the kit aims at its chest (3.3 up)
		AimFrom = { Fwd = 0.6, Up = 3.35 },  -- the kit's AIM_O: the aim line leaves 0.6 ahead of the root, 3.35 off the floor
		React = {                            -- the kit's dummy(): every hit leans it back and slides it away, then home
			Lean = 0.10, LeanTau = 0.14, LeanRise = 0.03, LeanMax = 0.38,   -- rad
			Slide = 0.16, SlideTau = 0.08, Hold = 0.35, Return = 0.8,       -- studs, s
			First = 1.5, Later = 0.9,        -- the amplitude on a blade's first body (kit dummy 1) / later ones (dummy 2)
		},
	},
}
WindBlade.Tuning = Tuning

----------------------------------------------------------------------------------------------------
-- MATHS (the kit's curves)
----------------------------------------------------------------------------------------------------
local sin, cos, exp, max, min, floor, pi, rad = math.sin, math.cos, math.exp, math.max, math.min, math.floor, math.pi,
	math.rad
local UP = Vector3.yAxis
local ZERO = Vector3.zero

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

--- ZephyrFX's smooth: u already 0..1
local function smooth(u)
	return u * u * (3 - 2 * u)
end

--- the kit's smooth(x, a, b): a smoothstep of x from a to b
local function sstep(x, a, b)
	return smooth(clamp01((x - a) / (b - a)))
end

--- the kit's span(t, a, b)
local function span(t, a, b)
	if b <= a then return (t >= b) and 1 or 0 end
	return clamp01((t - a) / (b - a))
end

--- the kit's ease_out (cubic)
local function easeOut(u)
	local v = 1 - clamp01(u)
	return 1 - v * v * v
end

local function lerp(a, b, u)
	return a + (b - a) * u
end

local function spow(x, e)
	if x <= 0 then return 0 end
	return x ^ e
end

local warnedKeys = {}
local function warnOnce(key, msg)
	if warnedKeys[key] then return end
	warnedKeys[key] = true
	warn("[ZephyrFX_WindBlade] " .. msg)
end

----------------------------------------------------------------------------------------------------
-- LAZY MODULES (nothing is required until a blade needs it, so the server never loads the look)
----------------------------------------------------------------------------------------------------
local ZD = nil                   -- IceMagic.ZephyrDraw; false once it failed to load
local function zd()
	if ZD == nil then
		local m = script.Parent and script.Parent:FindFirstChild("ZephyrDraw")
		if not m then
			warnOnce("zdmissing", "IceMagic.ZephyrDraw is not in the place (yet) - Wind Blades fly and hit, undrawn")
			return nil                   -- not cached: it may still be replicating
		end
		local ok, mod = pcall(require, m)
		ZD = (ok and type(mod) == "table") and mod or false
		if not ZD then
			warnOnce("zdload", "IceMagic.ZephyrDraw failed to load (" .. tostring(mod) .. ") - Wind Blades fly and hit, undrawn")
		end
	end
	return ZD or nil
end

local Gameplay = nil             -- ZephyrFX.Tuning.WindBlade (shared with ZephyrHandler, the server)
local function gp()
	if not Gameplay then
		Gameplay = require(script.Parent:WaitForChild("ZephyrFX")).Tuning.WindBlade
	end
	return Gameplay
end

local VFXLibrary = nil
local function lib()
	if not VFXLibrary then
		VFXLibrary = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("VFXLibrary"))
	end
	return VFXLibrary
end

local function timeScale()
	return lib().ShotTimeScale()
end

--- The FX folder, made when missing (as ZephyrFX's: the blade's own casts look through it).
local function fxFolder()
	local name = lib().Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local SpellshotSettings = nil
--- The settings store, or false when the place does not have it (never waits).
local function settings()
	if SpellshotSettings == nil then
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = folder and folder:FindFirstChild("SpellshotSettings")
		local ok, mod = false, nil
		if m then ok, mod = pcall(require, m) end
		SpellshotSettings = (ok and type(mod) == "table") and mod or false
	end
	return SpellshotSettings
end

local function reduceFlashing()
	local s = settings()
	if not (s and type(s.Get) == "function") then return false end
	local ok, v = pcall(s.Get, "ReduceFlashing")
	return ok and v == true
end

local Viewmodel = nil
--- The viewmodel (the demo's own hand), or nil; never waits.
local function viewmodel()
	if Viewmodel == nil then
		local m = script.Parent and script.Parent:FindFirstChild("Viewmodel")
		local ok, mod = false, nil
		if m then ok, mod = pcall(require, m) end
		Viewmodel = (ok and type(mod) == "table") and mod or false
	end
	return Viewmodel or nil
end

----------------------------------------------------------------------------------------------------
-- THE BODIES (moved verbatim from ZephyrFX)
----------------------------------------------------------------------------------------------------
--- Every body in the world -- players and training dummies -- so the blade's WIDE cast can be aimed at bodies alone
--- (an Include filter). A wide cast against everything would stop the blade on doorframes it used to fly past.
local bodies = {}                   -- [model] = true
local function watchBody(d)
	if d:IsA("Humanoid") then
		local m = d.Parent
		-- (2026-10-19, audit GC-05) a model stamped WallOwner (Terra's Bulwark Wall carries a Humanoid) is a wall, not a
		-- body: the blade stops on it rather than spending a pierce and flying on through
		if m and m:IsA("Model") and m:GetAttribute("WallOwner") == nil then bodies[m] = true end
	end
end
-- ZephyrFX built this when it was required; it is built here when this is (the ZephyrFX stub warms this module up on
-- the client as ZephyrFX loads, so the first blade of a session does not pay for the scan)
local watching = false
local function watchBodies()
	if watching then return end
	watching = true
	for _, d in ipairs(workspace:GetDescendants()) do watchBody(d) end
	workspace.DescendantAdded:Connect(watchBody)
end
if RunService:IsClient() then watchBodies() end

--- The bodies one blade may catch: everything above that is not already in its own exclude list (its caster, and
--- everyone Config.AddUnhurtable ruled out). Dead entries are pruned as it goes, so nothing has to watch removals.
local function bodyList(exclude)
	watchBodies()
	local skip = {}
	for _, inst in ipairs(exclude) do skip[inst] = true end
	local list = {}
	for m in pairs(bodies) do
		if not m.Parent then
			bodies[m] = nil
		elseif not skip[m] then
			list[#list + 1] = m
		end
	end
	return list
end

--- YOUR OWN blades, counted (the M1 hit-registration probe, 2026-09-17): how many left the hand, how many cut a body,
--- how many ended on the world. Written as attributes on ReplicatedStorage.IceMagic rather than kept in a local,
--- because a require from the command bar gets its own copy of this module and would always read zero. This is the
--- client half of the picture ServerStorage.ShotStats holds; only your own shots are counted, so it is 8 writes a
--- second at the full rate and nothing at all for anybody else's blades.
local function countOwn(name)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	if not ice then return end
	local k = "WB_" .. name
	ice:SetAttribute(k, (ice:GetAttribute(k) or 0) + 1)
end

----------------------------------------------------------------------------------------------------
-- WHAT THE LOOK IS TOLD (cosmetic notes the sweep and the step leave; never in a hit's way)
----------------------------------------------------------------------------------------------------
local blades, swirls, pending = {}, {}, {}
local serial, burstSerial = 0, 0

--- Queue a particle burst for this frame's burst canvas (ZephyrDraw's Burst, called exactly once, so no id: a canvas
--- would remember every id for the session). Graphics Quality and Reduce Enemy VFX are the engine's: your own blade's
--- bursts go on an Own canvas, everybody else's on one that Reduce Enemy VFX thins. `sizeMul` scales the sizes.
local function pushBurst(bl, kind, pos, n, spec, dir, sizeMul)
	if n <= 0 then return end
	burstSerial += 1
	local size = spec.Size
	if size and sizeMul and sizeMul ~= 1 then size = { size[1] * sizeMul, size[2] * sizeMul } end
	pending[#pending + 1] = {
		Kind = kind, Pos = pos, N = n, Own = bl.Own == true or bl.Friendly == true,   -- the canvas: audit P5F-06 below
		O = { speed = spec.Speed, life = spec.Life, size = size, dir = dir, cone = spec.Cone, grow = spec.Grow,
			up = spec.Up or Tuning.Debris.Up, seed = burstSerial },
	}
end

--- A body the blade cut: when (clip s from the release), where, and its debris.
local function noteHit(bl, hit)
	local hits = bl.Hits
	if not hits then return end
	local along = max(0, (hit.Position - bl.Origin):Dot(bl.Dir))
	local n = #hits + 1
	hits[n] = { Pos = hit.Position, Along = along, T = along / gp().Speed, Body = true, Index = n,
		LinePos = bl.Origin + bl.Dir * along,   -- the cut / impact ring centre: on the shot line (the kit's X), not the contact
		Model = hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model") }   -- (the demo's dummy reaction)
	if bl.Planned then return end
	local D = Tuning.Debris
	local at = hit.Position - bl.Dir * D.Toward
	for _, spec in ipairs((n == 1) and D.First or D.Later) do
		pushBurst(bl, spec.Kind, at, spec.Count, spec, spec.Lift and (bl.Dir + UP * spec.Lift).Unit or nil)
	end
end

--- The world stopped the blade (not its last pierce): the ring and a little dust on the wall.
local function noteWall(bl, pos)
	if not (Tuning.WallPuff and bl.Hits) then return end
	local along = max(0, (pos - bl.Origin):Dot(bl.Dir))
	bl.Hits[#bl.Hits + 1] = { Pos = pos, Along = along, T = along / gp().Speed, Wall = true, Index = #bl.Hits + 1 }
	if bl.Planned then return end
	local D = Tuning.Debris
	for _, spec in ipairs(D.Wall) do
		pushBurst(bl, spec.Kind, pos - bl.Dir * D.Toward, spec.Count, spec, nil)
	end
end

----------------------------------------------------------------------------------------------------
-- THE SWEEP (moved verbatim from ZephyrFX; the one cosmetic line now leaves a note for the look)
----------------------------------------------------------------------------------------------------
--- Casts the segment from -> to, piercing characters. Returns the point where the blade stopped, or nil.
--- TWO casts, because the blade is not a laser: a hairline ray for what STOPS it (the world), and a sphere of
--- HitRadius over the same segment, filtered to bodies alone, for what it CUTS. Whichever lies nearer along the shot
--- wins. The sphere's contact sits at most HitRadius off the line, inside the server's HitSlack, and each segment
--- carries on down the shot's own axis rather than from an off-axis contact.
--- The blade is past `model`: neither cast sees it again, and the next segment starts no nearer than its contact.
local function passBody(bl, model, hit, from)
	bl.Exclude[#bl.Exclude + 1] = model
	bl.Params.FilterDescendantsInstances = bl.Exclude
	if bl.WideList then
		for i = #bl.WideList, 1, -1 do
			if bl.WideList[i] == model then table.remove(bl.WideList, i) end
		end
		bl.WideParams.FilterDescendantsInstances = bl.WideList
	end
	local along = math.max((hit.Position - bl.Origin):Dot(bl.Dir), (from - bl.Origin):Dot(bl.Dir))
	return bl.Origin + bl.Dir * along
end

local function sweep(bl, from, to)
	local S = gp()
	local radius = S.HitRadius or 0
	for _ = 1, S.Pierce + 2 do
		local delta = to - from
		if delta.Magnitude < 1e-3 then return nil end
		local solid = workspace:Raycast(from, delta, bl.Params)
		local solidModel = solid and solid.Instance:FindFirstAncestorOfClass("Model")
		local solidHum = solidModel and solidModel:GetAttribute("WallOwner") == nil   -- (2026-10-19, GC-05) a wall is world
			and solidModel:FindFirstChildOfClass("Humanoid")
		local wide = nil
		if radius > 0 and bl.WideParams and bl.WideList and #bl.WideList > 0 then
			wide = workspace:Spherecast(from, radius, delta, bl.WideParams)
		end
		-- the NEARER of the two wins, a body on the hairline included (2026-10-07 audit: a body the ray met always lost
		-- to the sphere, so a target already inside the sphere where a segment starts -- point blank, which a shape cast
		-- cannot see -- was skipped for a body behind it, and the segment then carried on past it for good)
		local hit, model, humanoid
		if wide and (not solid
			or (wide.Position - bl.Origin):Dot(bl.Dir) <= (solid.Position - bl.Origin):Dot(bl.Dir)) then
			hit = wide                                   -- a body, caught by the blade's width
			model = wide.Instance:FindFirstAncestorOfClass("Model")
			humanoid = model and model:FindFirstChildOfClass("Humanoid")
		elseif solid then
			hit, model, humanoid = solid, solidModel, solidHum
		end
		if not hit then return nil end
		-- a body already down (a corpse waiting on its respawn) is air to the blade: not reported (the server would only
		-- refuse it), no pierce spent on it, no cut drawn on it
		if humanoid and humanoid.Health <= 0 then
			from = passBody(bl, model, hit, from)
			continue
		end
		-- the hit report first: nothing cosmetic may stand between a hit and the server hearing of it
		if bl.OnHit then task.spawn(bl.OnHit, hit) end
		if not humanoid then
			if bl.OnHit then countOwn("world") end
			return hit.Position
		end
		if bl.OnHit then countOwn("body") end
		-- someone else's blade meeting YOU gets no hit drawn: it would sit on your own camera
		local me = Players.LocalPlayer and Players.LocalPlayer.Character
		if model ~= me then pcall(noteHit, bl, hit) end
		bl.Pierced += 1
		if bl.Pierced >= S.Pierce then
			return hit.Position
		end
		from = passBody(bl, model, hit, from)
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- THE BLADE'S FRAME (shared by the live step and the frozen demo)
----------------------------------------------------------------------------------------------------
--- Where the blade's centre is `d` studs into its flight at clip time `tc`: on the shot line, plus the hand offset
--- (and, for your own, the camera's travel since the release) easing out -- the kit's blade_pos: over Tuning.Merge
--- studs, or your own over ZephyrFX's Merge seconds.
local function centreAt(bl, d, tc, travel)
	local p = bl.Origin + bl.Dir * d
	local off = bl.Offset
	if off then
		local u = d / Tuning.Merge             -- the kit's 9 studs for every blade (was Merge seconds for your own)
		local w = 1 - smooth(math.clamp(u, 0, 1))
		if w > 0 then p += (off + travel) * w end
	end
	return p
end

--- Your own blade's size: 1 until OwnShrinkFrom studs out, easing to OwnFarScale OwnShrinkOver studs further (ZephyrFX).
local function ownScale(bl, d)
	if not bl.Own then return 1 end
	local S = gp()
	local far = math.clamp((d - S.OwnShrinkFrom) / S.OwnShrinkOver, 0, 1)
	return 1 - (1 - S.OwnFarScale) * smooth(far)
end

--- A near hand (your own) is drawn smaller and a touch toward the camera: -> size multiplier, the point to draw at.
local function handFrame(p, camPos)
	if camPos then
		local v = camPos - p
		local m = v.Magnitude
		if m < Tuning.OwnNear and m > 1e-3 then
			return Tuning.OwnHandScale, p + v / m * Tuning.HandToward
		end
	end
	return 1, p
end

-- scratch arrays and option tables, reused every frame (ZephyrDraw reads them and keeps neither)
local BUF = {}
local function buf(key)
	local b = BUF[key]
	if not b then
		b = {}
		BUF[key] = b
	end
	return b
end
local function trim(t, n)
	for i = #t, n + 1, -1 do t[i] = nil end
	return t
end
local O_LENS, O_CORE, O_RIM, O_ACC = { tag = "lens" }, { tag = "core" }, { tag = "rim" }, { tag = "accent" }
local O_WAKE, O_SPIRAL, O_RIPPLE = { tag = "wake" }, { tag = "spiral" }, { tag = "ripple" }
local O_IMPACT, O_CUT, O_CUTG, O_SCR = { tag = "impact" }, { tag = "cut" }, { tag = "cut" }, { tag = "scratch" }
local O_SWC, O_SWG, O_LIGHT = { tag = "swirl" }, { tag = "swirl" }, {}

--- One blade's flight at clip time t: d studs flown, stopped at stopT (or nil), `travel` = your camera's move since the
--- release (zero for anybody else's). The kit's blade() of v4 + v5 + v6, piece by piece.
local function drawBlade(cv, bl, t, d, stopT, travel)
	local T = Tuning
	local G = gp()
	local K = T.Knots
	local fadeFrom, fadeTo = T.FadeFrom, T.FadeTo
	if bl.Own then fadeFrom, fadeTo = G.OwnFadeFrom or fadeFrom, G.OwnFadeTo or fadeTo end
	local fade = 1 - sstep(d, fadeFrom, fadeTo)
	if stopT then fade *= 1 - clamp01((t - stopT) / T.WipeTime) end
	local upS = bl.UpS
	local dv = bl.Sw or bl.Dir   -- the horns' sweep-back and the lens rows (bl.Sw: your own, turned to face you)
	if fade > 0.003 then
		local sc = ownScale(bl, d)
		local c = centreAt(bl, d, t, travel)
		local R, SPAN = bl.Radius * sc, bl.Span
		local st = 1 + T.Stretch * exp(-t / T.StretchTau)
		local back = T.Back * st
		-- THE LENS SLIVER (v5): an nu x nv "surf" Sheet, u along the arc (sa), v from the leading face to the back (ch)
		local L = T.Lens
		local nu, nv = K.Lens, K.LensRows
		local P = buf("lensP")
		for i = 1, nu do
			local sa = (i - 1) / (nu - 1)
			local a = (sa - 0.5) * SPAN
			local base = c + upS * (sin(a) * R) - dv * ((1 - cos(a)) * R * back)
			local thick = max(L.Min, L.Thick * spow(sin(pi * sa), L.Power) * st) * sc
			for j = 1, nv do
				P[(i - 1) * nv + j] = base + dv * (thick * lerp(L.Lead, L.Tail, (j - 1) / (nv - 1)))
			end
		end
		trim(P, nu * nv)
		O_LENS.fade, O_LENS.alpha, O_LENS.glow, O_LENS.maxSpans = fade, L.Alpha, L.Glow, nu - 1
		O_LENS.e0, O_LENS.e1, O_LENS.a0 = L.E0, L.E1, L.A0
		cv:Sheet(P, nu, nv, "surf", O_LENS)
		-- THE CORE THREAD on the leading face (v4 arc(R, fwd = 0.12)) and THE RIM (v4 g1; v5 dropped g2)
		local C, Rm = T.Core, T.Rim
		local n = K.Core
		local PC, WC = buf("coreP"), buf("coreW")
		for i = 1, n do
			local sa = (i - 1) / (n - 1)
			local a = (sa - 0.5) * SPAN
			PC[i] = c + upS * (sin(a) * R) - dv * ((1 - cos(a)) * R * back - C.Lead * sc)
			WC[i] = (C.Width * spow(sin(pi * sa), T.WidthPower) + C.Min) * sc
		end
		trim(PC, n)
		trim(WC, n)
		O_CORE.fade, O_CORE.glow, O_CORE.tail, O_CORE.maxSpans = fade, C.Glow, C.Fray, n - 1
		cv:Ribbon(PC, WC, "core", O_CORE)
		n = K.Rim
		local PR, WR = buf("rimP"), buf("rimW")
		for i = 1, n do
			local sa = (i - 1) / (n - 1)
			local a = (sa - 0.5) * SPAN
			PR[i] = c + upS * (sin(a) * R) - dv * ((1 - cos(a)) * R * back)
			WR[i] = (Rm.Width * spow(sin(pi * sa), T.WidthPower) + Rm.Min) * sc
		end
		trim(PR, n)
		trim(WR, n)
		O_RIM.fade, O_RIM.alpha, O_RIM.glow, O_RIM.tail, O_RIM.maxSpans = fade * Rm.Fade, Rm.Alpha, Rm.Glow, Rm.Fray, n - 1
		cv:Ribbon(PR, WR, "glow", O_RIM)
		-- THE ACCENT ARCS (v4 a1 / a2): a share of the span, offset along it, dropped back behind the crescent
		local A = T.Accent
		n = K.Accent
		O_ACC.fade, O_ACC.alpha, O_ACC.glow, O_ACC.tail, O_ACC.maxSpans = fade * A.Fade, A.Alpha, A.Glow, A.Fray, n - 1
		for ai, acc in ipairs(T.Accents) do
			local PA, WA = buf(ai == 1 and "acc1P" or "acc2P"), buf(ai == 1 and "acc1W" or "acc2W")
			local Ra = acc.Radius * sc
			for i = 1, n do
				local u = (i - 1) / (n - 1)
				local ss = (u - 0.5) * SPAN * A.Share + acc.Offset
				PA[i] = c + upS * (sin(ss) * Ra) - dv * ((1 - cos(ss)) * Ra * A.Back + A.Drop * sc)
				WA[i] = A.Width * spow(sin(lerp(A.W0, A.W1, u)), A.Power) * sc
			end
			trim(PA, n)
			trim(WA, n)
			cv:Ribbon(PA, WA, "arc", O_ACC)
		end
		if bl.Trail then
			-- THE VAPOR WAKE (v4 path_ribbon): the blade's own path back WakeStuds (or to the release), which drains
			-- into the stop point once the blade has stopped
			local W = T.Wake
			local run = G.Speed * t
			local dTail = math.clamp(run - min(W.Studs, run), 0, d)
			local wTail = W.Tail
			if bl.Own then   -- your own: it starts OwnWakeFrom studs out and thinner, so it does not bury the crescent
				dTail = math.clamp(math.max(dTail, G.OwnWakeFrom or 0), 0, d)
				wTail *= G.OwnWakeTail or 1
			end
			if d - dTail > W.MinStuds then
				n = K.Wake
				local PW, WW = buf("wakeP"), buf("wakeW")
				for k = 1, n do
					local u = (k - 1) / (n - 1)
					local dp = lerp(d, dTail, u)
					PW[k] = centreAt(bl, dp, dp / G.Speed, travel)
					WW[k] = lerp(W.Head, wTail, u) * spow(sin(pi * lerp(0.02, 0.98, u)), W.Power) * sc
				end
				trim(PW, n)
				trim(WW, n)
				O_WAKE.fade, O_WAKE.alpha, O_WAKE.tail, O_WAKE.maxSpans = fade * W.Fade, W.Alpha, W.Fray, n - 1
				cv:Ribbon(PW, WW, "vapor", O_WAKE)
			end
			-- THE SPIRAL WAKE (v5): two arcs, half a turn apart, round the path just behind the blade
			local Sp = T.Spiral
			n = K.Spiral
			O_SPIRAL.fade, O_SPIRAL.alpha, O_SPIRAL.glow, O_SPIRAL.tail, O_SPIRAL.maxSpans =
				fade * Sp.Fade, Sp.Alpha, Sp.Glow, Sp.Fray, n - 1
			for kk = 0, 1 do
				local P2 = buf(kk == 0 and "sp0" or "sp1")
				for k = 1, n do
					local s = Sp.Studs * (k - 1) / (n - 1)
					local tsB = s / T.BlenderSpeed
					local dp = math.clamp(run - s, 0, d)
					local ctr = centreAt(bl, dp, dp / G.Speed, travel)
					local ang = Sp.Twist * tsB + kk * pi
					local rr = (Sp.R0 + Sp.Grow * tsB) * sc
					P2[k] = ctr + bl.E1 * (rr * cos(ang)) + bl.E2 * (rr * sin(ang))
				end
				trim(P2, n)
				cv:Ribbon(P2, Sp.Width * sc, "arc", O_SPIRAL)
			end
		end
	end
	-- THE RIPPLE RING (v4 rip) left in the air near the hand: its own fade, not the blade's
	local Rp = T.Ripple
	local k = span(t, 0, Rp.Time)
	if k > 0 and k < 1 and bl.RippleAt then
		O_RIPPLE.fade, O_RIPPLE.alpha = (1 - k) * Rp.Fade, Rp.Alpha
		cv:RingK(bl.RippleAt, Rp.R0 + Rp.Grow * easeOut(k), bl.Dir, Rp.Width * (1 - k) + Rp.Min, "vapor", O_RIPPLE)
	end
end

--- The floor under a point, through bodies and effects: position, normal (or nil).
local function floorUnder(bl, p, reach)
	if not bl.FloorParams then return nil end
	local r = workspace:Raycast(p + UP * 0.25, UP * -(reach + 0.25), bl.FloorParams)
	if r and r.Normal.Y > 0.5 then return r.Position, r.Normal end
	return nil
end

--- A blade's hits at clip time t (v4 imp, v6 cut, v5 scr): each runs on its own clock from its contact.
local function drawHits(cv, bl, t, softFlash)
	local hits = bl.Hits
	if not hits or #hits == 0 then return end
	local T = Tuning
	local K = T.Knots
	local dv, upS = bl.Dir, bl.UpS
	local RF = T.ReduceFlashing
	for _, h in ipairs(hits) do
		local th = t - h.T
		if th >= 0 and th < T.HitLife then
			-- your own hits far off are drawn bigger (they sit at 30-80 studs, the kit's at 12) and the cut lingers a little
			local G = gp()
			local hs, tauK = 1, 1
			if bl.Own then
				hs = math.clamp(((h.LinePos or h.Pos) - bl.Origin).Magnitude / (G.OwnHitNear or 15), 1, G.OwnHitScaleMax or 1)
				tauK = G.OwnCutTau or 1
			end
			-- THE IMPACT VAPOR RING, facing the shot
			local I = T.Impact
			local k = span(th, 0, I.Time)
			if k < 1 then
				O_IMPACT.fade = (1 - k) * I.Fade * (h.Wall and I.WallFade or 1)
				O_IMPACT.alpha, O_IMPACT.glow = I.Alpha, I.Glow
				cv:RingK((h.LinePos or h.Pos) - dv * I.Toward, (I.R0 + I.Grow * easeOut(k)) * hs, dv, (I.Width * (1 - k) + I.Min) * hs, "vapor", O_IMPACT)
			end
			if h.Body then
				-- THE CUT LINE across the body along the blade's span: flashes in, fades out
				local Ct = T.Cut
				if th < Ct.Time then
					local rise = softFlash and RF.CutRise or Ct.Rise
					local f = sstep(th, 0, rise) * exp(-th / (Ct.Tau * tauK)) * (softFlash and RF.CutScale or 1)
					if f > 0.003 then
						local half = (Ct.Half + Ct.Grow * sstep(th, 0, Ct.GrowTime)) * hs
						local cc = (h.LinePos or h.Pos) - dv * Ct.Toward
						local n = K.Cut
						local PCt, WCt, WGt = buf("cutP"), buf("cutW"), buf("cutG")
						local coreW = Ct.Core - Ct.CoreLoss * th / Ct.Time
						for i = 1, n do
							local u = (i - 1) / (n - 1)
							local w = spow(sin(pi * lerp(0.04, 0.96, u)), Ct.Power)
							PCt[i] = cc + upS * lerp(-half, half, u)
							WCt[i] = coreW * w * hs
							WGt[i] = Ct.Glow * w * hs
						end
						trim(PCt, n)
						trim(WCt, n)
						trim(WGt, n)
						O_CUT.fade, O_CUT.glow, O_CUT.tail, O_CUT.maxSpans = f, Ct.CoreGlow, Ct.Fray, n - 1
						cv:Ribbon(PCt, WCt, "core", O_CUT)
						O_CUTG.fade, O_CUTG.alpha, O_CUTG.glow, O_CUTG.tail, O_CUTG.maxSpans =
							f * Ct.GlowFade, Ct.GlowAlpha, Ct.GlowGlow, Ct.Fray, n - 1
						cv:Ribbon(PCt, WGt, "glow", O_CUTG)
					end
				end
				-- THE SCRATCH MARKS (v5 scr): under the first body, if the floor is near; three radial lines growing out
				local Sc = T.Scratch
				if h.Index == 1 then
					if h.Floor == nil then
						local fp, fnrm = floorUnder(bl, h.Pos, Sc.Reach)
						h.Floor = fp and { Pos = fp, N = fnrm } or false
					end
					local fl = h.Floor
					local fadeS = 1 - sstep(th, Sc.FadeFrom, Sc.FadeTo)
					local g = span(th, 0, Sc.Grow)
					if fl and fadeS > 0.003 and g * Sc.Length > 0.02 then
						local nrm = fl.N
						local fy = dv - nrm * dv:Dot(nrm)
						fy = (fy.Magnitude > 1e-3) and fy.Unit or bl.Right:Cross(nrm).Unit   -- the floor's "forward"
						local fx = fy:Cross(nrm)                                              -- ... and its "right"
						local o = fl.Pos + nrm * Sc.Lift - fy * Sc.Back
						local n = K.Scratch
						local PS = buf("scrP")
						O_SCR.n, O_SCR.fade, O_SCR.glow, O_SCR.tail, O_SCR.maxSpans = nrm, fadeS, Sc.Glow, Sc.Fray, n - 1
						for j = 0, Sc.Count - 1 do
							local a0 = bl.Serial * Sc.Spin + j * Sc.Step
							local dr = fx * cos(a0) + fy * sin(a0)
							for i = 1, n do
								PS[i] = o + dr * lerp(Sc.R0 + Sc.Length * g, Sc.R0, (i - 1) / (n - 1))
							end
							trim(PS, n)
							cv:Ribbon(PS, Sc.Width, "scuff", O_SCR)
						end
					end
				end
			end
		end
	end
end

--- The swirl at a hand (v4, tau < 0) at swirl clock k (0 .. 1: k = 1 is the release): an open spiral winding into the
--- palm, its outer radius shrinking as it winds. `sg` the hand's sign, dir / up / right the shot's frame.
local function drawSwirl(cv, sg, hand, dir, up, right, k, camPos)
	if k <= 0 or k >= 1 then return end
	local Sw = Tuning.Swirl
	local hs, at = handFrame(hand, camPos)
	local tauB = (k - 1) * Sw.Time
	local ax = right * (Sw.Axis[1] * sg) + dir * Sw.Axis[2] + up * Sw.Axis[3]
	ax = ax.Unit
	local ctr = at + dir * (Sw.Ahead * hs)
	local d0 = ax:Cross(up)                          -- the kit's perp_any: axis x Z
	if d0.Magnitude < 1e-4 then d0 = ax:Cross(right) end
	d0 = d0.Unit
	local d1 = ax:Cross(d0)
	local r0 = Sw.R0 * (1 - Sw.Shrink * k) * hs
	local r1 = Sw.R1 * hs
	local a0 = Sw.Spin * tauB + Sw.Phase * sg
	local a1 = a0 - rad(Sw.Turn)
	local n = Tuning.Knots.Swirl
	local P, WC, WG = buf("swP"), buf("swC"), buf("swG")
	for i = 1, n do
		local s = (n - i) / (n - 1)                  -- reversed, as the kit's [::-1]: knot 1 = the palm end
		local a = lerp(a0, a1, s)
		P[i] = ctr + (d0 * cos(a) + d1 * sin(a)) * lerp(r0, r1, s)
		local u = (i - 1) / (n - 1)
		WC[i] = lerp(Sw.Core[1], Sw.Core[2], u) * hs
		WG[i] = lerp(Sw.Glow[1], Sw.Glow[2], u) * hs
	end
	trim(P, n)
	trim(WC, n)
	trim(WG, n)
	local f = sstep(k, 0, Sw.FadeIn)
	O_SWC.fade, O_SWC.glow, O_SWC.tail, O_SWC.maxSpans = f, Sw.CoreGlow, Sw.CoreFray or Sw.Fray, n - 1
	cv:Ribbon(P, WC, "core", O_SWC)
	O_SWG.fade, O_SWG.alpha, O_SWG.tail, O_SWG.maxSpans = f * Sw.GlowFade, Sw.GlowAlpha, Sw.Fray, n - 1
	cv:Ribbon(P, WG, "glow", O_SWG)
end

--- The shared light on one blade at clip t (0 <= t < FlightTime): its position and energy (W), or nil.
local function bladeLight(bl, t, d, travel, softFlash)
	local Lt = Tuning.Light
	if t < 0 or t >= Lt.FlightTime then return nil end
	local G = gp()
	-- it rides the blade, but stays Short studs this side of the first thing in its way (the kit: D1 - 1.5)
	local first = bl.Hits and bl.Hits[1]
	local limit = first and first.Along or math.huge
	local dl = math.clamp(min(d, limit - Lt.Short), 0, max(d, 0))
	local p = centreAt(bl, dl, dl / G.Speed, travel) - UP * Lt.Drop
	local e = Lt.Flight * (1 - t / Lt.FlightTime)
	local soft = softFlash and Tuning.ReduceFlashing.LightScale or 1
	if bl.Hits then
		for i, h in ipairs(bl.Hits) do
			local th = t - h.T
			if h.Body and th >= 0 then
				e += Lt.Pierce * exp(-th / Lt.PierceTau) * soft
				if i == 1 and bl.BurstFirst then e += Lt.First * exp(-th / Lt.FirstTau) * soft end
			end
		end
	end
	return p, e
end

local function setLight(cv, p, e)
	if not p or e <= 0.5 then return end
	local Lt = Tuning.Light
	O_LIGHT.range, O_LIGHT.flicker = Lt.Range, Lt.Flicker
	cv:Light(p, e, O_LIGHT)
end

--- A shot frame (dir, up, right) for a swirl that was not told its aim.
local function frameOf(dir)
	local up = UP - dir * dir.Y
	if up.Magnitude < 0.2 then up = Vector3.zAxis - dir * dir.Z end
	up = up.Unit
	return dir, up, dir:Cross(up)
end

----------------------------------------------------------------------------------------------------
-- CANVASES (pooled per kind: a blade's flight, a blade's hits; and three shared ones)
----------------------------------------------------------------------------------------------------
-- ZephyrDraw.Budgets.WindBlade (45 Beams, 1 light) is per blade in flight: a blade's flight and its hits each draw on
-- a canvas of their own under it. The swirls and the one light share the HANDS canvas (a light budget of 1: there is
-- one); the particle bursts go on two burst canvases, your own (Own: Graphics Quality only) and everybody else's
-- (Reduce Enemy VFX thins those too) -- the engine applies both per canvas.
local canvasPools = { WindBlade = {}, WindBladeHit = {} }
local HANDS_BUDGET = { Beams = 60, Lights = 1 }
local BURST_BUDGET = { Beams = 0, Lights = 0 }
local hands, burstsOwn, burstsOther = nil, nil, nil

local function takeCanvas(name)
	local pool = canvasPools[name]
	local cv = pool and table.remove(pool)
	if cv then return cv end
	local Z = zd()
	if not (Z and Z.new) then return nil end
	local ok, made = pcall(Z.new, name, nil, { Budget = "WindBlade" })
	return ok and made or nil
end

local function sharedCanvas(Z, name, own, budget)
	local ok, made = pcall(Z.new, name, nil, { Own = own, Budget = budget })
	return ok and made or nil
end

local function giveCanvas(name, cv)
	if not cv then return end
	pcall(function() cv:Clear() end)
	local pool = canvasPools[name]
	if pool and #pool < Tuning.CanvasKeep then
		pool[#pool + 1] = cv
	else
		pcall(function() cv:Destroy() end)
	end
end

local function freeCanvases(bl)
	giveCanvas("WindBlade", bl.Canvas)
	giveCanvas("WindBladeHit", bl.HitCanvas)
	bl.Canvas, bl.HitCanvas = nil, nil
end

--- One canvas's frame: Begin, the draw (guarded, so a failing piece never leaves the canvas open), End.
local function paint(cv, t, fn, ...)
	cv:Begin(t)
	local ok, err = pcall(fn, cv, ...)
	cv:End()
	if not ok then warnOnce("draw:" .. tostring(fn), "a Wind Blade piece failed to draw: " .. tostring(err)) end
end

----------------------------------------------------------------------------------------------------
-- THE LIVE STEP
----------------------------------------------------------------------------------------------------
-- After the camera and the viewmodel have moved for the frame (Camera + 3, as ZephyrFX's was), so a blade is swept and
-- placed against the view that is about to be drawn. Its own name: a pre-import ZephyrFX still in a place binds
-- "SpellshotWindBlades".
local STEP = "SpellshotWindBladesV6"
local bound = false
local stepWind

local function ensureBound()
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 3, stepWind)
	end
end

--- Whether a blade's look is over at clip t (stopped at stopT): the crescent gone, its trail drained, the ripple and the
--- light done, every hit's pieces done.
local function lookDone(bl, t, stopT)
	local T = Tuning
	if t > T.MaxLife then return true end
	if not stopT then return false end
	local last = max(stopT + max(T.WipeTime, T.Wake.Studs / gp().Speed), T.Ripple.Time, T.Light.FlightTime)
	local hits = bl.Hits
	if hits and #hits > 0 then last = max(last, hits[#hits].T + T.HitLife) end
	return t >= last
end

--- The floor debris along the path (v4 dust line + speck), kicked as the blade passes each mark.
local function kickFloor(bl)
	local D = Tuning.Debris
	local marks = D.Floor
	local i = bl.KickAt or 1
	while marks[i] and bl.Dist >= marks[i].At do
		local mk = marks[i]
		local p = centreAt(bl, mk.At, mk.At / gp().Speed, bl.Travel or ZERO)
		local fp = floorUnder(bl, p, D.FloorReach)
		if fp then
			local fwd = bl.Dir - UP * bl.Dir.Y
			fwd = (fwd.Magnitude > 1e-3) and fwd.Unit or bl.Dir
			pushBurst(bl, mk.Kind, fp + UP * D.FloorLift, mk.Count, mk, fwd)
		end
		i += 1
	end
	bl.KickAt = i
end

--- Which blade or press swirl the shared light rides: the newest, your own first.
local function lightCandidate(now, scale)
	local best, bestAt, bestOwn = nil, -math.huge, false
	local function offer(item, at, own)
		if (own and not bestOwn) or (own == bestOwn and at > bestAt) then
			best, bestAt, bestOwn = item, at, own
		end
	end
	local ft = Tuning.Light.FlightTime
	for _, bl in ipairs(blades) do
		local t = (now - bl.T0) * scale
		if t >= 0 and t < ft then offer(bl, bl.T0, bl.Own == true) end
	end
	for _, sw in ipairs(swirls) do
		if not (sw.Late or sw.Released) then
			offer(sw, sw.T0 + sw.Lead / math.max(scale, 1e-3), sw.Own == true)
		end
	end
	return best
end

--- Where a swirl's hand is now, or nil once it is gone.
local function swirlHand(sw)
	local at = sw.At
	if typeof(at) == "Vector3" then return at end
	if typeof(at) == "Instance" and at.Parent then
		if at:IsA("Attachment") then return at.WorldPosition end
		if at:IsA("BasePart") then return at.Position end
	end
	return nil
end

--- A swirl's aim: as told, else your camera's look for a hand near it, else its body's facing.
local function swirlDir(sw, hand, cam)
	if sw.Dir then return sw.Dir end
	local camCF = cam and cam.CFrame
	if camCF and (camCF.Position - hand).Magnitude < Tuning.OwnNear then return camCF.LookVector end
	local at = sw.At
	local model = typeof(at) == "Instance" and at:FindFirstAncestorOfClass("Model")
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if root then return root.CFrame.LookVector end
	return camCF and camCF.LookVector or Vector3.zAxis * -1
end

--- A swirl's clock k this frame (0 .. 1).
local function swirlK(sw, now, scale)
	local a = (now - sw.T0) * scale
	if sw.Late then return a / Tuning.Swirl.Late end
	-- the kit's clock: its 0.14 s wind-up ENDS at the release, so at the press (Lead before it) k is already
	-- 1 - Lead / Time (0.57 at Trigger 0.06): radius, spin, fade and light then match the kit at every instant
	return math.clamp(1 + (a - sw.Lead) / Tuning.Swirl.Time, 0, 0.999)
end

local function drawHands(cv, now, scale, cam, softFlash)
	local camPos = cam and cam.CFrame.Position
	for _, sw in ipairs(swirls) do
		local hand = swirlHand(sw)
		if hand and not sw.Released then
			local dir, up, right = frameOf(swirlDir(sw, hand, cam))
			drawSwirl(cv, sw.Sg, hand, dir, up, right, swirlK(sw, now, scale), camPos)
		end
	end
	-- the shared light
	local best = lightCandidate(now, scale)
	if best then
		if best.Swirl then
			local hand = swirlHand(best)
			if hand then
				local hs, at = handFrame(hand, camPos)
				local dir = swirlDir(best, hand, cam)
				setLight(cv, at + dir * (Tuning.Light.Lead * hs) - UP * Tuning.Light.Drop,
					Tuning.Light.Swirl * swirlK(best, now, scale))
			end
		else
			local t = (now - best.T0) * scale
			setLight(cv, bladeLight(best, t, best.Dist, best.Travel or ZERO, softFlash))
		end
	end
end

--- The bursts queued since the last frame whose blade is (`own`) / is not your own, each fired once.
local function fireBursts(cv, own)
	if not cv.Burst then return end
	for _, b in ipairs(pending) do
		if b.Own == own then
			local ok, err = pcall(cv.Burst, cv, b.Kind, b.Pos, b.N, b.O)
			if not ok then warnOnce("burst", "a Wind Blade burst failed: " .. tostring(err)) end
		end
	end
end

local function drawFrame(now, scale, cam)
	local Z = zd()
	if not Z then
		table.clear(pending)
		return
	end
	local softFlash = reduceFlashing()
	local camPos = cam and cam.CFrame.Position
	-- (2026-10-19, audit P5E-07) the MaxDrawn slots go by PRIORITY, not age: other players' blades still flying (the
	-- only telegraph of a hit coming at you), then yours still flying, then the stopped ones kept only for their hit's
	-- look -- each newest first. What is left over flies and hits, undrawn.
	local left = Tuning.MaxDrawn
	for _, bl in ipairs(blades) do bl.DrawOK = false end
	for pass = 1, 3 do
		for i = #blades, 1, -1 do
			if left <= 0 then break end
			local bl = blades[i]
			local flying = bl.StopT == nil
			if not bl.DrawOK and ((pass == 1 and flying and not bl.Own) or (pass == 2 and flying) or pass == 3) then
				bl.DrawOK = true
				left -= 1
			end
		end
	end
	for i = #blades, 1, -1 do
		local bl = blades[i]
		local t = (now - bl.T0) * scale
		bl.Travel = (bl.Own and bl.Offset and camPos and bl.CamStart) and (camPos - bl.CamStart) or ZERO
		if not bl.Planned then
			local ok, err = pcall(kickFloor, bl)
			if not ok then warnOnce("kick", "the Wind Blade floor debris failed: " .. tostring(err)) end
		end
		if bl.DrawOK and bl.UpS then
			bl.Canvas = bl.Canvas or takeCanvas("WindBlade")
			if bl.Canvas then paint(bl.Canvas, t, drawBlade, bl, t, bl.Dist, bl.StopT, bl.Travel) end
			if #bl.Hits > 0 then
				bl.HitCanvas = bl.HitCanvas or takeCanvas("WindBladeHit")
				if bl.HitCanvas then paint(bl.HitCanvas, t, drawHits, bl, t, softFlash) end
			end
		elseif bl.Canvas or bl.HitCanvas then
			freeCanvases(bl)
		end
	end
	if Z.new then
		hands = hands or sharedCanvas(Z, "WindBladeHands", true, HANDS_BUDGET)
		if #pending > 0 then
			burstsOwn = burstsOwn or sharedCanvas(Z, "WindBladeBursts", true, BURST_BUDGET)
			burstsOther = burstsOther or sharedCanvas(Z, "WindBladeBursts", false, BURST_BUDGET)
		end
	end
	if hands then paint(hands, now * scale, drawHands, now, scale, cam, softFlash) end
	if #pending > 0 then
		if burstsOwn then paint(burstsOwn, now * scale, fireBursts, true) end
		if burstsOther then paint(burstsOther, now * scale, fireBursts, false) end
	end
	table.clear(pending)
end

stepWind = function()
	local S = gp()
	local now = os.clock()
	local scale = timeScale()
	-- THE FLIGHT AND THE HITS (moved verbatim from ZephyrFX's stepWind): every blade is swept before anything is drawn
	for i = #blades, 1, -1 do
		local bl = blades[i]
		local t = (now - bl.T0) * scale
		if not bl.StoppedAt then
			local dist = math.min(S.Speed * t, S.Range)
			if dist > bl.Dist then
				local stop = sweep(bl, bl.Origin + bl.Dir * bl.Dist, bl.Origin + bl.Dir * dist)
				if stop then
					dist = math.max(0, (stop - bl.Origin):Dot(bl.Dir))
					bl.StoppedAt = now
					-- the look's note: the WORLD stopped it (a last pierce stops it with Pierced == Pierce)
					if bl.Pierced < S.Pierce then pcall(noteWall, bl, stop) end
				elseif dist >= S.Range then
					bl.StoppedAt = now
				end
				bl.Dist = dist
			end
			if bl.StoppedAt then bl.StopT = t end
		end
		-- dropped only once it has STOPPED (as ZephyrFX's were), and then when its look is over
		local ok, done = pcall(lookDone, bl, t, bl.StopT)
		if bl.StoppedAt and (done or not ok) then
			table.remove(blades, i)
			freeCanvases(bl)
		end
	end
	-- the swirls: a press swirl ends on its release (or Linger after its lead), a late one when it has wound
	for i = #swirls, 1, -1 do
		local sw = swirls[i]
		local a = (now - sw.T0) * scale
		local over = sw.Released or (sw.Late and a >= Tuning.Swirl.Late)
			or (not sw.Late and a >= sw.Lead + Tuning.Swirl.Linger) or swirlHand(sw) == nil
		if over then table.remove(swirls, i) end
	end
	local ok, err = pcall(drawFrame, now, scale, workspace.CurrentCamera)
	if not ok then warnOnce("frame", "the Wind Blade look failed this frame: " .. tostring(err)) end
	if #blades == 0 and #swirls == 0 then
		if hands then pcall(function() hands:Clear() end) end   -- (the burst canvases' particles fly on)
		table.clear(pending)
		RunService:UnbindFromRenderStep(STEP)
		bound = false
	end
end

----------------------------------------------------------------------------------------------------
-- A BLADE
----------------------------------------------------------------------------------------------------
local lastFire = setmetatable({}, { __mode = "k" })   -- [caster key] = os.clock() of its last blade

--- The caster behind somebody else's blade: the first Model in its exclude list (AbilityFX puts the caster there).
local function casterKey(list)
	for i = 2, #list do
		local inst = list[i]
		if typeof(inst) == "Instance" and inst:IsA("Model") then return inst end
	end
	return "other"
end

--- The look's own fields on a new blade: its hand, its crescent's frame, its floor probe, its burst.
local function prepareLook(bl, opts)
	local T = Tuning
	serial += 1
	bl.Serial = serial
	if opts and opts.Own ~= nil then bl.Own = opts.Own == true else bl.Own = bl.OnHit ~= nil end
	bl.Planned = (opts and opts.Planned == true) or false
	bl.Trail = (not bl.Own) or gp().OwnTrail == true
	bl.Sg = T.HandSign[bl.Side] or 1
	local arc = T.Arc[bl.Side] or T.Arc.R
	bl.Radius, bl.Span = arc.Radius, rad(arc.Span)
	bl.Right = bl.Dir:Cross(bl.Up)
	local tilt = rad(T.Tilt) * bl.Sg
	local upS = bl.Right * sin(tilt) + bl.Up * cos(tilt)
	bl.UpS = upS   -- every stroke the kit's crescent (the hot horn low): the kit has no up-stroke look, and the arm plays one flick
	-- 2026-10-09: your own blade flies down your eye line, so a crescent swept back along Dir lies in a plane through the
	-- camera and reads as a flat dash (the lens edge-on). Its sweep is turned toward the screen: OwnSweepMix of Dir, the
	-- rest across the view (dv x upS, by hand), so the curve, the lens and the hot leading face all face you
	if bl.Own then
		local m = gp().OwnSweepMix or 1
		local across = bl.Dir:Cross(upS) * bl.Sg
		if m < 1 and across.Magnitude > 1e-3 then bl.Sw = (bl.Dir * m + across.Unit * (1 - m)).Unit else bl.Sw = nil end
	else
		bl.Sw = nil
	end
	bl.E1, bl.E2 = bl.Right, bl.Dir:Cross(bl.Right)   -- the spiral wake's frame (the kit's dv x Z, dv x e1)
	bl.RippleAt = centreAt(bl, T.Ripple.At, T.Ripple.At / gp().Speed, ZERO)
	-- the floor probes look through every body and the effects
	local seeThrough = table.clone(bl.Exclude)
	for _, m in ipairs(bl.WideList) do seeThrough[#seeThrough + 1] = m end
	local fp = RaycastParams.new()
	fp.FilterType = Enum.RaycastFilterType.Exclude
	fp.FilterDescendantsInstances = seeThrough
	fp.IgnoreWater = true
	bl.FloorParams = fp
	bl.KickAt = 1
	-- the first blade of a burst (v4 flashes the first hit of each burst)
	local key = bl.Own and "own" or casterKey(bl.Exclude)
	-- (2026-10-19, audit P5F-06) a teammate's blade bursts on the Own canvas too: Reduce Enemy VFX thins an enemy's only
	do
		local Z = zd()
		bl.Friendly = typeof(key) == "Instance" and Z ~= nil and type(Z.Friendly) == "function" and Z.Friendly(key) == true
	end
	local last = lastFire[key]
	bl.BurstFirst = (last == nil) or ((bl.T0 - last) * timeScale() > T.Light.BurstGap)
	if not bl.Planned then lastFire[key] = bl.T0 end
end

--- A blade, set up exactly as ZephyrFX.FireWindBlade set one up (the look's fields added), not yet flying.
local function newBlade(origin, dir, exclude, visualFrom, onHit, side, stroke, opts)
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 then return nil end
	dir = dir.Unit
	side = (side == "L") and "L" or "R"
	stroke = (stroke == "Up") and "Up" or "Down"
	local cam = workspace.CurrentCamera
	local up = Vector3.yAxis - dir * dir.Y
	if up.Magnitude < 0.2 then
		local alt = cam and cam.CFrame.UpVector or Vector3.zAxis
		up = alt - dir * dir:Dot(alt)
		if up.Magnitude < 1e-3 then up = Vector3.xAxis - dir * dir.X end
	end
	local folder = fxFolder()
	local list = { folder }
	for _, inst in ipairs(exclude or {}) do list[#list + 1] = inst end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	-- the blade's WIDTH: a second filter holding the bodies alone, for the sphere in `sweep` above
	local wideList = bodyList(list)
	local wideParams = RaycastParams.new()
	wideParams.FilterType = Enum.RaycastFilterType.Include
	wideParams.FilterDescendantsInstances = wideList
	local bl = {
		Origin = origin, Dir = dir, Up = up.Unit,
		Dist = 0, Params = params, Exclude = list, Pierced = 0, OnHit = onHit,
		WideList = wideList, WideParams = wideParams,
		CamStart = cam and cam.CFrame.Position or origin, T0 = os.clock(),
		Side = side, Stroke = stroke, Hand = visualFrom or origin, Hits = {},
	}
	if visualFrom then
		-- the crescent's centre a touch down the shot from the hand (the kit's d = 0.6), easing onto the line over Merge
		bl.Offset = visualFrom + dir * Tuning.HandLead - origin
	end
	local ok, err = pcall(prepareLook, bl, opts)
	if not ok then warnOnce("prep", "a Wind Blade's look could not be set up: " .. tostring(err)) end
	return bl
end

--- The press swirl on this hand that a release at `at` hands over from, if there is one.
local function pressSwirl(side, at, now, scale)
	local Sw = Tuning.Swirl
	for _, sw in ipairs(swirls) do
		if not sw.Late and not sw.Released and sw.Side == side and (now - sw.T0) * scale <= Sw.Gap then
			local hand = swirlHand(sw)
			if hand and (hand - at).Magnitude <= Sw.Near then return sw end
		end
	end
	return nil
end

--- The release's beat at the hand: the swirl (unless the press already wound one there), the puff, your own shake.
local function releaseLook(bl)
	local T = Tuning
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	if T.Swirl.On then
		local pre = pressSwirl(bl.Side, bl.Hand, bl.T0, timeScale())
		if pre then
			pre.Released = true
		else
			swirls[#swirls + 1] = { Swirl = true, Side = bl.Side, Sg = bl.Sg, At = bl.Hand, Dir = bl.Dir, T0 = bl.T0,
				Late = true, Own = bl.Own, Lead = 0 }
		end
	end
	local P = T.Puff
	local hs, at = handFrame(bl.Hand, camPos)
	pushBurst(bl, "puff", at + bl.Dir * (P.Ahead * hs), P.Count, P, bl.Dir, hs)
	if bl.Own and not bl.Planned then
		local Z = zd()
		if Z and type(Z.CameraKick) == "function" then
			local K = T.Kick
			Z.CameraKick({ pitch = K.Pitch, roll = K.Roll * ((bl.Side == "R") and 1 or -1), decay = K.Decay,
				osc = K.Osc, phase = K.Phase })
		end
	end
end

----------------------------------------------------------------------------------------------------
-- PUBLIC
----------------------------------------------------------------------------------------------------
--- THE SWIRL at a casting hand, ahead of its release: called at the press, it winds over the press-to-release lead
--- (Trigger) and hands over to the blade that leaves that hand; a release with no swirl ahead of it plays one after.
function WindBlade.WindBladeSwirl(position, side, stroke, dir)
	if not RunService:IsClient() then return end
	side = (side == "L") and "L" or "R"
	stroke = (stroke == "Up") and "Up" or "Down"
	if not Tuning.Swirl.On then return end
	local kind = typeof(position)
	if kind ~= "Vector3" and not (kind == "Instance" and (position:IsA("BasePart") or position:IsA("Attachment"))) then
		return
	end
	local cam = workspace.CurrentCamera
	local sw = {
		Swirl = true, Side = side, Stroke = stroke, Sg = Tuning.HandSign[side] or 1, At = position,
		Dir = (typeof(dir) == "Vector3" and dir.Magnitude > 0.1) and dir.Unit or nil,
		T0 = os.clock(), Lead = gp().Trigger, Late = false,
	}
	local hand = swirlHand(sw)
	sw.Own = hand ~= nil and cam ~= nil and (cam.CFrame.Position - hand).Magnitude < Tuning.OwnNear
	swirls[#swirls + 1] = sw
	ensureBound()
end

--- `origin` along `dir` is the shot itself; `visualFrom`, when given, is where the blade is SEEN to leave (the
--- slashing hand in first person): it starts there and eases onto the true line over Merge. `onHit(result)`, when
--- given, is called for every character the blade passes through and for what finally stops it: that makes it this
--- client's own shot, reported to the server. `side` is the slashing hand ("L" / "R") and `stroke` its direction
--- ("Down" / "Up"). (ZephyrFX.FireWindBlade's contract, unchanged; `opts` is this module's own, for the demo.)
local function fireBlade(origin, dir, exclude, visualFrom, onHit, side, stroke, opts)
	if not RunService:IsClient() then return nil end
	local bl = newBlade(origin, dir, exclude, visualFrom, onHit, side, stroke, opts)
	if not bl then return nil end
	local ok, err = pcall(releaseLook, bl)
	if not ok then warnOnce("release", "a Wind Blade's release look failed: " .. tostring(err)) end
	blades[#blades + 1] = bl
	if onHit then countOwn("fired") end             -- your own blade: the probe's denominator
	ensureBound()
	return bl
end

function WindBlade.FireWindBlade(origin, dir, exclude, visualFrom, onHit, side, stroke, opts)
	fireBlade(origin, dir, exclude, visualFrom, onHit, side, stroke, opts)
end

----------------------------------------------------------------------------------------------------
-- THE DEMO (StarterPlayerScripts.ZephyrTestHarness): the reel's whole hero take on a character, no server
----------------------------------------------------------------------------------------------------
local demo = nil

local CastPoseMod = nil
--- CastPose (the body's clips), or nil; never waits.
local function castPose()
	if CastPoseMod == nil then
		local m = script.Parent and script.Parent:FindFirstChild("CastPose")
		local ok, mod = false, nil
		if m then ok, mod = pcall(require, m) end
		CastPoseMod = (ok and type(mod) == "table") and mod or false
	end
	return CastPoseMod or nil
end

function WindBlade.StopDemo()
	if demo then
		local d = demo
		demo = nil
		pcall(d.Stop)
	end
end

--- The training dummy a character faces (within Demo.AimCone of `look`, within Range): its root's position, or nil.
local function demoTarget(eye, look, character)
	watchBodies()
	local best, bestDot = nil, math.cos(rad(Tuning.Demo.AimCone))
	for m in pairs(bodies) do
		if m.Parent and m ~= character and m:GetAttribute("TrainingDummy") then
			local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
			if root then
				local v = root.Position - eye
				local dist = v.Magnitude
				if dist > 1 and dist <= gp().Range then
					local dot = v.Unit:Dot(look)
					if dot > bestDot then
						best, bestDot = root.Position, dot
					end
				end
			end
		end
	end
	return best
end

--- The take's shots: Demo.Bursts (or one burst of opts.Shots), the hands alternating from each burst's opening hand and
--- each hand's strokes Down, Up, Down ... from the burst's start (SpellshotInput's order). -> shots, bursts
local function demoShots(opts)
	local D = Tuning.Demo
	local bursts = D.Bursts
	local n = tonumber(opts.Shots)
	if n then bursts = { { At = 0, Count = math.max(1, floor(n)), Hand = "R" } } end
	local shots = {}
	for _, b in ipairs(bursts) do
		local strokes = { R = "Down", L = "Down" }
		local other = (b.Hand == "R") and "L" or "R"
		for j = 0, b.Count - 1 do
			local side = (j % 2 == 0) and b.Hand or other
			local press = b.At + j * D.Rate
			shots[#shots + 1] = { Side = side, Stroke = strokes[side], Press = press, Release = press + gp().Trigger }
			strokes[side] = (strokes[side] == "Down") and "Up" or "Down"
		end
	end
	return shots, bursts
end

-- THE DUMMY'S REACTION (the kit's dummy(): the server's knockback, played locally). It moves two joints of the rig on
-- this client only: the Root joint (R15: HumanoidRootPart.RootRigAttachment; R6: RootJoint.C0) slides the body away
-- along the shot, the Waist (R15) leans the torso back -- the root part itself never moves, and every joint is put
-- back exactly when the take ends or stops.
local function jointRef(j)
	if not j then return nil end
	if j:IsA("Motor6D") then
		return j.Part0 and { Inst = j, Prop = "C0", Part = j.Part0, Orig = j.C0 } or nil
	end
	local ok, a0 = pcall(function() return j.Attachment0 end)
	if ok and a0 and a0.Parent and a0.Parent:IsA("BasePart") then
		return { Inst = a0, Prop = "CFrame", Part = a0.Parent, Orig = a0.CFrame }
	end
	return nil
end

local function reactRig(model)
	local lower, upper = model:FindFirstChild("LowerTorso"), model:FindFirstChild("UpperTorso")
	local root = model:FindFirstChild("HumanoidRootPart")
	local r = {
		Root = jointRef((lower and lower:FindFirstChild("Root")) or (root and root:FindFirstChild("RootJoint"))),
		Waist = jointRef(upper and upper:FindFirstChild("Waist")),
	}
	return r.Root and r or nil
end

local function setJoint(ref, cf)
	pcall(function() ref.Inst[ref.Prop] = cf end)
end

--- The kit's dummy() at clip t: per hit k s ago, lean += A Lean e^(-k / LeanTau) smooth(k / LeanRise) and
--- slide += A Slide (1 - e^(-k / SlideTau)); the slide eases home e^(-(t - last - Hold) / Return); lean <= LeanMax.
local function reaction(hits, t)
	local R = Tuning.Demo.React
	local lean, slide, last = 0, 0, nil
	for _, h in ipairs(hits) do
		local k = t - h.At
		if k >= 0 then
			lean += h.Amp * R.Lean * exp(-k / R.LeanTau) * smooth(clamp01(k / R.LeanRise))
			slide += h.Amp * R.Slide * (1 - exp(-k / R.SlideTau))
			last = last and max(last, h.At) or h.At
		end
	end
	if last then slide *= exp(-max(0, t - last - R.Hold) / R.Return) end
	return min(lean, R.LeanMax), slide
end

--- Pose a dummy's joints: slid `slide` studs along `dirFlat`, its top tipped `lean` rad away along it.
local function applyReaction(rig, dirFlat, lean, slide)
	local root, waist = rig.Root, rig.Waist
	local axis = UP:Cross(dirFlat)                   -- about this, +lean tips the top along the shot
	local function tip(ref)
		local ax = (ref.Part.CFrame * ref.Orig):VectorToObjectSpace(axis)
		return CFrame.fromAxisAngle(ax.Unit, lean)
	end
	local cf = CFrame.new(root.Part.CFrame:VectorToObjectSpace(dirFlat * slide)) * root.Orig
	if waist then
		setJoint(waist, waist.Orig * tip(waist))
	else
		cf *= tip(root)
	end
	setJoint(root, cf)
end

--- Demo(character, opts): the reel's hero take (spring/wind_blade_bl.py HERO_BURSTS / MACRO) on `character`. The guard
--- rises 0.8 s before each burst (CastPose WindBladeRise), every press plays the body's flick (CastPose
--- WindBlade<Stroke><Side>) -- and in first person the viewmodel's (ArmClips.WindSlash<Stroke>) -- and winds the swirl at
--- the hand, every release fires a blade, and every dummy a blade cuts leans back and slides away as the kit's do
--- (opts.NoReact: not). In FIRST PERSON (your own character, the camera at its head) the blades are your own: they
--- leave the viewmodel hand onto the crosshair, no trail, the micro-shake. Otherwise they are the kit's third person
--- exactly: from the body's hands onto the aim line from the chest (Demo.AimFrom) over the kit's 9 studs, wake and spiral
--- wake drawn. Nothing is reported to the server. opts.Freeze = clip seconds from the first press: that one frame, held
--- until Stop; opts.Shots = one burst of that many; opts.NoPose = no body / viewmodel clips.
function WindBlade.Demo(character, opts)
	WindBlade.StopDemo()
	opts = opts or {}
	if not RunService:IsClient() then return nil end
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return nil end
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not root then return nil end
	local T, G, D = Tuning, gp(), Tuning.Demo
	local player = Players.LocalPlayer
	local isLocal = player ~= nil and character == player.Character
	local hum = character:FindFirstChildOfClass("Humanoid")

	local function firstPerson()
		local head = character:FindFirstChild("Head")
		local c = workspace.CurrentCamera
		return isLocal and head ~= nil and c ~= nil and (c.CFrame.Position - head.Position).Magnitude < 2
	end
	-- the floor under the root: the kit's z = 0
	local function floorDepth()
		if hum and hum.RigType == Enum.HumanoidRigType.R15 then return hum.HipHeight + root.Size.Y / 2 end
		return root.Size.Y / 2 + 2
	end
	-- the hand a blade leaves: the viewmodel's in first person, the body's otherwise (the point, and the part to follow)
	local function handOf(side, fp)
		local part = character:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
			or character:FindFirstChild(side == "L" and "Left Arm" or "Right Arm")
		if fp then
			local vm = viewmodel()
			if vm and type(vm.GetMuzzleCFrame) == "function" then
				local ok, cf = pcall(vm.GetMuzzleCFrame, side)
				if ok and typeof(cf) == "CFrame" then return cf.Position, nil end
			end
		end
		return part and part.Position or root.Position, part
	end
	local cam = workspace.CurrentCamera
	local fp0 = firstPerson()
	local target = demoTarget(fp0 and cam.CFrame.Position or root.Position,
		fp0 and cam.CFrame.LookVector or root.CFrame.LookVector, character)
	if target then target += UP * D.AimUp end
	local exclude = { character }
	if isLocal and cam then exclude[2] = cam end
	--- one shot's line now: origin, dir, the hand (point, part), first person
	local function shotOf(sh)
		local fp = firstPerson()
		local hand, part = handOf(sh.Side, fp)
		local origin, look
		if fp then
			local c = workspace.CurrentCamera
			origin, look = c.CFrame.Position, c.CFrame.LookVector
		else
			origin = (root.CFrame * CFrame.new(0, D.AimFrom.Up - floorDepth(), -D.AimFrom.Fwd)).Position
			look = root.CFrame.LookVector
		end
		local aim = target and (target - origin) or look
		local dir = (aim.Magnitude > 1e-3) and aim.Unit or look
		return origin, dir, hand, part, fp
	end
	local shots, bursts = demoShots(opts)

	local freeze = tonumber(opts.Freeze)
	if freeze then
		-- ONE FRAME, held: every shot planned (its whole flight swept at once, nothing reported, no particles), drawn
		-- at its own clock at `freeze` clip seconds from the first press
		local Z = zd()
		if not Z then return nil end
		for _, sh in ipairs(shots) do
			local origin, dir, hand, _, fp = shotOf(sh)
			sh.Hand, sh.Dir = hand, dir
			if sh.Release <= freeze then
				local bl = newBlade(origin, dir, exclude, hand, nil, sh.Side, sh.Stroke, { Own = fp, Planned = true })
				if bl then
					bl.T0 = 0
					local stop = sweep(bl, bl.Origin, bl.Origin + bl.Dir * G.Range)
					if stop then
						bl.StopDist = math.max(0, (stop - bl.Origin):Dot(bl.Dir))
						if bl.Pierced < G.Pierce then pcall(noteWall, bl, stop) end
					else
						bl.StopDist = G.Range
					end
					bl.StopAt = bl.StopDist / G.Speed
					sh.Blade = bl
				end
			end
		end
		local function frame(cv, t)
			local camNow = workspace.CurrentCamera
			local camPos = camNow and camNow.CFrame.Position
			local soft = reduceFlashing()
			local light, lightP, lightE = -math.huge, nil, 0
			for _, sh in ipairs(shots) do
				local tb = t - sh.Release
				if tb < 0 then
					if tb > -T.Swirl.Time and T.Swirl.On then
						local k = 1 + tb / T.Swirl.Time   -- the kit's wind-up: the Swirl.Time before the release
						local dir, up, right = frameOf(sh.Dir)
						drawSwirl(cv, T.HandSign[sh.Side] or 1, sh.Hand, dir, up, right, k, camPos)
						if sh.Release > light then
							local hs, at = handFrame(sh.Hand, camPos)
							light, lightP, lightE = sh.Release, at + dir * (T.Light.Lead * hs) - UP * T.Light.Drop,
								T.Light.Swirl * k
						end
					end
				elseif sh.Blade then
					local bl = sh.Blade
					local d = min(G.Speed * tb, bl.StopDist)
					local stopT = (tb >= bl.StopAt) and bl.StopAt or nil
					if not lookDone(bl, tb, stopT) then
						bl.Dist = d
						drawBlade(cv, bl, tb, d, stopT, ZERO)
						drawHits(cv, bl, tb, soft)
						if tb < T.Light.FlightTime and sh.Release > light then
							local p, e = bladeLight(bl, tb, d, ZERO, soft)
							if p then light, lightP, lightE = sh.Release, p, e end
						end
					end
				end
			end
			setLight(cv, lightP, lightE)
			return true
		end
		-- the frame's blades on ONE canvas: at 8 a second at most ~5 are alive at once (WindBlade's 45 Beams each, 1 light)
		local budget = { Beams = 45 * 8, Lights = 1 }
		local handle
		if type(Z.Demo) == "function" then
			handle = Z.Demo("WindBladeDemo", frame, { Freeze = freeze, Own = fp0, Budget = budget })
		elseif type(Z.Play) == "function" then
			handle = Z.Play("WindBladeDemo", frame, { Clock = function() return freeze end, MaxLife = 3600,
				Own = fp0, Budget = budget })
		end
		if not handle then return nil end
		demo = { Stop = function() if handle.Stop then handle:Stop() end end }
		return demo
	end

	-- LIVE: the take on the clock (clip t = 0 is the first press; the lead-in runs from -Lead)
	local token = { Dead = false }
	local start = os.clock()
	local lead = D.Lead
	local fired = {}                                   -- the take's blades (their hits drive the dummies)
	local function at(t, fn)
		task.delay(math.max(0, (t + lead) / timeScale()), function()
			if token.Dead or not character.Parent then return end
			local ok, err = pcall(fn)
			if not ok then warnOnce("demobeat", "a Wind Blade demo beat failed: " .. tostring(err)) end
		end)
	end
	local CP = (not opts.NoPose) and castPose() or nil
	if CP and type(CP.Play) == "function" then
		for _, b in ipairs(bursts) do                  -- the guard rises: RELAX -> DIP -> GUARD
			at(b.At - lead, function() CP.Play(character, "WindBladeRise") end)
		end
	end
	for _, sh in ipairs(shots) do
		at(sh.Press, function()
			local _, dir, hand, part, fp = shotOf(sh)
			if CP and type(CP.Play) == "function" then CP.Play(character, "WindBlade" .. sh.Stroke .. sh.Side) end
			if fp and not opts.NoPose then
				local vm = viewmodel()
				if vm and type(vm.PlayShot) == "function" then vm.PlayShot(sh.Side, "WindSlash" .. sh.Stroke) end
			end
			WindBlade.WindBladeSwirl(part or hand, sh.Side, sh.Stroke, dir)
		end)
		at(sh.Release, function()
			local origin, dir, hand, _, fp = shotOf(sh)
			local bl = fireBlade(origin, dir, exclude, hand, nil, sh.Side, sh.Stroke, { Own = fp })
			if bl then fired[#fired + 1] = bl end
		end)
	end

	-- the dummies' reaction, every frame until the take's tail
	local stepName = "ZephyrWindBladeDemoReact"
	local rigs = {}                                    -- [model] = { Rig, Hits = { {At, Amp} }, Dir }
	local lastRelease = shots[#shots].Release
	local bound = false
	local function finish()
		token.Dead = true
		if bound then
			bound = false
			pcall(RunService.UnbindFromRenderStep, RunService, stepName)
		end
		for _, r in pairs(rigs) do
			if r.Rig then
				setJoint(r.Rig.Root, r.Rig.Root.Orig)
				if r.Rig.Waist then setJoint(r.Rig.Waist, r.Rig.Waist.Orig) end
			end
		end
		table.clear(rigs)
	end
	local function react()
		local scale = timeScale()
		local t = (os.clock() - start) * scale - lead
		if token.Dead or t > lastRelease + D.Tail then
			finish()
			return
		end
		for _, bl in ipairs(fired) do
			for i = (bl.DemoSeen or 0) + 1, #bl.Hits do
				local h = bl.Hits[i]
				local m = h.Body and h.Model
				if m and m ~= character then
					local r = rigs[m]
					if not r then
						r = { Rig = reactRig(m), Hits = {} }
						rigs[m] = r
					end
					r.Hits[#r.Hits + 1] = { At = (bl.T0 - start) * scale - lead + h.T,
						Amp = (h.Index == 1) and D.React.First or D.React.Later }
					local f = bl.Dir - UP * bl.Dir.Y
					if f.Magnitude > 1e-3 then r.Dir = f.Unit end
				end
			end
			bl.DemoSeen = #bl.Hits
		end
		for m, r in pairs(rigs) do
			if r.Rig and r.Dir and m.Parent then
				local lean, slide = reaction(r.Hits, t)
				local ok, err = pcall(applyReaction, r.Rig, r.Dir, lean, slide)
				if not ok then warnOnce("react", "the Wind Blade demo's dummy reaction failed: " .. tostring(err)) end
			end
		end
	end
	if not opts.NoReact then
		bound = true
		RunService:BindToRenderStep(stepName, Enum.RenderPriority.Character.Value + 2, react)
	end
	demo = { Stop = finish }
	return demo
end

return WindBlade
