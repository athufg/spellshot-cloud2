--[[
	ToxinClient  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ToxinClient

	The client half of TOXIN (ToxinHandler is the server; the first playable build, 2026-09-30). Required by
	SpellshotInput (LocalCast, Bind, FireM1) and AbilityFX (Handlers), the way RadiantClient and UmbraClient are.

	  TOXIC BUBBLES  FireM1 claims the M1 click: the arm throws (Icicle Shard's borrowed shot, cosmetic -- a dedicated clip
	                 pass is still to come) and the click's CastRequest carries the release, { Origin = the eye, Dir = the
	                 aim }. The bubble itself is the server's (it simulates the lob and decides the hit); every client,
	                 the thrower's too, draws it from the ToxinBubble broadcast.
	  THE REST       Corrosive Cloud, Antitoxin Vent, Acid Rain and Patient Zero use SpellshotInput's generic cast path
	                 (Acid Rain and Patient Zero are Targeted rows). Their arms are the generic Viewmodel.Play(Id) --
	                 nothing, until clips exist.
	  HANDLERS       every Toxin* broadcast goes to ToxinFX.Handlers, guarded: a failing or missing ToxinFX draws
	                 nothing and never stops a mechanic. ToxinPZMiss (nobody to mark) flashes the Ultimate slot.

	LOAD-TIME SAFETY: SpellshotInput requires this on its load path, so nothing here waits: ToxinFX, Viewmodel and
	SpellshotConfig are found lazily (FindFirstChild), and ToxinTuning is not needed at all.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local ToxinClient = {}
ToxinClient.LocalCast = {}
ToxinClient.Handlers = {}

----------------------------------------------------------------------------------------------------
-- modules, found lazily (never a wait on the input path)
----------------------------------------------------------------------------------------------------
local iceFolder = script.Parent
local spellFolder = ReplicatedStorage:FindFirstChild("Spellshot")
local mods = {}
local warned = {}

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ToxinClient] " .. tostring(msg))
end

local function need(name)
	if mods[name] then return mods[name] end
	spellFolder = spellFolder or ReplicatedStorage:FindFirstChild("Spellshot")
	local m = iceFolder:FindFirstChild(name) or (spellFolder and spellFolder:FindFirstChild(name))
	if not m then return nil end                     -- looked for again next time (it may not have replicated yet)
	local ok, mod = pcall(require, m)
	if not ok or type(mod) ~= "table" then
		warnOnce("load:" .. name, name .. " failed to load: " .. tostring(mod))
		return nil
	end
	mods[name] = mod
	return mod
end

local function aimCF()
	local V = need("VFXLibrary")
	local fn = V and V.LocalAimCFrame
	local ok, cf = false, nil
	if type(fn) == "function" then ok, cf = pcall(fn) end
	return (ok and typeof(cf) == "CFrame") and cf or workspace.CurrentCamera.CFrame
end

local function castRemote()
	spellFolder = spellFolder or ReplicatedStorage:FindFirstChild("Spellshot")
	return spellFolder and spellFolder:FindFirstChild("CastRequest")
end

local bound = {}
function ToxinClient.Bind(fns)
	bound = type(fns) == "table" and fns or {}
end

----------------------------------------------------------------------------------------------------
-- TOXIC BUBBLES (own)
----------------------------------------------------------------------------------------------------
local nextSide = "R"

function ToxinClient.FireM1(character, ability)
	if type(ability) ~= "table" or ability.Id ~= "ToxicBubbles" then return false end
	if not (character and character.Parent) or player.Character ~= character then return true end
	-- a two-handed cast owns the arms (Riptide's gate): the click is spent, not held over
	local VM = need("Viewmodel")
	if VM and ((type(VM.IsPlaying) == "function" and VM.IsPlaying()) or (type(VM.Tracing) == "function" and VM.Tracing())) then
		return true
	end
	if bound.CanCast and not bound.CanCast("M1", character) then
		if bound.Flash then bound.Flash("M1", true) end
		return true
	end
	local side = nextSide
	nextSide = (side == "R") and "L" or "R"
	if VM and type(VM.PlayShot) == "function" then
		local ok, err = pcall(VM.PlayShot, side, "IcicleShard")
		if not ok then warnOnce("shot", "Viewmodel.PlayShot failed: " .. tostring(err)) end
	end
	local acf = aimCF()
	local cast = castRemote()
	if cast then cast:FireServer("M1", { Origin = acf.Position, Dir = acf.LookVector, Side = side }) end
	return true
end

----------------------------------------------------------------------------------------------------
-- Handlers: the server's broadcasts, drawn for everyone by ToxinFX
----------------------------------------------------------------------------------------------------
local KINDS = {
	"ToxinBubble", "ToxinBubblePop", "ToxinBubbleRest", "ToxinBubbleExpire", "ToxinBubbleConvert",
	"ToxinCloud", "ToxinCloudEnd", "ToxinLifesteal", "ToxinSelfTick",
	"ToxinPZMark", "ToxinPZBurst", "ToxinPZCancel",
	"ToxinVent", "ToxinVentEnd", "ToxinAcidRain", "ToxinAcidTick",
}
for _, kind in ipairs(KINDS) do
	ToxinClient.Handlers[kind] = function(d)
		local F = need("ToxinFX")
		local f = F and type(F.Handlers) == "table" and F.Handlers[kind]
		if type(f) ~= "function" then return end
		local Wr = need("ToxinWrap")                                   -- (a caster's colour wrap: drawn in its palette)
		local ok, err = pcall(Wr and Wr.Run or function(_, g, x) return g(x) end, kind, f, d)
		if not ok then warnOnce("fx:" .. kind, "ToxinFX " .. kind .. " failed: " .. tostring(err)) end
	end
end

ToxinClient.Handlers.ToxinPZMiss = function()
	if bound.Flash then pcall(bound.Flash, "Ultimate", true) end
end

-- (2026-10-20) ToxinFX also keeps Witch's Brew's worn cauldron on every wearer's back from spawn, before any Toxin
-- broadcast: load it a moment after start, off the load path (need is pcall-guarded; nothing here waits)
task.delay(3, function() need("ToxinFX") end)

return ToxinClient
