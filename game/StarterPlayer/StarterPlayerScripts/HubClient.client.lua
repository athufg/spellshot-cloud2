--[[
	HubClient  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubClient

	The client half of HubServer. The Hub and the arena share one server, and the player's "Zone" attribute
	("Hub" | "Arena", set by HubServer) says which one they are in; "Map" says which map (a MapRegistry id).
	This script makes the screen match:
	  Hub                  combat HUD off, the Hub's lighting with the bloom kept for its Neon and the game's one sky
	                       (the Hub is the Arcane Observatory since 2026-10-14), the Open Academy's floating islands
	                       (shown only in the Hub and on its Training Grounds), and a third-person camera that stops at
	                       the Hub's walls
	  Arena, a comic map   combat HUD back, the same flat lighting (its colours are baked bands too) but with the
	                       bloom kept for the neon, and the map's own skybox
	  Arena, the range     combat HUD back, the place's own lighting back
	  Arena, either        BACK TO HUB on screen (or press H)
	A comic wipe covers every move between the two while the server streams the far side in.
	Also: opens the loadout menu or Quick Play when a Hub prompt asks, shows the Hub's notices and the duel
	countdown, and gives the Hub's prompts the player's Interact bind (E is the Defense ability).
	In a DUEL (DuelMatch): the round, round-result and match-result banners, and BACK TO HUB comes off the screen unless
	the server says this player may leave (CanLeaveMatch: devs only, and leaving forfeits).
	In a TEAM match (2026-10-18, team mode) the same banners speak for the team ("YOUR TEAM TAKES THE ROUND"), "out" and
	"left" say who is down or gone, living teammates wear a gold outline, and Quick Play is told how full its queue is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hubRemote = ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("Hub", 30)
if not hubRemote then return end
local registryModule = ReplicatedStorage.Spellshot:WaitForChild("MapRegistry", 10)
local MapRegistry = registryModule and require(registryModule)
-- (2026-10-19, audit P5F-13) the shadows answer is shared with Graphics Quality (Settings.ApplyShadows)
local Settings = require(ReplicatedStorage.Spellshot:WaitForChild("SpellshotSettings"))
local HUB_NAME = "ArcaneObservatoryHub"    -- the Arcane Observatory (2026-10-14); the Open Academy before it is unwired

local INK = Color3.fromRGB(17, 17, 17)
local PAPER = Color3.fromRGB(234, 229, 216)
local RED = Color3.fromRGB(228, 37, 31)
local CREAM = Color3.fromRGB(250, 244, 232)

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local gui = make("ScreenGui", {
	Name = "HubClient", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local function topInset()
	local ok, inset = pcall(function() return GuiService.TopbarInset end)
	return (ok and inset and inset.Max.Y > 0) and inset.Max.Y or 58
end

local function zone()
	return player:GetAttribute("Zone")
end

----------------------------------------------------------------------------------------------------
-- notices
----------------------------------------------------------------------------------------------------
local toast = make("Frame", {
	Name = "Notice", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, topInset() + 14),
	Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = PAPER, Visible = false,
}, gui)
make("UIStroke", { Color = INK, Thickness = 3 }, toast)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, toast)
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, toast)
local toastText = make("TextLabel", {
	BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = INK, Text = "",
}, toast)
local toastToken = 0

local function showToast(text)
	toastToken += 1
	local mine = toastToken
	toastText.Text = tostring(text)
	toast.Visible = true
	task.delay(4, function()
		if toastToken == mine then toast.Visible = false end
	end)
end

----------------------------------------------------------------------------------------------------
-- the duel countdown
----------------------------------------------------------------------------------------------------
local countLabel = make("TextLabel", {
	Name = "Countdown", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(520, 110), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, TextSize = 72,
	TextColor3 = CREAM, Text = "", Visible = false,
}, gui)
make("UIStroke", { Color = INK, Thickness = 5 }, countLabel)
local countSeen = 0

local function showCountdown(seconds)
	countSeen = os.clock()
	if seconds and seconds > 0 then
		countLabel.Text = "DUEL IN " .. seconds
	else
		countLabel.Text = "DUEL!"
	end
	countLabel.Visible = true
end
RunService.Heartbeat:Connect(function()
	-- the server repeats the count every 0.2 s while the pad stays full; silence means someone stepped off
	if countLabel.Visible and os.clock() - countSeen > 0.7 then countLabel.Visible = false end
end)

----------------------------------------------------------------------------------------------------
-- the duel's banners
----------------------------------------------------------------------------------------------------
-- DuelMatch tells each duellist, from their own side: a round starting, a round's result, the match's result.
local GOLD = Color3.fromRGB(245, 184, 0)
local banner = make("Frame", {
	Name = "DuelBanner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.92, 0, 0, 170), BackgroundTransparency = 1, Visible = false,
}, gui)
local bannerScale = make("UIScale", {}, banner)
local bannerTitle = make("TextLabel", {
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 104), Font = Enum.Font.LuckiestGuy, TextScaled = true,
	TextColor3 = CREAM, Text = "",
}, banner)
make("UITextSizeConstraint", { MaxTextSize = 88 }, bannerTitle)
make("UIStroke", { Color = INK, Thickness = 6 }, bannerTitle)
local bannerSub = make("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 46),
	Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = CREAM, Text = "",
}, banner)
make("UITextSizeConstraint", { MaxTextSize = 38 }, bannerSub)
make("UIStroke", { Color = INK, Thickness = 4 }, bannerSub)
local BANNER_POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local bannerToken = 0

local function showBanner(title, sub, colour, seconds)
	bannerToken += 1
	local mine = bannerToken
	bannerTitle.Text, bannerSub.Text = title, sub or ""
	bannerTitle.TextColor3 = colour or CREAM
	banner.Visible = true
	bannerScale.Scale = 1.35
	TweenService:Create(bannerScale, BANNER_POP, { Scale = 1 }):Play()
	task.delay(seconds, function()
		if bannerToken == mine then banner.Visible = false end
	end)
end

local function scoreLine(d)
	-- a team match's score is the team's (2026-10-18, team mode)
	if d.Team then
		return ("YOUR TEAM %d - %d THEM"):format(d.Me or 0, d.Them or 0)
	end
	return ("YOU %d - %d %s"):format(d.Me or 0, d.Them or 0, string.upper(tostring(d.Opponent or "?")))
end

--- A TEAM match's banners (2026-10-18, team mode): the same moments as a duel's, spoken for the team.
local function onTeamMatch(kind, d)
	local allies = (type(d.Allies) == "table") and #d.Allies or 0
	local foes = (type(d.Foes) == "table") and #d.Foes or 0
	if kind == "round" then
		if d.Round == 1 then
			showBanner("ROUND 1", ("FIRST TO %d  ·  %dv%d"):format(d.FirstTo or 5, allies + 1, math.max(foes, 1)), CREAM, 2.2)
		else
			showBanner("ROUND " .. tostring(d.Round), scoreLine(d), CREAM, 1.8)
		end
	elseif kind == "roundEnd" then
		local clock = (d.How == "time") and "TIME! " or ""
		if d.Result == "win" then
			showBanner(clock .. "YOUR TEAM TAKES THE ROUND!", scoreLine(d), GOLD, 1.9)
		elseif d.Result == "loss" then
			showBanner(clock .. "THEY TAKE THE ROUND", scoreLine(d), RED, 1.9)
		else
			showBanner(clock .. "DRAW -- NO POINT", scoreLine(d), CREAM, 1.9)
		end
	elseif kind == "out" then
		-- down while teammates stand: no respawn until the round is over
		local n = tonumber(d.Standing) or 0
		showBanner("YOU'RE OUT!", ("BACK NEXT ROUND  ·  %d TEAMMATE%s STANDING"):format(n, (n == 1) and "" or "S"), RED, 2.4)
	elseif kind == "left" then
		local who = string.upper(tostring(d.Who or "A PLAYER"))
		showToast(d.Ally and (who .. " LEFT -- YOUR TEAM PLAYS ON SHORT-HANDED") or (who .. " LEFT -- THEY ARE A PLAYER DOWN"))
	elseif kind == "end" then
		if d.How == "forfeit" then
			if d.Result == "win" then
				showBanner("YOU WIN BY FORFEIT!", "THE OTHER TEAM LEFT", GOLD, 3)
			else
				showBanner("MATCH FORFEITED", scoreLine(d), RED, 3)
			end
		elseif d.Result == "win" then
			showBanner("YOUR TEAM WINS!", scoreLine(d), GOLD, 3.8)
		elseif d.Result == "draw" then   -- (2026-10-19, audit P3-13) MaxRounds ended a level match
			showBanner("MATCH DRAWN", scoreLine(d), CREAM, 3.8)
		else
			showBanner("THEIR TEAM WINS", scoreLine(d), RED, 3.8)
		end
	end
end

local function onMatch(kind, d)
	d = (type(d) == "table") and d or {}
	if d.Team then return onTeamMatch(kind, d) end
	local them = string.upper(tostring(d.Opponent or "your opponent"))
	if kind == "round" then
		if d.Round == 1 then
			showBanner("ROUND 1", ("FIRST TO %d  ·  VS %s"):format(d.FirstTo or 5, them), CREAM, 2.2)
		else
			showBanner("ROUND " .. tostring(d.Round), scoreLine(d), CREAM, 1.8)
		end
	elseif kind == "roundEnd" then
		local clock = (d.How == "time") and "TIME! " or ""     -- the round clock ran out (DuelMatch, 2026-10-17)
		if d.Result == "win" then
			showBanner(clock .. "ROUND TO YOU!", scoreLine(d), GOLD, 1.9)
		elseif d.Result == "loss" then
			showBanner(clock .. "ROUND TO " .. them, scoreLine(d), RED, 1.9)
		else
			showBanner(clock .. "DRAW -- NO POINT", scoreLine(d), CREAM, 1.9)
		end
	elseif kind == "end" then
		if d.How == "forfeit" then
			if d.Result == "win" then
				showBanner("YOU WIN BY FORFEIT!", them .. " LEFT THE DUEL", GOLD, 3)
			else
				showBanner("DUEL FORFEITED", scoreLine(d), RED, 3)
			end
		elseif d.Result == "win" then
			showBanner("YOU WIN THE DUEL!", scoreLine(d), GOLD, 3.8)
		elseif d.Result == "draw" then   -- (2026-10-19, audit P3-13) MaxRounds ended a level match
			showBanner("MATCH DRAWN", scoreLine(d), CREAM, 3.8)
		else
			showBanner(them .. " WINS THE DUEL", scoreLine(d), RED, 3.8)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- teammates (2026-10-18, team mode)
----------------------------------------------------------------------------------------------------
-- In a team match every living teammate wears a gold outline, seen through walls, so a friend is never taken for a
-- target; enemies wear nothing. Gold, not cyan: the round plate already spends red on your score and cyan on theirs.
-- The outlines live under the camera (this client only) and go the moment either player is out of the match.
local function isTeammate(other)
	if other == player then return false end
	local match, team = player:GetAttribute("DuelMatch"), player:GetAttribute("MatchTeam")
	return match ~= nil and team ~= nil and other:GetAttribute("DuelMatch") == match
		and other:GetAttribute("MatchTeam") == team
end
task.spawn(function()
	local marks = {}      -- [player] = their Highlight
	while true do
		local camera = workspace.CurrentCamera
		for _, other in ipairs(Players:GetPlayers()) do
			local char = other.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			local mark = marks[other]
			if camera and humanoid and humanoid.Health > 0 and isTeammate(other) then
				if not (mark and mark.Parent) then
					mark = make("Highlight", {
						Name = "TeammateMark", FillTransparency = 1, OutlineColor = GOLD, OutlineTransparency = 0,
						DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
					}, camera)
					marks[other] = mark
				end
				if mark.Adornee ~= char then mark.Adornee = char end
			elseif mark then
				mark:Destroy()
				marks[other] = nil
			end
		end
		for other, mark in pairs(marks) do
			if not other.Parent then
				mark:Destroy()
				marks[other] = nil
			end
		end
		task.wait(0.4)
	end
end)

----------------------------------------------------------------------------------------------------
-- the wipe that covers a move between the Hub and the arena
----------------------------------------------------------------------------------------------------
-- Its own ScreenGui, above every menu, so nothing is left showing while the far side streams in.
local wipeGui = make("ScreenGui", {
	Name = "HubWipe", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local wipe = make("Frame", {
	Name = "Wipe", BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(-1, 0), Visible = false,
}, wipeGui)
local wipeText = make("TextLabel", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.LuckiestGuy, TextSize = 72,
	TextColor3 = CREAM, Text = "", ZIndex = 2,
}, wipe)
make("UIStroke", { Color = RED, Thickness = 4 }, wipeText)
local WIPE_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WIPE_OUT = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local wipeToken = 0

local function reveal()
	wipeToken += 1
	local mine = wipeToken
	local t = TweenService:Create(wipe, WIPE_OUT, { Position = UDim2.fromScale(1, 0) })
	t.Completed:Connect(function()
		if wipeToken == mine then wipe.Visible = false end
	end)
	t:Play()
end

local function cover(toZone, mapName, label)
	wipeToken += 1
	local mine = wipeToken
	if type(label) == "string" then
		wipeText.Text = label                     -- a duel round's number
	elseif toZone == "Arena" then
		wipeText.Text = mapName and ("TO " .. mapName .. "!") or "TO THE ARENA!"
	else
		wipeText.Text = "BACK TO THE HUB"
	end
	wipe.Position = UDim2.fromScale(-1, 0)
	wipe.Visible = true
	TweenService:Create(wipe, WIPE_IN, { Position = UDim2.fromScale(0, 0) }):Play()
	-- never leave the screen covered if the server's reveal is lost
	task.delay(8, function()
		if wipeToken == mine then reveal() end
	end)
end
-- (2026-10-26) the same wipe for client cuts (the Loadout Showcase): Command:Fire("cover", label) / Fire("reveal")
make("BindableEvent", { Name = "Command" }, wipeGui).Event:Connect(function(what, label)
	if what == "cover" then cover(nil, nil, label) elseif what == "reveal" then reveal() end
end)

----------------------------------------------------------------------------------------------------
-- server messages
----------------------------------------------------------------------------------------------------
local function command(guiName, what, arg)
	local g = playerGui:FindFirstChild(guiName) or playerGui:WaitForChild(guiName, 5)
	local c = g and g:FindFirstChild("Command")
	if c then c:Fire(what, arg) end
end

hubRemote.OnClientEvent:Connect(function(what, a, reason, extra, label)
	if what == "notice" then
		showToast(a)
	elseif what == "match" then
		onMatch(a, reason)
	elseif what == "open" then
		-- (2026-10-26, the owner) the Loadout Altar opens its showcase (AltarShowcase) where it runs; else the flat menu
		local showcase = a == "Loadout" and playerGui:FindFirstChild("AltarShowcase")
		if showcase and showcase:GetAttribute("Ready") then
			command("AltarShowcase", "open")
		else
			command(a == "Loadout" and "LoadoutMenu" or "QuickPlay", "open")
		end
	elseif what == "queued" and a == false then
		-- the server dropped you from Quick Play's queue; "dequeued" tells nothing back to the server
		if reason then showToast(reason) end
		command("QuickPlay", "dequeued", reason)
	elseif what == "queued" and a == true then
		-- (2026-10-18, team mode) the server put you back in the queue: a team match's map vote was called off
		if reason then showToast(reason) end
		command("QuickPlay", "requeued", reason)
	elseif what == "queueCount" then
		-- (2026-10-18, team mode) how full Quick Play's queue is: "3/6"
		command("QuickPlay", "count", ("%d/%d"):format(tonumber(a) or 0, tonumber(reason) or 0))
	elseif what == "countdown" then
		showCountdown(a)
	elseif what == "transition" then
		if a == "cover" then
			cover(reason, extra, label)
			task.spawn(command, "QuickPlay", "close")
			task.spawn(command, "LoadoutMenu", "close")
			task.spawn(command, "MapVote", "close")
		else
			-- face the way the spot faces (the duel marks face each other): first person keeps the camera's old
			-- heading through a move and turns the body back to it, so the camera is turned, not the body
			-- (2026-10-30) and the body has to be where the server put it: a client still holding its old place (measured in
			-- Play: the server's move never reached it) takes the body back there when the server hands it over, so a body
			-- this far off the spot is set on it from here too (the client owns its body; the move's grace covers it)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if typeof(label) == "CFrame" and root and (root.Position - label.Position).Magnitude > 50 then
				player.Character:PivotTo(label)
				root.AssemblyLinearVelocity = Vector3.zero
			end
			local look = typeof(extra) == "Vector3" and Vector3.new(extra.X, 0, extra.Z) or nil
			if look and look.Magnitude > 0.01 then
				local cam = workspace.CurrentCamera
				local pos = cam.CFrame.Position
				cam.CFrame = CFrame.lookAt(pos, pos + look.Unit)
			end
			reveal()
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- what the screen looks like in each zone
----------------------------------------------------------------------------------------------------
-- Health, mana, the ability slots, the passive chip, the crosshair, the round plate and the play-area
-- border are PopArtHUD's five ScreenGuis. PopArtHUD never sets Enabled itself, so this holds. PLAY, the
-- Element chip and the settings gear belong to other scripts and stay in both zones.
local COMBAT_GUIS = {
	PopArtHUD = true, PopArtHUDEdge = true, PopArtHUDTop = true, PopArtHUDReadout = true, PopArtHUDCrosshair = true,
}

local function applyHud()
	local show = zone() ~= "Hub"
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and COMBAT_GUIS[g.Name] then g.Enabled = show end
	end
end
playerGui.ChildAdded:Connect(function(g)
	if g:IsA("ScreenGui") and COMBAT_GUIS[g.Name] then g.Enabled = zone() ~= "Hub" end
end)

-- The Hub's baked colour bands were made for flat light, and so were a comic map's; the range keeps the place's
-- own lighting. The swap happens on this client only (the server's Lighting is never touched), and exactly what
-- was there is put back, so SettingsRuntime's own effects and rows are left alone.
-- Every playable space that is not carrying its own profile gets this, the Hub included.
-- Brightness 0 with white ambient means there is no directional light to occlude, so no surface
-- can be darker than any other whatever is in front of it -- which is the fairness rule: nobody
-- gets to stand somewhere genuinely darker than the rest of the map and use it as cover.
-- GlobalShadows is stated here rather than inherited from whatever the place was last saved with.
local FLAT_LIGHT = {
	Brightness = 0, Ambient = Color3.new(1, 1, 1), OutdoorAmbient = Color3.new(1, 1, 1),
	EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ExposureCompensation = 0,
	GlobalShadows = false,
}
local HUB_OFF = { DepthOfFieldEffect = true, SunRaysEffect = true }       -- bloom stays: the Observatory's rune lines, pad rings and portal are Neon
local MAP_OFF = { DepthOfFieldEffect = true, SunRaysEffect = true }       -- bloom stays: it is what makes neon glow
-- A real-light map KEEPS its sun rays: a raking sun through a row of towers is the effect, not an
-- artefact of one. Only depth of field goes, because a duel needs the far end of a bridge sharp.
local LIT_OFF = { DepthOfFieldEffect = true }
local SKY_FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }
local savedLight, savedProfile = nil, nil

--- "Hub", a comic map's id, or nil for the place's own lighting; and that map's registry entry.
local function lightProfile()
	if zone() == "Hub" then return "Hub", nil end
	local map = MapRegistry and MapRegistry.Get(player:GetAttribute("Map"))
	if zone() == "Arena" and map and (map.FlatLight or map.Light) then return map.Id, map end
	return nil, nil
end

local function restoreLight()
	if not savedLight then return end
	Settings.ProfileShadows = nil     -- (2026-10-19, audit P5F-13) back to Graphics Quality's answer alone
	Settings.ApplyShadows()
	for k, v in pairs(savedLight.props) do
		pcall(function() Lighting[k] = v end)
	end
	for e, was in pairs(savedLight.effects) do
		if e.Parent then e.Enabled = was end
	end
	for e, v in pairs(savedLight.atmospheres) do
		if e.Parent then
			e.Density, e.Haze, e.Glare = v[1], v[2], v[3]
			if v[4] then e.Offset, e.Color, e.Decay = v[4], v[5], v[6] end
		end
	end
	for e, old in pairs(savedLight.effectProps or {}) do
		if e.Parent then
			for k, v in pairs(old) do pcall(function() e[k] = v end) end
		end
	end
	local cl = savedLight.clouds
	if cl then
		if cl.made then
			cl.inst:Destroy()
		elseif cl.inst.Parent then
			for k, v in pairs(cl.props) do cl.inst[k] = v end
		end
	end
	local sky = savedLight.sky
	if sky then
		if sky.made then
			sky.inst:Destroy()
		elseif sky.inst.Parent then
			for k, v in pairs(sky.props) do sky.inst[k] = v end
		end
	end
	savedLight = nil
end

local function applyLighting()
	local profile, map = lightProfile()
	if profile == savedProfile then return end
	restoreLight()
	savedProfile = profile
	if not profile then return end
	savedLight = { props = {}, effects = {}, atmospheres = {} }
	-- A map either has baked comic bands and wants no light at all laid over them (FLAT_LIGHT), or it
	-- carries its own real-light profile and wants exactly that and nothing else. Same save-and-restore
	-- path either way, so leaving a map still puts back precisely what was there.
	-- One sky and one light for the whole game, the way Rivals has one: MapRegistry.Universal is the
	-- rig measured off the owner's Rivals captures (2026-09-22). A map can still carry its own Light;
	-- the Hub and every map without one get the universal rig. FLAT_LIGHT is only the fallback for a
	-- place with no rig defined at all.
	local universal = MapRegistry and MapRegistry.Universal
	local lit = (map and map.Light) or (universal and universal.Light) or nil
	for k, v in pairs((lit and lit.Props) or FLAT_LIGHT) do
		if k == "GlobalShadows" then
			-- (2026-10-19, audit P5F-13) not copied: the profile's wish is ANDed with Graphics Quality (LOW / MEDIUM keep
			-- shadows off) and neither saved nor restored, so a quality change made in a zone is not undone on leaving
			Settings.ProfileShadows = v == true
		else
			savedLight.props[k] = Lighting[k]
			pcall(function() Lighting[k] = v end)
		end
	end
	Settings.ApplyShadows()
	local off = (profile == "Hub") and HUB_OFF or (lit and LIT_OFF or MAP_OFF)
	for _, e in ipairs(Lighting:GetChildren()) do
		if off[e.ClassName] then
			savedLight.effects[e] = e.Enabled
			e.Enabled = false
		elseif e:IsA("Atmosphere") then
			savedLight.atmospheres[e] = { e.Density, e.Haze, e.Glare, e.Offset, e.Color, e.Decay }
			-- a comic map wants no atmosphere at all; a real-light one wants its own sense of distance
			local a = lit and lit.Atmosphere
			e.Density = a and a.Density or 0
			e.Haze = a and a.Haze or 0
			e.Glare = a and a.Glare or 0
			if a and a.Offset then e.Offset = a.Offset end
			if a and a.Color then e.Color = a.Color end
			if a and a.Decay then e.Decay = a.Decay end
		end
	end
	local skyFaces = (map and map.Sky) or (profile == "Hub" and MapRegistry and MapRegistry.HubSky) or (universal and universal.Sky) or nil
	if skyFaces and skyFaces.Ft ~= "" then
		local sky = Lighting:FindFirstChildOfClass("Sky")
		local made = sky == nil
		sky = sky or Instance.new("Sky")
		local props = { CelestialBodiesShown = sky.CelestialBodiesShown, StarCount = sky.StarCount }
		for _, face in ipairs(SKY_FACES) do
			props["Skybox" .. face] = sky["Skybox" .. face]
			sky["Skybox" .. face] = skyFaces[face]
		end
		-- WHY THERE WAS NO SUN. The comic skies are painted without one, so Roblox's own disc would
		-- float over them with no light in the scene to match it -- this line turned it off for every
		-- map, and it has been off ever since. A real-light map asks for it back, and then the disc, the
		-- rays and the shadows all come from one direction.
		-- (2026-09-22: the universal rig paints its sun into the skybox - a flat 224 plateau and a glow,
		-- as measured in Rivals, never a clipped disc - so its Sun is false and the engine disc stays off)
		sky.CelestialBodiesShown = (lit and lit.Sun) == true
		sky.StarCount = 0
		if made then sky.Parent = Lighting end
		savedLight.sky = { inst = sky, made = made, props = props }
	end
	-- the rig's post effects: bloom held above the sky's 224 ceiling so only Neon blooms, no sun rays
	-- (Rivals' sun has no streaks), and a neutral grade so the painted sky lands as measured. Keyed by
	-- the effect's Name first, then its ClassName; every touched property is saved and put back.
	local fx = lit and lit.Effects
	if fx then
		savedLight.effectProps = {}
		for _, e in ipairs(Lighting:GetChildren()) do
			local want = fx[e.Name] or fx[e.ClassName]
			if want then
				local old = {}
				for k, v in pairs(want) do
					old[k] = e[k]
					pcall(function() e[k] = v end)
				end
				savedLight.effectProps[e] = old
			end
		end
	end
	-- Roblox draws better clouds than we can paint, so a map that wants cumulus asks for the
	-- engine's volumetric layer rather than getting them baked into its skybox. Measured against
	-- the reference this is not a close call: painted cloud cannot be soft and large at once.
	-- Gated per map through the same save-and-restore path as everything else here, so leaving
	-- the map puts the layer back exactly as it was found.
	local wantClouds = lit and lit.Clouds
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if wantClouds or clouds then
		local cmade = clouds == nil
		clouds = clouds or Instance.new("Clouds")
		savedLight.clouds = { inst = clouds, made = cmade, props = {
			Enabled = clouds.Enabled, Cover = clouds.Cover,
			Density = clouds.Density, Color = clouds.Color } }
		if wantClouds then
			clouds.Cover = wantClouds.Cover or 0.55
			clouds.Density = wantClouds.Density or 0.62
			clouds.Color = wantClouds.Color or Color3.new(1, 1, 1)
		end
		clouds.Enabled = wantClouds ~= nil
		if cmade then clouds.Parent = workspace.Terrain end
	end
end

----------------------------------------------------------------------------------------------------
-- BACK TO HUB (arena only)
----------------------------------------------------------------------------------------------------
local backHolder = make("Frame", {
	Name = "BackToHub", Position = UDim2.fromOffset(16, topInset() + 12), Size = UDim2.fromOffset(214, 44),
	BackgroundColor3 = INK, BorderSizePixel = 0, Visible = false,
}, gui)
local backFace = make("TextButton", {
	Position = UDim2.fromOffset(-3, -3), Size = UDim2.fromScale(1, 1), BackgroundColor3 = PAPER, AutoButtonColor = false,
	Font = Enum.Font.LuckiestGuy, TextSize = 22, TextColor3 = INK, Text = "BACK TO HUB  ·  H",
}, backHolder)
make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, backFace)
local backSent = false

--- Mid-duel, BACK TO HUB is a dev's only (the server decides; CanLeaveMatch mirrors it), and it forfeits the match.
local function inDuel()
	return player:GetAttribute("DuelMatch") ~= nil
end
local function canLeave()
	return not inDuel() or player:GetAttribute("CanLeaveMatch") == true
end

local function resetBack()
	backSent = false
	backFace.Text = inDuel() and "FORFEIT  ·  H" or "BACK TO HUB  ·  H"
	backFace.BackgroundColor3 = PAPER
	backFace.TextColor3 = INK
end

local function goBack()
	if backSent or zone() ~= "Arena" or not canLeave() then return end
	backSent = true
	backFace.Text = "HEADING BACK..."
	backFace.BackgroundColor3 = RED
	backFace.TextColor3 = CREAM
	hubRemote:FireServer("return")
	task.delay(6, function()
		if backSent then resetBack() end
	end)
end
backFace.Activated:Connect(goBack)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.H then goBack() end
end)

----------------------------------------------------------------------------------------------------
-- zone changes
----------------------------------------------------------------------------------------------------
local function applyBack()
	resetBack()
	backHolder.Visible = zone() == "Arena" and canLeave()
end

-- The Academy's floating islands (OpenAcademyBackdrop) ring the Hub out to 1,250 studs, near enough to be seen from the
-- arena at the origin. On this client they are there only while the player is in the Hub or on its Training Grounds.
local backdrop
local function applyBackdrop()
	if not backdrop then return end
	local show = zone() == "Hub" or player:GetAttribute("Map") == "TrainingGrounds"
	backdrop.Parent = show and workspace or nil
end
task.spawn(function()
	backdrop = workspace:WaitForChild("OpenAcademyBackdrop", 60)
	applyBackdrop()
end)

local function applyZone()
	applyHud()
	applyLighting()
	applyBack()
	applyBackdrop()
end
player:GetAttributeChangedSignal("Zone"):Connect(applyZone)
player:GetAttributeChangedSignal("DuelMatch"):Connect(applyBack)
player:GetAttributeChangedSignal("CanLeaveMatch"):Connect(applyBack)
player:GetAttributeChangedSignal("Map"):Connect(applyLighting)
player:GetAttributeChangedSignal("Map"):Connect(applyBackdrop)
applyZone()

----------------------------------------------------------------------------------------------------
-- third person in the Hub stops at walls
----------------------------------------------------------------------------------------------------
-- FirstPersonController's V gives a third-person camera 7 back and 3 to the right. Roblox's Poppercam only lets CanCollide,
-- nearly opaque parts stop it, and the Observatory's meshes do not collide while its colliders are invisible, so the camera
-- went through the walls and the dome. After the shoulder shift (Camera+2) the camera is pulled in to the first collider
-- between the head and it. First person, the arena and every other map are untouched; no mesh is made to collide.
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
local wallFolder
local CAMERA_RADIUS, CAMERA_MARGIN = 0.35, 0.2
RunService:BindToRenderStep("HubCameraWalls", Enum.RenderPriority.Camera.Value + 3, function()
	if zone() ~= "Hub" or player.CameraMode == Enum.CameraMode.LockFirstPerson then return end
	if not (wallFolder and wallFolder.Parent) then
		local hubModel = workspace:FindFirstChild(HUB_NAME)
		wallFolder = hubModel and hubModel:FindFirstChild("Colliders")
		if not wallFolder then return end
		wallParams.FilterDescendantsInstances = { wallFolder }
	end
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then return end
	local cam = workspace.CurrentCamera
	local from, to = head.Position, cam.CFrame.Position
	local d = to - from
	if d.Magnitude < 0.1 then return end
	local hit = workspace:Spherecast(from, CAMERA_RADIUS, d, wallParams)
	if hit then
		cam.CFrame = cam.CFrame.Rotation + (from + d.Unit * math.max(hit.Distance - CAMERA_MARGIN, 0.3))
	end
end)

----------------------------------------------------------------------------------------------------
-- (2026-10-19, audit P6A-14) the "Ley over the Hall of Cores" spin was removed: its Hall / Floor / Ley parts exist only in
-- the replaced hub (ServerStorage.ReplacedHubs.SpellshotHub), so in the Arcane Observatory it only waited 90 s and quit.
-- It is in git history (before this date) if that hub ever comes back.
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- the Hub's prompts take the player's Interact bind
----------------------------------------------------------------------------------------------------
-- E is the Defense ability and its bind eats the key before a prompt sees it. A save from before
-- Interact had a default still reads "None", so an unbound Interact falls back to G / ButtonB.
task.spawn(function()
	local hub = workspace:WaitForChild(HUB_NAME, 60)
	if not hub then return end
	local Settings = require(ReplicatedStorage.Spellshot:WaitForChild("SpellshotSettings"))
	-- A clickable prompt is a button in the world. In first person the cursor is locked to the middle of the screen,
	-- and while a prompt's button sits under it the camera gets no mouse movement: looking at a prompt froze the view
	-- (the owner, 2026-10-14). Only touch needs to tap a prompt; everyone else holds the Interact key.
	local function tapToUse()
		local t = UserInputService:GetLastInputType()
		return t == Enum.UserInputType.Touch
			or (t == Enum.UserInputType.None and UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	end
	local function apply(pp)
		pp.KeyboardKeyCode = Settings.KeyCode("Bind_Interact") or Enum.KeyCode.G
		pp.GamepadKeyCode = Settings.KeyCode("Pad_Interact") or Enum.KeyCode.ButtonB
		pp.ClickablePrompt = tapToUse()
	end
	local function applyAll()
		for _, d in ipairs(hub:GetDescendants()) do
			if d:IsA("ProximityPrompt") then apply(d) end
		end
	end
	hub.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then apply(d) end
	end)
	Settings.Bind("Bind_Interact", applyAll)
	Settings.OnChange("Pad_Interact", applyAll)
	local touch = tapToUse()
	UserInputService.LastInputTypeChanged:Connect(function()
		if tapToUse() ~= touch then
			touch = tapToUse()
			applyAll()
		end
	end)
end)
