--[[
	RailspikeFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/RailspikeFX

	RAILSPIKE, RE-LIT (2026-09-27). Railspike is Voltaic's Mobility Technique: a fixed 0.55 s windup on a press
	(VoltaicTuning.Railspike.ChargeTime), then a hitscan rail through every body on a 90-stud line. The damage is the
	server's and lands on the fire instant; everything drawn after that instant is afterglow. This module is the Roblox
	port of blender_scripts/voltaic/railspike_bl.py AS IT IS NOW -- pass 2, the jag corrective, the fan and the dispersal:
	its T table (Tuning below, under the same names), plan_windup / windup_frame, strike_layout / jag_rope, line_frame,
	strand_fade / line_env, pierce_frame / streaks, impact_frame and sparks_frame -- and of
	vfx_blocking/voltaic/RAILSPIKE_showcase.md (timings, layering, budget, flags). The strike's SILHOUETTE is v2's
	(anim_railspike2.py: three strands on a camera-facing bow per leg, lanes, pinch, per-shot wander, 30 Hz joint and knot
	jitter, width flicker, the two-frame accent, the depth stack, the 0.40 s hold, the 0 / 2 / 1 break order), imported
	number for number. It replaces the comic v2.1 build whole: no kit meshes (VT_Railspike_Charge / _Chevron /
	_Strand_01..04 are no longer drawn) and no VFXLibrary emitters. Everything is light, drawn with the kit's re-lit
	toolkit, the way ChainBoltFX, VoltOrbFX and OverchargeFX draw theirs.

	THE EMULATION MAP (the showcase's stand-ins -> the Roblox pieces they stood in for)
	  * a camera-facing strip (overcharge_bl.strip) -> VoltaicKit.BeamChain: FaceCamera Beams, Segments 4, one per run.
	    CORE: Kit.Tex.Core, LightEmission 1. GLOW: Kit.Tex.Glow, LightEmission 0.55, opacity x GLOW_ALPHA (0.85). A joint
	    that turns more than 60 degrees on screen breaks at 85 % width (strip()'s rule); a broken GLOW joint gets the
	    showcase's soft round cap (draw(): a glow_add sprite 1.1 x the glow's width at half its Brightness) -- the kit's
	    cap Beam, textured VT_Overcharge_Soft, painted with the glow (paintCaps). Every chain here is PAINTED per Beam:
	    the showcase's per-point k (opacity) and wh (toward white) become each Beam's Transparency and Color sequences,
	    its per-point hot layer that Beam's Brightness -- Roblox pays per Beam, never per emulated point. A strand is ONE
	    chain with both layers on the same attachments (the showcase's gstep-2 glow: a glow point on every corner).
	  * a star sprite pair -> ParticleEmitters with Kit.Tex.StarGlow (LightEmission 0.75, Base) under Kit.Tex.StarCore
	    (LightEmission 1, Light), ZOffset toward the camera (the showcase's z push, same size on screen). Particle Size is
	    half the quad (a Roblox particle draws 2 x Size), so the showcase's star(size) is Size = size (glow) / 0.8 x size
	    (core). A star is re-emitted (Clear + Emit(1)) whenever its size, roll, colour, opacity or light changes: a knot
	    re-rolls at 30 Hz, the pops grow every frame.
	  * glow_add sprites -> ParticleEmitters with VT_Overcharge_Soft (rbxassetid://130067461865773), LightEmission 1:
	    the seed's glow, the motes and the branch-tip sparks are KEYED sprites (one Attachment + emitter each,
	    re-emitted wherever it moves: plan_windup's motes every frame, the tips on every re-roll), and v2's sparks
	    (VoltSparks bursts and RailspikeCrackle emitters with v2's exact motion, re-textured soft: one sprite each, Size
	    x 0.55 -- the showcase's 0.55-quad glow).
	  * "flats" (glows laid ON a surface) -> a SurfaceGui (LightInfluence 0, Brightness) with a soft ImageLabel on an
	    invisible part turned to the surface normal (showcase flag 5). Not a Decal (it cannot glow) and not a flat Beam (a
	    FaceCamera=false Beam's ribbon axis is still unverified in this engine: VoltOrbFX's RibbonNormal).
	  * point lights -> PointLights, Brightness and Range straight from the T numbers (Kit.light: none on a flat-lit map,
	    halved in daylight). compositor Glare -> Kit.bloomPulse.
	  * the showcase's stage (Blender, Z up, AIM +X, the caster behind the shot plane at +Y) -> the live shot: the line
	    frame is v2's (the shot's direction, its camera-facing lateral lat = c x awayPerp, the view ray), per LEG as the
	    comic port did (leg 1 leaves between the hands, off the eye's line). Hand-local windup vectors (x, y, z) map to
	    aim * x + bodyward * y + up * z, bodyward = up x aim for the right hand (the showcase's +Y, the caster's side),
	    mirrored for the left. Blender "-Y" offsets (toward the side camera) become "toward this viewer's camera".

	THE BEATS, in SHOT time (real seconds x ShotTimeScale, the house rule). A frame is one 60 Hz game frame; a TICK is a
	30 Hz runtime frame (the v2 crackle, re-rolled on it).
	  1 WINDUP  0.00-0.55 on the press, off BOTH hands (the owner, 2026-09-28: both arms throw it, out at shoulder
	            height and well apart -- CastPose / Viewmodel RailspikeSurge): a violet seed star in each palm warming to
	            Light (0.04-0.30), growing 0.35 -> 1.00 (Sine/Out) and spinning 6 rad/s; THE SURGE, CONSTANT and SPREAD
	            OUT HORIZONTALLY (not the showcase's reeled-in arcs): from each hand a flat fan of bolts along the aim
	            (-12 .. +48 degrees inward .. outward about the vertical, +-6 off level), bridges crackling hand to hand,
	            all from 0.02-0.18 to the shot, re-jagged every tick, reaching 2.4 -> 4.2 studs (first person
	            1.1 -> 2.1) as it charges -- level on the BODY's facing wherever the arms are the body's; three threads
	            spiralling into the point between the hands with bright bands running down them (in by 0.14); motes
	            drawn inward; a soft glow and a PointLight climbing 0.5 -> 2.6 (violet -> Base); the "loaded" flash over
	            0.50-0.55. Past 0.55 (the shot is late: the network) it HOLDS that state until the shot, a stop or its
	            watchdog (ChargeTime + GiveUp + 0.3). Causal: nothing reads the release.
	  2 THE LINE  frame 0: at full length. Per strand per leg the rope is v2's joints; along it the strand's OWN zigzag
	            (jag_rope: lognormal kink gaps, subtle / sharp kinks, the odd step, easing in at the knots, 1.3x amplitude
	            at the wall), re-rolled every tick from its own seed (the cast's T0 and caster, the strand, the leg, the
	            tick). The FAN: lanes x 0.80 -> 2.00 from the hand to the far end, pinching onto a body to 45 % and onto the
	            end to 35 %. Each strand: a Light CORE on its zigzag wrapped in a Base GLOW on every corner of it (the
	            broken ones capped), lit ALONG IT by the braid (hot -> cool every 6 studs, a third of a turn apart, creeping
	            8 studs/s), the corners (whiter, wider; mid-runs at 62 %) and a PULSE (every 0.30 s, 125 studs/s, from game
	            frame 2, out of step per strand), the hottest points brighter (HotB). A faint haze Beam per leg. Knots: a
	            star on the muzzle, every body and the end (the muzzle pop 1.0 -> 1.9 over 0.08 s, bodies 0.8x -> 1.52x,
	            then 0.62x +-10 % re-rolled every tick). The dispersal (a tree): jagged branches off the kinks -- rare and
	            short at the hand, many and long toward the end -- twigs off those and twigs off those, a spark on every
	            tip and loose ones past the far tips.
	  3 PIERCE  frames 0-2 at every body's ENTRY: a small star, streaks thrown up and down out of the entry face and out
	            of the exit (peaking on frame 1, Base tips on frame 2), a hot spot ON the body, a one-frame light.
	  4 IMPACT  where the line stops on a surface: a star (1.1x on frame 1, shrinking to 0.45x by 0.12 s, gone 0.20), arcs
	            crawling over the surface (6 for 3 frames, then 3 through the hold, re-rolled every tick), a light that
	            lands at full for one frame and settles to a held glow by 0.15, the caster's Bloom kick; the hot spot
	            under it cools Light -> Base -> violet once the strands leave, gone at +0.93.
	  THE END   the hold lasts 0.40; then the strands leave top, bottom, middle 0.04 apart, each FADING over 0.10 (dim,
	            thinner, cooling to Base) into two frames of violet ember: the last is gone at +0.613. The knots, the haze
	            and the hold lights ride one continuous envelope (line_env).

	API (unchanged from the comic build; CONTRACT.md section 6)
	  RailspikeFX.Charge(character, opts) -> handle   the windup. handle:Stop() fades it (StopFade), handle:Destroy()
	      removes it at once. opts.Own the local caster's own press; opts.T0 the server time of the cast
	      (RailspikeChargeStart; a late one skips ahead); opts.Side (unused: the surge leaves both hands); opts.Level (PORT plumbing: the
	      highest level this windup may build to, default 1, clamped to MaxLevel = 0). A second Charge for a character
	      whose windup is live returns that windup.
	  RailspikeFX.ChargeStop(character)               RailspikeChargeStop (an interrupt, a death): the windup fades out.
	  RailspikeFX.Fire(data, opts) -> handle|nil      RailspikeShot { Character, Origin, Dir, Dist, Hits, Points, T0 }
	      (End for Dist, Level optional). opts.Own the caster's own draw from its claim (a broadcast of the same shot
	      inside OwnEcho is then skipped); opts.Side; opts.Level. Fire ends the character's windup at once: the seed
	      becomes the muzzle pop.
	  RailspikeFX.Clear()                             EXTRA: destroys everything in flight.
	  PIERCE POINTS: Points[i] is Hits[i]'s claimed hit position -- the eye ray's hit on that body, i.e. its ENTRY face (the
	  caster's own claim, the server's validated broadcast and the harness all send it that way). The exit, the surface
	  normal and the body's centre on the line are derived here by two raycasts against Hits[i] alone; a Points entry with
	  no model exits 1.2 studs on and faces the shooter; Hits with no Points enter where the line meets the model. The
	  surface the line stops on (its normal) is found by one raycast at the end; a line that ends in the air has no impact
	  star, arcs, light or hot spot (its end knot still draws). Nothing new is needed from the server.

	FIRST PERSON (the caster's own view; not built in the showcase, flag 8 -- OverchargeFX's precedent): the windup sits at
	the Viewmodel's two muzzles ~1.3 studs from the lens, 25 degrees either side of the crosshair, so its geometry
	(threads, motes, the bolts' widths) is drawn at FpScale and its seed stars at FpSeed; the fans run BoltFpLen out
	along the camera's aim (the first-person arms follow it) and fade by their nearest point to the lens
	(FpWindupLens); there is no windup light (it would light
	the Viewmodel sleeve). On the line, the muzzle knot is FpSeed-sized; the glow and the haze fade in with distance from
	the lens (FpGlowLens: the 0.62-stud glow at 1.5 studs would fill a third of the screen); near the lens the kinks throw
	less and the core is thinner (FpJag), and the core fades in over the first stud off the hand (FpCoreFade) -- but it
	is never faded out along the line (v2's rule: faded, the strands collapse into a scribble round the crosshair;
	unfaded they leave the hand low-right). The glow's round caps fade in faster (FpGlowLens squared); the dying
	strand's two ember frames keep the same lens rules; no branch (so no twig or tip spark) roots within FpGlowLens[2]
	of the lens (OverchargeFX's "no forks in first person: they fill the lens"), and a branch's core takes the strand's
	FpJag thinning at its root (never wider than the strand it hangs off). Kit.bloomPulse skips every kick while
	the first-person arms are up.

	SETTINGS
	  * Reduce Flashing: every Beam x CalmBeam (0.85); the muzzle / pierce / impact flashes x CalmFlash (0.6), half on
	    their first frame (eased in); no Bloom (the kit's rule); no pierce star; the loaded flash at half; the pulse's
	    whitening x CalmPulse; the zigzag, joint jitter, knot, arc, windup bolt and hold / impact light-flicker re-rolls every
	    CalmEvery ticks (10 Hz, v2's rule); no width flicker, no accent; no camera punch (Viewmodel's rule).
	  * Thin (VoltaicKit.thin: another player's cast under Reduce Enemy VFX, or Graphics Quality's density under 0.6):
	    the showcase's thin tier -- StrandSegs.Thin kink runs a strand, the glow on every 4th corner, the dispersal cut
	    to ThinBranches depth-1 branches a strand as a core only with their tip sparks (no twigs, no loose sparks, no
	    branch glow), no haze, 2 pierce streaks a body -- plus ThinImpactArcs, no hold lights, Bolts.Thin windup bolts a hand, Bridges.Thin
	    and no bolt forks, ThinThreadPts; particle counts (the motes, v2's sparks) x the density and x 0.5 for someone
	    else's cast (VFXLibrary's rule for its own emitters).
	  * Flat-lit maps: no PointLights (Kit.light), BeamChain's own tone-down, and every particle / SurfaceGui emission x0.35,
	    Brightness x0.7. Daylight: every PointLight x0.5 (Kit.light); glow and haze Brightness x DayGlow (OverchargeFX).
	  * Camera: Viewmodel.Punch(CasterPunch) for the caster on the fire frame; anyone within PunchReach of a body gets
	    NearPunch x (1 - d / reach) through Kit.punchNear -- both through Viewmodel, so the Camera Shake setting scales them.
	  * ShotTimeScale: every clock here is shot time; emitters run at its TimeScale; Bloom decays in shot time (the kit).

	BUDGET (enabled Beams, High)
	  The zigzag is the one thing that must cost Beams per run (a Beam is straight): a strand is one chain, core + glow
	  on every corner, so 2 Beams a run, plus a cap on every broken glow corner. Kink spacing (PORT, screenK()): the
	  showcase's WORLD gaps wherever the line is seen at the showcase's own scale -- d / sin (distance over the sine of
	  the line's angle to the view ray) up to JagScreen (52 studs, the far end of the showcase's ref camera view) --
	  wider in step beyond it (further, or foreshortened: the caster down their own line), clamped 1..JagGapMax: never
	  denser on screen than the showcase. Each strand holds at most StrandSegs runs, shared out over its legs by their
	  expected kinks (past its share a leg's gaps stretch evenly, so the kinks still span it) -- a safety cap for long
	  lines seen square on; the showcase's own 43.5-stud scene fits under it. Everything else is folded: the mid-run
	  points and the hot layer into each run's sequences, one haze Beam a leg, knots and stars as particles, one straight
	  soft-ended glow Beam per streak / arc / depth-1 branch.
	  MEASURED (a Lua 5.4 mock of the Roblox API running this module and the real VoltaicKit, enabled Beams under
	  workspace counted every frame, 2026-09-27 -- the geometry is real, the engine is not):
	    someone else's, the showcase's scene seen square on from 27 studs (two bodies, a wall at 43.5): 22-23 kinks a
	      strand on the 26-stud first leg (the jag corrective's 23.4), 36-38 over the line; fire frame 533 = strands 242
	      + their caps 78, dispersal 138, pierce 42, impact 30, haze 3; hold ~441 (the showcase's own table: ~500 / ~400
	      before its dispersal, which it measured at ~2.5x the rest uncapped).
	    own cast, a duel shot (a body at 26, a wall at 40): windup <= 73 (the old arcs; the constant bolts, measured in
	      Studio Play 2026-09-28, first person: <= 116, ~95 mean, 108+ once every bolt is in); fire 223 (third person) / 284 (first person);
	      hold ~201 / ~227; gone at +0.62 (the last ember) and every instance cleared by +0.93.
	    six bodies in a row and a wall at 90, own, first person (the worst case): fire 460 (peak 477), hold ~413.
	    thin (Reduce Enemy VFX): a 90-stud whiff 87; Graphics Quality 0.5, an 8-stud wall 54.
	  The levers, if play says it is too heavy: MaxBranches / MaxTwigs (the dispersal, ~4.7 Beams a piece), StrandSegs
	  (the density of long lines), LOOKS.strand.Caps (the corner caps).
	  Particles: 2 a knot star, 2 a pierce star, 2 the impact star, 5 the seed, the motes (~11 live), the tip sparks (<=
	  MaxSparks a strand), v2's sparks; 35-80 live at the fire (116 for six bodies). SurfaceGuis: one a body (2 frames),
	  the wall's. PointLights at once: the muzzle flash, 2 hold lights, the impact and one a body for 2 frames
	  (MaxPierceLights 3) -- at most 7; 1 in the windup.

	DEVIATIONS from the showcase (all PORT)
	  1 Kink spacing in screen space past the showcase's own view scale, and the StrandSegs cap (BUDGET above). The rope,
	    its lanes and the per-kink rules are the showcase's; only the gap between kinks can grow, and only where the
	    showcase's cameras never looked (far, or foreshortened) or on a line longer than the cap covers.
	  2 The strand glow's ends sit ON the knots (it shares the core's attachments), not pushed out 35 % of its width; it
	    is 0 wide there, under the knot star.
	  3 The hot layer is folded: a run's Brightness x (1 + (HotB - 1) x HotFold x its mean heat), its colour toward white
	    by half its heat. The corner's 1.3x core width is its mean (1.15) along a run (a Beam's width runs straight
	    between corners).
	  4 The dispersal is capped (the showcase's own shipping advice): MaxBranches a strand -- a random pick of the kinks
	    that roll one on the showcase's rule, so the pick keeps its distribution -- and MaxTwigs a strand shared by them,
	    against the showcase's ~15 branches and their twigs uncapped: a VISIBLY thinner canopy at the wall than the
	    owner's "branches of trees" (the lever: MaxBranches / MaxTwigs); no floor cut (the floor is not known). The
	    showcase's note also wants a jag TEXTURE so a branch is one Beam: there is none and none can be uploaded here
	    (flagged), so a branch is a chain (bolt_spine's 2..4 kinks).
	  5 The wall arcs are jag depth 2 (the showcase's 3); a streak's / arc's / branch's glow is one straight Beam with
	    soft ends, not a chain (so those glows have no caps).
	  6 The haze is one Beam a leg, its width constant, its ends and the first-person lens faded by Transparency.
	  7 The fan and the dispersal are measured on max(FanMin, the line's length), not the showcase's fixed 43.5 studs, so
	    every shot opens toward its own end; the hold lights sit at the showcase's shares of the line (13 / 43.5, 30 / 43.5).
	  8 Hold-to-charge is not a mechanic (showcase flag 3, the owner's call): MaxLevel = 0 clamps every level; the level
	    plumbing (FullAt, the Over / Hold numbers, opts.Level / data.Level) is kept so it could be passed later. The
	    windup's slow Bloom build is one kick at the loaded flash (caster only).
	  9 v2's sparks re-drawn with one soft sprite each (the showcase drew a glow and a hot core).
	  10 Random draws are per cast (seeded from the broadcast's T0 and the caster): every observer of one shot rolls the
	    same kinks for one camera, but the zigzag is laid on each viewer's own camera-facing lateral and screen spacing,
	    so no two viewers see identical geometry (showcase flag 13 asked for identical; that is not possible with a
	    camera-facing layout -- v2 was the same).
	  11 Stars are re-emitted particles (Clear + Emit) rather than Beam quads, so they cost no Beams.
	  12 Pierce streaks: the showcase's 2 up / 2 down / 3 out of the exit a body up to two bodies (PierceBudget 14), then
	    fewer in the same shares (4 a body at three, 3 at four, 2 from five: one off the entry, alternating up / down, and
	    one out of the exit).

	FLAGS (the owner's, to check in Studio)
	  1 Compile-checked with Studio's own compiler (tools/luau_compile_check.py) and run under a Lua 5.4 mock of the Roblox
	    API (every beat, every setting and the edge paths: late, stale, echo, point blank, no Character, a stop, a death,
	    the watchdog, Clear; the silhouette plotted from a bystander's and the caster's cameras). NOT yet played in
	    Studio: the look is unmeasured on screen, the Beam counts are the mock's.
	  2 The SurfaceGui hot spots are alpha-blended with Brightness > 1, not additive like the showcase's glow_add.
	  3 First person is this port's own design (FpScale / FpSeed / FpWindupLens / FpGlowLens / FpJag / FpCoreFade and the
	    branch gate), to be judged in play. v2's own fan (the lanes spreading about a stud within 4 studs of the hand)
	    still reads large from the caster's eye; that is the silhouette, kept.
	  4 A character is not a pillar: the strands pass inside the struck body (Beams are depth-tested); the knot star
	    (pushed 0.6 toward the camera, ZOffset 0.3) and the pierce burst sit in front of it (showcase flag 6).
	  5 No jag texture for the branches (deviation 4); an uploaded one would let a branch be a single Beam.
	  6 VFXLibrary.VoltChargeEmitter / RailspikeCrackleEmitter and the VT_Railspike_* kit meshes are no longer used by
	    Railspike (VFXLibrary's presets are unchanged; their motion numbers are copied here).
	  7 The budget is the showcase's own line (BUDGET): ~530 Beams at a bystander's fire frame, ~440 through its hold,
	    for 0.6 s; every strand Beam is repainted every frame (the braid creeps). Watch the frame time in a busy fight.
	  8 The strand / arc caps are the kit's cap Beams, painted from here: paintCaps walks BeamChain's own break list
	    (Brk, CapPool, CapsShown, N) in Set's order -- a change to that part of VoltaicKit must keep it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local RailspikeFX = {}

-- VT_Overcharge_Soft (export/voltaic/VT_Overcharge_Soft.png), uploaded 2026-09-26. nil would draw with Kit.Tex.Implosion.
local SOFT_TEX = "rbxassetid://130067461865773"

----------------------------------------------------------------------------------------------------
-- The numbers: railspike_bl.py's T (and anim_railspike2.py's for the silhouette), under the same names. Seconds of SHOT
-- time: from the press (the windup), from the fire frame (everything else). EVERY NUMBER IS A PROPOSAL (2026-09-26).
-- ChargeTime, Hold and GiveUp are replaced by VoltaicTuning.Railspike's when that module loads. PORT marks this
-- module's own numbers.
----------------------------------------------------------------------------------------------------
RailspikeFX.Tuning = {
	-- the live rules
	ChargeTime = 0.55,             -- T.Press (R2.CHARGE): the fixed windup; the shot fires at level 0
	GiveUp = 1.0,                  -- the server's backstop past the charge; a windup's watchdog is both + 0.3
	Hold = 0.40,                   -- R2.HOLD: full strength from the fire frame
	FullAt = 1.20,                 -- T.FullAt: level 1 of the showcase's hold-to-charge (NOT a mechanic: MaxLevel)
	MaxLevel = 0,                  -- PORT: every charge level (the windup's own, a shot's Level) is clamped to this

	-- 1 WINDUP
	Node = { 0.35, 1.00 },         -- the seed's scale over the press, Sine/Out (v2's node: R2.NODE_S0 / S1)
	NodeSpin = 6.0,                -- rad/s about the aim (R2.NODE_SPIN)
	NodeOver = 0.45,               -- x more scale at level 1
	HoldI = 0.9,                   -- the windup's intensity keeps climbing through a hold: + this at level 1
	-- THE SURGE (the owner, 2026-09-28): BOTH hands throw it -- the arms out at shoulder height and well apart
	-- (CastPose / Viewmodel RailspikeSurge) -- and its bolts are CONSTANT and spread out HORIZONTALLY: from each hand a
	-- flat fan of long bolts out along the aim, a few degrees above or below level, and bridges crackling hand to hand,
	-- each from its strike-in to the shot, re-jagged every tick -- none born, none dying. The level is the BODY's (its
	-- facing) wherever the arms are the body's; only the first-person arms follow the camera. (Before, in turn: the
	-- showcase's gathering arcs blinked in and out; one hand's ring hung below the hand; one hand's bundle ran along a
	-- third-person camera's pitch into the ground.)
	Bolts = { Own = 4, Other = 3, Thin = 2 },     -- a hand
	Bridges = { Own = 2, Other = 2, Thin = 1 },   -- hand to hand
	BoltIn = { 0.02, 0.016, 0.05 },   -- bolt k (a shuffled order over both hands and the bridges) strikes out at
	                               -- [1] + k x [2], over [3]
	BoltLen = { 2.4, 4.2 },        -- studs out from the hand: at the press / at 0.55 (reaching further as it charges) ...
	BoltFpLen = { 1.1, 2.1 },      -- ... in first person (the hands ~1.3 studs from the lens, 25 degrees either side)
	BoltLenOver = 0.35,            -- ... x (1 + this x level); x 0.85..1.15 a bolt
	BoltFan = { -12.0, 48.0 },     -- degrees about the vertical off the aim a hand's fan spans: inward (-) .. outward (+)
	BoltTilt = 6.0,                -- degrees above / below level a bolt runs (x -1..1 a bolt)
	BoltSweep = { 5.0, 1.3 },      -- degrees / Hz each bolt sweeps side to side about its place in the fan
	BoltSway = { 2.5, 3.0 },       -- degrees / Hz its tilt sways
	BoltBreath = { 0.10, 4.0 },    -- its length breathes this much, this many times a second
	BoltJag = 0.10,                -- Kit.jag's first kink throw, x the bolt's length
	BridgeBow = { 0.18, 0.12 },    -- a bridge's middle pushed out along the aim / up or down (a bridge each way), x the gap
	BridgeJag = 0.12,              -- a bridge's first kink throw, x the gap between the hands
	BoltDepth = { 3, 2 },          -- Kit.jag depth: the caster's own / anyone else's (and thin)
	BoltFlicker = { 0.85, 1.10 },  -- per tick, per bolt: core Brightness x (none under Reduce Flashing)
	BoltFork = 0.30,               -- a fork's length, x the bolt's
	Arc = { 0.045, 0.34, 2.2, 1.2 },  -- a bolt's core width, glow width, core Brightness, glow Brightness
	ArcOver = 0.45,                -- brightness x (1 + this x level)
	ArcFork = 0.4,                 -- per bolt per tick: the chance of a fork (plan_windup's share); none when thin
	MoteRate = 42.0,               -- inward sparkles a second at 0.55 (x (0.6 + 0.4 charge) x (1 + level))
	Threads = 3,                   -- one per strand of the shot
	ThreadR = { 1.05, 0.45 },      -- the spiral's outer radius: at the press / at 0.55
	ThreadFlow = 2.2,              -- bright bands a second running down each thread into the point (x (1 + level))
	ThreadAhead = { 1.2, 0.35 },   -- studs ahead of the charge point the spiral's outer end sits
	ThreadTurns = 0.70, ThreadSpin = 9.0,   -- turns along a thread; rad/s it wheels
	Thread = { 0.05, 0.36, 2.2, 1.1 },      -- core / glow width, core / glow Brightness (x (0.45 + 0.55 charge))
	ThreadOver = 0.5,
	SeedGlow = { 0.35, 0.80, 1.6 },         -- the soft glow: Size at the press start / at the fire; Brightness
	SeedLight = { 0.5, 2.6, 1.6, 7.0 },     -- PointLight: Brightness at the start / at 0.55 / extra at level 1; Range
	SetFlash = 0.05,               -- the seed flashes white over the last this-many seconds to 0.55 ("loaded")
	ThreadPts = 8, ThinThreadPts = 6,       -- PORT: points a thread (the showcase's 14; the band folds into sequences)
	StopFade = 0.08,               -- PORT: a stopped windup fades out over this
	LoadedBloom = { 0.25, 0.06 },  -- PORT: the caster's one Bloom kick at the loaded flash (+Intensity, tau)

	-- 2 THE LINE: v2's silhouette (anim_railspike2.py) ...
	Pop = 0.08, NodePop = 1.90,    -- R2.POP: the muzzle knot 1.0 -> 1.9 ...
	PierceScale = 0.80,            -- ... body and end knots 0.8x -> 1.52x
	PiercePush = 0.60,             -- body and end knots pushed this far along the camera ray, clear of the body
	KnotScale = 0.62, KnotScaleJitter = 0.10,   -- then 0.62x +-10 %, re-rolled every tick
	AccentTicks = 2, AccentWidth = 1.30,        -- 1.30x wide for the first two ticks
	BreakOrder = { 0, 2, 1 },      -- strands 1 / 2 / 3 (top / middle / bottom) leave at Hold + this x BreakStagger
	BreakStagger = 0.04,
	Lanes = { 1.10, 0.05, -1.00 }, -- studs along the lateral at full spread (R2.LANE)
	LaneWidth = { 1.00, 0.86, 1.10 },
	Wander = { 0.20, 0.32, 0.20 }, -- per-shot static wander of every interior joint, x spread
	DepthStep = 0.20,              -- the middle strand this far toward the camera, the bottom one this far away
	Jitter = 0.15,                 -- per-tick jump of every interior joint, studs
	KnotJitter = 0.05,             -- per-tick spread of the strand ends at a knot
	Flicker = { 0.85, 1.12 },      -- per-tick, per-chord width scale
	SpreadFullAt = 14.0,           -- a leg shorter than this fans proportionally less
	RampIn = 4.0, RampOut = 7.0,   -- the fan-out off a knot / the convergence onto the next (capped 35 % / 45 % of a leg)
	TileLen = 5.0, TileMax = 6,    -- v2's chord: a rope has round(L / 5) chords, 1..6 a leg
	JagBase = 0.38,                -- railspike_strands.JAG_AMP: a kink's full throw, studs
	Tick = 30,                     -- Hz: the runtime frame the crackle re-rolls on
	CalmEvery = 3,                 -- Reduce Flashing: every this-many ticks (10 Hz)

	-- ... drawn re-lit (railspike_bl T)
	StrandCore = 0.10, StrandGlow = 0.62,   -- widths, x the lane width / flicker / accent
	StrandB = { 1.15, 1.25 },      -- core / glow Brightness
	StrandOver = { 0.40, 0.15 },   -- level 1: width x (1 + a), brightness x (1 + b)
	Braid = { 6.0, 8.0 },          -- THE TWIST: hot -> cool every this-many studs, creeping down range at studs/s
	TwistK = { 0.40, 1.0 },        -- opacity: the cool part of the braid -> the hot part
	TwistWhite = 0.20,             -- whiteness at the hot part
	CornerWhite = 0.30, CornerW = 1.30,     -- a zigzag corner: whiter (x the braid), and the core 1.3x wide
	MidK = 0.62,                   -- mid-run opacity (the corners carry the light)
	HotB = 2.4,                    -- x core Brightness where it is hottest (braid x corner x pulse)
	HotFold = 0.55,                -- PORT: the hot layer's width share, folded into its run's Brightness
	Pulse = { 0.30, 125.0, 3.0, 0.55, 1.2 },   -- period s, studs/s, width studs (sigma), whiteness, glow widening
	PulsePhase = { 0.0, 0.10, 0.20 },
	JagGap = { 0.45, 2.00, 0.45, 1.13 },       -- studs between kinks: clamp lo / hi, lognormal sigma, mean
	JagAmp = { 0.25, 0.85, 1.00, 1.35, 0.28 }, -- x JagBase: subtle lo / hi, sharp lo / hi, share of sharp
	JagSame = 0.14,                -- chance a kink keeps its side (a step) -- never twice running
	JagEnd = 1.0,                  -- studs from a knot over which kinks ease to 55 %
	JagStrand = { { 0.95, 1.00 }, { 1.12, 0.90 }, { 1.00, 1.08 } },   -- per strand: gap x, amplitude x
	Branch = { 0.05, 0.70, 0.8 },  -- chance a kink throws a branch: at the hand / at the end, rising as u^this
	BranchLen = { 0.7, 3.2 },      -- studs, at the hand / at the end (x 0.7..1.3)
	BranchRake = { 18.0, 50.0 },   -- degrees off the strand's run, leaning down range, to the kink's own side
	BranchSub = { 0.15, 0.75, 0.50 },   -- twigs: from this far down range, their chance at the end, length x the parent
	BranchTurn = { 15.0, 40.0 },   -- degrees a twig turns off its parent (outward three times in four)
	BranchDepth = 3,               -- branch -> twig -> twig; every piece jagged by bolt_spine's rule (2 / 3 / 4 kinks
	                               -- under 1.0 / under 1.8 / past, leaning 0.10 + 0.07 x its length)
	BranchW = { 0.90, 0.65, 0.45 },     -- core width x the strand's, per depth, tapering to nothing at the tip
	BranchB = { 1.00, 0.80, 0.65 },     -- core Brightness x the strand's, per depth
	BranchGlow = 0.55,             -- a depth-1 branch's glow, x the strand's (twigs are a core only)
	Spark = { 0.12, 0.08, 2.4 },   -- a tip's spark: Size at depth 1 / 3, Brightness
	SparkLoose = { 0.55, 2, 0.15, 0.70 },   -- loose sparks past a tip: chance, at most, studs past it lo / hi
	MaxBranches = 6, MaxTwigs = 4, -- PORT: a strand's dispersal a tick -- a random pick of the kinks that roll a branch
	                               -- (the showcase's own shipping advice: cap branches per strand), twigs shared by them
	ThinBranches = 3,              -- PORT: the thin tier's (the showcase's): depth-1 branches as a core, their tip sparks
	MaxSparks = 16,                -- PORT: tip and loose sparks a strand
	Fan = { 0.80, 2.00 },          -- the lane spread (and wander) x this, from the hand to the end
	Pinch = { 0.45, 0.35 },        -- the bundle narrows onto a body / the end to this share of its spread there
	GlowFan = { 1.00, 1.90 },      -- the glow and the haze widen with it
	JagFan = 1.30,                 -- the zigzag's amplitude x this at the end
	FanMin = 20.0,                 -- PORT: the fan runs over max(this, the line's length) studs
	Haze = { 1.6, 0.15, 0.6 },     -- the bundle haze: width, alpha, Brightness
	HoldLights = { { 13 / 43.5, 1.3, 9.0 }, { 30 / 43.5, 1.2, 12.0 } },   -- (share of the line, Brightness, Range)
	Fade = 0.10,                   -- each strand's fade after its break time
	Ember = 2,                     -- frames of violet ember at the end of it
	KnotStar = { 1.25, 2.2, 1.2 }, -- a knot's star: size x the v2 knot scale, core / glow Brightness
	MuzzleFlash = { 3.5, 10.0 },   -- the fire frame's muzzle light (Brightness, Range), Base; x0.4 on frame 1
	Bloom = { 0.55, 0.12, 0.06 },  -- the fire's Bloom kick: +Intensity, +Size, tau (the caster's own shot)

	-- 3 PIERCE
	PierceStar = { 0.55, 1.2, 0.8 },        -- size (frame 0; x0.6 on frame 1), core / glow Brightness
	PierceStreaks = { 4, 3 },      -- out of the entry face (half up, half down) / out of the exit
	PierceLen = { 0.8, 1.6 },
	PierceArc = { 0.06, 0.30, 2.8, 1.3 },
	PierceLight = { 5.0, 6.5, 1.5 },        -- Brightness frame 0, Range, Brightness frame 1
	PierceSpot = { 0.75, 2.2 },    -- the hot spot ON the body (frames 0-1): size (x2 = studs across), Brightness
	PierceBudget = 14,             -- PORT: streaks shared out over the bodies: the showcase's 7 a body (2 up, 2 down, 3
	                               -- out of the exit) up to two bodies, then fewer (2..7 a body, always one out the exit)
	MaxPierceLights = 3,           -- PORT: only the first this-many bodies get the one-frame light

	-- 4 IMPACT
	ImpactStar = { 1.30, 1.7, 1.0 },        -- size frame 0 (1.1x frame 1, then to 0.45x by 0.12 s); core / glow Brightness
	ImpactArcs = { 6, 3 },         -- arcs over the surface: the first 3 frames / through the hold
	ThinImpactArcs = { 3, 2 },     -- PORT
	ImpactArcDepth = 2,            -- PORT: jag depth (the showcase's 3)
	ImpactArcLen = { 0.8, 1.9 },
	ImpactArc = { 0.05, 0.30, 2.8, 1.2 },
	ImpactLight = { 5.0, 14.0, 1.4 },       -- frame 0 Brightness, Range; the held glow
	ImpactPush = 2.2,              -- the light sits this far off the surface toward the shooter
	Afterglow = { 1.0, 0.35, 1.0, 0.9, 1.1 },   -- the hot spot: size and cooling time after the strands leave,
	                                            -- Brightness; its size / Brightness under the held knot

	-- v2's sparks (anim_railspike2 SPARKS / CRACKLE = VFXLibrary's VoltSparks / RailspikeCrackle), re-drawn soft
	SparkBurst = 6,                -- VoltSparkBurst on every body and the end, the fire frame
	KnotCrackle = 40,              -- a knot's crackle, a second (bodies and the end; never the muzzle)
	LineCrackle = 1.6,             -- a leg's crackle box: Rate = this x its length ...
	LineSkip = 6.0,                -- ... the first leg's box starts this far out from the hand
	LineBox = { 0.3, 1.9 },        -- the box across the view ray / along the lateral (x spread x fan)
	CrackleLinger = 0.30,          -- the emitters outlive the hold by this much (chips in flight finish)
	SparkSize = 0.55,              -- the soft sprite's Size x v2's preset Size (the showcase's 0.55-quad glow)
	SparkBright = 2.2,

	-- PORT: the budget (see the header)
	StrandSegs = { Own = 36, Other = 42, Thin = 12 },   -- kink runs a strand over its whole line: a safety cap -- the
	                               -- showcase's scene (43.5 studs, three legs) seen square on needs ~41
	JagScreen = 52,                -- studs of d / sin (a point's distance over the sine of the line's angle to the view
	                               -- ray: its on-screen scale). The showcase's ref camera sees its whole line at <= 52 (the
	                               -- wall end: 37.5 / 0.72), its side camera at <= 46: up to this, the showcase's world gaps
	JagSinMin = 0.02,              -- a guard only: a line running into the lens takes JagGapMax
	JagGapMax = 4.0,               -- a gap is at most this x the showcase's

	-- PORT: first person
	FpScale = 0.35,                -- the windup's arcs, threads and motes at the Viewmodel muzzle
	FpSeed = 0.12,                 -- the seed star and the muzzle knot
	FpWindupLens = { 0.8, 1.4 },   -- an arc fades by its nearest point to the lens: gone within / whole past (studs)
	FpGlowLens = { 1.5, 6.0 },     -- the line's glow and haze fade in from / to this far from the lens (its caps as the
	                               -- square); no branch roots nearer than [2]
	FpJag = { 2.0, 9.0, 0.30, 0.40 },   -- the line's kink throw / core width: x [3] / x [4] at [1] studs from the lens,
	                                    -- whole past [2] (a 0.4-stud kink 3 studs off the lens swings 8 degrees)
	FpCoreFade = { 1.2, 2.5 },     -- the core fades in from / to this far from the lens (the hand is ~1.5 away)

	-- camera
	CasterPunch = 0.12, NearPunch = 0.10, PunchReach = 12,

	-- settings
	CalmBeam = 0.85, CalmFlash = 0.6, CalmPulse = 0.5, DayGlow = 1.8,

	-- network / sanity
	LateForgive = 0.25,            -- real seconds of broadcast lateness the strike plays through from its fire frame
	OwnEcho = 1.0,                 -- a broadcast of the caster's own shot this soon after its local draw is skipped
	MaxBodies = 8,
	MergeGap = 0.75,               -- body points closer than this along the line are one knot
	MinLeg = 0.4,                  -- a leg shorter than this draws no strands
	MuzzleSlack = 10,              -- a hand further than this from the shot's origin is not trusted
	MaxHandGap = 6,                -- two hands further apart than this are no pose: the surge keeps to the right one
}
local T = RailspikeFX.Tuning

local F = 1 / 60
local FRAME_TOL = 0.25             -- a quarter frame: "on this frame" against float drift in the clock
local GLOW_ALPHA = 0.85            -- VoltaicFX's GLOW_ALPHA (= BeamChain's GlowAlpha)
local EMBER_HALO = Color3.fromRGB(122, 74, 208)
local WHITE = Color3.new(1, 1, 1)
local FLAT_EMISSION, FLAT_BRIGHTNESS = 0.35, 0.7
local NSTR = 3                     -- strands
local DEPTHS = { 0, -1, 1 }        -- x DepthStep along the view ray (negative: toward the camera)
local CLASSES = { 1, 2, 4, 8, 12, 16, 24, 32, 48, 64 }
local POOL_CAP = 32
local RUNNER = "SpellshotRailspikeFX"

----------------------------------------------------------------------------------------------------
-- plumbing: lazy requires (nothing at load)
----------------------------------------------------------------------------------------------------
local Kit, COL, SOFT, LOOKS = nil, nil, nil, nil
local retryAt = 0
local warned = {}

local function warnOnce(key, msg)
	if Kit and Kit.warnOnce then
		Kit.warnOnce("RailspikeFX:" .. key, "[RailspikeFX] " .. msg)
		return
	end
	if warned[key] then return end
	warned[key] = true
	warn("[RailspikeFX] " .. msg)
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

-- the chain kinds: which BeamChain layer each draws (the other is unparented). STRAND draws both on the same
-- attachments -- the core on every zigzag corner and the glow on every corner with it (the showcase's gstep-2 glow).
-- HALO is a glow without caps (the ember's).
local LAYER = { core = "Core", glow = "Glow", haze = "Core", halo = "Glow", strand = "Core" }
local SPARE = { core = "Glow", glow = "Core", haze = "Glow", halo = "Core" }

local function buildLooks()
	-- a glow joint that breaks gets the showcase's soft round cap: a glow_add sprite w x 1.1 at x0.5 its Brightness
	-- (strip() -> draw()); painted per frame by paintCaps
	local capped = { BreakWidth = 0.85, Caps = true, CapTexture = SOFT, CapScale = 1.1, CapBright = 0.5 }
	local glow, strand = table.clone(capped), table.clone(capped)
	glow.Name, strand.Name = "RailspikeGlow", "RailspikeStrand"
	LOOKS = {
		core = { BreakWidth = 0.85, Caps = false, Name = "RailspikeCore" },
		glow = glow,
		strand = strand,
		halo = { BreakWidth = 0.85, Caps = false, Name = "RailspikeHalo" },
		haze = { Break = 0, Caps = false, CoreZ = -0.01, Name = "RailspikeHaze" },
	}
end

--- Loads VoltaicKit (required) and VoltaicTuning (optional) once. False while the kit is missing.
local function libs()
	if Kit then return true end
	if os.clock() < retryAt then return false end
	local k = requireIce("VoltaicKit", 3)
	if not (k and k.BeamChain and k.host and k.light and k.jag and k.Tex and k.muzzle and k.fxFolder) then
		retryAt = os.clock() + 5
		warnOnce("kit", "IceMagic.VoltaicKit is missing or failed to load: Railspike draws nothing until it is back")
		return false
	end
	Kit, COL = k, k.COL
	SOFT = SOFT_TEX or k.Tex.Implosion
	pcall(k.libs)                          -- warm the kit's own lazy requires here, where a timed wait may yield
	local tuning = requireIce("VoltaicTuning", 2)
	local r = type(tuning) == "table" and tuning.Railspike or nil
	if type(r) == "table" then
		for _, key in ipairs({ "ChargeTime", "Hold", "GiveUp" }) do
			if type(r[key]) == "number" and r[key] > 0 then T[key] = r[key] end
		end
	else
		warnOnce("tuning", "IceMagic.VoltaicTuning.Railspike is missing: using ChargeTime 0.55, Hold 0.40, GiveUp 1.0")
	end
	buildLooks()
	return true
end

-- The kit's settings reads, never allowed to break a frame
local function kitFlag(fn, ...)
	if not fn then return false end
	local ok, v = pcall(fn, ...)
	return ok and v == true
end

local function liveScale()
	local ok, s = pcall(Kit.timeScale)
	return math.max(0.01, (ok and type(s) == "number") and s or 1)
end

local function serverNow()
	local ok, t = pcall(Kit.serverNow)
	return (ok and type(t) == "number") and t or workspace:GetServerTimeNow()
end

----------------------------------------------------------------------------------------------------
-- small maths
----------------------------------------------------------------------------------------------------
local function lerp(a, b, u) return a + (b - a) * u end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end       -- the showcase's ease()
local function easeInQuad(u) u = clamp01(u) return u * u end
local function easeOutQuad(u) u = clamp01(u) return 1 - (1 - u) * (1 - u) end
local function easeOutCubic(u) u = clamp01(u) return 1 - (1 - u) ^ 3 end
local function sineOut(u) return math.sin(clamp01(u) * math.pi / 2) end

local function span(t, a, b)
	if b > a then return clamp01((t - a) / (b - a)) end
	return t >= b and 1 or 0
end

local function safeUnit(v, fallback)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return fallback
end

local function perpAny(a)
	local p = a:Cross(Vector3.yAxis)
	if p.Magnitude < 1e-4 then p = a:Cross(Vector3.xAxis) end
	if p.Magnitude < 1e-6 then return Vector3.xAxis end
	return p.Unit
end

--- A standard normal draw (Box-Muller).
local function gauss(rng)
	local u1 = math.max(1e-9, rng:NextNumber())
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * rng:NextNumber())
end

--- A seed from any integers (the showcase's string-keyed Randoms, as one number).
local function mix(...)
	local h = 5381
	for i = 1, select("#", ...) do
		local v = math.floor(tonumber((select(i, ...))) or 0)
		h = (h * 33 + v + 7919) % 2147483629
	end
	return h
end

local function seedFrom(t, model)
	local s = math.floor((tonumber(t) or os.clock()) * 1000) % 1000000
	if typeof(model) == "Instance" then
		local name = model.Name
		for i = 1, math.min(#name, 24) do s = (s * 31 + string.byte(name, i)) % 1000003 end
	end
	return s + 1
end

local function shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function arclen(pts)
	local acc = table.create(#pts)
	acc[1] = 0
	for i = 2, #pts do acc[i] = acc[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	return acc
end

--- The polyline between arc lengths s0 < s1, its ends interpolated.
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

--- Width per point: `taper` of it lost down the run, `tip` of it at both free ends.
local function endsProfile(n, w, taper, tip)
	local out = table.create(n)
	for i = 1, n do
		local u = n > 1 and (i - 1) / (n - 1) or 0
		out[i] = (i == 1 or i == n) and w * tip or w * (1 - taper * u)
	end
	return out
end

--- The glow's attachments: every gstep-th point, and the last.
local function thinIdx(n, gstep)
	local idx = {}
	for i = 1, n, gstep do idx[#idx + 1] = i end
	if (n - 1) % gstep ~= 0 then idx[#idx + 1] = n end
	return idx
end

--- A direction within `spread` degrees of `axis` (the showcase's cone_dir).
local function coneDir(axis, spread, r)
	local ct = 1 - r:NextNumber() * (1 - math.cos(math.rad(spread)))
	local st = math.sqrt(math.max(0, 1 - ct * ct))
	local ph = r:NextNumber(0, 2 * math.pi)
	local a = safeUnit(axis, Vector3.yAxis)
	local b = perpAny(a)
	local c = a:Cross(b)
	return safeUnit(a * ct + b * (st * math.cos(ph)) + c * (st * math.sin(ph)), a)
end

--- 0 at `ramp[1]` studs from the lens, 1 past `ramp[2]`.
local function lensK(p, camPos, ramp)
	return clamp01(((p - camPos).Magnitude - ramp[1]) / (ramp[2] - ramp[1]))
end

--- A polyline's lens factor: by its nearest point to the lens (OverchargeFX's lensFade).
local function lensFade(pts, camPos, ramp)
	local dmin = math.huge
	for i = 1, #pts - 1 do
		local p, ab = pts[i], pts[i + 1] - pts[i]
		local l2 = ab:Dot(ab)
		local u = l2 > 1e-9 and clamp01((camPos - p):Dot(ab) / l2) or 0
		dmin = math.min(dmin, (p + ab * u - camPos).Magnitude)
	end
	if #pts == 1 then dmin = (pts[1] - camPos).Magnitude end
	return clamp01((dmin - ramp[1]) / (ramp[2] - ramp[1]))
end

local function rootOf(model)
	if typeof(model) ~= "Instance" then return nil end
	local r = model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then return r end
	return model:IsA("Model") and model.PrimaryPart or nil
end

local function alive(character)
	if typeof(character) ~= "Instance" or not character.Parent then return false end
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum == nil or hum.Health > 0
end

local function firstPersonNow()
	local lp = Players.LocalPlayer
	if lp and lp.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
	return kitFlag(Kit.viewmodelUp)
end

--- The hand: VoltaicKit.muzzle (the Viewmodel's muzzle for the local caster in first person, else the body's grip), or
--- a spot ahead of the root if that fails, or nil. The kit's own last resort -- no grip and no Head, e.g. a character
--- Destroyed under a windup -- is THIS viewer's camera; that is never a hand (it drew the windup on the lens).
local function muzzleOf(character, side)
	local ok, m = pcall(Kit.muzzle, character, side)
	if ok and typeof(m) == "Vector3" then
		local cam = workspace.CurrentCamera
		if not (cam and (m - cam.CFrame.Position).Magnitude < 1e-3) then return m end
	end
	local root = rootOf(character)
	return root and root.CFrame:PointToWorldSpace(Vector3.new(side == "L" and -1 or 1, 0.4, -1.2)) or nil
end

--- Where the windup points: the camera's aim for the local caster's FIRST-PERSON arms (they follow the camera), and the
--- body's LEVEL facing wherever the arms are the body's -- everyone else's, and the caster's own in the third-person
--- view (CastPose poses the arms level at the shoulders; a third-person camera's pitch drove the surge into the ground).
local function aimOf(character, own, fp)
	local cam = workspace.CurrentCamera
	if own and fp and cam then return cam.CFrame.LookVector end
	local root = rootOf(character)
	if root then
		local f = root.CFrame.LookVector
		local flat = Vector3.new(f.X, 0, f.Z)
		if flat.Magnitude > 1e-3 then return flat.Unit end
		return f
	end
	local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local flat = Vector3.new(look.X, 0, look.Z)
	return flat.Magnitude > 1e-3 and flat.Unit or look
end

--- Both hands -- the surge leaves both (the owner's note, 2026-09-28): { R = , L = } (one may be missing) and the point
--- between them, or the one hand there is. Two "hands" further apart than MaxHandGap are no pose (a ragdoll, a
--- streaming hitch): the right one alone then.
local function bothHands(character)
	local R, L = muzzleOf(character, "R"), muzzleOf(character, "L")
	if R and L and (R - L).Magnitude <= T.MaxHandGap then return { R = R, L = L }, (R + L) * 0.5 end
	local one = R or L
	if not one then return nil, nil end
	return { [R and "R" or "L"] = one }, one
end

--- The showcase's hand frame: X the aim, Z up (square to it), Y = Z x X -- the caster's side for the right hand
--- (mirrored for the left).
local function handFrame(aim, sign)
	local X = safeUnit(aim, Vector3.new(0, 0, -1))
	local up = Vector3.yAxis - X * X.Y
	if up.Magnitude < 1e-3 then up = Vector3.zAxis - X * X.Z end
	local Z = up.Unit
	return X, Z:Cross(X) * sign, Z
end

--- v2's awayPerp: the camera-to-`at` direction with its `c` component removed, unit. As the line runs into the lens
--- (the caster looking down their own shot) that vanishes, so the camera's down axis is blended in below 0.35 studs of
--- offset: the frame keeps a steady facing instead of spinning on noise.
local function awayPerp(at, c, camCF)
	local away = at - camCF.Position
	local p = away - c * away:Dot(c)
	local m = p.Magnitude
	if m < 0.35 then
		local down = -camCF.UpVector
		local q = down - c * down:Dot(c)
		if q.Magnitude < 1e-3 then
			local r = camCF.RightVector
			q = r - c * r:Dot(c)
		end
		if q.Magnitude > 1e-3 then p += q.Unit * (0.35 - m) end
		m = p.Magnitude
	end
	if m < 1e-4 then return perpAny(c) end
	return p / m
end

----------------------------------------------------------------------------------------------------
-- the pools: BeamChains by kind and size. An idle chain is parented to nil.
----------------------------------------------------------------------------------------------------
local chainPool = {}    -- [kind] = { [class] = { entry } }

local function classFor(nseg)
	for _, c in ipairs(CLASSES) do
		if nseg <= c then return c end
	end
	return CLASSES[#CLASSES]
end

local function dropEntry(e)
	pcall(function()
		e.chain:Destroy()
		e.folder:Destroy()
	end)
end

--- A BeamChain of `kind` and `cls` segments under `parent`. A chain made on a flat-lit map carries that map's tone-down,
--- so an idle chain from the other kind of map is not reused. The layer the kind does not draw is unparented.
local function takeChain(kind, cls, parent, flat)
	local byKind = chainPool[kind]
	local list = byKind and byKind[cls]
	while list and #list > 0 do
		local e = table.remove(list)
		if e.flat == flat and pcall(function() e.folder.Parent = parent end) and e.folder.Parent == parent then
			return e
		end
		dropEntry(e)
	end
	local folder = Instance.new("Folder")
	folder.Name = "RailspikeBeams"
	folder.Parent = parent
	local chain = Kit.BeamChain.new(folder, cls, LOOKS[kind])
	local spare = SPARE[kind]
	if spare then
		for _, b in ipairs(chain[spare]) do b.Parent = nil end
	end
	return { kind = kind, cls = cls, folder = folder, chain = chain, flat = flat, beams = chain[LAYER[kind]], cache = {},
		glows = chain.Glow, gcache = {} }
end

local function giveChain(e)
	local ok = pcall(function()
		e.chain:Hide()
		e.folder.Parent = nil
	end)
	local byKind = chainPool[e.kind]
	if not byKind then
		byKind = {}
		chainPool[e.kind] = byKind
	end
	local list = byKind[e.cls]
	if not list then
		list = {}
		byKind[e.cls] = list
	end
	if ok and #list < POOL_CAP then list[#list + 1] = e else dropEntry(e) end
end

----------------------------------------------------------------------------------------------------
-- painting: the showcase's per-point k / wh / hot, folded into each Beam's sequences and Brightness
----------------------------------------------------------------------------------------------------
local function sameList(old, new)
	if old == nil or #old ~= #new then return false end
	for i = 1, #new do
		if math.abs(old[i] - new[i]) > 0.004 then return false end
	end
	return true
end

local function cacheOf(e, i)
	local c = e.cache[i]
	if not c then
		c = {}
		e.cache[i] = c
	end
	return c
end

--- One Beam's look. `ak` = { t, alpha, t, alpha, ... } (times 0 .. 1) -> Transparency 1 - alpha; `wk` = { t, whiteness,
--- ... } toward white on `col` (nil: `col` flat); Brightness `br`. Written only where it changed; the lists are kept
--- (never mutate one after passing it).
local function paintBeam(b, c, ak, col, wk, br)
	if not b then return end
	if not sameList(c.a, ak) then
		local kp = {}
		for i = 1, #ak, 2 do kp[#kp + 1] = NumberSequenceKeypoint.new(ak[i], 1 - clamp01(ak[i + 1])) end
		b.Transparency = NumberSequence.new(kp)
		c.a = ak
	end
	if wk then
		if c.col ~= col or not sameList(c.w, wk) then
			local kp = {}
			for i = 1, #wk, 2 do kp[#kp + 1] = ColorSequenceKeypoint.new(wk[i], col:Lerp(WHITE, clamp01(wk[i + 1]))) end
			b.Color = ColorSequence.new(kp)
			c.col, c.w = col, wk
		end
	elseif c.col ~= col or c.w ~= nil then
		b.Color = ColorSequence.new(col)
		c.col, c.w = col, nil
	end
	br = math.max(0, br)
	if c.br == nil or math.abs(c.br - br) > 0.005 then
		b.Brightness = br
		c.br = br
	end
end

--- Every segment of chain entry `e` at one colour, opacity and Brightness.
local function paintFlat(e, nseg, col, alpha, br)
	local a = clamp01(alpha)
	local ak = { 0, a, 1, a }
	local bk = br * e.chain.BrK
	for i = 1, nseg do paintBeam(e.beams[i], cacheOf(e, i), ak, col, nil, bk) end
end

--- A strand entry's glow Beam i's paint cache.
local function glowCacheOf(e, i)
	local c = e.gcache[i]
	if not c then
		c = {}
		e.gcache[i] = c
	end
	return c
end

--- The soft round caps BeamChain:Set laid over this chain's broken glow joints this frame, painted like the glow they
--- close: opacity `ga` (a number, or a list per point), `br` the glow's Brightness (x the look's CapBright). The chain
--- is painted per Beam (never through Look), so its caps would otherwise keep Look's default opacity through every fade
--- and lens fade. Walks the kit's own break list in its own order (Set: j = 2 .. N-1, broken, glow width > CapMin).
local function paintCaps(e, gw, ga, br)
	local ch = e.chain
	local shown = ch.CapsShown or 0
	if shown == 0 or type(ch.Brk) ~= "table" or type(ch.CapPool) ~= "table" then return end
	local capMin = tonumber(ch.L.CapMin) or 0.05
	local capB = math.max(0, br) * (tonumber(ch.L.CapBright) or 0.5)
	local k = 0
	for j = 2, (ch.N or 0) - 1 do
		if k >= shown then return end
		if ch.Brk[j] then
			local w = type(gw) == "table" and (tonumber(gw[j]) or tonumber(gw[#gw]) or 0) or gw
			if w > capMin then
				k += 1
				local cap = ch.CapPool[k]
				local b = cap and cap.Beam
				if b then
					local a = clamp01(type(ga) == "table" and (ga[j] or 0) or ga)
					if cap.rsA == nil or math.abs(cap.rsA - a) > 0.004 then
						b.Transparency = NumberSequence.new(1 - a)
						cap.rsA = a
					end
					if cap.rsB == nil or math.abs(cap.rsB - capB) > 0.005 then
						b.Brightness = capB
						cap.rsB = capB
					end
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE CANVAS: what a windup and a strike share -- groups of pooled chains reused frame to frame, keyed particles,
-- surface glows and named lights
----------------------------------------------------------------------------------------------------
local Canvas = {}
Canvas.__index = Canvas

local NO_OPTS = {}
local GLOWCHAIN = { glowChain = true }
local CORE_ONLY = { coreOnly = true }

function Canvas:initCanvas(name, character, at)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Kit.fxFolder()
	self.folder = folder
	self.host = Kit.host(name .. "Host", CFrame.new(typeof(at) == "Vector3" and at or Vector3.zero))
	self.host.Parent = folder
	self.groups, self.lights, self.parts, self.flats = {}, {}, {}, {}
	self.drawN, self.dead = 0, false
	self.calm = kitFlag(Kit.reduceFlashing)
	self.kb = self.calm and T.CalmBeam or 1
	self.flat = kitFlag(Kit.flatLit)
	self.glowK = kitFlag(Kit.daylight) and T.DayGlow or 1
	self.thin = kitFlag(Kit.thin, character)
	self.own = character ~= nil and kitFlag(Kit.isOwn, character)
	self.ts = liveScale()
	-- particle counts: Graphics Quality's density, and half for somebody else's cast under Reduce Enemy VFX
	local ok, _, _, S = pcall(Kit.libs)
	local density, thinEnemy = 1, false
	if ok and type(S) == "table" then
		density = tonumber(S.EffectDensity) or 1
		thinEnemy = S.ThinEnemyVFX == true
	end
	-- (2026-10-19, audit P5F-06) an ENEMY's cast: a teammate's is not halved
	self.pk = math.clamp(density, 0, 1) * ((thinEnemy and not self.own and (character == nil or kitFlag(Kit.isEnemy, character))) and 0.5 or 1)
end

function Canvas:group(name)
	local g = self.groups[name]
	if not g then
		g = { used = 0, e = {} }
		self.groups[name] = g
	end
	return g
end

function Canvas:beginFrame(ctx)
	self.drawN += 1
	self.ctx = ctx
	for _, g in pairs(self.groups) do g.used = 0 end
end

--- Hides what this frame did not draw (kept for the next): chains, particles, surface glows, lights.
function Canvas:endFrame()
	for _, g in pairs(self.groups) do
		for i = g.used + 1, #g.e do g.e[i].chain:Hide() end
	end
	for _, L in pairs(self.lights) do
		if L.light and L.frame ~= self.drawN and L.light.Brightness ~= 0 then L.light.Brightness = 0 end
	end
	for _, P in pairs(self.parts) do
		if P.live and P.frame ~= self.drawN then
			P.pe:Clear()
			P.live = false
		end
	end
	for _, S in pairs(self.flats) do
		if S.frame ~= self.drawN and S.gui.Enabled then S.gui.Enabled = false end
	end
end

--- The group's next chain slot, of `kind` and big enough for `nseg` segments (last frame's, when it matches).
function Canvas:take(g, kind, nseg)
	local cls = classFor(nseg)
	g.used += 1
	local e = g.e[g.used]
	if e and e.kind == kind and e.cls == cls then return e end
	if e then giveChain(e) end
	e = takeChain(kind, cls, self.folder, self.flat)
	g.e[g.used] = e
	return e
end

--- A chain of `kind` laid on `pts` with per-point `widths` (a number or a list) on the layer the kind draws.
function Canvas:chain(g, kind, pts, widths)
	local e = self:take(g, kind, #pts - 1)
	if LAYER[kind] == "Core" then
		e.chain:Set(pts, widths, 0)
	else
		e.chain:Set(pts, 0, widths)
	end
	return e
end

--- A small jagged arc, the showcase's beam() at the port's economy: a CORE chain on every point (cw: a number, tapered
--- to 0 at both free ends; or a list per point) and ONE straight GLOW Beam from its first point to its last, soft at
--- both ends and pushed out 35 % of its width (o.glowChain: the showcase's glow chain on every 2nd point instead;
--- o.coreOnly: none). Colours flat per layer; `a` the opacity; Brightness as given (x the canvas's calm factor by the
--- caller).
function Canvas:bolt(g, pts, cw, gw, cc, cb, gc, gb, a, o)
	local n = #pts
	if n < 2 or a <= 0.003 then return end
	o = o or NO_OPTS
	local cwl = type(cw) == "table" and cw or endsProfile(n, cw, 0.45, 0)
	local hasGlow = not o.coreOnly and gw ~= nil and (type(gw) == "table" or gw > 0)
	if hasGlow and o.glowChain then
		local gstep = n <= 4 and 1 or 2
		local idx = thinIdx(n, gstep)
		local m = #idx
		local gwl = type(gw) == "table" and gw or endsProfile(n, gw, 0.35, 0)
		local gp, base = table.create(m), table.create(m)
		for j = 1, m do
			gp[j] = pts[idx[j]]
			base[j] = gwl[idx[j]] or 0
		end
		local w0 = math.max(m > 2 and base[2] or base[1], 1e-3)
		local w1 = math.max(m > 2 and base[m - 1] or base[m], 1e-3)
		local e0, e1 = gp[1] - gp[2], gp[m] - gp[m - 1]
		if e0.Magnitude > 1e-6 then gp[1] = gp[1] + e0.Unit * (0.35 * w0) end
		if e1.Magnitude > 1e-6 then gp[m] = gp[m] + e1.Unit * (0.35 * w1) end
		local widths
		if m == 2 then
			local mx = 0
			for i = 1, n do mx = math.max(mx, gwl[i] or 0) end
			gp = { gp[1], (gp[1] + gp[2]) / 2, gp[2] }
			widths = { 0, mx, 0 }
		else
			widths = table.create(m)
			for j = 1, m do widths[j] = (j == 1 or j == m) and 0 or base[j] end
		end
		local ge = self:chain(g, "glow", gp, widths)
		paintFlat(ge, #gp - 1, gc, a * GLOW_ALPHA, gb * self.glowK)
		paintCaps(ge, widths, a * GLOW_ALPHA, gb * self.glowK * ge.chain.BrK)
	elseif hasGlow then
		local w = gw
		if type(gw) == "table" then
			w = 0
			for _, v in ipairs(gw) do w = math.max(w, v) end
		end
		local d = pts[n] - pts[1]
		if w > 1e-3 and d.Magnitude > 1e-4 then
			local u = d.Unit
			local ge = self:chain(g, "glow", { pts[1] - u * (0.35 * w), pts[n] + u * (0.35 * w) }, w)
			local ga = clamp01(a * GLOW_ALPHA)
			paintBeam(ge.beams[1], cacheOf(ge, 1), { 0, 0, 0.3, ga, 0.7, ga, 1, 0 }, gc, nil,
				gb * self.glowK * ge.chain.BrK)
		end
	end
	local ce = self:chain(g, "core", pts, cwl)
	paintFlat(ce, n - 1, cc, a, cb)
end

--- A keyed billboard particle -- a star half or a soft glow -- at `pos`: Size `size` (half its quad), rolled `roll`
--- degrees, pushed `z` studs toward the camera (ZOffset). Re-emitted whenever its look changes; cleared by endFrame
--- when a frame does not draw it.
function Canvas:particle(key, tex, emission, pos, size, roll, col, alpha, bright, z)
	if alpha <= 0.003 or size <= 1e-3 then return end
	local P = self.parts[key]
	if not P then
		local att = Instance.new("Attachment")
		att.Name = "RailspikeSprite"
		att.Parent = self.host
		local pe = Instance.new("ParticleEmitter")
		pe.Name = key
		pe.Texture = tex
		pe.LightEmission = emission * (self.flat and FLAT_EMISSION or 1)
		pe.LightInfluence = 0
		pe.Speed = NumberRange.new(0)
		pe.RotSpeed = NumberRange.new(0)
		pe.SpreadAngle = Vector2.zero
		pe.Drag = 0
		pe.Acceleration = Vector3.zero
		pe.Lifetime = NumberRange.new(20)
		pe.Orientation = Enum.ParticleOrientation.FacingCamera
		pe.LockedToPart = false
		pe.Rate = 0
		pe.Enabled = false
		pe.Parent = att
		P = { att = att, pe = pe, live = false, frame = 0, p = nil, s = -1, r = 0, c = nil, a = -1, b = -1, z = 0 }
		self.parts[key] = P
	end
	P.frame = self.drawN
	local br = math.max(0, bright) * (self.flat and FLAT_BRIGHTNESS or 1)
	if P.live and P.p and (P.p - pos).Magnitude < 1e-3 and math.abs(P.s - size) < 1e-3 and math.abs(P.r - roll) < 0.05
		and P.c == col and math.abs(P.a - alpha) < 0.004 and math.abs(P.b - br) < 0.005 and P.z == z then
		return
	end
	local pe = P.pe
	P.att.WorldPosition = pos
	pe.Size = NumberSequence.new(size)
	pe.Transparency = NumberSequence.new(1 - clamp01(alpha))
	pe.Color = ColorSequence.new(col)
	pe.Brightness = br
	pe.ZOffset = z
	pe.Rotation = NumberRange.new(roll)
	pe:Clear()
	pe:Emit(1)
	P.live, P.p, P.s, P.r, P.c, P.a, P.b, P.z = true, pos, size, roll, col, alpha, br, z
end

--- The showcase's star(): Chain Bolt's StarGlow (Base) under StarCore (Light, 0.8 its size).
function Canvas:star(key, pos, size, roll, coreB, glowB, alpha, z, coreCol, glowCol)
	self:particle(key .. "g", Kit.Tex.StarGlow or Kit.Tex.Implosion, 0.75, pos, size, roll, glowCol or COL.Base, alpha,
		glowB, z)
	self:particle(key .. "c", Kit.Tex.StarCore or Kit.Tex.Implosion, 1, pos, size * 0.8, roll, coreCol or COL.Light,
		alpha, coreB, z + 0.05)
end

--- A soft glow laid ON a surface (showcase flag 5): a SurfaceGui on an invisible part turned to `normal`, `size` studs
--- across, alpha-blended at Brightness `bright`.
function Canvas:flatSpot(key, pos, normal, size, col, alpha, bright)
	if alpha <= 0.003 or size <= 1e-3 then return end
	local S = self.flats[key]
	if not S then
		local part = Kit.host("RailspikeSpot", CFrame.new(pos))
		part.Parent = self.folder
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Glow"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(128, 128)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Adornee = part
		gui.Parent = part
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.BorderSizePixel = 0
		img.Size = UDim2.fromScale(1, 1)
		img.Image = SOFT
		img.Parent = gui
		S = { part = part, gui = gui, img = img, frame = 0 }
		self.flats[key] = S
	end
	S.frame = self.drawN
	local n = safeUnit(normal, Vector3.yAxis)
	local up = math.abs(n.Y) > 0.95 and Vector3.zAxis or Vector3.yAxis
	S.part.Size = Vector3.new(size, size, 0.05)
	S.part.CFrame = CFrame.lookAt(pos + n * 0.04, pos + n * 2, up)      -- the Front face looks out along the normal
	if S.img.ImageColor3 ~= col then S.img.ImageColor3 = col end
	S.img.ImageTransparency = 1 - clamp01(alpha)
	S.gui.Brightness = math.max(0, bright) * (self.flat and FLAT_BRIGHTNESS or 1)
	if not S.gui.Enabled then S.gui.Enabled = true end
end

--- The named PointLight at `pos` this frame (made on first use; none on a flat-lit map; halved in daylight).
function Canvas:light(key, pos, bright, range, col)
	local L = self.lights[key]
	if not L then
		L = {}
		local att = Kit.attach(self.host, pos)
		local l = Kit.light(att, 1, range, col or COL.Light)
		if l then
			L.att, L.light, L.dayK = att, l, l.Brightness
		else
			att:Destroy()
		end
		self.lights[key] = L
	end
	L.frame = self.drawN
	local l = L.light
	if not l then return end
	L.att.WorldPosition = pos
	local v = math.max(0, bright) * L.dayK
	if math.abs(l.Brightness - v) > 1e-3 then l.Brightness = v end
	range = math.clamp(range, 0, 60)
	if math.abs(l.Range - range) > 1e-3 then l.Range = range end
	if col and l.Color ~= col then l.Color = col end
end

--- Clears everything at once. `poison`: a frame failed, so the pooled chains are destroyed, not put back.
function Canvas:Destroy(poison)
	if self.dead then return end
	self.dead = true
	self.Live = false
	if self.onDestroy then pcall(self.onDestroy, self) end
	for _, g in pairs(self.groups) do
		for _, e in ipairs(g.e) do
			if poison then dropEntry(e) else giveChain(e) end
		end
		table.clear(g.e)
	end
	pcall(function() self.folder:Destroy() end)
end

----------------------------------------------------------------------------------------------------
-- ONE runner for everything, at RenderPriority.Last (after the camera, CastPose and the Viewmodel's arms)
----------------------------------------------------------------------------------------------------
local objs = {}
local bound = false
local ctx = { cam = nil, camPos = Vector3.zero, camCF = CFrame.new() }

local function fillCtx()
	local cam = workspace.CurrentCamera
	ctx.cam = cam
	if cam then
		ctx.camCF = cam.CFrame
		ctx.camPos = ctx.camCF.Position
	end
end

local function stepOne(o)
	local ok, res = pcall(o.step, o, ctx)
	if not ok then
		warnOnce("step", "a Railspike frame failed and its effect was cleared: " .. tostring(res))
		o:Destroy(true)
		return false
	end
	return res == true
end

local function runner()
	fillCtx()
	local now = os.clock()
	for i = #objs, 1, -1 do
		local o = objs[i]
		local keep = (not o.dead) and now <= o.deadline and stepOne(o)
		if not keep then
			table.remove(objs, i)
			if not o.dead then o:Destroy() end
		end
	end
	if bound and #objs == 0 then
		bound = false
		pcall(RunService.UnbindFromRenderStep, RunService, RUNNER)
	end
end

function Canvas:start()
	if self.dead then return end
	objs[#objs + 1] = self
	if not bound then
		bound = true
		RunService:BindToRenderStep(RUNNER, Enum.RenderPriority.Last.Value, runner)
	end
	fillCtx()
	if not stepOne(self) and not self.dead then self:Destroy() end      -- drawn on this frame, not the next
end

--- A soft spark emitter (v2's preset motion, VT_Overcharge_Soft): Light for the first half of a life, then Base.
local function softSparks(parent, preset, canvas)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = preset.Name
	pe.Texture = SOFT
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COL.Light), ColorSequenceKeypoint.new(0.49, COL.Light),
		ColorSequenceKeypoint.new(0.5, COL.Base), ColorSequenceKeypoint.new(1, COL.Base),
	})
	pe.LightEmission = canvas.flat and FLAT_EMISSION or 1
	pe.LightInfluence = 0
	pe.Brightness = T.SparkBright * (canvas.flat and FLAT_BRIGHTNESS or 1)
	pe.Size = preset.Size
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = preset.Life
	pe.Speed = preset.Speed
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(0)
	pe.Drag = preset.Drag
	pe.Acceleration = preset.Acc
	pe.ZOffset = 0.3
	pe.Rate = preset.Rate or 0
	pe.Enabled = (preset.Rate or 0) > 0
	pe.TimeScale = math.clamp(canvas.ts, 0.01, 1)
	pe.Parent = parent
	return pe
end

local function sparkSize(keys)
	local kp = {}
	for _, k in ipairs(keys) do kp[#kp + 1] = NumberSequenceKeypoint.new(k[1], k[2] * T.SparkSize) end
	return NumberSequence.new(kp)
end

-- anim_railspike2.SPARKS (VoltSparks) and CRACKLE (RailspikeCrackle): v2's exact motion
local function burstPreset()
	return { Name = "RailspikeSparks", Size = sparkSize({ { 0, 0.44 }, { 1, 0.07 } }), Life = NumberRange.new(0.18, 0.30),
		Speed = NumberRange.new(26, 52), Drag = 6, Acc = Vector3.new(0, -18, 0), Rate = 0 }
end

local function cracklePreset(rate)
	return { Name = "RailspikeCrackle", Size = sparkSize({ { 0, 0.36 }, { 0.5, 0.30 }, { 1, 0.06 } }),
		Life = NumberRange.new(0.10, 0.20), Speed = NumberRange.new(6, 14), Drag = 6, Acc = Vector3.new(0, -10, 0),
		Rate = rate }
end

----------------------------------------------------------------------------------------------------
-- 1 THE WINDUP
----------------------------------------------------------------------------------------------------
local Charge = setmetatable({}, { __index = Canvas })
Charge.__index = Charge

local charges = {}       -- [character] = the windup (live or fading)

local function deadHandle(character)
	local h = { Character = character, Live = false, Stopping = false }
	function h:Stop() end
	function h:Destroy() end
	return h
end

--- Shot seconds since the press: on the server's T0 when there is one (an observer joins in step), else this client's
--- clock from the call.
function Charge:clock()
	if self.T0 then return (serverNow() - self.T0) * self.ts end
	return (os.clock() - self.c0) * self.ts
end

--- (q, lv): the press's own build 0..1 over ChargeTime, and the held level past it (clamped to MaxLevel).
function Charge:chargeAt(t)
	local q = clamp01(t / T.ChargeTime)
	local lv = clamp01((t - T.ChargeTime) / math.max(1e-3, T.FullAt - T.ChargeTime))
	return q, math.min(lv, math.clamp(T.MaxLevel, 0, 1), self.level)
end

--- The seed's white flashes: "loaded" over the last SetFlash to ChargeTime (then easing off over 0.10), and "full"
--- at FullAt when a level can reach it. Fixed times only, never the release.
function Charge:flashAt(t)
	local a = span(t, T.ChargeTime - T.SetFlash, T.ChargeTime) * (1 - span(t, T.ChargeTime, T.ChargeTime + 0.10))
	local b = 0
	if math.min(T.MaxLevel, self.level) >= 1 then b = span(t, T.FullAt - T.SetFlash, T.FullAt) end
	return math.max(a, b)
end

local BOLT_GROUPS = {}
for i = 1, 24 do BOLT_GROUPS[i] = "bolt" .. i end
local SEED_KEYS = {}
for _, side in ipairs({ "R", "L" }) do
	SEED_KEYS[side] = { vc = "seedVc" .. side, vg = "seedVg" .. side, g = "seedG" .. side, c = "seedC" .. side,
		s = "seedS" .. side }
end

--- The constant bolts, planned once on the press from this cast's RNG: each hand's fan (a bearing in it, evenly spread
--- and jittered, a tilt off level, a length, a phase) and the bridges between the hands (a bow each way), every one with
--- its strike-in time (a shuffled order over them all).
function Charge:planBolts()
	local tier = self.thin and "Thin" or (self.own and "Own" or "Other")
	local nh = math.max(0, math.floor(T.Bolts[tier] or 0))
	local nb = math.max(0, math.floor(T.Bridges[tier] or 0))
	nh = math.min(nh, math.floor((#BOLT_GROUPS - math.min(nb, #BOLT_GROUPS)) / 2))
	nb = math.min(nb, #BOLT_GROUPS - 2 * nh)
	local n = 2 * nh + nb
	local r = Random.new(self.seed * 3 + 11)
	local order = table.create(n)
	for k = 1, n do order[k] = k - 1 end
	shuffle(order, r)
	self.bolts = table.create(n)
	local k = 0
	for _, side in ipairs({ "R", "L" }) do
		for i = 1, nh do
			k += 1
			local u = nh > 1 and (i - 1 + r:NextNumber(-0.3, 0.3)) / (nh - 1) or 0.5
			self.bolts[k] = {
				side = side,
				fan = lerp(T.BoltFan[1], T.BoltFan[2], clamp01(u)),
				tilt = r:NextNumber(-1, 1) * T.BoltTilt,
				len = r:NextNumber(0.85, 1.15),
				ph = r:NextNumber(0, 2 * math.pi),
				seed = r:NextInteger(1, 1000000),
				t0 = T.BoltIn[1] + order[k] * T.BoltIn[2],
			}
		end
	end
	for i = 1, nb do
		k += 1
		self.bolts[k] = {
			bridge = true,
			bow = (i % 2 == 1) and 1 or -1,
			ph = r:NextNumber(0, 2 * math.pi),
			seed = r:NextInteger(1, 1000000),
			t0 = T.BoltIn[1] + order[k] * T.BoltIn[2],
		}
	end
end

local MOTE_SLOTS = 24          -- keyed sprites the motes cycle through (~11 live at a press's 42 a second)

--- plan_windup's motes, causally: every mote born up to `t` on the charge's rate (x the particle density), each on a
--- direction kept off the caster's own forearm and the eye line (the showcase's filter, the pass-1 fix), from this
--- cast's RNG.
function Charge:planMotes(t)
	if not self.Stopping then
		local guard = 0
		while self.nextMote <= t and guard < 64 do
			guard += 1
			local s = self.nextMote
			local q, lv = self:chargeAt(s)
			local r = self.moteRng
			local d = Vector3.xAxis
			for _ = 1, 30 do
				d = r:NextUnitVector()
				if d.X > -0.2 and math.abs(d.Y) < 0.92 then break end   -- never through the caster's own forearm
			end
			self.moteSlot = self.moteSlot % MOTE_SLOTS + 1
			self.motes[#self.motes + 1] = { s = s, d = d, r0 = r:NextNumber(1.0, 1.9) * (1 + 0.3 * lv),
				life = r:NextNumber(0.16, 0.26), key = "mote" .. self.moteSlot }
			local rate = T.MoteRate * (0.6 + 0.4 * q) * (1 + lv) * self.pk
			self.nextMote = rate > 1e-3 and s + r:NextNumber(0.6, 1.4) / rate or math.huge
		end
	end
	for i = #self.motes, 1, -1 do
		local m = self.motes[i]
		if t - m.s >= m.life then table.remove(self.motes, i) end
	end
end

function Charge:Stop()
	if not self.Live or self.Stopping then return end
	self.Stopping = true
	self.stopT = math.max(0, self:clock())
end

function Charge:onDestroy()
	if charges[self.character] == self then charges[self.character] = nil end
end

--- windup_frame(), this render frame, at BOTH hands (`hands.R`, `hands.L`; `cm` between them, where the threads gather
--- and the shot will leave) along `aim`; `fade` 1 -> 0 through a stop.
function Charge:draw(t, hands, cm, aim, fade, cx)
	local fno = math.floor(t * 60 + FRAME_TOL)
	local tq = fno / 60
	local q, lv = self:chargeAt(tq)
	local I = 0.35 + 0.65 * smooth(q) + T.HoldI * smooth(lv)
	local fl = self:flashAt(tq) * (self.calm and 0.5 or 1)
	local fp = self.fp
	local sc = fp and T.FpScale or 1
	local ss = fp and T.FpSeed or 1
	local X, Y, Z = handFrame(aim, 1)          -- X the aim, Z up, Y the caster's LEFT
	local camPos = cx.camPos
	local kb = self.kb

	-- the seeds, one in each palm: a violet spark warming to Light, v2's node scale and spin, drawn as a star; the white
	-- flashes
	local s = lerp(T.Node[1], T.Node[2], sineOut(q)) * (1 + T.NodeOver * smooth(lv)) * ss
	local warm = smooth(span(tq, 0.04, 0.30))
	local roll = math.deg(T.NodeSpin * tq * (1 + 0.6 * lv))
	local gs = lerp(T.SeedGlow[1], T.SeedGlow[2], smooth(q)) * (1 + 0.5 * smooth(lv)) * (1 + 0.35 * fl) * ss
	for side, c in pairs(hands) do
		local K = SEED_KEYS[side]
		local rl = side == "L" and -roll or roll
		if warm < 1 then
			self:particle(K.vc, Kit.Tex.StarCore or Kit.Tex.Implosion, 1, c, s * 0.9, rl, COL.Dark, (1 - warm) * fade,
				3.0 * kb, 0.3 * ss)
			self:particle(K.vg, Kit.Tex.StarGlow or Kit.Tex.Implosion, 0.75, c, s * 1.2, rl, EMBER_HALO,
				(1 - warm) * fade, 1.4 * kb, 0.28 * ss)
		end
		if warm > 0 then
			self:particle(K.g, Kit.Tex.StarGlow or Kit.Tex.Implosion, 0.75, c, s * 1.1, rl, COL.Base, warm * fade,
				1.1 * I * kb, 0.3 * ss)
			self:particle(K.c, Kit.Tex.StarCore or Kit.Tex.Implosion, 1, c, s * 0.9, rl, COL.Light:Lerp(WHITE, 0.7 * fl),
				warm * fade, 1.4 * I * (1 + 0.6 * fl) * kb, 0.35 * ss)
		end
		self:particle(K.s, SOFT, 1, c, gs, 0, COL.Dark:Lerp(COL.Base, warm), fade, T.SeedGlow[3] * I * kb, 0.35 * ss)
	end

	-- THE SURGE (the owner): CONSTANT bolts, SPREAD OUT HORIZONTALLY. From each hand a flat fan runs out along the aim
	-- (BoltFan degrees about the vertical, inward .. outward; BoltTilt above / below level), and bridges crackle from hand
	-- to hand, bowed out along the aim. Each from its strike-in (struck out of the hand) to the shot, re-jagged every
	-- tick (every CalmEvery under Reduce Flashing), reaching further as the charge builds, sweeping a little in its fan,
	-- its length breathing. Each keeps its own Beams (a group of its own). A fork, re-rolled every tick, on some.
	local cw, gw, cb, gb = T.Arc[1], T.Arc[2], T.Arc[3], T.Arc[4]
	local kk = 1 + T.ArcOver * lv
	local tick = math.floor(tq * T.Tick + FRAME_TOL)
	local rk = self.calm and math.floor(tick / T.CalmEvery) or tick
	local BL = fp and T.BoltFpLen or T.BoltLen
	local Lb = lerp(BL[1], BL[2], smooth(q)) * (1 + T.BoltLenOver * smooth(lv))
	local depth = (self.own and not self.thin) and T.BoltDepth[1] or T.BoltDepth[2]
	local warmB = 0.8 + 0.2 * smooth(q)
	local ccol = COL.Light:Lerp(WHITE, 0.5 * fl)
	local gF = self:group("boltForks")
	local hR, hL = hands.R, hands.L
	local gap = (hR and hL) and (hR - hL).Magnitude or 0
	for k, B in ipairs(self.bolts) do
		local g = self:group(BOLT_GROUPS[k])
		local u = span(tq, B.t0, B.t0 + T.BoltIn[3])
		local pts, dl, len
		local br = Random.new(mix(B.seed, rk))
		if u <= 0 then
			pts = nil
		elseif B.bridge then
			if gap > 0.2 then
				local bw = math.sin(2 * math.pi * 1.1 * tq + B.ph)
				local mid = (hL + hR) * 0.5 + X * (T.BridgeBow[1] * gap * (1 + 0.25 * bw))
					+ Z * (T.BridgeBow[2] * gap * B.bow * (1 + 0.3 * bw))
				local amp = T.BridgeJag * gap
				pts = Kit.jag(hL, mid, math.max(1, depth - 1), amp * 0.5, br, 0.6)
				local rest = Kit.jag(mid, hR, math.max(1, depth - 1), amp * 0.5, br, 0.6)
				for i = 2, #rest do pts[#pts + 1] = rest[i] end
				dl, len = safeUnit(hR - hL, Y), gap
			end
		else
			local c = hands[B.side]
			if c then
				local out = B.side == "L" and Y or -Y                 -- away from the other hand
				local th = math.rad(B.fan + T.BoltSweep[1] * math.sin(2 * math.pi * T.BoltSweep[2] * tq + B.ph))
				local ph = math.rad(B.tilt + T.BoltSway[1] * math.sin(2 * math.pi * T.BoltSway[2] * tq + 2.3 * B.ph))
				dl = (X * math.cos(th) + out * math.sin(th)) * math.cos(ph) + Z * math.sin(ph)
				len = Lb * B.len * (1 + T.BoltBreath[1] * math.sin(2 * math.pi * T.BoltBreath[2] * tq + 1.7 * B.ph))
				pts = Kit.jag(c, c + dl * len, depth, T.BoltJag * len, br, 0.6)
			end
		end
		if pts then
			local shown = pts
			if u < 1 then
				local acc = arclen(pts)
				shown = cutPath(pts, acc, 0, acc[#acc] * u)
			end
			local a = fade
			if fp and #shown >= 2 then a *= lensFade(shown, camPos, T.FpWindupLens) end
			local flick = self.calm and 1 or lerp(T.BoltFlicker[1], T.BoltFlicker[2], br:NextNumber())
			if a > 0.01 and #shown >= 2 then
				self:bolt(g, shown, cw * (1 + 0.3 * lv) * sc, gw * sc, ccol, cb * warmB * flick * (1 + 0.5 * fl) * kk * kb,
					COL.Base, gb * warmB * kk * kb, a, GLOWCHAIN)
			end
			if u >= 1 and not self.thin and a > 0.01 and #pts >= 4 and br:NextNumber() < T.ArcFork then
				-- a fork off the bolt, mostly level (the surge's plane), a little above or below
				local fb = pts[br:NextInteger(2, #pts - 2)]
				local hs = safeUnit(Z:Cross(dl), Y) * (br:NextNumber() < 0.5 and -1 or 1)
				local fd = safeUnit(hs * 0.6 + dl * 0.6 + Z * br:NextNumber(-0.25, 0.25), dl)
				local fl2 = T.BoltFork * len
				self:bolt(gF, Kit.jag(fb, fb + fd * fl2, 1, 0.3 * fl2, br), cw * 0.7 * sc, nil, COL.Light,
					cb * 0.8 * warmB * kk * kb, nil, 0, a, CORE_ONLY)
			end
		end
	end
	local c = cm                                   -- the threads, the motes and the light gather between the hands

	-- three threads spiralling into the charge point, a bright band RUNNING DOWN each into it (the inflow)
	local twc, twg, tbc, tbg = T.Thread[1], T.Thread[2], T.Thread[3], T.Thread[4]
	local Rr = lerp(T.ThreadR[1], T.ThreadR[2], smooth(q)) * (1 + 0.25 * smooth(lv)) * sc
	local ahead = lerp(T.ThreadAhead[1], T.ThreadAhead[2], smooth(q)) * sc
	local thk = (0.45 + 0.55 * smooth(q)) * (1 + T.ThreadOver * smooth(lv))
	local ta = smooth(span(tq, 0.03, 0.14)) * fade          -- faded in by ALPHA (a brightness ramp drew black wires)
	if ta > 0.02 then
		local gT = self:group("threads")
		local N = self.thin and T.ThinThreadPts or T.ThreadPts
		for si = 0, T.Threads - 1 do
			local ph0 = si * 2 * math.pi / T.Threads + T.ThreadSpin * (1 + 0.6 * lv) * tq
			local tr = Random.new(7000 + si * 31 + fno)
			local pts = table.create(N + 1)
			for i = 0, N do
				local u = i / N                                -- 0 at the charge point, 1 at the outer end
				local an = ph0 + 2 * math.pi * T.ThreadTurns * u
				local p = c + X * (ahead * u) + (Y * math.cos(an) + Z * math.sin(an)) * (Rr * u ^ 1.4)
				if i > 0 and i < N then p += tr:NextUnitVector() * (0.012 * sc) end
				pts[N + 1 - i] = p                             -- the outer end first: the taper runs into the point
			end
			local band = 1 - ((T.ThreadFlow * (1 + lv)) * tq + si / 3) % 1      -- 1 -> 0: outer -> in
			local function kAt(uu)                            -- uu: the thread's u (0 at the point)
				local z = uu - band
				return 0.30 + 0.70 * math.exp(-(z * z) / (2 * 0.10 * 0.10))
			end
			-- the glow on every 2nd point (its opacity the band's there)
			local idx = thinIdx(N + 1, 2)
			local m = #idx
			local gpts, gws = table.create(m), table.create(m)
			local gwv = twg * (0.7 + 0.5 * lv) * sc
			for j = 1, m do
				local i = idx[j] - 1
				gpts[j] = pts[idx[j]]
				gws[j] = (j == 1 or j == m) and 0 or gwv * (1 - 0.35 * i / N)
			end
			local e0, e1 = gpts[1] - gpts[2], gpts[m] - gpts[m - 1]
			if e0.Magnitude > 1e-6 then gpts[1] = gpts[1] + e0.Unit * (0.35 * gwv) end
			if e1.Magnitude > 1e-6 then gpts[m] = gpts[m] + e1.Unit * (0.35 * gwv) end
			local ge = self:chain(gT, "glow", gpts, gws)
			local gbr = tbg * thk * kb * self.glowK * ge.chain.BrK
			for j = 1, m - 1 do
				local u0, u1 = (N - (idx[j] - 1)) / N, (N - (idx[j + 1] - 1)) / N
				paintBeam(ge.beams[j], cacheOf(ge, j), { 0, ta * GLOW_ALPHA * kAt(u0), 1, ta * GLOW_ALPHA * kAt(u1) },
					COL.Base, nil, gbr)
			end
			paintCaps(ge, gws, ta * GLOW_ALPHA, gbr)
			-- the core, painted per run: its two points and the mid-run (the showcase's per-point k, folded)
			local cws = table.create(N + 1)
			for i = 0, N do cws[i + 1] = (i > 0 and i < N) and twc * (0.4 + 0.6 * (i / N)) * sc or 0 end
			local ce = self:chain(gT, "core", pts, cws)
			local cbr = tbc * thk * kb * ce.chain.BrK
			for i = 0, N - 1 do
				local u0, u1 = (N - i) / N, (N - i - 1) / N
				paintBeam(ce.beams[i + 1], cacheOf(ce, i + 1),
					{ 0, ta * kAt(u0), 0.5, ta * kAt((u0 + u1) / 2), 1, ta * kAt(u1) }, COL.Light,
					{ 0, 0.4 * fl * (i / N), 1, 0.4 * fl * ((i + 1) / N) }, cbr)
			end
		end
	end

	-- the motes: soft sparkles drawn in to the point from off the arm's side, slow and then accelerating (ease-in)
	self:planMotes(t)
	for _, m in ipairs(self.motes) do
		local u = (tq - m.s) / m.life
		if u >= 0 and u < 1 then
			local dd = X * m.d.X + Y * m.d.Y + Z * m.d.Z
			local p = c + dd * (lerp(m.r0, 0.1, easeInQuad(u)) * sc)
			self:particle(m.key, SOFT, 1, p, 0.09 * sc, 0, COL.Light, (1 - 0.6 * u) * fade, 2.2 * I * kb, 0.2 * sc)
		end
	end

	-- the light: one WORLD position for every viewer, ahead of the hand along the aim (none in first person)
	if not fp then
		local L0, L1, L2, rng_ = T.SeedLight[1], T.SeedLight[2], T.SeedLight[3], T.SeedLight[4]
		self:light("seed", c + X * 0.5, (lerp(L0, L1, smooth(q)) + L2 * smooth(lv)) * fade, rng_ + 3 * lv,
			COL.Dark:Lerp(COL.Base, warm))
	end

	-- the caster's one Bloom kick, at the loaded flash (the kit skips it under Reduce Flashing and in first person)
	if self.own and not self.bloomed and not self.Stopping and tq >= T.ChargeTime - T.SetFlash then
		self.bloomed = true
		pcall(Kit.bloomPulse, T.LoadedBloom[1], 0, T.LoadedBloom[2], T.SetFlash)
	end
end

function Charge:step(cx)
	if self.dead then return false end
	-- a body that is gone (Destroyed, removed) takes its windup with it at once: there is no hand left to fade on (the
	-- kit's muzzle would have fallen back to this viewer's camera)
	if typeof(self.character) ~= "Instance" or not self.character.Parent then return false end
	local t = math.max(0, self:clock())
	local fade = 1
	if self.Stopping then
		local u = (t - self.stopT) / T.StopFade
		if u >= 1 then return false end
		fade = 1 - easeInQuad(u)
	elseif t >= self.watchdog or not alive(self.character) then
		self:Stop()
		return true
	end
	if not cx.cam then return true end
	local hands, cm = bothHands(self.character)
	if not hands then return false end
	self.fp = self.own and firstPersonNow()
	self:beginFrame(cx)
	self:draw(t, hands, cm, aimOf(self.character, self.own, self.fp), fade, cx)
	self:endFrame()
	return true
end

local function chargeImpl(character, opts, box)
	local T0 = type(opts.T0) == "number" and opts.T0 or nil
	local existing = charges[character]
	if existing and existing.Live then
		if not existing.Stopping and (existing.T0 == nil or T0 == nil or math.abs(existing.T0 - T0) < 0.3) then
			return existing                      -- the same cast heard twice (own press, then own broadcast)
		end
		existing:Destroy()
	end
	local ts = liveScale()
	local watchdog = T.ChargeTime + T.GiveUp + 0.3
	if T0 and (serverNow() - T0) * ts >= watchdog then return deadHandle(character) end   -- the shot has been and gone
	local side = opts.Side == "L" and "L" or "R"
	if not bothHands(character) then return deadHandle(character) end

	local self = setmetatable({}, Charge)
	box.obj = self
	self:initCanvas("RailspikeCharge", character, nil)
	self.character, self.Character = character, character
	self.own = opts.Own == true or self.own
	self.Own = self.own
	self.side, self.sign = side, side == "L" and -1 or 1
	self.T0, self.c0, self.ts = T0, os.clock(), ts
	self.level = math.clamp(tonumber(opts.Level) or 1, 0, 1)   -- the highest level this windup may build to
	self.watchdog = watchdog
	self.Live, self.Stopping = true, false
	self.seed = seedFrom(T0 or serverNow(), character)
	self:planBolts()
	self.moteRng = Random.new(self.seed * 5 + 17)
	self.motes, self.nextMote, self.moteSlot = {}, 0, 0
	self.deadline = os.clock() + (watchdog + 1) / ts + 0.5
	Debris:AddItem(self.folder, (watchdog + 2) / ts)       -- the backstop if the runner ever stops

	charges[character] = self
	self:start()
	return self
end

----------------------------------------------------------------------------------------------------
-- 2-4 THE STRIKE
----------------------------------------------------------------------------------------------------
local Strike = setmetatable({}, { __index = Canvas })
Strike.__index = Strike

local lastOwnFire = -math.huge

function Strike:xOf(p) return (p - self.muzzle):Dot(self.dir) end
function Strike:fanU(p) return clamp01(self:xOf(p) / self.fanLen) end
function Strike:fan(p) return lerp(T.Fan[1], T.Fan[2], self:fanU(p)) end
function Strike:glowFanX(x) return lerp(T.GlowFan[1], T.GlowFan[2], clamp01(x / self.fanLen)) end

--- The bow along a leg: 0 on each knot, 1 once clear of both ramps.
local function bow(x, leg)
	local u = math.min(x / leg.rin, (leg.L - x) / leg.rout)
	return math.sin(math.pi / 2 * clamp01(u))
end

--- PORT: how much wider than the showcase's a kink gap may be at `p` for this camera. A gap's size on screen goes as
--- gap x sin / d (sin: the line's angle to the view ray). Up to JagScreen studs of d / sin -- everywhere the showcase's
--- own side and ref cameras saw their line, and anything nearer or squarer -- it is 1: the showcase's world gaps, its
--- exact density (the jag corrective's 23.4 kinks a strand on its 26-stud first leg). Further or more foreshortened (the
--- caster looking down their own shot) the gaps widen in step, so they are never denser on screen than the showcase's
--- camera saw them; at most JagGapMax x.
function Strike:screenK(p, cdir, camPos)
	local v = p - camPos
	local d = v.Magnitude
	if d < 1e-3 then return 1 end
	local sn = cdir:Cross(v / d).Magnitude
	return math.clamp(d / math.max(sn, T.JagSinMin) / T.JagScreen, 1, T.JagGapMax)
end

--- Kinks a leg would take at the showcase's mean gap and gap scale 1, for this camera.
function Strike:expectKinks(leg, camPos)
	local steps = math.max(1, math.ceil(leg.L / 2))
	local dl = leg.L / steps
	local sum = 0
	for i = 0, steps - 1 do
		local p = leg.a + leg.c * ((i + 0.5) * dl)
		sum += dl / (T.JagGap[4] * self:screenK(p, leg.c, camPos))
	end
	return sum
end

--- (width k, brightness k, ember) of strand s at shot time ts (strand_fade).
function Strike:strandFade(s, ts)
	local bt = T.Hold + T.BreakOrder[s] * T.BreakStagger
	if ts < bt then return 1, 1, false end
	local e = (ts - bt) / T.Fade
	if e < 1 then return 1 - 0.45 * smooth(e), (1 - e) ^ 1.5 * 0.9 + 0.1, false end
	if ts < bt + T.Fade + T.Ember * F then return 0.5, 0.4, true end
	return 0, 0, false
end

--- line_env: 1 through the hold, falling smoothly across the strands' staggered fades to 0 as the last ember goes.
function Strike:lineEnv(ts)
	local best = 0
	for s = 1, NSTR do
		local bt = T.Hold + T.BreakOrder[s] * T.BreakStagger
		best = math.max(best, clamp01(1 - (ts - bt) / (T.Fade + T.Ember * F)))
	end
	return best
end

--- A strand's rope on one leg this tick: v2's joints EXACTLY as anim_railspike2 lays them (lanes, bow, pinch, wander,
--- jitter, knot jitter, depth), and each chord's width scale (flicker, accent).
function Strike:joints(leg, li, s, kj, kr, accent)
	local n, L = leg.n, leg.L
	local lane = T.Lanes[s]
	local depth = leg.yv * (DEPTHS[s] * T.DepthStep)
	local joints, jx = table.create(n + 1), table.create(n + 1)
	for j = 0, n do
		local x = L * j / n
		local P = leg.a + leg.c * x
		local fk = self:fan(P)
		local off
		if j == 0 then
			off = lane * fk * leg.pa + kj[leg.qa][s]
		elseif j == n then
			off = lane * fk * leg.pb + kj[leg.qb][s]
		else
			local fl = lerp(leg.pa, leg.pb, x / L)
			off = lane * fk * (fl + (1 - fl) * leg.spread * bow(x, leg))
				+ T.Wander[s] * fk * leg.spread * self.wander[s][li][j] + T.Jitter * kr:NextNumber(-1, 1)
		end
		local p = P + leg.lat * off + depth
		joints[j + 1] = p
		jx[j + 1] = self:xOf(p)
	end
	local ws = table.create(n)
	for j = 1, n do
		local fl = self.calm and 1 or lerp(T.Flicker[1], T.Flicker[2], 0.5 + 0.5 * kr:NextNumber(-1, 1))
		ws[j] = T.LaneWidth[s] * fl * accent
	end
	local jw = table.create(n + 1)
	for j = 1, n + 1 do jw[j] = ((ws[j - 1] or ws[j]) + (ws[j] or ws[j - 1])) * 0.5 end
	return joints, ws, jx, jw
end

--- jag_rope(): the strand's own zigzag along its rope. Kinks at lognormal gaps (x the screen spacing), each thrown off
--- the chord's camera-facing lateral by a subtle or a sharp amplitude x the chord's width scale, alternating sides but
--- for the odd step, easing in near the knots, 1.3x at the end. Past `maxK` (this rope's share of the strand's budget)
--- the gaps are stretched evenly so the kinks still span the whole rope (deviation 1): never a straight tail.
function Strike:jagRope(joints, ws, camPos, rng, s, maxK, leg)
	local nseg = #joints - 1
	local acc = table.create(nseg + 1)
	acc[1] = 0
	for i = 1, nseg do acc[i + 1] = acc[i] + (joints[i + 1] - joints[i]).Magnitude end
	local Lr = acc[nseg + 1]
	local FX, FZ = table.create(nseg), table.create(nseg)
	for i = 1, nseg do
		local p0, p1 = joints[i], joints[i + 1]
		local x = safeUnit(p1 - p0, leg.c)
		local away = (p0 + p1) * 0.5 - camPos
		local y = away - x * away:Dot(x)
		y = y.Magnitude > 1e-6 and y.Unit or perpAny(x)
		FX[i], FZ[i] = x, x:Cross(y)
	end
	local lo, hi, sig, gm = T.JagGap[1], T.JagGap[2], T.JagGap[3], T.JagGap[4]
	local alo, ahi, slo, shi, share = T.JagAmp[1], T.JagAmp[2], T.JagAmp[3], T.JagAmp[4], T.JagAmp[5]
	local gk, ak = T.JagStrand[s][1], T.JagStrand[s][2]
	local unit = math.exp(-0.5 * sig * sig)                   -- the lognormal's mean back to 1
	local function gap(p)
		local g = math.min(hi, math.max(lo, gm * unit * math.exp(gauss(rng) * sig)))
		return gk * g * self:screenK(p, leg.c, camPos)
	end
	local function at(sp)
		local j = 1
		while j < nseg and acc[j + 1] < sp do j += 1 end
		return joints[j]:Lerp(joints[j + 1], (sp - acc[j]) / math.max(1e-9, acc[j + 1] - acc[j])), j
	end
	-- where the kinks fall along the rope: the showcase's gaps first, then stretched to the quota
	local ss = {}
	local sp = 0.5 * gap(joints[1])
	while sp < Lr - 0.35 and #ss < 256 do
		ss[#ss + 1] = sp
		sp += gap((at(sp)))
	end
	if #ss > maxK then
		if maxK < 1 then
			table.clear(ss)
		else
			local k = ss[#ss] / ss[maxK]
			for i = #ss, maxK + 1, -1 do ss[i] = nil end
			for i = 1, maxK do ss[i] *= k end
		end
	end
	local kinks = {}
	local side, stepped = (rng:NextNumber() < 0.5 and 1 or -1), false
	for _, spk in ipairs(ss) do
		local p, j = at(spk)
		local f
		if rng:NextNumber() < share then f = rng:NextNumber(slo, shi) else f = rng:NextNumber(alo, ahi) end
		f *= lerp(0.55, 1, smooth(math.min(spk, Lr - spk) / T.JagEnd)) * lerp(1, T.JagFan, self:fanU(p))
		if self.fp then f *= lerp(T.FpJag[3], 1, lensK(p, camPos, T.FpJag)) end     -- first person: calmer at the lens
		kinks[#kinks + 1] = { p = p + FZ[j] * (side * T.JagBase * ak * f * ws[j]), j = j, side = side }
		if stepped or rng:NextNumber() >= T.JagSame then
			side, stepped = -side, false
		else
			stepped = true
		end
	end
	local n = #kinks + 2
	local pts, corner, vw, vx = table.create(n + 1), table.create(n + 1), table.create(n + 1), table.create(n + 1)
	pts[1], corner[1], vw[1] = joints[1], false, ws[1]
	for i, K in ipairs(kinks) do pts[i + 1], corner[i + 1], vw[i + 1] = K.p, true, ws[K.j] end
	if #kinks == 0 then
		-- a leg too short for a kink: the showcase's mid-run point, so the core and glow still taper 0 -> w -> 0
		local mp, j = at(Lr * 0.5)
		pts[2], corner[2], vw[2] = mp, false, ws[j]
		n += 1
	end
	pts[n], corner[n], vw[n] = joints[nseg + 1], false, ws[nseg]
	for i = 1, n do vx[i] = self:xOf(pts[i]) end
	return { pts = pts, corner = corner, ws = vw, x = vx, nk = #kinks, kinks = kinks, FX = FX, FZ = FZ }
end

--- The dispersal's grow(): a jagged branch of `length` studs from `root` along (dx, dz) in the chord's (along, lateral)
--- plane (bolt_spine's kinks and lean), cut short at the line's end; its tip's spark, the loose ones, then its twigs
--- while the strand's twig budget and `budget.depth` allow.
function Strike:grow(st, root, dx, dz, length, w, depth, X, Z, sd, rng, budget)
	local nseg = (length < 1.0 and 2 or length < 1.8 and 3 or 4) + 1
	local lean = 0.10 + 0.07 * length
	local side = rng:NextNumber() < 0.5 and 1 or -1
	local D = X * dx + Z * dz
	local N = Z * dx - X * dz
	local stop = self.lineLen - 0.15
	local bp = {}
	for i = 0, nseg do
		local u = i / nseg
		local jog = (i == 0 or i == nseg) and 0 or side * lean * rng:NextNumber(0.62, 1.0)
		side = -side
		local q = root + D * (u * length) + N * jog
		if self:xOf(q) > stop then break end
		bp[#bp + 1] = q
	end
	if #bp < 2 then return end
	st.branches[#st.branches + 1] = { pts = bp, w = w, depth = depth, x = self:xOf(root) }
	local tip = bp[#bp]
	local head = safeUnit(bp[#bp] - bp[#bp - 1], D)
	local sparks = st.sparks
	if #sparks < T.MaxSparks then
		sparks[#sparks + 1] = { p = tip, s = lerp(T.Spark[1], T.Spark[2], (depth - 1) / 2), b = T.Spark[3] }
	end
	if budget.loose then
		local ch, most, lo, hi = T.SparkLoose[1], T.SparkLoose[2], T.SparkLoose[3], T.SparkLoose[4]
		for _ = 1, most do
			if rng:NextNumber() < ch * self:fanU(tip) then
				local p = tip + head * rng:NextNumber(lo, hi) + Z * rng:NextNumber(-0.25, 0.25)
				local s = T.Spark[2] * rng:NextNumber(0.6, 1.0)
				if #sparks < T.MaxSparks then sparks[#sparks + 1] = { p = p, s = s, b = T.Spark[3] * 1.1 } end
			end
		end
	end
	if depth >= budget.depth then return end
	local su, sp, sl = T.BranchSub[1], T.BranchSub[2], T.BranchSub[3]
	for i = 2, #bp - 1 do
		if budget.twigs <= 0 then return end
		local u = self:fanU(bp[i])
		if u >= su and rng:NextNumber() < sp * (u - su) / (1 - su) then
			budget.twigs -= 1
			local a = math.rad(rng:NextNumber(T.BranchTurn[1], T.BranchTurn[2])) * (rng:NextNumber() < 0.75 and sd or -sd)
			self:grow(st, bp[i], dx * math.cos(a) - dz * math.sin(a), dx * math.sin(a) + dz * math.cos(a),
				length * sl * rng:NextNumber(0.7, 1.2), w, depth + 1, X, Z, sd, rng, budget)
		end
	end
end

--- strike_layout() for runtime frame `rk` (a re-roll: every tick, every CalmEvery under Reduce Flashing): every
--- strand's ropes, zigzags and dispersal, laid for this camera. The strand's kink budget is shared out over its legs.
function Strike:build(k, rk, cx)
	local camPos = cx.camPos
	local kr = Random.new(mix(self.seed, rk, 1))
	local accent = (not self.calm and k < T.AccentTicks) and T.AccentWidth or 1
	local kj = table.create(#self.way)
	for w = 1, #self.way do
		local row = table.create(NSTR)
		for s = 1, NSTR do row[s] = T.KnotJitter * kr:NextNumber(-1, 1) end
		kj[w] = row
	end
	for _, leg in ipairs(self.legs) do
		local yv = awayPerp(leg.mid, leg.c, cx.camCF)
		leg.yv, leg.lat = yv, leg.c:Cross(yv)
		leg.expect = self:expectKinks(leg, camPos)
	end
	local nLegs = #self.legs
	local geo = {}
	-- the dispersal: a random pick of the kinks that roll a branch (the showcase's own rule, so the pick keeps its
	-- distribution -- rare at the hand, most toward the end). Thin: the showcase's thin tier (depth-1 branches as a core
	-- and their tip sparks). First person: none rooted within FpGlowLens[2] of the lens, where the line itself is thinned
	-- and faded (OverchargeFX's rule: forks fill the lens); the roll is still drawn, so the stream is unchanged.
	local maxB = self.thin and T.ThinBranches or T.MaxBranches
	local gate = self.fp and T.FpGlowLens[2] or 0
	for s = 1, NSTR do
		local gk = T.JagStrand[s][1]
		local expect = 0
		for _, leg in ipairs(self.legs) do expect += leg.expect / gk end
		local avail = math.max(1, self.segCap - nLegs)
		local st = { ropes = {}, branches = {}, sparks = {} }
		local cands = {}
		for li, leg in ipairs(self.legs) do
			local joints, ws = self:joints(leg, li, s, kj, kr, accent)
			local rng = Random.new(mix(self.seed, rk, s, li, 7))
			-- this leg's share of the strand's kink budget, by its expected kinks
			local maxK = math.max(1, math.floor(avail * (leg.expect / gk) / math.max(1e-6, expect) + 0.5))
			local R = self:jagRope(joints, ws, camPos, rng, s, maxK, leg)
			R.cws = ws
			st.ropes[li] = R
			-- the dispersal's candidates: interior kinks that roll a branch (rare at the hand, most at the end)
			if maxB > 0 then
				local b0, b1, bpow = T.Branch[1], T.Branch[2], T.Branch[3]
				for i = 2, #R.kinks - 1 do
					local K = R.kinks[i]
					local u = self:fanU(K.p)
					local roll = rng:NextNumber()
					if roll < lerp(b0, b1, u ^ bpow) and (gate <= 0 or (K.p - camPos).Magnitude >= gate) then
						cands[#cands + 1] = { R = R, K = K, u = u }
					end
				end
			end
		end
		if #cands > 0 then
			local brng = Random.new(mix(self.seed, rk, s, 91))
			shuffle(cands, brng)
			local budget = self.thin and { twigs = 0, depth = 1, loose = false }
				or { twigs = T.MaxTwigs, depth = T.BranchDepth, loose = true }
			for i = 1, math.min(#cands, maxB) do
				local C = cands[i]
				local a = math.rad(brng:NextNumber(T.BranchRake[1], T.BranchRake[2]))
				local len = lerp(T.BranchLen[1], T.BranchLen[2], C.u) * brng:NextNumber(0.7, 1.3)
				self:grow(st, C.K.p, math.cos(a), C.K.side * math.sin(a), len, C.R.cws[C.K.j] or 1, 1,
					C.R.FX[C.K.j], C.R.FZ[C.K.j], C.K.side, brng, budget)
			end
		end
		geo[s] = st
	end
	self.geo = geo
end

--- The showcase's per-point look along a strand: (opacity, whiteness, heat 0..1) for braid value tv, pulse g.
local function strandLook(tv, g, corner, pw)
	local k = math.min(1, lerp(T.TwistK[1], T.TwistK[2], tv ^ 0.7) * (corner and 1 or T.MidK))
	local wh = math.min(0.95, T.TwistWhite * tv * tv + (corner and T.CornerWhite * tv or 0) + pw * g)
	local hot = tv * tv * (corner and 1 or 0.4) + g
	return k, wh, clamp01((hot - 0.55) / 0.45)
end

local function whFold(wh, hk) return math.min(0.95, wh + (1 - wh) * 0.5 * hk) end

--- One strand on one leg this frame (line_frame): the CORE on its zigzag and the GLOW on every corner of it -- one
--- STRAND chain, the two layers on the same attachments (the showcase's gstep-2 glow; a glow that skipped the corners
--- read as a gold ribbon beside a hard white wire), each Beam painted with its two ends' per-point look, the glow's
--- broken corners under soft caps. Thin: the glow on every 4th corner, on its own chain (the showcase's thin tier). A
--- dying strand: a violet core in a faint lifted-violet halo.
function Strike:drawRope(g, R, wk, bk, ember, cc, L, cx)
	local pts, n = R.pts, #R.pts
	local cwS, gwS, cbS, gbS, pw, pg = L.cwS, L.gwS, L.cbS, L.gbS, L.pw, L.pg
	local twv, pulse = L.twv, L.pulse
	local camPos = cx.camPos
	local fp = self.fp
	local cornerW = (1 + T.CornerW) / 2                    -- deviation 3: a corner's 1.3x core along its runs

	if ember then
		-- the showcase's beam(ember=True): a Dark core (x0.8) in a lifted-violet halo (3x it + 0.05) on every corner, at
		-- 0.15. First person: the live strand's lens rules (thinner at the lens, the core faded in off the hand, the halo
		-- faded in with the glow), so its two frames never pop in beside the hand
		local cw, hw, ca, ha = table.create(n), table.create(n), table.create(n), table.create(n)
		for i = 1, n do
			local w = (i == 1 or i == n) and 0 or cwS * R.ws[i] * wk * (R.corner[i] and cornerW or 1) * 0.8
			local a, h = 1, 0.15
			if fp then
				w *= lerp(T.FpJag[4], 1, lensK(pts[i], camPos, T.FpJag))
				a = lensK(pts[i], camPos, T.FpCoreFade)
				h *= lensK(pts[i], camPos, T.FpGlowLens)
			end
			cw[i], ca[i], ha[i] = w, a, h
			hw[i] = (i == 1 or i == n) and 0 or w * 3 + 0.05
		end
		local he = self:chain(g, "halo", pts, hw)
		local hb = 3.0 * 0.45 * 0.8 * self.kb * he.chain.BrK
		for i = 1, n - 1 do paintBeam(he.beams[i], cacheOf(he, i), { 0, ha[i], 1, ha[i + 1] }, EMBER_HALO, nil, hb) end
		local ce = self:chain(g, "core", pts, cw)
		local cb = 3.0 * 0.45 * self.kb * ce.chain.BrK
		for i = 1, n - 1 do paintBeam(ce.beams[i], cacheOf(ce, i), { 0, ca[i], 1, ca[i + 1] }, COL.Dark, nil, cb) end
		return
	end

	-- the showcase's per point: the core's width, opacity, whiteness and heat; the glow's width (braid, fan, pulse) and
	-- opacity (its k: the corners carry the light); the cap's opacity (the glow layer's). First person: the core thinner
	-- near the lens (FpJag) and faded in off the hand (FpCoreFade), the glow faded in with distance (FpGlowLens: the
	-- 0.62-stud glow at 1.5 studs would fill a third of the screen) and its round caps faster still (squared)
	local cw, k, wh, hk = table.create(n), table.create(n), table.create(n), table.create(n)
	local gw, ga, capA = table.create(n), table.create(n), table.create(n)
	for i = 1, n do
		local corner, x = R.corner[i], R.x[i]
		local gg, tv = pulse(x), twv(x)
		local tip = i == 1 or i == n
		cw[i] = tip and 0 or cwS * R.ws[i] * wk * (corner and cornerW or 1) * (1 + 0.35 * gg)
		k[i], wh[i], hk[i] = strandLook(tv, gg, corner, pw)
		gw[i] = tip and 0 or gwS * R.ws[i] * wk * (0.85 + 0.3 * tv) * self:glowFanX(x) * (1 + pg * gg)
		ga[i], capA[i] = GLOW_ALPHA * k[i], GLOW_ALPHA
		if fp then
			local lg = lensK(pts[i], camPos, T.FpGlowLens)
			ga[i] *= lg
			capA[i] *= lg * lg
			cw[i] *= lerp(T.FpJag[4], 1, lensK(pts[i], camPos, T.FpJag))
			k[i] *= lensK(pts[i], camPos, T.FpCoreFade)
		end
	end

	local ce
	if self.thin and n > 4 then
		-- the thin tier: the glow on every 4th corner (its ends kept), its own chain
		local idx = thinIdx(n, 4)
		local m = #idx
		local gp, gws, gas, cas = table.create(m), table.create(m), table.create(m), table.create(m)
		for j = 1, m do
			local i = idx[j]
			gp[j], gws[j], gas[j], cas[j] = pts[i], gw[i], ga[i], capA[i]
		end
		local ge = self:chain(g, "glow", gp, gws)
		local gbr = gbS * bk * self.glowK * ge.chain.BrK
		for j = 1, m - 1 do paintBeam(ge.beams[j], cacheOf(ge, j), { 0, gas[j], 1, gas[j + 1] }, COL.Base, nil, gbr) end
		paintCaps(ge, gws, cas, gbr)
		ce = self:chain(g, "core", pts, cw)
	else
		ce = self:take(g, "strand", n - 1)
		ce.chain:Set(pts, cw, gw)
		local gbr = gbS * bk * self.glowK * ce.chain.BrK
		for i = 1, n - 1 do
			paintBeam(ce.glows[i], glowCacheOf(ce, i), { 0, ga[i], 1, ga[i + 1] }, COL.Base, nil, gbr)
		end
		paintCaps(ce, gw, capA, gbr)
	end

	-- the core: every run painted with its two corners and its mid-run (opacity, whiteness), its heat as Brightness
	local brK = ce.chain.BrK
	for i = 1, n - 1 do
		local xm = (R.x[i] + R.x[i + 1]) * 0.5
		local km, whm, hkm = strandLook(twv(xm), pulse(xm), false, pw)
		if fp then km *= lensK((pts[i] + pts[i + 1]) * 0.5, camPos, T.FpCoreFade) end
		local heat = (hk[i] + hkm + hk[i + 1]) / 3
		paintBeam(ce.beams[i], cacheOf(ce, i), { 0, k[i], 0.5, km, 1, k[i + 1] }, cc,
			{ 0, whFold(wh[i], hk[i]), 0.5, whFold(whm, hkm), 1, whFold(wh[i + 1], hk[i + 1]) },
			cbS * bk * (1 + (T.HotB - 1) * T.HotFold * heat) * brK)
	end
end

--- line_frame(): the strands (core + glow a rope, painted), their dispersal and its sparks, this frame.
function Strike:drawStrands(tq, gf, cx)
	local lv = self.level
	local wo, bo = T.StrandOver[1], T.StrandOver[2]
	local per, vel, sig = T.Pulse[1], T.Pulse[2], T.Pulse[3]
	local bl, bv = T.Braid[1], T.Braid[2]
	local L = {
		cwS = T.StrandCore * (1 + wo * lv), gwS = T.StrandGlow * (1 + wo * lv),
		cbS = T.StrandB[1] * (1 + bo * lv) * self.kb, gbS = T.StrandB[2] * (1 + bo * lv) * self.kb,
		pw = T.Pulse[4] * (self.calm and T.CalmPulse or 1), pg = T.Pulse[5],
	}
	for s = 1, NSTR do
		local st = self.geo and self.geo[s]
		local wk, bk, ember = self:strandFade(s, tq)
		local g = self:group("s" .. s)
		local gB = self:group("b" .. s)
		if st and wk > 0 then
			-- THE TWIST (a braid phase running ALONG the strand, the three a third of a turn apart, creeping down range)
			-- and the PULSE of current (muzzle -> end, out of step with the other two; from game frame 2)
			local head = ((tq + T.PulsePhase[s]) % per) * vel
			local phase = 2 * math.pi * (s - 1) / 3
			L.twv = function(x) return 0.5 + 0.5 * math.cos(2 * math.pi * (x - bv * tq) / bl + phase) end
			L.pulse = function(x)
				if gf < 2 then return 0 end
				local z = (x - head) / sig
				return math.exp(-z * z)
			end
			local cc = bk < 1 and COL.Base:Lerp(COL.Light, bk) or COL.Light
			for _, R in ipairs(st.ropes) do self:drawRope(g, R, wk, bk, ember, cc, L, cx) end
			-- the dispersal: branches taper to nothing at their tips; a depth-1 branch carries a glow (not thin), twigs a
			-- core only; every tip a soft spark (one keyed sprite each), the loose ones past it; all of it gone before the
			-- ember
			if not ember then
				for _, B in ipairs(st.branches) do
					local bp, mm = B.pts, #B.pts
					-- first person: the strand's own FpJag thinning at the branch's root, so no branch is wider than
					-- the thinned strand it hangs off (roots are >= FpGlowLens[2] from the lens: see build)
					local lk = self.fp and lerp(T.FpJag[4], 1, lensK(bp[1], cx.camPos, T.FpJag)) or 1
					local cwl = table.create(mm)
					for i = 1, mm do
						local tp = i == 1 and 1 or (1 - (i - 1) / (mm - 1)) ^ 0.8
						cwl[i] = L.cwS * T.BranchW[B.depth] * B.w * wk * tp * lk
					end
					local bb = T.BranchB[B.depth]
					local gwv = (B.depth == 1 and not self.thin)
						and L.gwS * T.BranchGlow * B.w * wk * self:glowFanX(B.x) * 0.6 or nil
					self:bolt(gB, bp, cwl, gwv, cc, L.cbS * bb * bk, COL.Base, L.gbS * bb * 0.8 * bk, 1)
				end
				for i, S in ipairs(st.sparks) do
					self:particle("tip" .. s .. "_" .. i, SOFT, 1, S.p, S.s * wk, 0, COL.Light, 1, S.b * bk * self.kb, 0.3)
				end
			end
		end
	end
end

--- The bundle's haze: one faint Beam a leg along the shot, its ends faded (so the gaps between strands stay dark).
function Strike:drawHaze(tq, cx)
	if self.thin then return end
	local env = self:lineEnv(tq)
	if env <= 0.02 then return end
	local hw, ha, hb = T.Haze[1], T.Haze[2], T.Haze[3]
	local g = self:group("haze")
	local a = ha * env * env
	for _, leg in ipairs(self.legs) do
		local w = hw * (0.5 + 0.5 * leg.spread) * self:glowFanX(self:xOf(leg.mid))
		local e = self:chain(g, "haze", { leg.a, leg.b }, w)
		local ak = {}
		for _, kp in ipairs({ { 0, 0 }, { 0.1, 0.7 }, { 0.25, 1 }, { 0.5, 1 }, { 0.75, 1 }, { 0.9, 0.7 }, { 1, 0 } }) do
			local lf = self.fp and lensK(leg.a:Lerp(leg.b, kp[1]), cx.camPos, T.FpGlowLens) or 1
			ak[#ak + 1] = kp[1]
			ak[#ak + 1] = a * kp[2] * lf
		end
		paintBeam(e.beams[1], cacheOf(e, 1), ak, COL.Base, nil, hb * self.glowK * self.kb * e.chain.BrK)
	end
end

--- The knots: a star on every convergence (the muzzle, each body, the end), re-rolled every tick; v2's pops first.
function Strike:drawKnots(tq, k, rk, cx)
	local env = self:lineEnv(tq)
	local fk = tq >= T.Hold and easeOutQuad(env) or 1
	if fk <= 0.02 then return end
	local ksz, kcb, kgb = T.KnotStar[1], T.KnotStar[2], T.KnotStar[3]
	local lv = self.level
	for w, qi in ipairs(self.way) do
		local kn = self.knots[qi]
		local p = kn.pos
		local muzzle = kn.kind == "muzzle"
		local pos = muzzle and p or p - safeUnit(p - cx.camPos, Vector3.zero) * T.PiercePush
		local kr = Random.new(mix(self.seed, rk, 71, w))
		local ksc
		if tq < T.Pop then
			local e = easeOutCubic(tq / T.Pop)
			ksc = (muzzle and lerp(T.Node[2], T.NodePop, e) or T.PierceScale * lerp(1, T.NodePop, e)) * T.KnotScale
		else
			ksc = T.KnotScale * (1 + kr:NextNumber(-T.KnotScaleJitter, T.KnotScaleJitter))
		end
		local size = ksz * ksc * (1 + 0.25 * lv)
		if muzzle and self.fp then size *= T.FpSeed end
		self:star("knot" .. w, pos, size, kr:NextNumber(0, 360),
			kcb * (k < 2 and 1.25 or 1) * (1 + 0.3 * lv) * self.kb, kgb * self.kb, fk, 0.3)
	end
end

--- One pierce streak on game frame f (streaks(): born short off the face, thrown out on frame 1, tips going out).
function Strike:drawStreak(g, S, f)
	local cw, gw, cb, gb = T.PierceArc[1], T.PierceArc[2], T.PierceArc[3], T.PierceArc[4]
	local jr = Random.new(S.seed + f * 17)
	local o, d, ln = S.o, S.d, S.ln
	local kb = self.kb
	if f == 0 then
		local pts = Kit.jag(o + d * 0.05, o + d * (ln * 0.45), 1, 0.12 * ln, jr)
		self:bolt(g, pts, cw, gw * 0.8, COL.Light, cb * kb, COL.Base, gb * kb, 1)
	elseif f == 1 then
		local pts = Kit.jag(o + d * (ln * 0.20), o + d * (ln * 1.20), 1, 0.14 * ln, jr)
		self:bolt(g, pts, cw, gw, COL.Light, cb * kb, COL.Base, gb * kb, 1)
	elseif f == 2 then
		local pts = Kit.jag(o + d * ln, o + d * (ln * 1.5), 1, 0.10 * ln, jr)
		self:bolt(g, pts, cw * 0.6, nil, COL.Base, cb * 0.6 * kb, nil, 0, 0.5, CORE_ONLY)
	end
end

--- 3 PIERCE: frames 0-2 at every body's entry.
function Strike:drawPierce(gf, cx)
	if gf < 0 or gf > 2 then return end
	local k = 1 + 0.3 * self.level
	local g = self:group("pierce")
	for bi, B in ipairs(self.bodies) do
		if gf < 2 and not self.calm then                     -- a SMALL star: the impact is the only big one
			self:star("pierce" .. bi, B.entry, T.PierceStar[1] * k * (gf == 0 and 1 or 0.6), B.roll,
				T.PierceStar[2] * self.kb, T.PierceStar[3] * self.kb, gf == 0 and 1 or 0.6, 0.9)
		end
		for _, S in ipairs(B.streaks) do self:drawStreak(g, S, gf) end
		if gf < 2 then
			-- the struck surface itself flashes: a hot spot laid ON the body at the entry
			local ssz, sb = T.PierceSpot[1], T.PierceSpot[2]
			self:flatSpot("spot" .. bi, B.entry, B.normal, ssz * 2 * (1 + 0.25 * gf) * k,
				gf == 0 and COL.Light or COL.Base, gf == 0 and 1 or 0.7, sb * (gf == 0 and 1 or 0.7))
			if bi <= T.MaxPierceLights then
				local lb, lr, lb1 = T.PierceLight[1], T.PierceLight[2], T.PierceLight[3]
				local b = gf == 0 and lb or lb1
				if self.calm then b *= T.CalmFlash * (gf == 0 and 0.5 or 1) end
				self:light("pierce" .. bi, B.entry - self.dir * 0.6 + B.toCam * 0.5, b * k, lr, COL.Light)
			end
		end
	end
end

--- 4 IMPACT: where the line stops on a surface.
function Strike:drawImpact(tq, gf, rk, cx)
	local W = self.wall
	if not W then return end
	local env = self:lineEnv(tq)
	local k = 1 + 0.35 * self.level
	local HIT, nrm = W.pos, W.normal
	-- the star: full on the fire frame, 1.1x the next, shrinking to 0.45x by 0.12 s, gone by 0.20
	if tq < 0.20 then
		local sz, cb, gb = T.ImpactStar[1], T.ImpactStar[2], T.ImpactStar[3]
		local sk = gf == 0 and 1 or gf == 1 and 1.1 or lerp(1.1, 0.45, easeOutQuad((tq - 2 * F) / (0.12 - 2 * F)))
		local a = tq < 0.12 and 1 or 1 - span(tq, 0.12, 0.20)
		local roll = Random.new(mix(self.seed, 4800, math.floor(gf / 3))):NextNumber(0, 360)
		local pos = HIT - safeUnit(HIT - cx.camPos, Vector3.zero) * 0.3
		self:star("impact", pos, sz * k * sk, roll, cb * (gf == 0 and 1.25 or 1) * self.kb, gb * self.kb, a, 2.0)
	end
	-- arcs crawling over the surface round the hit (in its plane, just proud of it), easing out with the line
	if env > 0.02 then
		local counts = self.thin and T.ThinImpactArcs or T.ImpactArcs
		local n = gf < 3 and counts[1] or counts[2]
		local cw, gw, cb2, gb2 = T.ImpactArc[1], T.ImpactArc[2], T.ImpactArc[3], T.ImpactArc[4]
		local t1 = perpAny(nrm)
		local t2 = nrm:Cross(t1)
		local g = self:group("impact")
		for j = 1, n do
			local r = Random.new(mix(self.seed, 6100 + j * 37, rk))
			local ang = r:NextNumber(0, 2 * math.pi)
			local d = t1 * math.cos(ang) + t2 * math.sin(ang)
			local ln = r:NextNumber(T.ImpactArcLen[1], T.ImpactArcLen[2]) * (gf < 3 and 1 or 0.7) * k
			local a0 = HIT + d * r:NextNumber(0.05, 0.35)
			local pts = Kit.jag(a0, a0 + d * ln, T.ImpactArcDepth, 0.22 * ln, r)
			for i, p in ipairs(pts) do pts[i] = p - nrm * (p - HIT):Dot(nrm) + nrm * 0.06 end
			self:bolt(g, pts, cw, gw, COL.Light, cb2 * env * self.kb, COL.Base, gb2 * env * self.kb, 1)
		end
	end
	-- the light on the target: full one frame, 55 % settling to the held glow by 0.15 s, held (flickering) through the
	-- hold, then easing out past the last ember -- decoupled from the strands, so it never cuts
	local gone = T.Hold + 2 * T.BreakStagger + T.Fade
	local asz, acool, ab, hsz, hb = T.Afterglow[1], T.Afterglow[2], T.Afterglow[3], T.Afterglow[4], T.Afterglow[5]
	if tq < gone + acool then
		local lb, lr, lh = T.ImpactLight[1], T.ImpactLight[2], T.ImpactLight[3]
		local b
		if gf == 0 then
			b = lb * (self.calm and T.CalmFlash * 0.5 or 1)
		elseif tq < 0.15 then
			b = lerp(lb * 0.55 * (self.calm and T.CalmFlash or 1), lh, easeOutQuad((tq - F) / (0.15 - F)))
		elseif tq < T.Hold then
			-- flickering on the re-roll frame rk (every tick; every CalmEvery ticks under Reduce Flashing: 10 Hz)
			b = lh * Random.new(mix(self.seed, 881, rk)):NextNumber(0.85, 1.15)
		else
			b = lh * (1 - easeInQuad(span(tq, T.Hold, gone + 0.15))) + lh * 0.35 * (1 - span(tq, gone, gone + acool))
		end
		self:light("impact", HIT - self.dir * T.ImpactPush + self.toCamH * 0.3, b * k, lr, COL.Light)
		-- the hot spot, FLAT on the surface: under the knot while it holds, then cooling Light -> Base -> lifted violet
		-- (never brighter at the release; never through brown)
		local e = span(tq, gone - 0.06, gone + acool)
		local col = e < 0.5 and COL.Light:Lerp(COL.Base, clamp01(e * 2)) or COL.Base:Lerp(EMBER_HALO, (e - 0.5) * 2)
		local held = tq < gone - 0.06
		local size = (held and hsz or lerp(hsz, asz, easeOutQuad(e * 3)) * (1 - 0.25 * e)) * 2
		self:flatSpot("afterglow", HIT, nrm, size, col, held and 1 or (1 - e) ^ 1.5, held and hb or ab)
	end
end

--- The muzzle flash (fire frame, x0.4 the next) and the hold lights along the shot (the floor under it), flickering on
--- the re-roll frame `rk` (every tick; every CalmEvery ticks under Reduce Flashing).
function Strike:drawLights(tq, gf, rk)
	local lv = self.level
	if gf < 2 then
		local b = T.MuzzleFlash[1] * (gf == 0 and 1 or 0.4) * (1 + 0.4 * lv)
		if self.calm then b *= T.CalmFlash * (gf == 0 and 0.5 or 1) end
		self:light("muzzle", self.flashPos, b, T.MuzzleFlash[2], COL.Base)
	end
	if self.thin then return end
	local env = self:lineEnv(tq)
	if env <= 0.01 then return end
	for hi, H in ipairs(T.HoldLights) do
		local along = self.lineLen * H[1]
		if along > 2 then
			local flk = Random.new(mix(self.seed, 991 + hi, rk)):NextNumber(0.8, 1.15)
			self:light("hold" .. hi, self.muzzle + self.dir * along + self.holdOff, H[2] * env * flk * (1 + 0.4 * lv), H[3],
				COL.Base)
		end
	end
end

function Strike:step(cx)
	if self.dead then return false end
	local ts = self.tStart + (os.clock() - self.c0) * self.ts
	if ts >= self.endAt then return false end
	if self.crackleOn and ts >= T.Hold then
		self.crackleOn = false
		for _, pe in ipairs(self.crackle) do
			if pe.Parent then pe.Enabled = false end
		end
	end
	if not cx.cam then return true end
	local gf = math.floor(ts * 60 + FRAME_TOL)
	local tq = gf / 60
	local k = math.floor(gf / 2)                            -- the 30 Hz runtime frame
	local rk = self.calm and math.floor(k / T.CalmEvery) or k
	self.fp = self.own and firstPersonNow()
	self:beginFrame(cx)
	if rk ~= self.geoK and #self.legs > 0 then
		self:build(k, rk, cx)
		self.geoK = rk
	end
	self:drawStrands(tq, gf, cx)
	self:drawHaze(tq, cx)
	self:drawKnots(tq, k, rk, cx)
	self:drawPierce(gf, cx)
	self:drawImpact(tq, gf, rk, cx)
	self:drawLights(tq, gf, rk)
	self:endFrame()
	return true
end

--- A raycast against `model` alone.
local function probe(model, from, vec)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	return workspace:Raycast(from, vec, params)
end

local function fireImpl(data, opts, box)
	local origin, dir = data.Origin, data.Dir
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3 then return nil end
	dir = dir.Unit
	local character = (typeof(data.Character) == "Instance" and data.Character:IsA("Model")) and data.Character or nil
	local own = opts.Own == true or (character ~= nil and kitFlag(Kit.isOwn, character))
	if opts.Own == true then
		lastOwnFire = os.clock()
	elseif own and os.clock() - lastOwnFire < T.OwnEcho then
		return nil                                -- this client already drew its own shot from its claim
	end
	if character and charges[character] then
		charges[character]:Destroy()             -- the seed becomes the muzzle pop, at once
	end

	-- the clock: shot seconds since the fire frame (a late broadcast plays from its fire frame up to LateForgive)
	local scale = liveScale()
	local late = 0
	if opts.Own ~= true and type(data.T0) == "number" then late = math.max(0, serverNow() - data.T0) end
	local start = math.max(0, late - T.LateForgive) * scale
	local strikeEnd = T.Hold + 2 * T.BreakStagger + T.Fade + T.Ember * F
	if start >= strikeEnd then return nil end
	local fireBeats = start < T.Pop               -- sparks, punches, Bloom: only if the fire frame is still ours to draw

	-- the line and the bodies: Points[i] is Hits[i]'s entry (see the header)
	local dist = tonumber(data.Dist)
	if not dist and typeof(data.End) == "Vector3" then dist = (data.End - origin):Dot(dir) end
	dist = math.clamp(dist or 90, 0.5, 400)
	local endPos = origin + dir * dist
	local points = type(data.Points) == "table" and data.Points or {}
	local hits = type(data.Hits) == "table" and data.Hits or {}
	local raw = {}
	for i = 1, math.min(math.max(#points, #hits), T.MaxBodies * 2) do
		local p = points[i]
		if type(p) == "table" then p = p.Position or p[2] end
		local m = hits[i]
		if typeof(m) ~= "Instance" then m = nil end
		if typeof(p) ~= "Vector3" and m then
			-- no entry point: where the line meets the model
			local r = rootOf(m)
			if r then
				local sc = (r.Position - origin):Dot(dir)
				local h = probe(m, origin + dir * math.max(0, sc - 6), dir * 8)
				p = h and h.Position or origin + dir * math.max(0, sc - 0.5)
			end
		end
		if typeof(p) == "Vector3" then
			local s = (p - origin):Dot(dir)
			if s > 0 and s < dist - T.MergeGap then raw[#raw + 1] = { along = s, entry = p, model = m } end
		end
	end
	table.sort(raw, function(a, b) return a.along < b.along end)
	local bodies, last = {}, -math.huge
	for _, b in ipairs(raw) do
		if b.along - last >= T.MergeGap and #bodies < T.MaxBodies then
			bodies[#bodies + 1] = b
			last = b.along
		end
	end
	-- each body's entry face, its normal, its exit and its centre on the line
	for _, B in ipairs(bodies) do
		B.normal = -dir
		local exitAlong = B.along + 1.2
		if B.model then
			local h = probe(B.model, B.entry - dir * 1.5, dir * 3)
			if h then
				B.entry, B.normal = h.Position, h.Normal
				B.along = (h.Position - origin):Dot(dir)
			end
			local hx = probe(B.model, B.entry + dir * 8, -dir * 8)
			if hx then
				local a = (hx.Position - origin):Dot(dir)
				if a > B.along + 0.1 then exitAlong = a end
			end
		end
		exitAlong = math.min(exitAlong, dist - 0.05)
		B.exit = origin + dir * exitAlong + (B.entry - (origin + dir * B.along))
		B.center = origin + dir * ((B.along + exitAlong) * 0.5)
	end

	-- between the hands at the fire instant (the strands leave there: both arms throw the surge), unless that is nowhere
	-- near the shot
	local muzzle = nil
	if character then
		local _, cm = bothHands(character)
		muzzle = cm
	end
	if not muzzle or (muzzle - origin).Magnitude > T.MuzzleSlack then muzzle = origin end
	local muzzleAlong = (muzzle - origin):Dot(dir)

	-- the knots: the muzzle, every body, the end; the waypoints: every knot ahead of the last far enough to make a leg
	local knots = { { kind = "muzzle", pos = muzzle } }
	for _, B in ipairs(bodies) do knots[#knots + 1] = { kind = "body", pos = B.center, body = B } end
	knots[#knots + 1] = { kind = "end", pos = endPos }
	local way = { 1 }
	for i = 2, #knots do
		local p = knots[i].pos
		if (p - origin):Dot(dir) > muzzleAlong + T.MinLeg and (p - knots[way[#way]].pos).Magnitude >= T.MinLeg then
			way[#way + 1] = i
		end
	end

	-- the surface the line stops on, if any
	local wall = nil
	do
		local ex = { Kit.fxFolder() }
		if character then ex[#ex + 1] = character end
		if workspace.CurrentCamera then ex[#ex + 1] = workspace.CurrentCamera end
		for _, B in ipairs(bodies) do
			if B.model then ex[#ex + 1] = B.model end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ex
		local h = workspace:Raycast(endPos - dir * 1.5, dir * 2.5, params)
		if h and math.abs((h.Position - origin):Dot(dir) - dist) < 1.25 then wall = { pos = h.Position, normal = h.Normal } end
	end

	local self = setmetatable({}, Strike)
	box.obj = self
	self:initCanvas("Railspike", character, origin)
	self.character, self.Character, self.Live = character, character, true
	self.own = own
	self.ts, self.tStart, self.c0 = scale, start, os.clock()   -- tStart: never `start` (the method)
	self.dir, self.origin, self.muzzle, self.endPos = dir, origin, muzzle, endPos
	self.level = math.min(math.clamp(tonumber(opts.Level) or tonumber(data.Level) or 0, 0, 1), math.clamp(T.MaxLevel, 0, 1))
	self.seed = seedFrom(data.T0 or serverNow(), character)
	self.knots, self.way, self.bodies, self.wall = knots, way, bodies, wall
	self.lineLen = math.max(1, (endPos - muzzle):Dot(dir))
	self.fanLen = math.max(T.FanMin, self.lineLen)
	self.segCap = self.thin and T.StrandSegs.Thin or (own and T.StrandSegs.Own or T.StrandSegs.Other)
	self.crackle, self.geoK = {}, nil
	local afterEnd = T.Hold + 2 * T.BreakStagger + T.Fade + T.Afterglow[2]
	self.endAt = math.max(strikeEnd, wall and afterEnd or 0, T.Hold + T.CrackleLinger) + F
	self.deadline = os.clock() + (self.endAt - start) / scale + 1
	Debris:AddItem(self.folder, (self.endAt - start) / scale + 2)   -- the backstop if the runner ever stops

	local cam0 = workspace.CurrentCamera
	local camCF0 = cam0 and cam0.CFrame or CFrame.lookAt(origin - dir * 10 + Vector3.new(0, 3, 0), origin)
	local function towardCam(at)
		local v = camCF0.Position - at
		v = Vector3.new(v.X, 0, v.Z)
		v -= dir * v:Dot(dir)
		return safeUnit(v, Vector3.zero)
	end
	self.toCamH = towardCam(endPos)
	self.holdOff = towardCam(muzzle + dir * (self.lineLen * 0.5)) * 0.6 - Vector3.yAxis * 0.4
	self.flashPos = muzzle + dir * 0.9                   -- between the hands (both throw it)

	-- the legs, each with its per-shot wander
	local wrng = Random.new(mix(self.seed, 555))
	local function pinchOf(kn)
		if kn.kind == "muzzle" then return 0 end
		return kn.kind == "end" and T.Pinch[2] or T.Pinch[1]
	end
	self.legs = {}
	self.wander = { {}, {}, {} }
	for w = 1, #way - 1 do
		local ka, kb = knots[way[w]], knots[way[w + 1]]
		local a, b = ka.pos, kb.pos
		local L = (b - a).Magnitude
		local leg = {
			a = a, b = b, L = L, c = (b - a) / L, mid = (a + b) * 0.5,
			n = math.clamp(math.floor(L / T.TileLen + 0.5), 1, T.TileMax), spread = math.min(1, L / T.SpreadFullAt),
			rin = math.min(T.RampIn, 0.35 * L), rout = math.min(T.RampOut, 0.45 * L),
			qa = w, qb = w + 1, pa = pinchOf(ka), pb = pinchOf(kb),
		}
		self.legs[w] = leg
		for s = 1, NSTR do
			local wd = table.create(math.max(0, leg.n - 1))
			for j = 1, leg.n - 1 do wd[j] = wrng:NextNumber(-1, 1) end
			self.wander[s][w] = wd
		end
	end

	-- the pierce streaks, planned once a body: thrown up and down out of the entry face and out of the exit -- the
	-- showcase's 2 / 2 / 3 a body while PierceBudget allows (two bodies), then fewer in the same shares, the split kept
	-- even (an odd entry streak alternates up / down body to body) and always one out of the exit
	local nb = #bodies
	local full = T.PierceStreaks[1] + T.PierceStreaks[2]
	local per = self.thin and 2 or math.clamp(math.floor(T.PierceBudget / math.max(1, nb)), 2, full)
	local nExit = math.max(1, math.floor(per * T.PierceStreaks[2] / full + 0.5))
	local nEntry = per - nExit
	local pk = 1 + 0.3 * self.level
	for bi, B in ipairs(bodies) do
		local nUp = (bi % 2 == 1) and math.ceil(nEntry / 2) or math.floor(nEntry / 2)
		local r = Random.new(mix(self.seed, 4400, bi))
		B.roll = r:NextNumber(0, 360)
		B.toCam = towardCam(B.entry)
		B.streaks = {}
		local lift = B.toCam * 0.25 - dir * 0.55
		local function plan(o, axis, spread, count, salt, lenK)
			local rr = Random.new(mix(self.seed, salt, bi))
			for j = 1, count do
				B.streaks[#B.streaks + 1] = { o = o, d = coneDir(axis, spread, rr),
					ln = rr:NextNumber(T.PierceLen[1], T.PierceLen[2]) * lenK, seed = mix(self.seed, salt, bi, j) }
			end
		end
		plan(B.entry, lift + Vector3.yAxis * 0.8, 50, nUp, 5100, pk)
		plan(B.entry, lift - Vector3.yAxis * 0.8, 50, nEntry - nUp, 5150, pk)
		plan(B.exit, dir + Vector3.yAxis * 0.35, 40, nExit, 5300, 0.8 * pk)
	end

	-- v2's sparks, re-drawn soft: a burst on every body and the end (the fire frame), the crackle through the hold on
	-- every body and the end and one box a leg in this client's fan plane (never at the muzzle, where the chips land in
	-- the caster's face)
	local knotHost = self.host
	if fireBeats then
		for i = 2, #knots do
			local att = Kit.attach(knotHost, knots[i].pos)
			local pe = softSparks(att, burstPreset(), self)
			pe:Emit(math.max(1, math.floor(T.SparkBurst * self.pk + 0.5)))
		end
	end
	if start < T.Hold and self.pk > 0 then
		for i = 2, #knots do
			local att = Kit.attach(knotHost, knots[i].pos)
			self.crackle[#self.crackle + 1] = softSparks(att, cracklePreset(T.KnotCrackle * self.pk), self)
		end
		for li, leg in ipairs(self.legs) do
			local skip = (li == 1 and knots[way[1]].kind == "muzzle") and T.LineSkip or 0
			local len = leg.L - skip
			if len >= 0.5 then
				local mid = leg.a + leg.c * (skip + len / 2)
				local lat = leg.c:Cross(awayPerp(leg.mid, leg.c, camCF0))
				local h = Kit.host("RailspikeLine", CFrame.lookAt(mid, mid + leg.c, lat))
				h.Size = Vector3.new(T.LineBox[1], math.max(0.2, T.LineBox[2] * leg.spread * self:fan(mid)), len)
				h.Parent = self.folder
				self.crackle[#self.crackle + 1] = softSparks(h, cracklePreset(T.LineCrackle * len * self.pk), self)
			end
		end
	end
	self.crackleOn = #self.crackle > 0

	-- the fire frame: the camera punch (through Viewmodel: the Camera Shake setting) and the caster's Bloom kick
	if fireBeats then
		if own then
			local okL, _, VM = pcall(Kit.libs)
			if okL and type(VM) == "table" and VM.Punch then pcall(VM.Punch, T.CasterPunch) end
			if not self.calm then
				local bk = 1 + 0.5 * self.level
				pcall(Kit.bloomPulse, T.Bloom[1] * bk, T.Bloom[2] * bk, T.Bloom[3])
			end
		elseif Kit.punchNear then
			for _, B in ipairs(bodies) do pcall(Kit.punchNear, B.center, T.NearPunch, T.PunchReach) end
		end
	end

	self:start()                                    -- drawn on the fire frame
	return self
end

----------------------------------------------------------------------------------------------------
-- THE API
----------------------------------------------------------------------------------------------------
--- The windup. Returns a handle with :Stop() and :Destroy(); never nil, never throws (a missing kit gives a handle that
--- does nothing).
function RailspikeFX.Charge(character, opts)
	opts = type(opts) == "table" and opts or {}
	if not RunService:IsClient() or typeof(character) ~= "Instance" then return deadHandle(character) end
	if not libs() then return deadHandle(character) end
	local box = {}
	local ok, res = pcall(chargeImpl, character, opts, box)
	if ok and type(res) == "table" then return res end
	warnOnce("charge", "Charge failed: " .. tostring(res))
	if box.obj then pcall(function() box.obj:Destroy(true) end) end
	return deadHandle(character)
end

--- RailspikeChargeStop (an interrupt or a death before the fire): the windup fades out. Nothing if there is none.
function RailspikeFX.ChargeStop(character)
	local h = character ~= nil and charges[character]
	if h then h:Stop() end
end

--- The strike. Returns a handle with :Destroy(), or nil when there is nothing to draw (stale, a bad payload, the
--- caster's own echo, the kit missing). Never throws.
function RailspikeFX.Fire(data, opts)
	if not RunService:IsClient() or type(data) ~= "table" then return nil end
	if not libs() then return nil end
	local box = {}
	local ok, res = pcall(fireImpl, data, type(opts) == "table" and opts or {}, box)
	if ok then return res end
	warnOnce("fire", "Fire failed: " .. tostring(res))
	if box.obj then pcall(function() box.obj:Destroy(true) end) end
	return nil
end

--- EXTRA: clears every windup and strike in flight (a round reset, a harness).
function RailspikeFX.Clear()
	for i = #objs, 1, -1 do
		local o = objs[i]
		if not o.dead then o:Destroy() end
	end
	table.clear(charges)
end

return RailspikeFX
