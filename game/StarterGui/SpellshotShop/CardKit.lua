--[[ CardKit (ModuleScript) -> StarterGui.SpellshotShop.CardKit
SPELLSHOT shop v4 (2026-10-03): the ONE drawing kit, drawn in the game's own NEWSPRINT menu kit (Quick Play, Map Vote,
Loadout, Settings; lifted into src/house_kit_reference.luau). The builder (Edit, through loadstring of this Source) and
ShopController (runtime, through require) both draw with it, so a card the controller generates is the same code as a
static card.
  * THE KIT: paper under an ink dot screen; flat colour slabs with a heavy ink border and ONE solid ink shadow, offset
    down-right; near-square corners; a tilted gold title banner; red Bangers banner headings; Roboto Mono capitals for
    small labels; LuckiestGuy titles with a hard extrude. No UIGradient, no glow, no soft shadow, no disc behind art.
  * NUMBERS: Quick Play draws a 1160 x 600 canvas at about 1.57x on a 1080p screen; the shop's canvas is 1920 x 1080 at
    about 0.95x, so Quick Play's 8 / 3 / 3 (shadow, border, radius) are 12 / 5 / 5 here, and its mono 14-18 is 22-28.
    Every slab carries the one 5 px border (as Quick Play's one weight); only the shadow steps down on small slabs.
  * ONE PALETTE TABLE (PALETTES) drives every colour; rarity, Element and Sparks colours have their own tables. Two
    palettes ship: Newsprint (default) and Ink. setTheme picks one, buildDesign draws the whole canvas in it, copyLook
    moves a fresh build's colours onto the live one. The palettes differ in COLOUR ONLY (no transparency, size or tree
    differs), so a live switch is a pure colour copy and the controller's cached transparencies stay right.
  * CARDS: Item_<id> (the button: slot, name, attributes) > Shadow (stays put) + Face (centre-anchored, UIScale) with
    everything else. Plain at rest. HoverFX inside Face holds all that appears on hover: the flat rarity fill, a
    halftone patch and the recoloured text. faceCard records the fades (Base*) and the lift (LiftX, LiftY, LiftScale,
    RestX, RestY, RestStroke, HoverStroke) as attributes for the controller; poseCard applies them at once.
  * the runtime pieces: buildGrid (the Catalog page's wall: layout 1 "Wall", 2026-10-04: group headings and
    wallCards, 4 across), fillConfirm (the popup), paint* (highlights), setToast, shopChip.
Pure drawing: no state, no input, no remotes, no MarketplaceService.
]]
local TS = game:GetService("TextService")
local K = {}

-- ---------------------------------------------------------------- fonts: the kit's four, nothing else
local F = {
	display = Font.fromEnum(Enum.Font.LuckiestGuy),   -- titles, big buttons' words, stickers
	banner = Font.fromEnum(Enum.Font.Bangers),        -- red banner headings, ink head bars
	black = Font.fromEnum(Enum.Font.GothamBlack),     -- rows, tabs, numbers
	bold = Font.fromEnum(Enum.Font.GothamBold),
	mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),   -- every small label
}
local FE = { display = Enum.Font.LuckiestGuy, banner = Enum.Font.Bangers, black = Enum.Font.GothamBlack }
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function hex(h) h = h:gsub("#", ""); return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end

-- ---------------------------------------------------------------- THE PALETTE (the only place a kit colour is written)
-- Roles: Ink = borders, shadows, ink bars and chips, text on Gold/Green. Paper = the backdrop and the popup sheet.
-- Card = card and panel faces. Pill = pills, paper buttons, paper chips. Track = bar tracks, an idle day, CLAIMED.
-- RedInk = banner headings and the active tab; Red = stickers. Gold = the title banner, highlights. Green = Buy/Claim.
-- CreamText/CreamDim = text on Ink, RedInk, Red, Green. Text/Dim = text on Paper, Card and Pill. Idle = an unselected
-- option's word. Extrude = the knocked-back copy under a title on Paper/Card. Dot = the dot screen on Paper/Card.
-- Cache = the Elemental Cache's flood. Chest/ChestLid = the chest drawing. Sheet = the popup's sheet. Sel / OnSel = the
-- chosen segment's or sort chip's block and its word. Missing keys fall back to Newsprint.
local PALETTES = {
	Newsprint = {
		label = "Newsprint", feel = "the game's menus: cream paper under an ink dot screen, ink borders and shadows",
		Ink = { 17, 17, 17 }, Paper = { 234, 229, 216 }, Card = { 246, 243, 235 }, Pill = { 250, 247, 240 },
		Track = { 222, 213, 196 }, Red = { 228, 37, 31 }, RedInk = { 200, 30, 26 }, Cyan = { 18, 198, 231 },
		Gold = { 245, 184, 0 }, Green = { 126, 204, 36 }, CreamText = { 250, 244, 232 }, CreamDim = { 206, 200, 188 },
		Grey = { 120, 116, 106 }, LockedInk = { 88, 82, 72 }, Hover = { 224, 218, 202 }, White = { 255, 255, 255 },
		Text = { 17, 17, 17 }, Dim = { 120, 116, 106 }, Idle = { 17, 17, 17 }, Extrude = { 222, 213, 196 },
		Dot = { 17, 17, 17 }, Cache = { 91, 43, 181 }, Chest = { 88, 82, 72 }, ChestLid = { 120, 116, 106 },
		Sheet = { 234, 229, 216 }, Sel = { 17, 17, 17 }, OnSel = { 250, 244, 232 },
	},
	Ink = {
		label = "Ink", feel = "the colours of the first shop in the game's shapes: charcoal paper, cream text, near-black ink",
		-- the faces are a step lighter than the brief's 28,29,36 / 38,40,51 / 48,51,63 (the brief allows it) so that the
		-- near-black borders and shadows READ: shadow on paper 1.17:1 -> 1.5:1, border on card 1.35:1 -> 1.95:1
		Ink = { 10, 10, 12 }, Paper = { 46, 48, 60 }, Card = { 62, 65, 82 }, Pill = { 76, 80, 98 }, Track = { 38, 40, 50 },
		Grey = { 150, 146, 138 }, LockedInk = { 150, 146, 138 }, Hover = { 84, 88, 108 },
		Text = { 250, 244, 232 }, Dim = { 206, 200, 188 }, Idle = { 206, 200, 188 }, Extrude = { 10, 10, 12 },
		Dot = { 128, 132, 152 }, Chest = { 92, 96, 114 }, ChestLid = { 118, 123, 144 },
		Sheet = { 62, 65, 82 }, Sel = { 250, 244, 232 }, OnSel = { 10, 10, 12 },
	},
}
local THEME_ORDER = { "Newsprint", "Ink" }
local C = {}            -- the active palette as Color3s: every drawing reads it at call time
local INK, SEA = nil, nil

-- ---------------------------------------------------------------- the kit's numbers (design px on the 1920 x 1080 canvas)
local BIG = { s = 12, b = 5, r = 5 }   -- cards, panels, the big buttons, the title banner, the back slab
local MED = { s = 10, b = 5, r = 4 }   -- pills, banner headings, the tab strip, rows
local SML = { s = 8, b = 5, r = 3 }    -- price pills on small cards, small buttons
local S, B, R = BIG.s, BIG.b, BIG.r
local CHIP_B, CHIP_R = 3, 3            -- chips: thin border, no shadow
local LIFT = { px = 6, grow = 8, scale = 1.05, hover = 5, selected = 10, press = 3 }
local DOT = "rbxassetid://82944445925061"   -- BarKit's halftone cell: one white dot per tile
local FLAT = "rbxasset://textures/ui/InGameMenu/WhiteSquare.png"   -- built-in content: an opaque white square (the scroll bar)
local ZR, ZFX, ZART, ZTXT, ZTOP = 2, 3, 4, 5, 6   -- a card Face's layers: rest-only, HoverFX, art, text and pills, stickers

-- ---------------------------------------------------------------- tiny helpers
local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c end
local function outline(o, t, colour, transp)
	local s = Instance.new("UIStroke"); s.Thickness = t; s.Color = colour or C.Ink; s.Transparency = transp or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = o
	return s
end
-- frame: colour nil = transparent. opts: r (corner), transp, z, stroke { thickness, colour, transparency }, clip
local function frame(parent, name, x, y, w, h, color, opts)
	opts = opts or {}
	local f = Instance.new("Frame")
	f.Name = name; f.Position = UDim2.fromOffset(x, y); f.Size = UDim2.fromOffset(w, h); f.BorderSizePixel = 0
	if color then f.BackgroundColor3 = color; f.BackgroundTransparency = opts.transp or 0 else f.BackgroundTransparency = 1 end
	f.ClipsDescendants = opts.clip or false
	if opts.z then f.ZIndex = opts.z end
	if opts.r then corner(f, opts.r) end
	if opts.stroke then outline(f, opts.stroke[1], opts.stroke[2], opts.stroke[3]) end
	f.Parent = parent
	return f
end
local function tbutton(parent, name, x, y, w, h, color, opts)
	opts = opts or {}
	local b = Instance.new("TextButton")
	b.Name = name; b.Text = ""; b.AutoButtonColor = false; b.BorderSizePixel = 0
	b.Position = UDim2.fromOffset(x, y); b.Size = UDim2.fromOffset(w, h)
	if color then b.BackgroundColor3 = color; b.BackgroundTransparency = opts.transp or 0 else b.BackgroundTransparency = 1 end
	if opts.z then b.ZIndex = opts.z end
	if opts.r then corner(b, opts.r) end
	if opts.stroke then outline(b, opts.stroke[1], opts.stroke[2], opts.stroke[3]) end
	b.Parent = parent
	return b
end
local AX = { L = Enum.TextXAlignment.Left, C = Enum.TextXAlignment.Center, R = Enum.TextXAlignment.Right }
local AY = { T = Enum.TextYAlignment.Top, C = Enum.TextYAlignment.Center, B = Enum.TextYAlignment.Bottom }
-- label: GothamBlack, the palette's Text colour, one line, unless opts say otherwise. Nothing under 14 px.
-- opts: font, ax, ay, wrap, rich, z, stroke { thickness, colour } (a text outline)
local function label(parent, name, x, y, w, h, text, size, color, opts)
	opts = opts or {}
	local t = Instance.new("TextLabel")
	t.Name = name; t.BackgroundTransparency = 1; t.Position = UDim2.fromOffset(x, y); t.Size = UDim2.fromOffset(w, h)
	t.FontFace = opts.font or F.black; t.TextSize = math.max(14, size or 24); t.TextColor3 = color or C.Text
	t.Text = text; t.TextWrapped = opts.wrap == true
	t.TextXAlignment = AX[opts.ax or "L"]; t.TextYAlignment = AY[opts.ay or "C"]
	if opts.rich then t.RichText = true end
	if opts.z then t.ZIndex = opts.z end
	if opts.stroke then
		local s = Instance.new("UIStroke"); s.Thickness = opts.stroke[1]; s.Color = opts.stroke[2] or C.Ink
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; s.Parent = t
	end
	t.Parent = parent
	return t
end
-- the kit's small label: bold Roboto Mono, typed in CAPITALS with " · " as the separator
local function mono(parent, name, x, y, w, h, text, size, color, opts)
	opts = opts or {}
	return label(parent, name, x, y, w, h, text, size, color, { font = F.mono, ax = opts.ax, ay = opts.ay, wrap = opts.wrap, z = opts.z })
end
local function textW(str, size, font) return TS:GetTextSize(str, size, font or Enum.Font.GothamBlack, Vector2.new(9999, 9999)).X end
local function monoW(str, size) return math.ceil((utf8.len(str) or #str) * size * 0.6) + 2 end   -- Roboto Mono advances 0.6 em
local function fmt(n) local s = tostring(n); while true do local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2"); s = r; if k == 0 then break end end; return s end
local function fitSize(str, maxW, size, minS, font)
	while size > (minS or 20) and textW(str, size, font) > maxW do size -= 2 end
	return size
end

-- HALFTONE: the dot cell, tiled. on = "paper" (the palette's Dot on Paper/Card/Pill), "colour" (ink dots on a colour
-- slab) or "ink" (white dots on an ink bar). alpha is ImageTransparency (0.78 strong .. 0.9 faint). A sized rectangle,
-- so it can be a PATCH; r rounds it to its slab's corner when it covers a whole face.
local function halftone(parent, name, x, y, w, h, on, alpha, pitch, z, r)
	local i = Instance.new("ImageLabel")
	i.Name = name; i.BackgroundTransparency = 1; i.BorderSizePixel = 0; i.Image = DOT
	i.ImageColor3 = (on == "ink" and C.White) or (on == "colour" and C.Ink) or C.Dot
	i.ImageTransparency = alpha; i.ScaleType = Enum.ScaleType.Tile; i.TileSize = UDim2.fromOffset(pitch, pitch)
	i.Position = UDim2.fromOffset(x, y); i.Size = UDim2.fromOffset(w, h)
	if z then i.ZIndex = z end
	if r then corner(i, r) end
	i.Parent = parent
	return i
end

-- SLAB: holder (transparent; a TextButton when o.button) > Shadow (solid ink, offset kind.s down-right, never moves) +
-- Face (flat colour, ink border kind.b, radius kind.r). The holder's box INCLUDES the shadow, as in Quick Play.
-- Returns holder, face, face width, face height. o: button, z, rot. A slab button carries Kit = "SlabButton".
local function slab(parent, name, x, y, w, h, colour, kind, o)
	kind = kind or BIG; o = o or {}
	local s = kind.s
	local holder = o.button and tbutton(nil, name, x, y, w, h) or frame(nil, name, x, y, w, h)
	if o.z then holder.ZIndex = o.z end
	if o.rot then holder.Rotation = o.rot end
	if o.button then holder:SetAttribute("Kit", "SlabButton") end
	frame(holder, "Shadow", s, s, w - s, h - s, C.Ink, { r = kind.r, z = 0 })
	local face = frame(holder, "Face", 0, 0, w - s, h - s, colour, { r = kind.r, z = 1, stroke = { kind.b, C.Ink } })
	holder.Parent = parent
	return holder, face, w - s, h - s
end
-- A CARD's slab: the same, but the holder is the button and the Face is centre-anchored with a UIScale, so the
-- controller can lift it off the Shadow (position + scale) while the button keeps its slot and hit area.
local function slabCard(parent, name, x, y, w, h)
	local card = tbutton(nil, name, x, y, w, h)
	local fw, fh = w - S, h - S
	frame(card, "Shadow", S, S, fw, fh, C.Ink, { r = R, z = 0 })
	local face = frame(card, "Face", fw / 2, fh / 2, fw, fh, C.Card, { r = R, z = 1, stroke = { B, C.Ink } })
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	local sc = Instance.new("UIScale"); sc.Name = "UIScale"; sc.Parent = face
	card.Parent = parent
	return card, face, fw, fh
end
-- TITLE WITH ITS EXTRUDE: two identical labels, the back one knocked `depth` px down-right. Returns face, extrude.
-- o: font, ax, ay, wrap, z, stroke (px, ink, on both copies)
local function display(parent, name, x, y, w, h, text, size, faceC, extrudeC, depth, o)
	o = o or {}
	local st = o.stroke and { o.stroke, C.Ink } or nil
	local font = o.font or F.display
	local ex = label(parent, name .. "Extrude", x + depth, y + depth, w, h, text, size, extrudeC, { font = font, ax = o.ax, ay = o.ay, wrap = o.wrap, z = o.z, stroke = st })
	local fc = label(parent, name, x, y, w, h, text, size, faceC, { font = font, ax = o.ax, ay = o.ay, wrap = o.wrap, z = o.z, stroke = st })
	return fc, ex
end
-- a slab button's word. primary = QUEUE's: cream over an ink extrude, ink stroke. Else SOLO TEST's: Text over Extrude.
local function buttonWord(face, fw, fh, text, size, primary, dy)
	local depth = size >= 50 and 5 or 4
	if primary then
		return display(face, "Word", 0, dy or 4, fw, fh - 6, text, size, C.CreamText, C.Ink, depth, { ax = "C", stroke = size >= 50 and 3 or 2, z = 3 })
	end
	return display(face, "Word", 0, dy or 4, fw, fh - 6, text, size, C.Text, C.Extrude, depth - 1, { ax = "C", z = 3 })
end
-- CHIP: a thin-bordered label box, no shadow. Mono by default. Returns chip, width.
local function chipW(text, size, fe) return (fe and textW(text, size, fe) or monoW(text, size)) + 24 end
local function chip(parent, name, x, y, text, size, faceC, inkC, o)
	o = o or {}
	local w, h = o.w or chipW(text, size, o.fe), o.h or (size + 14)
	local c = frame(parent, name, x, y, w, h, faceC, { r = CHIP_R, z = o.z, stroke = { CHIP_B, C.Ink } })
	label(c, "Word", 0, o.dy or 0, w, h, text, size, inkC, { font = o.font or F.mono, ax = "C", z = o.z })
	return c, w
end
-- ZIGZAG STICKER (Quick Play's NOW LIVE!): a tilted strip with teeth along both long edges and pointed ends, drawn
-- twice (ink, then the colour on top). ROTATED, root and teeth: a rotated GuiObject escapes every clip, so NEVER inside
-- the Catalog scroller. cx, cy = its centre.
local function sticker(parent, name, cx, cy, w, text, o)
	o = o or {}
	local h, tooth, size = o.h or 46, o.tooth or 20, o.size or 30
	local root = frame(parent, name, math.floor(cx - w / 2), math.floor(cy - h / 2), w, h, nil, { z = o.z })
	root.Rotation = o.rot or -9
	local count = math.max(1, math.floor(w / tooth))
	for pass, spec in ipairs({ { C.Ink, 6, "Rim" }, { o.colour or C.Red, 0, "Fill" } }) do
		local g = spec[2]
		local function square(x, y, s)
			local d = s + g * 1.4
			local f = frame(root, spec[3] .. "Tooth", 0, 0, d, d, spec[1], { z = pass })
			f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromOffset(x, y); f.Rotation = 45
		end
		frame(root, spec[3], -g, -g, w + g * 2, h + g * 2, spec[1], { z = pass })
		for i = 0, count do
			square(i / count * w, 0, tooth * 0.62)
			square(i / count * w, h, tooth * 0.62)
		end
		square(0, h / 2, h * 0.72)
		square(w, h / 2, h * 0.72)
	end
	label(root, "Word", 0, 3, w, h, text, size, C.CreamText, { font = F.display, ax = "C", z = 3, stroke = { 3, C.Ink } })
	return root
end

-- ---------------------------------------------------------------- currency icons
local ROBUX_IMG = "rbxasset://textures/ui/common/robux@3x.png"
local SPARKS = { main = hex("E91E8C"), light = hex("FFB0DA"), deep = hex("A80E64") }
local function robuxIcon(parent, x, y, s, color, z)
	local i = Instance.new("ImageLabel"); i.Name = "RobuxIcon"; i.BackgroundTransparency = 1; i.Image = ROBUX_IMG
	i.ImageColor3 = color or C.Text; i.Position = UDim2.fromOffset(x, y); i.Size = UDim2.fromOffset(s, s)
	if z then i.ZIndex = z end; i.Parent = parent; return i
end
-- sparksIcon: the Sparks mark, a magenta four-arm sparkle plus a satellite dot (2026-10-02). NO Rotation anywhere, so
-- it is safe inside ScrollingFrames. Two cuts of the same mark:
--   flat = nil   the SHOP chip's (K.shopChip, kept as it is): each arm fades to its tip through a UIGradient
--   flat = true  the shop's own (v4: the kit has no UIGradient): each arm steps down from root to tip, hard-edged
local TO_TIP = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.1), NumberSequenceKeypoint.new(1, 1) })
local function sparksIcon(parent, x, y, s, z, flat)
	local b = frame(parent, "SparksIcon", x, y, s, s, SPARKS.main, { transp = 1, z = z })
	b:SetAttribute("Currency", "Sparks")
	local cx, cy = s * 0.44, s * 0.5
	local function arm(name, dir, len, th, fade)
		th = math.max(2, math.floor(th + 0.5)); len = math.max(2, math.floor(len + 0.5))
		local ax, ay, w, h, rot
		if dir == "U" then ax, ay, w, h, rot = cx - th / 2, cy - len, th, len, 270
		elseif dir == "D" then ax, ay, w, h, rot = cx - th / 2, cy, th, len, 90
		elseif dir == "L" then ax, ay, w, h, rot = cx - len, cy - th / 2, len, th, 180
		else ax, ay, w, h, rot = cx, cy - th / 2, len, th, 0 end
		local a = frame(b, name, math.floor(ax + 0.5), math.floor(ay + 0.5), w, h, SPARKS.main, { r = math.max(1, th // 2), z = z })
		if fade then local g = Instance.new("UIGradient"); g.Rotation = rot; g.Transparency = TO_TIP; g.Parent = a end
	end
	local lv, lh = s * 0.5, s * 0.34
	for _, d in ipairs({ "U", "D", "L", "R" }) do
		local long = (d == "U" or d == "D") and lv or lh
		if flat then -- five steps, tip to root: fine enough to read as a taper, not as a plus sign
			for i, st in ipairs({ { 1, 0.045 }, { 0.78, 0.085 }, { 0.58, 0.13 }, { 0.4, 0.18 }, { 0.24, 0.24 } }) do
				arm("Arm" .. d .. i, d, long * st[1], s * st[2])
			end
		else
			arm("Arm" .. d, d, long, s * 0.12, true)         -- the long thin spike
			arm("Root" .. d, d, long * 0.5, s * 0.24, true)  -- the thick root that makes it taper
		end
	end
	local core = math.max(4, math.floor(s * 0.26))
	frame(b, "Core", math.floor(cx - core / 2 + 0.5), math.floor(cy - core / 2 + 0.5), core, core, SPARKS.main, { r = core // 2, z = z })
	if s >= 36 then
		local hi = math.max(3, math.floor(s * 0.1))
		frame(b, "Glint", math.floor(cx - hi / 2 + 0.5), math.floor(cy - hi / 2 + 0.5), hi, hi, SPARKS.light, { r = hi // 2, z = z })
	end
	local dot = math.max(3, math.floor(s * 0.17))
	frame(b, "Satellite", math.floor(s * 0.84 - dot / 2), math.floor(s * 0.17 - dot / 2), dot, dot, SPARKS.main, { r = dot // 2, z = z })
	return b
end
-- the currency's mark and the amount (GothamBlack); returns the x where it ends
local function price(parent, x, y, p, size, color, z)
	size = size or 30
	if p[1] == "Robux" then robuxIcon(parent, x, y + 2, size, color, z) else sparksIcon(parent, x, y + 2, size, z, true) end
	local str = fmt(p[2])
	label(parent, "Price", x + size + 8, y, textW(str, size) + 6, size + 6, str, size, color, { z = z })
	return x + size + 8 + textW(str, size) + 6
end

-- ---------------------------------------------------------------- rarity + Elements (colour roles the owner approved)
-- onInk: text laid over the flat rarity colour is Ink (the light colours) rather than CreamText
local RARITY = {
	Common   = { word = "COMMON",   c = hex("8A94A6"), onInk = false, order = 5 },
	Rare     = { word = "RARE",     c = hex("2F8CFF"), onInk = false, order = 4 },
	Epic     = { word = "EPIC",     c = hex("9B4DFF"), onInk = false, order = 3 },
	Mythic   = { word = "MYTHIC",   c = hex("FF9E1F"), onInk = true,  order = 1 },
	Seasonal = { word = "SEASONAL", c = hex("17C3A3"), onInk = true,  order = 2 },
}
local RARITY_ORDER = { "Mythic", "Seasonal", "Epic", "Rare", "Common" }
-- the rarity colour as TEXT on an ink chip (a touch lighter, so Rare and Epic keep their contrast)
local function rarityInk(Rr) return Rr.c:Lerp(C.White, 0.15) end
-- THE rarity mark everywhere: a small ink chip, the word in the rarity colour (the colour never appears without it)
local function rarityChip(parent, x, y, rarity, size, z)
	local Rr = RARITY[rarity]
	local c, w = chip(parent, "RarityChip", x, y, Rr.word, size or 22, C.Ink, rarityInk(Rr), { z = z })
	c:SetAttribute("Rarity", rarity)
	return c, w
end
local ELEMENTS = { "Pyro", "Cryo", "Voltaic", "Terra", "Zephyr", "Aqua", "Umbra", "Radiant", "Toxin" }
local EL = {
	Pyro    = { base = rgb({242, 92, 13}),  light = rgb({255, 199, 77}),  dark = rgb({107, 23, 8}),   logo = "rbxassetid://130389704231772" },
	Cryo    = { base = rgb({64, 181, 240}), light = rgb({222, 247, 255}), dark = rgb({13, 79, 168}),  logo = "rbxassetid://114087404434526" },
	Voltaic = { base = rgb({245, 199, 15}), light = rgb({255, 245, 115}), dark = rgb({74, 26, 140}),  logo = "rbxassetid://93665291516779" },
	Terra   = { base = rgb({130, 107, 36}), light = rgb({204, 186, 92}),  dark = rgb({51, 33, 13}),   logo = "rbxassetid://82316909276985" },
	Zephyr  = { base = rgb({79, 209, 197}), light = rgb({255, 255, 255}), dark = rgb({18, 92, 89}),   logo = "rbxassetid://88913973979961" },
	Aqua    = { base = rgb({38, 140, 176}), light = rgb({60, 232, 224}),  dark = rgb({14, 58, 80}),   logo = nil },
	Umbra   = { base = rgb({79, 33, 145}),  light = rgb({181, 140, 240}), dark = rgb({13, 8, 23}),    logo = "rbxassetid://102056654131849" },
	Radiant = { base = rgb({245, 194, 48}), light = rgb({255, 247, 214}), dark = rgb({112, 82, 10}),  logo = "rbxassetid://94631631053912" },
	Toxin   = { base = rgb({128, 212, 33}), light = rgb({204, 245, 112}), dark = rgb({74, 26, 107}),  logo = "rbxassetid://100939666418347" },
}
-- item art is the Element's logo, straight on the face (no disc). An Element without a logo gets a square colour chip
-- with its initial.
local function elementArt(parent, x, y, s, el, z)
	if EL[el].logo then
		local i = Instance.new("ImageLabel"); i.Name = "Art"; i.BackgroundTransparency = 1; i.Image = EL[el].logo
		i.ScaleType = Enum.ScaleType.Fit; i.Position = UDim2.fromOffset(x, y); i.Size = UDim2.fromOffset(s, s)
		if z then i.ZIndex = z end; i.Parent = parent; return i
	end
	local m = math.floor(s * 0.12)
	local f = frame(parent, "Art", x + m, y + m, s - 2 * m, s - 2 * m, EL[el].base, { r = R, z = z, stroke = { math.max(3, s // 30), C.Ink } })
	label(f, "Initial", 0, math.floor(s * 0.03), s - 2 * m, s - 2 * m, el:sub(1, 1), math.floor(s * 0.5), C.CreamText, { font = F.display, ax = "C", z = z, stroke = { math.max(2, s // 60), C.Ink } })
	return f
end
-- standard sort: rarity (Mythic, Seasonal, Epic, Rare, Common), then price high to low
local function sorted(list, by)
	local t = table.clone(list)
	table.sort(t, function(a, b)
		if by == "element" and a.el ~= b.el then return table.find(ELEMENTS, a.el) < table.find(ELEMENTS, b.el) end
		if by == "price" then return a.price[2] < b.price[2] end
		if RARITY[a.rarity].order ~= RARITY[b.rarity].order then return RARITY[a.rarity].order < RARITY[b.rarity].order end
		return a.price[2] > b.price[2]
	end)
	return t
end
local function ofKind(items, kind) local t = {} for _, it in ipairs(items) do if it.kind == kind then table.insert(t, it) end end return t end

-- ---------------------------------------------------------------- themes
--- setTheme(name, fallback): case-insensitive, spaces/&/_ ignored, a 3+ letter prefix is enough ("news", "ink").
--- Fills C in place (every drawing reads it at call time). Returns the key, or nil for an unknown name; with
--- fallback = true an unknown, old (Charcoal, DuskCloister, SkyDeck, InkPaper) or missing name becomes "Newsprint".
local function setTheme(name, fallback)
	local key
	if type(name) == "string" then
		local n = (name:lower():gsub("[%s_&%-]", ""))
		for _, k in ipairs(THEME_ORDER) do
			local lk = k:lower()
			if lk == n or (#n >= 3 and lk:sub(1, #n) == n) then key = k; break end
		end
	end
	if not key and fallback then key = THEME_ORDER[1] end
	if not key then return nil end
	table.clear(C)
	for k, v in pairs(PALETTES[THEME_ORDER[1]]) do C[k] = type(v) == "table" and rgb(v) or v end
	for k, v in pairs(PALETTES[key]) do C[k] = type(v) == "table" and rgb(v) or v end
	INK, SEA = C.Ink, RARITY.Seasonal.c
	K.INK, K.SEA, K.theme = INK, SEA, key
	return key
end
setTheme(THEME_ORDER[1])

-- ---------------------------------------------------------------- the card language
-- A card Face's layers (ZIndex): ZR rest-only things, which the flat fill COVERS as it fades in (the rest name, the
-- rest patch); ZFX HoverFX (Fill, lit Patch, lit text); ZART the art; ZTXT pills and chips; ZTOP stickers, buttons.
local function hoverFX(face, fw, fh, fill)
	local fx = frame(face, "HoverFX", 0, 0, fw, fh, nil, { z = ZFX })
	fx.Visible = false
	frame(fx, "Fill", 0, 0, fw, fh, fill, { r = R, z = 1 })
	return fx
end
-- TEXT THAT CHANGES WITH THE CARD: the rest copy on the Face at ZR, the lit copy inside HoverFX over the fill. Both
-- palettes build both copies (copyLook pairs the two trees child by child). o: font, ax, ay, wrap, litStroke
local function swapText(face, fx, name, x, y, w, h, text, size, restC, litC, o)
	o = o or {}
	local a = label(face, name, x, y, w, h, text, size, restC, { font = o.font, ax = o.ax, ay = o.ay, wrap = o.wrap, z = ZR })
	local b = label(fx, name, x, y, w, h, text, size, litC, { font = o.font, ax = o.ax, ay = o.ay, wrap = o.wrap, z = 3, stroke = o.litStroke and { o.litStroke, C.Ink } or nil })
	return a, b
end
-- a card's NAME. At rest: Text over the palette's Extrude (SOLO TEST's cut). Lit, on a dark fill: cream over an ink
-- extrude with an ink stroke (DUEL's cut); on a light fill (onInk): ink over the fill's own shade (CONVERGENCE's cut).
local function title(face, fx, name, x, y, w, h, text, size, depth, fill, onInk, o)
	o = o or {}
	local font = o.font or F.display
	local st = (not onInk) and (size >= 56 and 3 or 2) or nil
	if depth > 0 then
		label(face, name .. "Extrude", x + depth, y + depth, w, h, text, size, C.Extrude, { font = font, ax = o.ax, ay = o.ay, wrap = o.wrap, z = ZR })
		label(fx, name .. "Extrude", x + depth, y + depth, w, h, text, size, onInk and fill:Lerp(C.Ink, 0.28) or C.Ink, { font = font, ax = o.ax, ay = o.ay, wrap = o.wrap, z = 3, stroke = st and { st, C.Ink } or nil })
	end
	return swapText(face, fx, name, x, y, w, h, text, size, C.Text, onInk and C.Ink or C.CreamText, { font = font, ax = o.ax, ay = o.ay, wrap = o.wrap, litStroke = st })
end
-- the halftone PATCH behind a card's art (never a wash over the face): the palette's dots on the Face at rest, and a
-- bigger one in ink over the lit fill. Whole dots only.
local function artPatch(face, fx, ax, ay, s, fw, bottom, pitch, reach)
	local function snap(v) return math.max(pitch, math.floor(v / pitch) * pitch) end
	local x0, y0 = math.floor(ax + s * 0.44), math.floor(ay + s * 0.3)
	local y1 = math.min(bottom, math.floor(ay + s * 1.04))
	halftone(face, "Patch", x0, y0, snap(math.min(fw - 14, ax + s * (reach or 1.2)) - x0), snap(y1 - y0), "paper", 0.74, pitch, ZR)
	local lx, ly = math.floor(ax + s * 0.3), math.max(14, math.floor(ay + s * 0.1))
	halftone(fx, "Patch", lx, ly, snap(fw - 14 - lx), snap(y1 - ly), "colour", 0.78, pitch, 2)
end

-- SMOOTH HOVER. The controller fades a card's HoverFX in (0.18 s) and out (0.15 s), Quad Out, and lifts its Face off
-- the Shadow. faceCard(card) -> the Face; the first call records what the controller needs, as attributes:
--   on every HoverFX element   BaseBg / BaseImg / BaseText / BaseStroke: its built transparency (the fade's far end)
--   on the card                BaseZ; RestX, RestY (the Face's resting Position, px); LiftX, LiftY (px to add when
--                              lifted: negative = up-left); LiftScale (Face.UIScale when lifted); RestStroke and
--                              HoverStroke (the Face border's thickness)
-- The lift keeps Quick Play's read ("stands up off its shadow"): the Face grows about its centre by at most LIFT.grow
-- px a side (scale <= 1.05) and moves up-left by that growth + LIFT.px, so its bottom-right edge travels LIFT.px away
-- from the Shadow and the shadow strip WIDENS. The Shadow never moves. Idempotent.
local FADE = { BaseBg = "BackgroundTransparency", BaseImg = "ImageTransparency", BaseText = "TextTransparency", BaseStroke = "Transparency" }
local function faceCard(card)
	local face = card:FindFirstChild("Face")
	if not face then return card end
	if card:GetAttribute("LiftScale") ~= nil then return face end
	local fx = face:FindFirstChild("HoverFX")
	if fx then
		for _, x in ipairs(fx:GetDescendants()) do
			if x:IsA("GuiObject") then
				x:SetAttribute("BaseBg", x.BackgroundTransparency)
				if x:IsA("ImageLabel") or x:IsA("ImageButton") then x:SetAttribute("BaseImg", x.ImageTransparency) end
				if x:IsA("TextLabel") or x:IsA("TextButton") then x:SetAttribute("BaseText", x.TextTransparency) end
			elseif x:IsA("UIStroke") then
				x:SetAttribute("BaseStroke", x.Transparency)
			end
		end
	end
	local fw, fh = face.Size.X.Offset, face.Size.Y.Offset
	local scale = math.min(LIFT.scale, 1 + 2 * LIFT.grow / math.max(fw, fh, 1))
	local st = face:FindFirstChildOfClass("UIStroke")
	local rest = st and st.Thickness or B
	card:SetAttribute("BaseZ", card.ZIndex)
	card:SetAttribute("RestX", face.Position.X.Offset); card:SetAttribute("RestY", face.Position.Y.Offset)
	card:SetAttribute("LiftX", -math.floor(fw * (scale - 1) / 2 + LIFT.px + 0.5))
	card:SetAttribute("LiftY", -math.floor(fh * (scale - 1) / 2 + LIFT.px + 0.5))
	card:SetAttribute("RestStroke", rest)
	if card:GetAttribute("HoverStroke") == nil then card:SetAttribute("HoverStroke", rest + 2) end
	card:SetAttribute("LiftScale", scale)
	return face
end
-- the fading parts of a HoverFX: { instance, property, built value }, only those that are ever visible (< 1)
local function fadeParts(fx)
	local t = {}
	if not fx then return t end
	for _, x in ipairs(fx:GetDescendants()) do
		for a, prop in pairs(FADE) do
			local b = x:GetAttribute(a)
			if type(b) == "number" and b < 1 then table.insert(t, { x, prop, b }) end
		end
	end
	return t
end
--- poseCard(card, lit): a card in its hovered (lit = true) or rest pose AT ONCE, no tween: colours, lift, scale and
--- border. The Edit captures use it; the controller can use it to snap.
local function poseCard(card, lit)
	local face = faceCard(card)
	if face == card then return end
	lit = lit and true or false
	local fx = face:FindFirstChild("HoverFX")
	if fx then
		for _, p in ipairs(fadeParts(fx)) do p[1][p[2]] = p[3] end
		fx.Visible = lit
	end
	local sc, st = face:FindFirstChildOfClass("UIScale"), face:FindFirstChildOfClass("UIStroke")
	local rx, ry = card:GetAttribute("RestX") or 0, card:GetAttribute("RestY") or 0
	face.Position = UDim2.fromOffset(rx + (lit and card:GetAttribute("LiftX") or 0), ry + (lit and card:GetAttribute("LiftY") or 0))
	if sc then sc.Scale = lit and card:GetAttribute("LiftScale") or 1 end
	if st then st.Thickness = (lit and card:GetAttribute("HoverStroke") or card:GetAttribute("RestStroke")) or B end
	card.ZIndex = lit and 30 or (card:GetAttribute("BaseZ") or 1)
end

-- PRICE PILL: a Pill slab holding the currency's mark and the amount. pillW = the holder's width (shadow included).
local function pillW(p, size, kind) return 16 + size + 8 + textW(fmt(p[2]), size) + 6 + 14 + kind.s end
local function pricePill(parent, x, y, p, size, h, kind, z)
	kind = kind or SML
	local holder, face = slab(parent, "PricePill", x, y, pillW(p, size, kind), h, C.Pill, kind, { z = z })
	holder:SetAttribute("Currency", p[1]); holder:SetAttribute("Amount", p[2])
	price(face, 16, (h - kind.s - size - 6) // 2, p, size, C.Text)
	return holder
end
-- LuckiestGuy while it fits (down to minS); a name too long even then falls back to GothamBlack (never under
-- `floor`: 16, or 20 on the Catalog wall)
local function nameFit(str, maxW, size, minS, floor)
	local s = fitSize(str, maxW, size, minS, FE.display)
	if textW(str, s, FE.display) <= maxW then return s, F.display end
	return fitSize(str, maxW, minS + 2, floor or 16, FE.black), F.black
end

-- THE card on the Today page (the Catalog wall draws the same language bigger: wallCard). Card-cream slab at rest: the art straight on the
-- face over a halftone patch, the name, "PYRO · SKIN" in mono capitals, the price in a Pill slab, the rarity word in an
-- ink chip. Its rarity colour lives in HoverFX. big = the featured card (the only one with a tilted sticker: Today is
-- not a scroller).
local function itemCard(parent, it, x, y, w, h, big)
	local Rr = RARITY[it.rarity]
	local card, face, fw, fh = slabCard(parent, "Item_" .. it.id, x, y, w, h)
	card:SetAttribute("Rarity", it.rarity); card:SetAttribute("Element", it.el); card:SetAttribute("Kind", it.kind)
	card:SetAttribute("ItemId", it.id)
	-- Mythic's emphasis, as a kit device only: its lifted border is heavier than any other card's (no glow)
	if it.rarity == "Mythic" then card:SetAttribute("HoverStroke", B + 5) end
	local fx = hoverFX(face, fw, fh, Rr.c)
	local tall = fh >= 400
	local pad = big and 26 or (tall and 18 or 14)
	local sub = (it.el .. " · " .. it.kind):upper()
	local name = it.name:upper()
	local footTop
	if big then
		local pw = pillW(it.price, 40, MED)
		pricePill(face, fw - pad - pw, fh - pad - 84, it.price, 40, 84, MED, ZTXT)
		local mw = fw - 3 * pad - pw
		local ns = fitSize(name, mw - 10, 72, 44, FE.display)
		footTop = fh - pad - 134
		title(face, fx, "Name", pad, footTop, mw, 88, name, ns, 6, Rr.c, Rr.onInk)
		swapText(face, fx, "Sub", pad + 4, fh - pad - 40, mw, 36, sub, 26, C.Text, C.Ink, { font = F.mono })
		local sw = textW("TODAY'S PICK", 30, FE.display) + 44
		sticker(face, "Ribbon", fw - pad - sw / 2 - 6, pad + 28, sw, "TODAY'S PICK", { z = ZTOP })
	else
		local ps, ph = 30, tall and 62 or 54
		local pw = pillW(it.price, ps, SML)
		local py = fh - pad - ph
		pricePill(face, (fw - (pw - SML.s)) // 2, py, it.price, ps, ph, SML, ZTXT)
		local ny = py - 6
		if tall then
			swapText(face, fx, "Sub", pad, ny - 30, fw - 2 * pad, 30, sub, 22, C.Text, C.Ink, { font = F.mono, ax = "C" })
			ny -= 34
		end
		local ns, font = nameFit(name, fw - 2 * pad - 4, tall and 40 or 30, 22)
		footTop = ny - ns - 10
		-- the extrude is Quick Play's small-card cut: about 0.09 of the type size (34 / 3 there)
		title(face, fx, "Name", pad, footTop, fw - 2 * pad, ns + 10, name, ns, math.max(2, math.floor(ns * 0.09 + 0.5)), Rr.c, Rr.onInk, { ax = "C", font = font })
	end
	local top = pad + (big and 44 or (tall and 44 or 38))   -- the art starts under the rarity chip, never behind it
	local s = math.min(footTop - 8 - top, fw - 2 * pad - 20)
	-- the featured card's art sits left of centre (Quick Play's hero: emblem left, patch right), clear of its sticker
	local ax, ay = big and math.floor(fw * 0.36 - s / 2) or (fw - s) // 2, top + (footTop - 8 - top - s) // 2
	artPatch(face, fx, ax, ay, s, fw, footTop - 4, big and 18 or (tall and 16 or 12), big and 1.6 or 1.2)
	elementArt(face, ax, ay, s, it.el, ZART)
	local cp = (big or tall) and pad or pad - 4
	rarityChip(face, cp, cp, it.rarity, big and 30 or (tall and 26 or 24), ZTXT)
	if it.value then -- bundles sell on their VALUE tag: an UNROTATED gold chip on the top edge (the grid is a scroller)
		local vw = chipW(it.value, 22, FE.display)
		chip(face, "ValueTag", fw - pad - vw, big and pad or -16, it.value, 22, C.Gold, C.Ink, { font = F.display, fe = FE.display, dy = 2, z = ZTOP })
	end
	faceCard(card)
	return card
end

-- the Elemental Cache chest (170 x 148 at k = 1), scalable: flat blocks, ink outlines
local function chestArt(parent, x, y, k, z)
	local function p(v) return math.floor(v * k + 0.5) end
	local s1, s2 = math.max(3, math.floor(4 * math.sqrt(k) + 0.5)), math.max(2, math.floor(3 * math.sqrt(k) + 0.5))
	local g = frame(parent, "ChestArt", x, y, p(170), p(148), nil, { z = z })
	frame(g, "Lid", 0, 0, p(170), p(60), C.ChestLid, { r = math.min(R, p(6)), stroke = { s1, C.Ink } })   -- no radius above the kit's
	frame(g, "Chest", 0, p(62), p(170), p(86), C.Chest, { r = math.min(R, p(4)), stroke = { s1, C.Ink } })
	frame(g, "BandV", p(72), 0, p(26), p(148), C.Gold, { stroke = { s2, C.Ink } })
	frame(g, "BandH", 0, p(52), p(170), p(12), C.Gold, { stroke = { s2, C.Ink } })
	local lock = frame(g, "Lock", p(65), p(38), p(40), p(46), C.Gold, { r = math.min(R, p(3)), stroke = { s2, C.Ink } })
	frame(lock, "Keyhole", p(16), p(14), p(8), p(18), C.Ink, { r = p(2) })
	return g
end
-- the Season Pass ticket (64 x 46 at k = 1), scalable
local function ticketArt(parent, x, y, k, z)
	local function p(v) return math.floor(v * k + 0.5) end
	local tk = frame(parent, "Ticket", x, y, p(64), p(46), C.Gold, { r = math.min(R, p(3)), stroke = { math.max(3, math.floor(3 * math.sqrt(k) + 0.5)), C.Ink }, z = z })
	frame(tk, "Perf", p(44), p(6), math.max(3, p(3)), p(34), C.Ink, { transp = 0.45 })
	return tk
end

-- ---------------------------------------------------------------- Catalog wall (built at runtime AND by the builder)
-- Layout 1 "Wall" (the owner's pick, 2026-10-04): one vertical scroller the full page width; per group a slim red
-- banner heading (name and item count), then big cards 4 across. NOTHING in here may be rotated (a rotated GuiObject
-- escapes the scroller's clip). PAD: the scroller's side margin, room for a lifted Face (it travels about 22 px
-- up-left, plus its lifted border). HEADH + HGAP: a heading and the gap to its cards (a lifted Face rises about 29 px,
-- 32 on Mythic). HEAD: a heading's width, ending on the last column's Face edge (4 x 426 + 3 x 20 - 12 = 1752).
-- BAR: the scroll bar, inside the column of faces. TOP0: the first heading's y on the canvas.
local GRID = { COLS = 4, CW = 426, CH = 412, GX = 20, GY = 22, PAD = 36, BAR = 12, HEADH = 52, HGAP = 34, TOP0 = 10 }
GRID.HEAD = GRID.COLS * GRID.CW + (GRID.COLS - 1) * GRID.GX - S
-- a group's heading: ONE slim red banner (Bangers cream, ink dots) holding the name and the item count (a paper chip,
-- as POPULAR on Quick Play's DUEL), then an ink rule to the wall's right edge (a short row reads as a shelf)
local function sectionHeader(grid, y, key, title, count)
	local hf = frame(grid, "Section_" .. key, GRID.PAD, y, GRID.HEAD, GRID.HEADH)
	local tw = textW(title, 34, FE.banner)
	local cs = count == 1 and "1 ITEM" or (count .. " ITEMS")
	local cw = chipW(cs, 20)
	local bw = 20 + tw + 8 + 14 + cw + 12
	local _, bf = slab(hf, "Banner", 0, 0, bw + MED.s, 42 + MED.s, C.RedInk, MED)
	halftone(bf, "Halftone", 0, 0, bw, 42, "colour", 0.86, 9, 1, MED.r)
	label(bf, "Title", 20, 1, tw + 8, 42, title, 34, C.CreamText, { font = F.banner, z = 2 })
	chip(bf, "Count", 20 + tw + 8 + 14, 6, cs, 20, C.Pill, C.Text, { h = 30, z = 2 })
	local rx = bw + MED.s + 14
	frame(hf, "Rule", rx, 19, GRID.HEAD - rx, 4, C.Ink)
	hf:SetAttribute("Count", count)
	return hf
end
-- THE WALL CARD (the card language, laid out for a big card): rarity chip top-left, the art large on a halftone patch,
-- the name in LuckiestGuy with its extrude, "ELEMENT · KIND" in mono capitals bottom-left, the price Pill bottom-right.
-- A Bundle adds its VALUE chip top-right (UNROTATED: the wall is a scroller) and a line saying what it contains. Plain
-- at rest; HoverFX holds the flat rarity fill, the lit patch and the lit text; faceCard records the fades and the lift.
local function wallCard(parent, it, x, y, w, h)
	local Rr = RARITY[it.rarity]
	local card, face, fw, fh = slabCard(parent, "Item_" .. it.id, x, y, w, h)
	card:SetAttribute("Rarity", it.rarity); card:SetAttribute("Element", it.el); card:SetAttribute("Kind", it.kind)
	card:SetAttribute("ItemId", it.id)
	if it.rarity == "Mythic" then card:SetAttribute("HoverStroke", B + 5) end   -- as itemCard: no glow, a heavier lifted border
	local fx = hoverFX(face, fw, fh, Rr.c)
	local pad = 18
	-- bottom row: the kind on the left, the price Pill on the right (its face ends on the padding)
	local ps, ph = 32, 64
	local pw = pillW(it.price, ps, SML)
	local px, py = fw - pad - (pw - SML.s), fh - pad - (ph - SML.s)
	pricePill(face, px, py, it.price, ps, ph, SML, ZTXT)
	local sub = (it.el .. " · " .. it.kind):upper()
	local subW = px - 10 - (pad + 2)
	swapText(face, fx, "Sub", pad + 2, py, subW, ph - SML.s, sub, monoW(sub, 22) <= subW and 22 or 20, C.Text, C.Ink, { font = F.mono })
	local foot = py - 8
	if it.contains then -- a Bundle says what is inside, one mono line above the bottom row
		swapText(face, fx, "Contains", pad + 2, py - 34, fw - 2 * pad, 28, it.contains:upper(), 20, C.Text, C.Ink, { font = F.mono })
		foot = py - 36
	end
	-- the name: one line, left, in a fixed 50 px box so every card's rows line up
	local name = it.name:upper()
	local ns, font = nameFit(name, fw - 2 * pad - 8, 40, 26, 20)
	local ny = foot - 50
	title(face, fx, "Name", pad, ny, fw - 2 * pad, 50, name, ns, math.max(2, math.floor(ns * 0.09 + 0.5)), Rr.c, Rr.onInk, { font = font })
	-- the art: under the rarity chip (never behind it), centred, as large as the face allows
	local top = pad + 40 + 6
	local s = math.min(ny - 4 - top, fw - 2 * pad - 20)
	local ax, ay = (fw - s) // 2, top + (ny - 4 - top - s) // 2
	artPatch(face, fx, ax, ay, s, fw, ny - 2, 16, 1.2)
	elementArt(face, ax, ay, s, it.el, ZART)
	rarityChip(face, pad, pad, it.rarity, 26, ZTXT)
	if it.value then -- a gold chip, level with the rarity chip
		local vw = chipW(it.value, 24, FE.display)
		chip(face, "ValueTag", fw - pad - vw, pad, it.value, 24, C.Gold, C.Ink, { font = F.display, fe = FE.display, dy = 2, h = 40, z = ZTOP })
	end
	faceCard(card)
	return card
end
-- buildGrid(grid, items, by): by = "rarity" | "element" | "price". Destroys the old headings and cards, builds the new.
local function buildGrid(grid, items, by)
	for _, ch in ipairs(grid:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
	local groups = {}
	if by == "price" then -- Robux cheapest first, then Sparks cheapest first (950 Robux never sits next to 1,000 Sparks)
		local rob, spk = {}, {}
		for _, it in ipairs(sorted(items, "price")) do table.insert(it.price[1] == "Robux" and rob or spk, it) end
		groups = { { key = "Robux", title = "ROBUX", list = rob }, { key = "Sparks", title = "SPARKS", list = spk } }
	elseif by == "element" then -- one group per Element that has items, in config order
		local byRarity = sorted(items, "rarity")
		for _, el in ipairs(ELEMENTS) do
			local l = {}
			for _, it in ipairs(byRarity) do if it.el == el then table.insert(l, it) end end
			table.insert(groups, { key = el, title = el:upper(), list = l })
		end
	else -- rarity, best first
		local byRarity = sorted(items, "rarity")
		for _, r in ipairs(RARITY_ORDER) do
			local l = {}
			for _, it in ipairs(byRarity) do if it.rarity == r then table.insert(l, it) end end
			table.insert(groups, { key = r, title = RARITY[r].word, list = l })
		end
	end
	local y, cards, sections = GRID.TOP0, 0, 0
	for _, g in ipairs(groups) do
		if #g.list > 0 then
			sectionHeader(grid, y, g.key, g.title, #g.list)
			sections += 1
			y += GRID.HEADH + GRID.HGAP
			for i, it in ipairs(g.list) do
				wallCard(grid, it, GRID.PAD + ((i - 1) % GRID.COLS) * (GRID.CW + GRID.GX), y + ((i - 1) // GRID.COLS) * (GRID.CH + GRID.GY), GRID.CW, GRID.CH)
				cards += 1
			end
			y += math.ceil(#g.list / GRID.COLS) * (GRID.CH + GRID.GY)
		end
	end
	grid.CanvasSize = UDim2.fromOffset(0, y)
	grid.CanvasPosition = Vector2.zero
	grid:SetAttribute("Cards", cards); grid:SetAttribute("Sections", sections)
	return cards, sections
end

-- ---------------------------------------------------------------- highlights (one painter per control)
-- a segment or a sort option (the filter bar's ONE control style): a Sel block (ink; cream in the Ink palette) under
-- the chosen word. Only BackgroundTransparency and Word.TextColor3 change.
local function paintSegment(b, on)
	b.BackgroundTransparency = on and 0 or 1
	b.Word.TextColor3 = on and C.OnSel or C.Idle
end
local paintSort = paintSegment
-- a tab: Active is the red slab with the cream word (the marker)
local function paintTab(tab, on)
	local a = tab:FindFirstChild("Active"); if a then a.Visible = on end
end
-- the daily-reward strip: day `day` of 7, claimed or not
local function paintDaily(dr, day, days, claimed)
	local face = dr.Face
	for d = 1, days do
		local dot = face:FindFirstChild("Day" .. d)
		if dot then
			local now, done = d == day and not claimed, d < day or (d == day and claimed)
			dot.BackgroundColor3 = now and C.Gold or (done and C.Green or C.Track)
			dot.N.TextColor3 = (now or done) and C.Ink or C.Dim
		end
	end
	face.Sub.Text = claimed and ("DAY %d OF %d · CLAIMED!"):format(day, days) or ("DAY %d OF %d · IT'S FREE!"):format(day, days)
	local cf = dr.ClaimButton.Face
	cf.BackgroundColor3 = claimed and C.Track or C.Green
	for _, w in ipairs({ cf.Word, cf.WordExtrude }) do
		w.Text = claimed and "CLAIMED" or "CLAIM"
		w.TextSize = claimed and 32 or 46
		local st = w:FindFirstChildOfClass("UIStroke"); if st then st.Enabled = not claimed end
	end
	cf.Word.TextColor3 = claimed and C.LockedInk or C.CreamText
	cf.WordExtrude.Visible = not claimed
	dr:SetAttribute("Claimed", claimed)
end
-- seconds to the next 00:00 UTC, as "10H 51M 07S" (mono capitals)
local function countdown(now)
	local left = 86400 - (math.floor(now) % 86400)
	return ("%dH %02dM %02dS"):format(left // 3600, (left % 3600) // 60, left % 60)
end

-- ---------------------------------------------------------------- the confirm popup's sheet
-- thing = { type = "item", it = <item> } | { type = "cache", cache = CACHE } | { type = "pass", pass = PASS }
-- card = ConfirmModal.Card: a slab holder (Shadow + Face, the paper sheet with its ink head bar) with the static
-- Cancel / Buy slab buttons. Rebuilds card.Content, then sizes the sheet and moves the buttons under the content.
-- The modal is three canvases wide and tall (the ink scrim reaches the screen edges at any aspect), so the sheet sits
-- at the canvas centre plus one canvas (MODAL_X, MODAL_Y).
local CW, HEAD, MODAL_X, MODAL_Y = 800, 68, 1920, 1080
local function fillConfirm(card, t)
	local old = card:FindFirstChild("Content"); if old then old:Destroy() end
	local ct = frame(card, "Content", 0, 0, CW, 1080, nil, { z = 3 })
	local name, rarity, kind, p, q1, lines, odds
	if t.type == "cache" then
		local cache = t.cache
		name, p, q1 = cache.name, cache.price, "Buy 1 " .. cache.key .. " for"
		lines, odds = { "1 " .. cache.key .. ", opened at once for 1 random item" }, cache.odds
	elseif t.type == "pass" then
		local pass = t.pass
		name, rarity, kind, p, q1 = pass.name, "Seasonal", pass.sub, pass.price, "Buy the " .. pass.name .. " for"
		lines = { pass.unlocks }
	else
		local it = t.it
		name, rarity, kind, p, q1 = it.name, it.rarity, ("%s · %s"):format(it.el, it.kind), it.price, "Buy " .. it.name .. " for"
		if it.contains then lines = { "Contains: " .. it.contains } end
	end
	local y = HEAD + 26   -- no patch behind the art here: the sheet is one of the two all-over dot screens
	if t.type == "cache" then chestArt(ct, 400 - 111, y + 4, 1.3)
	elseif t.type == "pass" then ticketArt(ct, 400 - 109, y + 22, 3.4)
	else elementArt(ct, 300, y, 200, t.it.el) end
	y += 200 + 12
	local nm = name:upper()
	display(ct, "Name", 0, y, CW, 78, nm, fitSize(nm, CW - 80, 64, 40, FE.display), C.Text, C.Extrude, 5, { ax = "C" })
	y += 88
	if rarity then
		local ks = kind:upper()
		local cw0, kw = chipW(RARITY[rarity].word, 28), monoW(ks, 28)
		local x0 = math.floor((CW - (cw0 + 16 + kw)) / 2)
		rarityChip(ct, x0, y, rarity, 28)
		mono(ct, "Kind", x0 + cw0 + 16, y, kw, 42, ks, 28, C.Text)
		y += 60
	end
	for i, s in ipairs(lines or {}) do
		local str = s:upper()
		local rows = math.ceil(monoW(str, 26) / (CW - 48))
		mono(ct, "Line" .. i, 24, y, CW - 48, rows * 32 + 4, str, 26, C.Text, { ax = "C", wrap = true })
		y += rows * 32 + 12
	end
	if odds then -- best first: each rarity's ink chip, then its share
		local parts, total = {}, -22
		for i = #odds, 1, -1 do
			local o = odds[i]
			local cw0, pw = chipW(RARITY[o[1]].word, 20), textW(o[2] .. "%", 24) + 4
			table.insert(parts, { o, cw0, pw }); total += cw0 + 10 + pw + 22
		end
		local row = frame(ct, "Odds", math.floor((CW - total) / 2), y, total, 38)
		local x = 0
		for _, q in ipairs(parts) do
			rarityChip(row, x, 2, q[1][1], 20)
			label(row, "Pct", x + q[2] + 10, 0, q[3], 38, q[1][2] .. "%", 24, C.Text)
			x += q[2] + 10 + q[3] + 22
		end
		y += 52
	end
	y += 8
	-- "Buy <name> for (icon) 500 Robux?" -- the exact price with its currency's name, shrunk to fit one line
	local unit = p[1] .. "?"
	local qs = 34
	local function qwidth(s) return textW(q1, s) + 14 + (s + 4) + 8 + textW(fmt(p[2]), s + 4) + 6 + 6 + textW(unit, s) end
	while qs > 22 and qwidth(qs) > CW - 60 do qs -= 2 end
	local q1w = textW(q1, qs)
	local qx = math.floor((CW - qwidth(qs)) / 2)
	label(ct, "Question", qx, y, q1w + 8, 52, q1, qs, C.Text)
	local ex = price(ct, qx + q1w + 14, y + 4, p, qs + 4, C.Text)
	label(ct, "Unit", ex + 6, y, textW(unit, qs) + 8, 52, unit, qs, C.Text)
	y += 52 + 32
	local H = y + 104 + 28
	ct.Size = UDim2.fromOffset(CW, H)
	card.Size = UDim2.fromOffset(CW + S, H + S)
	card.Position = UDim2.fromOffset(MODAL_X + (1920 - CW) // 2, MODAL_Y + (1080 - H) // 2)
	card.Shadow.Size = UDim2.fromOffset(CW, H); card.Face.Size = UDim2.fromOffset(CW, H)
	card.Cancel.Position = UDim2.fromOffset(60, y)
	card.Buy.Position = UDim2.fromOffset(CW - 60 - 320, y)
	card:SetAttribute("Currency", p[1]); card:SetAttribute("Amount", p[2]); card:SetAttribute("Title", name)
	return H
end

-- ---------------------------------------------------------------- the toast: an ink slab, cream GothamBlack
local function setToast(toast, text)
	local w = textW(text, 28) + 72
	toast.Size = UDim2.fromOffset(w + MED.s, 76 + MED.s)
	toast.Position = UDim2.fromOffset(math.floor((1920 - w) / 2), 958)
	toast.Face.Word.Text = text
end

-- ---------------------------------------------------------------- the SHOP chip, in the Hub chip strip's lighter style
-- (LoadoutMenu's slab: cream face, 2 px ink outline, 3 px hard ink shadow, corner 5; chipH 44, or 52 on touch)
-- KEPT AS IT IS (it is already in the kit): always Newsprint's ink and pill, whatever palette the shop is in.
local CHIPC = { Ink = rgb(PALETTES.Newsprint.Ink), Pill = rgb(PALETTES.Newsprint.Pill) }
local function shopChip(parent, chipH)
	local LABEL_W = chipH > 44 and 66 or 58
	local holder = Instance.new("Frame")
	holder.Name = "ShopChip"; holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(1, 0)
	holder.Size = UDim2.fromOffset(chipH + LABEL_W + 3, chipH + 3); holder.ZIndex = 1
	holder:SetAttribute("ChipH", chipH)
	local sh = Instance.new("Frame")
	sh.Name = "Shadow"; sh.BackgroundColor3 = CHIPC.Ink; sh.BackgroundTransparency = 0.2; sh.BorderSizePixel = 0
	sh.Position = UDim2.fromOffset(3, 3); sh.Size = UDim2.new(1, -3, 1, -3); sh.ZIndex = 1; sh.Parent = holder
	local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 5); c1.Parent = sh
	local face = Instance.new("Frame")
	face.Name = "Face"; face.BackgroundColor3 = CHIPC.Pill; face.BorderSizePixel = 0; face.Size = UDim2.new(1, -3, 1, -3); face.ZIndex = 2
	face.Parent = holder
	local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 5); c2.Parent = face
	local st = Instance.new("UIStroke"); st.Color = CHIPC.Ink; st.Thickness = 2; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = face
	local s = math.floor(chipH * 0.7)
	local icon = sparksIcon(face, math.floor((chipH - s) / 2) + 2, math.floor((chipH - s) / 2), s, 3)
	icon.Name = "Icon"
	local t = Instance.new("TextLabel")
	t.Name = "Label"; t.BackgroundTransparency = 1; t.Font = Enum.Font.Bangers; t.Text = "SHOP"; t.TextSize = chipH > 44 and 27 or 24
	t.TextColor3 = CHIPC.Ink; t.TextXAlignment = Enum.TextXAlignment.Left
	t.Position = UDim2.fromOffset(chipH - 4, 1); t.Size = UDim2.new(1, -(chipH - 4), 1, 0); t.ZIndex = 3; t.Parent = face
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"; hit.Text = ""; hit.AutoButtonColor = false; hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1); hit.ZIndex = 8; hit.Parent = face
	holder.Parent = parent
	return holder
end

-- ---------------------------------------------------------------- runtime theme switch: copy a fresh build's LOOK
-- copyLook(src, dst): src is a fresh buildDesign() in the new palette, dst the live one (same code, so the same tree).
-- Children pair by Name + ClassName + occurrence. Copied: colours (fills, text, images, strokes), stroke thickness,
-- corner radii, the HoverFX Base* attributes, and every background/stroke transparency EXCEPT under Tabs (the
-- controller fades those). Not entered: Grid and Content (rebuilt by the controller). Nodes only the live tree has
-- (Glider, PopScale, PressScale) are left alone. The two palettes differ in colour only, so nothing else moves.
local SKIP_KIDS = { Grid = true, Content = true }
local BASES = { "BaseBg", "BaseImg", "BaseText", "BaseStroke" }
local function copyLook(src, dst, inTabs)
	if src:IsA("GuiObject") then
		dst.BackgroundColor3 = src.BackgroundColor3
		if not inTabs then dst.BackgroundTransparency = src.BackgroundTransparency end
		if src:IsA("TextLabel") or src:IsA("TextButton") then dst.TextColor3 = src.TextColor3
		elseif src:IsA("ImageLabel") or src:IsA("ImageButton") then dst.ImageColor3 = src.ImageColor3
		elseif src:IsA("ScrollingFrame") then dst.ScrollBarImageColor3 = src.ScrollBarImageColor3 end
	elseif src:IsA("UIStroke") then
		dst.Color = src.Color; dst.Thickness = src.Thickness
		if not inTabs then dst.Transparency = src.Transparency end
	elseif src:IsA("UICorner") then
		dst.CornerRadius = src.CornerRadius
	end
	for _, a in ipairs(BASES) do
		local v = src:GetAttribute(a)
		if v ~= nil then dst:SetAttribute(a, v) end
	end
	if SKIP_KIDS[src.Name] then return end
	local pool, seen = {}, {}
	for _, c in ipairs(dst:GetChildren()) do
		local k = c.Name .. "|" .. c.ClassName
		pool[k] = pool[k] or {}
		table.insert(pool[k], c)
	end
	local tabsHere = src.Name == "Tabs" -- its tab buttons are the controller's to fade; its own slab is not
	for _, c in ipairs(src:GetChildren()) do
		local k = c.Name .. "|" .. c.ClassName
		seen[k] = (seen[k] or 0) + 1
		local d = pool[k] and pool[k][seen[k]]
		if d then copyLook(c, d, inTabs or (tabsHere and c:IsA("GuiButton"))) end
	end
end

-- ---------------------------------------------------------------- exports
K.F, K.FE, K.rgb, K.hex, K.frame, K.tbutton, K.label, K.mono, K.textW, K.monoW, K.fmt, K.fitSize = F, FE, rgb, hex, frame, tbutton, label, mono, textW, monoW, fmt, fitSize
K.corner, K.outline, K.halftone, K.slab, K.slabCard, K.display, K.buttonWord, K.chip, K.chipW, K.sticker = corner, outline, halftone, slab, slabCard, display, buttonWord, chip, chipW, sticker
K.ROBUX_IMG, K.SPARKS, K.robuxIcon, K.sparksIcon, K.price = ROBUX_IMG, SPARKS, robuxIcon, sparksIcon, price
K.RARITY, K.RARITY_ORDER, K.rarityInk, K.rarityChip, K.ELEMENTS, K.EL, K.elementArt, K.sorted, K.ofKind = RARITY, RARITY_ORDER, rarityInk, rarityChip, ELEMENTS, EL, elementArt, sorted, ofKind
K.C, K.KIT = C, { BIG = BIG, MED = MED, SML = SML, SHADOW = S, BORDER = B, RADIUS = R, LIFT = LIFT, DOT = DOT }
K.hoverFX, K.swapText, K.title, K.artPatch, K.faceCard, K.fadeParts, K.poseCard = hoverFX, swapText, title, artPatch, faceCard, fadeParts, poseCard
K.pillW, K.pricePill, K.itemCard, K.wallCard, K.chestArt, K.ticketArt, K.GRID, K.sectionHeader, K.buildGrid = pillW, pricePill, itemCard, wallCard, chestArt, ticketArt, GRID, sectionHeader, buildGrid
K.paintSegment, K.paintSort, K.paintTab, K.paintDaily, K.countdown = paintSegment, paintSort, paintTab, paintDaily, countdown
K.fillConfirm, K.setToast, K.shopChip = fillConfirm, setToast, shopChip
K.PALETTES, K.THEMES, K.THEME_ORDER, K.setTheme, K.copyLook = PALETTES, PALETTES, THEME_ORDER, setTheme, copyLook

-- ---------------------------------------------------------------- the whole canvas
-- K.buildDesign(Cat) -> the Backdrop Frame, UNPARENTED, drawn in the ACTIVE palette (setTheme first). The Edit builder
-- parents it to the gui; ShopController builds a throwaway one in a new palette and copyLook()s it onto the live one.
-- Backdrop = the paper and its dots, edge to edge at any aspect (the dots are NOT under the fit scale: 12 real px, as
-- Quick Play's). Design = the 1920 x 1080 canvas under the Fit UIScale. LEFT..FACE_R = the faces' column, 60..1848.
function K.buildDesign(Cat)
	local ITEMS, BYID, DAILY, CACHE, PASS, BAL = Cat.ITEMS, Cat.BYID, Cat.DAILY, Cat.CACHE, Cat.PASS, Cat.BAL
	local LEFT, FACE_R, TOP = 60, 1848, 254   -- TOP: where a page's content starts: 30 px under the tab strip's shadow, so a
	-- card at the top of a page can lift (its Face rises about 29) without touching the strip
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"; backdrop.Size = UDim2.fromScale(1, 1); backdrop.BorderSizePixel = 0
	backdrop.BackgroundColor3 = C.Paper
	backdrop:SetAttribute("Theme", K.theme)   -- the palette this canvas is drawn in (ShopController re-themes a mismatch)
	local dots = halftone(backdrop, "Dots", 0, 0, 0, 0, "paper", 0.84, 12, 1)
	dots.Size = UDim2.fromScale(1, 1)
	local D = Instance.new("Frame")
	D.Name = "Design"; D.AnchorPoint = Vector2.new(0.5, 0.5); D.Position = UDim2.fromScale(0.5, 0.5)
	D.Size = UDim2.fromOffset(1920, 1080); D.BorderSizePixel = 0; D.BackgroundTransparency = 1; D.ZIndex = 2
	D.Parent = backdrop
	local fit = Instance.new("UIScale"); fit.Name = "Fit"; fit.Parent = D

	-- a red banner heading (Settings' DISPLAY / EFFECTS, Loadout's ELEMENT): RedInk slab, ink dots, Bangers cream
	local function bannerHeading(parent, name, x, y, w, text)
		local holder, face, fw = slab(parent, name, x, y, w, 60 + MED.s, C.RedInk, MED)
		halftone(face, "Halftone", 0, 0, fw, 60, "colour", 0.86, 11, 1, MED.r)
		label(face, "Word", 22, 2, fw - 44, 60, text, 46, C.CreamText, { font = F.banner, z = 2 })
		return holder, face
	end
	-- a green primary button (QUEUE, in green): Green slab, ink dots, LuckiestGuy cream over an ink extrude
	local function greenButton(parent, name, x, y, w, h, text, size, z)
		local b, face, fw, fh = slab(parent, name, x, y, w, h, C.Green, BIG, { button = true, z = z })
		halftone(face, "Halftone", 0, 0, fw, fh, "colour", 0.88, 12, 1, R)
		buttonWord(face, fw, fh, text, size, true)
		return b, face, fw, fh
	end

	-- ================================================================ TODAY
	local today = frame(D, "PageToday", 0, 0, 1920, 1080)
	do -- the page heading: a red banner, and the countdown in a paper box (mono capitals)
		local lead = "NEW ITEMS IN"
		local w1, w2 = monoW(lead, 22), monoW("23H 59M 59S", 28)
		local cw = 22 + w1 + 16 + w2 + 22
		local cd, cf = slab(today, "Countdown", FACE_R - cw, TOP, cw + MED.s, 60 + MED.s, C.Pill, MED)
		cd:SetAttribute("CountsTo", "00:00 UTC")
		mono(cf, "Lead", 22, 0, w1, 60, lead, 22, C.Dim)
		mono(cd, "Time", 22 + w1 + 16, 0, w2, 60, K.countdown(os.time()), 28, C.Text, { z = 3 })
		bannerHeading(today, "Header", LEFT, TOP, FACE_R - cw - 22 - LEFT, "TODAY'S DROP")
	end
	do -- the featured pick and 3 more
		local cw, gap, y, h = 336, 30, TOP + 100, 540   -- 32 px under the heading: a lifted Face rises about 29
		itemCard(today, BYID[DAILY.ids[1]], LEFT, y, 2 * cw + gap, h, true)
		for i = 2, 4 do itemCard(today, BYID[DAILY.ids[i]], LEFT + 2 * cw + 2 * gap + (i - 2) * (cw + gap), y, cw, h) end
	end
	do -- the daily reward (login streak) and the pass
		local dr, df, fw, fh = slab(today, "DailyReward", LEFT, TOP + 668, 1120, 132, C.Card)
		dr:SetAttribute("Day", DAILY.day); dr:SetAttribute("Days", DAILY.days)
		local gift = frame(df, "Gift", 24, 24, 72, 72, C.RedInk, { r = MED.r, stroke = { 4, C.Ink } })
		frame(gift, "RibbonV", 29, 0, 14, 72, C.Gold)
		frame(gift, "RibbonH", 0, 24, 72, 14, C.Gold)
		label(df, "Title", 118, 16, 340, 50, "DAILY REWARD", 38, C.Text, { font = F.display })
		mono(df, "Sub", 120, 70, 340, 30, "", 22, C.Dim)
		for d = 1, DAILY.days do
			local s = d == DAILY.day and 50 or 46   -- 50 on the 58 pitch: its border stays 4 clear of its neighbours'
			local dot = frame(df, "Day" .. d, 474 + (d - 1) * 58 + (56 - s) // 2, (fh - s) // 2, s, s, C.Track, { r = CHIP_R, stroke = { CHIP_B, C.Ink } })
			label(dot, "N", 0, 0, s, s, tostring(d), d == DAILY.day and 30 or 26, C.Dim, { ax = "C" })
		end
		greenButton(dr, "ClaimButton", fw - 16 - 196, 16, 196, 88, "CLAIM", 46, 3)   -- 16 clear of the row's edges, shadow included
		K.paintDaily(dr, DAILY.day, DAILY.days, false)

		local pass, pf, pw, ph = slabCard(today, "PassCard", 1204, TOP + 668, 656, 132)
		pass:SetAttribute("Kind", "Pass"); pass:SetAttribute("Level", PASS.level); pass:SetAttribute("Levels", PASS.levels)
		local fx = hoverFX(pf, pw, ph, SEA)
		halftone(fx, "Patch", 12, 12, 112, 96, "colour", 0.78, 16, 2)   -- lit only: a row card carries no patch at rest
		K.ticketArt(pf, 22, 30, 1.3, ZART)
		swapText(pf, fx, "Title", 124, 14, 330, 50, "SEASON PASS", 36, C.Text, C.Ink, { font = F.display })
		swapText(pf, fx, "Level", 126, 68, 120, 36, ("LV %d/%d"):format(PASS.level, PASS.levels), 26, C.Text, C.Ink)
		local bar = frame(pf, "Bar", 254, 78, 170, 16, C.Track, { r = CHIP_R, stroke = { CHIP_B, C.Ink }, z = ZTXT })
		frame(bar, "Fill", 0, 0, math.floor(170 * PASS.level / PASS.levels), 16, C.Gold, { r = CHIP_R })
		pricePill(pf, pw - 20 - pillW(PASS.price, 30, MED), 24, PASS.price, 30, 72, MED, ZTXT)
		K.faceCard(pass)
	end

	-- ================================================================ CATALOG: layout 1 "Wall" (the owner's pick, 2026-10-04)
	local cat = frame(D, "PageCatalog", 0, 0, 1920, 1080)
	do
		-- THE FILTER BAR: one paper slab the column's width. Segments on the left, SORT BY and its three choices on the
		-- right, both in ONE control style (paintSegment / paintSort): the chosen one is a Sel block, its word in OnSel.
		local bw = FACE_R - LEFT
		local bar = slab(cat, "FilterBar", LEFT, TOP, bw + MED.s, 72 + MED.s, C.Pill, MED)
		local SEGW, SORTW, GAP = 220, 196, 6
		local function option(parent, name, x, w, word)
			local b = tbutton(parent, name, x, 8, w, 56, C.Sel, { r = CHIP_R, transp = 1 })
			label(b, "Word", 0, 0, w, 56, word, 26, C.Idle, { ax = "C" })
			return b
		end
		local seg = frame(bar, "Segments", 0, 0, 16 + 3 * SEGW + 2 * GAP, 72, nil, { z = 3 })
		seg:SetAttribute("Selected", "Skin")
		for i, k in ipairs({ { "Skins", "Skin" }, { "Tints", "Tint" }, { "Bundles", "Bundle" } }) do
			local b = option(seg, "Seg_" .. k[1], 8 + (i - 1) * (SEGW + GAP), SEGW, k[1]:upper())
			b:SetAttribute("Kind", k[2])
			K.paintSegment(b, k[2] == "Skin")
		end
		local lw = monoW("SORT BY", 26)
		local ow = 3 * SORTW + 2 * GAP
		local sw = lw + 18 + ow
		local sc = frame(bar, "SortControl", bw - 8 - sw, 0, sw, 72, nil, { z = 3 })
		sc:SetAttribute("Selected", "Rarity")
		mono(sc, "Label", 0, 0, lw, 72, "SORT BY", 26, C.Text)
		local opts = frame(sc, "Options", lw + 18, 0, ow, 72)
		for i, k in ipairs({ "Rarity", "Element", "Price" }) do
			K.paintSort(option(opts, "Sort_" .. k, (i - 1) * (SORTW + GAP), SORTW, k:upper()), k == "Rarity")
		end
		frame(bar, "Divider", bw - 8 - sw - 26, 14, 4, 44, C.Ink, { z = 3 })   -- one ink rule parts the two controls
		-- THE WALL: one scroller the page's width. Its side margin starts GRID.PAD left of the column of faces; its bar
		-- (flat opaque ink, square ends: the default images are translucent and round-ended) ends on FACE_R.
		local grid = Instance.new("ScrollingFrame")
		grid.Name = "Grid"; grid.Position = UDim2.fromOffset(LEFT - GRID.PAD, TOP + 92)
		grid.Size = UDim2.fromOffset(FACE_R - (LEFT - GRID.PAD), 704)
		grid.BackgroundTransparency = 1; grid.BorderSizePixel = 0; grid.ScrollBarThickness = GRID.BAR
		grid.TopImage = FLAT; grid.MidImage = FLAT; grid.BottomImage = FLAT
		grid.ScrollBarImageColor3 = C.Ink; grid.ScrollBarImageTransparency = 0
		grid.ScrollingDirection = Enum.ScrollingDirection.Y; grid.Parent = cat
		-- the folds: a card the scroller cuts ends on an ink rule, never on open paper. The bottom one always; the top one
		-- only while the wall is scrolled (the controller: TopFold.Visible = Grid.CanvasPosition.Y > 0)
		frame(cat, "Fold", LEFT, TOP + 796, bw, 4, C.Ink)
		frame(cat, "TopFold", LEFT, TOP + 88, bw, 4, C.Ink).Visible = false
		K.buildGrid(grid, K.ofKind(ITEMS, "Skin"), "rarity")   -- the controller rebuilds it from Catalog on every change
	end

	-- ================================================================ CACHES: the Cache, big, and its odds as a table
	local caches = frame(D, "PageCaches", 0, 0, 1920, 1080)
	do
		local hero, hf, fw, fh = slabCard(caches, "CacheHero", LEFT, TOP, 820, 800)
		hero:SetAttribute("Kind", "Cache")
		local fx = hoverFX(hf, fw, fh, C.Cache)
		title(hf, fx, "Title", 0, 30, fw, 92, "ELEMENTAL CACHE", 76, 6, C.Cache, false, { ax = "C" })
		swapText(hf, fx, "Sub", 0, 132, fw, 40, CACHE.contents:upper(), 28, C.Dim, C.CreamText, { font = F.mono, ax = "C" })
		halftone(hf, "Patch", 404, 314, 288, 252, "paper", 0.8, 18, ZR)
		halftone(fx, "Patch", 332, 224, 414, 342, "colour", 0.78, 18, 2)
		K.chestArt(hf, 404 - 204, 198, 2.4, ZART)
		local a, b = fmt(CACHE.price[2]) .. " ROBUX", "PER " .. CACHE.key:upper()
		local aw, bw = textW(a, 38), monoW(b, 24)
		local plw = 20 + 40 + 10 + aw + 16 + bw + 20
		local pl, plf = slab(hf, "PriceLine", (fw - plw) // 2, 574, plw + MED.s, 68 + MED.s, C.Pill, MED, { z = ZTXT })
		pl:SetAttribute("Currency", CACHE.price[1]); pl:SetAttribute("Amount", CACHE.price[2])
		robuxIcon(plf, 20, 14, 40, C.Text)
		label(plf, "Amount", 70, 0, aw + 6, 68, a, 38, C.Text)
		mono(plf, "Per", 70 + aw + 16, 2, bw, 68, b, 24, C.Dim)
		greenButton(hf, "OpenButton", (fw - 400) // 2, 668, 412, 104, "OPEN", 62, ZTOP)
		K.faceCard(hero)

		local op, of, ow = slab(caches, "OddsPanel", 904, TOP, 956, 800, C.Card)
		bannerHeading(of, "Title", 28, 28, ow - 56 + MED.s, "DROP ODDS")
		mono(of, "Hint", 32, 108, ow - 64, 40, ("WHAT 1 %s CAN GIVE YOU"):format(CACHE.key:upper()), 24, C.Dim)
		local tbl = frame(of, "OddsTable", 28, 164, ow - 56 + MED.s, 500)
		for i = #CACHE.odds, 1, -1 do
			local o = CACHE.odds[i]; local Rr = RARITY[o[1]]
			local row, rf, rw = slab(tbl, "Odds_" .. o[1], 0, (#CACHE.odds - i) * 128, ow - 56 + MED.s, 104 + MED.s, C.Pill, MED)
			row:SetAttribute("Rarity", o[1]); row:SetAttribute("Percent", o[2])
			rarityChip(rf, 24, 30, o[1], 30)
			local track = frame(rf, "Track", 252, 38, 440, 28, C.Track, { r = CHIP_R, stroke = { CHIP_B, C.Ink } })
			frame(track, "Fill", 0, 0, math.max(20, math.floor(440 * o[2] / 100)), 28, Rr.c, { r = CHIP_R })
			label(rf, "Pct", rw - 24 - 170, 0, 170, 104, o[2] .. "%", 52, C.Text, { ax = "R" })
		end
		mono(of, "Note", 32, 700, ow - 64, 40, "MYTHIC ITEMS ALSO SELL DIRECTLY IN THE CATALOG.", 22, C.Dim)
	end

	-- ================================================================ PASS: the pass, then the next tiers
	local passPg = frame(D, "PagePass", 0, 0, 1920, 1080)
	local function trackMark(parent, x, y, w, h, track)
		local prem = track == "Premium"
		local m = frame(parent, "Mark_" .. track, x, y, w, h, prem and C.Gold or C.Green, { r = CHIP_R, stroke = { CHIP_B, C.Ink } })
		m:SetAttribute("Track", track)
		local word = prem and "PREMIUM" or "FREE"
		local ww = textW(word, 24)
		local lx = math.floor((w - ww - (prem and 28 or 0)) / 2)
		if prem then -- a small padlock: premium needs the pass
			local cy = math.floor(h / 2)
			frame(m, "Shackle", lx + 3, cy - 13, 14, 14, nil, { r = 4, stroke = { 3, C.Ink } })
			frame(m, "Lock", lx, cy - 4, 20, 15, C.Ink, { r = 2, z = 2 })
			lx += 28
		end
		label(m, "Word", lx, 0, ww + 6, h, word, 24, C.Ink, { z = 2 })
		return m
	end
	do
		local pp, pf, fw = slab(passPg, "PassPanel", LEFT, TOP, 1800, 322, C.Card)
		pp:SetAttribute("Level", PASS.level); pp:SetAttribute("Levels", PASS.levels)
		halftone(pf, "Patch", 232, 102, 90, 126, "paper", 0.8, 18)   -- three whole columns clear of the ticket, none under it
		K.ticketArt(pf, 64, 90, 3)
		display(pf, "Title", 320, 20, 900, 98, "SEASON PASS", 84, C.Text, C.Extrude, 6)
		mono(pf, "Sub", 324, 126, 900, 40, PASS.sub:upper(), 26, C.Dim)
		label(pf, "Level", 324, 180, 600, 50, ("LEVEL %d / %d"):format(PASS.level, PASS.levels), 36, C.Text)
		local bar = frame(pf, "Bar", 326, 248, 800, 30, C.Track, { r = CHIP_R, stroke = { MED.b, C.Ink } })
		frame(bar, "Fill", 0, 0, math.floor(800 * PASS.level / PASS.levels), 30, C.Gold, { r = CHIP_R })
		local gb, gf = slab(pp, "GetPassButton", fw - 44 - 420, 58, 432, 202, C.Green, BIG, { button = true, z = 3 })
		halftone(gf, "Halftone", 0, 0, 420, 190, "colour", 0.88, 12, 1, R)
		buttonWord(gf, 420, 104, "GET PASS", 62, true, 16)
		local pstr = fmt(PASS.price[2]) .. " ROBUX"
		local pw = 40 + 10 + textW(pstr, 36)
		local pr = frame(gf, "PriceRow", math.floor((420 - pw) / 2), 118, pw + 6, 52, nil, { z = 3 })
		pr:SetAttribute("Currency", PASS.price[1]); pr:SetAttribute("Amount", PASS.price[2])
		robuxIcon(pr, 0, 6, 40, C.Ink)
		label(pr, "Amount", 50, 0, textW(pstr, 36) + 6, 52, pstr, 36, C.Ink)

		local tz = frame(passPg, "Tiers", LEFT, TOP + 346, 1800, 454)
		local lg = frame(tz, "Legend", 1788 - 640, 12, 640, 44)
		trackMark(lg, 3, 2, 96, 40, "Free")
		mono(lg, "FreeText", 112, 0, 160, 44, "FOR EVERYONE", 20, C.Text)
		trackMark(lg, 286, 2, 180, 40, "Premium")
		mono(lg, "PremiumText", 480, 0, 160, 44, "WITH THE PASS", 20, C.Text)
		bannerHeading(tz, "Title", 0, 0, 1788 - 640 - 24 + MED.s, "NEXT REWARDS")
		for i, t in ipairs(PASS.tiers) do
			local card, face, cw = slab(tz, "Tier_" .. t.lv, (i - 1) * 304, 90, 280, 364, C.Card)   -- 13+ px under the heading's shadow
			card:SetAttribute("Level", t.lv); card:SetAttribute("Track", t.track); card:SetAttribute("Reward", t.kind)
			local lv = "LV " .. t.lv
			label(face, "Lv", 16, 12, 150, 46, lv, 34, C.Text, { font = F.display })
			if i == 1 then -- the next reward: Quick Play's "selected" border, and a gold chip
				face:FindFirstChildOfClass("UIStroke").Thickness = B + 2
				chip(face, "Next", 16 + textW(lv, 34, FE.display) + 14, 16, "NEXT", 22, C.Gold, C.Ink, { font = F.display, fe = FE.display, dy = 2 })
			end
			if t.kind == "Sparks" then
				halftone(face, "Patch", 132, 118, 96, 80, "paper", 0.8, 16)
				sparksIcon(face, cw // 2 - 54, 78, 108, nil, true)
				label(face, "Reward", 8, 206, cw - 16, 46, fmt(t.amount) .. " SPARKS", 30, C.Text, { ax = "C" })
			else
				halftone(face, "Patch", 132, 118, 96, 80, "paper", 0.8, 16)
				elementArt(face, cw // 2 - 62, 72, 124, t.el)
				local nm = t.name:upper()
				label(face, "Reward", 8, 200, cw - 16, 42, nm, fitSize(nm, cw - 24, 32, 22, FE.display), C.Text, { font = F.display, ax = "C" })
				mono(face, "Sub", 8, 242, cw - 16, 30, (t.el .. " · " .. t.kind):upper(), 20, C.Dim, { ax = "C" })
				rarityChip(face, cw - 16 - chipW(RARITY[t.rarity].word, 20), 16, t.rarity, 20)
			end
			trackMark(face, 14, 292, cw - 28, 46, t.track)
		end
	end

	-- ================================================================ top bar (everywhere): back, title, balances
	do
		local top = frame(D, "TopBar", 0, 0, 1920, 136)
		-- the back slab (Quick Play's): it closes the shop
		local _, cf = slab(top, "CloseButton", LEFT, 30, 104, 92, C.Pill, BIG, { button = true })
		label(cf, "Arrow", 0, -2, 92, 80, "◀", 68, C.Text, { ax = "C" })
		-- the tilted title banner: Gold slab, ink dots, LuckiestGuy ink (no extrude, as QUICK PLAY's)
		local tw = textW("SHOP", 84, FE.display)
		local bw = tw + 112
		local _, bf = slab(top, "Title", LEFT + 104 + 24, 20, bw + S, 96 + S, C.Gold, BIG, { rot = -1.5 })
		halftone(bf, "Halftone", 0, 0, bw, 96, "colour", 0.9, 11, 1, R)
		label(bf, "Word", 0, 5, bw, 96, "SHOP", 84, C.Ink, { font = F.display, ax = "C", z = 2 })
		-- balances: Pill slabs, top-right. Sparks mark + amount + the green "+" slab; Robux glyph + amount.
		local rStr = fmt(BAL.robux)
		local rw = 18 + 40 + 10 + textW(rStr, 36) + 8 + 18
		local rb, rf = slab(top, "RobuxBalance", FACE_R - rw, 34, rw + MED.s, 76 + MED.s, C.Pill, MED)
		rb:SetAttribute("Placeholder", true)
		robuxIcon(rf, 18, 18, 40, C.Text)
		label(rf, "Amount", 68, 0, textW(rStr, 36) + 8, 76, rStr, 36, C.Text)
		local sStr = fmt(BAL.sparks)
		local nw, ww = textW(sStr, 36), monoW("SPARKS", 22)
		local sw = 16 + 44 + 10 + nw + 12 + ww + 14 + 56 + 18
		local sb, sf = slab(top, "SparksBalance", FACE_R - rw - MED.s - 18 - sw, 34, sw + MED.s, 76 + MED.s, C.Pill, MED)
		sparksIcon(sf, 16, 16, 44, nil, true)
		label(sf, "Amount", 70, 0, nw + 8, 76, sStr, 36, C.Text)
		mono(sf, "Word", 70 + nw + 12, 2, ww, 76, "SPARKS", 22, C.Dim)
		local _, pf = slab(sb, "AddSparks", sw - 18 - 52, 9, 52 + SML.s, 52 + SML.s, C.Green, SML, { button = true, z = 3 })
		label(pf, "Plus", 0, -3, 52, 52, "+", 44, C.CreamText, { ax = "C", stroke = { 2, C.Ink } })
	end

	-- ================================================================ the tab strip, under the header (everywhere)
	-- Settings' strip: an ink bar under white dots, GothamBlack capitals; the active tab is a red slab with a cream
	-- word. Each tab's Active is that slab (the controller's Glider is cut from it and slides between tabs).
	do
		local tabs, tf, tw = slab(D, "Tabs", LEFT, 142, FACE_R - LEFT + MED.s, 72 + MED.s, C.Ink, MED)
		tabs.Shadow.ZIndex = -1; tf.ZIndex = 0   -- under the Glider (ZIndex 1) and the tabs (2)
		halftone(tf, "Halftone", 0, 0, tw, 72, "ink", 0.86, 14, 1, MED.r)
		for i, t in ipairs({ "Today", "Catalog", "Caches", "Pass" }) do
			local tb = tbutton(tabs, "Tab_" .. t, 10 + (i - 1) * 310, 8, 300, 56, nil, { z = 2 })
			tb:SetAttribute("Page", t)
			label(tb, "Word", 0, 0, 300, 56, t:upper(), 26, C.CreamDim, { ax = "C" })
			local hi = frame(tb, "Active", 0, 0, 300, 56, C.RedInk, { r = MED.r, stroke = { CHIP_B, C.Ink }, z = 2 })
			label(hi, "Word", 0, 0, 300, 56, t:upper(), 26, C.CreamText, { ax = "C", z = 2 })
			K.paintTab(tb, t == "Today")
		end
	end

	-- ================================================================ confirm popup (filled per selection by fillConfirm)
	-- the ink scrim (Settings'/Loadout's: ink at 0.35 under faint white dots) is the modal itself, three canvases wide
	-- and tall so it covers the screen at any aspect; the sheet is a Paper slab under the dot screen, with an ink head bar
	do
		local m = tbutton(D, "ConfirmModal", -MODAL_X, -MODAL_Y, 3 * 1920, 3 * 1080, C.Ink, { transp = 0.35, z = 50 })
		-- (no dot screen on the scrim: the brief keeps the all-over dot screens to the backdrop and the sheet)
		local card = tbutton(m, "Card", MODAL_X + 560, MODAL_Y + 180, CW + S, 720 + S, nil, { z = 2 })
		frame(card, "Shadow", S, S, CW, 720, C.Ink, { r = R, z = 0 })
		local sheet = frame(card, "Face", 0, 0, CW, 720, C.Sheet, { r = R, z = 1, stroke = { B, C.Ink } })
		halftone(sheet, "Halftone", 0, 0, 0, 0, "paper", 0.78, 11, 1, R).Size = UDim2.fromScale(1, 1)
		local head = frame(sheet, "Head", 0, 0, CW, HEAD, C.Ink, { r = R, z = 2 })
		halftone(head, "Halftone", 0, 0, CW, HEAD, "ink", 0.86, 12, 1, R)
		label(head, "Word", 26, 1, CW - 52, HEAD, "CONFIRM PURCHASE", 42, C.CreamText, { font = F.banner, z = 2 })
		-- CANCEL: a paper slab, ink word (SOLO TEST's). BUY: the green primary.
		local _, cf, cw, ch = slab(card, "Cancel", 60, 584, 320 + S, 92 + S, C.Pill, BIG, { button = true, z = 4 })
		halftone(cf, "Halftone", 0, 0, cw, ch, "paper", 0.9, 12, 1, R)
		buttonWord(cf, cw, ch, "CANCEL", 40, false, 5)
		greenButton(card, "Buy", CW - 60 - 320, 584, 320 + S, 92 + S, "BUY", 60, 4)
		K.fillConfirm(card, { type = "item", it = BYID.s02 })
		m.Visible = false
	end

	-- ================================================================ toast: an ink slab, cream GothamBlack
	do
		local toast = frame(D, "Toast", 660, 958, 600 + MED.s, 76 + MED.s, nil, { z = 60 })
		local sh = frame(toast, "Shadow", MED.s, MED.s, 0, 0, C.Ink, { r = MED.r, z = 0 })
		sh.Size = UDim2.new(1, -MED.s, 1, -MED.s)
		local tf = frame(toast, "Face", 0, 0, 0, 0, C.Ink, { r = MED.r, z = 1, stroke = { MED.b, C.Ink } })
		tf.Size = UDim2.new(1, -MED.s, 1, -MED.s)
		halftone(tf, "Halftone", 0, 0, 0, 0, "ink", 0.86, 12, 1, MED.r).Size = UDim2.fromScale(1, 1)
		label(tf, "Word", 0, 0, 0, 0, "", 28, C.CreamText, { ax = "C", z = 2 }).Size = UDim2.fromScale(1, 1)
		K.setToast(toast, "Demo: purchase not connected yet, nothing was charged")
		toast.Visible = false
	end

	-- ================================================================ rest pose: Today, nothing lit, no popup
	for _, n in ipairs({ "PageCatalog", "PageCaches", "PagePass" }) do D[n].Visible = false end
	for _, x in ipairs(D:GetDescendants()) do
		if x.Name == "HoverFX" and x:IsA("GuiObject") then x.Visible = false end
	end
	return backdrop
end

return K
