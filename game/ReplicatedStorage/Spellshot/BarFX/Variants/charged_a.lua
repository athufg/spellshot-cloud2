--!nocheck
-- Tesla Clamp Cage: two steel electrodes bite the bar's ends and a jagged volt aura grips it; each stack adds arcs
-- (rails, then crossing overhead arcs, then big purple arcs behind), the discharge lights everything and cracks off the
-- right node. Ported from status_fx/bench/opts/charged-a.html (round 2, 2026-09-24).
local V = { title = "Tesla Clamp Cage" }

-- bolt sprites: { pad, H } of the baked strip (ends at pad and pad + L on the mid line), see sprites/charged-*
local SPEC = { spark = { 5.5, 21 }, big = { 10.5, 53 }, bigfork = { 7.5, 31 }, bigtail = { 6.5, 29 }, arc = { 7, 40 },
	rail = { 5.75, 21.5 }, half = { 6.25, 32.5 }, inner = { 5.25, 34.5 } }

function V.mount(fx)
	local C = fx.C
	local rnd = math.random
	local function root(layer) return fx.rect(layer, { x = 0, y = 0, w = 640, h = 240, transparency = 1 }) end
	local function lay(img, spec, x1, y1, x2, y2, rot)
		local dx, dy = x2 - x1, y2 - y1
		local L = math.sqrt(dx * dx + dy * dy)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = fx.P((x1 + x2) / 2, (y1 + y2) / 2)
		img.Size = fx.S(L + 2 * spec[1], spec[2])
		img.Rotation = rot == false and 0 or math.deg(math.atan2(dy, dx)) + (rnd() < 0.5 and 180 or 0)
	end
	local function mkWord(text, size, color, maxChars)
		local w, h = 0.53 * size * maxChars + 30, size + 16
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = fx.S(w, h)
		holder.ZIndex = 45
		holder.Visible = false
		holder.Parent = fx.front
		local sc = Instance.new("UIScale")
		sc.Parent = holder
		local labs = {}
		for i, col in ipairs({ C.ink, color }) do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Position = i == 1 and UDim2.fromScale(4 / w, 4 / h) or UDim2.fromScale(0, 0)
			t.Font = Enum.Font.LuckiestGuy
			t.Text = text
			t.TextColor3 = col
			t.ZIndex = i
			t.Parent = holder
			fx.px(t, "TextSize", size)
			fx.stroke(t, 3.5, C.ink)
			labs[i] = t
		end
		return { holder = holder, sc = sc, labs = labs, size = size }
	end
	local function setWord(wd, text, left, top)
		for _, l in ipairs(wd.labs) do l.Text = text end
		wd.holder.Position = fx.P(left + 0.53 * wd.size * #text / 2, top + wd.size / 2)
	end
	local function wordPop(wd, age, dur, rot, big)
		if age < 0 or age > dur then wd.holder.Visible = false return end
		local a = math.floor(age * 12) / 12
		local k = a < 0.05 and 0.4 or a < 0.1 and (big or 1.3) or a < 0.17 and 0.95 or 1
		local out = age > dur - 0.12 and 0.75 or 1
		wd.holder.Visible = true
		wd.holder.Rotation = rot
		wd.sc.Scale = k * out
	end

	fx.restyle("label", { TextColor3 = C.voltD })

	-------------------------------------------------------------------- behind: aura, purple arcs, the gripping rings
	local backRoot = root(fx.back)
	local aura = fx.sprite(backRoot, "charged-a/aura1_1", { x = 70, y = 22, w = 460, h = 178, z = 1 })
	local B = {}
	for i = 1, 3 do B[i] = fx.sprite(backRoot, "charged-s/arc1", { z = 2 }) end
	-- the bar's box-shadow: 4 px volt ring, 4 px ink ring, 5 px ink drop shadow
	fx.rect(backRoot, { x = 97, y = 109, w = 416, h = 72, corner = 36, color = C.ink, z = 3 })
	fx.rect(backRoot, { x = 92, y = 104, w = 416, h = 72, corner = 36, color = C.ink, z = 4 })
	local ring = fx.rect(backRoot, { x = 96, y = 108, w = 408, h = 64, corner = 32, color = C.volt, z = 5 })
	local cx, cy, cw, ch = fx.chipRect()
	fx.rect(backRoot, { x = cx - 7, y = cy - 7, w = cw + 14, h = ch + 14, corner = 21, color = C.ink, z = 3 })
	fx.rect(backRoot, { x = cx - 4, y = cy - 4, w = cw + 8, h = ch + 8, corner = 18, color = C.volt, z = 4 })

	-------------------------------------------------------------------- the fill: purple halftone over the red
	local fillRoot = root(fx.fill)
	fx.dots(fillRoot, { x = 104, y = 116, w = 392, h = 48, color = C.voltD, alpha = 0.45, pitch = 7, z = 2 })
	local barRoot = root(fx.bar)
	local inB = fx.sprite(barRoot, "charged-a/inner1", { z = 2 })

	-------------------------------------------------------------------- in front: arcs, clamps, node timers, sparks
	local frontRoot = root(fx.front)
	local rails, halves = {}, {}
	for i = 1, 2 do rails[i] = fx.sprite(frontRoot, "charged-a/rail1", { z = 1 }) end
	for i = 1, 8 do halves[i] = fx.sprite(frontRoot, "charged-a/half1", { z = 1 }) end
	local clampG, nodes = {}, {}
	for side = 1, 2 do
		local g = root(frontRoot)
		g.ZIndex = 2
		local nx = side == 1 and 104 or 496
		fx.sprite(g, side == 1 and "charged-a/clampL" or "charged-a/clampR", { x = side == 1 and 92 or 470, y = 82, w = 38, h = 96, z = 1 })
		nodes[side] = fx.rect(g, { x = nx, y = 80, w = 24, h = 24, anchor = Vector2.new(0.5, 0.5), corner = "pill", color = C.voltM, stroke = 4, z = 2 })
		fx.rect(g, { x = nx - 3.5, y = 76, w = 6.4, h = 3, anchor = Vector2.new(0.5, 0.5), corner = "pill", color = C.white, rotation = -38.7, z = 3 })
		clampG[side] = g
	end
	-- the window timer: a volt ring draining clockwise from 12 o'clock round each node (two clipped halves, each
	-- cut by a hard-stepped UIGradient on its stroke)
	local TSEQ = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.502, 1), NumberSequenceKeypoint.new(1, 1) })
	local rings = {}
	for _, ncx in ipairs({ 104, 496 }) do
		local r = {}
		for side = 1, 2 do
			local clip = fx.rect(frontRoot, { x = side == 1 and ncx or ncx - 24, y = 56, w = 24, h = 48, transparency = 1, z = 3 })
			clip.ClipsDescendants = true
			local circ = Instance.new("Frame")
			circ.BackgroundTransparency = 1
			circ.AnchorPoint = Vector2.new(0.5, 0.5)
			circ.Position = UDim2.fromScale(side == 1 and 0 or 1, 0.5)
			circ.Size = UDim2.fromScale(31 / 24, 31 / 48)
			circ.Parent = clip
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0.5, 0)
			cc.Parent = circ
			local stroke = fx.stroke(circ, 5, C.volt)
			local grad = Instance.new("UIGradient")
			grad.Transparency = TSEQ
			grad.Parent = stroke
			r[side] = grad
		end
		rings[#rings + 1] = r
	end
	local sp = {}
	for i = 1, 8 do sp[i] = fx.sprite(frontRoot, "charged-s/spark1", { z = 4 }) end
	local payG = root(frontRoot)
	payG.ZIndex = 5
	local burst = fx.sprite(payG, "charged-s/burst12_1", { x = 530, y = 44, w = 137, h = 137, anchor = Vector2.new(0.5, 0.5), color = C.volt, z = 1 })
	local big = fx.sprite(payG, "charged-s/big1", { z = 2 })
	local bigF = fx.sprite(payG, "charged-s/bigfork1", { z = 2 })
	local bigF2 = fx.sprite(payG, "charged-s/bigtail1", { z = 2 })
	local aWord = mkWord("ZAP!", 34, C.volt, 6)
	local aBig = mkWord("KRAK!", 42, C.white, 5)
	setWord(aBig, "KRAK!", 470, 22)

	local wAt, pAt = -9, -9
	local boilT, on0 = 0, nil

	local function boil(st)
		local s = st.pay and 4 or st.s
		fx.setSprite(aura, "charged-a/aura" .. math.clamp(s, 1, 4) .. "_" .. rnd(1, 2))
		local nA = st.pay and 6 or ({ [0] = 0, 2, 3, 4 })[s] or 0
		for i = 1, 2 do
			rails[i].Visible = st.on and i <= nA
			if rails[i].Visible then
				fx.setSprite(rails[i], "charged-a/rail" .. rnd(1, 2))
				local y = i == 1 and 110 or 170
				lay(rails[i], SPEC.rail, 118, y, 482, y)
			end
		end
		for k = 0, 3 do
			local on = st.on and (k + 3) <= nA
			local h1, h2 = halves[k * 2 + 1], halves[k * 2 + 2]
			h1.Visible, h2.Visible = on, on
			if on then
				local mx = 300 + (rnd() - 0.5) * 80
				local my = ({ 30, 52, 40, 64 })[k + 1] + rnd() * 10
				local x0 = k % 2 == 1 and 496 or 104
				local x1 = k % 2 == 1 and 104 or 496
				fx.setSprite(h1, "charged-a/half" .. rnd(1, 2))
				fx.setSprite(h2, "charged-a/half" .. rnd(1, 2))
				lay(h1, SPEC.half, x0, 80, mx, my)
				lay(h2, SPEC.half, mx, my, x1, 80)
			end
		end
		for i = 1, 3 do
			local on = st.on and (st.pay or s >= i)
			B[i].Visible = on
			if on then
				local x = 150 + (i - 1) * 120 + rnd() * 40
				fx.setSprite(B[i], "charged-s/arc" .. rnd(1, 3))
				lay(B[i], SPEC.arc, x, 120, x + (rnd() - 0.5) * 60, 26 + (i - 1) * 10)
			end
		end
		inB.Visible = st.on
		if st.on then
			fx.setSprite(inB, "charged-a/inner" .. rnd(1, 2))
			lay(inB, SPEC.inner, 104, 128 + rnd() * 24, 496, 128 + rnd() * 24, false)
		end
		local n = st.pay and 8 or st.on and 2 + s * 2 or 0
		for i = 1, 8 do
			local e = sp[i]
			e.Visible = i <= n
			if i <= n then
				local left = (i - 1) % 2 == 0
				local x = left and 104 or 496
				local a = -math.pi / 2 + (left and -1 or 1) * (0.3 + rnd() * 1.1)
				local len = 16 + rnd() * 14
				fx.setSprite(e, "charged-s/spark" .. rnd(1, 3))
				lay(e, SPEC.spark, x + math.cos(a) * 14, 80 + math.sin(a) * 14, x + math.cos(a) * (14 + len), 80 + math.sin(a) * (14 + len))
			end
		end
		payG.Visible = st.pay
		if st.pay then
			fx.setSprite(big, "charged-s/big" .. rnd(1, 2))
			lay(big, SPEC.big, 496, 80, 590, 30)
			local f = 0.2 + rnd() * 0.6
			local jx, jy = 496 + 94 * f, 80 - 50 * f
			local a = math.atan2(-50, 94) + (rnd() < 0.5 and -0.8 or 0.8)
			fx.setSprite(bigF, "charged-s/bigfork" .. rnd(1, 2))
			lay(bigF, SPEC.bigfork, jx, jy, jx + math.cos(a) * 34, jy + math.sin(a) * 34)
			fx.setSprite(bigF2, "charged-s/bigtail" .. rnd(1, 2))
			lay(bigF2, SPEC.bigtail, 590, 30, 636, 12)
			fx.setSprite(burst, "charged-s/burst12_" .. rnd(1, 2))
			burst.Rotation = rnd() * 360
		end
	end

	local self = {}
	function self.event(name, st)
		if name == "stack" then
			local s = math.clamp(st.s, 1, 3)
			setWord(aWord, ({ "ZAP!", "ZZAP!", "ZZZAP!" })[s], 150 + (s - 1) * 100, 30)
			wAt = fx.clock
		end
		if name == "pay" then pAt = fx.clock end
		boil(st)
	end
	function self.update(st, dt)
		local now = fx.clock
		backRoot.Visible, barRoot.Visible, fillRoot.Visible, frontRoot.Visible = st.on, st.on, st.on, st.on
		ring.BackgroundColor3 = st.pay and C.white or C.volt
		local hot = st.s >= 3 or st.pay
		for side = 1, 2 do nodes[side].BackgroundColor3 = hot and C.volt or C.voltM end
		-- clamps jolt on the 10 fps boil at 3 stacks
		local j = hot and ((math.floor(now * 10) % 2 == 1) and 2 or -2) or 0
		clampG[1].Position = fx.P(-j, j)
		clampG[2].Position = fx.P(j, -j)
		-- node rings drain with the window
		local t = st.pay and 1 or math.clamp(st.t, 0, 1)
		for _, r in ipairs(rings) do
			r[1].Rotation = math.min(t, 0.5) * 360
			r[2].Rotation = math.clamp(t * 360, 180, 360)
		end
		boilT += dt
		if boilT > 0.1 or st.on ~= on0 then boilT = 0; boil(st) end
		wordPop(aWord, now - wAt, 0.7, -7)
		wordPop(aBig, now - pAt, 1, 6, 1.4)
		on0 = st.on
	end
	return self
end

return V
