--[[
	EconomyService  (Script)  ->  ServerScriptService/EconomyService

	(2026-10-18, economy) Starts ServerScriptService.PlayerData (saves, the starter kit, ProcessReceipt) and answers the
	one economy remote. Everything about WHAT is owned and what it costs lives in PlayerData and EconomyConfig.

	THE REMOTE. ReplicatedStorage.Spellshot.EconomyRequest (RemoteFunction), made here at startup:

	  client -> server   InvokeServer("UnlockElement", element)
	  server -> client   ok (bool), code (string), message (string), sparks (number), need (number)

	  code is PlayerData.BuyElement's: "ok" | "owned" | "short" | "unknown" | "notforsale" | "loading" | "offline" |
	  "busy" (asked again within MIN_GAP). The menu shows `message`; the new balance and the owned set arrive as the
	  player's attributes anyway, so nothing else needs the reply.

	TRUST. The client says only WHICH Element. Whether it exists, is built, is already owned, what it costs and whether
	the balance covers it are all decided here, from the save.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

PlayerData.Start()

local MIN_GAP = 0.5                   -- fastest a client may ask

local remote = folder:FindFirstChild("EconomyRequest")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "EconomyRequest"
	remote.Parent = folder
end

local lastAt = setmetatable({}, { __mode = "k" })

local function fmt(n)
	local s = tostring(math.floor(n))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then return s end
	end
end

local function display(element)
	local def = Config.Elements[element]
	return string.upper(def and def.Display or tostring(element))
end

local MESSAGES = {
	ok = function(el, info) return ("%s unlocked! %s Sparks left. Pick it to equip it."):format(display(el), fmt(info.Sparks)) end,
	owned = function(el) return ("You already own %s."):format(display(el)) end,
	short = function(el, info)
		return ("%s costs %s Sparks: you need %s more. Win matches, or get a Sparks pack in the Shop.")
			:format(display(el), fmt(info.Price), fmt(info.Need))
	end,
	unknown = function() return "There is no such Element to unlock." end,
	notforsale = function(el) return ("%s can't be bought with Sparks."):format(display(el)) end,
	loading = function() return "Your Elements are still loading. Try again in a moment." end,
	offline = function() return "Your progress could not be loaded, so unlocks are paused. Rejoin to try again." end,
}

remote.OnServerInvoke = function(player, what, element)
	local now = os.clock()
	if now - (lastAt[player] or 0) < MIN_GAP then
		return false, "busy", "One moment...", player:GetAttribute("Sparks") or 0, 0
	end
	lastAt[player] = now
	if what == "UnlockElement" then
		local ok, code, info = PlayerData.BuyElement(player, element)
		info = info or {}
		local say = MESSAGES[code] or MESSAGES.unknown
		return ok, code, say(element, info), player:GetAttribute("Sparks") or 0, info.Need or 0
	end
	return false, "unknown", "Unknown request.", player:GetAttribute("Sparks") or 0, 0
end
