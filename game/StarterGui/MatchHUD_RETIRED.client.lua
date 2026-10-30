--[[
	MatchHUD  (LocalScript)  ->  StarterGui/MatchHUD

	The in-match HUD for SPELLSHOT. Builds one ScreenGui named "SpellshotHUD".

	LAYOUT
	  bottom-left, stacked        StatusTag  (only while a status is active)
	                              Health bar
	                              Mana bar   (thinner, immediately beneath)

	  bottom-right, clustered     [M1][Primary][Mobility][Defense]  [ ULTIMATE ]
	                                                       [Passive] sits above the
	                                                       row/Ultimate boundary

	SIX SLOTS, NOT FIVE
	  Design manual v0.2 split M1 (basic attack) from the Primary Ability (a distinct battle
	  ability). The row therefore carries both. M1 has no cooldown UI -- it is fire-rate limited,
	  not cooldown limited -- and is drawn with the ELEMENT LOGO rather than a role glyph, because
	  the manual's own reasoning for bundling M1 with the Element is that an opponent's basic
	  attack is what tells you which Element you are fighting.

	THE HEALTH AND MANA BARS ARE ART, NOT FRAMES
	  Everything else here is drawn with Roblox Frames and UIStroke. These two are Blender
	  renders (blender_scripts/build_hud_bars.py): thick black comic ink, a hand-wobbled panel
	  edge, halftone dots in the empty channel and a hard offset drop shadow -- none of which a
	  UICorner and a UIStroke can produce, because their whole character is that they are NOT
	  geometrically even. The fill is a fixed-size image inside a clipping frame rather than a
	  stretched one, so the halftone and the gloss keep their pixel scale at every health value.

	FILL TREATMENTS ON THE ABILITY SLOTS
	  * Primary/Mobility/Defense are cooldown timers -> bottom-up wipe + numeric countdown.
	  * Ultimate is a charge meter built from damage dealt/taken (manual, Section 3), so it fills
	    UP toward ready and pulses at 100% -- deliberately the opposite motion to a cooldown.
	  * M1 and always-on Passives have no fill layer at all.
	  * Passive treatment is per-Element (SpellshotConfig.Elements[e].Passive.Display).

	STATE comes from attributes so a match loop, a test script, or nothing at all can drive it:
	  player:    Element, Mobility, Defense, Ultimate   (loadout)
	  character: Mana, UltCharge, CD_<role>, CDTotal_<role>, PassiveActive/Expires/Stacks/Proc,
	             Status, StatusExpires, StatusTotal, MoveState
	Health is read from the Humanoid directly.
]]

-- (2026-10-19, audit P6A-08) RETIRED: PopArtHUD is the HUD. A "_RETIRED" name does not stop a StarterGui LocalScript
-- from running, and if it ran it built a second HUD and replaced _G.SpellshotHUD (the dev panel's calls then errored).
-- It now stops here whatever its Enabled says. Delete it (or move it to ServerStorage) in Studio when convenient.
do return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local IconAssets = require(folder:WaitForChild("IconAssets"))
Config.Icons = IconAssets

----------------------------------------------------------------------------------------------------
-- look & metrics
----------------------------------------------------------------------------------------------------
-- BAR_ART numbers are the pixel geometry the Blender renders were produced at, printed by
-- build_hud_bars.py. They are here rather than eyeballed so the fill lands exactly in the
-- trough; if the art is re-rendered at a different size, copy the new HUD_GEO values across.
local BAR_ART = {
	Health = { Image = { 364, 72 }, Trough = { 315, 27 }, Offset = { 24, 22 } },
	Mana   = { Image = { 364, 70 }, Trough = { 315, 25 }, Offset = { 24, 22 } },
	Burst  = { 170, 170 },
}

local UI = {
	Margin = 26,
	TagHeight = 32,
	TagGap = 12,
	BarGap = 2,

	Slot = 64,          -- M1 / Primary / Mobility / Defense
	SlotGap = 8,
	Ult = 88,           -- deliberately larger: higher impact, and the mobile layout gives it
	UltGap = 10,        -- its own big button (manual, Section 3)
	Passive = 46,

	Ink = Color3.fromRGB(8, 11, 18),          -- the bold dark outline stroke, used everywhere
	Panel = Color3.fromRGB(15, 20, 31),
	PanelLo = Color3.fromRGB(8, 11, 19),
	Empty = Color3.fromRGB(26, 32, 46),
	Chip = Color3.fromRGB(222, 60, 52),       -- the comic red behind a health drop
	-- the bars are printed on newsprint, so their numerals are ink on paper, not white on dark
	BarInk = Color3.fromRGB(24, 22, 28),
	Text = Color3.fromRGB(236, 244, 255),
	Dim = Color3.fromRGB(120, 138, 165),
	Stroke = 2,
}

-- M1 is the always-available left click. Q/E/R for the three Techniques matches the genre
-- SPELLSHOT is positioned against; F for the Primary Ability is the PC stand-in for the
-- manual's "dedicated button for Primary Ability" on the mobile layout.
local KEY_LABEL = { M1 = "LMB", Primary = "F", Mobility = "Q", Defense = "E", Ultimate = "R" }
local COOLDOWN_ROLES = { "Primary", "Mobility", "Defense" }

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end

local function corner(parent, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function stroke(parent, color, thickness)
	return make("UIStroke", {
		Color = color or UI.Ink, Thickness = thickness or UI.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

----------------------------------------------------------------------------------------------------
-- build
----------------------------------------------------------------------------------------------------
if playerGui:FindFirstChild("SpellshotHUD") then playerGui.SpellshotHUD:Destroy() end
-- the ice prototype's bar is superseded by this one; never show both
if playerGui:FindFirstChild("IceAbilityHUD") then playerGui.IceAbilityHUD:Destroy() end

local gui = make("ScreenGui", {
	Name = "SpellshotHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- crosshair -------------------------------------------------------------------------------------
local crosshair = make("Frame", {
	Name = "Crosshair", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 6, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.1, BorderSizePixel = 0,
}, gui)
corner(crosshair, 3)
stroke(crosshair, UI.Ink, 1.5)

-- Charge ring for a chargeable M1. Manual v0.2 gives Terra "Boulder Shot -- hold to charge,
-- release early for less damage; the only chargeable M1 in the game", so this does have a real
-- consumer now (v0.1 had none, which is why it shipped hidden). Nothing calls it yet because
-- Terra's M1 is not built; HUD.SetPrimaryCharge is the hook when it is.
local chargeRing = make("Frame", {
	Name = "PrimaryCharge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 22),
	Size = UDim2.new(0, 46, 0, 4), BackgroundColor3 = UI.Empty, BorderSizePixel = 0, Visible = false,
}, gui)
corner(chargeRing, 2)
stroke(chargeRing, UI.Ink, 1.5)
local chargeFill = make("Frame", {
	Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
}, chargeRing)
corner(chargeFill, 2)

----------------------------------------------------------------------------------------------------
-- bottom-left: status tag + health + mana
----------------------------------------------------------------------------------------------------
local leftH = UI.TagHeight + UI.TagGap + BAR_ART.Health.Image[2] + UI.BarGap + BAR_ART.Mana.Image[2]
local left = make("Frame", {
	Name = "LeftCluster", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, UI.Margin, 1, -UI.Margin),
	Size = UDim2.new(0, BAR_ART.Health.Image[1], 0, leftH),
}, gui)

--- The status tag. Every player carries this above their head in world space; the local player
--- cannot see their own, so their copy lives here, directly above the Health bar.
local function buildStatusTag(parent, height, anchorLeft)
	local tag = make("Frame", {
		Name = "StatusTag", BackgroundColor3 = UI.Panel, BorderSizePixel = 0,
		AnchorPoint = anchorLeft and Vector2.new(0, 0) or Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 168, 0, height), Visible = false,
	}, parent)
	corner(tag, math.floor(height * 0.3))
	local st = stroke(tag, UI.Ink, UI.Stroke)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(30, 40, 60), UI.PanelLo), Rotation = 90,
	}, tag)
	local icon = make("ImageLabel", {
		Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, math.floor(height * 0.16), 0.5, 0),
		Size = UDim2.new(0, height - 8, 0, height - 8), ScaleType = Enum.ScaleType.Fit, ZIndex = 2,
	}, tag)
	local label = make("TextLabel", {
		Name = "Label", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, height + 2, 0.5, 0), Size = UDim2.new(1, -(height + 10), 1, 0),
		Font = Enum.Font.GothamBold, TextSize = math.floor(height * 0.46),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Text,
		TextStrokeTransparency = 0.5, TextStrokeColor3 = UI.Ink, Text = "", ZIndex = 2,
	}, tag)
	local timer = make("Frame", {
		Name = "Timer", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = UI.Text, BorderSizePixel = 0, ZIndex = 3,
	}, tag)

	local api = {}
	function api.Set(statusName, remaining, total)
		local def = Config.Statuses[statusName]
		if not def then api.Hide(); return end
		local col = Config.ElementColor(def.Element)
		tag.Visible = true
		st.Color = UI.Ink
		icon.Image = Config.ElementLogo(def.Element)
		label.Text = def.Label
		label.TextColor3 = col
		timer.BackgroundColor3 = col
		local frac = (total and total > 0) and math.clamp((remaining or 0) / total, 0, 1) or 1
		timer.Size = UDim2.new(frac, 0, 0, 3)
		-- width follows the label so short names do not sit in a long empty pill
		tag.Size = UDim2.new(0, math.clamp(label.TextBounds.X + height + 26, 110, 240), 0, height)
	end
	function api.Hide() tag.Visible = false end
	api.Frame = tag
	return api
end

local statusTag = buildStatusTag(left, UI.TagHeight, true)
statusTag.Frame.Position = UDim2.new(0, 0, 0, 0)

--- A comic bar: the Blender-rendered frame, a red chip layer, the rendered fill clipped from the
--- left, ink numerals, and a starburst that fires on damage.
local function buildComicBar(parent, y, art, frameImage, fillImage, withChip, name, fontSize)
	local root = make("ImageLabel", {
		Name = name, BackgroundTransparency = 1, Image = frameImage,
		Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(0, art.Image[1], 0, art.Image[2]),
		ZIndex = 3,
	}, parent)

	local ox, oy = art.Offset[1], art.Offset[2]
	local tw, th = art.Trough[1], art.Trough[2]

	local chip
	if withChip then
		chip = make("Frame", {
			Name = "Chip", BackgroundColor3 = UI.Chip, BorderSizePixel = 0,
			Position = UDim2.new(0, ox, 0, oy), Size = UDim2.new(0, tw, 0, th), ZIndex = 1,
		}, root)
	end

	-- clip + fixed-size image: stretching the fill would smear the halftone and the gloss line
	local clip = make("Frame", {
		Name = "FillClip", BackgroundTransparency = 1, ClipsDescendants = true,
		Position = UDim2.new(0, ox, 0, oy), Size = UDim2.new(0, tw, 0, th), ZIndex = 2,
	}, root)
	local fill = make("ImageLabel", {
		Name = "Fill", BackgroundTransparency = 1, Image = fillImage,
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, tw, 0, th), ZIndex = 2,
	}, clip)

	local text = make("TextLabel", {
		Name = "Value", BackgroundTransparency = 1,
		Position = UDim2.new(0, ox, 0, oy), Size = UDim2.new(0, tw - 8, 0, th),
		Font = Enum.Font.LuckiestGuy, TextSize = fontSize, TextColor3 = UI.BarInk,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 5,
	}, root)

	local burst = make("ImageLabel", {
		Name = "Burst", BackgroundTransparency = 1, Image = IconAssets.HUD.Burst,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, ox + tw, 0, oy + th * 0.5),
		Size = UDim2.new(0, 0, 0, 0), Visible = false, ZIndex = 6,
	}, root)

	return {
		Root = root, Clip = clip, Fill = fill, Chip = chip, Text = text, Burst = burst,
		TroughW = tw, TroughH = th, OX = ox, OY = oy,
	}
end

local healthBar = buildComicBar(left, UI.TagHeight + UI.TagGap, BAR_ART.Health,
	IconAssets.HUD.FrameHealth, IconAssets.HUD.FillHealth, true, "HealthBar", 20)
local manaBar = buildComicBar(left, UI.TagHeight + UI.TagGap + BAR_ART.Health.Image[2] + UI.BarGap,
	BAR_ART.Mana, IconAssets.HUD.FrameMana, IconAssets.HUD.FillMana, false, "ManaBar", 15)

----------------------------------------------------------------------------------------------------
-- bottom-right: ability cluster
----------------------------------------------------------------------------------------------------
local ROW = { "M1", "Primary", "Mobility", "Defense" }
local rowW = UI.Slot * #ROW + UI.SlotGap * (#ROW - 1)
local clusterW = rowW + UI.UltGap + UI.Ult
local clusterH = UI.Passive + 10 + UI.Ult
local right = make("Frame", {
	Name = "AbilityCluster", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -UI.Margin, 1, -UI.Margin), Size = UDim2.new(0, clusterW, 0, clusterH),
}, gui)

--- One ability slot. `fillMode`:
---   "cooldown" bottom-up wipe that drains as the ability comes back
---   "charge"   bottom-up fill that builds toward ready, then pulses
---   "none"     no fill layer at all (M1, and always-on Passives)
local function buildSlot(name, size, x, y, fillMode, keyLabel)
	local slot = make("Frame", {
		Name = name, Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, size, 0, size),
		BackgroundColor3 = UI.Panel, BorderSizePixel = 0,
	}, right)
	corner(slot, math.floor(size * 0.17))
	local st = stroke(slot, UI.Ink, UI.Stroke + 1)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(30, 40, 60), UI.PanelLo), Rotation = 90,
	}, slot)

	-- the Element tint lives on an inner rim so the bold dark outline stays the outermost edge
	local rim = make("Frame", {
		Name = "Rim", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, ZIndex = 2,
	}, slot)
	corner(rim, math.floor(size * 0.14))
	local rimStroke = stroke(rim, Color3.fromRGB(120, 140, 170), 2)

	local icon = make("ImageLabel", {
		Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, size - 16, 0, size - 16),
		ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
	}, slot)

	local fill, count
	if fillMode ~= "none" then
		fill = make("Frame", {
			Name = "Fill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(6, 10, 20),
			BackgroundTransparency = fillMode == "charge" and 0.55 or 0.35,
			BorderSizePixel = 0, ZIndex = 4,
		}, slot)
		corner(fill, math.floor(size * 0.17))
		count = make("TextLabel", {
			Name = "Count", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.GothamBlack, TextSize = math.floor(size * 0.34), TextColor3 = UI.Text,
			TextStrokeTransparency = 0.35, TextStrokeColor3 = UI.Ink, Text = "", ZIndex = 5,
		}, slot)
	end

	local key
	if keyLabel then
		key = make("TextLabel", {
			Name = "Key", BackgroundColor3 = UI.PanelLo, BackgroundTransparency = 0.1, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 9),
			Size = UDim2.new(0, math.max(26, #keyLabel * 9 + 12), 0, 15),
			Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = UI.Dim, Text = keyLabel, ZIndex = 6,
		}, slot)
		corner(key, 4)
		stroke(key, UI.Ink, 1.5)
	end

	local badge = make("TextLabel", {
		Name = "Badge", BackgroundColor3 = UI.PanelLo, BackgroundTransparency = 0.05, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 3, 0, -3),
		Size = UDim2.new(0, 20, 0, 20), Font = Enum.Font.GothamBlack, TextSize = 12,
		TextColor3 = UI.Text, Text = "", Visible = false, ZIndex = 7,
	}, slot)
	corner(badge, 10)
	stroke(badge, UI.Ink, 1.5)

	return {
		Frame = slot, Icon = icon, Fill = fill, Count = count, Rim = rimStroke,
		Stroke = st, Key = key, Badge = badge, Size = size, Mode = fillMode,
	}
end

local rowY = clusterH - UI.Slot
local ultY = clusterH - UI.Ult
local slots = {}
for i, role in ipairs(ROW) do
	local mode = (role == "M1") and "none" or "cooldown"
	slots[role] = buildSlot(role, UI.Slot, (UI.Slot + UI.SlotGap) * (i - 1), rowY, mode, KEY_LABEL[role])
end
slots.Ultimate = buildSlot("Ultimate", UI.Ult, rowW + UI.UltGap, ultY, "charge", KEY_LABEL.Ultimate)
-- Passive sits above the boundary between the row and the Ultimate, as in the layout sketch.
slots.Passive = buildSlot("Passive", UI.Passive, rowW + UI.UltGap - math.floor(UI.Passive * 0.5),
	ultY - UI.Passive - 10, "none", nil)

local ultReady = make("TextLabel", {
	Name = "Ready", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 20),
	Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = UI.Text,
	TextStrokeTransparency = 0.25, TextStrokeColor3 = UI.Ink, Text = "READY", Visible = false, ZIndex = 6,
}, slots.Ultimate.Frame)

----------------------------------------------------------------------------------------------------
-- world-space status tags over other players (the local player's copy is the one above, on the HUD)
----------------------------------------------------------------------------------------------------
local worldTags = {}

local function ensureWorldTag(otherPlayer)
	local character = otherPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return nil end
	local rec = worldTags[otherPlayer]
	if rec and rec.Billboard.Parent == head then return rec end
	if rec then rec.Billboard:Destroy() end
	local bb = make("BillboardGui", {
		Name = "SpellshotStatusTag", Adornee = head, AlwaysOnTop = false,
		Size = UDim2.new(0, 168, 0, 30), StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0),
		MaxDistance = 90, LightInfluence = 0,
	}, head)
	rec = { Billboard = bb, Tag = buildStatusTag(bb, 26, false) }
	rec.Tag.Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	worldTags[otherPlayer] = rec
	return rec
end

Players.PlayerRemoving:Connect(function(p)
	local rec = worldTags[p]
	if rec then rec.Billboard:Destroy() end
	worldTags[p] = nil
end)

----------------------------------------------------------------------------------------------------
-- state plumbing
----------------------------------------------------------------------------------------------------
local function attr(inst, name, default)
	if not inst then return default end
	local v = inst:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function loadout()
	return {
		Element = attr(player, "Element", Config.DefaultLoadout.Element),
		Mobility = attr(player, "Mobility", Config.DefaultLoadout.Mobility),
		Defense = attr(player, "Defense", Config.DefaultLoadout.Defense),
		Ultimate = attr(player, "Ultimate", Config.DefaultLoadout.Ultimate),
	}
end

--- Repaint every slot for the current loadout. M1/Primary/Passive follow the Element; the three
--- Technique slots follow the equipped Technique's ORIGIN Element, which is what makes a
--- cross-Element build legible at a glance (manual: cross-Element mixing is a feature).
local function applyLoadout()
	local lo = loadout()
	for role, slot in pairs(slots) do
		local elem = Config.SlotElement(lo, role)
		slot.Icon.Image = Config.RoleIcon(role, elem)
		slot.Rim.Color = Config.ElementColor(elem)
		if slot.Count then slot.Count.TextColor3 = UI.Text end
	end
	ultReady.TextColor3 = Config.ElementColor(Config.SlotElement(lo, "Ultimate"))
	return lo
end

local currentLoadout = applyLoadout()
for _, name in ipairs({ "Element", "Mobility", "Defense", "Ultimate" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		currentLoadout = applyLoadout()
	end)
end

----------------------------------------------------------------------------------------------------
-- damage impact: the comic starburst
----------------------------------------------------------------------------------------------------
local impact = { Until = 0, Seed = 0 }

local function fireImpact(fracAfter)
	local b = healthBar.Burst
	impact.Until = os.clock() + 0.34
	impact.Seed = math.random() * 100
	b.Visible = true
	b.Position = UDim2.new(0, healthBar.OX + math.floor(healthBar.TroughW * fracAfter),
		0, healthBar.OY + healthBar.TroughH * 0.5)
end

----------------------------------------------------------------------------------------------------
-- per-frame update
----------------------------------------------------------------------------------------------------
local shownHealth = 1
local chipHealth = 1
local lastHealthFrac = 1

local function setSlotDim(slot, dim)
	slot.Icon.ImageColor3 = dim and Color3.fromRGB(118, 132, 156) or Color3.new(1, 1, 1)
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = os.clock()
	local lo = currentLoadout

	-- health ------------------------------------------------------------------------------------
	local hp = humanoid and humanoid.Health or 0
	local maxHp = (humanoid and humanoid.MaxHealth > 0) and humanoid.MaxHealth or Config.MaxHealth
	local hFrac = math.clamp(hp / maxHp, 0, 1)
	if hFrac < lastHealthFrac - 0.001 then fireImpact(hFrac) end
	lastHealthFrac = hFrac

	shownHealth = shownHealth + (hFrac - shownHealth) * math.clamp(18 * dt, 0, 1)
	-- the chip layer lags behind, so a burst of damage reads as a red edge sliding back rather
	-- than as an instant jump
	chipHealth = (chipHealth < shownHealth) and shownHealth
		or chipHealth + (hFrac - chipHealth) * math.clamp(2.6 * dt, 0, 1)
	healthBar.Clip.Size = UDim2.new(0, math.floor(healthBar.TroughW * shownHealth), 0, healthBar.TroughH)
	if healthBar.Chip then
		healthBar.Chip.Size = UDim2.new(0, math.floor(healthBar.TroughW * chipHealth), 0, healthBar.TroughH)
	end
	healthBar.Text.Text = string.format("%d", math.max(0, math.floor(hp + 0.5)))

	-- impact burst + shake ------------------------------------------------------------------------
	do
		local b = healthBar.Burst
		if now < impact.Until then
			local t = 1 - (impact.Until - now) / 0.34
			local size = math.floor(BAR_ART.Burst[1] * (0.45 + 0.75 * t))
			b.Size = UDim2.new(0, size, 0, size)
			b.ImageTransparency = t * t          -- holds full opacity then drops away fast
			b.Rotation = impact.Seed + t * 26
			-- the whole left cluster kicks, which sells the hit far better than the bar alone
			local k = (1 - t) * 4
			left.Position = UDim2.new(0, UI.Margin + math.sin(now * 90 + impact.Seed) * k,
				1, -UI.Margin + math.cos(now * 77) * k * 0.6)
		elseif b.Visible then
			b.Visible = false
			left.Position = UDim2.new(0, UI.Margin, 1, -UI.Margin)
		end
	end

	-- mana --------------------------------------------------------------------------------------
	local mana = attr(character, "Mana", Config.MaxMana)
	local mFrac = math.clamp(mana / Config.MaxMana, 0, 1)
	manaBar.Clip.Size = UDim2.new(0, math.floor(manaBar.TroughW * mFrac), 0, manaBar.TroughH)
	manaBar.Text.Text = string.format("%d", math.floor(mana + 0.5))

	-- cooldown slots ------------------------------------------------------------------------------
	for _, role in ipairs(COOLDOWN_ROLES) do
		local slot = slots[role]
		local readyAt = attr(character, "CD_" .. role, 0)
		local total = attr(character, "CDTotal_" .. role, 1)
		local remain = math.max(0, readyAt - now)
		local frac = (total > 0) and math.clamp(remain / total, 0, 1) or 0
		slot.Fill.Size = UDim2.new(1, 0, frac, 0)
		slot.Count.Text = remain > 0 and string.format(remain >= 10 and "%d" or "%.1f", remain) or ""
		setSlotDim(slot, remain > 0)
	end

	-- ultimate charge -------------------------------------------------------------------------------
	do
		local slot = slots.Ultimate
		local charge = math.clamp(attr(character, "UltCharge", 0), 0, 1)
		-- fills UP toward ready: the dim overlay retreats downward as charge builds
		slot.Fill.Size = UDim2.new(1, 0, 1 - charge, 0)
		local ready = charge >= 1
		slot.Count.Text = ready and "" or string.format("%d%%", math.floor(charge * 100))
		ultReady.Visible = ready
		setSlotDim(slot, not ready)
		if ready then
			local pulse = 0.5 + 0.5 * math.sin(now * 6)
			slot.Stroke.Color = Config.ElementColor(Config.SlotElement(lo, "Ultimate")):Lerp(UI.Ink, 1 - pulse)
			ultReady.TextTransparency = 0.15 * (1 - pulse)
		else
			slot.Stroke.Color = UI.Ink
		end
	end

	-- passive ---------------------------------------------------------------------------------------
	do
		local slot = slots.Passive
		local def = Config.Elements[lo.Element]
		local mode = def and def.Passive.Display or "None"
		local active = true
		if mode == "State" then
			active = attr(character, "PassiveActive", false) == true
		elseif mode == "Timer" then
			local expires = attr(character, "PassiveExpires", 0)
			active = math.max(0, expires - now) > 0
			slot.Badge.Visible = false
			slot.Rim.Transparency = active and 0 or 0.55
		elseif mode == "Stacks" then
			local n = attr(character, "PassiveStacks", 0)
			slot.Badge.Visible = n > 0
			slot.Badge.Text = tostring(n)
			active = n > 0
		elseif mode == "Proc" then
			local last = attr(character, "PassiveProc", 0)
			active = (now - last) < 0.6            -- brief flash on proc, no persistent fill
		end
		if mode ~= "Timer" then slot.Rim.Transparency = active and 0 or 0.6 end
		setSlotDim(slot, not active)
	end

	-- status tag -------------------------------------------------------------------------------------
	do
		local name = attr(character, "Status", nil)
		local expires = attr(character, "StatusExpires", 0)
		local total = attr(character, "StatusTotal", 1)
		local remain = expires > 0 and (expires - now) or 0
		if name and name ~= "" and (expires == 0 or remain > 0) then
			statusTag.Set(name, remain, total)
		else
			statusTag.Hide()
		end
	end

	-- other players' world tags -------------------------------------------------------------------
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ch = other.Character
			local name = attr(ch, "Status", nil)
			if name and name ~= "" then
				local rec = ensureWorldTag(other)
				if rec then
					local expires = attr(ch, "StatusExpires", 0)
					rec.Tag.Set(name, math.max(0, expires - now), attr(ch, "StatusTotal", 1))
				end
			elseif worldTags[other] then
				worldTags[other].Tag.Hide()
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- exposed hooks
----------------------------------------------------------------------------------------------------
local HUD = {}

--- Charge indicator for a chargeable M1 (Terra's Boulder Shot). alpha 0..1, or nil to hide.
function HUD.SetPrimaryCharge(alpha)
	if not alpha then chargeRing.Visible = false; return end
	chargeRing.Visible = true
	chargeFill.Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
	chargeFill.BackgroundColor3 = Config.ElementColor(currentLoadout.Element)
end

_G.SpellshotHUD = HUD
return nil
