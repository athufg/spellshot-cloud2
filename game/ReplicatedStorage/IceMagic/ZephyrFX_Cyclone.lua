--[[
	ZephyrFX_Cyclone  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrFX_Cyclone      CLIENT ONLY (inert on the server)
	Zephyr v6 import, 2026-10-06 (vfx_blocking/zephyr/aqua_v6/ROBLOX_IMPORT_PLAN.md, section 4: CYCLONE)

	THE LOOK OF ZEPHYR'S ULTIMATE, CYCLONE, v6: a storm of thick ribbons drawn up into a bulging tornado. It replaces the
	toon Cyclone kit (ZephyrCyclone_Kit placed by InkStroke from ZephyrInkData) outright -- the owner's decision, plan
	section 0. Nothing about what the Cyclone DOES lives here: the catch, the pull, the juggle, the damage and every timing
	the server and the input read stay in ZephyrFX (Tuning.Cyclone, CyclonePullVelocity, CycloneLoopClock, the forming clock
	CycloneFormLeft) and ZephyrHandler, byte for byte. ZephyrFX's Cyclone functions keep their signatures and hand the
	drawing to this module (guarded: a missing or broken look never touches a mechanic).

	WHO CALLS IT
	  ZephyrFX.Cyclone / CycloneSteer / CycloneActive / CycloneEnd    (AbilityFX's Cyclone handlers, SpellshotInput's steering)
	      -> Cyclone.Cyclone / CycloneSteer / CycloneActive / CycloneEnd here, same arguments
	  StarterPlayerScripts.ZephyrTestHarness   -> Cyclone.Demo(character, { Freeze = showcase s })
	Every call is safe on any client at any time; on the server they do nothing.

	THE SOURCES (port them, do not reinvent them)
	  blender_scripts/zephyr/aqua/cyclone_v6.py   THE LOOK: the v6 size H6 / R6, the 72 thick 'blade' ribbons (12 flung),
	                                              the dim core body, the glare x1.9, 5 more flares and 6 more streaks, the
	                                              9 kW core light, rocks + pale sparks + the dust billow, the first-person
	                                              edge glare
	  blender_scripts/zephyr/aqua/cyclone_v5.py   the layers v6 keeps: the core-body shell, flares, streaks, the glare, the
	                                              base disc, the ground ring, the juggle ring pulses, the vapor streamers,
	                                              the release pillar, the floor scuffs, the juggle sparks, the soft dust ring
	  blender_scripts/zephyr/aqua/cyclone_v4.py   the arms' wind (hands()), the touchdown dust / chip / spark bursts, the
	                                              release puffs
	  blender_scripts/zephyr/spring/cyclone_bl.py THE CLOCK: grow, spin (Phi), strength, air_fade, loosen, surge, Hnow,
	                                              axis_xy (the sway), omega / caster_wind -- ported below line for line
	  blender_scripts/zephyr/aqua/za.py, za5.py   the kinds (core / glow / blade / vapor / scuff), ring, burst, Sheet
	The look reference: vfx_blocking/zephyr/aqua_v6/6_cyclone/zs6v_cyclone_sheet.png (birth, touchdown, juggle pulse, the
	pillar, first person).

	WHAT IT DRAWS (ZephyrDraw, IceMagic.ZephyrDraw: one canvas per Cyclone, one shared PointLight)
	  BLADES     Tuning.Blades (72, Flung 12 of them flung past the column at the top; + LowBlades filling the foot, 2026-10-07)
	             thick flat 'blade' ribbons wound round
	             the funnel: each its own height, radius, sweep 1.2..3.4 rad, tilt +-0.9, pitch, width 1.4..4.4 and spin
	             0.55..1.6 x the funnel's, born from the foot up as the funnel grows (v6's 72 / 12: the dense mass of the
	             reel, at 2..3 Hermite spans each to fit the budget; each a soft aqua strand over an opaque aqua body
	             strand -- the daylight recolour, Tuning: THE BLADES IN DAYLIGHT). The
	             funnel's radius is v6's R6(z) = (2.6 + 5.4 (z/H)^0.85 + 1.4 sin(pi z/H)) x the growth scale; its height
	             H6 = 0.74 x the spring build's (about 30 studs, ~16 across the flared top, ~5 at the foot)
	  BODY       the dim core body: v5's inner shell (0.55 R, spinning 1.1x) as a closed 'shell' Sheet (mat_shell's soft
	             foot and rim, e0 0.55 / e1 1.8 / a0 0.45), alpha 0.16, glow 0.55
	  GLARE      the white-hot glare up the axis: a core thread inside two glow sleeves (0.35 / 1.6 / 3.4 wide, v6's x1.9 /
	             x1.5 glow), brightening with the surge
	  TOP        Flares (8) glow ribbons swinging out past the top, Streaks (8) core + glow streaks shooting up diagonally
	             (v5 + v6 had 10 / 12), and Streamers (5) vapor streamers shed off the rim
	  FLOOR      the spinning base disc (6 flat glow arms, 4 -> 13 studs), the ground ring (3 -> 18 studs while it rises),
	             4 dark scuff spirals from touchdown
	  PULSES     a ring climbs the funnel on every juggle tick that lands (see THE JUGGLE)
	  PILLAR     the release: 10 tall narrow streaks while the funnel pulls in to a column, then the slow thinning
	  ARMS       the caster's arm wind: a glow + core trail behind each hand while the arms circle (v4 hands(), caster_wind):
	             the body's hands, or YOUR viewmodel fists in first person (smaller, OwnHandScale)
	  DEBRIS     rocks thrown up through the base, pale sparks, the dust billow (v6, every 0.06 Blender s); the touchdown
	             dust ring + chips + sparks (v4); sparks on each juggled body (v5); puffs off the top at the release (v4)
	             and the soft dust ring left as it thins (v5). ParticleEmitter bursts through cv:Burst (ZephyrDraw thins
	             every count by the Graphics Quality density, and an enemy's under Reduce Enemy VFX)
	  LIGHT      the core light on the axis at 0.35 H: 9000 W x the air x (0.6 + 0.4 strength) x (1 + 0.5 surge) x the
	             kit's sin(23 t) flicker, Range 16, scaled by LightScale so full strength is Brightness ~2.2: the reel's
	             soft pool round the foot, not a teal floor out past the caster
	  YOUR VIEW  your OWN Cyclone washes your screen's edges (ZD.ScreenGlare) with its strength, while your camera is near
	             it (GlareNear .. GlareFar studs from its foot: v6's first-person glare, in the Blender at 20 studs) --
	             in first person only (v6 draws it in the fp shot alone)
	  DEMO       the showcase on the showcase's clock: the funnel 20 studs ahead, the caster's CycloneForm / CycloneRelease
	             clips (CastPose, and the Viewmodel for your own character), two stand-in dummies (DummySim, ported) pulled
	             in, caught, juggled through the six hits (a pulse + sparks each), thrown at the release, landing

	THE CLOCK. The look is a PURE function of the time and four facts -- Start (the cast, minus Late), ActiveAt (the
	touchdown the server announced), EndAt (the end) and the steered centre -- so a late joiner, a missed message and a
	frozen demo frame all land on the same picture. The Blender clock is mapped onto the live beats:
	  LIVE                                        BLENDER (spring/cyclone_bl.py seconds)
	  the cast -> FormTime (1.2 s)                0 -> T_CL1 1.50 at x1.25: the summon, the corkscrew climb, the funnel up
	                                              from a 2-stud seed. It follows the crosshair (CycloneSteer: your own copy
	                                              takes each spot as it comes, never faster than SteerSpeed; everybody
	                                              else's eases after the server's spots at SteerEase) -- the toon's rule
	  formed, touchdown not heard yet             held at 1.50, full height, still turning
	  touchdown (CycloneActive) -> the end        1.50 -> 3.95 at x1: the overshoot, the surge, the dust ring bursting,
	                                              then held at 3.95 (T_CH's draw-back and thrust have no live beat): the
	                                              hold, its spin, sway and pulses running on
	  the end (CycloneEnd, unwinding)             4.18 -> 6.60 over ReleaseTime (x1.86): the surge, THE PILLAR, the slow
	                                              thinning, the last wisps. Look only: the server has let everyone go
	  the end, instant (a new cast, a reset)      gone at once
	The funnel's turn (Phi) and the flow clock (the sway, the streak cycles, the flicker) are integrated piecewise over
	that mapping (a table of the spin's integral), so they never jump and a frozen frame never turns.

	THE JUGGLE. The server does not broadcast its damage ticks; it re-tags every body it hurts AIRBORNE (SpellshotService's
	Status / StatusExpires attributes, refreshed each TickInterval). So each client watches the bodies near a touched-down
	Cyclone (players' characters and the training dummies) and a refreshed AIRBORNE tag on a body inside the catch cylinder
	is a tick landing: a ring pulse climbs the funnel (one per tick, however many bodies) and sparks pop on that body. The
	Demo has no server, so it pulses on the showcase's six hits (Tuning.DemoHits) on its stand-ins. Cyclone.Pulse(character,
	at) is the hook for a future broadcast.

	OWN VIEW (the game is first person). Your funnel stands at the crosshair, 20..70 studs out: drawn as everybody sees it.
	Your arms' wind rides the viewmodel fists, stored in camera space so a turn of the view never smears it, at
	OwnHandScale. Any ribbon whose nearest point comes within NearIn + NearOver studs of a camera fades toward NearFloor
	(bodies juggled inside the funnel, or a caster standing in it, are not blinded by a 4-stud ribbon across the lens).
	The edge glare is yours alone (Reduce Flashing: ZephyrDraw drops its flicker and dims it); the light's 23 rad/s
	flicker is dropped under Reduce Flashing too.

	API
	  Cyclone.Cyclone(character, center, opts)        the cast: opts.Late (s already under way), opts.Own (your own copy)
	  Cyclone.CycloneSteer(character, center)         a forming Cyclone's new spot (ignored once it has touched down)
	  Cyclone.CycloneActive(character, center, late)  touchdown where the server fixed it (a look that missed the cast
	                                                  starts here, formed)
	  Cyclone.CycloneEnd(character, instant)          the end: instant = gone now, otherwise the release plays
	  Cyclone.Pulse(character, at?)                   a juggle tick by hand (at = the struck body's position, for sparks)
	  Cyclone.Demo(character, opts) -> handle         THE SHOWCASE, 1:1 with the reel, without the server (see DEMO above and
	                                                  Cyclone.Demo). opts.Freeze = showcase seconds (the reel's: 0.95 birth,
	                                                  1.56 touchdown, 2.29 juggle pulse, 4.58 the pillar) holds that frame
	                                                  until handle:Stop(). A new Demo stops the last one
	  Cyclone.StopDemo()                              the demo that is up ends now (the harness)
	  Cyclone.StopAll()                               every Cyclone look ends now
	  Cyclone.Tuning                                  the look's numbers (the cast's and the pull's stay ZephyrFX.Tuning.Cyclone)

	NOT LIKE BLENDER. Beams, not meshes (ZephyrDraw's limits: no thickness, linear widths between knots, Catmull-Rom spans
	thinned to maxSpans); 72 blades of 9 knots for 26, 8 / 10 flares and streaks for 10 / 12, a 7 x 8 core body for 24 x 22; the
	particles are ParticleEmitter bursts, not the Blender's field-advected sprites, so the swirl is an initial sideways
	kick (SwirlKick, BillowSwirl) rather than a flow; v5's orbiting pebbles and v4's mist / specks / inflow streak particles
	are not drawn (the handoff's three floor emitters); the hold is the steady state (the Blender's channel arms, draw-back
	and thrust are not live beats: in game the palms push out at touchdown, CastPose / Viewmodel CycloneRelease, so the
	arms' wind fades over HandFadeAfterTouchdown); randomness is Random.new seeds, not numpy's.
	BUDGET (counted the engine's way): about 600 Beams through the hold (blades ~360 = 72 x ~2.5 spans x 2 strands, the
	foot's fill ~80, body 24, floor ~34, top ~54, glare 9, hands 12, a pulse 4 each), 1 light -- under ZD.Budgets.Cyclone
	(640 / 1), which Play's opts.Budget = "Cyclone" checks.
	UNVERIFIED WITHOUT PLAY (the main session tunes these in Play): the blade / body / glare brightness under the place's
	Bloom (I 0.6, Size 24, Threshold 1.6) -- ZephyrDraw's calibration; LightScale; ReleaseTime; Scale; the glare's level and
	reach; the near fade; the debris sizes and the swirl kick; whether the juggle detection sees every tick on a dummy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cyclone = {}

----------------------------------------------------------------------------------------------------
-- TUNING (the look only; the cast, the catch and the pull are ZephyrFX.Tuning.Cyclone, read through shared())
----------------------------------------------------------------------------------------------------
local Tuning = {
	-- THE BLENDER CLOCK (spring/cyclone_bl.py, seconds from the Ultimate press): the beats the curves below are keyed on
	T_CL0 = 0.28,          -- the corkscrew climb starts, arms low ...
	T_CL1 = 1.50,          -- ... and touches down: the funnel at full height
	T_CH = 4.00,           -- the channel ends (the draw-back, the thrust: no live beat)
	T_REL = 4.38,          -- the release: the surge and the pillar
	T_TH0 = 4.50,          -- the slow thinning ...
	T_TH1 = 6.30,          -- ... to here
	HF = 40,               -- the spring build's full funnel height (studs) ...
	HeightShare = 0.74,    -- ... of which v6 draws this (cyclone_v6.H6: about 30 studs, 5.5 character heights)
	OMF = 6.4,             -- the funnel's full spin, rad/s, counter-clockwise seen from above
	W0 = 2.6, W1 = 15.0, WC = 3.2,   -- the arms' turn (rad/s): the climb's start, its top, the channel (omega)

	-- THE LIVE MAPPING (see the header's table)
	HoldCap = 3.95,        -- the hold shows this Blender second for as long as it lasts: the steady state, before T_CH
	ReleaseFrom = 4.18,    -- the release plays from here (0.2 s ahead of T_REL, so the surge rises instead of popping) ...
	ReleaseTo = 6.60,      -- ... to where the air has gone (T_TH1 + 0.30) ...
	ReleaseTime = 1.3,     -- PROVISIONAL (v6 import): ... over this many live seconds (x1.86; the toon unwind took 0.5)
	ParticleTail = 1.2,    -- s the canvas outlives the funnel, so the last thrown rocks land before their emitters go
	Lost = 3,              -- s past its whole life (FormTime + ActiveTime), a look that never heard its end releases itself
	MaxLifeSlack = 5,      -- s on top of the longest life ZephyrDraw lets one Cyclone run (its own backstop)
	Scale = 1.0,           -- PROVISIONAL (v6 import): the look's size against the Blender studs (1: ~30 tall, ~8 round at
	                       -- the top, the ground ring out to 18). The pull's Radius (26) is gameplay and does not change it

	-- THE BLADES (cyclone_v6: 72 thick ribbons, the last 12 flung; the plan: 24..30, 4..6 flung)
	Blades = 72,           -- the owner (2026-10-07): 'the tornado looks different' -- back to the Blender's 72 (the v6
	                       -- import drew 44); each span is 2 Beams (the blade and its body strand, below)
	BladeWidth = 0.8,      -- the owner (2026-10-07, 2nd look): 1.35 read as flat solid sheets; thinner strokes leave the Blender gaps
	LookRadius = 1.3,      -- the owner (2026-10-07): the Blender funnel flares ~1.3x wider than the port drew (LOOK only)
	Flung = 12,            -- ... the last this many of them flung past the column at the top (v6: 12 of 72)
	MinBlades = 14,        -- the unflung blades never drop under this (Graphics Quality LOW)
	ThinShare = 0.65,      -- an enemy's Cyclone under Reduce Enemy VFX keeps this share of its blades
	BladePts = 9,          -- knots per blade (the Blender's 26; ZephyrDraw fits Catmull-Rom spans through them)
	SpanPerRad = 1.15,     -- one span per this much sweep (rad), MinBladeSpans..MaxBladeSpans spans a blade (a span
	MinBladeSpans = 2,     -- is a Hermite curve: ~100 degrees of arc each still reads round)
	MaxBladeSpans = 3,
	BladeSeed = 66,        -- cyclone_v6's numpy seed, kept as the Random seed
	-- THE BLADES IN DAYLIGHT (the owner, 2026-10-07, the in-game take vs the Blender frame: 'make it similar'). In game
	-- the ribbons read PALE, THIN and SEE-THROUGH (the sky through them) with a sparse foot; the Blender's are thick,
	-- near-opaque, saturated aqua with soft edges and a thin hot centre, overlapping into one dense mass. Why: the
	-- zd_blade strip's own alpha (1 - ss(|v|, 0.06, 0.95) x the streak breakup) averages ~0.4 across the width, so a
	-- Beam at Transparency 0 still shows ~60% of the sky -- and the white bladecore strip (LE 0.8, additive) on top
	-- washed what was left toward white. Raising o.alpha cannot pass the texture, so each blade's INNER strand is
	-- recoloured into an opaque aqua BODY (the bladecore strip is solid in its middle) under the soft-edged outer one:
	-- ~0.95 opaque at the centre, ~0.75 a third of the way out, feathering to nothing at the edge. Per-call options
	-- only (o.color / o.le / o.e0 / o.e1 / o.core / o.inner_w): the shared "blade" kind is the other moves' too.
	BladeColor = Color3.fromRGB(94, 230, 216),    -- #5EE6D8, the Blender frame's ribbon aqua (the outer, soft strand)
	BladeHotColor = Color3.fromRGB(190, 250, 244),   -- the body strand: a shade lighter, so the centre reads hot
	BladeBodyShare = 0.32, -- the body strand's width, x the blade's (its alpha ~1 in its middle, ~0 at its edge)
	BladeLE = 0.06,        -- LightEmission: nearly pure alpha blend -- the sky must not add through (it read white)
	BladeBodyLE = 0.35,    -- a glowing centre line in each stroke, as the Blender (was 0.12: no centre)
	BladeE0 = 1.2, BladeE1 = 0.8,   -- Brightness ~1.18 (1 + 1/8 (e0 + e1 h^2), h ~0.6): the strip's luminance falls to
	                       -- ~0.84 a quarter out, so x1.18 lands the visible band on #5EE6D8 (its clipped centre is
	                       -- under the body strand); a surge (glow 1.6) takes it to ~1.3, still under Bloom's 1.6
	BladeBodyE0 = 0.2, BladeBodyE1 = 0.2,   -- the body: Brightness ~1.07 (BS 1.5) -- saturated, not a blooming white
	-- THE FOOT'S FILL: the Blender's 72 blades sit on a funnel ~1/3 the top's width at the foot, so its lower third
	-- overlaps into a solid mass; at the port's LookRadius and in daylight the same share read as a few separate
	-- strands. These extra unflung blades (their own seed: the 72 keep the Blender scatter) wind round the lower half.
	LowBlades = 6,        -- PROVISIONAL: ~2.8 spans x 2 Beams each (~80 Beams; the whole funnel stays under 640)
	LowSeed = 67,

	-- THE BODY, GLARE AND TOP
	BodyRows = 7, BodyCols = 8,   -- the core body Sheet: rows up the height x columns round it (v5's shell 24 x 22)
	BodyAlpha = 0.16, BodyGlow = 0.55,   -- cyclone_v6: "the core body: dim vapor, not glass"
	BodyE0 = 0.55, BodyE1 = 1.8, BodyA0 = 0.45,   -- its mat_shell (cyclone_v5's shell 2: e0, e1, a0)
	GlarePts = 6,          -- knots up the glare (the Blender's 30)
	Flares = 8,            -- PROVISIONAL (v6 import): flare ribbons (v5 5 + v6 5 = 10; the plan: 5..8)
	Streaks = 10,          -- PROVISIONAL (v6 import): core + glow streaks shooting up (v5 6 + v6 6 = 12); 8 -> 10
	                       -- (2026-10-07): the Blender frame's top reads as several long white streaks, the port's as one
	StreakRise = 2.2,      -- their rise per stud out (the Blender's 1.4 -- ~54 deg; its frame reads near-vertical through
	                       -- its lens: at the game's wider FOV 1.4 read as a sideways spray)
	StreakLen = 9,         -- studs long (the Blender's 6: through the game's FOV they read as short dashes)
	StreakCoreW = 0.15, StreakGlowW = 0.45,   -- the Blender's 0.10 / 0.6: a thin WHITE line, not an aqua smear
	StreakZ = 3,           -- studs of ZOffset: they leave from inside the (now opaque) top, which hid their first third
	-- THE GLARE's white thread up the axis (the Blender: visible over the whole funnel). Its ZOffset pulls it in front of
	-- the near wall of opaque blades -- up to the funnel's own radius, never past GlareZGap studs short of your camera
	-- (a ZOffset past the camera would drop it from view, e.g. for a body juggled inside the funnel)
	GlareZGap = 4,
	-- THE FLOOR SPIRAL (the base disc) on the noon floor: the Blender alpha 0.5 / LE 0.3 read as nothing on the grey
	-- floor (the in-game take shows no ring); a little more body and light so its spiral of rings reads
	DiscAlpha = 0.8, DiscLE = 0.45, DiscGlow = 1.0,
	TopSeed = 12,          -- cyclone_v5's seed, for the flares' and streaks' scatter
	FlarePts = 6, StreamerPts = 6, Streamers = 5,
	DiscArms = 6, DiscPts = 7, ScuffArms = 4, ScuffPts = 6, PillarLines = 10,
	RingSpans = 4,         -- spans per closed ring (the ground ring, the pulses: ZephyrDraw's rings are exact at 90 deg)
	BodySpans = 3,         -- spans up each band of the core body (a smooth profile: 3 Hermite spans hold it)

	-- THE JUGGLE (see the header): pulses, sparks
	PulseTime = 0.42,      -- s a pulse takes to climb the funnel (cyclone_v5: th -> th + 0.42)
	PulseGap = 0.2,        -- ticks landing on several bodies at once make ONE pulse: a new one no sooner than this (s)
	MaxPulses = 6,         -- pulses kept at once (the Blender's six hits)
	ScanEvery = 0.5,       -- s between looks for bodies near a touched-down Cyclone
	DummyRescan = 10,      -- s the training dummies list is kept (workspace.TrainingGround, attribute TrainingDummy)
	CatchSlack = 6,        -- studs over the catch cylinder's top a juggled root may be (it bobs over JuggleHeight)
	HitSparkLift = 1.5,    -- studs over the body's root the juggle sparks pop (the Blender: root + 2.6 on its rig)

	-- THE ARMS' WIND (cyclone_v4.hands: path ribbons of the hands, glow 0.28 s 0.45 -> 0.1, core 0.18 s 0.09 -> 0.02)
	HandSpan = 0.28, HandCoreSpan = 0.18, HandPts = 6,
	HandGlowW = { 0.45, 0.10 }, HandCoreW = { 0.09, 0.02 },
	HandFadeAfterTouchdown = 0.35,   -- s: the game's palms push out at touchdown (CycloneRelease), so the wind lets go
	OwnHandScale = 0.6,    -- PROVISIONAL (v6 import): your own fists' wind, this much thinner (they sit a stud or two away)
	HandKeep = 0.4,        -- s of hand history kept

	-- THE LIGHT (v6: 9000 W x e; the handoff: Range 30, Brightness 5 at full)
	LightWatts = 9000,
	LightScale = 0.15,     -- PROVISIONAL (v6 import): full strength at Brightness ~2.2. The v6 light washes the floor in a
	                       -- soft pool round the foot (the reel: ~12 studs); at Brightness 5 / Range 30 the noon floor
	                       -- turned teal out past the caster (the in-game capture)
	LightRange = 16, LightAt = 0.35, LightAxisAt = 0.4,   -- on the axis (as it sways at 0.4 H), 0.35 H up: Range 16 from
	                       -- ~10 studs up lights a ~12-stud pool on the floor

	-- YOUR VIEW: the edge glare (cyclone_v6 fp: a 5 x 48 annulus 0.6 studs ahead, alpha 0.7)
	GlareNear = 24,        -- PROVISIONAL (v6 import): full glare with your camera this near the funnel's foot (the
	GlareFar = 60,         -- Blender's caster stood at 20) ... none from this far (the Range is 70)
	GlareFlicker = 0.15, GlareHz = 19,   -- the Blender's (0.85 + 0.15 sin(19 t)), handed to ZD.ScreenGlare (its alpha
	                       -- 0.7 is ZephyrDraw's Config.Glare.Max; Reduce Flashing: ZephyrDraw drops the flicker, x0.6)

	-- THE NEAR FADE (every view): a ribbon reaching within NearIn + NearOver studs of the camera fades toward NearFloor
	NearIn = 1.5,          -- PROVISIONAL (v6 import)
	NearOver = 4,
	NearFloor = 0.15,

	-- THE DEBRIS (cyclone_v6: tb 0.4 .. 4.5 every 0.06 -> a rock, a pale spark, half the time a billow puff)
	DebrisFrom = 0.4, DebrisEvery = 0.06, BillowShare = 0.5,
	MaxCatchUp = 3,        -- events a frame may fire after a hitch (or a frozen demo frame): the rest are skipped
	SwirlKick = 9,         -- PROVISIONAL (v6 import): studs/s round the axis given to thrown rocks (the Blender's swirl
	                       -- field, about 13 at the foot's wall, carried them; a burst cannot follow a field)
	BillowSwirl = 4, BillowInflow = 3,   -- PROVISIONAL (v6 import): the billow's drift round and in (field: ~5 and ~9 * e^-z)
	-- za's KINDS base sizes (studs): a burst's size is za's multiplier of them (BurstSizeIsMultiplier, below)
	KindBase = { chip = 0.17, spark = 0.36, dust = 1.1, puff = 0.6, mist = 1.0, speck = 0.07, glint = 0.09 },
	BurstSizeIsMultiplier = true,   -- ZephyrDraw's cv:Burst o.size: za's multiplier (true) or studs (false)

	-- Blender alpha -> ZephyrDraw alpha: ZephyrDraw's o.alpha IS za's zk_alpha (0.5 = the kind's own opacity), so 1
	AlphaFromBlender = 1.4,   -- the owner (2026-10-07): the daylight range needs more body than the dark Blender stage

	-- THE DEMO (the showcase staged without a server: spring/cyclone_bl.py, cyclone_v5 HITS)
	DemoAhead = 20,        -- studs: the funnel's foot straight ahead of the caster (C0 = (0, 20, 0))
	DemoDummies = {        -- D1 / D2: start (caster frame from the foot: x right, y forward), catch s, seed, tumble rad/s
		{ x = -7.6, y = -4.2, catch = 1.30, seed = 0.3, tumble = { 0.9, 0.35, 1.2 } },
		{ x = 6.4, y = 6.6, catch = 1.56, seed = 1.1, tumble = { -0.5, -0.8, 0.9 } },
	},
	DemoHits = { 1.85, 2.27, 2.69, 3.11, 3.53, 3.95 },   -- the six juggle hits (alternating dummies): a pulse each
	DemoFormRate = 1.25,   -- Blender s per CycloneForm clip s (its keys sit on the live 1.2 s form: T_CL1 1.5 / 1.2)
	DemoReleaseClip = 3.75,   -- Blender s CycloneRelease starts: its draw-back key (0.53) lands on T_THR 4.28, the thrust
	                          -- (0.65) on T_THR + 0.12
	DummyColor = Color3.fromRGB(222, 196, 150),   -- the reel's pale training-dummy tan
}
Cyclone.Tuning = Tuning

-- the shared numbers' stand-ins, for a place where ZephyrFX cannot be read (they are ZephyrFX.Tuning.Cyclone's)
local SHARED_FALLBACK = {
	FormTime = 1.2, ActiveTime = 4, LateMax = 0.5, SteerEase = 18, SteerSpeed = 60, Radius = 26, HoldSlack = 5,
	Height = 26, Below = 3, FirstTick = 0.25, TickInterval = 0.5,
}

----------------------------------------------------------------------------------------------------
-- LAZY REQUIRES (nothing here runs at require: the module is inert on the server)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrFX_Cyclone] " .. msg)
end

--- Your own character (nil with no LocalPlayer: the Edit DataModel, the server).
local function localCharacter()
	local lp = Players.LocalPlayer
	return lp and lp.Character or nil
end

local function iceFolder()
	return ReplicatedStorage:FindFirstChild("IceMagic")
end

local ZD = nil                 -- IceMagic.ZephyrDraw; false once it failed to load (a missing one is looked for again)
local function engine()
	if ZD == nil then
		local folder = iceFolder()
		local m = folder and folder:FindFirstChild("ZephyrDraw")
		if not m then
			warnOnce("zd", "IceMagic.ZephyrDraw is not in the place - the Cyclone pulls and hurts, undrawn")
			return nil
		end
		local ok, mod = pcall(require, m)
		if ok and type(mod) == "table" then
			ZD = mod
		else
			ZD = false
			warnOnce("zdload", "IceMagic.ZephyrDraw failed to load - the Cyclone is undrawn: " .. tostring(mod))
		end
	end
	return ZD or nil
end

local ZephyrFX = nil
--- ZephyrFX.Tuning.Cyclone: the cast's clocks (FormTime, ActiveTime, LateMax, SteerEase, SteerSpeed) and the catch
--- (Radius, HoldSlack, Height, Below, FirstTick, TickInterval) the look keeps step with. ZephyrFX requires THIS module
--- only from inside its functions, so requiring it back here is never a cycle.
local function shared()
	if ZephyrFX == nil then
		ZephyrFX = false
		local folder = iceFolder()
		local m = folder and folder:FindFirstChild("ZephyrFX")
		local ok, mod = pcall(function() return m and require(m) end)
		if ok and type(mod) == "table" then ZephyrFX = mod end
	end
	local C = ZephyrFX and ZephyrFX.Tuning and ZephyrFX.Tuning.Cyclone
	return C or SHARED_FALLBACK
end

local Settings = nil
local function settings()
	if Settings == nil then
		Settings = false
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = folder and folder:FindFirstChild("SpellshotSettings")
		local ok, s = pcall(function() return m and require(m) end)
		if ok and type(s) == "table" then Settings = s end
	end
	return Settings or nil
end

local function reduceFlashing()
	local s = settings()
	if not (s and type(s.Get) == "function") then return false end
	local ok, v = pcall(s.Get, "ReduceFlashing")
	return ok and v == true
end

--- Graphics Quality's effect density (SettingsRuntime), halved for somebody else's Cyclone under Reduce Enemy VFX.
local function density(thin)
	local s = settings()
	local d = (s and type(s.EffectDensity) == "number") and s.EffectDensity or 1
	if thin and s and s.ThinEnemyVFX then d *= 0.5 end
	return d
end

local Viewmodel = nil
local function viewmodel()
	if Viewmodel == nil then
		Viewmodel = false
		local folder = iceFolder()
		local m = folder and folder:FindFirstChild("Viewmodel")
		if m then
			local ok, v = pcall(require, m)
			if ok and type(v) == "table" then Viewmodel = v end
		end
	end
	return Viewmodel or nil
end

----------------------------------------------------------------------------------------------------
-- MATHS (pyro_kit / zk: smooth = smoothstep, ease_out = cubic, span = a clamped ramp)
----------------------------------------------------------------------------------------------------
local sin, cos, exp, sqrt, min, max, floor, ceil, pi = math.sin, math.cos, math.exp, math.sqrt, math.min, math.max,
	math.floor, math.ceil, math.pi
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)
local T = Tuning

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function clamp01(x)
	return clamp(x, 0, 1)
end

local function sm(x, a, b)
	local u = clamp01((x - a) / (b - a))
	return u * u * (3 - 2 * u)
end

local function span(t, a, b)
	if b > a then return clamp01((t - a) / (b - a)) end
	return t >= b and 1 or 0
end

local function easeOut(u)
	u = clamp01(u)
	return 1 - (1 - u) ^ 3
end

local function lerp(a, b, u)
	return a + (b - a) * u
end

----------------------------------------------------------------------------------------------------
-- THE BLENDER CLOCK (spring/cyclone_bl.py, line for line; t = Blender seconds from the press)
----------------------------------------------------------------------------------------------------
--- The arms' angular speed (rad/s): the climb accelerates W0 -> W1, settles to WC in the channel, stops at T_CH.
local function omega(t)
	if t < T.T_CL0 then return T.W0 * sm(t, T.T_CL0 - 0.22, T.T_CL0) end
	if t < T.T_CL1 then
		local s = (t - T.T_CL0) / (T.T_CL1 - T.T_CL0)
		return T.W0 + (T.W1 - T.W0) * s ^ 1.5
	end
	if t < T.T_CH then return T.WC + (T.W1 - T.WC) * exp(-(t - T.T_CL1) / 0.16) end
	return T.WC * (1 - sm(t, T.T_CH, T.T_CH + 0.22))
end

--- The funnel's height as a share of full: a 2-stud seed, up with the arms, a ~9% overshoot at touchdown, settling
--- (a damped spring: w 8, z 0.55).
local function grow(t)
	local seed = 0.05 * sm(t, 0.06, 0.30)
	local spanC = T.T_CL1 - T.T_CL0 - 0.03
	if t <= T.T_CL1 then
		local s = clamp01((t - T.T_CL0 - 0.03) / spanC)
		return seed + (1 - seed) * s ^ 1.7
	end
	local u = t - T.T_CL1
	local v0 = 1.7 * (1 - 0.05) / spanC
	local w, z = 8.0, 0.55
	local wd = w * sqrt(1 - z * z)
	return 1 + v0 / wd * exp(-z * w * u) * sin(wd * u)
end

--- The funnel's spin as a share of OMF: follows the arms through the climb, holds, surges at the release, slows as it thins.
local function spin(t)
	if t < T.T_CL1 then return max(0.22 * sm(t, 0.06, 0.30), omega(t) / T.W1) end
	local s = 1.0
	if t > T.T_REL then s += 0.35 * exp(-(t - T.T_REL) / 0.22) end
	return s * (1 - 0.72 * sm(t, T.T_TH0, T.T_TH1))
end

local function strength(t)
	local s = 0.22 * sm(t, 0.06, 0.35) + 0.78 * clamp01(grow(t))
	if t > T.T_REL then s *= 1 + 0.3 * exp(-(t - T.T_REL) / 0.3) end
	return s * (1 - sm(t, T.T_TH0, T.T_TH1 + 0.15))
end

local function airFade(t)
	return sm(t, 0.04, 0.30) * (1 - sm(t, T.T_TH0 + 0.45, T.T_TH1 + 0.30))
end

local function loosen(t)
	return sm(t, T.T_TH0, T.T_TH1)
end

--- The release pulse and (smaller) the touchdown pulse: the funnel swells and its core brightens a moment.
local function surge(t)
	return exp(-((t - T.T_REL - 0.06) / 0.13) ^ 2) + 0.7 * exp(-((t - T.T_CL1 - 0.05) / 0.12) ^ 2)
end

local function hNow(t)
	return T.HF * max(grow(t), 0.03) * (1 + 0.14 * loosen(t))
end

--- cyclone_v5.pillar: the release column, up over 0.1 s, gone by T_REL + 0.9.
local function pillar(t)
	local p0, p1 = T.T_REL, T.T_REL + 0.55
	return sm(t, p0, p0 + 0.10) * (1 - sm(t, p1 - 0.1, p1 + 0.35))
end

--- The caster's own spiral: builds with the arm spin, light in the channel, gone after T_CH.
local function casterWind(t)
	return (sm(t, 0.05, 0.35) * (0.25 + 0.75 * omega(t) / T.W1)) * (1 - sm(t, T.T_CH, T.T_CH + 0.5))
end

--- cyclone_v6.R6's shape, before the growth scale: zz = z / H, clamped 0 .. 1.2.
local function radiusShape(zz)
	return 2.6 + 5.4 * zz ^ 0.85 + 1.4 * sin(pi * min(zz, 1))
end

--- The funnel's axis sways (spring axis_xy): fixed at the foot, ~1 stud at the v6 top. Returns the Blender (x, y) offset
--- from the foot; `fl` is the flow clock, `gk` = min(1, grow).
local function axisXY(z, fl, gk)
	local zz = clamp(z / T.HF, 0, 1.3)
	local k = zz ^ 1.4 * gk
	local ox = (1.5 * sin(0.5 * fl + 2.4 * zz + 0.6) + 0.4 * sin(1.4 * fl + 6.0 * zz)) * k
	local oy = 1.1 * sin(0.37 * fl + 1.9 * zz + 2.1) * k
	return ox, oy
end

-- THE FUNNEL'S TURN: Phi(t) = OMF x the integral of spin, tabled once (the spring build's _PH, at 5 ms)
local PHI_T0, PHI_DT, PHI_N = -1.0, 0.005, 1801
local phiTable = nil

local function buildPhi()
	phiTable = table.create(PHI_N)
	phiTable[1] = 0
	local acc, prev = 0, spin(PHI_T0)
	for i = 2, PHI_N do
		local s = spin(PHI_T0 + (i - 1) * PHI_DT)
		acc += 0.5 * (prev + s) * PHI_DT
		phiTable[i] = acc
		prev = s
	end
end

--- The integral of spin from PHI_T0 to t (Blender seconds), linear outside the table.
local function spinIntegral(t)
	if not phiTable then buildPhi() end
	local x = (t - PHI_T0) / PHI_DT + 1
	if x <= 1 then return (t - PHI_T0) * spin(PHI_T0) end
	if x >= PHI_N then
		local tN = PHI_T0 + (PHI_N - 1) * PHI_DT
		return phiTable[PHI_N] + (t - tN) * spin(tN)
	end
	local i = floor(x)
	return phiTable[i] + (phiTable[i + 1] - phiTable[i]) * (x - i)
end

----------------------------------------------------------------------------------------------------
-- THE LIVE CLOCK -> THE BLENDER CLOCK (pure in the time: see the header's table)
----------------------------------------------------------------------------------------------------
--- Forming at absolute time x: the Blender second shown, the funnel's phase (rad) and the flow clock.
local function evalForm(look, x, C)
	local tl = x - look.Start
	local rate = T.T_CL1 / max(C.FormTime, 0.05)
	local tB = clamp(tl * rate, PHI_T0, T.T_CL1)
	local wait = max(0, tl - C.FormTime)          -- formed, touchdown not heard yet: full height, turning at spin 1
	return tB, T.OMF * (spinIntegral(tB) + wait), tB + wait
end

--- Touched down (x >= ActiveAt): the overshoot plays at x1, then the hold is held at HoldCap, still turning.
local function evalHold(look, x, C)
	local a = look.ActiveAt
	local _, ph0, fl0 = evalForm(look, a, C)
	local since = x - a
	local tB = min(T.T_CL1 + since, T.HoldCap)
	local over = max(0, T.T_CL1 + since - T.HoldCap)
	return tB, ph0 + T.OMF * (spinIntegral(tB) - spinIntegral(T.T_CL1) + over * spin(T.HoldCap)), fl0 + since
end

local function evalLive(look, x, C)
	if look.ActiveAt and x >= look.ActiveAt then return evalHold(look, x, C) end
	return evalForm(look, x, C)
end

--- The look at absolute time x: Blender second, phase, flow clock, and whether it is the release.
local function evaluate(look, x, C)
	if look.Blender then
		-- the demo runs the showcase's own clock 1:1 (x = Blender seconds from the press: the reel's timing)
		return x, T.OMF * spinIntegral(x), x, x >= T.ReleaseFrom
	end
	local e = look.EndAt
	if e and x >= e then
		local _, ph0, fl0 = evalLive(look, e, C)
		local rate = (T.ReleaseTo - T.ReleaseFrom) / max(T.ReleaseTime, 0.05)
		local tB = T.ReleaseFrom + (x - e) * rate
		return tB, ph0 + T.OMF * (spinIntegral(tB) - spinIntegral(T.ReleaseFrom)), fl0 + (tB - T.ReleaseFrom), true
	end
	local tB, ph, fl = evalLive(look, x, C)
	return tB, ph, fl, false
end

----------------------------------------------------------------------------------------------------
-- THE SCATTER (seeded once: every client draws the same funnel)
----------------------------------------------------------------------------------------------------
local bladeDefs, flareDefs, streakDefs = nil, nil, nil
local BLADE_PROFILE = nil     -- sin(pi clip(s 0.94 + 0.03))^0.4 along a blade

local function scatter()
	if bladeDefs then return end
	bladeDefs = {}
	local rs = Random.new(T.BladeSeed)
	for i = 1, T.Blades do
		local flung = i > T.Blades - T.Flung
		local d = { Flung = flung }
		d.a0 = rs:NextNumber(0, 6.28)
		d.rk = flung and rs:NextNumber(0.95, 1.35) or rs:NextNumber(0.5, 1.15)
		d.zh = flung and rs:NextNumber(0.82, 1.0) or rs:NextNumber(0.12, 1.0)
		d.sweep = rs:NextNumber(1.2, 3.4)
		d.pitch = rs:NextNumber(-0.12, 0.35)
		d.wd = rs:NextNumber(1.4, 4.4)
		d.sp = rs:NextNumber(0.55, 1.6)
		d.tilt = rs:NextNumber(-0.9, 0.9)
		d.al = rs:NextNumber(0.45, 0.85)
		d.scroll = rs:NextNumber(1.5, 3.0)       -- the handoff: the texture flows along a strip at 1.5..3 studs/s
		d.ct, d.st = cos(d.tilt), sin(d.tilt)
		d.spans = clamp(ceil(d.sweep / T.SpanPerRad), T.MinBladeSpans, T.MaxBladeSpans)
		bladeDefs[i] = d
	end
	-- the foot's fill (see Tuning.LowBlades): the lower half, tighter in, longer sweeps and broader than the 72's low
	-- ones (the width tapers to 0.55 at the foot), each on its own spin
	local rl = Random.new(T.LowSeed)
	for i = 1, T.LowBlades do
		local d = { Flung = false, Low = true }
		d.a0 = rl:NextNumber(0, 6.28)
		d.rk = rl:NextNumber(0.55, 1.05)
		d.zh = rl:NextNumber(0.08, 0.55)
		d.sweep = rl:NextNumber(2.0, 3.4)
		d.pitch = rl:NextNumber(-0.05, 0.25)
		d.wd = rl:NextNumber(2.4, 4.4)
		d.sp = rl:NextNumber(0.7, 1.5)
		d.tilt = rl:NextNumber(-0.7, 0.7)
		d.al = rl:NextNumber(0.6, 0.85)
		d.scroll = rl:NextNumber(1.5, 3.0)
		d.ct, d.st = cos(d.tilt), sin(d.tilt)
		d.spans = clamp(ceil(d.sweep / T.SpanPerRad), T.MinBladeSpans, T.MaxBladeSpans)
		bladeDefs[T.Blades + i] = d
	end
	local rt = Random.new(T.TopSeed)
	flareDefs, streakDefs = {}, {}
	for i = 1, T.Flares do
		flareDefs[i] = { a0 = rt:NextNumber(0, 6.28), rk = rt:NextNumber(0.8, 1.4) }
	end
	for i = 1, T.Streaks do
		streakDefs[i] = { a0 = rt:NextNumber(0, 6.28), ph = rt:NextNumber(0, 1) }
	end
	BLADE_PROFILE = {}
	for k = 1, T.BladePts do
		local s = (k - 1) / (T.BladePts - 1)
		BLADE_PROFILE[k] = sin(pi * clamp(s * 0.94 + 0.03, 0, 1)) ^ 0.4
	end
end

----------------------------------------------------------------------------------------------------
-- LOOKS
----------------------------------------------------------------------------------------------------
local looks = {}               -- [character] = look (the live ones; a demo is apart)
local demoLook = nil
local nextId = 0

local function newArrays(n)
	return table.create(n, Vector3.zero), table.create(n, 0), table.create(n, UP)
end

--- A look's own drawing state: the blade set its Graphics Quality allows, and every array and option table it reuses.
local function newLook(character, center, start, own, demo)
	scatter()
	nextId += 1
	local thin = (not demo) and not own
	-- the single-particle debris events thin by this (ZephyrDraw thins every burst's count by the same density itself)
	local zd = engine()
	local d = (zd and type(zd.Density) == "function") and zd.Density(not thin) or density(thin)
	local s = settings()
	local share = clamp(density(false), 0.5, 1) * ((thin and s and s.ThinEnemyVFX) and T.ThinShare or 1)   -- the blades
	local look = {
		Id = nextId, Character = character, Center = center, Target = center, Start = start, Own = own, Demo = demo,
		Density = d, Seed = nextId * 7919, Ev = { debris = -1, dustRing = -1, demoTick = -1 },
		Pulses = {}, PendingHits = {}, Bodies = {}, NextScan = -math.huge, LastPulse = -math.huge,
		Hands = { R = {}, L = {} }, Blades = {},
	}
	-- the blades: the unflung ones first, then the flung (cyclone_v6 keeps them last)
	local nf = max(3, floor(T.Flung * share + 0.5))
	local nb = max(T.MinBlades, floor((T.Blades - T.Flung) * share + 0.5))
	local nl = floor(T.LowBlades * share + 0.5)                -- the foot's fill thins with the rest
	local took, tookF, tookL = 0, 0, 0
	for _, def in ipairs(bladeDefs) do
		local take = false
		if def.Low then
			if tookL < nl then tookL += 1 take = true end
		elseif def.Flung then
			if tookF < nf then tookF += 1 take = true end
		elseif took < nb then
			took += 1
			take = true
		end
		if take then
			local pts, wid, side = newArrays(T.BladePts)
			local widI = table.create(T.BladePts, 0)
			table.insert(look.Blades, {
				D = def, Pts = pts, Wid = wid, Side = side, WidI = widI,
				-- the daylight look (Tuning: THE BLADES IN DAYLIGHT): the outer soft strand in the Blender aqua, and
				-- the inner strand (o.core, widths o.inner_w) recoloured from the white bladecore into the opaque body
				O = { side = side, scroll = def.scroll, tail = 0.45, maxSpans = def.spans, tag = "blades",
					color = T.BladeColor, le = T.BladeLE, e0 = T.BladeE0, e1 = T.BladeE1, inner_w = widI,
					core = { color = T.BladeHotColor, le = T.BladeBodyLE, e0 = T.BladeBodyE0, e1 = T.BladeBodyE1,
						alpha = 1.0 } },
			})
		end
	end
	local nBody = T.BodyRows * T.BodyCols
	look.BodyP = table.create(nBody, Vector3.zero)
	look.BodyO = { closed = true, e0 = T.BodyE0, e1 = T.BodyE1, a0 = T.BodyA0, maxSpans = T.BodySpans, tag = "body" }
	look.GlareP = table.create(T.GlarePts, Vector3.zero)
	look.GlareO = {}
	for i = 1, 3 do look.GlareO[i] = { tail = 0.3, maxSpans = 3, tag = "glare" } end
	look.Flares = {}
	for i = 1, T.Flares do
		local pts, wid = newArrays(T.FlarePts)
		look.Flares[i] = { Pts = pts, Wid = wid, O = { tail = 0.6, maxSpans = 3, tag = "top" } }
	end
	look.StreakP = {}
	look.StreakO = { core = { tail = 0.5, maxSpans = 1, tag = "top" }, glow = { tail = 0.5, maxSpans = 1, tag = "top" } }
	for i = 1, T.Streaks do look.StreakP[i] = { Vector3.zero, Vector3.zero } end
	look.Disc = {}
	for i = 1, T.DiscArms do
		local pts, wid, side = newArrays(T.DiscPts)
		look.Disc[i] = { Pts = pts, Wid = wid, Side = side, O = { side = side, tail = 0.5, maxSpans = 3, tag = "floor" } }
	end
	look.Scuffs = {}
	for i = 1, T.ScuffArms do
		local pts, _, side = newArrays(T.ScuffPts)
		look.Scuffs[i] = { Pts = pts, Side = side, O = { side = side, tail = 0.4, maxSpans = 2, tag = "floor" } }
	end
	look.Streamers = {}
	for i = 1, T.Streamers do
		local pts, wid = newArrays(T.StreamerPts)
		look.Streamers[i] = { Pts = pts, Wid = wid, O = { tail = 0.7, maxSpans = 2, tag = "top" } }
	end
	look.PillarP = {}
	for i = 1, T.PillarLines do look.PillarP[i] = { Vector3.zero, Vector3.zero } end
	look.PillarO = { tail = 0.4, maxSpans = 1, tag = "pillar" }
	look.RingO = { maxSpans = T.RingSpans, tag = "rings" }
	look.HandP = { glow = table.create(T.HandPts, Vector3.zero), core = table.create(T.HandPts, Vector3.zero) }
	look.HandW = { glow = table.create(T.HandPts, 0), core = table.create(T.HandPts, 0) }
	look.HandO = { glow = { tail = 0.6, maxSpans = 3, tag = "arms" }, core = { tail = 0.5, maxSpans = 3, tag = "arms" } }
	return look
end

--- Blender stage (x right, y forward, z up, studs from the funnel's foot) -> the world, at the look's Scale.
local function W(look, x, y, z)
	local c, s = look.Center, T.Scale
	return Vector3.new(c.X + x * s, c.Y + z * s, c.Z - y * s)
end

local function nearFade(dmin)
	return clamp((dmin - T.NearIn) / T.NearOver, T.NearFloor, 1)
end

----------------------------------------------------------------------------------------------------
-- PARTICLES (cv:Burst: za.burst as ParticleEmitter:Emit; guarded -- a missing kind never ends the funnel)
----------------------------------------------------------------------------------------------------
local function sizeRange(kind, a, b)
	if T.BurstSizeIsMultiplier then return { a, b } end
	local base = (T.KindBase[kind] or 1) * T.Scale
	return { a * base, b * base }
end

local function burst(cv, kind, pos, n, o)
	if n <= 0 or type(cv.Burst) ~= "function" then return end
	local ok, err = pcall(cv.Burst, cv, kind, pos, n, o)
	if not ok then warnOnce("burst" .. kind, "cv:Burst(" .. kind .. ") failed: " .. tostring(err)) end
end

--- A burst's count: the Blender's. ZephyrDraw multiplies it by the effect density itself (Graphics Quality, Reduce Enemy
--- VFX for somebody else's -- Play's opts.Own), so it is not thinned twice here.
local function count(_look, n)
	return n
end

--- Round the axis, counter-clockwise from above, at Blender angle a (radial (cos a, sin a) -> world (cos a, 0, -sin a)).
local function tangentAt(a)
	return Vector3.new(-sin(a), 0, -cos(a))
end

--- One debris event (cyclone_v6, every DebrisEvery Blender s): a rock and a pale spark thrown up through the base, and
--- half the time a puff of the dust billow round it.
local function debrisEvent(look, cv, i)
	local rng = Random.new(look.Seed + i * 131)
	local S = T.Scale
	local a = rng:NextNumber(0, TAU)
	local ca, sa = cos(a), sin(a)
	local keep = clamp01(look.Density)
	if rng:NextNumber() < keep then
		-- the rock: from 3 studs out, thrown out (3) and up (10..18), carried round by the swirl
		local v = Vector3.new(3 * ca, rng:NextNumber(10, 18), -3 * sa) + tangentAt(a) * T.SwirlKick
		local speed = v.Magnitude * S
		-- 2026-10-08: its life (0.8 .. 1.4) and size (1.0 .. 2.0) go to the emitter as RANGES, which draws each rock's from
		-- them. Passed as this rock's own exact pair, every rock, spark, billow and ring puff was a look of its own to
		-- ZephyrDraw (an emitter per kind, size and life): ~250 asked for a cast against MaxEmitters, so all but the first
		-- few were dropped, with a warning every cast. The two draws stay, so whatever is seeded after them keeps its value
		rng:NextNumber(0.8, 1.4); rng:NextNumber(1.0, 2.0)
		burst(cv, "chip", W(look, 3 * ca, 3 * sa, 0.3), 1, {
			dir = v.Unit, cone = 0.05, up = 0, speed = { speed, speed }, life = { 0.8, 1.4 },
			size = sizeRange("chip", 1.0, 2.0), id = "rock" .. i,
		})
	end
	if rng:NextNumber() < keep then
		-- the pale spark: from the same spot, 0..3 up, rising 8..16
		local up = rng:NextNumber(8, 16) * S
		rng:NextNumber(0.3, 0.6); rng:NextNumber(0.4, 0.8)             -- (as the rock's: ranges, the draws kept)
		burst(cv, "spark", W(look, 3 * ca, 3 * sa, 0.3 + rng:NextNumber(0, 3)), 1, {
			dir = UP, cone = 0.04, up = 0, speed = { up, up }, life = { 0.3, 0.6 }, size = sizeRange("spark", 0.4, 0.8),
			id = "psp" .. i,
		})
	end
	if rng:NextNumber() < T.BillowShare * keep then
		-- the billow: a slow puff 9..15 studs out on the floor, drifting up (0.4), round and in
		local r = rng:NextNumber(9, 15)
		local v = Vector3.new(0, 0.4, 0) + tangentAt(a) * T.BillowSwirl - Vector3.new(ca, 0, -sa) * T.BillowInflow
		rng:NextNumber(1.4, 2.2); rng:NextNumber(1.6, 2.8)             -- (as the rock's: ranges, the draws kept)
		local speed = v.Magnitude * S
		burst(cv, "dust", W(look, r * ca, r * sa, 0.3), 1, {
			dir = v.Unit, cone = 0.1, up = 0, speed = { speed, speed }, life = { 1.4, 2.2 },
			size = sizeRange("dust", 1.6, 2.8), id = "billow" .. i,
		})
	end
end

--- Fires the events whose index the clock has passed since last frame, at most MaxCatchUp of them.
local function catchUp(look, key, cur, fire)
	local last = look.Ev[key]
	if cur <= last then return end
	look.Ev[key] = cur
	for i = max(last + 1, cur - T.MaxCatchUp + 1), cur do fire(i) end
end

--- The touchdown (cyclone_v4: T_CL1): the wide dust ring, chips thrown up spiralling, sparks.
local function touchdownBursts(look, cv)
	local foot, S = W(look, 0, 0, 0.3), T.Scale
	burst(cv, "dust", foot, count(look, 40), { speed = { 12 * S, 24 * S }, life = { 1.0, 1.8 }, up = 0.02,
		size = sizeRange("dust", 1.2, 2.2), id = "tdDust" })
	burst(cv, "chip", foot, count(look, 20), { speed = { 8 * S, 16 * S }, life = { 1.2, 2.0 }, up = 0.8,
		size = sizeRange("chip", 0.6, 1.4), id = "tdChip" })
	burst(cv, "spark", W(look, 0, 0, 2.0), count(look, 20), { speed = { 6 * S, 16 * S }, life = { 0.4, 0.9 },
		size = sizeRange("spark", 0.6, 1.4), id = "tdSpark" })
end

--- A juggled body's sparks (cyclone_v5: 12 at the struck dummy, 5..13 studs/s, 0.25..0.6 s).
local function hitSparks(look, cv, at, key)
	local S = T.Scale
	burst(cv, "spark", at + Vector3.new(0, T.HitSparkLift, 0), count(look, 12), { speed = { 5 * S, 13 * S },
		life = { 0.25, 0.6 }, size = sizeRange("spark", 0.6, 1.4), id = key })
end

----------------------------------------------------------------------------------------------------
-- THE JUGGLE (live: refreshed AIRBORNE tags inside the catch cylinder; see the header)
----------------------------------------------------------------------------------------------------
local dummyList, dummyAt = {}, -math.huge

local function dummies()
	local now = os.clock()
	if now - dummyAt < T.DummyRescan then return dummyList end
	dummyAt = now
	table.clear(dummyList)
	local ground = workspace:FindFirstChild("TrainingGround")
	if ground then
		for _, d in ipairs(ground:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("TrainingDummy") then table.insert(dummyList, d) end
		end
	end
	return dummyList
end

local function statusExpires(model)
	local v = model:GetAttribute("StatusExpires")
	return type(v) == "number" and v or 0
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

--- Inside the catch cylinder (ZephyrHandler's: Radius + HoldSlack round the axis, Below under the spot, Height over it,
--- plus CatchSlack for the bob).
local function inCylinder(look, p, C)
	local c = look.Center
	local dx, dz = p.X - c.X, p.Z - c.Z
	local dy = p.Y - c.Y
	return dx * dx + dz * dz <= (C.Radius + C.HoldSlack) ^ 2 and dy >= -C.Below and dy <= C.Height + T.CatchSlack
end

local function scanBodies(look)
	local fresh = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and c ~= look.Character then fresh[c] = look.Bodies[c] or statusExpires(c) end
	end
	for _, d in ipairs(dummies()) do
		if d.Parent and d ~= look.Character then fresh[d] = look.Bodies[d] or statusExpires(d) end
	end
	look.Bodies = fresh
end

--- A tick landed: one pulse per tick (PulseGap), sparks on the body.
local function juggleHit(look, cv, now, at)
	look.HitCount = (look.HitCount or 0) + 1
	if at then hitSparks(look, cv, at, "hit" .. look.HitCount) end
	if now - look.LastPulse >= T.PulseGap then
		look.LastPulse = now
		table.insert(look.Pulses, now)
		if #look.Pulses > T.MaxPulses then table.remove(look.Pulses, 1) end
	end
end

local function watchJuggle(look, cv, now, C)
	if now >= look.NextScan then
		look.NextScan = now + T.ScanEvery
		scanBodies(look)
	end
	for model, last in pairs(look.Bodies) do
		local e = statusExpires(model)
		if e ~= last then
			look.Bodies[model] = e
			if e > last + 0.05 and model:GetAttribute("Status") == "Airborne" then
				local root = rootOf(model)
				if root and inCylinder(look, root.Position, C) then juggleHit(look, cv, now, root.Position) end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE DEMO'S STAND-INS (spring/cyclone_bl.py DummySim, ported: two training dummies pulled in leaning into the pull,
-- caught, orbiting the axis bobbing and tumbling, thrown out at the release, landing in a crouch) and its juggle
----------------------------------------------------------------------------------------------------
local EYE, PGAIN, PSPEED, ORBIT = 4.6, 2.5, 18.0, 14.0   -- DummySim's orbit radius, pull gain / cap, orbit speed
local JH, JB, JP, LIFT_T = 8.0, 2.2, 1.1, 0.6            -- the juggle height, bob, bob period, lift time
local GRAV = 9.81 * 5.25 / 1.8                            -- zk.G: real gravity in studs/s^2
local SIM_T0, SIM_DT = -0.5, 1 / 120

--- DummySim.simulate: the hip centre's path (funnel frame: Blender x / y from the foot, z up; hip at 2 standing).
local function simDummy(def, sx, sy)
	local cx, cy, cz, vx, vy, vz = sx, sy, 2.0, 0, 0, 0
	local phase, held = 0, 0
	local rec = { P = {}, Ph = {}, Held = {}, TLand = math.huge }
	local n = floor((T.ReleaseTo + 1.4 - SIM_T0) / SIM_DT) + 1
	for i = 1, n do
		local t = SIM_T0 + (i - 1) * SIM_DT
		rec.P[i], rec.Ph[i], rec.Held[i] = Vector3.new(cx, cy, cz), phase, held
		local S = strength(t)
		if phase == 0 then
			if t >= def.catch then
				phase, held = 1, 0
			else                                                 -- dragged in and round, harder as the funnel grows
				local d = max(sqrt(cx * cx + cy * cy), 1e-3)
				local ox, oy = cx / d, cy / d
				local k = clamp01((S - 0.30) / 0.6) ^ 2
				local a = min(1, 6 * SIM_DT)
				vx += ((-ox * 2.6 - oy * 1.2) * k - vx) * a
				vy += ((-oy * 2.6 + ox * 1.2) * k - vy) * a
				vz = 0
			end
		end
		if phase == 1 then
			if t >= T.T_REL then                                 -- the release: flung out and up
				phase = 2
				local d = max(sqrt(cx * cx + cy * cy), 1e-6)
				local hs = sqrt(vx * vx + vy * vy)
				if hs > 6 then vx, vy = vx * 6 / hs, vy * 6 / hs end
				vx += cx / d * 2.5
				vy += cy / d * 2.5
				vz = max(vz, 0) + 4
			else                                                 -- held: in to EYE, round, lifted to the juggle height
				held += SIM_DT
				local ax, ay = axisXY(min(cz, hNow(t)), t, min(1, grow(t)))
				local rx, ry = cx - ax, cy - ay
				local d = max(sqrt(rx * rx + ry * ry), 1e-3)
				local ox, oy = rx / d, ry / d
				local inw = clamp((d - EYE) * PGAIN, -PSPEED, PSPEED)
				local orb = ORBIT * clamp01(d / EYE)
				local lf = clamp01(held / LIFT_T)
				local hgt = JH * lf + JB * lf * sin((held + def.seed) * TAU / JP)
				local sc = min(1, S * 1.2)
				local a = min(1, 7 * SIM_DT)
				vx += ((-ox * inw - oy * orb) * sc - vx) * a
				vy += ((-oy * inw + ox * orb) * sc - vy) * a
				vz += (clamp((hgt + 2 - cz) * 4, -20, 30) * sc - vz) * a
			end
		end
		if phase == 2 then
			vz -= GRAV * SIM_DT
			if cz + vz * SIM_DT <= 2 and vz < 0 then
				phase, rec.TLand, vz = 3, t, 0
			end
		end
		if phase == 3 then
			local sp = sqrt(vx * vx + vy * vy)
			if sp > 0 then
				local k = max(0, sp - 30 * SIM_DT) / sp
				vx, vy = vx * k, vy * k
			end
		end
		cx, cy, cz = cx + vx * SIM_DT, cy + vy * SIM_DT, cz + vz * SIM_DT
		if phase == 3 then cz = 2 end
	end
	return rec
end

local LIMBS = {
	{ "Torso", Vector3.new(2, 2, 1) }, { "Head", Vector3.new(1.25, 1.25, 1.25) },
	{ "RA", Vector3.new(1, 2, 1) }, { "LA", Vector3.new(1, 2, 1) }, { "RL", Vector3.new(1, 2, 1) }, { "LL", Vector3.new(1, 2, 1) },
}

local function demoFolder()
	local f = workspace:FindFirstChild("ZephyrCycloneDemo")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ZephyrCycloneDemo"
		f.Parent = workspace
	end
	return f
end

--- The two stand-ins (the demo's own anchored, non-colliding, non-querying parts: they go with the demo).
local function buildStandIns(look, fwd)
	local right = fwd:Cross(UP)
	look.StandIns = {}
	for i, def in ipairs(T.DemoDummies) do
		local off = right * def.x + fwd * def.y
		local m = Instance.new("Model")
		m.Name = "CycloneDemoDummy" .. i
		local parts = {}
		for _, spec in ipairs(LIMBS) do
			local p = Instance.new("Part")
			p.Name, p.Size, p.Color = spec[1], spec[2], T.DummyColor
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Parent = m
			parts[spec[1]] = p
		end
		m.Parent = demoFolder()
		look.StandIns[i] = { Def = def, Model = m, Parts = parts, Sim = simDummy(def, off.X, -off.Z) }
	end
end

local function destroyStandIns(look)
	for _, d in ipairs(look.StandIns or {}) do
		if d.Model then d.Model:Destroy() end
	end
	look.StandIns = nil
end

--- A rotation turning a limb's hang (-Y) onto `dir` (body space).
local function hang(dir)
	local a = Vector3.new(0, -1, 0)
	local c = a:Cross(dir)
	local s, d = c.Magnitude, a:Dot(dir)
	if s < 1e-5 then return d > 0 and CFrame.identity or CFrame.Angles(pi, 0, 0) end
	return CFrame.fromAxisAngle(c / s, math.atan2(s, d))
end

--- DummySim._raw, simplified to a rigid R6 figure: the hip frame (lean / tumble / crouch) and the limbs' directions
--- (body space: x right, y up, -z forward).
local function poseStandIn(look, d, t)
	local sim = d.Sim
	local x = clamp((t - SIM_T0) / SIM_DT + 1, 1, #sim.P - 1)
	local i = floor(x)
	local c = sim.P[i]:Lerp(sim.P[i + 1], x - i)
	local ph, held, sd, ti = sim.Ph[i], sim.Held[i], d.Def.seed, d.Def.tumble
	local hip = W(look, c.X, c.Y, c.Z)
	local toF = Vector3.new(look.Center.X - hip.X, 0, look.Center.Z - hip.Z)
	toF = toF.Magnitude > 1e-3 and toF.Unit or Vector3.new(0, 0, -1)
	local orb = math.atan2(c.Y, c.X)
	local fwd, up, drop = toF, UP, 0
	local armR, armL, legR, legL
	if ph == 0 then
		-- leaning into the pull, bracing, facing the caster
		local k = clamp01((strength(t) - 0.12) / 0.7)
		local toC = Vector3.new(look.CasterPos.X - hip.X, 0, look.CasterPos.Z - hip.Z)
		fwd = toC.Magnitude > 1e-3 and toC.Unit or toF
		local lean = 0.38 * k + 0.05 * k * sin(t * 9 + sd)
		up = UP * cos(lean) + toF * sin(lean)
		local ra = math.rad(lerp(8, 100, k))
		armR = Vector3.new(0.15, -cos(ra), -sin(ra)).Unit
		armL = Vector3.new(-0.15, -cos(ra * 0.9), -sin(ra * 0.9)).Unit
		legR, legL = Vector3.new(0.08, -1, 0.1 * k).Unit, Vector3.new(-0.08, -1, 0.1 * k).Unit
		drop = 0.15 * k
	elseif ph == 1 or ph == 2 then
		-- caught: orbiting, tumbling, arms up in a waving V, legs kicking; thrown: righting itself as it falls
		local a, upright = held, 1
		if ph == 2 then a, upright = held + (t - T.T_REL), sm(t, T.T_REL + 0.10, T.T_REL + 0.55) end
		local keep = ph == 2 and (1 - upright) or clamp01(held / 0.45)
		local pitch = (ti[1] * a + 0.45 * sin(2.1 * a + sd)) * keep
		local roll = (ti[2] * a + 0.35 * sin(1.7 * a + 2 * sd)) * keep
		local yaw = orb + pi * 0.5 + ti[3] * a                  -- Blender yaw: the rig faces (-sin yaw, cos yaw)
		local base = CFrame.lookAt(Vector3.zero, Vector3.new(-sin(yaw), 0, -cos(yaw))) * CFrame.Angles(pitch, 0, roll)
		fwd, up = base.LookVector, base.UpVector
		local fl = ph == 1 and 1 or 1 - upright * 0.8
		local function armDir(sg)
			local v = Vector3.new(sg * (0.95 + 0.25 * sin(4.3 * a + sg)), 1.45 + 0.35 * sin(3.7 * a + 2 * sg) * fl,
				-0.35 * sin(5.1 * a + sg + sd)).Unit
			if ph == 2 then v = v:Lerp(Vector3.new(sg * 1.1, 0.6, -0.6).Unit, upright).Unit end
			return v
		end
		armR, armL = armDir(1), armDir(-1)
		legR = Vector3.new(0.22, -1.75, -0.5 * sin(3.3 * a + 1.4 + sd) * fl).Unit
		legL = Vector3.new(-0.22, -1.75, -0.5 * sin(3.3 * a - 1.4 + sd) * fl).Unit
	else
		-- landed: absorbs in a crouch, then recovers with a stagger
		local u = t - sim.TLand
		local absorb = sm(u, 0, 0.10) * (1 - sm(u, 0.25, 0.95))
		local yaw = orb + pi * 0.5 + ti[3] * (held + (sim.TLand - T.T_REL))
		local sway = 0.08 * sin(u * 7 + sd) * exp(-u * 1.5)
		local base = CFrame.lookAt(Vector3.zero, Vector3.new(-sin(yaw), 0, -cos(yaw)))
			* CFrame.Angles(-(0.35 * absorb + 0.06), 0, sway)
		fwd, up = base.LookVector, base.UpVector
		armR = Vector3.new(0.45, -0.75, -0.5 - 0.5 * absorb).Unit
		armL = Vector3.new(-0.45, -0.75, -0.5 - 0.5 * absorb).Unit
		legR, legL = Vector3.new(0.3, -1, -0.35 * absorb).Unit, Vector3.new(-0.3, -1, 0.1).Unit
		drop = 0.62 * absorb
	end
	-- the hip frame (right = fwd x up), the torso over it, the limbs hung from their joints
	local rightV = fwd:Cross(up)
	rightV = rightV.Magnitude > 1e-4 and rightV.Unit or Vector3.new(1, 0, 0)
	local torso = CFrame.fromMatrix(hip - Vector3.new(0, drop, 0), rightV, up.Unit) * CFrame.new(0, 1, 0)
	local p = d.Parts
	p.Torso.CFrame = torso
	p.Head.CFrame = torso * CFrame.new(0, 1.65, 0)
	p.RA.CFrame = torso * CFrame.new(1.5, 0.5, 0) * hang(armR) * CFrame.new(0, -0.5, 0)
	p.LA.CFrame = torso * CFrame.new(-1.5, 0.5, 0) * hang(armL) * CFrame.new(0, -0.5, 0)
	p.RL.CFrame = torso * CFrame.new(0.5, -1, 0) * hang(legR) * CFrame.new(0, -1, 0)
	p.LL.CFrame = torso * CFrame.new(-0.5, -1, 0) * hang(legL) * CFrame.new(0, -1, 0)
	d.Hip = hip
end

--- The demo's juggle (cyclone_v5 HITS): a ring pulse up the funnel and sparks on the struck stand-in, alternating.
local function demoTicks(look, cv, now)
	table.clear(look.Pulses)
	local cur = -1
	for k, th in ipairs(T.DemoHits) do
		if now >= th then
			cur = k
			table.insert(look.Pulses, th)
		end
	end
	catchUp(look, "demoTick", cur, function(k)
		local th = T.DemoHits[k]
		if not th or now - th > T.PulseTime then return end
		local d = look.StandIns and look.StandIns[(k - 1) % 2 + 1]
		-- the Blender's sparks pop at the struck rig's root + 2.6 (hip + 0.6); hitSparks lifts by HitSparkLift
		if d and d.Hip then hitSparks(look, cv, d.Hip + Vector3.new(0, 0.6 - T.HitSparkLift, 0), "demoHit" .. k) end
	end)
end

--- The caster's body (CastPose) and, for your own character, the viewmodel arms play the move's clips on the demo's
--- clock: CycloneForm (keyed on the live 1.2 s form: / DemoFormRate puts its keys on the Blender's beats; its loop is
--- the channel's slow circle) until DemoReleaseClip, then CycloneRelease (the draw-back, the thrust on T_THR + 0.12).
local CastPoseMod = nil
local function castPose()
	if CastPoseMod == nil then
		CastPoseMod = false
		local folder = iceFolder()
		local m = folder and folder:FindFirstChild("CastPose")
		local ok, mod = pcall(function() return m and require(m) end)
		if ok and type(mod) == "table" then CastPoseMod = mod end
	end
	return CastPoseMod or nil
end

local function demoClock(look, name, clip)
	if name == "CycloneRelease" then
		return function() return (look.DemoT or 0) - T.DemoReleaseClip end
	end
	local from, len = clip and clip.LoopFrom, clip and clip.LoopLength
	return function()
		local u = (look.DemoT or 0) / T.DemoFormRate
		if from and len and len > 0 and u >= from then u = from + (u - from) % len end
		return u
	end
end

local function demoClips(look)
	local want = (look.DemoT or 0) < T.DemoReleaseClip and "CycloneForm" or "CycloneRelease"
	if look.ClipNow == want then return end
	look.ClipNow = want
	local cp = castPose()
	if cp and cp.Clips and cp.Clips[want] and type(cp.PlayClocked) == "function" then
		local ok, err = pcall(cp.PlayClocked, look.Character, want, demoClock(look, want, cp.Clips[want]))
		if not ok then warnOnce("castpose", "CastPose." .. want .. " failed: " .. tostring(err)) end
	end
	local vm = look.Character == localCharacter() and viewmodel()
	if vm and vm.Clips and vm.Clips[want] and type(vm.Play) == "function" then
		pcall(vm.Play, want, demoClock(look, want, vm.Clips[want]))
	end
end

--- The demo's clips let go (only while they are still the ones playing).
local function stopDemoClips(look)
	if not look.ClipNow then return end
	look.ClipNow = nil
	local cp = castPose()
	if cp and type(cp.CurrentClip) == "function" and type(cp.Stop) == "function" then
		local ok, cur = pcall(cp.CurrentClip, look.Character)
		if ok and (cur == "CycloneForm" or cur == "CycloneRelease") then pcall(cp.Stop, look.Character) end
	end
	local vm = look.Character == localCharacter() and viewmodel()
	if vm and type(vm.CurrentClip) == "function" and type(vm.Stop) == "function" then
		local ok, cur = pcall(vm.CurrentClip)
		if ok and (cur == "CycloneForm" or cur == "CycloneRelease") then pcall(vm.Stop) end
	end
end

----------------------------------------------------------------------------------------------------
-- THE ARMS' WIND (cyclone_v4.hands: a path ribbon behind each hand; yours ride the viewmodel fists)
----------------------------------------------------------------------------------------------------
--- The hand's world position this frame and the frame its history is kept in: the CAMERA for your viewmodel fist (so a
--- turn of the view never smears the trail), the ROOT for a body's hand (so a walk does not either).
local function handNow(look, side)
	local character = look.Character
	local zd, fp = engine(), true
	if zd and type(zd.FirstPerson) == "function" then
		local ok, v = pcall(zd.FirstPerson)
		if ok then fp = v == true end
	end
	if character == localCharacter() and fp then           -- (a third-person view: the body's hands, as everyone sees)
		local vm = viewmodel()
		if vm and type(vm.GetFistCFrame) == "function" then
			local ok, cf = pcall(vm.GetFistCFrame, side)
			local cam = workspace.CurrentCamera
			if ok and cf and cam then return cf.Position, cam.CFrame, true end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local hand = character:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
	if hand then return hand.Position, root.CFrame, false end
	local arm = character:FindFirstChild(side == "L" and "Left Arm" or "Right Arm")
	if arm then return (arm.CFrame * CFrame.new(0, -arm.Size.Y * 0.5, 0)).Position, root.CFrame, false end
	return nil
end

--- The kept position at time t (linear between samples, the oldest before them).
local function historyAt(hist, t)
	local n = #hist
	if n == 0 then return nil end
	if t <= hist[1].T then return hist[1].P end
	for i = n, 2, -1 do
		local a = hist[i - 1]
		if t >= a.T then
			local b = hist[i]
			local u = (b.T > a.T) and (t - a.T) / (b.T - a.T) or 1
			return a.P:Lerp(b.P, clamp01(u))
		end
	end
	return hist[n].P
end

local function drawHand(look, cv, side, now, w)
	local p, frameCF, own = handNow(look, side)
	local hist = look.Hands[side]
	if not p then
		table.clear(hist)
		return
	end
	if hist.Own ~= own then
		table.clear(hist)
		hist.Own = own
	end
	table.insert(hist, { T = now, P = frameCF:PointToObjectSpace(p) })
	while #hist > 2 and now - hist[1].T > T.HandKeep do table.remove(hist, 1) end
	if w <= 0.01 or #hist < 3 or now - hist[1].T < 0.05 then return end
	local wk = (own and T.OwnHandScale or 1) * T.Scale
	for _, kind in ipairs({ "glow", "core" }) do
		local dur = kind == "glow" and T.HandSpan or T.HandCoreSpan
		local wr = kind == "glow" and T.HandGlowW or T.HandCoreW
		local pts, wid, n = look.HandP[kind], look.HandW[kind], T.HandPts
		local length = 0
		for k = 1, n do
			local s = (k - 1) / (n - 1)
			pts[k] = frameCF:PointToWorldSpace(historyAt(hist, now - dur * s))
			-- za.path_ribbon: w_head -> w_tail, x sin(pi clip(0.02 .. 0.98))^0.35
			wid[k] = lerp(wr[1], wr[2], s) * sin(pi * lerp(0.02, 0.98, s)) ^ 0.35 * wk
			if k > 1 then length += (pts[k] - pts[k - 1]).Magnitude end
		end
		if length > 0.05 then
			local o = look.HandO[kind]
			-- glow: alpha 0.6; core: the Ribbon's default 0.5 (za's own opacity)
			o.fade, o.glow, o.alpha = w, 1.0, (kind == "glow" and 0.6 or 0.5) * T.AlphaFromBlender
			cv:Ribbon(pts, wid, kind, o)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE FRAME (cyclone_v6.funnel over v5's layers; every coefficient is the Blender's)
----------------------------------------------------------------------------------------------------
local F = {}                   -- this frame's scalars (one Cyclone is drawn at a time: reused)

local function radiusAt(z)
	return radiusShape(clamp(z / max(F.H, 1), 0, 1.2)) * F.sc * F.pk * T.LookRadius
end

local function axisAt(z)
	return axisXY(z, F.Fl, F.gk)
end

local function drawFunnel(look, cv, camPos)
	local AK, S = T.AlphaFromBlender, T.Scale
	local H, f, pf, su, Ph, Fl, lo = F.H, F.f, F.pf, F.su, F.Ph, F.Fl, F.lo
	local live = F.live

	-- THE BLADES (cyclone_v6): thick flat ribbons, width mostly vertical, tilted toward the radial
	if live then
		local pk1, pk2, pk3 = 1 - 0.9 * pf, 1 - 0.85 * pf, 1 - 0.6 * pf
		local Hm = max(H, 1)
		for _, b in ipairs(look.Blades) do
			local d = b.D
			local born = sm(F.g, d.zh * 0.85 - 0.15, d.zh * 0.85)
			if born > 0.01 then
				local pts, wid, side, n = b.Pts, b.Wid, b.Side, T.BladePts
				local widI, bodyK = b.WidI, T.BladeBodyShare
				local dmin = math.huge
				for k = 1, n do
					local s = (k - 1) / (n - 1)
					local zz = H * clamp(d.zh - d.pitch * s * pk1 - 0.02, 0, 1.15)
					local ang = d.a0 + Ph * d.sp - d.sweep * s * pk2
					local r = radiusAt(zz) * d.rk
					if d.Flung then r *= 1 + 0.6 * (1 - s) end
					local ox, oy = axisAt(zz)
					local ca, sa = cos(ang), sin(ang)
					local p = W(look, ox + r * ca, oy + r * sa, zz + 0.1)
					pts[k] = p
					side[k] = Vector3.new(ca * d.st, d.ct, -sa * d.st)
					wid[k] = d.wd * (0.55 + 0.45 * zz / Hm) * pk3 * BLADE_PROFILE[k] * S * T.BladeWidth
					widI[k] = wid[k] * bodyK                       -- the opaque body strand (o.inner_w)
					local dd = (p - camPos).Magnitude
					if dd < dmin then dmin = dd end
				end
				local o = b.O
				o.fade = f * born * nearFade(dmin)
				o.alpha = d.al * AK
				o.glow = 1 + 0.6 * su
				o.t = Fl + d.a0                                    -- the kit's t = t + a0: each streaks on its own phase
				cv:Ribbon(pts, wid, "blade", o)
			end
		end
	end

	-- THE CORE BODY (v5's inner shell, v6's dim vapor): rows up the height, columns round it
	if live then
		local P, nu, nv = look.BodyP, T.BodyRows, T.BodyCols
		for i = 1, nu do
			local s = (i - 1) / (nu - 1)
			local zz = H * s
			local r = radiusAt(zz) * 0.55 * (1 + 0.25 * lo) * (1 + 0.05 * sin(zz * 0.3))
			local ox, oy = axisAt(zz)
			for j = 1, nv do                                       -- (the "shell" kind fades its own foot and rim)
				local a = TAU * (j - 1) / nv + Ph * 1.10 - zz * 0.04
				P[(i - 1) * nv + j] = W(look, ox + r * cos(a), oy + r * sin(a), zz + 0.05)
			end
		end
		local o = look.BodyO
		o.fade, o.alpha, o.glow, o.t = f * (1 - 0.7 * pf), T.BodyAlpha * AK, T.BodyGlow, Fl * 1.6   -- t x (0.5 + sp)
		cv:Sheet(P, nu, nv, "shell", o)
	end

	-- THE GLARE: a white-hot thread up the axis inside two sleeves (v5 widths, v6 x1.9 / x1.5 glow)
	if live then
		local gp, n = look.GlareP, T.GlarePts
		local dmin = math.huge
		for k = 1, n do
			local z = lerp(H * 0.98, 0.3, (k - 1) / (n - 1))
			local ox, oy = axisAt(z)
			gp[k] = W(look, ox, oy, z)
			local dd = (gp[k] - camPos).Magnitude
			if dd < dmin then dmin = dd end
		end
		local near = nearFade(dmin)
		-- the white thread's ZOffset: in front of the near wall of blades (the funnel's mid radius), never within
		-- GlareZGap of your camera (Tuning.GlareZGap)
		look.GlareO[1].z = floor(clamp(min(radiusAt(H * 0.5), dmin - T.GlareZGap), 0, 30) * 4) / 4   -- (0.25 steps: few writes)
		local WD, FD, AL, GL = { 0.35, 1.6, 3.4 }, { 1.0, 0.7, 0.4 }, { 1.0, 0.55, 0.3 }, { 1.3 * 1.9, 1.1 * 1.5, 0.8 * 1.5 }
		for i = 1, 3 do
			local o = look.GlareO[i]
			o.fade, o.alpha, o.glow, o.t = f * FD[i] * near, AL[i] * AK, GL[i] * (1 + 0.6 * su), Fl + i
			cv:Ribbon(gp, WD[i] * (1 + 0.3 * pf) * S, i == 1 and "core" or "glow", o)
		end
	end

	-- THE TOP: flares swinging out past the column (head = the thin outer tip) ...
	if live and pf <= 0.5 then
		local RH = radiusAt(H)
		local cx, cy = axisAt(H)
		for i, fl in ipairs(look.Flares) do
			local d = flareDefs[i]
			local pts, wid, n = fl.Pts, fl.Wid, T.FlarePts
			for k = 1, n do
				local s = 1 - (k - 1) / (n - 1)          -- P[::-1]: the ribbon runs from s = 1 (head) to s = 0
				local zz = H * (0.72 + 0.32 * s)
				local ang = d.a0 + Ph * 0.8 - 2.0 * s
				local r = RH * d.rk * (0.85 + 0.6 * s)
				pts[k] = W(look, cx + r * cos(ang), cy + r * sin(ang), zz)
				wid[k] = (2.2 * (1 - s) + 0.2) * S
			end
			local o = fl.O
			o.fade, o.alpha, o.glow = f * 0.75, 0.5 * AK, 1.0
			cv:Ribbon(pts, wid, "glow", o)
		end
		-- ... and streaks shooting up diagonally off the top, cycling outward 1.6 times a second
		local z8 = H * 0.8
		local R8 = radiusAt(z8) * 0.7
		local ax8, ay8 = axisAt(z8)
		for i, d in ipairs(streakDefs) do
			local u = (Fl * 1.6 + d.ph) % 1.0
			local a = d.a0 + Ph * 0.5
			local ca, sa = cos(a), sin(a)
			local ox, oy = ax8 + R8 * ca, ay8 + R8 * sa
			local rise = T.StreakRise
			local k = 1 / sqrt(1 + rise * rise)
			local dx, dy, dz = ca * k, sa * k, rise * k
			local hd, tl = T.StreakLen + 14 * u, 14 * u
			local pts = look.StreakP[i]
			pts[1] = W(look, ox + dx * hd, oy + dy * hd, z8 + dz * hd)
			pts[2] = W(look, ox + dx * tl, oy + dy * tl, z8 + dz * tl)
			local fu = sin(pi * u) * f
			local oc, og = look.StreakO.core, look.StreakO.glow
			oc.fade, oc.glow, oc.alpha = fu, 1.2, 0.5 * AK          -- the core keeps the Ribbon's default alpha
			og.fade, og.alpha, og.glow = fu * 0.7, 0.5 * AK, 1.0
			oc.z, og.z = T.StreakZ, T.StreakZ
			cv:Ribbon(pts, T.StreakCoreW * S, "core", oc)
			cv:Ribbon(pts, T.StreakGlowW * S, "glow", og)
		end
	end

	-- THE BASE DISC: six flat glow arms spiralling out 4 -> 13 studs, turning with the funnel
	if live then
		local reach = (0.6 + 0.4 * min(1, H / T.HF)) * (1 - 0.5 * pf)
		for i, arm in ipairs(look.Disc) do
			local a0 = (i - 1) * 1.047
			local pts, wid, side, n = arm.Pts, arm.Wid, arm.Side, T.DiscPts
			for k = 1, n do
				local s = (k - 1) / (n - 1)
				local ang = a0 + Ph * 0.9 - 2.2 * s
				local rr = lerp(4.0, 13.0, s) * reach
				local ca, sa = cos(ang), sin(ang)
				pts[k] = W(look, rr * ca, rr * sa, 0.25)
				side[k] = Vector3.new(ca, 0, -sa)                -- flat on the floor: the width runs radially
				wid[k] = lerp(1.8, 0.6, s) * S
			end
			local o = arm.O
			o.fade, o.alpha, o.glow, o.le = f * 0.7, T.DiscAlpha * AK, T.DiscGlow, T.DiscLE
			cv:Ribbon(pts, wid, "glow", o)
		end
	end

	-- THE GROUND RING: 3 -> 18 studs while the funnel rises (Blender 0.3 .. 1.4)
	local k = span(F.tB, 0.3, 1.4)
	if k > 0 and k < 1 and not F.rel then
		local o = look.RingO
		o.fade, o.alpha, o.glow = (1 - k) * 0.6, 0.5 * AK, 1.0
		cv:RingK(W(look, 0, 0, 0.15), (3 + 15 * easeOut(k)) * S, UP, (1.4 * (1 - k) + 0.2) * S, "vapor", o)
	end

	-- THE PULSES: a ring climbs the funnel on every juggle tick
	for _, t0 in ipairs(look.Pulses) do
		local u = (F.now - t0) / T.PulseTime
		if u > 0 and u < 1 then
			local z = H * (0.25 + 0.75 * easeOut(u))
			local ox, oy = axisAt(z)
			local o = look.RingO
			o.fade, o.alpha, o.glow = (1 - u) * 0.9, 0.7 * AK, 1.5
			cv:RingK(W(look, ox, oy, z), radiusAt(z) * 1.02 * S, UP, (0.6 * (1 - u) + 0.15) * S, "glow", o)
		end
	end

	-- THE STREAMERS: vapor shed off the rim, curling out and up
	if live then
		local RH = radiusAt(H)
		local cx, cy = axisAt(H)
		for i, st in ipairs(look.Streamers) do
			local a0 = (i - 1) * 1.256
			local pts, wid, n = st.Pts, st.Wid, T.StreamerPts
			for kk = 1, n do
				local s = (kk - 1) / (n - 1)
				local ang = a0 + Ph * 0.25 + 1.5 * s
				local r = RH * (1.0 + 0.9 * s)
				pts[kk] = W(look, cx + r * cos(ang), cy + r * sin(ang), H * (0.95 + 0.12 * s))
				wid[kk] = (2.5 * s + 0.6) * S
			end
			local o = st.O
			o.fade, o.alpha, o.glow = f * 0.55, 0.4 * AK, 1.0
			cv:Ribbon(pts, wid, "vapor", o)
		end
	end

	-- THE PILLAR: the release pulls the funnel into a tall narrow column of streaks
	if pf > 0.01 then
		local o = look.PillarO
		o.fade, o.alpha, o.glow = pf, 0.6 * AK, 1.3
		for i = 1, T.PillarLines do
			local a = (i - 1) * 0.628 + Fl * 3
			local r = 1.2 + 0.9 * ((i - 1) % 3)
			local x, y = r * cos(a), r * sin(a)
			local pts = look.PillarP[i]
			pts[1] = W(look, x, y, H * 1.05)
			pts[2] = W(look, x, y, 0.2)
			cv:Ribbon(pts, 0.5 * S, "glow", o)
		end
	end

	-- THE SCUFFS: dark spirals worn into the floor from touchdown (v5; v4's end fade, so they go with the funnel)
	local sf = sm(F.tB, T.T_CL1 - 0.1, T.T_CL1 + 0.3) * (1 - sm(F.tB, 5.5, 6.6))
	if sf > 0.01 then
		for i, sc in ipairs(look.Scuffs) do
			local a0 = (i - 1) * pi / 2 + 0.6 * Fl
			local pts, side, n = sc.Pts, sc.Side, T.ScuffPts
			for kk = 1, n do
				local s = (kk - 1) / (n - 1)
				local ang = a0 + 2.2 * s
				local rr = lerp(11.0, 3.5, s)
				local ca, sa = cos(ang), sin(ang)
				pts[kk] = W(look, rr * ca, rr * sa, 0.03)
				side[kk] = Vector3.new(ca, 0, -sa)
			end
			local o = sc.O
			o.fade, o.glow, o.alpha = sf, 0.7, 0.5 * AK
			cv:Ribbon(pts, 0.9 * S, "scuff", o)
		end
	end
end

--- The core light (cyclone_v6): on the axis at 0.35 H, 9000 W x e, Range 30.
local function drawLight(look, cv, rf)
	if not F.live or type(cv.Light) ~= "function" then return end
	local flick = rf and 0.925 or (0.85 + 0.15 * sin(F.Fl * 23))
	local e = F.f * (0.6 + 0.4 * F.st) * (1 + 0.5 * F.su) * flick
	local cx, cy = axisAt(F.H * T.LightAxisAt)
	local ok, err = pcall(cv.Light, cv, W(look, cx, cy, F.H * T.LightAt), T.LightWatts * T.LightScale * e,
		{ range = T.LightRange * T.Scale, flicker = 0, tag = "light" })
	if not ok then warnOnce("light", "cv:Light failed: " .. tostring(err)) end
end

--- Your own Cyclone's edge glare (cyclone_v6 fp): e = air x strength x (0.55 + 0.45 surge) x a sin(19 t) flicker, alpha
--- 0.7, by how near your camera is to its foot.
local function glareLevel(look, camPos)
	if not F.live then return 0 end
	local c = look.Center
	local d = Vector3.new(camPos.X - c.X, 0, camPos.Z - c.Z).Magnitude
	local near = 1 - clamp01((d - T.GlareNear) / max(T.GlareFar - T.GlareNear, 1))
	return clamp01(F.f * F.st * (0.55 + 0.45 * F.su) * near)
end

local GLARE_O = { flicker = T.GlareFlicker, hz = T.GlareHz }

--- ZD.ScreenGlare is per frame: shown while it is called, gone the frame it is not.
local function setGlare(level)
	local zd = engine()
	if not (zd and type(zd.ScreenGlare) == "function") then return end
	local ok, err = pcall(zd.ScreenGlare, level, GLARE_O)
	if not ok then warnOnce("glare", "ZephyrDraw.ScreenGlare failed: " .. tostring(err)) end
end

--- Following the crosshair until touchdown, never faster than the server lets it move (the toon's rule, kept): your own
--- copy takes each spot as it comes; everybody else's eases after the server's.
local function steer(look, dt, C)
	local step = look.Target - look.Center
	if step.Magnitude > 1e-3 then
		local want = look.Own and step or step * clamp(C.SteerEase * dt, 0, 1)
		local most = C.SteerSpeed * dt
		if want.Magnitude > most then want = want.Unit * most end
		look.Center += want
	end
end

--- Ends a look: forgotten (the canvas is ZephyrDraw's to destroy, OnEnd; the glare goes the frame it is not asked for).
local function finish(look)
	if look.Finished then return end
	look.Finished = true
	look.Dead = true
	if looks[look.Character] == look then looks[look.Character] = nil end
	if demoLook == look then demoLook = nil end
	if look.Demo then                                   -- the demo's own stand-ins and clips go with it
		destroyStandIns(look)
		stopDemoClips(look)
	end
end

--- One frame of `look` at time `now` (os.clock() live; clip seconds in a demo). Returns false to end it.
local function frame(look, cv, now, dt)
	if look.Dead then return false end
	local C = shared()
	if not look.Demo and not look.EndAt then
		-- the body went, or the end was never heard: the release plays by itself
		if not look.Character.Parent or now - look.Start > C.FormTime + C.ActiveTime + T.Lost then look.EndAt = now end
	end
	if look.Demo then look.DemoT = now end          -- the stand-ins' and the caster clips' clock
	if look.EndAt and now - look.EndAt >= (look.Blender and T.ReleaseTo - T.ReleaseFrom or T.ReleaseTime) + T.ParticleTail then
		finish(look)
		return false
	end
	if not look.Demo and not look.ActiveAt then steer(look, dt or 0, C) end

	local tB, Ph, Fl, rel = evaluate(look, now, C)
	-- a Cyclone ended before touchdown releases from the size it had reached
	local gEnd = 1
	if rel and not (look.ActiveAt and look.ActiveAt <= look.EndAt) then
		gEnd = clamp(grow((evalForm(look, look.EndAt, C))), 0.05, 1)
	end
	local gr = grow(tB)
	local g = rel and gEnd < 1 and gEnd or clamp01(gr)
	local pf = pillar(tB)
	local lo, su = loosen(tB), surge(tB)
	F.now, F.tB, F.Ph, F.Fl, F.rel = now, tB, Ph, Fl, rel
	F.g, F.gk = g, min(1, g)
	F.pf, F.lo, F.su = pf, lo, su
	F.f, F.st = airFade(tB), strength(tB)
	F.H = hNow(tB) * T.HeightShare * (1 + 0.3 * pf) * gEnd
	F.sc = (0.55 + 0.45 * g) * (1 + 0.35 * lo) * (1 + 0.06 * su)
	F.pk = 1 - 0.62 * pf
	F.live = F.f > 0.004 and F.H > 0.6

	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or look.Center + Vector3.new(0, 1000, 0)
	local rf = reduceFlashing()

	-- touchdown, once (a look that heard it late, past 0.4 s, does not throw it)
	if look.ActiveAt and not look.Touched and now >= look.ActiveAt and not (look.EndAt and now >= look.EndAt) then
		look.Touched = true
		if now - look.ActiveAt < 0.4 then touchdownBursts(look, cv) end
	end
	-- the demo's stand-ins (every frame: pulled in, juggled, thrown, landed) and the caster's clips
	if look.Demo then
		for _, d in ipairs(look.StandIns or {}) do
			local ok, err = pcall(poseStandIn, look, d, now)
			if not ok then warnOnce("standin", "a demo stand-in failed: " .. tostring(err)) end
		end
		demoClips(look)
	end
	-- the juggle
	if look.ActiveAt and now >= look.ActiveAt and not (look.EndAt and now >= look.EndAt) then
		if look.Demo then
			demoTicks(look, cv, now)
		else
			watchJuggle(look, cv, now, C)
		end
	end
	for _, hit in ipairs(look.PendingHits) do juggleHit(look, cv, now, hit) end
	table.clear(look.PendingHits)

	drawFunnel(look, cv, camPos)
	drawLight(look, cv, rf)

	-- the arms' wind while they circle (cyclone_v4: caster_wind), letting go as the palms push out at touchdown
	-- (the demo plays the showcase's channel: the hands keep circling overhead until T_CH, so their wind runs on)
	local w = (look.Blender or not rel) and casterWind(tB) or 0
	local windDone
	if look.Blender then
		windDone = tB > T.T_CH + 0.5
	else
		windDone = rel or (look.ActiveAt and now - look.ActiveAt >= T.HandFadeAfterTouchdown)
	end
	if not look.Blender and look.ActiveAt and now >= look.ActiveAt then
		w *= 1 - sm(now - look.ActiveAt, 0, T.HandFadeAfterTouchdown)
	end
	if look.Character.Parent and not windDone then
		drawHand(look, cv, "R", now, w)
		drawHand(look, cv, "L", now, w)
	end

	-- the debris: rocks, pale sparks and the billow, from 0.4 until the thinning starts
	local emitting = tB >= T.DebrisFrom and (not rel or tB < T.T_TH0) and F.f > 0.004
	local cur = floor((Fl - T.DebrisFrom) / T.DebrisEvery)
	if emitting then
		catchUp(look, "debris", cur, function(i) debrisEvent(look, cv, i) end)
	elseif cur > look.Ev.debris then
		look.Ev.debris = cur
	end
	if rel then
		-- the release's puffs off the top (cyclone_v4, at T_REL, about 0.45 H) ...
		if not look.Puffed and tB >= T.T_REL then
			look.Puffed = true
			if tB - T.T_REL < 0.6 then
				local S = T.Scale
				burst(cv, "puff", W(look, 0, 0, F.H * 0.45), count(look, 14), { speed = { 4 * S, 10 * S },
					life = { 0.6, 1.2 }, size = sizeRange("puff", 0.8, 1.6), id = "relPuff" })
			end
		end
		-- ... and the soft dust ring left on the floor as it thins (cyclone_v5: 40 over T_TH0 .. + 0.8)
		local ringCur = floor((tB - T.T_TH0) / 0.04)
		if ringCur >= 0 then
			catchUp(look, "dustRing", min(ringCur, 19), function(j)
				local rng = Random.new(look.Seed + 50000 + j)
				for _ = 1, 2 do
					if rng:NextNumber() < clamp01(look.Density) then
						local a, r = rng:NextNumber(0, TAU), rng:NextNumber(5, 9)
						rng:NextNumber(1.5, 2.5); rng:NextNumber(1.2, 2.2)   -- (2026-10-08, as debrisEvent's rock: ranges, the draws kept)
						local up = 0.2 * T.Scale
						burst(cv, "dust", W(look, r * cos(a), r * sin(a), 0.2), 1, { dir = UP, cone = 0.2, up = 0,
							speed = { up, up }, life = { 1.5, 2.5 }, size = sizeRange("dust", 1.2, 2.2),
							id = "dustRing" .. j .. ":" .. r })
					end
				end
			end)
		end
	end

	-- your own view: the edge glare (v6 draws it in the first-person shot only: a third-person demo is not washed)
	local zd, firstPerson = engine(), true
	if zd and type(zd.FirstPerson) == "function" then
		local ok, v = pcall(zd.FirstPerson)
		if ok then firstPerson = v == true end
	end
	if look.Character == localCharacter() and firstPerson then
		local level = glareLevel(look, camPos)
		if level > 0.002 then setGlare(level) end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- THE DRIVER
----------------------------------------------------------------------------------------------------
local function osClock()
	return os.clock()
end

local function play(look, name, opts)
	local zd = engine()
	if not zd then return nil end
	opts.OnEnd = function() finish(look) end
	opts.Own = look.Character == localCharacter()        -- ZephyrDraw's density: yours is never Reduce-Enemy-thinned
	opts.Budget = "Cyclone"                               -- ZD.Budgets.Cyclone: 380 Beams, 1 light (End() warns past it)
	local fn = function(cv, t, dt) return frame(look, cv, t, dt) end
	local ok, handle
	if opts.Freeze ~= nil then
		local freeze = opts.Freeze
		if type(zd.Demo) == "function" then
			ok, handle = pcall(zd.Demo, name, fn, opts)
		else
			opts.Freeze = nil
			opts.Clock = function() return freeze end
			ok, handle = pcall(zd.Play, name, fn, opts)
		end
	else
		ok, handle = pcall(zd.Play, name, fn, opts)
	end
	if not ok then
		warnOnce("play", "ZephyrDraw could not play the Cyclone: " .. tostring(handle))
		return nil
	end
	look.Handle = handle
	return handle
end

local function stopLook(look)
	if not look then return end
	look.Dead = true
	if look.Handle and type(look.Handle.Stop) == "function" then pcall(look.Handle.Stop, look.Handle) end
	finish(look)
end

----------------------------------------------------------------------------------------------------
-- API (ZephyrFX's Cyclone functions delegate here, same arguments)
----------------------------------------------------------------------------------------------------
--- The cast: forming at `center`. opts: Late (s the cast is already under way), Own (your own copy: its steering is
--- taken as it comes, not eased). A new cast replaces the last look at once.
function Cyclone.Cyclone(character, center, opts)
	if not RunService:IsClient() then return end
	opts = opts or {}
	if not character or typeof(center) ~= "Vector3" then return end
	local C = shared()
	stopLook(looks[character])
	local look = newLook(character, center, os.clock() - clamp(opts.Late or 0, 0, C.LateMax), opts.Own == true, false)
	looks[character] = look
	play(look, "ZephyrCyclone", {
		Clock = osClock, MaxLife = C.FormTime + C.ActiveTime + T.Lost + T.ReleaseTime + T.ParticleTail + T.MaxLifeSlack,
	})
end

--- Where a forming Cyclone is being steered to (your crosshair, or a spot the server passed on). Ignored once it has
--- touched down or ended.
function Cyclone.CycloneSteer(character, center)
	local look = character and looks[character]
	if look and not look.ActiveAt and not look.EndAt and typeof(center) == "Vector3" then look.Target = center end
end

--- Touchdown, where the server fixed it (`late`: how long ago). A look that missed the cast starts here, formed.
function Cyclone.CycloneActive(character, center, late)
	if not RunService:IsClient() then return end
	if not character or typeof(center) ~= "Vector3" then return end
	local C = shared()
	late = clamp(late or 0, 0, C.LateMax)
	local look = looks[character]
	if not look or look.EndAt then
		Cyclone.Cyclone(character, center, { Late = 0 })
		look = looks[character]
		if not look then return end
		look.Start = os.clock() - C.FormTime - late
	end
	look.ActiveAt = os.clock() - late
	look.Center, look.Target = center, center
end

--- The end: `instant` takes it away now (a new cast, leaving the arena, a round reset); otherwise the release plays.
function Cyclone.CycloneEnd(character, instant)
	local look = character and looks[character]
	if not look then return end
	if instant then
		stopLook(look)
	elseif not look.EndAt then
		look.EndAt = os.clock()
	end
end

--- A juggle tick by hand: a pulse up `character`'s Cyclone, sparks at `at` if given (the hook for a future broadcast).
function Cyclone.Pulse(character, at)
	local look = character and looks[character]
	if not look or look.EndAt then return end
	table.insert(look.PendingHits, typeof(at) == "Vector3" and at or false)
end

--- Every Cyclone look ends now (the demo too).
function Cyclone.StopAll()
	for _, look in pairs(looks) do stopLook(look) end
	stopLook(demoLook)
end

--- The demo that is up, if any, ends now (ZephyrTestHarness calls it after the handle's :Stop()).
function Cyclone.StopDemo()
	stopLook(demoLook)
end

--- Where the demo stands its Cyclone: the showcase's C0, DemoAhead studs straight ahead of `root` (flat), grounded straight
--- down through characters. Returns the flat forward and the foot.
local function demoSpot(character, root)
	local fwd = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.new(0, 0, -1)
	local spot = root.Position + fwd * T.DemoAhead
	local exclude = { character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 8 do
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
		if not hit then break end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local body = model and model:FindFirstChildOfClass("Humanoid") and model
		if not body and hit.Instance.CanCollide then return fwd, hit.Position end
		table.insert(exclude, body or hit.Instance)       -- through bodies and non-colliding parts, onto the floor
	end
	return fwd, Vector3.new(spot.X, root.Position.Y - 3, spot.Z)
end

--- THE TEST HARNESS'S DEMO: the showcase (spring/cyclone_bl.py + cyclone_v6) on `character`, no server, on the
--- showcase's own clock 1:1 (Blender seconds from the press, the reel's: 0.95 birth, 1.56 touchdown, 2.29 juggle, 4.58
--- the pillar): the funnel DemoAhead studs ahead, the caster's CycloneForm / CycloneRelease clips, two stand-in dummies
--- pulled in, juggled (a pulse and sparks on each of the six hits), thrown at the release and landing. opts.Freeze =
--- showcase seconds holds that one frame until handle:Stop(). A new Demo stops the last one.
function Cyclone.Demo(character, opts)
	if not RunService:IsClient() then return nil end
	opts = opts or {}
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	stopLook(demoLook)
	local fwd, foot = demoSpot(character, root)
	local look = newLook(character, foot, 0, character == localCharacter(), true)
	look.Blender = true
	look.ActiveAt = T.T_CL1
	look.EndAt = T.ReleaseFrom
	look.CasterPos = root.Position
	local ok, err = pcall(buildStandIns, look, fwd)
	if not ok then warnOnce("standins", "the demo stand-ins failed: " .. tostring(err)) end
	demoLook = look
	local total = T.ReleaseTo + T.ParticleTail
	local o = { Until = total + 0.1, MaxLife = total + T.MaxLifeSlack }
	if type(opts.Freeze) == "number" then
		o.Freeze = clamp(opts.Freeze, 0, T.ReleaseTo)
		o.Until, o.MaxLife = nil, 3600
	end
	local handle = play(look, "ZephyrCycloneDemo", o)
	if not handle then finish(look) end
	return handle
end

return Cyclone
