--[[
	ZephyrSkyrider  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrSkyrider          Zephyr v6 import, 2026-10-06

	SKYRIDER, the Technique pool's Mobility half (it REPLACES Gust Jump: the owner's decision, ROBLOX_IMPORT_PLAN
	section 0). Summon a bird of wind and ride it: fly where you look, flap a gust that throws enemies back; it drains
	mana until you jump off.

	ONE SHARED MODULE, TWO SIDES (the plan's client contract, section 5):
	  .Tuning      every gameplay number. ServerScriptService.ZephyrSkyriderServer requires this module for it, so the
	               module is INERT on the server: nothing client-side is touched, waited on or bound at require; every
	               other module is found lazily, on first use, and every call into one is pcall-guarded.
	  .Handlers    the broadcasts this piece receives, ("VFX", kind, data) on IceAbilityRemote through AbilityFX
	               (ZephyrClient merges them, each wrapped):
	                 SkyriderStart   { Caster (character), T0 (server time of the press) }   the bird gathers
	                 SkyriderGust    { Caster, Dir (unit Vector3), T0 }                       the flap: wind-up, stroke, cone
	                 SkyriderGustHit { Caster, Victim (model), At (Vector3), T0 }            a body the cone reached
	                 SkyriderHit     { Caster, At, T0 }                                       the rider was hurt: the wobble
	                 SkyriderEnd     { Caster, Reason, T0 }                                   the dismount
	                 SkyriderKnock   { Velocity, Until (server time), Caster }                to a struck PLAYER alone: their
	                                 own client throws their own body (the knock pattern of AbilityFX's AftershockKnock)
	  .LocalCast   { Skyrider = fn(role, character, ability) -> true }: THE PRESS, called by ZephyrClient.TryCast before
	               SpellshotInput's generic path. It always answers true (it took the press whole): the generic HELD
	               path would release on the key coming up, and this ride's release is its END. SpellshotInput's own
	               LOCAL_CAST order (character, role) is accepted too.
	  .Init(b)     (alias .Bind) SpellshotInput's gates { Flash, CanCast, AimPoint, BlockedByMovement }.
	  .Demo(character, opts)   the test harness: opts.Ride = true flies a real LOCAL ride (no server: no mana, no
	               damage, a gust at 3.1 s, the dismount at opts.Seconds or 7 s); otherwise THE SHOWCASE 1:1
	               (ZephyrFX_Skyrider.Demo: you ride the bird along the Blender flight with the reel's poses, timing and
	               hero camera; opts.Freeze = clip seconds). -> { Stop }
	  .IsActive() / .Interrupt(reason)   your ride owns your body / let go of it (a Cyclone pull, an Aftershock knock:
	               ZephyrClient forwards them; MovementController stands its air moves down while IsActive).

	THE PRESS (the Technique key; either slot may hold Skyrider, VFXLibrary.TechniqueSlot). Ready: alive, in the arena,
	no menu, not stunned (rooted / lifted, a zero speed cap, interrupted, staggered, entombed, burrowed), no dash under
	way, its cooldown over and the mana there (SpellshotInput's CanCast), not already held on the server. Then: the slot
	flashes, the cast goes to the server as a HELD press (CastRequest (slot, {})) -- SpellshotService pays ManaCost,
	sets Holding_<slot> and fires PerformCast { Phase = "Start" } at ZephyrSkyriderServer -- and the ride starts HERE at
	once (movement is the client's). No SkyriderStart back by max(DeniedWait, 2 x ping + 0.3): the ride is cut
	("Denied") and the slot flashes red.
	THE KEY AGAIN while riding: the GUST FLAP (SkyriderGust { Dir } on IceAbilityRemote; the server checks, pays
	Gust.ManaCost, broadcasts, and hits). Refused here (red flash) inside the summon, inside Gust.Cooldown of the last,
	or short of the mana.
	JUMP: the dismount. SkyriderEnd (reason) on IceAbilityRemote, then the held cast's release (CastRequest (slot,
	{ Release = true })), which starts the cooldown in SpellshotService. The server ends a ride on its own too (empty mana,
	MaxRide, death, a stun, leaving the arena, the speed check): its SkyriderEnd ends the motor here.

	THE MOTOR (your own client, while you ride; GustJumpMotor's arrangement: the client owns its body's physics).
	One Attachment on the HumanoidRootPart with a LinearVelocity (World, all three axes, ForcePerMass x the assembly's
	mass) and an AlignOrientation (OneAttachment), the Humanoid in PlatformStand (so MovementController's air moves,
	the double jump and the momentum keeper all stand down: canMoveInAir). Every Heartbeat:
	  SUMMON (0 .. SummonTime)  the body is lifted to the ride height, CruiseClearance over the ground (the bird gathers
	            under it), its speed along the ground eased from what it had into the flight's
	  FLIGHT    along the camera's look: FlySpeed, W BoostSpeed, S BrakeSpeed (the PlayerModule's move vector, so pads and
	            touch steer too), reached at Accel. THE HEIGHT: a look pitched inside PitchDeadDown..PitchDeadUp (where the
	            camera rests, looking down at you) flies level and HOLDS the height (HoldPull, at most HoldSpeed); past the
	            band the excess climbs or dives (clamped to PitchMin..PitchMax) and the height held is where it leaves you.
	            A/D bank-turn: the VIEW is
	            yawed at TurnRate (TurnRotatesCamera; a render step after the camera), so the bird and the crosshair
	            turn together -- or, with it off, the heading is carved off the look by up to TurnOffsetMax. The heading
	            swings toward the look at most HeadingRate rad/s, so a mouse flick banks rather than snaps. THE FLOOR
	            RULE: the bird's back never sinks under MinClearance over the highest ground under it or ahead along the
	            flight (sphere probes out to ClearAhead s, from ProbeUp over the root: a step up is climbed before it is
	            reached); a wall too tall for them, met within WallAhead s, is climbed at LiftSpeed and slid along when
	            close (WallSlide), never pushed into; a roof within HeadRoom stops every climb. BODIES never stop it: every
	            character in a box around and ahead of the rider is kept from touching it (NoCollisionConstraints on
	            this client, DashMotor's ThroughCharacters) until NoCollideLinger after the dismount. The root rolls RootBankShare into the turn and pitches RootPitchShare with the climb (the third-person
	            body leans). The gust stroke drags the flight (Gust.FlightDrag over Gust.DragTime: the push of the air).
	            A knock (SkyriderKnock) while riding is added on top and decays to its Until.
	  THE END   any of: Jump, the server's SkyriderEnd, MaxRide (the client's own backstop), death, a stun, a zone change,
	            a dash taking the body, Interrupt, a respawn. The movers go, PlatformStand is put back, the root is set
	            upright on its heading, the body DROPS with DropKeep of its speed along the ground (skyrider_bl's fall),
	            and the bird breaks into wisps. The server's echo of your own end is not drawn twice.

	THE BODY. Your own view: Viewmodel clips SkyriderMount (the forearms come to rest forward on the bird's neck, held),
	SkyriderGust (the left hand pulls back, thrusts at the target, both drop low so the cone reads, back to the brace),
	SkyriderWobble (the free hand thrown out for balance). Everyone else: CastPose clips of the same names (the hop, the
	one-knee kneel on the bird's back, the gust command, the balance catch). Both are held clips, let go at the end,
	where the body plays SkyriderFall (the showcase's fall: arms flung up, the landing crouch on the touchdown, the rise).
	Held two-arm clips keep the M1 off while riding (Viewmodel.IsPlaying): the hands are on the bird.

	EVERY NUMBER IS PROVISIONAL (v6 import). Nothing here has been seen in Play.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local isClient = RunService:IsClient()
local player = isClient and Players.LocalPlayer or nil

local ZephyrSkyrider = {}

----------------------------------------------------------------------------------------------------
-- TUNING (shared with ServerScriptService.ZephyrSkyriderServer)
----------------------------------------------------------------------------------------------------
-- The row (VFXLibrary, INTEGRATION): Cooldown 12, ManaCost 15, Held = true. Everything here: PROVISIONAL (v6 import).
ZephyrSkyrider.Tuning = {
	-- the press
	SummonTime = 0.44,          -- s: the bird gathers out of the air and the caster kneels on it; the flight starts here
	SeatBelowRoot = 2.4,        -- studs: the bird's back (the rider's kneel) under the HumanoidRootPart's centre
	DeniedWait = 0.6,           -- s (at least; 2 x ping + 0.3 if more): no SkyriderStart by then and the ride is cut

	-- the flight (the rider's own client)
	FlySpeed = 60, --[[42 until the 2026-10-17 balance pass]]              -- studs/s along the look -- PROVISIONAL (v6 import)
	BoostSpeed = 75, --[[55 until the 2026-10-17 balance pass]]            -- W -- PROVISIONAL (v6 import)
	BrakeSpeed = 24,            -- S -- PROVISIONAL (v6 import)
	Accel = 70,                 -- studs/s^2 toward the wanted speed
	PitchMin = -35,             -- degrees: the steepest dive ...
	PitchMax = 30,              -- ... and climb -- PROVISIONAL (v6 import)
	PitchDeadDown = -22,        -- degrees: the look's pitch inside this band flies LEVEL (the height is held). The
	PitchDeadUp = 8,            --   third-person camera rests looking down at the rider: read raw, that rest was a
	                            --   dive, and the playtest ride hugged the floor rule at MinClearance (2026-10-07)
	CruiseClearance = 9,        -- studs: the summon lifts the bird's back this far over the ground; the ride holds it
	HoldPull = 3,               -- 1/s: how hard the held height is kept ...
	HoldSpeed = 16,             -- ... at most this fast (studs/s): a hop over an obstacle settles back gently
	TurnRate = 1.8,             -- rad/s: A / D bank-turn -- PROVISIONAL (v6 import)
	TurnRotatesCamera = true,   -- A / D yaw the view (false: they carve the heading off the look instead)
	TurnOffsetMax = 0.45,       -- rad: that carve, when the view is not turned
	HeadingRate = 5.0,          -- rad/s the flight heading may swing toward the look
	MinClearance = 6,           -- studs: the bird's back over the ground under it (or ahead) -- PROVISIONAL (v6 import)
	ClearPull = 10,             -- 1/s: how hard the floor rule (and the summon) lifts
	ClearReach = 80,            -- studs of probe under the root
	ClearAhead = 0.6,           -- s: the floor probes look along the flight this far (at 0, 1/4, 3/5 and all of it)
	ClearRadius = 2,            -- studs: the probes are spheres (a thin ray slipped past a dummy's head and a post)
	ProbeUp = 24,               -- studs over the root the probes start: the tallest step they see to climb (never
	                            --   above a roof: an up-ray clips them)
	HeadRoom = 4,               -- studs: a roof this close over the root stops every climb
	WallRadius = 1.6,           -- studs: the sphere cast along the flight for a wall the probes cannot see over ...
	WallAhead = 0.3,            -- ... this far ahead (s of flight): seen, the bird climbs its face at LiftSpeed ...
	WallSlide = 3,              -- ... and this close (studs) it slides along it instead of pushing in
	LiftSpeed = 32,             -- studs/s: the most the summon, the floor rule or a wall climbs (the server allows it)
	PassWidth = 10,             -- studs: bodies inside this box around and ahead of the rider stop colliding with it
	PassHeight = 14,            --   (NoCollisionConstraints on this client, DashMotor's ThroughCharacters): the ride
	PassLead = 0.3,             --   flew INTO a training dummy and stuck there 4 s (2026-10-07). Lead: s of flight ahead
	NoCollideLinger = 0.6,      -- s after the dismount the bodies still pass (a drop out of one does not fling)
	RootPitchShare = 0.35,      -- the root pitches this share of the climb ...
	RootBankShare = 0.35,       -- ... and rolls this share of the bird's bank into the turn ...
	RootBankMax = 0.5,          -- ... at most this (rad)
	BankG = 28.6,               -- skyrider_bl's G (studs/s^2) in the bank: 1.15 atan(v w / G)
	ForcePerMass = 4000,        -- the movers' force, per unit of assembly mass (DashMotor's / GustJumpMotor's)
	AlignResponsiveness = 25,
	DropKeep = 0.6,             -- the dismount: this share of the speed along the ground is kept as the body drops
	DismountGrace = 0.3,        -- s after the press a jump does not dismount (a held jump from before)
	LatchAfterEnd = 0.3,        -- s after a ride ends the key cannot start another (its release is on its way)

	-- mana and time (the server)
	ManaPerSecond = 12,         -- drained through SpellshotService's SpendMana (the regen, 7/s, still runs) -- PROVISIONAL (v6 import)
	DrainInterval = 0.1,        -- s
	MaxRide = 10,               -- s from the press -- PROVISIONAL (v6 import)
	LowMana = 30,               -- the last 30 points of the bar: the bird thins (ZephyrFX_Skyrider reads the same)

	-- the server's checks
	SpeedSlack = 1.3,           -- the root's speed may reach |(BoostSpeed, LiftSpeed)| x this + SpeedPad ...
	SpeedPad = 12,
	OverSpeedTime = 0.5,        -- ... for this long before the ride is ended ("Speed")
	TimeSlack = 0.5,            -- s past MaxRide (+ 2 x ping) the server ends a ride the client did not
	HitGap = 0.2,               -- s: SkyriderHit (the wobble) is broadcast at most this often per rider

	-- THE GUST FLAP (the key again while riding)
	Gust = {
		WindUp = 0.2,           -- s: the wing-up wind-up (WINDUP), then the power stroke
		Stroke = 0.18,          -- s: the stroke (STROKE blends 0.03 .. 0.32 after the wind-up)
		Launch = 0.04,          -- s after the stroke the cone leaves the wings (skyrider_bl T_LAUNCH - T_STROKE)
		HalfAngle = 28,         -- degrees: the hit cone -- PROVISIONAL (v6 import)
		Range = 22,             -- studs ahead -- PROVISIONAL (v6 import)
		BodyPad = 1.5,          -- studs: a body this far outside the cone still counts (its width)
		Damage = 12,            -- PROVISIONAL (v6 import)
		KnockOut = 55,          -- studs/s away from the rider ... -- PROVISIONAL (v6 import)
		KnockUp = 20,           -- ... and up (Updraft's scale is NOT applied: not a passive hit) -- PROVISIONAL (v6 import)
		KnockTime = 0.25,       -- s the knock drives the body (the victim's own client; dummies on the server)
		KnockForcePerMass = 4000,
		ManaCost = 10,          -- PROVISIONAL (v6 import)
		Cooldown = 2.5,         -- s between flaps (internal) -- PROVISIONAL (v6 import)
		CooldownSlack = 0.15,   -- s the server allows a flap early (a late packet before an early one)
		FrontReach = 27,        -- studs: the cone's front, RF (1 - exp(-tau / FrontTau)) (skyrider_bl RF, TAU_F) --
		FrontTau = 0.24,        --   a body is hit when the front reaches it (~0.4 s at 22 studs)
		ApexAhead = 4.8,        -- studs: the cone's apex is the drawn bird's chest -- (6.0 + 0.2) x KS x BS ahead of
		ApexUp = -0.5,          --   the seat along the flight, (0.9 - 1.5) x 0.78 over it -- so the hits and the drawn
		                        --   front start from the same point (ZephyrFX_Skyrider's Look.Gust.Apex)
		FlightDrag = 0.35,      -- the stroke slows the flight this share (skyrider_bl VF: 21 -> 13.5) ...
		DragTime = 0.45,        -- ... over this long after the stroke (a sin^2 bump)
	},
}
local Tu = ZephyrSkyrider.Tuning

ZephyrSkyrider.Handlers = {}
ZephyrSkyrider.LocalCast = {}

local V3 = Vector3.new
local CLIPS = { SkyriderMount = true, SkyriderGust = true, SkyriderWobble = true, SkyriderFall = true }

----------------------------------------------------------------------------------------------------
-- modules, found lazily (client only; never at require)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrSkyrider] " .. tostring(msg))
end

local mods = {}
local function need(name)
	local m0 = mods[name]
	if m0 then return m0 end
	if m0 == false then return nil end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = (ice and ice:FindFirstChild(name)) or (spell and spell:FindFirstChild(name))
	if not m then return nil end                          -- not there yet: asked again next time
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" then
		mods[name] = mod
		return mod
	end
	mods[name] = false
	warnOnce("load:" .. name, name .. " failed to load: " .. tostring(mod))
	return nil
end

--- <module>.<fn>(...) guarded: a missing module or function, or an error in it, does nothing
local function call(modName, fn, ...)
	local M = need(modName)
	local f = M and M[fn]
	if type(f) ~= "function" then return nil end
	local ok, res = pcall(f, ...)
	if not ok then
		warnOnce(modName .. ":" .. fn, modName .. "." .. fn .. " failed: " .. tostring(res))
		return nil
	end
	return res
end

local function fx(fn, ...) return call("ZephyrFX_Skyrider", fn, ...) end

local function fxOpts(own, T0)
	return { Own = own, T0 = T0, SummonTime = Tu.SummonTime, WindUp = Tu.Gust.WindUp, SeatBelowRoot = Tu.SeatBelowRoot,
		GustHalfAngle = Tu.Gust.HalfAngle }                 -- (2026-10-19, audit P5E-09) the drawn cone = the hit cone
end

--- the third-person body clip on a character, guarded; Stop lets go only of OUR clip
local function pose(character, clip)
	call("CastPose", "Play", character, clip)
end
local function poseStop(character)
	local cur = call("CastPose", "CurrentClip", character)
	if cur and CLIPS[cur] then call("CastPose", "Stop", character) end
end
--- your own arms, guarded
local function arms(clip)
	call("Viewmodel", "Play", clip)
end
local function armsStop()
	local cur = call("Viewmodel", "CurrentClip")
	if cur and CLIPS[cur] then call("Viewmodel", "Stop") end
end

local function iceRemote()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	return ice and ice:FindFirstChild("IceAbilityRemote")
end
local function castRemote()
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	return spell and spell:FindFirstChild("CastRequest")
end
local function fire(remote, ...)
	if remote then
		local args = table.pack(...)
		pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
	end
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function ping()
	local p = 0
	if player then pcall(function() p = player:GetNetworkPing() end) end
	return p
end

----------------------------------------------------------------------------------------------------
-- SpellshotInput's gates
----------------------------------------------------------------------------------------------------
local gates = {}
function ZephyrSkyrider.Init(bindings)
	if not isClient then return end
	gates = type(bindings) == "table" and bindings or {}
end
ZephyrSkyrider.Bind = ZephyrSkyrider.Init

local function flash(role, denied)
	if type(gates.Flash) == "function" then pcall(gates.Flash, role, denied) end
end

----------------------------------------------------------------------------------------------------
-- the shared checks (the same rules the server reads)
----------------------------------------------------------------------------------------------------
--- the tighter of the two ability speed caps (MovementController / GustJumpMotor / the server read the same)
local function capOf(character)
	return math.min(character:GetAttribute("SpeedCapSlow") or math.huge, character:GetAttribute("SpeedCapUlt") or math.huge)
end

--- why this body may not fly right now, or nil: rooted or lifted, a zero speed cap, interrupted, staggered,
--- entombed, burrowed (shared by the motor, the press and ZephyrSkyriderServer)
function ZephyrSkyrider.Stunned(character, humanoid)
	if not (character and humanoid) then return "Gone" end
	if humanoid.JumpHeight <= 0 or capOf(character) <= 0 then return "Rooted" end
	if workspace:GetServerTimeNow() < (character:GetAttribute("InterruptedUntil") or 0) then return "Interrupted" end
	if character:GetAttribute("RX_Staggered") or character:GetAttribute("RX_Entombed") or character:GetAttribute("Burrowed") then
		return "Stunned"
	end
	return nil
end

--- the cone's front (studs from the apex) tau seconds after the launch, and its inverse (skyrider_bl cone_front / cone_tau)
function ZephyrSkyrider.ConeFront(tau)
	local G = Tu.Gust
	return G.FrontReach * (1 - math.exp(-math.max(0, tau) / G.FrontTau))
end
function ZephyrSkyrider.ConeTau(d)
	local G = Tu.Gust
	return -G.FrontTau * math.log(math.max(1e-4, 1 - d / G.FrontReach))
end

----------------------------------------------------------------------------------------------------
-- THE MOTOR (client: your own ride)
----------------------------------------------------------------------------------------------------
local ride = nil             -- the ride under way (see startRide)
local latchUntil = 0
local pressN, heardN = 0, 0
local controls = nil         -- the PlayerModule's controls (its move vector), found at the first ride

local function menusOpen()
	return player:GetAttribute("SettingsOpen") or player:GetAttribute("LoadoutOpen") or player:GetAttribute("QuickPlayOpen")
		or player:GetAttribute("ShopOpen")
		or player:GetAttribute("ReactionsOpen")   -- (2026-10-19, audit GA-20) the Reactions tablet is a menu too
end

local function slotOf(r)
	local V = need("VFXLibrary")
	local slot = V and type(V.TechniqueSlot) == "function" and V.TechniqueSlot(player, "Skyrider")
	return slot or (r and r.Role) or "Mobility"
end

local function dashing()
	local D = need("DashMotor")
	if D and type(D.IsActive) == "function" then
		local ok, on = pcall(D.IsActive)
		return ok and on == true
	end
	return false
end

--- the move vector: x = right, z = back (the PlayerModule's, so keys, pads and touch all steer); keys if it is not there
local function moveVector()
	if controls then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" then return v end
	end
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then z -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then z += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then x += 1 end
	return V3(x, 0, z)
end

local function findControls()
	if controls ~= nil then return end
	controls = false
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if not pm then controls = nil return end
	local ok, mod = pcall(require, pm)
	if ok and type(mod) == "table" and type(mod.GetControls) == "function" then
		local ok2, c = pcall(mod.GetControls, mod)
		if ok2 and c then controls = c end
	end
end

local function flat(v)
	return V3(v.X, 0, v.Z)
end

local function rayParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list + 1] = p.Character end
	end
	local V = need("VFXLibrary")
	local fxName = V and V.Config and V.Config.FXFolderName or "IceMagicFX"
	local fxf = workspace:FindFirstChild(fxName)
	if fxf then list[#list + 1] = fxf end
	if workspace.CurrentCamera then list[#list + 1] = workspace.CurrentCamera end
	if character and not table.find(list, character) then list[#list + 1] = character end
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true          -- a non-colliding prop is nothing to climb over, nor to land on
	return params
end

--- the character (a model with a Humanoid) that inst is part of, or nil (DashMotor's)
--- (2026-10-19, audit P6A-05) a model stamped WallOwner (Terra's Bulwark Wall, which carries a Humanoid) is a wall,
--- never a body: the ride is stopped by it and never no-collides it
local function characterOf(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			if model:GetAttribute("WallOwner") ~= nil then return nil end
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

--- BODIES NEVER STOP THE RIDE (DashMotor's ThroughCharacters): `model` stops touching this body -- one
--- NoCollisionConstraint between each of its parts and each of ours, made on this client only (it simulates its own
--- body). The ride flew into a training dummy and stuck there 4 s (2026-10-07): the motor pushed level into it forever.
local function passThrough(r, model)
	if model == r.Character or r.Passing[model] then return end
	r.Passing[model] = true
	for _, other in ipairs(model:GetDescendants()) do
		if other:IsA("BasePart") then
			for _, mine in ipairs(r.Mine) do
				local nc = Instance.new("NoCollisionConstraint")
				nc.Part0, nc.Part1 = mine, other
				nc.Parent = r.PassFolder
			end
		end
	end
end

--- every body about to be touched: a box from just behind the rider to PassLead s of its flight ahead
local function scanBodies(r, root, hv, dt)
	if not r.PassFolder then return end
	local hs = hv.Magnitude
	local dir = hs > 1 and hv / hs or r.Heading
	local ahead = hs * math.max(2 * dt, Tu.PassLead) + 4
	local box = CFrame.lookAt(root.Position, root.Position + dir) * CFrame.new(0, -1, -(ahead - 4) * 0.5)
	local ok, parts = pcall(workspace.GetPartBoundsInBox, workspace, box, V3(Tu.PassWidth, Tu.PassHeight, ahead + 4),
		r.ScanParams)
	if not ok then return end
	for _, part in ipairs(parts) do
		if not r.Seen[part] then
			r.Seen[part] = true                      -- the map's parts are asked once, not every frame
			local model = characterOf(part)
			if model then passThrough(r, model) end
		end
	end
end

local function startPassThrough(r)
	r.Passing, r.Mine, r.Seen = {}, {}, setmetatable({}, { __mode = "k" })
	-- EVERY part of this body, whatever its CanCollide reads (the Humanoid can make a limb collide)
	for _, part in ipairs(r.Character:GetDescendants()) do
		if part:IsA("BasePart") then r.Mine[#r.Mine + 1] = part end
	end
	local folder = Instance.new("Folder")
	folder.Name = "SkyriderPassThrough"
	folder.Parent = r.Root
	r.PassFolder = folder
	local sp = OverlapParams.new()
	sp.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { r.Character }
	local V = need("VFXLibrary")
	local fxf = workspace:FindFirstChild(V and V.Config and V.Config.FXFolderName or "IceMagicFX")
	if fxf then ex[#ex + 1] = fxf end
	sp.FilterDescendantsInstances = ex
	r.ScanParams = sp
end

--- the dismount: the bodies pass a little longer (a drop out of the middle of one is not flung), then collide again
local function releasePassThrough(r)
	local folder = r.PassFolder
	if not folder then return end
	r.PassFolder = nil
	task.delay(Tu.NoCollideLinger, function() pcall(function() folder:Destroy() end) end)
end

--- the highest ground the flight must clear: under the root and along the flight (0, 1/4, 3/5 and all of ClearAhead
--- s ahead), SPHERES dropped from ProbeUp over the root (clipped under a roof), so a step up is seen -- and climbed --
--- before it is reached. The old two thin rays (under the root, 0.35 s ahead) slipped past a dummy's head.
local AHEAD_SHARES = { 0, 0.25, 0.6, 1 }
local function groundAhead(r, pos, hv, roofY)
	local top = pos.Y + Tu.ProbeUp
	if roofY then top = math.min(top, roofY - Tu.ClearRadius - 0.1) end
	top = math.max(top, pos.Y)
	local best = nil
	for _, share in ipairs(AHEAD_SHARES) do
		local q = pos + hv * (Tu.ClearAhead * share)
		local hit = workspace:Spherecast(V3(q.X, top, q.Z), Tu.ClearRadius, V3(0, -(top - pos.Y) - Tu.ClearReach, 0),
			r.Params)
		if hit and (not best or hit.Position.Y > best) then best = hit.Position.Y end
	end
	return best
end

--- the first WALL along the flight within `len` (a sphere from the root), or nil. A character is never one (bodies are
--- passed through: its model joins the filter and the cast is made again); a floor-like face is the probes' business.
local function wallAhead(r, origin, dir, len)
	for _ = 1, 4 do
		local hit = workspace:Spherecast(origin, Tu.WallRadius, dir * len, r.WallParams)
		if not hit then return nil end
		local body = characterOf(hit.Instance)
		if not body then return (math.abs(hit.Normal.Y) < 0.7) and hit or nil end
		r.WallParams:AddToFilter(body)
	end
	return nil
end

--- THE DISMOUNT'S BODY (the showcase's FTRACK, CastPose.SkyriderFall): our held clip is let go, then FALL plays on a
--- clock that holds it while the body is in the air and runs the landing crouch and the rise from the touchdown, so any
--- drop height lands on its feet. Every client, on the rider's character (a ray under its root finds the floor).
local FALL_HOLD, FALL_LAND = 0.6, 0.875          -- clip s: FALL held here while airborne / the clip's touchdown
local function fallPose(character)
	poseStop(character)
	local root = character and character.Parent and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) then return end   -- a dead body falls as its death has it, not as a dismount
	local t0, landed = os.clock(), nil
	local params = rayParams(character)
	call("CastPose", "PlayClocked", character, "SkyriderFall", function()
		if landed then return FALL_LAND + (os.clock() - landed) end
		return math.min(os.clock() - t0, FALL_HOLD)
	end)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if not root.Parent or now - t0 > 6 or (landed and now - landed > 1.3) then
			conn:Disconnect()
			return
		end
		if not landed and now - t0 > 0.15 and workspace:Raycast(root.Position, V3(0, -3.6, 0), params) then
			landed = now
		end
	end)
end

local endRide                -- forward

--- the ride's frame (Heartbeat): every rule of THE MOTOR in the header
local function step(dt)
	local r = ride
	if not r then return end
	local c, hum, root = r.Character, r.Humanoid, r.Root
	if player.Character ~= c or not (c.Parent and root.Parent and hum.Parent) then endRide("CharacterChanged") return end
	if hum.Health <= 0 then endRide("Died") return end
	if player:GetAttribute("Zone") ~= r.Zone then endRide("Zone") return end
	local why = ZephyrSkyrider.Stunned(c, hum)
	if why then endRide(why) return end
	if dashing() then endRide("Dash") return end
	local now = os.clock()
	local t = now - r.Start
	if r.Demo then
		if not r.DemoGusted and t >= 3.1 then
			r.DemoGusted = true
			r.GustAt = now
			local cam = workspace.CurrentCamera
			fx("Gust", c, serverNow(), (cam and cam.CFrame.LookVector) or root.CFrame.LookVector)
			arms("SkyriderGust")
			pose(c, "SkyriderGust")
		end
		if t > r.DemoLength then endRide("Demo") return end
	elseif t > Tu.MaxRide then
		endRide("Timeout")                 -- the client's own backstop; the server ends it a little later anyway
		return
	end
	dt = math.clamp(dt, 0, 0.1)

	-- where the flight wants to go
	local cam = workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or root.CFrame.LookVector
	local mv = moveVector()
	r.TurnInput = math.clamp(mv.X, -1, 1)
	-- the climb: only the look's pitch PAST the level band (THE HEIGHT in the header), clamped
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	local lo, hi = math.rad(Tu.PitchDeadDown), math.rad(Tu.PitchDeadUp)
	local climb = 0
	if pitch < lo then climb = pitch - lo elseif pitch > hi then climb = pitch - hi end
	climb = math.clamp(climb, math.rad(Tu.PitchMin), math.rad(Tu.PitchMax))
	local want = flat(look)
	want = want.Magnitude > 1e-3 and want.Unit or r.Heading
	if not Tu.TurnRotatesCamera and math.abs(r.TurnInput) > 0.05 then
		want = CFrame.Angles(0, -r.TurnInput * Tu.TurnOffsetMax, 0):VectorToWorldSpace(want)
	end
	-- the heading swings toward it no faster than HeadingRate (a flick banks rather than snaps)
	local cross = r.Heading:Cross(want).Y
	local ang = math.atan2(cross, math.clamp(r.Heading:Dot(want), -1, 1))
	local turn = math.clamp(ang, -Tu.HeadingRate * dt, Tu.HeadingRate * dt)
	r.Heading = CFrame.Angles(0, turn, 0):VectorToWorldSpace(r.Heading)
	local omega = (dt > 0) and turn / dt or 0
	r.Omega += (omega - r.Omega) * (1 - math.exp(-dt / 0.12))
	-- the speed: cruise, boost, brake
	local target = Tu.FlySpeed
	if mv.Z < -0.3 then target = Tu.BoostSpeed elseif mv.Z > 0.3 then target = Tu.BrakeSpeed end
	local cap = capOf(c)
	if cap < target then target = math.max(Tu.BrakeSpeed * 0.5, cap) end
	r.Speed += math.clamp(target - r.Speed, -Tu.Accel * dt, Tu.Accel * dt)
	local speed = r.Speed
	-- the gust stroke pushes back on the flight (skyrider_bl's VF dips through the stroke)
	if r.GustAt then
		local G = Tu.Gust
		local u = now - r.GustAt - G.WindUp
		if u > 0 and u < G.DragTime then speed *= 1 - G.FlightDrag * math.sin(math.pi * u / G.DragTime) ^ 2 end
	end
	local S = Tu.SummonTime
	local pos = root.Position
	local summoning = t < S
	-- along the ground: the heading at the speed (less what a climb or dive takes)
	local hv = r.Heading * (speed * math.cos(climb))
	-- up and down: past the band the look climbs or dives (and the height held follows you); inside it the height is
	-- HELD. The summon lifts to that height quickly (ClearPull) whatever the look
	local vy
	if climb ~= 0 and not summoning then
		vy = speed * math.sin(climb)
		r.HoldY = pos.Y
	elseif summoning then
		vy = math.clamp((r.HoldY - pos.Y) * Tu.ClearPull, -Tu.LiftSpeed, Tu.LiftSpeed)
	else
		vy = math.clamp((r.HoldY - pos.Y) * Tu.HoldPull, -Tu.HoldSpeed, Tu.HoldSpeed)
	end
	-- the summon: the speed along the ground eased in from what the body had
	if summoning then
		local e = math.clamp(t / S, 0, 1)
		e = e * e * (3 - 2 * e)
		hv = r.EntryFlat:Lerp(hv, e)
	end
	-- a roof close over the root: no climbing into it, and no height held above it
	local roof = workspace:Raycast(pos, V3(0, Tu.ProbeUp, 0), r.Params)
	local roofY = roof and roof.Position.Y or nil
	local capped = roofY ~= nil and roofY - pos.Y < Tu.HeadRoom
	if capped then r.HoldY = math.min(r.HoldY, pos.Y) end
	-- THE FLOOR RULE: the bird's back never under MinClearance over the highest ground under it or ahead
	local groundY = groundAhead(r, pos, hv, roofY)
	if groundY then
		local rideY = groundY + Tu.MinClearance + Tu.SeatBelowRoot
		if pos.Y < rideY then vy = math.max(vy, math.min(Tu.LiftSpeed, (rideY - pos.Y) * Tu.ClearPull)) end
	end
	-- a wall too tall for the probes: climb its face, and close to it slide along it rather than push in and stop
	local hs = hv.Magnitude
	if hs > 1 then
		local wall = wallAhead(r, pos, hv / hs, math.max(Tu.WallSlide, hs * Tu.WallAhead))
		if wall then
			vy = math.max(vy, Tu.LiftSpeed)
			local n = flat(wall.Normal)
			if wall.Distance < Tu.WallSlide and n.Magnitude > 1e-3 then
				n = n.Unit
				local into = hv:Dot(n)
				if into < 0 then hv -= n * into end
			end
		end
	end
	if capped then vy = math.min(vy, 0) end
	-- bodies in the way are passed through, never pushed against (passThrough)
	scanBodies(r, root, hv, dt)
	local vel = V3(hv.X, vy, hv.Z)
	-- a knock while riding rides on top, fading to its Until
	local k = r.Knock
	if k then
		local left = k.Until - serverNow()
		if left <= 0 then
			r.Knock = nil
		else
			vel += k.V * math.clamp(left / math.max(0.05, k.Span), 0, 1)
		end
	end
	if r.Mover then
		local force = root.AssemblyMass * Tu.ForcePerMass
		r.Mover.MaxAxesForce = V3(force, force, force)
		r.Mover.VectorVelocity = vel
	end
	-- the body: the heading, a share of the climb and of the bank (the third-person rider leans with the bird)
	if r.Align then
		local bank = Tu.RootBankShare * 1.15 * math.atan(speed * r.Omega / Tu.BankG)
		bank = math.clamp(bank, -Tu.RootBankMax, Tu.RootBankMax)
		local path = math.clamp(math.atan2(vy, math.max(hv.Magnitude, 1)), math.rad(Tu.PitchMin), math.rad(Tu.PitchMax))
		r.Align.CFrame = CFrame.lookAt(Vector3.zero, r.Heading) * CFrame.Angles(path * Tu.RootPitchShare, 0, 0)
			* CFrame.Angles(0, 0, bank)
	end
end

--- A / D yaw the view (TurnRotatesCamera): after the camera has solved, so the camera module carries it on
local function turnStep(dt)
	local r = ride
	if not r or not Tu.TurnRotatesCamera then return end
	local x = r.TurnInput or 0
	if math.abs(x) < 0.05 or os.clock() - r.Start < Tu.SummonTime then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cf = cam.CFrame
	cam.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, -x * Tu.TurnRate * math.clamp(dt, 0, 0.1), 0) * cf.Rotation
end

local TURN_STEP = "ZephyrSkyriderTurn"

local function cleanup(r)
	for _, conn in ipairs(r.Conns) do pcall(function() conn:Disconnect() end) end
	r.Conns = {}
	if r.TurnBound then
		pcall(function() RunService:UnbindFromRenderStep(TURN_STEP) end)
		r.TurnBound = false
	end
	if r.Attachment then pcall(function() r.Attachment:Destroy() end) end
	r.Attachment, r.Mover, r.Align = nil, nil, nil
	releasePassThrough(r)
	local hum, root = r.Humanoid, r.Root
	-- upright on the heading: the ride left the root pitched and banked, and a body let go tilted lands tilted
	if root and root.Parent and hum and hum.Health > 0 then
		local h = r.Heading
		pcall(function() root.CFrame = CFrame.lookAt(root.Position, root.Position + h) end)
	end
	if r.SetPlatformStand and hum and hum.Parent then
		pcall(function() hum.PlatformStand = false end)
		if hum.Health > 0 then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end) end
	end
end

--- THE END of your own ride (see THE MOTOR). fromServer: the server's SkyriderEnd (nothing is sent back).
endRide = function(reason, fromServer, T0)
	local r = ride
	if not r then return end
	ride = nil
	latchUntil = os.clock() + Tu.LatchAfterEnd
	cleanup(r)
	local root, hum = r.Root, r.Humanoid
	-- the drop: the body keeps a share of the flight's speed along the ground and falls
	if root and root.Parent and hum and hum.Health > 0 then
		local v = root.AssemblyLinearVelocity
		pcall(function() root.AssemblyLinearVelocity = V3(v.X * Tu.DropKeep, math.min(v.Y, 6), v.Z * Tu.DropKeep) end)
	end
	if not fromServer and not r.Demo and reason ~= "Denied" then
		fire(iceRemote(), "SkyriderEnd", tostring(reason))
		fire(castRemote(), slotOf(r), { Release = true })        -- the held cast's release: the cooldown starts
	end
	fx("End", r.Character, tonumber(T0) or serverNow(), reason)
	armsStop()
	fallPose(r.Character)
end

--- the ride starts HERE (the press, or the demo): movers on, the bird, the arms
local function startRide(character, role, T0, demo, demoLength)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then return nil end
	findControls()
	local look = flat(root.CFrame.LookVector)
	local cam = workspace.CurrentCamera
	if cam then
		local cl = flat(cam.CFrame.LookVector)
		if cl.Magnitude > 1e-3 then look = cl end
	end
	look = look.Magnitude > 1e-3 and look.Unit or V3(0, 0, -1)
	local v = root.AssemblyLinearVelocity
	-- the speed the ride eases in from, never above BoostSpeed: a ride started out of a knock or a fast fall began over
	-- the server's speed check
	local entry = flat(v)
	if entry.Magnitude > Tu.BoostSpeed then entry = entry.Unit * Tu.BoostSpeed end
	pressN += 1
	local r = {
		Character = character, Humanoid = hum, Root = root, Role = role, T0 = T0, Start = os.clock(),
		Zone = player:GetAttribute("Zone"), Heading = look, Omega = 0,
		Speed = math.clamp(entry.Magnitude, Tu.BrakeSpeed, Tu.BoostSpeed),
		EntryFlat = entry, LastGust = -math.huge, Press = pressN, Demo = demo == true, DemoLength = demoLength or 7,
		Conns = {}, TurnInput = 0, Params = rayParams(character), WallParams = rayParams(character),
	}
	-- the height the ride holds: CruiseClearance over the ground under you (or where you are, if higher), under a roof
	local pos = root.Position
	r.HoldY = pos.Y
	local below = workspace:Raycast(pos, V3(0, -Tu.ClearReach, 0), r.Params)
	if below then r.HoldY = math.max(pos.Y, below.Position.Y + Tu.CruiseClearance + Tu.SeatBelowRoot) end
	local roof = workspace:Raycast(pos, V3(0, Tu.ProbeUp, 0), r.Params)
	if roof then r.HoldY = math.min(r.HoldY, math.max(pos.Y, roof.Position.Y - Tu.HeadRoom)) end
	ride = r
	startPassThrough(r)
	-- the movers (the client owns its body: GustJumpMotor's arrangement)
	local att = Instance.new("Attachment")
	att.Name = "SkyriderMotor"
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SkyriderMotor"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.ForceLimitsEnabled = true
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * Tu.ForcePerMass
	lv.MaxAxesForce = V3(force, force, force)
	lv.VectorVelocity = v
	lv.Parent = att
	local ao = Instance.new("AlignOrientation")
	ao.Name = "SkyriderMotor"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = false
	ao.MaxTorque = math.huge
	ao.Responsiveness = Tu.AlignResponsiveness
	ao.CFrame = CFrame.lookAt(Vector3.zero, look)
	ao.Parent = att
	att.Parent = root
	r.Attachment, r.Mover, r.Align = att, lv, ao
	if not hum.PlatformStand then
		hum.PlatformStand = true
		r.SetPlatformStand = true
	end
	table.insert(r.Conns, RunService.Heartbeat:Connect(step))
	pcall(function() RunService:UnbindFromRenderStep(TURN_STEP) end)   -- never two (an earlier ride's, if its unbind failed)
	local okBind = pcall(function()
		RunService:BindToRenderStep(TURN_STEP, Enum.RenderPriority.Camera.Value + 1, turnStep)
	end)
	r.TurnBound = okBind
	-- JUMP: the dismount (the touch button, keys and pads all raise JumpRequest)
	table.insert(r.Conns, UserInputService.JumpRequest:Connect(function()
		if ride == r and os.clock() - r.Start > Tu.DismountGrace then endRide("Jump") end
	end))
	table.insert(r.Conns, player.CharacterRemoving:Connect(function()
		if ride == r then endRide("CharacterChanged") end
	end))
	-- the look: your own bird (own-view rules), the arms on the bird's neck, the body's kneel
	fx("Start", character, fxOpts(true, T0))
	arms("SkyriderMount")
	pose(character, "SkyriderMount")
	return r
end

--- READY (see THE PRESS): every one of these, or the key only flashes the slot red
local function ready(role, character, ability)
	if os.clock() < latchUntil or not character or player.Character ~= character then return false end
	if player:GetAttribute("Zone") == "Hub" or menusOpen() then return false end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return false end
	if ZephyrSkyrider.Stunned(character, hum) or dashing() then return false end
	if character:GetAttribute("Holding_" .. role) then return false end
	if type(gates.BlockedByMovement) == "function" then
		local ok, blocked = pcall(gates.BlockedByMovement, role, character)
		if ok and blocked then return false end
	end
	if type(gates.CanCast) == "function" then
		local ok, can = pcall(gates.CanCast, role, character)
		if ok then return can == true end
	end
	-- no gates (SpellshotInput not bound yet): its own two checks, the cooldown and the mana
	if workspace:GetServerTimeNow() < (character:GetAttribute("CD_" .. role) or 0) then return false end
	return (character:GetAttribute("Mana") or 0) >= ((ability and ability.ManaCost) or 0)
end

--- THE KEY AGAIN while riding: the gust flap
local function tryGust(role)
	local r = ride
	local G = Tu.Gust
	local now = os.clock()
	local c = r.Character
	if now - r.Start < Tu.SummonTime or now - r.LastGust < G.Cooldown
		or (c:GetAttribute("Mana") or 0) < G.ManaCost then
		flash(role, true)
		return
	end
	local cam = workspace.CurrentCamera
	local dir = (cam and cam.CFrame.LookVector) or r.Root.CFrame.LookVector
	r.LastGust, r.GustAt = now, now
	flash(role, false)
	fire(iceRemote(), "SkyriderGust", { Dir = dir })
	fx("Gust", c, serverNow(), dir)
	arms("SkyriderGust")
	pose(c, "SkyriderGust")
end

--- THE PRESS (ZephyrClient.TryCast): always true -- the press is this module's whole
ZephyrSkyrider.LocalCast.Skyrider = function(a, b, c)
	if not isClient then return false end
	-- (role, character, ability), or SpellshotInput's LOCAL_CAST order (character, role)
	local role, character, ability = a, b, c
	if typeof(a) == "Instance" then role, character = b, a end
	if type(role) ~= "string" then role = "Mobility" end
	if type(ability) ~= "table" then
		local V = need("VFXLibrary")
		ability = V and V.AbilityById and V.AbilityById.Skyrider or nil
	end
	if ride then
		if ride.Character == character and not ride.Demo then tryGust(role) else flash(role, true) end
		return true
	end
	if not ready(role, character, ability) then
		flash(role, true)
		return true
	end
	flash(role, false)
	local T0 = serverNow()
	fire(castRemote(), role, {})                 -- the HELD press: SpellshotService pays, ZephyrSkyriderServer starts
	local r = startRide(character, role, T0, false)
	if not r then return true end
	-- no answer (SkyriderStart) by the wait: the server turned the press away -- the ride is cut and the slot flashes
	local press = r.Press
	task.delay(math.max(Tu.DeniedWait, 2 * ping() + 0.3), function()
		if ride == r and r.Press == press and heardN < press then
			endRide("Denied")
			flash(role, true)
		end
	end)
	return true
end

--- your ride owns your body (MovementController stands down; ZephyrClient.IsActive)
function ZephyrSkyrider.IsActive()
	return ride ~= nil
end

--- something else takes your body (a Cyclone pull, an Aftershock knock): the ride ends, as a dismount
function ZephyrSkyrider.Interrupt(reason)
	if ride then endRide(type(reason) == "string" and reason or "Interrupted") end
end

----------------------------------------------------------------------------------------------------
-- HANDLERS (every client, from AbilityFX)
----------------------------------------------------------------------------------------------------
local function own(character)
	return player ~= nil and character == player.Character
end

ZephyrSkyrider.Handlers.SkyriderStart = function(d)
	local c = d.Caster
	if typeof(c) ~= "Instance" then return end
	if own(c) then
		if ride and ride.Character == c then
			heardN = math.max(heardN, ride.Press)                -- the press was taken: no denial
			return
		end
		-- the server started a ride this body is not flying (the press was given up here first): end it there too
		fire(iceRemote(), "SkyriderEnd", "Stale")
		fire(castRemote(), slotOf(nil), { Release = true })
		return
	end
	fx("Start", c, fxOpts(false, d.T0))
	pose(c, "SkyriderMount")
end

ZephyrSkyrider.Handlers.SkyriderGust = function(d)
	local c = d.Caster
	if typeof(c) ~= "Instance" or typeof(d.Dir) ~= "Vector3" then return end
	if own(c) and ride and ride.GustAt and os.clock() - ride.GustAt < 1.0 then return end   -- drawn on the press already
	fx("Gust", c, d.T0, d.Dir)
	if not own(c) then pose(c, "SkyriderGust") end
end

ZephyrSkyrider.Handlers.SkyriderGustHit = function(d)
	local c = d.Caster
	if typeof(c) ~= "Instance" or typeof(d.At) ~= "Vector3" then return end
	fx("GustHit", c, d.Victim, d.At, d.T0)
end

ZephyrSkyrider.Handlers.SkyriderHit = function(d)
	local c = d.Caster
	if typeof(c) ~= "Instance" then return end
	fx("Hit", c, d.At, d.T0)
	pose(c, "SkyriderWobble")
	if own(c) and ride then arms("SkyriderWobble") end
end

ZephyrSkyrider.Handlers.SkyriderEnd = function(d)
	local c = d.Caster
	if typeof(c) ~= "Instance" then return end
	if own(c) and ride and ride.Character == c and not ride.Demo then
		endRide(type(d.Reason) == "string" and d.Reason or "Server", true, d.T0)
		return
	end
	-- your own body with no ride here: the echo of the end you made yourself (drawn then: a second fallPose restarted
	-- the fall mid-air), or a server ride this client never flew (a Stale one: no bird to break)
	if own(c) and not ride then return end
	fx("End", c, d.T0, d.Reason)
	fallPose(c)
end

--- STRUCK by a gust (sent to you alone): your own client throws your own body -- AbilityFX's AftershockKnock pattern
--- (a LinearVelocity on the root driving the server's Velocity until its Until, then the throw carries on under the
--- body's own physics; a newer knock replaces an older one). Riding, it rides on top of the flight instead.
local knocked = nil
local function dropKnock()
	local k = knocked
	if not k then return end
	knocked = nil
	pcall(function() k.Conn:Disconnect() end)
	pcall(function() k.Attachment:Destroy() end)
end

ZephyrSkyrider.Handlers.SkyriderKnock = function(d)
	if not player then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local v = d.Velocity
	if not (root and humanoid and humanoid.Health > 0 and typeof(v) == "Vector3" and v == v and v.Magnitude <= 500
		and type(d.Until) == "number" and d.Until == d.Until) then
		return
	end
	if ride and ride.Character == character then
		ride.Knock = { V = v, Until = d.Until, Span = math.max(0.05, d.Until - serverNow()) }
		return
	end
	dropKnock()
	local D = need("DashMotor")
	if D and type(D.IsActive) == "function" and type(D.Cancel) == "function" then
		local ok, on = pcall(D.IsActive)
		if ok and on then pcall(D.Cancel, "SkyriderGust") end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SkyriderKnockAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "SkyriderKnock"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * Tu.Gust.KnockForcePerMass
	mover.MaxAxesForce = V3(force, force, force)
	mover.VectorVelocity = v
	mover.Parent = attachment
	attachment.Parent = root
	local k = { Attachment = attachment }
	knocked = k
	k.Conn = RunService.Heartbeat:Connect(function()
		if knocked ~= k then return end
		if player.Character ~= character or not root.Parent or humanoid.Health <= 0 or serverNow() > d.Until then
			dropKnock()
		end
	end)
	-- your own screen's Knockback pulse (StatusReactions), as AftershockKnock reports it
	local R = _G.SpellshotReactions
	if type(R) == "table" and type(R.Pulse) == "function" then pcall(R.Pulse, "Knockback") end
end

----------------------------------------------------------------------------------------------------
-- DEMO (the test harness)
----------------------------------------------------------------------------------------------------
--- opts.Ride = true: a real LOCAL ride for opts.Seconds (default 7), no server (nothing paid, nothing hit), a gust at
--- 3.1 s. Otherwise the bird's showcase (ZephyrFX_Skyrider.Demo; opts.Freeze = clip seconds). -> { Stop }
function ZephyrSkyrider.Demo(character, opts)
	if not isClient then return nil end
	opts = type(opts) == "table" and opts or {}
	if opts.Ride and not opts.Freeze then
		if ride then endRide("Demo") end
		if not (character and character:FindFirstChild("HumanoidRootPart")) then return nil end
		local r = startRide(character, "Mobility", serverNow(), true, tonumber(opts.Seconds) or 7)
		if not r then return nil end
		return { Stop = function() if ride == r then endRide("Demo") end end }
	end
	local F = need("ZephyrFX_Skyrider")
	if not (F and type(F.Demo) == "function") then return nil end
	return F.Demo(character, opts)
end

return ZephyrSkyrider
