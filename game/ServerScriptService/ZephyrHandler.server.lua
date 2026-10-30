--[[
	ZephyrHandler  (Script)  ->  ServerScriptService/ZephyrHandler

	The gameplay side of the Zephyr kit's M1, Primary and Ultimate: WIND BLADE (2026-09-15), CROSS-SLASH DASH
	(2026-09-16) and CYCLONE (2026-09-17). ZephyrFX draws them (since the v6 import, 2026-10-06, through ZephyrFX_WindBlade /
	ZephyrFX_CrossSlash / ZephyrFX_Cyclone on ZephyrDraw -- the glow look; nothing here changed for it). Their numbers are
	ZephyrFX.Tuning, shared with the client. Every one is a stand-in (the manual sets the behaviour, not the figures).

	THE v6 IMPORT (2026-10-06) moved the rest of the kit out of this script:
	  * DEFLECT GUST and GUST JUMP are retired -- their sections, their remote actions (GustJumpAgain, GustJumpHover) and
	    their dispatch entries are gone (the pre-import script: D:/voltkit_scratch/_backups/roblox_studio_2026-10-06/).
	  * Their replacements run in Scripts of their own: SKYRIDER (Mobility) in ZephyrSkyriderServer, GUST PAD (Defense) in
	    ZephyrGustPadServer, and UPDRAFT (the Passive) in ZephyrUpdraftServer. Each listens to PerformCast for its own Id.
	  * UPDRAFT'S KNOCKBACK: every Zephyr knockback this script gives is multiplied by ZephyrUpdraft.KnockbackScale(player)
	    (updraftKnockScale, below: 1 when the module is missing or fails). Today there is none -- Wind Blade and the X hurt
	    without pushing, and Cyclone's pull is a hold, not a knockback (CyclonePullVelocity, kept verbatim) -- so the scale
	    is wired for the next one and changes nothing yet.

	  M1   Wind Blade   a very fast, light shot that PIERCES: it passes through up to Pierce characters in a line and
	                    hurts each once; anything else stops it. The shooter's client reports each character its own
	                    blade passes through, and what stops it (WindBladeRelease / WindBladeHit); this checks every
	                    report against the LINE -- Icicle Shard and Fireball's arrangement, with one change: a shot is
	                    kept after a hit, for the next character, until it is spent, stopped or too old.

	  PRIMARY   Cross-Slash Dash (2026-09-16)   the charge (forearms cross), a glide along the aim with the hands behind
                    and an X stamped at the Trigger onto whatever is in reach ahead. Since 2026-09-17 it is HELD (the
                    key's hold charges the distance, the release launches it: SpellshotService's held path), aimed in
                    3D at the crosshair's point, and the glide passes straight through characters, hurting each one
                    it passes. The caster's client moves the body (DashMotor) and reports what the glide and the X
                    caught (CrossSlashStrike); this checks the hold, the launch, the timing, the dash line and each claim.

	ULTIMATE  Cyclone (2026-09-17)   a tornado at the crosshair's ground spot. The press arrives already paid for (the
                    Ultimate's charge, SpellshotService). It FORMS there for FormTime, following the caster's crosshair
                    (CycloneSteer: range, rate and speed checked here), the caster walking at FormMoveShare of the walk
                    (SpeedCapUlt); then it stands where it formed for ActiveTime, pulling every enemy in its cylinder in
                    and up and hurting them every TickInterval (AIRBORNE), and unwinds. A caught player's own client moves
                    its body (CyclonePull, sent to that player alone); an unanchored dummy is moved here. Its caster dying
                    unwinds it; leaving the arena, a round reset or a new cast ends it at once. Numbers: ZephyrFX.Tuning.Cyclone.

	WHERE CASTS COME FROM: SpellshotService checks and pays for the cast, then fires PerformCast; AbilityHandler,
	PyroHandler, this and the three Zephyr Scripts above each act only on their own ability Ids. Damage goes through
	CombatCore.

	Server -> client (AbilityFX): ("VFX", kind, data) on IceAbilityRemote -- to everyone, except the Cyclone's pull and
	release, which go to the caught player alone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local ZephyrFX = require(iceFolder:WaitForChild("ZephyrFX"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local releaseHold = spellFolder:WaitForChild("ReleaseHold")
local Core = require(script.Parent:WaitForChild("CombatCore"))

local T = ZephyrFX.Tuning
local remote = Core.Remote
local broadcast = Core.Broadcast
local ABILITY = VFXLibrary.AbilityById

--- Whether the ability `player` holds in `role` is the one named.
local function holds(player, role, id)
	local a = VFXLibrary.AbilityFor(player, role)
	return a ~= nil and a.Id == id
end

--- UPDRAFT'S KNOCKBACK (the v6 import, 2026-10-06): the factor every Zephyr knockback this script gives `player`'s hits is
--- multiplied by -- ZephyrUpdraft.KnockbackScale(player) (Tuning.KnockbackMult while that player holds Updraft and is
--- airborne, else 1). Found lazily and guarded: a missing module, a missing function or an error is a scale of 1, so the
--- Passive can never break a hit. A module that is not there yet is looked for again every LookAgain seconds.
local UPDRAFT_LOOK_AGAIN = 5
local updraft, updraftLookedAt = nil, -math.huge
local function updraftModule()
	if updraft == nil and os.clock() - updraftLookedAt >= UPDRAFT_LOOK_AGAIN then
		updraftLookedAt = os.clock()
		local m = iceFolder:FindFirstChild("ZephyrUpdraft")
		if m then
			local ok, mod = pcall(require, m)
			if ok and type(mod) == "table" and type(mod.KnockbackScale) == "function" then
				updraft = mod
			else
				updraft = false
				warn("[ZephyrHandler] ZephyrUpdraft.KnockbackScale unavailable - Zephyr knockbacks unscaled: " .. tostring(mod))
			end
		end
	end
	return updraft or nil
end
local function updraftKnockScale(player)
	local m = updraftModule()
	if not m then return 1 end
	local ok, scale = pcall(m.KnockbackScale, player)
	if ok and type(scale) == "number" and scale == scale and scale > 0 then return scale end
	return 1
end
--- Whether `player` holds Updraft and is airborne by its rule right now; nil when that cannot be asked (no module).
--- A Wind Blade's release snapshots it: the hit is reported a flight and a round trip later, and the Passive's bonus
--- belongs to where the shooter was when the blade left the hand (ZephyrUpdraftServer reads it as info.UpdraftAir).
local function updraftAirborne(player)
	local m = updraftModule()
	if not (m and type(m.Holds) == "function" and type(m.IsAirborne) == "function") then return nil end
	local ok, air = pcall(function() return m.Holds(player) and m.IsAirborne(player) end)
	if not ok then return nil end
	-- (2026-10-19, audit P4-04) air someone else put the body in is not Updraft's (ZephyrUpdraftServer's rule, `thrown`):
	-- an Earthen Tomb holding it, or a knock or an enemy Cyclone still carrying it (KnockedUntil, server time)
	local character = player.Character
	if air == true and character and (character:GetAttribute("RX_Entombed") == true
		or workspace:GetServerTimeNow() < (character:GetAttribute("KnockedUntil") or 0)) then
		return false
	end
	return air == true
end
-- (no knockback here calls it yet: see the header. A new one is `velocity * updraftKnockScale(player)`.)

----------------------------------------------------------------------------------------------------
-- M1: WIND BLADE
----------------------------------------------------------------------------------------------------
-- The click relays the slash -- which hand, and which way it strokes -- so every client can play it and fly that
-- stroke's blade from that hand. The HITS are decided separately, from the release and the shooter's reports (below).
local function castWindBlade(player, character, humanoid, root, payload)
	local dir = payload.Dir
	if Core.ValidVector(dir) and dir.Magnitude > 0.1 then
		dir = dir.Unit
	else
		dir = root.CFrame.LookVector
	end
	broadcast("WindBlade", {
		Character = character, Side = (payload.Side == "L") and "L" or "R",
		Stroke = (payload.Stroke == "Up") and "Up" or "Down", Dir = dir,
	})
end

local shots = {}           -- [player] = { [id] = { Origin, Dir, At, Life, Character, Hit = {[model] = true}, Count } }
local buckets = {}         -- [player] = { Tokens, At }: the fire-rate check

-- The release: the shooter's eye and aim at the moment the flick let go.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "WindBladeRelease" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "WindBlade") then return end
	local character, humanoid, root = Core.CanAct(player)          -- CanAct, not AliveCharacter: not from underground (2026-09-21)
	if not character then return end
	local origin, dir, id = a.Origin, a.Dir, a.Id
	-- id ~= id refuses a NaN Id (2026-10-19, audit P1-11): the write below raised "table index is NaN" (TerraHandler's fix)
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or type(id) ~= "number" or id ~= id
		or dir.Magnitude < 0.1 then
		return
	end
	local now = os.clock()
	-- one blade per FireInterval on average. At eight a second a single late packet is already a full interval, and the
	-- bucket used to refill at EXACTLY the rate the client fires at, with two blades of slack: over a long burst that
	-- is a driftless random walk against a floor, so ordinary jitter threw shots away for good (rej_rate, and then
	-- rej_noshot for the hit that followed, with the blade drawn and flying on the shooter's own screen). It now
	-- refills a little faster than the client can fire and holds four, so only genuine over-rate is refused.
	local b = buckets[player]
	if not b then
		b = { Tokens = 3, At = now }
		buckets[player] = b
	end
	-- 0.92 (ASSUMED): the bucket earns a blade 8% sooner than the client asks for one, so it drifts up to its cap
	-- instead of wandering into the floor. The long-run cap is still a rate, ~9 blades a second rather than 8.3.
	local interval = ABILITY.WindBlade.FireInterval * 0.92 / VFXLibrary.ShotTimeScale()
	b.Tokens = math.min(4, b.Tokens + (now - b.At) / interval)
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
	local mine = shots[player]
	if not mine then
		mine = {}
		shots[player] = mine
	end
	for oldId, shot in pairs(mine) do
		if now - shot.At > shot.Life then mine[oldId] = nil end
	end
	local S = T.WindBlade
	mine[id] = {
		Origin = origin, Dir = dir.Unit, At = now, Character = character, Hit = {}, Count = 0,
		Life = S.Range / (S.Speed * VFXLibrary.ShotTimeScale()) + 1.5,
		Air = updraftAirborne(player),             -- Updraft: airborne at the release (nil: not known, judged at the hit)
	}
	Core.CountShot("release")
end)

-- What the shooter's blade passed through, or stopped on. Checked, then applied. The outcome names are CombatCore's.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "WindBladeHit" or type(a) ~= "table" then return end
	local mine = shots[player]
	local shot = mine and type(a.Id) == "number" and mine[a.Id]
	if not shot then
		Core.CountShot("rej_noshot")
		return
	end
	local S = T.WindBlade
	local now = os.clock()
	if now - shot.At > shot.Life then
		mine[a.Id] = nil
		Core.CountShot("rej_late")
		return
	end
	local part, position = a.Part, a.Position
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
		or not Core.ValidVector(position) then
		Core.CountShot("rej_badpart")
		return
	end
	-- on the line ...
	local rel = position - shot.Origin
	local along = rel:Dot(shot.Dir)
	if along < 0 or along > S.Range + 1 or (rel - shot.Dir * along).Magnitude > S.HitSlack then
		Core.CountShot("rej_offline")
		return
	end
	-- ... and no sooner than the blade could have flown there
	if now - shot.At < along / (S.Speed * VFXLibrary.ShotTimeScale()) - 0.25 then
		Core.CountShot("rej_early")
		return
	end
	local reason, model, humanoid = Core.CheckTarget(part, position, shot.Character)
	if reason == "rej_moved" then
		-- SECOND CHANCE. WasThere measures from the ROOT with 4.5 studs of reach: a contact on an outstretched limb,
		-- a raised head or a scaled avatar can sit outside that and still be a real hit. The claimed part IS the body
		-- part, so ask it directly -- is the point on this part, now?
		local lp = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2 + Vector3.new(1, 1, 1)
		if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then
			reason = nil
			model = part:FindFirstAncestorOfClass("Model")
			humanoid = model and model:FindFirstChildOfClass("Humanoid")
			Core.CountShot("save_moved")
		end
	end
	if reason then
		Core.CountShot(reason)
		return
	end
	if humanoid and shot.Hit[model] then
		Core.CountShot("rej_repeat")                 -- one hurt per character per blade
		return
	end
	-- Core.Blocked ignores characters, so the bodies this blade already passed through are never cover
	if Core.Blocked(shot, along, humanoid and model or part) then
		-- SECOND CHANCE. That line was drawn from the eye the CLIENT claimed. Where the server has the shooter's own
		-- head is the one point it is sure of, and a shooter mid-slide or mid-dash is exactly where the two differ.
		local head = shot.Character:FindFirstChild("Head")
		local saved = false
		if head then
			local rel = position - head.Position
			local d = rel.Magnitude
			if d > 0.5 then
				saved = not Core.Blocked({ Origin = head.Position, Dir = rel / d, Character = shot.Character },
					d, humanoid and model or part)
			end
		end
		if not saved then
			mine[a.Id] = nil
			Core.CountShot("rej_blocked")
			return
		end
		Core.CountShot("save_blocked")
	end
	-- WHAT A HIT ACTUALLY WAS. "hit" counted the floor and the wall that every MISSED blade ends on, so the printed
	-- line read healthy while no body was being cut -- the one number that would have shown this bug. hit_char is
	-- bodies, hit_world is everything else, and a body hit that took nothing off now says why (rej_friendly:
	-- Config.MayHurt or a team; dmg_soaked: a shield ate all of it).
	-- a body is only cut by a PAID blade (2026-10-19, audit P1-12 / GC-14), asked once per blade: a pierce is one shot
	if humanoid then
		if shot.Paid == nil then shot.Paid = Core.TakePaidM1(player) end
		if not shot.Paid then
			mine[a.Id] = nil
			Core.CountShot("rej_unpaid")
			return
		end
	end
	Core.CountShot("hit")
	if humanoid then
		Core.CountShot("hit_char")
		shot.Hit[model] = true
		shot.Count += 1
		local before = humanoid.Health
		if Core.DealDamage(player, humanoid, S.Damage, { Ranged = true, From = shot.Origin, UpdraftAir = shot.Air }) then
			if humanoid.Health >= before then Core.CountShot("dmg_soaked") end
		else
			Core.CountShot("rej_friendly")
		end
		if shot.Count >= S.Pierce then mine[a.Id] = nil end
	else
		Core.CountShot("hit_world")
		mine[a.Id] = nil                             -- anything that is not a character stops the blade
	end
	Core.ShotImpact:Fire(part, position, player)
end)

----------------------------------------------------------------------------------------------------
-- PRIMARY: CROSS-SLASH DASH
----------------------------------------------------------------------------------------------------
-- HELD since 2026-09-17 (SpellshotService's held path). The press arrives as Phase
-- "Start", already checked and paid for, with Holding_Primary set: the CHARGE. This refuses a body that cannot dash
-- (frozen, or slowed under DashMinCap -- a root is a cap of 0: its cooldown starts at once and nothing is drawn, and that
-- client drops its charge when no broadcast comes) and tells everyone (the held wind-up). Phase "Release" is the key
-- coming up -- the cooldown has started -- carrying the LAUNCH the caster's client made (Client: Start, Dir, Dist), or no
-- launch (Client.Cancel: that client dropped its charge; or this script's own end: a round reset, leaving the arena, a
-- root or a freeze, the backstop), which only lets the wind-up go. A launch is checked -- the distance a charged one and
-- no longer than the hold the server measured could charge, the direction a unit vector (any pitch), the start near the
-- server's body -- then kept, and relayed so every client plays the glide. The caster's client moves the body
-- (DashMotor). At the Trigger it reports what its glide passed and what its X caught (CrossSlashStrike); each claim is
-- checked against the corridor the glide swept or the X's reach ahead, both along the 3D dash line, and the server's own
-- copy of the world, then applied once per character.
local charges = {}         -- [player] = { At, Epoch, Character, Reason, Ended }: a charge being held
local slashes = {}         -- [player] = { At, Epoch, Start, Dir, Right, Up, Dist, Glide, Character, Hit = {[model] = true}, Struck }

local function capOf(character)
	return math.min(character:GetAttribute("SpeedCapSlow") or math.huge, character:GetAttribute("SpeedCapUlt") or math.huge)
end

-- the rules the caster's client drops a charge on, as far as this side can see them
local function cannotDash(character)
	return character:FindFirstChild("IceFrozenState") ~= nil or capOf(character) < T.CrossSlash.DashMinCap
end

--- Ends a charge from this side: its cooldown starts (as a release would start it), and the release comes back here with
--- no launch.
local function endCharge(player, reason)
	local c = charges[player]
	if not c or c.Ended then return end
	c.Reason, c.Ended = reason, true
	local character = player.Character
	if character and character:GetAttribute("Holding_Primary") == "CrossSlashDash" then
		releaseHold:Fire(player, "Primary")          -- SpellshotService starts the cooldown and hands the release back here
	else
		charges[player] = nil
	end
end

--- The distance a key held `held` seconds charges (the caster's client's rule).
local function chargedDistance(held)
	local S = T.CrossSlash
	return S.MinDistance + (S.MaxDistance - S.MinDistance) * math.clamp(held / S.FullChargeTime, 0, 1)
end

-- a launch this refuses: its cooldown has already started; nothing is kept, so its strike lands nowhere
local function refuseLaunch(character)
	Core.CountShot("rej_launch")
	broadcast("CrossSlashCancel", { Character = character })
end

local function launchCrossSlash(player, character, humanoid, root, c, launch)
	local S = T.CrossSlash
	local now = os.clock()
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	-- the hold as this side measured it, press to launch. The client charges on the key's own time, which ends before its
	-- launch, so a real claim is inside this; the two messages' jitter is allowed for (0.1 s and a ping)
	local held = now - c.At
	local dist = launch.Dist
	if type(dist) ~= "number" or dist ~= dist or dist < S.MinDistance - 0.01 or dist > S.MaxDistance + 0.01
		or dist > chargedDistance(held + 0.1 + ping) + 0.01 then
		refuseLaunch(character)
		return
	end
	local dir = launch.Dir
	if not Core.ValidVector(dir) or math.abs(dir.Magnitude - 1) > 0.01 then
		refuseLaunch(character)
		return
	end
	dir = dir.Unit
	-- where it started: the client's claim, if the server's copy of the body could have been there
	local start = launch.Start
	local speed = Core.TrailSpeed(root, humanoid.WalkSpeed)
	if not Core.ValidVector(start) or (start - root.Position).Magnitude > 6 + speed * (0.35 + Core.Lag(ping)) then
		start = root.Position
	end
	local frame = ZephyrFX.CrossSlashFrame(Vector3.zero, dir)
	slashes[player] = {
		At = now, Epoch = Core.Epoch(player), Start = start, Dir = dir, Right = frame.RightVector, Up = frame.UpVector,
		Dist = dist, Glide = dist / (S.DashDistance / S.DashTime), Character = character, Hit = {}, Struck = false,
	}
	broadcast("CrossSlashDash", {
		Character = character, Start = start, Dir = dir, Dist = dist, Hold = held,
		T0 = workspace:GetServerTimeNow(),
	})
end

local function castCrossSlashDash(player, character, humanoid, root, payload)
	if payload.Phase == "Start" then
		charges[player] = { At = os.clock(), Epoch = Core.Epoch(player), Character = character }
		if cannotDash(character) then
			endCharge(player, "Refused")
			return
		end
		broadcast("CrossSlashCharge", { Character = character, T0 = workspace:GetServerTimeNow() })
	elseif payload.Phase == "Release" then
		local c = charges[player]
		charges[player] = nil
		if not c or c.Reason == "Refused" then return end              -- nothing was drawn
		local launch = type(payload.Client) == "table" and payload.Client or nil
		if c.Reason or not launch or launch.Cancel or c.Character ~= character or c.Epoch ~= Core.Epoch(player)
			or cannotDash(character) then
			broadcast("CrossSlashCancel", { Character = character })
			return
		end
		launchCrossSlash(player, character, humanoid, root, c, launch)
	end
end

-- Whether a claimed point is inside what the slash covered, and where to check the line of sight from. The X's hits
-- (passed false): its reach ahead of the strike, from the strike. The glide's (passed true): the corridor it swept from
-- the start to where the strike says it got to (no further than the dash's distance), as wide and tall as the X, from
-- the nearest point of the dash line. Both are measured in the dash's own frame (ZephyrFX.CrossSlashFrame): along Dir,
-- across Right (level), and along Up. `along` is the strike's progress along the dash line.
local function slashReach(slash, origin, along, position, passed)
	local S = T.CrossSlash
	if not passed then
		local r = position - origin
		local ahead = r:Dot(slash.Dir)
		if ahead < -1.5 or ahead > S.Reach + 1.5 or math.abs(r:Dot(slash.Right)) > S.HalfWidth + 1.5
			or math.abs(r:Dot(slash.Up)) > S.HalfHeight + 2.5 then
			return false
		end
		return true, origin
	end
	local swept = math.clamp(along, 0, slash.Dist)
	local rs = position - slash.Start
	local at = rs:Dot(slash.Dir)
	if at < -1.5 or at > swept + 1.5 or math.abs(rs:Dot(slash.Right)) > S.HalfWidth + 1.5
		or math.abs(rs:Dot(slash.Up)) > S.HalfHeight + 2.5 then
		return false
	end
	return true, slash.Start + slash.Dir * math.clamp(at, 0, swept)
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "CrossSlashStrike" or type(a) ~= "table" then return end
	local S = T.CrossSlash
	local slash = slashes[player]
	if not slash or slash.Struck then
		Core.CountShot("rej_noshot")
		return
	end
	slash.Struck = true                                  -- one strike per cast
	if Core.Epoch(player) ~= slash.Epoch or player:GetAttribute("Zone") == "Hub"
		or not holds(player, "Primary", "CrossSlashDash") then
		Core.CountShot("rej_noshot")
		return
	end
	-- (2026-10-19, audit P1-13) CanAct, not AliveCharacter: no strike while interrupted (Undertow, Aftershock), burrowed
	-- or cast-locked by a round reset
	local character, humanoid, root = Core.CanAct(player)
	if not character or character ~= slash.Character then return end
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	-- on time: the Trigger after the launch was heard, give or take a round trip. The Trigger sits as far past the end of
	-- the glide as it always has, and the glide lasts as long as its distance takes at the glide's pace
	local scale = VFXLibrary.ShotTimeScale()
	local since = os.clock() - slash.At
	local due = slash.Glide + (S.Trigger - S.ChargeTime - S.DashTime) / scale
	if since < due - 0.3 or since > due + 0.6 + 2 * ping then
		Core.CountShot(since < due and "rej_early" or "rej_late")
		return
	end
	-- where the strike came from: along the dash line, no further than the dash went, and near the server's body
	local origin = a.Origin
	if not Core.ValidVector(origin) then
		Core.CountShot("rej_origin")
		return
	end
	local rel = origin - slash.Start
	local along = rel:Dot(slash.Dir)
	local off = rel - slash.Dir * along
	local speed = Core.TrailSpeed(root, S.DashDistance / S.DashTime)
	if along < -3 or along > slash.Dist + 4 or math.abs(off:Dot(slash.Right)) > 4 or math.abs(off:Dot(slash.Up)) > 8
		or (origin - root.Position).Magnitude > 6 + speed * (0.35 + Core.Lag(ping)) then
		Core.CountShot("rej_origin")
		return
	end
	-- (2026-10-19, audit GC-02) a glide through a Bulwark Wall strikes nothing: the wall stops the dash (DashMotor), so a
	-- strike from its far side is a client that went through it, and every body it claims there is behind cover
	if Core.WallBetween(slash.Start, origin) then
		Core.CountShot("rej_wall")
		return
	end
	-- a character the glide passed is only reported now, at the Trigger: it is checked against where the server had it
	-- at any time since the launch was heard (plus the round trip and the interpolation). The X's keep the usual second
	local window = since + 2 * ping + 0.3
	local function claim(h, passed)
		local part, position = type(h) == "table" and h.Part, type(h) == "table" and h.Position
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
			or not Core.ValidVector(position) then
			Core.CountShot("rej_badpart")
			return
		end
		local inside, from = slashReach(slash, origin, along, position, passed)
		if not inside then
			Core.CountShot("rej_offline")
			return
		end
		local reason, model, victim = Core.CheckTarget(part, position, character, passed and window or nil)
		if reason then
			Core.CountShot(reason)
			return
		end
		if not victim or slash.Hit[model] or Core.IsFriendly(player, model) then
			Core.CountShot("rej_repeat")
			return
		end
		local toward = position - from
		if Core.Blocked({ Origin = from, Dir = toward.Magnitude > 1e-3 and toward.Unit or slash.Dir, Character = character },
			toward.Magnitude, model) then
			Core.CountShot("rej_blocked")
			return
		end
		slash.Hit[model] = true
		Core.CountShot("hit")
		Core.DealDamage(player, victim, S.Damage, { From = origin })
	end
	-- the glide's list and the X's list are capped apart (MaxPath, MaxTargets), as the client fills them
	local passedList = type(a.Passed) == "table" and a.Passed or {}
	for i = 1, math.min(#passedList, S.MaxPath) do
		claim(passedList[i], true)
	end
	local hits = type(a.Hits) == "table" and a.Hits or {}
	for i = 1, math.min(#hits, S.MaxTargets) do
		claim(hits[i], false)
	end
end)

----------------------------------------------------------------------------------------------------
-- DEFENSE / MOBILITY: retired 2026-10-06 (the v6 import)
----------------------------------------------------------------------------------------------------
-- Deflect Gust (the parry: castDeflectGust -> CombatCore.TryParry) and Gust Jump (the held jump, its second jump and its
-- float: castGustJump, GustJumpAgain, GustJumpHover and their backstop) were here. Gust Pad and Skyrider replace them, in
-- ZephyrGustPadServer and ZephyrSkyriderServer. CombatCore's parry hooks (OnParry / TryParry) stay: they are generic.

-- the backstop: a Cross-Slash charge held past MaxHold (the client launches by itself at MaxHold; this allows its launch
-- a round trip and a half-second more) or under a root or a freeze is ended there
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, c in pairs(charges) do
		if player.Character ~= c.Character or not (c.Character and c.Character.Parent) then
			charges[player] = nil                        -- died or respawned: that body's hold went with it
		elseif not c.Ended then
			local ping = 0
			pcall(function() ping = player:GetNetworkPing() end)
			if cannotDash(c.Character) then
				endCharge(player, "Stopped")
			elseif now - c.At > T.CrossSlash.MaxHold + 0.5 + 2 * ping then
				endCharge(player, "Timeout")
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- ULTIMATE: CYCLONE
----------------------------------------------------------------------------------------------------
-- (2026-09-17) The press arrives already paid for: SpellshotService took the Ultimate's charge before it fired PerformCast
-- (a dev's free Ultimate is not spent). It carries the ground spot under the caster's crosshair (Center), which is checked
-- the way the Ring of Fire's is -- in reach of the body, and grounded here, straight down through characters. A spot that
-- fails is refused: nothing happens, and the charge is given back. Then:
--   FORMING   FormTime at the spot, which the caster's crosshair still moves (CycloneSteer, below: a few a second, in
--             reach, grounded, and no faster than SteerSpeed); the caster walks at FormMoveShare of the walk (SpeedCapUlt).
--   ACTIVE    ActiveTime where it formed. Every PullInterval, each living character in its cylinder (Radius round the
--             axis, from Below under the spot to Height over it; HoldSlack more for someone already caught) that the caster
--             may hurt (Core.IsFriendly: teammates, and anyone Config.MayHurt refuses, are left alone) is caught and pulled:
--             a player's own client moves its body (it owns it), told so by CyclonePull every PullSend, sent to that player
--             alone; an unanchored dummy the server owns is moved here, with the same rule (ZephyrFX.CyclonePullVelocity);
--             an anchored dummy is not moved. Every TickInterval each caught character takes Damage and the AIRBORNE tag.
--             Anyone who leaves the cylinder, dies or turns friendly is let go (CycloneRelease).
--   END       the time runs out, or its caster dies: everyone is let go and it unwinds (the look only). Leaving the arena,
--             a round reset (CombatCore.ClearPlayer), leaving the game or a new cast end it at once. Nothing is left behind.
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local addUltCharge = spellFolder:WaitForChild("AddUltCharge")

local cyclones = {}        -- [player] = { Character, Humanoid, Center, Phase, Cap, FormEnd, ActiveEnd, Epoch, Tokens, At,
                           --   SteerAt, NextPull, NextTick, Caught = {[model] = { Humanoid, Root, Player, Since, SentAt,
                           --   Seed, Mover, Attachment }} }
local cycloneSeed = Random.new()

--- The ground under `point`, found straight down THROUGH characters (the Ring of Fire's rule): a spot on an enemy is the
--- floor round their feet. nil over a drop.
local function groundUnder(point, character)
	local list = { character }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit.Position end
		list[#list + 1] = model
	end
	return nil
end

-- the client pulls its spot in to Range from where it stands; the slack is the server's copy of the body trailing it
local function cycloneInReach(root, point)
	local flatAway = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	return flatAway.Magnitude <= ABILITY.Cyclone.Range + T.Cyclone.RangeSlack
end

--- (2026-10-19, audit P1-09) LINE OF SIGHT for the aimed spot (PyroHandler's inSight, for the Ring of Fire). The honest
--- client can only pick a spot its camera sees, so the server asks the same of its own copy of the world: from the
--- caster's eye to the spot -- or to a point a few studs over it, so low cover in front of the spot does not hide it --
--- nothing solid may stand in between. Bodies never count; a Bulwark Wall does (Core.Blocked's rule). A spot out of sight
--- is grounded again from just short of the first thing in the way, so a spot through a wall, or on the storey above or
--- below, comes back to this side of it. nil when there is no floor there either.
local SIGHT_RISES = { 0.5, 3, 5 }
local function inSight(character, root, spot)
	local head = character:FindFirstChild("Head")
	local eye = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local list = { character }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local stop
	for _, rise in ipairs(SIGHT_RISES) do
		local d = spot + Vector3.new(0, rise, 0) - eye
		local len = d.Magnitude
		if len < 0.5 then return spot end
		local dir = d / len
		stop = nil
		for _ = 1, 8 do
			params.FilterDescendantsInstances = list
			local hit = workspace:Raycast(eye, d, params)
			if not hit then break end
			local depth = (hit.Position - eye):Dot(dir)
			if depth >= len - Core.SameSurface then break end
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) or model:GetAttribute("WallOwner") then
				stop = eye + dir * math.max(0, depth - 1)
				break
			end
			list[#list + 1] = model
		end
		if not stop then return spot end
	end
	return groundUnder(stop - Vector3.new(0, 2, 0), character)     -- groundUnder casts from 2 over the point it is given
end

-- THE TRAINING DUMMIES (2026-10-09): the range's dummies stand anchored (only the strafer walks), and an anchored body is
-- not moved -- so one Cyclone lifted only the strafer, never the crowd round it. A caught anchored dummy is now unanchored
-- for the ride (the server owns it, so it is moved here like any dummy), and DummyReturn seconds after the last Cyclone
-- lets it go it is put back where it stood and anchored again. A dummy caught again before then keeps its first spot.
local lifted = {}          -- [model] = { Pivot, Parts, Token }

local function heldByAnyCyclone(model)
	for _, cy in pairs(cyclones) do
		if cy.Caught[model] then return true end
	end
	return false
end

local function liftDummy(model, root)
	if not (root.Anchored and model:GetAttribute("TrainingDummy") ~= nil) then return end
	local entry = lifted[model]
	if not entry then
		local parts = {}
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p.Anchored then parts[#parts + 1] = p end
		end
		entry = { Pivot = model:GetPivot(), Parts = parts, Token = 0 }
		lifted[model] = entry
	end
	entry.Token += 1
	for _, p in ipairs(entry.Parts) do
		if p.Parent then p.Anchored = false end
	end
	pcall(function() root:SetNetworkOwner(nil) end)
end

local function returnDummy(model)
	local entry = lifted[model]
	if not entry then return end
	local token = entry.Token
	task.delay(T.Cyclone.DummyReturn or 2, function()
		if lifted[model] ~= entry or entry.Token ~= token or heldByAnyCyclone(model) then return end
		lifted[model] = nil
		if not model.Parent then return end
		for _, p in ipairs(entry.Parts) do
			if p.Parent then
				p.AssemblyLinearVelocity, p.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			end
		end
		pcall(function() model:PivotTo(entry.Pivot) end)
		for _, p in ipairs(entry.Parts) do
			if p.Parent then p.Anchored = true end
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
	end)
end

--- Lets one caught character go: its client stops pulling, or the server's mover comes off the dummy.
local function letGo(cy, model)
	local held = cy.Caught[model]
	if not held then return end
	cy.Caught[model] = nil
	if held.Player then
		pcall(function()
			remote:FireClient(held.Player, "VFX", "CycloneRelease", { Caster = cy.Character })
		end)
	end
	if held.Mover then held.Mover:Destroy() end
	if held.Attachment then held.Attachment:Destroy() end
	if lifted[model] then returnDummy(model) end
end

--- Ends `player`'s Cyclone. how: "Unwind" (its time ran out, or its caster died), "Instant" (a new cast, leaving the
--- arena, a round reset, leaving the game).
local function endCyclone(player, how)
	local cy = cyclones[player]
	if not cy then return end
	cyclones[player] = nil
	for model in pairs(cy.Caught) do
		letGo(cy, model)
	end
	local character = cy.Character
	if character.Parent and character:GetAttribute("SpeedCapUlt") == cy.Cap then
		character:SetAttribute("SpeedCapUlt", nil)     -- SpellshotService puts the stance's speed back
	end
	broadcast("CycloneEnd", { Character = character, Instant = how ~= "Unwind", Formed = cy.Phase == "Active" })
end

local function castCyclone(player, character, humanoid, root, payload)
	endCyclone(player, "Instant")
	local C = T.Cyclone
	local center = payload.Center
	local ground = Core.ValidVector(center) and cycloneInReach(root, center) and groundUnder(center, character)
	if ground then ground = inSight(character, root, ground) end     -- (2026-10-19, audit P1-09)
	if not ground then
		-- a spot that could not have been aimed at from here: nothing happens, and the Ultimate is given back
		addUltCharge:Fire(player, 1)
		broadcast("CycloneEnd", { Character = character, Instant = true, Refused = true })
		return
	end
	local now = os.clock()
	local cap = Config.Movement.BaseWalkSpeed * C.FormMoveShare
	character:SetAttribute("SpeedCapUlt", cap)
	cyclones[player] = {
		Character = character, Humanoid = humanoid, Center = ground, Phase = "Forming", Cap = cap,
		FormEnd = now + C.FormTime, ActiveEnd = now + C.FormTime + C.ActiveTime, Epoch = Core.Epoch(player),
		Tokens = 3, At = now, SteerAt = now, NextPull = 0, NextTick = 0, Caught = {},
	}
	broadcast("Cyclone", { Character = character, Center = ground, T0 = workspace:GetServerTimeNow() })
end

-- While it forms, its caster's crosshair moves it: the client sends the ground spot under its aim a few times a second,
-- pulled in to Range. Each is checked as the cast's spot is, and then held to SteerSpeed from the last spot taken (a
-- spot further than that is taken only that far, grounded again there), and passed on to everyone else.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "CycloneSteer" then return end
	local cy = cyclones[player]
	if not cy or cy.Phase ~= "Forming" or not Core.ValidVector(a) then return end
	local C = T.Cyclone
	local now = os.clock()
	if now >= cy.FormEnd then return end
	cy.Tokens = math.min(3, cy.Tokens + (now - cy.At) * C.SteerRate)
	cy.At = now
	if cy.Tokens < 1 then return end
	cy.Tokens -= 1
	local character, _, root = Core.AliveCharacter(player)
	if not character or character ~= cy.Character or not cycloneInReach(root, a) then return end
	local ground = groundUnder(a, character)
	if not ground then return end
	local step = Vector3.new(ground.X - cy.Center.X, 0, ground.Z - cy.Center.Z)
	local most = C.SteerSpeed * math.min(now - cy.SteerAt, C.SteerWindow) + C.SteerSlack
	if step.Magnitude > most then
		local p = cy.Center + step.Unit * most
		ground = groundUnder(Vector3.new(p.X, math.max(ground.Y, cy.Center.Y) + 4, p.Z), character)
		if not ground then return end
	end
	ground = inSight(character, root, ground)        -- (2026-10-19, audit P1-09) as the cast's own spot
	if not ground then return end
	cy.Center, cy.SteerAt = ground, now
	broadcast("CycloneSteer", { Character = character, Center = ground })
end)

-- one catch check: who is in the cylinder now, caught or let go
local function pullCyclone(player, cy, now)
	local C = T.Cyclone
	local mid = cy.Center + Vector3.new(0, (C.Height - C.Below) / 2, 0)
	local half = (C.Height + C.Below) / 2
	local reach = math.sqrt((C.Radius + C.HoldSlack) ^ 2 + half * half)
	local seen = {}
	for victim, model in pairs(Core.HumanoidsNear(mid, reach, cy.Character)) do
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if root and not Core.IsFriendly(player, model) then
			local held = cy.Caught[model]
			local d = root.Position - cy.Center
			local radius = C.Radius + (held and C.HoldSlack or 0)
			if Vector3.new(d.X, 0, d.Z).Magnitude <= radius and d.Y >= -C.Below and d.Y <= C.Height then
				seen[model] = true
				if not held then
					held = {
						Humanoid = victim, Root = root, Player = Players:GetPlayerFromCharacter(model), Since = now,
						SentAt = -math.huge, Seed = cycloneSeed:NextNumber(0, C.JugglePeriod),
					}
					cy.Caught[model] = held
					if not held.Player then liftDummy(model, root) end
					if not held.Player and not root.Anchored then
						-- a dummy the server simulates is moved here; one a player's client simulates is left alone
						local ok, owner = pcall(function() return root:GetNetworkOwner() end)
						if ok and owner == nil then
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
							mover.VectorVelocity = Vector3.zero
							mover.Parent = attachment
							attachment.Parent = root
							held.Mover, held.Attachment = mover, attachment
						end
					end
				end
				if held.Player and now - held.SentAt >= C.PullSend then
					held.SentAt = now
					local serverNow = workspace:GetServerTimeNow()
					-- (2026-10-19, audit P4-04) juggled by an enemy is not Updraft's air: KnockedUntil runs past the pull's
					-- hold by the fall from the juggle height (~0.6 s at this place's gravity), so the drop does not count
					model:SetAttribute("KnockedUntil",
						math.max(serverNow + C.PullHold + 0.8, model:GetAttribute("KnockedUntil") or 0))
					pcall(function()
						remote:FireClient(held.Player, "VFX", "CyclonePull", {
							Caster = cy.Character, Center = cy.Center, Until = serverNow + C.PullHold,
							Held = now - held.Since, Seed = held.Seed,
						})
					end)
				end
			end
		end
	end
	for model in pairs(cy.Caught) do
		if not seen[model] then letGo(cy, model) end
	end
end

local function stepCyclone(player, cy, now)
	local C = T.Cyclone
	local character = cy.Character
	if player.Character ~= character or not character.Parent or cy.Humanoid.Health <= 0 then
		endCyclone(player, "Unwind")                     -- its caster died or respawned
		return
	end
	if Core.Epoch(player) ~= cy.Epoch or player:GetAttribute("Zone") == "Hub" then
		endCyclone(player, "Instant")                    -- the backstop to OnClear
		return
	end
	if cy.Phase == "Forming" then
		if now < cy.FormEnd then return end
		cy.Phase = "Active"
		cy.NextTick = now + C.FirstTick
		if character:GetAttribute("SpeedCapUlt") == cy.Cap then character:SetAttribute("SpeedCapUlt", nil) end
		broadcast("CycloneActive", { Character = character, Center = cy.Center, T0 = workspace:GetServerTimeNow() })
	end
	if now >= cy.ActiveEnd then
		endCyclone(player, "Unwind")
		return
	end
	if now >= cy.NextPull then
		cy.NextPull = now + C.PullInterval
		pullCyclone(player, cy, now)
	end
	for _, held in pairs(cy.Caught) do
		if held.Mover then
			if held.Root.Parent and not held.Root.Anchored then
				held.Mover.VectorVelocity = ZephyrFX.CyclonePullVelocity(held.Root.Position, cy.Center, now - held.Since,
					held.Seed)
			else
				held.Mover.VectorVelocity = Vector3.zero
			end
		end
	end
	if now >= cy.NextTick then
		cy.NextTick = now + C.TickInterval
		for _, held in pairs(cy.Caught) do
			-- (2026-10-19, audit P4-13) a Bulwark Wall caught in it takes the damage and nothing else: no AIRBORNE tag
			if held.Humanoid.Health > 0 and Core.DealDamage(player, held.Humanoid, C.Damage, { From = cy.Center })
				and not Core.IsWall(held.Humanoid.Parent) then
				Core.ApplyStatusTag(held.Humanoid, "Airborne", C.StatusTime)
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	if next(cyclones) == nil then return end
	local now = os.clock()
	for player, cy in pairs(cyclones) do
		stepCyclone(player, cy, now)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	endCyclone(player, "Instant")
end)

-- Leaving the arena, or a duel round being reset: the player's own Cyclone ends at once, and any Cyclone holding them lets
-- them go.
Core.OnClear(function(player)
	endCyclone(player, "Instant")
	local character = player.Character
	if not character then return end
	for _, cy in pairs(cyclones) do
		if cy.Caught[character] then letGo(cy, character) end
	end
end)

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
local casts = {
	WindBlade = castWindBlade,
	CrossSlashDash = castCrossSlashDash,
	Cyclone = castCyclone,
	-- Skyrider, GustPad (and the Passive, Updraft) are not here: each has its own Script (see the header)
}

performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return end
	fn(player, character, humanoid, root, type(payload) == "table" and payload or {})
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	shots[player] = nil
	buckets[player] = nil
	charges[player] = nil
	slashes[player] = nil
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): blades in flight land nowhere, a slash under
-- way strikes nothing, and a Cross-Slash still charging ends there (its cooldown starts, as a release would start it;
-- the charge launches nothing).
Core.OnClear(function(player)
	shots[player] = nil
	endCharge(player, "Clear")
	slashes[player] = nil
end)
