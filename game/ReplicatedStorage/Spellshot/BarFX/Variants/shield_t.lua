--!nocheck
-- Bedrock Slab: the whole bar petrifies into a stone slab with a rampart behind it and bolted clamps at both ends.
-- Ported from status_fx/bench/opts/shield-t.html (round 2, 2026-09-24).
local V = { title = "Bedrock Slab" }

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

	-- the slab: a hard-cornered 5 px ink frame with a 6 px ink drop shadow, standing in for the pill's own border
	local slabShadow = fx.rect(fx.back, { x = 106, y = 118, w = 400, h = 56, color = C.ink, corner = 10, z = 20 })
	local slabInk = fx.rect(fx.back, { x = 100, y = 112, w = 400, h = 56, color = C.ink, corner = 10, z = 21 })
	local slabIn = fx.rect(fx.back, { x = 105, y = 117, w = 390, h = 46, color = C.terraD, corner = 6, z = 22 })
	local slabDots = fx.dots(fx.back, { x = 105, y = 117, w = 390, h = 46, color = C.ink, alpha = 0.5, pitch = 6, z = 23 })

	-- behind: the foundation ledge and the three rampart sections (they slam down from above)
	local ledgeImg = fx.sprite(fx.back, "shield-t/ledge", { z = 1 })
	local LEDGE = K.node(ledgeImg, 92, 148, 418, 38, { gx = 94, gy = 150, gw = 414, gh = 34 })
	local RAM = {}
	local ramRect = { { 90, 59, 147, 73, 92, 61, 143, 69 }, { 226, 51, 153, 81, 228, 53, 149, 77 }, { 368, 57, 143, 75, 370, 59, 139, 71 } }
	for i, r in ipairs(ramRect) do
		local img = fx.sprite(fx.back, "shield-t/ram" .. i, { z = 1 + i })
		RAM[i] = K.node(img, r[1], r[2], r[3], r[4], { gx = r[5], gy = r[6], gw = r[7], gh = r[8] })
	end

	-- inside the bar: the dark bedrock trough (halftone), the masonry fill (wiped in), the cracks
	local trough = fx.dots(fx.bar, { x = 104, y = 116, w = 392, h = 48, color = C.ink, alpha = 0.5, pitch = 6, z = 1 })
	local stoneClip = Instance.new("Frame")
	stoneClip.BackgroundTransparency = 1
	stoneClip.ClipsDescendants = true
	stoneClip.Position = fx.P(104, 116)
	stoneClip.Size = fx.S(392, 48)
	stoneClip.ZIndex = 2
	stoneClip.Parent = fx.bar
	local bricks = fx.sprite(stoneClip, "shield-t/bricks", {})
	bricks.Position = UDim2.fromScale(0, 0)
	bricks.Size = UDim2.fromScale(1, 1)
	local crack1 = fx.sprite(fx.bar, "shield-t/crack1", { x = 104, y = 116, w = 392, h = 48, z = 3, visible = false })
	local crack2 = fx.sprite(fx.bar, "shield-t/crack2", { x = 104, y = 116, w = 392, h = 48, z = 4, visible = false })

	-- in front: bolted stone clamps at both ends, pebbles trickling off the bottom edge
	local CAPS = {}
	for i, dx in ipairs({ 0, 406 }) do
		local img = fx.sprite(fx.front, "shield-t/cap", { z = 10 })
		CAPS[i] = K.node(img, 82 + dx, 96, 36, 80, { gx = 84 + dx, gy = 98, gw = 32, gh = 76 })
	end
	local PEB = {}
	for i = 0, 2 do
		local img = fx.sprite(fx.front, "shield-t/pebble", { z = 5 })
		PEB[i + 1] = K.node(img, 168 + i * 120, 161, 14, 14, { gx = 170 + i * 120, gy = 163, gw = 10, gh = 10 })
	end

	-- the bar itself: bedrock trough, terra fill, tan label (the pill's border is hidden under the slab frame)
	local function skinOn()
		fx.restyle("bar", { BackgroundColor3 = C.terraD })
		fx.restyle("barStroke", { Transparency = 1 })
		fx.restyle("fill", { BackgroundColor3 = C.terra })
		fx.restyle("label", { TextColor3 = C.terraL })
	end
	local function skinOff()      -- the plain red pill is back for the BREAK
		fx.restyle("bar", { BackgroundColor3 = C.white })
		fx.restyle("barStroke", { Transparency = 0 })
		fx.restyle("fill", { BackgroundColor3 = C.red })
		fx.restyle("label", { TextColor3 = C.ink })
	end
	skinOn()
	local skinned = true

	local cr = 0
	local wipeT0 = nil
	local function reset()
		cr = 0
		for _, r in ipairs(RAM) do K.stop(r) end
		K.stop(LEDGE)
	end

	local self = {}
	function self.event(name, st)
		if name == "on" then
			reset()
			local all = { LEDGE, RAM[1], RAM[2], RAM[3] }
			for i, r in ipairs(all) do
				K.play(r, { { o = 0, y = -80, sy = 1.2 }, { o = 0.55, y = 5, sx = 1.12, sy = 0.75 }, { o = 0.8, y = -3, sx = 0.96, sy = 1.06 }, { o = 1, tf = true } },
					{ dur = 0.34, delay = (i - 1) * 0.06, steps = 5, ox = 0.5, oy = 1 })
			end
			K.play(CAPS[1], { { o = 0, x = -46, r = -18 }, { o = 0.7, x = 4, sx = 0.8 }, { o = 1, tf = true } }, { dur = 0.3, delay = 0.12, steps = 4 })
			K.play(CAPS[2], { { o = 0, x = 46, r = 18 }, { o = 0.7, x = -4, sx = 0.8 }, { o = 1, tf = true } }, { dur = 0.3, delay = 0.12, steps = 4 })
			wipeT0 = fx.clock
			for i, p in ipairs(PEB) do
				K.play(p, { { o = 0, y = -6, tf = true }, { o = 1, x = 7, y = 30, r = 200 } }, { dur = 1.1, delay = -(i - 1) * 0.37, steps = 10, inf = true })
			end
			K.pop("BEDROCK!", 300, 56, 200, 70, { fs = 30, pc = C.terraL, burst = "shield-t/burst_bedrock", dur = 1.0, rot = -5 })
			K.chunks(6, 110, 490, 104, 112, K.STONE, 0.6)
			K.shake(6)
		elseif name == "hit" then
			local n = math.floor((1 - st.a) * 3 + 0.5)
			if n >= 3 then return end
			n = math.max(n, 1)
			cr = n
			K.play(RAM[4 - n], { { o = 0, tf = true }, { o = 0.2, x = 10, y = -22, r = 8 }, { o = 0.85, op = 1 }, { o = 1, x = 70, y = 120, r = 75, op = 0 } },
				{ dur = 0.52, steps = 7 })
			local x = n == 1 and 436 or 300
			K.pop("KRAK!", x, 64, 120, 60, { fs = 24, pc = C.terraL, rot = n == 1 and 8 or -8, dur = 0.65, burst = "shield-s/burst_small", bw = 124, bh = 62 })
			K.chunks(8, x - 70, x + 70, 86, 120, K.STONE, 1)
			K.shake(6)
		elseif name == "pay" then
			local shell = { { 97, 109, 150, 62, 100, 144 }, { 223, 109, 158, 62, 226, 152 }, { 357, 109, 146, 62, 360, 140 } }
			for i, s in ipairs(shell) do
				local img = fx.sprite(fx.front, "shield-t/shell" .. i, { z = 20 })
				local nd = K.node(img, s[1], s[2], s[3], s[4], { gx = s[5], gy = 112, gw = s[6], gh = 56 })
				local dx = (i - 2) * 60
				local rot = (i - 2) * 24 + (i == 2 and 8 or 0)
				K.play(nd, { { o = 0, tf = true }, { o = 0.2, x = dx * 0.3, y = -14, r = rot * 0.3 }, { o = 0.85, op = 1 }, { o = 1, x = dx, y = 70, r = rot, op = 0 } },
					{ dur = 0.56, steps = 7, done = function() img:Destroy() end })
			end
			K.chunks(16, 96, 506, 104, 168, K.STONE, 1.5)
			K.chunks(6, 96, 506, 96, 110, K.STEEL, 1.2)
			K.pop("SHATTERED!", 300, 70, 280, 120, { fs = 36, pc = C.red, burst = "shield-t/burst_shattered", dur = 0.7, rot = -4 })
			K.shake(8)
		elseif name == "end" then
			reset()
		end
	end

	function self.update(st, dt)
		local skin = st.on and not st.pay
		if skin ~= skinned then
			skinned = skin
			if skin then skinOn() else skinOff() end
		end
		for _, o in ipairs({ slabShadow, slabInk, slabIn, slabDots, trough, stoneClip }) do o.Visible = skin end
		crack1.Visible = skin and cr >= 1
		crack2.Visible = skin and cr >= 2
		for _, r in ipairs(RAM) do r.obj.Visible = skin end
		LEDGE.obj.Visible = skin
		for _, c in ipairs(CAPS) do c.obj.Visible = skin end
		for _, p in ipairs(PEB) do p.obj.Visible = skin end
		-- the trough halftone sits only past the fill; the masonry covers the fill, wiped in left to right (steps(6))
		local hp = math.clamp(st.hp, 0.002, 1)
		local tw = math.max(1, 392 * (1 - hp))
		trough.Position = fx.P(104 + 392 * hp, 116)
		trough.Size = fx.S(tw, 48)
		trough.TileSize = UDim2.fromScale(6 / tw, 6 / 48)
		local wipe = 1
		if wipeT0 then wipe = math.floor(math.clamp((fx.clock - wipeT0) / 0.3, 0, 1) * 6) / 6 end
		local frac = math.max(0.002, hp * wipe)
		stoneClip.Size = fx.S(392 * frac, 48)
		bricks.Size = UDim2.fromScale(1 / frac, 1)
		K.step()
	end

	return self
end

return V
