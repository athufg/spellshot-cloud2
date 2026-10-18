--[[
	HeadingCompass  (ModuleScript)  ->  ReplicatedStorage/Spellshot/HeadingCompass

	The HUD heading compass: a strip that shows which way the CAMERA is pointing, as a tape of degree
	numbers sliding past a fixed centre readout. This module is pure drawing and layout maths. It
	never touches Players, the camera or the settings; HeadingCompassClient owns all of that, and
	_compass_preview.luau (on disk) runs this same source in Edit.

	NORTH. This is the project's first written north.
	    0 degrees = world +Z, the direction the maps' own part names call North,
	    counting UP as the player turns right:   0 = +Z    90 = -X    180 = -Z    270 = +X
	The zero lives in ONE constant, ZERO_OFFSET_DEG: it is the heading shown while looking along
	world +Z. Change that number and nothing else to re-point north.

	SCOPE. The player's OWN heading and nothing else: no marker for an enemy, a teammate or an
	objective, and no N / E / S / W. Numbers only. That is a design decision, not an omission.

	THE LOOK (numbers only, 2026-10-04). Nothing is drawn behind the numerals: no band, no plate,
	no dots, no image of any kind. Every numeral is LuckiestGuy with an Ink UIStroke, the way the
	HUD draws its other floating numbers (StatusReactions' inkText), so it reads over a bright sky
	and over a dark wall. The centre readout is the lead: the exact heading as a whole number, in
	the HUD's Gold, bigger than any tape number, always opaque, in a box sized for three digits so
	nothing moves when the digit count changes. The tape numbers are white.

	THE RING. With no band the numbers alone carry the curve. The tape is a cylinder seen from the
	front: a number d degrees from the heading sits at  x = RING * sin(d) / sin(HALF_ANGLE), so
	the numbers close up toward the ends; its size falls with cos(d) (1 at the centre, MIN_SCALE
	at the ends); and its opacity falls all the way across the arc,
	1 - (d / HALF_ANGLE) ^ FADE_POWER: nearly solid beside the readout, gone exactly at the end.
	Fill and ink edge fade together. A number also fades out before it would touch the readout.

	SMOOTH, NOT STEPPY. TextSize rounds to whole pixels, so it is never animated. Every tape number
	keeps one TextSize and is sized by its own UIScale (its ink edge shrinks with it), and every
	position is a UDim2 SCALE (offsets truncate to whole pixels). Nothing is rotated.

	COST. 36 number labels (0, 10 .. 350) are made once in new(); each keeps its value for life,
	so no text is ever rewritten on the tape. SetHeading only moves, scales, fades and hides them.
	The ticks are switched off by SHOW_TICKS: while it is false no tick instance is made.
]]

local HeadingCompass = {}

----------------------------------------------------------------------------------------------------
-- constants
----------------------------------------------------------------------------------------------------
HeadingCompass.ZERO_OFFSET_DEG = 0      -- the heading read while looking along world +Z
HeadingCompass.HALF_ANGLE_DEG = 40      -- how much of the ring shows either side of the heading
HeadingCompass.LABEL_STEP_DEG = 10      -- a number every 10 degrees: a pool of 36
HeadingCompass.SHOW_TICKS = false       -- true: a tick between every two numbers, made in new()
HeadingCompass.TICK_STEP_DEG = 5        -- ticks go on the multiples of this that carry no number
HeadingCompass.MIN_SCALE = 0.8          -- a number's size at the very end of the arc (centre = 1)
HeadingCompass.FADE_POWER = 3           -- opacity = 1 - (d / HALF_ANGLE) ^ FADE_POWER (60 and 120 at a heading of 90: ~0.58)
HeadingCompass.DESIGN_W = 520           -- design px at Fit 1, before the HUD scale
HeadingCompass.DESIGN_H = 31            -- the readout's digits and their ink edge, nothing else
-- The whole strip against the HUD's own scale s. Layout starts the fit at s * SCALE, so the feed,
-- chip and button clamps and MIN_FIT all work on the size that is drawn.
HeadingCompass.SCALE = 0.8
HeadingCompass.FLAT_EPS = 1e-3          -- looking straight up or down: keep the last heading

-- What PopArtHUD uses to size itself (its applyScale and the TopCentre group). Layout() repeats
-- the formula so the strip keeps to the plate's scale (times SCALE).
HeadingCompass.HUD = {
	DesignW = 1060, DesignH = 600, MinScale = 0.34, MaxScale = 0.85,
	PlateW = 332, PlateH = 94, PlateScale = 0.65, TopMargin = 10,
}
-- Between the strip and the round plate, x s. The numerals have no band around them, so no air
-- of their own, and the plate's ink outline (4.5 x s) is drawn outside its rectangle: at 6 the
-- readout sat 1 px off that outline (measured in an Edit capture), at 10 it is 4 to 5 px.
HeadingCompass.GAP = 10
HeadingCompass.FEED_GAP = 8             -- kept clear of the recent-duel feed, x s
HeadingCompass.BUTTON_GAP = 8           -- kept clear of Roblox's top-left buttons and the chip row, px
-- The strip belongs ABOVE the round plate, in the top row. That row has to hold it at this much
-- of its full size (s * SCALE) or more; if it cannot (the chips, on a landscape phone) the strip
-- goes BELOW the plate instead.
HeadingCompass.ABOVE_MIN = 0.85
-- Below this Layout says hide. Two cases set it and both must show: a landscape phone at UI
-- Size 100% (s 0.528, fit 0.423: the readout's TextSize is 13.5 px, its digits 10 px tall, the
-- tape numbers' TextSize 9 px) and UI Size 50% on a desktop (s 0.425, fit 0.34: readout 11 px,
-- that player chose the size).
HeadingCompass.MIN_FIT = 0.33

local W, H = HeadingCompass.DESIGN_W, HeadingCompass.DESIGN_H
local HALF = HeadingCompass.HALF_ANGLE_DEG
local MIN_SCALE = HeadingCompass.MIN_SCALE
local FADE_POWER = HeadingCompass.FADE_POWER
local LABEL_STEP = HeadingCompass.LABEL_STEP_DEG
local TICK_STEP = HeadingCompass.TICK_STEP_DEG

local SIN_HALF = math.sin(math.rad(HALF))
local COS_HALF = math.cos(math.rad(HALF))

local C = {
	Ink = Color3.fromRGB(17, 17, 17),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(245, 184, 0),
}

-- text, design px inside Root (W x H). The tape numbers and the readout share one centre line.
local LABEL_SIZE = 22                   -- the tape numbers' one TextSize
local LABEL_BOX = Vector2.new(66, 27)
local LABEL_STROKE = 2.6                -- their ink edge (it scales with the number)
local READ_SIZE = 32                    -- the centre readout
local READ_STROKE = 3.2
local READ = { w = 64, h = 40 }         -- its box: the widest three digits ("300") and their edge
-- LuckiestGuy's digits sit above the middle of their line: their optical centre is 0.15 of the
-- TextSize higher than a centred label puts it (measured off the font, and off the health bar's
-- number in the live HUD). Both the tape numbers and the readout are moved down by that much.
-- The digits are 0.72 of the TextSize tall.
local DIGIT_LIFT = 0.15
-- each digit's width as a fraction of the TextSize (its advance, measured off the font file)
local ADVANCE = {
	["0"] = 0.632, ["1"] = 0.388, ["2"] = 0.508, ["3"] = 0.527, ["4"] = 0.538,
	["5"] = 0.530, ["6"] = 0.572, ["7"] = 0.505, ["8"] = 0.570, ["9"] = 0.554,
}
-- A number never slides under the readout (two numerals on top of each other read as neither):
-- it fades out over CENTRE_FADE design px and is gone while its ink is still CENTRE_CLEAR px
-- from the readout's box.
local CENTRE_FADE = 9
local CENTRE_CLEAR = 3
local READ_EDGE = READ.w / 2
-- the ticks (only when SHOW_TICKS): white with the ink edge, like the numbers
local TICK_W, TICK_H = 3, 12
local TICK_STROKE = 1.5
-- A tick touching a number reads as a digit ("|300" as 1300): it fades out as the number's edge
-- comes within TICK_CLEAR design px of it, and is gone at TICK_TOUCH.
local TICK_CLEAR, TICK_TOUCH = 6, 2

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end

-- Position and Size as SCALE of a parent pw x ph design px, so fractions of a pixel survive.
local function at(pw, ph, x, y)
	return UDim2.fromScale(x / pw, y / ph)
end

--- The ink edge of a numeral (Contextual: on the glyphs) or of a tick (Border: on the frame).
local function inkEdge(inst, thickness, mode)
	return make("UIStroke", {
		Color = C.Ink, Thickness = thickness,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round,
	}, inst)
end

--- The ring's falloff: 1 at the heading, `floor` at HALF degrees either side.
local function falloff(deg, floor)
	return floor + (1 - floor) * (math.cos(math.rad(deg)) - COS_HALF) / (1 - COS_HALF)
end

--- Half the inked width of a tape number at size 1, design px: its digits and its edge.
local function inkHalf(text)
	local w = 0
	for i = 1, #text do w += ADVANCE[string.sub(text, i, i)] or 0.56 end
	return w * LABEL_SIZE / 2 + LABEL_STROKE
end

-- The arc ends where the widest number, at its smallest, still has all its ink inside the strip:
-- no number is ever cut by the strip's edge. RING is that half width, design px.
local RING = W / 2
do
	local widest = 0
	for v = 0, 360 - LABEL_STEP, LABEL_STEP do widest = math.max(widest, inkHalf(tostring(v))) end
	RING -= widest * MIN_SCALE
end
local REACH = RING / (W / 2)

----------------------------------------------------------------------------------------------------
-- heading
----------------------------------------------------------------------------------------------------
--- The heading of a camera CFrame in degrees, 0 to 360. Looking almost straight up or down the
--- flattened look vector has no direction: `last` comes back unchanged (0 if there is none).
function HeadingCompass.FromCFrame(cf, last)
	local look = cf.LookVector
	local x, z = look.X, look.Z
	local eps = HeadingCompass.FLAT_EPS
	if x * x + z * z < eps * eps then
		return last or 0
	end
	local h = (math.deg(math.atan2(-x, z)) + HeadingCompass.ZERO_OFFSET_DEG) % 360
	return (h < 360) and h or 0     -- a tiny negative angle rounds up to exactly 360
end

--- Where a mark `d` degrees from the heading sits. Returns x (-1 .. 1 of the ring's half width),
--- its size (MIN_SCALE .. 1) and its opacity (1 at the heading, falling to 0 exactly at the end
--- of the arc); nil when it is off the visible slice.
function HeadingCompass.Project(d)
	local a = math.abs(d)
	if a >= HALF then return nil end
	return math.sin(math.rad(d)) / SIN_HALF, falloff(d, MIN_SCALE), 1 - (a / HALF) ^ FADE_POWER
end

----------------------------------------------------------------------------------------------------
-- layout maths (pure: the client feeds it live readings, the Edit test feeds it mocks)
----------------------------------------------------------------------------------------------------
--- input, all in the full-bleed layer's own px:
---   screen      Vector2   the layer's size
---   hud         Vector2?  the PopArtHUD ScreenGui's AbsoluteSize (what the HUD scales from)
---   uiScale     number?   Settings.Scale("UIScale")
---   plate       { x, y, w, h }?   the round plate at its NORMAL place (the caller takes the
---                                 current shift back out); nil or empty falls back to the HUD's formula
---   feedLeft, feedTop  number?    left and top edge of the recent-duel feed
---   chip        { x, y, w, h }?   the visible chips of the top-right row, as one rectangle (in a
---                                 match that is QuickPlay's PLAY; the SHOP chip joins it outside
---                                 one). The row is fixed px and draws above the HUD.
---   topbarMinX, topbarHeight  number?  GuiService.TopbarInset: right edge of Roblox's own
---                                      top-left buttons, and the height of that row
--- returns { arrangement, s, fit, x, y, halfWidth, clampedBy, below, show, shift }: Root goes at
--- (x, y) with Fit = fit, and the round plate goes down by `shift` px (0 unless "above").
function HeadingCompass.Layout(input)
	local hud = HeadingCompass.HUD
	local screen = input.screen
	local vp = input.hud
	if not vp or vp.X < 8 or vp.Y < 8 then vp = screen end
	local s = math.clamp(math.min(vp.X / hud.DesignW, vp.Y / hud.DesignH), hud.MinScale, hud.MaxScale)
		* (input.uiScale or 1)

	-- ABOVE the round plate (preferred): the strip takes the plate's own top margin, centred on
	-- the screen, and the plate goes down by the strip's height and the gap. Nothing here reads
	-- the plate's live place, so moving the plate cannot move the strip.
	do
		local half = W / 2
		local full = s * HeadingCompass.SCALE
		local cx, top = screen.X / 2, math.max(4, math.floor(hud.TopMargin * s))
		local fit, by = full, "none"
		if input.topbarMinX and top < (input.topbarHeight or 0) then
			local room = (cx - input.topbarMinX - HeadingCompass.BUTTON_GAP) / half
			if room < fit then fit, by = room, "buttons" end
		end
		local chip = input.chip
		if chip and chip.w > 0 and chip.h > 0 and top < chip.y + chip.h then
			local room = (chip.x - cx - HeadingCompass.BUTTON_GAP) / half
			if room < fit then fit, by = room, "chips" end
		end
		if fit >= HeadingCompass.ABOVE_MIN * full and fit >= HeadingCompass.MIN_FIT then
			local shift = math.floor(H * fit + HeadingCompass.GAP * s + 0.5)
			-- the feed is lower and to the right: the plate, once down, must still clear it
			local p = input.plate
			local right, bottom
			if p and p.w > 0 and p.h > 0 then
				right, bottom = p.x + p.w, p.y + p.h
			else
				right = cx + hud.PlateW * hud.PlateScale * s / 2
				bottom = top + hud.PlateH * hud.PlateScale * s
			end
			local onFeed = input.feedLeft ~= nil and right + HeadingCompass.FEED_GAP * s > input.feedLeft
				and (input.feedTop == nil or bottom + shift > input.feedTop)
			if not onFeed then
				return { arrangement = "above", s = s, fit = fit, x = cx, y = top, halfWidth = half * fit,
					clampedBy = by, below = "none", show = true, shift = shift }
			end
		end
	end

	-- BELOW the round plate (the fallback, and where the strip sat before 2026-10-04): shift 0.
	local cx, top
	local p = input.plate
	if p and p.w > 0 and p.h > 0 then
		cx = p.x + p.w / 2
		top = p.y + p.h
	else
		cx = screen.X / 2
		top = math.max(4, math.floor(hud.TopMargin * s)) + hud.PlateH * hud.PlateScale * s
	end
	top += HeadingCompass.GAP * s

	local half = W / 2
	local fit, by = s * HeadingCompass.SCALE, "none"
	if input.feedLeft then
		local room = (input.feedLeft - cx - HeadingCompass.FEED_GAP * s) / half
		if room < fit then fit, by = room, "feed" end
	end
	-- The chip row does not scale with the HUD, so on a narrow screen (every landscape phone) the
	-- strip would run under it. Shrinking it clear would leave nothing to read: it goes below the
	-- row instead.
	local below = "plate"
	local chip = input.chip
	if chip and chip.w > 0 and chip.h > 0 and top < chip.y + chip.h
		and cx + half * fit > chip.x - HeadingCompass.BUTTON_GAP then
		top = chip.y + chip.h + HeadingCompass.GAP * s
		below = "chips"
	end
	-- Roblox's buttons only matter when the strip starts inside their row
	if input.topbarMinX and top < (input.topbarHeight or 0) then
		local room = (cx - input.topbarMinX - HeadingCompass.BUTTON_GAP) / half
		if room < fit then fit, by = room, "buttons" end
	end
	local show = fit >= HeadingCompass.MIN_FIT
	fit = math.max(fit, 0.01)
	return { arrangement = "below", s = s, fit = fit, x = cx, y = top, halfWidth = half * fit,
		clampedBy = by, below = below, show = show, shift = 0 }
end

----------------------------------------------------------------------------------------------------
-- the strip
----------------------------------------------------------------------------------------------------
local Compass = {}
Compass.__index = Compass

function HeadingCompass.new(parent)
	local self = setmetatable({}, Compass)

	local root = make("Frame", {
		Name = "HeadingCompass", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(W, H), ZIndex = 3,
	}, nil)
	local fit = make("UIScale", { Name = "Fit", Scale = 1 }, root)

	-- the tape: a window the size of the strip. ZIndex rises in draw order through the whole
	-- strip, so it layers the same under either ZIndexBehavior.
	local tape = make("Frame", {
		Name = "Tape", BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1), ZIndex = 5,
	}, root)

	local ticks, labels = {}, {}
	if HeadingCompass.SHOW_TICKS then
		for v = 0, 360 - TICK_STEP, TICK_STEP do
			if v % LABEL_STEP ~= 0 then
				local f = make("Frame", {
					Name = "Tick" .. v, BackgroundColor3 = C.White, BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 5,
				}, tape)
				ticks[#ticks + 1] = { value = v, frame = f, on = false, alpha = 1,
					edge = inkEdge(f, TICK_STROKE, Enum.ApplyStrokeMode.Border) }
			end
		end
	end
	for v = 0, 360 - LABEL_STEP, LABEL_STEP do
		local text = tostring(v)
		local t = make("TextLabel", {
			Name = "Label" .. v, BackgroundTransparency = 1, BorderSizePixel = 0,
			-- anchored on the digits' optical centre, so the number grows and shrinks about the
			-- tape's centre line
			AnchorPoint = Vector2.new(0.5, 0.5 - DIGIT_LIFT * LABEL_SIZE / LABEL_BOX.Y),
			Size = UDim2.fromOffset(LABEL_BOX.X, LABEL_BOX.Y),
			Font = Enum.Font.LuckiestGuy, TextSize = LABEL_SIZE, TextColor3 = C.White,
			Text = text, Visible = false, ZIndex = 6,
		}, tape)
		labels[#labels + 1] = { value = v, label = t, on = false, alpha = 1, half = inkHalf(text),
			scale = make("UIScale", { Scale = 1 }, t), edge = inkEdge(t, LABEL_STROKE) }
	end

	-- the fixed readout, dead centre: a box sized for three digits, so nothing moves when the
	-- digit count changes
	local box = make("Frame", {
		Name = "Readout", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = at(W, H, READ.w, READ.h), ZIndex = 7,
	}, root)
	local readout = make("TextLabel", {
		Name = "Value", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = at(READ.w, READ.h, 0, DIGIT_LIFT * READ_SIZE), Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.LuckiestGuy, TextSize = READ_SIZE, TextColor3 = C.Gold,
		Text = "0", ZIndex = 9,
	}, box)
	inkEdge(readout, READ_STROKE)

	self.Root = root
	self.Fit = fit
	self._ticks = ticks
	self._labels = labels
	self._readout = readout
	self._lx, self._lr, self._la = {}, {}, {}     -- SetHeading's scratch: the inked numbers
	self._heading = nil
	self._shown = 0

	self:SetHeading(0)
	root.Parent = parent
	return self
end

--- Lay the tape out for a heading in degrees (any real number; it wraps). Cheap enough for every
--- frame: no instance is made, hidden marks only have Visible switched off.
function Compass:SetHeading(deg)
	if deg ~= deg or not self.Root then return end      -- NaN, or already destroyed
	deg = deg % 360
	if deg == self._heading then return end
	self._heading = deg

	local whole = math.floor(deg + 0.5) % 360
	if whole ~= self._shown then
		self._shown = whole
		self._readout.Text = tostring(whole)
	end

	local project = HeadingCompass.Project
	local ticks = self._ticks
	local ticking = ticks[1] ~= nil
	-- the numbers first: the ticks (when on) need to know where the inked ones are
	local lx, lr, la, n = self._lx, self._lr, self._la, 0
	for _, m in ipairs(self._labels) do
		-- the wrapped difference: 359 to 0 is one degree, not a jump
		local x, size, alpha = project((m.value - deg + 180) % 360 - 180)
		if x then
			local px, half = x * RING, m.half * size
			local gap = (math.abs(px) - READ_EDGE - half - CENTRE_CLEAR) / CENTRE_FADE
			if gap < 1 then alpha *= math.max(gap, 0) end
			if ticking and alpha > 0 then
				n += 1
				lx[n], lr[n], la[n] = px, half, alpha
			end
			local t = m.label
			t.Position = UDim2.fromScale(0.5 + 0.5 * x * REACH, 0.5)
			m.scale.Scale = size
			if alpha ~= m.alpha then
				m.alpha = alpha
				t.TextTransparency = 1 - alpha
				m.edge.Transparency = 1 - alpha
			end
			if not m.on then m.on = true; t.Visible = true end
		elseif m.on then
			m.on = false
			m.label.Visible = false
		end
	end
	for _, m in ipairs(ticks) do
		local x, size, alpha = project((m.value - deg + 180) % 360 - 180)
		if x then
			local px, reach = x * RING, TICK_W * size / 2 + TICK_STROKE + TICK_TOUCH
			-- with no plate to hide under, a tick is gone before it reaches the readout
			local gap = (math.abs(px) - READ_EDGE - reach) / CENTRE_FADE
			if gap < 1 then alpha *= math.max(gap, 0) end
			for i = 1, n do
				gap = (math.abs(px - lx[i]) - lr[i] - reach) / (TICK_CLEAR - TICK_TOUCH)
				if gap < 1 then alpha *= 1 - la[i] * (1 - math.max(gap, 0)) end
			end
			local f = m.frame
			f.Position = UDim2.fromScale(0.5 + 0.5 * x * REACH, 0.5)
			f.Size = UDim2.fromScale(TICK_W / W * size, TICK_H / H * size)
			if alpha ~= m.alpha then
				m.alpha = alpha
				f.BackgroundTransparency = 1 - alpha
				m.edge.Transparency = 1 - alpha
			end
			if not m.on then m.on = true; f.Visible = true end
		elseif m.on then
			m.on = false
			m.frame.Visible = false
		end
	end
end

function Compass:Destroy()
	if self.Root then self.Root:Destroy() end
	self.Root, self.Fit, self._readout = nil, nil, nil
	self._ticks, self._labels = {}, {}
end

return HeadingCompass
