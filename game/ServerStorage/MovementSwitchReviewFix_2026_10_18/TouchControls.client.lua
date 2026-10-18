--[[
	TouchControls  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/TouchControls

	THE TOUCH CONTROL LAYER (2026-10-04). On a touch device the game had a move stick, a look drag and a jump
	button, and nothing else: M1 was the mouse button and every ability a key. This draws the missing buttons
	and turns a finger on one into the press its key makes, through TouchBus:

		FIRE (M1)   JUMP   SLIDE / CROUCH                       built here, in the HUD's own slot plate
		PRIMARY   TECHNIQUE 1   TECHNIQUE 2   ULTIMATE          the HUD's own slots, moved under the thumb

	The four ability buttons ARE PopArtHUD's slots. They already carry everything a player reads off an
	ability -- the cooldown veil and count, charges, Immolate's pips, the Heat meter, the Ultimate's charge --
	so on touch they are lifted out of the bottom-right strip, sized for a thumb and laid in a row above
	FIRE, with the keycap tab hidden. Off touch they go back exactly where PopArtHUD built them.

	NOTHING HERE SINKS INPUT. Every button is a plain Frame, so a finger that goes down on FIRE and then drags
	still turns the camera: you aim while you shoot, and while you hold a charge. Presses are read off each
	frame's own InputBegan, so the hit test is the engine's and no screen-space arithmetic is done here.

	Roblox's own jump button is folded away (it sat under the ability strip); JUMP here goes through
	MovementController, which is also where the double jump and the wall jump live.

	Settings read: ButtonSize, ButtonOpacity. In Studio, the player attribute TouchControlsPreview = true
	shows the layer on a keyboard.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Settings = require(folder:WaitForChild("SpellshotSettings"))
local Art = require(folder:WaitForChild("PopArtAssets"))
local TouchBus = require(folder:WaitForChild("TouchBus"))
local Config = require(folder:WaitForChild("SpellshotConfig"))   -- (2026-10-18, movement switch) Movement.Mode for SLIDE / CROUCH

local INK = Color3.fromRGB(17, 17, 17)
local WHITE = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(228, 37, 31)
local GOLD = Color3.fromRGB(245, 184, 0)
local HELD = Color3.fromRGB(190, 186, 174)          -- a plate with a thumb on it
local SHARD = "rbxassetid://98211061341574"         -- VFXLibrary.Config.Textures.Shard: the Icicle Shard sprite

-- Where each button sits and how big it is, in pixels on a 360-high phone: the centre's distance from the
-- screen's right and bottom edges. TWO ROWS (the owner's pick, layout B, 2026-10-04): the bottom row is what you
-- hold -- Slide, Jump, Fire, with Fire in the corner under the resting thumb -- and the row above is what you
-- cast, in the HUD's own order, the Ultimate at the edge. Each row sits on one baseline.
-- SIZE SAYS HOW OFTEN (after RIVALS' cluster, 2026-10-04): Fire, then Jump, then the Ultimate; the three abilities
-- are smaller than the Ultimate (asked for), and Slide is the smallest thing you hold.
local SPEC = {
	M1       = { size = 80, dx = 62,  dy = 68 },
	Jump     = { size = 64, dx = 148, dy = 60 },
	Crouch   = { size = 50, dx = 219, dy = 53 },
	Ultimate = { size = 62, dx = 51,  dy = 155 },
	Defense  = { size = 48, dx = 116, dy = 148 },
	Mobility = { size = 48, dx = 174, dy = 148 },
	Primary  = { size = 48, dx = 232, dy = 148 },
}
local HUD_ROLES = { "Primary", "Mobility", "Defense", "Ultimate" }
local SYNC_EVERY = 0.1

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

----------------------------------------------------------------------------------------------------
-- the layer
----------------------------------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "SpellshotTouch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local holder = make("Frame", {
	Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false,
}, gui)

-- BUTTON OPACITY IS THE PLATE'S (2026-10-04): the white body goes see-through so the fight shows behind the
-- buttons, and the icon on it stays solid so it still reads. All seven plates take it, the four HUD slots'
-- included (layoutHud). Written to the plate itself rather than to a CanvasGroup, which Roblox renders at a
-- lower resolution on the low graphics levels a phone runs at.
local plateFade = 0
local ownPlates = {}

local buttons = {}      -- every button a finger can land on: { action, frame, plate, count }

--- Two bars meeting at a point. `apex` is the point's height in the button (0..1); `up` is which way it points.
local function chevron(parent, apex, up, colour, stroked)
	local L, T = 0.34, 0.12
	local reach = 0.7071 * (L / 2 - T / 2)
	for _, side in ipairs({ -1, 1 }) do
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = colour,
			Position = UDim2.fromScale(0.5 + side * reach, apex + (up and reach or -reach)),
			Size = UDim2.fromScale(L, T), Rotation = (up and 45 or -45) * side, ZIndex = 3,
		}, parent)
		if stroked then
			make("UIStroke", { Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Miter }, bar)
		end
	end
end

local ICON = {}

-- FIRE: the shard in flight, three speed lines behind it
function ICON.M1(icon)
	make("ImageLabel", {
		Name = "Shard", BackgroundTransparency = 1, Image = SHARD, ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.57, 0.43),
		Size = UDim2.fromScale(0.62, 0.62), ZIndex = 3,
	}, icon)
	for _, at in ipairs({ { 0.22, 0.60 }, { 0.31, 0.76 }, { 0.50, 0.83 } }) do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = INK,
			Position = UDim2.fromScale(at[1], at[2]), Size = UDim2.fromScale(0.17, 0.055), Rotation = -45, ZIndex = 3,
		}, icon)
	end
end

-- JUMP: two chevrons up (the second one is the double jump)
function ICON.Jump(icon)
	chevron(icon, 0.27, true, INK, false)
	chevron(icon, 0.51, true, GOLD, true)
end

-- SLIDE / CROUCH: two chevrons down
function ICON.Crouch(icon)
	chevron(icon, 0.49, false, RED, true)
	chevron(icon, 0.73, false, INK, false)
end

local function buildButton(action)
	local root = make("Frame", {
		Name = action, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
	}, holder)
	local plate = make("ImageLabel", {
		Name = "Plate", BackgroundTransparency = 1, Image = Art.Slot, ImageColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 1,
	}, root)
	ownPlates[#ownPlates + 1] = plate
	local icon = make("Frame", {
		Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ZIndex = 2,
	}, root)
	ICON[action](icon)
	local b = { action = action, frame = root, plate = plate, icon = icon, count = 0, own = true }
	buttons[#buttons + 1] = b
	return b
end

local fireButton = buildButton("M1")
local jumpButton = buildButton("Jump")
local crouchButton = buildButton("Crouch")
local own = { fireButton, jumpButton, crouchButton }

-- The four ability buttons are PopArtHUD's slots (see layoutHud), but a finger cannot be read off the slots
-- themselves: a touch's InputBegan goes to the topmost GuiObject under it, and full-screen layers sit above the
-- HUD. So each slot gets a bare pad on THIS layer, laid exactly over where the slot is put.
local pads = {}
for _, role in ipairs(HUD_ROLES) do
	local pad = make("Frame", {
		Name = role, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false,
	}, holder)
	local b = { action = role, frame = pad, count = 0 }
	buttons[#buttons + 1] = b
	pads[role] = b
end

Settings.Bind("ButtonOpacity", function(v)
	plateFade = 1 - math.clamp((tonumber(v) or 100) / 100, 0.2, 1)
	for _, plate in ipairs(ownPlates) do
		plate.ImageTransparency = plateFade
	end
end)

----------------------------------------------------------------------------------------------------
-- presses
----------------------------------------------------------------------------------------------------
local claimed = {}          -- [InputObject] = the button that finger is holding
local layerOn = false       -- touch is the way this player is playing right now

local function menusOpen()
	return player:GetAttribute("SettingsOpen") or player:GetAttribute("LoadoutOpen")
		or player:GetAttribute("QuickPlayOpen") or player:GetAttribute("ShopOpen")
end

local function hittable(b)
	if not layerOn or menusOpen() then return false end
	return holder.Visible and b.frame.Visible
end

local function press(input, b)
	if claimed[input] or not hittable(b) then return end
	claimed[input] = b
	b.count += 1
	if b.count == 1 then
		if b.plate then b.plate.ImageColor3 = HELD end
		TouchBus.Fire(b.action, true)
	end
end

local function release(input)
	local b = claimed[input]
	if not b then return end
	claimed[input] = nil
	b.count = math.max(0, b.count - 1)
	if b.count == 0 then
		if b.plate then b.plate.ImageColor3 = WHITE end
		TouchBus.Fire(b.action, false)
	end
end

local function releaseAll()
	for input in pairs(claimed) do
		release(input)
	end
end

--- The engine's own hit test: a touch that BEGINS on this frame.
local function listen(b)
	return b.frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if input.UserInputState ~= Enum.UserInputState.Begin then return end
		press(input, b)
	end)
end
for _, b in ipairs(buttons) do
	listen(b)
end

UserInputService.TouchEnded:Connect(function(input)
	release(input)
end)
UserInputService.WindowFocusReleased:Connect(releaseAll)
player.CharacterAdded:Connect(releaseAll)

----------------------------------------------------------------------------------------------------
-- the HUD's ability slots, moved under the thumb
----------------------------------------------------------------------------------------------------
local slotRec = setmetatable({}, { __mode = "k" })     -- [slot root] = what was changed on it, to put back

local function findHud()
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Name == "PopArtHUD" then
			local layer = g:FindFirstChild("OpacityLayer")
			local group = layer and layer:FindFirstChild("BottomRight")
			if group then return g, layer, group end
		end
	end
	return nil
end

local function layoutHud(on, f, screen)
	local hudGui, layer, group = findHud()
	local live = on and group ~= nil and hudGui.Enabled
	for _, role in ipairs(HUD_ROLES) do
		pads[role].frame.Visible = live
		if not group then pads[role].plate = nil end
	end
	if not group then return end
	local groupScale = group:FindFirstChildOfClass("UIScale")
	local s = math.max(0.01, groupScale and groupScale.Scale or 1)

	for _, role in ipairs(HUD_ROLES) do
		local root = group:FindFirstChild(role)
		if root and root:IsA("GuiObject") then
			local rec = slotRec[root]
			if not rec then
				rec = {
					pos = root.Position,
					scale = make("UIScale", { Name = "TouchScale", Scale = 1 }, root),
					key = root:FindFirstChild("Key"),
				}
				slotRec[root] = rec
			end
			local slotPlate = root:FindFirstChild("Plate")
			pads[role].plate = slotPlate                       -- the pad tints the slot's own plate while held
			if slotPlate then slotPlate.ImageTransparency = on and plateFade or 0 end
			if on then
				local spec = SPEC[role]
				local want = spec.size * f
				rec.scale.Scale = want / math.max(1, root.Size.X.Offset * s)
				local corner = Vector2.new(screen.X - spec.dx * f - want / 2, screen.Y - spec.dy * f - want / 2)
				local at = (gui.AbsolutePosition + corner - group.AbsolutePosition) / s
				root.Position = UDim2.fromOffset(at.X, at.Y)
				if rec.key then rec.key.Visible = false end
			elseif rec.moved then
				rec.scale.Scale = 1
				root.Position = rec.pos
				if rec.key then rec.key.Visible = true end
			end
			rec.moved = on
		end
	end

	-- the passive pill sat over the strip's right end, where the arcs now are: it goes above the vitals
	local pill = group:FindFirstChild("PassivePill")
	local vitals = layer:FindFirstChild("BottomLeft")
	if pill and pill:IsA("GuiObject") then
		local rec = slotRec[pill]
		if not rec then
			rec = { pos = pill.Position }
			slotRec[pill] = rec
		end
		if on and vitals then
			local size = pill.AbsoluteSize
			local topRight = Vector2.new(vitals.AbsolutePosition.X + size.X, vitals.AbsolutePosition.Y - size.Y - 4 * f)
			local at = (topRight - group.AbsolutePosition) / s
			pill.Position = UDim2.fromOffset(at.X, at.Y)
			rec.moved = true
		elseif rec.moved then
			pill.Position = rec.pos
			rec.moved = false
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Roblox's jump button
----------------------------------------------------------------------------------------------------
-- It is the default controls' own, and it comes back whenever they rebuild it; folded to nothing each time.
local function foldStockJump()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local stock = frame and frame:FindFirstChild("JumpButton")
	if stock and stock:IsA("GuiObject") and (stock.Size.X.Offset ~= 0 or stock.Size.X.Scale ~= 0) then
		stock.Size = UDim2.fromOffset(0, 0)
	end
end

----------------------------------------------------------------------------------------------------
-- keeping it all in step
----------------------------------------------------------------------------------------------------
local function touchPreferred()
	if RunService:IsStudio() and player:GetAttribute("TouchControlsPreview") then return true end
	local ok, touch = pcall(function()
		return UserInputService.PreferredInput == Enum.PreferredInput.Touch
	end)
	if ok then return touch end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function sync()
	local on = touchPreferred()
	local screen = gui.AbsoluteSize
	if screen.X < 8 or screen.Y < 8 then return end
	-- a thumb is the same size on every screen: the buttons grow with a tablet only gently
	local f = math.clamp(math.min(screen.Y / 360, screen.X / 720), 1, 1.6) * math.clamp(Settings.Get("ButtonSize") / 100, 0.5, 1.5)

	layerOn = on
	local show = on and not menusOpen()
	if holder.Visible and not show then releaseAll() end
	holder.Visible = show

	-- no casting in the Hub: FIRE is for the arena. Jump and slide work everywhere.
	local arena = player:GetAttribute("Zone") == "Arena"
	if fireButton.frame.Visible and not arena then
		for input, b in pairs(claimed) do
			if b == fireButton then release(input) end
		end
	end
	fireButton.frame.Visible = arena

	-- (2026-10-18, movement switch) RunningOnly has no slide. The SLIDE / CROUCH button stays as a crouch-only button
	-- (the crouch key still crouches on a keyboard) unless Config.Movement.RunningOnlyTouchCrouch is false, which hides
	-- it; a finger on it is let go first, so the crouch is not left held down. The mode is the workspace attribute
	-- MovementMode, else Config.Movement.Mode, re-read on this sync's own 0.1 s beat.
	local mode = workspace:GetAttribute("MovementMode")
	if mode ~= "Full" and mode ~= "RunningOnly" then mode = Config.Movement.Mode end
	local crouchShown = not (mode == "RunningOnly" and Config.Movement.RunningOnlyTouchCrouch == false)
	if crouchButton.frame.Visible and not crouchShown then
		for input, b in pairs(claimed) do
			if b == crouchButton then release(input) end
		end
	end
	crouchButton.frame.Visible = crouchShown

	for _, b in ipairs(own) do
		local spec = SPEC[b.action]
		local size = spec.size * f
		b.frame.Size = UDim2.fromOffset(size, size)
		b.frame.Position = UDim2.new(1, -spec.dx * f, 1, -spec.dy * f)
		b.plate.Size = UDim2.fromOffset(size, size)
		b.icon.Size = UDim2.fromOffset(size, size)
	end
	for role, b in pairs(pads) do
		local spec = SPEC[role]
		local size = spec.size * f
		b.frame.Size = UDim2.fromOffset(size, size)
		b.frame.Position = UDim2.new(1, -spec.dx * f, 1, -spec.dy * f)
	end

	layoutHud(on, f, screen)
	if on then foldStockJump() end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < SYNC_EVERY then return end
	acc = 0
	sync()
end)
for _, name in ipairs({ "Zone", "SettingsOpen", "LoadoutOpen", "QuickPlayOpen", "ShopOpen" }) do
	player:GetAttributeChangedSignal(name):Connect(sync)
end
sync()
