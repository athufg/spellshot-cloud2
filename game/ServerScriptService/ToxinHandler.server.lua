--[[
	ToxinHandler  (Script)  ->  ServerScriptService/ToxinHandler

	The gameplay side of TOXIN, reworked (manual v0.15, "Toxin -- reworked", with the v0.17 Technique decisions; the first
	playable build, 2026-09-30). ToxinClient is its client half and ToxinFX draws it. Every number is ToxinTuning's
	(ReplicatedStorage.IceMagic, pure data) and every one is a PROPOSAL. The old kit (Spore Burst, the self-centred
	Corrosive Cloud, Overgrowth Vault, Antidote Cloak, Bloom) never had a cast path; its config text is retired and
	recorded in ServerStorage.ToxinKitSuperseded.

	WHERE CASTS COME FROM: SpellshotService checks and pays for the cast, then fires PerformCast; this script acts only on
	its own ability Ids. Damage goes through CombatCore and the Poisoned status through StatusEffects, so shields, the
	Ultimate's charge, the status HUD and the callouts all work as for every other kit.

	  M1        TOXIC BUBBLES   the click's CastRequest carries the release (Origin: the eye, held to the server's head;
	                            Dir: the aim). The bubble is SIMULATED HERE (slow enough that the server's copy of a body
	                            is fair): a lob, Speed out of the hand under Gravity, swept each frame as a sphere. It
	                            STOPS at the first enemy it touches (DECIDED): a pop, Damage and PoisonStacks of Poisoned.
	                            A miss onto the world RESTS where it lands (a wall drops it to the floor below) for
	                            RestLife, then expires.
	  PRIMARY   CORROSIVE CLOUD Precheck_CorrosiveCloud: only with a live bubble of the caster's (flying or resting), so a
	                            press without one costs nothing. The cast converts the NEWEST live bubble into a cloud at
	                            that exact point (an airborne point pools onto the floor below, within FloorReach).
	  PASSIVE   SYMBIOSIS       every DoT tick a Toxin's poison lands on someone else (Poisoned ticks, cloud ticks) heals
	                            the Toxin by Lifesteal x the health it removed (CombatCore.Heal). THE BASELINE RULE: a
	                            Toxin's own poison (its clouds, its burst, the Poisoned stacks its clouds put on it) hurts
	                            it at SelfDamageMult -- reduced, not zero (a CombatCore modifier).
	  ULTIMATE  PATIENT ZERO    ChargeOnCatch: the enemy nearest the aim line (Range, LockRadius, in sight) is marked and
	                            the charge spent; nobody there, nothing is spent. Telegraph later it detonates on wherever
	                            the target is then: a BurstDamage hit and a cloud of constant Radius (VARIANT B, DECIDED),
	                            its damage and duration scaled by the target's allies within AllyRadius -- every other body
	                            the caster may hurt (in a 1v1 there are none, and the unscaled numbers carry the cast).
	  TECHNIQUE ANTITOXIN VENT  an instant cleanse of the caster's OWN poison (the Poisoned record, only while the caster
	                            is the one who put it there -- an enemy Toxin's poison is never touched), then ToxinVentUntil
	                            on the character: zero self-damage from their own poison, and their own clouds put no
	                            poison on them (free passage).
	  TECHNIQUE ACID RAIN       a downpour over the aimed ground spot: every Tick, everyone inside takes TickDamage (not a
	                            DoT: no lifesteal) and a stack of CORRODED (ToxinVuln / ToxinVulnUntil on the model, server
	                            time), which multiplies every Toxin poison hit they take by 1 + VulnPerStack x stacks.

	Server -> client (AbilityFX -> ToxinClient.Handlers), ("VFX", kind, data) on IceAbilityRemote, to everyone:
	  ToxinBubble / ToxinBubblePop / ToxinBubbleRest / ToxinBubbleExpire / ToxinBubbleConvert, ToxinCloud / ToxinCloudEnd,
	  ToxinLifesteal, ToxinPZMark / ToxinPZBurst / ToxinPZCancel, ToxinVent / ToxinVentEnd, ToxinAcidRain / ToxinAcidTick;
	  and to one player: ToxinSelfTick (their own poison hurt them: the screen tell), ToxinPZMiss (nobody to mark).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local T = require(iceFolder:WaitForChild("ToxinTuning"))          -- pure data; the clients read the same table
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Core = require(script.Parent:WaitForChild("CombatCore"))
local Status = require(script.Parent:WaitForChild("StatusEffects"))

local remote = Core.Remote
local broadcast = Core.Broadcast

local Callouts = nil
do
	local ok, mod = pcall(function() return require(spellFolder:WaitForChild("Callouts", 10)) end)
	if ok and type(mod) == "table" then Callouts = mod end
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ToxinHandler] " .. tostring(msg))
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

local function eyeOf(character, root)
	local head = character:FindFirstChild("Head")
	return head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
end

local function pingOf(player)
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	return ping
end

local function tell(player, kind, data)
	pcall(function() remote:FireClient(player, "VFX", kind, data) end)
end

local function pop(model, text)
	if not Callouts then return end
	local head = model and (model:FindFirstChild("Head") or rootOf(model))
	if head then pcall(Callouts.Pop, head, Vector3.new(0, 1.2, 0), text, "poison") end
end

local function isPlayer(v)
	return typeof(v) == "Instance" and v:IsA("Player")
end

--- Every player's body and the FX folder: a ray that sees only the world.
local function worldParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	if extra then exclude[#exclude + 1] = extra end
	params.FilterDescendantsInstances = exclude
	return params
end

--- A ray that sees through every body (a character, a training dummy) but not a Bulwark Wall, which is cover.
local function castThroughBodies(origin, direction, params)
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		local mdl = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (mdl and mdl:FindFirstChildOfClass("Humanoid")) or mdl:GetAttribute("WallOwner") then return hit end
		params:AddToFilter(mdl)
	end
	return nil
end

--- The floor under `point` (from a little above it), ignoring bodies and the FX folder; nil over nothing.
local function groundBelow(point, reach)
	local hit = castThroughBodies(point + Vector3.new(0, 1, 0), Vector3.new(0, -(reach or 40) - 1, 0), worldParams())
	return hit and hit.Position or nil
end

--- A spot the caster aimed at, held to `range` and put down on the floor.
local function aimedGround(root, target, range)
	local spot = Core.ClampTarget(root, target, range)
	return groundBelow(spot + Vector3.new(0, 5, 0), 60) or spot
end

--- The body nearest the aim line out of the eye (Mark's lock rule, RadiantHandler's pickOnAim): in front, within
--- lockRadius of the line and range of the caster, in sight, and accepted. Walls, decoys and veiled bodies never.
local function pickOnAim(character, root, aimAt, range, lockRadius, accept)
	local eye = eyeOf(character, root)
	local aim = Core.ValidVector(aimAt) and (aimAt - eye) or root.CFrame.LookVector
	if aim.Magnitude < 1e-3 then aim = root.CFrame.LookVector end
	aim = aim.Unit
	local best, bestPerp, bestDist = nil, math.huge, math.huge
	for hum, model in pairs(Core.HumanoidsNear(root.Position, range + 4, character)) do
		local r = rootOf(model)
		if r and hum.Health > 0 and model ~= character and not Core.IsWall(model) and not model:GetAttribute("DecoyOwner")
			and not (Core.IsVeiled and Core.IsVeiled(model)) and accept(model, hum) then
			local rel = r.Position - eye
			local along = rel:Dot(aim)
			local perp = (rel - aim * along).Magnitude
			local dist = (r.Position - root.Position).Magnitude
			if along > 0 and perp <= lockRadius and dist <= range
				and (perp < bestPerp - 0.25 or (perp < bestPerp + 0.25 and dist < bestDist))
				and not Core.Blocked({ Origin = eye, Dir = rel.Unit, Character = character }, rel.Magnitude, model) then
				best, bestPerp, bestDist = model, perp, dist
			end
		end
	end
	return best
end

--- A body this caster's poison may touch: alive, not a wall, not on the caster's side (CombatCore.IsFriendly).
local function hurtable(player, model, hum)
	return hum and hum.Health > 0 and not Core.IsWall(model) and not Core.IsFriendly(player, model)
end

----------------------------------------------------------------------------------------------------
-- THE BASELINE RULE, ACID RAIN'S CORRODED, and SYMBIOSIS (one damage pipeline: CombatCore's)
----------------------------------------------------------------------------------------------------
local function isPoison(info)
	return type(info) == "table" and (info.Status == "Poisoned" or info.ToxinPoison == true)
end

local function ventOn(character)
	return character ~= nil and (character:GetAttribute("ToxinVentUntil") or 0) > serverNow()
end

-- The Vent's DoT shield (2026-10-17, the owner's pick): while the mask is on, every DoT tick on the masked Toxin -- burn,
-- poison, clouds -- is thinned by T.Vent.DoTReduction. Priority -7: just after the poison rule (-8), before any shield.
Core.AddModifier(-7, function(victim, amount, info, caster)
	if amount <= 0 or not (info and info.DoT) or not ventOn(victim.Parent) then return amount end
	return amount * (1 - (T.Vent.DoTReduction or 0))
end)

local vuln = setmetatable({}, { __mode = "k" })          -- [humanoid] = { Stacks, Until (server time), Model }

local function clearVuln(humanoid)
	local v = vuln[humanoid]
	vuln[humanoid] = nil
	local model = v and v.Model or (humanoid and humanoid.Parent)
	if model and model.Parent then
		model:SetAttribute("ToxinVuln", nil)
		model:SetAttribute("ToxinVulnUntil", nil)
	end
end

local function vulnStacks(humanoid)
	local v = vuln[humanoid]
	if not v then return 0 end
	if serverNow() > v.Until then
		clearVuln(humanoid)
		return 0
	end
	return v.Stacks
end

-- Priority -8: after Mark (-10), before every shield soaks. A Toxin's own poison on itself is thinned (zero behind the
-- Vent's mask); anyone else's Toxin poison is amplified by their Corroded stacks.
Core.AddModifier(-8, function(victim, amount, info, caster)
	if amount <= 0 or not isPoison(info) then return amount end
	local model = victim.Parent
	if isPlayer(caster) and caster.Character == model then
		if ventOn(model) then return 0 end
		return amount * T.Symbiosis.SelfDamageMult
	end
	local n = vulnStacks(victim)
	if n > 0 then return amount * (1 + T.AcidRain.VulnPerStack * n) end
	return amount
end)

local threadAt = setmetatable({}, { __mode = "k" })     -- [victim humanoid] = os.clock() of the last lifesteal thread
local selfTellAt = {}                                    -- [player] = os.clock() of the last self-damage tell

Core.OnHitLanded(function(caster, humanoid, amount, info)
	if not (isPlayer(caster) and isPoison(info)) then return end
	local character = caster.Character
	if not character then return end
	local removed = type(info) == "table" and info.Removed or 0
	if humanoid.Parent == character then
		-- the baseline rule's tell: the owner's screen desaturates a moment (ToxinFX), at most every SelfTellEvery
		if removed > 0 then
			local now = os.clock()
			if now - (selfTellAt[caster] or 0) >= T.Symbiosis.SelfTellEvery then
				selfTellAt[caster] = now
				tell(caster, "ToxinSelfTick", { Amount = removed })
			end
		end
		return
	end
	-- SYMBIOSIS: DoT only (a Poisoned tick, a cloud tick), and only a Toxin's
	if not info.DoT or caster:GetAttribute("Element") ~= "Toxin" or removed <= 0 then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0) then return end
	local healed = Core.Heal and Core.Heal(caster, hum, removed * T.Symbiosis.Lifesteal, { Source = "Symbiosis" }) or 0
	local now = os.clock()
	if now - (threadAt[humanoid] or 0) >= T.Symbiosis.ThreadEvery then
		threadAt[humanoid] = now
		broadcast("ToxinLifesteal", { From = humanoid.Parent, To = character, Healed = healed })
	end
end)

----------------------------------------------------------------------------------------------------
-- CLOUDS (Corrosive Cloud and Patient Zero's detonation)
----------------------------------------------------------------------------------------------------
local clouds = {}            -- list of { Id, Owner, Character, Center, Radius, Bottom, Top, Start, Until, Next, ... }
local cloudSeq = 0

--- A cloud at `point`: an airborne point pools onto the floor below (within FloorReach). Returns the record.
local function addCloud(owner, point, o)
	local C = T.Cloud
	local floor = groundBelow(point, C.FloorReach)
	local floorY = floor and floor.Y or (point.Y - 3)
	local now = os.clock()
	cloudSeq += 1
	local c = {
		Id = cloudSeq, Owner = owner, Character = owner.Character, Epoch = Core.Epoch(owner),
		Point = point, Center = Vector3.new(point.X, floorY, point.Z), Radius = o.Radius,
		Bottom = floorY - C.Below, Top = math.max(point.Y, floorY) + C.Above,
		Start = now + o.FormTime, Until = now + o.FormTime + o.Duration, Next = now + o.FormTime,
		TickDamage = o.TickDamage, Stacks = o.Stacks or C.PoisonStacks, Source = o.Source, Poisoned = {},
	}
	table.insert(clouds, c)
	return c
end

local function cloudTick(c, now)
	local C = T.Cloud
	local owner = c.Owner
	local mid = Vector3.new(c.Center.X, (c.Bottom + c.Top) / 2, c.Center.Z)
	local reach = math.sqrt(c.Radius ^ 2 + ((c.Top - c.Bottom) / 2) ^ 2) + 2
	for hum, model in pairs(Core.HumanoidsNear(mid, reach, nil)) do
		local r = rootOf(model)
		if r and hum.Health > 0 and not Core.IsWall(model) then
			local p = r.Position
			if flat(p - c.Center).Magnitude <= c.Radius and p.Y >= c.Bottom and p.Y <= c.Top then
				local info = { DoT = true, ToxinPoison = true, Source = c.Source, From = c.Center }
				local mine = model == owner.Character
				-- the owner: reduced (the modifier), and nothing at all behind the Vent's mask -- free passage
				if mine and ventOn(model) then continue end
				if mine or not Core.IsFriendly(owner, model) then
					if Core.DealDamage(owner, hum, c.TickDamage, info) then
						-- the Poisoned refresh, at most every 1.5 s a body (every tick would re-pop POISON twice a second)
						if now - (c.Poisoned[hum] or -99) >= 1.5 then
							c.Poisoned[hum] = now
							Status.Apply(owner, hum, "Poisoned", { Stacks = c.Stacks, Self = mine or nil })
						end
					end
				end
			end
		end
	end
	c.Next += C.Tick
end

local function endCloud(i, reason)
	local c = table.remove(clouds, i)
	if c and reason ~= "Expired" then broadcast("ToxinCloudEnd", { Id = c.Id, Reason = reason }) end
end

-- ELEMENTAL REACTIONS (2026-10-17): the clouds' levers for ServerScriptService.ElementalReactions. Combustion ignites the
-- cloud a body stands in (it burns away in that burst); Toxic Squall, a Zephyr hit in a cloud, spreads it, once.
--- The newest formed cloud holding `position`, or nil.
Core.Hooks.CloudAt = function(position)
	local now = os.clock()
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		if now >= c.Start and flat(position - c.Center).Magnitude <= c.Radius and position.Y >= c.Bottom and position.Y <= c.Top then
			return c
		end
	end
	return nil
end
Core.Hooks.IgniteCloud = function(c)
	for i, x in ipairs(clouds) do
		if x == c then
			endCloud(i, "Ignited")
			return
		end
	end
end
--- The cloud's radius times `factor` for the rest of its life, drawn as the old cloud giving way to a bigger one.
Core.Hooks.GrowCloud = function(c, factor)
	c.Radius *= factor
	local left = math.max(0.5, c.Until - os.clock())
	broadcast("ToxinCloudEnd", { Id = c.Id, Reason = "Grown" })
	broadcast("ToxinCloud", { Character = c.Character, Id = c.Id, Point = c.Center, Center = c.Center, Radius = c.Radius,
		T0 = serverNow(), FormTime = 0.25, Duration = left, Kind = "Corrosive" })
end

----------------------------------------------------------------------------------------------------
-- M1: TOXIC BUBBLES
----------------------------------------------------------------------------------------------------
local bubbles = {}           -- [player] = { bubble, ... } oldest first
local bubbleSeq = 0

local function bubblePos(b, t)
	return b.Origin + b.Vel * t + Vector3.new(0, -0.5 * b.G * t * t, 0)
end

local function bubbleNow(b)
	if b.State == "Rest" then return b.Pos end
	return bubblePos(b, os.clock() - b.T0)
end

local function dropBubble(player, b, kind, data)
	local list = bubbles[player]
	if list then
		local i = table.find(list, b)
		if i then table.remove(list, i) end
	end
	b.State = "Gone"
	if kind then
		data = data or {}
		data.Id = b.Id
		data.Character = b.Character
		broadcast(kind, data)
	end
end

local function castBubble(player, character, humanoid, root, payload)
	local B = T.Bubble
	local eye = eyeOf(character, root)
	local origin = payload.Origin
	local speed = math.max(root.AssemblyLinearVelocity.Magnitude, humanoid.WalkSpeed)
	if not (Core.ValidVector(origin) and (origin - eye).Magnitude <= B.OriginSlack + speed * (0.35 + pingOf(player))) then
		origin = eye
	end
	local dir = payload.Dir
	if not (Core.ValidVector(dir) and dir.Magnitude > 0.1) then dir = root.CFrame.LookVector end
	dir = dir.Unit
	-- the sac forms a little ahead of the eye -- never through a wall the caster stands against
	local start = origin + dir * B.StartAhead
	local block = workspace:Raycast(origin, dir * B.StartAhead, worldParams())
	if block then start = block.Position - dir * 0.3 end
	local scale = VFXLibrary.ShotTimeScale and VFXLibrary.ShotTimeScale() or 1
	bubbleSeq += 1
	local b = {
		Id = bubbleSeq, Owner = player, Character = character, Epoch = Core.Epoch(player), State = "Fly",
		Origin = start, Vel = dir * B.Speed * scale, G = B.Gravity * scale * scale, T0 = os.clock(), Last = start,
	}
	local list = bubbles[player]
	if not list then
		list = {}
		bubbles[player] = list
	end
	table.insert(list, b)
	-- too many at once: the oldest RESTING one expires early (a flying one is left to land)
	while #list > B.MaxLive do
		local victim = nil
		for _, o in ipairs(list) do
			if o.State == "Rest" then victim = o break end
		end
		victim = victim or list[1]
		dropBubble(player, victim, "ToxinBubbleExpire", { Position = bubbleNow(victim) })
	end
	broadcast("ToxinBubble", { Character = character, Id = b.Id, Origin = start, Vel = b.Vel, G = b.G, T0 = serverNow() })
end

--- One frame of a flying bubble: swept as a sphere from where it was to where it is now.
local function stepBubble(player, b, now)
	local B = T.Bubble
	local t = now - b.T0
	local p = bubblePos(b, t)
	local seg = p - b.Last
	if seg.Magnitude < 1e-3 then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { b.Character }
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	Config.AddUnhurtable(exclude, player)
	params.FilterDescendantsInstances = exclude
	local hit = nil
	for _ = 1, 4 do
		hit = workspace:Spherecast(b.Last, B.Radius, seg, params)
		if not hit then break end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if not hum then break end                                       -- the world
		if model:GetAttribute("WallOwner") or hurtable(player, model, hum) then break end   -- a wall is cover; an enemy
		params:AddToFilter(model)                                       -- a body it cannot hurt: through it
		hit = nil
	end
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum then
			-- STOPS at the first enemy it hits: the pop, a single-target poison tick
			dropBubble(player, b, "ToxinBubblePop", { Position = hit.Position, Target = model })
			if Core.DealDamage(player, hum, B.Damage, { Ranged = true, From = b.Origin, Source = "ToxicBubbles" })
				and not Core.IsWall(model) then
				Status.Apply(player, hum, "Poisoned", { Stacks = B.PoisonStacks })
			end
			return
		end
		-- a miss: it rests where it lands; off a wall or a ceiling it drops to the floor below first
		local at = hit.Position + hit.Normal * (B.Radius * 0.8)
		if hit.Normal.Y < 0.55 then
			local floor = groundBelow(at, 40)
			at = floor and (floor + Vector3.new(0, B.Radius * 0.8, 0)) or at
		end
		b.State, b.Pos, b.RestUntil = "Rest", at, now + B.RestLife
		broadcast("ToxinBubbleRest", { Id = b.Id, Character = b.Character, Position = at })
		return
	end
	b.Last = p
	if t > B.FlightLife then dropBubble(player, b, "ToxinBubbleExpire", { Position = p }) end
end

--- The caster's newest live bubble (flying or resting), or nil.
local function liveBubble(player)
	local list = bubbles[player]
	if not list then return nil end
	for i = #list, 1, -1 do
		if list[i].State ~= "Gone" and list[i].Epoch == Core.Epoch(player) then return list[i] end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: CORROSIVE CLOUD
----------------------------------------------------------------------------------------------------
do
	local precheck = spellFolder:FindFirstChild("Precheck_CorrosiveCloud")
	if not (precheck and precheck:IsA("BindableFunction")) then
		if precheck then precheck:Destroy() end
		precheck = Instance.new("BindableFunction")
		precheck.Name = "Precheck_CorrosiveCloud"
		precheck.Parent = spellFolder
	end
	-- must not yield: reads the table and answers
	precheck.OnInvoke = function(player)
		return liveBubble(player) ~= nil
	end
end

local function castCloud(player, character)
	local b = liveBubble(player)
	if not b then return end                    -- (the Precheck refused this already; a race costs nothing more)
	local C = T.Cloud
	local point = bubbleNow(b)
	dropBubble(player, b, "ToxinBubbleConvert", { Position = point })
	local c = addCloud(player, point, { Radius = C.Radius, Duration = C.Duration, TickDamage = C.TickDamage,
		FormTime = C.FormTime, Source = "CorrosiveCloud" })
	broadcast("ToxinCloud", { Character = character, Id = c.Id, Point = point, Center = c.Center, Radius = c.Radius,
		T0 = serverNow(), FormTime = C.FormTime, Duration = C.Duration, Kind = "Corrosive" })
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: PATIENT ZERO
----------------------------------------------------------------------------------------------------
local marks = {}             -- [player] = { Target, Epoch, LastPos, At }

local function detonate(player, character, m)
	local P = T.PatientZero
	local target = m.Target
	local r = target.Parent and rootOf(target)
	local hum = target:FindFirstChildOfClass("Humanoid")
	local pos = (r and hum and hum.Health > 0) and r.Position or m.LastPos
	if target.Parent and target:GetAttribute("ToxinPZUntil") == m.Until then target:SetAttribute("ToxinPZUntil", nil) end
	-- VARIANT B: the target's allies near it -- every other body the caster may hurt
	-- (by the root's distance: HumanoidsNear answers for any PART in the radius, so a body just outside it counted)
	local allies = 0
	for oh, om in pairs(Core.HumanoidsNear(pos, P.AllyRadius + 3, target)) do
		local orr = rootOf(om)
		if orr and (orr.Position - pos).Magnitude <= P.AllyRadius and om ~= character and not om:GetAttribute("DecoyOwner")
			and hurtable(player, om, oh) then
			allies += 1
		end
	end
	allies = math.min(allies, P.AllyCap)
	local mult = 1 + P.DamagePerAlly * allies
	local duration = P.CloudDuration + P.DurationPerAlly * allies
	-- the burst: everyone inside the (constant) radius; the caster at the reduced rate
	for vh, vm in pairs(Core.HumanoidsNear(pos, P.Radius + 3, nil)) do
		local vr = rootOf(vm)
		if vr and vh.Health > 0 and not Core.IsWall(vm) and flat(vr.Position - pos).Magnitude <= P.Radius
			and math.abs(vr.Position.Y - pos.Y) <= P.Radius then
			local mine = vm == character
			if (mine and not ventOn(vm)) or (not mine and not Core.IsFriendly(player, vm)) then
				if Core.DealDamage(player, vh, P.BurstDamage * mult, { ToxinPoison = true, Source = "PatientZero", From = pos })
					and not mine then
					Status.Apply(player, vh, "Poisoned", { Stacks = T.Cloud.PoisonStacks })
				end
			end
		end
	end
	local c = addCloud(player, pos, { Radius = P.Radius, Duration = duration, TickDamage = P.CloudTickDamage * mult,
		FormTime = 0.25, Source = "PatientZero" })
	broadcast("ToxinPZBurst", { Character = character, Target = target, Position = pos, Center = c.Center,
		Radius = P.Radius, Allies = allies, Duration = duration, CloudId = c.Id, T0 = serverNow() })
end

local function castPatientZero(player, character, humanoid, root, payload)
	local P = T.PatientZero
	local target = pickOnAim(character, root, payload.Target, P.Range, P.LockRadius, function(model, hum)
		return hurtable(player, model, hum)
	end)
	if not target then
		tell(player, "ToxinPZMiss", {})
		return                                  -- ChargeOnCatch: nothing marked, nothing spent
	end
	character:SetAttribute("UltCharge", 0)     -- (the dev free-Ultimate's heartbeat puts it straight back)
	local t0 = serverNow()
	local m = { Target = target, Epoch = Core.Epoch(player), LastPos = rootOf(target).Position, Until = t0 + P.Telegraph }
	marks[player] = m
	target:SetAttribute("ToxinPZUntil", m.Until)
	broadcast("ToxinPZMark", { Character = character, Target = target, T0 = t0, Telegraph = P.Telegraph, Fuse = P.Fuse })
	task.delay(P.Telegraph, function()
		if marks[player] == m then marks[player] = nil end
		if Core.Epoch(player) ~= m.Epoch or player.Character ~= character then
			if target.Parent and target:GetAttribute("ToxinPZUntil") == m.Until then target:SetAttribute("ToxinPZUntil", nil) end
			broadcast("ToxinPZCancel", { Character = character, Target = target })
			return
		end
		local ok, err = pcall(detonate, player, character, m)
		if not ok then warnOnce("pz", "Patient Zero's detonation failed: " .. tostring(err)) end
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: ANTITOXIN VENT
----------------------------------------------------------------------------------------------------
local function castVent(player, character, humanoid)
	local V = T.Vent
	-- the cleanse: the caster's OWN poison only (the record's caster is who last applied it)
	local cleansed = 0
	if Status.Has(humanoid, "Poisoned") and type(Status.CasterOf) == "function"
		and Status.CasterOf(humanoid, "Poisoned") == player then
		cleansed = Status.Stacks(humanoid, "Poisoned")
		Status.Clear(humanoid, "Poisoned")
	end
	local t0 = serverNow()
	local untilT = t0 + V.Duration
	character:SetAttribute("ToxinVentUntil", untilT)
	broadcast("ToxinVent", { Character = character, T0 = t0, Duration = V.Duration, Cleansed = cleansed })
	task.delay(V.Duration, function()
		if character.Parent and character:GetAttribute("ToxinVentUntil") == untilT then
			character:SetAttribute("ToxinVentUntil", nil)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: ACID RAIN
----------------------------------------------------------------------------------------------------
local function addVuln(humanoid, model)
	local A = T.AcidRain
	local v = vuln[humanoid]
	if not v or serverNow() > v.Until then
		v = { Stacks = 0, Model = model }
		vuln[humanoid] = v
	end
	v.Stacks = math.min(A.VulnMaxStacks, v.Stacks + 1)
	v.Until = serverNow() + A.VulnDuration
	model:SetAttribute("ToxinVulnUntil", v.Until)
	model:SetAttribute("ToxinVuln", v.Stacks)
	pop(model, v.Stacks > 1 and ("CORRODED x" .. v.Stacks) or "CORRODED")
end

local function castAcidRain(player, character, humanoid, root, payload)
	local A = T.AcidRain
	local center = aimedGround(root, payload.Target, A.Range)
	broadcast("ToxinAcidRain", { Character = character, Center = center, Radius = A.Radius, Height = A.Height,
		T0 = serverNow(), Gather = A.GatherTime, RainTime = A.RainTime })
	local epoch = Core.Epoch(player)
	local ticks = math.max(1, math.floor(A.RainTime / A.Tick + 0.5))
	for k = 0, ticks - 1 do
		task.delay(A.GatherTime + A.Tick * (k + 0.5), function()
			if Core.Epoch(player) ~= epoch then return end
			local hit = {}
			local mid = center + Vector3.new(0, A.Height / 2, 0)
			for hum, model in pairs(Core.HumanoidsNear(mid, math.sqrt(A.Radius ^ 2 + (A.Height / 2) ^ 2) + 2, character)) do
				local r = rootOf(model)
				if r and hurtable(player, model, hum) then
					local d = r.Position - center
					if flat(d).Magnitude <= A.Radius and d.Y >= -3 and d.Y <= A.Height then
						if Core.DealDamage(player, hum, A.TickDamage, { Source = "AcidRain", From = center }) then
							addVuln(hum, model)
							hit[#hit + 1] = model
						end
					end
				end
			end
			broadcast("ToxinAcidTick", { Character = character, Center = center, Hit = hit })
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
local casts = {
	ToxicBubbles = castBubble,
	CorrosiveCloud = castCloud,
	PatientZero = castPatientZero,
	AntitoxinVent = castVent,
	AcidRain = castAcidRain,
}

performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return end
	local ok, err = pcall(fn, player, character, humanoid, root, type(payload) == "table" and payload or {}, role)
	if not ok then warnOnce("cast" .. ability.Id, ability.Id .. " failed: " .. tostring(err)) end
end)

----------------------------------------------------------------------------------------------------
-- the Heartbeat: bubbles in flight and at rest, cloud ticks, Patient Zero's tracking, Corroded's expiry
----------------------------------------------------------------------------------------------------
local nextSweep = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, list in pairs(bubbles) do
		for i = #list, 1, -1 do
			local b = list[i]
			if b and b.State ~= "Gone" then
				if b.Epoch ~= Core.Epoch(player) or not b.Character.Parent then
					dropBubble(player, b, "ToxinBubbleExpire", { Position = bubbleNow(b) })
				elseif b.State == "Fly" then
					local ok, err = pcall(stepBubble, player, b, now)
					if not ok then
						warnOnce("bubble", "a bubble's step failed: " .. tostring(err))
						dropBubble(player, b, "ToxinBubbleExpire", { Position = b.Last })
					end
				elseif now > b.RestUntil then
					dropBubble(player, b, "ToxinBubbleExpire", { Position = b.Pos })
				end
			end
		end
	end
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		if not c.Owner.Parent or Core.Epoch(c.Owner) ~= c.Epoch then
			endCloud(i, "Cleared")
		elseif now >= c.Until then
			endCloud(i, "Expired")
		elseif now >= c.Next then
			local ok, err = pcall(cloudTick, c, now)
			if not ok then
				warnOnce("cloud", "a cloud tick failed: " .. tostring(err))
				c.Next = now + T.Cloud.Tick
			end
		end
	end
	for _, m in pairs(marks) do
		local r = m.Target.Parent and rootOf(m.Target)
		if r then m.LastPos = r.Position end
	end
	if now >= nextSweep then
		nextSweep = now + 0.25
		for hum in pairs(vuln) do vulnStacks(hum) end
	end
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
local function forget(player, reason)
	local list = bubbles[player]
	if list then
		for i = #list, 1, -1 do
			local b = list[i]
			dropBubble(player, b, "ToxinBubbleExpire", { Position = bubbleNow(b) })
		end
		bubbles[player] = nil
	end
	for i = #clouds, 1, -1 do
		if clouds[i].Owner == player then endCloud(i, reason) end
	end
	local m = marks[player]
	if m then
		marks[player] = nil
		if m.Target.Parent and m.Target:GetAttribute("ToxinPZUntil") == m.Until then m.Target:SetAttribute("ToxinPZUntil", nil) end
	end
	local c = player.Character
	if c then
		if c:GetAttribute("ToxinVentUntil") then
			c:SetAttribute("ToxinVentUntil", nil)
			broadcast("ToxinVentEnd", { Character = c })
		end
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then clearVuln(hum) end
	end
	selfTellAt[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	forget(player, "Left")
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): bubbles burst, clouds lift, a mark is
-- dropped (its detonation checks the epoch), the mask comes off, Corroded goes.
Core.OnClear(function(player)
	forget(player, "Cleared")
end)

print("[ToxinHandler] ready")
