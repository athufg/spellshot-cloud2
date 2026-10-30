--[[
	AquaClient  (ModuleScript)  ->  ReplicatedStorage/IceMagic/AquaClient

	Aqua's client half (build prompt Phase 2, 2026-09-24). AquaHandler is the server; AquaFX draws; this module is what
	a client DOES. Two scripts require it, and share the one copy a client has:

	  SpellshotInput  the keys: FireRiptide (the M1 branch of fireShard), LocalCast (the arms on the keypress, as
	                  SpellshotInput's own LOCAL_CAST), ReleasePayload (Sidearm's key coming up stops its rapid fire),
	                  SetReleaser (so a Sidearm out of mana lets go by itself through SpellshotInput's releaseHeld).
	  AbilityFX       Handlers: every Aqua* broadcast, drawn for every character (the caster's own arms and shots were
	                  already drawn on the keypress, so those skip the local body). AquaMawEnd / AquaTwinTideEnd (the
	                  server ended a cast early: a round reset, the caster gone) drop that cast's colliders and look at
	                  once (2026-10-19, audit P5D-09); the walls' colliders are built from the broadcast whatever is
	                  drawn (AquaFX, audit P5D-08).

	YOUR OWN BODY. Movement is client-owned, so everything that moves a player happens on that player's own client:
	  AquaPull   Undertow caught you: straight to the vortex's centre in PullTime, a little lift (Cyclone's mover).
	  AquaKnock  a Twin Tide crush or the shark's bite: thrown, then physics carries you.
	  SlipUntil  an enemy's wet ground (Riding the Current). LOW TRACTION, the owner's call (2026-09-24): "very hard to
	             walk... tough to redirect yourself but you still can". Your keys still steer, but the body only turns
	             toward where they point at Traction per second -- momentum carries you. On the ground only.
	A dash under way (DashMotor) is cancelled by a pull; the slip stands down for a dash or a slide.
	Nothing checks that a client obeys: like every body a client moves, the server cannot force it (flagged, as Cyclone).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local Viewmodel = require(iceFolder:WaitForChild("Viewmodel"))
local CastPose = require(iceFolder:WaitForChild("CastPose"))
local AquaFX = require(iceFolder:WaitForChild("AquaFX"))
local A = require(iceFolder:WaitForChild("AquaTuning"))
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local DashMotor = require(spellFolder:WaitForChild("DashMotor"))
local iceRemote = iceFolder:WaitForChild("IceAbilityRemote")

local AquaClient = {}
AquaClient.LocalCast = {}
AquaClient.Handlers = {}

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function serverNow()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

--- The frame this client's shots leave from: the eye, even in the third-person testing view (SpellshotInput.aimCF).
local function aimCF()
	local fn = VFXLibrary.LocalAimCFrame
	return (fn and fn()) or workspace.CurrentCamera.CFrame
end

--- Your own shots pass through yourself and through everyone you may not hurt (Config.MayHurt).
local function ownExclude(character)
	return Config.AddUnhurtable({ character, workspace.CurrentCamera }, player)
end

--- Another player's shot, as this client draws it, flies through whoever the shooter could not hurt (AbilityFX).
local function shotExclude(c)
	local shooter = Players:GetPlayerFromCharacter(c)
	return shooter and Config.AddUnhurtable({ c }, shooter) or { c }
end

--- (2026-10-19, audit P5F-06) Another player's cast that Reduce Enemy VFX leaves whole: not an ENEMY's (VFXLibrary.IsEnemy:
--- a teammate's in your match, an ally dummy's). AquaFX's `own` for thinning; false when VFXLibrary cannot say.
local function friendly(c)
	return typeof(c) == "Instance" and type(VFXLibrary.IsEnemy) == "function" and not VFXLibrary.IsEnemy(c)
end

--- A held viewmodel clip let go of `seconds` later, if it is still the one playing (a refused cast never lets go).
local function stopClipLater(name, seconds)
	task.delay(seconds, function()
		if Viewmodel.CurrentClip() == name then Viewmodel.Stop() end
	end)
end

local shotId = 0

----------------------------------------------------------------------------------------------------
-- M1: RIPTIDE
----------------------------------------------------------------------------------------------------
--- The click (SpellshotInput.fireShard, which gates it like every M1 and picks the arm): the palm thrust, and on its
--- full extension the wave, from your feet straight down the look (flat). Your own copy finds the bodies it passes
--- through and reports each one; the server checks every claim (AquaHandler).
function AquaClient.FireRiptide(character, side)
	Viewmodel.PlayShot(side, "IcicleShard", function()
		if player.Character ~= character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local dir = flat(workspace.CurrentCamera.CFrame.LookVector)
		if dir.Magnitude < 0.1 then dir = flat(root.CFrame.LookVector) end
		dir = dir.Unit
		shotId += 1
		local id = shotId
		local origin = root.Position
		iceRemote:FireServer("RiptideRelease", { Id = id, Origin = origin, Dir = dir })
		AquaFX.Riptide({
			Origin = origin, Dir = dir, Own = true, Exclude = ownExclude(character),
			OnHit = function(part, position)
				iceRemote:FireServer("RiptideHit", { Id = id, Part = part, Position = position })
			end,
			-- (2026-10-21) the wall it breaks on, claimed the same way: the server's world branch announces it on
			-- ShotImpact (a Training Ground TargetBoard scores it), as Wind Blade's world hit is announced
			OnWorld = function(part, position)
				iceRemote:FireServer("RiptideHit", { Id = id, Part = part, Position = position })
			end,
		})
	end)
end

----------------------------------------------------------------------------------------------------
-- the arms on the keypress (PLACEHOLDER clips: Aqua has none of its own yet -- each borrows the nearest one)
----------------------------------------------------------------------------------------------------
-- Undertow (the owner, 2026-09-25: "IT SHOULD BE INFRONT OF YOUR FACE, YOUR HANDS DOING THE CIRCULAR ARC"): your own
-- disc is drawn on the keypress, in front of your eye along your aim (the server's own frame, undertowFrame in
-- AquaHandler, is the same maths from your head), and your RIGHT HAND DRAWS IT: a live offset on the right arm
-- (Viewmodel.SetArmOffset) keeps the fist on the line from your eye to the water at the hand, so the hand traces the
-- circle and the water trails behind it. It lets go after the draw and eases home.
local function undertowFrameLocal(character)
	local U = A.Undertow
	local camera = workspace.CurrentCamera
	local head = character:FindFirstChild("Head")
	local acf = aimCF()
	local eye = acf.Position
	if head and (eye - head.Position).Magnitude > 3 then eye = head.Position end      -- the third-person testing view
	local look = camera.CFrame.LookVector
	local f = flat(look)
	if f.Magnitude < 0.05 then
		local root = character:FindFirstChild("HumanoidRootPart")
		f = flat(root and root.CFrame.LookVector or Vector3.new(0, 0, -1))
	end
	f = f.Unit
	local maxP = math.rad(U.MaxPitch)
	local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -maxP, maxP)
	look = f * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
	return eye + look * U.DiscDistance - Vector3.new(0, U.DiscDrop, 0), look
end

----------------------------------------------------------------------------------------------------
-- THE ARMS' OFFSET SLOTS: one owner inside AquaClient
----------------------------------------------------------------------------------------------------
-- Viewmodel.SetArmOffset keeps ONE function per arm, so the gun hold and Undertow's hand draw (both Aqua, castable
-- together: Undertow is the Primary, Sidearm a Technique) used to overwrite each other -- Undertow cast while the gun was
-- out took the right arm off the gun for good, and the gun's clean-up cut a running Undertow draw short. Each is a
-- LAYER here now; the slot's function sums them, and nobody clears anybody else's. The R slot is solved just before the L
-- slot in every Viewmodel.Update, so what R summed this frame (armDelta.R) is where the right arm really is when the left
-- is placed. After a rig rebuild (Viewmodel.Build clears the slots) the layers are put back -- the slots are only ever
-- set by us while a layer is live, so another Element's SetArmOffset (TerraFX) is never trampled.
local ARM_FIELDS = { "X", "Y", "Z", "Pitch", "Yaw", "Roll", "Wrist" }
local ARM_ORDER = { "gun", "undertow" }        -- summed in this order
local armLayers = { R = {}, L = {} }           -- side -> { [owner] = fn() -> partial delta or nil }
local armDelta = { R = nil, L = nil }          -- what each slot summed in the last Update
local armSlot = {}
for _, side in ipairs({ "R", "L" }) do
	armSlot[side] = function()
		local sum = nil
		for _, owner in ipairs(ARM_ORDER) do
			local fn = armLayers[side][owner]
			if fn then
				local ok, d = pcall(fn)
				if not ok then
					warn("[AquaClient] arm layer " .. owner .. "/" .. side .. " failed and was dropped: " .. tostring(d))
					armLayers[side][owner] = nil
				elseif type(d) == "table" then
					sum = sum or { X = 0, Y = 0, Z = 0, Pitch = 0, Yaw = 0, Roll = 0, Wrist = 0 }
					for _, f in ipairs(ARM_FIELDS) do sum[f] += tonumber(d[f]) or 0 end
				end
			end
		end
		armDelta[side] = sum
		return sum
	end
end
local function setArmLayer(side, owner, fn)
	armLayers[side][owner] = fn
	if next(armLayers[side]) then
		Viewmodel.SetArmOffset(side, armSlot[side])
	else
		armDelta[side] = nil
		Viewmodel.SetArmOffset(side, nil)
	end
end
-- a rebuilt rig starts with empty slots: put the live layers back
local armRig = nil
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	local rig = camera and camera:FindFirstChild("SpellshotViewmodel")
	if rig ~= armRig then
		armRig = rig
		if rig then
			for _, side in ipairs({ "R", "L" }) do
				if next(armLayers[side]) then Viewmodel.SetArmOffset(side, armSlot[side]) end
			end
		end
	end
end)

local undertowHand = 0                      -- which draw owns the "undertow" layer (a new cast takes it over)

AquaClient.LocalCast.Undertow = function(character)
	local center, look = undertowFrameLocal(character)
	local t0 = serverNow()
	local h = AquaFX.Undertow(center, look, t0)
	undertowHand += 1
	local mine = undertowHand
	local U = A.Undertow
	local started = os.clock()
	-- where the fist rests (camera space) and the VIEW, both on the first frame: the hand draws the disc as it was cast.
	-- Projected through each new frame's camera, a run at a disc 4.2 away blew the projection up within 0.1 s and a quick
	-- turn did the same -- the arm was flung off the screen, then snapped home.
	local base, camCF0 = nil, nil
	local lastD = Vector3.zero
	setArmLayer("R", "undertow", function()
		if undertowHand ~= mine then return nil end
		local e = os.clock() - started
		-- follow fully while drawing, then ease back home
		local k = math.clamp(e / 0.06, 0, 1) * (1 - math.clamp((e - U.ConjureTime - 0.12) / 0.25, 0, 1))
		if k <= 0 and e > U.ConjureTime then
			task.defer(function()
				if undertowHand == mine then setArmLayer("R", "undertow", nil) end
			end)
			return nil
		end
		local camera = workspace.CurrentCamera
		if not camera then return nil end
		if not base then                                                   -- no offset has been drawn yet: the rest pose
			local fist = Viewmodel.GetFistCFrame("R")
			if not fist then return nil end
			camCF0 = camera.CFrame
			base = camCF0:PointToObjectSpace(fist.Position)
		end
		-- the fist circles half as wide as the water it draws, on the same beat (all the way dragged the whole forearm
		-- across the screen, in front of the disc; turning the forearm to point at it swung it about the elbow, off the
		-- screen), with a small tilt the way it is moving. Held where it last was if the head can't be projected, and
		-- never more than 0.6 stud from rest.
		local v = camCF0:PointToObjectSpace(h.Head())
		if v.Z < -0.5 and base.Z < -0.2 then
			local target = v * (base.Z / math.min(v.Z, -2))
			local d = Vector3.new(target.X - base.X, target.Y - base.Y, 0) * 0.55
			if d.Magnitude > 0.6 then d = d.Unit * 0.6 end
			lastD = d
		end
		local d = lastD * k
		return { X = d.X, Y = d.Y, Pitch = math.clamp(d.Y * 22, -15, 15), Yaw = math.clamp(-d.X * 22, -15, 15) }
	end)
end
-- Twin Tide: Bulwark Wall's raise.
AquaClient.LocalCast.TwinTide = function()
	Viewmodel.Play("BulwarkWall")
	stopClipLater("BulwarkWall", 0.8)
end
-- Leviathan's Maw: Flash Freeze's slam.
AquaClient.LocalCast.LeviathansMaw = function()
	Viewmodel.Play("FlashFreeze")
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: SIDEARM -- draw, shoot, rapid fire while held, put away (the owner, 2026-09-25)
----------------------------------------------------------------------------------------------------
-- "It should look like you hold out a gun and then shoot" and "if u keep holding it rapid fires bullets but takes mana
-- in return". The press DRAWS the gun (AquaFX.SidearmGun) and the first shot leaves DrawTime later, whether the key is
-- still down or not: a tap is that one drawn shot. Still down, the gun fires FireRate bullets a second -- slow, as every
-- one knocks its target back -- each paying BulletCost (the server takes it: SidearmShot), until the key comes up or the bar cannot pay -- then the hold
-- lets go by itself, so the cooldown starts. After the last shot the gun is held out Linger longer, then put away.
-- Every shot goes to the server the moment it leaves (SidearmShot: the server checks the draw, the rate and the mana);
-- the release only ends the hold.
local sidearm = nil          -- this client's gun: { Role, Start, Character, Gun, Held, Shots, NextShot, LastShot }
local releaser = nil         -- SpellshotInput's releaseHeld(role)

function AquaClient.SetReleaser(fn)
	releaser = fn
end

--- The gun in first person, GRIPPED: AK_SA_Gun's origin is its hand-hold point, so it goes on the right fist, the barrel
--- pointed at the crosshair's far point (the owner, 2026-09-25: "the gun holding looks weird" -- it sat at the cast
--- point past the fist, turned 24 degrees in, hanging in front of the hand instead of in it). In the third-person
--- view the body's hand holds it, along the look. The bullets still fly from the eye down the crosshair.
local function ownGunFrame()
	local camera = workspace.CurrentCamera
	local fist = Viewmodel.GetFistCFrame("R")
	if not fist then
		local m = Viewmodel.GetMuzzleCFrame("R")
		return CFrame.lookAt(m.Position, m.Position + camera.CFrame.LookVector)
	end
	local aim = camera.CFrame.Position + camera.CFrame.LookVector * 60
	-- the grip sits a touch into the fist and under the barrel's line
	local at = fist.Position + camera.CFrame.UpVector * 0.03
	return CFrame.lookAt(at, aim, camera.CFrame.UpVector)
end

----------------------------------------------------------------------------------------------------
-- THE GUN HOLD (first person): the gun pinned to the camera, BOTH hands pinned to the gun
----------------------------------------------------------------------------------------------------
-- (2026-09-25, the owner: "if you are running and hold the gun, the hand animation is like very bugged".) The old hold
-- was two OFFSETS on whatever the rig was doing. Running is always the rig's Sprint state (MovementController auto-
-- sprints), so the right arm kept the RIVALS sprint pose and its stride under a fixed nudge -- the gun dived off the bottom
-- of the frame every stride -- and the left hand chased LAST frame's right fist (GetFistCFrame inside an offset fn is the
-- previous Update's) through THIS frame's camera, from a base frozen on the first frame, the stride still under it.
-- Now both arms sit on a HELD arm shot (Scorching Lash's mechanism: a held shot is its last key exactly, and the stride,
-- the fall lift and the look-sway are faded off that arm -- Viewmodel.Update), so the pose under each offset is KNOWN and
-- the offsets are solved in closed form, camera space, from one motion shared by the gun and both hands:
--   right fist = motion * the rest grip
--   gun        = ownGunFrame's maths on that fist * the gun body's own draw / kick / holster (gun.BodyOffset)
--   left fist  = gun * a CFrame IN THE GUN'S FRAME (GUN_HAND_REST, or what AquaClient.GunHand returns)
-- so nothing can come apart in any movement state. Wants AquaFX.SidearmGun placed after the arms (Camera + 3) and its
-- BodyOffset; without them the hands still hold together, the gun just trails a frame and the left hand skips the kick.
local VC = Viewmodel.Config
local ARM_LEN = VC.ArmLength                      -- elbow to fist (1.2)
local HOLD_CLIP = "AquaGunHold"
local STRIDE_RATE = 2 * math.pi / 0.534           -- the rig's measured stride (Viewmodel STRIDE.Period), rad/s
local HOLD_MOTION = {
	BobX = 0.022,      -- studs at a full run: side to side, once a stride
	BobY = 0.026,      -- ...down on each footfall
	RunDrop = 0.03,    -- ...and the whole hold this much lower
	LandDip = 0.07,    -- studs, a landing at 60 st/s (less for a softer one)...
	LandTime = 0.28,   -- ...down and back over this long
}

local function armPose(x, y, z, pitch, yaw, roll)
	return { X = x, Y = y, Z = z, Pitch = pitch, Yaw = yaw, Roll = roll, Wrist = 0 }
end
-- THE REST HOLD = the old hold's own idle frame, so a still frame looks exactly as it did: HOLD_R is Viewmodel's
-- POSE.Idle.R plus the old right offset (X 0.12, Y -0.04, Z 0.2, Pitch -16); HOLD_L is POSE.Idle.L plus the old left
-- offset as it solved at rest (the fist 0.30 left of the grip, 0.11 up, 0.14 toward the muzzle).
local HOLD_R = armPose(1.175, -1.347, -0.434, 52.2, 27.7, -11.8)
local HOLD_L = armPose(-0.241, -1.291, -0.690, 60.2, -27.7, 11.8)

--- An arm pose's fist, camera space: Viewmodel's solveArm with no sway and Wrist 0, carried ArmLength along the forearm
--- (GetFistCFrame). Its LookVector is the forearm, elbow to fist.
local function fistOf(p)
	return CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(math.rad(p.Pitch), math.rad(p.Yaw), math.rad(p.Roll))
		* CFrame.new(0, 0, -ARM_LEN)
end

--- The inverse: the arm pose that puts its fist on `fist` (camera space). ToEulerAnglesXYZ is CFrame.Angles' own
--- inverse. Keep a forearm's yaw inside +-80 degrees (one coming up from below the frame always is), or the angles
--- take the other branch.
local function poseFor(fist)
	local root = fist * CFrame.new(0, 0, ARM_LEN)
	local rx, ry, rz = root:ToEulerAnglesXYZ()
	return armPose(root.X, root.Y, root.Z, math.deg(rx), math.deg(ry), math.deg(rz))
end

local function wrapDeg(a)
	return (a + 180) % 360 - 180
end

--- The SetArmOffset delta that takes an arm posed at `base` to `want`, `w` of the way.
local function deltaTo(want, base, w)
	return {
		X = (want.X - base.X) * w, Y = (want.Y - base.Y) * w, Z = (want.Z - base.Z) * w,
		Pitch = wrapDeg(want.Pitch - base.Pitch) * w, Yaw = wrapDeg(want.Yaw - base.Yaw) * w,
		Roll = wrapDeg(want.Roll - base.Roll) * w, Wrist = (want.Wrist - base.Wrist) * w,
	}
end

--- The gun's held frame from the right fist, camera space: ownGunFrame's own maths (the grip 0.03 above the fist, the
--- barrel at the crosshair's point 60 studs out, camera up).
local function gunBaseCam(fistR)
	return CFrame.lookAt(fistR.Position + Vector3.new(0, 0.03, 0), Vector3.new(0, 0, -60), Vector3.yAxis)
end

local REST_FIST_R = fistOf(HOLD_R)
--- THE LEFT HAND'S REST ON THE GUN, in the gun body's frame (origin = the grip, -Z the barrel, +Y up). The old hold's
--- own spot, (-0.299, 0.107, -0.137), is beside the barrel ~0.46 from the reservoir -- a palm there cannot charge it --
--- so the rest is the PALM ON THE RESERVOIR's left flank (its centre ~(0, 0.20, 0.20) at the first-person size, radius
--- ~0.18), the forearm kept at the old hold's angle.
local GUN_HAND_REST = CFrame.new(-0.25, 0.17, 0.12) * (gunBaseCam(REST_FIST_R):Inverse() * fistOf(HOLD_L)).Rotation
AquaClient.GunHandRest = GUN_HAND_REST
--- THE PLUG-IN for whatever the left hand does ON the gun (the owner, 2026-09-25: the hand charging the gun with aqua
--- power, matched to each shot -- designed separately). `fn(s, now)` gets the hold (s.Start, s.Shots, s.LastShot,
--- s.NextShot, s.Held, s.PutAway) and returns a CFrame in the gun's frame -- e.g. GUN_HAND_REST * CFrame.new(0, 0.06,
--- 0.10) * CFrame.Angles(math.rad(-10), 0, 0) -- or nil for the rest. Whatever it returns rides the gun, kick included.
--- It runs inside the render step: it must not yield. (A charge glow on the palm reads Viewmodel.GetFistCFrame("L") from
--- the gun's step or a Heartbeat, where it is this frame's.)
AquaClient.GunHand = nil

local function gunHandCF(s, now)
	local fn = AquaClient.GunHand
	if fn then
		local ok, cf = pcall(fn, s, now)
		if ok and typeof(cf) == "CFrame" then return cf end
	end
	return GUN_HAND_REST
end

-- Both arms HELD on the gun: a held arm shot sits on its last key (Trigger is never reached, so it is never a pending
-- shot and never flashes the palm). One clip, played on each side: its Pose carries both arms.
Viewmodel.ArmClips[HOLD_CLIP] = Viewmodel.ArmClips[HOLD_CLIP] or {
	Trigger = math.huge, Hold = true,
	Keys = {
		{ t = 0.00, From = true },
		{ t = A.Sidearm.DrawTime, Pose = { R = HOLD_R, L = HOLD_L },
			Easing = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
	},
}

--- THE LEFT HAND CHARGING THE GUN (the owner, 2026-09-25: "match it for when he shoots and the hand then like charges the
--- gun with aqua power ... dont make it those goofy bullets"). A delta on top of the rest (the palm on the reservoir),
--- by the gun's charge phase (gun.Phase(): 0 = a shot just left, 1 = charged). The shot knocks the hand OFF the
--- reservoir (back down the forearm); it winds back, twisting against the swirl gathering round it (AquaFX draws the
--- swirl), then DRIVES the palm onto the reservoir (ease-in: it hits), a hair into the water; it presses, straining,
--- while the gun fills; the READY pulse thumps it back and it settles, braced. Every channel is 0 at phase 0 and 1, so
--- held fire loops with no seam. Studs camera space, degrees; the fist turns about the ELBOW 1.2 back (a degree of Pitch
--- moves it ~0.021), Wrist is x0.35 of that, Roll twists the forearm about itself.
local function smooth01(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
-- piecewise between keys { phase, value, ease }: "in" accelerates into the key (a hit), "out" decelerates, nil = smooth
local function keyed(ph, keys)
	if ph <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if ph <= b[1] then
			local u = (ph - a[1]) / (b[1] - a[1])
			if b[3] == "in" then
				u = u * u
			elseif b[3] == "out" then
				u = 1 - (1 - u) * (1 - u)
			else
				u = u * u * (3 - 2 * u)
			end
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return keys[#keys][2]
end
local OUT_L = Vector3.new(-0.465, -0.822, 0.329)   -- off the reservoir: back down the left forearm
local ARM_OFF = { { 0, 0 }, { 0.13, 0.11, "out" }, { 0.30, 0.14 }, { 0.40, -0.025, "in" }, { 0.50, -0.012 },
	{ 0.83, -0.02 }, { 0.87, 0.025, "out" }, { 1, 0 } }
local ARM_WRIST = { { 0, 0 }, { 0.13, 10, "out" }, { 0.30, 16 }, { 0.40, -5, "in" }, { 0.50, -3 }, { 0.83, -3 },
	{ 0.87, 3, "out" }, { 1, 0 } }
local ARM_ROLL = { { 0, 0 }, { 0.13, 0 }, { 0.30, -14 }, { 0.40, 6, "in" }, { 0.55, 0 } }   -- the swirl's sense
local function chargeArm(ph, now)
	-- strain while the gun fills (pressed): a fine tremble along the push, under 15 Hz so a 30 fps phone won't alias it
	local strain = 0.0045 * smooth01((ph - 0.42) / 0.2) * (1 - smooth01((ph - 0.80) / 0.05))
	local tremble = (math.sin(now * 70) * 0.6 + math.sin(now * 47 + 1.3) * 0.4) * strain
	local d = OUT_L * (keyed(ph, ARM_OFF) + tremble)
	return { X = d.X, Y = d.Y, Z = d.Z, Wrist = keyed(ph, ARM_WRIST), Roll = keyed(ph, ARM_ROLL) }
end

local gunArms = 0
local function holdArms(s)
	gunArms += 1
	local mine = gunArms
	local S = A.Sidearm
	local gun = s.Gun          -- kept: dropSidearm clears s.Gun on the put-away, and the holster still has to be followed
	local h = { B = Vector3.zero, Phase = 0, Amt = 0, Air = 0, FallV = 0, LandAt = -1, LandAmp = 0,
		SwayX = 0, SwayY = 0, LastCam = nil, Own = { R = 0, L = 0 }, Lost = {} }

	local function weight(now)
		-- on the shot clock, like the held clip and the gun's own draw and holster (ShotTimeScale films them slowed)
		local ts = VFXLibrary.ShotTimeScale()
		local k = math.clamp((now - s.Start) / math.max(S.DrawTime / ts, 0.05), 0, 1)
		if s.PutAway then k *= 1 - math.clamp((now - s.PutAway) / ((S.HolsterTime + 0.1) / ts), 0, 1) end
		return k * k * (3 - 2 * k)
	end
	local function rightFist()
		return CFrame.new(h.B) * REST_FIST_R
	end
	--- The right fist as it is really drawn this Update: the held pose plus everything the R slot summed (the gun's
	--- layer, and anything riding it -- Undertow's hand draw), so the left hand stays on the gun whatever moves the right.
	local function drawnRightFist()
		local dR = armDelta.R
		if not dR then return rightFist() end
		local p = {}
		for _, f in ipairs(ARM_FIELDS) do p[f] = (HOLD_R[f] or 0) + (dR[f] or 0) end
		return fistOf(p)
	end
	local function leftFist(now)
		local body = gunBaseCam(drawnRightFist())
		if gun and gun.BodyOffset then body = body * gun.BodyOffset(now) end     -- the draw, the kick, the holster
		return body * gunHandCF(s, now)
	end

	-- take both arms -- not one an M1 is still winding up on (PlayShot would fire it early); the manager takes that later
	for _, side in ipairs({ "R", "L" }) do
		if not Viewmodel.ShotPending(side) then Viewmodel.PlayShot(side, HOLD_CLIP) end
		h.Own[side] = Viewmodel.ShotPlaying(side, HOLD_CLIP) and 1 or 0
	end

	setArmLayer("R", "gun", function()
		if gunArms ~= mine then return nil end
		local w = weight(os.clock()) * h.Own.R
		if w <= 0.001 then return nil end
		return deltaTo(poseFor(rightFist()), HOLD_R, w)
	end)
	setArmLayer("L", "gun", function()
		if gunArms ~= mine then return nil end
		local now = os.clock()
		-- the right arm taken (an M1 thrust carries the gun off with it): the left lets go of the gun too
		local w = weight(now) * h.Own.L * h.Own.R
		if w <= 0.001 then return nil end
		local d = deltaTo(poseFor(leftFist(now)), HOLD_L, w)
		-- CHARGING it after every shot, on top of the palm-on-the-reservoir rest (it already rides the gun's kick)
		local c = chargeArm(gun and gun.Phase and gun.Phase() or 1, now)
		d.X += c.X * w
		d.Y += c.Y * w
		d.Z += c.Z * w
		d.Roll += c.Roll * w
		d.Wrist += c.Wrist * w
		return d
	end)

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if gunArms ~= mine then                              -- a newer draw owns the arms (its shots replaced these)
			conn:Disconnect()
			return
		end
		local now = os.clock()
		if s.PutAway and weight(now) <= 0 then               -- put away: the arms ease back to the rig
			conn:Disconnect()
			setArmLayer("R", "gun", nil)                      -- only the gun's own layers (a running Undertow draw keeps its own)
			setArmLayer("L", "gun", nil)
			Viewmodel.StopShot("R", HOLD_CLIP)
			Viewmodel.StopShot("L", HOLD_CLIP)
			return
		end

		-- WHO HAS THE ARMS. A two-arm cast clip (Viewmodel.Play) or an M1 thrust (PlayShot) takes an arm: the hold lets it
		-- go (the gun rides the right fist wherever that goes) and takes it back 0.2 s after it is free.
		local busy = Viewmodel.IsPlaying()
		local alive = player.Character == s.Character and s.Character.Parent ~= nil
		for _, side in ipairs({ "R", "L" }) do
			local held = Viewmodel.ShotPlaying(side, HOLD_CLIP)
			if held and busy then
				Viewmodel.StopShot(side, HOLD_CLIP)
				held = false
			end
			if held then
				h.Lost[side] = nil
			else
				h.Lost[side] = h.Lost[side] or now
				if alive and not busy and not s.PutAway and not Viewmodel.ShotPending(side) and now - h.Lost[side] > 0.2 then
					Viewmodel.PlayShot(side, HOLD_CLIP)          -- eases back in from wherever the arm is
					h.Lost[side] = nil
				end
			end
			h.Own[side] += ((held and 1 or 0) - h.Own[side]) * math.clamp(20 * dt, 0, 1)
		end

		-- THE HOLD'S OWN MOTION: the held shots fade the rig's stride and look-sway off both arms, so the hold carries its
		-- own -- one camera-space Vector3 for the gun and both hands at once (a frame behind the camera, like anything eased;
		-- shared, so it can never pull them apart).
		local camera = workspace.CurrentCamera
		local camCF = camera and camera.CFrame
		if camCF and h.LastCam and dt > 1e-4 then
			-- look-sway: the rig's own constants (Viewmodel.Update's sway), per second instead of per frame
			local rx, ry = h.LastCam:ToObjectSpace(camCF):ToEulerAnglesYXZ()
			local r = 1 - (1 - VC.SwayResponse) ^ (dt * 60)
			h.SwayX = math.clamp(h.SwayX + (-ry / dt * VC.SwayAmount - h.SwayX) * r, -VC.SwayMax, VC.SwayMax)
			h.SwayY = math.clamp(h.SwayY + (-rx / dt * VC.SwayAmount - h.SwayY) * r, -VC.SwayMax, VC.SwayMax)
		end
		h.LastCam = camCF
		local char = s.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local v = root and root.AssemblyLinearVelocity or Vector3.zero
		local st = hum and hum:GetState()
		local air = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
		local sliding = char ~= nil and char:GetAttribute("MoveState") == "Slide"
		-- the stride: on your feet, moving, not sliding (root velocity: MoveDirection reads 0 in a render step)
		local goal = (not air and not sliding) and math.clamp((Vector3.new(v.X, 0, v.Z).Magnitude - 2) / 20, 0, 1) or 0
		h.Amt += (goal - h.Amt) * math.clamp((air and 14 or 8) * dt, 0, 1)
		h.Phase = (h.Phase + dt * STRIDE_RATE) % (2 * math.pi)
		-- falling: the rig's touch of lift; landing hard: a dip as deep as the fall was fast
		local fall = air and math.clamp((-v.Y - 4) / 40, 0, 1) or 0
		h.Air += (fall - h.Air) * math.clamp(10 * dt, 0, 1)
		if air then
			h.FallV = math.min(h.FallV, v.Y)
		else
			if h.FallV < -20 then
				h.LandAt, h.LandAmp = now, HOLD_MOTION.LandDip * math.clamp(-h.FallV / 60, 0, 1)
			end
			h.FallV = 0
		end
		local lt = now - h.LandAt
		local land = (lt >= 0 and lt < HOLD_MOTION.LandTime) and h.LandAmp * math.sin(math.pi * lt / HOLD_MOTION.LandTime) or 0
		local a = h.Amt
		h.B = Vector3.new(
			h.SwayX + HOLD_MOTION.BobX * math.sin(h.Phase) * a,
			h.SwayY - (HOLD_MOTION.BobY * (0.5 - 0.5 * math.cos(2 * h.Phase)) + HOLD_MOTION.RunDrop) * a
				+ VC.FallLift * h.Air - land,
			0)
	end)
end

--- Put this client's gun away (it drops into water) and stop shooting: the server's word, a death, a new body.
local function dropSidearm()
	local s = sidearm
	if not s then return end
	sidearm = nil
	s.Dropped = true
	s.PutAway = os.clock()
	if s.Gun then
		s.Gun.Holster()
		s.Gun = nil
	end
end

local function canPay(character)
	return character:GetAttribute("DevFreeMana") == true or (character:GetAttribute("Mana") or 0) >= A.Sidearm.BulletCost
end

--- When the other hand's charge must be full: the next shot while the key is held, otherwise just before the gun is put
--- away (the Linger after a tap).
local function chargeDue(s)
	if s.Held then return s.NextShot end
	return s.LastShot + A.Sidearm.Linger / VFXLibrary.ShotTimeScale() - 0.04
end

--- One shot, now: the kick, the bullet from the eye down the crosshair (drawn from the muzzle), and the claim.
local function fireSidearm(s)
	local S = A.Sidearm
	s.Shots += 1
	local n = s.Shots
	local muzzle = s.Gun and s.Gun.Muzzle() or nil
	if s.Gun then s.Gun.Kick() end
	local acf = aimCF()
	local eye, dir = acf.Position, workspace.CurrentCamera.CFrame.LookVector
	shotId += 1
	local sid = shotId
	iceRemote:FireServer("SidearmShot", { Id = sid, Origin = eye, Dir = dir, N = n })
	AquaFX.FireSlug(eye, dir, n, ownExclude(s.Character), muzzle, function(hit)
		iceRemote:FireServer("SidearmHit", { Id = sid, Part = hit.Instance, Position = hit.Position })
	end)
	s.LastShot = os.clock()
	s.NextShot = s.LastShot + (1 / S.FireRate) / VFXLibrary.ShotTimeScale()
	if s.Gun then s.Gun.ChargeUntil(chargeDue(s)) end
end

-- the press (tryCast's generic HELD path has already checked the cooldown and the mana, and sends the press). No arm
-- clip: the right arm's idle pose already holds the gun where the eye expects it (an arm hold borrowed at
-- first swung the arm out of view and left the gun hanging at the lens)
AquaClient.LocalCast.Sidearm = function(character, role)
	dropSidearm()
	local head = character:FindFirstChild("Head")
	local firstPerson = head and (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 2.5
	local now = os.clock()
	sidearm = { Role = role, Start = now, Character = character, Held = true, Shots = 0, LastShot = 0,
		NextShot = now + A.Sidearm.DrawTime / VFXLibrary.ShotTimeScale(),
		-- first person: gripped, and bigger (the owner: "the gun needs to be bigger"; 0.34 read as a toy)
		Gun = AquaFX.SidearmGun(ownGunFrame, firstPerson and 0.46 or 1) }
	if firstPerson then
		sidearm.Gun.SetPalm(function() return Viewmodel.GetFistCFrame("L") end)
		holdArms(sidearm)
	end
end

--- The key came up (SpellshotInput.releaseHeld, for whatever ability it was holding): for Sidearm the rapid fire stops.
--- The drawn shot still leaves if it has not yet (a tap). Nothing rides on the release: every shot went on its own.
function AquaClient.ReleasePayload(id, _role)
	if id ~= "Sidearm" then return nil end
	local s = sidearm
	if s then s.Held = false end
	return nil
end

RunService.Heartbeat:Connect(function()
	local s = sidearm
	if not s then return end
	if player.Character ~= s.Character or not s.Character.Parent then
		dropSidearm()
		return
	end
	local S = A.Sidearm
	local now = os.clock()
	-- the other hand charges the gun for the next shot (first person): due at the next shot, or at the put-away once the
	-- key is up
	if s.Gun and s.Shots > 0 then s.Gun.ChargeUntil(chargeDue(s)) end
	if now >= s.NextShot then
		if s.Shots == 0 then
			fireSidearm(s)                                      -- the drawn shot (paid by the press)
		elseif s.Held then
			if canPay(s.Character) then
				fireSidearm(s)
			else
				-- out of mana: the hold lets go by itself (its cooldown starts)
				s.Held = false
				if releaser then releaser(s.Role) end
			end
		end
	end
	if s.Held and now - s.Start >= S.HoldMax / VFXLibrary.ShotTimeScale() then
		s.Held = false
		if releaser then releaser(s.Role) end
	end
	-- let go and done shooting: held out a moment longer, then put away
	if not s.Held and s.Shots > 0 and now - s.LastShot >= S.Linger / VFXLibrary.ShotTimeScale() then
		dropSidearm()
	end
end)

----------------------------------------------------------------------------------------------------
-- YOUR OWN BODY: pulled, thrown, slipping
----------------------------------------------------------------------------------------------------
-- 2026-10-08: whatever of Zephyr's moves this body lets go through IceMagic.ZephyrClient.Interrupt (Skyrider's ride ends,
-- as a dismount), found lazily and guarded, as AbilityFX's Cyclone pull and Aftershock knock ask it. Spellshot.GustJumpMotor
-- was asked here until now; it left with Gust Jump on 2026-10-06, so a pull or a knock was fought by the ride's own mover.
local zephyrClient = nil
local function interruptMotion(reason)
	if DashMotor.IsActive() then DashMotor.Cancel(reason) end
	-- ...the PULL alone (2026-10-08, review): Undertow is the one Aqua ability that ends what a body holds (AquaHandler's
	-- interrupt), and a Skyrider ride is held. A KNOCK -- every Sidearm bullet that lands, a crush, a bite -- cancels a
	-- dash, as it always has, and is a hit to a rider like any other (the wobble): asked here too, one bullet was a
	-- dismount and the ride's 12 s cooldown.
	if reason ~= "AquaPull" then return end
	if zephyrClient == nil then
		local module = iceFolder:FindFirstChild("ZephyrClient")
		local ok, mod = pcall(function() return module and require(module) end)
		zephyrClient = (ok and type(mod) == "table" and mod) or false
	end
	if zephyrClient and type(zephyrClient.Interrupt) == "function" then pcall(zephyrClient.Interrupt, reason) end
end

local function newMover(root, name, forcePerMass)
	local attachment = Instance.new("Attachment")
	attachment.Name = name .. "Attachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = name
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * forcePerMass
	mover.MaxAxesForce = Vector3.new(force, force, force)
	mover.VectorVelocity = root.AssemblyLinearVelocity
	mover.Parent = attachment
	attachment.Parent = root
	return attachment, mover
end

local moved = nil            -- a pull or a throw running on this body: { Kind, Until, Center, Velocity, Root, Attachment, Mover }

local function dropMoved()
	local m = moved
	if not m then return end
	moved = nil
	m.Attachment:Destroy()
end

local function startMoved(kind, fields, forcePerMass)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0) then return end
	dropMoved()
	interruptMotion(kind)
	local attachment, mover = newMover(root, kind, forcePerMass)
	fields.Kind, fields.Root, fields.Character, fields.Attachment, fields.Mover = kind, root, character, attachment, mover
	moved = fields
end

AquaClient.Handlers.AquaPull = function(d)
	if typeof(d.Center) ~= "Vector3" or type(d.Until) ~= "number" then return end
	startMoved("AquaPull", { Center = d.Center, Until = d.Until }, A.Undertow.PullForcePerMass)
end

AquaClient.Handlers.AquaKnock = function(d)
	if typeof(d.Velocity) ~= "Vector3" or type(d.Until) ~= "number" or d.Velocity.Magnitude > 500 then return end
	startMoved("AquaKnock", { Velocity = d.Velocity, Until = d.Until }, A.Sidearm.KnockForcePerMass)
end

AquaClient.Handlers.AquaInterrupted = function()
	-- the server ended every hold this body had; a Sidearm in hand goes with it (no shot)
	dropSidearm()
end

-- the slip's mover: flat (Plane), so jumping and falling are untouched
local slipMover = nil        -- { Attachment, Mover, Root }

local function dropSlip()
	if slipMover then
		slipMover.Attachment:Destroy()
		slipMover = nil
	end
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = serverNow()

	-- a pull or a throw
	local m = moved
	if m then
		if m.Character ~= character or not m.Root.Parent or not humanoid or humanoid.Health <= 0 or now > m.Until then
			dropMoved()
		elseif m.Kind == "AquaPull" then
			local U = A.Undertow
			local left = math.max(0.06, m.Until - now)
			local to = flat(m.Center - m.Root.Position)
			local v = to.Magnitude > 1 and to / left or Vector3.zero
			if v.Magnitude > U.PullMaxSpeed then v = v.Unit * U.PullMaxSpeed end
			m.Mover.VectorVelocity = v + Vector3.new(0, U.PullLift, 0)
		else
			m.Mover.VectorVelocity = m.Velocity
		end
	end

	-- the slip: on the ground, while SlipUntil lasts, and nothing else is moving the body
	local slipping = root and humanoid and humanoid.Health > 0 and not moved
		and now < (character:GetAttribute("SlipUntil") or 0)
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and not DashMotor.IsActive()
		and character:GetAttribute("MoveState") ~= "Slide"
	if not slipping then
		dropSlip()
		return
	end
	if not slipMover or slipMover.Root ~= root then
		dropSlip()
		local attachment = Instance.new("Attachment")
		attachment.Name = "AquaSlipAttachment"
		local mover = Instance.new("LinearVelocity")
		mover.Name = "AquaSlip"
		mover.Attachment0 = attachment
		mover.RelativeTo = Enum.ActuatorRelativeTo.World
		mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		mover.PrimaryTangentAxis = Vector3.xAxis
		mover.SecondaryTangentAxis = Vector3.zAxis
		mover.ForceLimitsEnabled = true
		mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		local force = root.AssemblyMass * A.Current.SlipForcePerMass
		mover.MaxPlanarAxesForce = Vector2.new(force, force)
		local v0 = root.AssemblyLinearVelocity
		mover.PlaneVelocity = Vector2.new(v0.X, v0.Z)
		mover.Parent = attachment
		attachment.Parent = root
		slipMover = { Attachment = attachment, Mover = mover, Root = root }
	end
	-- where the keys point, at the pace you would walk; the body turns toward it only at Traction per second, from
	-- the velocity it really has (a wall it ran into has already stopped it)
	local want = flat(humanoid.MoveDirection) * humanoid.WalkSpeed
	local have = flat(root.AssemblyLinearVelocity)
	local k = 1 - math.exp(-A.Current.Traction * dt)
	local v = have + (want - have) * k
	slipMover.Mover.PlaneVelocity = Vector2.new(v.X, v.Z)
end)

----------------------------------------------------------------------------------------------------
-- RIDING THE CURRENT: foam at the feet of anyone moving on wet ground -- the owner riding their own current, and (the
-- owner's "water splashes everywhere", 2026-09-25) an enemy slipping on it
----------------------------------------------------------------------------------------------------
local nextSplash = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextSplash then return end
	nextSplash = now + 0.16
	local sNow = serverNow()
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local wet = c and (c:GetAttribute("AquaRiding") == true or sNow < (c:GetAttribute("SlipUntil") or 0))
		if root and wet and flat(root.AssemblyLinearVelocity).Magnitude > 6 then
			AquaFX.RidingSplash(c)
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- the broadcasts (AbilityFX hands every Aqua* kind here)
----------------------------------------------------------------------------------------------------
local H = AquaClient.Handlers

-- Riptide: the body's palm thrust for everyone; the wave for everyone but its shooter (theirs left on the click)
H.AquaRiptide = function(d)
	local c = d.Character
	if not c then return end
	CastPose.Play(c, "IcicleShard" .. ((d.Side == "L") and "L" or "R"))
	if c == player.Character then return end
	if typeof(d.Origin) ~= "Vector3" or typeof(d.Dir) ~= "Vector3" then return end
	AquaFX.Riptide({ Origin = d.Origin, Dir = d.Dir, T0 = d.T0, Exclude = shotExclude(c),
		Friendly = friendly(c) })                            -- (2026-10-19, audit P5F-06) a teammate's: not thinned
end

-- Undertow: the body's arms circling as the disc is drawn in front of it; the caster's own disc was drawn on the keypress
H.AquaUndertow = function(d)
	local c = d.Character
	if typeof(d.Center) ~= "Vector3" then return end
	if c then CastPose.Play(c, "CycloneForm") end
	if c == player.Character then return end
	-- (2026-10-19, audit P5D-02) not ours; (P5F-06) a teammate's counts as ours for Reduce Enemy VFX
	AquaFX.Undertow(d.Center, typeof(d.Look) == "Vector3" and d.Look or nil, d.T0, friendly(c))
end

H.AquaUndertowSnap = function(d)
	local c = d.Character
	if not c then return end
	CastPose.Play(c, "CycloneRelease")
	if c == player.Character then Viewmodel.Punch(0.1) end         -- the yank, felt
end

-- (2026-10-19, audit P5D-09) each caster's live Twin Tide, so the server's AquaTwinTideEnd can drop it
local tides = setmetatable({}, { __mode = "k" })     -- [character] = { Handle, T0 }

--- The server's end for a cast (AquaMawEnd / AquaTwinTideEnd { Character, T0 }): the entry for that character, if its
--- T0 is the ended cast's (an older cast's end never drops a newer one).
local function endedEntry(list, d)
	local c = d.Character
	local entry = c and list[c]
	if not entry then return nil end
	if type(d.T0) == "number" and type(entry.T0) == "number" and math.abs(d.T0 - entry.T0) > 1e-3 then return nil end
	list[c] = nil
	return entry
end

H.AquaTwinTide = function(d)
	local c = d.Character
	if typeof(d.Center) ~= "Vector3" or typeof(d.Axis) ~= "Vector3" then return end
	if c then
		CastPose.Play(c, "BulwarkWallRaise")
		task.delay(0.8, function()
			if CastPose.CurrentClip(c) == "BulwarkWallRaise" then CastPose.Stop(c) end
		end)
	end
	-- (2026-10-19, audit P5D-02) own / not; (P5F-06) a teammate's is not thinned either
	local handle = AquaFX.TwinTide(d.Center, d.Axis, d.T0, c and (c == player.Character or friendly(c)))
	if c and type(handle) == "table" then
		local entry = { Handle = handle, T0 = d.T0 }
		tides[c] = entry
		local W = A.TwinTide
		task.delay(W.CloseTime + W.HoldTime + W.SinkTime + 4, function()   -- past the look's flipbook: nothing left to end
			if tides[c] == entry then tides[c] = nil end
		end)
	end
end

-- (2026-10-19, audit P5D-09) the server ended a Twin Tide whose walls were still up (a round reset, the caster left):
-- its colliders and its look go at once, so nobody is blocked by a cast the server no longer runs
H.AquaTwinTideEnd = function(d)
	local entry = endedEntry(tides, d)
	if entry and type(entry.Handle.Cancel) == "function" then entry.Handle.Cancel() end
end

-- Sidearm: another player's gun -- drawn when they press, kicked by each of their shots, put away Linger after their
-- last one once their key is up
local guns = setmetatable({}, { __mode = "k" })      -- [character] = { Gun, Off, LastShot, Shots }

local function putAwayGun(c)
	local g = guns[c]
	guns[c] = nil
	if g then g.Gun.Holster() end
	if CastPose.CurrentClip(c) == "SidearmDraw" then CastPose.Stop(c) end
end

H.AquaSidearmHold = function(d)
	local c = d.Character
	if not c then return end
	if c == player.Character then
		-- the server ended this client's hold (the key, the mana, the give-up): the rapid fire stops; a drawn shot
		-- still due still leaves, and the gun is put away after it as usual
		if d.On == false and sidearm then sidearm.Held = false end
		return
	end
	if d.On then
		putAwayGun(c)
		CastPose.Play(c, "SidearmDraw")
		guns[c] = {
			Gun = AquaFX.SidearmGun(function()
				local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
				local root = c:FindFirstChild("HumanoidRootPart")
				if not (hand and root and c.Parent) then return nil end
				return CFrame.lookAt(hand.Position, hand.Position + root.CFrame.LookVector)
			end, nil, friendly(c)),                              -- (2026-10-19, audit P5D-02 / P5F-06) an enemy's gun: thinned
			LastShot = 0, Shots = 0,
		}
	else
		local g = guns[c]
		if g then g.Off = os.clock() end
	end
end

H.AquaSidearm = function(d)
	local c = d.Character
	if not c or c == player.Character then return end
	if typeof(d.Origin) ~= "Vector3" or typeof(d.Dir) ~= "Vector3" then return end
	local g = guns[c]
	local from = g and g.Gun.Muzzle() or nil
	if g then
		g.Gun.Kick()
		g.LastShot = os.clock()
		g.Shots += 1
	end
	AquaFX.FireSlug(d.Origin, d.Dir, type(d.N) == "number" and d.N or 2, shotExclude(c), from, nil)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local S = A.Sidearm
	for c, g in pairs(guns) do
		-- key up: Linger after the last shot (or, if no shot ever came, a moment after the draw would have fired)
		local done = g.Off and ((g.Shots > 0 and now - math.max(g.Off, g.LastShot) >= S.Linger)
			or (g.Shots == 0 and now - g.Off >= S.DrawTime + 0.6))
		if done or not c.Parent then putAwayGun(c) end
	end
end)

-- Leviathan's Maw: the whole Ultimate from its server time; the server names the shark's target and the bite
local maws = setmetatable({}, { __mode = "k" })      -- [character] = { Handle, T0 }

H.AquaMaw = function(d)
	local c = d.Character
	if typeof(d.Center) ~= "Vector3" then return end
	if c then CastPose.Play(c, "FlashFreeze") end
	-- (2026-10-19, audit P5D-02) own / not; (P5F-06) a teammate's is not thinned either
	local handle = AquaFX.Maw(d.Center, d.T0, c and (c == player.Character or friendly(c)))
	if c then
		local entry = { Handle = handle, T0 = d.T0 }
		maws[c] = entry
		task.delay(A.Maw.EndTime + 0.5, function()
			if maws[c] == entry then maws[c] = nil end
		end)
	end
end

-- (2026-10-19, audit P5D-09) the server ended the Maw early (a round reset, the caster left): the tank's colliders and
-- ceiling go at once and it drains from there (AquaFX's Cancel), so nobody respawns trapped in it
H.AquaMawEnd = function(d)
	local entry = endedEntry(maws, d)
	if entry and type(entry.Handle.Cancel) == "function" then entry.Handle.Cancel() end
end

-- one shark circling for every enemy the tank closed on, each lunging at and biting its own (the owner, 2026-09-25)
H.AquaMawTrapped = function(d)
	local entry = d.Character and maws[d.Character]
	if entry and type(d.Count) == "number" then entry.Handle.SetSharks(d.Count) end
end

H.AquaMawLunge = function(d)
	local entry = d.Character and maws[d.Character]
	if not entry then return end
	if type(d.Targets) == "table" then
		entry.Handle.LungeMany(d.Targets)
	else
		entry.Handle.Lunge(d.Target, d.Point)
	end
end

H.AquaMawBite = function(d)
	local entry = d.Character and maws[d.Character]
	if not entry then return end
	if type(d.Bitten) == "table" then
		entry.Handle.BiteMany(d.Bitten)
	else
		entry.Handle.Bite(d.Target)
	end
end

-- COLOUR WRAPS (2026-10-19): every handler and keypress cast above, the foam at a rider's feet and the local body's own
-- shots draw in their caster's wrap (AquaWrap.Install); with no wrap each is called exactly as before
pcall(function() require(iceFolder:WaitForChild("AquaWrap", 5)).Install(AquaClient, AquaFX) end)

return AquaClient
