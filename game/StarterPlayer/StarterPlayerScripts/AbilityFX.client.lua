--[[
	AbilityFX  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/AbilityFX

	Replays every ability's visuals from the server broadcast, on every client including the
	caster's own. Split out of the old AbilityInputController when that script was retired: input
	and playback were two jobs in one file, and only the input half needed rewriting for the
	Role-shaped binds.

	TWO animation systems, on purpose, and this script only drives one and a half of them:
	  CastPose   the real body -- what every OTHER player sees. Driven for every character here.
	  Viewmodel  the caster's own arms. Driven from SpellshotInput on the keypress, because waiting
	             for this broadcast would put a round trip between the input and the animation.

	The exception is the Ultimate. Its windup, its shot and its stop are server-decided beats
	rather than keypresses, so those are the three places this script also pokes the local
	viewmodel. The two systems are not mirrored and are not meant to match frame for frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local CastPose = require(iceFolder:WaitForChild("CastPose"))
local Viewmodel = require(iceFolder:WaitForChild("Viewmodel"))
local remote = iceFolder:WaitForChild("IceAbilityRemote")
local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))

--- Another player's shot, as this client draws it, flies through whoever the shooter could not hurt, the way it
--- does on the shooter's own screen (SpellshotInput) and in the server's checks.
local function shotExclude(c)
	local shooter = Players:GetPlayerFromCharacter(c)
	return shooter and Config.AddUnhurtable({ c }, shooter) or { c }
end

-- Stances (idle / sprint / crouch / slide) are driven off each character's replicated MoveState
-- attribute. Starting the driver here as well as in FirstPersonController is deliberate and
-- idempotent: this script runs on every client for every character, which is exactly the scope
-- the stance system needs.
CastPose.Start()

-- CryoFX (2026-09-24): Cryo's grounded visuals, and the rebuilt Blizzard / Deep Freeze / Mirror Cage. Found with a
-- timeout so a place without it still plays everything else; its per-frame watchers start here.
local CryoFX = nil
do
	local m = iceFolder:WaitForChild("CryoFX", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	CryoFX = ok and mod or nil
	if CryoFX then CryoFX.Start() end
end

local handlers = {}

-- [character] = os.clock() until which that character is mid Frost Slide dash, as far as this client
-- heard it. Cold Momentum's footfall marks stand down for it: the dash draws its own solid foot lines.
local dashingUntil = setmetatable({}, { __mode = "k" })

-- The local dash, straight from the motor that is running it rather than a round trip later. Looked up
-- lazily so a place without the module still plays every other ability.
local DashMotor = nil
local function localDashing()
	if not DashMotor then
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		local module = folder and folder:FindFirstChild("DashMotor")
		if not module then return false end
		DashMotor = require(module)
	end
	return DashMotor.IsActive()
end

-- Cryo's FROST LOTUS skin (2026-10-15; FrostLotusKit), found lazily: its M1 is the hold-and-pluck
local frostLotusModule = nil
local function frostLotus()
	if frostLotusModule == nil then
		local m = iceFolder:FindFirstChild("FrostLotusKit")
		local ok, mod = pcall(function() return m and require(m) end)
		frostLotusModule = (ok and mod) or false
	end
	return frostLotusModule or nil
end

-- Icicle Shard: the body's palm thrust for everyone, and the crystal shard leaving that hand at
-- full extension. The caster's own shard already left their viewmodel hand on the click.
handlers.IcicleShard = function(d)
	local c = d.Character
	if not c then return end
	local side = (d.Side == "L") and "L" or "R"
	local clipName = "IcicleShard" .. side
	local fl = frostLotus()
	if fl and fl.On(c) and fl.PluckOn() then
		-- Frost Lotus: the right hand plucks a petal from the lotus held in the left and throws it, every shot, on the
		-- same beat; the lotus is held until 1 s after the last shot (FrostLotusKit.M1 reads these, on this client only)
		clipName = "IcicleShardLotus"
		local now = workspace:GetServerTimeNow()
		c:SetAttribute("FrostLotusHold", now + CastPose.Clips.IcicleShardLotus.Keys[#CastPose.Clips.IcicleShardLotus.Keys].t + 1.0)
		c:SetAttribute("FrostLotusPluck", now + 0.02)
	end
	CastPose.Play(c, clipName)
	if c == player.Character or not d.Target then return end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local scale = (ice and ice:GetAttribute("CastPoseTimeScale")) or 1
	task.delay(CastPose.Clips[clipName].Trigger / scale, function()
		local hand = c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
			or c:FindFirstChild(side == "L" and "Left Arm" or "Right Arm")
		if hand and hand.Parent then VFXLibrary.FireIcicleShard(hand.Position, d.Target, shotExclude(c), nil, nil, c) end
	end)
end

handlers.FlashFreeze = function(d)
	if d.Caster then CastPose.Play(d.Caster, "FlashFreeze") end
	-- d.Center: the server's centre, where the caster aimed (2026-10-18); the zone is no longer always at their feet
	if d.OriginPart then VFXLibrary.CastFlashFreeze(d.OriginPart, d.Seed, d.Caster, d.Center) end
end

handlers.FlashFreezeRoot = function(d)
	-- the frozen Highlight itself is server-made and replicates; this is only the moment of
	-- capture, which needs to be loud enough that the victim knows why they stopped moving
	if not d.Character then return end
	if CryoFX then CryoFX.Shatter(d.Character, false, d.Caster) else VFXLibrary.ShatterFX(d.Character, false) end
end

handlers.FlashFreezeShatter = function(d)
	if not d.Character then return end
	if CryoFX then CryoFX.Shatter(d.Character, true, d.Caster) else VFXLibrary.ShatterFX(d.Character, true) end
end

-- Frost Slide: the dash lean for everyone, the dash's spray and foot lines, and the frozen patch where
-- it started. The caster already drew their own spray and lines on the keypress (SpellshotInput), so
-- here that is everybody else's; the patch is the server's alone, so every client -- the caster's too --
-- draws it from this broadcast, on the server's clock.
handlers.FrostSlide = function(d)
	local c = d.Character
	if not c then return end
	CastPose.Play(c, "FrostSlide")
	dashingUntil[c] = os.clock() + 0.35
	if c ~= player.Character and d.Start then
		VFXLibrary.FrostSlideDashFX(c, d.Start, d.Dir, d.Dist, d.Seed)
	end
	if d.Patch then VFXLibrary.FrostSlidePatch(d.Start, d.Normal, d.Dir, d.Seed, d.T0, c) end
end

handlers.ChillAura = function(d)
	if not d.Character then return end
	CastPose.Play(d.Character, "ChillAura")
	VFXLibrary.CastChillAura(d.Character, d.Duration, d.T0)
end

-- the caster died with the aura up: the ring collapses where it is
handlers.ChillAuraStop = function(d)
	if d.Character then VFXLibrary.StopChillAura(d.Character) end
end

handlers.CryoBeamWindup = function(d)
	if not d.Character then return end
	CastPose.Play(d.Character, "CryoBeamCharge")
	VFXLibrary.CryoBeamWindup(d.Character, d.ChargeTime, d.T0)
	if d.Character == player.Character then Viewmodel.Play("CryoBeamCharge") end
end

handlers.CryoBeamFire = function(d)
	if not d.Character then return end
	CastPose.Play(d.Character, "CryoBeam")
	VFXLibrary.CastCryoBeam(d.Character, d.Target, d.T0)          -- the focused crystals become the shot
	if d.Character == player.Character then Viewmodel.Play("CryoBeam") end
end

handlers.CryoBeamAim = function(d)
	if d.Character then VFXLibrary.UpdateCryoBeam(d.Character, d.Target) end
end

handlers.CryoBeamStop = function(d)
	if not d.Character then return end
	VFXLibrary.StopCryoBeam(d.Character)                          -- everything un-forms from where it is
	CastPose.Stop(d.Character)
	if d.Character == player.Character then Viewmodel.Stop() end
end

-- Cryo's rebuilt Techniques and Ultimate (2026-09-24): the body borrows the nearest existing clip (none has its own
-- yet), CryoFX draws the rest. Deep Freeze plays no body clip on purpose: the trap is unseen, and a slam would say where.
handlers.Blizzard = function(d)
	if d.Character then CastPose.Play(d.Character, "ChillAura") end
	if CryoFX then CryoFX.Blizzard(d) end
end
handlers.BlizzardEnd = function(d)
	if CryoFX then CryoFX.BlizzardEnd(d) end
end
handlers.DeepFreezeArmed = function(d)                             -- sent to the caster alone
	if CryoFX then CryoFX.DeepFreezeArmed(d) end
end
handlers.DeepFreezeGone = function(d)
	if CryoFX then CryoFX.DeepFreezeGone(d) end
end
handlers.DeepFreeze = function(d)
	if CryoFX then CryoFX.DeepFreeze(d) end
end
handlers.DeepFreezeEnd = function(d)
	if CryoFX then CryoFX.DeepFreezeEnd(d) end
end
handlers.MirrorCage = function(d)
	if d.Character then CastPose.Play(d.Character, "ChillAura") end
	if CryoFX then CryoFX.MirrorCage(d) end
end
handlers.MirrorCageEnd = function(d)
	if CryoFX then CryoFX.MirrorCageEnd(d) end
end
handlers.MirrorCageFree = function(d)                              -- one trapped body let go early
	if CryoFX then CryoFX.MirrorCageFree(d) end
end
handlers.ChillStacks = function(d)
	if CryoFX then CryoFX.ChillStacks(d) end
end

-- Cold Momentum (Cryo's passive): while a character's buff is up, a frost mark lands under the
-- planted foot on every step of its CastPose locomotion cycle. Driven off replicated attributes, so
-- every client draws everyone's trail with no extra remote.
do
	local RunService = game:GetService("RunService")
	-- (2026-10-19, audit P5F-25) weak keys: a respawned character's entry went only when its player left
	local lastStep = setmetatable({}, { __mode = "k" })   -- [character] = the half-cycle index of its last footfall
	local rng = Random.new()
	RunService.Heartbeat:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local c = plr.Character
			if c and c:GetAttribute("PassiveActive") and (plr:GetAttribute("Element") or "Cryo") == "Cryo" then
				local phase, amt = CastPose.GetCycle(c)
				local hum = c:FindFirstChildOfClass("Humanoid")
				local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
				local sliding = c:GetAttribute("MoveState") == "Slide"
				-- a dash is not a stride, and it leaves its own solid lines under the feet
				local dashing = (dashingUntil[c] or 0) > os.clock() or (c == player.Character and localDashing())
				if phase and amt > 0.5 and grounded and not sliding and not dashing then
					local step = math.floor(phase / math.pi)
					if lastStep[c] and step ~= lastStep[c] then
						local left = c:FindFirstChild("LeftFoot") or c:FindFirstChild("Left Leg")
						local right = c:FindFirstChild("RightFoot") or c:FindFirstChild("Right Leg")
						local foot = (left and right) and ((left.Position.Y <= right.Position.Y) and left or right) or (left or right)
						if CryoFX then CryoFX.ColdMomentumMark(c, foot, rng) else VFXLibrary.ColdMomentumMark(c, foot, rng) end
					end
					lastStep[c] = step
				else
					lastStep[c] = nil
				end
			elseif c then
				lastStep[c] = nil
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		if plr.Character then lastStep[plr.Character] = nil end
	end)
end

----------------------------------------------------------------------------------------------------
-- Pyro (Build Prompt #21)
----------------------------------------------------------------------------------------------------
-- PyroFX draws it and CastPose moves the body. The caster's own arms and fire start on the keypress in
-- SpellshotInput, so for the local player these do only what the server decides.
local PyroFX = require(iceFolder:WaitForChild("PyroFX"))
-- Scorching Lash's burn stacks on every burning body, off RX_Burning_Stacks (2026-09-23). Guarded: PyroFX's
-- phase-two functions are written only after the owner approves the shape sheet and the colour pass.
if PyroFX.WatchBurnStacks then pcall(PyroFX.WatchBurnStacks) end

-- M1, Fireball: the punch for everyone; for everybody else's throw, the charge on the fist and the fireball
-- leaving it at full extension.
handlers.Fireball = function(d)
	local c = d.Character
	if not c then return end
	local side = (d.Side == "L") and "L" or "R"
	CastPose.Play(c, "Fireball" .. side)
	if c == player.Character then return end
	PyroFX.Charge(c, side, d.Hot, false)
	task.delay(PyroFX.Tuning.Fireball.Trigger / VFXLibrary.ShotTimeScale(), function()
		local hand = c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
		if hand and hand.Parent and typeof(d.Dir) == "Vector3" then
			PyroFX.FireFireball((hand.CFrame * CFrame.new(0, -0.45, 0)).Position, d.Dir, shotExclude(c), nil, nil, d.Hot)
		end
	end)
end

-- M1, Wind Blade: the slash for everyone, and for everybody else's shot that stroke's blade leaving that hand on the
-- slash's release. Your own blade already left your viewmodel hand on the click.
local ZephyrFX = nil
local windShotAt = setmetatable({}, { __mode = "k" })   -- [character] = os.clock() of its last Wind Blade
handlers.WindBlade = function(d)
	local c = d.Character
	if not c then return end
	local side = (d.Side == "L") and "L" or "R"
	local stroke = (d.Stroke == "Up") and "Up" or "Down"
	-- chained into the last shot (inside the body clip's hold, HoldUntil), the other arm holds where it is; otherwise
	-- (a new burst) only the slashing arm moves
	local now = os.clock()
	local last = windShotAt[c]
	windShotAt[c] = now
	local chained = last ~= nil
		and (now - last) * VFXLibrary.ShotTimeScale() < CastPose.Clips.WindBladeDownR.HoldUntil
	CastPose.Play(c, "WindBlade" .. stroke .. side .. (chained and "" or "Solo"))
	if c == player.Character or typeof(d.Dir) ~= "Vector3" then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	-- the kit's pre-fire swirl, winding into that palm over the Trigger before its blade leaves (2026-10-08)
	local swirlHand = c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
		or c:FindFirstChild(side == "L" and "Left Arm" or "Right Arm")
	if swirlHand then pcall(ZephyrFX.WindBladeSwirl, swirlHand, side, stroke, d.Dir) end
	task.delay(ZephyrFX.Tuning.WindBlade.Trigger / VFXLibrary.ShotTimeScale(), function()
		local hand = c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
			or c:FindFirstChild(side == "L" and "Left Arm" or "Right Arm")
		-- (2026-10-19, audit P5E-08) the hit line is the shooter's eye down Dir, so the blade flies that line and eases
		-- onto it from the hand (visualFrom), as the shooter's own does; the broadcast carries no eye, so the Head
		-- (where the first-person camera sits) stands in for it. Was: flown from the hand, parallel to the real line.
		local head = c:FindFirstChild("Head")
		if hand and hand.Parent then
			ZephyrFX.FireWindBlade(head and head.Position or hand.Position, d.Dir, shotExclude(c),
				head and hand.Position or nil, nil, side, stroke)
		end
	end)
end

-- Primary, Cross-Slash Dash (held since 2026-09-17): the charge, glide and fling for everyone's body, and for everybody
-- else's cast the load, braid and X, from two broadcasts -- the press (CrossSlashCharge: the wind-up, held) and the
-- launch (CrossSlashDash: the glide, in 3D) -- each caught up by however late it arrived. Your own look and arms started
-- on the keypress (SpellshotInput); your body runs on that same cast's clock (ZephyrFX.CrossSlashClock).
handlers.CrossSlashCharge = function(d)
	local c = d.Character
	if not c then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	if c ~= player.Character then
		local late = (type(d.T0) == "number") and math.clamp(workspace:GetServerTimeNow() - d.T0, 0, 0.5) or 0
		ZephyrFX.CrossSlash(c, nil, { Timing = ZephyrFX.CrossSlashTiming(late) })
	end
	CastPose.PlayClocked(c, "CrossSlashDash", ZephyrFX.CrossSlashClock(c))
end

handlers.CrossSlashDash = function(d)
	local c = d.Character
	if not c or c == player.Character or typeof(d.Dir) ~= "Vector3" then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	local S = ZephyrFX.Tuning.CrossSlash
	local scale = VFXLibrary.ShotTimeScale()
	local late = (type(d.T0) == "number") and math.clamp(workspace:GetServerTimeNow() - d.T0, 0, 0.5) or 0
	local launched = os.clock() - late
	-- the charge's clock, or (its broadcast never came) one started the server's measured hold before the launch
	local timing = ZephyrFX.CrossSlashTimingOf(c)
	if not timing or timing.LaunchAt then
		local hold = (type(d.Hold) == "number" and d.Hold == d.Hold) and math.clamp(d.Hold, 0, S.MaxHold + 1)
			or S.ChargeTime / scale
		timing = ZephyrFX.CrossSlashTiming(os.clock() - launched + hold)
		ZephyrFX.CrossSlash(c, nil, { Timing = timing })
	end
	local dist = (type(d.Dist) == "number" and d.Dist == d.Dist) and d.Dist or S.MinDistance   -- DashDistance is a pace
	timing.LaunchAt = (launched - timing.Start) * scale
	timing.Glide = dist / (S.DashDistance / S.DashTime) * scale
	ZephyrFX.CrossSlashLaunch(c, d.Dir)
	CastPose.PlayClocked(c, "CrossSlashDash", ZephyrFX.CrossSlashClock(c))
end

-- a charge that launched nothing (dropped, refused on the launch, or ended by the server): the body lets the wind-up go
handlers.CrossSlashCancel = function(d)
	local c = d.Character
	if not c then return end
	CastPose.Stop(c)
	if c == player.Character then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	ZephyrFX.CrossSlashCancel(c)
end

-- Mobility, Gust Jump's four handlers (GustJump, GustJumpHover, GustJumpHoverEnd, GustJumpLand) were here until
-- 2026-10-06, the v6 import: Skyrider replaced it, and its broadcasts (SkyriderStart / SkyriderGust / SkyriderHit /
-- SkyriderEnd), Gust Pad's and Updraft's are ZephyrClient's (merged at the bottom).

-- Ultimate, Cyclone (2026-09-17): from the cast, the arms up and circling on everyone's body (looped for as long as it
-- forms) and the tornado forming at the spot for everyone, you included; everybody else's copy follows the spots the server
-- passes on (yours follows your own crosshair, SpellshotInput); at touchdown the palms push out at it, and at the end it
-- unwinds (or, cut off, is gone at once). Your own arms started on the keypress; these only move them on server beats.
local function cycloneLate(d)
	return (type(d.T0) == "number") and math.max(0, workspace:GetServerTimeNow() - d.T0) or 0
end

handlers.Cyclone = function(d)
	local c = d.Character
	if not (c and typeof(d.Center) == "Vector3") then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	local late = math.min(cycloneLate(d), ZephyrFX.Tuning.Cyclone.LateMax)
	local clip = CastPose.Clips.CycloneForm
	CastPose.PlayClocked(c, "CycloneForm", ZephyrFX.CycloneLoopClock(os.clock(), clip.LoopFrom, clip.LoopLength, late))
	ZephyrFX.Cyclone(c, d.Center, { Late = late, Own = c == player.Character })
end

handlers.CycloneSteer = function(d)
	local c = d.Character
	if not (c and typeof(d.Center) == "Vector3") or c == player.Character then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	ZephyrFX.CycloneSteer(c, d.Center)
end

handlers.CycloneActive = function(d)
	local c = d.Character
	if not (c and typeof(d.Center) == "Vector3") then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	ZephyrFX.CycloneActive(c, d.Center, cycloneLate(d))
	CastPose.Play(c, "CycloneRelease")
	if c == player.Character and Viewmodel.CurrentClip() == "CycloneForm" then Viewmodel.Play("CycloneRelease") end
end

-- the end: a Cyclone cut off before touchdown also lets the circling arms go (a refused cast never started them here)
handlers.CycloneEnd = function(d)
	local c = d.Character
	if not c then return end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	ZephyrFX.CycloneEnd(c, d.Instant == true)
	if not d.Formed and not d.Refused then CastPose.Stop(c) end
	if c == player.Character and Viewmodel.CurrentClip() == "CycloneForm" then Viewmodel.Stop() end
end

-- CAUGHT. Your client simulates your own body, so a Cyclone that catches you asks it to move you (the server sends these
-- to you alone, every PullSend while you are held, each good for PullHold): a LinearVelocity on the root, DashMotor's
-- mover, steered every Heartbeat by ZephyrFX.CyclonePullVelocity -- in, round and up. A dash or a Skyrider ride under way
-- lets go first. It ends on CycloneRelease, when the messages stop, or with the body; a body let go keeps at most
-- ReleaseSpeed. Nothing checks that a client obeys: like every body a client moves, the server cannot force it (flagged).
local RunService = game:GetService("RunService")
local caught = nil           -- { Caster, Character, Root, Humanoid, Center, Until, Since, Seed, Attachment, Mover, Conn }

-- Whatever of Zephyr's moves YOUR body (Skyrider's ride, since the v6 import of 2026-10-06; Gust Jump's glide before it)
-- lets go when something else takes the body -- ZephyrClient.Interrupt(reason), found lazily, guarded: a missing or
-- failing module just interrupts nothing.
local zephyrClient = nil
local function interruptZephyrMotion(reason)
	if zephyrClient == nil then
		local m = iceFolder:FindFirstChild("ZephyrClient")
		local ok, mod = pcall(function() return m and require(m) end)
		zephyrClient = (ok and type(mod) == "table" and mod) or false
	end
	if zephyrClient and type(zephyrClient.Interrupt) == "function" then
		pcall(zephyrClient.Interrupt, reason)
	end
end

local function dropCaught()
	local k = caught
	if not k then return end
	caught = nil
	k.Conn:Disconnect()
	k.Mover:Destroy()
	k.Attachment:Destroy()
	if k.Root.Parent then
		local v = k.Root.AssemblyLinearVelocity
		local most = ZephyrFX.Tuning.Cyclone.ReleaseSpeed
		if v.Magnitude > most then k.Root.AssemblyLinearVelocity = v.Unit * most end
	end
end

handlers.CyclonePull = function(d)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0 and typeof(d.Center) == "Vector3" and type(d.Until) == "number") then
		return
	end
	ZephyrFX = ZephyrFX or require(iceFolder:WaitForChild("ZephyrFX"))
	if caught and caught.Character == character then
		caught.Caster, caught.Center, caught.Until = d.Caster, d.Center, d.Until
		return
	end
	dropCaught()
	-- whatever else was moving the body lets go of it
	if localDashing() then DashMotor.Cancel("Cyclone") end
	interruptZephyrMotion("Cyclone")
	local C = ZephyrFX.Tuning.Cyclone
	local attachment = Instance.new("Attachment")
	attachment.Name = "CyclonePullAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "CyclonePull"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * C.ForcePerMass
	mover.MaxAxesForce = Vector3.new(force, force, force)
	mover.VectorVelocity = root.AssemblyLinearVelocity
	mover.Parent = attachment
	attachment.Parent = root
	local k = {
		Caster = d.Caster, Character = character, Root = root, Humanoid = humanoid, Center = d.Center, Until = d.Until,
		Since = os.clock() - math.clamp(type(d.Held) == "number" and d.Held or 0, 0, C.LiftTime),
		Seed = type(d.Seed) == "number" and d.Seed or 0, Attachment = attachment, Mover = mover,
	}
	caught = k
	k.Conn = RunService.Heartbeat:Connect(function()
		if caught ~= k then return end
		if player.Character ~= character or not root.Parent or humanoid.Health <= 0
			or workspace:GetServerTimeNow() > k.Until then
			dropCaught()
			return
		end
		mover.VectorVelocity = ZephyrFX.CyclonePullVelocity(root.Position, k.Center, os.clock() - k.Since, k.Seed)
	end)
end

handlers.CycloneRelease = function(d)
	if caught and (d.Caster == nil or d.Caster == caught.Caster) then dropCaught() end
end

handlers.Immolate = function(d)
	if not d.Character then return end
	CastPose.Play(d.Character, "Immolate")
	PyroFX.Immolate(d.Character, d.T0)
end

handlers.EmberRefund = function(d)
	if d.Character then PyroFX.EmberRefund(d.Character, d.From) end
end


-- Ring of Fire, on the server's clock from T0: the hand draws the circle round the pointed spot by itself (the arm
-- follows the drawing point in third person, and your own fist loops round in first person), then the settle as it
-- closes, then the snap-and-point. PyroFX times the line, seal, eruption and IGNITE! from the same T0.
handlers.RingOfFire = function(d)
	local c = d.Character
	if not (c and typeof(d.Center) == "Vector3") then return end
	local own = c == player.Character
	local R = PyroFX.Tuning.RingOfFire
	PyroFX.RingOfFire(c, d.Center, d.Radius, d.Hot, d.T0, d.Start, function(point)
		CastPose.SetAim(c, point)
	end)
	local late = (type(d.T0) == "number") and math.max(0, workspace:GetServerTimeNow() - d.T0) or 0
	if own then Viewmodel.SetTrace(true, os.clock() - late, R.DrawTime) end
	task.delay(math.max(0, R.DrawTime - late), function()
		-- the trace ends whatever became of the body (review r1, 2026-09-24): a draw cut short by a new body -- a duel
		-- round's reset, the trip home -- returned below with the trace still on, and every later body then refused the
		-- M1, Detonate and the Lash (Viewmodel.Tracing) until another Ring of Fire was drawn to its end
		if own then Viewmodel.SetTrace(false) end
		if not c.Parent then return end
		CastPose.SetAim(c, nil)
		CastPose.Play(c, "RingOfFireSettle")
		if own then Viewmodel.Play("RingOfFireSettle") end
	end)
	task.delay(math.max(0, R.DrawTime + R.SettleTime - late), function()
		if not c.Parent then return end
		CastPose.Play(c, "RingOfFirePoint")
		if own then
			Viewmodel.Play("RingOfFireIdle")
			Viewmodel.PlayShot("R", "RingOfFirePoint")
		end
	end)
end

-- ...and until the snap the circle follows its caster's crosshair. Your own is moved straight from your aim
-- (SpellshotInput), so the spots the server passes on only move someone else's; the lock, where the server lit it,
-- pins every copy.
handlers.RingOfFireSteer = function(d)
	local c = d.Character
	if not (c and typeof(d.Center) == "Vector3") or c == player.Character then return end
	PyroFX.SteerRing(c, d.Center)
end

handlers.RingOfFireLock = function(d)
	local c = d.Character
	if not (c and typeof(d.Center) == "Vector3") then return end
	PyroFX.LockRing(c, d.Center)
end

-- Pyro phase two (2026-09-23): DETONATE and SCORCHING LASH (Techniques since round 2: Detonate Pyro's only, the Lash
-- anyone's, either one in Q or E). The bodies move
-- here for everyone, the caster's own included (CastPose); the caster's arms started on the keypress (SpellshotInput).
-- EVERY PyroFX CALL IS GUARDED: those functions are written only after the owner has approved the shape sheet and the
-- colour pass, so until they exist these handlers move the bodies and draw nothing, and one that errors is warned about
-- once rather than taking its handler down with it. The Instances in these broadcasts can arrive nil (a map streamed out
-- on this client) or be gone by now, so each is checked, and the blasts carry a Position of their own.
local phaseTwoWarned = {}
local function pyroHook(name, ...)
	local fn = PyroFX[name]
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok and not phaseTwoWarned[name] then
		phaseTwoWarned[name] = true
		warn("AbilityFX: PyroFX." .. name .. " failed: " .. tostring(err))
	end
end

local function present(inst)
	return typeof(inst) == "Instance" and inst.Parent ~= nil
end

-- the flick, for everyone's body; the mark itself lands on the flick's beat (DetonateMark)
handlers.Detonate = function(d)
	local c = d.Character
	if not present(c) then return end
	CastPose.Play(c, "Detonate")
	pyroHook("DetonateFlick", c, d.T0)
end

-- { Character, Victim, T0 (server time the mark landed), Fuse (seconds to the blast) }: nothing to hang it on without
-- the victim here
handlers.DetonateMark = function(d)
	if not present(d.Victim) then return end
	pyroHook("DetonateMark", d)
end

-- { Character, Victim, Position, Amount, Scale (0..1), Lethal, T0 }: the caster may be gone (a blast outlives its
-- caster's death), and the victim streamed out -- the Position still places it
handlers.DetonateBlast = function(d)
	if not (present(d.Victim) or typeof(d.Position) == "Vector3") then return end
	pyroHook("DetonateBlast", d)
end

-- { Victim, Position }: the mark went out without a blast
handlers.DetonateFizzle = function(d)
	if not (present(d.Victim) or typeof(d.Position) == "Vector3") then return end
	pyroHook("DetonateFizzle", d)
end

-- { Character, T0, On }: the whip HELD (round 2, 2026-09-24). On: the body takes the hold -- since round 3 the whip arm
-- drawn back and the other pointing forward -- and rests on it (SetBase, so anything else the body plays meanwhile comes
-- back to it), and the burning whip trails from the hand, for everyone. Off (the hold ended without a sweep: a death, a
-- clear, a swap): the body lets go and the whip goes. A sweep ends the hold too, but on its own broadcast (ScorchingLash,
-- below), which carries no Off.
handlers.ScorchingLashHold = function(d)
	local c = d.Character
	if not present(c) then return end
	local own = c == player.Character
	if d.On == true then
		CastPose.Play(c, "ScorchingLashHold")
		CastPose.SetBase(c, "ScorchingLashHold")
		pyroHook("LashHold", c, true, d.T0, own)
	else
		CastPose.SetBase(c, nil)
		if CastPose.CurrentClip(c) == "ScorchingLashHold" then CastPose.Stop(c) end
		pyroHook("LashHold", c, false, nil, own)
	end
end

-- { Character, T0, Dir }: the SWEEP (round 3), for everyone's body -- the hold lets go of the base pose and the sweep clip
-- plays -- and the whip swept round the caster from Dir (the flat aim at the release); the caster's own whip is told it
-- is theirs (drawn off the first-person view's fist)
handlers.ScorchingLash = function(d)
	local c = d.Character
	if not present(c) then return end
	CastPose.SetBase(c, nil)
	CastPose.Play(c, "ScorchingLash")
	pyroHook("Lash", c, d.T0, typeof(d.Dir) == "Vector3" and d.Dir or nil, c == player.Character)
end

-- { Character, Victims = { model, ... }, Positions = { Vector3, ... } }: a victim may arrive nil, its Position will not
handlers.ScorchingLashHit = function(d)
	if type(d.Positions) ~= "table" and type(d.Victims) ~= "table" then return end
	pyroHook("LashHit", d)
end

----------------------------------------------------------------------------------------------------
-- TERRA
----------------------------------------------------------------------------------------------------
local TerraFX = nil
-- [character] = a token table while that character is gathering a Boulder Shot. The rock gathers in their hand for
-- everyone else from the moment the hold reaches the server, so the charge is a telegraph you can react to: a big
-- rock in a Terra's hand is the tell that a heavy shot is coming. The caster's own rock is already in their own
-- hand from the press (SpellshotInput). The token keeps TerraFX's rock (Rock), so the throw flies THAT rock on.
local terraCharge = setmetatable({}, { __mode = "k" })
-- The server announces the end of a hold (BoulderChargeStop) one message BEFORE the throw (BoulderShot): the thrower
-- sends BoulderCharge{On=false} on the ice remote and the cast on the cast remote after it. So a stop is not a drop
-- straight away -- the rock stays in the hand this long for the throw to come and take it, and only then falls apart.
local BOULDER_STOP_GRACE = 0.35
-- [character] = how many holds have started: a stop's delayed let-go only lets go of ITS OWN hold's windup, never a
-- newer one pressed inside the grace (a dropped tap mashed straight into the next hold)
local boulderHolds = setmetatable({}, { __mode = "k" })

local function bodyHand(c)
	return function()
		if not c.Parent then return nil end
		local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		local root = c:FindFirstChild("HumanoidRootPart")
		if not (hand and hand.Parent and root) then return nil end
		local look = root.CFrame.LookVector
		return hand.CFrame, nil, CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
	end
end

handlers.BoulderChargeStart = function(d)
	local c = d.Character
	if not c then return end
	-- the BODY, for every client including the thrower's own (nobody sees their own body in first person, but
	-- everybody else does): the rework's windup (2026-09-23), clocked in seconds on the server's clock from the press
	boulderHolds[c] = (boulderHolds[c] or 0) + 1
	local t0 = d.T0
	if t0 then
		CastPose.PlayClocked(c, "BoulderWindup", function() return workspace:GetServerTimeNow() - t0 end)
	else
		CastPose.Play(c, "BoulderWindup")
	end
	if c == player.Character then return end
	TerraFX = TerraFX or require(iceFolder:WaitForChild("TerraFX"))
	local token = { At = os.clock() }
	terraCharge[c] = token
	token.Rock = TerraFX.Charge(function()
		if terraCharge[c] ~= token or not c.Parent then return nil end
		local held = (token.StopAt or os.clock()) - token.At
		if token.StopAt and os.clock() - token.StopAt >= (token.Grace or 0) then return nil end
		return math.clamp(held / TerraFX.Tuning.BoulderShot.ChargeTime, 0, 1)
	end, bodyHand(c), { Thin = VFXLibrary.IsEnemy(c), Character = c, Wrap = d.Skin })   -- (2026-10-19, audit P5F-06) a teammate's is drawn full
end

handlers.BoulderChargeStop = function(d)
	local c = d.Character
	if not c then return end
	-- a RELEASE (the server accepted a throw: its BoulderShot is on the way) keeps the rock in the hand for the grace;
	-- a DROP (death, a round clearing, an "Interrupted" -- her own Aftershock's slam taking both arms, or somebody else's
	-- striking her, 2026-09-25; the burrow it once named went with Tremor Vault) lets it go this frame -- a rock left in a
	-- hand that is slamming the ground, or being thrown back, would read as a throw still coming
	local grace = d.Reason == "Release" and BOULDER_STOP_GRACE or 0
	local token = terraCharge[c]
	if token and not token.StopAt then
		token.StopAt = os.clock()
		token.Grace = grace
	end
	local hold = boulderHolds[c]
	-- dropped rather than thrown: the body lets ITS OWN hold go -- once the throw has had its chance to arrive (the
	-- throw broadcast plays its own clip instead, from wherever the windup had got to)
	task.delay(grace, function()
		if token and token.Thrown then return end
		if terraCharge[c] == token then terraCharge[c] = nil end
		if boulderHolds[c] == hold and CastPose.CurrentClip(c) == "BoulderWindup" then CastPose.Stop(c) end
	end)
end

-- The throw itself, for everyone but the thrower: their own boulder left their own hand on the release.
-- Bedrock (the Passive): the plates assemble from each character's own Bedrock_Stacks attribute, so every
-- client draws every Terra's shield with no remote at all -- the same arrangement Cold Momentum's footfalls use.
-- Staggered (Bulwark Charge's knockdown) the same way: stars round every staggered head, from RX_Staggered.
do
	local TF = require(iceFolder:WaitForChild("TerraFX"))
	TF.WatchBedrock()
	TF.WatchWraps()
	TF.WatchStagger()
end

-- Bulwark Charge: the ground tearing up behind the charger, and the knockdown burst where the shoulder lands.
-- The charger's own trail started on their keypress (SpellshotInput); the burst is the server's, so every client
-- draws it -- including the charger's, which is the only word they get that the charge connected.
handlers.BulwarkCharge = function(d)
	local c = d.Character
	if not c or c == player.Character then return end
	TerraFX = TerraFX or require(iceFolder:WaitForChild("TerraFX"))
	local until_ = os.clock() + TerraFX.Tuning.BulwarkCharge.MaxTime
	TerraFX.BulwarkTrail(c, function() return os.clock() < until_ end, d.Skin)
end

handlers.BulwarkHit = function(d)
	if typeof(d.Position) ~= "Vector3" then return end
	TerraFX = TerraFX or require(iceFolder:WaitForChild("TerraFX"))
	TerraFX.BulwarkHit(d.Position, d.Dir, d.Character ~= player.Character, d.Skin)
end

-- Earthen Tomb (the Ultimate, 2026-09-19; v2, the redesign): every beat is TerraHandler's verdict, so every client --
-- the caster's included -- draws each one from its broadcast, on the server's clock (T0). Terra's floor-grab pose is NOT
-- here: CastPose holds it off her TombPhase attribute, the same state the server branches on.
local function terra()
	TerraFX = TerraFX or require(iceFolder:WaitForChild("TerraFX"))
	return TerraFX
end
-- Bulwark Wall (the Defense, 2026-09-19): raised, hit, and dropped on TerraHandler's word.
handlers.WallRaise = function(d)
	if d.Character and typeof(d.CF) == "CFrame" then terra().WallRaise(d.Character, d.CF, d.T0) end
end
-- (2026-10-19, audit P5B-17) the server's T0 rides along, as WallRaise's does, so the rework's late-beat logic runs
-- from the server's moment, not the arrival (TerraFX forwards it to TerraFX_Wall's Hit / Drop)
handlers.WallHit = function(d)
	if d.Character and typeof(d.Point) == "Vector3" then terra().WallHit(d.Character, d.Point, d.Left, d.T0) end
end
handlers.WallDrop = function(d)
	if d.Character then terra().WallDrop(d.Character, d.Reason, d.T0) end
end
-- AFTERSHOCK (the Mobility Technique, 2026-09-25; it REPLACES Tremor Vault, whose VaultSink / VaultPop handlers are
-- deleted rather than disabled, as Glacial Spikes' were): both fists into the ground and a ring of erupting rock racing
-- out from the fists' point. Every beat is TerraHandler's, on the server's clock from T0 and slowed by ShotTimeScale as
-- the server's hit test is, so every client -- the caster's own included -- draws the very front the server strikes
-- with. The BODY plays for everyone, the caster's own too (nobody sees their own body in first person, everybody else
-- does), on TerraFX.AftershockClock: the clip's keys are in "sim" seconds and the clock holds the contact frame through
-- the hitpause (HoldFrames). The caster's own arms and camera started on the keypress (SpellshotInput).
local function aftershockClock(t0)
	return function()
		return terra().AftershockClock((workspace:GetServerTimeNow() - t0) * VFXLibrary.ShotTimeScale())
	end
end

-- { Character, At (the centre, on the floor), Face (flat unit), T0, Seed }
handlers.Aftershock = function(d)
	local c = d.Character
	if not (present(c) and typeof(d.At) == "Vector3" and typeof(d.Face) == "Vector3"
		and type(d.T0) == "number" and d.T0 == d.T0) then
		return
	end
	local own = c == player.Character
	CastPose.PlayClocked(c, "Aftershock", aftershockClock(d.T0))
	terra().Aftershock(c, d.At, d.Face, d.T0, {
		-- (2026-10-19, audit P5F-06) no Thin: TerraFX.Aftershock thins an enemy's (VFXLibrary.IsEnemy), not a teammate's
		Own = own, Seed = (type(d.Seed) == "number" and d.Seed == d.Seed) and d.Seed or 0,
	})
end

-- { Character (the caster), Victim, At (the victim's feet, on the floor), Dir (flat, out from the centre), T0 }: the
-- shard under a struck body. The caster may be gone (the ring outlives its caster) and the victim streamed out -- At
-- still places it.
handlers.AftershockStrike = function(d)
	if not (typeof(d.At) == "Vector3" and typeof(d.Dir) == "Vector3") then return end
	local c = typeof(d.Character) == "Instance" and d.Character or nil
	local victim = typeof(d.Victim) == "Instance" and d.Victim or nil
	local t0 = (type(d.T0) == "number" and d.T0 == d.T0) and d.T0 or workspace:GetServerTimeNow()
	terra().AftershockStrike(c, victim, d.At, d.Dir, t0)
end

-- { Character, Reason }: the windup was cut before the slam (a death, a clear, an interrupt, a Tomb) -- the look goes at
-- once and the body lets ITS OWN clip go. Sent only before Hit: after the slam the ring is committed and runs out.
handlers.AftershockEnd = function(d)
	local c = d.Character
	if typeof(c) ~= "Instance" then return end
	terra().AftershockEnd(c, type(d.Reason) == "string" and d.Reason or nil)
	if CastPose.CurrentClip(c) == "Aftershock" then CastPose.Stop(c) end
end

-- STRUCK (sent to you alone): the front throws you back. Your client simulates your own body, so the server asks it to
-- move you, as Cyclone's pull and Aqua's knock do (the CyclonePull pattern above; AquaClient's AquaKnock): a dash or a
-- Skyrider ride under way lets go first, then a LinearVelocity on the root drives the server's Velocity until its Until (server
-- time; KnockTime after the strike) and lets go -- the launch then carries on under the body's own physics. A newer
-- knock replaces an older one. Nothing checks that a client obeys (flagged, as for Cyclone).
local knocked = nil          -- { Character, Root, Humanoid, Until, Attachment, Mover, Conn }

local function dropKnock()
	local k = knocked
	if not k then return end
	knocked = nil
	k.Conn:Disconnect()
	k.Attachment:Destroy()
end

handlers.AftershockKnock = function(d)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local v = d.Velocity
	if not (root and humanoid and humanoid.Health > 0 and typeof(v) == "Vector3" and v == v and v.Magnitude <= 500
		and type(d.Until) == "number" and d.Until == d.Until) then
		return
	end
	dropKnock()
	-- whatever else was moving the body lets go of it
	if localDashing() then DashMotor.Cancel("Aftershock") end
	interruptZephyrMotion("Aftershock")
	local A = terra().Tuning.Aftershock
	local attachment = Instance.new("Attachment")
	attachment.Name = "AftershockKnockAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "AftershockKnock"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * A.KnockForcePerMass
	mover.MaxAxesForce = Vector3.new(force, force, force)
	mover.VectorVelocity = v
	mover.Parent = attachment
	attachment.Parent = root
	local k = { Character = character, Root = root, Humanoid = humanoid, Until = d.Until, Attachment = attachment,
		Mover = mover }
	knocked = k
	k.Conn = RunService.Heartbeat:Connect(function()
		if knocked ~= k then return end
		if player.Character ~= character or not root.Parent or humanoid.Health <= 0
			or workspace:GetServerTimeNow() > k.Until then
			dropKnock()
		end
	end)
	-- ...and your own screen's Knockback pulse (StatusReactions, _G.SpellshotReactions), never RX_Staggered: that flag
	-- draws the stars over your head for everyone. The screen-wide displacement fans were retired on request on
	-- 2026-09-24, so today this pulse draws nothing; it is kept so the moment is reported if a HUD treatment returns.
	local R = _G.SpellshotReactions
	if type(R) == "table" and type(R.Pulse) == "function" then pcall(R.Pulse, "Knockback") end
end

-- ELEMENTAL REACTIONS (2026-10-17): a reaction set off on YOUR body pops its word by your own health bar (StatusReactions'
-- "Reaction" pulse); everyone else reads it over your head (ElementalReactions' callout).
handlers.Reaction = function(d)
	if d.Victim == nil or d.Victim ~= player.Character then return end
	local R = _G.SpellshotReactions
	if type(R) == "table" and type(R.Pulse) == "function" then pcall(R.Pulse, "Reaction", d) end
end

handlers.TombCast = function(d)
	if not (d.Character and d.Victim and typeof(d.From) == "Vector3") then return end
	terra().TombCast(d.Character, d.Victim, d.From, d.T0, d.Grip, d.Speed, d.Reach)
end
handlers.TombMiss = function(d)
	if d.Character then terra().TombMiss(d.Character, d.At) end
end
handlers.TombCatch = function(d)
	if not (d.Character and typeof(d.At) == "Vector3") then return end
	terra().TombCatch(d.Character, d.Victim, d.At, d.Face, d.T0, d.Rise or 1.6, d.Height or 12)
end
handlers.TombBreak = function(d)
	if d.Character then terra().TombBreak(d.Character, d.Reason) end
end
handlers.TombBurst = function(d)
	if d.Character then terra().TombBurst(d.Character, d.Position, d.Hit) end
end
handlers.TombDescend = function(d)
	if d.Character then terra().TombDescend(d.Character, d.T0, d.Time, d.From) end
end

handlers.BoulderShot = function(d)
	local c = d.Character
	if not c then return end
	local token = terraCharge[c]
	terraCharge[c] = nil
	if token then token.Thrown = true end
	CastPose.Play(c, "BoulderThrow")        -- the body throws for every client, the thrower's own included
	if c == player.Character or typeof(d.Dir) ~= "Vector3" then return end
	TerraFX = TerraFX or require(iceFolder:WaitForChild("TerraFX"))
	local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	local from = hand and hand.Parent and hand.Position or nil
	local head = c:FindFirstChild("Head")
	local origin = head and head.Position or from
	if not origin then return end
	-- the rock that was gathering in their hand is the one that flies (nothing gathered here -- a late joiner -- and a
	-- whole rock leaves the hand instead)
	local live = token and token.Rock and not token.Rock.Broken and not token.Rock.Thrown and token.Rock or nil
	TerraFX.FireBoulder(origin, d.Dir, d.Charge or 0, shotExclude(c), live or from, nil, d.Skin)   -- (2026-10-18 review: was { c }, so it broke on the thrower's teammates)
end

-- EARTHEN TOMB, first person (2026-09-20). CastPose does the body for everyone off the same attribute; this is the
-- caster's OWN view. The keypress already plays the smash (SpellshotInput plays the clip named for the ability), so
-- what is left is the two ends it cannot see: the RAISE once the platform starts to climb -- clocked by the climb, so
-- the hand rises with the stone -- and letting go when the Tomb is over, however it ended (the catch's miss, a break,
-- a death, a round reset: TombPhase is cleared on all of them).
local function watchOwnTomb(character)
	if not character then return end
	local function pose()
		local phase = character:GetAttribute("TombPhase")
		if phase == "Rise" then
			Viewmodel.Play("EarthenTombRaise", function()
				local at, over = character:GetAttribute("TombRiseAt"), character:GetAttribute("TombRiseFor")
				if not (at and over and over > 0) then return 1 end
				local u = math.clamp((workspace:GetServerTimeNow() - at) / over, 0, 1)
				return 1 - (1 - u) ^ 2.2          -- TerraFX.TombRise, the platform's own curve
			end)
		elseif phase == "Cast" then
			if Viewmodel.CurrentClip() ~= "EarthenTomb" then Viewmodel.Play("EarthenTomb") end
		else
			local clip = Viewmodel.CurrentClip()
			if clip == "EarthenTomb" or clip == "EarthenTombRaise" then Viewmodel.Stop() end
		end
	end
	character:GetAttributeChangedSignal("TombPhase"):Connect(pose)
	character:GetAttributeChangedSignal("TombRiseAt"):Connect(pose)
	pose()
	-- ...and Bulwark Wall's hand, first person: up on the cast, braced while the wall stands, let go whenever the
	-- server says the hold is over (released, broken, bar empty, dead). The wall may be in either Technique slot since
	-- v0.7 (2026-09-24), so both holds are watched.
	local function wall()
		if character:GetAttribute("Holding_Defense") == "BulwarkWall"
			or character:GetAttribute("Holding_Mobility") == "BulwarkWall" then
			if Viewmodel.CurrentClip() ~= "BulwarkWall" then Viewmodel.Play("BulwarkWall") end
		elseif Viewmodel.CurrentClip() == "BulwarkWall" then
			Viewmodel.Stop()
		end
	end
	character:GetAttributeChangedSignal("Holding_Defense"):Connect(wall)
	character:GetAttributeChangedSignal("Holding_Mobility"):Connect(wall)
	wall()
end
watchOwnTomb(player.Character)
player.CharacterAdded:Connect(watchOwnTomb)

-- Aqua (2026-09-24): every Aqua* broadcast is AquaClient's (found with a timeout, like CryoFX, so a place without it
-- still plays everything else)
do
	local m = iceFolder:WaitForChild("AquaClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod then
		for kind, fn in pairs(mod.Handlers) do handlers[kind] = fn end
	end
end

-- (2026-10-19, audit P5F-25) the five merges below run off the load path, after the listener at the bottom can already
-- hear their kinds: a broadcast with no handler YET is held (at most 64) and played when its module's merge lands,
-- instead of dropped. Once every merge has finished, an unknown kind is just ignored again.
local held = { Waiting = 5, List = {} }
function held.Done()
	held.Waiting -= 1
	local keep = {}
	for _, e in ipairs(held.List) do
		local h = handlers[e[1]]
		if h then task.spawn(h, e[2])
		elseif held.Waiting > 0 then keep[#keep + 1] = e end
	end
	held.List = keep
end

-- Voltaic (2026-09-25): every Voltaic broadcast is VoltaicClient's (plus StatusDischarge, which had no handler).
-- Merged off the load path so nothing here waits on it, and never over a kind that already has a handler.
task.spawn(function()
	local m = iceFolder:WaitForChild("VoltaicClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod and type(mod.Handlers) == "table" then
		for kind, fn in pairs(mod.Handlers) do handlers[kind] = handlers[kind] or fn end
	elseif m then
		warn("[AbilityFX] VoltaicClient failed to load: " .. tostring(mod))
	end
	held.Done()
end)

-- Umbra (2026-09-27): every Umbra broadcast is UmbraClient's. Merged off the load path, never over an existing handler.
task.spawn(function()
	local m = iceFolder:WaitForChild("UmbraClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod and type(mod.Handlers) == "table" then
		for kind, fn in pairs(mod.Handlers) do handlers[kind] = handlers[kind] or fn end
	elseif m then
		warn("[AbilityFX] UmbraClient failed to load: " .. tostring(mod))
	end
	held.Done()
end)

-- Radiant (2026-09-29): every Radiant broadcast is RadiantClient's. Merged off the load path, never over an existing handler.
task.spawn(function()
	local m = iceFolder:WaitForChild("RadiantClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod and type(mod.Handlers) == "table" then
		for kind, fn in pairs(mod.Handlers) do handlers[kind] = handlers[kind] or fn end
	elseif m then
		warn("[AbilityFX] RadiantClient failed to load: " .. tostring(mod))
	end
	held.Done()
end)

-- Toxin (2026-09-30): every Toxin broadcast is ToxinClient's. Merged off the load path, never over an existing handler.
task.spawn(function()
	local m = iceFolder:WaitForChild("ToxinClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod and type(mod.Handlers) == "table" then
		for kind, fn in pairs(mod.Handlers) do handlers[kind] = handlers[kind] or fn end
	elseif m then
		warn("[AbilityFX] ToxinClient failed to load: " .. tostring(mod))
	end
	held.Done()
end)

-- Zephyr (2026-10-06, the v6 import): every Skyrider, Gust Pad and Updraft broadcast is ZephyrClient's (it merges the three
-- modules' Handlers). Merged off the load path, never over an existing handler -- the Wind Blade, Cross-Slash and Cyclone
-- broadcasts above stay this script's own.
task.spawn(function()
	local m = iceFolder:WaitForChild("ZephyrClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod and type(mod.Handlers) == "table" then
		for kind, fn in pairs(mod.Handlers) do handlers[kind] = handlers[kind] or fn end
		held.Done()
		-- (2026-10-19, audit P5E-13) a piece that had not replicated within ZephyrClient's PieceWait is merged into its
		-- Handlers later, and this copy was taken once: look again while any piece is still missing (for two minutes),
		-- asking ZephyrClient to look for it too where it offers that (Refresh), since a non-Zephyr never presses a key
		-- that would make it look
		local function missing()
			local okL, loaded = pcall(mod.Loaded)
			if not (okL and type(loaded) == "table") then return false end
			for _, st in pairs(loaded) do if st == "missing" then return true end end
			return false
		end
		for _ = 1, 40 do
			if not missing() then break end
			task.wait(3)
			if type(mod.Refresh) == "function" then pcall(mod.Refresh) end
			for kind, fn in pairs(mod.Handlers) do handlers[kind] = handlers[kind] or fn end
		end
	else
		if m then warn("[AbilityFX] ZephyrClient failed to load: " .. tostring(mod)) end
		held.Done()
	end
end)

remote.OnClientEvent:Connect(function(action, kind, data)
	if action ~= "VFX" then return end
	local handler = handlers[kind]
	if type(data) ~= "table" then return end
	if handler then task.spawn(handler, data)
	elseif held.Waiting > 0 and #held.List < 64 then held.List[#held.List + 1] = { kind, data } end   -- (audit P5F-25)
end)
