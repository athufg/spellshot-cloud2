--!nocheck
-- Strapped Charges: five bombs strapped along the bar, a fuse wrapped round it racing to a blinking detonator, then a
-- left-to-right BA-BA-BOOM! chain. Ported from status_fx/bench/opts/primed-a.html (round 2, 2026-09-24).
local V = { title = "Strapped Charges" }

-- each bomb's wick (M30 18 C30 8 38 4 44 6 S54 2 54 -6 in the 60 x 66 bomb box), 20 equal steps
local WICK = { 30.0,18.0, 30.1,16.0, 30.5,14.0, 31.1,12.1, 32.1,10.4, 33.3,8.8, 34.8,7.5, 36.5,6.5, 38.4,5.8, 40.4,5.5,
	42.4,5.6, 44.4,6.1, 46.4,6.4, 48.3,6.0, 50.0,5.0, 51.4,3.5, 52.4,1.8, 53.2,-0.1, 53.6,-2.0, 53.9,-4.0, 54.0,-6.0 }
local function wickPoint(f)
	local n = #WICK / 2 - 1
	local x = math.clamp(f, 0, 1) * n
	local i = math.clamp(math.floor(x), 0, n - 1)
	local u = x - i
	local ax, ay, bx, by = WICK[2 * i + 1], WICK[2 * i + 2], WICK[2 * i + 3], WICK[2 * i + 4]
	return ax + (bx - ax) * u, ay + (by - ay) * u
end
local WICK_LEVELS = { 1.0, 0.84, 0.68, 0.51, 0.35 }

-- the wrapped fuse: M129 100 H471 A40 40 0 0 1 471 180 H129 A40 40 0 0 1 89 140
local TOP, ARC_R, BOT, ARC_L = 342, math.pi * 40, 342, math.pi * 20
local FUSE_L = TOP + ARC_R + BOT + ARC_L
local function fusePoint(d)
	if d <= TOP then return 129 + d, 100 end
	d -= TOP
	if d <= ARC_R then local a = -math.pi / 2 + d / 40 return 471 + 40 * math.cos(a), 140 + 40 * math.sin(a) end
	d -= ARC_R
	if d <= BOT then return 471 - d, 180 end
	d -= BOT
	local a = math.pi / 2 + math.min(d, ARC_L) / 40
	return 129 + 40 * math.cos(a), 140 + 40 * math.sin(a)
end
-- stepped CSS keyframes: keys = { {p, scale, rot}, ... }, steps() with fill both
local POP = { { 0, 0, -8 }, { 0.4, 1.18, 3 }, { 0.6, 0.96, 0 }, { 1, 1, 0 } }
local TICK = { { 0, 0.3, -10 }, { 0.3, 1.25, 4 }, { 0.5, 1, 0 }, { 1, 1, 0 } }
local function kf(keys, p, steps)
	if p >= 1 then return keys[#keys][2], keys[#keys][3] end
	p = math.floor(math.max(p, 0) * steps) / steps
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if p <= b[1] then
			local u = (p - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u
		end
	end
	return keys[#keys][2], keys[#keys][3]
end

-- hard-stop colour bands for a UIGradient: { {color, endFraction}, ... }
local function seq(list)
	local k, prev = {}, 0
	for _, b in ipairs(list) do
		k[#k + 1] = ColorSequenceKeypoint.new(prev == 0 and 0 or math.min(1, prev + 0.002), b[1])
		k[#k + 1] = ColorSequenceKeypoint.new(b[2], b[1])
		prev = b[2]
	end
	return ColorSequence.new(k)
end
local function grad(parent, s, rot)
	local g = Instance.new("UIGradient")
	g.Color = s
	g.Rotation = rot or 0
	g.Parent = parent
	return g
end

local EMB = { { 16, -20, 0 }, { -22, -18, 0.1 }, { 20, -24, 0.2 }, { 6, 22, 0.15 } }

function V.mount(fx)
	local C = fx.C
	local hex = function(h) return Color3.fromRGB(tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)) end
	local GUN = hex("#262A31")

	-- a CSS border-box rect: the ink border sits inside w x h
	local function box(parent, o)
		local s = o.stroke or 0
		return fx.rect(parent, { x = o.x + s, y = o.y + s, w = o.w - 2 * s, h = o.h - 2 * s, color = o.color,
			corner = o.corner and math.max(1, o.corner - s) or nil, stroke = s > 0 and s or nil, z = o.z })
	end
	local function text(parent, o)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = fx.P(o.x, o.y)
		holder.Size = fx.S(o.w, o.h)
		holder.ZIndex = o.z
		holder.Parent = parent
		local sc = Instance.new("UIScale")
		sc.Parent = holder
		local function one(color, d, z)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Position = UDim2.fromScale(d / o.w, d / o.h)
			t.Font = Enum.Font.LuckiestGuy
			t.Text = o.text
			t.TextColor3 = color
			t.ZIndex = z
			t.Parent = holder
			fx.px(t, "TextSize", o.size)
			fx.stroke(t, o.stroke, C.ink)
			return t
		end
		local r = { holder = holder, scale = sc }
		if o.shadow then r.shadow = one(C.ink, o.shadow, 1) end
		r.label = one(o.color, 0, 2)
		return r
	end
	local function spark(parent, size, z)
		local h = Instance.new("Frame")
		h.BackgroundTransparency = 1
		h.AnchorPoint = Vector2.new(0.5, 0.5)
		h.Size = fx.S(size, size)
		h.ZIndex = z
		h.Parent = parent
		local img = fx.sprite(h, "primed-s/spark", {})
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		local em = {}
		for i = 1, 4 do
			local e = fx.rect(h, { color = C.pyroY, stroke = 2, z = 2 })
			e.AnchorPoint = Vector2.new(0.5, 0.5)
			e.Rotation = 45
			em[i] = e
		end
		return { holder = h, img = img, em = em, size = size }
	end
	local function sparkStep(sp, x, y)
		sp.holder.Position = fx.P(x, y)
		local a = (fx.clock % 0.2) < 0.1
		sp.img.Rotation = a and 0 or 24
		sp.img.Size = a and UDim2.fromScale(1, 1) or UDim2.fromScale(0.82, 0.82)
		for i, e in ipairs(sp.em) do
			local d = EMB[i]
			local ph = math.floor(((fx.clock + d[3]) % 0.3) / 0.3 * 3) / 3
			local k = 1 - 0.7 * ph
			e.Position = UDim2.fromScale((17 + d[1] * ph) / sp.size, (17 + d[2] * ph) / sp.size)
			e.Size = UDim2.fromScale(4 * k / sp.size, 4 * k / sp.size)
		end
	end


	-- the real HUD: the badge becomes the detonator's steel box
	fx.restyle("chip", { BackgroundColor3 = C.steel })
	local cx, cy, cw, ch = fx.chipRect()
	fx.rect(fx.front, { x = cx + 5, y = cy + 5, w = cw - 10, h = 0.28 * (ch - 10), color = C.steelL, corner = 9, z = 1 })
	fx.rect(fx.front, { x = cx + 5, y = cy + 0.75 * ch, w = cw - 10, h = 0.25 * ch - 5, color = C.steelD, corner = 9, z = 1 })

	------------------------------------------------------------------ back: the big yellow burst
	local backB = fx.sprite(fx.back, "primed-a/back", { x = 315, y = 125, w = 470, h = 170, anchor = Vector2.new(0.5, 0.5), z = 6, visible = false })
	local backS = Instance.new("UIScale")
	backS.Parent = backB

	------------------------------------------------------------------ fill: char on the payoff
	local char = fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.paper, z = 3, visible = false })
	local charDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.pyro, alpha = 1, pitch = 8, z = 4 })
	charDots.Visible = false

	------------------------------------------------------------------ front: the fuse wrapped round the bar
	local nopay = {}
	local topF = fx.rect(fx.front, { x = 129, y = 100, w = 342, h = 5, anchor = Vector2.new(0, 0.5), color = C.terraL, stroke = 3, z = 12 })
	local botF = fx.rect(fx.front, { x = 129, y = 180, w = 342, h = 5, anchor = Vector2.new(0, 0.5), color = C.terraL, stroke = 3, z = 12 })
	nopay[#nopay + 1] = topF
	nopay[#nopay + 1] = botF
	local arcs = {}
	local function arcPiece(cx0, cy0, midDeg, startD)
		local a = math.rad(midDeg)
		local img = fx.sprite(fx.front, "primed-a/arc", { x = cx0 + 40 * math.cos(a), y = cy0 + 40 * math.sin(a), w = 16, h = 34,
			anchor = Vector2.new(0.5, 0.5), rotation = midDeg, z = 12 })
		arcs[#arcs + 1] = { img = img, mid = startD + math.pi * 40 / 6 / 2 }
		nopay[#nopay + 1] = img
	end
	local seg = math.pi * 40 / 6
	for i = 0, 5 do arcPiece(471, 140, -75 + 30 * i, TOP + seg * i) end
	for i = 0, 2 do arcPiece(129, 140, 105 + 30 * i, TOP + ARC_R + BOT + seg * i) end

	------------------------------------------------------------------ front: straps and bombs
	local B = { { 184, 18 }, { 258, 22 }, { 332, 18 }, { 406, 22 }, { 474, 17 } }
	local bombs = {}
	for i, b in ipairs(B) do
		local x, s = b[1], b[2] / 22
		local strap = box(fx.front, { x = x - 10, y = 98, w = 20, h = 82, color = C.white, stroke = 4, corner = 4, z = 24 })
		grad(strap, seq({ { hex("#E6CF96"), 0.3 }, { C.terraL, 0.72 }, { C.terra, 1 } }), 0)
		local buckle = box(fx.front, { x = x - 11, y = 146, w = 22, h = 18, color = C.steelL, stroke = 4, corner = 3, z = 25 })
		local wick = fx.sprite(fx.front, "primed-a/wick1", { x = x - 30 * s, y = 122 - 78 * s, w = 60 * s, h = 78 * s, z = 25 })
		local body = fx.sprite(fx.front, "primed-a/bomb", { x = x - 30 * s, y = 122 - 78 * s, w = 60 * s, h = 78 * s, z = 26 })
		local wsp = fx.sprite(fx.front, "primed-s/wspark", { w = 24, h = 24, z = 30 })
		wsp.AnchorPoint = Vector2.new(0.5, 0.5)
		bombs[i] = { x = x, s = s, wick = wick, body = body, wsp = wsp, level = 1, red = false }
		for _, o in ipairs({ strap, buckle, wick, body, wsp }) do nopay[#nopay + 1] = o end
	end

	-- the main spark, the detonator LED, the TIK/TOK pops
	local sp = spark(fx.front, 34, 45)
	nopay[#nopay + 1] = sp.holder
	local led = box(fx.front, { x = 48, y = 92, w = 16, h = 16, color = C.red, stroke = 3, z = 32 })
	local ledCorner = Instance.new("UICorner")
	ledCorner.CornerRadius = UDim.new(0.5, 0)
	ledCorner.Parent = led
	nopay[#nopay + 1] = led
	local tik = text(fx.front, { text = "", x = 320, y = 31, w = 140, h = 50, size = 34, color = C.white, stroke = 3.5, shadow = 4, z = 50 })
	nopay[#nopay + 1] = tik.holder

	------------------------------------------------------------------ payoff: the chain
	local BB = { { 96, 66, 0 }, { 196, 52, 25 }, { 290, 72, -18 }, { 384, 52, 12 }, { 452, 72, -30 } }
	local BB2 = { { 120, 86, 0 }, { 220, 72, 20 }, { 314, 92, -15 }, { 408, 72, 30 }, { 476, 92, -24 } }
	local booms = {}
	for i, d in ipairs(BB) do
		local img = fx.sprite(fx.front, "primed-a/bb", { x = d[1] + 62, y = d[2] + 55, w = 124, h = 110, anchor = Vector2.new(0.5, 0.5), z = 34, visible = false })
		local sc = Instance.new("UIScale"); sc.Parent = img
		booms[#booms + 1] = { img = img, sc = sc, delay = 0.05 * (i - 1), rot = d[3] }
	end
	for i, d in ipairs(BB2) do
		local img = fx.sprite(fx.front, "primed-a/bb2", { x = d[1] + 39, y = d[2] + 35, w = 78, h = 70, anchor = Vector2.new(0.5, 0.5), z = 35, visible = false })
		local sc = Instance.new("UIScale"); sc.Parent = img
		booms[#booms + 1] = { img = img, sc = sc, delay = 0.05 * (i - 1), rot = d[3] }
	end
	booms[#booms + 1] = { img = backB, sc = backS, delay = 0, rot = 0 }
	local word = text(fx.front, { text = "BA-BA-BOOM!", x = 335, y = 37, w = 480, h = 80, size = 62, color = C.pyroY, stroke = 4, shadow = 4, z = 55 })
	word.holder.Visible = false

	local lastSec, payAt = 0, nil
	local layers = { fx.back, fx.bar, fx.fill, fx.front }

	local self = {}
	function self.event(name, st)
		if name == "on" then lastSec = 0; payAt = nil
		elseif name == "pay" then payAt = fx.clock; fx.shake(7, 0.4) end
	end
	function self.update(st, dt)
		for _, l in ipairs(layers) do l.Visible = st.on end
		if not st.on then return end
		if st.pay and not payAt then payAt = fx.clock; fx.shake(7, 0.4) end
		if not st.pay then payAt = nil end
		local pay = payAt ~= nil
		local urg = st.t < 0.34
		for _, o in ipairs(nopay) do o.Visible = not pay end

		if pay then
			local pt = fx.clock - payAt
			fx.restyle("fill", { BackgroundColor3 = C.red })
			char.Visible = true
			local charred = pt >= 0.096
			char.BackgroundColor3 = charred and C.ink or C.paper
			charDots.Visible = charred
			for _, b in ipairs(booms) do
				local e = pt - b.delay
				b.img.Visible = e >= 0
				local s, r = kf(POP, e / 0.5, 5)
				b.sc.Scale = math.max(0.001, s)
				b.img.Rotation = b.rot + r
			end
			local e = pt - 0.12
			word.holder.Visible = e >= 0
			local s, r = kf(POP, e / 0.45, 5)
			word.scale.Scale = math.max(0.001, s)
			word.holder.Rotation = r
			return
		end
		char.Visible, charDots.Visible, word.holder.Visible = false, false, false
		for _, b in ipairs(booms) do b.img.Visible = false end

		-- the fill throbs dark red in the last seconds; the bar jitters
		local throb = urg and (fx.clock % 0.4) >= 0.2
		fx.restyle("fill", { BackgroundColor3 = throb and C.redD or C.red })
		if urg then fx.shake(1.5, 0.05) end

		-- the wrapped fuse burns away from its start (top-left), clockwise
		local t = math.max(0.01, st.t)
		local burnt = (1 - t) * FUSE_L
		local tv = math.max(0, TOP - burnt)
		topF.Visible = tv > 0.5
		topF.Position = fx.P(471 - tv, 100)
		topF.Size = fx.S(math.max(0.5, tv), 5)
		local bv = math.clamp(TOP + ARC_R + BOT - burnt, 0, BOT)
		botF.Visible = bv > 0.5
		botF.Size = fx.S(math.max(0.5, bv), 5)
		for _, a in ipairs(arcs) do a.img.Visible = burnt < a.mid end
		local sx, sy = fusePoint(burnt)
		sparkStep(sp, sx, sy)

		-- the LED: 1 Hz red, then 2.5 Hz yellow
		local period = urg and 0.4 or 1
		led.Visible = (fx.clock % period) < period / 2
		led.BackgroundColor3 = urg and C.pyroY or C.red

		-- the bombs: wicks shorten, sparks ride the tips, red and throbbing at the end
		local k = 0.35 + 0.65 * t
		local lvl = 1
		for i = #WICK_LEVELS, 1, -1 do if WICK_LEVELS[i] >= k - 1e-3 then lvl = i break end end
		local squash = urg and (fx.clock % 0.4) >= 0.2
		for _, b in ipairs(bombs) do
			local s = b.s
			if b.level ~= lvl then b.level = lvl; fx.setSprite(b.wick, "primed-a/wick" .. lvl) end
			if b.red ~= urg then b.red = urg; fx.setSprite(b.body, urg and "primed-a/bomb_red" or "primed-a/bomb") end
			local x0, y0, w, h = b.x - 30 * s, 122 - 78 * s, 60 * s, 78 * s
			if squash then
				local py = 122 - 66 * s + 56.1 * s
				x0, w = b.x - 30 * s * 1.14, w * 1.14
				y0, h = py - (py - y0) * 0.9, h * 0.9
			end
			for _, img in ipairs({ b.wick, b.body }) do
				img.Position = fx.P(x0, y0)
				img.Size = fx.S(w, h)
			end
			local qx, qy = wickPoint(k)
			b.wsp.Position = fx.P(b.x - 30 * s + qx * s, 122 - 66 * s + qy * s)
			local boil = (fx.clock % 0.2) < 0.1
			b.wsp.Rotation = boil and 0 or 24
			b.wsp.Size = boil and fx.S(24, 24) or fx.S(19.7, 19.7)
		end

		-- TIK! TOK! then 3! 2! 1!
		local s = math.max(1, math.ceil(st.t * 6 - 1e-6))
		if s ~= lastSec then
			lastSec = s
			local hot = s <= 3
			local txt = hot and (s .. "!") or ((s % 2 == 1) and "TIK!" or "TOK!")
			tik.label.Text = txt
			tik.shadow.Text = txt
			tik.label.TextColor3 = hot and C.pyroY or C.white
			if tik.hot ~= hot then
				tik.hot = hot
				fx.px(tik.label, "TextSize", hot and 44 or 34)
				fx.px(tik.shadow, "TextSize", hot and 44 or 34)
			end
			local left = hot and 250 or (s % 2 == 1) and 180 or 330
			tik.holder.Position = fx.P(left + 70, hot and 36 or 31)
			tik.born = fx.clock
		end
		local ts, tr = kf(TICK, (fx.clock - (tik.born or -1)) / 0.35, 4)
		tik.scale.Scale = ts
		tik.holder.Rotation = tr
	end
	return self
end

return V
