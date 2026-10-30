--!nocheck
-- Toxin Vial: the whole bar becomes a sealed glass vial of bubbling toxin, steel-banded and stoppered, a TOXIC label
-- slapped on and five fume clouds boiling above. Ported from status_fx/bench/opts/poison-t.html (round 2, 2026-09-24).
local V = { title = "Toxin Vial" }

function V.mount(fx)
	local C = fx.C
	local V2 = Vector2.new
	local MID = V2(0.5, 0.5)

	------------------------------------------------------------------------------------------------
	-- shared toxin kit (same in poison_t / poison_a / poison_f)
	------------------------------------------------------------------------------------------------
	-- CSS keyframes with a per-segment steps(n) timing function: keys = { {t, a, b}, ... }
	local function kfs(e, keys, n)
		if e <= keys[1][1] then return keys[1][2], keys[1][3] or 0 end
		for i = 1, #keys - 1 do
			local a, b = keys[i], keys[i + 1]
			if e < b[1] then
				local u = (e - a[1]) / (b[1] - a[1])
				if n then u = math.floor(u * n) / n end
				return a[2] + (b[2] - a[2]) * u, (a[3] or 0) + ((b[3] or 0) - (a[3] or 0)) * u
			end
		end
		local l = keys[#keys]
		return l[2], l[3] or 0
	end
	-- a whole-design-space container, scaled about a pivot (design px) for squash/stretch
	local function layer(parent, z)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = z or 1
		f.Parent = parent
		return f
	end
	local function scaleAbout(f, sx, sy, px, py)
		f.Size = UDim2.fromScale(sx, sy)
		f.Position = UDim2.fromScale(px / 640 * (1 - sx), py / 240 * (1 - sy))
	end
	-- rise: a bubble climbs dy while growing .5 -> 1, swells to 1.35, pops (steps(9) per segment)
	local RISE = { { 0, 0.5, 0 }, { 0.7, 1, 1 }, { 0.85, 1.35, 1 } }
	local function rise(phase)
		if phase >= 0.86 then return 0, 1 end
		if phase >= 0.85 then return 1.35, 1 end
		return kfs(phase, RISE, 9)
	end
	-- burst: splat + 4 droplets + lettered word, removed after 0.65 s
	local SPLAT = { { 0, 0.2, 0 }, { 0.15, 1.15, 8 }, { 0.35, 1, 10 }, { 0.5, 0, 14 } }
	local WORD = { { 0, 0.3, 0 }, { 0.12, 1.3, 0 }, { 0.24, 1, 0 }, { 0.51, 1, -8 }, { 0.6, 0, -12 } }
	local bursts = {}
	local function stepBurst(b, e)
		local s, r = kfs(e, SPLAT, 5)
		b.splat.Visible = s > 0.01
		b.splat.Size = fx.S(b.sz * s, b.sz * s)
		b.splat.Rotation = r
		local u = math.floor(math.min(e / 0.55, 1) * 6) / 6
		for _, d in ipairs(b.drops) do
			d.obj.Position = fx.P(b.x + d.dx * u, b.y + d.dy * u)
			d.obj.Size = fx.S(12 * (1 - 0.6 * u), 12 * (1 - 0.6 * u))
		end
		if b.word then
			local sc, ty = kfs(e, WORD, 6)
			b.word.Visible = sc > 0.01
			if b.wscale then b.wscale.Scale = math.max(sc, 0.01) end
			b.word.Position = fx.P(b.wx, b.wy + ty)
		end
	end
	local function burst(x, y, word, plain, opt)
		opt = opt or {}
		local R = opt.r or 34
		local sz = 2 * R * 92 / 88
		local b = { born = fx.clock, x = x, y = y, sz = sz, drops = {} }
		b.splat = fx.sprite(fx.front, opt.splat or "poison-s/splatL", { x = x, y = y, w = sz, h = sz, anchor = MID, z = 56 })
		for i = 0, 3 do
			local a = -math.pi * (0.15 + i * 0.23)
			local d = fx.sprite(fx.front, "poison-s/drop", { x = x, y = y, w = 12, h = 12, anchor = MID, rotation = -45, z = 55 })
			b.drops[#b.drops + 1] = { obj = d, dx = math.cos(a) * 46, dy = math.sin(a) * 40 + 30 }
		end
		if word then
			local fs = opt.fs or 30
			local w = #plain * fs * 0.62
			b.wx = x + (opt.wx or -40) + w / 2
			b.wy = y + (opt.wy or -52) + fs * 0.5
			local holder, label = fx.word(fx.front, word, { x = b.wx, y = b.wy, size = fs, color = C.toxinL, stroke = 3.5,
				rotation = opt.rot or -8, z = 58, pop = false, burstW = w + 40, burstH = fs * 1.6 })
			label.RichText = true
			b.word = holder
			b.wscale = holder:FindFirstChildOfClass("UIScale")
		end
		bursts[#bursts + 1] = b
		stepBurst(b, 0)
	end
	local function stepBursts()
		for i = #bursts, 1, -1 do
			local b = bursts[i]
			local e = fx.clock - b.born
			if e >= 0.65 then
				if b.splat.Parent then b.splat:Destroy() end
				for _, d in ipairs(b.drops) do if d.obj.Parent then d.obj:Destroy() end end
				if b.word and b.word.Parent then b.word:Destroy() end
				table.remove(bursts, i)
			else
				stepBurst(b, e)
			end
		end
	end
	local function minus(n) return '<font color="#FFFFFF">-' .. n .. "</font>" end

	------------------------------------------------------------------------------------------------
	-- TAKEOVER: the vial
	------------------------------------------------------------------------------------------------
	-- the bar turns to pale green glass, the fill to toxin, the heart chip to a green skull cap
	fx.restyle("bar", { BackgroundColor3 = Color3.fromRGB(0xE6, 0xFA, 0xD0) })
	fx.restyle("fill", { BackgroundColor3 = C.toxin })
	fx.restyle("chip", { BackgroundColor3 = C.toxin })
	fx.restyle("glyph", { ImageTransparency = 1 })

	-- behind: five fume clouds along the length
	local back = layer(fx.back, 1)
	local PX = { 128, 212, 296, 380, 470 }
	local puffs = {}
	for i = 0, 4 do
		local top = (i == 4) and 58 or (56 + (i % 2) * 6)
		local img = fx.sprite(back, "poison-t/puffA", { x = PX[i + 1], y = top + 28, w = 70, h = 56, anchor = MID, z = 2 })
		fx.flip(img, { "poison-t/puffA", "poison-t/puffB" }, 1 / 0.12, 0)
		puffs[i + 1] = { img = img, x = PX[i + 1], top = top, gone = false, i = i }
	end

	-- inside the bar (empty channel): the glass glints and the glass halftone, clipped to the part the fill leaves
	local barL = layer(fx.bar, 1)
	local glassClip = Instance.new("Frame")
	glassClip.BackgroundTransparency = 1
	glassClip.ClipsDescendants = true
	glassClip.ZIndex = 1
	glassClip.Parent = barL
	local glare = fx.sprite(glassClip, "poison-t/glare", { z = 1 })
	local glassDots = fx.dots(glassClip, { color = C.toxinM, alpha = 0.22, pitch = 7, z = 2 })
	-- the liquid, clipped to the fill
	local fillL = layer(fx.fill, 1)
	fx.rect(fillL, { x = 104, y = 148, w = 392, h = 16, color = C.toxinM, z = 2 })
	fx.dots(fillL, { x = 104, y = 151, w = 392, h = 13, color = C.ink, alpha = 0.25, pitch = 6, z = 3 })
	fx.rect(fillL, { x = 104, y = 148, w = 392, h = 3, color = C.ink, z = 4 })
	local hi = fx.rect(fillL, { x = 116, y = 122, w = 200, h = 6, color = C.toxinL, corner = 4, z = 5 })
	local BX = { 22, 60, 98, 140, 176, 214, 250, 288, 322, 356 }
	local bubs = {}
	for i = 0, 9 do
		local sz = 11 + (i * 5) % 9
		local img = fx.sprite(fillL, "poison-s/bub", { x = 104 + BX[i + 1] + sz / 2, y = 161 - sz / 2, w = sz, h = sz, anchor = MID, z = 6 })
		bubs[#bubs + 1] = { img = img, x = 104 + BX[i + 1] + sz / 2, sz = sz, dy = 18 + (i * 7) % 16, rd = 0.9 + (i % 4) * 0.2,
			dl = i * 0.31, s2 = (i % 3 == 2) }
	end
	fx.dots(fillL, { x = 104, y = 116, w = 392, h = 48, color = C.toxinM, alpha = 0.22, pitch = 7, z = 8 })
	-- foam head at the fill's edge and the long glass sheen
	local foam = fx.sprite(barL, "poison-t/foamA", { x = 300, y = 102, w = 40, h = 78, z = 4 })
	fx.flip(foam, { "poison-t/foamA", "poison-t/foamB" }, 1 / 0.12, 0)
	fx.rect(barL, { x = 130, y = 120, w = 300, h = 5, color = C.white, corner = 3, z = 5 })
	fx.rect(barL, { x = 440, y = 120, w = 18, h = 5, color = C.white, corner = 3, z = 5 })

	-- in front: steel bands, neck, stopper, the TOXIC label, the x2 burst, the skull cap
	local front = layer(fx.front, 1)
	fx.sprite(front, "poison-t/band", { x = 180, y = 103, w = 23, h = 77, z = 2 })
	fx.sprite(front, "poison-t/band", { x = 412, y = 103, w = 23, h = 77, z = 2 })
	fx.sprite(front, "poison-t/neck", { x = 486, y = 114, w = 18, h = 52, z = 2 })
	fx.sprite(front, "poison-t/cork", { x = 500, y = 119, w = 41, h = 45, z = 3 })
	local label = fx.sprite(front, "poison-t/label", { x = 262 + 47.5, y = 106 + 35.5, w = 95, h = 71, anchor = MID, rotation = -4, z = 4 })
	local labelScale = Instance.new("UIScale")
	labelScale.Parent = label
	local toxic = Instance.new("TextLabel")
	toxic.BackgroundTransparency = 1
	toxic.AnchorPoint = MID
	toxic.Position = UDim2.fromScale(46 / 95, 43.5 / 71)
	toxic.Size = UDim2.fromScale(80 / 95, 18 / 71)
	toxic.Font = Enum.Font.LuckiestGuy
	toxic.Text = "TOXIC"
	toxic.TextColor3 = C.toxinD
	toxic.ZIndex = 2
	toxic.Parent = label
	fx.px(toxic, "TextSize", 15)
	local x2star = fx.sprite(front, "poison-t/x2star", { x = 361, y = 115, w = 62, h = 62, anchor = MID, z = 5 })
	local x2scale = Instance.new("UIScale")
	x2scale.Parent = x2star
	local x2word = fx.word(front, "x2", { x = 361, y = 115, size = 24, color = C.white, stroke = 2.5, rotation = 8, z = 6, pop = false,
		burstW = 62, burstH = 62 })
	local x2wscale = x2word:FindFirstChildOfClass("UIScale")
	local chipDots = fx.dots(front, { x = 30, y = 114, w = 52, h = 52, color = C.ink, alpha = 0.25, pitch = 7, z = 7 })
	local skull = fx.sprite(front, "poison-s/skull", { x = 56, y = 140, w = 46, h = 46, anchor = MID, z = 8 })

	------------------------------------------------------------------------------------------------
	local POP = { { 0, 0.2 }, { 0.4, 1.25 }, { 0.7, 0.92 }, { 1, 1 } }
	local STAMP = { { 0, 1.6 }, { 0.5, 0.9 }, { 1, 1 } }
	local JOLT = { { 0, 1.035, 0.86 }, { 0.09, 0.985, 1.08 }, { 0.18, 1.01, 0.97 }, { 0.27, 1, 1 } }
	local WOB = { { 0, 1, 1 }, { 0.12, 1.06, 0.94 }, { 0.24, 0.95, 1.05 }, { 0.36, 1, 1 } }
	local labelBorn, stampBorn, x2Born, joltBorn = fx.clock, nil, nil, nil
	local lastS = 0
	local tickN = 0
	local TK = { { 518, 116, "GLUG!", 8 }, { 150, 108, "GLUG!", -10 }, { 304, 104, "BLUB!", -6 } }

	local self = {}
	function self.event(name, st)
		if name == "on" then
			tickN = 0
			labelBorn = fx.clock
			burst(300, 104, "POISONED!", "POISONED!", { r = 40, fs = 32, wx = -86, wy = -46, rot = -5 })
		elseif name == "stack" and st.s == 2 then
			joltBorn = fx.clock
			fx.shake(2, 0.27)
			burst(362, 100, "DOUBLE DOSE!", "DOUBLE DOSE!", { r = 42, fs = 30, wx = -110, wy = -58, rot = -4, splat = "poison-s/splatG" })
		elseif name == "tick" then
			joltBorn = fx.clock
			fx.shake(2, 0.27)
			local k = TK[tickN % 3 + 1]
			tickN += 1
			local n = tostring(st.drop or st.s * 2)   -- (2026-10-19, audit GA-05) the real HP lost (BarFX st.drop); the bench's s * 2 in previews
			burst(k[1], k[2], k[3] .. " " .. minus(n), k[3] .. " -" .. n, { rot = k[4], wx = k[1] > 480 and -120 or -44 })
		end
	end

	function self.update(st, dt)
		local on = st.on
		back.Visible, barL.Visible, fillL.Visible, front.Visible = on, on, on, on
		local s2 = st.s >= 2
		if s2 and lastS < 2 then stampBorn = fx.clock; x2Born = fx.clock end
		lastS = st.s
		local clock = fx.clock
		local ex = 104 + 392 * st.hp

		-- the jolt squashes the whole vial about its middle
		local sx, sy = 1, 1
		if joltBorn then
			local e = clock - joltBorn
			if e < 0.27 then sx, sy = kfs(e, JOLT, 3) else joltBorn = nil end
		end
		for _, f in ipairs({ back, barL, fillL, front }) do scaleAbout(f, sx, sy, 300, 140) end

		-- fumes: drift, boil, swell at 2 stacks, and leave one by one from the stopper end as the time runs out
		for _, p in ipairs(puffs) do
			local ph = ((clock + p.i * 0.37) / 1.2) % 1
			local ty = 6 - 12 * math.floor(ph * 6) / 6
			local k = s2 and 1.28 or 1
			p.img.Position = fx.P(p.x, p.top + 28 + ty)
			p.img.Size = fx.S(70 * k, 56 * k)
			local g = on and st.t < (p.i + 0.5) / 5
			if g and not p.gone then burst(p.x, p.top + 30, nil, nil, { r = 26, splat = "poison-s/splatP" }) end
			p.gone = g
			p.img.Visible = not g
		end

		-- glass channel: the part of the bar the fill leaves
		local gw = math.max(496 - ex, 0.5)
		glassClip.Position = fx.P(ex, 116)
		glassClip.Size = fx.S(gw, 48)
		glare.Position = UDim2.fromScale((321 - ex) / gw, 0)
		glare.Size = UDim2.fromScale(74 / gw, 1)
		glassDots.Position = UDim2.fromScale((104 - ex) / gw, 0)
		glassDots.Size = UDim2.fromScale(392 / gw, 1)
		glassDots.TileSize = UDim2.fromScale(7 / 392, 7 / 48)

		-- liquid
		hi.Size = fx.S(math.max(0, 392 * st.hp - 34), 6)
		foam.Position = fx.P(ex - 23, 102)
		for _, b in ipairs(bubs) do
			local vis = (not b.s2) or s2
			b.img.Visible = vis
			if vis then
				local sc, u = rise(((clock + b.dl) / b.rd) % 1)
				b.img.Visible = sc > 0.01
				b.img.Position = fx.P(b.x, 161 - b.sz / 2 - b.dy * u)
				b.img.Size = fx.S(b.sz * sc, b.sz * sc)
			end
		end

		-- label pop on, restamp at 2 stacks; the x2 burst pops in
		local e = clock - labelBorn
		labelScale.Scale = e < 0.3 and (kfs(e, POP, 3)) or 1
		if stampBorn then
			local e2 = clock - stampBorn
			if e2 < 0.35 then labelScale.Scale = (kfs(e2 / 0.35, STAMP, 4)) else stampBorn = nil end
		end
		x2star.Visible, x2word.Visible = s2, s2
		if s2 then
			local sc = 1
			if x2Born and clock - x2Born < 0.35 then sc = (kfs((clock - x2Born) / 0.35, POP, 4)) end
			x2scale.Scale = sc
			if x2wscale then x2wscale.Scale = sc end
		end

		-- the skull cap on the real badge, wobbling
		local cx, cy, cw, ch = fx.chipRect()
		local wx, wy = kfs(clock % 0.36, WOB, 3)
		local k = cw / 64
		skull.Position = fx.P(cx + cw / 2, cy + ch / 2)
		skull.Size = fx.S(46 * k * wx, 46 * k * wy)
		chipDots.Position = fx.P(cx + 6 * k, cy + 6 * k)
		chipDots.Size = fx.S(cw - 12 * k, ch - 12 * k)

		stepBursts()
	end

	return self
end

return V
