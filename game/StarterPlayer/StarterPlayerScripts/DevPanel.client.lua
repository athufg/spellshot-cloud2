--[[
	DevPanel  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/DevPanel

	The dev/test panel. Hidden by default, toggled with the ';' key.

	WHY THIS EXISTS
	Almost everything built for this game -- 8 Elements, 24 Techniques, ~16 status reactions --
	could previously only be seen by playing until it happened to come up. That is not a way to
	check work. This drives every one of them on demand.

	WHAT REPLACED WHAT
	The old build printed a five-line cheat readout permanently in the corner. It is gone: none of
	it shows during normal play, and everything it did moved in here under the toggle.

	DESIGN RULE FOR THIS FILE: coverage over polish. It is a test harness, so it is a plain
	scrolling list of labelled buttons in categories. No rendered art, no chassis, no animation --
	if it looked like the HUD it would be harder to tell the tool from the thing under test.

	IT DRIVES THE REAL PATHS, NOT TEST-ONLY ONES. Equipping an Element sets the same player
	attribute the loadout system sets; a status raises the same RX_<Kind> character attribute the
	server raises. So a green result here means the real path works, not that a parallel test path
	works.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local devRemote = folder:WaitForChild("DevRequest")
local castRemote = folder:WaitForChild("CastRequest")

local TOGGLE_KEY = Enum.KeyCode.Semicolon

----------------------------------------------------------------------------------------------------
-- look (deliberately utilitarian)
----------------------------------------------------------------------------------------------------
local C = {
	Panel = Color3.fromRGB(16, 18, 24),
	Header = Color3.fromRGB(28, 32, 42),
	Btn = Color3.fromRGB(38, 44, 58),
	BtnOn = Color3.fromRGB(28, 120, 72),
	BtnHot = Color3.fromRGB(120, 40, 40),
	Text = Color3.fromRGB(225, 232, 240),
	Dim = Color3.fromRGB(140, 150, 165),
	Accent = Color3.fromRGB(120, 235, 180),
}

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

if playerGui:FindFirstChild("SpellshotDevPanel") then
	playerGui.SpellshotDevPanel:Destroy()
end
-- the old always-on readout, if a previous build left one behind
if playerGui:FindFirstChild("SpellshotDev") then
	playerGui.SpellshotDev:Destroy()
end

local gui = make("ScreenGui", {
	-- IgnoreGuiInset FALSE so the panel starts below Roblox's own topbar; with it true the
	-- header sat underneath the core menu and chat buttons and could not be read.
	Name = "SpellshotDevPanel", ResetOnSpawn = false, IgnoreGuiInset = false,
	DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false,
}, playerGui)

local panel = make("Frame", {
	Name = "Panel", BackgroundColor3 = C.Panel, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0, 8),
	Size = UDim2.new(0, 420, 1, -18), ZIndex = 50,
}, gui)
make("UIStroke", { Color = C.Accent, Thickness = 1, Transparency = 0.4 }, panel)

local header = make("TextLabel", {
	Name = "Header", BackgroundColor3 = C.Header, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.Code, TextSize = 14,
	TextColor3 = C.Accent, Text = "  SPELLSHOT DEV PANEL   [ ; ] to close",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51,
}, panel)

-- SPARKS TO (2026-10-23, owner: "do onyl for sparks"): who the Sparks button pays, always on screen because it is the one
-- row in this panel that may act on someone else. Every other row still acts on you. Set by the SPARKS TARGET list below.
local sparksToLabel = make("TextLabel", {
	Name = "SparksTo", BackgroundColor3 = C.Btn, BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 22),
	Font = Enum.Font.Code, TextSize = 12, TextColor3 = C.Accent, Text = "  SPARKS TO: you",
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 51,
}, panel)

local status = make("TextLabel", {
	Name = "Status", BackgroundColor3 = C.Header, BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26),
	Font = Enum.Font.Code, TextSize = 12, TextColor3 = C.Dim, Text = "  ready",
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 51,
}, panel)

local scroll = make("ScrollingFrame", {
	Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 1, -82),
	CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8, Active = true, ZIndex = 51,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
	PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10) }, scroll)

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function say(msg)
	status.Text = "  " .. msg
end

local function section(title)
	local f = make("TextLabel", {
		BackgroundColor3 = C.Header, BorderSizePixel = 0, LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.Code, TextSize = 13,
		TextColor3 = C.Accent, Text = " " .. title, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 52,
	}, scroll)
	return f
end

--- A row of small buttons. `items` is a list of { label, onClick, [toggleGetter] }. An onClick that returns a
--- string has it shown in the status line instead of "-> sent": what the press really did, when that differs.
local function buttonRow(items, perRow, height)
	perRow = perRow or 4
	height = height or 24
	local rows = math.ceil(#items / perRow)
	local holder = make("Frame", {
		BackgroundTransparency = 1, LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, rows * (height + 3)), ZIndex = 52,
	}, scroll)
	local made = {}
	for i, item in ipairs(items) do
		local r = math.floor((i - 1) / perRow)
		local c = (i - 1) % perRow
		local b = make("TextButton", {
			BackgroundColor3 = C.Btn, BorderSizePixel = 0, AutoButtonColor = true,
			Position = UDim2.new(c / perRow, 2, 0, r * (height + 3)),
			Size = UDim2.new(1 / perRow, -4, 0, height),
			Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.Text,
			Text = item[1], TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 53,
		}, holder)
		b.Activated:Connect(function()
			local ok, res = pcall(item[2], b)
			say(ok and (type(res) == "string" and res or (item[1] .. " -> sent")) or ("ERR " .. tostring(res)))
		end)
		made[#made + 1] = { button = b, item = item }
	end
	return made
end

----------------------------------------------------------------------------------------------------
-- helpers that drive the REAL paths
----------------------------------------------------------------------------------------------------
local function dev(...)
	devRemote:FireServer(...)
end

local function reactions()
	return _G.SpellshotReactions
end

local function hud()
	return _G.SpellshotHUD
end

local function currentElement()
	return player:GetAttribute("Element") or Config.DefaultLoadout.Element
end

----------------------------------------------------------------------------------------------------
-- SPARKS TARGET  (2026-10-23)
----------------------------------------------------------------------------------------------------
-- Every player on this server, live. Clicking one makes them the target of the Sparks button (+1000 SPARKS, in
-- ECONOMY) and of NOTHING else: every other row still acts on you. The default is you; a target who leaves falls back
-- to you. Only the target's UserId is sent; SpellshotService checks the caller is a dev and the target is a player on
-- this server before it pays them, and logs caller, target and action.
local sparksTargetId = player.UserId
local sparksButton                              -- the +1000 SPARKS button, set in ECONOMY below
local sparksConn                                -- the target's Sparks attribute, shown in the strip

local function sparksTarget()
	local t = Players:GetPlayerByUserId(sparksTargetId)
	if not t or t.Parent ~= Players then
		sparksTargetId = player.UserId
		t = player
	end
	return t
end

local function playerLabel(p)
	return p == player and (p.Name .. " (you)") or p.Name
end

local function paintSparksLabel()
	local t = sparksTarget()
	sparksToLabel.Text = ("  SPARKS TO: %s   (has %s)"):format(playerLabel(t), tostring(t:GetAttribute("Sparks") or "-"))
	if sparksButton then
		sparksButton.Text = t == player and "+1000 SPARKS" or ("+1000 SPARKS > " .. t.Name)
		sparksButton.BackgroundColor3 = t == player and C.Btn or C.BtnHot
	end
end

section("SPARKS TARGET  (click a player: only +1000 SPARKS goes to them)")
local sparksList = make("Frame", {
	BackgroundTransparency = 1, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), ZIndex = 52,
}, scroll)

local paintSparksTarget
--- Rebuilds the list from Players (the selected row highlighted) and repaints the strip. `leaving` is left out: during
--- PlayerRemoving the leaver is still in Players.
paintSparksTarget = function(leaving)
	if leaving and leaving.UserId == sparksTargetId then sparksTargetId = player.UserId end
	local t = sparksTarget()
	if sparksConn then sparksConn:Disconnect() end
	sparksConn = t:GetAttributeChangedSignal("Sparks"):Connect(paintSparksLabel)
	for _, ch in ipairs(sparksList:GetChildren()) do ch:Destroy() end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= leaving then list[#list + 1] = p end
	end
	table.sort(list, function(x, y)
		if (x == player) ~= (y == player) then return x == player end
		return x.Name:lower() < y.Name:lower()
	end)
	local perRow, height = 3, 22
	for i, p in ipairs(list) do
		local r, c = math.floor((i - 1) / perRow), (i - 1) % perRow
		local uid = p.UserId
		local b = make("TextButton", {
			BackgroundColor3 = p == t and C.BtnOn or C.Btn, BorderSizePixel = 0, AutoButtonColor = true,
			Position = UDim2.new(c / perRow, 2, 0, r * (height + 3)), Size = UDim2.new(1 / perRow, -4, 0, height),
			Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.Text,
			Text = (p == t and "* " or "  ") .. playerLabel(p), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 53,
		}, sparksList)
		b.Activated:Connect(function()
			sparksTargetId = uid
			paintSparksTarget()
			say("Sparks now go to " .. playerLabel(sparksTarget()) .. "; every other row is still you")
		end)
	end
	sparksList.Size = UDim2.new(1, 0, 0, math.ceil(#list / perRow) * (height + 3))
	paintSparksLabel()
end
Players.PlayerAdded:Connect(function() paintSparksTarget() end)
Players.PlayerRemoving:Connect(function(p)
	local wasTarget = p.UserId == sparksTargetId and p ~= player
	paintSparksTarget(p)
	if wasTarget then say(p.Name .. " left: Sparks go to you again") end
end)

----------------------------------------------------------------------------------------------------
-- ELEMENTS
----------------------------------------------------------------------------------------------------
section("ELEMENTS  (equip - M1 / Primary / Passive / Ult, + default Techniques)")
do
	local items = {}
	for _, e in ipairs(Config.ElementOrder) do
		items[#items + 1] = { e:upper(), function() dev("SetElement", e) end }
	end
	buttonRow(items, 4)
end

-- ECONOMY (2026-10-18, economy): Sparks and owned Elements, through PlayerData's real paths (SpellshotService's dev
-- actions EcoAddSparks / EcoUnlockAll / EcoReset). RESET is a new player's save: the starter kit and 0 Sparks; the
-- purchase records stay, so no Robux receipt can pay twice. The line under the buttons reads what the server wrote.
section("ECONOMY  (Sparks + owned Elements, through PlayerData)")
do
	-- (2026-10-23) +1000 SPARKS goes to the SPARKS TARGET (the list at the top); UNLOCK ALL and RESET are still you
	local ecoRow = buttonRow({
		{ "+1000 SPARKS", function()
			local t = sparksTarget()
			dev("EcoAddSparks", t.UserId)
			return ("+1000 SPARKS -> %s (asked the server)"):format(playerLabel(t))
		end },
		{ "UNLOCK ALL", function() dev("EcoUnlockAll") end },
		{ "RESET TO STARTER", function() dev("EcoReset") end },
	}, 3)
	sparksButton = ecoRow[1].button
	paintSparksTarget()
	local info = make("TextLabel", {
		BackgroundColor3 = C.Btn, BorderSizePixel = 0, LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Code, TextSize = 11, TextWrapped = true,
		TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 52,
	}, scroll)
	local function refresh()
		info.Text = (" SPARKS %s   LOADED %s\n OWNED %s"):format(tostring(player:GetAttribute("Sparks") or "-"),
			tostring(player:GetAttribute("DataLoaded")), tostring(player:GetAttribute("OwnedElements") or "-"))
	end
	for _, a in ipairs({ "Sparks", "OwnedElements", "DataLoaded" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()
end

section("ELEMENT KIT  (what the equipped Element gives you)")
do
	local info = make("TextLabel", {
		BackgroundColor3 = C.Btn, BorderSizePixel = 0, LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 54), Font = Enum.Font.Code, TextSize = 11,
		TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 52,
	}, scroll)
	local function refresh()
		local e = currentElement()
		local d = Config.Elements[e]
		if not d then info.Text = " ?"; return end
		-- the Ultimate comes with the Element too since v0.7 (2026-09-24), and an Element may name default Techniques
		local ult = Config.Ultimate[Config.ElementUltimate(e) or ""]
		local kit = (" %s\n M1      %s\n PRIMARY %s\n PASSIVE %s\n ULT     %s")
			:format(e:upper(), d.M1.Name, d.Primary.Name, d.Passive.Name, ult and ult.Name or "-")
		local extra = 1
		local defaults = Config.ElementDefaults[e]
		if defaults then
			local names = {}
			for _, slot in ipairs(Config.TechniqueSlots) do
				local entry = Config.Technique(defaults[slot])
				if entry then names[#names + 1] = entry.Name end
			end
			kit ..= ("\n DEFAULT %s"):format(table.concat(names, " + "))
			extra += 1
		end
		info.Text = kit
		info.Size = UDim2.new(1, 0, 0, 54 + 13 * extra)
	end
	player:GetAttributeChangedSignal("Element"):Connect(refresh)
	refresh()
	buttonRow({
		{ "CAST PRIMARY", function() castRemote:FireServer("Primary", {}) end },
		{ "CAST M1", function() castRemote:FireServer("M1", {}) end },
		-- (2026-10-19, audit P6A-22) through the dev remote: a client-set attribute never replicates, so the server and
		-- other clients never saw these (SpellshotService's dev handler sets PassiveActive on the character)
		{ "PASSIVE ON", function() dev("PassiveActive", true) end },
		{ "PASSIVE OFF", function() dev("PassiveActive", false) end },
	}, 4)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUES  (v0.7, 2026-09-24: two slots over one pool; the Ultimate is the Element's own)
----------------------------------------------------------------------------------------------------
-- Either slot takes any Technique in the pool (SpellshotConfig.Mobility + .Defense) through dev SetTechnique, which
-- refuses one the Element may not hold (Config.ElementMayHold: since P31, 2026-10-18, any other Element's) and the one
-- already in the other slot; the panel says
-- which instead of "sent". The slots are named as the player reads them (Config.SlotLabel); "Mobility" / "Defense" are
-- only the internal slot keys sent to the server. The 2026-09-23 Element-fixed slots are gone.
-- What a bare CAST (an empty payload straight to CastRequest) cannot do that the real key path in SpellshotInput does:
local BARE_CAST_NOTE = {
	Detonate = "refused free with no recent hit",
	ScorchingLash = "no whip from here: use the key",
}

local techniqueKeys = {}
for _, half in ipairs(Config.TechniqueSlots) do
	for k in pairs(Config[half]) do techniqueKeys[#techniqueKeys + 1] = k end
end
table.sort(techniqueKeys, function(a, b)
	local ea, eb = Config.Technique(a), Config.Technique(b)
	if ea.Origin ~= eb.Origin then return ea.Origin < eb.Origin end
	return a < b
end)

for _, slot in ipairs(Config.TechniqueSlots) do
	local label = Config.SlotLabel[slot]
	local other = (slot == "Mobility") and "Defense" or "Mobility"
	-- (2026-10-19, audit P4-14) under P31 (Config.TechniquesOwnElementOnly) a slot holds only the Element's own
	section(("%s  (%s)"):format(label:upper(),
		Config.TechniquesOwnElementOnly and "your Element's own" or ("any of %d"):format(#techniqueKeys)))
	local items = {}
	for _, k in ipairs(techniqueKeys) do
		local entry = Config.Technique(k)
		items[#items + 1] = { entry.Name:upper(), function()
			if not Config.ElementMayHold(currentElement(), k) then
				return ("%s is %s's only -- not sent"):format(entry.Name, entry.Origin)
			end
			if (player:GetAttribute(other) or Config.DefaultLoadout[other]) == k then
				return ("%s is already in %s -- not sent"):format(entry.Name, Config.SlotLabel[other])
			end
			dev("SetTechnique", slot, k)
			return nil
		end }
	end
	buttonRow(items, 2, 22)
	buttonRow({
		{ "CAST " .. label:upper(), function()
			castRemote:FireServer(slot, {})
			local key = player:GetAttribute(slot) or Config.DefaultLoadout[slot]
			local entry = Config.Technique(key)
			if entry and BARE_CAST_NOTE[key] then
				return ("%s sent -- %s"):format(entry.Name, BARE_CAST_NOTE[key])
			end
			return nil
		end },
	}, 1, 22)
end

section("ULTIMATE  (the Element's own)")
buttonRow({
	{ "CAST ULTIMATE", function()
		castRemote:FireServer("Ultimate", {})
		local own = Config.Ultimate[Config.ElementUltimate(currentElement()) or ""]
		return own and (own.Name .. " sent") or "sent -- this Element has no Ultimate"
	end },
}, 1, 22)

----------------------------------------------------------------------------------------------------
-- STATUS & BUFF REACTIONS
----------------------------------------------------------------------------------------------------
-- Every entry in the reactions brief gets a trigger. Sustained states are on/off pairs because
-- half of what you need to check is that they clear correctly; one-shots are single fires.
section("STATUS - SUSTAINED  (raise / lower)")
do
	local sustained = {
		{ "Burning", "Pyro" }, { "Chilled", "Cryo" }, { "Poisoned", "Toxin" },
		{ "Charged", "Voltaic" }, { "Shielded", "Pyro" }, { "Blessed", "Radiant" }, { "Marked", "Umbra" },
		{ "Stealth", "Umbra" }, { "VisionDenial", "Umbra" }, { "Haste", "Zephyr" },
		{ "ZoneWarning", "Pyro" },
	}
	local items = {}
	for _, s in ipairs(sustained) do
		items[#items + 1] = { "+" .. s[1], function() dev("SetStatus", s[1], true, s[2]) end }
		items[#items + 1] = { "-" .. s[1], function() dev("SetStatus", s[1], false) end }
	end
	buttonRow(items, 4, 22)
	buttonRow({ { "CLEAR ALL STATUSES", function()
		dev("ClearStatuses")
		local R = reactions()
		if R then R.ClearAll() end
	end } }, 1, 24)
end

-- ELEMENTAL APPLICATION (manual v0.13, 2026-09-24). Unlike the flag rows above, these run the REAL status: its stacks,
-- its clock, its damage (ServerScriptService.StatusEffects). The presets are the three balance reworks, live: every Chill,
-- Burn and status reads the preset at the moment it is used. "on dummy" puts it on the nearest training dummy FROM you;
-- "on me" puts it on you from no one, so your own HUD can be checked. HIT ME 20 lands through the damage pipeline (Mark's
-- bonus, Blessing's soak), which DMG 25 below skips.
section("ELEMENTAL APPLICATION  (real statuses; presets A / B / C)")
do
	local function preset(key, label)
		return { "PRESET " .. key .. ": " .. label, function()
			dev("StatusPreset", key)
			return "status preset " .. key .. " (" .. label .. ") -- applies to the next hit"
		end }
	end
	buttonRow({ preset("A", "SPEC"), preset("B", "THRESHOLD"), preset("C", "SOFT") }, 3, 24)
	local items = {}
	for _, k in ipairs({ "Poisoned", "Charged", "Marked", "Blessed" }) do
		items[#items + 1] = { k:upper() .. " ON DUMMY", function() dev("StatusApply", k, "dummy") end }
	end
	for _, k in ipairs({ "Poisoned", "Charged", "Marked", "Blessed" }) do
		items[#items + 1] = { k:upper() .. " ON ME", function() dev("StatusApply", k, "self") end }
	end
	items[#items + 1] = { "HIT ME 20", function() dev("StatusHit", 20) end }
	buttonRow(items, 4, 22)
end

-- ELEMENTAL REACTIONS (2026-10-17): put a status on the nearest dummy, then hit it with another Element (your M1, or a
-- Technique from another Element) to set off its reaction (ServerScriptService.ElementalReactions).
section("ELEMENTAL REACTIONS  (status on the nearest dummy, then hit it with another Element)")
do
	local items = {}
	for _, k in ipairs({ { "Burning", "BURN x2" }, { "Chilled", "CHILL x2" }, { "Rooted", "ROOT 4s" },
		{ "Poisoned", "POISON" }, { "Charged", "CHARGE x2" } }) do
		items[#items + 1] = { k[2] .. " ON DUMMY", function()
			dev("ReactionStatus", k[1])
			return k[2] .. " on the nearest dummy: now hit it with another Element"
		end }
	end
	buttonRow(items, 5, 22)
end

-- BAR FX (2026-09-24): the round-2 full-bar status looks, all 24, switchable live so people can be asked which they
-- prefer ("implement all and give me access in dev tools"). One row per status: A takeover / B assault / C living
-- fill / OLD (StatusReactions' previous look). PLAY runs that status's loop on your own bar with the current pick;
-- A>B>C plays the three in turn. The pick is the LocalPlayer attribute BarFX_<kind> (ReplicatedStorage.Spellshot.BarFX),
-- and StatusReactions steps aside for every status not set to OLD. Real statuses (the rows above and below) use the pick.
section("BAR FX  (status looks on the health bar: A / B / C / OLD;  PLAY previews on your bar)")
do
	local okFx, BarFX = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("BarFX", 10))
	end)
	if not okFx then
		buttonRow({ { "BAR FX FAILED TO LOAD", function() return tostring(BarFX) end } }, 1, 22)
	else
		local LETTER = { t = "A", a = "B", f = "C", old = "OLD" }
		local rows = {}
		local function title(kind, id)
			local V = id ~= "old" and BarFX.Variant(kind, id)
			return V and V.title or (id == "old" and "previous look" or "not loaded")
		end
		local function paintRow(kind)
			local pick = BarFX.Choice(kind)
			for _, m in ipairs(rows[kind] or {}) do
				m.button.BackgroundColor3 = (m.item.choice == pick) and C.BtnOn or C.Btn
			end
		end
		local function pickAll(id)
			for _, k in ipairs(BarFX.KINDS) do
				BarFX.SetChoice(k, id)
				paintRow(k)
			end
			return "every status -> " .. LETTER[id]
		end
		local function play(kind)
			local pick = BarFX.Choice(kind)
			if pick == "old" then return kind .. " is on OLD: raise the real status with the rows below to see it" end
			BarFX.Preview(kind, nil, 1)
			return kind .. ": playing " .. LETTER[pick] .. " " .. title(kind, pick)
		end
		buttonRow({
			{ "ALL A", function() return pickAll("t") end },
			{ "ALL B", function() return pickAll("a") end },
			{ "ALL C", function() return pickAll("f") end },
			{ "ALL OLD", function() return pickAll("old") end },
			{ "STOP PREVIEWS", function() BarFX.StopPreview() return "previews stopped" end },
		}, 5, 22)
		for _, kind in ipairs(BarFX.KINDS) do
			local items = { { kind:upper(), function()
				return ("%s:  A %s  |  B %s  |  C %s"):format(kind, title(kind, "t"), title(kind, "a"), title(kind, "f"))
			end } }
			for _, id in ipairs(BarFX.CHOICES) do
				local item = { LETTER[id], function()
					BarFX.SetChoice(kind, id)
					paintRow(kind)
					return kind .. " -> " .. LETTER[id] .. " " .. title(kind, id)
				end }
				item.choice = id
				items[#items + 1] = item
			end
			items[#items + 1] = { "PLAY", function() return play(kind) end }
			items[#items + 1] = { "A>B>C", function() BarFX.Compare(kind) return kind .. ": A, then B, then C" end }
			local made = buttonRow(items, 7, 22)
			rows[kind] = {}
			for _, m in ipairs(made) do
				if m.item.choice then table.insert(rows[kind], m) end
			end
			paintRow(kind)
		end
	end
end

-- Pyro phase two (2026-09-23): Detonate's mark and Scorching Lash's burn stacks carry more than the flag -- the mark's
-- fuse, the lash burn's stack count. SetStatus takes them as a table in place of the Element: Fuse (seconds) becomes
-- RX_Primed_Expires / _Total, Stacks becomes RX_Burning_Stacks, written before the flag as PyroHandler does; lowering
-- a kind clears them. A mark raised here is only the victim's picture: it runs out after its fuse and never explodes.
section("STATUS - PYRO MARK / BURN STACKS  (Detonate, Scorching Lash)")
do
	local function primed(seconds)
		dev("SetStatus", "Primed", true, { Element = "Pyro", Fuse = seconds })
	end
	local function burn(stacks)
		dev("SetStatus", "Burning", true, { Element = "Pyro", Stacks = stacks })
	end
	buttonRow({
		{ "+PRIMED 1.5s", function() primed(1.5) end },
		{ "+PRIMED 6s", function() primed(6) end },
		{ "-PRIMED", function() dev("SetStatus", "Primed", false) end },
		{ "-BURN", function() dev("SetStatus", "Burning", false) end },
		{ "BURN x1", function() burn(1) end },
		{ "BURN x2", function() burn(2) end },
		{ "BURN x3", function() burn(3) end },
	}, 4, 22)
end

section("STATUS - ONE-SHOT MOMENTS")
do
	local pulses = {
		{ "BURN TICK", "BurnTick", { Amount = 6 } },
		{ "KRAK (freeze)", "Krak" },
		{ "PUNISH", "Punish" },
		{ "SHIELD BREAK", "ShieldBreak" },
		{ "CLEANSE", "Cleanse" },
		{ "MANA SURGE", "SpendSurge" },
		{ "KNOCKBACK", "Knockback" },
		{ "PULL", "Pull" },
		{ "READY BURST", "Ready", { Slot = "SlotUltimate" } },
		{ "DECOY POOF", "DecoyPoof" },
	}
	local items = {}
	for _, p in ipairs(pulses) do
		items[#items + 1] = { p[1], function()
			local R = reactions()
			if R then R.Pulse(p[2], p[3]) else error("reactions not loaded") end
		end }
	end
	buttonRow(items, 2, 22)
end

section("STATUS - HEALTH / RESOURCE")
do
	buttonRow({
		{ "DMG 25", function() dev("Damage", 25) end },
		{ "DMG 60", function() dev("Damage", 60) end },
		{ "HEAL 25", function() dev("Heal", 25) end },
		{ "FULL HEAL", function() dev("Heal", 999) end },
		{ "SHIELD 25", function() dev("SetShield", 25) end },
		{ "SHIELD 0", function() dev("SetShield", 0) end },
		{ "ULT 0%", function() dev("SetUltCharge", 0) end },
		{ "ULT 50%", function() dev("SetUltCharge", 0.5) end },
	}, 4, 22)
end

section("STATUS - CROSSHAIR / ICON / FEED")
do
	buttonRow({
		{ "CROSSHAIR MARK ON", function()
			local H = hud(); if H then H.SetCrosshairMarked(true) end
		end },
		{ "CROSSHAIR MARK OFF", function()
			local H = hud(); if H then H.SetCrosshairMarked(false) end
		end },
		{ "CHARGE 25%", function() local H = hud(); if H then H.SetCharge("Defense", 0.25) end end },
		{ "CHARGE 75%", function() local H = hud(); if H then H.SetCharge("Defense", 0.75) end end },
		{ "CHARGE -> READY", function() local H = hud(); if H then H.SetCharge("Defense", 1) end end },
		{ "CHARGE CLEAR", function() local H = hud(); if H then H.SetCharge("Defense", 0) end end },
		{ "PUSH DUEL RESULT", function() dev("Kill", player.Name, "TESTDUMMY") end },
		{ "CLEAR DUEL FEED", function() local H = hud(); if H then H.ClearKills() end end },
	}, 2, 22)
end

section("STATUS - LEGACY TAG  (single Status attribute)")
do
	local names = {}
	for k in pairs(Config.Statuses) do names[#names + 1] = k end
	table.sort(names)
	local items = {}
	for _, n in ipairs(names) do
		items[#items + 1] = { n:upper(), function() dev("LegacyStatus", n, 8) end }
	end
	items[#items + 1] = { "CLEAR TAG", function() dev("LegacyStatus", nil) end }
	buttonRow(items, 3, 20)
end

----------------------------------------------------------------------------------------------------
-- MATCH STATE  (everything the old always-on overlay did)
----------------------------------------------------------------------------------------------------
section("MATCH STATE")
do
	local toggles = {
		{ "FREE ULTIMATE", "ToggleFreeUlt", "DevFreeUltimate" },
		{ "NO COOLDOWNS", "ToggleNoCooldowns", "DevNoCooldowns" },
		{ "FREE MANA", "ToggleFreeMana", "DevFreeMana" },
	}
	local made = {}
	local items = {}
	for _, t in ipairs(toggles) do
		items[#items + 1] = { t[1], function() dev(t[2]) end }
	end
	made = buttonRow(items, 3, 24)

	-- reflect live state so the panel shows what is actually on, not what was last clicked
	local function paint()
		local ch = player.Character
		for i, t in ipairs(toggles) do
			local on = ch and ch:GetAttribute(t[3])
			if made[i] then
				made[i].button.BackgroundColor3 = on and C.BtnOn or C.Btn
				made[i].button.Text = (on and "* " or "  ") .. t[1]
			end
		end
	end
	local function hook(ch)
		for _, t in ipairs(toggles) do
			ch:GetAttributeChangedSignal(t[3]):Connect(paint)
		end
		paint()
	end
	if player.Character then hook(player.Character) end
	player.CharacterAdded:Connect(function(ch) task.defer(hook, ch) end)

	buttonRow({
		{ "FILL ULT", function() dev("FillUlt") end },
		{ "RESET COOLDOWNS", function() dev("ClearCooldowns") end },
	}, 2, 24)
end

-- MOVEMENT (2026-10-18, movement switch): the team-mode switch. FULL is the game as it was; RUNNING ONLY keeps the run,
-- the crouch and one ground jump (no slide, slide-jump, wall run, wall jump or double jump). It asks the server --
-- MovementModeServer checks Config.IsDev -- which sets the workspace attribute MovementMode for every player at once.
-- The row paints from that attribute (else Config.Movement.Mode), so it shows what the server has, not the last click.
section("MOVEMENT  (team mode switch: every player on this server)")
do
	local modeRemote = folder:WaitForChild("MovementModeRequest", 10)
	local modes = { { "MOVEMENT: FULL", "Full" }, { "MOVEMENT: RUNNING ONLY", "RunningOnly" } }
	local items = {}
	for _, m in ipairs(modes) do
		items[#items + 1] = { m[1], function()
			if not modeRemote then return "ReplicatedStorage.Spellshot.MovementModeRequest is missing" end
			modeRemote:FireServer(m[2])
			return m[1] .. " -> asked the server"
		end }
	end
	local made = buttonRow(items, 2, 24)
	local function current()
		local m = workspace:GetAttribute("MovementMode")
		if m ~= "Full" and m ~= "RunningOnly" then m = Config.Movement.Mode end
		return m == "RunningOnly" and "RunningOnly" or "Full"
	end
	local function paint()
		local now = current()
		for i, m in ipairs(modes) do
			local on = now == m[2]
			if made[i] then
				made[i].button.BackgroundColor3 = on and C.BtnOn or C.Btn
				made[i].button.Text = (on and "* " or "  ") .. m[1]
			end
		end
	end
	workspace:GetAttributeChangedSignal("MovementMode"):Connect(paint)
	paint()
	if modeRemote then
		modeRemote.OnClientEvent:Connect(function(what)
			if what == "denied" then
				say("The SERVER refused the movement switch: this account is not a dev on this server.")
			end
		end)
	end
end

section("SCENARIOS  (stacked cases from the clash rules)")
do
	buttonRow({
		{ "R1 FILL CLASH: burn->chill", function()
			dev("SetStatus", "Burning", true, "Pyro")
			task.delay(0.8, function() dev("SetStatus", "Chilled", true, "Cryo") end)
		end },
		{ "R2 ZONE + SHIELD", function()
			dev("SetStatus", "Shielded", true, "Radiant")
			dev("SetStatus", "ZoneWarning", true)
		end },
		{ "R2 ZONE, NO SHIELD", function()
			dev("SetStatus", "Shielded", false)
			dev("SetStatus", "ZoneWarning", true)
		end },
		{ "R3 EDGE STACK", function()
			dev("SetStatus", "Stealth", true, "Umbra")
			dev("SetStatus", "Marked", true, "Umbra")
			task.delay(0.9, function() dev("SetStatus", "VisionDenial", true, "Umbra") end)
		end },
		{ "R4 HASTE + KNOCKBACK", function()
			dev("SetStatus", "Haste", true, "Zephyr")
			task.delay(1.0, function()
				local R = reactions()
				if R then R.Pulse("Knockback") end
			end)
		end },
		{ "EVERYTHING AT ONCE", function()
			for _, k in ipairs({ "Burning", "Chilled", "Poisoned", "Charged", "Shielded",
								 "Marked", "Haste" }) do
				dev("SetStatus", k, true)
			end
		end },
	}, 1, 24)
end

----------------------------------------------------------------------------------------------------
-- toggle
----------------------------------------------------------------------------------------------------
-- FREEING THE CURSOR IS THE WHOLE PROBLEM WITH A PANEL IN A FIRST-PERSON GAME.
-- The player is locked to first person, so Roblox's CameraModule re-applies
-- MouseBehavior = LockCenter during its own render step, every frame. Assigning the property
-- once is undone before the next click lands: the cursor snaps back to the middle of the screen
-- and nothing in the panel can be clicked or scrolled. Neither CameraMode = Classic nor raising
-- CameraMaxZoomDistance releases it, because the camera is still AT first-person distance.
--
-- So re-assert it AFTER the camera has run, on a render step bound above Camera priority. That
-- wins every frame for as long as the panel is open, and unbinding hands the lock straight back.
local CURSOR_STEP = "SpellshotDevPanelCursor"
local cursorBound = false

local function holdCursorFree(hold)
	if hold == cursorBound then return end
	cursorBound = hold
	if hold then
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
	end
end

local function setOpen(open)
	gui.Enabled = open
	holdCursorFree(open)
	if open then
		say("';' closes. The cursor is free, so the mouse stops turning the camera.")
	end
end

-- The server drops a dev request from a player it does not consider a dev, and used to do it in
-- silence. On a Team Test server -- a real Roblox server, where IsStudio() is false -- that is
-- exactly what a panel with dead buttons looks like.
devRemote.OnClientEvent:Connect(function(what, serverIsStudio)
	-- (2026-10-23) the server's answer to +1000 SPARKS: who got them, or why not (the second value is its message)
	if what == "eco" then say(tostring(serverIsStudio)) return end
	if what ~= "denied" then return end
	say("The SERVER refused that: this account is not a dev on this server."
		.. (serverIsStudio and "" or " This is a real server (Team Test or live), not a Studio"
			.. " playtest, so it needs Config.Dev.AllowInLiveGame and the owner or a UserIds entry."))
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_KEY then
		-- only a dev may even OPEN the panel (owner, 2026-09-24: "only us two can press ; to open the tab anyway let
		-- alone use it"): Config.IsDev -- the place owner and Config.Dev.UserIds on a real server, whoever is playing in
		-- a Studio test. The server still refuses every dev request from anyone else.
		if not Config.IsDev(player) then
			if gui.Enabled then setOpen(false) end
			return
		end
		setOpen(not gui.Enabled)
	end
end)

setOpen(false)
return nil
