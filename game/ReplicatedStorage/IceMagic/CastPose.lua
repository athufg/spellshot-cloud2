--[[
	CastPose  (ModuleScript)  ->  ReplicatedStorage/IceMagic/CastPose

	THE body-animation layer for SPELLSHOT. One clip table, one stance table, applied to the real
	character body -- so every viewer sees the same motion, including the player themselves.

	THIS IS THE THIRD-PERSON SYSTEM, AND ONLY THAT
	  What your own camera renders is a dedicated viewmodel (see Viewmodel.lua) with its own rig,
	  its own scale and its own animation set. This module never touches it and does not know it
	  exists. Everything here is judged on one question: does it read correctly on a body seen from
	  across the map?

	  The two are deliberately NOT mirrored. An earlier pass tried making the body serve both --
	  camera at the head, real limbs drawn -- which guarantees they agree and guarantees they look
	  wrong, because a pose that frames well at arm's length is not a pose that reads at ten studs.
	  A first-person sprint wants the hands low and open at the bottom of the screen; a third-person
	  sprint wants a stride. Those are different animations and they should be authored as such.

	  So: same underlying facts (idle / walking / sprinting / sliding / casting), two independent
	  responses to them. Adding an ability means authoring it in both places, on purpose.

	CLIPS vs STANCES
	  Clip    one-shot, beat-timed, played on a cast. Overrides the stance while it runs.
	  Stance  continuous, selected by the character's replicated MoveState attribute. This is where
	          idle/sprint/crouch/slide live. Because MoveState is a server-set attribute on the
	          character, every client already has it for every character -- the stance driver needs
	          no remotes and no per-player wiring.

	  A clip that is not `Both` leaves the OFF hand on the stance rather than dropping it to
	  neutral: while the right hand casts, the left keeps the ready posture, so a cast reads as one
	  arm doing something rather than the whole upper body resetting.

	WHERE THE OFFSET IS APPLIED (this took some finding)
	  Current Roblox R15 characters are NOT Motor6D rigs any more -- the joints are
	  `AnimationConstraint` instances (RightShoulder, RightElbow, Waist, ... same names, different
	  class), linked through a pair of RigAttachments. Two consequences:
	    * `joint.Transform = joint.Transform * offset` from a RenderStep bound after
	      Enum.RenderPriority.Character does nothing. The animator re-applies its pose afterwards,
	      so the offset is gone before the frame is drawn.
	    * `C0`/`C1` still exist on the constraint but are READ-ONLY -- they are derived from the
	      attachments.
	  The writable equivalent of C0 is therefore **Attachment0.CFrame**. Offsetting that rotates the
	  child limb about the joint and is completely independent of callback ordering.

	  AND THE STOCK ANIMATION HAS TO BE OFF, NOT FOUGHT.
	  SpellshotService disables each character's `Animate` script on the SERVER, so no client plays
	  the stock tracks and this module is the only thing posing a body. That is not tidiness, it is
	  the only thing that works: the animator writes `Transform` AFTER every RenderStepped binding,
	  so a step that reads Transform and cancels it is always cancelling last frame's value.
	  Measured live -- with the stock tracks playing the Ready stance came out as an arm hanging at
	  the side, wobbling through a 0.25 spread; with them stopped it was the solved direction
	  exactly, to a spread of 0.00. It is also what made the old cast poses read as "it animates,
	  but very subtly": an idle shoulder sits around -77 degrees, so a +75 degree pose layered on
	  top of it composed to about -2 and the arm simply hung there.

	  Joints are still written as `base * offset * Transform:Inverse()`. With Animate off Transform
	  is identity and the inverse costs nothing, but it means a one-off emote or a future uploaded
	  clip degrades to "mostly right" rather than "arm falls to the side".

	  BECAUSE THE STOCK ANIMATION IS GONE, THE STANCES OWN LOCOMOTION TOO. That is what the leg
	  channels and the walk/run cycles below are for -- nothing else is going to move the legs.

	  Older Motor6D rigs are still supported: for those the offset goes on C0 as usual.

	  These are client-side property writes on a server-owned character, so nothing replicates.
	  Every client runs this independently -- exactly like the VFX.

	CHANNELS
	  Degrees on semantic channels, not raw CFrames, so the R6 rig -- whose shoulder frame is
	  rotated 90 degrees relative to R15 -- is one small adapter instead of a duplicated table.
	    Arm    shoulder swing. POSITIVE brings the arm forward (+90 is horizontal in front, +180
	           straight up in front); negative swings it back behind you.
	    Elbow  positive flexes -- the forearm folds up and in, the way an elbow actually bends.
	    Wrist  positive cocks the hand back.
	    In     shoulder YAW toward the aim line, mirrored per side. This is the channel that makes
	           the hands converge near the centre of the screen instead of hanging at shoulder
	           width -- it is applied before the swing, so the whole raised arm rotates about the
	           vertical rather than twisting in place.
	    Hip    per leg. Positive swings the leg forward. A stance value applies to both legs, which
	           is the slide tuck; a cycle adds the per-side opposition that makes a stride.
	    Knee   negative flexes, which is the only direction a knee bends.
	    Waist  negative bends the torso forward, positive leans it back.
	    Drop   studs (2026-09-25, Aftershock): the whole body LOWERED under the root -- the LowerTorso and all that
	           hangs off it, on the R15 `Root` joint (HumanoidRootPart.RootRigAttachment -> LowerTorso). The root
	           itself, and so the physics and the camera, never moves. With the knees keyed to match, the
	           feet stay on the floor and the hands can reach it, which no amount of Waist can do on a root that
	           never moves. Never below 0 (that would lift the feet).
	    Shift  studs, the same joint: positive carries the hips FORWARD under the root, negative back.
	           Drop and Shift are OPT-IN: a clip that keys neither never writes the Root joint at all.

	  WHY ARM AND WAIST LOOK LIKE THEY DISAGREE (they don't). Every one of these is a positive
	  rotation about the joint's X axis. An arm or a leg hangs DOWN from its joint, so its rest
	  direction is -Y and Rx(+) carries it toward -Z, which is forward. The torso stands UP from
	  its joint, rest direction +Y, so the identical Rx(+) carries it toward +Z -- backward. Same
	  rotation, opposite-facing limbs. Waist positive leaning back is the check on this: it is
	  independently confirmed below (the Flash Freeze slam bends forward at -58, the Slide stance
	  leans back over its legs at +24).

	  NOTE ON THE CAST CLIPS: the oldest ones still carry their original hand-tuned values, not
	  re-derived against the above. The Cryo Beam pair WAS re-authored against it (cryo_beam_spec E,
	  2026-09-15): the old fire key's `Arm = -88`, commented "snaps forward", computed to
	  horizontal-BACKWARD and is retired -- the fire arm is now +88, the Icicle Shard thrust's.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Cryo Beam's fire beat, seconds after the cast: the server fires at LevitateTime + ChargeTime, and the
-- windup clip counts its FOCUS keys back from it. (VFXLibrary never requires this module, so reading its
-- tuning here is not a cycle.)
local CryoTuning = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("VFXLibrary")).Tuning.CryoBeam
-- Cryo's FROSTBLADE skin (2026-10-14): its Naruto run in Cold Momentum's window, layered on the stance (FrostbladeKit.Naruto)
local frostbladeModule = nil
local function frostblade()
	if frostbladeModule == nil then
		local m = ReplicatedStorage:WaitForChild("IceMagic"):FindFirstChild("FrostbladeKit")
		local ok, mod = pcall(function() return m and require(m) end)
		frostbladeModule = (ok and mod and mod.Naruto) and mod or false
	end
	return frostbladeModule or nil
end
local narutoWarned = false
-- ...and Frost Lotus's held lotus (FrostLotusKit.M1: the left arm holds it while the M1 is being thrown)
local lotusModule = nil
local function frostLotus()
	if lotusModule == nil then
		local m = ReplicatedStorage:WaitForChild("IceMagic"):FindFirstChild("FrostLotusKit")
		local ok, mod = pcall(function() return m and require(m) end)
		lotusModule = (ok and mod and mod.M1) and mod or false
	end
	return lotusModule or nil
end
local lotusWarned = false
local CRYO_FIRE = CryoTuning.LevitateTime + CryoTuning.ChargeTime

local CastPose = {}

local rad = math.rad
local ZERO = Vector3.new()

CastPose.Config = {
	BlendIn = 14,        -- into a clip
	BlendOut = 9,        -- out of a clip, back to the stance
	StanceBlend = 7,     -- between stances
	-- A cast fires the clip twice: once locally the instant the key goes down (SpellshotInput,
	-- for responsiveness) and once when the server's broadcast comes back (AbilityFX). The second
	-- call must not restart the clip or every cast would visibly hitch one round trip in.
	RestartGuard = 0.4,
	AimBlend = 20,       -- onto a live aim pose (Ring of Fire's trace), which moves every frame
}

----------------------------------------------------------------------------------------------------
-- pose algebra
----------------------------------------------------------------------------------------------------
-- Per-SIDE channels. The legs live here rather than as one shared value because a stride needs
-- the two of them in opposition; a pose that wants both legs together (the slide tuck) just sets
-- the same number for each.
local LIMB = { "Arm", "Elbow", "Wrist", "In", "Hip", "Knee" }
local LEG = { Hip = true, Knee = true }
local SIDES = { "R", "L" }

local function blankLimb()
	return { Arm = 0, Elbow = 0, Wrist = 0, In = 0, Hip = 0, Knee = 0 }
end

local function blankPose()
	return { R = blankLimb(), L = blankLimb(), Waist = 0, Turn = 0, Drop = 0, Shift = 0, Cam = ZERO }
end

local function lerp(a, b, t) return a + (b - a) * t end

----------------------------------------------------------------------------------------------------
-- stances  (continuous, selected by MoveState)
----------------------------------------------------------------------------------------------------
--- Sprint pump. Returns the per-side ARM deltas for this phase; the two arms are half a stride
--- apart, which is the whole reason a pump reads as running rather than as a bounce. Additive on
--- top of the stance, so it survives a cast without fighting it.
--- A stride. Arms and legs swing CONTRALATERALLY -- right arm forward with the left leg -- which
--- is the one detail that separates a run from a hop. The elbow closes on the arm's forward
--- half-stride, and the knee flexes on the leg's BACKswing, which is what lifts the foot to clear
--- the ground; max(0, ...) is what keeps each of those one-sided.
local function strideSample(armSwing, elbowClose, legSwing, kneeFlex, phase, amt)
	local s = math.sin(phase)
	return
		{ Arm = s * armSwing * amt, Elbow = math.max(0, s) * elbowClose * amt,
			Hip = -s * legSwing * amt, Knee = -math.max(0, s) * kneeFlex * amt },
		{ Arm = -s * armSwing * amt, Elbow = math.max(0, -s) * elbowClose * amt,
			Hip = s * legSwing * amt, Knee = -math.max(0, -s) * kneeFlex * amt }
end

local function stride(armSwing, elbowClose, legSwing, kneeFlex)
	return function(phase, amt)
		return strideSample(armSwing, elbowClose, legSwing, kneeFlex, phase, amt)
	end
end

-- (2026-10-27, the owner: arms straight down, never curved) elbowClose is 0: the arms swing straight from the
-- shoulder, no bend on the forward half-stride. Was stride(14, 9, ...) and stride(24, 18, ...).
local walkCycle = stride(14, 0, 24, 30)
local sprintCycle = stride(24, 0, 38, 52)

-- ARMS STRAIGHT DOWN IN EVERY STANCE (2026-10-27, the owner: "dont make their arms curve in third
-- person ... remove the holding arms posture thing, make them straight down"). The old raised
-- "holding magic" posture is gone: Arm, Elbow and In are 0, so both arms hang at the sides and only
-- the cycles below swing them, straight. Casts still raise the arm (clips override the stance) and
-- blend back down to this. Old Arm/Elbow/In: Ready 38/48/16, Sprint 44/62/12, Crouch 36/54/20,
-- Slide -18/34/-14 (ServerStorage.ArmsDownSuperseded_2026_10_27 holds the old module).
--
-- Every stance carries a cycle, because with the stock Animate script off nothing else is going
-- to move the legs. Cycles are gated on the humanoid actually moving, so standing still in any
-- stance is a clean static pose rather than a march on the spot.
CastPose.Stances = {
	Ready  = { Arm = 0, Elbow = 0, In = 0, Waist = -3,
		Cycle = walkCycle, Cadence = 8.5 },
	-- Running: torso pitched into the run.
	Sprint = { Arm = 0, Elbow = 0, In = 0, Waist = -12,
		Cycle = sprintCycle, Cadence = 12.5 },
	Crouch = { Arm = 0, Elbow = 0, In = 0, Waist = -16, Hip = 6, Knee = -22,
		Cycle = walkCycle, Cadence = 6.0 },
	-- Feet-first slide: legs swung forward under the body, torso leaned back over them, arms down
	-- along it. Hip does the real work -- this is the one pose where the legs carry the silhouette,
	-- and a slide has to be identifiable from across the map at a glance.
	Slide  = { Arm = 0, Elbow = 0, In = 0, Waist = 24, Hip = 56, Knee = -34 },
}

-- MoveState is the server's vocabulary ("None" | "Sprint" | "Crouch" | "Slide"); this maps it onto
-- stance names. Anything unknown falls back to Ready rather than to nothing.
local STANCE_FOR_STATE = {
	None = "Ready", Sprint = "Sprint", Crouch = "Crouch", Slide = "Slide",
}

----------------------------------------------------------------------------------------------------
-- clips  (one-shot, beat-timed)
----------------------------------------------------------------------------------------------------
-- Beat times match VFXLibrary.Tuning.<ability>.LeadIn.
--   Stance = true   this key IS the current stance, whatever that is. Cast clips open and close on
--                   it, so a cast blends out of and back into the posture the body is actually
--                   holding instead of snapping through a neutral hands-down pose on the way.
--   Cam             camera punch, applied to the CASTER only (see GetCameraOffset).
--   From / FromBody a FromCurrent clip's key that IS the pose the body was in when the clip started: From the arms and
--                   legs, FromBody the torso too (2026-09-23).
--   Tremble         { Turn, Arm, From, Full }: a shake under load, in degrees, building from From to Full (seconds).
--                   Optional (2026-09-25, Aftershock): Until (seconds; the shake is gone 0.02 s after it), Waist
--                   (degrees of lean shake), and on a Both clip BOTH arms shake, not just the lead one.
--   Drop / Shift    the body channels on the Root joint (see CHANNELS), blended like Waist; a key without them is 0.
local function key(t, tbl)
	tbl.t = t
	return tbl
end

CastPose.Clips = {
	-- M1, Icicle Shard: a repulsor palm thrust -- the arm punches straight out to horizontal, elbow
	-- locked, hand cocked back so the PALM faces the target, and snaps home. One arm per shot,
	-- alternating (Side = "L" is the left). Rate: played sharp rather than smoothed, or a 70 ms
	-- punch never reaches full extension. Repeat: every shot is a fresh cast, never a duplicate.
	-- Trigger is full extension, when the shard leaves the hand.
	IcicleShardR = {
		Trigger = 0.12, Rate = 45, Repeat = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.12, { Arm = 88, Elbow = 4, Wrist = 55, In = 10, Waist = -4, Easing = Enum.EasingStyle.Quad }),
			key(0.187, { Arm = 85, Elbow = 6, Wrist = 50, In = 10, Waist = -4 }),
			key(0.453, { Stance = true, Easing = Enum.EasingStyle.Quad }),
		},
	},
	IcicleShardL = {
		Trigger = 0.12, Rate = 45, Repeat = true, Side = "L",
		Keys = {
			key(0.00, { Stance = true }),
			key(0.12, { Arm = 88, Elbow = 4, Wrist = 55, In = 10, Waist = -4, Easing = Enum.EasingStyle.Quad }),
			key(0.187, { Arm = 85, Elbow = 6, Wrist = 50, In = 10, Waist = -4 }),
			key(0.453, { Stance = true, Easing = Enum.EasingStyle.Quad }),
		},
	},
	-- Cryo's FROST LOTUS skin (2026-10-15): the M1 HOLD-AND-PLUCK. The left hand holds a lotus (FrostLotusKit.M1 layers that
	-- arm); the RIGHT hand throws every shot -- in one fast continuous motion it reaches across to the lotus, plucks a petal
	-- and throws it, released on the Default's beat (Trigger 0.12) and back inside the Default's 0.453 s, so the rate and
	-- the release cannot change. Chained at the M1's interval it is back at the lotus as the next click comes.
	IcicleShardLotus = {
		Trigger = 0.12, Rate = 45, Repeat = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.04, { Arm = 52, Elbow = 74, Wrist = 12, In = 58, Waist = -3, Easing = Enum.EasingStyle.Quad }),
			key(0.12, { Arm = 88, Elbow = 4, Wrist = 55, In = 10, Waist = -4, Easing = Enum.EasingStyle.Quad }),
			key(0.187, { Arm = 85, Elbow = 6, Wrist = 50, In = 10, Waist = -4 }),
			key(0.453, { Stance = true, Easing = Enum.EasingStyle.Quad }),
		},
	},
	-- "bend down and smash the hand into the ground" -- Flash Freeze reuses the Absolute Zero
	-- asset and its animation unchanged; only the name and the slot moved.
	FlashFreeze = {
		Keys = {
			key(0.00, { Stance = true }),
			key(0.16, { Arm = -158, Elbow = -20, Waist = 16, Hip = 0, In = 4,
				Cam = Vector3.new(0, 0.25, 0), Easing = Enum.EasingStyle.Quad }),   -- fist up
			key(0.38, { Arm = -18, Elbow = -8, Waist = -58, Hip = -26, In = 10,
				Cam = Vector3.new(0, -1.7, 0), Easing = Enum.EasingStyle.Quint }),  -- slam
			key(0.58, { Arm = -14, Elbow = -6, Waist = -54, Hip = -24, In = 10,
				Cam = Vector3.new(0, -1.5, 0) }),
			key(1.15, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	},
	-- Frost Slide (the Mobility ABILITY, a dash -- not the Ctrl movement slide, which is a stance).
	-- The body pitches into the dash with both arms swept back behind it, knees bent off the push, and
	-- is back on the stance by the time the 0.2 s dash has carried it clear. Authored against the
	-- channel signs above: Arm negative is behind you, Waist negative bends forward. Both: one arm back
	-- reads as a throw. Rate: sharp, or a 60 ms lean never lands. Repeat: charges can go 0.35 s apart,
	-- and every dash is its own cast. Trigger 0 matches Tuning.FrostSlide.LeadIn.
	FrostSlide = {
		Trigger = 0, Rate = 40, Repeat = true, Both = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.06, { Arm = -52, Elbow = 16, Waist = -24, Hip = -10, Knee = -18, In = -10,
				Easing = Enum.EasingStyle.Quint }),
			key(0.22, { Arm = -46, Elbow = 14, Waist = -20, Hip = -8, Knee = -14, In = -10 }),
			key(0.35, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	},
	-- Chill Aura: both arms pressed down and out, planting the zone. Mirrored, because a
	-- one-armed version reads as a punch rather than as something settling around you.
	ChillAura = {
		Both = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.14, { Arm = -34, Elbow = -46, Waist = -14, Hip = -10, In = -8,
				Cam = Vector3.new(0, -0.35, 0), Easing = Enum.EasingStyle.Back }),
			key(0.50, { Arm = -30, Elbow = -42, Waist = -12, Hip = -8, In = -8,
				Cam = Vector3.new(0, -0.2, 0) }),
			key(0.95, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	},
	-- Ultimate, Cryo Beam (cryo_beam_spec E). The caster floats 4.5 studs through all of it, so EVERY key
	-- carries the float legs (Hip 14, Knee -26): a clip key without Hip/Knee pulls the legs to 0, not to the
	-- stance (keyArm). The windup, held until the fire: CHANNEL, both hands open low at the front of the waist
	-- as the body lifts (absolute times); FOCUS, from CRYO_FIRE - 0.70, both hands come up cupped forward at
	-- chest height, close together.
	CryoBeamCharge = {
		Trigger = 0.40, Hold = true, Both = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.22, { Arm = 38, Elbow = 58, Wrist = 0, In = 14, Waist = -4, Hip = 12, Knee = -24,
				Easing = Enum.EasingStyle.Quad }),                                   -- hands (+-0.65, 0.23, -1.39)
			key(CRYO_FIRE - 0.70, { Arm = 38, Elbow = 58, Wrist = 0, In = 14, Waist = -4, Hip = 14, Knee = -26 }),
			key(CRYO_FIRE - 0.43, { Arm = 70, Elbow = 22, Wrist = 0, In = 16, Waist = -8, Hip = 14, Knee = -26,
				Easing = Enum.EasingStyle.Quad }),                                   -- hands (+-0.53, 0.52, -1.64)
			key(CRYO_FIRE, { Arm = 74, Elbow = 18, Wrist = 0, In = 18, Waist = -10, Hip = 14, Knee = -26,
				Easing = Enum.EasingStyle.Sine }),
		},
	},
	-- the fire, held for the channel: the right arm drives straight out at shoulder height, elbow locked, palm
	-- out (Wrist positive, as Icicle Shard's thrust) with the chest turned into it, while the left drops to a
	-- brace under it (OffKeys), then settles. A fixed forward arm: it does not follow the aim.
	CryoBeam = {
		Trigger = 0.10, Hold = true, OffKeys = true,
		Keys = {
			key(0.00, { Arm = 74, Elbow = 18, Wrist = 0, In = 18, Waist = -10, Hip = 14, Knee = -26,
				Off = { Arm = 74, Elbow = 18, Wrist = 0, In = 18 } }),
			key(0.10, { Arm = 88, Elbow = 4, Wrist = 55, In = 10, Waist = -6, Turn = 8, Hip = 14, Knee = -26,
				Off = { Arm = 40, Elbow = 70, Wrist = 0, In = 30 }, Easing = Enum.EasingStyle.Quint }),
			key(0.22, { Arm = 84, Elbow = 8, Wrist = 50, In = 10, Waist = -6, Turn = 6, Hip = 14, Knee = -26,
				Off = { Arm = 40, Elbow = 70, Wrist = 0, In = 30 }, Easing = Enum.EasingStyle.Quad }),
		},
	},

	-- Technique, Voltaic's Railspike (the owner's note, 2026-09-28): BOTH arms throw the surge, the hands at SHOULDER
	-- height and well apart (In slightly out: the hands a shoulder-width-plus apart, never meeting). The windup, held
	-- to the fire: up by 0.16 with the elbows a little bent (gathering), pressing out by 0.50 with a tremble under the
	-- load; the palms turned out (Wrist, as Icicle Shard's thrust). Its own clip, not CryoBeamCharge (Cryo Beam's
	-- levitating windup: its first key held the hands at the waist for Railspike's whole 0.55 s). StanceLegs: the
	-- caster walks on under it. The caster's own first-person arms are Viewmodel.Clips.RailspikeSurge.
	RailspikeSurge = {
		Trigger = 0.55, Hold = true, Both = true, Rate = 40, StanceLegs = true,
		Tremble = { Turn = 0, Arm = 0.8, From = 0.20, Full = 0.50 },
		Keys = {
			key(0.00, { Stance = true }),
			key(0.16, { Arm = 84, Elbow = 26, Wrist = 40, In = -4, Waist = 4, Easing = Enum.EasingStyle.Quad }),
			key(0.50, { Arm = 88, Elbow = 16, Wrist = 48, In = -6, Waist = 2, Easing = Enum.EasingStyle.Sine }),
		},
	},
	-- the fire, played for everyone on RailspikeShot: both arms drive straight out, elbows locked, the chest into it,
	-- held through the line's hold (RailspikeFX Hold 0.40), then back on the stance
	RailspikeThrow = {
		Trigger = 0.07, Both = true, Rate = 60, StanceLegs = true,
		Keys = {
			key(0.00, { Arm = 88, Elbow = 16, Wrist = 48, In = -6, Waist = 2 }),
			key(0.07, { Arm = 92, Elbow = 0, Wrist = 62, In = -2, Waist = -8, Easing = Enum.EasingStyle.Quint }),
			key(0.20, { Arm = 90, Elbow = 4, Wrist = 56, In = -2, Waist = -6, Easing = Enum.EasingStyle.Quad }),
			key(0.40, { Arm = 89, Elbow = 6, Wrist = 54, In = -2, Waist = -5 }),
			key(0.75, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	},

	----------------------------------------------------------------------------- Pyro (Build Prompt #21)
	-- Every Pyro clip is StanceLegs: the legs stay on the stance, stride and all, so a cast never stops the
	-- run under it. Turn is the torso's yaw; OffKeys lets a key carry `Off`, what the OTHER arm does.
	--
	-- M1, Fireball: the hand tilts up while the fire gathers on the fist and the shoulder draws back, then a
	-- real punch -- arm locked at shoulder height, chest and shoulder driven through -- and the fireball leaves
	-- at full extension (Trigger). Hands alternate, like Icicle Shard; the left-hand clips are built below.
	FireballR = {
		Trigger = 0.42, Rate = 45, Repeat = true, StanceLegs = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.18, { Arm = 26, Elbow = 70, Wrist = 34, In = 18, Waist = 2, Turn = -14, Easing = Enum.EasingStyle.Quad }),
			key(0.34, { Arm = 24, Elbow = 74, Wrist = 38, In = 18, Waist = 3, Turn = -18, Easing = Enum.EasingStyle.Sine }),
			key(0.42, { Arm = 90, Elbow = 0, Wrist = -4, In = 12, Waist = -8, Turn = 22, Easing = Enum.EasingStyle.Quad }),
			key(0.50, { Arm = 86, Elbow = 6, Wrist = -2, In = 12, Waist = -6, Turn = 18 }),
			key(0.85, { Stance = true, Easing = Enum.EasingStyle.Quad }),
		},
	},
	-- Primary, Immolate: a quick open, then both forearms sweep in level across the chest, the hands meeting in
	-- front of it with a small hunch over them; the motes ignite there (Trigger). Back on the stance by 0.52 s.
	Immolate = {
		Trigger = 0.22, Both = true, Rate = 30, StanceLegs = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.10, { Arm = 58, Elbow = 22, Wrist = -10, In = -26, Waist = 3, Easing = Enum.EasingStyle.Quad }),
			key(0.22, { Arm = 52, Elbow = 48, Wrist = 10, In = 62, Waist = -10, Easing = Enum.EasingStyle.Quad }),
			key(0.30, { Arm = 50, Elbow = 46, Wrist = 8, In = 60, Waist = -8 }),
			key(0.52, { Stance = true, Easing = Enum.EasingStyle.Quad }),
		},
	},
	-- Aqua's SIDEARM draw (2026-10-27: this was Cinder Shield's cast, CinderShieldCast, which the Sidearm borrowed;
	-- the shield left the game): both fists wind apart and meet in front of the chest (In is measured: a blocky hand
	-- is a stud wide, and the knuckles meet at 37), then the right hand comes up over the body while the left drops
	-- out of the way. Hold: it may also be a BASE pose (SetBase).
	SidearmDraw = {
		Trigger = 5 / 30, Hold = true, OffKeys = true, Rate = 40, StanceLegs = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.10, { Arm = 50, Elbow = 86, Wrist = 0, In = -12, Waist = 4,
				Off = { Arm = 50, Elbow = 86, Wrist = 0, In = -12 }, Easing = Enum.EasingStyle.Quad }),
			key(5 / 30, { Arm = 78, Elbow = 36, Wrist = 0, In = 37, Waist = -6,
				Off = { Arm = 78, Elbow = 36, Wrist = 0, In = 37 }, Easing = Enum.EasingStyle.Quad }),
			key(0.22, { Arm = 78, Elbow = 36, Wrist = 0, In = 37, Waist = -5,
				Off = { Arm = 78, Elbow = 36, Wrist = 0, In = 37 } }),
			key(0.34, { Arm = 90, Elbow = 30, Wrist = -40, In = 24, Waist = -2,
				Off = { Arm = -4, Elbow = 12, Wrist = 0, In = 4 }, Easing = Enum.EasingStyle.Quad }),
		},
	},
	-- Ultimate, Ring of Fire. While the hand draws the circle, the right arm is solved live to point at the drawing
	-- point (SetAim). When the circle closes, a settling beat -- the arm drops, the chest lifts --
	RingOfFireSettle = {
		Hold = true, Rate = 14, StanceLegs = true,
		Keys = {
			key(0.00, { Arm = 58, Elbow = 10, Wrist = -6, In = 6, Waist = -2, Easing = Enum.EasingStyle.Sine }),
			key(0.20, { Arm = 44, Elbow = 42, Wrist = 6, In = 8, Waist = 5, Easing = Enum.EasingStyle.Sine }),
		},
	},
	-- -- then SNAP-AND-POINT: the hand thrown up high above the head, cocked back, and flicked out and down to
	-- point at the circle on the ignition frame (Trigger). A big arm movement reads at gameplay distance, where
	-- a fingerless blocky hand's snap does not. Arm and In were solved on the measured rig for a circle 13
	-- studs ahead.
	RingOfFirePoint = {
		Trigger = 7 / 30, Rate = 50, StanceLegs = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.16, { Arm = 170, Elbow = 64, Wrist = 36, In = -4, Waist = 7, Turn = 10, Easing = Enum.EasingStyle.Quad }),
			key(7 / 30, { Arm = 85.3, Elbow = 0, Wrist = -8, In = 31.3, Waist = -12, Turn = -10, Easing = Enum.EasingStyle.Quad }),
			key(0.40, { Arm = 83.3, Elbow = 4, Wrist = -6, In = 31.3, Waist = -10, Turn = -8 }),
			key(0.85, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	},
}

--- A punch thrown with the other hand. In mirrors on its own (it is signed per side); the torso turn is a
--- body channel, so it flips here. `off`, when given, is what the right arm does meanwhile.
local function leftHanded(clip, off)
	local keys = {}
	for i, k in ipairs(clip.Keys) do
		local copy = table.clone(k)
		if copy.Turn then copy.Turn = -copy.Turn end
		if off and not copy.Stance then copy.Off = off end
		keys[i] = copy
	end
	local out = table.clone(clip)
	out.Keys, out.Side, out.OffKeys = keys, "L", off ~= nil
	return out
end

CastPose.Clips.FireballL = leftHanded(CastPose.Clips.FireballR)

-- Mobility, DETONATE (Pyro phase two, 2026-09-23; the approved blocking, pyropack/pyro_newmoves_anim.py DETONATE): the
-- marking gesture, a BACKHAND FLICK. The right hand is drawn across to the left side of the face with the torso coiled
-- (right shoulder forward), held a beat, then flicked out backhand to the right, the arm ending held straight out to
-- the side -- a one-armed T that reads from the front at gameplay distance. The mark lands on the flick (Trigger,
-- PyroFX.Tuning.Detonate.Trigger). Not aimed: the marked player is whoever you last hit. A key with no Easing is Quad,
-- as in the approved file.
CastPose.Clips.Detonate = {
	Trigger = 0.27, Rate = 60, StanceLegs = true,
	Keys = {
		key(0.00, { Stance = true }),
		key(0.12, { Arm = 70, Elbow = 80, Wrist = 24, In = 60, Waist = -4, Turn = 18, Easing = Enum.EasingStyle.Quad }),
		key(0.20, { Arm = 72, Elbow = 84, Wrist = 28, In = 62, Waist = -5, Turn = 20, Easing = Enum.EasingStyle.Sine }),
		key(0.27, { Arm = 88, Elbow = 4, Wrist = -26, In = -72, Waist = 0, Turn = -16, Easing = Enum.EasingStyle.Quad }),
		key(0.38, { Arm = 86, Elbow = 8, Wrist = -18, In = -70, Waist = 0, Turn = -14 }),
		key(0.78, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}

-- Defense, SCORCHING LASH, round 3 (owner, 2026-09-24): "when you hold, your one arm which is not holding should be like
-- pointing forward and the one holding should be like back ... if u release it comes all the way from the side like in a
-- curve path". The blocking: pyropack/lash_v3_anim.py (HOLD, SWEEP), reviewed in sheets_newmoves/Lash_v3_Preview.*.
-- HOLDING it: the whip arm (right) drawn back behind the body, low and out past the hip -- the whip trails behind on the
-- ground (PyroFX) -- the torso turned right-shoulder-back, and the free arm (left, OffKeys) pointing straight at the
-- crosshair: its In -26 undoes the torso's Turn -30. Hold: it runs until the sweep (ScorchingLash) or the hold's end takes
-- over, and it is also the body's BASE pose while held (SetBase, AbilityFX). StanceLegs: the run goes on under it.
local LASH_AIM = { Arm = 86, Elbow = 2, Wrist = -8, In = -26 }        -- the left arm pointing at the crosshair
local LASH_PULL = { Arm = 22, Elbow = 76, Wrist = 0, In = -6 }        -- ...and pulled back to the hip
CastPose.Clips.ScorchingLashHold = {
	Hold = true, Rate = 24, OffKeys = true, StanceLegs = true,
	Keys = {
		key(0.00, { Stance = true }),
		key(0.20, { Arm = 58, Elbow = 16, Wrist = 0, In = -96, Waist = 4, Turn = -30, Off = LASH_AIM,
			Easing = Enum.EasingStyle.Quad }),
	},
}

-- RELEASING it: THE SIDEARM SWEEP. A level arm (Arm ~88) is swung round the body by In alone, and the torso's Turn adds to
-- it, so each key is the arm's heading (about Turn + In; 0 = the aim, negative = the caster's right) shared between the
-- two, the body leading: out of the hold the hand rises, still behind (0.06, -124), comes round the right side at
-- shoulder height (0.12, -95), across the front (0.17, -5) and out to the front-left, where the whip cracks (0.22, +84;
-- the Trigger = PyroFX.Tuning.ScorchingLash.Trigger; the hand itself is then about +35 round the root, measured), then
-- wraps on across and drops, and the body is back on the stance by 0.75 (ClipEnd = the M1Lock). The left fist pulls back
-- to the hip as the right swings through where it was aiming. FromCurrent: the sweep leaves from wherever the body really
-- is -- the hold, or partway into it on a tap -- the arms (From), the torso (FromBody) and the aiming arm (OFF_HOLD).
-- Rate 90: exact at 60 fps (rate * dt clamps to 1); a faster client trails the ~1500 deg/s sweep by ~7 degrees at 240.
local OFF_HOLD = {}   -- a key's Off: that arm holds where it was when the clip started (FromCurrent clips; Wind Blade too)
CastPose.Clips.ScorchingLash = {
	Trigger = 0.22, Rate = 90, OffKeys = true, StanceLegs = true, FromCurrent = true,
	Keys = {
		key(0.00, { From = true, FromBody = true, Off = OFF_HOLD }),
		key(0.06, { Arm = 82, Elbow = 8, Wrist = -6, In = -100, Waist = 2, Turn = -24, Off = OFF_HOLD,
			Easing = Enum.EasingStyle.Sine }),
		key(0.12, { Arm = 88, Elbow = 6, Wrist = -4, In = -87, Waist = -4, Turn = -8,
			Off = { Arm = 50, Elbow = 50, Wrist = 0, In = -16 }, Easing = Enum.EasingStyle.Linear }),
		key(0.17, { Arm = 88, Elbow = 4, Wrist = 0, In = -21, Waist = -8, Turn = 16, Off = LASH_PULL,
			Easing = Enum.EasingStyle.Linear }),
		key(0.22, { Arm = 84, Elbow = 4, Wrist = 10, In = 44, Waist = -10, Turn = 40, Off = LASH_PULL,
			Easing = Enum.EasingStyle.Sine }),
		key(0.30, { Arm = 72, Elbow = 18, Wrist = 6, In = 54, Waist = -9, Turn = 42, Off = LASH_PULL,
			Easing = Enum.EasingStyle.Quad }),
		key(0.40, { Arm = 58, Elbow = 30, Wrist = 0, In = 60, Waist = -7, Turn = 32,
			Off = { Arm = 26, Elbow = 64, Wrist = 0, In = 4 }, Easing = Enum.EasingStyle.Sine }),
		key(0.75, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}

-- M1, Wind Blade (Zephyr): the third-person half of the M1 (Viewmodel ArmClips.WindSlashDown/Up are the first-person
-- half). The hands alternate and each hand alternates its stroke name -- RIGHT Down, LEFT Down, RIGHT Up, LEFT Up
-- (SpellshotInput / AbilityFX pick them) -- and every one fires on the Trigger (ZephyrFX.Tuning.WindBlade.Trigger). One
-- clip per shot owns both arms (FromCurrent: it leaves from the pose the body is really in). OFF_HOLD (a key's Off: that
-- arm holds where it was when the clip started) is declared above with Scorching Lash's sweep: ONE table, by identity.
-- The 2026-09-16 slash and its 2026-09-17 hold / lower up-stroke are in the pre-import backup
-- (D:/voltkit_scratch/_backups/roblox_studio_2026-10-06/).
-- v6 (2026-10-07, the owner: "the moves need to be the same as the Blender showcase"): THE GUARD AND THE WRIST FLICK
-- REPLACE THE SLASH above. The source: blender_scripts/zephyr/spring/wind_blade_bl.py (GUARD / DIP / EASE_G, pulses(),
-- caster_pose()), the reel vfx_blocking/zephyr/aqua_v6/1_wind_blade. Both hands are held up in front in a boxer's guard
-- -- elbows low, forearms angled up at the target, hands at chest height -- and a blade is a WRIST FLICK, not an arm
-- swing: the hand cocks up and back (0.03 s), snaps down, in and forward onto the release (the kit's 'snap' ease, the
-- Trigger 0.06 s), overshoots (0.105 s) and settles back on the guard by 0.28 s, the elbow opening ~16 degrees and
-- closing with it, while the chest turns ~6 degrees into the slashing hand and back (1.32 x the kit's yaw pulse: a
-- smooth pulse, not the old 20-degree snap). Every number below was solved from the kit's hand targets on its own rig
-- (shoulders at chest +-1.5, arm 1.10 + 1.05: the same R15 proportions), sampled every 15 ms, first-shot timing (the
-- cock is the press window). The OTHER arm holds where it was through the release (OFF_HOLD) and is back on the guard by
-- 0.105 s -- the kit's flick recovery of that hand's previous blade ends right there. After the burst the guard holds,
-- eases a touch lower (EASE_G) by HoldUntil and is back on the stance by 1.7 s (the kit's GUARD .. EASE_G .. RELAX).
-- Up and Down are the same flick: the kit has no up-stroke (SpellshotInput / AbilityFX still alternate the names; the
-- crescent itself turns half round for an Up). StanceLegs, so the run carries on under it; Repeat. WindBladeRise is the
-- kit's lead-in (RELAX -> DIP -> GUARD over the 0.8 s before the first press), played by ZephyrFX_WindBlade.Demo only:
-- the live M1's first flick swings up from the stance.
local WB_HOLD_UNTIL = 1.05        -- = Viewmodel ArmClips.WindSlashDown.HoldUntil; AbilityFX chains shots inside it
local WB_GUARD = { Arm = 34, Elbow = 98, In = 8, Wrist = 3 }      -- the kit's GUARD hand (1.30, 1.62, 3.38), flex 0.05
local WB_EASE = { Arm = 18, Elbow = 105, In = 8, Wrist = 0 }      -- EASE_G (1.34, 1.45, 3.15)
local WB_WAIST = -5               -- the guard's lean forward (the kit's pelvis + spine pitch, 0.16 rad, mostly the hips)
--- One flick sample (clip seconds): the slashing arm, the chest's Turn; the other arm held until the release, then guard.
local function wbFlick(t, arm, elbow, inward, wrist, turn, ease)
	return key(t, { Arm = arm, Elbow = elbow, In = inward, Wrist = wrist, Turn = turn, Waist = WB_WAIST,
		Off = (t <= 0.06) and OFF_HOLD or WB_GUARD, Easing = ease or Enum.EasingStyle.Linear })
end
local function wbClip()
	return {
		Trigger = 0.06, Rate = 60, Repeat = true, StanceLegs = true, OffKeys = true,
		FromCurrent = true, HoldUntil = WB_HOLD_UNTIL,
		Keys = {
			key(0.000, { From = true, FromBody = true, Off = OFF_HOLD }),
			wbFlick(0.015, 35.1, 100.8, 7.9, 20.6, -0.9, Enum.EasingStyle.Sine),
			wbFlick(0.030, 36.7, 103.3, 7.5, 38.4, -1.9),     -- the COCK: up and back, the wrist cocked
			wbFlick(0.045, 34.7, 86.0, 9.7, -21.6, 4.7),       -- the snap
			wbFlick(0.060, 34.7, 85.3, 9.8, -23.5, 6.0),       -- RELEASE (Trigger)
			wbFlick(0.075, 35.1, 83.3, 10.0, -28.0, 6.1),
			wbFlick(0.090, 35.2, 82.3, 10.1, -29.9, 5.6),
			wbFlick(0.105, 35.3, 82.1, 10.1, -30.4, 5.3),      -- the overshoot
			wbFlick(0.120, 35.2, 82.3, 10.1, -30.0, 5.2),
			wbFlick(0.150, 34.9, 84.6, 9.9, -25.7, 4.9),
			wbFlick(0.180, 34.3, 88.4, 9.5, -18.1, 4.0),
			wbFlick(0.210, 34.0, 92.5, 9.0, -9.4, 2.6),
			wbFlick(0.240, 33.9, 96.0, 8.5, -1.8, 1.2),
			wbFlick(0.280, 33.9, 98.0, 8.2, 2.9, 0.1, Enum.EasingStyle.Sine),   -- back on the guard
			key(0.450, { Arm = 34, Elbow = 98, In = 8, Wrist = 3, Waist = WB_WAIST, Off = WB_GUARD }),
			key(WB_HOLD_UNTIL, { Arm = 18, Elbow = 105, In = 8, Wrist = 0, Waist = -3, Off = WB_EASE,
				Easing = Enum.EasingStyle.Sine }),
			key(1.700, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	}
end
CastPose.Clips.WindBladeDownR = wbClip()
CastPose.Clips.WindBladeUpR = wbClip()
-- the left hand's: the chest turns the other way, each key's own Off kept (held, then the guard)
local function wbLeft(clip)
	local out = leftHanded(clip)
	out.OffKeys = true
	return out
end
CastPose.Clips.WindBladeDownL = wbLeft(CastPose.Clips.WindBladeDownR)
CastPose.Clips.WindBladeUpL = wbLeft(CastPose.Clips.WindBladeUpR)
-- the lead-in (the demo's): from wherever the body is, the hands dip to the belly (DIP, wrists flexed) and rise into
-- the guard with a little overshoot (the kit's 'back' ease), then hold it until the first flick takes over
CastPose.Clips.WindBladeRise = {
	Rate = 30, Both = true, StanceLegs = true, FromCurrent = true,
	Keys = {
		key(0.00, { From = true, FromBody = true }),
		key(0.30, { Arm = -8, Elbow = 123, In = 11, Wrist = 20, Waist = -9, Easing = Enum.EasingStyle.Sine }),   -- DIP
		key(0.68, { Arm = 34, Elbow = 98, In = 8, Wrist = 3, Waist = WB_WAIST, Easing = Enum.EasingStyle.Back }), -- GUARD
		key(3.00, { Arm = 34, Elbow = 98, In = 8, Wrist = 3, Waist = WB_WAIST }),
	},
}
-- SOLO: the slashing arm only, the other arm left to its stance -- for a shot that does not chain (the first of a
-- burst: the last shot is older than the hold). AbilityFX picks it.
local function wbSolo(clip)
	local out = table.clone(clip)
	out.Keys = {}
	for i, k in ipairs(clip.Keys) do
		local copy = table.clone(k)
		copy.Off = nil
		out.Keys[i] = copy
	end
	out.OffKeys = false
	return out
end
for _, name in ipairs({ "WindBladeUpR", "WindBladeDownR", "WindBladeDownL", "WindBladeUpL" }) do
	CastPose.Clips[name .. "Solo"] = wbSolo(CastPose.Clips[name])
end

-- PRIMARY, Cross-Slash Dash (Zephyr; re-keyed 2026-10-07 to the v6 showcase): the caster track of
-- blender_scripts/zephyr/spring/cross_slash_dash_bl.py (CASTER: C_ANT .. C_REC1, with v5's 0.14 s hold on the slash pose
-- and v4's two-frame hit-stop), each key FITTED to these channels (a least-squares fit of the kit's two-bone arms and legs:
-- shoulder at the chest's +-1.5 / 1.35, arms 1.10 + 1.05, legs 0.92 + 0.92; Waist = -(pelvis + spine pitch), Drop / Shift =
-- the hips' drop and slide x 1.1 for the R15 legs). The kit's beats land on the cast's clock through ZephyrFX_CrossSlash's
-- map (kit 0 .. T_GO 0.50 -> look 0 .. ChargeTime 0.30; the dash T_GO .. T_ARR -> ChargeTime .. ChargeTime + DashTime;
-- T_ARR .. T_X -> .. Trigger 0.92; 1:1 after):
--   COUNTER 0.06  the arms swing back and out, the chest up          SWING 0.114  the hands sweep round in front
--   CROSS   0.168 the X-guard: both arms reach forward and in, nearly straight, the wrists crossed in front of the upper
--                 chest at shoulder height, the right in front; the knees sink (Back: it locks in with a settle)
--   COIL    0.252 / DIP 0.30  coiled lower, the weight rocks back -- the look's clock HOLDS at 0.28 between them while the
--                 key is held (HoldPose), trembling (the kit's coil tremble, ~1 degree)
--   DASH    0.406 .. 0.546  the arms stay CROSSED through the dash; the body leans 45 forward over a driving right knee,
--                 the left leg trailing straight behind
--   SNAP    0.685 the arms snap open WIDE and low as the body passes through dummy 1 (the wrist ribbons' moment)
--   SLASH   0.80  the arrival: a deep skidding crouch, chest up, both arms flung wide and a little back (Back: overshoot);
--                 held through the X (Trigger 0.92) and the kit's hit-stop + hold to 1.127, sinking a touch by 1.286
--   RECOVER 1.686 rising, the hands come in low; the stance by 2.116 (the kit's REC2, which is the ready pose)
-- Not carried: the kit's chest twist and the skid-turn's yaw (the game's root is the camera's; Demo turns the root
-- itself), the lateral spread of the skid's feet (no hip abduction channel: the knees take it). Rate 60 so the snap
-- lands inside its 0.14 s; the right arm leads, the left is Off.
CastPose.Clips.CrossSlashDash = {
	Trigger = 0.92, Rate = 60, OffKeys = true,
	Tremble = { Turn = 0, Arm = 1.1, From = 0.12, Full = 0.276, Until = 0.40 },
	StanceLegsFrom = 1.13,   -- past the slash's hold, a caster who walks off gets the stance's legs back (not the skid)
	Keys = {
		key(0.00, { Stance = true }),
		key(0.06, { Arm = -35, In = 30, Elbow = 25, Wrist = -10, Waist = 7, Hip = 10, Knee = -4, Shift = -0.09,
			Off = { Arm = -35, In = 30, Elbow = 25, Wrist = -10, Hip = -2, Knee = -4 }, Easing = Enum.EasingStyle.Quad }),
		key(0.114, { Arm = 40, In = 9, Elbow = 78, Wrist = 4, Waist = -5, Hip = 30, Knee = -40, Drop = 0.13,
			Off = { Arm = 34, In = 12, Elbow = 87, Wrist = 4, Hip = 10, Knee = -42 }, Easing = Enum.EasingStyle.Sine }),
		key(0.168, { Arm = 82, In = 45, Elbow = 9, Wrist = 8, Waist = -13, Hip = 40, Knee = -56, Drop = 0.24, Shift = 0.07,
			Off = { Arm = 68, In = 51, Elbow = 36, Wrist = 8, Hip = 8, Knee = -50 }, Easing = Enum.EasingStyle.Back }),
		key(0.252, { Arm = 80, In = 45, Elbow = 9, Wrist = 8, Waist = -17, Hip = 48, Knee = -68, Drop = 0.37, Shift = 0.07,
			Off = { Arm = 66, In = 51, Elbow = 33, Wrist = 8, Hip = 10, Knee = -62 }, Easing = Enum.EasingStyle.Sine }),
		key(0.30, { Arm = 78, In = 45, Elbow = 12, Wrist = 8, Waist = -6, Hip = 64, Knee = -76, Drop = 0.53, Shift = -0.11,
			Off = { Arm = 64, In = 51, Elbow = 36, Wrist = 8, Hip = 12, Knee = -74 }, Easing = Enum.EasingStyle.Sine }),
		key(0.406, { Arm = 82, In = 45, Elbow = 6, Wrist = 8, Waist = -45, Hip = 68, Knee = -58, Drop = 0.24, Shift = 0.11,
			Off = { Arm = 66, In = 51, Elbow = 36, Wrist = 8, Hip = -62, Knee = -8 }, Easing = Enum.EasingStyle.Quint }),
		key(0.546, { Arm = 82, In = 45, Elbow = 6, Wrist = 8, Waist = -45, Hip = 68, Knee = -58, Drop = 0.24, Shift = 0.11,
			Off = { Arm = 66, In = 51, Elbow = 36, Wrist = 8, Hip = -62, Knee = -8 }, Easing = Enum.EasingStyle.Linear }),
		key(0.685, { Arm = 46, In = -105, Elbow = 39, Wrist = -10, Waist = -34, Hip = 74, Knee = -60, Drop = 0.37,
			Shift = 0.11, Off = { Arm = 42, In = -102, Elbow = 36, Wrist = -10, Hip = -54, Knee = -6 },
			Easing = Enum.EasingStyle.Quint }),
		key(0.80, { Arm = 60, In = -111, Elbow = 6, Wrist = -12, Waist = -17, Hip = 20, Knee = -92, Drop = 0.73,
			Off = { Arm = 50, In = -108, Elbow = 12, Wrist = -12, Hip = 74, Knee = -82 }, Easing = Enum.EasingStyle.Back }),
		key(0.92, { Arm = 60, In = -112, Elbow = 4, Wrist = -12, Waist = -18, Hip = 19, Knee = -93, Drop = 0.74,
			Off = { Arm = 50, In = -108, Elbow = 10, Wrist = -12, Hip = 75, Knee = -83 }, Easing = Enum.EasingStyle.Sine }),
		key(1.127, { Arm = 60, In = -112, Elbow = 4, Wrist = -12, Waist = -18, Hip = 19, Knee = -93, Drop = 0.74,
			Off = { Arm = 50, In = -108, Elbow = 10, Wrist = -12, Hip = 75, Knee = -83 }, Easing = Enum.EasingStyle.Linear }),
		key(1.286, { Arm = 60, In = -114, Elbow = 0, Wrist = -12, Waist = -19, Hip = 18, Knee = -94, Drop = 0.77,
			Off = { Arm = 50, In = -108, Elbow = 6, Wrist = -12, Hip = 76, Knee = -84 }, Easing = Enum.EasingStyle.Sine }),
		key(1.686, { Arm = 12, In = -35, Elbow = 30, Wrist = 0, Waist = -10, Hip = 34, Knee = -96, Drop = 0.31,
			Off = { Arm = 15, In = -20, Elbow = 25, Wrist = 0, Hip = 46, Knee = -54 }, Easing = Enum.EasingStyle.Sine }),
		key(2.116, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
-- (MOBILITY, Gust Jump's clips -- GustJump here, GustJumpLand / GustJumpHover / GustJumpGlide after Aftershock's -- were
-- removed 2026-10-08: nothing has played them since Skyrider replaced Gust Jump on 2026-10-06 (its clips are the Skyrider*
-- ones). The module as it stood is ServerStorage.BugfixSuperseded_2026_10_08.CastPose.)
-- DEFENSE, Bulwark Wall (2026-09-20): the hand that CALLS IT UP, then the brace. Her right arm drives up out of the
-- ground on the cast -- the slabs leave the floor on the same beat (Trigger 0.06 against TerraFX.Tuning.BulwarkWall's
-- RiseTime 0.26), so hand and stone read as one motion -- and she turns side-on behind it, knees set, that hand up
-- across her face, and HOLDS while the wall stands. A held clip: CastPose.Start lets it go the moment her
-- Holding_Defense attribute clears, which the server does on the release, the break, an empty bar and death alike.
CastPose.Clips.BulwarkWallRaise = {
	Trigger = 0.06, Rate = 48, Hold = true, ReleaseRate = 24, StanceLegs = false,
	Keys = {
		key(0.00, { Arm = 62, Elbow = 16, Wrist = 24, In = 10, Waist = -30, Hip = 20, Knee = -34 }),
		key(0.06, { Arm = -74, Elbow = 8, Wrist = -30, In = -12, Waist = -6, Hip = 8, Knee = -22,
			Easing = Enum.EasingStyle.Quint }),
		key(0.26, { Arm = -52, Elbow = 62, Wrist = -18, In = 34, Waist = -14, Hip = 14, Knee = -30,
			Easing = Enum.EasingStyle.Back }),
		key(0.40, { Arm = -48, Elbow = 66, Wrist = -16, In = 38, Waist = -16, Hip = 16, Knee = -32,
			Easing = Enum.EasingStyle.Sine }),
	},
}
-- M1, Boulder Shot, THE REWORK (2026-09-23; it replaces the 2026-09-20 Pick / Charge / Throw trio on request): the body
-- of the Blender showcase (blender_scripts/terra/m1_rework_bl.py -- R_WRIST, R_POLE, R_PALM, L_WRIST, L_POLE, BODY),
-- brought over as TWO clips, because in the game the button can come up at any moment -- a tap at 0.05 s, a hold for
-- three seconds -- and the showcase's one timeline only ever shows a full hold.
--   WINDUP  clocked in SECONDS SINCE THE PRESS (PlayClocked; the clock is the charge's own, not a 0..1 fraction). REACH
--           out and down over the floor (0.08), the core lands on the palm (0.18, SpellshotInput's BOULDER_TAP, so the
--           Trigger), the off hand comes up and points down the range (0.30), the arm COCKS back over the shoulder as the
--           body turns away (0.62) and is WOUND at full charge (1.10, TerraFX.Tuning.BoulderShot.ChargeTime) -- and then
--           simply holds there for as long as the button does: sampleClip holds the last key past its time, and Hold
--           keeps the clip from releasing. The showcase's T_UP hold keys are that hold. Tremble: the arm shakes under
--           the weight, building with the charge and full at full (see step()).
--   THROW   played when the button comes up, keys in seconds after button-up (the showcase's t - T_UP), and it LEAVES
--           FROM WHEREVER THE BODY IS (FromCurrent, FromBody): mid-reach on a tap, wound on a full hold. Over the top
--           (0.028), RELEASE (0.05, the Trigger: the rock leaves the hand -- the showcase's T_R), the follow-through
--           across the body and low (0.18), easing out (0.39), the stance by 0.83. The off hand holds where it was
--           (OFF_HOLD) until the body unwinds and then snaps back and down (0.15).
-- THE NUMBERS ARE DERIVED, NOT EYEBALLED: a forward-kinematics model of this module's own channel maths (armOffset,
-- buildOffsets) on the R15 blocky rig's measured RigAttachments (the TrainingGround dummies), fitted so the WRIST lands
-- where the showcase's does relative to its shoulder (after Turn / Waist; the showcase's arm is 2.15 studs long and
-- this rig's 1.58, so its shoulder-to-wrist vector is scaled by 0.735) with the ELBOW on its pole's side. The showcase's
-- shoulder is taken WITHOUT its pelvis dip and shift, because this root never moves: so the hand keeps the showcase's
-- path through the world rather than riding a body that is not there. Wrist residuals, rig studs, as keyed: windup
-- 0.02 / 0.04 / 0.04 / 0.03 / 0.03, off hand 0.03 / 0.04 / 0.04; throw 0.05 / 0.06 / 0.01 / 0.02 / 0.11, off hand
-- 0.05 / 0.04 / 0.02. The 0.39 key asks for the hand low and INSIDE the shoulder line, which a rig with no adduction
-- channel can only approach. NOTE the showcase's own release is NOT a straight arm: relative to its shoulder the wrist
-- is 0.61 of the arm's reach out, forearm rising (the body carries the shoulder into it), and that is what is keyed.
--   Turn  = the showcase's twist, in degrees (both are + for the right shoulder forward).
--   Waist = MINUS its lean (Waist negative bends forward; see the header).
--   Hip / Knee: the pelvis dip (0.30 studs at wound, 0.36 at release) as leg flex -- the root does not move here, so it
--           reads as knees bent. The showcase's pelvis SHIFT and its staggered feet have no channel and are left out.
--   Wrist: the showcase keeps the hand straight and ROLLS the palm (up under the rock, out at the release). There is no
--           roll here -- the palm is always on the arm's swing plane -- so the Wrist is the cock toward the showcase
--           palm, capped at 40 (the fit asks for more on every palm-up key).
-- The off (left) arm is keyed from L_WRIST too, except while the right reaches (0.08, 0.18): it stays on the stance,
-- which already carries it up and forward, rather than hanging first the way the showcase's idle does.
CastPose.Clips.BoulderWindup = {
	Trigger = 0.18, Rate = 40, Hold = true, ReleaseRate = 26, StanceLegs = false, OffKeys = true,
	Tremble = { Turn = 0.69, Arm = 1.19, From = 0.18, Full = 1.10 },     -- degrees: 0.012 rad twist, 0.035 studs at the wrist
	Keys = {
		key(0.00, { Stance = true }),
		key(0.08, { Arm = 16, Elbow = 60, Wrist = 32, In = -5, Turn = 8, Waist = -13, Hip = 26, Knee = -50,
			Easing = Enum.EasingStyle.Quad }),                                    -- REACH, out and down over the floor
		key(0.18, { Arm = 5, Elbow = 104, Wrist = 40, In = -16, Turn = 3, Waist = -6, Hip = 19, Knee = -36,
			Easing = Enum.EasingStyle.Sine }),                                    -- the core lands on the palm
		key(0.30, { Arm = 6, Elbow = 114, Wrist = 40, In = -22, Turn = -5, Waist = -3, Hip = 21, Knee = -40,
			Off = { Arm = 28, Elbow = 99, Wrist = 0, In = 12 },
			Easing = Enum.EasingStyle.Sine }),                                    -- the off hand points down the range
		key(0.62, { Arm = 29, Elbow = 102, Wrist = 40, In = -43, Turn = -23, Waist = 2, Hip = 29, Knee = -55,
			Off = { Arm = 34, Elbow = 95, Wrist = 0, In = -6 },
			Easing = Enum.EasingStyle.Sine }),                                    -- COCK, drawn back over the shoulder
		key(1.10, { Arm = 49, Elbow = 74, Wrist = 40, In = -49, Turn = -32, Waist = 6, Hip = 34, Knee = -65,
			Off = { Arm = 23, Elbow = 101, Wrist = 0, In = -13 },
			Easing = Enum.EasingStyle.Sine }),                                    -- WOUND, and held
	},
}
CastPose.Clips.BoulderThrow = {
	Trigger = 0.05, Rate = 54, FromCurrent = true, StanceLegs = false, OffKeys = true,
	Keys = {
		key(0.000, { From = true, FromBody = true, Off = OFF_HOLD }),
		key(0.028, { Arm = 73, Elbow = 104, Wrist = 40, In = -35, Turn = -11, Waist = -4, Hip = 37, Knee = -70,
			Off = OFF_HOLD, Easing = Enum.EasingStyle.Quad }),                     -- OVER the top
		key(0.050, { Arm = 61, Elbow = 99, Wrist = 38, In = -4, Turn = 7, Waist = -13, Hip = 38, Knee = -72,
			Off = OFF_HOLD, Easing = Enum.EasingStyle.Quint }),                    -- RELEASE, down the line
		key(0.150, { Arm = 0, Elbow = 101, Wrist = 24, In = 41, Turn = 23, Waist = -18, Hip = 33, Knee = -63,
			Off = { Arm = -84, Elbow = 105, Wrist = 0, In = 31 },
			Easing = Enum.EasingStyle.Quad }),                                    -- the off hand snaps back and down
		key(0.180, { Arm = 2, Elbow = 85, Wrist = 32, In = 47, Turn = 24, Waist = -17, Hip = 32, Knee = -60,
			Off = { Arm = -82, Elbow = 101, Wrist = 0, In = 33 },
			Easing = Enum.EasingStyle.Sine }),                                    -- FOLLOW-THROUGH, across and low
		key(0.390, { Arm = -30, Elbow = 78, Wrist = 40, In = 48, Turn = 18, Waist = -12, Hip = 24, Knee = -46,
			Off = { Arm = -61, Elbow = 76, Wrist = 0, In = 32 },
			Easing = Enum.EasingStyle.Sine }),
		key(0.830, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
-- ULTIMATE, Earthen Tomb (v3, 2026-09-20; it replaces v2's one-armed floor-reach on request): THE TWO-ARM SMASH.
-- Both arms swing up over her head and drive into the ground TOGETHER -- the weight goes back on the wind-up, then the
-- whole body folds over the blow, knees bent, and the hands stay buried while the cast is live. Nothing here times the
-- hold: CastPose.Start plays it while her TombPhase attribute is "Cast" and lets go the moment that changes (the catch,
-- a miss, a death) -- the same attribute, set on the same server line, that the mechanic branches on.
-- Trigger 0.12 is the fissure's own GripTime (TerraFX.Tuning.EarthenTomb.GripTime): the hands land on the floor on the
-- frame the crack leaves them. ReleaseRate: back to the stance fast.
CastPose.Clips.EarthenTombSlam = {
	Trigger = 0.12, Rate = 46, Both = true, Hold = true, ReleaseRate = 22,
	Keys = {
		key(0.00, { Stance = true }),
		key(0.05, { Arm = -48, Elbow = 24, Wrist = -12, In = -8, Waist = 16, Hip = -8, Knee = -14,
			Easing = Enum.EasingStyle.Back }),                                    -- both fists up, weight back
		key(0.12, { Arm = 80, Elbow = 2, Wrist = 46, In = 6, Waist = -64, Hip = 34, Knee = -56,
			Easing = Enum.EasingStyle.Quint }),                                   -- SMASH, both hands into the floor
		key(0.24, { Arm = 72, Elbow = 8, Wrist = 40, In = 8, Waist = -56, Hip = 28, Knee = -48,
			Easing = Enum.EasingStyle.Sine }),                                    -- held there, hands buried
	},
}
-- ...and THE RAISE, once the target is caught: one arm comes up off the floor and hauls, the body opening out of the
-- fold as it goes, so she reads as the one willing the platform up even though she never leaves the ground. It is
-- CLOCKED BY THE PLATFORM (CastPose.Start below): its time IS the climb's fraction, 0 to 1, on the climb's own eased
-- curve -- not a timer that happens to be the same length -- so the arm and the stone can never drift apart. One arm,
-- so the off hand stays on the stance and the silhouette reads as a lift rather than a shrug.
CastPose.Clips.EarthenTombRaise = {
	Rate = 34, Hold = true, ReleaseRate = 22, StanceLegs = false,
	Keys = {
		key(0.00, { Arm = 72, Elbow = 8, Wrist = 40, In = 8, Waist = -56, Hip = 28, Knee = -48 }),
		key(0.35, { Arm = 26, Elbow = 22, Wrist = 12, In = -12, Waist = -18, Hip = 12, Knee = -26,
			Easing = Enum.EasingStyle.Sine }),
		key(1.00, { Arm = -62, Elbow = 10, Wrist = -26, In = -16, Waist = 12, Hip = -6, Knee = -10,
			Easing = Enum.EasingStyle.Sine }),
	},
}
-- MOBILITY TECHNIQUE, Aftershock (2026-09-25; it replaces Tremor Vault): BOTH FISTS INTO THE GROUND. From the owner's
-- approved Blender showcase, blender_scripts/terra/aftershock_bl.py (R_WRIST / R_POLE / BODY): the fists dip and close
-- (0.07), come up the front of the chest (0.22), go OVERHEAD with the weight back (Rise 0.40), are held at the TOP --
-- arms long, trembling (Top 0.54) -- DRIVE over and down (0.615), and meet the floor together at CONTACT (Hit 0.68),
-- the whole body folded over them and sunk on its knees, the feet planted; left there (to 0.98, TerraFX.Tuning.Aftershock
-- FistsUp after Hit), pulled out (1.30) and back on the stance by 1.63 (Recover after Hit).
-- KEYS ARE IN SIM SECONDS. AbilityFX plays this with PlayClocked on TerraFX.AftershockClock, which holds the clock on
-- Hit for the HITPAUSE (HoldFrames / 60 s) -- so the body freezes on the contact frame exactly as the showcase's does,
-- and 0.74 is sim time too (the showcase's pelvis sinks on for 0.06 s after the contact). Every client plays it on the
-- server's T0, the caster included; the first-person arms are Viewmodel.Clips.Aftershock.
-- THE NUMBERS ARE DERIVED (tools/fit_aftershock_port.py, on tools/fit_castpose.py's measured rig; the same method as
-- Boulder Shot's, see above), with the new ROOT channels: Drop / Shift are the showcase pelvis's dip / shift x the rig's
-- leg scale (1.049), Drop never below 0, and the legs are solved so each ankle stays where it stood -- the feet do not
-- leave the floor (0.03 stud at worst, at the TOP, where the hips go back with nothing to lower). Waist is MINUS the
-- showcase's lean; no twist, so no Turn; Wrist 0 (the showcase's hand is straight on its forearm).
--   CONTACT: the BOTTOM OF EACH HAND on the floor 2.15 studs ahead of the root (TerraFX.Tuning.Aftershock.Reach, the
--            ring's centre) and 0.5 to the side -- the fit misses by 0.06-0.09 stud -- with Waist fitted too: -75, a
--            deeper fold than the showcase's lean, because this rig's arm is 0.735 of its length.
--   OVERHEAD: the rig has no shoulder abduction, so a straight-up arm (Arm ~165) keeps the fists ~1.4 studs apart where
--            the showcase's meet; Arm 156 / In 80 brings them to ~0.9 apart for 0.1 stud of height.
--   0.22 / 0.615 are fitted with Arm >= 0: unconstrained, the arm swings BEHIND the body with the elbow folded shut.
-- Tremble: the showcase's strain, 0.04 studs at the wrist (x 0.735 = 1.1 degrees of Arm, both arms) and 0.010 rad of
-- lean, building from 0.34, full by 0.50, and gone just after the TOP (Until) -- the drive is not a shake.
-- Rate 56: the blend trails the curve by ~18 ms, which the 67 ms freeze swallows. StanceLegs = false: the legs ARE the
-- slam (the server holds the caster in place until Hit + RootUntil). StanceLegsFrom 0.98 is that release: Hit 0.68 +
-- RootUntil 0.30, both in SIM seconds, because TerraHandler measures RootUntil on the hitpause clock too (it lets go
-- when TerraFX.AftershockClock(t) >= Hit + RootUntil, real 1.047); the same beat as Viewmodel's OUT key. Hardcoded,
-- CastPose does not require TerraFX -- keep it in step with TerraFX.Tuning.Aftershock. From there a caster who walks
-- off gets the stance's legs and the body back up, while one who stays put plays the pull-out as keyed.
-- EVERY NUMBER HERE IS A PROPOSAL.
CastPose.Clips.Aftershock = {
	Trigger = 0.68, Rate = 56, ReleaseRate = 16, Both = true, StanceLegs = false, StanceLegsFrom = 0.98,
	Tremble = { Turn = 0, Arm = 1.1, Waist = 0.57, From = 0.34, Full = 0.50, Until = 0.54 },
	Keys = {
		key(0.00, { Stance = true }),
		key(0.07, { Arm = -2, Elbow = 22, Wrist = 0, In = 19, Waist = -6, Hip = 25, Knee = -51, Drop = 0.19, Shift = 0.06,
			Easing = Enum.EasingStyle.Quad }),                                    -- GATHER: a small dip, the fists closing
		key(0.22, { Arm = 11, Elbow = 139, Wrist = 0, In = 30, Waist = 1, Hip = 21, Knee = -36, Drop = 0.10, Shift = -0.07,
			Easing = Enum.EasingStyle.Sine }),                                    -- up the front of the chest
		key(0.40, { Arm = 156, Elbow = 0, Wrist = 0, In = 80, Waist = 11, Hip = 7, Knee = 0, Drop = 0, Shift = -0.25,
			Easing = Enum.EasingStyle.Sine }),                                    -- OVERHEAD, the weight going back
		key(0.54, { Arm = 156, Elbow = 0, Wrist = 0, In = 77, Waist = 15, Hip = 10, Knee = 0, Drop = 0, Shift = -0.34,
			Easing = Enum.EasingStyle.Sine }),                                    -- the TOP, held: the read
		key(0.615, { Arm = 116, Elbow = 94, Wrist = 0, In = 79, Waist = -17, Hip = 33, Knee = -66, Drop = 0.31, Shift = 0.05,
			Easing = Enum.EasingStyle.Quad }),                                    -- DRIVE, over and down
		key(0.68, { Arm = 86, Elbow = 0, Wrist = 0, In = 29, Waist = -75, Hip = 42, Knee = -121, Drop = 1.05, Shift = 0.38,
			Easing = Enum.EasingStyle.Quad }),                                    -- CONTACT (the clock holds here)
		key(0.74, { Arm = 84, Elbow = 0, Wrist = 0, In = 29, Waist = -73, Hip = 42, Knee = -124, Drop = 1.11, Shift = 0.39,
			Easing = Enum.EasingStyle.Sine }),                                    -- ...and sinks on into it
		key(0.98, { Arm = 88, Elbow = 0, Wrist = 0, In = 28, Waist = -76, Hip = 43, Knee = -119, Drop = 1.01, Shift = 0.35,
			Easing = Enum.EasingStyle.Sine }),                                    -- the fists left in the ground
		key(1.30, { Arm = -10, Elbow = 75, Wrist = 0, In = 34, Waist = -20, Hip = 33, Knee = -71, Drop = 0.37, Shift = 0.13,
			Easing = Enum.EasingStyle.Sine }),                                    -- pulled out
		key(1.63, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
-- ULTIMATE, Cyclone (re-keyed 2026-10-07 from the v6 showcase: blender_scripts/zephyr/spring/cyclone_bl.py circle_hands,
-- _track and caster_pose, put on these channels by a two-bone fit; keys in LIVE seconds = the Blender's / 1.25, the live
-- form being 1.2 s for its 1.5). FORM: the summon -- bent forward, the torso coiled clockwise (the counter-move), both
-- arms swept low and in (0.224) -- then THE CORKSCREW: both wrists circle the vertical COUNTER-CLOCKWISE seen from above,
-- IN PHASE (each round its own axis a shoulder-width apart: the right swings out while the left swings in), rising
-- chest-high -> overhead, the circle widening, the turn accelerating 2.6 -> 15 rad/s (a key every 60 degrees of it, so
-- they crowd toward the top), the chest winding with the hands, arched at the top (1.2). Then the channel's slow overhead
-- circle (3.2 rad/s), the LOOP: the caller's clock (ZephyrFX.CycloneLoopClock with LoopFrom / LoopLength) repeats
-- [LoopFrom, LoopFrom + LoopLength) until touchdown, its last key equal to its first. Rate 30, so the fast turns are not
-- smoothed away. Hold; StanceLegs: the caster walks on under it. Off = the left arm (In is mirrored per side).
CastPose.Clips.CycloneForm = {
	Trigger = 0.224, Hold = true, OffKeys = true, StanceLegs = true, Rate = 30,
	LoopFrom = 1.462, LoopLength = 1.571,
	Keys = {
		key(0.000, { Stance = true }),
		key(0.224, { Arm = 49, Elbow = 26, Wrist = 10, In = 27, Waist = -18, Turn = -17,
			Off = { Arm = 46, Elbow = 26, Wrist = 10, In = 33 }, Easing = Enum.EasingStyle.Sine }),
		key(0.480, { Arm = 55, Elbow = 26, Wrist = 10, In = 30, Waist = -11, Turn = -3,
			Off = { Arm = 53, Elbow = 26, Wrist = 10, In = 24 }, Easing = Enum.EasingStyle.Linear }),
		key(0.643, { Arm = 65, Elbow = 26, Wrist = 10, In = 38, Waist = -5, Turn = 13,
			Off = { Arm = 64, Elbow = 26, Wrist = 10, In = 14 }, Easing = Enum.EasingStyle.Linear }),
		key(0.765, { Arm = 60, Elbow = 59, Wrist = 10, In = 48, Waist = -3, Turn = 13,
			Off = { Arm = 50, Elbow = 80, Wrist = 10, In = 11 }, Easing = Enum.EasingStyle.Linear }),
		key(0.864, { Arm = 59, Elbow = 103, Wrist = 10, In = 36, Waist = -1, Turn = -4,
			Off = { Arm = 58, Elbow = 108, Wrist = 10, In = 41 }, Easing = Enum.EasingStyle.Linear }),
		key(0.949, { Arm = 95, Elbow = 49, Wrist = 10, In = 5, Waist = 2, Turn = -22,
			Off = { Arm = 95, Elbow = 48, Wrist = 10, In = 54 }, Easing = Enum.EasingStyle.Linear }),
		key(1.024, { Arm = 112, Elbow = 26, Wrist = 10, In = 5, Waist = 6, Turn = -19,
			Off = { Arm = 114, Elbow = 26, Wrist = 10, In = 41 }, Easing = Enum.EasingStyle.Linear }),
		key(1.092, { Arm = 122, Elbow = 26, Wrist = 10, In = 20, Waist = 9, Turn = 6,
			Off = { Arm = 119, Elbow = 26, Wrist = 10, In = 21 }, Easing = Enum.EasingStyle.Linear }),
		key(1.154, { Arm = 122, Elbow = 26, Wrist = 10, In = 44, Waist = 10, Turn = 26,
			Off = { Arm = 116, Elbow = 26, Wrist = 10, In = 5 }, Easing = Enum.EasingStyle.Linear }),
		key(1.200, { Arm = 122, Elbow = 26, Wrist = 10, In = 62, Waist = 11, Turn = 23,
			Off = { Arm = 124, Elbow = 26, Wrist = 10, In = -5 }, Easing = Enum.EasingStyle.Linear }),
		-- the channel: overhead, arched, the slow circle (the loop)
		key(1.462, { Arm = 119, Elbow = 56, Wrist = 10, In = 43, Waist = 6, Turn = 0,
			Off = { Arm = 119, Elbow = 61, Wrist = 10, In = 37 }, Easing = Enum.EasingStyle.Sine }),
		key(1.724, { Arm = 119, Elbow = 59, Wrist = 10, In = 15, Waist = 6, Turn = -4,
			Off = { Arm = 124, Elbow = 32, Wrist = 10, In = 51 }, Easing = Enum.EasingStyle.Linear }),
		key(1.985, { Arm = 122, Elbow = 40, Wrist = 10, In = 10, Waist = 6, Turn = -4,
			Off = { Arm = 123, Elbow = 26, Wrist = 10, In = 45 }, Easing = Enum.EasingStyle.Linear }),
		key(2.247, { Arm = 126, Elbow = 26, Wrist = 10, In = 24, Waist = 6, Turn = 0,
			Off = { Arm = 124, Elbow = 26, Wrist = 10, In = 29 }, Easing = Enum.EasingStyle.Linear }),
		key(2.509, { Arm = 123, Elbow = 26, Wrist = 10, In = 41, Waist = 6, Turn = 4,
			Off = { Arm = 124, Elbow = 33, Wrist = 10, In = 13 }, Easing = Enum.EasingStyle.Linear }),
		key(2.771, { Arm = 126, Elbow = 26, Wrist = 10, In = 51, Waist = 6, Turn = 4,
			Off = { Arm = 119, Elbow = 56, Wrist = 10, In = 11 }, Easing = Enum.EasingStyle.Linear }),
		key(3.033, { Arm = 119, Elbow = 56, Wrist = 10, In = 43, Waist = 6, Turn = 0,
			Off = { Arm = 119, Elbow = 61, Wrist = 10, In = 37 }, Easing = Enum.EasingStyle.Linear }),
	},
}
-- ...and the touchdown (the server's CycloneActive; the Cyclone demo starts it at Blender 3.75): the showcase's channel ->
-- draw-back -> thrust -> recovery (cyclone_bl.py _track from T_CH, at the Blender's own spacing). Overhead and arched,
-- trembling under the load (0 .. 0.25); the hands pulled back by the ears, the weight back, the chest open (0.53, T_THR);
-- both palms DRIVEN at the funnel, the body lunging after them (0.65, the snap: Back); the follow-through (1.00); the arms
-- come down (1.85) and home to the stance (2.85). Both: symmetric. StanceLegs: the caster walks on.
CastPose.Clips.CycloneRelease = {
	Trigger = 0.65, Rate = 30, Both = true, StanceLegs = true,
	Tremble = { Turn = 0.6, Arm = 1.3, From = 0.0, Full = 0.08, Until = 0.25 },
	Keys = {
		key(0.00, { Arm = 124, Elbow = 40, Wrist = 10, In = 30, Waist = 8 }),
		key(0.25, { Arm = 122, Elbow = 42, Wrist = 10, In = 30, Waist = 6, Easing = Enum.EasingStyle.Sine }),
		key(0.53, { Arm = 140, Elbow = 110, Wrist = 30, In = -15, Waist = 14, Easing = Enum.EasingStyle.Sine }),
		key(0.65, { Arm = 95, Elbow = 8, Wrist = 50, In = 20, Waist = -20, Easing = Enum.EasingStyle.Back }),
		key(1.00, { Arm = 91, Elbow = 14, Wrist = 45, In = 20, Waist = -12, Easing = Enum.EasingStyle.Sine }),
		key(1.85, { Arm = 40, Elbow = 50, Wrist = 15, In = 15, Waist = -4, Easing = Enum.EasingStyle.Sine }),
		key(2.85, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
-- ULTIMATE, Voltaic's Cascade, re-lit (2026-09-27): THE SUMMON (blender_scripts/voltaic/cascade_bl.py arm_angles /
-- hand_pos / Caster.pose). Both arms swing forward and up overhead together over 0.02-0.30 s (the showcase's ArmTop:
-- 166 degrees of swing with a 9-degree outward V), are HELD there trembling until the charge leaves the hands at 0.50
-- (the Trigger = VoltaicFX.Tuning.Cascade.Windup -- hardcoded, CastPose does not require VoltaicFX: retune Windup and
-- these keys move with it by hand), stay up while the sky answers, and come down over 0.62-0.95, so the caster is free
-- well before the storm breaks. This rig has no shoulder abduction (Aftershock's note), so the V is the swing leaned
-- outward: the showcase's hand direction (0.15 out, 0.24 forward, 0.96 up) is 16.7 degrees off vertical at a bearing
-- 32 degrees out from forward -> Arm 163 (180 = straight up in front) and In -32 (away from the aim line, both arms).
-- Tremble: the showcase's 0.035 studs at the hand over a ~2-stud arm = 1.0 degree of Arm, both arms (Both), from the
-- top to the launch (Until). StanceLegs: the caster walks on under it. Every client plays it on CascadeGather
-- (VoltaicClient.Handlers); the caster's own first-person arms are Viewmodel.Clips.CascadeSummon.
-- EVERY NUMBER HERE IS A PROPOSAL.
CastPose.Clips.CascadeSummon = {
	Trigger = 0.50, Rate = 40, Both = true, StanceLegs = true,
	Tremble = { Turn = 0, Arm = 1.0, From = 0.26, Full = 0.30, Until = 0.50 },
	Keys = {
		key(0.00, { Stance = true }),
		key(0.02, { Stance = true }),
		key(0.30, { Arm = 163, Elbow = 6, Wrist = 8, In = -32, Waist = 6, Easing = Enum.EasingStyle.Sine }),  -- overhead, a V
		key(0.50, { Arm = 163, Elbow = 6, Wrist = 8, In = -32, Waist = 6 }),                                    -- the launch
		key(0.62, { Arm = 163, Elbow = 6, Wrist = 8, In = -32, Waist = 5 }),                                    -- the sky answers
		key(0.95, { Stance = true, Easing = Enum.EasingStyle.Sine }),                                           -- down: free
	},
}
-- ===== GUST PAD (Zephyr v6 import, 2026-10-06; showcase pass 2026-10-07) -- ADD-ONLY BLOCK, the Gust Pad builder's ====
-- DEFENSE TECHNIQUE, Gust Pad (it replaces Deflect Gust). Three body clips, the showcase's caster (blender_scripts/zephyr/
-- spring/gust_pad_bl.py Caster.press / Caster.run; the v6 aqua reel keeps its beats), read off its joint keys into the
-- channel signs above. The left arm and the left leg are keyed in Off (OffKeys).
--   GustPad        THE PRESS, every client on the server's GustPad broadcast (ZephyrGustPad.Handlers). The wind-up
--                  (Blender -0.20: the body rises and leans back, the right palm high over the head, wrist cocked) is
--                  squeezed into the first 0.06 s (the key IS t = 0) -> the CONTACT (0.14, the Trigger = ZephyrGustPad
--                  .Tuning.Look.Contact): DOWN ON ONE KNEE -- the hips dropped 0.8 (hip 1.96 -> 1.16) and back a little,
--                  the right knee on the floor with its shin back, the left foot planted ahead (thigh level, shin
--                  upright), the spine bent 28 degrees in, the right palm FLAT on the floor ahead (a straight arm, the
--                  wrist cocked 60), the LEFT ARM THROWN BACK for balance at shoulder height -> 0.34 the weight settles a
--                  hair deeper (follow-through) -> 0.72 up into a staggered ready stance -> 1.10 the stance.
--                  StanceLegsFrom 0 (Umbra's rule): a caster who keeps moving keeps the stride -- no kneel-skating.
--   GustPadLaunch  a PLAYER stepped on a pad (ZephyrGustPad.Handlers.GustPadStep, on the step's server clock; t = 0 the
--                  step, the launch at Coil 0.26): the crouch soaks it in (0.14), the coiled hold (0.24: lower, chin
--                  in), THE ASCENT at 0.36 (Blender L + 0.10, a snap) -- a clean vertical line: the right fist punched
--                  straight up, the left arm back along the body, legs together, the left foot trailing -- held to
--                  1.30, back on the stance by 1.80.
--   GustPadRun     the showcase's run-on (ZephyrGustPad.Demo only; t = 0 is Run0 - 0.3 = 4.69): the counter-move (0.30:
--                  sink, lean back, arms drawn back), stride 1 (0.50: right foot ahead, left arm forward), the take-off
--                  (0.68: the right knee drives up, its arm swings up), the tuck in the hop (0.83: knees up, arms out),
--                  then GustPadLaunch's keys from the landing (0.88 = Land2 5.57).
-- Authored against the channel signs above, NOT YET SEEN IN PLAY. EVERY NUMBER HERE IS A PROPOSAL.
do
	-- GustPadLaunch's keys from a landing at clip time o (the crouch, the hold, the ascent, the fall back to the stance)
	local function launchKeys(o, out)
		out[#out + 1] = key(o + 0.14, { Arm = 36, Elbow = 16, Wrist = -10, In = -50, Waist = -22, Hip = 44, Knee = -92,
			Drop = 0.66, Off = { Arm = 36, Elbow = 16, Wrist = -10, In = -50, Hip = 44, Knee = -92 },
			Easing = Enum.EasingStyle.Quad })                                          -- landed: the crouch soaks it in
		out[#out + 1] = key(o + 0.24, { Arm = 32, Elbow = 14, Wrist = -12, In = -52, Waist = -25, Hip = 48, Knee = -100,
			Drop = 0.74, Off = { Arm = 32, Elbow = 14, Wrist = -12, In = -52, Hip = 48, Knee = -100 },
			Easing = Enum.EasingStyle.Sine })                                          -- the coiled hold
		out[#out + 1] = key(o + 0.36, { Arm = 174, Elbow = 0, Wrist = 0, In = 4, Waist = 3, Hip = 0, Knee = -4, Drop = 0,
			Off = { Arm = -20, Elbow = 6, Wrist = -6, In = 15, Hip = -10, Knee = -28 },
			Easing = Enum.EasingStyle.Quint })                                         -- THE ASCENT: fist up, a clean line
		out[#out + 1] = key(o + 1.30, { Arm = 172, Elbow = 2, Wrist = 0, In = 4, Waist = 2, Hip = 0, Knee = -6, Drop = 0,
			Off = { Arm = -22, Elbow = 6, Wrist = -6, In = 15, Hip = -12, Knee = -30 }, Easing = Enum.EasingStyle.Sine })
		out[#out + 1] = key(o + 1.80, { Stance = true, Easing = Enum.EasingStyle.Sine })
		return out
	end

	CastPose.Clips.GustPad = {
		Trigger = 0.14, Rate = 40, StanceLegsFrom = 0, OffKeys = true,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.06, { Arm = 140, Elbow = 22, Wrist = 42, In = -20, Waist = 7, Hip = 0, Knee = -4,
				Off = { Arm = 22, Elbow = 24, Wrist = 0, In = 10 }, Easing = Enum.EasingStyle.Quad }),   -- WIND-UP: palm high
			key(0.14, { Arm = 68, Elbow = 6, Wrist = 60, In = 4, Waist = -28, Hip = -4, Knee = -96, Drop = 0.80,
				Shift = -0.2, Off = { Arm = -62, Elbow = 10, Wrist = -10, In = 40, Hip = 84, Knee = -88 },
				Easing = Enum.EasingStyle.Quint }),                                    -- THE PRESS: down on one knee
			key(0.34, { Arm = 72, Elbow = 6, Wrist = 66, In = 4, Waist = -30, Hip = -4, Knee = -98, Drop = 0.88,
				Shift = -0.2, Off = { Arm = -56, Elbow = 12, Wrist = -10, In = 38, Hip = 86, Knee = -90 },
				Easing = Enum.EasingStyle.Back }),                                     -- the weight settles (follow-through)
			key(0.72, { Arm = 40, Elbow = 30, Wrist = -20, In = 8, Waist = -7, Hip = 12, Knee = -22, Drop = 0.16,
				Off = { Arm = 6, Elbow = 16, Wrist = 0, In = 6, Hip = -8, Knee = -12 },
				Easing = Enum.EasingStyle.Sine }),                                     -- up: a staggered ready stance
			key(1.10, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	}

	CastPose.Clips.GustPadLaunch = {
		Trigger = 0.26, Rate = 40, OffKeys = true,
		Keys = launchKeys(0, { key(0.00, { Stance = true }) }),
	}

	CastPose.Clips.GustPadRun = {
		Trigger = 1.14, Rate = 40, OffKeys = true,
		Keys = launchKeys(0.88, {
			key(0.00, { Stance = true }),
			key(0.30, { Arm = -28, Elbow = 18, Wrist = 0, In = 6, Waist = 5, Hip = 10, Knee = -24, Drop = 0.24,
				Off = { Arm = -28, Elbow = 18, Wrist = 0, In = 6 }, Easing = Enum.EasingStyle.Quad }),   -- the counter-move
			key(0.50, { Arm = -36, Elbow = 22, Wrist = 0, In = 4, Waist = -18, Hip = 36, Knee = -24, Drop = 0.08,
				Off = { Arm = 62, Elbow = 42, Wrist = 0, In = 14, Hip = -26, Knee = -42 },
				Easing = Enum.EasingStyle.Sine }),                                     -- stride 1
			key(0.68, { Arm = 112, Elbow = 32, Wrist = 0, In = 6, Waist = -17, Hip = 70, Knee = -84, Drop = 0,
				Off = { Arm = -36, Elbow = 18, Wrist = 0, In = 6, Hip = -20, Knee = -12 },
				Easing = Enum.EasingStyle.Quad }),                                     -- the take-off: the knee drives up
			key(0.83, { Arm = 68, Elbow = 22, Wrist = 0, In = -48, Waist = -7, Hip = 52, Knee = -84, Drop = 0,
				Off = { Arm = 68, Elbow = 22, Wrist = 0, In = -48, Hip = 46, Knee = -80 },
				Easing = Enum.EasingStyle.Sine }),                                     -- the hop: knees tucked, arms out
		}),
	}
end
-- ===== end GUST PAD =========================================================================================

----------------------------------------------------------------------------------------------------------------- Umbra (Phase 4)
-- UMBRA'S THIRD-PERSON CLIPS (Phase 4 stage A, 2026-09-28). The owner's approved Phase 3 poses, key for key:
--   Shadow Dart   styleboard_magicflow/poses/shadow_dart_castpose_w230.json   (the 2.3 s charge, the owner's number)
--   Mark          A/poses/mark_castpose.json
--   Shadow Step, Eclipse (charge + open), Decoy Double (cast + the decoy's own idle)   B/poses/CastPose_*.json
-- Every body clip is played by UmbraAnim (ReplicatedStorage.IceMagic.UmbraAnim), never from here; see TRIGGERS.md for
-- which broadcast plays which, and on which clock.
--
-- INSTALL: paste this whole block into CastPose.lua on the line AFTER the "end GUST PAD" banner (2026-10-27: it
-- followed CastPose.Clips.FireballShieldL, which left with the Cinder Shield). It needs, and finds in scope
-- there: key(), leftHanded() and the CastPose table. No other line of CastPose changes -- every field used below is one
-- step() already reads:
--   Turn            the torso's yaw (keyBody, buildOffsets' Waist joint)
--   Drop            the Root joint (Aftershock, 2026-09-25)
--   OffKeys / Off   the other arm, and an Off leg (Off.Hip / Off.Knee: the per-side legs, Cross-Slash's glide path)
--   StanceLegs      the legs stay the stance's, stride and all
--   StanceLegsFrom  from that clip time on, a body that is really MOVING gets the stance's legs back (Aftershock's rule)
--   Tremble         { Turn, Arm, From, Full }; on a Both clip both arms shake
--   Hold / ReleaseRate / Rate / Both / Trigger / Stance keys   as every other clip
-- ...except LoopFrom / LoopLength, which CastPose itself never reads: as with CycloneForm, the LOOP is the caller's clock
-- (CastPose.PlayClocked). UmbraDecoyPoser supplies it for UmbraDecoyReady. Nothing to change in the module for it.
--
-- THE JSONS' EASING NAMES ("Quad", "Enum.EasingStyle.Quint") are Enum.EasingStyle values here; CastPose eases every
-- segment Out by its DESTINATION key's style, which is what the Phase 3 replica (B/scripts/umb_lib.py) did, so the
-- approved videos are what these keys play. A key with no Easing is Quad, as in the approved files.
--
-- TIMES THAT ARE TUNING, READ FROM UmbraTuning (pure data, no requires; VFXLibrary -- which this module already
-- requires at the top -- has required it by the time this line runs, so FindFirstChild is enough and nothing waits):
--   UmbraTuning.ShadowDart.Windup  the click to the release (OWNER: 2.3). The charge keys scale with it by Windup / 2.3;
--                                  the snap (0.03), the follow-through (+0.08) and the ease home (+0.50) keep their
--                                  lengths. At 2.3 every key is the approved file's exactly.
--   UmbraTuning.Eclipse.WindupTime the held press before the open (1.0). The charge keys and the Tremble scale by it the
--                                  same way; at 1.0 they are the approved file's.
-- A missing UmbraTuning falls back to the approved numbers, so this block can never take CastPose down.
--
-- ADDITIONS TO THE APPROVED FILES (each flagged in TRIGGERS.md; standing still, none of them changes a frame of the
-- approved videos, which were all shot standing):
--   UmbraShadowStep     StanceLegsFrom = 0.12: from the re-form on, a body that runs on gets its stride back instead of
--                       gliding 0.4 s on bent knees
--   UmbraEclipseCharge  StanceLegsFrom = 0 (the same rule as Shadow Dart's): the owner has not said whether the caster is
--   UmbraEclipseOpen    held in place during the windup (B's open question); rooted, it changes nothing, and walking it
--                       strides instead of sliding in a crouch
--   UmbraDecoyDouble    StanceLegs = true: its keys never name a leg (B's intent: an arm cue only), but without it a
--                       caster who casts on the run would have both legs pulled straight for 0.65 s
--   UmbraDecoyDoubleL   NEW, the same cue left-handed: the server puts the decoy on Umbra's LEFT when a wall blocks the
--                       right (UmbraHandler.castDecoy), and the right arm must not open away from the copy
-- NOT added, kept as approved: UmbraShadowStep is ONE-armed (no Both) although B's comment says "hands pulled in to the
-- chest" -- the replica played it one-armed and that is what the owner approved. Add Both = true if both were meant.

local UMBRA_T = nil
do
	local m = script.Parent:FindFirstChild("UmbraTuning")
	local ok, mod = pcall(function()
		return m and require(m)
	end)
	if ok and type(mod) == "table" then
		UMBRA_T = mod
	else
		warn("[CastPose] UmbraTuning unavailable, Umbra's clips use the approved timings: " .. tostring(mod))
	end
end

-- the dart: the click to the release, and the share of the approved 2.3 s the charge keys stretch by
local UMB_W = math.max(0.2, tonumber(UMBRA_T and UMBRA_T.ShadowDart and UMBRA_T.ShadowDart.Windup) or 2.3)
local UMB_WS = UMB_W / 2.3
-- Eclipse's held press, and its share of the approved 1.0 s
local UMB_EW = math.max(0.3, tonumber(UMBRA_T and UMBRA_T.Eclipse and UMBRA_T.Eclipse.WindupTime) or 1.0)
local UMB_ES = UMB_EW / 1.0

-- M1, SHADOW DART (the MAGIC FLOW board, Windup 2.30 s -- the owner: "the time ... from press till the bullet shoots ...
-- should be 2.3 sec"). TUCK the arm in against the body, forearm up, as the flow starts to gather; GATHER, a slow drift
-- -- the tucked hand comes forward and in, the wrist cups, the chest settles; BRACE, the stance sets (knees give, chest
-- turns in) and the left hand comes in against the right (on the blocky rig it cannot reach the right elbow, so the brace
-- is both hands together at the front of the chest -- A's note); HOLD, still, the telegraph; RELEASE on the Trigger, the
-- forearm snapping out as the dart leaves the hand; follow-through; home on the stance. The left arm is the Off arm.
-- StanceLegsFrom 0: standing, the knees give into the brace; a body that is MOVING keeps its stride and its Drop eases to
-- 0, so an M1 never makes a runner glide on bent legs. Under Eclipse the whole cycle runs M1RateMult faster: UmbraAnim
-- plays it on a clock scaled by it (PlayClocked), so the keys never change.
CastPose.Clips.UmbraShadowDart = {
	Trigger = UMB_W, Rate = 40, OffKeys = true, StanceLegs = false, StanceLegsFrom = 0, ReleaseRate = 14,
	Keys = {
		key(0.00, { Stance = true }),                                                                     -- the click
		key(0.30 * UMB_WS, { Arm = 16, Elbow = 118, Wrist = 34, In = 22, Waist = -6, Turn = -6, Hip = 14.2, Knee = -25.8,
			Drop = 0.05, Off = { Arm = 34, Elbow = 60, Wrist = 0, In = 22 }, Easing = Enum.EasingStyle.Quad }),      -- TUCK
		key(1.30 * UMB_WS, { Arm = 34, Elbow = 104, Wrist = 44, In = 36, Waist = -8, Turn = -2, Hip = 19.1, Knee = -34.7,
			Drop = 0.09, Off = { Arm = 40, Elbow = 58, Wrist = 0, In = 26 }, Easing = Enum.EasingStyle.Sine }),      -- GATHER
		key(1.65 * UMB_WS, { Arm = 72, Elbow = 48, Wrist = 28, In = 60, Waist = -10, Turn = 12, Hip = 25.7, Knee = -46.4,
			Drop = 0.16, Off = { Arm = 92, Elbow = 8, Wrist = 15, In = 64 }, Easing = Enum.EasingStyle.Quint }),     -- BRACE
		key(UMB_W - 0.03, { Arm = 73, Elbow = 49, Wrist = 28, In = 60, Waist = -10, Turn = 12, Hip = 25.7, Knee = -46.4,
			Drop = 0.16, Off = { Arm = 92, Elbow = 8, Wrist = 15, In = 64 }, Easing = Enum.EasingStyle.Sine }),      -- HOLD
		key(UMB_W, { Arm = 98, Elbow = 0, Wrist = -28, In = 38, Waist = -12, Turn = 16, Hip = 25.7, Knee = -46.4,
			Drop = 0.16, Off = { Arm = 92, Elbow = 8, Wrist = 15, In = 64 }, Easing = Enum.EasingStyle.Quint }),     -- RELEASE
		key(UMB_W + 0.08, { Arm = 95, Elbow = 4, Wrist = -32, In = 36, Waist = -11, Turn = 15, Hip = 25.7, Knee = -46.4,
			Drop = 0.16, Off = { Arm = 86, Elbow = 8, Wrist = 15, In = 64 }, Easing = Enum.EasingStyle.Quad }),      -- follow
		key(UMB_W + 0.50, { Stance = true, Easing = Enum.EasingStyle.Sine }),                                  -- home
	},
}

-- TECHNIQUE, MARK (A, 2026-09-27): quick and unshowy, 0.36 s end to end. The LEFT arm (Off) snaps out at the target and
-- the mark applies on the Trigger (0.08); held a beat -- the glance, which is only the torso's turn, there being no head
-- channel -- and home. The right (lead) arm is keyed to hold the Ready posture, so a Shadow Dart hand stays put.
-- StanceLegs: the run goes on under it.
CastPose.Clips.UmbraMark = {
	Trigger = 0.08, Rate = 45, OffKeys = true, StanceLegs = true, ReleaseRate = 16,
	Keys = {
		key(0.00, { Stance = true }),
		key(0.08, { Arm = 40, Elbow = 50, Wrist = 0, In = 18, Waist = -4, Turn = -10,
			Off = { Arm = 90, Elbow = 4, Wrist = -8, In = 20 }, Easing = Enum.EasingStyle.Quint }),              -- POINT
		key(0.20, { Arm = 40, Elbow = 50, Wrist = 0, In = 18, Waist = -4, Turn = -9,
			Off = { Arm = 88, Elbow = 6, Wrist = -6, In = 20 }, Easing = Enum.EasingStyle.Sine }),               -- the glance
		key(0.36, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}

-- PRIMARY, SHADOW STEP (B; the owner: "no physical dash or run cycle at all"). A small pre-dissolve cue and nothing else:
-- the knees give, the right hand pulls in to the chest, a short lean -- and the smoke takes the body at its lowest (0.06).
-- It re-forms at the destination IN THAT SAME PULLED-IN POSE (0.12 = UmbraTuning.ShadowStep.DissolveTime, when the
-- server moves it) and straightens back onto the stance by 0.55. The 0.12 key is where UmbraAnim's clock HOLDS until the
-- body has really been moved (ShadowStepIn), so the re-form is never drawn at the old spot. StanceLegsFrom 0.12: added,
-- see the header.
CastPose.Clips.UmbraShadowStep = {
	Trigger = 0, Rate = 40, StanceLegsFrom = 0.12,
	Keys = {
		key(0.00, { Stance = true }),
		key(0.06, { Arm = 22, Elbow = 100, Wrist = -12, In = 34, Waist = -16, Hip = 23, Knee = -45, Drop = 0.16,
			Easing = Enum.EasingStyle.Quad }),                                                                     -- drawn in
		key(0.12, { Arm = 22, Elbow = 100, Wrist = -12, In = 34, Waist = -16, Hip = 23, Knee = -45, Drop = 0.16 }), -- moved here
		key(0.30, { Arm = 34, Elbow = 64, Wrist = -2, In = 20, Waist = -8, Hip = 19, Knee = -37, Drop = 0.1,
			Easing = Enum.EasingStyle.Quad }),                                                                     -- rising
		key(0.55, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}

-- ULTIMATE, ECLIPSE (B). THE GATHER, held -- the Ultimate's telegraph: both hands come up in front of the chest, the
-- blocky hands' inner faces turned to each other a hand's width apart, the knees give and the body sinks; the mass forms
-- in that space. Then the hands PRESS it, closing by about a fifth over the hold while both arms tremble under the load
-- (Tremble, both arms: Both), the body sinking a touch further. Hold: the last key stays until the open plays over it.
CastPose.Clips.UmbraEclipseCharge = {
	Trigger = UMB_EW, Hold = true, Both = true, Rate = 20, StanceLegsFrom = 0,
	Tremble = { Turn = 0.5, Arm = 0.9, From = 0.30 * UMB_ES, Full = 0.95 * UMB_ES },
	Keys = {
		key(0.00, { Stance = true }),
		key(0.24 * UMB_ES, { Arm = 66, Elbow = 50, Wrist = 4, In = 18, Waist = -8, Hip = 20, Knee = -40, Drop = 0.12,
			Easing = Enum.EasingStyle.Quad }),                                                                     -- GATHER
		key(0.62 * UMB_ES, { Arm = 67, Elbow = 50, Wrist = 6, In = 21, Waist = -10, Hip = 22, Knee = -43, Drop = 0.14,
			Easing = Enum.EasingStyle.Sine }),
		key(UMB_EW, { Arm = 68, Elbow = 50, Wrist = 8, In = 24, Waist = -11, Hip = 23, Knee = -45, Drop = 0.16,
			Easing = Enum.EasingStyle.Sine }),                                                                     -- PRESSED
	},
}
-- ...THE OPEN, on the server's EclipseStart: the arms spread outward -- level, wide, palms turned out (Wrist cocked back)
-- -- and the chest opens with them as the body comes up out of the crouch (the keys after the first name no leg and no
-- Drop, so the knees straighten and the body rises: that is the move); full spread on the Trigger (0.10), where the
-- pulse and the domain go out. Then back onto the stance by 0.95. Its first key is the pressed pose, so an open that
-- comes with no charge before it (a server that sends no EclipseCharge) still reads as a squeeze and a spread.
CastPose.Clips.UmbraEclipseOpen = {
	Trigger = 0.10, Both = true, Rate = 36, StanceLegsFrom = 0,
	Keys = {
		key(0.00, { Arm = 68, Elbow = 50, Wrist = 8, In = 24, Waist = -11, Hip = 23, Knee = -45, Drop = 0.16 }),
		key(0.10, { Arm = 90, Elbow = 6, Wrist = 28, In = -62, Waist = 6, Easing = Enum.EasingStyle.Quint }),      -- SPREAD
		key(0.32, { Arm = 86, Elbow = 10, Wrist = 22, In = -58, Waist = 5, Easing = Enum.EasingStyle.Sine }),
		key(0.95, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}

-- TECHNIQUE, DECOY DOUBLE (B, option A). The CASTER's cue while the copy peels off its right side: the right arm opens
-- out and down toward it, letting it go, and the chest turns a little away -- the body releasing a layer of itself, not
-- throwing or summoning. Small, then straight back to the stance. StanceLegs: added, see the header.
CastPose.Clips.UmbraDecoyDouble = {
	Trigger = 0.10, Rate = 30, StanceLegs = true,
	Keys = {
		key(0.00, { Stance = true }),
		key(0.10, { Arm = 22, Elbow = 30, Wrist = -12, In = -34, Waist = 2, Turn = 8, Easing = Enum.EasingStyle.Quad }),
		key(0.30, { Arm = 26, Elbow = 34, Wrist = -8, In = -30, Waist = 1, Turn = 6, Easing = Enum.EasingStyle.Sine }),
		key(0.65, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
-- ...and the same cue with the LEFT hand, for a decoy the server put on the left (a wall on the right). leftHanded flips
-- the torso's Turn and makes the left arm the lead; In mirrors on its own (armOffset signs it per side).
CastPose.Clips.UmbraDecoyDoubleL = leftHanded(CastPose.Clips.UmbraDecoyDouble)

-- THE DECOY'S OWN IDLE (B, NEW: nothing posed a decoy before -- it is a clone of a body whose Animate script is off, so
-- it stood in the rig's rest pose, arms hanging). The Ready stance a real Umbra stands in, breathing and shifting its
-- weight: the chest dips on each breath (Waist), the arms rise a hair, the weight moves from one leg to the other (one
-- knee eases, the hips turn a little toward the other) -- no locomotion. A 4 s loop whose last key is its first, looped
-- by the CALLER (UmbraDecoyPoser plays it with PlayClocked on a clock that wraps LoopFrom .. LoopFrom + LoopLength,
-- Cyclone's convention). Hold, so it never lets go on its own; OffKeys: the left arm and leg are keyed in Off. Rate 10
-- is B's: it smooths the Sine keys' corners, as the approved replica did.
CastPose.Clips.UmbraDecoyReady = {
	Hold = true, OffKeys = true, Rate = 10, LoopFrom = 0, LoopLength = 4,
	Keys = {
		key(0, { Arm = 38, Elbow = 48, Wrist = 0, In = 16, Waist = -3, Turn = 0, Hip = 0, Knee = 0,
			Off = { Arm = 38, Elbow = 48, Wrist = 0, In = 16, Hip = 0, Knee = 0 }, Easing = Enum.EasingStyle.Sine }),
		key(1, { Arm = 40, Elbow = 51, Wrist = 0, In = 17, Waist = -4.5, Turn = 2.5, Hip = 2, Knee = -7,
			Off = { Arm = 39, Elbow = 49, Wrist = 0, In = 16, Hip = 0, Knee = 0 }, Easing = Enum.EasingStyle.Sine }),
		key(2, { Arm = 38, Elbow = 48, Wrist = 0, In = 16, Waist = -3, Turn = 0, Hip = 0, Knee = 0,
			Off = { Arm = 38, Elbow = 48, Wrist = 0, In = 16, Hip = 0, Knee = 0 }, Easing = Enum.EasingStyle.Sine }),
		key(3, { Arm = 39, Elbow = 49, Wrist = 0, In = 16, Waist = -4.5, Turn = -2.5, Hip = 0, Knee = 0,
			Off = { Arm = 40, Elbow = 51, Wrist = 0, In = 17, Hip = 2, Knee = -7 }, Easing = Enum.EasingStyle.Sine }),
		key(4, { Arm = 38, Elbow = 48, Wrist = 0, In = 16, Waist = -3, Turn = 0, Hip = 0, Knee = 0,
			Off = { Arm = 38, Elbow = 48, Wrist = 0, In = 16, Hip = 0, Knee = 0 }, Easing = Enum.EasingStyle.Sine }),
	},
}

-- ===== SKYRIDER (Zephyr v6 import, 2026-10-06) -- ADD-ONLY BLOCK, the Skyrider builder's ==================
-- ZEPHYR'S MOBILITY TECHNIQUE, Skyrider (it replaces Gust Jump): the rider on the bird of wind, from the reviewed
-- spring build's rider (blender_scripts/zephyr/spring/skyrider_bl.py WTRACK / KTRACK: STAND -> CROUCH -> JUMP -> TUCK
-- -> LAND -> KNEEL, G_WIND -> G_PUSH, and kneel_pose's wobble), which the v5 / v6 aqua builds keep. Every client plays
-- these from the broadcasts (IceMagic.ZephyrSkyrider.Handlers); the rider's own arms are Viewmodel.Clips.Skyrider*.
--   SkyriderMount   THE SUMMON, 0 .. 0.44 (ZephyrSkyrider.Tuning.SummonTime, hardcoded: this module does not require
--                   Zephyr modules): the crouch (0.14), the hop with both arms flung up (0.30), the tuck as the bird
--                   comes under (0.44), the landing deep in the kneel (0.50), and the KNEEL (0.88), held for the ride:
--                   the right knee down on the bird's back (thigh under the hip, shin back along it), the left foot
--                   planted forward, the torso leaning in, the right hand low by the knee, the left forward at the
--                   chest. Drop lowers the body under the root -- the root rides SeatBelowRoot (2.4) over the bird's
--                   back, so the knee and the planted foot land on it.
--   SkyriderGust    THE GUST FLAP, on the press (WindUp 0.2): the left hand pulls back and up by the head as the wings
--                   gather (G_WIND, 0.18), thrusts forward at the target on the stroke (G_PUSH, 0.24 = the launch),
--                   holds through the cone (0.65), and is back in the kneel by 1.05 (KTRACK, from the 3.10 wind-up).
--   SkyriderWobble  HIT: the body is thrown and twisted, the free (left) hand flung out and up to catch the balance
--                   (kneel_pose's hitw catch: hand_l -> (-2.0, 0.45, 3.55)), back in the kneel by 0.75.
-- These three are HELD clips (Hold: the kneel stays until ZephyrSkyrider lets go at the dismount, CastPose.Stop) with the
-- legs keyed (StanceLegs false) and the left arm keyed in Off (OffKeys). Authored against the channel signs above,
-- NOT YET SEEN IN PLAY. EVERY NUMBER HERE IS A PROPOSAL.
do
	local KNEEL = { Arm = 14, Elbow = 24, Wrist = 8, In = 6, Hip = -12, Knee = -100, Waist = -24, Drop = 0.35,
		Off = { Arm = 62, Elbow = 52, Wrist = -8, In = 18, Hip = 82, Knee = -88 } }
	local function kneel(t, easing, extra)
		local k = table.clone(KNEEL)
		k.Off = table.clone(KNEEL.Off)
		k.Easing = easing
		if extra then
			for ch, v in pairs(extra) do
				if ch == "Off" then
					for c2, v2 in pairs(v) do k.Off[c2] = v2 end
				else
					k[ch] = v
				end
			end
		end
		return key(t, k)
	end
	CastPose.Clips.SkyriderMount = {
		Trigger = 0.44, Rate = 26, Hold = true, OffKeys = true, StanceLegs = false,
		Keys = {
			key(0.00, { Stance = true }),
			key(0.14, { Arm = -36, Elbow = 30, Wrist = 6, In = -8, Hip = 46, Knee = -80, Waist = -26, Drop = 0.7,
				Off = { Arm = -36, Elbow = 30, Wrist = 6, In = -8, Hip = 46, Knee = -80 },
				Easing = Enum.EasingStyle.Quad }),                                   -- CROUCH: the arms back, the knees in
			key(0.30, { Arm = 160, Elbow = 14, Wrist = 0, In = -18, Hip = -6, Knee = -12, Waist = 8, Drop = 0,
				Off = { Arm = 160, Elbow = 14, Wrist = 0, In = -18, Hip = -6, Knee = -12 },
				Easing = Enum.EasingStyle.Quint }),                                  -- JUMP: long, both arms flung up
			key(0.44, { Arm = 70, Elbow = 50, Wrist = 0, In = 4, Hip = 40, Knee = -70, Waist = -10, Drop = 0.2,
				Off = { Arm = 118, Elbow = 30, Wrist = 0, In = -20, Hip = 56, Knee = -40 },
				Easing = Enum.EasingStyle.Sine }),                                   -- TUCK: the bird comes under
			kneel(0.50, Enum.EasingStyle.Quad, { Arm = 8, Elbow = 30, Wrist = 10, Hip = -18, Knee = -110, Waist = -34,
				Drop = 0.55, Off = { Arm = 96, Elbow = 40, In = -30, Hip = 88, Knee = -96 } }),   -- LAND: deep, balancing
			kneel(0.88, Enum.EasingStyle.Back),                                      -- the KNEEL, held for the ride
		},
	}
	CastPose.Clips.SkyriderGust = {
		Trigger = 0.24, Rate = 34, Hold = true, OffKeys = true, StanceLegs = false,
		Keys = {
			kneel(0.00, Enum.EasingStyle.Sine),
			kneel(0.18, Enum.EasingStyle.Quad, { Waist = -32, Drop = 0.55,
				Off = { Arm = 128, Elbow = 112, In = 24, Wrist = -10 } }),          -- G_WIND: the left hand pulled up by the head
			kneel(0.24, Enum.EasingStyle.Quint, { Waist = -34, Drop = 0.45,
				Off = { Arm = 96, Elbow = 4, In = 18, Wrist = -24 } }),             -- G_PUSH: thrust at the target
			kneel(0.65, nil, { Waist = -34, Drop = 0.45, Off = { Arm = 94, Elbow = 6, In = 18, Wrist = -22 } }),
			kneel(1.05, Enum.EasingStyle.Back),                                      -- back in the kneel (KTRACK 4.15)
		},
	}
	CastPose.Clips.SkyriderWobble = {
		Trigger = 0.07, Rate = 36, Hold = true, OffKeys = true, StanceLegs = false,
		Keys = {
			kneel(0.00, Enum.EasingStyle.Sine),
			kneel(0.07, Enum.EasingStyle.Quad, { Arm = 20, Elbow = 30, Waist = -14, Turn = -20,
				Off = { Arm = 150, Elbow = 10, In = -64, Wrist = 0 } }),            -- thrown: the free hand out and up
			kneel(0.40, nil, { Arm = 18, Elbow = 28, Waist = -16, Turn = -14,
				Off = { Arm = 144, Elbow = 14, In = -60, Wrist = 0 } }),
			kneel(0.75, Enum.EasingStyle.Sine),
		},
	}
	-- SkyriderFall  THE DISMOUNT (skyrider_bl FTRACK, clip time from the dismount; the showcase lands at ~0.93 s): out
	-- of the kneel into FALL (both arms flung up and out, the torso back, one leg trailing) by 0.24, held down the drop,
	-- the landing crouch LANDC (deep, the right hand low forward, the left out for balance) on the touchdown, RISE, and
	-- back to the stance. Not held: it lets go by itself. ZephyrFX_Skyrider.Demo plays it on the showcase's clock.
	CastPose.Clips.SkyriderFall = {
		Trigger = 0.0, Rate = 30, OffKeys = true, StanceLegs = false,
		Keys = {
			kneel(0.00, Enum.EasingStyle.Sine),
			key(0.24, { Arm = 150, Elbow = 22, Wrist = 0, In = -38, Hip = 24, Knee = -52, Waist = 14, Drop = 0,
				Off = { Arm = 156, Elbow = 18, Wrist = 0, In = -42, Hip = -10, Knee = -34 },
				Easing = Enum.EasingStyle.Quart }),                                  -- FALL
			key(0.875, { Arm = 146, Elbow = 26, Wrist = 0, In = -36, Hip = 28, Knee = -58, Waist = 12, Drop = 0,
				Off = { Arm = 152, Elbow = 22, Wrist = 0, In = -40, Hip = -6, Knee = -40 },
				Easing = Enum.EasingStyle.Sine }),
			key(1.015, { Arm = 30, Elbow = 30, Wrist = 8, In = 6, Hip = 56, Knee = -96, Waist = -32, Drop = 0.85,
				Off = { Arm = 72, Elbow = 18, Wrist = 0, In = -56, Hip = 52, Knee = -92 },
				Easing = Enum.EasingStyle.Quart }),                                  -- LANDC: the touchdown
			key(1.145, { Arm = 30, Elbow = 30, Wrist = 8, In = 6, Hip = 54, Knee = -92, Waist = -30, Drop = 0.8,
				Off = { Arm = 70, Elbow = 18, Wrist = 0, In = -54, Hip = 50, Knee = -88 } }),
			key(1.675, { Arm = 12, Elbow = 16, Wrist = 0, In = -8, Hip = 12, Knee = -18, Waist = -8, Drop = 0.2,
				Off = { Arm = 14, Elbow = 16, Wrist = 0, In = -10, Hip = 10, Knee = -16 },
				Easing = Enum.EasingStyle.Back }),                                   -- RISE
			key(2.0, { Stance = true, Easing = Enum.EasingStyle.Sine }),
		},
	}
end
-- ===== end SKYRIDER =========================================================================================

-- ===== UPDRAFT (Zephyr v6 import, 2026-10-07) -- ADD-ONLY BLOCK, the Updraft builder's =========================
-- ZEPHYR'S PASSIVE, Updraft: the showcase's jump (blender_scripts/zephyr/spring/updraft_bl.py KEYS, kept by the v6 aqua
-- build), its hand and foot targets turned into these channels by IK chords -- the arm's swing plane gives Arm + In
-- (a back-swung arm is a negative Arm with In turning it out), the leg's chord gives Hip + Knee, spine + pelvis pitch
-- the Waist, spine yaw the Turn, the hips' height the Drop / Shift. Right = the lead side, left in Off (OffKeys).
--   UpdraftJump  the whole hero shot; clip time = showcase time + 0.30 (ZephyrUpdraft.Tuning.Demo.ClipOffset): the
--                rest (0.06), THE DIP (0.23: hips down 0.55, chest pitched in, arms swung back), the push (0.30 =
--                take-off: legs straight, arms up and forward), RIDING THE WIND (0.60 / 0.82: the right knee up in
--                front, the left leg trailing long, the arms out wide -- the left forward and high, the right back and
--                low), the wind-up (0.948: the chest coils right, the right hand cocked back, the left reaching at
--                the target), THE FLICK (0.995: a whip-fast snap forward-down, the off-hand pulled back), the
--                follow-through (1.16), riding again (1.40), the fall (1.628: legs reach for the floor, arms out),
--                the landing (1.698), the squash (1.828: hips down 0.68), the springy recovery (2.198), the stance.
--                Played by ZephyrUpdraft.Demo with PlayClocked on its own (filming) clock.
--   UpdraftRide  LIVE, from a holder's take-off (ZephyrUpdraft's watcher: PlayClocked on seconds since the take-off,
--                only when no other clip owns the body): the push into the riding shape, HELD while airborne.
--   UpdraftLand  LIVE, on that body's landing (only if it is still on UpdraftRide): the squash and the recovery; a body
--                that lands moving gets the stance's stride back at once (StanceLegsFrom 0).
-- Authored from the showcase's keys, NOT YET SEEN IN PLAY. EVERY NUMBER HERE IS A PROPOSAL.
do
	local function pz(t, easing, ch, off)
		ch.Off = off
		ch.Easing = easing
		return key(t, ch)
	end
	local S, Q5, C3, BK, LN = Enum.EasingStyle.Sine, Enum.EasingStyle.Quint, Enum.EasingStyle.Cubic,
		Enum.EasingStyle.Back, Enum.EasingStyle.Linear
	-- the shapes (degrees; Drop / Shift studs), each the showcase key it is named for
	local function REST(t, e)
		return pz(t, e, { Arm = 5, Elbow = 20, Wrist = 0, In = 0, Hip = 0, Knee = 0, Waist = -3 },
			{ Arm = 5, Elbow = 20, Wrist = 0, In = 0, Hip = 0, Knee = 0 })
	end
	local function PUSH(t, e)                                   -- 0.00: legs straight off the floor, arms up-forward
		return pz(t, e, { Arm = 35, Elbow = 60, In = -20, Hip = -5, Knee = -4, Waist = 1, Shift = 0.05 },
			{ Arm = 35, Elbow = 60, In = -20, Hip = -7, Knee = -4 })
	end
	local function LIFT(t, e)                                   -- 0.09: the right knee comes up, the arms swing high
		return pz(t, e, { Arm = 60, Elbow = 60, In = -28, Hip = 36, Knee = -69, Waist = 5 },
			{ Arm = 60, Elbow = 60, In = -28, Hip = -10, Knee = -4 })
	end
	local function RIDE(t, e, k)                                -- 0.30 / 0.52 / 1.10: riding the wind
		k = k or 0
		return pz(t, e, { Arm = -72 - 5 * k, Elbow = 20, Wrist = -12, In = 54 + 2 * k, Hip = 85 + 5 * k, Knee = -91,
			Waist = -1, Turn = 3 },
			{ Arm = 105 + 3 * k, Elbow = 25, Wrist = 10, In = -49 - 2 * k, Hip = -28 - 2 * k, Knee = -4 })
	end
	local function LAND(t, e)                                   -- T_LAND: arms out, feet down
		return pz(t, e, { Arm = 66, Elbow = 30, In = -65, Hip = 9, Knee = -4, Waist = -2 },
			{ Arm = 66, Elbow = 30, In = -65, Hip = -4, Knee = -4 })
	end
	local function SQUASH(t, e)                                 -- T_LAND + 0.13: the landing squash
		return pz(t, e, { Arm = 36, Elbow = 25, In = -30, Hip = 56, Knee = -102, Waist = -34, Drop = 0.68, Shift = 0.12 },
			{ Arm = 36, Elbow = 25, In = -30, Hip = 34, Knee = -99 })
	end
	local function RECOVER(t, e)                                -- T_LAND + 0.50: the springy recovery (overshoot)
		return pz(t, e, { Arm = 15, Elbow = 20, In = -20, Hip = 15, Knee = -19, Waist = -5, Drop = 0.03, Shift = 0.04 },
			{ Arm = 15, Elbow = 20, In = -20, Hip = 0, Knee = -16 })
	end

	CastPose.Clips.UpdraftJump = {
		Trigger = 0.30, Rate = 36, OffKeys = true, StanceLegs = false,
		Keys = {
			key(0.00, { Stance = true }),
			REST(0.06, S),
			pz(0.23, S, { Arm = -45, Elbow = 20, In = 16, Hip = 57, Knee = -90, Waist = -31, Drop = 0.55, Shift = -0.12 },
				{ Arm = -45, Elbow = 20, In = 16, Hip = 41, Knee = -92 }),                   -- THE DIP
			PUSH(0.30, Q5),                                                                 -- take-off
			LIFT(0.39, C3),
			RIDE(0.60, S),                                                                  -- RIDING THE WIND
			RIDE(0.82, S, 1),
			pz(0.948, S, { Arm = -70, Elbow = 70, Wrist = 26, In = 50, Hip = 89, Knee = -94, Waist = -6, Turn = -23 },
				{ Arm = 52, Elbow = 25, In = -17, Hip = -29, Knee = -4 }),                  -- the wind-up
			pz(0.995, Q5, { Arm = 62, Elbow = 12, Wrist = -32, In = -4, Hip = 74, Knee = -88, Waist = -13, Turn = 17 },
				{ Arm = -73, Elbow = 20, In = 70, Hip = -33, Knee = -4 }),                  -- THE FLICK
			pz(1.16, BK, { Arm = 52, Elbow = 15, Wrist = -40, In = 12, Hip = 79, Knee = -90, Waist = -10, Turn = 23 },
				{ Arm = -73, Elbow = 20, In = 70, Hip = -31, Knee = -4 }),                  -- follow-through
			RIDE(1.40, S, 0.6),                                                             -- riding again
			pz(1.628, S, { Arm = 80, Elbow = 30, In = -77, Hip = 14, Knee = -15, Waist = 1 },
				{ Arm = 80, Elbow = 30, In = -75, Hip = 8, Knee = -28 }),                   -- the fall: reaching down
			LAND(1.698, LN),
			SQUASH(1.828, C3),
			RECOVER(2.198, BK),
			key(2.75, { Stance = true, Easing = S }),
		},
	}
	CastPose.Clips.UpdraftRide = {
		Trigger = 0, Rate = 30, Hold = true, Repeat = true, OffKeys = true, StanceLegs = false,
		Keys = {
			key(0.00, { Stance = true }),
			PUSH(0.05, Q5),
			LIFT(0.14, C3),
			RIDE(0.35, S),
			RIDE(0.57, S, 1),
		},
	}
	CastPose.Clips.UpdraftLand = {
		Trigger = 0, Rate = 30, Repeat = true, OffKeys = true, StanceLegs = false, StanceLegsFrom = 0,
		Keys = {
			LAND(0.00, LN),
			SQUASH(0.13, C3),
			RECOVER(0.50, BK),
			key(1.05, { Stance = true, Easing = S }),
		},
	}
end
-- ===== end UPDRAFT ==========================================================================================

-- WITCH'S BREW (Toxin Epic skin, 2026-10-23): the caster's body acting with the worn cauldron. Generated from
-- vfx_blocking/toxin/witchs_brew_2026_10_20/blender/wb_body.py (previewed in wb_body_anim.py), keyed to WitchsBrewFX's
-- beats; played by WitchsBrewFX from the hooks that move the pot.
CastPose.Clips.WBSplash = {
	Rate = 50, Repeat = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.04, { Arm = 176, Elbow = 142, Wrist = 10, In = -16, Waist = 5, Turn = -12, Easing = Enum.EasingStyle.Quad }),
		key(0.07, { Arm = 184, Elbow = 150, Wrist = 40, In = -18, Waist = 7, Turn = -14, Easing = Enum.EasingStyle.Quad }),
		key(0.11, { Arm = 84, Elbow = 12, Wrist = -25, In = 14, Waist = -10, Turn = 14, Easing = Enum.EasingStyle.Quint }),
		key(0.2, { Arm = 72, Elbow = 22, Wrist = -10, In = 14, Waist = -6, Turn = 8, Easing = Enum.EasingStyle.Quad }),
		key(0.4, { Arm = 172, Elbow = 138, Wrist = 10, In = -14, Waist = 3, Turn = -8, Easing = Enum.EasingStyle.Quad }),
		key(0.58, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.WBDirect = {
	Rate = 22, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.18, { Arm = 72, Elbow = 24, Wrist = -12, In = 18, Waist = -4, Turn = 8, Easing = Enum.EasingStyle.Quad }),
		key(0.6, { Arm = 76, Elbow = 20, Wrist = -16, In = 20, Waist = -5, Turn = 10, Easing = Enum.EasingStyle.Sine }),
		key(0.95, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.WBPulse = {
	Rate = 18, Repeat = true, FromCurrent = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { From = true, FromBody = true }),
		key(0.14, { From = true, Waist = 3, Easing = Enum.EasingStyle.Sine }),
		key(0.34, { From = true, Waist = -5, Easing = Enum.EasingStyle.Quad }),
		key(0.6, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.WBLaunch = {
	Rate = 26, Both = true, StanceLegsFrom = 0.5,
	Keys = {
		key(0, { Stance = true }),
		key(0.08, { Arm = 150, Elbow = 96, Wrist = 10, In = -10, Hip = 20, Knee = -40, Waist = 8, Drop = 0.12, Easing = Enum.EasingStyle.Quad }),
		key(0.22, { Arm = 128, Elbow = 10, Wrist = 30, In = 6, Hip = 10, Knee = -20, Waist = -12, Drop = 0.05, Easing = Enum.EasingStyle.Quint }),
		key(0.4, { Arm = 96, Elbow = 14, Wrist = 24, In = 10, Waist = -6, Easing = Enum.EasingStyle.Quad }),
		key(0.75, { Arm = 24, Elbow = 34, In = 6, Waist = 5, Easing = Enum.EasingStyle.Sine }),
		key(4, { Arm = 26, Elbow = 36, In = 6, Waist = 6 }),
	},
}
CastPose.Clips.WBCatch = {
	Rate = 30, Both = true, FromCurrent = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { From = true, FromBody = true }),
		key(0.4, { Arm = 150, Elbow = 100, Wrist = 10, In = -8, Waist = 4, Easing = Enum.EasingStyle.Quad }),
		key(0.6, { Arm = 140, Elbow = 110, Wrist = 10, In = -8, Hip = 24, Knee = -50, Waist = -14, Drop = 0.16, Cam = Vector3.new(0, -0.18, 0), Easing = Enum.EasingStyle.Quint }),
		key(0.8, { Arm = 60, Elbow = 60, In = 10, Hip = 10, Knee = -20, Waist = -6, Drop = 0.06, Easing = Enum.EasingStyle.Quad }),
		key(1.15, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.WBHerb = {
	Rate = 34, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.14, { Arm = 168, Elbow = 110, Wrist = 20, In = -20, Waist = 3, Turn = -10, Easing = Enum.EasingStyle.Quad }),
		key(0.3, { Arm = 176, Elbow = 118, Wrist = 30, In = -24, Waist = 4, Turn = -12 }),
		key(0.45, { Arm = 150, Elbow = 90, Wrist = -10, In = -14, Turn = -6, Easing = Enum.EasingStyle.Quad }),
		key(0.58, { Arm = 178, Elbow = 60, Wrist = -30, In = -30, Waist = 6, Turn = -14, Easing = Enum.EasingStyle.Quint }),
		key(0.95, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.WBTip = {
	Rate = 20, Both = true, StanceLegsFrom = 0.4,
	Keys = {
		key(0, { Stance = true }),
		key(0.3, { Arm = 64, Elbow = 118, Wrist = 10, In = 34, Hip = 14, Knee = -28, Waist = 16, Drop = 0.08, Easing = Enum.EasingStyle.Quad }),
		key(4.3, { Arm = 62, Elbow = 120, Wrist = 10, In = 34, Hip = 14, Knee = -28, Waist = 18, Drop = 0.08 }),
		key(4.8, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
	Tremble = { Turn = 0.6, Arm = 1.2, Waist = 0.8, From = 0.3, Full = 0.6, Until = 4.3 },
}

-- HYDRA (Toxin Mythic skin, 2026-10-23): the caster's body performing with the creature. Generated from
-- vfx_blocking/toxin/hydra_2026_10_21/helm/hydra_body.py (previewed there through a copy of this module's evaluation),
-- timed to the kit's Blender animations; played by HydraFX from the same hooks that start the creature.
CastPose.Clips.HydraSpit = {
	Rate = 40, Repeat = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.06, { Arm = 20, Elbow = 72, In = 10, Waist = 6, Turn = -12, Easing = Enum.EasingStyle.Quad }),
		key(0.11, { Arm = 78, Elbow = 18, Wrist = 40, In = 14, Hip = 12, Knee = -24, Waist = -15, Turn = 16, Shift = 0.14, Easing = Enum.EasingStyle.Quint }),
		key(0.2, { Arm = 62, Elbow = 30, Wrist = 20, In = 14, Hip = 8, Knee = -16, Waist = -7, Turn = 9, Shift = 0.08, Easing = Enum.EasingStyle.Quad }),
		key(0.48, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.HydraExhale = {
	Rate = 30, Both = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.18, { Arm = -26, Elbow = 40, In = -10, Hip = 10, Knee = -20, Waist = 24, Turn = -8, Drop = 0.05, Easing = Enum.EasingStyle.Quad }),
		key(0.3, { Arm = 58, Elbow = 22, Wrist = 30, In = 22, Hip = 24, Knee = -50, Waist = -14, Turn = 6, Drop = 0.19, Shift = 0.1, Easing = Enum.EasingStyle.Back }),
		key(0.4, { Arm = 50, Elbow = 28, Wrist = 20, In = 20, Hip = 24, Knee = -50, Waist = 8, Drop = 0.19, Easing = Enum.EasingStyle.Quad }),
		key(0.6, { Arm = 48, Elbow = 30, Wrist = 20, In = 20, Hip = 24, Knee = -50, Waist = 10, Drop = 0.19 }),
		key(0.95, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
	Tremble = { Turn = 1.5, Arm = 2.5, Waist = 1.5, From = 0.3, Full = 0.4, Until = 0.6 },
}
CastPose.Clips.HydraGulp = {
	Rate = 30, Repeat = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.14, { Arm = 40, Elbow = 56, In = 20, Waist = 5, Turn = -8, Easing = Enum.EasingStyle.Quad }),
		key(0.22, { Arm = 46, Elbow = 98, Wrist = 20, In = 36, Hip = 10, Knee = -20, Waist = -11, Turn = 4, Drop = 0.03, Easing = Enum.EasingStyle.Quint }),
		key(0.38, { Arm = 44, Elbow = 90, Wrist = 10, In = 32, Waist = 3, Easing = Enum.EasingStyle.Quad }),
		key(0.65, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}
CastPose.Clips.HydraRain = {
	Rate = 32, Both = true, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.12, { Arm = -36, Elbow = 30, In = -16, Hip = 30, Knee = -60, Waist = -26, Drop = 0.27, Easing = Enum.EasingStyle.Quint }),
		key(0.22, { Arm = 150, Elbow = 24, Wrist = 20, In = -6, Hip = 20, Knee = -40, Waist = 16, Drop = 0.12, Easing = Enum.EasingStyle.Back }),
		key(0.4, { Arm = 156, Elbow = 18, Wrist = 20, In = -6, Hip = 20, Knee = -40, Waist = 20, Drop = 0.12 }),
		key(0.68, { Arm = 60, Elbow = 40, In = 10, Waist = 4, Easing = Enum.EasingStyle.Sine }),
		key(0.85, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
	Tremble = { Turn = 0, Arm = 2, From = 0.22, Full = 0.3, Until = 0.4 },
}
CastPose.Clips.HydraPZ = {
	Rate = 26, Both = true, StanceLegsFrom = 0.6,
	Keys = {
		key(0, { Stance = true }),
		key(0.1, { Arm = 30, Elbow = 10, Wrist = -30, In = 10, Hip = 30, Knee = -60, Waist = -26, Drop = 0.27, Easing = Enum.EasingStyle.Quint }),
		key(0.16, { Arm = 62, Elbow = 20, In = 14, Hip = 24, Knee = -50, Waist = -10, Drop = 0.19, Easing = Enum.EasingStyle.Quad }),
		key(0.3, { Arm = 86, Elbow = 6, Wrist = 40, In = 22, Hip = 24, Knee = -50, Waist = -18, Drop = 0.19, Cam = Vector3.new(0, -0.2, 0), Easing = Enum.EasingStyle.Quint }),
		key(0.42, { Arm = 80, Elbow = 10, Wrist = 30, In = 22, Hip = 24, Knee = -50, Waist = -16, Drop = 0.19 }),
		key(0.6, { Arm = 50, Elbow = 112, Wrist = 10, In = 40, Hip = 30, Knee = -60, Waist = -12, Drop = 0.27, Easing = Enum.EasingStyle.Quad }),
		key(3.15, { Arm = 52, Elbow = 118, Wrist = 10, In = 42, Hip = 30, Knee = -60, Waist = -15, Drop = 0.27 }),
		key(3.4, { Arm = 168, Elbow = 20, Wrist = 10, In = -4, Hip = 10, Knee = -20, Waist = 18, Drop = 0.03, Easing = Enum.EasingStyle.Quad }),
		key(3.5, { Arm = 40, Elbow = 12, Wrist = -20, In = 12, Hip = 35, Knee = -70, Waist = -44, Drop = 0.36, Cam = Vector3.new(0, -0.6, 0), Easing = Enum.EasingStyle.Quint }),
		key(3.85, { Arm = 36, Elbow = 14, Wrist = -16, In = 12, Hip = 35, Knee = -70, Waist = -40, Drop = 0.36 }),
		key(4.4, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
	Tremble = { Turn = 1.2, Arm = 2.4, Waist = 1.2, From = 0.6, Full = 3, Until = 3.15 },
}
CastPose.Clips.HydraVent = {
	Rate = 40, StanceLegsFrom = 0,
	Keys = {
		key(0, { Stance = true }),
		key(0.05, { Arm = 150, Elbow = 100, Wrist = 10, In = 30, Waist = 4, Easing = Enum.EasingStyle.Quad }),
		key(0.27, { Arm = 72, Elbow = 62, Wrist = 0, In = 30, Hip = 14, Knee = -28, Waist = -10, Drop = 0.06, Cam = Vector3.new(0, -0.22, 0), Easing = Enum.EasingStyle.Quint }),
		key(0.36, { Arm = 66, Elbow = 58, In = 28, Hip = 8, Knee = -16, Waist = -4, Drop = 0.03, Easing = Enum.EasingStyle.Quad }),
		key(0.7, { Stance = true, Easing = Enum.EasingStyle.Sine }),
	},
}

----------------------------------------------------------------------------------------------------
-- rig adapters
----------------------------------------------------------------------------------------------------
--- One arm's channels as a joint rotation. The yaw is applied FIRST so it turns the whole arm
--- about the vertical (converging the hands toward the aim line); applying it after the swing
--- would twist the forearm in place instead.
local function armOffset(a, side)
	return CFrame.Angles(0, rad(a.In * side), 0) * CFrame.Angles(rad(a.Arm), 0, 0)
end

local function buildOffsets(isR6, cur, sunk)
	local out = {}
	if isR6 then
		-- R6's shoulder frame is rotated 90 degrees about Y relative to R15, so the forward swing
		-- lives on Z instead of X, and there is no waist or hip joint to bend.
		out["Right Shoulder"] = CFrame.Angles(0, 0, rad(-cur.R.Arm - cur.R.Elbow * 0.5))
		out["Left Shoulder"] = CFrame.Angles(0, 0, rad(cur.L.Arm + cur.L.Elbow * 0.5))
		return out
	end
	out.RightShoulder = armOffset(cur.R, 1)
	out.RightElbow = CFrame.Angles(rad(cur.R.Elbow), 0, 0)
	out.RightWrist = CFrame.Angles(rad(cur.R.Wrist), 0, 0)
	out.LeftShoulder = armOffset(cur.L, -1)
	out.LeftElbow = CFrame.Angles(rad(cur.L.Elbow), 0, 0)
	out.LeftWrist = CFrame.Angles(rad(cur.L.Wrist), 0, 0)
	-- Turn is the torso's yaw, applied before the lean the way In is before the swing: a punch drives the
	-- shoulder and chest through with it
	out.Waist = CFrame.Angles(0, rad(cur.Turn or 0), 0) * CFrame.Angles(rad(cur.Waist), 0, 0)
	out.RightHip = CFrame.Angles(rad(cur.R.Hip), 0, 0)
	out.LeftHip = CFrame.Angles(rad(cur.L.Hip), 0, 0)
	out.RightKnee = CFrame.Angles(rad(cur.R.Knee), 0, 0)
	out.LeftKnee = CFrame.Angles(rad(cur.L.Knee), 0, 0)
	-- Drop / Shift (Aftershock, 2026-09-25): the Root joint, written ONLY while either is off zero -- so a body on any
	-- other clip or stance never has it touched, and the frame they come back to 0 the hand-back in step() returns the
	-- joint to its own value. Checked read-only on the TrainingGround dummies: `Root` is an AnimationConstraint on the
	-- LowerTorso whose Attachment0 is HumanoidRootPart.RootRigAttachment at (0, -1, 0) with an identity rotation, so
	-- this offset is plain root space: -Y lowers, -Z is forward. Clamped, so a stray key can never throw the body clear.
	-- Drop is fitted to a STANDING root (floor 3.192 under it); `sunk` (2026-09-25) is how far the root already sits
	-- below that -- a Crouch / Slide HipHeight -- and comes off Drop, so a cast from a crouch reaches the same floor
	-- instead of burying the torso and fists in it. The gate stays on the raw channels: other clips never touch Root.
	local drop, shift = cur.Drop or 0, cur.Shift or 0
	if math.abs(drop) > 1e-3 or math.abs(shift) > 1e-3 then
		out.Root = CFrame.new(0, -math.clamp(drop - (sunk or 0), 0, 1.5), -math.clamp(shift, -0.6, 0.6))
	end
	return out
end

--- Finds the writable instance/property that acts as each joint's base offset.
--- AnimationConstraint rigs (current R15): Attachment0.CFrame. Motor6D rigs (R6, older): C0.
local function collectJoints(character)
	local joints = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("AnimationConstraint") then
			local a0 = d.Attachment0
			-- `joint` is kept alongside the writable slot because the override needs to read the
			-- animator's Transform for this frame and cancel it.
			if a0 then joints[d.Name] = { inst = a0, prop = "CFrame", joint = d } end
		elseif d:IsA("Motor6D") then
			joints[d.Name] = { inst = d, prop = "C0", joint = d }
		end
	end
	return joints
end

----------------------------------------------------------------------------------------------------
-- playback
----------------------------------------------------------------------------------------------------
local active = {}          -- [character] = state
local bound = false
local started = false

-- Tuning hook: set the "CastPoseTimeScale" attribute on ReplicatedStorage.IceMagic to slow the
-- clips down (0.1 plays them 10x slower) while dialling in poses. Defaults to 1.
local function timeScale()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local v = ice and ice:GetAttribute("CastPoseTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

-- LIVE TUNING. A stance is a framing decision, and framing has to be looked at rather than
-- calculated -- so any channel can be overridden without a restart by setting an attribute named
-- "Stance_<stance>_<channel>" on ReplicatedStorage.IceMagic, e.g. Stance_Ready_Arm = 62.
-- Attributes are also the only channel that crosses script contexts here (the command bar and the
-- MCP each get their own require cache and their own globals), so this is how a pose gets swept
-- from outside the running game. Cached, and refreshed only when an attribute actually changes.
local tuning = {}
local function refreshTuning()
	table.clear(tuning)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	if not ice then return end
	for k, v in pairs(ice:GetAttributes()) do
		local stance, ch = string.match(k, "^Stance_(%w+)_(%w+)$")
		if stance and type(v) == "number" then
			tuning[stance] = tuning[stance] or {}
			tuning[stance][ch] = v
		end
	end
end

local function sampleClip(clip, t)
	local keys = clip.Keys
	local last = keys[#keys]
	if t >= last.t then return last, last, 0 end
	if t <= keys[1].t then return keys[1], keys[1], 0 end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			return a, b, (t - a.t) / math.max(1e-4, b.t - a.t)
		end
	end
	return last, last, 0
end

--- A key's value on one channel. `Stance = true` keys read straight off the live stance sample,
--- so a cast leaves and returns to the posture the body is actually holding. `From = true` keys (a FromCurrent
--- clip) read `fromArm`, the arm's pose when the clip started.
local function keyArm(k, ch, stanceArm, fromArm)
	if k.Stance then return stanceArm[ch] or 0 end
	if k.From and fromArm then return fromArm[ch] or 0 end
	return k[ch] or 0
end

--- The torso's value (Waist, Turn). A `FromBody = true` key of a FromCurrent clip reads the torso as it was when the
--- clip started (Boulder Shot's throw, 2026-09-23: a tap leaves from mid-reach, a full hold from wound), where a plain
--- From key only ever carried the arms.
local function keyBody(k, ch, stance, from)
	if k.Stance then return stance[ch] or 0 end
	if k.FromBody and from then return from[ch] or 0 end
	return k[ch] or 0
end

--- The stance pose for this frame, including its cycle. Called once per character per frame --
--- the phase advances inside, so a second call would double-step it.

local function stanceTarget(state, dt)
	local def = CastPose.Stances[state.Stance] or CastPose.Stances.Ready
	local over = tuning[state.Stance]
	local out = blankPose()
	for _, ch in ipairs(LIMB) do
		local v = (over and over[ch]) or def[ch] or 0
		out.R[ch] = v
		out.L[ch] = v
	end
	out.Waist = (over and over.Waist) or def.Waist or 0

	-- Cycles ramp rather than switch, so entering and leaving a sprint does not pop. Gated on
	-- actually moving: holding Shift while stood still must not pump the arms.
	--
	-- Gated on ROOT SPEED, not Humanoid.MoveDirection. MoveDirection is not safe to read from a
	-- render step: the control module calls Humanoid:Move with a zero vector during the render
	-- phase when no key is down, and the real direction only appears during physics. Measured, on
	-- a character genuinely walking at 16 studs/s, it read 0.000 at every render step and 0.983
	-- at every heartbeat -- so a cycle gated on it never ran at all. Velocity is the same value
	-- whenever you look at it.
	local moving = false
	local hum = state.Humanoid
	local root = hum and hum.Parent and hum.RootPart
	if root then
		local v = root.AssemblyLinearVelocity
		moving = (v.X * v.X + v.Z * v.Z) > 4          -- ~2 studs/s, well under a crouch walk
	end
	state.Moving = moving       -- a clip's StanceLegsFrom reads it (Aftershock, 2026-09-25)
	local want = (def.Cycle and moving) and 1 or 0
	state.CycleAmt = lerp(state.CycleAmt, want, math.clamp(7 * dt, 0, 1))
	if def.Cycle and state.CycleAmt > 0.001 then
		state.CyclePhase += dt * (def.Cadence or 10)
		local dR, dL = def.Cycle(state.CyclePhase, state.CycleAmt)
		for _, ch in ipairs(LIMB) do
			out.R[ch] += dR[ch] or 0
			out.L[ch] += dL[ch] or 0
		end
	end
	return out
end

--- The OFF arm's value on one channel, for a clip with OffKeys: a Stance key is the rest pose, a key's `Off`
--- table is what that arm does, and a key without one leaves it on the rest pose. `Off = OFF_HOLD` keeps the arm
--- where it was when the clip started (`fromArm`, a FromCurrent clip).
local function keyOff(k, ch, restArm, fromArm)
	if k.Stance or not k.Off then return restArm[ch] or 0 end
	if k.Off == OFF_HOLD then return fromArm and fromArm[ch] or restArm[ch] or 0 end
	return k.Off[ch] or 0
end

--- A BASE clip's held pose (the Scorching Lash hold): its last key's arms and torso, over the stance's legs.
local function basePose(clip, stance)
	local last = clip.Keys[#clip.Keys]
	local out = blankPose()
	local lead, off = "R", "L"
	if clip.Side == "L" then lead, off = "L", "R" end
	for _, ch in ipairs(LIMB) do
		if LEG[ch] then
			out.R[ch], out.L[ch] = stance.R[ch], stance.L[ch]
		else
			out[lead][ch] = keyArm(last, ch, stance[lead])
			if clip.Both then
				out[off][ch] = out[lead][ch]
			elseif clip.OffKeys then
				out[off][ch] = keyOff(last, ch, stance[off])
			else
				out[off][ch] = stance[off][ch]
			end
		end
	end
	out.Waist = keyBody(last, "Waist", stance)
	out.Turn = keyBody(last, "Turn", stance)
	out.Drop = keyBody(last, "Drop", stance)
	out.Shift = keyBody(last, "Shift", stance)
	return out
end

-- Ring of Fire's trace (SetAim): the right arm points at the aim point from the shoulder, the torso turns
-- into it by a share of the yaw, and the left hand rides up loose, so the body conducts the circle as it is
-- drawn. The review replica solved it by iterating on the rig; the direct solve from the shoulder lands within
-- a few degrees of that.
local SHOULDER_R = Vector3.new(1, 0.763, 0)
local function aimPose(state, stance)
	local root = state.Humanoid and state.Humanoid.RootPart
	if not (root and state.Aim) then return stance end
	local d = root.CFrame:PointToObjectSpace(state.Aim) - SHOULDER_R
	local yaw = math.deg(math.atan2(-d.X, -d.Z))
	local pitch = math.deg(math.atan2(math.sqrt(d.X * d.X + d.Z * d.Z), -d.Y))
	local out = blankPose()
	for _, ch in ipairs(LIMB) do
		out.R[ch], out.L[ch] = stance.R[ch], stance.L[ch]
	end
	out.Turn = math.clamp(0.45 * yaw, -40, 40)
	out.Waist = -4
	local w = os.clock() * math.pi * 6          -- the conducting wobble, three times a second
	out.R.Arm, out.R.In = pitch, yaw - out.Turn
	out.R.Elbow, out.R.Wrist = 8 + 6 * math.sin(w), -10 + 8 * math.sin(w + 1)
	out.L.Arm, out.L.Elbow, out.L.Wrist, out.L.In = 44, 72, 10, 20
	return out
end

--- Put every joint we touched back to the value it had before we started writing it.
local function restore(state)
	for name, base in pairs(state.Bases) do
		local slot = state.Joints[name]
		if slot and slot.inst and slot.inst.Parent then
			pcall(function() slot.inst[slot.prop] = base end)
		end
	end
	state.Bases = {}
end

--- UniformAvatar's ApplyDescription replaces the limbs, which orphans every cached attachment and
--- every cached base. Notice that and re-collect rather than silently posing a dead rig.
local function jointsStale(state)
	local probe = state.Joints.RightShoulder or state.Joints["Right Shoulder"]
	return not (probe and probe.inst and probe.inst.Parent)
end

local function step(dt)
	local any = false
	for character, state in pairs(active) do
		if not (character.Parent and state.Humanoid and state.Humanoid.Parent) then
			active[character] = nil
		else
			any = true
			if jointsStale(state) then
				-- restore FIRST. Bases are captured lazily from the attachment's current value, so
				-- re-collecting without handing the old joints back would cache a value this module
				-- had already written -- the offset gets folded into the "rest" pose and the next
				-- frame's write is measured from the wrong zero. That is what made the Ready stance
				-- decode to -2.7 degrees instead of 75 after a respawn.
				restore(state)
				state.Joints = collectJoints(character)
				state.Bases = {}
				state.Written = {}
			end

			local stance = stanceTarget(state, dt)
			-- the Frostblade runner's Naruto run: the upper body over the stance (legs and stride its own), never over a cast
			local fb = frostblade()
			if fb then
				local ok, err = pcall(fb.Naruto, state, stance, dt)
				if not ok and not narutoWarned then
					narutoWarned = true
					warn("[CastPose] Frostblade run: " .. tostring(err))
				end
			end
			local fl = frostLotus()
			if fl then
				local ok, err = pcall(fl.M1, state, stance, dt)
				if not ok and not lotusWarned then
					lotusWarned = true
					warn("[CastPose] Frost Lotus hold: " .. tostring(err))
				end
			end
			-- REST is what the body settles on between clips: the stance, or a BASE clip's held pose (the Scorching
			-- Lash hold), which a clip played over it leaves from and comes back to. Legs stay the stance's.
			local rest = stance
			if state.Base and state.Clip ~= state.Base then rest = basePose(state.Base, stance) end
			local restRate = state.Base and (state.Base.Rate or CastPose.Config.BlendIn) or CastPose.Config.StanceBlend
			local target, rate = rest, restRate
			if state.Aim and not state.Clip then
				target, rate = aimPose(state, stance), CastPose.Config.AimBlend or 20
			end

			local clip = state.Clip
			local shake, shakeT, shakeSide = 0, 0, "R"      -- a Tremble clip's shake this frame (0 = none)
			if clip then
				if state.Releasing then
					rate = state.Base and restRate or clip.ReleaseRate or CastPose.Config.BlendOut
				else
					local t = (os.clock() - state.ClipStart) * timeScale()
					-- a clip started with its own clock (PlayClocked) runs on that instead, while it is that play
					if state.Clock and state.ClockStart == state.ClipStart then t = state.Clock() or t end
					local a, b, alpha = sampleClip(clip, t)
					local e = TweenService:GetValue(math.clamp(alpha, 0, 1),
						b.Easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					target = blankPose()
					-- `Side = "L"` casts with the left hand; the other hand keeps the rest pose
					local lead, off = "R", "L"
					if clip.Side == "L" then lead, off = "L", "R" end
					local from = clip.FromCurrent and state.ClipFrom or nil     -- the arms when the clip started
					for _, ch in ipairs(LIMB) do
						if LEG[ch] and clip.StanceLegs then
							-- the legs keep running under the cast
							target.R[ch], target.L[ch] = stance.R[ch], stance.L[ch]
						else
							local v = lerp(keyArm(a, ch, rest[lead], from and from[lead]),
								keyArm(b, ch, rest[lead], from and from[lead]), e)
							target[lead][ch] = v
							-- a one-armed clip leaves the OFF hand on the rest pose: while the right
							-- casts, the left keeps the ready posture -- unless the clip keys that arm
							-- too (OffKeys). Legs are a whole-body crouch, not a limp -- unless an OffKeys
							-- clip keys the off leg in its Off table (Cross-Slash Dash's glide: one knee
							-- forward, the other leg trailing); a key without one keeps the legs together.
							if LEG[ch] and clip.OffKeys and ((a.Off and a.Off[ch]) or (b.Off and b.Off[ch])) then
								local function offLeg(k)
									if k.Stance then return rest[off][ch] or 0 end
									if k.Off and k.Off[ch] then return k.Off[ch] end
									return keyArm(k, ch, rest[lead])
								end
								target[off][ch] = lerp(offLeg(a), offLeg(b), e)
							elseif LEG[ch] or clip.Both then
								target[off][ch] = v
							elseif clip.OffKeys then
								target[off][ch] = lerp(keyOff(a, ch, rest[off], from and from[off]),
									keyOff(b, ch, rest[off], from and from[off]), e)
							else
								target[off][ch] = rest[off][ch]
							end
						end
					end
					target.Waist = lerp(keyBody(a, "Waist", rest, from), keyBody(b, "Waist", rest, from), e)
					target.Turn = lerp(keyBody(a, "Turn", rest, from), keyBody(b, "Turn", rest, from), e)
					-- the Root channels (Aftershock, 2026-09-25): 0 on every key that does not name them
					target.Drop = lerp(keyBody(a, "Drop", rest, from), keyBody(b, "Drop", rest, from), e)
					target.Shift = lerp(keyBody(a, "Shift", rest, from), keyBody(b, "Shift", rest, from), e)
					-- StanceLegsFrom (Aftershock, 2026-09-25): from this clip time on, a body that is actually MOVING
					-- gets its legs back -- the stance's, stride and all -- and its Root channels eased to the rest's,
					-- so a caster the server has just let go of walks out of the pull-out instead of gliding across
					-- the floor sunk on folded knees. Latched once it starts (a velocity flicker must not fold the
					-- knees again) and ramped, not switched. A caster who stays put keeps the keyed pull-out.
					if clip.StanceLegsFrom and not clip.StanceLegs then
						if t >= clip.StanceLegsFrom and state.Moving then state.LegsFreed = true end
						state.LegsFree = lerp(state.LegsFree or 0, state.LegsFreed and 1 or 0, math.clamp(12 * dt, 0, 1))
						local free = state.LegsFree
						if free > 0.001 then
							for ch in pairs(LEG) do
								target.R[ch] = lerp(target.R[ch], stance.R[ch], free)
								target.L[ch] = lerp(target.L[ch], stance.L[ch], free)
							end
							target.Drop = lerp(target.Drop, rest.Drop or 0, free)
							target.Shift = lerp(target.Shift, rest.Shift or 0, free)
						end
					end
					-- Tremble (Boulder Shot's windup, 2026-09-23): the casting arm and the torso shake under the
					-- weight, 0.35 of it building over the charge and the rest arriving at full, as the showcase's
					-- strain(). Added after the blend (below) so the blend cannot smooth an 18 Hz shake away.
					local tr = clip.Tremble
					if tr then
						shake = 0.35 * math.clamp((t - tr.From) / math.max(1e-3, tr.Full - tr.From), 0, 1)
							+ 0.65 * math.clamp((t - tr.Full + 0.05) / 0.1, 0, 1)
						-- an Until (Aftershock's TOP, 2026-09-25) lets it go in 0.02 s: the strain ends when the drive starts
						if tr.Until then shake *= math.clamp(1 - (t - tr.Until) / 0.02, 0, 1) end
						shakeT, shakeSide = t, lead
					end
					target.Cam = (a.Cam or ZERO):Lerp(b.Cam or ZERO, e)
					rate = clip.Rate or CastPose.Config.BlendIn

					local last = clip.Keys[#clip.Keys]
					if t > last.t and not clip.Hold then state.Releasing = true end
				end
			end

			-- blend
			local k = math.clamp(rate * dt, 0, 1)
			local cur = state.Cur
			local settled = true
			for _, side in ipairs(SIDES) do
				for _, ch in ipairs(LIMB) do
					local c = cur[side][ch]
					local n = c + (target[side][ch] - c) * k
					cur[side][ch] = n
					if math.abs(n - rest[side][ch]) > 0.25 then settled = false end
				end
			end
			cur.Waist += (target.Waist - cur.Waist) * k
			cur.Turn = (cur.Turn or 0) + ((target.Turn or 0) - (cur.Turn or 0)) * k
			-- the Root channels blend like Waist; a body lowered on them has not settled until it is back up
			cur.Drop = (cur.Drop or 0) + ((target.Drop or 0) - (cur.Drop or 0)) * k
			cur.Shift = (cur.Shift or 0) + ((target.Shift or 0) - (cur.Shift or 0)) * k
			if math.abs(cur.Drop - (rest.Drop or 0)) > 0.01 or math.abs(cur.Shift - (rest.Shift or 0)) > 0.01 then
				settled = false
			end
			state.Cam = state.Cam:Lerp(target.Cam or ZERO, k)

			-- a released clip is finished once the body has actually reached the stance again
			if state.Releasing and settled then
				state.Clip, state.ClipName, state.Releasing = nil, nil, false
			end

			-- the Tremble goes on a copy, so the blended pose never accumulates it
			local posed = cur
			if shake > 0 then
				local tr = clip.Tremble
				posed = { R = table.clone(cur.R), L = table.clone(cur.L), Waist = cur.Waist, Cam = cur.Cam,
					Drop = cur.Drop, Shift = cur.Shift,
					Turn = (cur.Turn or 0) + tr.Turn * shake * (math.sin(shakeT * 113) + 0.5 * math.sin(shakeT * 171)) }
				local armShake = tr.Arm * shake * (math.sin(shakeT * 97 + 3.1) + 0.4 * math.sin(shakeT * 203 + 1))
				posed[shakeSide].Arm += armShake
				-- a Both clip's arms are one gesture, so they shake as one; and an optional lean shake (Aftershock)
				if clip.Both then posed[shakeSide == "R" and "L" or "R"].Arm += armShake end
				if tr.Waist then posed.Waist += tr.Waist * shake * (math.sin(shakeT * 89 + 0.6) + 0.5 * math.sin(shakeT * 151)) end
			end
			-- how far below its standing height the root already is (a Crouch / Slide HipHeight): Drop is measured from standing
			local baseHip = character:GetAttribute("BaseHipHeight")
			local sunk = baseHip and math.max(0, baseHip - state.Humanoid.HipHeight) or 0
			local offsets = buildOffsets(state.IsR6, posed, sunk)
			-- hand back anything we wrote last frame but are not writing now (the hips, the moment
			-- a slide ends) so the animator gets its joint straight back
			for name in pairs(state.Written) do
				if not offsets[name] then
					local slot, base = state.Joints[name], state.Bases[name]
					if base and slot and slot.inst and slot.inst.Parent then
						slot.inst[slot.prop] = base
					end
					state.Written[name] = nil
				end
			end
			for name, offset in pairs(offsets) do
				local slot = state.Joints[name]
				if slot and slot.inst and slot.inst.Parent then
					local base = state.Bases[name]
					if not base then
						base = slot.inst[slot.prop]
						state.Bases[name] = base
					end
					-- Transform:Inverse() is the override: it cancels whatever the animator put on
					-- THIS joint this frame, so the stance is what you see rather than the stance
					-- plus an idle that is holding the arm down.
					local tf = slot.joint and slot.joint.Parent and slot.joint.Transform
					slot.inst[slot.prop] = tf and (base * offset * tf:Inverse()) or (base * offset)
					state.Written[name] = true
				end
			end
		end
	end

	if not any and bound then
		RunService:UnbindFromRenderStep("SpellshotCastPose")
		bound = false
	end
end

local function ensureBound()
	if bound then return end
	bound = true
	RunService:BindToRenderStep("SpellshotCastPose", Enum.RenderPriority.Character.Value + 1, step)
end

----------------------------------------------------------------------------------------------------
-- character registry
----------------------------------------------------------------------------------------------------
--- Which stance a character is on: its MoveState's.
local function stanceFor(character)
	local moveState = character:GetAttribute("MoveState") or "None"
	return STANCE_FOR_STATE[moveState] or "Ready"
end

local function stateFor(character)
	if not (character and character.Parent) then return nil end
	local s = active[character]
	if s then return s end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	s = {
		Character = character,
		Humanoid = humanoid,
		IsR6 = humanoid.RigType == Enum.HumanoidRigType.R6,
		Joints = collectJoints(character),
		Bases = {},
		Written = {},
		Clip = nil, ClipName = nil, ClipStart = 0, Releasing = false,
		Stance = stanceFor(character),
		Cur = blankPose(),
		Cam = ZERO,
		CyclePhase = 0, CycleAmt = 0,
		Base = nil,          -- a held clip the body rests on instead of the stance (SetBase)
		Aim = nil,           -- a world point the right arm points at (SetAim)
	}
	active[character] = s
	ensureBound()
	return s
end

--- Drives every character's stance off its replicated MoveState attribute. This is the mechanism
--- that makes first and third person impossible to desync: there is no per-view wiring at all,
--- just one attribute that every client already receives for every character.
function CastPose.Start()
	if started then return end
	started = true

	refreshTuning()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	if ice then ice.AttributeChanged:Connect(refreshTuning) end

	local function watch(character)
		if not character then return end
		local s = stateFor(character)
		-- WAIT for the body rather than give up on it (2026-09-20). CharacterAdded can arrive before the model is
		-- in the world, and stateFor answers nil until it is; this used to `return` there, which left that
		-- character with NO watchers for the rest of its life. Nothing below was ever connected: the stance never
		-- restanced off MoveState, and the Earthen Tomb and Bulwark Wall poses never played -- measured on a live
		-- character, whose shoulder did not move a degree through a cast of either while the VFX ran fine.
		if not s then
			local t0 = os.clock()
			repeat
				task.wait()
				s = stateFor(character)
			until s or os.clock() - t0 > 5
			if not s then return end
		end
		-- ApplyDescription rebuilds the limbs a beat after the character arrives, which orphans
		-- the joints collected above; re-collect once things have settled. Restore first, for the
		-- same reason as in step(): by now this module has been writing for a quarter of a second,
		-- so the attachments no longer hold their rest values.
		task.delay(0.4, function()
			local cur = stateFor(character)
			if not cur then return end
			restore(cur)
			cur.Joints = collectJoints(character)
			cur.Bases = {}
			cur.Written = {}
		end)
		local function restance()
			local cur = active[character]
			if not cur then return end
			cur.Stance = stanceFor(character)
		end
		character:GetAttributeChangedSignal("MoveState"):Connect(restance)
		-- Earthen Tomb: the SMASH while the server's TombPhase says the cast is live, then the RAISE for as long as the
		-- platform climbs -- clocked by the climb itself (TombRiseAt / TombRiseFor, set with the phase on the same server
		-- line). Both let go the instant the phase says the Tomb is over: the catch, a miss, a death, a round reset.
		local function tombPose()
			local cur = active[character]
			local phase = character:GetAttribute("TombPhase")
			if phase == "Cast" then
				CastPose.Play(character, "EarthenTombSlam")
			elseif phase == "Rise" then
				CastPose.PlayClocked(character, "EarthenTombRaise", function()
					local at, over = character:GetAttribute("TombRiseAt"), character:GetAttribute("TombRiseFor")
					if not (at and over and over > 0) then return 1 end
					local u = math.clamp((workspace:GetServerTimeNow() - at) / over, 0, 1)
					return 1 - (1 - u) ^ 2.2         -- TerraFX.TombRise, the platform's own curve: they climb as one
				end)
			elseif cur and (cur.ClipName == "EarthenTombSlam" or cur.ClipName == "EarthenTombRaise") then
				CastPose.Stop(character)
			end
		end
		character:GetAttributeChangedSignal("TombPhase"):Connect(tombPose)
		character:GetAttributeChangedSignal("TombRiseAt"):Connect(tombPose)
		tombPose()
		-- Bulwark Wall's brace: held while the server says the wall is hers, let go the instant it is not -- the key
		-- coming up, the wall broken, an empty bar, a death. One attribute, so there is no state of its own to leak.
		-- Either Technique slot may hold the wall since v0.7 (2026-09-24), so BOTH holds are watched -- and the brace
		-- starts only when the wall's hold does (wallHeld), so the other slot's hold changing never restarts it.
		local wallHeld = false
		local function wallPose()
			local cur = active[character]
			local held = character:GetAttribute("Holding_Defense") == "BulwarkWall"
				or character:GetAttribute("Holding_Mobility") == "BulwarkWall"
			if held then
				if not wallHeld then CastPose.Play(character, "BulwarkWallRaise") end
			elseif cur and cur.ClipName == "BulwarkWallRaise" then
				CastPose.Stop(character)
			end
			wallHeld = held
		end
		character:GetAttributeChangedSignal("Holding_Defense"):Connect(wallPose)
		character:GetAttributeChangedSignal("Holding_Mobility"):Connect(wallPose)
		wallPose()
	end

	local function hook(player)
		if player.Character then task.spawn(watch, player.Character) end
		player.CharacterAdded:Connect(watch)
		player.CharacterRemoving:Connect(function(c) active[c] = nil end)
	end

	for _, p in ipairs(Players:GetPlayers()) do hook(p) end
	Players.PlayerAdded:Connect(hook)
end

----------------------------------------------------------------------------------------------------
-- api
----------------------------------------------------------------------------------------------------
--- Play a cast clip on a character's body. Safe to call on every client, and safe to call twice
--- for the same cast (local prediction + server broadcast) -- the second call inside RestartGuard
--- is ignored rather than restarting the clip mid-swing.
function CastPose.Play(character, clipName)
	local clip = CastPose.Clips[clipName]
	if not clip then return end
	local s = stateFor(character)
	if not s then return end
	if s.ClipName == clipName and not s.Releasing and not clip.Repeat
		and (os.clock() - s.ClipStart) < CastPose.Config.RestartGuard then
		return
	end
	s.Clip = clip
	s.ClipName = clipName
	s.ClipStart = os.clock()
	s.Releasing = false
	s.LegsFreed, s.LegsFree = false, 0      -- a StanceLegsFrom clip starts with its legs keyed
	-- a FromCurrent clip (Wind Blade) swings out of the pose the body is really in: its From keys and OFF_HOLD arm
	if clip.FromCurrent then
		s.ClipFrom = { R = table.clone(s.Cur.R), L = table.clone(s.Cur.L), Waist = s.Cur.Waist, Turn = s.Cur.Turn or 0,
			Drop = s.Cur.Drop or 0, Shift = s.Cur.Shift or 0 }
	end
	ensureBound()
end

--- Play, on a clock of the caller's: `clock()` gives the clip's time (the look's time, already scaled) instead of the
--- seconds since it started. Cross-Slash Dash's body holds its wind-up for as long as the charge is held and stretches
--- its glide over the charged glide (ZephyrFX.CrossSlashClock). Asked again for the clip already playing, only the clock
--- is taken.
--- A clock may run past the clip's last key: the last key is held there (a Hold clip never lets go on its own), which
--- is how Boulder Shot's windup sits wound for as long as the button is held (2026-09-23; its clock is SECONDS since the
--- press, not a 0..1 fraction).
function CastPose.PlayClocked(character, clipName, clock)
	CastPose.Play(character, clipName)
	local s = active[character]
	if s and s.ClipName == clipName then
		s.Clock, s.ClockStart = clock, s.ClipStart
	end
end

--- Rest a character's body on a HELD clip's final pose instead of its stance (the Scorching Lash hold): clips
--- played over it leave from it and come back to it, and the legs keep the stance's stride. nil lets go.
function CastPose.SetBase(character, clipName)
	local s = stateFor(character)
	if s then s.Base = clipName and CastPose.Clips[clipName] or nil end
end

--- Point the right arm at a world point, live, while no clip is playing (Ring of Fire's trace). nil lets go.
function CastPose.SetAim(character, point)
	local s = stateFor(character)
	if s then s.Aim = point end
end

--- Release a held clip (the Cryo Beam channel) back to the stance.
function CastPose.Stop(character)
	local s = active[character]
	if s and s.Clip then s.Releasing = true end
end

--- The locomotion cycle a character is on: its phase (radians; a foot plants each time sin(phase)
--- crosses zero) and how far into the cycle blend it is (0 standing, 1 fully walking/running).
--- For effects that land on footfalls, such as Cold Momentum's frost marks.
function CastPose.GetCycle(character)
	local s = active[character]
	if not s then return nil, 0 end
	return s.CyclePhase, s.CycleAmt
end

function CastPose.IsPlaying(character)
	local s = active[character]
	return s ~= nil and s.Clip ~= nil and not s.Releasing
end

--- The name of the clip a body is on, or nil: so a caller can let go of ITS OWN hold (Boulder Shot's windup) without
--- cutting short whatever else may be running on that body.
function CastPose.CurrentClip(character)
	local s = active[character]
	if not (s and s.Clip and not s.Releasing) then return nil end
	return s.ClipName
end

--- The camera punch the active clip wants, for the local character only. FirstPersonController
--- adds it to the movement controller's posture dip and writes the sum to Humanoid.CameraOffset,
--- so the two never overwrite each other.
function CastPose.GetCameraOffset(character)
	local s = active[character]
	return s and s.Cam or ZERO
end

--- Force a stance directly. The MoveState driver normally does this; exposed for testing and for
--- the dev panel.
function CastPose.SetStance(character, name)
	local s = stateFor(character)
	if s and CastPose.Stances[name] then s.Stance = name end
end

--- Hand every joint back and forget the character. Only needed when something outside this module
--- wants the rig left exactly as the animator had it.
function CastPose.Release(character)
	local s = active[character]
	if not s then return end
	restore(s)
	active[character] = nil
end

return CastPose
