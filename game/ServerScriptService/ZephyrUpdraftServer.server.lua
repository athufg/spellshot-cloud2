--[[
	ZephyrUpdraftServer  (Script)  ->  ServerScriptService/ZephyrUpdraftServer          Zephyr v6 import, 2026-10-06

	The gameplay side of UPDRAFT, Zephyr's Passive (design manual Section 2: "bonus damage and bonus knockback while
	airborne"). A Passive has no key and no cast path: nothing here listens to PerformCast. Every number is
	ZephyrUpdraft.Tuning (ReplicatedStorage.IceMagic.ZephyrUpdraft, shared with the client's tell), and every gameplay
	number there is PROVISIONAL (v6 import).

	  WHO HOLDS IT   ZephyrUpdraft.Holds: the player's Element is Zephyr and SpellshotConfig.PartialKits.Zephyr.Passive
	                 is true -- the Element decides the Passive (TerraHandler's isTerra for Bedrock). Every Heartbeat this
	                 mirrors the answer onto the CHARACTER as ZephyrPassive = "Updraft" (removed when not), the way
	                 Bedrock publishes Bedrock_Stacks: the server decides, one character attribute tells every client,
	                 and that is what ZephyrUpdraft's tell watches. An Element change in the Hub (no respawn) is picked up
	                 the next Heartbeat; a new body the first Heartbeat it exists.
	  AIRBORNE       ZephyrUpdraft.Airborne(character): MinClearance studs of air under the feet by a short downward sphere
	                 cast, and not climbing, swimming or seated. Each Heartbeat notes every holder that is airborne
	                 (ZephyrUpdraft.NoteAirborne), so a hit or a knock within AirGrace of it still counts. NOT air someone
	                 else put the body in (2026-10-19, audit P4-04: `thrown`, below): held by an Earthen Tomb (RX_Entombed),
	                 or still carried by a knock, a launch or an enemy Cyclone (KnockedUntil, server time, written by
	                 whoever threw it) -- crowd control must not buff its victim.
	  DAMAGE         CombatCore.AddModifier(ModifierPriority = -6): x DamageMult on every hit an airborne holder lands --
	                 after Mark (-10) and Toxin's amplifier (-8), before Bedrock (1), Bulwark Charge (5)
	                 and every soak, so a shield in front of the victim soaks the raised amount. Not a burn tick
	                 (info.DoT), a reaction's bonus, a chain or a status's damage (info.Reaction / Chain / Status:
	                 2026-10-19, audit P3-17), not the holder's own body, and not a hit whose info says NoUpdraft = true. A hit whose
	                 info carries UpdraftAir (a boolean: airborne at the shot's RELEASE) is judged by that instead of
	                 by the moment the hit lands -- Wind Blade's, whose report comes a flight and a round trip later.
	  THE HIT        CombatCore.OnHitLanded: a hit this modifier raised broadcasts UpdraftHit { Character = the holder's
	                 body, At = the victim's chest, T0 = server time, Victim = the victim's model } to everyone (the pulse
	                 that climbs the holder's body, the mark on the victim) -- at most one per HitPulseGap per player, so
	                 Wind Blade's eight a second do not restart the 0.25 s pulse before it reaches the top.
	  KNOCKBACK      not here: ZephyrHandler multiplies each Zephyr knockback by ZephyrUpdraft.KnockbackScale(player) when
	                 it sends it (the integration builder's wiring). This script's Heartbeat memory is what gives that
	                 call its AirGrace.

	Server -> client (AbilityFX, through ZephyrClient's merged Handlers): ("VFX", "UpdraftHit", data) on IceAbilityRemote.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local Updraft = require(iceFolder:WaitForChild("ZephyrUpdraft"))
local Core = require(script.Parent:WaitForChild("CombatCore"))

local T = Updraft.Tuning

--- (2026-10-19, audit P4-04) Air that is not the holder's own: an Earthen Tomb holds the body up on a pillar only the clients
--- draw (the server sees nothing under it), and a knock, a launch or an enemy Cyclone throws it. Each thrower stamps
--- KnockedUntil (server time) on the body for the throw and its fall; the Tomb's RX_Entombed lasts its whole hold.
local function thrown(character)
	return character:GetAttribute("RX_Entombed") == true
		or workspace:GetServerTimeNow() < (character:GetAttribute("KnockedUntil") or 0)
end

----------------------------------------------------------------------------------------------------
-- who holds it, and who is airborne (every Heartbeat)
----------------------------------------------------------------------------------------------------
-- The attribute is written only when it changes (Bedrock's lesson, 2026-09-21: comparing like for like, so a removed
-- attribute is not rewritten every frame). The airborne cast runs for holders only: one sphere cast each a Heartbeat.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.Parent then
			local holds = Updraft.Holds(player)
			local want = holds and "Updraft" or nil
			if character:GetAttribute(T.Attribute) ~= want then
				character:SetAttribute(T.Attribute, want)
			end
			if holds then
				local ok, air = pcall(Updraft.Airborne, character, false)
				if ok and air and not thrown(character) then Updraft.NoteAirborne(player, now) end
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- the damage bonus
----------------------------------------------------------------------------------------------------
-- [victim humanoid] = the caster whose hit this modifier just raised. DealDamage runs the modifiers and then the hit
-- listeners in the same call, so the listener below reads it back at once; keyed by the victim (not one slot) so a
-- listener that deals damage of its own in between cannot overwrite it.
local raised = setmetatable({}, { __mode = "k" })

Core.AddModifier(T.ModifierPriority, function(victim, amount, info, caster)
	raised[victim] = nil
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return amount end
	-- (2026-10-19, audit P3-17) nor a reaction's bonus, a chain's arc or a status's own damage: not the holder's shot
	if type(info) == "table" and (info.DoT or info.NoUpdraft or info.Reaction or info.Chain or info.Status) then return amount end
	local character = caster.Character
	if not character or victim.Parent == character then return amount end      -- never on your own body
	if not Updraft.Holds(caster) then return amount end
	-- WHEN the shooter was airborne: a shot that knows (info.UpdraftAir, snapshotted at its release -- ZephyrHandler's
	-- Wind Blade) is judged by that, not by now. Its hit is reported a flight and a round trip after the blade left the
	-- hand (up to 0.33 s + ping), far past AirGrace: judged at the hit, a blade thrown in the air just before landing lost
	-- the bonus, and one thrown from the floor just before a jump got it.
	local air = type(info) == "table" and info.UpdraftAir
	-- (a release's snapshot already asked `thrown`: ZephyrHandler.updraftAirborne)
	if type(air) ~= "boolean" then air = Updraft.IsAirborne(caster) and not thrown(character) end
	if not air then return amount end
	raised[victim] = caster
	return amount * T.DamageMult
end)

----------------------------------------------------------------------------------------------------
-- the aerial hit's broadcast
----------------------------------------------------------------------------------------------------
local lastPulse = setmetatable({}, { __mode = "k" })     -- [player] = os.clock() of the last UpdraftHit

Core.OnHitLanded(function(caster, humanoid, amount, info)
	if raised[humanoid] ~= caster then return end
	raised[humanoid] = nil
	local character = typeof(caster) == "Instance" and caster.Character
	if not character then return end
	local now = os.clock()
	if now - (lastPulse[caster] or -math.huge) < T.HitPulseGap then return end
	lastPulse[caster] = now
	local model = humanoid.Parent
	local part = model and (model:FindFirstChild("HumanoidRootPart") or (model:IsA("Model") and model.PrimaryPart))
	Core.Broadcast("UpdraftHit", {
		Character = character,
		At = part and (part.Position + Vector3.new(0, 0.2, 0)) or nil,   -- the chest (the kit's hit point, 3.2 over the floor)
		T0 = workspace:GetServerTimeNow(),
		Victim = model,
	})
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
-- Everything above is keyed weakly (players, humanoids) and holds no state a clear or a death has to end: a body that
-- dies stops being airborne by itself (Airborne asks for a living Humanoid), and a new body gets its attribute on the
-- first Heartbeat. Leaving: nothing to drop.
Players.PlayerRemoving:Connect(function(player)
	lastPulse[player] = nil
end)
