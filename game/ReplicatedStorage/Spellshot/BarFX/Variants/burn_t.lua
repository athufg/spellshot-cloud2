--!nocheck
-- Burning Log: the whole health bar turns into a burning charcoal log that splits open on every stack.
-- Ported from status_fx/bench/opts/burn-t.html (round 2, 2026-09-24).
local V = { title = "Burning Log" }

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

	-- ------------------------------------------------------------------ the log
	fx.restyle("bar", { BackgroundColor3 = C.pyroD })          -- charcoal where HP is gone
	fx.restyle("fill", { BackgroundColor3 = C.pyro })          -- the molten core
	fx.restyle("label", { TextColor3 = C.pyroL })
	local fillDots = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = C.pyroY, alpha = 1, pitch = 8, z = 1 })
	local emptyDots = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = hex("A8300E"), alpha = 1, pitch = 7, z = 1 })
	local seam = fx.sprite(fx.bar, "burn-t/seam", { x = 104, y = 116, w = 392, h = 48, color = C.pyroY, z = 2, visible = false })
	local crustT = fx.sprite(fx.bar, "burn-t/crust_top", { x = 100, y = 112, w = 400, h = 36, z = 3, visible = false })
	local crustB = fx.sprite(fx.bar, "burn-t/crust_bot", { x = 100, y = 132, w = 400, h = 36, z = 3, visible = false })
	local cracksT, cracksB = {}, {}
	for n = 1, 3 do
		cracksT[n] = fx.sprite(fx.bar, "burn-t/ck_top" .. n, { x = 100, y = 112, w = 400, h = 36, color = C.pyroY, z = 4, visible = false })
		cracksB[n] = fx.sprite(fx.bar, "burn-t/ck_bot" .. n, { x = 100, y = 132, w = 400, h = 36, color = C.pyroY, z = 4, visible = false })
	end

	-- the coal chip
	local cx, cy, cw, ch = fx.chipRect()
	local u = cw / 64
	local coal = fx.rect(fx.front, { x = cx + 4 * u, y = cy + 4 * u, w = cw - 8 * u, h = ch - 8 * u, color = C.pyroD, corner = 10 * u, stroke = 4 * u, z = 22, visible = false })
	coal.ClipsDescendants = true
	local coalDots = fx.dots(coal, { w = 56, h = 56, color = hex("A8300E"), alpha = 1, pitch = 7 })
	coalDots.Position = UDim2.fromScale(0, 0)
	coalDots.Size = UDim2.fromScale(1, 1)
	local coalFlame = newFlame(coal, "o", 2, 99)
	coalFlame.img.Visible = true
	coalFlame.img.AnchorPoint = Vector2.new(0.5, FAY)
	coalFlame.img.Position = UDim2.fromScale((6 + 22) / 56, (2 + 54) / 56)
	coalFlame.img.Size = UDim2.fromScale(44 * FW / 56, 54 * FH / 56)
	coalFlame.fixed = true

	-- flames along the top of the log, rooted in the crust line, and one at each end
	local HF = { 0.8, 1.1, 0.7, 1, 0.85, 1.15, 0.75, 1.05, 0.9, 0.8 }
	local tops = {}
	for i = 0, 9 do
		local f = newFlame(fx.front, (i % 3 == 1) and "r" or "o", 24, i + 1)
		f.x, f.y, f.w, f.h, f.hf, f.rot = 150 + i * 36, 119, 34, 58, HF[i + 1], 0
		tops[#tops + 1] = f
	end
	for _, e in ipairs({ { 110, -30 }, { 498, 30 } }) do
		local f = newFlame(fx.front, "o", 24, e[1])
		f.x, f.y, f.w, f.h, f.hf, f.rot = e[1], 140, 40, 60, 0.9, e[2]
		tops[#tops + 1] = f
	end
	for i = 0, 5 do
		newEmber(150 + i * 62, 78 + (i * 23) % 30, ((i % 2 == 1) and 1 or -1) * (6 + i * 3), i * 0.29, 1.1, 64, 9)
	end
	local bursts = { newBurst(56), newBurst(56) }
	local bi = 0
	local CX = { 40, 176, 318, 104, 246, 360, 72, 140, 212, 284 }
	local WORDS = { "HOT!", "HOTTER!", "SCORCHED!" }
	local seamUntil = -1
	local ticks = 0

	local self = {}
	function self.event(name, st)
		if name == "stack" or name == "on" then
			popWord(WORDS[math.clamp(st.s, 1, 3)], 325, 54, 190, 80, C.pyro, -4)
			fx.shake(3, 0.24)
		elseif name == "tick" or name == "hit" then
			hitUntil = fx.clock + 0.25
			if name == "tick" then
				seamUntil = fx.clock + 0.2
				ticks += 1
				bi += 1
				local b = bursts[(bi - 1) % 2 + 1]
				local n = st.s >= 3 and 10 or st.s == 2 and 6 or 3
				b.x = 104 + CX[math.floor(fx.rand(ticks * 7 + 3) * n) + 1] + 6
				b.y = (bi % 2 == 1) and 116 or 164
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
		-- molten fill dots / charcoal dots on the empty part
		local fw = 392 * hp
		fillDots.Visible = st.on
		fillDots.Size = fx.S(fw, 48)
		fillDots.TileSize = UDim2.fromScale(8 / fw, 8 / 48)
		emptyDots.Visible = st.on and hp < 0.999
		emptyDots.Position = fx.P(104 + fw, 116)
		emptyDots.Size = fx.S(math.max(1, 392 - fw), 48)
		emptyDots.TileSize = UDim2.fromScale(7 / math.max(1, 392 - fw), 7 / 48)
		-- the crust plates part with stacks and creep back as the window drains
		local d = s * 3.2 * (0.3 + 0.7 * t)
		crustT.Visible, crustB.Visible = st.on, st.on
		crustT.Position = fx.P(100, 112 - d)
		crustB.Position = fx.P(100, 132 + d)
		local glow = (st.on and t < 0.3) and C.pyro or C.pyroY
		for n = 1, 3 do
			local vis = st.on and s >= n
			cracksT[n].Visible, cracksB[n].Visible = vis, vis
			cracksT[n].Position, cracksB[n].Position = crustT.Position, crustB.Position
			cracksT[n].ImageColor3, cracksB[n].ImageColor3 = glow, glow
		end
		seam.Visible = st.on and fx.clock < seamUntil
		-- flames
		local core = s >= 3 and "w" or "y"
		local sy = on * (0.3 + 0.25 * s) * (0.45 + 0.55 * t) * (1 + 0.25 * hit)
		for _, f in ipairs(tops) do
			placeFlame(f.img, f.x, f.y, f.w * on, f.h * f.hf * sy, f.rot)
		end
		for _, f in ipairs(flames) do setCore(f, core) end
		coal.Visible = st.on
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
