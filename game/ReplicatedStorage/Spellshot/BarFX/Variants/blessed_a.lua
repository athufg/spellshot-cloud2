--!nocheck
-- Seraph's Embrace: a wall of holy rays, seraph wings on both ends and three gold clasps that break off one per hit.
-- Ported from status_fx/bench/opts/blessed-a.html (round 2, 2026-09-24).
local V = { title = "Seraph's Embrace" }

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local G2 = rgb(255, 224, 138)
local V2 = Vector2.new

function V.mount(fx)
	local C = fx.C
	local GOLD, GL, W, INK = C.rad, C.radL, C.white, C.ink

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
	-- rotate the design point (px, py) by deg (clockwise on screen) about (ox, oy)
	local function rotAbout(px, py, ox, oy, deg)
		local r = math.rad(deg)
		local dx, dy = px - ox, py - oy
		return ox + dx * math.cos(r) - dy * math.sin(r), oy + dx * math.sin(r) + dy * math.cos(r)
	end

	------------------------------------------------------------------ behind: the ray wall
	local HS = { 96, 120, 108, 126, 112, 130, 118, 130, 112, 126, 108, 120, 96 }
	local rays = {}
	for i = 0, 12 do
		local u = i / 12
		local img = fx.sprite(fx.back, i % 2 == 1 and "blessed-a/ray_pale" or "blessed-a/ray_gold",
			{ x = 112 + u * 376, y = 140, w = 52, h = 1, anchor = V2(.5, .5), z = i % 2 == 1 and 1 or 2, visible = false })
		rays[#rays + 1] = { img = img, i = i, bx = 112 + u * 376, H = HS[i + 1], lean = (u - .5) * 44 }
	end
	-- short spikes under the bar (scaled about their top edge)
	local spikes = fx.sprite(fx.back, "blessed-a/spikes", { x = 310, y = 157, w = 420, h = 40, anchor = V2(.5, 0), z = 1 })
	-- wings grip both ends (feathers fan from a pivot at each end)
	local WINGS = {
		{ name = "blessed-a/wing_l", x = -10, ax = 66, sign = 1 },
		{ name = "blessed-a/wing_r", x = 446, ax = 46, sign = -1 },
	}
	for _, w in ipairs(WINGS) do
		w.img = fx.sprite(fx.back, w.name, { x = w.x + 60, y = 95, w = 120, h = 110, anchor = V2(.5, .5), z = 3 })
	end
	-- the bar's ring: 4 px pale gold, ink to 7 px, 4/4 ink shadow
	fx.rect(fx.back, { x = 97, y = 109, w = 414, h = 70, color = INK, corner = "pill", z = 8 })
	fx.rect(fx.back, { x = 93, y = 105, w = 414, h = 70, color = INK, corner = "pill", z = 9 })
	fx.rect(fx.back, { x = 96, y = 108, w = 408, h = 64, color = GL, corner = "pill", z = 10 })

	------------------------------------------------------------------ front: halo, clasps, sparkles
	local cx, cy = fx.chipRect()
	local haloX, haloY = cx - 2 - 6, cy - 30 - 6
	local halo = fx.sprite(fx.front, "blessed-s/halo_hl", { x = haloX, y = haloY, w = 84, h = 38, z = 6 })
	local CX = { 200, 300, 400 }
	local clasps = {}
	for i, x in ipairs(CX) do
		clasps[i] = fx.sprite(fx.front, "blessed-a/clasp", { x = x, y = 143, w = 34, h = 90, anchor = V2(.5, .5), z = 8 })
	end
	local claspGone = { false, false, false }
	local SPK = { { 150, 64 }, { 250, 40 }, { 360, 50 }, { 450, 70 }, { 520, 120 } }
	local spk = {}
	for i, p in ipairs(SPK) do
		spk[i] = fx.sprite(fx.front, "blessed-s/spark", { x = p[1], y = p[2], w = 18.2, h = 18.2, anchor = V2(.5, .5),
			color = (i - 1) % 2 == 1 and GL or W, z = 5 })
	end

	local function popClasp(i, dir)
		local c = clasps[i]
		if claspGone[i] then return end
		claspGone[i] = true
		local x0 = CX[i]
		play(.5, function(p)
			if not c.Parent then return end
			c.Position = fx.P(x0 + dir * 40 * p, 143 - 50 * p + p * p * 90)
			c.Rotation = dir * 200 * p
			local s = 1 - p * .5
			c.Size = fx.S(34 * s, 90 * s)
			c.ImageTransparency = p > .9 and 1 or 0
		end, function() if c.Parent then c.ImageTransparency = 1 end end)
	end
	local function resetClasps()
		for i, c in ipairs(clasps) do
			claspGone[i] = false
			c.Position = fx.P(CX[i], 143)
			c.Rotation = 0
			c.Size = fx.S(34, 90)
			c.ImageTransparency = 0
		end
	end

	local lost, rayK, flinch, wingsHidden = 0, 0, -9, false
	local self = {}
	function self.event(name, st)
		if name == "on" then
			lost, rayK, wingsHidden = 0, 0, false
			resetClasps()
			fire("BLESSED!", 300, 40, 230, 86, GOLD, "blessed-s/burst_on", 1)
		elseif name == "hit" and not st.pay then
			local x
			if lost < 2 then
				popClasp(3 - lost, 1)
				lost += 1
				x = CX[4 - lost]
			else
				x = CX[1]
			end
			flash(x, 140, 40)
			fx.shake(6, .25)
			flinch = fx.clock
			fire("BLOCK!", x, 59, 150, 70, W, "blessed-s/burst_hit", .8)
		elseif name == "pay" then
			popClasp(1, -1)
			fx.shake(10, .25)
			rayK = 0
			fire("BROKEN!", 300, 56, 250, 104, W, "blessed-s/burst_big", .7)
			flash(300, 140, 56)
			shards(20, 540, 50, 150, 18, { W, GOLD, W, G2 })
			wingsHidden = true
		end
	end

	function self.update(st, dt)
		stepA()
		local on = st.on
		local T = fx.stepped(fx.clock, 12)
		local a = on and st.a or 0
		local b = math.floor(T * 8) % 2
		if not st.pay then
			rayK += ((.35 + .65 * a) - rayK) * (1 - .75 ^ (dt * 60))
		else
			rayK = math.max(0, rayK - .2 * dt * 60)
		end
		local fl = (fx.clock - flinch) < .25 and .8 or 1
		for _, r in ipairs(rays) do
			local j = ((r.i + b) % 2 == 1) and 1 or .9
			local hk = r.H * rayK * j * fl
			if not on or hk < 1 then
				r.img.Visible = false
			else
				r.img.Visible = true
				local len = math.sqrt(hk * hk + r.lean * r.lean)
				local deg = math.deg(math.atan2(r.lean, hk))
				local hgt = len / 130 * 136
				local dp = hgt * (133 / 136 - .5)
				local th = math.rad(deg)
				r.img.Size = fx.S(52, hgt)
				r.img.Rotation = deg
				r.img.Position = fx.P(r.bx + dp * math.sin(th), 140 - dp * math.cos(th))
			end
		end
		spikes.Visible = on
		spikes.Size = fx.S(420, 40 * (b == 1 and 1 or .75))
		local fp = (math.floor(T * 6) % 2 == 1) and 1 or -1
		for _, w in ipairs(WINGS) do
			w.img.Visible = on and not wingsHidden and not st.pay
			local deg = fp * 5 * w.sign
			local px, py = rotAbout(w.x + 60, 95, w.x + w.ax, 126, deg)
			w.img.Position = fx.P(px, py)
			w.img.Rotation = deg
		end
		halo.Visible = on
		halo.Position = fx.P(haloX, haloY + (math.floor(T * 4) % 2 == 1 and -3 or 0))
		for i, s in ipairs(spk) do
			s.Visible = on
			local k = (math.floor(T * 6) + (i - 1)) % 3
			local sc = ({ 1, .5, .8 })[k + 1]
			s.Size = fx.S(18.2 * sc, 18.2 * sc)
			s.Rotation = k * 30
		end
		for i, c in ipairs(clasps) do
			if not on then c.Visible = false else c.Visible = true end
			if claspGone[i] and not on then c.ImageTransparency = 1 end
		end
	end

	return self
end

return V
