--[[
	CombatCore  (ModuleScript)  ->  ServerScriptService/CombatCore

	The server's shared combat plumbing. Every ability script uses it -- AbilityHandler for the Cryo kit,
	PyroHandler for the Pyro kit -- so a hit is a hit whoever threw it:

	  DealDamage   the ONE way ability damage lands. Modifiers run first, lowest priority first (armour thins
	               a hit, then a shield soaks what is left), the Humanoid takes the rest,
	               and then the hit and kill listeners hear about it (Cold Momentum, Ember Refund). A shield
	               has to soak an Icicle Shard as surely as a Fireball, which is why this is not per kit.
	  shot checks  where every character and dummy has stood over the last second, whether something solid
	               stands on a line, and ServerStorage.ShotStats -- what a client-reported M1 hit is checked
	               against, whichever Element fired it.
	  ClearPlayer  ends everything a player has running, and takes off what is on them, when they leave the arena
	               (and before every duel round). Each ability script says what that means for it with OnClear.
	  DeathTime    the FRAME in which a hit took a humanoid to 0 (FrameClock) -- how DuelMatch orders two deaths; two in
	               the same frame are simultaneous. DealDamage also charges the caster's Ultimate by the health it removed.
	  TryParry     a parry's catch claim, asked of whatever can be parried (OnParry: TrainingGround's practice shots).
	               Nothing calls it today -- Deflect Gust, the parry, was retired on 2026-10-06 -- and the hook stays for
	               whatever parries next. (2026-10-19, audit P3-24: this read as if Deflect Gust were live.)

	Moved out of AbilityHandler on 2026-09-14, unchanged in behaviour, when the Pyro kit needed the same
	checks. Server only.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local applyStatusEvent = spellFolder:WaitForChild("ApplyStatus")
local addUltCharge = spellFolder:WaitForChild("AddUltCharge")

local Core = {}

Core.FriendlyFire = false          -- when false, players on the caster's Team are never hit

-- ELEMENTAL REACTIONS (2026-10-17): the kits' own status levers, which ServerScriptService.ElementalReactions pulls (break a
-- root, clear a Chill, fan a Burn, grow a cloud). Each kit fills in its own entries; a missing one means that kit has no
-- such status (yet), and the reaction that needs it simply does not fire.
Core.Hooks = {}

----------------------------------------------------------------------------------------------------
-- the ability remote (server -> client: ("VFX", kind, data); client -> server: shot reports, aim)
----------------------------------------------------------------------------------------------------
local remote = iceFolder:FindFirstChild("IceAbilityRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "IceAbilityRemote"
	remote.Parent = iceFolder
end
Core.Remote = remote

function Core.Broadcast(kind, data)
	remote:FireAllClients("VFX", kind, data)
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
function Core.FxFolder()
	return workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
end

function Core.AliveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root then
		return character, humanoid, root
	end
	return nil
end

--- The alive character that may ACT right now, or nil. Alive is not enough on its own: a player underground on
--- Tremor Vault is alive, rooted and untouchable, and must not be able to attack from down there. SpellshotService
--- refuses the CAST remote while Burrowed, but every kit decides its damage on its own release/hit remote, and none
--- of them knew about it -- so a burrowed player kept firing for full damage, invisibly, out of a body nothing could
--- hurt (2026-09-21). Every release handler asks this instead of Core.AliveCharacter.
function Core.CanAct(player)
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return nil end
	if character:GetAttribute("Burrowed") then return nil end
	-- ...nor across a duel's round reset (DuelMatch's CastLocked): the M1 release remotes never went through
	-- SpellshotService's gate, so a shot fired into the reset still landed on a body about to be replaced.
	if player:GetAttribute("CastLocked") then return nil end
	-- ...nor while Undertow's interrupt lasts (Aqua, 2026-09-24): InterruptedUntil, in server time
	if workspace:GetServerTimeNow() < (character:GetAttribute("InterruptedUntil") or 0) then return nil end
	return character, humanoid, root
end

--- Is this character model actually a Bulwark Wall rather than a person? It carries a Humanoid, which is how every
--- kit's hits damage it -- but that also puts it in HumanoidsNear's answers, so a status meant for a body lands on
--- it: Chill stacks and a root on a wall, the Cryo ice Highlight painted over the invisible wall box, the shatter
--- playing in mid-air at its centre (2026-09-21). Damage is right to land on it; nothing else is.
function Core.IsWall(model)
	return model ~= nil and model:GetAttribute("WallOwner") ~= nil
end

--- VEILED (Umbra's Shadow Step, 2026-09-27): from the dissolve to a moment after the re-form, a body no new target lock may
--- pick, and one a lock already homing on it loses (Earthen Tomb, Mirror Cage). VeiledUntil is server time.
function Core.IsVeiled(model)
	return model ~= nil and (model:GetAttribute("VeiledUntil") or 0) > workspace:GetServerTimeNow()
end

function Core.ValidVector(v)
	if typeof(v) ~= "Vector3" then return false end
	local x, y, z = v.X, v.Y, v.Z
	return x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6
end

function Core.ClampTarget(root, target, range)
	if not Core.ValidVector(target) then
		return root.Position + root.CFrame.LookVector * math.min(range, 10)
	end
	local d = target - root.Position
	if d.Magnitude > range then d = d.Unit * range end
	return root.Position + d
end

--- True when the caster's abilities must leave this character alone -- no damage, no slow, no root: a teammate (unless
--- FriendlyFire), and, on request (2026-09-16), any player Config.MayHurt rules out -- anyone in the Hub, even hit by
--- something thrown before they left, and any other player who is not the caster's opponent in the same duel. Since
--- 2026-10-18 (team mode) that rules out a TEAMMATE in the same team match too (MayHurt's MatchTeam clause).
--- Training dummies are not players, so they still take everything. ALLY DUMMIES (AllyDummy, 2026-09-30) take nothing,
--- from anyone: they are the range's practice allies (see Core.IsAllyOf).
function Core.IsFriendly(caster, victimCharacter)
	if victimCharacter and victimCharacter:GetAttribute("AllyDummy") then return true end
	-- a Bulwark Wall (TerraHandler, 2026-09-19) sides with whoever raised it: friendly to them, and to anyone who may not
	-- hurt them -- their team, the Hub -- and fair game to everyone who may
	-- ...and so does Umbra's Decoy Double (2026-09-27, DecoyOwner): a copy of its caster's body, friendly the same way
	local owner = victimCharacter and (victimCharacter:GetAttribute("WallOwner") or victimCharacter:GetAttribute("DecoyOwner"))
	if owner then
		local ownerPlayer = Players:GetPlayerByUserId(owner)
		if not ownerPlayer or ownerPlayer == caster then return true end
		return ownerPlayer.Character ~= nil and Core.IsFriendly(caster, ownerPlayer.Character)
	end
	local victim = Players:GetPlayerFromCharacter(victimCharacter)
	if not victim then return false end
	local isPlayer = typeof(caster) == "Instance" and caster:IsA("Player")
	if isPlayer then
		if not Config.MayHurt(caster, victim) then return true end
	elseif victim:GetAttribute("Zone") == "Hub" then
		return true
	end
	if Core.FriendlyFire or not isPlayer then return false end
	-- (2026-10-19, audit P3-09) the caster's own body before the Team clause: a Toxin's self-damage rules (its own cloud
	-- and Patient Zero burst) must not stop working the day anyone assigns Player.Team
	if victim == caster then return false end
	return victim.Team ~= nil and victim.Team == caster.Team
end

--- Two in the same PARTY: the same Map and the same duel (two players in no duel -- Solo Test -- count). Maps are shared
--- by several matches at once, so a heal, a shield or a swap never reaches into someone else's match. Works on a player
--- or on a model carrying the same attributes (an ally dummy). RadiantHandler's, moved here on 2026-09-30.
function Core.SameParty(a, b)
	return a:GetAttribute("Map") == b:GetAttribute("Map") and a:GetAttribute("DuelMatch") == b:GetAttribute("DuelMatch")
end

--- ALLIES, for every support kit (2026-09-30): may `player`'s support abilities help `model` (a shield, a heal, a share,
--- a swap)? It must be a living body, and never in the Hub. Two kinds:
---   another player in the caster's Zone and party (Core.SameParty) whom the caster may not hurt (Core.IsFriendly) --
---     so a 1v1 duel has none, and in a team match (2026-10-18) Config.MayHurt's MatchTeam clause makes teammates allies
---   an ALLY DUMMY: a model with the AllyDummy attribute and its own Zone / Map attributes, in the caster's Zone and
---     party -- the range's practice allies (ServerScriptService.AllyDummies). A duel fought on the range is not their
---     party (no DuelMatch on a dummy), so they never soak a duelist's heals.
--- The caster's own body is not its own ally: each kit decides what falls back to the caster.
function Core.IsAllyOf(player, model)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(model) ~= "Instance" then return false end
	local zone = player:GetAttribute("Zone")
	if zone == "Hub" then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return false end
	if model:GetAttribute("AllyDummy") then
		return model:GetAttribute("Zone") == zone and Core.SameParty(player, model)
	end
	local other = Players:GetPlayerFromCharacter(model)
	if not other or other == player then return false end
	if other:GetAttribute("Zone") ~= zone or not Core.SameParty(player, other) then return false end
	return Core.IsFriendly(player, model)
end

function Core.HumanoidsNear(position, radius, excludeCharacter)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- built up rather than written { excludeCharacter, fxFolder() }: with no character to exclude
	-- that literal starts with a nil, and a list with a hole in it is not a list
	local exclude = {}
	if excludeCharacter then exclude[#exclude + 1] = excludeCharacter end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	params.FilterDescendantsInstances = exclude
	local found = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			found[humanoid] = model
		end
	end
	return found
end

--- Bridge to the SPELLSHOT status tag, so the floating tag over a victim (and the local copy above their
--- own health bar) lights up from real play.
function Core.ApplyStatusTag(humanoid, statusName, duration)
	local character = humanoid.Parent
	if character then applyStatusEvent:Fire(character, statusName, duration) end
end

----------------------------------------------------------------------------------------------------
-- damage
----------------------------------------------------------------------------------------------------
-- info is a table the modifiers and listeners read: Ranged = true for a projectile or beam hit (what Heat
-- Rush thins), DoT = true for a burn tick, From = the Vector3 the hit came from (where a deflect sparks).
local modifiers = {}         -- { Priority, Fn }, lowest priority first
local hitListeners = {}
local killListeners = {}
local listenerWarned = {}

--- fn(victimHumanoid, amount, info, caster) -> the amount left after it. Lower priority runs first.
function Core.AddModifier(priority, fn)
	table.insert(modifiers, { Priority = priority, Fn = fn })
	table.sort(modifiers, function(a, b) return a.Priority < b.Priority end)
end

--- fn(caster, victimHumanoid, amount, info): every landed hit, soaked or not.
function Core.OnHitLanded(fn)
	table.insert(hitListeners, fn)
end

--- fn(caster, victimHumanoid, info): the hit that took a victim from alive to 0 health. A training dummy
--- counts every time it is knocked out (it refills rather than dying).
function Core.OnKill(fn)
	table.insert(killListeners, fn)
end

-- PARRIES (Deflect Gust). Whatever flies something that can be parried registers a resolver; a press's claim is asked
-- of each in turn until one catches. A resolver that errors counts as no catch (warned once).
local parryResolvers = {}

--- fn(player, claim) -> true if it caught (and returned) the claimed shot. `claim` is { Id = number, Contact = Vector3? }.
function Core.OnParry(fn)
	table.insert(parryResolvers, fn)
end

--- Whether any resolver caught `player`'s claim.
function Core.TryParry(player, claim)
	for _, fn in ipairs(parryResolvers) do
		local ok, caught = pcall(fn, player, claim)
		if not ok then
			if not listenerWarned[fn] then
				listenerWarned[fn] = true
				warn("[CombatCore] a parry resolver failed: " .. tostring(caught))
			end
		elseif caught then
			return true
		end
	end
	return false
end

local function tell(list, ...)
	for i, fn in ipairs(list) do
		local ok, err = pcall(fn, ...)
		if not ok and not listenerWarned[fn] then
			listenerWarned[fn] = true
			warn("[CombatCore] a damage listener failed: " .. tostring(err))
		end
	end
end

-- When a hit took each humanoid to 0, stamped right here as it lands: DuelMatch puts two deaths in order by these, not by
-- when something next looked.
-- (2026-10-19, audit P3-15) stamped with the FRAME (FrameClock: os.clock() at the last Heartbeat), not os.clock() itself.
-- One AoE killing the last player of both teams ran its DealDamage calls in pairs() order, with listeners in between,
-- so "who died first" came down to hash order and listener cost against DuelMatch's 1 ms DRAW_WINDOW. Every death in one
-- frame now has the same stamp (a draw); deaths in different frames keep their order.
local deathTimes = setmetatable({}, { __mode = "k" })
-- (2026-10-19, audit GA-08) and WHO took it there, with the killing hit's Element: { caster, element } (DuelMatch's kill feed)
local killers = setmetatable({}, { __mode = "k" })
local frameStamp = os.clock()
RunService.Heartbeat:Connect(function() frameStamp = os.clock() end)

--- The stamp a death in this frame gets (see deathTimes): DuelMatch stamps the deaths it sees itself with the same clock.
function Core.FrameClock()
	return frameStamp
end

-- WHICH ELEMENT A HIT IS (2026-10-17, for the reactions). A kit may say so in info.Element; otherwise it is the Element of
-- the kit script that dealt it, read off the call stack. A Technique lives in its own Element's script, so a hit is its
-- Technique's Element. (2026-10-19, audit P3-24) While Config.TechniquesOwnElementOnly is on (P31, 2026-10-18) that is
-- always the player's own Element; with it off, a Pyro running a Zephyr Technique would land Zephyr hits, as the old
-- shared pool intended. A script not listed (the dev panel, the range's practice shots, StatusEffects' ticks) deals hits
-- of no Element, which react with nothing.
local SCRIPT_ELEMENT = {
	AbilityHandler = "Cryo", PyroHandler = "Pyro", VoltaicHandler = "Voltaic", TerraHandler = "Terra", TerraTestServer = "Terra",
	ZephyrHandler = "Zephyr", ZephyrSkyriderServer = "Zephyr", ZephyrUpdraftServer = "Zephyr", ZephyrGustPadServer = "Zephyr",
	ToxinHandler = "Toxin", AquaHandler = "Aqua", UmbraHandler = "Umbra", RadiantHandler = "Radiant",
}
Core.ScriptElement = SCRIPT_ELEMENT

local function callerElement()
	for level = 2, 14 do
		local src = debug.info(level, "s")
		if src == nil then return nil end
		local e = SCRIPT_ELEMENT[string.match(src, "([%w_]+)$") or ""]
		if e then return e end
	end
	return nil
end

function Core.DealDamage(caster, humanoid, amount, info)
	if humanoid.Health <= 0 or Core.IsFriendly(caster, humanoid.Parent) then return false end
	info = info or {}
	if info.Element == nil then info.Element = callerElement() end
	local left = amount
	for _, m in ipairs(modifiers) do
		local ok, out = pcall(m.Fn, humanoid, left, info, caster)
		if ok and type(out) == "number" then left = math.max(0, out) end
		if left <= 0 then break end
	end
	local before = humanoid.Health
	if left > 0 then humanoid:TakeDamage(left) end
	local removed = before - math.max(humanoid.Health, 0)
	-- (2026-10-19, audit P3-01) whether THIS call took it to 0, decided now: a hit listener below may deal damage of its own
	-- (a reaction's bonus) that kills, and that inner call tells the kill listeners itself -- asking Health after the
	-- listeners told them a second time, with this hit's info, for one death
	local killed = before > 0 and humanoid.Health <= 0
	if killed then
		deathTimes[humanoid] = frameStamp                           -- (2026-10-19, audit P3-15) the frame, see deathTimes
		killers[humanoid] = { caster, info.Element }                -- (2026-10-19, audit GA-08) see Core.Killer
	end
	-- The Ultimate charges from damage DEALT as well as taken (manual, Section 3; SpellshotService counts the taking).
	-- By the health actually removed, so a hit a shield soaked whole charges nothing.
	if removed > 0 and typeof(caster) == "Instance" and caster:IsA("Player") and caster.Character ~= humanoid.Parent then
		addUltCharge:Fire(caster, removed * Config.UltChargePerDamage)
	end
	-- the health this hit actually removed (0 when a shield soaked it whole): Halo converts it (RadiantHandler, 2026-09-29)
	info.Removed = removed
	-- (2026-10-19, audit P3-01) the health this hit left, before any listener deals more: a listener comparing health before
	-- and after the hit (Ember Refund's LowHealth) reads this, not humanoid.Health, which a reaction bonus may have moved
	info.HealthAfter = math.max(humanoid.Health, 0)
	tell(hitListeners, caster, humanoid, amount, info)
	if killed then tell(killListeners, caster, humanoid, info) end
	return true
end

--- THE GAME'S ONE HEAL (2026-09-29, with the Radiant rework). Health never regenerates on its own (SpellshotConfig):
--- only abilities heal, and every heal goes through here, on the server. Clamped to MaxHealth; refused for the dead,
--- Bulwark Walls, decoys and training dummies (they refill themselves). Ally dummies (AllyDummy) ARE healed: they are
--- what support kits practise on. A heal neither charges the Ultimate nor counts
--- as damage (SpellshotService charges only on a drop). Returns the health actually restored.
local healListeners = {}
function Core.Heal(healer, humanoid, amount, info)
	if typeof(humanoid) ~= "Instance" or not humanoid:IsA("Humanoid") then return 0 end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
	local model = humanoid.Parent
	if not model or humanoid.Health <= 0 then return 0 end
	if Core.IsWall(model) or model:GetAttribute("DecoyOwner") or model:GetAttribute("TrainingDummy") then return 0 end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + amount)
	local healed = humanoid.Health - before
	if healed > 0 then tell(healListeners, healer, humanoid, healed, info or {}) end
	return healed
end

--- fn(healer, humanoid, healed, info): every heal that restored anything (RadiantHandler's heal readout listens here).
function Core.OnHeal(fn)
	table.insert(healListeners, fn)
end

--- The frame (FrameClock) in which a hit through DealDamage took `humanoid` to 0, or nil.
function Core.DeathTime(humanoid)
	return deathTimes[humanoid]
end

--- (2026-10-19, audit GA-08) Who dealt the hit that took `humanoid` to 0 through DealDamage (a Player, or nil for the world
--- and the dev panel), and that hit's Element (nil: none) -- or nil when no DealDamage killed it.
function Core.Killer(humanoid)
	local k = killers[humanoid]
	if not k then return nil end
	return k[1], k[2]
end

----------------------------------------------------------------------------------------------------
-- movement: the server's check on where a player's body goes (2026-10-19, audit P1-03)
----------------------------------------------------------------------------------------------------
-- A player's body is moved by its own client, so the server took any position a client sent: a modified client could
-- teleport, out-run every legal speed, or walk out of a root, a Mirror Cage, a Deep Freeze prison or an Earthen Tomb.
-- Three pieces (numbers: Config.MovementGuard):
--   THE GUARD   every Heartbeat, each living PLAYER's body (never a dummy) has its flat (XZ) speed measured from where it
--               stood at least Window seconds ago -- each distinct position timed from when the server FIRST saw it, so
--               replication arriving in a burst after a stall is not read as a sprint -- against BaseSpeed, or FastSpeed
--               while it is in a fast state (fastNow) at any time since that position. A move of more than MinStep studs
--               over the limit counts ShotStats "move_snap" and, while Enforce is on, is put back where the body last
--               stood (rotation kept). Vertical is never judged: falls and launches are not the guard's.
--   ALLOWMOVE   every SERVER move of a player's body (PivotTo, a teleport, a swap) opens a grace window first, in which
--               the guard leaves that body alone and after which it starts fresh.
--   HOLDBODY    while any kit holds a body (a root, the Tomb; Cyclone moves only anchored dummies, so it takes no hold), the server owns its physics -- network
--               ownership -- so a client has nothing to walk it out with; the guard does not judge a held body.
-- A new body (a respawn, a round) starts fresh: the state is per model.
local MG = Config.MovementGuard or {}
local graceUntil = setmetatable({}, { __mode = "k" })    -- [model] = os.clock() until which the guard leaves it alone
local moveSeen = setmetatable({}, { __mode = "k" })      -- [model] = { Hist = { { firstSeen, position }, ... }, FastAt }
local holds = setmetatable({}, { __mode = "k" })         -- [model] = { Keys = { [key] = true }, Count, Player, Conn }

--- A server move of `model` is coming (call it right BEFORE the PivotTo / CFrame write): the movement guard leaves the body
--- alone for `seconds` (default Config.MovementGuard.Grace), then judges it from wherever it is by then.
function Core.AllowMove(model, seconds)
	if typeof(model) ~= "Instance" then return end
	local s = (type(seconds) == "number" and seconds == seconds and seconds > 0) and math.min(seconds, 30) or (MG.Grace or 1)
	local untilT = os.clock() + s
	if untilT > (graceUntil[model] or 0) then graceUntil[model] = untilT end
	moveSeen[model] = nil
end

local function setOwner(model, player)                   -- player nil: the server
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() root:SetNetworkOwner(player) end) end
end

local function dropHolds(model)
	local h = holds[model]
	if not h then return end
	holds[model] = nil
	if h.Conn then h.Conn:Disconnect() end
	if h.Player and h.Player.Parent and model:IsDescendantOf(workspace) then setOwner(model, h.Player) end
	Core.AllowMove(model)                                -- the body is the client's again: a moment to settle
end

--- `key` holds `model` (on = true) or lets it go (on = false). One hold per (model, key): a second `on` for the same key is
--- the same hold, and one `off` ends it; the body is held while ANY key holds it. While held, a PLAYER's body is the
--- server's to simulate (its root's network owner is the server); when the last hold ends it goes back to its player,
--- and Core.AllowMove gives it a grace window. Holds go with the model, and Core.ClearPlayer drops a player's.
function Core.HoldBody(model, key, on)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or key == nil then return end
	local h = holds[model]
	if on then
		if not model:IsDescendantOf(workspace) then return end
		if not h then
			h = { Keys = {}, Count = 0, Player = Players:GetPlayerFromCharacter(model) }
			holds[model] = h
			h.Conn = model.AncestryChanged:Connect(function()
				if not model:IsDescendantOf(workspace) then dropHolds(model) end
			end)
		end
		if not h.Keys[key] then
			h.Keys[key] = true
			h.Count += 1
			if h.Player then setOwner(model, nil) end
		end
	elseif h and h.Keys[key] then
		h.Keys[key] = nil
		h.Count -= 1
		if h.Count <= 0 then dropHolds(model) end
	end
end

--- Whether any kit holds `model` (Core.HoldBody).
function Core.IsHeld(model)
	return holds[model] ~= nil
end

-- a body that may move fast right now: a Skyrider ride, a knock or a pull (KnockedUntil), a held Technique, or a cast in
-- the last FastAfterCast seconds (CastAt, SpellshotService) -- every dash, glide and blink starts with one
local function fastNow(character, serverNow)
	local ride = character:GetAttribute("SkyriderT0")
	if ride ~= nil and ride ~= false then return true end
	if serverNow < (tonumber(character:GetAttribute("KnockedUntil")) or 0) then return true end
	local castAt = tonumber(character:GetAttribute("CastAt"))
	if castAt and serverNow - castAt < (MG.FastAfterCast or 1.5) then return true end
	for _, role in ipairs(Config.Roles) do
		if character:GetAttribute("Holding_" .. role) then return true end
	end
	return false
end

local function guardBody(model, root, now, serverNow)
	local st = moveSeen[model]
	local pos = root.Position
	local fast = fastNow(model, serverNow)
	if not st then
		moveSeen[model] = { Hist = { { now, pos } }, FastAt = fast and now or -math.huge }
		return
	end
	if fast then st.FastAt = now end
	local hist = st.Hist
	local last = hist[#hist]
	if (pos - last[2]).Magnitude < 0.05 then return end  -- the same position: the time it was first seen stands
	-- the reference: the newest position first seen at least Window ago (or the oldest kept, early on)
	local window = MG.Window or 0.5
	while hist[2] and now - hist[2][1] >= window do table.remove(hist, 1) end
	local ref = hist[1]
	local t = math.clamp(now - ref[1], 1 / 60, MG.MaxGap or 3)
	local dx, dz = pos.X - ref[2].X, pos.Z - ref[2].Z
	local d = math.sqrt(dx * dx + dz * dz)
	local ceiling = (st.FastAt >= ref[1]) and (MG.FastSpeed or 170) or (MG.BaseSpeed or 90)
	if d > (MG.MinStep or 10) and d / t > ceiling then
		Core.CountShot("move_snap")
		if MG.Enforce then
			local back = last[2]
			pcall(function() model:PivotTo(model:GetPivot() + (back - pos)) end)
			return                                       -- where it last stood stays the last position
		end
	end
	hist[#hist + 1] = { now, pos }
end

RunService.Heartbeat:Connect(function()
	if MG.Enabled ~= true then return end
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			if holds[character] or root.Anchored or now < (graceUntil[character] or 0) then
				moveSeen[character] = nil                -- held, anchored or just moved by the server: fresh once let go
			else
				guardBody(character, root, now, serverNow)
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- clearing a player's fight
----------------------------------------------------------------------------------------------------
-- Everything a player has running -- a channel, an aura, a zone, a shield, a circle still to erupt, shots in flight --
-- and what is still on them (slows, roots, burns) is cleared the moment they leave the arena, whichever way they leave:
-- HubServer sets Zone, and this watches it. DuelMatch clears both duellists again before every round. Each ability
-- script registers what clearing means for it (OnClear), and anything it scheduled for later checks Epoch(player): a
-- clear moves the epoch on, so a delayed hit from before the clear lands nowhere.
local clearListeners = {}
local epochs = setmetatable({}, { __mode = "k" })

--- fn(player, reason): end what this script has running for `player`, and take off what it left on them.
function Core.OnClear(fn)
	table.insert(clearListeners, fn)
end

--- A number that changes every time `player` is cleared.
function Core.Epoch(player)
	return epochs[player] or 0
end

--- reason: "zone" (left the arena) | "round" (a duel round is being reset) | "left" (left the game)
function Core.ClearPlayer(player, reason)
	epochs[player] = (epochs[player] or 0) + 1
	tell(clearListeners, player, reason)
	-- (2026-10-19, audit P1-03) and any hold still on their body (Core.HoldBody): what held it was just cleared
	for model, h in pairs(holds) do
		if h.Player == player then dropHolds(model) end
	end
end

-- (2026-10-19, audit P3-07) LEAVING THE GAME IS A CLEAR. It moved no epoch, so whatever a leaver had running went on
-- landing in their name in some kits (Ring of Fire, Immolate burns, Flash Freeze, Twin Tide, Maw, Acid Rain, Storm
-- Surge...) but not in others (Detonate, Volt Orb, Cascade, clouds, Deep Freeze...), and could still kill and decide a
-- team match's round. Every kit's OnClear runs and every epoch check stops, as for a player leaving the arena.
Players.PlayerRemoving:Connect(function(player)
	Core.ClearPlayer(player, "left")
end)

local function watchZone(player)
	local zone = player:GetAttribute("Zone")
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local was = zone
		zone = player:GetAttribute("Zone")
		if was == "Arena" and zone ~= "Arena" then Core.ClearPlayer(player, "zone") end
	end)
end
Players.PlayerAdded:Connect(watchZone)
for _, player in ipairs(Players:GetPlayers()) do
	watchZone(player)
end

----------------------------------------------------------------------------------------------------
-- rate limits
----------------------------------------------------------------------------------------------------
-- (2026-10-19, audit P1-07) A per-player token bucket for the client remotes no other gate limits: `perSecond` tokens come
-- back each second, up to `burst`, and each call that answers true spends one. `key` names the bucket (one per action), so
-- a kit asks Core.Allow(player, "BoulderCharge", 4, 6) before doing a press's work or re-broadcasting it, and drops the
-- message (answers nothing) when it is false. An honest client never comes near a limit set above its own send rate.
local buckets = setmetatable({}, { __mode = "k" })     -- [player] = { [key] = { Tokens, At } }
function Core.Allow(player, key, perSecond, burst)
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local b = mine[key]
	if not b then
		b = { Tokens = burst, At = now }
		mine[key] = b
	end
	b.Tokens = math.min(burst, b.Tokens + (now - b.At) * perSecond)
	b.At = now
	if b.Tokens < 1 then return false end
	b.Tokens -= 1
	return true
end

----------------------------------------------------------------------------------------------------
-- the training boards' impact signal
----------------------------------------------------------------------------------------------------
local shotImpact = ServerStorage:FindFirstChild("ShotImpact")
if not shotImpact then
	shotImpact = Instance.new("BindableEvent")
	shotImpact.Name = "ShotImpact"
	shotImpact.Parent = ServerStorage
end
Core.ShotImpact = shotImpact

----------------------------------------------------------------------------------------------------
-- shot stats
----------------------------------------------------------------------------------------------------
-- EVERY OUTCOME OF A SHOT, COUNTED. ServerStorage.ShotStats holds one attribute per outcome, so a
-- report of "sometimes it hits and nothing happens" can be read off rather than argued about:
--   release / hit         accepted
--   rej_rate              the fire-rate bucket was empty
--   rej_origin            the claimed eye was too far from where the server has the shooter
--   rej_noshot            a hit arrived for a shot the server never accepted (usually rej_rate)
--   rej_late              the hit arrived after the shot's life ran out
--   rej_badpart           the claimed part is gone, or not a part
--   rej_offline           the claimed point is not on the shot's line (a Fireball: its arc)
--   rej_early             it arrived sooner than the shot could have flown there
--   rej_self              the shooter's own character
--   rej_moved             a character, but nowhere it has stood in the last second (or the caller's window)
--   rej_offpart           a fixed object, but the point is not on it
--   rej_blocked           something solid stands between the eye and the point
--   rej_launch            a Cross-Slash launch refused: longer than its hold allows, or a bad direction or distance
local statsFolder = ServerStorage:FindFirstChild("ShotStats")
if not statsFolder then
	statsFolder = Instance.new("Folder")
	statsFolder.Name = "ShotStats"
	statsFolder.Parent = ServerStorage
end

function Core.CountShot(reason)
	statsFolder:SetAttribute(reason, (statsFolder:GetAttribute(reason) or 0) + 1)
end

-- Printed to the server output, but only when shots have actually been refused since the last
-- print. In a Studio playtest the attributes can just be read off ServerStorage; in a Team Test the
-- server is a real Roblox server and this line is the only way the numbers get back to anyone.
task.spawn(function()
	local lastTotal, lastBodies = 0, 0
	while true do
		task.wait(20)
		local hits, releases, refused, worst, worstN = 0, 0, 0, nil, 0
		for k, v in pairs(statsFolder:GetAttributes()) do
			if k == "hit" then
				hits = v
			elseif k == "release" then
				releases = v
			elseif string.sub(k, 1, 4) == "rej_" then
				-- ONLY a rej_ row is a refusal. hit_char / hit_world / save_ / dmg_ are breakdowns of an accepted
				-- shot, and counting them here would read every one of them as a shot thrown away.
				refused += v
				if v > worstN then worst, worstN = k, v end
			end
		end
		local bodies = statsFolder:GetAttribute("hit_char") or 0
		if refused > lastTotal or bodies - lastBodies >= 50 then
			lastTotal, lastBodies = refused, bodies
			warn(string.format("[ShotStats] %d released, %d landed (%d on a body, %d on the world), %d refused"
				.. " -- most often %s (%d). Full breakdown: ServerStorage.ShotStats", releases, hits, bodies,
				statsFolder:GetAttribute("hit_world") or 0, refused, tostring(worst), worstN))
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- where things have stood
----------------------------------------------------------------------------------------------------
-- Where every character and dummy has stood over the last HISTORY seconds, so a hit on something that
-- moves can be checked against where the server had it around the time the shooter saw it. A claim is
-- checked against the last TRACK_TIME of that, unless its caller asks for a longer window (Cross-Slash
-- Dash reports the characters its glide passed at the Trigger, well after it passed them).
local TRACK_TIME = 1.0
local HISTORY = 2.5
-- studs from a character's root to anywhere on its body, with slack; plus a stud per unit of hitbox scale above 1
-- (HitboxScale, 2026-10-17: a standing body's farthest hitbox corner is 3.2 studs out at 1x, 3.9 at 2x)
local REACH = 4.5 + math.max(0, ((Config.Hitbox and Config.Hitbox.Scale) or 1) - 1)
local tracks = {}               -- [model] = { { time, rootPosition }, ... }, oldest first

local function trackHumanoid(humanoid)
	local model = humanoid.Parent
	if model and model:IsA("Model") and not tracks[model] then tracks[model] = {} end
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Humanoid") then trackHumanoid(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then trackHumanoid(d) end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, samples in pairs(tracks) do
		if not model.Parent then
			tracks[model] = nil
		else
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if root then
				samples[#samples + 1] = { now, root.Position }
				while samples[1] and now - samples[1][1] > HISTORY do table.remove(samples, 1) end
			end
		end
	end
end)

function Core.WasThere(model, position, window)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if root and (root.Position - position).Magnitude <= REACH then return true end
	local oldest = os.clock() - math.min(window or TRACK_TIME, HISTORY)
	for _, sample in ipairs(tracks[model] or {}) do
		if sample[1] >= oldest and (sample[2] - position).Magnitude <= REACH then return true end
	end
	return false
end

--- (2026-10-19, audit P1-01) The speed a caster's ORIGIN slack may allow for: how far the server's copy of a moving body
--- trails the real one. It used to be the root's AssemblyLinearVelocity, uncapped -- a value the owning client writes,
--- so one frame of 10,000 studs/s let a shot "leave" from anywhere and its cover check run from there (Scorching Lash
--- was the one release that capped it, review r1). Now the client's velocity counts only up to what the server has SEEN
--- this body cover over the last quarter second (its own samples above, with margin for replication arriving in
--- bursts), never under `floor` (a kit's own dash speed) and never over TRAIL_MAX.
local TRAIL_MAX = 150           -- studs/s: faster than any ride, dash or throw in the game (Skyrider boost ~75, knocks ~55)
local TRAIL_WINDOW = 0.25
function Core.TrailSpeed(root, floor)
	floor = floor or 0
	local claimed = root.AssemblyLinearVelocity.Magnitude
	local seen = 0
	local samples = tracks[root.Parent]
	if samples and #samples >= 2 then
		local last = samples[#samples]
		for i = #samples - 1, 1, -1 do
			local s = samples[i]
			if last[1] - s[1] >= TRAIL_WINDOW or i == 1 then
				local dt = last[1] - s[1]
				if dt > 1e-3 then seen = (last[2] - s[2]).Magnitude / dt end
				break
			end
		end
	end
	local speed = math.min(claimed, seen * 1.5 + 10)
	return math.min(math.max(speed, floor), math.max(TRAIL_MAX, floor))
end

--- (2026-10-19, audit P1-01) A ping as an origin allowance may use it: a lagging client raises its own ping, so it is
--- capped (Scorching Lash's LASH_MAX_LAG is 0.25 s; this is a little kinder to a long route).
function Core.Lag(ping)
	ping = tonumber(ping) or 0
	if ping ~= ping then return 0 end
	return math.clamp(ping, 0, 0.3)
end

--- True if something solid (a wall, a board) stands on the shot's line short of `along` studs, on the
--- server's copy of the world. Characters never count: where they stand is exactly what the two views
--- disagree about. `shot` carries Origin, Dir (unit) and Character.
local SAME_SURFACE = 0.75       -- studs: this close to the claimed point, a blocker IS the target
Core.SameSurface = SAME_SURFACE

function Core.Blocked(shot, along, skip)
	if along <= 0.5 then return false end
	local list = { shot.Character, skip }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(shot.Origin, shot.Dir * along, params)
		if not hit then return false end
		-- How far along the line the blocker actually is. A target board is a Model -- a Face and
		-- the frame around it -- so a shot into the face can clip the frame a few tenths of a stud
		-- earlier; that is the same object, not cover. Excluding the whole model would be simpler
		-- and would let a shot pass through the near wall of a big model to its far side.
		local depth = (hit.Position - shot.Origin):Dot(shot.Dir)
		if depth >= along - SAME_SURFACE then return false end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return true end
		-- a Bulwark Wall has a Humanoid (it is how every kit's hits damage it) but it is COVER, not a character: the
		-- one wall in the game stops every line through it (2026-09-19)
		if model:GetAttribute("WallOwner") then return true end
		list[#list + 1] = model
	end
	return false
end

--- (2026-10-19, audit P1-12 / GC-14) One PAID M1 for a shot about to deal damage: true and spent, or false. SpellshotService
--- counts every M1 CastRequest it accepts (and charges) in the player's "M1Paid" / "M1PaidAt" attributes; each kit's hit
--- path asks here once per shot, on the shot's first damaging hit (by then its cast, sent with or just after the release,
--- has arrived). A shot that never hits spends nothing, so a few paid shots may be banked -- at most M1_BANK, and none
--- once M1_STALE seconds have passed since the last one was paid. Damage can therefore never outrun what was paid for,
--- and a shot that hurts someone always had its relay sent to every other client.
local M1_BANK = 3
local M1_STALE = 6               -- longer than any M1's flight, slow motion included (a Boulder lives 2.4 s / ShotTimeScale)
local m1Used = setmetatable({}, { __mode = "k" })     -- [player] = how many of its paid shots are spent
function Core.TakePaidM1(player)
	local paid = player:GetAttribute("M1Paid") or 0
	local used = m1Used[player] or 0
	if workspace:GetServerTimeNow() - (player:GetAttribute("M1PaidAt") or -math.huge) > M1_STALE then used = paid end
	used = math.max(used, paid - M1_BANK)
	if used >= paid then
		m1Used[player] = used
		return false
	end
	m1Used[player] = used + 1
	return true
end

--- (2026-10-19, audit GC-02) Whether a Bulwark Wall stands on the line from `a` to `b` -- walls only, so a dash's own
--- line up a ramp or a stair is never refused by the floor. The wall is a model with a Humanoid, so every "through
--- characters" dash took it for a body and went through it (DashMotor, now fixed on the client); the server re-checks
--- here what a dash's damage may reach. Walls are parented straight to workspace (TerraHandler), so the list is short.
function Core.WallBetween(a, b)
	local walls = {}
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("WallOwner") then walls[#walls + 1] = m end
	end
	if #walls == 0 or not (Core.ValidVector(a) and Core.ValidVector(b)) then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = walls
	return workspace:Raycast(a, b - a, params) ~= nil
end

--- The claimed point checked against the thing claimed: a character has to have stood near it in the last
--- second (or `window` seconds, optional), a fixed part has to actually contain it. Returns nil when it holds,
--- or the rejection reason.
function Core.CheckTarget(part, position, shooterCharacter, window)
	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if model and model == shooterCharacter then return "rej_self" end
	-- a Bulwark Wall is checked like the fixed part it is -- the point must be on its body -- not like a character that
	-- moves (it is 12 studs wide: a hit at its end is further from its middle than any body's REACH)
	if humanoid and not model:GetAttribute("WallOwner") then
		if not Core.WasThere(model, position, window) then return "rej_moved" end
	else
		local lp = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2 + Vector3.new(0.5, 0.5, 0.5)
		if math.abs(lp.X) > half.X or math.abs(lp.Y) > half.Y or math.abs(lp.Z) > half.Z then
			return "rej_offpart"
		end
	end
	return nil, model, humanoid
end

return Core
