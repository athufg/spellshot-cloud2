--[[
	PyroFlame_Fire  (ReplicatedStorage.IceMagic.PyroFlame_Fire, ModuleScript, CLIENT)          Pyro Phase 3, 2026-10-05

	The V1 "Layered blaze+" look of FIREBALL (M1), IMMOLATE (Primary) and EMBER REFUND (Passive): flames only, drawn
	with PyroDraw from the Phase 3 flame library (ReplicatedStorage.FireMagicMeshes.Flame). Ported from the confirmed Blender
	pieces (vmarm/pyro/vis2026/fie: lib/fie_lib_r2.py + lib/fie_fire_r2.py, scripts/fireball_r2.py, immolate_r2.py,
	ember_refund_r2.py) onto the LIVE beats and call contracts of PyroFX. Inert at require (services only): PyroFX is
	required by the server too, so PyroFX must require this lazily, on a client, the way it requires Viewmodel.

	DROP-IN FOR PyroFX (same parameters, same clocks, same attributes; PyroFX delegates when its look is "flame"):
	  Fire.Charge(character, side, hot, ownView, startClock)            = PyroFX.Charge
	  Fire.FireFireball(origin, dir, exclude, visualFrom, onHit, hot)   = PyroFX.FireFireball   (its hit detection, verbatim)
	  Fire.Burst(position, hot?, back?, own?)                           = PyroFX.Burst          (the three extras are optional)
	  Fire.Immolate(character, serverT0) -> controller                  = PyroFX.Immolate       (reads Stacks_Primary)
	  Fire.EmberRefund(character, from?)                                = PyroFX.EmberRefund    (from: optional, see below)
	  Fire.Init({ PyroFX, AddEffect, MoteControllers, Fallen })         once, optional: share PyroFX's own render step, its
	                                                                    moteControllers table and its book of the fallen (see WIRING)
	  Fire.Ready() -> bool                                              PyroDraw and the flame meshes are there
	  Fire.Visual                                                       every visual-only number (nothing the server reads)

	WHAT IS LIVE AND STAYS LIVE (PyroFX.Tuning, read here, never written): Fireball Speed / Life / Trigger / ChargeFrom /
	ChargePeakTP / ChargePeakFP / GrowTP / GrowFP / Merge / BurstNear, the raycast per frame along FireballPoint, the hit
	report BEFORE anything cosmetic; Immolate Trigger / OrbitAt / OrbitRadius / OrbitSpeed / Chest / PopIn and "slot i is
	spent once i > Stacks_Primary, after a non-zero count was seen", no timeout; EmberRefund.Ring's 13 frames.
	Clocks as live: Charge and the flight on the shot clock (VFXLibrary.ShotTimeScale), Burst / Immolate / EmberRefund on
	real time, a server stamp through workspace:GetServerTimeNow.

	FIRST PERSON (the designs were rendered from a shoulder camera; these are this port's rules, in Fire.Visual):
	  Charge      on the viewmodel fist (GetArmCFrame(side) * (0, 0, -1.25 - 0.25 s), as live), x ChargePeakFP / ChargePeakTP
	              (0.22), no gather sparks, its motion read against the camera
	  Fireball    your own ball: the live 0.11 -> 1 growth, a shorter tail (OwnTail) that never reaches back past
	              OwnFrom s of flight, smaller and shorter wisps (the live own-ember rule)
	  Immolate    your own motes and the refund ring stay at ROOT height as live (MoteLiftFP = 0: lifted they cross the
	              crosshair); the chest burst at the live chest point x CastFP; no fire on the viewmodel arms
	THINNING: every canvas takes PyroDraw's density (Settings.EffectDensity, x 0.6 for other players under
	Settings.ThinEnemyVFX); the Fireball also applies the live expression (density < 0.75 or thinned enemy): half the
	wisps and embers. Settings "ReduceFlashing": the bursts lose their flash swell.

	NOT DRAWN HERE, MUST KEEP RUNNING: the burn on a body a buffed hit landed on (the live Immolate draws nothing on
	the target: that is PyroFX.startBurn off RX_Burning_Stacks, and StatusReactions / BarFX), CastPose / Viewmodel clips,
	every sound, the HUD. No comic word belongs to these three abilities.

	WIRING (PyroFX): a lazy loader that requires this module, calls Fire.Init({ PyroFX = PyroFX, AddEffect = addEffect,
	MoteControllers = moteControllers }) once, and at the top of Charge / FireFireball / Burst / Immolate / EmberRefund:
	`if look() == "flame" then return flame().X(...) end`. With MoteControllers shared, a re-cast stops the other look's
	motes exactly as it stops its own. EmberRefund's streak needs where the enemy fell: the broadcast carries only the
	caster, so without `from` (a Vector3, a part or a model) it looks for the nearest humanoid at 0 health; with neither
	it draws the ring alone, at once, as live.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fire = {}

----------------------------------------------------------------------------------------------------
-- VISUAL NUMBERS (the look only; gameplay numbers are PyroFX.Tuning's and are not copied here)
----------------------------------------------------------------------------------------------------
local V = {
	-- FIREBALL (fie_lib_r2.Throw)
	ChargeSize = { 0.14, 0.58 },      -- the fist flame's size = [1] + [2] x the wind-up's ease (hand_flame; 1 = 2.9 studs tall)
	ChargeFP = 1.0,                   -- first person: x ChargePeakFP / ChargePeakTP, x this
	GatherRadius = 1.7,               -- sparks drawn in to the fist (not in first person)
	TearTime = 0.13, TearWidth = 0.75, TearSpan = 0.07,     -- the fist's last fire tears off through the follow-through
	TailSpan = 0.15,                  -- the ball's tail = the path of its last TailSpan s (HOT x 1.3, PyroDraw)
	OwnTail = 0.6, OwnFrom = 0.05, OwnWisp = 0.7, OwnWispLife = 10 / 14,     -- your own ball, seen from behind it
	WispRate = 50, WispLife = 0.4, Embers = 45,
	BurstSize = 3.0, BurstLife = 0.5, BurstArcs = 72, BurstUp = 0.25,       -- thrown back the way it came, a little up
	-- IMMOLATE (fie_fire_r2.Motes, mote_draw, mote_wisps, mote_spend_fx, immolate_ignite, arm_wash)
	MoteLift = 1.3, MoteLiftFP = 0,   -- the orbit plane over the root at full radius (your own, in first person)
	MoteBob = 0.08, MoteSize = 1.0, MoteBall = 0.33, MoteWatts = 170,
	MoteSpan = { 0.09, 0.17 },        -- the mote's tail: short while it spirals out, the full one on the orbit
	MoteWispRate = 6, MoteWispLife = 0.34, MoteWispScale = 0.36,
	SpendSparks = 36, SpendLife = 0.8,
	CastSize = 1.8, CastLife = 0.38, CastFP = 0.5, CastSparks = 30,
	ChestOut = 0.85,                  -- the chest point: this far in front of the UpperTorso
	Wash = { n = 4, reach = 0.085, hold = 0.11, out = 0.13 },
	-- EMBER REFUND (fie_fire_r2.flare_ring, ember_streak; ember_refund_r2.py)
	RingDelay = 0.30,                 -- with a streak the ring lights when its first flame lands (design); without, at once (live)
	RingLife = 0.95, RingLicks = 20, RingSeed = 5, RingLength = 2.3, RingSpin = 180, RingClear = 0.75, RingHoop = 0.6,
	RingWisps = 14, RingEmbers = 34,
	StreakDelay = 0.02, StreakLeaders = 7, StreakBorn = 0.13, StreakFlight = { 0.28, 0.32 }, StreakSeed = 8,
	StreakMin = 3.0, StreakMax = 160, -- no streak from closer than the orbit; the search range for the fallen body
	FallenFresh = 0.5,                -- the streak's source fell no longer ago than this (s), by PyroFX's book (Fire.Init's Fallen)
	StreakRef = 16,                   -- the distance the streak was designed at (its tails keep that length from farther)
	PuffSparks = 44,
	RootHeight = 3.0,                 -- the HumanoidRootPart's centre over the floor (the ring's floor glow)
}
Fire.Visual = V

----------------------------------------------------------------------------------------------------
-- LIBS (lazy), MATHS
----------------------------------------------------------------------------------------------------
local sin, cos, floor, ceil, min, max, exp, sqrt, abs, rad, pi = math.sin, math.cos, math.floor, math.ceil, math.min,
	math.max, math.exp, math.sqrt, math.abs, math.rad, math.pi
local clamp = math.clamp
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)
local ZERO = Vector3.new(0, 0, 0)

local PyroFX: any, T: any, PD: any, Viewmodel: any, VFXLibrary: any, Settings: any = nil, nil, nil, nil, nil, nil
local sst: any, equint: any, eback: any, rnd: any = nil, nil, nil, nil
local moteControllers = {}          -- [character] = controller; PyroFX's own table after Fire.Init
local fallen = nil                  -- [model] = os.clock() when PyroFX's watcher first saw it at 0 health (Fire.Init's Fallen)

local function libs()
	if PD then return end
	local ice = script.Parent
	if not (ice and ice:FindFirstChild("PyroDraw")) then ice = ReplicatedStorage:WaitForChild("IceMagic") end
	PyroFX = PyroFX or require(ice:WaitForChild("PyroFX"))
	T = PyroFX.Tuning
	VFXLibrary = require(ice:WaitForChild("VFXLibrary"))
	Viewmodel = require(ice:WaitForChild("Viewmodel"))
	Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	local pd = require(ice:WaitForChild("PyroDraw"))
	sst, equint, eback, rnd = pd.sst, pd.equint, pd.eback, pd.Rand
	PD = pd
end

local warned = {}
local function warnOnce(key, msg)
	if not warned[key] then
		warned[key] = true
		warn("[PyroFlame_Fire] " .. msg)
	end
end

local function easeOutQuad(x)
	x = clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

--- A live 30 fps scale table sampled smoothly between its frames (the kit's seq_s): 0 before it, `after` (or its
--- last value) once it has run out.
local function seqS(list, tau, after)
	if tau < 0 then return 0 end
	local x = tau * 30
	local i = floor(x)
	if i >= #list - 1 then return after or list[#list] end
	return list[i + 1] + (list[i + 2] - list[i + 1]) * (x - i)
end

local function unit(v, fallback)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return fallback or UP
end

local function flat(v, fallback)
	local h = Vector3.new(v.X, 0, v.Z)
	local m = h.Magnitude
	if m > 1e-3 then return h / m end
	return fallback
end

--- the kit's runit: a unit vector per (id, seed)
local function runit(k, seed, c0)
	local z = rnd(seed, k, c0) * 2 - 1
	local a = rnd(seed, k, c0 + 1) * TAU
	local r = sqrt(max(0, 1 - z * z))
	return Vector3.new(-r * cos(a), z, r * sin(a))
end

--- a detached tongue's swell and pinch over its life f 0..1 (the kit's _bright_wisps envelope)
local function wispEnv(f, lead)
	return max(0, sin(pi * min(1, f * 0.9 + lead))) ^ 0.8
end

--- The os.clock() moment that a server-time stamp corresponds to on this machine (PyroFX.localClock).
local function localClock(serverT0)
	if type(serverT0) ~= "number" then return os.clock() end
	return os.clock() - (workspace:GetServerTimeNow() - serverT0)
end

local function isLocal(character)
	return character ~= nil and character == Players.LocalPlayer.Character
end

local function firstPerson()
	return Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson
end

local function fxFolder()
	local name = VFXLibrary.Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function reduceFlashing()
	return (Settings.Get and Settings.Get("ReduceFlashing")) and true or false
end

----------------------------------------------------------------------------------------------------
-- THE RENDER STEP (PyroFX's engine: closures fn(now, dt) -> alive, each in pcall). Fire.Init can hand over
-- PyroFX's own addEffect, so both looks run on the one "SpellshotPyroFX" step.
----------------------------------------------------------------------------------------------------
local STEP = "SpellshotPyroFlameFire"
local effects = {}
local bound = false
local sharedAdd = nil

local function step(dt)
	local now = os.clock()
	for i = #effects, 1, -1 do
		local ok, alive = pcall(effects[i], now, dt)
		if not ok then
			warnOnce("step", "an effect failed: " .. tostring(alive))
			alive = false
		end
		if not alive then table.remove(effects, i) end
	end
	if #effects == 0 and bound then
		RunService:UnbindFromRenderStep(STEP)
		bound = false
	end
end

local function addEffect(fn)
	if sharedAdd then
		sharedAdd(fn)
		return
	end
	table.insert(effects, fn)
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 4, step)
	end
end

--- One frame of a canvas: draw(cv, t, a, b) between Begin and End. -> what draw returned, or nil when it failed
--- (warned once): the caller then ends the effect, so nothing is left standing on screen.
local function guarded(cv, t, draw, a, b)
	cv:Begin(t)
	local ok, res = pcall(draw, cv, t, a, b)
	cv:End()
	if not ok then
		warnOnce("draw:" .. cv.Name, cv.Name .. ": " .. tostring(res))
		return nil
	end
	return res
end

----------------------------------------------------------------------------------------------------
-- A SHORT HISTORY OF A MOVING POINT (a fist): what a streaming tail needs to follow the path it took.
-- tr.Frame: points are held in that CFrame's space (the camera, for what rides the viewmodel) and read back in it.
----------------------------------------------------------------------------------------------------
local function newTrack(n)
	return { n = n, i = 0, count = 0, t = table.create(n, 0), p = table.create(n, ZERO), Frame = nil }
end

local function trackPush(tr, t, p)
	local i = tr.i % tr.n + 1
	tr.i = i
	tr.t[i] = t
	tr.p[i] = p
	if tr.count < tr.n then tr.count += 1 end
end

local function trackAt(tr, tq)
	if tr.count == 0 then return ZERO end
	local n, i = tr.n, tr.i
	local t1, p1 = tr.t[i], tr.p[i]
	local out = p1
	if tq < t1 then
		for k = 1, tr.count - 1 do
			local j = (i - k - 1) % n + 1
			local t0, p0 = tr.t[j], tr.p[j]
			out = p0
			if tq >= t0 then
				local d = t1 - t0
				if d > 1e-6 then out = p0:Lerp(p1, (tq - t0) / d) end
				break
			end
			t1, p1 = t0, p0
		end
	end
	local frame = tr.Frame
	if frame then return frame * out end
	return out
end

----------------------------------------------------------------------------------------------------
-- M1: FIREBALL
----------------------------------------------------------------------------------------------------
--- The fire gathering on a fist through the punch's windup (PyroFX.Charge's anchors and clock): a flame standing on
--- the fist that leans against its motion, sparks drawn in to it; at the release the fist's last fire tears off
--- through the follow-through (TearTime). `ownView`: the caller's claim that it is the local player's own.
function Fire.Charge(character, side, hot, ownView, startClock)
	libs()
	local F = T.Fireball
	local own = ownView and true or false
	-- as live: on the viewmodel's fist only when the camera is in the head, otherwise on the body's hand
	local fp = own and firstPerson()
	hot = hot and true or false
	local cv = PD.new("PyroCharge", { own = own, hot = hot })
	local start = startClock or os.clock()
	local handName = (side == "L") and "LeftHand" or "RightHand"
	local peak = fp and F.ChargePeakFP or F.ChargePeakTP
	local k = fp and (F.ChargePeakFP / F.ChargePeakTP) * V.ChargeFP or 1
	local seed = (side == "L") and 1 or 0
	local track = newTrack(24)
	local function fistAt(tq) return trackAt(track, tq) end
	local lastLocal, lastU = nil, 0
	local flameO = { size = 0, hot = hot, seed = 13 + seed, vel = ZERO }
	local gatherO = { id = "gather", radius = V.GatherRadius, hot = hot }
	local tearO = { width = 0, hot = hot, span = V.TearSpan, t_min = F.Trigger - 0.06, rise = 9 * k, seed = 5 + seed }

	local function frame(_, u)
		local g = easeOutQuad((u - F.ChargeFrom) / (F.Trigger - F.ChargeFrom))
		local s = peak * g
		local pos, camCF
		if fp then
			local armCF = Viewmodel.GetArmCFrame(side)
			if not armCF then return true end
			pos = (armCF * CFrame.new(0, 0, -1.25 - 0.25 * s)).Position
			local cam = workspace.CurrentCamera
			camCF = cam and cam.CFrame
		else
			local hand = character:FindFirstChild(handName)
			if not hand then return true end
			pos = (hand.CFrame * CFrame.new(0, -0.15 - (0.05 + 0.62 * s), 0)).Position
		end
		-- the fist's own motion; in first person against the view, which the arm rides
		local loc = camCF and camCF:PointToObjectSpace(pos) or pos
		local vel = ZERO
		if lastLocal and u > lastU then
			vel = (loc - lastLocal) / (u - lastU)
			if camCF then vel = camCF:VectorToWorldSpace(vel) end
		end
		lastLocal, lastU = loc, u
		track.Frame = camCF
		trackPush(track, u, loc)
		if u < F.ChargeFrom then return true end
		if u < F.Trigger then
			flameO.size = (V.ChargeSize[1] + V.ChargeSize[2] * g) * k
			flameO.vel = vel
			cv:hand_flame(pos, u, flameO)
			if not fp then cv:ember_gather(pos, u, F.ChargeFrom + 0.01, F.Trigger - 0.05, gatherO) end
		else
			local v = 1 - (u - F.Trigger) / V.TearTime
			if v > 0.05 then
				tearO.width = V.TearWidth * v * k
				cv:fire_tail(fistAt, u, tearO)
			end
		end
		return true
	end

	addEffect(function(now)
		local u = (now - start) * VFXLibrary.ShotTimeScale()
		if u >= F.Trigger + V.TearTime or not character.Parent or not guarded(cv, u, frame) then
			cv:Destroy()
			return false
		end
		return true
	end)
end

local burstSeq = 0

--- The impact (PyroFX.Burst's clock and its BurstNear rule): the ball's own shells blown open into a bulb with a torn
--- licking crown, licks thrown out round the way it came, wisps left rising, its sparks and the long-arc embers.
--- `hot`, `back` (unit: the way the ball came, default up) and `own` are optional: FireFireball passes them.
function Fire.Burst(position, hot, back, own, wrap)
	libs()
	local F = T.Fireball
	hot = hot and true or false
	back = back or UP
	local born = os.clock()
	local cam = workspace.CurrentCamera
	local k = (cam and (position - cam.CFrame.Position).Magnitude < F.BurstNear) and 0.4 or 1
	burstSeq = (burstSeq + 1) % 8
	local cv = PD.new("PyroBurst", { own = own and true or false, hot = hot, wrap = wrap })
	local burstO = { size = V.BurstSize * k, hot = hot, seed = 700 + 31 * burstSeq, back = back, flash = not reduceFlashing() }
	local arcsO = { id = "arcs", count = V.BurstArcs * k, hemi = flat(back, back), hot = hot }

	local function frame(_, tau)
		cv:burst(position, tau / V.BurstLife, burstO)
		cv:ember_burst(position, tau, arcsO)
		return true
	end

	addEffect(function(now)
		local tau = now - born
		if tau > 1.85 * V.BurstLife or not guarded(cv, tau, frame) then
			cv:Destroy()
			return false
		end
		return true
	end)
end

local function drawFlight(cv, t, st)
	local F = T.Fireball
	if st.offset and st.cam then st.travel = st.cam.CFrame.Position - st.camStart end
	local peak = st.own and F.ChargePeakFP or F.ChargePeakTP
	local o = st.ballO
	o.scale = peak + (1 - peak) * easeOutQuad(t / (st.own and F.GrowFP or F.GrowTP))
	cv:fire_ball(st.ballAt, t, o)
	cv:wisps(st.ballAt, t, st.wispFrom, st.wispTo, st.wispO)
	cv:embers(st.ballAt, t, st.emberO)
	return true
end

local function drawAfter(cv, t, st)
	cv:wisps(st.ballAt, t, st.wispFrom, st.wispTo, st.wispO)
	return true
end

--- What the ball leaves when it stops at flight time tEnd: the tongues it shed live out their life, then the canvas goes.
local function afterglow(st, tEnd)
	local cv = st.cv
	st.wispTo = tEnd
	if st.off or guarded(cv, tEnd, drawAfter, st) == nil then
		cv:Destroy()
		return
	end
	local endAt = os.clock()
	local life = st.wispO.life + 0.03
	addEffect(function(now)
		local age = now - endAt
		if age > life or guarded(cv, tEnd + age, drawAfter, st) == nil then
			cv:Destroy()
			return false
		end
		return true
	end)
end

local shotSeq = 0

--- A fireball's flight: PyroFX.FireFireball with the flames swapped in. THE LOOP IS THE LIVE ONE (it carries this
--- client's hit detection): the same line (FireballPoint), the same raycast per frame, the hit reported through
--- onHit before anything cosmetic. A drawing error never stops the flight: the ball goes unseen and still lands.
function Fire.FireFireball(origin, dir, exclude, visualFrom, onHit, hot)
	libs()
	local F = T.Fireball
	if dir.Magnitude < 0.1 then return end
	local v0 = PyroFX.FireballVelocity(dir.Unit)
	local own = onHit ~= nil
	hot = hot and true or false
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { fxFolder() }
	for _, inst in ipairs(exclude or {}) do list[#list + 1] = inst end
	params.FilterDescendantsInstances = list
	local start = os.clock()
	local lastT = 0
	local offset = visualFrom and (visualFrom - origin) or nil
	local cam = workspace.CurrentCamera
	local camStart = cam and cam.CFrame.Position or origin
	local thin = (Settings.EffectDensity or 1) < 0.75 or (Settings.ThinEnemyVFX and not own)

	shotSeq = (shotSeq + 1) % 64
	local fwd = v0.Unit
	local back = unit(-fwd + UP * V.BurstUp)
	local wrap = PD.CurrentWrap and PD.CurrentWrap()   -- the thrower's wrap, for the impact made frames from now
	local share = thin and 0.5 or 1
	local st
	st = {
		cv = PD.new("PyroFireball", { own = own, hot = hot }),
		own = own, hot = hot, thin = thin, seed = shotSeq, off = false,
		offset = offset, cam = cam, camStart = camStart, travel = ZERO,
		-- where the ball is SEEN at flight time tq: the line, eased onto from the fist (the live Merge)
		ballAt = function(tq)
			if tq < 0 then tq = 0 end
			local p = PyroFX.FireballPoint(origin, v0, tq)
			if offset then
				local w = 1 - easeOutQuad(tq / F.Merge)
				if w > 0 then p += (offset + st.travel) * w end
			end
			return p
		end,
		ballO = { hot = hot, scale = 1, span = V.TailSpan, tail = own and V.OwnTail or 1, t_min = own and V.OwnFrom or 0, seed = shotSeq },
		wispFrom = own and V.OwnFrom or 0.02, wispTo = math.huge,
		wispO = { hot = hot, seed = 12 + shotSeq, rate = V.WispRate * share, scale = own and V.OwnWisp or 1,
			life = V.WispLife * (own and V.OwnWispLife or 1) },
		emberO = { id = "trail", hot = hot, count = V.Embers * share, t0 = own and V.OwnFrom or 0.01 },
	}
	local cv = st.cv

	addEffect(function(now)
		local t = math.min((now - start) * VFXLibrary.ShotTimeScale(), F.Life)
		local a = PyroFX.FireballPoint(origin, v0, lastT)
		local b = PyroFX.FireballPoint(origin, v0, t)
		local hit = t > lastT and workspace:Raycast(a, b - a, params)
		lastT = t
		if hit or t >= F.Life then
			if hit then
				-- the hit report first: nothing cosmetic may stand between a hit and the server hearing of it
				if onHit then task.spawn(onHit, hit) end
				local ok, err = pcall(Fire.Burst, hit.Position + hit.Normal * 0.3, hot, back, own, wrap)
				if not ok then warnOnce("burst", "the burst failed: " .. tostring(err)) end
			end
			afterglow(st, t)
			return false
		end
		if not st.off and guarded(cv, t, drawFlight, st) == nil then
			st.off = true
			cv:Clear()
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: IMMOLATE
----------------------------------------------------------------------------------------------------
local MOTE_EMBERS = { id = "mote", count = 5, life = { 0.2, 0.45 }, out = { 0.5, 2.5 }, up = { 0.5, 3.0 }, spread = 0.12, g = 14, kd = 4.5,
	size = { 0.03, 0.07 }, hot = false }
local ARMS = {
	{ Upper = "RightUpperArm", Lower = "RightLowerArm", Hand = "RightHand" },
	{ Upper = "LeftUpperArm", Lower = "LeftLowerArm", Hand = "LeftHand" },
}
local ARM_TOP = Vector3.new(0, 0.4, 0)          -- a limb's upper joint in its own frame (fie_lib_r2.ArmTrack)
local HAND_END = Vector3.new(0, -0.15, 0)

--- a spent mote: it flares (x 1.8 in 0.06 s) and snuffs to nothing by 0.2 s
local function spendEnv(tau)
	if tau < 0 then return 1 end
	if tau < 0.06 then return 1 + 0.8 * equint(tau / 0.06) end
	return 1.8 * (1 - sst(0.06, 0.2, tau))
end

--- Immolate on `character` (PyroFX.Immolate's beats and its Stacks_Primary rule): the chest IGNITES at the Trigger
--- (the kit's burst, HOT, riding the chest) and the fire washes out over both arms; the three motes are born inside
--- it and spiral out to the orbit by OrbitAt, each the Fireball in miniature with a tail along the arc it flew, a
--- crown lick, tongues pinching off, sparks and a light. A buffed hit spent: the next mote flares, snuffs and leaves
--- a puff of sparks and four wisps. Lives until all three are spent or the body goes. -> its controller.
function Fire.Immolate(character, serverT0)
	libs()
	local I = T.Immolate
	local registry = moteControllers
	local old = registry[character]
	if old then old.Stopped = true end
	local ctl = { Stopped = false, Seen = false }
	registry[character] = ctl
	local start = localClock(serverT0) + I.Trigger
	local own = isLocal(character)
	local cv = PD.new("PyroImmolate", { own = own, hot = true })
	local seed = 30
	local orbitIn = I.OrbitAt - I.Trigger
	local wispRate = V.MoteWispRate * clamp(cv.Density, 0.3, 1)
	local wispLife, wispScale = V.MoteWispLife, V.MoteWispScale * V.MoteSize
	local castEnd = 1.85 * V.CastLife + 0.05
	local washEnd = V.Wash.reach + V.Wash.hold + V.Wash.out + 0.12
	local rootPos, chestVec, lift = ZERO, ZERO, V.MoteLift

	-- the live orbit (PyroFX.Immolate), u seconds after the ignition, + the lift to shoulder height and a small bob
	local function moteAt(i, uq)
		if uq < 0 then uq = 0 end
		local grow = easeOutQuad(uq / orbitIn)
		local r = 0.25 + (I.OrbitRadius - 0.25) * grow
		local a = rad(-90 + 120 * (i - 1) + I.OrbitSpeed * uq)
		local c = rootPos + chestVec * (1 - grow)
		return Vector3.new(c.X + cos(a) * r, c.Y + lift * grow + V.MoteBob * grow * sin(10.5 * (start + uq) + 2 * i), c.Z + sin(a) * r)
	end

	local slots = {}
	for i = 1, 3 do
		local wisps = {}
		for w = 1, 4 do wisps[w] = { k = -1, p = ZERO, v = ZERO } end
		slots[i] = {
			At = function(uq) return moteAt(i, uq) end,
			SpentAt = nil, SpentU = nil, PopPos = ZERO, Wisps = wisps,
			SpendO = { id = "spend" .. i, count = V.SpendSparks, speed = { 3, 13 }, bias = UP, g = 30, kd = 4, life = { 0.22, 0.55 },
				size = { 0.04, 0.1 }, hot = false },
		}
	end
	local arms = {}
	for si = 1, 2 do
		local tr = newTrack(16)
		arms[si] = { Track = tr, At = function(tq) return trackAt(tr, tq) end, Prev = {}, PrevU = nil }
	end

	local castO = { size = V.CastSize, hot = true, seed = 640 + seed, back = UP, flash = not reduceFlashing() }
	local sparkO = { id = "cast", count = V.CastSparks, speed = { 3, 12 }, bias = UP, g = 26, kd = 4.5, life = { 0.2, 0.45 }, size = { 0.04, 0.1 },
		hot = false }
	local ballO = { hot = true, scale = 1, span = 0.1, t_min = 0, rise = 10, light = false, seed = seed }
	local crownO = { hot = true, lean = ZERO, ph = 0, flat = 0.9 }
	local wispO = { hot = true, cool = 0, ph = 0, curl_to = UP }
	local lightO = { t = 0, ph = 0 }
	local washO = { hot = true, layers = "ball", lean = ZERO, width = 1, grow = 0, ph = 0 }
	local sheetO = { width = 0, hot = true, span = 0.06, t_min = 0, rise = 7, seed = 60 }

	-- the fire washing out over the arms as they open: a wave of flames from the shoulder to the fist, bigger toward
	-- the fist, lagging the swing, pinched off one after another; each fist drags a sheet of flame out of the burst
	local function washArms(u)
		local W = V.Wash
		for si = 1, 2 do
			local names, arm = ARMS[si], arms[si]
			local ua, la, hd = character:FindFirstChild(names.Upper), character:FindFirstChild(names.Lower), character:FindFirstChild(names.Hand)
			if ua and la and hd then
				local sd = seed + 11 * (si - 1)
				local a0, a1, a2 = ua.CFrame * ARM_TOP, la.CFrame * ARM_TOP, hd.CFrame * HAND_END
				trackPush(arm.Track, u, a2)
				local d1, d2 = max((a1 - a0).Magnitude, 1e-6), max((a2 - a1).Magnitude, 1e-6)
				local along = unit(a2 - a0)
				local dtU = arm.PrevU and (u - arm.PrevU) or 0
				local glow, tip = 0, a2
				for j = 0, W.n - 1 do
					local s = 0.14 + 0.86 * j / max(W.n - 1, 1)
					local x = s * (d1 + d2)
					local p = a0 + (a1 - a0) * clamp(x / d1, 0, 1) + (a2 - a1) * clamp((x - d1) / d2, 0, 1)
					local prev = arm.Prev[j + 1]
					local vel = (prev and dtU > 1e-4) and (p - prev) / dtU or ZERO
					arm.Prev[j + 1] = p
					local d = u - W.reach * s - 0.014 * rnd(sd, j, 0)
					if d > 0 then
						local h0 = W.hold + 0.05 * s
						local g = eback(d / 0.05, 1.5) * (1 - sst(h0, h0 + W.out * (0.6 + 0.4 * s), d))
						if g > 0.02 then
							local H = (1.5 + 1.1 * s) * (0.75 + 0.5 * rnd(sd, j, 1))
							washO.lean = vel * -0.02 + along * (0.22 + 0.16 * rnd(sd, j, 2))
							washO.width = (0.46 + 0.14 * rnd(sd, j, 3)) * H
							washO.grow = g
							washO.ph = rnd(500 + sd, j, 7) * TAU
							cv:standing_flame(p + UP * 0.35, H, u, washO)
							if g > glow then glow = g end
						end
					end
					tip = p
				end
				arm.PrevU = u
				local w = 0.7 * equint(u / 0.03) * (1 - sst(0.07, 0.18, u))
				if w > 0.05 then
					sheetO.width, sheetO.seed = w, 60 + sd
					cv:fire_tail(arm.At, u, sheetO)
				end
				if glow > 0.05 then
					lightO.t, lightO.ph = u, 1.3 * (si - 1)
					cv:fire_light(tip + UP * 0.8, 380 * min(glow, 1), lightO)
				end
			end
		end
	end

	local function frame(_, u, now, root)
		local fp = own and firstPerson()
		local rootCF = root.CFrame
		rootPos = rootCF.Position
		chestVec = rootCF:VectorToWorldSpace(I.Chest)
		lift = fp and V.MoteLiftFP or V.MoteLift
		-- the count arrives as an attribute; nothing is spent until it has been seen at all
		local stacks = character:GetAttribute("Stacks_Primary") or 0
		if stacks > 0 then ctl.Seen = true end
		local grow = easeOutQuad(u / orbitIn)
		local any = false

		-- the cast's fire: the burst igniting at the chest, thrown forward and up, and a pop of sparks
		if u <= castEnd then
			any = true
			local torso = (not fp) and character:FindFirstChild("UpperTorso")
			local c = torso and torso.CFrame * Vector3.new(0, 0, -V.ChestOut) or rootPos + chestVec
			local look = flat(rootCF.LookVector, Vector3.new(0, 0, -1))
			castO.size = V.CastSize * (fp and V.CastFP or 1)
			castO.back = look + UP * 0.15
			cv:burst(c, u / V.CastLife, castO)
			sparkO.bias = look * 0.3 + UP * 0.6
			cv:ember_burst(c, u, sparkO)
		end

		-- the motes
		local span = V.MoteSpan[1] + V.MoteSpan[2] * sst(0.15, 0.55, u)
		local pop = seqS(I.PopIn, u, 1) * (0.35 + 0.65 * grow)
		for i = 1, 3 do
			local slot = slots[i]
			if ctl.Seen and i > stacks and not slot.SpentAt then
				slot.SpentAt = now
				slot.SpentU = u
				slot.PopPos = moteAt(i, u + 0.06)
			end
			local s = pop
			if slot.SpentAt then s *= spendEnv(now - slot.SpentAt) end
			if s > 0.03 then
				any = true
				local k = V.MoteSize * s
				ballO.scale, ballO.span, ballO.seed = V.MoteBall * k, span, seed + i
				local c = cv:fire_ball(slot.At, u, ballO)
				local vel = (c - moteAt(i, u - 1 / 60)) * 60
				crownO.lean, crownO.ph = vel * -0.05, 2.1 * i
				cv:flame(3, c - UP * (0.1 * k), unit(UP - vel * 0.05), 0.95 * k, 0.46 * k, crownO)
				lightO.t, lightO.ph = u, (seed + i) * 1.7
				cv:fire_light(c + UP * (0.25 * k), V.MoteWatts * s, lightO)
				if not slot.SpentAt then cv:embers(slot.At, u, MOTE_EMBERS) end
			end
		end

		-- tongues pinching off each mote: left where they tore off, rising, cooling, shrinking away
		for i = 1, 3 do
			local slot = slots[i]
			local t0 = 0.2 + 0.05 * (i - 1)
			local lo, hi = max(t0, u - wispLife), min(u, slot.SpentU or math.huge)
			if hi >= lo then
				for k = ceil((lo - t0) * wispRate - 1e-9), floor((hi - t0) * wispRate + 1e-9) do
					local tb = t0 + k / wispRate
					local age = u - tb
					local w = slot.Wisps[k % 4 + 1]
					if w.k ~= k then
						w.k = k
						w.p = moteAt(i, tb)
						w.v = (w.p - moteAt(i, tb - 1 / 120)) * 120
					end
					local f = clamp(age / (wispLife * (0.7 + 0.3 * rnd(seed + i, k, 0))), 0, 1)
					local sc = wispScale * (0.75 + 0.5 * rnd(seed + i, k, 7)) * wispEnv(f, 0.22)
					if sc > 0.01 then
						any = true
						local p = w.p + w.v * (0.05 * (1 - exp(-8 * age))) + UP * (0.4 * wispScale + 2.2 * age + 2.5 * age * age)
						wispO.cool, wispO.ph = 0.16 * f, rnd(seed + i, k, 8) * TAU
						cv:flame("lick", p, unit(UP - w.v * 0.06), 1.5 * sc * (1 + 0.6 * f), 0.6 * sc, wispO)
					end
				end
			end
		end

		-- what a spent mote leaves where it flared: a puff of sparks, four wisps, a light pop. Nothing solid
		for i = 1, 3 do
			local slot = slots[i]
			local tau = slot.SpentAt and (now - slot.SpentAt)
			if tau and tau <= V.SpendLife then
				any = true
				local c0 = slot.PopPos
				cv:ember_burst(c0, tau - 0.04, slot.SpendO)
				local sd = 60 + seed + i
				for j = 0, 3 do
					local age = tau - 0.07 - 0.04 * rnd(sd, j, 0)
					local life = 0.3 + 0.14 * rnd(sd, j, 1)
					if age > 0 and age < life then
						local f = age / life
						local d = runit(j, sd, 2)
						d = Vector3.new(d.X, abs(d.Y) * 0.5, d.Z)
						local sc = V.MoteSize * 0.62 * wispEnv(f, 0.2)
						wispO.cool, wispO.ph = 0.16 * f, rnd(sd, j, 3) * TAU
						cv:flame("lick", c0 + d * (0.22 + 1.3 * age) + UP * (0.25 + 2.6 * age + 3.0 * age * age), unit(UP + d * 0.4),
							1.5 * sc * (1 + 0.6 * f), 0.6 * sc, wispO)
					end
				end
				local watts = 560 * exp(-tau / 0.07)
				if watts > 4 then
					lightO.t, lightO.ph = nil, 0
					cv:fire_light(c0, watts, lightO)
				end
			end
		end

		if not fp and u <= washEnd then washArms(u) end
		return any or not ctl.Seen
	end

	local function cleanup()
		cv:Destroy()
		if registry[character] == ctl then registry[character] = nil end
	end

	addEffect(function(now)
		local root = character:FindFirstChild("HumanoidRootPart")
		if ctl.Stopped or not (root and character.Parent) then
			cleanup()
			return false
		end
		local u = now - start
		if u < 0 then return true end
		if not guarded(cv, u, frame, now, root) then
			cleanup()
			return false
		end
		return true
	end)
	return ctl
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: EMBER REFUND
----------------------------------------------------------------------------------------------------
local RING_FIELD = { id = "ring", inner = 0.85, count = V.RingEmbers, t0 = 0.03, t1 = 0.36, life = { 0.3, 0.7 }, up = { 3, 10 },
	size = { 0.05, 0.12 }, lift = 0.5 }
local PUFF = { id = "puff", count = V.PuffSparks, speed = { 4, 15 }, bias = UP, g = 30, kd = 3.6, life = { 0.3, 0.7 }, size = { 0.06, 0.14 },
	hot = false }
local STREAK_SPARKS = { id = "streak", count = 9, life = { 0.12, 0.3 }, out = { 0.5, 3 }, up = { 0.2, 2 }, spread = 0.3, g = 10, kd = 4,
	size = { 0.05, 0.11 }, hot = false }

-- the ring's seeded shape: the kit's row_vary(n, seed, 1.3) and flare_ring's per-lick numbers, pure in (n, seed)
local ringShape = nil
local function getRingShape()
	if ringShape then return ringShape end
	local n, seed = V.RingLicks, V.RingSeed
	local v, v1 = 1.3, 1.0
	local sd = seed + 17
	local kA, kB = max(2, floor(n / 11 + 0.5)), max(3, floor(n / 4.7 + 0.5))
	local phA, phB = rnd(sd, 1, 5) * TAU, rnd(sd, 2, 5) * TAU
	local shape = { n = n, wisps = {}, a0 = 0 }
	for j = 0, n - 1 do
		local s = j / n * TAU
		local h = 1 + v * (0.25 * (0.62 * sin(kA * s + phA) + 0.38 * sin(kB * s + phB)) + 0.15 * (rnd(sd, j, 6) * 2 - 1))
		local tall = rnd(sd, j, 9) < 0.14 * v1
		local gap = (rnd(sd, j, 11) < 0.12 * v1) and not tall
		local q = rnd(sd, j, 10)
		if tall then h = max(h, 0.95) * (1 + v1 * (0.40 + 0.45 * q)) end
		if gap then h = h * (1 - v1 * (0.55 + 0.20 * q)) end
		h = clamp(h, 0.18, 2.8)
		local w = h ^ 0.5 * (1 + min(v, 1.5) * 0.26 * (rnd(sd, j, 12) * 2 - 1))
		if tall then w = w * (1 - 0.18 * v1) elseif gap then w = w * (1 + 0.2 * v1) end
		local ds = v1 * 0.30 * (rnd(sd, j, 15) * 2 - 1)
		local q2 = rnd(seed + 1, j, 1)
		shape[j + 1] = {
			h = h, w = clamp(w, 0.3, 1.9), tall = tall, dn = v1 * 0.14 * (rnd(sd, j, 8) * 2 - 1),
			a = (j + 1.5 * ds) * TAU / n,                       -- its place round the ring
			ab = (j + 0.5 + 0.6 * (q2 - 0.5)) * TAU / n,        -- the bed lick beside it
			q1 = rnd(seed + 1, j, 0), q2 = q2, q3 = rnd(seed + 1, j, 2), q4 = rnd(seed + 1, j, 3),
			ph = rnd(seed, j, 21) * TAU,
		}
	end
	shape.a0 = shape[1].a
	local nw = V.RingWisps
	local spin = rad(V.RingSpin)
	for j = 0, nw - 1 do
		local born = 0.17 + 0.2 * rnd(seed + 3, j, 0)
		shape.wisps[j + 1] = {
			born = born, life = 0.26 + 0.16 * rnd(seed + 3, j, 1), k = 0.75 + 0.5 * rnd(seed + 3, j, 2), ph = rnd(seed + 3, j, 3) * TAU,
			-- it stops turning with the ring the moment it tears off
			a = j * TAU / nw + rad(-90) + spin * born + 0.3 + 0.35 * (rnd(seed + 3, j, 4) - 0.5),
			out = 1.5 + rnd(seed + 3, j, 5), up = 0.7 + 0.5 * rnd(seed + 3, j, 6),
		}
	end
	ringShape = shape
	return shape
end

--- THE ORBIT FLARES AS A RING OF FIRE from os.clock() t0: licks rooted on the orbit thrown OUTWARD, swept back against
--- its turn, each with its own length, delay and speed through the live envelope (EmberRefund.Ring); their tips turn
--- upward, the last tongues tear off as wisps. The arc AHEAD of the caster stays low (the crosshair's lane).
local function refundRing(character, t0, own)
	local R = T.EmberRefund.Ring
	local cv = PD.new("PyroRefundRing", { own = own, hot = true })
	local shape = getRingShape()
	local n = shape.n
	local radius, length, clear = T.Immolate.OrbitRadius, V.RingLength, V.RingClear
	local spin = rad(V.RingSpin)
	local bedStep = cv.Density < 0.75 and 2 or 1
	local wispAt = {}                   -- where each torn wisp was left (the ring's centre when it tore off)
	local lightO = { t = 0, ph = 0 }
	local lickO = { hot = true, flat = 0.7, lean = ZERO, curl_to = UP, ph = 0 }
	local bedO = { hot = true, flat = 0.7, side = UP, lean = ZERO, ph = 0 }
	local hoopO = { hot = true, spin = 0, thick = 1 }
	local wispO = { hot = true, cool = 0, ph = 0, curl_to = UP }

	local function frame(_, tau, root)
		local fp = own and firstPerson()
		local rootCF = root.CFrame
		local c = rootCF.Position
		local zc = c.Y + (fp and V.MoteLiftFP or V.MoteLift)
		local fwd = flat(rootCF.LookVector, nil)
		local fx, fz = fwd and fwd.X or 0, fwd and fwd.Z or 0
		local hg = seqS(R, tau)
		local up = sst(0.05, 0.30, tau)
		local drift = 0.6 * easeOutQuad(tau / 0.3)
		local base = rad(-90) + spin * tau
		local ring = radius + drift

		if hg > 0.03 then
			cv:ground_glow(Vector3.new(c.X, c.Y - V.RootHeight, c.Z), 8, 1.2 * min(hg, 1.2), tau, 0)
			for q = 0, 2 do
				local a = base + shape.a0 + q * TAU / 3
				lightO.t, lightO.ph = tau, q * 2.1
				cv:fire_light(Vector3.new(c.X + cos(a) * (radius + 1.2), zc + 0.5, c.Z + sin(a) * (radius + 1.2)), 430 * hg, lightO)
			end
		end

		-- the licks: each runs the live envelope on its own clock
		for j = 1, n do
			local L = shape[j]
			local h = seqS(R, (tau - 0.045 * L.q1) * (1 + 0.3 * L.q2))
			local len = min(length * L.h * h * (0.85 + 0.3 * L.q4), 1.75 * length)
			if len > 0.08 then
				local a = L.a + base
				local ca, sa = cos(a), sin(a)
				-- 1 = licks up freely .. 1 - clear = held low, on the arc ahead of the caster
				local keep = 1 - clear * clamp((ca * fx + sa * fz - 0.25) / 0.45, 0, 1)
				local wd = min(0.46 * length * L.w * min(h, 1) ^ 0.6, 0.62 * len)
				local el = (0.08 + 0.26 * L.q3 + up * (0.25 + 0.45 * L.q4) * (L.tall and 1.5 or 1)) * keep
				local ce, se = cos(el), sin(el)
				local rr = ring + 0.3 * L.dn
				local turn = Vector3.new(-sa, 0, ca)                 -- the way the ring turns
				lickO.lean = turn * -0.2
				lickO.curl_to = keep > 0.6 and UP or -turn
				lickO.ph = L.ph
				cv:flame("lick", Vector3.new(c.X + ca * rr, zc + 0.12 * (L.q3 - 0.5), c.Z + sa * rr),
					unit(Vector3.new(ca * ce + sa * 0.28, se, sa * ce - ca * 0.28)), len, wd, lickO)
			end
		end

		if hg > 0.03 then
			-- the bed: low squat licks between them, so it is a ring of fire and not separate teeth; and the hoop
			local lb0 = min(hg, 1.2)
			for j = 1, n, bedStep do
				local L = shape[j]
				local a = L.ab + base
				local ca, sa = cos(a), sin(a)
				local keep = 1 - clear * clamp((ca * fx + sa * fz - 0.25) / 0.45, 0, 1)
				local lb = length * (0.34 + 0.3 * L.q1) * lb0
				local el = (0.2 + 0.3 * L.q4 + 0.3 * up) * keep
				local ce, se = cos(el), sin(el)
				local turn = Vector3.new(-sa, 0, ca)
				bedO.side, bedO.lean, bedO.ph = turn, turn * -0.2, L.ph * 1.7
				cv:flame(2, Vector3.new(c.X + ca * ring, zc, c.Z + sa * ring), unit(Vector3.new(ca * ce + sa * 0.25, se, sa * ce - ca * 0.25)),
					lb, 0.7 * lb, bedO)
			end
			hoopO.spin, hoopO.thick = base, V.RingHoop * sqrt(min(hg, 1))
			cv:hoop(Vector3.new(c.X, zc + 0.02, c.Z), ring, tau, hoopO)
		end

		-- the last tongues tear off the licks and rise, shrinking away (the ones ahead of the caster are the small ones)
		for j = 1, #shape.wisps do
			local W = shape.wisps[j]
			local age = tau - W.born
			if age > 0 and age < W.life then
				local at = wispAt[j]
				if not at then
					at = Vector3.new(c.X, zc, c.Z)
					wispAt[j] = at
				end
				local f = age / W.life
				local ca, sa = cos(W.a), sin(W.a)
				local keep = 1 - clear * clamp((ca * fx + sa * fz - 0.25) / 0.45, 0, 1)
				local sc = 0.6 * wispEnv(f, 0.2) * W.k * (0.45 + 0.55 * keep)
				if sc > 0.01 then
					local rw = radius + W.out + 1.4 * age
					wispO.cool, wispO.ph = 0.16 * f, W.ph
					cv:flame("lick", Vector3.new(at.X + ca * rw, at.Y + W.up + 3.0 * age + 4.0 * age * age, at.Z + sa * rw),
						unit(Vector3.new(sa * 0.3 + ca * 0.35, 1, sa * 0.35 - ca * 0.3)), 1.5 * sc * (1 + 0.6 * f), 0.6 * sc, wispO)
				end
			end
		end
		cv:ember_field(Vector3.new(c.X, zc, c.Z), radius + 0.8, tau, RING_FIELD)
		return true
	end

	addEffect(function(now)
		local root = character:FindFirstChild("HumanoidRootPart")
		local tau = now - t0
		if tau > V.RingLife or not (root and character.Parent) then
			cv:Destroy()
			return false
		end
		if tau < 0 then return true end
		if not guarded(cv, tau, frame, root) then
			cv:Destroy()
			return false
		end
		return true
	end)
end

--- THE STREAK from where the enemy fell (src) back to the caster's orbit, from os.clock() `born` (the kill): a puff of
--- sparks on the body, then small streaming flames that leave it one after another and are pulled in along high arcs,
--- faster and faster, to the near half of the orbit. A FIXED flight time whatever the distance (`dist` studs): from
--- farther than the design's StreakRef the flames' tails are held to the length they have there.
local function refundStreak(character, src, born, own, dist)
	local cv = PD.new("PyroRefundStreak", { own = own, hot = true })
	local seed = V.StreakSeed
	local n = V.StreakLeaders
	local t0 = born + V.StreakDelay
	local life = V.StreakBorn + V.StreakFlight[2] * 1.15 + 0.06
	local radius = T.Immolate.OrbitRadius
	local span = 0.065 * clamp(V.StreakRef / max(dist, 1), 0.2, 1)
	local c, zdst = src, src.Y
	local back, side = Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)
	local leaders = {}
	for i = 0, n - 1 do
		local p0 = src + runit(i, seed, 2) * (0.2 + 0.55 * rnd(seed, i, 4))
		if p0.Y < src.Y - 2.65 then p0 = Vector3.new(p0.X, src.Y - 2.65, p0.Z) end
		local tb = V.StreakBorn * i / max(n - 1, 1)
		local dur = V.StreakFlight[1] + (V.StreakFlight[2] - V.StreakFlight[1]) * rnd(seed, i, 1)
		local aj = (i / max(n - 1, 1) - 0.5) * 2.4 * ((i % 2 == 0) and 1 or -1)      -- they land round the near half of the orbit
		local zoff = (rnd(seed, i, 6) - 0.5) * 0.4
		local sideL, upL = (rnd(seed, i, 8) - 0.5) * 3.4, 2.0 + 2.6 * rnd(seed, i, 9)
		leaders[i + 1] = {
			tb = tb, dur = dur,
			TailO = { width = 0, hot = true, span = span, t_min = tb, rise = 0, seed = 20 + i },
			-- a quadratic Bezier to where the caster is NOW: it lifts off, then is pulled in
			At = function(tq)
				local u = clamp((tq - tb) / dur, 0, 1)
				local e = 0.35 * u + 0.65 * u * u
				local p2 = c + (back * cos(aj) + side * sin(aj)) * radius
				p2 = Vector3.new(p2.X, zdst + zoff, p2.Z)
				local p1 = p0 + (p2 - p0) * 0.45 + side * sideL + UP * upL
				local m = 1 - e
				return p0 * (m * m) + p1 * (2 * e * m) + p2 * (e * e)
			end,
		}
	end

	local function frame(_, tau, now, root)
		local fp = own and firstPerson()
		c = root.Position
		zdst = c.Y + (fp and V.MoteLiftFP or V.MoteLift)
		back = flat(src - c, back)                                   -- from the caster toward the fallen enemy
		side = Vector3.new(back.Z, 0, -back.X)
		cv:ember_burst(src, now - born, PUFF)
		for i = 1, n do
			local ld = leaders[i]
			local u = (tau - ld.tb) / ld.dur
			if u > 0 and u < 1 then
				local o = ld.TailO
				o.width = (0.46 + 0.26 * u) * (1 - 0.5 * sst(0.85, 1.0, u))
				local p = cv:fire_tail(ld.At, tau, o)
				if i % 2 == 1 then cv:fire_light(p, 260 * (0.4 + 0.6 * u)) end
				if i <= 5 then cv:embers(ld.At, tau, STREAK_SPARKS) end
			end
		end
		return true
	end

	addEffect(function(now)
		local root = character:FindFirstChild("HumanoidRootPart")
		local tau = now - t0
		if tau > life or not (root and character.Parent) or not guarded(cv, tau, frame, now, root) then
			cv:Destroy()
			return false
		end
		return true
	end)
end

local function positionOf(from)
	local ty = typeof(from)
	if ty == "Vector3" then return from end
	if ty == "Instance" then
		if from:IsA("BasePart") then return from.Position end
		local part = from:FindFirstChild("HumanoidRootPart") or (from:IsA("Model") and from.PrimaryPart)
		if part then return part.Position end
	end
	return nil
end

--- Where the enemy this kill felled is, when nobody said (the broadcast names the caster only): a body at 0 health
--- (players' characters and the Training Ground's dummies), the caster's own aside. With PyroFX's book of when each
--- watched body fell (Fire.Init's Fallen) it is the one that fell LAST, and only within FallenFresh seconds: a body
--- the watcher has not seen at 0 health yet fell this very frame. An older corpse lying nearer is not taken, and with
--- no fresh one there is no streak (the ring alone). Without the book: the nearest corpse, as before.
local function fallenNear(character, at)
	local best, bestD, bestT = nil, V.StreakMax, -math.huge
	local book, now = fallen, os.clock()
	local function try(model)
		if model == character then return end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health <= 0 then
			local d = (root.Position - at).Magnitude
			if d >= V.StreakMax then return end
			if book then
				local fell = book[model] or now
				if now - fell <= V.FallenFresh and (fell > bestT or (fell == bestT and d < bestD)) then
					best, bestD, bestT = root.Position, d, fell
				end
			elseif d < bestD then
				best, bestD = root.Position, d
			end
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then try(pl.Character) end
	end
	local ground = workspace:FindFirstChild("TrainingGround")
	if ground then
		for _, d in ipairs(ground:GetDescendants()) do
			if d:IsA("Humanoid") and d.Parent then try(d.Parent) end
		end
	end
	return best
end

--- The Passive (PyroFX.EmberRefund; real time, no attribute read, no body clip): a streak of embers from the fallen
--- enemy back to the caster, and the orbit flares as a ring of fire when its first flame lands. `from` (optional: a
--- Vector3, a part or a model) is where the enemy fell; without it the body that fell last (fallenNear); with neither
--- the ring alone, at once.
function Fire.EmberRefund(character, from)
	libs()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local own = isLocal(character)
	local born = os.clock()
	local src = positionOf(from) or fallenNear(character, root.Position)
	local dist = src and (src - root.Position).Magnitude or 0
	if src and dist >= V.StreakMin then
		refundStreak(character, src, born, own, dist)
		refundRing(character, born + V.RingDelay, own)
	else
		refundRing(character, born, own)
	end
end

----------------------------------------------------------------------------------------------------
-- WIRING
----------------------------------------------------------------------------------------------------
--- Once, from PyroFX's lazy loader (every field optional): PyroFX itself (so this module never requires it),
--- AddEffect = PyroFX's addEffect (one render step for both looks), MoteControllers = PyroFX's moteControllers
--- (a re-cast then stops the other look's motes; both looks honour controller.Stopped), Fallen = PyroFX's book of when
--- each watched body fell (the Ember Refund streak's source: fallenNear).
function Fire.Init(deps)
	if type(deps) ~= "table" then return end
	if type(deps.PyroFX) == "table" then PyroFX = deps.PyroFX end
	if type(deps.AddEffect) == "function" then sharedAdd = deps.AddEffect end
	if type(deps.MoteControllers) == "table" then moteControllers = deps.MoteControllers end
	if type(deps.Fallen) == "table" then fallen = deps.Fallen end
end

--- Whether the flame look can draw at all: PyroDraw loads and the flame meshes are in the place. The look switch
--- should fall back to "toon" while this is false.
function Fire.Ready()
	local ok, res = pcall(function()
		libs()
		local folder = PD.MeshFolder()
		return folder ~= nil and folder:FindFirstChild("PF_Ball_1") ~= nil and folder:FindFirstChild("PF_Lick_1") ~= nil
	end)
	return ok and res == true
end

return Fire
