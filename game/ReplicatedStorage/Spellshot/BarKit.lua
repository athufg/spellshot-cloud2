--[[
	BarKit  (ModuleScript)  ->  ReplicatedStorage/Spellshot/BarKit

	The health bar, mana bar and icon badges from
	"SPELLSHOT Pop-Art HUD Kit v2.pdf" -- built TWO WAYS off ONE geometry table:

	    BarKit.Build(parent, "native")    Roblox Frames: UICorner, UIStroke, a tiled dot image
	    BarKit.Build(parent, "blender")   the PNGs rendered by build_popart_bars_v3.py

	Everything that is not the chassis is identical between the two -- same numbers, same text
	layer, same glyph art, same 40%-black offset shadow -- so a side-by-side is a test of how the
	chassis is produced and nothing else.

	WHERE THE NUMBERS COME FROM
	The kit page is vector, so every rect, corner radius, stroke width, tiling-pattern pitch and
	text size below was read out of the PDF's content stream and scaled by one factor, K = 1.6
	design px per PDF point, chosen so the assembled group lands on the 516px the HUD's
	bottom-left group already occupies. Nothing here was measured off a screenshot.

	THREE THINGS THE REFERENCE ACTUALLY SAYS
	  * The halftone covers the WHOLE trough -- one dot layer over both the fill and the empty
	    remainder, which is why it reads dark on the colour and pale grey on the white.
	  * They are round dots at 21.6% black (health) / 29.8% (mana), on a 11.2px pitch. The
	    plus-shapes you see zooming into the page are the PDF rasteriser upsampling a 3pt dot.
	  * There is no highlight streak. Dropped on instruction.

	The kit's tags are deliberately absent: the Shield tag was removed in an earlier pass, and the
	element and level tags on request (2026-09-11). The reference image predates both.

	THE FILL IS CLIPPED, NEVER STRETCHED. A Clip frame of the current width holds a full-width
	fill, so the left cap keeps the chassis's corner radius and the right end is a hard vertical
	cut -- which is exactly how the kit draws it (its fill is an unrounded rect behind a rounded
	white shape).
]]

local BarKit = {}

----------------------------------------------------------------------------------------------------
-- geometry, in design px
----------------------------------------------------------------------------------------------------
local G = {
	Badge   = 62,   BadgeR = 13,
	BarW    = 422,  HpH = 53,  HpR = 22,
	-- DELIBERATELY OFF THE KIT. Its mana bar is 25.5pt, 0.77 of the health bar; on request this
	-- drops to 0.57 so it reads as clearly secondary instead of as a second health bar.
	MpH = 30,  MpR = 12,
	Stroke  = 4.8,
	Gap     = 12,   RowGap = 86.4,
	Shadow  = 6,    ShadowT = 0.598,          -- the kit's shadow is black at 40.2%
	Heart   = 29,   GemW = 21,   GemH = 25,     -- heart at the kit's 18pt; the mana mark is
	                                            -- deliberately smaller, so the two badges are
	                                            -- not equally loud
	ValInset = 17,  ValStroke = 2.4,
	LblInset = 18,
	DotPitch = 11.2,
	-- ROW SCALES, on request: the health row (bar + heart badge) at 73% of the kit, the mana row
	-- (bar + gem badge) at 53%. Each row is built at kit size inside its own frame and scaled there,
	-- so every radius, stroke and dot pitch shrinks with it and stays in proportion.
	HpScale = 0.726,
	MpScale = 0.529,
	StackGap = 8,                     -- between the health row and the mana row
}

local SIZE = { Health = G.HpH, Mana = G.MpH }
local RADIUS = { Health = G.HpR, Mana = G.MpR }
-- The kit's numerals are 19.5pt / 14.25pt, which scales to 31 / 23 design px -- but TextSize is
-- an em size and LuckiestGuy fills more of its em than the kit's face does. Measured against the
-- reference's outline bbox (36x24 px for "78"), 31 rendered 27.5 tall; these are the sizes that
-- land on 24.
-- Mana's numerals scale with its bar (20 * 30/41), or the outline touches the ink top and
-- bottom once the bar is thinned.
local VAL_SIZE = { Health = 27, Mana = 15 }
local LBL_SIZE = { Health = 18, Mana = 13 }
local DOT_ALPHA = { Health = 0.216, Mana = 0.298 }
-- Opposite ink per bar, sampled off the kit: a health dot over the red is DARKER than the ground
-- (black at 21.6%), a mana dot over the blue is LIGHTER (white at 29.8%).
local LABEL = { Health = "H P", Mana = "M A N A" }

local C = {
	Paper = Color3.fromRGB(239, 231, 215),
	Ink   = Color3.fromRGB(17, 17, 17),
	White = Color3.fromRGB(255, 255, 255),
	Red   = Color3.fromRGB(229, 38, 31),
	Blue  = Color3.fromRGB(59, 45, 240),
	Gold  = Color3.fromRGB(245, 184, 0),
}
local FILL_COLOUR = { Health = C.Red, Mana = C.Blue }

-- rendered by blender_scripts/build_popart_bars_v3.py, uploaded 2026-09-09
BarKit.Art = {
	Frame = { Health = "rbxassetid://74206243337435",  Mana = "rbxassetid://89251605487816" },
	Fill  = { Health = "rbxassetid://128406728375800",  Mana = "rbxassetid://103513125794026" },
	Badge = { Health = "rbxassetid://102257661372008",  Mana = "rbxassetid://74072882840966" },
	Glyph = { Health = "rbxassetid://75678556063959",  Mana = "rbxassetid://126300748109535" },
	Dot       = "rbxassetid://82944445925061",   -- one WHITE dot in one 11.2px cell, tiled by
	                                            -- Roblox and tinted per bar. ImageColor3 is
	                                            -- multiplicative, so the tile has to be white
	                                            -- or the mana bar could never go light.
}

-- LAYOUT, top to bottom: health row, mana row. The mana row's bottom is the block's bottom, so a
-- caller that anchors the block to the screen's bottom edge puts the bars there.
-- One function feeds both BarKit.Size and Build(), so the two can never drift apart.
local BAR_X = 88.8                                   -- (99.75 - 44.25) * 1.6, bar interior's left
local function layout()
	local rowW = BAR_X + G.BarW + G.Stroke              -- badge column + bar + the ink
	local rowH = G.Badge + G.Stroke * 2 + G.Shadow       -- the badge is the tallest thing in a row
	local hpY = 0
	local mpY = hpY + rowH * G.HpScale + G.StackGap
	return {
		rowW = rowW, rowH = rowH, hpY = hpY, mpY = mpY,
		width = math.max(rowW * G.HpScale, rowW * G.MpScale),
		height = mpY + rowH * G.MpScale,
	}
end

-- The assembled footprint, available before Build() so a caller can size its group from it.
local L0 = layout()
BarKit.Size = Vector2.new(L0.width, L0.height)

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function corner(inst, r)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, inst)
end

local function stroke(inst, thickness, mode)
	return make("UIStroke", {
		Color = C.Ink, Thickness = thickness,
		-- Border outlines a TextLabel's RECTANGLE, not its glyphs -- that drew a black bar down
		-- the left of the fill. Contextual is the mode that follows the letterform.
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, inst)
end

--- The offset silhouette behind every block. In native mode that is a rounded Frame; in blender
--- mode it is the SAME image tinted black, which gives an exact silhouette for free.
local function shadowFrame(parent, x, y, w, h, r, zi)
	local f = make("Frame", {
		Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = G.ShadowT, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x + G.Shadow, y + G.Shadow),
		Size = UDim2.fromOffset(w, h), ZIndex = zi,
	}, parent)
	corner(f, r)
	return f
end

local function shadowImage(parent, id, x, y, w, h, zi, slice)
	local f = make("ImageLabel", {
		Name = "Shadow", BackgroundTransparency = 1, Image = id,
		ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = G.ShadowT,
		Position = UDim2.fromOffset(x + G.Shadow, y + G.Shadow),
		Size = UDim2.fromOffset(w, h), ZIndex = zi,
	}, parent)
	if slice then
		f.ScaleType = Enum.ScaleType.Slice
		f.SliceCenter = Rect.new(slice[1], slice[2], slice[3], slice[4])
	end
	return f
end

----------------------------------------------------------------------------------------------------
-- the text layer -- identical in both modes
----------------------------------------------------------------------------------------------------
local function _addTextInto(host, interior, kind)
	-- The kit outlines its numerals by stamping four offset black copies behind a white one.
	-- UIStroke is the same result done properly: one outline that follows the letterform.
	local value = make("TextLabel", {
		Name = "Value", BackgroundTransparency = 1,
		Font = Enum.Font.LuckiestGuy, TextSize = VAL_SIZE[kind], TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Position = UDim2.fromOffset(G.ValInset, 0),
		Size = UDim2.new(1, -G.ValInset, 1, 0), Text = "", ZIndex = 22,
	}, host)
	stroke(value, G.ValStroke, Enum.ApplyStrokeMode.Contextual)

	-- Barlow Condensed ExtraBold is not a Roblox face; GothamBlack with the kit's own letter
	-- tracking (it spaces its caps out too) is the closest read available in-engine.
	make("TextLabel", {
		Name = "Label", BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = LBL_SIZE[kind], TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -G.LblInset, 1, 0), Text = LABEL[kind], ZIndex = 12,
	}, interior)
	return value
end


--- The value numerals optionally live OUTSIDE the bar, in a layer the caller owns. The status
--- treatments (frost crust, acid film) paint the whole trough from a ScreenGui above the HUD, and
--- the number underneath is exactly the one you want to read while one is running -- so the caller
--- passes a higher-ordered layer and mirrors the returned holders onto the bars each frame.
local function addText(interior, kind, valueLayer, readouts)
	local host, hold, vscale = interior, nil, nil
	if valueLayer then
		hold = make("Frame", {
			Name = kind .. "Readout", BackgroundTransparency = 1,
			Size = UDim2.fromOffset(G.BarW, SIZE[kind]), ZIndex = 20,
		}, valueLayer)
		vscale = make("UIScale", { Scale = 1 }, hold)
		host = hold
		readouts[#readouts + 1] = { hold = hold, scale = vscale, bar = interior, ox = 0, oy = 0 }
	end
	return _addTextInto(host, interior, kind)
end

----------------------------------------------------------------------------------------------------
-- one bar row
----------------------------------------------------------------------------------------------------
local function buildBar(root, kind, mode, x, centreY, valueLayer, readouts)
	local h, r = SIZE[kind], RADIUS[kind]
	local top = centreY - h * 0.5
	local interior

	if mode == "native" then
		shadowFrame(root, x - G.Stroke, top - G.Stroke,
			G.BarW + G.Stroke * 2, h + G.Stroke * 2, r + G.Stroke, 2)
		interior = make("Frame", {
			Name = kind .. "Bar", BackgroundColor3 = C.White, BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(x, top), Size = UDim2.fromOffset(G.BarW, h), ZIndex = 4,
		}, root)
		corner(interior, r)
		stroke(interior, G.Stroke)
	else
		shadowImage(root, BarKit.Art.Frame[kind], x - G.Stroke, top - G.Stroke,
			G.BarW + G.Stroke * 2, h + G.Stroke * 2, 2)
		make("ImageLabel", {
			Name = kind .. "Chassis", BackgroundTransparency = 1,
			Image = BarKit.Art.Frame[kind],
			Position = UDim2.fromOffset(x - G.Stroke, top - G.Stroke),
			Size = UDim2.fromOffset(G.BarW + G.Stroke * 2, h + G.Stroke * 2), ZIndex = 4,
		}, root)
		-- an invisible frame in interior coordinates, so the fill and text place identically
		interior = make("Frame", {
			Name = kind .. "Bar", BackgroundTransparency = 1, ClipsDescendants = true,
			Position = UDim2.fromOffset(x, top), Size = UDim2.fromOffset(G.BarW, h), ZIndex = 5,
		}, root)
		corner(interior, r)
	end

	-- the clip is the reading; the fill inside it is always full width
	local clip = make("Frame", {
		Name = "Clip", BackgroundTransparency = 1, ClipsDescendants = true,
		Size = UDim2.fromOffset(G.BarW, h), ZIndex = 6,
	}, interior)

	local fill
	if mode == "native" then
		fill = make("Frame", {
			Name = "Fill", BackgroundColor3 = FILL_COLOUR[kind], BorderSizePixel = 0,
			Size = UDim2.fromOffset(G.BarW, h), ZIndex = 6,
		}, clip)
		corner(fill, r)
	else
		fill = make("ImageLabel", {
			Name = "Fill", BackgroundTransparency = 1, Image = BarKit.Art.Fill[kind],
			Size = UDim2.fromOffset(G.BarW, h), ZIndex = 6,
		}, clip)
	end

	-- HALFTONE. Health is the kit's own treatment: black dots at 21.6% over the fill AND the empty
	-- channel alike. Mana is a requested departure -- the kit leaves its empty channel clean
	-- (white dots on white), and here it carries dots too. Getting both inks in one bar is a
	-- layering trick rather than two clipped regions: the dark layer sits UNDER the fill, so it
	-- only ever shows where the fill is not, and the kit's white layer rides on top of the fill.
	-- Both layers tile from the same origin at the same pitch, so they stay in phase and the two
	-- inks meet exactly on the fill boundary.
	if mode == "native" then
		local function dotLayer(parent, colour, alpha, zi)
			return make("ImageLabel", {
				Name = "Halftone", BackgroundTransparency = 1, Image = BarKit.Art.Dot,
				ImageColor3 = colour, ImageTransparency = 1 - alpha,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(G.BarW, h), ZIndex = zi,
				ScaleType = Enum.ScaleType.Tile,
				-- TileSize in OFFSET would truncate 11.2 to 11 and drift ~8px across the bar, so
				-- the pitch is a fraction of the interior instead, which stays float-exact.
				TileSize = UDim2.fromScale(G.DotPitch / G.BarW, G.DotPitch / h),
			}, parent)
		end
		if kind == "Health" then
			dotLayer(interior, Color3.new(0, 0, 0), DOT_ALPHA.Health, 8)
		else
			dotLayer(interior, Color3.new(0, 0, 0), DOT_ALPHA.Health, 5)   -- empty channel only
			dotLayer(clip, Color3.new(1, 1, 1), DOT_ALPHA.Mana, 8)         -- over the fill
		end
	end

	local value = addText(interior, kind, valueLayer, readouts)

	-- A ring OUTSIDE the ink, for the zone-warning pulse. It cannot be a second UIStroke on the
	-- chassis: Roblox applies only one per object, and the chassis's is the ink itself.
	local ring = make("Frame", {
		Name = kind .. "PulseRing", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x - G.Stroke, top - G.Stroke),
		Size = UDim2.fromOffset(G.BarW + G.Stroke * 2, h + G.Stroke * 2), ZIndex = 9,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, r + G.Stroke) }, ring)
	local pulse = make("UIStroke", {
		Color = C.Red, Thickness = 0, Transparency = 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round,
	}, ring)

	return { clip = clip, value = value, interior = interior, pulse = pulse, width = G.BarW }
end

----------------------------------------------------------------------------------------------------
-- badge
----------------------------------------------------------------------------------------------------
local function buildBadge(root, kind, mode, x, centreY)
	local top = centreY - G.Badge * 0.5
	if mode == "native" then
		shadowFrame(root, x - G.Stroke, top - G.Stroke,
			G.Badge + G.Stroke * 2, G.Badge + G.Stroke * 2, G.BadgeR + G.Stroke, 2)
		local card = make("Frame", {
			Name = kind .. "Badge", BackgroundColor3 = C.White, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, top),
			Size = UDim2.fromOffset(G.Badge, G.Badge), ZIndex = 4,
		}, root)
		corner(card, G.BadgeR)
		stroke(card, G.Stroke)
	else
		shadowImage(root, BarKit.Art.Badge[kind], x - G.Stroke, top - G.Stroke,
			G.Badge + G.Stroke * 2, G.Badge + G.Stroke * 2, 2)
		make("ImageLabel", {
			Name = kind .. "Badge", BackgroundTransparency = 1, Image = BarKit.Art.Badge[kind],
			Position = UDim2.fromOffset(x - G.Stroke, top - G.Stroke),
			Size = UDim2.fromOffset(G.Badge + G.Stroke * 2, G.Badge + G.Stroke * 2), ZIndex = 4,
		}, root)
	end

	-- the glyph is rendered art in BOTH modes: Frames cannot draw a heart, and sharing it keeps
	-- the comparison about the chassis
	if mode == "native" then
		local gw = (kind == "Health") and G.Heart or G.GemW
		local gh = (kind == "Health") and (G.Heart / 1.0304) or G.GemH
		make("ImageLabel", {
			Name = "Glyph", BackgroundTransparency = 1, Image = BarKit.Art.Glyph[kind],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x + G.Badge * 0.5, centreY),
			Size = UDim2.fromOffset(gw + G.ValStroke, gh + G.ValStroke),
			ScaleType = Enum.ScaleType.Fit, ZIndex = 7,
		}, root)
	end
end

----------------------------------------------------------------------------------------------------
-- assembly
----------------------------------------------------------------------------------------------------
function BarKit.Build(parent, mode, opts)
	mode = mode or "native"   -- the shipping build; "blender" is kept for comparison
	opts = opts or {}
	local L = layout()
	local width, height = L.width, L.height

	local root = make("Frame", {
		Name = "BarKit_" .. mode, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height), ZIndex = 2,
	}, parent)

	-- one frame per row, built in kit coordinates and scaled from its top-left
	local function row(kind, y, scale)
		local f = make("Frame", {
			Name = kind .. "Row", BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(L.rowW, L.rowH), ZIndex = 2,
		}, root)
		make("UIScale", { Scale = scale }, f)
		return f
	end

	local readouts = {}
	local centreY = G.Badge * 0.5 + G.Stroke
	local function bar(kind, y, scale)
		local r = row(kind, y, scale)
		buildBadge(r, kind, mode, G.Stroke, centreY)
		local b = buildBar(r, kind, mode, BAR_X, centreY, opts.ValueLayer, readouts)
		-- the readout lives in another ScreenGui, so it has to be told about the row's scale
		if opts.ValueLayer then readouts[#readouts].rowScale = scale end
		return b
	end
	local hp = bar("Health", L.hpY, G.HpScale)
	local mp = bar("Mana", L.mpY, G.MpScale)

	local api = {
		root = root,
		size = Vector2.new(width, height),
		bars = { Health = hp, Mana = mp },
		readouts = readouts,          -- the caller mirrors these onto the bars each frame
	}
	function api.Set(kind, frac, text)
		local b = api.bars[kind]
		b.clip.Size = UDim2.fromOffset(math.floor(G.BarW * math.clamp(frac, 0, 1) + 0.5), SIZE[kind])
		if text then b.value.Text = text end
	end
	return api
end

return BarKit
