--[[
	PyroHandler  (Script)  ->  ServerScriptService/PyroHandler

	The gameplay side of the Pyro kit (design manual Section 2; wired 2026-09-14 after Build Prompt #21).
	PyroFX draws all of it and this decides what it does. Every number is PyroFX.Tuning, shared with the
	client, and every one of them is a stand-in: the manual sets the behaviour, not the figures.

	  M1        Fireball        a straight shot with a splash. The shooter's client reports what its own
	                            fireball hit; this checks the claim against the LINE (FireballRelease /
	                            FireballHit) -- the same arrangement Icicle Shard has with AbilityHandler
	  Primary   Immolate        the next Stacks M1 throws that land burn everyone they hurt (RX_Burning);
	                            Stacks_Primary / StacksMax_Primary count them for the HUD's flames
	  Passive   Ember Refund    a hit taking an enemy under 30% health takes Share of Immolate's cooldown off whatever is
	                            left of it (T.EmberRefund.Trigger; until 2026-10-17 a kill did)
	  Ultimate  Ring of Fire    POINTED: the client sends the ground spot under its crosshair, and the hand
	                            draws a circle round it by itself; a settle, the snap-and-point, and fire
	                            erupts inside it. Until the snap the
	                            circle follows the caster's crosshair (RingOfFireSteer), and burns where it
	                            was when the snap came (RingOfFireLock)

	PYRO'S OWN SLOTS (2026-09-23, Config.ElementSlots): a Pyro's Q and E are no longer the Techniques above but
	these two. (2026-10-27, the owner) Heat Rush and Cinder Shield, Pyro's other two, are gone from the game.
	  Mobility  Detonate        marks whoever you last hit with Fireball or Immolate; after a Fuse the mark
	                            explodes, harder the lower their health (RX_Primed). A press with no target is
	                            refused before it costs anything (Precheck_Detonate, asked by SpellshotService)
	  Defense   Scorching Lash  HELD (round 2, 2026-09-24): the burning whip trails behind you while the key is
	                            down; letting go SWEEPS it (round 3): round your right side and across the front,
	                            35 studs. The caster's client reports what the sweep caught (ScorchingLashStrike),
	                            checked here against that sector round your aim, and every body struck gains a
	                            stacking burn (RX_Burning_Stacks).
	                            A Pyro may equip it in either Technique slot (Mobility or Defense role); other
	                            Elements only with TechniquesOwnElementOnly off (2026-10-19, audit P4-14)

	WHERE CASTS COME FROM: SpellshotService checks and pays for the cast, then fires PerformCast; both this
	and AbilityHandler hear it and each acts only on its own kit's ability Ids. Damage goes through
	CombatCore, so a Cryo kill still refunds a Pyro's Immolate.

	Server -> client (AbilityFX): ("VFX", kind, data) on IceAbilityRemote.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local PyroFX = require(iceFolder:WaitForChild("PyroFX"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))   -- the Lash's trail cap reads Movement (2026-10-08)
local performCast = spellFolder:WaitForChild("PerformCast")
local releaseHold = spellFolder:WaitForChild("ReleaseHold")
local addUltCharge = spellFolder:WaitForChild("AddUltCharge")
local giveBack = spellFolder:WaitForChild("GiveBack")          -- (player, role, true): the cast and its Ultimate charge back
local Core = require(script.Parent:WaitForChild("CombatCore"))
-- ELEMENTAL APPLICATION (2026-09-24): the burn numbers come from the live status preset, and every burn publishes its clock
local Status = require(script.Parent:WaitForChild("StatusEffects"))

local T = PyroFX.Tuning
local remote = Core.Remote
local broadcast = Core.Broadcast
local ABILITY = VFXLibrary.AbilityById

--- Whether the ability `player` holds in `role` is the one named.
local function holds(player, role, id)
	local a = VFXLibrary.AbilityFor(player, role)
	return a ~= nil and a.Id == id
end

--- True if something solid -- not a character -- stands between two points on the server's copy of the world.
local function lineBlocked(from, to, exclude)
	local list = {}
	for _, inst in pairs(exclude) do list[#list + 1] = inst end
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then return false end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return true end
		-- a Bulwark Wall carries a Humanoid so that every kit's hits can damage it, but it is COVER: Core.Blocked
		-- says so (CombatCore, 2026-09-19) and this private copy of the walk never did, so the splash and the haze
		-- -- both decided by the server alone, with no client claim involved -- reached straight through a wall
		-- (2026-09-21)
		if model:GetAttribute("WallOwner") then return true end
		list[#list + 1] = model
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- DETONATE'S TARGET: whom each Pyro last hit with Fireball or Immolate
----------------------------------------------------------------------------------------------------
-- 2026-09-23. Detonate marks whoever its caster LAST hit with a Fireball or with Immolate, so every such hit is noted
-- here, per caster: a Fireball's direct victim (which outranks the splash of the same throw), else the splash victim
-- nearest the impact, and every tick of an Immolate burn (Ring of Fire's burns run through the same burn() and are told
-- apart by their source). Never a Bulwark Wall (cover, not a body), never anyone the caster may not hurt, never the
-- dead. A Scorching Lash hit is not one of these. DetonateUntil on the CASTER's character is when the note stops
-- counting (server time; nil = no target): their client refuses a press with nothing to mark before it costs anything,
-- and the HUD dims the slot. The server's own answer is detonateTarget, which the cast and SpellshotService's
-- Precheck_Detonate both ask -- and DetonateUntil now says exactly what it says (publishTarget, below).
-- Weak-keyed (review r1, 2026-09-24), as burns and lashBurns are: a note written for a player who has since left must
-- not hold their Player, or the victim's Humanoid, for the life of the server.
local lastHit = setmetatable({}, { __mode = "k" })   -- [player] = { Humanoid, Model, At (server time), Epoch, VictimEpoch }
-- Players who have LEFT (PlayerRemoving, below). Leaving is not a clear -- their epoch never moves -- so without this an
-- Immolate burn still ticking in their name wrote their note again after PlayerRemoving had dropped it, and a Detonate
-- pressed in the Trigger before they left still marked, and blew up, in the name of someone no longer in the game.
local gone = setmetatable({}, { __mode = "k" })      -- [player] = true
local watchVictim          -- (below, with Detonate and the Lash) what a victim's death takes off them

--- Whether `humanoid` is a body `caster` may mark: alive, in the world, not a wall, and someone they may hurt.
local function eligible(caster, humanoid)
	local model = humanoid and humanoid.Parent
	return model ~= nil and model.Parent ~= nil and humanoid.Health > 0 and not Core.IsWall(model)
		and not Core.IsFriendly(caster, model)
end

--- The caster's Detonate target right now, or nil: a note taken since their last clear, inside its Window, on a body
--- still alive and in the world, not cleared since either (a player victim's epoch), still one they may hurt, and within
--- Range of the caster's root. No line of sight is asked: the mark does not travel.
local function detonateTarget(player, root)
	local rec = lastHit[player]
	if not (rec and root) or rec.Epoch ~= Core.Epoch(player) then return nil end
	if workspace:GetServerTimeNow() - rec.At > T.Detonate.Window / VFXLibrary.ShotTimeScale() then return nil end
	if rec.Humanoid.Parent ~= rec.Model or not eligible(player, rec.Humanoid) then return nil end
	if rec.VictimEpoch ~= nil then
		local victimPlayer = Players:GetPlayerFromCharacter(rec.Model)
		if not victimPlayer or Core.Epoch(victimPlayer) ~= rec.VictimEpoch then return nil end
	end
	local vroot = rec.Model:FindFirstChild("HumanoidRootPart") or rec.Model.PrimaryPart
	if not vroot or (vroot.Position - root.Position).Magnitude > T.Detonate.Range then return nil end
	return rec
end

--- DetonateUntil on the caster's current body: the end of their note's Window WHILE the precheck would take it, else
--- nil. It used to be the Window's end whatever else was true, so a note taken at 140 studs (a Fireball flies 162), or on
--- someone who then backed off past Range, lit the slot and played a flick that Precheck_Detonate then turned away in
--- silence, the M1 locked for nothing (review r1, 2026-09-24). So it is worked out from detonateTarget itself -- the
--- very answer the precheck gives -- on every note and every frame (the Heartbeat with Detonate, below), and written
--- only when it changes. The note is kept while it is out of Range: back inside the Window and the Range, it lights up
--- again.
local function publishTarget(player)
	local character = player.Character
	if not (character and character.Parent) then return end
	local rec = lastHit[player]
	local _, _, root = Core.AliveCharacter(player)
	local value = (rec and detonateTarget(player, root)) and (rec.At + T.Detonate.Window / VFXLibrary.ShotTimeScale()) or nil
	if character:GetAttribute("DetonateUntil") ~= value then
		character:SetAttribute("DetonateUntil", value)
	end
end

local function noteHit(caster, humanoid)
	if not (typeof(caster) == "Instance" and caster:IsA("Player")) or gone[caster] or not eligible(caster, humanoid) then
		return
	end
	local model = humanoid.Parent
	local victimPlayer = Players:GetPlayerFromCharacter(model)
	lastHit[caster] = {
		Humanoid = humanoid, Model = model, At = workspace:GetServerTimeNow(), Epoch = Core.Epoch(caster),
		VictimEpoch = victimPlayer and Core.Epoch(victimPlayer) or nil,
	}
	publishTarget(caster)
	watchVictim(humanoid)
end

local function dropTarget(player)
	if lastHit[player] == nil then return end
	lastHit[player] = nil
	publishTarget(player)
end

----------------------------------------------------------------------------------------------------
-- BURNING
----------------------------------------------------------------------------------------------------
-- A burn is a few ticks of damage over a second or two, published as RX_Burning (the victim's flame crest
-- and embers on their health bar) and the Burning tag. A newer burn replaces the one running, rather than
-- stacking, so a quick string of buffed throws is not a death sentence.
local burns = setmetatable({}, { __mode = "k" })     -- [humanoid] = token (a table of its own) of the burn running
-- SCORCHING LASH's burn (2026-09-23) is a second channel beside that one, and it STACKS: per victim, all casters
-- together, one tick clock started by the first stack. It lives in its own table so that neither channel ever cancels
-- the other -- a lash would otherwise replace an Immolate burn, and the other way round. Its ticks are below, with
-- the Lash.
local lashBurns = setmetatable({}, { __mode = "k" }) -- [humanoid] = { Stacks, TicksLeft, Caster, Epoch, Token, Model, VictimEpoch }

--- RX_Burning is ONE flag with two writers now, so nobody sets or clears it directly: it is recounted from both
--- channels. The first burn to end used to switch the flag off under the other one still running -- the two-writer bug
--- TerraHandler found with RX_Shielded (2026-09-21).
local function refreshBurning(model)
	if not (model and model.Parent) then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local lash = humanoid and lashBurns[humanoid]
	local on = humanoid ~= nil and (burns[humanoid] ~= nil or (lash ~= nil and lash.Stacks > 0))
	model:SetAttribute("RX_Burning", on)
	if not on then Status.Stamp(model, "Burning", 0) end
end

--- `source` names what lit it: "Immolate" (each of whose ticks is a hit Detonate can mark) or nil (Ring of Fire).
local function burn(caster, humanoid, ticks, damage, interval, source)
	local model = humanoid.Parent
	if not model then return end
	-- the live status preset's numbers (StatusEffects, 2026-09-24) stand in for the caller's: Immolate's burn or Ring of Fire's
	local BT = Status.Tune("Burning")
	local row = (source == "Immolate") and BT.Immolate or BT.Ring
	ticks, damage, interval = row.Ticks, row.TickDamage, BT.Interval
	-- a fresh table, not a count: a clear empties the entry, and a count starting again from 1 could match an old burn
	local token = {}
	burns[humanoid] = token
	local epoch = Core.Epoch(caster)
	model:SetAttribute("RX_Burning_Element", "Pyro")
	-- (2026-10-25) who lit it and with what, for the client's burn flames (PyroFX: they wear that caster's wrap)
	model:SetAttribute("RX_Burning_By", (typeof(caster) == "Instance" and caster:IsA("Player")) and caster.UserId or nil)
	model:SetAttribute("RX_Burning_Src", source or "RingofFire")
	refreshBurning(model)
	Status.Stamp(model, "Burning", ticks * interval)
	Core.ApplyStatusTag(humanoid, "Burning", ticks * interval)
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(interval)
			-- stops if the caster has been cleared since (left the arena, or a duel round was reset)
			if burns[humanoid] ~= token or humanoid.Health <= 0 or not model.Parent or Core.Epoch(caster) ~= epoch then break end
			if Core.DealDamage(caster, humanoid, damage, { DoT = true }) and source == "Immolate" then
				noteHit(caster, humanoid)
			end
		end
		if burns[humanoid] == token then
			burns[humanoid] = nil
			refreshBurning(model)                  -- down only if no lash burn is still holding it up
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- M1: FIREBALL
----------------------------------------------------------------------------------------------------
-- The click relays the punch so every client can play it and fly its own fireball from that hand. The HIT
-- is decided separately, from the release and the shooter's report (below).
local function castFireball(player, character, humanoid, root, payload)
	local dir = payload.Dir
	if Core.ValidVector(dir) and dir.Magnitude > 0.1 then
		dir = dir.Unit
	else
		dir = root.CFrame.LookVector
	end
	broadcast("Fireball", {
		Character = character, Side = (payload.Side == "L") and "L" or "R", Dir = dir,
		Hot = (character:GetAttribute("Stacks_Primary") or 0) > 0,
	})
end

local shots = {}           -- [player] = { [id] = { Origin, Velocity, At, Life, Character } }, awaiting their hit
local buckets = {}         -- [player] = { Tokens, At }: the fire-rate check

-- The release: the shooter's eye and aim at the moment the fist reached full extension. The line is rebuilt
-- from those two here with the same numbers the client flies (PyroFX.FireballVelocity / FireballPoint).
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "FireballRelease" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "Fireball") then return end
	local character, humanoid, root = Core.CanAct(player)          -- CanAct, not AliveCharacter: not from underground (2026-09-21)
	if not character then return end
	local origin, dir, id = a.Origin, a.Dir, a.Id
	-- id ~= id refuses a NaN Id (2026-10-19, audit P1-11): the write below raised "table index is NaN" (TerraHandler's fix)
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or type(id) ~= "number" or id ~= id
		or dir.Magnitude < 0.1 then
		return
	end
	local now = os.clock()
	-- one throw per FireInterval on average, with a throw and a half of slack for jitter (as ShardRelease)
	local b = buckets[player]
	if not b then
		b = { Tokens = 1.5, At = now }
		buckets[player] = b
	end
	local interval = ABILITY.Fireball.FireInterval / VFXLibrary.ShotTimeScale()
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
	local mine = shots[player]
	if not mine then
		mine = {}
		shots[player] = mine
	end
	for oldId, shot in pairs(mine) do
		if now - shot.At > shot.Life then mine[oldId] = nil end
	end
	mine[id] = {
		Origin = origin, Velocity = PyroFX.FireballVelocity(dir.Unit), At = now, Character = character,
		Life = T.Fireball.Life / VFXLibrary.ShotTimeScale() + 1.5,
	}
	Core.CountShot("release")
end)

--- The time along the flight closest to `point` (a straight line, clamped to its Life), and how far off it the
--- point is.
local function nearestOnLine(shot, point)
	local v = shot.Velocity
	local t = math.clamp((point - shot.Origin):Dot(v) / v:Dot(v), 0, T.Fireball.Life)
	return t, (PyroFX.FireballPoint(shot.Origin, v, t) - point).Magnitude
end

--- True if something solid stands on the flight short of time `tHit`, checked as Core.Blocked checks a line --
--- characters never count, and the target's own surface is not cover.
local function flightBlocked(shot, tHit, skip)
	local list = { shot.Character, skip }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local claimed = PyroFX.FireballPoint(shot.Origin, shot.Velocity, tHit)
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(shot.Origin, claimed - shot.Origin, params)
		if not hit then return false end
		if (hit.Position - claimed).Magnitude <= Core.SameSurface + T.Fireball.Radius then return false end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return true end
		if model:GetAttribute("WallOwner") then return true end          -- cover, not a character (2026-09-21)
		list[#list + 1] = model
	end
	return false
end

--- A checked hit lands: the direct hit, the splash round it, and -- if Immolate is up and it hurt anyone --
--- one buffed hit spent and everyone it hurt set burning.
local function landFireball(player, shot, position, direct)
	local F = T.Fireball
	local hurt = {}
	if direct and Core.DealDamage(player, direct, F.Direct, { Ranged = true, From = shot.Origin }) then
		hurt[#hurt + 1] = direct
	end
	-- the splash: anyone else close to the impact with nothing solid between them and it (measured from just
	-- in front of the surface, back toward the thrower, so the wall it hit is not in the way of itself)
	local back = shot.Origin - position
	local from = position + (back.Magnitude > 0.1 and back.Unit * 0.6 or Vector3.zero)
	for victim, model in pairs(Core.HumanoidsNear(position, F.SplashRadius, shot.Character)) do
		if victim ~= direct then
			local vroot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			-- the direct target's own body is not cover for the splash round it -- but a Bulwark Wall the ball hit IS
			-- cover for everyone behind it, so it must not be excluded here or it is filtered out before lineBlocked
			-- can test it (2026-09-21)
			local directModel = direct and direct.Parent
			if directModel and directModel:GetAttribute("WallOwner") then directModel = nil end
			if vroot and not lineBlocked(from, vroot.Position, { shot.Character, model, directModel }) then
				if Core.DealDamage(player, victim, F.Splash, { Ranged = true, From = position }) then
					hurt[#hurt + 1] = victim
				end
			end
		end
	end
	-- DETONATE's target (2026-09-23): the direct victim, if the ball hurt one it may mark; otherwise -- nobody hit
	-- directly, or only a wall, or the direct hit killed -- the splash victim nearest the impact
	local pick
	if direct and hurt[1] == direct and eligible(player, direct) then
		pick = direct
	else
		local best = math.huge
		for _, victim in ipairs(hurt) do
			if victim ~= direct and eligible(player, victim) then
				local vroot = victim.Parent:FindFirstChild("HumanoidRootPart") or victim.Parent.PrimaryPart
				local d = vroot and (vroot.Position - position).Magnitude or math.huge
				if d < best then best, pick = d, victim end
			end
		end
	end
	if pick then noteHit(player, pick) end
	local character = shot.Character
	local stacks = character.Parent and (character:GetAttribute("Stacks_Primary") or 0) or 0
	if #hurt > 0 and stacks > 0 and holds(player, "Primary", "Immolate") then
		character:SetAttribute("Stacks_Primary", stacks - 1)
		local I = T.Immolate
		for _, victim in ipairs(hurt) do
			burn(player, victim, I.BurnTicks, I.BurnDamage, I.BurnInterval, "Immolate")
		end
	end
end

-- What the shooter's fireball stopped on. Checked, then applied. The outcome names are CombatCore's.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "FireballHit" or type(a) ~= "table" then return end
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
	-- on the line (the ball has a radius, and the reported point is where its cast stopped) ...
	local tHit, off = nearestOnLine(shot, position)
	if off > T.Fireball.Radius + 1.5 then
		Core.CountShot("rej_offline")
		return
	end
	-- ... and no sooner than the fireball could have flown there
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
	-- only a PAID throw lands (2026-10-19, audit P1-12 / GC-14): its splash can hurt even off a wall
	if not Core.TakePaidM1(player) then
		Core.CountShot("rej_unpaid")
		return
	end
	Core.CountShot("hit")
	landFireball(player, shot, position, humanoid)
	Core.ShotImpact:Fire(part, position, player)
end)

----------------------------------------------------------------------------------------------------
-- PRIMARY: IMMOLATE, and the PASSIVE: EMBER REFUND
----------------------------------------------------------------------------------------------------
local function castImmolate(player, character)
	character:SetAttribute("StacksMax_Primary", T.Immolate.Stacks)
	character:SetAttribute("Stacks_Primary", T.Immolate.Stacks)
	broadcast("Immolate", { Character = character, T0 = workspace:GetServerTimeNow() })
end

-- "Landing a kill refunds 30% of Immolate's cooldown": a Pyro's kill, by anything, takes Share of Immolate's
-- full cooldown off what is left of it. PassiveProc (server time) marks the moment; every client flares the
-- mote ring from the broadcast.
-- What sets it off is T.EmberRefund.Trigger (2026-10-17, the owner's pick): "LowHealth" since then, "Kill" before.
local function emberRefund(caster, victimHumanoid)
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	if not holds(caster, "Primary", "Immolate") then return end
	local character = caster.Character
	if not (character and character.Parent) then return end
	local serverNow = workspace:GetServerTimeNow()
	local readyAt = character:GetAttribute("CD_Primary") or 0
	if readyAt > serverNow then
		character:SetAttribute("CD_Primary",
			math.max(serverNow, readyAt - T.EmberRefund.Share * ABILITY.Immolate.Cooldown))
	end
	character:SetAttribute("PassiveProc", serverNow)
	-- From (2026-10-05, the owner's call with the flame look): where the enemy fell, so the flame look's ember streak
	-- flies from the right spot even when that body is already gone on a client. Visual only: no mechanic reads it.
	local from = nil
	local victim = typeof(victimHumanoid) == "Instance" and victimHumanoid.Parent or nil
	if victim then
		local part = victim:FindFirstChild("HumanoidRootPart") or (victim:IsA("Model") and victim.PrimaryPart) or nil
		if part and part:IsA("BasePart") then from = part.Position end
	end
	broadcast("EmberRefund", { Character = character, From = from })
end

Core.OnKill(function(caster, victimHumanoid)
	if T.EmberRefund.Trigger == "Kill" then emberRefund(caster, victimHumanoid) end
end)

-- The duel trigger: a kill ends a duel round, so the kill rule never paid out there. A hit of the Pyro's that takes an
-- enemy from Below of their max health or more to under it (and leaves them standing) pays it instead.
Core.OnHitLanded(function(caster, humanoid, amount, info)
	if T.EmberRefund.Trigger ~= "LowHealth" then return end
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") or humanoid.Parent == caster.Character then return end
	local line = T.EmberRefund.Below * humanoid.MaxHealth
	-- (2026-10-19, audit P3-01) the health this hit left (CombatCore's info.HealthAfter), not what a reaction bonus from the
	-- same hit has since moved it to
	local after = (info and info.HealthAfter) or humanoid.Health
	local before = after + ((info and info.Removed) or 0)
	if after > 0 and after < line and before >= line then
		emberRefund(caster, humanoid)
	end
end)


----------------------------------------------------------------------------------------------------
-- ULTIMATE: RING OF FIRE
----------------------------------------------------------------------------------------------------
-- POINTED (2026-09-14): the cast carries the ground spot the caster aimed at, and the hand draws the circle round
-- it by itself -- the broadcast plays that draw for everyone, and the circle being drawn is the telegraph.

--- The ground under `point`, found straight down THROUGH characters: a spot on an enemy (or a dummy) is the floor
--- round their feet, not their torso -- which would lift the circle over them and out of reach of its own fire.
local function groundUnder(point, caster)
	local list = { caster }
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

--- (2026-10-19, audit P1-09) LINE OF SIGHT for the aimed spot. The honest client can only pick a spot its camera sees, so
--- the server asks the same of its own copy of the world: from the caster's eye to the spot -- or to a point a few studs
--- over it, so low cover in front of the spot does not hide it -- nothing solid may stand in between. Bodies never count;
--- a Bulwark Wall does (Core.Blocked's rule). A spot out of sight is grounded again from just short of the first thing in
--- the way (the line to the highest point), so a spot through a wall, or on the storey above or below, comes back to this
--- side of it. nil when there is no floor there either.
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

local rings = {}           -- [player] = the Ring of Fire still being drawn: { Character, Center, LockAt, Locked, Tokens, At }

local function castRingOfFire(player, character, humanoid, root, payload)
	local R = T.RingOfFire
	local center = payload.Center
	local ok = Core.ValidVector(center)
	if ok then
		-- the client pulls its spot in to Range from where it stands; the slack is the server's copy trailing it
		local flat = Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z)
		ok = flat.Magnitude <= ABILITY.RingOfFire.Range + 8
	end
	if not ok then
		-- a spot that could not have been aimed at from here: nothing happens, and the Ultimate is given back
		addUltCharge:Fire(player, 1)
		return
	end
	local radius = R.Radius
	local ground = groundUnder(center, character) or center
	-- (2026-10-19, audit P1-09) ...and in the caster's sight: through a wall it comes back to this side, and with no floor
	-- on this side at all it is refused like a spot out of reach
	ground = inSight(character, root, ground)
	if not ground then
		addUltCharge:Fire(player, 1)
		return
	end
	local fuse = R.DrawTime + R.SettleTime + R.SnapBeat
	local ring = { Character = character, Center = ground, LockAt = os.clock() + fuse, Tokens = 3, At = os.clock() }
	rings[player] = ring
	broadcast("RingOfFire", {
		Character = character, Center = ground, Radius = radius, Hot = false, T0 = workspace:GetServerTimeNow(),
		Start = PyroFX.RingStartAngle(ground, root.Position),
	})
	-- the draw, the settle, then the snap-and-point: the eruption lands on the point's ignition frame, wherever the
	-- caster's aim had moved the circle to by then. The circle is armed once it is cast, so it erupts even if its
	-- caster has fallen by then.
	task.delay(fuse, function()
		-- cleared before the snap (its caster left the arena, or a duel round was reset): it never erupts
		if ring.Cancelled then return end
		ring.Locked = true
		if rings[player] == ring then rings[player] = nil end
		ground = ring.Center
		broadcast("RingOfFireLock", { Character = character, Center = ground })
		local reach = radius
		for victim, model in pairs(Core.HumanoidsNear(ground + Vector3.new(0, 3, 0), reach + 4, character)) do
			local vroot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if vroot then
				local d = vroot.Position - ground
				if Vector3.new(d.X, 0, d.Z).Magnitude <= reach and d.Y >= -2 and d.Y <= R.Height then
					-- (2026-10-19, audit P4-13) a Bulwark Wall takes the eruption and nothing else: no burn, no Burning tag
					if Core.DealDamage(player, victim, R.Damage, { From = ground })
						and not Core.IsWall(model) then
						burn(player, victim, R.BurnTicks, R.BurnDamage, R.BurnInterval)
					end
				end
			end
		end
	end)
end

-- While the circle is being drawn, its caster's crosshair moves it (asked for 2026-09-14): the client sends the
-- ground spot under its aim a few times a second, pulled in to Range as the cast was. Each is checked the way the
-- cast's own spot is, grounded here, and passed on to everyone else. Nothing moves it once the snap has come.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "RingOfFireSteer" then return end
	local ring = rings[player]
	if not ring or ring.Locked or not Core.ValidVector(a) then return end
	local now = os.clock()
	if now >= ring.LockAt then return end
	-- a spot at most 30 times a second, with a few of slack (the client sends 15)
	ring.Tokens = math.min(3, ring.Tokens + (now - ring.At) * 30)
	ring.At = now
	if ring.Tokens < 1 then return end
	ring.Tokens -= 1
	local character, _, root = Core.AliveCharacter(player)
	if not character or character ~= ring.Character then return end
	local flat = Vector3.new(a.X - root.Position.X, 0, a.Z - root.Position.Z)
	if flat.Magnitude > ABILITY.RingOfFire.Range + 8 then return end
	local ground = groundUnder(a, character)
	if not ground then return end
	ground = inSight(character, root, ground)        -- (2026-10-19, audit P1-09) as the cast's own spot
	if not ground then return end
	ring.Center = ground
	broadcast("RingOfFireSteer", { Character = character, Center = ground })
end)

----------------------------------------------------------------------------------------------------
-- MOBILITY, Pyro's own (Q): DETONATE
----------------------------------------------------------------------------------------------------
-- 2026-09-23. The backhand flick MARKS whoever the caster last hit with Fireball or Immolate (DETONATE'S TARGET, above),
-- and a Fuse later the mark EXPLODES, harder the lower their health: Base at full, rising in a straight line to
-- Base + Bonus at FullAt of their health or lower, read the moment it goes off -- so hits landed during the fuse raise
-- the payout. One body, no splash. The mark is RX_Primed and its suffixes on the victim, which every client draws (a late
-- joiner too), plus the DetonateMark / DetonateBlast / DetonateFizzle broadcasts. One live mark per caster. An armed
-- mark goes off even if its caster has fallen since (as an armed Ring of Fire erupts), and fizzles if the caster was
-- cleared, or the victim died, was cleared, or may no longer be hurt. Deliberately NOT RX_Marked: that is Umbra's Mark
-- for Death, with its own art and burst.
local marks = {}           -- [player] = their live mark: { Caster, Character, Victim, Model, Epoch, VictimEpoch, Fuse, Expires }
local shownMark = setmetatable({}, { __mode = "k" })   -- [victim model] = the mark its RX_Primed attributes show

-- SpellshotService asks this BEFORE it charges a Detonate press (Precheck = true on the row): true only with a target,
-- so a press with none costs nothing at all. Built whole, its answer set first and parented last, so the service never
-- finds it unanswered -- and it refuses anything that does not answer true, so a missing one fails closed.
do
	local precheck = spellFolder:FindFirstChild("Precheck_Detonate")
	local fresh = not (precheck and precheck:IsA("BindableFunction"))
	if fresh then
		precheck = Instance.new("BindableFunction")
		precheck.Name = "Precheck_Detonate"
	end
	precheck.OnInvoke = function(player)
		local _, _, root = Core.AliveCharacter(player)
		return detonateTarget(player, root) ~= nil
	end
	if fresh then precheck.Parent = spellFolder end
end

local function victimPosition(model)
	local vroot = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	return vroot and vroot.Position or nil
end

--- The suffixes first and the flag LAST, so a client that sees RX_Primed rise already has its countdown.
local function showMark(mark)
	local model = mark.Model
	if not model.Parent then return end
	shownMark[model] = mark
	model:SetAttribute("RX_Primed_Element", "Pyro")
	model:SetAttribute("RX_Primed_Expires", mark.Expires)
	model:SetAttribute("RX_Primed_Total", mark.Fuse)
	model:SetAttribute("RX_Primed_By", mark.Caster.UserId)
	model:SetAttribute("RX_Primed_Paid", false)       -- (2026-10-19, audit GA-06) true only when it goes off (hideMark)
	model:SetAttribute("RX_Primed", true)
end

--- The flag down FIRST, then the suffixes -- and only while the attributes are still this mark's, so a stale clear never
--- wipes a newer mark (another caster's, on a dummy).
local function hideMark(mark, paid)
	local model = mark.Model
	if shownMark[model] ~= mark then return end
	shownMark[model] = nil
	if not model.Parent then return end
	-- (2026-10-19, audit GA-06) BarFX's payoff marker, before the flag falls: true when the mark went off, false for a
	-- fizzle or a clear. It stays after the flag (the next showMark resets it), so the client reads it with the fall
	model:SetAttribute("RX_Primed_Paid", paid == true)
	model:SetAttribute("RX_Primed", false)
	for _, suffix in ipairs({ "_Element", "_Expires", "_Total", "_By" }) do
		model:SetAttribute("RX_Primed" .. suffix, nil)
	end
end

--- A mark ends: off the victim, no longer its caster's live one, and -- unless it went off -- a fizzle everyone draws.
local function endMark(mark, fizzle)
	if mark.Done then return end
	mark.Done = true
	if marks[mark.Caster] == mark then marks[mark.Caster] = nil end
	hideMark(mark, not fizzle)
	if fizzle then
		broadcast("DetonateFizzle", { Victim = mark.Model, Position = victimPosition(mark.Model) })
	end
end

--- Whether a Detonate may still land: its caster not cleared since the press (a caster who has only fallen passes), the
--- victim alive and in its body, not cleared since either (a player's epoch), and still someone the caster may hurt -- a
--- victim who has gone to the Hub is not.
--- A caster who has LEFT the game is not one who has only fallen (review r1, 2026-09-24): leaving never moves the epoch,
--- so a Detonate pressed in the Trigger before they left used to mark after PlayerRemoving had run -- writing marks[] for
--- a Player no longer there -- and blow up in their name a Fuse later, on a duel winner still held on the victory screen.
local function markHolds(mark)
	local humanoid, model = mark.Victim, mark.Model
	if gone[mark.Caster] then return false end
	if Core.Epoch(mark.Caster) ~= mark.Epoch or not model.Parent or humanoid.Parent ~= model or humanoid.Health <= 0 then
		return false
	end
	if mark.VictimEpoch ~= nil then
		local victimPlayer = Players:GetPlayerFromCharacter(model)
		if not victimPlayer or Core.Epoch(victimPlayer) ~= mark.VictimEpoch then return false end
	end
	return not Core.IsFriendly(mark.Caster, model)
end

local function explode(mark)
	if mark.Done then return end                       -- replaced by a newer mark, or taken off by a clear or a death
	if not markHolds(mark) then
		endMark(mark, true)
		return
	end
	local D = T.Detonate
	local humanoid, model = mark.Victim, mark.Model
	local health = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	local amount = D.Base + D.Bonus * math.min(1, (1 - health) / (1 - D.FullAt))
	local position = victimPosition(model)
	-- off the victim BEFORE the damage, not after: a blast that kills fires the victim's Died, and that fizzles any mark
	-- still live on them -- which must not be this one, going off
	endMark(mark, false)
	Core.DealDamage(mark.Caster, humanoid, amount, { From = position, Detonate = true })   -- not Ranged, not DoT
	broadcast("DetonateBlast", {
		Character = mark.Character, Victim = model, Position = position, Amount = amount,
		Scale = (amount - D.Base) / D.Bonus, Lethal = humanoid.Health <= 0, T0 = workspace:GetServerTimeNow(),
	})
end

local function castDetonate(player, character, humanoid, root, payload, role)
	local D = T.Detonate
	local rec = detonateTarget(player, root)
	if not rec then
		-- SpellshotService's precheck turned away a press with no target before it cost anything, so this is only the
		-- rare race of a target lost between that check and this one: the whole cast goes back -- the mana, the cooldown
		-- and the Ultimate charge it added (GiveBack's third argument)
		giveBack:Fire(player, role or "Mobility", true)
		return
	end
	local scale = VFXLibrary.ShotTimeScale()
	local mark = {
		Caster = player, Character = character, Victim = rec.Humanoid, Model = rec.Model,
		Epoch = Core.Epoch(player), VictimEpoch = rec.VictimEpoch,
	}
	broadcast("Detonate", { Character = character, T0 = workspace:GetServerTimeNow() })
	-- the mark goes on at the flick's Trigger in the approved clip (slowed with the dev ShotTimeScale, as the clip is),
	-- if nothing has changed since the press that would stop it landing
	task.delay(D.Trigger / scale, function()
		if not markHolds(mark) then
			broadcast("DetonateFizzle", { Victim = mark.Model, Position = victimPosition(mark.Model) })
			return
		end
		local old = marks[player]
		if old then endMark(old, true) end                -- one live mark per caster: the new one replaces it
		local now = workspace:GetServerTimeNow()
		mark.Fuse = D.Fuse / scale
		mark.Expires = now + mark.Fuse
		marks[player] = mark
		-- (2026-10-19, audit GB-03) the broadcast BEFORE the attributes: it alone carries the caster's wrap and the landing
		-- pop, and a client's attribute watcher that started the crown first made the broadcast's own call a duplicate it
		-- threw away. Sent first, it is normally handled first; the attributes still carry the mark to a late joiner.
		broadcast("DetonateMark", {
			Character = character, Victim = mark.Model, Position = victimPosition(mark.Model), T0 = now, Fuse = mark.Fuse,
		})
		showMark(mark)
		watchVictim(mark.Victim)
		task.delay(mark.Fuse, explode, mark)
	end)
end

-- DetonateUntil follows the precheck frame by frame (publishTarget, review r1 2026-09-24): the Window running out, the
-- target walking out of Range and back in, dying, leaving, turning friendly. Only a change is written.
RunService.Heartbeat:Connect(function()
	for player in pairs(lastHit) do
		publishTarget(player)
	end
end)

----------------------------------------------------------------------------------------------------
-- A TECHNIQUE: SCORCHING LASH (either keyed slot; any Element only with TechniquesOwnElementOnly off -- 2026-10-19, audit P4-14)
----------------------------------------------------------------------------------------------------
-- 2026-09-23, reworked 2026-09-24 (round 2, the owner: "if you hold ability of whip, then the whip should be there just
-- you holding it ... should be medium to long range"). HELD, through SpellshotService's held path: the key going down
-- pays for it and sets Holding_<role> (Phase "Start"), and every client hangs the burning whip from the caster's hand
-- (ScorchingLashHold). The key coming up starts the cooldown and hands the release here (Phase "Release", with the
-- client's release payload in Client: its aim, Dir) -- the SWEEP since round 3 (the owner, 2026-09-24: "if u release it
-- comes all the way from the side like in a curve path and hits anything in that path"), relayed with that aim, flat,
-- for every client to draw round the caster. A tap is simply a hold that ends at once. What the sweep HIT is the
-- caster's own client's report at the Trigger (ScorchingLashStrike, below): what stood in the sector it swept on ITS
-- screen, checked here the way Cross-Slash's strike is (ZephyrHandler). A server sweep would miss: the server's copy of
-- a moving player trails its own client by about 0.2 s. Every body struck takes Damage, and every one that is not a
-- wall gains a burn STACK (lashBurns, with the burning above). A hold that ends any other way -- its caster dying or
-- cleared, the Lash swapped out of the slot mid-hold -- sweeps nothing: the whip simply goes (ScorchingLashHold On =
-- false). Held to HoldMax it sweeps by itself (the caster's client lets go at HoldMax; this side follows a moment later if
-- it has not).
local lashes = {}          -- [player] = the lash awaiting its strike: { At (server time), Epoch, Character, Struck, Dir, Role }
local lashHolds = {}       -- [player] = a whip being held: { Role, At (os.clock), Epoch, Character, Died, Auto }
local lashBuckets = {}     -- [player] = { Tokens, At }: how often a strike report may arrive
local LASH_CHEST = 1.5     -- studs above the caster's root: where the strike's aim and line of sight are drawn from
-- the server's own end of a hold held past HoldMax comes this long after the caster's client should have let go of it
local LASH_HOLD_GRACE = 0.5
-- The strike's allowances for a caster the server's copy trails (the origin check and the reach cap) grow with the
-- caster's speed and ping -- and BOTH of those come from the client: the owning client writes its root's velocity, and
-- a lagging one raises its ping. Unbounded, a client that wrote 500 studs/s for one step had a 231-stud origin slack
-- and a 167-stud reach cap, and whipped a body 150 studs away (review r1, 2026-09-24). So each is capped: the speed at
-- the fastest thing a body does on its own feet (Config.Movement.SlideJumpMaxSpeed; a slide is 35, a sprint 25),
-- the lag at a quarter second. A legitimate lash at a sprint on a 150 ms ping keeps its whole allowance.
-- 2026-10-08: READ from the config, no longer a copy of it. The copy stayed 50 when the slide jump's cap went to 70,
-- so a lash cracked at a full slide jump had only 50 studs/s of its trail allowed for.
local LASH_MAX_TRAIL_SPEED = Config.Movement.SlideJumpMaxSpeed
local LASH_MAX_LAG = 0.25
-- the sweep's allowances for lag (round 3): degrees either side of the sector, studs on its reach (Tuning's Slack), on
-- the hug and on the height -- the round-2 capsule's, carried over to the new shape
local LASH_SLACK = { Angle = 10, Reach = T.ScorchingLash.Slack, Inner = 1, Height = 1 }

--- A lash burn goes out: every stack drops, the count comes off the victim, and RX_Burning is recounted.
local function dropLash(humanoid, rec)
	if not rec or lashBurns[humanoid] ~= rec then return end
	lashBurns[humanoid] = nil
	rec.Token = nil
	local model = rec.Model
	if model.Parent then
		refreshBurning(model)                                   -- the flag first (an Immolate burn may still hold it up)
		model:SetAttribute("RX_Burning_Stacks", nil)            -- then the count
		model:SetAttribute("RX_Burning_By", nil)                -- (2026-10-19, audit GB-02) and who lit it
		model:SetAttribute("RX_Burning_Src", nil)
	end
end

--- Every lash burn credited to `caster` goes out (they were cleared, or left the game).
local function putOutLashes(caster)
	local out = {}
	for humanoid, rec in pairs(lashBurns) do
		if rec.Caster == caster then out[humanoid] = rec end
	end
	for humanoid, rec in pairs(out) do
		dropLash(humanoid, rec)
	end
end

--- One more stack on `humanoid` from `caster`'s lash: up to MaxStacks (all casters together), the ticks left reset to
--- Ticks, and the burn credited to whoever lashed last. The first stack starts the one tick clock and later hits never
--- restart it -- a hit never delays a tick; when the ticks run out every stack drops at once.
local function addLashStack(caster, humanoid)
	local L = T.ScorchingLash
	local LB = Status.Tune("Burning").Lash      -- the live status preset's stack cap and tick count (2026-09-24)
	local model = humanoid.Parent
	if not (model and model.Parent) then return end
	local rec = lashBurns[humanoid]
	local fresh = rec == nil
	if fresh then
		local victimPlayer = Players:GetPlayerFromCharacter(model)
		rec = {
			Stacks = 0, TicksLeft = 0, Token = {}, Model = model,
			VictimEpoch = victimPlayer and Core.Epoch(victimPlayer) or nil,
		}
		lashBurns[humanoid] = rec
	end
	rec.Stacks = math.min(LB.MaxStacks, rec.Stacks + 1)
	rec.TicksLeft = LB.Ticks
	rec.Caster, rec.Epoch = caster, Core.Epoch(caster)
	-- (2026-10-19, audit GB-02) who lit this burn, for the client's burn flames (PyroFX reads RX_Burning_By / _Src)
	model:SetAttribute("RX_Burning_By", (typeof(caster) == "Instance" and caster:IsA("Player")) and caster.UserId or nil)
	model:SetAttribute("RX_Burning_Src", "ScorchingLash")
	-- the Element, then the count, then the flag -- the order Chill's stacks are written in
	model:SetAttribute("RX_Burning_Element", "Pyro")
	model:SetAttribute("RX_Burning_Stacks", rec.Stacks)
	refreshBurning(model)
	Status.Stamp(model, "Burning", LB.Ticks * L.Interval)
	watchVictim(humanoid)
	if not fresh then return end
	local token = rec.Token
	task.spawn(function()
		while true do
			task.wait(L.Interval / VFXLibrary.ShotTimeScale())
			if lashBurns[humanoid] ~= rec or rec.Token ~= token then return end     -- already put out (a clear, a death)
			-- out if its (latest) caster has been cleared since, or the victim died, left, or was cleared themselves
			local victimPlayer = rec.VictimEpoch ~= nil and Players:GetPlayerFromCharacter(model) or nil
			if humanoid.Health <= 0 or humanoid.Parent ~= model or not model.Parent or Core.Epoch(rec.Caster) ~= rec.Epoch
				or (rec.VictimEpoch ~= nil and not (victimPlayer and Core.Epoch(victimPlayer) == rec.VictimEpoch)) then
				break
			end
			-- one tick for all the stacks (one damage number), a DoT like any burn tick -- and NOT a hit Detonate marks
			Core.DealDamage(rec.Caster, humanoid, Status.Tune("Burning").Lash.PerStack * rec.Stacks, { DoT = true })
			rec.TicksLeft -= 1
			if rec.TicksLeft <= 0 then break end
		end
		dropLash(humanoid, rec)
	end)
end

--- A hold ends WITHOUT a crack (its caster died or was cleared, or the Lash left the slot mid-hold): every client's whip
--- goes, and if the service still has it held, it is ended there too -- the cooldown starts as a release starts it, and
--- the release that comes back here finds no hold and cracks nothing.
local function endLashHold(player)
	local rec = lashHolds[player]
	if not rec then return end
	lashHolds[player] = nil
	if rec.Died then rec.Died:Disconnect() end
	broadcast("ScorchingLashHold", { Character = rec.Character, On = false })
	local character = rec.Character
	if character and character.Parent and character:GetAttribute("Holding_" .. rec.Role) == "ScorchingLash" then
		releaseHold:Fire(player, rec.Role)
	end
end

--- The Lash's two phases from SpellshotService's held path. `role` is the slot it was cast from (either Technique slot:
--- round 2 made the two keyed slots one pool), which the strike and the forced end both go by.
local function castScorchingLash(player, character, humanoid, root, payload, role)
	if payload.Phase == "Start" then
		-- the whip in the hand, for everyone; a hold still on record (the service never starts two) is ended first
		if lashHolds[player] then endLashHold(player) end
		local rec = { Role = role or "Defense", At = os.clock(), Epoch = Core.Epoch(player), Character = character }
		rec.Died = humanoid.Died:Connect(function()
			if lashHolds[player] == rec then endLashHold(player) end
		end)
		lashHolds[player] = rec
		broadcast("ScorchingLashHold", { Character = character, T0 = workspace:GetServerTimeNow(), On = true })
		return
	end
	if payload.Phase ~= "Release" then return end
	local rec = lashHolds[player]
	if not rec then return end                     -- already ended without a crack (a clear, a death, a swap)
	lashHolds[player] = nil
	if rec.Died then rec.Died:Disconnect() end
	-- (2026-10-19, audit P4-05) an interrupt (Undertow, Aftershock: SpellshotService's Reason) ends it without a crack
	if rec.Character ~= character or rec.Epoch ~= Core.Epoch(player) or not holds(player, rec.Role, "ScorchingLash")
		or payload.Reason == "Interrupted" then
		broadcast("ScorchingLashHold", { Character = rec.Character, On = false })
		return
	end
	-- THE SWEEP, round the caster's aim at the release, FLAT (round 3: the sector is measured in the horizontal plane):
	-- their client's (Client.Dir), if it sent a sane unit vector that is not straight up or down, else the way the
	-- server's copy faces (HoldMax's own end, which carries no client payload)
	local client = type(payload.Client) == "table" and payload.Client or nil
	local sent = client and client.Dir
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if Core.ValidVector(sent) and sent.Magnitude > 0.5 and sent.Magnitude < 1.5
		and Vector3.new(sent.X, 0, sent.Z).Magnitude > 0.1 then
		dir = Vector3.new(sent.X, 0, sent.Z)
	end
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local now = workspace:GetServerTimeNow()
	lashes[player] = {
		At = now, Epoch = Core.Epoch(player), Character = character, Struck = false, Dir = dir, Role = rec.Role,
	}
	broadcast("ScorchingLash", { Character = character, T0 = now, Dir = dir })
end

-- A hold is watched every frame: its body gone or dead, or the Lash no longer in its slot (a swap mid-hold, an Element
-- change) ends it without a crack; one held past HoldMax (the row's, else Tuning's; slowed by ShotTimeScale like every
-- timing here) whose client has not let go is let go from here -- SpellshotService ends it exactly as a release would, and
-- the crack goes out along the server's facing.
RunService.Heartbeat:Connect(function()
	local ending = {}
	for player, rec in pairs(lashHolds) do
		local character = rec.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and character.Parent and hum and hum.Health > 0) or player.Character ~= character
			or not holds(player, rec.Role, "ScorchingLash") then
			ending[#ending + 1] = player
		elseif not rec.Auto then
			local row = ABILITY.ScorchingLash
			local holdMax = (row and row.HoldMax) or T.ScorchingLash.HoldMax or 6
			if os.clock() - rec.At >= holdMax / VFXLibrary.ShotTimeScale() + LASH_HOLD_GRACE then
				rec.Auto = true
				releaseHold:Fire(player, rec.Role)
			end
		end
	end
	for _, player in ipairs(ending) do
		endLashHold(player)
	end
end)

-- THE STRIKE: sent by the caster's client at the crack (the Trigger after its release, on its own cast clock), naming
-- what stood in the swept sector on its screen: { Origin = its root, Dir = its aim, Hits = { { Part, Position }, ... } },
-- the bodies' roots as it saw them. Sent even with no hits, which only closes the lash. Checked as Cross-Slash's strike
-- is: one strike per release, on time, from where the server has the caster; and each body inside the sweep as the
-- caster saw it, somewhere the server had it lately, not beyond the server's own reach, and with nothing solid in
-- between. Outcomes count into ShotStats as lash_hit / lash_rej_<reason>, kept apart from the M1 summary line.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "ScorchingLashStrike" or type(a) ~= "table" then return end
	local L = T.ScorchingLash
	-- a few reports a second at most: a real client sends one per release, and its releases come a cooldown apart
	local clock = os.clock()
	local b = lashBuckets[player]
	if not b then
		b = { Tokens = 3, At = clock }
		lashBuckets[player] = b
	end
	b.Tokens = math.min(3, b.Tokens + (clock - b.At) * 2)
	b.At = clock
	if b.Tokens < 1 then
		Core.CountShot("lash_rej_rate")
		return
	end
	b.Tokens -= 1
	local lash = lashes[player]
	if not lash or lash.Struck then
		Core.CountShot("lash_rej_noshot")
		return
	end
	-- a lash that can never land any more is closed: its caster cleared since the release, in the Hub, no longer holding
	-- the Lash in the slot it cracked from, or unable to act (CanAct, not AliveCharacter: not from underground, nor
	-- across a round reset)
	local character, humanoid, root = Core.CanAct(player)
	if Core.Epoch(player) ~= lash.Epoch or player:GetAttribute("Zone") == "Hub"
		or not holds(player, lash.Role, "ScorchingLash") or not character or character ~= lash.Character then
		lashes[player] = nil
		Core.CountShot("lash_rej_noshot")
		return
	end
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	-- on time: the crack's Trigger after the release was heard (slowed by the dev ShotTimeScale, as the clip is), give or
	-- take the round trip. Early is a report from before the whip could have got there, and does not close the lash
	-- (only a strike that passes these checks does); late closes it for good
	local since = workspace:GetServerTimeNow() - lash.At
	local due = L.Trigger / VFXLibrary.ShotTimeScale()
	if since < due - 0.12 - ping then
		Core.CountShot("lash_rej_early")
		return
	elseif since > due + 0.5 + ping then
		lashes[player] = nil
		Core.CountShot("lash_rej_late")
		return
	end
	-- from where the server has the caster, allowing for its copy of a moving body trailing the real one (at most
	-- LASH_MAX_TRAIL_SPEED and LASH_MAX_LAG of it)
	local origin = a.Origin
	local lag = math.min(ping, LASH_MAX_LAG)
	local speed = math.min(Core.TrailSpeed(root, humanoid.WalkSpeed), LASH_MAX_TRAIL_SPEED)
	if not Core.ValidVector(origin) or (origin - root.Position).Magnitude > 6 + speed * (0.35 + lag) then
		Core.CountShot("lash_rej_origin")
		return
	end
	lash.Struck = true                                   -- one strike per release, whatever its claims come to
	-- THE SWEEP (round 3): round the caster's root as they reported it, from the flat aim the release carried (lash.Dir
	-- -- what every client drew the sweep round): SweepFrom .. SweepTo degrees out to Reach, or within Inner at any angle,
	-- root - Down .. root + Up (PyroFX.LashSweepHas, the shape the client gathered with), plus LASH_SLACK for lag
	local aim = lash.Dir
	local chest = origin + Vector3.new(0, LASH_CHEST, 0)
	-- the server's own cap: the claim's flat reach from the SERVER's copy of the caster, its trail allowed for. Without
	-- it the origin's slack and the sweep's reach add up to more than the whip. Reach + Slack + 4, plus the bounded trail
	-- (LASH_MAX_*): at most 40.5 + 70 x 0.45 = 72 studs, however fast or late the client says it is
	local velocity = root.AssemblyLinearVelocity
	local flatSpeed = math.min(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, LASH_MAX_TRAIL_SPEED)
	local serverReach = L.Reach + L.Slack + 4 + flatSpeed * (0.2 + lag)
	local struck, victims, positions = {}, {}, {}
	local function claim(h)
		local part, position = type(h) == "table" and h.Part, type(h) == "table" and h.Position
		if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
			or not Core.ValidVector(position) then
			Core.CountShot("lash_rej_badpart")
			return
		end
		-- the SWEEP as the caster saw it (the origin and the point are both from their screen)
		if not PyroFX.LashSweepHas(position - origin, aim, LASH_SLACK) then
			Core.CountShot("lash_rej_offline")
			return
		end
		local fromServer = position - root.Position
		if Vector3.new(fromServer.X, 0, fromServer.Z).Magnitude > serverReach then
			Core.CountShot("lash_rej_reach")
			return
		end
		-- a body the server had near that point lately (CombatCore's history), or a point actually on a wall
		local reason, model, victim = Core.CheckTarget(part, position, character)
		if reason then
			Core.CountShot("lash_" .. reason)
			return
		end
		if not (victim and victim.Health > 0) then
			Core.CountShot("lash_rej_badpart")                   -- a part of no one, or of someone already down
			return
		end
		if struck[model] then
			Core.CountShot("lash_rej_repeat")
			return
		end
		if Core.IsFriendly(player, model) then
			Core.CountShot("lash_rej_friendly")
			return
		end
		-- nothing solid between the caster's chest and them (Pyro's own line check, where a Bulwark Wall is cover)
		if lineBlocked(chest, position, { character, model }) then
			Core.CountShot("lash_rej_blocked")
			return
		end
		struck[model] = true
		Core.CountShot("lash_hit")
		victims[#victims + 1] = model
		positions[#positions + 1] = position
		-- a wall takes the hit, but a burn is for bodies
		if Core.DealDamage(player, victim, L.Damage, { From = root.Position }) and not Core.IsWall(model)
			and victim.Health > 0 then
			addLashStack(player, victim)
		end
	end
	local hits = type(a.Hits) == "table" and a.Hits or {}
	for i = 1, math.min(#hits, L.MaxTargets) do
		claim(hits[i])
	end
	if #victims > 0 then
		broadcast("ScorchingLashHit", { Character = character, Victims = victims, Positions = positions })
	end
end)

----------------------------------------------------------------------------------------------------
-- what a victim's death (or clear) takes off them
----------------------------------------------------------------------------------------------------
--- Everything these two left on `humanoid`: every live Detonate mark on it fizzles, its lash stacks drop, and every
--- Pyro's Detonate note pointing at it goes (their HUD stops offering a target that is no longer there).
local function clearVictim(humanoid)
	local ending = {}
	for _, mark in pairs(marks) do
		if mark.Victim == humanoid then ending[#ending + 1] = mark end
	end
	for _, mark in ipairs(ending) do
		endMark(mark, true)
	end
	dropLash(humanoid, lashBurns[humanoid])
	local noted = {}
	for caster, rec in pairs(lastHit) do
		if rec.Humanoid == humanoid then noted[#noted + 1] = caster end
	end
	for _, caster in ipairs(noted) do
		dropTarget(caster)
	end
end

-- A body's DEATH takes the mark and the lash stacks off it, hooked once per humanoid the first time either (or a
-- Detonate note) lands on it. A training dummy never dies -- it refills at 0 -- so its refill clears nothing.
local watched = setmetatable({}, { __mode = "k" })
watchVictim = function(humanoid)
	if watched[humanoid] then return end
	watched[humanoid] = true
	humanoid.Died:Connect(function()
		clearVictim(humanoid)
	end)
end


----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
local casts = {
	Fireball = castFireball,
	Immolate = castImmolate,
	RingOfFire = castRingOfFire,
	Detonate = castDetonate,                 -- Pyro's own Mobility slot (2026-09-23)
	ScorchingLash = castScorchingLash,       -- a Technique (2026-09-23; held, either slot, since round 2)
}

-- the role rides along as a sixth argument (2026-09-23), for a cast that has to hand itself back (GiveBack is by role);
-- the casts that do not need it ignore it
performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return end
	fn(player, character, humanoid, root, type(payload) == "table" and payload or {}, role)
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
--- Immolate's flame count exists only while the player's Primary Ability is Immolate.
local function refreshKit(player)
	local character = player.Character
	if not character then return end
	if holds(player, "Primary", "Immolate") then
		character:SetAttribute("StacksMax_Primary", T.Immolate.Stacks)
		if character:GetAttribute("Stacks_Primary") == nil then character:SetAttribute("Stacks_Primary", 0) end
	else
		character:SetAttribute("StacksMax_Primary", nil)
		character:SetAttribute("Stacks_Primary", nil)
	end
end

local function watch(player)
	player.CharacterAdded:Connect(function()
		task.defer(refreshKit, player)
		task.defer(publishTarget, player)          -- a new body carries the Detonate note's DetonateUntil too
	end)
	player:GetAttributeChangedSignal("Element"):Connect(function()
		refreshKit(player)
	end)
	task.defer(refreshKit, player)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

Players.PlayerRemoving:Connect(function(player)
	shots[player] = nil
	buckets[player] = nil
	-- (2026-10-19, audit P3-07) a ring still being drawn never erupts, even if this runs before OnClear's (which then finds
	-- no ring to cancel)
	if rings[player] then rings[player].Cancelled = true end
	rings[player] = nil
	-- Detonate and Scorching Lash (2026-09-23): a leaver's live mark fizzles, and lash burns credited to them go out.
	-- They are GONE first (review r1, 2026-09-24): a mark still on its way to its Trigger fizzles there instead of
	-- landing (markHolds), and a burn of theirs still ticking can no longer write their Detonate note back (noteHit)
	gone[player] = true
	local mark = marks[player]
	if mark then endMark(mark, true) end
	lastHit[player] = nil
	endLashHold(player)                  -- round 2: a whip still held goes for everyone
	lashes[player] = nil
	lashBuckets[player] = nil
	putOutLashes(player)
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer). A Ring of Fire still being drawn never erupts; fireballs
-- in flight land nowhere; and burning and Immolate's charged throws come off the player. Burns they set on others, and
-- a haze already on its way, check the epoch and stop.
-- 2026-09-23: their live Detonate mark fizzles and their Detonate note goes; a whip they hold goes without a crack
-- (round 2), a lash still waiting for its strike never lands, and lash burns credited to them go out at once (rather than at their next tick, so the stacks leave a dummy
-- with them). And what is ON them comes off: anyone's mark (fizzling), the lash stacks, and every Pyro's note on them.
-- ELEMENTAL REACTIONS (2026-10-17): Burn's levers for ServerScriptService.ElementalReactions. Melt, Overload and Combustion
-- consume a Burn (both channels go out); Wildfire fans it: one more lash stack and a fresh tick count, credited to whoever
-- lit the lash (or, on an Immolate burn alone, to the fanner), exactly as one more Scorching Lash stack would be.
Core.Hooks.ClearBurn = function(humanoid)
	burns[humanoid] = nil
	local rec = lashBurns[humanoid]
	if rec then dropLash(humanoid, rec) end
	refreshBurning(humanoid.Parent)
end
Core.Hooks.FanBurn = function(caster, humanoid)
	local rec = lashBurns[humanoid]
	addLashStack(rec and rec.Caster or caster, humanoid)
end
--- A test burn (the dev panel's REACTIONS row): `stacks` lash stacks from `caster`.
Core.Hooks.AddBurn = function(caster, humanoid, stacks)
	for _ = 1, stacks or 1 do addLashStack(caster, humanoid) end
end

Core.OnClear(function(player)
	local character = player.Character
	local ring = rings[player]
	if ring then
		ring.Cancelled = true
		rings[player] = nil
	end
	shots[player] = nil
	local mark = marks[player]
	if mark then endMark(mark, true) end
	dropTarget(player)
	endLashHold(player)                  -- round 2: a held whip goes without a crack, and its cooldown starts
	lashes[player] = nil
	putOutLashes(player)

	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- both burns come off, and RX_Burning is recounted from both channels rather than simply lowered
		burns[humanoid] = nil
		clearVictim(humanoid)
		refreshBurning(character)
	end
	if character:GetAttribute("Stacks_Primary") then character:SetAttribute("Stacks_Primary", 0) end
end)
