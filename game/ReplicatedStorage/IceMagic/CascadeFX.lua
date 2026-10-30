--[[
	CascadeFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/CascadeFX

	Cascade (Voltaic's Ultimate), RE-LIT (2026-09-27). The Roblox port of blender_scripts/voltaic/cascade_bl.py AS IT IS
	NOW -- its T table, build_lumps / build_groups (baked below), radial_k / group_scale / churn_phase / cloud_state,
	creases / seam_paint / seam_glow / seam_lights, plan_flashes / flash_field, arm_angles / plan_windup / windup_frame,
	ext_points / plan_telegraph / telegraph_frame, plan_fan / fork_intensity / fan_frame, plan_main / main_path /
	strike_frame, THE VOLTAIC BOLT SPEC volt(), the skeleton hit-flash (_skeleton / skel_level / skeleton_frame) and the
	sparks -- and of vfx_blocking/voltaic/CASCADE_showcase.md. It REPLACES the comic Cascade (the 22 VT3_Cascade_* toon
	meshes, VFXLibrary's Cascade emitters) whole. VoltaicFX keeps Tuning.Cascade (the server reads it) and hands the
	three broadcasts here: VoltaicFX.CascadeGather / CascadeStrike / CascadeEnd -> CascadeFX.Gather / Strike / End.

	THE CLOCK. t = Kit.clock(T0) (shot seconds since the key; T0 is the server's cast stamp). VoltaicFX.Tuning.Cascade
	.Windup (0.50) puts the caster's windup in front of the storm: the storm's clock is S = t - Windup, the comic's clock
	unchanged, and Tuning.Cascade.Strikes (what the server schedules from T0) is Windup + StormStrikes, so the five
	damage ticks moved with it (Windup = 0 is today's timing exactly). V is the storm's VISUAL clock: S held on the
	dominant strike's contact for HoldFrames / 60 s (THE HITPAUSE, TerraFX.AftershockClock's pattern) -- the cloud, the
	sparks (ParticleEmitter.TimeScale 0) and every lump freeze; only the contact builds.

	THE EMULATION MAP, Blender -> Roblox (the kit's; railspike_bl / volt_orb_bl / overcharge_bl):
	  * axes: Blender (x, y, z) -> Roblox (-x, z, y) (VoltaicKit.KIT_TURN, the comic port's map), in a storm frame on the
	    marked point turned so Blender +y (caster -> storm) runs from the caster's root to the point, horizontally.
	  * a cloud LUMP -> a Part with a SpecialMesh (MeshType Sphere) drawing the lump's ellipsoid (2r, 2r x SQ_G 0.80,
	    2r): the Part is sized once to the biggest the lump grows (its home ellipsoid x LumpRoom 1.25) and the mesh's
	    uniform Scale (r / that) draws it inside, so the culling and shadow bounds (Part.Size) always cover the mesh.
	    SmoothPlastic, OPAQUE, Color = Dark x its value, anchored, CanCollide / CanQuery / CanTouch off; every lump
	    moved in one workspace:BulkMoveTo a frame. The field (483 lumps: 117 big, 309 florets, 19 three-lump scrap puffs,
	    651 hop points) is BAKED below from cascade_bl.py itself, run headless -- the same numbers, so it matches.
	  * a camera-facing strip -> a Beam (FaceCamera, Segments 4): CORE (Kit.Tex.Core, LightEmission 1) + GLOW
	    (Kit.Tex.Glow, LightEmission 0.55, GLOW_ALPHA 0.85). volt()'s per-point brightness is FOLDED into each Beam's
	    Transparency and Color sequences: the showcase doubles every bolt's points with mid-runs and paints each; here a
	    bolt is one Beam per jag segment whose sequences carry corner -> mid-run -> corner, and the hot layer (the
	    Bloom points) is folded in as each segment's Brightness boost and whiteness. The glow spans two jag segments on
	    long bolts (its width hides the corner). So a strand is a handful of Beams, not the showcase's per-point dozens.
	  * a SEAM (the showcase's Neon tube along every exposed crease, re-solved every frame): re-solved at SeamHz (12-20;
	    half that SeamFar studs off) over a sweep-and-prune pair list (refreshed every solve while the cloud forms, every
	    PairEvery solves after) with SeamSamples (8-12) per crease circle,
	    each lit run cut into <= SeamPiece (120)-degree pieces; each piece ONE core Beam bowed along its circular arc (CurveSize =
	    the cubic Bezier handle, 4/3 tan(theta / 4) rho, each attachment's X axis on the arc's tangent), colour by heat
	    (Base -> Light -> white) and opacity by light in its sequences, width by light, and Beam.ZOffset pulling it one
	    tube radius out of the crease -- so the two lumps' own depth still cuts it and it shows only down in the fold
	    (a flat strip AT the crease line would be hidden by both walls). The glow Beam shares its arc, ZOffset + 0.3.
	    Every piece is re-placed from its two lumps' live positions on every frame the lumps are re-posed (CloudHz) or
	    the seams re-solved (the arc is solved in that pair's own crease frame), so a 20 Hz solve never lags the churn
	    and an unmoved cloud re-lays nothing. Capped at SeamCap (70-220) pieces, brightest first. All
	    the showcase's rules hold: only deep (SeamDeep), central (SeamReach) creases light; the slow leak noise leaves
	    about half dark; a dim crease (e < 0.10) draws nothing; floret creases x FloretSeam; the break-up's glow is
	    weighted by each fragment's own scale. SeamLights PointLights in the hottest creases, pushed 0.9 out of the V
	    (the brightest SeamShadows of them with Shadows on).
	  * a particle quad (a star, a soft glow) -> a camera-facing Beam quad (OverchargeFX's sprite): StarCore / StarGlow
	    pairs, VT_Overcharge_Soft (rbxassetid://130067461865773) glows -- per-frame size, and they build through the hold.
	  * a floor hot spot / the scorch -> a SurfaceGui (LightInfluence 0, Brightness > 1) with the Soft image on a flat
	    invisible part: the only emissive flat quad Roblox has without a new asset.
	  * PointLight -> PointLight, Brightness / Range straight from the T numbers (Range capped at 60); at most MaxLights
	    (12) at once by priority -- strike > belly > hub > channel > forks > hands > launch > seams.
	  * sparks -> one ParticleEmitter (the Soft sprite, VelocityParallel, Squash), Acceleration -60, Drag 1.6; the
	    render's floor bounce is dropped (showcase flag 8).
	  * Bloom -> VoltaicKit.bloomPulse (in first person through its `anyView` argument, THE VOLTAIC KIT PATCH -- FLAG 7);
	    ExposureCompensation -> this module's own kick (restored afterwards, any other writer's value adopted as the new
	    base, as the Kit's Bloom kick does); camera shake -> Viewmodel.Shake, translation only (DEVIATIONS 9; the Camera
	    Shake setting scales it, Reduce Flashing removes it).

	THE BEATS (seconds from the key; S = t - 0.50): 1 WINDUP 0-0.62 at the caster's hands (arcs reeled in, hand-to-hand
	bridges, seed stars and hand lights, the white set-flash, the launch bolt from both hands into the sky; the BODY is
	CastPose / Viewmodel "CascadeSummon", not drawn here). 2 GATHERING S 0-0.72 (the nine groups and the scraps curl in,
	churning; the punch at 0.52). 3 TELEGRAPH S 0.52-1.20 (walkers hop over the cloud, 12 -> 26, faster, further,
	wilder; internal flashes 3 -> 15 / s). 4 RELEASE: the fan at 1.200 (9 rays, 4 ground forks to the strike points),
	the forks re-strike on StormStrikes 1-4, the leader 1.500 / 1.517, CONTACT at 1.533 (the hold), THE FLASH one frame
	after it. 5 DISSIPATION V 1.80-4.36 (fragments shrinking as one piece, their glow with them). Gone by
	Windup + 4.36 + 0.067 + 0.20 = 5.13 s.

	WHERE THE BOLTS LAND. The fan needs four ground points at S 1.200 and the server decides strike N at its own time
	(showcase flag 2), so each client PREDICTS the server's rule at the fan (VoltaicHandler strikeOnce: the body in the
	zone struck fewest, ties to the nearest; none -> VoltaicTuning.Cascade.Spread's filler point) and draws the forks
	there. THE PREDICTION IS WHAT EVERY CLIENT SEES AT THE STRIKE MOMENT: the server strikes N at T0 + Strikes[N] and the
	client's clock is the server's, so CascadeStrike N normally arrives the one-way latency after strike N was drawn --
	then nothing on the ground moves (no scorch, ring or light teleports) and only a body the prediction missed gets its
	skeleton flash, late by the latency. A payload that arrives BEFORE its strike is drawn (a slowed review, a clock
	running behind) re-aims fork N (N <= 4) or the dominant bolt (N = 5). The dominant bolt is rooted at the belly hub
	(flag 9) and to a body off the centre LEANS EVENLY along its whole length (the steepest legs any path from the hub
	can have: tipping only the bottom leg would lay it past 70 degrees at the zone's edge), its swings turned across the
	lean and trimmed toward the zone's edge (buildMainKinks: steepest leg ~53 degrees off vertical at the edge, the
	showcase's own centre strike ~51); with nobody there it strikes the centre, as the showcase does.

	THE SKELETON HIT-FLASH. The strike payloads do not say who was hit, so the flash triggers on any model with a live
	Humanoid (not the caster) whose root is within SkelRadius of a strike's ground point: the fan's forks at the fan
	instant and on their re-strikes (SkelFan, no hitpause), the dominant strike at contact (SkelMain, held through the
	hitpause). Drawn as the showcase does: the icon skeleton in volt()'s material facing the viewer on the body's front,
	shivering; the jagged 14-spike Dark burst behind it (solid-colour Beam triangles, no texture) with a thin Base rim;
	a near-black Highlight on the body while the level is >= 0.3. At most SkelCap at once.

	FIRST PERSON. The caster's own windup rides the Viewmodel's fists (VoltaicKit.castPoint) at FpScale 0.35 -- arcs,
	bridges, seeds and motes a third the size, the hand lights x FpLight at a third of the range, the launch bolt thin
	near the lens and full width out in the sky -- so the charge sits at the top of the view and never fills it.

	SETTINGS.
	  * Reduce Flashing: no exposure kick, no shake and no set-flash (Bloom or hand whitening); THE FLASH's Bloom kick
	    halved (the Kit then drops it entirely); stars x0.75;
	    the strike's, the belly's, the hub's and the forks' lights, the floor hot spots and EVERY internal flash event
	    (the telegraph's, the punch, the fan, the re-strikes, the strike) x0.6, the telegraph's flashes at most 3 a
	    second; the telegraph, fan, forks and strike re-jagged at a third of their rate (10 / 20 Hz); the fork re-strikes
	    held as one stroke (no spike, reshape or whitening); Beams x0.85; the skeleton flash fades straight out over
	    three frames (no flicker) and its burst is 60 %. (2026-10-19, audit P5D-03)
	  * Graphics Quality (SpellshotSettings.EffectDensity -> tiers 1-4) and thin (Kit.thin: somebody else's cast with
	    Reduce Enemy VFX, or low density) scale the decoration, never the read: florets all / half / none (florets first),
	    scraps, SeamCap / SeamHz / SeamSamples / SeamLights / SeamShadows, the telegraph's walkers and jag depth, the
	    sparks, SkelCap, the big lumps' CastShadow. The big lumps, the fan, the forks, the dominant strike and its flash
	    always draw.
	  * Flat-lit maps: no PointLights, Beams emission x0.35 / Brightness x0.7 (the Kit's rule). Daylight: lights x0.5.

	BUDGET (HIGH; counted from the draw calls this code makes, not measured in Studio). Lumps: 483 parts (145 at LOW),
	one BulkMoveTo a frame (30 Hz at LOW / MEDIUM), a SpecialMesh.Scale write only when a radius moves > 0.8 %. Seams:
	<= 180 pieces (a core + a glow Beam each), 2 attachment CFrames each on a frame the cloud moved; the solve's cost is
	NOT MEASURED (a Python replica of the pair sweep: ~41,000 sweep steps / ~3,700 candidate pairs a refresh at HIGH,
	~3,800 / ~700 at LOW) -- read the "CascadeFX seamSolve" profiler label at HIGH before shipping (FLAG 8). Telegraph
	peak (26 walkers, redrawn at 30 Hz): 26 x (8 core + 4 glow) + forks + embers, ~430 Beams. Fan frame: 9 rays + 9 ray
	forks + 4 ground forks + their branches, ~310 Beams (the showcase: 1,114 segments). Strike: ~110 Beams + the ring
	(36) + stars. A skeleton flash ~210 Beams (three strands) + a 70-Beam burst, <= SkelCap (3) at once. Lights <= 12
	(<= 7 with shadows). Sparks <= 126 particles. INSTANCES: the Beams in use above are ~4,400 instances with their
	Attachments; the pools start empty in a session, so stepWarm makes them through the windup and the gathering
	(WarmBatch 110 a frame, ~40 frames at HIGH, done before the fan), never in the fan's or the contact's frame.

	DEVIATIONS from the showcase.
	  1 The lumps are smooth SpecialMesh spheres (decision 3), not the render's 8 noise-displaced lumpy variants.
	  2 Seams: 12 samples a crease (not 28), solved at 20 Hz (not per frame), capped (the render drew ~1,050 lit runs);
	    each piece's per-point radius is folded into its opacity (a Beam has one width a end).
	  3 The churn noise is math.noise (Roblox's improved Perlin, sd 0.272) for Blender's noise_vector (sd 0.279).
	  4 Random draws are per cast (seeded from T0 and the caster, so every client draws one cast alike); the lump field
	    is the showcase's own. The telegraph, fan, forks and strike re-jag at 30 Hz (the telegraph was 60).
	  5 The glow Beams do not push their ends 35 % past the core's; the glow spans two segments on long bolts.
	  6 The fork and strike ground points are the server's (see WHERE THE BOLTS LAND), not the render's pentagram.
	  7 Skeleton: facing the viewer (yaw only), scaled to the body's height; one Highlight darkens the whole body.
	  8 The windup's slow Bloom build (+0.10) is not ported. The set-flash's +0.25 is, for everyone watching the hands
	    but the caster in first person (faded out SetFlashReach studs off; a first-person onlooker through the Kit's
	    `anyView`, faded within FpBloomNear) -- the showcase's onlooking camera sees it; the caster's own raised arms
	    would bloom white (the Kit's reason for its first-person rule).
	  9 The camera shake is Viewmodel.Shake's: translation only (0.30 studs, decaying tau 0.22), at its own sines (61 / 53
	    / 71 rad/s, ~10 Hz). The showcase's 1.2-degree rotation (T.Shake[2]) and its 21 Hz (T.Shake[4]) are not applied:
	    a pitch or yaw would move the aim. (A roll-only jolt would not; it would be a new optional Viewmodel.Shake
	    argument, a Viewmodel change.)

	FLAGS (the owner's to check in Studio).
	  1 Compiled with Studio's own compiler (tools/luau_compile_check.py) on 2026-09-27, after the review fixes: OK.
	    Never run in Play yet. The main chunk holds ~166 locals of Luau's 200 at its end (the section helpers live in
	    do-blocks), BUT a top-level do-block's locals are main-chunk registers while it runs: the PEAK is 187, inside the
	    seamSolve block (its ~50 locals), so the hard limit is 13 locals away there. Add new helpers inside one of the
	    SMALL sections' blocks or inside a function -- never to the seamSolve block, nor at the top level before it.
	    (2026-10-19, audit P5D-14)
	  2 SpecialMesh Sphere scales to Part.Size x Scale (assumed: the Part is the lump's ellipsoid x LumpRoom, the Scale
	    uniform r / that); check one lump's drawn size against its r, and that a big lump at the screen's edge (looking
	    up into the cloud) does not pop.
	  3 The burst fill assumes a Beam with no Texture draws as a solid colour.
	  4 The seam ZOffset (SeamZ x the tube radius) and SeamHz / SeamCap are first guesses, to be judged in play.
	  5 A client's fork prediction can miss the server's pick (teammates, a body moving); what it drew stands, and the
	    struck body gets a late skeleton flash (WHERE THE BOLTS LAND).
	  6 The body pose is two NEW clips (CastPose / Viewmodel "CascadeSummon") -- returned as patches, not in place yet.
	  7 THE FLASH's Bloom (+1.1 Intensity / +0.25 Size) and the set-flash reach a first-person viewer only through
	    VoltaicKit.bloomPulse's 6th argument `anyView` -- a VoltaicKit PATCH returned with this port. Until it is in,
	    nobody in first person (FirstPersonController's default) gets either Bloom: only THE FLASH's exposure kick lands.
	  8 The seam solve's cost is unmeasured: profile "CascadeFX seamSolve" at HIGH (three storms at once is the worst).
	  9 (applied) VoltaicTestHarness skips its own caster dummy as a Cascade target, as the server does
	    (VoltaicTestHarness.client.lua lookCascade; 2026-10-19, audit P5D-18).

	PLUMBING (OverchargeFX's). Nothing happens at require time: VoltaicKit / VoltaicTuning / VoltaicFX are required
	lazily with timed waits on the first call, so the server may require this module and nothing breaks. One
	BindToRenderStep runner at RenderPriority.Last (after the camera and the Viewmodel) steps every storm in a pcall; a
	frame that errors clears its storm. Lumps, Beam strands, sprite quads and the seam kit are POOLED across casts (an
	idle piece parented to nil). A watchdog (MaxReal) and the FX folder's own clearing end a storm that outlived itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local CascadeFX = {}
CascadeFX.PendingEnds = {}           -- (2026-10-19, audit P5D-15) Ends heard before their storm (see CascadeFX.End)

-- VT_Overcharge_Soft (export/voltaic/VT_Overcharge_Soft.png), uploaded 2026-09-26: the soft glow sprite.
local SOFT_TEX = "rbxassetid://130067461865773"

----------------------------------------------------------------------------------------------------
-- The numbers: cascade_bl.py's T, key for key where it has one (S = storm seconds, V = the visual storm clock).
-- EVERY NUMBER IS A PROPOSAL. Windup / StormStrikes / BellyHeight / ZoneRadius are VoltaicFX.Tuning.Cascade's (the
-- server's clock); the rest are the look's. The PORT block at the end is this port's own.
----------------------------------------------------------------------------------------------------
CascadeFX.Tuning = {
	-- 1 WINDUP (seconds from the key, AUTHORED FOR A 0.50 WINDUP: another Windup plays them on t x 0.50 / Windup)
	HandArcRate = { 20.0, 60.0 },  -- gathering arcs per second PER HAND, at 0.14 / at 0.50
	HandArcFrom = { 0.9, 1.8 },    -- studs from the hand an arc's outer end starts
	HandArcLife = 0.12,            -- each is reeled in over this
	HandArc = { 0.045, 0.30, 2.2, 1.2 },    -- core width, glow width, core / glow Brightness
	Bridge = { 0.24, 0.50, 0.05 }, -- arcs snapping hand to hand overhead: from, to, one every this
	HandSeed = { 0.18, 0.75, 1.5 },-- the hand's glow: size at the key / at the top; Brightness
	HandLight = { 0.4, 2.4, 9.0 }, -- PointLight per hand: Brightness at the start / at the top; Range
	SetFlash = 0.06,               -- the hands flash white (x1.8) over the last this-many seconds before the launch
	Launch = { 0.07, 34.0, 0.11, 0.80, 2.6, 1.3 },   -- seconds on screen, length, core / glow width, core / glow Brightness

	-- 2 GATHERING (S)
	Gather = 0.40, Loose = { 1.18, 1.06 },
	Squeeze = { 0.52, 0.90, 0.93, 0.84 },   -- the punch lands at S, radius x, scale xy, scale z
	Rebound = { 0.62, 1.03 }, Settle = 0.72,
	Spin = 0.30,                   -- rad/s, clockwise from above, the whole time
	Tension = { 1.05, 0.965 }, Kick = { 1.06, 1.015, 1.45 },
	Churn = { { 0.0, 1.3 }, { 0.40, 1.45 }, { 0.52, 1.8 }, { 0.66, 0.9 }, { 0.90, 0.42 }, { 1.20, 1.05 }, { 1.40, 0.75 },
		{ 2.0, 0.55 }, { 4.6, 0.35 } },
	ChurnRate = { { 0.0, 1.5 }, { 0.52, 1.8 }, { 0.90, 0.75 }, { 1.20, 2.6 }, { 1.60, 1.3 }, { 4.6, 0.7 } },
	ChurnScale = 0.085,
	Charge = { { 0.0, 0.45 }, { 0.38, 0.55 }, { 0.52, 1.30 }, { 0.80, 1.00 }, { 1.20, 1.85 }, { 1.25, 1.55 }, { 1.52, 1.40 },
		{ 1.80, 1.60 }, { 3.2, 1.50 }, { 6.0, 1.40 } },
	Friction = 1.6,

	-- 3 TELEGRAPH (S)
	Tel = { 0.52, 1.20 }, Walkers = { 12, 26 }, Hop = { 0.110, 0.034 }, HopLen = { { 4.0, 8.0 }, { 4.0, 12.0 } },
	Err = { 0.20, 1.0 }, Reach = { 0.30, { 3.0, 6.5 }, 0.20 }, TelBulge = 0.30,
	TelArc = { 0.14, 1.10, 2.5, 1.35 }, TelArcOver = { 0.55, 0.45 }, TelLife = { 0.075, 0.034 },
	Flashes = { { 0.0, 2.0 }, { 0.52, 3.0 }, { 1.20, 15.0 } },
	AfterFlashes = { 1.85, 4.30, 5.0, { 0.95, 0.35 } },
	FlashAmp = { { 0.0, 0.45 }, { 0.52, 0.60 }, { 1.20, 1.30 } },

	-- 4 RELEASE (StormStrikes = VoltaicFX.Tuning.Cascade's, the comic's 1.2333 / 1.30 / 1.3667 / 1.4667 / 1.5333)
	Fan = 1.20, FanRays = 9, FanLen = { 7.0, 13.0 }, FanDip = { 8.0, 30.0 },
	FanArc = { 0.26, 1.60, 2.6, 1.4 }, ForkArc = { 0.30, 1.80, 2.8, 1.4 },
	FanHold = 0.10, FanFade = 0.07, ForkHold = 0.035, ForkFade = 0.035,
	HubStar = { 3.0, 2.3, 1.3 }, HubLight = { 7.0, 30.0 }, ForkStar = { 1.5, 2.3, 1.3 }, ForkLight = { 4.0, 11.0 },
	Leader = { 1.500, 1.5167 },
	Main = { 0.95, 5.5, 3.4, 1.9 }, MainKinks = { 5, 0.7, 1.5 }, MainHold = 0.20, MainFade = 0.20,
	Contact = { 0.35, 1.4, 2.6, 8.0, 22.0 },
	HoldFrames = 4,                -- THE HITPAUSE (TerraFX.Tuning.Aftershock.HoldFrames)
	FlashEV = { 0.60, 0.05 }, BellyLight = 4.0, FlashBloom = { 1.1, 0.25, 0.10 },
	BigLight = { 30.0, 60.0, 0.07, 5.0 }, ImpactStar = { 8.0, 3.0, 1.6 }, Ring = { 15.0, 0.30 },
	HeldRange = 60.0,              -- IN PLAY: the held glow (after the spike) lights the ground and the pillars at the
	                               -- full Range, and COOLS Light -> BELLY_LIGHT over 0.05-0.35 s: the belly it reaches
	                               -- goes lilac, not pink (a Range-20 glow left the ground unlit in daylight)
	Shake = { 0.30, 1.2, 0.22, 21.0 }, Sparks = { 70, 14 },

	-- 5 DISSIPATION (V)
	FadeStart = { ArmA3 = 1.80, ArmB2 = 1.86, ArmC2 = 1.92, ArmA2 = 1.98, ArmB1 = 2.04, ArmC1 = 2.10, ArmA1 = 2.18,
		Core = 2.28, Crown = 2.36 },
	FadeT = 2.0, FadeUp = 4.0, FadeApart = 0.20, Drift = { 12.0, 8.0, 2.0 },

	-- THE CLOUD's seams
	SeamTube = { 0.09, 0.22, 0.55 }, SeamLeak = { 0.30, 1.2, 0.12 }, SeamGlow = { 2.4, 0.30, 1.25 },
	SeamDeep = { 0.62, 1.10 }, SeamHot = { 0.34, 2.2 }, SeamReach = { 15.0, 11.0 }, FloretSeam = 0.35,
	SeamLight = { 1.7, 8.0 },

	-- THE VOLTAIC BOLT SPEC
	VoltVar = { 2.0, 5.0, 0.30 }, VoltK = { 0.40, 1.00, 0.62 }, VoltWhite = { 0.20, 0.30 }, VoltCorner = 1.30,
	VoltHot = { 0.55, 2.4, 0.55 }, VoltPulse = { 0.08, 90.0, 1.6, 0.55, 1.2 },

	-- THE SKELETON FLASH
	Skel = { 0.075, 0.42, 2.6, 1.3 }, SkelMain = { 4, 4 }, SkelFan = { 2, 2 }, Burst = { 14, 2.6, 4.4, 0.75 },
	BurstRim = { 0.05, 0.30, 2.0, 1.0 }, BodyDark = Color3.new(0.07, 0.035, 0.11),

	-- PORT (this port's own; see the header)
	NoiseK = 1.0,                  -- math.noise -> Blender noise (sd 0.272 vs 0.279, measured)
	SeamZ = 0.9,                   -- a seam Beam's ZOffset, x its tube radius: out of the crease, still cut by the walls
	SeamGlowZ = 0.3,               -- the glow's extra ZOffset (the showcase's 0.30 out of the crease)
	SeamSegments = 6,              -- a seam Beam's tessellation along its arc
	SeamPiece = 120,               -- degrees of crease circle per seam Beam at most (one cubic Bezier bows it well)
	PairEvery = 4,                 -- solves between pair-list refreshes (every solve while the cloud forms; the break-up's
	                               -- fragments only shrink and part, so a cached list stays a superset there)
	PairMargin = 1.2,              -- studs of slack on a cached pair
	SeamFar = 150,                 -- studs from the camera to the storm's point: beyond it the seams solve at half SeamHz
	MaxLights = 12,
	-- THE BODY'S COLOR3, tuned IN PLAY (2026-09-28): Dark #4A1A8C itself rendered pure blue (14, 0, 167 on screen) under
	-- the place's noon light (Ambient ~0.42/0.49/0.62) and its SkylineGrade (+0.35 saturation), not the near-black violet
	-- the dusk showcase shows. The same hue with more red, darker, reads dark violet here (x the lumps' 0.80-1.08 spread).
	Body = Color3.fromRGB(72, 16, 84),
	LumpRoom = 1.25,               -- a lump Part's Size is its home ellipsoid x this (the Loose / kick / churn growth fit
	                               -- inside it), the mesh drawn at r / (L.r x this): render and shadow bounds cover the mesh
	WarmBatch = 110,               -- instances made a frame through the windup and the gathering to pre-warm the pools
	                               -- for the fan, the contact and the skeleton flashes (a first cast never builds ~3,000
	                               -- Beams in the climax's frame)
	CatchUp = 2.0,                 -- a storm called off before any strike runs this many storm seconds a second EXTRA
	                               -- (x3 its pace) to its break-up, from where it is -- never a jump
	MainLean = { 0.25, 0.5 },      -- the dominant bolt leaning to a body: its swings cut by this at the zone's edge, its
	                               -- along-the-lean jitter by this once it leans (see buildMainKinks)
	SetFlashReach = { 45, 110 },   -- studs from the caster's hands: the set-flash's Bloom full within, gone beyond
	FpScale = 0.35, FpLight = 0.5, -- first person: the windup's size at the Viewmodel's fists; its hand lights
	FpHandCap = 0.25,              -- first person: a hand's glow / seed star at most this x its distance from the lens
	FpNear = { 4, 20 },            -- first person, ANY sprite or strand: at most SpriteCap / WidthCap x its distance
	FpSpriteCap = { 0.5, 1.2 },    -- from the lens (the first at <= FpNear[1] studs, the second at FpNear[2]; no limit
	FpWidthCap = { 0.15, 0.6 },    -- beyond) -- a strike landing on the viewer reads as a bright hit, not a white screen
	FpBloomNear = { 12, 25 },      -- first person: a Bloom kick none within, full beyond (studs to the strike / the hands)
	FlashReach = { 70, 170 },      -- studs from the strike: the exposure / Bloom kick full within, gone beyond
	ShakeReach = { 45, 110 },      -- ...and the camera shake (the showcase's wide camera was 42 studs off)
	SkelRadius = 3.0,              -- studs (flat) from a strike's ground point to a struck body's root (the prediction)
	HitBodyRadius = 7.0,           -- studs (flat) from a payload's At to the body it struck (the server's copy trails)
	FillerTol = 0.5,               -- studs (flat): an At this close to the server's filler point struck nobody
	SnapWindow = 0.12, SnapMax = 24, -- a telegraph landing lights the seams this long (s), the newest this many at once
	CalmStar = 0.75, CalmFlash = 0.6, CalmBeam = 0.85, CalmBurst = 0.60,
	MaxStorms = 3,
	MaxReal = 30,                  -- real seconds: the watchdog (stretched by a slowed review: TEND / ShotTimeScale + 5)
	LumpBatch = 48,                -- lumps made (or taken from the pool) a frame while a storm builds
	Quality = {                    -- by SpellshotSettings.EffectDensity tier (1 LOW .. 4 ULTRA); thin = tier 1. CloudHz: how
	                               -- often the lumps are re-posed (the seams ride them either way); TelHz / TelDepth: the
	                               -- telegraph's re-jag rate and jag depth (the showcase: 60 Hz, depth 4 = ULTRA)
		{ CloudHz = 30, Florets = 0, Scraps = 2, SeamCap = 70, SeamHz = 12, SeamSamples = 8, SeamLights = 3, SeamShadows = 0,
			Walkers = 0.5, TelHz = 30, TelDepth = 2, Sparks = 0.35, SkelCap = 1, LumpShadow = false },
		{ CloudHz = 30, Florets = 2, Scraps = 1, SeamCap = 120, SeamHz = 15, SeamSamples = 10, SeamLights = 5, SeamShadows = 0,
			Walkers = 0.75, TelHz = 30, TelDepth = 2, Sparks = 0.6, SkelCap = 2, LumpShadow = false },
		{ CloudHz = 60, Florets = 1, Scraps = 1, SeamCap = 180, SeamHz = 20, SeamSamples = 12, SeamLights = 8, SeamShadows = 3,
			Walkers = 1, TelHz = 30, TelDepth = 3, Sparks = 1, SkelCap = 3, LumpShadow = true },
		{ CloudHz = 60, Florets = 1, Scraps = 1, SeamCap = 220, SeamHz = 20, SeamSamples = 12, SeamLights = 10, SeamShadows = 4,
			Walkers = 1, TelHz = 60, TelDepth = 4, Sparks = 1, SkelCap = 3, LumpShadow = true },
	},
}
local T = CascadeFX.Tuning

local F = 1 / 60
local TAU = 2 * math.pi
local SQ_G = 0.80                  -- cascade3.SQ: every lump's squash, and the sphere space -> world map
local NEON_K = 2.4                 -- the showcase's Neon: its Color3 x this, emitted
local GLOW_ALPHA = 0.85            -- VoltaicFX's GLOW_ALPHA
local GLOW_LE = 0.55
local PARTICLE_QUAD = 2.0          -- a star's quad is 2 x its size
local EMBER_HALO = Color3.fromRGB(122, 74, 208)
local WHITE = Color3.new(1, 1, 1)
local SEAM_WHITE = Color3.new(1, 1, 0.92)
-- IN PLAY (2026-09-28): every light that reaches the cloud's belly is this violet-white, not Light / Base. Yellow light
-- on the violet body turned the whole storm hot pink under the place's noon light and +0.35 saturation grade (the fan,
-- the contact and the flash). Magenta is the Sparks currency's mark and never Voltaic VFX.
local BELLY_LIGHT = Color3.fromRGB(165, 150, 255)   -- R/B under 0.64: the lit body (72, 16, 84) stays violet (0.80 still read magenta)
local FLAT_EMISSION, FLAT_BRIGHTNESS = 0.35, 0.7
local W0 = 0.50                    -- the windup the showcase's hand timings are authored for
local VOLT_W = (1 + T.VoltCorner) / 2   -- volt()'s width on a bolt's inner points, folded: the showcase swells every
                                   -- corner to 1.30 and pinches every mid-run to 1.00; a Beam runs linearly corner to
                                   -- corner, so it carries their mean (the opacity / colour sequences keep the contrast)
local UP = Vector3.yAxis
local RUNNER = "SpellshotCascadeFX"
local SIDES = { "L", "R" }         -- the showcase's side 0 (left, x -1.45) and side 1

----------------------------------------------------------------------------------------------------
-- plumbing: lazy requires (nothing at load)
----------------------------------------------------------------------------------------------------
local Kit, COL, VTUN, WHITE_HOT = nil, nil, nil, nil
local CLOCK = nil                  -- VoltaicFX.Tuning.Cascade (Bind), else found lazily
local retryAt = 0
local kitLoading = false           -- libs() is part-way through its first load (it may yield on a timed wait)
local warned = {}

local function warnOnce(key, msg)
	if Kit and Kit.warnOnce then
		Kit.warnOnce("CascadeFX:" .. key, "[CascadeFX] " .. msg)
		return
	end
	if warned[key] then return end
	warned[key] = true
	warn("[CascadeFX] " .. msg)
end

--- IceMagic.<name>, pcall-required: a plain FindFirstChild first, then one timed wait.
local function requireIce(name, wait)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic") or ReplicatedStorage:WaitForChild("IceMagic", wait)
	if not ice then return nil end
	local m = ice:FindFirstChild(name) or ice:WaitForChild(name, wait)
	if not (m and m:IsA("ModuleScript")) then return nil end
	local ok, res = pcall(require, m)
	if ok and type(res) == "table" then return res end
	warnOnce("req:" .. name, ("IceMagic.%s failed to load: %s"):format(name, tostring(res)))
	return nil
end

--- VoltaicFX hands its Tuning.Cascade over (the server's clock: Windup, StormStrikes, BellyHeight, ZoneRadius).
function CascadeFX.Bind(tuning)
	if type(tuning) == "table" then CLOCK = tuning end
end

-- when VoltaicFX / VoltaicTuning cannot be read: the contract's numbers (and VoltaicTuning.Cascade.Spread's filler)
local FALLBACK = {
	Clock = { Windup = 0.50, StormStrikes = { 1.2333, 1.3000, 1.3667, 1.4667, 1.5333 }, BellyHeight = 14, ZoneRadius = 11 },
	Spread = { { 0.84, 0 }, { 0.46, 144 }, { 0.78, 288 }, { 0.55, 72 }, { 0.66, 216 } },
}

--- (Windup, the storm-clock strike times, belly height, zone radius) from the bound Tuning.Cascade.
local function clockNumbers()
	local C = CLOCK or FALLBACK.Clock
	local W = tonumber(C.Windup) or 0
	if W < 0 then W = 0 end
	local strikes
	if type(C.StormStrikes) == "table" and #C.StormStrikes >= 5 then
		strikes = C.StormStrikes
	elseif type(C.Strikes) == "table" and #C.Strikes >= 5 then
		strikes = {}
		for i, s in ipairs(C.Strikes) do strikes[i] = s - W end
	else
		strikes = FALLBACK.Clock.StormStrikes
	end
	return W, strikes, tonumber(C.BellyHeight) or 14, tonumber(C.ZoneRadius) or 11
end

local prepare                      -- forward: the baked data -> runtime tables

--- Loads VoltaicKit (required), VoltaicTuning and VoltaicFX's clock (optional) once. False while the kit is missing.
--- Kit is PUBLISHED LAST, after every table it needs is built: the timed waits below may yield, and a broadcast that
--- arrives meanwhile waits here for the load to finish (VoltaicFX's own cascadeFX() rule) instead of finding Kit set
--- and building a storm from nil tables.
local function libs()
	if Kit then return true end
	if kitLoading then
		local give = os.clock() + 12
		while kitLoading and os.clock() < give do task.wait() end
		return Kit ~= nil
	end
	if os.clock() < retryAt then return false end
	kitLoading = true
	local ok, err = pcall(function()
		local k = requireIce("VoltaicKit", 3)
		if not (k and k.clock and k.jag and k.Tex and k.COL and k.fxFolder) then
			retryAt = os.clock() + 5
			warnOnce("kit", "IceMagic.VoltaicKit is missing or failed to load: Cascade draws nothing until it is back")
			return
		end
		pcall(k.libs)                -- warm the kit's own lazy requires here, where a timed wait may yield
		local tun = requireIce("VoltaicTuning", 2)
		VTUN = (type(tun) == "table" and type(tun.Cascade) == "table") and tun.Cascade or nil
		if not CLOCK then
			local fx = requireIce("VoltaicFX", 2)
			if fx and type(fx.Tuning) == "table" and type(fx.Tuning.Cascade) == "table" then CLOCK = fx.Tuning.Cascade end
		end
		prepare()
		COL = k.COL
		WHITE_HOT = COL.Light:Lerp(WHITE, 0.6)
		Kit = k                      -- last: whoever sees Kit set sees everything ready
	end)
	kitLoading = false
	if not ok then
		retryAt = os.clock() + 5
		warnOnce("libs", "Cascade failed to initialise: " .. tostring(err))
	end
	return Kit ~= nil
end

local function kitFlag(fn, ...)
	if not fn then return false end
	local ok, v = pcall(fn, ...)
	return ok and v == true
end

local function qualityTier()
	local _, _, S = Kit.libs()
	local d = S and tonumber(S.EffectDensity) or 1
	if d < 0.6 then return 1 end
	if d < 0.9 then return 2 end
	if d < 1.1 then return 3 end
	return 4
end

local function firstPersonNow()
	local lp = Players.LocalPlayer
	if lp and lp.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
	return kitFlag(Kit.viewmodelUp)
end

-- THE LUMP FIELD, baked from cascade_bl.py build_lumps() / build_groups() (cascade3.lobe_field + the florets
-- + the scraps; random.Random(4411 / 777 / 41)), by blender_scripts/voltaic/cascade_bl.py itself run headless
-- (483 lumps: 117 big, 309 florets, 57 in 19 scrap puffs; 651 telegraph hop points). SPHERE SPACE, Blender axes
-- (z up; the world is this squashed by SQ_G in height about the belly plane). Row order = the showcase's idx.
-- LUMP_ROWS: { group (KEYS), home x, y, z, radius, value, floret (1), fragment, edge }
local DATA = {}
DATA.LUMP_ROWS = {
	{1,0.4,0.8,12.375,5.616,0.837,0,2,0.106}, {1,-3,-2.3,9.875,3.744,0.885,0,1,0.13}, {1,3.4,1.4,10.125,3.64,0.843,0,2,0.379}, {1,1.9,-3.2,14.875,2.6,0.919,0,2,0.679}, {1,-2.2,3.4,10.75,3.328,1.041,0,2,0.483}, {2,0,0,3.25,5.408,0.926,0,2,0.232},
	{2,-3.9,1.8,3.75,4.368,0.917,0,2,0.407}, {2,3.6,-2.4,3.5,4.472,1.065,0,1,0.31}, {2,1.8,3.9,4.125,4.16,0.848,0,2,0.416}, {2,-2.1,-4,4.25,4.056,0.869,0,1,0.458}, {3,0.327,-5.695,7.805,3.704,0.949,0,1,0.251}, {3,3.416,-4.568,7.805,3.704,0.899,0,1,0.107},
	{3,1.434,-2.814,6.205,2.793,0.865,0,1,0.206}, {3,3.024,-0.912,6.205,2.793,0.922,0,1,0.346}, {3,5.342,-6.695,5.323,3.258,1.026,0,2,0.113}, {3,7.265,-4.537,5.323,3.258,1.027,0,3,0.541}, {3,9.913,-4.942,3.343,3.535,0.959,0,3,0.142}, {3,10.902,-1.964,3.343,3.535,0.859,0,3,0.324},
	{3,12.236,-6.679,1.81,2.72,0.873,0,3,0.475}, {3,13.205,-4.467,1.81,2.72,0.967,0,3,0.435}, {4,12.551,-0.575,2.419,3.676,0.894,0,2,0.356}, {4,12.275,2.677,2.419,3.676,0.913,0,2,0.124}, {4,13.543,3.971,1.655,2.653,1.004,0,3,0.122}, {4,12.694,6.167,1.655,2.653,1.052,0,3,0.204},
	{4,11.136,3.891,1.512,1.927,0.99,0,2,0.07}, {4,10.457,5.46,1.512,1.927,0.916,0,2,0.134}, {4,11.928,6.959,1.77,2.661,0.82,0,1,0.599}, {4,10.567,8.889,1.77,2.661,0.836,0,2,0.348}, {4,11.996,11.356,1.94,2.498,0.999,0,1,0.069}, {4,10.367,12.86,1.94,2.498,0.978,0,1,0.362},
	{4,13.753,12.443,1.537,1.728,1,0,1,0.374}, {4,12.677,13.537,1.537,1.728,0.925,0,1,0.416}, {4,9.296,13.946,2.094,2.304,0.999,0,2,0.724}, {4,7.528,14.974,2.094,2.304,0.818,0,2,0.833}, {5,6.284,15.906,1.706,3.045,0.813,0,3,0.444}, {5,3.7,16.697,1.706,3.045,0.9,0,3,0.062},
	{5,4.654,13.657,1.49,2.112,0.901,0,2,0.845}, {5,2.844,14.145,1.49,2.112,0.96,0,2,0.708}, {5,2.886,17.758,1.626,2.383,1.054,0,3,0.168}, {5,0.782,17.974,1.626,2.383,0.826,0,3,0.472}, {5,-0.366,18.033,2.023,2.286,0.841,0,3,0.645}, {5,-2.39,17.878,2.023,2.286,0.809,0,1,0.709},
	{5,-5.075,19.442,1.899,2.232,0.932,0,1,0.347}, {5,-6.965,18.847,1.899,2.232,0.978,0,1,0.115}, {5,-7.892,20.084,1.933,2.438,0.866,0,1,0.112}, {5,-9.864,19.192,1.933,2.438,1.064,0,1,0.264}, {5,-10.002,17.79,1.439,1.771,0.913,0,2,0.294}, {5,-11.341,16.967,1.439,1.771,0.884,0,2,0.358},
	{5,-11.916,19.41,1.68,2.022,0.878,0,1,0.527}, {5,-13.408,18.411,1.68,2.022,0.895,0,1,0.723}, {5,-15.188,16.708,1.684,1.953,1.014,0,2,0.631}, {5,-16.425,15.494,1.684,1.953,0.919,0,2,0.717}, {6,4.507,3.427,7.416,3.737,0.873,0,1,0.334}, {6,1.814,5.363,7.416,3.737,0.817,0,1,0.185},
	{6,1.744,2.113,5.803,2.812,0.945,0,1,0.38}, {6,-0.693,2.65,5.803,2.812,0.809,0,1,0.527}, {6,1.867,8.005,4.04,3.417,0.852,0,1,0.541}, {6,-1.163,8.137,4.04,3.417,1.06,0,2,0.345}, {6,-2.238,9.792,2.098,3.157,1.006,0,2,0.133}, {6,-4.856,8.792,2.098,3.157,1.078,0,3,0.159},
	{6,-2.297,12.352,1.465,2.316,0.837,0,2,0.426}, {6,-4.28,11.812,1.465,2.316,0.862,0,2,0.507}, {6,-6.443,9.611,1.762,2.863,0.983,0,3,0.086}, {6,-8.386,7.973,1.762,2.863,0.923,0,3,0.248}, {7,-9.906,8.683,1.805,2.376,1.04,0,1,0.347}, {7,-11.165,6.991,1.805,2.376,0.97,0,1,0.216},
	{7,-8.688,6.901,1.538,1.718,0.924,0,1,0.282}, {7,-9.552,5.645,1.538,1.718,0.838,0,1,0.179}, {7,-11.263,5.979,2.152,2.637,0.946,0,1,0.147}, {7,-12.166,3.821,2.152,2.637,1.006,0,1,0.055}, {7,-15.059,3.001,1.597,2.144,0.901,0,2,0.17}, {7,-15.315,1.114,1.597,2.144,0.805,0,2,0.137},
	{7,-14.312,0.439,2.052,2.59,0.803,0,2,0.201}, {7,-14.198,-1.857,2.052,2.59,1.047,0,3,0.351}, {7,-15.955,-3.09,1.929,2.07,0.817,0,3,0.201}, {7,-15.504,-4.872,1.929,2.07,0.999,0,3,0.165}, {7,-14.522,-5.833,1.595,2.46,0.849,0,3,0.309}, {7,-13.569,-7.797,1.595,2.46,0.817,0,1,0.816},
	{8,-5.294,2.342,7.536,3.773,1.07,0,1,0.357}, {8,-5.705,-0.982,7.536,3.773,1.075,0,1,0.269}, {8,-2.858,0.333,5.927,2.681,1.067,0,3,0.684}, {8,-2.132,-1.933,5.927,2.681,1.045,0,3,0.553}, {8,-7.687,-1.034,3.765,3.757,1.014,0,1,0.466}, {8,-6.543,-4.166,3.765,3.757,0.968,0,3,0.116},
	{8,-7.104,-5.837,1.889,2.81,0.811,0,3,0.344}, {8,-5.274,-7.531,1.889,2.81,0.892,0,3,0.444}, {8,-9.196,-6.724,1.482,2.174,0.951,0,2,0.579}, {8,-7.928,-8.18,1.482,2.174,0.949,0,3,0.6}, {9,-5.776,-9.684,2.112,2.772,0.932,0,2,0.409}, {9,-3.537,-10.706,2.112,2.772,0.895,0,2,0.093},
	{9,-2.638,-12.134,2.108,2.526,1.02,0,1,0.221}, {9,-0.413,-12.411,2.108,2.526,1.02,0,2,0.363}, {9,0.324,-13.185,1.673,2.231,1.038,0,1,0.388}, {9,2.295,-12.988,1.673,2.231,0.921,0,2,0.714}, {2,-0.149,2.896,5.566,2.029,0.912,0,2,0.283}, {3,6.661,-7.29,8.027,1.393,0.895,0,2,0.287},
	{3,7.52,-6.401,8.027,1.393,0.955,0,2,0.332}, {6,-2.626,8.529,4.697,1.292,0.832,0,3,0.473}, {6,-3.698,8.121,4.697,1.292,1.028,0,3,0.392}, {1,-4.667,-3.421,11.207,1.38,0.932,0,1,0.234}, {3,1.116,-3.591,10.83,1.35,1.073,0,1,0.353}, {3,2.188,-3.057,10.83,1.35,1.03,0,1,0.344},
	{6,1.533,1.188,8.082,1.226,0.808,0,1,0.542}, {6,0.652,1.826,8.082,1.226,1.011,0,1,0.517}, {9,-4.544,-8.287,3.918,0.993,0.995,0,2,0.47}, {9,-3.752,-8.674,3.918,0.993,0.927,0,2,0.395}, {2,1.233,3.049,6.594,1.81,0.928,0,2,0.462}, {5,5.502,14.17,3.717,1.329,0.86,0,3,0.603},
	{5,4.387,14.553,3.717,1.329,0.912,0,3,0.495}, {8,-5.861,-0.662,6.801,1.62,0.845,0,1,0.176}, {8,-5.527,-2.06,6.801,1.62,1.043,0,3,0.437}, {2,-3.858,3.731,6.02,1.585,0.977,0,2,0.556}, {3,10.009,-1.822,5.398,1.512,1.024,0,1,0.794}, {3,10.162,-0.489,5.398,1.512,0.902,0,1,0.854},
	{6,-6.328,10.223,4.174,1.236,0.962,0,3,0.242}, {6,-7.233,9.604,4.174,1.236,0.817,0,3,0.234}, {1,4.284,-0.259,11.579,1.525,1.032,0,2,0.462}, {1,4.162,1.513,14.061,1.793,0.808,1,2,0.484}, {1,1.388,5.018,12.014,1.802,0.865,1,2,0.462}, {1,-2.9,1.115,14.267,1.895,0.821,1,1,0.505},
	{1,-3.936,1.228,12.832,1.692,0.886,1,1,0.409}, {1,1.966,4.802,12.048,1.911,0.873,1,2,0.451}, {1,0.343,4.68,12.095,2.017,0.88,1,2,0.423}, {1,-4.996,-3.897,10.152,1.471,0.89,1,1,0.305}, {1,-5.113,-0.547,11.217,1.28,0.899,1,1,0.242}, {1,-5.142,-2.643,11.592,1.224,0.825,1,1,0.233},
	{1,-4.546,-0.973,11.362,1.645,0.932,1,1,0.17}, {1,-5.201,-3.639,11.258,1.456,0.919,1,1,0.292}, {1,-4.244,-4.162,11.34,1.44,0.855,1,1,0.285}, {1,5.279,3.016,10.341,1.516,0.816,1,2,0.611}, {1,4.433,-0.934,10.543,1.554,0.837,1,2,0.543}, {1,5.752,1.262,9.489,1.531,0.854,1,2,0.669},
	{1,2.307,-4.696,15.866,0.84,0.974,1,1,0.906}, {1,1.761,-5.015,15.692,0.957,0.896,1,1,0.866}, {1,2.006,-4.691,15.989,0.854,0.941,1,1,0.891}, {1,-4.544,4.24,11.181,1.068,1.075,1,1,0.689}, {1,-1.349,5.53,10.373,1.182,1.088,1,2,0.62}, {1,-4.298,3.15,12.066,1.221,0.989,1,1,0.579},
	{1,-3.994,4.667,11.342,1.144,1.103,1,2,0.737}, {1,-1.765,5.575,11.266,1.311,0.961,1,2,0.626}, {2,3.117,2.2,1.968,2.054,0.856,1,2,0.523}, {2,-3.515,4.315,6.02,1.631,0.877,1,2,0.566}, {2,-5.55,4.592,4.237,1.764,0.914,1,2,0.716}, {2,-4.904,5.034,4.479,1.842,0.866,1,2,0.684},
	{2,-6.739,3.782,3.245,1.54,0.952,1,2,0.808}, {2,2.718,-5.772,4.33,1.757,0.99,1,1,0.375}, {2,2.283,-5.304,2.433,1.55,1.086,1,1,0.347}, {2,6.427,-0.901,4.469,1.425,0.991,1,1,0.719}, {2,6.329,-0.488,4.184,1.675,1.127,1,1,0.729}, {2,5.346,-0.268,4.791,1.468,0.991,1,1,0.647},
	{2,4.777,2.534,3.354,1.762,0.811,1,2,0.688}, {2,4.616,2.059,4.152,1.585,0.845,1,1,0.796}, {2,4.633,2.125,4.548,1.456,0.815,1,2,0.67}, {2,-0.352,-6.742,4.652,1.783,0.836,1,1,0.512}, {2,-3.944,-6.545,4.601,1.248,0.916,1,1,0.809}, {2,-0.284,-6.154,3.364,1.734,0.876,1,1,0.437},
	{2,-3.862,-5.934,5.413,1.41,0.884,1,1,0.781}, {3,-0.363,-8.49,7.74,1.505,0.875,1,1,0.495}, {3,1.382,-8.391,7.271,1.383,0.889,1,2,0.56}, {3,1.7,-7.583,8.757,1.385,0.905,1,1,0.356}, {3,-2.511,-6.234,7.76,1.464,0.987,1,1,0.517}, {3,1.254,-7.984,8.991,1.622,0.939,1,1,0.41},
	{3,2.057,-7.711,9.204,1.053,0.959,1,1,0.38}, {3,3.136,-7.008,9.312,1.235,0.947,1,2,0.531}, {3,5.896,-3.205,8.086,1.449,0.834,1,1,0.354}, {3,5.254,-4.387,9.61,1.463,0.855,1,1,0.343}, {3,5.801,-4.715,8.945,1.195,0.934,1,1,0.359}, {3,4.816,-6.407,8.666,1.104,0.828,1,2,0.393},
	{3,4.902,-0.986,6.951,0.833,0.936,1,1,0.396}, {3,4.817,-0.338,6.642,0.785,0.974,1,1,0.447}, {3,4.928,-1.175,6.923,1.2,0.852,1,1,0.384}, {3,6.511,-8.775,4.889,1.422,1.058,1,2,0.164}, {3,4.085,-8.693,5.533,1.286,1.063,1,2,0.265}, {3,5.821,-8.705,6.452,1.345,1.051,1,2,0.189},
	{3,4.477,-8.41,6.703,1.423,0.967,1,2,0.257}, {3,5.053,-9.131,6.046,1.302,0.988,1,2,0.236}, {3,3.686,-7.915,4.591,1.05,0.99,1,2,0.284}, {3,7.64,-2.708,6.482,0.919,0.996,1,1,0.533}, {3,9.186,-5.716,6.66,0.915,1.018,1,3,0.533}, {3,9.294,-4.801,6.892,1.092,0.98,1,3,0.521},
	{3,7.52,-2.084,6.327,1.331,1.039,1,1,0.545}, {3,8.284,-6.606,6.375,0.95,1.062,1,2,0.26}, {3,8.736,-7.251,3.305,1.417,0.989,1,2,0.35}, {3,12.369,-6.031,4.119,1.177,0.99,1,3,0.363}, {3,10.773,-6.644,5.122,1.113,0.93,1,3,0.41}, {3,8.905,-7.564,3.148,1.45,0.971,1,2,0.375},
	{3,11.979,-5.06,4.57,1.431,0.935,1,3,0.271}, {3,12.294,-5.296,3.996,1.11,0.9,1,3,0.288}, {3,12.418,-3.042,5.012,1.359,0.832,1,3,0.373}, {3,13.594,-2.521,3.835,1.371,0.855,1,3,0.486}, {3,12.568,-3.097,5.25,1.336,0.888,1,3,0.404}, {3,12.843,-2.061,5.181,1.012,0.879,1,3,0.499},
	{3,12.241,-8.566,2.865,0.911,0.814,1,2,0.71}, {3,10.985,-8.285,2.649,1.126,0.911,1,2,0.596}, {3,13.336,-8.466,1.401,1.142,0.884,1,2,0.879}, {3,11.497,-7.893,3.168,1.102,0.898,1,2,0.615}, {3,10.907,-7.861,1.397,1.031,0.837,1,2,0.659}, {3,11.03,-8.356,1.984,1.141,0.836,1,2,0.638},
	{3,14.918,-3.289,1.788,0.972,0.967,1,3,0.664}, {3,14.437,-5.329,3.193,1.087,0.913,1,3,0.56}, {3,14.879,-5.793,2.205,1.046,0.985,1,3,0.663}, {3,14.921,-5.716,1.323,0.877,0.892,1,3,0.709}, {3,14.463,-5.913,1.616,1.152,0.986,1,3,0.646}, {3,15.015,-5.007,2.388,0.839,0.921,1,3,0.647},
	{4,15.317,0.37,2.595,1.293,0.923,1,3,0.579}, {4,15.345,-0.218,1.802,1.468,0.904,1,2,0.423}, {4,14.518,0.684,3.398,1.261,0.942,1,2,0.343}, {4,14.46,-2.567,3.527,1.312,0.899,1,2,0.543}, {4,14.723,-2.147,2.356,1.07,0.826,1,2,0.515}, {4,14.623,3.934,3.677,1.241,0.88,1,3,0.246},
	{4,13.559,4.652,3.799,1.584,0.849,1,3,0.203}, {4,13.953,1.756,4.039,1.487,0.867,1,2,0.279}, {4,14.496,1.55,3.832,1.399,0.87,1,3,0.459}, {4,12.539,4.552,4.005,1.326,0.957,1,2,0.144}, {4,14.604,2.934,3.207,1.282,0.897,1,3,0.289}, {4,14.611,5.643,2.5,0.999,0.977,1,3,0.155},
	{4,15.327,3.525,2.683,1.167,0.93,1,3,0.266}, {4,15.48,4.293,2.32,1.089,1.018,1,3,0.231}, {4,15.245,3.669,1.079,0.875,1.033,1,3,0.27}, {4,15.34,3.308,1.99,1.155,1.021,1,3,0.276}, {4,13.762,7.278,2.806,1.138,1.111,1,3,0.303}, {4,14.363,7.266,2.362,0.799,0.994,1,3,0.303},
	{4,13.43,8.078,1.422,0.977,1.111,1,3,0.398}, {4,14.476,6.904,2.304,1.049,1.067,1,3,0.266}, {4,9.475,6.284,2.243,0.722,0.944,1,2,0.214}, {4,9.393,6.245,1.471,0.648,0.958,1,2,0.224}, {4,13.658,7.857,1.991,1.157,0.853,1,3,0.361}, {4,13.638,7.609,1.243,1.055,0.82,1,3,0.348},
	{4,13.05,8.166,2.438,0.917,0.768,1,3,0.406}, {4,9.14,9.928,2.486,0.955,0.776,1,2,0.45}, {4,12.558,9.384,2.504,0.968,0.869,1,1,0.276}, {4,9.162,10.33,1.022,0.796,0.829,1,2,0.485}, {4,8.838,10.095,1.987,0.865,0.797,1,2,0.47}, {4,12.63,12.495,2.995,1.048,0.927,1,1,0.313},
	{4,13.91,11.2,2.302,0.77,1.039,1,1,0.325}, {4,13.534,11.589,2.765,0.892,0.978,1,1,0.307}, {4,11.362,14.483,1.518,0.925,0.93,1,1,0.541}, {4,11.371,14.52,1.557,0.878,0.901,1,1,0.545}, {4,11.681,13.325,3.024,0.884,0.985,1,1,0.399}, {4,14.924,12.375,1.597,0.668,0.944,1,3,0.92},
	{4,14.37,13.47,2.151,0.56,1.036,1,1,0.543}, {4,14.343,11.765,2.379,0.58,1.027,1,1,0.408}, {4,13.387,14.278,2.481,0.637,0.968,1,1,0.563}, {4,12.453,14.695,1.792,0.627,0.902,1,1,0.574}, {4,13.936,13.851,1.905,0.667,0.942,1,1,0.543}, {4,10.67,14.966,2.797,0.779,1.058,1,1,0.645},
	{4,9.964,15.403,1.614,0.86,1.017,1,1,0.729}, {4,10.146,14.943,3.137,0.718,1.017,1,1,0.68}, {4,8.816,15.873,1.803,0.873,0.796,1,2,0.868}, {4,8.554,16.099,2.775,0.675,0.799,1,2,0.889}, {5,7.734,17.655,0.963,1.09,0.854,1,3,0.652}, {5,6.181,18.325,2.236,0.877,0.815,1,3,0.439},
	{5,6.364,18.013,3.027,1.104,0.851,1,3,0.478}, {5,7.542,16.948,3.238,1.251,0.818,1,3,0.637}, {5,7.357,17.657,2.376,1.213,0.796,1,3,0.584}, {5,4.403,18.722,1.121,1.005,0.855,1,3,0.305}, {5,2.069,16.705,3.197,1.041,0.909,1,3,0.328}, {5,4.635,18.601,2.437,1.085,0.894,1,3,0.295},
	{5,3.74,19.093,1.842,1.262,0.844,1,3,0.316}, {5,5.601,12.561,2.243,0.719,0.915,1,2,0.93}, {5,5.963,12.683,1.978,0.619,0.866,1,2,0.954}, {5,1.419,14.349,1.773,0.795,0.945,1,2,0.602}, {5,1.383,14.062,1.143,0.749,1.006,1,2,0.604}, {5,1.6,15.065,2.148,0.708,0.934,1,2,0.611},
	{5,3.09,19.598,2.245,0.902,1.048,1,3,0.408}, {5,3.57,19.298,1.544,1.04,1.028,1,3,0.351}, {5,2.801,19.145,2.608,0.819,1.016,1,3,0.369}, {5,0.89,19.598,1.714,0.882,0.825,1,3,0.585}, {5,1.668,19.627,1.169,1.029,0.795,1,3,0.517}, {5,-1.199,18.894,3.027,0.768,0.802,1,3,0.828},
	{5,-1.221,18.983,3,1.004,0.789,1,1,0.849}, {5,-0.919,19.621,1.674,0.811,0.778,1,1,0.877}, {5,-2.294,19.285,2.575,0.652,0.83,1,1,0.705}, {5,-3.929,17.23,1.948,0.863,0.794,1,2,0.238}, {5,-4.362,20.88,1.8,0.814,0.97,1,1,0.486}, {5,-3.671,19.746,2.568,0.975,0.976,1,1,0.536},
	{5,-3.564,20.074,2.019,0.82,0.916,1,1,0.549}, {5,-8.277,21.817,1.367,0.852,0.8,1,1,0.344}, {5,-6.554,21.189,2.482,0.866,0.833,1,1,0.306}, {5,-7.82,21.491,3.157,0.741,0.872,1,1,0.331}, {5,-10.505,20.886,1.952,0.95,0.987,1,1,0.406}, {5,-10.92,20.759,1.371,0.872,1.125,1,1,0.45},
	{5,-12.084,15.842,1.351,0.707,0.92,1,2,0.398}, {5,-12.377,16.26,1.923,0.749,0.908,1,2,0.423}, {5,-12.058,20.849,1.509,0.827,0.898,1,1,0.584}, {5,-12.672,20.796,2.128,0.812,0.864,1,1,0.654}, {5,-14.416,18.325,2.558,0.635,0.889,1,2,0.608}, {5,-14.543,18.305,2.608,0.753,0.877,1,2,0.617},
	{5,-13.652,19.86,1.163,0.773,0.899,1,1,0.757}, {5,-15.586,18.077,1.984,0.731,0.998,1,2,0.681}, {5,-16.629,17.151,2.004,0.832,1.032,1,2,0.741}, {5,-15.228,17.838,2.361,0.734,0.957,1,2,0.653}, {5,-17.169,14.842,2.641,0.591,0.952,1,2,0.777}, {5,-16.774,16.541,2.444,0.811,0.895,1,2,0.748},
	{5,-17.842,15.37,2.2,0.813,0.925,1,2,0.822}, {6,6.196,5.793,6.838,1.585,0.892,1,1,0.496}, {6,6.133,0.877,7.147,1.528,0.849,1,1,0.701}, {6,4.813,6.114,6.865,1.146,0.811,1,1,0.345}, {6,7.182,3.379,6.735,1.554,0.924,1,1,0.633}, {6,5.051,5.869,8.704,1.313,0.845,1,1,0.464},
	{6,6.867,2.754,8.388,1.496,0.905,1,1,0.675}, {6,2.015,7.874,7.783,1.158,0.835,1,1,0.455}, {6,4.053,6.585,9.042,1.531,0.825,1,1,0.461}, {6,-0.711,5.9,7.653,1.05,0.819,1,3,0.889}, {6,-0.531,6.669,7.843,1.165,0.86,1,1,0.521}, {6,-0.617,5.923,8.282,1.195,0.768,1,1,0.516},
	{6,3.551,10.091,3.473,1.397,0.866,1,1,0.815}, {6,4.593,7.418,4.298,1.095,0.817,1,1,0.52}, {6,0.818,10.367,4.75,1.033,0.87,1,2,0.502}, {6,0.802,10.217,5.16,1.054,0.808,1,2,0.536}, {6,4.307,8.427,3.9,1.499,0.841,1,1,0.63}, {6,3.01,9.871,4.727,1.362,0.894,1,2,0.793},
	{6,-2.542,10.14,5.379,1.28,0.99,1,2,0.393}, {6,-0.569,10.599,4.134,1.014,1.122,1,2,0.292}, {6,-0.054,10.403,5.098,1.051,1.123,1,2,0.441}, {6,-0.81,11.514,2.263,1.3,0.951,1,2,0.301}, {6,-2.657,11.641,3.414,1.089,1.03,1,2,0.292}, {6,-2.079,11.485,3.411,1.043,0.964,1,2,0.247},
	{6,-0.3,11.048,1.604,0.957,0.987,1,2,0.35}, {6,-1.628,12.041,3.128,0.91,1.023,1,2,0.32}, {6,-5.984,10.977,2.702,1.357,1.02,1,3,0.22}, {6,-6.148,7.166,3.342,1.306,1.122,1,3,0.225}, {6,-6.229,7.469,3.745,1.039,1.118,1,3,0.225}, {6,-0.74,13.057,1.457,0.695,0.807,1,2,0.545},
	{6,-1.139,13.779,1.277,0.974,0.819,1,2,0.638}, {6,-3.258,13.54,1.883,0.721,0.883,1,2,0.601}, {6,-4.688,13.177,2.405,0.807,0.817,1,2,0.651}, {6,-4.217,13.431,2.133,0.966,0.843,1,2,0.644}, {6,-5.615,13.031,1.896,0.954,0.876,1,2,0.748}, {6,-7.285,11.741,2.272,1.131,0.931,1,3,0.31},
	{6,-8.106,10.421,2.556,1.129,0.933,1,3,0.244}, {6,-6.966,11.521,1.092,1.076,1.039,1,3,0.304}, {6,-6.45,11.561,2.346,0.944,0.994,1,3,0.274}, {6,-6.493,11.818,2.344,0.866,0.945,1,3,0.302}, {6,-7.706,10.52,3.091,1.015,0.966,1,3,0.236}, {6,-8.802,10.172,1.417,1.027,0.908,1,3,0.304},
	{6,-9.212,10.013,2.551,0.933,0.97,1,3,0.326}, {6,-8.9,9.611,2.951,0.819,0.867,1,3,0.289}, {6,-8.974,9.874,2.042,1.058,0.951,1,3,0.296}, {7,-9.708,9.925,2.778,0.716,0.969,1,1,0.437}, {7,-9.092,10.316,1.266,0.951,1.08,1,1,0.474}, {7,-11.494,9.205,2.698,0.832,1.004,1,1,0.371},
	{7,-12.046,8.533,1.976,0.854,0.919,1,1,0.324}, {7,-12.432,7.96,1.327,0.716,1.001,1,1,0.293}, {7,-12.659,8.084,1.954,0.762,0.973,1,2,0.896}, {7,-11.891,7.495,3.057,1.059,0.956,1,1,0.264}, {7,-12.924,6.369,3.158,1.056,0.934,1,2,0.684}, {7,-13.26,6.182,1.906,0.773,0.964,1,2,0.624},
	{7,-13.446,5.201,1.896,0.981,0.958,1,2,0.489}, {7,-13.972,4.229,2.998,0.973,1.015,1,2,0.37}, {7,-11.887,2.158,3.13,0.876,0.987,1,1,0.147}, {7,-13.804,4.468,2.399,1.034,0.962,1,2,0.384}, {7,-13.048,2.645,3.576,0.917,1.032,1,1,0.181}, {7,-13.843,4.598,2.745,0.865,0.94,1,2,0.409},
	{7,-16.115,3.959,1.524,0.703,0.902,1,2,0.35}, {7,-16.13,3.392,2.643,0.919,0.897,1,2,0.301}, {7,-16.201,-0.202,1.025,0.603,0.853,1,2,0.367}, {7,-16.81,1.469,1.701,0.788,0.839,1,2,0.291}, {7,-16.398,0.765,2.551,0.876,0.745,1,2,0.285}, {7,-15.785,1.519,2.677,0.992,0.76,1,2,0.182},
	{7,-15.665,-1.904,3.257,0.935,1.047,1,3,0.395}, {7,-15.567,-0.869,2.957,0.975,1.001,1,3,0.515}, {7,-17.145,-2.308,1.924,0.834,0.822,1,3,0.422}, {7,-16.373,-1.564,1.917,0.793,0.759,1,3,0.43}, {7,-16.695,-1.99,2.294,0.855,0.819,1,3,0.409}, {7,-17.154,-5.105,1.84,0.801,1.037,1,3,0.383},
	{7,-17.031,-5.262,2.316,0.617,0.925,1,3,0.384}, {7,-16.41,-5.729,2.77,0.676,1.039,1,3,0.38}, {7,-16.382,-5.953,1.584,1.081,0.823,1,3,0.385}, {7,-15.02,-7.049,2.843,0.883,0.783,1,3,0.506}, {7,-16.011,-6.659,2.37,0.767,0.886,1,3,0.459}, {7,-15.177,-8.404,1.654,0.886,0.794,1,3,0.699},
	{7,-14.628,-9.348,1.736,0.973,0.862,1,3,0.848}, {7,-13.768,-9.472,2.094,0.999,0.866,1,1,0.931}, {8,-7.594,2.089,9.462,1.202,1.087,1,1,0.523}, {8,-6.989,4.169,7.769,1.32,1.006,1,1,0.577}, {8,-7.577,1.471,9.133,1.416,0.992,1,1,0.447}, {8,-5.488,5.358,7.383,1.537,1.094,1,1,0.732},
	{8,-7.974,2.896,6.82,1.604,1.023,1,1,0.425}, {8,-3.314,4.574,7.004,1.162,1.055,1,1,0.745}, {8,-7.593,-2.819,7.574,1.202,1.058,1,2,0.667}, {8,-6.341,-2.985,9.149,1.337,1.073,1,3,0.646}, {8,-8.327,-1.397,8.003,1.258,1.053,1,2,0.797}, {8,-8.083,-0.423,8.926,1.565,1.113,1,1,0.444},
	{8,-8.709,-1.507,7.075,1.362,1.018,1,2,0.66}, {8,-6.26,-3.509,7.522,1.643,1.01,1,3,0.446}, {8,-8.071,1.778,3.758,1.117,0.961,1,1,0.489}, {8,-9.468,0.08,5.549,1.444,1.002,1,1,0.455}, {8,-10.168,-2.325,3.862,1.265,1.066,1,2,0.337}, {8,-9.99,0.536,4.114,1.319,0.95,1,1,0.607},
	{8,-10.01,-0.018,3.047,1.634,1.074,1,2,0.695}, {8,-9.394,-1.943,5.426,1.628,1.057,1,2,0.427}, {8,-6.72,-6.063,5.379,1.58,0.947,1,3,0.297}, {8,-9.086,-4.416,3.872,1.153,0.92,1,2,0.048}, {8,-8.245,-6.589,4.089,1.12,0.944,1,3,0.409}, {8,-8.439,-5.781,4.51,1.414,0.925,1,2,0.301},
	{8,-8.466,-5.824,5.089,1.558,0.91,1,2,0.344}, {8,-7.364,-7.215,3.243,0.983,0.801,1,3,0.403}, {8,-8.512,-6.825,3.357,0.997,0.845,1,3,0.455}, {8,-3.489,-7.986,3.015,1.046,0.865,1,3,0.504}, {8,-10.464,-6.463,2.407,0.665,0.978,1,2,0.501}, {8,-10.058,-7.912,1.333,0.826,0.999,1,2,0.758},
	{8,-10.365,-7.623,2.073,0.873,0.933,1,2,0.671}, {8,-8.996,-9.248,1.49,0.93,0.875,1,3,0.757}, {8,-9.392,-8.678,1.57,0.785,0.982,1,2,0.829}, {9,-5.676,-11.567,2.864,1.059,0.936,1,2,0.373}, {9,-7.458,-9.526,3.329,1.214,0.868,1,2,0.634}, {9,-5.854,-11.459,3.41,1.118,0.933,1,2,0.414},
	{9,-7.936,-9.982,2.735,1.057,0.95,1,2,0.664}, {9,-7.122,-11.087,1.63,0.931,0.977,1,2,0.546}, {9,-6.381,-11.642,1.502,0.891,0.887,1,2,0.461}, {9,-4.669,-12.126,1.807,1.186,0.902,1,1,0.584}, {9,-4.016,-12.202,3.354,0.888,0.932,1,1,0.524}, {9,-1.853,-10.33,3.348,0.826,0.888,1,2,0.223},
	{9,-5.208,-11.806,2.289,1.145,0.839,1,1,0.698}, {9,-4.205,-12.435,2.494,1.171,0.912,1,1,0.495}, {9,-3.321,-13.691,1.639,0.896,0.983,1,1,0.369}, {9,-0.563,-14.285,2.401,0.937,1.05,1,1,0.362}, {9,0.151,-13.688,3.393,0.737,1.043,1,1,0.464}, {9,1.092,-11.685,2.764,0.816,1.055,1,2,0.524},
	{9,1.229,-14.505,2.208,0.89,1.028,1,1,0.638}, {9,0.479,-14.803,2.51,0.914,1.021,1,1,0.566}, {9,-0.777,-14.228,1.456,0.823,1.093,1,1,0.341}, {9,1.899,-14.461,2.22,0.965,0.932,1,1,0.746}, {9,3.923,-12.227,1.999,0.845,0.944,1,2,0.888}, {9,2.31,-14.654,1.325,0.842,0.946,1,1,0.841},
}
-- SCRAP_ROWS: { 1 = curling in / 2 = peeling off, its scrap, radius, value, offset x, y, z } (three lumps a puff)
DATA.SCRAP_ROWS = {
	{1,1,1.273,0.829,0,0,0}, {1,1,0.84,1.078,-0.205,0.171,0.446}, {1,1,0.739,0.8,-0.037,-0.281,-0.442}, {1,2,1.149,1.043,0,0,0}, {1,2,0.758,0.939,0.182,-0.528,0.265}, {1,2,0.666,0.926,0.394,-0.568,-0.103},
	{1,3,1.432,0.809,0,0,0}, {1,3,0.945,0.964,0.216,-0.1,0.513}, {1,3,0.83,0.981,-0.123,0.626,0.37}, {1,4,1.139,0.971,0,0,0}, {1,4,0.752,1.048,-0.358,0.54,-0.168}, {1,4,0.661,0.88,-0.35,-0.593,-0.095},
	{1,5,1.137,0.879,0,0,0}, {1,5,0.751,0.919,0.328,-0.382,-0.296}, {1,5,0.66,0.956,-0.195,0.439,0.31}, {1,6,0.978,0.905,0,0,0}, {1,6,0.646,0.856,0.3,-0.33,-0.247}, {1,6,0.567,0.84,0.108,-0.579,-0.087},
	{1,7,1.098,1.059,0,0,0}, {1,7,0.725,0.985,-0.41,-0.497,-0.132}, {1,7,0.637,1.06,-0.022,0.457,-0.303}, {1,8,1.416,0.907,0,0,0}, {1,8,0.935,0.933,0.004,0.778,-0.244}, {1,8,0.822,0.92,0.378,0.168,0.465},
	{1,9,1.349,0.813,0,0,0}, {1,9,0.89,0.844,0.196,0.612,0.321}, {1,9,0.782,0.876,-0.673,-0.148,-0.284}, {1,10,1.11,0.879,0,0,0}, {1,10,0.733,1.076,0.28,0.304,-0.33}, {1,10,0.644,0.969,0.506,0.111,-0.272},
	{1,11,1.454,1.002,0,0,0}, {1,11,0.96,0.887,0.869,0.055,-0.139}, {1,11,0.843,0.985,-0.744,0.408,-0.182}, {1,12,1.128,0.887,0,0,0}, {1,12,0.745,1.071,-0.037,-0.017,-0.419}, {1,12,0.654,1.035,0.512,-0.323,-0.211},
	{2,1,0.915,0.949,0,0,0}, {2,1,0.604,0.825,0.032,-0.334,0.275}, {2,1,0.531,0.987,0.378,-0.377,0.116}, {2,2,0.877,1.056,0,0,0}, {2,2,0.579,1.012,0.215,0.209,0.272}, {2,2,0.509,1.007,-0.143,-0.262,0.272},
	{2,3,0.637,0.837,0,0,0}, {2,3,0.42,0.837,0.067,-0.051,0.232}, {2,3,0.369,1.019,0.128,-0.264,0.159}, {2,4,0.821,0.841,0,0,0}, {2,4,0.542,0.905,-0.09,-0.479,-0.087}, {2,4,0.476,0.919,0.408,-0.201,-0.137},
	{2,5,0.608,0.995,0,0,0}, {2,5,0.402,0.853,-0.037,-0.129,-0.211}, {2,5,0.353,0.868,0.26,0.217,0.1}, {2,6,0.881,1.008,0,0,0}, {2,6,0.581,1.078,-0.481,0.111,-0.14}, {2,6,0.511,1.047,0.206,0.505,-0.012},
	{2,7,0.666,0.847,0,0,0}, {2,7,0.439,0.996,0.168,0.248,-0.17}, {2,7,0.386,0.906,0.392,0.122,-0.024},
}
-- SCRAP_IN: { delay, fly, from radius, from angle, from height, sweep, to radius, to height }
DATA.SCRAP_IN = {
	{0.0367,0.2756,37.372,1.6954,9.3614,3.1028,11.6135,6.5613},
	{0.0923,0.263,35.3477,3.963,14.7085,2.5747,7.628,6.0563},
	{0.0703,0.2575,41.2889,0.5558,7.7799,3.3418,10.7278,4.681},
	{0.0017,0.2959,46.0672,4.0355,9.8564,2.9845,9.4888,4.0299},
	{0.1336,0.2808,38.6803,4.2631,13.0366,2.7882,11.5439,6.1688},
	{0.091,0.2469,49.88,0.4497,6.9741,3.3145,10.0099,3.0059},
	{0.0685,0.2996,45.6299,4.2499,6.6113,3.3771,9.0768,3.2532},
	{0.0308,0.2798,47.798,3.4381,9.2724,2.4446,11.2808,6.5365},
	{0.0035,0.2595,40.6177,1.0158,10.043,2.6738,9.2193,3.7526},
	{0.1132,0.2715,37.0159,5.2391,7.6109,3.154,11.0461,4.8676},
	{0.0773,0.266,44.1282,4.2106,10.521,2.7681,8.7902,3.0402},
	{0.101,0.2935,31.5122,4.5983,15.2158,2.326,8.5266,3.0093},
}
-- SCRAP_OUT: { start, duration, from x, y, z, travel x, y, z }
DATA.SCRAP_OUT = {
	{1.9833,1.3361,5.062,11.277,1.217,4.281,8.495,4.568},
	{1.9225,1.4145,-9.252,7.858,5.083,-8.059,6.654,5.471},
	{2.3831,1.3958,15.102,-0.841,6.753,7.061,-0.482,7.886},
	{2.1806,1.2902,3.035,7.566,6.097,3.848,6.912,4.208},
	{2.1298,1.2809,-13.175,-5.73,3.719,-9.5,-3.852,4.619},
	{2.4459,1.4779,2.9,8.794,5.247,2.809,8.628,6.652},
	{1.9057,1.4719,-0.516,12.363,6.899,-0.31,8.923,7.619},
}
-- GROUP_ROWS (KEYS order): { home x, y, z, delay, sweep, k0, rise, s0, tumble axis x, y, z, tumble, curl, side, fly,
--   Subs = the break-up's fragments { centre x, y, z, push dir x, y, z, push studs, delay, spin } }
DATA.GROUP_ROWS = {
	{-0.02,0.639,11.673,0.052,1.8282,2.4637,5.3013,0.5097,-0.4,0.37,0.839,1.1611,0.3375,-1,0.3149, Subs = {{-3.362,-2.446,-0.817,-0.753,-0.003,0.658,7.92,0.07,-0.242}, {0.922,0.671,0.224,0.547,0.519,0.657,5.127,0.162,-0.427}}}, -- Crown
	{0.051,-0.024,3.78,0.05,1.0222,1.9184,3.8615,0.5351,0.625,-0.498,0.601,0.8422,-0.2801,1,0.3388, Subs = {{1.313,-3.195,0.112,0.165,-0.86,0.484,4.584,0.147,-0.093}, {-0.697,1.696,-0.059,-0.723,0.652,-0.228,4.087,0.03,-0.042}}}, -- Core
	{6.483,-4.74,5.454,0.0792,1.7861,2.1862,3.8329,0.4099,-0.136,-0.99,-0.041,0.7317,0.435,1,0.277, Subs = {{-4.057,0.535,2.021,0.397,-0.859,-0.323,7.579,0.091,0.21}, {-0.303,-2.607,-0.086,0.912,-0.378,0.16,4.882,0.08,-0.04}, {4.14,0.499,-1.969,0.724,-0.41,-0.555,6.674,0.119,0.429}}}, -- ArmA1
	{12.077,5.858,2.163,0.056,1.9452,2.1537,5.6462,0.4121,0.006,0.883,-0.469,1.1417,-0.3434,1,0.3327, Subs = {{-0.267,5.08,-0.28,0.228,0.964,-0.137,6.268,0.034,-0.171}, {-0.475,-1.619,0.123,0.713,0.469,0.521,6.852,0.122,-0.002}, {1.579,-0.998,-0.036,0.875,0.461,0.15,4.119,0.13,0.442}}}, -- ArmA2
	{-2.337,17.5,1.83,0.0655,1.9404,1.8861,6.0588,0.4893,-0.617,-0.73,-0.293,0.9816,0.218,-1,0.2884, Subs = {{-5.454,1.713,0.074,-0.573,0.669,0.474,4.922,0.027,0.207}, {-4.341,-1.936,-0.222,-0.755,0.65,-0.085,4.39,0.103,-0.059}, {6.011,-0.441,0.042,0.677,0.713,0.182,4.988,0.104,0.069}}}, -- ArmA3
	{-0.633,7.096,4.542,0.0482,1.9086,2.5565,5.4753,0.4748,-0.423,0.422,0.802,1.4347,0.0957,-1,0.3305, Subs = {{3.249,-2.322,1.892,0.36,0.743,0.565,4.594,0.144,0.031}, {-1.252,2.864,-1.663,0.341,0.911,0.23,6.908,0.085,-0.314}, {-5.702,1.884,-2.281,-0.868,0.422,0.262,5.958,0.125,0.221}}}, -- ArmB1
	{-13.225,1.107,1.927,0.0723,2.024,2.3267,7.2821,0.4159,0.131,0.329,-0.935,1.011,-0.5198,-1,0.286, Subs = {{1.823,2.753,-0.003,-0.897,0.032,-0.441,7.18,0.019,-0.129}, {-1.496,0.741,0.009,-0.912,0.41,0.018,7.371,0.069,0.403}, {-1.774,-5.053,-0.002,-0.749,-0.443,0.492,7.61,0.214,0.378}}}, -- ArmB2
	{-6.317,-2.044,5.128,0.0248,2.0199,2.7356,5.0752,0.4252,-0.248,-0.648,0.721,1.4197,-0.0331,-1,0.3487, Subs = {{-0.087,2.429,1.296,-0.973,-0.153,0.175,6.129,0.06,0.192}, {-2.807,-2.091,-1.163,-0.525,-0.658,0.54,4.773,0.146,-0.219}, {0.73,-2.323,-1.229,-0.823,-0.439,0.36,4.37,0.186,0.495}}}, -- ArmC1
	{-2.499,-11.6,2.118,0.0011,1.7775,2.0804,8.5744,0.4622,-0.183,0.503,-0.845,1.4554,-0.0598,-1,0.3661, Subs = {{0.848,-1.154,-0.102,-0.588,-0.8,-0.116,4.085,0.109,0.19}, {-0.402,0.547,0.048,-0.47,-0.768,-0.436,7.382,0.026,-0.095}}}, -- ArmC2
}
-- EXT_ROWS: the telegraph's hop points (cascade_bl.ext_points): { lump, dir x, y, z } flattened
DATA.EXT_ROWS = {
	1,0.678,-0.356,0.643, 1,-0.294,0.815,0.5, 1,-0.36,-0.862,0.357, 1,0.886,0.41,0.214, 1,-0.951,0.303,0.071, 1,0.496,-0.865,-0.071, 2,-0.269,-0.939,0.214, 3,0.666,0.378,0.643,
	3,0.134,0.968,0.214, 4,-0.713,-0.281,0.643, 4,0.808,-0.31,0.5, 4,-0.269,-0.939,0.214, 4,0.582,-0.785,-0.214, 4,-0.648,-0.575,-0.5, 5,-0.294,0.815,0.5, 5,0.214,0.953,-0.214,
	6,0.115,0.608,-0.786, 6,-0.297,-0.222,-0.929, 7,-0.834,0.235,-0.5, 7,0.115,0.608,-0.786, 7,-0.297,-0.222,-0.929, 8,0.834,0.42,-0.357, 8,0.403,-0.651,-0.643, 8,0.115,0.608,-0.786,
	8,-0.297,-0.222,-0.929, 9,0.85,0.521,0.071, 9,0.766,-0.013,-0.643, 9,-0.449,0.425,-0.786, 10,-0.269,-0.939,0.214, 10,0.026,-0.37,-0.929, 11,-0.36,-0.862,0.357, 11,-0.766,-0.534,-0.357,
	12,0.067,-0.763,0.643, 12,0.527,0.687,0.5, 15,0.898,-0.434,0.071, 15,-0.346,-0.913,-0.214, 15,0.403,-0.651,-0.643, 15,-0.297,-0.222,-0.929, 16,0.808,-0.31,0.5, 17,0.12,-0.99,0.071,
	17,-0.33,-0.691,-0.643, 17,-0.348,0.13,-0.929, 18,-0.863,0.356,-0.357, 18,-0.535,-0.31,-0.786, 19,0.808,-0.31,0.5, 19,-0.269,-0.939,0.214, 19,-0.648,-0.575,-0.5, 19,0.766,-0.013,-0.643,
	19,-0.449,0.425,-0.786, 19,0.026,-0.37,-0.929, 20,0.886,0.41,0.214, 20,0.858,-0.115,-0.5, 20,0.263,0.262,-0.929, 21,0.666,0.378,0.643, 21,-0.76,-0.096,-0.643, 21,0.505,-0.358,-0.786,
	21,-0.078,0.363,-0.929, 22,0.666,0.378,0.643, 22,-0.844,0.193,0.5, 22,0.996,-0.05,-0.071, 22,-0.76,-0.096,-0.643, 22,0.505,-0.358,-0.786, 22,-0.078,0.363,-0.929, 23,0.858,-0.115,-0.5,
	23,0.263,0.262,-0.929, 24,0.858,-0.115,-0.5, 24,0.263,0.262,-0.929, 26,-0.853,-0.151,-0.5, 27,0.263,0.262,-0.929, 28,-0.36,-0.862,0.357, 28,-0.951,0.303,0.071, 28,-0.766,-0.534,-0.357,
	28,-0.491,0.588,-0.643, 28,-0.028,-0.618,-0.786, 28,0.263,0.262,-0.929, 29,0.678,-0.356,0.643, 29,0.496,-0.865,-0.071, 29,0.858,-0.115,-0.5, 29,0.263,0.262,-0.929, 30,-0.149,-0.751,0.643,
	30,0.698,0.513,0.5, 30,-0.689,-0.722,-0.071, 30,0.424,0.638,-0.643, 30,-0.601,-0.148,-0.786, 30,0.326,-0.178,-0.929, 31,0.55,-0.669,0.5, 31,0.866,0.029,-0.5, 32,-0.334,0.928,-0.167,
	32,0.502,0.232,-0.833, 33,0.666,0.378,0.643, 33,0.134,0.968,0.214, 33,-0.768,-0.636,0.071, 33,0.56,0.66,-0.5, 33,-0.078,0.363,-0.929, 34,0.666,0.378,0.643, 34,0.035,-0.933,-0.357,
	35,0.12,-0.99,0.071, 35,0.58,0.811,-0.071, 35,-0.253,0.828,-0.5, 35,0.574,0.232,-0.786, 35,-0.348,0.13,-0.929, 36,0.424,0.638,-0.643, 36,-0.601,-0.148,-0.786, 36,0.326,-0.178,-0.929,
	37,0.035,-0.933,-0.357, 37,0.505,-0.358,-0.786, 37,-0.078,0.363,-0.929, 38,-0.844,0.193,0.5, 38,-0.768,-0.636,0.071, 38,0.035,-0.933,-0.357, 38,-0.76,-0.096,-0.643, 38,-0.078,0.363,-0.929,
	39,0.56,0.66,-0.5, 39,-0.078,0.363,-0.929, 40,0.134,0.968,0.214, 40,0.035,-0.933,-0.357, 40,-0.078,0.363,-0.929, 41,0.041,0.765,0.643, 41,0.12,-0.99,0.071, 41,-0.253,0.828,-0.5,
	41,-0.33,-0.691,-0.643, 41,-0.348,0.13,-0.929, 42,0.041,0.765,0.643, 42,-0.619,-0.606,0.5, 42,0.12,-0.99,0.071, 42,-0.956,-0.202,-0.214, 42,-0.253,0.828,-0.5, 42,-0.33,-0.691,-0.643,
	42,-0.348,0.13,-0.929, 43,-0.149,-0.751,0.643, 43,0.698,0.513,0.5, 43,0.021,0.997,0.071, 43,0.133,-0.856,-0.5, 43,0.424,0.638,-0.643, 43,0.326,-0.178,-0.929, 44,-0.36,-0.862,0.357,
	44,0.496,-0.865,-0.071, 44,-0.028,-0.618,-0.786, 44,0.263,0.262,-0.929, 45,-0.417,0.836,0.357, 45,0.097,0.929,-0.357, 45,-0.449,0.425,-0.786, 45,0.026,-0.37,-0.929, 46,0.041,0.765,0.643,
	46,-0.619,-0.606,0.5, 46,-0.253,0.828,-0.5, 46,-0.348,0.13,-0.929, 47,0.086,-0.982,0.167, 47,0.466,-0.297,-0.833, 48,-0.917,-0.361,0.167, 48,-0.152,-0.531,-0.833, 49,0.021,0.997,0.071,
	49,-0.729,0.583,-0.357, 49,0.424,0.638,-0.643, 49,0.326,-0.178,-0.929, 50,-0.844,0.193,0.5, 50,-0.686,0.695,-0.214, 50,0.035,-0.933,-0.357, 50,-0.76,-0.096,-0.643, 50,0.505,-0.358,-0.786,
	50,-0.078,0.363,-0.929, 51,0.873,-0.458,0.167, 51,-0.334,0.928,-0.167, 51,0.502,0.232,-0.833, 52,0.55,-0.669,0.5, 52,-0.704,-0.69,-0.167, 52,-0.42,0.359,-0.833, 53,0.527,0.687,0.5,
	53,0.824,-0.524,0.214, 53,0.917,0.335,-0.214, 53,0.229,0.731,-0.643, 54,-0.294,0.815,0.5, 54,-0.951,0.303,0.071, 57,0.666,0.378,0.643, 57,0.134,0.968,0.214, 57,0.505,-0.358,-0.786,
	57,-0.078,0.363,-0.929, 58,0.362,-0.08,-0.929, 59,0.886,0.41,0.214, 59,0.858,-0.115,-0.5, 59,-0.028,-0.618,-0.786, 59,0.263,0.262,-0.929, 60,0.041,0.765,0.643, 60,-0.33,-0.691,-0.643,
	61,0.698,0.513,0.5, 61,0.021,0.997,0.071, 61,0.975,0.065,-0.214, 61,0.424,0.638,-0.643, 61,0.326,-0.178,-0.929, 62,-0.951,0.303,0.071, 62,0.214,0.953,-0.214, 62,-0.491,0.588,-0.643,
	62,0.263,0.262,-0.929, 63,-0.834,0.235,-0.5, 63,0.115,0.608,-0.786, 63,-0.297,-0.222,-0.929, 64,0.12,-0.99,0.071, 64,-0.253,0.828,-0.5, 64,-0.33,-0.691,-0.643, 64,-0.348,0.13,-0.929,
	65,-0.259,0.963,0.071, 65,-0.863,0.356,-0.357, 65,0.229,0.731,-0.643, 66,-0.417,0.836,0.357, 66,-0.979,0.19,-0.071, 66,-0.449,0.425,-0.786, 66,0.026,-0.37,-0.929, 68,0.365,-0.415,-0.833,
	69,0.678,-0.356,0.643, 69,-0.951,0.303,0.071, 70,-0.621,0.448,0.643, 70,0.898,-0.434,0.071, 70,0.403,-0.651,-0.643, 70,-0.297,-0.222,-0.929, 71,-0.294,0.815,0.5, 71,-0.951,0.303,0.071,
	71,0.214,0.953,-0.214, 71,-0.491,0.588,-0.643, 71,0.263,0.262,-0.929, 72,-0.844,0.193,0.5, 72,-0.768,-0.636,0.071, 72,-0.76,-0.096,-0.643, 72,-0.078,0.363,-0.929, 73,0.041,0.765,0.643,
	73,0.933,0.031,0.357, 73,0.574,0.232,-0.786, 74,0.666,0.378,0.643, 74,-0.844,0.193,0.5, 74,0.531,-0.769,0.357, 74,0.996,-0.05,-0.071, 74,0.505,-0.358,-0.786, 74,-0.078,0.363,-0.929,
	75,-0.619,-0.606,0.5, 75,-0.742,0.635,0.214, 75,-0.956,-0.202,-0.214, 75,-0.253,0.828,-0.5, 75,-0.348,0.13,-0.929, 76,-0.834,0.235,-0.5, 77,0.886,0.41,0.214, 77,-0.766,-0.534,-0.357,
	77,0.858,-0.115,-0.5, 77,-0.491,0.588,-0.643, 77,0.263,0.262,-0.929, 78,-0.713,-0.281,0.643, 78,0.808,-0.31,0.5, 78,0.85,0.521,0.071, 78,0.582,-0.785,-0.214, 78,-0.648,-0.575,-0.5,
	78,0.766,-0.013,-0.643, 78,0.026,-0.37,-0.929, 79,-0.621,0.448,0.643, 79,-0.935,-0.281,0.214, 80,-0.619,-0.606,0.5, 80,0.12,-0.99,0.071, 83,-0.929,0.101,0.357, 83,-0.689,-0.722,-0.071,
	83,-0.601,-0.148,-0.786, 83,0.326,-0.178,-0.929, 84,-0.92,-0.163,0.357, 84,0.362,-0.08,-0.929, 85,0.115,0.608,-0.786, 85,-0.297,-0.222,-0.929, 86,0.834,0.42,-0.357, 86,0.115,0.608,-0.786,
	86,-0.297,-0.222,-0.929, 87,-0.36,-0.862,0.357, 87,-0.951,0.303,0.071, 87,-0.766,-0.534,-0.357, 87,-0.491,0.588,-0.643, 87,-0.028,-0.618,-0.786, 87,0.263,0.262,-0.929, 88,-0.601,-0.148,-0.786,
	88,0.326,-0.178,-0.929, 89,-0.713,-0.281,0.643, 89,-0.269,-0.939,0.214, 89,-0.648,-0.575,-0.5, 89,0.026,-0.37,-0.929, 90,0.527,0.687,0.5, 90,-0.46,-0.885,-0.071, 90,0.917,0.335,-0.214,
	90,0.229,0.731,-0.643, 90,-0.535,-0.31,-0.786, 90,0.362,-0.08,-0.929, 91,0.176,-0.848,0.5, 91,-0.346,-0.913,-0.214, 91,0.403,-0.651,-0.643, 91,-0.297,-0.222,-0.929, 92,0.176,-0.848,0.5,
	92,0.478,0.802,0.357, 92,-0.346,-0.913,-0.214, 92,0.115,0.608,-0.786, 92,-0.297,-0.222,-0.929, 93,-0.36,-0.862,0.357, 93,0.496,-0.865,-0.071, 93,-0.766,-0.534,-0.357, 93,-0.028,-0.618,-0.786,
	93,0.263,0.262,-0.929, 94,0.041,0.765,0.643, 94,0.933,0.031,0.357, 94,0.12,-0.99,0.071, 94,0.58,0.811,-0.071, 94,0.804,-0.475,-0.357, 94,-0.253,0.828,-0.5, 94,-0.33,-0.691,-0.643,
	94,0.574,0.232,-0.786, 94,-0.348,0.13,-0.929, 96,-0.837,-0.221,0.5, 96,0.873,-0.458,0.167, 97,-0.45,0.74,0.5, 106,0.795,0.584,-0.167, 108,0.873,-0.458,0.167, 109,-0.45,0.74,0.5,
	109,-0.192,-0.967,0.167, 114,0.38,0.778,0.5, 115,0.053,0.985,0.167, 116,-0.837,-0.221,0.5, 116,-0.334,0.928,-0.167, 118,0.86,0.101,0.5, 119,-0.45,0.74,0.5, 121,-0.917,-0.361,0.167,
	122,0.443,0.744,-0.5, 123,0.021,0.997,0.071, 124,-0.266,-0.824,0.5, 125,-0.639,0.585,0.5, 126,-0.837,-0.221,0.5, 128,-0.704,-0.69,-0.167, 130,0.857,0.487,0.167, 131,0.492,-0.713,-0.5,
	132,0.873,-0.458,0.167, 133,0.2,-0.966,-0.167, 134,-0.837,-0.221,0.5, 134,0.873,-0.458,0.167, 134,-0.334,-0.799,-0.5, 135,-0.266,-0.824,0.5, 136,-0.639,0.585,0.5, 137,-0.334,0.928,-0.167,
	138,-0.961,0.22,-0.167, 140,0.443,0.744,-0.5, 141,0.804,-0.475,-0.357, 141,0.574,0.232,-0.786, 142,0.38,0.778,0.5, 143,-0.387,0.775,-0.5, 144,-0.639,0.585,0.5, 145,-0.961,0.22,-0.167,
	145,0.076,0.548,-0.833, 147,0.2,-0.966,-0.167, 147,-0.529,-0.159,-0.833, 151,0.86,0.101,0.5, 151,0.443,0.744,-0.5, 152,0.92,-0.353,-0.167, 154,-0.334,-0.799,-0.5, 155,-0.192,-0.967,0.167,
	157,0.086,-0.982,0.167, 158,0.55,-0.669,0.5, 158,-0.704,-0.69,-0.167, 159,-0.192,-0.967,0.167, 159,0.365,-0.415,-0.833, 160,0.92,-0.353,-0.167, 161,-0.704,-0.69,-0.167, 162,-0.266,-0.824,0.5,
	162,0.492,-0.713,-0.5, 164,0.2,-0.966,-0.167, 165,0.857,0.487,0.167, 167,0.86,0.101,0.5, 171,0.86,0.101,0.5, 172,0.086,-0.982,0.167, 172,0.466,-0.297,-0.833, 173,-0.704,-0.69,-0.167,
	174,0.2,-0.966,-0.167, 175,-0.266,-0.824,0.5, 176,-0.917,-0.361,0.167, 176,-0.152,-0.531,-0.833, 180,0.873,-0.458,0.167, 181,0.86,0.101,0.5, 181,0.443,0.744,-0.5, 182,0.2,-0.966,-0.167,
	183,-0.266,-0.824,0.5, 185,-0.266,-0.824,0.5, 186,-0.917,-0.361,0.167, 186,-0.152,-0.531,-0.833, 191,0.086,-0.982,0.167, 193,0.55,-0.669,0.5, 193,-0.704,-0.69,-0.167, 194,0.55,-0.669,0.5,
	194,-0.704,-0.69,-0.167, 195,0.873,-0.458,0.167, 195,-0.334,-0.799,-0.5, 195,0.502,0.232,-0.833, 197,-0.861,0.093,-0.5, 198,-0.917,-0.361,0.167, 198,-0.152,-0.531,-0.833, 199,0.6,0.782,-0.167,
	200,0.86,0.101,0.5, 200,0.2,-0.966,-0.167, 201,0.086,-0.982,0.167, 202,0.92,-0.353,-0.167, 202,-0.152,-0.531,-0.833, 203,0.365,-0.415,-0.833, 204,0.866,0.029,-0.5, 205,0.873,-0.458,0.167,
	206,0.857,0.487,0.167, 206,0.492,-0.713,-0.5, 206,0.076,0.548,-0.833, 208,0.86,0.101,0.5, 209,0.92,-0.353,-0.167, 210,0.55,-0.669,0.5, 211,0.38,0.778,0.5, 212,0.86,0.101,0.5,
	213,0.795,0.584,-0.167, 215,0.873,-0.458,0.167, 216,0.866,0.029,-0.5, 217,0.55,-0.669,0.5, 217,0.866,0.029,-0.5, 218,0.795,0.584,-0.167, 219,0.492,-0.713,-0.5, 220,0.795,0.584,-0.167,
	220,0.365,-0.415,-0.833, 221,0.053,0.985,0.167, 222,0.795,0.584,-0.167, 223,0.795,0.584,-0.167, 224,0.857,0.487,0.167, 225,-0.917,-0.361,0.167, 226,-0.45,0.74,0.5, 226,-0.861,0.093,-0.5,
	227,0.86,0.101,0.5, 227,0.443,0.744,-0.5, 228,0.502,0.232,-0.833, 230,-0.917,-0.361,0.167, 232,-0.45,0.74,0.5, 232,-0.861,0.093,-0.5, 233,0.053,0.985,0.167, 233,-0.42,0.359,-0.833,
	235,0.92,-0.353,-0.167, 237,0.6,0.782,-0.167, 238,0.053,0.985,0.167, 238,-0.42,0.359,-0.833, 240,0.857,0.487,0.167, 240,0.492,-0.713,-0.5, 241,-0.45,0.74,0.5, 241,0.795,0.584,-0.167,
	242,0.92,-0.353,-0.167, 243,0.55,-0.669,0.5, 243,0.053,0.985,0.167, 244,-0.8,0.577,0.167, 244,0.443,0.744,-0.5, 245,0.053,0.985,0.167, 245,0.866,0.029,-0.5, 246,0.857,0.487,0.167,
	247,0.443,0.744,-0.5, 248,0.38,0.778,0.5, 249,0.38,0.778,0.5, 251,0.38,0.778,0.5, 251,0.92,-0.353,-0.167, 251,-0.387,0.775,-0.5, 252,0.053,0.985,0.167, 253,-0.45,0.74,0.5,
	253,0.795,0.584,-0.167, 254,0.86,0.101,0.5, 255,0.857,0.487,0.167, 256,0.795,0.584,-0.167, 257,-0.837,-0.221,0.5, 258,0.053,0.985,0.167, 259,0.443,0.744,-0.5, 260,0.86,0.101,0.5,
	260,0.2,-0.966,-0.167, 261,0.365,-0.415,-0.833, 262,-0.704,-0.69,-0.167, 263,-0.853,-0.151,-0.5, 264,-0.639,0.585,0.5, 264,-0.853,-0.151,-0.5, 265,-0.639,0.585,0.5, 265,0.6,0.782,-0.167,
	266,-0.334,0.928,-0.167, 266,0.502,0.232,-0.833, 267,-0.8,0.577,0.167, 269,-0.334,0.928,-0.167, 269,0.502,0.232,-0.833, 271,-0.639,0.585,0.5, 272,-0.639,0.585,0.5, 272,0.6,0.782,-0.167,
	273,0.053,0.985,0.167, 274,-0.853,-0.151,-0.5, 275,0.86,0.101,0.5, 275,0.443,0.744,-0.5, 276,0.38,0.778,0.5, 277,0.053,0.985,0.167, 277,0.866,0.029,-0.5, 278,0.053,0.985,0.167,
	278,-0.42,0.359,-0.833, 279,0.053,0.985,0.167, 280,0.38,0.778,0.5, 281,0.053,0.985,0.167, 282,0.443,0.744,-0.5, 283,-0.192,-0.967,0.167, 283,-0.861,0.093,-0.5, 283,0.365,-0.415,-0.833,
	284,-0.837,-0.221,0.5, 284,-0.334,-0.799,-0.5, 285,0.6,0.782,-0.167, 286,-0.45,0.74,0.5, 286,-0.861,0.093,-0.5, 288,-0.8,0.577,0.167, 289,-0.334,0.928,-0.167, 289,0.502,0.232,-0.833,
	290,-0.334,0.928,-0.167, 291,-0.387,0.775,-0.5, 295,-0.837,-0.221,0.5, 295,-0.334,0.928,-0.167, 295,-0.334,-0.799,-0.5, 296,0.6,0.782,-0.167, 296,0.466,-0.297,-0.833, 297,-0.266,-0.824,0.5,
	297,0.492,-0.713,-0.5, 298,0.443,0.744,-0.5, 299,0.873,-0.458,0.167, 299,0.502,0.232,-0.833, 301,0.795,0.584,-0.167, 303,0.86,0.101,0.5, 303,0.443,0.744,-0.5, 306,-0.961,0.22,-0.167,
	307,0.053,0.985,0.167, 307,0.866,0.029,-0.5, 307,-0.42,0.359,-0.833, 308,0.55,-0.669,0.5, 308,0.866,0.029,-0.5, 310,0.053,0.985,0.167, 311,0.857,0.487,0.167, 311,0.492,-0.713,-0.5,
	312,0.38,0.778,0.5, 313,-0.45,0.74,0.5, 313,-0.861,0.093,-0.5, 316,0.38,0.778,0.5, 317,-0.45,0.74,0.5, 319,0.502,0.232,-0.833, 320,-0.45,0.74,0.5, 321,-0.639,0.585,0.5,
	322,-0.266,-0.824,0.5, 324,0.38,0.778,0.5, 324,0.92,-0.353,-0.167, 325,-0.334,0.928,-0.167, 325,0.502,0.232,-0.833, 327,-0.639,0.585,0.5, 328,0.38,0.778,0.5, 328,-0.387,0.775,-0.5,
	329,-0.837,-0.221,0.5, 329,-0.334,0.928,-0.167, 330,0.38,0.778,0.5, 330,-0.387,0.775,-0.5, 332,-0.961,0.22,-0.167, 332,0.076,0.548,-0.833, 334,0.053,0.985,0.167, 335,-0.639,0.585,0.5,
	336,0.076,0.548,-0.833, 339,-0.334,0.928,-0.167, 341,-0.387,0.775,-0.5, 342,-0.917,-0.361,0.167, 342,-0.387,0.775,-0.5, 343,-0.8,0.577,0.167, 344,-0.334,0.928,-0.167, 345,-0.8,0.577,0.167,
	347,-0.837,-0.221,0.5, 347,-0.334,0.928,-0.167, 348,-0.837,-0.221,0.5, 349,-0.8,0.577,0.167, 350,-0.837,-0.221,0.5, 351,0.2,-0.966,-0.167, 354,-0.961,0.22,-0.167, 355,-0.387,0.775,-0.5,
	356,-0.8,0.577,0.167, 357,-0.192,-0.967,0.167, 357,-0.861,0.093,-0.5, 358,-0.961,0.22,-0.167, 359,-0.266,-0.824,0.5, 359,-0.961,0.22,-0.167, 361,-0.45,0.74,0.5, 362,-0.961,0.22,-0.167,
	363,-0.45,0.74,0.5, 363,-0.861,0.093,-0.5, 364,-0.42,0.359,-0.833, 365,-0.387,0.775,-0.5, 366,-0.837,-0.221,0.5, 366,-0.334,0.928,-0.167, 366,-0.334,-0.799,-0.5, 367,-0.45,0.74,0.5,
	367,-0.192,-0.967,0.167, 368,-0.192,-0.967,0.167, 369,-0.837,-0.221,0.5, 369,-0.334,-0.799,-0.5, 370,-0.837,-0.221,0.5, 371,-0.917,-0.361,0.167, 372,-0.917,-0.361,0.167, 373,0.086,-0.982,0.167,
	373,-0.853,-0.151,-0.5, 374,0.2,-0.966,-0.167, 375,-0.837,-0.221,0.5, 377,-0.8,0.577,0.167, 378,0.857,0.487,0.167, 378,-0.961,0.22,-0.167, 378,0.076,0.548,-0.833, 379,-0.45,0.74,0.5,
	379,-0.861,0.093,-0.5, 380,-0.334,0.928,-0.167, 381,-0.704,-0.69,-0.167, 382,-0.266,-0.824,0.5, 383,-0.837,-0.221,0.5, 384,-0.961,0.22,-0.167, 385,-0.639,0.585,0.5, 387,0.053,0.985,0.167,
	388,-0.961,0.22,-0.167, 389,-0.853,-0.151,-0.5, 390,-0.639,0.585,0.5, 391,-0.8,0.577,0.167, 391,-0.529,-0.159,-0.833, 392,-0.639,0.585,0.5, 393,0.55,-0.669,0.5, 395,-0.917,-0.361,0.167,
	397,-0.266,-0.824,0.5, 397,-0.961,0.22,-0.167, 399,0.55,-0.669,0.5, 401,-0.837,-0.221,0.5, 402,-0.192,-0.967,0.167, 403,-0.837,-0.221,0.5, 403,-0.334,-0.799,-0.5, 404,0.2,-0.966,-0.167,
	404,-0.529,-0.159,-0.833, 405,-0.704,-0.69,-0.167, 406,-0.334,-0.799,-0.5, 407,-0.639,0.585,0.5, 408,0.086,-0.982,0.167, 409,-0.8,0.577,0.167, 409,-0.529,-0.159,-0.833, 410,-0.192,-0.967,0.167,
	410,-0.861,0.093,-0.5, 411,-0.704,-0.69,-0.167, 412,-0.853,-0.151,-0.5, 413,-0.266,-0.824,0.5, 414,0.86,0.101,0.5, 416,-0.704,-0.69,-0.167, 417,-0.266,-0.824,0.5, 417,0.492,-0.713,-0.5,
	418,0.2,-0.966,-0.167, 419,0.086,-0.982,0.167, 420,0.86,0.101,0.5, 421,0.492,-0.713,-0.5, 422,-0.917,-0.361,0.167, 422,-0.152,-0.531,-0.833, 423,-0.192,-0.967,0.167, 425,0.857,0.487,0.167,
	425,0.076,0.548,-0.833, 426,0.873,-0.458,0.167, 426,-0.334,-0.799,-0.5,
}

----------------------------------------------------------------------------------------------------
-- small maths
----------------------------------------------------------------------------------------------------
local function lerp(a, b, u) return a + (b - a) * u end
local function clamp01(x)
	if x < 0 then return 0 elseif x > 1 then return 1 end
	return x
end
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end          -- the showcase's ease()
local function easeInQuad(u) u = clamp01(u) return u * u end
local function easeOutQuad(u) u = clamp01(u) return 1 - (1 - u) * (1 - u) end
local function easeOutCubic(u) u = clamp01(u) return 1 - (1 - u) ^ 3 end
local function span(t, a, b)
	if b > a then return clamp01((t - a) / (b - a)) end
	return t >= b and 1 or 0
end

--- Smooth interpolation through { x, y } keys (the showcase's curve()).
local function curve(keys, x)
	local n = #keys
	if x <= keys[1][1] then return keys[1][2] end
	for i = 1, n - 1 do
		local a, b = keys[i], keys[i + 1]
		if x <= b[1] then return lerp(a[2], b[2], smooth((x - a[1]) / (b[1] - a[1]))) end
	end
	return keys[n][2]
end

local function gauss(rng, mu, sd)
	local u1 = math.max(1e-9, rng:NextNumber())
	return mu + sd * math.sqrt(-2 * math.log(u1)) * math.cos(TAU * rng:NextNumber())
end

--- A Blender-space vector turned about Blender z (the storm's axis) by `a`.
local function rzv(v, a)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c - v.Y * s, v.X * s + v.Y * c, v.Z)
end

--- Rodrigues: `v` turned about the unit `axis` by `ang`.
local function rotAxis(v, axis, ang)
	local c, s = math.cos(ang), math.sin(ang)
	return v * c + axis:Cross(v) * s + axis * (axis:Dot(v) * (1 - c))
end

--- The showcase's perp_any (Blender space, z up) and the same in Roblox space (y up).
local function perpB(a)
	local p = a:Cross(Vector3.zAxis)
	if p.Magnitude < 1e-4 then p = a:Cross(Vector3.xAxis) end
	return p.Unit
end
local function perpR(a)
	local p = a:Cross(UP)
	if p.Magnitude < 1e-4 then p = a:Cross(Vector3.xAxis) end
	return p.Magnitude > 1e-6 and p.Unit or Vector3.xAxis
end

local function arclen(pts)
	local acc = table.create(#pts)
	acc[1] = 0
	for i = 2, #pts do acc[i] = acc[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	return acc
end

--- The polyline between arc lengths s0 < s1, its ends interpolated (the showcase's cut()).
local function cutPath(pts, acc, s0, s1)
	if s1 - s0 < 1e-5 or #pts < 2 then return {} end
	local function at(s)
		for i = 2, #acc do
			if s <= acc[i] + 1e-9 then
				local seg = acc[i] - acc[i - 1]
				local u = seg < 1e-9 and 0 or (s - acc[i - 1]) / seg
				return pts[i - 1]:Lerp(pts[i], u)
			end
		end
		return pts[#pts]
	end
	local out = { at(s0) }
	for i = 1, #pts do
		if s0 + 1e-6 < acc[i] and acc[i] < s1 - 1e-6 then out[#out + 1] = pts[i] end
	end
	out[#out + 1] = at(s1)
	return out
end

local function packCol(c)
	return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end

--- An sRGB channel scaled by `v` in LINEAR light (the render's srgb_lin(c) x v), back in sRGB -- what a Color3 holds.
local function srgbScale(c, v)
	local lin = c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
	lin = math.min(1, lin * v)
	return lin <= 0.0031308 and lin * 12.92 or 1.055 * lin ^ (1 / 2.4) - 0.055
end

local function seedFrom(t, model)
	local s = math.floor((tonumber(t) or os.clock()) * 1000) % 1000000
	if typeof(model) == "Instance" then
		local name = model.Name
		for i = 1, math.min(#name, 24) do s = (s * 31 + string.byte(name, i)) % 1000003 end
	end
	return s + 1
end

----------------------------------------------------------------------------------------------------
-- the baked data -> runtime tables (once, on the first cast)
----------------------------------------------------------------------------------------------------
local LUMPS, GROUPS, NMAIN = nil, nil, 0
local EXT_LI, EXT_D, EXT_N, EXT_HOME = nil, nil, nil, nil
local PHASE, PHASE_STEP = nil, 1 / 240
local SK = { bones = nil, knobs = nil, CHUNK = 64 }   -- the skeleton flash's icon (cascade_bl._skeleton); CHUNK: the
                                                      -- most points one of its strands carries

--- cascade_bl._skeleton(): the flat icon skeleton in the rig's front plane (x lateral, z up from the feet).
SK.build = function()
	local function ring2(cx, cz, rx, rz, a0, a1, n)
		local out = {}
		for i = 0, n - 1 do
			local a = math.rad(lerp(a0, a1, i / (n - 1)))
			out[#out + 1] = { cx + rx * math.cos(a), cz + rz * math.sin(a) }
		end
		return out
	end
	local b = {}
	local skull = ring2(0, 4.58, 0.40, 0.38, 200, -20, 12)
	for _, p in ipairs({ { 0.30, 4.28 }, { 0.22, 4.12 }, { 0.0, 4.06 }, { -0.22, 4.12 }, { -0.30, 4.28 }, { -0.376, 4.45 } }) do
		skull[#skull + 1] = p
	end
	b[#b + 1] = skull                                                                  -- the skull
	for _, sx in ipairs({ -1, 1 }) do b[#b + 1] = ring2(sx * 0.15, 4.52, 0.095, 0.095, 0, 360, 9) end   -- eye sockets
	b[#b + 1] = { { -0.05, 4.33 }, { 0.0, 4.41 }, { 0.05, 4.33 } }                    -- the nose
	b[#b + 1] = { { -0.17, 4.19 }, { 0.17, 4.19 } }                                   -- the teeth
	for _, x in ipairs({ -0.085, 0.0, 0.085 }) do b[#b + 1] = { { x, 4.14 }, { x, 4.24 } } end
	b[#b + 1] = { { 0.0, 4.03 }, { 0.0, 2.24 } }                                      -- the spine
	for _, z in ipairs({ 2.70, 2.52, 2.36 }) do b[#b + 1] = { { -0.09, z }, { 0.09, z } } end   -- lumbar ticks
	for _, sx in ipairs({ -1, 1 }) do
		b[#b + 1] = { { sx * 0.12, 3.86 }, { sx * 0.95, 3.93 } }                      -- clavicle
		for i = 0, 3 do                                                              -- ribs
			local z = 3.70 - 0.24 * i
			local w = 1.0 - 0.07 * i
			b[#b + 1] = { { sx * 0.06, z }, { sx * 0.36 * w, z + 0.06 }, { sx * 0.70 * w, z - 0.05 }, { sx * 0.78 * w, z - 0.22 } }
		end
		b[#b + 1] = { { sx * 1.45, 3.85 }, { sx * 1.50, 3.00 } }                      -- humerus
		b[#b + 1] = { { sx * 1.40, 2.95 }, { sx * 1.40, 2.26 } }                      -- the forearm's two bones
		b[#b + 1] = { { sx * 1.62, 2.95 }, { sx * 1.60, 2.26 } }
		b[#b + 1] = { { sx * 1.33, 2.18 }, { sx * 1.67, 2.18 } }                      -- the hand
		for k = 0, 3 do
			local x = sx * (1.36 + 0.093 * k)
			b[#b + 1] = { { x, 2.15 }, { x + sx * 0.01, 1.93 + ((k == 1 or k == 2) and 0.03 or 0) } }
		end
		b[#b + 1] = { { sx * 0.45, 1.92 }, { sx * 0.50, 1.06 } }                      -- femur
		b[#b + 1] = { { sx * 0.40, 1.00 }, { sx * 0.40, 0.20 } }                      -- the shin's two bones
		b[#b + 1] = { { sx * 0.60, 1.00 }, { sx * 0.58, 0.20 } }
		b[#b + 1] = { { sx * 0.35, 0.10 }, { sx * 0.78, 0.10 } }                      -- the foot
	end
	b[#b + 1] = { { 0.0, 2.25 }, { -0.35, 2.32 }, { -0.78, 2.28 }, { -0.72, 2.00 }, { -0.35, 1.90 }, { 0.0, 2.05 },
		{ 0.35, 1.90 }, { 0.72, 2.00 }, { 0.78, 2.28 }, { 0.35, 2.32 }, { 0.0, 2.25 } }  -- the pelvis
	local knobs = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, xz in ipairs({ { 1.45, 3.86 }, { 1.5, 2.98 }, { 1.5, 2.22 }, { 0.45, 1.92 }, { 0.5, 1.03 }, { 0.5, 0.16 } }) do
			knobs[#knobs + 1] = { sx * xz[1], xz[2] }
		end
	end
	return b, knobs
end

prepare = function()
	if LUMPS then return end
	local KEYS = { "Crown", "Core", "ArmA1", "ArmA2", "ArmA3", "ArmB1", "ArmB2", "ArmC1", "ArmC2" }
	GROUPS = {}
	for gi, row in ipairs(DATA.GROUP_ROWS) do
		local subs = {}
		for k, s in ipairs(row.Subs) do
			subs[k] = { C = Vector3.new(s[1], s[2], s[3]), d = Vector3.new(s[4], s[5], s[6]), D = s[7], delay = s[8], spin = s[9] }
		end
		local key = KEYS[gi]
		GROUPS[gi] = { key = key, H = Vector3.new(row[1], row[2], row[3]), delay = row[4], sweep = row[5], k0 = row[6],
			rise = row[7], s0 = row[8], tax = Vector3.new(row[9], row[10], row[11]).Unit, tang = row[12], curl = row[13],
			side = row[14], fly = row[15], subs = subs, fade0 = T.FadeStart[key] or 2.0 }
	end
	local lumps = {}
	for i, row in ipairs(DATA.LUMP_ROWS) do
		local G = GROUPS[row[1]]
		local home = Vector3.new(row[2], row[3], row[4])
		lumps[i] = { idx = i, g = row[1], home = home, r = row[5], val = row[6], floret = row[7] == 1, sub = row[8],
			edge = row[9], off = home - G.H, nh = home * T.ChurnScale, rh = home * 0.21 }
	end
	NMAIN = #lumps
	for _, row in ipairs(DATA.SCRAP_ROWS) do
		local i = #lumps + 1
		lumps[i] = { idx = i, g = 0, kind = row[1], puff = row[2], scrap = (row[1] == 1 and DATA.SCRAP_IN or DATA.SCRAP_OUT)[row[2]],
			r = row[3], val = row[4], soff = Vector3.new(row[5], row[6], row[7]), floret = false }
	end
	EXT_LI, EXT_D, EXT_N, EXT_HOME = {}, {}, {}, {}
	local ER = DATA.EXT_ROWS
	for k = 1, #ER, 4 do
		local n = #EXT_LI + 1
		local li = ER[k]
		local d = Vector3.new(ER[k + 1], ER[k + 2], ER[k + 3])
		local L = lumps[li]
		EXT_LI[n], EXT_D[n] = li, d
		EXT_N[n] = Vector3.new(d.X, d.Y, d.Z / SQ_G).Unit
		local p = L.home + d * L.r
		EXT_HOME[n] = Vector3.new(p.X, p.Y, 14 + p.Z * SQ_G)     -- the home layout in the world (planning only)
	end
	-- the churn noise's own clock: the integral of ChurnRate (cascade_bl.churn_phase), tabled
	PHASE = { 0 }
	local steps = math.floor(8.0 / PHASE_STEP) + 2
	for i = 2, steps do
		local s = (i - 2) * PHASE_STEP - 1.0
		PHASE[i] = PHASE[i - 1] + curve(T.ChurnRate, s) * PHASE_STEP
	end
	SK.bones, SK.knobs = SK.build()
	-- the skeleton drawn as a few strands of <= SK.CHUNK points (drawSkeleton): where each starts, and its points
	SK.cut, SK.chunkN = {}, {}
	local cn = 0
	for bi, poly in ipairs(SK.bones) do
		if cn > 0 and cn + #poly > SK.CHUNK then
			SK.cut[bi] = true
			SK.chunkN[#SK.chunkN + 1] = cn
			cn = 0
		end
		cn += #poly
	end
	SK.chunkN[#SK.chunkN + 1] = cn
	LUMPS = lumps
end

local function churnPhase(S)
	local x = math.clamp((S + 1.0) / PHASE_STEP, 0, #PHASE - 2)
	local i = math.floor(x)
	return lerp(PHASE[i + 1], PHASE[i + 2], x - i)
end

----------------------------------------------------------------------------------------------------
-- the storm's frame: sphere space / Blender world -> Roblox world
----------------------------------------------------------------------------------------------------
--- Blender world (z up, the marked point the origin) -> Roblox world: (x, y, z) -> O + BX x + BY y + UP z.
local function bw(storm, b)
	return storm.O + storm.BX * b.X + storm.BY * b.Y + UP * b.Z
end
local function bdir(storm, d)
	return storm.BX * d.X + storm.BY * d.Y + UP * d.Z
end
--- Sphere space -> Roblox world (the storm squashed by SQ_G in height about the belly plane).
local function sphereW(storm, c)
	return storm.O + storm.BX * c.X + storm.BY * c.Y + UP * (storm.belly + c.Z * SQ_G)
end

----------------------------------------------------------------------------------------------------
-- STRANDS: one bolt as one Beam per jag segment (core + glow), the showcase's per-point look folded into each Beam's
-- Transparency / Color sequences (corner -> mid-run -> corner). Consecutive segments share their Attachments on one
-- host Part. POOLED by look and size; an idle strand is parented to nil.
----------------------------------------------------------------------------------------------------
local CLASSES = { 2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128, 160 }
local strandPool = { bolt = {}, fill = {} }

-- this frame's camera (filled by the runner before any storm steps); fp = the viewer is in first person
local CTX = { camPos = Vector3.zero, right = Vector3.xAxis, up = Vector3.yAxis, camCF = CFrame.new(), fp = false }

--- First person: the most a quad (k = T.FpSpriteCap) or a strand's width (T.FpWidthCap) may span `dist` studs from the
--- lens -- k[1] x dist up close, easing to k[2] x dist by FpNear[2] studs, and no limit beyond (the caster watching the
--- storm is never touched; a bolt or star landing at the viewer's feet no longer fills the view).
local function fpCap(dist, k)
	if dist >= T.FpNear[2] then return math.huge end
	return dist * lerp(k[1], k[2], span(dist, T.FpNear[1], T.FpNear[2]))
end

local function classFor(nseg)
	for _, c in ipairs(CLASSES) do
		if nseg <= c then return c end
	end
	return CLASSES[#CLASSES]
end

local function inertPart(name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

local function mkBeam(a0, a1, tex, emission, zoff, segs, parent)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = segs
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.Texture = tex
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.LightEmission, b.LightInfluence = emission, 0
	b.ZOffset = zoff
	b.Width0, b.Width1 = 0, 0
	b.Enabled = false
	b.Parent = parent
	return b
end

--- A strand of `cls` segments. look "bolt": core (Tex.Core, additive) + glow (Tex.Glow, 0.55); look "fill": flat,
--- untextured, unlit Beams (the skeleton burst's dark fill), no glow.
local function newStrand(look, cls, flat)
	local host = inertPart("CascadeStrand")
	local emK = flat and FLAT_EMISSION or 1
	local s = { look = look, cls = cls, flat = flat, host = host, atts = table.create(cls + 1), core = table.create(cls),
		glow = table.create(cls), origin = Vector3.zero, key = nil, nC = 0, nG = 0,
		cw0 = {}, cw1 = {}, ct = {}, cc = {}, cb = {}, cOn = {}, gw0 = {}, gw1 = {}, gt = {}, gcol = {}, gbr = {}, gOn = {},
		ga = {}, gb = {} }
	for i = 1, cls + 1 do
		local a = Instance.new("Attachment")
		a.Parent = host
		s.atts[i] = a
	end
	for i = 1, cls do
		if look == "fill" then
			s.core[i] = mkBeam(s.atts[i], s.atts[i + 1], "", 0, 0, 1, host)
		else
			s.glow[i] = mkBeam(s.atts[i], s.atts[i + 1], Kit.Tex.Glow, GLOW_LE * emK, 0, 4, host)
			s.core[i] = mkBeam(s.atts[i], s.atts[i + 1], Kit.Tex.Core, emK, 0.02, 4, host)
		end
		s.cw0[i], s.cw1[i], s.cb[i], s.cOn[i] = -1, -1, -1, false
		s.ct[3 * i - 2], s.ct[3 * i - 1], s.ct[3 * i] = -1, -1, -1
		s.cc[3 * i - 2], s.cc[3 * i - 1], s.cc[3 * i] = -1, -1, -1
		s.gw0[i], s.gw1[i], s.gbr[i], s.gcol[i], s.gOn[i] = -1, -1, -1, -1, false
		s.gt[2 * i - 1], s.gt[2 * i] = -1, -1
		s.ga[i], s.gb[i] = i, i + 1
	end
	return s
end

local function strandHide(s)
	for i = 1, s.nC do
		if s.cOn[i] then
			s.core[i].Enabled = false
			s.cOn[i] = false
		end
	end
	for i = 1, s.nG do
		if s.gOn[i] then
			s.glow[i].Enabled = false
			s.gOn[i] = false
		end
	end
	s.nC, s.nG = 0, 0
end

local function dropStrand(s)
	pcall(function() s.host:Destroy() end)
end

local function giveStrand(s, poison)
	if poison then
		dropStrand(s)
		return
	end
	local ok = pcall(function()
		strandHide(s)
		s.host.Parent = nil
	end)
	s.key = nil
	local byCls = strandPool[s.look]
	local list = byCls[s.cls]
	if not list then
		list = {}
		byCls[s.cls] = list
	end
	if ok and #list < 48 then list[#list + 1] = s else dropStrand(s) end
end

local function takeStrand(storm, look, nseg)
	local cls = classFor(nseg)
	local list = strandPool[look][cls]
	while list and #list > 0 do
		local s = table.remove(list)
		if s.flat == storm.flat and pcall(function() s.host.Parent = storm.Folder end) and s.host.Parent == storm.Folder then
			return s
		end
		dropStrand(s)
	end
	local s = newStrand(look, cls, storm.flat)
	s.host.Parent = storm.Folder
	return s
end

local function seq2(a, b)
	if math.abs(a - b) < 1e-3 then return NumberSequence.new(a) end
	return NumberSequence.new(a, b)
end

local function seq3(a, m, b)
	if math.abs(a - m) < 1e-3 and math.abs(m - b) < 1e-3 then return NumberSequence.new(a) end
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, m),
		NumberSequenceKeypoint.new(1, b) })
end

local function cseq3(a, m, b, same)
	if same then return ColorSequence.new(a) end
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.5, m),
		ColorSequenceKeypoint.new(1, b) })
end

-- THE DRAW BUFFER: one strand's worth of points, filled by voltInto / beamInto / fillPoint, drawn by strandDraw.
-- Per point: position, core width, core opacity, core colour, glow width, glow opacity. Per segment (point i -> i + 1):
-- its mid-run's opacity and colour, its Brightness, and gap (a jump between two separate polylines: not drawn).
local D = { n = 0, P = {}, cw = {}, oC = {}, oM = {}, cC = {}, cM = {}, cbS = {}, gap = {}, gw = {}, gO = {},
	glow = false, gstep = 1, gc = WHITE, gb = 0, key = nil }

local WCAP = {}                    -- strandDraw's first-person width caps, per point (scratch)

local function dBegin()
	D.n, D.glow, D.gstep, D.key, D.capA = 0, false, 1, nil, nil
end

--- Lays strand `s` along the draw buffer. Only what changed is written; `D.key` (a shape id) equal to the strand's last
--- one skips the attachments (a 30 Hz shape drawn at 60 Hz).
local function strandDraw(s, Db)
	local n = math.min(Db.n, s.cls + 1)
	if n < 2 then
		strandHide(s)
		return
	end
	local P = Db.P
	local brK = s.flat and FLAT_BRIGHTNESS or 1
	local o = s.origin
	local rewrite = Db.key == nil or Db.key ~= s.key
	if (P[1] - o).Magnitude > 96 then
		o = P[1]
		s.origin = o
		s.host.CFrame = CFrame.new(o)
		rewrite = true
	end
	local atts = s.atts
	if rewrite then
		for i = 1, n do atts[i].Position = P[i] - o end
		s.key = Db.key
	end
	-- first person: no point of it wider than fpCap allows at its distance from the lens
	local capW = nil
	if CTX.fp then
		capW = WCAP
		local cam = CTX.camPos
		for i = 1, n do capW[i] = fpCap((P[i] - cam).Magnitude, T.FpWidthCap) end
	end
	-- the core: one Beam a segment
	local core, cw0, cw1, ct, cc, cb, cOn = s.core, s.cw0, s.cw1, s.ct, s.cc, s.cb, s.cOn
	local cwD, oC, oM, cC, cM, cbS, gap = Db.cw, Db.oC, Db.oM, Db.cC, Db.cM, Db.cbS, Db.gap
	for i = 1, n - 1 do
		local b = core[i]
		if gap[i] then
			if cOn[i] then
				b.Enabled = false
				cOn[i] = false
			end
		else
			local w0, w1 = cwD[i], cwD[i + 1]
			if capW then w0, w1 = math.min(w0, capW[i]), math.min(w1, capW[i + 1]) end
			if math.abs(cw0[i] - w0) > 0.002 then
				b.Width0 = w0
				cw0[i] = w0
			end
			if math.abs(cw1[i] - w1) > 0.002 then
				b.Width1 = w1
				cw1[i] = w1
			end
			local t0, tm, t1 = 1 - clamp01(oC[i]), 1 - clamp01(oM[i]), 1 - clamp01(oC[i + 1])
			local q = 3 * i
			if math.abs(ct[q - 2] - t0) > 0.012 or math.abs(ct[q - 1] - tm) > 0.012 or math.abs(ct[q] - t1) > 0.012 then
				b.Transparency = seq3(t0, tm, t1)
				ct[q - 2], ct[q - 1], ct[q] = t0, tm, t1
			end
			local c0, cm, c1 = cC[i], cM[i], cC[i + 1]
			local k0, km, k1 = packCol(c0), packCol(cm), packCol(c1)
			if cc[q - 2] ~= k0 or cc[q - 1] ~= km or cc[q] ~= k1 then
				b.Color = cseq3(c0, cm, c1, k0 == km and km == k1)
				cc[q - 2], cc[q - 1], cc[q] = k0, km, k1
			end
			local br = cbS[i] * brK
			if math.abs(cb[i] - br) > 0.01 then
				b.Brightness = br
				cb[i] = br
			end
			if not cOn[i] then
				b.Enabled = true
				cOn[i] = true
			end
		end
	end
	for i = n, s.nC do
		if cOn[i] then
			core[i].Enabled = false
			cOn[i] = false
		end
	end
	s.nC = n - 1
	-- the glow: every gstep-th point (never across a gap)
	local m = 0
	if Db.glow and #s.glow > 0 then
		local g = Db.gstep
		local glow, ga, gbv, gw0, gw1, gt, gcol, gbr, gOn = s.glow, s.ga, s.gb, s.gw0, s.gw1, s.gt, s.gcol, s.gbr, s.gOn
		local gwD, gO = Db.gw, Db.gO
		local colK = packCol(Db.gc)
		local gbright = Db.gb * brK
		local i = 1
		while i < n do
			if gap[i] then
				i += 1
			else
				local j = math.min(i + g, n)
				for k = i + 1, j - 1 do
					if gap[k] then
						j = k
						break
					end
				end
				m += 1
				local b = glow[m]
				if ga[m] ~= i or gbv[m] ~= j then
					b.Attachment0, b.Attachment1 = atts[i], atts[j]
					ga[m], gbv[m] = i, j
				end
				local w0, w1 = gwD[i], gwD[j]
				if capW then w0, w1 = math.min(w0, capW[i]), math.min(w1, capW[j]) end
				if math.abs(gw0[m] - w0) > 0.004 then
					b.Width0 = w0
					gw0[m] = w0
				end
				if math.abs(gw1[m] - w1) > 0.004 then
					b.Width1 = w1
					gw1[m] = w1
				end
				local t0, t1 = 1 - clamp01(gO[i]), 1 - clamp01(gO[j])
				if math.abs(gt[2 * m - 1] - t0) > 0.012 or math.abs(gt[2 * m] - t1) > 0.012 then
					b.Transparency = seq2(t0, t1)
					gt[2 * m - 1], gt[2 * m] = t0, t1
				end
				if gcol[m] ~= colK then
					b.Color = ColorSequence.new(Db.gc)
					gcol[m] = colK
				end
				if math.abs(gbr[m] - gbright) > 0.01 then
					b.Brightness = gbright
					gbr[m] = gbright
				end
				if not gOn[m] then
					b.Enabled = true
					gOn[m] = true
				end
				i = j
			end
		end
	end
	for k = m + 1, s.nG do
		if s.gOn[k] then
			s.glow[k].Enabled = false
			s.gOn[k] = false
		end
	end
	s.nG = m
end

----------------------------------------------------------------------------------------------------
-- SPRITES: a camera-facing Beam quad (OverchargeFX's), textured StarCore / StarGlow / Soft. Pooled by texture.
----------------------------------------------------------------------------------------------------
local spritePool = { soft = {}, starCore = {}, starGlow = {} }

local function newSprite(kind, flat)
	local host = inertPart("CascadeGlow")
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = host, host
	local tex = kind == "soft" and SOFT_TEX or (kind == "starCore" and Kit.Tex.StarCore or Kit.Tex.StarGlow)
	local le = (kind == "starGlow") and 0.75 or 1
	local b = mkBeam(a0, a1, tex or Kit.Tex.Implosion, le * (flat and FLAT_EMISSION or 1), 0, 1, host)
	return { kind = kind, flat = flat, host = host, a0 = a0, a1 = a1, beam = b, size = -1, tr = -1, br = -1, col = -1, on = false }
end

local function takeSprite(storm, kind)
	local list = spritePool[kind]
	while #list > 0 do
		local sp = table.remove(list)
		if sp.flat == storm.flat and pcall(function() sp.host.Parent = storm.Folder end) and sp.host.Parent == storm.Folder then
			return sp
		end
		pcall(function() sp.host:Destroy() end)
	end
	local sp = newSprite(kind, storm.flat)
	sp.host.Parent = storm.Folder
	return sp
end

local function giveSprite(sp, poison)
	if poison then
		pcall(function() sp.host:Destroy() end)
		return
	end
	local ok = pcall(function()
		sp.beam.Enabled = false
		sp.host.Parent = nil
	end)
	sp.on = false
	local list = spritePool[sp.kind]
	if ok and #list < 64 then list[#list + 1] = sp else pcall(function() sp.host:Destroy() end) end
end

----------------------------------------------------------------------------------------------------
-- DRAW GROUPS: per storm, per beat -- pooled strands and sprites reused frame to frame; what a frame does not draw is
-- hidden at its finish (kept for the next)
----------------------------------------------------------------------------------------------------
local function group(storm, name)
	local g = storm.groups[name]
	if not g then
		g = { used = 0, e = {}, su = 0, s = {}, dirty = false }
		storm.groups[name] = g
	end
	return g
end

local function beginG(g)
	g.used, g.su, g.dirty = 0, 0, true
end

local function finishG(g)
	for i = g.used + 1, #g.e do
		local s = g.e[i]
		if s.nC > 0 or s.nG > 0 then strandHide(s) end
	end
	for i = g.su + 1, #g.s do
		local sp = g.s[i]
		if sp.on then
			sp.beam.Enabled = false
			sp.on = false
		end
	end
end

--- Hides everything a group drew, once.
local function clearG(g)
	if not g.dirty then return end
	beginG(g)
	finishG(g)
	g.dirty = false
end

local function slot(storm, g, look, nseg)
	g.used += 1
	local s = g.e[g.used]
	if s and s.look == look and s.cls >= nseg and s.cls <= 2 * classFor(nseg) then return s end
	if s then giveStrand(s) end
	s = takeStrand(storm, look, nseg)
	g.e[g.used] = s
	return s
end

--- A soft glow / star quad `quad` studs across at `pos`, rolled `roll`, pushed z studs toward the eye at the same size
--- on screen (a ParticleEmitter's ZOffset: the showcase's sprite()). In first person no wider than fpCap at its distance
--- (EXTRA `cap`: a tighter limit, x the distance -- the caster's own hand glows).
local function sprite(storm, g, kind, pos, quad, roll, col, alpha, bright, z, cap)
	if alpha <= 0.003 or quad <= 1e-3 then return end
	local d = CTX.camPos - pos
	local dist = d.Magnitude
	if CTX.fp then
		quad = math.min(quad, fpCap(dist, T.FpSpriteCap))
		if cap then quad = math.min(quad, dist * cap) end
		if quad <= 1e-3 then return end
	end
	local size = quad
	if z and z > 0 and dist > 1e-6 then
		local zz = math.min(z, dist * 0.6)
		pos += d / dist * zz
		size = quad * (dist - zz) / dist
	end
	g.su += 1
	local sp = g.s[g.su]
	if not sp or sp.kind ~= kind then
		if sp then giveSprite(sp) end
		sp = takeSprite(storm, kind)
		g.s[g.su] = sp
	end
	sp.host.CFrame = CFrame.new(pos)
	local ax = CTX.right * math.cos(roll) + CTX.up * math.sin(roll)
	local half = ax * (size * 0.5)
	sp.a0.Position = -half
	sp.a1.Position = half
	local b = sp.beam
	if math.abs(sp.size - size) > 1e-3 then
		b.Width0, b.Width1 = size, size
		sp.size = size
	end
	local ck = packCol(col)
	if sp.col ~= ck then
		b.Color = ColorSequence.new(col)
		sp.col = ck
	end
	local tr = 1 - clamp01(alpha)
	if math.abs(sp.tr - tr) > 0.004 then
		b.Transparency = NumberSequence.new(tr)
		sp.tr = tr
	end
	local br = math.max(0, bright) * (sp.flat and FLAT_BRIGHTNESS or 1)
	if math.abs(sp.br - br) > 0.01 then
		b.Brightness = br
		sp.br = br
	end
	if not sp.on then
		b.Enabled = true
		sp.on = true
	end
end

--- Chain Bolt's star: a StarGlow (Base) under a StarCore (Light), 2 x `size` across; x0.75 under Reduce Flashing.
local function star(storm, g, pos, size, roll, coreB, glowB, a, z, coreCol, cap)
	local k = size * PARTICLE_QUAD * storm.starK
	sprite(storm, g, "starGlow", pos, k, roll, COL.Base, a, glowB, z or 0.4, cap)
	sprite(storm, g, "starCore", pos, k * 0.8, roll, coreCol or COL.Light, a, coreB, (z or 0.4) + 0.05, cap and cap * 0.8)
end

--- cascade_bl strip()'s CAPS. The render breaks a glow strip where its camera-facing sides turn more than 60 degrees,
--- or where its half-width outreaches 0.9 x the shorter neighbouring quarter-segment (it splits every segment in four
--- before the test), and lays a Soft quad w x 1.1 across at half the glow's Brightness over the break. Here the same
--- test at every joint of two glow Beams (two free Beams meeting at an angle leave a wedge open outside the turn), the
--- quad from the group's sprites, at most MAX_CAPS a strand.
local MAX_CAPS = 6
local function glowCaps(storm, g, Db)
	local capA = Db.capA
	if not (Db.glow and capA) or Db.n < 3 then return end
	local n, P, gw, gap, step = Db.n, Db.P, Db.gw, Db.gap, Db.gstep
	local cam = CTX.camPos
	local caps = 0
	local prev = nil                 -- the start of the glow Beam that ends at i
	local i = 1
	while i < n and caps < MAX_CAPS do
		if gap[i] then
			i += 1
			prev = nil
		else
			local j = math.min(i + step, n)
			for k = i + 1, j - 1 do
				if gap[k] then
					j = k
					break
				end
			end
			local w = gw[i]
			if prev and w > 0.05 then
				local a, b, c = P[prev], P[i], P[j]
				local s0 = (b - a):Cross(cam - (a + b) * 0.5)
				local s1 = (c - b):Cross(cam - (b + c) * 0.5)
				local m0, m1 = s0.Magnitude, s1.Magnitude
				if m0 > 1e-6 and m1 > 1e-6 then
					local cs = math.clamp(s0:Dot(s1) / (m0 * m1), -1, 1)
					local brk = cs < 0.5
					if not brk then
						local reach = cs > -0.999 and w * 0.5 * math.sqrt((1 - cs) / (1 + cs)) or math.huge
						local l0, l1 = (b - P[i - 1]).Magnitude, (P[i + 1] - b).Magnitude
						brk = reach > 0.9 * 0.25 * math.min(l0, l1)
					end
					if brk then
						caps += 1
						sprite(storm, g, "soft", b, w * 1.1, 0, Db.gc, capA, Db.gb * 0.5)
					end
				end
			end
			prev = i
			i = j
		end
	end
end

----------------------------------------------------------------------------------------------------
-- volt(): THE VOLTAIC BOLT SPEC (T.Volt*) on one bolt's corners, folded: the showcase inserts a mid-run point between
-- every two corners and paints every point; here each segment's Beam carries corner -> mid-run -> corner in its
-- sequences, and the hot layer (the Bloom points) rides as the segment's Brightness boost and whiteness.
----------------------------------------------------------------------------------------------------
local OPT = {}

--- A reusable options table (consumed before the next call): alpha, cool, heat, seed, pulse, key, glow corner-step,
--- tip. Extra fields (flatW, glowEnds, ember) are set by the caller after.
local function optv(a, cool, heat, seed, pulse, key, gstepC, tip)
	OPT.a, OPT.cool, OPT.heat, OPT.seed, OPT.pulse, OPT.key, OPT.gstepC, OPT.tip = a or 1, cool or 0, heat or 0, seed or 0,
		pulse, key, gstepC, tip or 0
	OPT.flatW, OPT.glowEnds, OPT.ember = nil, nil, nil
	return OPT
end

local function emberOpt(a, key)
	local o = optv(a, 0, 0, 0, nil, key)
	o.ember = true
	return o
end

local voltInto
do
local QA, QTW, QG, QK, QWH, QHK = {}, {}, {}, {}, {}, {}
voltInto = function(pts, cw, gw, cb, o)
	local n0 = #pts
	if n0 < 2 then return end
	if n0 == 2 and not o.flatW then
		-- a two-point bolt tapers to nothing at both ends: give it its mid-run as a real point
		pts = { pts[1], (pts[1] + pts[2]) * 0.5, pts[2] }
		n0 = 3
	end
	local np = 2 * n0 - 1
	QA[1] = 0
	for i = 2, n0 do
		local seg = (pts[i] - pts[i - 1]).Magnitude
		QA[2 * i - 2] = QA[2 * i - 3] + seg * 0.5
		QA[2 * i - 1] = QA[2 * i - 3] + seg
	end
	local VV, VK, VW, VP, VH = T.VoltVar, T.VoltK, T.VoltWhite, T.VoltPulse, T.VoltHot
	local lam = math.clamp(VV[3] * QA[np], VV[1], VV[2])
	local ph = Random.new(o.seed or 0):NextNumber(0, TAU)
	local heat = o.heat or 0
	local cool = clamp01(o.cool or 0)
	local a = o.a or 1
	local pp = o.pulse and (o.pulse % VP[1]) * VP[2] or nil
	local hotOn = cool < 0.95
	for q = 1, np do
		local tw = 0.5 + 0.5 * math.cos(TAU * QA[q] / lam + ph)
		local g = 0
		if pp then
			local x = (QA[q] - pp) / VP[3]
			g = math.exp(-x * x)
		end
		local corner = (q % 2 == 1) and q > 1 and q < np
		QTW[q], QG[q] = tw, g
		QK[q] = math.min(1, lerp(VK[1], VK[2], tw ^ 0.7) * (corner and 1 or VK[3]) + 0.5 * heat)
		QWH[q] = math.min(0.95, VW[1] * tw * tw + (corner and VW[2] * tw or 0) + VP[4] * g + heat)
		local hot = tw * tw * (corner and 1 or 0.4) + g + heat
		QHK[q] = hotOn and clamp01((hot - VH[1]) / 0.45) or 0
	end
	local cc = COL.Light:Lerp(COL.Base, cool)
	local hotK = (VH[2] - 1) * (1 - cool) * VH[3]
	local flatW = o.flatW
	local tip = o.tip or 0
	local gend = o.glowEnds and 0.5 or 0
	local hasGlow = gw and gw > 0
	local base = D.n
	for i = 1, n0 do
		local q = 2 * i - 1
		local u = (q - 1) / (np - 1)
		local ends = (q == 1 or q == np)
		local bc = flatW and cw or (ends and cw * tip or cw * (1 - 0.45 * u))
		local k = base + i
		D.P[k] = pts[i]
		D.cw[k] = bc * (ends and 1 or VOLT_W) * (1 + 0.35 * QG[q])
		D.oC[k] = a * QK[q]
		D.cC[k] = cc:Lerp(WHITE, math.min(0.95, QWH[q] + 0.5 * QHK[q]))
		local gws = 0
		if hasGlow then
			if ends then
				gws = (flatW and gw or 0) * gend * (0.85 + 0.3 * QTW[q])
			else
				gws = (flatW and gw or gw * (1 - 0.35 * u)) * (0.85 + 0.3 * QTW[q]) * (1 + VP[5] * QG[q])
			end
		end
		D.gw[k] = gws
		D.gO[k] = GLOW_ALPHA * a * QK[q]
	end
	if base > 0 then
		D.gap[base] = true
		D.oM[base], D.cM[base], D.cbS[base] = 0, cc, 0
	end
	for i = 1, n0 - 1 do
		local q = 2 * i
		local k = base + i
		D.gap[k] = false
		D.oM[k] = a * QK[q]
		D.cM[k] = cc:Lerp(WHITE, math.min(0.95, QWH[q] + 0.5 * QHK[q]))
		D.cbS[k] = cb * (1 + hotK * math.max(QHK[q - 1], QHK[q], QHK[q + 1]))
	end
	D.n = base + n0
	if hasGlow then D.capA = GLOW_ALPHA * a end        -- the glow layer's opacity: its break caps' (glowCaps)
end
end

--- The showcase's plain beam(): widths tapered 45 % / 35 % along it (or lists), no per-point variation; `ember` is
--- a bolt's last frames (a Dark core in a faint lifted-violet halo).
local function beamInto(pts, cw, gw, cc, cb, o)
	local n = #pts
	if n < 2 then return end
	local a = o.a or 1
	local tip = o.tip or 0
	local ember = o.ember
	local flatW = o.flatW
	local base = D.n
	for i = 1, n do
		local u = (i - 1) / (n - 1)
		local ends = (i == 1 or i == n)
		local w
		if type(cw) == "table" then
			w = cw[i] or 0
		else
			w = flatW and cw or (ends and cw * tip or cw * (1 - 0.45 * u))
		end
		local gwv = 0
		if ember then
			gwv = ends and 0 or w * 3 + 0.05
		elseif type(gw) == "table" then
			gwv = ends and 0 or (gw[i] or 0)
		elseif gw and gw > 0 then
			gwv = ends and 0 or (flatW and gw or gw * (1 - 0.35 * u))
		end
		local k = base + i
		D.P[k], D.cw[k], D.oC[k], D.cC[k], D.gw[k] = pts[i], w, a, cc, gwv
		D.gO[k] = ember and 0.15 * a or GLOW_ALPHA * a
	end
	if base > 0 then
		D.gap[base] = true
		D.oM[base], D.cM[base], D.cbS[base] = 0, cc, 0
	end
	for i = 1, n - 1 do
		local k = base + i
		D.gap[k] = false
		D.oM[k], D.cM[k], D.cbS[k] = a, cc, cb
	end
	D.n = base + n
	if not ember and (type(gw) == "table" or (gw and gw > 0)) then D.capA = GLOW_ALPHA * a end   -- (an ember: no caps)
end

local function voltDraw(storm, g, pts, cw, gw, cb, gb, o)
	if #pts < 2 then return end
	dBegin()
	voltInto(pts, cw, gw, cb * storm.kb, o)
	D.glow = gw ~= nil and gw > 0
	D.gstep = o.gstepC or ((#pts >= 7) and 2 or 1)
	D.gc, D.gb, D.key = COL.Base, gb * storm.kb, o.key
	strandDraw(slot(storm, g, "bolt", D.n - 1), D)
	glowCaps(storm, g, D)
end

local function beamDraw(storm, g, pts, cw, gw, cc, cb, gc, gb, o)
	if #pts < 2 then return end
	dBegin()
	beamInto(pts, cw, gw, cc, cb * storm.kb, o)
	D.glow = o.ember == true or type(gw) == "table" or (gw ~= nil and gw > 0)
	D.gstep = o.gstepC or ((#pts >= 9) and 2 or 1)
	D.gc = o.ember and EMBER_HALO or (gc or COL.Base)
	D.gb = (o.ember and cb * 0.8 or (gb or 0)) * storm.kb
	D.key = o.key
	strandDraw(slot(storm, g, "bolt", D.n - 1), D)
	glowCaps(storm, g, D)
end

----------------------------------------------------------------------------------------------------
-- LIGHTS: named requests each frame; the MaxLights highest-priority get PointLights (made on first use, off when not
-- asked for). None on a flat-lit map; x0.5 in daylight (the Kit's rules).
----------------------------------------------------------------------------------------------------
local LKEY = { hand = { "handL", "handR" }, fork = { "fork1", "fork2", "fork3", "fork4" }, seam = {} }
for i = 1, 16 do LKEY.seam[i] = "seam" .. i end

local function reqLight(storm, key, pos, b, range, col, prio, shadow)
	if b <= 0.005 then return end
	local n = storm.lreqN + 1
	storm.lreqN = n
	local e = storm.lreq[n]
	if not e then
		e = {}
		storm.lreq[n] = e
	end
	e.key, e.pos, e.b, e.range, e.col, e.prio, e.shadow = key, pos, b, range, col, prio, shadow == true
end

local function lightOrder(a, b)
	if a.prio ~= b.prio then return a.prio < b.prio end
	return a.b > b.b
end

local function applyLights(storm)
	local lk = storm.lightK
	local list = storm.lsort
	table.clear(list)
	if lk > 0 then
		for i = 1, storm.lreqN do list[i] = storm.lreq[i] end
		table.sort(list, lightOrder)
	end
	local frame = storm.frameN
	for i = 1, math.min(#list, T.MaxLights) do
		local e = list[i]
		local L = storm.lights[e.key]
		if not L then
			local att = Instance.new("Attachment")
			att.Parent = storm.lightHost
			local l = Instance.new("PointLight")
			l.Name = "CascadeLight"
			l.Brightness, l.Range, l.Shadows = 0, 8, false
			l.Parent = att
			L = { att = att, light = l, b = -1, r = -1, col = nil, sh = false, on = true, frame = frame }
			storm.lights[e.key] = L
		end
		L.frame = frame
		L.att.WorldPosition = e.pos
		local b = e.b * lk
		if math.abs(L.b - b) > 1e-3 then
			L.light.Brightness = b
			L.b = b
		end
		local r = math.min(e.range, 60)
		if math.abs(L.r - r) > 1e-3 then
			L.light.Range = r
			L.r = r
		end
		if L.col ~= e.col then
			L.light.Color = e.col
			L.col = e.col
		end
		if L.sh ~= e.shadow then
			L.light.Shadows = e.shadow
			L.sh = e.shadow
		end
		if not L.on then
			L.light.Enabled = true
			L.on = true
		end
	end
	for _, L in pairs(storm.lights) do
		if L.frame ~= frame and L.on then
			L.light.Enabled = false
			L.on = false
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE EXPOSURE KICK (Lighting.ExposureCompensation): the Kit's Bloom-kick rules for the one property it does not
-- cover -- overlapping kicks take the max, a value someone else writes mid-kick becomes the new base, and the base is
-- put back when the last kick is spent. Shot time: a slowed review decays it slower.
----------------------------------------------------------------------------------------------------
local exposureKick
do
local expo = { conn = nil, base = 0, wrote = nil, kicks = {} }

local function expoStop()
	if expo.conn then
		expo.conn:Disconnect()
		expo.conn = nil
	end
	pcall(function() Lighting.ExposureCompensation = expo.base end)
	expo.wrote = nil
	table.clear(expo.kicks)
end

local function expoStep()
	local now = os.clock()
	local ts = (Kit and Kit.timeScale) and Kit.timeScale() or 1
	local add = 0
	local kicks = expo.kicks
	for i = #kicks, 1, -1 do
		local k = kicks[i]
		local age = (now - k.born) * ts
		local e = age <= k.hold and 1 or math.exp(-(age - k.hold) / k.tau)
		if e < 0.01 then table.remove(kicks, i) else add = math.max(add, k.amt * e) end
	end
	local cur = Lighting.ExposureCompensation
	if expo.wrote ~= nil and math.abs(cur - expo.wrote) > 1e-3 then expo.base = cur end
	if #kicks == 0 then
		expoStop()
		return
	end
	Lighting.ExposureCompensation = expo.base + add
	expo.wrote = Lighting.ExposureCompensation          -- read back: the engine clamps it
end

exposureKick = function(amt, tau, hold)
	if not RunService:IsClient() or amt <= 0.001 then return end
	if #expo.kicks == 0 then
		expo.base = Lighting.ExposureCompensation
		expo.wrote = nil
	end
	if #expo.kicks >= 8 then table.remove(expo.kicks, 1) end
	table.insert(expo.kicks, { born = os.clock(), amt = amt, tau = math.max(1e-3, tau), hold = hold or 0 })
	if not expo.conn then
		expo.conn = RunService.RenderStepped:Connect(function()
			local ok, err = pcall(expoStep)
			if not ok then
				warnOnce("expo", "the exposure kick stopped: " .. tostring(err))
				pcall(expoStop)
			end
		end)
	end
	pcall(expoStep)
end
end

----------------------------------------------------------------------------------------------------
-- THE CLOUD: the lumps (cascade_bl.radial_k / group_scale / cloud_state), one BulkMoveTo a frame
----------------------------------------------------------------------------------------------------
local lumpPool = {}

local function takeLump()
	local e = table.remove(lumpPool)
	if e then return e[1], e[2] end
	local p = Instance.new("Part")
	p.Name = "CascadeLump"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = Vector3.one
	p.Transparency = 1
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = Vector3.new(0.01, 0.01, 0.01)
	m.Parent = p
	return p, m
end

local function giveLump(p, m, poison)
	if poison or #lumpPool >= 1000 then
		pcall(function() p:Destroy() end)
		return
	end
	local ok = pcall(function()
		p.Transparency = 1
		p.Parent = nil
	end)
	if ok then lumpPool[#lumpPool + 1] = { p, m } else pcall(function() p:Destroy() end) end
end

--- anim_cascade3.radial_k: the storm's shared radial factor once it is together.
local function radialK(S)
	local Lk = T.Loose[1]
	local sq = T.Squeeze
	local rb = T.Rebound
	local ki, ks, kt = T.Kick[1], T.Kick[2], T.Kick[3]
	if S < T.Gather then return Lk end
	if S < sq[1] then return lerp(Lk, sq[2], easeInQuad((S - T.Gather) / (sq[1] - T.Gather))) end
	if S < rb[1] then return lerp(sq[2], rb[2], easeOutCubic((S - sq[1]) / (rb[1] - sq[1]))) end
	if S < T.Settle then return lerp(rb[2], 1, smooth((S - rb[1]) / (T.Settle - rb[1]))) end
	if S < T.Tension[1] then return 1 + 0.008 * math.sin((S - T.Settle) * TAU * 2.2) end
	if S < T.Fan then return lerp(1, T.Tension[2], easeInQuad((S - T.Tension[1]) / (T.Fan - T.Tension[1]))) end
	if S < T.Fan + F * 2 then return lerp(T.Tension[2], ki, easeOutCubic((S - T.Fan) / (F * 2))) end
	if S < kt then return lerp(ki, ks, easeOutCubic((S - T.Fan - F * 2) / (kt - T.Fan - F * 2))) end
	return ks
end

--- anim_cascade3.group_scale: (xy, z).
local function groupScale(S)
	local Ls = T.Loose[2]
	local sq = T.Squeeze
	local rbAt = T.Rebound[1]
	if S < T.Gather then return Ls, Ls end
	if S < sq[1] then
		local u = easeInQuad((S - T.Gather) / (sq[1] - T.Gather))
		return lerp(Ls, sq[3], u), lerp(Ls, sq[4], u)
	end
	if S < rbAt then
		local u = easeOutCubic((S - sq[1]) / (rbAt - sq[1]))
		return lerp(sq[3], 1.03, u), lerp(sq[4], 1.06, u)
	end
	if S < T.Settle then
		local u = smooth((S - rbAt) / (T.Settle - rbAt))
		return lerp(1.03, 1, u), lerp(1.06, 1, u)
	end
	if S < T.Tension[1] then return 1, 1 end
	if S < T.Fan then
		local u = easeInQuad((S - T.Tension[1]) / (T.Fan - T.Tension[1]))
		return lerp(1, 0.98, u), lerp(1, 0.97, u)
	end
	if S < T.Kick[3] then
		local u = easeOutCubic((S - T.Fan) / (T.Kick[3] - T.Fan))
		return lerp(1.04, 1, u), lerp(1.05, 1, u)
	end
	return 1, 1
end

--- Blender's noise_vector on Roblox's noise (three offset fields).
local function churnVec(q)
	local K = T.NoiseK
	return Vector3.new(math.noise(q.X + 0.371, q.Y + 0.173, q.Z + 0.019),
		math.noise(q.X + 17.31, q.Y - 9.13, q.Z + 3.71),
		math.noise(q.X - 21.97, q.Y + 13.37, q.Z - 7.13)) * K
end

--- Every lump at visual storm time V (sphere space): C / R / Gw (glow weight) / On, and the active list.
local function cloudState(storm, V)
	local C, R, Gw, On, act = storm.C, storm.R, storm.Gw, storm.On, storm.act
	table.clear(act)
	local A = curve(T.Churn, V)
	local ph = churnPhase(V)
	local spin = -T.Spin * V
	local k = radialK(V)
	local sx, sz = groupScale(V)
	local dk = easeInQuad(span(V, 1.80, storm.VEND))
	local drift = Vector3.new(T.Drift[1] * dk, T.Drift[2] * dk, T.Drift[3] * dk / SQ_G)
	local amp = A * 1.6
	local rk = 0.07 * (A / 1.3)
	local phz = Vector3.new(0, 0, ph)
	local phx = ph * 1.7
	local gather = T.Gather
	local fadeT = T.FadeT
	for gi = 1, #GROUPS do
		local G = GROUPS[gi]
		local list = storm.byGroup[gi]
		local H = G.H
		local Cg, rotAng, rot2, gsx, gsz, uf
		local skip = false
		if V < gather then
			if V < G.delay then
				skip = true
			else
				local u = (V - G.delay) / G.fly
				local e = 0.5 * smooth(u) + 0.5 * easeOutQuad(u)
				local w = 1 - e
				local ang = spin + G.sweep * w
				local kk = lerp(G.k0, T.Loose[1], e)
				Cg = rzv(Vector3.new(H.X * kk, H.Y * kk, 0), ang) + Vector3.new(0, 0, H.Z + G.rise * w ^ 1.5)
				local s = lerp(G.s0, T.Loose[2], e) * smooth(span(V, G.delay, G.delay + 0.07))
				rotAng, rot2 = ang + G.curl * w, G.tang * w
				gsx, gsz, uf = s, s, 0
			end
		else
			uf = span(V, G.fade0, G.fade0 + fadeT)
			local ef = smooth(uf)
			local kk = k * (1 + T.FadeApart * ef)
			local ang = spin + 0.35 * uf * G.side
			local dz = -0.6 * math.sin(math.pi * span(V, gather, T.Rebound[1])) + T.FadeUp * ef / SQ_G
			Cg = rzv(Vector3.new(H.X * kk, H.Y * kk, 0), ang) + Vector3.new(0, 0, H.Z + dz) + drift
			rotAng, rot2 = ang, 0
			gsx, gsz = sx, sz
		end
		for _, L in ipairs(list) do
			local li = L.idx
			if skip then
				On[li] = false
			else
				local o = L.off
				local fs = 1
				if uf > 0 then
					-- the break-up: its fragment shrinks AS ONE PIECE, the rim a little ahead, florets first
					local sb = G.subs[L.sub]
					local us = clamp01((uf * fadeT - sb.delay) / (fadeT - sb.delay))
					fs = 1 - smooth((us - 0.06) / 0.94)
					fs *= 1 - 0.22 * L.edge * smooth(us)
					if L.floret then fs *= 1 - smooth((us - 0.04) / 0.56) end
					o = sb.C + rzv((o - sb.C) * fs, sb.spin * us) + sb.d * (sb.D * us ^ 1.4)
				end
				local lo = Vector3.new(o.X * gsx, o.Y * gsx, o.Z * gsz)
				if rot2 ~= 0 then lo = rotAxis(lo, G.tax, rot2) end
				local p = Cg + rzv(lo, rotAng) + churnVec(L.nh + phz) * (amp * fs)
				local rh = L.rh
				local r = L.r * gsx * fs * (1 + rk * math.noise(rh.X + phx + 0.37, rh.Y + 0.11, rh.Z + 0.23) * T.NoiseK)
				if r > 0.05 then
					C[li], R[li], On[li] = p, r, true
					Gw[li] = uf <= 0 and 1 or math.max(0, fs) ^ 0.6 * (1 - 0.25 * uf)
					act[#act + 1] = li
				else
					On[li] = false
				end
			end
		end
	end
	-- the scraps: curling in and swallowed / peeling off in the break-up
	for _, L in ipairs(storm.scraps) do
		local li = L.idx
		local sc = L.scrap
		local p, r, g = nil, 0, 0
		if L.kind == 1 then
			local d0, fly = sc[1], sc[2]
			if V >= d0 and V <= d0 + fly + 0.10 then
				local u = clamp01((V - d0) / fly)
				local e = easeOutQuad(u)
				local a = sc[4] + sc[6] * e + spin
				local rr = lerp(sc[3], sc[7], e)
				local k_ = smooth(span(V, d0, d0 + 0.05)) * (1 - smooth(span(V, d0 + fly - 0.06, d0 + fly + 0.10)))
				p = Vector3.new(math.cos(a) * rr, math.sin(a) * rr, lerp(sc[5], sc[8], e) / SQ_G) + L.soff * k_
				r, g = L.r * k_, 0.7
			end
		else
			local t0, dur = sc[1], sc[2]
			if V >= t0 and V <= t0 + dur then
				local u = (V - t0) / dur
				local p0 = rzv(Vector3.new(sc[3], sc[4], sc[5]), spin)
				local k_ = (1 - smooth((u - 0.30) / 0.70)) * smooth(span(u, 0, 0.08))
				p = Vector3.new(p0.X, p0.Y, p0.Z / SQ_G) + rzv(Vector3.new(sc[6], sc[7], sc[8]), spin) * easeOutQuad(u)
					+ drift + L.soff * k_
				r, g = L.r * k_, 0.6 * k_
			end
		end
		if p and r > 0.05 then
			C[li], R[li], Gw[li], On[li] = p, r, g, true
			act[#act + 1] = li
		else
			On[li] = false
		end
	end
end

--- A batch of the storm's lumps made (or taken from the pool) this frame.
local function stepBuild(storm, fast)
	local q = storm.buildQ
	local n = #q
	if storm.built >= n then return end
	local upto = math.min(n, storm.built + T.LumpBatch * (fast and 4 or 1))
	local dark = T.Body or COL.Dark
	for k = storm.built + 1, upto do
		local li = q[k]
		local L = LUMPS[li]
		local part, mesh = takeLump()
		local v = L.val                -- the value spread in linear light, as the render multiplies it
		part.Color = Color3.new(srgbScale(dark.R, v), srgbScale(dark.G, v), srgbScale(dark.B, v))
		part.CastShadow = storm.Q.LumpShadow and not L.floret and L.g > 0
		part.Transparency = 1
		-- the Part as big as the lump ever grows (LumpRoom), the mesh scaled down inside it: the engine's culling and
		-- shadow bounds follow Part.Size, never a SpecialMesh.Scale larger than it
		local rb = L.r * T.LumpRoom
		part.Size = Vector3.new(2 * rb, 2 * rb * SQ_G, 2 * rb)
		part.Parent = storm.Folder
		storm.lumpE[li] = { part = part, mesh = mesh, shown = false, sc = -1, rb = rb }
	end
	storm.built = upto
end

local function renderLumps(storm)
	local P, Cf = storm.bmP, storm.bmC
	table.clear(P)
	table.clear(Cf)
	local n = 0
	local O, BX, BY, belly = storm.O, storm.BX, storm.BY, storm.belly
	local C, R, On = storm.C, storm.R, storm.On
	local q = storm.buildQ
	for k = 1, storm.built do
		local li = q[k]
		local e = storm.lumpE[li]
		if e then
			if On[li] then
				local c = C[li]
				n += 1
				P[n] = e.part
				Cf[n] = CFrame.new(O + BX * c.X + BY * c.Y + UP * (belly + c.Z * SQ_G))
				local r = R[li]
				if math.abs(r - e.sc) > 0.008 * r + 0.003 then
					local k = r / e.rb           -- (the Part is the ellipsoid at e.rb: Size x Scale draws it at r)
					e.mesh.Scale = Vector3.new(k, k, k)
					e.sc = r
				end
				if not e.shown then
					e.part.Transparency = 0
					e.shown = true
				end
			elseif e.shown then
				e.part.Transparency = 1
				e.shown = false
			end
		end
	end
	if n > 0 then workspace:BulkMoveTo(P, Cf, Enum.BulkMoveMode.FireCFrameChanged) end
end

----------------------------------------------------------------------------------------------------
-- THE INTERNAL FLASHES (cascade_bl.plan_flashes / flash_field), in Blender-world coordinates
----------------------------------------------------------------------------------------------------
local function planFlashes(storm, rng)
	local ev = {}
	local anchor = Vector3.new(0, 0, storm.belly)
	local V = 0.02
	-- (2026-10-19, audit P5D-03) Reduce Flashing: every event's amplitude x CalmFlash (flashK), and the telegraph's
	-- internal flashes at most 3 a second (they ramp to 15)
	local fk = storm.flashK
	while V < T.Fan do
		local rate = curve(T.Flashes, V)
		if storm.calm then rate = math.min(rate, 3) end
		local amp = curve(T.FlashAmp, V) * rng:NextNumber(0.7, 1.3) * fk
		local q = Vector3.new(gauss(rng, 0, 7.0), gauss(rng, 0, 7.0), rng:NextNumber(-1.0, 7.0))
		ev[#ev + 1] = { V, anchor + q, rng:NextNumber(4.0, 7.5), amp, rng:NextNumber(0.05, 0.10), false }
		V += rng:NextNumber(0.5, 1.5) / rate
	end
	local A = T.AfterFlashes
	V = A[1]
	while V < A[2] do
		local u = (V - A[1]) / (A[2] - A[1])
		local dk = easeInQuad(span(V, 1.80, storm.VEND))
		local c = anchor + Vector3.new(T.Drift[1] * dk, T.Drift[2] * dk, T.Drift[3] * dk)
		local q = Vector3.new(gauss(rng, 0, 8.0 + 4 * u), gauss(rng, 0, 8.0 + 4 * u), rng:NextNumber(-1.0, 8.0) + 4.0 * u)
		ev[#ev + 1] = { V, c + q, rng:NextNumber(5.0, 8.0), lerp(A[4][1], A[4][2], u) * rng:NextNumber(0.7, 1.3) * fk,
			rng:NextNumber(0.08, 0.16), false }
		V += rng:NextNumber(0.5, 1.5) / A[3]
	end
	-- the set pieces: [6] dropped when the release is called off, [7] the strike they belong to (0 = the fan), [8] the
	-- seams are solved on their very first frame (stepSeams: never a solve period late)
	ev[#ev + 1] = { T.Squeeze[1], anchor + Vector3.new(0, 0, 3.0), 22.0, 1.25 * fk, 0.11, false, nil, true }  -- the punch
	ev[#ev + 1] = { T.Fan, anchor + Vector3.new(0, 0, -3.0), 16.0, 2.0 * fk, 0.12, true, 0, true }   -- the fan tears out of it
	for i = 1, 4 do
		ev[#ev + 1] = { storm.STR[i], anchor + Vector3.new(0, 0, -1.5), 10.0, 0.9 * fk, 0.06, true, i, true }
	end
	ev[#ev + 1] = { storm.FLASH, anchor + Vector3.new(0, 0, -2.0), 24.0, 3.2 * storm.flashK, 0.16, true, 5, true }  -- white
	return ev
end

--- A telegraph landing's kick of light into the seams round it (the render's flash_field.extra). Kept SnapWindow s.
local function addSnap(storm, V, q, a)
	local list = storm.snaps
	for i = #list, 1, -1 do
		if V - list[i][1] > T.SnapWindow then table.remove(list, i) end
	end
	list[#list + 1] = { V, q, a }
end

--- Whether flash event `ev` is off: the release called off, or a strike the server ended the storm before.
local function flashOff(storm, ev)
	if not ev[6] then return false end
	if storm.Cancelled then return true end
	return storm.Truncated == true and ev[7] ~= nil and ev[7] > (storm.lastN or 0)
end

--- The flash events alive at V, enveloped: storm.flList[1..flN] = { x, y, z (Blender world), sigma, sigma^2, amp }.
--- Only the newest SnapMax landings younger than SnapWindow count (the render lights the seams with a landing for the
--- 1.5 frames its star shows; here it has to outlive one seam solve).
local function flashPrep(storm, V)
	local list = storm.flList
	local n = 0
	local function add(q, s, a)
		n += 1
		local e = list[n]
		if not e then
			e = {}
			list[n] = e
		end
		e.x, e.y, e.z, e.s, e.s2, e.a = q.X, q.Y, q.Z, s, s * s, a
	end
	for _, ev in ipairs(storm.flashEv) do
		local dt = V - ev[1]
		local tau = ev[5]
		if dt >= 0 and dt < tau * 6 and not flashOff(storm, ev) then
			local env = math.exp(-dt / tau) * (dt < 0.05 and 1 or 0.85)
				+ (dt >= 0.05 and 0.35 * math.exp(-(dt - 0.05) / tau) or 0)
			add(ev[2], ev[3], ev[4] * env)
		end
	end
	local snaps = storm.snaps
	local taken = 0
	for i = #snaps, 1, -1 do
		local sn = snaps[i]
		local dt = V - sn[1]
		if dt >= 0 and dt < T.SnapWindow then
			add(sn[2], 3.0, sn[3] * math.exp(-dt / 0.05) * storm.flashK)   -- flashK: (2026-10-19, audit P5D-03)
			taken += 1
			if taken >= T.SnapMax then break end
		end
	end
	storm.flN = n
end

----------------------------------------------------------------------------------------------------
-- THE SEAMS (cascade_bl.creases / seam_paint / seam_glow / seam_lights): solved at SeamHz, placed every frame
----------------------------------------------------------------------------------------------------
local seamKitPool = {}

local function takeSeamKit(storm)
	while #seamKitPool > 0 do
		local kit = table.remove(seamKitPool)
		if kit.flat == storm.flat and pcall(function() kit.host.Parent = storm.Folder end) and kit.host.Parent == storm.Folder then
			kit.host.CFrame = CFrame.new(storm.O)
			return kit
		end
		pcall(function() kit.host:Destroy() end)
	end
	local host = inertPart("CascadeSeams")
	host.CFrame = CFrame.new(storm.O)
	host.Parent = storm.Folder
	return { host = host, els = {}, flat = storm.flat }
end

local function giveSeamKit(kit, poison)
	if not kit then return end
	if poison or #seamKitPool >= 2 then
		pcall(function() kit.host:Destroy() end)
		return
	end
	local ok = pcall(function()
		for _, e in ipairs(kit.els) do
			e.core.Enabled, e.glow.Enabled, e.on, e.gon, e.live = false, false, false, false, false
		end
		kit.host.Parent = nil
	end)
	if ok then seamKitPool[#seamKitPool + 1] = kit else pcall(function() kit.host:Destroy() end) end
end

--- One seam Beam pair (core + glow sharing their two attachments), made on first use.
local function seamEl(storm, kit, k)
	local e = kit.els[k]
	if e then return e end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = kit.host, kit.host
	local emK = kit.flat and FLAT_EMISSION or 1
	local glow = mkBeam(a0, a1, Kit.Tex.Glow, GLOW_LE * emK, 0, T.SeamSegments, kit.host)
	local core = mkBeam(a0, a1, Kit.Tex.Core, emK, 0, T.SeamSegments, kit.host)
	e = { a0 = a0, a1 = a1, core = core, glow = glow, on = false, gon = false, live = false, hasGlow = false,
		cs0 = -1, cs1 = -1, i = 0, j = 0, th0 = 0, th1 = 0, w = -1, gw = -1, z = -1, gz = -1, br = -1, gbr = -1 }
	kit.els[k] = e
	return e
end

local seamSolve
do
--- The seam colour ramp (the showcase's Neon: violet -> Base -> Light -> white; a visible seam is >= Base).
local function heatCol(h)
	if h <= 0.30 then return COL.Dark:Lerp(COL.Base, h / 0.30) end
	if h <= 0.62 then return COL.Base:Lerp(COL.Light, (h - 0.30) / 0.32) end
	return COL.Light:Lerp(SEAM_WHITE, math.min(1, (h - 0.62) / 0.38))
end

--- The pair list: every two active lumps within reach (plus PairMargin), by sweep and prune on x; each lump's
--- neighbours (the only lumps that can cover a point of its surface).
local function refreshPairs(storm)
	local SM = storm.seam
	local C, R = storm.C, storm.R
	local order = SM.order
	table.clear(order)
	for i, li in ipairs(storm.act) do order[i] = li end
	table.sort(order, function(a, b) return C[a].X < C[b].X end)
	local rmax = 0
	for _, li in ipairs(order) do
		if R[li] > rmax then rmax = R[li] end
	end
	for _, l in pairs(SM.nb) do table.clear(l) end
	local pa, pb, nb = SM.pa, SM.pb, SM.nb
	local np = 0
	local margin = T.PairMargin
	local n = #order
	for a = 1, n do
		local i = order[a]
		local ci, ri = C[i], R[i]
		local reach = ri + rmax + margin
		for b = a + 1, n do
			local j = order[b]
			local cj = C[j]
			if cj.X - ci.X > reach then break end
			local dv = cj - ci
			local lim = ri + R[j] + margin
			if dv.X * dv.X + dv.Y * dv.Y + dv.Z * dv.Z < lim * lim then
				np += 1
				pa[np], pb[np] = i, j
				local li_, lj_ = nb[i], nb[j]
				if not li_ then
					li_ = {}
					nb[i] = li_
				end
				if not lj_ then
					lj_ = {}
					nb[j] = lj_
				end
				li_[#li_ + 1] = j
				lj_[#lj_ + 1] = i
			end
		end
	end
	SM.np = np
end

-- solve scratch (one solve at a time)
local SP, SOK, RS, RL = {}, {}, {}, {}
local CNC, CNR = {}, {}          -- the neighbours that reach one crease circle: centre, radius^2
local FE = {}                    -- the flash events that reach one crease circle
local RE, RH, RR, RG = {}, {}, {}, {}
local PI, PJ, PT0, PT1, PE, PRAD, POFF, PCNT, PGL, PGC, PKEY, PB = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local KE, KH, KR, KG = {}, {}, {}, {}
local HB, KEEP, TAKEN, FREE = {}, {}, {}, {}
local LORD = {}                  -- the light candidates' slots, brightest first (a running top-K, no sort)
local LCW, LCE, LCH, LCI, LCJ, LCT, LCX, LCY, LCZ = {}, {}, {}, {}, {}, {}, {}, {}, {}
local SCOL = {}                  -- one piece's heat colours (scratch)
local KPT, KPC, KPG = {}, {}, {} -- keypoint lists by count, reused (a sequence copies its list)
local NBINS = 64                 -- the pieces' brightness histogram: the cut to SeamCap without a sort
local QT = 64                    -- a seam sequence's transparency is quantised to 1 / QT, compared, written on change

local function kpList(pool, cnt)
	local l = pool[cnt]
	if not l then
		l = table.create(cnt)
		pool[cnt] = l
	end
	return l
end

seamSolve = function(storm, V)
	local SM = storm.seam
	local kit = SM.kit
	local C, R, On, Gw = storm.C, storm.R, storm.On, storm.Gw
	-- (the gathering flies lumps in from outside: every solve; the break-up's fragments only shrink and part, so the
	-- cached, margin-padded list stays a superset of the live pairs between refreshes)
	local growing = V < T.Settle
	if SM.pairAge <= 0 or growing then
		refreshPairs(storm)
		SM.pairAge = T.PairEvery
	else
		SM.pairAge -= 1
	end
	local belly = storm.belly
	local G = curve(T.Charge, V)
	local d0, d1 = T.SeamDeep[1], T.SeamDeep[2]
	local fq, sh = T.SeamHot[1], T.SeamHot[2]
	local lo_, lg_, lf_ = T.SeamLeak[1], T.SeamLeak[2], T.SeamLeak[3]
	local ph = churnPhase(V)
	local hx, hy, hz = 0.31 * ph, -0.22 * ph, 0.9 * ph                  -- the hot spots drift along the creases
	local dk = easeInQuad(span(V, 1.80, storm.VEND))
	local cx, cy, cz = T.Drift[1] * dk, T.Drift[2] * dk, belly + T.Drift[3] * dk   -- the storm's heart (drifting)
	local ra = T.SeamReach[1] * (1 + 1.2 * smooth(span(V, 1.80, 3.4)))
	local rzz = T.SeamReach[2] * (1 + 0.8 * smooth(span(V, 1.80, 3.4)))
	local fk = smooth(span(V, 1.75, 2.30))
	local fr = T.Friction * (1 - span(V, 0.62, 0.90))
	local hotMax = lerp(1.75, 1.45, fk)
	local t0_, t1_, t2_ = T.SeamTube[1], T.SeamTube[2], T.SeamTube[3]
	local gwk, need = T.SeamGlow[1], T.SeamGlow[2]
	local N = storm.Q.SeamSamples
	local step = TAU / N
	local cosT, sinT = SM.cosT, SM.sinT
	local piece = math.max(1, math.floor(N * T.SeamPiece / 360 + 1e-6))     -- steps a Beam
	flashPrep(storm, V)
	local nfl = storm.flN
	local FL = storm.flList
	local nP, nK, nL = 0, 0, 0
	local KL = math.max(1, storm.Q.SeamLights * 4)                        -- light candidates kept (spares for the spacing)
	for k = 1, SM.np do
		local i, j = SM.pa[k], SM.pb[k]
		if On[i] and On[j] then
			local ci, cj = C[i], C[j]
			local ri, rj = R[i], R[j]
			local dv = cj - ci
			local d = dv.Magnitude
			if d < ri + rj - 0.02 and d > math.abs(ri - rj) + 0.02 and ri >= 0.05 and rj >= 0.05 then
				local a = (d * d + ri * ri - rj * rj) / (2 * d)
				local rho2 = ri * ri - a * a
				if rho2 > 0.0225 then
					local rho = math.sqrt(rho2)
					local cosd = (ri * ri + rj * rj - d * d) / (2 * ri * rj)
					local deep = clamp01((d0 - cosd) / d1) ^ 1.3
					local Li, Lj = LUMPS[i], LUMPS[j]
					local g = math.min(Gw[i], Gw[j])
					if Li.floret or Lj.floret then g *= T.FloretSeam end
					if Li.g ~= Lj.g and Li.g > 0 and Lj.g > 0 then g *= 1 + fr end
					local nrm = dv / d
					local m = ci + nrm * a
					local mbx, mby, mbz = m.X, m.Y, belly + m.Z * SQ_G              -- the crease's centre, Blender world
					-- the most this crease can show anywhere round its circle: a dark one is never sampled
					local qx, qy = mbx - cx, mby - cy
					local rxy = math.sqrt(qx * qx + qy * qy)
					local posM = math.exp(-(math.max(0, rxy - rho) / ra) ^ 2) * (1.2 - 0.9 * clamp01((mbz - rho - cz) / rzz))
					local leak = clamp01(lo_ + lg_ * math.noise(mbx * lf_ + 0.37, mby * lf_ + 0.11, mbz * lf_ + ph * 0.35))
					local lk = lerp(leak, 0.6 + 0.4 * leak, fk)
					local base = G * deep * g * lk
					local gflash = math.min(1, g)
					local fkd = (0.06 + 0.94 * deep) * gflash
					-- the flash events that can reach this circle at all (its centre less its radius within 2.5 sigma),
					-- and the most they add anywhere on it; each sample below takes them at its own point (seam_paint)
					local nf, fmax = 0, 0
					for q = 1, nfl do
						local fe = FL[q]
						local ex, ey, ez = mbx - fe.x, mby - fe.y, mbz - fe.z
						local reach = 2.5 * fe.s + rho
						local e2 = ex * ex + ey * ey + ez * ez
						if e2 < reach * reach then
							nf += 1
							FE[nf] = fe
							local dd = math.sqrt(e2) - rho
							fmax += dd > 0 and fe.a * math.exp(-dd * dd / fe.s2) or fe.a
						end
					end
					if base * posM * hotMax + fmax * fkd * (0.45 + 0.55 * posM) >= 0.10 then
						-- sample its circle; a sample inside any other lump is hidden. Only a neighbour of i that reaches
						-- the circle at all can hide a point of it: those first, then each sample against them alone
						local u = perpB(nrm)
						local v = nrm:Cross(u)
						local nc = 0
						local nbl = SM.nb[i]
						if nbl then
							for _, l in ipairs(nbl) do
								if l ~= j and On[l] then
									local rl = R[l] - 0.03
									if rl > 0 then
										local dm = m - C[l]
										local reach = rl + rho
										if dm.X * dm.X + dm.Y * dm.Y + dm.Z * dm.Z < reach * reach then
											nc += 1
											CNC[nc], CNR[nc] = C[l], rl * rl
										end
									end
								end
							end
						end
						local okAll, okAny = true, false
						for s = 1, N do
							local p = m + (u * cosT[s] + v * sinT[s]) * rho
							local free = true
							for q = 1, nc do
								local dp = p - CNC[q]
								if dp.X * dp.X + dp.Y * dp.Y + dp.Z * dp.Z < CNR[q] then
									free = false
									break
								end
							end
							SP[s], SOK[s] = p, free
							if free then okAny = true else okAll = false end
						end
						if okAny then
							-- the runs round the circle, each one sample into the lump at both ends (the tube dives in)
							local nr = 0
							if okAll then
								nr = 1
								RS[1], RL[1] = 1, N + 1
							else
								local s0 = 1
								while SOK[s0] do s0 += 1 end
								local cur, clen = nil, 0
								for k2 = 0, N - 1 do
									local idx = ((s0 + k2) % N) + 1
									if SOK[idx] then
										if not cur then
											cur = idx - 1
											if cur < 1 then cur = N end
											clen = 1
										end
										clen += 1
									elseif cur then
										clen += 1
										nr += 1
										RS[nr], RL[nr] = cur, clen
										cur = nil
									end
								end
								if cur then
									nr += 1
									RS[nr], RL[nr] = cur, clen
								end
							end
							local rad0 = math.max(t1_, math.min(t2_, t0_ * math.min(ri, rj)))
							local sqRho = rho ^ 0.5
							for r = 1, nr do
								local st, len = RS[r], RL[r]
								local emax, hsum = 0, 0
								for t = 0, len - 1 do
									local idx = ((st - 1 + t) % N) + 1
									local p = SP[idx]
									local pbx, pby, pbz = p.X, p.Y, belly + p.Z * SQ_G
									local qx2, qy2, qz2 = pbx - cx, pby - cy, pbz - cz
									local pos = math.exp(-((qx2 * qx2 + qy2 * qy2) / (ra * ra))) * (1.2 - 0.9 * clamp01(qz2 / rzz))
									local hot = clamp01(0.5 + 0.62 * math.noise(pbx * fq + hx, pby * fq + hy, pbz * fq + hz)) ^ sh
									local e = G * deep * pos * lerp(0.05 + 1.7 * hot, 0.55 + 0.9 * hot, fk) * g * lk
									if nf > 0 then
										local fsum = 0
										for q = 1, nf do
											local fe = FE[q]
											local ex, ey, ez = pbx - fe.x, pby - fe.y, pbz - fe.z
											local e2 = ex * ex + ey * ey + ez * ez
											if e2 < 6.25 * fe.s2 then fsum += fe.a * math.exp(-e2 / fe.s2) end
										end
										e += fsum * fkd * (0.45 + 0.55 * pos)
									end
									local endK = (t > 0 and t < len - 1) and 1 or 0.55
									local heat = clamp01(0.30 + 0.62 * e)
									RE[t + 1], RH[t + 1] = e, heat
									RR[t + 1] = rad0 * (0.5 + 1.2 * clamp01(e)) * endK * clamp01((e - 0.10) / 0.15)
									RG[t + 1] = gwk * clamp01((e - need * 0.5) / 1.0) * ((t > 0 and t < len - 1) and 1 or 0.35)
									hsum += heat
									if e > emax then emax = e end
									-- a seam light candidate, kept only while it is among the KL brightest so far
									if e > 0.25 then
										local w = e * sqRho
										local slotI, at = nil, nil
										if nL < KL then
											nL += 1
											slotI, at = nL, nL
										elseif w > LCW[LORD[KL]] then
											slotI, at = LORD[KL], KL
										end
										if slotI then
											LCW[slotI], LCE[slotI], LCH[slotI], LCI[slotI], LCJ[slotI] = w, e, heat, i, j
											LCT[slotI] = (idx - 1) * step
											LCX[slotI], LCY[slotI], LCZ[slotI] = pbx, pby, pbz
											while at > 1 and LCW[LORD[at - 1]] < w do
												LORD[at] = LORD[at - 1]
												at -= 1
											end
											LORD[at] = slotI
										end
									end
								end
								if emax >= 0.10 then
									local glow = len >= 3 and emax >= need
									local gcol = COL.Base:Lerp(COL.Light, clamp01((hsum / len - 0.3) / 0.6))
									local th0 = (st - 1) * step
									-- cut into pieces of <= SeamPiece steps, each one Beam
									local a0 = 0
									while a0 < len - 1 do
										local b0 = math.min(a0 + piece, len - 1)
										local radMax, pe = 0, 0
										for t = a0, b0 do
											if RR[t + 1] > radMax then radMax = RR[t + 1] end
											if RE[t + 1] > pe then pe = RE[t + 1] end
										end
										if radMax >= 0.01 then
											nP += 1
											PI[nP], PJ[nP] = i, j
											PT0[nP], PT1[nP] = th0 + a0 * step, th0 + b0 * step
											PE[nP], PRAD[nP], POFF[nP], PCNT[nP] = pe, radMax, nK + 1, b0 - a0 + 1
											PGL[nP], PGC[nP] = glow, gcol
											-- this piece's identity across solves: the lump pair and the sample it starts on
											PKEY[nP] = (i * 1024 + j) * 64 + ((st - 1 + a0) % N)
											for t = a0, b0 do
												nK += 1
												KE[nK], KH[nK], KR[nK], KG[nK] = RE[t + 1], RH[t + 1], RR[t + 1], RG[t + 1]
											end
										end
										a0 = b0
									end
								end
							end
						end
					end
				end
			end
		end
	end
	-- the brightest SeamCap pieces get the Beams: a histogram cut, no sort
	local cap = storm.Q.SeamCap
	local keep = 0
	if nP <= cap then
		for k = 1, nP do KEEP[k] = k end
		keep = nP
	else
		local emx = 0
		for k = 1, nP do
			if PE[k] > emx then emx = PE[k] end
		end
		for b = 1, NBINS do HB[b] = 0 end
		local scale = NBINS / math.max(emx, 1e-6)
		for k = 1, nP do
			local b = math.min(NBINS, math.floor(PE[k] * scale) + 1)
			PB[k] = b
			HB[b] += 1
		end
		local acc, tb = 0, NBINS
		while tb > 1 and acc + HB[tb] < cap do
			acc += HB[tb]
			tb -= 1
		end
		local room = cap - acc
		for k = 1, nP do
			local b = PB[k]
			if b > tb or (b == tb and room > 0) then
				if b == tb then room -= 1 end
				keep += 1
				KEEP[keep] = k
			end
		end
	end
	-- each kept piece on the Beam it had at the last solve where it can (the same crease run: its sequences are only
	-- rewritten when they change), the rest on the lowest free ones
	local prevMap, map = SM.keyEl, SM.keyElNext
	table.clear(map)
	table.clear(TAKEN)
	local hw, unplaced = 0, 0
	for q = 1, keep do
		local c = KEEP[q]
		local el = prevMap[PKEY[c]]
		if el and not TAKEN[el] then
			TAKEN[el] = c
			if el > hw then hw = el end
		else
			unplaced += 1
			FREE[unplaced] = c
		end
	end
	local nextFree = 1
	for q = 1, unplaced do
		while TAKEN[nextFree] do nextFree += 1 end
		TAKEN[nextFree] = FREE[q]
		if nextFree > hw then hw = nextFree end
		nextFree += 1
	end
	local brK = kit.flat and FLAT_BRIGHTNESS or 1
	for el = 1, math.max(hw, SM.nEl) do
		local c = TAKEN[el]
		if c then
			local E = seamEl(storm, kit, el)
			map[PKEY[c]] = el
			E.i, E.j, E.th0, E.th1 = PI[c], PJ[c], PT0[c], PT1[c]
			local radMax, cnt, off = PRAD[c], PCNT[c], POFF[c]
			local w = 2 * radMax
			if math.abs(E.w - w) > 0.01 then
				E.core.Width0, E.core.Width1 = w, w
				E.w = w
			end
			local z = T.SeamZ * radMax
			if math.abs(E.z - z) > 0.01 then
				E.core.ZOffset = z
				E.z = z
			end
			local br = NEON_K * (0.55 + 0.65 * math.min(1.2, PE[c])) * brK
			if math.abs(E.br - br) > 0.02 then
				E.core.Brightness = br
				E.br = br
			end
			-- its sequences, quantised, and written only when a value moved
			local qT, qC = E.qT, E.qC
			if not qT then
				qT, qC = {}, {}
				E.qT, E.qC = qT, qC
			end
			local same = E.cnt == cnt
			local gwMax = 0
			for t = 0, cnt - 1 do
				local q = off + t
				if KG[q] > gwMax then gwMax = KG[q] end
				local tv = math.floor((1 - clamp01(KR[q] / radMax) ^ 0.8) * QT + 0.5)
				local col = heatCol(KH[q])
				local cv = packCol(col)
				SCOL[t + 1] = col
				if qT[t + 1] ~= tv or qC[t + 1] ~= cv then
					same = false
					qT[t + 1], qC[t + 1] = tv, cv
				end
			end
			if not same then
				E.cnt = cnt
				local kpT, kpC = kpList(KPT, cnt), kpList(KPC, cnt)
				for t = 0, cnt - 1 do
					local tm = t / (cnt - 1)
					kpT[t + 1] = NumberSequenceKeypoint.new(tm, qT[t + 1] / QT)
					kpC[t + 1] = ColorSequenceKeypoint.new(tm, SCOL[t + 1])
				end
				E.core.Transparency = NumberSequence.new(kpT)
				E.core.Color = ColorSequence.new(kpC)
			end
			local glow = PGL[c] and gwMax > 0.05
			E.hasGlow = glow
			if glow then
				if math.abs(E.gw - gwMax) > 0.01 then
					E.glow.Width0, E.glow.Width1 = gwMax, gwMax
					E.gw = gwMax
				end
				local gz = z + T.SeamGlowZ
				if math.abs(E.gz - gz) > 0.01 then
					E.glow.ZOffset = gz
					E.gz = gz
				end
				local gb = T.SeamGlow[3] * brK
				if math.abs(E.gbr - gb) > 0.01 then
					E.glow.Brightness = gb
					E.gbr = gb
				end
				local qG = E.qG
				if not qG then
					qG = {}
					E.qG = qG
				end
				local gsame = E.gcnt == cnt
				for t = 0, cnt - 1 do
					local gv = math.floor((1 - GLOW_ALPHA * clamp01(KG[off + t] / gwMax)) * QT + 0.5)
					if qG[t + 1] ~= gv then
						gsame = false
						qG[t + 1] = gv
					end
				end
				if not gsame then
					E.gcnt = cnt
					local kpG = kpList(KPG, cnt)
					for t = 0, cnt - 1 do kpG[t + 1] = NumberSequenceKeypoint.new(t / (cnt - 1), qG[t + 1] / QT) end
					E.glow.Transparency = NumberSequence.new(kpG)
				end
				local gk = packCol(PGC[c])
				if E.gcol ~= gk then
					E.glow.Color = ColorSequence.new(PGC[c])
					E.gcol = gk
				end
			end
			E.live = true
		else
			local E = kit.els[el]
			if E then
				E.live = false
				if E.on then
					E.core.Enabled = false
					E.on = false
				end
				if E.gon then
					E.glow.Enabled = false
					E.gon = false
				end
			end
		end
	end
	SM.nEl = hw
	SM.keyEl, SM.keyElNext = map, prevMap
	-- the seam lights: the brightest crease points, 5 studs apart (the candidates are already brightest first)
	local lights = SM.lights
	local nl = 0
	local want = storm.Q.SeamLights
	for q = 1, nL do
		if nl >= want then break end
		local c = LORD[q]
		local px, py, pz = LCX[c], LCY[c], LCZ[c]
		local far = true
		for r = 1, nl do
			local Lr = lights[r]
			local ex, ey, ez = Lr.x - px, Lr.y - py, Lr.z - pz
			if ex * ex + ey * ey + ez * ez < 25 then
				far = false
				break
			end
		end
		if far then
			nl += 1
			local Lc = lights[nl]
			if not Lc then
				Lc = {}
				lights[nl] = Lc
			end
			Lc.i, Lc.j, Lc.th, Lc.e, Lc.heat, Lc.x, Lc.y, Lc.z = LCI[c], LCJ[c], LCT[c], LCE[c], LCH[c], px, py, pz
		end
	end
	SM.nLights = nl
end
end

local stepSeams
do
--- The crease circle of lumps i and j right now: centre, radius and its frame (sphere space), or nil.
local function creaseNow(storm, i, j)
	local On = storm.On
	if not (On[i] and On[j]) then return nil end
	local C, R = storm.C, storm.R
	local ci, ri, rj = C[i], R[i], R[j]
	local dv = C[j] - ci
	local d = dv.Magnitude
	if d >= ri + rj or d <= math.abs(ri - rj) or d < 1e-4 then return nil end
	local a = (d * d + ri * ri - rj * rj) / (2 * d)
	local rho2 = ri * ri - a * a
	if rho2 < 0.0025 then return nil end
	local nrm = dv / d
	local u = perpB(nrm)
	return ci + nrm * a, math.sqrt(rho2), u, nrm:Cross(u)
end

--- An attachment frame at `pos` (host-relative) with its X axis (a Beam's CurveSize axis) along `x`.
local function frameX(pos, x)
	local up = math.abs(x.Y) < 0.9 and UP or Vector3.xAxis
	return CFrame.fromMatrix(pos, x, x:Cross(up).Unit)
end

--- Every live seam piece re-laid on its crease as the lumps are posed now: the arc's two ends and their Bezier handles
--- (only on a frame the lumps moved or the seams were solved: an off-tick at CloudHz 30 and the hitpause re-lay nothing).
local function seamPlace(storm)
	local SM = storm.seam
	local kit = SM.kit
	local host = storm.O
	for k = 1, SM.nEl do
		local E = kit.els[k]
		local shown = false
		if E and E.live then
			local m, rho, u, v = creaseNow(storm, E.i, E.j)
			if m then
				local th0, th1 = E.th0, E.th1
				local c0, s0, c1, s1 = math.cos(th0), math.sin(th0), math.cos(th1), math.sin(th1)
				local p0 = m + (u * c0 + v * s0) * rho
				local p1 = m + (u * c1 + v * s1) * rho
				local hk = 4 / 3 * math.tan((th1 - th0) / 4) * rho
				local q0 = p0 + (v * c0 - u * s0) * hk
				local q1 = p1 - (v * c1 - u * s1) * hk
				local P0, P1 = sphereW(storm, p0), sphereW(storm, p1)
				local ax0, ax1 = sphereW(storm, q0) - P0, P1 - sphereW(storm, q1)
				local cs0, cs1 = ax0.Magnitude, ax1.Magnitude
				if cs0 > 1e-4 and cs1 > 1e-4 then
					E.a0.CFrame = frameX(P0 - host, ax0 / cs0)
					E.a1.CFrame = frameX(P1 - host, ax1 / cs1)
					if math.abs(E.cs0 - cs0) > 0.03 * cs0 + 0.005 then
						E.core.CurveSize0, E.glow.CurveSize0 = cs0, cs0
						E.cs0 = cs0
					end
					if math.abs(E.cs1 - cs1) > 0.03 * cs1 + 0.005 then
						E.core.CurveSize1, E.glow.CurveSize1 = cs1, cs1
						E.cs1 = cs1
					end
					shown = true
				end
			end
		end
		if E then
			if E.on ~= shown then
				E.core.Enabled = shown
				E.on = shown
			end
			local gshow = shown and E.hasGlow
			if E.gon ~= gshow then
				E.glow.Enabled = gshow
				E.gon = gshow
			end
		end
	end
	-- the seam lights ride their creases too, pushed 0.9 out of the V: placed here, asked for every frame (seamLights)
	for n = 1, SM.nLights do
		local Lc = SM.lights[n]
		local m, rho, u, v = creaseNow(storm, Lc.i, Lc.j)
		if m then
			local p = m + (u * math.cos(Lc.th) + v * math.sin(Lc.th)) * rho
			local pw, mw = sphereW(storm, p), sphereW(storm, m)
			local o = pw - mw
			o = o.Magnitude > 1e-4 and o.Unit or UP
			Lc.wp = pw + o * 0.9
			Lc.col = COL.Base:Lerp(COL.Light, clamp01(Lc.heat))
		else
			Lc.wp = nil
		end
	end
end

--- The seam lights where seamPlace last put them (every frame: an unasked light is switched off; the brightest
--- SeamShadows cast shadows).
local function seamLights(storm)
	local SM = storm.seam
	for n = 1, SM.nLights do
		local Lc = SM.lights[n]
		if Lc.wp then
			reqLight(storm, LKEY.seam[n], Lc.wp, T.SeamLight[1] * math.min(1.4, Lc.e), T.SeamLight[2], Lc.col, 10 + n,
				n <= storm.Q.SeamShadows)
		end
	end
end

stepSeams = function(storm, V)
	local SM = storm.seam
	local now = os.clock()
	-- a set-piece flash (the punch, the fan, a re-strike, THE FLASH: storm.syncT) is solved on the frame it starts, not
	-- up to a solve period later: the reduced rate must never leave the cloud's white behind the exposure kick
	local sync = false
	local st, k = storm.syncT, SM.syncI
	while st[k] and st[k] <= V + 1e-9 do
		sync = true
		k += 1
	end
	SM.syncI = k
	local solved = false
	if (sync or now >= SM.next) and V ~= SM.lastV then
		-- (half the rate for a storm SeamFar studs off: its seams are a few pixels wide)
		local far = (CTX.camPos - storm.O).Magnitude > T.SeamFar
		SM.next = now + 1 / (storm.Q.SeamHz * (far and 0.5 or 1))
		SM.lastV = V
		debug.profilebegin("CascadeFX seamSolve")
		seamSolve(storm, V)
		debug.profileend()
		solved = true
	end
	if solved or storm.posed then seamPlace(storm) end
	seamLights(storm)
end
end

----------------------------------------------------------------------------------------------------
-- 1 THE WINDUP at the caster's hands (cascade_bl.plan_windup / windup_frame). tau = the showcase's seconds.
----------------------------------------------------------------------------------------------------
local planWindup, stepWindup
do
planWindup = function(rng)
	local arcs = {}
	for si = 1, 2 do
		local t = 0.14
		while t < W0 - 0.02 do
			local q = span(t, 0.14, W0)
			local rate = lerp(T.HandArcRate[1], T.HandArcRate[2], q)
			arcs[#arcs + 1] = { side = si, s = t, d = rng:NextUnitVector(),
				r0 = rng:NextNumber(T.HandArcFrom[1], T.HandArcFrom[2]), seed = rng:NextInteger(1, 1000000),
				swirl = rng:NextNumber(0.6, 1.1) * (rng:NextNumber() < 0.5 and -1 or 1) }
			t += rng:NextNumber(0.6, 1.4) / rate
		end
	end
	local bridges = {}
	local t = T.Bridge[1]
	while t < T.Bridge[2] do
		bridges[#bridges + 1] = { s = t, seed = rng:NextInteger(1, 1000000) }
		t += T.Bridge[3] * rng:NextNumber(0.7, 1.3)
	end
	local motes = {}
	for si = 1, 2 do
		local tt = 0.05
		while tt < W0 do
			motes[#motes + 1] = { side = si, s = tt, d = rng:NextUnitVector(), r0 = rng:NextNumber(0.8, 1.5),
				life = rng:NextNumber(0.14, 0.22) }
			tt += rng:NextNumber(0.6, 1.4) / 30.0
		end
	end
	return { arcs = arcs, bridges = bridges, motes = motes }
end

--- `v` turned about the world vertical by `a` (the showcase's rz on an arc's start direction).
local function ryv(v, a)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end

local function drawWindup(storm, g, tau, hands, fp)
	local fs = fp and T.FpScale or 1
	local q = span(tau, 0, W0)
	local I = 0.35 + 0.65 * smooth(q)
	local fl = span(tau, W0 - T.SetFlash, W0) * (1 - span(tau, W0, W0 + 0.05))
	if storm.calm then fl = 0 end                    -- (2026-10-19, audit P5D-03) Reduce Flashing: no set-flash whitening
	local gone = smooth(span(tau, W0, W0 + 0.06))                   -- the charge leaves the hands at the launch
	local fno = math.floor(tau * 60 + 1e-6)
	local HS, HL = T.HandSeed, T.HandLight
	local warm = smooth(span(tau, 0.04, 0.30))
	-- first person: the hand's glow and seed star sized by angle (FpHandCap x the distance), so the two at the top of
	-- the view stay a hand's glow, never half of it
	local hcap = fp and T.FpHandCap or nil
	if gone < 1 then
		for si = 1, 2 do
			local h = hands[si]
			local s = lerp(HS[1], HS[2], smooth(q)) * (1 + 0.8 * fl) * (1 - gone) * fs
			star(storm, g, h, s, 6.0 * tau + (si - 1), 1.4 * I * (1 + 0.6 * fl), 1.0 * I, warm, 0.35 * fs,
				COL.Light:Lerp(WHITE, 0.7 * fl), hcap)
			sprite(storm, g, "soft", h, s * 1.6 * PARTICLE_QUAD, 0, COL.Dark:Lerp(COL.Base, warm), 1, HS[3] * I * (1 - gone),
				0.35 * fs, hcap)
			reqLight(storm, LKEY.hand[si], h + UP * (0.5 * fs),
				lerp(HL[1], HL[2], smooth(q)) * (1 + fl) * (1 - gone) * (fp and T.FpLight or 1), HL[3] * fs,
				COL.Dark:Lerp(COL.Base, warm), 6, false)
		end
	end
	local cw, gw, cb, gb = T.HandArc[1], T.HandArc[2], T.HandArc[3], T.HandArc[4]
	local W = storm.wind
	for _, A in ipairs(W.arcs) do
		local u = (tau - A.s) / T.HandArcLife
		if u >= 0 and u < 1 then
			local c = hands[A.side]
			local r = lerp(A.r0, 0.15, u ^ 1.4) * fs
			local dd = ryv(A.d, A.swirl * u)
			local ar = Random.new(A.seed + fno)
			local pts = Kit.jag(c + dd * r, c, 2, 0.30 * r, ar)
			local a = u < 0.40 and 1 or math.max(0, (0.65 - u) / 0.25)
			if u < 0.22 then
				local acc = arclen(pts)
				pts = cutPath(pts, acc, 0, acc[#acc] * span(u, 0, 0.22))
			end
			if a > 0.01 and #pts >= 2 then
				beamDraw(storm, g, pts, cw * fs, gw * fs, COL.Light, cb * I, COL.Base, gb * I, optv(a))
			end
		end
	end
	for _, B in ipairs(W.bridges) do
		local age = tau - B.s
		if age >= 0 and age < 2 * F then
			local a_, b_ = hands[1], hands[2]
			local len = (a_ - b_).Magnitude
			if len > 0.05 then
				local pts = Kit.jag(a_, b_, 3, 0.30 * len, Random.new(B.seed + fno))
				local m = #pts
				for i = 1, m do pts[i] = pts[i] + UP * (0.35 * len * math.sin(math.pi * (i - 1) / (m - 1))) end
				beamDraw(storm, g, pts, cw * 1.2 * fs, gw * 1.1 * fs, COL.Light, cb * 1.1 * I, COL.Base, gb * I, optv(1))
			end
		end
	end
	if tau < W0 then
		for _, Mo in ipairs(W.motes) do
			local u = (tau - Mo.s) / Mo.life
			if u >= 0 and u < 1 then
				local p = hands[Mo.side] + Mo.d * (lerp(Mo.r0, 0.1, easeInQuad(u)) * fs)
				sprite(storm, g, "soft", p, 0.08 * PARTICLE_QUAD * fs, 0, COL.Light, 1 - 0.6 * u, 2.0 * I, 0.2 * fs, hcap)
			end
		end
	end
	-- the launch: the two hands' arcs meet over the head and go up as one bolt into the sky
	local Ln = T.Launch
	local dur = Ln[1]
	if tau >= W0 and tau < W0 + dur + 0.05 then
		local u = (tau - W0) / dur
		local h0, h1 = hands[1], hands[2]
		local base = (h0 + h1) / 2 + UP * (1.6 * fs)
		local lr = Random.new(5150 + math.floor(fno / 2) + storm.seed % 1000)
		local top = base + storm.cRight * 0.8 + storm.cFwd * 1.5 + UP * Ln[2]
		local up = Kit.jag(base, top, 5, 1.6, lr, 0.55)
		local a = u < 1 and 1 or math.max(0, 1 - (u - 1) / (0.05 / dur))
		for si = 1, 2 do
			local pts = Kit.jag(hands[si], base, 2, 0.35 * fs, lr)
			for k = 2, #up do pts[#pts + 1] = up[k] end
			local acc = arclen(pts)
			local shown = cutPath(pts, acc, acc[#acc] * clamp01((u - 0.45) / 0.55), acc[#acc])
			if #shown >= 2 and a > 0.01 then
				-- the showcase's uniform core; in first person thin near the lens, full out in the sky
				local cws, gws = table.create(#shown), table.create(#shown)
				for k, p in ipairs(shown) do
					local near = fp and math.max(fs, math.min(1, (p - CTX.camPos).Magnitude / 6)) or 1
					cws[k], gws[k] = Ln[3] * near, Ln[4] * near
				end
				beamDraw(storm, g, shown, cws, gws, WHITE_HOT, Ln[5], COL.Base, Ln[6], optv(a))
			end
		end
		reqLight(storm, "launch", base + UP * 3.0, 3.0 * a * (1 - clamp01(u)), 14, COL.Light, 7, false)
	end
end

stepWindup = function(storm, t)
	local g = group(storm, "wind")
	local W = storm.W
	if not storm.wind or W <= 0.05 or not storm.Character then
		clearG(g)
		return
	end
	local tau = t * W0 / W
	if tau < 0 or tau > W0 + T.Launch[1] + 0.06 then
		clearG(g)
		return
	end
	-- the hands: the Viewmodel's fists for the caster in first person, else the body's grips
	local hands = storm.handPos
	local fp = storm.Own and firstPersonNow()
	if fp then
		for si, side in ipairs(SIDES) do
			local ok, cp = pcall(Kit.castPoint, side)
			if ok and cp then hands[si] = cp.WorldPosition else fp = false end
		end
	end
	if not fp then
		for si, side in ipairs(SIDES) do
			local a = storm.handAtts and storm.handAtts[side]
			if not (a and a.Parent) then
				local ok, h = pcall(Kit.hands, storm.Character)
				storm.handAtts = (ok and type(h) == "table") and h or {}
				a = storm.handAtts[side]
			end
			if not a then
				clearG(g)
				return
			end
			hands[si] = a.WorldPosition
		end
	end
	local root = storm.Character:FindFirstChild("HumanoidRootPart")
	local cf = fp and CTX.camCF or ((root and root:IsA("BasePart")) and root.CFrame or CTX.camCF)
	local lv = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	storm.cFwd = lv.Magnitude > 1e-3 and lv.Unit or storm.BY
	storm.cRight = storm.cFwd:Cross(UP)
	beginG(g)
	drawWindup(storm, g, tau, hands, fp)
	finishG(g)
	-- the white set-flash's Bloom (the showcase's +0.25, a whole-frame kick its onlooking camera sees): for whoever
	-- watches the hands -- faded out SetFlashReach studs from them, and for a first-person onlooker as they come within
	-- FpBloomNear (bloomPulse's `anyView`: the VoltaicKit patch) -- but never for the caster in first person, the Kit's
	-- reason for its rule (the kick would bloom their own raised arms white). Reduce Flashing: the Kit drops it.
	if not storm.setFlashed and tau >= W0 - T.SetFlash then
		storm.setFlashed = true
		if tau < W0 + 0.05 and not (storm.Own and (fp or CTX.fp)) and not storm.calm then
			local d = (CTX.camPos - (hands[1] + hands[2]) * 0.5).Magnitude
			local k = 1 - span(d, T.SetFlashReach[1], T.SetFlashReach[2])
			if CTX.fp then k *= smooth(span(d, T.FpBloomNear[1], T.FpBloomNear[2])) end
			k *= storm.ThinEnemy and 0.5 or 1
			if k > 0.01 then pcall(Kit.bloomPulse, 0.25 * k, 0, 0.05, T.SetFlash, 0, CTX.fp) end
		end
	end
end
end

----------------------------------------------------------------------------------------------------
-- 3 THE TELEGRAPH (cascade_bl.plan_telegraph / telegraph_frame): walkers hopping over the cloud, redrawn at 30 Hz
----------------------------------------------------------------------------------------------------
local planTelegraph, stepTelegraph
do
planTelegraph = function(storm, rng)
	local hops = {}
	local ext = storm.extList
	local nExt = #ext
	if nExt < 2 then return hops end
	local t0, t1 = T.Tel[1], T.Tel[2]
	local nw = math.max(1, math.floor(T.Walkers[2] * storm.Q.Walkers + 0.5))
	local w0 = math.max(1, math.floor(T.Walkers[1] * storm.Q.Walkers + 0.5))
	local anchor = Vector3.new(0, 0, 14)
	for w = 0, nw - 1 do
		local uw = (w < w0) and 0 or ((w - w0 + 1) / (nw - w0 + 1)) ^ 0.6
		local S = lerp(t0, t1 - 0.06, uw) + rng:NextNumber(0, 0.04)
		local cur = ext[rng:NextInteger(1, nExt)]
		local air = nil
		local guard = 0
		while S < t1 and guard < 400 do
			guard += 1
			local u = span(S, t0, t1)
			local dt = lerp(T.Hop[1], T.Hop[2], u * u) * rng:NextNumber(0.7, 1.3)
			local lo = lerp(T.HopLen[1][1], T.HopLen[2][1], u)
			local hi = lerp(T.HopLen[1][2], T.HopLen[2][2], u)
			local err = lerp(T.Err[1], T.Err[2], u ^ 1.5)
			local P0 = EXT_HOME[cur]
			if air == nil and rng:NextNumber() < T.Reach[3] + T.Reach[1] * u * u then
				-- a leap OFF the cloud, out along the surface, and back next hop
				local off = (EXT_N[cur] + rng:NextUnitVector() * 0.5).Unit * rng:NextNumber(T.Reach[2][1], T.Reach[2][2])
				hops[#hops + 1] = { s = S, u = u, seed = rng:NextInteger(1, 1000000), fork = rng:NextNumber() < 0.6,
					ak = 1, ae = cur, bk = 2, be = cur, boff = off }
				air = { cur, off }
			else
				-- the storm turns clockwise from above: early hops follow it, late ones go anywhere
				local q = P0 - anchor
				local tang = Vector3.new(q.Y, -q.X, 0)
				tang = tang.Magnitude > 1e-3 and tang.Unit or Vector3.xAxis
				local best, bs = nil, -9
				for _ = 1, 40 do
					local jx = ext[rng:NextInteger(1, nExt)]
					local dvec = EXT_HOME[jx] - P0
					local L = dvec.Magnitude
					if L >= lo and L <= hi then
						local sc = (1 - err) * (dvec / L):Dot(tang) + err * rng:NextNumber(-1, 1)
						if sc > bs then best, bs = jx, sc end
					end
				end
				if not best then best = ext[rng:NextInteger(1, nExt)] end
				local hop = { s = S, u = u, seed = rng:NextInteger(1, 1000000), fork = rng:NextNumber() < 0.15 + 0.45 * u,
					bk = 1, be = best }
				if air then hop.ak, hop.ae, hop.aoff = 2, air[1], air[2] else hop.ak, hop.ae = 1, cur end
				hops[#hops + 1] = hop
				air = nil
				cur = best
			end
			S += dt
		end
	end
	return hops
end

--- A hop end at the lumps' positions now: a surface point riding its lump, or an air point off one. (world, its
--- outward normal in the world, its Blender-world position) or nil.
local function extWorld(storm, kind, ei, off)
	local li = EXT_LI[ei]
	if not storm.On[li] then return nil end
	local r = storm.R[li]
	if r < 0.2 then return nil end
	local p = storm.C[li] + EXT_D[ei] * (r * 1.02)
	local pb = Vector3.new(p.X, p.Y, storm.belly + p.Z * SQ_G)
	if kind == 2 and off then pb += off end
	return bw(storm, pb), bdir(storm, EXT_N[ei]), pb
end

stepTelegraph = function(storm, V)
	local g = group(storm, "tel")
	local t0, t1 = T.Tel[1], T.Tel[2]
	-- IN PLAY (2026-09-28): the arcs stop on the fan's own frame (the showcase let their last hops run 0.06 s on). The fan
	-- replaces them on screen, and their tail cost ~6 ms on the heaviest frame of the storm (measured: 37 ms of Lua there).
	if storm.Cancelled or V < t0 or V >= t1 then
		clearG(g)
		return
	end
	-- re-jagged TelHz times a second (the showcase's 60 at ULTRA, 30 below); its one-frame windows (an arc's ember, a
	-- landing's star) last one tick, so a 30 Hz redraw never skips one
	local hz = storm.Q.TelHz or 30
	if storm.calm then hz /= 3 end                   -- (2026-10-19, audit P5D-03) Reduce Flashing: 10 / 20 Hz re-jag
	local tick = math.floor(V * hz + 1e-6)
	if tick == storm.telTick then return end
	storm.telTick = tick
	beginG(g)
	local cw, gw, cb, gb = T.TelArc[1], T.TelArc[2], T.TelArc[3], T.TelArc[4]
	local wo, bo = T.TelArcOver[1], T.TelArcOver[2]
	local depth = storm.Q.TelDepth
	local frame = 1 / hz
	for _, H in ipairs(storm.hops) do
		local life = lerp(T.TelLife[1], T.TelLife[2], H.u)
		local age = V - H.s
		if age >= 0 and age < life + frame then
			local P0, n0 = extWorld(storm, H.ak, H.ae, H.aoff)
			local P1, n1, P1b = extWorld(storm, H.bk, H.be, H.boff)
			if P0 and P1 then
				local L = (P1 - P0).Magnitude
				if L >= 0.3 then
					local ar = Random.new(H.seed + tick)
					local pts = Kit.jag(P0, P1, depth, 0.13 * L, ar, 0.55)
					local sb = n0 + n1
					local bul = sb.Magnitude > 1e-3 and sb.Unit or n0
					local m = #pts
					for i = 1, m do pts[i] = pts[i] + bul * (T.TelBulge * L * math.sin(math.pi * (i - 1) / (m - 1))) end
					local u = H.u
					local kw, kb = 1 + wo * u, 1 + bo * u
					if age >= life then
						beamDraw(storm, g, pts, cw * kw * 0.8, 0, COL.Dark, cb * 0.9, nil, 0, emberOpt(1))
					else
						local cool = 0.6 * clamp01(age / life)
						voltDraw(storm, g, pts, cw * kw, gw * kw, cb * kb, gb * kb, optv(1, cool, 0, H.seed * 7 + tick))
						if H.fork and m > 4 then
							local fb = pts[math.clamp(math.floor(m / 2) + 1 + ar:NextInteger(-1, 1), 1, m)]
							local fd = bul * 0.8 + perpR(P1 - P0) * ar:NextNumber(-1, 1)
							fd = fd.Magnitude > 1e-3 and fd.Unit or bul
							local fe = fb + fd * (L * ar:NextNumber(0.25, 0.45))
							voltDraw(storm, g, Kit.jag(fb, fe, 2, 0.15 * L, ar), cw * kw * 0.7, gw * 0.6, cb * 0.9 * kb, gb * 0.8,
								optv(1, cool, 0, H.seed * 7 + tick + 3, nil, nil, 1))
						end
						-- the snap where it lands: a star, and a kick of light into the seams round it
						if age < 1.5 * frame then
							star(storm, g, P1, 0.45 + 0.35 * u, ar:NextNumber(0, 6.3), 2.2, 1.2, 1, 0.5)
							if not H.snapped then
								H.snapped = true
								addSnap(storm, V, P1b, 0.5 + 0.4 * u)
							end
						end
					end
				end
			end
		end
	end
	finishG(g)
end
end

----------------------------------------------------------------------------------------------------
-- WHERE THE BOLTS LAND: the server's rule predicted at the fan; a CascadeStrike that arrives before its strike is
-- drawn re-aims it, one that arrives after (the usual case) only flashes a body the prediction missed
----------------------------------------------------------------------------------------------------
local QP = { overlap = nil, ray = nil }     -- the queries' params, made once

local function rootDrop(body, root)
	local hum = body:FindFirstChildOfClass("Humanoid")
	if hum and hum.RigType == Enum.HumanoidRigType.R15 then return hum.HipHeight + root.Size.Y / 2 end
	return 3
end

local applyHit, predictTargets
do
--- Whether the server could pick `m` for the caster (VoltaicHandler isEnemyBody): not the caster's body, no Bulwark Wall,
--- and a PLAYER only when Config.MayHurt allows it and they are not on the caster's Team (CombatCore.IsFriendly with
--- FriendlyFire off, the default). Anything that is not a player -- a training dummy -- always may.
local function mayStrike(storm, m)
	if m == storm.Character or m:GetAttribute("WallOwner") ~= nil then return false end
	-- (2026-10-19, audit P5D-11) the rest of the server's rule (VoltaicHandler isEnemyBody -> Core.IsFriendly): an ally
	-- dummy takes nothing, and a Decoy Double sides with its owner (the caster's own, or a friend's, is never struck)
	if m:GetAttribute("AllyDummy") then return false end
	local decoyOwner = m:GetAttribute("DecoyOwner")
	local caster = storm.Character and Players:GetPlayerFromCharacter(storm.Character)
	if decoyOwner ~= nil then
		local op = tonumber(decoyOwner) and Players:GetPlayerByUserId(tonumber(decoyOwner))
		if not op or op == caster then return false end
		return op.Character ~= nil and op.Character ~= m and mayStrike(storm, op.Character)
	end
	local victim = Players:GetPlayerFromCharacter(m)
	if not victim then return true end
	if not caster then return victim:GetAttribute("Zone") ~= "Hub" end
	if victim == caster then return false end
	local _, _, _, Config = Kit.libs()
	if Config and type(Config.MayHurt) == "function" then
		local ok, may = pcall(Config.MayHurt, caster, victim)
		if ok and may == false then return false end
	end
	return not (victim.Team ~= nil and victim.Team == caster.Team)
end

--- Every model with a live Humanoid and a root that has a part within `radius` of `point` that the caster may strike.
local function bodiesNear(storm, point, radius)
	local overlap = QP.overlap or OverlapParams.new()
	QP.overlap = overlap
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { Kit.fxFolder() }
	local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, point, radius, overlap)
	local out = {}
	if not ok or type(parts) ~= "table" then return out end
	local seen = {}
	for _, p in ipairs(parts) do
		local m = p.Parent
		if m and m:IsA("Model") and not seen[m] then
			seen[m] = true
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and root and root:IsA("BasePart") and mayStrike(storm, m) then out[#out + 1] = m end
		end
	end
	return out
end

local function groundAt(p, up, len, exclude)
	local rayParams = QP.ray or RaycastParams.new()
	QP.ray = rayParams
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = exclude and { Kit.fxFolder(), exclude } or { Kit.fxFolder() }
	local hit = workspace:Raycast(p + UP * up, -UP * len, rayParams)
	return hit and hit.Position or nil
end

local function bodyGround(body)
	local root = body:FindFirstChild("HumanoidRootPart")
	return groundAt(root.Position, 0, 12, body) or (root.Position - UP * rootDrop(body, root))
end

--- The body a strike at `at` connected with: the nearest live one whose root stands within `radius` (flat).
local function bodyAt(storm, at, radius)
	local best, bd = nil, radius
	for _, m in ipairs(bodiesNear(storm, at, radius + 3)) do
		local r = m.HumanoidRootPart.Position - at
		local d = Vector3.new(r.X, 0, r.Z).Magnitude
		if d <= bd and math.abs(r.Y) < 8 then best, bd = m, d end
	end
	return best
end

--- VoltaicTuning.Cascade.Spread (the server's filler points), else the contract's.
local function spreadTable()
	return (VTUN and type(VTUN.Spread) == "table" and #VTUN.Spread >= 1) and VTUN.Spread or FALLBACK.Spread
end

--- Where the server strikes bolt n when nobody is in the zone (VoltaicHandler strikeOnce: Spread[((n - 1) % #Spread) + 1]
--- at that fraction of the zone and that bearing from the point; its At is straight below it).
local function fillerAt(storm, n)
	local spread = spreadTable()
	local s = spread[((n - 1) % #spread) + 1]
	local a = math.rad(s[2])
	return storm.O + Vector3.new(math.cos(a), 0, math.sin(a)) * (s[1] * storm.zone)
end

local function setKnee(storm, f)
	local hv = f.g - storm.O
	hv = Vector3.new(hv.X, 0, hv.Z)
	f.knee = storm.hub + hv * f.kneeU - UP * f.kneeDrop
end

--- The dominant bolt's kinks: planMain's zigzag (the showcase's plan_main), ROOTED AT THE BELLY HUB (flag 9). Straight
--- down to the centre it is the showcase's own. To a body off the centre the channel LEANS EVENLY along its whole
--- length -- any path from the hub to a body at the zone's edge averages 42 degrees off vertical, and an even lean is
--- the one that tips no leg further (flag 9's "only the bottom leg leans" would lay that leg past 70 degrees) -- and its
--- swings turn to run ACROSS the lean, so a swing never adds to it, cut by MainLean[1] toward the zone's edge, with the
--- along-the-lean jitter cut by MainLean[2]. Measured on a replica of this plan (20,000 draws): the steepest leg of a
--- zone-edge strike sits at median 53 / p99 60 degrees off vertical, the showcase's own centre strike 51 / 61 (the
--- swings as they were, lined up with the lean: 63 / 69).
local function buildMainKinks(storm)
	local M = storm.main
	local top = storm.hub
	local bot = storm.mainG + UP * 0.05
	local lean = bot - top
	lean = Vector3.new(lean.X, 0, lean.Z)
	local ll = lean.Magnitude
	local ax, ay = storm.BX, storm.BY               -- the swing (Blender x) and its jitter (Blender y): the storm's
	local swingK, alongK = 1, 1
	if ll > 1e-3 then
		local L = lean / ll
		local P = L:Cross(UP)
		if P:Dot(storm.BX) < 0 then P = -P end
		local w = smooth(ll / 2)                       -- into the lean's frame over its first two studs (no flip)
		ax = storm.BX:Lerp(P, w)
		ax = ax.Magnitude > 1e-3 and ax.Unit or P
		ay = UP:Cross(ax)                              -- (= BY for ax = BX)
		swingK = 1 - T.MainLean[1] * clamp01(ll / math.max(1, storm.zone))
		alongK = 1 - T.MainLean[2] * w
	end
	local ks = { top }
	for i, u in ipairs(M.us) do
		local l = M.lat[i]
		ks[#ks + 1] = top:Lerp(bot, u) + ax * (l.X * swingK) + ay * (l.Y * alongK)
	end
	ks[#ks + 1] = bot
	M.ks = ks
	M.gen += 1
end

--- A CascadeStrike's At (`S`: the storm clock it arrived at). WHEN IT ARRIVES decides what it does. The server strikes
--- N at T0 + Strikes[N] and this client's clock is the server's (Kit.clock), so the payload normally lands the one-way
--- latency AFTER this client drew strike N on its prediction: then NOTHING ON THE GROUND MOVES -- the prediction is what
--- every client saw at the strike moment, and the scorch, the ring, the lights and the fork's hot spot stay where the
--- bolt landed -- and only a body the prediction missed gets its skeleton flash, late by that latency. One that arrives
--- BEFORE its strike is drawn (a slowed review, a clock running behind) re-aims fork N (1-4), or the dominant strike
--- leaning to its body (the centre when nobody is there). WHO WAS HIT is read off the server's own rule, not off this
--- client's copy of the bodies: an At on the server's filler point (FillerTol, with no body standing on it) struck
--- nobody; any other At struck a body, and the bolt goes THERE -- the server's copy of a sprinting target trails this
--- client's by the latency, and a body search round At would miss it and throw the climax back to the empty centre.
--- The skeleton flash takes the nearest live body within HitBodyRadius of it.
applyHit = function(storm, n, S)
	local at = storm.hitAt[n]
	if not at then return end
	local fl = fillerAt(storm, n)
	local onFiller = Vector3.new(at.X - fl.X, 0, at.Z - fl.Z).Magnitude < T.FillerTol
	local hit = not onFiller or bodyAt(storm, at, T.SkelRadius) ~= nil
	local body = hit and bodyAt(storm, at, T.HitBodyRadius) or nil
	if n <= 4 then
		local f = storm.forks[n]
		if not f then return end
		if f.fired then
			-- (a flash more than a quarter second late would read as a second, unseen strike: none)
			if body and body ~= f.body and S and S - f.at < 0.25 then storm.trigger(body, "fan", S) end
			return
		end
		if not f.g or (f.g - at).Magnitude > 0.5 then
			f.g = at
			setKnee(storm, f)
			f.gen += 1
		end
		f.body = body
	else
		if storm.hitFired then
			if body and body ~= storm.mainBody and S and S - storm.HIT < 0.25 then storm.trigger(body, "main", S) end
			return
		end
		local g = hit and at or storm.O
		if not storm.mainG or (storm.mainG - g).Magnitude > 0.5 then
			storm.mainG = g
			buildMainKinks(storm)
		end
		storm.mainBody = body
	end
end

predictTargets = function(storm, V)
	if storm.predDone or storm.Cancelled or V < T.Fan - 0.05 then return end
	storm.predDone = true
	local zone = storm.zone
	local list = {}
	for _, m in ipairs(bodiesNear(storm, storm.O, zone + 2)) do
		local r = m.HumanoidRootPart.Position - storm.O
		local d = Vector3.new(r.X, 0, r.Z).Magnitude
		if d <= zone then list[#list + 1] = { m = m, d = d, c = 0 } end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for n = 1, 5 do
		local best = nil
		for _, e in ipairs(list) do
			if not best or e.c < best.c then best = e end
		end
		local P = {}
		if best then
			best.c += 1
			P.body, P.g = best.m, bodyGround(best.m)
		elseif n == 5 then
			P.g = storm.O                                   -- nobody there: straight down at the centre
		else
			local p = fillerAt(storm, n)
			P.g = groundAt(p, 6, 26) or p
		end
		storm.pred[n] = P
	end
	for n = 1, 4 do
		local f = storm.forks[n]
		f.g, f.body = storm.pred[n].g, storm.pred[n].body
		setKnee(storm, f)
	end
	storm.mainG, storm.mainBody = storm.pred[5].g, storm.pred[5].body
	buildMainKinks(storm)
	for n = 1, 5 do
		if storm.hitAt[n] then applyHit(storm, n) end         -- (arrived before the fan: nothing is drawn yet)
	end
end
end

----------------------------------------------------------------------------------------------------
-- SPARKS, FLOOR SPOTS, THE FLASH KICKS
----------------------------------------------------------------------------------------------------
local function sparkEmitter(storm, big)
	local key = big and "sparkBig" or "sparkSmall"
	local pe = storm[key]
	if pe then return pe end
	if not storm.sparkHost then
		local host = inertPart("CascadeSparks")
		host.Parent = storm.Folder
		local att = Instance.new("Attachment")
		att.Parent = host
		storm.sparkHost, storm.sparkAtt = host, att
	end
	QP.sparkCol = QP.sparkCol or ColorSequence.new({ ColorSequenceKeypoint.new(0, COL.Light), ColorSequenceKeypoint.new(0.1, COL.Light),
		ColorSequenceKeypoint.new(0.5, COL.Base), ColorSequenceKeypoint.new(0.6, COL.Base), ColorSequenceKeypoint.new(1, EMBER_HALO) })
	pe = Instance.new("ParticleEmitter")
	pe.Name = key
	pe.Texture = SOFT_TEX
	pe.Rate = 0
	pe.Enabled = false
	pe.LightEmission = storm.flat and FLAT_EMISSION or 1
	pe.LightInfluence = 0
	pe.Brightness = 2.4 * (storm.flat and FLAT_BRIGHTNESS or 1)
	pe.Color = QP.sparkCol
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 1) })
	pe.Size = big and NumberSequence.new(0.42, 0.16) or NumberSequence.new(0.30, 0.12)
	pe.Squash = NumberSequence.new(2)
	pe.Orientation = Enum.ParticleOrientation.VelocityParallel
	pe.Drag = 1.6
	pe.Acceleration = Vector3.new(0, -60, 0)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Speed = big and NumberRange.new(12, 32) or NumberRange.new(8, 18)
	pe.Lifetime = big and NumberRange.new(0.5, 1.1) or NumberRange.new(0.35, 0.7)
	pe.Rotation = NumberRange.new(0)
	pe.RotSpeed = NumberRange.new(0)
	pe.LockedToPart = false
	pe.ZOffset = 0.2
	pe.TimeScale = storm.sparkTS or 1
	pe.Parent = storm.sparkAtt
	storm[key] = pe
	return pe
end

local function sparkBurst(storm, pos, big)
	local n = math.floor((big and T.Sparks[1] or T.Sparks[2]) * storm.Q.Sparks + 0.5)
	if n <= 0 then return end
	local pe = sparkEmitter(storm, big)
	storm.sparkHost.CFrame = CFrame.new(pos)
	pe:Emit(n)
end

--- A flat glow on the floor: the Soft image on a SurfaceGui lying on an invisible part (self-lit, over the Bloom).
local function flatSpot(storm, k, pos, size, col, alpha, bright)
	local f = storm.flats[k]
	if not f then
		local part = inertPart("CascadeSpot")
		part.Size = Vector3.new(1, 0.05, 1)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.Brightness = 1
		gui.CanvasSize = Vector2.new(64, 64)
		gui.AlwaysOnTop = false
		gui.Adornee = part
		gui.Parent = part
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.BorderSizePixel = 0
		img.Size = UDim2.fromScale(1, 1)
		img.Image = SOFT_TEX
		img.Parent = gui
		part.Parent = storm.Folder
		f = { part = part, gui = gui, img = img, size = -1, col = -1, a = -1, br = -1, frame = -1, on = true, pos = nil }
		storm.flats[k] = f
	end
	f.frame = storm.frameN
	if f.pos ~= pos then
		f.part.CFrame = CFrame.new(pos)
		f.pos = pos
	end
	if math.abs(f.size - size) > 0.01 then
		f.part.Size = Vector3.new(size, 0.05, size)
		f.size = size
	end
	local ck = packCol(col)
	if f.col ~= ck then
		f.img.ImageColor3 = col
		f.col = ck
	end
	if math.abs(f.a - alpha) > 0.005 then
		f.img.ImageTransparency = 1 - clamp01(alpha)
		f.a = alpha
	end
	local br = math.max(0, bright) * (storm.flat and FLAT_BRIGHTNESS or 1)
	if math.abs(f.br - br) > 0.01 then
		f.gui.Brightness = br
		f.br = br
	end
end

local function finishFlats(storm)
	for _, f in pairs(storm.flats) do
		local on = f.frame == storm.frameN
		if f.on ~= on then
			f.gui.Enabled = on
			f.on = on
		end
	end
end

--- THE FLASH's kicks for this client: ExposureCompensation, Bloom and the camera shake, by distance from the strike.
local function flashKicks(storm, ground)
	local d = (CTX.camPos - ground).Magnitude
	local k = 1 - span(d, T.FlashReach[1], T.FlashReach[2])
	-- halved only for Reduce Enemy VFX on somebody else's cast: Graphics Quality thins the decoration, never the flash
	local thinK = storm.ThinEnemy and 0.5 or 1
	if k > 0 then
		if not storm.calm then exposureKick(T.FlashEV[1] * k * thinK, T.FlashEV[2], F) end
		-- the Bloom kick. VoltaicKit drops every kick while the first-person viewmodel is up (it blooms the arms white);
		-- the climax asks through that rule (bloomPulse's 6th argument `anyView` -- THE VOLTAIC KIT PATCH returned with
		-- this port: until it is in, the Kit ignores the argument and nobody in first person, the default view, gets
		-- this half of THE FLASH), faded out as the strike comes within FpBloomNear of the viewer, so a strike on top of
		-- a first-person viewer never whites the screen through the arms
		local fp = CTX.fp
		local fpK = fp and smooth(span(d, T.FpBloomNear[1], T.FpBloomNear[2])) or 1
		if fpK > 0 then
			pcall(Kit.bloomPulse, T.FlashBloom[1] * k * thinK * fpK * (storm.calm and 0.5 or 1), T.FlashBloom[2] * k * fpK,
				T.FlashBloom[3], F, 0, fp)
		end
	end
	-- the shake: Viewmodel.Shake is translation only at its own ~10 Hz; the showcase's 1.2-degree rotation (T.Shake[2])
	-- and its 21 Hz (T.Shake[4]) are not applied (DEVIATIONS 9)
	local ks = 1 - span(d, T.ShakeReach[1], T.ShakeReach[2])
	if ks > 0 then
		local _, VM = Kit.libs()
		if VM and VM.Shake then pcall(VM.Shake, T.Shake[1] * ks, T.Shake[3]) end
	end
end

----------------------------------------------------------------------------------------------------
-- 4 THE RELEASE: (a) the fan and its four ground forks (cascade_bl.plan_fan / fork_intensity / fan_frame)
----------------------------------------------------------------------------------------------------
local planFan, stepFan
do
planFan = function(storm, rng)
	local rays = {}
	local n = T.FanRays
	for i = 0, n - 1 do
		local a = i * TAU / n + rng:NextNumber(-0.18, 0.18)
		local L = rng:NextNumber(T.FanLen[1], T.FanLen[2])
		local dip = math.rad(rng:NextNumber(T.FanDip[1], T.FanDip[2]))
		local d = Vector3.new(math.cos(a) * math.cos(dip), math.sin(a) * math.cos(dip), -math.sin(dip))
		rays[i + 1] = { id = i + 1, L = L, dW = bdir(storm, d), seed = rng:NextInteger(1, 1000000), j = -1 }
	end
	local forks = {}
	for i = 1, 4 do
		forks[i] = { id = i, kneeU = rng:NextNumber(0.50, 0.66), kneeDrop = rng:NextNumber(2.0, 3.6),
			seed = rng:NextInteger(1, 1000000), at = storm.STR[i], gen = 0, tag = -1, jgen = -1 }
	end
	return rays, forks
end

local function forkIntensity(V, f)
	local s0 = T.Fan
	local rs = f.at
	local room = T.Leader[1] - F - rs                 -- every fork is gone before the dominant's leader
	local hold = math.min(T.ForkHold, room / 2)
	local fade = math.min(T.ForkFade, room / 2)
	local e = rs + hold
	if V < s0 or V > e + fade + F then return 0, false end
	if V >= e then return math.max(0, 1 - (V - e) / math.max(fade, 1e-3)) * 0.8, true end
	if V >= rs then return 1.35 - 0.5 * span(V, rs, rs + 2 * F), false end
	return 1.0 - 0.52 * span(V, s0 + F, s0 + 3 * F), false
end

local function rayJag(storm, R, j30)
	if R.j == j30 then return end
	local rr = Random.new(R.seed + j30)
	local hub = storm.hub
	local pts = Kit.jag(hub, hub + R.dW * R.L, 3, 0.10 * R.L, rr)
	local n = #pts
	local i0 = rr:NextInteger(math.floor(n / 3), math.floor(2 * n / 3)) + 1
	local fb = pts[math.clamp(i0, 1, n)]
	local fd = (R.dW + perpR(R.dW) * rr:NextNumber(-0.8, 0.8) - UP * rr:NextNumber(0.2, 0.7)).Unit
	local fe = fb + fd * (R.L * rr:NextNumber(0.28, 0.48))
	R.pts, R.fpts = pts, Kit.jag(fb, fe, 2, 0.08 * R.L, rr)
	R.j = j30
	R.key, R.fkey = 100000 + R.id * 1000 + j30, 200000 + R.id * 1000 + j30
end

local function forkJag(storm, f, j30, restrike)
	local tag = j30 * 2 + (restrike and 1 or 0)
	if f.tag == tag and f.jgen == f.gen then return end
	local rr = Random.new(f.seed + (restrike and 777 + j30 or j30))
	local p1 = Kit.jag(storm.hub, f.knee, 3, 1.2, rr)
	local p2 = Kit.jag(f.knee, f.g + UP * 0.05, 4, 1.6, rr)
	local pts = table.create(#p1 + #p2)
	for _, p in ipairs(p1) do pts[#pts + 1] = p end
	for k = 2, #p2 do pts[#pts + 1] = p2[k] end
	local br = Random.new(f.seed * 3 + j30)
	local fb = p2[math.floor(#p2 / 2) + 1]
	local fe = fb + bdir(storm, Vector3.new(br:NextNumber(-2.5, 2.5), br:NextNumber(-2.5, 2.5), -br:NextNumber(1.0, 2.5)))
	f.pts, f.bpts = pts, Kit.jag(fb, fe, 2, 0.5, br)
	f.tag, f.jgen = tag, f.gen
	f.key = 300000 + f.id * 10000 + (f.gen % 50) * 200 + tag
	f.bkey = f.key + 5000000
end

stepFan = function(storm, V, S)
	local g = group(storm, "fan")
	local s0 = T.Fan
	if storm.Cancelled or not storm.predDone or V < s0 or V > storm.STR[4] + T.ForkHold + T.ForkFade + 1.2 then
		clearG(g)
		return
	end
	beginG(g)
	-- (2026-10-19, audit P5D-03) Reduce Flashing: the rays and forks re-jag at 10 Hz (the "j30" tick at a third)
	local j30 = math.floor((V - s0) * (storm.calm and 10 or 30) + 1e-6)
	local age = V - s0
	local hub = storm.hub
	-- the skeletons the fan connects with, in the same frame (once, never late)
	if not storm.fanFired then
		storm.fanFired = true
		if age < 0.1 then
			for i = 1, 4 do storm.trigger(storm.forks[i].body, "fan", S) end
		end
	end
	-- the rays: one frame, full length, no travel; held, then violet embers
	local cw, gw, cb, gb = T.FanArc[1], T.FanArc[2], T.FanArc[3], T.FanArc[4]
	if age < T.FanHold + T.FanFade + F then
		local ember = age >= T.FanHold + T.FanFade * 0.5
		local a = age < T.FanHold and 1 or math.max(0, 1 - (age - T.FanHold) / T.FanFade)
		local k0 = age < 2 * F and 1.25 or 1.0
		local hot0 = age < 2 * F and 0.25 or 0.0
		for _, R in ipairs(storm.rays) do
			rayJag(storm, R, j30)
			if ember then
				beamDraw(storm, g, R.pts, cw * 0.7, 0, COL.Dark, cb, nil, 0, emberOpt(a, R.key))
			else
				voltDraw(storm, g, R.pts, cw * k0, gw, cb * k0, gb * k0, optv(a, 1 - a, hot0, R.seed + j30, nil, R.key))
				voltDraw(storm, g, R.fpts, cw * 0.60, gw * 0.6, cb * 0.9 * k0, gb * 0.8,
					optv(a, 1 - a, hot0, R.seed + j30 + 11, nil, R.fkey))
			end
		end
	end
	-- the hub: a star and a light under the belly (it lights the cloud's underside from below)
	if age < 0.14 then
		local hs = T.HubStar
		local sz = hs[1] * (age < F and 1.0 or lerp(0.85, 0.3, span(age, F, 0.14)))
		star(storm, g, hub, sz, 0.4 + age * 3, hs[2], hs[3], 1 - span(age, 0.09, 0.14), 1.0)
	end
	if age < 0.5 then
		reqLight(storm, "hub", hub - UP * 1.2, T.HubLight[1] * math.exp(-age / 0.09) * storm.flashK, T.HubLight[2],
			BELLY_LIGHT, 3, true)
	end
	-- the four ground forks, each re-striking on its strike time (the render's fork and channel lights cast shadows:
	-- here at the tiers whose lumps do, HIGH and ULTRA)
	local fcw, fgw, fcb, fgb = T.ForkArc[1], T.ForkArc[2], T.ForkArc[3], T.ForkArc[4]
	local lsh = storm.Q.LumpShadow == true
	for i, f in ipairs(storm.forks) do
		if f.g then
			local I, ember = forkIntensity(V, f)
			-- the server ended the storm before this fork's strike (the caster died, the round reset): no re-strike;
			-- the fork fades from its hold level from the moment the end was heard
			local cut = storm.Truncated and i > (storm.lastN or 0) and not f.fired
			if cut then
				local fade = 1 - span(V, storm.endV or V, (storm.endV or V) + T.ForkFade + T.ForkHold)
				I, ember = (1.0 - 0.52 * span(V, s0 + F, s0 + 3 * F)) * fade, false
			end
			local restrike = not cut and V >= f.at and V < f.at + 2 * F
			-- (2026-10-19, audit P5D-03) Reduce Flashing: no re-strike spike (I <= 1), no new shape and no whitening at
			-- it -- the four re-strikes read as one held stroke
			if storm.calm then
				restrike = false
				if I > 1 then I = 1 end
			end
			if I > 0.01 then
				forkJag(storm, f, j30, restrike)
				if ember then
					beamDraw(storm, g, f.pts, fcw * 0.7, 0, COL.Dark, fcb, nil, 0, emberOpt(I, f.key))
				else
					local wh = restrike and 0.35 or 0
					local cool = V >= f.at + T.ForkHold and clamp01(1 - I) or 0
					voltDraw(storm, g, f.pts, fcw * (0.8 + 0.3 * I), fgw * (0.7 + 0.35 * I), fcb * I, fgb * I,
						optv(1, cool, wh, f.seed + j30 + (restrike and 777 or 0), V - s0, f.key))
					voltDraw(storm, g, f.bpts, fcw * 0.55, fgw * 0.5, fcb * 0.8 * I, fgb * 0.7 * I,
						optv(1, cool, wh, f.seed * 3 + j30, nil, f.bkey, 1))
				end
			end
			-- its ground contact: at the fan (drawn) and brighter at the re-strike; the hot spot cools long after
			local FS = T.ForkStar
			for pass = 1, cut and 1 or 2 do
				local tHit = pass == 1 and s0 or f.at
				local k = pass == 1 and 0.6 or 1.0
				local ah = V - tHit
				if ah >= 0 and ah < 0.10 then
					star(storm, g, f.g + UP * 0.35, FS[1] * k * (1 - 0.6 * span(ah, 0, 0.10)), 0.3 + i, FS[2], FS[3],
						1 - span(ah, 0.06, 0.10), 0.6)
				end
			end
			local spot = cut and 0 or 1 - smooth(span(V, f.at + 0.1, f.at + 1.2))
			if spot > 0 then
				local col = COL.Light:Lerp(COL.Base, span(V, f.at, f.at + 0.35)):Lerp(EMBER_HALO, span(V, f.at + 0.35, f.at + 1.0))
				flatSpot(storm, i, f.g + UP * 0.04, 2.4, col, spot, 1.4 * spot * storm.flashK)   -- flashK: audit P5D-03
			end
			local ra = V - f.at
			if ra >= 0 and ra < 0.6 and not cut then
				local b = (T.ForkLight[1] * math.exp(-ra / 0.07) + 0.8 * (1 - span(ra, 0.1, 0.6))) * storm.flashK   -- audit P5D-03
				reqLight(storm, LKEY.fork[i], f.g + UP * 1.6, b, T.ForkLight[2], COL.Light:Lerp(COL.Base, span(ra, 0, 0.2)), 5, lsh)
			elseif age < 0.1 then
				reqLight(storm, LKEY.fork[i], f.g + UP * 1.6, T.ForkLight[1] * 0.5 * storm.flashK, T.ForkLight[2], COL.Light, 5, lsh)
			end
			-- the re-strike's sparks and its skeleton (once, and only if not long past)
			if V >= f.at and not f.fired and not cut then
				f.fired = true
				if V - f.at < 0.15 then
					sparkBurst(storm, f.g + UP * 0.3, false)
					storm.trigger(f.body, "fan", S)
				end
			end
		end
	end
	finishG(g)
end
end

----------------------------------------------------------------------------------------------------
-- 4 THE RELEASE: (b) the dominant strike, the hitpause and THE FLASH (cascade_bl.plan_main / strike_frame)
----------------------------------------------------------------------------------------------------
local planMain, stepStrike
do
planMain = function(storm, rng)
	local n, sw0, sw1 = T.MainKinks[1], T.MainKinks[2], T.MainKinks[3]
	local us = {}
	for _ = 1, n - 1 do us[#us + 1] = rng:NextNumber() end
	table.sort(us)
	for i = 1, #us do us[i] = lerp(i / n, us[i], 0.35) end         -- irregular leg lengths, still in order
	local lat = {}
	local sgn = 1
	for i = 1, #us do
		if rng:NextNumber() < 0.8 then sgn = -sgn end
		lat[i] = Vector3.new(sgn * rng:NextNumber(sw0, sw1), rng:NextNumber(-0.8, 0.8), 0)
	end
	local branches = {}
	for b = 1, 4 do
		local i = rng:NextInteger(1, 4) + 1
		local d = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), -rng:NextNumber(0.6, 1.3)).Unit
		branches[b] = { i = i, dW = bdir(storm, d), L = rng:NextNumber(3.0, 6.0), seed = rng:NextInteger(1, 1000000) }
	end
	return { us = us, lat = lat, branches = branches, seed = rng:NextInteger(1, 1000000), gen = 0, ks = nil }
end

local function mainPath(storm, seed)
	local M = storm.main
	if M.pseed == seed and M.pgen == M.gen then return M.path end
	local rr = Random.new(seed)
	local pts = { M.ks[1] }
	for k = 1, #M.ks - 1 do
		local seg = Kit.jag(M.ks[k], M.ks[k + 1], 3, 0.30, rr, 0.55)
		for q = 2, #seg do pts[#pts + 1] = seg[q] end
	end
	M.path, M.pseed, M.pgen = pts, seed, M.gen
	return pts
end

local function mainBranches(storm, j30)
	local M = storm.main
	if M.bj == j30 and M.bgen == M.gen then return M.bpts end
	local br = Random.new(M.seed + 91 + j30)
	local out = {}
	for bi, b in ipairs(M.branches) do
		local fb = M.ks[math.min(b.i, #M.ks)]
		out[bi] = Kit.jag(fb, fb + b.dW * b.L, 3, 0.5, br)
	end
	M.bpts, M.bj, M.bgen = out, j30, M.gen
	return out
end

stepStrike = function(storm, V, S)
	local g = group(storm, "main")
	local l0, l1 = T.Leader[1], T.Leader[2]
	-- (Truncated: the server ended the storm before strike 5 -- no leader, no contact, no hitpause, no flash)
	if storm.Cancelled or storm.Truncated or not storm.predDone or V < l0 then
		clearG(g)
		return
	end
	local HIT, HP = storm.HIT, storm.HP
	local M = storm.main
	local ground = storm.mainG
	-- the skeleton flash at contact, held through the hitpause
	if S >= HIT and not storm.hitFired then
		storm.hitFired = true
		if S - HIT < 0.1 then storm.trigger(storm.mainBody, "main", HIT) end
	end
	local df = V - storm.FLASH                       -- < 0 through the contact frame and the whole hitpause
	local life = T.MainHold + T.MainFade
	if df > 1.7 then
		clearG(g)
		return
	end
	beginG(g)
	local hu = HP > 0 and clamp01((S - HIT) / HP) or 1
	local cw, gw, cb, gb = T.Main[1], T.Main[2], T.Main[3], T.Main[4]
	if V < HIT then
		-- the leader: two frames, thin and branching, feeling its way down
		local u = V < l1 and 0.45 or 0.85
		local pts = mainPath(storm, M.seed)
		local acc = arclen(pts)
		local shown = cutPath(pts, acc, 0, acc[#acc] * u)
		voltDraw(storm, g, shown, 0.10, 0.7, 2.0, 1.0, optv(1, 0, 0.2, M.seed + (V < l1 and 0 or 1), nil, nil, nil, 1.0))
		local lr = Random.new(M.seed + 5)
		for bi = 1, 3 do
			local b = M.branches[bi]
			if b.i < #M.ks and M.ks[b.i].Y > M.ks[1].Y - acc[#acc] * u then
				local fb = M.ks[b.i]
				voltDraw(storm, g, Kit.jag(fb, fb + b.dW * (b.L * 0.6), 2, 0.4, lr), 0.06, 0.4, 1.6, 0.8,
					optv(1, 0, 0.2, M.seed + b.seed))
			end
		end
		reqLight(storm, "channel", storm.hub - UP * 5.0, 1.5, 22.0, BELLY_LIGHT, 4, storm.Q.LumpShadow == true)
		finishG(g)
		return
	end
	if df <= life then
		local j30 = math.floor(math.max(0, df) * (storm.calm and 10 or 30) + 1e-6)   -- calm 10 Hz: (2026-10-19, audit P5D-03)
		local pts = mainPath(storm, M.seed + (df >= 0 and j30 or 0))
		local ember = df > T.MainHold + T.MainFade * 0.60
		local I, wk
		if df < 0 then
			I, wk = 1.0 + T.Contact[1] * hu, 1.0       -- CONTACT: connected, the world held, building -- no flash yet
		elseif df < T.MainHold then
			I = 1.35 - 0.35 * span(df, 0, 3 * F)
			wk = 1.55 - 0.55 * span(df, 0, 3 * F)       -- the return stroke: fat for three frames
		else
			I = math.max(0, 1 - (df - T.MainHold) / T.MainFade)
			wk = 0.6 + 0.4 * I
		end
		local key = 400000 + (df >= 0 and j30 or 999) + (M.gen % 50) * 1000
		if ember then
			beamDraw(storm, g, pts, cw * 0.6, 0, COL.Dark, cb, nil, 0, emberOpt(I, key))
		else
			-- the brightest moment of the whole sequence: the return stroke runs whiter than anything, current pulsing
			-- down it; it cools Light -> Base only as it fades
			local wh = (df >= 0 and df < 3 * F) and 0.45 or 0.15
			local cool = df >= T.MainHold and clamp01(1 - I) or 0
			voltDraw(storm, g, pts, cw * wk, gw * (0.8 + 0.2 * wk), cb * I, gb * I,
				optv(1, cool, wh, M.seed + j30, math.max(0, df), key, 2))
			local B = mainBranches(storm, j30)
			for bi, b in ipairs(M.branches) do
				voltDraw(storm, g, B[bi], cw * 0.35, gw * 0.4, cb * 0.85 * I, gb * 0.7 * I,
					optv(1, cool, wh * 0.6, M.seed + b.seed + j30, nil, key + bi * 100000, 1))
			end
		end
	end
	if df < 0 then
		-- the contact: a small star at the ground growing, the channel's own light, a ground light rising
		local Ct = T.Contact
		star(storm, g, ground + UP * 0.5, lerp(Ct[2], Ct[3], hu), 0.2, 2.6, 1.4, 1, 0.8)
		reqLight(storm, "channel", storm.hub - UP * 6.0, 3.0, 26.0, BELLY_LIGHT, 4, storm.Q.LumpShadow == true)
		reqLight(storm, "big", ground + UP * 1.2, Ct[4] * hu, Ct[5], COL.Light, 1, true)
		finishG(g)
		return
	end
	-- THE FLASH (the first frame after the hold)
	if not storm.flashed then
		storm.flashed = true
		if df < 0.25 then
			flashKicks(storm, ground)
			sparkBurst(storm, ground + UP * 0.4, true)
		end
	end
	local B0, R0, tau, Bh = T.BigLight[1], T.BigLight[2], T.BigLight[3], T.BigLight[4]
	-- both cool to BELLY_LIGHT within ~3 frames (in play: any yellow left on after that painted the storm magenta)
	local cool = span(df, 0.03, 0.08)
	reqLight(storm, "big", ground + UP * 2.2, B0 * math.exp(-df / tau) * storm.flashK, R0,
		COL.Light:Lerp(WHITE, 0.5):Lerp(BELLY_LIGHT, cool), 1, true)
	reqLight(storm, "bigheld", ground + UP * 2.2, Bh * (1 - span(df, 0.12, 0.90)) * storm.flashK, T.HeldRange,
		COL.Light:Lerp(BELLY_LIGHT, cool), 1, true)
	if df < 0.30 then
		reqLight(storm, "belly", storm.hub - UP * 2.0, T.BellyLight * math.exp(-df / 0.08) * storm.flashK, 34.0, BELLY_LIGHT, 2, true)
	end
	if df < 0.26 then
		local IS = T.ImpactStar
		local sz = IS[1] * (df < F and 1.0 or (df < 2 * F and 1.18 or lerp(1.0, 0.35, span(df, 2 * F, 0.26))))
		star(storm, g, ground + UP * 0.9, sz, 0.3 + df * 2, IS[2], IS[3], 1 - span(df, 0.18, 0.26), 1.5,
			COL.Light:Lerp(WHITE, df < 3 * F and 0.6 or 0))
	end
	-- the shock ring on the ground
	local Rr, Rt = T.Ring[1], T.Ring[2]
	if df < Rt then
		local u = df / Rt
		local rad = Rr * easeOutCubic(u)
		local n = 24
		local pts = table.create(n + 1)
		for i = 0, n do
			local a = i * TAU / n
			pts[i + 1] = ground + Vector3.new(math.cos(a) * rad, 0.12, math.sin(a) * rad)
		end
		local o = optv(1 - u * u, nil, nil, nil, nil, nil, 2)
		o.flatW = true
		beamDraw(storm, g, pts, 0.35 * (1 - u) + 0.08, 2.2 * (1 - 0.5 * u), COL.Light, 2.2 * (1 - u), COL.Base, 1.4 * (1 - u), o)
	end
	-- the scorch: a hot spot on the ground, cooling Light -> Base -> violet over 1.6 s
	local ua = span(df, 0.0, 1.6)
	if ua < 1 then
		local col = COL.Light:Lerp(COL.Base, span(df, 0.0, 0.35)):Lerp(EMBER_HALO, span(df, 0.35, 1.2))
		flatSpot(storm, 5, ground + UP * 0.05, 6.0 * (1 - 0.3 * ua), col, 1 - smooth(ua), 2.0 * (1 - smooth(ua)) * storm.flashK)
	end
	finishG(g)
end
end

----------------------------------------------------------------------------------------------------
-- THE SKELETON FLASH (cascade_bl.skel_level / skeleton_frame)
----------------------------------------------------------------------------------------------------
local stepSkeletons
do
local function skelLevel(storm, rec, S)
	local onFor, n
	if rec.kind == "main" then
		onFor, n = storm.HP + F, T.SkelMain[2]        -- the contact frame and every held frame: fully on
	else
		onFor, n = T.SkelFan[1] * F, T.SkelFan[2]
	end
	if S < rec.s0 + onFor - 1e-6 then return S >= rec.s0 - 1e-6 and 1 or 0 end
	local j = math.floor((S - rec.s0 - onFor) * 60 + 1e-6)
	if storm.calm then return j < 3 and (1 - (j + 1) / 4) or 0 end     -- Reduce Flashing: a straight fade, no flicker
	if j < 0 or j >= n then return 0 end
	return (1 - (j + 1) / (n + 1)) * (j % 2 == 0 and 1 or 0.3)
end

local function skelHighlight(storm, rec, body, on)
	if on then
		if not rec.hl then
			local h = Instance.new("Highlight")
			h.Name = "CascadeStruck"
			h.Adornee = body
			h.FillColor = T.BodyDark
			h.FillTransparency = 0
			h.OutlineTransparency = 1
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = storm.Folder
			rec.hl = h
		elseif not rec.hl.Enabled then
			rec.hl.Enabled = true
		end
	elseif rec.hl and rec.hl.Enabled then
		rec.hl.Enabled = false
	end
end

local function drawSkeleton(storm, g, body, root, rec, lv, S)
	local fno = math.floor(S * 60 + 1e-6)
	local drop = rootDrop(body, root)
	local head = body:FindFirstChild("Head")
	local top = (head and head:IsA("BasePart")) and (head.Position.Y + head.Size.Y / 2 - root.Position.Y) or 2.0
	local sc = math.clamp((drop + top) / 5, 0.6, 2.0)
	local feet = root.Position - UP * drop
	local cam = CTX.camPos
	local toCam = cam - root.Position
	toCam = Vector3.new(toCam.X, 0, toCam.Z)
	if toCam.Magnitude > 0.5 then
		toCam = toCam.Unit
	else
		-- the camera stands (nearly) over the root: face it by its own look, never by the body's
		local lv = CTX.camCF.LookVector
		lv = Vector3.new(-lv.X, 0, -lv.Z)
		toCam = lv.Magnitude > 1e-3 and lv.Unit or Vector3.zAxis
	end
	local right = (-toCam):Cross(UP)                 -- the viewer's right
	local front = toCam * (0.62 * sc)
	local jr = Random.new(rec.seed * 1000 + fno)
	local ccw, cgw, ccb, cgb = T.Skel[1], T.Skel[2], T.Skel[3], T.Skel[4]
	-- the skeleton, a decal on the body's front facing the viewer: volt()'s material, shivering with the charge. Drawn
	-- as three strands (SK.cut: <= SK.CHUNK points each), never one 150-point strand -- no single slot builds ~480
	-- instances in one frame
	local nb = #SK.bones
	for bi, poly in ipairs(SK.bones) do
		if bi == 1 or SK.cut[bi] then dBegin() end
		local pts = table.create(#poly)
		for k, xz in ipairs(poly) do
			local x = xz[1] + jr:NextNumber(-0.018, 0.018)
			local z = xz[2] + jr:NextNumber(-0.018, 0.018)
			pts[k] = feet + right * (x * sc) + UP * (z * sc) + front
		end
		local fl = 0.85 + 0.3 * jr:NextNumber()
		local o = optv(1, 0, 0, rec.seed * 97 + bi + fno)
		o.flatW, o.glowEnds = true, true
		voltInto(pts, ccw * sc, cgw * sc, ccb * lv * fl * storm.kb, o)
		if bi == nb or SK.cut[bi + 1] then
			D.glow, D.gstep, D.gc, D.gb = true, 1, COL.Base, cgb * lv * storm.kb
			strandDraw(slot(storm, g, "bolt", D.n - 1), D)
			glowCaps(storm, g, D)
		end
	end
	for _, xz in ipairs(SK.knobs) do
		sprite(storm, g, "soft", feet + right * (xz[1] * sc) + UP * (xz[2] * sc) + toCam * (0.65 * sc), 0.10 * PARTICLE_QUAD * sc,
			0, COL.Light, 1, 2.2 * lv, 0.1)
	end
	-- the burst behind it: a jagged Dark star facing the camera, a thin Base rim along every spike
	local c = feet + UP * (2.7 * sc)
	local fwd = c - cam
	fwd = fwd.Magnitude > 1e-4 and fwd.Unit or -toCam
	local r2 = fwd:Cross(UP)
	r2 = r2.Magnitude > 1e-4 and r2.Unit or Vector3.xAxis
	local up2 = r2:Cross(fwd).Unit
	c += fwd * (1.3 * sc)
	local br_ = Random.new(rec.seed * 31 + (rec.kind == "main" and 0 or 7))
	local nsp, rin, rout, fanK = T.Burst[1], T.Burst[2], T.Burst[3], T.Burst[4]
	local k = (rec.kind == "main" and 1 or fanK) * (1 + 0.05 * (fno % 2)) * sc * (storm.calm and T.CalmBurst or 1)
	local ring = table.create(2 * nsp)
	for i = 0, 2 * nsp - 1 do
		local a = (i + br_:NextNumber(-0.25, 0.25)) * math.pi / nsp
		local r = (i % 2 == 0 and rout * br_:NextNumber(0.75, 1.20) or rin * br_:NextNumber(0.85, 1.12)) * k
		ring[i + 1] = c + r2 * (r * math.cos(a)) + up2 * (r * math.sin(a))
	end
	-- the fill: per spike, a triangle from the centre out to its base, and one from its base to its tip (a Beam's
	-- width runs 0 -> w -> 0 along centre -> base -> tip), flat #4A1A8C, self-lit, under the Bloom threshold
	dBegin()
	local dark = COL.Dark
	for s = 0, nsp - 1 do
		local tip = ring[2 * s + 1]
		local vA = ring[((2 * s - 1) % (2 * nsp)) + 1]
		local vB = ring[2 * s + 2]
		local mid = (vA + vB) * 0.5
		local wb = (vA - vB).Magnitude * 1.08
		local base = D.n
		for q, pw in ipairs({ { c, 0 }, { mid, wb }, { tip, 0 } }) do
			local kk = base + q
			D.P[kk], D.cw[kk], D.oC[kk], D.cC[kk], D.gw[kk], D.gO[kk] = pw[1], pw[2], 1, dark, 0, 0
			if kk > 1 then
				D.oM[kk - 1], D.cM[kk - 1], D.cbS[kk - 1], D.gap[kk - 1] = 1, dark, 1, q == 1
			end
		end
		D.n = base + 3
	end
	strandDraw(slot(storm, g, "fill", D.n - 1), D)
	local loop = table.create(2 * nsp + 1)
	for i = 1, 2 * nsp do loop[i] = ring[i] end
	loop[2 * nsp + 1] = ring[1]
	local o = optv(1, nil, nil, nil, nil, nil, 2)
	o.flatW = true
	beamDraw(storm, g, loop, T.BurstRim[1] * sc, T.BurstRim[2] * sc, COL.Base, T.BurstRim[3] * lv, COL.Base, T.BurstRim[4] * lv, o)
	-- the struck body goes near-black while its skeleton shows
	skelHighlight(storm, rec, body, lv >= 0.3)
end

stepSkeletons = function(storm, S)
	local g = group(storm, "skel")
	if next(storm.skel) == nil then
		clearG(g)
		return
	end
	beginG(g)
	local lp = Players.LocalPlayer
	local mine = lp and lp.Character
	for body, rec in pairs(storm.skel) do
		local lv = skelLevel(storm, rec, S)
		local root = body.Parent and body:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or (lv <= 0 and S > rec.s0 + 0.05) then
			if rec.hl then pcall(function() rec.hl:Destroy() end) end
			storm.skel[body] = nil
		elseif lv > 0 and not (body == mine and CTX.fp) then
			drawSkeleton(storm, g, body, root, rec, lv, S)
		else
			-- (the viewer's own body in first person: the flash is for the others watching, never drawn round the lens)
			skelHighlight(storm, rec, body, false)
		end
	end
	finishG(g)
end
end

----------------------------------------------------------------------------------------------------
-- THE POOLS PRE-WARMED. The pools only fill with what earlier casts gave back, so the first Cascade a client sees
-- would build its fan (~690 instances), each skeleton flash (~700) and the contact (~430) in the very frames that need
-- them -- the climax, where the hitpause has to read. Through the windup and the gathering (V < Fan - 0.1) this makes
-- what the storm will need, WarmBatch instances a frame, straight into the pools (and the seam kit's Beams, before the
-- punch's solve lights a hundred creases at once). A warm pool (a later cast) is only counted.
----------------------------------------------------------------------------------------------------
local stepWarm
do
local function warmPlan(storm)
	local q, tot = {}, {}
	-- (every group keeps its strands until the storm ends, so one (look, class) asked for again adds up)
	local function add(look, cls, n)
		local key = look .. cls
		tot[key] = math.min(46, (tot[key] or 0) + n)       -- (a strand pool keeps 48 of a class)
		q[#q + 1] = { look = look, cls = cls, want = tot[key] }
	end
	local Q = storm.Q
	local skel = Q.SkelCap or 1
	if storm.wind then add("bolt", 48, 2) end                          -- the launch: needed first, at 0.50
	q[#q + 1] = { seam = true, want = Q.SeamCap }                      -- the seams: by the punch at S 0.52
	add("bolt", 8, T.FanRays)                                          -- THE FAN: its rays,
	add("bolt", 4, T.FanRays + 4)                                      -- their forks and the ground forks' branches,
	add("bolt", 24, 4)                                                 -- the four ground forks
	q[#q + 1] = { sprite = "starGlow", want = 12 }
	q[#q + 1] = { sprite = "starCore", want = 12 }
	q[#q + 1] = { sprite = "soft", want = math.min(62, 12 * skel + 16) }
	for _ = 1, skel do                                                 -- THE SKELETONS (SkelCap at once)
		for _, cn in ipairs(SK.chunkN) do add("bolt", classFor(cn - 1), 1) end
		add("fill", 48, 1)
		add("bolt", 32, 1)
	end
	add("bolt", 24, 2)                                                 -- THE STRIKE: the leader's first frame, the ring,
	add("bolt", 4, 3)                                                  -- the leader's branches,
	add("bolt", 48, 1)                                                 -- the channel,
	add("bolt", 8, 4)                                                  -- its branches
	return q
end

stepWarm = function(storm, V)
	if storm.warmDone or storm.Cancelled or V > T.Fan - 0.1 then return end
	local q = storm.warmQ
	if not q then
		q = warmPlan(storm)
		storm.warmQ, storm.warmI = q, 1
	end
	local flat = storm.flat
	local budget = T.WarmBatch
	while budget > 0 do
		local e = q[storm.warmI]
		if not e then
			storm.warmDone = true
			return
		end
		local have, cost = 0, 4
		if e.seam then
			local kit = storm.seam and storm.seam.kit
			have = kit and #kit.els or e.want
			if have < e.want then seamEl(storm, kit, have + 1) end
		elseif e.sprite then
			for _, sp in ipairs(spritePool[e.sprite]) do
				if sp.flat == flat then have += 1 end
			end
			if have < e.want then giveSprite(newSprite(e.sprite, flat)) end
		else
			local list = strandPool[e.look][e.cls]
			if list then
				for _, s in ipairs(list) do
					if s.flat == flat then have += 1 end
				end
			end
			cost = e.look == "fill" and 2 * e.cls + 1 or 3 * e.cls + 1
			if have < e.want then giveStrand(newStrand(e.look, e.cls, flat)) end
		end
		e.tries = (e.tries or 0) + 1
		-- (a pool that will not take it -- full of the other lighting's strands -- is not fed forever)
		if have >= e.want or e.tries > e.want + 1 then storm.warmI += 1 else budget -= cost end
	end
end
end

----------------------------------------------------------------------------------------------------
-- A STORM: built from a broadcast, stepped every render frame on its own clock, destroyed at its end
----------------------------------------------------------------------------------------------------
local STORMS = {}
local bound = false

local function destroyStorm(storm, poison)
	if storm.Dead then return end
	storm.Dead = true
	local i = table.find(STORMS, storm)
	if i then table.remove(STORMS, i) end
	for _, g in pairs(storm.groups) do
		for _, s in ipairs(g.e) do giveStrand(s, poison) end
		for _, sp in ipairs(g.s) do giveSprite(sp, poison) end
		table.clear(g.e)
		table.clear(g.s)
	end
	for _, e in pairs(storm.lumpE) do giveLump(e.part, e.mesh, poison) end
	table.clear(storm.lumpE)
	if storm.seam then giveSeamKit(storm.seam.kit, poison) end
	for _, rec in pairs(storm.skel) do
		if rec.hl then pcall(function() rec.hl:Destroy() end) end
	end
	table.clear(storm.skel)
	pcall(function() storm.Folder:Destroy() end)
end

local function stepStorm(storm)
	if storm.Dead then return false end
	if not (storm.Folder and storm.Folder.Parent) then return false end       -- the FX folder was cleared under us
	-- the watchdog: a storm lasts TEND shot seconds, so a slowed review (ShotTimeScale) stretches its real-time limit
	local ts = Kit.timeScale()
	local nowR = os.clock()
	if nowR - storm.Born > math.max(T.MaxReal, storm.TEND / math.max(0.05, ts) + 5) then return false end
	-- a storm called off before any strike hurries on to its break-up (CascadeFX.End): CatchUp storm seconds a second
	-- extra, from where it is
	if storm.catchUp and storm.catchUp > 0 then
		local d = math.min(storm.catchUp, T.CatchUp * math.max(0, nowR - (storm.lastReal or nowR)) * ts)
		storm.Shift += d
		storm.catchUp -= d
	end
	storm.lastReal = nowR
	local t = Kit.clock(storm.T0) + storm.Shift
	if t >= storm.TEND then return false end
	storm.frameN += 1
	storm.lreqN = 0
	local S = t - storm.W
	local HIT, HP = storm.HIT, storm.HP
	local V = S
	-- a storm ended before strike 5, or called off, has no contact to hold on
	local hold = not (storm.Truncated or storm.Cancelled)
	if S >= HIT and hold then V = (S < HIT + HP) and HIT or S - HP end
	-- THE HITPAUSE: the storm's own emitters stop through the hold
	local held = hold and S >= HIT and S < HIT + HP
	local ts = held and 0 or Kit.timeScale()
	if storm.sparkTS ~= ts then
		storm.sparkTS = ts
		if storm.sparkSmall then storm.sparkSmall.TimeScale = ts end
		if storm.sparkBig then storm.sparkBig.TimeScale = ts end
	end
	stepBuild(storm, V > 0.3)
	stepWarm(storm, V)
	stepWindup(storm, t)
	storm.posed = false
	if V >= 0 then
		local hz = storm.Q.CloudHz or 60
		local tick = hz >= 60 and V or math.floor(V * hz + 1e-6)
		if tick ~= storm.lastV then                 -- (a held frame -- the hitpause -- re-poses nothing)
			cloudState(storm, V)
			renderLumps(storm)
			storm.lastV = tick
			storm.posed = true                      -- (the seams re-lay on this frame only)
		end
		stepSeams(storm, V)
		stepTelegraph(storm, V)
		predictTargets(storm, V)
		stepFan(storm, V, S)
		stepStrike(storm, V, S)
	end
	stepSkeletons(storm, S)
	finishFlats(storm)
	applyLights(storm)
	return true
end

local function fillCtx()
	local cam = workspace.CurrentCamera
	if cam then
		local cf = cam.CFrame
		CTX.camCF, CTX.camPos, CTX.right, CTX.up = cf, cf.Position, cf.RightVector, cf.UpVector
	end
	CTX.fp = Kit ~= nil and firstPersonNow()
end

local function runner()
	fillCtx()
	for i = #STORMS, 1, -1 do
		local s = STORMS[i]
		if s then
			local ok, keep = pcall(stepStorm, s)
			if not ok then
				warnOnce("step", "a Cascade frame failed and its storm was cleared: " .. tostring(keep))
				destroyStorm(s, true)
			elseif not keep then
				destroyStorm(s, false)
			end
		end
	end
	if bound and #STORMS == 0 then
		bound = false
		pcall(RunService.UnbindFromRenderStep, RunService, RUNNER)
	end
end

--- The storm a broadcast is about: the caster's storm with this T0; with no T0, the caster's newest.
local function findStorm(character, T0)
	local best = nil
	for _, s in ipairs(STORMS) do
		if not s.Dead then
			if type(T0) == "number" then
				if math.abs(s.T0 - T0) < 1e-3 and (character == nil or s.Character == character) then return s end
			elseif s.Character == character and (not best or s.T0 > best.T0) then
				best = s
			end
		end
	end
	return best
end

local function newStorm(data, T0)
	local W, STR, belly, zone = clockNumbers()
	local HP = T.HoldFrames / 60
	local vend = 0
	for _, v in pairs(T.FadeStart) do
		if v > vend then vend = v end
	end
	vend += T.FadeT
	local tend = W + vend + HP + 0.20
	if Kit.clock(T0) >= tend then return nil end                   -- it has been and gone: draw nothing stale
	local character = (typeof(data.Character) == "Instance" and data.Character:IsA("Model")) and data.Character or nil
	local point = data.Point
	-- the storm's frame: Blender +y runs from the caster's root to the point (horizontal)
	local dir = nil
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local d = point - root.Position
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 2 then
			dir = d.Unit
		else
			local lv = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if lv.Magnitude > 1e-3 then dir = lv.Unit end
		end
	end
	if not dir then
		local cam = workspace.CurrentCamera
		local lv = cam and cam.CFrame.LookVector or Vector3.zAxis
		lv = Vector3.new(lv.X, 0, lv.Z)
		dir = lv.Magnitude > 1e-3 and lv.Unit or Vector3.zAxis
	end
	local thin = kitFlag(Kit.thin, character)
	local Q = T.Quality[thin and 1 or qualityTier()] or T.Quality[3]
	local own = kitFlag(Kit.isOwn, character)
	local _, _, Sset = Kit.libs()
	-- Reduce Enemy VFX, an ENEMY's cast (2026-10-19, audit P5F-06: was somebody else's, a teammate's included)
	local thinEnemy = not own and Sset ~= nil and Sset.ThinEnemyVFX == true and kitFlag(Kit.isEnemy, character)
	local calm = kitFlag(Kit.reduceFlashing)
	local lightK = 1
	if Kit.lightK then
		local ok, v = pcall(Kit.lightK)
		if ok and type(v) == "number" then lightK = v end
	end
	local seed = seedFrom(T0, character)
	local storm = {
		Character = character, Point = point, T0 = T0, Shift = 0, Born = os.clock(),
		W = W, STR = STR, belly = belly, zone = zone, HIT = STR[5], HP = HP, FLASH = STR[5] + F, VEND = vend, TEND = tend,
		O = point, BY = dir, BX = dir:Cross(UP),
		Folder = nil, Q = Q, Thin = thin, ThinEnemy = thinEnemy, Own = own, calm = calm,
		flat = kitFlag(Kit.flatLit), lightK = lightK,
		kb = calm and T.CalmBeam or 1, starK = calm and T.CalmStar or 1, flashK = calm and T.CalmFlash or 1,
		seed = seed, groups = {}, lreq = {}, lreqN = 0, lsort = {}, lights = {}, frameN = 0,
		C = {}, R = {}, Gw = {}, On = {}, act = {}, byGroup = {}, scraps = {}, lumpE = {}, buildQ = {}, built = 0,
		bmP = {}, bmC = {}, hitAt = {}, pred = {}, skel = {}, flats = {}, snaps = {}, flList = {}, flN = 0,
		handPos = {}, cFwd = dir, cRight = dir:Cross(UP), telTick = -1, lastV = nil, sparkTS = 1,
	}
	storm.hub = bw(storm, Vector3.new(0, 0, belly - 1.9))
	-- the lumps this client draws (Graphics Quality / thin: florets first, then every other scrap puff)
	local active = {}
	for gi = 1, #GROUPS do storm.byGroup[gi] = {} end
	local fi = 0
	for i = 1, NMAIN do
		local L = LUMPS[i]
		local keep = true
		if L.floret then
			fi += 1
			keep = Q.Florets == 1 or (Q.Florets == 2 and fi % 2 == 1)
		end
		if keep then
			table.insert(storm.byGroup[L.g], L)
			storm.buildQ[#storm.buildQ + 1] = i
			active[i] = true
		end
		storm.On[i] = false
	end
	for i = NMAIN + 1, #LUMPS do
		local L = LUMPS[i]
		if Q.Scraps == 1 or L.puff % 2 == 1 then
			storm.scraps[#storm.scraps + 1] = L
			storm.buildQ[#storm.buildQ + 1] = i
		end
		storm.On[i] = false
	end
	storm.extList = {}
	for k = 1, #EXT_LI do
		if active[EXT_LI[k]] then storm.extList[#storm.extList + 1] = k end
	end
	-- the per-cast plans (every client draws one cast alike)
	local rng = Random.new(seed)
	storm.wind = W > 0.05 and planWindup(rng) or nil
	storm.flashEv = planFlashes(storm, rng)
	storm.syncT = {}                                               -- the set pieces' starts (stepSeams solves on them)
	for _, ev in ipairs(storm.flashEv) do
		if ev[8] then storm.syncT[#storm.syncT + 1] = ev[1] end
	end
	table.sort(storm.syncT)
	storm.hops = planTelegraph(storm, rng)
	storm.rays, storm.forks = planFan(storm, rng)
	storm.main = planMain(storm, rng)
	-- its instances (last: a plan that fails leaves nothing behind)
	local folder = Instance.new("Folder")
	folder.Name = "Cascade"
	folder.Parent = Kit.fxFolder()
	storm.Folder = folder
	storm.lightHost = inertPart("CascadeLights")
	storm.lightHost.CFrame = CFrame.new(point)
	storm.lightHost.Parent = folder
	-- the seams
	local N = Q.SeamSamples
	local cosT, sinT = table.create(N), table.create(N)
	for s = 1, N do
		cosT[s], sinT[s] = math.cos((s - 1) * TAU / N), math.sin((s - 1) * TAU / N)
	end
	storm.seam = { kit = takeSeamKit(storm), pa = {}, pb = {}, np = 0, nb = {}, order = {}, pairAge = 0, next = 0,
		nEl = 0, lights = {}, nLights = 0, cosT = cosT, sinT = sinT, lastV = nil, syncI = 1, keyEl = {}, keyElNext = {} }
	-- the skeleton flash's trigger: on any model with a live Humanoid, at most SkelCap at once; main outranks fan
	storm.trigger = function(body, kind, s0)
		if typeof(body) ~= "Instance" or not body.Parent then return end
		-- never on the viewer's own body in first person (it would be drawn round the lens): it takes no SkelCap slot
		local lp = Players.LocalPlayer
		if lp and body == lp.Character and CTX.fp then return end
		local rec = storm.skel[body]
		if rec then
			if kind == "main" or rec.kind == "fan" then rec.kind, rec.s0 = kind, s0 end
			return
		end
		local n = 0
		for _ in pairs(storm.skel) do n += 1 end
		if n >= storm.Q.SkelCap then return end
		storm.skel[body] = { kind = kind, s0 = s0, hl = nil, seed = (seed % 9973) + n * 31 }
	end
	function storm.Destroy() destroyStorm(storm) end
	storm.handle = { Destroy = function() destroyStorm(storm) end }
	return storm
end

local function startStorm(storm)
	while #STORMS >= T.MaxStorms do destroyStorm(STORMS[1]) end
	table.insert(STORMS, storm)
	if not bound then
		bound = true
		RunService:BindToRenderStep(RUNNER, Enum.RenderPriority.Last.Value, runner)
	end
	fillCtx()
	local ok, keep = pcall(stepStorm, storm)                        -- the first frame now, not a frame late
	if not ok then
		warnOnce("start", "a Cascade storm failed on its first frame: " .. tostring(keep))
		destroyStorm(storm, true)
	elseif not keep then
		destroyStorm(storm)
	end
end

----------------------------------------------------------------------------------------------------
-- API (VoltaicFX.CascadeGather / CascadeStrike / CascadeEnd delegate here; the payloads are unchanged)
----------------------------------------------------------------------------------------------------
--- CascadeGather { Character, Point, T0 }: the whole storm on its own clock from T0 (the key), the windup included.
--- Returns a handle ({ Destroy }) or nil (not a client, no VoltaicKit, a bad payload, or long over).
function CascadeFX.Gather(data)
	if not RunService:IsClient() then return nil end
	if type(data) ~= "table" or typeof(data.Point) ~= "Vector3" then return nil end
	if not libs() then return nil end
	local T0 = type(data.T0) == "number" and data.T0 or Kit.serverNow()
	local same = findStorm(data.Character, T0)
	if same then return same.handle end                             -- a repeat of a gather already drawn
	local ok, storm = pcall(newStorm, data, T0)
	if not ok then
		warnOnce("new", "a Cascade storm could not be built: " .. tostring(storm))
		return nil
	end
	if not storm then return nil end
	startStorm(storm)
	-- (2026-10-19, audit P5D-15) an End that came first (CascadeFX.End kept it)
	local pend = CascadeFX.PendingEnds
	for i = #pend, 1, -1 do
		local e = pend[i]
		if os.clock() - e.At > 15 then
			table.remove(pend, i)
		elseif (e.T0 == nil or math.abs(e.T0 - storm.T0) < 1e-3)
			and (e.Character == nil or e.Character == storm.Character) and not (e.T0 == nil and e.Character == nil) then
			table.remove(pend, i)
			CascadeFX.End({ Character = e.Character, T0 = e.T0 })
		end
	end
	return (not storm.Dead) and storm.handle or nil
end

--- CascadeStrike { Character, Point, N, At, T0 }: strike N's ground point. Re-aims fork N (1-4) or the dominant bolt
--- (5); drawn on the storm's clock whenever the message arrives. With no storm for it (this client joined mid-cast)
--- the storm is built from the strike's Point and T0, already caught up.
function CascadeFX.Strike(data)
	if not RunService:IsClient() then return end
	if type(data) ~= "table" or typeof(data.At) ~= "Vector3" then return end
	local n = tonumber(data.N)
	if not n or n ~= math.floor(n) or n < 1 or n > 5 then return end
	if not libs() then return end
	local T0 = type(data.T0) == "number" and data.T0 or nil
	local storm = findStorm(data.Character, T0)
	if not storm then
		if not T0 or typeof(data.Point) ~= "Vector3" then return end
		local ok, built = pcall(newStorm, data, T0)
		if not ok then
			warnOnce("new", "a Cascade storm could not be built: " .. tostring(built))
			return
		end
		if not built then return end
		startStorm(built)
		if built.Dead then return end
		storm = built
	end
	storm.hitAt[n] = data.At
	storm.anyHit = true
	if n > (storm.lastN or 0) then storm.lastN = n end            -- (the server strikes in order: End reads how far)
	if storm.predDone then
		local S = Kit.clock(storm.T0) + storm.Shift - storm.W
		local ok, err = pcall(applyHit, storm, n, S)
		if not ok then warnOnce("hit", "a Cascade strike could not be aimed: " .. tostring(err)) end
	end
end

--- CascadeEnd { Character, T0 }: the server has no more strikes. After any strike that changes nothing (the break-up
--- is on the clock). Before one -- the storm was called off, nothing ever struck -- there is no release: heard in the
--- windup (only the hands were lit), the storm goes; later, the cloud hurries on to its break-up from where it is
--- (CatchUp: x3 its pace), never a jump.
function CascadeFX.End(data)
	if not RunService:IsClient() then return end
	if type(data) ~= "table" then return end
	local T0 = type(data.T0) == "number" and data.T0 or nil
	-- (2026-10-19, audit P5D-15) an End heard before its storm exists here (the first storm still loading the kit, or
	-- being built) is kept for 15 s; Gather applies it the moment the storm is up, so a cancelled storm is not drawn
	local pend = CascadeFX.PendingEnds
	local function keep()
		pend[#pend + 1] = { T0 = T0, Character = data.Character, At = os.clock() }
		if #pend > 16 then table.remove(pend, 1) end
	end
	if not Kit then
		keep()
		return
	end
	local found = false
	for _, storm in ipairs(table.clone(STORMS)) do
		local mine
		if T0 then
			mine = math.abs(storm.T0 - T0) < 1e-3 and (data.Character == nil or storm.Character == data.Character)
		else
			mine = storm.Character == data.Character
		end
		if mine then found = true end
		if mine and not storm.Dead and not storm.Ended then
			storm.Ended = true
			local S = Kit.clock(storm.T0) + storm.Shift - storm.W
			if not storm.anyHit then
				storm.Cancelled = true
				if S < 0.05 then
					destroyStorm(storm)                  -- nothing but the windup existed: no cloud conjured to break up
				elseif S < 1.75 then
					storm.catchUp = 1.75 - S             -- (stepStorm spends it)
				end
			elseif (storm.lastN or 0) < 5 and S < storm.HIT then
				-- the server stopped after strike lastN (the caster died, the round reset): what it never struck is not
				-- drawn -- the later forks do not re-strike (no sparks, no skeleton, no light), and there is no dominant
				-- bolt, hitpause or flash; the cloud breaks up on its own clock. (Heard at or after the contact, the
				-- strike has been drawn already and stands.)
				storm.Truncated = true
				storm.endV = S
			end
		end
	end
	if not found then keep() end
end

--- EXTRA: destroys every storm in flight.
function CascadeFX.Clear()
	for _, s in ipairs(table.clone(STORMS)) do destroyStorm(s) end
end

return CascadeFX
