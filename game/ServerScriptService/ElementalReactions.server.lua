--[[
	ElementalReactions  (Script)  ->  ServerScriptService/ElementalReactions

	THE ELEMENTAL REACTIONS (manual v0.23, Section 2, "Elemental Reactions"), built 2026-10-17 on the owner's "implement the
	reactions in game, like usable". A hit of one Element on a body carrying another Element's status sets off a bonus.

	HOW IT WORKS. Every hit goes through CombatCore.DealDamage, which now knows the hit's Element (info.Element: the kit script
	that dealt it). This listens to every landed hit (Core.OnHitLanded), reads the statuses the body carries at that moment,
	and fires at most one reaction per hit (plus Toxic Squall, which is about a cloud, not a status). The statuses stay their
	kits': the kits lend their levers through Core.Hooks (AbilityHandler: Chill and the roots; PyroHandler: Burn;
	ToxinHandler: the clouds). StatusEffects runs Poisoned and Charged itself.

	  Melt          Pyro x Cryo       Cryo on Burning, or Pyro on Chilled / Rooted: a burst, and the status it hit is consumed
	  Combustion    Pyro x Toxin      Pyro on Poisoned, or Toxin on Burning: a burst round the body -- over the whole Toxin
	                                  cloud it stands in, if any, which burns away -- and the status it hit is consumed
	  Overload      Pyro x Voltaic    Voltaic on Burning, or Pyro on Charged: a burst with a knockback and a stagger; consumed
	  Shatter       Cryo x Voltaic    Voltaic on Rooted: the root breaks early, for a bonus
	  Frozen        Cryo x Aqua       Aqua on Chilled (or Cryo on Wet): Chill (and Wet) consumed, a longer root begins
	  Wildfire      Pyro x Zephyr     Zephyr on Burning: one more burn stack and a fresh clock
	  Windchill     Cryo x Zephyr     Zephyr on Chilled: one more Chill stack
	  Storm Surge   Voltaic x Zephyr  Zephyr on Charged: one more Charged stack (working name)
	  Dust Storm    Terra x Zephyr    Zephyr on Cracked: one more stack. DORMANT: nothing applies Cracked (held by the owner)
	  Windswept     Aqua x Zephyr     Zephyr on Wet: one more stack. DORMANT: nothing applies Wet yet
	  Toxic Squall  Toxin x Zephyr    a Zephyr hit in a Toxin cloud (the body hit, or the thrower, stands in it): the cloud
	                                  spreads, once per cloud

	WHO MAY SET ONE OFF. Anyone whose hit lands. The status may be your own (a loadout mixing Elements) or a teammate's (the 2v2
	payoff the manual describes); the manual left that open, and this decides it: a teammate's Element reacts exactly as a
	self-mixed Technique does. A friend's hit is refused by DealDamage already, so it sets nothing off. Burn and poison ticks,
	a Charged discharge and a reaction's own damage never set one off, and (2026-10-19, audit P3-10) nor does a hit on the
	caster's own body.
	(2026-10-19, audit P3-24) Two things follow. Since P31 (Config.TechniquesOwnElementOnly, 2026-10-18) a loadout cannot
	mix Elements, and no rule below pairs an Element with itself, so a status you applied reacts only with a teammate's hit:
	in a 1v1 the only statuses left to react with are ones the victim put on itself (a Toxin's own poison). And a
	teammate's hit consumes what it reacts with, your Cryo's root included -- an ally's Pyro M1 frees your Cryo's catch
	(audit P3-05).

	SPAM. A consume clears what it reacted with, so it cannot repeat on that status. An extend has a per-body cooldown
	(Zephyr's Wind Blade fires fast), and Frozen a long one, so two players cannot chain roots on one body.

	THE NUMBERS (TUNE) are provisional starting points, not balanced. ReplicatedStorage.Spellshot:SetAttribute("ReactionsOff",
	true) turns every reaction off at once.

	FOR TOOLS: ServerStorage.ReactionsDebug (a BindableFunction)
	  Invoke("status", player, kind, "dummy" | model, stacks)  Burning | Chilled | Rooted | Poisoned | Charged, from `player`
	  Invoke("hit", player, model, element, amount)            a hit of that Element through the damage pipeline
	  Invoke("log")                                            the last reactions, one per line
	  Invoke("hits")                                           the last 20 hits with the Element each was tagged with
	The dev panel's ELEMENTAL REACTIONS row uses "status" through SpellshotService ("ReactionStatus").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Core = require(script.Parent:WaitForChild("CombatCore"))
local Status = require(script.Parent:WaitForChild("StatusEffects"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Callouts = require(spellFolder:WaitForChild("Callouts"))

local Hooks = Core.Hooks

local TUNE = {
	Melt        = { Bonus = 14, Cooldown = 0.75 },
	Combustion  = { Damage = 16, Radius = 8, Cooldown = 0.75 },
	Overload    = { Bonus = 12, Knock = 40, KnockLift = 18, KnockTime = 0.25, Stagger = 0.6, Cooldown = 0.75 },
	Shatter     = { Bonus = 10, Cooldown = 0.75 },
	Frozen      = { Root = 2.0, Cooldown = 6 },
	Wildfire    = { Cooldown = 2, MaxFan = 4 },   -- 2026-10-23: MaxFan, s one burn can be fanned for from its first fan
	Windchill   = { Stacks = 1, Cooldown = 2 },
	StormSurge  = { Stacks = 1, Cooldown = 2 },
	DustStorm   = { Stacks = 1, Cooldown = 2 },
	Windswept   = { Stacks = 1, Cooldown = 2 },
	ToxicSquall = { Grow = 1.35 },
}

----------------------------------------------------------------------------------------------------
-- the words: FROZEN!'s structure (a burst behind bold lettering), the burst tinted the pale of the status that was hit,
-- the word in the hitting Element's ink. One slot of their own, above the other callouts.
----------------------------------------------------------------------------------------------------
local INK = {
	Pyro = Color3.fromRGB(242, 92, 13), Cryo = Color3.fromRGB(20, 116, 170), Toxin = Color3.fromRGB(86, 150, 16),
	Voltaic = Color3.fromRGB(74, 26, 140), Zephyr = Color3.fromRGB(18, 112, 92), Aqua = Color3.fromRGB(14, 120, 140),
	Terra = Color3.fromRGB(130, 107, 36),
}
local PALE = {
	Pyro = Color3.fromRGB(255, 226, 196), Cryo = Color3.fromRGB(205, 236, 252), Toxin = Color3.fromRGB(226, 245, 200),
	Voltaic = Color3.fromRGB(236, 230, 250), Aqua = Color3.fromRGB(214, 246, 240), Terra = Color3.fromRGB(240, 228, 170),
}
local PLAIN_BURST = Callouts.Styles.ko and Callouts.Styles.ko.Burst

local function styleFor(hitElement, statusElement)
	local key = "rx_" .. tostring(hitElement) .. "_" .. tostring(statusElement)
	if not Callouts.Styles[key] then
		Callouts.Styles[key] = {
			Burst = PLAIN_BURST, Tint = PALE[statusElement] or Color3.new(1, 1, 1), BurstPx = 100, BurstRot = -5,
			TextSize = 30, Stroke = 2.6, TextRot = 4, Color = INK[hitElement] or Color3.new(0, 0, 0), Life = 1.2,
			Shift = Vector2.new(0, 1.15), Slot = "reaction",
		}
	end
	return key
end

local REACTION = {
	Melt       = { Word = "MELT!", Shape = "consume" },
	Combustion = { Word = "COMBUSTION!", Shape = "consume" },
	Overload   = { Word = "OVERLOAD!", Shape = "consume" },
	Shatter    = { Word = "SHATTER!", Shape = "consume" },
	Frozen     = { Word = "FROZEN SOLID!", Shape = "handoff", Style = "frozen" },
	Wildfire   = { Word = "WILDFIRE!", Shape = "extend" },
	Windchill  = { Word = "WINDCHILL!", Shape = "extend" },
	StormSurge = { Word = "STORM SURGE!", Shape = "extend" },
	DustStorm  = { Word = "DUST STORM!", Shape = "extend" },
	Windswept  = { Word = "WINDSWEPT!", Shape = "extend" },
}

-- what each Element reacts with, in order: the first status the body carries is the one this hit reacts with
local RULES = {
	Pyro    = { { "Rooted", "Melt" }, { "Chilled", "Melt" }, { "Charged", "Overload" }, { "Poisoned", "Combustion" } },
	Cryo    = { { "Burning", "Melt" }, { "Wet", "Frozen" } },
	Voltaic = { { "Rooted", "Shatter" }, { "Burning", "Overload" } },
	Toxin   = { { "Burning", "Combustion" } },
	Aqua    = { { "Chilled", "Frozen" } },
	Zephyr  = { { "Burning", "Wildfire" }, { "Chilled", "Windchill" }, { "Charged", "StormSurge" }, { "Wet", "Windswept" },
	            { "Cracked", "DustStorm" } },
}
local STATUS_ELEMENT = { Burning = "Pyro", Chilled = "Cryo", Rooted = "Cryo", Poisoned = "Toxin", Charged = "Voltaic",
	Wet = "Aqua", Cracked = "Terra" }

----------------------------------------------------------------------------------------------------
-- reading and consuming statuses
----------------------------------------------------------------------------------------------------
local function has(humanoid, model, kind)
	if kind == "Rooted" then
		return Hooks.IsRooted ~= nil and Hooks.IsRooted(humanoid)
	elseif kind == "Poisoned" or kind == "Charged" then
		return Status.Has(humanoid, kind)
	end
	return model:GetAttribute("RX_" .. kind) == true      -- Burning, Chilled; Wet and Cracked have no writer yet
end

local CONSUME = {
	Burning = function(h) if Hooks.ClearBurn then Hooks.ClearBurn(h) end end,
	Chilled = function(h) if Hooks.ClearChill then Hooks.ClearChill(h) end end,
	Rooted = function(h)
		if Hooks.BreakRoot then Hooks.BreakRoot(h) end
		if Hooks.ClearChill then Hooks.ClearChill(h) end
	end,
	Poisoned = function(h) Status.Clear(h, "Poisoned") end,
	Charged = function(h) Status.Clear(h, "Charged") end,
	Wet = function(h) if Hooks.ClearWet then Hooks.ClearWet(h) end end,
}

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

local function pop(model, text, styleKey)
	local head = model:FindFirstChild("Head") or rootOf(model)
	if head then pcall(Callouts.Pop, head, Vector3.new(0, 1.2, 0), text, styleKey) end
end

local function bonus(ctx, amount, name)
	if amount and amount > 0 and ctx.Humanoid.Health > 0 then
		Core.DealDamage(ctx.Caster, ctx.Humanoid, amount, { Reaction = name, From = ctx.From })
	end
end

local function blast(ctx, model, amount, scale)
	local r = rootOf(model)
	if not r then return end
	local h = model:FindFirstChildOfClass("Humanoid")
	Core.Broadcast("DetonateBlast", { Character = ctx.CasterChar, Victim = model, Position = r.Position, Amount = amount,
		Scale = scale, Lethal = h ~= nil and h.Health <= 0, T0 = workspace:GetServerTimeNow() })
end

----------------------------------------------------------------------------------------------------
-- the reactions
----------------------------------------------------------------------------------------------------
local FIRE = {}

FIRE.Melt = function(ctx)
	CONSUME[ctx.Status](ctx.Humanoid)
	if ctx.Status ~= "Burning" then
		-- the ice goes: Flash Freeze's shatter, drawn on the body
		Core.Broadcast("FlashFreezeShatter", { Character = ctx.Model, Caster = ctx.CasterChar })
	end
	bonus(ctx, TUNE.Melt.Bonus, "Melt")
end

FIRE.Combustion = function(ctx)
	local T = TUNE.Combustion
	local root = rootOf(ctx.Model)
	local cloud = root and Hooks.CloudAt and Hooks.CloudAt(root.Position)
	local center, radius = root and root.Position, T.Radius
	if cloud then
		center = Vector3.new(cloud.Center.X, (cloud.Bottom + cloud.Top) / 2, cloud.Center.Z)
		radius = math.max(T.Radius, cloud.Radius)
	end
	CONSUME[ctx.Status](ctx.Humanoid)
	if not center then return end
	local bodies = { [ctx.Humanoid] = ctx.Model }
	for h, m in pairs(Core.HumanoidsNear(center, radius + 3, nil)) do
		local r = rootOf(m)
		if r and (r.Position - center).Magnitude <= radius + 1 and not Core.IsWall(m) then bodies[h] = m end
	end
	for h, m in pairs(bodies) do
		if h.Health > 0 and m ~= ctx.CasterChar
			and Core.DealDamage(ctx.Caster, h, T.Damage, { Reaction = "Combustion", From = center }) then
			blast(ctx, m, T.Damage, 0.4)
		end
	end
	if cloud and Hooks.IgniteCloud then Hooks.IgniteCloud(cloud) end
end

FIRE.Overload = function(ctx)
	local T = TUNE.Overload
	CONSUME[ctx.Status](ctx.Humanoid)
	bonus(ctx, T.Bonus, "Overload")
	blast(ctx, ctx.Model, T.Bonus, 0.55)
	Core.Broadcast("StatusDischarge", { From = ctx.Model })
	if ctx.Humanoid.Health <= 0 then return end
	local vroot = rootOf(ctx.Model)
	if not vroot then return end
	local croot = rootOf(ctx.CasterChar)
	local away = croot and (vroot.Position - croot.Position) or -vroot.CFrame.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
	local velocity = away * T.Knock + Vector3.new(0, T.KnockLift, 0)
	local victim = Players:GetPlayerFromCharacter(ctx.Model)
	if victim then
		-- a player's own client simulates their body: it is asked to move them, Aftershock's knock (AbilityFX)
		pcall(function()
			Core.Remote:FireClient(victim, "VFX", "AftershockKnock", { Velocity = velocity,
				Until = workspace:GetServerTimeNow() + T.KnockTime, Center = croot and croot.Position or vroot.Position,
				Caster = ctx.Caster })
		end)
		-- (2026-10-19, audits P4-04 / P1-03) thrown by an enemy until it lands: KnockedUntil (server time), which Updraft's
		-- bonus ignores and CombatCore's movement guard reads as a fast state -- the knock, its fall, and a little slack
		ctx.Model:SetAttribute("KnockedUntil", math.max(workspace:GetServerTimeNow() + T.KnockTime
			+ math.clamp(2 * math.max(velocity.Y, 0) / workspace.Gravity, 0.35, 1.4) + 0.3,
			ctx.Model:GetAttribute("KnockedUntil") or 0))
	else
		vroot.AssemblyLinearVelocity = velocity       -- a dummy is the server's to throw
	end
	-- the stagger: Bulwark Charge's stars (RX_Staggered), for its own short while
	local stamp = os.clock()
	ctx.Model:SetAttribute("RX_Staggered_Element", "Voltaic")
	ctx.Model:SetAttribute("RX_Staggered", true)
	ctx.Model:SetAttribute("ReactionStaggerAt", stamp)
	Core.ApplyStatusTag(ctx.Humanoid, "Staggered", T.Stagger)
	task.delay(T.Stagger, function()
		if ctx.Model.Parent and ctx.Model:GetAttribute("ReactionStaggerAt") == stamp then
			ctx.Model:SetAttribute("ReactionStaggerAt", nil)
			-- (2026-10-19, audit P3-06) a Bulwark Charge stagger still running (TerraHandler's RX_StaggeredUntil, server
			-- time) keeps the stars up; its own timer lowers them
			if workspace:GetServerTimeNow() >= (ctx.Model:GetAttribute("RX_StaggeredUntil") or 0) - 0.05 then
				ctx.Model:SetAttribute("RX_Staggered", false)
			end
		end
	end)
end

FIRE.Shatter = function(ctx)
	CONSUME.Rooted(ctx.Humanoid)
	Core.Broadcast("FlashFreezeShatter", { Character = ctx.Model, Caster = ctx.CasterChar })
	bonus(ctx, TUNE.Shatter.Bonus, "Shatter")
end

FIRE.Frozen = function(ctx)
	if Hooks.ClearChill then Hooks.ClearChill(ctx.Humanoid) end
	if Hooks.ClearWet then Hooks.ClearWet(ctx.Humanoid) end
	if Hooks.Root then Hooks.Root(ctx.Humanoid, TUNE.Frozen.Root) end
	Core.Broadcast("FlashFreezeRoot", { Character = ctx.Model, Caster = ctx.CasterChar })
end

FIRE.Wildfire = function(ctx)
	if Hooks.FanBurn then Hooks.FanBurn(ctx.Caster, ctx.Humanoid) end
end

FIRE.Windchill = function(ctx)
	if Hooks.AddChill then Hooks.AddChill(ctx.Caster, ctx.Humanoid, TUNE.Windchill.Stacks) end
end

FIRE.StormSurge = function(ctx)
	-- the stack is the Voltaic's, as theirs were: the discharge at the top stays credited to them
	local owner = Status.CasterOf(ctx.Humanoid, "Charged")
	Status.Apply(owner or ctx.Caster, ctx.Humanoid, "Charged", { Stacks = TUNE.StormSurge.Stacks })
end

FIRE.DustStorm = function(ctx)
	if Hooks.AddCracked then Hooks.AddCracked(ctx.Caster, ctx.Humanoid, TUNE.DustStorm.Stacks) end
end

FIRE.Windswept = function(ctx)
	if Hooks.AddWet then Hooks.AddWet(ctx.Caster, ctx.Humanoid, TUNE.Windswept.Stacks) end
end

----------------------------------------------------------------------------------------------------
-- the log, the cooldowns, firing
----------------------------------------------------------------------------------------------------
local log = {}
local function note(line)
	table.insert(log, string.format("%.2f  %s", os.clock(), line))
	if #log > 40 then table.remove(log, 1) end
end

local last = setmetatable({}, { __mode = "k" })      -- [humanoid] = { [reaction] = os.clock() }
local function ready(humanoid, name)
	local t = last[humanoid] or {}
	last[humanoid] = t
	local now = os.clock()
	local cd = (TUNE[name] and TUNE[name].Cooldown) or 0
	if t[name] and now - t[name] < cd then return false end
	t[name] = now
	return true
end

-- 2026-10-23: Wildfire gives a burn a fresh clock, so a Zephyr hitting every Cooldown kept one burn alight for good (12 s+,
-- 3 stacks): it fans one burn only for TUNE.Wildfire.MaxFan s from its first fan; the body going out of Burning resets it
local fanFrom = setmetatable({}, { __mode = "k" })   -- [humanoid] = os.clock() of the first Wildfire on its burn
local function canFan(humanoid)
	local first = fanFrom[humanoid]
	return first == nil or os.clock() - first < TUNE.Wildfire.MaxFan
end
local function fanned(humanoid, model)
	if fanFrom[humanoid] then return end
	fanFrom[humanoid] = os.clock()
	local conn
	conn = model:GetAttributeChangedSignal("RX_Burning"):Connect(function()
		if model:GetAttribute("RX_Burning") ~= true then
			fanFrom[humanoid] = nil
			conn:Disconnect()
		end
	end)
end

local function fire(name, ctx)
	local before = ctx.Humanoid.Health
	local ok, err = pcall(FIRE[name], ctx)
	if not ok then
		warn("[ElementalReactions] " .. name .. " failed: " .. tostring(err))
		return
	end
	local R = REACTION[name]
	pop(ctx.Model, R.Word, R.Style or styleFor(ctx.Element, STATUS_ELEMENT[ctx.Status]))
	Core.Broadcast("Reaction", { Name = name, Word = R.Word, Shape = R.Shape, Victim = ctx.Model, Caster = ctx.CasterChar,
		Element = ctx.Element, Status = ctx.Status, Color = INK[ctx.Element] })
	note(string.format("%s  %s hit on %s (%s)  hp %.0f -> %.0f", name, ctx.Element, ctx.Status, ctx.Model.Name, before,
		ctx.Humanoid.Health))
end

local function squall(ctx)
	if not (Hooks.CloudAt and Hooks.GrowCloud) then return end
	local root = rootOf(ctx.Model)
	local cloud = root and Hooks.CloudAt(root.Position)
	local croot = rootOf(ctx.CasterChar)
	if not cloud and croot then cloud = Hooks.CloudAt(croot.Position) end
	if not cloud or cloud.Squalled then return end
	cloud.Squalled = true
	Hooks.GrowCloud(cloud, TUNE.ToxicSquall.Grow)
	pop(ctx.Model, "TOXIC SQUALL!", styleFor("Zephyr", "Toxin"))
	Core.Broadcast("Reaction", { Name = "ToxicSquall", Word = "TOXIC SQUALL!", Shape = "world", Victim = ctx.Model,
		Caster = ctx.CasterChar, Element = "Zephyr", Color = INK.Zephyr })
	note(string.format("ToxicSquall  cloud %s radius -> %.1f", tostring(cloud.Id), cloud.Radius))
end

-- every hit's Element as the pipeline tagged it, reactions or not (ReactionsDebug "hits"): why a reaction did or did not fire
local hits = {}
Core.OnHitLanded(function(caster, humanoid, amount, info)
	if type(info) == "table" then
		table.insert(hits, string.format("%.2f  %s on %s  %s%s%s", os.clock(), tostring(info.Element),
			humanoid.Parent and humanoid.Parent.Name or "?", info.DoT and "DoT " or "", info.Status and "status " or "",
			info.Reaction and ("reaction " .. info.Reaction) or ""))
		if #hits > 20 then table.remove(hits, 1) end
	end
	if spellFolder:GetAttribute("ReactionsOff") then return end
	if type(info) ~= "table" or info.DoT or info.Status or info.Reaction or info.Chain then return end
	local element = info.Element
	local rules = element and RULES[element]
	if not rules then return end
	local model = humanoid.Parent
	if not model or humanoid.Health <= 0 or Core.IsWall(model) or model:GetAttribute("DecoyOwner") then return end
	local casterChar = (typeof(caster) == "Instance" and caster:IsA("Player")) and caster.Character or nil
	-- (2026-10-19, audit P3-10) never on the caster's own body: a Toxin in its own Patient Zero burst while Burning set off
	-- Combustion on itself (consuming its own burn and bursting on everyone round it)
	if casterChar ~= nil and model == casterChar then return end
	local ctx = { Caster = caster, CasterChar = casterChar, Humanoid = humanoid, Model = model, Element = element,
		From = info.From }
	if element == "Zephyr" then
		local ok, err = pcall(squall, ctx)
		if not ok then warn("[ElementalReactions] Toxic Squall failed: " .. tostring(err)) end
	end
	for _, rule in ipairs(rules) do
		local kind, name = rule[1], rule[2]
		-- 2026-10-23: a status whose reaction is on cooldown (or a burn fanned for its MaxFan) passes the hit on to the next
		-- status in the list; it stopped the check before
		if has(humanoid, model, kind) and (name ~= "Wildfire" or canFan(humanoid)) and ready(humanoid, name) then
			ctx.Status = kind
			if name == "Wildfire" then fanned(humanoid, model) end
			fire(name, ctx)
			return
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- for tools and the dev panel
----------------------------------------------------------------------------------------------------
local function nearestDummy(player)
	local character = player and player.Character
	local root = rootOf(character)
	if not root then return nil end
	local best, bestD
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Humanoid") and d.Health > 0 and d.Parent ~= character and not Players:GetPlayerFromCharacter(d.Parent)
			and not d.Parent:GetAttribute("WallOwner") and not d.Parent:GetAttribute("DecoyOwner")
			and not d.Parent:GetAttribute("AllyDummy") then
			local r = rootOf(d.Parent)
			local dist = r and (r.Position - root.Position).Magnitude or math.huge
			if dist < 250 and (not bestD or dist < bestD) then best, bestD = d, dist end
		end
	end
	return best
end

local debugFn = ServerStorage:FindFirstChild("ReactionsDebug")
if not debugFn then
	debugFn = Instance.new("BindableFunction")
	debugFn.Name = "ReactionsDebug"
	debugFn.Parent = ServerStorage
end
debugFn.OnInvoke = function(cmd, a, b, c, d)
	if cmd == "log" then
		return table.concat(log, "\n")
	elseif cmd == "hits" then
		return table.concat(hits, "\n")
	elseif cmd == "status" then
		local player, kind = a, b
		local h = (c == "dummy" or c == nil) and nearestDummy(player)
			or (typeof(c) == "Instance" and c:FindFirstChildOfClass("Humanoid"))
		if not h then return "no target" end
		if kind == "Burning" and Hooks.AddBurn then
			Hooks.AddBurn(player, h, d or 2)
		elseif kind == "Chilled" and Hooks.AddChill then
			Hooks.AddChill(player, h, d or 2)
		elseif kind == "Rooted" and Hooks.Root then
			Hooks.Root(h, d or 4)
		elseif kind == "Poisoned" then
			Status.Apply(player, h, "Poisoned")
		elseif kind == "Charged" then
			Status.Apply(player, h, "Charged", { Stacks = d or 2 })
		else
			return "unknown status " .. tostring(kind)
		end
		return kind .. " on " .. h.Parent:GetFullName()
	elseif cmd == "hit" then
		local h = typeof(b) == "Instance" and b:FindFirstChildOfClass("Humanoid")
		if not h then return "no target" end
		local landed = Core.DealDamage(a, h, d or 5, { Element = c })
		return "hit landed: " .. tostring(landed) .. ", health " .. h.Health
	end
	return "commands: status | hit | log"
end
