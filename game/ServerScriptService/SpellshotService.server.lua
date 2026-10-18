--[[
	SpellshotService  (Script)  ->  ServerScriptService/SpellshotService

	Owns the state the HUD reads, the resource rules every cast has to pass, and the movement
	state machine. Everything is exposed as attributes rather than a bespoke replication channel:
	attributes already replicate, are cheap, and let a test script or a future match loop drive
	the HUD without touching HUD code.

	  on the Player     Element, Mobility, Defense, Ultimate      (loadout)
	  on the Character  Mana, UltCharge, CD_<role>, CDTotal_<role>,
	                    Charges_<role> / ChargesMax_<role> / ChargeAt_<role> / CastSeq_<role>
	                      (only for an ability with Charges -- see "charges" below),
	                    CDEscape_<role> / CDEscapeTotal_<role>  (an ESCAPE charge, server time: a row with
	                      EscapeCooldown, Umbra's Shadow Step -- see the generic cast path; 2026-10-18, umbra)
	                    PassiveActive / PassiveExpires / PassiveStacks / PassiveProc,
	                    Status, StatusExpires, StatusTotal,
	                    MoveState ("None" | "Sprint" | "Crouch" | "Slide"), SlideReadyAt
	                    DevMode / DevFreeUltimate / DevFreeMana / DevNoCooldowns  (dev only)
	  CD_<role>, ChargeAt_<role> and StatusExpires are SERVER time (workspace:GetServerTimeNow()), so a
	  client reads them against the same clock rather than its own.

	Baselines follow the design manual v0.2, Section 3: 100 HP, passively regenerating mana,
	and an Ultimate charged by damage dealt/taken rather than mana-gated. On request
	(2026-09-11): M1 costs a trickle of mana, less than the regen, so it never empties the bar.
	On request (2026-09-16): health never regenerates on its own, Roblox's default regen included;
	only healing abilities heal.

	SPLIT OF RESPONSIBILITY WITH AbilityHandler
	  This script decides whether a cast is ALLOWED (alive, off cooldown or holding a charge,
	  enough mana, enough Ultimate charge) and spends the resources. AbilityHandler decides what
	  the cast DOES. They talk over one bindable, so adding an ability never means touching the
	  resource rules and rebalancing mana never means touching the ability code.

	Public API (other server scripts):
	  ReplicatedStorage.Spellshot.ApplyStatus:Fire(character, statusName, duration)
	  ReplicatedStorage.Spellshot.AddUltCharge:Fire(player, amount01)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local SkinCatalog = require(folder:WaitForChild("SkinCatalog"))
local MOVE = Config.Movement
-- Mana costs, cooldowns and charges live on the ability definitions. Required up here rather than
-- with the cast handler, because a character spawning already needs them (its charges are filled).
local VFXLibrary = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("VFXLibrary"))
-- THE ECONOMY (2026-10-18, economy): which Elements a player OWNS (ServerScriptService.PlayerData; the numbers are
-- EconomyConfig's). Every way this script sets a player's Element asks it first -- except the dev panel's SetElement,
-- which is a dev's to bypass.
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Economy = require(folder:WaitForChild("EconomyConfig"))

local function remoteEvent(name)
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end

local function bindable(name)
	local b = folder:FindFirstChild(name)
	if not b then
		b = Instance.new("BindableEvent")
		b.Name = name
		b.Parent = folder
	end
	return b
end

local castRemote = remoteEvent("CastRequest")
local moveRemote = remoteEvent("MoveRequest")
local devRemote = remoteEvent("DevRequest")
local loadoutRemote = remoteEvent("LoadoutRequest")   -- the player's own Element / Technique choice
local killFeed = remoteEvent("KillFeed")   -- server -> client duel results for the HUD feed
local applyStatusEvent = bindable("ApplyStatus")
local addUltEvent = bindable("AddUltCharge")
local performCast = bindable("PerformCast")     -- SpellshotService -> AbilityHandler / PyroHandler
-- An ability script ending a HELD ability itself (Heat Rush at its longest hold): (player, role). The
-- cooldown starts here, exactly as it does when the player lets go.
local releaseHold = bindable("ReleaseHold")
-- An ability script SPENDING mana as it runs: (player, amount). The mana bar is this script's -- an ability
-- script writing the attribute would be overwritten by the regen on the next frame. Tremor Vault drains it
-- while she is under the ground.
local spendMana = bindable("SpendMana")
-- ...and GIVING A CAST BACK when the ability script finds it cannot run after all (Tremor Vault with nowhere
-- to sink): (player, role). Both the cooldown and the mana go back, so a cast that did nothing costs nothing.
-- (player, role, true) also takes back the Ultimate charge the cast added (Detonate's, 2026-09-23).
local giveBack = bindable("GiveBack")
-- PRECHECKS (2026-09-23). A row with Precheck = true is asked about BEFORE it is paid for: its ability script parents a
-- BindableFunction named Precheck_<Id> here and answers (player, role, payload) with true or not. See the generic cast
-- path below. Detonate is the first: a press with no target costs nothing at all.

----------------------------------------------------------------------------------------------------
-- developer mode
----------------------------------------------------------------------------------------------------
-- The only thing this changes is what a cast COSTS. Every ability still runs its real code path,
-- so a dev testing the Cryo Beam with a free Ultimate is testing the shipping Ultimate.
-- Gated in Config.Dev: Studio always, a live server only for the place owner and only when
-- AllowInLiveGame is on.
local DEV = Config.Dev or {}
local publishDev                       -- defined with the dev toggles, below

local function isDev(p)
	return Config.IsDev(p)             -- the one rule, shared with the duel's BACK TO HUB gate (HubServer)
end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local state = {}   -- [player] = { LastDamage, ManaFloat, SlideReadyAt, MoveState, Charges, CastSeq }

local function getState(p)
	local s = state[p]
	if not s then
		s = { LastDamage = 0, ManaFloat = Config.MaxMana, SlideReadyAt = 0, MoveState = "None" }
		s.Charges = {}   -- [role] = { Count, Max, NextAt, LockUntil }   (server time)
		s.CastSeq = {}   -- [role] = the last client Seq answered for that role
		s.Dev = isDev(p)
		s.FreeUltimate = s.Dev and DEV.FreeUltimate == true
		s.FreeMana = s.Dev and DEV.FreeMana == true
		s.NoCooldowns = s.Dev and DEV.NoCooldowns == true
		state[p] = s
	end
	return s
end

----------------------------------------------------------------------------------------------------
-- charges
----------------------------------------------------------------------------------------------------
-- An ability with a Charges field (Frost Slide, today) holds a small stock instead of one cooldown.
-- Each cast spends a charge, and they come back ONE AT A TIME, a full Cooldown apart, the clock
-- starting at the first spend -- three dashes back to back take three cooldowns to refill, not one.
-- ChargeGap is the short lockout between two casts, so the stock cannot be dumped in one frame.
-- Every time in here is SERVER time (workspace:GetServerTimeNow()): the client reads these
-- attributes, and only that clock means the same thing on both machines.
--
-- The HUD's CD_ / CDTotal_ keep their meaning: while charges remain they carry the ChargeGap
-- lockout, and only at zero do they carry the wait for the next charge. CastSeq_ is the last
-- request of the client's own that the server has answered, accepted or refused, which is how the
-- client counts the casts it has sent that are still in flight.
local function chargeRecord(p, role)
	local ability = VFXLibrary.AbilityFor(p, role)
	local s = getState(p)
	if not (ability and ability.Charges) then
		s.Charges[role] = nil
		return nil
	end
	local c = s.Charges[role]
	-- a loadout change can put a different ability in the slot: that one starts with its own full stock
	if not c or c.Id ~= ability.Id then
		c = { Id = ability.Id, Count = ability.Charges, Max = ability.Charges, NextAt = 0, LockUntil = 0 }
		s.Charges[role] = c
	end
	return c, ability
end

local function publishCharges(character, role, c, ability)
	if not character then return end
	character:SetAttribute("Charges_" .. role, c.Count)
	character:SetAttribute("ChargesMax_" .. role, c.Max)
	character:SetAttribute("ChargeAt_" .. role, c.NextAt)
	if c.Count > 0 then
		character:SetAttribute("CD_" .. role, c.LockUntil)
		character:SetAttribute("CDTotal_" .. role, ability.ChargeGap or 0)
	else
		character:SetAttribute("CD_" .. role, c.NextAt)
		character:SetAttribute("CDTotal_" .. role, ability.Cooldown)
	end
end

--- The slot no longer holds a charge ability (a loadout change): the HUD's badge goes with the attributes.
local function clearCharges(character, role)
	if not character then return end
	character:SetAttribute("Charges_" .. role, nil)
	character:SetAttribute("ChargesMax_" .. role, nil)
	character:SetAttribute("ChargeAt_" .. role, nil)
end

--- Records that a client request has been answered. Kept on the player as well as the character: a
--- respawn must republish the last Seq rather than reset it to 0, or a client whose counter carried
--- on across the death would count every dash it ever made as still in flight.
local function settleSeq(p, character, role, seq)
	if type(seq) ~= "number" then return end
	getState(p).CastSeq[role] = seq
	if character then character:SetAttribute("CastSeq_" .. role, seq) end
end

local function setStatus(character, statusName, duration)
	if not (character and character.Parent) then return end
	local def = Config.Statuses[statusName]
	if not def then
		character:SetAttribute("Status", "")
		character:SetAttribute("StatusExpires", 0)
		return
	end
	character:SetAttribute("Status", statusName)
	character:SetAttribute("StatusTotal", duration or 0)
	-- SERVER time, the way CD_ is. This was stamped in os.clock() (2026-09-21), which is per-VM CPU time
	-- and means nothing on another machine: the HUD subtracted it from its own clock, so the CHILLED /
	-- ROOTED tag either never showed at all or showed a bar that never drained.
	character:SetAttribute("StatusExpires", duration and (workspace:GetServerTimeNow() + duration) or 0)
end

applyStatusEvent.Event:Connect(function(character, statusName, duration)
	setStatus(character, statusName, duration)
end)

addUltEvent.Event:Connect(function(p, amount)
	local ch = p and p.Character
	if not ch then return end
	ch:SetAttribute("UltCharge", math.clamp((ch:GetAttribute("UltCharge") or 0) + (amount or 0), 0, 1))
end)

----------------------------------------------------------------------------------------------------
-- movement
----------------------------------------------------------------------------------------------------
-- The client asks for a state and owns the feel (camera dip, slide tilt, the impulse itself --
-- it has network ownership of its own character, so an impulse applied here would fight it).
-- The server owns the CONSEQUENCES: walk speed, hip height, and the slide cooldown. That keeps
-- speed server-authoritative without making the movement feel laggy.
local VALID_MOVE = { None = true, Sprint = true, Crouch = true, Slide = true, SlideJump = true }
local SLIDE_GRACE = 0.2   -- seconds of latency slack either side of a slide's end

-- Speed for a stance, under any cap an ability has put on the character. AbilityHandler publishes
-- them as attributes -- SpeedCapSlow for slows and roots, SpeedCapUlt while the Ultimate holds
-- you -- and the client predicts with the same rule, so both sides always agree.
local STANCE_SPEED = { Crouch = "CrouchSpeed", Slide = "SlideSpeed", Sprint = "SprintSpeed" }
local function stanceSpeed(character, state)
	-- MoveSpeedMult is a buff (Cryo's Cold Momentum): it scales the stance, and caps still win
	-- RushSpeedMult is Heat Rush's own, kept apart so it and Cold Momentum never overwrite each other
	local v = MOVE[STANCE_SPEED[state] or "BaseWalkSpeed"] * (character:GetAttribute("MoveSpeedMult") or 1)
		* (character:GetAttribute("RushSpeedMult") or 1)
	return math.min(v, character:GetAttribute("SpeedCapSlow") or math.huge,
		character:GetAttribute("SpeedCapUlt") or math.huge)
end

local function applyMoveState(player, character, humanoid, newState)
	local s = getState(player)
	s.MoveState = newState
	character:SetAttribute("MoveState", newState)

	if newState == "Crouch" then
		humanoid.WalkSpeed = stanceSpeed(character, newState)
		humanoid.HipHeight = MOVE.CrouchHipHeight
	elseif newState == "Slide" then
		-- WalkSpeed was pinned to SlideEndSpeed here for the whole slide, and that is what made
		-- the slide a constant crawl: the Humanoid's own controller drives the character toward
		-- MoveDirection * WalkSpeed every physics step, so it simply overwrote the client's
		-- decaying velocity write. It opens at the entry speed instead and the client walks it
		-- down the curve from there, which is also what stops a held W from turning the tail
		-- of the slide back into a sprint.
		humanoid.WalkSpeed = stanceSpeed(character, newState)
		humanoid.HipHeight = MOVE.CrouchHipHeight
	elseif newState == "Sprint" then
		humanoid.WalkSpeed = stanceSpeed(character, newState)
		humanoid.HipHeight = character:GetAttribute("BaseHipHeight") or humanoid.HipHeight
	else
		humanoid.WalkSpeed = stanceSpeed(character, newState)
		humanoid.HipHeight = character:GetAttribute("BaseHipHeight") or humanoid.HipHeight
	end
end

moveRemote.OnServerEvent:Connect(function(player, requested)
	if not VALID_MOVE[requested] then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then return end
	local s = getState(player)
	local now = os.clock()

	if requested == "Slide" then
		if now < s.SlideReadyAt then return end            -- server owns the slide cooldown
		if s.MoveState == "Slide" then return end
		-- the backstop from the slide's START follows its duration; an early end gives the rest back (below)
		local slideCooldown = MOVE.SlideDuration + (MOVE.SlideRegap or 0)
		s.SlideReadyAt = now + slideCooldown
		-- Published in SERVER time. os.clock() is different on every machine, so the client checks
		-- this against workspace:GetServerTimeNow(), never against its own clock -- which only ever
		-- agreed in Studio, where client and server are the same process.
		character:SetAttribute("SlideReadyAt", workspace:GetServerTimeNow() + slideCooldown)
		s.SlideStart = now
		applyMoveState(player, character, humanoid, "Slide")
		local started = now
		-- The CLIENT ends its own slide, on its own clock, and says what comes next: crouch if Ctrl
		-- is still held, otherwise straight back into the run. This timer is only the backstop for
		-- a client that never says (it fires a little past the slide's longest, for latency): it stands
		-- that client into a crouch.
		task.delay(MOVE.SlideDuration + SLIDE_GRACE, function()
			if state[player] ~= s or s.MoveState ~= "Slide" or s.SlideStart ~= started then return end
			if character.Parent and humanoid.Health > 0 then
				applyMoveState(player, character, humanoid, "Crouch")
			end
		end)
		return
	end

	-- A SLIDE THAT ENDS EARLY GIVES THE REST OF ITS COOLDOWN BACK (2026-10-04). The cooldown runs from the
	-- slide's START and is sized to a full slide (SlideDuration + SlideRegap), so a slide cut short -- the key let
	-- go, a slide-jump -- left the next press refused for up to a second, and a refused slide is a crouch:
	-- slide, slide-jump, land, Ctrl was 8 studs/s out of a 50 studs/s leap, every time. Whatever ends a
	-- slide now opens the next one. The client keeps SlideRegap between them on its own clock; the two
	-- requests arrive in order, so nothing is gained by asking early.
	if s.MoveState == "Slide" then
		s.SlideReadyAt = math.min(s.SlideReadyAt, now)
		character:SetAttribute("SlideReadyAt", math.min(character:GetAttribute("SlideReadyAt") or 0,
			workspace:GetServerTimeNow() + (MOVE.SlideRegap or 0)))
	end

	-- A slide-jump is the one EARLY way out of a slide: it stands you up into the leap (sprint
	-- speed, full hip height), and because MoveState is no longer "Slide" the timer above does
	-- nothing. The client carries the leap's extra speed itself.
	if requested == "SlideJump" then
		if s.MoveState ~= "Slide" then return end
		applyMoveState(player, character, humanoid, "Sprint")
		return
	end

	-- Anything else during a slide is the client's exit, and it is applied AT ONCE. It used to be held
	-- here until the slide's full duration had run, so a slide the client had already ended -- the key
	-- let go, a wall, a ledge -- went on showing as "Slide" to everyone for up to a second: the body
	-- pose, the slide sound. Ending one early buys a cheat nothing (it gives up the speed), and the
	-- next slide is still SlideRegap behind this one's end.
	applyMoveState(player, character, humanoid, requested)
end)

----------------------------------------------------------------------------------------------------
-- dev toggles
----------------------------------------------------------------------------------------------------
-- Attributes rather than a reply message, so the readout in SpellshotInput and anything else
-- that cares can just watch them. A non-dev never gets them set at all, which is also how the
-- client decides whether to draw the readout.
publishDev = function(p, character)
	character = character or p.Character
	if not character then return end
	local s = getState(p)
	if not s.Dev then return end
	character:SetAttribute("DevMode", true)
	character:SetAttribute("DevFreeUltimate", s.FreeUltimate)
	character:SetAttribute("DevFreeMana", s.FreeMana)
	character:SetAttribute("DevNoCooldowns", s.NoCooldowns)
	if s.FreeUltimate then character:SetAttribute("UltCharge", 1) end
end

local DEV_ACTIONS = {
	ToggleFreeUlt = "FreeUltimate",
	ToggleFreeMana = "FreeMana",
	ToggleNoCooldowns = "NoCooldowns",
}

-- Reaction kinds the dev panel can raise on the character. StatusReactions watches RX_<Kind>
-- booleans, so a test trigger is just an attribute write -- no bespoke test path that could
-- drift from what real gameplay does.
local RX_KINDS = {
	-- Charged is Voltaic's status since manual v0.13 (it was Shocked); Blessed is Radiant's, run by StatusEffects
	Burning = true, Chilled = true, Poisoned = true, Charged = true, Shielded = true, Blessed = true,
	Marked = true, Stealth = true, VisionDenial = true, Haste = true, ZoneWarning = true,
	-- Pyro's Detonate mark (2026-09-23): a kind of its own, deliberately not Umbra's Marked
	Primed = true,
}
-- The number suffixes a kind can carry beside its flag and its _Element, which SetStatus can write so the panel can test
-- what they drive (2026-09-23): _Stacks (Chill's, and Scorching Lash's burn stacks), and a countdown's _Expires (server
-- time) / _Total / _By (Detonate's RX_Primed). Turning a kind off clears them.
local RX_SUFFIXES = { "_Stacks", "_Expires", "_Total", "_By" }

--- Told once per player, so a refused dev panel says why instead of looking broken. This is how
--- the panel behaved in Team Test before AllowInLiveGame was turned on: it opened, and nothing it
--- asked for happened.
local toldNotDev = {}

devRemote.OnServerEvent:Connect(function(p, action, a, b, c)
	local s = getState(p)
	if not s.Dev then
		if not toldNotDev[p] then
			toldNotDev[p] = true
			devRemote:FireClient(p, "denied", RunService:IsStudio())
		end
		return                                -- a non-dev firing this remote gets nothing
	end
	local character = p.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- ---- dev panel: loadout ----------------------------------------------------------------
	if action == "SetElement" then
		-- through ApplyElement, as a loadout pick is (2026-09-24): the Element's default Techniques and its own Ultimate
		if Config.Elements[a] then Config.ApplyElement(p, a) end
		return
	-- ---- dev panel: economy (2026-10-18, economy) ------------------------------------------------------
	-- Through PlayerData's real paths, so a press changes exactly what a match reward, an unlock and a new save change.
	elseif action == "EcoAddSparks" then
		PlayerData.AddSparks(p, 1000, "dev")
		return
	elseif action == "EcoUnlockAll" then
		for name in pairs(Config.Elements) do PlayerData.Unlock(p, name) end
		return
	elseif action == "EcoReset" then
		-- a new player's save: the starter kit and 0 Sparks. An equipped Element the reset took away goes back to the default.
		if PlayerData.ResetToStarter(p) and not PlayerData.Owns(p, p:GetAttribute("Element")) then
			Config.ApplyElement(p, Config.DefaultLoadout.Element)
		end
		return
	elseif action == "SetTechnique" then
		-- a = Technique slot ("Mobility" = Q / "Defense" = E), b = any Technique key (v0.7, 2026-09-24: one pool for
		-- both slots; the Ultimate is the Element's own and is not set here). Unbuilt ones are allowed, as ever for the
		-- panel -- but not one this Element may not hold (Detonate off Pyro), nor the one already in the other slot.
		local element = p:GetAttribute("Element") or Config.DefaultLoadout.Element
		local other = (a == "Mobility") and "Defense" or "Mobility"
		if (a == "Mobility" or a == "Defense") and Config.ElementMayHold(element, b)
			and (p:GetAttribute(other) or Config.DefaultLoadout[other]) ~= b then
			p:SetAttribute(a, b)
		end
		return
	elseif action == "SetStatus" then
		-- a = reaction kind, b = on/off, c = source Element -- or (2026-09-23) a table { Element, Stacks, Fuse, By }:
		-- Stacks -> RX_<a>_Stacks, Fuse (seconds) -> RX_<a>_Expires (server time) and RX_<a>_Total, By -> RX_<a>_By (a
		-- UserId; a countdown with none is the dev's own). The suffixes go on BEFORE the flag, the flag comes off FIRST,
		-- as the real writers do it (PyroHandler, AbilityHandler), so the reactions see what gameplay would show them.
		if not RX_KINDS[a] then return end
		local flag = "RX_" .. a
		if b then
			local opts = type(c) == "table" and c or { Element = c }
			if type(opts.Element) == "string" then character:SetAttribute(flag .. "_Element", opts.Element) end
			if type(opts.Stacks) == "number" and opts.Stacks >= 1 then
				character:SetAttribute(flag .. "_Stacks", math.floor(math.min(opts.Stacks, 99)))
			end
			if type(opts.By) == "number" then character:SetAttribute(flag .. "_By", opts.By) end
			if type(opts.Fuse) == "number" and opts.Fuse > 0 then
				local fuse = math.min(opts.Fuse, 60)
				local expires = workspace:GetServerTimeNow() + fuse
				character:SetAttribute(flag .. "_Expires", expires)
				character:SetAttribute(flag .. "_Total", fuse)
				if type(opts.By) ~= "number" then character:SetAttribute(flag .. "_By", p.UserId) end
				-- a test countdown runs out by itself, as a real mark does when it goes off -- unless it was rewritten
				task.delay(fuse, function()
					if character.Parent and character:GetAttribute(flag .. "_Expires") == expires then
						character:SetAttribute(flag, false)
						for _, suffix in ipairs(RX_SUFFIXES) do character:SetAttribute(flag .. suffix, nil) end
					end
				end)
			end
			character:SetAttribute(flag, true)
		else
			character:SetAttribute(flag, false)
			for _, suffix in ipairs(RX_SUFFIXES) do character:SetAttribute(flag .. suffix, nil) end
		end
		return
	elseif action == "StatusPreset" then
		-- ELEMENTAL APPLICATION (2026-09-24): the balance rework in play, "A" | "B" | "C" (StatusEffects.Presets), read by
		-- every status at the moment it is used. Required HERE, not at the top: StatusEffects needs CombatCore, which waits
		-- for the ApplyStatus bindable this script makes.
		local Status = require(script.Parent:WaitForChild("StatusEffects"))
		if Status.Presets[a] then folder:SetAttribute("StatusPreset", a) end
		return
	elseif action == "StatusApply" then
		-- a = Poisoned | Charged | Marked | Blessed (the statuses whose kits are not built yet), b = "self" | "dummy".
		-- A dummy gets it FROM the dev, as a hit would give it; the dev's own body gets it from no one (the world), so
		-- nothing about it is "friendly" and it can be tested on your own HUD.
		local Status = require(script.Parent:WaitForChild("StatusEffects"))
		if b == "dummy" then
			local root = character:FindFirstChild("HumanoidRootPart")
			local best, bestD
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("Humanoid") and d.Health > 0 and d.Parent ~= character and not Players:GetPlayerFromCharacter(d.Parent)
					and not d.Parent:GetAttribute("WallOwner") then
					local r = d.Parent:FindFirstChild("HumanoidRootPart") or d.Parent.PrimaryPart
					local dist = (r and root) and (r.Position - root.Position).Magnitude or math.huge
					if dist < 250 and (not bestD or dist < bestD) then best, bestD = d, dist end
				end
			end
			if best then Status.Apply(p, best, a) end
		elseif humanoid then
			Status.Apply(nil, humanoid, a)
		end
		return
	elseif action == "StatusHit" then
		-- a hit on the dev's own body THROUGH the damage pipeline (Heat Rush, shields, Mark's bonus, Blessing's soak all
		-- run), which "Damage" above skips; nothing lands in the Hub (CombatCore.IsFriendly)
		local Core = require(script.Parent:WaitForChild("CombatCore"))
		if humanoid then Core.DealDamage(nil, humanoid, a or 20, {}) end
		return
	elseif action == "ClearStatuses" then
		for kind in pairs(RX_KINDS) do
			character:SetAttribute("RX_" .. kind, false)
			for _, suffix in ipairs(RX_SUFFIXES) do character:SetAttribute("RX_" .. kind .. suffix, nil) end
		end
		character:SetAttribute("Status", "")
		character:SetAttribute("StatusExpires", 0)
		return
	elseif action == "LegacyStatus" then
		-- drives the single-name Status attribute, which is what the floating tag reads
		if a and Config.Statuses[a] then
			character:SetAttribute("StatusTotal", b or 6)
			character:SetAttribute("StatusExpires", workspace:GetServerTimeNow() + (b or 6))
			character:SetAttribute("Status", a)
		else
			character:SetAttribute("Status", "")
			character:SetAttribute("StatusExpires", 0)
		end
		return
	elseif action == "ReactionStatus" then
		-- ELEMENTAL REACTIONS (2026-10-17): a = Burning | Chilled | Rooted | Poisoned | Charged on the nearest dummy, from the
		-- dev, so a reaction can be set off by hitting it with another Element (ServerScriptService.ElementalReactions)
		local fn = game:GetService("ServerStorage"):FindFirstChild("ReactionsDebug")
		if fn and type(a) == "string" then pcall(function() fn:Invoke("status", p, a, "dummy") end) end
		return
	elseif action == "Heal" then
		if humanoid then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (a or 25)) end
		return
	elseif action == "Damage" then
		-- nobody has health to lose in the Hub (CombatCore.IsFriendly), the dev included
		if humanoid and p:GetAttribute("Zone") ~= "Hub" then humanoid.Health = math.max(1, humanoid.Health - (a or 25)) end
		return
	elseif action == "SetShield" then
		character:SetAttribute("Shield", a or 0)
		return
	elseif action == "SetUltCharge" then
		character:SetAttribute("UltCharge", math.clamp(a or 0, 0, 1))
		return
	elseif action == "Kill" then
		-- broadcast a duel result so the HUD feed can be exercised without a real kill
		local ev = folder:FindFirstChild("KillFeed")
		if ev then
			ev:FireAllClients(a or p.Name, b or "TESTDUMMY", c or p:GetAttribute("Element"))
		end
		return
	end

	if action == "FillUlt" then
		character:SetAttribute("UltCharge", 1)
	elseif action == "ClearCooldowns" then
		for _, role in ipairs({ "Primary", "Mobility", "Defense" }) do
			character:SetAttribute("CD_" .. role, 0)
			character:SetAttribute("CDEscape_" .. role, 0)          -- the escape charge too (2026-10-18, umbra)
			local rec, ability = chargeRecord(p, role)
			if rec then
				rec.Count, rec.NextAt, rec.LockUntil = rec.Max, 0, 0
				publishCharges(character, role, rec, ability)
			end
		end
		s.ManaFloat = Config.MaxMana
		character:SetAttribute("Mana", s.ManaFloat)
	else
		local field = DEV_ACTIONS[action]
		if not field then return end
		s[field] = not s[field]
	end
	publishDev(p, character)
end)

----------------------------------------------------------------------------------------------------
-- spawn
----------------------------------------------------------------------------------------------------
local function onCharacter(p, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth
	humanoid.WalkSpeed = MOVE.BaseWalkSpeed
	-- a cap coming or going re-applies the stance's speed under whatever caps remain
	for _, attr in ipairs({ "SpeedCapSlow", "SpeedCapUlt", "MoveSpeedMult", "RushSpeedMult" }) do
		character:GetAttributeChangedSignal(attr):Connect(function()
			if humanoid.Parent then
				humanoid.WalkSpeed = stanceSpeed(character, character:GetAttribute("MoveState") or "None")
			end
		end)
	end
	-- No overhead nameplate health bar. This is the second of Roblox's two built-in health
	-- displays; the client turns off the core-GUI one (FirstPersonController), and this one has to
	-- be killed per Humanoid. Set on the SERVER so it holds for every viewer, not just the owner:
	-- health is read off the pop-art HP bar and nowhere else.
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.HealthDisplayDistance = 0

	-- STOCK ANIMATION OFF, SERVER SIDE. CastPose is the only thing that poses a body in this game:
	-- it owns idle, sprint, crouch, slide and every cast, on the real character, so first and third
	-- person cannot disagree. Roblox's Animate script fights that and wins -- the animator writes
	-- joint Transforms after every RenderStepped binding, so a client-side pose can neither compose
	-- with it nor cancel it reliably (measured: the Ready stance came out as an arm hanging at the
	-- side). Disabling it HERE rather than on each client matters: an Animate script runs on its
	-- owner's machine and replicates through the Animator, so a client can only silence its own
	-- character. Server-side, it is off for everyone.
	task.spawn(function()
		local animate = character:FindFirstChild("Animate")
			or character:WaitForChild("Animate", 5)
		if animate then animate.Disabled = true end
	end)
	-- Roblox's default Health script heals 1% a second in one-second steps, starting straight after
	-- a hit. Health never regenerates in this game (only healing abilities heal), so it goes; keep
	-- this even though nothing replaces it, or Roblox's own regen comes back.
	task.spawn(function()
		local regen = character:FindFirstChild("Health") or character:WaitForChild("Health", 5)
		if regen and regen:IsA("Script") then regen:Destroy() end
	end)
	-- UniformAvatar's ApplyDescription can change HipHeight, so record whatever this rig's
	-- standing height actually is rather than assuming the R15 default
	task.defer(function()
		if character.Parent then character:SetAttribute("BaseHipHeight", humanoid.HipHeight) end
	end)

	character:SetAttribute("Mana", Config.MaxMana)
	-- A duel carries the Ultimate from round to round. DuelMatch rebuilds both duellists with LoadCharacter every round,
	-- which would empty it, so while the player's "DuelMatch" attribute is set a new body gets the charge the last had.
	local ult = getState(p)
	character:SetAttribute("UltCharge", (p:GetAttribute("DuelMatch") ~= nil) and (ult.UltCarry or 0) or 0)
	ult.UltCarry = character:GetAttribute("UltCharge")
	character:GetAttributeChangedSignal("UltCharge"):Connect(function()
		if p.Character == character then ult.UltCarry = character:GetAttribute("UltCharge") or 0 end
	end)
	character:SetAttribute("Status", "")
	character:SetAttribute("StatusExpires", 0)
	character:SetAttribute("PassiveActive", false)
	character:SetAttribute("PassiveExpires", 0)
	character:SetAttribute("PassiveStacks", 0)
	character:SetAttribute("PassiveProc", 0)
	character:SetAttribute("MoveSpeedMult", 1)
	character:SetAttribute("MoveState", "None")
	character:SetAttribute("SlideReadyAt", 0)
	local s = getState(p)
	for _, role in ipairs({ "Primary", "Mobility", "Defense" }) do
		character:SetAttribute("CD_" .. role, 0)
		character:SetAttribute("CDTotal_" .. role, 1)
		character:SetAttribute("CDEscape_" .. role, 0)              -- a new life starts with the escape charge ready (2026-10-18, umbra)
		-- a new life starts with a full stock of charges
		local c, ability = chargeRecord(p, role)
		if c then
			c.Count, c.NextAt, c.LockUntil = c.Max, 0, 0
			publishCharges(character, role, c, ability)
		else
			clearCharges(character, role)
		end
		-- the last answered Seq goes on EVERY new body, for every role, whatever the slot holds now (review r1,
		-- 2026-09-24): Element-fixed slots mean an Element change swaps the Mobility and Defense abilities, and a body
		-- spawned while the slot held no charge ability used to carry no CastSeq_ at all. When a charge ability came
		-- back into the slot (refreshSlots), the client counted every request it had ever sent in that role as still
		-- in flight, and refused the key for good
		character:SetAttribute("CastSeq_" .. role, s.CastSeq[role] or 0)
	end
	s.ManaFloat = Config.MaxMana
	s.MoveState = "None"
	s.SlideReadyAt = 0                  -- a new body's slide is ready, as its SlideReadyAt attribute already says
	publishDev(p, character)

	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(h)
		if h < last then
			getState(p).LastDamage = os.clock()
			-- Ultimate charge builds from damage taken, here, and from damage dealt, in CombatCore.DealDamage (manual, Section 3)
			character:SetAttribute("UltCharge",
				math.clamp((character:GetAttribute("UltCharge") or 0) + (last - h) * Config.UltChargePerDamage, 0, 1))
		end
		last = h
	end)
end

--- A loadout change can put a different ability in a slot: its charges (or none) are republished at once.
local function refreshSlots(p)
	local character = p.Character
	if not character then return end
	for _, role in ipairs({ "Primary", "Mobility", "Defense" }) do
		local c, ability = chargeRecord(p, role)
		if c then publishCharges(character, role, c, ability) else clearCharges(character, role) end
		-- ...and the last answered Seq with it, so a charge ability coming back into a slot on this same body (an
		-- Element or Technique change) is not read against a CastSeq_ this body never had (see onCharacter)
		character:SetAttribute("CastSeq_" .. role, getState(p).CastSeq[role] or 0)
	end
end

local function onPlayer(p)
	for _, key in ipairs({ "Element", "Mobility", "Defense", "Ultimate" }) do
		p:GetAttributeChangedSignal(key):Connect(function() refreshSlots(p) end)
	end
	-- The finalized Cryo kit, in full. This used to be a random draw from the shared pools; with
	-- the kit finalized, every slot now points at something that is actually implemented.
	for k, v in pairs(Config.DefaultLoadout) do
		p:SetAttribute(k, v)
	end
	-- ...and the default Element's own Techniques and Ultimate, as any Element change gives them (2026-09-24). OWNED ONLY
	-- (2026-10-18, economy): the default (Cryo) is in the starter kit, which PlayerData counts as owned before the save has
	-- even loaded; were the kit ever to drop it, the kit's first Element stands in.
	local first = Config.DefaultLoadout.Element
	if not PlayerData.Owns(p, first) then first = Economy.StarterElements[1] end
	Config.ApplyElement(p, first)
	if p.Character then task.spawn(onCharacter, p, p.Character) end
	p.CharacterAdded:Connect(function(c) onCharacter(p, c) end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
----------------------------------------------------------------------------------------------------
-- loadout
----------------------------------------------------------------------------------------------------
-- The player's own choice, not the dev panel's: this one is open to everybody and therefore checks
-- everything. An Element has to exist AND be built; a Technique has to be in the pool AND come from a built
-- Element. Both are attributes, which is what the HUD, the viewmodel and the ability handler already read, so
-- nothing else has to know this remote exists.
-- v0.7 (2026-09-24): the Ultimate comes with the Element and is no longer a pick, so only the two Technique slots
-- ("Mobility" = Q, "Defense" = E, internal names) take a Technique -- any Technique, from either half of the pool,
-- but not one the Element may not hold (Detonate is Pyro's only) and not the one already in the other slot. A new
-- Element brings its default Techniques and swaps out any it may not hold (SpellshotConfig.ApplyElement).
local LOADOUT_ROLES = { Mobility = true, Defense = true }
local lastLoadoutAt = setmetatable({}, { __mode = "k" })

local toldLocked = setmetatable({}, { __mode = "k" })

loadoutRemote.OnServerEvent:Connect(function(p, what, a, b)
	local now = os.clock()
	if now - (lastLoadoutAt[p] or 0) < 0.08 then return end     -- a click is not 12 a second
	lastLoadoutAt[p] = now
	-- A SKIN (2026-10-10): ("Skin", abilityKey, skinId). Colour only, so it may change mid-match, a duel included (the
	-- next cast draws it). Only an ability of the player's own Element takes a skin (a borrowed Technique keeps Default:
	-- FLAGGED), the Id must be offered for it, and SkinCatalog.OwnsSkin must agree (the one place gating will go).
	if what == "Skin" then
		if not (type(a) == "string" and type(b) == "string") then return end
		local origin = SkinCatalog.Origin[a]
		if b ~= "Default" then
			local element = p:GetAttribute("Element") or Config.DefaultLoadout.Element
			if origin ~= element or not SkinCatalog.Allowed(origin, a, b) or not SkinCatalog.OwnsSkin(p, b) then return end
		end
		p:SetAttribute(SkinCatalog.Attr(a), b ~= "Default" and b or nil)
		return
	end
	-- AN ELEMENT'S SKIN (2026-10-13): ("ElementSkin", element, skinId) -- a whole rework, one per Element, for the
	-- player's own Element only. Like a wrap it may change mid-match (the next cast draws it).
	if what == "ElementSkin" then
		if not (type(a) == "string" and type(b) == "string" and Config.Elements[a]) then return end
		if b ~= "Default" then
			local element = p:GetAttribute("Element") or Config.DefaultLoadout.Element
			if a ~= element or not SkinCatalog.ElementSkinAllowed(a, b) or not SkinCatalog.OwnsSkin(p, b) then return end
		end
		p:SetAttribute(SkinCatalog.ElementSkinAttr(a), b ~= "Default" and b or nil)
		return
	end
	-- AN ELEMENT'S COLOUR WRAP (2026-10-15): ("ElementWrap", element, wrapId) -- over the Default shapes or the skin
	if what == "ElementWrap" then
		if not (type(a) == "string" and type(b) == "string" and Config.Elements[a]) then return end
		if b ~= "Default" then
			local element = p:GetAttribute("Element") or Config.DefaultLoadout.Element
			if a ~= element or not SkinCatalog.ElementWrapAllowed(a, b) or not SkinCatalog.OwnsSkin(p, b) then return end
		end
		p:SetAttribute(SkinCatalog.ElementWrapAttr(a), b ~= "Default" and b or nil)
		return
	end
	-- Locked for the whole of a duel (Build Prompt #24): the loadout is the same every round, and a swap would also refill
	-- a charge ability's stock mid-fight. Refused here, whatever a client's menu shows.
	if p:GetAttribute("Zone") == "Arena" and p:GetAttribute("DuelMatch") ~= nil then
		if now - (toldLocked[p] or 0) > 2 then
			toldLocked[p] = now
			local hub = folder:FindFirstChild("Hub")
			if hub then hub:FireClient(p, "notice", "Your loadout is locked until the duel is over.") end
		end
		return
	end
	if what == "Element" then
		if type(a) ~= "string" or not Config.Elements[a] or not Config.IsBuilt(a) then return end
		-- the Element you already are is no change: re-picking it must not reset your Techniques to its defaults
		if p:GetAttribute("Element") == a then return end
		-- OWNED ONLY (2026-10-18, economy): a locked Element is browsed in the menu, never equipped. Until the save loads,
		-- PlayerData answers with the starter kit, so a slow DataStore never locks anyone out of the starters.
		if not PlayerData.Owns(p, a) then
			local hub = folder:FindFirstChild("Hub")
			if hub then
				local price = Economy.PriceOf(a)
				hub:FireClient(p, "notice", not PlayerData.IsLoaded(p)
					and "Your Elements are still loading. Try again in a moment."
					or ("%s is locked%s."):format(string.upper(Config.Elements[a].Display or a),
						price and (": unlock it in the Loadout menu for " .. price .. " Sparks") or ""))
			end
			return
		end
		Config.ApplyElement(p, a)
	elseif what == "Technique" then
		if not (type(a) == "string" and LOADOUT_ROLES[a] and type(b) == "string") then return end
		local element = p:GetAttribute("Element") or Config.DefaultLoadout.Element
		if not Config.MayEquip(element, b) then return end              -- in the pool, built, and this Element's to hold
		local other = (a == "Mobility") and "Defense" or "Mobility"
		if (p:GetAttribute(other) or Config.DefaultLoadout[other]) == b then return end   -- never one in both slots
		p:SetAttribute(a, b)
	end
end)

Players.PlayerRemoving:Connect(function(p) state[p] = nil end)

----------------------------------------------------------------------------------------------------
-- cast requests
----------------------------------------------------------------------------------------------------
--- Mana cost and cooldown come from the ability definition, not from a table here, so the two
--- can never drift apart.
--- ...and it is the ability THIS player holds in that slot: the M1 and Primary Ability of their Element, the
--- Technique their loadout names (VFXLibrary.AbilityFor).
local function abilityForRole(p, role)
	return VFXLibrary.AbilityFor(p, role)
end

--- A refused charge cast spends nothing, and says so: the client flashes the slot, and CastSeq_
--- tells its prediction the request is no longer in flight.
local function refuseCharge(p, character, role, seq)
	settleSeq(p, character, role, seq)
	castRemote:FireClient(p, "Denied", role, seq)
end

--- A HELD ability's end, whoever ends it -- the player letting go, or the ability script at its longest hold
--- (ReleaseHold): the cooldown starts now, and the ability script hears the release. `client` is the letting-go
--- client's own payload (Cross-Slash Dash's launch rides on it; the ability script checks it), nil for ReleaseHold.
local function endHold(p, character, role, ability, client)
	if not (character and character.Parent) then return end
	character:SetAttribute("Holding_" .. role, nil)
	local s = getState(p)
	character:SetAttribute("CDTotal_" .. role, ability.Cooldown)
	character:SetAttribute("CD_" .. role, s.NoCooldowns and 0 or (workspace:GetServerTimeNow() + ability.Cooldown))
	performCast:Fire(p, role, ability, { Phase = "Release", Client = client })
end

releaseHold.Event:Connect(function(p, role)
	local character = p and p.Character
	if not (character and type(role) == "string") then return end
	local id = character:GetAttribute("Holding_" .. role)
	local ability = id and VFXLibrary.AbilityById[id]
	if ability then endHold(p, character, role, ability) end
end)

--- An ability script spending mana as it runs (Tremor Vault's drain underground). Free mana ignores it, as it
--- ignores a cast's cost.
spendMana.Event:Connect(function(p, amount)
	local character = p and p.Character
	if not (character and type(amount) == "number" and amount > 0) then return end
	local s = getState(p)
	if s.FreeMana then return end
	s.ManaFloat = math.max(0, s.ManaFloat - amount)
	character:SetAttribute("Mana", s.ManaFloat)
end)

--- A cast GIVEN BACK by the ability script: its cooldown cleared and its mana returned, so a cast that never
--- happened costs nothing (before this, Tremor Vault with nowhere to go kept the 15 and only gave the cooldown back).
--- (2026-10-18, umbra) a fourth argument, escape = true: the cast given back was the ESCAPE charge (UmbraHandler passes
--- payload.Escape), so the escape's own cooldown is cleared and the main one is left running.
giveBack.Event:Connect(function(p, role, ultToo, escape)
	local character = p and p.Character
	if not (character and type(role) == "string") then return end
	local ability = abilityForRole(p, role)
	if not ability then return end
	local s = getState(p)
	if not s.FreeMana then
		s.ManaFloat = math.min(Config.MaxMana, s.ManaFloat + (ability.ManaCost or 0))
		character:SetAttribute("Mana", s.ManaFloat)
	end
	if escape == true then
		character:SetAttribute("CDEscape_" .. role, 0)          -- (2026-10-18, umbra) the escape's charge back, never CD_
	else
		character:SetAttribute("CD_" .. role, 0)
	end
	-- ...and, when the script asks (ultToo: Detonate's, 2026-09-23), the Ultimate charge the cast added -- exactly what
	-- the generic path recorded it adding, so a give-back can neither farm the meter nor dent a ready Ultimate. Tremor
	-- Vault does not ask, and keeps what it always did.
	local added = ultToo == true and s.CastUlt and s.CastUlt[role]
	if added then
		s.CastUlt[role] = nil
		character:SetAttribute("UltCharge", math.clamp((character:GetAttribute("UltCharge") or 0) - added, 0, 1))
	end
	if ability.Held and character:GetAttribute("Holding_" .. role) == ability.Id then
		character:SetAttribute("Holding_" .. role, nil)        -- ...and it is not running, so the key works again
	end
end)

castRemote.OnServerEvent:Connect(function(p, role, payload)
	if type(role) ~= "string" then return end
	local ability = abilityForRole(p, role)
	payload = (type(payload) == "table") and payload or {}
	-- A charge cast is ANSWERED whatever becomes of it, even when it is turned away before the
	-- resource rules: the client counts the requests the server has not answered yet as charges
	-- already spent, so one dropped silently here would stay "in flight" on that client for good.
	-- Seq is a number the client counts up; the dev panel sends none, and none is simply no Seq.
	local chargeCast = ability ~= nil and ability.Charges ~= nil
	local seq = payload.Seq
	if not (type(seq) == "number" and seq == seq and math.abs(seq) < 2 ^ 31) then seq = nil end

	local character = p.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- WHAT IS ACTUALLY BEING HELD in this role, which is not always what the loadout says now: a Technique swap
	-- between the press and the release left the release matched against the NEW ability, so the key coming up
	-- silently cast that one -- paying its mana, stamping its cooldown, spending one of its charges -- while the old
	-- hold stayed up with nothing left to close it (2026-09-21). The held ability is the one the attribute names.
	local heldId = character and character:GetAttribute("Holding_" .. role)
	local heldAbility = heldId and VFXLibrary.AbilityById[heldId] or nil
	-- ...and a release or a steer belongs to THAT ability, never to the generic cast path below.
	local isRelease = heldAbility ~= nil and payload.Release ~= nil
	local isAim = heldAbility ~= nil and payload.Aim ~= nil and heldAbility.AimWhileHeld == true

	if p:GetAttribute("Zone") == "Hub"                     -- no casting in the Hub (HubServer)
		-- nor across a round reset: DuelMatch sets CastLocked over the window between ClearPlayer and the new body,
		-- where the old one is still alive in the Arena and anything cast would outlive the clear (2026-09-21)
		or p:GetAttribute("CastLocked")
		-- nor from underground (Tremor Vault). The exemption is NOT "any payload carrying Release or Aim": that was
		-- read before the role was dispatched, so ANY cast -- an M1, an Ultimate -- got through the gate just by
		-- attaching the field (2026-09-21). Only the held ability's own release and steering pass.
		or (character and character:GetAttribute("Burrowed") and not (isRelease or isAim))
		-- nor while Undertow's interrupt lasts (Aqua, 2026-09-24: InterruptedUntil, server time); a release still goes
		or (character and workspace:GetServerTimeNow() < (character:GetAttribute("InterruptedUntil") or 0)
			and not (isRelease or isAim))
		or not (humanoid and humanoid.Health > 0)
		or not (ability and ability.Implemented) then
		if chargeCast then refuseCharge(p, character, role, seq) end
		return
	end

	-- The release of a held ability is answered here, before any role branch, so that a swap mid-hold can never
	-- turn a key-up into a fresh cast of whatever now sits in the slot.
	-- ...but only for a HELD ability. A CHARGES ability sends its launch on a Release payload too (Cross-Slash
	-- Dash's `{ Release = true, Start, Dir, Dist }`), and that one belongs to the charge branch below.
	local heldRelease = payload.Release ~= nil and (heldAbility ~= nil or (ability ~= nil and ability.Held))
	local heldAim = payload.Aim ~= nil and (heldAbility ~= nil or (ability ~= nil and ability.Held))
	if heldRelease then
		if isRelease then endHold(p, character, role, heldAbility, payload) end
		return                          -- nothing held: a key-up is not a cast, whatever else is in the payload
	end
	if heldAim then
		if isAim and typeof(payload.Aim) == "Vector3" and payload.Aim.Magnitude < 1e4 then
			local s = getState(p)
			local aimNow = os.clock()
			if aimNow - (s.LastAim or 0) >= 1 / 30 then
				s.LastAim = aimNow
				performCast:Fire(p, role, heldAbility, { Phase = "Aim", Aim = payload.Aim })
			end
		end
		return                          -- ...and neither is a steer
	end
	local now = os.clock()
	local s = getState(p)

	if role == "Ultimate" then
		-- Dev free-Ultimate: skip the charge requirement and do not spend it. The heartbeat below
		-- pins the meter back to 1 anyway, so the HUD keeps reading READY and R stays castable.
		if not s.FreeUltimate then
			if (character:GetAttribute("UltCharge") or 0) < 1 then return end
			-- ChargeOnCatch (Earthen Tomb, 2026-09-19): the charge is CHECKED here and SPENT by the ability itself,
			-- only when it lands -- its fissure can be dodged, and a dodged Tomb costs nothing. Every other Ultimate
			-- (Cryo Beam among them) is paid for on the cast, as before.
			if not ability.ChargeOnCatch then character:SetAttribute("UltCharge", 0) end
		end
		performCast:Fire(p, role, ability, payload)
		return
	end

	-- M1 fires on a RATE: one shot per FireInterval (with slack for network jitter), and it does not
	-- feed the Ultimate per cast -- at three shots a second that would fill it in seconds. It costs a
	-- trickle of mana that, even at the full fire rate, is less than the regen; so it is never
	-- refused for want of mana: it takes what is there and the shot always goes.
	if role == "M1" then
		-- slack: a fifth of the interval, but never less than 50 ms, which a fast M1 (Wind Blade, 0.12 s) needs --
		-- one late packet is most of its interval. The slower M1s keep exactly the gate they had.
		local interval = ability.FireInterval or 0.2
		-- a faster M1 for a while (Umbra's Eclipse, 2026-09-27): M1RateMult on the character divides the interval
		local mult = character:GetAttribute("M1RateMult")
		if type(mult) == "number" and mult > 0 then interval /= mult end
		if now - (s.LastM1 or 0) < math.min(interval * 0.8, interval - 0.05) then return end
		s.LastM1 = now
		if not s.FreeMana then
			s.ManaFloat = math.max(0, s.ManaFloat - (ability.ManaCost or 0))
			character:SetAttribute("Mana", s.ManaFloat)
		end
		performCast:Fire(p, role, ability, payload)
		return
	end

	-- CHARGES (see "charges" above). The client has already begun the dash by the time this arrives,
	-- so the checks allow for what the server cannot see yet: 0.1 s of jitter on the ChargeGap, and
	-- 2 mana of grace for the M1 trickle whose spend has not replicated to the client (the spend
	-- then stops at an empty bar). A root or the Ultimate's hold (a speed cap of 0) refuses it, as
	-- does a channel -- ChannelingUlt, which AbilityHandler stamps on the character. That last clause
	-- read Channeling (2026-09-21), an attribute only the LocalScript ever writes: a client's write
	-- never reaches the server, so it was dead and the speed cap was doing the whole job by accident.
	if chargeCast then
		local c = chargeRecord(p, role)
		local serverNow = workspace:GetServerTimeNow()
		local cost = s.FreeMana and 0 or (ability.ManaCost or 0)
		local cap = math.min(character:GetAttribute("SpeedCapSlow") or math.huge,
			character:GetAttribute("SpeedCapUlt") or math.huge)
		-- Scorching Lash (Pyro, 2026-09-23) is the one charge ability that does not move the body: a whip is thrown
		-- standing still, so a speed cap of 0 -- which is there to stop a DASH -- does not refuse it, just as it refuses no
		-- cooldown cast. Its client (no DashMotor) sends it while rooted -- SpellshotInput.tryScorchingLash asks no speed
		-- cap either since review r1 (2026-09-24), when the two sides were found to disagree -- and a refusal here would
		-- leave that client drawing a whip whose strike then finds no lash. A channel still refuses it. (Should a root
		-- ever block the whip, it goes on BOTH sides together: `dashes` here and the cap check there.)
		local dashes = ability.Id ~= "ScorchingLash"
		if (c.Count < 1 and not s.NoCooldowns)
			or serverNow < c.LockUntil - 0.1
			or s.ManaFloat < cost - 2
			or (cap <= 0 and dashes)
			or character:GetAttribute("ChannelingUlt") == true then
			refuseCharge(p, character, role, seq)
			return
		end
		c.LockUntil = serverNow + (ability.ChargeGap or 0)
		-- dev no-cooldowns never spends a charge, but the ChargeGap still applies
		if not s.NoCooldowns then
			c.Count -= 1
			if c.NextAt == 0 then c.NextAt = serverNow + ability.Cooldown end
		end
		s.ManaFloat = math.max(0, s.ManaFloat - cost)
		character:SetAttribute("Mana", s.ManaFloat)
		publishCharges(character, role, c, ability)
		settleSeq(p, character, role, seq)
		-- a third of what a cooldown ability gives: three dashes are one cast's worth of meter
		character:SetAttribute("UltCharge", math.clamp((character:GetAttribute("UltCharge") or 0) + 0.02, 0, 1))
		performCast:Fire(p, role, ability, payload)
		return
	end

	-- HELD (Heat Rush, Gust Jump, Cross-Slash Dash): the key going down starts it and pays for it; the key coming up
	-- (payload.Release) ends it, and only then does the cooldown start. Holding_<role> says it is running -- for the
	-- ability script, and so a second press cannot start it twice.
	if ability.Held then
		-- The release (payload.Release) and the steer (payload.Aim, AimWhileHeld -- Tremor Vault's, which costs
		-- nothing and starts nothing) are both answered further up, against the ability the Holding_ attribute
		-- names rather than the one the loadout names now. All that is left here is a fresh press.
		if character:GetAttribute("Holding_" .. role) then return end
		if not s.NoCooldowns and workspace:GetServerTimeNow() < (character:GetAttribute("CD_" .. role) or 0) then return end
		local holdCost = s.FreeMana and 0 or (ability.ManaCost or 0)
		if s.ManaFloat < holdCost then return end
		-- PRECHECK on a held press too (2026-09-30, Benediction became held): asked exactly as the one-shot path below
		-- asks it, before anything is spent. A held press refused AFTER it is paid gets its mana and cooldown back
		-- (GiveBack) but never its Ultimate charge (a held press records no CastUlt), so without this a press that
		-- cannot plant -- mid-air, mashed -- was 6% of Ultimate for free.
		if ability.Precheck then
			local check = folder:FindFirstChild("Precheck_" .. ability.Id)
			local ok, yes = false, nil
			if check and check:IsA("BindableFunction") then
				ok, yes = pcall(check.Invoke, check, p, role, payload)
			end
			if not (ok and yes == true) then return end
		end
		s.ManaFloat -= holdCost
		character:SetAttribute("Mana", s.ManaFloat)
		character:SetAttribute("Holding_" .. role, ability.Id)
		character:SetAttribute("UltCharge", math.clamp((character:GetAttribute("UltCharge") or 0) + 0.06, 0, 1))
		performCast:Fire(p, role, ability, { Phase = "Start" })
		return
	end

	-- CD_ is stamped and checked in SERVER time; clients read it against the same clock.
	local serverNow = workspace:GetServerTimeNow()
	-- AN ESCAPE CHARGE (2026-10-18, umbra; handoff #8, the owner's "same key, second charge"). A row with EscapeCooldown > 0
	-- (Umbra's Shadow Step) holds a second, independent charge on the same key. While its own cooldown (CD_) runs and the
	-- escape's (CDEscape_<role>, server time) is ready, the press is the ESCAPE: the same cast, mana and Ultimate charge, but
	-- it starts CDEscape_ and leaves CD_ alone. Both ready: the normal cast, which starts CD_ as ever. Neither cooldown ever
	-- touches the other. payload.Escape tells the ability script which it was -- set here and only here, so a client's own
	-- Escape field never counts.
	local escape = false
	if not s.NoCooldowns and serverNow < (character:GetAttribute("CD_" .. role) or 0) then
		local esc = ability.EscapeCooldown
		if not (type(esc) == "number" and esc > 0 and serverNow >= (character:GetAttribute("CDEscape_" .. role) or 0)) then
			return
		end
		escape = true
	end
	payload.Escape = escape or nil
	--[[if not s.NoCooldowns and serverNow < (character:GetAttribute("CD_" .. role) or 0) then return end   until 2026-10-18]]
	local cost = s.FreeMana and 0 or (ability.ManaCost or 0)
	if s.ManaFloat < cost then return end
	-- PRECHECK (2026-09-23): an ability that can only run with something to act on (Precheck = true on its row; Detonate,
	-- which needs a target) asks its own script first, through Precheck_<Id>, and anything but a plain true refuses the
	-- press silently BEFORE a thing is spent -- no mana, no cooldown, no Ultimate charge. No such function, or a callback
	-- that errors, refuses too: it fails closed. It must not yield (Detonate's reads a table and answers).
	if ability.Precheck then
		local check = folder:FindFirstChild("Precheck_" .. ability.Id)
		local ok, yes = false, nil
		if check and check:IsA("BindableFunction") then
			ok, yes = pcall(check.Invoke, check, p, role, payload)
		end
		if not (ok and yes == true) then return end
	end
	s.ManaFloat -= cost
	character:SetAttribute("Mana", s.ManaFloat)
	if escape then
		-- the escape's own clock (2026-10-18, umbra); CD_ / CDTotal_ keep the main cooldown that is running
		character:SetAttribute("CDEscapeTotal_" .. role, ability.EscapeCooldown)
		character:SetAttribute("CDEscape_" .. role, serverNow + ability.EscapeCooldown)
	else
		character:SetAttribute("CDTotal_" .. role, ability.Cooldown)
		character:SetAttribute("CD_" .. role, s.NoCooldowns and 0 or (serverNow + ability.Cooldown))
	end
	-- casting an ability feeds the Ultimate a little, so the meter moves in normal play. What it ACTUALLY added (nothing,
	-- at a full meter) is kept per role, so a cast given back with its Ultimate charge (GiveBack) takes back exactly that
	-- and never a slice of an Ultimate that was already ready (2026-09-23)
	local ultBefore = character:GetAttribute("UltCharge") or 0
	local ultAfter = math.clamp(ultBefore + 0.06, 0, 1)
	character:SetAttribute("UltCharge", ultAfter)
	s.CastUlt = s.CastUlt or {}
	s.CastUlt[role] = ultAfter - ultBefore

	performCast:Fire(p, role, ability, payload)
end)

----------------------------------------------------------------------------------------------------
-- per-tick: mana regen, charge refill, passive conditions, status expiry
----------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local s = getState(p)

			-- mana regenerates passively (manual, Section 3)
			s.ManaFloat = math.min(Config.MaxMana, s.ManaFloat + Config.ManaRegenPerSecond * dt)
			character:SetAttribute("Mana", s.ManaFloat)

			-- health never comes back on its own (2026-09-16, on request): only a healing ability, a new
			-- body, or a HubServer move (to the Hub, or into a Solo Test) refills it

			-- dev: hold the Ultimate at ready so it never has to be farmed
			if s.FreeUltimate and (character:GetAttribute("UltCharge") or 0) < 1 then
				character:SetAttribute("UltCharge", 1)
			end
			if s.FreeMana and s.ManaFloat < Config.MaxMana then
				s.ManaFloat = Config.MaxMana
				character:SetAttribute("Mana", s.ManaFloat)
			end

			-- charges come back one at a time, each a full Cooldown after the one before (see
			-- "charges"); dev no-cooldowns holds the stock full, the way free mana holds the bar
			for role, c in pairs(s.Charges) do
				local ability = VFXLibrary.AbilityById[c.Id]
				local changed = false
				if s.NoCooldowns and c.Count < c.Max then
					c.Count, c.NextAt = c.Max, 0
					changed = true
				end
				while c.Count < c.Max and serverNow >= c.NextAt do
					c.Count += 1
					c.NextAt = (c.Count < c.Max) and (c.NextAt + ability.Cooldown) or 0
					changed = true
				end
				if changed then publishCharges(character, role, c, ability) end
			end

			-- status expiry
			local expires = character:GetAttribute("StatusExpires") or 0
			if expires > 0 and serverNow > expires then
				character:SetAttribute("Status", "")
				character:SetAttribute("StatusExpires", 0)
			end

			-- passive condition, per Element.
			-- Only the conditions the server can actually evaluate are driven here; the ones that
			-- depend on the target (Voltaic's "vs stationary targets", Umbra's "on unaware
			-- targets") belong to the damage pipeline and are left for that layer to set.
			-- (Radiant's launch passive Afterglow drove PassiveActive here -- "out of combat" as no damage taken for 5 s. It is
			-- retired with the rework, 2026-09-29: Overflow Light is RadiantHandler's, and PassiveProc marks it.)
		end
	end
end)
