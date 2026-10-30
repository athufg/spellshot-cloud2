--[[
	VoltaicHandler  (Script)  ->  ServerScriptService/VoltaicHandler

	The gameplay side of VOLTAIC (2026-09-25; the castable build: D:\voltkit_scratch\design.md sections 2a and 3 with the
	critique's corrections, bound by castable\CONTRACT.md). VoltaicClient is its client half; ChainBoltFX, OverchargeFX,
	RailspikeFX, VoltOrbFX and VoltaicFX (Cascade) draw it. Every number is VoltaicTuning's (ReplicatedStorage.IceMagic,
	pure data, the same table the clients read) except Cascade's clock and zone, which are VoltaicFX.Tuning.Cascade's --
	the render's own numbers, read here so the bolts land on the frames the storm draws them. Every number is a STAND-IN.

	  M1        CHAIN BOLT      hitscan, Range studs. The shooter's client spherecasts on the click and claims what it hit
	                            (ChainBoltFire: its eye, its aim, the part and the point). This checks the claim Wind Blade's
	                            way -- the fire-rate bucket, the eye against the server's head, the point on the line,
	                            CheckTarget and Blocked, each with its second chance -- and then the bolt CHAINS: from the
	                            body it hit to the nearest other enemy within ChainRadius that nothing solid hides, ChainLegs
	                            jumps (PrimedLegs while primed). Every body it damages takes a stack of CHARGED
	                            (StatusEffects). The damage is immediate; only the drawing of each jump is delayed (the
	                            clients, ChainDelay). A whiff is still a shot: it ends where the server's own ray stops.
	                            The M1's CastRequest (rate, mana, the relay) is SpellshotService's; this ignores it.
	  PRIMARY   OVERCHARGE      a short dash -- the caster's client moves the body (DashMotor, Bulwark Charge's arrangement;
	                            the server cannot verify the path) -- that PRIMES the next Chain Bolt for PrimedFor:
	                            VoltPrimedUntil (server time) and one HUD pip (StacksMax_Primary / Stacks_Primary). The tell
	                            is told to everyone TellDelay after the dash (OverchargePrimed). ANY M1 fired while primed
	                            spends it, a whiff and a refused shot included: the caster's client drops its tell on the
	                            fire frame, so the server does too. The cap, a loadout change, death and a clear end it.
	  PASSIVE   CHAIN REACTION  Charged filling on a target takes MaxStackCut s off Overcharge's cooldown (2026-10-17; with
	                            Trigger "Kill", the rule before: a kill takes Share of it off whatever is left of it, Pyro's
	                            Ember Refund, in shape). PassiveProc marks the moment; ChainReaction tells everyone.
	  TECHNIQUE RAILSPIKE       a fixed ChargeTime windup on the press (RailspikeChargeStart); then the caster's client fires
	                            a piercing line of Range and claims up to MaxPierce bodies on it (RailspikeFire). Checked
	                            against the windup this side timed, the eye, the line (clipped by the server's own world),
	                            CheckTarget and Blocked. A windup its caster cannot finish -- death, an interrupt (CanAct,
	                            every Heartbeat), a clear, a loadout change, GiveUp with no shot -- is stopped for everyone
	                            (RailspikeChargeStop). Nothing is refunded. A second press while one is live is ignored.
	  TECHNIQUE VOLT ORB        a lob. The throw leaves the hand ReleaseAt after the press; this steps the same deterministic
	                            arc every Heartbeat with a swept sphere (HitRadius) against anything solid, and bursts it on
	                            contact or at the Fuse (VoltOrbBurst). StrikeDelay later the burst hurts every enemy within
	                            DamageRadius it can see: CenterDamage falling to EdgeDamage at the edge (by flat distance to
	                            the root), plus DirectBonus on a body it touched. One live orb per caster: a new throw fizzles
	                            the old. The caster dying or being interrupted before the release drops it (VoltOrbFizzle);
	                            once thrown it flies on.
	  ULTIMATE  CASCADE         pointed: the charge is spent on the cast (SpellshotService). A storm gathers over the
	                            crosshair's ground spot, then five bolts strike at VoltaicFX's Strikes times -- each on the
	                            enemy under it struck fewest times so far (ties to the nearest), or on a fixed filler point
	                            when nobody is there. A strike that kills pops ARCSTORM!. No ground under the spot: nothing
	                            happens, and the charge is given back. Its caster dying does not cancel a placed storm; a
	                            clear does (CascadeEnd).

	TIME: every delay and window here is divided by VFXLibrary.ShotTimeScale() (0.25 = quarter speed, the slow-motion
	review), and the Volt Orb's flight runs on shot time ((now - ReleaseAt) * scale), as the clients' clocks do. The scale
	is sampled once per cast, so a change mid-cast cannot jump a clock.

	WHERE CASTS COME FROM: SpellshotService checks and pays for the cast, then fires PerformCast; the role rides along as a
	sixth argument (Pyro's arrangement) for a cast that has to hand itself back (Overcharge's GiveBack). Each kit's script
	acts only on its own ability Ids. Damage goes through CombatCore, so shields, Mark, Blessing and the Ultimate charge all
	apply as for every other kit.

	Server -> client (AbilityFX -> VoltaicClient.Handlers): ("VFX", kind, data) on IceAbilityRemote, to everyone:
	  ChainBolt, Overcharge, OverchargePrimed, ChainReaction, RailspikeChargeStart / RailspikeChargeStop / RailspikeShot,
	  VoltOrbThrow / VoltOrbBurst / VoltOrbFizzle, CascadeGather / CascadeStrike / CascadeEnd.
	Client -> server (IceAbilityRemote): ChainBoltFire, RailspikeFire.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local T = require(iceFolder:WaitForChild("VoltaicTuning"))       -- pure data; the clients read the same table
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local giveBack = spellFolder:WaitForChild("GiveBack")            -- (player, role, true): the cast and its Ultimate charge back
local addUltCharge = spellFolder:WaitForChild("AddUltCharge")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Core = require(script.Parent:WaitForChild("CombatCore"))
local Status = require(script.Parent:WaitForChild("StatusEffects"))

local remote = Core.Remote
local broadcast = Core.Broadcast
local ABILITY = VFXLibrary.AbilityById

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[VoltaicHandler] " .. tostring(msg))
end

-- The ARCSTORM! pop goes through the same module StatusEffects' pops do. Guarded: a word is not worth the kit.
local Callouts = nil
do
	local ok, mod = pcall(function()
		return require(spellFolder:WaitForChild("Callouts", 10))
	end)
	if ok and type(mod) == "table" then
		Callouts = mod
	else
		warnOnce("callouts", "Callouts unavailable, Cascade kills will not pop ARCSTORM!: " .. tostring(mod))
	end
end

--- Whether the ability `player` holds in `role` is the one named.
local function holds(player, role, id)
	local a = VFXLibrary.AbilityFor(player, role)
	return a ~= nil and a.Id == id
end

--- Which Technique slot ("Mobility" = Q, "Defense" = E) holds Technique `id`, or nil (v0.7: either slot holds any).
local function techSlot(player, id)
	return VFXLibrary.TechniqueSlot(player, id)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function timeScale()
	return VFXLibrary.ShotTimeScale()
end

local function pingOf(player)
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	return ping
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

--- A body `player`'s Voltaic may pick and hurt: none of their own (the body they cast with, or the one they have now),
--- no Bulwark Wall (cover, not a body), nobody friendly (a teammate, or anyone Config.MayHurt rules out).
local function isEnemyBody(player, model, casterChar)
	return model ~= nil and model ~= casterChar and model ~= player.Character and not Core.IsWall(model)
		and not Core.IsFriendly(player, model)
end

--- The claimed eye has to be the shooter's own: near where the server has their head, allowing for the server's copy
--- of a moving player trailing the real one (Icicle Shard's and Wind Blade's rule).
local function eyeNear(player, character, humanoid, root, origin)
	local head = character:FindFirstChild("Head")
	local speed = Core.TrailSpeed(root, humanoid.WalkSpeed)
	local allowance = T.ChainBolt.OriginSlack + speed * (0.35 + Core.Lag(pingOf(player)))
	return (origin - (head and head.Position or root.Position)).Magnitude <= allowance
end

--- Raycast params that see the world: every player's body, the FX folder and `extra` (a list) left out.
local function worldParams(extra, respectCollide)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = respectCollide == true
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	if extra then
		for _, inst in ipairs(extra) do exclude[#exclude + 1] = inst end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

--- A ray that sees through every body (a character, a training dummy) but not a Bulwark Wall, which is cover.
local function castThroughBodies(origin, direction, params)
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) or model:GetAttribute("WallOwner") then return hit end
		params:AddToFilter(model)
	end
	return nil
end

--- The floor straight down from `from` (through bodies, solid parts only), or nil within `reach`.
local function groundBelow(from, reach)
	local hit = castThroughBodies(from, Vector3.new(0, -reach, 0), worldParams(nil, true))
	return hit and hit.Position or nil
end

--- (2026-10-19, audit P1-09) LINE OF SIGHT for an aimed spot (ZephyrGustPadServer's sightPoint, copied): the honest client
--- can only pick a spot its camera sees, so the server asks the same -- from the caster's eye to the spot, or to a point a
--- few studs over it (low cover in front of the spot does not hide it), nothing solid in between. Bodies never count; a
--- Bulwark Wall does (Core.Blocked's rule). Returns the spot when seen, else the point just short of the first thing in the way.
local SIGHT_RISES = { 0.5, 3, 5 }
local function sightPoint(character, root, spot)
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
	return stop
end

local function onPart(part, position, pad)
	local lp = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2 + Vector3.new(pad, pad, pad)
	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

local function validClaimPart(part, position)
	return typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(workspace)
		and Core.ValidVector(position)
end

--- Core.CheckTarget with Wind Blade's SECOND CHANCE: WasThere measures from the ROOT with 4.5 studs of reach, so a
--- contact on an outstretched limb, a raised head or a scaled avatar can sit outside it and still be real. The claimed
--- part IS the body part, so it is asked directly. -> nil, model, humanoid on success, or the rejection reason.
local function checkClaim(part, position, shooterCharacter)
	local reason, model, humanoid = Core.CheckTarget(part, position, shooterCharacter)
	if reason == "rej_moved" and onPart(part, position, 1) then
		reason = nil
		model = part:FindFirstAncestorOfClass("Model")
		humanoid = model and model:FindFirstChildOfClass("Humanoid")
		Core.CountShot("save_moved")
	end
	return reason, model, humanoid
end

--- Core.Blocked with Wind Blade's SECOND CHANCE: the line was drawn from the eye the CLIENT claimed; where the server has
--- the shooter's own head is the one point it is sure of. true = blocked from both.
local function claimBlocked(shot, along, position, skip)
	if not Core.Blocked(shot, along, skip) then return false end
	local head = shot.Character:FindFirstChild("Head")
	if head then
		local rel = position - head.Position
		local d = rel.Magnitude
		if d > 0.5 and not Core.Blocked({ Origin = head.Position, Dir = rel / d, Character = shot.Character }, d, skip) then
			Core.CountShot("save_blocked")
			return false
		end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local buckets = {}   -- [player] = { Tokens, At }: Chain Bolt's fire-rate check
local primed = {}    -- [player] = { Character, Until (server time), Epoch }: Overcharge's primed Chain Bolt
local rails = {}     -- [player] = { Character, T0, Clock, Scale, Role, Epoch }: a Railspike windup
local orbs = {}      -- [player] = { Character, From, Vel, T0, ReleaseAt, Scale, Last, First, Epoch, Seed }: the live orb
local storms = {}    -- [storm] = true; storm = { Player, Character, Point, T0, Scale, Epoch, Count, Done, Ended, Clock }
local seeds = Random.new()

local PIPS = 1       -- the primed read on the HUD: one lit pip in the Primary slot (PopArtHUD's Stacks_ contract)

----------------------------------------------------------------------------------------------------
-- PRIMARY: OVERCHARGE's primed state (the Chain Bolt below spends it)
----------------------------------------------------------------------------------------------------
local function isPrimed(player, character)
	local p = primed[player]
	return p ~= nil and p.Character == character and Core.Epoch(player) == p.Epoch and serverNow() < p.Until
end

--- Ends `player`'s prime. reason "Consumed": the Chain Bolt that spent it already tells everyone (ChainBolt.Primed);
--- every other end (the cap, a loadout change, death, a clear, a refused shot, leaving) tells them with On = false.
local function clearPrimed(player, reason)
	local p = primed[player]
	if not p then return end
	primed[player] = nil
	local character = p.Character
	if character then
		if character:GetAttribute("VoltPrimedUntil") == p.Until then character:SetAttribute("VoltPrimedUntil", nil) end
		-- the pips only while they still read as ours: after an Element change the new kit's own refresh owns them
		-- (PyroHandler.refreshKit writes Immolate's on the same change), and they must not be wiped from under it.
		-- The max alone is our marker (Immolate's is T.Immolate.Stacks = 3): the lit count is not, since PyroHandler's
		-- own Core.OnClear zeroes Stacks_Primary on any body that carries it, and may run before ours.
		if character:GetAttribute("StacksMax_Primary") == PIPS then
			character:SetAttribute("StacksMax_Primary", nil)
			character:SetAttribute("Stacks_Primary", nil)
		end
	end
	if reason ~= "Consumed" then
		broadcast("OverchargePrimed", { Character = character, On = false })
	end
end

local function setPrimed(player, character, untilT)
	local p = { Character = character, Until = untilT, Epoch = Core.Epoch(player) }
	primed[player] = p
	character:SetAttribute("VoltPrimedUntil", untilT)
	character:SetAttribute("StacksMax_Primary", PIPS)
	character:SetAttribute("Stacks_Primary", PIPS)
	-- the tell shows TellDelay after the dash (as the dash lands); a prime spent or ended before then never shows it
	task.delay(T.Overcharge.TellDelay / timeScale(), function()
		if primed[player] ~= p or Core.Epoch(player) ~= p.Epoch then return end
		broadcast("OverchargePrimed", { Character = character, On = true, Until = untilT })
	end)
end

local function castOvercharge(player, character, humanoid, root, payload, role)
	local O = T.Overcharge
	-- where the dash started: the client's claim, if the server's copy of the body could have been there. Anything else
	-- is a dash that never happened here: the cast is handed back whole.
	local start = payload.Start
	local speed = Core.TrailSpeed(root, humanoid.WalkSpeed)
	if not Core.ValidVector(start) or (start - root.Position).Magnitude > O.StartSlack + speed * (0.35 + Core.Lag(pingOf(player))) then
		giveBack:Fire(player, role or "Primary", true)
		return
	end
	local dir = Core.ValidVector(payload.Dir) and flat(payload.Dir) or Vector3.zero
	if dir.Magnitude < 0.1 then dir = flat(root.CFrame.LookVector) end
	if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, -1) end
	dir = dir.Unit
	local dist = payload.Dist
	if type(dist) ~= "number" or dist ~= dist then dist = O.Distance end
	dist = math.clamp(dist, 0, O.Distance + 1)
	local now = serverNow()
	broadcast("Overcharge", { Character = character, From = start, To = start + dir * dist, T0 = now })
	setPrimed(player, character, now + O.PrimedFor / timeScale())
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: CHAIN REACTION
----------------------------------------------------------------------------------------------------
-- "A kill refunds 30% of Overcharge's cooldown": a Voltaic's kill, by anything, takes Share of Overcharge's full cooldown
-- off what is left of it. PassiveProc (server time) marks the moment; every client sparks the hands from the broadcast.
-- Only while the Passive is built (SpellshotConfig.PartialKits): the loadout keeps it locked until then.
Core.OnKill(function(caster, humanoid)
	if T.ChainReaction.Trigger ~= nil and T.ChainReaction.Trigger ~= "Kill" then return end   -- 2026-10-17: see below
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	if not holds(caster, "Primary", "Overcharge") then return end
	if Config.IsPartBuilt and not Config.IsPartBuilt("Voltaic", "Passive") then return end
	local character = caster.Character
	if not (character and character.Parent) then return end
	if humanoid and humanoid.Parent == character then return end        -- not by taking yourself out
	local now = serverNow()
	local row = ABILITY.Overcharge
	local cooldown = (row and row.Cooldown) or T.Overcharge.Cooldown or 9
	local readyAt = character:GetAttribute("CD_Primary") or 0
	local newReady = readyAt
	if readyAt > now then
		newReady = math.max(now, readyAt - T.ChainReaction.Share * cooldown)
		character:SetAttribute("CD_Primary", newReady)
	end
	character:SetAttribute("PassiveProc", now)
	broadcast("ChainReaction", { Character = character, Ready = newReady <= now })
end)

-- The duel trigger (2026-10-17, the owner's pick): a kill ends a duel round, so the kill rule never paid out there.
-- Every time Charged fills on a target (StatusEffects calls OnChargedFull as it goes off), MaxStackCut seconds come off
-- what is left of Overcharge's cooldown.
Status.OnChargedFull = function(caster, humanoid)
	if T.ChainReaction.Trigger ~= "MaxStacks" then return end
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	if not holds(caster, "Primary", "Overcharge") then return end
	if Config.IsPartBuilt and not Config.IsPartBuilt("Voltaic", "Passive") then return end
	local character = caster.Character
	if not (character and character.Parent) then return end
	local now = serverNow()
	local readyAt = character:GetAttribute("CD_Primary") or 0
	local newReady = readyAt
	if readyAt > now then
		newReady = math.max(now, readyAt - T.ChainReaction.MaxStackCut)
		character:SetAttribute("CD_Primary", newReady)
	end
	character:SetAttribute("PassiveProc", now)
	broadcast("ChainReaction", { Character = character, Ready = newReady <= now })
end

----------------------------------------------------------------------------------------------------
-- M1: CHAIN BOLT
----------------------------------------------------------------------------------------------------
--- One Chain Bolt per FireInterval on average. Wind Blade's bucket: it earns a bolt 8% sooner than the client may fire
--- one and holds Bucket, so ordinary jitter is never thrown away and only genuine over-rate is refused.
local function takeToken(player)
	local C = T.ChainBolt
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { Tokens = C.Bucket - 1, At = now }
		buckets[player] = b
	end
	local row = ABILITY.ChainBolt
	local interval = ((row and row.FireInterval) or 0.32) * 0.92 / timeScale()
	b.Tokens = math.min(C.Bucket, b.Tokens + (now - b.At) / interval)
	b.At = now
	if b.Tokens < 1 then return false end
	b.Tokens -= 1
	return true
end

--- Where a bolt that claimed nothing ends: the server's own world along the aim (bodies seen through), or full range.
local function whiffEnd(origin, dir, range, character)
	local hit = castThroughBodies(origin, dir * range, worldParams({ character }))
	return hit and hit.Position or (origin + dir * range)
end

--- THE CHAIN. From `first` (the body the bolt hit), `legs` jumps, each to the nearest enemy body within ChainRadius of the
--- last one (by root distance -- HumanoidsNear matches any part) that nothing solid hides from it and the bolt has not
--- already hit. Each takes ChainDamage and a Charged stack. Appends to `hits` / `points` in order.
local function chainFrom(player, character, first, legs, hitSet, hits, points)
	local C = T.ChainBolt
	local prev = first
	for _ = 1, legs do
		local prevRoot = rootOf(prev)
		if not prevRoot then return end
		local from = prevRoot.Position
		local candidates = {}
		for hum, model in pairs(Core.HumanoidsNear(from, C.ChainRadius, prev)) do
			if not hitSet[model] and hum.Health > 0 and isEnemyBody(player, model, character) then
				local r = rootOf(model)
				if r then
					candidates[#candidates + 1] = { Model = model, Humanoid = hum, Root = r, D = (r.Position - from).Magnitude }
				end
			end
		end
		table.sort(candidates, function(x, y) return x.D < y.D end)
		local nextBody = nil
		for _, c in ipairs(candidates) do
			local rel = c.Root.Position - from
			local d = rel.Magnitude
			local clear = d < 0.5 or not Core.Blocked({ Origin = from, Dir = rel / d, Character = prev }, d, c.Model)
			if clear then
				hitSet[c.Model] = true
				if Core.DealDamage(player, c.Humanoid, C.ChainDamage,
					{ Ranged = true, From = from, Chain = true, Source = "ChainBolt" }) then
					if C.Charged then pcall(Status.Apply, player, c.Humanoid, "Charged") end
					hits[#hits + 1] = c.Model
					points[#points + 1] = c.Root.Position
					nextBody = c.Model
					break
				end
			end
		end
		if not nextBody then return end
		prev = nextBody
	end
end

-- The click: the shooter's eye, aim and what its spherecast hit. Checked, applied, chained, then told to everyone. The
-- outcome names are CombatCore's (ServerStorage.ShotStats).
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "ChainBoltFire" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "ChainBolt") then return end
	local character, humanoid, root = Core.CanAct(player)       -- not from underground, not across a round reset
	if not character then return end
	local origin, dir = a.Origin, a.Dir
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	local C = T.ChainBolt

	-- THE PRIME is spent by this shot whatever becomes of it: the shooter's client dropped its tell on the fire frame
	local wasPrimed = isPrimed(player, character)
	if not takeToken(player) then
		Core.CountShot("rej_rate")
		if wasPrimed then clearPrimed(player, "Refused") end
		return
	end
	if not eyeNear(player, character, humanoid, root, origin) then
		Core.CountShot("rej_origin")
		if wasPrimed then clearPrimed(player, "Refused") end
		return
	end
	-- only a PAID bolt fires (2026-10-19, audit P1-12 / GC-14): the client sends its M1 CastRequest first (VoltaicClient),
	-- so the bolt's mana has been taken by the time this arrives; one that skipped it deals nothing
	if not Core.TakePaidM1(player) then
		Core.CountShot("rej_unpaid")
		if wasPrimed then clearPrimed(player, "Refused") end
		return
	end
	if wasPrimed then clearPrimed(player, "Consumed") end
	Core.CountShot("release")

	local hits, points, hitSet = {}, {}, {}
	local endPos = nil
	local chainStart = nil
	local part, position = a.Part, a.Position
	if part ~= nil then
		if not validClaimPart(part, position) then
			Core.CountShot("rej_badpart")
		else
			-- on the line, inside its range ...
			local rel = position - origin
			local along = rel:Dot(dir)
			if along < -0.5 or along > C.Range + 1.5 or (rel - dir * along).Magnitude > C.HitSlack then
				Core.CountShot("rej_offline")
			else
				-- ... on the thing claimed, and nothing solid between
				local reason, model, hum = checkClaim(part, position, character)
				if reason then
					Core.CountShot(reason)
				elseif claimBlocked({ Origin = origin, Dir = dir, Character = character }, math.max(along, 0), position,
					hum and model or part) then
					Core.CountShot("rej_blocked")
				else
					Core.CountShot("hit")
					endPos = position
					if hum then
						Core.CountShot("hit_char")
						hitSet[model] = true
						local before = hum.Health
						if Core.DealDamage(player, hum, C.Damage, { Ranged = true, From = origin, Source = "ChainBolt" }) then
							if hum.Health >= before then Core.CountShot("dmg_soaked") end
							hits[#hits + 1] = model
							if C.Charged then pcall(Status.Apply, player, hum, "Charged") end
							-- a Bulwark Wall takes the hit (every kit's hits damage it) but is cover: no chain leaves it
							if not Core.IsWall(model) then chainStart = model end
						else
							Core.CountShot("rej_friendly")
						end
					else
						Core.CountShot("hit_world")
					end
					Core.ShotImpact:Fire(part, position, player)
				end
			end
		end
	end
	if not endPos then endPos = whiffEnd(origin, dir, C.Range, character) end
	points[1] = endPos
	if chainStart then
		chainFrom(player, character, chainStart, wasPrimed and C.PrimedLegs or C.ChainLegs, hitSet, hits, points)
	end
	broadcast("ChainBolt", {
		Character = character, Origin = origin, Dir = dir, Side = (a.Side == "L") and "L" or "R",
		End = endPos, Hits = hits, Points = points, Primed = wasPrimed, T0 = serverNow(),
	})
end)

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: RAILSPIKE
----------------------------------------------------------------------------------------------------
local function stopRail(player, reason)
	local r = rails[player]
	if not r then return end
	rails[player] = nil
	broadcast("RailspikeChargeStop", { Character = r.Character })
end

local function castRailspike(player, character, humanoid, root, payload, role)
	local live = rails[player]
	-- a second press while a windup runs is ignored: the first one keeps its clock (a LocalCast cannot stop the request)
	if live and live.Character == character and live.Epoch == Core.Epoch(player) then return end
	if live then stopRail(player, "Replaced") end
	local now = serverNow()
	rails[player] = {
		Character = character, T0 = now, Clock = os.clock(), Scale = timeScale(), Role = role, Epoch = Core.Epoch(player),
	}
	broadcast("RailspikeChargeStart", { Character = character, T0 = now })
end

-- The shot: the shooter's eye, aim, the bodies its pierce ray passed through ({ Part, Position } each) and where it stopped.
remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "RailspikeFire" or type(a) ~= "table" then return end
	local rail = rails[player]
	if not rail then
		Core.CountShot("rej_noshot")
		return
	end
	local R = T.Railspike
	local character, humanoid, root = Core.CanAct(player)
	if not character or character ~= rail.Character or rail.Epoch ~= Core.Epoch(player)
		or player:GetAttribute("Zone") == "Hub" or not techSlot(player, "Railspike") then
		stopRail(player, "Refused")
		return
	end
	-- the windup, as this side timed it from the press (both ends scaled: a slowed review fires late on purpose)
	local elapsed = os.clock() - rail.Clock
	if elapsed < R.ChargeTime / rail.Scale - R.EarlySlack then
		Core.CountShot("rej_early")
		stopRail(player, "Refused")
		return
	end
	if elapsed > (R.ChargeTime + R.GiveUp) / rail.Scale then
		Core.CountShot("rej_late")
		stopRail(player, "Refused")
		return
	end
	local origin, dir = a.Origin, a.Dir
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or dir.Magnitude < 0.1 then
		stopRail(player, "Refused")
		return
	end
	dir = dir.Unit
	if not eyeNear(player, character, humanoid, root, origin) then
		Core.CountShot("rej_origin")
		stopRail(player, "Refused")
		return
	end
	rails[player] = nil                                   -- the windup is spent by this shot
	Core.CountShot("release")

	-- HOW FAR IT WENT: the server's own world along the aim (bodies seen through, a Bulwark Wall stops it), shortened to
	-- the client's claimed end when that sits on the line -- a client may only ever shorten its own shot
	local wallHit = castThroughBodies(origin, dir * R.Range, worldParams({ character }))
	local worldDist = wallHit and math.max(0, (wallHit.Position - origin):Dot(dir)) or R.Range
	local dist = worldDist
	if Core.ValidVector(a.End) then
		local rel = a.End - origin
		local along = rel:Dot(dir)
		if along >= 0 and along <= R.Range and (rel - dir * along).Magnitude <= 1 then
			dist = math.min(along, worldDist)
		end
	end

	-- the claimed bodies, each checked alone: on the line and short of where it stopped, on the body, nothing solid
	-- between; each body once, MaxPierce at most
	local shot = { Origin = origin, Dir = dir, Character = character }
	local list = type(a.Hits) == "table" and a.Hits or {}
	local accepted, seen = {}, {}
	for i = 1, math.min(#list, R.MaxPierce * 2) do
		if #accepted >= R.MaxPierce then break end
		local h = list[i]
		local part = type(h) == "table" and (h.Part or h[1]) or nil
		local position = type(h) == "table" and (h.Position or h[2]) or nil
		if not validClaimPart(part, position) then
			Core.CountShot("rej_badpart")
		else
			local rel = position - origin
			local along = rel:Dot(dir)
			if along < -1 or along > dist + 1 or (rel - dir * along).Magnitude > R.HitSlack then
				Core.CountShot("rej_offline")
			else
				local reason, model, hum = checkClaim(part, position, character)
				if reason then
					Core.CountShot(reason)
				elseif not hum then
					Core.CountShot("hit_world")                -- a rail claims bodies; the world is where it stopped
				elseif seen[model] then
					Core.CountShot("rej_repeat")
				elseif claimBlocked(shot, math.max(along, 0), position, model) then
					Core.CountShot("rej_blocked")
				else
					seen[model] = true
					accepted[#accepted + 1] = { Model = model, Humanoid = hum, Part = part, Position = position, Along = along }
				end
			end
		end
	end
	table.sort(accepted, function(x, y) return x.Along < y.Along end)
	local hits, points = {}, {}
	for _, h in ipairs(accepted) do
		Core.CountShot("hit")
		Core.CountShot("hit_char")
		local before = h.Humanoid.Health
		if Core.DealDamage(player, h.Humanoid, R.Damage, { Ranged = true, From = origin, Source = "Railspike" }) then
			if h.Humanoid.Health >= before then Core.CountShot("dmg_soaked") end
			hits[#hits + 1] = h.Model
			points[#points + 1] = h.Position
		else
			Core.CountShot("rej_friendly")
		end
		Core.ShotImpact:Fire(h.Part, h.Position, player)
	end
	-- the rail's end on a wall or a board marks it, as an M1's impact does
	if wallHit and dist >= worldDist - 0.05 then Core.ShotImpact:Fire(wallHit.Instance, wallHit.Position, player) end
	broadcast("RailspikeShot", {
		Character = character, Origin = origin, Dir = dir, Dist = dist, Hits = hits, Points = points, T0 = serverNow(),
	})
end)

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: VOLT ORB
----------------------------------------------------------------------------------------------------
--- Drops `player`'s live orb with no burst. At: where it was, once thrown (nil in the hand).
local function fizzle(player, reason)
	local orb = orbs[player]
	if not orb then return end
	orbs[player] = nil
	local thrown = serverNow() >= orb.ReleaseAt and not orb.First
	broadcast("VoltOrbFizzle", { Character = orb.Character, At = thrown and orb.Last or nil })
end

--- What the orb may touch: everything but its caster, the FX folder and every body the caster may not hurt (Config's
--- unhurtable players and teammates -- it passes through them, as their shots pass through each other).
local function orbExclude(player, casterChar)
	local list = { casterChar }
	local fx = Core.FxFolder()
	if fx then list[#list + 1] = fx end
	Config.AddUnhurtable(list, player)
	for _, other in ipairs(Players:GetPlayers()) do
		local c = other.Character
		if other ~= player and c and Core.IsFriendly(player, c) then list[#list + 1] = c end
	end
	return list
end

local function isBody(model)
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

--- The swept sphere: anything solid stops it -- any part of a body, or a world part that collides (a trigger volume or
--- a decoration with collisions off does not).
local function sweep(from, radius, step, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for _ = 1, 8 do
		local hit = workspace:Spherecast(from, radius, step, params)
		if not hit then return nil end
		if hit.Instance.CanCollide or isBody(hit.Instance:FindFirstAncestorOfClass("Model")) then return hit end
		params:AddToFilter(hit.Instance)
	end
	return nil
end

local function isBlock(part)
	return part:IsA("Part") and part.Shape == Enum.PartType.Block
end

--- Whether `part` really overlaps the sphere. GetPartBoundsInRadius answers by bounding box, which a big rotated part or
--- a wedge ramp fills far past its surface, so each candidate is asked again: its closest surface point (or, for a plain
--- block, its own box).
local function touches(part, center, radius)
	local ok, closest = pcall(function()
		return part:GetClosestPointOnSurface(center)            -- (inside the pcall: indexing a missing member throws)
	end)
	if ok and typeof(closest) == "Vector3" then
		return (closest - center).Magnitude <= radius or (isBlock(part) and onPart(part, center, 0))
	end
	return isBlock(part) and onPart(part, center, radius)
end

--- A shapecast misses what it already overlaps, so the release point is tested on its own: the part it sits in, a body
--- first, or nil.
local function overlapAt(center, radius, exclude)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local world = nil
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, params)) do
		if touches(part, center, radius) then
			local model = part:FindFirstAncestorOfClass("Model")
			if isBody(model) then return part, model end
			if part.CanCollide and not world then world = part end
		end
	end
	return world, nil
end

--- The body the orb touched, if it is one it may hurt (its direct-hit bonus and its bolt).
local function directOf(player, casterChar, model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and isEnemyBody(player, model, casterChar) then return model end
	return nil
end

--- StrikeDelay after the burst: every enemy within DamageRadius the burst can see (a line from it to their root that
--- nothing solid stands on; the body it touched always), CenterDamage falling to EdgeDamage by flat distance.
local function orbDamage(player, casterChar, at, direct)
	local V = T.VoltOrb
	local radius = V.DamageRadius
	local found = Core.HumanoidsNear(at, radius, casterChar)
	if direct and direct.Parent then
		local dh = direct:FindFirstChildOfClass("Humanoid")
		if dh and dh.Health > 0 then found[dh] = direct end
	end
	for hum, model in pairs(found) do
		local r = rootOf(model)
		if r and model ~= casterChar and model ~= player.Character then
			local rel = r.Position - at
			local d3 = rel.Magnitude
			local seen = model == direct or d3 < 0.5
				or not Core.Blocked({ Origin = at, Dir = rel / d3, Character = casterChar }, d3, model)
			if seen then
				-- HumanoidsNear matches any part, so a root can sit past the radius: held to it, never under EdgeDamage
				local d = math.min(flat(rel).Magnitude, radius)
				local amount = V.CenterDamage - (V.CenterDamage - V.EdgeDamage) * (d / radius)
					+ (model == direct and V.DirectBonus or 0)
				Core.DealDamage(player, hum, amount, { Ranged = true, From = at, Source = "VoltOrb" })
			end
		end
	end
end

--- The burst: told now (the crack and the break), hurting StrikeDelay later (the first strike). `part` / `contact`: what
--- it hit, for the training boards' marks.
local function detonate(player, orb, at, normal, direct, air, part, contact)
	if orbs[player] ~= orb then return end
	orbs[player] = nil
	local V = T.VoltOrb
	local casterChar = orb.Character
	-- the nearest enemy body within DamageRadius: the first strike's bolt goes into it
	local nearest, nearestD = nil, math.huge
	for _, model in pairs(Core.HumanoidsNear(at, V.DamageRadius, casterChar)) do
		local r = rootOf(model)
		if r and isEnemyBody(player, model, casterChar) then
			local d = (r.Position - at).Magnitude
			if d < nearestD then nearest, nearestD = model, d end
		end
	end
	broadcast("VoltOrbBurst", {
		Character = casterChar, At = at, Normal = normal, Direct = direct, Nearest = nearest, Air = air == true,
		T0 = serverNow(),
	})
	if part then Core.ShotImpact:Fire(part, contact or at, player) end
	local epoch = orb.Epoch
	task.delay(V.StrikeDelay / orb.Scale, function()
		if not player.Parent or Core.Epoch(player) ~= epoch then return end
		local ok, err = pcall(orbDamage, player, casterChar, at, direct)
		if not ok then warnOnce("orbdamage", "Volt Orb damage failed: " .. tostring(err)) end
	end)
end

local function castVoltOrb(player, character, humanoid, root, payload, role)
	local V = T.VoltOrb
	local head = character:FindFirstChild("Head") or root
	-- the look from the head to the crosshair's point (held to Range), pitched up by Lift and clamped to MinElev..MaxElev
	local target = Core.ClampTarget(root, payload.Target, V.Range or 60)
	local look = target - head.Position
	look = look.Magnitude > 0.1 and look.Unit or root.CFrame.LookVector
	local across = flat(look)
	if across.Magnitude < 0.05 then across = flat(root.CFrame.LookVector) end
	if across.Magnitude < 0.05 then across = Vector3.new(0, 0, -1) end
	across = across.Unit
	local elev = math.clamp(math.asin(math.clamp(look.Y, -1, 1)) + math.rad(V.Lift), math.rad(V.MinElev), math.rad(V.MaxElev))
	local vel = (across * math.cos(elev) + Vector3.yAxis * math.sin(elev)) * V.Speed
	local from = head.Position + CFrame.lookAt(Vector3.zero, across):VectorToWorldSpace(V.HandOffset)
	-- MaxLive 1: a new throw drops the old one
	if orbs[player] then fizzle(player, "Replaced") end
	local s = timeScale()
	local now = serverNow()
	local orb = {
		Character = character, From = from, Vel = vel, T0 = now, ReleaseAt = now + V.ReleaseAt / s, Scale = s,
		Last = from, First = true, Epoch = Core.Epoch(player), Seed = seeds:NextInteger(1, 1000000000),
	}
	orbs[player] = orb
	broadcast("VoltOrbThrow", {
		Character = character, From = from, Vel = vel, T0 = now, ReleaseAt = orb.ReleaseAt, Gravity = V.Gravity,
		Fuse = V.Fuse, Seed = orb.Seed,
	})
end

--- One Heartbeat of `player`'s orb: in the hand until ReleaseAt, then the arc, stepped with a swept sphere.
local function stepOrb(player, orb, now)
	local V = T.VoltOrb
	if not player.Parent or Core.Epoch(player) ~= orb.Epoch then
		fizzle(player, "Clear")
		return
	end
	if now < orb.ReleaseAt then
		-- still in the hand: its caster falling, or interrupted, drops it
		local ch = orb.Character
		local hum = ch:FindFirstChildOfClass("Humanoid")
		if player.Character ~= ch or not ch.Parent or not hum or hum.Health <= 0 then
			fizzle(player, "Died")
		elseif not Core.CanAct(player) then
			fizzle(player, "Interrupted")
		end
		return
	end
	-- shot time since the release, held to the fuse
	local t = math.min((now - orb.ReleaseAt) * orb.Scale, V.Fuse)
	local pos = orb.From + orb.Vel * t + Vector3.new(0, -0.5 * V.Gravity * t * t, 0)
	local exclude = orbExclude(player, orb.Character)
	if orb.First then
		orb.First = false
		local part, model = overlapAt(orb.From, V.HitRadius, exclude)
		if part then
			local away = orb.From - part.Position
			local normal = (not model and away.Magnitude > 0.01) and away.Unit or Vector3.yAxis
			detonate(player, orb, orb.From, normal, directOf(player, orb.Character, model), false, part, orb.From)
			return
		end
	end
	local step = pos - orb.Last
	if step.Magnitude > 1e-3 then                           -- a zero-length sweep is skipped, never cast
		local hit = sweep(orb.Last, V.HitRadius, step, exclude)
		if hit then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			detonate(player, orb, hit.Position + hit.Normal * 0.5, hit.Normal, directOf(player, orb.Character, model), false,
				hit.Instance, hit.Position)
			return
		end
		orb.Last = pos
	end
	if t >= V.Fuse then
		detonate(player, orb, pos, Vector3.yAxis, nil, true)
	end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: CASCADE
----------------------------------------------------------------------------------------------------
-- The storm's clock and zone are VoltaicFX.Tuning.Cascade's (the render's), read once. VoltaicFX has no top-level
-- LocalPlayer or waits (TerraHandler requires TerraFX the same way); if it cannot be read, the contract's numbers stand.
-- (Strikes: seconds from the cast, Windup 0.50 + the storm's 1.2333 / 1.30 / 1.3667 / 1.4667 / 1.5333 -- VoltaicFX's own)
local CASCADE_FALLBACK = { Strikes = { 1.7333, 1.8000, 1.8667, 1.9667, 2.0333 }, ZoneRadius = 11, BellyHeight = 14 }
local cascadeClock = nil

local function cascadeNumbers()
	if cascadeClock then return cascadeClock end
	local src = nil
	local m = iceFolder:FindFirstChild("VoltaicFX")
	if m and m:IsA("ModuleScript") then
		local ok, fx = pcall(require, m)
		if ok and type(fx) == "table" and type(fx.Tuning) == "table" and type(fx.Tuning.Cascade) == "table" then
			src = fx.Tuning.Cascade
		elseif not ok then
			warnOnce("voltaicfx", "VoltaicFX failed to load (" .. tostring(fx) .. "); Cascade runs on the contract's numbers")
		end
	end
	if not src then
		warnOnce("cascadetuning", "VoltaicFX.Tuning.Cascade not found; Cascade runs on the contract's numbers")
		src = {}
	end
	local strikes = (type(src.Strikes) == "table" and #src.Strikes > 0) and src.Strikes or CASCADE_FALLBACK.Strikes
	cascadeClock = {
		Strikes = strikes,
		ZoneRadius = type(src.ZoneRadius) == "number" and src.ZoneRadius or CASCADE_FALLBACK.ZoneRadius,
		BellyHeight = type(src.BellyHeight) == "number" and src.BellyHeight or CASCADE_FALLBACK.BellyHeight,
	}
	return cascadeClock
end

local function endStorm(storm)
	if storm.Ended then return end
	storm.Ended = true
	storms[storm] = nil
	broadcast("CascadeEnd", { Character = storm.Character, T0 = storm.T0 })
end

--- Bolt `n`: the enemy under the storm struck fewest times so far (ties to the nearest the point), else filler point n.
local function strikeOnce(storm, n)
	local K = T.Cascade
	local clock = storm.Clock
	local player, point, casterChar = storm.Player, storm.Point, storm.Character
	local zone = clock.ZoneRadius
	local best, bestHum, bestRoot, bestCount, bestD = nil, nil, nil, math.huge, math.huge
	for hum, model in pairs(Core.HumanoidsNear(point, zone + 2, casterChar)) do
		local r = rootOf(model)
		if r and hum.Health > 0 and isEnemyBody(player, model, casterChar) then
			local d = flat(r.Position - point).Magnitude
			if d <= zone then
				local c = storm.Count[model] or 0
				if c < bestCount or (c == bestCount and d < bestD) then
					best, bestHum, bestRoot, bestCount, bestD = model, hum, r, c, d
				end
			end
		end
	end
	local at
	if best then
		at = groundBelow(bestRoot.Position, 20) or Vector3.new(bestRoot.Position.X, point.Y, bestRoot.Position.Z)
		storm.Count[best] = bestCount + 1
		local before = bestHum.Health
		Core.DealDamage(player, bestHum, K.StrikeDamage,
			{ From = point + Vector3.new(0, clock.BellyHeight, 0), Source = "Cascade" })
		if before > 0 and bestHum.Health <= 0 and Callouts then
			local head = best:FindFirstChild("Head") or bestRoot
			pcall(Callouts.Pop, head, Vector3.new(0, 2.8, 0), "ARCSTORM!", "arcstorm")
		end
	else
		local spread = K.Spread[((n - 1) % #K.Spread) + 1]
		local a = math.rad(spread[2])
		local p = point + Vector3.new(math.cos(a), 0, math.sin(a)) * (spread[1] * zone)
		at = groundBelow(p + Vector3.new(0, 6, 0), 26) or p
	end
	broadcast("CascadeStrike", { Character = casterChar, Point = point, N = n, At = at, T0 = storm.T0 })
end

local function strike(storm, n)
	if storm.Ended then return end
	local player = storm.Player
	if not player.Parent or Core.Epoch(player) ~= storm.Epoch then
		endStorm(storm)
		return
	end
	local ok, err = pcall(strikeOnce, storm, n)
	if not ok then warnOnce("cascadestrike", "Cascade strike failed: " .. tostring(err)) end
	storm.Done += 1
	if storm.Done >= #storm.Clock.Strikes then endStorm(storm) end
end

local function castCascade(player, character, humanoid, root, payload, role)
	local K = T.Cascade
	local clock = cascadeNumbers()
	local aim = Core.ClampTarget(root, payload.Target, K.Range)
	-- the ground under the crosshair's spot, straight down through bodies; over a drop nothing happens and the Ultimate
	-- is given back (Cyclone's arrangement)
	local point = groundBelow(aim + Vector3.new(0, 6, 0), K.GroundProbe)
	-- (2026-10-19, audit P1-09) ...a spot the caster can see: behind a wall, or on the storey above or below, the storm
	-- comes back to the floor under where the sight line stops -- or, with none on this side, the Ultimate is given back
	if point then
		local seen = sightPoint(character, root, point)
		if seen ~= point then point = groundBelow(seen, K.GroundProbe) end
	end
	if not point then
		addUltCharge:Fire(player, 1)
		return
	end
	local s = timeScale()
	local now = serverNow()
	local storm = {
		Player = player, Character = character, Point = point, T0 = now, Scale = s, Epoch = Core.Epoch(player),
		Count = {}, Done = 0, Ended = false, Clock = clock,
	}
	storms[storm] = true
	broadcast("CascadeGather", { Character = character, Point = point, T0 = now })
	for n, at in ipairs(clock.Strikes) do
		task.delay(at / s, strike, storm, n)
	end
end

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
-- Chain Bolt has no cast function: its CastRequest is SpellshotService's rate and mana; the shot is ChainBoltFire.
local casts = {
	Overcharge = castOvercharge,
	Railspike = castRailspike,
	VoltOrb = castVoltOrb,
	Cascade = castCascade,
}

-- the role rides along as a sixth argument (Pyro's arrangement): Overcharge hands itself back by role, and Railspike
-- may be in either Technique slot
performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return end
	fn(player, character, humanoid, root, type(payload) == "table" and payload or {}, role)
end)

----------------------------------------------------------------------------------------------------
-- the Heartbeat: the prime's cap, the windup's backstops, the orbs in flight
----------------------------------------------------------------------------------------------------
local function stepPrimed(player, p, now)
	if player.Character ~= p.Character or not p.Character.Parent then
		clearPrimed(player, "Died")
	elseif Core.Epoch(player) ~= p.Epoch then
		clearPrimed(player, "Clear")
	elseif now >= p.Until then
		clearPrimed(player, "Expired")
	elseif not holds(player, "Primary", "Overcharge") then
		clearPrimed(player, "Loadout")
	end
end

local function stepRail(player, r, clock)
	local ch = player.Character
	if ch ~= r.Character or not ch.Parent then
		stopRail(player, "Died")
	elseif Core.Epoch(player) ~= r.Epoch then
		stopRail(player, "Clear")
	elseif not Core.CanAct(player) then
		stopRail(player, "Interrupted")                    -- InterruptedUntil, a burrow, a round lock: the windup ends now
	elseif not techSlot(player, "Railspike") then
		stopRail(player, "Loadout")
	elseif clock - r.Clock > (T.Railspike.ChargeTime + T.Railspike.GiveUp) / r.Scale then
		stopRail(player, "Timeout")                        -- the client never fired: GiveUp
	end
end

RunService.Heartbeat:Connect(function()
	if next(primed) == nil and next(rails) == nil and next(orbs) == nil then return end
	local now = serverNow()
	local clock = os.clock()
	-- each item on its own guard: one that errors is dropped (and told to end), never left running or blocking the rest
	for player, p in pairs(primed) do
		local ok, err = pcall(stepPrimed, player, p, now)
		if not ok then
			warnOnce("stepprimed", "primed step failed: " .. tostring(err))
			pcall(clearPrimed, player, "Error")
			primed[player] = nil
		end
	end
	for player, r in pairs(rails) do
		local ok, err = pcall(stepRail, player, r, clock)
		if not ok then
			warnOnce("steprail", "Railspike step failed: " .. tostring(err))
			pcall(stopRail, player, "Error")
			rails[player] = nil
		end
	end
	for player, orb in pairs(orbs) do
		local ok, err = pcall(stepOrb, player, orb, now)
		if not ok then
			warnOnce("steporb", "Volt Orb step failed: " .. tostring(err))
			pcall(fizzle, player, "Error")
			orbs[player] = nil
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
local function endStormsOf(player)
	for storm in pairs(storms) do
		if storm.Player == player then endStorm(storm) end
	end
end

--- A body that died or was removed: the prime and the windup go with it, and an orb still in its hand drops. An orb
--- already thrown flies on, and a placed storm still strikes.
local function endBody(player, character)
	local p = primed[player]
	if p and p.Character == character then clearPrimed(player, "Died") end
	local r = rails[player]
	if r and r.Character == character then stopRail(player, "Died") end
	local orb = orbs[player]
	if orb and orb.Character == character and serverNow() < orb.ReleaseAt then fizzle(player, "Died") end
end

local function watchCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function()
		endBody(player, character)
	end)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		endBody(player, character)
	end)
	if player.Character then task.spawn(watchCharacter, player, player.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	clearPrimed(player, "Left")
	stopRail(player, "Left")
	fizzle(player, "Left")
	endStormsOf(player)
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): the prime ends, a windup stops, an orb in
-- the hand or in flight drops without a burst, and a storm strikes nothing more. Anything already scheduled (the tell,
-- an orb's strike) checks the epoch and does nothing.
Core.OnClear(function(player)
	clearPrimed(player, "Clear")
	stopRail(player, "Clear")
	fizzle(player, "Clear")
	endStormsOf(player)
end)

print("[VoltaicHandler] ready")
