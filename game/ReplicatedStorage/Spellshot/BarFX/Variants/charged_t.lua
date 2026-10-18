--!nocheck
-- Overload Battery: the whole health row becomes a 3-cell battery; each stack lights a lamp and a cell of live current,
-- the third makes the casing jolt, the discharge arcs off the + terminal. Ported from status_fx/bench/opts/charged-t.html
-- (round 2, 2026-09-24).
local V = { title = "Overload Battery" }

-- bolt sprites: { pad, H } of the baked strip (ends at pad and pad + L on the mid line), see sprites/charged-*
local SPEC = { spark = { 5.5, 21 }, big = { 10.5, 53 }, bigfork = { 7.5, 31 }, bigtail = { 6.5, 29 }, cell = { 6, 38 } }

function V.mount(fx)
	local C = fx.C
	local hex = function(h) return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end
	local SHELL3 = hex("A56BFF")
	local rnd = math.random
	local function pick(t) return t[rnd(1, #t)] end
	local function root(layer) return fx.rect(layer, { x = 0, y = 0, w = 640, h = 240, transparency = 1 }) end
	-- lay a horizontal bolt strip between two design points (rot = false keeps it unrotated: the bar's clips)
	local function lay(img, spec, x1, y1, x2, y2, rot)
		local dx, dy = x2 - x1, y2 - y1
		local L = math.sqrt(dx * dx + dy * dy)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = fx.P((x1 + x2) / 2, (y1 + y2) / 2)
		img.Size = fx.S(L + 2 * spec[1], spec[2])
		img.Rotation = rot == false and 0 or math.deg(math.atan2(dy, dx)) + (rnd() < 0.5 and 180 or 0)
	end
	-- comic word with the bench's 4 px ink drop shadow; popped from the kit clock like the bench's wordPop
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

	-- the HUD restyles: the bar becomes the battery (bar voltD, fill volt, chip volt with its heart hidden)
	fx.restyle("bar", { BackgroundColor3 = C.voltD })
	fx.restyle("fill", { BackgroundColor3 = C.volt })
	fx.restyle("chip", { BackgroundColor3 = C.volt })
	fx.restyle("glyph", { ImageTransparency = 1 })
	fx.restyle("label", { TextColor3 = C.voltL })

	-------------------------------------------------------------------- behind: the casing
	local case = root(fx.back)
	fx.sprite(case, "charged-t/cap", { x = 508, y = 116, w = 38, h = 48, z = 1 })
	local shell = Instance.new("CanvasGroup")
	shell.BackgroundColor3 = C.voltM
	shell.BorderSizePixel = 0
	shell.Position = fx.P(12, 94)
	shell.Size = fx.S(508, 92)
	shell.ZIndex = 2
	shell.Parent = case
	local shellCorner = Instance.new("UICorner")
	shellCorner.Parent = shell
	fx.pxUDim(shellCorner, 30)
	local sd = fx.dots(shell, { w = 508, h = 92, color = C.ink, alpha = 0.28, pitch = 7 })
	sd.Size = UDim2.fromScale(1, 1)
	fx.rect(case, { x = 12, y = 94, w = 508, h = 92, transparency = 1, corner = 30, stroke = 4.5, z = 3 })
	fx.rect(case, { x = 44, y = 97.5, w = 444, h = 3, corner = "pill", color = C.white, transparency = 0.3, z = 4 })
	fx.rect(case, { x = 112, y = 170, w = 376, h = 12, corner = 6, color = C.voltD, stroke = 3, z = 4 })
	local tTime = fx.rect(case, { x = 114, y = 172, w = 372, h = 8, corner = 4, color = C.volt, z = 5 })
	local lamps = {}
	for i = 1, 3 do
		lamps[i] = fx.rect(case, { x = 118 + (i - 1) * 123, y = 97, w = 118, h = 12, corner = 6, color = C.voltD, stroke = 2.5, z = 6 })
	end
	for _, p in ipairs({ { 30, 110 }, { 30, 170 }, { 500, 110 }, { 500, 170 } }) do
		fx.rect(case, { x = p[1], y = p[2], w = 7, h = 7, anchor = Vector2.new(0.5, 0.5), corner = "pill", color = C.white, stroke = 2, z = 6 })
	end

	-------------------------------------------------------------------- inside the bar: 3 cells of live current
	local fillRoot = root(fx.fill)
	local stripes = fx.sprite(fillRoot, "charged-t/stripes", { x = 44, y = 116, w = 480, h = 48, z = 1 })
	local barRoot = root(fx.bar)
	-- the empty channel's volt halftone (only right of the fill, like the bench's bar background)
	local emptyClip = fx.rect(barRoot, { x = 400, y = 116, w = 96, h = 48, transparency = 1, z = 1 })
	emptyClip.ClipsDescendants = true
	local emptyDots = fx.dots(emptyClip, { w = 392, h = 48, color = C.voltL, alpha = 0.22, pitch = 7 })
	local cells, forks = {}, {}
	for i = 1, 3 do
		cells[i] = fx.sprite(barRoot, "charged-t/cell1", { z = 3 })
		forks[i] = fx.sprite(barRoot, "charged-t/forkU", { w = 28, h = 28, z = 3 })
	end
	fx.rect(barRoot, { x = 232, y = 112, w = 6, h = 56, color = C.ink, z = 4 })
	fx.rect(barRoot, { x = 362, y = 112, w = 6, h = 56, color = C.ink, z = 4 })

	-------------------------------------------------------------------- in front: minus-terminal glyph, sparks, discharge
	local frontRoot = root(fx.front)
	local cx, cy, cw, ch = fx.chipRect()
	fx.sprite(frontRoot, "charged-t/glyph", { x = cx + cw * 12 / 64, y = cy + ch * 4 / 64, w = cw * 38 / 64, h = ch * 56 / 64, z = 2 })
	local sp = {}
	for i = 1, 8 do sp[i] = fx.sprite(frontRoot, "charged-s/spark1", { z = 3 }) end
	local payG = root(frontRoot)
	payG.ZIndex = 5
	local burst = fx.sprite(payG, "charged-s/burst12_1", { x = 548, y = 52, w = 118, h = 118, anchor = Vector2.new(0.5, 0.5), color = C.volt, z = 1 })
	local big = fx.sprite(payG, "charged-s/big1", { z = 2 })
	local bigF = fx.sprite(payG, "charged-s/bigfork1", { z = 2 })
	local bigF2 = fx.sprite(payG, "charged-s/bigtail1", { z = 2 })
	local tWord = mkWord("ZAP!", 34, C.volt, 6)
	local tBig = mkWord("ZZAK!", 40, C.white, 5)
	setWord(tBig, "ZZAK!", 468, 32)

	local wAt, pAt, popAt, shakeAt = -9, -9, -9, -9
	local boilT, on0, hp0 = 0, nil, nil

	local function boil(st)
		for i = 1, 3 do
			local on = st.on and st.s >= i
			cells[i].Visible, forks[i].Visible = on, on
			if on then
				local x0 = 104 + (i - 1) * 130 + 8
				fx.setSprite(cells[i], "charged-t/cell" .. rnd(1, 3))
				lay(cells[i], SPEC.cell, x0, 140, x0 + 118, 140, false)
				local up = rnd() < 0.5
				fx.setSprite(forks[i], up and "charged-t/forkU" or "charged-t/forkD")
				local jx, jy = x0 + 20 + rnd() * 78, 140 + (rnd() - 0.5) * 16
				forks[i].Position = fx.P(jx - 6, jy - 14)
			end
		end
		local n = st.pay and 8 or st.on and st.s * 2 + 1 or 0
		for i = 1, 8 do
			local e = sp[i]
			e.Visible = i <= n
			if i <= n then
				local top = (i - 1) % 3 ~= 2
				local x = top and 40 + rnd() * 470 or ((i % 2 == 1) and 8 or 520)
				local y = top and 94 or 110 + rnd() * 60
				local len = 14 + rnd() * 16 + st.s * 5
				local a = top and (-math.pi / 2 + (rnd() - 0.5) * 1.2) or ((x < 100 and math.pi or 0) + (rnd() - 0.5) * 1.4)
				fx.setSprite(e, "charged-s/spark" .. rnd(1, 3))
				lay(e, SPEC.spark, x, y, x + math.cos(a) * len, y + math.sin(a) * len)
			end
		end
		payG.Visible = st.pay
		if st.pay then
			fx.setSprite(big, "charged-s/big" .. rnd(1, 2))
			lay(big, SPEC.big, 542, 140, 604, 40)
			local f = 0.2 + rnd() * 0.6
			local jx, jy = 542 + 62 * f, 140 - 100 * f
			local a = math.atan2(-100, 62) + (rnd() < 0.5 and -0.8 or 0.8)
			fx.setSprite(bigF, "charged-s/bigfork" .. rnd(1, 2))
			lay(bigF, SPEC.bigfork, jx, jy, jx + math.cos(a) * 30, jy + math.sin(a) * 30)
			fx.setSprite(bigF2, "charged-s/bigtail" .. rnd(1, 2))
			lay(bigF2, SPEC.bigtail, 604, 40, 636, 12)
			fx.setSprite(burst, "charged-s/burst12_" .. rnd(1, 2))
			burst.Rotation = rnd() * 360
		end
	end

	local self = {}
	function self.event(name, st)
		if name == "on" then popAt = fx.clock end
		if name == "stack" then
			if st.s >= 3 then shakeAt = fx.clock else popAt = fx.clock end
			local s = math.clamp(st.s, 1, 3)
			setWord(tWord, ({ "ZAP!", "ZZAP!", "ZZZAP!" })[s], 130 + (s - 1) * 123, 44)
			wAt = fx.clock
		end
		if name == "pay" then pAt = fx.clock; shakeAt = fx.clock end
		boil(st)
	end
	function self.update(st, dt)
		local now = fx.clock
		case.Visible, barRoot.Visible, fillRoot.Visible, frontRoot.Visible = st.on, st.on, st.on, st.on
		-- casing: squash pop (steps 3 over .3 s) or a stepped shake (4 steps of .06 s, twice)
		local sx, sy, dx, dy = 1, 1, 0, 0
		local pe = now - popAt
		if pe >= 0 and pe < 0.3 then
			if pe < 0.1 then sx, sy = 1.08, 0.86 elseif pe < 0.2 then sx, sy = 1.007, 0.993 else sx, sy = 0.98, 1.04 end
		end
		local se = now - shakeAt
		if se >= 0 and se < 0.48 then
			local o = ({ { -3, 1 }, { 3, -2 }, { -2, -1 }, { 2, 2 } })[math.floor((se % 0.24) / 0.06) + 1]
			dx, dy = o[1], o[2]
		end
		case.Position = fx.P(270 * (1 - sx) + dx, 140 * (1 - sy) + dy)
		case.Size = fx.S(640 * sx, 240 * sy)
		-- shell colour: violet, hotter at 3 stacks, flashing white / volt-light on the discharge
		local pa = now - pAt
		if st.pay and pa < 1 then
			shell.BackgroundColor3 = (pa % 0.5) < 0.25 and C.white or C.voltL
		else
			shell.BackgroundColor3 = st.s >= 3 and SHELL3 or C.voltM
		end
		for i = 1, 3 do
			lamps[i].BackgroundColor3 = st.pay and C.white or (st.s >= i and C.volt or C.voltD)
		end
		local tw = 372 * (st.pay and 0 or st.t)
		tTime.Visible = tw > 0.5
		tTime.Size = fx.S(math.max(tw, 0.5), 8)
		-- fill stripes crawl right in 10 px steps (0.6 s a period, 0.3 s at 3 stacks)
		local stepDur = st.s >= 3 and 0.05 or 0.1
		stripes.Position = fx.P(44 + (math.floor(now / stepDur) % 6) * 10, 116)
		fx.setSprite(stripes, st.pay and "charged-t/stripes_pay" or "charged-t/stripes")
		-- the empty channel's halftone
		if st.hp ~= hp0 then
			hp0 = st.hp
			local hx = 104 + 392 * math.clamp(st.hp, 0, 1)
			local cwid = math.max(1, 496 - hx)
			emptyClip.Position = fx.P(hx, 116)
			emptyClip.Size = fx.S(cwid, 48)
			emptyDots.Size = UDim2.fromScale(392 / cwid, 1)
			emptyDots.Position = UDim2.fromScale(-(hx - 104) / cwid, 0)
			emptyDots.TileSize = UDim2.fromScale(7 / 392, 7 / 48)
		end
		boilT += dt
		if boilT > 0.1 or st.on ~= on0 then boilT = 0; boil(st) end
		wordPop(tWord, now - wAt, 0.7, -7)
		wordPop(tBig, now - pAt, 1, 8, 1.4)
		on0 = st.on
	end
	return self
end

return V
