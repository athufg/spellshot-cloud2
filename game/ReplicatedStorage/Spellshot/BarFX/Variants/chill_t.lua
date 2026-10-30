--!nocheck
-- Glacier Casing: the bar turns into a slab of glacier ice, then the whole HUD is sealed in one faceted block.
-- Ported from status_fx/bench/opts/chill-t.html (round 2, 2026-09-24). Crystal lists and baked sprites come from
-- sprites/chill-s/_gen.js, which replays the HTML's seeded generator (same RNG, same call order).
local V = { title = "Glacier Casing" }

-- crystal data (x, y = base; w, h; rotation; pop delay), from _gen.js
local ENDS = {
	{ 104, 140, 16, 34, -112, 0 },
	{ 106, 128, 12, 24, -70, 0.05 },
	{ 106, 154, 12, 26, -140, 0.08 },
	{ 496, 140, 16, 34, 112, 0 },
	{ 494, 128, 12, 24, 70, 0.05 },
	{ 494, 154, 12, 26, 140, 0.08 },
}
local SPK = {
	{ 127.93, 110, 10.59, 25.17, 4.67, 0 },
	{ 162.53, 110, 12.8, 34.94, -10.3, 0.02 },
	{ 194.19, 110, 10.52, 22.73, 2.59, 0.04 },
	{ 223.09, 110, 12.56, 19.55, 15.19, 0.06 },
	{ 255.15, 110, 14.19, 28.95, 12.02, 0.08 },
	{ 289.81, 110, 11.41, 20.33, -9.51, 0.1 },
	{ 318.5, 110, 13.46, 32.53, 2.24, 0.12 },
	{ 351.38, 110, 12.22, 35.24, 8.72, 0.14 },
	{ 380.11, 110, 13.91, 30.12, -17.33, 0.16 },
	{ 418.27, 110, 13.07, 24.75, -17.7, 0.18 },
	{ 450.76, 110, 14.49, 43.56, -9.06, 0.2 },
	{ 477.34, 110, 12.38, 22.62, 17.93, 0.22 },
}
local BIG = {
	{ 40, 92, 24.01, 53.96, -31.72, 0.06 },
	{ 78, 86, 22.52, 58.55, -14.55, 0.08 },
	{ 116, 92, 20.51, 40.88, -18.78, 0.11 },
	{ 160, 86, 25.68, 66.31, -20.19, 0.14 },
	{ 212, 92, 22.63, 62.63, -1.82, 0.16 },
	{ 262, 86, 21.99, 62.37, -7.08, 0.18 },
	{ 318, 92, 25.29, 60.4, -1.57, 0.21 },
	{ 470, 86, 22.43, 49.69, 23.39, 0.24 },
	{ 506, 92, 24.72, 38.93, 26.1, 0.26 },
}

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
	-- the slab's colours on the real HUD
	fx.restyle("bar", { BackgroundColor3 = C.cryoL })
	fx.restyle("chip", { BackgroundColor3 = C.cryoL })
	fx.restyle("fill", { BackgroundColor3 = C.red })

	-- inside the bar: the fill's blue freeze dots (stack 2+), the ice sheet, its cracks, the running glint
	local fillDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = C.cryoD, alpha = 0.45, pitch = 7, z = 1 })
	fillDots.Visible = false
	local sheet = fx.sprite(fx.bar, "chill-t/sheet", { x = 104, y = 116, w = 392, h = 48, z = 2, transparency = 1 })
	local cracks = fx.sprite(fx.bar, "chill-t/cracks", { x = 104, y = 116, w = 392, h = 48, z = 3 })
	cracks.Visible = false
	local glint = fx.sprite(fx.bar, "chill-t/glint", { x = 104, y = 116, w = 48, h = 48, z = 4, transparency = 0.3 })

	-- in front: frost crusts on the frame, crystal clusters on the ends, the crystal row, the root block, shards, words
	local rimT = fx.sprite(fx.front, "chill-t/rimT", { x = 106, y = 94, w = 388, h = 28, z = 2 })
	local rimB = fx.sprite(fx.front, "chill-t/rimB", { x = 106, y = 158, w = 388, h = 28, z = 2 })
	local ends, spk, big = {}, {}, {}
	for i, row in ipairs(ENDS) do ends[i] = crystal(fx.front, row, 3) end
	for i, row in ipairs(SPK) do spk[i] = crystal(fx.front, row, 4) end
	for i, row in ipairs(BIG) do big[i] = crystal(fx.front, row, 5) end
	-- the block: two baked tiles (x 4..280, 280..544; y 76..200) and its cracks, all popped about (280, 140)
	local BLK = {
		{ fx.sprite(fx.front, "chill-t/blkL", { z = 6 }), 4, 76, 276, 124, 0 },
		{ fx.sprite(fx.front, "chill-t/blkR", { z = 6 }), 280, 76, 264, 124, 0 },
		{ fx.sprite(fx.front, "chill-t/ck1", { z = 7 }), 240, 76, 36, 70, 1 },
		{ fx.sprite(fx.front, "chill-t/ck2a", { z = 7 }), 490, 90, 50, 76, 2 },
		{ fx.sprite(fx.front, "chill-t/ck2b", { z = 7 }), 16, 140, 40, 54, 2 },
		{ fx.sprite(fx.front, "chill-t/ck3", { z = 7 }), 124, 76, 282, 124, 3 },
	}
	for _, b in ipairs(BLK) do b[1].Visible = false end
	local shards = mkShards(fx.front, 22, { 14, 84, 540, 196 }, 280, 150, 5)
	-- (2026-10-19, audit GA-01) max Chill stacks are the deepest SLOW since 2026-10-08, not a root, and FROZEN! is kept for
	-- real freezes (AbilityHandler): the word says what it is. The sealed block still draws; a real root has no bar look yet
	local wF = mkWord("CHILLED!", 400, 50, 190, 76, -7, "chill-t/wF", C.cryo)
	local wK = mkWord("KSSH!", 300, 70, 170, 80, 5, "chill-t/wK", C.white)

	local gRimT, gRimB, gEnds, gSpk, gBlk = shown(), shown(), shown(), shown(), shown()
	local payAt, shatterAt, paid, lastS2 = nil, nil, false, nil

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
		-- the fill freezes over from stack 2
		local s2 = on and s >= 2
		if s2 ~= lastS2 then
			lastS2 = s2
			fx.restyle("fill", { BackgroundColor3 = s2 and FILL_ICE or C.red })
		end
		fillDots.Visible = s2

		-- the sheet, cracks and glint
		sheet.ImageTransparency = 1 - ((not on and 0) or (s >= 3 and 0.78) or (s == 2 and 0.55) or 0.42)
		cracks.Visible = s2
		glint.Visible = on
		if on then
			local p = (fx.clock % 1.4) / 1.4
			local off = -80 + 560 * math.floor(p * 12) / 12
			glint.Position = fx.P(104 + off - 26, 116)
		end

		-- the crusts (scaleY about the bar edge, popped about x 0)
		local aT = gRimT.age(on and not pay)
		local aB = gRimB.age(on)
		rimT.Visible, rimB.Visible = aT >= 0, aB >= 0
		if aT >= 0 then
			local pp, sy = popScale(aT, 0.32), (s == 2) and 1 or 0.55
			rimT.Position = fx.P(106 * pp, 114 - 20 * pp * sy)
			rimT.Size = fx.S(388 * pp, 28 * pp * sy)
		end
		if aB >= 0 then
			local pp, sy = popScale(aB, 0.32), (s >= 2) and 1 or 0.55
			rimB.Position = fx.P(106 * pp, 166 - 8 * pp * sy)
			rimB.Size = fx.S(388 * pp, 28 * pp * sy)
		end

		-- the end clusters
		local aE = gEnds.age(on)
		local es = (s >= 3 and 1.25) or (s == 2 and (0.8 + 0.3 * t)) or 0.7
		for _, c in ipairs(ends) do
			if aE < 0 then c.img.Visible = false
			else local k = es * popScale(aE - c.d, 0.32); placeX(c, k, k) end
		end

		-- the crystal row off the top edge (stack 2, gone at the root)
		local aS = gSpk.age(s2 and not pay)
		local ss = 0.45 + 0.55 * t
		for _, c in ipairs(spk) do
			if aS < 0 then c.img.Visible = false
			else local k = ss * popScale(aS - c.d, 0.32); placeX(c, k, k) end
		end

		-- ROOT: the sealed block
		local aK = gBlk.age(on and pay)
		local gp = aK >= 0 and popScale(aK, 0.3) or 0
		local ck = pay and math.min(3, math.floor((1 - t) * 3.4)) or 0
		for _, b in ipairs(BLK) do
			local img, x, y, w, h, lvl = b[1], b[2], b[3], b[4], b[5], b[6]
			local vis = aK >= 0 and gp > 0.001 and (lvl == 0 or ck >= lvl)
			img.Visible = vis
			if vis then
				img.Position = fx.P(280 + (x - 280) * gp, 140 + (y - 140) * gp)
				img.Size = fx.S(w * gp, h * gp)
			end
		end
		for _, c in ipairs(big) do
			if aK < 0 then c.img.Visible = false
			else local k = popScale(aK - c.d, 0.32); placeX(c, k, k, gp, 280, 140) end
		end

		-- words and the shatter
		popW(wF, (pay and payAt) and (fx.clock - payAt) or -1)
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
