--!nocheck
-- Shadow Bounty: the whole bar turns into torn umbra cloth; twelve tatters on top are the 8 s clock and a rip tears it
-- open on the consume. Ported from status_fx/bench/opts/marked-t.html (round 2, 2026-09-24).
local V = { title = "Shadow Bounty" }

-- sprite boxes in design px {x, y, w, h}, printed by sprites/marked-s/_gen.js (tat/shard are relative to their base)
local BOX = { cloak = { 74, 76, 454, 121 }, tat = { -36, -60, 72, 68 }, brk = { 84, 96, 36, 36 }, burst = { 152, -3, 296, 117 },
	rip = { 171, 119, 336, 46 }, shard = { -13, -38, 27, 42 } }
local SIGIL, ALMOND = { 21, 104, 71, 66 }, { 31, 127, 50, 26 }
-- the 12 tatters: x, height, width (the bench's R() values)
local TATS = { { 118.0, 58.5, 36.3 }, { 151.1, 51.1, 35.3 }, { 184.2, 57.0, 35.1 }, { 217.3, 45.3, 36.3 }, { 250.4, 56.9, 34.3 },
	{ 283.5, 58.5, 35.1 }, { 316.5, 35.3, 36.7 }, { 349.6, 41.3, 39.6 }, { 382.7, 47.4, 38.5 }, { 415.8, 38.9, 30.6 },
	{ 448.9, 59.4, 31.5 }, { 482.0, 60.7, 31.6 } }
-- payoff shards: base x, fly x, fly y, spin
local SHARDS = { { 140, -40, -70, -200 }, { 210, -10, -80, 160 }, { 270, -60, -30, -120 }, { 330, 30, 70, 210 },
	{ 390, -50, 40, -160 }, { 450, 20, 90, 140 }, { 480, -30, 60, -220 }, { 170, 40, -60, 120 } }
-- word / burst keyframes {time, scale, rotation} (the bench's KF)
local POP = { { 0, .3, -10 }, { .09, 1.35, -4 }, { .18, .92, -6 }, { .27, 1.04, -5 }, { .36, 1, -5 }, { 1.1, 1.12, -5 }, { 1.2, 0, 0 } }
local POP2 = { { 0, .4, 6 }, { .08, 1.4, -3 }, { .16, .95, -7 }, { .25, 1.05, -6 }, { .34, 1, -6 } }
local BST = { { 0, .2, 0 }, { .08, 1.15, 0 }, { .16, .95, 4 }, { .32, 1, 2 }, { .5, 1.03, 3 } }

local function key(k, e)
	local v = k[1]
	for _, f in ipairs(k) do if e >= f[1] then v = f end end
	return v
end

-- a bench ".w" word: 44 px Luckiest, 9 px paint-order stroke (4.5 outside), 4 px ink drop shadow, optional mono line
local function mkWord(fx, parent, text, cx, top, color, small, smallColor)
	local C = fx.C
	local H = small and 59 or 44
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.6)
	holder.Position = fx.P(cx, top + 0.6 * H)
	holder.Size = fx.S(300, H)
	holder.ZIndex = 50
	holder.Visible = false
	holder.Parent = parent
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	local function lab(col, x, y, z)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.Text = text
		t.TextColor3 = col
		t.Position = UDim2.fromScale(x / 300, y / H)
		t.Size = UDim2.fromScale(1, 44 / H)
		t.ZIndex = z
		t.Parent = holder
		fx.px(t, "TextSize", 44)
		fx.stroke(t, 4.5, C.ink)
	end
	lab(C.ink, 4, 4, 1)
	lab(color, 0, 0, 2)
	if small then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Font = Enum.Font.RobotoMono
		s.Text = small
		s.TextColor3 = smallColor
		s.Position = UDim2.fromScale(0, 48 / H)
		s.Size = UDim2.fromScale(1, 11 / H)
		s.ZIndex = 3
		s.Parent = holder
		fx.px(s, "TextSize", 11)
	end
	return holder, sc
end

function V.mount(fx)
	local C = fx.C
	local function root(layer) return fx.rect(layer, { x = 0, y = 0, w = 640, h = 240, transparency = 1 }) end
	local rBack, rBar, rFill, rFront = root(fx.back), root(fx.bar), root(fx.fill), root(fx.front)

	-- restyles: violet frame, umbra fill, dark chip, lilac HP label, heart hidden
	fx.restyle("bar", { BackgroundColor3 = C.umbraD })
	fx.restyle("fill", { BackgroundColor3 = C.umbra })
	fx.restyle("chip", { BackgroundColor3 = C.umbraD })
	fx.restyle("glyph", { ImageTransparency = 1 })
	fx.restyle("label", { TextColor3 = C.umbraL })

	-- BEHIND: tatters (the clock), the boiling cloak, then the lilac + ink box-shadow rings of the bar and chip
	local tats = {}
	for i, v in ipairs(TATS) do
		local sx, sy = v[3] / 35, v[2] / 50
		local img = fx.sprite(rBack, "marked-t/tat0", { x = v[1], y = 114, w = BOX.tat[3] * sx, h = BOX.tat[4] * sy,
			anchor = Vector2.new(36 / 72, 60 / 68), z = 1 })
		fx.flip(img, { "marked-t/tat0", "marked-t/tat1", "marked-t/tat2" }, 10, (i - 1) / 10)
		tats[i] = { img = img, w = BOX.tat[3] * sx, h = BOX.tat[4] * sy, g = 0 }
	end
	local cloak = fx.sprite(rBack, "marked-t/cloak0", { x = BOX.cloak[1], y = BOX.cloak[2], w = BOX.cloak[3], h = BOX.cloak[4], z = 2 })
	fx.flip(cloak, { "marked-t/cloak0", "marked-t/cloak1", "marked-t/cloak2" }, 10)
	fx.rect(rBack, { x = 101, y = 113, w = 406, h = 62, color = C.ink, corner = "pill", z = 3 })
	fx.rect(rBack, { x = 97, y = 109, w = 406, h = 62, color = C.umbraL, corner = "pill", z = 4 })
	local chx, chy, chw, chh = fx.chipRect()
	local ccx, ccy, cs = chx + chw / 2, chy + chh / 2, chw / 64
	fx.rect(rBack, { x = chx, y = chy, w = chw + 6, h = chh + 6, color = C.ink, corner = 17, z = 3 })
	fx.rect(rBack, { x = chx - 3, y = chy - 3, w = chw + 6, h = chh + 6, color = C.umbraL, corner = 17, z = 4 })

	-- FILL: lilac halftone on the umbra fill, and the payoff flash
	local fillDots = fx.dots(rFill, { x = 104, y = 116, w = 392, h = 48, color = C.umbraL, alpha = 0.55, pitch = 7, z = 1 })
	local flash = fx.rect(rFill, { x = 104, y = 116, w = 392, h = 48, color = C.umbraL, z = 2, visible = false })

	-- BAR: lilac halftone on the empty channel, the scanning slit, the torn fill edge
	local emptyClip = fx.rect(rBar, { x = 104, y = 116, w = 392, h = 48, transparency = 1, z = 1 })
	emptyClip.ClipsDescendants = true
	local ed = fx.dots(emptyClip, { w = 392, h = 48, color = C.umbraL, alpha = 0.3, pitch = 7 })
	local scan = fx.sprite(rBar, "marked-t/scan", { x = 114, y = 112, w = 34, h = 56, z = 2 })
	local edge = fx.sprite(rBar, "marked-t/edge0", { x = 300, y = 110, w = 26, h = 60, z = 3 })
	fx.flip(edge, { "marked-t/edge0", "marked-t/edge1", "marked-t/edge2" }, 10)

	-- FRONT: corner reticle brackets, the chip sigil and its watching eye
	local brks = {}
	for _, b in ipairs({ { 102, 114, 0, -1, -1 }, { 498, 114, 90, 1, -1 }, { 102, 166, 270, -1, 1 }, { 498, 166, 180, 1, 1 } }) do
		local img = fx.sprite(rFront, "marked-t/brk", { x = b[1], y = b[2], w = 36, h = 36, anchor = Vector2.new(0.5, 0.5), rotation = b[3], z = 1 })
		brks[#brks + 1] = { img = img, x = b[1], y = b[2], dx = b[4], dy = b[5] }
	end
	local function chipBox(bx) return ccx + (bx[1] - 56) * cs, ccy + (bx[2] - 140) * cs, bx[3] * cs, bx[4] * cs end
	local sx, sy, sw, sh = chipBox(SIGIL)
	fx.sprite(rFront, "marked-s/sigil", { x = sx, y = sy, w = sw, h = sh, z = 2 })
	local ax, ay, aw, ah = chipBox(ALMOND)
	local eye = fx.rect(rFront, { x = ax + aw / 2, y = ay + ah / 2, w = aw, h = ah, anchor = Vector2.new(0.5, 0.5), transparency = 1, z = 3 })
	local almond = fx.sprite(eye, "marked-s/almond", { z = 1 })
	almond.Size = UDim2.fromScale(1, 1)
	local pup = fx.rect(eye, { transparency = 1, z = 2 })
	pup.Size = UDim2.fromScale(10 / 50, 18 / 26)
	pup.AnchorPoint = Vector2.new(0.5, 0.5)
	local pupE = fx.rect(pup, { color = C.ink, corner = "pill" })
	pupE.Size = UDim2.fromScale(1, 1)
	local glint = fx.rect(pup, { color = C.umbraL })
	glint.Position = UDim2.fromScale(3 / 10, 3 / 18)
	glint.Size = UDim2.fromScale(3 / 10, 4 / 18)

	-- PAYOFF: spike burst, the rip (revealed left to right in 4 steps), 8 cloth shards
	local pay = fx.rect(rFront, { x = 0, y = 0, w = 640, h = 240, transparency = 1, z = 4, visible = false })
	local b = BOX.burst
	local burst = fx.sprite(pay, "marked-t/burst", { x = b[1] + b[3] / 2, y = b[2] + b[4] / 2, w = b[3], h = b[4], anchor = Vector2.new(0.5, 0.5), z = 1 })
	local burstScale = Instance.new("UIScale")
	burstScale.Parent = burst
	local rb = BOX.rip
	local ripClip = fx.rect(pay, { x = rb[1], y = rb[2], w = rb[3], h = rb[4], transparency = 1, z = 2 })
	ripClip.ClipsDescendants = true
	local rip = fx.sprite(ripClip, "marked-t/rip", {})
	rip.Size = UDim2.fromScale(1, 1)
	local shards = {}
	for i, v in ipairs(SHARDS) do
		local img = fx.sprite(pay, "marked-t/shard", { x = v[1] + 0.5, y = 113, w = BOX.shard[3], h = BOX.shard[4], anchor = Vector2.new(0.5, 0.5), z = 3 })
		shards[i] = { img = img, v = v }
	end

	-- words
	local intro, introS = mkWord(fx, rFront, "HUNTED!", 300, 14, C.umbraL)
	local payW, payS = mkWord(fx, rFront, "RIPPED!", 300, 10, C.paper, "BONUS DAMAGE", C.ink)

	local wasOn, wasPay, onAt, payAt = false, false, nil, nil
	local self = {}
	function self.event(name, st) end
	function self.update(st, dt)
		local now = fx.clock
		local on = st.on
		for _, r in ipairs({ rBack, rBar, rFill, rFront }) do r.Visible = on end
		if on and not wasOn then onAt = now end
		if not on then onAt = nil end
		if st.pay and not wasPay then payAt = now; fx.shake(7, 0.72) end
		if not st.pay then payAt = nil end
		wasOn, wasPay = on, st.pay
		if not on then return end

		-- intro word
		if onAt then
			local e = now - onAt
			local k = key(POP, e)
			intro.Visible = e < 1.2 and not payAt   -- (2026-10-19, audit GA-16) a mark spent in its first 1.2 s: the payoff word alone (marked_a)
			introS.Scale = k[2]
			intro.Rotation = k[3]
		end

		-- the tatter clock: tatter i stands while t * 12 > i; it tears away in 3 steps over 0.2 s (scaleY 0, 20 deg)
		for i, tt in ipairs(tats) do
			local target = (st.t * 12 > i - 1) and 0 or 1
			if tt.g < target then tt.g = math.min(target, tt.g + dt / 0.2) elseif tt.g > target then tt.g = math.max(target, tt.g - dt / 0.2) end
			local g = math.floor(tt.g * 3 + 1e-6) / 3
			tt.img.Visible = g < 1 and not payAt
			tt.img.Size = fx.S(tt.w, tt.h * (1 - g))
			tt.img.Rotation = 20 * g
		end

		-- empty-channel halftone: only right of the fill
		local fw = math.clamp(st.hp, 0, 1) * 392
		local ew = math.max(1, 392 - fw)
		emptyClip.Position = fx.P(104 + fw, 116)
		emptyClip.Size = fx.S(ew, 48)
		ed.Position = UDim2.fromScale(-fw / ew, 0)
		ed.Size = UDim2.fromScale(392 / ew, 1)

		-- scan slit: 2.4 s each way, 12 steps
		local ph = (now % 4.8) / 2.4
		if ph > 1 then ph = 2 - ph end
		scan.Position = fx.P(114 + math.floor(ph * 12) / 12 * 340, 112)
		edge.Position = fx.P(104 + fw - 13, 110)

		-- brackets jitter outward every 0.3 s
		local out = (now % 0.6) >= 0.3
		for _, bk in ipairs(brks) do
			bk.img.Visible = not payAt
			bk.img.Position = fx.P(bk.x + (out and bk.dx * 5 or 0), bk.y + (out and bk.dy * 4 or 0))
		end

		-- chip eye: blinks at 88-92 % of 2.4 s, pupil looks left / right every 0.8 s
		local bp = (now % 2.4) / 2.4
		eye.Size = fx.S(aw, ah * ((bp >= 0.88 and bp < 0.92) and 0.15 or 1))
		pup.Position = UDim2.fromScale(0.5 + (((now % 1.6) < 0.8) and -5 or 5) / 50, 0.5)

		-- payoff
		pay.Visible = payAt ~= nil
		payW.Visible = payAt ~= nil
		if payAt then
			local e = now - payAt
			local k = key(POP2, e)
			payS.Scale, payW.Rotation = k[2], k[3]
			local kb = key(BST, e)
			burstScale.Scale, burst.Rotation = kb[2], kb[3]
			local p = math.min(4, math.floor(e / 0.06)) / 4
			ripClip.Visible = p > 0
			if p > 0 then
				ripClip.Size = fx.S(rb[3] * p, rb[4])
				rip.Size = UDim2.fromScale(1 / p, 1)
			end
			local f = math.min(7, math.floor(e / 0.1)) / 7
			for _, s in ipairs(shards) do
				local v = s.v
				s.img.Position = fx.P(v[1] + 0.5 + v[2] * f, 113 + v[3] * f)
				s.img.Size = fx.S(BOX.shard[3] * (1 - 0.4 * f), BOX.shard[4] * (1 - 0.4 * f))
				s.img.Rotation = v[4] * f
			end
			flash.Visible = e < 0.25
			flash.BackgroundColor3 = e < 0.125 and C.umbraL or C.paper
			fillDots.Visible = e >= 0.25
		else
			flash.Visible = false
			fillDots.Visible = true
		end
	end
	return self
end

return V
