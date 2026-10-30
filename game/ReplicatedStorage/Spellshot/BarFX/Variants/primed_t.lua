--!nocheck
-- Aerial Bomb: the whole health bar becomes a cartoon aerial bomb whose fuse burns back to the nose, then KA-BOOM!.
-- Ported from status_fx/bench/opts/primed-t.html (round 2, 2026-09-24).
local V = { title = "Aerial Bomb" }

-- the fuse path (M56 108 C56 84 64 62 96 60 S150 80 196 64 S270 34 318 58 S392 86 440 60 S506 30 540 52),
-- resampled at 48 equal arc lengths; the spark sits at fraction t of it, measured from the nose
local FUSE = { 56.0,108.0, 56.7,96.9, 59.1,86.0, 63.9,75.9, 71.5,67.9, 81.4,62.8, 92.3,60.3, 103.4,60.0, 114.5,61.2,
	125.4,63.6, 136.3,66.2, 147.2,68.5, 158.3,69.7, 169.5,69.6, 180.5,68.2, 191.3,65.5, 201.9,61.9, 212.4,58.2, 223.0,54.5,
	233.6,51.1, 244.4,48.2, 255.4,46.1, 266.5,45.2, 277.6,45.6, 288.7,47.3, 299.4,50.2, 309.8,54.2, 319.9,59.0, 330.0,63.8,
	340.3,68.2, 350.7,72.1, 361.4,75.2, 372.4,77.2, 383.6,77.8, 394.7,76.9, 405.6,74.5, 416.2,71.1, 426.5,66.8, 436.5,61.8,
	446.4,56.6, 456.3,51.5, 466.4,46.7, 476.7,42.5, 487.4,39.3, 498.5,37.8, 509.6,38.5, 520.3,41.6, 530.4,46.3, 540.0,52.0 }
local function fusePoint(f)
	local n = #FUSE / 2 - 1
	local x = math.clamp(f, 0, 1) * n
	local i = math.clamp(math.floor(x), 0, n - 1)
	local u = x - i
	local ax, ay, bx, by = FUSE[2 * i + 1], FUSE[2 * i + 2], FUSE[2 * i + 3], FUSE[2 * i + 4]
	return ax + (bx - ax) * u, ay + (by - ay) * u
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
			e.Position = UDim2.fromScale((sp.size / 2 + d[1] * ph) / sp.size, (sp.size / 2 + d[2] * ph) / sp.size)   -- (2026-10-19, audit GA-17) the spark's centre, as primed_f
			e.Size = UDim2.fromScale(4 * k / sp.size, 4 * k / sp.size)
		end
	end

	-- the real HUD: the empty channel goes gunmetal, the badge becomes the steel nose, the label goes yellow
	fx.restyle("bar", { BackgroundColor3 = GUN })
	fx.restyle("chip", { BackgroundColor3 = C.steel })
	fx.restyle("label", { TextColor3 = C.pyroY })

	------------------------------------------------------------------ back
	local collar = box(fx.back, { x = 78, y = 122, w = 30, h = 36, color = C.white, stroke = 4, z = 9 })
	grad(collar, seq({ { C.steelL, 0.25 }, { C.steel, 0.7 }, { C.steelD, 1 } }), 90)
	local fins = fx.sprite(fx.back, "primed-t/fins", { x = 452, y = 78, w = 120, h = 124, z = 8 })
	local boom1 = fx.sprite(fx.back, "primed-t/boom1", { x = 320, y = 103, w = 500, h = 190, anchor = Vector2.new(0.5, 0.5), z = 6, visible = false })
	local boom2 = fx.sprite(fx.back, "primed-t/boom2", { x = 320, y = 100, w = 340, h = 140, anchor = Vector2.new(0.5, 0.5), z = 7, visible = false })
	local b1s, b2s = Instance.new("UIScale"), Instance.new("UIScale")
	b1s.Parent = boom1
	b2s.Parent = boom2

	------------------------------------------------------------------ fill: riveted casing, heat, char
	local casing = fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.white, z = 1 })
	local SEQ_STEEL = seq({ { C.steelL, 0.2 }, { C.steel, 0.66 }, { C.steelD, 1 } })
	local SEQ_HEAT = seq({ { C.pyroL, 0.2 }, { C.pyro, 0.66 }, { C.redD, 1 } })
	local SEQ_HOT_A = seq({ { C.paper, 0.2 }, { C.pyroY, 0.66 }, { C.pyro, 1 } })
	local SEQ_HOT_B = seq({ { C.pyroL, 0.2 }, { C.red, 0.66 }, { C.pyroD, 1 } })
	local cg = grad(casing, SEQ_STEEL, 90)
	local rivT = fx.sprite(fx.fill, "primed-t/rivets", { x = 104, y = 117, w = 400, h = 12, color = C.steelL, z = 2 })
	local rivB = fx.sprite(fx.fill, "primed-t/rivets", { x = 104, y = 149, w = 400, h = 12, color = C.steelL, z = 2 })
	local char = fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.paper, z = 3, visible = false })
	local charDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.pyro, alpha = 1, pitch = 8, z = 4 })
	charDots.Visible = false
	local edge = fx.rect(fx.fill, { x = 400, y = 116, w = 4, h = 48, color = C.ink, z = 5 })

	------------------------------------------------------------------ bar: faint white dots on the empty channel
	local emptyClip = fx.rect(fx.bar, { x = 496, y = 116, w = 100, h = 48, anchor = Vector2.new(1, 0), transparency = 1, z = 1 })
	emptyClip.ClipsDescendants = true
	local emptyDots = fx.dots(emptyClip, { x = 0, y = 0, w = 392, h = 48, color = C.white, alpha = 0.12, pitch = 7 })
	emptyDots.AnchorPoint = Vector2.new(1, 0)
	emptyDots.Position = UDim2.fromScale(1, 0)

	------------------------------------------------------------------ front
	-- the badge's steel bands (the kit's badge is one colour; the bench's is a 3-band gradient)
	local cx, cy, cw, ch = fx.chipRect()
	local chipHi = fx.rect(fx.front, { x = cx + 5, y = cy + 5, w = cw - 10, h = 0.26 * (ch - 10), color = C.steelL, corner = 9, z = 1 })
	local chipLo = fx.rect(fx.front, { x = cx + 5, y = cy + 0.75 * ch, w = cw - 10, h = 0.25 * ch - 5, color = C.steelD, corner = 9, z = 1 })
	local bandA = fx.sprite(fx.front, "primed-t/band", { x = 196, y = 104, w = 18, h = 72, z = 25 })
	local bandB = fx.sprite(fx.front, "primed-t/band", { x = 310, y = 104, w = 18, h = 72, z = 25 })
	local haz = fx.sprite(fx.front, "primed-t/haz", { x = 412, y = 106, w = 34, h = 68, z = 24 })
	local cd = text(fx.front, { text = "6", x = 371, y = 140, w = 70, h = 56, size = 44, color = C.pyroY, stroke = 3.5, z = 31 })
	-- the fuse: two baked tiles inside a clip that ends at the spark
	local fuseClip = fx.rect(fx.front, { x = 0, y = 0, w = 640, h = 240, transparency = 1, z = 44 })
	fuseClip.ClipsDescendants = true
	local fuseIn = Instance.new("Frame")
	fuseIn.BackgroundTransparency = 1
	fuseIn.Size = UDim2.fromScale(1, 1)
	fuseIn.Parent = fuseClip
	fx.sprite(fuseIn, "primed-t/fuse_l", { x = 44, y = 29, w = 256, h = 87 })
	fx.sprite(fuseIn, "primed-t/fuse_r", { x = 300, y = 29, w = 252, h = 87 })
	local cap = box(fx.front, { x = 44, y = 96, w = 24, h = 16, color = C.steelD, stroke = 4, corner = 3, z = 45 })
	local sp = spark(fx.front, 34, 46)
	-- payoff
	local word = text(fx.front, { text = "KA-BOOM!", x = 330, y = 52, w = 420, h = 80, size = 58, color = C.pyroY, stroke = 4, shadow = 4, z = 55 })
	word.holder.Visible = false
	local SHARDS = { { 196, 110, -60, -80, -200 }, { 310, 110, 40, -90, 260 }, { 440, 110, 90, -60, 320 },
		{ 250, 140, -30, 40, -140 }, { 380, 140, 50, 36, 180 }, { 480, 130, 70, 30, 220, true } }
	local shards = {}
	for i, d in ipairs(SHARDS) do
		local f = fx.rect(fx.front, { x = d[1] + 11, y = d[2] + 15, w = 14, h = 22, anchor = Vector2.new(0.5, 0.5), color = d[6] and C.pyroY or C.white,
			corner = 1, stroke = 4, z = 50, visible = false })
		if not d[6] then grad(f, seq({ { C.steelL, 0.35 }, { C.steel, 0.7 }, { C.steelD, 1 } }), 0) end
		shards[i] = f
	end

	local nopay = { fins, bandA, bandB, haz, cd.holder, fuseClip, cap, sp.holder }
	local lastSec, payAt = 0, nil
	local layers = { fx.back, fx.bar, fx.fill, fx.front }

	local self = {}
	function self.event(name, st)
		if name == "on" then lastSec = 0; payAt = nil
		elseif name == "pay" then
			payAt = fx.clock
			fx.shake(7, 0.4)
		end
	end
	function self.update(st, dt)
		for _, l in ipairs(layers) do l.Visible = st.on end
		if not st.on then return end
		if st.pay and not payAt then payAt = fx.clock; fx.shake(7, 0.4) end
		if not st.pay then payAt = nil end
		local pay = payAt ~= nil
		local pt = pay and (fx.clock - payAt) or 0
		local heat = st.t < 0.34 and 2 or st.t < 0.67 and 1 or 0

		for _, o in ipairs(nopay) do o.Visible = not pay end
		local hp = math.clamp(st.hp, 0, 1)
		local ex = 104 + 392 * hp
		edge.Position = fx.P(ex - 4, 116)
		local ew = math.max(1, 392 * (1 - hp))
		emptyClip.Size = fx.S(ew, 48)
		emptyDots.Size = UDim2.fromScale(392 / ew, 1)
		emptyDots.TileSize = UDim2.fromScale(7 / 392, 7 / 48)

		if pay then
			casing.Visible, rivT.Visible, rivB.Visible = false, false, false
			char.Visible = true
			local charred = pt >= 0.096
			char.BackgroundColor3 = charred and C.ink or C.paper
			charDots.Visible = charred
			boom1.Visible, boom2.Visible, word.holder.Visible = true, true, true
			local s1, r1 = kf(POP, pt / 0.5, 5)
			b1s.Scale = math.max(0.001, s1); boom1.Rotation = r1
			local s2, r2 = kf(POP, (pt - 0.04) / 0.5, 5)
			b2s.Scale = math.max(0.001, pt < 0.04 and 0.001 or s2); boom2.Rotation = r2
			local s3, r3 = kf(POP, pt / 0.45, 5)
			word.scale.Scale = math.max(0.001, s3); word.holder.Rotation = r3
			local p = math.floor(math.clamp(pt / 0.6, 0, 1) * 6) / 6
			for i, f in ipairs(shards) do
				local d = SHARDS[i]
				f.Visible = true
				f.Position = fx.P(d[1] + 11 + d[3] * p, d[2] + 15 + d[4] * p)
				f.Rotation = d[5] * p
			end
			return
		end
		char.Visible, charDots.Visible = false, false
		boom1.Visible, boom2.Visible, word.holder.Visible = false, false, false
		for _, f in ipairs(shards) do f.Visible = false end

		-- casing heat
		casing.Visible = true
		if heat == 0 then
			cg.Color = SEQ_STEEL
			rivT.Visible, rivB.Visible = true, true
			rivT.ImageColor3, rivB.ImageColor3 = C.steelL, C.steelL
		elseif heat == 1 then
			cg.Color = SEQ_HEAT
			rivT.Visible, rivB.Visible = true, true
			rivT.ImageColor3, rivB.ImageColor3 = C.pyroY, C.pyroY
		else
			-- (2026-10-19, audit P5F-04) Reduce Flashing: the hot casing holds still instead of a 2.5 Hz red/yellow toggle
			cg.Color = (fx.calm() or (fx.clock % 0.4) < 0.2) and SEQ_HOT_A or SEQ_HOT_B
			rivT.Visible, rivB.Visible = false, false
			fx.shake(1.5, 0.05)
		end

		-- fuse burns back toward the nose
		local t = math.max(0.02, st.t)
		local sx, sy = fusePoint(t)
		fuseClip.Size = fx.S(math.max(1, sx), 240)
		fuseIn.Size = UDim2.fromScale(640 / math.max(1, sx), 1)
		sparkStep(sp, sx, sy)

		-- stencil countdown
		local s = math.max(1, math.ceil(st.t * (st.total or 6) - 1e-6))   -- (2026-10-19, audit GA-04) real seconds left: st.total is the fuse (Detonate 1.5 s), 6 only on the bench
		if s ~= lastSec then
			lastSec = s
			cd.label.Text = tostring(s)
			cd.born = fx.clock
		end
		local hot = heat == 2
		if cd.hot ~= hot then
			cd.hot = hot
			cd.label.TextColor3 = hot and C.white or C.pyroY
			fx.px(cd.label, "TextSize", hot and 50 or 44)
		end
		local ts, tr = kf(TICK, (fx.clock - (cd.born or -1)) / 0.35, 4)
		cd.scale.Scale = ts
		cd.holder.Rotation = tr
	end
	return self
end

return V
