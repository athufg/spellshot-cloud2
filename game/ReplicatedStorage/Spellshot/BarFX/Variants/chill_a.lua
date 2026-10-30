--!nocheck
-- Glacier Jaws: a glacier erupts around the bar and bites it with crystal jaws.
-- Ported from status_fx/bench/opts/chill-a.html (round 2, 2026-09-24). Crystal lists and baked sprites come from
-- sprites/chill-s/_gen.js, which replays the HTML's seeded generator (same RNG, same call order).
local V = { title = "Glacier Jaws" }

-- crystal data (x, y = base; w, h; rotation; pop delay), from _gen.js
local BACK = {
	{ 112, 136, 21.79, 46.76, -25.98, 0 },
	{ 148.54, 136, 18.82, 47.08, -19.59, 0.02 },
	{ 186.24, 136, 26.21, 74.94, -8.21, 0.04 },
	{ 215.12, 136, 20.3, 69.85, -17.83, 0.06 },
	{ 252.36, 136, 26.19, 51.31, -6.13, 0.08 },
	{ 288.02, 136, 23.46, 69.87, -3.51, 0.1 },
	{ 320.62, 136, 19.15, 63.58, -5.33, 0.12 },
	{ 355.68, 136, 27.37, 49.82, 8.5, 0.14 },
	{ 384.36, 136, 27.3, 48.75, 12.94, 0.16 },
	{ 423.51, 136, 25.94, 57.92, 15.89, 0.18 },
	{ 458.82, 136, 24.21, 77.96, 19.58, 0.2 },
	{ 495.85, 136, 23.28, 66.15, 25.25, 0.22 },
	{ 142.18, 128, 12, 28.45, -27.68, 0.1 },
	{ 213.9, 128, 12, 33.63, -22.53, 0.12 },
	{ 274.1, 128, 12, 37.96, -14.48, 0.14 },
	{ 343.17, 128, 12, 38.94, 5.42, 0.16 },
	{ 410.46, 128, 12, 35.25, 33.33, 0.18 },
	{ 472.7, 128, 12, 36.31, 30.38, 0.2 },
}
local UPPER = {
	{ 118, 104, 13.26, 24.97, 184.18, 0 },
	{ 154, 104, 14.55, 23.57, 184.69, 0.015 },
	{ 190, 104, 13.05, 26.98, 175.58, 0.03 },
	{ 226, 104, 14.93, 23.46, 175.13, 0.045 },
	{ 262, 104, 15.14, 28.12, 173.56, 0.06 },
	{ 298, 104, 14.09, 25.07, 184.68, 0.075 },
	{ 334, 104, 14.44, 31.76, 186.06, 0.09 },
	{ 370, 104, 15.96, 23.48, 179.12, 0.105 },
	{ 406, 104, 13.14, 26.91, 174.03, 0.12 },
	{ 442, 104, 14.79, 24.44, 179.41, 0.135 },
	{ 478, 104, 14.06, 27.82, 175.72, 0.15 },
}
local LOWER = {
	{ 136, 176, 14.07, 20.43, 3.67, 0.05 },
	{ 172, 176, 13.3, 26.85, 0.5, 0.065 },
	{ 208, 176, 14.37, 17.18, 3.64, 0.08 },
	{ 244, 176, 14.4, 24.34, 6.63, 0.095 },
	{ 280, 176, 15.27, 17.69, -0.18, 0.11 },
	{ 316, 176, 14.1, 24.97, 2.45, 0.125 },
	{ 352, 176, 14.31, 23.15, 7, 0.14 },
	{ 388, 176, 13.95, 22.74, -6.03, 0.155 },
	{ 424, 176, 14.85, 20.23, -2.44, 0.17 },
	{ 460, 176, 14.55, 26.57, -4.75, 0.185 },
}
local ENDS = {
	{ 102, 140, 20, 44, -96, 0.02 },
	{ 104, 124, 14, 30, -55, 0.06 },
	{ 104, 158, 14, 30, -135, 0.09 },
	{ 498, 140, 20, 44, 96, 0.02 },
	{ 496, 124, 14, 30, 55, 0.06 },
	{ 496, 158, 14, 30, 135, 0.09 },
}
-- the glints on the crystal tips
local STARS = { { 150, 70 }, { 262, 58 }, { 356, 64 }, { 458, 76 }, { 528, 118 } }

-- CSS popIn (0 -> 1.25 -> .92 -> 1) with steps(5) applied inside every keyframe segment
local KF = { { 0, 0 }, { 0.4, 1.25 }, { 0.7, 0.92 }, { 1, 1 } }
local function popScale(age, dur)
	if age < 0 then return 0 end
	local p = age / dur
	if p >= 1 then return 1 end
	for i = 1, 3 do
		local a, b = KF[i], KF[i + 1]
		if p < b[1] then
			local u = math.floor((p - a[1]) / (b[1] - a[1]) * 5) / 5
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return 1
end
local function R(seed)
	local s = seed
	return function()
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

function V.mount(fx)
	local C = fx.C
	local V2 = Vector2.new
	local FILL_ICE = Color3.fromRGB(0xB8, 0x20, 0x2A)   -- #B8202A, the frozen red

	-- a crystal: one ImageLabel, placed by its base; the sprite's centre is the crystal's centre
	local function crystal(parent, row, z)
		local x, y, w, h, rot, d = table.unpack(row)
		local big = h >= 34
		local img = fx.sprite(parent, big and "chill-s/xtal" or "chill-s/xtal_s", { z = z })
		img.AnchorPoint = V2(0.5, 0.5)
		img.Visible = false
		return { img = img, x = x, y = y, w = w, h = h, rot = rot, d = d, pw = big and 28 / 24 or 17 / 13, ph = big and 84 / 80 or 30 / 26 }
	end
	-- place with a scale (sx across, sy along the crystal) about its base; optional group scale gp about (gx, gy)
	local function placeX(c, sx, sy, gp, gx, gy)
		gp = gp or 1
		if sx * sy * gp <= 0.001 then c.img.Visible = false return end
		c.img.Visible = true
		local bx, by = c.x, c.y
		if gx then bx, by = gx + (bx - gx) * gp, gy + (by - gy) * gp end
		local w, h = c.w * sx * gp, c.h * sy * gp
		local r = math.rad(c.rot)
		c.img.Position = fx.P(bx + h / 2 * math.sin(r), by - h / 2 * math.cos(r))
		c.img.Size = fx.S(w * c.pw, h * c.ph)
		c.img.Rotation = c.rot
	end
	-- "the element became displayed" clock (CSS animations restart on display)
	local function shown()
		local g = {}
		function g.age(v)
			if not v then g.born = nil return -1 end
			if not g.born then g.born = fx.clock end
			return fx.clock - g.born
		end
		return g
	end
	local function mkWord(text, x, y, w, h, rot, sprite, color)
		local holder = fx.word(fx.front, text, { x = x, y = y, size = 30, color = color, stroke = 3, rotation = rot,
			burst = sprite, burstW = w + 16, burstH = h + 16, pop = false, z = 50 })
		holder.Visible = false
		return { holder = holder, sc = holder:FindFirstChildOfClass("UIScale") }
	end
	local function popW(wd, dt)
		if not wd.holder.Parent then return end
		if dt < 0 then wd.holder.Visible = false return end
		wd.holder.Visible = true
		wd.sc.Scale = (dt < 0.05 and 0.45) or (dt < 0.1 and 1.28) or (dt < 0.15 and 0.92) or 1
	end
	local function mkShards(parent, n, box, cx, cy, seed)
		local r, L = R(seed), {}
		local cols = { C.cryoL, C.cryo, C.cryoM, C.white, C.cryoD }
		for i = 0, n - 1 do
			local s = 7 + r() * 13
			local u = r()
			local name = (u < 1 / 3 and "chill-s/shard_a") or (u < 2 / 3 and "chill-s/shard_b") or "chill-s/shard_c"
			local x0 = box[1] + r() * (box[3] - box[1])
			local y0 = box[2] + r() * (box[4] - box[2])
			local dx, dy = x0 - cx, y0 - cy
			local d = math.sqrt(dx * dx + dy * dy)
			if d == 0 then d = 1 end
			local sp = 70 + r() * 120
			local o = { s = s, x0 = x0, y0 = y0, vx = dx / d * sp, vy = dy / d * sp * 0.7 - 70 - r() * 50, w = (r() - 0.5) * 700 }
			o.img = fx.sprite(parent, name, { color = cols[i % 5 + 1], z = 45 })
			o.img.AnchorPoint = V2(0.5, 0.5)
			o.img.Visible = false
			L[#L + 1] = o
		end
		return function(p)
			for _, o in ipairs(L) do
				if p < 0 then
					o.img.Visible = false
				else
					local q = math.floor(p * 10) / 10
					local k = (o.s / 20) * (1 - q * 0.6)
					o.img.Visible = true
					o.img.Position = fx.P(o.x0 + o.vx * q, o.y0 + o.vy * q + 190 * q * q)
					o.img.Rotation = math.floor(o.w * q + 0.5)
					o.img.Size = fx.S(34 * k, 46 * k)
				end
			end
		end
	end

	---------------------------------------------------------------- build

	-- behind the HUD: the fan of big crystals erupting from behind the bar
	local back = {}
	for i, row in ipairs(BACK) do back[i] = crystal(fx.back, row, 2) end
	-- inside the bar: frost creeping in from both edges (stack 2+), and the root's frozen-fill dots
	local frost = fx.sprite(fx.bar, "chill-a/frost", { x = 104, y = 116, w = 392, h = 48, z = 2, transparency = 1 })
	local fillDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.cryoD, alpha = 0.45, pitch = 7, z = 1 })
	fillDots.Visible = false
	-- in front: the jaws (upper fangs over the top edge, lower fangs over the bottom), the hinge clusters, the glints
	local upper, lower, ends, stars = {}, {}, {}, {}
	for i, row in ipairs(UPPER) do upper[i] = crystal(fx.front, row, 2) end
	for i, row in ipairs(LOWER) do lower[i] = crystal(fx.front, row, 3) end
	for i, row in ipairs(ENDS) do ends[i] = crystal(fx.front, row, 4) end
	for i, p in ipairs(STARS) do
		stars[i] = fx.sprite(fx.front, "chill-s/star", { x = p[1], y = p[2], w = 22, h = 22, anchor = V2(0.5, 0.5), z = 5 })
		stars[i].Visible = false
	end
	local shards = mkShards(fx.front, 24, { 90, 60, 510, 190 }, 300, 150, 9)
	-- (2026-10-19, audit GA-01) max Chill stacks are the deepest SLOW since 2026-10-08, not a root: the word says so
	local wR = mkWord("SLOWED!", 300, 44, 196, 74, -6, "chill-a/wR", C.cryo)
	local wK = mkWord("KRAK!", 300, 66, 164, 78, 6, "chill-a/wK", C.white)

	local gOn, gLow = shown(), shown()
	local payAt, shatterAt, paid, lastPay = nil, nil, false, nil

	local self = {}
	function self.event(name, st)
		if name == "pay" then
			payAt, paid = fx.clock, true
			fx.shake(5, 0.24)
		elseif name == "end" then
			if paid then shatterAt = fx.clock end
			paid = false
		elseif name == "on" then
			paid, shatterAt = false, nil
		end
	end

	function self.update(st, dt)
		local on, s, pay, t = st.on, st.s, st.pay, st.t
		-- the root: the frame goes deep blue, the fill freezes
		local p2 = on and pay
		if p2 ~= lastPay then
			lastPay = p2
			fx.restyle("barStroke", { Color = p2 and C.cryoD or C.ink })
			fx.restyle("fill", { BackgroundColor3 = p2 and FILL_ICE or C.red })
		end
		fillDots.Visible = p2

		local gb, gf, ge = 0, 0, 0
		if on then
			if s >= 3 then gb, gf, ge = 1.12, 1.5, 1.3
			elseif s == 2 then gb, gf, ge = 0.66 + 0.2 * t, 0.62 + 0.25 * t, 0.85
			else gb, gf, ge = 0.42 + 0.12 * t, 0.35 + 0.2 * t, 0.55 end
		end
		frost.ImageTransparency = 1 - ((not on and 0) or (s >= 3 and 0.7) or (s == 2 and 0.45) or 0)

		local aO = gOn.age(on)
		local aL = gLow.age(on and s >= 2)
		for _, c in ipairs(back) do
			if aO < 0 then c.img.Visible = false
			else local k = gb * popScale(aO - c.d, 0.3); placeX(c, k, k) end
		end
		for _, c in ipairs(upper) do
			if aO < 0 then c.img.Visible = false
			else local k = popScale(aO - c.d, 0.3); placeX(c, k, k * gf) end
		end
		for _, c in ipairs(lower) do
			if aL < 0 then c.img.Visible = false
			else local k = popScale(aL - c.d, 0.3); placeX(c, k, k * gf) end
		end
		for _, c in ipairs(ends) do
			if aO < 0 then c.img.Visible = false
			else local k = ge * popScale(aO - c.d, 0.3); placeX(c, k, k) end
		end
		-- glints blink 1 / .6 / .2 / .6 every 0.2 s (steps(2) in both halves of an 0.8 s loop), each 0.27 s apart
		for i, img in ipairs(stars) do
			img.Visible = on
			if on then
				local ph = ((fx.clock + (i - 1) * 0.27) % 0.8) / 0.8
				local k = (ph < 0.25 and 1) or (ph < 0.5 and 0.6) or (ph < 0.75 and 0.2) or 0.6
				img.Size = fx.S(22 * k, 22 * k)
			end
		end

		-- words and the shatter
		popW(wR, (pay and payAt) and (fx.clock - payAt) or -1)
		local sp = -1
		if shatterAt then
			local e = fx.clock - shatterAt
			if e < 0.7 then sp = e / 0.7 else shatterAt = nil end
		end
		shards(sp)
		popW(wK, sp >= 0 and sp * 0.7 or -1)
	end
	return self
end

return V
