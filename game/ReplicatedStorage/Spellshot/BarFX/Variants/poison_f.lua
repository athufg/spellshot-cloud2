--!nocheck
-- Venom Flow: the HP fill becomes a rushing river of venom with a purple vein and a foam head, the lost part turns to
-- purple sludge, a froth crown and drip rim frame the bar, and the cure eats the venom back from the left as time runs
-- out. Ported from status_fx/bench/opts/poison-f.html (round 2, 2026-09-24).
local V = { title = "Venom Flow" }

function V.mount(fx)
	local C = fx.C
	local V2 = Vector2.new
	local MID = V2(0.5, 0.5)

	------------------------------------------------------------------------------------------------
	-- shared toxin kit (same in poison_t / poison_a / poison_f)
	------------------------------------------------------------------------------------------------
	-- CSS keyframes with a per-segment steps(n) timing function: keys = { {t, a, b}, ... }
	local function kfs(e, keys, n)
		if e <= keys[1][1] then return keys[1][2], keys[1][3] or 0 end
		for i = 1, #keys - 1 do
			local a, b = keys[i], keys[i + 1]
			if e < b[1] then
				local u = (e - a[1]) / (b[1] - a[1])
				if n then u = math.floor(u * n) / n end
				return a[2] + (b[2] - a[2]) * u, (a[3] or 0) + ((b[3] or 0) - (a[3] or 0)) * u
			end
		end
		local l = keys[#keys]
		return l[2], l[3] or 0
	end
	-- a whole-design-space container, scaled about a pivot (design px) for squash/stretch
	local function layer(parent, z)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = z or 1
		f.Parent = parent
		return f
	end
	local function scaleAbout(f, sx, sy, px, py)
		f.Size = UDim2.fromScale(sx, sy)
		f.Position = UDim2.fromScale(px / 640 * (1 - sx), py / 240 * (1 - sy))
	end
	-- rise: a bubble climbs dy while growing .5 -> 1, swells to 1.35, pops (steps(9) per segment)
	local RISE = { { 0, 0.5, 0 }, { 0.7, 1, 1 }, { 0.85, 1.35, 1 } }
	local function rise(phase)
		if phase >= 0.86 then return 0, 1 end
		if phase >= 0.85 then return 1.35, 1 end
		return kfs(phase, RISE, 9)
	end
	-- burst: splat + 4 droplets + lettered word, removed after 0.65 s
	local SPLAT = { { 0, 0.2, 0 }, { 0.15, 1.15, 8 }, { 0.35, 1, 10 }, { 0.5, 0, 14 } }
	local WORD = { { 0, 0.3, 0 }, { 0.12, 1.3, 0 }, { 0.24, 1, 0 }, { 0.51, 1, -8 }, { 0.6, 0, -12 } }
	local bursts = {}
	local function stepBurst(b, e)
		local s, r = kfs(e, SPLAT, 5)
		b.splat.Visible = s > 0.01
		b.splat.Size = fx.S(b.sz * s, b.sz * s)
		b.splat.Rotation = r
		local u = math.floor(math.min(e / 0.55, 1) * 6) / 6
		for _, d in ipairs(b.drops) do
			d.obj.Position = fx.P(b.x + d.dx * u, b.y + d.dy * u)
			d.obj.Size = fx.S(12 * (1 - 0.6 * u), 12 * (1 - 0.6 * u))
		end
		if b.word then
			local sc, ty = kfs(e, WORD, 6)
			b.word.Visible = sc > 0.01
			if b.wscale then b.wscale.Scale = math.max(sc, 0.01) end
			b.word.Position = fx.P(b.wx, b.wy + ty)
		end
	end
	local function burst(x, y, word, plain, opt)
		opt = opt or {}
		local R = opt.r or 34
		local sz = 2 * R * 92 / 88
		local b = { born = fx.clock, x = x, y = y, sz = sz, drops = {} }
		b.splat = fx.sprite(fx.front, opt.splat or "poison-s/splatL", { x = x, y = y, w = sz, h = sz, anchor = MID, z = 56 })
		for i = 0, 3 do
			local a = -math.pi * (0.15 + i * 0.23)
			local d = fx.sprite(fx.front, "poison-s/drop", { x = x, y = y, w = 12, h = 12, anchor = MID, rotation = -45, z = 55 })
			b.drops[#b.drops + 1] = { obj = d, dx = math.cos(a) * 46, dy = math.sin(a) * 40 + 30 }
		end
		if word then
			local fs = opt.fs or 30
			local w = #plain * fs * 0.62
			b.wx = x + (opt.wx or -40) + w / 2
			b.wy = y + (opt.wy or -52) + fs * 0.5
			local holder, label = fx.word(fx.front, word, { x = b.wx, y = b.wy, size = fs, color = C.toxinL, stroke = 3.5,
				rotation = opt.rot or -8, z = 58, pop = false, burstW = w + 40, burstH = fs * 1.6 })
			label.RichText = true
			b.word = holder
			b.wscale = holder:FindFirstChildOfClass("UIScale")
		end
		bursts[#bursts + 1] = b
		stepBurst(b, 0)
	end
	local function stepBursts()
		for i = #bursts, 1, -1 do
			local b = bursts[i]
			local e = fx.clock - b.born
			if e >= 0.65 then
				if b.splat.Parent then b.splat:Destroy() end
				for _, d in ipairs(b.drops) do if d.obj.Parent then d.obj:Destroy() end end
				if b.word and b.word.Parent then b.word:Destroy() end
				table.remove(bursts, i)
			else
				stepBurst(b, e)
			end
		end
	end
	local function minus(n) return '<font color="#FFFFFF">-' .. n .. "</font>" end

	------------------------------------------------------------------------------------------------
	-- LIVING FILL: the venom stream
	------------------------------------------------------------------------------------------------
	local FLIP = 1 / 0.12
	local LILAC = Color3.fromRGB(0xB5, 0x8C, 0xF0)
	fx.restyle("bar", { BackgroundColor3 = C.toxinD })
	fx.restyle("label", { TextColor3 = C.toxinL })
	fx.restyle("chip", { BackgroundColor3 = C.toxinD })
	fx.restyle("glyph", { ImageTransparency = 1 })

	-- behind: the drip rim under the whole bar, then the bar's green + ink double rim and its fat offset shadow
	local back = layer(fx.back, 1)
	local rim = fx.sprite(back, "poison-f/rimA", { x = 90, y = 150, w = 422, h = 56, z = 1 })
	fx.flip(rim, { "poison-f/rimA", "poison-f/rimB" }, FLIP, 0)
	fx.rect(back, { x = 100, y = 112, w = 410, h = 66, color = C.ink, corner = 33, z = 2 })
	fx.rect(back, { x = 93, y = 105, w = 414, h = 70, color = C.ink, corner = 35, z = 3 })
	fx.rect(back, { x = 96, y = 108, w = 408, h = 64, color = C.toxin, corner = 32, z = 4 })

	-- inside the bar
	local barL = layer(fx.bar, 1)
	local sludgeDots = fx.dots(barL, { x = 400, y = 116, w = 96, h = 48, color = LILAC, alpha = 0.35, pitch = 7, z = 1 })
	local venom = Instance.new("Frame")
	venom.BackgroundColor3 = C.toxin
	venom.BorderSizePixel = 0
	venom.ClipsDescendants = true
	venom.ZIndex = 2
	venom.Parent = barL
	local vDots = fx.dots(venom, { color = C.toxinM, alpha = 0.45, pitch = 7, z = 1 })
	local flowB = fx.sprite(venom, "poison-f/flowB", { z = 2 })
	local flowA = fx.sprite(venom, "poison-f/flowA", { z = 3 })
	local veinB = fx.sprite(venom, "poison-f/veinB", { z = 4 })
	local vbs = {}
	for i = 0, 8 do
		local sz = 9 + (i * 5) % 9
		local img = fx.sprite(venom, (i % 4 == 1) and "poison-s/bubD" or "poison-s/bub", { z = 5 })
		vbs[#vbs + 1] = { img = img, lx = i * 44 - 30, ly = 14 + (i * 13) % 22, sz = sz, rd = 0.9 + (i % 3) * 0.3, dl = i * 0.23,
			s2 = (i % 3 == 2) }
	end
	local surge = fx.sprite(venom, "poison-f/surge", { z = 6 })
	local cure = fx.sprite(barL, "poison-f/cureA", { x = 200, y = 101, w = 36, h = 80, z = 3 })
	fx.flip(cure, { "poison-f/cureA", "poison-f/cureB" }, FLIP, 0)
	local foam = fx.sprite(barL, "poison-f/foamA", { x = 300, y = 100, w = 40, h = 82, z = 4 })
	fx.flip(foam, { "poison-f/foamA", "poison-f/foamB" }, FLIP, 0)

	-- in front: the froth crown along the top, the x2 burst, the chip's halftone and green heart
	local front = layer(fx.front, 1)
	local crownL = layer(front, 1)
	local crown = fx.sprite(crownL, "poison-f/crownA", { x = 95, y = 88, w = 416, h = 42, z = 1 })
	fx.flip(crown, { "poison-f/crownA", "poison-f/crownB" }, FLIP, 0)
	local x2star = fx.sprite(front, "poison-f/x2star", { x = 489, y = 111, w = 78, h = 78, anchor = MID, z = 3 })
	local x2scale = Instance.new("UIScale")
	x2scale.Parent = x2star
	local x2word = fx.word(front, "x2", { x = 489, y = 111, size = 28, color = C.toxinL, stroke = 3, rotation = -8, z = 4, pop = false,
		burstW = 74, burstH = 74 })
	local x2wscale = x2word:FindFirstChildOfClass("UIScale")
	local chipDots = fx.dots(front, { x = 30, y = 114, w = 52, h = 52, color = LILAC, alpha = 0.4, pitch = 7, z = 5 })
	local heart = fx.sprite(front, "poison-f/heart", { x = 56, y = 140, w = 38, h = 38, anchor = MID, z = 6 })

	------------------------------------------------------------------------------------------------
	local POP = { { 0, 0.2 }, { 0.4, 1.25 }, { 0.7, 0.92 }, { 1, 1 } }
	local JOLT2 = { { 0, 0.88 }, { 0.125, 1.07 }, { 0.25, 1 } }
	local surgBorn, x2Born = nil, nil
	local lastS = 0
	local function surg() surgBorn = fx.clock end

	local self = {}
	function self.event(name, st)
		local ex = 104 + st.hp * 392
		if name == "on" then
			surg()
			burst(ex, 110, "VENOM!", "VENOM!", { r = 40, fs = 34, wx = -130, wy = -54, rot = -6 })
		elseif name == "stack" and st.s == 2 then
			surg()
			burst(250, 106, "DOUBLE!", "DOUBLE!", { r = 44, fs = 32, wx = -80, wy = -60, rot = -4, splat = "poison-s/splatG" })
		elseif name == "tick" then
			surg()
			local n = tostring(st.drop or st.s * 2)   -- (2026-10-19, audit GA-05) the real HP lost (BarFX st.drop); the bench's s * 2 in previews
			burst(ex, 112, "HSSS! " .. minus(n), "HSSS! -" .. n, { r = 32, rot = -7, wx = -150, wy = -50 })
		end
	end

	function self.update(st, dt)
		local on = st.on
		back.Visible, barL.Visible, front.Visible = on, on, on
		local s2 = st.s >= 2
		if s2 and lastS < 2 then x2Born = fx.clock end
		lastS = st.s
		local clock = fx.clock
		local fillW = 392 * st.hp
		local ex = 104 + fillW
		local cx0 = 104 + fillW * (1 - st.t)
		local vw = fillW * st.t

		-- the bar jolts on every surge
		local sy, surgE = 1, nil
		if surgBorn then
			surgE = clock - surgBorn
			if surgE < 0.25 then sy = (kfs(surgE, JOLT2, 3)) end
			if surgE >= 0.42 then surgBorn = nil; surgE = nil end
		end
		scaleAbout(barL, 1, sy, 300, 140)

		-- the lost-HP sludge halftone (the bar background itself is restyled purple)
		local sw = math.max(496 - ex, 0.5)
		sludgeDots.Position = fx.P(ex, 116)
		sludgeDots.Size = fx.S(sw, 48)
		sludgeDots.TileSize = UDim2.fromScale(7 / sw, 7 / 48)

		-- the venom body: from the cure front to the fill's end
		venom.Visible = vw > 0.5
		if vw > 0.5 then
			venom.Position = fx.P(cx0, 116)
			venom.Size = fx.S(vw, 48)
			local function put(o, lx, ly, w, h)
				o.Position = UDim2.fromScale(lx / vw, ly / 48)
				o.Size = UDim2.fromScale(w / vw, h / 48)
			end
			put(vDots, 0, 0, vw, 48)
			vDots.TileSize = UDim2.fromScale(7 / vw, 7 / 48)
			local da, db = s2 and 0.6 or 1.2, s2 and 0.9 or 1.8
			local ta = -120 + 120 * math.floor(((clock / da) % 1) * 10) / 10
			local tb = -120 + 120 * math.floor(((clock / db) % 1) * 10) / 10
			put(flowB, tb, 0, 480, 48)
			put(flowA, ta, 0, 480, 48)
			put(veinB, ta, 0, 480, 48)
			veinB.Visible = s2
			for _, b in ipairs(vbs) do
				local rd = b.rd * (s2 and 0.55 or 1)
				local u = math.floor((((clock + b.dl) / rd) % 1) * 8) / 8
				b.img.Visible = (not b.s2) or s2
				put(b.img, b.lx + 90 * u, b.ly - 8 * u, b.sz, b.sz)
			end
			-- the surge chevron races along the stream
			surge.Visible = surgE ~= nil
			if surgE then
				local u = math.floor(math.min(surgE / 0.4, 1) * 6) / 6
				put(surge, -80 + 480 * u, 0, 70, 48)
			end
		end
		cure.Position = fx.P(cx0 - 14 - 5, 101)
		cure.Visible = vw > 0.5
		foam.Position = fx.P(ex - 20 - 3, 100)

		-- the crown grows taller at 2 stacks; the x2 burst pops in
		scaleAbout(crownL, 1, s2 and 1.35 or 1, 0, 114)
		x2star.Visible, x2word.Visible = s2, s2
		if s2 then
			local sc = 1
			if x2Born and clock - x2Born < 0.35 then sc = (kfs((clock - x2Born) / 0.35, POP, 4)) end
			x2scale.Scale = sc
			if x2wscale then x2wscale.Scale = sc end
		end

		-- the purple chip and its green heart, on the real badge
		local cx, cy, cw, ch = fx.chipRect()
		local k = cw / 64
		heart.Position = fx.P(cx + cw / 2, cy + ch / 2)
		heart.Size = fx.S(38 * k, 38 * k)
		chipDots.Position = fx.P(cx + 6 * k, cy + 6 * k)
		chipDots.Size = fx.S(cw - 12 * k, ch - 12 * k)

		stepBursts()
	end

	return self
end

return V
