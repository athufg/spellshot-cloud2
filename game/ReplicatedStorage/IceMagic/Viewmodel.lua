--[[
	Viewmodel  (ModuleScript)  ->  ReplicatedStorage/IceMagic/Viewmodel

	The DEDICATED first-person viewmodel: two purpose-built arms parented to the Camera, with their
	own geometry, their own scale, and their own animation set. This is all your own camera ever
	renders of you -- no torso, no legs, no head.

	WHY A DEDICATED RIG, AFTER TRYING THE OTHER THING
	  A previous pass put the camera at the character's head and drew the real body. It syncs
	  perfectly by construction, and it is the wrong answer: a real avatar's limbs are authored to
	  be seen from ten studs away, so at arm's length in a 70-degree lens the forearm alone spans a
	  third of the screen and the torso sits across the bottom of the frame. The reference does not
	  look like that -- it shows two arms, nothing else, occupying about the bottom third. That is a
	  viewmodel, and a viewmodel is built at viewmodel scale.

	FIRST AND THIRD PERSON ARE NOW INDEPENDENT SYSTEMS, DELIBERATELY
	  This module animates the arms you see. CastPose animates the real body everyone else sees.
	  Neither reads the other. They are not kept frame-identical and are not supposed to be -- they
	  are two pieces of animation work that happen to react to the same facts about what the player
	  is doing. That split is also why this one can be driven from RAW LOCAL INPUT (is Shift down
	  right now, is a slide running right now) instead of the replicated MoveState attribute: no
	  round trip, so the arms move on the keypress rather than a network tick later.

	THE SHAPE: ONE BARE ARM PER SIDE. NO SLEEVE, NO CUFF, NO HAND, NO FINGERS.
	  That is what the reference is, and it took two wrong passes to accept it -- the first cloned
	  the character's limbs and read as amorphous wedges, the second added a cuff, palm, fingers
	  and a thumb and read as an armoured gauntlet. Bare arms are not a simplification of the
	  reference, they ARE the reference. No element colour on the geometry either: the arms are
	  skin, full stop. Cryo's ice lives in the projectile and in the cast glow at the arm's tip.

	COMIC TREATMENT (three things, matching the rest of the pop-art kit)
	  1. OUTLINE. An inverted hull: the arm's own surface again, pushed 0.010 studs out along its
	     normals and wound inside-out, in flat black. Only its far side ever shows, as a band just
	     outside the silhouette. It is real geometry, so it is anti-aliased like everything else,
	     it thickens a little as the arm comes closer, and one closed shell means no interior lines.
	     (Highlight was tried first: its outline is aliased, and a part obeys only its nearest
	     Highlight, so per-tone Highlights drew a seam along every tone boundary.)
	  2. ONE BEVELLED CUBOID PER ARM, AS A MESH. The cross-section is a rounded RECTANGLE, not a
	     circle -- the reference arms are flat-sided slabs with softened edges and a flat end, and a
	     round tube reads as a pipe. Built in Blender and split by face into the five meshes of
	     IceMagic.ViewmodelArm3: an earlier build from primitives (crossed boxes, corner cylinders,
	     a Ball on the end) showed its seams as lego and its Ball as a knob, and EditableMesh is
	     gated behind Experience Settings > Security on this place.
	  3. TONES, LIT. Base on the top face, light down the outer side, shade down the inner side and
	     underneath -- each its own mesh with its own Color, and the tone boundaries land on the
	     bevel midlines. The pieces are lit by the scene plus a key light that rides the camera, so
	     the bevels carry a soft gradient and the arm reads as a solid, not a sticker. Flat
	     Highlight fills were tried first and looked exactly that flat.

	  Deliberately NOT here: wrist cuff, hand or glove shape, comic shine accent, halftone dots.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
-- Cryo Beam's fire beat, seconds after the cast: the server fires at LevitateTime + ChargeTime, and the
-- windup clip counts its FOCUS keys back from it. (VFXLibrary never requires this module -- the viewmodel
-- muzzle reaches it through VFXLibrary.LocalBeamOrigin -- so reading its tuning here is not a cycle.)
local CryoTuning = require(script.Parent:WaitForChild("VFXLibrary")).Tuning.CryoBeam
local CRYO_FIRE = CryoTuning.LevitateTime + CryoTuning.ChargeTime

local Viewmodel = {}

local rad = math.rad
local player = Players.LocalPlayer

----------------------------------------------------------------------------------------------------
-- configuration
----------------------------------------------------------------------------------------------------
Viewmodel.Config = {
	-- Local arm space: the arm runs from the elbow at z = 0 toward -Z.
	--
	-- SOLVED FROM THE REFERENCE IN 3D, NOT CHOSEN. A 21-second capture of RIVALS -- idle at 90 FOV,
	-- idle at 120, then running -- was masked per frame to isolate each fist, and a box of this
	-- section was fitted to every silhouette through the recording's own pinhole camera (Roblox
	-- FieldOfView is vertical; the frame was 2552x1464). The direction comes from where the arm's
	-- two long edges meet -- the vanishing point of two parallel 3D lines IS their direction -- and
	-- the depth from the tip's on-screen width. One rig, averaged over the 120-FOV idle frames,
	-- re-projects onto every 90-FOV frame within a few pixels, which is the proof that it is a real
	-- 3D placement and not a screen-space fudge. Idle, right arm, camera space:
	--
	--     tip .................... (0.497, -0.320, -1.029) studs
	--     pitch / yaw / roll ...... 68.2 / 27.7 / -11.8 degrees
	--
	-- The width is the scale anchor -- a silhouette cannot tell a big far arm from a small near one,
	-- so W/H stay ours and depth follows. Everything else is theirs: the arms rise at 68 degrees
	-- INTO the scene rather than across it, the tip sits a stud out, and at the bottom of the frame
	-- the arm passes half a stud from the lens. FOV is matched too (90, in FirstPersonController):
	-- the rig is fixed in 3D exactly as theirs is, so it looks like their 90 at 90 and their 120
	-- at 120.
	ArmLength = 1.2,            -- elbow to tip; the elbow is only the pose's reference point
	ArmWidth = 0.356,
	ArmHeight = 0.290,
	-- The mesh carries on this far BEHIND the elbow. At these poses the arm's far end goes behind
	-- the lens, so the mesh has to be long enough that its butt never enters the frame however far
	-- the run swings it. The near plane clips whatever is behind the camera.
	ArmBack = 1.3,

	-- THE ARM IS FIVE MESHES in IceMagic.ViewmodelArm4, one bevelled cuboid split by face: ArmTop
	-- (top face plus both ends), ArmBottom, ArmSideNeg (-X), ArmSidePos (+X), and ArmInk, the
	-- outline hull. (ArmShell, the whole surface in one piece, is in the same import and serves
	-- only as the reference frame.) Built in Blender from a projected cube -- flat faces exactly
	-- flat, 0.045-stud bevels smooth, tip flat -- and split at the bevel midlines.
	--
	-- WHY THE COLOURS BELOW ARE NOT THE COLOURS YOU SEE. Two things stood between a peach part and
	-- a peach pixel, both measured off native captures with white/grey/black pieces:
	--   * GLOSS. SmoothPlastic at the grazing angle these faces sit at reflects the sky: a BLACK
	--     piece rendered (120,128,150). A SurfaceAppearance with an all-white RoughnessMap kills
	--     that entirely (black -> (24,27,33)) and keeps the surface smooth, where Plastic and the
	--     other matte materials bring a visible grain.
	--   * LIGHT. The faces you see are lit by ambient alone unless something lights them from
	--     the viewer's side, and the ambient here is dim and bluish. So two small warm lights ride
	--     the camera: a key just below the lens for the top faces, and one down between the arms
	--     for the inner faces. Short ranges, so they die out before the ground.
	--
	-- The colours were solved from the measured response of each face to black/64/128/192/white
	-- pieces (out = a*(in/255)^g + b per channel; a matte MeshPart does not take Color on the
	-- same curve a plain Part does). A white piece tops out near (230,232,240) under these
	-- lights, so the peach lands at ~92% of (250,205,165) with the right hue. The sun still adds
	-- its own share, so the exact tone shifts a little with heading -- as the reference's does.
	RoughnessMap = "rbxassetid://119507074710478",   -- 16x16 white
	-- RETUNED FOR THE SUN-ON RIG (2026-09-23; the owner: "the sun made them look like that"). Under the v15 universal
	-- light the arms came out mustard, #B09763 facing the sun, against the pale peach Rivals' forearm holds in every frame
	-- the owner sent (#EDDCC9 lit, #D4BAA7 shade). Measured on a static copy of the idle arms at 90 FOV in the Hub
	-- (vmarm/rivals_sky/arm*.py), every capture turned into a light level through a fitted tonemap: shaded faces got 0.50
	-- of the flat reference (0.72 blue) where the old estimate said 1.03, so the lamps never came on; the sun adds ~1.5
	-- per unit of facing it; and the lamps were warm and sat BELOW the lens, lighting the inner faces 2-4x more than the
	-- tops. Now one white key lamp above and just behind the lens (tops 0.95, inner faces 0.40 per unit brightness) fills
	-- until a top face reaches TargetTop, and the tones are solved to land on Rivals' colours at that light: measured
	-- (241,221,198) top / (212,183,162) inner facing the sun, (242,224,202) / (214,186,166) facing away with the sun cut.
	-- The 2026-09-15 flat-light tones, if ever wanted: top (226,193,148), outer (236,207,156), inner (211,173,135).
	Skin = Color3.fromRGB(241, 186, 145),            -- top face and ends
	SkinLight = Color3.fromRGB(241, 186, 145),       -- outer side: lit like the top (Rivals' arm has one lit tone)
	SkinDark = Color3.fromRGB(222, 177, 142),        -- inner side and underside
	Ink = Color3.fromRGB(0, 0, 0),
	KeyLightOffset = Vector3.new(0, 0.3, 0.25),      -- above and just behind the lens: it lights the tops, not the gap
	KeyLightRange = 4,
	KeyLightBrightness = 7.0,
	KeyLightColor = Color3.fromRGB(255, 255, 255),   -- white: a warm lamp was half of the mustard
	GapLightOffset = Vector3.new(0, -0.95, -0.85),
	GapLightRange = 2.5,
	GapLightBrightness = 0,                          -- off: it lit only the inner faces (1.04 per unit) and flooded them
	-- LIGHT NORMALISATION. Every frame the scene's light on each face is estimated (sceneLight: a fill every face gets,
	-- plus the sun on the faces turned to it), the key lamp fills until a top face reaches TargetTop, and any face the
	-- scene then lights past its own target has its tone scaled back to it -- so the arms hold one colour whichever way
	-- you face, as Rivals' do. Levels are in units of flat light (a white Ambient and no sun = 1).
	TargetTop = Vector3.new(2.00, 2.00, 2.26),       -- the level the top tone is solved at (per channel: the fill is blue)
	TargetSide = Vector3.new(1.10, 1.12, 1.35),      -- the level the side/underside tone lands at with that lamp
	LampTop = 6.64,       -- what the key lamp at full is worth on a top face (0.948 per unit brightness x 7)
	LampSide = 2.81,      -- ... and on a side or underside face (0.401 x 7)
	AmbientShare = 0.75,  -- what max(Ambient, OutdoorAmbient) is worth on the arms with GlobalShadows on (1 with it off)
	SunShare = 0.60,      -- of Lighting.Brightness, what a face turned straight at the sun takes (measured ~1.5 at 2.5)
	SkyShare = 0.21,      -- what EnvironmentDiffuseScale's sky diffuse is worth at full, in SkyTint's colour
	-- The skylight is BLUE: the fit put about 2.2x as much blue as red on the arms.
	SkyTint = Vector3.new(0.82, 1.00, 2.29),
	-- A Color is sRGB and the light multiplies it in linear space, so holding the SCREEN colour still takes
	-- (target/level)^(1/2.2), not a linear divide. Checked against the fitted tonemap: the sun cut lands within 5 levels.
	ToneGamma = 1 / 2.2,
	ToneFloor = 0.45,     -- the tones never darken past this (a top face in full sun needs ~0.78)
	LightBlend = 8,       -- how fast the estimate is followed, per second, so crossing a zone eases instead of popping

	-- Motion
	IdleBlend = 10,          -- how fast a state change eases in
	ClipBlend = 18,          -- how fast a cast clip takes over
	SlideBlend = 20,         -- into and out of a slide: the reference is on the slide line in ~3 frames
	SwayAmount = 0.085,      -- look-sway, studs per rad/frame of camera turn
	SwayMax = 0.16,
	SwayResponse = 0.22,
	FallLift = 0.06,         -- falling: the arms float up this far (studs) at full fall speed...
	FallTip = 6,             -- ...and tip up this many degrees. Deliberately slight.
	ShotFlash = 4,           -- M1: palm glow brightness at release, fading in ~0.1 s

	-- A Beam whose first attachment sits on top of the camera draws nothing at all, so the muzzle
	-- is always pushed at least this far in front of the eye whatever the pose is doing.
	MuzzleMinDistance = 1.2,
}

local C = Viewmodel.Config

-- the light normalisation carries three channels rather than one luminance (see sceneLight), so it needs the colour
-- of each light source as a unit-ish vector: the sun renders white, the two lamps carry KeyLightColor's warmth
local ONE = Vector3.new(1, 1, 1)
local ZERO = Vector3.new()
local SUN_TINT = ONE
local LAMP_TINT = Vector3.new(C.KeyLightColor.R, C.KeyLightColor.G, C.KeyLightColor.B) / C.KeyLightColor.R

-- the M1's slow-motion tuning hook (see VFXLibrary.FireIcicleShard); 1 in normal play
local function shotScale()
	local v = script.Parent:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

----------------------------------------------------------------------------------------------------
-- poses
----------------------------------------------------------------------------------------------------
-- An arm pose is the ELBOW's camera-relative position plus the direction the forearm points from
-- it, plus a wrist bend. The forearm runs along the pose CFrame's LookVector, so:
--     LookVector = (-sin(yaw), cos(yaw) * sin(pitch), -cos(yaw) * cos(pitch))
-- Positive pitch aims the forearm UP the screen, positive yaw aims it inward for the right arm.
local function arm(x, y, z, pitch, yaw, roll, wrist)
	return { X = x, Y = y, Z = z, Pitch = pitch, Yaw = yaw, Roll = roll, Wrist = wrist }
end

--- Mirror an arm pose to the other side. X, yaw and roll flip; pitch and wrist do not.
local function mirror(a)
	return { X = -a.X, Y = a.Y, Z = a.Z, Pitch = a.Pitch, Yaw = -a.Yaw, Roll = -a.Roll,
		Wrist = a.Wrist }
end

--- A symmetric two-arm pose from one side's description.
local function sym(a) return { R = a, L = mirror(a) } end

--- A two-armed pose where the sides differ (most casts).
local function pair(r, l) return { R = r, L = l } end

-- IDLE is the pose every other pose is a departure from, and it is the one carrying the two
-- framing rules the reference actually pins down. Both are measured, not eyeballed -- the numbers
-- below were solved against a screen-space bounding box of every part, at three aspect ratios:
--
--   Both channels are now MEASURED, not solved for -- see the Config header. The elbow below is
--   the fitted tip walked back ArmLength along the fitted direction:
--       look = (-sin 27.7, cos 27.7 sin 68.2, -cos 27.7 cos 68.2) = (-0.465, 0.822, -0.329)
--       elbow = (0.497, -0.320, -1.029) - 1.2 * look = (1.055, -1.307, -0.634)
--   Note the depth: the elbow sits 0.63 studs out and the tip 1.03, so the arm RECEDES into the
--   scene, which is the foreshortening the reference shows and the earlier in-plane pose did not.
local POSE = {
	Idle = sym(arm(1.055, -1.307, -0.634, 68.2, 27.7, -11.8, 0)),

	-- Walking: barely different from idle. The motion is in the cycle, not the pose.
	Walk = sym(arm(1.065, -1.323, -0.624, 67.2, 27.7, -11.8, 2)),

	-- Sprinting: MEASURED. The median of every usable frame of the reference's run, per arm. The
	-- elbows come forward to the camera plane (Z -0.6 -> ~-0.05) and the arms drop to ~25 degrees
	-- of pitch, so a much longer stretch of forearm is in frame, low and thrust ahead -- the run
	-- reads as running because the whole arm moves, not because the pose is tilted.
	Sprint = pair(arm(0.785, -1.161, -0.068, 24.292, 17.907, -13.708, 8), arm(-0.785, -1.161, -0.068, 24.292, -17.907, 13.708, 8)),

	-- Sliding: MEASURED, like the run. Two RIVALS slides at 90 FOV, every frame fitted in 3D the same
	-- way (IoU 0.85-0.97; the two slides agree to ~0.03 stud). The pose is ASYMMETRIC: the right
	-- arm pulls in low and stands almost upright just right of centre, while the left lies long
	-- across the lower left, pointing in at the crosshair. Nothing cycles -- the pose is held -- but
	-- it is not frozen: over the 0.8 s hold both elbows drift steadily back toward the lens (~0.25
	-- stud, linear to within 0.04) and the right arm rolls further out. Slide is the pose as the
	-- slide begins (median of each slide's first 6 held frames), SlideLate the pose 0.8 s in
	-- (median of the last 6).
	Slide = pair(arm(0.533, -1.626, -0.982, 64.0, 7.3, -14.1, 0), arm(-1.504, -0.761, -0.901, 59.1, -51.9, 12.6, 0)),
	SlideLate = pair(arm(0.586, -1.627, -0.728, 62.0, 6.8, -20.6, 0), arm(-1.445, -0.850, -0.645, 53.4, -43.6, 14.6, 0)),

	-- Crouched: tucked in tighter and slightly higher than idle.
	Crouch = sym(arm(1.02, -1.253, -0.654, 70.2, 27, -9.8, -6)),

	----------------------------------------------------------------- cast shapes
	-- M1 (Icicle Shard): a repulsor palm thrust, not a throw. The forearm drives straight out toward
	-- the crosshair -- tip ~0.7 stud further into the scene than the ready pose, levelled to 25
	-- degrees -- and the shard leaves at full extension. One arm per shot; sym() mirrors it for the
	-- left, and the recoil pose is the same arm settled back a hair after the release.
	ShardOut = sym(arm(0.467, -0.783, -0.673, 25, 8, -18, 0)),       -- the palm turns out as it lands
	ShardRecoil = sym(arm(0.47, -0.80, -0.61, 26, 8, -14, 0)),
	-- Cryo's FROST LOTUS (2026-10-15): the right hand's reach across to the lotus (the pluck), and the left hand holding the
	-- lotus low in front, clear of the crosshair (each defined for the right arm; the left takes the mirror)
	LotusPluck = sym(arm(0.62, -1.02, -0.62, 32, 46, -24, 8)),
	LotusHold = sym(arm(0.86, -1.38, -0.78, 42, 30, -48, 12)),

	-- Flash Freeze: both fists come up, then drive down into the ground together.
	SlamUp = sym(arm(0.875, -1.164, -0.504, 83.2, 36.1, -15.8, -26)),
	SlamDown = sym(arm(0.835, -1.576, -0.964, 34.2, 36.1, 0.2, 38)),

	-- Chill Aura: palms turned down and pressed outward, planting the zone around you.
	AuraPush = sym(arm(1.035, -1.439, -0.884, 57.2, 36.1, -35.8, 54)),

	-- Frost Slide (the ability): the hand drops back hard, as if you had just pushed off.
	SlideTuck = pair(arm(1.175, -1.555, -0.344, 42.2, 36.1, -35.8, 26), arm(-1.085, -1.425, -0.564, 61.2, -31.2, 13.8, 4)),

	-- Cryo Beam (cryo_beam_spec E; tips solved with solveArm at FOV 90, 16:9). CHANNEL: both hands open low in
	-- the frame; FOCUS: they come up and in, cupped, and press together just under the crosshair; FIRE: the
	-- right palm drives out low at the right of the frame, the forearm pointing in at the crosshair, so the beam
	-- runs diagonally into the crosshair instead of straight away from the lens (moved there after the 2026-09-15
	-- Play review: on the Icicle Shard thrust's line the beam was seen end-on); the left drops to a brace low at
	-- the left (BeamBrace, the left arm of both), and the recoil is the right settled back a hair.
	ChannelOpen = sym(arm(0.798, -1.252, -0.335, 38, 26, -40, 0)),       -- tips (+-0.25, -0.56, -1.22), 0.50 apart
	FocusCup = sym(arm(0.475, -0.870, -0.366, 22, 16, -30, 0)),          -- tips 0.26 apart
	FocusPress = sym(arm(0.402, -0.775, -0.406, 18, 14, -30, 0)),        -- tips 0.20 apart
	BeamThrust = pair(arm(1.782, -1.185, -0.684, 16, 14, -16, 0), arm(-0.966, -1.711, -0.316, 50, -18, 14, 0)),
	BeamRecoil = pair(arm(1.792, -1.285, -0.619, 20, 14, -14, 0), arm(-0.966, -1.711, -0.316, 50, -18, 14, 0)),

	-- Railspike (Voltaic), the owner's note 2026-09-28: BOTH arms throw the surge, the hands WELL APART at shoulder
	-- height, forearms pointing out along the aim (elbows solved from the tips: tip = elbow + 1.25 x look, checked
	-- against ChannelOpen). GATHER: up and out, drawn back a touch as the charge builds; HOLD: pressing out, tips
	-- (+-0.60, -0.34, -1.30) -- 25 degrees either side of the crosshair, 15 down, 1.2 studs apart with the crosshair
	-- clear between them; THROW: driven out on the fire, tips (+-0.55, -0.28, -1.55); RECOIL: settled back a hair.
	SurgeGather = sym(arm(0.794, -0.823, -0.037, 20, 8, -20, 0)),     -- tips (+-0.62, -0.40, -1.20)
	SurgeHold = sym(arm(0.731, -0.641, -0.094, 14, 6, -20, 0)),       -- tips (+-0.60, -0.34, -1.30)
	SurgeThrow = sym(arm(0.659, -0.496, -0.324, 10, 5, -24, 0)),      -- tips (+-0.55, -0.28, -1.55)
	SurgeRecoil = sym(arm(0.679, -0.559, -0.252, 12, 5, -22, 0)),     -- tips (+-0.57, -0.30, -1.47)

	----------------------------------------------------------------- Pyro (Build Prompt #21)
	-- Fireball: the forearm tilts up with the fire gathering on the fist, drawn back a touch as the charge
	-- peaks, then punched straight down the crosshair -- further than a palm shot -- and a hair of recoil.
	FireballCharge = sym(arm(0.98, -1.36, -0.50, 50, 26, -34, 22)),
	FireballLoaded = sym(arm(1.00, -1.38, -0.42, 52, 27, -36, 26)),
	FireballPunch = sym(arm(0.40, -0.70, -0.86, 20, 9, 2, 0)),
	FireballRecoil = sym(arm(0.43, -0.74, -0.74, 22, 9, -4, 0)),
	-- Immolate: both arms swing out wide, then pull in to the chest, the tips meeting low without crossing.
	ImmolateOpen = sym(arm(1.30, -1.18, -0.80, 60, 8, -10, 6)),
	ImmolateIn = sym(arm(0.72, -1.40, -0.40, 62, 34, -40, 20)),
	-- Cryo's FROSTBLADE run (2026-10-15, the developer: "make the naruto run show in first person too"): Cold Momentum's
	-- Naruto run seen from the eyes. Arms swept straight back are behind the lens, so the fists drop low and wide to the
	-- bottom corners and stay there, cut by the frame, a hand kunai in each (FrostbladeKit.Naruto feeds SetNaruto)
	NarutoRun = sym(arm(1.311, -1.645, -0.132, 40, 15, -20, 0)),
	-- Ring of Fire: pointing down the crosshair while the hand draws the circle; the settle as it closes; thrown up
	-- at the right of the view, then flicked out down the crosshair onto the eruption. (A point solved straight
	-- at the circle pitched the arm down and lifted its back end into the lens.)
	TraceAim = sym(arm(0.52, -0.80, -0.78, 26, 10, -14, 4)),
	RingSettle = pair(arm(0.95, -1.30, -0.62, 58, 22, -12, 0), mirror(arm(1.055, -1.307, -0.634, 68.2, 27.7, -11.8, 0))),
	RingPointUp = sym(arm(1.0, -0.95, -1.05, 78, 20, -30, 30)),
	RingPointOut = sym(arm(0.42, -0.80, -0.92, 10, 8, -6, -8)),
	-- Detonate (Pyro phase two, 2026-09-23; the approved blocking, pyropack/pyro_newmoves_anim.py DT_*): the forearm
	-- swings in to stand up just under the crosshair (the hand drawn across), coils, then flicks out to the right edge
	-- pointing right; the hold is the flick settled a hair.
	DetonateGather = sym(arm(0.22, -1.30, -0.90, 62, 14, 20, 20)),
	DetonateCoil = sym(arm(0.20, -1.29, -0.92, 64, 17, 22, 24)),
	DetonateFlick = sym(arm(0.95, -1.05, -1.25, 22, -65, -20, -10)),
	DetonateHold = sym(arm(0.93, -1.07, -1.24, 24, -61, -18, -6)),
	-- Scorching Lash, round 3 (owner, 2026-09-24; pyropack/lash_v3_anim.py VM_*). HOLDING it: the right arm pulled back to
	-- the lower-right edge, mostly out of view (LashHold), while the left forearm points forward at the crosshair (LashAim,
	-- written for the right and mirrored by sym(): the left arm plays LashAim.L -- a held Fireball punch, the fist a little
	-- below-left of the crosshair so a six-second hold never covers it). RELEASING it: the right arm swings out past the
	-- right edge (LashEnter), sweeps in across the lower view under the crosshair (LashFront) to the crack lying across the
	-- lower left (LashCrack), and drops out at the bottom left (LashThru), while the left gets out of its way below the
	-- frame (LashDuck, mirrored like LashAim). Checked in the replica at 240 Hz, hold and release: the crosshair ray, and
	-- rays 0.04 of the half-height off it, never pass through either arm.
	LashHold = sym(arm(1.45, -1.75, -0.35, 40, -20, -20, 0)),
	LashAim = sym(arm(0.52, -0.84, -0.80, 8, 10, -6, 0)),
	LashEnter = sym(arm(1.70, -1.20, -0.70, 10, -60, -10, 0)),
	LashFront = sym(arm(0.85, -1.00, -1.20, 10, 25, 10, 0)),
	LashCrack = sym(arm(-0.35, -0.90, -1.25, 12, 74, 20, 0)),
	LashThru = sym(arm(-0.80, -1.40, -0.90, 25, 72, 30, 0)),
	LashDuck = sym(arm(1.15, -2.25, -0.40, 40, 15, -10, 0)),

	----------------------------------------------------------------- Terra: Bulwark Wall (2026-09-20)
	-- The wall is CALLED UP with one hand: it starts below the frame, palm down, and drives up out of the bottom of the
	-- view as the slabs leave the floor -- one connected motion. Then the body braces: that hand comes back across the
	-- face, knuckles out, and STAYS there while the wall does (the other arm is tucked in low behind it).
	WallSummonLow = pair(arm(0.95, -2.30, -0.70, 70, 10, -8, -20), mirror(arm(1.055, -1.307, -0.634, 68.2, 27.7, -11.8, 0))),
	WallSummonUp = pair(arm(0.80, -0.30, -1.05, -44, 6, -10, 26), mirror(arm(1.05, -1.90, -0.55, 46, 18, -6, 0))),
	WallBrace = pair(arm(0.42, -0.62, -0.92, -14, -26, 22, 16), mirror(arm(0.95, -1.75, -0.60, 40, 22, -10, 0))),

	----------------------------------------------------------------- Terra: Boulder Shot (reworked 2026-09-23)
	-- No poses here any more. The rework keys each arm on its OWN times (the off hand's guard lands at 0.30 s, between
	-- the throwing arm's core and cock keys), so its poses live in the two clips' per-side key lists, as the Wind Blade
	-- slash's do -- see Viewmodel.Clips.BoulderWindup / BoulderThrow. (The 2026-09-20 RockReach .. RockFollow set, one
	-- two-arm pose per beat played as eased steps, is gone with the three clips that used it.)

	----------------------------------------------------------------- Terra: Earthen Tomb (2026-09-20)
	-- The two-arm smash: both fists up over the lens, driven down out of the bottom of the frame, and left buried there
	-- while the cast is live. Then the raise: the right hand climbs back up through the frame, palm turned up, hauling --
	-- the left stays down on the floor. (Y is height, so -2.3 is below the bottom edge: the ground is under the view.)
	TombWind = sym(arm(0.95, -0.52, -0.78, -30, 10, -12, 12)),
	TombSmash = sym(arm(0.88, -2.36, -0.95, 62, 14, -10, -18)),
	TombGrip = sym(arm(0.92, -2.04, -0.86, 55, 12, -8, -12)),
	TombHaul = pair(arm(0.74, -1.30, -0.82, 12, 8, -16, 6), mirror(arm(0.95, -2.10, -0.80, 52, 12, -8, -10))),
	TombLift = pair(arm(0.66, -0.52, -0.70, -40, 4, -18, 22), mirror(arm(0.98, -2.16, -0.78, 54, 12, -8, -10))),

	----------------------------------------------------------------- Zephyr: Cross-Slash Dash (2026-09-16)
	-- CHARGE: the forearms rise and cross in the lower middle of the view (the left a hair deeper, so they never
	-- fight); DASH: both hands go behind the back, out of the frame; RELEASE: they whip up across the top of the view
	-- for a frame, then fling out and down to the lower corners as the X leaves; then back home.
	SlashCross = pair(arm(0.62, -1.15, -0.62, 55, 62, -30, 6), mirror(arm(0.62, -1.20, -0.70, 52, 62, -30, 6))),
	SlashGather = pair(arm(0.58, -1.10, -0.64, 58, 64, -32, 8), mirror(arm(0.58, -1.15, -0.72, 55, 64, -32, 8))),
	SlashBehind = sym(arm(1.05, -2.6, -0.2, 10, 20, 0, 0)),
	SlashCrossPass = pair(arm(0.75, -0.55, -0.95, 30, 70, 25, 0), mirror(arm(0.75, -0.62, -1.02, 26, 70, 25, 0))),
	SlashSpread = sym(arm(1.2, -1.1, -0.9, -20, -60, 20, -10)),
	-- the v6 showcase's (2026-10-07; see the CrossSlashDash clip): the counter-move, the dash's forward-pushed cross,
	-- the snap to the lower corners and the arrival's wide hold (tips ~0.96 / 1.12 across and ~0.5 / 0.6 down the view's
	-- half-tangents at 1 stud), the recovery coming back in. SlashBehind / CrossPass / Spread are the 2026-09-16 clip's.
	SlashAnt = sym(arm(0.95, -1.45, -0.35, 45, -35, 10, -12)),
	SlashDrive = pair(arm(0.62, -1.17, -0.78, 53, 62, -30, 6), mirror(arm(0.62, -1.22, -0.86, 50, 62, -30, 6))),
	SlashSnap = sym(arm(0.65, -1.25, -0.55, 40, -31, 20, -10)),
	SlashWide = sym(arm(0.75, -1.35, -0.45, 39, -32, 22, -12)),
	SlashFollow = sym(arm(0.95, -1.4, -0.5, 45, -10, 8, 0)),

	----------------------------------------------------------------- Zephyr: Gust Jump (2026-09-17)
	-- CAST: both forearms sweep in low and level from the sides, palms down, meeting at the bottom of the view as the wind
	-- gathers under the feet; LAUNCH: both hands shove down out of the view -- the push off the air.
	GustGather = sym(arm(1.10, -0.80, -0.35, 12, 40, -30, 28)),
	GustPush = sym(arm(1.00, -2.30, -0.45, -35, 20, -10, 30)),

	----------------------------------------------------------------- Zephyr: Cyclone (re-keyed 2026-10-07)
	-- The v6 showcase's first-person arms (blender_scripts/zephyr/spring/cyclone_bl.py circle_hands(fp) / _track(fp)):
	-- the hands' tips taken into the showcase's own (pitched) camera and halved onto this rig's scale, the forearms rising
	-- 38 -> 72 degrees with the climb. The circling keys are inline in CycloneForm; these are the release's beats.
	CycloneHold = sym(arm(0.84, -1.12, -0.98, 72, 14, -20, 24)),       -- the channel: overhead, the slow circle
	CycloneDraw = sym(arm(0.74, -1.38, -0.70, 75, 8, -10, 40)),        -- the draw-back: hands pulled back by the ears
	CyclonePush = sym(arm(0.68, -0.67, -0.56, 25, 10, -20, -25)),      -- the thrust: both palms driven at the funnel
	CycloneFollow = sym(arm(0.70, -0.76, -0.53, 25, 10, -20, -15)),
	CycloneRecover = sym(arm(0.78, -1.27, -0.27, 30, 10, -20, 10)),
}

Viewmodel.Poses = POSE

----------------------------------------------------------------------------------------------------
-- states  (continuous, chosen from raw local input every frame)
----------------------------------------------------------------------------------------------------
-- Each state is a base pose plus an optional cycle. The cycle is a function of a phase clock and a
-- 0..1 amount, returning a per-arm additive delta -- the same shape as a pose, minus the fields it
-- does not touch. Amplitudes are in studs / degrees.
local function bob(amount, rakeDeg)
	return function(phase, amt)
		local s, c = math.sin(phase), math.cos(phase * 2)
		local dR = { Y = s * amount * amt, Z = c * amount * 0.4 * amt, Pitch = -s * rakeDeg * amt }
		local dL = { Y = -s * amount * amt, Z = -c * amount * 0.4 * amt, Pitch = s * rakeDeg * amt }
		return dR, dL
	end
end

--- Sprint drives the arms fore-and-aft in opposition, hard enough to read as running rather than
--- as a walk bob, and rolls them slightly as they come forward.
--- A STRIDE, matched off the reference capture rather than guessed. Frame-stepping a second of
--- RIVALS running (30fps, ~0.6s per full cycle) shows the two arms alternating hard: each one
--- sweeps from low and outboard, up and ACROSS toward the centre, then drops back out while the
--- other takes over. For much of the cycle only one arm is in frame at all.
---
--- Two things an earlier version got wrong, both visible the moment you compare side by side:
---   * it lifted both arms together on abs(sin), which is a bounce, not a run. The lift has to be
---     signed so one arm rises while the other falls.
---   * its amplitude was tiny (8 degrees of pitch) because a previous pass had been trimmed back
---     to stop an arm crossing the crosshair. The reference DOES cross the middle mid-stride --
---     that sweep is the animation. Only the resting pose has to hold the channel open.
---
--- `inswing` is the across-the-body part: the rising arm pulls toward the aim line. Both sides
--- use -sin for it, because the left arm's X is negative, so the same sign moves each inboard on
--- its own half of the cycle.
local function pump(reach, lift, rollDeg, pitchDeg, inswing)
	inswing = inswing or 0
	return function(phase, amt)
		local s = math.sin(phase)
		local dR = { X = -s * inswing * amt, Y = s * lift * amt, Z = -s * reach * amt,
			Pitch = s * pitchDeg * amt, Roll = -s * rollDeg * amt }
		local dL = { X = -s * inswing * amt, Y = -s * lift * amt, Z = s * reach * amt,
			Pitch = -s * pitchDeg * amt, Roll = s * rollDeg * amt }
		return dR, dL
	end
end

--- A KEYFRAMED stride, measured rather than composed. The reference's run was tracked for seven
--- seconds, its stride period found by phase-folding the silhouette track (the fold with the
--- shortest string length: 0.534 s, and every tracked signal agreed), and every 3D fit binned by
--- phase. The run is contralateral and mirror-symmetric -- the left arm leaves the frame around
--- phase 0.1-0.3 and the right exactly half a period later -- so both arms' fits fold onto ONE
--- stride, and the right arm's table is the left's mirrored and shifted by half a period. Each
--- entry is the median pose in that twelfth of a stride, as a delta from the sprint pose. The
--- three bins where the arm is out of frame are the swing continuing down below the lens between
--- the last bin it was seen leaving and the first it was seen coming back. Phase 0 is the LEFT
--- arm at its most inboard.
local STRIDE = {
	Period = 0.534,     -- seconds per stride
	R = {
			{ X = -0.004, Y = 0.019, Z = 0.009, Pitch = 3.524, Yaw = -1.474, Roll = -0.278 },
			{ X = -0.027, Y = 0.044, Z = -0.047, Pitch = 0.771, Yaw = -0.278, Roll = -0.108 },
			{ X = -0.013, Y = 0.011, Z = -0.045, Pitch = 0.605, Yaw = 4.741, Roll = -0.623 },
			{ X = -0.013, Y = -0.021, Z = 0.025, Pitch = -0.379, Yaw = 5.897, Roll = -0.324 },
			{ X = 0.004, Y = -0.056, Z = 0.129, Pitch = -5.004, Yaw = 1.33, Roll = 0.213 },
			{ X = 0.03, Y = -0.179, Z = 0.266, Pitch = -22.868, Yaw = -1.675, Roll = 1.319 },
			{ X = 0.025, Y = -0.243, Z = 0.301, Pitch = -12.036, Yaw = 1.364, Roll = -0.724 },
			{ X = 0.025, Y = -0.265, Z = 0.318, Pitch = -26.455, Yaw = -0.485, Roll = -0.436 },
			{ X = 0.025, Y = -0.237, Z = 0.295, Pitch = -30.518, Yaw = -2.335, Roll = -0.148 },
			{ X = 0.025, Y = -0.139, Z = 0.212, Pitch = -19.936, Yaw = -4.184, Roll = 0.139 },
			{ X = 0.025, Y = 0.009, Z = 0.089, Pitch = 1.001, Yaw = -6.033, Roll = 0.427 },
			{ X = 0.023, Y = 0.013, Z = -0.036, Pitch = 0.375, Yaw = -4.294, Roll = -0.099 },
	},
	L = {
			{ X = -0.025, Y = -0.243, Z = 0.301, Pitch = -12.036, Yaw = -1.364, Roll = 0.724 },
			{ X = -0.025, Y = -0.265, Z = 0.318, Pitch = -26.455, Yaw = 0.485, Roll = 0.436 },
			{ X = -0.025, Y = -0.237, Z = 0.295, Pitch = -30.518, Yaw = 2.335, Roll = 0.148 },
			{ X = -0.025, Y = -0.139, Z = 0.212, Pitch = -19.936, Yaw = 4.184, Roll = -0.139 },
			{ X = -0.025, Y = 0.009, Z = 0.089, Pitch = 1.001, Yaw = 6.033, Roll = -0.427 },
			{ X = -0.023, Y = 0.013, Z = -0.036, Pitch = 0.375, Yaw = 4.294, Roll = 0.099 },
			{ X = 0.004, Y = 0.019, Z = 0.009, Pitch = 3.524, Yaw = 1.474, Roll = 0.278 },
			{ X = 0.027, Y = 0.044, Z = -0.047, Pitch = 0.771, Yaw = 0.278, Roll = 0.108 },
			{ X = 0.013, Y = 0.011, Z = -0.045, Pitch = 0.605, Yaw = -4.741, Roll = 0.623 },
			{ X = 0.013, Y = -0.021, Z = 0.025, Pitch = -0.379, Yaw = -5.897, Roll = 0.324 },
			{ X = -0.004, Y = -0.056, Z = 0.129, Pitch = -5.004, Yaw = -1.33, Roll = -0.213 },
			{ X = -0.03, Y = -0.179, Z = 0.266, Pitch = -22.868, Yaw = 1.675, Roll = -1.319 },
	},
}

local function keyed(keys)
	local n = #keys.R
	return function(phase, amt)
		local u = (phase / (2 * math.pi)) % 1 * n
		local i = math.floor(u)
		local t = u - i
		t = t * t * (3 - 2 * t)                     -- ease between keys so the fold's bins do not show
		local function sample(ring)
			local a, b = ring[i % n + 1], ring[(i + 1) % n + 1]
			local d = {}
			for k, va in pairs(a) do d[k] = (va + (b[k] - va) * t) * amt end
			return d
		end
		return sample(keys.R), sample(keys.L)
	end
end

Viewmodel.States = {
	Idle   = { Pose = POSE.Idle,   Cycle = bob(0.015, 1.8),  Cadence = 1.9 },   -- breathing
	-- Walking is the same stride at a little under half the amplitude.
	Walk   = { Pose = POSE.Walk,   Cycle = pump(0.105, 0.083, 6, 10.5, 0.075),  Cadence = 8.4 },
	-- Sprint: the measured stride; cadence is its period.
	Sprint = { Pose = POSE.Sprint, Cycle = keyed(STRIDE), Cadence = 2 * math.pi / STRIDE.Period },
	Crouch = { Pose = POSE.Crouch, Cycle = bob(0.021, 2.4),  Cadence = 5.0 },
	-- A slide is held, not cycled: the arms go to the measured entry pose and drift linearly to the
	-- late pose over Drift seconds of slide -- the reference's own rate, so a shorter slide simply
	-- stops part-way -- while the camera banks and drops (MovementController).
	Slide  = { Pose = POSE.Slide,  Late = POSE.SlideLate, Drift = 0.8, Cycle = nil },
}

----------------------------------------------------------------------------------------------------
-- clips  (one-shot, beat-timed, authored for THIS rig)
----------------------------------------------------------------------------------------------------
-- Trigger records the beat the VFX is timed to, so a caller can line an effect up with the pose
-- peak. Cam is the camera punch for that key. Three opt-in clip fields:
--   RestartGuard  seconds: Play asking for this clip again that soon after it started leaves it running
--                 rather than restarting it (the keypress plays it, the server's broadcast asks again)
--   Glow = false  the CastGlow light stays off for the whole clip
--   Spline = true the clip is CURVES, not eased steps: per-side key lists R / L (and a Cam list) in place of Keys,
--                 each played as one cubic through its keys (2026-09-23; see "spline clips" below Viewmodel.Play)

-- Boulder Shot's windup keys hang off the CHARGE: 0.62 and 1.10 are shares of TerraFX.Tuning.BoulderShot.ChargeTime
-- (1.10 s) -- the COCK a little over half way, the WOUND pose on the very frame the charge is full. Hardcoded rather than
-- read, because this module must not require TerraFX (TerraFX draws from the viewmodel's arms, not the other way round):
-- retune ChargeTime and these two move with it by hand, BOULDER_COCK keeping its 0.62 / 1.10 share.
local BOULDER_FULL = 1.10                    -- = TerraFX.Tuning.BoulderShot.ChargeTime
local BOULDER_COCK = 0.62                    -- = 0.564 x ChargeTime
-- The spline clips' blend. The From keys already start every clip exactly where the arm is, so the blend has no seam to
-- hide, and what it would add is LAG: the throw covers 1.3 studs and 45 degrees of pitch between its button-up and its
-- 0.05 s release, and at Rate 60 a 144 fps client drew the release 0.35 stud / 17 degrees short of the curve (60 fps
-- and below were exact, which is the trap: 60 is a whole step per frame there). Rate 240 is a whole step per frame up to
-- 240 fps -- Roblox's own cap -- so the arm IS the showcase's curve on every client, and past it (an uncapped client)
-- trails by 0.07 stud / 4 degrees at worst. Measured in a Python port of this blend against m1_rework_bl.py's track().
local BOULDER_RATE = 240

Viewmodel.Clips = {
	FlashFreeze = {
		Trigger = 0.38,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.16, Pose = POSE.SlamUp, Cam = Vector3.new(0, 0.22, 0),
				Easing = Enum.EasingStyle.Quad },
			{ t = 0.38, Pose = POSE.SlamDown, Cam = Vector3.new(0, -0.95, 0),
				Easing = Enum.EasingStyle.Quint },
			{ t = 0.58, Pose = POSE.SlamDown, Cam = Vector3.new(0, -0.80, 0) },
			{ t = 1.10, Pose = nil, Easing = Enum.EasingStyle.Sine },
		},
	},
	-- Frost Slide is a 0.2 s dash now, so the clip is the dash's length and no more: the arms drive into
	-- the push-off tuck on the first frames, hold it while the dash carries you, and are home by 0.3 s --
	-- which is also as long as IsPlaying() holds the M1 off. Trigger 0: the dash leaves on the keypress
	-- (Tuning.FrostSlide.LeadIn). The punch is a small dip, lighter than a cast's.
	FrostSlide = {
		Trigger = 0,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.05, Pose = POSE.SlideTuck, Cam = Vector3.new(0, -0.18, 0),
				Easing = Enum.EasingStyle.Quint },
			{ t = 0.20, Pose = POSE.SlideTuck, Cam = Vector3.new(0, -0.10, 0) },
			{ t = 0.30, Pose = nil, Easing = Enum.EasingStyle.Sine },
		},
	},
	ChillAura = {
		Trigger = 0.12,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.13, Pose = POSE.AuraPush, Cam = Vector3.new(0, -0.20, 0),
				Easing = Enum.EasingStyle.Back },
			{ t = 0.46, Pose = POSE.AuraPush, Cam = Vector3.new(0, -0.12, 0) },
			{ t = 0.86, Pose = nil, Easing = Enum.EasingStyle.Sine },
		},
	},
	-- Cryo Beam's windup, held from the keypress to the fire; ClipBlend lands each pose ~0.08 s after its key.
	-- CHANNEL opens the hands low as the body lifts (absolute times); FOCUS, from CRYO_FIRE - 0.70, cups them
	-- in and presses them together as the crystals gather. RestartGuard: the server's Windup broadcast asks for
	-- this clip again a round trip after the keypress started it. Glow = false: flat, no light on the hands.
	CryoBeamCharge = {
		Trigger = 0.40, Hold = true, RestartGuard = 0.6, Glow = false,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.20, Pose = POSE.ChannelOpen, Cam = Vector3.new(0, 0.10, 0),
				Easing = Enum.EasingStyle.Back },
			{ t = CRYO_FIRE - 0.70, Pose = POSE.ChannelOpen, Cam = Vector3.new(0, 0.12, 0) },
			{ t = CRYO_FIRE - 0.45, Pose = POSE.FocusCup, Cam = Vector3.new(0, 0.14, 0),
				Easing = Enum.EasingStyle.Quad },
			{ t = CRYO_FIRE - 0.13, Pose = POSE.FocusPress, Cam = Vector3.new(0, 0.16, 0),
				Easing = Enum.EasingStyle.Sine },
			{ t = CRYO_FIRE, Pose = POSE.FocusPress, Cam = Vector3.new(0, 0.16, 0) },
		},
	},
	-- the shot, keyed from the Fire broadcast: the right palm drives out on the UNLEASH with the camera dipping
	-- under it (a clip punch, so Camera Shake scales it and Reduce Flashing removes it -- see Update), kicks
	-- back a hair, and settles into the thrust for the channel. Stop blends the arms home.
	CryoBeam = {
		Trigger = 0.07, Hold = true, Glow = false,
		Keys = {
			{ t = 0.00, Pose = POSE.FocusPress, Cam = Vector3.new(0, 0.16, 0) },
			{ t = 0.07, Pose = POSE.BeamThrust, Cam = Vector3.new(0, -0.08, 0),
				Easing = Enum.EasingStyle.Quint },
			{ t = 0.16, Pose = POSE.BeamRecoil, Cam = Vector3.new(0, 0.04, 0),
				Easing = Enum.EasingStyle.Quad },
			{ t = 0.34, Pose = POSE.BeamThrust, Cam = Vector3.new(0, 0.06, 0),
				Easing = Enum.EasingStyle.Sine },
		},
	},

	-- Railspike's windup (Voltaic; VoltaicClient plays it on the press, RailspikeFX draws the surge off BOTH hands):
	-- both arms come up and out, wide apart at shoulder height, then press out as the charge builds. Held until the
	-- fire (RailspikeThrow) or a drop (Stop). Its own clip, not CryoBeamCharge (that one is Cryo Beam's, timed to its
	-- 1 s+ levitating windup). Glow = false: RailspikeFX lights the hands.
	RailspikeSurge = {
		Trigger = 0.55, Hold = true, RestartGuard = 0.6, Glow = false,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.14, Pose = POSE.SurgeGather, Cam = Vector3.new(0, 0.04, 0), Easing = Enum.EasingStyle.Back },
			{ t = 0.50, Pose = POSE.SurgeHold, Cam = Vector3.new(0, 0.06, 0), Easing = Enum.EasingStyle.Sine },
		},
	},
	-- (the fire is Viewmodel.ArmClips.RailspikeThrow, played on BOTH arms: a two-arm clip here would hold IsPlaying()
	-- -- and so every M1 -- for its whole length)

	----------------------------------------------------------------- Pyro (Build Prompt #21)
	Immolate = {
		Trigger = 0.22,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.10, Pose = POSE.ImmolateOpen, Cam = Vector3.new(0, 0.04, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.22, Pose = POSE.ImmolateIn, Cam = Vector3.new(0, -0.10, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.30, Pose = POSE.ImmolateIn, Cam = Vector3.new(0, -0.07, 0) },
			{ t = 0.52, Pose = nil, Easing = Enum.EasingStyle.Sine },
		},
	},
	-- Ring of Fire: the settle when the circle closes (held until the point takes over), and the ease back to
	-- idle the point plays over
	RingOfFireSettle = {
		Hold = true,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.20, Pose = POSE.RingSettle, Cam = Vector3.new(0, -0.05, 0), Easing = Enum.EasingStyle.Sine },
		},
	},
	RingOfFireIdle = {
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.60, Pose = POSE.Idle, Easing = Enum.EasingStyle.Sine },
		},
	},
	-- Zephyr's Ultimate, Cyclone (re-keyed 2026-10-07 from the v6 showcase, cyclone_bl.py; keys in LIVE seconds = the
	-- Blender's / 1.25): the summon (both hands low and in, 0.224), then THE CORKSCREW -- both hands circle COUNTER-
	-- CLOCKWISE seen from above, IN PHASE, each at its side of the view, rising and widening, the turn accelerating (a key
	-- every 60 degrees) -- to the top (1.2); then the channel's slow circle, the LOOP: the caller's clock
	-- (ZephyrFX.CycloneLoopClock with LoopFrom / LoopLength) repeats it until touchdown, its last key equal to its first.
	-- Hold; RestartGuard: the keypress starts it. Glow = false: flat, like the other Ultimates.
	CycloneForm = {
		Trigger = 0.224, Hold = true, RestartGuard = 0.6, Glow = false, Rate = 30,
		LoopFrom = 1.462, LoopLength = 1.571,
		Keys = {
			{ t = 0.000, Pose = nil },
			{ t = 0.224, Pose = pair(arm(0.96, -0.64, -0.83, 38, 14, -20, 24), mirror(arm(0.62, -0.64, -0.83, 38, 14, -20, 24))), Easing = Enum.EasingStyle.Sine },
			{ t = 0.480, Pose = pair(arm(0.78, -1.20, -0.88, 41, 14, -20, 24), mirror(arm(0.81, -1.20, -0.88, 41, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 0.643, Pose = pair(arm(0.56, -1.46, -0.74, 47, 14, -20, 24), mirror(arm(1.05, -1.46, -0.74, 47, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 0.765, Pose = pair(arm(0.57, -1.42, -0.54, 53, 14, -20, 24), mirror(arm(1.08, -1.42, -0.54, 53, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 0.864, Pose = pair(arm(0.86, -1.35, -0.48, 59, 14, -20, 24), mirror(arm(0.81, -1.35, -0.48, 59, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 0.949, Pose = pair(arm(1.18, -1.38, -0.76, 64, 14, -20, 24), mirror(arm(0.52, -1.38, -0.76, 64, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 1.024, Pose = pair(arm(1.17, -1.48, -1.20, 68, 14, -20, 24), mirror(arm(0.54, -1.48, -1.20, 68, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 1.092, Pose = pair(arm(0.83, -1.54, -1.43, 70, 14, -20, 24), mirror(arm(0.89, -1.54, -1.43, 70, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 1.154, Pose = pair(arm(0.51, -1.46, -1.26, 72, 14, -20, 24), mirror(arm(1.22, -1.46, -1.26, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 1.200, Pose = pair(arm(0.51, -1.33, -0.96, 72, 14, -20, 24), mirror(arm(1.22, -1.33, -0.96, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			-- the channel (the loop)
			{ t = 1.462, Pose = pair(arm(0.82, -1.12, -0.96, 72, 14, -20, 24), mirror(arm(0.86, -1.12, -0.96, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Sine },
			{ t = 1.724, Pose = pair(arm(0.98, -1.13, -1.03, 72, 14, -20, 24), mirror(arm(0.70, -1.13, -1.03, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 1.985, Pose = pair(arm(1.00, -1.18, -1.19, 72, 14, -20, 24), mirror(arm(0.68, -1.18, -1.19, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 2.247, Pose = pair(arm(0.86, -1.20, -1.29, 72, 14, -20, 24), mirror(arm(0.82, -1.20, -1.29, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 2.509, Pose = pair(arm(0.70, -1.19, -1.22, 72, 14, -20, 24), mirror(arm(0.98, -1.19, -1.22, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 2.771, Pose = pair(arm(0.68, -1.14, -1.06, 72, 14, -20, 24), mirror(arm(1.00, -1.14, -1.06, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
			{ t = 3.033, Pose = pair(arm(0.82, -1.12, -0.96, 72, 14, -20, 24), mirror(arm(0.86, -1.12, -0.96, 72, 14, -20, 24))), Easing = Enum.EasingStyle.Linear },
		},
	},
	-- ...and the touchdown (the server's CycloneActive; the Cyclone demo starts it at Blender 3.75): the showcase's
	-- channel (held, 0 .. 0.25) -> the draw-back (0.53, T_THR) -> the thrust, both palms driven at the funnel (0.65, the
	-- snap) -> the follow-through (1.00) -> the arms down (1.85) -> idle (2.85), at the Blender's own spacing
	CycloneRelease = {
		Trigger = 0.65, Rate = 30, Glow = false,
		Keys = {
			{ t = 0.00, Pose = POSE.CycloneHold },
			{ t = 0.25, Pose = POSE.CycloneHold, Easing = Enum.EasingStyle.Sine },
			{ t = 0.53, Pose = POSE.CycloneDraw, Cam = Vector3.new(0, 0.02, 0.06), Easing = Enum.EasingStyle.Sine },
			{ t = 0.65, Pose = POSE.CyclonePush, Cam = Vector3.new(0, -0.04, -0.12), Easing = Enum.EasingStyle.Back },
			{ t = 1.00, Pose = POSE.CycloneFollow, Cam = Vector3.new(0, -0.02, -0.05), Easing = Enum.EasingStyle.Sine },
			{ t = 1.85, Pose = POSE.CycloneRecover, Easing = Enum.EasingStyle.Sine },
			{ t = 2.85, Pose = POSE.Idle, Easing = Enum.EasingStyle.Sine },
		},
	},
	-- Zephyr's Primary, Cross-Slash Dash (re-keyed 2026-10-07 to the v6 showcase: cross_slash_dash_bl.FP_HANDS with
	-- cross_slash_v4's first-person snap pulled in so the arms stay in frame): the counter-move out to the sides, the
	-- forearms crossed low in the middle of the view (0.168) and coiled (0.252 / 0.30), pushed forward and STILL CROSSED
	-- through the dash, snapped open to the lower corners as you pass through (0.685), held wide through the arrival and
	-- the X (Trigger = ZephyrFX.Tuning.CrossSlash.Trigger) and the kit's hold, back in by 1.486 and home by 2.016. The
	-- kit's beats in look seconds through ZephyrFX_CrossSlash's clock map (ChargeTime 0.30, DashTime 0.50, Trigger 0.92).
	-- Rate 45. Played on the cast's own clock: held between the coil keys (0.28) while the key is held, the glide keys
	-- stretched over the charged glide. The X's zoom jolt and the takeoff's FOV punch are ZephyrDraw.CameraKick's.
	-- (Zephyr's Gust Jump clips -- GustJump here, and GustJumpHover, THE FLOAT, before CrossSlashDash -- were removed
	-- 2026-10-08: nothing has played them since Skyrider replaced Gust Jump on 2026-10-06. POSE.GustGather / GustPush are
	-- left in the pose table. The module as it stood is ServerStorage.BugfixSuperseded_2026_10_08.Viewmodel.)
	-- TERRA, Bulwark Wall (2026-09-20). The hand drives UP out of the bottom of the frame on the cast and the wall's own
	-- slabs leave the floor on the same beat (Trigger 0.06; the slabs' first course starts at 0 and is up by
	-- TerraFX.Tuning.BulwarkWall.RiseTime 0.26, so the hand leads them by a frame and they follow it). Then it settles
	-- across the face and HOLDS: AbilityFX lets go when the wall does, whichever way it went.
	BulwarkWall = {
		Trigger = 0.06, Hold = true, RestartGuard = 0.5, Rate = 50, Glow = false,
		Keys = {
			{ t = 0.00, Pose = POSE.WallSummonLow },
			{ t = 0.06, Pose = POSE.WallSummonUp, Cam = Vector3.new(0, 0.10, 0), Easing = Enum.EasingStyle.Quint },
			{ t = 0.26, Pose = POSE.WallBrace, Cam = Vector3.new(0, 0.04, 0), Easing = Enum.EasingStyle.Back },
		},
	},
	-- TERRA, Boulder Shot, REWORKED (2026-09-23): the owner's approved Blender showcase, blender_scripts/terra/
	-- m1_rework_bl.py -- its FP_R / FP_L / FP_CAM, which are this rig's own arm(...) rows (Blender's camera space is
	-- Roblox's), played the way the showcase plays them: CUBIC through the keys (Spline, see "spline clips"), never
	-- stopping on a middle key. Two clips where there were three (BoulderPick / BoulderCharge / BoulderThrow): the WINDUP
	-- for as long as the button is down, and the THROW when it comes up -- because in the game the button can come up at
	-- ANY time, a tap at 0.05 s or a hold of three seconds, and the showcase's single timeline (button up at 1.30) is
	-- just the one case of that.
	-- THE WINDUP, clocked in seconds since the press (SpellshotInput passes that clock to Play): the hand drives out and
	-- down over the floor (0.08, the Trigger: the first pieces tear loose), the core rock lands on the palm (0.18), the
	-- arm draws back into the cock as the charge builds and is WOUND on the frame it is full (BOULDER_COCK / BOULDER_FULL)
	-- -- a flat key, then HELD there however long the button stays down (Hold: past its last key a spline clip sits on
	-- it; the showcase's 1.10 -> 1.30 hold is exactly this). The off hand comes up and in to a guard. The camera sinks a
	-- touch into the reach and settles back and up with the weight. The tremble at full and the dip under each stone
	-- that lands are NOT in the clip: they are TerraFX's, laid on top with SetArmOffset.
	BoulderWindup = {
		Trigger = 0.08, Hold = true, Spline = true, Rate = BOULDER_RATE, Glow = false,
		R = {
			{ t = 0.00, From = true },
			{ t = 0.08, Pose = arm(0.78, -1.30, -1.05, 16, 12, -6, -16) },                  -- REACH: out and down, over the floor
			{ t = 0.18, Pose = arm(0.95, -1.18, -0.98, 40, 18, -10, 6) },                   -- the core lands: palm up
			{ t = BOULDER_COCK, Pose = arm(1.22, -1.10, -0.60, 50, 27, -18, 14) },          -- COCK
			{ t = BOULDER_FULL, Pose = arm(1.40, -1.02, -0.34, 57, 33, -24, 22), Stop = true },   -- WOUND, full: held
		},
		L = {
			{ t = 0.00, From = true },
			{ t = 0.30, Pose = arm(-0.90, -1.18, -0.82, 42, -22, 10, 0) },                  -- up and in: a guard
			{ t = BOULDER_FULL, Pose = arm(-0.88, -1.16, -0.80, 44, -22, 10, 0), Stop = true },
		},
		Cam = {
			{ t = 0.00, From = true },
			{ t = 0.08, Cam = Vector3.new(0, -0.05, -0.04) },
			{ t = BOULDER_FULL, Cam = Vector3.new(0.05, -0.02, 0.10), Stop = true },
		},
	},
	-- THE THROW, on the button coming up, from WHEREVER the arms are (the From keys): wound on a full hold, still on the
	-- way out on a tap. Over the top (0.028, kept tight: a bigger arc whips the held rock into the corner of the screen
	-- for a frame), the RELEASE long down the crosshair at 0.05 -- the Trigger, and the frame the showcase's rock leaves
	-- the fist -- the follow-through across the body and low, and home to the live pose by 0.77 while the off hand pulls
	-- down as the body unwinds. The camera lunges into the release and eases back. Keys are the showcase's minus its
	-- button-up (1.30).
	BoulderThrow = {
		Trigger = 0.05, Spline = true, Rate = BOULDER_RATE, Glow = false,
		R = {
			{ t = 0.00, From = true },
			{ t = 0.028, Pose = arm(1.02, -0.88, -0.66, 58, 17, -14, 6) },                  -- OVER the top
			{ t = 0.05, Pose = arm(0.56, -0.82, -1.36, 12, 6, -4, -24) },                   -- RELEASE, down the crosshair
			{ t = 0.17, Pose = arm(0.30, -1.40, -1.02, -10, -12, 6, -18) },                 -- FOLLOW-THROUGH, across and low
			{ t = 0.37, Pose = arm(0.84, -1.40, -0.78, 44, 20, -9, -4) },
			{ t = 0.77, Stop = true },                                                      -- the live pose
		},
		L = {
			{ t = 0.00, From = true },
			{ t = 0.15, Pose = arm(-1.22, -1.55, -0.36, 60, -30, 12, 0) },                  -- pulls down as the body unwinds
			{ t = 0.77, Stop = true },
		},
		Cam = {
			{ t = 0.00, From = true },
			{ t = 0.05, Cam = Vector3.new(-0.03, -0.07, -0.12) },
			{ t = 0.19, Cam = Vector3.new(-0.04, -0.03, -0.14) },
			{ t = 0.75, Cam = Vector3.new(), Stop = true },
		},
	},
	-- TERRA, Earthen Tomb (2026-09-20). THE SMASH, played on the keypress: the fists come up, then both drive down out of
	-- the frame with the camera dropping under the blow, and stay buried while the cast is live (Hold -- AbilityFX lets go
	-- when the server's TombPhase says the cast is over). Trigger 0.12 = TerraFX.Tuning.EarthenTomb.GripTime, the frame the
	-- fissure leaves her hands.
	EarthenTomb = {
		Trigger = 0.12, Hold = true, RestartGuard = 0.6, Glow = false,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.05, Pose = POSE.TombWind, Cam = Vector3.new(0, 0.07, 0), Easing = Enum.EasingStyle.Back },
			{ t = 0.12, Pose = POSE.TombSmash, Cam = Vector3.new(0, -0.15, 0), Easing = Enum.EasingStyle.Quint },
			{ t = 0.24, Pose = POSE.TombGrip, Cam = Vector3.new(0, 0.02, 0), Easing = Enum.EasingStyle.Sine },
		},
	},
	-- ...and THE RAISE. Its time is the PLATFORM's climb, 0 to 1 on the climb's own curve (AbilityFX clocks it from
	-- TombRiseAt / TombRiseFor), so the hand rises exactly as fast as the stone does, however long the climb takes.
	EarthenTombRaise = {
		Hold = true, Rate = 34, Glow = false,
		Keys = {
			{ t = 0.00, Pose = POSE.TombGrip, Cam = Vector3.new(0, 0.02, 0) },
			{ t = 0.35, Pose = POSE.TombHaul, Cam = Vector3.new(0, 0.06, 0), Easing = Enum.EasingStyle.Sine },
			{ t = 1.00, Pose = POSE.TombLift, Cam = Vector3.new(0, 0.12, 0), Easing = Enum.EasingStyle.Sine },
		},
	},
	CrossSlashDash = {
		Trigger = 0.92, Rate = 45,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.06, Pose = POSE.SlashAnt, Cam = Vector3.new(0, 0.02, 0.02), Easing = Enum.EasingStyle.Quad },
			{ t = 0.168, Pose = POSE.SlashCross, Cam = Vector3.new(0, -0.06, 0), Easing = Enum.EasingStyle.Back },
			{ t = 0.252, Pose = POSE.SlashGather, Cam = Vector3.new(0, -0.09, 0.03), Easing = Enum.EasingStyle.Sine },
			{ t = 0.30, Pose = POSE.SlashGather, Cam = Vector3.new(0, -0.13, 0.05), Easing = Enum.EasingStyle.Sine },
			{ t = 0.406, Pose = POSE.SlashDrive, Cam = Vector3.new(0, -0.10, -0.06), Easing = Enum.EasingStyle.Quint },
			{ t = 0.546, Pose = POSE.SlashDrive, Cam = Vector3.new(0, -0.10, -0.06) },
			{ t = 0.685, Pose = POSE.SlashSnap, Cam = Vector3.new(0, -0.10, 0), Easing = Enum.EasingStyle.Quint },
			{ t = 0.80, Pose = POSE.SlashWide, Cam = Vector3.new(0, -0.18, 0.05), Easing = Enum.EasingStyle.Back },
			{ t = 0.92, Pose = POSE.SlashWide, Cam = Vector3.new(0, -0.18, -0.08), Easing = Enum.EasingStyle.Quad },
			{ t = 1.206, Pose = POSE.SlashWide, Cam = Vector3.new(0, -0.17, 0) },
			{ t = 1.486, Pose = POSE.SlashFollow, Cam = Vector3.new(0, -0.07, 0), Easing = Enum.EasingStyle.Sine },
			{ t = 2.016, Pose = POSE.Idle, Easing = Enum.EasingStyle.Sine },
		},
	},
}

-- TERRA'S MOBILITY TECHNIQUE, Aftershock (2026-09-25; it replaces Tremor Vault): both fists overhead and down into the
-- ground in front of you. The showcase (blender_scripts/terra/aftershock_bl.py) has no first-person camera, so these
-- rows are AUTHORED for this rig from its beats and CHECKED AGAINST THE FRUSTUM in a Python port of solveArm and
-- splineTrack (the bar's 2.5 studs, ArmBack behind the elbow, projected at vertical FieldOfView 70, 90 and 110 -- the
-- setting's whole range -- at 16:9), not yet in Play:
--   GATHER  0.07   the fists dip and close in, low in the frame (tip ~75-85% down)
--   CHEST   0.22   the forearms stand up through the lower middle of the frame (tip ~55% down, near the centre)
--   RISE    0.40   gone out of the TOP: the elbows end above and a little behind the lens, so the whole bar is out of
--                  view at every FOV (on the way, for ~0.05 s, they sweep up past the lens: that is the arms going up)
--   TOP     0.54   held there, out of view (a Stop key), while the eye lifts and goes back with the weight
--   DRIVE   0.615  they chop down through the upper frame, fists near the centre
--   CONTACT 0.68   a Stop key: both fists at the bottom centre, 0.42 stud apart, the forearms driving DOWN into the floor
--                  ahead (tip 88% down at FOV 70, 77% at 90, 69% at 110 -- in frame at all three; a steep -60 pitch
--                  keeps the near end of the bar high and out of the way, ~12% of the frame per arm at FOV 70)
--   ...left in the ground to 0.98 (a Stop key), pulled out and low (1.30), and on the live pose by 1.63 (a Stop key).
-- The camera dips with the fold -- (0, -0.70, -0.30) at the contact -- and is back by 1.60; the slam's SHAKE is not in
-- the clip (Viewmodel.Shake, which SpellshotInput fires on the same clock). The left arm is the right mirrored.
-- KEYS ARE IN SIM SECONDS: SpellshotInput plays this with the hitpause clock (TerraFX.AftershockClock), which holds on
-- Hit for HoldFrames / 60 s, so the fists freeze on the contact frame while the shake runs on. The beat times are
-- HARDCODED, because this module must not require TerraFX (see BOULDER_FULL above): they are TerraFX.Tuning.Aftershock's
-- Rise / Top / Hit, Hit + FistsUp and Hit + Recover -- retune those and these move with them by hand.
-- Rate 240 (BOULDER_RATE): the arms ARE the curve on every client. Glow = false: an earth cast has no light.
-- EVERY NUMBER HERE IS A PROPOSAL -- tune it in Play at both ends of the FOV slider.
do
	local RISE, TOP, HIT = 0.40, 0.54, 0.68      -- = TerraFX.Tuning.Aftershock.Rise / Top / Hit
	local OUT, BACK = HIT + 0.30, HIT + 0.95     -- = Hit + FistsUp, Hit + Recover
	local R = {
		{ t = 0.00, From = true },
		{ t = 0.07, Pose = arm(1.00, -1.40, -0.53, 60, 30, -14, -8) },                  -- GATHER: dip, the fists close in
		{ t = 0.22, Pose = arm(0.47, -1.30, -1.24, 82, 12, -12, 8) },                   -- up through the lower middle
		{ t = RISE, Pose = arm(0.85, 0.95, 0.05, 94, 4, -10, 10) },                     -- OVERHEAD: out of the top
		{ t = TOP, Pose = arm(0.80, 1.05, 0.12, 98, 2, -8, 12), Stop = true },          -- the TOP, held out of view
		{ t = TOP + 0.075, Pose = arm(0.47, 0.30, -0.92, 5, 10, -8, -8) },              -- DRIVE, down through the frame
		{ t = HIT, Pose = arm(0.47, -0.08, -1.61, -60, 12, -6, -12), Stop = true },     -- CONTACT: fists bottom centre
		{ t = OUT, Pose = arm(0.47, -0.11, -1.58, -59, 12, -6, -11), Stop = true },     -- left in the ground
		{ t = HIT + 0.62, Pose = arm(0.83, -1.28, -0.23, 25, 20, -10, -4) },            -- pulled out, low
		{ t = BACK, Stop = true },                                                      -- the live pose
	}
	local L = {}
	for i, k in ipairs(R) do
		L[i] = table.clone(k)
		if k.Pose then L[i].Pose = mirror(k.Pose) end
	end
	Viewmodel.Clips.Aftershock = {
		Trigger = HIT, Spline = true, Rate = BOULDER_RATE, Glow = false,
		R = R,
		L = L,
		Cam = {
			{ t = 0.00, From = true },
			{ t = 0.07, Cam = Vector3.new(0, -0.06, 0) },
			{ t = TOP, Cam = Vector3.new(0, 0.12, 0.14), Stop = true },                  -- the eye lifts, the weight back
			{ t = HIT, Cam = Vector3.new(0, -0.70, -0.30), Stop = true },                -- ...and drops with the fold
			{ t = OUT, Cam = Vector3.new(0, -0.65, -0.28), Stop = true },
			{ t = HIT + 0.62, Cam = Vector3.new(0, -0.20, -0.08) },
			{ t = HIT + 0.92, Cam = Vector3.new(), Stop = true },
		},
	}
end

-- VOLTAIC'S ULTIMATE, Cascade re-lit (2026-09-27): THE SUMMON, first person. The showcase (blender_scripts/voltaic/
-- cascade_bl.py) raises both arms overhead, seen from behind the caster. Overhead in THIS rig is out of the top of the
-- view (Aftershock's RISE), which would hide the hands the charge gathers on, so here the forearms stand UP at either
-- side of the view, fists near its top edge: tips ~(+-0.55, 0.62, -1.02), 31 degrees up (in view at FOV 70-110), 1.1
-- studs apart with the crosshair clear between them -- where CascadeFX draws the arcs reeled into each hand, the
-- bridges snapping between them and the launch. The body's beats (CastPose.Clips.CascadeSummon): up by 0.30, the
-- tremble (keys every 0.03 s, +-0.008 stud / 1 degree: ~16 Hz, the two arms in opposition), the launch at 0.50 (the
-- Trigger = VoltaicFX.Tuning.Cascade.Windup, hardcoded: this module does not require VoltaicFX), held to 0.62 while the
-- storm answers, the live pose by 0.95. The eye lifts a touch with the arms and dips on the launch. Rate 240
-- (BOULDER_RATE): the arms ARE the curve. Glow = false: CascadeFX lights the hands. Authored against the frame maths
-- above (solveArm), NOT YET SEEN IN PLAY -- judge it at both ends of the FOV slider.
do
	local TOP = arm(0.84, -0.52, -0.78, 78, 14, -10, 0)       -- the forearm stood up at the right, the fist near the top
	local function shake(k)
		return arm(TOP.X + 0.008 * k, TOP.Y + 0.008 * k, TOP.Z, TOP.Pitch + 1.0 * k, TOP.Yaw, TOP.Roll, TOP.Wrist)
	end
	local R = { { t = 0.00, From = true }, { t = 0.30, Pose = TOP } }
	local L = { { t = 0.00, From = true }, { t = 0.30, Pose = mirror(TOP) } }
	for i = 0, 5 do
		local k = (i % 2 == 0) and 1 or -1
		R[#R + 1] = { t = 0.33 + 0.03 * i, Pose = shake(k) }
		L[#L + 1] = { t = 0.33 + 0.03 * i, Pose = mirror(shake(-k)) }
	end
	R[#R + 1] = { t = 0.50, Pose = TOP, Stop = true }            -- the launch
	R[#R + 1] = { t = 0.62, Pose = TOP, Stop = true }            -- held while the storm answers
	R[#R + 1] = { t = 0.95, Stop = true }                        -- the live pose
	L[#L + 1] = { t = 0.50, Pose = mirror(TOP), Stop = true }
	L[#L + 1] = { t = 0.62, Pose = mirror(TOP), Stop = true }
	L[#L + 1] = { t = 0.95, Stop = true }
	Viewmodel.Clips.CascadeSummon = {
		Trigger = 0.50, Spline = true, Rate = BOULDER_RATE, Glow = false,
		R = R,
		L = L,
		Cam = {
			{ t = 0.00, From = true },
			{ t = 0.30, Cam = Vector3.new(0, 0.06, 0.04) },
			{ t = 0.50, Cam = Vector3.new(0, 0.08, 0.05), Stop = true },
			{ t = 0.56, Cam = Vector3.new(0, -0.04, -0.02) },
			{ t = 0.95, Cam = Vector3.new(), Stop = true },
		},
	}
end

-- ===== GUST PAD (Zephyr v6 import, 2026-10-06) -- ADD-ONLY BLOCK, the Gust Pad builder's =====================
-- ZEPHYR'S DEFENSE TECHNIQUE, Gust Pad (it replaces Deflect Gust): the PALM-DOWN PRESS that puts a pad of air into the
-- floor at the crosshair. The showcase's first-person clip (blender_scripts/zephyr/spring/gust_pad_bl.py FPArms; the v6
-- aqua build keeps its beats) winds the right palm UP over -0.45..-0.18 and presses it flat, down and forward, at the
-- CONTACT (0.14), held through the BLOOM (0.26); here the key IS t = 0, so the wind-up is squeezed into the first 0.06 s.
-- One arm: the left stays on the live pose (no L track). The press lands low right of the crosshair (tip ~(0.37, -0.77,
-- -1.98): ~21 degrees under the centre, ~11 right -- in frame at FOV 70-110, clear of the crosshair), the eye dips with
-- the crouch, and it is home by 0.52 s (IsPlaying() holds the M1 off that long, no longer). Trigger = the contact
-- (ZephyrGustPad.Tuning.Look.Contact -- hardcoded: this module does not require Zephyr modules). Played by
-- ZephyrGustPad.LocalCast on the keypress; let go again if the server refuses the press (no floor there). Glow = false:
-- the pad lights itself, out where it lands. Authored by eye against the frame maths above (solveArm), NOT YET SEEN IN
-- PLAY. EVERY NUMBER HERE IS A PROPOSAL.
do
	local CONTACT = 0.14                                       -- = ZephyrGustPad.Tuning.Look.Contact
	Viewmodel.Clips.GustPad = {
		Trigger = CONTACT, Spline = true, Rate = BOULDER_RATE, Glow = false,
		R = {
			{ t = 0.00, From = true },
			{ t = 0.06, Pose = arm(1.02, -1.10, -0.62, 66, 24, -20, -26) },             -- the palm UP at the right, cocked
			{ t = CONTACT, Pose = arm(0.62, -1.28, -0.92, 26, 12, -18, 50), Stop = true }, -- THE PRESS: flat, down and forward
			{ t = 0.30, Pose = arm(0.64, -1.32, -0.88, 28, 12, -18, 48), Stop = true },   -- held through the bloom
			{ t = 0.52, Stop = true },                                                    -- the live pose
		},
		Cam = {
			{ t = 0.00, From = true },
			{ t = 0.06, Cam = Vector3.new(0, 0.05, 0) },
			{ t = CONTACT, Cam = Vector3.new(0, -0.22, -0.06), Stop = true },             -- the eye drops with the crouch
			{ t = 0.30, Cam = Vector3.new(0, -0.18, -0.05), Stop = true },
			{ t = 0.52, Cam = Vector3.new(), Stop = true },
		},
	}
end
-- ===== end GUST PAD =========================================================================================

----------------------------------------------------------------------------------------------------
-- arm clips  (one arm each, free to overlap -- the M1)
----------------------------------------------------------------------------------------------------
-- A full clip above owns BOTH arms, so starting one cuts the last one off. An M1 fires constantly
-- and alternates hands, so each arm gets its own slot instead: the right arm finishes coming home
-- while the left is already punching out, and neither is ever cut short. Keys: `From = true` is
-- wherever that arm was when the shot began; a key with no Pose is the live state pose (idle,
-- sprint, slide...), so every shot ends back on whatever the body is doing. Trigger is the
-- full-extension beat -- the frame the shard leaves the hand.
Viewmodel.ArmClips = {
	-- Frost Lotus's M1 (2026-10-15): the right hand plucks a petal from the lotus in the left and throws it in one fast
	-- motion -- the same full extension on the same beat (Trigger 0.107) and the same 0.453 s as IcicleShard, so the
	-- rate and the release cannot change; LotusHold: the left hand holding the lotus (held until SpellshotInput lets go)
	IcicleShardLotus = {
		Trigger = 0.107,
		Keys = {
			{ t = 0.000, From = true },
			{ t = 0.040, Pose = POSE.LotusPluck, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
			{ t = 0.107, Pose = POSE.ShardOut, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In },
			{ t = 0.173, Pose = POSE.ShardRecoil, Easing = Enum.EasingStyle.Sine },
			{ t = 0.453, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},
	LotusHold = {
		Hold = true, Trigger = math.huge,       -- (a hold never "releases": no shot leaves it, no flash on the arm)
		Keys = {
			{ t = 0.000, From = true },
			{ t = 0.100, Pose = POSE.LotusHold, Easing = Enum.EasingStyle.Quad },
		},
	},
	IcicleShard = {
		Trigger = 0.107,
		Keys = {
			{ t = 0.000, From = true },
			-- the punch accelerates INTO the stop, so full extension is a hard, readable beat
			{ t = 0.107, Pose = POSE.ShardOut, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In },
			{ t = 0.173, Pose = POSE.ShardRecoil, Easing = Enum.EasingStyle.Sine },
			{ t = 0.453, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},

	-- M1, Wind Blade (Zephyr, the slash rebuilt 2026-09-16): the approved choreography, blender_scripts/zephyr/wind_blade_v3/
	-- wb3_choreo.py, sampled every 0.015 s. Each hand has two strokes: down on the diagonal from high on its own
	-- side, and up from the bottom. A shot keys its arm through the slash (release at the Trigger, 0.06 s), the
	-- overshoot, the hold and the dip into its next stroke (0.255 s), and if nothing takes over, the arm settles back
	-- onto the live pose by 0.45 s. The poses are the right arm's (the choreography's left keys mirrored); sym() gives
	-- the left.
	-- 2026-09-17: the M1 plays WindSlashDown/Up instead, built from these two below splineShot: the same slash, then a
	-- still hold on the next stroke's start in place of the overshoot and dip. These two stay as they are for Deflect
	-- Gust's stand-in swing (SpellshotInput).
	-- The first posed key is 0.045 s, swung into from wherever the arm is (From): a chained shot starts on almost that
	-- pose already, and a shot from idle or a slow click rate swings in over three frames instead of snapping.
	-- Spline (2026-09-16): played as one smooth curve through these keys, with the arm eased onto it from wherever it was
	-- over Catch seconds (see splineShot), not an eased step per key -- the step stopped the arm dead on the 0.045 key and
	-- jumped it back to full speed a frame later, every stroke, and from rest snapped it up and back in three frames.
	WindBladeDown = {
		Trigger = 0.06, Spline = true, Catch = 0.10,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.045, Pose = sym(arm(1.249, -0.499, -0.596, 40.7, 7.7, -34.1, 0)), Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
			{ t = 0.060, Pose = sym(arm(1.261, -0.543, -0.629, 30.7, 19.9, -40.0, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.075, Pose = sym(arm(1.159, -0.704, -0.608, 24.4, 28.0, -39.1, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.090, Pose = sym(arm(1.048, -0.876, -0.552, 19.3, 34.9, -34.6, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.105, Pose = sym(arm(0.995, -0.965, -0.498, 16.3, 38.4, -30.0, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.120, Pose = sym(arm(1.005, -0.984, -0.438, 16.9, 37.2, -26.3, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.135, Pose = sym(arm(1.040, -0.977, -0.367, 19.6, 33.4, -22.3, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.150, Pose = sym(arm(1.067, -0.963, -0.306, 22.4, 29.1, -18.7, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.165, Pose = sym(arm(1.072, -0.956, -0.268, 23.7, 26.7, -16.0, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.180, Pose = sym(arm(1.054, -0.957, -0.244, 23.2, 27.0, -14.5, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.195, Pose = sym(arm(1.025, -0.956, -0.225, 21.6, 28.8, -13.8, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.210, Pose = sym(arm(0.994, -0.955, -0.215, 19.7, 30.9, -13.4, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.225, Pose = sym(arm(0.968, -0.957, -0.215, 18.3, 32.5, -12.8, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.240, Pose = sym(arm(0.958, -0.968, -0.222, 18.1, 32.6, -11.5, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.255, Pose = sym(arm(0.974, -0.998, -0.240, 20.2, 29.7, -8.8, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.45, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut },
		},
	},
	WindBladeUp = {
		Trigger = 0.06, Spline = true, Catch = 0.10,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.045, Pose = sym(arm(1.157, -1.092, -0.492, 34.6, 6.4, 4.1, 0)), Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
			{ t = 0.060, Pose = sym(arm(1.282, -0.976, -0.652, 41.3, -4.6, 8.0, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.075, Pose = sym(arm(1.312, -0.737, -0.716, 47.9, -12.5, 6.6, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.090, Pose = sym(arm(1.246, -0.487, -0.739, 55.1, -19.2, 2.1, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.105, Pose = sym(arm(1.161, -0.364, -0.747, 60.1, -22.4, -2.0, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.120, Pose = sym(arm(1.099, -0.381, -0.735, 61.4, -21.2, -4.7, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.135, Pose = sym(arm(1.036, -0.464, -0.702, 60.9, -17.8, -7.2, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.150, Pose = sym(arm(0.983, -0.561, -0.666, 59.7, -13.7, -9.5, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.165, Pose = sym(arm(0.947, -0.626, -0.641, 58.8, -10.8, -11.4, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.180, Pose = sym(arm(0.928, -0.633, -0.635, 59.1, -10.5, -12.8, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.195, Pose = sym(arm(0.915, -0.611, -0.641, 60.2, -12.2, -13.5, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.210, Pose = sym(arm(0.908, -0.573, -0.652, 61.7, -14.6, -13.8, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.225, Pose = sym(arm(0.911, -0.531, -0.664, 62.7, -16.8, -14.3, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.240, Pose = sym(arm(0.929, -0.500, -0.668, 62.6, -17.6, -15.5, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.255, Pose = sym(arm(0.966, -0.493, -0.657, 60.8, -16.2, -18.0, 0)), Easing = Enum.EasingStyle.Linear },
			{ t = 0.45, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut },
		},
	},

	----------------------------------------------------------------- Pyro (Build Prompt #21)
	-- M1, Fireball: the charge (the fire gathers on the fist), then the punch accelerating INTO full extension,
	-- where the fireball leaves (Trigger), a recoil, and home. The camera draws back a hair as the charge loads
	-- and kicks forward and down as the fist lands.
	-- Railspike's fire (Voltaic), played on BOTH arms at once (VoltaicClient fireRail, after Stop() drops the held
	-- RailspikeSurge): each hand drives the surge out from where it was (From), a hair of recoil held through the line's
	-- hold (RailspikeFX Hold 0.40), then back onto the live pose. An arm clip, not a Clips entry, so the M1 is free on the
	-- fire frame (an M1 shot simply takes its arm over), as Railspike's old Fireball shot was. The two arms' Cam add up,
	-- so each carries half the dip.
	RailspikeThrow = {
		Trigger = 0.06,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.06, Pose = POSE.SurgeThrow, Easing = Enum.EasingStyle.Quint, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(0, -0.035, 0) },
			{ t = 0.16, Pose = POSE.SurgeRecoil, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(0, 0.01, 0) },
			{ t = 0.40, Pose = POSE.SurgeRecoil },
			{ t = 0.75, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut },
		},
	},
	Fireball = {
		Trigger = 0.42,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.18, Pose = POSE.FireballCharge, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(0, 0.02, 0.05) },
			{ t = 0.34, Pose = POSE.FireballLoaded, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut,
				Cam = Vector3.new(0, 0.03, 0.08) },
			{ t = 0.42, Pose = POSE.FireballPunch, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In,
				Cam = Vector3.new(0, -0.07, -0.30) },
			{ t = 0.50, Pose = POSE.FireballRecoil, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(0, -0.04, -0.14) },
			{ t = 0.85, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},
	-- Ring of Fire's snap-and-point: thrown up at the right of the view, then flicked out down the crosshair on
	-- the ignition frame (Trigger)
	RingOfFirePoint = {
		Trigger = 7 / 30,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.16, Pose = POSE.RingPointUp, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(0, 0.03, 0.04) },
			{ t = 7 / 30, Pose = POSE.RingPointOut, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In,
				Cam = Vector3.new(0, -0.05, -0.18) },
			{ t = 0.40, Pose = POSE.RingPointOut, Cam = Vector3.new(0, -0.02, -0.06) },
			{ t = 0.85, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},

	----------------------------------------------------------------- Pyro phase two (2026-09-23)
	-- The approved blocking, pyropack/pyro_newmoves_anim.py (DETONATE_ARM, LASH_ARM_R, LASH_ARM_L), key for key. A key
	-- with no Easing or Direction is Quad Out, in the approved file as here.
	-- Mobility, DETONATE: one arm, the right. Drawn in under the crosshair, coiled, then the backhand flick out to the
	-- right edge on the Trigger (the mark lands, PyroFX.Tuning.Detonate.Trigger) with a small sideways camera jolt toward
	-- the flick -- the first shot to kick the camera sideways -- held, and home.
	Detonate = {
		Trigger = 0.27,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.12, Pose = POSE.DetonateGather, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(-0.02, 0, 0) },
			{ t = 0.20, Pose = POSE.DetonateCoil, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut,
				Cam = Vector3.new(-0.03, 0, 0.01) },
			{ t = 0.27, Pose = POSE.DetonateFlick, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In,
				Cam = Vector3.new(0.06, -0.01, -0.03) },
			{ t = 0.38, Pose = POSE.DetonateHold, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(0.03, 0, -0.01) },
			{ t = 0.78, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},
	-- Defense, SCORCHING LASH, round 3 (owner, 2026-09-24; the sidearm sweep, pyropack/lash_v3_anim.py): the whip arm, the
	-- right, RELEASED from the hold -- out past the right edge, then swept in across the lower view under the crosshair to
	-- the crack lying across the lower left on the Trigger (PyroFX.Tuning.ScorchingLash.Trigger, 0.22) with the camera
	-- jolted sideways along the stroke, then out at the bottom left and home by 0.75 (the body's ClipEnd). Played with
	-- ScorchingLashDuck on the left.
	ScorchingLash = {
		Trigger = 0.22,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.08, Pose = POSE.LashEnter, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut,
				Cam = Vector3.new(0.02, 0, 0.02) },
			{ t = 0.15, Pose = POSE.LashFront, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.In,
				Cam = Vector3.new(-0.03, -0.01, -0.02) },
			{ t = 0.22, Pose = POSE.LashCrack, Easing = Enum.EasingStyle.Linear, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(-0.10, -0.03, -0.05) },
			{ t = 0.32, Pose = POSE.LashThru, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.Out,
				Cam = Vector3.new(-0.05, -0.02, -0.02) },
			{ t = 0.75, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},
	-- ...and the LEFT arm at the release: it leaves the aim (ScorchingLashAim) and ducks below the frame before the stroke
	-- crosses where it was, with no camera kick of its own. Trigger = math.huge: Update compares t >= Trigger every frame (a
	-- nil one throws), so this arm never "releases" -- no palm flash on the wrong hand, and ShotPending("L") stays false.
	ScorchingLashDuck = {
		Trigger = math.huge,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.10, Pose = POSE.LashDuck, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
			{ t = 0.40, Pose = POSE.LashDuck },
			{ t = 0.75, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut },
		},
	},
	-- THE HOLD (round 3): the right arm drawn back to the lower-right edge and STAYING there (Hold: a held shot sits on its
	-- last key until another shot takes the arm -- the sweep, ScorchingLash, which departs from it -- or StopShot lets it
	-- go). Trigger = math.huge: it never "releases", so it is never a pending shot.
	ScorchingLashHold = {
		Trigger = math.huge, Hold = true,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.16, Pose = POSE.LashHold, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
		},
	},
	-- ...and, NEW in round 3, the LEFT forearm pointing forward at the crosshair for as long as the whip is held, the same
	-- kind of held shot: both arms are committed now, so the M1 is blocked while holding (SpellshotInput). Played on "L"
	-- with the grip; the release's ScorchingLashDuck takes the arm from it, and a hold that ends without a crack lets it go
	-- with StopShot("L", "ScorchingLashAim"), as the grip goes with StopShot("R", "ScorchingLashHold").
	ScorchingLashAim = {
		Trigger = math.huge, Hold = true,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.16, Pose = POSE.LashAim, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
		},
	},
}

----------------------------------------------------------------------------------------------------------------- Umbra (Phase 4)
-- UMBRA'S FIRST-PERSON CLIPS (Phase 4 stage A, 2026-09-28). The owner's approved Phase 3 arms, key for key:
--   Viewmodel.Clips.UmbraShadowDart      styleboard_magicflow/poses/shadow_dart_viewmodel_w230.json (both arms)
--   Viewmodel.ArmClips.UmbraMark         A/poses/mark_viewmodel.json (the LEFT slot: PlayShot("L", "UmbraMark"))
--   Viewmodel.Clips.UmbraShadowStep      B/poses/Viewmodel_ShadowStep.json
--   Viewmodel.Clips.UmbraEclipseCharge   B/poses/Viewmodel_EclipseCharge.json
--   Viewmodel.Clips.UmbraEclipseOpen     B/poses/Viewmodel_EclipseOpen.json
--   Viewmodel.Clips.UmbraDecoyDouble     B/poses/Viewmodel_DecoyDouble.json  (+ UmbraDecoyDoubleL, mirrored: see below)
-- Their poses go into POSE as Umbra* (Viewmodel.Poses, so the tuning tools see them). Every clip is played by UmbraAnim
-- (ReplicatedStorage.IceMagic.UmbraAnim), never from here; see TRIGGERS.md.
--
-- INSTALL, TWO HUNKS in Viewmodel.lua:
--  (1) Paste this whole block right AFTER the end of the ArmClips table -- the anchor is these 8 lines, which occur
--      exactly once (the ScorchingLashAim entry and the table's closing brace, tabs as in the file):
--          	ScorchingLashAim = {
--          		Trigger = math.huge, Hold = true,
--          		Keys = {
--          			{ t = 0.00, From = true },
--          			{ t = 0.16, Pose = POSE.LashAim, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
--          		},
--          	},
--          }
--      It needs, and finds in scope there: arm(), mirror(), sym(), pair(), POSE and Viewmodel.
--  (2) HideArms, a NEW clip field (B's proposal for Shadow Step; Viewmodel has no such thing today, and without the hunk
--      the field is simply ignored -- the arms stay drawn through the smoke, nothing breaks). In Viewmodel.Update replace
--          	local hide = thirdPerson()
--          	if hide ~= state.hidden then
--      (once in the file) with
--          	local hide = thirdPerson()
--          	-- HideArms (Umbra's Shadow Step, 2026-09-28): a clip may hide the arms for a window of its OWN time, { from, to }
--          	-- in clip seconds (its clock's, when it was played with one) -- the arms gone inside the smoke. The same write as
--          	-- the third-person view, so the two combine: either one hides the arms, and the frame the window ends they are back.
--          	local hc = state.clip
--          	if not hide and hc and hc.HideArms then
--          		local ht = (state.clipClock and state.clipClock()) or (os.clock() - state.clipStart)
--          		hide = ht >= hc.HideArms[1] and ht < hc.HideArms[2]
--          	end
--          	if hide ~= state.hidden then
--      That is the whole change: the existing branch below it writes LocalTransparencyModifier on every arm part and
--      switches the arm lamps off, exactly as for the third-person view, and puts them back the frame hide goes false.
--
-- HOW THESE PLAY IN THIS MODULE (checked against Update, so the approved videos are what the keys do):
--   * a Clips key eases Out by its DESTINATION key's Easing (Quad when none) and the arms chase it at the clip's Rate;
--     Cam is the destination key's. ArmClips (Mark) are played EXACTLY, with each key's Easing AND Direction.
--   * `Pose = nil` in a Clips key is NOT the live state pose: it is state.clipFrom, where the arms were when the clip
--     began. The Phase 3 replica (B/scripts/umb_lib.py) read it as the idle. For a clip that starts from the state pose
--     the two agree; for one that does not they do not -- UmbraEclipseOpen starts from the charge's squeeze, and a Shadow
--     Dart chained onto the last one's recovery starts from wherever that arm was -- so those two end on POSE.Idle, the
--     house fix (CycloneRelease and CrossSlashDash end the same way), which is what the videos show.
--   * Viewmodel.Play has no time scale of its own: UmbraAnim passes a clock (ShotTimeScale, and M1RateMult for the dart,
--     so under Eclipse the whole dart cycle runs 1.5x faster on the same keys).
--
-- TIMES THAT ARE TUNING, read from UmbraTuning exactly as the CastPose block reads them (pure data; VFXLibrary, required
-- at this module's top, has required it already):
--   ShadowDart.Windup      the click to the release (OWNER: 2.3); the charge keys stretch by Windup / 2.3, the snap, the
--                          recoil and the ease home keep their lengths
--   Eclipse.WindupTime     the held press (1.0); the charge keys stretch by it
--   ShadowStep's 0.12 key and HideArms' end are DissolveTime (0.12) as approved; UmbraAnim's clock HOLDS the clip inside
--   the window until the view has really moved, so a retuned DissolveTime needs nothing changed here.
--
-- CHANGES TO THE APPROVED FILES (each flagged in TRIGGERS.md):
--   UmbraShadowDart / UmbraEclipseOpen  the home key is POSE.Idle, not nil (see above)
--   UmbraMark                           Trigger = math.huge, not 0.08: an arm shot's Trigger fires the M1 PALM FLASH
--                                       (state.flash, ShotFlash 4 x the glow scale, in Umbra's shade) on that hand, and
--                                       the Mark cast is "quick and unshowy", no Tell and no light -- ScorchingLashDuck's
--                                       own device. The mark still lands at 0.08: that is the server's, not this key's.
--   UmbraDecoyDoubleL                   NEW, the peel cue on the LEFT arm, for a decoy the server put on the left (a wall
--                                       on the right); UmbraAnim predicts the side on the keypress

do
	local UMBRA_T = nil
	do
		local m = script.Parent:FindFirstChild("UmbraTuning")
		local ok, mod = pcall(function()
			return m and require(m)
		end)
		if ok and type(mod) == "table" then
			UMBRA_T = mod
		else
			warn("[Viewmodel] UmbraTuning unavailable, Umbra's clips use the approved timings: " .. tostring(mod))
		end
	end
	local W = math.max(0.2, tonumber(UMBRA_T and UMBRA_T.ShadowDart and UMBRA_T.ShadowDart.Windup) or 2.3)
	local WS = W / 2.3
	local EW = math.max(0.3, tonumber(UMBRA_T and UMBRA_T.Eclipse and UMBRA_T.Eclipse.WindupTime) or 1.0)
	local ES = EW / 1.0

	------------------------------------------------------------------------------------------------- poses
	-- M1, SHADOW DART: TUCK -- the right forearm pulled in low and steep, the flow starting to gather at its tip; GATHER --
	-- the tucked forearm drifts up and in as the ball forms at its tip; BRACE -- the right tip comes up just under the
	-- crosshair and the left forearm crosses in and meets it (in first person it really can); HOLD; RELEASE -- the right
	-- arm drives out toward the crosshair and flicks; the recoil. The left arm holds the brace through the release.
	POSE.UmbraDartTuck = pair(arm(0.78, -1.42, -0.34, 74, 16, -24, 14), arm(-1.1, -1.4, -0.6, 66, -27, 12, 0))
	POSE.UmbraDartGather = pair(arm(0.74, -1.36, -0.38, 66, 17, -22, 14), arm(-1.06, -1.34, -0.6, 62, -30, 13, 0))
	POSE.UmbraDartBrace = pair(arm(0.62, -1.12, -0.44, 38, 17, -18, 8), arm(-0.79, -0.96, -0.6, 37.6, -62.3, 22, 0))
	POSE.UmbraDartHold = pair(arm(0.62, -1.125, -0.435, 38.5, 17, -18, 8), arm(-0.79, -0.96, -0.6, 37.6, -62.3, 22, 0))
	POSE.UmbraDartRelease = pair(arm(0.5, -0.92, -0.72, 16, 10, -12, -24), arm(-0.79, -0.97, -0.6, 37.6, -62.3, 22, 0))
	POSE.UmbraDartRecoil = pair(arm(0.52, -0.95, -0.64, 20, 11, -13, -18), arm(-0.82, -0.99, -0.58, 40, -60, 20, 0))
	-- MARK, written for the right arm and mirrored (sym): the left slot plays .L. The left forearm flicks in and points
	-- below-left of the crosshair (its tip at screen -0.06, -0.31, never over the crosshair), held a beat.
	POSE.UmbraMarkPoint = sym(arm(0.46, -0.84, -0.78, 14, 12, -10, -6))
	POSE.UmbraMarkHold = sym(arm(0.46, -0.84, -0.75, 16, 12, -10, -6))
	-- SHADOW STEP: both arms drop and draw in toward the body on the keypress, then come back low and rise to the idle.
	POSE.UmbraStepTuck = sym(arm(0.98, -1.62, -0.42, 52, 30, -16, -12))
	POSE.UmbraStepRise = sym(arm(1.03, -1.46, -0.54, 60, 29, -13, -5))
	-- ECLIPSE: both forearms come in from the lower corners, their ends meeting low in the middle of the view (the
	-- crosshair stays clear); they press the mass; on the open they swing out to the edges, forearms pointing outward.
	POSE.UmbraEclipseGather = sym(arm(0.7, -1, -0.4, 36, 20, -40, 4))
	POSE.UmbraEclipsePress = sym(arm(0.66, -0.99, -0.41, 35, 20, -40, 6))
	POSE.UmbraEclipseSqueeze = sym(arm(0.63, -0.98, -0.42, 34, 20, -41, 8))
	POSE.UmbraEclipseOpen = sym(arm(1.45, -0.95, -0.75, 22, -50, 30, -20))
	POSE.UmbraEclipseOpenHold = sym(arm(1.4, -0.98, -0.72, 24, -46, 28, -16))
	-- DECOY DOUBLE: the decoy stands 3.8 studs to the right, outside a 90-degree view, so the cast is read off the right
	-- arm: it swings out toward the right edge (the copy peeling off it is the VFX) and comes home. The left stays idle.
	POSE.UmbraDecoyPeel = pair(arm(1.3, -1.2, -0.62, 56, -6, 6, -6), POSE.Idle.L)
	POSE.UmbraDecoyPeelHold = pair(arm(1.26, -1.24, -0.6, 58, 0, 2, -4), POSE.Idle.L)

	------------------------------------------------------------------------------------------------- clips
	-- M1, SHADOW DART (the MAGIC FLOW board, Windup 2.30 s). Both arms: the brace needs both. Glow = false: the ball in the
	-- hand is the VFX's, with its own light. Rate 40: at the default ClipBlend a 0.3 s tuck smears into the brace.
	Viewmodel.Clips.UmbraShadowDart = {
		Trigger = W, Glow = false, Rate = 40,
		Keys = {
			{ t = 0.00, Pose = nil },                                                                        -- the click
			{ t = 0.30 * WS, Pose = POSE.UmbraDartTuck, Cam = Vector3.new(0, -0.03, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 1.30 * WS, Pose = POSE.UmbraDartGather, Cam = Vector3.new(0, -0.04, 0), Easing = Enum.EasingStyle.Sine },
			{ t = 1.65 * WS, Pose = POSE.UmbraDartBrace, Cam = Vector3.new(0, -0.06, 0), Easing = Enum.EasingStyle.Quint },
			{ t = W - 0.03, Pose = POSE.UmbraDartHold, Cam = Vector3.new(0, -0.06, 0), Easing = Enum.EasingStyle.Sine },
			{ t = W, Pose = POSE.UmbraDartRelease, Cam = Vector3.new(0, -0.02, -0.05), Easing = Enum.EasingStyle.Quint },
			{ t = W + 0.08, Pose = POSE.UmbraDartRecoil, Cam = Vector3.new(0, 0.02, 0.02), Easing = Enum.EasingStyle.Quad },
			{ t = W + 0.50, Pose = POSE.Idle, Easing = Enum.EasingStyle.Sine },                            -- home
		},
	}

	-- PRIMARY, SHADOW STEP. The arms drop and draw in on the keypress, are GONE inside the smoke from 0.05 (HideArms) until
	-- the re-form, come back low and rise onto the idle. The 0.12 key is where UmbraAnim's clock holds until the view has
	-- actually moved, so the arms never re-form at the old spot. RestartGuard: a second Play asking for it that soon
	-- leaves it running.
	Viewmodel.Clips.UmbraShadowStep = {
		Trigger = 0, Glow = false, RestartGuard = 0.4, Rate = 30,
		HideArms = { 0.05, 0.12 },
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.05, Pose = POSE.UmbraStepTuck, Cam = Vector3.new(0, -0.1, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.12, Pose = POSE.UmbraStepTuck, Cam = Vector3.new(0, -0.08, 0) },
			{ t = 0.30, Pose = POSE.UmbraStepRise, Cam = Vector3.new(0, -0.03, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.50, Pose = nil, Easing = Enum.EasingStyle.Sine },
		},
	}

	-- ULTIMATE, ECLIPSE: the held GATHER / PRESS (the telegraph), held until the open takes over (Hold). RestartGuard: the
	-- keypress starts it and the server's EclipseCharge broadcast asks for it again a round trip later.
	Viewmodel.Clips.UmbraEclipseCharge = {
		Trigger = EW, Hold = true, Glow = false, RestartGuard = 0.6, Rate = 14,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.24 * ES, Pose = POSE.UmbraEclipseGather, Cam = Vector3.new(0, -0.04, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.62 * ES, Pose = POSE.UmbraEclipsePress, Cam = Vector3.new(0, -0.05, 0), Easing = Enum.EasingStyle.Sine },
			{ t = EW, Pose = POSE.UmbraEclipseSqueeze, Cam = Vector3.new(0, -0.06, 0), Easing = Enum.EasingStyle.Sine },
		},
	}
	-- ...THE OPEN, on the server's EclipseStart: both arms swing out to the edges with the camera lifting and easing back a
	-- touch (full spread on the Trigger, when the pulse goes out), settle, and go home.
	Viewmodel.Clips.UmbraEclipseOpen = {
		Trigger = 0.10, Glow = false, Rate = 30,
		Keys = {
			{ t = 0.00, Pose = POSE.UmbraEclipseSqueeze, Cam = Vector3.new(0, -0.06, 0) },
			{ t = 0.10, Pose = POSE.UmbraEclipseOpen, Cam = Vector3.new(0, 0.06, 0.14), Easing = Enum.EasingStyle.Quint },
			{ t = 0.32, Pose = POSE.UmbraEclipseOpenHold, Cam = Vector3.new(0, 0.04, 0.08), Easing = Enum.EasingStyle.Sine },
			{ t = 0.95, Pose = POSE.Idle, Easing = Enum.EasingStyle.Sine },                                -- home
		},
	}

	-- TECHNIQUE, DECOY DOUBLE: the right arm swings out toward the copy and comes home.
	Viewmodel.Clips.UmbraDecoyDouble = {
		Trigger = 0.10, Glow = false, Rate = 24,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.10, Pose = POSE.UmbraDecoyPeel, Cam = Vector3.new(0, -0.02, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.28, Pose = POSE.UmbraDecoyPeelHold, Easing = Enum.EasingStyle.Sine },
			{ t = 0.60, Pose = nil, Easing = Enum.EasingStyle.Sine },
		},
	}
	-- ...and mirrored, the LEFT arm swinging out, for a decoy on the left: each pose's sides swapped and mirrored, the
	-- camera's sideways part flipped.
	do
		local function swapSides(p)
			return { R = mirror(p.L), L = mirror(p.R) }
		end
		local src = Viewmodel.Clips.UmbraDecoyDouble
		local out = table.clone(src)
		out.Keys = {}
		for i, k in ipairs(src.Keys) do
			local c = table.clone(k)
			if k.Pose then c.Pose = swapSides(k.Pose) end
			if k.Cam then c.Cam = Vector3.new(-k.Cam.X, k.Cam.Y, k.Cam.Z) end
			out.Keys[i] = c
		end
		Viewmodel.Clips.UmbraDecoyDoubleL = out
	end

	-- TECHNIQUE, MARK: one arm, the LEFT (PlayShot("L", "UmbraMark")), played exactly -- the right stays free to fire.
	-- From wherever the arm is, the forearm flicks in to point (0.08, Quad Out: the mark lands), is held for the glance,
	-- and eases home to the live pose (a key with no Pose, as every ArmClip ends). Trigger = math.huge: see the header.
	Viewmodel.ArmClips.UmbraMark = {
		Trigger = math.huge,
		Keys = {
			{ t = 0.00, From = true },
			{ t = 0.08, Pose = POSE.UmbraMarkPoint, Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
			{ t = 0.20, Pose = POSE.UmbraMarkHold, Easing = Enum.EasingStyle.Sine },
			{ t = 0.36, Easing = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut },
		},
	}
end

-- ===== SKYRIDER (Zephyr v6 import, 2026-10-06) -- ADD-ONLY BLOCK, the Skyrider builder's ==================
-- ZEPHYR'S MOBILITY TECHNIQUE, Skyrider (it replaces Gust Jump): YOUR ARMS on the bird of wind. The showcase's first-
-- person rider (blender_scripts/zephyr/spring/skyrider_bl.py FP_HANDS / FPL_KEYS / FPR_KEYS: the hands braced low and
-- forward on the bird's back; the gust's pull back and out, the thrust forward and down at the target, both hands
-- dropping low and wide so the cone reads, back up after the shove) on this rig:
--   SkyriderMount   the press: the forearms press in low as the wind gathers (0.10), shove down as the body hops
--                   (0.26), then come to REST forward on the bird's neck (0.60) -- the brace, held for the whole ride.
--                   The brace's forearm tips sit ~31 degrees under the centre, either side of it (in frame at FOV
--                   70-110, clear of the crosshair).
--   SkyriderGust    the flap (WindUp 0.2): the left hand pulls back and out (0.16), THRUSTS forward and down at the
--                   target on the launch (0.24, the Trigger, a small push of the eye), both drop low and wide (0.40)
--                   through the cone, and are back on the brace by 1.20.
--   SkyriderWobble  hit: the left hand is thrown out and up for balance (0.07), held, back on the brace by 0.75.
-- All three HOLD (the brace stays until ZephyrSkyrider lets go at the dismount, Viewmodel.Stop): a held two-arm clip
-- keeps IsPlaying() true, so the M1 waits while you ride -- the hands are on the bird. Glow = false: the bird lights
-- itself. The crouch / hop poses are Gust Jump's GustGather / GustPush values, copied (not referenced) so retiring
-- Gust Jump's poses can never break these. Played by ZephyrSkyrider (client). Authored by eye against the frame maths
-- above, NOT YET SEEN IN PLAY. EVERY NUMBER HERE IS A PROPOSAL.
do
	local BRACE = sym(arm(0.70, -1.35, -0.60, 16, 18, -12, -12))       -- forearms forward and low, on the bird's neck
	local CROUCH = sym(arm(1.10, -0.80, -0.35, 12, 40, -30, 28))       -- = POSE.GustGather
	local HOP = sym(arm(1.00, -2.30, -0.45, -35, 20, -10, 30))         -- = POSE.GustPush
	local PULL_L = mirror(arm(1.25, -1.15, -0.20, 38, -28, 20, 12))    -- the left hand back and out
	local THRUST_L = mirror(arm(0.45, -0.95, -1.10, 4, 6, -10, -26))   -- forward and down at the target
	local LOW = sym(arm(1.15, -1.85, -0.55, 0, 26, -10, 0))            -- both low and wide: the cone reads
	local BALANCE_L = mirror(arm(1.55, -0.55, -0.35, 58, -55, 30, 0))  -- thrown out and up
	Viewmodel.Clips.SkyriderMount = {
		Trigger = 0.44, Hold = true, RestartGuard = 0.6, Rate = 30, Glow = false,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.10, Pose = CROUCH, Cam = Vector3.new(0, -0.08, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.26, Pose = HOP, Cam = Vector3.new(0, 0.12, 0), Easing = Enum.EasingStyle.Quint },
			{ t = 0.60, Pose = BRACE, Cam = Vector3.new(0, -0.10, 0), Easing = Enum.EasingStyle.Back },
			{ t = 0.90, Pose = BRACE, Easing = Enum.EasingStyle.Sine },
		},
	}
	Viewmodel.Clips.SkyriderGust = {
		Trigger = 0.24, Hold = true, RestartGuard = 0.5, Rate = 40, Glow = false,
		Keys = {
			{ t = 0.00, Pose = BRACE },
			{ t = 0.16, Pose = pair(BRACE.R, PULL_L), Cam = Vector3.new(0, 0.03, 0.04), Easing = Enum.EasingStyle.Quad },
			{ t = 0.24, Pose = pair(BRACE.R, THRUST_L), Cam = Vector3.new(0, -0.06, -0.15), Easing = Enum.EasingStyle.Quint },
			{ t = 0.40, Pose = LOW, Cam = Vector3.new(0, -0.04, -0.06), Easing = Enum.EasingStyle.Sine },
			{ t = 0.85, Pose = LOW },
			{ t = 1.20, Pose = BRACE, Easing = Enum.EasingStyle.Sine },
		},
	}
	Viewmodel.Clips.SkyriderWobble = {
		Trigger = 0.07, Hold = true, RestartGuard = 0.3, Rate = 40, Glow = false,
		Keys = {
			{ t = 0.00, Pose = BRACE },
			{ t = 0.07, Pose = pair(BRACE.R, BALANCE_L), Cam = Vector3.new(0.05, 0.06, 0), Easing = Enum.EasingStyle.Quad },
			{ t = 0.40, Pose = pair(BRACE.R, BALANCE_L) },
			{ t = 0.75, Pose = BRACE, Easing = Enum.EasingStyle.Sine },
		},
	}
end
-- ===== end SKYRIDER =========================================================================================

-- ===== UPDRAFT (Zephyr v6 import, 2026-10-07) -- ADD-ONLY BLOCK, the Updraft builder's =========================
-- ZEPHYR'S PASSIVE, Updraft: YOUR ARMS through the showcase's jump (blender_scripts/zephyr/spring/updraft_bl.py FPK,
-- "hands out, catching the air"). Clip time = showcase time + 0.30 (ZephyrUpdraft.Tuning.Demo.ClipOffset), the same
-- clock as CastPose.Clips.UpdraftJump: the rest (0.06), the dip (0.23: both hands swung down and back, out of the
-- frame, the eye dropping), the push (0.39: flung up and forward into view), RIDING (0.62 / 0.82: out wide and low,
-- palms riding the air), the wind-up (0.948: the right hand cocked back up and out, the left reaching at the target),
-- THE FLICK (0.995: the right snaps forward and down at the dummy, the left pulled back), the follow-through across the
-- body (1.16), riding again (1.335), the fall (1.50: higher and wider), the landing (1.818: low and forward, the eye
-- dropping with the squash), back to where the arms were (2.398). Played ONLY by ZephyrUpdraft.Demo (with its clock):
-- a live jump never plays it, since a two-arm clip holds the M1 off while it runs. Glow = false: the tell lights itself.
-- Authored by eye against the frame maths above, NOT YET SEEN IN PLAY. EVERY NUMBER HERE IS A PROPOSAL.
do
	local DIP = sym(arm(1.00, -2.15, -0.30, -30, 22, -10, 20))         -- swung down and back, under the frame
	local UPF = sym(arm(0.85, -0.70, -0.85, 76, 8, -10, -16))          -- flung up and forward, high in front
	local RIDE = sym(arm(1.40, -1.40, -0.55, 18, -12, -32, -14))       -- out wide and low, palms riding the air
	local WIND_R = arm(1.45, -0.80, -0.20, 62, -24, -22, 30)           -- the right hand cocked back up and out
	local REACH_L = mirror(arm(0.60, -0.95, -1.05, 22, 10, -10, -10))  -- the left reaching at the target
	local FLICK_R = arm(0.40, -0.85, -1.15, 8, 14, -10, -40)           -- THE FLICK: forward and down at the dummy
	local PULL_L = mirror(arm(1.35, -1.30, -0.30, 18, -22, -22, 0))    -- the off-hand pulled back, a counterweight
	local FOLLOW_R = arm(0.05, -1.25, -1.05, -5, 32, -10, -45)         -- the follow-through across the body
	local FALL = sym(arm(1.45, -1.15, -0.45, 36, -16, -26, -6))        -- higher and wider for the balance
	local LAND = sym(arm(0.85, -1.55, -0.85, 12, 20, -10, 0))          -- low and forward as the body squashes
	local S, Q5, C3, BK = Enum.EasingStyle.Sine, Enum.EasingStyle.Quint, Enum.EasingStyle.Cubic, Enum.EasingStyle.Back
	Viewmodel.Clips.UpdraftJump = {
		Trigger = 0.30, Rate = 30, Glow = false,
		Keys = {
			{ t = 0.00, Pose = nil },
			{ t = 0.06, Pose = nil },
			{ t = 0.23, Pose = DIP, Cam = Vector3.new(0, -0.14, 0), Easing = S },
			{ t = 0.39, Pose = UPF, Cam = Vector3.new(0, 0.06, 0), Easing = Q5 },
			{ t = 0.62, Pose = RIDE, Easing = S },
			{ t = 0.82, Pose = RIDE, Easing = S },
			{ t = 0.948, Pose = pair(WIND_R, REACH_L), Easing = S },
			{ t = 0.995, Pose = pair(FLICK_R, PULL_L), Cam = Vector3.new(0, -0.03, -0.08), Easing = Q5 },
			{ t = 1.16, Pose = pair(FOLLOW_R, PULL_L), Easing = BK },
			{ t = 1.335, Pose = RIDE, Easing = S },
			{ t = 1.50, Pose = FALL, Easing = S },
			{ t = 1.818, Pose = LAND, Cam = Vector3.new(0, -0.16, 0), Easing = C3 },
			{ t = 2.398, Pose = nil, Easing = S },
		},
	}
end
-- ===== end UPDRAFT ==========================================================================================

----------------------------------------------------------------------------------------------------
-- rig construction
----------------------------------------------------------------------------------------------------
local state = {
	model = nil, arms = nil, character = nil, humanoid = nil,
	stateName = "Idle", blend = nil,
	clip = nil, clipStart = 0, clipFrom = nil,
	phase = 0, cycleAmt = 0,
	swayX = 0, swayY = 0, lastCamCF = nil,
	camOffset = Vector3.new(), posture = Vector3.new(),
	move = { Sprint = false, Crouch = false, Sliding = false, SlideTime = 0, Speed = 0, Grounded = true,
		VerticalSpeed = 0 },
	slideFastUntil = 0,
	air = 0,
	shots = {}, shotW = { R = 0, L = 0 }, shown = {}, flash = { R = 0, L = 0 }, steady = { R = 0, L = 0 },
	vel = { R = {}, L = {} },      -- how fast each shown arm pose is moving, per channel per second (a Spline shot's start)
	glow = 0, glowTarget = 0,
	lampScale = 1, fill = Vector3.new(1, 1, 1), sunAmt = 0, sunDir = nil, keyLamp = nil, gapLamp = nil,
	-- Pyro: Ring of Fire's trace (SetTrace)
	-- Frostblade: the Naruto run's first-person weight (0..1, eased by FrostbladeKit; SetNaruto)
	naruto = 0,
	trace = false, traceCam = nil, traceYaw = 0, tracePitch = 0, traceDraw = nil,
	-- the third-person testing view: whether the rig is currently not being drawn
	hidden = false,
	-- an impact's camera punch (Viewmodel.Punch): when it landed and how hard, in studs
	punchAt = -1, punchAmp = 0,
	-- camera SHAKES (Viewmodel.Shake, 2026-09-25): { At, Amp, Decay, Ph } each, summed, dropped once spent
	shakes = {},
	-- the camera offset when the current clip began: what a Spline clip's Cam From key means
	clipCamFrom = nil,
	-- SetArmOffset's per-side functions (R, L), called every frame; nil = none
	armOffset = {},
}

--- THE THIRD-PERSON TESTING VIEW (FirstPersonController, V). Read off CameraMode for the same reason
--- PyroFX reads it: it is the one fact about the view that every client script already shares, so
--- there is nothing to wire up and nothing to keep in step.
---
--- The rig is NOT torn down for third person -- it stays built and stays animating, and this module
--- simply stops drawing it. Destroying it would leave state.clip set for good (only Update clears it
--- and Update returns early when the rig is gone), and SpellshotInput gates every M1 on IsPlaying().
local function thirdPerson()
	return player ~= nil and player.CameraMode ~= Enum.CameraMode.LockFirstPerson
end

--- The hand a local effect leaves from while the arms are not drawn: the real character's, which is
--- exactly the origin every OTHER character's effects already use. nil if there is no body to ask.
local function bodyHandCFrame(side)
	local c = state.character or player.Character
	if not c then return nil end
	local hand = c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
		or c:FindFirstChild(side == "L" and "Left Arm" or "Right Arm")
	return hand and hand.CFrame or nil
end

local function elementColours()
	local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
	local id = player:GetAttribute("Element") or Config.DefaultLoadout.Element
	local def = Config.Elements[id] or Config.Elements[Config.DefaultLoadout.Element]
	return def, id
end

--- The arm meshes live beside this module as a template Model. A running script cannot set
--- MeshId, so the arm is cloned rather than built.
local ARM_TEMPLATE = "ViewmodelArm4"   -- ArmTop, ArmBottom, ArmSideNeg, ArmSidePos, ArmInk, ArmShell

local function prep(p)
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	return p
end

--- Builds one arm: four lit tone meshes, the black outline hull, the cast point and the glow. The
--- arm is rigid, so every offset is computed once here and only the root moves per frame.
local function buildArm(parent, side)
	local m = Instance.new("Model")
	m.Name = side == 1 and "ArmR" or "ArmL"
	m.Parent = parent

	local a = { Model = m, Side = side, Pieces = {}, Shell = {} }
	local template = script.Parent:FindFirstChild(ARM_TEMPLATE)
	-- the mesh is centred on its own bounds, which run from ArmBack behind the elbow to the tip
	local centre = CFrame.new(0, 0, (C.ArmBack - C.ArmLength) * 0.5)

	-- The RoughnessMap lives on the template pieces (set once in Edit mode; clones carry it). A
	-- LocalScript is not allowed to write SurfaceAppearance maps, so this only repairs a template
	-- that lost it, and gives up quietly if it cannot.
	local function matte(piece)
		if piece:FindFirstChildOfClass("SurfaceAppearance") then return end
		pcall(function()
			local sa = Instance.new("SurfaceAppearance")
			sa.RoughnessMap = C.RoughnessMap
			sa.Parent = piece
		end)
	end

	local shellSrc = template and template:FindFirstChild("ArmShell")
	if shellSrc then
		-- Piece offsets are taken relative to the shell, whose centre is the box centre. The tone is
		-- chosen by WHERE a piece sits, not by its name: the FBX import mirrors X, so the piece
		-- called ArmSideNeg lands on +X. Which side faces INWARD depends on the arm: -X for the
		-- right, +X for the left.
		local ref = shellSrc.CFrame
		for _, src in ipairs(template:GetChildren()) do
			if src:IsA("MeshPart") and src ~= shellSrc then
				local rel = ref:ToObjectSpace(src.CFrame)
				local piece = prep(src:Clone())
				-- the face this piece IS, in arm space, so the light normalisation can ask how much sun reaches it
				local normal
				if src.Name == "ArmInk" then
					-- the hull: unlit black, single-sided so only its far side draws
					piece.Material = Enum.Material.Neon
					piece.Color = C.Ink
					piece.DoubleSided = false
				else
					if math.abs(rel.X) > 0.1 then
						piece.Color = (rel.X * side < 0) and C.SkinDark or C.SkinLight     -- inner : outer
						normal = Vector3.new(rel.X > 0 and 1 or -1, 0, 0)
					elseif rel.Y < -0.1 then
						piece.Color = C.SkinDark                                          -- underside
						normal = Vector3.new(0, -1, 0)
					else
						piece.Color = C.Skin                                              -- top and ends
						normal = Vector3.new(0, 1, 0)
					end
					matte(piece)
				end
				piece.Parent = m
				-- tone: the calibrated colour the piece was built with, kept so the light normalisation can scale
				-- it down and back without losing it. The ink hull has neither tone nor normal: it is unlit Neon
				-- black, and no amount of scene light reaches it.
				a.Pieces[#a.Pieces + 1] = { part = piece, cf = centre * rel, normal = normal,
					tone = normal and piece.Color or nil, top = normal ~= nil and normal.Y > 0.5 }
			end
		end
	else
		-- without the meshes the game still gets arms: a plain block of the same section
		warn("[Viewmodel] IceMagic." .. ARM_TEMPLATE .. " is missing; arms fall back to a block")
		local block = prep(Instance.new("Part"))
		block.Size = Vector3.new(C.ArmWidth, C.ArmHeight, C.ArmLength + C.ArmBack)
		block.Color = C.Skin
		block.Parent = m
		a.Pieces[1] = { part = block, cf = centre, tone = C.Skin, normal = Vector3.new(0, 1, 0), top = true }
	end

	-- the cast point and glow ride the first piece; CastPoint is re-aimed in world space per frame
	local carrier = a.Pieces[1].part
	local att = Instance.new("Attachment")
	att.Name = "CastPoint"
	att.Parent = carrier
	a.CastPoint = att

	local light = Instance.new("PointLight")
	light.Name = "CastGlow"
	light.Range = 5
	light.Brightness = 0
	light.Shadows = false
	light.Parent = carrier
	a.Glow = light

	return a
end

function Viewmodel.Build(character)
	Viewmodel.Destroy()
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local def = elementColours()

	local model = Instance.new("Model")
	model.Name = "SpellshotViewmodel"

	local arms = { R = buildArm(model, 1), L = buildArm(model, -1) }

	local function lamp(name, range, brightness)
		local holder = Instance.new("Part")
		holder.Name = name
		holder.Size = Vector3.new(0.05, 0.05, 0.05)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Parent = model
		local light = Instance.new("PointLight")
		light.Range = range
		light.Brightness = brightness
		light.Color = C.KeyLightColor
		light.Shadows = false
		light.Parent = holder
		return holder
	end
	state.keyLight = lamp("KeyLight", C.KeyLightRange, C.KeyLightBrightness)
	state.gapLight = lamp("GapLight", C.GapLightRange, C.GapLightBrightness)
	state.keyLamp = state.keyLight:FindFirstChildOfClass("PointLight")
	state.gapLamp = state.gapLight:FindFirstChildOfClass("PointLight")
	state.lampScale, state.lampShown = -1, nil   -- unset: the first Update snaps it to the scene instead of fading in

	model.Parent = camera

	state.model = model
	-- 2026-10-28 (the owner: "when i spawn in with TP on, the first person hands show up too"): a fresh rig is drawn,
	-- but state.hidden still said the OLD rig was hidden, so Update saw no change and never hid the new one. Forget it:
	-- the next Update writes the right transparency for whichever view is on.
	state.hidden = nil
	state.arms = arms
	state.character = character
	state.humanoid = character and character:FindFirstChildOfClass("Humanoid")
	state.stateName = "Idle"
	state.blend = { R = table.clone(POSE.Idle.R), L = table.clone(POSE.Idle.L) }
	state.clip, state.clipFrom = nil, nil
	state.camOffset = Vector3.new()
	state.glow, state.glowTarget = 0, 0
	for _, a in pairs(arms) do a.Glow.Color = def.Light end
	return model
end

function Viewmodel.Destroy()
	state.dressKey, state.dressT = nil, nil   -- (2026-10-29) a fresh rig dresses its arms again
	if state.model then state.model:Destroy() end
	if state.humanoid and state.humanoid.Parent then
		state.humanoid.CameraOffset = Vector3.new()
	end
	state.model, state.arms, state.keyLight, state.gapLight = nil, nil, nil, nil
	state.keyLamp, state.gapLamp = nil, nil
	state.character, state.humanoid = nil, nil
	state.clip, state.clipFrom, state.clipCamFrom = nil, nil, nil
	-- ...and Ring of Fire's trace (review r1, 2026-09-24): a body torn down mid-draw must not hand the trace on to the
	-- next one, which would refuse every M1, Detonate and Lash (Tracing) until a Ring of Fire was drawn to its end.
	-- (AbilityFX also ends it at DrawTime whatever became of the body; this is the rig's own guarantee.)
	state.trace, state.traceCam, state.traceDraw = false, nil, nil
	-- an arm offset belongs to the rig it was set on: a respawn (Build calls this first) starts the new arms clean, and
	-- whatever set it -- a Boulder Shot hold dropped by the death -- cannot leave the next life's arms sagging
	state.armOffset = {}
	-- ...and so do the camera shakes (2026-09-25): a death mid-slam does not carry the rumble into the next life
	state.shakes = {}
	-- ...and a HELD shot likewise (round 2: Scorching Lash's grip), which would otherwise never end on the new arms
	for side, sh in pairs(state.shots) do
		if sh.Clip.Hold then state.shots[side] = nil end
	end
end

function Viewmodel.IsBuilt()
	return state.model ~= nil and state.model.Parent ~= nil
end

--- Retint the cast glow for a loadout change mid-session. The arms themselves never change
--- colour -- they are skin, whatever element you are playing.
function Viewmodel.Refresh()
	if not Viewmodel.IsBuilt() then return end
	local def = elementColours()
	for _, a in pairs(state.arms) do a.Glow.Color = def.Light end
end

----------------------------------------------------------------------------------------------------
-- input state
----------------------------------------------------------------------------------------------------
--- Fed by MovementController from its OWN key state and its OWN slide timer -- not from the
--- replicated MoveState attribute. That is the point: the arms react on the keypress, and this
--- module never has to agree with what the server thinks is happening.
function Viewmodel.SetMovement(m)
	local s = state.move
	s.Sprint = m.Sprint or false
	s.Crouch = m.Crouch or false
	s.Sliding = m.Sliding or false
	s.SlideTime = m.SlideTime or 0
	s.Speed = m.Speed or 0
	s.Grounded = m.Grounded ~= false
	s.VerticalSpeed = m.VerticalSpeed or 0
end

--- Posture offset (the crouch/slide camera dip), summed with the clip's own camera punch here so
--- the two never overwrite each other on Humanoid.CameraOffset.
function Viewmodel.SetPosture(offset)
	state.posture = offset or Vector3.new()
end

--- Fingertip glow, 0..1. Casts drive this up; it decays on its own.
function Viewmodel.SetGlow(v)
	state.glowTarget = math.clamp(v or 0, 0, 1)
end

--- A live OFFSET on one arm (2026-09-23, for Boulder Shot: the arm dipping under each stone that lands on the rock, and
--- trembling under its weight at full charge -- the showcase's own dips and tremble, which are effects, not keys).
--- `fn()` is called once a frame and returns a PARTIAL delta over the arm's pose fields -- X, Y, Z in studs, Pitch,
--- Yaw, Roll, Wrist in degrees, any it leaves out 0 -- or nil for none this frame. It is added to that arm last: on
--- top of the clip or state pose, the blend and the cycle, just before the arm is placed, so GetFistCFrame and the
--- muzzle both see it. `fn` nil clears it; one per side, a second call replaces the first. `side` is "R" or "L".
--- Display only: a shot starting on that arm departs from the animation, not from the offset (state.shown never
--- carries it), and the offset goes on riding on top, so it is never counted twice. Destroy clears both sides -- and
--- Build calls Destroy, so a respawn starts clean. An fn that errors is dropped with a warning instead of taking the
--- arms down every frame after it. It must not yield (it runs inside the render step).
function Viewmodel.SetArmOffset(side, fn)
	if fn ~= nil and type(fn) ~= "function" then
		error("Viewmodel.SetArmOffset: fn must be a function or nil, got " .. typeof(fn), 2)
	end
	state.armOffset[side == "L" and "L" or "R"] = fn
end

----------------------------------------------------------------------------------------------------
-- playback
----------------------------------------------------------------------------------------------------
--- A camera PUNCH for an impact beat (the Terra kit's heaviest hits): `amount` studs of dip that rebounds once and
--- is gone in about a third of a second -- a punch, never a sustained shake. It rides the clip punch's own path,
--- so the Camera Shake setting scales it and Reduce Flashing removes it outright. A bigger punch landing inside a
--- smaller one takes over; a smaller one does not cut a bigger one short.
function Viewmodel.Punch(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	local pt = os.clock() - state.punchAt
	local left = (pt >= 0 and pt < 0.32) and state.punchAmp * math.exp(-pt * 13) or 0
	if amount >= left then
		state.punchAt = os.clock()
		state.punchAmp = amount
	end
end

--- A camera SHAKE (Aftershock, 2026-09-25): `amp` studs of jitter on all three axes that dies away as
--- amp * exp(-age / decay) -- the slam's hard shake (Tuning.Aftershock Shake 0.5 / ShakeDecay 0.22), the ring's longer
--- rumble (0.10 / 0.45), a strike's jolt. The showcase's own camera shake (aftershock_bl.py shake()): sines at 61, 53
--- and 71 rad/s on x, depth and height, the depth at 0.8, each shake on its own phase. Where Punch is one dip that
--- rebounds, this keeps shaking for as long as it lasts, and SEVERAL ADD UP (the rumble lands on the slam's tail). It is
--- summed into Punch's own term, so the Camera Shake setting scales it and Reduce Flashing removes it outright, and it
--- runs on os.clock, so it keeps shaking through a hitpause that has frozen the clip. TRANSLATION ONLY: the showcase
--- also rolls and pitches its camera, but a pitch here would move the aim, so none is written.
local MAX_SHAKES = 8
function Viewmodel.Shake(amp, decay)
	amp, decay = tonumber(amp) or 0, tonumber(decay) or 0
	if amp <= 0 or decay <= 0 then return end
	local list = state.shakes
	if #list >= MAX_SHAKES then table.remove(list, 1) end      -- the oldest has spent the most
	local now = os.clock()
	list[#list + 1] = { At = now, Amp = math.min(amp, 2), Decay = math.min(decay, 3), Ph = (now * 7) % (2 * math.pi) }
end

--- `clock` (optional): a function giving the clip's time instead of the seconds since this call -- Cross-Slash Dash's
--- held charge holds its wind-up for as long as the key is held (ZephyrFX.CrossSlashTime); Boulder Shot's windup is
--- clocked in seconds since the button went down. nil when it has none.
function Viewmodel.Play(clipName, clock)
	local clip = Viewmodel.Clips[clipName]
	if not clip then return nil end
	-- RestartGuard: the same clip asked for again this soon keeps running instead of starting over
	if clip.RestartGuard and state.clip == clip and os.clock() - state.clipStart < clip.RestartGuard then
		return clip.Trigger
	end
	-- a Wind Blade shot that has let go and is only holding for its hand's next stroke (YieldHeld) gives the arm to the
	-- clip; state.blend is that shot's pose, so the clip still departs from where the arm is
	for side, sh in pairs(state.shots) do
		if sh.Released and sh.Clip.YieldHeld then state.shots[side] = nil end
	end
	-- the clip departs from wherever the arms actually are, so a cast never snaps
	state.clipFrom = { R = table.clone(state.blend.R), L = table.clone(state.blend.L) }
	state.clipCamFrom = state.camOffset             -- ...and a Spline clip's camera track from wherever the camera is
	state.clip = clip
	state.clipStart = os.clock()
	state.clipClock = clock
	state.glowTarget = clip.Glow == false and 0 or 1
	return clip.Trigger
end

--- Whether an arm is partway through a shot that has not let go yet. Playing another shot on that arm would release
--- it at once (PlayShot below), so a swing that fires nothing -- Deflect Gust's -- asks first and uses the other arm.
function Viewmodel.ShotPending(side)
	local sh = state.shots[side]
	return sh ~= nil and sh.OnRelease ~= nil and not sh.Released
end

--- Whether an arm is still playing a shot of `clipName`: false once that shot is over, or once another shot or a clip
--- has taken the arm (a held Wind Blade shot gives way to a clip, YieldHeld in Play above). The Wind Blade asks it
--- before it chains a stroke onto a hand's hold (SpellshotInput).
function Viewmodel.ShotPlaying(side, clipName)
	local sh = state.shots[side]
	return sh ~= nil and sh.Clip == Viewmodel.ArmClips[clipName]
end

--- Play a one-arm clip (the M1). `onRelease(side)` is called on the exact rendered frame the clip
--- reaches its Trigger (full extension), after the arms have been placed for that frame -- so the
--- shard leaves a hand that is really at full extension, and a frame hitch cannot make it late.
--- (A task.delay timer can: one resumed 130 ms late in testing, with the arm already on its way
--- back.) If the rig is not built, the release fires straight away so a shot is never lost.
function Viewmodel.PlayShot(side, clipName, onRelease)
	local clip = Viewmodel.ArmClips[clipName]
	if not clip then return end
	if not Viewmodel.IsBuilt() then
		if onRelease then task.spawn(onRelease, side) end
		return
	end
	local prev = state.shots[side]
	if prev and prev.OnRelease and not prev.Released then task.spawn(prev.OnRelease, side) end
	state.shots[side] = { Clip = clip, Start = os.clock(), OnRelease = onRelease,
		From = table.clone(state.shown[side] or state.blend[side]),
		Vel = clip.Spline and table.clone(state.vel[side]) or nil }
end

--- Let go of a HELD shot (ArmClips with Hold, round 2: Scorching Lash's grip) -- only if that arm is still on it; the
--- arm eases back to whatever the rest of the rig is doing. Another shot on that arm replaces it without this.
function Viewmodel.StopShot(side, clipName)
	local sh = state.shots[side]
	if sh and sh.Clip == Viewmodel.ArmClips[clipName] then state.shots[side] = nil end
end

function Viewmodel.Stop()
	state.clip = nil
	state.glowTarget = 0
end

function Viewmodel.IsPlaying()
	return state.clip ~= nil
end

--- Which continuous state raw input says we are in. Order matters: a slide beats a sprint beats a
--- crouch, because that is the order they override each other as inputs.
local function currentState()
	local m = state.move
	if m.Sliding then return "Slide" end
	if m.Crouch then return "Crouch" end
	if m.Sprint and m.Speed > 4 then return "Sprint" end
	if m.Speed > 2 then return "Walk" end
	return "Idle"
end

local FIELDS = { "X", "Y", "Z", "Pitch", "Yaw", "Roll", "Wrist" }

----------------------------------------------------------------------------------------------------
-- Pyro hooks (Build Prompt #21)
----------------------------------------------------------------------------------------------------

--- Ring of Fire's draw: while on, the right arm points down the crosshair, and its fist loops once round over
--- `drawTime` seconds from the os.clock() moment `drawStart` -- the hand drawing the circle by itself.
function Viewmodel.SetTrace(on, drawStart, drawTime)
	state.trace = on and true or false
	state.traceCam = nil
	state.traceYaw, state.tracePitch = 0, 0
	state.traceDraw = (on and drawStart and drawTime) and { Start = drawStart, Time = drawTime } or nil
end

--- Whether the right arm is busy drawing Ring of Fire's circle (an M1 waits for it).
function Viewmodel.Tracing()
	return state.trace
end

--- Cryo's Frostblade: Cold Momentum's Naruto run in first person, as a weight 0..1 that FrostbladeKit.Naruto eases and
--- feeds every frame. The arms blend to POSE.NarutoRun, the stride stops pumping, and the view leans in as the body's
--- head does in the run (0.2 studs). A clip or a shot still takes the arms over it, as it does any other state.
function Viewmodel.SetNaruto(w)
	state.naruto = math.clamp(w or 0, 0, 1)
end

--- Whether an arm is playing a one-arm shot of any kind (the run's hand kunai step out of a throwing hand).
function Viewmodel.ArmBusy(side)
	return state.shots[side] ~= nil
end

--- The world frame of an arm's root (its elbow end), for what rides the arm: the Fireball charge on the fist.
--- nil when the rig is not built.
function Viewmodel.GetArmCFrame(side)
	-- same as GetMuzzleCFrame: in third person what rides the arm has to ride the body's arm. The hand
	-- rather than the elbow, which is close enough for an effect that was sitting on the fist anyway.
	if thirdPerson() then return bodyHandCFrame(side) end
	if not Viewmodel.IsBuilt() then return nil end
	return state.arms[side == "L" and "L" or "R"].CastPoint.WorldCFrame * CFrame.new(0, 0, C.ArmLength + 0.05)
end

--- The world frame of an arm's TIP -- the fist -- as drawn this frame (2026-09-23, for Boulder Shot's held rock). Its
--- position is the arm's pose frame (camera * (x, y, z) * (pitch, yaw, roll) * the wrist tip, with the sway solveArm
--- applies and any SetArmOffset) carried ArmLength along the forearm; its rotation is that same frame, so LookVector
--- is the forearm's direction, elbow to tip, and UpVector the arm's +Y (the top face). It is GetArmCFrame's frame moved
--- to the other end of the forearm: in first person GetArmCFrame IS the pose frame at the elbow (its CastPoint maths
--- cancels out), so this is GetArmCFrame(side) * CFrame.new(0, 0, -ArmLength), and CastPoint sits 0.05 past it. Unlike
--- GetArmCFrame it does not fall back to the body's hand: nil in the third-person view, when the rig is not built, or
--- before the first frame has placed it. "This frame" means as of the last Viewmodel.Update, which runs at
--- RenderPriority Camera + 2 (FirstPersonController): read it from a later step and it is the arm on screen.
function Viewmodel.GetFistCFrame(side)
	if thirdPerson() or not Viewmodel.IsBuilt() then return nil end
	local root = state.arms[side == "L" and "L" or "R"].Root
	return root and root * CFrame.new(0, 0, -C.ArmLength) or nil
end

--- The name of the two-arm clip playing, if any.
function Viewmodel.CurrentClip()
	if not state.clip then return nil end
	for name, clip in pairs(Viewmodel.Clips) do
		if clip == state.clip then return name end
	end
	return nil
end

--- The trace pose for this frame: TraceAim led into the camera's own turn -- the arm swings ahead of the
--- sweep and rolls with it (the rates are smoothed, a single frame's turn is noise).
local function traceArm(camCF, dt)
	local a = table.clone(POSE.TraceAim.R)
	local last = state.traceCam
	state.traceCam = camCF
	if last and dt > 0 then
		local rx, ry = last:ToObjectSpace(camCF):ToEulerAnglesYXZ()
		local k = math.clamp(12 * dt, 0, 1)
		state.traceYaw += (math.deg(ry) / dt - state.traceYaw) * k
		state.tracePitch += (math.deg(rx) / dt - state.tracePitch) * k
	end
	a.X -= math.clamp(0.0011 * state.traceYaw, -0.16, 0.16)
	a.Y -= math.clamp(0.0008 * state.tracePitch, -0.10, 0.10)
	a.Roll += math.clamp(0.06 * state.traceYaw, -12, 12)
	local draw = state.traceDraw
	if draw then
		-- one loop of the fist: out to the right, down, and back round to where it began
		local ang = 2 * math.pi * math.clamp((os.clock() - draw.Start) / draw.Time, 0, 1)
		a.X += 0.14 * math.sin(ang)
		a.Y += 0.10 * (math.cos(ang) - 1)
		a.Roll += 10 * math.sin(ang)
	end
	return a
end

local function lerpArm(a, b, t)
	local out = {}
	for _, k in ipairs(FIELDS) do
		local av, bv = a[k] or 0, b[k] or 0
		out[k] = av + (bv - av) * t
	end
	return out
end

--- A per-arm delta with another added on top (either may be missing a field, or be nil).
local function addDelta(d, e)
	local out = {}
	if d then for k, v in pairs(d) do out[k] = v end end
	for k, v in pairs(e) do out[k] = (out[k] or 0) + v end
	return out
end

--- A delta scaled toward nothing (s = 0 removes it).
local function scaleDelta(d, s)
	if not d or s >= 0.999 then return d end
	local out = {}
	for k, v in pairs(d) do out[k] = v * s end
	return out
end

local function samplePose(clip, t, fallback)
	local keys = clip.Keys
	local function poseAt(k) return k.Pose or fallback end
	if t <= keys[1].t then return poseAt(keys[1]), poseAt(keys[1]), 0, keys[1] end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local span = math.max(1e-4, b.t - a.t)
			return poseAt(a), poseAt(b), (t - a.t) / span, b, a
		end
	end
	local last = keys[#keys]
	return poseAt(last), poseAt(last), 0, last
end

-- SPLINE arm clips (the Wind Blade slash, 2026-09-16). An eased step per key stops the arm dead on every key it eases
-- into and starts it again at full speed on the next frame, and it had to reach the stroke's first pose from wherever
-- the arm was in three frames -- from the idle that is a jump up and a reversal straight into the slash. A Spline clip
-- is two smooth parts added together instead:
--   the STROKE  one cubic Hermite curve through the posed keys, each key's slope the choreography's own (a quadratic
--               through it and its neighbours, one-sided at the two ends of the run, so the approved stroke is followed
--               as it was sampled), handing back to the live pose at rest on the last key. Before its first posed key
--               it eases in from rest to that key's slope, so it is already moving when it gets there
--   the CATCH-UP  the gap between where the arm was when the shot took it and where the stroke starts, and how fast the
--               arm was already going, both let go smoothly over the clip's Catch seconds
-- So the arm leaves exactly where it was, at the speed it was going, and is on the choreography from Catch on. A chained
-- stroke starts close to its own first pose and barely needs it; a stroke from rest folds the gap into the slash
-- instead of snapping to it. (Inside Catch the release pose is short of the choreography's by what is left of the gap:
-- the blade leaves from the hand wherever it is.)
local SPLINE_MAX_MOVE, SPLINE_MAX_TURN = 10, 1200       -- a carried start speed is clamped to this (studs/s, deg/s)

local function quadSlope(ta, pa, tb, pb, tc, pc, t)
	local da = (2 * t - tb - tc) / ((ta - tb) * (ta - tc))
	local db = (2 * t - ta - tc) / ((tb - ta) * (tb - tc))
	local dc = (2 * t - ta - tb) / ((tc - ta) * (tc - tb))
	local out = {}
	for _, f in ipairs(FIELDS) do
		out[f] = da * (pa[f] or 0) + db * (pb[f] or 0) + dc * (pc[f] or 0)
	end
	return out
end

--- The posed keys' slopes for one side, worked out once per clip.
local function splineSlopes(clip, side)
	clip.SplineSlopes = clip.SplineSlopes or {}
	local out = clip.SplineSlopes[side]
	if out then return out end
	out = {}
	local keys = clip.Keys
	local function posed(i) return keys[i] and keys[i].Pose ~= nil end
	for i, k in ipairs(keys) do
		if k.Pose then
			local a, b, c
			if posed(i - 1) and posed(i + 1) then a, b, c = i - 1, i, i + 1
			elseif posed(i + 1) and posed(i + 2) then a, b, c = i, i + 1, i + 2
			elseif posed(i - 1) and posed(i - 2) then a, b, c = i - 2, i - 1, i
			end
			if a then
				out[i] = quadSlope(keys[a].t, keys[a].Pose[side], keys[b].t, keys[b].Pose[side], keys[c].t, keys[c].Pose[side], k.t)
			end
		end
	end
	clip.SplineSlopes[side] = out
	return out
end

-- `fields` (optional) are the channels to blend: an arm's seven by default, a camera offset's three for a spline clip
local function hermite(p0, m0, p1, m1, u, h, fields)
	local u2 = u * u
	local u3 = u2 * u
	local c0, c1, c2, c3 = 2 * u3 - 3 * u2 + 1, (u3 - 2 * u2 + u) * h, -2 * u3 + 3 * u2, (u3 - u2) * h
	local out = {}
	for _, f in ipairs(fields or FIELDS) do
		out[f] = c0 * (p0[f] or 0) + c1 * (m0 and m0[f] or 0) + c2 * (p1[f] or 0) + c3 * (m1 and m1[f] or 0)
	end
	return out
end

--- The stroke alone, `t` clip seconds in (see above). `live` is the state pose the last key hands back to.
local function splineStroke(clip, t, side, live)
	local keys = clip.Keys
	local slopes = splineSlopes(clip, side)
	local first = 1
	while keys[first] and not keys[first].Pose do first += 1 end
	local k1 = keys[first]
	if t < k1.t then
		-- easing in from rest to the first posed key's own slope: p1 + m1 (t^2 - t1^2) / (2 t1)
		local p, m, t1 = k1.Pose[side], slopes[first], math.max(1e-4, k1.t)
		local out = {}
		for _, f in ipairs(FIELDS) do
			out[f] = (p[f] or 0) + (m and m[f] or 0) * (t * t - t1 * t1) / (2 * t1)
		end
		return out
	end
	local i = first
	while i < #keys - 1 and t > keys[i + 1].t do i += 1 end
	local a, b = keys[i], keys[i + 1]
	local h = math.max(1e-4, b.t - a.t)
	return hermite(a.Pose[side], slopes[i], b.Pose and b.Pose[side] or live, b.Pose and slopes[i + 1] or nil,
		math.clamp((t - a.t) / h, 0, 1), h)
end

--- One arm's pose `t` (clip seconds) into a Spline shot: the stroke plus what is left of the catch-up.
local function splineShot(sh, t, side, live, scale)
	local clip = sh.Clip
	local pose = splineStroke(clip, t, side, live)
	local catch = clip.Catch or 0.1
	if not sh.Gap then
		-- the gap to the stroke's start, and the arm's own speed in clip seconds (clamped against a frame that jumped)
		local start = splineStroke(clip, 0, side, live)
		sh.Gap, sh.GapVel = {}, {}
		for _, f in ipairs(FIELDS) do
			local lim = (f == "X" or f == "Y" or f == "Z") and SPLINE_MAX_MOVE or SPLINE_MAX_TURN
			sh.Gap[f] = (sh.From[f] or 0) - (start[f] or 0)
			sh.GapVel[f] = math.clamp(((sh.Vel and sh.Vel[f]) or 0) / scale, -lim, lim)
		end
	end
	if t >= catch then return pose end
	local u = t / catch
	local u2 = u * u
	local u3 = u2 * u
	local w, g = 2 * u3 - 3 * u2 + 1, (u3 - 2 * u2 + u) * catch
	for _, f in ipairs(FIELDS) do
		pose[f] = (pose[f] or 0) + sh.Gap[f] * w + sh.GapVel[f] * g
	end
	return pose
end

--- M1, Wind Blade's own clips: ArmClips.WindSlashDown / WindSlashUp. v6 (2026-10-07, the owner: the moves must be the
--- Blender showcase's): the first-person GUARD AND WRIST FLICK of blender_scripts/zephyr/spring/wind_blade_bl.py
--- (FP_GUARD, pulses(), caster_pose(fp = true): the flick at 0.72 of the third person's, the wrist at 0.55) replaces the
--- 2026-09-16 slash (WindBladeDown / WindBladeUp above, left as they were). Both forearms come up from the bottom corners
--- angled up and in at the crosshair -- the kit's FP_GUARD hands (+-1.38, 1.85, 3.82), framed for this rig at FOV 90
--- where the kit's FOV-70 frame has them, ~37% out and ~36% down from the centre -- and a blade is a small WRIST FLICK:
--- the hand cocks up and back (0.03 s), snaps down, in and forward onto the release (the Trigger, 0.06 s), overshoots
--- (0.105 s) and is back on the guard by 0.28 s. The arm then HOLDS the guard to HoldUntil (SpellshotInput's chaining
--- window, unchanged) and goes home to the live pose by HomeAt (the kit eases FP_GUARD -> FP_LOW over ~0.65 s). The hand
--- path is the kit's (D_COCK / D_FLICK x its pulses, x 0.85 for this rig's nearer hands), moved as the elbow; the kit's
--- wrist flex is the Wrist channel at 0.65 x (this rig's wrist tips the whole forearm: the same tip travel). Keys sampled
--- from pulses() every 15 ms. Down and Up are the same flick (the kit has no up-stroke; SpellshotInput still alternates
--- the names, so they are two tables). A clip that takes the arms takes a held arm too (YieldHeld).
do
	local HOLD_UNTIL, HOME_AT = 1.05, 1.60
	local GUARD = sym(arm(1.149, -1.170, -0.263, 46.0, 23.0, -11.8, 11.9))
	local function flick()
		return {
			Trigger = 0.06, Spline = true, Catch = 0.10, HoldUntil = HOLD_UNTIL, HomeAt = HOME_AT, YieldHeld = true,
			Keys = {
				{ t = 0.000, From = true },
				{ t = 0.015, Pose = sym(arm(1.157, -1.129, -0.245, 46.0, 23.0, -11.8, 18.3)) },
				{ t = 0.030, Pose = sym(arm(1.166, -1.087, -0.226, 46.0, 23.0, -11.8, 24.6)) },   -- the cock
				{ t = 0.045, Pose = sym(arm(1.113, -1.265, -0.340, 46.0, 23.0, -11.8, 3.2)) },    -- the snap
				{ t = 0.060, Pose = sym(arm(1.111, -1.271, -0.344, 46.0, 23.0, -11.8, 2.5)) },    -- RELEASE
				{ t = 0.075, Pose = sym(arm(1.106, -1.286, -0.356, 46.0, 23.0, -11.8, 0.9)) },
				{ t = 0.090, Pose = sym(arm(1.103, -1.292, -0.361, 46.0, 23.0, -11.8, 0.2)) },
				{ t = 0.105, Pose = sym(arm(1.103, -1.294, -0.362, 46.0, 23.0, -11.8, 0.0)) },    -- the overshoot
				{ t = 0.120, Pose = sym(arm(1.103, -1.293, -0.361, 46.0, 23.0, -11.8, 0.2)) },
				{ t = 0.150, Pose = sym(arm(1.109, -1.277, -0.348, 46.0, 23.0, -11.8, 1.7)) },
				{ t = 0.180, Pose = sym(arm(1.120, -1.248, -0.326, 46.0, 23.0, -11.8, 4.4)) },
				{ t = 0.210, Pose = sym(arm(1.132, -1.216, -0.300, 46.0, 23.0, -11.8, 7.5)) },
				{ t = 0.240, Pose = sym(arm(1.143, -1.187, -0.277, 46.0, 23.0, -11.8, 10.3)) },
				{ t = 0.280, Pose = GUARD },                                                     -- back on the guard
				{ t = 0.450, Pose = GUARD },
				{ t = HOLD_UNTIL, Pose = GUARD },
				{ t = HOME_AT },
			},
		}
	end
	Viewmodel.ArmClips.WindSlashDown = flick()
	Viewmodel.ArmClips.WindSlashUp = flick()
end

----------------------------------------------------------------------------------------------------
-- spline clips  (two-arm Clips with Spline = true)
----------------------------------------------------------------------------------------------------
-- TERRA'S BOULDER SHOT REWORK (2026-09-23) was authored in Blender as CURVES, and is played here as the showcase plays
-- it: track() in blender_scripts/terra/m1_rework_bl.py, one cubic Hermite through each arm's keys with CATMULL-ROM
-- tangents over their uneven times -- a middle key's slope is the chord from the key before it to the key after, over
-- the time between them -- and a FLAT tangent on the first key, the last, and any key marked Stop. So the arm eases out
-- of wherever it was, moves THROUGH its middle keys without stopping on any of them, and settles onto the last. The
-- eased step per key the other clips use (samplePose) stops the arm dead on every key it eases into, and the
-- reach -> core -> cock chain has to flow.
-- A Spline clip carries its keys PER SIDE, R and L, each on its own times, plus an optional Cam list for the camera
-- offset, interpolated the same way (not the "punch the key is moving toward" the stepped clips use: a cubic camera
-- is the showcase's, and at the clip's own Rate it lands on its beats instead of trailing them by the usual 12/s).
-- A key is { t, Pose = arm(...) } (a Cam key: Cam = Vector3), or { t, From = true } -- that arm's pose when the clip
-- began (state.clipFrom), or the camera's offset then (state.clipCamFrom) -- or { t } alone, the LIVE state pose this
-- frame (idle, walk, the slide drift...; no offset for a Cam key), so a clip that ends on one hands the arm back to
-- whatever the body is doing without a seam. Past its last key a track sits on it: that is a Hold clip's hold, for as
-- long as the caller keeps it. The blend still runs on top at the clip's Rate, so these clips set a high one.
-- (Not an ArmClips Spline shot, which fits quadratic slopes through a densely sampled choreography and catches up from
-- the arm's own speed. This is the showcase's interpolation, exactly, so its rows can be pasted as they stand.)
local CAM_FIELDS = { "X", "Y", "Z" }

--- One track of a Spline clip, `t` seconds in. `from` is what a From key means and `live` what a key with no value
--- means; `fields` are the channels (a Vector3 reads by the same X / Y / Z names as a table does).
local function splineTrack(keys, t, from, live, fields)
	local n = #keys
	local function valueOf(i)
		local k = keys[i]
		if k.From then return from end
		return k.Pose or k.Cam or live
	end
	if t <= keys[1].t then return valueOf(1) end
	if t >= keys[n].t then return valueOf(n) end
	local i = 1
	while i < n - 1 and keys[i + 1].t <= t do i += 1 end
	-- Catmull-Rom over uneven times; flat (nil) at either end of the track and on a Stop key
	local function slope(j)
		if j == 1 or j == n or keys[j].Stop then return nil end
		local a, b = valueOf(j - 1), valueOf(j + 1)
		local span = keys[j + 1].t - keys[j - 1].t
		local out = {}
		for _, f in ipairs(fields) do
			out[f] = ((b[f] or 0) - (a[f] or 0)) / span
		end
		return out
	end
	local h = math.max(1e-4, keys[i + 1].t - keys[i].t)
	return hermite(valueOf(i), slope(i), valueOf(i + 1), slope(i + 1), (t - keys[i].t) / h, h, fields)
end

--- When a clip is over: its last key's time -- for a Spline clip, the latest of its tracks' (worked out once).
local function clipLength(clip)
	if not clip.Spline then return clip.Keys[#clip.Keys].t end
	if not clip.Length then
		local len = 0
		for _, name in ipairs({ "R", "L", "Cam" }) do
			local track = clip[name]
			if track and #track > 0 then len = math.max(len, track[#track].t) end
		end
		clip.Length = len
	end
	return clip.Length
end

----------------------------------------------------------------------------------------------------
-- solve
----------------------------------------------------------------------------------------------------
--- The light the SCENE alone puts on the arms, in units of the flat-light reference the tones were calibrated
--- against: a white Ambient with no sun is 1 (Config.LampFull says what is done with it). It comes back as two
--- numbers because the two halves land differently: the FILL reaches every face alike -- Ambient is the floor
--- everywhere and OutdoorAmbient is what a pair of arms a stud in front of the lens always sits in, so the two
--- are taken channel by channel, plus the sky's own diffuse -- while the SUN only reaches the faces turned
--- towards it, which is the whole reason a sunlit map shades the arms and flat light does not. Exposure
--- multiplies both, as it does on screen.
--- Rough on purpose: it has to rank the Hub, a comic map, a night map and the range correctly, and every
--- constant it leans on sits in Config where a capture can retune it. Two things it deliberately does not model:
--- the correction that comes out of it is one number per face, so it holds the arms' BRIGHTNESS against a coloured
--- sky but not their hue, and it has no idea whether the player is standing in shade -- a face turned at a sun the
--- player is standing behind a wall from is corrected as though the sun reached it.
local function lum(v)
	return 0.299 * v.X + 0.587 * v.Y + 0.114 * v.Z
end
local function sceneLight()
	local exposure = 2 ^ Lighting.ExposureCompensation
	local amb, out = Lighting.Ambient, Lighting.OutdoorAmbient
	-- the sky's own diffuse only renders with shadows on; Graphics Quality 1-2 turns them off (SettingsRuntime) and
	-- then Ambient is the whole story, so counting it there would leave the arms a tenth dark on the dimmest clients
	local sky = Lighting.GlobalShadows and (C.SkyTint * (C.SkyShare * Lighting.EnvironmentDiffuseScale)) or ZERO
	-- Channel by channel, twice over. The engine raises OutdoorAmbient to at least Ambient one channel at a time, so
	-- the brighter of the two is a per-channel question; and the fill that comes out of it is COLOURED -- this place's
	-- lavender Ambient beside a grey OutdoorAmbient put ~20% more blue on the arms than red, which is why they read
	-- cool and washed in the range next to the Hub capture even once their brightness was right. Carrying three
	-- numbers instead of one luminance lets the correction take that tint back out.
	local share = Lighting.GlobalShadows and C.AmbientShare or 1
	local fill = (Vector3.new(math.max(amb.R, out.R), math.max(amb.G, out.G), math.max(amb.B, out.B)) * share + sky) * exposure
	if Lighting.Brightness <= 0.001 then return fill, 0, nil end
	local sunDir = Lighting:GetSunDirection()
	-- GetSunDirection keeps pointing at the sun after it sets, so a night map with a bright moon would otherwise
	-- shade the arms as if it were noon
	if sunDir.Y <= 0 then return fill, 0, nil end
	return fill, C.SunShare * Lighting.Brightness * exposure, sunDir
end

--- One arm's pose with its SetArmOffset delta added, as a fresh table (`p` may be state.blend's own). An fn that errors
--- is cleared -- unless it was already replaced from inside the call -- and the arm is drawn without it.
local function withArmOffset(side, p)
	local fn = state.armOffset[side]
	if not fn then return p end
	local ok, d = pcall(fn)
	if not ok then
		if state.armOffset[side] == fn then state.armOffset[side] = nil end
		warn("[Viewmodel] SetArmOffset(\"" .. side .. "\") failed and was cleared: " .. tostring(d))
		return p
	end
	if type(d) ~= "table" then return p end
	local out = {}
	for _, f in ipairs(FIELDS) do out[f] = (p[f] or 0) + (tonumber(d[f]) or 0) end
	return out
end

----------------------------------------------------------------------------------------------------
-- OUTFIT ON THE ARMS (2026-10-29, the owner: the outfit did not show on the hands in first person). The arms are a rig
-- of their own, so a premium Outfit's pieces -- rigid Accessories ElementCoat puts on the body (SpellshotOutfit, each on
-- its R15 part) -- never reached them. Every worn piece on a LowerArm or a Hand is copied onto the matching arm: read
-- relative to the elbow (a Hand piece through the rest wrist), the forearm's long axis (-Y) laid along the arm (-Z), its
-- section scaled to the arm's (ArmWidth x ArmHeight) and elbow-to-fingertips to ArmLength. Re-read when the
-- character's DressedOutfit or UniformStamp changes (polled); the copies carry no emitters, lights, welds or scripts.
----------------------------------------------------------------------------------------------------
local DRESS_POLL = 0.5
local DRESS_KEEP = { SpecialMesh = true, SurfaceAppearance = true, Decal = true, Texture = true }
local DRESS_MAP = CFrame.Angles(math.pi / 2, 0, 0)   -- lower arm space -> arm space: -Y (to the hand) -> -Z (forward)
-- (2026-10-29, the owner: the outfit on the hands flickered) mapped exactly, a sleeve's inner faces landed ON the arm's
-- skin and its fingertips on the arm's end cap, and the coincident faces z-fought: the section stands this much proud,
-- the tip this far past the cap
local DRESS_PAD, DRESS_TIP = 1.12, 0.04
-- (2026-10-29, the owner: lines at the Knight's wrist, skin under Frostbound / Magma Warlord) the hand pieces met the
-- forearm piece face to face at the wrist (and the upper arm's at the elbow): the hand pieces stand a little forward and
-- wider, the upper arm's a little back; and while an outfit is on, the arm's own shell takes the sleeve's colour, so a
-- gap between pieces reads as the sleeve and never as skin
local DRESS_HAND_SEP, DRESS_HAND_PAD, DRESS_UPPER_SEP = 0.02, 1.05, 0.02

local function clearDress()
	for _, a in pairs(state.arms or {}) do
		for _, e in ipairs(a.Dress or {}) do e.part:Destroy() end
		a.Dress = {}
		for _, e in ipairs(a.Pieces or {}) do
			if e.skinTone then e.tone, e.skinTone, e.shownTone = e.skinTone, nil, nil end
		end
	end
end

local function dressArms()
	local ch = state.character
	if not (ch and ch.Parent and state.arms) then return end
	local key = tostring(ch:GetAttribute("DressedOutfit")) .. "|" .. tostring(ch:GetAttribute("UniformStamp"))
	if key == state.dressKey then return end
	clearDress()
	if not ch:GetAttribute("DressedOutfit") then
		state.dressKey = key
		return
	end
	local found = 0
	for side, name in pairs({ R = "Right", L = "Left" }) do
		local a = state.arms[side]
		local lower, hand = ch:FindFirstChild(name .. "LowerArm"), ch:FindFirstChild(name .. "Hand")
		local elbow = lower and lower:FindFirstChild(name .. "ElbowRigAttachment")
		local wristL = lower and lower:FindFirstChild(name .. "WristRigAttachment")
		local wristH = hand and hand:FindFirstChild(name .. "WristRigAttachment")
		if a and lower and hand and elbow and wristL and wristH then
			local restHand = wristL.CFrame * wristH.CFrame:Inverse()          -- the hand in the lower arm's space, at rest
			local e = elbow.Position
			local tipY = (restHand * Vector3.new(0, -hand.Size.Y / 2, 0)).Y   -- the fingertips
			local sx, sz = DRESS_PAD * C.ArmWidth / lower.Size.X, DRESS_PAD * C.ArmHeight / lower.Size.Z
			local sl = (C.ArmLength + DRESS_TIP) / math.max(0.2, e.Y - tipY)
			-- (2026-10-29) the upper arm too: the arm runs ArmBack behind the elbow, straight on, and showed bare skin there
			local upper = ch:FindFirstChild(name .. "UpperArm")
			local elbowU = upper and upper:FindFirstChild(name .. "ElbowRigAttachment")
			local shoulderU = upper and upper:FindFirstChild(name .. "ShoulderRigAttachment")
			local lenU = (elbowU and shoulderU) and math.max(0.2, shoulderU.Position.Y - elbowU.Position.Y) or nil
			local lsx, lsl, lsz = sx, sl, sz
			for _, acc in ipairs(ch:GetChildren()) do
				local bp = acc:IsA("Accessory") and acc:GetAttribute("SpellshotOutfit") and acc:GetAttribute("BodyPart")
				if bp == lower.Name or bp == hand.Name or (lenU and bp == upper.Name) then
					local host = (bp == hand.Name and hand) or (bp == lower.Name and lower) or upper
					local e = e
					local sep = 0
					if host == upper then
						e = elbowU.Position
						sx, sz = DRESS_PAD * C.ArmWidth / upper.Size.X, DRESS_PAD * C.ArmHeight / upper.Size.Z
						sl = (C.ArmBack + DRESS_TIP) / lenU
						sep = DRESS_UPPER_SEP
					elseif host == hand then
						sx, sl, sz = lsx * DRESS_HAND_PAD, lsl, lsz * DRESS_HAND_PAD
						sep = -DRESS_HAND_SEP
					else
						sx, sl, sz = lsx, lsl, lsz
					end
					if host == lower and not a.SleeveColor then a.SleeveColor = acc:FindFirstChild("Handle") and acc.Handle.Color end
					for _, src in ipairs(acc:GetDescendants()) do
						if src:IsA("BasePart") and src.Transparency < 1 then
							local rel = host.CFrame:ToObjectSpace(src.CFrame)
							if host == hand then rel = restHand * rel end
							local d = rel.Position - e
							local function k(v) return Vector3.new(v.X * sx, v.Y * sl, v.Z * sz).Magnitude end
							local was = src.Archivable
							src.Archivable = true
							local c = src:Clone()
							src.Archivable = was
							for _, x in ipairs(c:GetChildren()) do
								if not DRESS_KEEP[x.ClassName] then x:Destroy() end
							end
							c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
							c.CastShadow, c.Massless = false, true
							c.Size = Vector3.new(src.Size.X * k(rel.XVector), src.Size.Y * k(rel.YVector), src.Size.Z * k(rel.ZVector))
							c.LocalTransparencyModifier = state.hidden and 1 or 0
							c.Parent = a.Model
							a.Dress = a.Dress or {}
							a.Dress[#a.Dress + 1] = { part = c,
								cf = CFrame.new(d.X * sx, -d.Z * sz, d.Y * sl + sep) * DRESS_MAP * rel.Rotation }
							found += 1
						end
					end
				end
			end
		end
	end
	-- the shell in the sleeve's colour: each face keeps its own shade of the skin (inner / outer / underside), now of the sleeve
	for _, a in pairs(state.arms) do
		local sc = a.SleeveColor
		a.SleeveColor = nil
		if sc and a.Dress and #a.Dress > 0 then
			for _, e in ipairs(a.Pieces) do
				if e.tone then
					e.skinTone = e.skinTone or e.tone
					local t, k = e.skinTone, C.Skin
					e.tone = Color3.new(math.min(1, sc.R * t.R / math.max(0.05, k.R)), math.min(1, sc.G * t.G / math.max(0.05, k.G)),
						math.min(1, sc.B * t.B / math.max(0.05, k.B)))
					e.shownTone = nil
				end
			end
		end
	end
	-- an outfit whose pieces have not replicated yet is read again at the next poll
	if found > 0 then state.dressKey = key end
end

--- Places one arm from its pose. The arm is rigid, so this moves a single root frame and every
--- piece rides its precomputed offset off it.
local function solveArm(a, p, camCF, sway)
	local root = camCF
		* CFrame.new(p.X + sway.X, p.Y + sway.Y, p.Z)
		* CFrame.Angles(rad(p.Pitch), rad(p.Yaw), rad(p.Roll))
		-- The Wrist channel survives the loss of an actual wrist: it tips the far end up or down
		-- about the elbow, which is the only articulation a rigid arm has left, and is still what
		-- sells a throw or a palm-out cast. Scaled down because it swings the whole arm now.
		* CFrame.Angles(rad(p.Wrist * 0.35), 0, 0)

	a.Root = root          -- kept for the light normalisation, which needs the arm's heading this frame
	for _, e in ipairs(a.Pieces) do
		e.part.CFrame = root * e.cf
	end
	-- The invisible ink shell rides exactly the same offsets -- no depth trickery needed, since it
	-- is never drawn and only its Highlight silhouette shows.
	for _, e in ipairs(a.Shell) do
		e.part.CFrame = root * e.cf
	end
	for _, e in ipairs(a.Dress or {}) do      -- (2026-10-29) the worn outfit's forearm and hand pieces
		e.part.CFrame = root * e.cf
	end
	a.CastPoint.WorldCFrame = root * CFrame.new(0, 0, -C.ArmLength - 0.05)
end

function Viewmodel.Update(dt)
	if not Viewmodel.IsBuilt() then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local camCF = camera.CFrame

	-- Draw the arms, or do not. Written only on the frame the view actually changes, and checked here
	-- rather than pushed in from outside so that a respawn's fresh rig picks the right one up by
	-- itself. LocalTransparencyModifier is the same client-only channel FirstPersonController uses to
	-- hide the body, and it composes with each part's own Transparency rather than replacing it.
	local hide = thirdPerson()
	-- HideArms (Umbra's Shadow Step, 2026-09-28): a clip may hide the arms for a window of its OWN time, { from, to }
	-- in clip seconds (its clock's, when it was played with one) -- the arms gone inside the smoke. The same write as
	-- the third-person view, so the two combine: either one hides the arms, and the frame the window ends they are back.
	local hc = state.clip
	if not hide and hc and hc.HideArms then
		local ht = (state.clipClock and state.clipClock()) or (os.clock() - state.clipStart)
		hide = ht >= hc.HideArms[1] and ht < hc.HideArms[2]
	end
	state.dressT = (state.dressT or DRESS_POLL) + dt     -- (2026-10-29) the outfit on the arms, re-read when it changes
	if state.dressT >= DRESS_POLL then
		state.dressT = 0
		dressArms()
	end
	if hide ~= state.hidden then
		state.hidden = hide
		for _, d in ipairs(state.model:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
				d.LocalTransparencyModifier = hide and 1 or 0
			elseif d:IsA("Light") then
				d.Enabled = not hide       -- the arm lamps light the world around them, not just the arms
			end
		end
	end

	-- ---------------------------------------------------------------- target pose
	local want = currentState()
	local def = Viewmodel.States[want] or Viewmodel.States.Idle
	local target = def.Pose
	if def.Late then
		local u = math.clamp(state.move.SlideTime / def.Drift, 0, 1)
		target = { R = lerpArm(def.Pose.R, def.Late.R, u), L = lerpArm(def.Pose.L, def.Late.L, u) }
	end
	-- FROSTBLADE'S NARUTO RUN (Cold Momentum): the arms drop back to the bottom corners by the run's weight
	if state.naruto > 0.001 and want ~= "Slide" and want ~= "Crouch" then
		target = { R = lerpArm(target.R, POSE.NarutoRun.R, state.naruto),
			L = lerpArm(target.L, POSE.NarutoRun.L, state.naruto) }
	end
	-- RING OF FIRE'S TRACE: the right arm points down the crosshair at the trace point, leading the sweep
	if state.trace then
		target = { R = traceArm(camCF, dt), L = target.L }
	end
	-- Into a slide, and for a moment after it, the arms move at the reference's pace: on the slide
	-- line within ~3 frames, and off it into the run or the idle just as fast.
	if want == "Slide" then state.slideFastUntil = os.clock() + 0.35 end
	local rate = os.clock() < state.slideFastUntil and C.SlideBlend or C.IdleBlend
	local camTarget = Vector3.new()
	local camRate = 12                              -- how fast the camera offset follows camTarget, per second

	if state.clip then
		local t = (state.clipClock and state.clipClock()) or (os.clock() - state.clipStart)
		if state.clip.Spline then
			-- SPLINE CLIP (Boulder Shot): each arm on its own curve, and the camera on its own. `target` is still the
			-- live state pose here, which is what a key with no pose hands back to
			local clip, from = state.clip, state.clipFrom or target
			target = {
				R = clip.R and splineTrack(clip.R, t, from.R, target.R, FIELDS) or target.R,
				L = clip.L and splineTrack(clip.L, t, from.L, target.L, FIELDS) or target.L,
			}
			if clip.Cam then
				local c = splineTrack(clip.Cam, t, state.clipCamFrom or ZERO, ZERO, CAM_FIELDS)
				camTarget = Vector3.new(c.X, c.Y, c.Z)
			end
			camRate = clip.Rate or C.ClipBlend          -- the camera rides the curve as tightly as the arms do
		else
			local a, b, alpha, bKey = samplePose(state.clip, t, state.clipFrom or def.Pose)
			local e = TweenService:GetValue(math.clamp(alpha, 0, 1),
				bKey.Easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			target = { R = lerpArm(a.R, b.R, e), L = lerpArm(a.L, b.L, e) }
			camTarget = (bKey.Cam or Vector3.new())
		end
		rate = state.clip.Rate or C.ClipBlend          -- a clip with a beat too quick for ClipBlend sets its own
		if t > clipLength(state.clip) and not state.clip.Hold then
			state.clip = nil
			state.glowTarget = 0
		end
	end

	-- ---------------------------------------------------------------- per-arm shots (M1)
	-- Played EXACTLY -- no blend lag -- so full extension lands on the frame the shard leaves, and
	-- the arm's stride is faded off while it fires and back on afterwards so nothing jumps.
	local shotPose = {}
	local releases = {}
	for _, side in ipairs({ "R", "L" }) do
		local sh = state.shots[side]
		if sh then
			local scale = shotScale()
			local t = (os.clock() - sh.Start) * scale
			local keys = sh.Clip.Keys
			-- a HELD shot (Scorching Lash's grip) sits on its last key for as long as it has the arm
			if sh.Clip.Hold then t = math.min(t, keys[#keys].t) end
			if not sh.Released and t >= sh.Clip.Trigger then
				sh.Released = true
				state.flash[side] = 1
				if sh.OnRelease then releases[#releases + 1] = { sh.OnRelease, side } end
			end
			if t >= keys[#keys].t and not sh.Clip.Hold then
				state.shots[side] = nil
			elseif sh.Clip.Spline then
				shotPose[side] = splineShot(sh, t, side, target[side], scale)
			else
				local a, b = keys[1], keys[2]
				for i = 1, #keys - 1 do
					if t <= keys[i + 1].t then a, b = keys[i], keys[i + 1]; break end
				end
				local function poseOf(k)
					if k.Pose then return k.Pose[side] end
					if k.From then return sh.From end
					return target[side]
				end
				local alpha = math.clamp((t - a.t) / math.max(1e-4, b.t - a.t), 0, 1)
				local e = TweenService:GetValue(alpha, b.Easing or Enum.EasingStyle.Quad,
					b.Direction or Enum.EasingDirection.Out)
				shotPose[side] = lerpArm(poseOf(a), poseOf(b), e)
				-- a shot can kick the camera too (the Fireball punch), read the way a clip's Cam is: the
				-- punch the arm is moving toward. Two shots at once sum.
				if b.Cam then camTarget += b.Cam end
			end
		end
		if state.shots[side] then
			state.shotW[side] = 1
		else
			state.shotW[side] -= state.shotW[side] * math.clamp(10 * dt, 0, 1)
		end
		-- The firing arm is also steadied against turn lag (its stride and fall lift are already faded
		-- by shotW), so the hand the shard leaves is where the thrust put it. Eased in over a few frames
		-- so whatever sway the arm had does not snap off.
		local hold = state.shots[side] and 1 or 0
		local cur = state.steady[side]
		state.steady[side] = cur + (hold - cur) * math.clamp((hold > cur and 30 or 10) * dt, 0, 1)
	end

	-- ---------------------------------------------------------------- cycle
	-- The cycle rides on top of the blended pose, so it survives a cast instead of fighting it.
	local cyc = def.Cycle
	local moving = state.move.Speed > 2
	local airborne = not state.move.Grounded
	-- In the air the legs are not running, so neither are the arms: the stride fades out fast and
	-- the arms hold the pose they left the ground in.
	-- A state change hands the arms from one cycle to another. Swapping the function outright snapped
	-- the arms by whatever the old cycle's offset was at that instant -- measured at up to a stud in a
	-- single frame on run->slide and crouch->run. So the outgoing cycle keeps its own phase and fades
	-- out while the new one fades in from nothing.
	if cyc ~= state.cycleFn then
		if state.cycleFn and state.cycleAmt > 0.001 then
			state.oldCycle = { Fn = state.cycleFn, Amt = state.cycleAmt, Phase = state.phase,
				Cadence = state.cycleCadence or 6 }
		end
		state.cycleFn, state.cycleCadence = cyc, def.Cadence or 6
		state.cycleAmt = 0
	end
	local wantAmt = (cyc and (moving or want == "Idle") and not airborne) and 1 or 0
	state.cycleAmt += (wantAmt - state.cycleAmt) * math.clamp((airborne and 14 or 8) * dt, 0, 1)
	local dR, dL
	if cyc and state.cycleAmt > 0.001 then
		state.phase += dt * (def.Cadence or 6)
		-- (the Naruto run holds the arms still: its weight takes the stride's pump away)
		dR, dL = cyc(state.phase, state.cycleAmt * (1 - 0.9 * state.naruto))
	end
	local old = state.oldCycle
	if old then
		old.Amt -= old.Amt * math.clamp(10 * dt, 0, 1)
		old.Phase += dt * old.Cadence
		if old.Amt < 0.005 then
			state.oldCycle = nil
		else
			local oR, oL = old.Fn(old.Phase, old.Amt)
			dR, dL = addDelta(dR, oR), addDelta(dL, oL)
		end
	end
	-- Falling, the arms float up a touch -- a little lift and tip, growing with how fast you drop and
	-- gone the moment you land. Rising does nothing: the arms just hold.
	local fall = airborne and math.clamp((-state.move.VerticalSpeed - 4) / 40, 0, 1) or 0
	state.air += (fall - state.air) * math.clamp(10 * dt, 0, 1)
	if state.air > 0.001 then
		local lift = { Y = C.FallLift * state.air, Pitch = C.FallTip * state.air }
		dR, dL = addDelta(dR, lift), addDelta(dL, lift)
	end

	dR, dL = scaleDelta(dR, 1 - state.shotW.R), scaleDelta(dL, 1 - state.shotW.L)

	-- ---------------------------------------------------------------- blend
	local k = math.clamp(rate * dt, 0, 1)
	state.blend.R = lerpArm(state.blend.R, target.R, k)
	state.blend.L = lerpArm(state.blend.L, target.L, k)
	for side, p in pairs(shotPose) do state.blend[side] = p end

	-- ---------------------------------------------------------------- sway
	if state.lastCamCF then
		local delta = state.lastCamCF:ToObjectSpace(camCF)
		local _, dy, dx = delta:ToEulerAnglesYXZ()
		state.swayX = math.clamp(state.swayX + (-dy * C.SwayAmount * 60 - state.swayX) * C.SwayResponse,
			-C.SwayMax, C.SwayMax)
		state.swayY = math.clamp(state.swayY + (-dx * C.SwayAmount * 60 - state.swayY) * C.SwayResponse,
			-C.SwayMax, C.SwayMax)
	end
	state.lastCamCF = camCF
	local sway = Vector3.new(state.swayX, state.swayY, 0)

	-- ---------------------------------------------------------------- apply
	local function withDelta(p, d)
		if not d then return p end
		local out = {}
		for _, f in ipairs(FIELDS) do out[f] = (p[f] or 0) + (d[f] or 0) end
		return out
	end
	local pR, pL = withDelta(state.blend.R, dR), withDelta(state.blend.L, dL)
	if dt > 1e-4 then                               -- ... and how fast it is going (a Spline shot carries that on)
		for side, p in pairs({ R = pR, L = pL }) do
			local was, v = state.shown[side], state.vel[side]
			for _, f in ipairs(FIELDS) do
				v[f] = was and ((p[f] or 0) - (was[f] or 0)) / math.max(dt, 1 / 240) or 0
			end
		end
	end
	state.shown.R, state.shown.L = pR, pL           -- where a new shot starts from
	-- SetArmOffset's live weight (Boulder Shot's dips and tremble) goes on last, after shown and vel are taken, so a
	-- shot never departs from it and it is never counted twice
	pR, pL = withArmOffset("R", pR), withArmOffset("L", pL)
	solveArm(state.arms.R, pR, camCF, sway * (1 - state.steady.R))
	solveArm(state.arms.L, pL, camCF, sway * (1 - state.steady.L))
	-- the arms are placed for this frame: anything released now leaves from where the hand IS
	for _, r in ipairs(releases) do task.spawn(r[1], r[2]) end
	state.keyLight.CFrame = camCF * CFrame.new(C.KeyLightOffset)
	state.gapLight.CFrame = camCF * CFrame.new(C.GapLightOffset)
	-- LIGHT NORMALISATION (see Config.LampFull). Every visible face is measured against the flat-light reference the
	-- tones were calibrated at: the lamps fill the scene's shortfall for all of them, and any face the scene then
	-- overdoes -- the sun-facing ones, which is what blew the arms white in the range -- has its tone scaled back down
	-- by exactly what it is getting. Flat light comes out at lamps off and tones untouched, which is the state the Hub
	-- capture was matched against, so the Hub renders the same byte for byte.
	local fill, sunAmt, sunDir = sceneLight()
	-- the direction is kept when the sun goes: Brightness drops to 0 in ONE frame when HubClient swaps the profile in,
	-- and dropping the whole sun term with it would jump the tones back by half while the fill was still easing
	state.sunDir = sunDir or state.sunDir
	if state.lampScale < 0 then
		state.fill, state.sunAmt = fill, sunAmt                     -- built this frame: start where the scene is
	else
		local lightK = math.clamp(C.LightBlend * dt, 0, 1)          -- and ease, so crossing into the Hub is not a pop
		state.fill += (fill - state.fill) * lightK
		state.sunAmt += (sunAmt - state.sunAmt) * lightK
	end
	for _, a in pairs(state.arms) do
		for _, e in ipairs(a.Pieces) do
			if e.normal then
				e.level = state.fill
				if a.Root and state.sunDir and state.sunAmt > 0.001 then
					-- the sun's own light is white; what makes the fill coloured is the ambients, already in it
					e.level += SUN_TINT * (state.sunAmt * math.max(0, a.Root:VectorToWorldSpace(e.normal):Dot(state.sunDir)))
				end
			end
		end
	end
	-- the lamps answer to the fill alone: the arm always has a face turned away from the sun, so the darkest face is
	-- the fill every time, and the lamps go on doing exactly the job they were added for -- lighting what the sky does not
	local lampGoal = math.clamp((lum(C.TargetTop) - lum(state.fill)) / C.LampTop, 0, 1)
	if state.lampScale < 0 then
		state.lampScale = lampGoal
	else
		state.lampScale += (lampGoal - state.lampScale) * math.clamp(C.LightBlend * dt, 0, 1)
	end
	local lamp = math.floor(state.lampScale * 100 + 0.5) / 100          -- a Brightness write only when it moves
	if state.keyLamp and state.lampShown ~= lamp then
		state.lampShown = lamp
		state.keyLamp.Brightness = C.KeyLightBrightness * lamp
		state.gapLamp.Brightness = C.GapLightBrightness * lamp
	end
	-- the lamps sit close enough to the lens to reach every face the camera can see, so they count once, for all of
	-- them, in their own warm colour
	for _, a in pairs(state.arms) do
		for _, e in ipairs(a.Pieces) do
			if e.tone then
				local lv = (e.level or ONE) + LAMP_TINT * (lamp * (e.top and C.LampTop or C.LampSide))
				local tg = e.top and C.TargetTop or C.TargetSide
				local qr = math.clamp((tg.X / math.max(0.05, lv.X)) ^ C.ToneGamma, C.ToneFloor, 1)
				local qg = math.clamp((tg.Y / math.max(0.05, lv.Y)) ^ C.ToneGamma, C.ToneFloor, 1)
				local qb = math.clamp((tg.Z / math.max(0.05, lv.Z)) ^ C.ToneGamma, C.ToneFloor, 1)
				-- 1% steps: a Color write only when it actually moves, and fine enough that a slow pan does not band
				local key = math.floor(qr * 100 + 0.5) * 10000 + math.floor(qg * 100 + 0.5) * 100 + math.floor(qb * 100 + 0.5)
				if e.shownTone ~= key then
					e.shownTone = key
					e.part.Color = Color3.new(e.tone.R * qr, e.tone.G * qg, e.tone.B * qb)
				end
			end
		end
	end

	-- ---------------------------------------------------------------- camera + glow
	state.camOffset = state.camOffset:Lerp(camTarget, math.clamp(camRate * dt, 0, 1))
	if state.humanoid and state.humanoid.Parent then
		-- CAMERA SHAKE scales the clip's punch and nothing else. The posture dip is the crouch and
		-- slide stance -- information about where your eyes are, not a flourish -- so it is never
		-- scaled or a player who turns shake off would stop dipping when they crouch. Reduce
		-- Flashing takes the punch to zero outright.
		local shake = Settings.Get("ReduceFlashing") and 0 or Settings.Scale("CameraShake")
		-- an impact's punch (Viewmodel.Punch) rides the same scale: a hard dip that rebounds once and is gone
		local punch = Vector3.new()
		local pt = os.clock() - state.punchAt
		if pt >= 0 and pt < 0.32 then
			local k = state.punchAmp * math.exp(-pt * 13) * math.cos(pt * 48)
			punch = Vector3.new(0.35 * k, -k, 0)
		end
		-- ...and so do the shakes (Viewmodel.Shake): every live one adds, a spent one (under a thousandth of a stud) goes
		local shakes = state.shakes
		for i = #shakes, 1, -1 do
			local s = shakes[i]
			local a = os.clock() - s.At
			local e = s.Amp * math.exp(-math.max(0, a) / s.Decay)
			if e < 1e-3 then
				table.remove(shakes, i)
			else
				punch += Vector3.new(math.sin(a * 61 + s.Ph), math.sin(a * 71 + 2.1 + s.Ph),
					0.8 * math.sin(a * 53 + 1.3 + s.Ph)) * e
			end
		end
		-- the Naruto run's lean: the head 0.2 studs forward and down, as the body's head moves in the run
		state.humanoid.CameraOffset = (state.camOffset + punch) * shake + state.posture
			+ Vector3.new(0, -0.1, -0.17) * state.naruto
	end

	state.glow += (state.glowTarget - state.glow) * math.clamp(9 * dt, 0, 1)
	if state.glowTarget < state.glow then state.glowTarget = math.max(0, state.glowTarget - dt * 0.8) end
	local b = state.glow * 3.5
	for _, side in ipairs({ "R", "L" }) do
		state.flash[side] -= state.flash[side] * math.clamp(14 * dt, 0, 1)
	end
	-- a Glow = false clip keeps the light dark outright, over any glow or palm flash still fading from before it
	if state.clip and state.clip.Glow == false then
		state.glow, b = 0, 0
		state.flash.R, state.flash.L = 0, 0
	end
	-- The glow asks a different question from the lamps. It was cut in flat light because Bloom blew it out there, not
	-- because the scene was bright, so it keeps its own scale: full anywhere the fill is short of the reference, gone
	-- only in flat light itself. Riding the lamp fill instead would have taken the M1's palm flash to a sixth in the
	-- range -- the one place it has a sunlit scene to read against.
	local glowScale = math.clamp((1 - lum(state.fill)) * 8, 0, 1)
	-- the M1's palm glow: a short flash on the hand that just fired, over whatever a cast is doing.
	-- (2026-10-19, audit P5F-03) Reduce Flashing keeps the palm flash at 0.4 (the cast glow itself is untouched)
	local shotFlash = C.ShotFlash * (Settings.Get("ReduceFlashing") and 0.4 or 1)
	state.arms.R.Glow.Brightness = math.max(b, state.flash.R * shotFlash) * glowScale
	state.arms.L.Glow.Brightness = math.max(b * 0.45, state.flash.L * shotFlash) * glowScale
end

----------------------------------------------------------------------------------------------------
-- muzzle
----------------------------------------------------------------------------------------------------
--- World CFrame the beam/projectile should leave from: the right hand's cast point, pushed clear
--- of the lens so a Beam anchored there actually draws.
function Viewmodel.GetMuzzleCFrame(side)
	local camera = workspace.CurrentCamera
	if not camera then return CFrame.new() end
	-- In the third-person view the arms are still there, still posed, and still parented to the Camera
	-- -- so their cast point is a spot in mid-air in front of the lens, which is the last place a
	-- visible effect should leave from. The body's hand is where the viewer is looking.
	if thirdPerson() then
		local body = bodyHandCFrame(side)
		if body then return body end
	end
	if not Viewmodel.IsBuilt() then return camera.CFrame * CFrame.new(0.3, -0.3, -1.4) end

	local cf = state.arms[side == "L" and "L" or "R"].CastPoint.WorldCFrame * CFrame.Angles(-math.pi / 2, 0, 0)
	local rel = camera.CFrame:ToObjectSpace(cf)
	local minZ = -C.MuzzleMinDistance
	if rel.Position.Z > minZ then
		cf = camera.CFrame * (rel * CFrame.new(0, 0, minZ - rel.Position.Z))
	end
	return cf
end

--- Where the arms actually are on screen, for checking the framing rules without eyeballing them.
--- Returns the fingertip position of each hand in viewport percentages, and the gap between them.
function Viewmodel.MeasureFraming()
	local camera = workspace.CurrentCamera
	if not (camera and Viewmodel.IsBuilt()) then return nil end
	local vp = camera.ViewportSize
	local halfH = math.tan(math.rad(camera.FieldOfView / 2))
	local aspect = vp.X / vp.Y

	local function tip(a)
		local p = a.CastPoint.WorldCFrame.Position
		local rel = camera.CFrame:PointToObjectSpace(p)
		local d = math.max(0.05, -rel.Z)
		return {
			x = rel.X / (d * halfH * aspect) * 100,
			y = -rel.Y / (d * halfH) * 100,
			depth = d,
		}
	end
	local r, l = tip(state.arms.R), tip(state.arms.L)

	-- topmost point of either arm, as a percentage down the screen from the very top
	local top = math.huge
	for _, a in pairs(state.arms) do
		-- tone pieces only: the ink shells are invisible and inflated, so including them would
		-- report the outline's extent rather than the arm's
		for _, e in ipairs(a.Pieces) do
			local p = e.part
			do
				-- all eight corners of the part's box, so the EDGE is measured rather than the centre
				local hs = p.Size * 0.5
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local w = p.CFrame * Vector3.new(hs.X * sx, hs.Y * sy, hs.Z * sz)
							local rel = camera.CFrame:PointToObjectSpace(w)
							local d = math.max(0.05, -rel.Z)
							top = math.min(top, -rel.Y / (d * halfH) * 100)
						end
					end
				end
			end
		end
	end
	-- `top` is in percent of HALF-height, positive below centre. Screen coordinates run 0 (top) to
	-- 100 (bottom), with the centre at 50, so the arms start 50 + top/2 percent down the screen and
	-- fill everything below that.
	return {
		right = r, left = l,
		gapPct = r.x - l.x,
		topPct = top,
		screenFillPct = 50 - top * 0.5,
	}
end

return Viewmodel
