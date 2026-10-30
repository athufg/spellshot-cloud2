--[[
	HubBoards  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubBoards

	THE HUB'S BOARDS come alive (2026-10-25, the owner's hub-rebuild brief, steps 5 and 6; every screen, 2026-10-27). Client
	only, runs only while HubLife.On(). In the REACTIONS board's newsprint kit (HubLifeKit).

	ONE PANEL FOR EVERY BOARD (2026-10-27, the owner: "no screen in the hub is a blank black panel", all of them in TOP
	DUELISTS' style). Every board's frame and header are the hub's own mesh; its black face is a few triangles of the merged
	OBS_Screen_Dark_01 (measured 2026-10-27: centre, the normal toward the room, the in-plane up). board() lays a SurfaceGui
	on an invisible part on that face: the paper, its halftone dot, rounded corners, all at TOP DUELISTS' physical sizes
	(its 40 px a stud; a board drawn finer scales every px by PPS / 40). emptyCard() is TOP DUELISTS' empty state (the card
	slab, the LuckiestGuy headline with its extrude, one GothamBold line: what will show + why it is empty now), widened
	and fitted on a narrower board.

	  TOP DUELISTS   the Duels room's centre board. Rows: rank, the duellist's name, their Element chip, their wins.
	                 NO FAKE DATA. The only source read is a "DuelWins" number attribute on each player, which nothing sets
	                 yet: PlayerData keeps Stats.Wins privately (2026-10-25). Until the backend publishes it the board shows
	                 its honest empty state. BACKEND NEEDED (flagged to the owner): (1) PlayerData sets player attribute
	                 DuelWins = Stats.Wins on load and after AwardMatch -> this board then ranks the server's players; (2) for
	                 an all-time / season board, an OrderedDataStore of wins written at AwardMatch and read here through a
	                 server remote. There is no rating system to show.
	  LONGEST STREAK (2026-10-27) the board right of it (as you face them). Nothing tracks win streaks (PlayerData's Stats
	                 are Wins / Losses / Draws / RoundsWon only), so: the designed empty state. BACKEND NEEDED: a current
	                 and best streak in Stats, set at AwardMatch, published as player attributes -> rows like TOP DUELISTS'.
	  LIVE DUELS     (2026-10-27) the board left of it. REAL, live: every match DuelMatch runs, read from the attributes it
	                 already sets on each player (DuelMatch = the match's id, MatchTeam A / B, RoundsWon) and HubServer's
	                 Map. A row: the duellists (a team match: the first name + the rest's count), their Element chips (1v1),
	                 the map, the score. Nobody in a match: the empty state. (A duel's pad is not published, so not shown.)
	  DAILY DEALS    (2026-10-27) upstairs in the Store. REAL: the Shop's own TODAY'S DROP (StarterGui.SpellshotShop's
	                 Catalog.DAILY: the featured pick + 3 more, with the Catalog's name, kind, Element, rarity and price,
	                 drawn with the shop's CardKit.price), and the Shop's refresh countdown (CardKit.countdown, to 00:00 UTC).
	                 Re-read every second, so a new rotation shows when the Catalog changes.
	  THE PLACARDS   (2026-10-27) the small wayfinding signs: the DUELS and LOADOUT hex plaques side by side on the pillar
	                 between the two archways, the second LOADOUT plaque across the Loadout arch, and the tall DUELS banner by
	                 the Training doorway. Each face shows the Interact key and what it does, and each is an in-world button:
	                 a ProximityPrompt (the hub's own: hold 0.2, reach 12, no line of sight; inside the hub model, so
	                 HubClient applies the player's Interact bind and HubPrompts draws it) that runs EXACTLY the top-right
	                 menu's flow: DUELS = the PLAY chip (QuickPlay's Command "open"), LOADOUT = the LOADOUT chip (out of a
	                 match the Altar showcase chamber when it is Ready, else the Loadout menu: LoadoutMenu's chipHit).
	  VS CARD        over a duel pad the moment both halves are taken: a comic panel split in the two duellists' Element
	                 colours, their names, a VS burst between. Read from the players' own positions with the server's rule
	                 (HubServer padOf: within 6.5 studs of the pad's centre, -1..9 above it; the half is which side of the
	                 pad's axis), so it needs no backend; it may show for a moment for someone the server is still moving
	                 into a vote. The pads already light each half in its player's Element colour (HubServer).
	Not drawn here: the REACTIONS TV (ReactionsBoard), the duel pads' post screens (HubServer's PadScreen), the Loadout
	altar's slot floors (HubLoadoutCounter); the TRAINING banner and the TRENDING screen are cut whole by the hub-polish
	mesh cut (hub/hub_polish_2026_10_27, rev 3).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
local K = require(spell:WaitForChild("HubLifeKit"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Board = {
		-- the face's measured corners (OBS_Screen_Dark_01): x 7985.45..8014.55, top edge y 20.40 at z 8120.95, bottom edge
		-- y 11.59 at z 8122.82; the cut corners take ~1.3 studs at the top, ~2.3 at the bottom
		Centre = Vector3.new(8000, 15.995, 8121.885),
		Up = Vector3.new(0, 8.81, -1.87).Unit,
		N = Vector3.new(0, -1.87, -8.81).Unit,
		Size = Vector2.new(27.6, 8.0),
		PPS = 40,
		Rows = 8,
		Refresh = 2,
	},
	-- (2026-10-27) the other faces, measured from OBS_Screen_Dark_01's triangles: Centre = the black face's centre, N = its
	-- normal toward the room, Size = the panel (inside the white frame, clear of the cut corners), Lift = the panel's
	-- centre above the face's (the plaques' and the banner's faces end in a point at the bottom)
	Streak = { Centre = Vector3.new(8025.777, 14.487, 8114.594), N = Vector3.new(-0.599, -0.174, -0.781),     -- face 14.1 x 9.0
		Size = Vector2.new(12.6, 8.0), PPS = 40 },
	Live = { Centre = Vector3.new(7974.221, 14.488, 8114.595), N = Vector3.new(0.600, -0.174, -0.781),         -- face 14.1 x 9.0
		Size = Vector2.new(12.6, 8.0), PPS = 40, Rows = 3, Refresh = 1 },
	Deals = { Centre = Vector3.new(8070.514, 18.417, 8024.490), N = Vector3.new(-0.861, -0.105, -0.497),      -- face 9.4 x 5.4
		Size = Vector2.new(8.6, 4.6), PPS = 60, Refresh = 1 },
	Placards = {
		-- face 3.6 x 4.6, pointed at the bottom
		{ Name = "DuelsPlaque", Kind = "Duels", Centre = Vector3.new(7970.05, 7.71, 8039.49), N = Vector3.new(0.598, -0.139, -0.789) },
		{ Name = "LoadoutPlaque", Kind = "Loadout", Centre = Vector3.new(7965.32, 7.71, 8035.42), N = Vector3.new(0.693, -0.139, -0.707) },
		{ Name = "LoadoutPlaque2", Kind = "Loadout", Centre = Vector3.new(7955.31, 7.71, 7978.59), N = Vector3.new(0.893, -0.139, 0.427) },
		-- face 1.9 x 6.4, pointed at the bottom
		{ Name = "DuelsBanner", Kind = "Duels", Tall = true, Centre = Vector3.new(8030.57, 4.46, 8051.55), N = Vector3.new(-0.990, -0.139, 0.031),
			Size = Vector2.new(1.56, 5.0), Lift = 0.43 },
	},
	Placard = { Size = Vector2.new(3.1, 3.5), Lift = 0.32, PPS = 80, MaxDistance = 300,   -- (2026-10-27) was 120: never a black face in view
		-- the prompt: HubServer's prompt() numbers; its anchor out in front of the face's lower part
		Hold = 0.2, Reach = 12, Out = 1.4, Down = 1.6 },
	Pads = { Count = 9, Radius = 6.5, Above = 8.5, Every = 0.2, Size = Vector2.new(11, 4.2) },
	LiveRed = Color3.fromRGB(255, 86, 74),
}

local folder = Instance.new("Folder")
folder.Name = "HubLife_Boards"
folder.Parent = workspace

----------------------------------------------------------------------------------------------------
-- THE PANEL: TOP DUELISTS' component, for every board (2026-10-27)
----------------------------------------------------------------------------------------------------
local function textW(str, size, font)
	return TextService:GetTextSize(str, size, font, Vector2.new(100000, 100000)).X
end

--- a board on a measured face: the invisible part, the SurfaceGui, the paper with its dots. Returns
--- { Name, Screen, Gui, Paper, List (the content frame), W, H (px), px (TOP DUELISTS' px -> this board's), N, Up, At }
local function board(name, B)
	local n = B.N.Unit
	local up = B.Up or Vector3.yAxis
	up = (up - n * up:Dot(n)).Unit
	local s = B.PPS / 40
	local function px(v) return math.floor(v * s + 0.5) end
	local at = B.Centre + up * (B.Lift or 0)
	local screen = Instance.new("Part")
	screen.Name = "HubLife_" .. name .. "Screen"
	screen.Anchored, screen.CanCollide, screen.CanQuery, screen.CanTouch, screen.CastShadow = true, false, false, false, false
	screen.Transparency = 1
	screen.Size = Vector3.new(B.Size.X, B.Size.Y, 0.05)
	screen.CFrame = CFrame.fromMatrix(at + n * 0.06, n:Cross(up), up)
	screen.Parent = folder
	local W, H = math.floor(B.Size.X * B.PPS + 0.5), math.floor(B.Size.Y * B.PPS + 0.5)
	-- (2026-10-27, verify pass) MaxDistance past the hub's whole span: at 160 TOP DUELISTS went back to a black face for anyone
	-- looking through the DUELS arch from the Store-gate side of the plaza (~166 studs away)
	local sg = K.make("SurfaceGui", { Name = "HubLife" .. name, Face = Enum.NormalId.Front, Adornee = screen, LightInfluence = 0,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = B.PPS, MaxDistance = B.MaxDistance or 300, ResetOnSpawn = false }, playerGui)
	local paper = K.make("Frame", { Name = "Paper", BackgroundColor3 = K.C.Paper, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, sg)
	K.corner(paper, px(18))
	K.halftone(paper, 0.86, K.C.Ink, px(12), 1)
	local list = K.make("Frame", { Name = "Rows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, paper)
	return { Name = name, Screen = screen, Gui = sg, Paper = paper, List = list, W = W, H = H, px = px, N = n, Up = up, At = at }
end

local function clear(b)
	for _, c in ipairs(b.List:GetChildren()) do c:Destroy() end
end

local EXTRUDE = K.C.Card:Lerp(K.C.Ink, 0.28)

--- TOP DUELISTS' empty state: a card slab 62% x 60% of the board, centred; the headline in LuckiestGuy (64 px at 40 a
--- stud) over its extrude; one GothamBold line in LockedInk. On a narrower board the card widens (to 92%) and then the
--- headline shrinks until it fits one line; the card grows to fit the line.
local function emptyCard(b, title, line)
	clear(b)
	local px, W, H = b.px, b.W, b.H
	local tSize, lSize, pad, shadow = px(64), px(26), px(28), px(10)
	local w = math.floor(W * 0.62)
	local need = textW(title, tSize, Enum.Font.LuckiestGuy) + 2 * pad + shadow + px(8)
	if need > w then w = math.min(math.floor(W * 0.92), need) end
	local inner = w - shadow - 2 * pad
	while tSize > px(20) and textW(title, tSize, Enum.Font.LuckiestGuy) > inner - px(4) do tSize -= 2 end
	local titleH = math.floor(tSize * 76 / 64 + 0.5)
	local lineY = px(18) + titleH + px(10)
	local lineH = TextService:GetTextSize(line, lSize, Enum.Font.GothamBold, Vector2.new(inner, 100000)).Y
	local h = math.min(math.floor(H * 0.94), math.max(math.floor(H * 0.6), lineY + lineH + px(16) + shadow))
	local _, face = K.slab(b.List, UDim2.fromOffset(w, h), UDim2.fromOffset(math.floor((W - w) / 2), math.floor((H - h) / 2)), K.C.Card, 3,
		shadow, px(4), px(6))
	K.display(face, { Name = "Title", Text = title, TextSize = tSize, Position = UDim2.fromOffset(pad, px(18)),
		Size = UDim2.new(1, -2 * pad, 0, titleH), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 }, px(4), K.C.Ink, EXTRUDE)
	K.make("TextLabel", { Name = "Line", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = lSize, TextWrapped = true,
		TextColor3 = K.C.LockedInk, Text = line, Position = UDim2.fromOffset(pad, lineY), Size = UDim2.new(1, -2 * pad, 1, -lineY - px(16)),
		ZIndex = 6 }, face)
	b.Gui:SetAttribute("State", "Empty")
end

----------------------------------------------------------------------------------------------------
-- TOP DUELISTS
----------------------------------------------------------------------------------------------------
do
	local B = Tuning.Board
	local b = board("TopDuelists", B)
	local W, H = b.W, b.H
	local function empty()
		emptyCard(b, "NO DUEL RESULTS YET", "Duel wins show here once they are saved. (Leaderboard backend not built yet.)")
		folder:SetAttribute("BoardRows", 0)
	end
	local function rows(entries)
		clear(b)
		local cols, perCol = 2, math.ceil(B.Rows / 2)
		local pad, gap = 26, 14
		local cw = math.floor((W - pad * 2 - gap) / cols)
		local rh = math.floor((H - pad * 2 - gap * (perCol - 1)) / perCol)
		for i, e in ipairs(entries) do
			if i > B.Rows then break end
			local col, row = math.floor((i - 1) / perCol), (i - 1) % perCol
			local x, y = pad + col * (cw + gap), pad + row * (rh + gap)
			local _, face = K.slab(b.List, UDim2.fromOffset(cw, rh), UDim2.fromOffset(x, y), K.C.Card, 3, 6, 3, 4)
			local badge = K.make("Frame", { BackgroundColor3 = (i <= 3) and K.C.Gold or K.C.Ink, BorderSizePixel = 0,
				Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(rh - 18, rh - 18), ZIndex = 6 }, face)
			K.corner(badge, (rh - 18) // 2)
			K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = tostring(i),
				TextColor3 = (i <= 3) and K.C.Ink or K.C.CreamText, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, badge)
			local nx = rh + 2
			K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				Text = e.Name, TextColor3 = K.C.Ink, Position = UDim2.fromOffset(nx, 6), Size = UDim2.new(1, -nx - 240, 1, -18), ZIndex = 6 }, face)
			if e.Element then K.chip(face, e.Element, cw - 236, 8, 130, rh - 22, 15, 6) end
			K.display(face, { Text = tostring(e.Wins) .. " W", TextSize = 40, Position = UDim2.fromOffset(cw - 98, 2),
				Size = UDim2.fromOffset(84, rh - 12), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 }, 2, K.C.Ink, EXTRUDE)
		end
		b.Gui:SetAttribute("State", "Rows")
		folder:SetAttribute("BoardRows", math.min(#entries, B.Rows))
	end
	local last = nil
	task.spawn(function()
		while folder.Parent do
			local entries = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local w = p:GetAttribute("DuelWins")
				if type(w) == "number" then
					entries[#entries + 1] = { Name = p.DisplayName, Wins = math.floor(w), Element = p:GetAttribute("Element") }
				end
			end
			table.sort(entries, function(a, c) return a.Wins > c.Wins or (a.Wins == c.Wins and a.Name < c.Name) end)
			local key = #entries
			for _, e in ipairs(entries) do key = key .. "|" .. e.Name .. ":" .. e.Wins .. ":" .. tostring(e.Element) end
			if key ~= last then
				last = key
				if #entries == 0 then empty() else rows(entries) end
			end
			task.wait(B.Refresh)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- LONGEST STREAK (2026-10-27): nothing tracks streaks yet, so its designed empty state
----------------------------------------------------------------------------------------------------
do
	local b = board("LongestStreak", Tuning.Streak)
	emptyCard(b, "NO STREAKS YET", "Win streaks show here once they are tracked. (Streak tracking not built yet.)")
end

----------------------------------------------------------------------------------------------------
-- LIVE DUELS (2026-10-27): every running match, from the attributes DuelMatch and HubServer already set
----------------------------------------------------------------------------------------------------
do
	local L = Tuning.Live
	local b = board("LiveDuels", L)
	local okM, MapRegistry = pcall(require, spell:WaitForChild("MapRegistry", 10))
	if not okM then MapRegistry = nil end
	local function nameOf(p) return string.upper(p.DisplayName) end
	local function matches()
		local byId = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local id = p:GetAttribute("DuelMatch")
			if id ~= nil then
				local m = byId[id]
				if not m then
					m = { Id = id, A = {}, B = {} }
					byId[id] = m
				end
				local side = (p:GetAttribute("MatchTeam") == "B") and m.B or m.A
				side[#side + 1] = p
			end
		end
		local list = {}
		for _, m in pairs(byId) do
			local byName = function(x, y) return x.DisplayName < y.DisplayName end
			table.sort(m.A, byName)
			table.sort(m.B, byName)
			local a1, b1 = m.A[1], m.B[1]
			local function side(t) return (#t == 0 and "?") or (#t == 1 and nameOf(t[1])) or (nameOf(t[1]) .. " +" .. (#t - 1)) end
			m.Title = side(m.A) .. "  VS  " .. side(m.B)
			m.Team = #m.A > 1 or #m.B > 1
			if not m.Team then
				m.ElA = a1 and a1:GetAttribute("Element")
				m.ElB = b1 and b1:GetAttribute("Element")
			end
			local wa = (a1 and a1:GetAttribute("RoundsWon")) or (b1 and b1:GetAttribute("RoundsLost")) or 0
			local wb = (b1 and b1:GetAttribute("RoundsWon")) or (a1 and a1:GetAttribute("RoundsLost")) or 0
			m.Score = tostring(wa) .. "-" .. tostring(wb)
			local mapId = (a1 and a1:GetAttribute("Map")) or (b1 and b1:GetAttribute("Map"))
			local map = mapId and MapRegistry and MapRegistry.Get(mapId)
			local where = (map and map.Name) or (mapId and string.upper(tostring(mapId))) or "STARTING"
			m.Where = m.Team and (("TEAM %dV%d  ·  %s"):format(#m.A, #m.B, where)) or where
			m.Key = table.concat({ tostring(m.Id), m.Title, tostring(m.ElA), tostring(m.ElB), m.Score, m.Where }, "|")
			list[#list + 1] = m
		end
		table.sort(list, function(x, y)
			if type(x.Id) == "number" and type(y.Id) == "number" then return x.Id < y.Id end
			return tostring(x.Id) < tostring(y.Id)
		end)
		return list
	end
	local function rows(list)
		clear(b)
		local px, W, H = b.px, b.W, b.H
		local pad, gap = px(22), px(12)
		local per = L.Rows
		local rh = math.floor((H - 2 * pad - gap * (per - 1)) / per)
		local fw, fh = W - 2 * pad - px(6), rh - px(6)
		for i = 1, math.min(#list, per) do
			local m = list[i]
			local y = pad + (i - 1) * (rh + gap)
			local _, face = K.slab(b.List, UDim2.fromOffset(W - 2 * pad, rh), UDim2.fromOffset(pad, y), K.C.Card, 3, px(6), px(3), px(4))
			if i == per and #list > per then
				K.display(face, { Text = "+" .. (#list - per + 1) .. " MORE DUELS RUNNING", TextSize = px(28), Position = UDim2.fromOffset(px(12), px(4)),
					Size = UDim2.new(1, -px(24), 1, -px(8)), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 }, px(2), K.C.Ink, EXTRUDE)
				break
			end
			local scoreW = px(84)
			-- the duellists
			K.make("TextLabel", { Name = "Who", BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left, Text = m.Title, TextColor3 = K.C.Ink, Position = UDim2.fromOffset(px(10), px(5)),
				Size = UDim2.fromOffset(fw - px(20) - scoreW, math.floor(fh * 0.44)), ZIndex = 6 }, face)
			-- LIVE, their Elements, the map
			local y2 = math.floor(fh * 0.52)
			local ch = fh - y2 - px(6)
			local x = px(10)
			local live = K.make("Frame", { Name = "Live", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y2),
				Size = UDim2.fromOffset(px(46), ch), ZIndex = 6 }, face)
			K.corner(live, px(4))
			K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "LIVE", TextSize = px(13),
				TextColor3 = Tuning.LiveRed, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, live)
			x += px(46) + px(6)
			if m.ElA or m.ElB then
				local cw = px(84)
				K.chip(face, m.ElA or "?", x, y2, cw, ch, px(12), 6)
				x += cw
				K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "VS", TextSize = px(12), TextColor3 = K.C.Ink,
					Position = UDim2.fromOffset(x, y2), Size = UDim2.fromOffset(px(24), ch), ZIndex = 6 }, face)
				x += px(24)
				K.chip(face, m.ElB or "?", x, y2, cw, ch, px(12), 6)
				x += cw + px(8)
			end
			K.make("TextLabel", { Name = "Where", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = px(14),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = m.Where, TextColor3 = K.C.LockedInk,
				Position = UDim2.fromOffset(x, y2), Size = UDim2.fromOffset(math.max(0, fw - x - scoreW - px(4)), ch), ZIndex = 6 }, face)
			-- the score (rounds won)
			K.display(face, { Name = "Score", Text = m.Score, TextSize = px(40), Position = UDim2.fromOffset(fw - scoreW - px(8), px(2)),
				Size = UDim2.fromOffset(scoreW, fh - px(4)), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 }, px(2), K.C.Ink, EXTRUDE)
		end
		b.Gui:SetAttribute("State", "Rows")
	end
	local last = nil
	task.spawn(function()
		while folder.Parent do
			local list = matches()
			local key = tostring(#list)
			for _, m in ipairs(list) do key = key .. "#" .. m.Key end
			if key ~= last then
				last = key
				if #list == 0 then
					emptyCard(b, "NO DUELS RUNNING", "Duels in progress show here live, with the score. (Nobody is duelling right now.)")
				else
					rows(list)
				end
				folder:SetAttribute("LiveDuels", #list)
			end
			task.wait(L.Refresh)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- DAILY DEALS (2026-10-27): the Shop's own TODAY'S DROP and its countdown
----------------------------------------------------------------------------------------------------
task.spawn(function()
	local D = Tuning.Deals
	local b = board("DailyDeals", D)
	local shop = playerGui:WaitForChild("SpellshotShop", 30)
	local catMod = shop and shop:WaitForChild("Catalog", 10)
	local okC, Cat = false, nil
	if catMod then okC, Cat = pcall(require, catMod) end
	if not okC or type(Cat) ~= "table" or type(Cat.DAILY) ~= "table" or type(Cat.BYID) ~= "table" then
		emptyCard(b, "NO DEALS RIGHT NOW", "Today's Drop shows here once the Shop's catalog loads.")
		return
	end
	local ckMod = shop:FindFirstChild("CardKit")
	local okK, CK = false, nil
	if ckMod then okK, CK = pcall(require, ckMod) end
	if not okK or type(CK) ~= "table" then CK = nil end
	local function countdown()
		if CK and CK.countdown then return CK.countdown(os.time()) end
		local left = 86400 - (math.floor(os.time()) % 86400)
		return ("%dH %02dM %02dS"):format(left // 3600, (left % 3600) // 60, left % 60)
	end
	--- the currency's mark and the amount: the shop's own CardKit.price (Robux glyph / Sparks mark, GothamBlack)
	local function price(parent, x, y, p, size, z)
		if type(p) ~= "table" then return end
		if CK and CK.price then
			local ok = pcall(CK.price, parent, x, y, p, size, K.C.Ink, z)
			if ok then return end
		end
		local n = tostring(p[2] or "")
		K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = size, TextXAlignment = Enum.TextXAlignment.Left,
			Text = (p[1] == "Robux") and ("R$ " .. n) or (n .. " SPARKS"), TextColor3 = K.C.Ink, Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(200, size + 6), ZIndex = z }, parent)
	end
	local timeLabel = nil
	local function build(items)
		clear(b)
		local W, H = b.W, b.H
		local pad, gap = 15, 12
		-- the countdown strip (the Shop's "NEW ITEMS IN")
		local sh = 46
		local _, strip = K.slab(b.List, UDim2.fromOffset(W - 2 * pad, sh), UDim2.fromOffset(pad, H - pad - sh), K.C.Pill, 3, 6, 4, 5)
		K.make("TextLabel", { BackgroundTransparency = 1, FontFace = K.MONO, TextSize = 18, TextColor3 = K.C.LockedInk, Text = "NEW ITEMS IN",
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(140, sh - 6), ZIndex = 6 }, strip)
		timeLabel = K.make("TextLabel", { Name = "Time", BackgroundTransparency = 1, FontFace = K.MONO, TextSize = 24, TextColor3 = K.C.Ink,
			Text = countdown(), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(150, 0), Size = UDim2.fromOffset(190, sh - 6),
			ZIndex = 6 }, strip)
		K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = K.C.LockedInk,
			Text = "TODAY'S DROP", TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, -14, 1, 0), ZIndex = 6 }, strip)
		-- the featured pick
		local top = H - pad - sh - gap - pad
		local fwide = 320
		local it = items[1]
		local _, face = K.slab(b.List, UDim2.fromOffset(fwide, top), UDim2.fromOffset(pad, pad), K.C.Card, 3, 9, 4, 6)
		local fw = fwide - 9
		local sticker = K.make("Frame", { Name = "Sticker", BackgroundColor3 = K.C.Gold, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6 }, face)
		K.corner(sticker, 4)
		K.outline(sticker, 3)
		K.make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, sticker)
		K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextSize = 20, Text = "TODAY'S PICK", TextColor3 = K.C.Ink,
			Size = UDim2.new(0, 0, 1, 2), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7 }, sticker)
		K.rarityChip(face, it.rarity, 12 + textW("TODAY'S PICK", 20, Enum.Font.LuckiestGuy) + 18 + 10, 13, 24, 15, 6)
		local name = string.upper(tostring(it.name))
		local nSize = 40
		while nSize > 18 and textW(name, nSize, Enum.Font.LuckiestGuy) > fw - 30 do nSize -= 2 end
		K.display(face, { Name = "ItemName", Text = name, TextSize = nSize, Position = UDim2.fromOffset(12, 48), Size = UDim2.fromOffset(fw - 24, 44),
			ZIndex = 6 }, 3, K.C.Ink, EXTRUDE)
		K.chip(face, it.el, 12, 100, 130, 30, 16, 6)
		K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = K.C.LockedInk,
			Text = string.upper(tostring(it.kind or "")), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(152, 100),
			Size = UDim2.fromOffset(fw - 164, 30), ZIndex = 6 }, face)
		price(face, 12, top - 9 - 44, it.price, 26, 7)
		-- the 3 more
		local cx = pad + fwide + gap
		local cw = W - pad - cx
		K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = K.C.LockedInk, Text = "ALSO TODAY",
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(cx + 2, pad - 2), Size = UDim2.fromOffset(cw, 20), ZIndex = 4 }, b.List)
		local y0, rgap = pad + 23, 8
		local rh = math.floor((top - 23 - rgap * 2) / 3)
		for i = 2, math.min(4, #items) do
			local o = items[i]
			local _, rf = K.slab(b.List, UDim2.fromOffset(cw, rh), UDim2.fromOffset(cx, y0 + (i - 2) * (rh + rgap)), K.C.Card, 3, 5, 3, 4)
			K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.upper(tostring(o.name)), TextColor3 = K.C.Ink, Position = UDim2.fromOffset(7, 3), Size = UDim2.fromOffset(cw - 5 - 26, 19),
				ZIndex = 6 }, rf)
			local R = K.Rarity[o.rarity]
			if R then
				-- the rarity as a thin rung down the card's right edge (the shop's colour; the word is the featured card's job)
				K.make("Frame", { Name = "Rung", BackgroundColor3 = R.Color, BorderSizePixel = 0, Position = UDim2.new(1, -12, 0, 6),
					Size = UDim2.new(0, 6, 1, -12), ZIndex = 6 }, rf)
			end
			price(rf, 7, 21, o.price, 16, 7)
		end
		b.Gui:SetAttribute("State", "Deal")
		folder:SetAttribute("Deal", tostring(it.id))
	end
	local last = nil
	while folder.Parent do
		local ids = Cat.DAILY.ids or {}
		local items = {}
		for _, id in ipairs(ids) do
			local it = Cat.BYID[id]
			if it then items[#items + 1] = it end
		end
		local key = table.concat(ids, ",")
		if key ~= last then
			last = key
			if #items == 0 then
				timeLabel = nil
				emptyCard(b, "NO DEALS RIGHT NOW", "Today's Drop shows here once the Shop lists one. (The Shop has no pick today.)")
			else
				build(items)
			end
		end
		if timeLabel then timeLabel.Text = countdown() end
		task.wait(D.Refresh)
	end
end)

----------------------------------------------------------------------------------------------------
-- THE PLACARDS (2026-10-27): the DUELS / LOADOUT wayfinding signs, as in-world buttons
----------------------------------------------------------------------------------------------------
-- exactly the top-right chips' flows
local function openPlay()
	-- the PLAY chip (QuickPlay: playHit -> setOpen; its Command "open" is setOpen(true))
	local g = playerGui:FindFirstChild("QuickPlay")
	local c = g and g:FindFirstChild("Command")
	if c then c:Fire("open") end
end
local function openLoadout()
	-- the LOADOUT chip (LoadoutMenu's chipHit, 2026-10-27): out of a match, the Loadout Altar's showcase chamber; else the menu
	local sc = playerGui:FindFirstChild("AltarShowcase")
	local cmd = sc and sc:GetAttribute("Ready") and sc:FindFirstChild("Command")
	if cmd and player:GetAttribute("DuelMatch") == nil then
		cmd:Fire("open")
		return
	end
	local g = playerGui:FindFirstChild("LoadoutMenu")
	local c = g and g:FindFirstChild("Command")
	if c then c:Fire("open") end
end

local placardCount = 0
for _, P in ipairs(Tuning.Placards) do
	local T = Tuning.Placard
	local B = { Centre = P.Centre, N = P.N, Size = P.Size or T.Size, Lift = P.Lift or T.Lift, PPS = T.PPS, MaxDistance = T.MaxDistance }
	local b = board(P.Name, B)
	local px, W, H = b.px, b.W, b.H
	local loadout = P.Kind == "Loadout"
	-- the prompt first: the face's keycap reads its key
	local anchor = Instance.new("Part")
	anchor.Name = "HubLife_" .. P.Name .. "Prompt"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(b.At + b.N * T.Out - b.Up * T.Down)
	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText, pp.ActionText = loadout and "Loadout" or "Duels", loadout and "Open" or "Play"
	pp.HoldDuration, pp.MaxActivationDistance = T.Hold, T.Reach
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode, pp.GamepadKeyCode = Enum.KeyCode.G, Enum.KeyCode.ButtonB   -- HubClient applies the player's own bind
	pp.Parent = anchor
	anchor.Parent = hub                       -- inside the hub model: HubClient's prompt binding finds it
	pp.Triggered:Connect(function()
		b.Gui:SetAttribute("Triggered", (b.Gui:GetAttribute("Triggered") or 0) + 1)
		if loadout then openLoadout() else openPlay() end
	end)
	placardCount += 1

	-- the face: one card (TOP DUELISTS' empty-state slab), the key, the action, one line
	local m = px(6)
	local _, face = K.slab(b.List, UDim2.fromOffset(W - 2 * m, H - 2 * m), UDim2.fromOffset(m, m), K.C.Card, 3, px(6), px(3), px(5))
	local fw, fh = W - 2 * m - px(6), H - 2 * m - px(6)
	local kc = P.Tall and px(30) or px(34)
	local kx, ky = math.floor((fw - kc) / 2), px(P.Tall and 8 or 10)
	local capShadow = K.make("Frame", { BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(kx + px(3), ky + px(3)),
		Size = UDim2.fromOffset(kc, kc), ZIndex = 5 }, face)
	K.corner(capShadow, px(5))
	local cap = K.make("Frame", { Name = "Keycap", BackgroundColor3 = K.C.Gold, BorderSizePixel = 0, Position = UDim2.fromOffset(kx, ky),
		Size = UDim2.fromOffset(kc, kc), ZIndex = 6 }, face)
	K.corner(cap, px(5))
	K.outline(cap, px(2))
	local key = K.make("TextLabel", { Name = "Key", BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = K.C.Ink,
		Position = UDim2.fromScale(0.16, 0.14), Size = UDim2.fromScale(0.68, 0.72), ZIndex = 7 }, cap)
	local function keyWord()
		if pp.ClickablePrompt then return "TAP" end
		local t = UserInputService:GetLastInputType()
		if string.find(t.Name, "Gamepad") then return (string.gsub(pp.GamepadKeyCode.Name, "^Button", "")) end
		local ok, s = pcall(function() return UserInputService:GetStringForKeyCode(pp.KeyboardKeyCode) end)
		return (ok and s and s ~= "") and string.upper(s) or string.upper(pp.KeyboardKeyCode.Name)
	end
	local function paintKey() key.Text = keyWord() end
	paintKey()
	pp:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(paintKey)
	pp:GetPropertyChangedSignal("GamepadKeyCode"):Connect(paintKey)
	pp:GetPropertyChangedSignal("ClickablePrompt"):Connect(paintKey)
	UserInputService.LastInputTypeChanged:Connect(paintKey)
	local word = loadout and "OPEN" or "PLAY"
	local line = loadout and "Element, Techniques and skins" or "Queue a match or a solo test"
	local titleY = ky + kc + px(P.Tall and 10 or 8)
	local titleBottom
	if P.Tall then
		-- the banner: the word stacked down its length
		local tSize = px(26)
		local stacked = table.concat(string.split(word, ""), "\n")
		local th = math.floor(#word * tSize * 0.92 + tSize * 0.15)
		K.display(face, { Name = "Title", Text = stacked, TextSize = tSize, LineHeight = 0.92, Position = UDim2.fromOffset(px(2), titleY),
			Size = UDim2.fromOffset(fw - px(4), th), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 6 }, px(2), K.C.Ink, EXTRUDE)
		titleBottom = titleY + th
		line = "Quick Play"
	else
		local tSize = px(30)
		while tSize > px(14) and textW(word, tSize, Enum.Font.LuckiestGuy) > fw - px(10) do tSize -= 2 end
		local th = math.floor(tSize * 1.2)
		K.display(face, { Name = "Title", Text = word, TextSize = tSize, Position = UDim2.fromOffset(px(4), titleY),
			Size = UDim2.fromOffset(fw - px(8), th), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 }, px(2), K.C.Ink, EXTRUDE)
		titleBottom = titleY + th
	end
	K.make("TextLabel", { Name = "Line", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = px(P.Tall and 9 or 10), TextWrapped = true,
		TextColor3 = K.C.LockedInk, Text = line, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(px(5), titleBottom + px(4)), Size = UDim2.fromOffset(fw - px(10), math.max(0, fh - titleBottom - px(8))),
		ZIndex = 6 }, face)
	b.Gui:SetAttribute("State", "Placard")
	b.Gui:SetAttribute("Kind", P.Kind)
end
folder:SetAttribute("Placards", placardCount)

----------------------------------------------------------------------------------------------------
-- THE VS CARD over a full duel pad
----------------------------------------------------------------------------------------------------
do
	local PD = Tuning.Pads
	local pads = {}
	local have = {}
	-- the pads stream in as you near the Duels room: look again for any not found yet
	local function addPad(i)
		local centre = hub:FindFirstChild("PC_DuelPad_P" .. i .. "_Centre", true)
		if centre and centre:IsA("BasePart") then
			have[i] = true
			local flat = centre.CFrame.LookVector * Vector3.new(1, 0, 1)
			local axis = flat.Magnitude > 0.01 and flat.Unit or Vector3.zAxis
			local anchor = Instance.new("Part")
			anchor.Name = "HubLife_VSAnchor_P" .. i
			anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
			anchor.Size = Vector3.new(0.2, 0.2, 0.2)
			anchor.CFrame = CFrame.new(centre.Position + Vector3.new(0, PD.Above, 0))
			anchor.Parent = folder
			local bb = K.make("BillboardGui", { Name = "HubLifeVS", Adornee = anchor, Size = UDim2.fromScale(PD.Size.X, PD.Size.Y),
				LightInfluence = 0, MaxDistance = 110, Enabled = false, ResetOnSpawn = false }, playerGui)
			local root = K.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5) }, bb)
			local scale = K.make("UIScale", { Scale = 1 }, root)
			-- (each half's words keep clear of the VS burst in the middle: A's sit left, B's right)
			local function half(xs)
				local tx = (xs < 0.5) and 0.05 or 0.33
				local f = K.make("Frame", { BorderSizePixel = 0, Position = UDim2.fromScale(xs, 0.12), Size = UDim2.fromScale(0.47, 0.76), ZIndex = 2 }, root)
				K.make("UIStroke", { Color = K.C.Ink, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
				K.make("UICorner", { CornerRadius = UDim.new(0.08, 0) }, f)
				local sh = K.make("Frame", { BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromScale(xs + 0.015, 0.16),
					Size = UDim2.fromScale(0.47, 0.76), ZIndex = 1 }, root)
				K.make("UICorner", { CornerRadius = UDim.new(0.08, 0) }, sh)
				K.halftone(f, 0.82, K.C.Ink, 8, 3)
				local name = K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true,
					Position = UDim2.fromScale(tx, 0.1), Size = UDim2.fromScale(0.62, 0.5), ZIndex = 4 }, f)
				K.make("UIStroke", { Color = K.C.Ink, Thickness = 2 }, name)
				local el = K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
					Position = UDim2.fromScale(tx, 0.62), Size = UDim2.fromScale(0.62, 0.26), ZIndex = 4 }, f)
				return f, name, el
			end
			local fa, na, ea = half(0.0)
			local fb, nb, eb = half(0.53)
			local burst = K.make("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://88718198034720", ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.34, 1.05), ZIndex = 8,
				ImageColor3 = Color3.fromRGB(255, 214, 64) }, root)
			local vs = K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextScaled = true, Text = "VS",
				TextColor3 = K.C.Ink, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.45),
				Rotation = -8, ZIndex = 9 }, burst)
			K.make("UIStroke", { Color = K.C.White, Thickness = 3 }, vs)
			pads[#pads + 1] = { Centre = centre.Position, Axis = axis, Gui = bb, Scale = scale, A = { fa, na, ea }, B = { fb, nb, eb }, Key = nil }
		end
	end
	task.spawn(function()
		while folder.Parent and #pads < PD.Count do
			for i = 1, PD.Count do
				if not have[i] then addPad(i) end
			end
			folder:SetAttribute("Pads", #pads)
			task.wait(2)
		end
	end)
	local function fill(side, p)
		local el = p:GetAttribute("Element")
		local def = el and K.element(el)
		local col = def and def.Base or K.C.Track
		side[1].BackgroundColor3 = col
		side[2].Text = string.upper(p.DisplayName)
		side[2].TextColor3 = K.C.CreamText
		side[3].Text = string.upper((def and def.Display) or tostring(el or "?"))
		side[3].TextColor3 = K.wordOn(col)
	end
	task.spawn(function()
		while folder.Parent do
			-- who stands on which half (HubServer's padOf rule)
			local occ = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local ch = p.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				local hum = ch and ch:FindFirstChildOfClass("Humanoid")
				if hrp and hum and hum.Health > 0 and p:GetAttribute("Zone") == "Hub" then
					for i, pd in ipairs(pads) do
						local rel = hrp.Position - pd.Centre
						if rel.Y > -1 and rel.Y < 9 and Vector3.new(rel.X, 0, rel.Z).Magnitude < PD.Radius then
							occ[i] = occ[i] or {}
							local side = (rel:Dot(pd.Axis) < 0) and "A" or "B"
							occ[i][side] = occ[i][side] or p
							break
						end
					end
				end
			end
			for i, pd in ipairs(pads) do
				local o = occ[i]
				local full = o and o.A and o.B
				local key = full and (o.A.UserId .. ":" .. o.B.UserId .. ":" .. tostring(o.A:GetAttribute("Element")) .. ":" .. tostring(o.B:GetAttribute("Element"))) or nil
				if key ~= pd.Key then
					pd.Key = key
					if full then
						fill(pd.A, o.A)
						fill(pd.B, o.B)
						pd.Gui.Enabled = true
						pd.Scale.Scale = 0.3
						TweenService:Create(pd.Scale, TweenInfo.new(HubLife.Calm() and 0.3 or 0.28, HubLife.Calm() and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
							Enum.EasingDirection.Out), { Scale = 1 }):Play()
					else
						pd.Gui.Enabled = false
					end
				end
			end
			folder:SetAttribute("VSCards", (function() local c = 0 for _, pd in ipairs(pads) do if pd.Key then c += 1 end end return c end)())
			task.wait(PD.Every)
		end
	end)
end

folder:SetAttribute("Ready", true)
