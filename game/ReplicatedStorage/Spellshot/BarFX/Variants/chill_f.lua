--!nocheck
-- Frozen Core: the health fill itself freezes into a living crystal core that creeps over it, stack by stack.
-- Ported from status_fx/bench/opts/chill-f.html (round 2, 2026-09-24). Crystal lists and baked sprites come from
-- sprites/chill-s/_gen.js, which replays the HTML's seeded generator (same RNG, same call order).
local V = { title = "Frozen Core" }

-- snow motes (x, y inside the bar; animation phase), from _gen.js
local MOTES = {
	{ 40.01, 21.01, 0 },
	{ 115.6, 32.53, -0.43 },
	{ 168.87, 37.37, -0.86 },
	{ 226.58, 33.34, -1.29 },
	{ 281.02, 19.03, -1.72 },
	{ 334.47, 18.29, -2.15 },
	{ 377.39, 21.69, -2.58 },
}
-- ROOT crystals bursting through the frame (x, y = base; w, h; rotation; pop delay), from _gen.js
local ROOT = {
	{ 117.54, 118, 16.31, 47.58, -7.37, 0 },
	{ 151.76, 118, 16.44, 45.98, -13.69, 0.02 },
	{ 177.18, 118, 12.89, 53.56, 4.16, 0.04 },
	{ 212.16, 118, 16.86, 31.9, 9.95, 0.06 },
	{ 238.59, 118, 13.5, 67.86, 17.84, 0.08 },
	{ 267.43, 118, 14.75, 61.9, -19.49, 0.1 },
	{ 301.06, 118, 17.87, 34.37, -8.62, 0.12 },
	{ 331.03, 118, 17.33, 66.22, 19.2, 0.14 },
	{ 363.18, 118, 13.64, 36.16, 15.71, 0.16 },
	{ 389.41, 118, 15.52, 55.46, -9.15, 0.18 },
	{ 421.84, 118, 16.96, 74.21, 12.16, 0.2 },
	{ 130.78, 162, 11.93, 16.91, 187.42, 0.08 },
	{ 175.68, 162, 10.32, 20.52, 170.12, 0.1 },
	{ 229.12, 162, 12.88, 24.58, 160.95, 0.12 },
	{ 271.29, 162, 13, 19.6, 178.66, 0.14 },
	{ 319.2, 162, 10.17, 21.8, 162.14, 0.16 },
	{ 360.22, 162, 12.31, 25.41, 165.6, 0.18 },
	{ 410.51, 162, 10.91, 21.98, 192.45, 0.2 },
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
	-- the channel goes deep ice-blue, the HP label pale
	fx.restyle("bar", { BackgroundColor3 = C.cryoD })
	fx.restyle("label", { TextColor3 = C.cryoL })

	-- the ice: a clip that grows from the bar's left end over the fill, holding a 392 x 48 design frame
	local iceClip = Instance.new("Frame")
	iceClip.Name = "Ice"
	iceClip.BackgroundTransparency = 1
	iceClip.ClipsDescendants = true
	iceClip.Position = fx.P(104, 116)
	iceClip.Size = fx.S(1, 48)
	iceClip.ZIndex = 2
	iceClip.Visible = false
	iceClip.Parent = fx.bar
	local ice = Instance.new("Frame")
	ice.Name = "Design"
	ice.BackgroundTransparency = 1
	ice.Size = UDim2.fromScale(1, 1)
	ice.Parent = iceClip
	local function inIce(name, x, w)
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Stretch
		fx.setSprite(img, name)
		img.Position = UDim2.fromScale(x / 392, 0)
		img.Size = UDim2.fromScale(w / 392, 1)
		img.Parent = ice
		return img
	end
	local lattice = inIce("chill-f/lattice", 0, 448)
	local glare = inIce("chill-f/glare", 0, 392)
	local cks = { inIce("chill-f/ck1", 0, 392), inIce("chill-f/ck2", 0, 392), inIce("chill-f/ck3", 0, 392) }
	glare.ZIndex, glare.Visible = 2, false
	for _, c in ipairs(cks) do c.ZIndex, c.Visible = 3, false end

	-- the frost front where the ice meets the thawed red (2-frame boil)
	local edge = fx.sprite(fx.bar, "chill-f/e1", { x = 104, y = 114, w = 22, h = 52, z = 3 })
	edge.Visible = false
	fx.flip(edge, { "chill-f/e1", "chill-f/e2" }, 10)
	-- snow motes drifting through the whole bar
	local motes = {}
	for i, m in ipairs(MOTES) do
		motes[i] = fx.sprite(fx.bar, "chill-f/mote", { x = 104 + m[1], y = 116 + m[2], w = 10, h = 13, anchor = V2(0.5, 0.5), z = 4 })
		motes[i].Visible = false
	end
	-- the pale inner ring
	local ring = fx.rect(fx.bar, { x = 107, y = 119, w = 386, h = 42, transparency = 1, corner = 21, stroke = 3, strokeColor = C.cryoL, z = 5 })
	ring.Visible = false

	-- in front: the ROOT crystals, the shards, the words
	local root = {}
	for i, row in ipairs(ROOT) do root[i] = crystal(fx.front, row, 3) end
	local shards = mkShards(fx.front, 24, { 104, 90, 480, 180 }, 300, 140, 13)
	-- (2026-10-19, audit GA-01) max Chill stacks are the deepest SLOW since 2026-10-08, not a root or a freeze: the word says so
	local wZ = mkWord("CHILLED!", 420, 46, 190, 74, -6, "chill-f/wZ", C.cryo)
	local wK = mkWord("KRSH!", 300, 64, 160, 78, 6, "chill-f/wK", C.white)

	local gRoot = shown()
	local payAt, shatterAt, paid = nil, nil, false

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
		local cov = 0
		if on then
			cov = (s >= 3 and 1) or (s == 2 and (0.5 + 0.42 * t)) or (0.22 + 0.38 * t)
		end
		local iw = 392 * math.clamp(st.hp, 0, 1) * cov

		-- the ice and its crawling lattice (56 px period, 10 steps over 2.4 s)
		iceClip.Visible = on and iw > 0.5
		if iceClip.Visible then
			iceClip.Size = fx.S(iw, 48)
			ice.Size = UDim2.fromScale(392 / iw, 1)
			local p = (fx.clock % 2.4) / 2.4
			lattice.Position = UDim2.fromScale(-56 * math.floor(p * 10) / 10 / 392, 0)
		end
		glare.Visible = on and pay
		local ck = pay and math.min(3, math.floor((1 - t) * 3.4)) or 0
		for i, c in ipairs(cks) do c.Visible = on and ck >= i end

		edge.Visible = on and s < 3
		if edge.Visible then edge.Position = fx.P(104 + iw - 6, 114) end
		ring.Visible = on

		-- motes: (0,0) -> (-40,6) -> (-80,0) over 3 s, 18 steps a half
		for i, img in ipairs(motes) do
			img.Visible = on
			if on then
				local m = MOTES[i]
				local ph = ((fx.clock - m[3]) % 3) / 3
				local dx, dy
				if ph < 0.5 then
					local u = math.floor(ph / 0.5 * 18) / 18
					dx, dy = -40 * u, 6 * u
				else
					local u = math.floor((ph - 0.5) / 0.5 * 18) / 18
					dx, dy = -40 - 40 * u, 6 - 6 * u
				end
				img.Position = fx.P(104 + m[1] + dx, 116 + m[2] + dy)
			end
		end

		-- ROOT: crystals burst out through the frame
		local aR = gRoot.age(on and pay)
		for _, c in ipairs(root) do
			if aR < 0 then c.img.Visible = false
			else local k = popScale(aR - c.d, 0.3); placeX(c, k, k) end
		end

		-- words and the shatter
		popW(wZ, (pay and payAt) and (fx.clock - payAt) or -1)
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
