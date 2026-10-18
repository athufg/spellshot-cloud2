--[[
	LoadoutMenu  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/LoadoutMenu

	PLACEHOLDER. A small panel for the two choices the manual separates:

	  YOUR ELEMENT      what your M1, your Primary, your Passive and (v0.7, 2026-09-24) your Ultimate
	                    are. One of eight.
	  YOUR TECHNIQUES   the two you carry (Technique 1 and 2, Q and E by default), BOTH drawn from ONE
	                    pool that every Element contributes to -- so a Cryo player can run Pyro's
	                    Scorching Lash. That is why this is two choices and not one.

	ALL EIGHT ELEMENTS ARE LISTED; NOT ALL ARE BUILT. Config.BuiltElements says which may be picked
	(Cryo and Pyro in full, Zephyr in part); the rest are drawn dimmed and marked SOON: they are designed
	in SpellshotConfig -- name, archetype, colours, M1, Primary, Passive, and one Technique each in the
	three pools -- and nothing is built. A partly built Element (Config.PartialKits) can be picked and is
	tagged with what is live; its unbuilt Techniques stay locked like an unbuilt Element's. Picking
	anything with no cast path is refused here and again by the server.

	THE v0.7 LOADOUT (2026-09-24; it replaces the 2026-09-23 Element-fixed slots): the ULTIMATE row shows
	the Element's own, and its arrows are dimmed and only say why. The two TECHNIQUE rows browse the same
	pool, each skipping the Technique the other row holds, and hide what the Element may not hold
	(Detonate is Pyro's only). Picking an Element may equip its default Techniques (Pyro: Detonate and
	Scorching Lash) -- the server does that, and the rows follow. The rows never say "Mobility" or
	"Defense": those are only the slots' internal names (Config.SlotLabel).

	It is a placeholder in look, not in behaviour: what it does select is really equipped, through
	Spellshot.LoadoutRequest, which validates every choice server-side. The art is the same
	newsprint kit as the settings panel because it costs nothing to match.

	For tools: the ScreenGui carries a BindableEvent "Command" -- Fire("open"), Fire("close"),
	Fire("element", name), Fire("technique", role, key), Fire("skin", skinId), Fire("view", "Techniques" | "Skins"
	(the wraps) | "ElementSkins"), and (2026-10-18, economy) Fire("unlock", name) (the UNLOCK confirm for a locked
	Element) and Fire("confirm") (that confirm's UNLOCK / GET SPARKS button).

	OWNED AND LOCKED (2026-10-18, economy). The server says what the player owns ("OwnedElements") and holds ("Sparks"),
	both player attributes written by ServerScriptService.PlayerData; the prices are EconomyConfig's. A built Element the
	player does not own wears a padlock, its price and an UNLOCK button: it can be browsed (the footer reads out its kit)
	but not equipped. UNLOCK opens a confirm in this panel, which asks Spellshot.EconomyRequest; the server checks it all
	again and the grid follows the attributes. Short of Sparks, the confirm says how many more and offers GET SPARKS (the
	shop, on its packs). The header's right end shows the balance.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local Icons = require(folder:WaitForChild("IconAssets"))
local Skins = require(folder:WaitForChild("SkinCatalog"))
local loadoutRemote = folder:WaitForChild("LoadoutRequest")
-- (2026-10-18, economy) prices and the starter kit; the remote is looked up when UNLOCK is pressed (EconomyService)
local Economy = require(folder:WaitForChild("EconomyConfig"))

local DOT = "rbxassetid://82944445925061"     -- BarKit's halftone cell, as the settings panel uses

local C = {
	Ink = Color3.fromRGB(17, 17, 17),
	Paper = Color3.fromRGB(234, 229, 216),
	Card = Color3.fromRGB(246, 243, 235),
	Pill = Color3.fromRGB(250, 247, 240),
	RedInk = Color3.fromRGB(200, 30, 26),
	CreamText = Color3.fromRGB(250, 244, 232),
	CreamDim = Color3.fromRGB(206, 200, 188),
	Track = Color3.fromRGB(222, 213, 196),
	Grey = Color3.fromRGB(120, 116, 106),
	Hover = Color3.fromRGB(224, 218, 202),
	Green = Color3.fromRGB(126, 204, 36),
	Gold = Color3.fromRGB(245, 184, 0),     -- (2026-10-18, economy) GET SPARKS
}
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)   -- the kit's small labels

-- 352 high, not 322: the right column is a 30 px banner plus three 62 px rows with gaps (248),
-- and the footer line sits under that, not on top of it. 395 (2026-10-13): one more Element-grid row, for the SKINS card
-- under WRAPS.
local DESIGN_W, DESIGN_H = 660, 395
local HEAD_H = 44
local CURSOR_STEP = "SpellshotLoadoutCursor"
local ROLES = { "Mobility", "Defense", "Ultimate" }

----------------------------------------------------------------------------------------------------
-- kit
----------------------------------------------------------------------------------------------------
local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function corner(parent, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function outline(parent, t)
	return make("UIStroke", { Color = C.Ink, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function text(parent, props)
	local t = make("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = C.Ink, TextSize = 14,
		Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props) do t[k] = v end
	return t
end

local function halftone(parent, radius, alpha, colour, pitch)
	local h = make("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = DOT, ImageColor3 = colour or Color3.new(1, 1, 1),
		ImageTransparency = alpha or 0.88, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(pitch or 8, pitch or 8), Size = UDim2.fromScale(1, 1), ZIndex = 2,
	}, parent)
	corner(h, radius)
	return h
end

--- Flat colour, ink outline, hard offset shadow. Returns holder, face.
local function slab(parent, size, pos, colour, radius, shadow)
	local holder = make("Frame", { BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new() }, parent)
	if shadow and shadow > 0 then
		local sh = make("Frame", {
			Name = "Shadow", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.2, BorderSizePixel = 0,
			Size = UDim2.new(1, -shadow, 1, -shadow), Position = UDim2.fromOffset(shadow, shadow), ZIndex = 1,
		}, holder)
		corner(sh, radius)
	end
	local face = make("Frame", {
		Name = "Face", BackgroundColor3 = colour, BorderSizePixel = 0,
		Size = UDim2.new(1, -(shadow or 0), 1, -(shadow or 0)), ZIndex = 2,
	}, holder)
	corner(face, radius)
	outline(face, 2)
	return holder, face
end

local function hitbox(parent, z)
	return make("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = z or 8,
	}, parent)
end

-- THE SPARKS MARK (2026-10-18, economy): the shop's own drawing (SpellshotShop.CardKit.sparksIcon, its flat cut) --
-- borrowed, not redrawn, so the currency has one face. The shop's gui can arrive after this script runs, so a mark is
-- a holder that is filled the moment CardKit can be required.
local sparkKit, sparkHolders = nil, {}
local function fillSpark(h)
	if sparkKit and h.Parent and not h:FindFirstChild("SparksIcon") then
		sparkKit.sparksIcon(h, 0, 0, h:GetAttribute("S"), h.ZIndex, true)
	end
end
local function sparkMark(parent, s, pos, z)
	local h = make("Frame", { Name = "SparksMark", BackgroundTransparency = 1, Size = UDim2.fromOffset(s, s),
		Position = pos or UDim2.new(), ZIndex = z or 14 }, parent)
	h:SetAttribute("S", s)
	sparkHolders[#sparkHolders + 1] = h
	fillSpark(h)
	return h
end
task.spawn(function()
	local shop = playerGui:WaitForChild("SpellshotShop", 60)
	local kit = shop and shop:WaitForChild("CardKit", 10)
	local ok, K = pcall(function() return kit and require(kit) end)
	if not (ok and type(K) == "table" and K.sparksIcon) then return end
	sparkKit = K
	for _, h in ipairs(sparkHolders) do fillSpark(h) end
end)

--- 12450 -> "12,450"
local function fmt(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then return s end
	end
end

--- A padlock on a small ink plate (cream shackle and body): a locked Element's badge.
local function lockBadge(parent, pos, z)
	local b = make("Frame", { Name = "Lock", BackgroundColor3 = C.Ink, BorderSizePixel = 0, Position = pos,
		Size = UDim2.fromOffset(15, 15), ZIndex = z, Visible = false }, parent)
	corner(b, 3)
	local shackle = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(7, 8), ZIndex = z + 1 }, b)
	corner(shackle, 3)
	make("UIStroke", { Color = C.CreamText, Thickness = 1.5 }, shackle)
	corner(make("Frame", { BackgroundColor3 = C.CreamText, BorderSizePixel = 0, Position = UDim2.fromOffset(3, 7),
		Size = UDim2.fromOffset(9, 6), ZIndex = z + 2 }, b), 1)
	return b
end

----------------------------------------------------------------------------------------------------
-- what is equipped, and what may be
----------------------------------------------------------------------------------------------------
local function currentElement()
	return player:GetAttribute("Element") or Config.DefaultLoadout.Element
end

--- (2026-10-18, economy) The Elements the player owns, as the server last said (the starter kit until it has).
local function ownedSet()
	return Economy.ParseOwned(player:GetAttribute("OwnedElements"))
end

local function sparks()
	return tonumber(player:GetAttribute("Sparks")) or 0
end

local function currentTechnique(role)
	return player:GetAttribute(role) or Config.DefaultLoadout[role]
end

--- The other Technique slot: the same Technique is never in both.
local function otherSlot(role)
	return (role == "Mobility") and "Defense" or "Mobility"
end

--- The current Element's own Ultimate (its pool entry), or nil.
local function ownUltimate(element)
	return Config.Ultimate[Config.ElementUltimate(element) or ""]
end

local function elementDisplay(name)
	local def = Config.Elements[name]
	return def and def.Display or name
end

--- Elements in the manual's own order, so the grid never shuffles.
local function elementsInOrder()
	local list = {}
	for name, def in pairs(Config.Elements) do
		list[#list + 1] = { Name = name, Def = def }
	end
	table.sort(list, function(a, b) return (a.Def.Order or 99) < (b.Def.Order or 99) end)
	return list
end

--- The Technique pool both rows browse (v0.7, 2026-09-24: both halves of it), in Element order, without what the
--- current Element may not hold (Detonate off Pyro).
local function techniqueList()
	local element = currentElement()
	local list = {}
	for _, half in ipairs(Config.TechniqueSlots) do
		for key, entry in pairs(Config[half]) do
			if Config.ElementMayHold(element, key) then
				list[#list + 1] = { Key = key, Entry = entry, Order = (Config.Elements[entry.Origin] or {}).Order or 99 }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Key < b.Key
	end)
	return list
end

----------------------------------------------------------------------------------------------------
-- the screen
----------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("LoadoutMenu")
if old then old:Destroy() end

local gui = make("ScreenGui", {
	Name = "LoadoutMenu", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 41, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local command = make("BindableEvent", { Name = "Command" }, gui)

-- the opener: a LOADOUT button in the top strip, just left of the settings gear, wearing your Element. Labelled at the
-- user's ask (2026-09-15): as a bare Element icon it did not read as the way into the loadout.
local chipSize = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and 52 or 44
local LABEL_W = 88              -- the LOADOUT label beside the icon; QuickPlay's PLAY sits this much further left
local chipHolder, chipFace = slab(gui, UDim2.fromOffset(chipSize + LABEL_W + 3, chipSize + 3), nil, C.Pill, 5, 3)
chipHolder.Name = "LoadoutButton"
chipHolder.AnchorPoint = Vector2.new(1, 0)
chipHolder.Position = UDim2.new(1, -14 - chipSize - 9, 0, 7)
local chipIcon = make("ImageLabel", {
	Name = "Icon", BackgroundTransparency = 1, Image = Icons.Element[currentElement()] or "",
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, chipSize / 2, 0.5, 0),
	Size = UDim2.fromOffset(chipSize * 0.86, chipSize * 0.86), ZIndex = 3,
}, chipFace)
text(chipFace, {
	Name = "Label", Font = Enum.Font.Bangers, Text = "LOADOUT", TextSize = 24, TextColor3 = C.Ink,
	Position = UDim2.fromOffset(chipSize - 4, 1), Size = UDim2.new(1, -(chipSize - 4), 1, 0), ZIndex = 3,
})
local chipHit = hitbox(chipFace)

local backdrop = make("TextButton", {
	Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
	Visible = false, ZIndex = 10,
}, gui)
make("ImageLabel", {
	BackgroundTransparency = 1, Image = DOT, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0.94,
	ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(12, 12), Size = UDim2.fromScale(1, 1), ZIndex = 10,
}, backdrop)

local holder = make("Frame", {
	Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), ZIndex = 11,
}, backdrop)
local fitScale = make("UIScale", {}, holder)
local panel = make("Frame", { Name = "Panel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11 }, holder)
local popScale = make("UIScale", {}, panel)

-- header
local _, headFace = slab(panel, UDim2.fromOffset(DESIGN_W - 90, HEAD_H), UDim2.fromOffset(0, 0), C.Ink, 6, 4)
halftone(headFace, 6, 0.86)
text(headFace, {
	Font = Enum.Font.Bangers, Text = "LOADOUT", TextSize = 30, TextColor3 = C.CreamText,
	Position = UDim2.fromOffset(16, 1), Size = UDim2.fromOffset(220, HEAD_H), ZIndex = 4,
})
-- 2026-10-10: a fixed 300 px line ran past the bar on both sides and over the title; it now takes the bar right of the
-- title, wraps, and shrinks to fit (never outside its box)
local headNote = text(headFace, {
	Text = "", TextSize = 11, TextColor3 = C.CreamDim, TextWrapped = true, TextScaled = true,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.new(1, -170, 1, -8), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
})
make("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 6 }, headNote)
-- (2026-10-18, economy) the player's Sparks, at the bar's right end (where the retired BUILT note stood)
local balance = make("Frame", { Name = "SparksBalance", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(220, HEAD_H), ZIndex = 4 }, headFace)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, balance)
sparkMark(balance, 20, nil, 5).LayoutOrder = 1
local balanceText = text(balance, { Name = "Amount", Text = "0", TextSize = 18, TextColor3 = C.CreamText,
	AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, HEAD_H), LayoutOrder = 2, ZIndex = 5 })
text(balance, { Name = "Word", Text = "SPARKS", FontFace = MONO, TextSize = 11, TextColor3 = C.CreamDim,
	AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, HEAD_H), LayoutOrder = 3, ZIndex = 5 })
local function showBalance()
	balanceText.Text = fmt(sparks())
end
local _, closeFace = slab(panel, UDim2.fromOffset(78, HEAD_H), UDim2.new(1, -78, 0, 0), C.Ink, 6, 4)
local closeX = text(closeFace, {
	Font = Enum.Font.LuckiestGuy, Text = "X", TextSize = 30, TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = 3,
})
make("UIStroke", { Color = C.Ink, Thickness = 3 }, closeX)
local closeHit = hitbox(closeFace)

-- the page
local BODY_Y = HEAD_H + 12
local _, sheet = slab(panel, UDim2.fromOffset(DESIGN_W, DESIGN_H - BODY_Y), UDim2.fromOffset(0, BODY_Y), C.Paper, 8, 7)
halftone(sheet, 8, 0.78, C.Ink, 7)

local page = make("Frame", {
	Name = "Page", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, BODY_Y + 12),
	Size = UDim2.fromOffset(DESIGN_W - 32, DESIGN_H - BODY_Y - 24), ZIndex = 12,
}, panel)

local COL_L, COL_GAP = 300, 16
local COL_R = DESIGN_W - 32 - COL_L - COL_GAP
local left = make("Frame", { Name = "Left", BackgroundTransparency = 1,
	Size = UDim2.fromOffset(COL_L, page.Size.Y.Offset), ZIndex = 12 }, page)
local right = make("Frame", { Name = "Right", BackgroundTransparency = 1,
	Position = UDim2.fromOffset(COL_L + COL_GAP, 0), Size = UDim2.fromOffset(COL_R, page.Size.Y.Offset), ZIndex = 12 }, page)
-- the right column's two pages (2026-10-10): TECHNIQUES, and SKINS behind the SKINS card
local techView = make("Frame", { Name = "Techniques", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 12 }, right)
local skinsView = make("Frame", { Name = "Skins", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 12,
	Visible = false }, right)
-- (2026-10-13) and the Element's SKINS (full reworks) behind the SKINS card; "Skins" above stays the WRAPS page
local elSkinsView = make("Frame", { Name = "ElementSkins", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 12, Visible = false }, right)

local function banner(parent, label, width)
	local _, face = slab(parent, UDim2.fromOffset(width, 30), UDim2.fromOffset(0, 0), C.RedInk, 4, 4)
	face.ZIndex = 13
	halftone(face, 4, 0.86, C.Ink, 7).ZIndex = 14
	local lbl = text(face, {
		Font = Enum.Font.Bangers, Text = label, TextSize = 22, TextColor3 = C.CreamText,
		Position = UDim2.fromOffset(12, 1), Size = UDim2.new(1, -24, 1, 0), ZIndex = 15,
	})
	return 30 + 8, lbl
end

-- the footer line: what the panel last did, or why it would not
local note = text(page, {
	Text = "", TextSize = 12, TextColor3 = C.Grey, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 16), ZIndex = 14,
})
local function say(msg, bad)
	note.Text = msg
	note.TextColor3 = bad and C.RedInk or C.Grey
end

----------------------------------------------------------------------------------------------------
-- the Element grid
----------------------------------------------------------------------------------------------------
local elementChips = {}
local viewing = "Techniques"   -- the right column's page
local skinsFace = nil          -- the WRAPS card
local elSkinsFace = nil        -- the SKINS card
local setView                  -- (below)
local openUnlock               -- (below, 2026-10-18, economy): a locked Element's UNLOCK confirm

--- For a partly built Element, what is live, as a short tag ("M1 ONLY"); nil for a whole kit.
local function partialTag(name)
	local partial = Config.PartialKits[name]
	if not partial then return nil end
	local live = {}
	for _, role in ipairs({ "M1", "Primary", "Passive" }) do
		if partial[role] then live[#live + 1] = role:upper() end
	end
	return (#live > 0 and table.concat(live, " + ") or "NOTHING") .. " ONLY"
end

local function refreshElements()
	local chosen = currentElement()
	local owned = ownedSet()
	for name, chip in pairs(elementChips) do
		local built = Config.IsBuilt(name)
		local on = (name == chosen)
		chip.face.BackgroundColor3 = on and C.Pill or (built and C.Card or C.Track)
		local stroke = chip.face:FindFirstChildOfClass("UIStroke")
		stroke.Color = on and C.RedInk or C.Ink
		stroke.Thickness = on and 4 or 2
		chip.label.TextColor3 = built and C.Ink or C.Grey
		chip.icon.ImageTransparency = built and 0 or 0.55
		-- LOCKED (2026-10-18, economy): built and not owned -- browsable, priced, its icon dimmed under a padlock
		local locked = built and not owned[name]
		chip.lock.Visible = locked
		chip.price.Visible = locked and chip.forSale
		chip.unlock.Visible = locked and chip.forSale
		chip.unlockHit.Visible = locked and chip.forSale
		if locked then chip.icon.ImageTransparency = 0.4 end
		-- 2026-10-10: no "M1 + PRIMARY + PASSIVE ONLY" under a card any more (it was clipped at the card's edge); the
		-- header's BUILT note still says how much of a partly built kit is live
		chip.tag.Text = locked and "" or (built and (on and "EQUIPPED" or "") or "SOON")   -- (a locked card's line is its price)
		chip.tag.TextColor3 = on and C.Green or C.Grey
	end
	chipIcon.Image = Icons.Element[chosen] or ""
	showBalance()
end

do
	local y = banner(left, "ELEMENT", COL_L)
	-- 38 high, 43 apart (was 44 / 50): five rows and the footer under them fit the page -- AQUA was cut off by the
	-- panel's edge and the footer printed over it (2026-10-10)
	local CW, CH, GAP = (COL_L - 8) / 2, 38, 7
	for i, item in ipairs(elementsInOrder()) do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local _, face = slab(left, UDim2.fromOffset(CW - 4, CH),
			UDim2.fromOffset(col * (CW + 4), y + row * (CH + GAP - 2)), C.Card, 4, 3)
		face.ZIndex = 13
		local icon = make("ImageLabel", {
			BackgroundTransparency = 1, Image = Icons.Element[item.Name] or "",
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(28, 28), ZIndex = 14,
		}, face)
		local label = text(face, {
			Text = string.upper(item.Def.Display or item.Name), TextSize = 13,
			Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 0, CH - 14), ZIndex = 14,
		})
		local tag = text(face, {
			Text = "", TextSize = 9, TextColor3 = C.Grey, Position = UDim2.fromOffset(42, CH - 18),
			Size = UDim2.new(1, -50, 0, 12), ZIndex = 14,
		})
		-- LOCKED (2026-10-18, economy): a padlock on the icon, the price on the tag line, UNLOCK at the card's right end
		local forSale = Economy.PriceOf(item.Name) ~= nil
		local lock = lockBadge(face, UDim2.fromOffset(24, 17), 15)
		local price = make("Frame", { Name = "Price", BackgroundTransparency = 1, Position = UDim2.fromOffset(42, CH - 18),
			Size = UDim2.fromOffset(50, 12), ZIndex = 14, Visible = false }, face)
		sparkMark(price, 11, UDim2.fromOffset(0, 0), 14)
		text(price, { Text = fmt(Economy.PriceOf(item.Name) or 0), TextSize = 10, Position = UDim2.fromOffset(13, 0),
			Size = UDim2.fromOffset(40, 12), ZIndex = 14 })
		local unlock = make("Frame", { Name = "Unlock", BackgroundColor3 = C.Ink, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(44, 13),
			ZIndex = 15, Visible = false }, face)
		corner(unlock, 2)
		text(unlock, { Text = "UNLOCK", TextSize = 9, TextColor3 = C.CreamText, Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 16 })
		-- its hit area is the card's whole right end (52 px, full height), not only the small slab: a thumb can find it
		local unlockHit = make("TextButton", { Name = "UnlockHit", Text = "", AutoButtonColor = false,
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 52, 1, 0), ZIndex = 17, Visible = false }, face)
		unlockHit.Activated:Connect(function() openUnlock(item.Name) end)
		unlockHit.MouseEnter:Connect(function() unlock.BackgroundColor3 = C.RedInk end)
		unlockHit.MouseLeave:Connect(function() unlock.BackgroundColor3 = C.Ink end)
		hitbox(face, 15).Activated:Connect(function()
			if not Config.IsBuilt(item.Name) then
				say(string.format("%s is designed and not built -- %s, %s, %s are on paper only.",
					item.Def.Display or item.Name, item.Def.M1.Name, item.Def.Primary.Name,
					item.Def.Passive.Name), true)
				return
			end
			if not ownedSet()[item.Name] then
				-- BROWSED, NOT EQUIPPED (2026-10-18, economy): what it would give you, and what it costs
				local ult = ownUltimate(item.Name)
				say(string.format("%s: %s, %s, %s, %s. LOCKED%s.", item.Def.Display or item.Name, item.Def.M1.Name,
					item.Def.Primary.Name, item.Def.Passive.Name, ult and ult.Name or "no Ultimate",
					forSale and (": UNLOCK it for " .. fmt(Economy.PriceOf(item.Name)) .. " Sparks") or ""))
				return
			end
			if item.Name == currentElement() then
				-- no change, and none sent: the server would not reset your Techniques to the Element's defaults either
				say(string.format("You are already %s.", item.Def.Display or item.Name))
				return
			end
			loadoutRemote:FireServer("Element", item.Name)
			if Config.PartialKits[item.Name] then
				local live, soon = {}, {}
				for _, role in ipairs({ "M1", "Primary", "Passive" }) do
					local list = Config.IsPartBuilt(item.Name, role) and live or soon
					list[#list + 1] = item.Def[role].Name
				end
				say(string.format("%s: %s live; %s not built yet.", item.Def.Display or item.Name,
					table.concat(live, ", "), table.concat(soon, ", ")))
			else
				-- its Ultimate comes with it, and an Element may equip default Techniques (Pyro's Detonate and Scorching
				-- Lash, 2026-09-24)
				local ult = ownUltimate(item.Name)
				local own = {}
				local defaults = Config.ElementDefaults[item.Name]
				for _, slot in ipairs(Config.TechniqueSlots) do
					local entry = defaults and Config.Technique(defaults[slot])
					if entry then own[#own + 1] = entry.Name end
				end
				say(string.format("%s: %s, %s, %s, %s%s.", item.Def.Display or item.Name,
					item.Def.M1.Name, item.Def.Primary.Name, item.Def.Passive.Name, ult and ult.Name or "no Ultimate",
					#own > 0 and ("; equips " .. table.concat(own, " and ")) or ""))
			end
		end)
		face.MouseEnter:Connect(function()
			if face.BackgroundColor3 == C.Card then face.BackgroundColor3 = C.Hover end
		end)
		face.MouseLeave:Connect(refreshElements)
		elementChips[item.Name] = { face = face, icon = icon, label = label, tag = tag,
			lock = lock, price = price, unlock = unlock, unlockHit = unlockHit, forSale = forSale }
	end
	-- THE SKINS CARD (2026-10-10): the free cell after the last Element, an Element card's look, the Rainbow palette as
	-- six flat stripes for its icon; it swaps the right column to the SKINS page and back
	local n = #elementsInOrder()
	local _, face = slab(left, UDim2.fromOffset(CW - 4, CH),
		UDim2.fromOffset((n % 2) * (CW + 4), y + math.floor(n / 2) * (CH + GAP - 2)), C.Card, 4, 3)
	face.ZIndex = 13
	local mark = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(24, 20), ZIndex = 14 }, face)
	-- THE MARK FOLLOWS THE EQUIPPED ELEMENT (2026-10-10; SkinCatalog.WrapIcon): Radiant's rainbow stripes, Pyro's azure
	-- flame-drop, and a neutral cream palette for every Element with no wraps of its own. Flat, ink outline, no gradients.
	local marks = {}
	marks.Stripes = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 14 }, mark)
	local stops = (Skins.Skins.Rainbow and Skins.Skins.Rainbow.Stops) or {}
	for i, c in ipairs(stops) do
		make("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, Size = UDim2.new(1 / #stops, 0, 1, 0),
			Position = UDim2.fromScale((i - 1) / #stops, 0), ZIndex = 14 }, marks.Stripes)
	end
	make("UIStroke", { Color = C.Ink, Thickness = 1.5 }, marks.Stripes)
	-- a teardrop (a circle under a turned square), nested from the ink outline in to the white core
	marks.Drop = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 14 }, mark)
	for i, l in ipairs({ { 20, "#080E1A" }, { 16, "#1C6FD8" }, { 11, "#4FD6EE" }, { 6, "#FFFFFF" } }) do
		local s, col = l[1], Color3.fromHex(l[2])
		local base = -(20 - s) * 0.25
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, make("Frame", { BackgroundColor3 = col, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, base), Size = UDim2.fromOffset(s, s),
			ZIndex = 14 + i }, marks.Drop))
		make("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = UDim2.new(0.5, 0, 1, base - s * 0.62), Size = UDim2.fromOffset(s * 0.62, s * 0.62),
			ZIndex = 14 + i }, marks.Drop)
	end
	-- a painter's palette: cream, ink outline, three ink wells
	marks.Palette = make("Frame", { BackgroundColor3 = Color3.fromHex("#F3E7CF"), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 17), ZIndex = 15 }, mark)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, marks.Palette)
	make("UIStroke", { Color = C.Ink, Thickness = 1.5 }, marks.Palette)
	for _, xy in ipairs({ { 0.3, 0.38 }, { 0.55, 0.3 }, { 0.72, 0.55 } }) do
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, make("Frame", { BackgroundColor3 = C.Ink, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(xy[1], xy[2]), Size = UDim2.fromOffset(4, 4),
			ZIndex = 16 }, marks.Palette))
	end
	local function showMark()
		local want = (Skins.WrapIcon or {})[player:GetAttribute("Element")] or "Palette"
		for k, f in pairs(marks) do f.Visible = (k == want) end
	end
	player:GetAttributeChangedSignal("Element"):Connect(showMark)
	showMark()
	text(face, { Text = "WRAPS", TextSize = 13, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), ZIndex = 14 })
	skinsFace = face
	hitbox(face, 15).Activated:Connect(function()
		setView(viewing == "Skins" and "Techniques" or "Skins")
	end)
	face.MouseEnter:Connect(function() face.BackgroundColor3 = C.Hover end)
	face.MouseLeave:Connect(function() face.BackgroundColor3 = (viewing == "Skins") and C.Pill or C.Card end)

	-- THE SKINS CARD (2026-10-13): the cell after WRAPS, the same card; it swaps the right column to the SKINS page (the
	-- Element's full reworks). Its mark: a horned head -- crimson horns on black while the equipped Element has a skin
	-- to offer, cream and ink while it has none.
	local _, sface = slab(left, UDim2.fromOffset(CW - 4, CH),
		UDim2.fromOffset(((n + 1) % 2) * (CW + 4), y + math.floor((n + 1) / 2) * (CH + GAP - 2)), C.Card, 4, 3)
	sface.ZIndex = 13
	local smark = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(24, 22), ZIndex = 14 }, sface)
	local horns = {}
	for _, side in ipairs({ -1, 1 }) do
		local h = make("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Rotation = side * 28,
			Position = UDim2.new(0.5, side * 6, 1, -11), Size = UDim2.fromOffset(5, 11), ZIndex = 15 }, smark)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, h)
		make("UIStroke", { Color = C.Ink, Thickness = 1.5 }, h)
		horns[#horns + 1] = h
	end
	local head = make("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(16, 15), ZIndex = 16 }, smark)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, head)
	make("UIStroke", { Color = C.Ink, Thickness = 1.5 }, head)
	local function showSkinMark()
		local has = #Skins.ListElementSkins(player:GetAttribute("Element")) > 1
		head.BackgroundColor3 = has and Color3.fromHex("#1A1416") or Color3.fromHex("#F3E7CF")
		for _, h in ipairs(horns) do h.BackgroundColor3 = has and Color3.fromHex("#C8141C") or Color3.fromHex("#F3E7CF") end
	end
	player:GetAttributeChangedSignal("Element"):Connect(showSkinMark)
	showSkinMark()
	text(sface, { Text = "SKINS", TextSize = 13, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), ZIndex = 14 })
	elSkinsFace = sface
	hitbox(sface, 15).Activated:Connect(function()
		setView(viewing == "ElementSkins" and "Techniques" or "ElementSkins")
	end)
	sface.MouseEnter:Connect(function() sface.BackgroundColor3 = C.Hover end)
	sface.MouseLeave:Connect(function() sface.BackgroundColor3 = (viewing == "ElementSkins") and C.Pill or C.Card end)
end

----------------------------------------------------------------------------------------------------
-- UNLOCK (2026-10-18, economy): the confirm a locked Element's UNLOCK opens, over the panel
----------------------------------------------------------------------------------------------------
-- An ink veil over the panel and one paper slab, in the panel's own dialect (nothing lifts). It reads the price and the
-- balance as it opens and again whenever either changes; the server checks both again (EconomyService) and the grid
-- follows the attributes it writes. Short of Sparks it says how many more and offers GET SPARKS: the shop, on its packs.
local unlockFor, unlockBusy = nil, false
local veil = make("TextButton", { Name = "UnlockConfirm", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false }, panel)
local MW, MH = 392, 212
local _, mFace = slab(veil, UDim2.fromOffset(MW, MH), UDim2.new(0.5, -MW / 2, 0.5, -MH / 2), C.Paper, 6, 6)
hitbox(mFace, 1)                               -- a click on the slab is not a click on the veil (which cancels)
halftone(mFace, 6, 0.9, C.Ink, 7)
local mTitle = text(mFace, { Font = Enum.Font.Bangers, TextSize = 28, Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 34), ZIndex = 4 })
local mIcon = make("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 50),
	Size = UDim2.fromOffset(56, 56), ZIndex = 4 }, mFace)
local mRows = {}
for i, word in ipairs({ "PRICE", "YOU HAVE", "AFTER" }) do
	local y = 46 + (i - 1) * 22
	local w = text(mFace, { Text = word, FontFace = MONO, TextSize = 11, TextColor3 = C.Grey,
		Position = UDim2.fromOffset(88, y), Size = UDim2.fromOffset(100, 20), ZIndex = 4 })
	sparkMark(mFace, 14, UDim2.fromOffset(192, y + 3), 4)
	local v = text(mFace, { TextSize = 16, Position = UDim2.fromOffset(212, y), Size = UDim2.fromOffset(160, 20), ZIndex = 4 })
	mRows[i] = { word = w, value = v }
end
local mNote = text(mFace, { Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Grey, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -32, 0, 34), ZIndex = 4 })
local function mButton(label, colour, x, w)
	local holder, face = slab(mFace, UDim2.fromOffset(w, 40), UDim2.new(0, x, 1, -54), colour, 4, 4)
	holder.ZIndex = 4
	local word = text(face, { Text = label, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	return hitbox(face, 6), word, face
end
local cancelHit = mButton("CANCEL", C.Pill, 16, 150)
local okHit, okWord, okFace = mButton("UNLOCK", C.Green, MW - 6 - 16 - 190, 190)

local function fillUnlock()
	local name = unlockFor
	if not name then return end
	-- (2026-10-18 review) no balance to judge the price against yet: the save is still loading, or it could not load on
	-- this server (DataError). The placeholder 0 is not "short", so nothing here points at the Sparks packs.
	if player:GetAttribute("DataLoaded") ~= true then
		local failed = player:GetAttribute("DataError") == true
		mTitle.Text = failed and "SAVE UNAVAILABLE" or "LOADING YOUR SAVE"
		mIcon.Image = Icons.Element[name] or ""
		mRows[1].value.Text = fmt(Economy.PriceOf(name) or 0)
		mRows[2].value.Text = "..."
		mRows[3].word.Text = "AFTER"
		mRows[3].value.Text = "..."
		mRows[3].value.TextColor3 = C.Ink
		mNote.Text = failed and "Your save couldn't load on this server, so unlocks are paused here. Nothing you own is lost."
			or "Your Sparks and Elements are still loading. This takes a moment."
		okWord.Text = "WAIT"
		okFace.BackgroundColor3 = C.Pill
		return
	end
	local display = elementDisplay(name)
	local price, have = Economy.PriceOf(name) or 0, sparks()
	local short = have < price
	mTitle.Text = short and "NOT ENOUGH SPARKS" or ("UNLOCK " .. string.upper(display) .. "?")
	mIcon.Image = Icons.Element[name] or ""
	mRows[1].value.Text = fmt(price)
	mRows[2].value.Text = fmt(have)
	mRows[3].word.Text = short and "STILL NEEDED" or "AFTER"
	mRows[3].value.Text = fmt(math.abs(have - price))
	mRows[3].value.TextColor3 = short and C.RedInk or C.Ink
	mNote.Text = short and ("You need " .. fmt(price - have) .. " more Sparks for " .. display
		.. ". Win matches to earn them, or get a Sparks pack in the Shop.")
		or (display .. "'s M1, Primary, Passive and Ultimate are yours for good. It is not equipped until you pick it.")
	okWord.Text = unlockBusy and "..." or (short and "GET SPARKS" or "UNLOCK")
	okFace.BackgroundColor3 = short and C.Gold or C.Green
end

local function closeUnlock()
	unlockFor = nil
	veil.Visible = false
end

openUnlock = function(name)
	if not (Config.Elements[name] and Config.IsBuilt(name)) or ownedSet()[name] then return end
	if not Economy.PriceOf(name) then
		say(string.format("%s can't be bought with Sparks.", elementDisplay(name)), true)
		return
	end
	unlockFor = name
	fillUnlock()
	veil.Visible = true
end

local function confirmUnlock()
	local name = unlockFor
	if not name or unlockBusy then return end
	if player:GetAttribute("DataLoaded") ~= true then return end     -- WAIT (fillUnlock): nothing loaded to spend yet
	if sparks() < (Economy.PriceOf(name) or 0) then
		-- GET SPARKS: the shop, on its packs (opening, it closes this menu through our Command)
		closeUnlock()
		local shop = playerGui:FindFirstChild("SpellshotShop")
		local cmd = shop and shop:FindFirstChild("Command")
		if cmd then cmd:Fire("sparks") else say("The shop isn't available right now.", true) end
		return
	end
	local remote = folder:FindFirstChild("EconomyRequest")
	if not remote then
		closeUnlock()
		say("Unlocking isn't available on this server.", true)
		return
	end
	unlockBusy = true
	fillUnlock()
	task.spawn(function()
		local ok, good, _, msg = pcall(function() return remote:InvokeServer("UnlockElement", name) end)
		unlockBusy = false
		-- only the confirm this call came from closes: one opened for another Element meanwhile just gets its button back
		if unlockFor == name then closeUnlock() else fillUnlock() end
		if not ok then
			say("No answer from the server: nothing was spent. Try again.", true)
		else
			say(msg or (good and "Unlocked." or "Not unlocked."), not good)
		end
		refreshElements()
	end)
end
cancelHit.Activated:Connect(closeUnlock)
veil.Activated:Connect(closeUnlock)
okHit.Activated:Connect(confirmUnlock)

----------------------------------------------------------------------------------------------------
-- the three Technique rows
----------------------------------------------------------------------------------------------------
local roleRows = {}

--- `snap`: back to what is equipped (a loadout change, the panel opening); otherwise keep what the arrows browsed to.
local function refreshRoles(snap)
	for role, row in pairs(roleRows) do
		local locked = (role == "Ultimate")
		if locked then
			-- the Element's own (v0.7, 2026-09-24): shown as equipped, nothing to browse -- the arrows dim and explain
			local own = ownUltimate(currentElement())
			row.value.Text = own and string.upper(own.Name) or "NONE"
			row.value.TextColor3 = C.Ink
			row.origin.Text = string.upper(elementDisplay(currentElement())) .. "'S OWN  --  COMES WITH THE ELEMENT"
			row.origin.TextColor3 = C.Grey
			row.mark.Visible = own ~= nil
		else
			-- the list follows the Element (Detonate is listed for Pyro only), so it is rebuilt each time
			local browsedKey = row.list[row.index] and row.list[row.index].Key
			local equipped = currentTechnique(role)
			local want = (snap or not browsedKey) and equipped or browsedKey
			row.list = techniqueList()
			row.index = 1
			for i, item in ipairs(row.list) do
				if item.Key == want then row.index = i end
			end
			local browsed = row.list[row.index]
			local built = Config.IsTechniqueBuilt(role, browsed.Key)
			row.value.Text = string.upper(browsed.Entry.Name)
			row.value.TextColor3 = built and C.Ink or C.Grey
			row.origin.Text = string.upper(browsed.Entry.Origin) .. (built and "" or "  --  SOON")
			row.origin.TextColor3 = built and C.Grey or C.RedInk
			row.mark.Visible = (browsed.Key == equipped)
		end
		for _, b in ipairs(row.arrows) do
			b.BackgroundColor3 = locked and C.Track or C.Ink
			b.TextColor3 = locked and C.Grey or C.CreamText
		end
	end
end

do
	local y = banner(techView, "TECHNIQUES", COL_R)
	for _, role in ipairs(ROLES) do
		local _, face = slab(techView, UDim2.fromOffset(COL_R, 62), UDim2.fromOffset(0, y), C.Card, 4, 3)
		face.ZIndex = 13
		text(face, {
			Text = string.upper(Config.SlotLabel[role] or role), TextSize = 12, TextColor3 = C.Grey,
			Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(120, 14), ZIndex = 14,
		})
		local mark = text(face, {
			Text = "EQUIPPED", TextSize = 9, TextColor3 = C.Green, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(70, 12),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14, Visible = false,
		})
		local value = text(face, {
			Text = "", TextSize = 15, Position = UDim2.fromOffset(42, 20),
			Size = UDim2.new(1, -84, 0, 20), ZIndex = 14, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local origin = text(face, {
			Text = "", TextSize = 10, TextColor3 = C.Grey, Position = UDim2.fromOffset(42, 40),
			Size = UDim2.new(1, -84, 0, 14), ZIndex = 14,
		})
		local list = (role == "Ultimate") and {} or techniqueList()
		local index = 1
		for i, item in ipairs(list) do
			if item.Key == currentTechnique(role) then index = i end
		end
		local row = { list = list, index = index, value = value, origin = origin, mark = mark, arrows = {} }
		roleRows[role] = row

		local function step(dir)
			if role == "Ultimate" then
				local own = ownUltimate(currentElement())
				say(string.format("%s is %s's own Ultimate -- pick another Element for another.",
					own and own.Name or "The Ultimate", elementDisplay(currentElement())), true)
				return
			end
			-- the Technique in the other row is skipped: one Technique is never in both slots
			local taken = currentTechnique(otherSlot(role))
			for _ = 1, #row.list do
				row.index = (row.index - 1 + dir) % #row.list + 1
				if row.list[row.index].Key ~= taken then break end
			end
			local browsed = row.list[row.index]
			if Config.IsTechniqueBuilt(role, browsed.Key) then
				loadoutRemote:FireServer("Technique", role, browsed.Key)
				say(browsed.Entry.Name .. ": " .. browsed.Entry.Desc)
			elseif Config.IsBuilt(browsed.Entry.Origin) then
				say(browsed.Entry.Name .. " is " .. browsed.Entry.Origin
					.. "'s, and it is not built yet -- you keep what you had.", true)
			else
				say(browsed.Entry.Name .. " is " .. browsed.Entry.Origin
					.. "'s, and that kit is not built -- you keep what you had.", true)
			end
			refreshRoles()
		end

		local function arrow(glyph, atRight, dir)
			local b = make("TextButton", {
				Text = glyph, Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = C.CreamText,
				BackgroundColor3 = C.Ink, AutoButtonColor = false, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(atRight and 1 or 0, 0.5),
				Position = UDim2.new(atRight and 1 or 0, atRight and -10 or 10, 0.5, 8),
				Size = UDim2.fromOffset(24, 26), ZIndex = 15,
			}, face)
			corner(b, 4)
			b.Activated:Connect(function() step(dir) end)
			row.arrows[#row.arrows + 1] = b
		end
		arrow("<", false, -1)
		arrow(">", true, 1)
		y += 62 + 8
	end
end

----------------------------------------------------------------------------------------------------
-- the SKINS page (2026-10-10): one row per ability slot of the equipped Element -- M1, Primary, Passive (when it draws
-- anything), Ultimate and the two Techniques -- each a Technique row: the slot and ability, a < > stepper round the skin
-- name, EQUIPPED. A slot with Default alone (every Element but Radiant for now, and a Technique borrowed from another
-- Element: FLAGGED) shows greyed arrows, as the Ultimate's. A step equips at once (LoadoutRequest "Skin"); the next cast
-- draws it. The rows scroll inside the column: six do not fit its height, and the panel keeps its size.
----------------------------------------------------------------------------------------------------
local skinsTitle, skinsScroll
local skinRows = {}

local function abilityKey(name)
	return (string.gsub(name or "", "[^%w]", ""))
end

local function skinSlots()
	local el = currentElement()
	local def = Config.Elements[el]
	local out = {}
	if not def then return out end
	local function add(slot, entry, key, origin)
		if entry then
			out[#out + 1] = { Slot = slot, Name = entry.Name, Key = key or abilityKey(entry.Name), Origin = origin or el }
		end
	end
	add("M1", def.M1)
	add("PRIMARY", def.Primary)
	if def.Passive and def.Passive.Display ~= "None" then add("PASSIVE", def.Passive) end
	add("ULTIMATE", ownUltimate(el))
	for _, role in ipairs({ "Mobility", "Defense" }) do
		local key = currentTechnique(role)
		local entry = key and Config.Technique(key)
		if entry then add(string.upper(Config.SlotLabel[role] or role), entry, key, entry.Origin) end
	end
	return out
end

-- THE ELEMENT'S WRAP (2026-10-16), at the top of the WRAPS page: the Element's colour wraps (SkinCatalog.ElementWraps),
-- one for the whole Element, worn over the Default shapes or over the skin picked on the SKINS page (LoadoutRequest
-- "ElementWrap"). Cards like the skins': its rarity, its name in its own palette, the four palette swatches, EQUIPPED or
-- EQUIP. Returns whether the Element has wraps of its own.
local function elementWrapRows(scroll, rows, el)
	local wraps = (Skins.ElementWraps or {})[el]
	if wraps and #wraps > 1 then
		local equipped = Skins.ElementSkin(player, el)
		local over = Skins.Skins[equipped]
		local hHolder, hFace = slab(scroll, UDim2.fromOffset(COL_R - 10, 26), nil, C.Track, 4, 0)
		hHolder.LayoutOrder = -100
		hFace.ZIndex = 13
		text(hFace, {
			Text = string.upper(elementDisplay(el)) .. " WRAP  --  EVERY ABILITY, OVER " .. ((equipped ~= "Default" and over and string.upper(over.DisplayName or equipped))
				or "THE DEFAULT LOOK"), TextSize = 11, TextColor3 = C.Ink,
			Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ZIndex = 14, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		rows[#rows + 1] = hHolder
		local worn = Skins.ElementWrap and Skins.ElementWrap(player, el) or "Default"
		for i, id in ipairs(wraps) do
			local w = Skins.Skins[id] or { DisplayName = id }
			local on = (id == worn)
			local holder, face = slab(scroll, UDim2.fromOffset(COL_R - 10, 54), nil, on and C.Pill or C.Card, 4, 3)
			holder.LayoutOrder = -100 + i
			face.ZIndex = 13
			local st = face:FindFirstChildOfClass("UIStroke")
			if st and on then st.Color, st.Thickness = C.RedInk, 3 end
			text(face, {
				Text = (id == "Default") and "NO WRAP  -  ITS OWN COLOURS"
					or ("COLOUR WRAP  -  " .. string.upper(w.Rarity or "")), TextSize = 10, TextColor3 = C.Grey,
				Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 14), ZIndex = 14, TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local name = text(face, {
				Text = string.upper((id == "Default") and "Default" or (w.DisplayName or id)), TextSize = 15,
				Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -170, 0, 22), ZIndex = 14,
			})
			local P = w.Palette
			if P and P.Main and P.Highlight then
				name.TextColor3 = Color3.new(1, 1, 1)
				make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.Highlight),
					ColorSequenceKeypoint.new(0.5, P.Main), ColorSequenceKeypoint.new(1, P.Shadow or P.Main) }) }, name)
				make("UIStroke", { Color = C.Ink, Thickness = 1 }, name)
				for k, c in ipairs({ P.Main, P.Shadow, P.Highlight, P.Accent }) do
					local sw = make("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -84 - (4 - k) * 18, 0.5, 0), Size = UDim2.fromOffset(14, 14), ZIndex = 15 }, face)
					corner(sw, 3)
					make("UIStroke", { Color = C.Ink, Thickness = 1 }, sw)
				end
			end
			local function pick()
				if on then
					say(((id == "Default") and "No wrap" or (w.DisplayName or id)) .. " is already on.")
					return
				end
				loadoutRemote:FireServer("ElementWrap", el, id)
				say((id == "Default") and (elementDisplay(el) .. ": its own colours again -- on your next cast.")
					or (elementDisplay(el) .. ": the " .. (w.DisplayName or id) .. " wrap -- on your next cast."))
			end
			if on then
				text(face, {
					Text = "EQUIPPED", TextSize = 10, TextColor3 = C.Green, AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(70, 14),
					TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14,
				})
			else
				local btn = make("TextButton", {
					Text = "EQUIP", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C.CreamText,
					BackgroundColor3 = C.Ink, AutoButtonColor = false, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(64, 26), ZIndex = 16,
				}, face)
				corner(btn, 4)
				btn.Activated:Connect(pick)
			end
			hitbox(face, 15).Activated:Connect(pick)
			rows[#rows + 1] = holder
		end
		return true
	end
	return false
end

local function refreshSkins()
	if not skinsScroll then return end
	local el = currentElement()
	skinsTitle.Text = "WRAPS  --  " .. string.upper(elementDisplay(el))
	for _, r in ipairs(skinRows) do r:Destroy() end
	table.clear(skinRows)
	local elWraps = elementWrapRows(skinsScroll, skinRows, el)
	for i, s in ipairs(skinSlots()) do
		local own = (s.Origin == el)
		local list = own and Skins.List(el, s.Key) or { "Default" }
		local equipped = player:GetAttribute(Skins.Attr(s.Key))
		if type(equipped) ~= "string" or not table.find(list, equipped) then equipped = "Default" end
		-- the Element's SKIN, while one is on: the wraps go OVER it (SkinCatalog.Chosen "<Skin>+<Wrap>"), so the row still
		-- steps; only the colour wraps are offered there (a wrap with its own material code does not go over a skin)
		local full = own and Skins.ElementSkin(player, el) or "Default"
		if full ~= "Default" then
			local over = {}
			for _, id in ipairs(list) do
				if id == "Default" or (Skins.WrapsOverSkin and Skins.WrapsOverSkin(id)) then over[#over + 1] = id end
			end
			list = over
			if not table.find(list, equipped) then equipped = "Default" end
		end
		local fullDef = (full ~= "Default") and (Skins.Skins[full] or { DisplayName = full }) or nil
		local locked = #list <= 1
		if elWraps and locked then continue end      -- (the Element's wrap above covers it)
		local holder, face = slab(skinsScroll, UDim2.fromOffset(COL_R - 10, 62), nil, C.Card, 4, 3)
		holder.LayoutOrder = i
		face.ZIndex = 13
		text(face, {
			Text = s.Slot .. "  -  " .. string.upper(s.Name), TextSize = 11, TextColor3 = C.Grey,
			Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -96, 0, 14), ZIndex = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		text(face, {
			Text = "EQUIPPED", TextSize = 9, TextColor3 = C.Green, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(70, 12),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14,
		})
		local skin = Skins.Skins[equipped] or { DisplayName = equipped }
		-- no wrap over a skin: the row shows the skin's own colours under its name
		local shown = (fullDef and equipped == "Default") and fullDef or skin
		local value = text(face, {
			Text = (fullDef and equipped == "Default") and (string.upper(fullDef.DisplayName or full) .. "'S OWN")
				or string.upper(skin.DisplayName or equipped),
			TextSize = 15, TextColor3 = locked and C.Grey or C.Ink,
			Position = UDim2.fromOffset(42, 20), Size = UDim2.new(1, -84, 0, 20), ZIndex = 14,
		})
		local stops = shown.Stops or shown.Label
		if stops then   -- the skin's own colours on its name
			local kp = {}
			for k, c in ipairs(stops) do kp[k] = ColorSequenceKeypoint.new((k - 1) / (#stops - 1), c) end
			value.TextColor3 = Color3.new(1, 1, 1)
			make("UIGradient", { Color = ColorSequence.new(kp) }, value)
			make("UIStroke", { Color = C.Ink, Thickness = 1 }, value)
		end
		local overName = fullDef and string.upper(fullDef.DisplayName or full) or nil
		text(face, {
			Text = (fullDef and locked) and ("OVER THE " .. overName .. " SKIN  --  NO WRAPS YET")
				or fullDef and ("OVER THE " .. overName .. " SKIN  --  " .. (#list - 1) .. " WRAP" .. ((#list == 2) and "" or "S"))
				or locked and (own and "DEFAULT ONLY  --  NO WRAPS YET"
				or ("BORROWED FROM " .. string.upper(s.Origin) .. "  --  KEEPS ITS COLOURS"))
				or (#list .. " WRAPS  --  COLOUR ONLY"),
			TextSize = 10, TextColor3 = C.Grey, Position = UDim2.fromOffset(42, 40), Size = UDim2.new(1, -84, 0, 14), ZIndex = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local function step(dir)
			if locked then
				say(not own and (s.Name .. " is " .. s.Origin .. "'s: a borrowed Technique keeps its own colours.")
					or fullDef and (s.Name .. " has no wraps that go over the " .. (fullDef.DisplayName or full) .. " skin yet.")
					or (s.Name .. " has no wraps yet."), true)
				return
			end
			local idx = table.find(list, equipped) or 1
			local nextId = list[(idx - 1 + dir) % #list + 1]
			loadoutRemote:FireServer("Skin", s.Key, nextId)
			local def = Skins.Skins[nextId]
			if fullDef then
				say(s.Name .. ": " .. ((nextId == "Default") and ("the " .. (fullDef.DisplayName or full) .. " skin's own colours")
					or ((def and def.DisplayName or nextId) .. " over the " .. (fullDef.DisplayName or full) .. " skin"))
					.. " -- on your next cast.")
			else
				say(s.Name .. ": " .. (def and def.DisplayName or nextId) .. " -- on your next cast.")
			end
		end
		for _, a in ipairs({ { "<", false, -1 }, { ">", true, 1 } }) do
			local btn = make("TextButton", {
				Text = a[1], Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = locked and C.Grey or C.CreamText,
				BackgroundColor3 = locked and C.Track or C.Ink, AutoButtonColor = false, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(a[2] and 1 or 0, 0.5), Position = UDim2.new(a[2] and 1 or 0, a[2] and -10 or 10, 0.5, 8),
				Size = UDim2.fromOffset(24, 26), ZIndex = 15,
			}, face)
			corner(btn, 4)
			btn.Activated:Connect(function() step(a[3]) end)
		end
		skinRows[#skinRows + 1] = holder
	end
end

do
	local y, lbl = banner(skinsView, "WRAPS", COL_R)
	skinsTitle = lbl
	lbl.Size = UDim2.new(1, -100, 1, 0)
	-- BACK, a small black button like the X
	local _, backFace = slab(skinsView, UDim2.fromOffset(66, 24), UDim2.new(1, -80, 0, 1), C.Ink, 4, 2)
	backFace.ZIndex = 16
	text(backFace, {
		Font = Enum.Font.LuckiestGuy, Text = "BACK", TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = 17,
	})
	hitbox(backFace, 18).Activated:Connect(function() setView("Techniques") end)
	skinsScroll = make("ScrollingFrame", {
		Name = "Rows", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 1, -y - 22), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5, ScrollBarImageColor3 = C.Ink, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 13,
	}, skinsView)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, skinsScroll)
	make("UIPadding", { PaddingBottom = UDim.new(0, 4) }, skinsScroll)
end

----------------------------------------------------------------------------------------------------
-- the SKINS page (2026-10-13): the equipped Element's full skins -- a rework of the whole kit (shapes, staff, colours),
-- one choice for every ability at once -- as cards: the skin's name in its own colours, what it changes, EQUIPPED or an
-- EQUIP button. A pick equips at once (LoadoutRequest "ElementSkin"); the next cast draws it. While a skin is on, the
-- WRAPS page still steps: a colour wrap goes OVER the skin (its forms, the wrap's colours -- SkinCatalog "<Skin>+<Wrap>").
----------------------------------------------------------------------------------------------------
local elSkinsTitle, elSkinsScroll
local elSkinRows = {}

local function refreshElementSkins()
	if not elSkinsScroll then return end
	local el = currentElement()
	elSkinsTitle.Text = "SKINS  --  " .. string.upper(elementDisplay(el))
	for _, r in ipairs(elSkinRows) do r:Destroy() end
	table.clear(elSkinRows)
	local list = Skins.ListElementSkins(el)
	local equipped = Skins.ElementSkin(player, el)
	for i, id in ipairs(list) do
		local skin = Skins.Skins[id] or { DisplayName = id }
		local on = (id == equipped)
		local holder, face = slab(elSkinsScroll, UDim2.fromOffset(COL_R - 10, 62), nil, on and C.Pill or C.Card, 4, 3)
		holder.LayoutOrder = i
		face.ZIndex = 13
		local st = face:FindFirstChildOfClass("UIStroke")
		if st and on then st.Color, st.Thickness = C.RedInk, 3 end
		text(face, {
			Text = (id == "Default") and ("DEFAULT  -  " .. string.upper(elementDisplay(el)) .. "'S OWN LOOK")
				or "FULL SKIN  -  EVERY ABILITY", TextSize = 11, TextColor3 = C.Grey,
			Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -96, 0, 14), ZIndex = 14, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local value = text(face, {
			Text = string.upper(skin.DisplayName or id), TextSize = 15, Position = UDim2.fromOffset(12, 20),
			Size = UDim2.new(1, -96, 0, 20), ZIndex = 14,
		})
		local stops = skin.Stops or skin.Label
		if stops then
			local kp = {}
			for k, c in ipairs(stops) do kp[k] = ColorSequenceKeypoint.new((k - 1) / (#stops - 1), c) end
			value.TextColor3 = Color3.new(1, 1, 1)
			make("UIGradient", { Color = ColorSequence.new(kp) }, value)
			make("UIStroke", { Color = C.Ink, Thickness = 1 }, value)
		end
		text(face, {
			Text = skin.Blurb or ((id == "Default") and "NO SKIN  --  WRAPS APPLY" or ""), TextSize = 10, TextColor3 = C.Grey,
			Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -96, 0, 14), ZIndex = 14, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local function pick()
			if on then
				say((skin.DisplayName or id) .. " is already on.")
				return
			end
			loadoutRemote:FireServer("ElementSkin", el, id)
			say((id == "Default") and (elementDisplay(el) .. ": back to its own look -- on your next cast.")
				or (elementDisplay(el) .. ": the " .. (skin.DisplayName or id) .. " skin -- on your next cast."))
		end
		if on then
			text(face, {
				Text = "EQUIPPED", TextSize = 10, TextColor3 = C.Green, AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(70, 14),
				TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14,
			})
		else
			local btn = make("TextButton", {
				Text = "EQUIP", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C.CreamText,
				BackgroundColor3 = C.Ink, AutoButtonColor = false, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(64, 26), ZIndex = 16,
			}, face)
			corner(btn, 4)
			btn.Activated:Connect(pick)
		end
		hitbox(face, 15).Activated:Connect(pick)
		elSkinRows[#elSkinRows + 1] = holder
	end
	if #list <= 1 then
		local holder, face = slab(elSkinsScroll, UDim2.fromOffset(COL_R - 10, 40), nil, C.Track, 4, 0)
		holder.LayoutOrder = #list + 1
		face.ZIndex = 13
		text(face, {
			Text = "NO SKINS FOR " .. string.upper(elementDisplay(el)) .. " YET", TextSize = 11, TextColor3 = C.Grey,
			Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ZIndex = 14,
		})
		elSkinRows[#elSkinRows + 1] = holder
	end
end

do
	local y, lbl = banner(elSkinsView, "SKINS", COL_R)
	elSkinsTitle = lbl
	lbl.Size = UDim2.new(1, -100, 1, 0)
	local _, backFace = slab(elSkinsView, UDim2.fromOffset(66, 24), UDim2.new(1, -80, 0, 1), C.Ink, 4, 2)
	backFace.ZIndex = 16
	text(backFace, {
		Font = Enum.Font.LuckiestGuy, Text = "BACK", TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = 17,
	})
	hitbox(backFace, 18).Activated:Connect(function() setView("Techniques") end)
	elSkinsScroll = make("ScrollingFrame", {
		Name = "Rows", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 1, -y - 22), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5, ScrollBarImageColor3 = C.Ink, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 13,
	}, elSkinsView)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, elSkinsScroll)
	make("UIPadding", { PaddingBottom = UDim.new(0, 4) }, elSkinsScroll)
end

setView = function(v)
	viewing = v
	techView.Visible = v == "Techniques"
	skinsView.Visible = v == "Skins"
	elSkinsView.Visible = v == "ElementSkins"
	for _, card in ipairs({ { skinsFace, "Skins" }, { elSkinsFace, "ElementSkins" } }) do
		local f = card[1]
		if f then
			local on = v == card[2]
			f.BackgroundColor3 = on and C.Pill or C.Card
			local st = f:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = on and C.RedInk or C.Ink
				st.Thickness = on and 4 or 2
			end
		end
	end
	if v == "Skins" then
		refreshSkins()
		say("Wraps change colour only -- they go over your skin too. It shows on your next cast.")
	elseif v == "ElementSkins" then
		refreshElementSkins()
		say("Skins rework the whole Element -- new shapes, new staff, new colours -- for every ability at once. Wraps go on top.")
	end
end

player.AttributeChanged:Connect(function(name)
	local loadout = name == "Element" or name == "Mobility" or name == "Defense"
	local skinAttr = string.sub(name, 1, 12) == "ElementSkin_" or string.sub(name, 1, 12) == "ElementWrap_"
	if viewing == "Skins" and (string.sub(name, 1, 5) == "Skin_" or skinAttr or loadout) then
		refreshSkins()
	elseif viewing == "ElementSkins" and (skinAttr or name == "Element") then
		refreshElementSkins()
	end
end)

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local open = false

local function setOpen(v)
	if v == open then return end
	open = v
	-- the input scripts stand down while a menu is up, the same as for the settings panel
	player:SetAttribute("LoadoutOpen", v or nil)
	if v then
		refreshElements()
		refreshRoles(true)
		setView("Techniques")
		say("Pick an Element: its M1, Primary, Passive and Ultimate come with it. Techniques: any two, from every Element.")
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		popScale.Scale = 0.94
		TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 0.35 }):Play()
		TweenService:Create(popScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		-- first person re-locks the mouse every frame; win it back while the panel is up
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		closeUnlock()
		backdrop.Visible = false
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
	end
end

chipHit.Activated:Connect(function() setOpen(not open) end)
chipHit.MouseEnter:Connect(function()
	TweenService:Create(chipIcon, TweenInfo.new(0.2), { Rotation = -12 }):Play()
end)
chipHit.MouseLeave:Connect(function()
	TweenService:Create(chipIcon, TweenInfo.new(0.2), { Rotation = 0 }):Play()
end)
closeHit.Activated:Connect(function() setOpen(false) end)

command.Event:Connect(function(what, a, b)
	if what == "open" then
		setOpen(true)
	elseif what == "close" then
		setOpen(false)
	elseif what == "element" then
		loadoutRemote:FireServer("Element", a)
	elseif what == "technique" then
		loadoutRemote:FireServer("Technique", a, b)
	elseif what == "skin" then
		loadoutRemote:FireServer("ElementSkin", currentElement(), a)
	elseif what == "wrap" then
		loadoutRemote:FireServer("ElementWrap", currentElement(), a)
	elseif what == "view" then
		setView(a)
	elseif what == "unlock" then
		setOpen(true)
		openUnlock(a)
	elseif what == "confirm" then
		confirmUnlock()
	end
end)

for _, name in ipairs({ "Element", "Mobility", "Defense", "Ultimate" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		refreshElements()
		refreshRoles(true)
	end)
end
-- (2026-10-18, economy) what the player owns and holds: the grid's locks, the header's balance, an open confirm
for _, name in ipairs({ "OwnedElements", "Sparks", "DataLoaded", "DataError" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		refreshElements()
		if unlockFor then
			if ownedSet()[unlockFor] then closeUnlock() else fillUnlock() end
		end
	end)
end

-- fit the panel to the screen, off the ScreenGui (Camera.ViewportSize misreports in Studio)
-- the header's note: which kits are built, and how much of a partly built one
do
	local names = {}
	for _, item in ipairs(elementsInOrder()) do
		if Config.IsBuilt(item.Name) then
			local partial = partialTag(item.Name)
			names[#names + 1] = string.upper(item.Def.Display or item.Name) .. (partial and (" (" .. partial .. ")") or "")
		end
	end
	headNote.Text = ""   -- the BUILT list is gone from the header (owner, 2026-10-10); `names` is kept for a debug readout
	headNote.Visible = false
end

local function fit()
	local s = gui.AbsoluteSize
	if s.X < 10 or s.Y < 10 then return end
	fitScale.Scale = math.clamp(math.min(s.X / (DESIGN_W + 70), s.Y / (DESIGN_H + 70)), 0.35, 1.0)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
refreshElements()
refreshRoles(true)
