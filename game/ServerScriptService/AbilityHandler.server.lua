--[[
	AbilityHandler  (Script)  ->  ServerScriptService/AbilityHandler

	The gameplay side of the finalized Cryo kit (design manual v0.2, Section 2).

	  Primary Ability   Flash Freeze   ground zone where the crosshair points (20 studs, 2026-10-18); linger
	                                   past 1s -> rooted; still frozen when the zone ends -> shattered for heavy damage
	  Technique         Blizzard       a storm where the crosshair points (20 studs, 2026-10-18): everyone else
	                                   inside is slowed and can barely see (2026-09-24, replaces Frost Slide)
	  Technique         Deep Freeze    an unseen trap at the caster's feet: whoever sets it off is
	                                   sealed in a crystal prison, rooted (replaces Chill Aura)
	  Ultimate          Mirror Cage    a dome of ice mirrors round the lock: every enemy inside is
	                                   trapped and shot by their own reflections (replaces Cryo Beam)
	  (Frost Slide, Chill Aura and Cryo Beam keep their code below, unreachable: no row, no pool entry,
	  no `casts` entry. The numbers of the new three are ReplicatedStorage.IceMagic.CryoTuning.)

	Glacial Spikes and Diamond Skin were cut with the v0.2 kit. Their cast paths, damage tables,
	plate-cracking hit signal and remote actions are all gone rather than disabled.

	WHERE CASTS COME FROM
	  SpellshotService validates and charges the cast, then fires Spellshot.PerformCast. This
	  script never sees a request that has not already paid its mana or Ultimate charge, which is
	  why there is no cooldown bookkeeping left in here.

	M1 HITS
	  The shooter's client decides what an Icicle Shard hit -- the rod it draws stops on something
	  and it reports that ("ShardHit") -- and this script checks the claim before applying it. The
	  server used to fly the shot itself and missed whatever moved: every client draws moving things
	  about a sixth of a second behind the server, so a strafing target you had dead centre was
	  already 2-3 studs further on here (18 of 20 such shots missed in a trial).

	Server -> client protocol (see AbilityFX.client):
	  ("VFX", kind, data)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local SkinCatalog = require(spellFolder:WaitForChild("SkinCatalog"))     -- the caster's HUD skin, stamped on Chill
-- Damage, the friendly-fire rule and the M1 hit checks are shared with the other kits (CombatCore): a
-- shield has to soak an Icicle Shard, and a hit is a hit for every passive that listens.
local Core = require(script.Parent:WaitForChild("CombatCore"))
-- ELEMENTAL APPLICATION (2026-09-24): Chill's numbers come from the live status preset, and it publishes its clock
local Status = require(script.Parent:WaitForChild("StatusEffects"))

local remote = Core.Remote

local performCast = spellFolder:WaitForChild("PerformCast")
local giveBack = spellFolder:WaitForChild("GiveBack")
-- the rebuilt Techniques' and Ultimate's numbers (2026-09-24): one table, read by the client's visuals too
local CRYO = require(iceFolder:WaitForChild("CryoTuning"))

local T = VFXLibrary.Tuning

local Tune = {
	FriendlyFire = false,          -- when false, players on the caster's Team are never hit

	-- Icicle Shard (M1): the manual's "fast flat trajectory, low damage, stacks Chill; 3 stacks
	-- briefly roots". The damage is a starting number, about 13 hits from full health.
	ShardDamage = 8,
	-- SUPERSEDED 2026-09-24: chillFromShard reads the live status preset (StatusEffects.Tune("Chilled")) instead of the
	-- four rows below, so the balance presets can be switched in play. These are the values the build ran before that.
	ShardChillSpeed = { 22, 15 },   -- speed cap at 1 and 2 stacks (a sprint is 30)
	ShardChillWindow = 5.0, --[[3.0 until the 2026-10-17 balance pass; nothing reads it, StatusEffects' Chill preset owns the window]]         -- stacks lapse this long after the last hit
	ShardRootTime = 0.8,            -- the third stack roots for this long, then the stacks clear
	ShardRootImmunity = 1.2,        -- no new stacks for this long after a root ends

	-- Flash Freeze: the front itself is a light hit; the payoff is the shatter on anyone who
	-- stayed in it, which is what makes the zone a real decision rather than chip damage.
	FlashFreezeContactDamage = 10,
	FlashFreezeShatterDamage = 34,
	FlashFreezeSlowSpeed = 5,

	-- Chill Aura: low damage, heavy slow. Standing in someone's aura should feel like a mistake
	-- you can walk out of, not a burst you cannot react to.
	AuraDamagePerTick = 3,
	AuraSlowSpeed = 8,
	AuraSlowDuration = 1.0,
	AuraFreezeAfter = 2.5,         -- seconds of continuous exposure before it roots instead

	-- Cryo Beam: the Ultimate. Damage is per second while the beam is on a target; at 46/s a
	-- full 2.4s channel is lethal from full health, which is what a charge-gated Ultimate that
	-- costs you a second and a half of standing still should be worth.
	BeamDamagePerSecond = 46,
	BeamTickRate = 0.15,
	BeamHitRadius = 4.0,
	BeamSlowSpeed = 9,
	BeamSlowTime = 0.9,
}

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
Core.FriendlyFire = Tune.FriendlyFire

-- the shared helpers, under the names this script has always used
local broadcast = Core.Broadcast
local fxFolder = Core.FxFolder
local aliveCharacter = Core.AliveCharacter
local validVector = Core.ValidVector
local clampTarget = Core.ClampTarget
local isFriendly = Core.IsFriendly
local humanoidsNear = Core.HumanoidsNear
-- A Bulwark Wall carries a Humanoid so that hits damage it, which also puts it in humanoidsNear's answers. Every
-- status this kit lands landed on the wall as well (2026-09-21): Chill stacks and a root on it, the ice Highlight
-- painted over its invisible 12-stud box, the body shatter bursting in mid-air at its centre, and Status attributes
-- pinned on it forever because the sweep only walks player characters. Damage on a wall is the design; nothing else is.
local isWall = Core.IsWall

----------------------------------------------------------------------------------------------------
-- PASSIVE: COLD MOMENTUM (Cryo)
----------------------------------------------------------------------------------------------------
-- "+10% move speed for 2s after landing any hit". Every hit a Cryo player lands -- shard, zone
-- contact, shatter, aura tick, beam tick, a training dummy too -- (re)starts the window. The bonus
-- is published as the character's MoveSpeedMult attribute, which SpellshotService multiplies into
-- the stance speed (under any slow's cap) and MovementController predicts the same way, so a slow
-- still wins over the buff. PassiveActive / PassiveExpires (server time) light the HUD and the
-- footfall frost marks, and RX_Haste raises the game's existing speed-buff reaction.
local coldMomentum = {}   -- [character] = token of the newest hit
local function onHitLanded(caster)
	if not caster or (caster:GetAttribute("Element") or Config.DefaultLoadout.Element) ~= "Cryo" then return end
	local character = caster.Character
	if not character then return end
	local passive = Config.Elements.Cryo.Passive
	local token = (coldMomentum[character] or 0) + 1
	coldMomentum[character] = token
	character:SetAttribute("PassiveActive", true)
	character:SetAttribute("PassiveExpires", workspace:GetServerTimeNow() + passive.Duration)
	character:SetAttribute("MoveSpeedMult", 1 + passive.SpeedBonus)
	character:SetAttribute("RX_Haste_Element", "Cryo")
	character:SetAttribute("RX_Haste", true)
	task.delay(passive.Duration, function()
		if coldMomentum[character] ~= token then return end        -- a newer hit extended it
		coldMomentum[character] = nil
		if not character.Parent then return end
		-- (2026-10-19, audit P4-20) the buff comes off only while it is still Cryo's own: MoveSpeedMult and PassiveActive
		-- are shared with Aqua's Riding the Current, and an Element switch inside the window hands them to it
		if character:GetAttribute("MoveSpeedMult") == 1 + passive.SpeedBonus then
			character:SetAttribute("PassiveActive", false)
			character:SetAttribute("PassiveExpires", 0)
			character:SetAttribute("MoveSpeedMult", 1)
		end
		character:SetAttribute("RX_Haste", false)
	end)
end

-- Every landed hit from any kit (a Cryo player's own, or -- with Config.TechniquesOwnElementOnly off -- another
-- Element's Technique they borrowed; 2026-10-19, audit P4-14) restarts Cold Momentum for a Cryo caster: CombatCore
-- tells every listener.
Core.OnHitLanded(function(caster)
	onHitLanded(caster)
end)

--- `info` is what the damage modifiers read: Ranged = true for a projectile or a beam,
--- From = where the hit came from.
local function dealDamage(caster, humanoid, amount, info)
	return Core.DealDamage(caster, humanoid, amount, info)
end

--- Bridge to the SPELLSHOT status tag, so the floating tag over a victim (and the local copy
--- above their own health bar) lights up from real play.
local applyStatusTag = Core.ApplyStatusTag

-- A slow is a CAP, not a speed. It is published as the character's SpeedCapSlow attribute, and
-- SpellshotService applies min(stance speed, caps) whenever either changes -- so a slow cannot be
-- shrugged off by changing stance mid-slow, and when it ends you get the speed of whatever you
-- are doing NOW. (It used to put back the speed you had when it began: slowed while standing
-- still, you stayed at walking pace afterwards even at a full sprint.) The client's slide and
-- slide-jump read the same attribute, so they obey it too.
--
-- OVERLAPPING SLOWS. Every slow on a humanoid is kept as its own { Speed, Until }, and the cap is
-- the tightest one still running. It used to be one shared record in which the NEWEST slow's timer
-- decided when everything ended, and the cap only ever went down: a 1 s chill landing on a 4 s root
-- cut the root to 1 s, and a longer, milder slow landing on a root held the root's 0 until that
-- slow ran out. Now each entry lapses on its own clock, and the cap is recomputed and republished as
-- each one does.
--
-- JUMPING (fixed 2026-09-14). A slow no longer takes jumping away: only a ROOT (a slow to 0) and the
-- Cryo Beam's lift do, and they hold named locks on one table per humanoid. Jumping is off while any
-- lock is held and comes back to the place's own jump (StarterPlayer) when the last one lets go. It
-- used to be zeroed by EVERY slow -- one Chill shard cost jumping for its whole duration -- and put back
-- from a snapshot taken when the first slow of a chain began, so a slow that landed while a Cryo Beam
-- had jumping at 0 put back 0: no jumping again until respawn.
local BASE_JUMP_HEIGHT = game:GetService("StarterPlayer").CharacterJumpHeight
local BASE_JUMP_POWER = game:GetService("StarterPlayer").CharacterJumpPower
local jumpLocks = setmetatable({}, { __mode = "k" }) -- [humanoid] = { [reason] = true }
-- (2026-10-19, audit P1-03) [humanoid] = the body whose CombatCore "CryoRoot" hold this file has on (see setJumpLock)
local rootHolds = setmetatable({}, { __mode = "k" })

local function setJumpLock(humanoid, reason, on)
	local locks = jumpLocks[humanoid] or {}
	locks[reason] = on and true or nil
	local locked = next(locks) ~= nil
	jumpLocks[humanoid] = locked and locks or nil
	humanoid.JumpHeight = locked and 0 or BASE_JUMP_HEIGHT
	humanoid.JumpPower = locked and 0 or BASE_JUMP_POWER
	-- (2026-10-19, audit P1-03) THE ROOT IS THE SERVER'S. The "Root" lock is set wherever the slow cap is recomputed, and
	-- is on exactly while the tightest running cap is 0 (Flash Freeze, its frozen patches, Deep Freeze's prison, Mirror
	-- Cage, a reaction's root) -- overlapping roots included, since it follows the recount. While it is on, the body's
	-- physics are the server's (Core.HoldBody: network ownership, players only), so a modified client cannot walk out of
	-- it. Only a change is passed on, so the hold is taken and let go once each.
	if reason == "Root" and Core.HoldBody then
		local held = rootHolds[humanoid]
		local model = humanoid.Parent
		if on and not held and model then
			rootHolds[humanoid] = model
			Core.HoldBody(model, "CryoRoot", true)
		elseif not on and held then
			rootHolds[humanoid] = nil
			Core.HoldBody(held, "CryoRoot", false)
		end
	end
end

-- Other kits' own roots lock jumping through here, so the jump lock keeps ONE writer (RadiantHandler's Benediction,
-- 2026-09-29): Spellshot.JumpLock:Fire(humanoid, reason, on). Each caller sets and clears only its own reason; this
-- file's own reasons ("Root", "CryoBeam") are not theirs to touch.
do
	local ev = spellFolder:FindFirstChild("JumpLock")
	if not ev then
		ev = Instance.new("BindableEvent")
		ev.Name = "JumpLock"
		ev.Parent = spellFolder
	end
	ev.Event:Connect(function(humanoid, reason, on)
		if typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid") and type(reason) == "string"
			and reason ~= "Root" and reason ~= "CryoBeam" then
			setJumpLock(humanoid, reason, on)
		end
	end)
end

local slowed = {} -- [humanoid] = { Entries = { { Speed, Until }, ... } }

local function slowCap(rec, now)
	local cap
	for _, entry in ipairs(rec.Entries) do
		if entry.Until > now and (cap == nil or entry.Speed < cap) then cap = entry.Speed end
	end
	return cap
end

local function rooted(rec, now)
	for _, entry in ipairs(rec.Entries) do
		if entry.Until > now and entry.Speed <= 0 then return true end
	end
	return false
end

-- `source` (optional) names who asked, so that one source's slows can be ended early (endSlows, below)
local function applySlow(humanoid, walkSpeed, duration, statusName, source)
	applyStatusTag(humanoid, statusName or "Chilled", duration)
	local character = humanoid.Parent
	local rec = slowed[humanoid]
	if not rec then
		rec = { Entries = {} }
		slowed[humanoid] = rec
	end
	local now = os.clock()
	local entry = { Speed = walkSpeed, Until = now + duration, Source = source }
	table.insert(rec.Entries, entry)
	if character then
		character:SetAttribute("SpeedCapSlow", slowCap(rec, now))
	end
	humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, walkSpeed)
	if walkSpeed <= 0 then setJumpLock(humanoid, "Root", true) end
	task.delay(duration, function()
		if slowed[humanoid] ~= rec then return end
		-- this entry is over (it goes by identity: the timer can wake a hair before Until), and so
		-- is any other whose time has also run out
		local t = os.clock()
		for i = #rec.Entries, 1, -1 do
			local e = rec.Entries[i]
			if e == entry or e.Until <= t then table.remove(rec.Entries, i) end
		end
		if #rec.Entries == 0 then
			slowed[humanoid] = nil
			if humanoid.Parent then
				humanoid.Parent:SetAttribute("SpeedCapSlow", nil)   -- SpellshotService restores the speed
				setJumpLock(humanoid, "Root", false)
			end
		elseif humanoid.Parent then
			humanoid.Parent:SetAttribute("SpeedCapSlow", slowCap(rec, t))
			setJumpLock(humanoid, "Root", rooted(rec, t))
		end
	end)
	return entry       -- (2026-10-19, audit P3-04) so a caller can tell later whether its own slow was ended early
end

-- Ends every slow one source asked for, before its time (2026-09-24). The shard root is the case: Chill's stacks reset
-- to 0 at the root, so the slows those stacks applied end with them. Before this, stack 2's slow ran on after the root
-- (a 15 cap for ~3.6 s in preset A) while the status already read "not chilled".
local function endSlows(humanoid, source)
	local rec = slowed[humanoid]
	if not rec then return end
	for i = #rec.Entries, 1, -1 do
		-- `source` may also be a test on the entry (2026-10-17: a reaction breaking every root, whoever applied it)
		local e = rec.Entries[i]
		if (type(source) == "function" and source(e)) or e.Source == source then
			e.Ended = true          -- (2026-10-19, audit P3-04) ended early (a broken root), not run out
			table.remove(rec.Entries, i)
		end
	end
	local character = humanoid.Parent
	if #rec.Entries == 0 then
		slowed[humanoid] = nil
		if character then
			character:SetAttribute("SpeedCapSlow", nil)
			setJumpLock(humanoid, "Root", false)
		end
	elseif character then
		local t = os.clock()
		character:SetAttribute("SpeedCapSlow", slowCap(rec, t))
		setJumpLock(humanoid, "Root", rooted(rec, t))
	end
end

----------------------------------------------------------------------------------------------------
-- PRIMARY ABILITY: FLASH FREEZE
----------------------------------------------------------------------------------------------------
-- The manual's wording is the spec: "anyone who lingers past 1s is rooted, then shattered for
-- heavy damage if still frozen when it ends". So the zone tracks TIME INSIDE per victim rather
-- than hitting once on contact -- walking through it costs almost nothing, standing in it costs
-- the round. Dwell deliberately never decays: leaving and re-entering still gets you rooted, so
-- the timer cannot be juked by strafing in and out of the edge.

--- (2026-10-19, audit P1-09) LINE OF SIGHT for a spot aimed with the crosshair. The honest client can only pick a spot its
--- camera sees, so the server asks the same of its own copy of the world: from the caster's eye to the spot -- or to a
--- point a few studs over it, so low cover in front of the spot does not hide it -- nothing solid may stand in between.
--- Bodies never count; a Bulwark Wall does (Core.Blocked's rule). Returns the spot when it is in sight, else the point
--- just short of the first thing in the way on the line to the highest of them, for the caller to ground again.
local SIGHT_RISES = { 0.5, 3, 5 }
local function sightPoint(character, root, spot)
	local head = character:FindFirstChild("Head")
	local eye = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local list = { character }
	local fx = fxFolder()
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
	return stop
end

--- CURSOR TARGETING (P29, 2026-10-18; the owner shipped Flash Freeze and Blizzard at 20 studs): where a zone aimed with
--- the crosshair lands -- the aim point the client sent (its row is Targeted) pulled in to `range` from the caster, then
--- the floor under it (VFXLibrary.GroundBelow: through bodies, at most 40 below the aim). nil keeps the zone where the
--- caster stands, as before: a range of 0 (the old self-centred cast), no aim sent, or no floor under it (the sky, a drop).
local function cursorFloor(character, root, payload, range)
	if not range or range <= 0 or not (payload and validVector(payload.Target)) then return nil end
	local aim = clampTarget(root, payload.Target, range)
	local floor, _, hit = VFXLibrary.GroundBelow(aim, { character, fxFolder() }, 46)
	if not hit then return nil end
	-- (2026-10-19, audit P1-09) a floor out of the caster's sight (through a wall, the storey above or below) is grounded
	-- again from where the sight line stops: GroundBelow casts from 6 over the point it is given, so this casts from there
	local seen = sightPoint(character, root, floor)
	if seen ~= floor then
		floor, _, hit = VFXLibrary.GroundBelow(seen - Vector3.new(0, 6, 0), { character, fxFolder() }, 46)
	end
	return hit and floor or nil
end

local function castFlashFreeze(player, character, humanoid, root, payload)
	local seed = math.random(1, 2 ^ 30)
	local F = T.FlashFreeze
	-- cursor-targeted since 2026-10-18 (F.CastRange; 0 puts it back round the caster's feet)
	local center = cursorFloor(character, root, payload, F.CastRange)
		or VFXLibrary.FlashFreezeCentre(root.Position, { character, fxFolder() })
	-- The centre the server hurts by, and the server time it was cast at, the way Frost Slide and the beam send
	-- theirs. The message used to carry the caster's live root part and nothing else, so every client probed its own
	-- centre whenever the message arrived and started its own clock (2026-09-21): a zone cast at a sprint drew
	-- several studs from where it freezes people, a network trip behind. OriginPart rides along until AbilityFX and
	-- VFXLibrary read Center/T0.
	broadcast("FlashFreeze", {
		OriginPart = root, Center = center, T0 = workspace:GetServerTimeNow(), Seed = seed, Caster = character,
	})

	local t0 = os.clock() + F.LeadIn        -- the front leaves the hand on the slam, not the keypress
	local zoneEnd = t0 + F.ExpandTime + F.RimLinger

	local dwell = {}      -- [humanoid] = seconds spent inside
	local rooted = {}     -- [humanoid] = this zone's root entry (applySlow's) once the root has landed
	local contacted = {}
	local epoch = Core.Epoch(player)
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		-- the caster left the arena, or a duel round was reset (CombatCore.ClearPlayer): the zone stops and shatters nobody
		if Core.Epoch(player) ~= epoch then
			conn:Disconnect()
			return
		end
		local now = os.clock()
		if now < t0 then return end
		if now > zoneEnd then
			conn:Disconnect()
			-- the shatter is drawn only where it actually landed: a victim who left the arena between the root and the
			-- zone's end is refused by DealDamage, and used to burst into the loudest VFX in the kit anyway,
			-- standing in the Hub, for no damage (2026-09-21)
			-- (2026-10-19, audit P3-04) "shattered if STILL frozen when it ends": not a victim whose root a reaction broke
			-- (Melt / Shatter already paid for it: endSlows marks the entry Ended), nor one moved out of the zone since (a
			-- Position Trade) -- the root holds a body where it stood, so anything past the rim plus a body's reach moved
			for victim, entry in pairs(rooted) do
				local vroot = victim.Parent and victim.Parent:FindFirstChild("HumanoidRootPart")
				if victim.Parent and victim.Health > 0 and not entry.Ended
					and vroot and (vroot.Position - center).Magnitude <= F.Radius + 6 then
					-- a shatter refused (the victim has gone to the Hub, or out of the duel) shows nothing on them either
					if dealDamage(player, victim, Tune.FlashFreezeShatterDamage) then
						broadcast("FlashFreezeShatter", { Character = victim.Parent, Caster = character })
					end
				end
			end
			return
		end

		local elapsed = now - t0
		local radius = (elapsed < F.ExpandTime) and VFXLibrary.FlashFreezeRadiusAt(elapsed) or F.Radius
		for victim in pairs(humanoidsNear(center, radius, character)) do
			if not isFriendly(player, victim.Parent) then
				-- a wall in the zone takes the contact damage and nothing else (isWall, above). It cannot walk out, so
				-- it reached the root every single time, and the shatter that follows a root with it
				local wall = isWall(victim.Parent)
				if not contacted[victim] then
					contacted[victim] = true
					dealDamage(player, victim, Tune.FlashFreezeContactDamage)
					if not wall then applySlow(victim, Tune.FlashFreezeSlowSpeed, 1.2, "Chilled") end
				end
				dwell[victim] = (dwell[victim] or 0) + dt
				if not wall and dwell[victim] >= F.LingerToRoot and not rooted[victim] then
					local remaining = math.max(0.5, zoneEnd - now)
					rooted[victim] = applySlow(victim, 0, remaining, "Rooted")
					VFXLibrary.ApplyFrozenState(victim.Parent, remaining)
					-- Caster: whose freeze it is, for their skin (Frostblade's pierce)
					broadcast("FlashFreezeRoot", { Character = victim.Parent, Caster = character })
				end
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- MOBILITY: FROST SLIDE
----------------------------------------------------------------------------------------------------
-- "The caster dashes; a medium-radius patch of ground behind them freezes over. Anyone who steps on
-- that frozen patch freezes on contact -- no slip, no slow, just a clean freeze." Three charges, each
-- a dash (the charges and their mana are SpellshotService's).
--
-- The DASH is the client's: it has network ownership of its own character, so it moves itself
-- (DashMotor) the moment the key goes down and tells this script where it started, which way and how
-- far. Nothing here moves anybody. What this script owns is the PATCH: it lands on the ground under
-- where the dash began -- checked against where the server has the caster, with the same allowance
-- for a moving player that ShardRelease uses -- and every client draws it from the same centre and
-- the same server-time T0, so the ice you see forming is the ice that freezes you.
--
-- CONTACT. The patch grows over PatchForm along FrostSlidePatchRadiusAt, the curve the drawn sheet
-- follows, and anyone whose feet are on it -- inside that radius (plus a little reach for a boot
-- on the rim) and at about the patch's height, so a jump over it or a floor above it does not count
-- -- is frozen for FrozenDuration. A patch freezes each victim once; FreezeImmunity after the thaw
-- keeps two patches laid side by side from chaining one freeze into the next. No damage: the freeze
-- is the whole payoff, and it counts as a landed hit for Cold Momentum.
local patches = {}   -- { Center, Normal, T0, Expires, Owner, Frozen = { [humanoid] = true } }
local patchImmune = setmetatable({}, { __mode = "k" })   -- [humanoid] = os.clock() it can be frozen again

local function castFrostSlide(player, character, humanoid, root, payload)
	local S = T.FrostSlide
	payload = payload or {}

	-- Where the dash began, as the client saw it. The server's copy of a moving player trails the real
	-- one, and a dash is the fastest thing a player does, so the allowance is the ShardRelease one
	-- at no less than full dash speed (DashDistance / DashTime, 65 studs/s). A claim outside it -- or
	-- none, as from the dev panel -- starts the dash where the server has the caster now.
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	local speed = Core.TrailSpeed(root, S.DashDistance / S.DashTime)
	local allowance = 6 + speed * (0.35 + Core.Lag(ping))
	local start = payload.Start
	if not (validVector(start) and (start - root.Position).Magnitude <= allowance) then
		start = root.Position
	end
	local dir = validVector(payload.Dir) and Vector3.new(payload.Dir.X, 0, payload.Dir.Z) or Vector3.zero
	if dir.Magnitude > 1e-3 then
		dir = dir.Unit
	else
		dir = VFXLibrary.Flat(root.CFrame.LookVector)
	end
	local dist = payload.Dist
	if type(dist) == "number" and dist == dist then
		dist = math.clamp(dist, 0, S.DashDistance)
	else
		dist = S.DashDistance
	end

	-- the patch sits on the ground under the start; dashing off with nothing underfoot (an air dash
	-- high over a drop) lays no patch and freezes nobody
	local exclude = { character }
	local fx = fxFolder()
	if fx then exclude[#exclude + 1] = fx end
	-- GroundBelow casts from 6 above the point it is given, so the probe starts just above the body and still reaches
	-- 12 studs under the dash start: a dash from the top of a jump lays its patch. It used to be handed the root
	-- itself, which put the ray origin some 9 studs over the feet (2026-09-21): dash under a doorway lintel or a
	-- walkway and the first thing below the origin was the TOP of that overhang, so the patch -- and everyone's
	-- drawing of it -- formed on the roof, freezing whoever stood up there and nobody on the floor.
	local center, normal, ground = VFXLibrary.GroundBelow(start - Vector3.new(0, 5.5, 0), exclude, 12.5)
	local hasPatch = ground ~= nil

	local seed = math.random(1, 2 ^ 30)
	broadcast("FrostSlide", {
		Character = character, Start = center, Normal = normal, Dir = dir, Dist = dist, Seed = seed,
		T0 = workspace:GetServerTimeNow(), Patch = hasPatch,
	})
	if not hasPatch then return end

	local t0 = os.clock()
	table.insert(patches, {
		Center = center, Normal = normal, T0 = t0, Expires = t0 + S.PatchLife, Owner = player,
		Frozen = setmetatable({}, { __mode = "k" }),
	})
end

-- One shared loop for every live patch, every frame: a dash is fast and a patch is small, so a
-- throttled check could let someone sprint across the rim between two ticks.
RunService.Heartbeat:Connect(function()
	if #patches == 0 then return end
	local now = os.clock()
	local S = T.FrostSlide
	for i = #patches, 1, -1 do
		local patch = patches[i]
		if now >= patch.Expires then
			table.remove(patches, i)
		else
			local owner = patch.Owner
			local reach = VFXLibrary.FrostSlidePatchRadiusAt(now - patch.T0) + S.ContactReach
			-- broad phase: a generous sphere a little above the ice, so bodies standing on it are inside
			local near = humanoidsNear(patch.Center + Vector3.new(0, 2.5, 0), S.PatchRadius + 3, owner.Character)
			for victim, model in pairs(near) do
				local vroot = model:FindFirstChild("HumanoidRootPart")
				if vroot and not patch.Frozen[victim] and now >= (patchImmune[victim] or 0)
					and not isFriendly(owner, model) then
					-- narrow phase: feet on the patch, not merely near it
					local offset = vroot.Position - patch.Center
					local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
					local feetY = vroot.Position.Y - vroot.Size.Y / 2 - victim.HipHeight
					local dy = feetY - patch.Center.Y
					if flatDistance <= reach and dy >= -S.ContactBelow and dy <= S.ContactAbove then
						patchImmune[victim] = now + S.FrozenDuration + S.FreezeImmunity
						patch.Frozen[victim] = true
						applySlow(victim, 0, S.FrozenDuration, "Rooted")
						VFXLibrary.ApplyFrozenState(model, S.FrozenDuration)
						broadcast("FlashFreezeRoot", { Character = model })
						onHitLanded(owner)
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- DEFENSE: CHILL AURA
----------------------------------------------------------------------------------------------------
local auras = {}   -- [player] = { Character, Root, Humanoid, Expires, Dwell, LastTick }

local function castChillAura(player, character, humanoid, root)
	local A = T.ChillAura
	-- T0 is the server time of the cast: every client opens the ring LeadIn after it and collapses it
	-- when this aura ends, however late the broadcast reaches them
	broadcast("ChillAura", { Character = character, Duration = A.Duration, T0 = workspace:GetServerTimeNow() })
	auras[player] = {
		Character = character, Root = root, Humanoid = humanoid, Expires = os.clock() + A.Duration,
		Dwell = {}, LastTick = os.clock(),
	}
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local A = T.ChillAura
	for player, aura in pairs(auras) do
		if now > aura.Expires or not aura.Root:IsDescendantOf(workspace) then   -- a leaver's model is only unparented
			auras[player] = nil
		elseif aura.Humanoid.Health <= 0 then
			-- the aura dies with its caster, and every client collapses the ring
			auras[player] = nil
			broadcast("ChillAuraStop", { Character = aura.Character })
		elseif now - aura.LastTick >= A.TickRate then
			local step = now - aura.LastTick
			aura.LastTick = now
			local inside = humanoidsNear(aura.Root.Position, A.Radius, aura.Character)
			-- the root comes after CONTINUOUS exposure: whoever is not inside on a tick starts again from 0
			for victim in pairs(aura.Dwell) do
				if not inside[victim] then aura.Dwell[victim] = nil end
			end
			for victim in pairs(inside) do
				if not isFriendly(player, victim.Parent) then
					dealDamage(player, victim, Tune.AuraDamagePerTick)
					-- a wall standing in the aura is chipped by it and left alone otherwise (isWall, above)
					if not isWall(victim.Parent) then
						aura.Dwell[victim] = (aura.Dwell[victim] or 0) + step
						if aura.Dwell[victim] >= Tune.AuraFreezeAfter then
							-- stayed in melee range too long: the aura stops slowing and starts rooting
							applySlow(victim, 0, 1.2, "Rooted")
							VFXLibrary.ApplyFrozenState(victim.Parent, 1.2)
							aura.Dwell[victim] = 0
						else
							applySlow(victim, Tune.AuraSlowSpeed, Tune.AuraSlowDuration, "Chilled")
						end
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- ULTIMATE: CRYO BEAM
----------------------------------------------------------------------------------------------------
-- Three beats, and the first two are entirely telegraph: the caster leaves the ground and a cast
-- circle spins under them for the whole windup. That is what pays for the damage on the far
-- side -- an opponent who reads it has well over a second to break line of sight.
local ultimates = {}   -- [player] = state

local function endUltimate(player, silent)
	local u = ultimates[player]
	if not u then return end
	ultimates[player] = nil
	if u.Conn then u.Conn:Disconnect() end
	if u.Align then u.Align:Destroy() end
	if u.Orient then u.Orient:Destroy() end
	if u.A0 then u.A0:Destroy() end
	if u.Anchor then u.Anchor:Destroy() end
	if u.Humanoid and u.Humanoid.Parent then
		u.Humanoid.PlatformStand = false
		-- clearing the cap hands speed back to SpellshotService, which applies whatever stance you
		-- are in now (this used to set walking pace, 16, even with W held)
		u.Humanoid.Parent:SetAttribute("SpeedCapUlt", nil)
		setJumpLock(u.Humanoid, "CryoBeam", false)          -- a root still running keeps jumping off
	end
	if not silent then
		broadcast("CryoBeamStop", { Character = u.Character })
	end
end

local function castCryoBeam(player, character, humanoid, root, payload)
	endUltimate(player, true)
	local U = T.CryoBeam
	local ability = VFXLibrary.AbilityById.CryoBeam
	local target = clampTarget(root, payload.Target, ability.Range)

	-- Lift: an AlignPosition against a world anchor, so the character genuinely floats and still
	-- collides. Anchoring the root instead would take network ownership away from the client and
	-- freeze its camera along with it.
	local anchor = Instance.new("Part")
	anchor.Name = "CryoLiftAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(root.Position + Vector3.new(0, U.LevitateHeight, 0))
	anchor.Parent = fxFolder() or workspace

	local a0 = Instance.new("Attachment")
	a0.Name = "CryoLiftAttachment"
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor

	local align = Instance.new("AlignPosition")
	align.Attachment0 = a0
	align.Attachment1 = a1
	align.MaxForce = 1e6
	align.Responsiveness = 22
	align.Parent = root

	-- Hold the caster upright. The obvious way to lift someone is PlatformStand, but that turns
	-- the humanoid's balance off: the character flops over and, because the first-person camera
	-- is parented to the humanoid, the caster's view tumbles with it -- you spend your Ultimate
	-- looking at the sky. An AlignOrientation keeps the rig level and the camera pointing where
	-- the player aimed it.
	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = a0
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.CFrame = CFrame.new(Vector3.zero, Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
	orient.MaxTorque = 1e6
	orient.Responsiveness = 30
	orient.Parent = root

	character:SetAttribute("SpeedCapUlt", 0)
	humanoid.WalkSpeed = 0
	setJumpLock(humanoid, "CryoBeam", true)

	local u = {
		Character = character, Humanoid = humanoid, Root = root, Anchor = anchor,
		Align = align, Orient = orient, A0 = a0, Target = target, Phase = "Lift",
		Start = os.clock(), LastTick = 0, T0 = workspace:GetServerTimeNow(),
	}
	ultimates[player] = u

	-- T0: the server time of the cast, so every client's windup and beam run on one clock (a late message catches up)
	broadcast("CryoBeamWindup", {
		Character = character,
		ChargeTime = U.LevitateTime + U.ChargeTime,
		T0 = u.T0,
	})

	local fireAt = u.Start + U.LevitateTime + U.ChargeTime
	local endAt = fireAt + U.FireTime

	u.Conn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if not (character.Parent and humanoid.Health > 0) then
			endUltimate(player)
			return
		end
		if now >= endAt then
			endUltimate(player)
			return
		end
		if now < fireAt then return end

		if u.Phase ~= "Fire" then
			u.Phase = "Fire"
			broadcast("CryoBeamFire", { Character = character, Target = u.Target, T0 = u.T0 })
		end
		if now - u.LastTick < Tune.BeamTickRate then return end
		u.LastTick = now

		-- The beam is re-raycast server side every tick: what a client draws never decides
		-- damage (manual, Section 12 -- server-authoritative hit detection).
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
		local from = hand.Position
		local dir = u.Target - from
		if dir.Magnitude < 0.5 then dir = root.CFrame.LookVector end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		-- through anyone this beam may not hurt (isFriendly): a body that cannot take the hit is not cover either
		local skip = { character, fxFolder() }
		for _, other in ipairs(Players:GetPlayers()) do
			local c = other.Character
			if c and c ~= character and isFriendly(player, c) then skip[#skip + 1] = c end
		end
		params.FilterDescendantsInstances = skip
		params.RespectCanCollide = true
		local hit = workspace:Raycast(from, dir.Unit * ability.Range, params)
		local hitPos = hit and hit.Position or (from + dir.Unit * ability.Range)
		for victim, model in pairs(humanoidsNear(hitPos, Tune.BeamHitRadius, character)) do
			if dealDamage(player, victim, Tune.BeamDamagePerSecond * Tune.BeamTickRate, { Ranged = true, From = from })
				and not isWall(model) then     -- the beam wears a wall down; it does not chill or frost it (isWall, above)
				applySlow(victim, Tune.BeamSlowSpeed, Tune.BeamSlowTime, "Chilled")
				if not model:FindFirstChild("IceFrozenState") then
					VFXLibrary.ApplyFrozenState(model, Tune.BeamSlowTime + 0.3)
				end
			end
		end
	end)
end

-- The Ultimate keeps aiming while it fires, so the client streams its aim point.
local lastAim = {}
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "UltAim" then return end
	local u = ultimates[player]
	if not u then return end
	local now = os.clock()
	if now - (lastAim[player] or 0) < 1 / 30 then return end     -- cheap per-player rate limit
	lastAim[player] = now
	if not validVector(a) then return end
	u.Target = clampTarget(u.Root, a, VFXLibrary.AbilityById.CryoBeam.Range)
	broadcast("CryoBeamAim", { Character = u.Character, Target = u.Target })
end)

----------------------------------------------------------------------------------------------------
-- Icicle Shard (M1)
----------------------------------------------------------------------------------------------------
-- The click relays the thrust so every client can play it and fly a rod from that hand. The HIT is
-- decided separately, from the release (below).
local function castIcicleShard(player, character, humanoid, root, payload)
	payload = payload or {}
	local range = VFXLibrary.AbilityById.IcicleShard.Range
	local target = validVector(payload.Target) and clampTarget(root, payload.Target, range)
		or (root.Position + root.CFrame.LookVector * range)
	broadcast("IcicleShard", { Character = character, Target = target, Side = (payload.Side == "L") and "L" or "R" })
end

-- The hit. When the thrust releases the shard, the shooter's client sends the shot's true line -- from
-- the eye straight down the crosshair, the line its own rod follows ("ShardRelease") -- and then, when
-- that rod stops on something, what it stopped on ("ShardHit"). The claim is checked against the
-- line and against where the server has had things, then applied here: damage, Chill, and an
-- announcement on ServerStorage.ShotImpact, which the training boards listen to.
local shotImpact = Core.ShotImpact

-- CHILL. Each shard hit adds a stack and slows a little harder. The third is the deepest slow (2026-10-08: it used to
-- root, "too strong for a basic attack"): it holds one Window, further hits adding nothing, then the stacks clear and
-- Stack3Immunity follows, so a perfect tapper cannot keep a target in it. It never makes IceFrozenState: FROZEN! is
-- reserved for real freezes (Flash Freeze, Deep Freeze, Mirror Cage). Stacks lapse Window after the last hit. The count is published as RX_Chilled / RX_Chilled_Stacks, which is what the
-- victim's own HUD reads for its frost crust (one stage per stack).
local chill = setmetatable({}, { __mode = "k" })   -- [humanoid] = { Stacks, Token, ImmuneUntil }

local function publishChill(model, stacks, caster)
	if not model.Parent then return end
	model:SetAttribute("RX_Chilled_Element", "Cryo")
	-- the CASTER's skin rides the status (the victim's bar wears it: BarFX / SkinCatalog.HudBar). Written as a stack
	-- lands, left in place as it clears, so the look's own exit (the shatter) still plays in the caster's skin.
	if stacks > 0 then
		local hs = caster and SkinCatalog.HudSkin(caster, "Cryo") or "Default"
		model:SetAttribute("RX_Chilled_Skin", hs ~= "Default" and hs or nil)
	end
	model:SetAttribute("RX_Chilled_Stacks", stacks > 0 and stacks or nil)
	model:SetAttribute("RX_Chilled", stacks > 0)
	-- every client draws the stacks as a frost crust climbing the victim (CryoFX, 2026-09-24): a broadcast rather than
	-- attribute watchers, because a range dummy is a model no client would otherwise know to watch
	-- Caster: the shooter's body, so a Cryo wrap draws the chill in the SHOOTER's colours (CryoWrap)
	local cc = (typeof(caster) == "Instance" and caster:IsA("Player")) and caster.Character or caster
	broadcast("ChillStacks", { Character = model, Stacks = stacks, Caster = cc })
end

local function chillFromShard(humanoid, model, caster)
	if isWall(model) then return end     -- a shard chips a wall; it does not stack Chill on it (isWall, above)
	-- the live status preset (StatusEffects, 2026-09-24): the window, the slow per stack (preset B: only the last), the
	-- last stack's deep slow and the immunity after it
	local CT = Status.Tune("Chilled")
	local now = os.clock()
	local c = chill[humanoid]
	if not c then
		c = { Stacks = 0, Token = 0, ImmuneUntil = 0 }
		chill[humanoid] = c
	end
	if now < c.ImmuneUntil then return end
	c.Stacks += 1
	c.Token += 1
	local token = c.Token
	if c.Stacks >= CT.MaxStacks then
		-- the deep slow: held one Window (hits in it add nothing), then cleared, then Stack3Immunity
		c.Stacks = 0
		c.ImmuneUntil = now + CT.Window + (CT.Stack3Immunity or 0)
		publishChill(model, CT.MaxStacks, caster)
		Status.Stamp(model, "Chilled", CT.Window)
		endSlows(humanoid, "Shard")                  -- the lighter caps give way to the deepest
		local deep = CT.SlowCaps[CT.MaxStacks]
		if deep then applySlow(humanoid, deep, CT.Window, "Chilled", "Shard") end
		task.delay(CT.Window, function()
			if c.Token == token then
				publishChill(model, 0)
				Status.Stamp(model, "Chilled", 0)
			end
		end)
		return
	end
	publishChill(model, c.Stacks, caster)
	Status.Stamp(model, "Chilled", CT.Window)
	local cap = CT.SlowCaps[c.Stacks]
	if cap then applySlow(humanoid, cap, CT.Window, "Chilled", "Shard") end
	task.delay(CT.Window, function()
		if c.Token == token then
			c.Stacks = 0
			publishChill(model, 0)
			Status.Stamp(model, "Chilled", 0)
		end
	end)
end

-- EVERY OUTCOME OF A SHOT, COUNTED, where the server has had things, and whether something solid is in the
-- way: all shared with the Fireball's checks now, so they live in CombatCore (the outcome names are
-- listed there).
local count = Core.CountShot
local wasThere = Core.WasThere
local blocked = Core.Blocked

local shots = {}                -- [player] = { [id] = { Origin, Dir, At, Life, Character } }, awaiting their hit
local buckets = {}              -- [player] = { Tokens, At }: the fire-rate check

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "ShardRelease" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end   -- no M1 in the Hub (HubServer)
	-- only a player whose M1 IS Icicle Shard (a Pyro's Fireball reports to PyroHandler)
	if VFXLibrary.AbilityFor(player, "M1") ~= VFXLibrary.AbilityById.IcicleShard then return end
	-- CanAct, not aliveCharacter: Tremor Vault was a shared Mobility Technique (retired since; 2026-10-19, audit P4-14),
	-- so a burrowed CRYO player was firing shards for full damage out of a hidden, untouchable body (2026-09-21). Any
	-- burrow, cast lock or interrupt still refuses the shot. The performCast dispatcher below keeps
	-- plain aliveCharacter -- a held ability started before the burrow still has to be able to END down there.
	local character, humanoid, root = Core.CanAct(player)
	if not character then return end
	local origin, target, id = a.Origin, a.Target, a.Id
	-- id ~= id refuses a NaN Id (2026-10-19, audit P1-11): the write below raised "table index is NaN" (TerraHandler's fix)
	if not (validVector(origin) and validVector(target)) or type(id) ~= "number" or id ~= id then return end
	local ability = VFXLibrary.AbilityById.IcicleShard
	local now = os.clock()
	-- One shot per FireInterval on average. The bucket holds a shot and a half, so network jitter that
	-- bunches two releases together cannot throw one away (the gap already measured 0.32 s against a
	-- 0.33 s interval in Studio, where the old 0.8x limit left 50 ms), while the long-run rate still caps.
	local b = buckets[player]
	if not b then
		b = { Tokens = 1.5, At = now }
		buckets[player] = b
	end
	-- The SAME interval the client fires at: it divides FireInterval by ShotTimeScale, and a bucket
	-- refilling at the unscaled rate simply loses shots whenever the shot is slowed down for filming.
	local interval = (ability.FireInterval or 0.25) / VFXLibrary.ShotTimeScale()
	b.Tokens = math.min(2, b.Tokens + (now - b.At) / interval)
	b.At = now
	if b.Tokens < 1 then
		count("rej_rate")
		return
	end
	b.Tokens -= 1
	-- The eye has to be the shooter's own: near their head -- allowing for the server's copy of a moving
	-- player trailing the real one by about 0.2 s in Studio (measured: 6.9 studs behind at sprint speed,
	-- 10.8 at a slide-jump) and more over a real network. A flat 6 studs threw away every shot fired
	-- while sprinting or sliding.
	local head = character:FindFirstChild("Head")
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	-- The speed is what the server sees or what the player may walk at, whichever is more: from a
	-- standstill the server still reads 0 for the first ~0.2 s while the player is already moving.
	local speed = Core.TrailSpeed(root, humanoid.WalkSpeed)
	local allowance = 6 + speed * (0.35 + Core.Lag(ping))
	if (origin - (head and head.Position or root.Position)).Magnitude > allowance then
		count("rej_origin")
		return
	end
	local dir = target - origin
	if dir.Magnitude < 0.1 then return end
	local mine = shots[player]
	if not mine then
		mine = {}
		shots[player] = mine
	end
	for oldId, shot in pairs(mine) do
		if now - shot.At > shot.Life then mine[oldId] = nil end
	end
	mine[id] = {
		Origin = origin, Dir = dir.Unit, At = now, Character = character,
		Life = ability.Range / (T.IcicleShard.Speed * VFXLibrary.ShotTimeScale()) + 1.5,
	}
	count("release")
end)

-- What the shooter's rod stopped on. Checked, then applied.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "ShardHit" or type(a) ~= "table" then return end
	local mine = shots[player]
	local shot = mine and type(a.Id) == "number" and mine[a.Id]
	if not shot then
		count("rej_noshot")
		return
	end
	mine[a.Id] = nil                                   -- one hit per shot
	local now = os.clock()
	if now - shot.At > shot.Life then
		count("rej_late")
		return
	end
	local part, position = a.Part, a.Position
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
		or not validVector(position) then
		count("rej_badpart")
		return
	end
	local ability = VFXLibrary.AbilityById.IcicleShard
	-- on the shot's own line, inside its range...
	local rel = position - shot.Origin
	local along = rel:Dot(shot.Dir)
	-- 1.5 studs off the axis, not 1: the rod has thickness, and the point reported is where its
	-- cast stopped, so a hit on the lip of a surface sits a fraction off the line.
	if along < 0 or along > ability.Range + 1 or (rel - shot.Dir * along).Magnitude > 1.5 then
		count("rej_offline")
		return
	end
	-- ...and no sooner than the shard could have flown there (the report travels the same road as the
	-- release, so the network cancels out; the slack is for jitter)
	local flight = along / (T.IcicleShard.Speed * VFXLibrary.ShotTimeScale())
	if now - shot.At < flight - 0.25 then
		count("rej_early")
		return
	end
	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if model and model == shot.Character then
		count("rej_self")
		return
	end
	if humanoid then
		-- a character moves: the point has to be on it somewhere it has stood in the last second
		if not wasThere(model, position) then
			count("rej_moved")
			return
		end
	else
		-- anything else holds still: the point has to be on the part
		local lp = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2 + Vector3.new(0.5, 0.5, 0.5)
		if math.abs(lp.X) > half.X or math.abs(lp.Y) > half.Y or math.abs(lp.Z) > half.Z then
			count("rej_offpart")
			return
		end
	end
	if blocked(shot, along, humanoid and model or part) then
		count("rej_blocked")
		return
	end
	-- a body is only hurt by a PAID shot (2026-10-19, audit P1-12 / GC-14: the M1 CastRequest could be skipped)
	if humanoid and not Core.TakePaidM1(player) then
		count("rej_unpaid")
		return
	end
	count("hit")
	count(humanoid and "hit_char" or "hit_world")      -- the Wind Blade's split: a wall is not a body
	if humanoid and dealDamage(player, humanoid, Tune.ShardDamage, { Ranged = true, From = shot.Origin }) then
		chillFromShard(humanoid, model, player)
	end
	shotImpact:Fire(part, position, player)
end)

Players.PlayerRemoving:Connect(function(player)
	shots[player] = nil
	buckets[player] = nil
end)

----------------------------------------------------------------------------------------------------
-- THE REBUILT TECHNIQUES AND ULTIMATE (2026-09-24): BLIZZARD, DEEP FREEZE, MIRROR CAGE
----------------------------------------------------------------------------------------------------
-- The owner: "implement them in the game" -- Blizzard takes Frost Slide's place (the Mobility half of the pool),
-- Deep Freeze Chill Aura's (the Defense half), Mirror Cage Cryo Beam's (Cryo's Ultimate). Their numbers are
-- CryoTuning's, the one table the client draws from too. They live here, not in a script of their own, because the
-- slows, the roots and Cold Momentum are this script's (applySlow's records must have ONE writer, or two scripts
-- publishing SpeedCapSlow would overwrite each other's caps). Frost Slide, Chill Aura and Cryo Beam keep their code
-- above, but nothing can cast them: their rows and pool entries are gone, and so are their entries in `casts`.

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

--- Where a body's feet are, the way Frost Slide's patch measured them.
local function feetOf(model, humanoid)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local legs = humanoid and (humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight) or 2
	return root, root.Position.Y - root.Size.Y / 2 - legs
end

--- The Deep Freeze placement goes to the caster alone (an unseen trap must not reach anyone else's client, where an
--- exploiter could read it): AbilityFX's dispatcher takes a FireClient exactly as it takes a broadcast.
local function tellOwner(player, kind, data)
	pcall(function() remote:FireClient(player, "VFX", kind, data) end)
end

--- A body that is rooted right now: its slow records hold a 0.
local function isRooted(humanoid)
	local rec = slowed[humanoid]
	return rec ~= nil and rooted(rec, os.clock())
end

-- ELEMENTAL REACTIONS (2026-10-17): Cryo's levers for ServerScriptService.ElementalReactions. Melt and Frozen consume Chill,
-- Shatter and Melt break a root, Frozen roots, Windchill adds a stack. Chill and the roots stay this script's; the
-- reactions only ask.
Core.Hooks.IsRooted = isRooted
--- Chill consumed: the stacks and the shard slows they applied go, and the count comes off (a deep slow's immunity stays).
Core.Hooks.ClearChill = function(humanoid)
	local c = chill[humanoid]
	if c then
		c.Token += 1
		c.Stacks = 0
	end
	endSlows(humanoid, "Shard")
	local model = humanoid.Parent
	if model then
		publishChill(model, 0)
		Status.Stamp(model, "Chilled", 0)
	end
end
--- `n` more Chill stacks, exactly as `n` more shards would land them (the deep slow, its window and its immunity included).
Core.Hooks.AddChill = function(caster, humanoid, n)
	local model = humanoid.Parent
	if not model then return end
	for _ = 1, n or 1 do chillFromShard(humanoid, model, caster) end
end
--- Every root on the body ends now (any slow to 0, whoever applied it), and its ice with it.
Core.Hooks.BreakRoot = function(humanoid)
	endSlows(humanoid, function(e) return e.Speed <= 0 end)
	local model = humanoid.Parent
	if not model then return end
	local frozen = model:FindFirstChild("IceFrozenState")
	if frozen then frozen:Destroy() end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child.Name == "FrozenEmitterAttachment" then child:Destroy() end
		end
	end
	if model:GetAttribute("Status") == "Rooted" then
		model:SetAttribute("Status", "")
		model:SetAttribute("StatusExpires", 0)
	end
end
--- A root of `seconds` in Flash Freeze's look (the ice state), tagged ROOTED.
Core.Hooks.Root = function(humanoid, seconds)
	local model = humanoid.Parent
	if not model or isWall(model) then return end
	applySlow(humanoid, 0, seconds, "Rooted", "Reaction")
	VFXLibrary.ApplyFrozenState(model, seconds)
end

------------------------------------------------------------------------------------------ BLIZZARD
-- A storm dropped where the caster stands, Radius wide and Duration long. Everyone inside who may be hurt -- not the
-- caster, not whoever they may not hurt, not a Bulwark Wall -- is slowed to SlowCap, re-applied every Tick for
-- SlowHold so walking out ends it within half a second (Chill Aura's cadence). The whiteout is drawn by the victim's
-- own client (CryoFX), from the broadcast. A body that is rooted is left alone: the slow would re-tag it "Chilled"
-- over its ROOTED status every tick. One storm per caster; a new one replaces the old.
local storms = {}          -- [player] = { Character, Center, Ends, Epoch, NextTick }

local function endStorm(player, early)
	local s = storms[player]
	if not s then return end
	storms[player] = nil
	if early then broadcast("BlizzardEnd", { Character = s.Character }) end
end

local function castBlizzard(player, character, humanoid, root, payload)
	local Bz = CRYO.Blizzard
	local _, feet = feetOf(character, humanoid)
	local center, _, hit = VFXLibrary.GroundBelow(root.Position, { character, fxFolder() }, 30)
	if not hit then center = Vector3.new(root.Position.X, feet or root.Position.Y - 3, root.Position.Z) end
	-- cursor-targeted since 2026-10-18 (Bz.CastRange; 0 keeps the storm where the caster stands, as above)
	center = cursorFloor(character, root, payload, Bz.CastRange) or center
	endStorm(player, true)
	local look = flat(root.CFrame.LookVector)
	storms[player] = {
		Character = character, Center = center, Ends = os.clock() + Bz.Duration, Epoch = Core.Epoch(player), NextTick = 0,
	}
	broadcast("Blizzard", {
		Character = character, Center = center, T0 = serverNow(), Duration = Bz.Duration, Radius = Bz.Radius,
		-- "12 o'clock" of the edge's clock is where the caster faced (the first arc to go dark)
		Yaw = look.Magnitude > 1e-3 and math.atan2(look.X, look.Z) or 0,
	})
end

local function stepStorms(now)
	local Bz = CRYO.Blizzard
	for player, s in pairs(storms) do
		if Core.Epoch(player) ~= s.Epoch or not s.Character.Parent then
			endStorm(player, true)
		elseif now >= s.Ends then
			storms[player] = nil                           -- every client ends it on its own clock
		elseif now >= s.NextTick then
			s.NextTick = now + Bz.Tick
			local mid = s.Center + Vector3.new(0, (Bz.Height - Bz.Below) / 2, 0)
			local reach = math.sqrt(Bz.Radius ^ 2 + ((Bz.Height + Bz.Below) / 2) ^ 2)
			for victim, model in pairs(humanoidsNear(mid, reach, s.Character)) do
				if victim.Health > 0 and not isWall(model) and not isFriendly(player, model)
					and not isRooted(victim) and not model:FindFirstChild("IceFrozenState") then
					local vroot, feet = feetOf(model, victim)
					if vroot and flat(vroot.Position - s.Center).Magnitude <= Bz.Radius
						and feet >= s.Center.Y - Bz.Below and feet <= s.Center.Y + Bz.Height then
						applySlow(victim, Bz.SlowCap, Bz.SlowHold, "Chilled")
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------ DEEP FREEZE
-- An unseen trap at the caster's feet (the ground under them, at most DropLimit down; no ground -> the cast is given
-- back). It is live after ArmTime and melts after Life; MaxTraps per caster, the oldest goes. The first body that may
-- be hurt with its feet within Reach (flat) and between Below and Above the trap sets it off: Damage (a landed hit, so
-- Cold Momentum follows), then a root for Root with the frozen state, the FROZEN! look and callout. A victim who has
-- just thawed is immune to every trap for Immunity. Only the trigger is broadcast.
local traps = {}           -- { Id, Owner, Character, Pos, ArmAt, Expires, Epoch }
local trapSeq = 0
local freezeImmune = setmetatable({}, { __mode = "k" })   -- [humanoid] = os.clock() until which no trap takes them
local prisons = setmetatable({}, { __mode = "k" })        -- [victim model] = os.clock() the prison thaws

local function dropTrap(i, reason)
	local t = table.remove(traps, i)
	if t and t.Owner.Parent then tellOwner(t.Owner, "DeepFreezeGone", { Id = t.Id, Reason = reason }) end
end

local function castDeepFreeze(player, character, humanoid, root, _, role)
	local Df = CRYO.DeepFreeze
	local pos, _, hit = VFXLibrary.GroundBelow(root.Position, { character, fxFolder() }, Df.DropLimit)
	if not hit then
		-- nowhere to put it (over the drop): nothing is spent
		local slot = role or VFXLibrary.TechniqueSlot(player, "DeepFreeze")
		if slot then giveBack:Fire(player, slot, true) end
		return
	end
	local mine = 0
	for _, t in ipairs(traps) do
		if t.Owner == player then mine += 1 end
	end
	while mine >= Df.MaxTraps do
		for i, t in ipairs(traps) do
			if t.Owner == player then
				dropTrap(i, "Replaced")
				break
			end
		end
		mine -= 1
	end
	trapSeq += 1
	local now = os.clock()
	table.insert(traps, {
		Id = trapSeq, Owner = player, Character = character, Pos = pos,
		ArmAt = now + Df.ArmTime, Expires = now + Df.Life, Epoch = Core.Epoch(player),
	})
	tellOwner(player, "DeepFreezeArmed", { Id = trapSeq, Position = pos, T0 = serverNow(), ArmTime = Df.ArmTime, Life = Df.Life })
end

local function springTrap(t, victim, model, vroot, feet)
	local Df = CRYO.DeepFreeze
	local now = os.clock()
	freezeImmune[victim] = now + Df.Root + Df.Immunity
	prisons[model] = now + Df.Root
	dealDamage(t.Owner, victim, Df.Damage)
	applySlow(victim, 0, Df.Root, "Rooted")
	VFXLibrary.ApplyFrozenState(model, Df.Root)
	broadcast("DeepFreeze", {
		Character = t.Character, Victim = model, Position = t.Pos,
		At = Vector3.new(vroot.Position.X, feet, vroot.Position.Z),
		T0 = serverNow(), Duration = Df.Root, Seed = math.random(1, 2 ^ 30),
	})
	if t.Owner.Parent then tellOwner(t.Owner, "DeepFreezeGone", { Id = t.Id, Reason = "Sprung" }) end
end

local function stepTraps(now)
	local Df = CRYO.DeepFreeze
	for i = #traps, 1, -1 do
		local t = traps[i]
		if not t.Owner.Parent or Core.Epoch(t.Owner) ~= t.Epoch then
			dropTrap(i, "Cleared")
		elseif now >= t.Expires then
			dropTrap(i, "Melted")
		elseif now >= t.ArmAt then
			for victim, model in pairs(humanoidsNear(t.Pos + Vector3.new(0, 1.5, 0), Df.Reach + 3, t.Owner.Character)) do
				if victim.Health > 0 and not isWall(model) and not isFriendly(t.Owner, model)
					and (freezeImmune[victim] or 0) <= now and not model:GetAttribute("Burrowed") then
					local vroot, feet = feetOf(model, victim)
					local rise = feet and (feet - t.Pos.Y)
					if vroot and flat(vroot.Position - t.Pos).Magnitude <= Df.Reach and rise >= -Df.Below and rise <= Df.Above then
						table.remove(traps, i)
						springTrap(t, victim, model, vroot, feet)
						break
					end
				end
			end
		end
	end
end

--- A prisoner who is cleared (left the arena, a round reset) or gone: the prison breaks for everyone now.
local function breakPrison(model)
	if prisons[model] and prisons[model] > os.clock() then
		broadcast("DeepFreezeEnd", { Victim = model })
	end
	prisons[model] = nil
end

------------------------------------------------------------------------------------------ MIRROR CAGE
-- Round 2 (the owner, 2026-09-24): "the ultimate needs to be way bigger since it can also trap multiple enemies ...
-- make it so that the players who are trapped, their reflection is shooting them".
-- THE LOCK is Earthen Tomb's (TerraHandler.acquire): the enemy nearest the aim line out of the caster's eye, within
-- LockRadius of it, in front, no further than Range (+ RangeSlack), with nothing solid between -- every test on the
-- server's own copy; the client sends only where its crosshair points. A dev panel's bare cast has no aim point: the
-- caster's facing stands in for it. The lock is where the dome goes up.
-- THE DOME is Radius wide round the lock, and EVERY enemy inside it as it closes is trapped with them (up to
-- MaxVictims): rooted for CryoTuning.MirrorCageRoot(), and shot by their own reflections. CryoTuning.MirrorCageBolts()
-- is the list every client draws for each trapped body, so each bolt's damage lands here on its Arrive. The panels and
-- the reflections are drawn only; they block nothing.
-- The row is ChargeOnCatch: SpellshotService only checks the meter, and it is spent here when a cage forms, so a press
-- with nobody to lock costs nothing (the client flashes the slot when no "MirrorCage" comes back).
local cages = {}                                          -- [caster player] = cage
local caged = setmetatable({}, { __mode = "k" })          -- [trapped model] = caster player

local function acquireCage(player, character, root, aimAt)
	local Mc = CRYO.MirrorCage
	local head = character:FindFirstChild("Head")
	local eye = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local aim = validVector(aimAt) and (aimAt - eye) or root.CFrame.LookVector
	if aim.Magnitude < 1e-3 then aim = root.CFrame.LookVector end
	aim = aim.Unit
	local range = Mc.Range + Mc.RangeSlack
	local best, bestPerp, bestDist = nil, math.huge, math.huge
	for _, model in pairs(humanoidsNear(root.Position, range + 4, character)) do
		local r = model:FindFirstChild("HumanoidRootPart")
		-- never a body behind Umbra's Shadow Step veil (2026-09-27)
		if r and not caged[model] and not isWall(model) and not isFriendly(player, model) and not Core.IsVeiled(model) then
			local rel = r.Position - eye
			local along = rel:Dot(aim)
			local perp = (rel - aim * along).Magnitude
			local dist = flat(r.Position - root.Position).Magnitude
			if along > 0 and perp <= Mc.LockRadius and dist <= range
				and (perp < bestPerp - 0.25 or (perp < bestPerp + 0.25 and dist < bestDist))
				and not Core.Blocked({ Origin = eye, Dir = rel.Unit, Character = character }, rel.Magnitude, model) then
				best, bestPerp, bestDist = model, perp, dist
			end
		end
	end
	return best
end

--- Everyone the dome closes on: the lock first, then every other enemy inside it, nearest the middle first.
local function trappedIn(player, character, center, first)
	local Mc = CRYO.MirrorCage
	local list = { first }
	local others = {}
	local mid = center + Vector3.new(0, (Mc.TrapAbove - Mc.TrapBelow) / 2, 0)
	local reach = math.sqrt(Mc.Radius ^ 2 + ((Mc.TrapAbove + Mc.TrapBelow) / 2) ^ 2)
	for humanoid, model in pairs(humanoidsNear(mid, reach, character)) do
		if model ~= first and humanoid.Health > 0 and not caged[model] and not isWall(model) and not isFriendly(player, model) then
			local r, feet = feetOf(model, humanoid)
			local d = r and flat(r.Position - center).Magnitude
			if d and d <= Mc.Radius - 1 and feet >= center.Y - Mc.TrapBelow and feet <= center.Y + Mc.TrapAbove then
				others[#others + 1] = { Model = model, D = d }
			end
		end
	end
	table.sort(others, function(a, b) return a.D < b.D end)
	for _, o in ipairs(others) do
		if #list >= Mc.MaxVictims then break end
		list[#list + 1] = o.Model
	end
	return list
end

local function endCage(player, early)
	local c = cages[player]
	if not c then return end
	cages[player] = nil
	for _, v in ipairs(c.Victims) do
		if caged[v.Model] == player then caged[v.Model] = nil end
	end
	if early then broadcast("MirrorCageEnd", { Character = c.Character }) end
end

--- One trapped body leaves the cage early (cleared, gone): their reflections stop, the rest go on.
local function freeFromCage(player, v)
	if v.Gone then return end
	v.Gone = true
	local c = cages[player]
	if caged[v.Model] == player then caged[v.Model] = nil end
	if c then broadcast("MirrorCageFree", { Character = c.Character, Victim = v.Model }) end
end

local function castMirrorCage(player, character, humanoid, root, payload)
	if cages[player] then return end                      -- one at a time: the meter still reads full until it lands
	local first = acquireCage(player, character, root, payload.Target)
	if not first then return end
	local fhum = first:FindFirstChildOfClass("Humanoid")
	local froot = first:FindFirstChild("HumanoidRootPart")
	if not (fhum and froot and fhum.Health > 0) then return end
	character:SetAttribute("UltCharge", 0)
	local center, _, hit = VFXLibrary.GroundBelow(froot.Position, { first, character, fxFolder() }, 30)
	if not hit then
		local _, feet = feetOf(first, fhum)
		center = Vector3.new(froot.Position.X, feet or froot.Position.Y - 3, froot.Position.Z)
	end
	local toCaster = flat(root.Position - center)
	local rootTime = CRYO.MirrorCageRoot()
	local victims, rows = {}, {}
	for _, model in ipairs(trappedIn(player, character, center, first)) do
		local vhum = model:FindFirstChildOfClass("Humanoid")
		local vroot, feet = feetOf(model, vhum)
		if vhum and vroot then
			applySlow(vhum, 0, rootTime, "Rooted")
			caged[model] = player
			local vp = Players:GetPlayerFromCharacter(model)
			victims[#victims + 1] = {
				Model = model, Humanoid = vhum, Player = vp, Epoch = vp and Core.Epoch(vp) or nil, Next = 1, Gone = false,
			}
			rows[#rows + 1] = { Model = model, At = Vector3.new(vroot.Position.X, feet, vroot.Position.Z) }
		end
	end
	cages[player] = {
		Character = character, Center = center, Start = os.clock(), Epoch = Core.Epoch(player),
		Bolts = CRYO.MirrorCageBolts(), Victims = victims,
	}
	broadcast("MirrorCage", {
		Character = character, Center = center, T0 = serverNow(), Victims = rows,
		-- every ring's open slot faces the caster
		Yaw = toCaster.Magnitude > 1e-3 and math.atan2(toCaster.X, toCaster.Z) or 0,
	})
end

local function stepCages(now)
	local Mc = CRYO.MirrorCage
	for player, c in pairs(cages) do
		if Core.Epoch(player) ~= c.Epoch then
			endCage(player, true)
		else
			local t = now - c.Start
			local live = 0
			for _, v in ipairs(c.Victims) do
				if not v.Gone then
					if not v.Model.Parent or v.Humanoid.Health <= 0 or (v.Player and Core.Epoch(v.Player) ~= v.Epoch) then
						freeFromCage(player, v)
					else
						live += 1
						while v.Next <= #c.Bolts and c.Bolts[v.Next].Arrive <= t do
							v.Next += 1
							dealDamage(player, v.Humanoid, Mc.BoltDamage, { Ranged = true, From = c.Center + Vector3.new(0, 3, 0) })
						end
					end
				end
			end
			if live == 0 then
				endCage(player, true)
			elseif t >= CRYO.MirrorCageRoot() then
				endCage(player, false)
			end
		end
	end
end

------------------------------------------------------------------------------------------ one loop for all three
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, stepFn in ipairs({ stepStorms, stepTraps, stepCages }) do
		local ok, err = pcall(stepFn, now)
		if not ok then warn("[AbilityHandler] " .. tostring(err)) end
	end
end)

--- Everything of the three a player runs, or is held in, ends: the storm, their traps, their cage, a cage or a prison
--- round them. `early` broadcasts the ends so every client stops drawing them.
local function clearRebuilt(player, character)
	endStorm(player, true)
	for i = #traps, 1, -1 do
		if traps[i].Owner == player then dropTrap(i, "Cleared") end
	end
	endCage(player, true)
	if character then
		-- held in someone's cage: only this body leaves it, the others stay trapped
		local caster = caged[character]
		local c = caster and cages[caster]
		if c then
			for _, v in ipairs(c.Victims) do
				if v.Model == character then freeFromCage(caster, v) end
			end
		end
		breakPrison(character)
	end
end

-- (2026-10-19, audit P3-05) A reaction that breaks a root (Melt, Shatter: ElementalReactions -> Hooks.BreakRoot) ends every
-- root on the body, the Deep Freeze prison's and Mirror Cage's included -- so those mechanics end with it, out loud, the way
-- a clear ends them: the prison breaks for everyone (DeepFreezeEnd), and the body leaves its cage (MirrorCageFree: its
-- reflections stop, the rest of the cage goes on). They used to stay drawn round a body that could walk away, and the
-- cage's bolts kept landing on it wherever it went. (Whether a reaction should be able to break an Ultimate's root at all
-- is the owner's call: see the fix log.)
do
	local breakRoot = Core.Hooks.BreakRoot
	Core.Hooks.BreakRoot = function(humanoid)
		breakRoot(humanoid)
		local model = humanoid.Parent
		if not model then return end
		local caster = caged[model]
		local c = caster and cages[caster]
		if c then
			for _, v in ipairs(c.Victims) do
				if v.Model == model then freeFromCage(caster, v) end
			end
		end
		breakPrison(model)
	end
end

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
-- By ability Id, not by role: a role holds whichever ability the player's loadout puts there, and the Pyro
-- kit's Ids are PyroHandler's. The slot rides along as a sixth argument (PyroHandler's way), for a cast that has to
-- give itself back.
local casts = {
	IcicleShard = castIcicleShard,
	FlashFreeze = castFlashFreeze,
	Blizzard = castBlizzard,
	DeepFreeze = castDeepFreeze,
	MirrorCage = castMirrorCage,
}

performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = aliveCharacter(player)
	if not character then return end
	fn(player, character, humanoid, root, type(payload) == "table" and payload or {}, role)
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
local function watch(player)
	player.CharacterRemoving:Connect(function(character)
		endUltimate(player, true)
		auras[player] = nil
		clearRebuilt(player, character)
	end)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

Players.PlayerRemoving:Connect(function(player)
	endUltimate(player, true)
	auras[player] = nil
	lastAim[player] = nil
	clearRebuilt(player, player.Character)
	for i = #patches, 1, -1 do
		if patches[i].Owner == player then table.remove(patches, i) end
	end
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer). Nothing of this kit is left running for the
-- player -- the beam and its lift, the aura, the frozen patches their dashes laid (a Flash Freeze stops itself on the
-- epoch), their shards in flight -- and nothing of it stays on them: slows, roots, jump locks, Chill stacks, the frozen
-- look, the status tag, Cold Momentum.
Core.OnClear(function(player)
	endUltimate(player)
	clearRebuilt(player, player.Character)
	local aura = auras[player]
	if aura then
		auras[player] = nil
		broadcast("ChillAuraStop", { Character = aura.Character })
	end
	for i = #patches, 1, -1 do
		if patches[i].Owner == player then table.remove(patches, i) end
	end
	shots[player] = nil

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		slowed[humanoid] = nil                        -- its pending expiries find a different record and do nothing
		character:SetAttribute("SpeedCapSlow", nil)   -- SpellshotService puts the stance's speed back
		setJumpLock(humanoid, "Root", false)
		local c = chill[humanoid]
		if c then
			c.Token += 1
			c.Stacks, c.ImmuneUntil = 0, 0
		end
		publishChill(character, 0)
	end
	local frozen = character:FindFirstChild("IceFrozenState")
	if frozen then frozen:Destroy() end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child.Name == "FrozenEmitterAttachment" then child:Destroy() end
		end
	end
	character:SetAttribute("Status", "")
	character:SetAttribute("StatusExpires", 0)
	if coldMomentum[character] then
		coldMomentum[character] = nil
		character:SetAttribute("PassiveActive", false)
		character:SetAttribute("PassiveExpires", 0)
		character:SetAttribute("MoveSpeedMult", 1)
		character:SetAttribute("RX_Haste", false)
	end
end)
