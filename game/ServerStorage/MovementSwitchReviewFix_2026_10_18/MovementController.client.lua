--[[
	MovementController  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/MovementController

	Sprint, crouch, slide, and the air and wall moves.

	  Move (any direction)        Sprint -- automatic; there is no walk. RIVALS does the same: one
	                              speed, always, and the hands are pumping the moment you move.
	  Ctrl  (hold)                Crouch -- lower hitbox, half speed
	  Ctrl while moving           Slide  -- a short momentum-preserving low-profile slide, faster than the run
	  Jump during a slide         Slide-jump -- ends the slide in a longer, faster leap
	  Jump in the air             Double jump -- one air jump, for everyone (not while riding a Skyrider: Jump dismounts)
	  Airborne, along a wall      Wall run -- ride along the wall for a moment, the camera banked off it
	  Jump during a wall run      Wall jump -- off the wall, a little stronger than a ground jump

	THE NUMBERS (all in SpellshotConfig.Movement, chosen here, not given by the manual)
	  The manual fixes the philosophy -- "uniform base move speed across all elements ...
	  preserves aim-focused gunfights instead of turning into a mobility-stacking contest" -- and
	  a 1.5-2.5s TTK, but no figures. So:
	    Sprint 25 -- RIVALS' measured run pace is ~30; 25 was asked for on 2026-09-12. Base 16 is only
	      what you stand at; moving is always a sprint. No stamina meter, because the manual has no
	      such system.
	    Crouch 8 (half) with hip height 2.0 -> 0.9, which genuinely lowers the head and therefore
	      the hitbox rather than just dipping the camera.
	    Slide 1.6 s at its longest (SlideDuration; 1.1 until 2026-10-04), entering at 35 (or faster, if you already were), HOLDING near that and giving ground
	      only in its last third, ending at 28 -- still above the run -- for ~33 on average. A slide never
	      costs you speed (2026-09-14: "make the slide faster than running"; the 2026-09-12 calm-down had
	      it averaging ~22, slower than just running). The next slide is SlideRegap (0.1 s) behind the END of
	      this one, however it ended (from its start that is at most SlideDuration + SlideRegap).
	    Slide exit: still holding Ctrl -> crouch. Otherwise straight back into the run.
	      (2026-10-08: except a slide that ends by LEAVING THE GROUND with Ctrl still held -- the fall spends the
	      key, as a slide-jump does: the run while you fall and when you land. See the slide impulse.)
	    The slide lasts only as long as you are actually sliding: letting go of the key, leaving the
	      ground or being stopped by a wall ends it on the spot. SlideDuration is its longest, not its length.

	  SLIDE-JUMP. Jumping during a slide ends it in a leap that is flatter and faster than a normal
	  jump -- SPELLSHOT's take on RIVALS' slide jump:
	    6 studs high (from standing height) against a normal jump's 7.2, launching at the slide's
	    current speed + 20 studs/s -- never below 40, never above 50. That speed is HELD for the whole
	    flight and only eases back to sprint over 0.35 s after you land.
	  It stays bounded by the slide it comes out of: one leap per slide -- and Ctrl held (or pressed) in
	  the air is the next slide, the moment you land. The slide ENDS on the jump -- the server skips its end-of-slide crouch and stands
	  you up -- so the two never stack.

	AIR AND WALLS (2026-09-14: "add wall running, double jump by normal and also if you jump while wall
	running, you get a slightly stronger jump"). Every player has them; they are not Techniques.
	  DOUBLE JUMP. One jump in the air (AirJumps), rising DoubleJumpHeight. It re-aims the speed you carry
	    toward where you are steering. Landing, or catching a wall, gives it back.
	  WALL RUN. Airborne, moving at least WallRunMinSpeed and steering along a wall beside you (a wall
	    at waist AND head height, within WallRunReach of the body, with some air under your feet): you
	    ride along it at WallRunSpeed, or faster if you came in faster, for up to WallRunTime, sinking
	    under a share of gravity. It ends when the wall does, when you let go or steer off it, land,
	    crouch or run out of time. The camera banks WallRunTilt away from the wall. The wall you just
	    left can't be caught again for WallRunRegrab; the wall across the way can.
	  SKYRIDER (Zephyr's Mobility Technique since the v6 import, 2026-10-06; it replaced Gust Jump) owns the body while you
	    ride: no double jump (Jump is the dismount), no wall run, and the air momentum keeper stands down. Asked through
	    ZephyrClient.IsActive (zephyrRiding, below) -- optional: no module, no ride.
	  WALL JUMP. Jump while wall running: up WallJumpHeight -- more than a ground jump -- pushed away
	    from the wall at WallJumpPush and keeping your speed along it. The push is held for WallJumpKeep
	    so air steering doesn't cancel it at once. Your double jump is still there afterwards.
	  None of these while rooted or lifted by a Cryo Beam (the server's jump lock: JumpHeight 0), dashing
	    or dead. Parts with the NoWallRun attribute (a map's invisible edge) can't be run on.
	  A press is read from the keys (Space, a gamepad's A) and, on touch, from JumpRequest. The ground
	    jump itself stays the Humanoid's own; these act only in the air or on a wall.

	MOVEMENT MODE (2026-10-18, movement switch; for team fights). Config.Movement.Mode, or the workspace attribute
	  MovementMode when one is set (read live: the dev panel's MOVEMENT row flips it mid-match). "Full" is everything
	  above. "RunningOnly" keeps the run, the crouch and ONE ordinary ground jump: the crouch key only crouches (no
	  slide, so no slide-jump), and there is no wall run, wall jump or double jump. Each move is refused at its entry
	  (slideRefusal, tryWallRun, onJumpPress, watchJumps); the moves themselves are unchanged. Switched on mid-move, a
	  slide or a wall run ends through its own ending (the slide spends the crouch key, as a fall does); a slide-jump
	  leap or a wall jump's push already in flight finishes as it would have. Kit mobility is not this script's.

	  Abilities stay castable mid-slide. Sliding into a Flash Freeze is good play, and Frost Slide
	  (the Mobility slot) is a dash that TAKES OVER from a slide, leap or wall run rather than stacking
	  on it: the moment a dash starts, whatever was running is dropped, and no slide can start until
	  the dash is over (DashMotor moves the body; see "the dash" below).

	AUTHORITY
	  The server owns WalkSpeed, HipHeight and the slide cooldown (SpellshotService). This script
	  owns the impulses and the feel, because the client has network ownership of its own
	  character -- a velocity applied on the server would fight the client's own simulation and
	  produce rubber-banding. The air and wall moves are client-side only: to the server, and to
	  everyone watching, a wall run is a sprint through the air.
	  It also PREDICTS the server's WalkSpeed and HipHeight for each stance the moment it asks for
	  it, so nothing waits a round trip (see request). Abilities that slow or root you publish caps
	  (SpeedCapSlow / SpeedCapUlt) that both sides apply.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Settings = require(spellFolder:WaitForChild("SpellshotSettings"))
local moveRemote = spellFolder:WaitForChild("MoveRequest")
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local Viewmodel = require(iceFolder:WaitForChild("Viewmodel"))
local DashMotor = require(spellFolder:WaitForChild("DashMotor"))

-- Zephyr's body motor (Skyrider's ride, 2026-10-06; Gust Jump's GustJumpMotor was here before it): whether it owns the
-- body right now, through IceMagic.ZephyrClient.IsActive. Optional and guarded, the RadiantFloat way: no module (or one
-- that fails) is never riding. Not found yet, it is looked for again every ZEPHYR_LOOK_AGAIN seconds, never every frame.
local ZEPHYR_LOOK_AGAIN = 2
local zephyrClient, zephyrLookedAt = nil, -math.huge
local function zephyrRiding()
	if zephyrClient == nil and os.clock() - zephyrLookedAt >= ZEPHYR_LOOK_AGAIN then
		zephyrLookedAt = os.clock()
		local m = iceFolder:FindFirstChild("ZephyrClient")
		if m then
			local ok, mod = pcall(require, m)
			zephyrClient = (ok and type(mod) == "table" and type(mod.IsActive) == "function") and mod or false
		end
	end
	if not zephyrClient then return false end
	local ok, on = pcall(zephyrClient.IsActive)
	return ok and on == true
end

-- Radiant's Halo float (IceMagic.RadiantFloat, 2026-09-29) holds off while a wall run writes the body's velocity: its
-- half-gravity lift would otherwise drift the run upward between these Heartbeats. Optional: no module, no call.
local radiantFloat = nil
local floatHeld = false
local function holdFloat(on)
	if on == floatHeld then return end
	floatHeld = on
	if radiantFloat == nil then
		radiantFloat = false
		local m = iceFolder:FindFirstChild("RadiantFloat")
		if m then
			local ok, mod = pcall(require, m)
			if ok and type(mod) == "table" and type(mod.Suspend) == "function" then radiantFloat = mod end
		end
	end
	if radiantFloat then radiantFloat.Suspend("WallRun", on) end
end

local MOVE = Config.Movement

-- MOVEMENT MODE (2026-10-18, movement switch): "Full" or "RunningOnly" (see the header). The workspace attribute
-- MovementMode wins when it holds a known mode -- a dev sets it live through MovementModeServer, because a Config edit
-- from the command bar during Play never reaches the game -- and Config.Movement.Mode is the default. Cached, and kept
-- current by the attribute's own signal, so the per-frame checks below cost nothing.
local MODES = { Full = true, RunningOnly = true }
local movementMode = "Full"
local function readMovementMode()
	local m = workspace:GetAttribute("MovementMode")
	if not MODES[m] then m = MOVE.Mode end
	movementMode = MODES[m] and m or "Full"
end
readMovementMode()
workspace:GetAttributeChangedSignal("MovementMode"):Connect(readMovementMode)
--- RunningOnly: the run, the crouch and one ground jump; no slide, slide-jump, wall run, wall jump or air jump.
local function runningOnly()
	return movementMode == "RunningOnly"
end

-- When a slide is over before its time runs out (see the slide impulse below).
local SLIDE_AIR_GRACE = 0.15	 -- seconds off the ground before a slide has turned into a fall
local SLIDE_BLOCK_GRACE = 0.12   -- no stop check this early: the entry frame still carries the run
local SLIDE_BLOCKED = 0.45	   -- moving at under this share of the written speed: something is in the way
local SLIDE_BLOCK_HOLD = 0.08	-- ...for this long, so one jolt off a corner doesn't end it

local SLIDE_REGAP = MOVE.SlideRegap or 0.1   -- seconds between one slide's END and the next one's start
local SLIDE_ARM_GROUND = 0.25    -- seconds an armed slide (see slideArmed) waits ON THE GROUND before it is just a crouch

local CROUCH_RESLIDE = 0.2       -- seconds after letting a crouch go in which a slide needs no run-up speed
local SLIDE_DROP_GRACE = 0.2     -- seconds at a slide's start in which being off the ground is the body dropping, not a fall
local HEAD_TOP = 2.2             -- studs from the root's centre to the top of the head (2.14 measured on the uniform rig)
local JUMP_RESCUE_FRAMES = 3     -- Heartbeats a ground jump press waits for the Humanoid's own jump before it is forced
local GROUND_STATES = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}

-- The air and wall moves (the tuning is in SpellshotConfig.Movement).
-- (TouchJump is the on-screen JUMP button's stand-in for a KeyCode: see TOUCH, below the input handlers)
local JUMP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true, TouchJump = true }
local TOUCH_JUMP_GAP = 0.2       -- touch sends JumpRequest again and again while held; a new press follows a gap
local WALL_GRACE = 0.1           -- seconds a wall run survives the wall going missing (a seam, a corner)
local MOVE_SYNC_GRACE = 0.5      -- seconds the server may disagree about the stance before it is told again
local WALL_MIN_AIR = 1.2         -- studs of air under the feet before a wall can be caught
local WALL_HEAD = 1.5            -- the second wall probe, this far above the body's centre

-- Sprint is not a key: it is "moving". Set from Humanoid.MoveDirection on Heartbeat (it reads 0
-- during the render step even mid-stride, so it is sampled on Heartbeat only), so it covers
-- keyboard, gamepad and touch alike.
local held = { Sprint = false, Crouch = false }
local slide = nil          -- { Dir, Start, Until }
local slideTookCrouch = false  -- Toggle Crouch: this slide is what is holding the crouch flag down
-- A SLIDE PRESS THAT COULD NOT START YET (2026-10-04). Ctrl while moving, but in the air or inside the gap
-- after the last slide: the press used to fall through to a crouch and was never looked at again, so
-- slide, slide-jump, land, Ctrl was 8 studs/s out of a 50 studs/s leap. It is held here instead -- no
-- crouch -- and becomes the slide on the first frame it can (see "the armed slide" below).
local slideArmed = nil     -- { Ground = os.clock() when it first waited on the ground } while the key is held
local slideReadyAt = 0     -- os.clock() from which the next slide may start (this client's own clock)
local crouchLeftAt = 0     -- os.clock() the crouch key last let go of a crouch (see slideRefusal)
local jumpWanted = nil     -- { Frames } a jump press on the ground the Humanoid has not answered yet (see "the dropped jump")
local leap = nil           -- { Start, Speed } while a slide-jump's launch speed is carried
local requested = "None"
local airJumps = 0         -- air jumps used since last on the ground or on a wall
local wallRun = nil        -- { Normal, Tangent, Speed, VY, Start, Seen } while riding a wall
local wallKick = nil       -- { Until, Velocity } a wall jump's push, held against air steering
local lastWall = nil       -- { Normal, Time } the wall just left, which can't be caught again yet
-- Every wall caught since the feet last touched the ground, and the height of the latest catch (see tryWallRun)
local airWalls = { Used = {}, Top = nil }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local headParams = RaycastParams.new()      -- the headroom check: only what a body actually collides with
headParams.FilterType = Enum.RaycastFilterType.Exclude
headParams.RespectCanCollide = true

-- hitbox twins (HitboxScale, 2026-10-17) are for shots only: never a floor, wall or ledge for this script's rays
local HitboxTags = game:GetService("CollectionService")
local function withHitboxes(list)
	for _, t in HitboxTags:GetTagged("Hitbox") do list[#list + 1] = t end
	return list
end
HitboxTags:GetInstanceAddedSignal("Hitbox"):Connect(function(t) rayParams:AddToFilter(t) end)

local function character()
	return player.Character
end

local function humanoid()
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- PREDICTED, then confirmed. The server owns WalkSpeed and HipHeight and sets them when a request
-- lands -- a full round trip after the keypress, which on a live server is a slide that drops a
-- tenth of a second late and a run that picks up late after it. So the client applies the same
-- stance values itself the instant it asks (it simulates its own character anyway), and the
-- server's identical values arrive and change nothing. RIVALS behaves the same way: measured off
-- the capture, its eye starts dropping with the slide's bank, at 57 ms ping.
local function cap(c)
	return math.min(c:GetAttribute("SpeedCapSlow") or math.huge, c:GetAttribute("SpeedCapUlt") or math.huge)
end

-- a speed buff (Cold Momentum) scales the stance speed; the caps above still win, as on the server
local function mult(c)
	-- RushSpeedMult is Heat Rush's, apart from Cold Momentum's MoveSpeedMult; the server multiplies both too
	return (c:GetAttribute("MoveSpeedMult") or 1) * (c:GetAttribute("RushSpeedMult") or 1)
end

local STANCE_SPEED = { Crouch = "CrouchSpeed", Sprint = "SprintSpeed", None = "BaseWalkSpeed" }

-- The standing hip height. BaseHipHeight is the server's and arrives a moment after the body
-- spawns; until it does, the height the body spawned at is remembered here. Reading HipHeight back
-- off the Humanoid once a slide has already lowered it is how a body ends up stuck in a crouch.
local standingHip = nil
local function hipBase(c, hum)
	local attr = c:GetAttribute("BaseHipHeight")
	if attr then standingHip = attr end
	return standingHip or hum.HipHeight
end

-- NO ROOM TO STAND (2026-10-04). Letting go of Ctrl under something lower than a standing body used to
-- stand you up anyway: the Humanoid stayed squeezed under it (it has nowhere to go), but at the run's 25
-- studs/s and with the server showing a sprint -- slide into a crouch gap, let go, and you ran through it.
-- A body that is down stays a crouch until there is room above its head.
local function noHeadroom(c, hum)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local rise = hipBase(c, hum) - MOVE.CrouchHipHeight
	if rise <= 0 then return false end
	return workspace:Blockcast(CFrame.new(root.Position), Vector3.new(1.6, 0.2, 0.8),
		Vector3.new(0, HEAD_TOP + rise - 0.15, 0), headParams) ~= nil
end

-- THE STANCE YOU ARE IN RIGHT NOW, read off the live flags -- never remembered, never restored.
-- Every way this script could leave you crawling was a stance saved and then not put back: a
-- refreshState swallowed because a slide or a charge was running (the held flag had ALREADY
-- changed, so nothing ever asked again), a request() that no-opped because the remembered state
-- happened to match, a crouch flag a slide-jump left set. The owner further down writes this every
-- frame, so none of them can outlive a single frame.
local function wantedState()
	if slide then return "Slide" end
	-- a dash ends standing: a crouch key held through one is not a crouch-walk at the end of it
	if held.Crouch and not slideArmed and not DashMotor.IsActive() then return "Crouch" end
	-- already down (the last stance asked for was a crouch or a slide) and nothing above to stand up into
	if (requested == "Crouch" or requested == "Slide") and not DashMotor.IsActive() then
		local c = character()
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and noHeadroom(c, hum) then return "Crouch" end
	end
	return held.Sprint and "Sprint" or "None"
end

-- The same rule the server uses (SpellshotService.stanceSpeed): the stance's speed scaled by the
-- buffs, under whatever caps are on the character at this instant.
local function stanceSpeed(c, state)
	return math.min(MOVE[STANCE_SPEED[state] or "BaseWalkSpeed"] * mult(c), cap(c))
end

local function predict(state)
	local c = character()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return end
	hum.HipHeight = (state == "Crouch" or state == "Slide") and MOVE.CrouchHipHeight or hipBase(c, hum)
	if STANCE_SPEED[state] then hum.WalkSpeed = stanceSpeed(c, state) end     -- a slide or leap sets its own
end

local function request(nextState)
	if nextState == requested then return end
	requested = nextState
	predict(nextState)
	moveRemote:FireServer(nextState)
end

local function grounded(hum)
	return hum.FloorMaterial ~= Enum.Material.Air
end

local function airborne(hum)
	local st = hum:GetState()
	return hum.FloorMaterial == Enum.Material.Air
		and (st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping)
end

--- Rooted or lifted by a Cryo Beam (the server's jump lock), held by a dash, platform-standing or dead:
--- none of the air or wall moves.
local function canMoveInAir(hum, c)
	return hum.Health > 0 and hum.JumpHeight > 0 and not hum.PlatformStand and not DashMotor.IsActive()
		and cap(c) > 0
end

local function horizontalSpeed(root)
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

----------------------------------------------------------------------------------------------------
-- slide
----------------------------------------------------------------------------------------------------
--- Why a slide can't start this frame: nil (it can), "Wait" (in the air, or inside the gap after the last
--- slide -- it will be able to in a moment, so the press is armed rather than spent on a crouch) or "No".
local function slideRefusal()
	-- (2026-10-18, movement switch) RunningOnly has no slide: "No", so the press is the crouch it falls through to and
	-- an armed slide gives up (not "Wait": nothing would ever let it start)
	if runningOnly() then return "No" end
	local hum = humanoid()
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return "No" end
	if DashMotor.IsActive() then return "No" end               -- the dash owns the body until it ends
	if horizontalSpeed(root) < MOVE.SlideMinSpeed then
		-- ...unless the crouch was let go a moment ago and you are steering: Ctrl released and pressed again at
		-- the end of a slide finds the body still at the crouch's 8 studs/s for a frame or two, and that press
		-- was a crouch again. It is the slide, at once (no standing up in between).
		if not (held.Sprint and os.clock() - crouchLeftAt < CROUCH_RESLIDE
			and stanceSpeed(c, "Sprint") >= MOVE.SlideMinSpeed) then
			return "No"
		end
	end
	-- FloorMaterial still reads the floor for the first frames of a jump, so the Humanoid's own state is asked
	-- too: a slide started in those frames ran in the air and ended as a crouch at 8 studs/s mid-jump.
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then return "Wait" end
	if not grounded(hum) then return "Wait" end
	if os.clock() < slideReadyAt then return "Wait" end
	return nil
end

--- The slide is over, however it ended, and the next one is SLIDE_REGAP away. The cooldown used to run only
--- from the slide's START (1.2 s, sized to a full 1.1 s slide), so the shorter the slide the longer the
--- wait: one cut short by a slide-jump or by letting go refused the next press for up to a second.
local function dropSlide()
	if not slide then return end
	slide = nil
	slideReadyAt = math.min(slideReadyAt, os.clock() + SLIDE_REGAP)
end

local function startSlide()
	local hum = humanoid()
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return false end
	if slideRefusal() then return false end
	if DashMotor.IsActive() then return false end               -- the dash owns the body until it ends
	-- (the cooldown is slideRefusal's, on this client's own clock: the server's SlideReadyAt attribute arrives a
	-- round trip late, which is longer than the gap it would be guarding)

	-- Direction is locked at the moment of entry. That is what "momentum-preserving" means
	-- here: a slide continues where you were already going, it is not a second aim input.
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local dir = flat.Magnitude > 1 and flat.Unit or root.CFrame.LookVector
	-- Entry speed CARRIES OVER: the slide opens at whatever you were actually doing, floored at
	-- the designed burst so a slide out of a walk still gets its kick -- and capped at the leap's
	-- top speed, so a frame still carrying a dash's 65 studs/s cannot open a slide at that pace.
	leap = nil
	slide = {
		Dir = Vector3.new(dir.X, 0, dir.Z).Unit,
		Start = os.clock(),
		Entry = math.min(math.max(horizontalSpeed(root), MOVE.SlideSpeed), MOVE.SlideJumpMaxSpeed),
	}
	slideReadyAt = slide.Start + MOVE.SlideDuration + SLIDE_REGAP     -- the backstop; dropSlide pulls it in
	request("Slide")
	return true
end

local function endSlide()
	dropSlide()
	-- Toggle Crouch: the press that began the slide is spent ON the slide. It used to stay latched,
	-- so every slide ended in a crouch-walk at 8 studs/s -- the very thing the toggle's own comment
	-- says must not happen -- and the only way out was to press the key twice.
	if slideTookCrouch then
		slideTookCrouch = false
		held.Crouch = false
	end
	request(wantedState())
end

----------------------------------------------------------------------------------------------------
-- slide-jump
----------------------------------------------------------------------------------------------------
-- Detected from the Humanoid actually jumping rather than from a key, so Space, a gamepad's A and
-- the touch button all count, and a jump the Humanoid refuses (already airborne, rooted by a
-- freeze) never fires it. By the time StateChanged reports Jumping the Humanoid has launched at
-- its own JumpHeight, so the leap simply replaces that velocity with its own.
local function slideJump(hum, root)
	local full = math.clamp(horizontalSpeed(root) + MOVE.SlideJumpBoost, MOVE.SlideJumpMinSpeed, MOVE.SlideJumpMaxSpeed)
	-- THE BOOST IS EARNED BY SLIDING (2026-10-04). Ctrl and Space pressed together used to be a slide of no
	-- length and the full leap out of it, and with a slide waiting on every landing that chained: 49
	-- studs/s held for as long as you kept pressing both, without ever sliding. The leap's speed now grows
	-- from the run's to the full figure over the slide's first SlideJumpMinSlide seconds -- measured from
	-- the RUN, not from the speed carried in, so a landing at 50 jumped out of at once is 25 again.
	local earned = math.clamp((os.clock() - slide.Start) / (MOVE.SlideJumpMinSlide or 0.25), 0, 1)
	local run = MOVE.SprintSpeed * mult(hum.Parent)
	local speed = math.min(run + math.max(0, full - run) * earned, cap(hum.Parent))
	local dir = slide.Dir
	dropSlide()
	leap = { Start = os.clock(), Speed = speed }
	-- The apex is measured from STANDING height. Mid-slide the body rides up to HipHeight lower, so
	-- the gap back up to standing is added -- measured off the floor, because in the first frames of
	-- a slide the body has not come down yet.
	local standing = (hum.Parent:GetAttribute("BaseHipHeight") or hum.HipHeight) + root.Size.Y / 2
	local floor = workspace:Raycast(root.Position, Vector3.new(0, -(standing + 2), 0), rayParams)
	local low = floor and math.max(0, standing - (root.Position.Y - floor.Position.Y)) or 0
	local up = math.sqrt(2 * workspace.Gravity * (MOVE.SlideJumpHeight + low))
	root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, up, dir.Z * speed)
	-- THE HUMANOID'S OWN JUMP LANDS AFTER THIS WRITE (measured 2026-10-05: the apex was the plain jump's 7.2 whatever
	-- SlideJumpHeight said, 6.0 or 4.0). The leap's Heartbeat puts the leap's own climb back on its first frame.
	leap.Up = up
	-- The server ends the slide and stands you up; this is the only early way out it accepts.
	-- Stand up here and now rather than a round trip later, then carry the leap's own speed.
	-- THE JUMP SPENDS THE CROUCH KEY. The server puts you in Sprint for a slide-jump, but the client
	-- landed straight back into a crouch because Ctrl was still down (or, with Toggle Crouch, still
	-- latched): 8 studs/s at the end of a 45 studs/s leap, with nothing on screen to say why. A crouch
	-- after a slide-jump now takes a fresh press of the key.
	slideTookCrouch = false
	held.Crouch = false
	predict("Sprint")
	hum.WalkSpeed = speed
	moveRemote:FireServer("SlideJump")
	requested = "Sprint"
end

local function watchJumps(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then jumpWanted = nil end      -- the press was answered
		-- (2026-10-18, movement switch) no slide-jump in RunningOnly: a jump in the frame the switch lands is a plain jump
		if new ~= Enum.HumanoidStateType.Jumping or not slide or runningOnly() then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root and hum.Health > 0 then slideJump(hum, root) end
	end)
end

----------------------------------------------------------------------------------------------------
-- walls
----------------------------------------------------------------------------------------------------
-- A wall is a colliding, near-vertical surface that is not a body and not marked NoWallRun.
local function wallHit(origin, direction)
	local hit = workspace:Raycast(origin, direction, rayParams)
	if not hit then return nil end
	local part = hit.Instance
	if not part.CanCollide or part:GetAttribute("NoWallRun") or math.abs(hit.Normal.Y) > 0.3 then return nil end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then return nil end
	return hit
end

--- The wall beside the body in the flat direction `dir`: hit at the body's centre AND at head height,
--- facing the same way, so the side of a low ledge or a rail is not a wall. Returns the centre hit and
--- its flattened normal.
local function wallAlong(root, dir, reach)
	local low = wallHit(root.Position, dir * reach)
	if not low then return nil end
	local high = wallHit(root.Position + Vector3.new(0, WALL_HEAD, 0), dir * (reach + 0.3))
	if not high or high.Normal:Dot(low.Normal) < 0.9 then return nil end
	return low, Vector3.new(low.Normal.X, 0, low.Normal.Z).Unit
end

local function endWallRun(now)
	if not wallRun then return end
	lastWall = { Normal = wallRun.Normal, Time = now }
	wallRun = nil
	if not leap and not wallKick then predict(requested) end      -- back to the stance's own air speed
end

--- Catch a wall: airborne, fast enough, steering along a wall that is beside you with air under your feet.
local function tryWallRun(hum, root, c, now)
	if runningOnly() then return end                                -- (2026-10-18, movement switch) no wall run in RunningOnly
	if slide or held.Crouch or not airborne(hum) or not canMoveInAir(hum, c) then return end
	if zephyrRiding() then return end                               -- a Skyrider ride owns the body: no wall to catch
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local steer = hum.MoveDirection
	if flat.Magnitude < MOVE.WallRunMinSpeed or steer.Magnitude < 0.1 or cap(c) < MOVE.WallRunMinSpeed then return end
	local standing = (c:GetAttribute("BaseHipHeight") or hum.HipHeight) + root.Size.Y / 2
	if workspace:Raycast(root.Position, Vector3.new(0, -(standing + WALL_MIN_AIR), 0), rayParams) then return end
	local dir = flat.Unit
	local right = dir:Cross(Vector3.yAxis)
	local best, normal
	for _, side in ipairs({ 1, -1 }) do
		local hit, n = wallAlong(root, right * side, MOVE.WallRunReach)
		if hit and (not best or hit.Distance < best.Distance) then best, normal = hit, n end
	end
	if not best then return end
	-- ONE CATCH PER WALL PER JUMP, AND NEVER HIGHER THAN THE LAST (2026-10-16: "you can infinitely bug it -- wall ride,
	-- jump off and get on the wall again with more height"). WallRunRegrab alone was a timer, and at gravity 64 a wall
	-- jump is still climbing when 0.45 s runs out, so the same wall was caught again higher up, over and over. Now a
	-- wall you have ridden stays spent until you land (the same face: same facing, same plane give or take 3 studs), and
	-- a catch has to be no higher than the one before it, so two facing walls can't be climbed by zig-zagging either.
	for _, used in ipairs(airWalls.Used) do
		if normal:Dot(used.Normal) > 0.8 and math.abs((best.Position - used.Pos):Dot(used.Normal)) < 3 then return end
	end
	if airWalls.Top and root.Position.Y > airWalls.Top + 0.5 then return end
	if lastWall and now - lastWall.Time < MOVE.WallRunRegrab and normal:Dot(lastWall.Normal) > 0.8 then return end
	local along = flat - normal * flat:Dot(normal)
	if along.Magnitude < MOVE.WallRunMinSpeed then return end
	local tangent = along.Unit
	if steer:Dot(tangent) < 0.35 then return end                    -- steering along the wall, not off it
	leap = nil
	wallKick = nil
	airJumps = 0                                                    -- a wall gives the double jump back
	table.insert(airWalls.Used, { Pos = best.Position, Normal = normal })
	airWalls.Top = root.Position.Y
	wallRun = {
		Normal = normal, Tangent = tangent, Start = now, Seen = now,
		Speed = math.min(math.max(along.Magnitude, MOVE.WallRunSpeed * mult(c)), MOVE.SlideJumpMaxSpeed, cap(c)),
		VY = math.max(v.Y * 0.5, MOVE.WallRunLift),
	}
end

local function stepWallRun(hum, root, c, now, dt)
	local w = wallRun
	-- (a Skyrider ride starting mid-run takes the body: the run lets go, as it did for a Gust Jump's launch)
	-- (2026-10-18, movement switch: RunningOnly switched on mid-run lets go here, as running out of time does)
	if now - w.Start > MOVE.WallRunTime or held.Crouch or not canMoveInAir(hum, c) or grounded(hum) or zephyrRiding()
		or runningOnly() then
		endWallRun(now)
		return
	end
	local steer = hum.MoveDirection
	if steer.Magnitude < 0.1 or steer:Dot(w.Normal) > 0.6 or steer:Dot(w.Tangent) < 0 then
		endWallRun(now)                                             -- let go, or steered off the wall
		return
	end
	local hit, n = wallAlong(root, -w.Normal, MOVE.WallRunReach + 0.8)
	if hit and n:Dot(w.Normal) > 0.7 then
		w.Seen = now
		w.Normal = n
		w.Tangent = (w.Tangent - n * w.Tangent:Dot(n)).Unit              -- follow a curving wall
	elseif now - w.Seen > WALL_GRACE then
		endWallRun(now)                                             -- the wall ran out
		return
	end
	w.Speed = math.min(w.Speed, cap(c))
	if w.Speed < MOVE.WallRunMinSpeed then
		endWallRun(now)
		return
	end
	w.VY = math.max(w.VY - workspace.Gravity * MOVE.WallRunGravity * dt, -MOVE.WallRunMaxFall)
	-- In the air the Humanoid steers toward MoveDirection * WalkSpeed, so WalkSpeed is set to the run's
	-- speed rather than left to pull it back to the sprint.
	hum.WalkSpeed = w.Speed
	root.AssemblyLinearVelocity = w.Tangent * w.Speed - w.Normal * MOVE.WallRunStick + Vector3.new(0, w.VY, 0)
end

----------------------------------------------------------------------------------------------------
-- the jump in the air: wall jump and double jump
----------------------------------------------------------------------------------------------------
local function wallJump(hum, root, c, now)
	local w = wallRun
	local keep = math.max(w.Speed, MOVE.SprintSpeed * mult(c))
	local push = w.Tangent * keep + w.Normal * MOVE.WallJumpPush
	if push.Magnitude > cap(c) then push = push.Unit * cap(c) end
	wallRun = nil
	lastWall = { Normal = w.Normal, Time = now }
	wallKick = { Until = now + MOVE.WallJumpKeep, Velocity = push }
	hum.WalkSpeed = math.min(keep, cap(c))
	root.AssemblyLinearVelocity = Vector3.new(push.X, math.sqrt(2 * workspace.Gravity * MOVE.WallJumpHeight), push.Z)
end

local function doubleJump(hum, root)
	airJumps += 1
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local steer = hum.MoveDirection
	if steer.Magnitude > 0.1 then
		flat = Vector3.new(steer.X, 0, steer.Z).Unit * flat.Magnitude      -- re-aim the speed you carry
	end
	wallKick = nil
	root.AssemblyLinearVelocity = Vector3.new(flat.X, math.sqrt(2 * workspace.Gravity * MOVE.DoubleJumpHeight), flat.Z)
end

local function menusOpen()
	return player:GetAttribute("SettingsOpen") or player:GetAttribute("LoadoutOpen") or player:GetAttribute("QuickPlayOpen")
		or player:GetAttribute("ShopOpen")
end

--- A jump PRESS. On the ground this does nothing: the Humanoid makes the ground jump (and a slide-jump
--- out of a slide) itself.
local function onJumpPress()
	if menusOpen() then return end
	local c = character()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or not canMoveInAir(hum, c) then return end
	local now = os.clock()
	if not wallRun and GROUND_STATES[hum:GetState()] then
		jumpWanted = { Frames = 0 }                                 -- the Humanoid's to make; see "the dropped jump"
	-- (2026-10-18, movement switch) RunningOnly: the ground jump above only -- no wall jump, no double jump
	elseif wallRun and not runningOnly() then
		wallJump(hum, root, c, now)
	elseif not slide and airborne(hum) and airJumps < MOVE.AirJumps and not zephyrRiding() and not runningOnly() then
		doubleJump(hum, root)                                       -- never over a Skyrider ride (its Jump is the dismount)
	end
end

local lastTouchJump = 0
UserInputService.JumpRequest:Connect(function()
	-- keys and gamepads are read as presses below; JumpRequest is for the touch button
	if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then return end
	local now = os.clock()
	local fresh = now - lastTouchJump > TOUCH_JUMP_GAP
	lastTouchJump = now
	if fresh then onJumpPress() end
end)

----------------------------------------------------------------------------------------------------
-- the dash
----------------------------------------------------------------------------------------------------
-- Frost Slide's dash is DashMotor's, not this script's: it moves the body with a constraint for a
-- fifth of a second. All this script does is get out of the way. A slide, leap or wall run in
-- progress is dropped on the spot -- their Heartbeats below would otherwise keep writing their own
-- speed over the dash -- and the stance goes back to the run (or standing), never to a crouch:
-- dashing out of a slide with Ctrl still held is a dash, not a crouch-walk at the end of it.
-- When the dash ends, the stance's WalkSpeed and HipHeight are applied again, because the stance
-- request above is skipped when nothing changed (a leap's raised WalkSpeed would otherwise outlive
-- it), and a cap may have come or gone during the dash.
DashMotor.Started.Event:Connect(function()
	-- Toggle Crouch: a slide the dash takes over gives its press back, as endSlide does. It stayed latched,
	-- so a dash out of a slide ended in a crouch-walk until the key was pressed again.
	if slide and slideTookCrouch then
		slideTookCrouch = false
		held.Crouch = false
	end
	dropSlide()
	slideArmed = nil
	jumpWanted = nil
	leap = nil
	wallRun = nil
	wallKick = nil
	request(held.Sprint and "Sprint" or "None")
end)

-- (A Gust Jump launched mid wall run used to end the run here, from GustJumpMotor.Launched. Skyrider, which replaced it on
-- 2026-10-06, has no such event: stepWallRun lets go when zephyrRiding() turns true.)

----------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------
local function refreshState()
	-- It used to give up while a slide or a dash was running. The flag it had been called FOR
	-- (sprint, crouch) had already changed by then, so the change was simply lost and nothing ever
	-- asked again: start moving during a Cross-Slash charge and the run was never requested, so you
	-- walked at 16 afterwards until something else happened to change the stance. wantedState reads
	-- the flags live, and during a slide or a dash it answers with the state those already set.
	request(wantedState())
end

-- A dash ends standing: whatever the player is holding NOW (crouch, sprint) takes over, and predict
-- puts WalkSpeed back even when that state did not change (request skips an unchanged state).
DashMotor.Ended.Event:Connect(function()
	refreshState()
	predict(requested)
end)

--- Crouch, and therefore slide -- they are one key by design: a slide IS a crouch entered while
--- you are moving fast. Right Control keeps working while the bind is at its default, because it
--- always has and nobody expects rebinding to be what takes it away.
local function isCrouchKey(k)
	if k == "TouchCrouch" then return true end                -- the on-screen SLIDE button (TOUCH, below)
	if k == Settings.KeyCode("Pad_Crouch") then return true end
	local bound = Settings.KeyCode("Bind_Crouch")
	if not bound then return false end
	if k == bound then return true end
	return bound == Enum.KeyCode.LeftControl and k == Enum.KeyCode.RightControl
end

local function onInputBegan(input, gameProcessed)
	local k = input.KeyCode
	-- The default controls bind jump through ContextActionService, which marks the press as already
	-- processed, so a jump key is read BEFORE that check. A key typed into a text box is not a jump.
	if JUMP_KEYS[k] then
		if not UserInputService:GetFocusedTextBox() then onJumpPress() end
		return
	end
	if gameProcessed then return end
	if menusOpen() then return end
	if isCrouchKey(k) then
		-- TOGGLE CROUCH flips the stance on the press instead of holding it down. A slide is still
		-- the same press while moving: tapping into a slide and standing up out of it is the shape
		-- players expect, so a toggle that ended up crouched after every slide would be wrong.
		if Settings.Get("ToggleCrouch") then
			if held.Crouch then
				held.Crouch = false
				slideArmed = nil
				if requested == "Crouch" then crouchLeftAt = os.clock() end
				refreshState()
				return
			end
			held.Crouch = true
		else
			held.Crouch = true
		end
		-- Ctrl WHILE moving is a slide, not a crouch. If the slide is refused (airborne, too
		-- slow, on cooldown) it falls through to an ordinary crouch rather than doing nothing.
		if held.Sprint then
			if startSlide() then
				-- with Toggle Crouch this press belongs to the slide; endSlide gives it back
				slideTookCrouch = Settings.Get("ToggleCrouch") and true or false
				return
			end
			-- Refused only for NOW (airborne, or the gap after the last slide): the press stays armed and is
			-- the slide the moment it can be, instead of a crouch that had to be let go and pressed again.
			if slideRefusal() == "Wait" then
				slideArmed = {}
				return
			end
		end
		refreshState()
	end
end
UserInputService.InputBegan:Connect(onInputBegan)

local function onInputEnded(input)
	local k = input.KeyCode
	if isCrouchKey(k) and not Settings.Get("ToggleCrouch") then
		held.Crouch = false
		slideArmed = nil
		if requested == "Crouch" then crouchLeftAt = os.clock() end
		refreshState()
	end
end
UserInputService.InputEnded:Connect(onInputEnded)

-- TOUCH (2026-10-04). TouchControls' JUMP and SLIDE buttons arrive through TouchBus and run the two handlers above,
-- as Space and the crouch key do. One thing is added: on a key the default controls make the ground jump, and no
-- default control saw this press, so the Humanoid is asked here (the dropped-jump rescue below still backs it up).
do
	local TouchBus = require(spellFolder:WaitForChild("TouchBus"))
	TouchBus.Event:Connect(function(action, down)
		if action == "Jump" then
			if not down or menusOpen() then return end
			local hum = humanoid()
			if hum and hum.Health > 0 then hum.Jump = true end
			onInputBegan({ KeyCode = "TouchJump" }, false)
		elseif action == "Crouch" then
			local input = { KeyCode = "TouchCrouch" }
			if down then onInputBegan(input, false) else onInputEnded(input) end
		end
	end)
end

-- A key let go while the window is not in front never sends its InputEnded, so a held crouch would stay down
-- until the key was pressed and released again. (Toggle Crouch has nothing held to lose.)
UserInputService.WindowFocusReleased:Connect(function()
	if Settings.Get("ToggleCrouch") or not held.Crouch then return end
	held.Crouch = false
	slideArmed = nil
	refreshState()
end)

-- AUTO-SPRINT. Any movement input is a sprint; releasing it is a stop. Sampled on Heartbeat
-- because Humanoid.MoveDirection reads 0 on the render step while you are plainly walking.
RunService.Heartbeat:Connect(function()
	local hum = humanoid()
	local moving = hum ~= nil and hum.Health > 0 and hum.MoveDirection.Magnitude > 0.05
	if moving ~= held.Sprint then
		held.Sprint = moving
		refreshState()
	end
end)

-- A speed buff coming or going (Heat Rush held, Cold Momentum) re-applies the stance's speed here as well, the
-- moment the attribute arrives, rather than leaving it to the server's WalkSpeed write alone (2026-09-14: Heat
-- Rush's speed-up could not be felt). A leap, wall run or dash holds its own speed and is left alone (the dash's
-- end re-applies the stance anyway); predict sets none for a slide.
local function watchSpeed(c)
	for _, name in ipairs({ "MoveSpeedMult", "RushSpeedMult" }) do
		c:GetAttributeChangedSignal(name):Connect(function()
			if c == character() and not leap and not wallRun and not wallKick and not DashMotor.IsActive() then
				predict(requested)
			end
		end)
	end
end

local function onCharacter(c)
	slide = nil
	slideTookCrouch = false
	slideArmed = nil
	slideReadyAt = 0
	jumpWanted = nil
	standingHip = nil
	leap = nil
	wallRun = nil
	wallKick = nil
	lastWall = nil
	table.clear(airWalls.Used)
	airWalls.Top = nil
	airJumps = 0
	requested = "None"
	held.Sprint = false
	held.Crouch = false
	rayParams.FilterDescendantsInstances = withHitboxes({ c })
	headParams.FilterDescendantsInstances = { c }
	task.spawn(watchJumps, c)
	watchSpeed(c)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

----------------------------------------------------------------------------------------------------
-- per-frame: the armed slide
----------------------------------------------------------------------------------------------------
-- A slide press that was refused only for the moment (see slideArmed) is tried again every frame while the
-- key is down and you are still moving: it starts on the frame you touch down, or the frame the gap after
-- the last slide is over. It gives up -- and the key becomes the crouch it would have been -- when the
-- refusal turns final (too slow by now, a dash) or it has stood on the ground for SLIDE_ARM_GROUND.
RunService.Heartbeat:Connect(function()
	if not slideArmed then return end
	local hum = humanoid()
	if not (hum and hum.Health > 0) or not held.Crouch then slideArmed = nil; return end
	local now = os.clock()
	if held.Sprint and startSlide() then
		slideArmed = nil
		slideTookCrouch = Settings.Get("ToggleCrouch") and true or false
		return
	end
	if grounded(hum) then
		slideArmed.Ground = slideArmed.Ground or now
	else
		slideArmed.Ground = nil
	end
	if not held.Sprint or slideRefusal() ~= "Wait"
		or (slideArmed.Ground and now - slideArmed.Ground > SLIDE_ARM_GROUND) then
		slideArmed = nil
		refreshState()
	end
end)

----------------------------------------------------------------------------------------------------
-- per-frame: the dropped jump
----------------------------------------------------------------------------------------------------
-- The default controls make the ground jump: they read the jump key on the render step and set
-- Humanoid.Jump while it is down. A tap whose press and release both arrive inside one frame is never
-- seen down, so nothing jumps -- measured 2026-10-04 with real keys: 9 of 9 such taps mid-slide did
-- nothing (the "missed slide-jump"), and plain running jumps were lost the same way. The press is
-- remembered here; if the Humanoid has not entered Jumping a few frames later and is still standing on
-- the ground, the jump is made for it. A press the Humanoid answers itself is cleared in watchJumps, so
-- this never adds a second jump -- and a slide-jump comes out of it the usual way, off StateChanged.
RunService.Heartbeat:Connect(function()
	if not jumpWanted then return end
	jumpWanted.Frames += 1
	if jumpWanted.Frames < JUMP_RESCUE_FRAMES then return end
	jumpWanted = nil
	local c = character()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum or not canMoveInAir(hum, c) or not grounded(hum) or not GROUND_STATES[hum:GetState()] then return end
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
end)

----------------------------------------------------------------------------------------------------
-- per-frame: the slide impulse
----------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	if not slide then return end
	local hum = humanoid()
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then slide = nil; return end

	local now = os.clock()
	local t = (now - slide.Start) / MOVE.SlideDuration
	-- THE SLIDE LASTS AS LONG AS YOU ARE ACTUALLY SLIDING, and SlideDuration is only the longest it can
	-- run. It used to be a fixed 1.1 s from the keypress: tap Ctrl, run into a wall or slide off a
	-- ledge, and the arms, the camera bank and everyone else's view of your body went on sliding
	-- anyway. It ends the moment any of these stops being true:
	--   the key is still held	   (with Toggle Crouch: until it is pressed again)
	--   you are still on the ground  (after a short grace, so a bump or a seam isn't a fall)
	--   nothing has stopped you	  (moving at well under the speed being written = a wall or a body)
	-- (2026-10-18, movement switch) RunningOnly switched on mid-slide: the slide ends here, the way any slide ends, and
	-- the switch SPENDS THE CROUCH KEY as a fall does (below) -- back to the run, not a crawl out of 34 studs/s; a
	-- crouch takes a fresh press.
	if runningOnly() then
		held.Crouch = false
		endSlide()
		return
	end
	if t >= 1 or not held.Crouch then
		endSlide()
		return
	end
	if grounded(hum) then
		slide.AirSince = nil
	elseif not slide.AirSince then
		-- Lowering the hips takes the floor away for a moment, and a body caught still rising out of a crouch
		-- is thrown clear of it for about a quarter second: counted from SLIDE_DROP_GRACE in, or that slide
		-- ended as a "fall" 0.2 s after it began.
		slide.AirSince = math.max(now, slide.Start + SLIDE_DROP_GRACE)
	elseif now - slide.AirSince > SLIDE_AIR_GRACE then
		-- A SLIDE THAT LEAVES THE GROUND IS A RUN IN THE AIR (2026-10-08). With the key still held its end was a
		-- crouch: 34 studs/s to the crouch's 8 in mid-air, the camera dipped, and a crawl on landing. THE FALL
		-- SPENDS THE CROUCH KEY, as a slide-jump does (see slideJump) and as Toggle Crouch always has (endSlide
		-- gives that press back): the run while you fall and when you land; a new slide, or a crouch, takes a
		-- fresh press. (The day's first fix ARMED the held key instead: a new slide on every landing by itself,
		-- each at the full entry speed, for as long as the ground kept dropping away. Review: more than was asked.)
		held.Crouch = false
		endSlide()
		return
	end
	if slide.Written and now - slide.Start > SLIDE_BLOCK_GRACE
		and horizontalSpeed(root) < slide.Written * SLIDE_BLOCKED then
		slide.BlockedSince = slide.BlockedSince or now
		if now - slide.BlockedSince > SLIDE_BLOCK_HOLD then
			endSlide()
			return
		end
	else
		slide.BlockedSince = nil
	end
	-- HELD, then eased. RIVALS' slide keeps ~1.4x its running pace for most of its second, so the
	-- curve stays near the entry speed and only gives ground in the last third, landing on
	-- SlideEndSpeed -- still above sprint -- as the duration runs out.
	local hold = 1 - t ^ MOVE.SlideHold
	local speed = MOVE.SlideEndSpeed + (slide.Entry - MOVE.SlideEndSpeed) * hold

	-- WalkSpeed has to come down the curve WITH the velocity write. The Humanoid drives the
	-- character toward MoveDirection * WalkSpeed every physics step, so leaving WalkSpeed at a
	-- single value is what pinned the old slide to one constant pace no matter what this wrote.
	speed = math.min(speed, cap(c))                -- a slow or root holds a slide back too
	if speed < MOVE.SlideMinSpeed then			-- a root or a heavy slow stops a slide outright
		endSlide()
		return
	end
	slide.Written = speed
	local hum2 = humanoid()
	if hum2 then hum2.WalkSpeed = speed end

	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(slide.Dir.X * speed, v.Y, slide.Dir.Z * speed)
end)

-- The leap's carried speed. In the air the Humanoid steers you toward MoveDirection * WalkSpeed,
-- so WalkSpeed IS the air speed. It is HELD at the launch speed for the whole flight -- bleeding it
-- off mid-air is what made the old leap feel like an ordinary jump -- and only after you land does
-- it ease back to sprint, so the landing keeps some of the run-up instead of stopping dead.
-- Landing with Ctrl still held drops straight into the crouch (press it again for a new slide).
RunService.Heartbeat:Connect(function()
	if not leap then return end
	local hum = humanoid()
	if not (hum and hum.Health > 0) then leap = nil; return end
	local now = os.clock()
	if leap.Up then
		-- the leap's climb, less what gravity has taken since the jump (see slideJump)
		local root = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart")
		if root then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, leap.Up - workspace.Gravity * (now - leap.Start), v.Z)
		end
		leap.Up = nil
	end
	if not leap.Landed then
		if now - leap.Start > 0.15 and grounded(hum) then
			leap.Landed = now
			if held.Crouch and not slideArmed then            -- (an armed slide takes the landing itself)
				leap = nil
				refreshState()
				return
			end
		elseif now - leap.Start > MOVE.SlideJumpAirHold then
			leap.Landed = now                    -- a long fall: stop holding, start the bleed
		end
	end
	local u = leap.Landed and (now - leap.Landed) / MOVE.SlideJumpLandBleed or 0
	if u >= 1 then
		leap = nil
		hum.WalkSpeed = math.min(MOVE.SprintSpeed * mult(hum.Parent), cap(hum.Parent))
		refreshState()
		return
	end
	local sprint = MOVE.SprintSpeed * mult(hum.Parent)
	hum.WalkSpeed = math.min(sprint + (leap.Speed - sprint) * (1 - u), cap(hum.Parent))
end)

----------------------------------------------------------------------------------------------------
-- per-frame: speed is kept in the air
----------------------------------------------------------------------------------------------------
-- (2026-10-05, asked for: "speed should be constant in jumps, no slowing down unless you hold S or look 180 and go
-- the opposite way".) The Humanoid steers an airborne body toward MoveDirection * WalkSpeed, so letting go of W
-- mid-jump stopped you dead in the air, and a sideways tap traded pace for the turn. Now the flat speed you leave the
-- ground with is CARRIED until you land: each frame it is put back, along whichever way you are actually travelling,
-- so steering still bends the path and only the pace is held. Steering AGAINST the travel (S, or W after turning
-- round) lets go of it, and the Humanoid brakes and reverses as it always did; the speed you have when you stop
-- opposing is the one carried from there. It is only ever a floor, and never above the cap a slow or a root
-- publishes: a knock-back can still throw you faster, and a slide, wall run, wall kick, dash and Skyrider ride write
-- their own speeds and are left alone.
do
	local AIR_OPPOSE = -0.5         -- MoveDirection . travel below this is "going the other way"
	local carried = nil             -- { Speed, Dir, Wrote } while airborne
	RunService.Heartbeat:Connect(function()
		local c = character()
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if not (hum and root and hum.Health > 0) or not airborne(hum) or not canMoveInAir(hum, c)
			or slide or wallRun or wallKick or zephyrRiding() then
			carried = nil
			return
		end
		local v = root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		local speed = flat.Magnitude
		if not carried then
			carried = { Speed = speed, Dir = speed > 0.5 and flat.Unit or nil }
			return
		end
		local dir = speed > 0.5 and flat.Unit or carried.Dir
		local steer = hum.MoveDirection
		if dir and steer.Magnitude > 0.1 and steer.Unit:Dot(dir) < AIR_OPPOSE then
			carried.Speed, carried.Dir, carried.Wrote = speed, dir, nil   -- braking: whatever is left is what is carried
			return
		end
		if speed > carried.Speed then
			-- your own steering may build speed up to the stance's; anything past that is a push, and is not kept
			carried.Speed = math.max(carried.Speed, math.min(speed, hum.WalkSpeed))
		end
		carried.Dir = dir
		local keep = math.min(carried.Speed, cap(c))
		if dir and speed < keep then
			-- With no key held the Humanoid brakes through every physics step of the frame, so a write of exactly
			-- `keep` averaged about 5% under it (measured). What it took off the last write is half given back up
			-- front, which makes the frame's AVERAGE the carried speed.
			local lost = carried.Wrote and math.clamp(carried.Wrote - speed, 0, keep * 0.4) or 0
			local write = keep + lost / 2
			carried.Wrote = write
			root.AssemblyLinearVelocity = Vector3.new(dir.X * write, v.Y, dir.Z * write)
		else
			carried.Wrote = nil
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- per-frame: the air and wall moves
----------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local c = character()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then
		wallRun, wallKick = nil, nil
		holdFloat(false)
		return
	end
	local now = os.clock()
	if grounded(hum) then
		airJumps = 0                           -- the double jump comes back on landing
		table.clear(airWalls.Used)             -- ...and every wall can be ridden again
		airWalls.Top = nil
	end
	if DashMotor.IsActive() then
		wallRun, wallKick = nil, nil
		holdFloat(false)
		return
	end
	if not wallRun then tryWallRun(hum, root, c, now) end
	if wallRun then stepWallRun(hum, root, c, now, dt) end
	holdFloat(wallRun ~= nil)
	if wallKick then
		if now > wallKick.Until or grounded(hum) or wallRun then
			wallKick = nil
			if not leap and not wallRun then predict(requested) end
		else
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(wallKick.Velocity.X, v.Y, wallKick.Velocity.Z)
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- per-frame: THE ONE OWNER OF WalkSpeed
----------------------------------------------------------------------------------------------------
-- Nothing saves a walk speed and puts it back any more. On every frame in which no move is holding
-- the body -- no slide, no leap, no wall run, no wall kick, no dash and no charge's hold -- the
-- stance's own speed is written from the live flags and the live caps. A stance that was never
-- re-requested, a restore skipped by an early return, a cap that came and went while a slide was
-- running, two systems each putting back their own remembered number: none of them can leave you
-- crawling, because the next frame writes the right speed whatever happened in the last one.
-- It is connected LAST, after the slide, leap and wall Heartbeats above, so a move that is actually
-- running writes its own speed and this leaves it alone.
RunService.Heartbeat:Connect(function()
	local c = character()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return end
	if slide or leap or wallRun or wallKick then return end
	-- A dash, and a charge's hold before it (DashMotor.IsActive is true for both), move the body with
	-- a constraint of their own and WalkSpeed is not theirs to fight. The frame their hold lets go,
	-- the lines below write the stance again -- which is exactly what a charge that ends WITHOUT a
	-- dash needs, because that one never fires DashMotor.Ended at all.
	if DashMotor.IsActive() then return end
	local state = wantedState()
	-- asked for here too: a crouch held only by a low ceiling ends when you walk out from under it, and
	-- no key or stick event marks that moment
	request(state)
	hum.WalkSpeed = stanceSpeed(c, state)
	hum.HipHeight = (state == "Crouch") and MOVE.CrouchHipHeight or hipBase(c, hum)
end)

-- THE SERVER IS TOLD AGAIN when it disagrees. request() only fires when the state CHANGES, so a
-- request the server dropped -- a SlideJump it refused because the stance behind it landed first,
-- one sent in the frame the body died -- left the two sides disagreeing for good. That matters
-- because the server re-asserts ITS OWN MoveState's speed whenever a cap or a buff moves
-- (SpellshotService watches SpeedCapSlow, SpeedCapUlt, MoveSpeedMult and RushSpeedMult), so a
-- server still parked in Crouch drops a running player to 8 studs/s the next time any of those
-- change -- a second, or a minute, after the slide-jump that caused it, for no reason the player
-- can see. The replicated MoveState is compared with what this client wants and the request is
-- simply sent again, once, after a round trip's grace.
local syncAt = 0
RunService.Heartbeat:Connect(function()
	local c = character()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then syncAt = 0; return end
	if requested == "Slide" and not slide then request(wantedState()) end   -- a slide gone without a word
	local server = c:GetAttribute("MoveState")
	-- a slide is over within the second either way, and a dash is not a stance: neither is resent
	if server == nil or server == requested or slide or DashMotor.IsActive() then
		syncAt = 0
		return
	end
	local now = os.clock()
	if syncAt == 0 then
		syncAt = now + MOVE_SYNC_GRACE
	elseif now >= syncAt then
		syncAt = 0
		moveRemote:FireServer(requested)
	end
end)

----------------------------------------------------------------------------------------------------
-- posture: camera dip, slide roll and wall-run bank
----------------------------------------------------------------------------------------------------
-- The Viewmodel owns Humanoid.CameraOffset (it also carries the cast clips' own camera punch), so
-- the crouch dip is handed over as a separate posture offset and summed there rather than written
-- directly -- otherwise whichever of the two wrote last each frame would win.
--
-- The viewmodel's MOVEMENT state is fed from here too, and deliberately from this script's own key
-- flags and slide timer rather than from the replicated MoveState attribute. First person is not
-- waiting on a round trip to know that Shift is down: the arms change on the keypress. The body
-- animation everyone else sees does read the replicated attribute, and that is fine -- the two
-- systems are not trying to agree frame for frame. On a wall run the arms keep running.
-- THE SLIDE CAMERA, measured off RIVALS (two slides at 30 fps; roll read from the lean of the wall
-- seams, eye height from where the horizon crosses the wall tiles):
--   * it banks 6.5 degrees and HOLDS it for the whole slide -- no unwinding as the slide slows --
--     getting there in about four frames and levelling out in about four when the slide ends
--   * the eye drops to about two thirds of standing height over the same four frames
-- Both ride one 0..1 amount, walked at a constant rate and eased, so bank and drop move as one.
-- A crouch keeps exactly the dip it always had. A slide blends in from standing and out to whatever
-- follows it, and a slide-jump leap or a dash carries no crouch dip even with Ctrl still held.
-- THE WALL-RUN CAMERA banks WallRunTilt AWAY from the wall on its own 0..1 amount, summed with the slide's.
local slideCam = 0
local rollSign = -1
local wallCam = 0
local wallSign = 1
local roll = 0
RunService.RenderStepped:Connect(function(dt)
	local c = character()
	local step = dt / MOVE.SlideTiltRamp
	slideCam = math.clamp(slideCam + (slide and step or -step), 0, 1)
	local e = slideCam * slideCam * (3 - 2 * slideCam)
	local wstep = dt / MOVE.WallRunTiltRamp
	wallCam = math.clamp(wallCam + (wallRun and wstep or -wstep), 0, 1)
	local ew = wallCam * wallCam * (3 - 2 * wallCam)

	local crouched = wantedState() == "Crouch"     -- the key, or a ceiling too low to stand under
	local base = (crouched and not leap) and MOVE.CrouchCameraDip or 0
	Viewmodel.SetPosture(Vector3.new(0, base + (MOVE.SlideCameraDip - base) * e, 0))

	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local st = hum and hum:GetState()
	Viewmodel.SetMovement({
		Sprint = held.Sprint,
		Crouch = crouched or (held.Crouch and not slideArmed),
		Sliding = slide ~= nil,
		SlideTime = slide and (os.clock() - slide.Start) or 0,
		Speed = root and horizontalSpeed(root) or 0,
		-- airborne = the Humanoid's own jump and fall states (FloorMaterial lags a frame or two); a wall
		-- run counts as footing, so the arms keep their stride along the wall
		Grounded = wallRun ~= nil or not (st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping),
		VerticalSpeed = root and root.AssemblyLinearVelocity.Y or 0,
	})

	-- On a forward slide the reference always banks the same way: the view tips clockwise, top of
	-- the screen swinging right. A slide that is mostly to the LEFT banks into it instead.
	if slide then
		rollSign = (camera.CFrame.RightVector:Dot(slide.Dir) < -0.5) and 1 or -1
	end
	-- On a wall the top of the view tips away from it: a wall on the right (its normal pointing left)
	-- rolls positive, one on the left negative.
	if wallRun then
		wallSign = (camera.CFrame.RightVector:Dot(wallRun.Normal) < 0) and 1 or -1
	end
	roll = math.rad(MOVE.SlideTilt) * rollSign * e + math.rad(MOVE.WallRunTilt) * wallSign * ew
end)

-- Applied after the default camera script has written CFrame for the frame, so it composes with
-- Roblox's own first-person camera instead of replacing it.
RunService:BindToRenderStep("SpellshotSlideRoll", Enum.RenderPriority.Camera.Value + 1, function()
	if math.abs(roll) < 1e-4 then return end
	camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, roll)
end)
