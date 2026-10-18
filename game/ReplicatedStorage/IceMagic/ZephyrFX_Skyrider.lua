--[[
	ZephyrFX_Skyrider  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrFX_Skyrider     Zephyr v6 import, 2026-10-06

	THE BIRD OF SKYRIDER (Zephyr's Mobility Technique; it replaces Gust Jump: the owner's decision, ROBLOX_IMPORT_PLAN
	section 0). A bird of glowing wind that gathers out of the air under its caster, carries them, flaps a gust and
	breaks into wisps when they jump off. This module only DRAWS: IceMagic.ZephyrSkyrider owns the ride (the client
	flight motor, the press, the handlers) and ServerScriptService.ZephyrSkyriderServer the gameplay. It is a straight
	port of the v6 Blender rig onto IceMagic.ZephyrDraw (the RadiantDraw fork, plan section 3):

	  blender_scripts/zephyr/aqua/skyrider_v6.py   THE RIG, line for line: DOF (13 per wing), KK / ZZ (the springs),
	                                               REST / WINDUP / STROKE, targets() (the stroke with its phase lags
	                                               0.35 / 0.70 / 1.05 rad, the bank, the hit kick and stutter, the low-mana
	                                               ragged amplitude and tremor), the WingSim run LIVE per bird at 240 Hz
	                                               (semi-implicit Euler, 4 substeps a 60 fps frame), rig() (shoulder ->
	                                               elbow -> wrist -> tip, 2.9 / 3.1 / 2.9), wing_geo() (the Catmull-Rom spar
	                                               bending at every joint, per-sample frames blended across the joints, the
	                                               continuous membrane from inside the body to the tip, the chord profile),
	                                               feathers() (coverts on the upper arm and forearm, secondaries + tertials,
	                                               primaries fanning 20-82 degrees from the hand with slot and bend),
	                                               layers() (summon: skeleton, body, membrane, coverts, secondaries,
	                                               primaries; dismount: the reverse, tips first), flicker(), the wisps
	                                               (5 at low mana, 18 at the dismount), the summon's 8 gather ribbons and the
	                                               wing light (280 W + 900 W x the gust wind-up, + 1500 W x the hit wobble).
	  blender_scripts/zephyr/aqua/skyrider_v5.py   the body Sheet round the spine, the white-hot spine, the 7-feather fan
	                                               tail, beak, eyes, the 3 crest plumes, the wingtip vortices, the
	                                               particles, and the GUST: the wind-up compression spiral, the pressure
	                                               crests peeling off each wing, the cone's expanding pointed wavefronts,
	                                               streamlines, vortex threads, the soft vapor edge, the trench lines on the
	                                               floor, the hit rings and the pressure bloom on whoever it reached.
	  blender_scripts/zephyr/spring/skyrider_bl.py the body profile (SPK), spine(), body_dz() (the flap ripple down the
	                                               back), head_rot() / head_feat() (beak, gape, eyes, crest root), the bank
	                                               from the turn rate (Track: -1.15 atan(v w / G) + 0.5 hitw), hitw(),
	                                               flick(), the gust cone's front curve (27 studs, tau 0.24), explode() (the
	                                               summon: shapes scattered along the swoop) and scat() (the dismount: the
	                                               shapes keep the bird's momentum, fly outward, loosen and fade).

	WHO CALLS IT. ZephyrSkyrider (client only), from the broadcasts every client gets through AbilityFX and from the
	rider's own motor:
	  FX.Start(character, opts)      a bird under `character` from opts.T0 (server time of the press). opts: Own (your
	                                 own ride: the own-view rules below), SummonTime, WindUp (ZephyrSkyrider.Tuning's)
	  FX.Gust(character, T0, dir)    the flap: the wind-up from T0 (server time), the stroke WindUp later, the cone along
	                                 `dir` (a world unit vector, the rider's aim at the press)
	  FX.GustHit(character, victim, at, T0)   one body the cone reached (the ring and the bloom on it)
	  FX.Hit(character, at, T0)      the rider was hurt: the wobble (the struck wing is the side `at` is on)
	  FX.End(character, T0, reason)  the dismount: the bird breaks from the tips inward, 18 wisps, the scatter
	  FX.Stop(character)             gone at once (a respawn); FX.Get(character) -> the bird or nil
	  FX.Demo(character, opts)       the test harness: THE SHOWCASE 1:1 (see DEMO below): the character rides the bird
	                                 along skyrider_bl's own flight (the hop onto the swooping bird, the kneel, the banked
	                                 S, the climb, the gust at 3.10 / 3.30 at the dummies, the peel-off, the hit wobble at
	                                 4.70, low mana from 5.20, the dismount at 6.20 and the fall), its CastPose clips on
	                                 the same clock, the reel's speed ramp and hero camera; opts.Freeze = clip seconds
	                                 holds one frame. -> { Stop, Bird }
	Every call is guarded by the caller and by itself (pcall round every canvas call): drawing never breaks a mechanic,
	and without ZephyrDraw nothing is drawn at all (one warning; looked for again on the next Start).

	THE STAGE. Blender's bird-local frame is +X the bird's right, +Y forward, +Z up; the rider kneels at BACK_L
	(0, -0.2, 1.5). The bird is drawn about that seat: world = seat + R * (BS * KS * (P - BACK)), where KS = 0.6 (the
	v5 bird scale about the seat, span about 19 studs) and BS = 1.3 (bird units -> studs), and a bird-local (x, y, z)
	becomes Roblox (x, z, -y) in the bird's frame (= ZD.FromStage). The SEAT is Tuning.SeatBelowRoot under the rider's
	HumanoidRootPart. The frame's heading follows the root's velocity along the ground (its look when slow), the
	turn rate omega is the heading's smoothed rate, the pitch is 0.85 atan2(climb, speed) + the Blender beats' nods, the
	bank is Track's -1.15 atan(v omega / G) + 0.5 hitw (G = zk's 9.81 m/s^2 in studs, 28.6). Everybody computes all of it
	from the replicated root, so every client draws the same bird; the wing PHASE is each client's own (integrated
	locally), which nobody can compare.

	LIVE DRIVERS (the Blender timeline is fixed; the game's is not). SummonTime (0.44) maps the summon window -0.24..0.40
	onto 0..0.44 (form, layers, explode, gather); the flap weight ramps in 0.18..0.51 s after it (the catch, as Blender's
	0.62..0.95 after its 0.44); the flap period is 0.95 s at the cruise speed, x (speed / 42)^0.35, slowing 15 % at
	empty mana; the bird glides (flap x 0.4) diving steeper than ~9 degrees. A gust is the press: WINDUP blends in over
	WindUp (0.2 s) and STROKE over the next 0.03 s to 0.32 s, the flap fades out over 0.12 s from the press and back over
	0.55..0.90 s after the stroke. Low mana (thin) is the last LowMana (30) points of the caster's Mana attribute.
	The light's gust term decays after the stroke (Blender's v6 held it at full for the rest of the clip; a slip).

	OWN VIEW (the rider, first person). The bird is drawn at OwnScale, OwnDrop lower and with OwnBankShare of the bank,
	so the wings frame the view and never sweep across the crosshair; the summon and wisp ribbons fade inside
	OwnNear of the camera. The gust kicks the view (ZD.CameraKick: the v5 FP kick, FOV +13 % and a small roll) and a
	hit jolts it.

	THE KINDS (ZephyrDraw's): the membrane and the body are "surf" Sheets (za5 mat_surf, with the v6 e0 / e1 / a0:
	the wing 0.6 / 1.5 / 0.62, the body 0.5 / 1.6 / 0.55 -- the trailing edge, the tip and the belly feathered by the
	kind itself), the feathers and the tail fan "feather" (mat_feather5: root bright, tip deeper, the fray as the tail
	fade), the spar a CoreGlow pair, the spine and eyes "core", beak / crest / gather / wisps / streamlines "glow",
	vortices / wavefronts / threads "arc", the vapor edge and hit rings "vapor", the trenches "scuff", the bloom
	cv:Arcs (za.Arcs, seed 71). Blender's alpha values are passed as they are (o.alpha is za's zk_alpha).

	BUDGET (plan: <= 420 Beams, 1 light, the bird plus the gust; Play opts.Budget = "Skyrider"). Spans are thinned per
	element (Look.Spans); feathers are Blender's 16 / 16 / 10 per wing cut to 14 / 14 / 10 (the full rows are computed
	and evenly sampled; Look.Feathers sets it -- the full rows put the gust's peak at 425). Counted with a mock canvas
	over the showcase (one Beam a span, two for CoreGlow and the scuff's line): cruise ~294, the gust's peak ~409 (3.75),
	the dismount's wisps ~72; the per-frame cost ~0.3-0.9 ms in Studio (FX._DryRun / FX._Draw).

	NOT LIKE BLENDER. Beams, not subdivided alpha meshes: the membrane is a 12 x 4 Sheet per wing (Blender 41 x 7), the
	body 12 x 8 (36 x 14); the trailing edge, belly and tip alpha is the "surf" kind's own. Particles are
	ParticleEmitter bursts at Blender's counts (not deterministic); the Blender flow field that carries them is not run.
	The v5 rider fill light is not drawn (one light), and the wing light sits under the DRAWN chest (Blender hung it
	under skyrider_bl's unscaled chest, ahead of the shrunk bird's beak); the gust cone's apex is that drawn chest too,
	and the server's hit cone starts there (ZephyrSkyrider.Tuning.Gust.ApexAhead / ApexUp), so the front you see is
	the front that hits. Vortex trails are the tip's real recent path (a ring buffer), not the rig re-evaluated in the
	past. In the demo the rider kneels on the fixed seat (BACK_L; skyrider_bl rocked it with the spine) and leans with
	the bird's whole roll (kneel_pose's extra lean into the turn is not keyed), and the dummies are not shoved (they are
	the server's): the cone's rings and the bloom land on them.

	EVERY NUMBER IS PROVISIONAL (v6 import). Nothing here has been seen in Play.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FX = {}

local sin, cos, tan, asin, atan, atan2 = math.sin, math.cos, math.tan, math.asin, math.atan, math.atan2
local abs, max, min, floor, sqrt, exp, log, pi = math.abs, math.max, math.min, math.floor, math.sqrt, math.exp,
	math.log, math.pi
local TAU = 2 * pi
local V3 = Vector3.new
local UP = Vector3.yAxis
local VZERO = Vector3.zero

----------------------------------------------------------------------------------------------------
-- TUNING
----------------------------------------------------------------------------------------------------
FX.Tuning = {
	-- THE RIG: skyrider_v6.py, verbatim. DOF per wing, in order:
	--   e_s sw_s tw_s (shoulder elevation / sweep / twist), f_e e_e (elbow flex / elevation),
	--   f_w e_w tw_w (wrist flex / elevation / twist), fan slot (primaries), b_cov b_sec b_pri (feather bend per tier)
	Rig = {
		LA = 2.9, LF = 3.1, LH = 2.9,                       -- upper arm, forearm, hand (bird-local units)
		K = { 560, 560, 480, 460, 460, 380, 380, 320, 260, 300, 160, 110, 80 },
		Z = { 0.75, 0.8, 0.7, 0.7, 0.7, 0.6, 0.6, 0.55, 0.6, 0.6, 0.45, 0.35, 0.3 },
		Rest = { 0.14, -0.10, 0.0, 0.12, -0.05, 0.10, 0.06, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0 },
		Windup = { 1.15, -0.45, 0.20, 1.35, 0.30, 1.50, 0.40, 0.20, 0.60, 0.3, 0.0, 0.0, 0.0 },
		Stroke = { -0.85, 0.35, -0.35, 0.0, -0.10, 0.0, -0.15, -0.55, 1.35, 0.0, 0.35, 0.7, 1.0 },
		Kick = { 3, 2, 2, 3, 3, 4, 4, 4, 3, 3, 6, 7, 8 },  -- the hit's velocity kick, per DOF (x a unit normal)
		Shoulder = V3(0.85, 2.7, 0.95),                    -- x mirrored per side
		Back = V3(0, -0.2, 1.5),                           -- BACK_L: the rider's kneel, the bird's scale origin
		KS = 0.6,                                          -- the v5 bird scale about the seat (span ~19 studs)
		BS = 1.3,                                          -- bird units -> studs (skyrider_bl BS)
		Hz = 240,                                          -- the spring sim's rate (Blender WingSim's dt 1/240)
		MaxSubsteps = 64,                                  -- per frame, live (a long hitch skips ahead instead)
		Amp = 0.8,                                         -- MainDriver.A at full mana
	},

	-- the live drivers (see LIVE DRIVERS in the header) -- PROVISIONAL (v6 import)
	Drive = {
		SummonTime = 0.44,          -- = ZephyrSkyrider.Tuning.SummonTime (Start passes the live one)
		WindUp = 0.2,               -- = ZephyrSkyrider.Tuning.Gust.WindUp (Start passes the live one)
		CruisePeriod = 0.95,        -- s, the flap at CruiseSpeed
		CruiseSpeed = 42,           -- studs/s (= ZephyrSkyrider.Tuning.FlySpeed)
		SpeedExp = 0.35,            -- period / (speed / CruiseSpeed)^SpeedExp
		LowManaSlow = 0.15,         -- the flap slows this share at empty mana (Blender freq 1.12 -> 0.95)
		LowMana = 30,               -- thin = the last LowMana points of the Mana attribute
		ThinTau = 0.25,             -- s, how fast thin follows the bar
		DiveGlide = 0.6,            -- the flap drops this share diving ...
		DiveFrom = 0.15, DiveFull = 0.5,   -- ... from this pitch (rad, down) to this
		HeadingFollow = 12,         -- 1/s the drawn heading follows the flight's
		OmegaTau = 0.12,            -- s, the turn rate's smoothing
		BankG = 28.6,               -- zk G (9.81 m/s^2 in studs): Track's bank = -1.15 atan(v w / G)
		BankK = 1.15, BankMax = 1.2,
		PitchShare = 0.85,          -- Track: th = 0.85 atan2(vz, v)
		FlickSlot = 0.21,           -- s: live low-mana flicks, one chance per slot ...
		FlickChance = 0.9,          -- ... x thin
	},

	-- the look -- PROVISIONAL (v6 import)
	Look = {
		SeatBelowRoot = 2.4,        -- = ZephyrSkyrider.Tuning.SeatBelowRoot (Start passes the live one)
		Scale = 1.0,                -- the whole bird
		OwnScale = 0.9,             -- your own bird (first person) ...
		OwnDrop = 0.4,              -- ... this much lower (studs) ...
		OwnBankShare = 0.35,        -- ... and banking this share (Blender's FP camera kept 0.2 of the roll)
		OwnNear = { 0.8, 2.2 },     -- studs: own-view ribbons fade out inside this of the camera
		Feathers = { cov = 14, sec = 14, pri = 10 }, -- per wing: Blender's 16 / 16 / 10, cut only as far as the 420
		                                             -- cap needs (the full rows peak at 425; the plan's fallback 8 / 8 / 6)
		MemRows = 12, MemCols = 4,  -- the membrane Sheet per wing (Blender 41 x 7)
		BodyRings = 12, BodyAround = 8,             -- the body Sheet (Blender 36 x 14)
		SwoopBack = 6, SwoopDown = 2.5,             -- the summon: the bird slides in from behind and below
		EndCarry = 0.3,             -- after the dismount the frame coasts on with this share of the bird's velocity
		Spans = {                   -- o.maxSpans per element (Beams)
			Feather = 2, Spar = 5, Spine = 5, Sheet = 5, Tail = 2, Beak = 2, Crest = 3, Vortex = 4, Gather = 4,
			Wisp = 4, Comp = 4, Crest_P = 4, Front = 3, Stream = 1, Thread = 6, Edge = 2, Trench = 1, Bloom = 3,
		},
		Light = { Watts = 280, Gust = 900, Hit = 1500, Range = 12, Flicker = 0.15, Below = 1.0 },
		Cam = { GustFov = 0.13, GustRoll = 0.03, GustDecay = 0.12, HitRoll = 0.04, HitShake = 0.05, HitDecay = 0.2 },
		Gust = {
			Half = 21,              -- degrees: the drawn cone (skyrider_bl HALF; the server's hit cone is 28)
			Reach = 27, Tau = 0.24, -- cone_front: RF (1 - exp(-tau / TAU_F)) (= ZephyrSkyrider.Tuning.Gust)
			Launch = 0.04,          -- the cone leaves the wings this long after the stroke (T_LAUNCH - T_STROKE)
			Apex = V3(0, 6.0, 0.9), -- chest_w: the cone's apex, bird-local, scaled WITH the bird (skyrider_bl took it
			                        -- unscaled, 1.7 studs ahead of the shrunk v5 bird's beak); the server's hit cone
			                        -- starts at the same point (ZephyrSkyrider.Tuning.Gust.ApexAhead / ApexUp)
			Fronts = 5, Arcs = 3,   -- the wavefronts: 5 fronts x 3 pointed arcs
			Streams = 8, Threads = 2, Edges = 6, Trenches = 5,
			FloorReach = 60,        -- studs of down-ray for the floor under the apex
			Life = 3.2,             -- s after the launch a gust is drawn at all
		},
		Wisps = { LowEvery = 0.17, LowFrom = 0.25, LowMax = 6, Life = 0.6, EndLife = 0.95 },
	},
}
local T = FX.Tuning
local RIG, DRV, LOOK = T.Rig, T.Drive, T.Look

local REST, WINDUP, STROKE, KK, KICK = RIG.Rest, RIG.Windup, RIG.Stroke, RIG.K, RIG.Kick
local NQ = 13
local CC = {}                                  -- c = 2 Z sqrt(K): the critical damping share
for i = 1, NQ do CC[i] = 2 * RIG.Z[i] * sqrt(RIG.K[i]) end
local BACK = RIG.Back
local LA, LF, LH = RIG.LA, RIG.LF, RIG.LH

----------------------------------------------------------------------------------------------------
-- MATHS (zk / za5 / pyro_kit, identical curves)
----------------------------------------------------------------------------------------------------
local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end
local function clamp01(x) return clamp(x, 0, 1) end
local function lerp(a, b, u) return a + (b - a) * u end
--- zk.smooth(x, a, b): smoothstep of (x - a) / (b - a)
local function smooth(x, a, b)
	local u = clamp01((x - a) / (b - a))
	return u * u * (3 - 2 * u)
end
local function ease(u) u = clamp01(u) return u * u * (3 - 2 * u) end
local function easeOut(u) u = clamp01(u) return 1 - (1 - u) ^ 3 end
local function span(t, a, b)
	if b > a then return clamp01((t - a) / (b - a)) end
	return (t >= b) and 1 or 0
end
--- skyrider_bl.bump: sin^2 over (a, b)
local function bump(t, a, b)
	if t <= a or t >= b then return 0 end
	local s = sin(pi * (t - a) / (b - a))
	return s * s
end
--- skyrider_bl.hn: the deterministic hash in [0, 1)
local function hn(a, b, c, d)
	local s = sin(a * 12.9898 + (b or 0) * 78.233 + (c or 0) * 37.719 + (d or 0) * 4.581 + 0.5) * 43758.5453
	return s - floor(s)
end
--- a unit normal sample from the hash (Box-Muller): WingSim's rs.normal
local function gauss(a, b, c)
	local u1 = max(1e-9, hn(a, b, c, 1))
	local u2 = hn(a, b, c, 2)
	return sqrt(-2 * log(u1)) * cos(TAU * u2)
end
local function nrm(v)
	local m = v.Magnitude
	if m > 1e-9 then return v / m end
	return v
end
local function wrapAngle(a)
	return (a + pi) % TAU - pi
end
--- piecewise-linear np.interp on sorted xs
local function interp(x, xs, ys)
	if x <= xs[1] then return ys[1] end
	for i = 2, #xs do
		if x <= xs[i] then
			return ys[i - 1] + (ys[i] - ys[i - 1]) * (x - xs[i - 1]) / (xs[i] - xs[i - 1])
		end
	end
	return ys[#ys]
end
--- name -> a stable number in [0, 50) (skyrider_v5.key_of's role: each part scatters its own way)
local function keyOf(name)
	local h = 7
	for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 997 end
	return h / 997 * 50
end

--- za5.spline: uniform Catmull-Rom through P resampled to n points, then a light Gaussian smoothing (ends kept)
local KERNELS = {}
local function kernel(sigma)
	local k = KERNELS[sigma]
	if k then return k end
	local r = floor(3 * sigma)
	local g, sum = {}, 0
	for j = -r, r do
		local w = exp(-0.5 * (j / sigma) ^ 2)
		g[j + r + 1] = w
		sum += w
	end
	for i = 1, #g do g[i] /= sum end
	k = { R = r, G = g }
	KERNELS[sigma] = k
	return k
end
local splineRaw = {}
local function spline(P, n, sigma, out)
	out = out or table.create(n)
	local k = #P
	local q0, qn = 2 * P[1] - P[2], 2 * P[k] - P[k - 1]
	local function Q(i)
		if i <= 0 then return q0 end
		if i > k then return qn end
		return P[i]
	end
	local raw = (sigma > 0) and splineRaw or out
	for m = 0, n - 1 do
		local s = (k - 1) * m / (n - 1)
		local i = clamp(floor(s), 0, k - 2)
		local u = s - i
		local p0, p1, p2, p3 = Q(i), Q(i + 1), Q(i + 2), Q(i + 3)
		raw[m + 1] = 0.5 * ((2 * p1) + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * (u * u)
			+ (3 * p1 - p0 - 3 * p2 + p3) * (u * u * u))
	end
	if sigma > 0 then
		local K = kernel(sigma)
		local r, g = K.R, K.G
		for i = 1, n do
			local acc = VZERO
			for j = -r, r do acc += raw[clamp(i + j, 1, n)] * g[j + r + 1] end
			out[i] = acc
		end
		out[1], out[n] = raw[1], raw[n]
	end
	for i = n + 1, #out do out[i] = nil end
	return out
end
--- np.gradient direction (central inside, one-sided at the ends), normalised
local function tangent(P, i)
	local n = #P
	if i == 1 then return nrm(P[2] - P[1]) end
	if i == n then return nrm(P[n] - P[n - 1]) end
	return nrm(P[i + 1] - P[i - 1])
end
--- zk.arc_pts: a (spiral) arc about `axis` through centre, radius r0 -> r1, angle a0 -> a1, climbing `rise`
local function arcPts(c, axis, startDir, r0, a0, a1, n, rise, r1, out)
	out = out or table.create(n)
	local ax = nrm(axis)
	local d0 = startDir - ax * startDir:Dot(ax)
	if d0.Magnitude < 1e-6 then d0 = ax:Cross(math.abs(ax.Y) < 0.9 and UP or Vector3.xAxis) end
	d0 = nrm(d0)
	local d1 = ax:Cross(d0)
	r1 = r1 or r0
	rise = rise or 0
	for k = 0, n - 1 do
		local s = (n > 1) and k / (n - 1) or 0
		local a = a0 + (a1 - a0) * s
		out[k + 1] = c + (d0 * cos(a) + d1 * sin(a)) * (r0 + (r1 - r0) * s) + ax * (rise * s)
	end
	return out
end
--- `n` points evenly from a to b
local function linspace(a, b, n, out)
	out = out or table.create(n)
	for i = 1, n do out[i] = a + (b - a) * ((n > 1) and (i - 1) / (n - 1) or 0) end
	return out
end
--- `n` indices spread evenly over 1..N (a feather row cut to the budget keeps its whole span)
local function pickIdx(N, n)
	local out = {}
	n = clamp(n, 1, N)
	for m = 1, n do out[m] = (n == 1) and math.ceil(N / 2) or (1 + floor((m - 1) * (N - 1) / (n - 1) + 0.5)) end
	return out
end

-- Blender's rotations about the bird-local axes as CFrames (a rotation-only CFrame IS the 3x3 matrix: Roblox's
-- CFrame.Angles about one axis is the same right-handed matrix as skyrider_bl's Rx / Ry / Rz)
local function Rx(a) return CFrame.Angles(a, 0, 0) end
local function Ry(a) return CFrame.Angles(0, a, 0) end
local function Rz(a) return CFrame.Angles(0, 0, a) end
local XAX, YAX, ZAX = V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1)

----------------------------------------------------------------------------------------------------
-- THE BODY PROFILE (skyrider_bl SPK, _cr, _resample: precomputed once; pure maths, no instances)
----------------------------------------------------------------------------------------------------
-- (y, z, width) beak tip -> head -> neck -> chest -> back -> hips -> tail base, held in a Vector3 as a 3-vector
local SPK = {
	V3(7.15, 2.15, 0.05), V3(6.55, 2.40, 1.05), V3(5.95, 2.50, 2.00), V3(5.35, 2.28, 1.85), V3(4.65, 1.75, 1.45),
	V3(3.85, 1.05, 2.45), V3(2.75, 0.45, 3.95), V3(1.00, 0.30, 4.0), V3(-0.80, 0.25, 3.5), V3(-2.40, 0.30, 2.6),
	V3(-3.70, 0.40, 1.55),
}
local NS = 30
local SY, SZ, SW, SS = {}, {}, {}, {}
local IB, IH = 1, 1
local HEAD_C = V3(0, 5.95, 2.5)
local PIVOT = V3(0, 4.05, 1.0)
do
	local n = #SPK
	local Pp = { 2 * SPK[1] - SPK[2] }
	for i = 1, n do Pp[#Pp + 1] = SPK[i] end
	Pp[#Pp + 1] = 2 * SPK[n] - SPK[n - 1]
	local C = {}
	for j = 2, n do                                    -- _cr(P, n_per=10)
		local p0, p1, p2, p3 = Pp[j - 1], Pp[j], Pp[j + 1], Pp[j + 2]
		for k = 0, 9 do
			local u = k / 10
			C[#C + 1] = 0.5 * (2 * p1 + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * (u * u)
				+ (3 * p1 - p0 - 3 * p2 + p3) * (u * u * u))
		end
	end
	C[#C + 1] = SPK[n]
	local d = { 0 }                                    -- _resample(P, NS): by arc length in (y, z)
	for i = 2, #C do
		local a, b = C[i - 1], C[i]
		d[i] = d[i - 1] + sqrt((b.X - a.X) ^ 2 + (b.Y - a.Y) ^ 2)
	end
	local L = d[#d]
	local j = 1
	for i = 1, NS do
		local s = L * (i - 1) / (NS - 1)
		while j < #C - 1 and d[j + 1] < s do j += 1 end
		local u = (d[j + 1] > d[j]) and clamp01((s - d[j]) / (d[j + 1] - d[j])) or 0
		local p = C[j]:Lerp(C[j + 1], u)
		SY[i], SZ[i], SW[i], SS[i] = p.X, p.Y, p.Z, (i - 1) / (NS - 1)
	end
	local bb, bh = math.huge, math.huge
	for i = 1, NS do
		if abs(SY[i] - BACK.Y) < bb then bb, IB = abs(SY[i] - BACK.Y), i end
		if abs(SY[i] - 5.95) < bh then bh, IH = abs(SY[i] - 5.95), i end
	end
end

-- feathers() rows (skyrider_v6), full; the drawn ones are an even pick of these (Look.Feathers)
local COV_B, SEC_B, SEC_L = {}, {}, {}
do
	local a = linspace(0.04, 0.31, 7)
	local b = linspace(0.36, 0.64, 9)
	for _, v in ipairs(a) do COV_B[#COV_B + 1] = v end
	for _, v in ipairs(b) do COV_B[#COV_B + 1] = v end
	a = linspace(0.05, 0.30, 4)
	b = linspace(0.34, 0.66, 12)
	for _, v in ipairs(a) do SEC_B[#SEC_B + 1] = v; SEC_L[#SEC_L + 1] = 2.0 end
	local lb = linspace(2.5, 2.2, 12)
	for i, v in ipairs(b) do SEC_B[#SEC_B + 1] = v; SEC_L[#SEC_L + 1] = lb[i] end
end
local PRI_H = linspace(0.05, 1.0, 10)
local PRI_U = linspace(0, 1, 10)
local PRI_L = { 3.0, 3.2, 3.4, 3.6, 3.8, 4.0, 4.2, 4.2, 4.0, 3.7 }
local WB = linspace(0, 1, 40)                          -- the spar's samples (wing_geo b)
local CH_X, CH_Y = { 0, 0.33, 0.66, 1.0 }, { 2.6, 2.4, 1.6, 0.45 }
-- Blades' width profile (za5): sin(pi clip(s 0.92 + 0.08))^0.55 (1 - 0.45 s), at the feather's 3 knots s = 0, 0.5, 1
local FEATHER_S = { 0, 0.5, 1 }
local FEATHER_W = {}
for i, s in ipairs(FEATHER_S) do
	FEATHER_W[i] = max(0.04, sin(pi * clamp01(s * 0.92 + 0.08)) ^ 0.55 * (1 - 0.45 * s))
end

----------------------------------------------------------------------------------------------------
-- modules, found lazily (client only; never at require)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrFX_Skyrider] " .. tostring(msg))
end

local zdMod, zdLooked = nil, -math.huge
local function getZD()
	if zdMod then return zdMod end
	if os.clock() - zdLooked < 2 then return nil end
	zdLooked = os.clock()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild("ZephyrDraw")
	if not m then
		warnOnce("nozd", "IceMagic.ZephyrDraw is not there: Skyrider's bird draws nothing (the ride is unaffected)")
		return nil
	end
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" then
		zdMod = mod
		return mod
	end
	warnOnce("zderr", "ZephyrDraw failed to load: " .. tostring(mod))
	return nil
end

--- ZD.<fn>(...) guarded
local function zdCall(fn, ...)
	local ZD = getZD()
	local f = ZD and ZD[fn]
	if type(f) ~= "function" then return nil end
	local ok, res = pcall(f, ...)
	if not ok then warnOnce("zd:" .. fn, "ZephyrDraw." .. fn .. " failed: " .. tostring(res)) return nil end
	return res
end

----------------------------------------------------------------------------------------------------
-- canvas calls (plan section 3), each guarded: one bad call is one warning, never a lost bird
----------------------------------------------------------------------------------------------------
local function cvCall(cv, name, ...)
	local f = cv[name]
	if type(f) ~= "function" then
		warnOnce("cv:" .. name, "ZephyrDraw canvas has no " .. name .. " (that layer is not drawn)")
		return nil
	end
	local ok, res = pcall(f, cv, ...)
	if not ok then warnOnce("cverr:" .. name, "cv:" .. name .. " failed: " .. tostring(res)) return nil end
	return res
end

local function rib(cv, pts, widths, kind, o)
	if #pts < 2 then return end
	cvCall(cv, "Ribbon", pts, widths, kind, o)
end

--- cv:Sheet, or (an engine without it) its bands drawn as flat Ribbons: band j runs along u between rows j and j+1
local function sheet(cv, P, nu, nv, kind, o)
	if type(cv.Sheet) == "function" then
		cvCall(cv, "Sheet", P, nu, nv, kind, o)
		return
	end
	local bands = o.closed and nv or nv - 1
	for j = 1, bands do
		local j2 = (j % nv) + 1
		local pts, wid, side = table.create(nu), table.create(nu), table.create(nu)
		for i = 1, nu do
			local a, b = P[(i - 1) * nv + j], P[(i - 1) * nv + j2]
			pts[i] = (a + b) * 0.5
			wid[i] = (b - a).Magnitude
			side[i] = nrm(b - a)
		end
		rib(cv, pts, wid, kind, { side = side, fade = o.fade, alpha = o.alpha, glow = o.glow, maxSpans = o.maxSpans })
	end
end

local function burst(cv, kind, pos, n, o)
	if n <= 0 or type(cv.Burst) ~= "function" then return end
	cvCall(cv, "Burst", kind, pos, n, o)
end

----------------------------------------------------------------------------------------------------
-- THE RIG (skyrider_v6.py)
----------------------------------------------------------------------------------------------------
--- targets(D, t, s): the wing's wanted pose this instant (D: the driver's values at t, filled by drive())
local function targets(D, t, s, q)
	local w, A, ph = D.w, D.A, D.ph
	local wa = w * A
	local sp, s35, s70, s105 = sin(ph), sin(ph - 0.35), sin(ph - 0.7), sin(ph - 1.05)
	local u0, d0 = max(0, -sp), max(0, sp)                         -- u_(x) = max(0, -sin x), d_(x) = max(0, sin x)
	local u35, d35 = max(0, -s35), max(0, s35)
	local u70, d70 = max(0, -s70), max(0, s70)
	local u105, d105 = max(0, -s105), max(0, s105)
	q[1] = REST[1] + wa * 0.85 * cos(ph)
	q[2] = REST[2] + wa * (-0.15 * u0)
	q[3] = REST[3] + wa * (-0.18 * d0 + 0.12 * u0)
	q[4] = REST[4] + wa * 0.75 * u35
	q[5] = REST[5] + wa * 0.35 * cos(ph - 0.35)
	q[6] = REST[6] + wa * 0.95 * u70
	q[7] = REST[7] + wa * 0.45 * cos(ph - 0.7)
	q[8] = REST[8] + wa * (-0.40 * d70 + 0.35 * u70)
	q[9] = REST[9] + wa * (0.25 * d105 - 0.30 * u105)
	q[10] = REST[10] + wa * 0.9 * u105
	q[11] = REST[11] + wa * 0.15 * d0
	q[12] = REST[12] + wa * 0.35 * d35
	q[13] = REST[13] + wa * 0.6 * d70
	q[7] += 0.04 * sin(3.1 * t + s)                                -- a small continuous trim of the hand in the glide
	local b = D.bank
	q[1] += -0.35 * b * s
	q[8] += 0.25 * b * s
	q[1] += D.hitw * ((s == D.struck) and -0.7 or 0.45)            -- the struck wing drops, the other lifts
	local k1, k2 = D.k1, D.k2                                       -- the gust: WINDUP, then STROKE
	if k1 + k2 > 0 then
		local keep = 1 - k1 - k2
		for i = 1, NQ do q[i] = q[i] * keep + WINDUP[i] * k1 + STROKE[i] * k2 end
	end
	local u = D.hitU
	if u and u > 0 then                                            -- the hit: a stutter through the joints + feathers
		local st = exp(-u / 0.17) * (1 - exp(-u / 0.02))
		for i = 0, 4 do q[4 + i] += st * 0.22 * sin(TAU * 9.0 * u + i * 0.9 + s) end
		for i = 0, 2 do q[11 + i] += st * 0.55 * sin(TAU * 11.0 * u + i * 1.3 - s) end
	end
	local th = D.thin                                               -- low mana: a tremor, each wing its own
	if th > 0 then
		for i = 0, 4 do q[4 + i] += th * 0.10 * sin(17.0 * t + i * 1.1 + 2.0 * s) end
	end
	return q
end

-- the Blender timeline (the demo; skyrider_bl / skyrider_v6 MainDriver), pure functions of t
local BL = {
	T_HIT = 4.70, T_LOW0 = 5.20, T_ZERO = 6.20, TWU = 3.10, TS = 3.30, T_END = 7.45,
	FLICKS = { 5.56, 5.77, 5.93, 6.05, 6.14 },
}
function BL.omega(t)
	local w = 0.55 * bump(t, 1.05, 1.95) - 0.62 * bump(t, 1.95, 2.85) - 1.7 * bump(t, 3.65, 4.55)
	local u = t - BL.T_HIT
	if u > 0 then w += 0.55 * sin(TAU * 2.4 * u) * exp(-u / 0.28) end
	return w + 0.16 * bump(t, 5.35, 6.2)
end
function BL.hitw(t)
	local u = t - BL.T_HIT
	if u < 0 then return 0 end
	return (1 - exp(-u / 0.03)) * exp(-u / 0.24) * (1.0 + 0.35 * sin(TAU * 3.5 * u))
end
function BL.thin(t)
	return 0.7 * ease(span(t, BL.T_LOW0, BL.T_LOW0 + 0.5)) + 0.3 * ease(span(t, 5.6, BL.T_ZERO))
end
function BL.flick(t)
	local m = 1
	for _, f in ipairs(BL.FLICKS) do m *= 1 - 0.55 * exp(-((t - f) / 0.028) ^ 2) end
	return m
end
function BL.wf(t)
	return ease(span(t, 0.62, 0.95)) * (1 - ease(span(t, 2.78, 2.95))) + ease(span(t, 3.85, 4.2))
end
function BL.freq(t)
	return 1.12 - 0.17 * ease(span(t, BL.T_LOW0, BL.T_LOW0 + 0.5))
end
BL.PHI_AT_062 = 1.5 * pi + 0.2                                      -- Track: ph(0.62) = 1.5 pi + 0.2

--- hitw(u) (skyrider_bl), u = seconds since the hit
local function hitwOf(u)
	if u < 0 then return 0 end
	return (1 - exp(-u / 0.03)) * exp(-u / 0.24) * (1.0 + 0.35 * sin(TAU * 3.5 * u))
end

----------------------------------------------------------------------------------------------------
-- THE SHOWCASE FLIGHT (FX.Demo only): skyrider_bl's Track (VF / ZF through PCHIP, omega integrated into the heading,
-- the pitch from the climb, the bank from the turn), the rider's hop and fall, the gust's marks (the chest at the
-- launch, the dummies D1 / D2) and hero_cam, ported as they are. STAGE coordinates: Blender (x, y, z) -> (x, z, -y)
-- (x right, y up, -z forward), the floor y = 0, the rider standing at the origin facing -z at t = 0. Built once.
----------------------------------------------------------------------------------------------------
local SHOW = {
	TA = -0.8, TB = 7.9, HZ = 240,
	G = 9.81 * 5.25 / 1.8,                                -- zk G: real gravity, studs/s^2
	T_JUMP = 0.14, T_CATCH = 0.44, T_X0 = 0.38, T_X1 = 0.52, T_LAUNCH = 3.34, JUMP_V = 18.5, CATCH_Y = 0.35,
	K_DRAG = 1.1, CUT_G0 = 3.05, CUT_G1 = 4.02,
	VF = { { -0.8, 31.0 }, { 0.0, 30.0 }, { 0.44, 24.5 }, { 1.0, 21.5 }, { 3.25, 21.0 }, { 3.42, 13.5 }, { 3.75, 11.5 },
		{ 4.55, 16.5 }, { 4.70, 16.5 }, { 4.80, 15.0 }, { 5.10, 16.5 }, { 5.25, 17.0 }, { 6.20, 15.5 }, { 7.9, 15.5 } },
	ZF = { { -0.8, 2.9 }, { -0.1, 2.5 }, { 0.28, 2.15 }, { 0.44, 2.3 }, { 0.62, 3.3 }, { 0.95, 4.6 }, { 1.4, 6.0 },
		{ 1.9, 6.5 }, { 2.95, 6.8 }, { 3.30, 7.15 }, { 3.50, 7.55 }, { 3.90, 9.2 }, { 4.60, 12.5 }, { 4.70, 12.6 },
		{ 4.88, 11.9 }, { 5.10, 11.85 }, { 5.30, 11.9 }, { 6.20, 10.3 }, { 7.9, 10.3 } },
	-- the reel's speed ramp (skyrider_bl HERO_SEG): the summon at half speed, the gust flap at a quarter
	SEG = { { -0.20, 0.15, 1.0 }, { 0.15, 0.75, 0.5 }, { 0.75, 3.27, 1.0 }, { 3.27, 3.82, 0.25 }, { 3.82, 7.45, 1.0 } },
	STEP = "ZephyrSkyriderDemo",
}
do
	local function pchip(keys)                            -- skyrider_bl _pchip, exactly
		local n = #keys
		local x, y, h, d, m = {}, {}, {}, {}, {}
		for i = 1, n do x[i], y[i], m[i] = keys[i][1], keys[i][2], 0 end
		for i = 1, n - 1 do h[i] = x[i + 1] - x[i]; d[i] = (y[i + 1] - y[i]) / h[i] end
		for i = 2, n - 1 do
			if d[i - 1] * d[i] > 0 then
				local w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
				m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
			end
		end
		m[1], m[n] = d[1], d[n - 1]
		return function(t)
			local i = 1
			while i < n - 1 and t > x[i + 1] do i += 1 end
			local hh = h[i]
			local s = clamp01((t - x[i]) / hh)
			return (2 * s ^ 3 - 3 * s * s + 1) * y[i] + (s ^ 3 - 2 * s * s + s) * hh * m[i]
				+ (-2 * s ^ 3 + 3 * s * s) * y[i + 1] + (s ^ 3 - s * s) * hh * m[i + 1]
		end
	end
	local function idx(t)
		local x = (t - SHOW.TA) * SHOW.HZ
		local i = clamp(floor(x), 0, SHOW.n - 2)
		return i + 1, clamp01(x - i)
	end
	function SHOW.get(arr, t)
		local i, w = idx(t)
		return arr[i] + (arr[i + 1] - arr[i]) * w
	end
	--- the bird's frame at t (bankShare scales the roll: the own view's), its rotation only
	function SHOW.rot(t, bankShare)
		local i, w = idx(t)
		local function L(a) return a[i] + (a[i + 1] - a[i]) * w end
		return Ry(L(SHOW.psi)) * Rx(L(SHOW.th)) * Rz(-L(SHOW.be) * (bankShare or 1))
	end
	--- a bird-local point, unscaled (skyrider_bl to_w: root + BS R P) -> stage
	function SHOW.bird(t, P)
		return SHOW.get(SHOW.root, t) + SHOW.rot(t):VectorToWorldSpace(V3(P.X, P.Z, -P.Y) * RIG.BS)
	end
	--- the seat frame (BACK_L on the bird's back, the rider's kneel; ZephyrFX's B.CF before the stage)
	function SHOW.seat(t, bankShare)
		local R = SHOW.rot(t, bankShare)
		return CFrame.new(SHOW.get(SHOW.root, t) + R:VectorToWorldSpace(V3(BACK.X, BACK.Z, -BACK.Y) * RIG.BS)) * R
	end
	--- skyrider_bl fall_root: the kneel origin after the dismount, ballistic with drag along the ground, to the floor
	function SHOW.fall(t)
		local TZ, TL, K = BL.T_ZERO, SHOW.T_LAND, SHOW.K_DRAG
		local tau = min(t, TL) - TZ
		local V0, P0 = SHOW.VB0, SHOW.P0
		local Vf = V3(V0.X, 0, V0.Z)
		local p = P0 + Vf * ((1 - exp(-K * tau)) / K)
		p = V3(p.X, max(0, P0.Y + V0.Y * tau - 0.5 * SHOW.G * tau * tau), p.Z)
		if t > TL then p += Vf * (exp(-K * (TL - TZ)) * 0.12 * (1 - exp(-(t - TL) / 0.12))) end
		return p
	end
	--- skyrider_bl hero_cam: the summon's low camera, the swing into the rear-three-quarter chase, the gust shot from
	--- beyond the dummies (CUT_G0..CUT_G1), the peel-off alongside, the dismount watched from where it stops tracking
	function SHOW.cam(t)
		local A = SHOW.get(SHOW.anchor, t)
		local h = SHOW.get(SHOW.psiS, t)
		local F, Rg = V3(-sin(h), 0, -cos(h)), V3(cos(h), 0, -sin(h))
		local function rel(x, y, z) return A + Rg * x + F * y + UP * z end
		if t >= SHOW.CUT_G0 and t < SHOW.CUT_G1 then
			local u = (t - SHOW.CUT_G0) / (SHOW.CUT_G1 - SHOW.CUT_G0)
			local lk = SHOW.bird(min(t, BL.T_ZERO), V3(0, 1.0, 0.6)) + UP * 2.5
			lk += (SHOW.GL2 - lk) * ease(span(t, 3.12, 3.5))
			return SHOW.GC2 + (SHOW.GL2 - SHOW.GC2) * (0.08 * ease(u)), lk, 46 - 2 * ease(u)
		end
		local u0 = ease(span(t, -0.2, 0.4))
		local p0 = V3(15, 3.0, -8.5):Lerp(V3(26, 4.2, -15), u0)
		local l0 = V3(-0.3, 2.6, 1.0):Lerp(V3(-1.0, 3.8, 5.0), u0)
		if t < SHOW.CUT_G0 then
			local w = ease(span(t, 0.30, 1.30))
			local bul = sin(pi * w)
			return p0:Lerp(rel(22, -19, 15), w) + Rg * (9 * bul) + UP * (6 * bul), l0:Lerp(rel(0, 4.5, 2), w), 40
		end
		local TZ = BL.T_ZERO
		local AZ = SHOW.get(SHOW.anchor, TZ)
		local Ad = AZ + SHOW.VB0 * ((1 - exp(-1.2 * max(0, t - TZ))) / 1.2 * 0.85)
		Ad = V3(Ad.X, AZ.Y, Ad.Z)
		local hz = SHOW.get(SHOW.psiS, TZ)
		local p4 = Ad + V3(cos(hz), 0, -sin(hz)) * 19 + V3(-sin(hz), 0, -cos(hz)) * 7 - UP * 4
		local l4 = (SHOW.fall(clamp(t, TZ, BL.T_END)) + UP * 2.2) * 0.7 + (SHOW.CB0 + SHOW.VB0 * 0.15) * 0.3
		l4 = V3(l4.X, max(l4.Y, 2.5), l4.Z)
		local w = ease(span(t, 6.05, 6.6))
		return rel(24, -16, 14):Lerp(p4, w), rel(0, 4, 2):Lerp(l4, w), 40 + 4 * w
	end
	--- the reel's playback speed at clip t
	function SHOW.speed(t)
		for _, s in ipairs(SHOW.SEG) do
			if t >= s[1] and t < s[2] then return s[3] end
		end
		return 1
	end
	--- Track.__init__, at 240 Hz over -0.8 .. 7.9, once
	function SHOW.build()
		if SHOW.root then return SHOW end
		local TA, HZ = SHOW.TA, SHOW.HZ
		local n = floor((SHOW.TB - TA) * HZ + 0.5) + 1
		local VF, ZF = pchip(SHOW.VF), pchip(SHOW.ZF)
		local iC = floor((SHOW.T_CATCH - TA) * HZ + 0.5) + 1
		local psi, v, X, Y, Z = table.create(n), table.create(n), table.create(n), table.create(n), table.create(n)
		local acc = 0
		for i = 1, n do
			acc += BL.omega(TA + (i - 1) / HZ) / HZ
			psi[i] = acc
		end
		local p0, ax, ay = psi[iC], 0, 0
		for i = 1, n do
			local t = TA + (i - 1) / HZ
			psi[i] -= p0
			v[i] = VF(t)
			ax += -v[i] * sin(psi[i]) / HZ
			ay += v[i] * cos(psi[i]) / HZ
			X[i], Y[i], Z[i] = ax, ay, ZF(t)
		end
		local root, vel, th, be = table.create(n), table.create(n), table.create(n), table.create(n)
		local x0, y0, yC = X[iC], Y[iC], SHOW.CATCH_Y - RIG.BS * BACK.Y
		for i = 1, n do
			local t = TA + (i - 1) / HZ
			local a, b = max(1, i - 1), min(n, i + 1)
			local vz = (Z[b] - Z[a]) * HZ / (b - a)                  -- np.gradient
			root[i] = V3(X[i] - x0, Z[i], -(Y[i] + yC - y0))
			vel[i] = V3(-v[i] * sin(psi[i]), vz, -v[i] * cos(psi[i]))
			th[i] = 0.85 * atan2(vz, v[i]) + 0.25 * bump(t, 3.2, 3.75) - 0.12 * bump(t, 4.7, 5.1) + 0.12 * bump(t, 0.35, 0.95)
			be[i] = -1.15 * atan(v[i] * BL.omega(t + 0.1) / SHOW.G) + 0.50 * BL.hitw(t)
				+ 0.07 * sin(TAU * 0.9 * t) * BL.thin(t)
		end
		local k = floor(0.3 * HZ)                                      -- the cameras' +-0.3 s box (edges held)
		local function box(Arr, zero)
			local cs = { [0] = zero }
			for j = 1, n + 2 * k do cs[j] = cs[j - 1] + Arr[clamp(j - k, 1, n)] end
			local out = table.create(n)
			for i = 1, n do out[i] = (cs[i + 2 * k] - cs[i - 1]) / (2 * k + 1) end
			return out
		end
		SHOW.n, SHOW.psi, SHOW.th, SHOW.be, SHOW.v, SHOW.vel = n, psi, th, be, v, vel
		SHOW.root = root
		SHOW.anchor, SHOW.psiS = box(root, VZERO), box(psi, 0)
		-- the gust's marks: the (unscaled) chest at the launch, the dummies D1 / D2 ahead-left, the gust camera
		local A = SHOW.bird(SHOW.T_LAUNCH, V3(0, 6.0, 0.9))
		local f = SHOW.rot(SHOW.T_LAUNCH).LookVector
		local FH = nrm(V3(f.X, 0, f.Z))
		local RH = FH:Cross(UP)
		local Af = V3(A.X, 0, A.Z)
		SHOW.D1, SHOW.D2 = Af + FH * 17.5 - RH * 4.2, Af + FH * 23.0 - RH * 7.4
		SHOW.GC2 = Af + FH * 14.0 + RH * 33.0 + UP * 8.5
		SHOW.GL2 = A * 0.45 + (SHOW.D1 + SHOW.D2) * 0.275 + UP * 1.6
		-- the dismount: bird_centre and the velocity at T_ZERO, the rider's fall from the seat, the landing
		local TZ = BL.T_ZERO
		SHOW.CB0, SHOW.VB0, SHOW.P0 = SHOW.bird(TZ, V3(0, 1.0, 0.6)), SHOW.get(vel, TZ), SHOW.seat(TZ).Position
		SHOW.PSI0 = SHOW.get(psi, TZ)
		local vz0 = SHOW.VB0.Y
		SHOW.T_LAND = TZ + (vz0 + sqrt(vz0 * vz0 + 2 * SHOW.G * SHOW.P0.Y)) / SHOW.G
		return SHOW
	end
end

--- the bird's live low-mana flicks (Blender FLICKS were hand-placed): one chance per FlickSlot, x thin
local function flickLive(B, t)
	local th = B.thin
	if th <= 0.02 then return 1 end
	local slot = DRV.FlickSlot
	local k0 = floor(t / slot)
	local m = 1
	for k = k0 - 1, k0 + 1 do
		if hn(B.Seed, k, 5) < th * DRV.FlickChance then
			local f = (k + 0.2 + 0.6 * hn(B.Seed, k, 6)) * slot
			m *= 1 - 0.55 * exp(-((t - f) / 0.028) ^ 2)
		end
	end
	return m
end

--- the latest event of a list (each { T = clip s }) at or before t
local function latest(list, t)
	local best = nil
	for _, e in ipairs(list) do
		if e.T <= t and (not best or e.T > best.T) then best = e end
	end
	return best
end

--- The driver's values at t (one substep): MainDriver's w / A / ph / bank / hit, the gust blend, thin. Live from the
--- bird's events and the flight it reads; Demo from the Blender timeline. The phase is integrated here (dt).
local function drive(B, t, dt)
	local D = B.D
	if B.Demo then
		local th = BL.thin(t)
		D.thin = th
		D.w = BL.wf(t)
		D.A = RIG.Amp * (1 - 0.45 * th) * (1 - 0.35 * th * (0.5 + 0.5 * sin(5.1 * t + 1.3 * sin(2.3 * t))))
		B.PHI += TAU * BL.freq(t) * dt
		D.ph = B.PHI + 0.4 * th * sin(13 * t)
		D.bank = clamp(BL.omega(t), -1, 1)
		D.hitw = BL.hitw(t)
		D.hitU = t - BL.T_HIT
		D.struck = 1
		D.TWU, D.TS = BL.TWU, BL.TS
	else
		local th = B.thin
		D.thin = th
		local S = B.SummonTime
		local w = ease(span(t, S + 0.18, S + 0.51))                 -- the catch: the flap comes in after the summon
		local g = latest(B.Gusts, t)
		if g then
			w *= 1 - ease(span(t, g.T, g.T + 0.12)) * (1 - ease(span(t, g.TS + 0.55, g.TS + 0.9)))
			D.TWU, D.TS = g.T, g.TS
		else
			D.TWU, D.TS = nil, nil
		end
		w *= 1 - DRV.DiveGlide * smooth(-B.Pitch, DRV.DiveFrom, DRV.DiveFull)   -- diving: the wings held, gliding
		D.w = w
		local sp = clamp(B.Speed / DRV.CruiseSpeed, 0.4, 1.6)
		D.A = RIG.Amp * (1 - 0.45 * th) * (1 - 0.35 * th * (0.5 + 0.5 * sin(5.1 * t + 1.3 * sin(2.3 * t))))
			* (0.92 + 0.08 * sp)
		local f = (1 / DRV.CruisePeriod) * sp ^ DRV.SpeedExp * (1 - DRV.LowManaSlow * th)
		B.PHI += TAU * f * dt
		D.ph = B.PHI + 0.4 * th * sin(13 * t)
		D.bank = clamp(B.Omega, -1, 1)
		local h = latest(B.Hits, t)
		if h then
			D.hitU = t - h.T
			D.hitw = hitwOf(D.hitU)
			D.struck = h.S
		else
			D.hitU, D.hitw, D.struck = nil, 0, 1
		end
	end
	if D.TWU then
		local TWU, TS = D.TWU, D.TS
		D.k1 = smooth(t, TWU, TS) * (1 - smooth(t, TS, TS + 0.03))
		D.k2 = smooth(t, TS, TS + 0.03) * (1 - smooth(t, TS + 0.18, TS + 0.32))
	else
		D.k1, D.k2 = 0, 0
	end
end

--- rig(): the wing's joints and bone frames (bird-local) from the simulated angles
local function rig(q, s)
	local S = V3(0.85 * s, 2.7, 0.95)
	local x = V3(s, 0, 0)
	local R1 = Rz(s * q[2]) * Ry(-s * q[1]) * Rx(q[3])
	local E = S + R1:VectorToWorldSpace(x) * LA
	local R2 = R1 * Rz(-s * q[4]) * Ry(-s * q[5])
	local W = E + R2:VectorToWorldSpace(x) * LF
	local R3 = R2 * Rz(s * q[6]) * Ry(-s * q[7]) * Rx(q[8])
	local Tp = W + R3:VectorToWorldSpace(x) * LH
	return S, E, W, Tp, R1, R2, R3
end

--- The WingSim, live: damped springs per DOF, both wings, semi-implicit Euler at Rig.Hz from the bird's own start.
--- A hit kicks every DOF's velocity once (a hashed unit normal x Rig.Kick), as Blender's rs.normal kick.
local SIDES = { 1, -1 }
local function simReset(B, t0)
	local sim = { T = t0, Q = {}, V = {}, Kicked = {} }
	if B.TipHist then table.clear(B.TipHist) end
	drive(B, t0, 0)
	for _, s in ipairs(SIDES) do
		sim.Q[s] = targets(B.D, t0, s, table.create(NQ, 0))
		sim.V[s] = table.create(NQ, 0)
	end
	B.Sim = sim
end

local tqBuf = table.create(NQ, 0)
local function simStep(B, t, maxSub)
	local sim = B.Sim
	if not sim or t < sim.T - 1e-6 then
		simReset(B, B.Demo and -0.6 or min(t, 0))
		sim = B.Sim
	end
	local dt = 1 / RIG.Hz
	local n = 0
	maxSub = maxSub or RIG.MaxSubsteps
	while sim.T + dt <= t + 1e-9 do
		if n >= maxSub then
			sim.T = t                                                -- a long hitch: skip ahead (the springs settle)
			break
		end
		local tt = sim.T + dt
		drive(B, tt, dt)
		local hits = B.Demo and B.DemoHits or B.Hits
		for _, h in ipairs(hits) do
			if not sim.Kicked[h] and tt >= h.T then
				sim.Kicked[h] = true
				for _, s in ipairs(SIDES) do
					local v = sim.V[s]
					for i = 1, NQ do v[i] += gauss(B.Seed + h.T * 7.3, i, s) * KICK[i] end
				end
			end
		end
		for _, s in ipairs(SIDES) do
			local q, v = sim.Q[s], sim.V[s]
			local tq = targets(B.D, tt, s, tqBuf)
			for i = 1, NQ do
				v[i] += (KK[i] * (tq[i] - q[i]) - CC[i] * v[i]) * dt
				q[i] += v[i] * dt
			end
		end
		if B.Demo then
			-- the hovering demo keeps its tips' recent path (bird-local) for the vortices, as Blender re-evaluates rig()
			local _, _, _, tR = rig(sim.Q[1], 1)
			local _, _, _, tL = rig(sim.Q[-1], -1)
			local h = B.TipHist
			h[#h + 1] = { T = tt, [1] = tR, [-1] = tL }
			if #h > 110 then table.remove(h, 1) end                    -- ~0.45 s at 240 Hz
		end
		sim.T = tt
		n += 1
	end
	drive(B, t, 0)                                                    -- the draw reads this frame's driver values
end

--- wing_geo(): the spar (a smooth spline through the joints, bowed between them), per-sample frames blended across the
--- joints (chord, normal, span), the chord profile, and the membrane rows/cols this build draws
local function wingGeo(q, s, G)
	G = G or {}
	local S, E, Wj, Tp, R1, R2, R3 = rig(q, s)
	G.S, G.E, G.W, G.T, G.R1, G.R2, G.R3, G.q, G.s = S, E, Wj, Tp, R1, R2, R3, q, s
	local bow0 = R1:VectorToWorldSpace(YAX) * 0.18
	local bow1 = R2:VectorToWorldSpace(YAX) * 0.10
	local bow2 = R3:VectorToWorldSpace(-YAX) * 0.05
	local ctrl = { S, (S + E) / 2 + bow0, E, (E + Wj) / 2 + bow1, Wj, (Wj + Tp) / 2 + bow2, Tp }
	G.LE = spline(ctrl, 40, 1.0, G.LE)
	local ch = { R1:VectorToWorldSpace(-YAX), R2:VectorToWorldSpace(-YAX), R3:VectorToWorldSpace(-YAX) }
	local no = { R1:VectorToWorldSpace(ZAX), R2:VectorToWorldSpace(ZAX), R3:VectorToWorldSpace(ZAX) }
	G.CH, G.NO, G.SP, G.C = G.CH or {}, G.NO or {}, G.SP or {}, G.C or {}
	for i = 1, 40 do
		local b = WB[i]
		local w1 = 1 - smooth(b, 0.27, 0.39)
		local w3 = smooth(b, 0.61, 0.73)
		local w2 = 1 - w1 - w3
		G.CH[i] = nrm(ch[1] * w1 + ch[2] * w2 + ch[3] * w3)
		G.NO[i] = nrm(no[1] * w1 + no[2] * w2 + no[3] * w3)
		G.SP[i] = tangent(G.LE, i)
		G.C[i] = interp(b, CH_X, CH_Y)
	end
	return G
end

--- the membrane's point (row r over [root, LE 1..40] = 1..41, v 0..1): LE + CH c v + NO 0.15 c sin(pi v)
local function memPoint(G, r, v)
	local LEp, CHp, NOp, c
	if r == 1 then
		LEp = G.LE[1] - G.SP[1] * 0.7                                 -- the root sits inside the body
		CHp, NOp, c = G.CH[1], G.NO[1], 2.8
	else
		LEp, CHp, NOp, c = G.LE[r - 1], G.CH[r - 1], G.NO[r - 1], G.C[r - 1]
	end
	return LEp + CHp * (c * v) + NOp * (0.15 * c * sin(pi * v))
end

--- wing_geo.at(bb): the spar's point, chord, normal, span and chord length at fraction bb (b is uniform)
local function at(G, bb)
	local x = clamp(bb, 0, 1) * 39 + 1
	local i = clamp(floor(x), 1, 39)
	local u = x - i
	return G.LE[i]:Lerp(G.LE[i + 1], u), nrm(G.CH[i]:Lerp(G.CH[i + 1], u)), nrm(G.NO[i]:Lerp(G.NO[i + 1], u)),
		nrm(G.SP[i]:Lerp(G.SP[i + 1], u)), lerp(G.C[i], G.C[i + 1], u)
end

--- rot_about: rotate V about the unit axis A by ang
local function rotAbout(V, A, ang)
	local c, s_ = cos(ang), sin(ang)
	return V * c + A:Cross(V) * s_ + A * (A:Dot(V) * (1 - c))
end

--- feathers(): the tiers ON their bones. Each feather: root, dir, normal, length, width, curl (bird-local units)
local function feathers(G, picks, out)
	local q, s = G.q, G.s
	local fan, slot, bc, bs_, bp = q[9], q[10], q[11], q[12], q[13]
	out = out or {}
	out.cov = out.cov or {}
	out.sec = out.sec or {}
	out.pri = out.pri or {}
	for m, i in ipairs(picks.cov) do                                -- coverts: the upper arm + forearm
		local bb = COV_B[i]
		local P, C, N, S_, c = at(G, bb)
		local f = out.cov[m] or {}
		f.R, f.D, f.N, f.L, f.W, f.C = P + C * (0.08 * c), nrm(C + S_ * 0.15), N, 0.45 * c + 0.4, 0.95, 0.10 + bc
		f.I = i
		out.cov[m] = f
	end
	for m, i in ipairs(picks.sec) do                                -- tertials + secondaries
		local bb = SEC_B[i]
		local P, C, N, S_, c = at(G, bb)
		local f = out.sec[m] or {}
		f.R, f.D, f.N, f.L, f.W, f.C = P + C * (0.35 * c), nrm(C + S_ * (0.08 + 0.25 * bb)), N, SEC_L[i], 1.05, 0.12 + bs_
		f.I = i
		out.sec[m] = f
	end
	local R3 = G.R3                                                 -- primaries: fanning from the hand
	local sp = nrm(R3:VectorToWorldSpace(V3(s, 0, 0)))
	local ch = nrm(R3:VectorToWorldSpace(-YAX))
	local no = nrm(R3:VectorToWorldSpace(ZAX))
	for m, i in ipairs(picks.pri) do
		local u = PRI_U[i]
		local al = math.rad(20 + (u ^ 0.9) * 62 * fan)
		local d = nrm(ch * cos(al) + sp * sin(al))
		local f = out.pri[m] or {}
		f.R = G.W + (G.T - G.W) * PRI_H[i]
		f.D = d
		f.N = rotAbout(no, d, slot * (0.2 + 0.8 * u) * s)           -- the slots open on the upstroke
		f.L, f.W, f.C = PRI_L[i], 1.15, 0.14 + bp * (0.6 + 0.4 * u)
		f.I = i
		out.pri[m] = f
	end
	return out
end

--- body_dz (skyrider_bl): the flap's ripple down the back + the keyed strokes rippling to the tail
local function bodyDz(B, t, s)
	local a = 0.4 + 0.6 * B.D.w * (B.D.A / RIG.Amp)
	local dz = 0.20 * a * sin(B.D.ph - 1.6 - 2.4 * s) * (0.15 + 0.85 * s)
	for _, k in ipairs(B.Strokes) do
		local u = t - k.T - 0.16 * clamp01((s - 0.3) / 0.7)
		if u > 0 and u < 3 then
			dz += -k.K * sin(TAU * u / 0.55) * exp(-u / 0.3) * (0.2 + 0.8 * s)
		end
	end
	return dz
end

--- head_rot (skyrider_bl): the head leads the turn, nods down into the gust's wind-up and up through the stroke
local function headRot(B, t)
	local hy = 0.45 * B.OmegaLead
	local hp = 0.12 * bump(t, B.CatchA, B.CatchB)
	local TS = B.D.TS
	if TS then hp += -0.28 * bump(t, TS - 0.35, TS + 0.06) + 0.24 * bump(t, TS, TS + 0.65) end
	return Rz(hy) * Rx(-hp)
end

--- spine(t): the back as 30 points (beak tip first) + widths
local function spine(B, t, out)
	local Hr = headRot(B, t)
	for i = 1, NS do
		local s = SS[i]
		local P = V3(0, SY[i], SZ[i] + bodyDz(B, t, s))
		local w = smooth(-s, -0.34, -0.05)
		if w > 0 then
			local Q = Hr:VectorToWorldSpace(P - PIVOT) + PIVOT
			P = P:Lerp(Q, w)
		end
		local tw = clamp01(s - 0.4)
		out[i] = P + V3(-0.8 * B.OmegaNow * tw * tw, 0, 0)
	end
	B.Hr = Hr
	return out
end

--- head_feat (skyrider_bl): the beak (upper, lower with the gape), the eye lines, the crest root, the head's back
local BEAK_U = { V3(0, 6.85, 2.62), V3(0, 7.25, 2.66), V3(0, 7.6, 2.50), V3(0, 7.85, 2.28), V3(0, 7.88, 2.05),
	V3(0, 7.78, 1.92) }
local BEAK_L = { V3(0, 6.85, 2.20), V3(0, 7.15, 2.13), V3(0, 7.42, 2.07), V3(0, 7.62, 2.03) }
local BEAK_PIV = V3(0, 6.85, 2.28)
local EYEL = {}
for k, sx in ipairs({ 1, -1 }) do
	EYEL[k] = { V3(sx * 0.50, 6.80, 2.68), V3(sx * 0.56, 6.40, 2.72), V3(sx * 0.60, 5.95, 2.62), V3(sx * 0.58, 5.50, 2.40),
		V3(sx * 0.52, 5.05, 2.10) }
end
local function headFeat(B, t, H)
	local Hr = B.Hr
	local dz = bodyDz(B, t, SS[IH])
	local function Hp(p)
		p = p + V3(0, -0.5, 0)
		p = HEAD_C + (p - HEAD_C) * 1.15 + V3(0, 0, dz)
		return Hr:VectorToWorldSpace(p - PIVOT) + PIVOT
	end
	local gape = 0.28 * bump(t, B.CatchA + 0.02, B.CatchB + 0.05)
	if B.D.TS then gape += 0.40 * bump(t, B.D.TS - 0.05, B.D.TS + 0.65) end
	local Rg = Rx(-gape)
	H.up = H.up or {}
	H.lo = H.lo or {}
	for i, p in ipairs(BEAK_U) do H.up[i] = Hp(p) end
	for i, p in ipairs(BEAK_L) do H.lo[i] = Hp(Rg:VectorToWorldSpace(p - BEAK_PIV) + BEAK_PIV) end
	H.eyel = H.eyel or { {}, {} }
	for k = 1, 2 do
		for i, p in ipairs(EYEL[k]) do H.eyel[k][i] = Hp(p) end
	end
	H.crest = Hp(V3(0, 5.95, 2.95))
	H.back = Hp(V3(0, 5.6, 2.9)) - Hp(V3(0, 6.6, 2.9))
	return H
end

--- layers(): per-layer presence. The summon builds the skeleton first, then the surface fills out (root -> tip);
--- the dismount breaks it from the feather tips inward. tb = the summon clock, d = the dismount fraction.
local function layers(tb, d, ly)
	local function o(a, b) return 1 - smooth(d, a, b) end
	local function S(a, b) return smooth(tb, a, b) end
	ly.skel = S(-0.10, 0.08) * o(0.5, 0.9)
	ly.mem = S(0.06, 0.30) * o(0.3, 0.75)
	ly.body = S(0.02, 0.24) * o(0.45, 1.0)
	ly.cov = S(0.12, 0.32) * o(0.22, 0.6)
	ly.sec = S(0.16, 0.36) * o(0.1, 0.45)
	ly.pri = S(0.20, 0.40) * o(0.0, 0.3)
	return ly
end

----------------------------------------------------------------------------------------------------
-- THE BIRD'S FRAME (bird-local -> world)
----------------------------------------------------------------------------------------------------
--- explode (skyrider_bl): before the bird has formed, its shapes are scattered and stretched along the swoop
local EXPLODE_C = V3(0, 1.0, 0.6)
local function explode(B, q, key)
	local k = 1 - B.Form
	local off = V3(hn(key, 1) - 0.5, hn(key, 2) - 0.5, (hn(key, 3) - 0.5) * 0.5) * 3.0
	local c = EXPLODE_C
	local Q = c + (q - c) * (1 + 0.6 * k)
	Q = V3(Q.X, c.Y + (Q.Y - c.Y) * (1 + 1.4 * k) - 3.0 * k, Q.Z)
	return Q + off * (k * k)
end

--- a bird-local point -> world: KS about the seat, the summon's explode, BS (x the drawn scale), the frame
local function toW(B, p, key)
	local q = BACK + (p - BACK) * RIG.KS
	if B.Form < 1 then q = explode(B, q, key or 0) end
	local d = (q - BACK) * B.KB
	return B.CF:PointToWorldSpace(V3(d.X, d.Z, -d.Y))
end
--- a bird-local direction -> world
local function toWd(B, v)
	return B.CF:VectorToWorldSpace(V3(v.X, v.Z, -v.Y))
end

--- scat (skyrider_bl), in place on a group of world points: after the dismount the shape keeps the bird's momentum,
--- flies outward from the body, loosens and fades. Returns fade, width scale.
local function scat(B, pts, key, n)
	local tau = B.Tau
	if not tau or tau <= 0 then return 1, 1 end
	n = n or #pts
	if n == 0 then return 1, 1 end
	local c = VZERO
	for i = 1, n do c += pts[i] end
	c /= n
	local out = nrm(c - B.CB0)
	local g = (1 - exp(-1.6 * tau)) / 1.6
	local rr = 0.8 + 0.6 * hn(key, 7)
	local base = c + B.VB0 * g + out * (3.2 * rr * g) + V3(0, 0.7 * tau, 0)
	local grow = 1 + 0.9 * ease(span(tau, 0, 0.6))
	for i = 1, n do pts[i] = base + (pts[i] - c) * grow end
	return 1 - ease(span(tau, 0.05, 0.6)), 1 + 0.9 * span(tau, 0, 0.5)
end

--- own-view fade for a ribbon passing near the camera (the summon / wisp ribbons can sweep the eye)
local function nearFade(B, p)
	if not B.Own then return 1 end
	local cam = workspace.CurrentCamera
	if not cam then return 1 end
	return smooth((p - cam.CFrame.Position).Magnitude, LOOK.OwnNear[1], LOOK.OwnNear[2])
end

----------------------------------------------------------------------------------------------------
-- BIRDS
----------------------------------------------------------------------------------------------------
local birds = {}           -- [character] = the live bird (one per character)

--- The flight, read from the root each frame (or the Blender hover for the demo), and the frame built from it.
local function observe(B, t, dtf)
	local D = B.D
	if B.Demo then
		-- the showcase flight's frame at t (held at the dismount's instant after it: drawBird coasts it from there)
		local tt = (B.TE and t >= B.TE) and B.TE or t
		B.Speed, B.Pitch = SHOW.get(SHOW.v, tt), SHOW.get(SHOW.th, tt)
		B.OmegaNow, B.OmegaLead = BL.omega(tt), BL.omega(tt + 0.1)
		B.Omega = B.OmegaNow
		B.thin = BL.thin(tt)
		B.Bank = SHOW.get(SHOW.be, tt)
		B.CF = B.Stage * SHOW.seat(tt, B.Own and LOOK.OwnBankShare or 1)
		if B.Own then B.CF -= UP * LOOK.OwnDrop end
		B.Vel = B.Stage:VectorToWorldSpace(SHOW.get(SHOW.vel, tt))
		return true
	end
	local root = B.Character and B.Character.Parent and B.Character:FindFirstChild("HumanoidRootPart")
	if B.TE == nil then
		if not root then return false end
		local v = root.AssemblyLinearVelocity
		local flat = V3(v.X, 0, v.Z)
		local sp = flat.Magnitude
		local dir
		if sp > 4 then
			dir = flat / sp
		else
			local lv = root.CFrame.LookVector
			dir = V3(lv.X, 0, lv.Z)
			dir = dir.Magnitude > 1e-3 and dir.Unit or V3(0, 0, -1)
		end
		local psiT = atan2(-dir.X, -dir.Z)
		if B.Psi == nil then
			B.Psi, B.Omega = psiT, 0
		elseif dtf > 0 then
			local d = wrapAngle(psiT - B.Psi) * (1 - exp(-dtf * DRV.HeadingFollow))
			B.Psi = wrapAngle(B.Psi + d)
			B.Omega += (d / dtf - B.Omega) * (1 - exp(-dtf / DRV.OmegaTau))
		end
		B.OmegaNow, B.OmegaLead = B.Omega, B.Omega
		B.Speed, B.Vel, B.Flat = v.Magnitude, v, sp
		local mana = B.Character:GetAttribute("Mana")
		local thinRaw = (type(mana) == "number") and clamp01((DRV.LowMana - mana) / DRV.LowMana) or 0
		B.ThinRaw = B.ThinRaw + (thinRaw - B.ThinRaw) * (dtf > 0 and (1 - exp(-dtf / DRV.ThinTau)) or 0)
		B.thin = ease(B.ThinRaw)
		-- the frame: heading, then the pitch, then the bank (Track: Rz(psi) Rx(th) Ry(be))
		local S = B.SummonTime
		local th = DRV.PitchShare * atan2(v.Y, max(sp, 1)) + 0.12 * bump(t, S - 0.09, S + 0.51)
		local g = latest(B.Gusts, t)
		if g then th += 0.25 * bump(t, g.TS - 0.10, g.TS + 0.45) end
		local h = latest(B.Hits, t)
		local hw, hs = 0, 1
		if h then
			hw, hs = hitwOf(t - h.T), h.S
			th -= 0.12 * bump(t, h.T, h.T + 0.4)
			local u = t - h.T                                        -- the wobble's sloppy steering (omega)
			B.OmegaNow += 0.55 * sin(TAU * 2.4 * u) * exp(-u / 0.28)
		end
		B.Pitch = th
		local be = -DRV.BankK * atan(sp * B.Omega / DRV.BankG) + 0.50 * hw * hs + 0.07 * sin(TAU * 0.9 * t) * B.thin
		be = clamp(be, -DRV.BankMax, DRV.BankMax)
		if B.Own then be *= LOOK.OwnBankShare end
		B.Bank = be
		local seat = root.Position - UP * (B.SeatBelow + (B.Own and LOOK.OwnDrop or 0))
		local sw = 1 - ease(clamp01(t / max(0.05, S)))
		if sw > 0 then seat += (-dir * LOOK.SwoopBack - UP * LOOK.SwoopDown) * sw end
		B.CF = CFrame.new(seat) * CFrame.Angles(0, B.Psi, 0) * Rx(th) * Rz(-be)
	end
	return true
end

--- One frame of the bird (frame_fn): the rig, the body, the head, the effects. Returns false when it is over.
local function drawBird(B, cv, t)
	local dtf = clamp(t - (B.LastT or t), 0, 0.1)
	B.LastT = t
	if not observe(B, t, dtf) then
		if B.TE == nil then FX._endBird(B, t, "Gone") end
	end
	if not B.CF then return B.TE == nil or t < (B.TE or 0) + 1.6 end

	-- the dismount: freeze the frame where the ride ended and let it coast; scat() carries the rest
	if B.TE and t >= B.TE then
		if not B.EndCF then
			B.EndCF, B.VB0 = B.CF, B.Vel or VZERO
			B.CB0 = toW(B, EXPLODE_C)                                -- bird_centre: (0, 1, 0.6) bird-local
			burst(cv, "puff", B.CB0, 40, { id = "end_puff", speed = { 3, 10 }, life = { 0.8, 1.6 }, size = { 0.6, 1.4 } })
			burst(cv, "spark", B.CB0, 30, { id = "end_spark", speed = { 4, 12 }, life = { 0.4, 0.9 } })
			FX._wispsEnd(B)
		end
		B.Tau = t - B.TE
		B.CF = B.EndCF + B.VB0 * (B.Tau * LOOK.EndCarry)
		if B.Tau > 0.05 then
			burst(cv, "mist", B.CB0, 14, { id = "end_mist", speed = { 2, 6 }, life = { 0.9, 1.5 }, size = { 1.0, 1.8 } })
		end
	else
		B.Tau = nil
	end

	-- the summon clock and the presence of every layer
	local S = B.SummonTime
	local tb
	if B.Demo then
		tb = t
	elseif t < S then
		tb = -0.24 + t * (0.64 / S)
	else
		tb = 0.40 + (t - S)
	end
	B.Tb = tb
	B.Form = ease(span(tb, 0, 0.30))
	local d = B.TE and span(t - B.TE, 0, 0.54) or 0
	local ly = layers(tb, d, B.Ly)

	-- the springs, up to now
	simStep(B, t, B.Freeze and 100000 or nil)
	local D = B.D

	local thin = B.thin
	local flk = B.Demo and BL.flick(t) or flickLive(B, t)
	local flicker = 1 - thin * (0.15 + 0.35 * max(0, sin(37 * t) * sin(23 * t + 1.0)))
	local tell = (1 - 0.5 * thin) * flk * flicker
	local stut = (1.0 + 0.3 * D.hitw * sin(t * 90)) * flicker
	local fray = 0.6 * thin + 0.4 * D.hitw
	local k = B.KB * RIG.KS                                          -- bird units -> studs for lengths and widths
	local SP = LOOK.Spans
	B.Skel, B.TipNow = B.Skel or {}, B.TipNow or {}

	------------------------------------------------------------------ the wings
	for _, s in ipairs(SIDES) do
		local G = wingGeo(B.Sim.Q[s], s, B.Geo[s])
		B.Geo[s] = G
		local F = feathers(G, B.Picks, B.Feath[s])
		B.Feath[s] = F
		local wingFade = tell * max(ly.skel, ly.mem, ly.body, ly.cov, ly.sec, ly.pri)
		-- the spar's world points (also the summon's targets and the gust's pressure crests)
		local skel = B.Skel[s] or {}
		for i = 1, 40 do skel[i] = toW(B, G.LE[i], keyOf("le") + s) end
		local f3, ws3 = scat(B, skel, keyOf("le") + s, 40)
		B.Skel[s] = skel
		B.TipNow[s] = skel[40]
		if wingFade * f3 > 0.004 then
			-- the membrane: rows over [root, LE] (sa), cols over the chord (ch) -- ZephyrDraw's "surf" is mat_surf: it
			-- feathers the trailing edge and the tip itself and keeps the leading edge hot (v6: e0 0.6, e1 1.5, a0 0.62)
			local nu, nv = LOOK.MemRows, LOOK.MemCols
			local P = B.MemP[s] or table.create(nu * nv)
			for i = 1, nu do
				local r = 1 + floor((i - 1) * 40 / (nu - 1) + 0.5)
				for j = 1, nv do
					P[(i - 1) * nv + j] = toW(B, memPoint(G, r, (j - 1) / (nv - 1)), keyOf("mem") + s)
				end
			end
			local fm = scat(B, P, keyOf("mem") + s, nu * nv)
			B.MemP[s] = P
			local fade = tell * fm * ly.mem
			if fade > 0.004 then
				sheet(cv, P, nu, nv, "surf", { fade = fade, alpha = 0.62, glow = stut, e0 = 0.6, e1 = 1.5, a0 = 0.62,
					t = t + s, maxSpans = SP.Sheet })
			end
			-- the feather tiers: soft tapered blades from their quill roots, bending along their length
			for _, tier in ipairs({ "cov", "sec", "pri" }) do
				local list = F[tier]
				local key = keyOf(tier) + s
				local tierFade = tell * (tier == "cov" and 0.85 or 1.0) * ly[tier]
				local knots = B.Knots[s .. tier] or {}
				local n = 0
				for _, f in ipairs(list) do
					local Dd = nrm(f.D)
					local Nn = nrm(f.N - Dd * f.N:Dot(Dd))
					for _, sv in ipairs(FEATHER_S) do
						n += 1
						knots[n] = toW(B, f.R + Dd * (sv * f.L) + Nn * (sv * sv * f.C * f.L), key)
					end
					f.Side = toWd(B, Dd:Cross(Nn))
				end
				B.Knots[s .. tier] = knots
				local ft, wsT = scat(B, knots, key, n)
				local fade = tierFade * ft
				-- the tips, for the wisps (this frame's and last frame's: their velocity)
				local tips = B.FTips[s .. tier] or {}
				local prev = B.FTipsPrev[s .. tier] or {}
				for m = 1, #list do
					prev[m] = tips[m]
					tips[m] = knots[m * 3]
				end
				B.FTips[s .. tier], B.FTipsPrev[s .. tier] = tips, prev
				if fade > 0.004 then
					-- mat_feather5 is ZephyrDraw's "feather" (root bright -> tip deeper, its own opacity 0.78); the
					-- fraying tip (tipz: smooth(fu, 0.62 - 0.35 fray, 1)) is the tail fade
					local frayT = min(1, fray + ((tier == "pri") and 0.7 * thin or 0))
					for m, f in ipairs(list) do
						local pts = { knots[m * 3 - 2], knots[m * 3 - 1], knots[m * 3] }
						local wd = f.W * k * wsT
						rib(cv, pts, { wd * FEATHER_W[1], wd * FEATHER_W[2], wd * FEATHER_W[3] }, "feather", {
							side = f.Side, fade = fade, glow = stut, tail = 0.38 + 0.35 * frayT, t = t + m * 0.37,
							maxSpans = SP.Feather,
						})
					end
				end
			end
			-- the spar: a white-hot core along the leading edge inside its glow sleeve (the core goes first at the end)
			local cf = ly.skel * tell * f3
			if B.TE and t > B.TE then cf *= max(0, 1 - (t - B.TE) / 0.15) end
			local pts, wc, wg = table.create(13), table.create(13), table.create(13)
			for m = 1, 13 do
				local i = 1 + floor((m - 1) * 39 / 12 + 0.5)
				pts[m] = skel[i]
				local u = (i - 1) / 39
				wc[m] = lerp(0.13, 0.03, u) * ws3
				wg[m] = lerp(0.6, 0.15, u) * ws3
			end
			-- one set of knots, the glow sleeve with its white-hot core on top (CoreGlow; the core's own fade / glow)
			local gf = tell * f3 * 0.8 * ly.skel
			if gf > 0.004 or cf > 0.004 then
				cvCall(cv, "CoreGlow", pts, wc, wg, { fade = gf, alpha = 0.6, glow = stut, tail = 0.35, maxSpans = SP.Spar,
					core = { fade = cf, glow = 1.25 * stut, tail = 0.25 } })
			end
		end
	end

	------------------------------------------------------------------ the body, spine, tail, head, crest
	local Psp = spine(B, t, B.Spine)
	-- body_geo: a lofted, deep-chested tube round the spine (ellipse 0.42 W wide, 0.56 W deep)
	local P36 = spline(Psp, 36, 1.0, B.Spine36)
	B.Spine36 = P36
	local nr, na = LOOK.BodyRings, LOOK.BodyAround
	local G = B.BodyP or table.create(nr * na)
	local spineL = B.SpineL or {}
	local U36 = B.U36 or {}
	for i = 1, 36 do
		local Tn = tangent(P36, i)
		U36[i] = nrm(ZAX - Tn * Tn:Dot(ZAX))
	end
	B.U36 = U36
	local function Wat(i) return interp((i - 1) / 35, SS, SW) end
	for m = 1, nr do
		local i = 1 + floor((m - 1) * 35 / (nr - 1) + 0.5)
		local Tn, U = tangent(P36, i), U36[i]
		local Sd = Tn:Cross(U)
		local W = Wat(i)
		local rx, rz = 0.42 * W, 0.56 * W
		-- round the ring from the side, over the top: the closed Sheet's ch (za5) is bright along the top, the belly
		-- feathered -- ZephyrDraw's "surf" draws that itself
		for j = 1, na do
			local th = TAU * (j - 1) / na
			G[(m - 1) * na + j] = toW(B, P36[i] + Sd * (rx * cos(th)) + U * (rz * sin(th)), keyOf("body"))
		end
	end
	B.BodyP = G
	local fb = scat(B, G, keyOf("body"), nr * na)
	local bodyFade = tell * fb * ly.body
	if bodyFade > 0.004 then
		sheet(cv, G, nr, na, "surf", { fade = bodyFade, alpha = 0.48, glow = stut, closed = true, e0 = 0.5, e1 = 1.6,
			a0 = 0.55, t = t, maxSpans = SP.Sheet })
	end
	-- the white-hot spine along the top of the back (Sw[:-4]: the first 32 of 36)
	for m = 1, 8 do
		local i = 1 + floor((m - 1) * 31 / 7 + 0.5)
		local W = Wat(i)
		spineL[m] = toW(B, P36[i] + U36[i] * (0.56 * W * 0.9), keyOf("spine"))
	end
	B.SpineL = spineL
	local fs, wss = scat(B, spineL, keyOf("spine"), 8)
	local spineFade = tell * fs * ly.skel
	if spineFade > 0.004 then
		local wsp = table.create(8)
		for m = 1, 8 do wsp[m] = lerp(0.10, 0.05, (m - 1) / 7) * wss end
		rib(cv, spineL, wsp, "core", { fade = spineFade, glow = 1.2, tail = 0.4, maxSpans = SP.Spine })
	end
	-- the fan tail: 7 feathers, spreading in the turns
	do
		local base = Psp[NS] * 0.6 + Psp[NS - 3] * 0.4
		local spread = 0.5 + 0.5 * min(1, abs(B.OmegaNow))
		local key = keyOf("tail")
		local knots, sides, lens = B.TailK or {}, {}, {}
		local zN = V3(0, 0, 1)
		for i = 1, 7 do
			local a = (-1 + 2 * (i - 1) / 6) * spread
			local tdir = nrm(V3(sin(a), -cos(a), 0.05 + 0.1 * sin(D.ph)))
			local root = base + tdir * 0.2
			local L = 4.2 * (1 - 0.15 * abs(a))
			local Nn = nrm(zN - tdir * zN:Dot(tdir))
			for n, sv in ipairs(FEATHER_S) do
				knots[(i - 1) * 3 + n] = toW(B, root + tdir * (sv * L) + Nn * (sv * sv * 0.12 * L), key)
			end
			sides[i] = toWd(B, tdir:Cross(Nn))
			lens[i] = L
		end
		B.TailK = knots
		local ft, wst = scat(B, knots, key, 21)
		local fade = tell * ft * ly.body
		if fade > 0.004 then
			local wd = 1.0 * k * wst
			for i = 1, 7 do
				rib(cv, { knots[i * 3 - 2], knots[i * 3 - 1], knots[i * 3] },
					{ wd * FEATHER_W[1], wd * FEATHER_W[2], wd * FEATHER_W[3] }, "feather",
					{ side = sides[i], fade = fade, glow = stut, tail = 0.38 + 0.35 * fray, t = t + i * 0.37, maxSpans = SP.Tail })
			end
		end
	end
	-- the head: beak (upper, lower), the eye lines, the crest plumes
	local H = headFeat(B, t, B.Head)
	B.Head = H
	local headParts = { { "beak_u", H.up, 0.4, "glow" }, { "beak_l", H.lo, 0.26, "glow" },
		{ "eye0", H.eyel[1], 0.08, "core" }, { "eye1", H.eyel[2], 0.08, "core" } }
	for _, part in ipairs(headParts) do
		local key = keyOf(part[1])
		local src = part[2]
		local pts, wid = table.create(#src), table.create(#src)
		for i, p in ipairs(src) do
			pts[i] = toW(B, p, key)
			wid[i] = lerp(part[3], part[3] * 0.2, (#src > 1) and (i - 1) / (#src - 1) or 0) * k
		end
		local fh, wsh = scat(B, pts, key, #src)
		local fade = tell * fh * ly.body
		if fade > 0.004 then
			for i = 1, #wid do wid[i] *= wsh end
			rib(cv, pts, wid, part[4], { fade = fade, glow = 1.2, tail = 0.3, maxSpans = SP.Beak })
		end
	end
	do
		local bk = nrm(H.back)
		for kk = 0, 2 do
			local key = keyOf("crest") + kk
			local P = {}
			for i = 1, 12 do
				local sl = (i - 1) / 11
				local wave = 0.28 * sin(TAU * 1.6 * t - 3.0 * sl + kk) * sl
				P[i] = H.crest + bk * ((3.2 + 0.4 * kk) * sl) + ZAX * (0.95 * sl - 0.35 * sl * sl + wave + 0.12 * kk)
					+ XAX * ((kk - 1) * 0.28 * sl)
			end
			local Ps = spline(P, 12, 0.8)
			local pts, wid = table.create(6), table.create(6)
			for m = 1, 6 do
				local i = 1 + floor((m - 1) * 11 / 5 + 0.5)
				local sl = (i - 1) / 11
				pts[m] = toW(B, Ps[i], key)
				wid[m] = (0.42 * (1 - 0.85 * sl) + 0.04) * k
			end
			local fc, wsc = scat(B, pts, key, 6)
			local fade = tell * fc * ly.body
			if fade > 0.004 then
				for m = 1, 6 do wid[m] *= wsc end
				rib(cv, pts, wid, "glow", { fade = fade, alpha = 0.55, glow = 1.1, tail = 0.6, t = t + kk, maxSpans = SP.Crest })
			end
		end
	end

	------------------------------------------------------------------ wingtip vortices (the tip's own recent path)
	local buf = B.TipBuf
	if B.Demo then
		-- the showcase flight: the tips' recent path (bird-local, from the sim) placed by the track's frame at its time,
		-- as Blender re-evaluates the rig along the Track (every second sample: 120 Hz is plenty for 10 knots)
		table.clear(buf)
		local cf0 = B.CF
		for n, e in ipairs(B.TipHist) do
			if n % 2 == 0 and e.T >= t - 0.4 and e.T <= t + 1e-6 then
				local te = (B.TE and e.T >= B.TE) and B.TE or e.T
				B.CF = B.Stage * SHOW.seat(te, B.Own and LOOK.OwnBankShare or 1)
				if B.Own then B.CF -= UP * LOOK.OwnDrop end
				buf[#buf + 1] = { T = e.T, [1] = toW(B, e[1]), [-1] = toW(B, e[-1]) }
			end
		end
		B.CF = cf0
	elseif not B.TE then
		local last = buf[#buf]
		if not last or t > last.T + 1e-4 then                         -- a frame that did not advance adds nothing
			buf[#buf + 1] = { T = t, [1] = B.TipNow[1], [-1] = B.TipNow[-1] }
		end
		while #buf > 2 and buf[1].T < t - 0.4 do table.remove(buf, 1) end
	end
	if B.Form >= 0.5 and (not B.TE or t <= B.TE + 0.3) and #buf >= 3 then
		for _, s in ipairs(SIDES) do
			for kk = 0, 1 do
				local pts, wid = table.create(10), table.create(10)
				local ok = true
				local j = #buf
				for m = 1, 10 do
					local lin = (m - 1) / 9
					local ts = t - 0.32 * lin
					while j > 1 and buf[j].T > ts do j -= 1 end
					local a, b = buf[j], buf[min(j + 1, #buf)]
					local u = (b.T > a.T) and clamp01((ts - a.T) / (b.T - a.T)) or 0
					local p = a[s]:Lerp(b[s], u)
					local hel = V3(cos(30 * ts + 3 * kk), 0, sin(30 * ts + 3 * kk)) * (0.12 + 0.45 * lin)
					pts[m] = p + toWd(B, hel)
					wid[m] = lerp(0.12, 0.03, lin)
					if m > 1 and (pts[m] - pts[m - 1]).Magnitude > 2.5 * 3.2 then ok = false end
				end
				if ok then
					rib(cv, pts, wid, "arc", { fade = 0.75 * tell, alpha = 0.6, glow = 0.95, tail = 0.7, t = t + kk,
						maxSpans = SP.Vortex })
				end
			end
		end
	end

	------------------------------------------------------------------ the light: the wings glow onto the rider and the floor
	do
		local LT = LOOK.Light
		local g = latest(B.Gusts, t)
		local kg = 0
		if g then kg = smooth(t, g.T, g.TS) * (1 - smooth(t, g.TS + 0.1, g.TS + 0.5)) end
		local watts = (LT.Watts + LT.Gust * kg) * tell * ly.body + LT.Hit * D.hitw
		if watts > 1 then
			cvCall(cv, "Light", toW(B, V3(0, 4.0, 0.9)) - UP * LT.Below, watts, { range = LT.Range, flicker = LT.Flicker })
		end
	end

	------------------------------------------------------------------ the summon: wind gathering into the skeleton
	do
		local g = smooth(tb, -0.24, 0.14)
		if g > 0 and g < 1 and B.Skel[1] and B.Skel[-1] then
			local tg = {}
			for _, s in ipairs(SIDES) do
				for _, j in ipairs({ 6, 15, 25, 35 }) do tg[#tg + 1] = B.Skel[s][j] end
			end
			for i = 0, 7 do
				local a0, ph = i * 2.39996, i * 0.7
				local pts, wid = table.create(10), table.create(10)
				for m = 1, 10 do
					local sl = (m - 1) / 9
					local R = (1 - g) ^ 1.2 * (1.0 + 7.5 * sl)
					local ang = a0 + 5.0 * sl + 7.0 * tb
					local z = (1 - g) * (3.0 * sl - 0.6) + 0.4 * sin(ph + 3 * sl)
					pts[m] = tg[i + 1] + V3(R * cos(ang), z, -R * sin(ang))  -- Blender world (x, y, z) -> (x, z, -y)
					wid[m] = lerp(0.06, 0.32, sl) * (1 - 0.4 * g)
				end
				local fade = sin(pi * g) ^ 0.7 * nearFade(B, pts[5])
				if fade > 0.004 then
					rib(cv, pts, wid, "glow", { fade = fade, alpha = 0.6, glow = 1.2, tail = 0.6, t = t + i, maxSpans = SP.Gather })
				end
			end
		end
		if t >= 0 and t < 0.3 then
			burst(cv, "mist", toW(B, V3(0, 1, 0.6)), 10, { id = "summon_mist", dir = B.CF.LookVector, speed = { 4, 8 },
				up = 0.25, cone = 0.6, life = { 0.9, 0.9 }, size = { 0.8, 1.5 } })
		end
	end

	------------------------------------------------------------------ wisps peeling off the feather tips
	FX._wisps(B, cv, t)

	------------------------------------------------------------------ the shed glints and puffs while flying (v5 particles)
	if not B.TE and t > S and B.Form >= 1 then
		local slot = floor(t / 0.12)
		if slot ~= B.ShedSlot then
			B.ShedSlot = slot
			local c = toW(B, EXPLODE_C)
			local jit = V3(gauss(B.Seed, slot, 1) * 1.0, gauss(B.Seed, slot, 3) * 0.5, gauss(B.Seed, slot, 2) * 1.2)
			burst(cv, "puff", c + jit, 1, { id = "shed" .. slot, dir = UP, speed = { 0.3, 0.5 }, life = { 0.6, 1.0 },
				size = { 0.35, 0.7 } })
			for _, s in ipairs(SIDES) do
				if hn(B.Seed, slot, s + 5) < 0.45 and B.TipNow[s] then
					burst(cv, "spark", B.TipNow[s], 1, { id = "tip" .. slot .. "_" .. s, dir = -UP, speed = { 0.4, 0.6 },
						life = { 0.4, 0.8 }, size = { 0.35, 0.6 } })
				end
			end
		end
	end
	-- the rider's hit: puffs and sparks shed off the struck wing
	for _, h in ipairs(B.Hits) do
		if t >= h.T and not h.Burst then
			h.Burst = true
			local Gs = B.Geo[h.S]
			local p = Gs and toW(B, (at(Gs, 0.6))) or toW(B, EXPLODE_C)
			burst(cv, "puff", p, 8, { id = "hit_puff" .. h.T, speed = { 2, 5 }, life = { 0.6, 1.0 } })
			burst(cv, "spark", p, 10, { id = "hit_spark" .. h.T, speed = { 3, 8 }, life = { 0.3, 0.6 } })
		end
	end

	------------------------------------------------------------------ the gust flap
	for _, g in ipairs(B.Gusts) do
		if t >= g.T and t < g.TS + LOOK.Gust.Launch + LOOK.Gust.Life then
			FX._gust(B, cv, t, g)
		end
	end

	-- done: the dismount has played out (the last wisp is ~1 s after the end)
	if B.TE and t > B.TE + 1.6 then return false end
	if B.Demo and t > BL.T_END + 0.2 and not B.Freeze then return false end
	return true
end

----------------------------------------------------------------------------------------------------
-- WISPS (skyrider_v6 wisps / tip): ribbons peeling off the feather tips, keeping a quarter of the tip's velocity,
-- rising 1.1 studs/s and curling at 8 rad/s
----------------------------------------------------------------------------------------------------
--- the dismount's 18: primaries first, then the secondaries, then the coverts (the tips inward)
function FX._wispsEnd(B)
	local TE = B.TE
	local np, ns, nc = #B.Picks.pri, #B.Picks.sec, #B.Picks.cov
	for j = 0, 7 do
		table.insert(B.Wisps, { T = TE + 0.03 * j, S = (j % 2 == 1) and 1 or -1, Tier = "pri", J = (j * 3 + 1) % np + 1,
			Amp = 1.0, Life = LOOK.Wisps.EndLife })
	end
	for j = 0, 5 do
		table.insert(B.Wisps, { T = TE + 0.12 + 0.04 * j, S = (j % 2 == 1) and 1 or -1, Tier = "sec",
			J = (j * 5 + 2) % ns + 1, Amp = 1.0, Life = LOOK.Wisps.EndLife })
	end
	for j = 0, 3 do
		table.insert(B.Wisps, { T = TE + 0.25 + 0.05 * j, S = (j % 2 == 1) and 1 or -1, Tier = "cov",
			J = (j * 7 + 3) % nc + 1, Amp = 0.9, Life = 0.9 })
	end
end

function FX._wisps(B, cv, t)
	-- low mana: a primary-tip wisp every LowEvery / thin, at most LowMax alive (Blender: 5 over the last second)
	local W = LOOK.Wisps
	if not B.TE and B.thin > W.LowFrom and t >= (B.NextLowWisp or 0) then
		local alive = 0
		for _, w in ipairs(B.Wisps) do if t - w.T < w.Life then alive += 1 end end
		if alive < W.LowMax then
			B.LowWispN = (B.LowWispN or 0) + 1
			local kn = B.LowWispN
			table.insert(B.Wisps, { T = t, S = (kn % 2 == 1) and 1 or -1, Tier = "pri", J = (kn * 3) % #B.Picks.pri + 1,
				Amp = 0.7, Life = W.Life })
		end
		B.NextLowWisp = t + W.LowEvery / max(0.3, B.thin)
	end
	local SP = LOOK.Spans
	local keep = {}
	for _, w in ipairs(B.Wisps) do
		local tau = t - w.T
		if tau < w.Life then keep[#keep + 1] = w end
		if tau >= 0 and tau < w.Life then
			if not w.P0 then
				-- captured on its first frame: the tip where it is, and its velocity from the last frame
				local tips = B.FTips[w.S .. w.Tier]
				local prev = B.FTipsPrev[w.S .. w.Tier]
				local p = tips and tips[w.J]
				if not p then continue end
				local q = prev and prev[w.J]
				local dtv = max(1 / 120, (B.FrameDt or 1 / 60))
				w.P0 = p
				w.V = q and (p - q) / dtv or (B.Vel or VZERO)
				if w.V.Magnitude > 120 then w.V = w.V.Unit * 120 end
			end
			local dv = nrm(w.V + V3(0, 1e-3, 0))
			local e1 = dv:Cross(UP)
			e1 = e1.Magnitude > 1e-4 and e1.Unit or Vector3.xAxis
			local e2 = dv:Cross(e1)
			local ph = w.T * 13.0
			local kk = tau / w.Life
			local pts, wid = table.create(8), table.create(8)
			for m = 1, 8 do
				local ts = lerp(max(0, tau - 0.4), tau, (m - 1) / 7)
				local sl = (m - 1) / 7
				pts[m] = w.P0 + w.V * (0.25 * (1 - exp(-ts / 0.25))) + UP * (1.1 * ts)
					+ (e1 * cos(8 * ts + ph) + e2 * sin(8 * ts + ph)) * (0.8 * ts ^ 0.8)
				wid[m] = 0.32 * w.Amp * sin(pi * clamp01(sl * 0.94 + 0.03)) ^ 0.6 * (1 - 0.6 * kk)
			end
			local fade = w.Amp * (1 - kk) ^ 1.3 * smooth(tau, 0, 0.05) * nearFade(B, pts[8])
			if fade > 0.004 then
				rib(cv, pts, wid, "glow", { fade = fade, alpha = 0.55, glow = 1.0, tail = 0.6, t = t + w.T, maxSpans = SP.Wisp })
			end
		end
	end
	B.Wisps = keep
end

----------------------------------------------------------------------------------------------------
-- THE GUST (skyrider_v5 gust(), on this gust's own clock: T = the press, TS = the stroke, TL = the launch)
----------------------------------------------------------------------------------------------------
local function coneFront(tau)
	local GL = LOOK.Gust
	return GL.Reach * (1 - exp(-max(0, tau) / GL.Tau))
end
local function coneTau(d)
	local GL = LOOK.Gust
	return -GL.Tau * log(max(1e-4, 1 - d / GL.Reach))
end
FX.ConeFront, FX.ConeTau = coneFront, coneTau

--- what a floor ray passes through: every player's body and the camera (ZephyrDraw's own carrier Part does not
--- answer queries, as RadiantDraw's: CanQuery off)
local function floorExclude()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list + 1] = p.Character end
	end
	if workspace.CurrentCamera then list[#list + 1] = workspace.CurrentCamera end
	return list
end

local floorParams = nil
local function floorBelow(p, reach, exclude)
	if not floorParams then
		floorParams = RaycastParams.new()
		floorParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	floorParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(p, V3(0, -reach, 0), floorParams)
	return hit and hit.Position.Y or nil
end

function FX._gust(B, cv, t, g)
	local GL = LOOK.Gust
	local SP = LOOK.Spans
	local AX = g.Dir
	local H = math.rad(GL.Half)
	local e1 = AX:Cross(UP)
	e1 = e1.Magnitude > 1e-3 and e1.Unit or B.CF.RightVector
	local e2 = AX:Cross(e1)
	local TS, TL = g.TS, g.TS + GL.Launch
	local tau = t - TL
	local apexNow = toW(B, GL.Apex)                                  -- chest_w(t): the cone's apex (the bird's chest)
	-- the snapshots: the leading edges at the stroke, the apex and the floor at the launch
	if t >= TS and not g.LE then
		g.LE = {}
		for _, s in ipairs(SIDES) do
			local src = B.Skel[s]
			if src then
				local pts = table.create(12)
				for m = 1, 12 do pts[m] = src[1 + floor((m - 1) * 39 / 11 + 0.5)] end
				g.LE[s] = pts
			end
		end
	end
	if t >= TL and not g.A then
		g.A = g.AFix or apexNow                                       -- (the demo knows its launch apex: a frozen frame too)
		local fy = floorBelow(g.A, GL.FloorReach, floorExclude())
		if fy then
			local h = g.A.Y - fy
			local dn = asin(clamp(-AX.Y, -1, 1))
			if h > 0.2 and dn + H > 0.05 then
				local LG = h / sin(dn + H)
				if LG < GL.Reach then
					local lower = nrm(AX * cos(H) - UP * sin(H))
					g.G0 = g.A + lower * LG
					g.G0 = V3(g.G0.X, fy, g.G0.Z)
					if AX.Y < -0.05 then
						local G1 = g.A + AX * (h / -AX.Y)
						g.G1 = V3(G1.X, fy, G1.Z)
					end
					g.Floor = fy
				end
			end
		end
	end
	local A = g.A or apexNow

	-- 1. the wind-up: a bright compression gathers under the wings (a tight open spiral + a core knot)
	local kc = smooth(t, g.T, TS) * (1 - smooth(t, TS, TS + 0.08))
	if kc > 0.01 then
		local cpt = apexNow - UP * 1.2
		for i = 0, 2 do
			local r0 = (2.2 - 1.4 * kc) * (1 + 0.3 * i)
			local a0 = 14 * t + 2.1 * i
			local P = arcPts(cpt, AX, e1, r0, a0, a0 - math.rad(280), 10, 0, r0 * 0.3)
			local Pr = table.create(10)
			for m = 1, 10 do Pr[m] = P[11 - m] end
			local w = (i == 0) and 0.08 or 0.4 * (1 - 0.2 * i)
			rib(cv, Pr, w, (i == 0) and "core" or "glow", { fade = kc, glow = 1.0 + 0.8 * kc, alpha = 0.6, tail = 0.5,
				maxSpans = SP.Comp })
		end
	end
	-- the view kick on your own stroke (skyrider_v5 FP: FOV 70 + 9 x the kick, a small roll)
	if B.Own and t >= TS + 0.02 and not g.Kicked then
		g.Kicked = true
		local C = LOOK.Cam
		zdCall("CameraKick", { fov = C.GustFov, roll = C.GustRoll, decay = C.GustDecay })
	end

	-- 2. the power stroke: a pressure crest peels off each wing and drives forward into the cone
	local u = t - TS
	if u > 0 and u < 0.35 and g.LE then
		local d = coneFront(max(0, u - 0.03)) * 0.8
		local spreadc = 1.0 + 0.08 * d
		for _, s in ipairs(SIDES) do
			local LEw = g.LE[s]
			if LEw then
				local P = table.create(#LEw)
				for m, p in ipairs(LEw) do P[m] = A + (p - A) * spreadc + AX * d end
				for j = 0, 1 do
					rib(cv, P, ((j == 0) and 0.12 or 0.9) * (1 - u / 0.35) + 0.03, (j == 0) and "core" or "glow",
						{ fade = 1 - u / 0.35, glow = 1.4, alpha = 0.65, tail = 0.5, maxSpans = SP.Crest_P })
				end
			end
		end
	end
	if tau <= 0 then return end

	-- 3. the cone: nested expanding pointed arcs (wavefronts), streamlines, vortex threads, a vapor edge
	for i = 0, GL.Fronts - 1 do
		local ti = tau - 0.05 * i
		local d = coneFront(max(ti, 0)) * (1 - 0.06 * i)
		local fd = smooth(ti, 0.0, 0.04) * (1 - smooth(ti, 0.35, 0.75))
		if fd > 0.01 then
			local R_ = max(0.5, d * tan(H))
			for j = 0, GL.Arcs - 1 do
				local a0 = j * 2.094 + 0.6 * i + 2.0 * ti
				local P = arcPts(A + AX * d, AX, e1, R_, a0, a0 + math.rad(95), 8)
				local wid = table.create(8)
				for m = 1, 8 do
					local x = (m - 1) / 7
					P[m] += AX * (sin(pi * x) * 0.12 * R_)                   -- bowed forward
					wid[m] = 0.22 * (1 - 0.1 * i) * sin(lerp(0.1, 3.04, x)) ^ 0.6 + 0.02
				end
				rib(cv, P, wid, "arc", { fade = fd, glow = 1.2, alpha = 0.7, tail = 0.5, t = t + i, maxSpans = SP.Front })
			end
		end
	end
	local fc = smooth(tau, 0.0, 0.05) * (1 - smooth(tau, 0.5, 1.2))
	local d1 = coneFront(max(tau, 0.0))
	if fc > 0.01 then
		for i = 0, GL.Streams - 1 do                                     -- streamlines fanning from each wing
			local a = (i % 4) * 0.35 - 0.5 + ((i < 4) and 0 or pi)
			local dirv = nrm(AX * cos(H * 0.8) + (e1 * cos(a) + e2 * sin(a)) * sin(H * 0.8))
			local head, tailP = A + dirv * d1, A + dirv * (d1 * 0.15)
			rib(cv, { head, (head + tailP) * 0.5, tailP }, { 0.05, 0.2, 0.35 }, "glow",
				{ fade = fc * 0.8, alpha = 0.5, glow = 1.0, tail = 0.6, t = t + i, maxSpans = SP.Stream })
		end
		for i = 0, GL.Threads - 1 do                                     -- spiral vortex threads through the cone
			local P = table.create(16)
			for m = 1, 16 do
				local sl = 1 - (m - 1) / 15
				local dd = d1 * sl
				local ang = i * pi + 9 * sl - 6 * tau
				local r = dd * tan(H) * 0.55
				P[m] = A + AX * dd + e1 * (r * cos(ang)) + e2 * (r * sin(ang))
			end
			rib(cv, P, 0.08, "arc", { fade = fc * 0.8, alpha = 0.6, glow = 1.0, tail = 0.6, maxSpans = SP.Thread })
		end
	end
	local fv = smooth(tau, 0.0, 0.06) * (1 - smooth(tau, 0.6, 1.6))
	if fv > 0.01 then
		for i = 0, GL.Edges - 1 do                                       -- the soft vapor edge (drifts on, thinning)
			local a = i * pi / 3 + 0.3
			local dirv = nrm(AX * cos(H) + (e1 * cos(a) + e2 * sin(a)) * sin(H))
			local lift = UP * (0.6 * max(0, tau - 0.5))
			local P = { A + dirv * d1 + lift, A + dirv * (d1 * 0.5) + lift, A + lift }
			rib(cv, P, { 1.9, 1.1, 0.3 }, "vapor", { fade = fv * 0.7, alpha = 0.4, tail = 0.7, maxSpans = SP.Edge })
		end
	end
	-- 4. the world: parallel trench lines fanned across the floor, revealed with the front; the dust fan and chips
	if g.G0 and tau >= 0.05 then
		local axh = V3(AX.X, 0, AX.Z)
		axh = axh.Magnitude > 1e-3 and axh.Unit or B.CF.LookVector
		local side = UP:Cross(axh)
		local reach = clamp(d1 * cos(H) - (g.G0 - A):Dot(AX), 0, 22)
		local fade = 1 - smooth(t, TL + 1.66, TL + 3.16)
		if reach > 0.2 and fade > 0.004 then
			for i = 0, GL.Trenches - 1 do
				local o = g.G0 + side * ((i - 2) * 1.4) + UP * 0.03
				local dir = axh + side * ((i - 2) * 0.08)
				rib(cv, { o + dir * reach, o + dir * (reach * 0.5), o }, 0.55, "scuff",
					{ side = side, fade = fade, glow = 0.7, tail = 0.2, maxSpans = SP.Trench })
			end
		end
		-- the dust fan swept flat across the floor and the chips skittering ahead, as the front passes each spot
		local G1 = g.G1 or g.G0 + axh * 8
		for m = 1, 6 do
			local f = 0.08 + 0.16 * (m - 1)
			local p = g.G0:Lerp(G1, f) + UP * 0.15
			local tp = coneTau(max(0.5, (p + UP * 2.6 - A):Dot(AX)))
			if tau >= tp then
				burst(cv, "dust", p, 10, { id = "gdust" .. g.T .. "_" .. m, dir = axh, speed = { 10, 18 }, cone = 0.35,
					up = 0.05, life = { 0.8, 1.4 }, size = { 0.8, 1.6 } })
				if m >= 2 then
					burst(cv, "chip", p, 4, { id = "gchip" .. g.T .. "_" .. m, dir = axh + UP * 0.2, speed = { 12, 20 },
						cone = 0.3, life = { 0.6, 1.0 }, size = { 0.6, 1.1 } })
				end
			end
		end
	end
	-- 5. the hits: a pressure ring at each body the front reached, a bloom of pointed arcs on the first
	for n, h in ipairs(g.Hits) do
		local uh = span(t, h.T, h.T + 0.45)
		if uh > 0 and uh < 1 then
			cvCall(cv, "RingK", h.At - AX * 0.8, 0.6 + 1.8 * easeOut(uh), AX, 0.5 * (1 - uh) + 0.08, "vapor",
				{ fade = (1 - uh) * 0.7, alpha = 0.55, glow = 1.2 })
		end
		if t >= h.T and not h.Burst then
			h.Burst = true
			burst(cv, "spark", h.At, 14, { id = "hspark" .. h.T .. n, speed = { 5, 14 }, life = { 0.25, 0.6 } })
			burst(cv, "puff", h.At, 6, { id = "hpuff" .. h.T .. n, speed = { 2, 6 }, life = { 0.5, 0.9 } })
			burst(cv, "dust", h.At - UP * 2.5, 10, { id = "hdust" .. h.T .. n, speed = { 4, 9 }, up = 0.05,
				life = { 0.6, 1.1 } })
		end
		if n == 1 then
			local ub = span(t, h.T - 0.02, h.T + 0.35)
			if ub > 0 and ub < 1 then FX._bloom(B, cv, t, h.At, AX, sin(pi * ub), 0.9 + 0.6 * ub, 1.5) end
		end
	end
	-- the recovery: a few feathers fall away from the tips as glints
	if u > 0.05 and u < 0.7 then
		local slot = floor((u - 0.05) / 0.08)
		for _, s in ipairs(SIDES) do
			local tip = B.TipNow[s]
			if tip then
				burst(cv, "spark", tip, 1, { id = "rec" .. g.T .. "_" .. slot .. "_" .. s, dir = -UP, speed = { 0.8, 1.2 },
					life = { 0.6, 0.6 }, size = { 0.5, 0.5 } })
			end
		end
	end
end

--- za.Arcs (8, seed 71, r 1.4-2.4, span 80-160 deg, w 0.08-0.25, speed 6-10, tilt 0.4): pointed arcs orbiting a centre
--- on varied planes, thick-to-thin; the parameters are hashed (same statistics, not Blender's draws)
function FX._bloom(B, cv, t, centre, axis, fade, scale, speedMul)
	if fade <= 0.003 then return end
	if type(cv.Arcs) == "function" then                             -- ZephyrDraw's own za.Arcs
		cvCall(cv, "Arcs", t, centre, axis, { n = 8, seed = 71, r = { 1.4, 2.4 }, span = { 80, 160 }, w = { 0.08, 0.25 },
			speed = { 6, 10 }, tilt = 0.4, fade = fade, scale = scale, speed_mul = speedMul, maxSpans = LOOK.Spans.Bloom })
		return
	end
	local ax = nrm(axis)
	local b0 = ax:Cross(abs(ax.Y) < 0.9 and UP or Vector3.xAxis).Unit
	local b1 = ax:Cross(b0)
	for i = 1, 8 do
		local r = lerp(1.4, 2.4, hn(71, i, 1))
		local spanA = math.rad(lerp(80, 160, hn(71, i, 2)))
		local w = lerp(0.08, 0.25, hn(71, i, 3)) * ((hn(71, i, 4) < 0.33) and 1.7 or 1.0)
		local spd = lerp(6, 10, hn(71, i, 5))
		local ph = TAU * hn(71, i, 6)
		local n_ = nrm(ax + b0 * (gauss(71, i, 7) * 0.4) + b1 * (gauss(71, i, 8) * 0.4))
		local d0 = n_:Cross(abs(n_.Y) < 0.9 and UP or Vector3.xAxis).Unit
		local d1 = n_:Cross(d0)
		local rise = lerp(-0.25, 0.25, hn(71, i, 9))
		local glow = lerp(0.7, 1.5, hn(71, i, 10))
		local alpha = lerp(0.35, 0.8, hn(71, i, 11))
		local fl = 0.75 + 0.25 * sin(t * 9.0 + TAU * hn(71, i, 12))
		local a0 = ph + spd * speedMul * t
		local R = r * scale
		local pts, wid = table.create(6), table.create(6)
		for m = 1, 6 do
			local s = (m - 1) / 5
			local ang = a0 - spanA * s                                    -- the head leads, the tail trails behind
			pts[m] = centre + (d0 * cos(ang) + d1 * sin(ang)) * R + n_ * (s * rise * R)
			wid[m] = w * scale * sin(pi * clamp01(s * 0.92 + 0.04)) ^ 0.7 * (1 - 0.65 * s)
		end
		rib(cv, pts, wid, "arc", { fade = fade * fl, glow = glow, alpha = alpha, tail = 0.55, maxSpans = LOOK.Spans.Bloom })
	end
end

----------------------------------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------------------------------
local function newBird(character, opts)
	opts = opts or {}
	local picks = {
		cov = pickIdx(#COV_B, LOOK.Feathers.cov), sec = pickIdx(#SEC_B, LOOK.Feathers.sec),
		pri = pickIdx(#PRI_L, LOOK.Feathers.pri),
	}
	local S = tonumber(opts.SummonTime) or DRV.SummonTime
	local scale = LOOK.Scale * ((opts.Own and LOOK.OwnScale) or 1)
	local B = {
		Character = character, Own = opts.Own == true, Demo = opts.Demo == true, Freeze = opts.Freeze,
		T0 = opts.T0, SummonTime = S, WindUp = tonumber(opts.WindUp) or DRV.WindUp,
		SeatBelow = tonumber(opts.SeatBelowRoot) or LOOK.SeatBelowRoot,
		Scale = scale, KB = RIG.BS * scale,
		Seed = keyOf(character and character.Name or "demo") * 13.7 + 1.3,
		Gusts = {}, Hits = {}, Wisps = {}, DemoHits = {},
		Strokes = { { T = S + 0.06, K = 0.30 } },                   -- the catch's keyed stroke rippling down the back
		CatchA = S - 0.14, CatchB = S + 0.36,                     -- head_rot / gape: the catch's nod (Blender 0.30..0.80)
		D = { w = 0, A = RIG.Amp, ph = 0, bank = 0, hitw = 0, struck = 1, k1 = 0, k2 = 0, thin = 0 },
		PHI = BL.PHI_AT_062 - TAU * (1 / DRV.CruisePeriod) * (S + 0.18),
		Omega = 0, OmegaNow = 0, OmegaLead = 0, Speed = 0, Pitch = 0, Bank = 0, thin = 0, ThinRaw = 0,
		Ly = {}, Geo = {}, Feath = {}, Knots = {}, FTips = {}, FTipsPrev = {}, MemP = {}, Spine = {}, TipBuf = {}, TipHist = {},
		Head = {}, Picks = picks, Form = 0,
	}
	if B.Demo then
		B.PHI = BL.PHI_AT_062 + TAU * 1.12 * (-0.6 - 0.62)        -- Track's phase at the sim's start (-0.6)
		B.DemoHits = { { T = BL.T_HIT, S = 1 } }
		B.Strokes = { { T = 0.50, K = 0.30 }, { T = 3.36, K = 0.42 } }
		B.CatchA, B.CatchB = 0.30, 0.80
	end
	return B
end

--- frame_fn wrapper: the draw's own errors end only this bird (the driver warns once)
local function play(B, name, clockOpts)
	local ZD = getZD()
	if not ZD then return nil end
	local fn = function(cv, t, dt)
		B.FrameDt = dt
		return drawBird(B, cv, t)
	end
	local ok, handle
	if B.Freeze and type(ZD.Demo) == "function" then
		ok, handle = pcall(ZD.Demo, name, fn, { Freeze = B.Freeze, Budget = "Skyrider", Own = B.Own })
	else
		clockOpts.Budget, clockOpts.Own = "Skyrider", B.Own          -- the plan's 420 Beams / 1 light; your own density
		ok, handle = pcall(ZD.Play, name, fn, clockOpts)
	end
	if not ok then
		warnOnce("play", "ZephyrDraw " .. (B.Freeze and "Demo" or "Play") .. " failed: " .. tostring(handle))
		return nil
	end
	B.Handle = handle
	return handle
end

--- A bird under `character`, from opts.T0 (server time of the press). Replaces one already there.
function FX.Start(character, opts)
	if typeof(character) ~= "Instance" then return nil end
	opts = opts or {}
	local old = birds[character]
	if old and old.Handle then pcall(function() old.Handle:Stop() end) end
	local T0 = tonumber(opts.T0) or workspace:GetServerTimeNow()
	opts.T0 = T0
	local B = newBird(character, opts)
	birds[character] = B
	play(B, "Skyrider", { T0 = T0, Scale = 1, MaxLife = 40, Prewarm = { Spans = 260, Lights = 1 },
		OnEnd = function() if birds[character] == B then birds[character] = nil end end })
	return B
end

function FX.Get(character)
	return birds[character]
end

--- clip seconds of a server time on this bird's clock
local function clipOf(B, T0)
	local t = tonumber(T0)
	if not t then return nil end
	return t - B.T0
end

--- the gust flap: the wind-up from T0 (server time), the stroke WindUp later, the cone along `dir`
function FX.Gust(character, T0, dir)
	local B = birds[character]
	if not B or typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3 then return end
	local t = clipOf(B, T0) or (workspace:GetServerTimeNow() - B.T0)
	for _, g in ipairs(B.Gusts) do
		if abs(g.T - t) < 0.5 then return end                       -- already drawing it (your own, predicted)
	end
	local g = { T = t, TS = t + B.WindUp, Dir = dir.Unit, Hits = {} }
	table.insert(B.Gusts, g)
	table.insert(B.Strokes, { T = g.TS + 0.06, K = 0.42 })
	while #B.Gusts > 3 do table.remove(B.Gusts, 1) end
	while #B.Strokes > 4 do table.remove(B.Strokes, 1) end
end

--- one body the gust reached: its pressure ring (and the bloom, on the first)
function FX.GustHit(character, victim, at, T0)
	local B = birds[character]
	if not B or typeof(at) ~= "Vector3" then return end
	local t = clipOf(B, T0) or (workspace:GetServerTimeNow() - B.T0)
	local g = latest(B.Gusts, t)
	if not g then return end
	table.insert(g.Hits, { T = t, At = at, Victim = victim })
end

--- the rider was hurt: the wobble (the struck wing is the side `at` is on)
function FX.Hit(character, at, T0)
	local B = birds[character]
	if not B or B.TE then return end
	local t = clipOf(B, T0) or (workspace:GetServerTimeNow() - B.T0)
	local s = 1
	if typeof(at) == "Vector3" and B.CF then
		s = (B.CF.RightVector:Dot(at - B.CF.Position) >= 0) and 1 or -1
	end
	table.insert(B.Hits, { T = t, S = s })
	while #B.Hits > 4 do table.remove(B.Hits, 1) end
	if B.Own then
		local C = LOOK.Cam
		zdCall("CameraKick", { roll = C.HitRoll * s, shake = C.HitShake, decay = C.HitDecay })
	end
end

--- the dismount at T0 (server time): the bird breaks from the tips inward and scatters into wisps
function FX._endBird(B, t, reason)
	if B.TE then return end
	B.TE = t
	B.EndReason = reason
end
function FX.End(character, T0, reason)
	local B = birds[character]
	if not B then return end
	local t = clipOf(B, T0) or (workspace:GetServerTimeNow() - B.T0)
	FX._endBird(B, max(t, 0), reason)
end

--- gone at once
function FX.Stop(character)
	local B = birds[character]
	if not B then return end
	birds[character] = nil
	if B.Handle then pcall(function() B.Handle:Stop() end) end
end

--- (diagnostics; pure maths, nothing drawn or created) the demo's rig at clip t on the Blender timeline: the right
--- wing's 13 DOF, both tips (bird-local), the left wing's DOF -- what the port was checked against skyrider_v6's WingSim
function FX._Probe(t)
	local B = newBird(nil, { Demo = true })
	simStep(B, t, 1e6)
	local qR, qL = B.Sim.Q[1], B.Sim.Q[-1]
	local _, _, _, tipR = rig(qR, 1)
	local _, _, _, tipL = rig(qL, -1)
	return table.clone(qR), tipR, tipL, table.clone(qL)
end

--- (diagnostics; nothing is created) a LIVE bird that is not played: draw it yourself, FX._Draw(B, cv, t), with clip
--- times from opts.T0 (default 0); `character` may be any table answering Parent / FindFirstChild / GetAttribute.
--- Gust / GustHit / Hit / End then work on it by that same key.
function FX._NewBird(character, opts)
	opts = opts or {}
	local B = newBird(character, opts)
	B.T0 = tonumber(opts.T0) or 0
	birds[character] = B
	return B
end
function FX._Draw(B, cv, t)
	B.FrameDt = 1 / 60
	return drawBird(B, cv, t)
end

--- the cone's apex at the showcase launch (the drawn chest, scaled with the bird) on a demo bird's stage
function SHOW.apex(B)
	local cf0, form0 = B.CF, B.Form
	B.CF = B.Stage * SHOW.seat(BL.TS + LOOK.Gust.Launch, B.Own and LOOK.OwnBankShare or 1)
	if B.Own then B.CF -= UP * LOOK.OwnDrop end
	B.Form = 1
	local a = toW(B, LOOK.Gust.Apex)
	B.CF, B.Form = cf0, form0
	return a
end

--- (diagnostics; nothing is created) the whole demo frame at each clip time in `times`, drawn into `cv` -- any table
--- with the canvas methods (Ribbon, Sheet, RingK, Burst, Light): a counting mock checks the draw path and the budget
--- without ZephyrDraw or Play. The bird flies the showcase flight from the stage `at` (a CFrame at floor level, default
--- the origin) and flaps its gust at `target` (default the showcase's first dummy mark, D1's chest).
function FX._DryRun(times, cv, at, target)
	SHOW.build()
	local B = newBird(nil, { Demo = true, Freeze = true })
	B.T0, B.Stage = 0, at or CFrame.new()
	local apex = SHOW.apex(B)
	local tgt = target or B.Stage:PointToWorldSpace(SHOW.D1 + UP * 2.6)
	local dir = nrm(tgt - apex)
	B.Gusts = { { T = BL.TWU, TS = BL.TS, Dir = dir, AFix = apex, Hits = {
		{ T = BL.TS + LOOK.Gust.Launch + coneTau(max(0.5, (tgt - apex):Dot(dir) - 0.9)), At = tgt } } } }
	B.WindUp = BL.TS - BL.TWU
	B.Hits = { { T = BL.T_HIT, S = 1 } }
	B.TE = BL.T_ZERO
	local out = {}
	for _, t in ipairs(times) do
		B.FrameDt = 1 / 60
		out[#out + 1] = drawBird(B, cv, t)
	end
	return out, B
end

----------------------------------------------------------------------------------------------------
-- DEMO (the test harness): THE SHOWCASE, 1:1. The character rides the bird along skyrider_bl's flight -- the hop onto
-- the swooping bird, the kneel, the banked S, the climb, the gust flap at the dummies, the peel-off, the hit wobble,
-- low mana, the dismount and the fall -- with its CastPose clips (and, in first person, its Viewmodel clips) on the
-- same clock, and (third person) the reel's hero camera. Nothing is sent to the server; the body is anchored and
-- placed every frame, and put back where it stood at the end.
----------------------------------------------------------------------------------------------------
local function sibling(name)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild(name)
	if not m then return nil end
	local ok, mod = pcall(require, m)
	return (ok and type(mod) == "table") and mod or nil
end

--- every training dummy's root (a Humanoid model that is no player's)
local function dummyRoots(except)
	local out = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Humanoid") and d.Parent and d.Parent ~= except and not Players:GetPlayerFromCharacter(d.Parent) then
			local m = d.Parent
			local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
			if r and r:IsA("BasePart") and (m:GetAttribute("TrainingDummy") or m.Name:lower():find("dummy")) then
				out[#out + 1] = r
			end
		end
	end
	return out
end

--- opts: Freeze = clip seconds (hold that one frame: 0 summon .. 3.36 stroke .. 4.78 wobble .. 5.83 low mana .. 6.41
--- dismount); Reel = false plays it at an even speed (default: the reel's own ramp, the summon at 1/2 and the gust flap
--- at 1/4, x IceMagic's ShotTimeScale); Camera = false keeps your camera (default: the reel's hero camera, third
--- person only); AtDummy = false flies from where you stand (default: from where the nearest dummy ahead stands on the
--- showcase's first dummy mark, when the floor is there); FirstPerson (default: your CameraMode) rides in your own
--- eyes: the own-view bird and the Viewmodel clips. -> { Stop, Bird }
function FX.Demo(character, opts)
	opts = opts or {}
	if SHOW.Up then SHOW.Up.Stop() end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then return nil end
	SHOW.build()
	local freeze = tonumber(opts.Freeze)
	local lp = Players.LocalPlayer
	local fp = opts.FirstPerson
	if fp == nil then fp = lp ~= nil and lp.CameraMode == Enum.CameraMode.LockFirstPerson end
	local bankShare = fp and LOOK.OwnBankShare or 1

	-- the stage: your floor and facing, or the dummy-aligned one
	local start = root.CFrame
	local lv = V3(start.LookVector.X, 0, start.LookVector.Z)
	lv = lv.Magnitude > 1e-3 and lv.Unit or V3(0, 0, -1)
	local yaw = CFrame.lookAt(VZERO, lv)
	local excl = floorExclude()
	local fy = floorBelow(root.Position, 40, excl) or (root.Position.Y - 3)
	local h0 = clamp(root.Position.Y - fy, 2, 4)                     -- the root over the floor, standing
	local stage = CFrame.new(root.Position.X, fy, root.Position.Z) * yaw
	local roots = dummyRoots(character)
	if opts.AtDummy ~= false then
		local best, bestD = nil, 150
		for _, r in ipairs(roots) do
			local off = r.Position - root.Position
			if off.Magnitude < bestD and off:Dot(lv) > 0 then best, bestD = r, off.Magnitude end
		end
		if best then
			local ex = table.clone(excl)
			ex[#ex + 1] = best.Parent
			local dfy = floorBelow(best.Position, 40, ex)
			if dfy then
				local d1 = yaw:VectorToWorldSpace(SHOW.D1)
				local o = V3(best.Position.X - d1.X, dfy, best.Position.Z - d1.Z)
				local ofy = floorBelow(o + UP * 25, 60, ex)
				if ofy and abs(ofy - dfy) < 4 then stage = CFrame.new(o.X, ofy, o.Z) * yaw end
			end
		end
	end

	-- the bird on that flight; the gust at the showcase's beats, aimed where the showcase aimed (D1's chest), hitting
	-- every dummy its cone reaches
	local B = newBird(nil, { Demo = true, Freeze = freeze, Own = fp })
	B.T0, B.Stage = 0, stage
	local GL = LOOK.Gust
	local apex = SHOW.apex(B)
	local dir = nrm(stage:PointToWorldSpace(SHOW.D1 + UP * 2.6) - apex)
	local g = { T = BL.TWU, TS = BL.TS, Dir = dir, Hits = {}, AFix = apex }
	local tanH = tan(math.rad(GL.Half))
	for _, r in ipairs(roots) do
		local off = r.Position - apex
		local along = off:Dot(dir)
		if along > 0.5 and along < GL.Reach - 0.5 and (off - dir * along).Magnitude < tanH * along + 1.5 then
			g.Hits[#g.Hits + 1] = { T = BL.TS + GL.Launch + coneTau(max(0.5, along - 0.9)), At = r.Position }
		end
	end
	B.Gusts, B.WindUp = { g }, BL.TS - BL.TWU
	B.Hits, B.TE = { { T = BL.T_HIT, S = 1 } }, BL.T_ZERO

	-- the clock every part reads: the reel's speed ramp x ShotTimeScale, from the reel's first frame (-0.20)
	local clk = { t = SHOW.SEG[1][1], last = os.clock() }
	local reel = opts.Reel ~= false
	local function clock()
		if freeze then return freeze end
		local now = os.clock()
		local dt = min(now - clk.last, 0.1)
		clk.last = now
		if dt > 0 then
			local ZD = getZD()
			local sc = (ZD and type(ZD.TimeScale) == "function" and ZD.TimeScale()) or 1
			clk.t += dt * sc * (reel and SHOW.speed(clk.t) or 1)
		end
		return clk.t
	end

	-- the body: the CastPose clips on the clock (the Viewmodel's too in first person), the root placed every frame
	local CP, VM = sibling("CastPose"), fp and sibling("Viewmodel") or nil
	local saved = { Anchored = root.Anchored, PS = hum.PlatformStand }
	local cam = workspace.CurrentCamera
	local drive = cam ~= nil and not fp and opts.Camera ~= false
	if drive then saved.CamType, saved.Fov = cam.CameraType, cam.FieldOfView end
	local seatBelow = LOOK.SeatBelowRoot
	local clip = nil
	local function pose(name, t0)
		if clip == name then return end
		clip = name
		local c = function() return clock() - t0 end
		if CP and type(CP.PlayClocked) == "function" then
			if CP.Clips and CP.Clips[name] then pcall(CP.PlayClocked, character, name, c) else pcall(CP.Stop, character) end
		end
		if VM then
			if VM.Clips and VM.Clips[name] then pcall(VM.Play, name, c) else pcall(VM.Stop) end
		end
	end
	--- the root at t (stage): standing, the hop (world_info), into the kneel on the seat (T_X0..T_X1), the ride, the
	--- fall (fall_root, righting itself over 0.42 s, the tumble, the landing)
	local function riderCF(t)
		local TZ = BL.T_ZERO
		if t >= TZ then
			local tau = t - TZ
			local up = ease(span(tau, 0, 0.42))
			local tumble = 0.22 * ease(span(tau, 0.15, 0.6)) * (1 - ease(span(t, SHOW.T_LAND - 0.1, SHOW.T_LAND + 0.2)))
			local R = SHOW.seat(TZ, bankShare).Rotation:Lerp(Ry(SHOW.PSI0), up) * Rx(tumble)
			return CFrame.new(SHOW.fall(t) + R.UpVector * lerp(seatBelow, h0, up)) * R
		end
		local ride = SHOW.seat(t, bankShare) * CFrame.new(0, seatBelow, 0)
		if t >= SHOW.T_X1 then return ride end
		local tau = t - SHOW.T_JUMP
		local z = tau > 0 and max(0, SHOW.JUMP_V * tau - 0.5 * SHOW.G * tau * tau) or 0
		local hop = CFrame.new(0, h0 + z, -SHOW.CATCH_Y * ease(span(t, SHOW.T_JUMP, SHOW.T_CATCH)))
		if t < SHOW.T_X0 then return hop end
		return hop:Lerp(ride, ease(span(t, SHOW.T_X0, SHOW.T_X1)))
	end

	local handle
	local done = false
	local function finish()
		if done then return end
		done = true
		pcall(function() RunService:UnbindFromRenderStep(SHOW.STEP) end)
		if B.Handle then pcall(function() B.Handle:Stop() end) end
		if CP then
			local ok, cur = pcall(CP.CurrentClip, character)
			if ok and type(cur) == "string" and cur:sub(1, 8) == "Skyrider" then pcall(CP.Stop, character) end
		end
		if VM then
			local ok, cur = pcall(VM.CurrentClip)
			if ok and type(cur) == "string" and cur:sub(1, 8) == "Skyrider" then pcall(VM.Stop) end
		end
		if root.Parent then
			root.Anchored = saved.Anchored
			hum.PlatformStand = saved.PS
			root.CFrame = start
			root.AssemblyLinearVelocity = VZERO
		end
		if drive then
			cam.CameraType = saved.CamType
			cam.FieldOfView = saved.Fov
		end
		if SHOW.Up == handle then SHOW.Up = nil end
	end
	handle = { Stop = finish, Bird = B }
	SHOW.Up = handle

	local function step()
		local t = clock()
		if t >= BL.T_ZERO then pose("SkyriderFall", BL.T_ZERO)
		elseif t >= BL.T_HIT then pose("SkyriderWobble", BL.T_HIT)
		elseif t >= BL.TWU then pose("SkyriderGust", BL.TWU)
		elseif t >= 0 then pose("SkyriderMount", 0) end
		local tc = min(t, BL.T_END)
		if root.Parent then root.CFrame = stage * riderCF(tc) end
		if drive then
			local p, l, fov = SHOW.cam(tc)
			local cf = CFrame.lookAt(stage:PointToWorldSpace(p), stage:PointToWorldSpace(l))
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame, cam.Focus, cam.FieldOfView = cf, cf, fov
		end
		if not freeze and t > BL.T_END + 0.6 then finish() end
	end

	root.Anchored, hum.PlatformStand = true, true
	play(B, "SkyriderDemo", { Clock = clock, Until = BL.T_END + 0.3, MaxLife = 60 })
	-- after the camera scripts and FirstPersonController's facing (Camera + 2): this frame's body and view are ours
	local okBind, err = pcall(function()
		RunService:BindToRenderStep(SHOW.STEP, Enum.RenderPriority.Camera.Value + 5, function()
			local ok, e = pcall(step)
			if not ok then
				warnOnce("demostep", "the demo's step failed: " .. tostring(e))
				finish()
			end
		end)
	end)
	if not okBind then
		warnOnce("demobind", "the demo could not bind: " .. tostring(err))
		finish()
		return nil
	end
	pcall(step)
	return handle
end

--- (diagnostics) the showcase flight's tables and functions (SHOW.build() first)
FX._Show = SHOW

--- the harness's stop: whatever showcase is up
function FX.StopDemo()
	if SHOW.Up then SHOW.Up.Stop() end
end

return FX
