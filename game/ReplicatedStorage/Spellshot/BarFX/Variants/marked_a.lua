--!nocheck
-- Shadow Grip: a boiling shadow mass rises behind the bar, nine clawed fingers clamp it end to end and a slit-pupil eye
-- watches from above; the consume crushes it. Ported from status_fx/bench/opts/marked-a.html (round 2, 2026-09-24).
local V = { title = "Shadow Grip" }

-- sprite boxes in design px {x, y, w, h}, printed by sprites/marked-s/_gen.js (fgt/fgb are relative to the knuckle)
local BOX = { mass = { 62, 59, 475, 142 }, eyeb = { 209, 9, 185, 96 }, eye = { 238, 36, 124, 48 }, fgt = { -29, -6, 57, 84 },
	fgb = { -26, -56, 51, 62 }, crack0 = { 149, 111, 30, 55 }, crack1 = { 238, 111, 31, 55 }, burst = { 121, 1, 353, 104 } }
local TOP, BOT = { 190, 265, 340, 415, 482 }, { 228, 303, 378, 450 }
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
	local function box(parent, name, b, z)
		return fx.sprite(parent, name, { x = b[1], y = b[2], w = b[3], h = b[4], z = z })
	end

	-- BEHIND: the boiling shadow mass, the eye in its own shadow above the bar, then the lilac + ink rings
	local mass = box(rBack, "marked-a/mass0", BOX.mass, 1)
	fx.flip(mass, { "marked-a/mass0", "marked-a/mass1", "marked-a/mass2" }, 10)
	local eyeG = fx.rect(rBack, { x = 0, y = 0, w = 640, h = 240, transparency = 1, z = 2 })
	local eyeb = box(eyeG, "marked-a/eyeb0", BOX.eyeb, 1)
	fx.flip(eyeb, { "marked-a/eyeb0", "marked-a/eyeb1", "marked-a/eyeb2" }, 10)
	local eyeW = box(eyeG, "marked-a/eye0", BOX.eye, 2)
	local lid = box(eyeG, "marked-a/lid0", BOX.eye, 3)
	box(eyeG, "marked-a/eyeo", BOX.eye, 4)
	fx.rect(rBack, { x = 101, y = 113, w = 406, h = 62, color = C.ink, corner = "pill", z = 3 })
	fx.rect(rBack, { x = 97, y = 109, w = 406, h = 62, color = C.umbraL, corner = "pill", z = 4 })
	local chx, chy, chw, chh = fx.chipRect()
	fx.rect(rBack, { x = chx, y = chy, w = chw + 6, h = chh + 6, color = C.ink, corner = 17, z = 3 })
	fx.rect(rBack, { x = chx - 3, y = chy - 3, w = chw + 6, h = chh + 6, color = C.umbraL, corner = 17, z = 4 })

	-- BAR: the stains the grip leaves inside the bar
	for _, x in ipairs(TOP) do fx.sprite(rBar, "marked-a/staint", { x = x - 14, y = 114, w = 40, h = 22, z = 1 }) end
	for _, x in ipairs(BOT) do fx.sprite(rBar, "marked-a/stainb", { x = x - 12, y = 144, w = 40, h = 22, z = 1 }) end
	-- FILL: the payoff flash (lilac, paper, then the red fill again)
	local flash = fx.rect(rFill, { x = 104, y = 116, w = 392, h = 48, color = C.umbraL, z = 2, visible = false })

	-- FRONT: payoff (burst + cracks) under the fingers
	local pay = fx.rect(rFront, { x = 0, y = 0, w = 640, h = 240, transparency = 1, z = 1, visible = false })
	local b = BOX.burst
	local burst = fx.sprite(pay, "marked-a/burst", { x = b[1] + b[3] / 2, y = b[2] + b[4] / 2, w = b[3], h = b[4], anchor = Vector2.new(0.5, 0.5), z = 1 })
	local burstScale = Instance.new("UIScale")
	burstScale.Parent = burst
	local cracks = {}
	for i, c in ipairs({ { "crack0", 0 }, { "crack1", 0 }, { "crack0", 170 }, { "crack1", 170 } }) do
		local cb = BOX[c[1]]
		local img = fx.sprite(pay, "marked-a/" .. c[1], { x = cb[1] + c[2] + cb[3] / 2, y = cb[2] + cb[4] / 2, w = cb[3], h = cb[4], anchor = Vector2.new(0.5, 0.5), z = 2 })
		cracks[i] = { img = img, w = cb[3], h = cb[4] }
	end

	-- the fingers: five from above (knuckle y 70), four from below (knuckle y 190), each slams in with its row
	local fingers = {}
	local function finger(x, top, i)
		local bx = top and BOX.fgt or BOX.fgb
		local pre = top and "marked-a/fgt" or "marked-a/fgb"
		local ay = top and 0 or 1
		local baseY = top and (70 + bx[2]) or (190 + bx[2] + bx[4])
		local img = fx.sprite(rFront, pre .. "0", { x = x, y = baseY, w = bx[3], h = bx[4], anchor = Vector2.new(-bx[1] / bx[3], ay), z = 3 })
		fx.flip(img, { pre .. "0", pre .. "1", pre .. "2" }, 10, i / 10)
		fingers[#fingers + 1] = { img = img, x = x, y = baseY, w = bx[3], h = bx[4], d = top and 1 or -1, i = i, top = top }
	end
	for i, x in ipairs(TOP) do finger(x, true, i - 1) end
	for i, x in ipairs(BOT) do finger(x, false, i + 4) end

	local intro, introS = mkWord(fx, rFront, "HUNTED!", 490, 16, C.umbraL)
	local payW, payS = mkWord(fx, rFront, "CRUNCH!", 300, 8, C.paper, "MARK CONSUMED", C.umbraL)

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

		local eOn = onAt and (now - onAt) or 99
		local k = key(POP, eOn)
		intro.Visible = eOn < 1.2 and not payAt        -- a mark consumed in its first second: CRUNCH! alone
		introS.Scale, intro.Rotation = k[2], k[3]

		-- the eye: pupil looks around (1.8 s, 3 steps), the lid lowers with the time used
		eyeG.Visible = not payAt
		local lp = math.floor((now % 1.8) / 0.6)
		fx.setSprite(eyeW, "marked-a/eye" .. math.clamp(lp, 0, 2))
		fx.setSprite(lid, "marked-a/lid" .. math.clamp(math.floor((1 - st.t) * 3 + 0.5), 0, 3))

		-- fingers: slam (0.3 s, 3 steps), throb out of step (0.8 s), slacken outward up to 12 px as t drains
		local slam = 1 - math.min(3, math.floor(eOn / 0.1)) / 3
		local ePay = payAt and (now - payAt) or nil
		for _, f in ipairs(fingers) do
			local sy, rot, dy = 1, 0, 0
			if ePay then
				sy = (ePay < 0.1 and 1.3) or (ePay < 0.2 and 1.18) or 1.22
			else
				if ((now + f.i * 0.17) % 0.8) >= 0.4 then sy, rot = 1.07, 2 * f.d end
				dy = -f.d * (1 - st.t) * 12
				dy += (f.top and -70 or 40) * slam
			end
			f.img.Position = fx.P(f.x, f.y + dy)
			f.img.Size = fx.S(f.w, f.h * sy)
			f.img.Rotation = rot
		end

		pay.Visible = ePay ~= nil
		payW.Visible = ePay ~= nil
		if ePay then
			local k2 = key(POP2, ePay)
			payS.Scale, payW.Rotation = k2[2], k2[3]
			local kb = key(BST, ePay)
			burstScale.Scale, burst.Rotation = kb[2], kb[3]
			local cs = math.min(3, math.floor(ePay / (0.2 / 3))) / 3
			for _, c in ipairs(cracks) do
				c.img.Visible = cs > 0
				c.img.Size = fx.S(c.w * cs, c.h * cs)
			end
			flash.Visible = ePay < 0.25
			flash.BackgroundColor3 = ePay < 0.125 and C.umbraL or C.paper
		else
			flash.Visible = false
		end
	end
	return self
end

return V
