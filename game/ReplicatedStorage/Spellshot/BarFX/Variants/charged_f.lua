--!nocheck
-- Live Wire: the fill turns into an insulated cable carrying current; each stack adds a lane of lightning along the
-- whole fill and a purple bolt behind the bar, a crackling node rides the fill's end, three stacks turn it acid volt,
-- the discharge fires from the node and leaves the fill spent. Ported from status_fx/bench/opts/charged-f.html
-- (round 2, 2026-09-24).
local V = { title = "Live Wire" }

-- bolt sprites: { pad, H, amp } of the baked strip (ends at pad and pad + L on the mid line), see sprites/charged-*
local SPEC = { spark = { 5.5, 21 }, big = { 10.5, 53 }, bigfork = { 7.5, 31 }, bigtail = { 6.5, 29 }, arc = { 7, 40 },
	laneM = { 7.5, 39, 12 }, laneT = { 5.75, 27.5, 8 } }

function V.mount(fx)
	local C = fx.C
	local rnd = math.random
	local function root(layer) return fx.rect(layer, { x = 0, y = 0, w = 640, h = 240, transparency = 1 }) end
	local function lay(img, spec, x1, y1, x2, y2, rot, amp)
		local dx, dy = x2 - x1, y2 - y1
		local L = math.sqrt(dx * dx + dy * dy)
		local H = spec[2]
		if amp then H = 2 * amp + 2 * spec[1] end
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = fx.P((x1 + x2) / 2, (y1 + y2) / 2)
		img.Size = fx.S(L + 2 * spec[1], H)
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

	-- the cable: purple jacket + ink rings, light-volt chip, volt-light label
	fx.restyle("bar", { BackgroundColor3 = C.voltD })
	fx.restyle("fill", { BackgroundColor3 = C.voltM })
	fx.restyle("chip", { BackgroundColor3 = C.voltL })
	fx.restyle("label", { TextColor3 = C.voltL })

	-------------------------------------------------------------------- behind: jacket rings and purple bolts
	local backRoot = root(fx.back)
	local bs = {}
	for i = 1, 4 do bs[i] = fx.sprite(backRoot, "charged-s/arc1", { z = 1 }) end
	fx.rect(backRoot, { x = 97, y = 109, w = 414, h = 70, corner = 35, color = C.ink, z = 3 })
	fx.rect(backRoot, { x = 93, y = 105, w = 414, h = 70, corner = 35, color = C.ink, z = 4 })
	fx.rect(backRoot, { x = 96, y = 108, w = 408, h = 64, corner = 32, color = C.voltM, z = 5 })
	local cx, cy, cw, ch = fx.chipRect()
	fx.rect(backRoot, { x = cx - 7, y = cy - 7, w = cw + 14, h = ch + 14, corner = 21, color = C.ink, z = 3 })
	fx.rect(backRoot, { x = cx - 4, y = cy - 4, w = cw + 8, h = ch + 8, corner = 18, color = C.voltM, z = 4 })

	-------------------------------------------------------------------- the empty channel's violet halftone
	local barRoot = root(fx.bar)
	local emptyClip = fx.rect(barRoot, { x = 400, y = 116, w = 96, h = 48, transparency = 1, z = 1 })
	emptyClip.ClipsDescendants = true
	local emptyDots = fx.dots(emptyClip, { w = 392, h = 48, color = C.voltM, alpha = 0.55, pitch = 7 })

	-------------------------------------------------------------------- the living fill: halftone, timer, lanes
	local fillRoot = root(fx.fill)
	local fDots = fx.dots(fillRoot, { x = 104, y = 116, w = 392, h = 48, color = C.ink, alpha = 0.25, pitch = 7, z = 1 })
	local fTime = fx.rect(fillRoot, { x = 104, y = 120, w = 392, h = 6, color = C.white, stroke = 2, z = 3 })
	local lanes = {}
	lanes[1] = fx.sprite(fillRoot, "charged-f/laneM1", { z = 4 })
	lanes[2] = fx.sprite(fillRoot, "charged-f/laneT1", { z = 4 })
	lanes[3] = fx.sprite(fillRoot, "charged-f/laneT1", { z = 4 })

	-------------------------------------------------------------------- in front: discharge, sparks, the riding node
	local frontRoot = root(fx.front)
	local payG = root(frontRoot)
	payG.ZIndex = 1
	local fBurst = fx.sprite(payG, "charged-s/burst12_1", { x = 385, y = 62, w = 283, h = 108, anchor = Vector2.new(0.5, 0.5), color = C.volt, z = 1 })
	local big = fx.sprite(payG, "charged-s/big1", { z = 2 })
	local bigF = fx.sprite(payG, "charged-s/bigfork1", { z = 2 })
	local bigF2 = fx.sprite(payG, "charged-s/bigtail1", { z = 2 })
	local sp = {}
	for i = 1, 8 do sp[i] = fx.sprite(frontRoot, "charged-s/spark1", { z = 3 }) end
	local headB = fx.sprite(frontRoot, "charged-s/burst8_1", { anchor = Vector2.new(0.5, 0.5), color = C.volt, z = 4 })
	local headC = fx.sprite(frontRoot, "charged-s/burst6_1", { anchor = Vector2.new(0.5, 0.5), z = 5 })
	local fWord = mkWord("ZAP!", 34, C.volt, 6)
	local fBig = mkWord("DISCHARGE!", 40, C.white, 10)
	setWord(fBig, "DISCHARGE!", 282, 24)

	local wAt, pAt = -9, -9
	local boilT, on0, hp0, look0 = 0, nil, nil, nil

	local function spentNow(st) return st.pay and fx.clock - pAt > 0.45 end

	local function boil(st)
		local w = 392 * math.clamp(st.hp, 0, 1)
		local s = st.pay and 3 or st.s
		local spent = spentNow(st)
		local three = s >= 3 and not st.pay
		-- lanes of live current along the whole fill (purple bolts once the fill turns acid at 3 stacks)
		local Y, A = { 140, 129, 151 }, { 9, 5, 5 }
		local nL = spent and 0 or st.pay and 3 or s
		for i = 1, 3 do
			local on = st.on and i <= nL
			lanes[i].Visible = on
			if on then
				local base = i == 1 and "laneM" or "laneT"
				fx.setSprite(lanes[i], "charged-f/" .. base .. (three and "p" or "") .. rnd(1, 3))
				lay(lanes[i], SPEC[base], 98, Y[i], 104 + w + 6, Y[i] + (rnd() - 0.5) * 8, false, A[i] + s * 2)
			end
		end
		-- the leading edge: a crackling node riding the end of the fill
		local hx, hy = 104 + w, 140
		local r = spent and 10 or 16 + s * 4
		fx.setSprite(headB, "charged-s/burst8_" .. rnd(1, 2))
		headB.Position = fx.P(hx, hy)
		headB.Size = fx.S(r * 2.533, r * 2.533)
		headB.Rotation = rnd() * 360
		fx.setSprite(headC, "charged-s/burst6_" .. rnd(1, 2))
		headC.Position = fx.P(hx, hy)
		headC.Size = fx.S(r * 0.5 * 2.617, r * 0.5 * 2.617)
		headC.Rotation = rnd() * 360
		-- sparks leaping off the fill's top and bottom edges along its length
		local n = spent and 2 or st.on and 2 + s * 2 or 0
		for i = 1, 8 do
			local e = sp[i]
			e.Visible = i <= n
			if i <= n then
				local top = (i - 1) % 3 ~= 2
				local x = 110 + rnd() * math.max(0, w - 10)
				local y = top and 110 or 170
				local len = 14 + rnd() * 12 + s * 5
				local a = (top and -math.pi / 2 or math.pi / 2) + (rnd() - 0.5) * 1.1
				fx.setSprite(e, "charged-s/spark" .. rnd(1, 3))
				lay(e, SPEC.spark, x, y, x + math.cos(a) * len, y + math.sin(a) * (top and len or math.min(len, 16)))
			end
		end
		-- big purple bolts behind the bar, one per stack
		for i = 1, 4 do
			local on = st.on and not spent and i <= s + (st.pay and 1 or 0)
			bs[i].Visible = on
			if on then
				local x = 130 + (i - 1) * 95 + rnd() * 30
				fx.setSprite(bs[i], "charged-s/arc" .. rnd(1, 3))
				lay(bs[i], SPEC.arc, x, 130, x + (rnd() - 0.5) * 50, 40 + rnd() * 30)
			end
		end
		payG.Visible = st.pay and not spent
		if payG.Visible then
			fx.setSprite(big, "charged-s/big" .. rnd(1, 2))
			lay(big, SPEC.big, hx, hy, 560, 60)
			local f = 0.2 + rnd() * 0.6
			local jx, jy = hx + (560 - hx) * f, hy + (60 - hy) * f
			local a = math.atan2(60 - hy, 560 - hx) + (rnd() < 0.5 and -0.8 or 0.8)
			fx.setSprite(bigF, "charged-s/bigfork" .. rnd(1, 2))
			lay(bigF, SPEC.bigfork, jx, jy, jx + math.cos(a) * 34, jy + math.sin(a) * 34)
			fx.setSprite(bigF2, "charged-s/bigtail" .. rnd(1, 2))
			lay(bigF2, SPEC.bigtail, 560, 60, 636, 14)
			fx.setSprite(fBurst, "charged-s/burst12_" .. rnd(1, 2))
		end
	end

	local self = {}
	function self.event(name, st)
		if name == "stack" then
			local s = math.clamp(st.s, 1, 3)
			setWord(fWord, ({ "ZAP!", "ZZAP!", "ZZZAP!" })[s], 140 + (s - 1) * 110, 40)
			wAt = fx.clock
		end
		if name == "pay" then pAt = fx.clock end
		if name == "end" then pAt = -9 end
		boil(st)
	end
	function self.update(st, dt)
		local now = fx.clock
		backRoot.Visible, barRoot.Visible, fillRoot.Visible, frontRoot.Visible = st.on, st.on, st.on, st.on
		-- the fill: violet, acid volt at 3 stacks, white on the discharge, spent violet after it
		local spent = spentNow(st)
		local look = spent and "spent" or st.pay and "pay" or st.s >= 3 and "three" or "base"
		if look ~= look0 then
			look0 = look
			local L = ({ base = { C.voltM, C.ink, 0.25 }, three = { C.volt, C.voltD, 0.35 }, pay = { C.white, C.ink, 0 },
				spent = { C.voltD, C.volt, 0.35 } })[look]
			fx.restyle("fill", { BackgroundColor3 = L[1] })
			fDots.ImageColor3 = L[2]
			fDots.ImageTransparency = 1 - L[3]
		end
		local hp = math.clamp(st.hp, 0, 1)
		local tw = 392 * hp * (st.pay and 0 or st.t)
		fTime.Visible = tw > 0.5
		fTime.Size = fx.S(math.max(tw, 0.5), 6)
		if hp ~= hp0 then
			hp0 = hp
			local hx = 104 + 392 * hp
			local cwid = math.max(1, 496 - hx)
			emptyClip.Position = fx.P(hx, 116)
			emptyClip.Size = fx.S(cwid, 48)
			emptyDots.Size = UDim2.fromScale(392 / cwid, 1)
			emptyDots.Position = UDim2.fromScale(-(hx - 104) / cwid, 0)
			emptyDots.TileSize = UDim2.fromScale(7 / 392, 7 / 48)
		end
		boilT += dt
		if boilT > 0.1 or st.on ~= on0 then boilT = 0; boil(st) end
		wordPop(fWord, now - wAt, 0.7, -7)
		wordPop(fBig, now - pAt, 1, -5, 1.35)
		on0 = st.on
	end
	return self
end

return V
