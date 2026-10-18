--[[
	ZephyrUpdraft  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrUpdraft        Zephyr v6 import, 2026-10-06

	UPDRAFT, Zephyr's Passive. The manual (Section 2): "bonus damage and bonus knockback while airborne". SHARED by the
	server and every client, the way TerraFX.Tuning is: one Tuning table, one airborne rule, and the client's tell.

	THE RULE (decided on the SERVER, ServerScriptService.ZephyrUpdraftServer):
	  WHO       a player whose Element is Zephyr, once SpellshotConfig.PartialKits.Zephyr.Passive is true (Holds: the same
	            Element-decides-the-Passive rule TerraHandler's isTerra uses for Bedrock -- there is no Passive slot to
	            equip). The server mirrors it onto the CHARACTER as ZephyrPassive = "Updraft" (Bedrock's precedent:
	            the server decides, a character attribute tells every client), and that attribute is what the tell reads.
	  AIRBORNE  at least MinClearance studs of air under the feet (a short downward SPHERE cast from the root, so a foot on
	            a ledge the root hangs past still counts as standing), and not climbing, swimming or seated; on the local
	            client the engine's FloorMaterial must also be Air (see Airborne for why the server does not ask it).
	            AirGrace: a hit or a knock this soon after the last airborne Heartbeat still counts -- a blade released
	            at the top of a jump that lands as the feet touch down.
	  DAMAGE    x DamageMult on every hit the holder lands while airborne (CombatCore.AddModifier, ModifierPriority:
	            after Mark and Toxin's amplifiers, before every armour and soak). Not a DoT tick (info.DoT), not their
	            own body, and not a hit whose info carries NoUpdraft = true (the opt-out for a kit that should not get it).
	  KNOCKBACK x KnockbackMult on Zephyr's knockbacks while airborne: KnockbackScale(player), which ZephyrHandler multiplies
	            into the velocity it sends (INTEGRATION wires it; this module never moves a body).
	  THE HIT   every hit the bonus raised broadcasts UpdraftHit { Character, At, T0, Victim } (at most one per HitPulseGap
	            per player): the pulse that climbs the body, and the mark on the victim.

	THE TELL (client, every client, for every airborne Updraft holder; a straight port of the Blender kit onto
	IceMagic.ZephyrDraw -- blender_scripts/zephyr/aqua/updraft_v6.py on top of updraft_v5.py on top of updraft_v4.py, the
	clock functions from blender_scripts/zephyr/spring/updraft_bl.py). On its own clock: real seconds from the take-off
	(the jump is physics: the filming slow-down cannot slow it, Gust Jump's rule), t = 0 when the feet left the floor.
	  PRESENCE  builds 0 -> 1 over Build (0.12 s) from the take-off, thins over Thin (0.42 s) from the landing, (1-k)^1.6
	  v4        the rising helix round the legs: 1 core thread, 3 glow ribbons, 3 hairline arcs, head at the TOP (the air
	            rises), turning at 7.5 rad/s; specks (40/s) and sparkles (14/s) lift off round the feet; an aerial hit
	            sends a ring PULSE up the helix in 0.25 s and puffs off the body; a soft vapor ring spills off the feet on
	            landing; take-off and landing dust
	  v5        the helix climbs the torso too (2 glow ribbons); a downward-facing DISC of swirling wind under the feet (a
	            turning Sheet + 3 spiral arms + dust swirling in it, 25/s); ribbons trailing from both ankles (glow + core,
	            0.3 s of the ankle's own path); on landing a downdraft puff and a scuff ring
	  v6        it GROWS with height: glow x (0.72 + 0.5 h), presence x (0.75 + 0.25 h), the disc reaching 0.8 -> 1.15 x
	            wider (h = feet height / ApexHeight, the default jump's apex); it FLASHES at the apex: a waist ring (core
	            + glow, 1.3 -> 2.8 studs over 0.33 s), an 18-spark pop, the helix and disc surging x 1.9 (tau 0.16 s);
	            an aqua light under the feet, (120 + 420 h) W x presence, +1100 W at the apex (W / 600 = Brightness)
	  OWN VIEW  (your own body, seen from your own eyes) subtle: only the disc (its Sheet, arms and dust) and the ankle
	            ribbons, which sit below the camera and read when you look down; the light at Tell.OwnView.Light of its
	            level. The helix, the torso helix, the pulse ring, the apex ring and the floor marks would all wrap the
	            camera and are not drawn there.
	  THE VICTIM  a small spark + puff mark on the body an airborne hit landed on (v4's hit burst), on every screen.
	Budget (ZephyrDraw canvas "Updraft", plan section 3: <= 110 Beams, 1 light): the helix 5 + 15 + 12, the torso 8,
	the disc 8 bands x 3 spans = 24, the arms 12, the ankles 12 -> 88 steady, plus the pulse ring and the apex rings
	(<= 24) on their beats. Each layer's spans are capped in Tell (Spans / MaxSpans); the own view draws 48.

	WHO CALLS IT
	  ZephyrUpdraftServer (server)   Tuning, Holds, Airborne, NoteAirborne, IsAirborne
	  ZephyrHandler (server)         KnockbackScale(player): multiply each Zephyr knockback velocity by it
	  ZephyrClient (client)          Handlers (merged into AbilityFX), LocalCast (none: a Passive has no key), Init/Bind
	  ZephyrTestHarness (client)     Demo(character, opts)

	API
	  ZephyrUpdraft.Tuning
	  ZephyrUpdraft.Holds(player) -> bool                  the rule (Element + PartialKits), server or client
	  ZephyrUpdraft.HoldsCharacter(character) -> bool      the character attribute the server keeps (the client's test)
	  ZephyrUpdraft.Clearance(character, depth?) -> clearance, groundPos?, feetY   studs of air under the feet (or depth)
	  ZephyrUpdraft.Airborne(character, useFloor?) -> bool, clearance
	  ZephyrUpdraft.NoteAirborne(player, now?)             the server's Heartbeat memory (AirGrace)
	  ZephyrUpdraft.IsAirborne(player) -> bool             airborne now, or within AirGrace of it
	  ZephyrUpdraft.KnockbackScale(player) -> number       KnockbackMult while a holder is airborne, else 1
	  ZephyrUpdraft.DamageScale(player) -> number          DamageMult while a holder is airborne, else 1 (readouts only)
	  ZephyrUpdraft.Handlers = { UpdraftHit = fn(d) }      client
	  ZephyrUpdraft.LocalCast = {}                         client (empty)
	  ZephyrUpdraft.Init(bindings) / .Bind(bindings)       client, idempotent: starts the watcher
	  ZephyrUpdraft.Demo(character, opts) -> handle{Stop}  client: the Blender hero shot on that character, no server --
	      the stand, THE DIP, the push, the jump along the Blender arc (the root lifted, yawing as the showcase's does),
	      riding the wind, the wind-up, THE FLICK (a Wind Blade crescent from the right hand to the dummy), the aerial
	      hit (a stand-in dummy 15 studs ahead / 2 right takes it and staggers back, updraft_bl DKEYS; a real
	      TrainingDummy standing there is used instead), the apex flash, the pulse climbing the helix, the fall, the
	      landing squash and the tell thinning away. The body plays CastPose UpdraftJump and your own arms Viewmodel
	      UpdraftJump on the same clock, which is the filming clock (ZephyrDraw.TimeScale x opts.Speed).
	      opts.Freeze = clip s (hold one frame until Stop) | opts.Speed (clip rate x, 1) | opts.Lift (own body: false =
	      do not lift it, the tell draws on a ghost path, no body clip) | opts.Full (own body: draw the whole tell, not
	      the own-view cut) | opts.Dummy = false (no stand-in) | opts.Jump = true (no clip: make your own character jump
	      for real and draw the LIVE tell on it for 4 s, held or not -- the watcher's real path, real heights)
	  THE BODY (live, Tell.Pose.Live): a holder's real jump plays CastPose UpdraftRide from the take-off (the push into
	      the riding shape, held) and UpdraftLand on the landing -- only while no other clip owns that body; every client
	  ZephyrUpdraft.StopDemo()                             client: stops the demo that is up (puts a lifted body back)

	NOT LIKE BLENDER (ZephyrDraw Beams, not Blender meshes; see ZEPHYR_V6_HANDOFF section 5)
	  * the disc is a 4 x 8 Sheet (Blender: 10 x 22): 8 spiral wedges, each as wide as the gap between its neighbours,
	    carrying the source's 2.7 rad twist root to rim, in ZephyrDraw's "surf" kind with the disc's own mat_surf
	    constants (e0 0.5, e1 1.6, a0 0.6) -- the kind itself fades the trailing `ch` side (it spins with the disc) and
	    feathers the rim, as mat_surf does; the source's fray 0.3 is the texture's
	  * the particles cannot ride the Blender flow field: each stream's emitter orbits its ring every frame and is aimed
	    along the field AT that point (the caster's velocity + the funnel's lift + its counter-clockwise swirl), so they
	    rise and swirl as the field throws them; they are ParticleEmitter bursts, not deterministic
	  * v4's 250 W flash light at the dummy is the blade's own impact (Wind Blade lights its pierce): dropped here, the
	    canvas has one light. The Demo's stand-in dummy is six anchored local blocks (no rig, no Humanoid), posed per
	    frame from DKEYS by plain box maths, and destroyed with the Demo
	  * the body's poses are the showcase's hand / foot targets turned into CastPose channels by IK chords (Arm / In from
	    the arm's swing plane, Hip / Knee from the leg's chord, Waist / Turn / Drop from the spine and hips); CastPose
	    has no hip abduction or pelvis pitch, so the legs stay under the hips and the pelvis tilt rides the Waist
	  * the in-game jump (JumpHeight 7.2, Gravity 64: about 0.95 s of air) is not the Blender jump (7.0 studs, 1.4 s);
	    every beat is in real seconds from the take-off, the apex is where the body actually turns, and h is read live
	  * every ZephyrDraw call is pcall-guarded per method (call()): a missing or failing layer is skipped with one warning
	    and never stops a mechanic -- or the rest of the tell. The calls follow ZephyrDraw's own header (2026-10-06):
	    o.alpha is za's zk_alpha as it is, a burst's size is za's multiple of the kind's size, a stream's pos / dir /
	    speed / rate are live per frame, and Reduce Flashing steadies and dims the light inside ZephyrDraw

	Every gameplay number is PROVISIONAL (v6 import). Nothing here runs on require: the client's watcher starts at Init
	(or the first broadcast or Demo), ZephyrDraw and SpellshotConfig are required lazily, and on the server nothing in
	the client half ever runs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_CLIENT = RunService:IsClient()
local UP = Vector3.yAxis
local sin, cos, exp, max, min, pi = math.sin, math.cos, math.exp, math.max, math.min, math.pi

local ZephyrUpdraft = {}

----------------------------------------------------------------------------------------------------
-- TUNING (shared with ZephyrUpdraftServer; the look numbers are the Blender kit's, with their source)
----------------------------------------------------------------------------------------------------
local T = {
	Element = "Zephyr",
	Attribute = "ZephyrPassive",   -- the character attribute the server keeps: "Updraft" while its player holds it
	DamageMult = 1.25,             -- PROVISIONAL (v6 import): x every hit landed while airborne
	KnockbackMult = 1.5,           -- PROVISIONAL (v6 import): x Zephyr's knockbacks while airborne (KnockbackScale)
	MinClearance = 1.5,            -- PROVISIONAL (v6 import): studs of air under the feet before it counts as airborne
	AirGrace = 0.1,                -- PROVISIONAL (v6 import): s after the last airborne Heartbeat a hit still counts
	ProbeRadius = 0.9,             -- PROVISIONAL (v6 import): the downward sphere cast's radius (an R15's feet are +-0.5)
	ModifierPriority = -6,         -- after Umbra's Mark (-10) and Toxin's amplifier (-8), before Bedrock (1) and soaks
	HitPulseGap = 0.3,             -- PROVISIONAL (v6 import): s between two UpdraftHit broadcasts per player (8 blades a
	                               --   second would restart the 0.25 s pulse before it ever reached the top)
	FXFolderName = "IceMagicFX",   -- fallback; VFXLibrary.Config.FXFolderName wins when readable (never ground)

	Tell = {
		Build = 0.12,              -- updraft_bl.tell_on: presence builds 0 -> 1 over this from the take-off (s) ...
		Thin = 0.42,               -- ... and thins over this from the landing ...
		ThinPow = 1.6,             -- ... front-loaded: (1 - k) ^ ThinPow
		EndAfter = 1.3,            -- the episode ends this long after the landing (the scuff ring is gone by 1.2 s)
		MinPresence = 0.004,       -- below this nothing of the tell's body is drawn (the kit's e <= 0.004)
		LandClearance = 0.35,      -- airborne ends at this little air under the feet (or the engine's floor, own body)
		ProbeDepth = 40,           -- studs probed below the feet for the height ratio (deeper = h 1)
		ApexHeight = nil,          -- studs of feet height that are h = 1; nil = the default jump's apex, read from
		                           --   StarterPlayer (JumpHeight, or JumpPower^2 / 2g): 7.2 today (Blender: H_PK 7.0)
		MaxDistance = 220,         -- a tell further than this from the camera is not drawn (still tracked)
		ScanEvery = 0.25,          -- s between scans for holders (the ZephyrPassive attribute)
		InHub = true,              -- false: no tell on a body whose player's Zone is "Hub"
		SuppressWhile = { "SkyriderT0" },   -- character attributes: while any is truthy the tell thins away as if landed.
		                           --   SkyriderT0 is set for the whole ride (ZephyrSkyriderServer): the disc and helix
		                           --   would cut through the bird's back. Only the LOOK -- the bonus still applies.
		ReduceFlashing = 0.5,      -- Reduce Flashing (ZD.Calm): the apex surge of the helix / disc glow and the waist
		                           --   ring x this (ZephyrDraw calms the light itself: no flicker, x its CalmLight)
		AlphaRef = 1.0,            -- ZephyrDraw's o.alpha IS za's zk_alpha (its header: 0.5 = the kind's own opacity,
		                           --   "port the Blender values as they are"): o.alpha = the kit's alpha / AlphaRef
		Axis = { Right = 0.05, Fwd = 0.15 },   -- updraft_bl.axis_c: the feet plane nudged under the tucked knees

		Kinds = { Core = "core", Glow = "glow", Hair = "arc", Disc = "surf", Vapor = "vapor", Scuff = "scuff" },

		-- updraft_v6.Piece.spiral: everything of the tell's body grows with the height ratio h and surges at the apex
		Grow = { GlowBase = 0.72, GlowPerH = 0.5, Surge = 0.9, FadeBase = 0.75, FadePerH = 0.25 },

		-- updraft_v4.Piece.spiral: strands i = 0..6, kind 0 the core thread, 1..3 glow ribbons, 4..6 hairline arcs
		Helix = {
			Spans = { Core = 5, Glow = 5, Hair = 4 },
			Top = 3.2, TopStep = 0.3,      -- z from Top - TopStep x kind (the head, the top: the air rises) ...
			Bottom = -0.5,                 -- ... down to here (below the feet)
			Phase = 2.1, KindPhase = { 0.0, 0.4, 1.1 },
			Spin = 7.5, SpinStep = 0.3,    -- rad/s x (1 + SpinStep x kind)
			Twist = 1.1, TwistStep = 0.25, -- rad per stud of height
			R0 = 1.55, RSlope = 0.18,      -- radius (R0 - RSlope z) ...
			KindR = { 0.75, 1.0, 1.15 },   -- ... x this per kind ...
			Flare = 0.15,                  -- ... x (1 + Flare x i) (the source's `0.15 * i % 2`, which never wraps for i <= 6)
			CoreW = 0.10, GlowW = { 0.5, 0.25 }, HairW = 0.06,
			GlowFade = 0.85, HairFade = 0.8, Alpha = 0.6, HairGlow = 0.9,
			CoreTail = 0.5, GlowTail = 0.55, HairTail = 0.7,
			PulseGlow = 0.5,               -- glow x (1 + PulseGlow x the pulse) while the aerial-hit pulse climbs
		},
		-- updraft_v5.Piece.spiral: the helix climbs the torso too
		Torso = {
			Count = 2, Spans = 4, Top = 5.2, Bottom = 1.8, Spin = 6.5, Twist = 1.0, R0 = 1.75, RSlope = 0.08,
			W = { 0.55, 0.2 }, Fade = 0.75, Alpha = 0.55, Glow = 1.1, PulseGlow = 0.5, Tail = 0.5,
		},
		-- updraft_v5 disc (Sheet 10 x 22 closed, mat_surf e0 0.5 e1 1.6 a0 0.6) + updraft_v6's reach
		Disc = {
			Rings = 4, Around = 8,         -- the Sheet's rows (root -> rim) and columns (round, closed)
			R = { 0.5, 2.6 }, Spin = 5.0,
			Twist = 2.7,                   -- rad from the root ring to the rim (0.3 per ring over the source's 10)
			Drop = 0.45, Dish = 0.25,      -- z = -(Drop + Dish (r / 2.6)^2): downward-facing, curling down at the rim
			Glow = 1.15, Alpha = 0.62,     -- (the source's fray 0.3 has no ZephyrDraw counterpart: the surf texture frays)
			E0 = 0.5, E1 = 1.6, A0 = 0.6,  -- mat_surf("za5_disc", e0 = 0.5, e1 = 1.6, a0 = 0.6): the "surf" kind's constants
			Reach = { 0.8, 0.35, 0.15 },   -- v6: radius x (0.8 + 0.35 h + 0.15 apex)
		},
		Arms = {                           -- updraft_v5 darms: 3 spiral arms flat under the feet
			Count = 3, Spans = 4, Spin = 7.0, Sweep = math.rad(260), R = { 0.4, 2.8 }, Drop = 0.5,
			W = { 0.18, 0.45 }, Alpha = 0.65, Glow = 1.2, Tail = 0.5,
		},
		Ankle = {                          -- updraft_v5: path_ribbon from each ankle, glow and core
			Dur = 0.3, Points = 8, Spans = 3,
			GlowW = { 0.45, 0.1 }, CoreW = { 0.08, 0.02 }, Alpha = 0.6, Glow = 1.1, Tail = 0.6,
			History = 32, SampleDt = 1 / 90,   -- the ankle path kept per body: >= 0.35 s at any frame rate
		},
		Pulse = {                          -- updraft_bl pulse_* + updraft_v4's ring
			Time = 0.25, In = 0.03, Z0 = -1.35, Z1 = 2.85,
			R0 = 1.75, RSlope = 0.15, W = 0.32, Glow = 1.4, Alpha = 0.7, Spans = 4,
			MaxLag = 0.15,                 -- s of broadcast latency taken off the pulse's start (more is ignored)
		},
		Apex = {                           -- updraft_v6: peak(t) and the waist ring
			Rise = 0.03, Tau = 0.16,       -- smooth(t, tpk - Rise, tpk) x exp(-(t - tpk) / Tau)
			RiseSpeed = 3,                 -- studs/s up before the turn counts as an apex ...
			MinClear = 2.5,                -- ... at least this high (a hop off a step does not flash) ...
			Rearm = 1.0,                   -- ... and once per rise: a new one only after rising again this long after
			Waist = 2.4, R0 = 1.3, Grow = 1.5, Lead = 0.01, Dur = 0.32,
			CoreW = 0.10, CoreW0 = 0.02, CoreGlow = 1.4,
			GlowW = 0.55, GlowShrink = 0.5, GlowFade = 0.85, GlowAlpha = 0.6, GlowGlow = 1.2, GlowR = 1.02,
			Spans = 4,
		},
		Land = {                           -- updraft_v5 scuff ring + updraft_v4 dring
			ScuffLift = 0.03, ScuffR0 = 1.6, ScuffGrow = 1.2, ScuffDur = 0.6, ScuffW = 0.6, ScuffGlow = 0.6,
			ScuffFadeFrom = 0.8, ScuffFadeTo = 1.2,
			RingLift = 0.1, RingR0 = 1.2, RingGrow = 2.0, RingDur = 0.5, RingW = 0.6, RingW0 = 0.1, RingFade = 0.5,
			RingAlpha = 0.45, Spans = 4,
		},
		Light = { Base = 120, PerH = 420, Apex = 1100, Lift = 0.2, Range = 10, Flicker = 0.15 },   -- updraft_v6.draw
		OwnView = { Light = 0.5 },         -- your own tell's light x this (the floor under you, not your eyes)
		Hit = { MarkLife = 1.0 },          -- s the victim mark's canvas lives (its longest particle)

		-- particles: za.burst's arguments verbatim (size = a multiple of the kind's own size); streams at the kit's rates
		Particles = {
			SizeIsMultiplier = true,       -- ZephyrDraw's o.size: za's multiplier of the kind's own size (true), or studs
			KindBase = { speck = 0.07, spark = 0.36, dust = 1.1, puff = 0.6 },   -- za.KINDS base sizes (studs), for false
			Lift = 6.0, Swirl = 9.0,       -- updraft_bl.field: the funnel's lift and swirl (studs/s) the streams ride
			TakeoffSpeed = 8,              -- a take-off rising faster than this kicks the floor dust (not a walk off a ledge)
			Speck = { Rate = 40, R = 1.2, Z = { -0.3, 1.0 }, Up = 4, Life = { 0.4, 0.8 }, Size = { 1, 1 }, Orbit = 17.3 },
			Spark = { Rate = 14, R = 0.9, Z = { 0.0, 2.0 }, Up = 3, Life = { 0.35, 0.6 }, Size = { 0.35, 0.6 }, Orbit = 13.1 },
			DiscDust = { Rate = 25, R = 1.6, Z = -0.6, Down = 1, Inflow = 0.8, SwirlK = 0.93, Life = { 0.5, 0.5 },
				Size = { 0.5, 0.8 }, Orbit = 19.7 },
			Takeoff = { N = 14, Lift = 0.2, Speed = { 4, 9 }, Life = { 0.6, 1.1 }, Up = 0.02, Seed = 1 },
			LandDust = { N = 12, Lift = 0.2, Speed = { 3, 7 }, Life = { 0.6, 1.0 }, Up = 0.02, Seed = 2 },
			Downdraft = { N = 16, Lift = 0.3, Speed = { 5, 10 }, Life = { 0.5, 0.9 }, Up = -0.2, Seed = 9 },
			ApexSparks = { N = 18, Lift = 2.6, Speed = { 4, 9 }, Life = { 0.25, 0.55 }, Up = 0.0, Size = { 0.4, 0.8 },
				Seed = 17 },
			HitPuffs = { N = 6, Lift = 1.0, Delay = 0.03, Speed = { 1, 3 }, Life = { 0.4, 0.8 }, Up = 1.0, Seed = 5 },
			MarkSparks = { N = 10, Speed = { 5, 12 }, Life = { 0.25, 0.55 }, Up = 0.3, Size = { 0.6, 1.4 }, Seed = 3 },
			MarkPuffs = { N = 5, Speed = { 2, 5 }, Life = { 0.4, 0.8 }, Up = 0.3, Size = { 0.6, 1.4 }, Seed = 4 },
		},

		-- the body and the arms: CastPose / Viewmodel clips (ADD-ONLY blocks in those modules, from updraft_bl KEYS / FPK)
		Pose = {
			Live = true,                   -- a holder's real jumps ride in the showcase's shape: UpdraftRide from the take-off
			                               --   (clocked on it), UpdraftLand on the landing -- only while no other clip owns the
			                               --   body (a cast always wins). Third person only: the Viewmodel clip would hold the M1
			Ride = "UpdraftRide", Land = "UpdraftLand", Jump = "UpdraftJump",
		},

		-- the Demo's clip: updraft_bl's whole hero shot, verbatim (V0 20 studs/s, 1.398 s of air, apex 6.99 at 0.699), on
		-- the filming clock (ZephyrDraw.TimeScale: the slow-down slows it, as it does every other piece's Demo)
		Demo = {
			V0 = 20.0, Air = 1.398, Drift = 1.2, Rel = 0.660, Hit = 0.735, From = -0.5, Tail = 1.3,
			ClipOffset = 0.30,             -- the UpdraftJump clips' time = this clip's time + ClipOffset (the dip is at -0.24)
			FaceYaw = -0.13,               -- updraft_bl.YAW: the caster's rest facing in the stage (at the dummy; + = left)
			-- the root's yaw over the clip, MINUS the rest facing (updraft_bl KEYS' yaw; rad, + = left), smoothstepped
			Yaw = { { -0.24, 0 }, { 0.09, -0.09 }, { 0.30, -0.25 }, { 0.52, -0.21 }, { 0.648, -0.13 }, { 0.695, 0.01 },
				{ 0.86, 0.03 }, { 1.10, -0.21 }, { 1.328, -0.17 }, { 1.398, -0.15 }, { 1.528, -0.13 }, { 1.898, -0.11 },
				{ 2.448, -0.09 } },
			Dummy = { X = 2.0, Y = 15.0 }, -- updraft_bl.D_BASE (stage studs: right, ahead): a stand-in dummy is drawn there
			UseRealWithin = 3.5,           -- ... unless a real TrainingDummy stands this close to that spot (then it is hit)
			DummyColor = Color3.fromRGB(205, 190, 150),   -- the stand-in's sand (a real dummy's colour wins)
			HitHeight = 3.2,               -- updraft_v4: the blade lands on the dummy's chest (D_BASE + 3.2 up)
			-- updraft_bl.DKEYS (s after the hit): torso pitch P (+ forward) / roll R / yaw Y, head pitch Hd, hips (HipY,
			-- HipZ), Slide (studs pushed back), hands HR / HL (dummy-local studs: x right, y toward the caster, z up), the
			-- feet's y (FR / FL); E = the ease INTO the key (zk.EASES)
			DummyKeys = {
				{ T = 0.00, E = "io", P = 0, R = 0, Y = 0, Hd = 0, HipY = 0, HipZ = 2.0, Slide = 0,
					HR = { 1.55, 0.2, 1.72 }, HL = { -1.55, 0.2, 1.72 }, FR = 0, FL = 0 },
				{ T = 0.08, E = "snap", P = -0.38, R = 0.06, Y = 0.10, Hd = -0.30, HipY = -0.2, HipZ = 1.95, Slide = 0.30,
					HR = { 1.95, -0.35, 2.4 }, HL = { -1.9, -0.45, 2.25 }, FR = 0, FL = 0 },
				{ T = 0.32, E = "out", P = -0.50, R = 0.08, Y = 0.12, Hd = -0.18, HipY = -0.3, HipZ = 1.9, Slide = 0.62,
					HR = { 2.0, -0.5, 2.0 }, HL = { -1.95, -0.55, 1.95 }, FR = 0.05, FL = -0.35 },
				{ T = 0.85, E = "io", P = 0.08, R = 0, Y = 0.02, Hd = 0.05, HipY = 0.05, HipZ = 1.98, Slide = 0.66,
					HR = { 1.55, 0.2, 1.72 }, HL = { -1.55, 0.2, 1.72 }, FR = 0.05, FL = -0.35 },
				{ T = 1.40, E = "back", P = 0, R = 0, Y = 0, Hd = 0, HipY = 0, HipZ = 2.0, Slide = 0.66,
					HR = { 1.55, 0.2, 1.72 }, HL = { -1.55, 0.2, 1.72 }, FR = 0.05, FL = -0.35 },
			},
			-- updraft_v4.blade: the Wind Blade the flick throws, from the right hand (at Rel) to the dummy (at Hit + Arrive)
			Blade = { Points = 8, Spans = 3, Bow = 0.9, Back = 0.6, Arrive = 0.04, Linger = 0.06, Out = 0.06,
				CoreW = { 0.08, 0.01 }, GlowW = { 0.35, 0.02 }, Shape = 0.8, CoreGlow = 1.2, GlowFade = 0.8, GlowAlpha = 0.6 },
			JumpWatch = 4.0,                   -- opts.Jump: s the live tell is forced on your own character
		},
	},
}
ZephyrUpdraft.Tuning = T

----------------------------------------------------------------------------------------------------
-- shared helpers (server and client)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrUpdraft] " .. tostring(msg))
end

local configMod = nil         -- SpellshotConfig, found lazily (false: not found)
local function config()
	if configMod == nil then
		local sp = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = sp and sp:FindFirstChild("SpellshotConfig")
		local ok, mod = pcall(function() return m and require(m) end)
		configMod = (ok and type(mod) == "table") and mod or false
	end
	return configMod or nil
end

local fxName = nil
local function fxFolderName()
	if fxName == nil then
		fxName = T.FXFolderName
		local ice = ReplicatedStorage:FindFirstChild("IceMagic")
		local m = ice and ice:FindFirstChild("VFXLibrary")
		local ok, V = pcall(function() return m and require(m) end)
		if ok and type(V) == "table" and type(V.Config) == "table" and type(V.Config.FXFolderName) == "string" then
			fxName = V.Config.FXFolderName
		end
	end
	return fxName
end

--- Root centre to the soles: an R15's HipHeight plus half the root; an R6 stands on 2-stud legs.
local function feetDrop(hum, root)
	if hum.RigType == Enum.HumanoidRigType.R6 then return root.Size.Y * 0.5 + 2.0 end
	return hum.HipHeight + root.Size.Y * 0.5
end

-- states in which a body is held by something (a ladder, water, a seat): never airborne, whatever is under it
local HELD = {
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

-- one RaycastParams per body, rebuilt every 2 s (the FX folder can appear after the first cast)
local probeCache = setmetatable({}, { __mode = "k" })
local function probeParams(character)
	local e = probeCache[character]
	local now = os.clock()
	if e and now - e.At < 2 then return e.Params end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.RespectCanCollide = true             -- only what a foot can stand on
	local list = { character }
	local fx = workspace:FindFirstChild(fxFolderName())
	if fx then list[#list + 1] = fx end
	if IS_CLIENT and workspace.CurrentCamera then list[#list + 1] = workspace.CurrentCamera end   -- the viewmodel arms
	p.FilterDescendantsInstances = list
	probeCache[character] = { Params = p, At = now }
	return p
end

--- Studs of air under `character`'s feet (depth when nothing is found that far down), the ground point the cast
--- touched (nil if none), and the soles' height. nil when there is no living body to ask.
function ZephyrUpdraft.Clearance(character, depth)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 then return nil end
	depth = depth or (T.MinClearance + 0.25)
	local drop = feetDrop(hum, root)
	local origin = root.Position
	local feetY = origin.Y - drop
	-- a SPHERE, not a ray: a body whose root hangs past a ledge its foot still stands on is standing
	local hit = workspace:Spherecast(origin, T.ProbeRadius, Vector3.new(0, -(drop + depth), 0), probeParams(character))
	if not hit then return depth, nil, feetY end
	return max(0, feetY - hit.Position.Y), hit.Position, feetY
end

--- Whether `character` is airborne by Updraft's rule: MinClearance of air under the feet and not held by a ladder,
--- water or a seat. useFloor also requires the engine's FloorMaterial to be Air -- only for a body this machine
--- simulates (the local client's own): FloorMaterial is not replicated, and on the server, for a body its owner's
--- client simulates, it is not something to bet a damage bonus on. Returns the clearance too.
function ZephyrUpdraft.Airborne(character, useFloor)
	local clear = ZephyrUpdraft.Clearance(character)
	if not clear then return false, 0 end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if HELD[hum:GetState()] then return false, clear end
	if useFloor and hum.FloorMaterial ~= Enum.Material.Air then return false, clear end
	return clear >= T.MinClearance, clear
end

--- The rule for WHO holds it: the player's Element is Zephyr (Config.DefaultLoadout's when unset), and Zephyr's Passive
--- is built (SpellshotConfig.PartialKits) -- TerraHandler's isTerra, for Updraft.
function ZephyrUpdraft.Holds(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	local Config = config()
	if not Config then return false end
	local element = player:GetAttribute("Element") or (Config.DefaultLoadout and Config.DefaultLoadout.Element)
	if element ~= T.Element then return false end
	return type(Config.IsPartBuilt) == "function" and Config.IsPartBuilt(T.Element, "Passive") == true
end

--- The client's test: the attribute ZephyrUpdraftServer keeps on the character.
function ZephyrUpdraft.HoldsCharacter(character)
	return character ~= nil and character:GetAttribute(T.Attribute) == "Updraft"
end

-- the server's memory of each holder's last airborne Heartbeat (ZephyrUpdraftServer writes it), for AirGrace
local lastAir = setmetatable({}, { __mode = "k" })

function ZephyrUpdraft.NoteAirborne(player, now)
	lastAir[player] = now or os.clock()
end

--- Airborne now (a fresh cast), or within AirGrace of the last airborne Heartbeat. The server's view: no FloorMaterial.
function ZephyrUpdraft.IsAirborne(player)
	local character = player and player.Character
	if not character then return false end
	local at = lastAir[player]
	if at and os.clock() - at <= T.AirGrace then return true end
	local air = ZephyrUpdraft.Airborne(character, IS_CLIENT and player == Players.LocalPlayer)
	return air
end

--- THE KNOCKBACK HOOK: KnockbackMult while `player` holds Updraft and is airborne, else 1. Multiply the knockback
--- velocity (or impulse) a Zephyr hit gives its victim by this, at the moment it is sent. Never errors: 1 on anything odd.
function ZephyrUpdraft.KnockbackScale(player)
	local ok, scale = pcall(function()
		if not ZephyrUpdraft.Holds(player) then return 1 end
		return ZephyrUpdraft.IsAirborne(player) and T.KnockbackMult or 1
	end)
	return (ok and type(scale) == "number") and scale or 1
end

--- The damage factor the server's modifier applies right now (for readouts; the modifier itself is the server's).
function ZephyrUpdraft.DamageScale(player)
	local ok, scale = pcall(function()
		if not ZephyrUpdraft.Holds(player) then return 1 end
		return ZephyrUpdraft.IsAirborne(player) and T.DamageMult or 1
	end)
	return (ok and type(scale) == "number") and scale or 1
end

----------------------------------------------------------------------------------------------------
-- CLIENT: the tell
----------------------------------------------------------------------------------------------------
ZephyrUpdraft.Handlers = {}
ZephyrUpdraft.LocalCast = {}         -- a Passive has no key

local TL = T.Tell
local KIND = TL.Kinds

local ZD = nil                       -- IceMagic.ZephyrDraw, found lazily (false: missing or failed)
local function zd()
	if ZD ~= nil then return ZD or nil end
	if not IS_CLIENT then
		ZD = false
		return nil
	end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild("ZephyrDraw")
	if not m then
		warnOnce("zd", "IceMagic.ZephyrDraw is not in the place: Updraft's tell is not drawn (the passive still works)")
		ZD = false
		return nil
	end
	local ok, mod = pcall(require, m)
	ZD = (ok and type(mod) == "table") and mod or false
	if not ZD then warnOnce("zd", "IceMagic.ZephyrDraw failed to load: " .. tostring(mod)) end
	return ZD or nil
end

--- cv:<method>(...), guarded per method: a method ZephyrDraw does not have, or one that errors, skips that layer of
--- the tell (one warning) and never ends the effect or touches a mechanic.
local function call(cv, method, ...)
	local f = cv[method]
	if type(f) ~= "function" then
		warnOnce("m:" .. method, "ZephyrDraw has no cv:" .. method .. " -- that layer of the tell is skipped")
		return nil
	end
	local ok, res = pcall(f, cv, ...)
	if not ok then
		warnOnce("e:" .. method, "cv:" .. method .. " failed: " .. tostring(res))
		return nil
	end
	return res
end

-- the kit's curves (pyro_kit / zk: smooth = smoothstep, ease_out = cubic out, span = linear 0..1)
local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
local function smooth(x, a, b)
	local u = clamp01((x - a) / (b - a))
	return u * u * (3 - 2 * u)
end
local function easeOut(u)
	u = clamp01(u)
	local v = 1 - u
	return 1 - v * v * v
end
local function span(t, a, b) return clamp01((t - a) / (b - a)) end

-- THE BLENDER STAGE IN ROBLOX: the tell lies round a vertical axis, so a point at angle a, radius r, height z over the
-- axis centre c (the feet plane) is c + (r cos a, z, -r sin a) -- Blender's x right / y forward / z up turned into
-- Roblox's (x, y, z) -> (x, z, -y), a proper rotation, so the kit's counter-clockwise-from-above stays that. The angles
-- are WORLD-fixed (the source's are): turning your body does not swing the helix round with the camera.
local function ringPt(c, r, a, z)
	return c + Vector3.new(r * cos(a), z, -r * sin(a))
end

local function aliveParts(c)
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	return hum, root
end

--- The ankle joint: the R15 rig's ankle attachment on that lower leg, else the end of the limb, else R6's leg, else a
--- guess under the root (ZephyrFX's legPoint rule).
local function ankle(c, side, root)
	local limb = c:FindFirstChild(side .. "LowerLeg")
	if limb then
		local a = limb:FindFirstChild(side .. "AnkleRigAttachment")
		if a and a:IsA("Attachment") then return a.WorldPosition end
		return limb.Position - limb.CFrame.UpVector * (limb.Size.Y * 0.45)
	end
	local leg = c:FindFirstChild(side .. " Leg")
	if leg then return leg.Position - leg.CFrame.UpVector * (leg.Size.Y * 0.4) end
	root = root or c:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	return root.Position + root.CFrame.RightVector * ((side == "Right") and 0.5 or -0.5) - Vector3.new(0, 2.7, 0)
end

local function flatLook(cf)
	local lv = cf.LookVector
	local f = Vector3.new(lv.X, 0, lv.Z)
	if f.Magnitude < 1e-4 then return Vector3.new(0, 0, -1) end
	return f.Unit
end

--- Your own body seen from your own eyes (the camera at the head, the way RadiantFX_Staff asks).
local function ownView(c)
	local lp = Players.LocalPlayer
	if not lp or c ~= lp.Character then return false end
	local head, cam = c:FindFirstChild("Head"), workspace.CurrentCamera
	if not (head and cam) then return lp.CameraMode == Enum.CameraMode.LockFirstPerson end
	return (cam.CFrame.Position - head.Position).Magnitude < 2.5
end

local apexH = nil
local function apexHeight()
	if TL.ApexHeight then return TL.ApexHeight end
	if not apexH then
		local sp = game:GetService("StarterPlayer")
		local h = 7.2
		local ok = pcall(function()
			if sp.CharacterUseJumpPower then
				h = sp.CharacterJumpPower ^ 2 / (2 * max(workspace.Gravity, 1))
			else
				h = sp.CharacterJumpHeight
			end
		end)
		apexH = (ok and h > 0.5) and h or 7.2
	end
	return apexH
end

-- Settings "ReduceFlashing", read at most once a second
local settingsLib, reduceAt, reduceOn = nil, -math.huge, false
local function reduceFlashing()
	if ZD and type(ZD.Calm) == "function" then           -- ZephyrDraw's own reading of the same setting
		local ok, on = pcall(ZD.Calm)
		if ok then return on == true end
	end
	local now = os.clock()
	if now - reduceAt < 1 then return reduceOn end
	reduceAt = now
	if settingsLib == nil then
		settingsLib = false
		local sp = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = sp and sp:FindFirstChild("SpellshotSettings")
		local ok, lib = pcall(function() return m and require(m) end)
		if ok and type(lib) == "table" then settingsLib = lib end
	end
	reduceOn = false
	if settingsLib and type(settingsLib.Get) == "function" then
		local ok, on = pcall(settingsLib.Get, "ReduceFlashing")
		reduceOn = ok and on == true
	end
	return reduceOn
end

----------------------------------------------------------------------------------------------------
-- the clock functions (updraft_bl / updraft_v6), on an EPISODE: one airborne stretch of one body and its landing tail
--   ep.TakeOff (clip s) ep.E0 (presence it built up from) ep.LandT / ep.ELand (the landing and the presence then)
--   ep.TPk (the apex) ep.THit (the last aerial hit) ep.Scuff = { T, Pos, Seq } (the last landing's floor marks)
----------------------------------------------------------------------------------------------------
local function presence(ep, t)
	if ep.LandT then
		local k = clamp01((t - ep.LandT) / TL.Thin)
		return ep.ELand * (1 - k) ^ TL.ThinPow
	end
	return ep.E0 + (1 - ep.E0) * smooth(t, ep.TakeOff, ep.TakeOff + TL.Build)
end

--- updraft_v6.peak: on Rise before the apex, decaying with Tau after it
local function peakOf(ep, t)
	local tp = ep.TPk
	if not tp then return 0 end
	local A = TL.Apex
	return smooth(t, tp - A.Rise, tp) * exp(-max(0, t - tp) / A.Tau)
end

--- updraft_bl.pulse_env / pulse_z: the travelling band (0..1) and its height over the feet plane (studs)
local function pulseOf(ep, t)
	local th = ep.THit
	if not th then return 0, 0 end
	local P = TL.Pulse
	local env = smooth(t, th, th + P.In) * (1 - smooth(t, th + P.Time - 0.04, th + P.Time + 0.07))
	local u = clamp01((t - th) / P.Time)
	local pu = -0.04 + 1.08 * (0.45 * u + 0.55 * easeOut(u))
	return env, P.Z0 + (P.Z1 - P.Z0) * pu
end

----------------------------------------------------------------------------------------------------
-- scratch (drawing is synchronous: one frame function at a time reads and refills these)
----------------------------------------------------------------------------------------------------
local helixPts, torsoPts, armPts, armSide, ankPts = {}, {}, {}, {}, {}
for i = 0, 6 do helixPts[i] = {} end
for i = 1, TL.Torso.Count do torsoPts[i] = {} end
for i = 1, TL.Arms.Count do
	armPts[i] = {}
	armSide[i] = {}
end
for i = 1, 2 do ankPts[i] = {} end
local discPts = {}

--- a width array lerped a -> b over n points (built once per key)
local widthCache = {}
local function linWidths(key, a, b, n, shape)
	local w = widthCache[key]
	if w then return w end
	w = table.create(n)
	for k = 1, n do
		local s = (n > 1) and (k - 1) / (n - 1) or 0
		local v = a + (b - a) * s
		if shape then v = v * shape(s) end
		w[k] = v
	end
	widthCache[key] = w
	return w
end

-- za.path_ribbon's end taper: x sin(pi clip(linspace(0.02, 0.98))) ^ 0.35
local function pathTaper(s)
	return sin(pi * (0.02 + 0.96 * s)) ^ 0.35
end

-- hoisted option tables (read, never kept, by ZephyrDraw: the varying fields are overwritten each frame)
local AR = TL.AlphaRef
local H, TOR, D, ARM, ANK, PUL, APX, LND, LT = TL.Helix, TL.Torso, TL.Disc, TL.Arms, TL.Ankle, TL.Pulse, TL.Apex,
	TL.Land, TL.Light
local O = {
	core = { fade = 1, glow = 1, tail = H.CoreTail, maxSpans = H.Spans.Core, tag = "updraft_helix" },
	glow = { fade = 1, glow = 1, alpha = H.Alpha / AR, tail = H.GlowTail, maxSpans = H.Spans.Glow, tag = "updraft_helix" },
	hair = { fade = 1, glow = 1, alpha = H.Alpha / AR, tail = H.HairTail, maxSpans = H.Spans.Hair, tag = "updraft_helix" },
	torso = { fade = 1, glow = 1, alpha = TOR.Alpha / AR, tail = TOR.Tail, maxSpans = TOR.Spans, tag = "updraft_torso" },
	-- the "surf" kind is mat_surf: it feathers the trailing `ch` edge (on a closed sheet ch = 0.5 - 0.5 sin(column
	-- angle), so the faint side spins with the disc) and the rim (sa 0.86 -> 1.02) itself -- no o.fa needed
	disc = { fade = 1, glow = 1, alpha = D.Alpha / AR, closed = true, e0 = D.E0, e1 = D.E1, a0 = D.A0, maxSpans = D.Rings - 1,
		tag = "updraft_disc" },
	arm = { fade = 1, glow = 1, alpha = ARM.Alpha / AR, tail = ARM.Tail, side = nil, maxSpans = ARM.Spans, tag = "updraft_disc" },
	ank = { fade = 1, glow = 1, alpha = ANK.Alpha / AR, tail = ANK.Tail, maxSpans = ANK.Spans, tag = "updraft_ankle" },
	pulse = { fade = 1, glow = PUL.Glow, alpha = PUL.Alpha / AR, maxSpans = PUL.Spans, tag = "updraft_pulse" },
	apexCore = { fade = 1, glow = APX.CoreGlow, maxSpans = APX.Spans, tag = "updraft_apex" },
	apexGlow = { fade = 1, glow = APX.GlowGlow, alpha = APX.GlowAlpha / AR, maxSpans = APX.Spans, tag = "updraft_apex" },
	scuff = { fade = 1, glow = LND.ScuffGlow, maxSpans = LND.Spans, tag = "updraft_land" },
	dring = { fade = 1, alpha = LND.RingAlpha / AR, maxSpans = LND.Spans, tag = "updraft_land" },
	light = { range = LT.Range, flicker = LT.Flicker, tag = "updraft_light" },
}
local PO = TL.Particles
local SO = {                           -- stream option tables (speed is rewritten per frame)
	speck = { id = "updraft_speck", speed = { 0, 0 }, dir = UP, cone = 0.15, life = PO.Speck.Life, size = PO.Speck.Size },
	spark = { id = "updraft_spark", speed = { 0, 0 }, dir = UP, cone = 0.2, life = PO.Spark.Life, size = PO.Spark.Size },
	dust = { id = "updraft_discdust", speed = { 0, 0 }, dir = UP, cone = 0.15, life = PO.DiscDust.Life, size = PO.DiscDust.Size },
}

--- za's size multiplier {a, b} as ZephyrDraw's o.size (Particles.SizeIsMultiplier: as it is, or x the kind's base)
local sizeCache = {}
local function sizeFor(kind, mult)
	if PO.SizeIsMultiplier then return mult end
	local key = kind .. ":" .. mult[1] .. ":" .. mult[2]
	local s = sizeCache[key]
	if not s then
		local base = PO.KindBase[kind] or 1
		s = { mult[1] * base, mult[2] * base }
		sizeCache[key] = s
	end
	return s
end
SO.speck.size = sizeFor("speck", PO.Speck.Size)
SO.spark.size = sizeFor("spark", PO.Spark.Size)
SO.dust.size = sizeFor("dust", PO.DiscDust.Size)

--- A burst once per key per episode (za.burst's arguments; o.id lets ZephyrDraw dedupe as well).
local function burstOnce(cv, fired, key, kind, pos, B)
	if fired[key] then return end
	fired[key] = true
	call(cv, "Burst", kind, pos, B.N, {
		id = key, speed = B.Speed, life = B.Life, up = B.Up, size = sizeFor(kind, B.Size or { 0.6, 1.4 }), seed = B.Seed,
	})
end

--- A stream at one point of its ring this frame, aimed along the funnel's field there (updraft_bl.field: the body's
--- velocity + the lift + the counter-clockwise swirl, + the source's own launch velocity `up`).
local function streamAt(cv, kind, o, rate, c, r, a, z, vel, up, swirlK, inflow)
	local radial = Vector3.new(cos(a), 0, -sin(a))
	local tangent = Vector3.new(-sin(a), 0, -cos(a))
	local v = vel + tangent * (PO.Swirl * (swirlK or 1)) + UP * (PO.Lift + up) - radial * (inflow or 0)
	local m = v.Magnitude
	if m < 1e-3 then return end
	o.dir = v / m
	m = math.floor(m * 2 + 0.5) * 0.5               -- half-stud steps: the emitter's Speed is rewritten only on a change
	o.speed[1], o.speed[2] = m * 0.85, m * 1.15
	call(cv, "Stream", kind, c + radial * r + UP * z, rate, o)
end

--- The victim's mark (updraft_v4's hit burst at the dummy): sparks and puffs once.
local function hitMark(cv, fired, key, at)
	burstOnce(cv, fired, key .. "_s", "spark", at, PO.MarkSparks)
	burstOnce(cv, fired, key .. "_p", "puff", at, PO.MarkPuffs)
end

----------------------------------------------------------------------------------------------------
-- THE FRAME: the whole tell for one body at clip time t. S (per frame): C (the axis centre on the feet plane), E
-- (presence), H (height ratio), Pk (apex peak), PE / PZ (the pulse and its height), Air, Own, Reduce (1 or the
-- ReduceFlashing factor), Vel (the body's velocity), Ankle(side 1|2, age s) -> Vector3?
----------------------------------------------------------------------------------------------------
local function drawTell(cv, t, S, ep)
	local C, e, h, pk, pe = S.C, S.E, S.H, S.Pk, S.PE
	local own, rf = S.Own, S.Reduce
	local Gr = TL.Grow
	-- updraft_v6: the tell's body grows with the height and surges at the apex
	local g = (Gr.GlowBase + Gr.GlowPerH * h) * (1 + Gr.Surge * pk * rf)
	local fm = Gr.FadeBase + Gr.FadePerH * h
	local body = e > TL.MinPresence

	if body and not own then
		-- v4: the rising helix round the legs (the head at the top: the air rises)
		local g4 = 1 + H.PulseGlow * pe
		for i = 0, 6 do
			local kind = (i == 0) and 0 or ((i < 4) and 1 or 2)
			local n = ((kind == 0) and H.Spans.Core or ((kind == 1) and H.Spans.Glow or H.Spans.Hair)) + 1
			local pts = helixPts[i]
			local a0 = i * H.Phase + H.KindPhase[kind + 1]
			local zTop = H.Top - H.TopStep * kind
			local spin = H.Spin * t * (1 + H.SpinStep * kind)
			local tw = H.Twist + H.TwistStep * kind
			local rk = H.KindR[kind + 1] * (1 + H.Flare * i)
			for k = 1, n do
				local z = zTop + (H.Bottom - zTop) * (k - 1) / (n - 1)
				pts[k] = ringPt(C, (H.R0 - H.RSlope * z) * rk, a0 + spin - z * tw, z)
			end
			for k = n + 1, #pts do pts[k] = nil end
			-- o.t is the streak clock: the kit passes t for the core and t + i for the others (no two streak alike)
			if kind == 0 then
				O.core.fade, O.core.glow, O.core.t = e * fm, g4 * g, t
				call(cv, "Ribbon", pts, H.CoreW, KIND.Core, O.core)
			elseif kind == 1 then
				O.glow.fade, O.glow.glow, O.glow.t = e * H.GlowFade * fm, g4 * g, t + i
				call(cv, "Ribbon", pts, linWidths("helixGlow", H.GlowW[1], H.GlowW[2], n), KIND.Glow, O.glow)
			else
				O.hair.fade, O.hair.glow, O.hair.t = e * H.HairFade * fm, H.HairGlow * g4 * g, t + i
				call(cv, "Ribbon", pts, H.HairW, KIND.Hair, O.hair)
			end
		end
		-- v5: the helix climbs the torso too
		local nT = TOR.Spans + 1
		O.torso.fade, O.torso.glow = e * TOR.Fade * fm, (TOR.Glow + TOR.PulseGlow * pe) * g
		for i = 1, TOR.Count do
			local pts = torsoPts[i]
			for k = 1, nT do
				local z = TOR.Top + (TOR.Bottom - TOR.Top) * (k - 1) / (nT - 1)
				pts[k] = ringPt(C, TOR.R0 - TOR.RSlope * z, (i - 1) * pi + TOR.Spin * t - z * TOR.Twist, z)
			end
			O.torso.t = t + (i - 1)
			call(cv, "Ribbon", pts, linWidths("torso", TOR.W[1], TOR.W[2], nT), KIND.Glow, O.torso)
		end
	end

	if body then
		-- v5: the downward-facing disc of swirling wind under the feet (v6: reaching wider as the body rises)
		local nu, nv = D.Rings, D.Around
		local reach = D.Reach[1] + D.Reach[2] * h + D.Reach[3] * pk
		local spin = D.Spin * t
		for i = 1, nu do
			local s = (i - 1) / (nu - 1)
			local r = D.R[1] + (D.R[2] - D.R[1]) * s
			local z = -(D.Drop + D.Dish * (r / D.R[2]) ^ 2)
			local tw = D.Twist * s
			for j = 1, nv do
				discPts[(i - 1) * nv + j] = ringPt(C, r * reach, 2 * pi * (j - 1) / nv + spin + tw, z)
			end
		end
		O.disc.fade, O.disc.glow = e * fm, D.Glow * g
		call(cv, "Sheet", discPts, nu, nv, KIND.Disc, O.disc)
		-- v5: three spiral arms flat under the feet, their width lying along the radius
		local nA = ARM.Spans + 1
		O.arm.fade, O.arm.glow = e * fm, ARM.Glow * g
		for i = 1, ARM.Count do
			local pts, side = armPts[i], armSide[i]
			local a0 = (i - 1) * 2.094 + ARM.Spin * t
			for k = 1, nA do
				local s = (k - 1) / (nA - 1)
				local a = a0 - ARM.Sweep * s
				local rr = ARM.R[1] + (ARM.R[2] - ARM.R[1]) * s
				pts[k] = ringPt(C, rr, a, -ARM.Drop)
				side[k] = Vector3.new(cos(a), 0, -sin(a))
			end
			O.arm.side = side
			call(cv, "Ribbon", pts, linWidths("arm", ARM.W[1], ARM.W[2], nA), KIND.Glow, O.arm)
		end
		O.arm.side = nil
		-- v5: ribbons trailing from the ankles: each one's own last 0.3 s, glow and core (camera-facing)
		local nK = ANK.Points
		O.ank.fade, O.ank.glow = e * fm, ANK.Glow * g
		for sd = 1, 2 do
			local pts = ankPts[sd]
			local ok, len = true, 0
			for k = 1, nK do
				local p = S.Ankle(sd, ANK.Dur * (k - 1) / (nK - 1))
				if not p then
					ok = false
					break
				end
				if k > 1 then len += (p - pts[k - 1]).Magnitude end
				pts[k] = p
			end
			if ok and len > 0.05 then
				call(cv, "Ribbon", pts, linWidths("ankG", ANK.GlowW[1], ANK.GlowW[2], nK, pathTaper), KIND.Glow, O.ank)
				call(cv, "Ribbon", pts, linWidths("ankC", ANK.CoreW[1], ANK.CoreW[2], nK, pathTaper), KIND.Core, O.ank)
			end
		end
	end

	if not own then
		-- v4: the aerial hit -- a ring pulse climbs the helix
		if pe > 0.01 then
			local zc = S.PZ
			O.pulse.fade = pe
			call(cv, "RingK", C + UP * zc, PUL.R0 - PUL.RSlope * zc, UP, PUL.W, KIND.Glow, O.pulse)
		end
		-- v6: the apex flash, a bright ring round the waist
		if ep.TPk then
			local u = span(t, ep.TPk - APX.Lead, ep.TPk + APX.Dur)
			if u > 0 and u < 1 then
				local cw = C + UP * APX.Waist
				local r = APX.R0 + APX.Grow * easeOut(u)
				local f = (1 - u) ^ 1.5 * (rf < 1 and (0.5 + 0.5 * rf) or 1)
				O.apexCore.fade = f
				call(cv, "RingK", cw, r, UP, APX.CoreW * (1 - u) + APX.CoreW0, KIND.Core, O.apexCore)
				O.apexGlow.fade, O.apexGlow.t = f * APX.GlowFade, t + 1
				call(cv, "RingK", cw, r * APX.GlowR, UP, APX.GlowW * (1 - APX.GlowShrink * u), KIND.Glow, O.apexGlow)
			end
		end
		-- the landing: v5's scuff ring and v4's soft vapor ring spilling off the feet
		local sc = ep.Scuff
		if sc then
			local k = span(t, sc.T, sc.T + LND.ScuffDur)
			local fs = 1 - smooth(t, sc.T + LND.ScuffFadeFrom, sc.T + LND.ScuffFadeTo)
			if t >= sc.T and fs > 0.004 then
				O.scuff.fade = fs
				call(cv, "RingK", sc.Pos + UP * LND.ScuffLift, LND.ScuffR0 + LND.ScuffGrow * easeOut(k), UP, LND.ScuffW,
					KIND.Scuff, O.scuff)
			end
			local kr = span(t, sc.T, sc.T + LND.RingDur)
			if kr > 0 and kr < 1 then
				O.dring.fade = (1 - kr) * LND.RingFade
				call(cv, "RingK", sc.Pos + UP * LND.RingLift, LND.RingR0 + LND.RingGrow * easeOut(kr), UP,
					LND.RingW * (1 - kr) + LND.RingW0, KIND.Vapor, O.dring)
			end
		end
	end

	-- v6: the aqua light under the feet, lifting with the body (Reduce Flashing: ZephyrDraw steadies and dims it)
	local watts = e * (LT.Base + LT.PerH * h) + LT.Apex * pk
	if own then watts *= TL.OwnView.Light end
	if watts > 1 then call(cv, "Light", C + UP * LT.Lift, watts, O.light) end

	-- particles
	local vel = S.Vel or Vector3.zero
	if S.Air then
		if not own then
			local P = PO.Speck                      -- v4: specks lifting off round the feet
			local a = t * P.Orbit
			streamAt(cv, "speck", SO.speck, P.Rate, C, P.R, a,
				P.Z[1] + (P.Z[2] - P.Z[1]) * (0.5 + 0.5 * sin(t * 31.7)), vel, P.Up)
			P = PO.Spark                            -- v4: sparkles among them
			a = t * P.Orbit + 2.0
			streamAt(cv, "spark", SO.spark, P.Rate, C, P.R, a,
				P.Z[1] + (P.Z[2] - P.Z[1]) * (0.5 + 0.5 * sin(t * 27.1 + 1.0)), vel, P.Up)
		end
		local P = PO.DiscDust                       -- v5: dust swirling in the disc (it is the disc's: own view too)
		streamAt(cv, "dust", SO.dust, P.Rate, C, P.R, t * P.Orbit + 4.0, P.Z, vel, -P.Down, P.SwirlK, P.Inflow)
	end
	if not own then
		local fired, seq = ep.Fired, ep.AirSeq
		if ep.Jumped and ep.TakeoffPos and t >= ep.TakeOff then          -- v4: take-off dust off the floor
			burstOnce(cv, fired, "takeoff" .. seq, "dust", ep.TakeoffPos + UP * PO.Takeoff.Lift, PO.Takeoff)
		end
		local sc = ep.Scuff
		if sc and t >= sc.T then                                           -- v4 landing dust + v5 downdraft puff
			burstOnce(cv, fired, "land" .. sc.Seq, "dust", sc.Pos + UP * PO.LandDust.Lift, PO.LandDust)
			burstOnce(cv, fired, "down" .. sc.Seq, "dust", sc.Pos + UP * PO.Downdraft.Lift, PO.Downdraft)
		end
		if ep.TPk and t >= ep.TPk then                                     -- v6: the apex sparkle pop
			burstOnce(cv, fired, "apex" .. (ep.PkSeq or 0), "spark", C + UP * PO.ApexSparks.Lift, PO.ApexSparks)
		end
		if ep.THit and t >= ep.THit + PO.HitPuffs.Delay then              -- v4: puffs off the body on the aerial hit
			burstOnce(cv, fired, "hit" .. (ep.HitSeq or 0), "puff", C + UP * PO.HitPuffs.Lift, PO.HitPuffs)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE WATCHER: every holder's body, every frame -- airborne or not by the same rule as the server's, plus the engine's
-- floor for your own; an episode (one ZephyrDraw effect) from each take-off to its landing tail
----------------------------------------------------------------------------------------------------
-- the body (CastPose) and your own arms (Viewmodel), required lazily on the client; a missing module or clip is skipped
local mods = {}
local function need(name)
	local m = mods[name]
	if m == nil then
		m = false
		local ice = IS_CLIENT and ReplicatedStorage:FindFirstChild("IceMagic")
		local inst = ice and ice:FindFirstChild(name)
		if inst then
			local ok, mod = pcall(require, inst)
			if ok and type(mod) == "table" then m = mod end
		end
		mods[name] = m
	end
	return m or nil
end

local function modCall(name, fn, ...)
	local M = need(name)
	local f = M and M[fn]
	if type(f) ~= "function" then return nil end
	local ok, res = pcall(f, ...)
	return ok and res or nil
end

local PS = TL.Pose
--- Take-off: the body rides the updraft (UpdraftRide, clocked on the take-off) unless a cast clip owns it.
local function poseRide(ep)
	if not PS.Live then return end
	local c = ep.Character
	local cur = modCall("CastPose", "CurrentClip", c)
	if cur ~= nil and cur ~= PS.Land and cur ~= PS.Ride then return end
	modCall("CastPose", "PlayClocked", c, PS.Ride, function() return ep.Clock() - ep.TakeOff end)
end

--- Landing (landed) or cut short: the squash, or straight back to the stance -- only if the body is still riding.
local function poseLand(ep, landed)
	if not (PS.Live and ep) then return end
	local c = ep.Character
	if modCall("CastPose", "CurrentClip", c) ~= PS.Ride then return end
	if landed then
		modCall("CastPose", "Play", c, PS.Land)
	else
		modCall("CastPose", "Stop", c)
	end
end

local started = false
local watched = {}                                         -- [character] = W
local forced = setmetatable({}, { __mode = "k" })          -- [character] = os.clock() deadline (Demo's Jump)
local demoing = setmetatable({}, { __mode = "k" })         -- [character] = true while a Demo draws on it
local lastScan = -math.huge
local epCount = 0

local function suppressed(c)
	for _, name in ipairs(TL.SuppressWhile) do
		if c:GetAttribute(name) then return true end
	end
	if not TL.InHub then
		local p = Players:GetPlayerFromCharacter(c)
		if p and p:GetAttribute("Zone") == "Hub" then return true end
	end
	return false
end

local function isHolder(c)
	if demoing[c] then return false end
	local f = forced[c]
	if f and f > os.clock() then return true end
	return ZephyrUpdraft.HoldsCharacter(c)
end

-- the ankle path ring buffer (W.AnkT / AnkR / AnkL, head index W.AnkHead)
local function ankPush(w, now, r, l)
	local N = ANK.History
	w.AnkHead = w.AnkHead % N + 1
	w.AnkT[w.AnkHead], w.AnkR[w.AnkHead], w.AnkL[w.AnkHead] = now, r, l
	w.AnkCount = min(w.AnkCount + 1, N)
	w.AnkAt = now
end

local function ankAt(w, side, tq)
	local N = ANK.History
	local arr = (side == 1) and w.AnkR or w.AnkL
	local i = w.AnkHead
	local newer = nil
	for _ = 1, w.AnkCount do
		local ti = w.AnkT[i]
		if ti <= tq then
			if newer then
				local tn = w.AnkT[newer]
				return arr[i]:Lerp(arr[newer], clamp01((tq - ti) / max(tn - ti, 1e-4)))
			end
			return arr[i]
		end
		newer = i
		i = (i - 2) % N + 1
	end
	return newer and arr[newer] or nil                    -- older than the history: its oldest point
end

local function newWatch(c)
	return {
		Character = c, Hum = nil, Root = nil, Air = false, Ep = nil, Vy = 0, PrevFeet = nil, PrevAt = 0,
		AnkT = {}, AnkR = {}, AnkL = {}, AnkHead = 0, AnkCount = 0, AnkAt = -math.huge,
	}
end

local function landEpisode(ep, pos)
	if not ep or ep.LandT then return end
	local t = ep.Clock()
	ep.ELand = presence(ep, t)
	ep.LandT = t
	if pos then ep.Scuff = { T = t, Pos = pos, Seq = ep.AirSeq } end
	poseLand(ep, pos ~= nil)
end

local function liveFrameFn(ep)
	local w = ep.W
	local S = { C = Vector3.zero, E = 0, H = 0, Pk = 0, PE = 0, PZ = 0, Air = false, Own = false, Reduce = 1, Vel = nil }
	S.Ankle = function(side, age)
		local c = ep.Character
		if age <= 1e-4 then return ankle(c, (side == 1) and "Right" or "Left", w.Root) end
		return ankAt(w, side, os.clock() - age) or ankle(c, (side == 1) and "Right" or "Left", w.Root)
	end
	return function(cv, t)
		if ep.Cut and not ep.LandT then landEpisode(ep, nil) end
		if ep.LandT and t - ep.LandT > TL.EndAfter then return false end
		local c = ep.Character
		local hum, root = w.Hum, w.Root
		if not (c.Parent and hum and root and root.Parent == c) then return false end
		local cf = root.CFrame
		local look = flatLook(cf)
		local right = look:Cross(UP)
		S.C = cf.Position - UP * feetDrop(hum, root) + right * TL.Axis.Right + look * TL.Axis.Fwd
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - S.C).Magnitude > TL.MaxDistance then return true end   -- too far: nothing
		S.E = presence(ep, t)
		S.H = ep.LandT and 0 or ep.H
		S.Pk = peakOf(ep, t)
		S.PE, S.PZ = pulseOf(ep, t)
		S.Air = w.Air and not ep.LandT
		S.Own = ownView(c)
		S.Reduce = reduceFlashing() and TL.ReduceFlashing or 1
		S.Vel = ep.Vel
		drawTell(cv, t, S, ep)
		return true
	end
end

local function startEpisode(w, lead)
	local Z = zd()
	if not (Z and type(Z.Play) == "function") then return nil end
	epCount += 1
	local born = os.clock() - (lead or 0)
	local ep = {
		W = w, Character = w.Character, Born = born, TakeOff = 0, E0 = 0, LandT = nil, ELand = 1, TPk = nil,
		PkSeq = 0, PkDone = false, Rising = false, THit = nil, HitSeq = 0, H = 0, Vel = Vector3.zero, Fired = {},
		AirSeq = 1, Jumped = false, TakeoffPos = nil, Scuff = nil, Cut = false, Done = false,
	}
	ep.Clock = function() return os.clock() - born end
	local lp = Players.LocalPlayer
	local ok, handle = pcall(Z.Play, "Updraft", liveFrameFn(ep), {
		Clock = ep.Clock, MaxLife = math.huge, Budget = "Updraft",
		Own = lp ~= nil and w.Character == lp.Character,      -- your own tell is never thinned by Reduce Enemy VFX
		OnEnd = function()
			ep.Done = true
			if w.Ep == ep then w.Ep = nil end
			-- ended before its landing (a frame that failed, the root gone): nothing would ever land it now -- the next
			-- landing finds no episode -- so put the body back here, or UpdraftRide (held while airborne) stays on it
			if not ep.LandT then poseLand(ep, false) end
		end,
	})
	if not ok then
		warnOnce("play", "ZephyrDraw.Play failed: " .. tostring(handle))
		return nil
	end
	ep.Handle = handle
	return ep
end

local function takeOff(w, clear, ground)
	local vy = w.Vy
	local ep = w.Ep
	if ep and not ep.Done and not ep.Cut then
		-- airborne again inside the last landing's tail: the same tell builds back up from where it stands
		local t = ep.Clock()
		ep.E0 = presence(ep, t)
		ep.TakeOff = t
		ep.LandT = nil
		ep.AirSeq += 1
		ep.PkDone, ep.Rising = false, false
	else
		-- t = 0 is the feet leaving the floor: the cast saw MinClearance of air some moment after that
		local lead = (vy > 1) and min(0.12, clear / vy) or 0.05
		ep = startEpisode(w, lead)
		w.Ep = ep
		if not ep then return end
	end
	ep.Jumped = vy > PO.TakeoffSpeed
	ep.TakeoffPos = ground
	poseRide(ep)
end

--- The apex: the turn from rising to falling, predicted Rise s ahead from the climb speed (so peak()'s ramp starts
--- before it, as the source's does), once per rise, and only high enough up.
local function watchApex(ep, vy, clear)
	local A = TL.Apex
	local t = ep.Clock()
	if ep.PkDone then
		if vy > A.RiseSpeed and ep.TPk and t - ep.TPk > A.Rearm then
			ep.PkDone, ep.Rising = false, true
		end
		return
	end
	if vy > A.RiseSpeed then ep.Rising = true end
	if not ep.Rising or clear < A.MinClear then return end
	local tta = (vy > 0) and vy / max(workspace.Gravity, 1) or 0
	if vy <= 0 or tta <= A.Rise then
		ep.TPk = t + tta
		ep.PkSeq += 1
		ep.PkDone, ep.Rising = true, false
	end
end

local function updateWatch(w, now)
	local c = w.Character
	local hum, root = w.Hum, w.Root
	if not (hum and hum.Parent == c) then
		hum = c:FindFirstChildOfClass("Humanoid")
		w.Hum = hum
	end
	if not (root and root.Parent == c) then
		root = c:FindFirstChild("HumanoidRootPart")
		w.Root = root
	end
	if not (hum and root) or hum.Health <= 0 then
		if w.Air then
			w.Air = false
			landEpisode(w.Ep, nil)
		end
		return
	end
	if now - w.AnkAt >= ANK.SampleDt then
		local r, l = ankle(c, "Right", root), ankle(c, "Left", root)
		if r and l then ankPush(w, now, r, l) end
	end
	local clear, ground, feetY = ZephyrUpdraft.Clearance(c, TL.ProbeDepth)
	if not clear then return end
	-- the climb speed from the soles' own path: the same on every screen (somebody else's body's engine velocity is
	-- extrapolated between network updates)
	local dt = now - w.PrevAt
	if w.PrevFeet and dt > 1e-3 then
		w.Vy += ((feetY - w.PrevFeet) / dt - w.Vy) * 0.5
	end
	w.PrevFeet, w.PrevAt = feetY, now
	local lp = Players.LocalPlayer
	local own = lp ~= nil and c == lp.Character
	local grounded = HELD[hum:GetState()] == true or (own and hum.FloorMaterial ~= Enum.Material.Air)
	local quiet = suppressed(c)
	if not w.Air then
		if not grounded and not quiet and clear >= T.MinClearance then
			w.Air = true
			takeOff(w, clear, ground)
		end
	elseif grounded or quiet or clear <= TL.LandClearance then
		w.Air = false
		local pos = ground or Vector3.new(root.Position.X, feetY, root.Position.Z)
		landEpisode(w.Ep, (not quiet) and pos or nil)
	end
	local ep = w.Ep
	if ep then
		ep.H = w.Air and clamp01(clear / apexHeight()) or 0
		ep.Vel = root.AssemblyLinearVelocity
		if w.Air and not ep.LandT then watchApex(ep, w.Vy, clear) end
	end
end

local function scan(now)
	lastScan = now
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and c.Parent and not watched[c] and isHolder(c) then watched[c] = newWatch(c) end
	end
	for c, until_ in pairs(forced) do
		if until_ > now and c.Parent and not watched[c] and isHolder(c) then watched[c] = newWatch(c) end
	end
	for c, w in pairs(watched) do
		if not c.Parent or not isHolder(c) then
			-- no longer a holder (or gone): whatever is drawn thins away as a landing does
			if w.Ep then w.Ep.Cut = true end
			watched[c] = nil
		end
	end
end

local function step()
	local now = os.clock()
	if now - lastScan >= TL.ScanEvery then scan(now) end
	for _, w in pairs(watched) do
		local ok, err = pcall(updateWatch, w, now)
		if not ok then warnOnce("watch", "the airborne watch failed: " .. tostring(err)) end
	end
end

local function ensureStarted()
	if started or not IS_CLIENT then return end
	started = true
	RunService.Heartbeat:Connect(step)
end

local bound = {}
--- Client, once (idempotent): starts the watcher. bindings are SpellshotInput's (Flash, CanCast, AimPoint,
--- BlockedByMovement); a Passive casts nothing, so they are only kept.
function ZephyrUpdraft.Init(bindings)
	if type(bindings) == "table" then bound = bindings end
	ensureStarted()
end
ZephyrUpdraft.Bind = ZephyrUpdraft.Init

----------------------------------------------------------------------------------------------------
-- Handlers (AbilityFX merges them through ZephyrClient)
----------------------------------------------------------------------------------------------------
--- The victim's mark: its own little canvas (no light, two bursts), alive for the bursts' longest particle.
local function playHitMark(at, own)
	local Z = zd()
	if not (Z and type(Z.Play) == "function") then return end
	local fired = {}
	local born = os.clock()
	pcall(Z.Play, "UpdraftHitMark", function(cv, t)
		hitMark(cv, fired, "updraft_mark", at)
		return t < TL.Hit.MarkLife
	end, { Clock = function() return os.clock() - born end, MaxLife = TL.Hit.MarkLife + 1, Own = own })
end

--- UpdraftHit { Character, At, T0, Victim }: an airborne holder's hit landed. The pulse climbs that body (if this
--- screen is drawing its tell), and the victim gets the mark.
ZephyrUpdraft.Handlers.UpdraftHit = function(d)
	if not IS_CLIENT or type(d) ~= "table" then return end
	ensureStarted()
	local c = d.Character
	if typeof(c) == "Instance" then
		local w = watched[c]
		local ep = w and w.Ep
		if ep and not ep.Done then
			local lag = 0
			if type(d.T0) == "number" then
				lag = workspace:GetServerTimeNow() - d.T0
				if lag < 0 or lag > TL.Pulse.MaxLag then lag = 0 end
			end
			ep.THit = ep.Clock() - lag
			ep.HitSeq += 1
		end
	end
	-- the victim's mark -- but not on YOUR body seen from your own eyes: two bursts at your chest would sit on the camera
	-- (the own-view rule the tell keeps; the Wind Blade's sweep draws no cut on you either)
	local victim = d.Victim
	if typeof(d.At) == "Vector3" and not (typeof(victim) == "Instance" and ownView(victim)) then
		local lp = Players.LocalPlayer
		playHitMark(d.At, lp ~= nil and c ~= nil and c == lp.Character)
	end
end

----------------------------------------------------------------------------------------------------
-- DEMO (ZephyrTestHarness): updraft_bl's hero shot played on a character without the server
----------------------------------------------------------------------------------------------------
local DM = TL.Demo

-- zk.EASES (the ease INTO a key)
local EASE = {
	io = function(u) return u * u * (3 - 2 * u) end,
	out = function(u) local v = 1 - u; return 1 - v * v * v end,
	snap = function(u) local v = 1 - u; return 1 - v * v * v * v * v end,
	back = function(u) local v = u - 1; return 1 + 2.70158 * v * v * v + 1.70158 * v * v end,
	lin = function(u) return u end,
}

--- {t, value} keys, smoothstepped between neighbours, held past either end (the Demo's root yaw)
local function keyed(keys, t)
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b[1] then
			local a = keys[i - 1]
			return a[2] + (b[2] - a[2]) * smooth(t, a[1], b[1])
		end
	end
	return keys[#keys][2]
end

--- The stand-in dummy's pose s after the hit (DummyKeys), into `out` (scalars, and the hand / foot fields as arrays).
local DK = DM.DummyKeys
local function dummyPose(dt, out)
	local a, b, w = DK[1], DK[1], 0
	if dt > DK[1].T then
		a, b = DK[#DK], DK[#DK]
		for i = 2, #DK do
			if dt <= DK[i].T then
				a, b = DK[i - 1], DK[i]
				w = (EASE[b.E] or EASE.io)(clamp01((dt - a.T) / (b.T - a.T)))
				break
			end
		end
	end
	for _, f in ipairs({ "P", "R", "Y", "Hd", "HipY", "HipZ", "Slide", "FR", "FL" }) do
		out[f] = a[f] + (b[f] - a[f]) * w
	end
	for _, f in ipairs({ "HR", "HL" }) do
		local va, vb = a[f], b[f]
		out[f] = Vector3.new(va[1] + (vb[1] - va[1]) * w, va[2] + (vb[2] - va[2]) * w, va[3] + (vb[3] - va[3]) * w)
	end
	return out
end

--- A real TrainingDummy whose root stands within UseRealWithin (flat) of `spot`, and any dummy's colour.
local function realDummy(spot)
	local found, color = nil, nil
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("TrainingDummy") then
			local body = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
			if body and body:IsA("BasePart") then color = color or body.Color end
			local r = m:FindFirstChild("HumanoidRootPart")
			if r and not found then
				local d = r.Position - spot
				if Vector3.new(d.X, 0, d.Z).Magnitude < DM.UseRealWithin then found = r end
			end
		end
	end
	return found, color
end

--- The stand-in: six anchored local blocks in the zk blocky figure's sizes (torso 2 x 2 x 1, a 1.2 head, 2.1-stud limbs).
local function buildDummy(color)
	local model = Instance.new("Model")
	model.Name = "UpdraftDemoDummy"
	local parts = {}
	local function block(name, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Color = color
		p.Parent = model
		parts[name] = p
	end
	block("Torso", Vector3.new(2, 2, 1))
	block("Head", Vector3.new(1.2, 1.2, 1.2))
	block("RightArm", Vector3.new(0.95, 0.95, 2.1))
	block("LeftArm", Vector3.new(0.95, 0.95, 2.1))
	block("RightLeg", Vector3.new(0.98, 0.98, 2.1))
	block("LeftLeg", Vector3.new(0.98, 0.98, 2.1))
	model.Parent = workspace:FindFirstChild(fxFolderName()) or workspace
	return model, parts
end

--- Poses the stand-in (updraft_bl.dummy_pose, the DKEYS stagger) at clip time t. cf0: its floor frame, facing the caster.
--- A dummy-local Blender point (x right, y toward the caster, z up) is (x, z, -y) in cf0's Roblox frame.
local dpose = {}
local function poseDummy(parts, cf0, t)
	local k = dummyPose(t - DM.Hit, dpose)
	local base = cf0 * CFrame.new(0, 0, k.Slide)                       -- pushed straight back, away from the caster
	local hip = Vector3.new(0, k.HipZ, -k.HipY)
	local waist = hip + Vector3.new(0, 0.4, 0)
	local rc = CFrame.Angles(0, k.Y, 0) * CFrame.Angles(0, 0, -k.R) * CFrame.Angles(-k.P, 0, 0)
	local chest = base * CFrame.new(waist) * rc
	parts.Torso.CFrame = chest * CFrame.new(0, 0.6, 0)
	parts.Head.CFrame = chest * CFrame.new(0, 1.65, 0) * CFrame.Angles(-k.Hd, 0, 0) * CFrame.new(0, 0.6, 0)
	local upHint = base.LookVector
	for sd, name in ipairs({ "RightArm", "LeftArm" }) do
		local sg = (sd == 1) and 1 or -1
		local s = chest * Vector3.new(1.5 * sg, 1.35, 0)
		local hv = (sd == 1) and k.HR or k.HL
		local h = base * Vector3.new(hv.X, hv.Z, -hv.Y)
		local d = h - s
		if d.Magnitude > 1e-3 then parts[name].CFrame = CFrame.lookAt(s + d.Unit * 1.05, h, upHint) end
	end
	for sd, name in ipairs({ "RightLeg", "LeftLeg" }) do
		local sg = (sd == 1) and 1 or -1
		local hj = base * (hip + Vector3.new(0.5 * sg, 0.1, 0))
		local ft = base * Vector3.new(0.55 * sg, 0, -((sd == 1) and k.FR or k.FL))
		parts[name].CFrame = CFrame.lookAt((hj + ft) * 0.5, ft, upHint)
	end
end

-- updraft_v4.blade: the crescent the flick throws (core + glow on one bowed path), scratch reused every frame
local BL = DM.Blade
local bladePts, bladeCW, bladeGW = {}, {}, {}
for k = 1, BL.Points do
	local s = -0.5 + (k - 1) / (BL.Points - 1)
	local w = sin(pi * (s + 0.5)) ^ BL.Shape
	bladeCW[k] = BL.CoreW[1] * w + BL.CoreW[2]
	bladeGW[k] = BL.GlowW[1] * w + BL.GlowW[2]
end
local OB = {
	core = { fade = 1, glow = BL.CoreGlow, maxSpans = BL.Spans, tag = "updraft_blade" },
	glow = { fade = 1, alpha = BL.GlowAlpha / AR, maxSpans = BL.Spans, tag = "updraft_blade" },
}
local function drawBlade(cv, t, h0, tgt, right)
	if t < DM.Rel or t > DM.Hit + BL.Linger then return end
	local u = span(t, DM.Rel, DM.Hit + BL.Arrive)
	local d = tgt - h0
	if d.Magnitude < 1e-3 then return end
	local dv = d.Unit
	local c = h0 + d * easeOut(u)
	local up = dv:Cross(right)                                         -- the kit's cross(dv, x): the bow's axis
	if up.Magnitude < 1e-3 then return end
	up = up.Unit
	for k = 1, BL.Points do
		local s = -0.5 + (k - 1) / (BL.Points - 1)
		bladePts[k] = c + up * (sin(s * 2) * BL.Bow) - dv * ((1 - cos(s * 2)) * BL.Back)
	end
	local f = 1 - smooth(t, DM.Hit, DM.Hit + BL.Out)
	OB.core.fade, OB.glow.fade = f, f * BL.GlowFade
	call(cv, "Ribbon", bladePts, bladeCW, KIND.Core, OB.core)
	call(cv, "Ribbon", bladePts, bladeGW, KIND.Glow, OB.glow)
end

local function handPos(c, root)
	local h = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	if h and h:IsA("BasePart") then
		return (h.Name == "Right Arm") and (h.Position - h.CFrame.UpVector * (h.Size.Y * 0.4)) or h.Position
	end
	return root.Position + root.CFrame.RightVector * 1.5 + UP * 0.6
end

local currentDemo = nil       -- the last Demo's handle (one at a time: a lifted body must be put back before the next)

--- Stops the demo that is up (the harness calls this after the handle's own Stop; either is enough).
function ZephyrUpdraft.StopDemo()
	local h = currentDemo
	currentDemo = nil
	if h then pcall(h.Stop, h) end
end

--- Demo(character, opts) -> handle { Stop() } | nil. See the header for opts.
function ZephyrUpdraft.Demo(character, opts)
	if not IS_CLIENT then return nil end
	ZephyrUpdraft.StopDemo()
	opts = type(opts) == "table" and opts or {}
	local hum, root = aliveParts(character)
	if not (hum and root) then return nil end
	ensureStarted()
	local lp = Players.LocalPlayer
	local isOwn = lp ~= nil and character == lp.Character

	-- the LIVE path: a real jump on your own body, the watcher's real tell (forced on for JumpWatch s)
	if opts.Jump then
		forced[character] = os.clock() + DM.JumpWatch
		lastScan = -math.huge
		if isOwn then hum.Jump = true end
		currentDemo = { Stop = function() forced[character] = nil end }
		return currentDemo
	end

	local Z = zd()
	if not (Z and type(Z.Play) == "function") then return nil end
	-- the clip owns this body's tell while it plays: the live one (if any) thins away
	demoing[character] = true
	local w = watched[character]
	if w and w.Ep then w.Ep.Cut = true end

	local V0, TA = DM.V0, DM.Air
	local Gb = 2 * V0 / TA                                  -- the Blender jump's gravity (zk.G)
	local TPK = TA * 0.5
	local HPK = V0 * TPK - 0.5 * Gb * TPK * TPK
	local drop = feetDrop(hum, root)
	local baseCF = root.CFrame
	local baseRot = baseCF.Rotation
	local look = flatLook(baseCF)
	-- THE STAGE: +Y is the body's facing turned back by the rest yaw, so the body faces the dummy as the showcase's does
	local sLook = CFrame.Angles(0, -DM.FaceYaw, 0):VectorToWorldSpace(look)
	local sRight = sLook:Cross(UP)
	local feet0 = baseCF.Position - UP * drop
	local function stage(x, y, z) return feet0 + sRight * x + sLook * y + UP * z end
	local ankOff = {}
	for sd, name in ipairs({ "Right", "Left" }) do
		local a = ankle(character, name, root)
		ankOff[sd] = a and (a - baseCF.Position) or Vector3.new(0, -2.7, 0)
	end

	-- the victim: a real dummy standing on the showcase's spot, else the stand-in there
	local spot = stage(DM.Dummy.X, DM.Dummy.Y, 0)
	local real, realColor = realDummy(spot)
	local dummyModel, dummyParts, dummyCF = nil, nil, nil
	local hitAt
	if real then
		hitAt = real.Position + UP * 0.2
	else
		hitAt = spot + UP * DM.HitHeight
		if opts.Dummy ~= false then
			local ok, m, parts = pcall(buildDummy, realColor or DM.DummyColor)
			if ok then
				dummyModel, dummyParts = m, parts
				dummyCF = CFrame.lookAt(spot, Vector3.new(feet0.X, spot.Y, feet0.Z))
			end
		end
	end

	local function zAt(t)
		if t <= 0 or t >= TA then return 0 end
		return V0 * t - 0.5 * Gb * t * t
	end
	local function feetAt(t)
		local ta = math.clamp(t, 0, TA)
		return feet0 + UP * zAt(t) + sLook * (DM.Drift * ta)
	end

	-- own body: lifted along the clip (anchored, restored at the end); anybody else's: the tell draws on a ghost path
	local lift = isOwn and opts.Lift ~= false
	local wasAnchored = root.Anchored
	if lift then root.Anchored = true end

	local ep = {
		Character = character, TakeOff = 0, E0 = 0, LandT = TA, ELand = 1, TPk = TPK, PkSeq = 1, THit = DM.Hit,
		HitSeq = 1, Fired = {}, AirSeq = 1, Jumped = true, TakeoffPos = feet0,
		Scuff = { T = TA, Pos = feetAt(TA), Seq = 1 },
	}
	local S = { C = feet0, E = 0, H = 0, Pk = 0, PE = 0, PZ = 0, Air = false, Own = false, Reduce = 1, Vel = Vector3.zero }
	local freeze = type(opts.Freeze) == "number" and opts.Freeze or nil
	local speed = type(opts.Speed) == "number" and opts.Speed or 1

	-- the ankles' own path (the posed body's real ankles, sampled on CLIP time so the ribbon keeps its 0.3 clip-s
	-- length at any filming speed); a frozen frame or a ghost body uses the computed path
	local hist = { AnkT = {}, AnkR = {}, AnkL = {}, AnkHead = 0, AnkCount = 0, AnkAt = -math.huge }
	local useReal = lift and not freeze
	local clipT = 0
	S.Ankle = function(side, age)
		if useReal and hist.AnkCount > 1 then
			local p = ankAt(hist, side, clipT - age)
			if p then return p end
		end
		return feetAt(clipT - age) + UP * drop + ankOff[side]
	end

	-- THE CLOCK: the filming clock (ZephyrDraw.TimeScale, read every frame) x opts.Speed, accumulated, so the jump, the
	-- body's clip and the arms' clip all slow down together; one value per frame whoever asks first
	local demoT, lastAt = freeze or DM.From, os.clock()
	local function clock()
		if freeze then return freeze end
		local now = os.clock()
		if now ~= lastAt then
			local s = 1
			if type(Z.TimeScale) == "function" then
				local ok, v = pcall(Z.TimeScale)
				if ok and type(v) == "number" and v > 0 then s = v end
			end
			demoT += (now - lastAt) * s * speed
			lastAt = now
		end
		return demoT
	end
	local function clipClock() return max(0, clock() + DM.ClipOffset) end
	if lift then modCall("CastPose", "PlayClocked", character, PS.Jump, clipClock) end
	if isOwn then modCall("Viewmodel", "Play", PS.Jump, clipClock) end

	local h0 = nil                                          -- the right hand at the flick's release
	local finished = false
	local function restore()
		if finished then return end
		finished = true
		demoing[character] = nil
		if lift and root.Parent then
			root.CFrame = baseCF
			root.Anchored = wasAnchored
		end
		if modCall("CastPose", "CurrentClip", character) == PS.Jump then modCall("CastPose", "Stop", character) end
		if isOwn and modCall("Viewmodel", "CurrentClip") == PS.Jump then modCall("Viewmodel", "Stop") end
		if dummyModel then
			dummyModel:Destroy()
			dummyModel = nil
		end
	end
	local ok, handle = pcall(Z.Play, "UpdraftDemo", function(cv, t)
		if not (character.Parent and root.Parent) then return false end
		clipT = t
		local feet = feetAt(t)
		if lift then
			root.CFrame = CFrame.new(baseCF.Position + (feet - feet0)) * CFrame.Angles(0, keyed(DM.Yaw, t), 0) * baseRot
			if useReal and t - hist.AnkAt >= ANK.SampleDt then
				local r, l = ankle(character, "Right", root), ankle(character, "Left", root)
				if r and l then ankPush(hist, t, r, l) end
			end
		end
		if dummyParts then pcall(poseDummy, dummyParts, dummyCF, t) end
		S.C = feet + sRight * TL.Axis.Right + sLook * TL.Axis.Fwd
		-- updraft_bl.tell_on, verbatim
		S.E = smooth(t, 0, TL.Build) * ((t > TA) and (1 - clamp01((t - TA) / TL.Thin)) ^ TL.ThinPow or 1)
		S.H = clamp01(zAt(t) / HPK)
		S.Pk = peakOf(ep, t)
		S.PE, S.PZ = pulseOf(ep, t)
		S.Air = t > 0 and t < TA
		S.Vel = S.Air and (sLook * DM.Drift + UP * (V0 - Gb * t)) or Vector3.zero
		S.Own = isOwn and not opts.Full and ownView(character)
		S.Reduce = reduceFlashing() and TL.ReduceFlashing or 1
		drawTell(cv, t, S, ep)
		-- the flick's blade (updraft_v4.blade): from the right hand where it is at the release, to the dummy's chest
		if t >= DM.Rel and t <= DM.Hit + BL.Linger then
			if not h0 then
				h0 = lift and handPos(character, root) or (feetAt(DM.Rel) + UP * 3.6 + sRight * 1.5)
			end
			drawBlade(cv, t, h0, hitAt, sRight)
		elseif t < DM.Rel then
			h0 = nil
		end
		if t >= DM.Hit then hitMark(cv, ep.Fired, "demo_mark", hitAt) end
		if freeze then return true end
		return t < TA + DM.Tail
	end, { Clock = clock, MaxLife = freeze and math.huge or 600, OnEnd = restore, Budget = "Updraft", Own = isOwn })
	if not ok then
		restore()
		warnOnce("demo", "ZephyrDraw.Play failed: " .. tostring(handle))
		return nil
	end
	currentDemo = {
		Handle = handle,
		Stop = function()
			if handle and type(handle.Stop) == "function" then pcall(handle.Stop, handle) end
			restore()
		end,
	}
	return currentDemo
end

return ZephyrUpdraft
