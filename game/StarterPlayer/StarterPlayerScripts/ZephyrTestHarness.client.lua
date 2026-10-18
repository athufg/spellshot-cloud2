--[[
	ZephyrTestHarness  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/ZephyrTestHarness

	STUDIO ONLY (it returns at once anywhere else). The Zephyr v6 import's demo trigger (ROBLOX_IMPORT_PLAN.md, section 6):
	plays any one piece of the kit on your own character WITHOUT the server -- no cast, no mana, no cooldown, nobody hurt --
	so the look can be judged, and frozen on one frame for a screenshot, from a single attribute write.

	TRIGGER: workspace attribute ZephyrDemo, a string
	  "<Piece>:<seq>"                    play that piece once, live
	  "<Piece>:<seq>:<freezeSeconds>"    draw that one moment of the piece's clip and hold it (opts.Freeze), until the
	                                     next trigger
	  "Skyrider:<seq>:ride"              Skyrider's own local ride (opts.Ride: ZephyrSkyrider flies your body for real,
	                                     no server -- nothing paid, nothing hit) instead of the bird's showcase
	  "Stop:<seq>"                       stop whatever demo is up
	<Piece> is one of WindBlade, CrossSlash, Cyclone, Updraft, GustPad, Skyrider. <seq> is any number that changes from one
	write to the next, so the same piece (and the same frame) can be played again. Set it from the Server datamodel during
	Play (it replicates) or from the Client datamodel (this client alone). Only CHANGES play: the value already there when
	this script starts is ignored, so a value left on the workspace in Edit does not replay on every Play.

	WHAT IT CALLS: that piece's own Demo(character, { Freeze = n }) -- every piece module of the import has one, and it aims
	along the character's LookVector, at the training dummies if there are any:
	  WindBlade  IceMagic.ZephyrFX_WindBlade.Demo        Updraft   IceMagic.ZephyrUpdraft.Demo
	  CrossSlash IceMagic.ZephyrFX_CrossSlash.Demo       GustPad   IceMagic.ZephyrGustPad.Demo
	  Cyclone    IceMagic.ZephyrFX_Cyclone.Demo          Skyrider  IceMagic.ZephyrSkyrider.Demo (else ZephyrFX_Skyrider.Demo)
	The previous demo is stopped first: its handle's :Stop() if the Demo returned one (ZephyrDraw.Demo's handle does), and
	the module's StopDemo() if it has one. Every call is guarded.

	RESULT: the LocalPlayer attribute ZephyrDemoResult -- "<the trigger> ok", or "<the trigger> <why not>" -- and the
	Output ("[ZephyrTestHarness] ..."), for the main session to read back with execute_luau on the Client. The first
	trigger also logs which of ZephyrClient's pieces loaded (ZephyrClient.Loaded).
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic", 30)
if not iceFolder then
	warn("[ZephyrTestHarness] IceMagic never appeared: harness off")
	return
end

local ATTRIBUTE = "ZephyrDemo"
local RESULT = "ZephyrDemoResult"

-- the piece names the trigger takes -> the modules whose Demo plays them, tried in order
local DEMO_MODULES = {
	WindBlade = { "ZephyrFX_WindBlade" },
	CrossSlash = { "ZephyrFX_CrossSlash" },
	Cyclone = { "ZephyrFX_Cyclone" },
	Updraft = { "ZephyrUpdraft" },
	GustPad = { "ZephyrGustPad" },
	Skyrider = { "ZephyrSkyrider", "ZephyrFX_Skyrider" },
}

local current = nil            -- { Module = the piece module, Handle = what its Demo returned }
local toldLoaded = false

local function report(trigger, outcome)
	local line = tostring(trigger) .. " " .. tostring(outcome)
	pcall(function() player:SetAttribute(RESULT, line) end)
	print("[ZephyrTestHarness] " .. line)
end

--- Which of ZephyrClient's pieces loaded, once (the first trigger): a missing piece is the usual reason a demo fails.
local function tellLoaded()
	if toldLoaded then return end
	toldLoaded = true
	local m = iceFolder:FindFirstChild("ZephyrClient")
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and type(mod) == "table" and type(mod.Loaded) == "function" then
		local got, loaded = pcall(mod.Loaded)
		if got and type(loaded) == "table" then
			local parts = {}
			for key, state in pairs(loaded) do parts[#parts + 1] = key .. "=" .. tostring(state) end
			table.sort(parts)
			print("[ZephyrTestHarness] ZephyrClient pieces: " .. table.concat(parts, ", "))
		end
	else
		print("[ZephyrTestHarness] ZephyrClient not loaded: " .. tostring(m and mod or "missing"))
	end
end

--- Stops the demo that is up, if any: its handle's :Stop(), then its module's StopDemo().
local function stopCurrent()
	local c = current
	current = nil
	if not c then return end
	local h = c.Handle
	if type(h) == "table" and type(h.Stop) == "function" then
		local ok, err = pcall(h.Stop, h)
		if not ok then warn("[ZephyrTestHarness] stopping the last demo failed: " .. tostring(err)) end
	end
	if c.Module and type(c.Module.StopDemo) == "function" then pcall(c.Module.StopDemo) end
end

--- The piece module that can demo `name`: the first in its list that loads and has a Demo. nil and why not otherwise.
local function demoModule(name)
	local list = DEMO_MODULES[name]
	if not list then return nil, "unknown piece (one of WindBlade, CrossSlash, Cyclone, Updraft, GustPad, Skyrider)" end
	local why = list[1] .. " is not in IceMagic"
	for _, modName in ipairs(list) do
		local m = iceFolder:FindFirstChild(modName)
		if m then
			local ok, mod = pcall(require, m)
			if ok and type(mod) == "table" and type(mod.Demo) == "function" then return mod end
			why = ok and (modName .. " has no Demo") or (modName .. " failed to load: " .. tostring(mod))
		end
	end
	return nil, why
end

local function onTrigger()
	local trigger = workspace:GetAttribute(ATTRIBUTE)
	if type(trigger) ~= "string" or trigger == "" then return end
	tellLoaded()
	local name, _seq, freeze = string.match(trigger, "^%s*([%a]+)%s*:%s*([^:]*)%s*:?%s*([^:]*)%s*$")
	if not name then
		report(trigger, "unreadable (want <Piece>:<seq> or <Piece>:<seq>:<freezeSeconds>)")
		return
	end
	stopCurrent()
	if name == "Stop" then
		report(trigger, "ok (stopped)")
		return
	end
	local character = player.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		report(trigger, "no character to play it on")
		return
	end
	local mod, why = demoModule(name)
	if not mod then
		report(trigger, why)
		return
	end
	local opts = {}
	freeze = string.match(freeze or "", "^%s*(.-)%s*$")
	local n = tonumber(freeze)
	if n then
		opts.Freeze = math.max(0, n)
	elseif string.lower(freeze or "") == "ride" then
		opts.Ride = true                       -- Skyrider's local ride (any other piece ignores it)
	end
	local ok, handle = pcall(mod.Demo, character, opts)
	if not ok then
		report(trigger, "Demo failed: " .. tostring(handle))
		return
	end
	current = { Module = mod, Handle = handle }
	if handle == nil then
		report(trigger, "played, but its Demo returned nothing (no handle to stop it by)")
	else
		report(trigger, n and ("ok (frozen at " .. n .. " s)") or (opts.Ride and "ok (ride)") or "ok")
	end
end

workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(onTrigger)
-- a demo's character going away (a respawn) takes the demo with it
player.CharacterRemoving:Connect(stopCurrent)
