--[[
	PopArtHUD  (LocalScript)  ->  StarterGui/PopArtHUD

	The in-match HUD on the approved pop-art chassis (SPELLSHOT_Pop-Art_HUD_Kit_v2.pdf, row 01).

	LAYOUT (unchanged from the approved kit):
	  bottom-left   Health bar, Mana bar beneath it, each with its icon chip; readout pills under
	  bottom-right  Primary / Mobility / Defense, then the larger Ultimate;
	                Passive pill above that cluster  (position deliberately left as built)
	  top-centre    round counter
	  top-right     recent-duel feed
	  centre        crosshair

	SECOND REVIEW PASS -- what changed and why:

	  * NO M1 SLOT. The manual makes M1 the always-available left click with no cooldown and no
	    resource, so there is nothing for a slot to display; it was showing a plate whose entire
	    content was an icon that never changed state. The row is four: Primary, Mobility, Defense,
	    Ultimate. Dropping it is most of the fix for the row feeling crowded.

	  * ONE LABEL PER SLOT, NOT TWO. Each slot carried both a keybind chip AND the spelled-out role
	    name. The kit leans on the icon art plus at most a small keybind chip, so the spelled-out
	    word is gone. The Ultimate keeps a word because its label bar is where READY! fires.

	  * THE TOP-RIGHT TAGS ARE A DUEL FEED. They were rendering the local player against a single
	    opponent, which with nobody else in the server produced one tag reading "NAME <gem> --".
	    The same paired-name-plus-separator style appears in the kit's row-4 kill feed, so this is
	    that: the two most recent duel results, hidden entirely when there are none, rather than a
	    permanently half-empty tag.

	  * DENSITY. Benchmarked against RIVALS, which pins everything tight to the edges and never
	    puts a multi-line block on screen. Slots 126 -> 92, Ultimate 158 -> 116, margins 34 -> 22,
	    slimmer bars, hairline play-area border, and MAX_SCALE capped below 1 so the chassis never
	    renders at full authored size even on a large monitor.

	  * The Shield readout pill is gone -- not part of the approved design.

	RENDERED CHASSIS + LIVE TEXT: numerals, names and cooldowns are TextLabels over rendered
	plates. Fixed display words are rendered art, because those need the outline treatment.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local Art = require(folder:WaitForChild("PopArtAssets"))
local Icons = require(folder:WaitForChild("IconAssets"))
local SkinCatalog = require(folder:WaitForChild("SkinCatalog"))
local BarKit = require(folder:WaitForChild("BarKit"))
local Settings = require(folder:WaitForChild("SpellshotSettings"))
-- The ability rows (2026-10-18, umbra), read only for an ESCAPE charge (EscapeCooldown). Guarded: without them the HUD
-- runs as before and no escape chip shows.
local VFXLibrary = nil
do
	local ok, mod = pcall(function()
		return require(ReplicatedStorage:WaitForChild("IceMagic", 10):WaitForChild("VFXLibrary", 10))
	end)
	if ok and type(mod) == "table" then VFXLibrary = mod end
end

----------------------------------------------------------------------------------------------------
-- metrics
----------------------------------------------------------------------------------------------------
-- DESIGN_* is the natural bound of the chassis, so scale 1 would be "authored size". MAX_SCALE is
-- deliberately below 1: at RIVALS density the HUD should never occupy its full authored footprint
-- even on a large monitor.
local DESIGN_W, DESIGN_H = 1060, 600
local MIN_SCALE, MAX_SCALE = 0.34, 0.85

local UI = {
	Margin = 22,
	BarGap = 8,
	ChipGap = 10,
	PillGap = 10,
	SlotGap = 10,
	GroupGap = 12,

	Ink = Color3.fromRGB(17, 17, 17),
	White = Color3.fromRGB(255, 255, 255),
	Red = Color3.fromRGB(228, 37, 31),
	Cyan = Color3.fromRGB(18, 198, 231),
	Gold = Color3.fromRGB(245, 184, 0),
	Grey = Color3.fromRGB(120, 116, 106),
}


-- M1 is intentionally absent: it has no cooldown, no cost and no state to show.
local ROW = { "Primary", "Mobility", "Defense" }
-- the binds in SpellshotInput: the authored defaults; (2026-10-19, audit P5F-18) the chips follow the live Bind_<role> /
-- Pad_<role> settings (refreshKeys, below), the pad column while the last input is a gamepad
local KEY_LABEL = { Primary = "F", Mobility = "Q", Defense = "E", Ultimate = "R" }
local keyChips = {}   -- [role] = { tab = the KeyTab frame, cap = its label }
local COOLDOWN_ROLES = ROW

-- on-screen slot sizes, smaller than the authored plate; the plate is 9-sliced so it holds up
local SLOT = 92
local ULT = 116

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function image(parent, id, props)
	local p = props or {}
	p.Image = id or ""
	p.BackgroundTransparency = 1
	return make("ImageLabel", p, parent)
end

local function sliced(parent, id, slice, props)
	local i = image(parent, id, props)
	if slice then
		i.ScaleType = Enum.ScaleType.Slice
		i.SliceCenter = Rect.new(slice[1], slice[2], slice[3], slice[4])
	end
	return i
end

local function label(parent, props)
	local t = make("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy,
		TextColor3 = UI.Ink, Text = "",
	}, parent)
	for k, v in pairs(props or {}) do t[k] = v end
	return t
end

local function caps(parent, props)
	local t = label(parent, props)
	t.Font = Enum.Font.GothamBlack
	return t
end

----------------------------------------------------------------------------------------------------
-- build
----------------------------------------------------------------------------------------------------
for _, old in ipairs({ "SpellshotHUD", "PopArtHUD", "PopArtHUDReadout", "PopArtHUDEdge",
	"PopArtHUDTop", "IceAbilityHUD" }) do
	local g = playerGui:FindFirstChild(old)
	if g then g:Destroy() end
end

-- IgnoreGuiInset FALSE: the chassis is corner-anchored and would otherwise tuck under Roblox's
-- own topbar. The reaction layer keeps a separate full-bleed ScreenGui for vignettes.
local gui = make("ScreenGui", {
	Name = "PopArtHUD", ResetOnSpawn = false, IgnoreGuiInset = false,
	DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- THE PLAY-AREA BORDER LIVES IN ITS OWN FULL-BLEED ScreenGui.
-- It used to be a child of the HUD, which is IgnoreGuiInset = FALSE so the corner-anchored
-- chassis clears Roblox's topbar. That inset is exactly why the border could never reach the
-- screen: its container started ~36-58px down and the frame was inset a further `e` px on top,
-- leaving the gap at the corners and edges. The border needs the opposite treatment from the
-- chassis, so it gets its own layer with IgnoreGuiInset = TRUE and no margin at all.
--
-- The only inset kept is the stroke's own thickness: UIStroke draws OUTWARD from the frame's
-- bounds, so a frame at exactly fromScale(1, 1) would push its entire border off-screen.
local EDGE = 1
local edgeGui = make("ScreenGui", {
	Name = "PopArtHUDEdge", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 9, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local frameEdge = make("Frame", {
	Name = "PlayFrame", BackgroundTransparency = 1,
	Size = UDim2.new(1, -EDGE * 2, 1, -EDGE * 2),
	Position = UDim2.fromOffset(EDGE, EDGE), ZIndex = 0,
}, edgeGui)
make("UIStroke", { Color = UI.Ink, Thickness = EDGE, Transparency = 0.62 }, frameEdge)

-- THE ROUND COUNTER GETS THE SAME FULL-BLEED TREATMENT, for the same reason.
-- It is top-CENTRE, so unlike the corner chassis it has nothing to gain from clearing Roblox's
-- topbar -- the topbar's own controls live at the far left and far right, and the middle is empty.
-- Sitting in the inset-respecting layer cost it the topbar inset (~58px here) PLUS the chassis
-- margin on top, which is the gap above it: it read as floating rather than as mounted to the top
-- of the play area. Its own layer, full-bleed, with a small margin of its own.
local topGui = make("ScreenGui", {
	Name = "PopArtHUDTop", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 11, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local TOP_MARGIN = 10

-- READOUT LAYER. The health and mana numbers sit in their own ScreenGui above the status-reaction
-- layer, because a bar treatment paints the entire trough -- the frost crust, the acid film -- and
-- the number underneath it is exactly the one you want to read while the treatment is running.
-- Everything else about them is unchanged; they are mirrored onto the bars frame by frame below.
local readoutGui = make("ScreenGui", {
	Name = "PopArtHUDReadout", ResetOnSpawn = false, IgnoreGuiInset = false,
	DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- A zero-size marker at the layout origin. AbsolutePosition on an inset-respecting ScreenGui is
-- reported in a shifted space, and the size of that shift is not worth assuming -- reading it off
-- a known point is exact whatever Roblox's topbar inset happens to be.
-- HUD OPACITY LAYERS. Everything that fades sits inside a CanvasGroup filling its ScreenGui, and
-- the setting is that group's GroupTransparency. A canvas CLIPS to its own bounds, which is why
-- these are screen-sized and not one per corner: the keybind tab above each slot sits outside its
-- group's rectangle and a per-corner canvas would cut it off. The alternative -- walking every
-- drawable and multiplying its transparency -- loses to the cooldown loop and the status
-- treatments, which write those same properties every frame.
local function canvasFor(parent)
	return make("CanvasGroup", {
		Name = "OpacityLayer", BackgroundTransparency = 1, GroupTransparency = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 2,
	}, parent)
end
local canvas = canvasFor(gui)
local topCanvas = canvasFor(topGui)
local readoutCanvas = canvasFor(readoutGui)

local originRef = make("Frame", {
	Name = "OriginRef", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(0, 0), Visible = false,
}, gui)

local readouts = {}

local groups = {}
--- `opts.parent` puts a group on a different ScreenGui (the top-centre plate wants the full-bleed
--- layer); `opts.margin` overrides UI.Margin for that group alone, `opts.marginY` only its vertical.
--- `opts.scale` sizes that one group against the rest of the chassis, leaving its margin alone.
local function group(name, anchor, posScale, w, h, opts)
	opts = opts or {}
	local f = make("Frame", {
		Name = name, BackgroundTransparency = 1,
		AnchorPoint = anchor, Size = UDim2.fromOffset(w, h), ZIndex = 3,
	}, opts.parent or canvas)
	local s = make("UIScale", { Scale = 1 }, f)
	groups[#groups + 1] = { frame = f, scale = s, posScale = posScale, margin = opts.margin, sizeScale = opts.scale,
		marginY = opts.marginY }
	return f
end

-- (the v2 bar/chip/pill art is no longer used here -- BarKit owns that block now)
local TAG_W, TAG_H = Art.Size.NameTag[1], Art.Size.NameTag[2]
local PASS_W, PASS_H = Art.Size.PillPassive[1], Art.Size.PillPassive[2]

-- The health/mana block is BarKit -- built to the kit's own vector geometry, with the mana bar
-- deliberately thinned to 0.57 of the health bar. Its footprint drives this group.
local BL_W, BL_H = BarKit.Size.X, BarKit.Size.Y
local BR_W = SLOT * #ROW + UI.SlotGap * #ROW + ULT
local BR_H = ULT + UI.GroupGap + PASS_H

-- The round counter sits 35% smaller than the kit's plate (asked for 2026-09-13). Only its size: it
-- keeps the same gap to the top edge, and the UI Size setting still scales it with everything else.
local gTopCentre = group("TopCentre", Vector2.new(0.5, 0), Vector2.new(0.5, 0),
	Art.Size.RoundCounter[1], Art.Size.RoundCounter[2],
	{ parent = topCanvas, margin = TOP_MARGIN, scale = 0.65 })
local gTopRight = group("TopRight", Vector2.new(1, 0), Vector2.new(1, 0), TAG_W, TAG_H * 2 + 6)
-- the vitals sit on the very bottom edge of the screen
local gBottomLeft = group("BottomLeft", Vector2.new(0, 1), Vector2.new(0, 1), BL_W, BL_H, { marginY = 6 })
local gBottomRight = group("BottomRight", Vector2.new(1, 1), Vector2.new(1, 1), BR_W, BR_H)

----------------------------------------------------------------------------------------------------
-- crosshair
----------------------------------------------------------------------------------------------------
-- On its OWN full-bleed layer, dead centre of the real screen. It used to live in the HUD layer,
-- which respects Roblox's topbar inset, so it was drawn half the inset (~29 px) BELOW the camera's
-- centre -- and every shot, which aims down the camera's centre, landed above it.
-- Drawn from Frames, not an image: a white plus with an ink outline and a centre dot, one fixed
-- pixel size, crisp and readable on light and dark ground alike.
local crossGui = make("ScreenGui", {
	Name = "PopArtHUDCrosshair", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 12, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
-- CROSS is the authored geometry at Size 100%; the Size row scales it and the Outline row sets the
-- ink thickness. Rebuilt outright on a change rather than tweened: a crosshair that animates while
-- you drag the slider is harder to judge than one that simply is the new shape.
-- NOT part of HUD Opacity, and not scaled by UI Size -- it has its own Size row, and a crosshair
-- you can half-see is a worse crosshair, not a subtler one.
local CROSS = { Arm = 8, Thick = 2, Gap = 4, Dot = 2 }
local crossHolder = make("Frame", {
	Name = "CrosshairHolder", BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(Art.Size.Crosshair[1], Art.Size.Crosshair[2]), ZIndex = 4,
}, crossGui)
-- the pieces get their own holder so a rebuild never touches the marked-hit star beside them
local crossPieces = make("Frame", {
	Name = "Pieces", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
}, crossHolder)

local function buildCrosshair()
	crossPieces:ClearAllChildren()
	local colour = Settings.CrosshairColors[Settings.Get("CrosshairColor")] or UI.White
	local shape = Settings.ById.CrosshairShape.Options[Settings.Get("CrosshairShape")]
	local k = Settings.Get("CrosshairSize") / 100
	local ink = Settings.Get("CrosshairOutline")

	local function piece(name, x, y, w, h, round)
		local f = make("Frame", {
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y),
			Size = UDim2.fromOffset(math.max(1, w), math.max(1, h)), BackgroundColor3 = colour,
			BorderSizePixel = 0, ZIndex = 5,
		}, crossPieces)
		if ink > 0 then make("UIStroke", { Color = UI.Ink, Thickness = ink }, f) end
		if round then make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f) end
		return f
	end

	local arm, thick, gap = CROSS.Arm * k, math.max(1, CROSS.Thick * k), CROSS.Gap * k
	if shape == "CROSS + DOT" or shape == "CROSS" then
		local off = gap + arm / 2
		piece("Up", 0, -off, thick, arm)
		piece("Down", 0, off, thick, arm)
		piece("Left", -off, 0, arm, thick)
		piece("Right", off, 0, arm, thick)
	end
	if shape == "CROSS + DOT" or shape == "DOT" then
		piece("Dot", 0, 0, CROSS.Dot * k, CROSS.Dot * k, true)
	end
	if shape == "CIRCLE" then
		local ring = make("Frame", {
			Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(arm * 2.4, arm * 2.4), BackgroundTransparency = 1, ZIndex = 5,
		}, crossPieces)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		make("UIStroke", { Color = colour, Thickness = math.max(1, thick) }, ring)
		if ink > 0 then
			-- the ink goes on a slightly larger ring behind it: a stroke cannot outline a stroke
			local edge = make("Frame", {
				Name = "RingInk", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(arm * 2.4 + thick * 2, arm * 2.4 + thick * 2),
				BackgroundTransparency = 1, ZIndex = 4,
			}, crossPieces)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, edge)
			make("UIStroke", { Color = UI.Ink, Thickness = ink }, edge)
		end
	end
end

for _, id in ipairs({ "CrosshairColor", "CrosshairShape", "CrosshairSize", "CrosshairOutline" }) do
	Settings.Bind(id, buildCrosshair)
end
local crossStar = image(crossHolder, Art.CrosshairStar[1], {
	Name = "Star", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(70, 70), ZIndex = 3, Visible = false,
})

-- THE CHARGE RING, for a chargeable M1 (Terra's Boulder Shot, 2026-09-17 -- the one there is). A ring that CLOSES
-- in on the crosshair as the rock gathers: it starts wide and shrinks to the crosshair's own size at full charge,
-- so the moment to let go is the moment it lands on the cross rather than a bar you have to read. At full it snaps
-- to the Element's Light tone and thickens, which is the only "ready" state it has. Drawn on the crosshair's own
-- layer, and outside HUD Opacity and UI Size for the same reason the crosshair is.
local chargeRing = make("Frame", {
	Name = "ChargeRing", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 6, Visible = false,
}, crossHolder)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, chargeRing)
local chargeStroke = make("UIStroke", { Color = UI.White, Thickness = 3 }, chargeRing)
local chargeInk = make("Frame", {
	Name = "ChargeRingInk", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, ZIndex = 5, Visible = false,
}, crossHolder)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, chargeInk)
make("UIStroke", { Color = UI.Ink, Thickness = 3 }, chargeInk)

--- The hook SpellshotInput drives: alpha 0..1 while a charge is held, nil to put the ring away.
function _G.SpellshotChargeRing(alpha)
	if not alpha then
		chargeRing.Visible = false
		chargeInk.Visible = false
		return
	end
	local a = math.clamp(alpha, 0, 1)
	local d = math.floor(64 - 44 * a + 0.5)              -- 64 px wide at rest, 20 px (the crosshair) at full
	local full = a >= 0.999
	chargeRing.Size = UDim2.fromOffset(d, d)
	chargeInk.Size = UDim2.fromOffset(d + 6, d + 6)
	chargeStroke.Thickness = full and 5 or 3
	local elem = Config.Elements[player:GetAttribute("Element")]
	chargeStroke.Color = (full and elem) and elem.Light or UI.White
	chargeRing.Visible = true
	chargeInk.Visible = true
end

----------------------------------------------------------------------------------------------------
-- round counter
----------------------------------------------------------------------------------------------------
local rcH = Art.Size.RoundCounter[2]
image(gTopCentre, Art.RoundCounter, { Name = "Plate", Size = UDim2.fromScale(1, 1), ZIndex = 3 })
local scoreL = label(gTopCentre, { Name = "Left", Size = UDim2.fromOffset(92, rcH),
	Position = UDim2.fromOffset(11, 0), TextSize = 30, TextColor3 = UI.Red, ZIndex = 4 })
local roundMid = caps(gTopCentre, { Name = "Mid", Size = UDim2.fromOffset(126, rcH),
	Position = UDim2.fromOffset(103, 0), TextSize = 15, Text = "ROUND", ZIndex = 4 })
local roundMidColor = roundMid.TextColor3
local scoreR = label(gTopCentre, { Name = "Right", Size = UDim2.fromOffset(92, rcH),
	Position = UDim2.fromOffset(229, 0), TextSize = 30, TextColor3 = UI.Cyan, ZIndex = 4 })

----------------------------------------------------------------------------------------------------
-- recent-duel feed (top right)
----------------------------------------------------------------------------------------------------
-- Two rows, most recent on top, each "KILLER <gem> VICTIM" in the kit's paired-name style. Hidden
-- outright when there is nothing to show -- a permanently half-populated tag was the bug here.
local FEED_MAX = 2
local feedRows = {}
local feed = {}       -- newest first; each entry carries the clock time it should disappear at

local function buildFeedRow(index)
	local t = sliced(gTopRight, Art.NameTag, Art.Slice.NameTag, {
		Name = "Duel" .. index, Position = UDim2.fromOffset(0, (index - 1) * (TAG_H + 6)),
		Size = UDim2.fromOffset(TAG_W, TAG_H), ZIndex = 3, Visible = false,
	})
	local killer = caps(t, { Name = "Killer", Size = UDim2.new(0.40, 0, 1, 0),
		Position = UDim2.fromOffset(16, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15, TextColor3 = UI.White, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
	local gem = image(t, "", { Name = "Gem", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 4 })
	local victim = caps(t, { Name = "Victim", Size = UDim2.new(0.40, 0, 1, 0),
		Position = UDim2.new(0.56, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15, TextColor3 = UI.Grey, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
	return { root = t, killer = killer, gem = gem, victim = victim }
end

for i = 1, FEED_MAX do
	feedRows[i] = buildFeedRow(i)
end

local function refreshFeed()
	for i = 1, FEED_MAX do
		local row = feedRows[i]
		local e = feed[i]
		if e then
			row.root.Visible = true
			row.killer.Text = tostring(e.killer):upper()
			row.victim.Text = tostring(e.victim):upper()
			row.gem.Image = (Art.Gem.Diamond and Art.Gem.Diamond[e.element]) or ""
			row.killer.TextColor3 = (e.killer == player.Name) and UI.Gold or UI.White
		else
			row.root.Visible = false
		end
	end
end
refreshFeed()

----------------------------------------------------------------------------------------------------
-- bars
----------------------------------------------------------------------------------------------------
local barKit = BarKit.Build(gBottomLeft, "native", { ValueLayer = readoutCanvas })
local healthBar, manaBar = barKit.bars.Health, barKit.bars.Mana
for _, r in ipairs(barKit.readouts) do
	readouts[#readouts + 1] = r
end

----------------------------------------------------------------------------------------------------
-- ability cluster
----------------------------------------------------------------------------------------------------
local slots = {}
local function buildSlot(role, size, x, isUlt)
	local root = make("Frame", {
		Name = role, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, BR_H - size), Size = UDim2.fromOffset(size, size), ZIndex = 3,
	}, gBottomRight)

	local plate = image(root, isUlt and Art.SlotUlt or Art.Slot, {
		Name = "Plate", Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	if not isUlt then
		plate.ScaleType = Enum.ScaleType.Slice
		plate.SliceCenter = Rect.new(Art.Slice.Slot[1], Art.Slice.Slot[2],
			Art.Slice.Slot[3], Art.Slice.Slot[4])
	end

	local glyph = image(root, "", { Name = "Glyph", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, isUlt and 0.42 or 0.48),
		Size = UDim2.fromOffset(math.floor(size * 0.58), math.floor(size * 0.58)),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 5 })

	local veilClip = make("Frame", { Name = "VeilClip", BackgroundTransparency = 1,
		ClipsDescendants = true, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), ZIndex = 6 }, root)
	image(veilClip, Art.SlotVeil, { Name = "Veil", AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(size, size),
		ImageTransparency = 0.30, ZIndex = 6 })

	local count = label(root, { Name = "Count", Size = UDim2.fromScale(1, 1),
		TextSize = math.floor(size * 0.30), TextColor3 = UI.White, ZIndex = 7 })

	-- ONE readout only. The Ultimate's black bar carries its charge, then READY! -- never the word
	-- "ULTIMATE", which the star glyph and the slot's size already say.
	local nameTag
	if isUlt then
		nameTag = caps(root, { Name = "Name", AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -9), Size = UDim2.fromOffset(size, 14),
			TextSize = 11, TextColor3 = UI.White, ZIndex = 7 })
	end

	-- Every slot gets its keybind tab, the Ultimate included: without one there is nothing on
	-- screen telling the player the key, and a 22px tab is the "small keybind chip" the brief allows.
	local key = KEY_LABEL[role]
	if key then
		local kw = math.max(30, #key * 8 + 14)
		local tab = sliced(root, Art.KeyTab, Art.Slice.KeyTab, {
			Name = "Key", AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -11),
			Size = UDim2.fromOffset(kw, 22), ZIndex = 8 })
		local cap = caps(tab, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -2),
			TextSize = 10, Text = key, ZIndex = 9 })
		keyChips[role] = { tab = tab, cap = cap }
	end

	local charge = image(root, "", { Name = "Charge", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size - 16, size - 16),
		ZIndex = 5, Visible = false })

	-- CHARGE COUNT BADGE, for an ability that holds several uses. (2026-10-19, audit GA-08) no ability row defines Charges
	-- today (Frost Slide's 3 dashes, its first user, is gone), so the badge never shows; kept for a future one. A flat
	-- white chip with the kit's ink stroke and the same LuckiestGuy numeral as the countdown, tucked
	-- over the slot's bottom-right corner the way the keybind tab sits over its top edge. Built for
	-- every row slot and hidden; the per-frame loop shows it only while the character carries a
	-- ChargesMax_<role>, so a loadout without a charge ability never sees it.
	local charges, chargesText
	if not isUlt then
		charges = make("Frame", {
			Name = "Charges", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 1, 4),
			Size = UDim2.fromOffset(24, 24), BackgroundColor3 = UI.White, BorderSizePixel = 0,
			ZIndex = 8, Visible = false,
		}, root)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, charges)
		make("UIStroke", { Color = UI.Ink, Thickness = 2 }, charges)
		chargesText = label(charges, { Name = "Count", Size = UDim2.fromScale(1, 1),
			TextSize = 16, ZIndex = 9 })
	end

	-- THE ESCAPE CHARGE (2026-10-18, umbra): a second, independent use on the same key (Umbra's Shadow Step). A small
	-- hard-edged ink square over the slot's bottom-LEFT corner, the charge badge's mirror: while the escape recharges, paper
	-- fills it from the bottom; ready, it is solid gold (READY!'s colour). Built for every row slot and hidden; the
	-- per-frame loop shows it only while the slot's row has an EscapeCooldown.
	local escape, escapeFill
	if not isUlt then
		escape = make("Frame", {
			Name = "Escape", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -3, 1, 3),
			Size = UDim2.fromOffset(18, 18), BackgroundColor3 = UI.Ink, BorderSizePixel = 0,
			ZIndex = 8, Visible = false,
		}, root)
		make("UIStroke", { Color = UI.Ink, Thickness = 2 }, escape)
		escapeFill = make("Frame", { Name = "Fill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Gold, BorderSizePixel = 0, ZIndex = 9 }, escape)
	end

	-- IMMOLATE'S STACKS (asked for 2026-09-14): how many buffed hits are left, as three pips hung off the slot's
	-- bottom edge -- the motes orbiting your body are out of sight in first person. Each pip is the slot's Element
	-- logo, so Pyro's for Immolate (applyLoadout sets it). Built for every row slot and hidden; the per-frame loop
	-- shows them while the character carries StacksMax_<role>, lit up to Stacks_<role>.
	local pips, pipImages
	if not isUlt then
		pips = make("Frame", {
			Name = "Pips", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(86, 28), BackgroundTransparency = 1, ZIndex = 8, Visible = false,
		}, root)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }, pips)
		pipImages = {}
		for i = 1, 3 do
			pipImages[i] = image(pips, "", { Name = "Stack" .. i, LayoutOrder = i,
				Size = UDim2.fromOffset(28, 28), ScaleType = Enum.ScaleType.Fit, ZIndex = 8 })
		end
	end

	return { root = root, glyph = glyph, veilClip = veilClip, count = count,
		name = nameTag, charge = charge, charges = charges, chargesText = chargesText,
		pips = pips, pipImages = pipImages,
		escape = escape, escapeFill = escapeFill,                 -- (2026-10-18, umbra)
		size = size, isUlt = isUlt }
end

do
	local x = 0
	for _, role in ipairs(ROW) do
		slots[role] = buildSlot(role, SLOT, x, false)
		x += SLOT + UI.SlotGap
	end
	slots.Ultimate = buildSlot("Ultimate", ULT, x, true)
end

-- Passive pill position left exactly as previously built
local passivePill = sliced(gBottomRight, Art.PillPassive, Art.Slice.PillPassive, {
	Name = "PassivePill", AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(BR_W, 0), Size = UDim2.fromOffset(PASS_W, PASS_H), ZIndex = 3,
})
local passiveGem = image(passivePill, "", { Name = "Gem", AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(22, 22), ZIndex = 4 })
local passiveText = caps(passivePill, { Name = "Text", AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 44, 0.5, 0), Size = UDim2.new(1, -58, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, ZIndex = 4 })
-- (2026-10-19, audit GA-10) THE PASSIVE'S STACKS: a passive that publishes StacksMax_Passive / Stacks_Passive on the
-- character (Terra's Bedrock, TerraHandler: 5) gets a row of its Element's logos at the pill's right end, lit up to
-- the count, as Immolate's pips are on a slot. Pips are made as the max needs them; hidden while there is no max.
local passivePips = make("Frame", {
	Name = "Pips", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 1, ZIndex = 5, Visible = false,
}, passivePill)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }, passivePips)
local passivePipImages = {}

----------------------------------------------------------------------------------------------------
-- responsive scale
----------------------------------------------------------------------------------------------------
local currentScale = 1

local function applyScale()
	-- Measure the ScreenGui, NOT camera.ViewportSize. The camera reports 1x1 for the first frames
	-- of a play session (and in Studio it can stay 1x1 indefinitely), and a scale computed from that
	-- clamps to MIN_SCALE and never recovers -- which rendered the whole chassis at 34%.
	local vp = gui.AbsoluteSize
	if vp.X < 8 or vp.Y < 8 then
		vp = camera.ViewportSize
	end
	if vp.X < 8 or vp.Y < 8 then
		return                      -- nothing sane to measure yet; the resize signal will retry
	end
	-- The fit to the screen first, then the player's own UI Size on top of it -- which is what the
	-- row promises, and why the fit is clamped before the multiply rather than after. One number
	-- drives every corner, the readout numbers and (through GetScale) the status treatments, so the
	-- whole HUD grows and shrinks together.
	local s = math.clamp(math.min(vp.X / DESIGN_W, vp.Y / DESIGN_H), MIN_SCALE, MAX_SCALE)
	s *= Settings.Scale("UIScale")
	currentScale = s
	for _, g in ipairs(groups) do
		g.scale.Scale = s * (g.sizeScale or 1)
		local m = math.max(4, math.floor((g.margin or UI.Margin) * s))
		local my = math.max(4, math.floor((g.marginY or g.margin or UI.Margin) * s))
		local px = (g.posScale.X == 0) and m or ((g.posScale.X == 1) and -m or 0)
		local py = (g.posScale.Y == 0) and my or ((g.posScale.Y == 1) and -my or 0)
		if g.frame == gTopCentre then py += (topCanvas:GetAttribute("CompassShift") or 0) end -- the heading compass sits above the round plate; HeadingCompassClient sets this, in px
		g.frame.Position = UDim2.new(g.posScale.X, px, g.posScale.Y, py)
	end
	for _, r in ipairs(readouts) do
		r.scale.Scale = s * (r.rowScale or 1)     -- a bar row can be scaled inside the group
	end
	-- frameEdge is deliberately NOT rescaled here: it tracks the real screen, not the chassis
	-- margin, so it stays flush at every resolution.
end

local function applyOpacity()
	local alpha = Settings.Scale("HUDOpacity")
	canvas.GroupTransparency = 1 - alpha
	topCanvas.GroupTransparency = 1 - alpha
	readoutCanvas.GroupTransparency = 1 - alpha
end

--- Text Size, on top of whatever each label was authored at. The authored sizes are captured on the
--- first call, so repeated changes scale the original rather than compounding.
local textBase = nil

local function applyTextSize()
	local k = Settings.Scale("TextSize")
	if not textBase then
		textBase = {}
		for _, root in ipairs({ gui, topGui, readoutGui }) do
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					textBase[#textBase + 1] = { o = d, v = d.TextSize }
				end
			end
		end
	end
	for _, e in ipairs(textBase) do
		e.o.TextSize = math.max(6, math.floor(e.v * k + 0.5))
	end
end

-- (2026-10-19, audit P5F-18) the slot chips show the player's own binds, not a hardcoded F/Q/E/R
do
	local UserInputService = game:GetService("UserInputService")
	local function onPad()
		local t = UserInputService:GetLastInputType()
		return t ~= nil and t.Name:find("^Gamepad") ~= nil
	end
	local function refreshKeys()
		local pad = onPad()
		for role, chip in pairs(keyChips) do
			local text = Settings.KeyText((pad and "Pad_" or "Bind_") .. role)
			if chip.cap then chip.cap.Text = text end
			if chip.tab then chip.tab.Size = UDim2.fromOffset(math.max(30, #text * 8 + 14), 22) end
		end
	end
	for role in pairs(keyChips) do
		Settings.OnChange("Bind_" .. role, refreshKeys)
		Settings.OnChange("Pad_" .. role, refreshKeys)
	end
	local lastPad = onPad()
	UserInputService.LastInputTypeChanged:Connect(function()
		local pad = onPad()
		if pad ~= lastPad then
			lastPad = pad
			refreshKeys()
		end
	end)
	refreshKeys()
end

applyScale()
Settings.Bind("UIScale", applyScale)
Settings.Bind("HUDOpacity", applyOpacity)
Settings.Bind("TextSize", applyTextSize)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
topCanvas:GetAttributeChangedSignal("CompassShift"):Connect(applyScale)
-- one deferred pass, because AbsoluteSize is not final on the frame the GUI is parented
task.defer(applyScale)
task.delay(0.5, applyScale)

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local function attr(inst, name, default)
	if not inst then return default end
	local v = inst:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function loadout()
	return {
		Element = attr(player, "Element", Config.DefaultLoadout.Element),
		Mobility = attr(player, "Mobility", Config.DefaultLoadout.Mobility),
		Defense = attr(player, "Defense", Config.DefaultLoadout.Defense),
		Ultimate = attr(player, "Ultimate", Config.DefaultLoadout.Ultimate),
	}
end

local current = loadout()

-- What each row slot holds, by Id (the per-ability extras below key off this). Since v0.7 (2026-09-24) the two
-- Technique slots are the player's picks from ONE pool -- a Pyro's default Detonate and Scorching Lash among them --
-- so this is the attribute again; the 2026-09-23 Element-fixed slots are gone.
local slotIds = {}

-- An ability that needs a TARGET to go: its slot stays dimmed, as for a cooldown, until the server says there is one.
-- The value is a server-time attribute on the character (Detonate, 2026-09-23: PyroHandler publishes DetonateUntil
-- from the caster's last Fireball or Immolate hit; nil or past means nobody to mark, and the press is refused free).
local TARGET_UNTIL = { Detonate = "DetonateUntil" }

-- AN ABILITY'S OWN ICON (2026-10-06). IconAssets.Ability holds one per ability that has art: Primary by Element,
-- Technique and Ultimate by pool key. A slot shows it larger than a Role glyph (72% of the slot against 58%: the
-- owner's pick, the icons are drawn to fill their frame). An ability with no icon keeps its Role glyph, old size.
local ABILITY = Icons.Ability or {}
local OWN_PRIMARY, OWN_TECHNIQUE, OWN_ULTIMATE = ABILITY.Primary or {}, ABILITY.Technique or {}, ABILITY.Ultimate or {}
local GLYPH_FRAC, ICON_FRAC = 0.58, 0.72
-- A SKIN'S HUD SET (2026-10-14): while the player's own Element skin has one (SkinCatalog.HudSkin), its icon takes the
-- slot -- the same size, tile, key tab, veil and READY. A borrowed Technique (another Element's) keeps its own icon, and
-- an id not uploaded yet (empty) keeps the Default icon.
local SKINNED = ABILITY.Skins or {}
local function skinIcon(elem, pool, key)
	local hs = SkinCatalog.HudSkin(player, elem)
	local t = hs ~= "Default" and SKINNED[hs] and SKINNED[hs][pool]
	local id = t and t[key]
	return (type(id) == "string" and id ~= "") and id or nil
end
local function setGlyph(slot, icon, fallback)
	local px = math.floor(slot.size * (icon and ICON_FRAC or GLYPH_FRAC))
	slot.glyph.Size = UDim2.fromOffset(px, px)
	slot.glyph.Image = icon or fallback
end

-- [role] = the row's EscapeCooldown when the slot holds an escape charge, else nil (2026-10-18, umbra)
local escapeOf = {}

local function applyLoadout()
	current = loadout()
	for _, role in ipairs(ROW) do
		slotIds[role] = current[role]
		local okRow, row = pcall(function() return VFXLibrary and VFXLibrary.AbilityFor(player, role) end)
		local esc = okRow and type(row) == "table" and row.EscapeCooldown
		escapeOf[role] = (type(esc) == "number" and esc > 0) and esc or nil
		local elem = Config.SlotElement(current, role)
		-- a Technique's glyph is its own half of the pool's (a Chill Aura in Q still wears the defensive glyph), in its
		-- origin's colours; the Primary's is the Primary's
		local _, half = Config.Technique(current[role])
		local art = Art.Role[half or role]
		local own
		if role == "Primary" then own = skinIcon(elem, "Primary", elem) or OWN_PRIMARY[elem]
		elseif current[role] then own = skinIcon(elem, "Technique", current[role]) or OWN_TECHNIQUE[current[role]] end
		setGlyph(slots[role], own, (art and art[elem]) or "")
		for _, pip in ipairs(slots[role].pipImages or {}) do
			pip.Image = Icons.Element[elem] or ""
		end
	end
	local ue = Config.SlotElement(current, "Ultimate")
	setGlyph(slots.Ultimate, current.Ultimate and (skinIcon(ue, "Ultimate", current.Ultimate) or OWN_ULTIMATE[current.Ultimate]),
		(Art.Role.Ultimate and Art.Role.Ultimate[ue]) or "")

	local pe = current.Element
	passiveGem.Image = (Art.Gem.Dot and Art.Gem.Dot[pe]) or ""
	local def = Config.Elements[pe]
	passiveText.Text = ((def and def.Passive.Name) or ""):upper()
	for _, pip in ipairs(passivePipImages) do pip.Image = Icons.Element[pe] or "" end   -- (2026-10-19, audit GA-10)
end

applyLoadout()
for _, n in ipairs({ "Element", "Mobility", "Defense", "Ultimate" }) do
	player:GetAttributeChangedSignal(n):Connect(applyLoadout)
end
player.AttributeChanged:Connect(function(n)                -- a skin put on or off (or a Studio HUD preview)
	if n:match("^ElementSkin_") or n:match("^HudSkinPreview_") then applyLoadout() end
end)

----------------------------------------------------------------------------------------------------
-- per-frame
----------------------------------------------------------------------------------------------------
local shownHealth, shownMana = 1, 1
local lastHealthFrac = 1
local crossAcc, crossFrame = 0, 1

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = os.clock()

	local hp = humanoid and humanoid.Health or 0
	local maxHp = (humanoid and humanoid.MaxHealth > 0) and humanoid.MaxHealth or Config.MaxHealth
	local hFrac = math.clamp(hp / maxHp, 0, 1)
	if hFrac < lastHealthFrac - 0.002 and _G.SpellshotReactions then
		-- (2026-10-19, audit GA-07) any HP loss is not a burn tick: a neutral "Damage" burst once StatusReactions
		-- advertises one (RX.Handles.Damage), the burn art only until then
		local RX = _G.SpellshotReactions
		RX.Pulse((RX.Handles and RX.Handles.Damage) and "Damage" or "BurnTick",
			{ Amount = math.ceil((lastHealthFrac - hFrac) * maxHp) })
	end
	lastHealthFrac = hFrac
	shownHealth += (hFrac - shownHealth) * math.clamp(16 * dt, 0, 1)
	barKit.Set("Health", shownHealth, tostring(math.max(0, math.floor(hp + 0.5))))

	local mana = attr(character, "Mana", Config.MaxMana)
	local mFrac = math.clamp(mana / Config.MaxMana, 0, 1)
	shownMana += (mFrac - shownMana) * math.clamp(16 * dt, 0, 1)
	barKit.Set("Mana", shownMana, tostring(math.floor(mana + 0.5)))

	-- keep the readouts sitting on their bars; they live in a different ScreenGui, so they are
	-- placed from the bar's absolute rect rather than carried along by the corner group's layout
	local shift = originRef.AbsolutePosition
	for _, r in ipairs(readouts) do
		local a = r.bar.AbsolutePosition
		r.hold.Position = UDim2.fromOffset(
			a.X - shift.X + r.ox * currentScale,
			a.Y - shift.Y + r.oy * currentScale)
	end

	-- CD_<role> is stamped in SERVER time (workspace:GetServerTimeNow). It used to be the server's
	-- os.clock(), a per-machine clock that has nothing to do with this client's, so the countdown
	-- read against it was off by however far the two machines' clocks happened to sit apart.
	local serverNow = workspace:GetServerTimeNow()
	for _, role in ipairs(COOLDOWN_ROLES) do
		local slot = slots[role]
		local readyAt = attr(character, "CD_" .. role, 0)
		local total = attr(character, "CDTotal_" .. role, 1)
		local remain = math.max(0, readyAt - serverNow)
		-- A charge ability: the badge carries the count, and while any charge is left the slot stays
		-- lit with no countdown -- the short gap between two uses is not worth a flicker of veil.
		-- Only at zero does the veil run, against the next charge's return (CD_/CDTotal_ then).
		local maxCharges = attr(character, "ChargesMax_" .. role, nil)
		if slot.charges then
			slot.charges.Visible = maxCharges ~= nil
		end
		if maxCharges ~= nil then
			local left = attr(character, "Charges_" .. role, maxCharges)
			if slot.chargesText then
				slot.chargesText.Text = tostring(math.floor(left))
			end
			if left > 0 then
				remain = 0
			end
		end
		-- the escape charge (2026-10-18, umbra): solid gold when ready, filling with paper from the bottom while it recharges
		if slot.escape then
			local escTotal = escapeOf[role]
			slot.escape.Visible = escTotal ~= nil
			if escTotal then
				local escLeft = math.max(0, attr(character, "CDEscape_" .. role, 0) - serverNow)
				local escAll = attr(character, "CDEscapeTotal_" .. role, escTotal)
				local filled = (escAll > 0) and (1 - math.clamp(escLeft / escAll, 0, 1)) or 1
				slot.escapeFill.Size = UDim2.fromScale(1, escLeft > 0 and filled or 1)
				slot.escapeFill.BackgroundColor3 = escLeft > 0 and UI.White or UI.Gold
			end
		end
		-- Immolate's stacks: lit up to Stacks_<role>, dark past it
		local maxStacks = attr(character, "StacksMax_" .. role, nil)
		if slot.pips then
			slot.pips.Visible = maxStacks ~= nil
			if maxStacks ~= nil then
				local lit = attr(character, "Stacks_" .. role, 0)
				for i, flame in ipairs(slot.pipImages) do
					flame.ImageTransparency = (i <= lit) and 0 or 0.55
					flame.ImageColor3 = (i <= lit) and UI.White or Color3.fromRGB(60, 52, 48)
				end
			end
		end

		-- nobody to target (Detonate with no recent hit): the glyph dims as it does for a cooldown, with no veil or count
		local targetAttr = TARGET_UNTIL[slotIds[role]]
		local noTarget = targetAttr ~= nil and attr(character, targetAttr, 0) <= serverNow

		local frac = (total > 0) and math.clamp(remain / total, 0, 1) or 0
		slot.veilClip.Size = UDim2.new(1, 0, frac, 0)
		slot.count.Text = remain > 0 and string.format(remain >= 10 and "%d" or "%.1f", remain) or ""
		slot.glyph.ImageTransparency = (remain > 0 or noTarget) and 0.45 or 0
	end

	-- (2026-10-19, audit GA-10) the passive's stacks (Bedrock): lit up to Stacks_Passive, dark past it
	do
		local maxP = attr(character, "StacksMax_Passive", nil)
		maxP = (type(maxP) == "number" and maxP >= 1) and math.min(math.floor(maxP), 8) or nil
		passivePips.Visible = maxP ~= nil
		if maxP then
			for i = #passivePipImages + 1, maxP do
				passivePipImages[i] = image(passivePips, Icons.Element[current.Element] or "", { Name = "Stack" .. i,
					LayoutOrder = i, Size = UDim2.fromOffset(20, 20), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 })
			end
			local lit = attr(character, "Stacks_Passive", 0)
			for i, pip in ipairs(passivePipImages) do
				pip.Visible = i <= maxP
				pip.ImageTransparency = (i <= lit) and 0 or 0.55
				pip.ImageColor3 = (i <= lit) and UI.White or Color3.fromRGB(60, 52, 48)
			end
		end
	end

	do
		local slot = slots.Ultimate
		local charge = math.clamp(attr(character, "UltCharge", 0), 0, 1)
		local ready = charge >= 1
		slot.veilClip.Size = UDim2.new(1, 0, 1 - charge, 0)
		slot.count.Text = ""            -- the charge lives in the label bar, not over the glyph too
		slot.glyph.ImageTransparency = ready and 0 or 0.35
		if ready then
			slot.name.Text = "READY!"
			slot.name.TextColor3 = UI.Gold
			slot.name.TextTransparency = 0.10 * (1 - (0.5 + 0.5 * math.sin(now * 6)))
		else
			slot.name.Text = string.format("%d%%", math.floor(charge * 100))
			slot.name.TextColor3 = UI.White
			slot.name.TextTransparency = 0
		end
	end

	if crossStar.Visible then
		crossAcc += dt
		if crossAcc >= 0.12 then
			crossAcc = 0
			crossFrame = crossFrame % #Art.CrosshairStar + 1
			crossStar.Image = Art.CrosshairStar[crossFrame]
		end
	end

	scoreL.Text = tostring(attr(player, "RoundsWon", 0))
	scoreR.Text = tostring(attr(player, "RoundsLost", 0))

	-- the round clock (DuelMatch's RoundEndsAt, server time; 2026-10-17): the plate's middle counts down instead of ROUND
	local endsAt = player:GetAttribute("RoundEndsAt")
	if type(endsAt) == "number" then
		local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		-- (2026-10-19, audit GA-09) both sizes x Text Size, as applyTextSize scales every other label
		roundMid.Text = string.format("%d:%02d", left // 60, left % 60)
		roundMid.TextSize = math.max(6, math.floor(22 * Settings.Scale("TextSize") + 0.5))
		roundMid.TextColor3 = (left <= 10) and UI.Red or roundMidColor
	elseif roundMid.Text ~= "ROUND" then
		roundMid.Text = "ROUND"
		roundMid.TextSize = math.max(6, math.floor(15 * Settings.Scale("TextSize") + 0.5))
		roundMid.TextColor3 = roundMidColor
	end
end)

----------------------------------------------------------------------------------------------------
-- hooks
----------------------------------------------------------------------------------------------------
local HUD = {}

function HUD.SetCrosshairMarked(on)
	crossStar.Visible = on and true or false
end

local pulseConn
function HUD.PulseHealthBorder(on)
	if pulseConn then pulseConn:Disconnect(); pulseConn = nil end
	if not on then healthBar.pulse.Thickness = 0; return end
	pulseConn = RunService.RenderStepped:Connect(function()
		-- (2026-10-19, audit GA-11) under Reduce Flashing the border holds steady at its middle width (no 2.5 Hz pulse)
		if Settings.Get("ReduceFlashing") then
			healthBar.pulse.Thickness = 2
		else
			healthBar.pulse.Thickness = 1 + 2 * math.abs(math.sin(os.clock() * 8))
		end
	end)
end

function HUD.SetCharge(role, alpha)
	local slot = slots[role]
	if not slot then return end
	if not alpha or alpha <= 0 then slot.charge.Visible = false; return end
	slot.charge.Visible = true
	slot.charge.Image = Art.Charge[math.clamp(math.floor(alpha * #Art.Charge) + 1, 1, #Art.Charge)]
	if alpha >= 1 and _G.SpellshotReactions then
		_G.SpellshotReactions.Pulse("Ready", { Slot = "Slot" .. role })   -- (2026-10-19, audit GA-08) the role's own slot
		slot.charge.Visible = false
	end
end

--- Push a duel result onto the top-right feed. Newest first, capped at FEED_MAX.
function HUD.PushKill(killer, victim, element)
	table.insert(feed, 1, { killer = killer, victim = victim, element = element or "Cryo",
		expires = os.clock() + Settings.Get("KillFeedDuration") })
	while #feed > FEED_MAX do table.remove(feed) end
	refreshFeed()
end

-- An entry used to stay until two newer ones pushed it off, so on a quiet server the last duel sat
-- in the corner for the rest of the match. Kill Feed Duration is how long one lives.
task.spawn(function()
	while true do
		task.wait(0.25)
		local now, dropped = os.clock(), false
		for i = #feed, 1, -1 do
			if feed[i].expires and now >= feed[i].expires then
				table.remove(feed, i)
				dropped = true
			end
		end
		if dropped then refreshFeed() end
	end
end)

function HUD.ClearKills()
	feed = {}
	refreshFeed()
end

function HUD.GetScale() return currentScale end

_G.SpellshotHUD = HUD

-- Real kills arrive on this RemoteEvent once the match layer fires it; until then the feed stays
-- empty and hidden, and the dev panel can push test entries.
task.spawn(function()
	local ev = folder:FindFirstChild("KillFeed") or folder:WaitForChild("KillFeed", 15)
	if ev and ev:IsA("RemoteEvent") then
		ev.OnClientEvent:Connect(function(killer, victim, element)
			HUD.PushKill(killer, victim, element)
		end)
	end
end)

local function registerSurfaces()
	local RX = _G.SpellshotReactions
	if not RX then return false end
	-- BarKit's interior IS the trough (the chassis is that frame plus its stroke), so bar and
	-- trough register to the same instance. Fill stays the clip, which is what tracks the value.
	RX.RegisterSurface("HealthBar", healthBar.interior)
	RX.RegisterSurface("HealthTrough", healthBar.interior)
	RX.RegisterSurface("HealthFill", healthBar.clip)
	RX.RegisterSurface("ManaBar", manaBar.interior)
	RX.RegisterSurface("ManaTrough", manaBar.interior)
	RX.RegisterSurface("ManaFill", manaBar.clip)
	RX.RegisterSurface("PassivePill", passivePill)
	RX.RegisterSurface("SlotUltimate", slots.Ultimate.root)
	for _, role in ipairs(ROW) do
		RX.RegisterSurface("Slot" .. role, slots[role].root)
	end
	RX.HealthBorderPulse = HUD.PulseHealthBorder
	RX.GetScale = HUD.GetScale
	return true
end

task.spawn(function()
	for _ = 1, 200 do
		if registerSurfaces() then break end
		task.wait(0.1)
	end
end)

return nil
