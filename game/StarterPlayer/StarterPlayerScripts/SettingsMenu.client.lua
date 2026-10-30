--[[
	SettingsMenu  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/SettingsMenu

	BUILD PROMPT #15, STAGES 1 AND 2. A gear at the top right opens the settings panel; every row
	drives a real setting, and every setting is saved per player.

	THE MENU IS THIN. A row says what it is called, what it does in plain words, and which setting
	it drives. The range, the option list and the default all come from that setting's definition in
	SpellshotSettings, so the menu cannot promise a range the store will not accept. Changing a row
	calls Settings.Set and nothing else -- the script that owns the behaviour is listening.

	THE LAYOUT IS OURS, NOT RIVALS'. RIVALS' menu was captured from the live game as reference
	(settings_reference/) and four patterns were drawn from it; the user picked a combination of two
	(settings_reference/layouts/):

	  * THE SPREAD -- two columns, so a whole category fits with NO scrolling, and help arrives as a
	    comic speech bubble pinned to the row the pointer is on rather than a fixed panel of text.
	  * THE STAGE -- on the categories that can show something, the top of the right column is a
	    live preview that reacts to the row you are changing: the crosshair draws itself, the
	    Element palette shows its chips, the view shows its own brightness and field of view.

	So: one page per category, everything visible at once, and the right-hand space does work
	instead of holding a paragraph.

	SKIN: NEWSPRINT, picked from four treatments (settings_reference/layouts/skin_*.png). Paper
	stock under a coarse ink dot screen, heavy black rules, square-ish corners, hard offset
	shadows, red banner headings set in Bangers, red as the only accent. No gloss anywhere: no
	gradient, no soft corner, no glow.

	PLATFORM: a touch device and a keyboard/controller device get separate lists, never one list
	with dead rows. Touch-only devices get Controls (touch); everything else gets Controls (camera
	and keybinds). Mute When Unfocused is absent on mobile. In Studio only, the player attribute
	SettingsPreviewPlatform ("Mobile" / "PC") previews the other list.

	WHERE THE GEAR SITS: the strip along the top of the screen that Roblox's own buttons use,
	mirrored on the right. The HUD's top-right corner below it belongs to the recent-duel feed.

	KEYBINDS. A cap in the KEY or PAD column captures the next key or gamepad button you press.
	Escape cancels, Backspace clears it, and taking a key another role already holds SWAPS the two
	rather than leaving a role unbound. A keyboard cap refuses a gamepad button and a pad cap
	refuses a key, so a column can never end up holding the other kind. Keys that Roblox consumes
	before a script sees them (backslash, full stop) are refused as well -- binding one would look
	like it worked and then do nothing.

	For tools: the ScreenGui carries a BindableEvent "Command" -- Fire("open"), Fire("close"),
	Fire("tab", id), Fire("hover", rowLabel), Fire("set", settingId, value), Fire("reset"). The last
	two exist because a tool running code in its own thread gets its own copy of the settings module
	and cannot reach this one any other way.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot")
	:WaitForChild("SpellshotSettings"))

-- rendered on the HUD icon rig (blender: build_settings_icons.py)
local ICON = {
	Gear = "rbxassetid://109672425631202",
	Video = "rbxassetid://100556252346579",
	Controls = "rbxassetid://105172386041661",
	Touch = "rbxassetid://94879763757102",
	Audio = "rbxassetid://124973600015567",
	HUD = "rbxassetid://106225559355801",
	Access = "rbxassetid://96082761888316",
}
local DOT = "rbxassetid://82944445925061"     -- BarKit's halftone cell: one white dot per tile

local C = {
	Ink = Color3.fromRGB(17, 17, 17),
	Cream = Color3.fromRGB(238, 230, 214),
	White = Color3.new(1, 1, 1),
	Red = Color3.fromRGB(228, 37, 31),
	Gold = Color3.fromRGB(245, 184, 0),
	Cyan = Color3.fromRGB(18, 198, 231),
	Green = Color3.fromRGB(126, 204, 36),
	Pink = Color3.fromRGB(236, 72, 153),
	Grey = Color3.fromRGB(120, 116, 106),
	Track = Color3.fromRGB(222, 213, 196),
	Sky = Color3.fromRGB(84, 122, 150),
	Ground = Color3.fromRGB(96, 104, 96),

	-- NEWSPRINT skin: paper stock, a coarse ink dot screen, heavy black rules, red banner headings
	-- in Bangers. No gloss anywhere -- nothing is a gradient and no corner is soft.
	Paper = Color3.fromRGB(234, 229, 216),
	Card = Color3.fromRGB(246, 243, 235),
	Pill = Color3.fromRGB(250, 247, 240),
	RedInk = Color3.fromRGB(200, 30, 26),
	CreamText = Color3.fromRGB(250, 244, 232),
	CreamDim = Color3.fromRGB(206, 200, 188),
	Hover = Color3.fromRGB(224, 218, 202),
}

local DESIGN_W, DESIGN_H = 1000, 620
local TAB_H = 56
local BODY_Y = TAB_H + 14
local COL_W, COL_GAP = 470, 20
local STAGE_H = 196
local ROW_GAP = 7
local CURSOR_STEP = "SpellshotSettingsCursor"

----------------------------------------------------------------------------------------------------
-- which list this device gets
----------------------------------------------------------------------------------------------------
local function platform()
	if RunService:IsStudio() then
		local forced = player:GetAttribute("SettingsPreviewPlatform")
		if forced == "Mobile" or forced == "PC" then return forced end
	end
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "Mobile" or "PC"
end

----------------------------------------------------------------------------------------------------
-- the rows
----------------------------------------------------------------------------------------------------
-- Id names the setting in SpellshotSettings. Everything numeric or optional about a row -- its
-- range, its step, its choices, its default -- lives with the setting, not here.
local function tabs(plat)
	local list = {
		{ Id = "Video", Title = "VIDEO", Icon = "Video", Stage = "view", Rows = {
			{ Kind = "section", Label = "Display" },
			{ Kind = "choice", Label = "Graphics Quality", Id = "GraphicsQuality",
				Desc = "How much the game draws: shadows and effect density. Lower runs smoother on slower devices." },
			{ Kind = "slider", Label = "Field of View", Id = "FieldOfView", Unit = "", Live = true,
				Desc = "How wide your view is, in degrees. The first-person arms are fitted at 90, so they read a little larger below it." },
			-- 2026-10-27 (the owner: "a small button to go third person so mobile players can do too, put it in settings")
			{ Kind = "toggle", Label = "Third Person", Id = "ThirdPerson",
				Desc = "Shows your whole character from a camera behind your shoulder instead of the first-person arms. Shots still leave from your head, so up close one can land a little off the crosshair. On PC, V switches it too." },
			{ Kind = "slider", Label = "Brightness", Id = "Brightness", Unit = "%", Live = true,
				Desc = "Brightens or darkens the picture. This is the picture, not the sun: it never changes how the map is lit for anyone else." },
			{ Kind = "section", Label = "Effects" },
			{ Kind = "slider", Label = "Camera Shake", Id = "CameraShake", Unit = "%",
				Desc = "How hard the camera punches on a cast. The crouch and slide dip is not shake and is never scaled." },
			{ Kind = "slider", Label = "Motion Blur", Id = "MotionBlur", Unit = "%",
				Desc = "How much the view smears while you are turning fast. Nothing below a real flick: a walk or a small aim correction stays sharp. 0 turns it off outright." },
			{ Kind = "toggle", Label = "Reduce Enemy VFX", Id = "ReduceEnemyVFX",
				-- (2026-10-19, audit P5F-20) what it does, not "halves the particles": the cut varies by effect.
				-- (2026-10-19, audit P5F-06, wave 2) enemies only: VFXLibrary.IsEnemy spares your own and your teammates'
				Desc = "Thins your enemies' effects (not yours or your teammates') so busy fights stay readable: about half the particles, and some extra layers dropped. Clarity and performance only -- hitboxes never change." },
		} },
	}
	if plat == "Mobile" then
		table.insert(list, { Id = "Controls", Title = "CONTROLS", Icon = "Touch", Rows = {
			{ Kind = "section", Label = "Touch" },
			{ Kind = "slider", Label = "Touch Sensitivity", Id = "TouchSensitivity", Unit = "%",
				Desc = "How far the camera turns for each swipe: from an eighth of Roblox's own touch turn up to five times it. 1.00x in the middle leaves it unchanged." },
			{ Kind = "toggle", Label = "Camera Assist", Id = "CameraAssist",
				Desc = "Helps the camera follow a target you are tracking on touch. Camera assist, not aim assist: it never moves your aim onto anyone. Saved; not built yet." },
			{ Kind = "toggle", Label = "M1 Auto-Fire", Id = "AutoFire",
				Desc = "Hold to keep firing at the M1's own fire rate instead of tapping for each shot." },
			{ Kind = "section", Label = "Buttons" },
			{ Kind = "slider", Label = "Button Size", Id = "ButtonSize", Unit = "%",
				Desc = "Size of the on-screen buttons: Fire, Jump, Slide and the four abilities." },
			{ Kind = "slider", Label = "Button Opacity", Id = "ButtonOpacity", Unit = "%",
				Desc = "How solid the body of each on-screen button is drawn. Lower lets you see the fight through them; the icons stay solid." },
			{ Kind = "toggle", Label = "Left-Handed Layout", Id = "LeftHanded",
				Desc = "Mirrors the controls: ability buttons on the left, the move stick on the right. Saved; not built yet." },
			{ Kind = "button", Label = "Reposition Buttons", Button = "EDIT LAYOUT",
				Desc = "Drag each button to wherever your thumbs want it. Needs the touch buttons, which are not built yet." },
		} })
	else
		table.insert(list, { Id = "Controls", Title = "CONTROLS", Icon = "Controls", Rows = {
			{ Kind = "section", Label = "Camera" },
			{ Kind = "slider", Label = "Sensitivity", Id = "Sensitivity", Unit = "",
				Desc = "How far the camera turns for each move of the mouse: from an eighth of your Roblox sensitivity up to five times it. 1.00x in the middle leaves it unchanged, and every notch either side is the same step." },
			{ Kind = "slider", Label = "While Channeling", Id = "ChannelSensitivity", Sub = true, Unit = "%",
				Desc = "Your sensitivity while you hold a channel, such as the Ultimate's beam, as a percentage of the one above. 60% by default, so a held beam is easier to keep on a target." },
			{ Kind = "toggle", Label = "Invert Y-Axis", Id = "InvertY",
				Desc = "Moving the mouse or stick up looks down." },
			{ Kind = "section", Label = "Movement" },
			{ Kind = "toggle", Label = "Toggle Crouch", Id = "ToggleCrouch",
				Desc = "Crouch stays down when you tap the key, instead of only while you hold it. A slide still needs the press while you are moving fast, and still ends by itself." },
			{ Kind = "section", Label = "Keybinds", Columns = { "KEY", "PAD" } },
			{ Kind = "keybind", Label = "Primary Ability", Id = "Bind_Primary", Pad = "Pad_Primary",
				Desc = "Your Element's signature ability." },
			{ Kind = "keybind", Label = "Technique 1", Id = "Bind_Mobility", Pad = "Pad_Mobility",
				Desc = "The first of your two Techniques (Q unless you rebind it here)." },
			{ Kind = "keybind", Label = "Technique 2", Id = "Bind_Defense", Pad = "Pad_Defense",
				Desc = "The second of your two Techniques (E unless you rebind it here)." },
			{ Kind = "keybind", Label = "Ultimate", Id = "Bind_Ultimate", Pad = "Pad_Ultimate",
				Desc = "Your Element's Ultimate, once it is charged." },
			{ Kind = "keybind", Label = "Crouch", Id = "Bind_Crouch", Pad = "Pad_Crouch",
				Desc = "Crouch. Pressed while you are moving fast, the same key slides." },
			{ Kind = "keybind", Label = "Slide", Mirror = "Bind_Crouch", PadMirror = "Pad_Crouch",
				Desc = "Slide is crouch entered at speed, so it is the same key as Crouch and follows it. Rebind Crouch to move both." },
			{ Kind = "keybind", Label = "Interact", Id = "Bind_Interact", Pad = "Pad_Interact",
				Desc = "Hold at a prompt in the Hub: the shrines, the Binding Table, the Ledger, the Cache Vault and the Duel Pads. Unbound, the Hub uses G." },
		} })
	end
	local audio = { Id = "Audio", Title = "AUDIO", Icon = "Audio", Rows = {
		{ Kind = "section", Label = "Volume" },
		{ Kind = "slider", Label = "Master", Id = "VolMaster", Unit = "%", Desc = "Everything the game plays." },
		{ Kind = "slider", Label = "Sound Effects", Id = "VolSFX", Sub = true, Unit = "%", Desc = "Casts, hits, footsteps and the world." },
		{ Kind = "slider", Label = "Music", Id = "VolMusic", Sub = true, Unit = "%", Desc = "Menu and match music." },
		{ Kind = "slider", Label = "Interface", Id = "VolInterface", Sub = true, Unit = "%", Desc = "Clicks, ticks and menu sounds." },
	} }
	if plat ~= "Mobile" then
		table.insert(audio.Rows, { Kind = "toggle", Label = "Mute When Unfocused", Id = "MuteUnfocused",
			Desc = "Silences the game while its window is in the background." })
	end
	table.insert(list, audio)
	table.insert(list, { Id = "HUD", Title = "HUD", Icon = "HUD", Stage = "crosshair", Rows = {
		{ Kind = "section", Label = "Crosshair" },
		{ Kind = "swatch", Label = "Color", Id = "CrosshairColor", Swatch = Settings.CrosshairColors,
			Desc = "The crosshair's fill colour.", Live = true },
		{ Kind = "choice", Label = "Shape", Id = "CrosshairShape", Desc = "The crosshair's shape.", Live = true },
		{ Kind = "slider", Label = "Size", Id = "CrosshairSize", Unit = "%", Desc = "How big the crosshair is drawn.", Live = true },
		{ Kind = "slider", Label = "Outline", Id = "CrosshairOutline", Unit = " px",
			Desc = "Thickness of the ink outline round the crosshair.", Live = true },
		{ Kind = "section", Label = "Combat" },
		{ Kind = "toggle", Label = "Damage Numbers", Id = "DamageNumbers", Desc = "Numbers that pop off whatever you hit." },
		{ Kind = "toggle", Label = "Compass", Id = "Compass", Desc = "A strip at the top of the screen showing which way you are facing, in degrees. Shown during matches." },
		{ Kind = "slider", Label = "Status Intensity", Id = "StatusIntensity", Unit = "%",
			Desc = "How strong burning, chilled, poisoned and the other status treatments are on your HUD. Worth lowering when several Elements stack in Squad Clash." },
		{ Kind = "section", Label = "Layout" },
		{ Kind = "slider", Label = "UI Size", Id = "UIScale", Unit = "%",
			Desc = "Scales the whole HUD by one ratio: the health and mana bars, the ability slots, the round counter, the duel feed and the status treatments all together. On top of the automatic fit to your screen." },
		{ Kind = "slider", Label = "HUD Opacity", Id = "HUDOpacity", Unit = "%", Desc = "How solid the HUD is drawn." },
		{ Kind = "slider", Label = "Kill Feed Duration", Id = "KillFeedDuration", Unit = " s",
			Desc = "How long each duel result stays in the feed before it goes." },
	} })
	table.insert(list, { Id = "Access", Title = "ACCESS", Icon = "Access", Stage = "palette", Rows = {
		{ Kind = "section", Label = "Vision" },
		{ Kind = "toggle", Label = "Colorblind-Safe Elements", Id = "ColorblindSafe", Live = true,
			-- (2026-10-19, audit P5F-08 / P5F-20) the row says what it reaches: the uniforms, nothing else
			Desc = "Repaints player uniforms so the two Element pairs that collide -- Pyro against Terra, Toxin against Cryo -- stay apart (Terra turns violet, Toxin teal). Ability effects, the HUD and icon art keep their own colours." },
		{ Kind = "toggle", Label = "Reduce Flashing", Id = "ReduceFlashing",
			Desc = "Softens the full-screen impact bursts and the vignette, and turns camera shake off." },
		{ Kind = "slider", Label = "Text Size", Id = "TextSize", Unit = "%", Live = true,
			Desc = "Scales the text on the HUD and in this menu." },
	} })
	-- Every page ends with its own reset, the way RIVALS does it: this page only, and two taps so a
	-- stray click cannot undo an evening of fiddling.
	for _, tab in ipairs(list) do
		local ids = {}
		for _, row in ipairs(tab.Rows) do
			if row.Id then table.insert(ids, row.Id) end
			if row.Pad then table.insert(ids, row.Pad) end
		end
		table.insert(tab.Rows, { Kind = "reset", Label = "Reset " .. tab.Title, Ids = ids,
			Desc = "Puts every setting on this page back to its default, and nothing on any other page. Tap it twice." })
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- building blocks
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
		BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = C.Ink, TextSize = 16,
		Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props) do t[k] = v end
	return t
end

local function halftone(parent, radius, alpha, colour, pitch)
	local h = make("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = DOT, ImageColor3 = colour or C.White,
		ImageTransparency = alpha or 0.88, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(pitch or 9, pitch or 9),
		Size = UDim2.fromScale(1, 1), ZIndex = 2,
	}, parent)
	corner(h, radius)
	return h
end

--- A kit block: flat colour, ink outline, hard offset shadow. Returns holder, face.
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

----------------------------------------------------------------------------------------------------
-- the screen
----------------------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("SettingsMenu")
if old then old:Destroy() end

local gui = make("ScreenGui", {
	Name = "SettingsMenu", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local command = make("BindableEvent", { Name = "Command" }, gui)

-- the gear: a kit chip in the top strip, mirroring Roblox's own buttons on the left
local gearSize = (platform() == "Mobile") and 52 or 44
local gearHolder, gearFace = slab(gui, UDim2.fromOffset(gearSize + 3, gearSize + 3), nil, C.Pill, 5, 3)
gearHolder.Name = "GearButton"
gearHolder.AnchorPoint = Vector2.new(1, 0)
gearHolder.Position = UDim2.new(1, -14, 0, 7)
local gearImage = make("ImageLabel", {
	Name = "Gear", BackgroundTransparency = 1, Image = ICON.Gear, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9), ZIndex = 3,
}, gearFace)
local gearHit = hitbox(gearFace)

local backdrop = make("TextButton", {
	Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10,
}, gui)
make("ImageLabel", {
	BackgroundTransparency = 1, Image = DOT, ImageColor3 = C.White, ImageTransparency = 0.94,
	ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(12, 12), Size = UDim2.fromScale(1, 1), ZIndex = 10,
}, backdrop)

local holder = make("Frame", {
	Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), ZIndex = 11,
}, backdrop)
local fitScale = make("UIScale", {}, holder)
local panel = make("Frame", { Name = "Panel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11 }, holder)
local popScale = make("UIScale", {}, panel)

-- the page the columns sit on: one cream sheet, so the spread reads as a page and not as two lists
local sheetHolder, sheet = slab(panel, UDim2.fromOffset(DESIGN_W, DESIGN_H - BODY_Y), UDim2.fromOffset(0, BODY_Y), C.Paper, 8, 7)
halftone(sheet, 8, 0.78, C.Ink, 7)

-- tab strip
local _, bar = slab(panel, UDim2.fromOffset(DESIGN_W - 104, TAB_H), UDim2.fromOffset(0, 0), C.Ink, 6, 4)
halftone(bar, 6, 0.86)
local tabRow = make("Frame", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ZIndex = 3,
}, bar)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
}, tabRow)

local _, closeFace = slab(panel, UDim2.fromOffset(88, TAB_H), UDim2.new(1, -88, 0, 0), C.Ink, 6, 4)
local closeX = text(closeFace, {
	Font = Enum.Font.LuckiestGuy, Text = "X", TextSize = 38, TextColor3 = C.White,
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 3), ZIndex = 3,
})
make("UIStroke", { Color = C.Ink, Thickness = 3 }, closeX)
local closeHit = hitbox(closeFace)

-- the two columns of the spread
local page = make("Frame", {
	Name = "Page", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, BODY_Y + 14),
	Size = UDim2.fromOffset(DESIGN_W - 32, DESIGN_H - BODY_Y - 28), ZIndex = 12,
}, panel)
local columns = {
	make("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.fromOffset(COL_W, page.Size.Y.Offset), ZIndex = 12 }, page),
	make("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromOffset(COL_W + COL_GAP, 0),
		Size = UDim2.fromOffset(COL_W, page.Size.Y.Offset), ZIndex = 12 }, page),
}

----------------------------------------------------------------------------------------------------
-- the speech bubble: the help text, pinned to the row the pointer is on
----------------------------------------------------------------------------------------------------
local SPECS = {}          -- [row label] = spec, so a tool can ask for a row by name
local BUBBLE_W = 360
local bubbleHolder, bubbleFace = slab(panel, UDim2.fromOffset(BUBBLE_W, 140), nil, C.Card, 6, 5)
bubbleHolder.Name = "Bubble"
bubbleHolder.ZIndex = 30
bubbleHolder.Visible = false
bubbleFace.ZIndex = 30
local bubbleTitle = text(bubbleFace, {
	Font = Enum.Font.Bangers, TextSize = 23, TextColor3 = C.RedInk, Position = UDim2.fromOffset(14, 6),
	Size = UDim2.new(1, -28, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 31,
})
local bubbleBody = text(bubbleFace, {
	Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 1, -44), ZIndex = 31,
})
-- the tail: a square turned on its corner, tucked behind the face, with the face's own outline
-- patched over where the two meet
local bubbleTail = make("Frame", {
	Name = "Tail", BackgroundColor3 = C.Card, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(22, 22), Rotation = 45, ZIndex = 29,
}, bubbleHolder)
outline(bubbleTail, 2)
local bubblePatch = make("Frame", {
	Name = "Patch", BackgroundColor3 = C.Card, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(6, 26), ZIndex = 32,
}, bubbleFace)

local hideAt = 0

local function showBubble(rowFace, spec)
	-- (hoverRow below is the same thing, by row name, for tools)
	if not spec.Desc then return end
	bubbleTitle.Text = string.upper(spec.Label)
	bubbleBody.Text = spec.Desc
	-- measured at the body's own size (2026-10-19, audit P5F-19: Text Size scales it)
	local bounds = TextService:GetTextSize(spec.Desc, bubbleBody.TextSize, Enum.Font.GothamBold, Vector2.new(BUBBLE_W - 28, 1000))
	local h = math.max(78, bounds.Y + 50)
	bubbleHolder.Size = UDim2.fromOffset(BUBBLE_W, h)
	-- which column the row is in decides the side the bubble sits on
	local rowLeft = rowFace.AbsolutePosition.X - page.AbsolutePosition.X
	local onLeft = rowLeft < (COL_W + COL_GAP) * 0.5
	local y = rowFace.AbsolutePosition.Y - panel.AbsolutePosition.Y
	y = math.clamp(y / math.max(0.01, fitScale.Scale * popScale.Scale) - 10, BODY_Y + 10,
		math.max(BODY_Y + 10, holder.Size.Y.Offset - h - 14))
	local x = onLeft and (COL_W + COL_GAP + 24) or (DESIGN_W - COL_W - COL_GAP - BUBBLE_W - 24)
	bubbleHolder.Position = UDim2.fromOffset(x, y)
	local tailX = onLeft and 0 or BUBBLE_W - 5
	local rowMid = rowFace.AbsoluteSize.Y * 0.5 / math.max(0.01, fitScale.Scale * popScale.Scale)
	local tailY = math.clamp(rowFace.AbsolutePosition.Y - panel.AbsolutePosition.Y, 0, 10000)
	tailY = math.clamp(tailY / math.max(0.01, fitScale.Scale * popScale.Scale) + rowMid - y, 22, h - 22)
	bubbleTail.Position = UDim2.fromOffset(tailX, tailY)
	bubblePatch.Position = UDim2.fromOffset(onLeft and 2 or BUBBLE_W - 7, tailY)
	bubbleHolder.Visible = true
end

local function hoverRow(face, label)
	local spec = SPECS[label]
	if spec then showBubble(face, spec) end
end

local function hideBubble()
	hideAt = os.clock() + 0.05
	task.delay(0.08, function()
		if os.clock() >= hideAt then bubbleHolder.Visible = false end
	end)
end

----------------------------------------------------------------------------------------------------
-- controls
----------------------------------------------------------------------------------------------------
local conns = {}          -- global input hooks, dropped when the tab changes
local liveUpdate          -- set per tab: the stage's refresh, called when a Live row changes

local function fmt(spec, v)
	-- a Curve setting's number is only where the knob sits; it reads out as the multiplier it gives (Build Prompt #25)
	local d = Settings.ById[spec.Id]
	local special = d and Settings.Readout(d, v)
	if special then return special end
	return tostring(math.floor(v + 0.5)) .. (spec.Unit or "")
end

--- The definition behind a row: where its range, its options and its default actually live.
local function def(spec)
	return Settings.ById[spec.Id]
end

local function valueOf(spec)
	return Settings.Get(spec.Id)
end

--- One way in and out for every control. The store validates, saves and tells whoever owns the
--- behaviour; the only thing left for the menu to do is refresh its own preview.
local function setValue(spec, v)
	Settings.Set(spec.Id, v)
	if spec.Live and liveUpdate then liveUpdate() end
end

local function toggleControl(face, spec)
	local on = valueOf(spec) and true or false
	local pill = make("TextButton", {
		Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 20),
		Size = UDim2.fromOffset(56, 26), BackgroundColor3 = C.Track, BorderSizePixel = 0, ZIndex = 14,
	}, face)
	corner(pill, 13)
	outline(pill, 2)
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.Ink,
		BorderSizePixel = 0, ZIndex = 15,
	}, pill)
	corner(knob, 10)
	outline(knob, 2)
	local function show(anim)
		local goal = { Position = on and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = on and C.White or C.Ink }
		if anim then
			TweenService:Create(knob, TweenInfo.new(0.12), goal):Play()
			TweenService:Create(pill, TweenInfo.new(0.12), { BackgroundColor3 = on and C.Green or C.Track }):Play()
		else
			knob.Position, knob.BackgroundColor3 = goal.Position, goal.BackgroundColor3
			pill.BackgroundColor3 = on and C.Green or C.Track
		end
	end
	show(false)
	pill.Activated:Connect(function()
		on = not on
		setValue(spec, on)
		show(true)
	end)
	table.insert(conns, Settings.OnChange(spec.Id, function(v)
		on = v and true or false
		show(true)
	end))
end

local function sliderControl(face, spec)
	local d = def(spec)
	local lo, hi, step = d.Min, d.Max, d.Step or 1
	local value = valueOf(spec)
	local box = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 20), Size = UDim2.fromOffset(68, 26),
		BackgroundColor3 = C.Pill, BorderSizePixel = 0, ZIndex = 20,
	}, face)
	corner(box, 4)
	outline(box, 2)
	local valueText = text(box, { TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 21 })
	local stepper = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -88, 0, 20), Size = UDim2.fromOffset(24, 26),
		BackgroundColor3 = C.Ink, BorderSizePixel = 0, ZIndex = 20,
	}, face)
	corner(stepper, 4)
	-- drawn, not typed: the triangle glyphs fall back to a font that renders them as specks
	local function chevron(pointsUp)
		local b = make("TextButton", {
			Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = pointsUp and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0.5, 0), ZIndex = 15,
		}, stepper)
		for _, side in ipairs({ -1, 1 }) do
			local arm = make("Frame", {
				BackgroundColor3 = C.White, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, side * 3, 0.5, 0), Size = UDim2.fromOffset(8, 3),
				Rotation = (pointsUp and 1 or -1) * side * 38, ZIndex = 16,
			}, b)
			corner(arm, 2)
		end
		return b
	end
	local up, down = chevron(true), chevron(false)
	local TRACK_X = 168
	local trackW = COL_W - 124 - TRACK_X
	local track = make("TextButton", {
		Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, TRACK_X, 0, 20),
		Size = UDim2.fromOffset(trackW, 10), BackgroundColor3 = C.Track, BorderSizePixel = 0, ZIndex = 14,
	}, face)
	corner(track, 3)
	outline(track, 2)
	local fill = make("Frame", { BackgroundColor3 = C.RedInk, BorderSizePixel = 0, ZIndex = 15 }, track)
	corner(fill, 3)
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.White,
		BorderSizePixel = 0, ZIndex = 16,
	}, track)
	corner(knob, 9)
	outline(knob, 2)
	local function show()
		local a = Settings.ToTrack(d, value)          -- a log track puts equal ratios, not equal numbers, under the knob
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueText.Text = fmt(spec, value)
	end
	local function set(v)
		value = math.clamp(lo + math.floor((v - lo) / step + 0.5) * step, lo, hi)
		setValue(spec, value)
		show()
	end
	-- a change from anywhere else (a load from the save, a tool) moves the knob too
	table.insert(conns, Settings.OnChange(spec.Id, function(v)
		value = v
		show()
	end))
	up.Activated:Connect(function() set(value + step) end)
	down.Activated:Connect(function() set(value - step) end)
	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		set(Settings.FromTrack(d, a))
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	show()
end

local function choiceControl(face, spec)
	local options = def(spec).Options
	local i = valueOf(spec)
	local box = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 20), Size = UDim2.fromOffset(186, 26),
		BackgroundColor3 = C.Pill, BorderSizePixel = 0, ZIndex = 14,
	}, face)
	corner(box, 4)
	outline(box, 2)
	local label = text(box, { TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15 })
	local function arrow(glyph, atRight, dir)
		local b = make("TextButton", {
			Text = glyph, Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = C.White, BackgroundColor3 = C.Ink,
			AutoButtonColor = false, BorderSizePixel = 0, AnchorPoint = Vector2.new(atRight and 1 or 0, 0),
			Position = UDim2.new(atRight and 1 or 0, 0, 0, 0), Size = UDim2.fromOffset(26, 26), ZIndex = 16,
		}, box)
		corner(b, 4)
		b.Activated:Connect(function()
			i = (i - 1 + dir) % #options + 1
			setValue(spec, i)
			label.Text = options[i]
		end)
	end
	arrow("<", false, -1)
	arrow(">", true, 1)
	label.Text = options[i]
	table.insert(conns, Settings.OnChange(spec.Id, function(v)
		i = v
		label.Text = options[i]
	end))
end

local function swatchControl(face, spec)
	local chips = {}
	local colours = spec.Swatch
	local n = #colours
	local function show()
		local chosen = valueOf(spec)
		for k, chip in ipairs(chips) do
			local s = chip:FindFirstChildOfClass("UIStroke")
			s.Thickness = (k == chosen) and 4 or 2
			s.Color = (k == chosen) and C.RedInk or C.Ink
		end
	end
	for k, colour in ipairs(colours) do
		local chip = make("TextButton", {
			Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = colour,
			BorderSizePixel = 0, Position = UDim2.new(1, -14 - (n - k) * 30, 0, 20), Size = UDim2.fromOffset(22, 22), ZIndex = 14,
		}, face)
		corner(chip, 3)
		outline(chip, 2)
		chip.Activated:Connect(function()
			setValue(spec, k)
			show()
		end)
		chips[k] = chip
	end
	table.insert(conns, Settings.OnChange(spec.Id, show))
	show()
end

-- How a bound key is written on a cap. Anything not in here prints its own name, which for the
-- letter and digit keys is exactly right.
local KEY_TEXT = {
	LeftControl = "CTRL", RightControl = "CTRL", LeftShift = "SHIFT", RightShift = "SHIFT",
	LeftAlt = "ALT", RightAlt = "ALT", Space = "SPACE", Return = "ENTER", Tab = "TAB",
	ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
	ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
	ButtonL3 = "LS", ButtonR3 = "RS", DPadUp = "D-UP", DPadDown = "D-DN",
	DPadLeft = "D-LT", DPadRight = "D-RT",
}

local function keyText(name)
	if not name or name == "None" then return "--" end
	return KEY_TEXT[name] or name:upper()
end

local function isPadKey(keyCode)
	return keyCode.Name:sub(1, 6) == "Button" or keyCode.Name:sub(1, 4) == "DPad"
		or keyCode.Name:sub(1, 5) == "Thumb"
end

--- Only one cap can be listening at a time; opening a second cancels the first.
local capturing = nil

--- A kit key tab: white cap, ink outline, a heavier ink lip along the bottom. `id` is the setting
--- it rebinds; without one (the Slide row, which follows Crouch) the cap only displays.
local function keycap(face, id, rightOffset, pad, mirror)
	local shown = id or mirror
	local lip = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -rightOffset, 0, 20), Size = UDim2.fromOffset(62, 26),
		BackgroundColor3 = C.Ink, BorderSizePixel = 0, ZIndex = 14,
	}, face)
	corner(lip, 4)
	local cap = make("TextButton", {
		Text = "", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C.Ink,
		AutoButtonColor = false, BackgroundColor3 = C.Pill, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -4), ZIndex = 15,
	}, lip)
	corner(cap, 4)
	outline(cap, 2)

	local function draw()
		local name = shown and Settings.Get(shown) or "None"
		cap.Text = keyText(name)
		local empty = (name == "None")
		cap.TextColor3 = (empty or not id) and C.Grey or C.Ink
		cap.BackgroundColor3 = empty and C.Track or C.Pill
	end
	draw()
	if shown then
		table.insert(conns, Settings.OnChange(shown, draw))
	end

	local function stopCapture()
		if capturing and capturing.cap == cap then capturing = nil end
		draw()
	end

	--- Take `key` for this cap. If another row in the same column already holds it, the two swap --
	--- leaving a role unbound because you rebound a different one is never what was meant.
	local function assign(key)
		local name = key.Name
		local mine = Settings.Get(id)
		for _, other in ipairs(Settings.Defs) do
			local samePad = (other.Id:sub(1, 4) == "Pad_") == pad
			if other.Kind == "key" and other.Id ~= id and samePad and Settings.Get(other.Id) == name then
				Settings.Set(other.Id, mine)
			end
		end
		Settings.Set(id, name)
	end

	if id then
		cap.Activated:Connect(function()
			if capturing then capturing.cancel() end
			cap.Text = pad and "PRESS BTN" or "PRESS KEY"
			cap.TextSize = 9
			cap.BackgroundColor3 = C.RedInk
			cap.TextColor3 = C.CreamText
			capturing = {
				cap = cap,
				pad = pad and true or false,
				cancel = function()
					cap.TextSize = 12
					stopCapture()
				end,
				clear = function()
					cap.TextSize = 12
					Settings.Set(id, "None")
					stopCapture()
				end,
				take = function(key)
					cap.TextSize = 12
					assign(key)
					stopCapture()
				end,
			}
		end)
	end
	return cap
end

--- The one input hook the rebinder needs. It is a plain connection rather than a control-owned one
--- because only one cap is ever listening, and it must keep listening across a tab change if the
--- panel is still open.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local cap = capturing
	if not cap then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard
		and input.UserInputType ~= Enum.UserInputType.Gamepad1 then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Unknown then return end
	if key == Enum.KeyCode.Escape then
		cap.cancel()
		return
	end
	-- Roblox eats a handful of keys before any script sees them; binding one would look like it
	-- worked and then never fire
	if gameProcessed then return end
	if key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
		cap.clear()
		return
	end
	if isPadKey(key) ~= cap.pad then return end        -- a key column takes keys, a pad column buttons
	cap.take(key)
end)

--- The per-page reset. Two taps: the first arms it and says so, the second does it. RIVALS asks
--- for a double tap for the same reason -- this is the one control on the page whose effect you
--- cannot see before you commit to it.
local function resetControl(face, spec)
	local holderB, faceB = slab(face, UDim2.fromOffset(150, 30), UDim2.new(1, -166, 0, 7), C.RedInk, 4, 3)
	holderB.ZIndex = 14
	faceB.ZIndex = 15
	local label = text(faceB, {
		Text = "RESET", TextSize = 13, TextColor3 = C.CreamText,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 16,
	})
	local armed = 0
	hitbox(faceB, 17).Activated:Connect(function()
		local now = os.clock()
		if now - armed <= 0.9 then
			armed = 0
			for _, id in ipairs(spec.Ids) do
				local d = Settings.ById[id]
				if d then Settings.Set(id, d.Default) end
			end
			label.Text = "DONE"
			task.delay(0.7, function() if label.Parent then label.Text = "RESET" end end)
		else
			armed = now
			label.Text = "TAP AGAIN"
			task.delay(0.95, function()
				if label.Parent and label.Text == "TAP AGAIN" then label.Text = "RESET" end
			end)
		end
	end)
end

local function buttonControl(face, spec)
	local holderB, faceB = slab(face, UDim2.fromOffset(150, 30), UDim2.new(1, -166, 0, 7), C.RedInk, 4, 3)
	holderB.ZIndex = 14
	faceB.ZIndex = 15
	text(faceB, { Text = spec.Button, TextSize = 13, TextColor3 = C.CreamText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 16 })
	hitbox(faceB, 17).Activated:Connect(function()
		faceB.BackgroundColor3 = C.Pill
		task.delay(0.2, function() if faceB.Parent then faceB.BackgroundColor3 = C.RedInk end end)
	end)
end

----------------------------------------------------------------------------------------------------
-- rows
----------------------------------------------------------------------------------------------------
local HEIGHT = { section = 38, toggle = 44, slider = 44, choice = 44, swatch = 44, keybind = 44,
	button = 44, reset = 44 }
local SUB = 20

local function addRow(parent, y, spec)
	local h = HEIGHT[spec.Kind] or 52
	if spec.Kind == "section" then
		local _, face = slab(parent, UDim2.fromOffset(COL_W, h), UDim2.fromOffset(0, y), C.RedInk, 4, 4)
		face.ZIndex = 13
		halftone(face, 4, 0.86, C.Ink, 7).ZIndex = 14
		text(face, {
			Font = Enum.Font.Bangers, Text = string.upper(spec.Label), TextSize = 26, TextColor3 = C.CreamText,
			Position = UDim2.fromOffset(14, 1), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 15,
		})
		if spec.Columns then
			for k, col in ipairs(spec.Columns) do
				text(face, {
					Text = col, TextSize = 11, TextColor3 = C.CreamText, TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14 - (#spec.Columns - k) * 72, 0.5, 0),
					Size = UDim2.fromOffset(62, 16), ZIndex = 15,
				})
			end
		end
		return h + ROW_GAP
	end
	local indent = spec.Sub and SUB or 0
	local holderRow, face = slab(parent, UDim2.fromOffset(COL_W - indent, h), UDim2.fromOffset(indent, y), C.Card, 4, 4)
	holderRow.Name = spec.Label
	SPECS[spec.Label] = spec
	face.ZIndex = 13
	text(face, {
		Text = string.upper(spec.Label), TextSize = 16, Position = UDim2.fromOffset(14, 0),
		TextSize = spec.Kind == "slider" and 13 or 14,
		Size = UDim2.fromOffset(spec.Kind == "slider" and 148 or 260, h - 4),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 14,
	})
	face.MouseEnter:Connect(function()
		face.BackgroundColor3 = C.Hover
		showBubble(face, spec)
	end)
	face.MouseLeave:Connect(function()
		face.BackgroundColor3 = C.Card
		hideBubble()
	end)
	if spec.Kind == "toggle" then
		toggleControl(face, spec)
	elseif spec.Kind == "slider" then
		sliderControl(face, spec)
	elseif spec.Kind == "choice" then
		choiceControl(face, spec)
	elseif spec.Kind == "swatch" then
		swatchControl(face, spec)
	elseif spec.Kind == "keybind" then
		keycap(face, spec.Id, 14 + 72, false, spec.Mirror)
		keycap(face, spec.Pad, 14, true, spec.PadMirror)
	elseif spec.Kind == "button" then
		buttonControl(face, spec)
	elseif spec.Kind == "reset" then
		resetControl(face, spec)
	end
	return h + ROW_GAP
end

----------------------------------------------------------------------------------------------------
-- the stage: on the categories that can show something, the top of the right column previews it
----------------------------------------------------------------------------------------------------
-- (2026-10-19, audit P5F-20) the palette preview reads Settings.ElementColors, in the manual's Element order: its own
-- hardcoded copy had drifted (a stale Pyro, the old Zephyr/Umbra/Radiant swaps, no Aqua). { NAME, normal, safe }.
local ELEMENTS = {}
do
	local okC, Config = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
	end)
	local defs = okC and type(Config) == "table" and Config.Elements or {}
	for name, pair in pairs(Settings.ElementColors) do
		local def = defs[name] or {}
		ELEMENTS[#ELEMENTS + 1] = { string.upper(def.Display or name), pair[1], pair[2], def.Order or 99 }
	end
	table.sort(ELEMENTS, function(a, b)
		if a[4] ~= b[4] then return a[4] < b[4] end
		return a[1] < b[1]
	end)
end

local function buildStage(parent, tab)
	local _, face = slab(parent, UDim2.fromOffset(COL_W, STAGE_H), UDim2.fromOffset(0, 0), C.Ink, 6, 4)
	face.ZIndex = 13
	halftone(face, 6, 0.9).ZIndex = 14
	local tag = text(face, {
		Font = Enum.Font.Bangers, Text = "LIVE", TextSize = 22, TextColor3 = C.Red,
		Position = UDim2.fromOffset(14, 3), Size = UDim2.fromOffset(100, 22), ZIndex = 16,
	})
	local screen = make("Frame", {
		Name = "Screen", BackgroundColor3 = C.Sky, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 30),
		Size = UDim2.fromOffset(COL_W - 24, STAGE_H - 44), ClipsDescendants = true, ZIndex = 15,
	}, face)
	corner(screen, 4)
	outline(screen, 2)

	if tab.Stage == "crosshair" then
		make("Frame", {                                     -- a horizon, so the crosshair has something to sit on
			BackgroundColor3 = C.Ground, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.fromScale(1, 0.38), ZIndex = 15,
		}, screen)
		local cross = make("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(120, 120), ZIndex = 16,
		}, screen)
		return face, function()
			cross:ClearAllChildren()
			local colour = Settings.CrosshairColors[Settings.Get("CrosshairColor")]
			local shape = Settings.ById.CrosshairShape.Options[Settings.Get("CrosshairShape")]
			local k = (Settings.Get("CrosshairSize") / 100) * 3.2
			local ink = Settings.Get("CrosshairOutline")
			local function piece(x, y, w, h, round)
				local f = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y),
					Size = UDim2.fromOffset(math.max(2, w), math.max(2, h)), BackgroundColor3 = colour,
					BorderSizePixel = 0, ZIndex = 17,
				}, cross)
				if ink > 0 then make("UIStroke", { Color = C.Ink, Thickness = ink * 1.6 }, f) end
				if round then corner(f, 20) end
			end
			local arm, thick, gap = 8 * k, 2 * k, 4 * k
			if shape == "CROSS + DOT" or shape == "CROSS" then
				local off = gap + arm / 2
				piece(0, -off, thick, arm)
				piece(0, off, thick, arm)
				piece(-off, 0, arm, thick)
				piece(off, 0, arm, thick)
			end
			if shape == "CROSS + DOT" or shape == "DOT" then
				piece(0, 0, thick * 1.4, thick * 1.4, true)
			end
			if shape == "CIRCLE" then
				local ring = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(arm * 2.4, arm * 2.4), BackgroundTransparency = 1, ZIndex = 17,
				}, cross)
				corner(ring, 999)
				make("UIStroke", { Color = colour, Thickness = math.max(2, thick) }, ring)
			end
		end
	elseif tab.Stage == "view" then
		make("Frame", {
			BackgroundColor3 = C.Ground, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.4), ZIndex = 15,
		}, screen)
		local world = make("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1), ZIndex = 16,
		}, screen)
		local worldScale = make("UIScale", {}, world)
		for _, at in ipairs({ 0.26, 0.5, 0.74 }) do            -- three dummies, to read the width of the view
			local body = make("Frame", {
				BackgroundColor3 = Color3.fromRGB(214, 180, 122), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(at, 0.68), Size = UDim2.fromOffset(22, 46), ZIndex = 16,
			}, world)
			outline(body, 2)
			corner(body, 4)
		end
		local dim = make("Frame", {
			BackgroundColor3 = C.Ink, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 18,
		}, screen)
		local fovTag = text(screen, {
			Font = Enum.Font.Bangers, TextSize = 20, TextColor3 = C.CreamText, AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -9, 1, -5), Size = UDim2.fromOffset(130, 20),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 19,
		})
		make("UIStroke", { Color = C.Ink, Thickness = 2 }, fovTag)
		return face, function()
			local fov = Settings.Get("FieldOfView")
			worldScale.Scale = 1 + (90 - fov) / 90 * 0.45       -- a wider view shows more, so things read smaller
			dim.BackgroundTransparency = 0.35 + (Settings.Get("Brightness") / 100) * 0.6
			fovTag.Text = string.format("FOV %d", fov)
		end
	elseif tab.Stage == "palette" then
		screen.BackgroundColor3 = C.Paper
		local chips = {}
		for i, e in ipairs(ELEMENTS) do
			-- five to a row (nine Elements; the sample line sits under two rows)
			local chip = make("Frame", {
				BackgroundColor3 = e[2], BorderSizePixel = 0, ZIndex = 16,
				Position = UDim2.fromOffset(10 + ((i - 1) % 5) * 86, 10 + math.floor((i - 1) / 5) * 56),
				Size = UDim2.fromOffset(80, 48),
			}, screen)
			corner(chip, 3)
			outline(chip, 2)
			local name = text(chip, {
				Text = e[1], TextSize = 12, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1), ZIndex = 17,
			})
			make("UIStroke", { Color = C.Ink, Thickness = 2 }, name)
			chips[i] = { chip, name }
		end
		local sample = text(screen, {
			Font = Enum.Font.Bangers, Text = "ULTIMATE READY", TextSize = 24, TextColor3 = C.RedInk,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 124),
			Size = UDim2.new(1, 0, 0, 28), ZIndex = 17,
		})
		sample:SetAttribute("NoMenuScale", true)   -- it shows Text Size itself (below); the menu pass must not scale it twice
		return face, function()
			local safe = Settings.Get("ColorblindSafe")
			for i, e in ipairs(ELEMENTS) do
				chips[i][1].BackgroundColor3 = safe and e[3] or e[2]
			end
			sample.TextSize = math.floor(24 * Settings.Get("TextSize") / 100)
		end
	end
	return face, function() end
end

----------------------------------------------------------------------------------------------------
-- tabs
----------------------------------------------------------------------------------------------------
local TABS = {}
local tabButtons = {}
local current

--- Fill the left column, then the right, so both end about level. The stage, when a category has
--- one, takes the top of the right column and the rows flow under it.
local function layout(tab)
	local heights = {}
	local total = 0
	for i, spec in ipairs(tab.Rows) do
		heights[i] = (HEIGHT[spec.Kind] or 52) + ROW_GAP
		total += heights[i]
	end
	local stageRoom = tab.Stage and (STAGE_H + ROW_GAP) or 0
	local target = (total + stageRoom) / 2
	local used, cut = 0, #tab.Rows
	for i = 1, #tab.Rows do
		if used + heights[i] * 0.5 > target - stageRoom * 0 then
			cut = i - 1
			break
		end
		used += heights[i]
	end
	cut = math.clamp(cut, 1, #tab.Rows)
	-- never leave a section header stranded at the bottom of a column
	if tab.Rows[cut] and tab.Rows[cut].Kind == "section" then cut -= 1 end
	return cut
end

local applyMenuTextSize           -- (below; 2026-10-19, audit P5F-19: a rebuilt tab is scaled too)

local function selectTab(id)
	local tab
	for _, t in ipairs(TABS) do
		if t.Id == id then tab = t end
	end
	tab = tab or TABS[1]
	current = tab.Id
	for tid, b in pairs(tabButtons) do
		local active = (tid == current)
		b.Pill.BackgroundColor3 = active and C.RedInk or C.Ink
		b.Pill.BackgroundTransparency = active and 0 or 1
		b.Label.TextColor3 = active and C.CreamText or C.CreamDim
	end
	for _, c in ipairs(conns) do c:Disconnect() end
	conns = {}
	liveUpdate = nil
	bubbleHolder.Visible = false
	for _, col in ipairs(columns) do
		for _, child in ipairs(col:GetChildren()) do child:Destroy() end
	end
	local cut = layout(tab)
	local y = 0
	for i = 1, cut do
		y += addRow(columns[1], y, tab.Rows[i])
	end
	local y2 = 0
	if tab.Stage then
		local _, refresh = buildStage(columns[2], tab)
		liveUpdate = refresh
		y2 = STAGE_H + ROW_GAP
	end
	for i = cut + 1, #tab.Rows do
		y2 += addRow(columns[2], y2, tab.Rows[i])
	end
	local sheetH = math.clamp(math.max(y, y2) + 24, 190, DESIGN_H - BODY_Y)
	sheetHolder.Size = UDim2.fromOffset(DESIGN_W, sheetH)
	page.Size = UDim2.fromOffset(DESIGN_W - 32, sheetH - 28)
	for _, col in ipairs(columns) do
		col.Size = UDim2.fromOffset(COL_W, sheetH - 28)
	end
	holder.Size = UDim2.fromOffset(DESIGN_W, BODY_Y + sheetH)
	if liveUpdate then liveUpdate() end
	if applyMenuTextSize then applyMenuTextSize() end
end

local function buildTabs()
	for _, b in pairs(tabButtons) do b.Button:Destroy() end
	tabButtons = {}
	TABS = tabs(platform())
	for i, tab in ipairs(TABS) do
		local b = make("TextButton", {
			Name = tab.Id, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(150, 44), LayoutOrder = i, ZIndex = 3,
		}, tabRow)
		local pill = make("Frame", {
			Name = "Pill", BackgroundColor3 = C.RedInk, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3,
		}, b)
		corner(pill, 4)
		outline(pill, 2)
		make("ImageLabel", {
			BackgroundTransparency = 1, Image = ICON[tab.Icon] or "", AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(30, 30), ZIndex = 5,
		}, b)
		local label = text(b, {
			Text = tab.Title, TextSize = 14, TextColor3 = C.CreamDim, Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -52, 1, 0), ZIndex = 5,
		})
		b.Activated:Connect(function() selectTab(tab.Id) end)
		tabButtons[tab.Id] = { Button = b, Pill = pill, Label = label }
	end
	selectTab(current or TABS[1].Id)
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local open = false

local function setOpen(v)
	if v == open then return end
	open = v
	-- Published so the input scripts can stand down: while the panel is up, the key you press to
	-- rebind Primary must not also cast Primary, and Ctrl must not crouch you behind the menu.
	player:SetAttribute("SettingsOpen", v or nil)
	if v then
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		popScale.Scale = 0.94
		TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 0.35 }):Play()
		TweenService:Create(popScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		-- the first-person camera re-locks the mouse every frame; win it back while the panel is up
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		backdrop.Visible = false
		bubbleHolder.Visible = false
		if capturing then capturing.cancel() end
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
	end
end

gearHit.Activated:Connect(function() setOpen(not open) end)
gearHit.MouseEnter:Connect(function()
	TweenService:Create(gearImage, TweenInfo.new(0.2), { Rotation = 45 }):Play()
end)
gearHit.MouseLeave:Connect(function()
	TweenService:Create(gearImage, TweenInfo.new(0.2), { Rotation = 0 }):Play()
end)
closeHit.Activated:Connect(function() setOpen(false) end)

command.Event:Connect(function(what, arg, arg2)
	if what == "set" then
		Settings.Set(arg, arg2)
		return
	elseif what == "reset" then
		Settings.Reset()
		return
	end
	if what == "open" then
		setOpen(true)
	elseif what == "close" then
		setOpen(false)
	elseif what == "tab" then
		setOpen(true)
		selectTab(arg)
	elseif what == "hover" then
		-- tools only: show the bubble for a row by name, the way pointing at it would
		for _, col in ipairs(columns) do
			for _, block in ipairs(col:GetChildren()) do
				local face = block:FindFirstChild("Face")
				if face and block.Name == arg then
					face.BackgroundColor3 = C.Cream
					hoverRow(face, block.Name)
				end
			end
		end
	end
end)

-- fit the page to the screen (read off the ScreenGui: Camera.ViewportSize can misreport in Studio)
local function fit()
	local s = gui.AbsoluteSize
	if s.X < 10 or s.Y < 10 then return end
	fitScale.Scale = math.clamp(math.min(s.X / (DESIGN_W + 70), s.Y / (DESIGN_H + 70)), 0.35, 1.0)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

--- TEXT SIZE applies to this menu too, on top of whatever each label was authored at. (2026-10-19, audit P5F-19) each
--- label's authored size is recorded ONCE (BaseTextSize) and every pass sets authored x k, so the labels that are never
--- rebuilt (the gear, the tab row, the bubble, the close X) follow a second change and a return to 100% too, and a
--- tab switch (selectTab calls this) no longer shows the authored sizes.
applyMenuTextSize = function()
	local k = Settings.Scale("TextSize")
	for _, d in ipairs(gui:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("NoMenuScale") then
			local base = d:GetAttribute("BaseTextSize")
			if type(base) ~= "number" then
				base = d.TextSize
				d:SetAttribute("BaseTextSize", base)
			end
			d.TextSize = math.max(8, math.floor(base * k + 0.5))
		end
	end
end

buildTabs()
applyMenuTextSize()
Settings.OnChange("TextSize", function()
	current = current or TABS[1].Id
	buildTabs()                       -- rebuilt from the authored sizes, then scaled again
	applyMenuTextSize()
end)

-- The saved values arrive a moment after the panel is built. Rebuilding the current tab is the
-- simplest way to be sure every control shows what was actually loaded.
Settings.OnLoaded(function()
	if TABS[1] then buildTabs() applyMenuTextSize() end
end)

if RunService:IsStudio() then
	player:GetAttributeChangedSignal("SettingsPreviewPlatform"):Connect(function()
		current = nil
		buildTabs()
	end)
end
