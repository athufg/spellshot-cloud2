--[[
	StatusEffects  (ModuleScript)  ->  ServerScriptService/StatusEffects

	ELEMENTAL APPLICATION (manual v0.13, Section 2): the one place a lingering status's NUMBERS, stacks, clock and expiry
	live. Built 2026-09-24 on the owner's go after the Phase 1 audit, which found no shared status system: Chill
	(AbilityHandler) and Burn (PyroHandler) each ran their own, and Poison / Mark / Blessing existed only as names.

	THE STATUSES
	  Burning   Pyro     DoT. Its ticks stay PyroHandler's (Immolate / Ring of Fire / Scorching Lash), which read their
	                     numbers from here, so a preset retunes them.
	  Chilled   Cryo     stacks; the last stack is a deep slow (2026-10-08: it used to root). The shard logic stays
	                     AbilityHandler's, reading its numbers here.
	  Poisoned  Toxin    DoT, run HERE. Applied by ToxinHandler (2026-09-30: Toxic Bubbles, Corrosive Cloud, Patient Zero)
	                     and the dev panel. opts.Self lets a Toxin's own cloud poison the Toxin itself (the kit's baseline
	                     self-damage rule; ToxinHandler thins that damage). CasterOf says whose poison it is.
	  Charged   Voltaic  stacks from hits; at MaxStacks it discharges a small chain to the nearest OTHER enemy of the
	                     caster, and, when there is none (every 1v1 duel), into the charged target itself for AloneDamage
	                     (7 in preset A since the 2026-10-17 balance pass; 0 before, the manual read literally). Applied by
	                     VoltaicHandler's Chain Bolt (and ElementalReactions' Storm Surge, and the dev panel). (2026-10-19,
	                     audit P3-24: this said no Chain Bolt existed yet.)
	  Marked    Umbra    KIT-OWNED since 2026-09-27 (Chill's arrangement): Umbra's Mark Technique -- self-only, stacks ripen,
	                     a headshot pays the most -- is UmbraHandler's, which writes RX_Marked and its suffixes itself. The
	                     team-primed Mark for Death that ran here is retired (ServerStorage.UmbraKitSuperseded).
	  Blessed   Radiant  PRIMED: an absorb pool that soaks damage until it is empty; unused, it lapses after Duration.
	  Cracked   Terra    HELD by the owner (2026-09-24) -- deliberately not here. Zephyr has none, on purpose.

	DURATIONS are REFRESHED, never extended: a reapplication resets the clock to Duration from now.

	THE THREE PRESETS are the balance reworks the owner asked to test (balance model: vmarm/status_fx/balance_sim.py).
	The live one is ReplicatedStorage.Spellshot:GetAttribute("StatusPreset") ("A" | "B" | "C"), which the dev panel
	switches mid-session; every number is read at the moment it is used, so a switch applies to the next hit.

	WHAT A CLIENT SEES is the existing attribute contract on the victim's model, unchanged, so the HUD layer, CombatFeedback
	and the world FX keep working: RX_<Kind> (flag, written LAST), RX_<Kind>_Element, _Stacks, _Amount, and the new
	_Expires (server time) / _Total, which the Phase 3 status HUD will draw its timers from.

	API (server)
	  Status.Tune(kind)                         the live preset's numbers for a kind
	  Status.PresetName()                       "A" | "B" | "C"
	  Status.Apply(caster, humanoid, kind, opts) -> the record, or nil if refused (friendly, a wall, dead)
	  Status.Clear(humanoid, kind) / Status.ClearAll(humanoid)
	  Status.Has(humanoid, kind) / Status.Stacks(humanoid, kind)
	  Status.Stamp(model, kind, seconds)        a kit-owned status (Chill, Burn) publishing its clock
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(script.Parent:WaitForChild("CombatCore"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Callouts = require(spellFolder:WaitForChild("Callouts"))

local Status = {}

----------------------------------------------------------------------------------------------------
-- the three reworks
----------------------------------------------------------------------------------------------------
-- A  SPEC            the manual's durations as written (5 s refreshed / 8 s primed) on today's effects. The model puts a
--                    Cryo target rooted 23-27% and slowed another 25-31% of a fight: the M1 lock the owner asked about.
-- B  THRESHOLD       an M1 hit only builds stacks; nothing happens until the last one. No per-stack slow at all.
--                    Rooted 17-19%, never slowed by the shard.
-- C  SOFT PRESSURE   the manual's durations, lighter per stack: a mild slow, a shorter root, a longer immunity.
--                    Rooted 11-13%, slowed 19-25% but never below walking pace.
-- Burn keeps PyroHandler's 0.5 s tick in all three; only how long and how hard changes. Charged / Poison / Mark /
-- Blessing are for kits that do not exist yet, so their numbers are PROVISIONAL starting points.
-- CHILL (2026-10-08, the owner: "a root is too strong for a basic attack"): the third Icicle Shard stack no longer roots.
-- It caps move speed at SlowCaps[MaxStacks] for one Window (further hits in that time add nothing), then the stacks clear
-- and no new stack lands for Stack3Immunity -- the same shape as the root it replaces, so a perfect tapper still cannot
-- hold a target in the deepest slow. Rooting stays with Flash Freeze, Deep Freeze and Mirror Cage. (The rooted-%
-- figures above were modelled with the old root.)
Status.Presets = {
	A = {
		Label = "SPEC",
		Burning  = { Interval = 0.5, Immolate = { Ticks = 10, TickDamage = 1.2 }, Ring = { Ticks = 10, TickDamage = 1.5 },
		             Lash = { Ticks = 10, PerStack = 1.0, --[[1.6 until the 2026-10-17 balance pass]] MaxStacks = 3 } },
		Chilled  = { Window = 5.0, MaxStacks = 3, SlowCaps = { 22, 15, 10 }, Stack3Immunity = 1.2 },
		Poisoned = { Duration = 5.0, Interval = 1.0, TickDamage = 6, --[[4 until the 2026-10-17 balance pass]] MaxStacks = 1 },
		Charged  = { Duration = 5.0, MaxStacks = 4, ChainDamage = 16, ChainRange = 20, AloneDamage = 7 }, --[[AloneDamage 0 until the 2026-10-17 balance pass]]
		Blessed  = { Duration = 8.0, Absorb = 35 },
	},
	B = {
		Label = "THRESHOLD",
		Burning  = { Interval = 0.5, Immolate = { Ticks = 6, TickDamage = 2 }, Ring = { Ticks = 6, TickDamage = 2.5 },
		             Lash = { Ticks = 6, PerStack = 2, MaxStacks = 3 } },
		Chilled  = { Window = 4.0, MaxStacks = 3, SlowCaps = { [3] = 10 }, Stack3Immunity = 2.0 },
		Poisoned = { Duration = 4.0, Interval = 1.0, TickDamage = 3, MaxStacks = 1 },
		Charged  = { Duration = 4.0, MaxStacks = 3, ChainDamage = 12, ChainRange = 20, AloneDamage = 7 },
		Blessed  = { Duration = 6.0, Absorb = 30 },
	},
	C = {
		Label = "SOFT PRESSURE",
		Burning  = { Interval = 0.5, Immolate = { Ticks = 10, TickDamage = 0.9 }, Ring = { Ticks = 10, TickDamage = 1.2 },
		             Lash = { Ticks = 10, PerStack = 1.2, MaxStacks = 3 } },
		Chilled  = { Window = 5.0, MaxStacks = 3, SlowCaps = { 22, 19, 10 }, Stack3Immunity = 2.5 },
		Poisoned = { Duration = 5.0, Interval = 1.0, TickDamage = 2.5, MaxStacks = 2 },
		Charged  = { Duration = 5.0, MaxStacks = 3, ChainDamage = 12, ChainRange = 18, AloneDamage = 6 },
		Blessed  = { Duration = 8.0, Absorb = 25 },
	},
}
Status.DefaultPreset = "A"

function Status.PresetName()
	local p = spellFolder:GetAttribute("StatusPreset")
	return (type(p) == "string" and Status.Presets[p]) and p or Status.DefaultPreset
end

function Status.Tune(kind)
	return Status.Presets[Status.PresetName()][kind]
end

local ELEMENT = { Burning = "Pyro", Chilled = "Cryo", Poisoned = "Toxin", Charged = "Voltaic", Marked = "Umbra",
	Blessed = "Radiant" }
local RUN_HERE = { Poisoned = true, Charged = true, Blessed = true }   -- Marked is UmbraHandler's since 2026-09-27
local BENIGN = { Blessed = true }
local SUFFIXES = { "_Stacks", "_Amount", "_Expires", "_Total" }
Status.Kinds = ELEMENT

----------------------------------------------------------------------------------------------------
-- state and publishing
----------------------------------------------------------------------------------------------------
local state = setmetatable({}, { __mode = "k" })   -- [humanoid] = { [kind] = record }

local function epochOf(model)
	local p = model and Players:GetPlayerFromCharacter(model)
	return p and Core.Epoch(p) or nil
end

--- the suffixes first, the flag last; the flag off first, then the suffixes -- the order every other writer uses
local function publish(model, kind, rec)
	if not (model and model.Parent) then return end
	local flag = "RX_" .. kind
	if rec then
		model:SetAttribute(flag .. "_Element", ELEMENT[kind])
		model:SetAttribute(flag .. "_Stacks", (rec.Stacks and rec.Stacks > 1) and rec.Stacks or nil)
		model:SetAttribute(flag .. "_Amount", rec.Amount and math.ceil(rec.Amount) or nil)
		model:SetAttribute(flag .. "_Expires", rec.ExpiresServer)
		model:SetAttribute(flag .. "_Total", rec.Total)
		model:SetAttribute(flag, true)
	else
		model:SetAttribute(flag, false)
		for _, s in ipairs(SUFFIXES) do model:SetAttribute(flag .. s, nil) end
		model:SetAttribute(flag .. "_Element", nil)
	end
end

--- A kit-owned status (Chill, Burn) publishing its clock beside the flag it already writes. seconds <= 0 clears it.
function Status.Stamp(model, kind, seconds)
	if not (model and model.Parent) then return end
	if seconds and seconds > 0 then
		model:SetAttribute("RX_" .. kind .. "_Expires", workspace:GetServerTimeNow() + seconds)
		model:SetAttribute("RX_" .. kind .. "_Total", seconds)
	else
		model:SetAttribute("RX_" .. kind .. "_Expires", nil)
		model:SetAttribute("RX_" .. kind .. "_Total", nil)
	end
end

local function recordOf(humanoid, kind)
	local s = state[humanoid]
	return s and s[kind]
end

function Status.Has(humanoid, kind)
	if RUN_HERE[kind] then return recordOf(humanoid, kind) ~= nil end
	local model = humanoid and humanoid.Parent
	return model ~= nil and model:GetAttribute("RX_" .. kind) == true
end

--- Who last applied `kind` to `humanoid` (the record's caster), or nil (2026-09-30, for Antitoxin Vent's own-poison-only
--- cleanse).
function Status.CasterOf(humanoid, kind)
	local rec = recordOf(humanoid, kind)
	return rec and rec.Caster or nil
end

function Status.Stacks(humanoid, kind)
	if RUN_HERE[kind] then
		local rec = recordOf(humanoid, kind)
		return rec and rec.Stacks or 0
	end
	local model = humanoid and humanoid.Parent
	return model and (model:GetAttribute("RX_" .. kind .. "_Stacks") or (Status.Has(humanoid, kind) and 1 or 0)) or 0
end

local lapseListeners = {}
--- fn(humanoid, kind, rec): a status's clock ran out on its own -- not emptied, not cleared (2026-09-29, for Radiant's
--- Overflow Light). rec is the record as it stood (Blessed: rec.Amount is the absorb left, rec.Caster who gave it).
--- Called just before the status clears.
function Status.OnLapse(fn)
	table.insert(lapseListeners, fn)
end

function Status.Clear(humanoid, kind)
	local s = state[humanoid]
	local rec = s and s[kind]
	if not rec then return end
	s[kind] = nil
	rec.Token = nil
	publish(rec.Model, kind, nil)
end

function Status.ClearAll(humanoid)
	local s = state[humanoid]
	if not s then return end
	for kind in pairs(s) do Status.Clear(humanoid, kind) end
end

----------------------------------------------------------------------------------------------------
-- callouts (the comic pops CHILL xN / BURN xN already use, over players and dummies alike)
----------------------------------------------------------------------------------------------------
local function pop(model, text, style)
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if head then pcall(Callouts.Pop, head, Vector3.new(0, 1.2, 0), text, style) end
end

----------------------------------------------------------------------------------------------------
-- apply
----------------------------------------------------------------------------------------------------
local function isCasterFriendly(caster, model)
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return false end
	if caster.Character == model then return true end
	return Core.IsFriendly(caster, model)
end

local discharge

--- opts: Stacks (how many to add, default 1), Amount (Blessed: the pool, default the preset's Absorb)
function Status.Apply(caster, humanoid, kind, opts)
	opts = opts or {}
	if not RUN_HERE[kind] then
		warn("[StatusEffects] " .. tostring(kind) .. " is not run here (Burning / Chilled are their kits'; Cracked is held)")
		return nil
	end
	if not (humanoid and humanoid.Parent and humanoid.Health > 0) then return nil end
	local model = humanoid.Parent
	if Core.IsWall(model) then return nil end
	local friendly = isCasterFriendly(caster, model)
	if BENIGN[kind] then
		-- a blessing goes on yourself or an ally, never an enemy
		if typeof(caster) == "Instance" and caster:IsA("Player") and not friendly then return nil end
	elseif friendly and not (opts.Self == true and kind == "Poisoned" and typeof(caster) == "Instance"
		and caster:IsA("Player") and caster.Character == model) then
		-- (opts.Self, 2026-09-30: a Toxin's own cloud poisoning the Toxin -- ToxinHandler's baseline self-damage rule)
		return nil
	end
	local t = Status.Tune(kind)
	local s = state[humanoid] or {}
	state[humanoid] = s
	local rec = s[kind]
	local fresh = rec == nil
	if fresh then
		rec = { Stacks = 0, Model = model, VictimEpoch = epochOf(model) }
		s[kind] = rec
	end
	-- (2026-10-19, audit P3-03) a SELF application (a Toxin in its own cloud) never takes over someone else's poison on it.
	-- It overwrote the record's caster: the enemy's ticks became the Toxin's own (thinned by Symbiosis, nothing behind the
	-- Vent), the enemy lost the credit, the Ultimate charge and the lifesteal, and Antitoxin Vent -- own poison only --
	-- could then cleanse it. The enemy's poison runs on as theirs; the cloud adds nothing to it.
	if not fresh and opts.Self == true and rec.Caster ~= nil and rec.Caster ~= caster then return nil end
	rec.Caster = caster
	rec.CasterEpoch = (typeof(caster) == "Instance" and caster:IsA("Player")) and Core.Epoch(caster) or nil
	local token = {}
	rec.Token = token

	local duration = t.Duration
	if kind == "Poisoned" or kind == "Charged" then
		rec.Stacks = math.min(t.MaxStacks, rec.Stacks + (opts.Stacks or 1))
	elseif kind == "Blessed" then
		rec.Stacks = 1
		rec.Amount = opts.Amount or t.Absorb
	end
	rec.Total = duration
	rec.ExpiresServer = workspace:GetServerTimeNow() + duration
	-- (2026-10-19, audit GA-06) whether the status's end is its PAYOFF (BarFX plays the payoff word only on true): false
	-- from every application; a Charged discharge and a Blessing soaked empty set it true before the flag drops, and a
	-- lapse, a clear or a death leave it false. Outside SUFFIXES, so the flag dropping does not wipe it first.
	if kind == "Charged" or kind == "Blessed" then model:SetAttribute("RX_" .. kind .. "_Paid", false) end

	-- CHARGED: at the last stack it goes off at once and the stacks are spent
	if kind == "Charged" and rec.Stacks >= t.MaxStacks then
		publish(model, kind, rec)
		discharge(rec, humanoid, t)
		if model.Parent then model:SetAttribute("RX_Charged_Paid", true) end    -- (2026-10-19, audit GA-06) the payoff
		Status.Clear(humanoid, kind)
		-- the kit hears it (VoltaicHandler: Chain Reaction's duel trigger, 2026-10-17)
		if Status.OnChargedFull then task.spawn(Status.OnChargedFull, caster, humanoid) end
		return rec
	end

	publish(model, kind, rec)
	if kind == "Poisoned" then
		pop(model, rec.Stacks > 1 and ("POISON x" .. rec.Stacks) or "POISON", "poison")
	elseif kind == "Charged" then
		pop(model, "CHARGE x" .. rec.Stacks, "charged")
	elseif kind == "Blessed" then
		pop(model, "BLESSED", "blessed")
	end

	-- the clock: refreshed, never extended -- only the newest application's token may end it. A DoT's clock runs a hair past
	-- its duration, so its last tick (due exactly AT the duration) lands before it goes: 5 s of 1 s ticks is 5 ticks, not 4.
	task.delay(duration + (kind == "Poisoned" and 0.1 or 0), function()
		if rec.Token == token and s[kind] == rec then
			-- a LAPSE: the clock ran out (not emptied, not cleared) -- Overflow Light reads what was left (2026-09-29)
			for _, fn in ipairs(lapseListeners) do
				local ok, err = pcall(fn, humanoid, kind, rec)
				if not ok then warn("[StatusEffects] lapse listener failed: " .. tostring(err)) end
			end
			Status.Clear(humanoid, kind)
		end
	end)

	-- POISON ticks on one clock per victim, started by the first application; later ones never delay a tick
	if kind == "Poisoned" and fresh then
		task.spawn(function()
			while true do
				local pt = Status.Tune("Poisoned")
				task.wait(pt.Interval)
				if s[kind] ~= rec or not rec.Token then return end
				if humanoid.Health <= 0 or humanoid.Parent ~= model or not model.Parent then
					Status.Clear(humanoid, kind)
					return
				end
				-- out if the caster was cleared since (left the arena, a new round), or the victim was
				local c = rec.Caster
				if (rec.CasterEpoch and not (c.Parent and Core.Epoch(c) == rec.CasterEpoch))
					or (rec.VictimEpoch and epochOf(model) ~= rec.VictimEpoch) then
					Status.Clear(humanoid, kind)
					return
				end
				Core.DealDamage(c, humanoid, pt.TickDamage * rec.Stacks, { DoT = true, Status = "Poisoned" })
			end
		end)
	end
	return rec
end

----------------------------------------------------------------------------------------------------
-- Charged's discharge
----------------------------------------------------------------------------------------------------
discharge = function(rec, humanoid, t)
	local model = humanoid.Parent
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not root then return end
	local caster = rec.Caster
	local casterChar = typeof(caster) == "Instance" and caster:IsA("Player") and caster.Character or nil
	local best, bestD
	for other, otherModel in pairs(Core.HumanoidsNear(root.Position, t.ChainRange, model)) do
		if otherModel ~= casterChar and not Core.IsWall(otherModel) and not isCasterFriendly(caster, otherModel) then
			local r = otherModel:FindFirstChild("HumanoidRootPart") or otherModel.PrimaryPart
			local d = r and (r.Position - root.Position).Magnitude or math.huge
			if not bestD or d < bestD then best, bestD = other, d end
		end
	end
	if best then
		Core.DealDamage(caster, best, t.ChainDamage, { Status = "Charged", Chain = true, From = root.Position })
		Core.Broadcast("StatusDischarge", { From = model, To = best.Parent })
		pop(best.Parent, "ZAP!", "charged")
	elseif (t.AloneDamage or 0) > 0 then
		Core.DealDamage(caster, humanoid, t.AloneDamage, { Status = "Charged", Chain = true, From = root.Position })
		Core.Broadcast("StatusDischarge", { From = model })
		pop(model, "ZAP!", "charged")
	end
end

----------------------------------------------------------------------------------------------------
-- Blessed, in the one damage pipeline every hit goes through
----------------------------------------------------------------------------------------------------
-- (MARK's payoff moved to UmbraHandler on 2026-09-27, at the same -10: the marker's own hit only, a flat bonus by stacks,
-- the most on a headshot. The old team-primed +BonusPct modifier that stood here is in ServerStorage.UmbraKitSuperseded.)

-- BLESSING soaks last (25): an absorb pool of its own, spent hit by hit, gone when empty.
Core.AddModifier(25, function(victim, amount)
	local rec = recordOf(victim, "Blessed")
	if not rec or amount <= 0 then return amount end
	local soak = math.min(amount, rec.Amount or 0)
	rec.Amount = (rec.Amount or 0) - soak
	if rec.Amount <= 0.01 then
		-- (2026-10-19, audits GA-02 / GA-06) soaked EMPTY is a break, not a lapse: the amount at 0 and the payoff marker
		-- before the flag drops, so BarFX plays the break
		local model = rec.Model
		if model and model.Parent then
			model:SetAttribute("RX_Blessed_Amount", 0)
			model:SetAttribute("RX_Blessed_Paid", true)
		end
		Status.Clear(victim, "Blessed")
	else
		publish(rec.Model, "Blessed", rec)
	end
	return amount - soak
end)

----------------------------------------------------------------------------------------------------
-- clearing: a death, a new round, leaving the arena
----------------------------------------------------------------------------------------------------
Core.OnClear(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then Status.ClearAll(humanoid) end
	-- and what this player put on others: a cleared caster's poison stops ticking, its marks and charges go
	for h, s in pairs(state) do
		for kind, rec in pairs(s) do
			if rec.Caster == player and not BENIGN[kind] then Status.Clear(h, kind) end
		end
	end
end)

local function watchDeaths(humanoid)
	humanoid.Died:Connect(function() Status.ClearAll(humanoid) end)
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Humanoid") then watchDeaths(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then watchDeaths(d) end
end)

-- BarFX (the client's full-bar status looks, 2026-09-24) fills each look to the live preset's MaxStacks, so publish
-- them where a client can read them: now, and whenever the preset changes.
local function publishMax()
	spellFolder:SetAttribute("StatusMax_Charged", Status.Tune("Charged").MaxStacks)
	spellFolder:SetAttribute("StatusMax_Poisoned", Status.Tune("Poisoned").MaxStacks)
	spellFolder:SetAttribute("StatusMax_Chilled", Status.Tune("Chilled").MaxStacks)
	spellFolder:SetAttribute("StatusMax_Burning", Status.Tune("Burning").Lash.MaxStacks)
end
publishMax()
spellFolder:GetAttributeChangedSignal("StatusPreset"):Connect(publishMax)

return Status
