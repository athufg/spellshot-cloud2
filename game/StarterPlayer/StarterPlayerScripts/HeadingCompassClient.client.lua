--[[
	HeadingCompassClient  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HeadingCompassClient

	Puts the heading compass (ReplicatedStorage/Spellshot/HeadingCompass) on the HUD and feeds it
	the camera. The drawing and the layout maths are the module's; this script only reads the game.

	WHERE. Inside PlayerGui.PopArtHUDTop.OpacityLayer, centred at the very top of the screen. Living in
	that layer is what gives it the HUD Opacity setting (the layer is the CanvasGroup that carries
	it) and the Hub switch (HubClient turns PopArtHUDTop off by name) without touching PopArtHUD.
	PopArtHUD destroys and rebuilds its ScreenGuis on every respawn, so the strip is rebuilt into
	whichever PopArtHUDTop is current.

	ABOVE THE ROUND PLATE. The strip takes the plate's place at the top and the plate moves down by
	the strip's height and a gap. PopArtHUD owns the plate's Position, so this script only writes
	the distance, in px, on the layer as the attribute CompassShift, and PopArtHUD's applyScale
	adds it. It is 0 whenever the strip is hidden or gone, so the plate goes back to the top.
	Where the top row cannot hold the strip at close to full size (the chips, on a landscape
	phone) the strip sits BELOW the plate as it used to, and CompassShift is 0.

	SIZE. The HUD's own scale s. Above the plate it is clamped clear of Roblox's top-left buttons
	and of the top-right chip row (PLAY, and SHOP outside a match: fixed px). Below the plate it is
	clamped clear of the recent-duel feed (PopArtHUD.OpacityLayer.TopRight), and goes down under
	the chips where it would run under them. See HeadingCompass.Layout.

	WHEN. Setting "Compass" on, AND the saved settings have arrived (so a player who turned it off
	never sees it flash), AND inMatch(). While hidden nothing runs per frame: the render step is
	unbound.

	It shows the player's OWN heading and nothing else. Do not add a marker for anything in the
	world here.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Spellshot = ReplicatedStorage:WaitForChild("Spellshot")
local Settings = require(Spellshot:WaitForChild("SpellshotSettings"))
local HeadingCompass = require(Spellshot:WaitForChild("HeadingCompass"))

local TOP_GUI, HUD_GUI = "PopArtHUDTop", "PopArtHUD"
local LAYER, PLATE, FEED = "OpacityLayer", "TopCentre", "TopRight"
-- on the layer: how far down, in px, PopArtHUD's applyScale puts the round plate (see the header)
local SHIFT = "CompassShift"
-- the top-right chip row: { ScreenGui, chip }. PLAY never hides; SHOP hides itself in the Arena.
local CHIPS = { { "QuickPlay", "QuickPlayButton" }, { "SpellshotShopButton", "ShopChip" } }
local STEP_NAME = "SpellshotCompass"
-- after the last camera writers (Camera + 1 and + 2), so the tape shows this frame's view
local STEP_PRIORITY = Enum.RenderPriority.Camera.Value + 5

--- Is the player in a match? Real duels and solo tests both run in the Arena zone. For real duels
--- only, add:  and player:GetAttribute("DuelMatch") ~= nil
local function inMatch()
	return player:GetAttribute("Zone") == "Arena"
end

--- PlayerGui also holds the PopArtHUD LocalScript's own clone under the same name as its ScreenGui,
--- so a gui is looked up by name AND class.
local function findGui(name)
	for _, child in ipairs(playerGui:GetChildren()) do
		if child.Name == name and child:IsA("ScreenGui") then return child end
	end
	return nil
end

local compass = nil          -- the HeadingCompass object in the current layer
local layer = nil            -- PopArtHUDTop.OpacityLayer it was built into
local watching = {}          -- connections on the current HUD's objects
local settingOn = false
local fits = true            -- Layout says there is room for a readable strip
local placed = false         -- the current strip has been through layout() once
local plateShift = 0         -- how far down the last layout() wants the round plate, px
local bound = false
local lastHeading = nil
local layoutQueued, attachQueued = false, false

----------------------------------------------------------------------------------------------------
-- per frame (only while visible)
----------------------------------------------------------------------------------------------------
local function step()
	local c = compass
	if not c then return end
	-- the Camera instance is replaced on some respawns: read it every frame, never cache it
	local camera = workspace.CurrentCamera
	if not camera then return end
	lastHeading = HeadingCompass.FromCFrame(camera.CFrame, lastHeading)
	c:SetHeading(lastHeading)
end

--- Tell PopArtHUD how far down the round plate goes. Written only when the number changes, so an
--- unchanged value never fires the attribute's signal (and never re-runs PopArtHUD's applyScale).
local function setShift(target, px)
	if target and (target:GetAttribute(SHIFT) or 0) ~= px then
		target:SetAttribute(SHIFT, px)
	end
end

local function refresh()
	local want = compass ~= nil and placed and settingOn and fits and Settings.IsLoaded() and inMatch()
	if compass then compass.Root.Visible = want end
	setShift(layer, want and plateShift or 0)     -- hidden: the plate goes back to the top
	if want and not bound then
		bound = true
		RunService:BindToRenderStep(STEP_NAME, STEP_PRIORITY, step)
		step()                                    -- the right number on the first visible frame
	elseif bound and not want then
		bound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
end

----------------------------------------------------------------------------------------------------
-- layout
----------------------------------------------------------------------------------------------------
--- The visible chips of the top-right row as one rectangle in the layer's px, or nil.
local function chipRect(origin)
	local x0, y0, x1, y1 = nil, nil, nil, nil
	for _, pair in ipairs(CHIPS) do
		local gui = findGui(pair[1])
		local chip = gui and gui.Enabled and gui:FindFirstChild(pair[2])
		if chip and chip:IsA("GuiObject") and chip.Visible and chip.AbsoluteSize.X > 0 then
			local p, sz = chip.AbsolutePosition - origin, chip.AbsoluteSize
			x0, y0 = math.min(x0 or p.X, p.X), math.min(y0 or p.Y, p.Y)
			x1, y1 = math.max(x1 or p.X + sz.X, p.X + sz.X), math.max(y1 or p.Y + sz.Y, p.Y + sz.Y)
		end
	end
	return x0 and { x = x0, y = y0, w = x1 - x0, h = y1 - y0 } or nil
end

local function layout()
	layoutQueued = false
	if not compass or not layer or not layer.Parent then return end
	local screen = layer.AbsoluteSize
	if screen.X < 8 or screen.Y < 8 then return end           -- the resize signal will retry
	-- Everything is measured against the layer itself, so Roblox's topbar inset (which shifts
	-- every AbsolutePosition.Y, full-bleed guis included) cancels out.
	local origin = layer.AbsolutePosition

	local hudGui = findGui(HUD_GUI)
	local plate = layer:FindFirstChild(PLATE)
	local feedLayer = hudGui and hudGui:FindFirstChild(LAYER)
	local feed = feedLayer and feedLayer:FindFirstChild(FEED)
	local inset = GuiService.TopbarInset

	local plateRect = nil
	if plate and plate:IsA("GuiObject") then
		local p, sz = plate.AbsolutePosition - origin, plate.AbsoluteSize
		-- its NORMAL place: PopArtHUD has it down by the layer's CompassShift, taken back out
		-- here, so where the strip goes never depends on where the strip sent the plate
		plateRect = { x = p.X, y = p.Y - (layer:GetAttribute(SHIFT) or 0), w = sz.X, h = sz.Y }
	end
	local feedRect = (feed and feed:IsA("GuiObject")) and (feed.AbsolutePosition - origin) or nil

	local r = HeadingCompass.Layout({
		screen = screen,
		hud = hudGui and hudGui.AbsoluteSize or nil,
		uiScale = Settings.Scale("UIScale"),
		plate = plateRect,
		feedLeft = feedRect and feedRect.X or nil,
		feedTop = feedRect and feedRect.Y or nil,
		chip = chipRect(origin),
		topbarMinX = inset.Min.X,
		topbarHeight = inset.Height,
	})
	compass.Fit.Scale = r.fit
	compass.Root.Position = UDim2.fromOffset(math.floor(r.x + 0.5), math.floor(r.y + 0.5))
	fits = r.show
	plateShift = r.shift
	placed = true
	refresh()
end

-- Deferred and coalesced: PopArtHUD rescales the plate and then the feed in one pass, and the
-- clamp has to read both after it.
local function requestLayout()
	if layoutQueued then return end
	layoutQueued = true
	task.defer(layout)
end

----------------------------------------------------------------------------------------------------
-- attach to whichever HUD is current
----------------------------------------------------------------------------------------------------
local function unwatch()
	for _, c in ipairs(watching) do c:Disconnect() end
	table.clear(watching)
end

local function drop()
	unwatch()
	setShift(layer, 0)                            -- a layer that lives on gets its plate back
	if compass then compass:Destroy() end
	compass, layer = nil, nil
	placed = false
	plateShift = 0
	refresh()                                     -- unbinds the render step
end

local queueAttach

local function attach()
	attachQueued = false
	local topGui = findGui(TOP_GUI)
	if not topGui then return end                 -- playerGui.ChildAdded calls again
	local newLayer = topGui:FindFirstChild(LAYER)
	if not newLayer then
		task.spawn(function()
			if topGui:WaitForChild(LAYER, 30) then queueAttach() end
		end)
		return
	end

	if newLayer ~= layer then
		drop()
		layer = newLayer
		compass = HeadingCompass.new(layer)
		compass.Root.Visible = false
		placed = false                            -- never shown before it has been positioned
		lastHeading = nil
	end

	unwatch()
	local function on(signal, fn)
		watching[#watching + 1] = signal:Connect(fn)
	end
	local function onRect(obj)
		if obj and obj:IsA("GuiObject") then
			on(obj:GetPropertyChangedSignal("AbsoluteSize"), requestLayout)
			on(obj:GetPropertyChangedSignal("AbsolutePosition"), requestLayout)
		end
	end
	local hudGui = findGui(HUD_GUI)
	local feedLayer = hudGui and hudGui:FindFirstChild(LAYER)
	on(topGui:GetPropertyChangedSignal("AbsoluteSize"), requestLayout)
	on(topGui:GetPropertyChangedSignal("Enabled"), requestLayout)
	if hudGui then
		on(hudGui:GetPropertyChangedSignal("AbsoluteSize"), requestLayout)
	end
	onRect(layer:FindFirstChild(PLATE))
	onRect(feedLayer and feedLayer:FindFirstChild(FEED))
	-- a plate or feed that arrives late: watch it too
	on(layer.ChildAdded, function(child)
		if child.Name == PLATE then queueAttach() end
	end)
	if feedLayer then
		on(feedLayer.ChildAdded, function(child)
			if child.Name == FEED then queueAttach() end
		end)
	end
	-- the chip row: PLAY widens while queuing, SHOP comes and goes with the zone
	for _, pair in ipairs(CHIPS) do
		local gui = findGui(pair[1])
		if gui then
			local chip = gui:FindFirstChild(pair[2])
			on(gui:GetPropertyChangedSignal("Enabled"), requestLayout)
			if chip and chip:IsA("GuiObject") then
				onRect(chip)
				on(chip:GetPropertyChangedSignal("Visible"), requestLayout)
			else
				on(gui.ChildAdded, function(child)
					if child.Name == pair[2] then queueAttach() end
				end)
			end
		end
	end
	-- the HUD being rebuilt takes the strip with it
	local mine = layer
	on(layer.Destroying, function()
		if layer == mine then drop() end
	end)

	requestLayout()
	refresh()
end

function queueAttach()
	if attachQueued then return end
	attachQueued = true
	task.defer(attach)
end

----------------------------------------------------------------------------------------------------
-- wiring
----------------------------------------------------------------------------------------------------
Settings.Bind("Compass", function(value)
	settingOn = value == true
	refresh()
end)
Settings.Bind("UIScale", requestLayout)
Settings.OnLoaded(refresh)

player:GetAttributeChangedSignal("Zone"):Connect(function()
	requestLayout()
	refresh()
end)
player:GetAttributeChangedSignal("DuelMatch"):Connect(refresh)   -- so inMatch() may use it
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(requestLayout)

playerGui.ChildAdded:Connect(function(child)
	if not child:IsA("ScreenGui") then return end
	local name = child.Name
	if name == TOP_GUI or name == HUD_GUI or name == CHIPS[1][1] or name == CHIPS[2][1] then queueAttach() end
end)
queueAttach()
