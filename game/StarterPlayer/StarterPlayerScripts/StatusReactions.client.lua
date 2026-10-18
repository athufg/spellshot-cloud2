--[[
	StatusReactions  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/StatusReactions

	Layer 2 on the approved pop-art HUD chassis, from "SPELLSHOT Status Reactions (standalone)".
	Every treatment is a Blender-rendered asset; this script only decides WHEN each one is on
	screen, WHERE it sits, and -- the part that actually needed designing -- WHICH ONE WINS when
	two want the same surface.

	SHAPE LANGUAGE IS FIXED PER TRIGGER, ONLY THE ACCENT COLOUR CHANGES PER ELEMENT. So a burn
	from any source is always the flame crest, and a chill from any source is always the frost
	crust creeping in from the left; the Element only picks the tint. That is what lets a player
	learn twelve reactions instead of twelve times eight.

	THE FOUR CLASH RULES (section 05 of the brief) ARE IMPLEMENTED HERE, NOT LEFT AS NOTES:

	  R1  ONE FILL TREATMENT AT A TIME on the health bar. Frost crust, acid overlay and ember
	      flicker all repaint the same pixels; two at once cancel out. Most recent wins, and the
	      displaced status drops to a chip on the chip row rather than vanishing -- you still need
	      to know you are poisoned while you are freezing.

	  R2  ZONE WARNING vs SHIELD RING. Both live just outside the bar border. With a shield up the
	      warning is unreadable there, so it moves onto the shield ring itself as a pulsing outer
	      glow instead of competing for the same millimetre.

	  R3  ONE EDGE TREATMENT ONLY, priority visionDenial > primed > marked > stealth. The harshest
	      is also the most urgent to read, so it takes the edge and the others are suppressed while
	      it holds -- not blended, because two stacked vignettes just read as one darker vignette.
	      (PRIMED, Pyro's Detonate fuse, joined 2026-09-23 just under visionDenial: being blinded is
	      that ability's whole effect and a fuse must not lift it. PRIMED's countdown is not an edge
	      treatment, so a blinded player still sees how long they have.)

	  R4  DISPLACEMENT SUPPRESSES HASTE. Haste sweeps and knockback fans are both white comic
	      lines; a knockback during haste would read as nothing at all. Displacement wins for its
	      0.4s and draws at a heavier stroke.

	DRIVING IT
	  StatusReactions.Apply(kind, opts)  / .Clear(kind) / .Pulse(kind, data)
	  and it also self-drives from character attributes so the existing server plumbing
	  (SpellshotService's Status / StatusExpires) lights it up with no extra wiring.

	2026-09-24: every SCREEN-WIDE treatment is gone on request (vignette edges, haste speed lines, displacement
	fans, the MARKED! burst, the cleanse ring). R3 and R4 therefore no longer draw anything; what is left lives on
	the health / mana bars.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local Art = require(folder:WaitForChild("PopArtAssets"))
local Settings = require(folder:WaitForChild("SpellshotSettings"))

local R = {}

----------------------------------------------------------------------------------------------------
-- tuning
----------------------------------------------------------------------------------------------------
local T = {
	CrestFPS = 9,            -- the crest "wavers on staggered timing"; redrawn, never tweened
	RingFPS = 6,
	ShockFPS = 12,
	EmberEvery = 0.16,
	EmberRise = 1.10,
	BubbleEvery = 0.34,
	DisplacementHold = 0.40, -- R4: how long displacement owns the line surface
	HasteFPS = 5,
	ChipSize = 34,
	ChipGap = 6,
	-- PRIMED, Detonate's fuse (2026-09-23). The edge pulse climbs from PrimedPulseSlow to PrimedPulseFast pulses a
	-- second as the fuse runs out, on the square of the elapsed fraction so the last third is where it races. The
	-- steady edge pulse is ~1 a second (sin(now * 3.2)), so it starts just above that. The top stays at 3 a second
	-- because a saturated red edge flashing faster than that is the classic photosensitivity trigger. Reduce
	-- Flashing holds it at PrimedPulseCalm. PrimedRamp stands in for the fuse length when the server sent no
	-- RX_Primed_Total (the dev panel's bare flag).
	PrimedPulseSlow = 1.2,
	PrimedPulseFast = 3.0,
	PrimedPulseCalm = 1.5,
	PrimedRamp = 1.5,
	PrimedCount = 27,        -- the seconds numeral, the HP readout's own size (BarKit VAL_SIZE.Health)
	PrimedWord = 13,
}

local ELEM_TINT = {}
for name, def in pairs(Config.Elements) do
	ELEM_TINT[name] = def.Base
end

----------------------------------------------------------------------------------------------------
-- gui scaffolding
----------------------------------------------------------------------------------------------------
for _, n in ipairs({ "SpellshotReactions", "SpellshotReactionsScreen" }) do
	local g = playerGui:FindFirstChild(n)
	if g then g:Destroy() end
end

-- TWO ScreenGuis, and the split is not cosmetic. Bar treatments are positioned from the HUD's
-- AbsolutePosition, so they must share the HUD's coordinate space -- which means the same
-- IgnoreGuiInset. Full-screen treatments (vignettes, speed lines, displacement fans) have to
-- cover the topbar strip too, so they need the opposite. Putting both in one ScreenGui put every
-- bar treatment exactly one topbar-inset off vertically.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpellshotReactionsScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true          -- must cover the whole screen
screenGui.DisplayOrder = 13
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local gui = Instance.new("ScreenGui")
gui.Name = "SpellshotReactions"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false               -- must match PopArtHUD, or bar art lands off by the inset
gui.DisplayOrder = 14                    -- above the HUD chassis (10), below the dev readout (20)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local screenLayer = Instance.new("CanvasGroup")
screenLayer.Name = "Screen"
screenLayer.BackgroundTransparency = 1
screenLayer.Size = UDim2.fromScale(1, 1)
screenLayer.ZIndex = 1
screenLayer.Parent = screenGui

local barLayer = Instance.new("CanvasGroup")
barLayer.Name = "Bars"
barLayer.BackgroundTransparency = 1
barLayer.Size = UDim2.fromScale(1, 1)
barLayer.ZIndex = 5
barLayer.Parent = gui

--- STATUS INTENSITY and REDUCE FLASHING. Both layers are CanvasGroups filling the screen, so the
--- strength of every treatment -- the crusts, the films, the chips, the vignette, and the parts of
--- them that animate every frame -- is one property each. Reduce Flashing takes a further bite out
--- of the SCREEN layer only: that is where the full-screen bursts and the pulsing vignette live,
--- and the bar treatments are information rather than flash.
local function applyReactionStrength()
	local a = Settings.Scale("StatusIntensity")
	local screenA = a * (Settings.Get("ReduceFlashing") and 0.35 or 1)
	barLayer.GroupTransparency = 1 - a
	screenLayer.GroupTransparency = 1 - screenA
end
Settings.Bind("StatusIntensity", applyReactionStrength)
Settings.Bind("ReduceFlashing", applyReactionStrength)

local function img(parent, image, props)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = image or ""
	i.ScaleType = Enum.ScaleType.Stretch
	i.Visible = false
	for k, v in pairs(props or {}) do
		i[k] = v
	end
	i.Parent = parent
	return i
end

--- Set by the HUD: pulses the health-bar border for the zone warning when no shield is up.
R.HealthBorderPulse = nil

--- The HUD publishes the on-screen rectangle of each surface it owns, so this script never has to
--- guess where the bars ended up. If the HUD is not up yet these stay nil and every bar treatment
--- simply does not render, which is the correct failure mode.
local Surfaces = {}
function R.RegisterSurface(name, guiObject)
	Surfaces[name] = guiObject
end

local function surfaceRect(name)
	local o = Surfaces[name]
	if not o or not o.Parent then return nil end
	return o.AbsolutePosition, o.AbsoluteSize
end

local INK = Color3.fromRGB(17, 17, 17)
local WHITE = Color3.fromRGB(255, 255, 255)
local RED = Color3.fromRGB(228, 37, 31)   -- the kit red, popBurst's default lettering

--- Live lettering on the bar layer, set the way the HUD sets its own numerals (BarKit's HP value): white LuckiestGuy
--- with an ink outline, so it reads over the flame crest, the frost crust or the arena behind it. Two things
--- need it (2026-09-23): the burn stack count on the crest and PRIMED's countdown. Before this the only text
--- on the reaction layer was a popBurst's.
local function inkText(parent, props, stroke)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextColor3 = WHITE
	t.Text = ""
	t.Visible = false
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = stroke or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = t
	t.Parent = parent
	return t
end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local State = {
	fill = nil,              -- R1: which status owns the health-bar fill right now
	fillSince = 0,
	displaced = {},          -- [kind] = true, shown as chips
	shield = nil,            -- { amount, ring }
	zoneWarning = false,     -- R2
	edge = {},               -- R3: [kind] = true
	haste = false,           -- R4
	displaceUntil = 0,
	active = {},             -- [kind] = record
	chipCount = 0,           -- chips on the row right now: PRIMED's badge lines up after them
	character = nil,         -- the body being watched, for a treatment that reads its attributes every frame
}

-- CHARGED is Voltaic's status since manual v0.13 (2026-09-24): the name SHOCKED had no writer and was renamed, not duplicated
local FILL_KINDS = { Burning = true, Chilled = true, Poisoned = true, Charged = true }

-- BarFX (2026-09-24): the round-2 full-bar looks (ReplicatedStorage.Spellshot.BarFX) draw these statuses unless the
-- player's pick for one is OLD (dev panel, BAR FX). This layer steps aside for them, so the two never draw on the bar
-- at once. RX kind here -> BarFX's name.
local BARFX_KIND = { Burning = "burn", Chilled = "chill", Poisoned = "poison", Charged = "charged", Marked = "marked",
	Blessed = "blessed", Primed = "primed", Shielded = "shield" }
local EDGE_PRIORITY = { VisionDenial = 4, Primed = 3, Marked = 2, Stealth = 1 }
-- An edge kind with no vignette of its own borrows one. PRIMED (Pyro's Detonate mark, 2026-09-23) uses the Marked
-- vignette. That art is baked jagged dark red (#8C0E12) and never tinted, since tintOf has no caller, so it reads as
-- fire and danger rather than as Umbra, and nothing new had to be rendered or uploaded. R3 never draws the two
-- kinds together.
local EDGE_ART = { Primed = "Marked" }

----------------------------------------------------------------------------------------------------
-- element helpers
----------------------------------------------------------------------------------------------------
local function tintOf(opts)
	local e = opts and opts.Element
	return (e and ELEM_TINT[e]) or Color3.new(1, 1, 1)
end

----------------------------------------------------------------------------------------------------
-- R1 -- health-bar fill arbitration
----------------------------------------------------------------------------------------------------
local chipRow

local function ensureChipRow()
	if chipRow and chipRow.Parent then return chipRow end
	chipRow = Instance.new("Frame")
	chipRow.Name = "ChipRow"
	chipRow.BackgroundTransparency = 1
	chipRow.Size = UDim2.fromOffset(300, T.ChipSize)
	chipRow.ZIndex = 8
	chipRow.Parent = barLayer
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, T.ChipGap)
	layout.Parent = chipRow
	return chipRow
end

local function refreshChips()
	local row = ensureChipRow()
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("ImageLabel") then c:Destroy() end
	end
	local n = 0
	for kind in pairs(State.displaced) do
		local id = Art.StatusChip[kind]
		if id then
			n += 1
			img(row, id, {
				Name = kind, Visible = true, ZIndex = 8,
				Size = UDim2.fromOffset(T.ChipSize, T.ChipSize),
				LayoutOrder = n,
			})
		end
	end
	-- ABOVE the health bar, not below it. Below put the row under the mana bar and the readout
	-- pills, which on the tightened HUD is past the bottom of the screen -- a displaced status
	-- would drop off the fill and then be invisible. Above the bar is empty space at every size.
	local pos, size = surfaceRect("HealthBar")
	if pos then
		row.Position = UDim2.fromOffset(pos.X, pos.Y - T.ChipSize - 8)
	end
	row.Visible = n > 0
	State.chipCount = n
end

--- Claim the health-bar fill for `kind`. Whoever held it drops to a chip. Returns false if the
--- caller should not draw (it lost the claim), which only happens if it re-claims what it holds.
local function claimFill(kind)
	if not FILL_KINDS[kind] then return true end
	local prev = State.fill
	if prev == kind then return true end
	if prev then
		State.displaced[prev] = true
		local rec = State.active[prev]
		if rec and rec.suppress then rec.suppress() end
	end
	State.displaced[kind] = nil
	State.fill = kind
	State.fillSince = os.clock()
	refreshChips()
	return true
end

local function releaseFill(kind)
	if State.fill ~= kind then
		State.displaced[kind] = nil
		refreshChips()
		return
	end
	State.fill = nil
	-- hand the surface back to whichever displaced status is still running
	for other in pairs(State.displaced) do
		local rec = State.active[other]
		if rec and rec.resume then
			State.displaced[other] = nil
			State.fill = other
			State.fillSince = os.clock()
			rec.resume()
			break
		end
	end
	refreshChips()
end

----------------------------------------------------------------------------------------------------
-- 01 · BURNING
----------------------------------------------------------------------------------------------------
local function startBurning(opts)
	local crest = img(barLayer, Art.Burn.Crest[1], { Name = "BurnCrest", ZIndex = 7 })
	-- SCORCHING LASH'S STACKS (2026-09-23) show as "x2" / "x3" on the crest's right end. The count is read from
	-- rec.stacks every frame, and R.Apply refreshes rec.stacks from RX_Burning_Stacks. A single stack adds nothing,
	-- because a plain burn already is one stack. The count goes as soon as the stacks drop, even while an Immolate
	-- burn is still holding the crest up.
	local stackText = inkText(barLayer, { Name = "BurnStacks", ZIndex = 8, AnchorPoint = Vector2.new(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Bottom })
	local rec = { conns = {}, parts = { crest, stackText }, kind = "Burning" }
	local frame, acc, embAcc = 1, 0, 0
	local hidden = false

	rec.suppress = function() hidden = true; crest.Visible = false; stackText.Visible = false end
	rec.resume = function() hidden = false end

	rec.conns[#rec.conns + 1] = RunService.RenderStepped:Connect(function(dt)
		local pos, size = surfaceRect("HealthBar")
		if not pos or hidden then crest.Visible = false; stackText.Visible = false; return end
		local w = size.X
		local h = math.floor(w * (Art.Meta.CrestH / Art.Meta.CrestW))
		crest.Visible = true
		crest.Size = UDim2.fromOffset(w, h)
		-- the crest HUGS the top edge: its baseline sits a few px inside the bar
		crest.Position = UDim2.fromOffset(pos.X, pos.Y - h + math.floor(size.Y * 0.30))

		-- The count is sized off the crest, so it grows and shrinks with the HUD. It sits just above the bar at the
		-- right end, which keeps it clear of the HP numerals (inside the bar, on the left) and of the BurnTick
		-- bursts (beside the bar, on the right).
		local n = rec.stacks
		if type(n) == "number" and n >= 2 then
			local ts = math.clamp(math.floor(h * 0.42), 14, 34)
			stackText.Visible = true
			stackText.Text = "x" .. math.floor(n)
			stackText.TextSize = ts
			stackText.Size = UDim2.fromOffset(ts * 2, ts)
			stackText.Position = UDim2.fromOffset(pos.X + w - math.floor(ts * 0.3), pos.Y - 2)
		else
			stackText.Visible = false
		end

		acc += dt
		if acc >= 1 / T.CrestFPS then
			acc = 0
			frame = frame % #Art.Burn.Crest + 1
			crest.Image = Art.Burn.Crest[frame]
		end

		embAcc += dt
		if embAcc >= T.EmberEvery then
			embAcc = 0
			local id = Art.Burn.Ember[math.random(1, #Art.Burn.Ember)]
			local e = img(barLayer, id, {
				Visible = true, ZIndex = 6,
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromOffset(pos.X + math.random(0, w), pos.Y - h * 0.4),
			})
			local up = math.random(60, 110)
			TweenService:Create(e, TweenInfo.new(T.EmberRise, Enum.EasingStyle.Sine),
				{ Position = e.Position - UDim2.fromOffset(math.random(-24, 24), up),
				  ImageTransparency = 1, Size = UDim2.fromOffset(6, 6) }):Play()
			task.delay(T.EmberRise + 0.05, function() e:Destroy() end)
		end
	end)
	return rec
end

----------------------------------------------------------------------------------------------------
-- 01 · CHILLED -> FROZEN
----------------------------------------------------------------------------------------------------
local function startChilled(opts)
	local crust = img(barLayer, Art.Chill.Crust[1], { Name = "ChillCrust", ZIndex = 7,
		ImageTransparency = 0.14 })
	local rec = { conns = {}, parts = { crust }, kind = "Chilled" }
	local hidden = false
	rec.suppress = function() hidden = true; crust.Visible = false end
	rec.resume = function() hidden = false end

	rec.conns[#rec.conns + 1] = RunService.RenderStepped:Connect(function()
		local pos, size = surfaceRect("HealthTrough")
		if not pos or hidden then crust.Visible = false; return end
		crust.Visible = true
		crust.Position = UDim2.fromOffset(pos.X, pos.Y)
		crust.Size = UDim2.fromOffset(size.X, size.Y)
		-- the third stack is the deepest slow (2026-10-08): its own crust stage drawn nearly solid. Never the fourth
		-- stage for it -- that art has FROZEN! lettered in, and FROZEN! is kept for real freezes
		local stacks = math.clamp(rec.stacks or 1, 1, #Art.Chill.Crust)
		crust.Image = Art.Chill.Crust[stacks]
		crust.ImageTransparency = (stacks == 3) and 0 or 0.14
	end)
	return rec
end

----------------------------------------------------------------------------------------------------
-- 01 · POISONED
----------------------------------------------------------------------------------------------------
local function startPoisoned(opts)
	local ov = img(barLayer, Art.Poison.Overlay, { Name = "Acid", ZIndex = 7,
		ImageTransparency = 0.18 })
	local rec = { conns = {}, parts = { ov }, kind = "Poisoned" }
	local acc, hidden = 0, false
	rec.suppress = function() hidden = true; ov.Visible = false end
	rec.resume = function() hidden = false end

	rec.conns[#rec.conns + 1] = RunService.RenderStepped:Connect(function(dt)
		local pos, size = surfaceRect("HealthTrough")
		if not pos or hidden then ov.Visible = false; return end
		ov.Visible = true
		ov.Position = UDim2.fromOffset(pos.X, pos.Y)
		ov.Size = UDim2.fromOffset(size.X, size.Y)
		acc += dt
		if acc >= T.BubbleEvery then
			acc = 0
			local b = img(barLayer, Art.Poison.Bubble[math.random(1, #Art.Poison.Bubble)], {
				Visible = true, ZIndex = 6, Size = UDim2.fromOffset(16, 16),
				Position = UDim2.fromOffset(pos.X + math.random(0, size.X), pos.Y),
			})
			TweenService:Create(b, TweenInfo.new(0.9, Enum.EasingStyle.Sine),
				{ Position = b.Position - UDim2.fromOffset(math.random(-10, 10), math.random(40, 70)),
				  ImageTransparency = 1 }):Play()
			task.delay(0.95, function() b:Destroy() end)
		end
	end)
	return rec
end

----------------------------------------------------------------------------------------------------
-- 01 · SHOCKED
----------------------------------------------------------------------------------------------------
local function startShocked(opts)
	local arc = img(barLayer, Art.Shock[1], { Name = "Shock", ZIndex = 7 })
	local rec = { conns = {}, parts = { arc }, kind = "Charged" }
	local acc, frame, hidden = 0, 1, false
	rec.suppress = function() hidden = true; arc.Visible = false end
	rec.resume = function() hidden = false end
	rec.conns[#rec.conns + 1] = RunService.RenderStepped:Connect(function(dt)
		local pos, size = surfaceRect("HealthTrough")
		if not pos or hidden then arc.Visible = false; return end
		arc.Visible = true
		arc.Position = UDim2.fromOffset(pos.X, pos.Y)
		arc.Size = UDim2.fromOffset(size.X, size.Y)
		acc += dt
		if acc >= 1 / T.ShockFPS then
			acc = 0
			frame = frame % #Art.Shock + 1
			arc.Image = Art.Shock[frame]
		end
	end)
	return rec
end

----------------------------------------------------------------------------------------------------
-- 01 · SHIELDED  (+ R2 zone-warning relocation)
----------------------------------------------------------------------------------------------------
local function startShielded(opts)
	local ring = img(barLayer, Art.Shield.Ring[1], { Name = "ShieldRing", ZIndex = 4 })
	local glow = img(barLayer, Art.Shield.ZoneGlow, { Name = "ZoneGlow", ZIndex = 3,
		ImageColor3 = Color3.fromRGB(228, 37, 31) })
	local rec = { conns = {}, parts = { ring, glow }, kind = "Shielded" }
	local acc, frame = 0, 1
	State.shield = rec

	rec.conns[#rec.conns + 1] = RunService.RenderStepped:Connect(function(dt)
		local pos, size = surfaceRect("HealthBar")
		if not pos then ring.Visible = false; glow.Visible = false; return end
		local pad = math.floor(size.Y * 0.30)
		local rx, ry = pos.X - pad, pos.Y - pad
		local rw, rh = size.X + pad * 2, size.Y + pad * 2
		ring.Visible = true
		ring.Position = UDim2.fromOffset(rx, ry)
		ring.Size = UDim2.fromOffset(rw, rh)
		acc += dt
		if acc >= 1 / T.RingFPS then
			acc = 0
			frame = frame % #Art.Shield.Ring + 1
			ring.Image = Art.Shield.Ring[frame]
		end
		-- R2: with a shield up the zone warning rides the RING, not the bar border
		if State.zoneWarning then
			glow.Visible = true
			local g = math.floor(pad * 0.55)
			glow.Position = UDim2.fromOffset(rx - g, ry - g)
			glow.Size = UDim2.fromOffset(rw + g * 2, rh + g * 2)
			glow.ImageTransparency = 0.25 + 0.35 * math.abs(math.sin(os.clock() * 7))
		else
			glow.Visible = false
		end
	end)
	return rec
end

local function shatterShield()
	local pos, size = surfaceRect("HealthBar")
	if not pos then return end
	for i = 1, #Art.Shield.Frag do
		local f = img(barLayer, Art.Shield.Frag[i], {
			Visible = true, ZIndex = 9, Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(pos.X + math.random(0, size.X), pos.Y + math.random(0, size.Y)),
			Rotation = math.random(0, 360),
		})
		TweenService:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = f.Position + UDim2.fromOffset(math.random(-120, 120), math.random(-110, -40)),
			  ImageTransparency = 1, Rotation = f.Rotation + math.random(-160, 160) }):Play()
		task.delay(0.6, function() f:Destroy() end)
	end
end

----------------------------------------------------------------------------------------------------
-- 03 · SCREEN-WIDE  (R3 edge arbitration, R4 line arbitration)
----------------------------------------------------------------------------------------------------
-- SCREEN-WIDE TREATMENTS REMOVED (owner, 2026-09-24: "remove the anime lines on screen and ... screen covering"): no
-- vignette edges, no haste speed lines, no knockback / pull fans, no MARKED! or cleanse burst across the view. Everything
-- this script draws now sits on the HUD's own surfaces. The edge kinds still record State.edge, for the status HUD to read.

--- PRIMED's fuse (2026-09-23), read straight off the watched body. Returns how far along the fuse is (0 at the mark,
--- 1 at the explosion) and the seconds left. RX_Primed_Expires is the explosion's server-time stamp, so the seconds
--- are measured against GetServerTimeNow, never os.clock. The mark's badge and the edge pulse below both use this.
--- With no Expires (the dev panel's bare flag) there are no seconds and the fuse never advances. With no Total the
--- fraction ramps over the last T.PrimedRamp seconds instead.
local function primedUrgency()
	local c = State.character
	local expires = c and c:GetAttribute("RX_Primed_Expires")
	if type(expires) ~= "number" then return 0, nil end
	local left = math.max(0, expires - workspace:GetServerTimeNow())
	local total = c:GetAttribute("RX_Primed_Total")
	if type(total) ~= "number" or total <= 0 then total = T.PrimedRamp end
	return 1 - math.clamp(left / total, 0, 1), left
end

local function refreshEdge() end        -- (screen edges removed 2026-09-24; kept so callers need no change)

----------------------------------------------------------------------------------------------------
-- 03 · PRIMED  (Pyro's Detonate mark, 2026-09-23)
----------------------------------------------------------------------------------------------------
-- A bomb on YOU. Detonate marks whoever the Pyro last hit, and after a short fuse the mark explodes, harder the
-- lower your health. All three pieces reuse art that is already uploaded; nothing new was rendered or uploaded.
--   * THE EDGE. The Marked vignette goes through R3 like any edge kind, and its pulse quickens as the fuse runs
--     down (the render loop above).
--   * THE COUNTDOWN. A badge on the chip row's line above the health bar: the Marked chip's target ring, the word
--     PRIMED, and the seconds left. It is on the BAR layer, outside R3, so a VisionDenial can take the edge without
--     hiding the timer, and Reduce Flashing does not dim it, because it is information rather than a flash.
--     Status Intensity scales it like every other bar treatment, down to nothing at 0.
--   * NO ONE-SHOT BURST. MarkedBurst has a skull and MARKED! baked in, and that is Umbra's word, not Pyro's. The
--     badge pops in the way the bursts do instead. The explosion needs nothing from here: the HUD's BurnTick "-N"
--     already fires on the health drop.
-- It clears on RX_Primed = false and leaves nothing behind: R.Clear destroys the badge with the record and drops
-- the edge. The server writes the flag LAST and clears it FIRST, so the times are always there while the flag is
-- up. They are still read off the body every frame rather than carried in opts, so a re-mark that only moves
-- RX_Primed_Expires (a clear and a re-raise in one server frame replicate as nothing) is still drawn right.
local PRIMED_LABEL = (Config.Statuses.Primed and Config.Statuses.Primed.Label) or "PRIMED"

local function startPrimed(opts)
	local badge = Instance.new("Frame")
	badge.Name = "Primed"
	badge.BackgroundTransparency = 1
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Size = UDim2.fromOffset(T.ChipSize, T.ChipSize)
	badge.ZIndex = 9
	badge.Visible = false
	badge.Parent = barLayer
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, T.ChipGap)
	layout.Parent = badge
	local pop = Instance.new("UIScale")
	pop.Scale = 0.55
	pop.Parent = badge
	img(badge, Art.StatusChip.Marked, { Name = "Chip", Visible = true, ZIndex = 9, LayoutOrder = 1,
		Size = UDim2.fromOffset(T.ChipSize, T.ChipSize) })
	inkText(badge, { Name = "Word", Visible = true, ZIndex = 10, LayoutOrder = 2, Font = Enum.Font.GothamBlack,
		Text = PRIMED_LABEL, TextSize = T.PrimedWord, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, T.ChipSize) }, 1.6)
	local count = inkText(badge, { Name = "Count", Visible = true, ZIndex = 10, LayoutOrder = 3,
		TextSize = T.PrimedCount, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, T.ChipSize),
		TextXAlignment = Enum.TextXAlignment.Left }, 2.4)
	local rec = { conns = {}, parts = { badge }, kind = "Primed" }

	State.edge.Primed = true
	TweenService:Create(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }):Play()

	rec.conns[#rec.conns + 1] = RunService.RenderStepped:Connect(function()
		local pos = surfaceRect("HealthBar")
		if not pos then badge.Visible = false; return end
		badge.Visible = true
		-- on the chip row's line, after its chips, so a displaced status and the fuse never cover each other
		badge.Position = UDim2.fromOffset(pos.X + State.chipCount * (T.ChipSize + T.ChipGap),
			pos.Y - 8 - math.floor(T.ChipSize * 0.5))
		local u, left = primedUrgency()
		-- the HUD's own countdown format (PopArtHUD's slot cooldowns), going from white to the kit red as time runs out
		count.Text = left and string.format(left >= 10 and "%d" or "%.1f", left) or ""
		count.TextColor3 = WHITE:Lerp(RED, u)
	end)
	return rec
end

----------------------------------------------------------------------------------------------------
-- one-shot pulses
----------------------------------------------------------------------------------------------------
local function popBurst(parent, image, x, y, size, life, text, textColor)
	local b = img(parent, image, {
		Visible = true, ZIndex = 12,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size * 0.55, size * 0.55),
	})
	if text then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = false
		t.TextSize = math.max(12, math.floor(size * 0.20))
		t.TextColor3 = textColor or Color3.fromRGB(228, 37, 31)
		t.Text = text
		t.ZIndex = 13
		t.Parent = b
	end
	TweenService:Create(b, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(size, size) }):Play()
	task.delay(life * 0.55, function()
		if b.Parent then
			TweenService:Create(b, TweenInfo.new(life * 0.45), { ImageTransparency = 1 }):Play()
			for _, c in ipairs(b:GetChildren()) do
				if c:IsA("TextLabel") then
					TweenService:Create(c, TweenInfo.new(life * 0.45), { TextTransparency = 1 }):Play()
				end
			end
		end
	end)
	task.delay(life + 0.1, function() b:Destroy() end)
	return b
end

----------------------------------------------------------------------------------------------------
-- public API
----------------------------------------------------------------------------------------------------
local STARTERS = {
	Burning = startBurning,
	Chilled = startChilled,
	Poisoned = startPoisoned,
	Charged = startShocked,
	-- BLESSED (Radiant, run by StatusEffects since 2026-09-24) borrows the shield ring until the status HUD gets its own art;
	-- a kind of its own, so it never switches off a Cinder Shield / Bedrock ring that RX_Shielded holds up
	Blessed = function(opts)
		local rec = startShielded(opts)
		rec.kind = "Blessed"
		return rec
	end,
	Shielded = startShielded,
	Primed = startPrimed,
}

function R.Apply(kind, opts)
	opts = opts or {}
	local fxKind = BARFX_KIND[kind]
	if fxKind and player:GetAttribute("BarFX_" .. fxKind) ~= "old" then
		if State.active[kind] then R.Clear(kind) end
		return
	end
	if STARTERS[kind] then
		if State.active[kind] then
			-- already running: just refresh its data (stack count, shield amount)
			local rec = State.active[kind]
			-- A count that the attribute driver finds GONE arrives as false and clears (2026-09-23). The lash's burn
			-- stacks drop to nil while an Immolate burn can still hold RX_Burning up, and `opts.Stacks or rec.stacks`
			-- kept the old "x3" drawn on the crest. A caller that passes no stacks at all (the legacy Status driver)
			-- still leaves them alone.
			if opts.Stacks ~= nil then rec.stacks = opts.Stacks or nil end
			rec.amount = opts.Amount or rec.amount
			return
		end
		claimFill(kind)
		local rec = STARTERS[kind](opts)
		rec.stacks = opts.Stacks or nil
		rec.amount = opts.Amount
		State.active[kind] = rec
		-- R2, the other way round: the ring takes the zone warning off the bar border. only the
		-- shield-first ordering was handled (2026-09-21), so a shield raised while the warning was
		-- already up left the border pulsing underneath the ring glow -- both treatments at once,
		-- which is the exact clash R2 exists to settle.
		if kind == "Shielded" and State.zoneWarning and R.HealthBorderPulse then
			R.HealthBorderPulse(false)
		end
		if FILL_KINDS[kind] and State.fill ~= kind then
			State.displaced[kind] = true
			if rec.suppress then rec.suppress() end
			refreshChips()
		end
		return
	end

	if EDGE_PRIORITY[kind] then
		State.edge[kind] = true
		refreshEdge()
		return
	end

	if kind == "Haste" then
		State.haste = true
	elseif kind == "ZoneWarning" then
		State.zoneWarning = true
		-- R2: with no shield up the warning belongs on the bar border, which the HUD owns
		if not State.active.Shielded and R.HealthBorderPulse then
			R.HealthBorderPulse(true)
		end
	end
end

function R.Clear(kind)
	local rec = State.active[kind]
	if rec then
		for _, c in ipairs(rec.conns) do c:Disconnect() end
		for _, p in ipairs(rec.parts) do p:Destroy() end
		State.active[kind] = nil
		if kind == "Shielded" then
			State.shield = nil
			shatterShield()
			-- R2 again: the warning has to fall back to the bar border now the ring is gone
			if State.zoneWarning and R.HealthBorderPulse then
				R.HealthBorderPulse(true)
			end
		end
		releaseFill(kind)
	end
	if EDGE_PRIORITY[kind] then
		State.edge[kind] = nil
		refreshEdge()
	end
	if kind == "Haste" then State.haste = false end
	if kind == "ZoneWarning" then
		State.zoneWarning = false
		if R.HealthBorderPulse then R.HealthBorderPulse(false) end
	end
end

function R.ClearAll()
	for kind in pairs(State.active) do R.Clear(kind) end
	for kind in pairs(State.edge) do R.Clear(kind) end
	State.haste = false
	State.zoneWarning = false
	State.displaced = {}
	refreshChips()
end

--- One-shot moments.
function R.Pulse(kind, data)
	data = data or {}
	local pos, size = surfaceRect("HealthBar")
	local cx = pos and (pos.X + size.X) or math.floor(gui.AbsoluteSize.X * 0.3)
	local cy = pos and (pos.Y + size.Y * 0.5) or math.floor(gui.AbsoluteSize.Y * 0.8)

	-- ELEMENTAL REACTIONS (2026-10-17): the reaction's word on the kit's plain burst, by the bar, in the hitting Element's ink
	if kind == "Reaction" then
		popBurst(barLayer, "rbxassetid://88718198034720", cx + 50, cy - 24, 190, 1.0, data.Word,
			typeof(data.Color) == "Color3" and data.Color or nil)
		return
	end
	if kind == "BurnTick" then
		popBurst(barLayer, Art.Burn.TickBurst, cx + 40, cy, 76, 0.45,
			data.Amount and ("-" .. tostring(data.Amount)) or nil)
	elseif kind == "Krak" then
		popBurst(barLayer, Art.Chill.Krak, cx + 20, cy - 10, 190, 0.75)
	elseif kind == "Punish" then
		popBurst(barLayer, Art.Poison.Punish, cx + 30, cy, 130, 0.65)
	elseif kind == "ShieldBreak" then
		shatterShield()
	elseif kind == "SpendSurge" then
		local mp, ms = surfaceRect("ManaTrough")
		if mp then
			local rip = img(barLayer, Art.Mana.Ripple, {
				Visible = true, ZIndex = 8,
				Size = UDim2.fromOffset(math.floor(ms.Y * (Art.Meta.RippleW / Art.Meta.RippleH)), ms.Y),
				Position = UDim2.fromOffset(mp.X - 40, mp.Y),
			})
			TweenService:Create(rip, TweenInfo.new(0.42, Enum.EasingStyle.Quad),
				{ Position = UDim2.fromOffset(mp.X + ms.X + 20, mp.Y) }):Play()
			task.delay(0.46, function() rip:Destroy() end)
		end
	elseif kind == "Ready" then
		local sp, ss = surfaceRect(data.Slot or "SlotUltimate")
		if sp then
			popBurst(barLayer, Art.Ready, sp.X + ss.X * 0.5, sp.Y + ss.Y * 0.5, 150, 0.6)
		end
	elseif kind == "DecoyPoof" then
		local pp, ps = surfaceRect("PassivePill")
		local x = pp and (pp.X - 20) or 200
		local y = pp and (pp.Y + ps.Y * 0.5) or 200
		task.spawn(function()
			for step = 1, #Art.Decoy do
				popBurst(barLayer, Art.Decoy[step], x, y, 60 + step * 26, 0.22)
				task.wait(0.07)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- self-drive from character attributes, so existing server code lights this up unchanged
----------------------------------------------------------------------------------------------------
-- SpellshotConfig.Statuses names -> reaction kinds. Anything not mapped simply has no layer-2
-- treatment yet and falls back to the HUD's own status tag.
local STATUS_TO_REACTION = {
	Burning = "Burning",
	Chilled = "Chilled",
	Rooted = "Chilled",
	Slipping = "Chilled",
	Poisoned = "Poisoned",
	Charged = "Charged",
	Blessed = "Shielded",
	Marked = "Marked",
	Blinded = "VisionDenial",
}

-- Concurrent statuses. The legacy `Status` attribute holds ONE name, which is all
-- SpellshotService needs for the floating tag -- but a player can genuinely be burning AND
-- shielded AND marked at the same time, and the whole point of the clash rules is deciding what
-- happens then. So the reaction layer also reads a set of per-kind boolean attributes,
-- `RX_<Kind>`, which the server can raise independently. Attributes replicate on their own, so
-- this needs no new remote and no change to the existing status plumbing.
local RX_PREFIX = "RX_"

local function watchReactionFlags(character)
	local function syncFlag(attrName)
		local kind = attrName:sub(#RX_PREFIX + 1)
		-- STAGGERED (Bulwark Charge's knockdown, 2026-09-18) is a ONE-SHOT here, not a sustained treatment: the
		-- moment its flag rises, the displacement fan the Knockback pulse already draws -- being knocked down IS a
		-- knockback, so it gets that shape rather than a new one. Everyone else sees the stars TerraFX draws over the
		-- staggered head from the same flag.
		if kind == "Staggered" then
			if character:GetAttribute(attrName) then R.Pulse("Knockback") end
			return
		end
		if not (STARTERS[kind] or EDGE_PRIORITY[kind] or kind == "Haste" or kind == "ZoneWarning") then
			return
		end
		local on = character:GetAttribute(attrName)
		if on then
			local elem = character:GetAttribute(attrName .. "_Element")
			-- `or false`: this driver owns the count, so a missing _Stacks means "none" and clears it (see R.Apply)
			R.Apply(kind, { Element = elem, Stacks = character:GetAttribute(attrName .. "_Stacks") or false,
				Amount = character:GetAttribute(attrName .. "_Amount") })
		else
			R.Clear(kind)
		end
	end
	character.AttributeChanged:Connect(function(name)
		if name:sub(1, #RX_PREFIX) ~= RX_PREFIX then return end
		-- a second or third chill stack only moves RX_Chilled_Stacks: RX_Chilled is re-set to the
		-- same true, which fires nothing. the suffixes were skipped outright (2026-09-21), so the
		-- frost crust kept whatever stage it had when the chill first rose. a suffix change now
		-- re-syncs its parent flag, and R.Apply's already-running branch picks up the new count.
		-- PRIMED's _Expires / _Total / _By (2026-09-23) need no re-sync, because its badge and edge pulse read
		-- them off the body every frame. A change to one of them reaches syncFlag as a kind such as
		-- "Primed_Expires", which the filter drops.
		local base = name:match("^(.-)_Stacks$") or name:match("^(.-)_Amount$")
		if base then
			if character:GetAttribute(base) then syncFlag(base) end
			return
		end
		if not name:find("_Element") then
			syncFlag(name)
		end
	end)
	for name in pairs(character:GetAttributes()) do
		if name:sub(1, #RX_PREFIX) == RX_PREFIX and not name:find("_Element")
			and not name:find("_Stacks") and not name:find("_Amount") then
			syncFlag(name)
		end
	end
end

local watched
local function watchCharacter(character)
	if watched == character then return end
	watched = character
	State.character = character
	R.ClearAll()
	watchReactionFlags(character)

	local last
	local function sync()
		local name = character:GetAttribute("Status")
		local kind = name and STATUS_TO_REACTION[name] or nil
		if kind == last then return end
		-- G1 (2026-09-23): the legacy name never clears a kind that its own RX_ flag still holds up. `Status` carries
		-- ONE name and the newest wins. So a Chill hit, or an Immolate tag running out, used to wipe a live burn
		-- crest while RX_Burning stayed true, and because the flag never changed, nothing put the crest back.
		-- RX_Burning now has two writers (the Immolate / Ring burn and Scorching Lash's stacks), which makes that
		-- the common case. When the flag does drop, the RX_ driver clears the kind itself.
		if last and not character:GetAttribute(RX_PREFIX .. last) then R.Clear(last) end
		last = kind
		if kind then
			local def = Config.Statuses[name]
			R.Apply(kind, { Element = def and def.Element })
		end
	end
	character:GetAttributeChangedSignal("Status"):Connect(sync)
	character:GetAttributeChangedSignal("StatusExpires"):Connect(sync)
	sync()
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(function(c) task.defer(watchCharacter, c) end)

-- a BarFX pick changed (dev panel): take the status away from this layer, or hand it back, right now
player.AttributeChanged:Connect(function(name)
	local fxKind = name:match("^BarFX_(%w+)$")
	if not fxKind then return end
	local c = State.character
	for rxKind, k in pairs(BARFX_KIND) do
		if k == fxKind then
			if c and c:GetAttribute("RX_" .. rxKind) then
				R.Apply(rxKind, { Element = c:GetAttribute("RX_" .. rxKind .. "_Element"),
					Stacks = c:GetAttribute("RX_" .. rxKind .. "_Stacks") or false, Amount = c:GetAttribute("RX_" .. rxKind .. "_Amount") })
			elseif State.active[rxKind] then
				R.Clear(rxKind)
			end
		end
	end
end)

_G.SpellshotReactions = R
return nil
