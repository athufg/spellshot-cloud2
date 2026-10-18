--!nocheck
-- Wall of Fire: a two-row wall of flame rises behind the bar, wraps both ends and licks over its front edge.
-- Ported from status_fx/bench/opts/burn-a.html (round 2, 2026-09-24).
local V = { title = "Wall of Fire" }

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

	-- ------------------------------------------------------------------ the scorched bar
	fx.restyle("bar", { BackgroundColor3 = hex("3A160C") })
	fx.restyle("fill", { BackgroundColor3 = C.red })
	fx.restyle("label", { TextColor3 = C.pyroL })
	fx.restyle("chip", { BackgroundColor3 = C.pyroY })
	local fillDots = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = C.pyro, alpha = 1, pitch = 7, z = 1 })
	local emptyDots = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = hex("8A2A0E"), alpha = 1, pitch = 7, z = 1 })
	-- the flame band licking up inside the bar, over the fill
	local band = fx.sprite(fx.bar, "burn-a/band", { x = 300, y = 168, w = 404, h = 40, anchor = Vector2.new(0.5, 1), z = 3, visible = false })
	local BOIL = { { 1, 1 }, { 1.06, 0.92 }, { 0.94, 1.07 } }

	-- BACK: the fire wall. Deepest row: 8 tall dark-red tongues; main row: 13 licks; two big end wraps
	local wall = {}
	for i = 0, 7 do
		local f = newFlame(fx.back, "d", 6, 100 + i)
		f.x, f.y, f.w, f.h, f.hf, f.rot = 128 + i * 50, 150, 64, 124, (i % 2 == 1) and 0.9 or 1.05, 0
		wall[#wall + 1] = f
	end
	local HF = { 1, 0.72, 0.95, 0.8, 1.08, 0.7, 0.98, 0.78, 1.05, 0.74, 0.96, 0.82, 1 }
	for i = 0, 12 do
		local f = newFlame(fx.back, (i % 2 == 1) and "r" or "o", 7, 200 + i)
		f.x, f.y, f.w, f.h, f.hf, f.rot = 104 + i * 32.6, 158, 58, 104, HF[i + 1], 0
		wall[#wall + 1] = f
	end
	for _, e in ipairs({ { 90, -38 }, { 512, 38 } }) do
		local f = newFlame(fx.back, "o", 8, 300 + e[1])
		f.x, f.y, f.w, f.h, f.hf, f.rot = e[1], 172, 70, 112, 0.95, e[2]
		wall[#wall + 1] = f
	end
	-- FRONT: licks crossing over the bar's lower edge (clear of the HP number), and a lean at the right end
	for i, x in ipairs({ 214, 262, 318, 366, 420, 470 }) do
		local k = i - 1
		local f = newFlame(fx.front, "o", 24, 400 + k)
		f.x, f.y, f.w, f.h, f.hf, f.rot = x, 184, 34 + (k % 2) * 8, 46 + (k % 3) * 8, 1.25, 0
		wall[#wall + 1] = f
	end
	do
		local f = newFlame(fx.front, "o", 24, 499)
		f.x, f.y, f.w, f.h, f.hf, f.rot = 504, 186, 44, 64, 1.3, 24
		wall[#wall + 1] = f
	end
	for i = 0, 5 do
		newEmber(140 + i * 64, 70 + (i * 37) % 40, ((i % 2 == 1) and 1 or -1) * (8 + i * 2), i * 0.37, 1.2, 70, 10)
	end
	local bursts = { newBurst(64), newBurst(64), newBurst(64) }
	local bi = 0
	local WORDS = { "BURN!", "BURN x2", "FWOOSH!" }
	local ticks = 0

	local self = {}
	function self.event(name, st)
		if name == "stack" or name == "on" then
			popWord(WORDS[math.clamp(st.s, 1, 3)], 459, 62, 150, 80, C.red, -6)
			fx.shake(3, 0.24)
		elseif name == "tick" or name == "hit" then
			hitUntil = fx.clock + 0.25
			if name == "tick" then
				ticks += 1
				bi += 1
				local b = bursts[(bi - 1) % 3 + 1]
				b.x = 130 + fx.rand(ticks * 13 + 1) * 360
				b.y = 108 + fx.rand(ticks * 17 + 5) * 8
				b.img.ImageColor3 = st.s >= 3 and HOT or C.pyroY
				b.born = fx.clock
				if st.s >= 2 then fx.shake(3, 0.24) end
			end
		elseif name == "end" then
			if word then word:Destroy() word = nil end
		end
	end

	function self.update(st, dt)
		local on = st.on and 1 or 0
		local s, t, hp = st.s, st.t, math.clamp(st.hp, 0.01, 1)
		local hit = fx.clock < hitUntil and 1 or 0
		local fw = 392 * hp
		fillDots.Visible = st.on
		fillDots.Size = fx.S(fw, 48)
		fillDots.TileSize = UDim2.fromScale(7 / fw, 7 / 48)
		emptyDots.Visible = st.on and hp < 0.999
		emptyDots.Position = fx.P(104 + fw, 116)
		emptyDots.Size = fx.S(math.max(1, 392 - fw), 48)
		emptyDots.TileSize = UDim2.fromScale(7 / math.max(1, 392 - fw), 7 / 48)
		-- inner band: scaleY on*(.35+.2s)*(.5+.5t)*(1+.3hit), boiling
		local bsy = on * (0.35 + 0.2 * s) * (0.5 + 0.5 * t) * (1 + 0.3 * hit)
		local bb = BOIL[math.floor(fx.clock * 10) % 3 + 1]
		band.Visible = bsy > 0.01
		band.Size = fx.S(404 * bb[1], 40 * bsy * bb[2])
		-- every lick: scale(on*w, on*hf*(.3+.23s)*(.45+.55t)*(1+.22hit))
		local sy = on * (0.3 + 0.23 * s) * (0.45 + 0.55 * t) * (1 + 0.22 * hit)
		for _, f in ipairs(wall) do
			placeFlame(f.img, f.x, f.y, f.w * on, f.h * f.hf * sy, f.rot)
		end
		local core = s >= 3 and "w" or "y"
		for _, f in ipairs(flames) do setCore(f, core) end
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
