--[[
	ShopButton  (LocalScript)  ->  StarterGui/SpellshotShopButton/ShopButton

	The SHOP chip in the Hub's top-right chip strip (the gear, LOADOUT, the red PLAY, and now SHOP). Drawn by the
	shop's CardKit.shopChip in the strip's lighter style (LoadoutMenu's slab: cream face, ink outline, hard shadow;
	chipH 44, or 52 on touch) with a Sparks glint and the word SHOP.

	Placement: just LEFT of QuickPlay's PLAY chip, faces 9 px apart like the rest of the strip (holder to holder 6 px,
	each holder carrying a 3 px shadow), tracking PLAY's AbsolutePosition and AbsoluteSize, so it moves left when PLAY
	grows into its QUEUING state. No PLAY chip: a fixed spot where it would sit.
	Visibility: the PLAY chip never hides (HubClient keeps PLAY, the Element chip and the gear in both zones), so the
	SHOP chip shows while Zone ~= "Arena" -- the Hub, and before the first zone is set.
	Click: SpellshotShop.Command:Fire("toggle").
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local shop = playerGui:WaitForChild("SpellshotShop")
local K = require(shop:WaitForChild("CardKit"))
local command = shop:WaitForChild("Command")

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local chipH = touchOnly and 52 or 44
local PLAY_W = touchOnly and 104 or 88   -- QuickPlay's own numbers, used only for the fallback spot
local LOADOUT_LABEL_W = 88
local GAP = 6

do local old = gui:FindFirstChild("ShopChip"); if old then old:Destroy() end end
local chip = K.shopChip(gui, chipH)
local hit = chip.Face.Hit
local word = chip.Face.Label
local baseSize = word.TextSize

local function fallback()
	chip.Position = UDim2.new(1, -(14 + 2 * (chipH + 9) + LOADOUT_LABEL_W + PLAY_W + 3 + GAP), 0, 7)
	chip:SetAttribute("Placement", "fallback")
end

local conns = {}
local function track()
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)
	local qp = playerGui:FindFirstChild("QuickPlay")
	local btn = qp and qp:FindFirstChild("QuickPlayButton")
	if not btn then fallback(); return end
	local function place()
		if not btn.Parent or btn.AbsoluteSize.X < 1 then fallback(); return end
		local origin = gui.AbsolutePosition   -- both guis ignore the inset; this keeps it right if one ever does not
		chip.Position = UDim2.fromOffset(btn.AbsolutePosition.X - GAP - origin.X, btn.AbsolutePosition.Y - origin.Y)
		chip:SetAttribute("Placement", "QuickPlayButton")
	end
	table.insert(conns, btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(place))
	table.insert(conns, btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	table.insert(conns, btn.AncestryChanged:Connect(function()
		if not btn:IsDescendantOf(playerGui) then task.defer(track) end
	end))
	place()
end
local function trackSoon(qp)
	task.spawn(function()
		if qp then qp:WaitForChild("QuickPlayButton", 5) end
		track()
	end)
end
playerGui.ChildAdded:Connect(function(c) if c.Name == "QuickPlay" then trackSoon(c) end end)
fallback()
task.spawn(function() trackSoon(playerGui:WaitForChild("QuickPlay", 10)) end)

local function applyVisible()
	chip.Visible = player:GetAttribute("Zone") ~= "Arena"
end
player:GetAttributeChangedSignal("Zone"):Connect(applyVisible)
applyVisible()

hit.MouseEnter:Connect(function() TweenService:Create(word, TweenInfo.new(0.15), { TextSize = baseSize + 3 }):Play() end)
hit.MouseLeave:Connect(function() TweenService:Create(word, TweenInfo.new(0.15), { TextSize = baseSize }):Play() end)
hit.Activated:Connect(function() command:Fire("toggle") end)
