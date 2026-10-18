--!nocheck
-- Pressure Charge: the fill becomes a packed explosive charge in six second-segments, a pressure wedge rams through it
-- inside a hazard-tape frame, then a crack tears the bar open: KRA-KOOM!
-- Ported from status_fx/bench/opts/primed-f.html (round 2, 2026-09-24).
local V = { title = "Pressure Charge" }
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


	-- the real HUD: a near-black channel, a yellow badge
	fx.restyle("bar", { BackgroundColor3 = hex("#1D1D22") })
	fx.restyle("chip", { BackgroundColor3 = C.pyroY })
	local nopay = {}

	------------------------------------------------------------------ back: the scrolling hazard-tape frame, the ray bursts
	local tape = Instance.new("CanvasGroup")
	tape.BackgroundTransparency = 1
	tape.Position = fx.P(88, 100)
	tape.Size = fx.S(424, 80)
	tape.ZIndex = 9
	tape.Parent = fx.back
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0.5, 0)
	tc.Parent = tape
	local stripes = fx.sprite(tape, "primed-f/tape", { color = C.pyroY })
	stripes.Size = UDim2.fromScale(460 / 424, 1)
	local tapeRim = box(fx.back, { x = 88, y = 100, w = 424, h = 80, color = C.white, stroke = 4, corner = 40, z = 10 })
	tapeRim.BackgroundTransparency = 1
	nopay[#nopay + 1] = tape
	nopay[#nopay + 1] = tapeRim
	local rays = fx.sprite(fx.back, "primed-f/rays", { x = 310, y = 109, w = 540, h = 166, anchor = Vector2.new(0.5, 0.5), z = 7, visible = false })
	local rays2 = fx.sprite(fx.back, "primed-f/rays2", { x = 310, y = 112, w = 380, h = 136, anchor = Vector2.new(0.5, 0.5), z = 8, visible = false })
	local rS, r2S = Instance.new("UIScale"), Instance.new("UIScale")
	rS.Parent = rays
	r2S.Parent = rays2

	------------------------------------------------------------------ fill: the packed charge
	fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.pyroD, z = 1 })
	fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.pyro, alpha = 1, pitch = 8, z = 2 })
	fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 7.7, color = C.redD, z = 3 })
	fx.rect(fx.fill, { x = 104, y = 156.3, w = 392, h = 7.7, color = hex("#3A0B04"), z = 3 })
	local char = fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.paper, z = 4, visible = false })
	local charDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.pyro, alpha = 1, pitch = 8, z = 5 })
	charDots.Visible = false
	local edge = fx.rect(fx.fill, { x = 400, y = 116, w = 4, h = 48, color = C.ink, z = 6 })

	------------------------------------------------------------------ bar: empty-channel powder dots, the pressure wedge, notches
	local emptyClip = fx.rect(fx.bar, { x = 496, y = 116, w = 100, h = 48, anchor = Vector2.new(1, 0), transparency = 1, z = 1 })
	emptyClip.ClipsDescendants = true
	local emptyDots = fx.dots(emptyClip, { x = 0, y = 0, w = 392, h = 48, color = C.pyro, alpha = 0.35, pitch = 7 })
	emptyDots.AnchorPoint = Vector2.new(1, 0)
	emptyDots.Position = UDim2.fromScale(1, 0)

	local press = fx.rect(fx.bar, { x = 104, y = 116, w = 1, h = 48, transparency = 1, z = 2 })
	press.ClipsDescendants = true
	local pressIn = Instance.new("Frame")
	pressIn.BackgroundTransparency = 1
	pressIn.Size = UDim2.fromScale(1, 1)
	pressIn.Parent = press
	local pbody = Instance.new("Frame")
	pbody.BorderSizePixel = 0
	pbody.BackgroundColor3 = C.white
	pbody.Size = UDim2.fromScale(1, 1)
	pbody.Parent = pressIn
	grad(pbody, seq({ { C.pyroY, 0.24 }, { C.pyro, 0.7 }, { C.redD, 1 } }), 90)
	local chev = fx.sprite(pressIn, "primed-f/chevrons", {})
	chev.Size = UDim2.fromScale(420 / 392, 1)
	chev.ZIndex = 2
	local tip = fx.sprite(fx.bar, "primed-f/tip", { x = 100, y = 116, w = 28, h = 48, z = 3 })
	nopay[#nopay + 1] = press
	nopay[#nopay + 1] = tip
	local notches = {}
	for i = 1, 5 do
		local n = fx.rect(fx.bar, { x = 104, y = 116, w = 5, h = 48, color = C.ink, z = 4 })
		local c = box(fx.bar, { x = 100, y = 114, w = 13, h = 8, color = C.pyroY, stroke = 2, z = 5 })
		notches[i] = { n, c }
		nopay[#nopay + 1] = n
		nopay[#nopay + 1] = c
	end

	------------------------------------------------------------------ front: spark, countdown, PRIMED tag, payoff
	local sp = spark(fx.front, 44, 45)
	nopay[#nopay + 1] = sp.holder
	local cd = text(fx.front, { text = "6", x = 281, y = 140, w = 90, h = 72, size = 50, color = C.white, stroke = 4, shadow = 4, z = 31 })
	nopay[#nopay + 1] = cd.holder
	local tag = Instance.new("Frame")
	tag.BackgroundTransparency = 1
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = fx.P(472, 92)
	tag.Size = fx.S(640, 240)
	tag.Rotation = 6
	tag.ZIndex = 32
	tag.Parent = fx.front
	-- inside the tag frame the design space is re-centred on the tag (so it rotates about its own centre)
	local function tagP(x, y) return UDim2.fromScale(x / 640, y / 240) end
	local tagShadow = Instance.new("Frame")
	tagShadow.BorderSizePixel = 0
	tagShadow.BackgroundColor3 = C.ink
	tagShadow.Position = tagP(320 - 52 + 3, 120 - 17.5 + 3)
	tagShadow.Size = tagP(104, 35)
	tagShadow.ZIndex = 1
	tagShadow.Parent = tag
	fx.pxUDim(Instance.new("UICorner", tagShadow), 6)
	local tagBox = fx.rect(tag, { x = 320 - 52 + 4, y = 120 - 17.5 + 4, w = 96, h = 27, color = C.pyro, corner = 2, stroke = 4, z = 2 })
	local tagText = Instance.new("TextLabel")
	tagText.BackgroundTransparency = 1
	tagText.Position = tagP(320 - 52, 120 - 17.5 + 1.5)
	tagText.Size = tagP(104, 35)
	tagText.Font = Enum.Font.LuckiestGuy
	tagText.Text = "PRIMED"
	tagText.TextColor3 = C.white
	tagText.ZIndex = 3
	tagText.Parent = tag
	fx.px(tagText, "TextSize", 20)
	fx.stroke(tagText, 2.5, C.ink)
	nopay[#nopay + 1] = tag

	local crack = fx.sprite(fx.front, "primed-f/crack", { x = 96, y = 108, w = 408, h = 64, z = 33, visible = false })
	local word = text(fx.front, { text = "KRA-KOOM!", x = 320, y = 42, w = 440, h = 80, size = 56, color = C.pyroY, stroke = 4, shadow = 4, z = 55 })
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
		local hp = math.clamp(st.hp, 0, 1)
		edge.Position = fx.P(104 + 392 * hp - 4, 116)
		local ew = math.max(1, 392 * (1 - hp))
		emptyClip.Size = fx.S(ew, 48)
		emptyDots.Size = UDim2.fromScale(392 / ew, 1)
		emptyDots.TileSize = UDim2.fromScale(7 / 392, 7 / 48)

		if pay then
			local pt = fx.clock - payAt
			char.Visible = true
			local charred = pt >= 0.096
			char.BackgroundColor3 = charred and C.ink or C.paper
			charDots.Visible = charred
			local cf = pt >= 0.25 and 1 or math.floor(pt / 0.25 * 4) / 4
			crack.Visible = cf > 0
			crack.Size = fx.S(408 * math.max(cf, 0.01), 64)
			rays.Visible, rays2.Visible = true, pt >= 0.05
			local s1, r1 = kf(POP, pt / 0.5, 5)
			rS.Scale = math.max(0.001, s1); rays.Rotation = r1
			local s2, r2 = kf(POP, (pt - 0.05) / 0.5, 5)
			r2S.Scale = math.max(0.001, s2); rays2.Rotation = r2
			local e = pt - 0.08
			word.holder.Visible = e >= 0
			local s3, r3 = kf(POP, e / 0.45, 5)
			word.scale.Scale = math.max(0.001, s3); word.holder.Rotation = r3
			return
		end
		char.Visible, charDots.Visible, crack.Visible, word.holder.Visible = false, false, false, false
		rays.Visible, rays2.Visible = false, false
		if urg then fx.shake(1.5, 0.05) end

		-- hazard tape scrolls in steps; orange and double speed in the last seconds
		local dur = urg and 0.2 or 0.4
		local off = math.floor((fx.clock % dur) / dur * 4) * 28.284 / 4
		stripes.Position = UDim2.fromScale((off - 28.284) / 424, 0)
		stripes.ImageColor3 = urg and C.pyro or C.pyroY

		-- the pressure wedge: width hp * (1 - t)
		local xe = hp * (1 - st.t) * 392
		local pw = math.max(1, xe)
		press.Size = fx.S(pw, 48)
		pressIn.Size = UDim2.fromScale(392 / pw, 1)
		local ro = math.floor((fx.clock % 0.3) / 0.1) * 28 / 3
		chev.Position = UDim2.fromScale((ro - 28) / 392, 0)
		tip.Position = fx.P(104 + xe - 4, 116)
		for i, n in ipairs(notches) do
			local nx = 104 + hp * 392 * i / 6 - 2
			n[1].Position = fx.P(nx, 116)
			n[2].Position = fx.P(nx - 4 + 2, 114 + 2)
		end
		sparkStep(sp, 104 + xe + 10, 140)

		-- the PRIMED tag blinks when urgent
		tag.Visible = not urg or (fx.clock % 0.4) < 0.2

		-- the big numeral
		local s = math.max(1, math.ceil(st.t * 6 - 1e-6))
		if s ~= lastSec then
			lastSec = s
			cd.label.Text = tostring(s)
			cd.shadow.Text = tostring(s)
			cd.born = fx.clock
		end
		local hot = st.t < 0.34
		if cd.hot ~= hot then
			cd.hot = hot
			cd.label.TextColor3 = hot and C.pyroY or C.white
			fx.px(cd.label, "TextSize", hot and 60 or 50)
			fx.px(cd.shadow, "TextSize", hot and 60 or 50)
		end
		local ts, tr = kf(TICK, (fx.clock - (cd.born or -1)) / 0.35, 4)
		cd.scale.Scale = ts
		cd.holder.Rotation = tr
	end
	return self
end

return V
