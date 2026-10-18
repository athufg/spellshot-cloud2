--[[
	PyroFlame_Ring  (ReplicatedStorage.IceMagic.PyroFlame_Ring, ModuleScript, CLIENT)          Pyro Phase 3, 2026-10-05

	RING OF FIRE (Pyro's Ultimate) in the "flame" look: the owner-confirmed Blender design ring_of_fire_r2.py (spread
	variant A, the WILDFIRE) drawn with PyroDraw from the Phase 3 mesh library. Flames only. No mechanics: this module
	never requires PyroHandler and changes no gameplay number; every beat is read from PyroFX.Tuning.RingOfFire
	(DrawTime, SettleTime, SnapBeat, EruptHold, EruptSink, SteerEase, LockLead, Radius, HotReach), so the 17.5 / 21
	change needs no edit here. Everything visual-only is in PyroFlame_Ring.Visual (below).

	Inert at require (services only): PyroDraw, PyroFX, Viewmodel and SpellshotSettings are required lazily, the way
	PyroFX's own libs() does, so PyroFX may require this from a function without a cycle.

	PUBLIC API, 1:1 with the PyroFX functions it stands in for (same parameters, same callbacks):
	  Ring.RingOfFire(character, center, radius, hot, serverT0, startAngle, onDraw) -> ring record | nil
	        = PyroFX.RingOfFire. Registers { Center, Target, LockAt, Locked } (the live record's four fields; + Handle,
	        the PyroDraw.Play handle) for `character`; onDraw(point) every frame of the draw, then onDraw(nil) ONCE when
	        the circle closes (also if the effect is ended early). Real time, like the live one. It returns the record
	        (the live function returns nothing) so the caller can hang IGNITE! on record.Center; nil = the flame meshes
	        are not in the place and NOTHING was started (fall back to the toon draw).
	  Ring.SteerRing(character, point, exact)      = PyroFX.SteerRing
	  Ring.LockRing(character, point)              = PyroFX.LockRing
	  Ring.RingSteerable(character) -> boolean     = PyroFX.RingSteerable
	  Ring.Bind({ Rings = <PyroFX's `rings` table>, PyroFX = PyroFX, Viewmodel = ..., PyroDraw = ... })   all optional.
	        With Rings bound BOTH looks share one registry, so PyroFX's own SteerRing / LockRing / RingSteerable work
	        for a flame ring unchanged (and these three here act on the same table). Unbound, this module keeps its own.
	  Ring.Ready() -> boolean                      the PF_ meshes this effect needs are in the mesh folder
	  Ring.Visual                                  the look's numbers (visual only)

	NOT DRAWN HERE (stays in PyroFX, live code): the comic word IGNITE! (mesh RingOfFireIgnite, PyroFX 1254-1273).
	See the integrator notes returned with this file.

	THE TIMELINE (tr = seconds after the press, tp = seconds after the snap; the snap = DrawTime + SettleTime + SnapBeat)
	  tr 0 .. DrawTime     the line is drawn ONE way round from startAngle (RingDrawPoint), a head flame racing on it
	  DrawTime             the circle closes: the line pulses 45 % taller, a ring of sparks
	  .. the snap          the settle and the wind-up: the hand flame grows, the line ducks 22 %
	  tp 0                 THE ERUPTION: the tower (44 x 6 studs at radius 17.5) is up in 0.15 s; the first front (46
	                       runner flames on a front that is not a circle) reaches the line 0.10 - 0.24 s later
	  tp 0.05 .. 0.9       10 crescent walls of flame roll out one after another, 16 spires shoot up and fall back,
	                       the floor burns low and patchy (28 % of it catches late)
	  EruptHold .. + Sink  the tower, walls and spires SINK (they shrink, never fade); the floor sinks unevenly
	  ~1.0 .. BurnDown     the floor and the line die back patch by patch, the tower's footprint last

	PARTS AND THINNING. One PyroDraw canvas (cap = PyroDraw.Config.MaxParts x density: 260 / 195 / 117 at Graphics
	3-4 / 2 / 1, x 0.6 for other players' rings under ThinEnemyVFX: PyroDraw.Density(own), the same expression PyroFX
	uses). The plan is made per cast against that cap (planCast): tower tiers, torn tongues, crown licks, wall tongues
	(8 -> 4 per wall; 7 walls of 10 under 0.6), spires, runners and line strips thin with density, and the FLOOR takes
	what is left, so nothing relies on the canvas dropping parts. Draw order = priority (the canvas drops what is drawn
	last): line, hand, tower, walls, spires, floor, first front. Every flame's mesh FAMILY is fixed for the cast (drawn
	through cv:piece_axes), so a gust never swaps a flame between Flame and Spire and reshuffles the pool; what beats on a
	flame (breathing, gusts) is stepped with its mesh swaps, as PyroDraw's own builders do.

	CHECKED HEADLESS ONLY (phase3/ring_port: the real PyroDraw on the Roblox mock under the Luau CLI, and an offline
	painter sheet against ring_of_fire_r2.py's own frames). Never run in Studio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ring = {}

local sin, cos, exp, abs, floor, ceil, max, min, sqrt, pi = math.sin, math.cos, math.exp, math.abs, math.floor, math.ceil,
	math.max, math.min, math.sqrt, math.pi
local TAU = 2 * pi
local GOLDEN = 2.39996323
local UP = Vector3.new(0, 1, 0)
local ZERO = Vector3.new(0, 0, 0)

----------------------------------------------------------------------------------------------------
-- THE LOOK'S NUMBERS (visual only; the design's, ring_of_fire_r2.py). Nothing here is read by the server.
----------------------------------------------------------------------------------------------------
Ring.Visual = {
	DesignRadius = 17.5,           -- the radius the design was drawn at: the tower and the patches scale from it
	HotHeight = 1.15,              -- HOT: every height x this (the reach x Tuning.HotReach)
	HotLineAtReach = true,         -- HOT: the line is drawn at radius x HotReach, where the fire really ends (the design).
	                               -- false = the live rule (the line at `radius` whatever the Heat)
	BurnDown = 1.5,                -- seconds after the snap by which the last flame is out (the design's 3 x 0.5 s burn)

	LineHeight = 3.5, LineSpacing = 1.5, LineJitter = 0.5, LinePop = 0.10,
	HeadHeight = 5.6, HeadWidth = 2.6, HeadLean = 0.55, HeadWatts = 2600,

	TowerRadius = 6.0, TowerHeight = 44.0, TowerRise = 0.15,     -- at DesignRadius: a tower, not a cone
	Torn = 11, Crown = 9, Foot = 26,                              -- torn tongues carried up, crown licks, foot flames
	FrontTime = 0.17, FrontPower = 1.5, Runners = 46,             -- the first front: the tower's foot -> the line
	Spacing = 3.0, LateAt = 0.66,                                 -- the floor: studs between flames; patches above this catch late
	WallFlames = 8, WallTop = 25.0,                               -- tongues per wall; no wall flame taller (the tower must dominate)

	Fill = 0.98,                   -- the plan fills the canvas to this share of its cap
	Pocket = 6.0,                  -- flames rooted this near the LOCAL camera are not drawn (0 = off): standing in the
	                               -- circle in first person you are not inside a mesh (the design's inside stills)
	PocketLine = 1.0,              -- ...but THE LINE is the edge of the damage and its telegraph: inside the pocket its row
	                               -- flames duck to this height (studs, x the HOT height) and its ground strip stays whole;
	                               -- only its odd tall tongues go, like every other flame
	Hand = { Enabled = true, ScaleFP = 0.3, ScaleTP = 1.0 },      -- the fire on the caster's drawing hand
	Prewarm = true,                -- pool parts are created through the draw and the settle, not on the snap frame
	FlashDim = 0.75,               -- lights x this, and no flicker, under Settings "ReduceFlashing"
	WordAside = 1.45,              -- NOT used here: where the DESIGN stands IGNITE! (x the drawn radius, along the camera's
	                               -- right; live Tuning.WordAside is 0.8). For PyroFX's own word code, if the owner picks it
}
local V = Ring.Visual

-- The later walls and the spires, BAKED from the design's own random table (m_geom.rr, seeds 512 / 311) so they are
-- the walls and spires the owner approved, not look-alikes. Angles are the design's (Blender, from +X toward +Y; the
-- caster stands at pi / 2).
local WALLS = {   -- direction (rad), angular span (rad), start (s after the snap), crossing time (s), height (studs)
	{ 0.4000, 1.1815, 0.0591, 0.2770, 9.766 },
	{ 2.8000, 0.7901, 0.1271, 0.2950, 19.204 },
	{ 5.1999, 0.8073, 0.1624, 0.3603, 17.038 },
	{ 1.3167, 1.1154, 0.2234, 0.2657, 11.664 },
	{ 3.7167, 1.1024, 0.2603, 0.2337, 17.823 },
	{ 6.1166, 0.8406, 0.3276, 0.2730, 18.669 },
	{ 2.2334, 0.7924, 0.3690, 0.2307, 12.133 },
	{ 4.6334, 0.7724, 0.4164, 0.3411, 8.525 },
	{ 0.7501, 0.6701, 0.4627, 0.3613, 8.499 },
	{ 3.1501, 0.6436, 0.5071, 0.2917, 19.851 },
}
local SPIRES = {  -- direction (rad), radius / R, start (s; -1 = as the first front passes), life (s), height (studs), phase
	{ 1.0192, 0.8556, -1.0000, 0.3267, 16.068, 3.3494 },
	{ 3.2582, 0.6596, -1.0000, 0.3405, 26.422, 5.9492 },
	{ 5.8059, 0.8543, -1.0000, 0.4456, 21.202, 3.0021 },
	{ 1.9057, 0.5847, -1.0000, 0.3254, 28.901, 2.8471 },
	{ 4.3858, 0.8689, -1.0000, 0.3062, 16.614, 1.8916 },
	{ 0.0939, 0.5911, 0.1302, 0.3566, 28.725, 4.3281 },
	{ 2.9830, 0.5082, 0.1663, 0.4552, 27.459, 2.7500 },
	{ 4.9257, 0.4809, 0.2079, 0.3503, 17.949, 1.1931 },
	{ 1.3875, 0.8995, 0.2270, 0.4212, 28.739, 3.7294 },
	{ 3.5498, 0.6626, 0.2887, 0.4044, 23.623, 4.1403 },
	{ 6.0939, 0.6726, 0.3100, 0.4445, 21.002, 5.7713 },
	{ 2.1779, 0.8555, 0.3416, 0.4443, 28.076, 0.0704 },
	{ 4.5866, 0.6278, 0.3972, 0.3995, 16.135, 4.4502 },
	{ 0.5850, 0.7304, 0.4465, 0.3091, 26.324, 6.1258 },
	{ 3.0338, 0.8862, 0.4753, 0.3881, 24.055, 0.5297 },
	{ 5.3449, 0.6556, 0.5088, 0.3411, 21.831, 2.3053 },
}
local SEED_FLOOR, SEED_WALL, SEED_FRONT, SEED_TOWER = 220, 613, 207, 60

-- a flame's mesh family, fixed for its life and told apart by identity below; .fam = PyroDraw's family name (4 phases each)
local F2 = { fam = "Flame2" }
local F3 = { fam = "Flame3" }
local SPIRE = { fam = "Spire" }
local NEEDED = { "PF_Flame2_1", "PF_Flame3_1", "PF_Spire_1", "PF_Lick_1", "PF_Column_1", "PF_RowA_1", "PF_RowB_1", "PF_Strip_1" }

----------------------------------------------------------------------------------------------------
-- maths (the kit's curves)
----------------------------------------------------------------------------------------------------
local function clamp(x: number, a: number, b: number): number
	if x < a then return a end
	if x > b then return b end
	return x
end

local function sst(a: number, b: number, x: number): number
	local d = b - a
	if d < 1e-9 then d = 1e-9 end
	local u = clamp((x - a) / d, 0, 1)
	return u * u * (3 - 2 * u)
end

local function sm(x: number): number
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function eback(u: number, s: number): number
	u = clamp(u, 0, 1) - 1
	return u * u * ((s + 1) * u + s) + 1
end

local function equint(u: number): number
	return 1 - (1 - clamp(u, 0, 1)) ^ 5
end

local function unit(v)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return UP
end

--- the tower's rise (the kit's _pil_g)
local function pilG(tp: number, delay: number, dur: number): number
	local x = tp - delay
	if x <= 0 then return 0 end
	return eback(x / dur, 1.2)
end

--- smooth patch noise 0..1 over the floor, patches about 8 studs across (design coordinates)
local function pn(x: number, y: number, s: number): number
	return clamp(0.5 + 0.25 * (sin(0.39 * x + 1.1 + s + 0.9 * sin(0.23 * y + 1.7 * s)) * sin(0.33 * y - 0.8 + 0.5 * s)
		+ sin(0.21 * x - 0.27 * y + 2.3 + s)), 0, 1)
end

--- the front is not a circle: fingers of fire get ahead in some directions (+-44 % of the travel time)
local function wob(a: number): number
	return 0.22 * sin(3 * a + 0.7) + 0.14 * sin(5 * a + 2.1) + 0.08 * sin(9 * a + 4.0)
end

--- seconds after the snap at which the FIRST front reaches (radius rad, direction a)
local function litTime(rad: number, a: number, R: number, pr: number): number
	local rOut, r0 = 0.955 * R, 0.6 * pr
	local u = clamp((rad - r0) / (rOut - r0), 0, 1)
	return V.FrontTime * (1 - (1 - u) ^ (1 / V.FrontPower)) * (1 + wob(a))
end

----------------------------------------------------------------------------------------------------
-- lazy libraries, the registry
----------------------------------------------------------------------------------------------------
local bound = {}                                           -- Ring.Bind's: Rings, PyroFX, Tuning, RingDrawPoint, Viewmodel, PyroDraw,
                                                           -- Settings; Density (tests: a fixed density for the canvas)
local ownRings = setmetatable({}, { __mode = "k" })        -- [character] = the newest ring, while PyroFX's table is not bound
local PD = nil
local viewmodelLib, settingsLib = nil, nil
local warned = {}

local function warnOnce(key, msg)
	if not warned[key] then
		warned[key] = true
		warn("[PyroFlame_Ring] " .. msg)
	end
end

function Ring.Bind(deps)
	for k, v in pairs(deps) do bound[k] = v end
end

local function sibling(name)
	local parent = script.Parent
	local m = parent and parent:FindFirstChild(name)
	if not m then error(("[PyroFlame_Ring] %s is not beside this module"):format(name)) end
	return require(m)
end

local function draw()
	if not PD then PD = bound.PyroDraw or sibling("PyroDraw") end
	return PD
end

local function tuning()
	if not bound.Tuning then
		local fx = bound.PyroFX or sibling("PyroFX")
		bound.PyroFX = fx
		bound.Tuning = fx.Tuning
		bound.RingDrawPoint = bound.RingDrawPoint or fx.RingDrawPoint
	end
	return bound.Tuning
end

local function registry()
	return bound.Rings or ownRings
end

local function viewmodel()
	if viewmodelLib == nil then
		viewmodelLib = bound.Viewmodel or false
		if not viewmodelLib then
			local ok, lib = pcall(sibling, "Viewmodel")
			if ok and type(lib) == "table" then viewmodelLib = lib end
		end
	end
	return viewmodelLib
end

local function reduceFlashing()
	if settingsLib == nil then
		settingsLib = bound.Settings or false
		local sp = (not settingsLib) and ReplicatedStorage:FindFirstChild("Spellshot")
		local m = sp and sp:FindFirstChild("SpellshotSettings")
		if m then
			local ok, lib = pcall(require, m)
			if ok and type(lib) == "table" then settingsLib = lib end
		end
	end
	if settingsLib and type(settingsLib.Get) == "function" then
		local ok, on = pcall(settingsLib.Get, "ReduceFlashing")
		return ok and on == true
	end
	return false
end

--- The os.clock() moment a server-time stamp corresponds to on this machine (PyroFX's localClock).
local function localClock(serverT0)
	if type(serverT0) ~= "number" then return os.clock() end
	return os.clock() - (workspace:GetServerTimeNow() - serverT0)
end

local function isLocal(character)
	local lp = Players.LocalPlayer
	return character ~= nil and lp ~= nil and character == lp.Character
end

local function firstPerson()
	local lp = Players.LocalPlayer
	return lp ~= nil and lp.CameraMode == Enum.CameraMode.LockFirstPerson
end

--- True when the flame meshes this effect is built from are in the place.
function Ring.Ready()
	local ok, D = pcall(draw)
	if not ok then return false end
	local folder = D.MeshFolder()
	if not folder then return false end
	for _, name in ipairs(NEEDED) do
		if not folder:FindFirstChild(name) then return false end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- STEERING (the live contract; the record is the live one's: Center, Target, LockAt, Locked)
----------------------------------------------------------------------------------------------------
--- Moves `character`'s Ring of Fire toward `point` while it can still be moved. `exact` puts it there this frame.
function Ring.SteerRing(character, point, exact)
	local ring = registry()[character]
	if not ring or ring.Locked then return end
	ring.Target = point
	if exact then ring.Center = point end
end

--- The server lit `character`'s Ring of Fire at `point`: it moves no more, bar settling onto that spot.
function Ring.LockRing(character, point)
	local ring = registry()[character]
	if not ring then return end
	ring.Locked = true
	if point then ring.Target = point end
end

--- True while `character`'s Ring of Fire is still following its caster's aim (up to LockLead before the snap).
function Ring.RingSteerable(character)
	local ring = registry()[character]
	return ring ~= nil and not ring.Locked and os.clock() < ring.LockAt - tuning().RingOfFire.LockLead
end

----------------------------------------------------------------------------------------------------
-- ONE FLAME, its mesh family fixed (PyroDraw's emitFlame without the automatic Spire swap)
----------------------------------------------------------------------------------------------------
local PIECE_O = { cool = 0 }
local FPS, LEAN_K = 12.5, 0.8                              -- PyroDraw.Config.FPS / LeanK, read when a ring starts

--- a flame's own stepped clock: it moves when the flame's mesh phase swaps (12.5 / s), so whatever beats on it
--- (breathing, gusts) resizes the part with the swap and not every frame
local function stepT(t: number, ph: number): number
	local off = ph / TAU * 4
	return (floor(t * FPS + off) - off) / FPS
end

--- names: F2 | F3 | SPIRE; p: root; d: unit axis (the lean already in it); side: the wide axis; h, w: height, belly width
local function flame(cv: any, names: any, p: any, d: any, side: any, h: number, w: number, flat: number, ph: number, t: number, cool: number)
	if h < 0.02 or w < 0.01 then return end
	local x = side - d * side:Dot(d)
	local m = x.Magnitude
	if m < 1e-4 then return end
	x = x / m
	if names == SPIRE and floor(ph * 7) % 2 == 1 then x = -x end        -- its S-curve the other way round
	PIECE_O.cool = cool
	-- by family and phase on its axes (PyroDraw's piece_axes): no name parse and one CFrame a flame, not two
	cv:piece_axes(names.fam, floor(t * FPS + ph / TAU * 4) % 4 + 1, p, x, d, w, h, w * flat, PIECE_O)
end

--- the kit's row_vary: the seeded variation of a row of n flames -> arrays h, w, lt (lean along), sw (sway phase)
local function rowVary(D, n, seed, vary)
	local sd = seed + 17
	local v1 = min(vary, 1)
	local kA, kB = max(2, floor(n / 11 + 0.5)), max(3, floor(n / 4.7 + 0.5))
	local pA, pB = D.Rand(sd, 1, 5) * TAU, D.Rand(sd, 2, 5) * TAU
	local H, W, LT, SW = table.create(n), table.create(n), table.create(n), table.create(n)
	for i = 0, n - 1 do
		local s = i / n * TAU
		local h = 1 + vary * (0.25 * (0.62 * sin(kA * s + pA) + 0.38 * sin(kB * s + pB)) + 0.15 * (D.Rand(sd, i, 6) * 2 - 1))
		local tall = D.Rand(sd, i, 9) < 0.14 * v1
		local gap = (not tall) and D.Rand(sd, i, 11) < 0.12 * v1
		local q = D.Rand(sd, i, 10)
		if tall then h = max(h, 0.95) * (1 + v1 * (0.40 + 0.45 * q)) end
		if gap then h = h * (1 - v1 * (0.55 + 0.20 * q)) end
		h = clamp(h, 0.18, 2.8)
		local w = sqrt(h) * (1 + min(vary, 1.5) * 0.26 * (D.Rand(sd, i, 12) * 2 - 1))
		if tall then w = w * (1 - 0.18 * v1) elseif gap then w = w * (1 + 0.2 * v1) end
		H[i + 1], W[i + 1] = h, clamp(w, 0.3, 1.9)
		LT[i + 1] = vary * 0.19 * (D.Rand(sd, i, 13) * 2 - 1)
		SW[i + 1] = D.Rand(sd, i, 7) * TAU
	end
	return H, W, LT, SW
end

-- the builders' option tables, reused every frame (nothing is allocated per call)
local LINE_O = { height = nil, grow = nil, lean = nil, tall = nil, closed = true, vary = 1, strip = 1.3, seed = 7 }
local STRIP_O = { width = 1.3, grow = nil, closed = true, step = 8 }
local FRONT_O = { width = 2.1, grow = nil, closed = true, step = 6 }
local COL_O = { grow = 1, gx = 1, seed = SEED_TOWER, speed = 50, sway = 1.5, tiers = 8 }
local ROW_O = { length = 6, height = 3.5, thick = 1, variant = 1, flip = false, up = UP, ph = 0 }
local LICK_O = { curl_to = UP, ph = 0, cool = 0 }
local HAND_O = { size = 1, tongues = 4, light = false, vel = ZERO, seed = 13 }
local LIGHT_O = { t = nil, ph = 0 }
local EM_LINE = { id = "ring_line", inner = 0.92, count = 0, size = { 0.1, 0.24 } }
local EM_GATHER = { id = "ring_gather", rate = 0, radius = 2.2 }
local EM_HEAD = { id = "ring_head", count = 0, life = { 0.25, 0.6 }, out = { 2, 8 }, up = { 4, 13 }, size = { 0.1, 0.24 } }
local EM_CLOSE = { id = "ring_close", inner = 0.96, count = 0, life = { 0.3, 0.6 }, up = { 9, 22 }, size = { 0.1, 0.26 } }
local EM_FLOOR = { id = "ring_floor", inner = 0, count = 0, life = { 0.6, 1.2 }, up = { 6, 18 }, size = { 0.14, 0.34 } }
local EM_BLAST = { id = "ring_blast", count = 130, speed = { 16, 44 }, bias = Vector3.new(0, 0.55, 0), kd = 2.2, life = { 0.6, 1.25 },
	size = { 0.16, 0.42 } }
local EM_TOWER = { id = "ring_tower", count = 110, life = { 0.8, 1.5 }, out = { 1, 9 }, up = { 26, 50 }, spread = 3.6, g = 8, kd = 1,
	size = { 0.2, 0.5 } }
local EM_SNAP = { id = "ring_snap", count = 60, speed = { 8, 28 }, hemi = UP, life = { 0.25, 0.6 }, size = { 0.07, 0.17 } }

----------------------------------------------------------------------------------------------------
-- THE CAST'S STATIC TABLES (built once per cast, at the press)
----------------------------------------------------------------------------------------------------
--- design direction b (Blender angle) -> Roblox unit vectors: radial, tangent (toward growing b)
local function radial(S: any, b: number)
	local cb, sb = cos(b), sin(b)
	return S.ex * cb + S.ey * sb, S.ey * cb - S.ex * sb
end

local function buildLine(D, S)
	local Rl = S.Rl
	local n = max(8, floor(TAU * Rl / V.LineSpacing + 0.5))
	local L = { n = n, off = table.create(n), dir = table.create(n), b = table.create(n), frac = table.create(n),
		td = table.create(n), ta = table.create(n), pts = table.create(n), grow = table.create(n), height = table.create(n),
		lean = table.create(n), tall = table.create(n) }
	for i = 1, n do
		local k = i - 1
		-- in DRAW order (b falls as the hand goes round), so the line's pieces appear in their draw order
		local b = pi / 2 - TAU * k / n + (D.Rand(7, k, 0) - 0.5) * 0.03
		local dir = radial(S, b)
		L.dir[i], L.b[i], L.frac[i] = dir, b, k / n
		L.off[i] = dir * (Rl + (D.Rand(7, k, 1) - 0.5) * V.LineJitter) + UP * 0.05
		-- when this arc of the line goes out, and when the first front reaches it
		L.td[i] = (S.BURN - 0.55) + 0.55 * clamp(0.5 + 0.32 * sin(2 * b + 1.0) + 0.22 * sin(5 * b + 2.2) + 0.25 * (D.Rand(77, k, 7) - 0.5), 0, 1)
		L.ta[i] = V.FrontTime * (1 + wob(b))
		L.lean[i] = ZERO
	end
	return L
end

local function buildFloor(D: any, S: any, N: number, full: number)
	local R, pr, kh = S.Rf, S.pr, S.kh
	local rOut = 0.955 * R
	local k17 = V.DesignRadius / R                          -- the same patches at any radius
	local wide = clamp(sqrt(full / N), 1, 1.4)              -- fewer flames than the design's: each a little wider
	local list = table.create(N)
	for i = 0, N - 1 do
		local rad = min(rOut * sqrt((i + 0.5) / N) * (1 + (D.Rand(SEED_FLOOR, i, 1) - 0.5) * 0.12), rOut + 0.2)
		local a = i * GOLDEN + (D.Rand(SEED_FLOOR, i, 0) - 0.5) * 0.6
		local rn = clamp(rad / R, 0, 1)
		local sx, sy = cos(a) * rad * k17, sin(a) * rad * k17
		local inner = rad < 0.8 * pr
		local lp = pn(sx, sy, 3.0)
		local isLate = lp > V.LateAt and not inner
		local ti = 0
		if inner then
			ti = S.HOLD - 0.16 + 0.12 * D.Rand(SEED_FLOOR, i, 5)             -- the tower's footprint: its own flames, late
		else
			local late = isLate and (0.10 + 0.34 * clamp((lp - V.LateAt) / (1 - V.LateAt), 0, 1) + 0.06 * D.Rand(SEED_FLOOR, i, 9)) or 0
			ti = litTime(rad, a, R, pr) + late + (D.Rand(SEED_FLOOR, i, 5) - 0.5) * 0.03
		end
		local q = 0.55 * pn(sx, sy, 7.0) + 0.30 * (1 - rn) + 0.15 * D.Rand(SEED_FLOOR, i, 7)
		local hp = pn(sx, sy, 11.0)
		local big = i % 5 == 0
		local torch = (i % 9 == 4) and not inner                           -- the odd tall slender tongue, on its own beat
		local Hb = kh * (2.0 + 9.5 * hp * hp) * (0.75 + 0.5 * D.Rand(SEED_FLOOR, i, 2)) * (big and 1.25 or 1) * (inner and 1.4 or 1)
		local wk = (0.34 + 0.12 * D.Rand(SEED_FLOOR, i, 3)) * (torch and 0.75 or 1) * wide
		-- its mesh family, for the whole cast: by its proportions standing in a middling gust
		local Ht = Hb * (torch and 1.33 or 1)
		local names = (Ht * 1.17 > 2.6 * (Ht * wk + 0.45)) and SPIRE or ((big or torch) and F3 or F2)
		local rd, tg = radial(S, a)
		list[i + 1] = {
			ti = max(ti, 0), td = 0.98 + (S.BURN - 0.98) * clamp(q * 1.3 - 0.06, 0, 1),
			off = rd * rad + UP * 0.05, rd = rd, tg = tg, rad = rad, width = Hb * wk + 0.45,
			Hb = Hb, wk = wk, torch = torch, r8 = D.Rand(SEED_FLOOR, i, 8) * TAU,
			surgeK = isLate and 1.1 or 0.55, sinkK = 0.12 + 0.40 * (1 - hp), g2 = 0.7 * sin(2 * a),
			a2 = 2 * a + rn * 3.0, a3 = 3 * a + 2.0, a5 = 5 * a + 1.0, phs = D.Rand(SEED_FLOOR, i, 6) * TAU,
			ph = D.Rand(7, i + SEED_FLOOR * 977, 4) * TAU, names = names,
		}
	end
	-- in the order they catch: the lit flames are always the head of the list, so a flame catching does not
	-- renumber the ones already burning
	table.sort(list, function(p, q) return p.ti < q.ti end)
	return list
end

local function buildWalls(D, S)
	local NF = S.NF
	local kh = S.kh
	local rvH, rvW, rvLT, rvSW = rowVary(D, #WALLS * NF, SEED_WALL, 1.3)
	local wide = sqrt(V.WallFlames / NF)                     -- fewer tongues: each a little wider
	local walls = {}
	for k = 0, #WALLS - 1 do
		if S.q >= 0.6 or k % 3 ~= 2 then
			local w = WALLS[k + 1]
			local wall = { a0 = w[1], half = 0.5 * w[2], s = w[3], d = w[4], h = w[5], flames = table.create(NF) }
			for f = 0, NF - 1 do
				local id = k * NF + f
				local u = (NF > 1) and f / (NF - 1) or 0.5
				local ang = w[1] + w[2] * (u - 0.5) + 0.05 * sin(id * 2.3)
				local rd, tg = radial(S, ang)
				local prof = 0.3 + 0.7 * sin(pi * u) ^ 0.7
				local hv, wv = clamp(rvH[id + 1], 0.3, 1.6), rvW[id + 1] * wide
				local Hs = kh * w[5] * prof * hv                 -- its height at the tallest point of its run
				wall.flames[f + 1] = {
					rd = rd, tg = tg, uu = (2 * u - 1) ^ 2, rj = (D.Rand(SEED_WALL, id, 5) - 0.5) * 0.9, hk = kh * w[5] * prof * hv,
					wv = wv, lt = rvLT[id + 1], sw = rvSW[id + 1], ph = D.Rand(7, id + SEED_WALL * 977, 4) * TAU,
					names = (Hs > 2.6 * min(0.28 * Hs * wv + 0.5, 6.5 * kh)) and SPIRE or F3,
				}
			end
			walls[#walls + 1] = wall
		end
	end
	return walls
end

local function buildSpires(S)
	local list = {}
	for j = 0, #SPIRES - 1 do
		if S.q >= 0.6 or j < 5 or j % 3 ~= 2 then
			local sp = SPIRES[j + 1]
			local rad = sp[2] * S.Rf
			local rd, tg = radial(S, sp[1])
			list[#list + 1] = {
				s = (sp[3] < 0) and (litTime(rad, sp[1], S.Rf, S.pr) + 0.02) or sp[3], L = sp[4],
				H = S.kh * sp[5] * sqrt(S.kR), off = rd * rad + UP * 0.05, rd = rd, tg = tg, a2 = 2 * sp[1] + 1.0, ph = sp[6],
			}
		end
	end
	return list
end

local function buildFront(D, S, n)
	local kh = S.kh
	local rvH, _, rvLT, rvSW = rowVary(D, n, SEED_FRONT, 1.7)
	local list = table.create(n)
	for j = 0, n - 1 do
		local a = j * TAU / n + 0.07 * sin(j * 2.3)
		local rd, tg = radial(S, a)
		local H = 5.2 * kh * rvH[j + 1] * (0.8 + 0.4 * D.Rand(SEED_FRONT, j, 2))
		list[j + 1] = {
			T = V.FrontTime * (1 + wob(a)), rd = rd, tg = tg, H = H, W = 0.42 * H + 0.9,
			out = 0.85 - 0.6 * clamp((H / kh - 3.5) / 6.0, 0, 1), lt = rvLT[j + 1], sw = rvSW[j + 1],
			ph = D.Rand(7, j + SEED_FRONT * 977, 4) * TAU, names = (H > 7.0 * kh) and F3 or F2,
		}
	end
	return list
end

local function buildTower(D, S)
	local seed = SEED_TOWER
	local torn = table.create(S.nTorn)
	for j = 0, S.nTorn - 1 do
		torn[j + 1] = {
			rate = 0.9 + 0.5 * D.Rand(seed, j, 0), f0 = D.Rand(seed, j, 1), a = D.Rand(seed, j, 2) * TAU,
			rad = 5.5 + 3.5 * D.Rand(seed, j, 3), h = 5.5 + 3.5 * D.Rand(seed, j, 4), w = 2.4 + 0.9 * D.Rand(seed, j, 5),
			ph = D.Rand(seed, j, 6) * TAU,
		}
	end
	local sd = seed + 7
	local crown = table.create(S.nCrown)
	for j = 0, S.nCrown - 1 do
		local uz = 0.34 + 0.40 * D.Rand(sd, j, 1)
		crown[j + 1] = {
			a = j * TAU / S.nCrown + 0.6 * D.Rand(sd, j, 0), uz = uz,
			rk = clamp(1 - uz ^ 1.8, 0, 1) ^ 0.75 * (0.15 + 0.35 * D.Rand(sd, j, 2)), hk = 0.22 + 0.22 * D.Rand(sd, j, 3),
			ph = D.Rand(7, j + sd * 131, 4) * TAU,
		}
	end
	local flip = table.create(S.footRows)
	for j = 0, S.footRows - 1 do flip[j + 1] = D.Rand(seed + 3, j, 10) < 0.5 end
	return torn, crown, flip
end

--- how many of a list of timed things are up at t
local function upAt(list, t, up)
	local n = 0
	for i = 1, #list do
		if up(list[i], t) then n += 1 end
	end
	return n
end

--- THE PLAN: what this cast draws, sized to its canvas (cap x density). The tower, the walls and the spires thin
--- with density; the FLOOR then takes what is free at the busiest moment of the eruption, and the first front's
--- runners what is free in its 0.33 s.
local function planCast(D, S, cv)
	local dens = cv.Density
	local q = clamp(dens, 0.3, 1)
	local budget = floor(cv.MaxParts * V.Fill)
	S.q = q
	local n = S.line.n
	local rows = max(1, floor(n / 4 + 0.5))
	S.thinStrip = q < 0.75                                   -- half the ground strips (and PyroDraw drops the tall tongues)
	local talls = 0
	if dens >= 0.75 then                                     -- PyroDraw.fire_line's own rule for the odd tall tongue (seed 7)
		for piece = 0, rows - 1 do
			if D.Rand(LINE_O.seed, piece, 11) < 0.5 then talls += 1 end
		end
	end
	local lineParts = rows + (S.thinStrip and max(1, floor(n / 8 + 0.5)) or rows) + talls
	S.nTorn = floor(V.Torn * q + 0.5)
	S.nCrown = max(4, floor(V.Crown * q + 0.5))
	S.footRows = (q >= 0.6) and max(3, floor(V.Foot / 4 + 0.5)) or 0
	-- a 44 x 6 tower is slender: under 6 tiers the column comes apart into separate blobs (PyroDraw's own floor is 4)
	S.tiers = (q >= 0.9) and D.Config.ColumnTiers or ((q >= 0.6) and 7 or 6)
	local tower = S.tiers + S.nTorn + S.nCrown + S.footRows
	S.NF = clamp(floor(V.WallFlames * q + 0.5), (q < 0.4) and 3 or 4, V.WallFlames)
	S.torn, S.crown, S.footFlip = buildTower(D, S)
	S.walls = buildWalls(D, S)
	S.spires = buildSpires(S)
	local gone = S.HOLD + S.SINK
	local function wallUp(w, t) return t > w.s and t < w.s + w.d + 0.11 and t < gone end
	local function spireUp(sp, t) return t > sp.s and t < sp.s + sp.L and t < gone end
	local function floorUp(f, t) return t > f.ti and t < f.td end
	local function rest(t)
		return lineParts + ((t < gone) and tower or 0) + upAt(S.walls, t, wallUp) * S.NF + upAt(S.spires, t, spireUp)
	end
	-- the floor: the design's count (x density), cut to what the busiest moment leaves
	local rOut = 0.955 * S.Rf
	local full = pi * rOut * rOut / (V.Spacing * V.Spacing)
	local want = max(12, floor(full * q + 0.5))
	local list = buildFloor(D, S, want, full)
	local N = want
	local wallsMost, spiresMost = 0, 0
	local t = 0.02
	while t < S.BURN do
		local lit = upAt(list, t, floorUp)
		if lit > 0 then N = min(N, floor((budget - rest(t)) * want / lit)) end
		wallsMost, spiresMost = max(wallsMost, upAt(S.walls, t, wallUp)), max(spiresMost, upAt(S.spires, t, spireUp))
		t += 0.02
	end
	N = max(12, N)
	if N < want then list = buildFloor(D, S, N, full) end
	S.floor = list
	-- the first front: its runners (and one ground strip per six) take what is free while they live
	local nRun = clamp(floor(V.Runners * q + 0.5), 12, V.Runners)
	local front = buildFront(D, S, nRun)
	local function runnerUp(f, tt) return tt < f.T + 0.08 end
	local keep = 1
	t = 0.02
	while t < V.FrontTime * 1.45 + 0.09 do
		local up = upAt(front, t, runnerUp)
		if up > 0 then keep = min(keep, (budget - rest(t) - upAt(list, t, floorUp)) / (up * 7 / 6 + 1)) end
		t += 0.02
	end
	if keep < 1 then
		nRun = max(0, floor(nRun * keep))
		front = buildFront(D, S, nRun)
	end
	S.front = front
	S.frontPts, S.frontGrow = table.create(nRun), table.create(nRun)
	S.plan = { Cap = cv.MaxParts, Budget = budget, Line = lineParts, Tower = tower, WallFlames = S.NF, Walls = #S.walls,
		Spires = #S.spires, Floor = N, FloorDesign = floor(full + 0.5), Runners = nRun }
	-- the pool the eruption needs, per mesh phase, for PyroDraw.Prewarm
	local c2, c3, cs = 0, 0, spiresMost + S.nCrown
	for i = 1, N do
		local nm = list[i].names
		if nm == F2 then c2 += 1 elseif nm == F3 then c3 += 1 else cs += 1 end
	end
	for i = 1, nRun do
		if front[i].names == F2 then c2 += 1 else c3 += 1 end
	end
	for i = 1, #S.walls do
		local share = min(1, wallsMost / #S.walls)
		for _, fl in ipairs(S.walls[i].flames) do
			if fl.names == F3 then c3 += share else cs += share end
		end
	end
	S.warm = { Flame2 = ceil(c2 / 4 * 1.25) + 1, Flame3 = ceil(c3 / 4 * 1.25) + 2, Spire = ceil(cs / 4 * 1.25) + 1,
		Column = 4, Lick = ceil(S.nTorn / 3) + 2, RowA = 2, RowB = 2, Strip = ceil(nRun / 6) + 2 }
	S.warmNow = {}
end

----------------------------------------------------------------------------------------------------
-- THE FRAME, piece by piece.  t = tr (seconds after the press) is also the wave clock; tp = t - the snap
----------------------------------------------------------------------------------------------------
--- 0 inside the local camera's pocket, 1 clear of it (p: a flame's root, w: its width)
local function pocket(S: any, p: any, w: number): number
	local dx, dz = p.X - S.camX, p.Z - S.camZ
	local edge = V.Pocket + 0.5 * w
	return sst(edge - 1.0, edge + 1.5, sqrt(dx * dx + dz * dz))
end

--- THE LINE (the fence), its drawing head, the closing pulse; it flares where the first front and each wall hit it
--- and dies back arc by arc. -> the share of it alight
local function lineFrame(cv: any, S: any, c: any, t: number, tp: number)
	local L = S.line
	local n = L.n
	local tDraw, kh = S.tDraw, S.kh
	local close = sst(tDraw - 0.02, tDraw + 0.06, t) * (1 - sst(tDraw + 0.08, tDraw + 0.32, t))    -- the circle closes: a pulse
	local inhale = (tp < 0) and sst(tDraw + S.tSettle, S.tSnap - 0.02, t) or 0                       -- the wind-up: it ducks
	local h0 = V.LineHeight * kh * (1 + 0.45 * close) * (1 - 0.22 * inhale)
	local erupt = tp >= 0
	local hits, nHit = S.hits, 0
	if erupt then
		h0 = h0 * (1 - 0.3 * sst(S.HOLD, S.HOLD + S.SINK + 0.15, tp))
		for i = 1, #S.walls do                                 -- the walls splashing against it now
			local w = S.walls[i]
			local xk = tp - (w.s + w.d) + 0.03
			if xk > 0 and xk < 1.0 then
				nHit += 1
				local hit = hits[nHit]
				if not hit then
					hit = { 0, 0, 0 }
					hits[nHit] = hit
				end
				hit[1], hit[2], hit[3] = w.a0, w.half, exp(-xk / 0.2)
			end
		end
	end
	local pts, grow, height, lean, tall = L.pts, L.grow, L.height, L.lean, L.tall
	local off, dir, bb, frac, td, ta = L.off, L.dir, L.b, L.frac, L.td, L.ta
	local sum, anyLean = 0, false
	local near = S.camNear
	for i = 1, n do
		local g = sst(0, 1, (t - tDraw * frac[i]) / V.LinePop)
		local h = h0
		local p = c + off[i]
		if erupt then
			local flare, blow = 0, 0
			local x = tp - ta[i]
			if x >= 0 then                                       -- the first front ARRIVES: it flares and is blown outward
				flare = 1.25 * exp(-x / 0.24) + 0.2
				blow = 0.55 * exp(-x / 0.2)
			end
			for k = 1, nHit do
				local hit = hits[k]
				local e = abs((bb[i] - hit[1] + pi) % TAU - pi) / hit[2]
				if e < 2.6 then
					local wv = exp(-e * e) * hit[3]
					flare += 0.9 * wv
					blow += 0.4 * wv
				end
			end
			h = h * (1 + flare)
			g = g * (1 - sst(td[i] - 0.3, td[i], tp))           -- the burn-down: arcs of it go out one after another
			if blow > 0.004 then
				lean[i] = dir[i] * blow
				anyLean = true
			else
				lean[i] = ZERO
			end
		end
		if near then
			-- inside the local camera's pocket the fence is NOT removed (it is the edge of the damage, for whoever stands
			-- on it through the telegraph): grow is left alone, so the ground strip stays whole, and the row flames duck.
			-- Its odd tall tongues are pocketed like every other flame, each where it stands (fire_line's o.tall)
			local pk = pocket(S, p, 0)
			local low = V.PocketLine * kh
			if h > low then h = low + (h - low) * pk end
			tall[i] = pk
		end
		pts[i], grow[i], height[i] = p, g, h
		sum += g
	end
	local stripW = 1.3 * (1 + 0.9 * close)
	LINE_O.height, LINE_O.grow, LINE_O.lean = height, grow, anyLean and lean or nil
	LINE_O.tall = near and tall or nil                       -- written for every point this frame when near
	LINE_O.strip = S.thinStrip and 0 or stripW
	cv:fire_line(pts, t, LINE_O)
	if S.thinStrip then
		STRIP_O.width, STRIP_O.grow = stripW, grow
		cv:ground_strip(pts, STRIP_O)
	end
	-- the drawing head: the flame the hand is drawing with, racing round, leaning back off its own speed
	if t > 0 and t < tDraw + 0.08 then
		local b = pi / 2 - TAU * min(t / tDraw, 1)
		local rd, tg = radial(S, b)
		local gh = sst(0, 0.04, t) * (1 - sst(tDraw, tDraw + 0.08, t))
		local hp = c + rd * S.Rl + UP * 0.05
		local ph = S.headPh
		if gh > 0.02 and not (near and pocket(S, hp, V.HeadWidth) < 0.5) then
			flame(cv, F3, hp, unit(UP + tg * (V.HeadLean * LEAN_K)), tg, V.HeadHeight * kh * gh * (0.82 + 0.18 * sin(TAU * 2.5 * stepT(t, ph) + ph)),
				V.HeadWidth * (0.6 + 0.4 * gh), 0.62, ph, t, 0)
			S.headAt, S.headOn = hp, gh
		end
	end
	return sum / n, close
end

--- THE FIRE ON THE CASTER'S DRAWING HAND: it draws with it, gathers in the settle, is thrown at the snap
local function handPoint(S)
	local character = S.character
	if not character then return nil end
	if S.own and firstPerson() then
		local vm = viewmodel()
		if vm and type(vm.GetArmCFrame) == "function" then
			local ok, cf = pcall(vm.GetArmCFrame, "R")
			if ok and cf then return cf * Vector3.new(0, 0, -1.25), V.Hand.ScaleFP, true end
		end
		return nil
	end
	local hand = character:FindFirstChild("RightHand")
	if hand then return hand.CFrame * Vector3.new(0, -0.25, 0), V.Hand.ScaleTP, false end
	return nil
end

local function handFrame(cv: any, S: any, t: number, tp: number, dt: number?)
	local tDraw, tSnap = S.tDraw, S.tSnap
	S.handAt = nil
	if not V.Hand.Enabled or t <= 0 or tp >= 0.6 then return end
	local p, scale, fp = handPoint(S)
	if not p then return end
	S.handAt, S.handScale = p, scale
	if t < tSnap + 0.1 then
		local size = 0.5 + 0.2 * sst(0, tDraw, t) + 0.55 * sst(tDraw, tSnap - 0.04, t)
		size = size * sst(0, 0.08, t) * (1 + 0.5 * sst(tSnap - 0.05, tSnap, t)) * (1 - sst(tSnap, tSnap + 0.09, t))
		if size > 0.03 then
			local vel = ZERO
			if not fp and S.handPrev and dt and dt > 1e-4 then      -- on a body the flame lags the hand; on the viewmodel it stands
				vel = (p - S.handPrev) / dt
				local m = vel.Magnitude
				if m > 30 then vel = vel * (30 / m) end
			end
			HAND_O.size, HAND_O.vel = size * scale, vel
			cv:hand_flame(p, t, HAND_O)
		end
	end
	S.handPrev = p
end

--- THE CENTRAL BLAST: a column of rising tiers, a torn crown of licks in its top half, torn tongues carried up round
--- it, the foot ring thrown out at the eruption. It SINKS after EruptHold. -> its light's strength
local function towerFrame(cv: any, S: any, c: any, t: number, tp: number)
	local s = 1 - clamp((tp - S.HOLD) / S.SINK, 0, 1)        -- live: it sinks back, it never fades
	if s <= 0.03 then return 0 end
	local height = V.TowerHeight * S.kh * sqrt(S.kR) * s
	local radius = S.pr * (0.55 + 0.45 * s)
	local kH, kr = height / 36, radius / 8
	local rise = V.TowerRise
	-- one mesh stands for the design's three nested columns (delays 0 / 0.03 / 0.06): it rises with the middle one,
	-- and the crown with it, so the crown never stands in the air
	local g = pilG(tp, 0.03, rise)
	if g > 0.02 then
		COL_O.grow, COL_O.gx, COL_O.speed, COL_O.tiers = g, 0.55 + 0.45 * min(g, 1), 50 * kH, S.tiers
		cv:column(c, radius, height, t, COL_O)
	end
	local g0 = min(g, 1.1)
	if g0 > 0.3 then                                          -- the torn crown: licks standing in the column's top half
		for j = 1, S.nCrown do
			local cr = S.crown[j]
			local zc = cr.uz * height * g0
			local Hl = min(cr.hk * height, 1.07 * height * g0 - zc) * (1 + 0.2 * sin(TAU * 2.5 * stepT(t, cr.ph) + j * 2.1))
			if Hl > 0.05 then
				local rd, tg = radial(S, cr.a + 0.9 * tp)
				local d = unit(unit(UP + rd * 0.06 + tg * 0.16) + (rd * -0.05 + tg * (0.10 * sin(TAU * 1.25 * t + j * 1.7))) * LEAN_K)
				flame(cv, SPIRE, c + rd * (radius * cr.rk) + UP * zc, d, tg, Hl, 0.22 * Hl, 0.75, cr.ph, t, 0.2)
			end
		end
	end
	for j = 1, S.nTorn do                                     -- torn tongues, carried up and inward
		local tn = S.torn[j]
		local f = (tp * tn.rate + tn.f0) % 1
		if tp > f * 0.8 + 0.12 then
			local rd, tg = radial(S, tn.a + 1.3 * tp)
			local sc = max(0, sin(pi * f)) ^ 0.7
			LICK_O.curl_to, LICK_O.ph, LICK_O.cool = -rd, tn.ph, 0.2 * f
			cv:flame("lick", c + rd * (tn.rad * (1 - 0.5 * f) * kr) + UP * ((3.0 + 35.0 * f ^ 0.9) * kH), unit(rd * 0.2 + tg * 0.3 + UP),
				tn.h * sc * kH, tn.w * sc * kr, LICK_O)
		end
	end
	local nR = S.footRows
	if nR > 0 then                                            -- the foot ring, thrown out at the eruption
		local rb = (7.5 + 6.5 * equint(tp / 0.5)) * kr
		local sc = 1.5 * eback(tp / 0.14, 1.5) * (0.5 + 0.5 * exp(-tp / 0.3)) * kr
		local seg = TAU * rb / nR
		for j = 0, nR - 1 do
			local rd, tg = radial(S, (j + 0.5) * TAU / nR + 0.14 * sin(j * 2.3))
			local ph = j * 2.2
			ROW_O.length, ROW_O.height = seg * 1.06, 3.9 * sc * (0.85 + 0.15 * sin(TAU * 2.5 * stepT(t, ph) + ph))
			ROW_O.thick, ROW_O.variant, ROW_O.flip, ROW_O.up, ROW_O.ph = max(0.4, sc), (j % 2 == 0) and 1 or 2, S.footFlip[j + 1], UP + rd * 0.55, j * 1.9
			cv:row(c + rd * (rb + 0.6 * sin(j * 1.9)) + UP * 0.05, tg, ROW_O)
		end
	end
	return min(pilG(tp, 0, rise), 1.15) * kr * kH
end

--- THE LATER WALLS OF FLAME: crescents of tongues that leave the tower's foot one after another and roll out to the
--- line, growing as they go (tallest 3/4 of the way out), leaning the way they travel
local function wallsFrame(cv: any, S: any, c: any, t: number, tp: number)
	local kh, pr = S.kh, S.pr
	local rOut, r0 = 0.955 * S.Rf, 0.7 * S.pr
	local sink = (1 - clamp((tp - S.HOLD) / S.SINK, 0, 1)) ^ 1.3
	if sink <= 0.02 then return end
	local near = S.camNear
	local top, fat = V.WallTop * kh, 6.5 * kh
	local w125 = TAU * 1.25 * t
	for i = 1, #S.walls do
		local w = S.walls[i]
		local age = tp - w.s
		if age > 0 then
			local d = w.d
			local env = eback(age / 0.10, 1.5) * (1 - sst(d - 0.03, d + 0.11, age)) * sink
			if env > 0.02 then
				local qq = clamp(age / d, 0, 1)
				local rw = r0 + (rOut - r0) * (1 - (1 - qq) ^ 1.35)
				local trav = 0.42 + 0.68 * sin(pi * qq ^ 1.3) ^ 0.8       -- low at the tower, tallest 3/4 out, low at the fence
				local out = 0.28 * (1 - 0.5 * sst(d - 0.1, d, age))
				local gk = min(env, 1.3)
				local wk = 0.6 + 0.4 * min(gk, 1)
				local bow = 2.4 * (0.4 + 0.6 * qq)
				for f = 1, #w.flames do
					local fl = w.flames[f]
					local H = min(fl.hk * trav, top)
					local W = min(0.28 * H * fl.wv + 0.5, fat)                 -- tongues, not a sheet
					local p = c + fl.rd * clamp(rw - bow * fl.uu + fl.rj, 0.55 * pr, rOut) + UP * 0.05
					local k = gk
					if near then k = k * pocket(S, p, W) end
					if k > 0.02 then
						local ph = fl.ph
						local lt = 1.4 * (fl.lt + 0.091 * sin(w125 + fl.sw))
						flame(cv, fl.names, p, unit(UP + (fl.rd * out + fl.tg * lt) * LEAN_K), fl.tg,
							H * k * (0.82 + 0.18 * sin(TAU * 2.5 * stepT(t, ph) + ph)), W * wk, 0.75, ph, t, 0)
					end
				end
			end
		end
	end
end

--- SPIRES THAT SHOOT UP AND FALL BACK anywhere between the tower and the line: a ragged skyline, no cone
local function spiresFrame(cv: any, S: any, c: any, t: number, tp: number)
	local sink = 1 - sst(S.HOLD + 0.05, S.HOLD + S.SINK, tp)
	if sink <= 0.02 then return end
	local near = S.camNear
	for j = 1, #S.spires do
		local sp = S.spires[j]
		local age = tp - sp.s
		if age > 0 and age < sp.L then
			local g = eback(age / 0.11, 1.5) * (1 - sst(sp.L - 0.17, sp.L, age)) * sink
			local p = c + sp.off
			if near then g = g * pocket(S, p, 0.22 * sp.H) end
			if g > 0.02 then
				local ln = sp.tg * (0.12 * sin(sp.a2 + TAU * 1.25 * t)) + sp.rd * (0.2 * exp(-age / 0.25) + 0.03)
				flame(cv, SPIRE, p, unit(UP + ln * LEAN_K), sp.tg, sp.H * g, 0.22 * sp.H * (0.6 + 0.4 * min(g, 1)) * min(g / 0.05, 1),
					0.8, sp.ph, t, 0)
			end
		end
	end
end

--- THE BURNING FLOOR: the whole circle alight but LOW and PATCHY, lit by the first front as it passes, with patches
--- that catch late and crests running outward through it; it sinks unevenly and dies back patch by patch.
--- -> the share of it alight
local function floorFrame(cv: any, S: any, c: any, t: number, tp: number)
	local list = S.floor
	local kh = S.kh
	local HOLD, SINK = S.HOLD, S.SINK
	local live = 1 - sst(HOLD - 0.05, HOLD + SINK, tp)        -- 1 through the hold, 0 once the big flames sank
	local sunk = sst(HOLD, HOLD + SINK, tp)
	local gustK = 0.12 + 0.45 * live
	local top = 20.0 * kh
	local w125 = TAU * 1.25 * t
	local near = S.camNear
	local lit = 0
	for i = 1, #list do
		local f = list[i]
		local age = tp - f.ti
		if age <= 0 then break end                              -- in the order they catch: the rest are not alight yet
		local td = f.td
		if tp < td then
			local g = eback(age / 0.13, 1.6) * (1 - sst(td - 0.24, td, tp))
			local p = c + f.off
			if near then g = g * pocket(S, p, f.width) end
			if g > 0.02 then
				lit += 1
				local ph = f.ph
				local tq = stepT(t, ph)
				local Hb = f.Hb
				if f.torch then Hb = Hb * 1.8 * (0.55 + 0.6 * max(sin(TAU * 1.25 * tq + f.r8), 0)) end
				local gust = 0.5 + 0.5 * sin(TAU * (2.5 * tq - f.rad / 9.0) + f.g2)       -- crests running outward, 2.5 Hz
				-- it sinks with the big flames, UNEVENLY: tall patches stay up, low ones gutter
				local decay = (1 - f.sinkK * sunk) * (1 - 0.3 * sst(HOLD + SINK, td, tp))
				local Hh = min(Hb * (1 + f.surgeK * exp(-age / 0.17)) * (1 + gustK * gust * gust) * decay, top)
				local W = Hb * decay ^ 0.7 * f.wk + 0.45
				-- each flame leans its own way: a swirl + the gust, only a little outward
				local wt = 0.22 * sin(f.a2 + w125) + 0.12 * sin(f.a5 - 2 * w125) + 0.16 * sin(w125 + f.phs)
				local wr = 0.30 * exp(-age / 0.2) + (0.04 + 0.10 * live) * gust + 0.02 * live + 0.08 * sin(f.a3 + w125)
					+ 0.12 * cos(w125 + f.phs * 1.7)
				local gg = min(g, 1.3)
				flame(cv, f.names, p, unit(UP + (f.tg * wt + f.rd * wr) * LEAN_K), f.tg,
					Hh * gg * (0.82 + 0.18 * sin(TAU * 2.5 * tq + ph)), W * (0.6 + 0.4 * min(gg, 1)), 0.72, ph, t,
					0.38 * sst(td - 0.55, td, tp))
			end
		end
	end
	return lit / max(#list, 1)
end

--- THE FIRST FRONT, racing out with the snap: runner flames of very different heights on a front that is not a
--- circle, over a burning line on the ground. At the line by 0.10 - 0.245 s.
local function frontFrame(cv: any, S: any, c: any, t: number, tp: number)
	local list = S.front
	local n = #list
	if n == 0 or tp > V.FrontTime * 1.45 + 0.09 then return end
	local rOut, r0 = 0.955 * S.Rf, 0.6 * S.pr
	local up = sst(0, 0.04, tp)
	local near = S.camNear
	local w125 = TAU * 1.25 * t
	local pts, grow = S.frontPts, S.frontGrow
	for j = 1, n do
		local f = list[j]
		local T = f.T
		local q = clamp(tp / T, 0, 1)
		local p = c + f.rd * (r0 + (rOut - r0) * (1 - (1 - q) ^ V.FrontPower)) + UP * 0.05
		local life = up * (1 - sst(T - 0.01, T + 0.08, tp))
		if near then life = life * pocket(S, p, f.W) end
		pts[j], grow[j] = p, life
		if life > 0.02 then
			local ph = f.ph
			local ln = f.rd * f.out + f.tg * (1.5 * (f.lt + 0.119 * sin(w125 + f.sw)))
			flame(cv, f.names, p, unit(UP + ln * LEAN_K), f.tg, f.H * life * (0.82 + 0.18 * sin(TAU * 2.5 * stepT(t, ph) + ph)),
				f.W * (0.6 + 0.4 * life), 0.8, ph, t, 0)
		end
	end
	FRONT_O.grow = grow
	cv:ground_strip(pts, FRONT_O)
end

--- LIGHTS (the canvas keeps 4, 2 when thinned: the first asked win) AND EMBERS (6 emitters; each keeps its place in
--- the call order while it has sparks in the air, so none is re-dressed mid-flight)
local function lightsFrame(cv: any, S: any, c: any, t: number, tp: number, lineLit: number, close: number, towerK: number)
	local dim = S.dim
	local ft = if dim < 1 then nil else t                      -- ReduceFlashing: steady lights
	LIGHT_O.t = ft
	local R = S.Rf
	if tp < 0 then
		if S.headOn and S.headOn > 0.02 then
			LIGHT_O.ph = 0.4
			cv:fire_light(S.headAt + UP * 2.0, V.HeadWatts * S.headOn * dim, LIGHT_O)
		end
		local settle = sst(S.tDraw, S.tSnap, t)
		if settle > 0.02 then cv:ground_glow(c, 0.5 * R, 0.55 * settle * dim, ft, 0.3) end      -- the floor inside begins to glow
		local lv = 0.9 * lineLit * (1 + 0.5 * close) * dim
		if lv > 0.02 then
			for q = 0, 2 do
				local rd = radial(S, q * TAU / 3 + 0.3)
				cv:ground_glow(c + rd * S.Rl, 7.0, lv, ft, q)
			end
		end
		return
	end
	-- the fire's light on the floor: up with the first front, down through the burn
	local lv = sm(tp / 0.2) * (1 - 0.55 * sm((tp - S.HOLD) / (S.SINK * 1.6))) * (1 - sm((tp - 0.95) / (S.BURN - 0.95))) * dim
	if lv > 0.01 then cv:ground_glow(c, 0.5 * R, 1.6 * lv, ft, 0.3) end
	if towerK > 0.01 then
		LIGHT_O.ph = 4.5
		cv:fire_light(c + UP * (4.5 * V.TowerHeight / 36 * S.kh * sqrt(S.kR)), 17000 * towerK * dim, LIGHT_O)
	end
	if lv > 0.01 then
		for q = 0, 1 do
			local rd = radial(S, q * pi + 0.4)
			cv:ground_glow(c + rd * (0.62 * R), 0.45 * R, 1.25 * lv, ft, 1.0 + q)
		end
	end
end

local function embersFrame(cv: any, S: any, c: any, t: number, tp: number, lineLit: number, floorLit: number)
	local tDraw, tSnap = S.tDraw, S.tSnap
	if tp > S.BURN - 0.2 then return end                        -- the last sparks rise off what is already out
	EM_LINE.count = 70 * floor(lineLit * 10 + 0.5) / 10
	cv:ember_field(c, S.Rl, t, EM_LINE)
	if tp < 0 then
		-- the settle: sparks drawn IN to the hand; the head's embers thrown behind it; a ring of sparks as it closes
		local hand = S.handAt
		local sc = hand and S.handScale or 1
		EM_GATHER.radius = 2.2 * sc
		EM_GATHER.rate = (hand and t >= tDraw and t <= tSnap - 0.06) and 75 or 0
		cv:ember_gather(hand or c, t, -1, tSnap, EM_GATHER)
		EM_HEAD.count = (S.headOn and S.headOn > 0.02 and t < tDraw) and 55 or 0
		cv:embers(S.headAt or c, t, EM_HEAD)
		EM_CLOSE.count = (t >= tDraw and t <= tDraw + 0.05) and 900 or 0
		cv:ember_field(c, S.Rl, t, EM_CLOSE)
		return
	end
	EM_FLOOR.count = 130 * floor(floorLit * 10 + 0.5) / 10
	cv:ember_field(c, 0.955 * S.Rf, t, EM_FLOOR)
	cv:ember_burst(c + UP * 2.5, tp, EM_BLAST)
	if tp <= S.HOLD + 0.1 then
		EM_TOWER.up[1], EM_TOWER.up[2], EM_TOWER.spread = 26 * S.kh, 50 * S.kh, 0.6 * S.pr
		cv:embers(c + UP * 5.0, t, EM_TOWER)
	end
	local hand = S.handAt
	if hand and tp < 0.6 then                                 -- thrown from the hand at the spot
		local sc = S.handScale or 1
		EM_SNAP.hemi = unit(c + UP - hand)
		EM_SNAP.speed[1], EM_SNAP.speed[2], EM_SNAP.count = 8 * sc, 28 * sc, (sc < 1) and 30 or 60
		cv:ember_burst(hand, tp, EM_SNAP)
	end
end

----------------------------------------------------------------------------------------------------
-- RING OF FIRE
----------------------------------------------------------------------------------------------------
--- Ring of Fire round `center` in the flame look. Same parameters and callbacks as PyroFX.RingOfFire: `startAngle` is
--- where the draw begins (RingStartAngle), and `onDraw(point)`, when given, is told every frame where the drawing
--- hand is on the ring, then nil once the circle has closed. -> the ring record { Center, Target, LockAt, Locked,
--- Handle }, or nil when the flame meshes are missing (nothing started: draw the toon ring instead).
function Ring.RingOfFire(character, center, radius, hot, serverT0, startAngle, onDraw)
	if not Ring.Ready() then
		warnOnce("meshes", "PyroDraw or its flame meshes are not in the place: no flame Ring of Fire")
		return nil
	end
	local D = draw()
	local R = tuning().RingOfFire
	radius = radius or R.Radius
	startAngle = startAngle or 0
	hot = hot and true or false
	FPS, LEAN_K = D.Config.FPS, D.Config.LeanK
	local t0 = localClock(serverT0)
	local tDraw, tSettle = R.DrawTime, R.SettleTime
	local tSnap = tDraw + tSettle + R.SnapBeat
	local ring = { Center = center, Target = center, LockAt = t0 + tSnap, Locked = false }
	local reg = registry()
	if character then reg[character] = ring end

	local reach = radius * (hot and (R.HotReach or 1) or 1)   -- where the fire ends: the area the server burns
	local own = isLocal(character)
	local S: any = {
		character = character, own = own,
		tDraw = tDraw, tSettle = tSettle, tSnap = tSnap, HOLD = R.EruptHold, SINK = R.EruptSink, BURN = V.BurnDown,
		Rf = reach, Rl = (hot and not V.HotLineAtReach) and radius or reach,
		kh = hot and V.HotHeight or 1, kR = reach / V.DesignRadius, pr = V.TowerRadius * reach / V.DesignRadius,
		-- the design's frame: its +Y is the caster's side of the circle (startAngle), its draw runs the live way round
		ex = Vector3.new(-sin(startAngle), 0, cos(startAngle)), ey = Vector3.new(cos(startAngle), 0, sin(startAngle)),
		hits = {}, headPh = D.Rand(7, 655, 4) * TAU, dim = reduceFlashing() and V.FlashDim or 1,
		camX = 0, camZ = 0, camNear = false,
	}
	S.line = buildLine(D, S)

	local drawing = onDraw ~= nil
	local drawPoint = bound.RingDrawPoint or function(cc, rr, a0, u)      -- PyroFX.RingDrawPoint (the server's maths)
		local a = a0 + TAU * u
		return cc + Vector3.new(cos(a) * rr, 0, sin(a) * rr)
	end
	local function tell(point)
		local ok, err = pcall(onDraw, point)
		if not ok then
			drawing = false
			warnOnce("ondraw", "onDraw failed: " .. tostring(err))
		end
	end
	local registered = character ~= nil

	local function frame(cv, t, dt)
		-- the circle follows its caster's aim until the server locks it (SteerRing / LockRing move the record)
		local gap = ring.Target - ring.Center
		if gap.Magnitude > 0.01 then
			ring.Center += gap * (1 - exp(-R.SteerEase * (dt or 0)))
		else
			ring.Center = ring.Target
		end
		local c = ring.Center
		local tp = t - tSnap
		if drawing then
			if t < tDraw then
				tell(drawPoint(c, S.Rl, startAngle, clamp(t / tDraw, 0, 1)))
			else
				drawing = false
				tell(nil)
			end
		end
		if registered and tp >= S.HOLD + S.SINK then            -- the live ring leaves the registry here too
			registered = false
			if reg[character] == ring then reg[character] = nil end
		end
		if t <= 0 then return true end
		if V.Prewarm and tp < -0.03 then                        -- the eruption's parts, made a few a frame before it
			local k = clamp(t / max(tSnap - 0.1, 0.05), 0, 1)
			for fam, want in pairs(S.warm) do S.warmNow[fam] = ceil(want * k) end
			D.Prewarm(S.warmNow)
		end
		local cam = workspace.CurrentCamera
		S.camNear = false
		if cam and V.Pocket > 0 then
			local cp = cam.CFrame.Position
			S.camX, S.camZ = cp.X, cp.Z
			local dx, dz = cp.X - c.X, cp.Z - c.Z
			S.camNear = cp.Y - c.Y < 12 and dx * dx + dz * dz < (S.Rf + V.Pocket + 8) ^ 2
		end
		S.headOn = nil
		local lineLit, close = lineFrame(cv, S, c, t, tp)
		handFrame(cv, S, t, tp, dt)
		local towerK, floorLit = 0, 0
		if tp > 0 then
			towerK = towerFrame(cv, S, c, t, tp)
			wallsFrame(cv, S, c, t, tp)
			spiresFrame(cv, S, c, t, tp)
			floorLit = floorFrame(cv, S, c, t, tp)
			frontFrame(cv, S, c, t, tp)
		end
		lightsFrame(cv, S, c, t, tp, lineLit, close, towerK)
		embersFrame(cv, S, c, t, tp, lineLit, floorLit)
		return tp < S.BURN + 0.05
	end

	local handle = D.Play("PyroRing", frame, {
		Clock = function() return os.clock() - t0 end, own = own, hot = hot, density = bound.Density,
		MaxLife = tSnap + V.BurnDown + 5,
		OnEnd = function()
			if drawing then
				drawing = false
				tell(nil)
			end
			if registered and reg[character] == ring then reg[character] = nil end
		end,
	})
	planCast(D, S, handle.Canvas)
	handle.Plan = S.plan
	ring.Handle = handle
	return ring
end

return Ring
