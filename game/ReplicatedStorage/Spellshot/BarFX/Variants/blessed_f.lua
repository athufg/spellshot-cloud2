--!nocheck
-- Liquid Sunlight: the fill becomes a river of gold light that reaches hp x absorb, with a sun riding its jagged edge.
-- Ported from status_fx/bench/opts/blessed-f.html (round 2, 2026-09-24).
local V = { title = "Liquid Sunlight" }

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local G2 = rgb(255, 224, 138)
local CREAM = rgb(255, 251, 234)
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
	-- a clip rectangle whose children still use design coordinates (same trick as the kit's fill clip)
	local function clipBox(parent, z)
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.ZIndex = z or 1
		clip.Parent = parent
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Parent = clip
		local box = { clip = clip, inner = inner }
		function box.set(x0, y0, w, h)
			w = math.max(0.5, w)
			clip.Position = fx.P(x0, y0)
			clip.Size = fx.S(w, h)
			inner.Size = UDim2.fromScale(640 / w, 240 / h)
			inner.Position = UDim2.fromScale(-x0 / w, -y0 / h)
		end
		return box
	end

	------------------------------------------------------------------ restyle: cream channel
	fx.restyle("bar", { BackgroundColor3 = CREAM })

	------------------------------------------------------------------ behind: beams leaking up, the bar's rings
	local beams = {}
	for i = 0, 5 do
		beams[#beams + 1] = fx.sprite(fx.back, "blessed-f/beam", { x = 110, y = 118, w = 30, h = 52, anchor = V2(.5, 50 / 52),
			color = i % 2 == 1 and W or GOLD, z = 1, visible = false })
	end
	fx.rect(fx.back, { x = 97, y = 109, w = 414, h = 70, color = INK, corner = "pill", z = 8 })
	fx.rect(fx.back, { x = 93, y = 105, w = 414, h = 70, color = INK, corner = "pill", z = 9 })
	fx.rect(fx.back, { x = 96, y = 108, w = 408, h = 64, color = GL, corner = "pill", z = 10 })

	------------------------------------------------------------------ inside: the gold inset rim (only over the empty channel)
	local rimBox = clipBox(fx.bar, 1)
	local rim = fx.rect(rimBox.inner, { x = 107, y = 119, w = 386, h = 42, transparency = 1, corner = "pill", stroke = 3, strokeColor = GOLD })

	------------------------------------------------------------------ the light river
	local body = clipBox(fx.bar, 3)
	fx.rect(body.inner, { x = 104, y = 116, w = 392, h = 48, color = GOLD, z = 1 })
	local tiles = {}
	for i = 0, 3 do
		tiles[#tiles + 1] = fx.sprite(body.inner, "blessed-f/stripes", { x = 104 + i * 156, y = 116, w = 156, h = 48, z = 2 })
	end
	fx.dots(body.inner, { x = 104, y = 116, w = 392, h = 48, color = GD, alpha = .35, pitch = 7, z = 3 })
	fx.rect(body.inner, { x = 104, y = 116, w = 392, h = 9, color = TOPHI, z = 4 })
	fx.rect(body.inner, { x = 104, y = 153, w = 392, h = 11, color = BOTLO, z = 4 })
	local MTOP = { 6, 26, 14, 30, 4, 20, 32 }
	local motes = {}
	for i = 0, 6 do
		local r = i % 2 == 1 and 8 or 10
		motes[#motes + 1] = { r = r, img = fx.sprite(body.inner, "blessed-s/spark", { x = 120, y = 130, w = r * 2.6, h = r * 2.6,
			anchor = V2(.5, .5), color = i % 3 ~= 0 and W or GL, z = 5 }) }
	end
	local edge = fx.sprite(fx.bar, "blessed-f/edge", { x = 104, y = 110, w = 32, h = 60, z = 4 })

	------------------------------------------------------------------ front: the edge sun, halo
	local esun = fx.sprite(fx.front, "blessed-f/esun", { x = 104, y = 134, w = 116, h = 116, anchor = V2(.5, .5), z = 6 })
	local cx, cy = fx.chipRect()
	local haloX, haloY = cx - 2 - 6, cy - 28 - 6
	local halo = fx.sprite(fx.front, "blessed-s/halo", { x = haloX, y = haloY, w = 84, h = 38, z = 6 })

	local shownW, surge = 392, -9
	local self = {}
	function self.event(name, st)
		if name == "on" then
			shownW = 0
			fire("BLESSED!", 300, 50, 230, 86, GOLD, "blessed-s/burst_on", 1)
		elseif name == "hit" and not st.pay then
			surge = fx.clock
			local x = 104 + st.hp * st.a * 392
			fx.shake(6, .25)
			flash(x, 140, 40)
			fire("BLOCK!", x, 61, 150, 70, W, "blessed-s/burst_hit", .8)
		elseif name == "pay" then
			fx.shake(10, .25)
			fire("BREAK!", 300, 58, 240, 104, W, "blessed-s/burst_big", .7)
			local x = 104 + shownW
			flash(x, 140, 60)
			flash(200, 136, 36)
			flash(380, 146, 30)
			shards(104, 500, 112, 168, 16, { GOLD, W, G2, W })
		end
	end

	local wasOn = true
	function self.update(st, dt)
		stepA()
		local on, pay = st.on, st.pay
		if on ~= wasOn then
			fx.restyle("bar", { BackgroundColor3 = on and CREAM or W })
			wasOn = on
		end
		local T = fx.stepped(fx.clock, 12)
		local target = on and st.hp * (st.a or 0) * 392 or 0
		shownW += (target - shownW) * (1 - .65 ^ (dt * 60))
		local ex = 104 + shownW
		local showLive = on and not pay

		-- the rim shows only where the channel is empty (it is the bar's inset shadow, under the fill)
		local fillEdge = 104 + math.clamp(st.hp or 0, 0, 1) * 392
		rimBox.clip.Visible = on
		rimBox.set(fillEdge, 100, 500 - fillEdge, 80)

		local bw = shownW - 22
		body.clip.Visible = showLive and bw > 0.5
		edge.Visible = showLive and shownW > 2
		esun.Visible = showLive and shownW > 2
		halo.Visible = showLive
		if not showLive then
			for _, b in ipairs(beams) do b.Visible = false end
			return
		end
		body.set(104, 116, math.max(0.5, bw), 48)
		local sx = -((T * 156) % 156)
		for i, t in ipairs(tiles) do t.Position = fx.P(104 + sx + (i - 1) * 156, 116) end
		edge.Position = fx.P(104 + shownW - 24, 110)

		local pulse = (fx.clock - surge) < .3 and 1.25 or 1
		local sc = ((math.floor(T * 8) % 2 == 1) and 1 or .92) * pulse * (.7 + .3 * (st.a or 0))
		esun.Position = fx.P(ex, 134)
		esun.Rotation = (T * 60) % 360
		esun.Size = fx.S(116 * sc, 116 * sc)

		local span = math.max(40, shownW)
		for i, m in ipairs(motes) do
			local k = i - 1
			local sp = 60 + k * 9
			local x = (k * 67 + T * sp) % span
			local left = span - x - 20
			local s = ({ 1, .55, .8 })[((math.floor(T * 6) + k) % 3) + 1]
			m.img.Position = fx.P(104 + left + 9, 116 + MTOP[i] + 9)
			m.img.Size = fx.S(m.r * 2.6 * s, m.r * 2.6 * s)
		end

		for i, b in ipairs(beams) do
			local k = i - 1
			local bx = 110 + ((k * 83 + T * 40) % math.max(30, shownW - 30))
			local kk = (math.floor(T * 8) + k) % 4
			b.Position = fx.P(bx + 15, 118)
			b.Size = fx.S(30, 52 * ({ 1, .7, .45, .8 })[kk + 1])
			b.Visible = bx < ex - 30
		end
		halo.Position = fx.P(haloX, haloY + (math.floor(T * 4) % 2 == 1 and -3 or 0))
	end

	return self
end

return V
