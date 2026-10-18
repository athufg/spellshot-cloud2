--[[ Catalog (ModuleScript) -> StarterGui.SpellshotShop.Catalog
SPELLSHOT shop: the ONE source of what the shop sells. ShopController and the builder read only this.
The tables are the v3 shared base's (src/_base.luau) as plain data, plus the Pass tiers and the daily-reward day.

PLACEHOLDERS, all of it: names are invented, odds are placeholder odds, tiers are placeholder rewards.
PRICES ARE BASE PRICES. Live Robux prices are REGIONAL (a player can be shown less than the Dashboard price), so a
real build must read each product's live price from MarketplaceService and never show these numbers as charged.
BAL.robux IS A PLACEHOLDER: Roblox gives games no API to read a player's Robux (the gui's RobuxBalance carries
Placeholder=true). BAL.sparks will come from the player's saved data once the shop is wired.
kind: Skin = a new visual model for an Element; Tint = a recolour of an Element's look. Mythic is bought directly
AND drops from the Cache (owner decision).
]]
local Catalog = {}

Catalog.ITEMS = {
	{ id = "s01", name = "Inferno Reaper",    kind = "Skin",   el = "Pyro",    rarity = "Epic",     price = { "Robux", 650 } },
	{ id = "s02", name = "Void Fire",         kind = "Skin",   el = "Pyro",    rarity = "Epic",     price = { "Robux", 500 } },
	{ id = "s03", name = "Glacier Warden",    kind = "Skin",   el = "Cryo",    rarity = "Rare",     price = { "Robux", 250 } },
	{ id = "s04", name = "Frostbite",         kind = "Skin",   el = "Cryo",    rarity = "Common",   price = { "Sparks", 1500 } },
	{ id = "s05", name = "Stormcaller",       kind = "Skin",   el = "Voltaic", rarity = "Mythic",   price = { "Robux", 950 } },
	{ id = "s06", name = "Arc Bolt",          kind = "Skin",   el = "Voltaic", rarity = "Rare",     price = { "Robux", 200 } },
	{ id = "s07", name = "Basalt Titan",      kind = "Skin",   el = "Terra",   rarity = "Epic",     price = { "Robux", 600 } },
	{ id = "s08", name = "Gale Runner",       kind = "Skin",   el = "Zephyr",  rarity = "Common",   price = { "Sparks", 1200 } },
	{ id = "s09", name = "Riptide Rogue",     kind = "Skin",   el = "Aqua",    rarity = "Rare",     price = { "Robux", 220 } },
	{ id = "s10", name = "Nightshade",        kind = "Skin",   el = "Umbra",   rarity = "Mythic",   price = { "Robux", 800 } },
	{ id = "s11", name = "Halo Knight",       kind = "Skin",   el = "Radiant", rarity = "Seasonal", price = { "Robux", 700 } },
	{ id = "s12", name = "Blight Spore",      kind = "Skin",   el = "Toxin",   rarity = "Common",   price = { "Sparks", 1000 } },
	{ id = "t01", name = "Ember Tint",        kind = "Tint",   el = "Pyro",    rarity = "Common",   price = { "Sparks", 600 } },
	{ id = "t02", name = "Aurora Tint",       kind = "Tint",   el = "Cryo",    rarity = "Rare",     price = { "Robux", 150 } },
	{ id = "t03", name = "Neon Tint",         kind = "Tint",   el = "Voltaic", rarity = "Common",   price = { "Sparks", 600 } },
	{ id = "t04", name = "Obsidian Tint",     kind = "Tint",   el = "Terra",   rarity = "Epic",     price = { "Robux", 300 } },
	{ id = "t05", name = "Twilight Tint",     kind = "Tint",   el = "Umbra",   rarity = "Rare",     price = { "Robux", 150 } },
	{ id = "t06", name = "Sunburst Tint",     kind = "Tint",   el = "Radiant", rarity = "Seasonal", price = { "Robux", 250 } },
	{ id = "b01", name = "Pyro Starter Pack", kind = "Bundle", el = "Pyro",    rarity = "Epic",     price = { "Robux", 499 }, value = "x3 VALUE", contains = "2 Skins + 1 Tint" },
	{ id = "b02", name = "Frost Bundle",      kind = "Bundle", el = "Cryo",    rarity = "Epic",     price = { "Robux", 799 }, value = "x4 VALUE", contains = "3 Skins + 2 Tints" },
	{ id = "b03", name = "Umbra Full Set",    kind = "Bundle", el = "Umbra",   rarity = "Mythic",   price = { "Robux", 1200 }, value = "x5 VALUE", contains = "Every Umbra Skin + Tint" },
	{ id = "b04", name = "New Player Pack",   kind = "Bundle", el = "Zephyr",  rarity = "Rare",     price = { "Robux", 99 },  value = "x6 VALUE", contains = "1 Skin + 2 Tints + 2,000 Sparks" },
}
Catalog.BYID = {}
for _, it in ipairs(Catalog.ITEMS) do Catalog.BYID[it.id] = it end

-- today's rotation (placeholder: a real build rotates at 00:00 UTC, which is what the live countdown counts to)
Catalog.DAILY = { ids = { "s02", "s06", "t04", "s08" }, refresh = "10h 51m", day = 3, days = 7 }

Catalog.CACHE = { id = "cache", name = "Elemental Cache", key = "Cache Key", price = { "Robux", 100 },
	contents = "1 random Skin or Tint",
	odds = { { "Common", 70 }, { "Rare", 24 }, { "Epic", 5 }, { "Mythic", 1 } } }   -- PLACEHOLDER odds

Catalog.PASS = { id = "pass", name = "Season Pass", sub = "Season 1 · Rift Pass", price = { "Robux", 950 }, level = 9, levels = 50,
	unlocks = "Unlocks every PREMIUM reward in Season 1",
	-- the next tiers after the player's level (PLACEHOLDER rewards). track: Free = everyone, Premium = with the pass
	tiers = {
		{ lv = 10, track = "Free",    kind = "Sparks", amount = 250 },
		{ lv = 11, track = "Premium", kind = "Tint",   name = "Rift Tint",  el = "Umbra", rarity = "Rare" },
		{ lv = 12, track = "Free",    kind = "Sparks", amount = 300 },
		{ lv = 13, track = "Premium", kind = "Sparks", amount = 600 },
		{ lv = 14, track = "Free",    kind = "Sparks", amount = 400 },
		{ lv = 15, track = "Premium", kind = "Skin",   name = "Riftwalker", el = "Umbra", rarity = "Epic" },
	} }

Catalog.BAL = { sparks = 12450, robux = 1250 }   -- robux is a PLACEHOLDER (see the header)

return Catalog
