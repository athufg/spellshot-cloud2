--[[
	FrostLotusFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/FrostLotusFX

	Cryo's FROST LOTUS skin, the piece logic (2026-10-15; the contract: vfx_blocking/cryo/cryo_frostlotus_skin_2026_10_14/
	HANDOFF_SPEC.md). Kept OUT of CryoFX on purpose: CryoFX sits at Luau's limit of 200 top-level locals, so it hands this
	module its own helpers once (Init: CryoFX._H) and calls in from each piece's hook, for a caster who wears the skin
	(CryoFX's FBX.LotusOn). The meshes are FrostLotusKit's.
	  Field         Flash Freeze (the Rare field, restored): lotus blooms of different sizes unfurling as the wave passes,
	                each bursting low on the rim's wave (shards, powder, a falling petal or two, sparkles)
	  (the rooted body's mini blooms ride CryoFX's own freeze plumbing: FrostLotusKit.BodyBlooms, encaseNew "LotusFF" /
	  "LotusDF"; the shatter is CryoFX's low, outward one with lotus petals for its pieces)
	  Cage*         Mirror Cage (Epic): one giant lotus under the target, opening ring by ring and holding; every bolt leaves
	                from a petal where it sits (outer ring first), each petal spent, the bloom thinning to the bare pod; the
	                unspent petals shed, the pod sinks; a per-viewer KEYHOLE fades whatever hides a player
	  Print         Cold Momentum: a small flat lotus bloom on each frost print, two small petals dropping by it (pooled)
	  Tap           Deep Freeze's tap: three tiny blooms sprout and melt (the trap itself is CryoFX's "LotusDF")
	  Storm*        Blizzard (Epic): petal streaks blowing one way, mostly in the outer band; the wall's flecks glitter,
	                streaming the same way
	  HitBloom      the blade's hit: a lotus pops open and sheds its 6 petals, a thin ring flash
	Every sparkle is the Rare layer (FrostLotusKit.Emitter: soft, never a flash; its own switch, SparklesOn).
]]

local LFX = {}
local H, FL                                       -- CryoFX's helpers (Init), FrostLotusKit
local rng = Random.new()

function LFX.Init(helpers, kit)
	H, FL = helpers, kit
	if kit and kit.OnRelease then kit.OnRelease(function() LFX._release() end) end   -- (2026-10-19, MeshBudget)
	LFX.Kit = kit                                 -- what CryoFX drops a finished bolt through (Mirror Cage's lfk.Kit)
end

local function tier(caster)
	-- (2026-10-19, audit P5A-12) an enemy is not me and not a teammate (CryoFX's isEnemy)
	local enemy = H.Settings.ThinEnemyVFX and caster ~= nil
		and (if H.isEnemy then H.isEnemy(caster) else caster ~= H.VFXLibrary.LocalCharacter)
	return FL.Tier(H.Settings.EffectDensity, enemy)
end

--- a soft sparkle burst (dew glints + glitter) at `pos`
local function sparkle(pos, dew, glitter)
	if not FL.SparklesOn() then return end
	local calm = H.Settings.Get and H.Settings.Get("ReduceFlashing")
	local h = H.host(CFrame.new(pos))
	h.Size = Vector3.new(0.4, 0.4, 0.4)
	if dew > 0 then FL.Emitter("dew", h, calm):Emit(dew) end
	if glitter > 0 then FL.Emitter("glitter", h, calm):Emit(glitter) end
	task.delay(2.5, function() h:Destroy() end)
end
LFX.Sparkle = sparkle

--- a petal thrown from `pos`: out, low, falling, fading (CryoFX's debris: "FL_Mote"); `spin` (default 4) how fast
local function petalOut(pos, out, scale, gy, up, spin)
	local m = FL.Kind("Mote")
	if not m then return end
	H.throw("FL_Mote", CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
		out * rng:NextNumber(1.5, 3.5) + Vector3.new(0, rng:NextNumber(0.8, up or 2.2), 0),
		Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * (spin or 4), rng:NextNumber(1.1, 1.6),
		m.Size * scale, gy, "Kunai")
end

----------------------------------------------------------------------------------------------------
-- LOOSE PETALS (Epic): FlutterS -- a small petal falling, fluttering and spinning (the M1 hit's shed, Cold Momentum's
-- drops); Flutter (a short hard-edged glint trail behind it) is the retired Epic Flash Freeze shed's. Pooled, one stepper.
----------------------------------------------------------------------------------------------------
local flutterPool, flutters = { Flutter = {}, FlutterS = {} }, {}
local function flutterGet(kind)
	local o = table.remove(flutterPool[kind])
	if o then return o end
	o = FL.New(kind)
	if o and kind == "Flutter" then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = o.Body, o.Body
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.FaceCamera, tr.Lifetime, tr.MinLength = true, 0.16, 0.05
		tr.LightEmission, tr.LightInfluence = 1, 0
		tr.Color = ColorSequence.new(FL.Look.LineHot, FL.Look.Line)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new(1, 0.15)
		tr.Enabled = false
		tr.Parent = o.Body
		o.A0, o.A1, o.Trail = a0, a1, tr
	end
	if o then o.Pool = kind end
	return o
end

local function flutterPut(o)
	if o.Trail then o.Trail.Enabled = false end
	FL.Parent(o, nil)
	table.insert(flutterPool[o.Pool], o)
end

--- a loose petal from `at`, velocity `v`, gravity `g`, `size` long, for `life` s (fading over its last 45 %), never under
--- the floor `gy`; `spin` scales its tumble; `face` (a direction): instead of tumbling it flies FLAT, its face held toward
--- `face` and turning about it like a pinwheel, rocking a little -- the petal's outline always shows. A Flutter's glint
--- trail starts on its second frame (no streak from the pool).
local function flutter(kind, at, v, size, life, gy, spin, g, face)
	local o = flutterGet(kind)
	if not o then return end
	FL.Fade(o, 0)
	FL.Parent(o, H.fxFolder())
	if o.A0 then o.A0.Position, o.A1.Position = Vector3.new(0, -0.4 * size, 0), Vector3.new(0, 0.4 * size, 0) end
	local side = Vector3.yAxis:Cross(v)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
	flutters[#flutters + 1] = { O = o, P0 = at, V = v, T0 = os.clock(), Life = life, S = size, GY = gy, G = g or 9, Side = side,
		Ph = rng:NextNumber(0, 6.28), Spin = Vector3.new(rng:NextNumber(5, 9), rng:NextNumber(-3, 3), rng:NextNumber(2, 5)) * (spin or 1),
		F = 0, Face = face and CFrame.lookAt(Vector3.zero, -face.Unit) or nil, Turn = rng:NextNumber(3.5, 5.5) * (rng:NextNumber() < 0.5 and -1 or 1) }
	if #flutters > 1 then return end
	H.run(function(now, dt, parts, cframes)
		for i = #flutters, 1, -1 do
			local f = flutters[i]
			local t = now - f.T0
			if t >= f.Life then
				flutterPut(f.O)
				table.remove(flutters, i)
			else
				local q = f.P0 + f.V * t - Vector3.new(0, 0.5 * f.G * t * t, 0) + f.Side * (math.sin(t * 10 + f.Ph) * 0.35 * f.S)
				if q.Y < f.GY + 0.15 then q = Vector3.new(q.X, f.GY + 0.15, q.Z) end
				FL.Fade(f.O, H.smooth((t - 0.55 * f.Life) / (0.45 * f.Life)))
				local rot = f.Face and (f.Face * CFrame.Angles(0.45 * math.sin(t * 4 + f.Ph), 0, f.Ph + f.Turn * t))
					or CFrame.Angles(f.Ph + f.Spin.X * t, f.Spin.Y * t, f.Spin.Z * t)
				FL.Place(f.O, CFrame.new(q) * rot, parts, cframes, f.S)
				f.F += 1
				if f.F == 2 and f.O.Trail then
					f.O.Trail:Clear()
					f.O.Trail.Enabled = true
				end
			end
		end
		return #flutters > 0
	end)
end

----------------------------------------------------------------------------------------------------
-- FLASH FREEZE: the field (VFXLibrary.CastFlashFreeze -> CryoFX.LotusField). Times are seconds after the cast: the front
-- leaves at leadIn and reaches the rim expand later; the rim's wave breaks it all from breakTime, wave later at the rim.
-- (The Rare field, restored 2026-10-15 at the developer's ask: the Epic mandala / boundary version is in ServerStorage
-- CryoKitSuperseded.before_ff_rare_restore_2026_10_15.)
----------------------------------------------------------------------------------------------------
function LFX.Field(ground, R, leadIn, expand, breakTime, wave, caster)
	if not FL.Kind("FieldBloom") then return end
	local n = FL.ZoneLotus[tier(caster)]
	local folder = Instance.new("Folder")
	folder.Name = "FrostLotusField"
	folder.Parent = H.fxFolder()
	local c = ground.Position
	local list = {}
	for i, b in ipairs(FL.Field(n, R, 7)) do
		local o = FL.New("FieldBloom", folder)
		if o then
			FL.Fade(o, 1)
			local d = math.sqrt(b.X * b.X + b.Z * b.Z) / R
			list[#list + 1] = { O = o, K = FL.BloomFrame(c + Vector3.new(b.X, 0.05, b.Z), Vector3.yAxis, 0.7 * i), S = b.R,
				Grow = leadIn + expand * d, Break = breakTime + wave * d, At = c + Vector3.new(b.X, 0.4, b.Z), Sparkled = false }
		end
	end
	local dens = H.density(caster)
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		local alive = false
		for _, b in ipairs(list) do
			if b.O then
				if t >= b.Break or not folder.Parent then
					if folder.Parent then                                     -- it bursts on the wave, low and out
						for _ = 1, 2 do
							petalOut(b.At, H.dirAt(rng:NextNumber(0, 2 * math.pi)), b.S * 0.3, c.Y, 1.6)
						end
						H.burst(b.At, Vector3.new(0, 0.35, 0) + H.dirAt(rng:NextNumber(0, 2 * math.pi)), { Chips = 6, Powder = 2 }, dens, 0.8)
						sparkle(b.At, 1, 3)
					end
					FL.Drop(b.O)
					b.O = nil
				else
					alive = true
					local u = (t - b.Grow) / 0.3
					if u > 0 then
						FL.Fade(b.O, 0)
						FL.Place(b.O, b.K, parts, cframes, b.S * math.max(0.02, H.easeOut(math.min(u, 1))))
						if not b.Sparkled then
							b.Sparkled = true
							sparkle(b.At + Vector3.new(0, 0.4, 0), 1, 2)
						end
					end
				end
			end
		end
		if not alive then
			folder:Destroy()
			return false
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- MIRROR CAGE, Epic (concept B, approved 2026-10-15): one giant lotus blooms from the ground under the TARGET (the cage's
-- centre; 2026-10-15 fix: it was under the caster) -- the pod rises under the trapped, the stamens unfold, the rings open
-- outer first -- and holds its open shape through the volley. CryoFX keeps the panels' layout (unseen now), fire list
-- and flight; every bolt leaves from a petal where it sits and flies in at the target (the outer ring first, the side
-- facing the caster first), the petal thinning a little per bolt and spent on its last, so the bloom thins to the bare
-- pod. The flight's TIME stays the Default's (TimeFrom). At the end the unspent petals shed and fall, then the pod sinks.
-- KEYHOLE: on each client, the petals and stamen sectors between this camera and a player in the bloom (or a trapped one
-- anywhere) fade to a ghost, so every body stays in sight; the nearest parts to a camera inside the bloom (the inner
-- ring, the stamens: the trapped player's own view) also fade by distance (VFXLibrary.RegisterProximityFade).
----------------------------------------------------------------------------------------------------
local Players = game:GetService("Players")
local KEY = { Every = 3, Ghost = 0.82, Rate = 9, Rows = { 0.7, 1.8, 2.9, 4.0, 4.9 }, Cols = { -0.9, 0, 0.9 } }
local OPEN, SPEND, SHED = 0.45, 0.14, 0.7
local SINK = { At = 0.35, Dur = 0.6, Depth = 1.6 }

function LFX.CageSetup(cage, aimAt, thin, center, gy)
	local G = FL.Giant
	if not (FL.Kind("GiantOuter") and FL.Kind("GiantPod")) then return end      -- still building: nothing extra
	local C = Vector3.new(center.X, gy, center.Z)                    -- under the target: the cage's centre, on its floor
	local croot = typeof(cage.Caster) == "Instance" and cage.Caster:FindFirstChild("HumanoidRootPart")
	local fwd = croot and H.flat(croot.Position - C) or Vector3.zero   -- toward the caster: that side fires first
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
	local back = -fwd
	local right = back:Cross(Vector3.yAxis)
	local L = { C = C, Petals = {}, Order = {}, Sectors = {}, Shot = 0, Total = 0, Frame = 0, Age = 0 }
	for ti, t in ipairs(G.Tiers) do
		local kind = FL.Kind(t.Kind)
		for k = 0, t.N - 1 do
			local a = math.rad(t.Off + 360 * k / t.N)
			local dir = right * math.cos(a) + back * math.sin(a)
			local lift = (k % 2 == 1) and t.Lift or 0
			local o = kind and FL.New(t.Kind, cage.Folder)
			if o then
				FL.Fade(o, 1)
				local K = CFrame.fromMatrix(C + dir * t.R0 + Vector3.new(0, t.Y0 + lift, 0), dir, Vector3.yAxis)
				if lift > 0 then K *= CFrame.Angles(0, 0, math.rad(12 * lift)) end
				L.Petals[#L.Petals + 1] = { O = o, K = K, Kind = kind, Tier = ti, Open = t.Open + 0.012 * k, Dir = dir,
					Face = dir:Dot(fwd), Phase = (a / (2 * math.pi)) % 1, S = 1, KF = 0, KT = 0, G = -1 }
			end
		end
	end
	L.Order = table.clone(L.Petals)
	table.sort(L.Order, function(p, q)
		if p.Tier ~= q.Tier then return p.Tier < q.Tier end
		return p.Face > q.Face
	end)
	L.Pod = FL.New("GiantPod", cage.Folder)
	if L.Pod then FL.Fade(L.Pod, 1) end
	local sk = FL.Kind("GiantStamens")
	if sk and not thin then
		for s = 0, G.Sectors - 1 do
			local o = FL.New("GiantStamens", cage.Folder)
			if o then
				FL.Fade(o, 1)
				local F = CFrame.new(C) * CFrame.Angles(0, 2 * math.pi * s / G.Sectors, 0)
				L.Sectors[#L.Sectors + 1] = { O = o, F = F, At = F * sk.Sphere, R = sk.Radius, KF = 0, KT = 0 }
			end
		end
	end
	for _, pn in ipairs(cage.Panels) do
		pn.Lotus = L
		L.Total += #pn.Fires
	end
	for _, p in ipairs(L.Petals) do                  -- (by distance from this client's camera: only a camera in the bloom)
		if p.Tier == 3 then H.VFXLibrary.RegisterProximityFade(p.O.Body) end
	end
	for _, sc in ipairs(L.Sectors) do H.VFXLibrary.RegisterProximityFade(sc.O.Body) end
	cage.Lotus = L
	cage.Blooms = {}                     -- (CryoFX steps, bursts and drops the skin's cage look while this is set)
end

-- the keyhole's geometry: does the segment a -> a + d pass within r of c; does it cross the triangle p0 p1 p2
local function nearSeg(a, d, c, r)
	local t = math.clamp((c - a):Dot(d) / d:Dot(d), 0, 1)
	return (a + d * t - c).Magnitude < r
end
local function crosses(o, d, p0, p1, p2)
	local e1, e2 = p1 - p0, p2 - p0
	local h = d:Cross(e2)
	local det = e1:Dot(h)
	if math.abs(det) < 1e-9 then return false end
	local f = 1 / det
	local s = o - p0
	local u = f * s:Dot(h)
	if u < 0 or u > 1 then return false end
	local q = s:Cross(e1)
	local v = f * d:Dot(q)
	if v < 0 or u + v > 1 then return false end
	local t = f * e2:Dot(q)
	return t > 0 and t < 0.995
end

local function keyhole(L, cage)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local E, camRight = cam.CFrame.Position, cam.CFrame.RightVector
	for _, p in ipairs(L.Petals) do p.KT = 0 end
	for _, s in ipairs(L.Sectors) do s.KT = 0 end
	local seen = {}
	local function check(m, anywhere)
		if typeof(m) ~= "Instance" or not m.Parent or seen[m] then return end
		seen[m] = true
		local root = m:FindFirstChild("HumanoidRootPart")
		if not root or (not anywhere and H.flat(root.Position - L.C).Magnitude > FL.Giant.R + 8) then return end
		local hum = m:FindFirstChildOfClass("Humanoid")
		local feet = root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 2)
		for _, y in ipairs(KEY.Rows) do
			for _, x in ipairs(KEY.Cols) do
				local P = Vector3.new(root.Position.X, feet + y, root.Position.Z) + camRight * x
				local d = P - E
				for _, p in ipairs(L.Petals) do
					if p.KT == 0 and p.Now and not p.Gone then
						local s, K = p.NowS, p.Now
						if nearSeg(E, d, K * (p.Kind.Sphere * s), p.Kind.Radius * s) then
							for _, t in ipairs(p.Kind.Proxy) do
								if crosses(E, d, K * (t[1] * s), K * (t[2] * s), K * (t[3] * s)) then
									p.KT = KEY.Ghost
									break
								end
							end
						end
					end
				end
				for _, sc in ipairs(L.Sectors) do
					if sc.KT == 0 and nearSeg(E, d, sc.At, sc.R) then sc.KT = KEY.Ghost end
				end
			end
		end
	end
	for _, v in ipairs(cage.Victims or {}) do check(v.Model, true) end
	check(cage.Caster, false)
	for _, plr in ipairs(Players:GetPlayers()) do check(plr.Character, false) end
end

local function ease(x, dt)
	if x.KF ~= x.KT then
		local step = KEY.Rate * dt
		x.KF = (x.KF < x.KT) and math.min(x.KT, x.KF + step) or math.max(x.KT, x.KF - step)
	end
end

function LFX.CageStep(cage, age, parts, cframes)
	local L = cage.Lotus
	if not L then return end
	local dt = math.clamp(age - L.Age, 0, 0.1)
	L.Age = age
	L.Frame += 1
	if L.Frame % KEY.Every == 1 then keyhole(L, cage) end
	-- the pod rises out of the ground, the stamens unfold; the pod's glow pulses on every bolt
	local podU = H.easeOut(math.clamp((age - 0.12) / 0.3, 0, 1))
	local lift = Vector3.new(0, -1.1 * (1 - podU), 0)
	if L.Pod then
		FL.Fade(L.Pod, podU > 0 and 0 or 1)
		local pulse = math.floor(8 * math.exp(-(age - (L.LastShot or -9)) / 0.12) + 0.5) / 8
		if pulse ~= L.Pulse then
			L.Pulse = pulse
			L.Pod.Body.Color = FL.Look.LineHot:Lerp(FL.Look.Heart, pulse)
		end
		FL.Place(L.Pod, CFrame.new(L.C + lift), parts, cframes)
	end
	local stU = H.easeOut(math.clamp((age - 0.3) / 0.3, 0, 1))
	for _, s in ipairs(L.Sectors) do
		ease(s, dt)
		FL.Fade(s.O, stU > 0 and s.KF or 1)
		FL.Place(s.O, s.F + lift, parts, cframes, math.max(0.05, stU))
	end
	-- the petals: open ring by ring, hold, thin per bolt, spent on the last; a glint travels round the Frost Line
	local glint = (age * 0.3) % 1
	for _, p in ipairs(L.Petals) do
		local u = (age - p.Open) / OPEN
		if not p.Gone and u > 0 then
			local e = H.easeOut(math.min(u, 1))
			local s = (0.35 + 0.65 * e) * p.S
			local spend = p.SpentAt and math.clamp((age - p.SpentAt) / SPEND, 0, 1) or 0
			if spend >= 1 then
				FL.Drop(p.O)
				p.Gone = true
			else
				ease(p, dt)
				FL.Fade(p.O, math.max(p.KF, 1 - math.min(1, u * 4), spend))
				p.Now = p.K * CFrame.Angles(0, 0, p.Kind.Closed * (1 - e))
				p.NowS = math.max(0.02, s * (1 - spend))
				FL.Place(p.O, p.Now, parts, cframes, p.NowS)
				if p.O.Line then
					local ph = (p.Phase - glint) % 1
					local g = math.floor(4 * math.max(0, 1 - ph / 0.14) + 0.5) / 4
					if g ~= p.G then
						p.G = g
						p.O.Line.Color = FL.Look.Line:Lerp(FL.Look.LineHot, g)
					end
				end
			end
		end
	end
end

--- where a bolt leaves: the middle of the next petal in the firing order (it thins; on its last bolt it is spent)
function LFX.BoltFrom(pn, aimAt)
	local L = pn.Lotus
	if not (L and #L.Order > 0) then
		return pn.Pos + (aimAt - pn.Pos).Unit * 1.2
	end
	L.Shot += 1
	L.LastShot = L.Age
	local n, total = #L.Order, math.max(L.Total, 1)
	local i = math.min(n, math.floor((L.Shot - 1) * n / total) + 1)
	local p = L.Order[i]
	if p.Gone or p.SpentAt then                              -- (more bolts than planned) any petal still in the bloom
		p = nil
		for _, q in ipairs(L.Order) do
			if not (q.Gone or q.SpentAt) then p = q break end
		end
		if not p then return L.C + Vector3.new(0, 1.2, 0) end
	end
	p.S = math.max(0.55, p.S - 0.1)
	if math.floor(L.Shot * n / total) + 1 > i or L.Shot >= total then p.SpentAt = L.Age end
	return (p.Now or p.K) * (p.Kind.Mid * (p.NowS or 1))
end

--- the Default's start, for the flight's time (CryoFX: Dur from here, so every bolt still lands on its beat)
function LFX.TimeFrom(pn, aimAt)
	return pn.Pos + (aimAt - pn.Pos).Unit * 1.2
end

function LFX.NewBolt(folder)
	local o = FL.New("Lance", folder)
	if o then FL.Fade(o, 0) end
	return o
end

--- the peel (a glint where the petal gives its bolt) and the strike
function LFX.Peel(pos) sparkle(pos, 1, 4) end
function LFX.Strike(pos) sparkle(pos, 2, 6) end

--- the bolt at flight fraction u: a helix round the straight line, 1.5 turns, its radius closing to nothing at the strike
function LFX.PlaceBolt(fly, u, parts, cframes)
	local a, d = fly.From, fly.To - fly.From
	local dir = d.Unit
	local e1 = dir:Cross(Vector3.yAxis)
	if e1.Magnitude < 1e-3 then e1 = dir:Cross(Vector3.xAxis) end
	e1 = e1.Unit
	local e2 = dir:Cross(e1)
	local function at(s)
		local ang = 2 * math.pi * 1.5 * s
		local r = 0.55 * math.sin(math.pi * math.min(1, s * 1.15)) * (1 - s)
		return a + d * s + (e1 * math.cos(ang) + e2 * math.sin(ang)) * r
	end
	local p, q = at(u), at(math.min(1, u + 0.03))
	local tg = ((q - p).Magnitude > 1e-4) and (q - p).Unit or dir
	FL.Place(fly.O, FL.Frame(p - tg * FL.Kinds.Lance.L, tg, Vector3.yAxis), parts, cframes)
end

--- the end: the unspent petals shed (they fold down, drop and fade, a petal mote or two), then the pod sinks
function LFX.CageBurst(cage, aimAt, gy, thin)
	local L = cage.Lotus
	cage.Lotus, cage.Blooms = nil, nil
	if not L then return end
	local t0 = os.clock()
	local fall = {}
	for i, p in ipairs(L.Petals) do
		if not p.Gone and p.Now then
			fall[#fall + 1] = { P = p, Delay = (i % 5) * 0.03, Spin = rng:NextNumber(-0.4, 0.4) }
			if not thin and i % 3 == 0 then
				petalOut(p.Now * (p.Kind.Mid * p.NowS), p.Dir, 0.6, L.C.Y, 1.2)
			end
		elseif not p.Gone then
			FL.Drop(p.O)
			p.Gone = true
		end
	end
	H.run(function(now, dt, parts, cframes)
		local t = now - t0
		for _, f in ipairs(fall) do
			local p = f.P
			if not p.Gone then
				local e = math.clamp((t - f.Delay) / SHED, 0, 1)
				if e >= 1 then
					FL.Drop(p.O)
					p.Gone = true
				else
					local K = CFrame.new(p.Dir * (1.5 * e) - Vector3.new(0, 2.2 * e * e, 0)) * p.Now
						* CFrame.Angles(f.Spin * e, 0, -math.rad(28) * e)
					FL.Fade(p.O, math.max(p.KF, H.smooth((e - 0.35) / 0.65)))
					FL.Place(p.O, K, parts, cframes, p.NowS)
				end
			end
		end
		local su = math.clamp((t - SINK.At) / SINK.Dur, 0, 1)
		local down = Vector3.new(0, -SINK.Depth * H.smooth(su), 0)
		local fade = H.smooth((su - 0.5) / 0.5)
		if L.Pod then
			FL.Fade(L.Pod, fade)
			FL.Place(L.Pod, CFrame.new(L.C + down), parts, cframes)
		end
		for _, s in ipairs(L.Sectors) do
			FL.Fade(s.O, math.max(s.KF, fade))
			FL.Place(s.O, s.F + down, parts, cframes)
		end
		if su >= 1 and t > SHED + 0.2 then
			LFX.CageDrop({ Lotus = L })
			return false
		end
		return true
	end)
end

function LFX.CageDrop(cage)
	local L = cage.Lotus
	cage.Lotus, cage.Blooms = nil, nil
	if not L then return end
	for _, p in ipairs(L.Petals) do
		if not p.Gone then FL.Drop(p.O) p.Gone = true end
	end
	FL.Drop(L.Pod)
	for _, s in ipairs(L.Sectors) do FL.Drop(s.O) end
	L.Pod, L.Sectors = nil, {}
end

----------------------------------------------------------------------------------------------------
-- COLD MOMENTUM (Epic stage 3): on the Default's print (its frame: +Y the ground's normal), a small flat lotus bloom
-- scaling and fading with it, and two small petals dropping beside it -- falling flat, turning, landing and fading as
-- the body runs on (so they lie behind it). Low count; the bloom and the petals are pooled.
----------------------------------------------------------------------------------------------------
local printPool = {}
function LFX.Print(cf, PR, thin)
	local o = table.remove(printPool) or FL.New("PrintBloom")
	if not o then return end
	FL.Fade(o, 1)
	FL.Parent(o, H.fxFolder())
	for _ = 1, (thin and 0 or 2) do                       -- (2026-10-19, audit P5A-12) thinned: the bloom only
		local d = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		flutter("FlutterS", cf.Position + Vector3.new(0, rng:NextNumber(1.0, 1.6), 0) + d * 0.3, d * 0.5 + Vector3.new(0, 0.3, 0),
			0.55, 0.95, cf.Position.Y, 1, 3.5, Vector3.yAxis)
	end
	if not thin then sparkle(cf.Position + Vector3.new(0, 0.2, 0), 1, 0) end
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local age = now - t0
		if age >= PR.Life then
			FL.Fade(o, 1)
			FL.Parent(o, nil)
			table.insert(printPool, o)
			return false
		end
		local k = (age < PR.Pop) and (0.6 + 0.4 * H.easeOut(age / PR.Pop)) or 1
		FL.Fade(o, H.smooth((age - PR.Hold) / (PR.Life - PR.Hold)))
		FL.Place(o, cf * CFrame.new(0, 0.02, 0), parts, cframes, 0.3 * k)
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- DEEP FREEZE's tap (the caster's own client): three tiny blooms sprout round the trap and melt on the Default's beat
----------------------------------------------------------------------------------------------------
function LFX.Tap(pos, folder, TP, T0)
	local list = {}
	for k = 0, 2 do
		local a = 2 * math.pi * k / 3 + 0.5
		local o = FL.New("MiniBloom", folder)
		if o then
			FL.Fade(o, 1)
			list[#list + 1] = { O = o, K = FL.BloomFrame(pos + Vector3.new(math.cos(a) * 0.45, 0.03, math.sin(a) * 0.45), Vector3.yAxis, a), D = 0.04 * k }
		end
	end
	sparkle(pos + Vector3.new(0, 0.3, 0), 2, 3)
	H.run(function(now, dt, parts, cframes)
		local age = H.serverNow() - T0
		if not folder.Parent or age > TP.MeltBy + 0.05 then
			for _, b in ipairs(list) do FL.Drop(b.O) end
			return false
		end
		local melt = H.smooth((age - TP.MeltAt) / (TP.MeltBy - TP.MeltAt))
		for _, b in ipairs(list) do
			local u = (age - b.D) / 0.14
			if u > 0 then
				FL.Fade(b.O, melt)
				FL.Place(b.O, b.K * CFrame.new(0, -0.1 * melt, 0), parts, cframes, 0.3 * math.max(0.02, H.easeOut(math.min(u, 1))))
			end
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- BLIZZARD (Epic stage 3): petal STREAKS blowing ONE way across the zone on the storm's wind (CryoFX hands it over),
-- most of them in the outer band, few through the middle, never a spiral: each a long thin pale petal, a glowing edge
-- and a short glint trail, crossing a stretch of the zone and fading before the Frost Line, then re-spawning upwind; up as the storm
-- forms, gone as it thins. The wall's flecks are icy-blue glitter and stream the same way (StormFleck). The Frost Line arcs and
-- the settle-to-clear tell are CryoFX's, untouched. Thin and few: no more in the way than the Default's snow.
----------------------------------------------------------------------------------------------------
function LFX.StormFleck(props, tangent, wind)
	props.Texture = FL.Look.Sparkle
	props.Color = ColorSequence.new(FL.Look.Glitter, FL.Look.IceBlue)      -- (Epic) tinted icy blue: the zone has body
	props.LightEmission = 0.5
	props.LightInfluence = 0.3
	if tangent and wind and typeof(props.Acceleration) == "Vector3" then     -- round the ring -> the wind's one way
		local acc = props.Acceleration
		local along = acc:Dot(tangent)
		props.Acceleration = acc - tangent * along + wind * math.abs(along)
	end
end

function LFX.Storm(s, c, R, form, caster, wind)
	if not FL.Kind("Streak") then return end
	if not wind then
		local root = caster and caster:FindFirstChild("HumanoidRootPart")
		local look = root and H.flat(root.CFrame.LookVector) or Vector3.zAxis
		wind = (look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis):Cross(Vector3.yAxis)
	end
	wind = H.flat(wind)
	wind = wind.Magnitude > 1e-3 and wind.Unit or Vector3.xAxis
	local list = {}
	for _ = 1, FL.StormStreaks[tier(caster)] do
		local o = FL.New("Streak", s.Folder)
		if o then
			FL.Fade(o, 1)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(-0.2, 0, 0), Vector3.new(0.2, 0, 0)
			a0.Parent, a1.Parent = o.Body, o.Body
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.FaceCamera, tr.Lifetime, tr.MinLength = true, 0.12, 0.05
			tr.LightEmission, tr.LightInfluence = 1, 0
			tr.Color = ColorSequence.new(FL.Look.LineHot, FL.Look.Line)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			tr.Enabled = false
			tr.Parent = o.Body
			list[#list + 1] = { O = o, Tr = tr, T0 = -1, Life = 0 }
		end
	end
	local function respawn(p, age)
		local a, r = rng:NextNumber(0, 2 * math.pi), R * (0.5 + 0.48 * math.sqrt(rng:NextNumber()))
		p.Life, p.V = rng:NextNumber(0.7, 1.1), rng:NextNumber(16, 24)
		p.P0 = c + Vector3.new(math.cos(a) * r, rng:NextNumber(0.6, 7), math.sin(a) * r) - wind * (p.V * p.Life * 0.5)
		p.T0, p.S, p.Wob, p.Fresh = age, rng:NextNumber(0.8, 1.15), rng:NextNumber(0, 6.28), 2
		p.Tr.Enabled = false
	end
	H.run(function(now, dt, parts, cframes)
		if not s.Folder.Parent then
			for _, p in ipairs(list) do FL.Drop(p.O) end
			return false
		end
		local age = H.serverNow() - s.T0
		local thinAt = s.Ended and s.EndAge or (s.Duration - 1.8)
		local on = H.smooth((age - form) / 1.4) * (1 - H.smooth((age - thinAt) / 1.2))
		for _, p in ipairs(list) do
			if p.T0 < 0 or age - p.T0 >= p.Life then
				if on > 0.02 then
					respawn(p, age)
				elseif p.T0 >= 0 then
					p.T0 = -1
					p.Tr.Enabled = false
					FL.Fade(p.O, 1)
				end
			end
			if p.T0 >= 0 then
				local t = age - p.T0
				local pos = p.P0 + wind * (p.V * t) + Vector3.new(0, 0.35 * math.sin(t * 6 + p.Wob), 0)
				local inside = 1 - H.smooth((H.flat(pos - c).Magnitude - (R - 2.5)) / 2.5)
				local vis = on * inside * math.clamp(math.min(t / 0.12, (p.Life - t) / 0.15), 0, 1)
				FL.Fade(p.O, 1 - vis)
				FL.Place(p.O, FL.Frame(pos, wind, Vector3.yAxis) * CFrame.Angles(0, p.Wob + t * 4, 0), parts, cframes, p.S)
				p.Fresh -= 1
				if p.Fresh == 0 then
					p.Tr:Clear()
					p.Tr.Enabled = vis > 0.05
				end
			end
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- THE DART'S HIT: a tiny bloom opening on the surface, facing back along the shot, fading in under a second. On a body
-- it rides the part it struck, as the Default's frost patch does (2026-10-15: fixed in the world, it hung in the air
-- behind a moving target); on the world it stays where it opened.
----------------------------------------------------------------------------------------------------
local hitPool, ringPool = {}, {}
local function pooled(pool, kind)
	return table.remove(pool) or FL.New(kind)
end
local function release(pool, o)
	FL.Fade(o, 1)
	FL.Parent(o, nil)
	table.insert(pool, o)
end

--- (CryoFX.ShardImpact, on each client at its own shot's hit: the shooter's on theirs.) A lotus of 6 petals pops open on
--- the hit (1.6 across x 2), and after 0.12 s its petals peel off and flutter out along the surface, spinning, for about
--- 0.4 s (FlutterS); a thin ring flash races out from it (smaller and dimmer under Reduce Flashing; none when thinned).
function LFX.HitBloom(hit, dir, thin, caster)
	local o = pooled(hitPool, "HitLotus")
	if not o then return end
	local folder = H.fxFolder()
	local calm = H.Settings.Get and H.Settings.Get("ReduceFlashing")
	FL.Fade(o, 1)
	FL.Parent(o, folder)
	local K0 = FL.BloomFrame(hit.Position + hit.Normal * 0.06, hit.Normal, rng:NextNumber(0, 6.28))
	local part = hit.Instance
	local body = part and part:IsA("BasePart") and part:FindFirstAncestorOfClass("Model")
	local rel = (body and body:FindFirstChildOfClass("Humanoid")) and part.CFrame:ToObjectSpace(K0) or nil
	local ring = (not thin) and pooled(ringPool, "HitRing") or nil
	if ring then
		FL.Fade(ring, 1)
		FL.Parent(ring, folder)
	end
	sparkle(hit.Position + hit.Normal * 0.2, 1, 2)
	local t0 = os.clock()
	H.run(function(now, dt, parts, cframes)
		local a = now - t0
		local K = (rel and part.Parent) and part.CFrame * rel or K0
		if ring then
			local u = a / 0.22
			if u >= 1 then
				release(ringPool, ring)
				ring = nil
			else
				FL.Fade(ring, calm and (0.55 + 0.45 * u) or u)
				FL.Place(ring, K, parts, cframes, (calm and 1.4 or 2.4) * (0.2 + 0.8 * H.easeOut(u)))
			end
		end
		if o then
			if a >= 0.12 or (rel and not part.Parent) then
				local n = thin and 3 or 6
				local gy = (K.UpVector.Y > 0.7) and K.Position.Y or (K.Position.Y - 3)
				for i = 1, n do
					local ang = 2 * math.pi * i / n
					local d = K.RightVector * math.cos(ang) + K.ZVector * math.sin(ang)
					flutter("FlutterS", K.Position + d * 0.9 + K.UpVector * 0.25, d * rng:NextNumber(2.5, 4) + K.UpVector * rng:NextNumber(1.5, 2.5),
						0.85, 0.42, gy, 1.6, 4)
				end
				release(hitPool, o)
				o = nil
			else
				FL.Fade(o, 0)
				FL.Place(o, K, parts, cframes, 1.6 * math.max(0.1, H.easeOut(math.min(a / 0.08, 1))))
			end
		end
		return o ~= nil or ring ~= nil
	end)
end

--- the kit let go of its meshes (2026-10-19, MeshBudget): every pooled piece here goes with it
function LFX._release()
	for _, list in pairs(flutterPool) do
		for _, o in ipairs(list) do FL.Drop(o) end
		table.clear(list)
	end
	for _, o in ipairs(printPool) do FL.Drop(o) end
	table.clear(printPool)
end

return LFX
