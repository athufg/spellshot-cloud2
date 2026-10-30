--[[
	ShopController  (LocalScript)  ->  StarterGui/SpellshotShop/ShopController

	SPELLSHOT's shop (Daily Drop, the owner's pick 2026-10-02) as a WORKING UI. It runs while the gui is disabled.
	A DEMO: buying shows the whole flow and charges and saves NOTHING -- no MarketplaceService, no DataStore, no
	remotes. Prices are the Catalog's BASE prices (live Robux prices are regional); the Robux balance is a placeholder.
	(2026-10-18, economy) Two parts are LIVE: the Sparks balance shows the player's "Sparks" attribute (written by
	ServerScriptService.PlayerData), and its "+" opens the SPARKS PACKS sheet (EconomyConfig.SparksPacks): a pack with a
	ProductId prompts MarketplaceService:PromptProductPurchase, one without says packs aren't on sale yet. Paying out is
	the server's (PlayerData's ProcessReceipt). Fire("sparks") opens the shop on the packs; PacksOpen is its attribute.

	For tools: the ScreenGui carries a BindableEvent "Command". Every UI action routes through the same functions:
	  Fire("open") / Fire("close") / Fire("toggle")
	  Fire("page", "Today" | "Catalog" | "Caches" | "Pass")
	  Fire("segment", "Skin" | "Tint" | "Bundle")      (plural and any case accepted; shows the Catalog)
	  Fire("sort", "Rarity" | "Element" | "Price")     (any case; shows the Catalog)
	  Fire("select", itemId | bundleId | "cache" | "pass")   opens the confirm (opens the shop first if it is closed)
	(2026-10-26, bundle cards) The Bundles segment shows Catalog.BUNDLES on its own wall (CardKit.buildBundleGrid, no
	sort control) and a bundle's confirm is its own sheet (CardKit.fillConfirm); still a demo: nothing is charged.
	  Fire("buy")  Fire("cancel")  Fire("claim")
	  Fire("theme", "Newsprint" | "Ink")   (any case, a 3+ letter prefix is enough; anything else falls back to Newsprint)
	  The active theme is the gui attribute Theme (default "Newsprint"): set it in Studio, or at runtime, and it applies.
	State for tests, as attributes on the ScreenGui: Ready, Open, Page, Segment, Sort, Selected ("" when none),
	ModalOpen, Claimed, LastToast, LastBuy, FitScale. The player carries ShopOpen = true while it is open.
	ModalOpen goes false the moment a close STARTS (the confirm then animates out for 0.14 s, ignoring input).
Page, Segment and Sort likewise change the moment a switch STARTS: the page cross-fade takes 0.22 s, and the grid's
fade-out / rebuild / fade-in takes 0.15 + 0.18 s (the grid's Cards attribute updates at the rebuild, ~0.15 s in).

	Open: Enabled, ShopOpen (the input scripts stand down for it), the cursor freed every frame above the camera
	(first person re-locks it), QuickPlay and LoadoutMenu closed through their own Command events. Close undoes all
	of it. The shop also closes itself when QuickPlay or LoadoutMenu opens, and on entering the Arena.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local K = require(gui:WaitForChild("CardKit"))
local Cat = require(gui:WaitForChild("Catalog"))
K.setTheme(gui:GetAttribute("Theme"), true) -- unknown, old or missing = Newsprint; the palette the gui was built in (CardKit.PALETTES), so runtime cards match
local command = gui:WaitForChild("Command")
-- (2026-10-18, economy) the live Sparks balance and the packs
local MarketplaceService = game:GetService("MarketplaceService")
local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("EconomyConfig"))

local design = gui:WaitForChild("Backdrop"):WaitForChild("Design")
local fitScale = design:WaitForChild("Fit")
local PAGES = { "Today", "Catalog", "Caches", "Pass" }
local pages = {}
for _, n in ipairs(PAGES) do pages[n] = design:WaitForChild("Page" .. n) end
local tabs = design:WaitForChild("Tabs")
local topBar = design:WaitForChild("TopBar")
local modal = design:WaitForChild("ConfirmModal")
local mCard = modal:WaitForChild("Card")
local toast = design:WaitForChild("Toast")
local filterBar = pages.Catalog:WaitForChild("FilterBar") -- the Wall's one filter slab holds both controls
local segments = filterBar:WaitForChild("Segments")
local sortControl = filterBar:WaitForChild("SortControl")
local sortOpts = sortControl:WaitForChild("Options")
local grid = pages.Catalog:WaitForChild("Grid")
local topFold = pages.Catalog:WaitForChild("TopFold") -- the ink rule at the scroller's top: shown only while scrolled
local countdownTime = pages.Today:WaitForChild("Countdown"):WaitForChild("Time")
local daily = pages.Today:WaitForChild("DailyReward")

-- THE SPARKS BALANCE IS LIVE (2026-10-18, economy): the player's "Sparks" attribute, not Catalog.BAL. The slab was laid
-- out round the placeholder's width (CardKit's top bar), so a new amount moves the word, the "+" and the slab's left edge
-- by the difference and keeps its right edge where it was. Robux stays the placeholder (no API reads a player's Robux).
local sparksBal = topBar:WaitForChild("SparksBalance")
local function showSparks()
	local amount = sparksBal.Face.Amount
	local str = K.fmt(math.floor(tonumber(player:GetAttribute("Sparks")) or 0))
	local d = K.textW(str, 36) + 8 - amount.Size.X.Offset
	amount.Text = str
	if d ~= 0 then
		amount.Size += UDim2.fromOffset(d, 0)
		sparksBal.Face.Word.Position += UDim2.fromOffset(d, 0)
		sparksBal.AddSparks.Position += UDim2.fromOffset(d, 0)
		sparksBal.Face.Size += UDim2.fromOffset(d, 0)
		sparksBal.Shadow.Size += UDim2.fromOffset(d, 0)
		sparksBal.Size += UDim2.fromOffset(d, 0)
		sparksBal.Position -= UDim2.fromOffset(d, 0)
	end
end

local CURSOR_STEP = "SpellshotShopCursor"
local KINDS = { Skin = "Skins", Tint = "Tints", Bundle = "Bundles" }   -- segment kind -> its button's word
local SORTS = { Rarity = "rarity", Element = "element", Price = "price" }
local PAGE_SET = { Today = true, Catalog = true, Caches = true, Pass = true }

local state = { open = false, page = "Today", segment = "Skin", sort = "Rarity", selected = nil, claimed = false }
local shown = nil          -- the card whose HoverFX is lit (and lifted)
local countdownGen, toastGen = 0, 0
local closing = false      -- the confirm is animating out: still Visible, but no longer "open" and deaf to input

--- case-insensitive key of `map`; a trailing "s" is forgiven ("Skins", "tints")
local function norm(map, v)
	if type(v) ~= "string" then return nil end
	local lv = v:lower()
	for k in pairs(map) do
		local lk = k:lower()
		if lk == lv or lk .. "s" == lv then return k end
	end
	return nil
end

local function publish()
	gui:SetAttribute("Open", state.open)
	gui:SetAttribute("Page", state.page)
	gui:SetAttribute("Segment", state.segment)
	gui:SetAttribute("Sort", state.sort)
	gui:SetAttribute("Selected", state.selected or "")
	gui:SetAttribute("ModalOpen", modal.Visible and not closing)
	gui:SetAttribute("Claimed", state.claimed)
end

----------------------------------------------------------------------------------------------------
-- hover: a card rests plain; its colours (its HoverFX) FADE in and it LIFTS while hovered (smooth, 2026-10-02).
-- Every card is a Shadow and a Face (CardKit.faceCard): the Face is the drawing, centred, with a UIScale; the outer
-- button keeps its slot and hit area. THE KIT'S LIFT (v4, 2026-10-03): the Face stands up off its Shadow. It moves
-- up-left by the card's LiftX / LiftY, grows to LiftScale and its ink border goes RestStroke -> HoverStroke; the
-- Shadow never moves. In 0.18 s / out 0.15 s, Quad Out, together with the HoverFX elements' transparencies (their
-- built values are attributes). PRESS: the Face goes down INTO the Shadow (PRESS_PX past rest, scale 1) in 0.07 s
-- and comes back in 0.12 s to the pose it belongs in (lifted while it is the lit card, else rest).
-- Z-order: a lifted card sits at Z_LIFT, a settling one at Z_SETTLE (so the new hover is above the one shrinking
-- away), and BaseZ comes back only when the shrink completes. A new hover or a reset cancels the card's tweens.
----------------------------------------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local FADE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_IN = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_PX = (K.KIT and K.KIT.LIFT and K.KIT.LIFT.press) or 3 -- how far a pressed Face goes into its Shadow
local function pressInput(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local Z_LIFT, Z_SETTLE = 30, 29
-- card -> { gen, tweens, fx, face, scale, stroke, parts, baseZ, lift, rest, up, down, restStroke, hoverStroke, pressed }
local anim = {} -- cleared by restAll
-- the page switch and the Catalog grid fade (below); a hover that arrives while either runs waits for it to end
local pageAnim = { gen = 0, tweens = {}, active = nil }   -- active = { from, to, oldParts, newParts }
local gridAnim = { gen = 0, tweens = {}, phase = nil, parts = nil } -- phase "out" | "in" | nil
local pendHover = nil
local function busy() return pageAnim.active ~= nil or gridAnim.phase ~= nil end

local function stateOf(card)
	local s = anim[card]
	if not s then
		local face = K.faceCard(card)
		local fx = face:FindFirstChild("HoverFX")
		s = { gen = 0, tweens = {}, fx = fx, face = face, scale = face:FindFirstChildOfClass("UIScale"), parts = K.fadeParts(fx),
			baseZ = card:GetAttribute("BaseZ") or 1, lift = card:GetAttribute("LiftScale") or 1 }
		-- the kit's lift, from the attributes CardKit.faceCard recorded (a card without them only fades and scales)
		local rx, ry = card:GetAttribute("RestX"), card:GetAttribute("RestY")
		if face ~= card and rx and ry then
			s.rest = UDim2.fromOffset(rx, ry)
			s.up = UDim2.fromOffset(rx + (card:GetAttribute("LiftX") or 0), ry + (card:GetAttribute("LiftY") or 0))
			s.down = UDim2.fromOffset(rx + PRESS_PX, ry + PRESS_PX)
			s.stroke = face:FindFirstChildOfClass("UIStroke") -- the Face's ink border (its first UIStroke)
			if s.stroke then
				s.restStroke = card:GetAttribute("RestStroke") or s.stroke.Thickness
				s.hoverStroke = card:GetAttribute("HoverStroke") or s.restStroke
			end
		end
		anim[card] = s
	end
	return s
end
local function halt(s)
	s.gen += 1
	for _, t in ipairs(s.tweens) do t:Cancel() end -- Cancel keeps the current values: the next tween starts from them
	table.clear(s.tweens)
	return s.gen
end
local function play(s, inst, info, props)
	local t = TweenService:Create(inst, info, props)
	table.insert(s.tweens, t); t:Play()
	return t
end
-- ONE PART OF A PAGE, GRID OR POPUP FADE (p = { instance, property, built value }) to v. A slab's Shadow is a full-size
-- ink frame UNDER its Face, so fading the two together shows the ink through the Face (a grey dip on every card). A
-- Shadow therefore keeps to the part of the fade where its Face is nearly solid: on the way out it goes in the first
-- 40%; on the way in it waits 60% and comes in over the rest. Returns the tween, or nil for a Shadow (so a caller's
-- "last tween" is never the short one).
local function fade(s, p, info, v)
	if p[1].Name ~= "Shadow" then return play(s, p[1], info, { [p[2]] = v }) end
	local t = info.Time
	play(s, p[1], TweenInfo.new(t * 0.4, info.EasingStyle, info.EasingDirection, 0, false, v < 1 and t * 0.6 or 0), { [p[2]] = v })
	return nil
end
local function liftCard(card)
	local s = stateOf(card); halt(s)
	card.ZIndex = Z_LIFT
	if s.fx then
		if not s.fx.Visible then for _, p in ipairs(s.parts) do p[1][p[2]] = 1 end; s.fx.Visible = true end
		-- through fade(): a bundle card's HoverFX holds slabs, whose ink Shadows must not dip the tiles grey (2026-10-26)
		for _, p in ipairs(s.parts) do fade(s, p, FADE_IN, p[3]) end
	end
	if s.up then play(s, s.face, FADE_IN, { Position = s.up }) end
	if s.stroke then play(s, s.stroke, FADE_IN, { Thickness = s.hoverStroke }) end
	if s.scale then play(s, s.scale, FADE_IN, { Scale = s.lift }) end
end
local function settle(card, s)
	if s.fx then s.fx.Visible = false end
	card.ZIndex = s.baseZ
end
local function dropCard(card)
	local s = stateOf(card); local my = halt(s)
	s.pressed = nil
	card.ZIndex = Z_SETTLE
	local last
	if s.rest then play(s, s.face, FADE_OUT, { Position = s.rest }) end
	if s.scale then last = play(s, s.scale, FADE_OUT, { Scale = 1 }) end
	-- the last tween ends the drop: where there is one, a tween a press cannot replace (a fade, the border)
	for _, p in ipairs(s.parts) do last = fade(s, p, FADE_OUT, 1) or last end
	if s.stroke then last = play(s, s.stroke, FADE_OUT, { Thickness = s.restStroke }) end
	if not last then settle(card, s); return end
	last.Completed:Connect(function(st)
		if st == Enum.PlaybackState.Completed and s.gen == my then settle(card, s) end
	end)
end
local function setShown(card)
	if shown == card then return end
	local old = shown
	shown = card
	if old and old.Parent then dropCard(old) end
	if card then liftCard(card) end
end
--- every card instantly at rest (open, close, page switch, grid rebuild): no lingering lift or colour
local function restAll()
	shown = nil
	for card, s in pairs(anim) do
		halt(s)
		for _, p in ipairs(s.parts) do p[1][p[2]] = 1 end
		if s.scale then s.scale.Scale = 1 end
		if s.rest then s.face.Position = s.rest end
		if s.stroke then s.stroke.Thickness = s.restStroke end
		if card.Parent then settle(card, s) end
	end
	table.clear(anim)
end
--- press: the Face goes down into its Shadow (the Shadow stays put); the release puts it back where it belongs
local function pressCard(card, down)
	if down then
		if busy() or modal.Visible then return end
		local s = stateOf(card)
		if not s.down then return end
		s.pressed = true
		play(s, s.face, PRESS_IN, { Position = s.down })
		if s.scale then play(s, s.scale, PRESS_IN, { Scale = 1 }) end
	else
		local s = anim[card]
		if not (s and s.pressed) then return end
		s.pressed = nil
		local lit = shown == card
		play(s, s.face, PRESS_OUT, { Position = lit and s.up or s.rest })
		if s.scale then play(s, s.scale, PRESS_OUT, { Scale = lit and s.lift or 1 }) end
	end
end
local function touching() return UserInputService:GetLastInputType() == Enum.UserInputType.Touch end
local function isCard(x)
	return x:IsA("GuiButton") and (x.Name:sub(1, 5) == "Item_" or x.Name == "CacheHero" or x.Name == "PassCard")
end
local function selectionOf(card)
	if card.Name == "CacheHero" then return "cache" end
	if card.Name == "PassCard" then return "pass" end
	return card:GetAttribute("ItemId") or card.Name:sub(6)
end

local selectThing -- forward: hook() needs it
local function hook(card)
	K.faceCard(card) -- no-op for a built card; wraps one from an older build
	card.MouseEnter:Connect(function()
		if touching() then return end
		if busy() then pendHover = card else setShown(card) end
	end)
	card.MouseLeave:Connect(function()
		pressCard(card, false) -- a press that leaves the card (a scroll drag, a mouse dragged off) lets go: InputEnded may never come
		if pendHover == card then pendHover = nil end
		if not touching() and shown == card then setShown(nil) end
	end)
	card.SelectionGained:Connect(function() setShown(card) end)
	card.SelectionLost:Connect(function() if shown == card then setShown(nil) end end)
	card.InputBegan:Connect(function(i) if pressInput(i) then pressCard(card, true) end end)
	card.InputEnded:Connect(function(i) if pressInput(i) then pressCard(card, false) end end)
	card.Activated:Connect(function(input)
		-- touch: the first tap shows the colours, a second tap on the same card selects it
		local touch = input and input.UserInputType == Enum.UserInputType.Touch
		if touch and shown ~= card then setShown(card) else selectThing(selectionOf(card)) end
	end)
end

----------------------------------------------------------------------------------------------------
-- toast, modal  (smooth popups, 2026-10-02: the hover's feel carried over)
-- Confirm OPEN: the dim fades 1 -> its built 0.35 (0.18 s Quad Out) while the card pops from PopScale 0.9 to 1
-- (0.22 s Back Out) and every card element fades 1 -> its built transparency (0.18 s Quad Out). CLOSE reverses it,
-- quicker: 0.14 s Quad In, card to 0.94, then Visible = false; input is ignored meanwhile, and a select cancels it.
-- No CanvasGroup (it would clip the card's stroke); built values are read once per instance (modalBase).
-- Toast: rises 16 px while fading in (0.2 s Quad Out), holds, sinks/fades out (0.25 s Quad In), hidden at 2.2 s;
-- a new toast replaces an old one through a fading copy. Buy/Cancel press their Face into the Shadow.
----------------------------------------------------------------------------------------------------
local Q, BACK, OUT, IN = Enum.EasingStyle.Quad, Enum.EasingStyle.Back, Enum.EasingDirection.Out, Enum.EasingDirection.In
local MODAL_IN = TweenInfo.new(0.18, Q, OUT)
local POP_IN = TweenInfo.new(0.22, BACK, OUT)
local MODAL_OUT = TweenInfo.new(0.14, Q, IN)
local POP_FROM, POP_TO = 0.9, 0.94
local TOAST_IN, TOAST_OUT = TweenInfo.new(0.2, Q, OUT), TweenInfo.new(0.25, Q, IN)
local TOAST_TOTAL, TOAST_RISE, GHOST_OUT = 2.2, 16, TweenInfo.new(0.15, Q, OUT)
-- (PRESS_IN / PRESS_OUT, 0.07 s / 0.12 s, are defined with the hover's: the cards press too)

--- the fading parts under (and including) root: { instance, property, built value }, only those ever visible (< 1);
--- each instance's built values are read the first time it is seen and kept in `base`
local function partsOf(root, base)
	local list = {}
	local function add(x, prop)
		local b = base[x]
		if not b then b = {}; base[x] = b end
		local v = b[prop]
		if v == nil then v = x[prop]; b[prop] = v end
		if v < 1 then table.insert(list, { x, prop, v }) end
	end
	local function visit(x)
		if x:IsA("GuiObject") then
			add(x, "BackgroundTransparency")
			if x:IsA("TextLabel") or x:IsA("TextButton") or x:IsA("TextBox") then
				add(x, "TextTransparency"); add(x, "TextStrokeTransparency")
			elseif x:IsA("ImageLabel") or x:IsA("ImageButton") then
				add(x, "ImageTransparency")
			end
		elseif x:IsA("UIStroke") then
			add(x, "Transparency")
		end
	end
	visit(root)
	for _, x in ipairs(root:GetDescendants()) do visit(x) end
	return list
end

local toastAnim = { gen = 0, tweens = {} }
local toastParts = partsOf(toast, {}) -- built values, read at start
local function showToast(text)
	toastGen += 1
	local my = toastGen
	if toast.Visible then -- the old toast fades away as a copy while the new one rises
		local ghost = toast:Clone()
		ghost.Name = "ToastFading"
		ghost.Parent = toast.Parent
		local last
		for _, p in ipairs(partsOf(ghost, {})) do
			last = TweenService:Create(p[1], GHOST_OUT, { [p[2]] = 1 }); last:Play()
		end
		if last then last.Completed:Connect(function() ghost:Destroy() end) else ghost:Destroy() end
	end
	halt(toastAnim)
	K.setToast(toast, text)
	local home = toast.Position
	local low = home + UDim2.fromOffset(0, TOAST_RISE)
	toast.Position = low
	for _, p in ipairs(toastParts) do p[1][p[2]] = 1 end
	toast.Visible = true
	gui:SetAttribute("LastToast", text)
	play(toastAnim, toast, TOAST_IN, { Position = home })
	for _, p in ipairs(toastParts) do play(toastAnim, p[1], TOAST_IN, { [p[2]] = p[3] }) end
	task.delay(TOAST_TOTAL - TOAST_OUT.Time, function()
		if toastGen ~= my then return end
		local g = halt(toastAnim)
		local last = play(toastAnim, toast, TOAST_OUT, { Position = low })
		for _, p in ipairs(toastParts) do play(toastAnim, p[1], TOAST_OUT, { [p[2]] = 1 }) end
		last.Completed:Connect(function(st)
			if st == Enum.PlaybackState.Completed and toastAnim.gen == g and toastGen == my then toast.Visible = false end
		end)
	end)
end
local function hideToast()
	toastGen += 1
	halt(toastAnim)
	toast.Visible = false
end

-- the confirm card pops from its centre: a UIScale on the card, and the card re-anchored at its centre after every
-- fillConfirm, which places it by its top-left corner. A scrim dot screen (modal.Dots; v4 builds none) would fade with the scrim.
-- Cancel / Buy are kit slab buttons: a press moves the button's Face into its Shadow (no scale).
local modalAnim = { gen = 0, tweens = {} }
-- instance -> built transparencies. STRONG keys (2026-10-26): with weak keys the GC could drop a static part's entry while
-- the card sat faded out, and the next open then read its faded 1 as "built" and left the sheet, its head bar and the
-- button words invisible (the bundle sheet's many rebuilt parts made the GC run often enough to show it). Content is
-- rebuilt per select, so openConfirm drops the entries of parts no longer in the card instead.
local modalBase = {}
local DIM = modal.BackgroundTransparency
local scrimDots = modal:FindFirstChild("Dots")
local DOTS = scrimDots and scrimDots.ImageTransparency or 1
local popScale = Instance.new("UIScale")
popScale.Name = "PopScale"; popScale.Parent = mCard
local pressFaces = {} -- a slab button's Face -> its resting Position
for _, n in ipairs({ "Cancel", "Buy" }) do
	local b = mCard:WaitForChild(n)
	local face = b:WaitForChild("Face")
	local up = face.Position
	local down = up + UDim2.fromOffset(PRESS_PX, PRESS_PX)
	pressFaces[face] = up
	b.InputBegan:Connect(function(i)
		if pressInput(i) and modal.Visible and not closing then TweenService:Create(face, PRESS_IN, { Position = down }):Play() end
	end)
	b.InputEnded:Connect(function(i) if pressInput(i) then TweenService:Create(face, PRESS_OUT, { Position = up }):Play() end end)
	b.MouseLeave:Connect(function() TweenService:Create(face, PRESS_OUT, { Position = up }):Play() end)
end
local function centred(x)
	local p, s = x.Position, x.Size
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.new(p.X.Scale, p.X.Offset + s.X.Offset / 2, p.Y.Scale, p.Y.Offset + s.Y.Offset / 2)
end

local function modalUp() return modal.Visible and not closing end

--- after fillConfirm: pop the card in (from wherever the dim is, so a select during a close takes over smoothly)
local function openConfirm()
	halt(modalAnim)
	closing = false
	centred(mCard)
	for face, up in pairs(pressFaces) do face.Position = up end
	for x in pairs(modalBase) do if not x:IsDescendantOf(mCard) then modalBase[x] = nil end end -- the old Content's
	local parts = partsOf(mCard, modalBase)
	for _, p in ipairs(parts) do p[1][p[2]] = 1 end
	popScale.Scale = POP_FROM
	if not modal.Visible then
		modal.BackgroundTransparency = 1
		if scrimDots then scrimDots.ImageTransparency = 1 end
		modal.Visible = true
	end
	play(modalAnim, modal, MODAL_IN, { BackgroundTransparency = DIM })
	if scrimDots then play(modalAnim, scrimDots, MODAL_IN, { ImageTransparency = DOTS }) end
	play(modalAnim, popScale, POP_IN, { Scale = 1 })
	for _, p in ipairs(parts) do fade(modalAnim, p, MODAL_IN, p[3]) end
end

--- animated unless `instant` (page switch, shop close); ModalOpen and Selected clear as the close starts
local function closeConfirm(instant)
	local my = halt(modalAnim)
	state.selected = nil
	setShown(nil)
	if instant or not modal.Visible then
		closing = false
		modal.Visible = false
	else
		closing = true
		play(modalAnim, modal, MODAL_OUT, { BackgroundTransparency = 1 })
		if scrimDots then play(modalAnim, scrimDots, MODAL_OUT, { ImageTransparency = 1 }) end
		local last = play(modalAnim, popScale, MODAL_OUT, { Scale = POP_TO })
		for _, p in ipairs(partsOf(mCard, modalBase)) do fade(modalAnim, p, MODAL_OUT, 1) end
		last.Completed:Connect(function(st)
			if st == Enum.PlaybackState.Completed and modalAnim.gen == my then
				closing = false
				modal.Visible = false
			end
		end)
	end
	publish()
end

----------------------------------------------------------------------------------------------------
-- pages, segment, sort  (smooth page switches, 2026-10-02: the hover's feel carried over)
-- PAGE SWITCH: 0.22 s Quad Out. The old page fades out while shifting 24 px away from the new tab, the new one fades
-- in from 24 px on the other side (a tab to the right slides the content left). No CanvasGroup (it would clip the
-- glows and strokes): every visible transparency under the page is read at rest at the START of the switch and
-- tweened to 1 / back to it; the old page is then hidden and put back at rest. HoverFX is the hover's, never faded.
-- A new switch (or a segment/sort change, open, close) first SNAPS a running one to its end: never two pages half-up.
-- TABS: one sliding "Glider" (v4: the red slab with its ink border, cut from a tab's Active) moves to the new tab
-- inside the ink strip while each tab's cream word (Active.Word) and dim word cross-fade, same 0.22 s. A rapid click
-- retargets them from wherever they are.
-- GRID (segment/sort on the open Catalog): fade out 0.15 s, rebuild, fade in 0.18 s; a new change mid-fade fades the
-- current cards out from where they are. Segment/sort highlights tween 0.18 s. Closed, or another page: instant.
----------------------------------------------------------------------------------------------------
local PAGE_T, SHIFT = TweenInfo.new(0.22, Q, OUT), 24
local GRID_OUT, GRID_IN, HL = TweenInfo.new(0.15, Q, OUT), TweenInfo.new(0.18, Q, OUT), TweenInfo.new(0.18, Q, OUT)
local DONE = Enum.PlaybackState.Completed
local home = {}
for n, pg in pairs(pages) do home[n] = pg.Position end

--- { instance, property, value NOW } for every visible (< 1) transparency under root; read only from a subtree at rest.
--- Subtrees named in `skip` are left out (HoverFX always).
local function restParts(root, skip, list)
	list = list or {}
	local function add(x, prop) local v = x[prop]; if v < 1 then table.insert(list, { x, prop, v }) end end
	local function visit(x)
		if x:IsA("GuiObject") then
			add(x, "BackgroundTransparency")
			if x:IsA("TextLabel") or x:IsA("TextButton") or x:IsA("TextBox") then
				if x.Text ~= "" then add(x, "TextTransparency"); add(x, "TextStrokeTransparency") end
			elseif x:IsA("ImageLabel") or x:IsA("ImageButton") then
				add(x, "ImageTransparency")
			elseif x:IsA("ScrollingFrame") then
				add(x, "ScrollBarImageTransparency")
			end
		elseif x:IsA("UIStroke") then
			add(x, "Transparency")
		end
		for _, c in ipairs(x:GetChildren()) do
			if c.Name ~= "HoverFX" and not (skip and skip[c.Name]) then visit(c) end
		end
	end
	visit(root)
	return list
end

-- the tabs: a Glider under them, Active (lit layer) always Visible and faded instead of toggled
local glider
local tabFx = {} -- page -> { on = lit layer parts, off = plain layer parts }
local tabAnim = { gen = 0, tweens = {} }
do
	local a0 = tabs:FindFirstChild("Tab_" .. PAGES[1]) and tabs["Tab_" .. PAGES[1]]:FindFirstChild("Active")
	if a0 then
		glider = Instance.new("Frame")
		glider.Name = "Glider"; glider.BorderSizePixel = 0; glider.ZIndex = 1; glider.Size = a0.Size
		glider.BackgroundColor3 = a0.BackgroundColor3; glider.BackgroundTransparency = a0.BackgroundTransparency
		local cr = a0:FindFirstChildOfClass("UICorner"); if cr then cr:Clone().Parent = glider end
		local sk = a0:FindFirstChildOfClass("UIStroke"); if sk then sk:Clone().Parent = glider end -- the slab's ink border glides with it
		local ul = a0:FindFirstChild("Underline")
		if ul then local u = ul:Clone(); u.Visible = true; u.Parent = glider end
		glider.Parent = tabs
	end
	for _, n in ipairs(PAGES) do
		local tab = tabs:FindFirstChild("Tab_" .. n)
		local a = tab and tab:FindFirstChild("Active")
		if a and glider then
			tab.ZIndex = 2 -- above the Glider
			a.Visible = true; a.BackgroundTransparency = 1
			local sk = a:FindFirstChildOfClass("UIStroke"); if sk then sk.Transparency = 1 end -- the Glider carries the border
			local ul = a:FindFirstChild("Underline"); if ul then ul.Visible = false end
			tabFx[n] = { on = restParts(a, { Underline = true }), off = restParts(tab, { Active = true }) }
		end
	end
end
local function paintTabs(animate)
	halt(tabAnim)
	local function set(p, v)
		if not animate then p[1][p[2]] = v elseif p[1][p[2]] ~= v then play(tabAnim, p[1], PAGE_T, { [p[2]] = v }) end
	end
	for _, n in ipairs(PAGES) do
		local fx, on = tabFx[n], n == state.page
		if fx then
			for _, p in ipairs(fx.on) do set(p, on and p[3] or 1) end
			for _, p in ipairs(fx.off) do set(p, on and 1 or p[3]) end
		else
			local tab = tabs:FindFirstChild("Tab_" .. n)
			if tab then K.paintTab(tab, on) end
		end
	end
	local tab = tabs:FindFirstChild("Tab_" .. state.page)
	if glider and tab then
		if animate then play(tabAnim, glider, PAGE_T, { Position = tab.Position }) else glider.Position = tab.Position end
	end
end

-- segment / sort highlights: CardKit's painters give the end values; the controller tweens to them
-- (Wall: segments and sort options are ONE control style: a Sel block fades in under the chosen word)
local hlAnim = { gen = 0, tweens = {} }
local function glide(b, paint, on, props)
	local from = {}
	for i, p in ipairs(props) do from[i] = p[1][p[2]] end
	paint(b, on)
	for i, p in ipairs(props) do
		local to = p[1][p[2]]
		if to ~= from[i] then p[1][p[2]] = from[i]; play(hlAnim, p[1], HL, { [p[2]] = to }) end
	end
end
local function paintCatalog(animate)
	halt(hlAnim)
	for kind, word in pairs(KINDS) do
		local b = segments:FindFirstChild("Seg_" .. word)
		if b then
			if animate then glide(b, K.paintSegment, kind == state.segment, { { b, "BackgroundTransparency" }, { b.Word, "TextColor3" } })
			else K.paintSegment(b, kind == state.segment) end
		end
	end
	for s in pairs(SORTS) do
		local b = sortOpts:FindFirstChild("Sort_" .. s)
		if b then
			local on = s == state.sort
			if animate then glide(b, K.paintSort, on, { { b, "BackgroundTransparency" }, { b.Word, "TextColor3" } })
			else K.paintSort(b, on) end
		end
	end
	segments:SetAttribute("Selected", state.segment)
	sortControl:SetAttribute("Selected", state.sort)
	-- (2026-10-26) a bundle has no single rarity or Element to sort by: on Bundles the sort (and its rule) steps away
	local sortable = state.segment ~= "Bundle"
	sortControl.Visible = sortable
	local rule = filterBar:FindFirstChild("Divider")
	if rule then rule.Visible = sortable end
end

--- TopFold: a card the scroller cuts at its top ends on an ink rule; nothing is cut while the wall is at its top
local function paintTopFold() topFold.Visible = grid.CanvasPosition.Y > 0 end
grid:GetPropertyChangedSignal("CanvasPosition"):Connect(paintTopFold)
--- the grid is rebuilt from the Catalog module on every change: old cards destroyed, new ones from CardKit.wallCard
local function rebuildGrid()
	restAll()
	if state.segment == "Bundle" then -- (2026-10-26) bundles have their own cards and wall (Catalog.BUNDLES), no sort
		K.buildBundleGrid(grid, Cat.BUNDLES, Cat.BUNDLE_GROUPS, Cat.BUNDLE_VALUE)
	else
		K.buildGrid(grid, K.ofKind(Cat.ITEMS, state.segment), SORTS[state.sort])
	end
	for _, ch in ipairs(grid:GetChildren()) do
		if isCard(ch) then hook(ch) end
	end
	paintTopFold()
end

local GRID_BAR = grid.ScrollBarImageTransparency
local function gridParts()
	local list = {}
	if GRID_BAR < 1 then list[1] = { grid, "ScrollBarImageTransparency", GRID_BAR } end
	for _, ch in ipairs(grid:GetChildren()) do restParts(ch, nil, list) end
	return list
end
local function flushHover()
	local c = pendHover
	pendHover = nil
	if c and c.Parent and not busy() and c:IsDescendantOf(pages[state.page]) then setShown(c) end
end
--- a running grid fade, done NOW: a pending rebuild happens, the cards come back to rest
local function finishGrid()
	if not gridAnim.phase then return end
	halt(gridAnim)
	if gridAnim.phase == "out" then rebuildGrid()
	else for _, p in ipairs(gridAnim.parts) do p[1][p[2]] = p[3] end end
	grid.ScrollBarImageTransparency = GRID_BAR
	gridAnim.phase, gridAnim.parts = nil, nil
end
local function fadeGrid()
	restAll()
	local my = halt(gridAnim)
	local parts = gridAnim.parts or gridParts() -- mid-fade: the cards on screen fade out from where they are
	gridAnim.phase, gridAnim.parts = "out", parts
	local function swapIn()
		if gridAnim.gen ~= my then return end
		for _, t in ipairs(gridAnim.tweens) do t:Cancel() end
		table.clear(gridAnim.tweens)
		rebuildGrid()
		local np = gridParts()
		for _, p in ipairs(np) do p[1][p[2]] = 1 end
		gridAnim.phase, gridAnim.parts = "in", np
		local last
		for _, p in ipairs(np) do last = fade(gridAnim, p, GRID_IN, p[3]) or last end
		local function done() if gridAnim.gen == my then finishGrid(); flushHover() end end
		if last then last.Completed:Connect(function(ps) if ps == DONE then done() end end) else done() end
	end
	local last
	for _, p in ipairs(parts) do last = fade(gridAnim, p, GRID_OUT, 1) or last end
	if last then last.Completed:Connect(function(ps) if ps == DONE then swapIn() end end) else swapIn() end
end

--- a running page switch, done NOW: the old page hidden and back at rest, the new one shown at rest
local function finishPage()
	local a = pageAnim.active
	if not a then return end
	halt(pageAnim)
	pageAnim.active = nil
	for _, p in ipairs(a.oldParts) do p[1][p[2]] = p[3] end
	for _, p in ipairs(a.newParts) do p[1][p[2]] = p[3] end
	local old, new = pages[a.from], pages[a.to]
	old.Visible = false; old.Position = home[a.from]
	new.Visible = true; new.Position = home[a.to]
end
local function settleAll()
	restAll() -- no card left lit, lifted, pressed or with its hover border
	finishGrid(); finishPage(); paintCatalog(false); paintTabs(false)
	pendHover = nil
end

local function showPage(name, instant)
	name = norm(PAGE_SET, name)
	if not name then warn("[SpellshotShop] page: expected Today, Catalog, Caches or Pass"); return false end
	if modal.Visible then closeConfirm(true) end
	restAll()
	finishGrid(); finishPage(); paintCatalog(false) -- a clean, at-rest state before anything is read
	local from = state.page
	state.page = name
	publish()
	local animate = not instant and state.open and from ~= name
	paintTabs(animate)
	if not animate then
		for n, pg in pairs(pages) do pg.Visible = (n == name); pg.Position = home[n] end
		return true
	end
	local dir = table.find(PAGES, name) > table.find(PAGES, from) and 1 or -1
	local old, new = pages[from], pages[name]
	local a = { from = from, to = name, oldParts = restParts(old), newParts = restParts(new) }
	local my = halt(pageAnim)
	pageAnim.active = a
	for _, p in ipairs(a.newParts) do p[1][p[2]] = 1 end
	new.Position = home[name] + UDim2.fromOffset(SHIFT * dir, 0)
	new.Visible = true
	play(pageAnim, old, PAGE_T, { Position = home[from] - UDim2.fromOffset(SHIFT * dir, 0) })
	for _, p in ipairs(a.oldParts) do fade(pageAnim, p, PAGE_T, 1) end
	local last = play(pageAnim, new, PAGE_T, { Position = home[name] })
	for _, p in ipairs(a.newParts) do fade(pageAnim, p, PAGE_T, p[3]) end
	last.Completed:Connect(function(ps)
		if ps == DONE and pageAnim.gen == my then finishPage(); flushHover() end
	end)
	return true
end

--- after a segment/sort change: on the open Catalog the highlights tween and the grid fades round its rebuild;
--- otherwise the grid rebuilds at once and the Catalog is shown (that switch is animated when the shop is open)
local function changeCatalog()
	finishPage()
	local onScreen = state.open and state.page == "Catalog"
	paintCatalog(onScreen)
	if onScreen then
		publish()
		fadeGrid()
	else
		finishGrid()
		rebuildGrid()
		if state.page ~= "Catalog" then showPage("Catalog") else publish() end
	end
end

local function setSegment(kind)
	kind = norm(KINDS, kind)
	if not kind then warn("[SpellshotShop] segment: expected Skin, Tint or Bundle"); return false end
	state.segment = kind
	changeCatalog()
	return true
end

local function setSort(by)
	by = norm(SORTS, by)
	if not by then warn("[SpellshotShop] sort: expected Rarity, Element or Price"); return false end
	state.sort = by
	changeCatalog()
	return true
end

----------------------------------------------------------------------------------------------------
-- fit: the 1920x1080 canvas to the ScreenGui (never Camera.ViewportSize), clear of Roblox's topbar buttons.
-- below = everything under the topbar strip; beside = the full height with side margins past the left buttons.
-- The larger wins, and it is never capped at 1.
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
	local below = math.min(s.X / 1920, (s.Y - topH) / 1080)
	local beside = math.min((s.X - 2 * (leftW + 8)) / 1920, s.Y / 1080)
	if below >= beside then
		fitScale.Scale = math.max(0.2, below)
		design.Position = UDim2.fromOffset(s.X / 2, topH + (s.Y - topH) / 2)
	else
		fitScale.Scale = math.max(0.2, beside)
		design.Position = UDim2.fromOffset(s.X / 2, s.Y / 2)
	end
	gui:SetAttribute("FitScale", fitScale.Scale)
end

----------------------------------------------------------------------------------------------------
-- open / close
----------------------------------------------------------------------------------------------------
local function closeOthers()
	for _, n in ipairs({ "QuickPlay", "LoadoutMenu" }) do
		local g = playerGui:FindFirstChild(n)
		local c = g and g:FindFirstChild("Command")
		if c and c:IsA("BindableEvent") then pcall(function() c:Fire("close") end) end
	end
end

local function startCountdown()
	countdownGen += 1
	local my = countdownGen
	task.spawn(function()
		while state.open and countdownGen == my do
			countdownTime.Text = K.countdown(os.time())
			task.wait(1)
		end
	end)
end

-- WALKING. The game's own input scripts stand down for ShopOpen, but Roblox's default controls still
-- walk and jump; sink those keys while the shop is up so a player can't wander off a ledge mid-browse.
local ContextActionService = game:GetService("ContextActionService")
local MOVE_SINK = "SpellshotShopMoveSink"
local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down,
	Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA }

local function setOpen(v)
	v = v and true or false
	if v == state.open then return end
	state.open = v
	if v then
		closeOthers()
		settleAll() -- the remembered page shows at once: no animation on open
		restAll()
		player:SetAttribute("ShopOpen", true)
		gui.Enabled = true
		fit()
		task.defer(fit) -- again once the enabled gui has laid out
		-- first person re-locks the mouse every frame; win it back while the shop is up (QuickPlay's way)
		RunService:BindToRenderStep(CURSOR_STEP, Enum.RenderPriority.Camera.Value + 10, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
		ContextActionService:BindActionAtPriority(MOVE_SINK, function() return Enum.ContextActionResult.Sink end,
			false, Enum.ContextActionPriority.High.Value + 100, table.unpack(MOVE_KEYS))
		startCountdown()
	else
		pcall(function() RunService:UnbindFromRenderStep(CURSOR_STEP) end)
		pcall(function() ContextActionService:UnbindAction(MOVE_SINK) end)
		if modal.Visible then closeConfirm(true) end
		settleAll()
		restAll()
		hideToast()
		gui.Enabled = false
		player:SetAttribute("ShopOpen", nil)
		countdownGen += 1
	end
	publish()
end

----------------------------------------------------------------------------------------------------
-- select, buy, cancel, claim (a demo: nothing is charged, nothing is saved)
----------------------------------------------------------------------------------------------------
function selectThing(id)
	local t
	if id == "cache" then t = { type = "cache", cache = Cat.CACHE }
	elseif id == "pass" then t = { type = "pass", pass = Cat.PASS }
	elseif type(id) == "string" and Cat.BYID[id] then t = { type = "item", it = Cat.BYID[id] }
	elseif type(id) == "string" and Cat.BUNDLE_BYID and Cat.BUNDLE_BYID[id] then
		-- (2026-10-26) a bundle's sheet; the Roster takes its deduction off the Elements the server says this player owns
		t = { type = "bundle", b = Cat.BUNDLE_BYID[id], owned = Economy.ParseOwned(player:GetAttribute("OwnedElements")),
			robux = Cat.BAL.robux }
	end
	if not t then warn("[SpellshotShop] select: unknown id " .. tostring(id)); return false end
	if not state.open then setOpen(true) end
	K.fillConfirm(mCard, t)
	state.selected = id
	openConfirm()
	publish()
	return true
end

local function buy()
	if not modalUp() then return false end -- closed, or already closing: a second click does nothing
	local what = state.selected
	local blocked = mCard:GetAttribute("Blocked") -- (2026-10-26) e.g. a Roster Bundle whose every Element is owned
	closeConfirm()
	if type(blocked) == "string" and blocked ~= "" then showToast(blocked); return false end
	gui:SetAttribute("LastBuy", what)
	showToast("Demo: purchase not connected yet, nothing was charged")
	return true
end

local function cancel()
	if modalUp() then closeConfirm() end
end

local function claim()
	if state.claimed then showToast("Today's reward is already claimed"); return end
	state.claimed = true   -- locally, until rejoin
	K.paintDaily(daily, Cat.DAILY.day, Cat.DAILY.days, true)
	showToast("Demo: daily reward not connected yet")
	publish()
end

----------------------------------------------------------------------------------------------------
-- SPARKS PACKS (2026-10-18, economy): the "+" on the Sparks balance. A sheet over the page, drawn fresh at every open in
-- the active palette (so a theme switch never leaves it behind), one row per EconomyConfig.SparksPacks entry. A row with
-- a ProductId prompts the Robux purchase; the Sparks arrive through the server's ProcessReceipt and the balance follows
-- the attribute. A row without one says packs aren't on sale yet. Z 55: over the confirm (50), under the toast (60).
----------------------------------------------------------------------------------------------------
local packs = nil
local function closePacks()
	if packs then packs:Destroy(); packs = nil end
	gui:SetAttribute("PacksOpen", false)
end
local function buyPack(pack)
	if (tonumber(pack.ProductId) or 0) <= 0 then
		showToast("Sparks packs aren't on sale yet")
		return
	end
	-- (2026-10-19, audit P2-13) no prompt while the save can't take the Sparks: ProcessReceipt pays only into a loaded
	-- save, so a purchase now would charge the Robux and hold the pack until a later join on a healthy server
	if player:GetAttribute("DataError") == true then
		showToast("Your save is unavailable on this server, so purchases are paused here")
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		showToast("Your save is still loading, try again in a moment")
		return
	end
	local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, pack.ProductId) end)
	if not ok then showToast("The Robux purchase couldn't open, try again") end
end
local function openPacks()
	if not state.open then setOpen(true) end
	if modal.Visible then closeConfirm(true) end
	closePacks()
	local C, KIT = K.C, K.KIT
	local list = Economy.SparksPacks
	local W, ROW, GAP = 980, 112, 18
	local onSale = false
	for _, p in ipairs(list) do
		if (tonumber(p.ProductId) or 0) > 0 then onSale = true end
	end
	local top = 40 + 64 + 20 + 40 + 16
	local H = top + #list * (ROW + GAP) + 4 + 80 + KIT.MED.s + 36
	packs = K.tbutton(design, "SparksPacks", 0, 0, 1920, 1080, C.Ink, { transp = 0.45, z = 55 })
	packs.Activated:Connect(closePacks)                     -- a tap off the sheet
	-- the sheet is a button too, so a tap ON it is not a tap off it
	local _, face = K.slab(packs, "Sheet", (1920 - W) // 2, (1080 - H) // 2, W + KIT.BIG.s, H + KIT.BIG.s, C.Paper, KIT.BIG,
		{ button = true })
	K.halftone(face, "Halftone", 0, 0, W, H, "paper", 0.9, 11, 1, KIT.BIG.r)
	local hw = K.textW("SPARKS PACKS", 44, K.FE.banner) + 56
	local _, hf = K.slab(face, "Heading", 40, 40, hw + KIT.MED.s, 64 + KIT.MED.s, C.RedInk, KIT.MED, { z = 2 })
	K.label(hf, "Word", 0, 0, hw, 64, "SPARKS PACKS", 44, C.CreamText, { font = K.F.banner, ax = "C", z = 2 })
	K.mono(face, "Note", 40, 40 + 64 + 20, W - 80, 40, onSale and "SPARKS UNLOCK ELEMENTS. EARN THEM IN MATCHES, OR SKIP THE GRIND HERE."
		or "PACKS AREN'T ON SALE YET. EARN SPARKS IN MATCHES.", 22, C.Dim, { z = 2 })
	local y = top
	for i, pack in ipairs(list) do
		local row, rf, rw, rh = K.slab(face, "Pack_" .. tostring(pack.Id or i), 40, y, W - 80, ROW, C.Card, KIT.MED, { button = true, z = 2 })
		K.sparksIcon(rf, 24, (rh - 60) // 2, 60, 2, true)
		local amt = K.fmt(pack.Sparks) .. " SPARKS"
		K.label(rf, "Amount", 104, 0, K.textW(amt, 40) + 8, rh, amt, 40, C.Text, { z = 2 })
		local priceStr = K.fmt(pack.RobuxDisplay or 0)
		local pw = K.textW(priceStr, 38)
		local px = rw - 28 - pw
		K.robuxIcon(rf, px - 12 - 40, (rh - 40) // 2, 40, C.Text, 2)
		K.label(rf, "Robux", px, 0, pw + 8, rh, priceStr, 38, C.Text, { z = 2 })
		if (tonumber(pack.ProductId) or 0) <= 0 then
			K.mono(rf, "Soon", px - 12 - 40 - 24 - 320, 0, 320, rh, "NOT ON SALE YET", 20, C.Dim, { ax = "R", z = 2 })
		end
		row.Activated:Connect(function() buyPack(pack) end)
		y += ROW + GAP
	end
	local cw = 260
	local close, cf = K.slab(face, "Close", (W - cw) // 2, y + 4, cw + KIT.MED.s, 80 + KIT.MED.s, C.Pill, KIT.MED,
		{ button = true, z = 2 })
	K.label(cf, "Word", 0, 0, cw, 80, "CLOSE", 36, C.Text, { ax = "C", z = 2 })
	close.Activated:Connect(closePacks)
	gui:SetAttribute("PacksOpen", true)
end
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not gui.Enabled then closePacks() end            -- the shop closing takes the sheet with it
end)

----------------------------------------------------------------------------------------------------
-- wiring: every control calls the same functions the Command event does
----------------------------------------------------------------------------------------------------
for _, n in ipairs(PAGES) do
	local tab = tabs:FindFirstChild("Tab_" .. n)
	if tab then tab.Activated:Connect(function() showPage(n) end) end
end
for kind, word in pairs(KINDS) do
	local b = segments:FindFirstChild("Seg_" .. word)
	if b then b.Activated:Connect(function() setSegment(kind) end) end
end
for s in pairs(SORTS) do
	local b = sortOpts:FindFirstChild("Sort_" .. s)
	if b then b.Activated:Connect(function() setSort(s) end) end
end
topBar:WaitForChild("CloseButton").Activated:Connect(function() setOpen(false) end)
topBar:WaitForChild("SparksBalance"):WaitForChild("AddSparks").Activated:Connect(function()
	openPacks()                                -- (2026-10-18, economy; was a "not connected yet" toast)
end)
-- (2026-10-18, economy) the balance follows the server; a rise while the shop is up says so
local lastSparks = tonumber(player:GetAttribute("Sparks")) or 0
player:GetAttributeChangedSignal("Sparks"):Connect(function()
	local now = tonumber(player:GetAttribute("Sparks")) or 0
	showSparks()
	if state.open and now > lastSparks then showToast("+" .. K.fmt(now - lastSparks) .. " Sparks") end
	lastSparks = now
end)
showSparks()
daily:WaitForChild("ClaimButton").Activated:Connect(claim)
mCard:WaitForChild("Buy").Activated:Connect(buy)
mCard:WaitForChild("Cancel").Activated:Connect(cancel)
modal.Activated:Connect(cancel) -- a tap outside the card
pages.Caches:WaitForChild("CacheHero"):WaitForChild("Face"):WaitForChild("OpenButton").Activated:Connect(function() selectThing("cache") end)
pages.Pass:WaitForChild("PassPanel"):WaitForChild("GetPassButton").Activated:Connect(function() selectThing("pass") end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not state.open then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if packs then closePacks() elseif modal.Visible then cancel() else setOpen(false) end
	end
end)

----------------------------------------------------------------------------------------------------
-- theme (stage B, 2026-10-02; v4: Newsprint or Ink, anything else falls back to Newsprint): Fire("theme", name) or
-- DebugCmd "theme <Name>". CardKit.setTheme picks the palette;
-- a throwaway CardKit.buildDesign drawn in it lends its LOOK (colours, strokes, corners, shadows, the HoverFX Base*
-- values) to the live canvas through CardKit.copyLook, so every instance, hook and state stays. Then the pieces the
-- controller owns are repainted: the Glider, the segment/sort highlights, the tabs, the daily strip and the grid
-- (rebuilt). Instant, from a settled state (no switch, fade, hover, confirm or toast running). The fade caches keep
-- working: they hold transparencies, and no theme changes a transparency they cache (toast, confirm, tabs).
----------------------------------------------------------------------------------------------------
local function applyTheme(name)
	local key = K.setTheme(name)
	if not key then -- v4: an unknown, old or missing name falls back to the default palette (Newsprint)
		warn("[SpellshotShop] theme: expected " .. table.concat(K.THEME_ORDER, " or ") .. "; using " .. K.THEME_ORDER[1])
		key = K.setTheme(K.THEME_ORDER[1])
	end
	if modal.Visible then closeConfirm(true) end
	hideToast()
	settleAll()
	restAll()
	local fresh = K.buildDesign(Cat)
	K.copyLook(fresh, design.Parent)
	fresh:Destroy()
	design.Parent:SetAttribute("Theme", key) -- the canvas's stamp (CardKit.buildDesign writes it)
	gui:SetAttribute("Theme", key)
	local a0 = tabs:FindFirstChild("Tab_" .. PAGES[1])
	a0 = a0 and a0:FindFirstChild("Active")
	if glider and a0 then
		glider.BackgroundColor3 = a0.BackgroundColor3
		local gs, s0 = glider:FindFirstChildOfClass("UIStroke"), a0:FindFirstChildOfClass("UIStroke")
		if gs and s0 then gs.Color = s0.Color; gs.Thickness = s0.Thickness end
		local u, u0 = glider:FindFirstChild("Underline"), a0:FindFirstChild("Underline")
		if u and u0 then u.BackgroundColor3 = u0.BackgroundColor3 end
	end
	paintCatalog(false)
	paintTabs(false)
	K.paintDaily(daily, Cat.DAILY.day, Cat.DAILY.days, state.claimed)
	rebuildGrid()
	publish()
	return true
end

local function runCommand(what, a)
	what = type(what) == "string" and what:lower() or what
	if what == "open" then setOpen(true)
	elseif what == "close" then setOpen(false)
	elseif what == "toggle" then setOpen(not state.open)
	elseif what == "page" then showPage(a)
	elseif what == "segment" then setSegment(a)
	elseif what == "sort" then setSort(a)
	elseif what == "select" then selectThing(a)
	elseif what == "buy" then buy()
	elseif what == "cancel" then cancel()
	elseif what == "claim" then claim()
	elseif what == "theme" then applyTheme(a)
	elseif what == "sparks" then openPacks()          -- (2026-10-18, economy) the shop, on its Sparks packs
	else warn("[SpellshotShop] unknown command " .. tostring(what)) end
end
command.Event:Connect(runCommand)

-- STUDIO-ONLY TEST HOOK (inert in a live server): Studio's assistant sandbox may not fire game
-- BindableEvents, so a test can set the ScreenGui attribute DebugCmd to "<command> [arg]" instead.
if game:GetService("RunService"):IsStudio() then
	gui:GetAttributeChangedSignal("DebugCmd"):Connect(function()
		local v = gui:GetAttribute("DebugCmd")
		if type(v) ~= "string" or v == "" then return end
		local w, arg = v:match("^(%S+)%s*(%S*)")
		runCommand(w, arg ~= "" and arg or nil)
	end)
end

-- another menu opening, or the Arena, closes the shop ((2026-10-19, audit GA-20) the Reactions tablet too, as it closes for the shop)
for _, a in ipairs({ "QuickPlayOpen", "LoadoutOpen", "ReactionsOpen" }) do
	player:GetAttributeChangedSignal(a):Connect(function()
		if player:GetAttribute(a) and state.open then setOpen(false) end
	end)
end
player:GetAttributeChangedSignal("Zone"):Connect(function()
	if player:GetAttribute("Zone") == "Arena" and state.open then setOpen(false) end
end)

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit) end)

----------------------------------------------------------------------------------------------------
-- start: rest pose, the static cards hooked, the grid rebuilt from Catalog
----------------------------------------------------------------------------------------------------
for _, x in ipairs(design:GetDescendants()) do
	if x.Name == "HoverFX" and x:IsA("GuiObject") then x.Visible = false end
	if isCard(x) and not x:IsDescendantOf(grid) then hook(x) end
end
modal.Visible = false
toast.Visible = false
gui.Enabled = false
player:SetAttribute("ShopOpen", nil)
paintCatalog()
rebuildGrid()
K.paintDaily(daily, Cat.DAILY.day, Cat.DAILY.days, false)
countdownTime.Text = K.countdown(os.time())
showPage(state.page)
fit()
-- THE ACTIVE THEME IS THE GUI ATTRIBUTE Theme. A canvas drawn in another theme (its Backdrop's Theme stamp) is
-- re-themed now, so setting the attribute in Studio is enough (no rebuild); changing it later re-applies it too.
-- An unknown, old or missing name falls back to Newsprint. applyTheme writes the canonical key, so this settles at once.
if design.Parent:GetAttribute("Theme") ~= K.theme then applyTheme(K.theme) end
gui:SetAttribute("Theme", K.theme)
gui:GetAttributeChangedSignal("Theme"):Connect(function()
	local v = gui:GetAttribute("Theme")
	if v ~= K.theme then applyTheme(v) end
end)
publish()
gui:SetAttribute("Ready", true)
