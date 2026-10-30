--[[
	ZephyrSkyriderServer  (Script)  ->  ServerScriptService/ZephyrSkyriderServer           Zephyr v6 import, 2026-10-06

	The gameplay side of SKYRIDER, the Technique pool's Mobility half (it replaces Gust Jump: ROBLOX_IMPORT_PLAN
	sections 0 and 5). Its numbers are IceMagic.ZephyrSkyrider.Tuning, shared with the rider's client; the bird is
	IceMagic.ZephyrFX_Skyrider, drawn on every client from the broadcasts below. EVERY NUMBER IS PROVISIONAL (v6 import).

	WHERE THE CAST COMES FROM. The row is HELD (Cooldown 12, ManaCost 15; INTEGRATION adds it): SpellshotService's held
	path checks the press (alive, off cooldown, the mana there), pays ManaCost, sets Holding_<slot> = "Skyrider" and
	fires PerformCast (player, slot, ability, { Phase = "Start" }). This Script listens for its own ability Id only
	(ZephyrHandler's pattern) and:
	  START     refuses a body that cannot fly (in the Hub, rooted or lifted, a zero speed cap, interrupted, staggered,
	            entombed, burrowed, or CombatCore.CanAct says no) by GIVING THE CAST BACK (SpellshotService's GiveBack: the
	            mana and the cooldown return, Holding_ clears) and saying nothing -- the rider's client cuts its ride when
	            no SkyriderStart comes. Otherwise the ride is on: SkyriderStart { Caster, T0 } to everyone, and the
	            character's SkyriderT0 attribute (server time) says so for as long as it lasts.
	  THE RIDE  (the rider's own client flies the body: ZephyrSkyrider's motor). Every Heartbeat this checks it and ends
	            it ("Died", "Zone" (the Hub, CastLocked), a stun ("Rooted" / "Interrupted" / "Stunned"), "Timeout" (MaxRide
	            + TimeSlack + 2 x ping from the press), "Mana" (the bar empty), "Speed" (the root faster than the
	            motor's fastest -- BoostSpeed along the ground with LiftSpeed up, its floor rule or a wall climb --
	            x SpeedSlack + SpeedPad, plus a knock's speed while one lasts, for OverSpeedTime)), and
	            DRAINS the mana: ManaPerSecond x DrainInterval through SpellshotService's SpendMana every DrainInterval
	            (the bar is SpellshotService's: an ability script writing the attribute would be overwritten by the regen;
	            the regen, 7/s, keeps running, so the bar falls at ManaPerSecond - 7 net).
	  THE END   whoever ends it -- the rider (SkyriderEnd on IceAbilityRemote: the jump off, or the client's own reasons),
	            this Script, a duel round reset or leaving the arena (CombatCore.OnClear) -- SkyriderEnd { Caster, Reason,
	            T0 } goes to everyone, and the hold is released here (ReleaseHold: SpellshotService starts the cooldown
	            and hands the release back as PerformCast { Phase = "Release" }). The rider's client also sends the held
	            cast's own release (CastRequest (slot, { Release = true })); whichever lands second finds nothing held.

	THE GUST FLAP (SkyriderGust { Dir } on IceAbilityRemote: the Technique key again while riding). Checked: the ride on
	and past its summon, Gust.Cooldown (less CooldownSlack) since the last, the mana there, CanAct. Paid: Gust.ManaCost
	through SpendMana. Told: SkyriderGust { Caster, Dir, T0 } to everyone (the bird's wind-up and stroke, the cone). Then
	at the LAUNCH (WindUp + Launch after the press) the cone is taken from the rider's root as it is then: every body
	within Range along Dir and inside HalfAngle (+ BodyPad for its width), with nothing solid between, is hit when the
	cone's front reaches it (ZephyrSkyrider.ConeTau: the same front curve the bird draws) -- Damage through
	CombatCore.DealDamage (friendly bodies are refused there, as everywhere), SkyriderGustHit { Caster, Victim, At, T0 } to
	everyone (the ring and the bloom on it), and the KNOCK: KnockOut away from the rider along the ground + KnockUp,
	the existing pattern (TerraHandler's / AquaHandler's): a PLAYER's body is its own client's, so it is SENT the throw
	(SkyriderKnock { Velocity, Until, Caster }, to them alone); a dummy the server simulates takes a server mover for
	KnockTime; a range dummy held Anchored is carried along the throw's arc and put back. A Bulwark Wall takes the
	damage only. Updraft's knockback scale is NOT applied (the plan: it is not a passive hit), nor its damage bonus
	(NoUpdraft = true: 2026-10-19, audit P5E-10). A round reset in between
	(CombatCore.Epoch) cancels the hits still on their way.

	THE WOBBLE. Any hit that lands on a rider (CombatCore.OnHitLanded) broadcasts SkyriderHit { Caster, At, T0 } (At =
	where it came from, else the rider) -- at most once per HitGap per rider.

	Server -> client ("VFX", kind, data) on IceAbilityRemote (CombatCore.Broadcast): SkyriderStart, SkyriderGust,
	SkyriderGustHit, SkyriderHit, SkyriderEnd to everyone; SkyriderKnock to the struck player alone. Client -> server on
	the same remote: SkyriderGust, SkyriderEnd. ZephyrSkyrider (client) handles every one of them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local Skyrider = require(iceFolder:WaitForChild("ZephyrSkyrider"))
local Core = require(script.Parent:WaitForChild("CombatCore"))
local performCast = spellFolder:WaitForChild("PerformCast")
local releaseHold = spellFolder:WaitForChild("ReleaseHold")
local spendMana = spellFolder:WaitForChild("SpendMana")
local giveBack = spellFolder:WaitForChild("GiveBack")

local T = Skyrider.Tuning
local G = T.Gust
local remote = Core.Remote
local broadcast = Core.Broadcast
local ID = "Skyrider"
local SLOTS = { "Mobility", "Defense" }

-- the reasons a client may give for its own end (anything else is "Client")
local CLIENT_REASONS = {
	Jump = true, Died = true, Zone = true, Timeout = true, Dash = true, Rooted = true, Interrupted = true, Stunned = true,
	CharacterChanged = true, Stale = true, Gone = true,
}

local rides = {}           -- [player] = { Character, Humanoid, Root, Role, At, T0, NextDrain, LastGust, Over, KnockUntil,
                           --              LastHit, Ended, EndedAt, EndReason }

local function tell(player, kind, data)
	pcall(function() remote:FireClient(player, "VFX", kind, data) end)
end

local function pingOf(player)
	local p = 0
	pcall(function() p = player:GetNetworkPing() end)
	return p
end

--- the slot this player's Skyrider hold is in, or nil (a hold in progress names its own: Holding_<slot>)
local function heldSlot(player, r)
	local c = player.Character
	if not c then return nil end
	if r and r.Role and c:GetAttribute("Holding_" .. r.Role) == ID then return r.Role end
	for _, s in ipairs(SLOTS) do
		if c:GetAttribute("Holding_" .. s) == ID then return s end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- the ride
----------------------------------------------------------------------------------------------------
--- THE END (see the header): told to everyone, and the hold released (the cooldown starts in SpellshotService).
--- keepHold: the hold is not this ride's to release (a new press replacing a ride never ended: Holding_ is the NEW one's)
local function endRide(player, reason, keepHold)
	local r = rides[player]
	if not r or r.Ended then return end
	r.Ended, r.EndedAt, r.EndReason = true, os.clock(), reason
	local c = r.Character
	if c and c.Parent then c:SetAttribute("SkyriderT0", nil) end
	broadcast("SkyriderEnd", { Caster = c, Reason = reason, T0 = workspace:GetServerTimeNow() })
	local slot = not keepHold and heldSlot(player, r) or nil
	if slot then
		releaseHold:Fire(player, slot)            -- SpellshotService starts the cooldown and hands the release back here
	else
		rides[player] = nil
	end
end

--- START (PerformCast Phase "Start"): refused -> the cast given back, in silence; else the ride is on
local function startRide(player, role, character, humanoid, root)
	local old = rides[player]
	if old and not old.Ended then endRide(player, "Replaced", true) end
	if player:GetAttribute("Zone") == "Hub" or Skyrider.Stunned(character, humanoid) or not Core.CanAct(player) then
		giveBack:Fire(player, role)
		return
	end
	local now = os.clock()
	local T0 = workspace:GetServerTimeNow()
	rides[player] = {
		Character = character, Humanoid = humanoid, Root = root, Role = role, At = now, T0 = T0,
		NextDrain = now + T.DrainInterval, LastGust = -math.huge, Over = 0, KnockUntil = 0, LastHit = -math.huge,
	}
	character:SetAttribute("SkyriderT0", T0)
	broadcast("SkyriderStart", { Caster = character, T0 = T0 })
end

-- PRECHECK (2026-10-19, audit P4-01): SpellshotService asks this BEFORE a press is paid (Precheck = true on the row),
-- with startRide's own refusals, so a press that cannot fly costs and changes nothing. Before it, a modified client
-- pressing while Entombed or rooted was paid (+6% Ultimate, no cooldown once given back) and TerraHandler counted the
-- accepted Mobility press as the Tomb's escape. Gust Pad's arrangement: built whole, answer set first, parented last.
do
	local precheck = spellFolder:FindFirstChild("Precheck_" .. ID)
	local fresh = not (precheck and precheck:IsA("BindableFunction"))
	if fresh then
		precheck = Instance.new("BindableFunction")
		precheck.Name = "Precheck_" .. ID
	end
	precheck.OnInvoke = function(player)
		local character, humanoid = Core.AliveCharacter(player)
		if not character or player:GetAttribute("Zone") == "Hub" then return false end
		return Skyrider.Stunned(character, humanoid) == nil and Core.CanAct(player) ~= nil
	end
	if fresh then precheck.Parent = spellFolder end
end

performCast.Event:Connect(function(player, role, ability, payload)
	if type(ability) ~= "table" or ability.Id ~= ID then return end
	payload = type(payload) == "table" and payload or {}
	if payload.Phase == "Start" then
		local character, humanoid, root = Core.AliveCharacter(player)
		if not character then return end
		startRide(player, role, character, humanoid, root)
	elseif payload.Phase == "Release" then
		-- the release: the client's (its own SkyriderEnd usually came first) or this Script's own ReleaseHold
		local r = rides[player]
		if r and not r.Ended then endRide(player, "Release") end
		r = rides[player]
		if r and r.Ended then rides[player] = nil end
	end
end)

-- the rider's own end (the jump off, or its client's reasons: a dash, a stun it saw first, a respawn)
remote.OnServerEvent:Connect(function(player, action, reason)
	if action ~= "SkyriderEnd" then return end
	local r = rides[player]
	if not r or r.Ended then return end
	endRide(player, (type(reason) == "string" and CLIENT_REASONS[reason]) and reason or "Client")
end)

----------------------------------------------------------------------------------------------------
-- the knock (TerraHandler's / AquaHandler's: serverOwned / moveDummy / carryDummy, local there)
----------------------------------------------------------------------------------------------------
local function serverOwned(root)
	if root.Anchored then return false end
	local ok, owner = pcall(function() return root:GetNetworkOwner() end)
	return ok and owner == nil
end

local function moveDummy(root, velocity, seconds, forcePerMass)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SkyriderMoveAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "SkyriderMove"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * forcePerMass
	mover.MaxAxesForce = Vector3.new(force, force, force)
	mover.VectorVelocity = velocity
	mover.Parent = attachment
	attachment.Parent = root
	task.delay(seconds, function() attachment:Destroy() end)
end

--- a range dummy is flown along `path(t)` (an offset from where it stood) for `seconds`, then put back `back` later
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
-- THE GUST FLAP
----------------------------------------------------------------------------------------------------
--- one body the front reached: the damage, the hit broadcast, the knock
local function strike(player, r, humanoid, model, vroot, dir, apex, epoch)
	if Core.Epoch(player) ~= epoch then return end
	if not (model.Parent and vroot.Parent and humanoid.Parent and humanoid.Health > 0) then return end
	-- (2026-10-19, audit P5E-10, an audit call the owner may reverse) NoUpdraft: a rider is always "airborne", so Updraft's x1.25 was a flat,
	-- hidden +25% on every gust; the kit's own comment says the gust is not an Updraft hit
	if not Core.DealDamage(player, humanoid, G.Damage, { From = apex, Ranged = true, Ability = ID, NoUpdraft = true }) then return end
	local now = workspace:GetServerTimeNow()
	broadcast("SkyriderGustHit", { Caster = r.Character, Victim = model, At = vroot.Position, T0 = now })
	if Core.IsWall(model) then return end
	local away = Vector3.new(vroot.Position.X - apex.X, 0, vroot.Position.Z - apex.Z)
	if away.Magnitude > 0.05 then
		away = away.Unit
	else
		away = Vector3.new(dir.X, 0, dir.Z)
		away = away.Magnitude > 0.05 and away.Unit or Vector3.new(0, 0, -1)
	end
	local velocity = away * G.KnockOut + Vector3.new(0, G.KnockUp, 0)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		tell(victim, "SkyriderKnock", { Velocity = velocity, Until = now + G.KnockTime, Caster = r.Character })
		local vr = rides[victim]
		if vr then vr.KnockUntil = os.clock() + G.KnockTime + 0.6 + 2 * pingOf(victim) end   -- the speed check allows it
		-- (2026-10-19, audit P4-04) thrown by someone else is not Updraft's air (ZephyrUpdraftServer): the throw, its fall
		-- from the knock's apex, and a ping for the knock to reach them
		local fall = math.clamp(2 * math.max(velocity.Y, 0) / workspace.Gravity, 0.35, 1.4)
		model:SetAttribute("KnockedUntil", math.max(now + G.KnockTime + fall + 0.3, model:GetAttribute("KnockedUntil") or 0))
	elseif serverOwned(vroot) then
		moveDummy(vroot, velocity, G.KnockTime, G.KnockForcePerMass)
	elseif vroot.Anchored then
		local g = workspace.Gravity
		local air = math.clamp(2 * math.max(velocity.Y, 0) / g, 0.35, 1.4)
		carryDummy(model, function(t)
			return Vector3.new(velocity.X * t, math.max(0, velocity.Y * t - 0.5 * g * t * t), velocity.Z * t)
		end, air, 0.6)
	end
end

--- THE LAUNCH: the cone from the rider's root as it is now; each body inside it is struck when the front gets there
local function launch(player, r, dir, epoch)
	if rides[player] ~= r or r.Ended or Core.Epoch(player) ~= epoch then return end   -- ended in the wind-up: no stroke
	local root = r.Root
	if not (root and root.Parent) then return end
	-- the apex: the drawn bird's chest, ahead of its seat along the flight (the bird's heading: the root's velocity
	-- along the ground, its look when slow) -- where the client draws the cone's front from
	local v = root.AssemblyLinearVelocity
	local heading = Vector3.new(v.X, 0, v.Z)
	if heading.Magnitude <= 4 then heading = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
	if heading.Magnitude <= 1e-3 then heading = Vector3.new(dir.X, 0, dir.Z) end
	heading = heading.Magnitude > 1e-3 and heading.Unit or Vector3.new(0, 0, -1)
	local apex = root.Position + Vector3.new(0, G.ApexUp - T.SeatBelowRoot, 0) + heading * G.ApexAhead
	local half = math.rad(G.HalfAngle)
	local tanH = math.tan(half)
	local found = Core.HumanoidsNear(apex, G.Range / math.cos(half) + G.BodyPad + 2, r.Character)
	local exclude = { r.Character }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	-- ...but never a Bulwark Wall (2026-10-19, audit GC-03): it is a model with a Humanoid, so it was found -- and then
	-- left out of its own line of sight, and the gust struck whoever stood behind "the one wall in the game"
	for _, model in pairs(found) do
		if not Core.IsWall(model) then exclude[#exclude + 1] = model end
	end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for humanoid, model in pairs(found) do
		local vroot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if vroot and vroot:IsA("BasePart") then
			local d = vroot.Position - apex
			local along = d:Dot(dir)
			if along > 0 and along <= G.Range + G.BodyPad then
				local perp = (d - dir * along).Magnitude
				local blocker = perp <= along * tanH + G.BodyPad and workspace:Raycast(apex, d, params)
				-- (the wall's own body is no cover for the wall itself)
				if perp <= along * tanH + G.BodyPad and not (blocker and not blocker.Instance:IsDescendantOf(model)) then
					local delay = Skyrider.ConeTau(math.max(0.5, along - 0.9))
					task.delay(delay, strike, player, r, humanoid, model, vroot, dir, apex, epoch)
				end
			end
		end
	end
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "SkyriderGust" then return end
	local r = rides[player]
	if not r or r.Ended then return end
	local character, _, root = Core.CanAct(player)
	if not character or character ~= r.Character then return end
	local now = os.clock()
	if now - r.At < T.SummonTime - 0.15 then return end
	if now - r.LastGust < G.Cooldown - G.CooldownSlack then return end
	if (character:GetAttribute("Mana") or 0) < G.ManaCost then return end
	local dir = type(a) == "table" and a.Dir or nil
	if Core.ValidVector(dir) and dir.Magnitude > 0.1 then
		dir = dir.Unit
	else
		dir = root.CFrame.LookVector
	end
	r.LastGust = now
	spendMana:Fire(player, G.ManaCost)
	broadcast("SkyriderGust", { Caster = character, Dir = dir, T0 = workspace:GetServerTimeNow() })
	task.delay(G.WindUp + G.Launch, launch, player, r, dir, Core.Epoch(player))
end)

----------------------------------------------------------------------------------------------------
-- THE WOBBLE
----------------------------------------------------------------------------------------------------
Core.OnHitLanded(function(caster, humanoid, amount, info)
	local model = humanoid and humanoid.Parent
	if not model then return end
	for player, r in pairs(rides) do
		if r.Character == model and not r.Ended then
			local now = os.clock()
			if now - r.LastHit >= T.HitGap and ((info and info.Removed) or amount or 0) > 0 then
				r.LastHit = now
				local from = info and info.From
				broadcast("SkyriderHit", {
					Caster = model, At = (typeof(from) == "Vector3") and from or (r.Root and r.Root.Position),
					T0 = workspace:GetServerTimeNow(),
				})
			end
			return
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- the checks and the drain, every Heartbeat
----------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, r in pairs(rides) do
		if r.Ended then
			if now - (r.EndedAt or now) > 3 then rides[player] = nil end   -- a release that never came back
			continue
		end
		local c, hum, root = r.Character, r.Humanoid, r.Root
		if player.Character ~= c or not (c and c.Parent and hum.Parent and root.Parent) or hum.Health <= 0 then
			endRide(player, "Died")
			continue
		end
		if player:GetAttribute("Zone") == "Hub" or player:GetAttribute("CastLocked") then
			endRide(player, "Zone")
			continue
		end
		local why = Skyrider.Stunned(c, hum)
		if why then
			endRide(player, why)
			continue
		end
		if now - r.At > T.MaxRide + T.TimeSlack + 2 * pingOf(player) then
			endRide(player, "Timeout")
			continue
		end
		-- the drain: ManaPerSecond in DrainInterval steps (caught up after a hitch, never more than a second's worth)
		local n = 0
		while now >= r.NextDrain and n < math.ceil(1 / T.DrainInterval) do
			r.NextDrain += T.DrainInterval
			n += 1
		end
		if now >= r.NextDrain then r.NextDrain = now + T.DrainInterval end
		if n > 0 then spendMana:Fire(player, T.ManaPerSecond * T.DrainInterval * n) end
		local mana = c:GetAttribute("Mana")
		if now - r.At > 0.25 and type(mana) == "number" and mana <= 0.001 then
			endRide(player, "Mana")
			continue
		end
		-- the speed check: the motor's fastest is BoostSpeed along the ground while its floor rule or a wall climb lifts
		-- at LiftSpeed (the ride climbs over what is in its way now), with room for lag and a knock while one lasts
		local limit = math.sqrt(T.BoostSpeed ^ 2 + T.LiftSpeed ^ 2) * T.SpeedSlack + T.SpeedPad
		if now < r.KnockUntil then limit += G.KnockOut + G.KnockUp end
		if root.AssemblyLinearVelocity.Magnitude > limit then
			r.Over += dt
			if r.Over > T.OverSpeedTime then
				endRide(player, "Speed")
				continue
			end
		else
			r.Over = math.max(0, r.Over - dt)
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): the ride ends at once (its cooldown starts,
-- as a release would start it), and the flap's hits still on their way land nowhere (Epoch).
Core.OnClear(function(player)
	endRide(player, "Clear")
end)

Players.PlayerRemoving:Connect(function(player)
	rides[player] = nil
end)
