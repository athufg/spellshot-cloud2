--[[
	ZephyrClient  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrClient

	The client half of ZEPHYR's v6 Techniques and Passive (the v6 import, 2026-10-06; the plan is
	vfx_blocking/zephyr/aqua_v6/ROBLOX_IMPORT_PLAN.md, sections 5 and 6). It does no drawing and no gameplay of its own: it
	gathers three modules into the one shape SpellshotInput and AbilityFX already load for Radiant, Umbra and Toxin --

	  UPDRAFT    IceMagic.ZephyrUpdraft    the Passive's tell on every airborne Updraft holder, the aerial-hit pulse
	  GUST PAD   IceMagic.ZephyrGustPad    the Defense Technique: the press, the pad's look, the launch column
	  SKYRIDER   IceMagic.ZephyrSkyrider   the Mobility Technique: the held ride (its flight motor), the gust flap, the bird
	                                       (drawn by IceMagic.ZephyrFX_Skyrider)

	-- and leaves the M1, Primary and Ultimate (Wind Blade, Cross-Slash Dash, Cyclone) where they always were: SpellshotInput
	and AbilityFX call ZephyrFX for those directly. Each piece module follows the import's client contract:
	  .Tuning                              its numbers (shared with its server Script)
	  .Handlers  [kind] = fn(data)         the broadcasts it draws, ("VFX", kind, data) through AbilityFX
	  .LocalCast [abilityId] = fn          the keypress (see THE TWO KINDS OF PRESS)
	  .Init(bindings) (or .Bind)           client only, once: SpellshotInput's gates
	  .Demo(character, opts)               the test harness (opts.Freeze = clip seconds)
	  optional  .TryCast(role, character, ability) -> handled    a piece that takes a press WHOLE (below)
	            .OwnsPress = { [abilityId] = true }              ...or says which of its LocalCasts do
	            .IsActive() / .Interrupt(reason)                 a piece that moves YOUR body (Skyrider's ride) says so,
	                                                             and lets go when something else takes the body

	THE TWO KINDS OF PRESS. SpellshotInput's generic path gates a press (cooldown, mana, slide lock), flashes the slot,
	plays the arms -- LOCAL_CAST[id](character, role), else the clip named by the Id -- and sends the CastRequest (with the
	aim point when the row is Targeted); a Held row's key coming up sends its release. That is right for GUST PAD (a
	Targeted press: its LocalCast plays the palm-down press and waits for the server's answer), so its LocalCast is merged
	into LOCAL_CAST as Radiant's is (ZephyrClient.LocalCast, called (character, role) -- the plan's (role, character,
	ability) order is passed too when a piece asks for it, see below). A press the generic path CANNOT carry -- SKYRIDER's
	ride is a HELD cast whose release is the ride's END, not the key coming up, and the key again while riding is its gust
	flap, as Gust Jump's motor owned its key -- is taken WHOLE, before the gate, by ZephyrClient.TryCast(role, character,
	ability): the piece's own TryCast, or a LocalCast listed in its OwnsPress (or in WHOLE_PRESS below), called with the
	plan's (role, character, ability) and answering true (it gated, flashed and sent its own cast: SpellshotInput stops) or
	false (the generic path carries on). A whole press that errors is swallowed -- one warning, the slot flashes red --
	rather than let the generic path send a second cast for it.

	WHAT THIS MODULE IS ASKED
	  SpellshotInput      Bind(bindings) once, at load (Init is the same function): every piece gets bindings =
	                      { Flash, CanCast, AimPoint, BlockedByMovement } -- SpellshotInput's own gates. LocalCast, merged
	                      into LOCAL_CAST at load. TryCast on every Technique press, ahead of the generic path.
	  AbilityFX           Handlers, merged once at load, never over a kind it already has. Every handler here is wrapped:
	                      an error in one is one warning, never a broken listener. Interrupt(reason) when a Cyclone pull or
	                      an Aftershock knock takes your body (it interrupted GustJumpMotor before).
	  MovementController  IsActive(): a piece owns your body (no double jump, no wall run, no air momentum keeper).
	  ZephyrTestHarness   Demo(character, { Piece = name, Freeze = s }) and Loaded(), for the Studio-only demo trigger.
	FireM1 is nil on purpose: nothing here claims the M1 click (Wind Blade stays SpellshotInput's own).

	LOADING. Client only: on the server this module is inert (no requires, nothing bound) and every function answers
	"nothing" -- it is never meant to run there. On the client each piece is found in IceMagic (a piece not replicated yet
	is waited for Tuning.PieceWait seconds at require, and looked for again on a later press or Demo at most every
	Tuning.LookAgain seconds), required inside a pcall, and merged: a missing or failing piece costs only its own
	Technique, never the others' and never the input script. A kind or ability Id two pieces both claim keeps the first
	(warned once).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ZephyrClient = {}
ZephyrClient.Tuning = {}       -- [piece] = that piece module's own Tuning table (Updraft / GustPad / Skyrider)
ZephyrClient.Handlers = {}     -- [kind] = the guarded handler (merged from the three pieces)
ZephyrClient.LocalCast = {}    -- [abilityId] = the arms on the keypress, LOCAL_CAST's (character, role), guarded
ZephyrClient.FireM1 = nil      -- nothing here claims the M1 click

-- this module's own numbers: how long it waits for a piece module that has not replicated yet
local Tuning = {
	PieceWait = 3,             -- s at require: a piece missing from IceMagic is waited for this long (client only) ...
	LookAgain = 2,             -- ... and, still missing, looked for again at most this often on a press / demo (s)
}
ZephyrClient.ClientTuning = Tuning

-- the three pieces, in merge order (the first to claim a kind or an Id keeps it)
local PIECES = {
	{ Key = "Updraft", Module = "ZephyrUpdraft" },
	{ Key = "GustPad", Module = "ZephyrGustPad" },
	{ Key = "Skyrider", Module = "ZephyrSkyrider" },
}

-- Ability Ids whose LocalCast is THE WHOLE PRESS (see the header), on top of any piece's own OwnsPress list. Skyrider's
-- answers true every time (ZephyrSkyrider: the ride's release is its end, the key again is the flap); Gust Pad's is
-- the arms after the generic gate, so it is not here.
local WHOLE_PRESS = {
	Skyrider = true,
}

-- the test harness's demo names -> the module whose Demo plays it (the reskins live in their own ZephyrFX_<Piece>;
-- Skyrider's bird may carry its own Demo too, tried after the ride's)
local DEMO_MODULES = {
	WindBlade = { "ZephyrFX_WindBlade" },
	CrossSlash = { "ZephyrFX_CrossSlash" },
	Cyclone = { "ZephyrFX_Cyclone" },
	Updraft = { "ZephyrUpdraft" },
	GustPad = { "ZephyrGustPad" },
	Skyrider = { "ZephyrSkyrider", "ZephyrFX_Skyrider" },
}
ZephyrClient.DemoNames = { "WindBlade", "CrossSlash", "Cyclone", "Updraft", "GustPad", "Skyrider" }

local isClient = RunService:IsClient()
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrClient] " .. tostring(msg))
end

----------------------------------------------------------------------------------------------------
-- the pieces
----------------------------------------------------------------------------------------------------
local mods = {}                -- [key] = the piece module (a table), false (it failed to load), nil (not found yet)
local status = {}              -- [key] = "ok" | "missing" | "error: ..." (the harness reads it through Loaded)
local lookedAt = {}            -- [key] = os.clock() of the last look for a missing piece
local bindings = nil           -- SpellshotInput's gates, once Bind has been called
local inited = {}              -- [key] = true once that piece's Init / Bind has been called
local wholePress = {}          -- [abilityId] = fn(role, character, ability) -> handled: a press taken whole

--- Calls `fn(...)` guarded; an error is one warning under `key`. Returns ok, result.
local function guarded(key, label, fn, ...)
	local ok, res = pcall(fn, ...)
	if not ok then warnOnce(key, label .. " failed: " .. tostring(res)) end
	return ok, res
end

--- Hands the gates to one piece (its Init, or its Bind if that is what it has), once.
local function initPiece(key, mod)
	if inited[key] or not bindings then return end
	local fn = (type(mod.Init) == "function" and mod.Init) or (type(mod.Bind) == "function" and mod.Bind) or nil
	inited[key] = true
	if fn then guarded("init:" .. key, key .. ".Init", fn, bindings) end
end

--- Merges one loaded piece into Tuning / Handlers / LocalCast (or the whole-press table).
local function merge(key, mod)
	if type(mod.Tuning) == "table" then ZephyrClient.Tuning[key] = mod.Tuning end
	if type(mod.Handlers) == "table" then
		for kind, fn in pairs(mod.Handlers) do
			if type(fn) ~= "function" then continue end
			if ZephyrClient.Handlers[kind] then
				warnOnce("kind:" .. tostring(kind), key .. " also handles '" .. tostring(kind) .. "': the first piece keeps it")
			else
				-- wrapped: a drawing error is one warning, never a dead listener (and never a mechanic stopped)
				ZephyrClient.Handlers[kind] = function(data)
					guarded("handler:" .. tostring(kind), key .. ".Handlers." .. tostring(kind), fn, data)
				end
			end
		end
	end
	if type(mod.LocalCast) == "table" then
		local owns = type(mod.OwnsPress) == "table" and mod.OwnsPress or {}
		for id, fn in pairs(mod.LocalCast) do
			if type(fn) ~= "function" then continue end
			if ZephyrClient.LocalCast[id] or wholePress[id] then
				warnOnce("cast:" .. tostring(id), key .. " also casts '" .. tostring(id) .. "': the first piece keeps it")
			elseif owns[id] or WHOLE_PRESS[id] then
				wholePress[id] = fn                      -- before the gate, (role, character, ability) -> handled
			else
				-- the arms after the generic gate, as LOCAL_CAST calls them: (character, role)
				ZephyrClient.LocalCast[id] = function(character, role)
					guarded("cast:" .. tostring(id), key .. ".LocalCast." .. tostring(id), fn, character, role)
				end
			end
		end
	end
	initPiece(key, mod)
end

--- Finds, requires and merges one piece. `wait` (s) waits that long for a module not replicated yet.
local function load(piece, wait)
	local key = piece.Key
	if mods[key] ~= nil then return end
	lookedAt[key] = os.clock()
	local m = iceFolder:FindFirstChild(piece.Module)
	if not m and wait and wait > 0 then m = iceFolder:WaitForChild(piece.Module, wait) end
	if not m then
		status[key] = "missing"
		return
	end
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" then
		mods[key] = mod
		status[key] = "ok"
		merge(key, mod)
	else
		mods[key] = false
		status[key] = "error: " .. tostring(mod)
		warnOnce("load:" .. key, piece.Module .. " failed to load: " .. tostring(mod))
	end
end

--- A piece still missing is looked for again, at most every LookAgain seconds (never waits).
local function refresh()
	if not isClient then return end
	local now = os.clock()
	for _, piece in ipairs(PIECES) do
		if mods[piece.Key] == nil and now - (lookedAt[piece.Key] or -math.huge) >= Tuning.LookAgain then
			load(piece, 0)
		end
	end
end

if isClient then
	for _, piece in ipairs(PIECES) do
		load(piece, Tuning.PieceWait)
	end
end

--- The loaded pieces, for the test harness: { [key] = "ok" | "missing" | "error: ..." }.
function ZephyrClient.Loaded()
	local out = {}
	for _, piece in ipairs(PIECES) do out[piece.Key] = status[piece.Key] or (isClient and "missing" or "server") end
	return out
end

----------------------------------------------------------------------------------------------------
-- SpellshotInput
----------------------------------------------------------------------------------------------------
--- SpellshotInput's gates ({ Flash, CanCast, AimPoint, BlockedByMovement }), handed to every piece once (Init / Bind).
--- A piece that loads later gets them when it loads.
function ZephyrClient.Bind(fns)
	if not isClient then return end
	bindings = type(fns) == "table" and fns or {}
	for key, mod in pairs(mods) do
		if mod then initPiece(key, mod) end
	end
end
ZephyrClient.Init = ZephyrClient.Bind

--- A press taken WHOLE (see the header), before SpellshotInput's generic gate: a piece's own TryCast, or a LocalCast it
--- (or WHOLE_PRESS) marks as the whole press. true = the piece took it and SpellshotInput stops there; false = the generic
--- path runs it (Gust Pad's press, every other Element's).
function ZephyrClient.TryCast(role, character, ability)
	if not isClient or type(ability) ~= "table" or ability.Id == nil then return false end
	refresh()
	local id = ability.Id
	local fn, label = wholePress[id], "LocalCast." .. tostring(id)
	if not fn then
		for key, mod in pairs(mods) do
			if mod and type(mod.TryCast) == "function" then
				local ok, handled = guarded("try:" .. key, key .. ".TryCast", mod.TryCast, role, character, ability)
				if not ok then
					if bindings and type(bindings.Flash) == "function" then pcall(bindings.Flash, role, true) end
					return true                          -- swallowed: it may already have sent its cast
				end
				if handled == true then return true end
			end
		end
		return false
	end
	local ok, handled = guarded("press:" .. tostring(id), label, fn, role, character, ability)
	if not ok then
		if bindings and type(bindings.Flash) == "function" then pcall(bindings.Flash, role, true) end
		return true                                  -- swallowed: it may already have sent its cast
	end
	return handled == true
end

----------------------------------------------------------------------------------------------------
-- your own body: AbilityFX and MovementController
----------------------------------------------------------------------------------------------------
--- Whether a piece moves YOUR body right now (Skyrider's ride): MovementController stands its air moves down for it.
function ZephyrClient.IsActive()
	for key, mod in pairs(mods) do
		if mod and type(mod.IsActive) == "function" then
			local ok, on = guarded("active:" .. key, key .. ".IsActive", mod.IsActive)
			if ok and on == true then return true end
		end
	end
	return false
end

--- Something else takes your body (a Cyclone's pull, an Aftershock's knock): every piece that moves it lets go.
function ZephyrClient.Interrupt(reason)
	for key, mod in pairs(mods) do
		if mod and type(mod.Interrupt) == "function" then
			guarded("interrupt:" .. key, key .. ".Interrupt", mod.Interrupt, reason)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- demos (the test harness)
----------------------------------------------------------------------------------------------------
--- Plays a piece's Demo on `character` (the contract's Demo(character, opts) shape): opts.Piece is one of DemoNames --
--- the three reskins too, through their ZephyrFX_<Piece> modules -- and the rest of opts goes to that Demo as it is
--- (opts.Freeze = clip seconds). Returns the Demo's own result (a handle with :Stop(), when it gives one), or nil and why.
function ZephyrClient.Demo(character, opts)
	if not isClient then return nil, "server" end
	refresh()
	opts = type(opts) == "table" and opts or {}
	local name = opts.Piece
	local list = DEMO_MODULES[name]
	if not list then return nil, "unknown piece '" .. tostring(name) .. "'" end
	local why = "no " .. list[1]
	for _, modName in ipairs(list) do
		local m = iceFolder:FindFirstChild(modName)
		if m then
			local ok, mod = pcall(require, m)
			if ok and type(mod) == "table" and type(mod.Demo) == "function" then
				local played, handle = pcall(mod.Demo, character, opts)
				if played then return handle or true end
				return nil, modName .. ".Demo failed: " .. tostring(handle)
			end
			why = ok and (modName .. " has no Demo") or (modName .. " failed to load: " .. tostring(mod))
		end
	end
	return nil, why
end

return ZephyrClient
