--[[
	ProfileCard  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/ProfileCard

	THE PLAYER PROFILE CARD (2026-10-27, the owner's "Player Profile Popup Card" prompt): a small popup card, dismissed
	with its X, NOT a profile page. A full page was deferred to an unscoped backlog; don't grow this card into one.

	THE TEMPLATE (2026-10-28, the owner's calls on the greybox), drawn in the house kit's shapes:
	  BANNER        the showcase: a panel the card's full width across its top half, nothing laid over it. No Mastery
	                banner exists yet, so every player gets the DEFAULT BANNER, a photo of the Hub's crystal (the owner's
	                pick of three, 2026-10-28). Under it lies a stand-in in the featured Element's own colours (slashes,
	                a dot screen), which shows while the photo loads or if it never does.
	  NAME ROW      straddles the banner's foot: the level SEAL (a 12-point star), the player's username (their real
	                Roblox name, not the display name: the owner's call) on the tilted gold plate Quick Play's title
	                uses, their title on the ink tag under it when they have one, and the Ranked DIAMOND with its tier.
	  WIN RATE      the card's biggest number, red, lettered like Quick Play's DUEL; total wins on a tag under it.
	  MOST PLAYED   a fanned hand of three cards in each Element's colours, the most played in the middle and raised
	                (2-1-3), each with its Mastery rank on a tab hung under it. The hand keeps the same gap to the
	                card's bottom edge as the wins tag (the owner).
	  X             on the card's top-right corner, centred on the vertex (the owner; the prompt had it bottom centre).
	                A tap on the dimmed screen round the card closes it too.
	COLOUR (2026-10-28, the owner's go after the greybox): the flat pop-art baseline in Quick Play's palette -- paper,
	ink, Red, Cyan, Gold -- plus each Element's own Base / Light / Dark. No gradient, glow or soft shadow anywhere. A
	piece with nothing behind it yet takes the locked cards' Track and LockedInk, as Quick Play's RANKED card does.
	Left out on purpose: cosmetics / wraps / skins (the full page's), a win streak (SPELLSHOT has none), a platform icon.

	IT OPENS FROM THE PLAYER THEMSELF (2026-10-28, the owner: "when you hover over a player profile option comes on their
	head"). In the Hub, look at another player and a PROFILE tag pops up over their head; the Interact key opens their
	card (the section "the hover tag" below has the rules).
	IT ALSO OPENS FROM A PLAYER'S BANNER. A GuiButton tagged "ProfileBanner" (CollectionService) with a number attribute
	"UserId" opens the card for that player when it is activated: tag a player's Mastery banner wherever one is drawn
	(lobby, post-match) and it opens this card. NO BANNER EXISTS YET: nothing builds Mastery, and the manual's per-Element
	name cards / profile banners (s7 item 5) are unbuilt, so nothing carries the tag today. Scripts can also use the
	gui's Command: Command:Fire("open", player) and Command:Fire("close").

	WHERE THE NUMBERS COME FROM: attributes on the TARGET player (set by the server, so every client sees them). Only the
	name, the equipped Element and PlayerData's DataLoaded / DataError exist today. Every other name in Source is this
	card's PROPOSAL for a system that is not built or not published; until something sets it, that piece shows a dash
	(the owner, 2026-10-28: no placeholder data anywhere on the card).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local K = require(spell:WaitForChild("HubLifeKit"))
local make = K.make

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TAG = "ProfileBanner"
local CURSOR_STEP = "ProfileCardCursor"

-- The attribute each piece reads off the target player. BUILT: something sets it today. Everything else is a proposal.
local Source = {
	Element = "Element",            -- BUILT (SpellshotConfig): the equipped Element, the stand-in for "featured"
	Featured = "FeaturedElement",   -- the player's featured / main Element: no such setting exists
	Level = "AccountLevel",         -- manual s5 Account Level (Casual XP from any match, caps around 30): not built
	Rank = "RankedTier",            -- manual s5 Ranked Ladder tier, e.g. "STORM II": Ranked is a locked card
	Title = "Title",                -- the player's title (manual s5: a ranked season reward): no titles exist
	Wins = "DuelWins",              -- PlayerData's Stats.Wins, kept private (HubBoards' TOP DUELISTS reads this name too)
	Losses = "DuelLosses",          -- PlayerData's Stats.Losses, kept private
	Draws = "DuelDraws",            -- PlayerData's Stats.Draws, kept private
	MostPlayed = "MostPlayed",      -- the top 3 Elements by playtime, "Pyro,Cryo,Terra": nothing tracks playtime
	Mastery = "Mastery_",           -- Mastery_<Element> = that Element's Mastery rank: not built
	Loaded = "DataLoaded",          -- BUILT (PlayerData): true once the save is in
	Error = "DataError",            -- BUILT (PlayerData): the save failed to load, or another server took it
}

-- THE HOUSE PALETTE (Quick Play's, through HubLifeKit): paper, ink and the HUD's three accents. The banner and the hand
-- of cards take each Element's own colours instead (tones below).
local C = {
	Ink = K.C.Ink,
	Paper = K.C.Paper,
	Pill = K.C.Pill,
	Cream = K.C.CreamText,
	Track = K.C.Track,
	Grey = K.C.Grey,
	LockedInk = K.C.LockedInk,
	Gold = K.C.Gold,
	Red = Color3.fromRGB(228, 37, 31),     -- Quick Play's Red and Cyan (HubLifeKit carries no copy)
	Cyan = Color3.fromRGB(18, 198, 231),
}

-- the default banner for every player until Mastery banners exist: the Hub's crystal, 1024 x 326 (the banner's 3.14:1),
-- shot sharp with the LOADOUT sign's lettering hidden for the photo (the owner, 2026-10-28; 82801926346890 was the blurred
-- first take)
local DEFAULT_BANNER = "rbxassetid://86358047341982"

-- EVERY NUMBER HERE IS A PROPOSAL (design px; fit() scales the canvas to the screen)
local SHADOW = 10                          -- the card's own ink shadow (Quick Play's slabs: 8)
local FACE_W, FACE_H = 690, 430
local X_FACE = 60                          -- the X slab's face, centred on the card's top-right corner
local W = FACE_W + X_FACE / 2 + 6          -- the canvas: the card, and the half of the X that hangs off its corner
local CANVAS_H = X_FACE / 2 + FACE_H + SHADOW
local BANNER_H = 210                       -- the banner's face; it runs the card's width less 12 px a side
local MAX_SCALE = 1.45                     -- a 1080p screen: two thirds of its height, a card and not a page
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

----------------------------------------------------------------------------------------------------
-- the kit's pieces
----------------------------------------------------------------------------------------------------
local function text(parent, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1, Text = "", TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, parent)
	for k, v in pairs(props) do l[k] = v end
	return l
end
local function sizeLimit(label, max, min)
	make("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min }, label)
end
local function round(f)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
end

--- A dot-screen patch, the kit's halftone sized and placed (no size: the whole parent).
local function dots(parent, alpha, colour, pitch, size, pos, z)
	return make("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = K.DOT, ImageColor3 = colour, ImageTransparency = alpha,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(pitch, pitch),
		Size = size or UDim2.fromScale(1, 1), Position = pos or UDim2.new(), ZIndex = z or 1,
	}, parent)
end

--- Display lettering the kit's way (Quick Play's DUEL): LuckiestGuy in `face` over a solid ink copy knocked `depth`
--- down-right, both stroked in ink, scaled to the box up to `max`. Returns the pair; setPair writes both.
local function display(parent, props, depth, max, min, face)
	local pair = {}
	for i, spec in ipairs({ { face, 0, 1 }, { C.Ink, depth, 0 } }) do
		local l = text(parent, props)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = spec[1]
		l.ZIndex = (props.ZIndex or 6) + spec[3]
		l.Position = props.Position + UDim2.fromOffset(spec[2], spec[2])
		make("UIStroke", { Color = C.Ink, Thickness = 3 }, l)
		sizeLimit(l, max, min)
		pair[i] = l
	end
	return pair
end
local function setPair(pair, s)
	pair[1].Text = s
	pair[2].Text = s
end

--- The kit's ink chip: an ink tag with cream mono capitals, as wide as its words. Returns chip, label.
local function inkChip(parent, pos, h, textSize, z, anchor)
	local f = make("Frame", {
		Name = "Chip", BackgroundColor3 = C.Ink, BorderSizePixel = 0, Position = pos, AnchorPoint = anchor or Vector2.zero,
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z,
	}, parent)
	K.corner(f, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, f)
	local l = text(f, {
		FontFace = K.MONO, TextSize = textSize, TextColor3 = C.Cream, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, ZIndex = z + 1,
	})
	return f, l
end

--- A 12-point seal: three squares a turn of 30 degrees apart, a coloured star on a larger ink one. Returns the seal
--- and its three coloured squares, for fill() to paint.
local function seal(parent, center, size, rotation, z)
	local root = make("Frame", {
		Name = "Seal", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = center,
		Size = UDim2.fromOffset(size, size), Rotation = rotation, ZIndex = z,
	}, parent)
	local faces = {}
	for _, spec in ipairs({ { C.Ink, size + 12, 1 }, { C.Red, size, 2 } }) do
		for k = 0, 2 do
			local square = make("Frame", {
				BackgroundColor3 = spec[1], BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(spec[2] * 0.72, spec[2] * 0.72),
				Rotation = k * 30, ZIndex = spec[3],
			}, root)
			if spec[3] == 2 then faces[#faces + 1] = square end
		end
	end
	return root, faces
end

--- The kit's diamond badge (Quick Play's LOCKED): three squares turned 45 degrees, ink, a cream rim, the field.
--- Returns the badge and its field, for fill() to paint.
local function diamond(parent, center, size, z)
	local root = make("Frame", {
		Name = "Diamond", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = center,
		Size = UDim2.fromOffset(size, size), ZIndex = z,
	}, parent)
	local field
	for _, spec in ipairs({ { C.Ink, size + 12, 1 }, { C.Pill, size + 4, 2 }, { C.LockedInk, size - 2, 3 } }) do
		field = make("Frame", {
			BackgroundColor3 = spec[1], BorderSizePixel = 0, Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(spec[2] * 0.7071, spec[2] * 0.7071), ZIndex = spec[3],
		}, root)
		K.corner(field, 2)
	end
	return root, field
end

----------------------------------------------------------------------------------------------------
-- the card
----------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("ProfileCard")
if old then old:Destroy() end

local gui = make("ScreenGui", {
	Name = "ProfileCard", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false,
	DisplayOrder = 55, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local command = make("BindableEvent", { Name = "Command" }, gui)

-- the dimmed screen round the card (the kit's scrim: ink, white dots); a tap on it closes the card
local backdrop = make("TextButton", {
	Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35,
	BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1,
}, gui)
dots(backdrop, 0.94, Color3.new(1, 1, 1), 12)

local canvas = make("Frame", {
	Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(W, CANVAS_H), ZIndex = 2,
}, gui)
local fitScale = make("UIScale", {}, canvas)
-- the entrance pops this one; fit() owns the canvas's
local pop = make("Frame", {
	Name = "Pop", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1), ZIndex = 2,
}, canvas)
local popScale = make("UIScale", {}, pop)

local cardHolder, card = K.slab(pop, UDim2.fromOffset(FACE_W + SHADOW, FACE_H + SHADOW), UDim2.fromOffset(0, X_FACE / 2), C.Paper, 2, SHADOW, 4, 4)
cardHolder.Name = "Card"
card.Active = true               -- a tap on the card is not a tap on the backdrop
-- the paper under the stats takes the dot; the banner covers the rest
dots(card, 0.86, C.Ink, 9, UDim2.new(1, 0, 0, FACE_H - 228), UDim2.fromOffset(0, 228), 2)

-- (4) THE MASTERY BANNER, the showcase: the card's full width, nothing laid over it
local bannerHolder, banner = K.slab(card, UDim2.fromOffset(FACE_W - 24 + 6, BANNER_H + 6), UDim2.fromOffset(12, 12), C.Track, 3, 6, 4, 3)
bannerHolder.Name = "Banner"
-- the stand-in, in the Element's colours (fill() paints it), under the photo: what shows while the photo loads. A
-- CanvasGroup clips the slashes, because a rotated frame escapes every other clip.
local art = make("CanvasGroup", { Name = "Art", BackgroundColor3 = C.Track, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, banner)
K.corner(art, 3)
local slash = {}
for _, b in ipairs({ { "Wide", 190, 120, C.Paper }, { "Rule", 16, 2, C.Ink }, { "Hair", 10, 250, C.Cream }, { "Deep", 70, -330, C.LockedInk } }) do
	slash[b[1]] = make("Frame", {
		Name = b[1], BackgroundColor3 = b[4], BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, b[3], 0.5, 0), Size = UDim2.fromOffset(b[2], 700), Rotation = 24, ZIndex = 2,
	}, art)
end
dots(art, 0.8, C.Ink, 11, UDim2.new(0.36, 0, 1, 0), UDim2.new(), 3)
-- the default banner over it: a photo of the Hub's crystal and its hall, taken in the game's own Hub light
local photo = make("ImageLabel", {
	Name = "Photo", BackgroundTransparency = 1, Image = DEFAULT_BANNER, ScaleType = Enum.ScaleType.Crop,
	Size = UDim2.fromScale(1, 1), ZIndex = 2,
}, banner)
K.corner(photo, 3)

-- (1) THE NAME on the gold title plate, tilted, half on the banner's foot: the player's username, their real Roblox
-- name (the owner), with their title on the ink tag under it when they have one
local plateHolder, plate = K.slab(card, UDim2.fromOffset(386, 66), UDim2.fromOffset(98, 192), C.Gold, 12, 6, 3, 3)
plateHolder.Name = "NamePlate"
plateHolder.Rotation = -2
dots(plate, 0.9, C.Ink, 7)
local nameWord = text(plate, {
	Name = "Username", Font = Enum.Font.LuckiestGuy, TextScaled = true,
	Position = UDim2.fromOffset(40, 8), Size = UDim2.new(1, -52, 1, -12), ZIndex = 4,
})
sizeLimit(nameWord, 42, 16)
local titleChip, titleWord = inkChip(card, UDim2.fromOffset(150, 248), 32, 17, 14)
titleChip.Name = "Title"
titleChip.Rotation = -2
titleWord.FontFace = Font.fromEnum(Enum.Font.GothamBlack)

-- (2) ACCOUNT LEVEL on a red seal over the plate's left end
local levelSeal, levelFaces = seal(card, UDim2.fromOffset(62, 218), 98, -10, 16)
levelSeal.Name = "Level"
local levelCaption = text(levelSeal, {
	FontFace = K.MONO, Text = "LEVEL", TextSize = 12, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.new(0, 0, 0.5, -30), Size = UDim2.new(1, 0, 0, 14), ZIndex = 4,
})
local levelWord = text(levelSeal, {
	Name = "Value", Font = Enum.Font.LuckiestGuy, TextSize = 38, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.new(0, 0, 0.5, -14), Size = UDim2.new(1, 0, 0, 40), ZIndex = 4,
})
make("UIStroke", { Color = C.Ink, Thickness = 2 }, levelWord)

-- (3) RANKED TIER on a cyan diamond over the banner's right foot (the owner's addition; it is not on the reference card)
local rankBadge, rankField = diamond(card, UDim2.fromOffset(626, 216), 64, 16)
rankBadge.Name = "Rank"
local rankCaption = text(rankBadge, {
	FontFace = K.MONO, Text = "RANK", TextSize = 12, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 14), ZIndex = 5,
})
make("UIStroke", { Color = C.Ink, Thickness = 1.5 }, rankCaption)
local tierChip, tierWord = inkChip(card, UDim2.fromOffset(626, 254), 26, 14, 18, Vector2.new(0.5, 0))
tierChip.Name = "Tier"

-- (5) WIN RATE, the card's biggest number, and (6) TOTAL WINS on a tag stuck under it
local rateChip, rateChipWord = inkChip(card, UDim2.fromOffset(24, 280), 26, 14, 8)
rateChipWord.Text = "WIN RATE"
rateChip.Rotation = -2
local rateWord = display(card, { Name = "WinRate", Position = UDim2.fromOffset(16, 308), Size = UDim2.fromOffset(330, 98), ZIndex = 8 }, 6, 112, 40, C.Red)
local winsTag, winsWord = inkChip(card, UDim2.fromOffset(24, 390), 34, 20, 12)
winsTag.Name = "Wins"
winsTag.Rotation = -3
winsWord.FontFace = Font.fromEnum(Enum.Font.GothamBlack)

-- (7) MOST PLAYED: a fanned hand of three, the most played in the middle and raised, its Mastery rank on a tab under
-- it. The side tabs' lowest corners sit as far off the card's bottom edge as the wins tag's does.
local mpChip, mpChipWord = inkChip(card, UDim2.fromOffset(368, 269), 26, 14, 8)
mpChipWord.Text = "MOST PLAYED"
mpChip.Rotation = 2
local FAN = {
	{ X = 496, Y = 351, W = 88, H = 108, R = 0, Z = 14 },    -- 1st: the middle
	{ X = 410, Y = 359, W = 74, H = 92, R = -10, Z = 12 },   -- 2nd: left
	{ X = 582, Y = 359, W = 74, H = 92, R = 10, Z = 12 },    -- 3rd: right
}
local fan = {}
for i, spec in ipairs(FAN) do
	local holder, face = K.slab(card, UDim2.fromOffset(spec.W + 5, spec.H + 5),
		UDim2.fromOffset(spec.X - spec.W / 2, spec.Y - spec.H / 2), C.Track, spec.Z, 5, 3, 3)
	holder.Name = "Played" .. i
	holder.Rotation = spec.R
	-- the logo in a cream well, as the Element chips carry theirs
	local well = make("Frame", {
		Name = "Well", BackgroundColor3 = C.Pill, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0), Size = UDim2.fromOffset(spec.W * 0.7, spec.W * 0.7), ZIndex = 4,
	}, face)
	round(well)
	K.outline(well, 2)
	local logo = make("ImageLabel", {
		Name = "Logo", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), ZIndex = 5,
	}, well)
	local mark = text(well, {
		Name = "Mark", Font = Enum.Font.LuckiestGuy, TextSize = math.floor(spec.W * 0.42), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 3), Size = UDim2.fromScale(1, 1), ZIndex = 5,
	})
	local word = text(face, {
		Name = "Element", Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 4, 1, -22), Size = UDim2.new(1, -8, 0, 15), ZIndex = 4,
	})
	sizeLimit(word, 13, 8)
	local tab = make("Frame", {
		Name = "Mastery", BackgroundColor3 = C.Ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(spec.W / 2, spec.H - 4), Size = UDim2.fromOffset(46, 22), ZIndex = spec.Z + 3,
	}, holder)
	K.corner(tab, 2)
	local rank = text(tab, {
		Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), ZIndex = spec.Z + 4,
	})
	fan[i] = { Face = face, Logo = logo, Mark = mark, Word = word, Rank = rank }
end

-- (8) THE X on the card's top-right corner, centred on the vertex: a red slab, the cream X stroked in ink, up on hover
local xHolder, xFace = K.slab(pop, UDim2.fromOffset(X_FACE + 6, X_FACE + 6), UDim2.fromOffset(FACE_W - X_FACE / 2, 0), C.Red, 30, 6, 3, 3)
xHolder.Name = "Close"
dots(xFace, 0.9, C.Ink, 6)
local xGlyph = text(xFace, {
	Font = Enum.Font.LuckiestGuy, Text = "X", TextSize = 40, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 3), Size = UDim2.fromScale(1, 1), ZIndex = 4,
})
make("UIStroke", { Color = C.Ink, Thickness = 3 }, xGlyph)
local xHit = make("TextButton", {
	Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10,
}, xFace)
xHit.MouseEnter:Connect(function() TweenService:Create(xFace, QUICK, { Position = UDim2.fromOffset(-3, -3) }):Play() end)
xHit.MouseLeave:Connect(function() TweenService:Create(xFace, QUICK, { Position = UDim2.new() }):Play() end)

----------------------------------------------------------------------------------------------------
-- fit. Three ways, the biggest wins: under the topbar strip; the full height, centred clear of Roblox's buttons on
-- both sides; the full height in the space right of them (a phone in landscape: about 10% bigger, off centre by half
-- the buttons' width). The last must beat the centred one by 2%.
----------------------------------------------------------------------------------------------------
local function fit()
	local s = gui.AbsoluteSize
	if s.X < 10 or s.Y < 10 then return end
	local topH, leftW = 0, 0
	local ok, inset = pcall(function() return GuiService.TopbarInset end)
	if ok and inset then
		topH, leftW = inset.Max.Y, inset.Min.X
	else
		topH = GuiService:GetGuiInset().Y
	end
	local tall = s.Y * 0.94 / CANVAS_H
	local best = { math.min(s.X * 0.94 / W, (s.Y - topH) * 0.94 / CANVAS_H), s.X / 2, topH + (s.Y - topH) / 2 }
	for _, f in ipairs({
		{ math.min((s.X - 2 * (leftW + 8)) / W, tall), s.X / 2, s.Y / 2 },
		{ math.min((s.X - leftW - 16) / W, tall) * 0.98, (leftW + s.X) / 2, s.Y / 2 },
	}) do
		if f[1] > best[1] then best = f end
	end
	fitScale.Scale = math.clamp(best[1], 0.3, MAX_SCALE)
	canvas.Position = UDim2.fromOffset(best[2], best[3])
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit) end)
fit()

----------------------------------------------------------------------------------------------------
-- filling it in
----------------------------------------------------------------------------------------------------
local target = nil
local watch = {}

local function get(name)
	return target and target:GetAttribute(name)
end
local function elementName(el)
	local def = (type(el) == "string") and K.element(el)
	return def and string.upper(def.Display or el) or nil
end
local function count(name)
	local v = get(name)
	return (type(v) == "number") and math.max(0, math.floor(v)) or nil
end

--- An Element's own colours (SpellshotConfig): base, light, dark. No Element: the locked cards' greys.
local function tones(el)
	local def = (type(el) == "string") and K.element(el)
	if not def then return C.Track, C.Paper, C.LockedInk end
	return def.Base or C.Track, def.Light or C.Paper, def.Dark or C.Ink
end

--- An Element's logo, or its initial where it has no logo of its own; `empty` where there is no Element.
local function emblem(logoLabel, markLabel, el, empty)
	local logo = el and K.logoFor(el)
	logoLabel.Image = logo or ""
	logoLabel.Visible = logo ~= nil
	markLabel.Visible = logo == nil
	markLabel.Text = el and string.sub(elementName(el), 1, 1) or empty
	local _, _, dark = tones(el)
	markLabel.TextColor3 = el and dark or C.LockedInk
end

local function fill()
	if not target then return end
	nameWord.Text = string.upper(target.Name)
	local title = get(Source.Title)
	titleWord.Text = (type(title) == "string") and string.upper(title) or ""
	titleChip.Visible = titleWord.Text ~= ""

	-- (4) the stand-in under the default banner, in the featured Element's colours (the equipped one while no featured
	-- setting exists)
	local featured = get(Source.Featured)
	local el = (elementName(featured) and featured) or (elementName(get(Source.Element)) and get(Source.Element)) or nil
	local base, light, dark = tones(el)
	banner.BackgroundColor3 = base
	art.BackgroundColor3 = base
	slash.Wide.BackgroundColor3 = light
	slash.Deep.BackgroundColor3 = dark

	-- (2) and (3): red and cyan once there is something to show, the locked greys until then
	local level = count(Source.Level)
	levelWord.Text = level and tostring(level) or "--"
	for _, square in ipairs(levelFaces) do square.BackgroundColor3 = level and C.Red or C.Track end
	levelWord.TextColor3 = level and C.Cream or C.LockedInk
	levelCaption.TextColor3 = level and C.Cream or C.LockedInk
	local tier = get(Source.Rank)
	local ranked = type(tier) == "string" and tier ~= ""
	tierWord.Text = ranked and string.upper(tier) or "--"
	rankField.BackgroundColor3 = ranked and C.Cyan or C.LockedInk

	-- (5) + (6); a draw counts as a match played
	local w, l, d = count(Source.Wins), count(Source.Losses), count(Source.Draws)
	local played = (w and l) and (w + l + (d or 0)) or nil
	local shown = played and played > 0
	setPair(rateWord, shown and (math.floor(w / played * 100 + 0.5) .. "%") or "--%")
	rateWord[1].TextColor3 = shown and C.Red or C.Track
	winsWord.Text = w and ((w == 1) and "1 WIN" or (w .. " WINS")) or "-- WINS"

	-- (7) three cards, always: the most played in the middle, each in its Element's colour
	local list = {}
	local mp = get(Source.MostPlayed)
	if type(mp) == "string" then
		for name in mp:gmatch("[^,%s]+") do
			if #list < 3 and elementName(name) then list[#list + 1] = name end
		end
	end
	for i, c in ipairs(fan) do
		local e = list[i]
		local cardTone = e and tones(e) or C.Track
		emblem(c.Logo, c.Mark, e, "--")
		c.Face.BackgroundColor3 = cardTone
		c.Word.Text = e and elementName(e) or "--"
		c.Word.TextColor3 = e and K.wordOn(cardTone) or C.LockedInk
		local m = e and count(Source.Mastery .. e)
		c.Rank.Text = m and tostring(m) or "--"
	end
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local function close()
	for _, c in ipairs(watch) do c:Disconnect() end
	table.clear(watch)
	target = nil
	gui.Enabled = false
	xFace.Position = UDim2.new()   -- a hover lift whose MouseLeave never came
	pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
end

local function open(p)
	if typeof(p) ~= "Instance" or not p:IsA("Player") or p.Parent ~= Players then return end
	close()
	target = p
	-- a save that loads, or a stat that changes, while the card is up fills it in
	watch[#watch + 1] = p.AttributeChanged:Connect(fill)
	fill()
	gui.Enabled = true
	fit()
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 0.35 }):Play()
	popScale.Scale = 0.9
	TweenService:Create(popScale, POP, { Scale = 1 }):Play()
	-- first person re-locks the mouse every frame; win it back while the card is up (MapVote's step)
	RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)
end

xHit.Activated:Connect(close)
backdrop.Activated:Connect(close)
Players.PlayerRemoving:Connect(function(p)
	if p == target then close() end
end)
command.Event:Connect(function(what, a)
	if what == "open" then open(a) elseif what == "close" then close() end
end)

----------------------------------------------------------------------------------------------------
-- the hover tag. In the Hub only. Look at another player (the crosshair, in first person) and a PROFILE tag pops up
-- over their head; the Interact key (the Hub prompts' own bind, G by default, B on a pad) opens their card. On a
-- touch screen, tap the player, then tap the tag. The tag never takes the mouse: in first person a clickable thing
-- under the locked cursor freezes the camera (HubClient's prompt note, 2026-10-14), so only touch gets a button. It
-- stays away while a Hub prompt is up, so the one key never does two things. A model with a number attribute
-- "ProfileUserId" counts as that player (a podium figure, a test stand-in).
----------------------------------------------------------------------------------------------------
local Settings = require(spell:WaitForChild("SpellshotSettings"))
local ProximityPromptService = game:GetService("ProximityPromptService")

local HOVER_RANGE = 70          -- studs: nobody further off is hovered
local HOVER_GRACE = 0.3         -- s the tag outlives the crosshair slipping off its player (no flicker at the edges)
local TOUCH_HOLD = 5            -- s a tapped player's tag waits for its own tap

local tag = make("BillboardGui", {
	Name = "ProfileHoverTag", AlwaysOnTop = true, LightInfluence = 0, MaxDistance = HOVER_RANGE + 10, ResetOnSpawn = false,
	Size = UDim2.fromOffset(190, 66), StudsOffset = Vector3.new(0, 2.6, 0), Enabled = false, Active = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local tagRoot = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, tag)
local tagScale = make("UIScale", {}, tagRoot)
-- the comic pointer: an ink diamond behind the slab, its lower half showing, aimed at the head
make("Frame", {
	Name = "Pointer", BackgroundColor3 = C.Ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
	Position = UDim2.fromOffset(92, 45), Size = UDim2.fromOffset(20, 20), ZIndex = 1,
}, tagRoot)
local _, tagFace = K.slab(tagRoot, UDim2.fromOffset(176, 48), UDim2.fromOffset(7, 0), C.Pill, 2, 5, 3, 3)
dots(tagFace, 0.9, C.Ink, 6)
local keyChip, keyWord = inkChip(tagFace, UDim2.fromOffset(8, 7), 29, 16, 6)
local tagWord = text(tagFace, {
	Name = "Word", Font = Enum.Font.Bangers, Text = "PROFILE", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(44, 1), Size = UDim2.new(1, -50, 1, 0), ZIndex = 6,
})
local tagHit = make("TextButton", {
	Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10,
	Interactable = false,
}, tagFace)

local hovered = nil             -- the player the tag stands over
local lostAt = nil              -- when the crosshair slipped off them
local tappedUntil = 0           -- touch: the tag waits until then for its own tap
local shownPrompts = {}         -- Hub prompts on screen now (a strong table: weak Instance keys drop live entries)
ProximityPromptService.PromptShown:Connect(function(pp) shownPrompts[pp] = true end)
ProximityPromptService.PromptHidden:Connect(function(pp) shownPrompts[pp] = nil end)
local function promptUp()
	for pp in pairs(shownPrompts) do
		if pp.Parent then return true end
		shownPrompts[pp] = nil
	end
	return false
end

--- The key to show on the tag: the Interact bind, or the pad's when a pad was the last thing touched.
local function keyName()
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") then
		return ((Settings.KeyCode("Pad_Interact") or Enum.KeyCode.ButtonB).Name:gsub("^Button", ""))
	end
	local code = Settings.KeyCode("Bind_Interact") or Enum.KeyCode.G
	local ok, s = pcall(function() return UserInputService:GetStringForKeyCode(code) end)
	return (ok and s and s ~= "") and string.upper(s) or string.upper(code.Name)
end

--- The player under a screen point, within HOVER_RANGE and not behind a wall: a player's character, or a model
--- carrying ProfileUserId. `viewport`: the point counts the topbar (GetMouseLocation), else it is a GUI point (a tap).
local function playerAt(point, viewport)
	local cam = workspace.CurrentCamera
	local ray = viewport and cam:ViewportPointToRay(point.X, point.Y) or cam:ScreenPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, cam }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * HOVER_RANGE, params)
	local node = hit and hit.Instance
	while node and node ~= workspace do
		if node:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(node)
			if not p then
				local id = node:GetAttribute("ProfileUserId")
				p = (type(id) == "number") and Players:GetPlayerByUserId(id) or nil
			end
			if p then return p, node end
		end
		node = node.Parent
	end
	return nil
end

local function hideTag()
	hovered, lostAt = nil, nil
	tag.Enabled = false
	tag.Adornee = nil
	tagHit.Interactable = false
end

local function showTag(p, model, tappable)
	local head = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not head then return end
	if hovered ~= p or tag.Adornee ~= head then
		tagScale.Scale = 0.6
		TweenService:Create(tagScale, POP, { Scale = 1 }):Play()
	end
	hovered, lostAt = p, nil
	tag.Adornee = head
	keyChip.Visible = not tappable
	keyWord.Text = keyName()
	tagWord.Position = UDim2.fromOffset(tappable and 6 or 44, 1)
	tagWord.Size = UDim2.new(1, tappable and -12 or -50, 1, 0)
	tag.Active = tappable
	tagHit.Interactable = tappable
	tag.Enabled = true
end

local function openHovered()
	local p = hovered
	tappedUntil = 0
	hideTag()
	if p then open(p) end
end

local hoverClock = 0
RunService.Heartbeat:Connect(function(dt)
	hoverClock += dt
	if hoverClock < 0.05 then return end
	hoverClock = 0
	if player:GetAttribute("Zone") ~= "Hub" or gui.Enabled or promptUp() then
		if hovered then hideTag() end
		return
	end
	if os.clock() < tappedUntil then return end            -- a tapped tag waits for its tap
	-- aiming: only while the view is locked (first person), so an open menu's free cursor never hovers the world
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		if hovered then hideTag() end
		return
	end
	local p, model = playerAt(UserInputService:GetMouseLocation(), true)
	if p then
		showTag(p, model, false)
	elseif hovered then
		lostAt = lostAt or os.clock()
		if os.clock() - lostAt > HOVER_GRACE then hideTag() end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not hovered or not tag.Enabled or tag.Active then return end   -- a touch tag opens by its own tap
	if input.KeyCode == (Settings.KeyCode("Bind_Interact") or Enum.KeyCode.G)
		or input.KeyCode == (Settings.KeyCode("Pad_Interact") or Enum.KeyCode.ButtonB) then
		openHovered()
	end
end)
tagHit.Activated:Connect(openHovered)
UserInputService.TouchTap:Connect(function(positions, processed)
	if processed or player:GetAttribute("Zone") ~= "Hub" or gui.Enabled or promptUp() then return end
	local pos = positions[1]
	if not pos then return end
	local p, model = playerAt(pos, false)
	if p then
		tappedUntil = os.clock() + TOUCH_HOLD
		showTag(p, model, true)
	end
end)

----------------------------------------------------------------------------------------------------
-- the click-through: any player's banner
----------------------------------------------------------------------------------------------------
local hooked = {}
local function hook(b)
	if hooked[b] or not b:IsA("GuiButton") then return end
	hooked[b] = b.Activated:Connect(function()
		local id = b:GetAttribute("UserId")
		local p = (type(id) == "number") and Players:GetPlayerByUserId(id) or nil
		if p then open(p) end   -- a player no longer in the server has no attributes to show: nothing opens
	end)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(b)
	if hooked[b] then
		hooked[b]:Disconnect()
		hooked[b] = nil
	end
end)
for _, b in ipairs(CollectionService:GetTagged(TAG)) do hook(b) end
