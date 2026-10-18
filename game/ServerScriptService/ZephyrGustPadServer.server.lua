--[[
	ZephyrGustPadServer  (Script)  ->  ServerScriptService/ZephyrGustPadServer          Zephyr v6 import, 2026-10-06

	The gameplay of GUST PAD, the Technique pool's Defense half (it REPLACES Deflect Gust, whose cast path ZephyrHandler
	loses in the same import). ReplicatedStorage.IceMagic.ZephyrGustPad draws it on every client and holds every number
	(.Tuning, shared). EVERY NUMBER IS PROVISIONAL (v6 import) -- the plan's figures, nothing measured in Play yet.

	WHERE THE PRESS COMES FROM. A Technique: the row (VFXLibrary, INTEGRATION's) is a plain cooldown cast -- Cooldown 14,
	ManaCost 20, Targeted (SpellshotInput's generic path sends { Target = aimPoint(Range) }), Range 40, Precheck. Either
	Technique slot may hold it (VFXLibrary.AbilityFor), so the role that arrives is whichever slot that is.
	  PRECHECK    SpellshotService asks Precheck_GustPad (a BindableFunction this script parents in ReplicatedStorage.
	              Spellshot -- Detonate's and Aftershock's arrangement) BEFORE it charges anything: true only for a living
	              caster whose aimed spot has a floor. The spot: the aimed point pulled in to Range (+ RangeSlack) from the
	              root, then a ray straight down from FloorUp over it, through every body, FloorDrop deep (Cyclone's
	              groundUnder rule); a floor steeper than MinFloorUp is no floor. No floor = refused in silence, at no cost.
	  THE CAST    PerformCast, for the Id GustPad only (the ZephyrHandler pattern). The spot is found again (the same rule;
	              a row without Precheck that lands here with no floor is GIVEN BACK -- mana and cooldown, GiveBack), the
	              caster's previous pad ends ("Replaced": one pad per caster), and the new pad is announced:
	                GustPad { Caster (character), Position (the floor point), T0, Life, Pad (id), Radius }.

	THE PAD. Armed ArmTime (0.26, the look's bloom) after the press, for Life (10) seconds from it.
	  A STEP      any body -- the caster, allies, enemies, training and ally dummies -- whose root is within Radius (3.4)
	              of the centre, flat, with its FEET between StepBelow under and StepAbove (3) over the pad's floor. (The
	              plan's "less than 3 studs over the pad" is read at the feet: a standing R15 root is 3.0 over its floor,
	              so a root rule would sit exactly on the line.) It is COILED: GustPadStep { Pad, Character, T0, At }
	              goes out (the step ripple and the pull-in), and the launch comes Coil (0.26) later, At. Players must be
	              in the caster's Zone and party (CombatCore.SameParty: maps are shared by several matches); Bulwark
	              Walls, Decoy Doubles and a Skyrider's rider (Holding_<slot> = "Skyrider", on the bird) are never taken.
	  THE LAUNCH  At At, a body still within Radius + CoilSlack (a dash out of the coil escapes it) is thrown STRAIGHT UP
	              at GustPad.LaunchSpeed() -- the speed that tops out at ApexHeight (19 studs) at workspace.Gravity --
	              its horizontal velocity cut to GustPad.KeptFlat (a third, at most MaxFlat 8 studs/s):
	                a PLAYER   is sent GustPadKnock { Pad, Speed, Hold, T0 } alone -- their own client throws their own
	                           body (the existing knock pattern: TerraHandler's AftershockKnock, AquaHandler's AquaKnock,
	                           ZephyrHandler's CyclonePull; the client half is ZephyrGustPad.Handlers.GustPadKnock);
	                a dummy the server simulates   takes a Line LinearVelocity here for GrabTime (TerraHandler's moveDummy,
	                           vertical only);
	                an anchored range dummy        is carried up its flight arc by its pivot and put back where it stood
	                           (TerraHandler's / AquaHandler's carryDummy).
	              Then GustPadLaunch { Pad, Character, T0 } to everyone (the column). No damage: a launch is not a hit.
	  LIMITS      each body is locked out of THIS pad from its step until Lockout (1.0 s) after its LANDING (the launch
	              plus GustPad.FlightTime: a lockout from the launch ran out in mid-air and did nothing); a pad gives
	              at most MaxLaunches (8): then it is spent ("Spent"). A step that escaped its coil gives its launch back.
	  THE END     GustPadEnd { Pad, Reason, T0 }: "Expired" (its Life, once no launch is still coiled), "Replaced", "Spent",
	              "Clear" (CombatCore.ClearPlayer: the arena left, a duel round reset), "Left" (the game). A coiled launch
	              dies with its pad, except a spent pad's, which only ends once its last launch is thrown. The caster
	              dying does NOT end it: a pad pressed into the floor stays there for its life.

	THE NUMBERS AT THIS PLACE'S GRAVITY (fixed 2026-10-07). The import's fixed LaunchSpeed 85 at this place's Gravity 64
	rose ~56 studs and hung ~2.7 s: the real-cast playtest threw its caster ~60 up and ~95 on (a held W kept a sprint's
	pace through the hang). Now the apex is the number (ApexHeight 19, the showcase's ~4 body heights: ~46 studs/s and
	~1.6 s of flight here) and the flat speed is cut at the launch (and held through a player's rise, client side).

	Server -> client: ("VFX", kind, data) on IceAbilityRemote (CombatCore.Broadcast; GustPadKnock to one player).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local GustPad = require(iceFolder:WaitForChild("ZephyrGustPad"))
local performCast = spellFolder:WaitForChild("PerformCast")
local Core = require(script.Parent:WaitForChild("CombatCore"))

local T = GustPad.Tuning
local remote = Core.Remote
local broadcast = Core.Broadcast
local ABILITY = VFXLibrary.AbilityById

local ID = "GustPad"
local SLOTS = { "Mobility", "Defense" }

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function tell(player, kind, data)
	pcall(function() remote:FireClient(player, "VFX", kind, data) end)
end

local function range()
	local row = ABILITY[ID]
	return (row and type(row.Range) == "number" and row.Range) or T.Range
end

--- How far a body's feet are under its root: HipHeight plus half the root (TerraHandler's feetUnderRoot). An R6 body's
--- HipHeight is 0 (its legs hang below the root, 2 studs long).
local function feetUnderRoot(root, humanoid)
	local legs = humanoid and (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight) or 2
	return root.Size.Y / 2 + legs
end

--- The floor under `point`: straight down from FloorUp over it, FloorDrop deep, THROUGH every body (a spot aimed at an
--- enemy is the floor round their feet) and the FX folder. Returns the RaycastResult, or nil over a drop.
local function floorUnder(point)
	local list = {}
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list + 1] = p.Character end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = list
	for _ = 1, 8 do
		local hit = workspace:Raycast(point + Vector3.new(0, T.FloorUp, 0), Vector3.new(0, -(T.FloorUp + T.FloorDrop), 0),
			params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit end
		params:AddToFilter(model)
	end
	return nil
end

--- The pad's spot for a press aimed at `target` from `root`, or nil (no floor there: refused).
local function spotFor(root, target)
	if not Core.ValidVector(target) then return nil end
	local p = Core.ClampTarget(root, target, range() + T.RangeSlack)
	local hit = floorUnder(p)
	if not hit or hit.Normal.Y < T.MinFloorUp then return nil end
	return hit.Position
end

-- The launch is sized by its APEX (Tuning.ApexHeight at workspace.Gravity: ZephyrGustPad.LaunchSpeed), never a fixed
-- studs/s -- the v6 import's 85 studs/s at this place's Gravity 64 threw bodies ~56 studs up (2026-10-07 playtest).
local launchSpeed = GustPad.LaunchSpeed

----------------------------------------------------------------------------------------------------
-- moving dummies (the server's own bodies)
----------------------------------------------------------------------------------------------------
--- A dummy the server simulates: straight up at `speed`, its horizontal velocity cut to KeptFlat (a third, at most MaxFlat:
--- a pop, not a fling -- a dummy has no air steering, so the cut at the launch is all it needs), held for `seconds` by
--- a Line LinearVelocity (TerraHandler's moveDummy, vertical only), then physics carries it.
local function serverOwned(root)
	if root.Anchored then return false end
	local ok, owner = pcall(function() return root:GetNetworkOwner() end)
	return ok and owner == nil
end

local function launchDummy(root, speed, seconds)
	local attachment = Instance.new("Attachment")
	attachment.Name = "GustPadLaunchAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "GustPadLaunch"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	mover.LineDirection = Vector3.new(0, 1, 0)
	mover.LineVelocity = speed
	mover.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	mover.MaxForce = root.AssemblyMass * T.KnockForcePerMass
	mover.Parent = attachment
	attachment.Parent = root
	root.AssemblyLinearVelocity = GustPad.KeptFlat(root.AssemblyLinearVelocity) + Vector3.new(0, speed, 0)
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Freefall) end   -- off its floor hold
	task.delay(seconds, function() attachment:Destroy() end)
end

--- A range dummy (Anchored): flown along `path(t)` (an offset from where it stood) for `seconds`, then put back where it
--- stood `back` seconds later (TerraHandler's carryDummy, copied: it is local there).
local carried = setmetatable({}, { __mode = "k" })
local function carryDummy(model, path, seconds, back)
	if carried[model] then return end
	local home = model:GetPivot()
	carried[model] = true
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if not model.Parent then
			conn:Disconnect()
			carried[model] = nil
			return
		end
		if t >= seconds + back then
			conn:Disconnect()
			model:PivotTo(home)
			carried[model] = nil
			return
		end
		model:PivotTo(home + path(math.min(t, seconds)))
	end)
end

----------------------------------------------------------------------------------------------------
-- the pads
----------------------------------------------------------------------------------------------------
local pads = {}           -- [player] = pad: { Id, Player, Character, At, T0, ArmAt, EndAt, Radius, Committed, Launched,
                          --   Lock = {[model] = server time}, Pending = {[model] = launch server time}, ScanAt }
local nextId = 0

local function endPad(player, reason)
	local pad = pads[player]
	if not pad then return end
	pads[player] = nil
	broadcast("GustPadEnd", { Pad = pad.Id, Reason = reason, T0 = workspace:GetServerTimeNow() })
end

--- Whether `model` may be taken by `pad` at all (not whether it is on it).
local function eligible(pad, model, humanoid)
	if Core.IsWall(model) or model:GetAttribute("DecoyOwner") ~= nil then return false end
	for _, slot in ipairs(SLOTS) do
		if model:GetAttribute("Holding_" .. slot) == "Skyrider" then return false end   -- on the bird: not on the floor
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		local caster = pad.Player
		if victim:GetAttribute("Zone") == "Hub" then return false end
		if victim ~= caster then
			if victim:GetAttribute("Zone") ~= caster:GetAttribute("Zone") then return false end
			if not Core.SameParty(caster, victim) then return false end
			-- a teammate in a team match is left alone (2026-10-18, team mode): teammates put no CC on each other, and this
			-- check is SameParty's, not Core.IsFriendly's, so Config.MayHurt's teammate rule does not reach it on its own
			local team = caster:GetAttribute("MatchTeam")
			if team ~= nil and victim:GetAttribute("MatchTeam") == team then return false end
		end
	end
	return humanoid.Health > 0
end

--- The flat distance of `root` from the pad's centre and the height of its feet over the pad's floor.
local function where(pad, root, humanoid)
	local d = root.Position - pad.At
	local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
	local feet = root.Position.Y - feetUnderRoot(root, humanoid) - pad.At.Y
	return flat, feet
end

--- A body stepped on: it is coiled toward a launch Coil from now.
local function commitStep(pad, model, now)
	local at = now + T.Coil
	pad.Committed += 1
	pad.Pending[model] = at
	pad.Lock[model] = at + T.Lockout
	broadcast("GustPadStep", { Pad = pad.Id, Character = model, T0 = now, At = at })
end

--- The coil lets go: throw `model` straight up, if it is still there.
local function launch(pad, model, now)
	local humanoid = model.Parent and model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and eligible(pad, model, humanoid)) then
		pad.Committed -= 1                                 -- gone: its launch goes back to the pad
		return
	end
	local flat, feet = where(pad, root, humanoid)
	if flat > pad.Radius + T.CoilSlack or feet < -T.StepBelow - T.CoilSlack or feet > T.StepAbove + T.CoilSlack then
		pad.Committed -= 1                                 -- escaped the coil (a dash out of it)
		return
	end
	local speed = launchSpeed()
	local hold = T.GrabTime
	local flight = GustPad.FlightTime(speed)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		-- Hold, not a server-clock Until: the client times it from its own receipt (an Until had passed a ping ago)
		tell(victim, "GustPadKnock", { Pad = pad.Id, Speed = speed, Hold = hold, T0 = now })
	elseif serverOwned(root) then
		launchDummy(root, speed, hold)
	elseif root.Anchored then
		-- a range dummy: flown up the same arc a body flies (the grab, then the coast to ApexHeight and the fall) and put
		-- back where it stood
		local g = workspace.Gravity
		carryDummy(model, function(t)
			local y = speed * math.min(t, hold)
			if t > hold then
				local u = t - hold
				y += speed * u - 0.5 * g * u * u
			end
			return Vector3.new(0, math.max(0, y), 0)
		end, math.clamp(flight, 0.35, 4.0), 0.4)
	end
	pad.Launched += 1
	-- the lockout runs from the LANDING: a body that comes back down on the pad stands Lockout before it is thrown again
	pad.Lock[model] = now + flight + T.Lockout
	broadcast("GustPadLaunch", { Pad = pad.Id, Character = model, T0 = now })
end

--- Who is on `pad` now: each body not locked out and not already coiled is committed (while launches remain).
local function scan(pad, now)
	local reach = pad.Radius + 3
	local probe = pad.At + Vector3.new(0, (T.StepAbove - T.StepBelow) / 2 + 2, 0)
	for humanoid, model in pairs(Core.HumanoidsNear(probe, reach + T.StepAbove + 3)) do
		if pad.Committed >= T.MaxLaunches then return end
		if not pad.Pending[model] and (pad.Lock[model] or 0) <= now then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and eligible(pad, model, humanoid) then
				local flat, feet = where(pad, root, humanoid)
				if flat <= pad.Radius and feet >= -T.StepBelow and feet <= T.StepAbove then
					commitStep(pad, model, now)
				end
			end
		end
	end
end

local function stepPad(player, pad, now)
	-- the coiled launches whose time has come
	for model, at in pairs(pad.Pending) do
		if now >= at then
			pad.Pending[model] = nil
			launch(pad, model, now)
		end
	end
	local pending = next(pad.Pending) ~= nil
	if pad.Launched >= T.MaxLaunches and not pending then
		endPad(player, "Spent")
		return
	end
	if now >= pad.EndAt then
		if not pending then endPad(player, "Expired") end
		return                                             -- no new steps past its life
	end
	if now >= pad.ArmAt and now >= pad.ScanAt then
		pad.ScanAt = now + T.ScanInterval
		scan(pad, now)
	end
end

RunService.Heartbeat:Connect(function()
	if next(pads) == nil then return end
	local now = workspace:GetServerTimeNow()
	for player, pad in pairs(pads) do
		local ok, err = pcall(stepPad, player, pad, now)
		if not ok then
			warn("[ZephyrGustPadServer] " .. tostring(err))
			endPad(player, "Error")
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- the press
----------------------------------------------------------------------------------------------------
-- SpellshotService asks this BEFORE it charges a Gust Pad press (Precheck = true on the row): true only for a living
-- caster whose aimed spot has a floor -- so a press at the sky over a drop costs nothing at all. Detonate's / Aftershock's
-- arrangement: built whole, its answer set first and parented last; anything but a plain true refuses. It must not yield,
-- and it does not (raycasts).
do
	local precheck = spellFolder:FindFirstChild("Precheck_" .. ID)
	local fresh = not (precheck and precheck:IsA("BindableFunction"))
	if fresh then
		precheck = Instance.new("BindableFunction")
		precheck.Name = "Precheck_" .. ID
	end
	precheck.OnInvoke = function(player, _role, payload)
		local character, _, root = Core.AliveCharacter(player)
		if not character then return false end
		local target = type(payload) == "table" and payload.Target or nil
		return spotFor(root, target) ~= nil
	end
	if fresh then precheck.Parent = spellFolder end
end

local function castGustPad(player, role, character, root, payload)
	local spot = spotFor(root, payload.Target)
	if not spot then
		-- only reached without the row's Precheck: the press did nothing, so it costs nothing
		local giveBack = spellFolder:FindFirstChild("GiveBack")
		if giveBack then giveBack:Fire(player, role) end
		return
	end
	endPad(player, "Replaced")
	nextId += 1
	local now = workspace:GetServerTimeNow()
	local pad = {
		Id = nextId, Player = player, Character = character, At = spot, T0 = now, ArmAt = now + T.ArmTime,
		EndAt = now + T.Life, Radius = T.Radius, Committed = 0, Launched = 0,
		Lock = setmetatable({}, { __mode = "k" }), Pending = {}, ScanAt = 0,
	}
	pads[player] = pad
	broadcast("GustPad", { Caster = character, Position = spot, T0 = now, Life = T.Life, Pad = pad.Id, Radius = pad.Radius })
end

performCast.Event:Connect(function(player, role, ability, payload)
	if not (ability and ability.Id == ID) then return end
	local character, _, root = Core.AliveCharacter(player)
	if not character then return end
	castGustPad(player, role, character, root, type(payload) == "table" and payload or {})
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): the pad goes, its coiled launches with it.
Core.OnClear(function(player)
	endPad(player, "Clear")
end)

Players.PlayerRemoving:Connect(function(player)
	endPad(player, "Left")
end)
