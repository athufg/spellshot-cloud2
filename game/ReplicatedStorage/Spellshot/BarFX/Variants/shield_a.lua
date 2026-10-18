--!nocheck
-- Tectonic Vice: stone shards erupt around the bar and three bolted vice-bands clamp it along its length.
-- Ported from status_fx/bench/opts/shield-a.html (round 2, 2026-09-24).
local V = { title = "Tectonic Vice" }

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

	-- the bar's drop shadow turns bedrock-brown (box-shadow 5px terraD)
	local shadow = fx.rect(fx.back, { x = 105, y = 117, w = 400, h = 56, color = C.terraD, corner = "pill", z = 30 })

	-- ten chisel-topped shards fan up from behind the top edge, seven jut down from below; grouped in thirds
	local TOP = { { 86, 34, 58, -24 }, { 122, 40, 74, -14 }, { 166, 32, 50, -6 }, { 204, 44, 80, -10 }, { 252, 36, 62, 4 },
		{ 292, 46, 86, -2 }, { 344, 34, 60, 8 }, { 382, 42, 78, 6 }, { 428, 36, 60, 14 }, { 466, 40, 72, 24 } }
	local BOT = { { 104, 32, 36, 196 }, { 160, 38, 40, 184 }, { 222, 30, 34, 174 }, { 278, 36, 40, 186 }, { 336, 32, 34, 178 },
		{ 396, 38, 40, 182 }, { 452, 32, 36, 168 } }
	local SP = {}
	local function shard(s, base, sprite, cw, ch)
		local bx, w, h, ang = s[1], s[2], s[3], s[4]
		local img = fx.sprite(fx.back, sprite, { z = #SP + 1 })
		-- the sprite is drawn for a cw x ch shard with a 2 px margin; stretched to this shard's w x h
		local mw, mh = 2 * w / cw, 2 * h / ch
		local nd = K.node(img, bx - mw, base - h - mh, w + 2 * mw, h + 2 * mh,
			{ gx = bx, gy = base - h, gw = w, gh = h, r0 = ang, px = bx + w / 2, py = base })
		nd.third = math.min(2, math.floor((bx + w / 2 - 86) / 140))
		nd.bx = bx
		SP[#SP + 1] = nd
	end
	for _, s in ipairs(TOP) do shard(s, 126, "shield-a/shard_top", 40, 72) end
	for _, s in ipairs(BOT) do shard(s, 152, "shield-a/shard_bot", 34, 38) end
	local DUST = {}
	for i = 0, 2 do
		local img = fx.sprite(fx.back, "shield-a/dust", { z = 20 })
		DUST[i + 1] = K.node(img, 148 + i * 118, 172, 12, 12, { gx = 150 + i * 118, gy = 174, gw = 8, gh = 8 })
	end

	-- three bolted stone vice-bands gripping the bar
	local BD = {}
	for i, x in ipairs({ 168, 298, 428 }) do
		local img = fx.sprite(fx.front, "shield-a/band", { z = 10 + i })
		BD[i] = K.node(img, x - 8, 92, 46, 93, { gx = x - 6, gy = 94, gw = 42, gh = 88 })
	end

	-- the pressed-in bedrock lines along the inside top and bottom of the bar
	local press = {
		fx.rect(fx.bar, { x = 104, y = 116, w = 392, h = 6, color = C.terraD, z = 2 }),
		fx.rect(fx.bar, { x = 104, y = 122, w = 392, h = 3, color = C.ink, z = 2 }),
		fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 6, color = C.terraL, alpha = 0.55, pitch = 6, z = 3 }),
		fx.rect(fx.bar, { x = 104, y = 155, w = 392, h = 3, color = C.ink, z = 2 }),
		fx.rect(fx.bar, { x = 104, y = 158, w = 392, h = 6, color = C.terraD, z = 2 }),
		fx.dots(fx.bar, { x = 104, y = 158, w = 392, h = 6, color = C.terraL, alpha = 0.55, pitch = 6, z = 3 }),
	}

	local function reset()
		for _, g in ipairs(SP) do K.stop(g) end
		for _, g in ipairs(BD) do K.stop(g) end
	end

	local self = {}
	function self.event(name, st)
		if name == "on" then
			reset()
			for _, g in ipairs(SP) do
				K.play(g, { { o = 0, y = 70, sx = 0.8, sy = 0.2 }, { o = 0.55, y = -8, sx = 0.9, sy = 1.18 }, { o = 0.8, y = 2, sx = 1.05, sy = 0.94 }, { o = 1, tf = true } },
					{ dur = 0.32, delay = math.abs(g.bx - 290) * 0.45 / 1000, steps = 5, ox = 0.5, oy = 1 })
			end
			for i, g in ipairs(BD) do
				K.play(g, { { o = 0, y = -40, s = 1.6, op = 0 }, { o = 0.01, y = -40, s = 1.6, op = 1 }, { o = 0.6, y = 3, sx = 1.2, sy = 0.8 }, { o = 1, tf = true } },
					{ dur = 0.22, delay = 0.11 + (i - 1) * 0.04, steps = 4 })
			end
			for i, p in ipairs(DUST) do
				K.play(p, { { o = 0, y = -4, tf = true }, { o = 1, x = -6, y = 16, r = -180 } }, { dur = 0.9, delay = -(i - 1) * 0.3, steps = 8, inf = true })
			end
			K.pop("STONEWALL!", 300, 40, 230, 66, { fs = 28, pc = C.terraL, burst = "shield-a/burst_stonewall", dur = 1.0, rot = -4 })
			K.chunks(10, 96, 504, 110, 170, K.STONE, 0.8, fx.back)
			K.shake(7)
		elseif name == "hit" then
			local n = math.floor((1 - st.a) * 3 + 0.5)
			if n >= 3 then return end
			n = math.max(n, 1)
			local k = 3 - n          -- 0-based third, right to left
			local j = 0
			for _, g in ipairs(SP) do
				if g.third == k then
					K.play(g, { { o = 0, tf = true }, { o = 0.2, y = -10, r = 10 }, { o = 0.85, op = 1 }, { o = 1, y = 80, sx = 0.7, sy = 0.2, r = 30, op = 0 } },
						{ dur = 0.42, delay = j * 0.03, steps = 6, ox = 0.5, oy = 1 })
					j += 1
				end
			end
			K.play(BD[k + 1], { { o = 0, tf = true }, { o = 0.25, x = 14, y = -26, r = 18 }, { o = 0.85, op = 1 }, { o = 1, x = 60, y = 120, r = 95, op = 0 } },
				{ dur = 0.56, steps = 7 })
			local x = ({ 168, 298, 428 })[k + 1] + 15
			K.pop("THUD!", x, 74, 116, 60, { fs = 26, pc = C.terraL, rot = k == 2 and 9 or -9, dur = 0.65, burst = "shield-s/burst_small", bw = 124, bh = 62 })
			K.chunks(10, x - 60, x + 60, 96, 176, K.STONE, 1.1)
			K.shake(7)
		elseif name == "pay" then
			K.chunks(18, 90, 510, 60, 190, K.STONE, 1.6)
			K.chunks(6, 150, 460, 110, 170, K.STEEL, 1.3)
			K.pop("CRUMBLE!", 300, 64, 270, 110, { fs = 38, pc = C.terraL, burst = "shield-a/burst_crumble", dur = 0.7, rot = -5 })
			K.shake(9)
		elseif name == "end" then
			reset()
		end
	end

	function self.update(st, dt)
		local on = st.on and not st.pay
		shadow.Visible = on
		for _, o in ipairs(press) do o.Visible = on end
		for _, g in ipairs(SP) do g.obj.Visible = on end
		for _, g in ipairs(BD) do g.obj.Visible = on end
		for _, p in ipairs(DUST) do p.obj.Visible = on end
		K.step()
	end

	return self
end

return V
