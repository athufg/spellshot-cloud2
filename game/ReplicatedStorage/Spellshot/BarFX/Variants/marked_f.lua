--!nocheck
-- Eyes in the Dark: the HP fill becomes living shadow ink full of watching eyes that shut one by one as the mark runs
-- out, and all snap wide when the bonus hit consumes it. Ported from status_fx/bench/opts/marked-f.html (round 2, 2026-09-24).
local V = { title = "Eyes in the Dark" }

-- sprite boxes in design px {x, y, w, h}, printed by sprites/marked-s/_gen.js
local BOX = { collar = { 80, 84, 438, 107 }, licks = { 100, 67, 402, 50 }, eruptu = { 100, 31, 409, 89 }, eruptd = { 139, 160, 351, 33 },
	burst = { 156, 0, 286, 101 } }
local SIGIL, ALMOND = { 21, 104, 71, 66 }, { 31, 127, 50, 26 }
local EYES = { 0.3, 0.46, 0.62, 0.78, 0.93 }     -- eye centres as fractions of the fill width
local POP = { { 0, .3, -10 }, { .09, 1.35, -4 }, { .18, .92, -6 }, { .27, 1.04, -5 }, { .36, 1, -5 }, { 1.1, 1.12, -5 }, { 1.2, 0, 0 } }
local POP2 = { { 0, .4, 6 }, { .08, 1.4, -3 }, { .16, .95, -7 }, { .25, 1.05, -6 }, { .34, 1, -6 } }
local BST = { { 0, .2, 0 }, { .08, 1.15, 0 }, { .16, .95, 4 }, { .32, 1, 2 }, { .5, 1.03, 3 } }
local ERUPT = { { 0, .1 }, { .07, 1.25 }, { .154, .9 }, { .238, 1 } }

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

	-- restyles: paper empty channel, near-black ink fill, dark chip, umbra HP label, heart hidden
	fx.restyle("bar", { BackgroundColor3 = C.paper })
	fx.restyle("fill", { BackgroundColor3 = C.umbraD })
	fx.restyle("chip", { BackgroundColor3 = C.umbraD })
	fx.restyle("glyph", { ImageTransparency = 1 })
	fx.restyle("label", { TextColor3 = C.umbra })

	-- BEHIND: shadow licks boiling off the top, the torn ink collar, the lilac + ink rings
	local licks = box(rBack, "marked-f/licks0", BOX.licks, 1)
	fx.flip(licks, { "marked-f/licks0", "marked-f/licks1", "marked-f/licks2" }, 10)
	local collar = box(rBack, "marked-f/collar0", BOX.collar, 2)
	fx.flip(collar, { "marked-f/collar0", "marked-f/collar1", "marked-f/collar2" }, 10)
	fx.rect(rBack, { x = 101, y = 113, w = 406, h = 62, color = C.ink, corner = "pill", z = 3 })
	fx.rect(rBack, { x = 97, y = 109, w = 406, h = 62, color = C.umbraL, corner = "pill", z = 4 })
	local chx, chy, chw, chh = fx.chipRect()
	local ccx, ccy, cs = chx + chw / 2, chy + chh / 2, chw / 64
	fx.rect(rBack, { x = chx, y = chy, w = chw + 6, h = chh + 6, color = C.ink, corner = 17, z = 3 })
	fx.rect(rBack, { x = chx - 3, y = chy - 3, w = chw + 6, h = chh + 6, color = C.umbraL, corner = 17, z = 4 })

	-- FILL: violet halftone, the boiling ragged bands top and bottom, the payoff flash
	fx.dots(rFill, { x = 104, y = 116, w = 392, h = 48, color = C.umbraL, alpha = 0.45, pitch = 7, z = 1 })
	local bands = box(rFill, "marked-f/bands0", { 104, 116, 392, 48 }, 2)
	fx.flip(bands, { "marked-f/bands0", "marked-f/bands1", "marked-f/bands2" }, 10)
	local flash = fx.rect(rFill, { x = 104, y = 116, w = 392, h = 48, color = C.umbraL, z = 3, visible = false })

	-- BAR: umbra halftone on the empty channel, the torn leading edge, the five eyes
	local emptyClip = fx.rect(rBar, { x = 104, y = 116, w = 392, h = 48, transparency = 1, z = 1 })
	emptyClip.ClipsDescendants = true
	local ed = fx.dots(emptyClip, { w = 392, h = 48, color = C.umbra, alpha = 0.3, pitch = 7 })
	local edge = fx.sprite(rBar, "marked-f/edge0", { x = 300, y = 114, w = 64, h = 52, z = 2 })
	fx.flip(edge, { "marked-f/edge0", "marked-f/edge1", "marked-f/edge2" }, 10)
	local eyes = {}
	for i, fr in ipairs(EYES) do
		local h = fx.rect(rBar, { x = 300, y = 140, w = 55, h = 40, anchor = Vector2.new(0.5, 0.5), transparency = 1, z = 3 })
		local base = fx.sprite(h, "marked-f/eye0", { z = 1 })
		base.Size = UDim2.fromScale(1, 1)
		local lid = fx.sprite(h, "marked-f/lid3", { z = 2, visible = false })
		lid.Size = UDim2.fromScale(1, 1)
		eyes[i] = { h = h, base = base, lid = lid, fr = fr, g = 0, lastBase = "", lastLid = -1 }
	end

	-- FRONT: chip sigil and its blinking eye
	local function chipBox(bx) return ccx + (bx[1] - 56) * cs, ccy + (bx[2] - 140) * cs, bx[3] * cs, bx[4] * cs end
	local sx, sy, sw, sh = chipBox(SIGIL)
	fx.sprite(rFront, "marked-s/sigil", { x = sx, y = sy, w = sw, h = sh, z = 1 })
	local ax, ay, aw, ah = chipBox(ALMOND)
	local ceye = fx.rect(rFront, { x = ax + aw / 2, y = ay + ah / 2, w = aw, h = ah, anchor = Vector2.new(0.5, 0.5), transparency = 1, z = 2 })
	local almond = fx.sprite(ceye, "marked-s/almond", { z = 1 })
	almond.Size = UDim2.fromScale(1, 1)
	local pupE = fx.rect(ceye, { color = C.ink, corner = "pill", z = 2 })
	pupE.AnchorPoint = Vector2.new(0.5, 0.5)
	pupE.Position = UDim2.fromScale((58 - 31) / 50, 0.5)
	pupE.Size = UDim2.fromScale(10 / 50, 18 / 26)

	-- PAYOFF: spike burst, then the eruption of shadow tatters above and below the bar
	local pay = fx.rect(rFront, { x = 0, y = 0, w = 640, h = 240, transparency = 1, z = 3, visible = false })
	local b = BOX.burst
	local burst = fx.sprite(pay, "marked-f/burst", { x = b[1] + b[3] / 2, y = b[2] + b[4] / 2, w = b[3], h = b[4], anchor = Vector2.new(0.5, 0.5), z = 1 })
	local burstScale = Instance.new("UIScale")
	burstScale.Parent = burst
	local eu, edd = BOX.eruptu, BOX.eruptd
	local erU = fx.sprite(pay, "marked-f/eruptu", { x = eu[1], y = eu[2] + eu[4], w = eu[3], h = eu[4], anchor = Vector2.new(0, 1), z = 2 })
	local erD = fx.sprite(pay, "marked-f/eruptd", { x = edd[1], y = edd[2], w = edd[3], h = edd[4], z = 2 })

	local intro, introS = mkWord(fx, rFront, "HUNTED!", 300, 12, C.umbraL)
	local payW, payS = mkWord(fx, rFront, "GOTCHA!", 300, 6, C.paper, "BONUS DAMAGE", C.ink)

	local wasOn, wasPay, onAt, payAt, settled = false, false, nil, nil, false
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
		local ePay = payAt and (now - payAt) or nil

		local eOn = onAt and (now - onAt) or 99
		local k = key(POP, eOn)
		intro.Visible = eOn < 1.2
		introS.Scale, intro.Rotation = k[2], k[3]

		-- the fill's pieces ride its width
		local fw = math.clamp(st.hp, 0, 1) * 392
		local ew = math.max(1, 392 - fw)
		emptyClip.Position = fx.P(104 + fw, 116)
		emptyClip.Size = fx.S(ew, 48)
		ed.Position = UDim2.fromScale(-fw / ew, 0)
		ed.Size = UDim2.fromScale(392 / ew, 1)
		edge.Position = fx.P(104 + fw - 14, 114)

		-- the eyes: the clock (shut one by one from the right), blink and glance out of step; all snap open on the pay
		for i, e in ipairs(eyes) do
			e.h.Position = fx.P(104 + fw * e.fr, 140)
			local target = (not ePay and not (st.t > (i - 1) / 5)) and 1 or 0
			if e.g < target then e.g = math.min(target, e.g + dt / 0.2) elseif e.g > target then e.g = math.max(target, e.g - dt / 0.2) end
			local step = math.floor(e.g * 3 + 1e-6)
			if step ~= e.lastLid then
				e.lastLid = step
				e.lid.Visible = step > 0
				if step > 0 then fx.setSprite(e.lid, "marked-f/lid" .. step) end
			end
			local name
			local blink = false
			if ePay then
				name = "marked-f/eyep"
			else
				local lp = (now + e.fr * 2) % 1.5
				name = (lp < 0.6 and "marked-f/eye0") or (lp < 1.05 and "marked-f/eye1") or "marked-f/eye2"
				local bp = ((now + e.fr * 3.1) % 2.2) / 2.2
				blink = bp >= 0.9 and bp < 0.95
			end
			if name ~= e.lastBase then e.lastBase = name; fx.setSprite(e.base, name) end
			e.h.Size = fx.S(55, blink and 4 or 40)
		end

		-- chip eye blinks at 90-95 % of 2.4 s
		local cb = (now % 2.4) / 2.4
		ceye.Size = fx.S(aw, ah * ((cb >= 0.9 and cb < 0.95) and 0.1 or 1))

		licks.Visible = not ePay
		pay.Visible = ePay ~= nil
		payW.Visible = ePay ~= nil
		if ePay then
			local k2 = key(POP2, ePay)
			payS.Scale, payW.Rotation = k2[2], k2[3]
			local kb = key(BST, ePay)
			burstScale.Scale, burst.Rotation = kb[2], kb[3]
			local er = key(ERUPT, ePay)[2]
			erU.Size = fx.S(eu[3], eu[4] * er)
			erD.Size = fx.S(edd[3], edd[4] * er)
			flash.Visible = ePay < 0.25
			flash.BackgroundColor3 = ePay < 0.125 and C.umbraL or C.paper
			if ePay >= 0.25 and not settled then settled = true; fx.restyle("fill", { BackgroundColor3 = C.umbra }) end
		else
			flash.Visible = false
			if settled then settled = false; fx.restyle("fill", { BackgroundColor3 = C.umbraD }) end
		end
	end
	return self
end

return V
