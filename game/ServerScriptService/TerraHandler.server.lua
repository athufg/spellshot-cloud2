--[[
	TerraHandler  (Script)  ->  ServerScriptService/TerraHandler

	The gameplay side of the Terra kit (design manual Section 2; wired 2026-09-17). TerraFX draws all of it and this
	decides what it does. Every number is TerraFX.Tuning, shared with the client, and EVERY ONE OF THEM IS NEW --
	the manual gives Terra behaviour and no figures, and SpellshotConfig carried none for Terra either.

	  M1   Boulder Shot   HELD TO CHARGE, released to throw. The hold is announced (BoulderCharge) so the server
	                      knows how long the rock was gathered -- the Passive will read the same state -- and so
	                      every other client can see the rock growing in the caster's hand. The shooter's client
	                      flies its own boulder and reports what it stopped on; this checks the claim against the
	                      ARC it rebuilds from the release (TerraFX.BoulderPoint), the same arrangement Fireball
	                      has with PyroHandler and Icicle Shard with AbilityHandler.
	  Defense  Bulwark Wall  (2026-09-19) the one wall in the game: HELD -- up while the key is down, while the BAR can
	                      pay for it (ManaPerSecond, 2026-09-20: no cooldown and no time cap), or until it has absorbed
	                      WallHP. A real server body,
	                      so it stops bodies and shots; a Humanoid, so every kit's hits damage it with no change to them.
	  Mobility  Aftershock  (2026-09-25, REPLACING Tremor Vault) both fists driven into the ground a step ahead: after
	                      the windup a ring of erupting rock races out from that spot, and everyone it reaches with their
	                      feet on the floor is hit, thrown back from the centre and interrupted. The SERVER decides the
	                      centre, the clock and every strike; the caster is held in place until just after the slam.
	  Primary  Bulwark Charge  a shouldered charge forward. The movement is the caster's client (DashMotor);
	                      this thins every hit the charger takes while it runs, and sweeps a box carried on
	                      the SERVER's copy of the body for whoever it reaches -- damage, Staggered, and
	                      thrown off their feet.
	  Ultimate  Earthen Tomb  (2026-09-19, replacing the never-wired Seismic Slam; v2, the redesign, the same day) a
	                      target LOCKED at cast, a fissure homing on them that only a jump beats, then the target
	                      alone raised in a stone fist and crushed at the top -- the state machine is in its own
	                      section below, and every branch of it is decided here.

	WHERE CASTS COME FROM: SpellshotService checks and pays for the cast, then fires PerformCast; this, AbilityHandler
	and PyroHandler all hear it and each acts only on its own kit's ability Ids. Damage goes through CombatCore, so a
	shield soaks a boulder too.

	Server -> client (AbilityFX): ("VFX", kind, data) on IceAbilityRemote.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local TerraFX = require(iceFolder:WaitForChild("TerraFX"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local Core = require(script.Parent:WaitForChild("CombatCore"))

local T = TerraFX.Tuning
local remote = Core.Remote
-- every Boulder Shot broadcast carries its caster's wrap Id (SkinCatalog, 2026-10-10; Default when none): colour only
local SkinCatalog = require(spellFolder:WaitForChild("SkinCatalog"))
local function broadcast(kind, data)
	if type(data) == "table" and data.Skin == nil then
		local ability = SkinCatalog.AbilityOfKind(kind)
		local c = ability and data.Character
		local plr = typeof(c) == "Instance" and Players:GetPlayerFromCharacter(c) or nil
		if plr then data.Skin = SkinCatalog.Chosen(plr, ability) end
	end
	return Core.Broadcast(kind, data)
end
local ABILITY = VFXLibrary.AbilityById

--- Whether the ability `player` holds in `role` is the one named.
local function holds(player, role, id)
	local a = VFXLibrary.AbilityFor(player, role)
	return a ~= nil and a.Id == id
end

--- Whether `player` is playing Terra, which is what decides the Passive: AbilityFor only resolves M1 and
--- Primary from the Element and the three pools from the player's own attributes -- there is no "Passive"
--- slot to equip, so a Passive is read off the Element itself.
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local function isTerra(player)
	local element = player:GetAttribute("Element") or Config.DefaultLoadout.Element
	return element == "Terra" and Config.IsPartBuilt("Terra", "Passive")
end

--- (2026-10-19, audit P4-04) A player this kit throws (Aftershock, Bulwark Charge) is stamped KnockedUntil, server time, for
--- the throw and its fall: air someone else put them in, which Zephyr's Updraft does not count (ZephyrUpdraftServer).
local function markKnocked(model, seconds)
	local untilT = workspace:GetServerTimeNow() + seconds
	model:SetAttribute("KnockedUntil", math.max(untilT, model:GetAttribute("KnockedUntil") or 0))
end

----------------------------------------------------------------------------------------------------
-- M1: BOULDER SHOT -- the charge
----------------------------------------------------------------------------------------------------
-- What each player is gathering right now. The Passive (Bedrock) will read this same table: "the longer you commit
-- to an attack, the more mitigation you get" is exactly this state, so it lives on the server rather than only on
-- the caster's client.
local charging = {}        -- [player] = { Character, At (os.clock of the press) }

--- How long `player` has been holding a Boulder Shot charge, or nil if they are not.
local function chargeHeld(player)
	local c = charging[player]
	if not (c and c.Character.Parent) then return nil end
	-- a live body, not merely a parented one (2026-09-21): a dead character stays under workspace for the whole
	-- respawn window, so Parent alone answered "still holding" and Bedrock went on stacking on the corpse
	local hum = c.Character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return nil end
	return os.clock() - c.At
end

--- `reason` goes out with the broadcast (2026-09-23, the Boulder Shot rework): "Release" is a hold that ended in an
--- accepted throw -- every other client keeps the rock in the hand a moment for the throw's own broadcast to take it
--- over -- and nil is a hold that was dropped (death, a round clearing), where the rock goes at once. "Interrupted"
--- (2026-09-25) is a drop too, but one the holder's OWN client has to hear about: their own Aftershock slam, or
--- somebody else's Aftershock striking them.
local chargeOffAt = {}     -- [player] = os.clock() of their last hold's end (2026-10-19, audit P1-07)

local function stopCharge(player, silent, reason)
	local c = charging[player]
	if not c then return end
	charging[player] = nil
	chargeOffAt[player] = os.clock()
	if c.Character.Parent then c.Character:SetAttribute("TerraCharging", nil) end
	-- (2026-10-19, audit P1-07) a hold whose start was never broadcast (a re-press inside the gap, below) ends unheard,
	-- unless it is an interrupt, which the holder's own client has to hear about
	if c.Shown == false and reason ~= "Interrupted" then silent = true end
	if not silent then broadcast("BoulderChargeStop", { Character = c.Character, Reason = reason }) end
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "BoulderCharge" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "BoulderShot") then return end
	-- CanAct, not AliveCharacter: a charge must not be gathered from under the ground either -- the rock drew at a
	-- hidden body and gave her position away, and the hold fed Bedrock stacks she could not be hit through anyway
	local character = Core.CanAct(player)
	if not character then
		stopCharge(player)
		return
	end
	if a.On then
		if charging[player] and charging[player].Character == character then return end
		-- (2026-10-19, audit P1-07) every On after an Off made a record and a broadcast to every client: a bucket on the
		-- presses (an Off is never refused -- it only ever ends a hold), and a re-press inside MIN_GAP of the last hold's
		-- end still starts the hold this server times (an honest quick re-press keeps its charge) but is announced only
		-- once the gap has passed, and not at all if it ends first
		if not Core.Allow(player, "BoulderCharge", 6, 8) then return end
		local MIN_GAP = 0.15
		local rec = { Character = character, At = os.clock() }
		charging[player] = rec
		character:SetAttribute("TerraCharging", true)
		local wait = MIN_GAP - (os.clock() - (chargeOffAt[player] or -math.huge))
		if wait <= 0 then
			broadcast("BoulderChargeStart", { Character = character, T0 = workspace:GetServerTimeNow() })
		else
			rec.Shown = false
			task.delay(wait, function()
				if charging[player] ~= rec then return end
				rec.Shown = true
				broadcast("BoulderChargeStart", { Character = character, T0 = workspace:GetServerTimeNow() })
			end)
		end
	else
		stopCharge(player)
	end
end)

----------------------------------------------------------------------------------------------------
-- M1: BOULDER SHOT -- the throw, and the hit
----------------------------------------------------------------------------------------------------
-- The press itself is nothing to look at: the rock gathers on the hold and leaves on the release, so the cast
-- relay only carries the release for everyone else to play.
-- The throw is split over two remotes -- the damage claim on the ice remote (BoulderRelease, checked against the hold
-- this server watched) and this relay, which every other client sizes the rock and its impact from. So the charge the
-- release settled on is handed over here. Until 2026-09-21 the relay took the client's own claim at face value, and a
-- tap could be DRAWN as the heaviest rock in the game while landing a tap's damage -- the growing rock is meant to be
-- a tell you can read, so it has to be the same number the hit is worth.
local lastThrow = {}       -- [player] = { Charge, At }: what the last release actually settled on

local function castBoulderShot(player, character, humanoid, root, payload)
	local dir = payload.Dir
	if Core.ValidVector(dir) and dir.Magnitude > 0.1 then
		dir = dir.Unit
	else
		dir = root.CFrame.LookVector
	end
	-- (2026-10-19, audit P1-16) only a release this server accepted sizes the rock (its Charge is checked against the hold
	-- it watched). The cast's own Charge was the fallback, so a cast with no release drew a full-charge throw that dealt
	-- nothing -- a fake of the tell -- and a NaN went to every client (math.clamp passes NaN through). No release: a tap.
	local charge = 0
	local last = lastThrow[player]
	if last and os.clock() - last.At <= 0.3 then charge = last.Charge end
	broadcast("BoulderShot", { Character = character, Dir = dir, Charge = charge })
end

local shots = {}           -- [player] = { [id] = { Origin, Velocity, Charge, At, Life, Character } }
local buckets = {}         -- [player] = { Tokens, At }: the throw-rate check

-- The release: the shooter's eye, aim and the charge it claims. The arc is rebuilt from those here with the same
-- numbers the client flies (TerraFX.BoulderVelocity / BoulderPoint).
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "BoulderRelease" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "BoulderShot") then return end
	local character, humanoid, root = Core.CanAct(player)          -- CanAct, not AliveCharacter: not from underground (2026-09-21)
	if not character then return end
	local origin, dir, id = a.Origin, a.Dir, a.Id
	-- id ~= id rejects NaN (2026-09-21): Core.ValidVector already refuses a NaN vector, but the Id check did not,
	-- and the write below then raised "table index is NaN" out of the handler -- a script error a client could ask
	-- for at will, with the charge and the rate token already spent
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or type(id) ~= "number" or id ~= id
		or dir.Magnitude < 0.1 then
		return
	end
	local now = os.clock()
	-- one throw per FireInterval on average, with half a throw of slack for jitter (as ShardRelease and
	-- FireballRelease). A charged M1 cannot be spammed anyway, but the bucket is what stops a script from trying.
	local b = buckets[player]
	if not b then
		b = { Tokens = 1.5, At = now }
		buckets[player] = b
	end
	local interval = ABILITY.BoulderShot.FireInterval / VFXLibrary.ShotTimeScale()
	b.Tokens = math.min(2, b.Tokens + (now - b.At) / interval)
	b.At = now
	if b.Tokens < 1 then
		Core.CountShot("rej_rate")
		return
	end
	b.Tokens -= 1
	-- the eye has to be the shooter's own, allowing for the server's copy of a moving player trailing the real one
	local head = character:FindFirstChild("Head")
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	local speed = Core.TrailSpeed(root, humanoid.WalkSpeed)
	if (origin - (head and head.Position or root.Position)).Magnitude > 6 + speed * (0.35 + Core.Lag(ping)) then
		Core.CountShot("rej_origin")
		return
	end
	-- THE CHARGE IS CHECKED, not taken: a claim is worth at most what the hold this server saw could have gathered,
	-- plus a tenth of a second of slack for the press that has not arrived yet. A client claiming a full charge on a
	-- tap therefore throws a tap's boulder.
	local held = chargeHeld(player)
	local B = T.BoulderShot
	local allowed = held and math.clamp((held + 0.1) / B.ChargeTime, 0, 1) or 0.1
	local claim = tonumber(a.Charge) or 0
	if claim ~= claim then claim = 0 end       -- (2026-10-19, audit P1-16) a NaN claim is a tap, not a NaN rock
	local charge = math.min(math.clamp(claim, 0, 1), allowed)
	lastThrow[player] = { Charge = charge, At = now }     -- ...and the relay draws the rock at this, not at the claim
	-- ANNOUNCED, not silent (2026-09-23): a release this server accepts whose M1 cast it then refuses (the cast relay's
	-- own interval, CastLocked) sends no BoulderShot, and every other client kept the rock in the thrower's hand and the
	-- body in its windup for ever. Now they hear the hold end, as a release, and let go if no throw follows.
	stopCharge(player, false, "Release")
	local mine = shots[player]
	if not mine then
		mine = {}
		shots[player] = mine
	end
	for oldId, shot in pairs(mine) do
		if now - shot.At > shot.Life then mine[oldId] = nil end
	end
	mine[id] = {
		Origin = origin, Velocity = TerraFX.BoulderVelocity(dir.Unit, charge), Charge = charge, At = now,
		Character = character, Life = B.Life / VFXLibrary.ShotTimeScale() + 1.5,
	}
	Core.CountShot("release")
end)

--- The time along the arc closest to `point` (sampled, because the arc is not a line), and how far off it that
--- point is. Twenty steps over the flight is finer than the rock's own radius at any speed it can be thrown.
local function nearestOnArc(shot, point)
	local B = T.BoulderShot
	local bestT, bestD = 0, math.huge
	for i = 0, 20 do
		local t = B.Life * i / 20
		local d = (TerraFX.BoulderPoint(shot.Origin, shot.Velocity, t) - point).Magnitude
		if d < bestD then bestT, bestD = t, d end
	end
	-- one refinement pass either side of the best sample, so the answer is not quantised to 1/20th of a flight
	local step = B.Life / 40
	for _, t in ipairs({ bestT - step, bestT + step }) do
		if t >= 0 and t <= B.Life then
			local d = (TerraFX.BoulderPoint(shot.Origin, shot.Velocity, t) - point).Magnitude
			if d < bestD then bestT, bestD = t, d end
		end
	end
	return bestT, bestD
end

--- True if something solid stands on the arc short of time `tHit` -- checked as Core.Blocked checks a line:
--- characters never count as cover, and the target's own surface is not cover either.
local function flightBlocked(shot, tHit, skip)
	local B = T.BoulderShot
	local list = { shot.Character, skip }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local claimed = TerraFX.BoulderPoint(shot.Origin, shot.Velocity, tHit)
	-- the arc is walked in segments; a straight ray from the eye would cut the corner and call the ground cover
	local steps = math.max(2, math.ceil(tHit / 0.05))
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local blocked, model = false, nil
		local prev = shot.Origin
		for i = 1, steps do
			local t = tHit * i / steps
			local nextPoint = TerraFX.BoulderPoint(shot.Origin, shot.Velocity, t)
			local hit = workspace:Raycast(prev, nextPoint - prev, params)
			if hit then
				if (hit.Position - claimed).Magnitude <= Core.SameSurface + B.Radius * 2 then
					return false
				end
				model = hit.Instance:FindFirstAncestorOfClass("Model")
				blocked = true
				break
			end
			prev = nextPoint
		end
		if not blocked then return false end
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return true end
		-- a Bulwark Wall has a Humanoid (it is how every kit's hits damage it) but it is COVER, not a character, and
		-- this walk has to say so for itself: Core.Blocked has this guard (CombatCore, 2026-09-19) and this copy of
		-- the same walk never got it, so a claimed hit on someone behind a wall was taken (2026-09-21)
		if model:GetAttribute("WallOwner") then return true end
		list[#list + 1] = model
	end
	return false
end

-- What the shooter's boulder stopped on. Checked, then applied. The outcome names are CombatCore's.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "BoulderHit" or type(a) ~= "table" then return end
	local mine = shots[player]
	local shot = mine and type(a.Id) == "number" and mine[a.Id]
	if not shot then
		Core.CountShot("rej_noshot")
		return
	end
	mine[a.Id] = nil                                   -- one hit per throw
	local now = os.clock()
	if now - shot.At > shot.Life then
		Core.CountShot("rej_late")
		return
	end
	local part, position = a.Part, a.Position
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
		or not Core.ValidVector(position) then
		Core.CountShot("rej_badpart")
		return
	end
	local B = T.BoulderShot
	-- on the arc (the rock has a radius, and the reported point is where its cast stopped) ...
	local tHit, off = nearestOnArc(shot, position)
	if off > B.Radius * TerraFX.ChargeScale(shot.Charge) / B.RockSize + 2 then
		Core.CountShot("rej_offline")
		return
	end
	-- ... and no sooner than the boulder could have flown there
	if now - shot.At < tHit / VFXLibrary.ShotTimeScale() - 0.25 then
		Core.CountShot("rej_early")
		return
	end
	local reason, model, humanoid = Core.CheckTarget(part, position, shot.Character)
	if reason then
		Core.CountShot(reason)
		return
	end
	if flightBlocked(shot, tHit, humanoid and model or part) then
		Core.CountShot("rej_blocked")
		return
	end
	-- a body is only hit by a PAID throw (2026-10-19, audit P1-12 / GC-14): the release reaches here first, so the
	-- question waits for the hit, by which time the throw's CastRequest has arrived
	if humanoid and not Core.TakePaidM1(player) then
		Core.CountShot("rej_unpaid")
		return
	end
	Core.CountShot("hit")
	if humanoid then
		Core.DealDamage(player, humanoid, TerraFX.ChargeDamage(shot.Charge), { Ranged = true, From = shot.Origin })
	end
	Core.ShotImpact:Fire(part, position, player)
end)

----------------------------------------------------------------------------------------------------
-- PRIMARY: BULWARK CHARGE
----------------------------------------------------------------------------------------------------
-- The charge forward is the caster's own client (DashMotor, as Frost Slide and Cross-Slash Dash are), because
-- movement that waits for a round trip does not feel like movement. What it HITS is this server's own business:
-- a box carried on the server's copy of the charging body, swept every Heartbeat for as long as the charge can
-- last. Nothing the client says about who it ran into is taken -- only where the charge started and which way.
local charges = {}         -- [player] = { Character, Root, Until, Dir, Hit = { [humanoid] = true } }

local function endCharge(player, silent)
	local c = charges[player]
	if not c then return end
	charges[player] = nil
	if c.Character.Parent then c.Character:SetAttribute("BulwarkCharging", nil) end
	if not silent then broadcast("BulwarkChargeEnd", { Character = c.Character }) end
end

local function castBulwarkCharge(player, character, humanoid, root, payload, role)
	local C = T.BulwarkCharge
	-- (2026-10-19, audit P1-10) refused, at no cost, where the caster's own client refuses the dash (DashMotor.CanStart with
	-- the row's MinCap): rooted or slowed below MinCap (either cap slot), or frozen. (Its third rule, Channeling, is an
	-- attribute the client sets on itself, which the server never sees.) An honest client never sends it then; a modified
	-- one got the sweep, the 40% reduction and Bedrock's stacks standing still.
	local cap = math.min(character:GetAttribute("SpeedCapSlow") or math.huge, character:GetAttribute("SpeedCapUlt") or math.huge)
	if cap < C.MinCap or character:FindFirstChild("IceFrozenState") then
		local giveBack = spellFolder:FindFirstChild("GiveBack")
		if giveBack then giveBack:Fire(player, role or "Primary") end
		return
	end
	local dir = payload.Dir
	if Core.ValidVector(dir) and dir.Magnitude > 0.1 then
		dir = Vector3.new(dir.X, 0, dir.Z)
		dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
	else
		dir = root.CFrame.LookVector
	end
	-- (2026-10-19, audit P1-16) a NaN Dist is the full distance: math.clamp passes NaN through to every client
	local dist = tonumber(payload.Dist)
	if not dist or dist ~= dist then dist = C.Distance end
	charges[player] = {
		Character = character, Root = root, Dir = dir, Hit = {},
		Until = os.clock() + C.MaxTime,
	}
	character:SetAttribute("BulwarkCharging", true)
	broadcast("BulwarkCharge", {
		Character = character, Start = root.Position, Dir = dir,
		Dist = math.clamp(dist, 0, C.Distance + 4),
		T0 = workspace:GetServerTimeNow(),
	})
end

-- The movement is the caster's client, so only it knows when the charge really ENDED -- stopped dead on a wall on the
-- first frame, or run its distance early. Until 2026-09-21 the server ran the full MaxTime whatever happened, so a
-- charge that never moved a stud still swept its box, still thinned every hit by 40% and still fed Bedrock for the
-- rest of the 0.95 s. The report can only ever SHORTEN the window, never hold it open, so there is nothing in it for
-- a client to lie about.
remote.OnServerEvent:Connect(function(player, action)
	if action ~= "BulwarkChargeEnd" then return end
	if charges[player] then endCharge(player) end
end)

--- The shoulder: everyone inside the box carried in front of the charging body, once each per charge. They take
--- the hit, go Staggered, and are thrown along the charge and up -- the manual's "knocks down whatever it hits".
local function sweepCharge(player, c)
	local C = T.BulwarkCharge
	local root = c.Root
	if not (root and root.Parent) then return end
	local origin = root.Position + c.Dir * C.Reach * 0.5
	for victim, model in pairs(Core.HumanoidsNear(origin, C.Reach + C.HalfWidth + 2, c.Character)) do
		if not c.Hit[victim] then
			local vroot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if vroot then
				local rel = vroot.Position - root.Position
				local along = rel:Dot(c.Dir)
				local side = rel - c.Dir * along
				-- (2026-10-19, audit GC-02 / GC-04) never through a Bulwark Wall; a wall itself takes the damage only
				local isWall = Core.IsWall(model)
				if along > -1.5 and along <= C.Reach and math.abs(side.Y) <= C.HalfHeight
					and Vector3.new(side.X, 0, side.Z).Magnitude <= C.HalfWidth
					and (isWall or not Core.WallBetween(root.Position, vroot.Position)) then
					c.Hit[victim] = true
					if isWall then
						Core.DealDamage(player, victim, C.Damage, { From = root.Position })
					elseif Core.DealDamage(player, victim, C.Damage, { From = root.Position }) then
						Core.ApplyStatusTag(victim, "Staggered", C.Stagger)
						model:SetAttribute("RX_Staggered_Element", "Terra")
						model:SetAttribute("RX_Staggered", true)
						-- (2026-10-19, audit P3-06) the stars end with the LAST stagger running, not the first to time
						-- out: RX_StaggeredUntil (server time) is the latest end any Bulwark Charge asked for, and an
						-- Overload's own stagger (ElementalReactions) holds its stamp, ReactionStaggerAt, until it ends
						local staggerUntil = workspace:GetServerTimeNow() + C.Stagger
						model:SetAttribute("RX_StaggeredUntil",
							math.max(staggerUntil, model:GetAttribute("RX_StaggeredUntil") or 0))
						task.delay(C.Stagger, function()
							if not model.Parent then return end
							if workspace:GetServerTimeNow() < (model:GetAttribute("RX_StaggeredUntil") or 0) - 0.05 then return end
							if model:GetAttribute("ReactionStaggerAt") ~= nil then return end
							model:SetAttribute("RX_Staggered", false)
							model:SetAttribute("RX_StaggeredUntil", nil)
						end)
						-- knocked off their feet: thrown along the charge and up. A dummy the server owns takes the
						-- throw here; a PLAYER's own client owns their body and overwrote a velocity written here, so
						-- it read as a shove (2026-10-19, audit P3-21): they are sent the throw to make themselves,
						-- the knock ElementalReactions' Overload sends (AbilityFX's AftershockKnock), held for
						-- Aftershock's KnockTime -- and stamped KnockedUntil for it and the fall (audit P4-04)
						local velocity = c.Dir * C.Knock + Vector3.new(0, C.KnockLift, 0)
						local victimPlayer = Players:GetPlayerFromCharacter(model)
						if victimPlayer then
							local knockTime = T.Aftershock.KnockTime
							pcall(function()
								remote:FireClient(victimPlayer, "VFX", "AftershockKnock", { Velocity = velocity,
									Until = workspace:GetServerTimeNow() + knockTime, Center = root.Position, Caster = player })
							end)
							markKnocked(model, knockTime + math.clamp(2 * C.KnockLift / workspace.Gravity, 0.35, 1.4) + 0.3)
						else
							vroot.AssemblyLinearVelocity = velocity
						end
						broadcast("BulwarkHit", { Position = vroot.Position, Dir = c.Dir, Character = c.Character })
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, c in pairs(charges) do
		local hum = c.Character:FindFirstChildOfClass("Humanoid")
		if not (c.Character.Parent and hum and hum.Health > 0) or now >= c.Until then
			endCharge(player)
		else
			sweepCharge(player, c)
		end
	end
end)

-- The reduction: while the charge runs, everything that hurts the charger is thinned. Priority 5, so it runs
-- BEFORE every soak -- a shield soaks what is left after the armour, not before it.
Core.AddModifier(5, function(victim, amount)
	local player = Players:GetPlayerFromCharacter(victim.Parent)
	local c = player and charges[player]
	if not (c and c.Character == victim.Parent) then return amount end
	return amount * (1 - T.BulwarkCharge.Reduction)
end)

----------------------------------------------------------------------------------------------------
-- DEFENSE: BULWARK WALL (2026-09-19)
----------------------------------------------------------------------------------------------------
-- The one wall in the game (SpellshotConfig.Defense.BulwarkWall: "full projectile/sightline block", 16 s). Its design,
-- as the kit's showcase set it down: a CHANNELLED HOLD, capped, that BREAKS ON DAMAGE, and the cooldown starts when it
-- drops, whichever way. This is that design wired to the Defense key -- no redesign. The hold is SpellshotService's
-- HELD path: the key going down pays and fires Phase "Start" here, the key
-- coming up ends the hold (endHold fires Phase "Release"; the row's Cooldown is 0, so nothing is locked), and anything
-- here that has to end it first -- an empty bar, the wall broken -- does so through ReleaseHold, the same way.
--   THE BODY is the server's own: one anchored, collidable, raycastable box the size of the kit's twelve slabs, WallAhead
--   studs in front of Terra and facing where she faced. It blocks bodies, and every shot in the game that is checked
--   against the server's world (Core.Blocked, every hit claim) stops on it. Every client draws the slabs over it
--   (TerraFX.WallRaise); the box itself is never seen.
--   ITS HEALTH is a Humanoid on the wall's model, so EVERY hit in the game -- a boulder, an icicle, a beam tick, an
--   area -- damages it through CombatCore.DealDamage with no kit having to know walls exist. WallOwner makes it friendly
--   to whoever raised it and to whoever cannot hurt them (CombatCore.IsFriendly). It never reaches 0: the last hit is
--   capped just short (a modifier below), and the wall breaks from there -- so breaking a wall is never a "kill" to
--   anything listening for one (Ember Refund, KO!).
-- Every number is TerraFX.Tuning.BulwarkWall, and every one of them is a PROPOSAL except the 16 s.
local releaseHold = spellFolder:WaitForChild("ReleaseHold")
-- SpellshotService owns the mana bar: the wall drains it through here (Tremor Vault, which also used GiveBack, is gone)
local spendMana = spellFolder:WaitForChild("SpendMana")
local walls = {}           -- [player] = { Model, Body, Humanoid, CF, At, Character }
local wallOf = setmetatable({}, { __mode = "k" })   -- [wall Humanoid] = its wall

--- The wall's size and the slabs' layout, off the imported kit itself (so the box is the slabs), or the kit's own
--- build numbers (build_terra_kit.py: 12 wide, 8.4 tall, 1.6 thick) if it is not imported.
local wallSize = Vector3.new(12.4, 8.4, 1.7)
do
	local kit = ReplicatedStorage:FindFirstChild("EarthMagicMeshes")
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for n = 1, 12 do
		local p = kit and kit:FindFirstChild(("TR_Wall_Slab_%02d"):format(n), true)
		if p and p:IsA("BasePart") then
			local c, h = p:GetPivot().Position, p.Size / 2
			lo, hi = lo:Min(c - h), hi:Max(c + h)
		end
	end
	if hi.X > lo.X then wallSize = Vector3.new(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z) end
	-- 2026-10-23: with the rework's kit in (TerraWall2, what TerraFX_Wall draws) the box is ITS wall: BulwarkWallKitData's
	-- Size, the top at Size.Y + Foot (the old slabs' box stood 0.6 studs over the stones)
	local data = spellFolder:FindFirstChild("BulwarkWallKitData")
	local ok, d = false, nil
	if data and kit and kit:FindFirstChild("TerraWall2") then ok, d = pcall(require, data) end
	if ok and type(d) == "table" and typeof(d.Size) == "Vector3" then
		wallSize = Vector3.new(d.Size.X, d.Size.Y + (tonumber(d.Foot) or 0), d.Size.Z)
	end
end

local function wallFloor(position, skip)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { skip }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	params.FilterDescendantsInstances = list
	return workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
end

--- Takes the wall down at once, however it went: the body gone, every client told how (Reason: "Released" -- the key
--- came up; "Empty" -- the bar ran dry; "Broken" -- its health spent; "Lost" -- its owner died or left).
local function dropWall(player, reason)
	local w = walls[player]
	if not w then return end
	walls[player] = nil
	wallOf[w.Humanoid] = nil
	if w.Model.Parent then w.Model:Destroy() end
	broadcast("WallDrop", { Character = w.Character, Reason = reason, T0 = workspace:GetServerTimeNow() })
end

--- Ends the HOLD from this side (an empty bar, broken): SpellshotService's endHold closes it out and fires the
--- Release that drops the wall -- with the reason we already know.
local function endWallHold(player, reason)
	local w = walls[player]
	if not w or w.Ending then return end
	w.Ending = reason
	local character = player.Character
	local slot = VFXLibrary.TechniqueSlot(player, ABILITY.BulwarkWall.Id)   -- Q or E since v0.7 (2026-09-24)
	if character and slot and character:GetAttribute("Holding_" .. slot) == ABILITY.BulwarkWall.Id then
		releaseHold:Fire(player, slot)              -- -> endHold -> PerformCast Release -> castBulwarkWall -> dropWall
	end
	dropWall(player, reason)                        -- (and at once if the hold had already gone)
end

local function raiseWall(player, character, root)
	local B = T.BulwarkWall
	dropWall(player, "Released")                    -- a new wall replaces an old one outright (it cannot, while held)
	local face = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	face = face.Magnitude > 0.1 and face.Unit or Vector3.new(0, 0, -1)
	local at = root.Position + face * B.WallAhead
	local ground = wallFloor(at, character)
	local base = Vector3.new(at.X, ground and ground.Position.Y or (root.Position.Y - 3), at.Z)
	local cf = CFrame.lookAt(base, base + face)     -- its LookVector is its front: the face the enemy sees
	local model = Instance.new("Model")
	model.Name = "BulwarkWall"
	model:SetAttribute("WallOwner", player.UserId)
	local body = Instance.new("Part")
	body.Name = "WallBody"
	body.Size = wallSize
	body.CFrame = cf * CFrame.new(0, wallSize.Y / 2, 0)
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch = true, true, true, false
	body.Transparency = 1
	body.CastShadow = false
	body.Parent = model
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health = B.WallHP, B.WallHP
	hum.BreakJointsOnDeath, hum.RequiresNeck = false, false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = body
	model.Parent = workspace                        -- NOT the FX folder: raycasts that skip effects must still hit it
	local w = { Model = model, Body = body, Humanoid = hum, CF = cf, At = os.clock(), Character = character }
	walls[player] = w
	wallOf[hum] = w
	broadcast("WallRaise", { Character = character, CF = cf, Size = wallSize, Model = model,
		T0 = workspace:GetServerTimeNow() })
end

local function castBulwarkWall(player, character, humanoid, root, payload)
	if payload.Phase == "Start" then
		raiseWall(player, character, root)
	elseif payload.Phase == "Release" then
		local w = walls[player]
		dropWall(player, (w and w.Ending) or "Released")
	end
end

-- THE MANA (2026-09-20, on request: the 16 s cooldown is gone and the bar is the whole limit) and an owner who is no
-- longer standing: checked every frame. The wall drains ManaPerSecond for as long as it stands; an empty bar ends the
-- hold itself, exactly as the key coming up would. There is NO time cap -- the drain (20) is above the bar's regen (7),
-- so a wall always ends; keep that true of any retune or it could be held for ever.
RunService.Heartbeat:Connect(function(dt)
	local B = T.BulwarkWall
	for player, w in pairs(walls) do
		local character = player.Character
		local alive = character == w.Character and character.Parent
			and (character:FindFirstChildOfClass("Humanoid") or { Health = 0 }).Health > 0
		if not alive then
			-- the HOLD goes with her, not just the wall: dropping the wall alone left Holding_Defense set on the body
			-- (measured 2026-09-20), which is a hold-based state with no resolve path -- the brace would stay on the
			-- corpse until it was replaced
			endWallHold(player, "Lost")
		else
			spendMana:Fire(player, B.ManaPerSecond * dt * VFXLibrary.ShotTimeScale())
			if (character:GetAttribute("Mana") or 0) <= 0.01 then
				endWallHold(player, "Empty")
			end
		end
	end
end)

-- The last hit is capped just short of 0 (so no kill), and the wall breaks the moment it is spent. Runs last.
Core.AddModifier(100, function(victim, amount)
	if not wallOf[victim] then return amount end
	return math.min(amount, math.max(0, victim.Health - 0.01))
end)

-- Every landed hit on a wall: which slab it came at (the attacker's side of the face, projected onto it -- the hit
-- claims carry no contact point), the wall's health left, and the break when it is spent.
Core.OnHitLanded(function(caster, humanoid, amount, info)
	local w = wallOf[humanoid]
	if not w then return end
	local owner
	for player, ww in pairs(walls) do if ww == w then owner = player end end
	local from = type(info) == "table" and typeof(info.From) == "Vector3" and info.From or w.Body.Position
	local rel = w.CF:PointToObjectSpace(from)
	local point = w.CF:PointToWorldSpace(Vector3.new(
		math.clamp(rel.X, -wallSize.X / 2 + 0.6, wallSize.X / 2 - 0.6),
		math.clamp(rel.Y, 0.6, wallSize.Y - 0.6),
		rel.Z < 0 and -wallSize.Z / 2 or wallSize.Z / 2))
	broadcast("WallHit", { Character = w.Character, Point = point, Left = humanoid.Health / humanoid.MaxHealth,
		T0 = workspace:GetServerTimeNow() })
	if owner and humanoid.Health <= 0.02 then endWallHold(owner, "Broken") end
end)

----------------------------------------------------------------------------------------------------
-- ULTIMATE: EARTHEN TOMB (v2, the redesign, 2026-09-19)
----------------------------------------------------------------------------------------------------
-- Replaces the first Earthen Tomb in place (v1: an aimed line, and Terra raised on a platform of her own beside the
-- target). ONLY THE TARGET LEAVES THE GROUND. Five beats, every branch between them decided HERE, on the server's own
-- copy of the bodies -- nothing a client says decides the lock, the catch, the dodge, the escape or the hit.
--   CAST     the LOCK: the enemy nearest the caster's aim line (within LockRadius of it, in Range, in sight) -- or no
--            cast at all, and nothing spent. Terra holds the floor-grab pose (TombPhase "Cast", which is also her
--            Bedrock window and her speed cap); after GripTime a fissure leaves her and HOMES on the target's ground
--            position at FissureSpeed, re-aimed every tick, so running, turning and dashing never lose it. When its
--            head reaches them (CatchReach x CatchMargin) the one question is: are they AIRBORNE, on this server's copy
--            of their body? Airborne = DODGED: it ends there, nothing spent by either side, Terra straight back to
--            normal. A target who jumped early and has landed again is simply caught.
--   CATCH    the Ultimate charge is spent now. The target is ENTOMBED (RX_Entombed and the status tag) and held by an
--            AlignPosition over the plinth erupting under them -- Cryo Beam's lift, which keeps their own physics and
--            camera. Terra's phase moves on, and with it her pose and her Bedrock window end: she is done.
--   RISE     the target climbs RiseHeight over RiseTime (TerraFX.TombRise), alone. Every tick their way out is checked:
--            a Mobility Technique the server ACCEPTS from them (the CCBreak stamp, below) -- ESCAPED: let go that
--            instant, and the pillar goes straight down with nobody on it; no timer is run out.
--   BURST    at the top, still caught: BurstDamage x CritMultiplier through CombatCore, flagged Crit, and ENTOMBED!.
--   DESCENT  the pillar comes down with the target on it, and lets them go on the floor. No fall damage anywhere.
-- ENTOMBED HOLDS THE BODY AND NOTHING ELSE. It is deliberately not a speed cap: a root (a cap of 0) refuses the
-- Mobility key outright, and the Mobility key is this status's way out. The target can still shoot back.
-- Once the target is caught the Tomb no longer needs Terra: it runs out even if she falls, and only ends early if she
-- leaves the arena or the game (dropTomb).
local Callouts = require(spellFolder:WaitForChild("Callouts"))

local tombs = {}                                          -- [caster player] = the running Tomb
local entombed = setmetatable({}, { __mode = "k" })       -- [victim model] = its Tomb
-- Aftershock's running casts (its section is below). Declared up here so setPhase can see them (2026-09-25): the Tomb
-- and an Aftershock windup share the one SpeedCapUlt slot, and each side must leave a cap the other still holds alone.
local aftershocks = {}                                    -- [player] = the cast under way: { Character, Humanoid, At, Face, T0, Epoch, ... }

--- Seconds of Tomb time in `dt`: the review slow-motion (ShotTimeScale) runs this Ultimate too.
local function tombDt(dt)
	return dt * VFXLibrary.ShotTimeScale()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function exclusionParams(model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { model }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	params.FilterDescendantsInstances = list
	return params
end

--- The floor under a point, or nil.
local function floorBelow(position, skip, reach)
	return workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -(reach or 40), 0), exclusionParams(skip))
end

--- Whether `model` is STANDING, on this server's copy of it: feet within GroundTolerance of the floor under them.
--- A jump, a glide, a dash's hop -- anything that has them off the ground -- clears it. The client never says.
local function standing(model, root, humanoid)
	local E = T.EarthenTomb
	-- an R6 body's HipHeight is 0 (its legs hang below the root, 2 studs long): its feet by its legs, not its HipHeight
	local legs = humanoid and (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight) or 2
	local feet = root.Position.Y - root.Size.Y / 2 - legs
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(root.Size.Y + 12), 0), exclusionParams(model))
	return hit ~= nil and feet - hit.Position.Y <= E.GroundTolerance
end

--- THE LOCK: the enemy nearest the aim line out of the caster's eye -- within LockRadius of that line (Cross-Slash
--- Dash's lock, LockRange / LockRadius, the one target-lock precedent the game has), in front, no further than the
--- row's Range (+ RangeSlack, for a view a moment old), with nothing solid in between. Every test is on the server's
--- own copy of the world; the client sends only where its crosshair points.
local function acquire(player, character, root, aimAt)
	local E = T.EarthenTomb
	local head = character:FindFirstChild("Head")
	local eye = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local aim = Core.ValidVector(aimAt) and (aimAt - eye) or root.CFrame.LookVector
	if aim.Magnitude < 1e-3 then aim = root.CFrame.LookVector end
	aim = aim.Unit
	local range = ABILITY.EarthenTomb.Range + E.RangeSlack
	local best, bestPerp, bestDist = nil, math.huge, math.huge
	for humanoid, model in pairs(Core.HumanoidsNear(root.Position, range + 4, character)) do
		local r = model:FindFirstChild("HumanoidRootPart")
		-- never a body behind Umbra's Shadow Step veil (2026-09-27)
		if r and not entombed[model] and not Core.IsFriendly(player, model) and not Core.IsVeiled(model) then
			local rel = r.Position - eye
			local along = rel:Dot(aim)
			local perp = (rel - aim * along).Magnitude
			local dist = flat(r.Position - root.Position).Magnitude
			if along > 0 and perp <= E.LockRadius and dist <= range
				and (perp < bestPerp - 0.25 or (perp < bestPerp + 0.25 and dist < bestDist))
				and not Core.Blocked({ Origin = eye, Dir = rel.Unit, Character = character }, rel.Magnitude, model) then
				best, bestPerp, bestDist = model, perp, dist
			end
		end
	end
	return best
end

--- Holds a body where `at` says, facing `face` -- Cryo Beam's lift: an AlignPosition to an anchored point and an
--- AlignOrientation keeping it level, so the player keeps their own physics and camera the whole way up.
local function hold(root, at, face)
	if root.Anchored then
		-- a body the server holds fixed (a range dummy) takes no constraint: it is carried by its pivot instead, and
		-- put back where it stood when it is let go
		local model = root:FindFirstAncestorOfClass("Model")
		return { Model = model, Pivot = model:GetPivot(), Base = at, Carried = true }
	end
	local anchor = Instance.new("Part")
	anchor.Name = "TombLiftAnchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = Core.FxFolder() or workspace
	local a0 = Instance.new("Attachment")
	a0.Name = "TombLiftAttachment"
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local align = Instance.new("AlignPosition")
	align.Attachment0, align.Attachment1 = a0, a1
	align.MaxForce = 1e6
	align.Responsiveness = 60
	align.Parent = root
	local look = flat(face)
	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = a0
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.CFrame = CFrame.lookAt(Vector3.zero, look.Magnitude > 0.1 and look.Unit or Vector3.zAxis)
	orient.MaxTorque = 1e6
	orient.Responsiveness = 30
	orient.Parent = root
	-- (2026-10-19, audit P1-03) while held, the body's physics are the server's (Core.HoldBody: network ownership, players
	-- only -- a dummy is the server's already), so a modified client cannot walk out of the Tomb; letGo gives it back
	local body = root.Parent
	if body and Core.HoldBody then Core.HoldBody(body, "Tomb", true) end
	return { Anchor = anchor, A0 = a0, Align = align, Orient = orient, Base = at, Body = body }
end

local function letGo(lift)
	if not lift then return end
	if lift.Carried then
		-- (a range dummy, anchored: never a player's body, so no Core.AllowMove is needed before this PivotTo)
		if lift.Model.Parent then lift.Model:PivotTo(lift.Pivot) end
		return
	end
	for _, k in ipairs({ "Align", "Orient", "A0", "Anchor" }) do
		if lift[k] then lift[k]:Destroy() end
	end
	-- (2026-10-19, audit P1-03) released on every way out -- the descent's end, an escape, a death, a clear, the caster
	-- leaving (all come through freeVictim); HoldBody's release also opens Core.AllowMove's grace for the drop
	if lift.Body and Core.HoldBody then Core.HoldBody(lift.Body, "Tomb", false) end
end

--- The target's height on the pillar: the only body a Tomb ever moves.
local function setHeight(tomb, h)
	tomb.Height = h
	local lift = tomb.VictimLift
	if lift and lift.Carried then
		if lift.Model.Parent then lift.Model:PivotTo(lift.Pivot + Vector3.new(0, h, 0)) end
	elseif lift and lift.Anchor.Parent then
		lift.Anchor.CFrame = CFrame.new(lift.Base + Vector3.new(0, h, 0))
	end
end

--- The target goes free: the hold released, the status lifted.
local function freeVictim(tomb)
	local model = tomb.Victim
	if not model then return end
	letGo(tomb.VictimLift)
	tomb.VictimLift = nil
	if entombed[model] == tomb then entombed[model] = nil end
	if model.Parent then
		model:SetAttribute("RX_Entombed", false)
		-- ...and the status tag with it (2026-09-21). It was fired once at the catch for the whole rise, hold and
		-- descent and nothing ever took it down, so an escape or a death left ENTOMBED lit over a free body for up
		-- to 2.8 s -- a clock of its own, drifting out of step with the mechanic. Only ours is cleared: a status
		-- somebody else put on them since is theirs.
		if model:GetAttribute("Status") == "Entombed" then
			model:SetAttribute("Status", "")
			model:SetAttribute("StatusExpires", 0)
		end
	end
	tomb.Free = true
end

--- The ONE switch for everything Terra's own body does in a Tomb. TombPhase is the phase the server is in; while it is
--- "Cast" -- from the lock until the catch or the miss, and not a moment either side -- Terra holds the floor-grab pose
--- (CastPose keys off this attribute on every client), builds Bedrock (committing, below) and cannot walk or dash out of
--- the grip (SpeedCapUlt 0). All three are set right here, in the same call that moves the mechanic on, so none of them
--- can run on a clock of its own and drift out of step with it.
local function setPhase(tomb, phase)
	tomb.Phase, tomb.T = phase, 0
	local c = tomb.Character
	if not c.Parent then return end
	c:SetAttribute("TombPhase", phase)
	-- the climb's clock, for the one-arm raise: both animation layers read it and drive the arm off the platform's own
	-- curve rather than a timer of their own (2026-09-20). Set with the phase, cleared with it.
	if phase == "Rise" then
		c:SetAttribute("TombRiseAt", workspace:GetServerTimeNow())
		c:SetAttribute("TombRiseFor", T.EarthenTomb.RiseTime)
	else
		c:SetAttribute("TombRiseAt", nil)
		c:SetAttribute("TombRiseFor", nil)
	end
	if phase == "Cast" then
		c:SetAttribute("SpeedCapUlt", 0)
		tomb.Capped = true
	elseif tomb.Capped then
		-- the slot is shared (2026-09-25): an Ultimate pressed during her own Aftershock windup must not lift the
		-- Aftershock's root when the Cast ends, or she walks off while the slam still plays. The Aftershock lifts it
		-- itself (releaseAftershockRoot) at Hit + RootUntil.
		local shock = aftershocks[tomb.Caster]
		if not (shock and shock.Capped and shock.Character == c) then
			c:SetAttribute("SpeedCapUlt", nil)
		end
		tomb.Capped = false
	end
end

--- The end of a Tomb, however it went: the hold released, every flag down, Terra back to normal.
local function finishTomb(player, tomb)
	if tombs[player] ~= tomb then return end
	tombs[player] = nil
	freeVictim(tomb)
	setPhase(tomb, nil)
end

--- DODGED or called off before a catch: the fissure dies where its head is, and NOTHING is spent -- the charge was
--- never taken (the ability row is ChargeOnCatch).
local function miss(player, tomb, reason)
	broadcast("TombMiss", { Character = tomb.Character, At = tomb.Head, Reason = reason, T0 = workspace:GetServerTimeNow() })
	finishTomb(player, tomb)
end

--- DESCENT with the target still on the pillar: it comes down, and they are let go on the floor.
local function descend(tomb)
	local E = T.EarthenTomb
	tomb.FromHeight = tomb.Height or 0
	setPhase(tomb, "Descent")
	broadcast("TombDescend", { Character = tomb.Character, Victim = tomb.Victim, T0 = workspace:GetServerTimeNow(),
		Time = E.DescendTime, From = tomb.FromHeight })
end

--- Got out, or gone, before the burst: let go THIS instant; the pillar goes straight down empty and the Tomb is over --
--- there is nothing left for a timer to wait on.
local function breakTomb(player, tomb, reason)
	local E = T.EarthenTomb
	freeVictim(tomb)
	local now = workspace:GetServerTimeNow()
	broadcast("TombBreak", { Character = tomb.Character, Victim = tomb.Victim, Reason = reason, T0 = now })
	broadcast("TombDescend", { Character = tomb.Character, Victim = tomb.Victim, T0 = now, Time = E.EscapeDescendTime,
		From = tomb.Height or 0, Early = true })
	finishTomb(player, tomb)
end

--- CATCH: the charge is spent here and only here; the target is Entombed and the plinth takes them up. Terra is done.
local function catch(player, tomb)
	local E = T.EarthenTomb
	local model, vroot, vhum = tomb.Victim, tomb.VictimRoot, tomb.VictimHum
	tomb.Character:SetAttribute("UltCharge", 0)          -- the dev free-Ultimate's heartbeat puts it straight back
	entombed[model] = tomb
	tomb.CaughtAt = workspace:GetServerTimeNow()
	local vFloor = floorBelow(vroot.Position, model)
	local at = vFloor and vFloor.Position or Vector3.new(vroot.Position.X, tomb.Head.Y, vroot.Position.Z)
	-- the target is turned to face Terra, and the plinth's lit side is turned the same way (TerraFX)
	local face = flat(tomb.From - at)
	if face.Magnitude < 0.1 then face = flat(-vroot.CFrame.LookVector) end
	tomb.VictimLift = hold(vroot, vroot.Position, face)
	model:SetAttribute("RX_Entombed_Element", "Terra")
	model:SetAttribute("RX_Entombed", true)
	Core.ApplyStatusTag(vhum, "Entombed", (E.RiseTime + E.BurstHold + E.DescendTime) / VFXLibrary.ShotTimeScale() + 0.3)
	setPhase(tomb, "Rise")                               -- Terra's pose, cap and Bedrock window end on this line
	broadcast("TombCatch", { Character = tomb.Character, Victim = model, At = at, Face = face, T0 = tomb.CaughtAt,
		Rise = E.RiseTime, Height = E.RiseHeight })
end

--- BURST: still caught at the top -- the guaranteed critical hit, and the payoff word.
local function burst(player, tomb)
	local E = T.EarthenTomb
	local model, vhum, vroot = tomb.Victim, tomb.VictimHum, tomb.VictimRoot
	local hit = Core.DealDamage(player, vhum, E.BurstDamage * E.CritMultiplier,
		{ Crit = true, Ultimate = true, From = tomb.From })
	if hit then
		local head = model:FindFirstChild("Head") or vroot
		Callouts.Pop(head, Vector3.new(0, 2.6, 0), "ENTOMBED!", "entombed")
	end
	broadcast("TombBurst", { Character = tomb.Character, Victim = model, Position = vroot.Position, Hit = hit,
		T0 = workspace:GetServerTimeNow() })
	setPhase(tomb, "Burst")
end

local function castEarthenTomb(player, character, humanoid, root, payload)
	if tombs[player] or entombed[character] then return end       -- one at a time, and not from inside one
	local victim = acquire(player, character, root, payload.Target)
	if not victim then return end                                  -- nothing locked: no cast, nothing spent
	local cFloor = floorBelow(root.Position, character)
	local from = cFloor and cFloor.Position or (root.Position - Vector3.new(0, 3, 0))
	local tomb = { Caster = player, Character = character, Humanoid = humanoid, Root = root, From = from, Head = from,
		Victim = victim, VictimHum = victim:FindFirstChildOfClass("Humanoid"), VictimRoot = victim:FindFirstChild("HumanoidRootPart"),
		T0 = workspace:GetServerTimeNow() }
	tombs[player] = tomb
	setPhase(tomb, "Cast")                                         -- Terra takes hold of the floor
	local E = T.EarthenTomb
	broadcast("TombCast", { Character = character, Victim = victim, From = from, T0 = tomb.T0, Grip = E.GripTime,
		Speed = E.FissureSpeed, Reach = E.CatchReach })
end

--- CAST, one tick: the grip, then the head homing on the target's CURRENT ground position -- re-aimed every tick.
local function stepCast(player, tomb, dt)
	local E = T.EarthenTomb
	local c, model, vroot, vhum = tomb.Character, tomb.Victim, tomb.VictimRoot, tomb.VictimHum
	if not (c.Parent and tomb.Humanoid.Health > 0) then return miss(player, tomb, "CasterDown") end
	if not (model.Parent and vroot and vroot.Parent and vhum and vhum.Health > 0)
		or entombed[model] or Core.IsFriendly(player, model) then
		return miss(player, tomb, "Lost")
	end
	-- Umbra's Shadow Step (2026-09-27) breaks the lock: a fissure homing on a veiled body loses it
	if Core.IsVeiled(model) then return miss(player, tomb, "Lost") end
	if tomb.T < E.GripTime then return end
	if tomb.T > E.GripTime + E.MaxTravel then return miss(player, tomb, "Outrun") end
	local reach = E.CatchReach * E.CatchMargin
	local toward = flat(vroot.Position - tomb.Head)
	local dist = toward.Magnitude
	local move = E.FissureSpeed * (tomb.T - math.max(E.GripTime, tomb.T - dt))   -- the grip's own tick moves only its share
	if dist - move > reach then
		local nextAt = tomb.Head + toward.Unit * move
		local ground = floorBelow(nextAt + Vector3.new(0, 2, 0), model, 12)
		if not ground then return miss(player, tomb, "NoGround") end   -- off an edge: a crack needs a floor to run on
		tomb.Head = Vector3.new(nextAt.X, ground.Position.Y, nextAt.Z)
		return
	end
	-- ARRIVED: its leading edge is on them. Standing is caught; airborne dodged it.
	if dist > reach then tomb.Head += toward.Unit * (dist - reach) end
	if standing(model, vroot, vhum) then
		catch(player, tomb)
	else
		miss(player, tomb, "Airborne")
	end
end

local function stepTomb(player, tomb, dt)
	local E = T.EarthenTomb
	tomb.T += dt
	if tomb.Phase == "Cast" then
		stepCast(player, tomb, dt)
		return
	end
	local model = tomb.Victim
	local held = tomb.VictimLift ~= nil
	local gone = not (model.Parent and tomb.VictimHum.Health > 0 and tomb.VictimRoot.Parent)
	local out = held and (model:GetAttribute("CCBreak") or 0) > tomb.CaughtAt
	if tomb.Phase == "Rise" then
		if gone then
			breakTomb(player, tomb, "Lost")
		elseif out then
			breakTomb(player, tomb, "Escape")          -- ESCAPED: a Mobility Technique got them out
		else
			local u = math.min(1, tomb.T / E.RiseTime)
			setHeight(tomb, E.RiseHeight * TerraFX.TombRise(u))
			if u >= 1 then burst(player, tomb) end
		end
		return
	end
	-- after the burst: an escape or a death still lets go at once; the pillar carries on down regardless
	if held and (gone or out) then freeVictim(tomb) end
	if tomb.Phase == "Burst" then
		if tomb.T >= E.BurstHold then descend(tomb) end
	elseif tomb.Phase == "Descent" then
		local u = math.min(1, tomb.T / E.DescendTime)
		setHeight(tomb, tomb.FromHeight * (1 - u * u))
		-- held a moment at the bottom before letting go, so the body is back on its feet -- not dropped the last
		-- stretch because it trailed its anchor on the way down
		if tomb.T >= E.DescendTime + 0.2 then finishTomb(player, tomb) end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local step = tombDt(dt)
	for player, tomb in pairs(tombs) do
		local ok, err = pcall(stepTomb, player, tomb, step)
		if not ok then
			warn("[TerraHandler] Earthen Tomb: " .. tostring(err))
			broadcast("TombMiss", { Character = tomb.Character, T0 = workspace:GetServerTimeNow() })
			finishTomb(player, tomb)
		end
	end
end)

-- THE WAY OUT: a Mobility Technique the server ACCEPTS from an Entombed body stamps CCBreak on it with the server time,
-- and a hold that began earlier than that lets go (stepTomb). The game's one "Mobility breaks crowd control" hook -- it
-- was written for the first Earthen Tomb, since nothing earlier had one, and this build keeps it rather than adding
-- another. (2026-10-19, audit P4-14: it said "a root refuses the Mobility key outright", which is not so -- only a
-- Charges cast checks the cap, in SpellshotService; Mark, Position Trade, Vent and the rest cast while rooted.)
-- Anything else that should free a body -- a future cleanse, a dev tool -- can stamp the same attribute. The Technique itself goes on as normal and is paid for as normal: its cooldown,
-- charge or mana is the whole price of getting out.
--- 2026-09-21: the stamp used to go on ANY performCast in the Mobility role, which made the escape free. Two ways:
--- the AimWhileHeld keep-alive packet is a performCast that costs nothing and starts nothing, and a Tremor Vault
--- with nowhere to burrow gives the whole cast back (mana, cooldown and hold) and still broke the hold. Above about
--- nine studs the give-back is GUARANTEED -- the floor probe is a fixed 12-stud ray from a root the Tomb is holding
--- in the air -- so from there up every Entombed Terra walked out for nothing. So: only a fresh press counts, and
--- Tremor Vault stamped its own once the burrow was real, not before it knew it could.
--- 2026-09-24 (v0.7): either Technique slot may hold any Technique, so the escape keys off the ABILITY, not the slot: a
--- movement Technique (its row's Role is "Mobility") pressed from Q or E. Detonate and Scorching Lash are no escape.
--- 2026-09-25: Aftershock replaces Tremor Vault in the list, and is no escape AT ALL -- it roots its own caster and
--- moves everyone else, so it has nothing to get anybody out of a hold with (and its Precheck refuses an Entombed
--- caster before anything is paid).
performCast.Event:Connect(function(player, role, ability, payload)
	if role ~= "Mobility" and role ~= "Defense" then return end
	if not (ability and ability.Role == "Mobility") then return end
	local phase = type(payload) == "table" and payload.Phase or nil
	if phase == "Aim" or phase == "Release" then return end
	if ability.Id == "Aftershock" or ability.Id == "Detonate" or ability.Id == "ScorchingLash" or ability.Id == "Blizzard"
		or ability.Id == "Railspike" then return end   -- Voltaic (2026-09-25): a standing windup is no escape either
	local character = player.Character
	if character and entombed[character] then
		character:SetAttribute("CCBreak", workspace:GetServerTimeNow())
	end
end)

----------------------------------------------------------------------------------------------------
-- MOBILITY: AFTERSHOCK (2026-09-25, replacing Tremor Vault)
----------------------------------------------------------------------------------------------------
-- The Blender showcase (blender_scripts/terra/aftershock_bl.py, vfx_blocking/terra/aftershock/NOTES_aftershock.md)
-- brought into the game as Terra's Mobility Technique; the build contract is vfx_blocking/terra/aftershock/PORT_SPEC.md.
-- Tremor Vault went with it, deleted rather than disabled (the Glacial Spikes precedent): the burrow, the hidden body,
-- its collision group and its priority-0 Burrowed modifier. The Burrowed guards in other scripts are dormant now, and
-- the TerraVault meshes stay in the place, unreferenced. It sits down here, below the Tomb, because it reads `flat`,
-- `entombed` and `tombs`, which are declared there.
--   THE PRESS  asked first, before anything is paid (Precheck_Aftershock): alive, not Entombed, not already in one, and
--              a floor within GroundBelow under the feet -- anything else is refused and costs nothing. Accepted, the
--              SERVER fixes the whole cast at once and says so once ("Aftershock"): T0 (server time), the flat facing,
--              the centre (the floor Reach ahead, where both fists land) and a Seed. Nothing in the payload is read.
--   WINDUP     the caster is held in place (SpeedCapUlt 0) from the key to Hit + RootUntil. Until the fists land (Hit)
--              the cast can still be CUT -- the caster dies, is cleared, is Entombed, or is interrupted by somebody
--              else -- and then it ends outright (AftershockEnd): nothing more is drawn or dealt.
--   THE RING   at Hit the contact frame is held HoldFrames/60 (the hitpause), and THEN the front leaves: its radius is
--              TerraFX.AftershockFrontR(TerraFX.AftershockRingTau(t)), the curve every client draws on the same clock,
--              so the rock seen coming up under a body and the hit agree. Past Hit it is committed and runs out even
--              if its caster falls (as Flash Freeze and Ring of Fire do); only a clear (the arena left, a duel round
--              reset) or leaving the game stops it.
--   A STRIKE   a body the front reaches (flat distance from the centre, within BodyRadius) with its FEET on the floor
--              (HitBelow under the centre's floor to HitAbove over it) takes Damage through CombatCore; if that landed
--              it is thrown out from the centre and up (x the front's strength where it stood) and INTERRUPTED: every
--              held ability ends, a Boulder charge or a Bulwark Charge is dropped, and casting is refused for
--              InterruptTime (InterruptedUntil, Undertow's mechanism). A Bulwark Wall, or a body an Earthen Tomb is
--              holding, takes the damage and nothing else. No Status tag, and never RX_Staggered (Bulwark's stars).
--   JUMP IT    a body in the air while the front passes under it is spared: once the front is BodyRadius beyond it
--              and it was never struck, it has jumped it (Earthen Tomb's "jump it"), and landing later does not count.
-- Every number is TerraFX.Tuning.Aftershock, shared with the clients. EVERY NUMBER HERE IS A PROPOSAL.
-- (`aftershocks`, the running casts, is declared with `tombs` above: the Tomb's setPhase reads it.)
local AFTERSHOCK_ROLES = { "M1", "Primary", "Mobility", "Defense", "Ultimate" }

--- The floor under `origin`, at most `reach` studs down, or nil. Every body -- a player, a training dummy, a Bulwark
--- Wall -- is looked through (a body is not floor), and so is the FX folder. The filter is built up rather than written
--- as a literal (a nil in a literal leaves a hole in it). Callers never start it high: from the root's height, so a
--- roof or a bridge over the caster is never taken for the floor.
local function aftershockFloor(origin, reach)
	local list = {}
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list + 1] = p.Character end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, Vector3.new(0, -reach, 0), params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit end
		params:AddToFilter(model)
	end
	return nil
end

--- How far a body's feet are under its root: HipHeight plus half the root (Frost Slide's patch test). An R6 body's
--- HipHeight is 0 (its legs hang below the root, 2 studs long), as standing() above has it (2026-09-25).
local function feetUnderRoot(root, humanoid)
	local legs = humanoid and (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight) or 2
	return root.Size.Y / 2 + legs
end

--- The floor under the caster's feet (GroundBelow at most), or nil: mid-air, or over a drop, there is none.
local function aftershockGround(root, humanoid)
	return aftershockFloor(root.Position, feetUnderRoot(root, humanoid) + T.Aftershock.GroundBelow)
end

-- SpellshotService asks this BEFORE it charges an Aftershock press (Precheck = true on the row): true only for a
-- caster who is alive, not Entombed, not already in an Aftershock and has a floor under their feet -- so a press in
-- the air, or from inside a Tomb, costs nothing at all. Detonate's arrangement (PyroHandler): built whole, its answer
-- set first and parented last, and anything but a plain true refuses. It must not yield, and it does not (raycasts).
do
	local precheck = spellFolder:FindFirstChild("Precheck_Aftershock")
	local fresh = not (precheck and precheck:IsA("BindableFunction"))
	if fresh then
		precheck = Instance.new("BindableFunction")
		precheck.Name = "Precheck_Aftershock"
	end
	precheck.OnInvoke = function(player)
		local character, humanoid, root = Core.AliveCharacter(player)
		if not character or entombed[character] or aftershocks[player] then return false end
		return aftershockGround(root, humanoid) ~= nil
	end
	if fresh then precheck.Parent = spellFolder end
end

--- The caster's hold in place ends: SpeedCapUlt comes off -- but only while it is still OURS (Earthen Tomb's Capped
--- pattern): the attribute is one shared slot, and a cap the caster's own Earthen Tomb has put on since (TombPhase
--- "Cast", holding the floor) is the Tomb's to lift.
local function releaseAftershockRoot(player, s)
	if not s.Capped then return end
	s.Capped = false
	local c = s.Character
	local tomb = tombs[player]
	if c.Parent and c:GetAttribute("SpeedCapUlt") == 0 and not (tomb and tomb.Phase == "Cast") then
		c:SetAttribute("SpeedCapUlt", nil)
	end
end

--- The end of a cast, however it went. `reason` goes out (AftershockEnd) only for a cast cut BEFORE the fists landed:
--- after the slam every client has the ring and runs it out on its own clock, so there is nothing to take back.
local function endAftershock(player, s, reason)
	if aftershocks[player] ~= s then return end
	aftershocks[player] = nil
	releaseAftershockRoot(player, s)
	if reason and not s.Slammed then
		broadcast("AftershockEnd", { Character = s.Character, Reason = reason })
	end
end

--- The same, only if the fists have not landed yet: death cuts the windup, but a ring already out runs on.
local function cutAftershock(player, reason)
	local s = aftershocks[player]
	if s and not s.Slammed then endAftershock(player, s, reason) end
end

local function tell(player, kind, data)
	pcall(function() remote:FireClient(player, "VFX", kind, data) end)
end

--- THE KNOCK, copied from AquaHandler (moveDummy / carryDummy / launch, 2026-09-24), where they are local. A player's
--- body is its own client's to move, so it is SENT the throw (AftershockKnock) and its client drives it; a dummy the
--- server simulates takes a server mover; a range dummy the server holds fixed (Anchored) is carried by its pivot.
local function serverOwned(root)
	if root.Anchored then return false end
	local ok, owner = pcall(function() return root:GetNetworkOwner() end)
	return ok and owner == nil
end

local function moveDummy(root, velocity, seconds, forcePerMass)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AftershockMoveAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "AftershockMove"
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

--- A range dummy is flown along `path(t)` (an offset from where it stood) for `seconds`, then put back where it stood
--- `back` seconds later -- so the range shows the throw without the dummy wandering off its spot.
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

--- INTERRUPTED (Undertow's mechanism, AquaHandler.interrupt): whatever the victim holds ends -- its cooldown starts, as
--- a release would start it -- a Boulder charge being gathered or a Bulwark Charge under way is dropped, and casting is
--- refused for InterruptTime (InterruptedUntil, which SpellshotService's gate and CombatCore.CanAct honour). A longer
--- interrupt already running is not shortened.
local function interruptVictim(victim)
	local c = victim.Character
	if not c then return end
	for _, role in ipairs(AFTERSHOCK_ROLES) do
		-- the reason rides along, as AquaHandler.interrupt sends it (audit P4-05): a listener that does not read it treats
		-- this as the release it always was
		if c:GetAttribute("Holding_" .. role) then releaseHold:Fire(victim, role, "Interrupted") end
	end
	if charging[victim] then stopCharge(victim, false, "Interrupted") end
	if charges[victim] then endCharge(victim) end
	local untilT = math.max(workspace:GetServerTimeNow() + T.Aftershock.InterruptTime, c:GetAttribute("InterruptedUntil") or 0)
	c:SetAttribute("InterruptedUntil", untilT)
	-- (2026-10-19, audit P4-06) ...and the victim's own client hears it: the holds above ended on this server only, so an
	-- Aqua's Sidearm stayed drawn on their screen and kept sending shots the server threw away. AquaInterrupted is
	-- Undertow's message for exactly this (AquaClient drops the gun; nothing else reads it yet)
	tell(victim, "AquaInterrupted", { Until = untilT })
end

--- A body the front reached with its feet on the floor. Damage first; everything else only if it landed.
local function strike(player, s, humanoid, model, vroot, d, feet)
	local A = T.Aftershock
	if not Core.DealDamage(player, humanoid, A.Damage, { From = s.At }) then return end
	-- a wall takes the damage and nothing else; so does a body the Tomb is holding (its AlignPosition would win anyway)
	if Core.IsWall(model) or entombed[model] then return end
	local dir = flat(vroot.Position - s.At)
	dir = dir.Magnitude > 0.05 and dir.Unit or s.Face
	-- the shard comes up under their feet, on the floor they stand on (read before the knock moves them)
	local ground = aftershockFloor(Vector3.new(vroot.Position.X, feet + 1, vroot.Position.Z), A.HitBelow + 2)
	local at = Vector3.new(vroot.Position.X, ground and ground.Position.Y or s.At.Y, vroot.Position.Z)
	-- thrown out from the centre and up, as hard as the front was still going where it caught them
	local k = math.max(A.KnockMin, TerraFX.AftershockStrength(d))
	local velocity = dir * (A.KnockOut * k) + Vector3.new(0, A.KnockLift * k, 0)
	local now = workspace:GetServerTimeNow()
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		tell(victim, "AftershockKnock", { Velocity = velocity, Until = now + A.KnockTime, Center = s.At, Caster = player })
		-- (2026-10-19, audit P4-04) the throw and its fall are not Updraft's air (ZephyrUpdraftServer)
		markKnocked(model, A.KnockTime + math.clamp(2 * math.max(velocity.Y, 0) / workspace.Gravity, 0.35, 1.4) + 0.3)
		interruptVictim(victim)
	elseif serverOwned(vroot) then
		moveDummy(vroot, velocity, A.KnockTime, A.KnockForcePerMass)
	elseif vroot.Anchored then
		-- a range dummy: flown on the throw's arc until it comes back down to where it stood (AquaHandler.launch)
		local g = workspace.Gravity
		local air = math.clamp(2 * math.max(velocity.Y, 0) / g, 0.35, 1.4)
		carryDummy(model, function(t)
			return Vector3.new(velocity.X * t, math.max(0, velocity.Y * t - 0.5 * g * t * t), velocity.Z * t)
		end, air, 0.6)
	end
	broadcast("AftershockStrike", { Character = s.Character, Victim = model, At = at, Dir = dir, T0 = now })
end

local function castAftershock(player, character, humanoid, root, payload)
	-- the payload is never read: no phase, no position -- the server's own copy of the body decides the whole cast
	if aftershocks[player] or entombed[character] then return end        -- (the Precheck refused both before paying)
	local A = T.Aftershock
	local t0 = workspace:GetServerTimeNow()
	local face = flat(root.CFrame.LookVector)
	face = face.Magnitude > 1e-3 and face.Unit or Vector3.new(0, 0, -1)
	-- the centre: the floor where both fists land, Reach ahead -- or, if there is none there (the edge of a drop), the
	-- floor under the feet carried out to that spot, so the ring never starts below the floor she is standing on
	local under = aftershockGround(root, humanoid)
	local floorY = under and under.Position.Y or (root.Position.Y - feetUnderRoot(root, humanoid))
	local ahead = root.Position + face * A.Reach
	local hit = aftershockFloor(ahead, feetUnderRoot(root, humanoid) + A.GroundBelow)
	local at = hit and hit.Position or Vector3.new(ahead.X, floorY, ahead.Z)
	local seed = math.random(1, 2 ^ 30)
	local s = {
		Character = character, Humanoid = humanoid, At = at, Face = face, T0 = t0, Epoch = Core.Epoch(player),
		Interrupted = character:GetAttribute("InterruptedUntil"),  -- a later change to it is somebody interrupting her
		Done = {},              -- [model] = true: struck, or jumped it -- either way the front is done with them
		PrevR = 0,              -- the front's radius on the last tick
		Capped = true,
	}
	aftershocks[player] = s
	broadcast("Aftershock", { Character = character, At = at, Face = face, T0 = t0, Seed = seed })
	-- both hands go into the ground, so a rock already gathered is DROPPED (as Tremor Vault dropped it), and her own
	-- client hears it as an interrupt
	stopCharge(player, false, "Interrupted")
	-- held in place from the key to just after the slam (Hit + RootUntil): the shared ultimate cap slot, owned as
	-- Earthen Tomb owns it (releaseAftershockRoot)
	character:SetAttribute("SpeedCapUlt", 0)
end

--- One tick of a cast, on the clock every client draws it on: t is seconds since the key (x the review slow-motion).
local function stepAftershock(player, s)
	local A = T.Aftershock
	local c = s.Character
	-- the caster left the arena, or a duel round was reset: it stops, and nobody else is struck (Flash Freeze's rule)
	if Core.Epoch(player) ~= s.Epoch then return endAftershock(player, s, "Cleared") end
	local t = (workspace:GetServerTimeNow() - s.T0) * VFXLibrary.ShotTimeScale()
	if not s.Slammed then
		-- THE WINDUP, still cuttable: health, not Parent (a corpse keeps its Parent for the whole respawn window)
		local reason
		if not (c.Parent and s.Humanoid.Health > 0) then
			reason = "Died"
		elseif entombed[c] then
			reason = "Entombed"
		else
			local cut = c:GetAttribute("InterruptedUntil")
			if cut ~= s.Interrupted and (cut or 0) > s.T0 then reason = "Interrupted" end
		end
		if reason then return endAftershock(player, s, reason) end
		if t < A.Hit then return end
		s.Slammed = true            -- the fists are in the ground: from here the ring is committed
	end
	if s.Capped and TerraFX.AftershockClock(t) >= A.Hit + A.RootUntil then releaseAftershockRoot(player, s) end
	local tau = TerraFX.AftershockRingTau(t)
	if tau < 0 then return end      -- the hitpause: the front has not left yet
	-- FrontR clamps tau to [0, RingTime], so the tick that ends the ring still sweeps out to the full Radius however late
	-- it runs: the sweep comes first and the end after it, so a server hitch over the last frames spares nobody
	-- (2026-09-25)
	local r = TerraFX.AftershockFrontR(tau)
	local reach = r + A.BodyRadius
	-- only the BAND the front swept since the last tick strikes (PrevR - BodyRadius out to r + BodyRadius), never the
	-- whole disk: a body found behind the front -- one that teleported in, dropped in from above or respawned inside the
	-- ring after it went by -- is not struck from a front every client drew further out. The band grows to cover all
	-- of the ground between two ticks, so a hitch still skips nobody (2026-09-25)
	local inner = s.PrevR - A.BodyRadius
	for humanoid, model in pairs(Core.HumanoidsNear(s.At + Vector3.new(0, 2.5, 0), reach + 2, c)) do
		if not s.Done[model] then
			local vroot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if vroot then
				local d = flat(vroot.Position - s.At).Magnitude
				if d < inner then
					-- the front is already BodyRadius beyond them and they were never struck: off the floor while it
					-- passed (jumped it), or not there when it did -- either way it is done with them
					s.Done[model] = true
				elseif d <= reach and d <= A.Radius + A.BodyRadius then
					local feet = vroot.Position.Y - feetUnderRoot(vroot, humanoid)
					local dy = feet - s.At.Y
					if dy >= -A.HitBelow and dy <= A.HitAbove then
						s.Done[model] = true
						strike(player, s, humanoid, model, vroot, d, feet)
					end
				end
			end
		end
	end
	s.PrevR = r
	if tau >= A.RingTime then endAftershock(player, s) end
end

RunService.Heartbeat:Connect(function()
	for player, s in pairs(aftershocks) do
		local ok, err = pcall(stepAftershock, player, s)
		if not ok then
			warn("[TerraHandler] Aftershock: " .. tostring(err))
			endAftershock(player, s, "Cleared")
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- PASSIVE: BEDROCK
----------------------------------------------------------------------------------------------------
-- Two layers, which is how the manual describes it.
--   FLAT     always on while you are Terra. This is the "why a slow Element survives being walked at" layer,
--            and it is the only mitigation in the game that costs nothing and can never be taken away.
--   STACKS   built only while you are COMMITTED to an attack -- holding a Boulder Shot charge, or mid Bulwark
--            Charge -- and lapsing a moment after you stop. Commit longer, take less.
-- The count lives on the character as Bedrock_Stacks (every client draws the plates from it) and as
-- Stacks_Passive / StacksMax_Passive, published for the HUD's passive chip, which draws them as a row of pips
-- (2026-10-19, audit GA-10: PopArtHUD).
local bedrock = {}         -- [player] = { Character, Stacks, Fed (os.clock of the last committing frame) }

local function bedrockRecord(player, character)
	local b = bedrock[player]
	if not b or b.Character ~= character then
		b = { Character = character, Stacks = 0, Fed = 0, Part = 0 }
		bedrock[player] = b
	end
	return b
end

local function publishBedrock(b)
	local character = b.Character
	if not character.Parent then return end
	local stacks = math.floor(b.Stacks)
	-- compared like for like (2026-09-21): at zero stacks the attribute is REMOVED, so the guard read nil ~= 0 and
	-- was true on every single Heartbeat -- four writes a frame for every Terra, and RX_Shielded republished false
	-- on top of whatever else had just set it
	local shown = character:GetAttribute("Bedrock_Stacks") or 0
	if shown ~= stacks then
		character:SetAttribute("Bedrock_Stacks", stacks > 0 and stacks or nil)
		character:SetAttribute("Stacks_Passive", stacks)
		-- (2026-10-27) Bedrock is the only kit that writes RX_Shielded since Cinder Shield left the game
		if stacks > 0 then
			character:SetAttribute("RX_Shielded_Element", "Terra")
			-- (2026-10-19, audits GA-02 / GA-06) Bedrock is armour (a share off each hit), with no pool to publish as
			-- RX_Shielded_Amount, so BarFX reads it as "unknown": full, no hits. And its lapse is never a payoff
			character:SetAttribute("RX_Shielded_Paid", false)
			character:SetAttribute("RX_Shielded", true)
		else
			character:SetAttribute("RX_Shielded", false)
		end
	end
end

--- True while `player` is committed to an attack: gathering a boulder, mid charge, or -- the third trigger -- holding
--- Earthen Tomb's cast: the floor-grab window, TombPhase "Cast", from the lock until the catch or the miss (v2,
--- 2026-09-19; the first Tomb fed it through the whole climb, which Terra no longer rides). The same phase drives her
--- pose and her speed cap (setPhase). This is the one place Bedrock decides; the Tomb adds its case here rather than
--- running a shield of its own.
local function committing(player)
	local tomb = tombs[player]
	return chargeHeld(player) ~= nil or charges[player] ~= nil
		or (tomb ~= nil and tomb.Phase == "Cast")
end

RunService.Heartbeat:Connect(function(dt)
	local B = T.Bedrock
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.Parent and isTerra(player) then
			local b = bedrockRecord(player, character)
			if character:GetAttribute("StacksMax_Passive") ~= B.MaxStacks then
				character:SetAttribute("StacksMax_Passive", B.MaxStacks)
			end
			if committing(player) then
				b.Part += dt
				while b.Part >= B.StackEvery and b.Stacks < B.MaxStacks do
					b.Part -= B.StackEvery
					b.Stacks += 1
				end
				b.Fed = now
			elseif b.Stacks > 0 and now - b.Fed >= B.Lapse then
				-- they lapse together, a moment after you stop committing, rather than ticking down one by one
				b.Stacks, b.Part = 0, 0
			end
			publishBedrock(b)
		-- (2026-10-19, audit GA-10) also at 0 stacks: StacksMax_Passive alone would keep the HUD's five dark pips after an
		-- Element change; RX_Shielded is only Bedrock's to drop when it had stacks up
		elseif character and (character:GetAttribute("Bedrock_Stacks") or character:GetAttribute("StacksMax_Passive")) then
			local hadStacks = character:GetAttribute("Bedrock_Stacks") ~= nil
			character:SetAttribute("Bedrock_Stacks", nil)
			character:SetAttribute("Stacks_Passive", nil)
			character:SetAttribute("StacksMax_Passive", nil)
			if hadStacks then character:SetAttribute("RX_Shielded", false) end
			bedrock[player] = nil
		end
	end
end)

-- The mitigation itself. Priority 1: Bedrock is armour, so it comes off the top, before Bulwark Charge's
-- reduction and before anything that soaks.
Core.AddModifier(1, function(victim, amount)
	local player = Players:GetPlayerFromCharacter(victim.Parent)
	if not (player and isTerra(player)) then return amount end
	local B = T.Bedrock
	local b = bedrock[player]
	local stacks = (b and b.Character == victim.Parent) and math.floor(b.Stacks) or 0
	return amount * (1 - math.min(0.9, B.Flat + B.PerStack * stacks))
end)

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
local casts = {
	BoulderShot = castBoulderShot,
	BulwarkCharge = castBulwarkCharge,
	BulwarkWall = castBulwarkWall,          -- a Technique: whoever has it equipped, whatever their Element
	Aftershock = castAftershock,            -- a Technique, likewise (2026-09-25, replacing Tremor Vault)
	EarthenTomb = castEarthenTomb,          -- a Technique: whoever has it equipped, whatever their Element
}

performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return end
	-- the slot rides along as a sixth argument (AbilityHandler's way), for a cast that has to give itself back
	fn(player, character, humanoid, root, type(payload) == "table" and payload or {}, role)
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
-- An Earthen Tomb its caster can no longer run (they left the game or the arena, the round was reset) ends outright:
-- the target let go, the pillar straight down. One whose TARGET goes is handled by the Tomb itself on its next tick.
local function dropTomb(player)
	local tomb = tombs[player]
	if not tomb then return end
	if tomb.Phase == "Cast" then
		miss(player, tomb, "Dropped")
	else
		breakTomb(player, tomb, "Dropped")
	end
end

--- ...and the OTHER side of it: a player who is somebody else's VICTIM, cleared or gone. Until 2026-09-21 nothing
--- freed them -- dropTomb only knows the Tomb a player is CASTING, and the Tomb's own per-tick exits are death and
--- CCBreak, neither of which a zone change trips. The lift is an AlignPosition at 1e6 force onto an anchored part
--- in the arena, so a victim teleported to the Hub was dragged back out of it, still Entombed. AbilityHandler's own
--- clear listener already strips what other people's abilities left on a cleared player; this is the Tomb's share.
local function freeVictimOf(player)
	local character = player.Character
	local tomb = character and entombed[character]
	if not tomb then return end
	local caster = tomb.Caster
	if caster and tombs[caster] == tomb then
		breakTomb(caster, tomb, "Lost")
	else
		freeVictim(tomb)                     -- the caster's record is already gone: just let the body go
	end
end

Players.PlayerRemoving:Connect(function(player)
	shots[player] = nil
	buckets[player] = nil
	lastThrow[player] = nil
	charging[player] = nil
	chargeOffAt[player] = nil
	charges[player] = nil
	dropTomb(player)
	freeVictimOf(player)                    -- ...and let go of them if they were somebody else's victim
	dropWall(player, "Lost")
	if aftershocks[player] then endAftershock(player, aftershocks[player], "Cleared") end
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): a charge being gathered is dropped and
-- boulders in flight land nowhere. An Aftershock stops too: cut, if the fists have not landed; a ring already out
-- strikes nobody else (Flash Freeze's rule for a clear).
Core.OnClear(function(player)
	stopCharge(player)
	endCharge(player)
	shots[player] = nil
	dropTomb(player)
	freeVictimOf(player)                    -- ...and let go of them if they were somebody else's victim
	endWallHold(player, "Lost")
	if aftershocks[player] then endAftershock(player, aftershocks[player], "Cleared") end
end)

-- Death ends a gathered charge exactly as a key-up does. Nothing used to (2026-09-21): every liveness test on the
-- charge path read Character.Parent, which a corpse satisfies for the whole respawn window, so the rock went on
-- growing in the dead hand on every other client and Bedrock kept plating the body.
-- ...and an Aftershock whose fists have not landed yet is cut (2026-09-25); a ring already out runs on.
local function watchDeath(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			stopCharge(player)
			cutAftershock(player, "Died")
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		stopCharge(player)
		endCharge(player, true)
		cutAftershock(player, "Died")
	end)
	player.CharacterAdded:Connect(function(character) watchDeath(player, character) end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterRemoving:Connect(function()
		stopCharge(player)
		endCharge(player, true)
		cutAftershock(player, "Died")
	end)
	player.CharacterAdded:Connect(function(character) watchDeath(player, character) end)
	if player.Character then task.spawn(watchDeath, player, player.Character) end
end
