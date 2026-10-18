--[[
	MapVote  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/MapVote

	The map vote between a confirmed match and the arena (the user's call, 2026-09-14: once a duel is confirmed,
	or on a solo test, vote for the map before loading in). HubServer runs the vote; this script only draws it
	and sends the clicks. Every way into the arena goes through it: Quick Play's DUEL match, a full Duel Pad,
	SOLO TEST from Quick Play or a pad, and the range door.

	  vote        server -> client  { Id, Kind = "Duel" | "Team" | "Solo", Seconds, Maps = {{ Id, Name, Sub, Image, Accent }},
	                                  Players = {{ UserId, Name, Team }} }   (Team "A" | "B": a team match's, 2026-10-18)
	  voteTally   server -> client  Id, {{ UserId, Map }}      everyone's vote so far, after every change
	  voteResult  server -> client  Id, winner (nil: called off), how ("votes" | "tie" | "none" | "left")
	  vote        client -> server  Id, map id                 clicking another map changes your vote

	MOST VOTES WINS. A tie, or no votes at all, is a coin flip. A solo test ends the moment you pick. The
	wipe to the arena (HubClient) closes this screen.

	Same paper, ink, halftone and slabs as Quick Play, so the two read as one flow. For tools: the ScreenGui
	carries a BindableEvent "Command" -- Fire("close"), Fire("pick", mapId).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hubRemote = ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("Hub", 30)
if not hubRemote then return end

local DOT = "rbxassetid://82944445925061"     -- BarKit's halftone cell, as the other panels use

local C = {
	Ink = Color3.fromRGB(17, 17, 17),
	Paper = Color3.fromRGB(234, 229, 216),
	Card = Color3.fromRGB(246, 243, 235),
	Pill = Color3.fromRGB(250, 247, 240),
	Red = Color3.fromRGB(228, 37, 31),
	Cyan = Color3.fromRGB(18, 198, 231),
	Gold = Color3.fromRGB(245, 184, 0),
	CreamText = Color3.fromRGB(250, 244, 232),
	Track = Color3.fromRGB(222, 213, 196),
	LockedInk = Color3.fromRGB(88, 82, 72),
}
local ACCENT = { Gold = C.Gold, Cyan = C.Cyan }

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local DESIGN_W, DESIGN_H = 1160, 600
local SHADOW, BORDER, RADIUS = 8, 3, 3
local DOT_ALPHA = 0.84
local CURSOR_STEP = "SpellshotMapVoteCursor"

local POP = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LIFT_SELECTED, LIFT_HOVER = 6, 3

----------------------------------------------------------------------------------------------------
-- kit (Quick Play's)
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

--- A coloured face over a solid copy knocked down-right, the game's display lettering. Returns face, extrude.
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

--- Flat colour, a heavy ink border and one solid ink shadow; the face lifts off the shadow or presses into it.
--- Returns holder, face, stroke.
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

local function chip(parent, label, pos, dark, w, h, textSize, anchor)
	local face = make("Frame", {
		BackgroundColor3 = dark and C.Ink or C.Pill, BorderSizePixel = 0, Position = pos,
		AnchorPoint = anchor or Vector2.zero, Size = UDim2.fromOffset(w, h), ZIndex = 20,
	}, parent)
	corner(face, 2)
	outline(face, 2)
	local text = mono(face, {
		Text = label, TextSize = textSize, TextColor3 = dark and C.CreamText or C.Ink,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 21,
	})
	return face, text
end

--- Quick Play's NOW LIVE! sticker: a tilted strip with zigzag edges, ink under red.
local function sticker(parent, label, center, w, colour, textSize)
	local h, tooth = 30, 13
	local root = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = center,
		Size = UDim2.fromOffset(w, h), Rotation = -9, ZIndex = 40, Visible = false,
	}, parent)
	local pop = make("UIScale", {}, root)
	local count = math.floor(w / tooth)
	for _, spec in ipairs({ { C.Ink, 4, 41 }, { colour or C.Red, 0, 42 } }) do
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
		BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = label, TextSize = textSize or 20,
		TextColor3 = C.CreamText, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = 43,
	}, root)
	make("UIStroke", { Color = C.Ink, Thickness = 2 }, t)
	return root, pop
end

----------------------------------------------------------------------------------------------------
-- the screen
----------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("MapVote")
if old then old:Destroy() end

-- above Quick Play (42) and the loadout menu, below the wipe (200)
local gui = make("ScreenGui", {
	Name = "MapVote", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local command = make("BindableEvent", { Name = "Command" }, gui)

local backdrop = make("Frame", {
	Name = "Backdrop", BackgroundColor3 = C.Paper, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
	Visible = false, ZIndex = 5,
}, gui)
local dots = make("ImageLabel", {
	BackgroundTransparency = 1, Image = DOT, ImageColor3 = C.Ink, ImageTransparency = DOT_ALPHA,
	ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(12, 12), Size = UDim2.fromScale(1, 1), ZIndex = 1,
}, backdrop)
make("TextButton", {               -- swallows clicks that miss the cards, so nothing behind the screen gets them
	Name = "Blocker", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2,
}, backdrop)

local panel = make("Frame", {
	Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), ZIndex = 3,
}, backdrop)
local fitScale = make("UIScale", {}, panel)
local popTargets = {}

-- header: the banner, who is in the match, the clock
local bannerHolder, bannerFace = slab(panel, UDim2.fromOffset(452, 68), UDim2.fromOffset(0, -2), C.Gold, 5)
bannerHolder.Rotation = -1.5
halftone(bannerFace, 0.9, C.Ink, 7)
make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "VOTE FOR A MAP", TextSize = 50, TextColor3 = C.Ink,
	Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 3), ZIndex = 4,
}, bannerFace)
popTargets[#popTargets + 1] = make("UIScale", {}, bannerHolder)

local _, kindText = chip(panel, "", UDim2.fromOffset(474, 14), true, 150, 40, 16)
local versus = mono(panel, {
	Text = "", TextSize = 17, Position = UDim2.fromOffset(640, 14), Size = UDim2.fromOffset(380, 40), ZIndex = 6,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local TIMER = 104
local timerHolder = make("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(DESIGN_W, -22),
	Size = UDim2.fromOffset(TIMER, TIMER), ZIndex = 5,
}, panel)
local timerShadow = make("Frame", {
	BackgroundColor3 = C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -6, 1, -6), ZIndex = 1,
}, timerHolder)
corner(timerShadow, TIMER)
local timerFace = make("Frame", {
	BackgroundColor3 = C.Pill, BorderSizePixel = 0, Size = UDim2.new(1, -6, 1, -6), ZIndex = 2,
}, timerHolder)
corner(timerFace, TIMER)
local timerStroke = outline(timerFace, 4)
local timerText = make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "", TextSize = 54, TextColor3 = C.Ink,
	Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), ZIndex = 3,
}, timerFace)
popTargets[#popTargets + 1] = make("UIScale", {}, timerHolder)

local note = mono(panel, {
	Text = "", TextSize = 16, TextColor3 = C.LockedInk, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center,
	Position = UDim2.fromOffset(2, DESIGN_H - 64), Size = UDim2.fromOffset(DESIGN_W - 4, 56), ZIndex = 6,
})

----------------------------------------------------------------------------------------------------
-- the cards, one per map, rebuilt for every vote
----------------------------------------------------------------------------------------------------
local CARD_TOP, CARD_BOTTOM, CARD_GAP = 92, 524, 24
local cards = {}
local cardPops = {}
local state = nil        -- the vote on screen: { Id, Kind, Maps, Players, EndsAt, Picks, Mine, Winner }
local hovered = nil
local open = false

local function paint()
	if not state then return end
	for id, card in pairs(cards) do
		local mine = state.Mine == id
		local won = state.Winner == id
		card.stroke.Thickness = (mine or won) and BORDER + 2 or BORDER
		local lift = (mine or won) and LIFT_SELECTED
			or ((hovered == id and not state.Winner) and LIFT_HOVER or 0)
		TweenService:Create(card.face, QUICK, { Position = UDim2.fromOffset(-lift, -lift) }):Play()
		card.mineTag.Visible = mine and not state.Winner
		if won and not card.pickedTag.Visible then
			card.pickedTag.Visible = true
			card.pickedPop.Scale = 1.6
			TweenService:Create(card.pickedPop, POP, { Scale = 1 }):Play()
		end
		card.wash.Visible = state.Winner ~= nil and not won
		for _, c in ipairs(card.votesRow:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		-- (2026-10-18, team mode) more than two voters do not fit a card's row by name: YOU, then "+N" for the rest
		local crowd = #state.Players > 2
		local rest = 0
		for order, row in ipairs(state.Players) do
			if state.Picks[row.UserId] == id then
				local me = row.UserId == player.UserId
				if crowd and not me then
					rest += 1
				else
					local label = me and "YOU" or string.upper(string.sub(row.Name or "?", 1, 14))
					local face = chip(card.votesRow, label, UDim2.new(), me, 24 + 10 * #label, 34, 15)
					face.LayoutOrder = me and 0 or order
				end
			end
		end
		if rest > 0 then
			local label = "+" .. rest
			local face = chip(card.votesRow, label, UDim2.new(), false, 24 + 10 * #label, 34, 15)
			face.LayoutOrder = 100
		end
	end
end

local function clearCards()
	for _, card in pairs(cards) do card.holder:Destroy() end
	cards = {}
	cardPops = {}
	hovered = nil
end

local function pick(id)
	if not (state and open) or state.Winner or state.Mine == id or not cards[id] then return end
	state.Mine = id                 -- shown straight away; the server's tally confirms it
	hubRemote:FireServer("vote", state.Id, id)
	local card = cards[id]
	card.face.Position = UDim2.fromOffset(2, 2)
	task.delay(0.07, paint)
	paint()
end

local function buildCards(maps)
	clearCards()
	local n = math.max(1, #maps)
	local w = math.floor((DESIGN_W - CARD_GAP * (n - 1)) / n)
	local h = CARD_BOTTOM - CARD_TOP
	for i, m in ipairs(maps) do
		local holder, face, stroke = slab(panel, UDim2.fromOffset(w, h),
			UDim2.fromOffset((i - 1) * (w + CARD_GAP), CARD_TOP), ACCENT[m.Accent] or C.Card, 3)
		local fw, fh = w - SHADOW, h - SHADOW
		halftone(face, 0.84, C.Ink, 10, UDim2.fromOffset(fw, 110), UDim2.fromOffset(0, fh - 110))

		-- the picture, in an ink frame
		local tw = fw - 32
		local th = math.min(math.floor(tw * 9 / 16), fh - 146)
		local frame = make("Frame", {
			Name = "Picture", BackgroundColor3 = C.Track, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 16),
			Size = UDim2.fromOffset(tw, th), ZIndex = 4, ClipsDescendants = true,
		}, face)
		outline(frame, 3)
		if type(m.Image) == "string" and m.Image ~= "" then
			make("ImageLabel", {
				BackgroundTransparency = 1, Image = m.Image, ScaleType = Enum.ScaleType.Crop,
				Size = UDim2.fromScale(1, 1), ZIndex = 5,
			}, frame)
		else
			halftone(frame, 0.72, C.Ink, 12, nil, nil, 5)
		end

		-- five maps make narrow cards: the title shrinks to its card (never above 42) instead of running off it
		local titleFace, titleExtrude = display(face, {
			Text = m.Name or m.Id, TextSize = 42, TextScaled = true, TextWrapped = true,
			Position = UDim2.fromOffset(18, th + 28), Size = UDim2.fromOffset(fw - 36, 48), ZIndex = 6,
		}, 4, C.CreamText, C.Ink, 2)
		for _, l in ipairs({ titleFace, titleExtrude }) do
			make("UITextSizeConstraint", { MaxTextSize = 42 }, l)
		end
		mono(face, {
			Text = m.Sub or "", TextSize = 16, Position = UDim2.fromOffset(20, th + 80),
			Size = UDim2.fromOffset(fw - 40, 20), ZIndex = 6, TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local votesRow = make("Frame", {
			Name = "Votes", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, fh - 50),
			Size = UDim2.fromOffset(fw - 32, 36), ZIndex = 8,
		}, face)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		}, votesRow)

		local mineTag = sticker(face, "YOUR VOTE", UDim2.fromOffset(92, 22), 132)
		local pickedTag, pickedPop = sticker(face, "PICKED!", UDim2.fromOffset(fw / 2, 16 + th / 2), 220, C.Red, 34)
		pickedTag.Size = UDim2.fromOffset(220, 44)
		local wash = make("Frame", {
			Name = "Wash", BackgroundColor3 = C.Paper, BackgroundTransparency = 0.35, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 45, Visible = false,
		}, face)
		corner(wash, RADIUS)

		local card = {
			map = m, holder = holder, face = face, stroke = stroke, votesRow = votesRow,
			mineTag = mineTag, pickedTag = pickedTag, pickedPop = pickedPop, wash = wash,
		}
		card.hit = hitbox(face)
		card.hit.Activated:Connect(function() pick(m.Id) end)
		card.hit.MouseEnter:Connect(function()
			hovered = m.Id
			paint()
		end)
		card.hit.MouseLeave:Connect(function()
			if hovered == m.Id then hovered = nil end
			paint()
		end)
		cards[m.Id] = card
		cardPops[#cardPops + 1] = make("UIScale", {}, holder)
	end
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local function closeOther(guiName)
	local g = playerGui:FindFirstChild(guiName)
	local c = g and g:FindFirstChild("Command")
	if c then c:Fire("close") end
end

local function setOpen(v)
	if v == open then return end
	open = v
	if v then
		closeOther("QuickPlay")          -- a match found from Quick Play would otherwise sit under the vote
		closeOther("LoadoutMenu")
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		dots.ImageTransparency = 1
		TweenService:Create(backdrop, TweenInfo.new(0.16), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(dots, TweenInfo.new(0.16), { ImageTransparency = DOT_ALPHA }):Play()
		local all = {}
		for _, s in ipairs(popTargets) do all[#all + 1] = s end
		for _, s in ipairs(cardPops) do all[#all + 1] = s end
		for i, s in ipairs(all) do
			s.Scale = 0.86
			task.delay((i - 1) * 0.045, function()
				if open then TweenService:Create(s, POP, { Scale = 1 }):Play() else s.Scale = 1 end
			end)
		end
		-- first person re-locks the mouse every frame; win it back while the vote is up
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		backdrop.Visible = false
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
	end
end

----------------------------------------------------------------------------------------------------
-- the clock
----------------------------------------------------------------------------------------------------
local shown = nil
RunService.Heartbeat:Connect(function()
	if not (open and state) then return end
	local text
	if state.Winner then
		text = "GO!"
	elseif state.Called then
		text = "--"
	else
		text = tostring(math.max(0, math.ceil(state.EndsAt - os.clock())))
	end
	if text ~= shown then
		shown = text
		timerText.Text = text
		timerText.TextSize = (#text > 2) and 40 or 54
		local urgent = not state.Winner and tonumber(text) and tonumber(text) <= 3
		timerStroke.Color = urgent and C.Red or C.Ink
		timerText.TextColor3 = urgent and C.Red or C.Ink
	end
end)

----------------------------------------------------------------------------------------------------
-- the server
----------------------------------------------------------------------------------------------------
local function nameOf(id)
	for _, m in ipairs(state and state.Maps or {}) do
		if m.Id == id then return m.Name or id end
	end
	return tostring(id)
end

hubRemote.OnClientEvent:Connect(function(what, a, b, c)
	if what == "vote" and type(a) == "table" then
		state = {
			Id = a.Id, Kind = a.Kind, Maps = a.Maps or {}, Players = a.Players or {},
			EndsAt = os.clock() + (tonumber(a.Seconds) or 10), Picks = {}, Mine = nil, Winner = nil,
		}
		shown = nil
		local solo = a.Kind == "Solo"
		local team = a.Kind == "Team"       -- Quick Play's team match (2026-10-18, team mode)
		local mine = nil
		for _, row in ipairs(state.Players) do
			if row.UserId == player.UserId then mine = row.Team end
		end
		local size = math.max(1, math.floor(#state.Players / 2))
		kindText.Text = solo and "SOLO TEST" or (team and ("TEAMS · %dv%d"):format(size, size)) or "DUEL · 1v1"
		local others, allies = {}, {}
		for _, row in ipairs(state.Players) do
			if row.UserId ~= player.UserId then
				local name = string.upper(row.Name or "?")
				if team and row.Team == mine then allies[#allies + 1] = name else others[#others + 1] = name end
			end
		end
		local you = (#allies > 0) and ("YOU + " .. table.concat(allies, ", ")) or "YOU"
		versus.Text = (#others > 0) and (you .. "  vs  " .. table.concat(others, ", ")) or ""
		note.TextColor3 = C.LockedInk
		note.Text = solo and "Pick the map for your solo test."
			or "Click a map to vote -- you can change it until the clock runs out. Most votes wins; a tie is a coin flip."
		buildCards(state.Maps)
		open = false
		setOpen(true)
		paint()
	elseif what == "voteTally" and state and a == state.Id then
		state.Picks = {}
		for _, row in ipairs(type(b) == "table" and b or {}) do
			state.Picks[row.UserId] = row.Map
		end
		state.Mine = state.Picks[player.UserId] or state.Mine
		paint()
	elseif what == "voteResult" and state and a == state.Id then
		note.TextColor3 = C.Ink
		if b then
			state.Winner = b
			local name = nameOf(b)
			note.Text = (c == "tie") and ("A tie -- the coin flip picked " .. name .. ".")
				or (c == "none") and ("Nobody voted, so the coin flip picked " .. name .. ".")
				or (name .. " it is.")
		else
			state.Called = true
			note.TextColor3 = C.Red
			note.Text = (state.Kind == "Team") and "A player left the map vote: you are back in the queue."   -- (2026-10-18 review)
				or (c == "left") and "The duel is off: your opponent left the game." or "The vote was called off."
			local id = state.Id
			task.delay(2.5, function()
				if state and state.Id == id then setOpen(false) end
			end)
		end
		paint()
	end
end)

command.Event:Connect(function(what, a)
	if what == "close" then
		setOpen(false)
	elseif what == "pick" then
		pick(a)
	end
end)

----------------------------------------------------------------------------------------------------
-- fit (Quick Play's: sized off the ScreenGui, the bigger of "below the topbar" and "beside its buttons")
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
	local below = math.min(s.X * 0.95 / DESIGN_W, (s.Y - topH) * 0.9 / DESIGN_H)
	local beside = math.min((s.X - 2 * (leftW + 8)) / DESIGN_W, s.Y * 0.9 / DESIGN_H)
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
