--!nocheck
-- Gilded Reliquary: the whole health bar becomes a gold holy relic that shatters when the shield breaks.
-- Ported from status_fx/bench/opts/blessed-t.html (round 2, 2026-09-24).
local V = { title = "Gilded Reliquary" }

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local G2, GO = rgb(255, 224, 138), rgb(224, 154, 18)
local TOPHI, BOTLO = rgb(255, 233, 160), rgb(217, 152, 15)
local V2 = Vector2.new

function V.mount(fx)
	local C = fx.C
	local GOLD, GL, GD, W, INK = C.rad, C.radL, C.radD, C.white, C.ink

	------------------------------------------------------------------ bench helpers (status clock, stepped 12 fps)
	local A = {}
	local function play(dur, fn, done)
		A[#A + 1] = { t0 = fx.clock, dur = dur, fn = fn, done = done }
		fn(0)
	end
	local function stepA()
		local T = fx.stepped(fx.clock, 12)
		for i = #A, 1, -1 do
			local a = A[i]
			local p = (T - fx.stepped(a.t0, 12)) / a.dur
			if p >= 1 then
				table.remove(A, i)
				a.fn(1)
				if a.done then a.done() end
			else
				a.fn(math.max(0, p))
			end
		end
	end
	-- comic word on a squashed 14-point burst: pop to 1.25, settle, shrink out over the last 20 %
	local function fire(text, cx, cy, w, h, col, burst, dur)
		local bw = w + 6
		local holder, label = fx.word(fx.front, text, { x = cx, y = cy, size = 34, color = col, stroke = 3.5,
			burst = burst, burstW = bw, burstH = h * bw / w, pop = false, z = 50 })
		label.Rotation = -6
		local sc = holder:FindFirstChildOfClass("UIScale")
		play(dur or 1, function(p)
			if not holder.Parent then return end
			local k = (p < .12 and p / .12 * 1.25) or (p < .22 and 1.25 - (p - .12) / .1 * .25) or (p < .8 and 1) or (1 - (p - .8) / .2)
			if sc then sc.Scale = math.max(0.01, k) end
			holder.Rotation = p < .2 and (-10 + p * 60) or 0
		end, function() if holder.Parent then holder:Destroy() end end)
	end
	local function flash(x, y, r)
		r = r or 34
		local base = 2 * r * 102 / 96
		local img = fx.sprite(fx.front, "blessed-s/flash", { x = x, y = y, w = base, h = base, anchor = V2(.5, .5), z = 45 })
		play(.35, function(p)
			if not img.Parent then return end
			local s = p < .4 and (.3 + p * 2.1) or (1.14 - (p - .4) * .6)
			img.Size = fx.S(base * s, base * s)
			img.ImageTransparency = p > .75 and 1 or 0
		end, function() if img.Parent then img:Destroy() end end)
	end
	local function shards(x0, x1, y0, y1, n, cols, dur)
		dur = dur or .75
		for i = 0, n - 1 do
			local x = x0 + (x1 - x0) * (i + .5) / n
			local y = y0 + ((i * 37) % 11) / 10 * (y1 - y0)
			local s = 12 + ((i * 53) % 7) * 2.6
			local dx = (x - 300) * .3 + ((i * 29) % 9 - 4) * 9
			local dy = -50 - ((i * 41) % 8) * 10
			local r = ((i * 71) % 13 - 6) * 60
			fx.emit(fx.front, "blessed-s/shard", { x = x, y = y, w = s * 46 / 20, h = s * 46 / 20, vx = dx / dur, vy = dy / dur,
				gravity = 240 / (dur * dur), spin = r / dur, grow = -0.6, life = dur, color = cols[i % #cols + 1], z = 44 })
		end
	end

	------------------------------------------------------------------ restyles: gold plate, gold medallion chip
	local function styleOn(pay)
		fx.restyle("bar", { BackgroundColor3 = GL })
		fx.restyle("fill", { BackgroundColor3 = pay and C.red or GOLD })
		fx.restyle("label", { TextColor3 = GD })
		fx.restyle("chip", { BackgroundColor3 = pay and W or GOLD })
		fx.restyle("glyph", { ImageTransparency = 1 })
	end
	local function styleOff()
		fx.restyle("bar", { BackgroundColor3 = W })
		fx.restyle("fill", { BackgroundColor3 = C.red })
		fx.restyle("label", { TextColor3 = INK })
		fx.restyle("chip", { BackgroundColor3 = W })
		fx.restyle("glyph", { ImageTransparency = 0 })
	end
	styleOn(false)

	------------------------------------------------------------------ behind: sun, spear tip, the rim rings
	local cx, cy, cw, ch = fx.chipRect()
	local ccx, ccy = cx + cw / 2, cy + ch / 2
	local sun = fx.sprite(fx.back, "blessed-t/sun", { x = ccx, y = ccy, w = 166, h = 166, anchor = V2(.5, .5), z = 1 })
	local tip = fx.sprite(fx.back, "blessed-t/tip", { x = 500, y = 140, w = 80, h = 104, anchor = V2(14 / 80, 52 / 104), z = 2 })
	-- bar: 6 px gold ring, then ink to 10 px, then a 5/5 ink drop shadow (box-shadow rings)
	fx.rect(fx.back, { x = 95, y = 107, w = 420, h = 76, color = INK, corner = "pill", z = 6 })
	fx.rect(fx.back, { x = 90, y = 102, w = 420, h = 76, color = INK, corner = "pill", z = 7 })
	local barRing = fx.rect(fx.back, { x = 94, y = 106, w = 412, h = 68, color = GOLD, corner = "pill", z = 8 })
	-- chip: 5 px pale ring, ink to 9 px, 4/4 ink shadow
	fx.rect(fx.back, { x = cx - 5, y = cy - 5, w = cw + 18, h = ch + 18, color = INK, corner = 23, z = 6 })
	fx.rect(fx.back, { x = cx - 9, y = cy - 9, w = cw + 18, h = ch + 18, color = INK, corner = 23, z = 7 })
	fx.rect(fx.back, { x = cx - 5, y = cy - 5, w = cw + 10, h = ch + 10, color = GL, corner = 19, z = 8 })

	------------------------------------------------------------------ the fill: gold with marching ray stripes
	local stripeHolder = Instance.new("Frame")
	stripeHolder.BackgroundTransparency = 1
	stripeHolder.Size = UDim2.fromScale(1, 1)
	stripeHolder.ZIndex = 2
	stripeHolder.Parent = fx.fill
	local tiles = {}
	for i = 0, 3 do
		tiles[#tiles + 1] = fx.sprite(stripeHolder, "blessed-t/stripes", { x = 104 + i * 140, y = 116, w = 140, h = 48, z = 2 })
	end
	local fillDots = fx.dots(fx.fill, { x = 104, y = 116, w = 392, h = 48, color = GD, alpha = .32, pitch = 7, z = 3 })
	local bandTop = fx.rect(fx.fill, { x = 104, y = 116, w = 392, h = 7, color = TOPHI, z = 4 })
	local bandBot = fx.rect(fx.fill, { x = 104, y = 155, w = 392, h = 9, color = BOTLO, z = 4 })

	------------------------------------------------------------------ inside the bar: glint, gloss (the absorb readout), cracks
	local glint = fx.sprite(fx.bar, "blessed-t/glint", { x = 104 - 60 - 19, y = 106, w = 64, h = 80, z = 5 })
	local gloss = fx.rect(fx.bar, { x = 123, y = 122, w = 354, h = 7, color = W, corner = 5, stroke = 2, z = 6 })
	local crack1 = fx.sprite(fx.bar, "blessed-t/crack1", { x = 212, y = 116, w = 66, h = 48, z = 7, visible = false })
	local crack2 = fx.sprite(fx.bar, "blessed-t/crack2", { x = 320, y = 116, w = 88, h = 48, z = 7, visible = false })

	------------------------------------------------------------------ front: white heart, cross crest, sparkles
	local heart = fx.sprite(fx.front, "blessed-s/heart", { x = ccx, y = ccy, w = 38, h = 38, anchor = V2(.5, .5), z = 3 })
	local crest = fx.sprite(fx.front, "blessed-t/crest", { x = 300, y = 102, w = 82, h = 82, anchor = V2(.5, .5), z = 4 })
	local SPK = { { 108, 102, 9 }, { 210, 178, 7 }, { 330, 100, 7 }, { 420, 180, 9 }, { 478, 102, 6 }, { 40, 98, 8 }, { 92, 180, 6 } }
	local spk = {}
	for i, p in ipairs(SPK) do
		spk[i] = fx.sprite(fx.front, "blessed-s/spark", { x = p[1], y = p[2], w = p[3] * 2.6, h = p[3] * 2.6, anchor = V2(.5, .5),
			color = (i - 1) % 2 == 1 and GL or W, z = 5 })
	end

	local live = { sun, tip, glint, gloss, crack1, crack2, crest, stripeHolder, fillDots, bandTop, bandBot }
	for _, s in ipairs(spk) do live[#live + 1] = s end

	local hits, wasPay, wasOn = 0, false, true
	local self = {}
	function self.event(name, st)
		if name == "on" then
			hits = 0
			fire("BLESSED!", 300, 58, 230, 92, GOLD, "blessed-s/burst_on", 1)
		elseif name == "hit" and not st.pay then
			hits += 1
			fx.shake(6, .25)
			local x = 100 + (hits == 1 and 130 or 262)
			flash(x, 140, 34)
			fire("BLOCK!", x, 65, 150, 70, W, "blessed-s/burst_hit", .8)
		elseif name == "pay" then
			hits = 0
			fx.shake(9, .25)
			fire("SHATTER!", 300, 62, 260, 108, W, "blessed-s/burst_big", .7)
			shards(110, 500, 116, 166, 16, { GOLD, W, GOLD, G2 })
			flash(300, 140, 48)
			flash(160, 130)
			flash(440, 150)
		elseif name == "end" then
			hits = 0
		end
	end

	function self.update(st, dt)
		stepA()
		local on, pay = st.on, st.pay
		if on ~= wasOn or pay ~= wasPay then
			if on then styleOn(pay) else styleOff() end
			barRing.BackgroundColor3 = pay and W or GOLD
			wasOn, wasPay = on, pay
		end
		local showLive = on and not pay
		for _, o in ipairs(live) do o.Visible = showLive end
		heart.Visible = on
		crack1.Visible = showLive and hits >= 1
		crack2.Visible = showLive and hits >= 2
		if not showLive then return end
		local T = fx.stepped(fx.clock, 12)
		sun.Rotation = (T * 40) % 360
		local sx = (T * 140) % 140
		for i, t in ipairs(tiles) do t.Position = fx.P(104 - 140 + sx + (i - 1) * 140, 116) end
		local g = (T % 1.6) / 1.6
		local L = g < .6 and (-60 + g / .6 * 500) or 440
		glint.Position = fx.P(104 + L - 19, 106)
		local wide = math.floor(T * 8) % 2 == 1
		tip.Size = wide and fx.S(80 * 1.08, 104 * .94) or fx.S(80, 104)
		crest.Rotation = (math.floor(T * 6) % 2 == 1) and 8 or -8
		for i, s in ipairs(spk) do
			local k = (math.floor(T * 6) + (i - 1)) % 3
			local sc = ({ 1, .55, .8 })[k + 1]
			local r = SPK[i][3] * 2.6 * sc
			s.Size = fx.S(r, r)
			s.Rotation = k * 30
		end
		local a = st.a or 0
		gloss.Visible = a > 0.01
		gloss.Size = fx.S(math.max(1, a * 356 - 2), 7)
	end

	return self
end

return V
