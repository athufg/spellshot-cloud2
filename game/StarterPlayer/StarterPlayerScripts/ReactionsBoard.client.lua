--[[
	ReactionsBoard  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/ReactionsBoard

	THE REACTIONS SCREEN in the Arcane Observatory Hub's Loadout room (2026-10-15, round 25; v3 the same day).

	  * THE WALL SCREEN. A SurfaceGui (in PlayerGui, adorned to Functional.TV_Reactions_Screen) draws the chart in the
	    NEWSPRINT kit. TV_Reactions_Screen is an invisible part laid exactly on the REACTIONS display's screen face: the
	    face itself is a few triangles inside the merged OBS_Screen_Dark_01 mesh. Its place comes from the Blender
	    script's R19_DISPLAYS entry "Reactions" (hub_v23.py), mapped Roblox = Blender (-x, z, y) + (8000, 0, 8000).
	  * THE TABLET (v2, the owner on 2026-10-15: "it shouldnt open a full screen ui, like the tablet ui still should be
	    there and inside that would be reactions"). Clicking or tapping the screen brings the board itself up in front
	    of you: the same cut-corner housing, white lit line, REACTIONS header plate and gold tab as the display on the
	    wall, with the reactions inside. It floats in the middle of the screen with the world all round it: no
	    backdrop, no dimming. The X on its corner or Escape puts it away. Nothing on the SurfaceGui is a button: a world
	    button under the first-person cursor stops the camera turning (HubClient's prompt fix, 2026-10-14).
	  * v3 (the owner's answers, 2026-10-15: "remove", "remove", "build now, and also increase overall scale byy 40%",
	    "closes once u walk a few steps"):
	      - Toxic Squall is off the list, and the SOON tags and their legend line are gone, on the wall and the tablet.
	        Ten reactions in two columns of five, the left one read first.
	      - THE PC TABLET is 1.4 times its v2 size on a 1920 x 1080 screen: every text, the chips, the X, the header
	        plate and the frame's border. The board's 4:3 frame cannot grow 1.4 times inside 1080 px, so the frame is
	        drawn wider (housing, lit line, cut corners and screen face are built here at any size; the header plate,
	        its lettering and the gold tab are the Blender library's shapes, scaled) and each card is wide enough to
	        hold its line in two rows. Sized off the screen with no cap: about 1.01 at 1920 x 1080.
	      - THE PHONE TABLET: on any screen under PHONE_MAX_H (500 px) high, for example a phone in landscape
	        (844 x 390, 667 x 375), the tablet is the same frame round ONE column of cards that scrolls, at real pixel
	        sizes (no scaling): descriptions 14 px, names 20, chip words 12, the X 46 x 46.
	      - WALKING AWAY puts it away: once the character is WALK_AWAY (4) studs, measured flat, from where it stood
	        when the tablet opened. Turning on the spot or looking round does not move the character, so it stays.
	    The part carries a ClickDetector "ReactionsClick", and it is listened to, BUT on 2026-10-15 it never fires from
	    the hall: the Hub's merged Visual meshes keep their default collision hulls and CanQuery, and those hulls
	    (OBS_Stone_Dress_02 is 78 x 26 x 172 studs) sit between the camera and the screen, so the mouse's target is
	    the hull. So this script also picks the screen itself: a short click or tap (not a drag) whose ray reaches
	    TV_Reactions_Screen, within the ClickDetector's own reach, with none of the Hub's Colliders in the way, opens
	    the tablet. It reads input and sinks nothing, so the camera turns as before. Casting is off in the Hub
	    (Zone "Hub"), so the left click that opens the tablet fires no M1.
	  * THE CURSOR. While the tablet is up the mouse is won back from first person the way Quick Play and the Loadout
	    do it (a render step at Camera + 10), and ReactionsOpen is published on the player like QuickPlayOpen. Another
	    screen opening (Settings, Loadout, Quick Play, the Shop) puts the tablet away, as the Shop does for those.
	  * ESCAPE closes the tablet even though Roblox's own menu takes the same key (it arrives gameProcessed, so a
	    gameProcessed check would never see it); Roblox's menu opens as well, as it does over any screen.

	THE LIST is the design manual's Elemental Reactions table (v0.23, lines 485-495), in its order, each row's words
	put plainly (SPELLSHOT_Backup/hub/observatory_2026_10_07/v25_reactions/REACTIONS.md), without Toxic Squall (the
	owner, 2026-10-15). None of the ten is in the game's code yet; the board no longer says so.

	The chips are SpellshotConfig.Elements' own Base colours and IconAssets.Element's logos. An Element whose logo is
	still Zephyr's placeholder (Aqua, 2026-10-15) shows its colour and name and no logo, rather than Zephyr's.

	For tools: the ScreenGui "ReactionsBoardView" carries a BindableEvent "Command" -- Fire("open"), Fire("close") --
	and the attributes Layout ("pc" / "phone") and FitScale.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local Icons = require(folder:WaitForChild("IconAssets"))

local HUB, SCREEN, CLICK = "ArcaneObservatoryHub", "TV_Reactions_Screen", "ReactionsClick"
local CURSOR_STEP = "SpellshotReactionsCursor"
local WALK_AWAY = 4 -- studs, flat, from where the character stood when the tablet opened
local PHONE_MAX_H = 500 -- a screen lower than this gets the phone tablet

----------------------------------------------------------------------------------------------------
-- the reactions (the manual's table, its order, Toxic Squall left out; A and B are the two Elements that make it)
----------------------------------------------------------------------------------------------------
local REACTIONS = {
	{ Name = "Melt", A = "Pyro", B = "Cryo",
		Line = "Cryo on a Burning target, or Pyro on a Chilled or Rooted one: bonus burst damage, and the status is used up." },
	{ Name = "Combustion", A = "Pyro", B = "Toxin",
		Line = "A Burning target inside a poison cloud (or the other way round) ignites the cloud: a one-time AoE burst." },
	{ Name = "Wildfire", A = "Pyro", B = "Zephyr",
		Line = "Zephyr on a Burning target: the Burn lasts longer or stacks higher, or a weaker Burn spreads to enemies nearby." },
	{ Name = "Windchill", A = "Cryo", B = "Zephyr",
		Line = "Zephyr on a Chilled target: bonus Chill stacks." },
	{ Name = "Shatter", A = "Cryo", B = "Voltaic",
		Line = "Voltaic on a Rooted target breaks the Root early, in exchange for Voltaic's bonus damage on stationary targets." },
	{ Name = "Overload", A = "Pyro", B = "Voltaic",
		Line = "Voltaic on a Burning target, or Pyro on a Charged one: a bonus burst with knockback / stagger, and the status is used up." },
	{ Name = "Frozen", A = "Cryo", B = "Aqua",
		Line = "Cryo on a Wet target, or Aqua on a Chilled one: Wet and Chill end in a longer, surer Root." },
	{ Name = "Storm Surge", A = "Voltaic", B = "Zephyr",
		Line = "Zephyr on a Charged target: bonus Charged stacks." },
	{ Name = "Dust Storm", A = "Terra", B = "Zephyr",
		Line = "Zephyr on a Cracked target: bonus Cracked stacks." },
	{ Name = "Windswept", A = "Aqua", B = "Zephyr",
		Line = "Zephyr on a Wet target: bonus Wet stacks." },
}

----------------------------------------------------------------------------------------------------
-- the kit (house_kit_reference.luau: Quick Play's palette, helpers and numbers)
----------------------------------------------------------------------------------------------------
local C = {
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
local DOT = "rbxassetid://82944445925061"
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local DOT_ALPHA = 0.84
local POP = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function corner(parent, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function outline(parent, t, colour)
	return make("UIStroke", {
		Color = colour or C.Ink, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function halftone(parent, alpha, colour, pitch, z)
	return make("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = DOT, ImageColor3 = colour or C.Ink,
		ImageTransparency = alpha, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(pitch, pitch),
		Size = UDim2.fromScale(1, 1), ZIndex = z or 1,
	}, parent)
end

--- Quick Play's slab: a centre-anchored holder, one solid ink shadow down-right, a flat face with a heavy ink border.
--- shadow / border / radius default to Quick Play's 8 / 3 / 3. Returns holder, face, stroke.
local function slab(parent, size, pos, colour, z, shadow, border, radius)
	shadow, border, radius = shadow or 8, border or 3, radius or 3
	local holder = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, ZIndex = z or 2,
		Position = UDim2.fromOffset(pos.X.Offset + size.X.Offset / 2, pos.Y.Offset + size.Y.Offset / 2),
	}, parent)
	local shadowFrame = make("Frame", {
		Name = "Shadow", BackgroundColor3 = C.Ink, BorderSizePixel = 0, ZIndex = 1,
		Size = UDim2.new(1, -shadow, 1, -shadow), Position = UDim2.fromOffset(shadow, shadow),
	}, holder)
	corner(shadowFrame, radius)
	local face = make("Frame", {
		Name = "Face", BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = 2,
		Size = UDim2.new(1, -shadow, 1, -shadow),
	}, holder)
	corner(face, radius)
	return holder, face, outline(face, border)
end

local function hitbox(parent)
	return make("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 50,
	}, parent)
end

--- The kit's mono label, bold Roboto Mono capitals.
local function mono(parent, props)
	local t = make("TextLabel", {
		BackgroundTransparency = 1, FontFace = MONO, TextColor3 = C.Ink, TextSize = 14,
		Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props) do t[k] = v end
	return t
end

--- Display lettering: an ink LuckiestGuy face over a solid copy knocked `depth` px down-right (the small cards' way).
--- Every size in this script is a fixed TextSize in its canvas's px. (Not TextScaled: a UITextSizeConstraint counts
--- real pixels, so under the tablet's UIScale it sized the chips unevenly and cut the long lines to one.)
local function display(parent, props, depth, faceColour, extrudeColour)
	local z = props.ZIndex or 6
	for _, spec in ipairs({ { extrudeColour, depth, z }, { faceColour, 0, z + 1 } }) do
		local l = make("TextLabel", {
			BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextXAlignment = Enum.TextXAlignment.Left,
		}, parent)
		for k, v in pairs(props) do l[k] = v end
		l.TextColor3 = spec[1]
		l.ZIndex = spec[3]
		l.Position = props.Position + UDim2.fromOffset(spec[2], spec[2])
	end
end

-- the colour a chip's word takes on an Element's Base: whichever of ink and cream reads better on it
local function lin(c)
	return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(c)
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end
local function wordOn(bg)
	local l = luminance(bg)
	local onInk = (l + 0.05) / (luminance(C.Ink) + 0.05)
	local onCream = (luminance(C.CreamText) + 0.05) / (l + 0.05)
	return onInk >= onCream and C.Ink or C.CreamText
end

--- The game's logo for an Element, or nil while it only borrows Zephyr's (Aqua's placeholder, IconAssets).
local function logoFor(element)
	local ids = Icons.Element or {}
	local id = ids[element]
	if not id or id == "" then return nil end
	if element ~= "Zephyr" and id == ids.Zephyr then return nil end
	return id
end

----------------------------------------------------------------------------------------------------
-- the cards (one builder for the wall and both tablets; S holds the sizes, in that canvas's px)
----------------------------------------------------------------------------------------------------
--- An Element chip: the Element's own colour, a paper well with its logo, its name. The kit's chip: a small radius,
--- an ink border, no shadow.
local function chip(parent, element, x, y, S)
	local def = Config.Elements[element]
	local base = def and def.Base or C.Track
	local face = make("Frame", {
		Name = "Chip_" .. element, BackgroundColor3 = base, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(S.ChipW, S.ChipH), ZIndex = 4,
	}, parent)
	corner(face, S.ChipRadius)
	outline(face, S.ChipBorder)
	local inset = S.ChipInset
	local tx = S.ChipTextX
	local logo = logoFor(element)
	if logo then
		local well = S.ChipH - 2 * inset
		local wellFrame = make("Frame", {
			Name = "Logo", BackgroundColor3 = C.Pill, BorderSizePixel = 0, Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.fromOffset(well, well), ZIndex = 5,
		}, face)
		corner(wellFrame, S.ChipRadius)
		make("ImageLabel", {
			BackgroundTransparency = 1, Image = logo, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.94), ZIndex = 6,
		}, wellFrame)
		tx = inset + well + math.ceil(inset * 1.5)
	end
	make("TextLabel", {
		Name = "Word", BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
		Text = string.upper(def and def.Display or element), TextColor3 = wordOn(base), TextSize = S.ChipText,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(tx, 1),
		Size = UDim2.new(1, -tx - inset, 1, -2), ZIndex = 5,
	}, face)
	return face
end

--- One reaction: the two chips, the name beside them, and the manual's line under them across the card.
local function card(parent, r, x, y, w, h, S)
	local holder, face = slab(parent, UDim2.fromOffset(w, h), UDim2.fromOffset(x, y), C.Card, 3, S.Shadow, S.Border, S.Radius)
	local id = (r.Name:gsub(" ", ""))
	holder.Name = "Card_" .. id
	face.Name = "Reaction_" .. id
	chip(face, r.A, S.Pad, S.Pad, S)
	chip(face, r.B, S.Pad + S.ChipW + S.ChipGap, S.Pad, S)
	local nx = S.Pad + 2 * S.ChipW + S.ChipGap + S.NameGap
	display(face, {
		Name = "Title", Text = string.upper(r.Name), TextSize = S.Name, Position = UDim2.fromOffset(nx, S.Pad - 1),
		Size = UDim2.new(1, -nx - S.Pad, 0, S.ChipH + 2), TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 6,
	}, S.Extrude, C.Ink, C.Card:Lerp(C.Ink, 0.28))
	local ly = S.Pad + S.ChipH + S.LineGap
	make("TextLabel", {
		Name = "Line", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = r.Line, TextSize = S.Line,
		TextColor3 = C.Ink, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(S.Pad + 2, ly),
		Size = UDim2.new(1, -2 * S.Pad - 4, 1, -ly - S.PadB), ZIndex = 5,
	}, face)
	return holder, face
end

--- All ten in a W x H box at (x0, y0): two columns of five, read down the left one first.
local function grid(parent, x0, y0, W, H, S)
	local root = make("Frame", {
		Name = "Chart", BackgroundTransparency = 1, Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(W, H),
		ZIndex = 3,
	}, parent)
	local rows = math.ceil(#REACTIONS / 2)
	local cw = math.floor((W - S.ColGap) / 2)
	local ch = math.floor((H - (rows - 1) * S.RowGap) / rows)
	for i, r in ipairs(REACTIONS) do
		local col, row = math.floor((i - 1) / rows), (i - 1) % rows
		card(root, r, col * (cw + S.ColGap), row * (ch + S.RowGap), cw, ch, S)
	end
	return root
end

--- All ten in one column that scrolls (the phone tablet), each card as tall as its line needs.
local function list(parent, x0, y0, W, H, S)
	local scroller = make("ScrollingFrame", {
		Name = "Chart", BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 3,
		Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(W, H),
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = S.Bar, ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 0, CanvasSize = UDim2.new(), ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, parent)
	local cw = W - S.Bar - S.BarGap
	local descW = cw - S.Shadow - 2 * S.Pad - 4
	local y = 0
	for _, r in ipairs(REACTIONS) do
		local lh = TextService:GetTextSize(r.Line, S.Line, Enum.Font.GothamBold, Vector2.new(descW, 100000)).Y
		local h = S.Pad + S.ChipH + S.LineGap + lh + S.PadB + S.Shadow + 1
		card(scroller, r, 0, y, cw, h, S)
		y += h + S.RowGap
	end
	scroller.CanvasSize = UDim2.fromOffset(0, y - S.RowGap)
	return scroller
end

----------------------------------------------------------------------------------------------------
-- the wall screen (its size and its text sizes are as in v2; the freed row makes each card taller)
----------------------------------------------------------------------------------------------------
-- The face is 10.44 x 7.56 studs: 100 px a stud. The display's own REACTIONS header plate covers the top 37 px of
-- the middle three quarters, so the chart starts under it.
local WALL_W, WALL_H = 1044, 756
local WALL = {
	Shadow = 6, Border = 3, Radius = 3, Pad = 8, PadB = 5, ChipW = 112, ChipH = 30, ChipGap = 8, ChipText = 14,
	ChipBorder = 2, ChipInset = 4, ChipTextX = 9, ChipRadius = 2, NameGap = 12, Name = 28, Extrude = 2,
	LineGap = 5, Line = 18, ColGap = 14, RowGap = 8, Note = 16,
}
local WALL_FOOT = 24 -- the "click or tap" line under the chart

local oldWall = playerGui:FindFirstChild("ReactionsBoardWall")
if oldWall then oldWall:Destroy() end
local oldView = playerGui:FindFirstChild("ReactionsBoardView")
if oldView then oldView:Destroy() end

local wallGui = make("SurfaceGui", {
	Name = "ReactionsBoardWall", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
	CanvasSize = Vector2.new(WALL_W, WALL_H), LightInfluence = 0, Brightness = 1,
	ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = true,
}, playerGui)
pcall(function() wallGui.MaxDistance = 150 end)
-- it shows, it takes no input: the click is picked by this script (see the header)
pcall(function() wallGui.Active = false end)
local wallPaper = make("Frame", {
	Name = "Paper", BackgroundColor3 = C.Paper, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1,
}, wallGui)
halftone(wallPaper, DOT_ALPHA, C.Ink, 12, 1)
do
	local chartH = WALL_H - 50 - 10 - WALL_FOOT
	grid(wallPaper, 14, 50, WALL_W - 28, chartH, WALL)
	mono(wallPaper, {
		Name = "Hint", Text = "CLICK OR TAP TO ENLARGE", TextSize = WALL.Note, TextColor3 = C.LockedInk,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(14, 50 + chartH + 3),
		Size = UDim2.fromOffset(WALL_W - 28, WALL.Note + 4), ZIndex = 4,
	})
end

----------------------------------------------------------------------------------------------------
-- the tablet's frame: the REACTIONS display's own frame at any size
----------------------------------------------------------------------------------------------------
-- The Blender library that built the board (obs_show19.reactions(): cut(-6.4, 0, 6.4, 9.6, 1.0), housing(out, 0.6,
-- 0.16, 0.26), header("REACTIONS", 1.0, 0, 9.1, white), tab(-6.4, 2.2, 0.9, 0.36)) in units u:
--   * the housing is a box with all four corners cut 1.0u; its white line runs from 0.16u to 0.42u in; the screen
--     face is 0.6u in. These are drawn below from u at any width and height.
--   * the header plate, its key line, border and lettering, and the gold tab are the library's shapes as bands
--     (v25_reactions/scripts/gen_frame.py), kept at 90 px a unit on the v2 tablet's 1152 x 864 housing and scaled
--     here: the plate about the housing's top middle, the tab about its bottom-left corner.
-- Each band is {y0, y1, left edge's x at y0, at y1, right edge's x at y0, at y1}, y down from the housing's top-left.
local FRAME = {
	{ "Tab", "Gold", {
		{649.8,659.5,-25.1,-36.5,46.2,44.5}, {659.5,672.5,-36.5,-38.8,44.5,42.2}, {672.5,682.2,-38.8,-40.5,42.2,30.8},
	} },
	{ "Plate", "Housing", {
		{-90.6,-61.8,249.7,215.8,963,958}, {-61.8,61.8,215.8,194,958,936.2}, {61.8,90.6,194,189,936.2,902.3},
	} },
	{ "Key", "Lit", {
		{-65.4,-62.2,248.9,248.3,322.8,325.5}, {-65.4,-62.2,326,325.5,423,422.7}, {-65.4,-49.1,440.9,421.6,470.6,484.1}, {-65.4,-62.2,511.6,507.8,694.8,694.2}, {-65.4,-62.2,698,694.2,740.6,743.3}, {-65.4,-62.2,743.9,743.3,849.1,848.5}, {-65.4,-62.2,852.3,848.5,926.2,925.6}, {-62.2,-49.1,248.3,246,422.7,421.6},
		{-62.2,-45,507.8,487.5,925.6,922.6}, {-49.1,-45,246,245.3,484.1,487.5}, {-45,34.2,245.3,231.3,922.6,908.6}, {34.2,62.2,231.3,226.4,908.6,875.7}, {62.2,65.4,226.4,225.8,485.8,485.3}, {62.2,65.4,485.8,488.5,672.3,671.7}, {62.2,65.4,672.3,674.9,721.4,717.6}, {62.2,65.4,721.4,720.8,875.7,871.9},
	} },
	{ "Border", "Housing", {
		{-54.6,-36.1,257.8,254.5,316.4,331.7}, {-54.6,-36.1,334.9,331.7,411.2,409.6}, {-54.6,-29.7,443.4,414.1,464.3,484.8}, {-54.6,-36.1,514.1,492.4,682.1,678.8}, {-54.6,-36.1,700.6,678.8,734.3,749.5}, {-54.6,-36.1,752.8,749.5,836.3,833.1}, {-54.6,-36.1,854.9,833.1,913.5,910.2}, {-36.1,-25.1,254.5,252.6,409.6,408.7},
		{-36.1,-29.7,492.4,484.8,910.2,909.1}, {-29.7,-25.1,414.1,408.7,909.1,908.3}, {-25.1,29.7,252.6,242.9,908.3,898.6}, {29.7,36.1,242.9,241.8,898.6,891.1}, {36.1,46.6,241.8,239.9,479.6,477.8}, {36.1,45.3,479.6,487.2,666.1,664.4}, {36.1,54.6,666.1,681.3,736.8,715}, {36.1,54.6,736.8,733.5,891.1,869.3},
		{45.3,54.6,487.2,494.9,625.9,623.6}, {45.3,54.6,625.9,624.2,664.4,662.8}, {46.6,54.6,239.9,238.5,394.2,390.1}, {46.6,54.6,394.2,392.8,477.8,476.4},
	} },
	{ "Letters", "Lit", {
		{-45,-25.7,265.7,262.3,310.7,326.6}, {-45,-25.7,342.9,339.5,400.7,390.9}, {-45,-24.1,445.7,421.1,458.6,475.8}, {-45,-25.7,516.4,493.7,561.4,551.6}, {-45,-25.7,580.7,570.9,638.6,628.7}, {-45,45,651.4,635.6,670.7,654.9}, {-45,-25.7,702.9,680.2,728.6,744.5}, {-45,-3.2,760.7,753.4,780,794.9},
		{-45,3.2,805.7,797.2,825,816.5}, {-45,-25.7,857.1,834.5,902.1,892.3}, {-25.7,-9.6,262.3,259.5,281.6,278.8}, {-25.7,-17.7,299.3,305.9,326.6,325.2}, {-25.7,-9.6,339.5,336.6,358.7,355.9}, {-25.7,-17.7,493.7,492.3,521.1,511.6}, {-25.7,45,593.4,580.9,612.7,600.2}, {-25.7,-17.7,680.2,678.8,707.5,698},
		{-25.7,-17.7,717.1,723.8,744.5,743}, {-25.7,-17.7,834.5,833,861.8,852.3}, {-24.1,-19.3,421.1,415.5,448.5,442.8}, {-24.1,-19.3,448.5,452.4,475.8,479.8}, {-19.3,-11.2,415.5,414.1,442.8,433.3}, {-19.3,-11.2,452.4,459.1,479.8,478.3}, {-17.7,-9.6,305.9,304.5,325.2,323.8}, {-17.7,17.7,492.3,486.1,511.6,505.4},
		{-17.7,17.7,678.8,672.5,698,691.8}, {-17.7,17.7,723.8,717.5,743,736.8}, {-17.7,-9.6,833,831.6,852.3,859}, {-11.2,0,414.1,412.1,433.3,431.4}, {-11.2,0,459.1,457.1,478.3,476.4}, {-9.6,-4.8,259.5,258.6,323.8,322.9}, {-9.6,9.6,336.6,333.2,383.2,373.4}, {-9.6,9.6,831.6,847.5,876.6,892.5},
		{-4.8,6.4,258.6,256.7,322.9,309.7}, {-3.2,45,753.4,744.9,772.6,764.1}, {-3.2,3.2,772.6,774.9,794.9,797.2}, {0,19.3,412.1,408.7,476.4,473}, {3.2,45,774.9,789.9,816.5,809.1}, {6.4,9.6,256.7,256.1,309.7,310.1}, {9.6,45,256.1,249.9,275.4,269.1}, {9.6,45,289.8,293.2,310.1,314.1},
		{9.6,25.7,333.2,330.4,352.5,349.7}, {9.6,17.7,865.2,871.8,892.5,891.1}, {17.7,25.7,486.1,484.7,505.4,512}, {17.7,25.7,672.5,671.1,691.8,698.4}, {17.7,25.7,717.5,708.1,736.8,735.4}, {17.7,25.7,871.8,862.4,891.1,889.7}, {19.3,45,408.7,404.1,428,423.4}, {19.3,45,453.7,449.1,473,468.4},
		{25.7,45,330.4,327,394.7,384.9}, {25.7,45,484.7,500.6,549,539.1}, {25.7,45,671.1,687,735.4,712.7}, {25.7,45,831.8,822,889.7,867},
	} },
}
local FRAME_COLOUR = { Housing = C.Ink, Lit = C.White, Paper = C.Paper, Gold = C.Gold }
local LIB_PX = 90 -- FRAME's px a unit
local LIB_W, LIB_H = 1152, 864 -- the housing FRAME was cut for
local PLATE_TOP, TAB_LEFT = -90.6, -40.5 -- how far the plate and the tab reach past the housing, in FRAME's px
local CUT_SHORTEN = 2 - math.sqrt(2) -- an inward offset of d shortens a 45-degree corner cut by d times this

-- A slanted edge is half a box, cut along its diagonal by a UIGradient with a hard step at its middle. The gradient's
-- Rotation is applied in the box's own 0..1 square (45 degrees runs corner to corner, whatever the box's shape);
-- GRADIENT_IN_BOX = false would treat it as screen pixels instead.
local GRADIENT_IN_BOX = true
local OVER = 0.6 -- each piece reaches this far over its neighbour, so no hairline opens between them when scaled

--- The half of an x, y, w, h box that holds the corner `solid` ("TL", "TR", "BL", "BR"); the cut is the other diagonal.
local function halfBox(parent, x, y, w, h, solid, colour, z)
	local gw, gh = 1, 1
	if not GRADIENT_IN_BOX then gw, gh = w, h end
	-- the step's normal, pointing away from the solid corner (y runs down; Rotation turns clockwise from +x)
	local nx, ny
	if solid == "TR" then nx, ny = -gh, gw
	elseif solid == "TL" then nx, ny = gh, gw
	elseif solid == "BR" then nx, ny = -gh, -gw
	else nx, ny = gh, -gw end
	-- about one px of soft edge: the box measures 2wh / sqrt(w^2 + h^2) across, along that normal
	local e = math.clamp(0.5 * math.sqrt(w * w + h * h) / math.max(2 * w * h, 1), 0.002, 0.1)
	local f = make("Frame", {
		Name = "Edge", BackgroundColor3 = colour, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h), ZIndex = z,
	}, parent)
	make("UIGradient", {
		Rotation = math.deg(math.atan2(ny, nx)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5 - e, 0),
			NumberSequenceKeypoint.new(0.5 + e, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	}, f)
end

--- One band: a plain middle and, where an edge leans, half a box on that side. T = {k, ox, oy} maps the band's
--- numbers to px (x * k + ox, y * k + oy). Offsets are whole px, so every piece is rounded outward and reaches one px
--- down over the band below: truncating the library's fractions is what opened the hairlines inside the letters.
local function band(parent, b, colour, z, T)
	local k, ox, oy = 1, 0, 0
	if T then k, ox, oy = T[1], T[2], T[3] end
	local y0 = math.floor(b[1] * k + oy)
	local h = math.ceil(b[2] * k + oy) + 1 - y0
	local l0, l1, r0, r1 = b[3] * k + ox, b[4] * k + ox, b[5] * k + ox, b[6] * k + ox
	local inL, inR = math.max(l0, l1), math.min(r0, r1)
	if inR > inL then
		local x0 = math.floor(inL - OVER)
		make("Frame", {
			Name = "Band", BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = z,
			Position = UDim2.fromOffset(x0, y0), Size = UDim2.fromOffset(math.ceil(inR + OVER) - x0, h),
		}, parent)
	end
	if math.abs(l0 - l1) > 0.05 then
		local x0 = math.floor(math.min(l0, l1))
		halfBox(parent, x0, y0, math.ceil(math.max(l0, l1)) - x0, h, l0 < l1 and "TR" or "BR", colour, z)
	end
	if math.abs(r0 - r1) > 0.05 then
		local x0 = math.floor(math.min(r0, r1))
		halfBox(parent, x0, y0, math.ceil(math.max(r0, r1)) - x0, h, r0 < r1 and "BL" or "TL", colour, z)
	end
end

--- A box at x, y, w x h with all four corners cut by c, as three bands.
local function cutBox(parent, x, y, w, h, c, colour, z)
	band(parent, { y, y + c, x + c, x, x + w - c, x + w }, colour, z)
	band(parent, { y + c, y + h - c, x, x, x + w, x + w }, colour, z)
	band(parent, { y + h - c, y + h, x, x + c, x + w, x + w - c }, colour, z)
end

--- FRAME's layers by name into `parent`, each a flat holder over it, in the order given, mapped by T (see band).
local function layers(parent, names, z0, T)
	local byName = {}
	for _, l in ipairs(FRAME) do byName[l[1]] = l end
	for i, name in ipairs(names) do
		local l = byName[name]
		local holder = make("Frame", {
			Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z0 + i - 1,
		}, parent)
		for _, b in ipairs(l[3]) do band(holder, b, FRAME_COLOUR[l[2]], 1, T) end
	end
end

--- The housing (ink body, white line, ink, paper face) for a W x H housing at u px a unit. The face's inset.
local function housingInto(parent, W, H, u)
	local face = math.floor(0.6 * u + 0.5)
	for i, ring in ipairs({ { "Body", 0, C.Ink }, { "Line", 0.16, C.White }, { "LineIn", 0.42, C.Ink }, { "Face", 0.6, C.Paper } }) do
		local d = math.floor(ring[2] * u + 0.5)
		local holder = make("Frame", {
			Name = ring[1], BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = i,
		}, parent)
		cutBox(holder, d, d, W - 2 * d, H - 2 * d, math.floor(u - d * CUT_SHORTEN + 0.5), ring[3], 1)
	end
	return face, math.floor(u - face * CUT_SHORTEN + 0.5)
end

--- The gold tab (scaled by u about the housing's bottom-left) and the header plate with its lettering (scaled by uh
--- about the housing's top middle).
local function headerInto(parent, W, H, u, uh)
	local kt, kp = u / LIB_PX, uh / LIB_PX
	layers(parent, { "Tab" }, 1, { kt, 0, H - LIB_H * kt })
	layers(parent, { "Plate", "Key", "Border", "Letters" }, 2, { kp, W / 2 - LIB_W / 2 * kp, 0 })
end

----------------------------------------------------------------------------------------------------
-- the two tablets' numbers
----------------------------------------------------------------------------------------------------
-- PC: px of a 1920 x 1080 screen (the fit lands at about 1.01 there). v2 drew at 0.92 there with the wall's sizes
-- (name 28, line 18, chip 112 x 30 / 14, X 68 x 56 / 42, frame 90 px a unit), so v3's sizes are those x 1.4 / 0.92
-- or more: name 37, line 24, chip 148 x 40 / 19, X 90 x 74 / 56, frame and plate 116 px a unit. A card is 722 wide so
-- that the longest line (Overload: 657 px at 24 px) wraps in two rows of 692.
local PC = {
	u = 116, uh = 116, CardW = 722, CardH = 116, Side = 14, Gap = 9, Bottom = 12, Dots = 16,
	FillW = 0.92, FillH = 0.93, -- the most of the screen (under Roblox's topbar) the tablet may take
	S = {
		Shadow = 8, Border = 4, Radius = 4, Pad = 9, PadB = 5, ChipW = 148, ChipH = 40, ChipGap = 10, ChipText = 19,
		ChipBorder = 3, ChipInset = 5, ChipTextX = 12, ChipRadius = 3, NameGap = 16, Name = 37, Extrude = 3,
		LineGap = 5, Line = 24, ColGap = 16, RowGap = 8,
	},
	X = { W = 90, H = 74, Shadow = 10, Border = 4, Radius = 4, Text = 56, Stroke = 4, Drop = 4, Lift = 4, Over = 10, Top = -16 },
}
-- Phone: real px, no scaling. One column of cards that scrolls; descriptions 14 px, the X 46 x 46.
local PHONE = {
	u = 24, uh = 30, Side = 8, Gap = 5, Bottom = 9, Dots = 10,
	FillW = 0.82, FillH = 0.88, MaxW = 760,
	S = {
		Shadow = 4, Border = 2, Radius = 3, Pad = 7, PadB = 5, ChipW = 82, ChipH = 26, ChipGap = 6, ChipText = 12,
		ChipBorder = 2, ChipInset = 3, ChipTextX = 8, ChipRadius = 2, NameGap = 10, Name = 20, Extrude = 2,
		LineGap = 4, Line = 14, RowGap = 6, Bar = 6, BarGap = 6,
	},
	X = { W = 46, H = 46, Shadow = 4, Border = 2, Radius = 3, Text = 30, Stroke = 2, Drop = 2, Lift = 2, Over = 4, Top = -8 },
}

----------------------------------------------------------------------------------------------------
-- the tablet: the board off the wall, floating in front of you
----------------------------------------------------------------------------------------------------
local view = make("ScreenGui", {
	Name = "ReactionsBoardView", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 43,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local command = make("BindableEvent", { Name = "Command" }, view)

-- no backdrop: the tablet alone, the world all round it
local tablet = make("Frame", {
	Name = "Tablet", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(100, 100), Visible = false, ZIndex = 1,
}, view)
local fitScale = make("UIScale", {}, tablet)
local lift = make("Frame", {
	Name = "Lift", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 1,
}, tablet)
local popScale = make("UIScale", {}, lift)

local open = false
local openedAt = nil
local setOpen -- below
local boxW, boxH = 100, 100

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--- (Re)build the tablet for "pc" (sized by the fit) or "phone" (sized from the screen: sw wide, h high under the
--- topbar). The old board goes; open or shut stays as it was.
local function buildTablet(mode, sw, h)
	local L = mode == "phone" and PHONE or PC
	local S, u, uh, X = L.S, L.u, L.uh, L.X
	local fi = math.floor(0.6 * u + 0.5)
	local top = math.ceil(-PLATE_TOP * uh / LIB_PX - fi) + L.Gap -- the chart starts under the plate
	local x0 = math.floor(TAB_LEFT * u / LIB_PX)
	local y0 = math.min(math.floor(PLATE_TOP * uh / LIB_PX), X.Top)
	local closeW, closeH = X.W + X.Shadow, X.H + X.Shadow
	local HW, HH
	if mode == "phone" then
		local bw = math.min(math.floor(sw * L.FillW), L.MaxW)
		local bh = math.floor(h * L.FillH)
		HW, HH = bw - X.Over + x0, bh + y0
	else
		HW = 2 * L.CardW + S.ColGap + 2 * L.Side + 2 * fi
		HH = top + 5 * L.CardH + 4 * S.RowGap + L.Bottom + 2 * fi
	end
	boxW, boxH = HW + X.Over - x0, HH - y0
	local faceW, faceH = HW - 2 * fi, HH - 2 * fi

	local old = lift:FindFirstChild("Board")
	if old then old:Destroy() end
	tablet.Size = UDim2.fromOffset(boxW, boxH)
	local board = make("Frame", {
		Name = "Board", BackgroundTransparency = 1, Position = UDim2.fromOffset(-x0, -y0),
		Size = UDim2.fromOffset(HW, HH), ZIndex = 1,
	})
	-- Active, so a click or touch on the tablet stops at the tablet
	make("Frame", {
		Name = "Catch", BackgroundTransparency = 1, Active = true, Size = UDim2.fromScale(1, 1), ZIndex = 1,
	}, board)
	local housing = make("Frame", { Name = "Housing", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, board)
	local _, faceCut = housingInto(housing, HW, HH, u)

	-- the screen: its dots (in three strips that leave the cut corners out) and the reactions
	local screen = make("Frame", {
		Name = "Screen", BackgroundTransparency = 1, Position = UDim2.fromOffset(fi, fi),
		Size = UDim2.fromOffset(faceW, faceH), ZIndex = 3,
	}, board)
	local cutC = math.ceil(faceCut)
	for i, r in ipairs({ { cutC, 0, faceW - 2 * cutC, cutC }, { 0, cutC, faceW, faceH - 2 * cutC },
		{ cutC, faceH - cutC, faceW - 2 * cutC, cutC } }) do
		local clip = make("Frame", {
			Name = "Dots" .. i, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1,
			Position = UDim2.fromOffset(r[1], r[2]), Size = UDim2.fromOffset(r[3], r[4]),
		}, screen)
		local dots = halftone(clip, DOT_ALPHA, C.Ink, L.Dots, 1)
		dots.Size = UDim2.fromOffset(faceW, faceH)
		dots.Position = UDim2.fromOffset(-r[1], -r[2])
	end
	if mode == "phone" then
		list(screen, L.Side, top, faceW - 2 * L.Side, faceH - top - L.Bottom, S)
	else
		grid(screen, L.Side, top, faceW - 2 * L.Side, 5 * L.CardH + 4 * S.RowGap, S)
	end

	-- over the screen's top edge, as on the wall: the gold tab, then the header plate and its lettering
	local header = make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, board)
	headerInto(header, HW, HH, u, uh)

	-- the X on the top-right corner: Quick Play's ink slab and white X, keyed in white like the header plate
	local closeHolder, closeFace, closeStroke = slab(board, UDim2.fromOffset(closeW, closeH),
		UDim2.fromOffset(HW - closeW + X.Over, X.Top), C.Ink, 5, X.Shadow, X.Border, X.Radius)
	closeHolder.Name = "Close"
	closeStroke.Color = C.White
	local glyph = make("TextLabel", {
		Name = "Glyph", BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "X", TextSize = X.Text,
		TextColor3 = C.White, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, X.Drop), ZIndex = 4,
	}, closeFace)
	make("UIStroke", { Color = C.Ink, Thickness = X.Stroke }, glyph)
	local closeHit = hitbox(closeFace)
	-- the X lifts on hover and presses on click, like Quick Play's buttons
	local up = UDim2.fromOffset(-X.Lift, -X.Lift)
	closeHit.MouseEnter:Connect(function() TweenService:Create(closeFace, QUICK, { Position = up }):Play() end)
	closeHit.MouseLeave:Connect(function() TweenService:Create(closeFace, QUICK, { Position = UDim2.new() }):Play() end)
	closeHit.Activated:Connect(function()
		closeFace.Position = UDim2.fromOffset(X.Drop / 2, X.Drop / 2)
		task.delay(0.07, function() TweenService:Create(closeFace, QUICK, { Position = UDim2.new() }):Play() end)
		setOpen(false)
	end)

	board.Parent = lift
	view:SetAttribute("Layout", mode)
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local OTHER_SCREENS = { "SettingsOpen", "LoadoutOpen", "QuickPlayOpen", "ShopOpen" }

setOpen = function(v)
	if v == open then return end
	open = v
	-- the input scripts' way of knowing a screen is up, as QuickPlayOpen / LoadoutOpen
	player:SetAttribute("ReactionsOpen", v or nil)
	if v then
		local root = rootPart()
		openedAt = root and root.Position
		tablet.Visible = true
		popScale.Scale = 0.9
		TweenService:Create(popScale, POP, { Scale = 1 }):Play()
		-- first person re-locks the mouse every frame; win it back while the tablet is up
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		openedAt = nil
		tablet.Visible = false
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
	end
end

-- (no gameProcessed check: Roblox's own menu takes Escape too, so it always arrives processed)
UserInputService.InputBegan:Connect(function(input)
	if open and input.KeyCode == Enum.KeyCode.Escape then setOpen(false) end
end)

-- walking away puts it away: WALK_AWAY studs, flat, from where the character stood when it opened
RunService.Heartbeat:Connect(function()
	if not open then return end
	local root = rootPart()
	if not root then setOpen(false) return end
	if not openedAt then openedAt = root.Position return end
	local d = root.Position - openedAt
	if d.X * d.X + d.Z * d.Z >= WALK_AWAY * WALK_AWAY then setOpen(false) end
end)

-- leaving the Hub (a duel, the training island) takes the tablet down with it, and so does another screen opening
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if player:GetAttribute("Zone") ~= "Hub" then setOpen(false) end
end)
for _, a in ipairs(OTHER_SCREENS) do
	player:GetAttributeChangedSignal(a):Connect(function()
		if player:GetAttribute(a) then setOpen(false) end
	end)
end

command.Event:Connect(function(what)
	if what == "open" then setOpen(true)
	elseif what == "close" then setOpen(false)
	end
end)

----------------------------------------------------------------------------------------------------
-- the screen part (streaming can take it away and bring a new copy back, so it is looked for again)
----------------------------------------------------------------------------------------------------
local bound = nil
local function bind(part)
	bound = part
	wallGui.Adornee = part
	local click = part:FindFirstChild(CLICK) or part:WaitForChild(CLICK, 10)
	if click and click:IsA("ClickDetector") then
		click.MouseClick:Connect(function()
			setOpen(true)
		end)
	end
end

--- Did a click or tap at this screen point land on the screen? Its ray must reach TV_Reactions_Screen (and only it
--- is looked for, so the Visual meshes' hulls do not count), within the ClickDetector's reach of the character, with
--- none of the Hub's Colliders in front of it. The display's own colliders wrap the screen face, so the last 2.5 studs
--- before the face are not checked.
local function pickAt(x, y)
	if open or not (bound and bound.Parent) then return false end
	if player:GetAttribute("Zone") ~= "Hub" then return false end
	for _, a in ipairs(OTHER_SCREENS) do
		if player:GetAttribute(a) then return false end
	end
	local camera = workspace.CurrentCamera
	local root = rootPart()
	if not (camera and root) then return false end
	local click = bound:FindFirstChild(CLICK)
	local reach = (click and click:IsA("ClickDetector")) and click.MaxActivationDistance or 24
	local ray = camera:ScreenPointToRay(x, y)
	local only = RaycastParams.new()
	only.FilterType = Enum.RaycastFilterType.Include
	only.FilterDescendantsInstances = { bound }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * (reach + 40), only)
	if not hit or (hit.Position - root.Position).Magnitude > reach then return false end
	local hub = workspace:FindFirstChild(HUB)
	local colliders = hub and hub:FindFirstChild("Colliders")
	local clear = hit.Distance - 2.5
	if colliders and clear > 0 then
		local walls = RaycastParams.new()
		walls.FilterType = Enum.RaycastFilterType.Include
		walls.FilterDescendantsInstances = { colliders }
		if workspace:Raycast(ray.Origin, ray.Direction * clear, walls) then return false end
	end
	return true
end

-- a click or a tap: pressed and let go within half a second and 12 px (so a drag that turns the camera never opens it)
local presses = {}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local t = input.UserInputType
	if gameProcessed or not (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then return end
	-- (one key for the mouse button, whichever InputObject it arrives on; a touch is its own object start to end)
	presses[t == Enum.UserInputType.MouseButton1 and "M1" or input] = { at = os.clock(), pos = Vector2.new(input.Position.X, input.Position.Y) }
end)
UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	if not (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then return end
	local key = t == Enum.UserInputType.MouseButton1 and "M1" or input
	local p = presses[key]
	presses[key] = nil
	if not p then return end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if os.clock() - p.at > 0.5 or (pos - p.pos).Magnitude > 12 then return end
	if pickAt(pos.X, pos.Y) then setOpen(true) end
end)

task.spawn(function()
	while true do
		if not (bound and bound:IsDescendantOf(workspace)) then
			bound = nil
			wallGui.Adornee = nil
			local hub = workspace:FindFirstChild(HUB)
			local functional = hub and hub:FindFirstChild("Functional")
			local part = functional and functional:FindFirstChild(SCREEN)
			if part then bind(part) end
		end
		task.wait(1)
	end
end)

----------------------------------------------------------------------------------------------------
-- layout. A screen under PHONE_MAX_H high gets the phone tablet, built to its size and centred under Roblox's topbar
-- (the Hub's own buttons share that row). Any other gets the PC tablet, scaled to take at most FillW of the width and
-- FillH of the height under the topbar, and centred on the screen, so the world shows all round it. Sized off the
-- ScreenGui (Camera.ViewportSize can misreport in Studio), and never capped at 1.
----------------------------------------------------------------------------------------------------
local mode, builtFor = nil, nil
local function layout()
	local s = view.AbsoluteSize
	if s.X < 10 or s.Y < 10 then return end
	local topH = 0
	local ok, inset = pcall(function() return GuiService.TopbarInset end)
	if ok and inset then
		topH = inset.Max.Y
	else
		topH = GuiService:GetGuiInset().Y
	end
	local h = s.Y - topH
	if s.Y < PHONE_MAX_H then
		if mode ~= "phone" or builtFor ~= s or view:GetAttribute("BuiltTop") ~= topH then
			mode, builtFor = "phone", s
			view:SetAttribute("BuiltTop", topH)
			buildTablet("phone", s.X, h)
		end
		fitScale.Scale = 1
		tablet.Position = UDim2.fromOffset(s.X / 2, topH + h / 2)
	else
		if mode ~= "pc" then
			mode, builtFor = "pc", s
			buildTablet("pc")
		end
		fitScale.Scale = math.max(0.2, math.min(s.X * PC.FillW / boxW, h * PC.FillH / boxH))
		-- centred on the whole screen (as much world under it as over it), unless that would reach the topbar
		tablet.Position = UDim2.fromOffset(s.X / 2, math.max(s.Y / 2, topH + boxH * fitScale.Scale / 2 + 6))
	end
	view:SetAttribute("FitScale", fitScale.Scale)
end
view:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout) end)
layout()
