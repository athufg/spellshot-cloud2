--[[
	HubLifeKit  (ModuleScript)  ->  ReplicatedStorage/Spellshot/HubLifeKit

	The NEWSPRINT kit for the hub-life boards (2026-10-25): the wrap pedestal's nameplate, the TOP DUELISTS board and the
	duel pads' VS card. The same palette, slab, chip and display type as the REACTIONS board (ReactionsBoard, which takes
	them from house_kit_reference.luau / Quick Play): paper, a heavy ink border, one solid ink shadow down-right, the
	halftone dot, LuckiestGuy display type with a darker extrude, GothamBlack chips. Client only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local K = {}

K.C = {
	Ink = Color3.fromRGB(17, 17, 17),
	Paper = Color3.fromRGB(234, 229, 216),
	Card = Color3.fromRGB(246, 243, 235),
	Pill = Color3.fromRGB(250, 247, 240),
	Gold = Color3.fromRGB(245, 184, 0),
	CreamText = Color3.fromRGB(250, 244, 232),
	Track = Color3.fromRGB(222, 213, 196),
	Grey = Color3.fromRGB(120, 116, 106),
	LockedInk = Color3.fromRGB(88, 82, 72),
	White = Color3.new(1, 1, 1),
}
K.DOT = "rbxassetid://82944445925061"
K.MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

-- the shop's rarity colours (CardKit's RARITY, the colour roles the owner approved)
K.Rarity = {
	Common = { Word = "COMMON", Color = Color3.fromHex("8A94A6") },
	Uncommon = { Word = "UNCOMMON", Color = Color3.fromHex("5BC236") },   -- (2026-10-26: the catalog's Uncommon wraps had no rung)
	Rare = { Word = "RARE", Color = Color3.fromHex("2F8CFF") },
	Epic = { Word = "EPIC", Color = Color3.fromHex("9B4DFF") },
	Mythic = { Word = "MYTHIC", Color = Color3.fromHex("FF9E1F") },
	Seasonal = { Word = "SEASONAL", Color = Color3.fromHex("17C3A3") },
}

function K.make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end
local make = K.make

function K.corner(parent, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

function K.outline(parent, t, colour)
	return make("UIStroke", { Color = colour or K.C.Ink, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

function K.halftone(parent, alpha, colour, pitch, z)
	return make("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = K.DOT, ImageColor3 = colour or K.C.Ink,
		ImageTransparency = alpha, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(pitch, pitch),
		Size = UDim2.fromScale(1, 1), ZIndex = z or 1,
	}, parent)
end

--- Quick Play's slab: a holder, one solid ink shadow down-right, a flat face with a heavy ink border. Sized by `size`
--- (a UDim2), placed by `pos` (top-left). Returns holder, face.
function K.slab(parent, size, pos, colour, z, shadow, border, radius)
	shadow, border, radius = shadow or 8, border or 3, radius or 3
	local holder = make("Frame", { BackgroundTransparency = 1, Size = size, Position = pos, ZIndex = z or 2 }, parent)
	local sh = make("Frame", {
		Name = "Shadow", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, ZIndex = (z or 2),
		Size = UDim2.new(1, -shadow, 1, -shadow), Position = UDim2.fromOffset(shadow, shadow),
	}, holder)
	K.corner(sh, radius)
	local face = make("Frame", {
		Name = "Face", BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = (z or 2) + 1,
		Size = UDim2.new(1, -shadow, 1, -shadow),
	}, holder)
	K.corner(face, radius)
	K.outline(face, border)
	return holder, face
end

--- LuckiestGuy display type with a darker extrude behind it (the REACTIONS titles)
function K.display(parent, props, depth, faceColour, extrudeColour)
	local z = props.ZIndex or 6
	local top
	for _, spec in ipairs({ { extrudeColour, depth, z }, { faceColour, 0, z + 1 } }) do
		local l = make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextXAlignment = Enum.TextXAlignment.Left }, parent)
		for k, v in pairs(props) do l[k] = v end
		l.TextColor3 = spec[1]
		l.ZIndex = spec[3]
		l.Position = props.Position + UDim2.fromOffset(spec[2], spec[2])
		top = l
	end
	return top
end

local function lin(c) return (c <= 0.04045) and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function luminance(c) return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B) end
--- ink or cream, whichever reads better on bg
function K.wordOn(bg)
	local l = luminance(bg)
	local onInk = (l + 0.05) / (luminance(K.C.Ink) + 0.05)
	local onCream = (luminance(K.C.CreamText) + 0.05) / (l + 0.05)
	return onInk >= onCream and K.C.Ink or K.C.CreamText
end

local Icons, Config = nil, nil
local function load()
	if Config == nil then
		local spell = ReplicatedStorage:WaitForChild("Spellshot")
		local ok1, c = pcall(require, spell:WaitForChild("SpellshotConfig"))
		local ok2, i = pcall(require, spell:WaitForChild("IconAssets"))
		Config = ok1 and c or false
		Icons = ok2 and i or false
	end
end

--- the game's logo for an Element, or nil while it only borrows Zephyr's (the REACTIONS board's rule)
function K.logoFor(element)
	load()
	local ids = (Icons and Icons.Element) or {}
	local id = ids[element]
	if not id or id == "" then return nil end
	if element ~= "Zephyr" and id == ids.Zephyr then return nil end
	return id
end

function K.element(element)
	load()
	return Config and Config.Elements and Config.Elements[element]
end

--- An Element chip: the Element's colour, a paper well with its logo, its name (the REACTIONS chip). w x h px.
function K.chip(parent, element, x, y, w, h, textSize, z)
	z = z or 4
	local def = K.element(element)
	local base = def and def.Base or K.C.Track
	local face = make("Frame", {
		Name = "Chip_" .. tostring(element), BackgroundColor3 = base, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z,
	}, parent)
	K.corner(face, 4)
	K.outline(face, 2)
	local inset = 3
	local tx = 8
	local logo = K.logoFor(element)
	if logo then
		local well = h - 2 * inset
		local wf = make("Frame", { Name = "Logo", BackgroundColor3 = K.C.Pill, BorderSizePixel = 0, Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.fromOffset(well, well), ZIndex = z + 1 }, face)
		K.corner(wf, 4)
		make("ImageLabel", { BackgroundTransparency = 1, Image = logo, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94), ZIndex = z + 2 }, wf)
		tx = inset + well + math.ceil(inset * 1.5)
	end
	make("TextLabel", {
		Name = "Word", BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
		Text = string.upper(def and def.Display or tostring(element)), TextColor3 = K.wordOn(base), TextSize = textSize or 14,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(tx, 1), Size = UDim2.new(1, -tx - inset, 1, -2), ZIndex = z + 1,
	}, face)
	return face
end

--- THE rarity mark (the shop's rule): a small ink chip, the word in the rarity colour (a touch lighter, for contrast)
function K.rarityChip(parent, rarity, x, y, h, textSize, z)
	local R = K.Rarity[rarity] or K.Rarity.Common
	local f = make("Frame", { Name = "Rarity", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z or 6 }, parent)
	K.corner(f, 4)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, f)
	make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = R.Word, TextSize = textSize or 14,
		TextColor3 = R.Color:Lerp(K.C.White, 0.15), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = (z or 6) + 1 }, f)
	return f
end

return K
