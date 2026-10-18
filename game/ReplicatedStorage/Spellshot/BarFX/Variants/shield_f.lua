--!nocheck
-- Ironclad Plating: the HP fill becomes rippling riveted chevron armour plates inside a bolted steel frame.
-- Ported from status_fx/bench/opts/shield-f.html (round 2, 2026-09-24).
local V = { title = "Ironclad Plating" }

----------------------------------------------------------------------------------------------------
-- shared shield kit (same block in shield_t / shield_a / shield_f): the bench's clock-scrubbed WAAPI keyframes,
-- its jagged-burst lettering and its flying stone/steel chunks.
----------------------------------------------------------------------------------------------------
local function Kit(fx)
	local K = { nodes = {}, pops = {} }
	-- a node: one GuiObject placed by its design rect (x y w h). Options: gx gy gw gh (the SVG fill-box the transform
	-- origin refers to, default the rect), r0 + px py (a fixed rotation about a pivot, applied outside the animation,
	-- like the bench's rotated outer <g>), spin (plain extra Rotation).
	function K.node(obj, x, y, w, h, o)
		o = o or {}
		obj.AnchorPoint = Vector2.new(0.5, 0.5)
		local n = { obj = obj, img = obj:IsA("ImageLabel"), cx = x + w / 2, cy = y + h / 2, w = w, h = h,
			gx = o.gx or x, gy = o.gy or y, gw = o.gw or w, gh = o.gh or h, r0 = o.r0 or 0, px = o.px or 0, py = o.py or 0,
			spin = o.spin or 0, alpha = o.alpha or 1 }
		K.nodes[#K.nodes + 1] = n
		K.apply(n, 0, 0, 1, 1, 0, 1)
		return n
	end
	-- CSS: transform-origin O, transform "translate(tx,ty) rotate(r) scale(sx,sy)"
	function K.apply(n, tx, ty, sx, sy, r, op, ofx, ofy)
		local Ox, Oy = n.gx + n.gw * (ofx or 0.5), n.gy + n.gh * (ofy or 0.5)
		local a = math.rad(r)
		local c, s = math.cos(a), math.sin(a)
		local vx, vy = (n.cx - Ox) * sx, (n.cy - Oy) * sy
		local lx, ly = Ox + tx + vx * c - vy * s, Oy + ty + vx * s + vy * c
		if n.r0 ~= 0 then
			local a0 = math.rad(n.r0)
			local c0, s0 = math.cos(a0), math.sin(a0)
			local dx, dy = lx - n.px, ly - n.py
			lx, ly = n.px + dx * c0 - dy * s0, n.py + dx * s0 + dy * c0
		end
		n.obj.Position = fx.P(lx, ly)
		n.obj.Size = fx.S(n.w * math.abs(sx), n.h * math.abs(sy))
		n.obj.Rotation = n.r0 + r + n.spin
		local tr = math.clamp(1 - op * n.alpha, 0, 1)
		if n.img then n.obj.ImageTransparency = tr else n.obj.BackgroundTransparency = tr end
	end
	-- keyframes: { o = offset, x y sx sy s r (a transform; tf = true for "none"), op = opacity }
	local function tracks(kf)
		local T, Op = {}, {}
		for _, k in ipairs(kf) do
			if k.tf or k.x or k.y or k.sx or k.sy or k.s or k.r then
				T[#T + 1] = { k.o, k.x or 0, k.y or 0, k.sx or k.s or 1, k.sy or k.s or 1, k.r or 0 }
			end
			if k.op then Op[#Op + 1] = { k.o, k.op } end
		end
		if #T == 0 or T[1][1] > 0 then table.insert(T, 1, { 0, 0, 0, 1, 1, 0 }) end
		if T[#T][1] < 1 then T[#T + 1] = { 1, 0, 0, 1, 1, 0 } end
		if #Op == 0 or Op[1][1] > 0 then table.insert(Op, 1, { 0, 1 }) end
		if Op[#Op][1] < 1 then Op[#Op + 1] = { 1, 1 } end
		return T, Op
	end
	local function sample(list, p, i)
		for j = 2, #list do
			local a, b = list[j - 1], list[j]
			if p <= b[1] or j == #list then
				local span = b[1] - a[1]
				local f = span > 0 and math.clamp((p - a[1]) / span, 0, 1) or 1
				return a[i] + (b[i] - a[i]) * f
			end
		end
		return list[1][i]
	end
	-- o: dur delay (s, may be negative) steps inf ox oy (origin, fractions of the fill-box) done fillNone
	function K.play(n, kf, o)
		local T, Op = tracks(kf)
		n.anim = { T = T, Op = Op, t0 = fx.clock, dur = o.dur, delay = o.delay or 0, steps = o.steps or 8, inf = o.inf,
			ox = o.ox or 0.5, oy = o.oy or 0.5, done = o.done, fillNone = o.fillNone }
	end
	function K.stop(n) n.anim = nil end
	function K.step()
		for i = #K.nodes, 1, -1 do
			local n = K.nodes[i]
			if not n.obj.Parent then
				table.remove(K.nodes, i)
			else
				local a = n.anim
				if a then
					local t = fx.clock - a.t0 - a.delay
					local p
					if a.inf then p = t <= 0 and 0 or (t % a.dur) / a.dur else p = math.clamp(t / a.dur, 0, 1) end
					if p < 1 then p = math.floor(p * a.steps) / a.steps end
					local T = a.T
					K.apply(n, sample(T, p, 2), sample(T, p, 3), sample(T, p, 4), sample(T, p, 5), sample(T, p, 6), sample(a.Op, p, 2), a.ox, a.oy)
					if not a.inf and t >= a.dur then
						if a.fillNone then n.anim = nil; K.apply(n, 0, 0, 1, 1, 0, 1) end
						local d = a.done
						a.done = nil
						if d then d() end
					end
				else
					K.apply(n, 0, 0, 1, 1, 0, 1)
				end
			end
		end
		-- lettering: scale(.2) rotate(-14) -> 1.25 rotate(4) @.18 -> .95 @.3 -> 1 @.85 -> scale(1.15,.1), steps(12)
		for i = #K.pops, 1, -1 do
			local q = K.pops[i]
			local e = fx.clock - q.t0
			if e >= q.dur or not q.holder.Parent then
				if q.holder.Parent then q.holder:Destroy() end
				table.remove(K.pops, i)
			else
				local p = math.floor(math.clamp(e / q.dur, 0, 1) * 12) / 12
				local sx, sy, r
				if p < 0.18 then local f = p / 0.18; sx = 0.2 + 1.05 * f; sy = sx; r = -14 + 18 * f
				elseif p < 0.3 then local f = (p - 0.18) / 0.12; sx = 1.25 - 0.3 * f; sy = sx; r = 4 - 4 * f
				elseif p < 0.85 then local f = (p - 0.3) / 0.55; sx = 0.95 + 0.05 * f; sy = sx; r = 0
				else local f = (p - 0.85) / 0.15; sx = 1 + 0.15 * f; sy = 1 - 0.9 * f; r = 0 end
				q.scale.Scale = sx
				q.holder.Size = fx.S(q.w, q.h * sy / sx)
				q.holder.Rotation = r
				q.label.Visible = sy / sx > 0.5
			end
		end
	end
	-- the bench's pop(): a jagged burst (sprite `burst`, drawn for bw x bh) with lettering, centred on x y
	function K.pop(word, x, y, w, h, o)
		local bw, bh = o.bw or w, o.bh or h
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = fx.P(x, y)
		holder.Size = fx.S(w, h)
		holder.ZIndex = 55
		holder.Parent = fx.front
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = holder
		local b = fx.sprite(holder, o.burst, {})
		b.Position = UDim2.fromScale(-3 / bw, -3 / bh)
		b.Size = UDim2.fromScale((bw + 11) / bw, (bh + 11) / bh)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.Text = word
		t.TextColor3 = o.pc or fx.C.white
		t.Rotation = o.rot or -6
		t.ZIndex = 2
		t.Parent = holder
		fx.px(t, "TextSize", o.fs or 22)
		fx.stroke(t, 3)
		K.pops[#K.pops + 1] = { holder = holder, scale = scale, label = t, t0 = fx.clock, dur = o.dur or 0.7, w = w, h = h }
	end
	-- the bench's chunks(): blocky 4/5-gons with a lit facet that arc up, spin and fall. pal = body names in shield-s
	K.STONE = { "stone", "stoneD" }
	K.STEEL = { "steel", "steelD" }
	K.RIVET = { "bronze", "steelB" }
	function K.chunks(n, x0, x1, y0, y1, pal, power, parent)
		for i = 0, n - 1 do
			local cx = x0 + (x1 - x0) * ((i + 0.5) / n)
			local cy = y0 + (y1 - y0) * (((i * 37) % 10) / 10)
			local r = 5 + ((i * 13) % 8) * (power > 1 and 1.2 or 1)
			local k = 4 + i % 2
			local img = fx.sprite(parent or fx.front, "shield-s/ch" .. k .. "_" .. pal[1 + i % #pal], { z = 50 })
			local sz = r * 2.5
			local nd = K.node(img, cx - sz / 2, cy - sz / 2, sz, sz, { spin = math.deg(i) })
			local dx = (cx - (x0 + x1) / 2) * 0.3 * power + (((i * 29) % 21) - 10) * power
			local up = -(28 + (i * 17) % 36) * power
			local sg = (i % 2 == 1) and 1 or -1
			K.play(nd, { { o = 0, tf = true }, { o = 0.4, x = dx * 0.55, y = up, r = 100 * sg }, { o = 1, x = dx, y = up * 0.1 + 80, r = 240 * sg } },
				{ dur = (620 + (i % 3) * 90) / 1000, steps = 9, done = function() img:Destroy() end })
		end
	end
	function K.shake(amp) fx.shake(amp or 5, 0.28) end
	return K
end
----------------------------------------------------------------------------------------------------

function V.mount(fx)
	local C = fx.C
	local K = Kit(fx)

	-- behind: the chamfered steel backplate and six armour-ridge fins along the top (grouped in thirds)
	local backplate = fx.sprite(fx.back, "shield-f/backplate", { x = 94, y = 96, w = 425, h = 93, z = 1 })
	local FINS = {}
	for i, f in ipairs({ { 120, 0 }, { 180, 0 }, { 250, 1 }, { 320, 1 }, { 390, 2 }, { 450, 2 } }) do
		local x, h = f[1], (i % 2 == 0) and 56 or 40
		local img = fx.sprite(fx.back, h == 56 and "shield-f/fin56" or "shield-f/fin40", { z = 1 + i })
		local nd = K.node(img, x - 2, 104 - h - 2, 48, h + 4, { gx = x, gy = 104 - h, gw = 44, gh = h })
		nd.k = f[2]
		FINS[i] = nd
	end

	-- in front: the bolted steel frame band with its heavy end brackets
	local frame = fx.sprite(fx.front, "shield-f/frame", { x = 80, y = 94, w = 446, h = 86, z = 10 })

	-- inside the bar: steel trough halftone, twelve overlapping chevron plates over the fill length, the glint
	local dots = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = C.ink, alpha = 0.35, pitch = 6, z = 1 })
	local N = 12
	local PL = {}
	for i = 0, N - 1 do
		local img = fx.sprite(fx.bar, "shield-f/plate", { z = 30 - i })
		-- the plate svg spans -4..48 x -6..54 around its 38 x 48 box
		local nd = K.node(img, 104 - 6 - 4, 110, 52, 60, { gx = 104 - 6, gy = 116, gw = 38, gh = 48 })
		nd.i = i
		nd.k = math.min(2, math.floor(i / (N / 3)))
		PL[i + 1] = nd
	end
	local glintImg = fx.sprite(fx.bar, "shield-f/glint", { z = 40 })
	local GLINT = K.node(glintImg, 104 - 12, 112, 44, 56, { gx = 104, gy = 112, gw = 26, gh = 56 })

	local function skinOn()
		fx.restyle("bar", { BackgroundColor3 = C.steelD })
		fx.restyle("fill", { BackgroundColor3 = C.redD })
		fx.restyle("label", { TextColor3 = C.steelL })
	end
	local function skinOff()      -- the normal red pill snaps back on the BREAK
		fx.restyle("bar", { BackgroundColor3 = C.white })
		fx.restyle("fill", { BackgroundColor3 = C.red })
		fx.restyle("label", { TextColor3 = C.ink })
	end
	skinOn()
	local skinned = true

	local function ripple()
		for _, p in ipairs(PL) do
			if not p.gone then
				K.play(p, { { o = 0, tf = true }, { o = 0.12, y = -3, sy = 1.06 }, { o = 0.24, tf = true }, { o = 1, tf = true } },
					{ dur = 1.4, delay = p.i * 0.055, steps = 14, inf = true, ox = 0.5, oy = 1 })
			end
		end
	end
	local function reset()
		for _, p in ipairs(PL) do K.stop(p) end
		for _, f in ipairs(FINS) do K.stop(f) end
	end

	local self = {}
	function self.event(name, st)
		if name == "on" then
			reset()
			for _, p in ipairs(PL) do
				p.gone = false
				K.play(p, { { o = 0, y = -70, r = -30, op = 0 }, { o = 0.01, y = -70, r = -30, op = 1 }, { o = 0.6, y = 4, sx = 1.15, sy = 0.8 }, { o = 1, tf = true } },
					{ dur = 0.2, delay = p.i * 0.022, steps = 4, done = (p.i == N - 1) and ripple or nil })
			end
			for i, f in ipairs(FINS) do
				K.play(f, { { o = 0, y = 30, sy = 0.1 }, { o = 0.6, y = -4, sy = 1.2 }, { o = 1, tf = true } },
					{ dur = 0.24, delay = 0.15 + (i - 1) * 0.03, steps = 4, ox = 0.5, oy = 1 })
			end
			K.play(GLINT, { { o = 0, x = -40 }, { o = 0.4, x = 420 }, { o = 1, x = 420 } }, { dur = 1.6, delay = 0.4, steps = 16, inf = true })
			K.pop("ARMORED!", 300, 50, 210, 70, { fs = 30, pc = C.steelL, burst = "shield-f/burst_armored", dur = 1.0, rot = -5 })
			K.chunks(6, 110, 490, 104, 112, K.STEEL, 0.6)
			K.shake(6)
		elseif name == "hit" then
			local n = math.floor((1 - st.a) * 3 + 0.5)
			if n >= 3 then return end
			n = math.max(n, 1)
			local k = 3 - n          -- 0-based third, peeled from the right
			local j = 0
			for idx = #PL, 1, -1 do
				local p = PL[idx]
				if p.k == k and not p.gone then
					p.gone = true
					K.play(p, { { o = 0, tf = true }, { o = 0.35, x = 6, y = -30, r = 40 }, { o = 0.85, op = 1 }, { o = 1, x = 22, y = 90, r = 160, op = 0 } },
						{ dur = 0.48, delay = j * 0.045, steps = 7 })
					j += 1
				end
			end
			for _, f in ipairs(FINS) do
				if f.k == k then
					K.play(f, { { o = 0, tf = true }, { o = 0.3, x = 8, y = -16, r = 25 }, { o = 0.85, op = 1 }, { o = 1, x = 40, y = 90, r = 120, op = 0 } },
						{ dur = 0.52, steps = 7 })
				end
			end
			local x = 104 + (k + 0.5) * 392 * st.hp / 3
			K.pop("CLANG!", x, 70, 124, 62, { fs = 26, pc = C.steelL, rot = k == 2 and 9 or -9, dur = 0.65, burst = "shield-s/burst_small" })
			K.chunks(8, x - 50, x + 50, 110, 160, K.STEEL, 1.1)
			K.shake(6)
		elseif name == "pay" then
			K.chunks(14, 96, 506, 104, 168, K.STEEL, 1.5)
			K.chunks(8, 110, 490, 104, 176, K.RIVET, 1.3)
			K.pop("ARMOR BREAK!", 300, 70, 300, 118, { fs = 34, pc = C.steelL, burst = "shield-f/burst_armorbreak", dur = 0.7, rot = -4 })
			K.shake(9)
		elseif name == "end" then
			reset()
		end
	end

	function self.update(st, dt)
		local on = st.on and not st.pay
		if on ~= skinned then
			skinned = on
			if on then skinOn() else skinOff() end
		end
		backplate.Visible = on
		frame.Visible = on
		dots.Visible = on
		GLINT.obj.Visible = on
		for _, f in ipairs(FINS) do f.obj.Visible = on end
		-- the plates are laid out over the current fill length: left = i/12 of it, minus 6 px
		local len = 392 * math.clamp(st.hp, 0, 1)
		for _, p in ipairs(PL) do
			p.obj.Visible = on
			local left = 104 + p.i / N * len - 6
			p.cx, p.gx = left + 22, left
		end
		K.step()
	end

	return self
end

return V
