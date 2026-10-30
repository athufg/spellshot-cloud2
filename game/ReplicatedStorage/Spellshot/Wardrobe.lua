--[[
	Wardrobe  (ModuleScript)  ->  ReplicatedStorage/Spellshot/Wardrobe

	THE WARDROBE'S SHARED RULES (2026-10-28): the one place the Character Editor's server (WardrobeServer) and its
	client (WardrobeEditor) agree on names, the panel's category order, Hat / Hair exclusivity and how the player
	attributes read. No state, no remotes, no item list: the items are DATA.

	THE DATA. ServerStorage.Accessories.<Category>.<Item> (hub/accessories_2026_10_28; one Accessory each, attributes
	AccessoryId, Category, Element, ElementTint, SpellshotOutfit, and SparkPrice / Rarity once they are set). Clients
	cannot see ServerStorage, so WardrobeServer mirrors it into ReplicatedStorage.Spellshot.WardrobeCatalog (the same
	folders and Accessories, cloned) and keeps the mirror in step: an item added to ServerStorage.Accessories shows in
	the panel with no change to any script.

	THE PLAYER ATTRIBUTES (written by the server only):
	  OwnedAccessories   "*" = every accessory (the Studio test override), else AccessoryIds joined by ",". NOTHING
	                     tracks accessory ownership yet (PlayerData saves Sparks and Elements only), so a live server
	                     writes "" -- every accessory is locked and shows its Sparks price.
	  WornAccessories    the AccessoryIds the player wears, joined by "," (one per category).

	THE WORN COPY'S MARKERS (on the Accessory the server puts on the character):
	  Wardrobe = "<AccessoryId>"   what it is (the server finds, keeps and re-applies its own by this)
	  SpellshotOutfit = false      UniformAvatar's strip keeps any Accessory whose SpellshotOutfit is not nil; ElementCoat's
	                               re-dress clears only the truthy ones (its coats). false = kept by the strip, left alone by
	                               the coat, with neither script changed.

	THE SKIN TONE (2026-10-28): the editor's SKIN entry -- not an accessory category (no data folder, no price: every
	tone is free for everyone). W.SkinTones is the palette, very light to very dark; the client asks for an INDEX
	(WardrobeRequest "Skin", i), the server checks it and writes
	  SkinTone           the tone's hex ("EAB892"; unset = the default, W.DefaultSkin). UniformAvatar paints it on the bare
	                     skin (W.SkinParts: the head and both hands) on every spawn, Element change and UniformStamp, and
	                     again whenever it changes. SESSION ONLY: PlayerData does not save it yet.

	OUTFITS (2026-10-29): premium full-body Outfits, worn INSTEAD of the Element coat, the accessories on top. Also
	DATA: ServerStorage.Outfits.<OutfitId> (hub/outfits_2026_10_28; a Folder of rigid Accessories, one per slot, built by
	install_outfits.lua; Folder attributes OutfitId, DisplayName, Element ("None" = any Element), RobuxPrice (0 = not
	priced), Premium, Order, Rarity). WardrobeServer mirrors it into ReplicatedStorage.Spellshot.<W.OutfitCatalogName>
	(an outfit added there shows in the editor's OUTFITS row with no change to any script) and answers
	WardrobeRequest ("EquipOutfit" | "UnequipOutfit", outfitId). ElementCoat does the dressing. Player attributes
	(server-written):
	  Outfit             the worn OutfitId; unset = the Element coat. SESSION ONLY, like the worn accessories.
	  OwnedOutfits       "*" = every outfit, else OutfitIds joined by ",": the same switch as OwnedAccessories
	                     (WardrobeServer's FREE_ALL / STUDIO_TEST_OWN_ALL). A locked outfit shows its Robux price.
	An outfit with an Element dresses only while the player is that Element (its colours are that Element's): the coat
	shows otherwise, and the outfit comes back with the Element.

	OUTFIT HEAD-PIECES (2026-10-29, hub/outfit_heads_2026_10_29): each outfit's head-piece is an ORDINARY Hat in
	ServerStorage.Accessories.Hats (install_outfit_heads.lua) carrying OutfitHead = <OutfitId> (W.HeadAttr); the outfit's
	Folder carries HeadPiece = <AccessoryId>. It is owned whenever its outfit is owned (W.Owns), the Hats row tags it
	OUTFIT, and WardrobeServer puts it on through the normal Hat equip (Hair comes off, the worn set changes, nothing
	else) the moment ElementCoat dresses its outfit -- once per outfit equip: a swap to any other Hat or Hair afterwards
	stays. ElementCoat marks the character with the outfit it dressed:
	  DressedOutfit      (character attribute) the OutfitId ElementCoat has on this body; unset = the coat.
]]

local W = {}

W.CatalogName = "WardrobeCatalog"        -- ReplicatedStorage.Spellshot.<this>: the server's mirror of the data
W.RemoteName = "WardrobeRequest"         -- ReplicatedStorage.Spellshot.<this>: RemoteFunction ("Equip" | "Unequip", id)
W.OwnedAttr = "OwnedAccessories"
W.WornAttr = "WornAccessories"
W.Mark = "Wardrobe"

-- the panel's order; a category folder in the data that is not listed here still shows, after these
W.Categories = { "Masks", "Pendants", "Hair", "Glasses", "Hats" }
W.Singular = { Masks = "MASK", Pendants = "PENDANT", Hair = "HAIR", Glasses = "GLASSES", Hats = "HAT" }

-- wearing one takes the other off (the owner's rule: a hat and hair never share the head). Enforced by the server.
W.Exclusive = { Hats = { "Hair" }, Hair = { "Hats" },
	Glasses = { "Masks" }, Masks = { "Glasses" } }   -- (2026-10-28, the owner) glasses OR a mask: both sit on the face

-- (2026-10-28) THE SKIN TONE: see the header
W.SkinAttr = "SkinTone"
W.SkinKey = "Skin"                       -- the editor rail's entry for it (a data folder of this name is not listed)
W.SkinParts = { "Head", "LeftHand", "RightHand" }   -- the bare skin (UniformAvatar's): everything else is clothes
W.SkinTones = {                          -- natural human skin, very light to very dark
	{ Hex = "FBE3D0", Name = "PORCELAIN" },
	{ Hex = "F3CFB3", Name = "IVORY" },
	{ Hex = "EAB892", Name = "PEACH" },  -- the default: the hub NPCs' tone (UniformAvatar's BODY.Skin before 2026-10-28)
	{ Hex = "DDA27A", Name = "SAND" },
	{ Hex = "C98B5F", Name = "HONEY" },
	{ Hex = "B0754A", Name = "CARAMEL" },
	{ Hex = "94603A", Name = "BRONZE" },
	{ Hex = "7A4A2C", Name = "CHESTNUT" },
	{ Hex = "5E3820", Name = "COCOA" },
	{ Hex = "4A2B19", Name = "MAHOGANY" },
	{ Hex = "36200F", Name = "EBONY" },
}
W.DefaultSkin = 3
for _, t in ipairs(W.SkinTones) do t.Color = Color3.fromHex(t.Hex) end

--- a hex ("EAB892" / "#eab892") -> its palette index, else nil
function W.SkinIndex(hex)
	if type(hex) ~= "string" then return nil end
	hex = string.upper((string.gsub(hex, "^#", "")))
	for i, t in ipairs(W.SkinTones) do
		if t.Hex == hex then return i end
	end
	return nil
end

--- the player's tone: index, Color3 (an unset or off-palette SkinTone = the default)
function W.SkinOf(player)
	local i = W.SkinIndex(player and player:GetAttribute(W.SkinAttr)) or W.DefaultSkin
	return i, W.SkinTones[i].Color
end

--- paint the bare skin (the head and both hands), and a BodyColors' head too if one is there
function W.PaintSkin(character, colour)
	if not character then return end
	for _, name in ipairs(W.SkinParts) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then part.Color = colour end
	end
	local bc = character:FindFirstChildOfClass("BodyColors")
	if bc then bc.HeadColor3 = colour end
end

--- "*" / "a,b,c" -> set (all = true for "*")
function W.ParseSet(attr)
	local set = {}
	if attr == "*" then return set, true end
	if type(attr) == "string" then
		for id in string.gmatch(attr, "[^,]+") do set[id] = true end
	end
	return set, false
end

--- acc (optional): the item's Accessory -- an Outfit head-piece (W.HeadAttr) is owned whenever its outfit is
function W.Owns(player, id, acc)
	local set, all = W.ParseSet(player:GetAttribute(W.OwnedAttr))
	if all or set[id] == true then return true end
	local outfit = acc and acc:GetAttribute(W.HeadAttr)
	return type(outfit) == "string" and outfit ~= "" and W.OwnsOutfit(player, outfit)
end

function W.WornSet(player)
	return (W.ParseSet(player:GetAttribute(W.WornAttr)))
end

--- the categories in a catalog folder: W.Categories first (each, even when empty or missing), then any other folder
function W.CategoriesIn(folder)
	local list, seen = {}, {}
	for _, c in ipairs(W.Categories) do
		list[#list + 1] = c
		seen[c] = true
	end
	local extra = {}
	for _, f in ipairs(folder and folder:GetChildren() or {}) do
		if f:IsA("Folder") and not seen[f.Name] then extra[#extra + 1] = f.Name end
	end
	table.sort(extra)
	for _, c in ipairs(extra) do list[#list + 1] = c end
	return list
end

--- one item's facts, from its Accessory's attributes
function W.Info(acc)
	local price = acc:GetAttribute("SparkPrice")
	return {
		Id = acc:GetAttribute("AccessoryId") or acc.Name,
		Name = acc.Name,
		Category = acc:GetAttribute("Category") or (acc.Parent and acc.Parent.Name),
		Element = acc:GetAttribute("Element"),
		Tint = acc:GetAttribute("ElementTint") == true,
		Rarity = acc:GetAttribute("Rarity"),
		Price = (type(price) == "number" and price > 0) and math.floor(price) or nil,
		Outfit = acc:GetAttribute(W.HeadAttr),   -- (2026-10-29) an Outfit's head-piece: that OutfitId
	}
end

-- (2026-10-29) OUTFITS: see the header
W.OutfitKey = "Outfits"                  -- the editor rail's entry for them (after SKIN; not an accessory category)
W.OutfitCatalogName = "OutfitCatalog"    -- ReplicatedStorage.Spellshot.<this>: the server's mirror of ServerStorage.Outfits
W.OutfitAttr = "Outfit"
W.OutfitOwnedAttr = "OwnedOutfits"
W.HeadAttr = "OutfitHead"                -- (2026-10-29) on a Hat: the OutfitId it is the head-piece of
W.HeadPieceAttr = "HeadPiece"            -- on an outfit Folder: its head-piece's AccessoryId
W.DressedOutfitAttr = "DressedOutfit"    -- on a character: the OutfitId ElementCoat has dressed on it (unset = the coat)

function W.OwnsOutfit(player, id)
	local set, all = W.ParseSet(player:GetAttribute(W.OutfitOwnedAttr))
	return all or set[id] == true
end

--- the Element an outfit is locked to, else nil (any Element: the attribute unset, "" or "None")
function W.OutfitElement(folder)
	local el = folder and folder:GetAttribute("Element")
	if type(el) ~= "string" or el == "" or el == "None" then return nil end
	return el
end

--- one outfit's facts, from its Folder's attributes
function W.OutfitInfo(folder)
	local price = folder:GetAttribute("RobuxPrice")
	return {
		Id = folder:GetAttribute("OutfitId") or folder.Name,
		Name = folder:GetAttribute("DisplayName") or folder.Name,
		Element = W.OutfitElement(folder),
		Rarity = folder:GetAttribute("Rarity"),
		Robux = (type(price) == "number" and price > 0) and math.floor(price) or nil,
		Premium = folder:GetAttribute("Premium") == true,
		Order = tonumber(folder:GetAttribute("Order")) or 1e6,
		Folder = folder,
	}
end

--- the outfits in a catalog folder (each a Folder holding Accessories), by Order then name
function W.Outfits(folder)
	local list = {}
	for _, f in ipairs(folder and folder:GetChildren() or {}) do
		if f:IsA("Folder") and f:FindFirstChildWhichIsA("Accessory") then list[#list + 1] = W.OutfitInfo(f) end
	end
	table.sort(list, function(x, y)
		if x.Order ~= y.Order then return x.Order < y.Order end
		return x.Name < y.Name
	end)
	return list
end

--- a category's Accessories (sorted by an Order attribute, then by name), as { Info..., Acc = the instance }
function W.Items(folder, category)
	local f = folder and folder:FindFirstChild(category)
	local list = {}
	for _, a in ipairs(f and f:GetChildren() or {}) do
		if a:IsA("Accessory") and a:FindFirstChild("Handle") then
			local info = W.Info(a)
			info.Acc = a
			info.Order = tonumber(a:GetAttribute("Order")) or 1e6
			list[#list + 1] = info
		end
	end
	table.sort(list, function(x, y)
		if x.Order ~= y.Order then return x.Order < y.Order end
		return x.Name < y.Name
	end)
	return list
end

return W
