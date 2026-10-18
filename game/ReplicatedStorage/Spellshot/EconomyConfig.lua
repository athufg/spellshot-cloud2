--[[
	EconomyConfig  (ModuleScript)  ->  ReplicatedStorage/Spellshot/EconomyConfig

	(2026-10-18, economy) Every number in SPELLSHOT's economy, and nothing else: no state, no remotes, no DataStore.
	The server (ServerScriptService.PlayerData) and the clients (LoadoutMenu, the shop) both read it, so a price is
	written once and the menu can never show one the server does not charge.

	THE DECISION (owner, locked 2026-10-18; the AMOUNTS are still open):
	  * Sparks is the one currency. The 9 base Elements are bought with it: Sparks come from playing, or from a Sparks
	    pack bought with Robux to skip the grind.
	  * Every player owns the STARTER KIT from their first join -- fixed, no choice screen.
	  * Skins and wraps stay Robux-only (the shop's own logic, untouched by this file).
	  * Event / collab Elements are a separate track, later. Ownership is keyed by Element NAME, so any future Element
	    id fits; one that must never be sold for Sparks goes in NotForSale.

	EVERY AMOUNT BELOW MARKED "PLACEHOLDER" IS ONE. The yardstick used to pick them: a first-to-5 duel WIN pays
	Win + 5 x PerRoundWon = 200 Sparks, so an Element costs about 8-10 wins.
]]

local Economy = {}

Economy.Currency = "Sparks"

----------------------------------------------------------------------------------------------------
-- the starter kit (owner, locked)
----------------------------------------------------------------------------------------------------
-- Granted once per player (PlayerData keeps a per-Element record of what it granted, so adding a starter here later
-- gives it to everyone once, and removing one never takes it from anyone who has it). Until a player's save has
-- loaded, these are what they own -- nobody is ever locked out of the starters by a slow DataStore.
Economy.StarterElements = { "Pyro", "Zephyr", "Cryo", "Terra", "Radiant" }

----------------------------------------------------------------------------------------------------
-- Element prices, in Sparks  (PLACEHOLDER amounts)
----------------------------------------------------------------------------------------------------
Economy.ElementPrice = {
	Default = 1800,      -- PLACEHOLDER: any Element without its own line (9 duel wins)
	Aqua = 1600,         -- PLACEHOLDER (8 wins)
	Toxin = 1800,        -- PLACEHOLDER (9 wins)
	Umbra = 2000,        -- PLACEHOLDER (10 wins)
	Voltaic = 2000,      -- PLACEHOLDER (10 wins)
}

-- Elements that can never be bought with Sparks (the event / collab track, later): [name] = true
Economy.NotForSale = {}

----------------------------------------------------------------------------------------------------
-- match rewards, in Sparks  (PLACEHOLDER amounts)
----------------------------------------------------------------------------------------------------
-- PlayerData.AwardMatch(player, result, roundsWon) pays MatchReward[result] + PerRoundWon x roundsWon.
Economy.MatchReward = {
	win = 150,           -- PLACEHOLDER
	loss = 50,           -- PLACEHOLDER: a loss still pays, so a losing streak still moves toward an Element
	draw = 75,           -- PLACEHOLDER
}
Economy.PerRoundWon = 10        -- PLACEHOLDER
Economy.MaxRoundsCounted = 10   -- a caller passing more is clamped here (a duel is first to 5)

----------------------------------------------------------------------------------------------------
-- Sparks packs (Robux)  (PLACEHOLDER amounts)
----------------------------------------------------------------------------------------------------
-- ProductId = 0 means "not on sale yet": the shop says so instead of prompting. The owner creates one Developer
-- Product per pack on the Creator Dashboard (Monetization > Developer Products), sets its Robux price there, and
-- pastes its id here. RobuxDisplay is only what the shop prints; Roblox charges the Dashboard price (and may show a
-- player a lower regional price), so keep the two in step by hand.
Economy.SparksPacks = {
	{ Id = "Pouch",  Name = "Pouch of Sparks",  Sparks = 500,  RobuxDisplay = 49,  ProductId = 0 },   -- PLACEHOLDER
	{ Id = "Satchel", Name = "Satchel of Sparks", Sparks = 1200, RobuxDisplay = 99,  ProductId = 0 },   -- PLACEHOLDER
	{ Id = "Chest",  Name = "Chest of Sparks",  Sparks = 2600, RobuxDisplay = 199, ProductId = 0 },   -- PLACEHOLDER
	{ Id = "Vault",  Name = "Vault of Sparks",  Sparks = 7000, RobuxDisplay = 499, ProductId = 0 },   -- PLACEHOLDER
}

----------------------------------------------------------------------------------------------------
-- helpers (both sides)
----------------------------------------------------------------------------------------------------
local STARTER = {}
for _, name in ipairs(Economy.StarterElements) do STARTER[name] = true end

function Economy.IsStarter(element)
	return STARTER[element] == true
end

--- The Sparks price of `element`, or nil when it cannot be bought with Sparks.
function Economy.PriceOf(element)
	if type(element) ~= "string" or Economy.NotForSale[element] then return nil end
	local p = Economy.ElementPrice[element]
	if p == nil then p = Economy.ElementPrice.Default end
	return (type(p) == "number" and p > 0) and math.floor(p) or nil
end

--- What a match pays: nil for a result that is not "win" | "loss" | "draw".
function Economy.MatchSparks(result, roundsWon)
	local base = Economy.MatchReward[result]
	if type(base) ~= "number" then return nil end
	local rounds = math.clamp(math.floor(tonumber(roundsWon) or 0), 0, Economy.MaxRoundsCounted)
	return base + Economy.PerRoundWon * rounds
end

--- The pack sold as Developer Product `productId`, or nil. (0 is never a pack: it means "not on sale yet".)
function Economy.PackByProductId(productId)
	if type(productId) ~= "number" or productId <= 0 then return nil end
	for _, pack in ipairs(Economy.SparksPacks) do
		if pack.ProductId == productId then return pack end
	end
	return nil
end

--- The player attribute "OwnedElements" ("Cryo,Pyro,...") as a set. No attribute yet = the starter kit.
function Economy.ParseOwned(attr)
	local set = {}
	if type(attr) ~= "string" then
		for name in pairs(STARTER) do set[name] = true end
		return set
	end
	for name in string.gmatch(attr, "[^,]+") do set[name] = true end
	return set
end

return Economy
