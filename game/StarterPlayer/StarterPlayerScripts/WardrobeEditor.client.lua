--[[
	WardrobeEditor  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/WardrobeEditor

	THE CHARACTER EDITOR AT THE WARDROBE MIRROR (2026-10-28): the upper Store gallery's mirror and round pedestal
	(workspace.ArcaneObservatoryHub.CharacterEditor dresses the alcove; the mirror glass is the hub's
	OBS_Mirror_Glass_01). Client only; the server half is ServerScriptService.WardrobeServer, the shared rules
	ReplicatedStorage.Spellshot.Wardrobe.

	  * THE PROMPT: a ProximityPrompt on an anchor in front of the pedestal, inside the hub model, exactly like HubBoards'
	    placards: HubClient gives it the player's Interact bind, HubPrompts draws it (the hub's speech balloon).
	  * ON PRESS: the avatar stands on the pedestal facing the mirror (placed once where the server sees it, then
	    anchored on this client on the disc itself; movement keys sunk, the input scripts stand down for LoadoutOpen),
	    the camera eases in to a 3/4 view of the avatar and its reflection, the HUD stands down (the Altar showcase's
	    way), and the side panel slides in: the categories (Wardrobe.Categories, plus any other folder in the data).
	  * THE MIRROR: the glass gets a reflection while the editor is open -- a SurfaceGui on its front face holding a
	    ViewportFrame, where every visible part of the local character (accessories and coat included) is copied each
	    frame at its mirror image across the glass and drawn from this camera's eye looking straight into the glass, so
	    the picture lines up with the glass from any angle. A worn accessory shows in the mirror the frame it lands.
	  * A CATEGORY: its items, read from the server's mirror of ServerStorage.Accessories (ReplicatedStorage.Spellshot.
	    WardrobeCatalog: nothing here names an item). An owned item equips on click through WardrobeRequest (the server
	    decides; Hats and Hair take each other off there) and shows on the avatar; clicked again it comes off. A locked
	    item shows its padlock and Sparks price (SparkPrice; "? TBD" while unpriced) and opens the Shop (the editor
	    closes first). An empty category says so, in TOP DUELISTS' empty-state tone (HubBoards).
	  * SKIN (2026-10-28): the rail's first entry (Wardrobe.SkinKey; not an accessory category). Its column is one card of
	    round colour swatches, Wardrobe.SkinTones from very light to very dark, the worn one ringed in gold, no prices
	    (every tone is free). A click paints this client's head and hands that frame (the avatar and the mirror both)
	    and asks WardrobeRequest("Skin", index); the server writes SkinTone and paints them for everyone (UniformAvatar
	    keeps it on every respawn). Quick clicks are sent one at a time, the last pick last; a refusal puts the
	    server's tone back.
	  * OUTFITS (2026-10-29): the rail's second entry (Wardrobe.OutfitKey). Its column lists the premium full-body outfits
	    from the server's mirror of ServerStorage.Outfits (ReplicatedStorage.Spellshot.OutfitCatalog: nothing here names
	    an outfit) in the accessory rows' look: a bust thumbnail of the outfit, its name, the Element it dresses (PYRO
	    ONLY) or ANY ELEMENT, EQUIPPED (WHEN PYRO while it waits for its Element: the coat shows meanwhile). An owned
	    outfit goes on (or comes off) on click through WardrobeRequest("EquipOutfit" | "UnequipOutfit", id) -- ElementCoat
	    dresses it INSTEAD of the Element coat, and the worn accessories stay on top; a locked one shows the padlock and
	    its Robux price (RobuxPrice; TBD while 0) and opens the Shop, as a locked accessory does.
	    In the mirror an outfit's left / right pieces are drawn with their twin's mesh (see twinOf), so a pauldron's
	    flare stays on the outside in the reflection.
	  * OUT: the X, Esc (which also opens Roblox's own menu: Roblox keeps that key) or the pad's B: the camera eases back
	    to the player's own view, the avatar back where it stood, the HUD and prompts back.
	THE LOOK is the Altar showcase's panel (AltarShowcase.client.lua: the framed ink slab, the title plate, the Bangers
	header tabs, the rows with their icon wells, rarity spine, EQUIPPED tag and padlock price pill), drawn with
	HubLifeKit, at the same reference sizes.
	Studio check hook: PlayerGui.WardrobeEditor.Command:Fire("open" | "close" | "category", name | "item", accessoryId |
	"outfit", outfitId | "skin", toneIndex | "fit", Vector2). State as gui attributes: Ready, Open, Category, Rows, Empty,
	Mirror, MirrorParts, MirrorTwins, LastReply, Skin (the tone index shown), Outfit (the worn outfit shown). Clickable by
	path: Canvas.Safe.Panel.Rail.List.Cat_<Category>.Hit (Cat_Skin, Cat_Outfits),
	Canvas.Safe.Panel.Items.List.Item_<AccessoryId | OutfitId>.Hit, Canvas.Safe.Panel.Items.List.Skin.Face.Tone_<index>.Hit,
	Canvas.Safe.Close.Hit.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
local K = require(spell:WaitForChild("HubLifeKit"))
local W = require(spell:WaitForChild("Wardrobe"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	-- the pedestal's top, measured 2026-10-28 (the disc's centre and its visible top; the hub's collider there,
	-- Colliders.Coll_furn_0267, stands 1.37 higher, so a player walking on sees their feet float)
	Stand = Vector3.new(8058.98, 12.6, 8044.3),
	Mirror = {
		Part = "OBS_Mirror_Glass_01",        -- the hub's mirror glass (Visual), its Front face toward the pedestal
		PPS = 80,                            -- the reflection's sharpness (SurfaceGui px per stud)
		Inset = { L = 0.16, R = 0.16, T = 0.72, B = 0.16 },   -- the clear glass inside the gold rim and the cut top corners
		Ambient = Color3.fromRGB(196, 192, 204), LightColor = Color3.fromRGB(205, 200, 190),
		Light = Vector3.new(0.35, -1, 0.55),  -- the room's light, travelling (mirrored for the reflection)
		Tint = Color3.fromRGB(232, 240, 250), Fade = 0.05,   -- the glass's own cool cast over the picture
		HeadTint = 1.15,                     -- a dynamic head's grey face texture times its skin Color (see stillCopy)
		Pedestal = { Top = Color3.fromRGB(206, 206, 214), Rim = Color3.fromRGB(190, 140, 60), R = 1.95, H = 0.62 },
	},
	Prompt = { At = Vector3.new(8058.98, 13.3, 8042.1), Hold = 0.2, Reach = 10 },   -- (the placards' prompt numbers, a shorter reach)
	-- the framing: the focus sits between the chest and the glass; the camera Dist out and Height up from it, turned
	-- Yaw degrees off the mirror's axis (+ = toward -X, the vanity side: the avatar reads left, its reflection right);
	-- then turned AsideYaw degrees left so the pair sits right of the panel (a turn, not a slide: a slide eats the 3/4)
	Cam = { Dist = 13, Height = 1.0, Yaw = 48, LookUp = 3.2, FOV = 46, AsideYaw = 12, In = 0.95, Out = 0.5 },
	Thumb = { Yaw = 28, Pitch = 12, FOV = 30 },
	Canvas = Vector2.new(1920, 1080), MinScale = 0.55, MinWidth = 1300,   -- (the showcase's reference screen)
}
local C = {
	RedInk = Color3.fromRGB(200, 30, 26), Green = Color3.fromRGB(126, 204, 36),   -- the Loadout's own (LoadoutMenu's C)
}
local EXTRUDE = K.C.Card:Lerp(K.C.Ink, 0.28)

local catalog = spell:WaitForChild(W.CatalogName, 30)
local remote = nil
task.spawn(function() remote = spell:WaitForChild(W.RemoteName, 60) end)
-- (2026-10-29) the outfits' mirror (WardrobeServer's; empty, or not there yet, before any outfit is installed)
local function outfitCatalog()
	return spell:FindFirstChild(W.OutfitCatalogName)
end

local function elementDef(el)
	return el and K.element(el) or nil
end
local function display(cat)
	return string.upper(tostring(cat))
end
local function commas(n)
	local s = tostring(math.floor(n))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then return s end
	end
end
local function textW(str, size, font)
	return TextService:GetTextSize(str, size, font, Vector2.new(1e4, 1e4)).X
end

----------------------------------------------------------------------------------------------------
-- the UI (the showcase's kit: HubLifeKit slabs, LuckiestGuy display, GothamBlack, RobotoMono labels)
----------------------------------------------------------------------------------------------------
local gui = K.make("ScreenGui", { Name = "WardrobeEditor", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 42, Enabled = false }, playerGui)
local command = K.make("BindableEvent", { Name = "Command" }, gui)
local canvas = K.make("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(Tuning.Canvas.X, Tuning.Canvas.Y) }, gui)
local canvasScale = K.make("UIScale", {}, canvas)
local safe = K.make("Frame", { Name = "Safe", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, canvas)
local function text(parent, props)
	local l = K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = K.C.Ink, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, v in pairs(props) do l[k] = v end
	return l
end
local function hit(parent, z)
	return K.make("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z or 20 }, parent)
end
--- the showcase's padlock: a cream shackle arch over a cream body with an ink keyhole, 22 x 26
local function padlock(parent, z, order)
	local g = K.make("Frame", { Name = "Padlock", BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 26), ZIndex = z, LayoutOrder = order or 0 }, parent)
	local shackle = K.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(12, 18), ZIndex = z }, g)
	K.corner(shackle, 6)
	K.make("UIStroke", { Color = K.C.CreamText, Thickness = 3 }, shackle)
	local body = K.make("Frame", { BackgroundColor3 = K.C.CreamText, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 11), Size = UDim2.fromOffset(22, 15), ZIndex = z + 1 }, g)
	K.corner(body, 3)
	local hole = K.make("Frame", { BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 3), Size = UDim2.fromOffset(6, 6), ZIndex = z + 2 }, body)
	K.corner(hole, 3)
	K.make("Frame", { BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(2, 5), ZIndex = z + 2 }, body)
	return g
end
--- the showcase's Sparks mark (a magenta four-arm sparkle, each arm fading to its tip; no Rotation, safe in scrolling lists)
local SPARKS = Color3.fromHex("E91E8C")
local TO_TIPS = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
local function sparksMark(parent, s, z, order)
	local b = K.make("Frame", { Name = "SparksIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(s, s), ZIndex = z, LayoutOrder = order or 0 }, parent)
	b:SetAttribute("Currency", "Sparks")
	local th = math.max(3, math.floor(s * 0.24 + 0.5))
	for _, tall in ipairs({ true, false }) do
		local arm = K.make("Frame", { BackgroundColor3 = SPARKS, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = tall and UDim2.fromOffset(th, s) or UDim2.fromOffset(math.floor(s * 0.7 + 0.5), th), ZIndex = z }, b)
		K.make("UIGradient", { Transparency = TO_TIPS, Rotation = tall and 90 or 0 }, arm)
	end
	local core = math.max(4, math.floor(s * 0.34 + 0.5))
	K.corner(K.make("Frame", { BackgroundColor3 = SPARKS, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(core, core), ZIndex = z }, b), core // 2)
	return b
end
--- (2026-10-29) the Robux mark for an outfit's price: "R$" in the Loadout's green, bold (no image to load or moderate)
local function robuxMark(parent, s, z, order)
	local b = text(parent, { Name = "RobuxIcon", Font = Enum.Font.GothamBlack, Text = "R$", TextColor3 = C.Green, TextSize = s,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, s), ZIndex = z, LayoutOrder = order or 0 })
	b:SetAttribute("Currency", "Robux")
	return b
end
--- the showcase's tag: an ink pill holding the padlock (if locked) and the price (the Sparks mark, the amount, a gold TBD on
--- a placeholder). Placed by its right edge at `pos`. (2026-10-29) currency "Robux": the Robux mark instead of the Sparks one
local function pricePill(parent, price, locked, pos, h, z, currency)
	local pill = K.make("Frame", { Name = "Price", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = pos,
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z }, parent)
	K.corner(pill, 6)
	K.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9) }, pill)
	K.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }, pill)
	if locked then padlock(pill, z + 1, 1) end
	if price then
		local ms, ts = math.floor(h * 0.55), math.floor(h * 0.52)
		if currency == "Robux" then robuxMark(pill, ts, z + 1, 2) else sparksMark(pill, ms, z + 1, 2) end
		text(pill, { Name = "Amount", Text = price.Amount, TextColor3 = K.C.CreamText, TextSize = ts, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, h), ZIndex = z + 1, LayoutOrder = 3 })
		if price.TBD then
			text(pill, { Name = "TBD", FontFace = K.MONO, Text = "TBD", TextColor3 = K.C.Gold, TextSize = math.floor(h * 0.42), AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, h), ZIndex = z + 1, LayoutOrder = 4 })
			pill:SetAttribute("Placeholder", true)
		end
	end
	return pill
end
local function sparksPrice(n)
	if type(n) == "number" then return { Amount = commas(n) } end
	return { Amount = "?", TBD = true }
end
local robuxPrice = sparksPrice   -- (2026-10-29) the same: an amount, or "? TBD" while unpriced

-- the panel, left, under the top bar: the showcase's framed ink slab (halftone, a gold keyline), its title plate docked
-- in the top, the rail (CATEGORIES) and the items column under it
local panelHolder, panelFace = K.slab(safe, UDim2.new(0, 770, 1, -24), UDim2.fromOffset(24, 0), K.C.Ink, 1, 10, 4, 10)
panelHolder.Name = "Panel"
K.halftone(panelFace, 0.9, Color3.fromRGB(60, 66, 96), 8, 2)
local keyline = K.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 1, -14), ZIndex = 3 }, panelFace)
K.corner(keyline, 7)
K.make("UIStroke", { Color = K.C.Gold, Thickness = 2, Transparency = 0.25 }, keyline)
local plate = K.make("Frame", { Name = "TitleBar", BackgroundColor3 = K.C.Card, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 16),
	Size = UDim2.new(1, -32, 0, 96), ZIndex = 4 }, panelFace)
K.corner(plate, 6)
K.outline(plate, 3)
K.halftone(plate, 0.9, K.C.Ink, 10, 5)
local title = K.display(plate, { Text = "WARDROBE", TextSize = 46, Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -36, 0, 54), ZIndex = 8 }, 4, K.C.Ink, EXTRUDE)
local tag = text(plate, { FontFace = K.MONO, TextSize = 20, TextColor3 = K.C.LockedInk, Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 28), ZIndex = 9,
	Text = "PICK A CATEGORY" })
local balance = nil   -- the Sparks balance pill, on the plate's right
local function refreshBalance()
	if balance then balance:Destroy() end
	local s = player:GetAttribute("Sparks")
	balance = pricePill(plate, { Amount = commas(type(s) == "number" and s or 0) }, false, UDim2.new(1, -14, 0, 74), 30, 9)
	balance.Name = "Balance"
end
local function scrollList(parent)
	return K.make("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
		CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = K.C.Gold,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ZIndex = 5 }, parent)
end
local rail = K.make("Frame", { Name = "Rail", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 134), Size = UDim2.new(0, 350, 1, -160), ZIndex = 5 }, panelHolder)
local railList = scrollList(rail)
local itemsPanel = K.make("Frame", { Name = "Items", BackgroundTransparency = 1, Position = UDim2.fromOffset(372, 134), Size = UDim2.new(0, 372, 1, -160), ZIndex = 5 }, panelHolder)
local itemList = scrollList(itemsPanel)
-- nothing picked: the panel narrows to the rail alone (the showcase's rule); the first pick widens it
panelHolder.ClipsDescendants = true
local PANEL_W = { Rail = 394, Full = 770 }
local picked = nil
local function setPicked(on, instant)
	if picked == on then return end
	picked = on
	local size = UDim2.new(0, on and PANEL_W.Full or PANEL_W.Rail, 1, -24)
	if instant then
		panelHolder.Size = size
		itemsPanel.Visible = on
		return
	end
	if on then itemsPanel.Visible = true end
	local tw = TweenService:Create(panelHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = size })
	tw.Completed:Connect(function() if picked == false then itemsPanel.Visible = false end end)
	tw:Play()
end
-- the X, top right under the top bar; the hint, bottom middle
local closeHolder, closeFace = K.slab(safe, UDim2.fromOffset(70, 70), UDim2.new(1, -94, 0, 0), K.C.Ink, 6, 6, 3, 4)
closeHolder.Name = "Close"
text(closeFace, { Font = Enum.Font.LuckiestGuy, Text = "X", TextColor3 = K.C.CreamText, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
local closeHit = hit(closeHolder)
local hintHolder, hintFace = K.slab(canvas, UDim2.fromOffset(500, 44), UDim2.new(0.5, 65, 1, -68), K.C.Ink, 6, 4, 2, 4)
hintHolder.Name = "Hint"
local hintWord = text(hintFace, { FontFace = K.MONO, Text = "CLICK AN ITEM TO WEAR IT", TextColor3 = K.C.CreamText, TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
local slideIn = {   -- each block's home and its wait off-screen
	{ panelHolder, UDim2.fromOffset(24, 0), UDim2.fromOffset(-820, 0) },
	{ closeHolder, UDim2.new(1, -94, 0, 0), UDim2.new(1, -94, 0, -260) },
	{ hintHolder, UDim2.new(0.5, 150, 1, -68), UDim2.new(0.5, 150, 1, 60) },
}
local function slideUI(show, delay)
	for i, s in ipairs(slideIn) do
		local ti = show and TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (delay or 0) + i * 0.04)
			or TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(s[1], ti, { Position = show and s[2] or s[3] }):Play()
	end
end
for _, s in ipairs(slideIn) do s[1].Position = s[3] end

-- the showcase's scale: the screen's height over the 1080 reference, never under MinScale, never so big the panel stops fitting
local fitSize = nil
local function fit(size)
	if typeof(size) == "Vector2" then fitSize = size elseif size == false then fitSize = nil end
	local v = fitSize or gui.AbsoluteSize
	if v.X < 2 or v.Y < 2 then v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Tuning.Canvas end
	if v.X < 2 or v.Y < 2 then v = Tuning.Canvas end
	local s = math.min(math.max(v.Y / Tuning.Canvas.Y, Tuning.MinScale), v.X / Tuning.MinWidth)
	canvasScale.Scale = s
	canvas.Size = UDim2.fromOffset(v.X / s, v.Y / s)
	local top = math.max(24, (GuiService.TopbarInset.Max.Y + 12) / s)
	safe.Position = UDim2.fromOffset(0, top)
	safe.Size = UDim2.new(1, 0, 1, -top)
	hintHolder.Visible = v.X / s - 794 - 24 >= 360
end
fit()

----------------------------------------------------------------------------------------------------
-- the rows (the showcase's): icon well, rarity spine, EQUIPPED, the price pill; selected rows swell, glow, step forward
----------------------------------------------------------------------------------------------------
local function iconWell(parent, size, x, y, fill, initial, z)
	local well = K.make("Frame", { Name = "Icon", BackgroundColor3 = fill, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size), ZIndex = z }, parent)
	K.make("UICorner", { CornerRadius = UDim.new(1, 0) }, well)
	K.outline(well, 3)
	if initial then
		text(well, { Font = Enum.Font.LuckiestGuy, Text = initial, TextColor3 = K.wordOn(fill), TextSize = math.floor(size * 0.5),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = z + 1 })
	end
	return well
end

--- an accessory's thumbnail: a still copy of the data's Accessory in a ViewportFrame, seen from the front a little to
--- one side; a glow that follows the wearer's Element takes this player's. (2026-10-29) `own` = acc is already a private
--- copy (an outfit's bust, below): used as it is, not cloned again
local function thumb(parent, acc, z, own)
	local vf = K.make("ViewportFrame", { Name = "Thumb", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92), Ambient = Color3.fromRGB(205, 205, 212), LightColor = Color3.fromRGB(255, 248, 236),
		LightDirection = Vector3.new(0.35, -0.8, 0.6), ZIndex = z }, parent)
	local ok, m = pcall(function() return own and acc or acc:Clone() end)
	if not ok or not m then return vf end
	local lo, hi = Vector3.one * 1e9, Vector3.one * -1e9
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, h = p.CFrame, p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
				local q = cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		elseif p:IsA("LuaSourceContainer") then
			p:Destroy()
		end
	end
	if m:GetAttribute("ElementTint") then
		local def = elementDef(player:GetAttribute("Element"))
		local glow = m:FindFirstChild("Glow")
		if def and glow and glow:IsA("BasePart") then glow.Color = def.Base end
	end
	m.Parent = vf
	local centre, r = (lo + hi) / 2, math.max(0.2, (hi - lo).Magnitude / 2)
	local T = Tuning.Thumb
	local yaw, pitch = math.rad(T.Yaw), math.rad(T.Pitch)
	local off = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	local cam = Instance.new("Camera")
	cam.FieldOfView = T.FOV
	cam.CFrame = CFrame.lookAt(centre + off * (r / math.sin(math.rad(T.FOV / 2)) * 0.98), centre)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

--- (2026-10-29) an outfit's thumbnail: its upper-body pieces (torso, belt, arms, hands) as they stand in the catalog --
--- the rest pose, the rig at the origin -- framed like an accessory, so the row shows the outfit's bust
local BUST = { Chest = true, Back = true, Collar = true, Belt = true, UpperArmL = true, UpperArmR = true, ForearmL = true,
	ForearmR = true, HandL = true, HandR = true }
local function outfitThumb(parent, folder, z)
	local m = Instance.new("Model")
	for _, a in ipairs(folder and folder:GetChildren() or {}) do
		if a:IsA("Accessory") and BUST[a:GetAttribute("OutfitSlot")] then
			local ok, c = pcall(function() return a:Clone() end)
			if ok and c then c.Parent = m end
		end
	end
	return thumb(parent, m, z, true)
end

local function rowState(row, selected, glowColour)
	row.Selected = selected
	TweenService:Create(row.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = selected and 1.06 or 1 }):Play()
	row.Glow.Color = glowColour
	TweenService:Create(row.Glow, TweenInfo.new(0.18), { Transparency = selected and 0 or 1 }):Play()
	TweenService:Create(row.Holder, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(row.X + (selected and 14 or 0), row.Y) }):Play()
end
local ROW_X = 8
local RAIL_W, TILE_W = 304, 326
local function makeRow(parent, w, h, y, fill, z)
	local holder, face = K.slab(parent, UDim2.fromOffset(w, h), UDim2.fromOffset(ROW_X, y), fill, z, 6, 3, 8)
	local scale = K.make("UIScale", {}, holder)
	local glow = K.make("UIStroke", { Thickness = 5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, face)
	K.halftone(face, 0.9, K.C.Ink, 7, z + 1)
	local row = { Holder = holder, Face = face, Scale = scale, Glow = glow, X = ROW_X, Y = y, Selected = false }
	local h2 = hit(holder)
	h2.MouseEnter:Connect(function() if not row.Selected then TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.03 }):Play() end end)
	h2.MouseLeave:Connect(function() if not row.Selected then TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end end)
	row.Hit = h2
	return row
end
local function equippedTag(parent, z, word)
	local eq = K.make("Frame", { Name = "Equipped", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z, Visible = false }, parent)
	K.corner(eq, 4)
	K.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, eq)
	text(eq, { Text = word or "EQUIPPED", TextColor3 = C.Green, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), ZIndex = z + 1 })
	return eq
end
--- the one header both lists use: a Bangers tab on a slab, live = red ink and lifted
local function headerTab(parent, word, x, w)
	local holder, face = K.slab(parent, UDim2.fromOffset(w, 48), UDim2.fromOffset(x, 0), K.C.Card, 6, 5, 3, 4)
	local label = text(face, { Font = Enum.Font.Bangers, Text = word, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
	return { Holder = holder, Face = face, Label = label, X = x }
end
local function tabLook(t, on)
	t.Face.BackgroundColor3 = on and C.RedInk or K.C.Card
	t.Label.TextColor3 = on and K.C.CreamText or K.C.Ink
	TweenService:Create(t.Holder, TweenInfo.new(0.15), { Position = UDim2.fromOffset(t.X, on and -4 or 0) }):Play()
end
tabLook(headerTab(rail, "CATEGORIES", 0, 190), true)
local itemsTab = headerTab(itemsPanel, "", 0, 190)
tabLook(itemsTab, true)

----------------------------------------------------------------------------------------------------
-- state + painting the panel from it
----------------------------------------------------------------------------------------------------
local view = { Category = nil, SkinShown = nil }   -- SkinShown: a tone picked here that the server has not confirmed yet
local isOpen = false

local function categories()
	return W.CategoriesIn(catalog)
end
--- (2026-10-28) the rail: SKIN first, then the accessory categories (a data folder named like it is not listed twice)
--- (2026-10-29) ...with OUTFITS second: the whole body first, the accessories that go on top of it after
local function railEntries()
	local list = { W.SkinKey, W.OutfitKey }
	for _, c in ipairs(categories()) do
		if c ~= W.SkinKey and c ~= W.OutfitKey then list[#list + 1] = c end
	end
	return list
end
--- (2026-10-29) the outfits on offer (the server's mirror), and the one this player wears (its row info, else nil)
local function outfitList()
	return W.Outfits(outfitCatalog())
end
local function wornOutfit(list)
	local id = player:GetAttribute(W.OutfitAttr)
	for _, it in ipairs(list or outfitList()) do
		if it.Id == id then return it end
	end
	return nil
end
--- the tone the panel shows as worn: a pick on its way to the server, else the server's
local function skinShown()
	local i = view.SkinShown
	if i and W.SkinTones[i] then return i end
	return (W.SkinOf(player))
end
local function hintText()
	local what = (view.Category == W.SkinKey) and "A TONE" or (view.Category == W.OutfitKey and "AN OUTFIT") or "AN ITEM"
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "TAP " .. what .. "  ·  DRAG TO TURN" end
	return "CLICK " .. what .. "  ·  DRAG OR A/D TO TURN"
end
local function itemsOf(cat)
	return W.Items(catalog, cat)
end
local function wornIn(cat, worn)
	for _, it in ipairs(itemsOf(cat)) do
		if worn[it.Id] then return it end
	end
	return nil
end

local railConns, itemConns = {}, {}
local function clearList(list, conns)
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)
	list:ClearAllChildren()
end

local refreshItems
local function refreshRail()
	clearList(railList, railConns)
	local worn = W.WornSet(player)
	local cats = railEntries()
	local shownSkin = skinShown()
	gui:SetAttribute("Skin", shownSkin)
	for i, cat in ipairs(cats) do
		local sel = cat == view.Category
		local row = makeRow(railList, RAIL_W, 64, 8 + (i - 1) * 72, sel and K.C.Gold or K.C.Card, 4)
		row.Holder.Name = "Cat_" .. cat
		if cat == W.SkinKey then
			-- (2026-10-28) SKIN: the well is the worn tone itself, the tone's name on the right
			local tone = W.SkinTones[shownSkin]
			iconWell(row.Face, 44, 8, 7, tone.Color, nil, 8).Name = "Swatch"
			text(row.Face, { Font = Enum.Font.LuckiestGuy, Text = display(cat), TextSize = 25, Position = UDim2.fromOffset(68, 4),
				Size = UDim2.new(1, -170, 1, -4), ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
			text(row.Face, { Name = "Tone", FontFace = K.MONO, Text = tone.Name, TextColor3 = K.C.LockedInk, TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(110, 22), ZIndex = 8 })
			rowState(row, sel, K.C.Gold:Lerp(K.C.White, 0.3))
			railConns[#railConns + 1] = row.Hit.MouseButton1Click:Connect(function() command:Fire("category", cat) end)
			continue
		end
		if cat == W.OutfitKey then
			-- (2026-10-29) OUTFITS: the well shows the worn outfit's bust (else the first on offer), WEARING or the count
			local outfits = outfitList()
			local on = wornOutfit(outfits)
			local show = on or outfits[1]
			local well = iconWell(row.Face, 44, 8, 7, show and K.C.Pill or K.C.Track:Lerp(K.C.Ink, 0.2), (not show) and "O" or nil, 8)
			if show then outfitThumb(well, show.Folder, 9) end
			local word = text(row.Face, { Font = Enum.Font.LuckiestGuy, Text = display(cat), TextSize = 25, Position = UDim2.fromOffset(68, 4),
				Size = UDim2.new(1, -170, 1, -4), ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
			if #outfits == 0 and not sel then word.TextColor3 = K.C.Grey end
			if on then
				equippedTag(row.Face, 9, "WEARING").Visible = true
			else
				text(row.Face, { FontFace = K.MONO, Text = (#outfits == 0) and "EMPTY" or (#outfits .. (#outfits == 1 and " OUTFIT" or " OUTFITS")),
					TextColor3 = K.C.LockedInk, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(90, 22), ZIndex = 8 })
			end
			rowState(row, sel, K.C.Gold:Lerp(K.C.White, 0.3))
			railConns[#railConns + 1] = row.Hit.MouseButton1Click:Connect(function() command:Fire("category", cat) end)
			continue
		end
		local list = itemsOf(cat)
		local on = wornIn(cat, worn)
		local show = on or list[1]
		local well = iconWell(row.Face, 44, 8, 7, show and K.C.Pill or K.C.Track:Lerp(K.C.Ink, 0.2), (not show) and string.sub(display(cat), 1, 1) or nil, 8)
		if show then thumb(well, show.Acc, 9) end
		local word = text(row.Face, { Font = Enum.Font.LuckiestGuy, Text = display(cat), TextSize = 25, Position = UDim2.fromOffset(68, 4),
			Size = UDim2.new(1, -170, 1, -4), ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
		if #list == 0 and not sel then word.TextColor3 = K.C.Grey end
		if on then
			equippedTag(row.Face, 9, "WEARING").Visible = true
		else
			text(row.Face, { FontFace = K.MONO, Text = (#list == 0) and "EMPTY" or (#list .. (#list == 1 and " ITEM" or " ITEMS")), TextColor3 = K.C.LockedInk,
				TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(90, 22), ZIndex = 8 })
		end
		rowState(row, sel, K.C.Gold:Lerp(K.C.White, 0.3))
		railConns[#railConns + 1] = row.Hit.MouseButton1Click:Connect(function() command:Fire("category", cat) end)
	end
	railList.CanvasSize = UDim2.fromOffset(0, 8 + #cats * 72 + 4)
end

--- TOP DUELISTS' empty state (HubBoards' emptyCard), fitted to the column: the card slab, the LuckiestGuy headline over its
--- extrude, one GothamBold line in LockedInk -- what will show here, and (in brackets) why it is empty now
local function emptyState(cat)
	local w, pad = TILE_W, 16
	local titleText = "NO " .. display(cat) .. " YET"
	local tSize = 34
	while tSize > 18 and textW(titleText, tSize, Enum.Font.LuckiestGuy) > w - 6 - 2 * pad - 4 do tSize -= 2 end
	local titleH = math.floor(tSize * 76 / 64 + 0.5)
	local line = string.format("%s show here once they're in the catalog. (None in stock yet.)", (cat:sub(1, 1):upper() .. cat:sub(2)))
	local lineY = 18 + titleH + 8
	local lineH = TextService:GetTextSize(line, 16, Enum.Font.GothamBold, Vector2.new(w - 6 - 2 * pad, 1e4)).Y
	local h = lineY + lineH + 18 + 6
	local holder, face = K.slab(itemList, UDim2.fromOffset(w, h), UDim2.fromOffset(ROW_X, 8), K.C.Card, 4, 6, 3, 6)
	holder.Name = "Empty"
	K.halftone(face, 0.9, K.C.Ink, 7, 5)
	K.display(face, { Name = "Title", Text = titleText, TextSize = tSize, Position = UDim2.fromOffset(pad, 18), Size = UDim2.new(1, -2 * pad, 0, titleH),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 }, 3, K.C.Ink, EXTRUDE)
	K.make("TextLabel", { Name = "Line", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextWrapped = true, TextColor3 = K.C.LockedInk,
		Text = line, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(pad, lineY),
		Size = UDim2.new(1, -2 * pad, 0, lineH + 4), ZIndex = 8 }, face)
	itemList.CanvasSize = UDim2.fromOffset(0, 8 + h + 12)
end

--- (2026-10-28) the SKIN column: one card -- the worn tone's name over the extrude, then the palette as round swatches,
--- four to a row, light to dark; the worn one sits on a gold disc (an ink-edged gold ring round it) and swells a little.
--- No prices: every tone is free.
local SWATCH = { Cols = 4, Cell = 72, Disc = 70, Size = 52, Gap = 10, Swell = 1.07 }
local function skinColumn()
	local tones, shown = W.SkinTones, skinShown()
	local tone = tones[shown]
	itemsTab.Label.Text = display(W.SkinKey)
	tag.Text = "SKIN TONE  ·  " .. tone.Name
	gui:SetAttribute("Rows", #tones)
	gui:SetAttribute("Empty", false)
	gui:SetAttribute("Skin", shown)
	local S = SWATCH
	local faceW = TILE_W - 6                                   -- (the slab's shadow)
	local gapX = math.floor((faceW - S.Cols * S.Cell) / (S.Cols + 1))
	local x0 = math.floor((faceW - S.Cols * S.Cell - (S.Cols - 1) * gapX) / 2)
	local titleY, titleH = 14, 42
	local gridY = titleY + titleH + 8
	local rows = math.ceil(#tones / S.Cols)
	local h = gridY + rows * S.Cell + (rows - 1) * S.Gap + 16 + 6
	local holder, face = K.slab(itemList, UDim2.fromOffset(TILE_W, h), UDim2.fromOffset(ROW_X, 8), K.C.Card, 4, 6, 3, 6)
	holder.Name = "Skin"
	K.halftone(face, 0.9, K.C.Ink, 7, 5)
	K.display(face, { Name = "Title", Text = tone.Name, TextSize = 34, Position = UDim2.fromOffset(16, titleY), Size = UDim2.new(1, -32, 0, titleH),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 }, 3, K.C.Ink, EXTRUDE)
	for i, t in ipairs(tones) do
		local col, row = (i - 1) % S.Cols, (i - 1) // S.Cols
		local on = i == shown
		local cell = K.make("Frame", { Name = "Tone_" .. i, BackgroundTransparency = 1, Size = UDim2.fromOffset(S.Cell, S.Cell), ZIndex = 8,
			Position = UDim2.fromOffset(x0 + col * (S.Cell + gapX), gridY + row * (S.Cell + S.Gap)) }, face)
		cell:SetAttribute("Hex", t.Hex)
		cell:SetAttribute("Worn", on)
		local scale = K.make("UIScale", { Scale = on and S.Swell or 1 }, cell)
		local disc = K.make("Frame", { Name = "Ring", BackgroundColor3 = K.C.Gold, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S.Disc, S.Disc), ZIndex = 8, Visible = on }, cell)
		K.make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
		K.outline(disc, 2)
		local sw = K.make("Frame", { Name = "Swatch", BackgroundColor3 = t.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S.Size, S.Size), ZIndex = 9 }, cell)
		K.make("UICorner", { CornerRadius = UDim.new(1, 0) }, sw)
		K.outline(sw, 3)
		local h2 = hit(cell)
		h2.MouseEnter:Connect(function() if not on then TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play() end end)
		h2.MouseLeave:Connect(function() if not on then TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end end)
		itemConns[#itemConns + 1] = h2.MouseButton1Click:Connect(function() command:Fire("skin", i) end)
	end
	itemList.CanvasSize = UDim2.fromOffset(0, 8 + h + 12)
end

--- (2026-10-29) the OUTFITS column: one row per outfit (the accessory rows' look): the rarity / Element / gold spine, the
--- outfit's bust in the well, its name, the Element it dresses ("PYRO ONLY") or ANY ELEMENT, EQUIPPED -- "WHEN PYRO" while
--- the player is another Element (the coat shows until then) -- and on a locked one the padlock and its Robux price
local function outfitColumn()
	local cat = W.OutfitKey
	itemsTab.Label.Text = display(cat)
	local list = outfitList()
	local on = wornOutfit(list)
	tag.Text = (#list == 0) and (display(cat) .. "  ·  EMPTY") or (display(cat) .. "  ·  " .. #list .. (#list == 1 and " OUTFIT" or " OUTFITS"))
	gui:SetAttribute("Rows", #list)
	gui:SetAttribute("Empty", #list == 0)
	gui:SetAttribute("Outfit", on and on.Id or nil)
	if #list == 0 then
		emptyState(cat)
		return
	end
	local mine = player:GetAttribute("Element")
	for i, it in ipairs(list) do
		local owned = W.OwnsOutfit(player, it.Id)
		local isWorn = on ~= nil and on.Id == it.Id
		local def = elementDef(it.Element)
		local R = it.Rarity and K.Rarity[it.Rarity]
		local spine = (R and R.Color) or (def and def.Base) or K.C.Gold
		local row = makeRow(itemList, TILE_W, 76, 8 + (i - 1) * 84, owned and K.C.Card or K.C.Track, 4)
		row.Holder.Name = "Item_" .. it.Id
		local band = K.make("Frame", { BackgroundColor3 = owned and spine or K.C.Grey, BorderSizePixel = 0, Size = UDim2.new(0, 36, 1, 0), ZIndex = 6 }, row.Face)
		K.corner(band, 8)
		local well = iconWell(row.Face, 56, 8, 7, owned and K.C.Pill or K.C.Track, nil, 8)
		local t = outfitThumb(well, it.Folder, 9)
		if not owned then t.ImageTransparency = 0.35 end
		text(row.Face, { Text = string.upper(it.Name), TextColor3 = owned and K.C.Ink or K.C.Grey, TextSize = 20, Position = UDim2.fromOffset(74, 8),
			Size = UDim2.new(1, -86, 0, 28), ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
		local elWord = it.Element and string.upper((def and def.Display) or it.Element) or nil
		if R then
			K.rarityChip(row.Face, it.Rarity, 74, 42, 22, 14, 8)
		else
			text(row.Face, { FontFace = K.MONO, Text = elWord and (elWord .. " ONLY") or "ANY ELEMENT", TextColor3 = K.C.LockedInk, TextSize = 16,
				Position = UDim2.fromOffset(74, 42), Size = UDim2.fromOffset(140, 22), ZIndex = 8 })
		end
		local waiting = false   -- (2026-10-30) outfits are worn on any Element
		local eq = equippedTag(row.Face, 9, waiting and ("WHEN " .. elWord) or "EQUIPPED")
		eq.Position = UDim2.new(1, -10, 0, 53)
		eq.Visible = isWorn
		if not owned then pricePill(row.Face, robuxPrice(it.Robux), true, UDim2.new(1, -10, 0, 53), 30, 10, "Robux") end
		rowState(row, isWorn, (R and R.Color or spine):Lerp(K.C.White, 0.3))
		itemConns[#itemConns + 1] = row.Hit.MouseButton1Click:Connect(function() command:Fire("outfit", it.Id) end)
	end
	itemList.CanvasSize = UDim2.fromOffset(0, 8 + #list * 84 + 4)
end

function refreshItems()
	clearList(itemList, itemConns)
	local cat = view.Category
	gui:SetAttribute("Category", cat)
	hintWord.Text = hintText()
	if not cat then
		itemList.CanvasSize = UDim2.new()
		gui:SetAttribute("Rows", 0)
		return
	end
	if cat == W.SkinKey then
		skinColumn()
		return
	end
	if cat == W.OutfitKey then
		outfitColumn()
		return
	end
	itemsTab.Label.Text = display(cat)
	local list = itemsOf(cat)
	local worn = W.WornSet(player)
	tag.Text = (#list == 0) and (display(cat) .. "  ·  EMPTY") or (display(cat) .. "  ·  " .. #list .. (#list == 1 and " ITEM" or " ITEMS"))
	gui:SetAttribute("Rows", #list)
	gui:SetAttribute("Empty", #list == 0)
	if #list == 0 then
		emptyState(cat)
		return
	end
	for i, it in ipairs(list) do
		local owned = W.Owns(player, it.Id, it.Acc)   -- (2026-10-29: an Outfit's head-piece is owned with its outfit)
		local isWorn = worn[it.Id] == true
		local def = elementDef(it.Element)
		local R = it.Rarity and K.Rarity[it.Rarity]
		local spine = (R and R.Color) or (def and def.Base) or K.C.Gold
		local row = makeRow(itemList, TILE_W, 76, 8 + (i - 1) * 84, owned and K.C.Card or K.C.Track, 4)
		row.Holder.Name = "Item_" .. it.Id
		-- the spine: a thick band down the left, under the icon (rarity, else the item's Element, else the house gold)
		local band = K.make("Frame", { BackgroundColor3 = owned and spine or K.C.Grey, BorderSizePixel = 0, Size = UDim2.new(0, 36, 1, 0), ZIndex = 6 }, row.Face)
		K.corner(band, 8)
		local well = iconWell(row.Face, 56, 8, 7, owned and K.C.Pill or K.C.Track, nil, 8)
		local t = thumb(well, it.Acc, 9)
		if not owned then t.ImageTransparency = 0.35 end
		text(row.Face, { Text = string.upper(it.Name), TextColor3 = owned and K.C.Ink or K.C.Grey, TextSize = 20, Position = UDim2.fromOffset(74, 8),
			Size = UDim2.new(1, -86, 0, 28), ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
		if R then
			K.rarityChip(row.Face, it.Rarity, 74, 42, 22, 14, 8)
		else
			local sub = (def and string.upper(def.Display or it.Element)) or (it.Tint and "YOUR ELEMENT") or W.Singular[cat] or display(cat)
			if it.Outfit then sub = def and (string.upper(def.Display or it.Element) .. " OUTFIT") or "OUTFIT" end   -- (2026-10-29: a head-piece)
			text(row.Face, { FontFace = K.MONO, Text = sub, TextColor3 = K.C.LockedInk, TextSize = 16, Position = UDim2.fromOffset(74, 42), Size = UDim2.fromOffset(140, 22), ZIndex = 8 })
		end
		local eq = equippedTag(row.Face, 9)
		eq.Position = UDim2.new(1, -10, 0, 53)
		eq.Visible = isWorn
		if not owned then pricePill(row.Face, sparksPrice(it.Price), true, UDim2.new(1, -10, 0, 53), 30, 10) end
		rowState(row, isWorn, (R and R.Color or spine):Lerp(K.C.White, 0.3))
		itemConns[#itemConns + 1] = row.Hit.MouseButton1Click:Connect(function() command:Fire("item", it.Id) end)
	end
	itemList.CanvasSize = UDim2.fromOffset(0, 8 + #list * 84 + 4)
end

local function refreshPlate()
	if not view.Category then tag.Text = "PICK A CATEGORY" end
	refreshBalance()
end

----------------------------------------------------------------------------------------------------
-- the mirror: the reflection while the editor is open
----------------------------------------------------------------------------------------------------
local M = nil
local KEEP = { Decal = true, Texture = true, SpecialMesh = true, SurfaceAppearance = true }
local function stillCopy(p)
	-- a dynamic head (FaceControls): its face texture is grey and only a live head tints it by the skin Color, which a
	-- ViewportFrame does not -- so its copy is a FileMesh whose VertexColor does the tint (face and skin both read)
	if p:IsA("MeshPart") and p.TextureID ~= "" and p:FindFirstChildOfClass("FaceControls") then
		local ok, meshSize = pcall(function() return p.MeshSize end)
		local c = Instance.new("Part")
		c.Name = p.Name
		c.Size = p.Size
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.FileMesh
		m.MeshId = p.MeshId
		m.TextureId = p.TextureID
		m.Scale = (ok and meshSize.Magnitude > 0) and (p.Size / meshSize) or Vector3.one
		local k = Tuning.Mirror.HeadTint
		m.VertexColor = Vector3.new(p.Color.R * k, p.Color.G * k, p.Color.B * k)
		m.Parent = c
		return c
	end
	local was = p.Archivable
	p.Archivable = true
	local ok, c = pcall(function() return p:Clone() end)
	p.Archivable = was
	if not ok or not c then return nil end
	for _, d in ipairs(c:GetDescendants()) do
		if d.Parent and not KEEP[d.ClassName] then d:Destroy() end
	end
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
	c.LocalTransparencyModifier = 0
	return c
end
local function mirrorOf(v, n) return v - 2 * v:Dot(n) * n end
--- a CFrame's mirror image across the glass, kept a proper rotation by flipping its own X (left / right) axis: a part
--- symmetric left to right -- the blocky body, nearly every accessory -- draws exactly as its reflection
local function reflectCF(cf)
	local n = M.N
	local p = cf.Position
	return CFrame.fromMatrix(p - 2 * (p - M.Pc):Dot(n) * n, -mirrorOf(cf.XVector, n), mirrorOf(cf.YVector, n), mirrorOf(cf.ZVector, n))
end

local function mirrorClear()
	if not M then return end
	for _, c in ipairs(M.Conns) do c:Disconnect() end
	M.Gui:Destroy()
	M = nil
	gui:SetAttribute("Mirror", "off")
end

local function mirrorBuild()
	mirrorClear()
	local glass = hub:FindFirstChild(Tuning.Mirror.Part, true)
	if not (glass and glass:IsA("BasePart")) then return end
	local R = Tuning.Mirror
	local cf, size = glass.CFrame, glass.Size
	local n = cf.LookVector                                       -- the Front face's normal: out toward the room
	local sg = K.make("SurfaceGui", { Name = "WardrobeMirror", Adornee = glass, Face = Enum.NormalId.Front, LightInfluence = 0, AlwaysOnTop = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = R.PPS, ClipsDescendants = true, ResetOnSpawn = false }, playerGui)
	-- the clear glass, in studs from the face's centre along the face's own right (as seen from the room) and up
	local x0, x1 = -size.X / 2 + R.Inset.L, size.X / 2 - R.Inset.R
	local y0, y1 = -size.Y / 2 + R.Inset.B, size.Y / 2 - R.Inset.T
	local clip = K.make("Frame", { Name = "Clear", BackgroundTransparency = 1, ClipsDescendants = true,
		Position = UDim2.fromOffset(math.floor((x0 + size.X / 2) * R.PPS + 0.5), math.floor((size.Y / 2 - y1) * R.PPS + 0.5)),
		Size = UDim2.fromOffset(math.floor((x1 - x0) * R.PPS + 0.5), math.floor((y1 - y0) * R.PPS + 0.5)) }, sg)
	local vf = K.make("ViewportFrame", { Name = "Reflection", BackgroundTransparency = 1, Ambient = R.Ambient, LightColor = R.LightColor,
		LightDirection = mirrorOf(R.Light.Unit, n), ImageColor3 = R.Tint, ImageTransparency = R.Fade }, clip)
	local vcam = Instance.new("Camera")
	vcam.Parent = vf
	vf.CurrentCamera = vcam
	M = { Gui = sg, Clip = clip, VF = vf, Cam = vcam, N = n, Pc = cf.Position + n * (size.Z / 2), Right = -cf.RightVector, Up = cf.UpVector,
		X0 = x0, X1 = x1, Y0 = y0, Y1 = y1, Pairs = {}, Dirty = true, Conns = {} }
	-- the mirror world's one still prop: the pedestal under the reflection (the disc's top and its gold rim)
	local P = R.Pedestal
	local function disc(colour, radius, height, topY)
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Cylinder
		d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		d.Material = Enum.Material.SmoothPlastic
		d.Color = colour
		d.Size = Vector3.new(height, radius * 2, radius * 2)
		d.CFrame = reflectCF(CFrame.new(Tuning.Stand.X, topY - height / 2, Tuning.Stand.Z) * CFrame.Angles(0, 0, math.pi / 2))
		d.Parent = vf
	end
	disc(P.Top, P.R, P.H, Tuning.Stand.Y)
	disc(P.Rim, P.R + 0.08, 0.12, Tuning.Stand.Y - 0.22)
	local character = player.Character
	if character then
		M.Conns[#M.Conns + 1] = character.DescendantAdded:Connect(function() if M then M.Dirty = true end end)
		M.Conns[#M.Conns + 1] = character.DescendantRemoving:Connect(function() if M then M.Dirty = true end end)
	end
	gui:SetAttribute("Mirror", "on")
end

--- (2026-10-29) an outfit part's partner for the mirror. A copy can only be turned, never flipped, so reflectCF draws a
--- part's own mesh X-flipped about its own centre: exact for anything symmetric (the body, nearly every accessory), wrong
--- for an outfit's one-sided shapes (a pauldron's flare would face inward). Outfits are built in mirror pairs, so the
--- reflection of a left piece's part IS the right piece's matching part (and a centre piece's one-sided part, its partner
--- across the middle): drawn with THAT mesh at reflectCF(this part's rig frame) * the partner's rest pose, the picture is
--- exact. The partner is found in the outfit catalog by rest pose: centre mirrored across the rig's x = 0, the same size,
--- material and triangle count (the Tris attribute). Returns the partner template, this part's rest CFrame and its.
local TWIN_SLOT = { UpperArmL = "UpperArmR", UpperArmR = "UpperArmL", ForearmL = "ForearmR", ForearmR = "ForearmL", HandL = "HandR",
	HandR = "HandL", ThighL = "ThighR", ThighR = "ThighL", ShinL = "ShinR", ShinR = "ShinL", BootL = "BootR", BootR = "BootL" }
local function twinOf(d)
	local acc = d:FindFirstAncestorOfClass("Accessory")
	local id = acc and acc:GetAttribute("OutfitId")
	local slot = id and acc:GetAttribute("OutfitSlot")
	local cat = slot and outfitCatalog()
	local f = cat and cat:FindFirstChild(id)
	if not f then return nil end
	local mine = f:FindFirstChild(id .. "_" .. slot)
	local other = f:FindFirstChild(id .. "_" .. (TWIN_SLOT[slot] or slot))
	local src = mine and mine:FindFirstChild(d.Name)
	if not (src and other and src:IsA("BasePart")) then return nil end
	local c = src.Position
	local want = Vector3.new(-c.X, c.Y, c.Z)
	for _, t in ipairs(other:GetChildren()) do
		if t:IsA("BasePart") and t.Material == src.Material and (t.Position - want).Magnitude < 0.005
			and (t.Size - src.Size).Magnitude < 0.005 and t:GetAttribute("Tris") == src:GetAttribute("Tris") then
			return t, src.CFrame, t.CFrame
		end
	end
	return nil
end

local SKIN_PART = {}
for _, n in ipairs(W.SkinParts) do SKIN_PART[n] = true end
local function mirrorParts()
	for _, pr in ipairs(M.Pairs) do pr[2]:Destroy() end
	table.clear(M.Pairs)
	local character = player.Character
	local twins = 0
	for _, d in ipairs(character and character:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 and not d:FindFirstAncestor("Hitboxes") then
			local c, fixS, fixT
			local twin, restS, restT = twinOf(d)          -- (2026-10-29) an outfit part: its partner's mesh
			if twin then
				c = stillCopy(twin)
				if c then
					c.Color, c.Material = d.Color, d.Material
					fixS, fixT = restS:Inverse(), restT
					twins += 1
				end
			else
				c = stillCopy(d)
			end
			if c then
				c.Parent = M.VF
				-- (2026-10-28) the bare skin's colour as copied: a new tone re-copies (the copies are stills)
				M.Pairs[#M.Pairs + 1] = { d, c, (SKIN_PART[d.Name] and d.Parent == character) and d.Color or nil, fixS, fixT }
			end
		end
	end
	M.Dirty = false
	gui:SetAttribute("MirrorParts", #M.Pairs)
	gui:SetAttribute("MirrorTwins", twins)
end

--- each frame: the copies to their mirror images, and the reflection's camera to this eye, looking straight into the
--- glass. With the view square-on to the glass, the picture maps onto the glass by a plain scale and shift: the
--- ViewportFrame is laid on the face centred on the eye's foot, as tall as the view's frustum is at the glass.
local function mirrorStep(camCF)
	if not M then return end
	if M.Dirty then mirrorParts() end
	for i = #M.Pairs, 1, -1 do
		local src, c, skin, fixS, fixT = M.Pairs[i][1], M.Pairs[i][2], M.Pairs[i][3], M.Pairs[i][4], M.Pairs[i][5]
		if src.Parent then
			-- (2026-10-29) an outfit part drawn with its partner's mesh: the partner at the mirrored rig frame
			c.CFrame = fixS and (reflectCF(src.CFrame * fixS) * fixT) or reflectCF(src.CFrame)
			c.Transparency = src.Transparency
			if skin and src.Color ~= skin then M.Dirty = true end   -- (2026-10-28) a new skin tone: next frame re-copies
		else
			M.Dirty = true
		end
	end
	local E = camCF.Position
	local d = (E - M.Pc):Dot(M.N)
	local rel = E - M.Pc
	local du, dv = rel:Dot(M.Right), rel:Dot(M.Up)
	local halfW = math.max(math.abs(du - M.X0), math.abs(du - M.X1)) + 0.05
	local halfH = math.max(math.abs(dv - M.Y0), math.abs(dv - M.Y1)) + 0.05
	local fov = (d > 0.3) and 2 * math.deg(math.atan(halfH / d)) or 180
	if fov > 118 or halfW > 40 then
		M.VF.Visible = false          -- (too close or too steep for one picture: the plain glass, a moment)
		return
	end
	M.VF.Visible = true
	M.Cam.FieldOfView = fov
	M.Cam.CFrame = CFrame.lookAt(E, E - M.N, M.Up)
	local pps = Tuning.Mirror.PPS
	M.VF.Size = UDim2.fromOffset(math.floor(2 * halfW * pps + 0.5), math.floor(2 * halfH * pps + 0.5))
	M.VF.Position = UDim2.fromOffset(math.floor((du - halfW - M.X0) * pps + 0.5), math.floor((M.Y1 - dv - halfH) * pps + 0.5))
end

----------------------------------------------------------------------------------------------------
-- the pose and the camera
----------------------------------------------------------------------------------------------------
local cam = { Mode = "off", T0 = 0, From = nil, FromFOV = 70 }
-- (2026-10-28, the owner) the player turns their own avatar to see the look from every side: drag on the open screen
-- (not the panel), or hold A / D (arrows); the turn has weight (eased), and it settles where you let go
local SPIN = { Gain = 0.011, KeySpeed = 2.6, Friction = 5.5, Max = 9 }   -- rad per px; rad/s; per s; rad/s
local spin = { Yaw = 0, V = 0, Drag = false, Last = nil, T = nil }
local function overPanel(pos)
	local at = Vector2.new(pos.X, pos.Y) + game:GetService("GuiService"):GetGuiInset()
	for _, f in ipairs({ panelHolder, closeHolder, hintHolder }) do
		local a, z = f.AbsolutePosition, f.AbsoluteSize
		if f.Visible and at.X >= a.X and at.X <= a.X + z.X and at.Y >= a.Y and at.Y <= a.Y + z.Y then return true end
	end
	return false
end
UserInputService.InputBegan:Connect(function(input)
	if cam.Mode ~= "on" and cam.Mode ~= "in" then return end
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
		and not overPanel(input.Position) then
		spin.Drag, spin.Last, spin.V = true, input.Position, 0
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not spin.Drag then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		-- (a free mouse reports Delta 0: the move is read off Position)
		local dx = input.Position.X - (spin.Last and spin.Last.X or input.Position.X)
		spin.Last = input.Position
		local dYaw = dx * SPIN.Gain
		spin.Yaw += dYaw
		spin.V = math.clamp(spin.V * 0.6 + (dYaw * 60) * 0.4, -SPIN.Max, SPIN.Max)   -- (the release keeps a little spin)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		spin.Drag = false
	end
end)
local saved = { Guis = {}, Root = nil, Cam = nil, FOV = 70, Shown = {} }
local function ease(t) return t < 0.5 and 16 * t ^ 5 or 1 - (-2 * t + 2) ^ 5 / 2 end   -- quint in-out (the showcase's)

local function mirrorFrame()
	local glass = hub:FindFirstChild(Tuning.Mirror.Part, true)
	local n = glass and glass.CFrame.LookVector or Vector3.new(0, 0, -1)
	n = Vector3.new(n.X, 0, n.Z).Unit
	local plane = glass and (glass.Position + glass.CFrame.LookVector * (glass.Size.Z / 2)) or (Tuning.Stand - n * 1.8)
	return -n, (plane - Tuning.Stand):Dot(-n)        -- toward the mirror; the disc's centre to the glass
end
local FWD, GAP = mirrorFrame()

--- the root's CFrame on the disc, facing the glass
local function standCF(topY)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local lift = (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
	local at = Vector3.new(Tuning.Stand.X, (topY or Tuning.Stand.Y) + lift, Tuning.Stand.Z)
	return CFrame.lookAt(at, at + FWD)
end

--- the editor's framing: a 3/4 view of the avatar and the glass in front of it
local function framing()
	local Cm = Tuning.Cam
	local focus = Tuning.Stand + Vector3.new(0, Cm.LookUp, 0) + FWD * (GAP * 0.5)
	local back = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(Cm.Yaw)):VectorToWorldSpace(-FWD)
	local pos = focus + back * Cm.Dist + Vector3.new(0, Cm.Height, 0)
	return CFrame.lookAt(pos, focus) * CFrame.Angles(0, math.rad(Cm.AsideYaw), 0)
end

-- the first-person viewmodel rides the camera: hidden while the camera is ours (the showcase's way)
local savedLTM = setmetatable({}, { __mode = "k" })
local function hidePart(d, on)
	if on then
		if savedLTM[d] == nil then savedLTM[d] = d.LocalTransparencyModifier end
		d.LocalTransparencyModifier = 1
	elseif savedLTM[d] ~= nil then
		d.LocalTransparencyModifier = savedLTM[d]
		savedLTM[d] = nil
	end
end
local function viewmodelHide(on)
	local c = workspace.CurrentCamera
	for _, d in ipairs(c and c:GetDescendants() or {}) do
		if d:IsA("BasePart") then hidePart(d, on) end
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m.Name:find("Viewmodel") then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then hidePart(d, on) end
			end
		end
	end
end
-- FirstPersonController hides the local body every frame in first person; this step runs after it and shows it
local function showBody(on)
	local character = player.Character
	for _, d in ipairs(character and character:GetDescendants() or {}) do
		if (d:IsA("BasePart") or d:IsA("Decal")) and not d:FindFirstAncestor("Hitboxes") then
			d.LocalTransparencyModifier = on and 0 or 1
		end
	end
end

local pose = { Anchored = false, CF = nil }
local STEP = "WardrobeEditorCamera"
local function stepCamera()
	local c = workspace.CurrentCamera
	if not c or cam.Mode == "off" then return end
	c.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	viewmodelHide(true)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	local dt = math.min(now - (spin.T or now), 0.1)
	spin.T = now
	local keys = ((UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)) and 1 or 0)
		- ((UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)) and 1 or 0)
	if keys ~= 0 then
		spin.V = keys * SPIN.KeySpeed
		spin.Yaw += spin.V * dt
	elseif not spin.Drag then
		spin.V *= math.exp(-SPIN.Friction * dt)
		spin.Yaw += spin.V * dt
	end
	if pose.Anchored and root and pose.CF then
		-- (2026-10-29, the owner: no turning in first person) first person hands the Humanoid AutoRotate under a
		-- camera-relative RotationType, and it snapped the body back to its facing every frame: off while the avatar stands
		local hum = pose.Character and pose.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.AutoRotate then
			pose.AutoRotate = true
			hum.AutoRotate = false
		end
		root.CFrame = pose.CF * CFrame.Angles(0, spin.Yaw, 0)
	end
	local target = framing()
	if cam.Mode == "in" then
		local e = ease(math.clamp((now - cam.T0) / Tuning.Cam.In, 0, 1))
		c.CFrame = cam.From:Lerp(target, e)
		c.FieldOfView = cam.FromFOV + (Tuning.Cam.FOV - cam.FromFOV) * e
		showBody(true)
		if e >= 1 then cam.Mode = "on" end
	elseif cam.Mode == "out" then
		local e = ease(math.clamp((now - cam.T0) / Tuning.Cam.Out, 0, 1))
		c.CFrame = target:Lerp(saved.Cam, e)
		c.FieldOfView = Tuning.Cam.FOV + (saved.FOV - Tuning.Cam.FOV) * e
		-- (the body fades back to first person's hidden as the camera nears the head)
		showBody(e < 0.6 or player.CameraMode ~= Enum.CameraMode.LockFirstPerson)
	else
		c.CFrame = target
		c.FieldOfView = Tuning.Cam.FOV
		showBody(true)
	end
	mirrorStep(c.CFrame)
end

----------------------------------------------------------------------------------------------------
-- open / close: the HUD and prompts stand down (the showcase's way), the avatar on the disc, the camera in
----------------------------------------------------------------------------------------------------
local MOVE_SINK = "WardrobeMoveSink"
local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down,
	Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA }
local OTHER_SCREENS = { "SettingsOpen", "LoadoutOpen", "QuickPlayOpen", "ShopOpen", "ReactionsOpen" }

local function hud(off)
	if off then
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Name ~= "HubWipe" and g.Enabled then
				saved.Guis[g] = true
				g.Enabled = false
			end
		end
	else
		for g in pairs(saved.Guis) do
			if g.Parent then g.Enabled = true end
		end
		table.clear(saved.Guis)
	end
end

--- the walkable top under the disc (the hub's collider: what the server stands the body on), else the disc's own
local function colliderTop()
	local cols = hub:FindFirstChild("Colliders")
	if not cols then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { cols }
	local r = workspace:Raycast(Tuning.Stand + Vector3.new(0, 6, 0), Vector3.new(0, -9, 0), params)
	return r and r.Position.Y or nil
end

local closing = false
-- (2026-10-28, the owner) the editor is SOLO: while it is open every OTHER player is hidden on this client -- body,
-- accessories, face, name -- so the only body in the room (and in the mirror) is your own. Each editor sees only itself.
local solo = { On = false, Conns = {}, Saved = setmetatable({}, { __mode = "k" }) }
local function soloPart(d, on)
	local prop, hidden
	if d:IsA("BasePart") then prop, hidden = "LocalTransparencyModifier", 1
	elseif d:IsA("Humanoid") then prop, hidden = "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None
	elseif d:IsA("BillboardGui") then prop, hidden = "Enabled", false
	else return end
	-- (2026-10-29 fix) the value it had is kept ON the instance (a local attribute, never replicated), not in a weak
	-- table, so it can always be put back: players who had used the wardrobe went on hiding everyone after leaving it
	if on then
		if d:GetAttribute("WardrobeSolo") == nil then
			local was = d[prop]
			d:SetAttribute("WardrobeSoloWas", typeof(was) == "EnumItem" and was.Name or was)
			d:SetAttribute("WardrobeSolo", true)
		end
		d[prop] = hidden
	elseif d:GetAttribute("WardrobeSolo") then
		local was = d:GetAttribute("WardrobeSoloWas")
		if prop == "DisplayDistanceType" then
			was = (type(was) == "string" and Enum.HumanoidDisplayDistanceType[was]) or Enum.HumanoidDisplayDistanceType.Viewer
		elseif was == nil then
			was = (prop == "Enabled") or 0
		end
		d[prop] = was
		d:SetAttribute("WardrobeSolo", nil)
		d:SetAttribute("WardrobeSoloWas", nil)
	end
end
local function soloCharacter(ch, on)
	for _, d in ipairs(ch:GetDescendants()) do soloPart(d, on) end
end
local function soloSet(on)
	if solo.On == on then return end
	solo.On = on
	for _, c in ipairs(solo.Conns) do c:Disconnect() end
	table.clear(solo.Conns)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then soloCharacter(p.Character, on) end
	end
	if not on then return end
	local function watchCharacter(ch)
		if not solo.On then return end   -- (2026-10-29 fix) a deferred hide that lands after the editor closed
		soloCharacter(ch, true)
		solo.Conns[#solo.Conns + 1] = ch.DescendantAdded:Connect(function(d) if solo.On then soloPart(d, true) end end)
	end
	local function watch(p)
		if p == player then return end
		if p.Character then solo.Conns[#solo.Conns + 1] = p.Character.DescendantAdded:Connect(function(d) if solo.On then soloPart(d, true) end end) end
		solo.Conns[#solo.Conns + 1] = p.CharacterAdded:Connect(function(ch) if solo.On then task.defer(watchCharacter, ch) end end)
	end
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	solo.Conns[#solo.Conns + 1] = Players.PlayerAdded:Connect(watch)
end

-- (2026-10-29 fix) while the editor is CLOSED nobody stays hidden on this client: anything still marked by the solo
-- hide (a close that never ran -- a respawn, a teleport, a late hide) is put back, once a second
task.spawn(function()
	while true do
		task.wait(1)
		if not solo.On then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Character then
					for _, d in ipairs(p.Character:GetDescendants()) do
						if d:GetAttribute("WardrobeSolo") then soloPart(d, false) end
					end
				end
			end
		end
	end
end)

local function openEditor()
	if isOpen then return end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return end
	if player:GetAttribute("DuelMatch") ~= nil or (player:GetAttribute("Zone") ~= nil and player:GetAttribute("Zone") ~= "Hub") then return end
	for _, a in ipairs(OTHER_SCREENS) do
		if player:GetAttribute(a) then return end
	end
	isOpen, closing = true, false
	gui:SetAttribute("Open", true)
	player:SetAttribute("WardrobeOpen", true)
	player:SetAttribute("LoadoutOpen", true)          -- (the input scripts' "a screen is up": movement and casting stand down)
	ProximityPromptService.Enabled = false
	local c = workspace.CurrentCamera
	saved.Cam, saved.FOV, saved.Root = c.CFrame, c.FieldOfView, root.CFrame
	-- the avatar onto the disc: first where the server will see it (the collider's top), then, anchored on this client,
	-- on the disc itself, facing the glass
	local top = colliderTop()
	character:PivotTo(standCF(top or Tuning.Stand.Y))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	pose.CF, pose.Character = standCF(Tuning.Stand.Y), character
	spin.Yaw, spin.V, spin.Drag = 0, 0, false
	task.delay(0.15, function()
		if not isOpen or closing or player.Character ~= character then return end
		root.Anchored = true
		pose.Anchored = true
	end)
	ContextActionService:BindActionAtPriority(MOVE_SINK, function() return Enum.ContextActionResult.Sink end,
		false, Enum.ContextActionPriority.High.Value + 100, table.unpack(MOVE_KEYS))
	-- (the pad's B here; Esc never reaches a bound action -- Roblox's menu takes it -- so Esc is watched below)
	ContextActionService:BindActionAtPriority("WardrobeLeave", function(_, state)
		if state == Enum.UserInputState.Begin then command:Fire("close") end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
	hud(true)
	soloSet(true)
	mirrorBuild()
	cam.From, cam.FromFOV, cam.T0, cam.Mode = saved.Cam, saved.FOV, os.clock(), "in"
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 20, stepCamera)
	view.Category = nil
	setPicked(false, true)
	refreshRail()
	refreshItems()
	refreshPlate()
	hintWord.Text = hintText()
	fit()
	gui.Enabled = true
	slideUI(true, 0.35)
end

local function closeEditor(andThen)
	if not isOpen or closing then return end
	closing = true
	slideUI(false)
	cam.Mode, cam.T0 = "out", os.clock()
	task.delay(Tuning.Cam.Out, function()
		RunService:UnbindFromRenderStep(STEP)
		pcall(function() ContextActionService:UnbindAction(MOVE_SINK) end)
		pcall(function() ContextActionService:UnbindAction("WardrobeLeave") end)
		mirrorClear()
		-- the avatar back where it stood (the same body only: a respawn keeps its own spawn)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character == pose.Character then
			root.Anchored = false
			if saved.Root then character:PivotTo(saved.Root) end
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		end
		if pose.AutoRotate then   -- (2026-10-29) AutoRotate back as it was
			local hum = pose.Character and pose.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.AutoRotate = true end
			pose.AutoRotate = nil
		end
		pose.Anchored, pose.CF, pose.Character = false, nil, nil
		local c = workspace.CurrentCamera
		if c then
			c.CameraType = Enum.CameraType.Custom
			c.FieldOfView = saved.FOV
		end
		viewmodelHide(false)
		soloSet(false)
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then showBody(true) end   -- (first person hides it again itself)
		hud(false)
		gui.Enabled = false
		cam.Mode = "off"
		ProximityPromptService.Enabled = true
		player:SetAttribute("LoadoutOpen", nil)
		player:SetAttribute("WardrobeOpen", nil)
		gui:SetAttribute("Open", false)
		isOpen, closing = false, false
		if andThen then task.defer(andThen) end
	end)
end

local function openShop()
	local shop = playerGui:FindFirstChild("SpellshotShop")
	local cmd = shop and shop:FindFirstChild("Command")
	if cmd then cmd:Fire("open") end
end

----------------------------------------------------------------------------------------------------
-- commands (the buttons, the prompt and the Studio check hook)
----------------------------------------------------------------------------------------------------
local function pick(id)
	for _, cat in ipairs(categories()) do
		for _, it in ipairs(itemsOf(cat)) do
			if it.Id == id then return it, cat end
		end
	end
	return nil
end

-- (2026-10-28) the skin tone's trip to the server: one request at a time, spaced past WardrobeServer's MIN_GAP, always
-- ending on the LAST pick (quick clicks through the palette never come back "busy"); then the panel follows the server
local skinSend = { Busy = false, Want = nil }
local function sendSkin()
	if skinSend.Busy or not skinSend.Want or not remote then return end
	local i = skinSend.Want
	skinSend.Want, skinSend.Busy = nil, true
	task.spawn(function()
		local okCall, ok, code = pcall(function() return remote:InvokeServer("Skin", i) end)
		gui:SetAttribute("LastReply", okCall and tostring(code) or "error")
		task.wait(0.15)
		skinSend.Busy = false
		if skinSend.Want then
			sendSkin()
			return
		end
		view.SkinShown = nil
		if not (okCall and ok) then
			-- refused: the server's tone back on this client's body and in the panel
			local _, colour = W.SkinOf(player)
			W.PaintSkin(player.Character, colour)
			if isOpen then
				refreshRail()
				refreshItems()
			end
		end
	end)
end

command.Event:Connect(function(what, arg)
	if what == "open" then
		openEditor()
	elseif what == "close" then
		closeEditor()
	elseif what == "fit" then
		fit(arg or false)
	elseif not isOpen or closing then
		return
	elseif what == "category" and type(arg) == "string" then
		view.Category = (view.Category ~= arg) and arg or nil      -- (the picked category again closes its column)
		setPicked(view.Category ~= nil)
		refreshRail()
		refreshItems()
		refreshPlate()
	elseif what == "item" and type(arg) == "string" then
		local it, cat = pick(arg)
		if not it then return end
		gui:SetAttribute("LastClick", arg)
		if not W.Owns(player, it.Id, it.Acc) then
			-- locked: no purchase here -- the Shop (the editor steps out first)
			closeEditor(openShop)
			return
		end
		if not remote then return end
		if view.Category ~= cat then
			view.Category = cat
			setPicked(true)
		end
		local verb = W.WornSet(player)[it.Id] and "Unequip" or "Equip"
		task.spawn(function()
			local okCall, ok, code = pcall(function() return remote:InvokeServer(verb, it.Id) end)
			gui:SetAttribute("LastReply", okCall and tostring(code) or "error")
			if not (okCall and ok) and isOpen then refreshItems() end
		end)
	elseif what == "outfit" and type(arg) == "string" then
		-- (2026-10-29) an outfit: on, or off when it is the one worn; locked -> the Shop, as a locked accessory
		local it
		for _, o in ipairs(outfitList()) do
			if o.Id == arg then it = o end
		end
		if not it then return end
		gui:SetAttribute("LastClick", arg)
		if not W.OwnsOutfit(player, it.Id) then
			closeEditor(openShop)
			return
		end
		if not remote then return end
		if view.Category ~= W.OutfitKey then
			view.Category = W.OutfitKey
			setPicked(true)
		end
		local verb = (player:GetAttribute(W.OutfitAttr) == it.Id) and "UnequipOutfit" or "EquipOutfit"
		task.spawn(function()
			local okCall, ok, code = pcall(function() return remote:InvokeServer(verb, it.Id) end)
			gui:SetAttribute("LastReply", okCall and tostring(code) or "error")
			if not (okCall and ok) and isOpen then refreshItems() end
		end)
	elseif what == "skin" then
		-- (2026-10-28) a skin tone: seen at once on this client (the avatar, so the mirror too), then the server's say
		local i = tonumber(arg)
		local tone = i and W.SkinTones[i]
		if not tone or not remote then return end
		gui:SetAttribute("LastClick", "Skin_" .. i)
		if view.Category ~= W.SkinKey then
			view.Category = W.SkinKey
			setPicked(true)
		end
		view.SkinShown = i
		W.PaintSkin(player.Character, tone.Color)
		skinSend.Want = i
		sendSkin()
		refreshRail()
		refreshItems()
	end
end)
closeHit.MouseButton1Click:Connect(function() command:Fire("close") end)
-- Esc (measured 2026-10-28): Roblox's menu takes it, so a ContextActionService bind never fires; InputBegan still sees it
-- (game-processed) as the menu opens. Either way out of the editor: Esc, or the Roblox menu opening by its own button.
UserInputService.InputBegan:Connect(function(input)
	if isOpen and input.KeyCode == Enum.KeyCode.Escape then command:Fire("close") end
end)
GuiService.MenuOpened:Connect(function()
	if isOpen then command:Fire("close") end
end)

-- the rows follow the server (what is worn, what is owned), the plate the balance, the lists the data
player.AttributeChanged:Connect(function(name)
	if not isOpen then return end
	if name == W.WornAttr or name == W.OwnedAttr or name == "Element" or name == W.SkinAttr   -- (2026-10-28: + SkinTone)
		or name == W.OutfitAttr or name == W.OutfitOwnedAttr then                                 -- (2026-10-29: + the outfit)
		refreshRail()
		refreshItems()
	elseif name == "Sparks" then
		refreshBalance()
	elseif name == "Zone" and player:GetAttribute("Zone") ~= "Hub" then
		closeEditor()
	end
end)
if catalog then
	catalog:GetAttributeChangedSignal("Version"):Connect(function()
		if isOpen then
			refreshRail()
			refreshItems()
		end
	end)
end
-- (2026-10-29) the outfits' mirror: the same, whenever it (re)appears or changes
do
	local conn = nil
	local function hookOutfits(f)
		if conn then conn:Disconnect() end
		conn = f:GetAttributeChangedSignal("Version"):Connect(function()
			if isOpen then
				refreshRail()
				refreshItems()
			end
		end)
	end
	if outfitCatalog() then hookOutfits(outfitCatalog()) end
	spell.ChildAdded:Connect(function(c)
		if c.Name == W.OutfitCatalogName then
			hookOutfits(c)
			if isOpen then
				refreshRail()
				refreshItems()
			end
		end
	end)
end
player.CharacterRemoving:Connect(function()
	if isOpen then
		pose.Anchored, pose.Character = false, nil
		closeEditor()
	end
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() fit() end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit() end)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() fit() end)

----------------------------------------------------------------------------------------------------
-- the prompt: HubBoards' placard way (an anchor inside the hub model: HubClient's bind, HubPrompts' balloon)
----------------------------------------------------------------------------------------------------
do
	local P = Tuning.Prompt
	local anchor = Instance.new("Part")
	anchor.Name = "HubLife_WardrobePrompt"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow, anchor.Transparency = true, false, false, false, false, 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(P.At)
	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText, pp.ActionText = "Wardrobe", "Open"
	pp.HoldDuration, pp.MaxActivationDistance = P.Hold, P.Reach
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode, pp.GamepadKeyCode = Enum.KeyCode.G, Enum.KeyCode.ButtonB   -- HubClient applies the player's own bind
	pp.Parent = anchor
	anchor.Parent = hub
	pp.Triggered:Connect(function()
		gui:SetAttribute("Triggered", (gui:GetAttribute("Triggered") or 0) + 1)
		command:Fire("open")
	end)
end

----------------------------------------------------------------------------------------------------
-- the Propeller Cap's propeller (any worn Spin part: its SpinWeld turns about the part's own Y, on every client)
----------------------------------------------------------------------------------------------------
do
	local spins = {}
	local function scan(acc)
		local s = acc:IsA("Accessory") and acc:FindFirstChild("Spin")
		local w = s and s:FindFirstChild("SpinWeld")
		local base = s and s:GetAttribute("SpinBaseC0")
		if w and w:IsA("Weld") and typeof(base) == "CFrame" then spins[w] = base end
	end
	local function watchCharacter(ch)
		for _, c in ipairs(ch:GetChildren()) do scan(c) end
		ch.ChildAdded:Connect(function(c) task.defer(scan, c) end)
	end
	local function watchPlayer(p)
		if p.Character then watchCharacter(p.Character) end
		p.CharacterAdded:Connect(watchCharacter)
	end
	for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
	Players.PlayerAdded:Connect(watchPlayer)
	RunService.Heartbeat:Connect(function()
		if next(spins) == nil then return end
		local a = (os.clock() * 9) % (2 * math.pi)
		for w, base in pairs(spins) do
			if w.Parent then w.C0 = base * CFrame.Angles(0, a, 0) else spins[w] = nil end
		end
	end)
end

gui:SetAttribute("Ready", true)
