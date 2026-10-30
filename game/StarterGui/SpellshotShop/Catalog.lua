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
	-- (2026-10-26) the four placeholder bundles that stood here (b01-b04) are gone: bundles are BUNDLES, below
}
Catalog.BYID = {}
for _, it in ipairs(Catalog.ITEMS) do Catalog.BYID[it.id] = it end

-- BUNDLES (2026-10-26, the owner's bundle cards: final art approved from the grey-box). Not in ITEMS: a bundle holds
-- several things, so it has no single rarity or Element. CardKit.bundleCard draws one, buildBundleGrid lays out the
-- Bundles wall (one section per BUNDLE_GROUPS entry, 3 across), fillConfirm's "bundle" sheet lists everything inside.
--   headline = the big tiles; bonus = the small ones in the dashed "+ BONUS" box (generic kill effects and Cache opens:
--   the owner changed the kill-effect rule for bundle bonuses, 2026-10-26; the Design Manual still says otherwise)
--   item.tag = its rarity (Uncommon / Rare / Epic / Mythic), or, for a thing with no rarity, the word for what it is
--   (ELEMENT, SPARKS, CACHE OPEN, KILL EFFECT). item.art = "logo" (the Element's logo, item.el), "sparks", "cache",
--   "killfx" or "accessory" (placeholder art). hero = the art at rest: Element names, or "starter".
--   limited = the LIMITED tag (the Mythical Variety bundles only). rarity = "Mythic": the MYTHIC chip on the price row.
--   was = the "bought separately" price behind the strike-through; mult = the "xN VALUE" alternative (BUNDLE_VALUE).
--   ownedOff = Robux off per headline ELEMENT the player already owns (the server's "OwnedElements"): the Roster only.
-- PLACEHOLDERS: every name, amount and price except the Roster's 1,000 -> 599 and its 150 per owned Element, and the
-- Starter's ~99. Mythical Variety bundles mix Element Skins and Wraps (owner, 2026-10-26): three example mixes.
local function item(name, tag, art, el) return { name = name, tag = tag, art = art, el = el } end
Catalog.BUNDLES = {
	{ id = "bun_bloodmoon", name = "Bloodmoon Bundle", group = "Mythic", line = "MYTHIC  ·  2 SKINS + 2 WRAPS",
	  limited = true, rarity = "Mythic", price = { "Robux", 2999 }, was = 5200, mult = "x1.7", hero = { "Pyro", "Umbra", "Cryo", "Zephyr" },
	  headline = { item("Pyro Skin", "Mythic", "logo", "Pyro"), item("Umbra Skin", "Mythic", "logo", "Umbra"),
	               item("Cryo Wrap", "Mythic", "logo", "Cryo"), item("Zephyr Wrap", "Mythic", "logo", "Zephyr") }, bonus = {} },
	{ id = "bun_starfall", name = "Starfall Bundle", group = "Mythic", line = "MYTHIC  ·  3 SKINS",
	  limited = true, rarity = "Mythic", price = { "Robux", 3499 }, was = 5550, mult = "x1.6", hero = { "Radiant", "Cryo", "Terra" },
	  headline = { item("Radiant Skin", "Mythic", "logo", "Radiant"), item("Cryo Skin", "Mythic", "logo", "Cryo"),
	               item("Terra Skin", "Mythic", "logo", "Terra") }, bonus = {} },
	{ id = "bun_stormglass", name = "Stormglass Bundle", group = "Mythic", line = "MYTHIC + EPIC  ·  4 WRAPS",
	  limited = true, rarity = "Mythic", price = { "Robux", 1399 }, was = 2350, mult = "x1.7", hero = { "Voltaic", "Aqua", "Toxin", "Zephyr" },
	  headline = { item("Voltaic Wrap", "Mythic", "logo", "Voltaic"), item("Aqua Wrap", "Mythic", "logo", "Aqua"),
	               item("Toxin Wrap", "Epic", "logo", "Toxin"), item("Zephyr Wrap", "Epic", "logo", "Zephyr") }, bonus = {} },
	{ id = "bun_starter", name = "Starter Bundle", group = "More", line = "NEW PLAYERS  ·  ONE PER ACCOUNT",
	  price = { "Robux", 99 }, was = 450, mult = "x4.5", hero = "starter",
	  headline = { item("2,000 Sparks", "SPARKS", "sparks"), item("Starter Wrap", "Uncommon", "logo", "Pyro"),
	               item("Accessory", "Uncommon", "accessory") },
	  bonus = { item("Kill Effect", "KILL EFFECT", "killfx"), item("Cache Open x1", "CACHE OPEN", "cache") } },
	{ id = "bun_voltaic", name = "Voltaic Bundle", group = "More", line = "ELEMENT BUNDLE  ·  UNLOCKS VOLTAIC",
	  price = { "Robux", 449 }, was = 650, mult = "x1.4", hero = { "Voltaic" },
	  headline = { item("Voltaic", "ELEMENT", "logo", "Voltaic"), item("Voltaic Wrap", "Rare", "logo", "Voltaic"),
	               item("Accessory", "Rare", "accessory") },
	  bonus = { item("Kill Effect", "KILL EFFECT", "killfx") } },
	{ id = "bun_roster", name = "Roster Bundle", group = "More", line = "EVERY ELEMENT YOU DON'T OWN YET",
	  price = { "Robux", 599 }, was = 1000, mult = "x1.7", hero = { "Toxin", "Voltaic", "Umbra", "Aqua" }, ownedOff = 150,
	  headline = { item("Toxin", "ELEMENT", "logo", "Toxin"), item("Voltaic", "ELEMENT", "logo", "Voltaic"),
	               item("Umbra", "ELEMENT", "logo", "Umbra"), item("Aqua", "ELEMENT", "logo", "Aqua") },
	  bonus = { item("Kill Effect", "KILL EFFECT", "killfx"), item("Wrap Cache x2", "CACHE OPEN", "cache") } },
}
-- the Bundles wall's sections, in order (a bundle whose group is not listed joins the last one)
Catalog.BUNDLE_GROUPS = { { key = "Mythic", title = "MYTHICAL VARIETY" }, { key = "More", title = "MORE BUNDLES" } }
-- the value signal on every bundle card: "was" = the bought-separately price struck through (the default: most of
-- what a bundle holds has its own price, so a player can check the number), "mult" = a red "xN VALUE" chip. OPEN:
-- the owner's call; both are built, so switching is this one word.
Catalog.BUNDLE_VALUE = "was"
Catalog.BUNDLE_BYID = {}
for _, b in ipairs(Catalog.BUNDLES) do Catalog.BUNDLE_BYID[b.id] = b end

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
