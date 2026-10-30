--!nocheck
-- Ooze Grip: a huge lumpy toxic ooze rises behind the bar and a dripping sheet pours over its rim; at 2 stacks three
-- goo straps slam round it. Ported from status_fx/bench/opts/poison-a.html (round 2, 2026-09-24).
local V = { title = "Ooze Grip" }

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
	-- ASSAULT: the ooze
	------------------------------------------------------------------------------------------------
	local FLIP = 1 / 0.12
	-- behind: the mass (lumpy bubbling top, dripping bottom), shrinking back towards the bar as time runs out
	local back = layer(fx.back, 1)
	local mass = layer(back, 1)
	local mL = fx.sprite(mass, "poison-a/massA_L", { x = 55, y = 44, w = 265, h = 156, z = 1 })
	local mR = fx.sprite(mass, "poison-a/massA_R", { x = 320, y = 44, w = 265, h = 156, z = 1 })
	fx.flip(mL, { "poison-a/massA_L", "poison-a/massB_L" }, FLIP, 0)
	fx.flip(mR, { "poison-a/massA_R", "poison-a/massB_R" }, FLIP, 0)
	local BX = { 96, 150, 214, 262, 330, 388, 436, 500, 540 }
	local bubs = {}
	for i = 0, 8 do
		local sz = 12 + (i * 7) % 12
		local name = (i % 2 == 1) and "poison-s/bubP" or "poison-s/bub"
		local top = 78 - (i % 2) * 8
		local img = fx.sprite(mass, name, { x = BX[i + 1] + sz / 2, y = top + sz / 2, w = sz, h = sz, anchor = MID, z = 2 })
		bubs[#bubs + 1] = { img = img, x = BX[i + 1] + sz / 2, y = top + sz / 2, sz = sz, dy = 34 + (i * 11) % 26,
			rd = 1 + (i % 3) * 0.25, dl = i * 0.29, s2 = (i % 3 == 1) }
	end
	-- the bar gains a purple outer ring while oozed (it sits over the mass, under the HUD)
	fx.rect(back, { x = 97, y = 109, w = 406, h = 62, color = C.toxinD, corner = 31, z = 3 })

	-- in front: the sheet over the top rim (chip included), and the straps
	local front = layer(fx.front, 1)
	local sheet = layer(front, 1)
	local sL = fx.sprite(sheet, "poison-a/sheetA_L", { x = 8, y = 78, w = 256, h = 96, z = 1 })
	local sR = fx.sprite(sheet, "poison-a/sheetA_R", { x = 264, y = 78, w = 260, h = 96, z = 1 })
	fx.flip(sL, { "poison-a/sheetA_L", "poison-a/sheetB_L" }, FLIP, 0)
	fx.flip(sR, { "poison-a/sheetA_R", "poison-a/sheetB_R" }, FLIP, 0)
	local straps = layer(front, 2)
	for i, x in ipairs({ 176, 306, 432 }) do
		fx.sprite(straps, i == 1 and "poison-a/strap1" or (i == 2 and "poison-a/strap2" or "poison-a/strap3"),
			{ x = x - 12, y = 84, w = 56, h = 126, z = 1 })
	end

	------------------------------------------------------------------------------------------------
	local STRETCH = { { 0, 1 }, { 0.12, 1.45 }, { 0.3, 1 } }
	local SLAM = { { 0, 0 }, { 0.12, 1.2 }, { 0.21, 0.9 }, { 0.3, 1 } }
	local stretchBorn, slamBorn = nil, nil
	local lastS = 0
	local tickN = 0
	local TK = { { 468, 112, "BLORP!", 7 }, { 150, 110, "BLORP!", -9 }, { 300, 108, "BLUB!", -6 } }
	local function shk()
		fx.shake(5, 0.26)
		stretchBorn = fx.clock
	end

	local self = {}
	function self.event(name, st)
		if name == "on" then
			tickN = 0
			shk()
			burst(300, 100, "OOZED!", "OOZED!", { r = 40, fs = 34, wx = -64, wy = -52, rot = -5 })
		elseif name == "stack" and st.s == 2 then
			shk()
			burst(306, 100, "IT'S GOT YOU!", "IT'S GOT YOU!", { r = 44, fs = 28, wx = -110, wy = -58, rot = -3, splat = "poison-s/splatG" })
		elseif name == "tick" then
			shk()
			local k = TK[tickN % 3 + 1]
			tickN += 1
			local n = tostring(st.drop or st.s * 2)   -- (2026-10-19, audit GA-05) the real HP lost (BarFX st.drop); the bench's s * 2 in previews
			burst(k[1], k[2], k[3] .. " " .. minus(n), k[3] .. " -" .. n, { rot = k[4], wx = k[1] > 440 and -110 or -44 })
		end
	end

	function self.update(st, dt)
		local on = st.on
		back.Visible, front.Visible = on, on
		local s2 = st.s >= 2
		if s2 and lastS < 2 then slamBorn = fx.clock end
		lastS = st.s
		local clock = fx.clock

		-- the mass: shrinks back as the time runs out, swells with the stacks
		local t, k = st.t, st.k
		scaleAbout(mass, (0.9 + 0.1 * t) * (0.94 + 0.06 * k), (0.42 + 0.58 * t) * (0.9 + 0.1 * k), 310, 140)
		for _, b in ipairs(bubs) do
			local vis = (not b.s2) or s2
			local sc, u = rise(((clock + b.dl) / b.rd) % 1)
			b.img.Visible = vis and sc > 0.01
			b.img.Position = fx.P(b.x, b.y - b.dy * u)
			b.img.Size = fx.S(b.sz * sc, b.sz * sc)
		end

		-- the sheet's drips stretch on every jolt
		local sy = 1
		if stretchBorn then
			local e = clock - stretchBorn
			if e < 0.3 then sy = (kfs(e, STRETCH, 3)) else stretchBorn = nil end
		end
		scaleAbout(sheet, 1, sy, 0, 110)

		-- straps slam on at 2 stacks
		straps.Visible = s2
		local sly = 1
		if slamBorn then
			local e = clock - slamBorn
			if e < 0.3 then sly = (kfs(e, SLAM, 3)) else slamBorn = nil end
		end
		scaleAbout(straps, 1, math.max(sly, 0.001), 0, 104)

		stepBursts()
	end

	return self
end

return V
