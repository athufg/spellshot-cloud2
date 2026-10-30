--[[
	QuickPlay  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/QuickPlay

	The mode picker, built to the supplied template: one hero card, one wide card, three small ones,
	a banner, and a queue button. The LAYOUT is the template's. Only the palette moved.

	WHERE IT LIVES, AND WHY THERE
	  PLAY is a third chip in the strip at the top right, where the settings gear and the loadout
	  chip already sit: same skin, same open/close behaviour, same input gate. It is deliberately the
	  WIDEST and the only red one of the three, because it is the primary action and the other two
	  are adjustments to it. In the Hub, the Ledger at the end of the Proving Cloister opens it too
	  (HubClient fires Command "open").

	FULL SCREEN, LIKE THE TEMPLATE
	  The first build floated a 940x548 sheet over a dark scrim and never scaled it past 1, so on a
	  1080p screen it covered about half the screen. The template is the whole screen: paper and dots
	  edge to edge, the cards filling it. The paper now covers the screen and the cards scale to fill
	  it, with no upper cap. Roblox's own buttons in the top-left are respected: the fit takes the
	  larger of "everything below the topbar" and "full height, with side margins that clear them".

	THE TEMPLATE DETAILS THE FIRST BUILD SKIPPED
	  * titles carry a hard ink drop shadow -- the same extrude the game's callouts are built with
	  * the small labels are a bold monospace (Roboto Mono), not Gotham
	  * corners are near-square, borders heavier, shadows solid ink
	  * the X on the Duel emblem is card-coloured with an ink rim, not a black X
	  * UNLOCK TBC sits in a dashed box, and NOW LIVE! is a tilted zigzag sticker rather than a star
	  * the halftone is a patch where the template puts one, not a wash over whole cards

	HOW IT RESPONDS
	  selected   the card stands up off its shadow and its border thickens
	  hover      a smaller lift; locked cards stay flat
	  press      the card pushes down into its shadow
	  open       the paper fades in and the cards pop in one after another
	  locked     the LOCKED badge thumps and the footer says why
	  queued     closing the screen keeps you queued, so the PLAY chip turns into a live QUEUING chip

	THE PALETTE, MAPPED FROM THE TEMPLATE
	  template pink hero   -> Red    (228,37,31)   the HUD's health red
	  template teal        -> Cyan   (18,198,231)  the HUD's mana / right-hand-side cyan
	  template yellow      -> Gold   (245,184,0)   the HUD's Ultimate gold
	  template grey locked -> Track  (222,213,196) newsprint paper, one step down
	  template pink burst  -> Red
	  Those three accents are exactly the three the HUD already uses, so this screen introduces no
	  new colour to the game.

	  MAGENTA IS DELIBERATELY ABSENT even though the template's hero and queue are pink. Magenta is
	  the Sparks currency mark and nothing else; spending it on a button here would cost the mark
	  the one thing that makes it readable as currency.

	WHAT IS REAL AND WHAT IS NOT
	  Selecting a mode writes the QuickPlayMode attribute; locked modes refuse, and say so.
	  QUEUE goes to HubServer (the Spellshot.Hub remote). DUEL fills to two teams of Config.Team.Size
	  (2026-10-18, team mode: a 3v3 on the duel's loop; the chip and the footer show the queue's fill, "3/6") and
	  moves everyone into the arena (same server, no loading). The other modes have no match loop yet,
	  so their cards are locked (2026-10-19, audit P6B-06; the server would say so and drop you from the queue). SOLO TEST sends you to the arena on your own.
	  There is no search spinner: the footer and the chip say what is actually happening.

	For tools: the ScreenGui carries a BindableEvent "Command" -- Fire("open"), Fire("close"),
	Fire("select", modeId), Fire("queue"), Fire("cancel"), and Fire("dequeued", reason) for when the
	server has already dropped you (nothing is sent back to it).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
-- the team match's size and format (2026-10-18, team mode): the DUEL card and the queue's lines read Config.Team
local Config = require(ReplicatedStorage.Spellshot:WaitForChild("SpellshotConfig"))
local TEAM_SIZE = math.max(1, math.floor((Config.Team and Config.Team.Size) or 3))
-- (2026-10-28, matchmaking) "Global": the queue is every server's, so the footer says SEARCHING ALL SERVERS
local GLOBAL_QUEUE = (Config.Matchmaking and Config.Matchmaking.Mode) == "Global"

--- HubServer's remote. The server makes it as it starts, so it is looked up when needed, not waited on.
local function hubRemote()
	return ReplicatedStorage.Spellshot:FindFirstChild("Hub")
end

local DOT = "rbxassetid://82944445925061"     -- BarKit's halftone cell, as the other panels use

local C = {
	Ink = Color3.fromRGB(17, 17, 17),
	Paper = Color3.fromRGB(234, 229, 216),
	Card = Color3.fromRGB(246, 243, 235),
	Pill = Color3.fromRGB(250, 247, 240),
	Red = Color3.fromRGB(228, 37, 31),
	RedInk = Color3.fromRGB(200, 30, 26),
	Cyan = Color3.fromRGB(18, 198, 231),
	Gold = Color3.fromRGB(245, 184, 0),
	CreamText = Color3.fromRGB(250, 244, 232),
	Track = Color3.fromRGB(222, 213, 196),
	LockedInk = Color3.fromRGB(88, 82, 72),
}

-- the template's small labels are a bold monospace
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

-- Design space. Wider than the template's picture (1.93:1 against 1.76:1) so it fills a 16:9 screen
-- without leaving bands, and still fills a wide, short Studio viewport.
local DESIGN_W, DESIGN_H = 1160, 600
local SHADOW, BORDER, RADIUS = 8, 3, 3
local DOT_ALPHA = 0.84
local CURSOR_STEP = "SpellshotQuickPlayCursor"

local POP = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LIFT_SELECTED, LIFT_HOVER = 6, 3

-- The five slots, in the template's own order and shape. `Locked` is the honest state of the
-- build: only DUEL has a match loop (the 3v3 team match), so every other card is locked -- and Duel
-- is the one the game is designed around (it is called Elemental Duels), so it is the hero and the
-- default. (2026-10-19, audit P6B-06: Squad Clash and Convergence were selectable and the server refused them.)
local MODES = {
	{
		Id = "Duel", Slot = "hero", Colour = C.Red, Title = "DUEL",
		--[[Sub = "1v1 · STEP ON, FIGHT NOW" until 2026-10-18 team mode]]
		Sub = ("%dv%d · TEAMS, FIRST TO %d"):format(TEAM_SIZE, TEAM_SIZE, (Config.Team and Config.Team.FirstTo) or 5),
		Tag = "CASUAL · INSTANT", Flag = "POPULAR",
	},
	{
		Id = "SquadClash", Slot = "wide", Colour = C.Cyan, Title = "SQUAD CLASH",
		Sub = "5v5 · FULL TEAM BRAWL",
		-- (2026-10-19, audit P6B-06) HubServer starts only DUEL ("Only DUEL can start a match in this build")
		Locked = true,
	},
	{
		Id = "Convergence", Slot = "small", Colour = C.Gold, Title = "CONVER-\nGENCE",
		Sub = "WEEKLY LTM", Locked = true,   -- (2026-10-19, audit P6B-06) was Burst = "NOW LIVE!": the server refuses it
	},
	{
		Id = "Ranked", Slot = "small", Colour = C.Track, Title = "RANKED",
		Sub = "MODE + SIZE TBC", Locked = true, Note = "UNLOCK TBC", NoteDashed = true,
	},
	{
		Id = "RiftRoyale", Slot = "small", Colour = C.Track, Title = "RIFT\nROYALE",
		Sub = "FREE FOR ALL", Locked = true, Note = "SEASON 2",
	},
}

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

local function outline(parent, t, colour)
	return make("UIStroke", {
		Color = colour or C.Ink, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function mono(parent, props)
	local t = make("TextLabel", {
		BackgroundTransparency = 1, FontFace = MONO, TextColor3 = C.Ink, TextSize = 14,
		Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props) do t[k] = v end
	return t
end

--- Display lettering the way the rest of the game builds it: a coloured face over a solid copy
--- knocked down-right. Both are the same label with the same props, so they always lay out alike.
--- Returns face, extrude.
local function display(parent, props, depth, faceColour, extrudeColour, stroke)
	local labels = {}
	local z = props.ZIndex or 6
	for i, spec in ipairs({ { extrudeColour, depth, z }, { faceColour, 0, z + 1 } }) do
		local l = make("TextLabel", {
			BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextXAlignment = Enum.TextXAlignment.Left,
		}, parent)
		for k, v in pairs(props) do l[k] = v end
		l.TextColor3 = spec[1]
		l.ZIndex = spec[3]
		l.Position = props.Position + UDim2.fromOffset(spec[2], spec[2])
		if stroke then make("UIStroke", { Color = C.Ink, Thickness = stroke }, l) end
		labels[i] = l
	end
	return labels[2], labels[1]
end

local function halftone(parent, alpha, colour, pitch, size, pos, z)
	return make("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = DOT, ImageColor3 = colour or C.Ink,
		ImageTransparency = alpha, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(pitch, pitch),
		Size = size or UDim2.fromScale(1, 1), Position = pos or UDim2.new(), ZIndex = z or 1,
	}, parent)
end

--- Flat colour, a heavy ink border and one solid ink shadow, never a gradient. The holder is
--- centred on its box so a pop scales from the middle. The face can lift off the shadow (selected,
--- hovered) or push down into it (pressed) while the shadow stays put, which is what sells it as
--- paper. Returns holder, face, stroke.
local function slab(parent, size, pos, colour, z)
	local holder = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, ZIndex = z or 2,
		Position = UDim2.fromOffset(pos.X.Offset + size.X.Offset / 2, pos.Y.Offset + size.Y.Offset / 2),
	}, parent)
	local shadow = make("Frame", {
		Name = "Shadow", BackgroundColor3 = C.Ink, BorderSizePixel = 0, ZIndex = 1,
		Size = UDim2.new(1, -SHADOW, 1, -SHADOW), Position = UDim2.fromOffset(SHADOW, SHADOW),
	}, holder)
	corner(shadow, RADIUS)
	local face = make("Frame", {
		Name = "Face", BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = 2,
		Size = UDim2.new(1, -SHADOW, 1, -SHADOW),
	}, holder)
	corner(face, RADIUS)
	return holder, face, outline(face, BORDER)
end

local function hitbox(parent)
	return make("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 50,
	}, parent)
end

--- The template's little labels: a thin-bordered chip, ink-on-cream or cream-on-ink.
local function chip(parent, label, pos, dark, w, h, textSize, anchor)
	local face = make("Frame", {
		BackgroundColor3 = dark and C.Ink or C.Pill, BorderSizePixel = 0, Position = pos,
		AnchorPoint = anchor or Vector2.zero, Size = UDim2.fromOffset(w, h), ZIndex = 20,
	}, parent)
	corner(face, 2)
	outline(face, 2)
	mono(face, {
		Text = label, TextSize = textSize, TextColor3 = dark and C.CreamText or C.Ink,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 21,
	})
	return face
end

--- UIStroke draws no dashes, so the template's dashed box is built from short bars.
local function dashedBox(parent, pos, w, h, colour, z)
	local root = make("Frame", {
		BackgroundTransparency = 1, Position = pos, Size = UDim2.fromOffset(w, h), ZIndex = z,
	}, parent)
	local DASH, GAP, T = 6, 4, 2
	local function run(horizontal, fixed)
		local length = horizontal and w or h
		local at = 0
		while at < length do
			local n = math.min(DASH, length - at)
			make("Frame", {
				BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = z,
				Position = horizontal and UDim2.fromOffset(at, fixed) or UDim2.fromOffset(fixed, at),
				Size = horizontal and UDim2.fromOffset(n, T) or UDim2.fromOffset(T, n),
			}, root)
			at += DASH + GAP
		end
	end
	run(true, 0)
	run(true, h - T)
	run(false, 0)
	run(false, w - T)
	return root
end

----------------------------------------------------------------------------------------------------
-- emblems and badges  (drawn, not uploaded)
----------------------------------------------------------------------------------------------------
--- The Duel mark: a cream disc in a heavy ink ring, crossed by a card-coloured X with an ink rim.
--- The X is drawn OVER the disc rather than clipped inside it, because a rotated GuiObject escapes
--- every ancestor clip. The rims sit a layer below both coloured bars, so no ink line cuts the
--- crossing.
local function emblemX(parent, size, pos, colour)
	local root = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Position = pos, ZIndex = 5,
	}, parent)
	local disc = make("Frame", {
		BackgroundColor3 = C.Pill, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1,
	}, root)
	corner(disc, math.floor(size / 2))
	outline(disc, math.max(5, math.floor(size * 0.065)))
	local arm, thick, rim = size * 0.66, size * 0.17, 4
	for _, spec in ipairs({ { C.Ink, rim, 2 }, { colour, 0, 3 } }) do
		for _, deg in ipairs({ 45, -45 }) do
			local bar = make("Frame", {
				BackgroundColor3 = spec[1], BorderSizePixel = 0, Rotation = deg, ZIndex = spec[3],
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(arm + spec[2] * 2, thick + spec[2] * 2),
			}, root)
			corner(bar, 3)
		end
	end
	return root
end

--- The Squad mark: two hollow squares -- a cream one and a gold one behind it -- with a red pennant
--- in front. Each square side is an ink bar with a narrower coloured bar on top, so the band has ink
--- on both edges. The pennant is a bar with a diamond under its bottom edge for the point.
local function emblemSquad(parent, size, pos, accent, second)
	local root = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Position = pos, ZIndex = 5,
	}, parent)
	local box = math.floor(size * 0.6)
	local band, e = math.max(5, math.floor(size * 0.055)), 3
	local function hollow(x, y, colour, z)
		for _, spec in ipairs({ { C.Ink, e, z }, { colour, 0, z + 1 } }) do
			local o = spec[2]
			for _, s in ipairs({
				{ x - o, y - o, box + 2 * o, band + 2 * o },
				{ x - o, y + box - band - o, box + 2 * o, band + 2 * o },
				{ x - o, y - o, band + 2 * o, box + 2 * o },
				{ x + box - band - o, y - o, band + 2 * o, box + 2 * o },
			}) do
				make("Frame", {
					BackgroundColor3 = spec[1], BorderSizePixel = 0, ZIndex = spec[3],
					Position = UDim2.fromOffset(s[1], s[2]), Size = UDim2.fromOffset(s[3], s[4]),
				}, root)
			end
		end
	end
	hollow(math.floor(size * 0.34), 0, second, 1)
	hollow(0, math.floor(size * 0.1), C.Pill, 3)

	local pw, ph = math.floor(size * 0.36), math.floor(size * 0.40)
	local px, py = math.floor(size * 0.22), math.floor(size * 0.26)
	local side = pw * 0.7071        -- a square turned 45 degrees whose width equals the bar's
	for _, spec in ipairs({ { C.Ink, 4, 5 }, { accent, 0, 6 } }) do
		local g = spec[2]
		make("Frame", {
			BackgroundColor3 = spec[1], BorderSizePixel = 0, ZIndex = spec[3],
			Position = UDim2.fromOffset(px - g, py - g), Size = UDim2.fromOffset(pw + g * 2, ph + g),
		}, root)
		make("Frame", {
			BackgroundColor3 = spec[1], BorderSizePixel = 0, ZIndex = spec[3], Rotation = 45,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px + pw / 2, py + ph),
			Size = UDim2.fromOffset(side + g * 1.4, side + g * 1.4),
		}, root)
	end
	return root
end

--- The template's LOCKED badge: a red diamond in a cream rim and an ink rim, the word straight
--- across it. Returns the badge and its UIScale, so a refused click can thump it.
local function lockedBadge(parent, center, size)
	local root = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = center,
		Size = UDim2.fromOffset(size, size), ZIndex = 12,
	}, parent)
	local pop = make("UIScale", {}, root)
	for _, spec in ipairs({ { C.Ink, size + 10, 1 }, { C.Pill, size + 4, 2 }, { C.RedInk, size, 3 } }) do
		local diamond = make("Frame", {
			BackgroundColor3 = spec[1], BorderSizePixel = 0, Rotation = 45, ZIndex = spec[3],
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(spec[2] * 0.7071, spec[2] * 0.7071),
		}, root)
		corner(diamond, 2)
	end
	local label = mono(root, {
		Text = "LOCKED", TextSize = 13, TextColor3 = C.CreamText, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, 16), ZIndex = 4,
	})
	make("UIStroke", { Color = C.Ink, Thickness = 1.5 }, label)
	return root, pop
end

--- The template's NOW LIVE! sticker: a tilted strip with a zigzag top and bottom and pointed ends.
--- The teeth are squares turned 45 degrees along both long edges, drawn twice -- ink, then red on
--- top -- so the rim is the silhouette's own edge and no line runs through the middle.
local function sticker(parent, label, center, w)
	local h, tooth = 30, 13
	local root = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = center,
		Size = UDim2.fromOffset(w, h), Rotation = -9, ZIndex = 12,
	}, parent)
	local count = math.floor(w / tooth)
	for _, spec in ipairs({ { C.Ink, 4, 1 }, { C.Red, 0, 2 } }) do
		local g = spec[2]
		local function square(x, y, s)
			make("Frame", {
				BackgroundColor3 = spec[1], BorderSizePixel = 0, ZIndex = spec[3], Rotation = 45,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(s + g * 1.4, s + g * 1.4),
			}, root)
		end
		make("Frame", {
			BackgroundColor3 = spec[1], BorderSizePixel = 0, ZIndex = spec[3],
			Position = UDim2.fromOffset(-g, -g), Size = UDim2.fromOffset(w + g * 2, h + g * 2),
		}, root)
		for i = 0, count do
			square(i / count * w, 0, tooth * 0.62)
			square(i / count * w, h, tooth * 0.62)
		end
		square(0, h / 2, h * 0.72)
		square(w, h / 2, h * 0.72)
	end
	local t = make("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = label, TextSize = 20,
		TextColor3 = C.CreamText, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = 3,
	}, root)
	make("UIStroke", { Color = C.Ink, Thickness = 2 }, t)
	return root
end

----------------------------------------------------------------------------------------------------
-- the screen
----------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("QuickPlay")
if old then old:Destroy() end

local gui = make("ScreenGui", {
	Name = "QuickPlay", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 42, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local command = make("BindableEvent", { Name = "Command" }, gui)

-- The opener. Third in the strip, left of the loadout chip and the gear, and the only wide red one
-- of the three: this is the primary action and those two are adjustments to it. Built in the strip's
-- own lighter style, not the screen's heavy one, so the three chips still match each other.
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local chipH = touchOnly and 52 or 44
local PLAY_W = touchOnly and 104 or 88
local LOADOUT_LABEL_W = 88     -- LoadoutMenu's button carries a LOADOUT label this wide beside its icon (its LABEL_W)
local playHolder = make("Frame", {
	Name = "QuickPlayButton", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14 - (chipH + 9) * 2 - LOADOUT_LABEL_W, 0, 7), Size = UDim2.fromOffset(PLAY_W + 3, chipH + 3), ZIndex = 1,
}, gui)
local playShadow = make("Frame", {
	BackgroundColor3 = C.Ink, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 1,
	Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -3, 1, -3),
}, playHolder)
corner(playShadow, 5)
local playFace = make("Frame", {
	BackgroundColor3 = C.Red, BorderSizePixel = 0, ZIndex = 2, Size = UDim2.new(1, -3, 1, -3),
}, playHolder)
corner(playFace, 5)
outline(playFace, 2)
halftone(playFace, 0.9, C.Ink, 6)
local playWord = make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.Bangers, Text = "PLAY", TextSize = 26, TextColor3 = C.CreamText,
	Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), ZIndex = 3,
}, playFace)

-- WHILE QUEUED THE CHIP SAYS SO. Closing the screen does not leave the queue, so the chip is the only
-- place left that can show it: it turns ink -- the same ink the CANCEL button turns -- and reads
-- QUEUING, with a pulsing red dot and the mode and time in queue under it. It grows to the LEFT, so
-- it never pushes into the loadout chip, and a click still opens the screen, which is where CANCEL is.
local QUEUED_W = touchOnly and 160 or 144
local queuedDot = make("Frame", {
	Name = "QueuedDot", BackgroundColor3 = C.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 17, 0.5, 0), Size = UDim2.fromOffset(10, 10), Visible = false, ZIndex = 3,
}, playFace)
corner(queuedDot, 7)
outline(queuedDot, 1.5, C.CreamText)
local queuedWord = make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.Bangers, Text = "QUEUING", TextSize = 24, TextColor3 = C.CreamText,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(30, touchOnly and 5 or 2),
	Size = UDim2.new(1, -36, 0, 26), Visible = false, ZIndex = 3,
}, playFace)
local queuedInfo = mono(playFace, {
	Text = "", TextSize = 11, TextColor3 = C.Track, Position = UDim2.new(0, 31, 1, touchOnly and -19 or -16),
	Size = UDim2.new(1, -36, 0, 12), Visible = false, ZIndex = 3,
})
local playHit = hitbox(playFace)

-- the paper, edge to edge, above everything else on screen (the chip strip included)
local backdrop = make("Frame", {
	Name = "Backdrop", BackgroundColor3 = C.Paper, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
	Visible = false, ZIndex = 5,
}, gui)
local dots = make("ImageLabel", {
	BackgroundTransparency = 1, Image = DOT, ImageColor3 = C.Ink, ImageTransparency = DOT_ALPHA,
	ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(12, 12), Size = UDim2.fromScale(1, 1), ZIndex = 1,
}, backdrop)

local panel = make("Frame", {
	Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), ZIndex = 2,
}, backdrop)
local fitScale = make("UIScale", {}, panel)

local popTargets = {}        -- UIScales that pop in on open, in reading order

----------------------------------------------------------------------------------------------------
-- header row
----------------------------------------------------------------------------------------------------
local backHolder, backFace = slab(panel, UDim2.fromOffset(64, 56), UDim2.fromOffset(0, 2), C.Pill, 5)
make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "◀", TextSize = 42, TextColor3 = C.Ink,
	Size = UDim2.fromScale(1, 1), ZIndex = 4,
}, backFace)
local backHit = hitbox(backFace)
popTargets[#popTargets + 1] = make("UIScale", {}, backHolder)

local bannerHolder, bannerFace = slab(panel, UDim2.fromOffset(380, 68), UDim2.fromOffset(80, -2), C.Gold, 5)
bannerHolder.Rotation = -1.5
halftone(bannerFace, 0.9, C.Ink, 7)
make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "QUICK PLAY", TextSize = 54, TextColor3 = C.Ink,
	Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 3), ZIndex = 4,
}, bannerFace)
popTargets[#popTargets + 1] = make("UIScale", {}, bannerHolder)

chip(panel, "CHOOSE YOUR FIGHT", UDim2.fromOffset(DESIGN_W - SHADOW, 12), false, 240, 40, 16, Vector2.new(1, 0))

----------------------------------------------------------------------------------------------------
-- the cards
----------------------------------------------------------------------------------------------------
local TOP, CARDS_BOTTOM = 86, 510
local HERO_W, HERO_H = 500, CARDS_BOTTOM - TOP
local RIGHT_X = HERO_W + 20
local RIGHT_W = DESIGN_W - RIGHT_X
local WIDE_H = 244
local SMALL_GAP = 16
local SMALL_Y = TOP + WIDE_H + 14
local SMALL_H = CARDS_BOTTOM - SMALL_Y
local SMALL_W = math.floor((RIGHT_W - SMALL_GAP * 2) / 3)

local cards = {}
local selected = "Duel"
local queued = false
local hovered = nil

local function smallIndex(id)
	local n = 0
	for _, m in ipairs(MODES) do
		if m.Slot == "small" then
			n += 1
			if m.Id == id then return n end
		end
	end
	return 1
end

local function buildCard(m)
	local w, h, x, y
	if m.Slot == "hero" then
		w, h, x, y = HERO_W, HERO_H, 0, TOP
	elseif m.Slot == "wide" then
		w, h, x, y = RIGHT_W, WIDE_H, RIGHT_X, TOP
	else
		w, h, x, y = SMALL_W, SMALL_H, RIGHT_X + (smallIndex(m.Id) - 1) * (SMALL_W + SMALL_GAP), SMALL_Y
	end
	local holder, face, stroke = slab(panel, UDim2.fromOffset(w, h), UDim2.fromOffset(x, y), m.Colour, 3)
	local fw, fh = w - SHADOW, h - SHADOW
	local card = { mode = m, holder = holder, face = face, stroke = stroke }

	if m.Slot == "hero" then
		halftone(face, 0.8, C.Ink, 11, UDim2.fromOffset(232, 196), UDim2.fromOffset(fw - 250, 60))
		chip(face, m.Tag, UDim2.fromOffset(20, 20), true, 176, 34, 15)
		chip(face, m.Flag, UDim2.fromOffset(fw - 20, 20), false, 114, 34, 15, Vector2.new(1, 0))
		emblemX(face, 168, UDim2.fromOffset(28, 86), m.Colour)
		display(face, {
			Text = m.Title, TextSize = 118, Position = UDim2.fromOffset(22, fh - 158),
			Size = UDim2.fromOffset(fw - 44, 120), ZIndex = 6,
		}, 6, C.CreamText, C.Ink, 2)
		mono(face, {
			Text = m.Sub, TextSize = 18, TextColor3 = C.CreamText, Position = UDim2.fromOffset(26, fh - 34),
			Size = UDim2.fromOffset(fw - 52, 22), ZIndex = 6,
		})

	elseif m.Slot == "wide" then
		halftone(face, 0.78, C.Ink, 11, UDim2.fromOffset(184, 120), UDim2.fromOffset(14, fh - 132))
		emblemSquad(face, 150, UDim2.fromOffset(34, 42), C.Red, C.Gold)
		display(face, {
			Text = m.Title, TextSize = 60, Position = UDim2.fromOffset(212, 64),
			Size = UDim2.fromOffset(fw - 232, 76), ZIndex = 6,
		}, 5, C.CreamText, C.Ink, 2)
		-- ink, not cream: cream on bright cyan is the one pairing on this screen that doesn't read
		mono(face, {
			Text = m.Sub, TextSize = 18, TextColor3 = C.Ink, Position = UDim2.fromOffset(216, 144),
			Size = UDim2.fromOffset(fw - 232, 22), ZIndex = 6,
		})
		if m.Locked then   -- (2026-10-19, audit P6B-06) the wide card can be locked too (Squad Clash)
			card.badge, card.badgePop = lockedBadge(face, UDim2.fromOffset(fw - 44, fh - 44), 64)
		end

	else
		local lines = select(2, m.Title:gsub("\n", "")) + 1
		local ink = m.Locked and C.LockedInk or C.Ink
		halftone(face, m.Locked and 0.8 or 0.84, C.Ink, 9)
		display(face, {
			Text = m.Title, TextSize = 34, Position = UDim2.fromOffset(16, 12),
			Size = UDim2.fromOffset(fw - 28, lines * 36), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6,
		}, 3, ink, m.Colour:Lerp(C.Ink, 0.28), nil)
		mono(face, {
			Text = m.Sub, TextSize = 13, TextColor3 = ink, Position = UDim2.fromOffset(18, 16 + lines * 36),
			Size = UDim2.fromOffset(fw - 32, 16), ZIndex = 6,
		})
		if m.Note then
			local at = UDim2.fromOffset(16, fh - 48)
			if m.NoteDashed then
				dashedBox(face, at, 88, 32, C.LockedInk, 7)
				mono(face, {
					Text = m.Note, TextSize = 12, TextColor3 = C.LockedInk, TextXAlignment = Enum.TextXAlignment.Center,
					Position = at, Size = UDim2.fromOffset(88, 32), ZIndex = 8,
				})
			else
				chip(face, m.Note, at, false, 90, 32, 13)
			end
		end
		if m.Locked then
			card.badge, card.badgePop = lockedBadge(face, UDim2.fromOffset(fw - 44, fh - 44), 64)
		end
		if m.Burst then
			sticker(face, m.Burst, UDim2.fromOffset(fw / 2 + 8, fh - 34), 132)
		end
	end

	card.hit = hitbox(face)
	popTargets[#popTargets + 1] = make("UIScale", {}, holder)
	cards[m.Id] = card
	return card
end

for _, m in ipairs(MODES) do buildCard(m) end

----------------------------------------------------------------------------------------------------
-- footer: the selection line, the note, the queue button
----------------------------------------------------------------------------------------------------
local QUEUE_W, QUEUE_H = 300, 72
local queueHolder, queueFace = slab(panel, UDim2.fromOffset(QUEUE_W, QUEUE_H),
	UDim2.fromOffset(DESIGN_W - QUEUE_W, DESIGN_H - QUEUE_H), C.Red, 5)
halftone(queueFace, 0.88, C.Ink, 8)
local queueWord, queueExtrude = display(queueFace, {
	Text = "QUEUE", TextSize = 50, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -8),
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
}, 4, C.CreamText, C.Ink, 2)
local queueHit = hitbox(queueFace)
popTargets[#popTargets + 1] = make("UIScale", {}, queueHolder)

-- SOLO TEST: the arena on your own, for testing without a second player. Paper, not red, so QUEUE
-- stays the one primary button.
local SOLO_W, SOLO_GAP = 190, 14
local soloHolder, soloFace = slab(panel, UDim2.fromOffset(SOLO_W, QUEUE_H),
	UDim2.fromOffset(DESIGN_W - QUEUE_W - SOLO_GAP - SOLO_W, DESIGN_H - QUEUE_H), C.Pill, 5)
halftone(soloFace, 0.9, C.Ink, 8)
display(soloFace, {
	Text = "SOLO TEST", TextSize = 30, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -12),
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
}, 3, C.Ink, C.Track, nil)
local soloHit = hitbox(soloFace)
popTargets[#popTargets + 1] = make("UIScale", {}, soloHolder)

local FOOTER_RIGHT = DESIGN_W - QUEUE_W - SOLO_GAP - SOLO_W - 18
local selectedLine = mono(panel, {
	Text = "", TextSize = 17, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(FOOTER_RIGHT, DESIGN_H - QUEUE_H / 2 - 4),
	Size = UDim2.fromOffset(300, 24), ZIndex = 6,
})

local note = mono(panel, {
	Text = "", TextSize = 14, TextColor3 = C.LockedInk, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Bottom, Position = UDim2.fromOffset(2, DESIGN_H - 58),
	Size = UDim2.fromOffset(330, 40), ZIndex = 6,
})
local function say(msg, bad)
	note.Text = msg
	note.TextColor3 = bad and C.RedInk or C.LockedInk
end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local function modeById(id)
	for _, m in ipairs(MODES) do
		if m.Id == id then return m end
	end
end

--- Where every card's face should sit: selected stands up off its shadow, hover lifts a little,
--- locked cards never lift.
local function paintCards()
	for id, card in pairs(cards) do
		local on = id == selected
		card.stroke.Thickness = on and BORDER + 2 or BORDER
		local px = on and LIFT_SELECTED or ((hovered == id and not card.mode.Locked) and LIFT_HOVER or 0)
		TweenService:Create(card.face, QUICK, { Position = UDim2.fromOffset(-px, -px) }):Play()
	end
end

--- Push a face down into its shadow for a beat, then let paintCards (or `rest`) put it back.
local function press(face, rest)
	face.Position = UDim2.fromOffset(2, 2)
	task.delay(0.07, function()
		if rest then
			TweenService:Create(face, QUICK, { Position = rest }):Play()
		else
			paintCards()
		end
	end)
end

--- The chip's QUEUING face. The clock is time since QUEUE was pressed. It counts honestly, for as long
--- as you stay queued: there is no match service yet to end it.
local queuedAt = nil
local queueFill = nil     -- "3/6": how full the queue is, as HubServer last said (2026-10-18, team mode)
local chipClock = nil
local pulse = nil

local function stopPulse()
	if pulse then
		pulse:Cancel()
		pulse = nil
	end
	queuedDot.Size = UDim2.fromOffset(10, 10)
	queuedDot.BackgroundTransparency = 0
end

--- A slow swell, not a blink. With Reduce Flashing on, the dot just stays lit.
local function startPulse()
	stopPulse()
	if Settings.Get("ReduceFlashing") then return end
	pulse = TweenService:Create(queuedDot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 0.35 })
	pulse:Play()
end

local function chipTime()
	local m = modeById(selected)
	local title = m and m.Title:gsub("%c", ""):gsub("%-", "") or "--"
	local s = math.floor(os.clock() - (queuedAt or os.clock()))
	-- with the queue's fill once the server has said it (2026-10-18, team mode): "DUEL 3/6 · 0:12"
	queuedInfo.Text = queueFill and ("%s %s · %d:%02d"):format(title, queueFill, s // 60, s % 60)
		or ("%s · %d:%02d"):format(title, s // 60, s % 60)
end

local function paintChip()
	local on = queued and queuedAt ~= nil
	playFace.BackgroundColor3 = on and C.Ink or C.Red
	playWord.Visible = not on
	queuedWord.Visible = on
	queuedInfo.Visible = on
	queuedDot.Visible = on
	TweenService:Create(playHolder, QUICK, { Size = UDim2.fromOffset((on and QUEUED_W or PLAY_W) + 3, chipH + 3) }):Play()
	if on then
		chipTime()
		if not chipClock then
			local last = 0
			chipClock = RunService.Heartbeat:Connect(function()
				if os.clock() - last >= 0.25 then
					last = os.clock()
					chipTime()
				end
			end)
		end
		if not pulse then startPulse() end
	else
		if chipClock then
			chipClock:Disconnect()
			chipClock = nil
		end
		stopPulse()
	end
end

local function refresh()
	paintCards()
	local m = modeById(selected)
	local title = m and m.Title:gsub("\n", ""):gsub("%-", "") or "--"
	local size = m and (m.Sub:match("^[^·]+") or ""):gsub("%s+$", "") or ""
	selectedLine.Text = "SELECTED · " .. title .. (size ~= "" and (" " .. size) or "")
	queueFace.BackgroundColor3 = queued and C.Ink or C.Red
	queueWord.Text = queued and "CANCEL" or "QUEUE"
	queueExtrude.Text = queueWord.Text
	-- on the ink button the extrude turns red, or the lettering would lose its shadow entirely
	queueExtrude.TextColor3 = queued and C.Red or C.Ink
	paintChip()
end

local function choose(id)
	local m = modeById(id)
	if not m then return end
	local card = cards[id]
	if m.Locked then
		say(("%s is locked -- %s."):format((m.Title:gsub("\n", " ")), (m.Note or "not available yet"):lower()), true)
		if card and card.badgePop then
			card.badgePop.Scale = 1.3
			TweenService:Create(card.badgePop, POP, { Scale = 1 }):Play()
		end
		return
	end
	if queued then
		say("Cancel the queue before changing mode.", true)
		return
	end
	selected = id
	player:SetAttribute("QuickPlayMode", id)
	say("")
	refresh()
	if card then press(card.face) end
end

-- (2026-10-19, audit P6A-18) HubServer silently drops any request but "cancel" that comes within 0.25 s of the one
-- before it, which left this screen showing QUEUING while the server had you out (or the reverse). Requests that would
-- land inside that gap are held and sent once it has passed; a held "queue" is dropped if you cancelled meanwhile.
local ASK_GAP = 0.35
local lastAsk = 0
local function ask(remote, what)
	if what == "cancel" then remote:FireServer(what, selected) return end   -- never throttled by the server
	local wait = ASK_GAP - (os.clock() - lastAsk)
	if wait <= 0 then
		lastAsk = os.clock()
		remote:FireServer(what, selected)
		return
	end
	lastAsk = os.clock() + wait
	task.delay(wait, function()
		if what == "queue" and not queued then return end
		remote:FireServer(what, selected)
	end)
end

--- fromServer: HubServer already dropped you from the queue, so there is nothing to tell it.
local function setQueued(v, fromServer)
	local was = queued
	if v and not queued then
		queuedAt = os.clock()
	elseif not v then
		queuedAt = nil
		queueFill = nil
	end
	queued = v
	player:SetAttribute("QuickPlayQueued", v or nil)
	local remote = hubRemote()
	if not fromServer and remote and v ~= was then
		ask(remote, v and "queue" or "cancel")
	end
	if v then
		local title = modeById(selected).Title:gsub("\n", ""):gsub("%-", "")
		if not remote then
			say("Queued for " .. title .. " -- the Hub server is not running, so nothing will start.", true)
		elseif selected == "Duel" and GLOBAL_QUEUE then
			say(("SEARCHING ALL SERVERS for DUEL %dv%d..."):format(TEAM_SIZE, TEAM_SIZE))
		elseif selected == "Duel" then
			--[["Queued for DUEL -- waiting for a second duellist in this Hub." until 2026-10-18 team mode]]
			say(("Queued for DUEL %dv%d -- it starts when %d are queued in this Hub."):format(TEAM_SIZE, TEAM_SIZE, 2 * TEAM_SIZE))
		else
			say("Queued for " .. title .. "...")
		end
	elseif not fromServer then
		say("")
	end
	refresh()
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local open = false

local function entrance()
	for i, s in ipairs(popTargets) do
		s.Scale = 0.86
		task.delay((i - 1) * 0.035, function()
			if open then TweenService:Create(s, POP, { Scale = 1 }):Play() else s.Scale = 1 end
		end)
	end
end

local function setOpen(v)
	if v == open then return end
	open = v
	-- the input scripts stand down while a menu is up, the same as the other two panels
	player:SetAttribute("QuickPlayOpen", v or nil)
	if v then
		hovered = nil
		refresh()
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		dots.ImageTransparency = 1
		TweenService:Create(backdrop, TweenInfo.new(0.16), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(dots, TweenInfo.new(0.16), { ImageTransparency = DOT_ALPHA }):Play()
		entrance()
		-- first person re-locks the mouse every frame; win it back while the screen is up
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		backdrop.Visible = false
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
	end
end

for id, card in pairs(cards) do
	card.hit.Activated:Connect(function() choose(id) end)
	card.hit.MouseEnter:Connect(function()
		hovered = id
		paintCards()
	end)
	card.hit.MouseLeave:Connect(function()
		if hovered == id then hovered = nil end
		paintCards()
	end)
end

--- The two plain buttons (back, queue) lift on hover and press on click, like the cards.
local function buttonFeel(face, hit, onActivate)
	local up = UDim2.fromOffset(-LIFT_HOVER, -LIFT_HOVER)
	hit.MouseEnter:Connect(function() TweenService:Create(face, QUICK, { Position = up }):Play() end)
	hit.MouseLeave:Connect(function() TweenService:Create(face, QUICK, { Position = UDim2.new() }):Play() end)
	hit.Activated:Connect(function()
		press(face, up)
		onActivate()
	end)
end

buttonFeel(queueFace, queueHit, function() setQueued(not queued) end)
buttonFeel(soloFace, soloHit, function()
	local remote = hubRemote()
	if not remote then
		say("SOLO TEST needs the Hub server, and it is not running.", true)
		return
	end
	if queued then setQueued(false, true) end
	ask(remote, "solo")          -- (P6A-18) paced like the queue: a throttled "solo" also left you queued server-side
	say("Sending you to the arena on your own...")
end)
buttonFeel(backFace, backHit, function() setOpen(false) end)

playHit.Activated:Connect(function() setOpen(not open) end)
playHit.MouseEnter:Connect(function()
	TweenService:Create(playWord, TweenInfo.new(0.15), { TextSize = 29 }):Play()
end)
playHit.MouseLeave:Connect(function()
	TweenService:Create(playWord, TweenInfo.new(0.15), { TextSize = 26 }):Play()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not open then return end
	if input.KeyCode == Enum.KeyCode.Escape then setOpen(false) end
end)

command.Event:Connect(function(what, a)
	if what == "open" then setOpen(true)
	elseif what == "close" then setOpen(false)
	elseif what == "select" then choose(a)
	elseif what == "queue" then setQueued(true)
	elseif what == "cancel" then setQueued(false)
	elseif what == "dequeued" then
		setQueued(false, true)
		say(a or "")
	elseif what == "requeued" then
		-- (2026-10-18, team mode) the server put you back in the queue: a team match's map vote was called off
		setQueued(true, true)
		if a then say(a) end
	elseif what == "count" then
		-- (2026-10-18, team mode) the queue's fill from HubServer, "3/6": on the chip, and in the footer while queued
		queueFill = (type(a) == "string") and a or nil
		if queued then
			if selected == "Duel" and queueFill and GLOBAL_QUEUE then
				say(("SEARCHING ALL SERVERS -- %s for DUEL %dv%d."):format(queueFill, TEAM_SIZE, TEAM_SIZE))
			elseif selected == "Duel" and queueFill then
				say(("Queued for DUEL %dv%d -- %s in the queue."):format(TEAM_SIZE, TEAM_SIZE, queueFill))
			end
			chipTime()
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- fit
----------------------------------------------------------------------------------------------------
-- Sized off the ScreenGui, because Camera.ViewportSize can misreport in Studio. Two candidate fits,
-- and the bigger one wins:
--   below   everything under the topbar strip, 95% of the width / 96% of what height is left
--   beside  the full height, with side margins wide enough that the header clears Roblox's buttons
-- A short wide window (Studio) takes "beside"; a 16:9 screen takes "below".
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
	local below = math.min(s.X * 0.95 / DESIGN_W, (s.Y - topH) * 0.96 / DESIGN_H)
	local beside = math.min((s.X - 2 * (leftW + 8)) / DESIGN_W, s.Y * 0.96 / DESIGN_H)
	if below >= beside then
		fitScale.Scale = math.max(0.3, below)
		panel.Position = UDim2.fromOffset(s.X / 2, topH + (s.Y - topH) / 2)
	else
		fitScale.Scale = math.max(0.3, beside)
		panel.Position = UDim2.fromOffset(s.X / 2, s.Y / 2)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit) end)
fit()

Settings.OnChange("ReduceFlashing", function()
	if queued then startPulse() end
end)

player:SetAttribute("QuickPlayMode", selected)
refresh()
