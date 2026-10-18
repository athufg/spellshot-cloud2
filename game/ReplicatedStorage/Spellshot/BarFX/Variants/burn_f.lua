--!nocheck
-- River of Fire: the HP fill becomes a scrolling river of flame inside a hot iron rim, spilling out above the bar.
-- Ported from status_fx/bench/opts/burn-f.html (round 2, 2026-09-24).
local V = { title = "River of Fire" }

local HOT = Color3.fromRGB(255, 247, 214)      -- #FFF7D6 white-hot
local FW, FH, FAY = 56 / 40, 74 / 64, 72 / 74  -- flame sprite box vs the 40x64 flame box, and where its bottom sits

function V.mount(fx)
	local C = fx.C
	local hex = function(h) return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end

	-- ------------------------------------------------------------------ shared helpers (flames, bursts, word)
	-- a flame whose 40x64 box is w x h, bottom-centre pivot at (px, py), rotated about that pivot like CSS origin 50% 100%
	local function placeFlame(img, px, py, w, h, rot)
		if w < 0.5 or h < 0.5 then img.Visible = false return end
		img.Visible = true
		local SW, SH = w * FW, h * FH
		local cy = SH * (0.5 - FAY)
		local r = math.rad(rot or 0)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = fx.P(px - cy * math.sin(r), py + cy * math.cos(r))
		img.Size = fx.S(SW, SH)
		img.Rotation = rot or 0
	end
	local flames = {}
	local function newFlame(parent, outer, z, seed)
		local f = { outer = outer, core = "y", names = {} }
		for i = 1, 3 do f.names[i] = "burn-s/flame_" .. outer .. "y_" .. (i - 1) end
		f.img = fx.sprite(parent, f.names[1], { z = z, visible = false })
		f.flip = fx.flip(f.img, f.names, 10, fx.rand(seed) * 0.3)
		flames[#flames + 1] = f
		return f
	end
	local function setCore(f, core)
		if f.core == core then return end
		f.core = core
		for i = 1, 3 do f.names[i] = "burn-s/flame_" .. f.outer .. core .. "_" .. (i - 1) end
		f.flip.last = nil
	end
	-- spike bursts: burst .3s: scale .3 -> 1.2 -> 0, rotate 0 -> 15 -> 30, stepped
	local SP = 108 / 100
	local function newBurst(size)
		return { img = fx.sprite(fx.front, "burn-s/spike", { z = 27, visible = false }), size = size, born = -1 }
	end
	local function stepBurst(b)
		local e = (fx.clock - b.born) / 0.3
		if b.born < 0 or e >= 1 then b.img.Visible = false return end
		local q = math.floor(e * 8) / 8
		local sc, rot
		if q < 0.5 then sc, rot = 0.3 + 0.9 * (q / 0.5), 15 * (q / 0.5)
		else sc, rot = 1.2 - 1.2 * ((q - 0.5) / 0.5), 15 + 15 * ((q - 0.5) / 0.5) end
		b.img.Visible = sc > 0.01
		b.img.AnchorPoint = Vector2.new(0.5, 0.5)
		b.img.Position = fx.P(b.x, b.y)
		b.img.Size = fx.S(b.size * SP * sc, b.size * SP * sc)
		b.img.Rotation = rot
	end
	-- the lettered word: pop .35s steps(5): .2/-20deg -> 1.25/8 -> .95/-3 -> 1/0; stays until the next stack or the end
	local word, wordScale, wordBorn
	local POP = { { 0, 0.2, -20 }, { 0.4, 1.25, 8 }, { 0.7, 0.95, -3 }, { 1, 1, 0 } }
	local function popAt(q)
		for i = 1, #POP - 1 do
			local a, b = POP[i], POP[i + 1]
			if q <= b[1] then
				local u = (q - a[1]) / (b[1] - a[1])
				return fx.lerp(a[2], b[2], u), fx.lerp(a[3], b[3], u)
			end
		end
		return 1, 0
	end
	local function popWord(text, x, y, w, h, burstColor, textRot)
		if word then word:Destroy() end
		local holder, label = fx.word(fx.front, text, { x = x, y = y, size = 28, color = C.pyroY, stroke = 6,
			burst = "burn-s/spike", burstColor = burstColor, burstW = w * SP, burstH = h * SP, pop = false, z = 28 })
		label.Rotation = textRot
		word, wordScale, wordBorn = holder, holder:FindFirstChildOfClass("UIScale"), fx.clock
	end
	local function stepWord()
		if not (word and word.Parent) then return end
		local q = math.min(1, math.floor((fx.clock - wordBorn) / 0.35 * 5) / 5)
		local sc, rot = popAt(q)
		wordScale.Scale = sc
		word.Rotation = rot
	end
	-- embers: diamonds rising 64 px and turning 180deg in 1.1 s, 9 steps
	local embers = {}
	local function newEmber(x, y, dx, delay, period, rise, steps)
		local r = fx.rect(fx.front, { x = x, y = y, w = 5, h = 5, anchor = Vector2.new(0.5, 0.5), color = C.pyroY, stroke = 2.5, rotation = 45, z = 26, visible = false })
		embers[#embers + 1] = { r = r, x = x, y = y, dx = dx, delay = delay, period = period, rise = rise, steps = steps }
	end
	local function stepEmbers(on)
		for _, e in ipairs(embers) do
			e.r.Visible = on
			if on then
				local ph = ((fx.clock + e.delay) / e.period) % 1
				local p = math.floor(ph * e.steps) / e.steps
				e.r.Position = fx.P(e.x + 4.5 + e.dx * p, e.y + 4.5 - e.rise * p)
				e.r.Rotation = 45 + 180 * p
			end
		end
	end
	local hitUntil = -1

	-- ------------------------------------------------------------------ charred bar, hot chip
	fx.restyle("bar", { BackgroundColor3 = hex("2E120A") })
	fx.restyle("fill", { BackgroundColor3 = C.pyro })
	fx.restyle("label", { TextColor3 = C.pyroL })
	fx.restyle("chip", { BackgroundColor3 = C.pyro })
	fx.restyle("glyph", { ImageTransparency = 1 })
	local cx, cy, cw, ch = fx.chipRect()
	local heart = fx.sprite(fx.front, "burn-f/heart", { x = cx + cw / 2, y = cy + ch / 2, w = cw * 38 / 64, h = ch * 38 / 64,
		anchor = Vector2.new(0.5, 0.5), color = C.pyroY, z = 22, visible = false })
	local emptyDots = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = hex("7A240C"), alpha = 1, pitch = 7, z = 1 })

	-- the hot iron rim (the bench's box-shadow rings): pyro ring 2+4t+3hit, ink ring 5+4t+3hit, ink drop 4,4 spread 5+4t
	local rimShadow = fx.rect(fx.back, { x = 100, y = 112, w = 400, h = 56, color = C.ink, corner = "pill", z = 7, visible = false })
	local rimInk = fx.rect(fx.back, { x = 100, y = 112, w = 400, h = 56, color = C.ink, corner = "pill", z = 8, visible = false })
	local rimHot = fx.rect(fx.back, { x = 100, y = 112, w = 400, h = 56, color = C.pyro, corner = "pill", z = 9, visible = false })
	local function ring(f, e, ox, oy)
		f.Position = fx.P(100 - e + ox, 112 - e + oy)
		f.Size = fx.S(400 + 2 * e, 56 + 2 * e)
	end

	-- a horizontally tiled lick strip that scrolls right-to-left in steps: holder (anchored bottom) + n copies
	local function strip(parent, name, W, H, n, sp, steps, z)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.ZIndex = z
		holder.Visible = false
		holder.Parent = parent
		for j = 1, n do
			local img = fx.sprite(holder, name, {})
			img.Size = UDim2.fromScale(1 / n, 1)
			img.Position = UDim2.fromScale((j - 1) / n, 0)
		end
		return { f = holder, W = W, H = H, n = n, sp = sp, steps = steps }
	end
	local function flowOff(L)
		local ph = (fx.clock / L.sp) % 1
		return -L.W * math.floor(ph * L.steps) / L.steps
	end

	-- INSIDE (fx.fill, clipped to the HP width): the river
	local riverBase = fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.pyro, z = 1, visible = false })
	local riverDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.red, alpha = 1, pitch = 7, z = 2 })
	local L1 = strip(fx.fill, "burn-f/l1", 240, 52, 3, 1.6, 16, 3)
	local L2 = strip(fx.fill, "burn-f/l2", 300, 40, 3, 1.1, 11, 4)
	local L3 = strip(fx.fill, "burn-f/l3", 150, 24, 4, 0.8, 8, 5)
	local wave = fx.sprite(fx.fill, "burn-f/wave", { x = 0, y = 140, w = 44.2, h = 56, anchor = Vector2.new(0.5, 0.5), z = 6, visible = false })
	local riverEdge = fx.rect(fx.fill, { x = 493, y = 116, w = 3, h = 48, color = C.ink, z = 7, visible = false })

	-- BACK: the crown of fire spilling out of the fill's top edge, as long as the fill
	local crownClip = Instance.new("Frame")
	crownClip.BackgroundTransparency = 1
	crownClip.ClipsDescendants = true
	crownClip.ZIndex = 6
	crownClip.Visible = false
	crownClip.Position = fx.P(104, 40)
	crownClip.Size = fx.S(392, 84)
	crownClip.Parent = fx.back
	local crownIn = Instance.new("Frame")        -- always 392 x 84 design, whatever the clip's width
	crownIn.BackgroundTransparency = 1
	crownIn.Size = UDim2.fromScale(1, 1)
	crownIn.Parent = crownClip
	local CR = strip(crownIn, "burn-f/crown", 300, 84, 3, 1.4, 14, 1)

	-- FRONT: the leading-edge flame
	local edge = newFlame(fx.front, "o", 24, 77)
	for i = 0, 4 do
		newEmber(110 + i * 12, 84 + (i * 23) % 30, ((i % 2 == 1) and 1 or -1) * (6 + i * 3), i * 0.29, 1.1, 64, 9)
	end
	local bursts = { newBurst(60), newBurst(60) }
	local bi = 0
	local WORDS = { "SIZZLE!", "SCORCH!", "INFERNO!" }
	local waveBorn = -1

	local self = {}
	function self.event(name, st)
		if name == "stack" or name == "on" then
			popWord(WORDS[math.clamp(st.s, 1, 3)], 235, 57, 170, 78, C.pyro, -5)
		elseif name == "tick" or name == "hit" then
			hitUntil = fx.clock + 0.25
			if name == "tick" then
				waveBorn = fx.clock
				bi += 1
				local b = bursts[(bi - 1) % 2 + 1]
				b.x = 104 + math.clamp(st.hp, 0, 1) * 392
				b.y = 118 + (bi % 2) * 30
				b.img.ImageColor3 = st.s >= 3 and HOT or C.pyroY
				b.born = fx.clock
			end
		elseif name == "end" then
			if word then word:Destroy() word = nil end
		end
	end

	function self.update(st, dt)
		local on = st.on and 1 or 0
		local s, t, hp = st.s, st.t, math.clamp(st.hp, 0.01, 1)
		local hit = fx.clock < hitUntil and 1 or 0
		local s2, s3 = s >= 2 and 1 or 0, s >= 3 and 1 or 0
		local fw = 392 * hp
		heart.Visible = st.on
		emptyDots.Visible = st.on and hp < 0.999
		emptyDots.Position = fx.P(104 + fw, 116)
		emptyDots.Size = fx.S(math.max(1, 392 - fw), 48)
		emptyDots.TileSize = UDim2.fromScale(7 / math.max(1, 392 - fw), 7 / 48)
		-- rim
		rimShadow.Visible, rimInk.Visible, rimHot.Visible = st.on, st.on, st.on
		ring(rimShadow, 5 + 4 * t, 4, 4)
		ring(rimInk, 5 + 4 * t + 3 * hit, 0, 0)
		ring(rimHot, 2 + 4 * t + 3 * hit, 0, 0)
		-- river
		riverBase.Visible, riverDots.Visible, riverEdge.Visible = st.on, st.on, st.on
		riverEdge.Position = fx.P(104 + fw - 3, 116)
		local function layer(L, sy)
			L.f.Visible = st.on and sy > 0.01
			L.f.Position = fx.P(104 + flowOff(L), 166)
			L.f.Size = fx.S(L.W * L.n, L.H * math.max(sy, 0.01))
		end
		layer(L1, (0.5 + 0.17 * s) * (0.55 + 0.45 * t) * (1 + 0.2 * hit))
		layer(L2, s2 * (0.7 + 0.3 * s3) * (0.5 + 0.5 * t) * (1 + 0.3 * hit))
		layer(L3, s3 * (0.4 + 0.6 * t) * (1 + 0.4 * hit))
		local we = (fx.clock - waveBorn) / 0.3
		wave.Visible = st.on and waveBorn >= 0 and we < 1
		if wave.Visible then
			local tx = -60 + 480 * math.floor(we * 6) / 6
			wave.Position = fx.P(104 + tx + 13, 140)
		end
		-- crown (behind the bar, as long as the fill)
		local csy = math.max(0, 0.33 * s - 0.13) * (0.45 + 0.55 * t) * (1 + 0.25 * hit)
		crownClip.Visible = st.on and csy > 0.01
		crownClip.Size = fx.S(fw, 84)
		crownIn.Size = UDim2.fromScale(1 / hp, 1)
		CR.f.Visible = true
		CR.f.Position = UDim2.fromScale(flowOff(CR) / 392, 86 / 84)
		CR.f.Size = UDim2.fromScale(CR.W * CR.n / 392, 84 * math.max(csy, 0.01) / 84)
		-- leading-edge flame
		local esy = on * (0.45 + 0.18 * s) * (0.55 + 0.45 * t) * (1 + 0.25 * hit)
		placeFlame(edge.img, 104 + fw, 172, 68 * on, 124 * esy, 0)
		local core = s >= 3 and "w" or "y"
		for _, f in ipairs(flames) do setCore(f, core) end
		for i, e in ipairs(embers) do e.x = 110 + (i - 1) * 12 + hp * (i - 1) * 70 end
		stepEmbers(st.on)
		for _, b in ipairs(bursts) do stepBurst(b) end
		if not st.on and word then word:Destroy() word = nil end
		stepWord()
	end

	function self.destroy()
		if word then word:Destroy() word = nil end
	end
	return self
end

return V
