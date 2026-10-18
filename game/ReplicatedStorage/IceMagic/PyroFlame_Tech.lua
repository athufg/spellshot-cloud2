--[[
	PyroFlame_Tech  (ModuleScript, CLIENT)  ->  ReplicatedStorage/IceMagic/PyroFlame_Tech        Pyro Phase 3, 2026-10-05

	The "flame" look (V1 "Layered blaze+", flames only) of Pyro's two Techniques, drawn with PyroDraw from the Phase 3
	mesh library (ReplicatedStorage.FireMagicMeshes.Flame). Ported from the owner-confirmed Blender pieces
	vis2026/detonate/detonate_r2.py and vis2026/scorching_lash/scorching_lash_r2.py, on the LIVE beats and call contracts
	of PyroFX (2026-09-24 source, unchanged on 2026-10-05). Nothing here is mechanical: no remote, no raycast that decides
	anything (the rope's floor ray is the live one), every gameplay number is read from PyroFX.Tuning.

	DROP-IN EQUIVALENTS (same parameters, same nil returns, same attributes read, same first / third person rules):
	    Tech.DetonateFlick(character, t0)            = PyroFX.DetonateFlick
	    Tech.DetonateMark(d)                         = PyroFX.DetonateMark      { Character, Victim, Position, T0, Fuse }
	    Tech.DetonateBlast(d)                        = PyroFX.DetonateBlast     { Character, Victim, Position, Amount, Scale, Lethal, T0 }
	                                                   THE FIRE ONLY: it never draws KABOOM! (see WIRING 3)
	    Tech.DetonateFizzle(d)                       = PyroFX.DetonateFizzle    { Victim, Position }
	    Tech.LashHold(character, on, t0, isOwn)      = PyroFX.LashHold
	    Tech.Lash(character, t0, dir, isOwn)         = PyroFX.Lash
	    Tech.LashHit(d)                              = PyroFX.LashHit           { Character, Victims, Positions }
	    Tech.WatchBurnStacks()                       = PyroFX.WatchBurnStacks   (once; see WIRING 2)
	  the factories behind them, for a look chosen per effect inside PyroFX's own locals:
	    Tech.StartMark(model, expires, fuse, landing, own)   = startMark   (own: the local player's Detonate; optional)
	    Tech.WatchMark(model)                                = watchMark
	    Tech.StartBurn(model)                                = startBurn
	    Tech.WhipFor(character, isOwn) -> ctl | nil          = whipFor
	    Tech.Share{ Marks, LastMark, Whips, Burns }          the four state tables both looks must share (WIRING 1)
	    Tech.FX, Tech.WHIP                                   the visual numbers (tune here; nothing mechanical)

	WIRING (PyroFX stays the only module the callers know; require this one lazily in PyroFX's libs(), client only)
	  1. Once, right after requiring it:  Flame.Share({ Marks = markControllers, LastMark = lastMark, Whips = whips,
	     Burns = burnControllers }).  The controllers made here carry the SAME fields the toon code reads and writes
	     (mark: Expires, Kill, FizzleAsked; whip: Own, Holding, CrackAt, CrackStarted, Recoiled, OutAt, Born, From, Cracked,
	     Dir, TrailNext, Kill; burn: presence), so either look's LashHold / Lash / DetonateBlast / DetonateFizzle drives a
	     controller the other look made, and a running effect keeps the look it started with. Without Share the two
	     looks keep separate books: fine while the look never changes, a double whip / crown if it flips mid-effect.
	  2. Branch where the digest says, on look() == "flame":
	       PyroFX.DetonateFlick      -> return Flame.DetonateFlick(character, t0)
	       startMark (local)         -> return Flame.StartMark(model, expires, fuse, landing)      [covers DetonateMark,
	                                    watchMark and so the late joiner off RX_Primed; PyroFX.DetonateMark needs no edit]
	       PyroFX.DetonateFizzle     -> no edit (it only sets FizzleAsked on the shared controller)
	       whipFor (local)           -> if not whips[character] then return Flame.WhipFor(character, isOwn) end
	                                    [LashHold and Lash then need no edit: they only write the controller's fields]
	       PyroFX.LashHit            -> return Flame.LashHit(d)
	       startBurn (local)         -> return Flame.StartBurn(model)      [WatchBurnStacks is called ONCE at load, so the
	                                    look must be chosen here, per body, not by delegating WatchBurnStacks]
	     (Delegating the public functions one for one works too, with Share; Tech.WatchBurnStacks is then a full watcher
	     that always draws flames.)
	  3. PyroFX.DetonateBlast keeps running for KABOOM!: on the flame look call Flame.DetonateBlast(d) and let the live
	     closure go on WITHOUT its star and embers (blast = nil, count = 0: takeEmber("DetonateBlast") and the debris
	     are the only toon pieces to skip) so the DetonateWord mesh is still taken, placed on the live BlastScale
	     1.0..1.8 / Step / Above / Tilt maths and x0.75 under Reduce Flashing, exactly as today. The live lines that set
	     ctl.Kill and return in your own first person stay first (this module's copy of them is then a no-op).
	  Nothing else of the toon look may run beside these: no ImmolatePop (flick snap, landing pop, point pops, hit
	  pops), no DetonateCrown2 / DetonateCrownFlame, no DetonateBlast star or FireballEmber debris, no LashWhipLink /
	  LashWhipTip, no LashBurn (path and stacks), no FireballBurst at the crack. The Burn crest and bars (StatusReactions
	  / BarFX), Callouts and the HUD are other modules and are not touched.

	CLOCKS. As live: every Detonate and Lash clock and the burn flames run on VFXLibrary.ShotTimeScale(); the fuse is
	the server's real seconds. Effects run on PyroDraw.Play (its own render step at Camera + 4, PyroFX's priority, so a
	viewmodel arm read here is this frame's), each in a pcall with its canvas destroyed when it ends.

	THINNING. PyroDraw's own (Settings.EffectDensity, x0.6 for other players' effects under ThinEnemyVFX) plus, under
	the live rule (density < 0.75, i.e. EffectDensity < 0.75 or ThinEnemyVFX and not own): the curtain 27 -> 18
	tongues, every other link tongue and path flame, 5 crown teeth of 9, no side licks on the stack flames.

	NOT LIKE THE BLENDER PIECES (beside PyroDraw's own limits: rigid instances, 3-4 flicker phases, ParticleEmitter
	embers that keep none of their source's speed, an integer hash for the variation):
	  * the pops, the blast, the crack and the hit pops are PyroDraw's burst builder as it is (the point pops and the
	    3rd..5th hit pop at half its licks);
	  * a curtain tongue is ONE rigid flame from its root toward where its tip was (it tilts, it cannot bend along
	    the path the rope took); the rope's past is closed-form through the driven sweep (live's whipSwept) and the
	    rope itself after the Snap; points on the rope are taken straight between joints (the piece: a spline);
	  * the rope is 18 Link pieces joint to joint (beaded, not one tube); the link tongues' speed is eased over 0.05 s
	    (the live rope steps at 120 Hz, not per frame);
	  * the recoil's tip streak is RecoilSpan of path in three pieces (the piece: 0.2 s as one bent ribbon);
	  * the crown's circlet is the library Hoop (2 phases, no streaks running round it); the crown is seated on the
	    ROOT (live's socket, CrownY) rather than on the Head part;
	  * the blast, the landing pop and the hit pops are turned to the viewer once, when they start (live turns its
	    flat star every frame); a point's pop stays where the point was;
	  * the rope starts on the floor and keeps no speed there (WHIP.Calm, the piece's rope; live's flings up).
	No HOT variant exists for these two abilities (live has none either). Never run in Studio: checked headless only
	(phase3/harness_tech: run_tech.py, paint_tech.py).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tech = {}

----------------------------------------------------------------------------------------------------
-- THE VISUAL NUMBERS (nothing here is read by the server; the beats are PyroFX.Tuning's)
----------------------------------------------------------------------------------------------------
-- The rope: PyroFX's local WHIP table, copied (the live simulation's numbers; tune both or neither).
local WHIP = {
	Links = 18, S0 = 1.0, S1 = 0.45,
	Hang = 6,
	Gravity = 60, Damp = 0.985, Step = 1 / 120, MaxSteps = 4, Iter = 6,
	Ground = 0.14, GroundRay = 14,
	Creep = 4,
	PopIn = { 0.4, 1.15, 1.0 }, Out = 0.3,
	Blend = 0.05, Snap = 0.30, Recoil = 0.62, FollowThru = 12,
	GrowU = 0.33, Bend = 45, Drop = 1.5,
	OwnGrip = 1.25, OwnScale = 0.7,
	-- THE PIECE'S ROPE (the one difference from live's, as its notes say; false = live's exactly): it starts hanging
	-- straight down to the floor with the rest laid back along it, and a link on the floor keeps no speed. Live starts
	-- its lower links UNDER the floor and keeps their vertical speed there, which flings them up for a few frames on
	-- every press (and on every step up); under the flames that reads as a burst of long tongues and a 20-stud streak.
	Calm = true,
}
Tech.WHIP = WHIP

local FX = {
	Floor = 3.0,                 -- studs from a root down to the floor it stands on (where the floor lights sit)

	-- DETONATE ------------------------------------------------------------------------------------------------
	-- the flick (dt_flick). FlickFP: live SnapFP / SnapTP = FlickFP = 0.4, the whole flick on your own viewmodel
	FlickFP = 0.4, FlickEnd = 0.45, SnapSize = 0.75,
	-- the mark landing (dt_land): the kit burst at LandSize on the chest (live Chest over the root), LandStep toward
	-- the viewer
	Chest = 0.55, LandSize = 1.3, LandStep = 0.9,
	-- the crown (dt_crown, round 1's): PopIn / PopOut are live's (PopOut with the piece's closing 0), Grace and
	-- Timeout live's. CrownY over the root: the piece sits it 0.8 over the head's top (live CrownY 2.55 is the toon
	-- band's). CrownFar: up to 1 + CrownFar times as big for a viewer CrownFarTo studs away (the piece's open
	-- question 3; 0 switches it off)
	PopIn = { 0.4, 1.25, 1.0 }, PopOut = { 1.0, 1.25, 0.4, 0.0 }, Grace = 0.5, Timeout = 1.5,
	CrownY = 2.9, CrownR = 1.45, CrownFar = 0.45, CrownFarFrom = 14, CrownFarTo = 40,
	-- the three flame points: degrees round from the viewer's side toward screen right, height, the third of the
	-- fuse each burns in (screen left, screen right, the tall middle one last = live LickOrder), lean out
	Points = { { -62, 1.75, 0, -1 }, { 62, 1.75, 1, 1 }, { 0, 2.35, 2, 0 } },
	PointLeft = 0.4, PointPop = 0.7,
	TeethDeg = { -150, -120, -90, -30, 30, 90, 120, 150, 180 },
	TeethH = { 0.36, 0.42, 0.36, 0.46, 0.46, 0.36, 0.42, 0.36, 0.44 },
	-- the blast (dt_blast): the kit burst at BlastSize x scale, scale BlastScale[1]..[2] with d.Scale. r2 asks 2.0 at
	-- 48 damage (live 1.8): the FIRE only; KABOOM! stays on PyroFX's own 1.8. Flung tongues: live Debris / DebrisBig
	BlastScale = { 1.0, 2.0 }, BlastSize = 2.6, BlastStep = 0.6, BigAt = 30, Flung = 6, FlungBig = 10,
	ReduceFlashing = 0.75,

	-- SCORCHING LASH ------------------------------------------------------------------------------------------
	RopeW = 0.54,                -- the rope's hull across at link scale 1 (the piece: radius 0.27)
	Curtain = 27, CurtainThin = 18, CA = 0.045, CK = 9,     -- tongues (3 per 2 links); the oldest fire shown; samples
	-- the path flames: every TrailStep degrees (live 10; the piece 7.5 = 21 flames), the piece's Trail list (0.33 s)
	TrailStep = 7.5, TrailScale = 0.8, TrailH = 4.2,
	Trail = { 0.5, 1.15, 1.0, 0.95, 0.9, 0.8, 0.65, 0.45, 0.2, 0.0 },
	CrackSize = 3.3, CrackLife = 0.36, RecoilSpan = 0.07,
	-- a hit: live's seat (HitUp over the UpperTorso, HitChest over a reported root, HitOut toward the caster)
	HitSize = 1.6, HitLife = 0.27, HitUp = 0.1, HitOut = 0.7, HitChest = 0.55,
	-- the burn stacks: live's seats and growth; BurnH the flame's height at scale 1 (r2: 2.75); lean out per seat
	BurnSlots = {
		{ Vector3.new(1.55, 0.7, 0.1), 1.0, 1 }, { Vector3.new(-1.55, 0.7, 0.1), 1.0, -1 }, { Vector3.new(0, 0.8, 1.1), 1.3, 0 },
	},
	BurnGrow = { 1.0, 1.08, 1.16 }, BurnScale = 0.9, BurnPop = { 0.4, 1.2, 1.0 }, BurnOut = 4 / 30, BurnH = 2.75,
}
Tech.FX = FX

----------------------------------------------------------------------------------------------------
-- maths
----------------------------------------------------------------------------------------------------
local sin, cos, abs, floor, max, min, sqrt, exp, pi = math.sin, math.cos, math.abs, math.floor, math.max, math.min,
	math.sqrt, math.exp, math.pi
local TAU = 2 * pi
local UP = Vector3.new(0, 1, 0)
local ZERO = Vector3.new(0, 0, 0)
local FWD = Vector3.new(0, 0, -1)

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function sm(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function sst(a, b, x)
	return sm((x - a) / max(b - a, 1e-9))
end

local function unit(v, fallback)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return fallback or UP
end

local function flatUnit(v, fallback)
	local h = Vector3.new(v.X, 0, v.Z)
	return h.Magnitude > 1e-3 and h.Unit or fallback
end

local function easeOutQuad(x)
	x = clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

--- The pieces' seq(): a 30 fps list, interpolated; `after` once it has run out. (PyroFX's own seq() steps.)
local function seqL(list, age, after)
	local x = age * 30
	if x <= 0 then return list[1] end
	local i = floor(x)
	if i >= #list - 1 then return after end
	return list[i + 1] + (list[i + 2] - list[i + 1]) * (x - i)
end

--- Thrown with v0, slowed by drag kd, pulled down by g (the kit's drag()). -> position, velocity
local function drag(p0, v0, age, kd, g)
	local e = 1 - exp(-kd * age)
	return p0 + v0 * (e / kd) + UP * ((g / (kd * kd)) * e - (g / kd) * age), v0 * exp(-kd * age) - UP * ((g / kd) * e)
end

--- The os.clock() moment that a server-time stamp corresponds to on this machine (PyroFX's localClock).
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

--- A short history of a moving point, for the builders that look back along its path (fire_tail, wisps, hand_flame).
local function histNew()
	return { t = {}, p = {}, n = 0 }
end

local function histPush(h, t, p)
	local n = h.n
	if n > 0 and t <= h.t[n] then
		h.p[n] = p
		return
	end
	n += 1
	h.t[n], h.p[n] = t, p
	if n > 192 then                                       -- keep the newest 128
		table.move(h.t, 65, n, 1)
		table.move(h.p, 65, n, 1)
		for i = n - 63, n do
			h.t[i], h.p[i] = nil, nil
		end
		n -= 64
	end
	h.n = n
end

local function histAt(h, t)
	local n = h.n
	if n == 0 then return nil end
	local ht, hp = h.t, h.p
	if t >= ht[n] then return hp[n] end
	if t <= ht[1] then return hp[1] end
	local i = n - 1
	while i > 1 and ht[i] > t do i -= 1 end
	return hp[i]:Lerp(hp[i + 1], (t - ht[i]) / max(ht[i + 1] - ht[i], 1e-6))
end

----------------------------------------------------------------------------------------------------
-- the libraries (lazy: this module is inert at require) and the tables made from them
----------------------------------------------------------------------------------------------------
local PD, VFXLibrary, Viewmodel, Settings, T = nil, nil, nil, nil, nil
local R = nil                                             -- PD.Rand(seed, k, column) = the kit's rr(k, column, seed)

-- the links' scales, grip to tip, and each joint's share of the length (PyroFX's whipScales / whipFractions)
local whipScales, FR = {}, { [0] = 0 }
do
	local total = 0
	for i = 1, WHIP.Links do
		whipScales[i] = WHIP.S0 + (WHIP.S1 - WHIP.S0) * (i - 1) / max(1, WHIP.Links - 1)
		total += whipScales[i]
	end
	local acc = 0
	for i = 1, WHIP.Links do
		acc += whipScales[i]
		FR[i] = acc / total
	end
end

local function runit(k, seed, c0)
	local z = R(seed, k, c0) * 2 - 1
	local a = R(seed, k, c0 + 1) * TAU
	local r = sqrt(max(0, 1 - z * z))
	return Vector3.new(-r * cos(a), z, r * sin(a))
end

--- The kit's row_vary(n, seed, vary) without its sway (ph is the sway's phase): [0 .. n-1] = { h, w, lt, ln, ds, dn,
--- ph, tall }.
local function rowVary(n, seed, vary)
	local v = max(vary, 0)
	local v1 = min(v, 1)
	local sd = seed + 17
	local kA, kB = max(2, floor(n / 11 + 0.5)), max(3, floor(n / 4.7 + 0.5))
	local pA, pB = R(sd, 1, 5) * TAU, R(sd, 2, 5) * TAU
	local out = {}
	for i = 0, n - 1 do
		local s = i / n * TAU
		local h = 1 + v * (0.25 * (0.62 * sin(kA * s + pA) + 0.38 * sin(kB * s + pB)) + 0.15 * (R(sd, i, 6) * 2 - 1))
		local tall = R(sd, i, 9) < 0.14 * v1
		local gap = R(sd, i, 11) < 0.12 * v1 and not tall
		local q = R(sd, i, 10)
		if tall then h = max(h, 0.95) * (1 + v1 * (0.40 + 0.45 * q)) end
		if gap then h = h * (1 - v1 * (0.55 + 0.20 * q)) end
		h = clamp(h, 0.18, 2.8)
		local w = h ^ 0.5 * (1 + min(v, 1.5) * 0.26 * (R(sd, i, 12) * 2 - 1))
		if tall then w = w * (1 - 0.18 * v1) elseif gap then w = w * (1 + 0.2 * v1) end
		out[i] = {
			h = h, w = clamp(w, 0.3, 1.9), tall = tall, ph = R(sd, i, 7) * TAU,
			lt = v * 0.19 * (R(sd, i, 13) * 2 - 1), ln = v * 0.09 * (R(sd, i, 14) * 2 - 1),
			ds = v1 * 0.30 * (R(sd, i, 15) * 2 - 1), dn = v1 * 0.14 * (R(sd, i, 8) * 2 - 1),
		}
	end
	return out
end

local LINKS = {}                                          -- [0 .. Links-1]: each link tongue's constants
local CURTAINS = {}                                       -- [M] = the curtain's constants for M tongues
local TRV = nil                                           -- the path flames' variation

local function statics()
	local n = WHIP.Links
	for k = 0, n - 1 do
		local frc = (FR[k] + FR[k + 1]) * 0.5
		-- two ways along one diagonal of the caster's (so none of the hanging part's licks points at a camera behind)
		local oa = math.rad(48) + ((k % 4 < 2) and 0 or pi) + (R(91, k, 6) - 0.5) * 0.9
		LINKS[k] = {
			c = cos(oa), s = sin(oa), ru = runit(k, 91, 5) * 0.22, h0 = 0.7 + 0.55 * R(91, k, 2), ph = R(91, k, 1) * TAU,
			sc = WHIP.S0 + (WHIP.S1 - WHIP.S0) * frc, base = 0.4 + 0.6 * sst(0, 0.25, frc), hang = 1 - sst(0.55, 0.8, frc),
		}
	end
	local L = T.ScorchingLash
	TRV = rowVary(floor((L.SweepTo - L.SweepFrom) / FX.TrailStep + 1e-6) + 1, 23, 1.0)
end

local function curtainStatic(M)
	local C = CURTAINS[M]
	if C then return C end
	local n = WHIP.Links
	local rv = rowVary(M, 91, 1.6)
	C = { n = M }
	for j = 0, M - 1 do
		local v = rv[j]
		local s = clamp((j + 0.5 + 0.9 * v.ds) * (n / M), 0.3, n - 0.05)
		local i0 = min(floor(s), n - 1)
		local fw = s - i0
		local fr = FR[i0] + (FR[i0 + 1] - FR[i0]) * fw
		local kind = 2
		if v.tall then kind = 3 elseif R(91, j, 2) > 0.75 then kind = "lick" end
		C[j] = {
			i0 = i0, fw = fw, sc = WHIP.S0 + (WHIP.S1 - WHIP.S0) * fr, h = v.h, w = v.w, lt = v.lt, ln = v.ln, phS = v.ph,
			kind = kind, phF = R(91, j, 1) * TAU,
			len = (2.2 + 6.6 * fr ^ 0.9) * v.h * (0.78 + 0.5 * R(91, j, 5)) * sst(0, 0.1, fr),
			upf = (0.8 + 0.9 * fr ^ 0.5) * (0.55 + 1.9 * R(91, j, 3) ^ 2) * v.h,
		}
	end
	CURTAINS[M] = C
	return C
end

local function libs()
	if PD then return end
	local ice = ReplicatedStorage:WaitForChild("IceMagic")
	VFXLibrary = require(ice:WaitForChild("VFXLibrary"))
	Viewmodel = require(ice:WaitForChild("Viewmodel"))
	Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	T = require(ice:WaitForChild("PyroFX")).Tuning
	local draw = require(ice:WaitForChild("PyroDraw"))
	R = draw.Rand
	statics()
	PD = draw
end

local function fxFolder()
	return workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
end

--- The viewer: -> the flat unit vector from `c` toward the camera, the viewer's screen right, the flat distance.
local function view(c, fallback)
	local d = workspace.CurrentCamera.CFrame.Position - c
	local f = flatUnit(d, fallback or FWD)
	return f, UP:Cross(f), sqrt(d.X * d.X + d.Z * d.Z)
end

--- The kit's burst with a share of its licks and wisps (the pieces' small pops: a mini pop from the same pool).
local function pop(cv, center, u, o, share)
	local d = cv.Density
	cv.Density = d * share
	cv:burst(center, u, o)
	cv.Density = d
end

-- the state both looks share (Tech.Share swaps PyroFX's own tables in)
local marks = {}                                          -- [victim model] = the mark drawn on it
local lastMark = setmetatable({}, { __mode = "k" })       -- [victim model] = the Expires of the newest mark drawn on it
local whips = {}                                          -- [character] = the whip being drawn on it
local burns = {}                                          -- [model] = the burn flames on it

--- PyroFX's own markControllers, lastMark, whips and burnControllers, so both looks keep one set of books.
function Tech.Share(t)
	if type(t) ~= "table" then return end
	marks = t.Marks or marks
	lastMark = t.LastMark or lastMark
	whips = t.Whips or whips
	burns = t.Burns or burns
end

local LO = { t = 0, ph = 0, range = nil }                 -- fire_light's options, reused

----------------------------------------------------------------------------------------------------
-- DETONATE: the flick
----------------------------------------------------------------------------------------------------
-- dt_flick. A flame kindles on the fingertips and SWELLS through the wind-up (sparks drawn in), is thrown off by the
-- backhand as a streak along the arc the hand took, a snap on the Trigger thrown along the live flick's throw (0.65
-- arm + 0.35 swing + 0.22 up), embers and peeling tongues. Live draws nothing before the Trigger; the wind-up flame
-- is the piece's (it starts when the broadcast arrives, so a late one joins it part-way). Your own, in first person:
-- on the viewmodel's fingertip and x FlickFP, as live.
local EM_GATHER = { [false] = { id = "gather", rate = 70, radius = 1.5, life = 0.18 },
	[true] = { id = "gather", rate = 70, radius = 1.5 * FX.FlickFP, life = 0.18, size = 0.09 * FX.FlickFP } }
local EM_FLICK = { [false] = { id = "flick", count = 130, life = { 0.25, 0.6 }, out = { 1.5, 6.0 }, up = { 1.0, 5.0 }, spread = 0.2,
	size = { 0.05, 0.12 } },
	[true] = { id = "flick", count = 60, life = { 0.2, 0.45 }, out = { 0.6, 2.4 }, up = { 0.4, 2.0 }, spread = 0.08,
		size = { 0.02, 0.05 } } }

function Tech.DetonateFlick(character, t0)
	libs()
	if not (character and character.Parent) then return end
	local D = T.Detonate
	local own = isLocal(character)
	local fp = own and firstPerson()
	local K = fp and FX.FlickFP or 1
	local start = localClock(t0)
	local hist = histNew()
	local lastTip, fling, snapAt = nil, nil, nil
	local function hand(tq)
		return histAt(hist, tq)
	end
	local HF = { size = 0, tongues = 3, seed = 13 }
	local TL = { width = 0, span = 0.085, t_min = 0.2, rise = 6 * K, seed = 4 }
	local WS = { rate = 65, life = 0.36, scale = 0.5 * K, seed = 14 }
	local BU = { size = FX.SnapSize * K, t = 0, seed = 730, back = UP, sparks = 0 }
	PD.Play("PyroFlick", function(cv, now)
		local tc = (now - start) * VFXLibrary.ShotTimeScale()         -- seconds of the clip, from the press
		local age = tc - D.Trigger
		if age >= FX.FlickEnd or not character.Parent then return false end
		-- the fingertip, and the way the arm points (live)
		local tip, arm
		local armCF = fp and Viewmodel.GetArmCFrame("R")
		if armCF then
			tip, arm = (armCF * CFrame.new(0, 0, -1.25)).Position, armCF.LookVector
		else
			local hp = character:FindFirstChild("RightHand")
			if not hp then return false end
			local upper = character:FindFirstChild("RightUpperArm")
			tip = (hp.CFrame * CFrame.new(0, -0.25, 0)).Position
			arm = upper and (tip - upper.Position) or -hp.CFrame.UpVector
		end
		histPush(hist, tc, tip)
		if age < 0 then
			lastTip = tip
		elseif not fling then
			local swing = lastTip and (tip - lastTip) or ZERO
			fling = unit((arm.Magnitude > 1e-3 and arm.Unit * 0.65 or ZERO)
				+ (swing.Magnitude > 1e-3 and swing.Unit * 0.35 or ZERO) + Vector3.new(0, 0.22, 0))
			snapAt = tip + unit(arm, fling) * (0.2 * K)
		end
		local trig = D.Trigger
		if tc > 0.03 and tc < trig + 0.08 then
			local g = sm((tc - 0.03) / 0.10) * (1 - sm((tc - trig) / 0.07))
			if g > 0.05 then
				HF.size = (0.34 + 0.30 * sm((tc - 0.05) / 0.14)) * g * K
				cv:hand_flame(hand, tc, HF)
			end
		end
		cv:ember_gather(tip, tc, 0.03, trig - 0.04, EM_GATHER[fp])
		if tc > 0.2 and tc < trig + 0.2 then
			local w = 0.66 * (1 - sm((tc - trig - 0.05) / 0.15))
			if w > 0.05 then
				TL.width = w * K
				cv:fire_tail(hand, tc, TL)
			end
		end
		cv:wisps(hand, tc, trig - 0.035, trig + 0.03, WS)
		if tc >= trig - 0.05 and tc <= trig + 0.05 then cv:embers(tip, tc, EM_FLICK[fp]) end
		if snapAt then
			BU.t, BU.back = tc, fling
			cv:burst(snapAt, age / 0.2, BU)
		end
		return true
	end, { Clock = os.clock, own = own })
end

----------------------------------------------------------------------------------------------------
-- DETONATE: the mark (the flame crown), its landing pop, the fizzle
----------------------------------------------------------------------------------------------------
-- dt_crown / dt_land / dt_fizzle, on live's startMark: the same controller, the same reading of RX_Primed /
-- RX_Primed_Expires each frame (a flag that goes down early fizzles it, one that goes down at its end waits Grace for
-- the blast, a fizzle broadcast is taken only once the flag is down, Timeout), hidden on your own body in first
-- person, turned about the vertical to each viewer.
--   the crown   a closed ring of flame (one Hoop) of CrownR, 9 low teeth, and three BIG flame points on the viewer's
--               side that burn DOWN one per third of the fuse (screen left, screen right, the tall middle one last) to
--               PointLeft, then pop off (a mini burst + sparks): 3, 2, 1. Sparks are drawn in over the last third of a
--               second. One light.
--   landing     the kit burst (LandSize) on the chest, a step toward the viewer; not for a mark found already running
--   the fizzle  the crown plays PopOut and cools, the countdown stopped where it was; three cooled wisps rise off it
--               and a few dim embers fall. The controller is given up when PopOut is over (as live); the wisps go on
--               for half a second more.
local EM_CROWN = { id = "crown", rate = 55, radius = 2.3, life = 0.2 }
local EM_POINT = {
	{ id = "pop1", count = 10, speed = { 3, 10 }, life = { 0.2, 0.45 }, size = { 0.05, 0.1 } },
	{ id = "pop2", count = 10, speed = { 3, 10 }, life = { 0.2, 0.45 }, size = { 0.05, 0.1 } },
	{ id = "pop3", count = 10, speed = { 3, 10 }, life = { 0.2, 0.45 }, size = { 0.05, 0.1 } },
}
local EM_FIZZLE = { id = "fizzle", count = 16, speed = { 1.5, 6.0 }, bias = Vector3.new(0, -0.1, 0), g = 26, kd = 3.0,
	life = { 0.3, 0.6 }, size = { 0.05, 0.1 } }
local FIZZLE = { { 0.03, 0.0, 0.0, 1.9 }, { 0.08, 0.7, 0.3, 1.2 }, { 0.12, -0.6, -0.4, 1.1 } }     -- delay, right, toward, height

local function landingPop(chest, own)
	local f, _, dist = view(chest)
	local at = chest
	if dist > FX.LandStep * 2 then at = chest + f * FX.LandStep end
	local born = os.clock()
	local BU = { size = FX.LandSize, t = 0, seed = 770, back = unit(f + UP * 0.5), sparks = 0 }
	local EB = { id = "land", count = 18, speed = { 4, 13 }, hemi = f, life = { 0.2, 0.5 }, size = { 0.05, 0.11 } }
	PD.Play("PyroMarkLand", function(cv, now)
		local a = (now - born) * VFXLibrary.ShotTimeScale()
		if a >= 0.5 then return false end
		BU.t = a
		cv:burst(at, a / 0.2, BU)
		cv:ember_burst(at, a, EB)
		return true
	end, { Clock = os.clock, own = own })
end

--- The Flame Crown on `model` for the mark that goes off at server time `expires`, `fuse` seconds after it landed.
--- `landing`: pop on the chest (not for a mark found already running). `own`: the local player's Detonate.
local function startMark(model, expires, fuse, landing, own)
	libs()
	local old = marks[model]
	if old then
		if abs(old.Expires - expires) < 0.05 then return end       -- the broadcast and the attributes: one mark
		old.Kill = true
	end
	fuse = max(fuse, 0.05)
	local ctl = { Expires = expires, Start = localClock(expires - fuse), Born = os.clock(), Shown = {}, PopAt = {}, Flame = true }
	marks[model] = ctl
	lastMark[model] = expires
	local root = model:FindFirstChild("HumanoidRootPart")
	local hideOwn = isLocal(model)
	if landing and root and not (hideOwn and firstPerson()) then
		landingPop(root.Position + Vector3.new(0, FX.Chest, 0), own == true)
	end
	local sd = floor(expires * 7) % 5
	local SF = { seed = 0, lean = ZERO, side = ZERO, width = nil, layers = 2, cool = 0 }
	local HO = { cool = 0 }
	local FZ = { cool = 0, ph = 0, t = 0 }
	local BU = { size = FX.PointPop, t = 0, seed = 760, light = false, sparks = 0 }
	local function release()
		if marks[model] == ctl then marks[model] = nil end
	end
	PD.Play("PyroMark", function(cv, now)
		root = model.Parent and model:FindFirstChild("HumanoidRootPart")
		if ctl.Kill or not root then return false end
		local ts = VFXLibrary.ShotTimeScale()
		-- whether the victim is still flagged with THIS mark (live, word for word)
		local on = model:GetAttribute("RX_Primed") == true
			and abs((tonumber(model:GetAttribute("RX_Primed_Expires")) or 0) - expires) < 0.05
		if on then
			ctl.Seen = true
		elseif ctl.Seen and not ctl.OffAt then
			ctl.OffAt = now
		end
		local due = ctl.Start + fuse
		if not ctl.FizzleAt then
			if (ctl.OffAt and (ctl.OffAt < due - 0.15 or now - ctl.OffAt > FX.Grace))
				or (ctl.FizzleAsked and not on) or now > due + FX.Timeout then
				ctl.FizzleAt = now
				ctl.FizzleU = (now - ctl.Start) / fuse                  -- the countdown stops where it was
			end
			ctl.FizzleAsked = nil
		end
		local s = seqL(FX.PopIn, (now - ctl.Born) * ts, 1)
		local u = (now - ctl.Start) / fuse
		local cool = 0
		local gone = nil
		if ctl.FizzleAt then
			gone = (now - ctl.FizzleAt) * ts
			if gone > 0.8 then return false end
			local k = seqL(FX.PopOut, gone, 0)
			if k < 0.03 then release() end                              -- live gives the controller up here
			s *= k
			cool = 0.3 * clamp(gone / 0.1, 0, 1)
			u = ctl.FizzleU
		end
		if hideOwn and firstPerson() then return true end              -- it sits round your own eye
		local c = (root.CFrame * CFrame.new(0, FX.CrownY, 0)).Position
		local f, r = view(c, flatUnit(root.CFrame.LookVector, FWD))
		local cam = workspace.CurrentCamera.CFrame.Position
		local far = 1 + FX.CrownFar * sst(FX.CrownFarFrom, FX.CrownFarTo, (cam - c).Magnitude)
		local sc = s * far
		local tm = now
		if s >= 0.03 then
			local rad = FX.CrownR * sc
			HO.cool = cool
			cv:hoop(c, rad, tm, HO)
			-- the three points first (they are the count): each burns DOWN toward its foot over its third of the fuse
			for i, pt in ipairs(FX.Points) do
				local a = math.rad(pt[1])
				local o = f * cos(a) + r * sin(a)
				local foot = c + o * rad + UP * (0.12 * sc)
				local burnt = u * 3 - pt[3]
				if burnt >= 1 then
					if ctl.Shown[i] and not ctl.FizzleAt then
						ctl.Shown[i] = false
						ctl.PopAt[i] = ctl.Start + fuse * (pt[3] + 1) / 3
						ctl.PopP = ctl.PopP or {}
						ctl.PopP[i] = foot + UP * 0.3
					end
				else
					ctl.Shown[i] = true
					local w = 1 - (1 - FX.PointLeft) * max(0, burnt)
					local H = pt[2] * sc
					SF.seed, SF.lean, SF.side = sd + 20 + i, o * 0.16 + r * (0.2 * pt[4]), UP:Cross(o)
					SF.width, SF.layers, SF.cool = 0.56 * H * (0.6 + 0.4 * w), 3, cool + 0.08 * max(0, burnt)
					cv:standing_flame(foot, H * w, tm, SF)
				end
			end
			local thin = cv.Density < 0.75
			SF.width, SF.layers, SF.cool = nil, 2, cool
			for i, deg in ipairs(FX.TeethDeg) do
				if not (thin and i % 2 == 0) then
					local a = math.rad(deg)
					local od = f * cos(a) + r * sin(a)
					SF.seed, SF.lean, SF.side = sd + 5 + 3 * i, od * 0.22, UP:Cross(od)
					cv:standing_flame(c + od * rad + UP * (0.1 * sc), FX.TeethH[i] * sc, tm, SF)
				end
			end
			LO.t, LO.ph, LO.range = tm, sd, nil
			cv:fire_light(c + UP * 0.6, 240 * sc, LO)
			if not gone then
				local tq = now - ctl.Start
				cv:ember_gather(c + UP * 0.4, tq, fuse - 0.36, fuse - 0.04, EM_CROWN)
			end
		end
		-- a point popping off
		for i = 1, 3 do
			local at = ctl.PopAt[i]
			if at then
				local a = (now - at) * ts
				if a < 0.5 then
					BU.t, BU.seed = a, 760 + 7 * i
					pop(cv, ctl.PopP[i], a / 0.2, BU, 0.45)
					cv:ember_burst(ctl.PopP[i], a, EM_POINT[i])
				end
			end
		end
		if gone then
			for j, w in ipairs(FIZZLE) do
				local a = gone - w[1]
				local life = 0.62 - 0.1 * (j - 1)
				if a > 0 and a < life then
					local q = a / life
					local g = max(0, sin(pi * min(1, q * 1.1 + 0.1))) ^ 0.8
					FZ.cool, FZ.ph, FZ.t = 0.37 + 0.3 * q, 2.1 * j, tm
					cv:flame(2, c + r * w[2] + f * w[3] + UP * (0.2 + 3.2 * a + 2.0 * a * a), UP, w[4] * g * (1 + 0.7 * q),
						0.55 * w[4] / 1.9 * g * (1 - 0.5 * q), FZ)
				end
			end
			cv:ember_burst(c, gone, EM_FIZZLE)
		end
		return true
	end, { Clock = os.clock, own = own == true, MaxLife = fuse + 8, OnEnd = release })
end
Tech.StartMark = startMark

--- A mark on the victim's RX_Primed attributes that nothing is drawing (a late joiner, a broadcast that never came).
local function watchMark(model)
	if model:GetAttribute("RX_Primed") ~= true then return end
	local expires, total = model:GetAttribute("RX_Primed_Expires"), model:GetAttribute("RX_Primed_Total")
	if type(expires) ~= "number" or type(total) ~= "number" then return end
	local last = lastMark[model]
	if last and abs(last - expires) < 0.05 then return end           -- drawn already, or drawn and gone off
	if workspace:GetServerTimeNow() >= expires then return end        -- due: its blast (or fizzle) is on the way
	startMark(model, expires, total, false, false)
end
Tech.WatchMark = watchMark

--- The mark landed: { Character, Victim, Position, T0 (server time it landed), Fuse (seconds to the blast) }.
function Tech.DetonateMark(d)
	local model = d.Victim
	if not (typeof(model) == "Instance" and model.Parent) then return end
	libs()
	local fuse = tonumber(d.Fuse) or T.Detonate.Fuse / VFXLibrary.ShotTimeScale()
	local t0 = tonumber(d.T0) or workspace:GetServerTimeNow()
	startMark(model, t0 + fuse, fuse, true, isLocal(d.Character))
end

--- The mark went out without a blast: { Victim, Position }. The mark's own frame takes it once the flag is down.
function Tech.DetonateFizzle(d)
	local model = typeof(d.Victim) == "Instance" and d.Victim or nil
	local ctl = model and marks[model]
	if ctl then ctl.FizzleAsked = true end
end

----------------------------------------------------------------------------------------------------
-- DETONATE: the blast
----------------------------------------------------------------------------------------------------
-- dt_blast. The kit's burst at BlastSize x scale (1.0 at 12 damage .. 2.0 at 48: every length x scale, so the big one
-- is the small one twice as big), thrown toward the viewer and up so it covers the body (BlastStep x scale toward the
-- viewer, never onto the lens), its own spray + an ember burst, Flung / FlungBig tongues of flame arcing out and
-- burning away (live Debris / DebrisBig, at BigAt damage), two lights that stand off the body and die with the fire.
-- Reduce Flashing: everything x0.75 (live). Not drawn on yourself in first person (live). NO KABOOM! here.
function Tech.DetonateBlast(d)
	libs()
	local model = typeof(d.Victim) == "Instance" and d.Victim or nil
	local ctl = model and marks[model]
	if ctl then ctl.Kill = true end                                   -- the mark goes on the blast's frame
	if model and isLocal(model) and firstPerson() then return end
	local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
	local at = root and root.Position or d.Position
	if typeof(at) ~= "Vector3" then return end
	local k = (Settings.Get and Settings.Get("ReduceFlashing")) and FX.ReduceFlashing or 1
	local base = (FX.BlastScale[1] + (FX.BlastScale[2] - FX.BlastScale[1]) * clamp(tonumber(d.Scale) or 0, 0, 1)) * k
	local big = (tonumber(d.Amount) or 0) >= FX.BigAt
	local chest = at + Vector3.new(0, FX.Chest, 0)
	local f, r, dist = view(chest)
	local c = chest + f * min(FX.BlastStep * base, max(0, dist - 2))
	local floorY = at.Y - FX.Floor
	local life = big and 0.5 or 0.4
	local bk = unit(f * 0.75 + UP * 0.66)
	local size = FX.BlastSize * base
	local k2 = (size / 3) ^ 2
	local n = big and FX.FlungBig or FX.Flung
	local seed = big and 700 or 720
	local BU = { size = size, t = 0, seed = seed, back = bk, light = false }
	local EB = { id = "blast", count = big and 110 or 45, speed = big and { 11, 40 } or { 8, 26 }, bias = f * 0.25 + UP * 0.4,
		life = big and { 0.4, 0.95 } or { 0.3, 0.7 } }
	local FT = { cool = 0, ph = 0, t = 0 }
	local lightAt = c + bk * (1.6 * base) + f * (0.8 * base)
	local glowAt = c + f * (2.4 * base)
	glowAt = Vector3.new(glowAt.X, floorY, glowAt.Z)
	local born = os.clock()
	PD.Play("PyroBlast", function(cv, now)
		local age = (now - born) * VFXLibrary.ShotTimeScale()
		if age > 1.0 then return false end
		BU.t = age
		cv:burst(c, age / life, BU)
		local le = 1 - sst(0.55 * life, 1.1 * life, age)                -- every light dies with the fire
		if le > 0 then
			LO.t, LO.ph, LO.range = age, 0.2, nil
			cv:fire_light(lightAt, (1300 * exp(-age / 0.09) + 420 * exp(-age / 0.2)) * k2 * le, LO)
			cv:ground_glow(glowAt, 7 * base, (big and 1.2 or 0.6) * exp(-age / 0.22) * le, age, 0.5)
		end
		cv:ember_burst(c, age, EB)
		local a0 = age - 0.05
		if a0 > 0 and a0 < life then
			local q = a0 / life
			for i = 0, n - 1 do
				local an = TAU * (i + 0.3) / n
				local dd = unit(r * cos(an) + UP * (sin(an) + 0.4) + f * 0.3)
				local p, v = drag(c + dd * (1.1 * base), dd * (19 * base * (0.8 + 0.4 * R(seed, i, 2))), a0, 3.6, 34)
				if p.Y > floorY + 0.2 then
					FT.cool, FT.ph, FT.t = 0.3 * q, 1.7 * i, age
					cv:flame(2, p, unit(-v), 2.1 * base * (1 - q) ^ 0.6 * (0.8 + 0.4 * R(seed, i, 3)), 0.6 * base * (1 - q) ^ 0.5, FT)
				end
			end
		end
		return true
	end, { Clock = os.clock, own = isLocal(d.Character) })
end

----------------------------------------------------------------------------------------------------
-- SCORCHING LASH: the rope (PyroFX's simulation, line for line)
----------------------------------------------------------------------------------------------------
--- The grip: the right fist -- the viewmodel's in your own first person, else the body's hand.
local function whipGrip(ctl)
	local character = ctl.Character
	if ctl.Own and firstPerson() then
		local arm = Viewmodel.GetArmCFrame("R")
		if arm then return (arm * CFrame.new(0, 0, -WHIP.OwnGrip)).Position end
	end
	local hand = character:FindFirstChild("RightHand")
	if hand then return (hand.CFrame * CFrame.new(0, -0.15, 0)).Position end
	local arm = character:FindFirstChild("Right Arm")
	return arm and (arm.CFrame * CFrame.new(0, -1, 0)).Position or nil
end

--- The floor under the caster (one ray a frame per whip), for the rope to lie on.
local function whipGround(ctl, root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctl.Character, fxFolder(), workspace.CurrentCamera }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -WHIP.GroundRay, 0), params)
	return hit and hit.Position.Y or -math.huge
end

--- One verlet step of the rope (live whipStep).
local function whipStep(ctl, grip, ground, stretch, h, back)
	local P, Q, n = ctl.P, ctl.Q, WHIP.Links
	local fall = Vector3.new(0, -WHIP.Gravity * h * h, 0)
	local floorY = ground + WHIP.Ground
	local creep = back and back * (WHIP.Creep * h) or ZERO
	for i = 1, n do
		local v = (P[i] - Q[i]) * WHIP.Damp
		Q[i] = P[i]
		local p = P[i] + v + fall
		if p.Y < floorY then
			p = Vector3.new(p.X, floorY, p.Z) + creep
			Q[i] = WHIP.Calm and p or Vector3.new(p.X, Q[i].Y, p.Z)   -- friction on the floor (Calm: and no bounce)
		end
		P[i] = p
	end
	for _ = 1, WHIP.Iter do
		P[0] = grip
		for i = 1, n do
			local d = P[i] - P[i - 1]
			local len = d.Magnitude
			if len > 1e-6 then
				local rest = (FR[i] - FR[i - 1]) * WHIP.Hang * stretch
				local corr = d * ((len - rest) / len)
				if i == 1 then
					P[i] -= corr
				else
					P[i - 1] += corr * 0.5
					P[i] -= corr * 0.5
				end
			end
		end
	end
	P[0] = grip
end

--- The SWEEP's joints `t` seconds after the release, laid from `grip` round the flat `aim` (live whipSwept), written
--- into `out` [0 .. Links].
local function whipSwept(out, grip, aim, left, t)
	local L = T.ScorchingLash
	local u = clamp(t / L.Trigger, 0, 1)
	local hand = L.WhipStart + (L.SweepTo - L.WhipStart) * u
	if t > L.Trigger then
		hand = L.SweepTo + WHIP.FollowThru * easeOutQuad((t - L.Trigger) / max(1e-3, WHIP.Snap - L.Trigger))
	end
	local bend = WHIP.Bend * sin(pi * u)
	local length = WHIP.Hang + (L.Reach - WHIP.Hang) * easeOutQuad(u / WHIP.GrowU)
	out[0] = grip
	local at = grip
	for i = 1, WHIP.Links do
		local f0, f1 = FR[i - 1], FR[i]
		local a = math.rad(hand - bend * (f0 + f1) * 0.5)
		at = at + (aim * cos(a) + left * sin(a)) * (length * (f1 - f0)) - Vector3.new(0, WHIP.Drop * (f1 - f0), 0)
		out[i] = at
	end
	return out
end

--- The joints `x` seconds after the release as the frame lays them: the rope as it lay, blended into the driven
--- sweep over Blend; the rope itself once the drive is over. (The sweep is closed-form, so its past needs no record.)
local function jointsAt(ctl, grip, aim, left, x, buf)
	if x >= WHIP.Snap then return ctl.P end
	local from = ctl.From or ctl.P
	if x <= 0 then return from end
	whipSwept(buf, grip, aim, left, x)
	local w = x / WHIP.Blend
	if w < 1 then
		for i = 1, WHIP.Links do buf[i] = from[i]:Lerp(buf[i], w) end
	end
	return buf
end

--- The angle of `rel` (from the caster's root) round the flat `aim`: positive to the left; behind the caster it counts
--- on below -180 (live sweepAngle).
local function sweepAngle(rel, aim, left)
	local a = math.deg(math.atan2(rel:Dot(left), rel:Dot(aim)))
	if a > T.ScorchingLash.SweepTo + 60 then a -= 360 end
	return a
end

--- The swept area as the tip sweeps it (live whipTrail): a flame at each TrailStep the tip has reached, on that exact
--- angle round the caster at the tip's distance and height; here each is shifted along and across the path by its own
--- share of the spacing (ls_trail's row_vary) and remembers the way the tip went.
local function whipTrail(ctl, centre, aim, left, tip, now)
	local L = T.ScorchingLash
	local rel = tip - centre
	local a = sweepAngle(rel, aim, left)
	local r = sqrt(rel.X * rel.X + rel.Z * rel.Z)
	ctl.TrailNext = ctl.TrailNext or L.SweepFrom
	while ctl.TrailNext <= L.SweepTo and a >= ctl.TrailNext - 1e-3 do
		local b = math.rad(ctl.TrailNext)
		local way = left * cos(b) - aim * sin(b)
		local across = way:Cross(UP)
		local idx = floor((ctl.TrailNext - L.SweepFrom) / FX.TrailStep + 0.5)
		local v = TRV[idx] or TRV[0]
		local gap = r * math.rad(FX.TrailStep)
		table.insert(ctl.Trail, {
			born = now, idx = idx, way = way, across = across,
			pos = centre + (aim * cos(b) + left * sin(b)) * r + Vector3.new(0, rel.Y, 0) + way * (v.ds * gap) + across * (v.dn * gap),
		})
		ctl.TrailNext += FX.TrailStep
	end
end

----------------------------------------------------------------------------------------------------
-- SCORCHING LASH: the crack, the whip's fire
----------------------------------------------------------------------------------------------------
local SCR_A, SCR_B = {}, {}

--- ls_crack: the kit's burst at the tip, thrown the way the tip was going, sparks, a flash of light on the floor.
--- At the tip's place ON the Trigger (closed-form), where live pops its FireballBurst on the first frame past it.
local function crack(ctl, grip, aim, left, floorY)
	local L = T.ScorchingLash
	local n = WHIP.Links
	local p = whipSwept(SCR_A, grip, aim, left, L.Trigger)[n]
	local d = unit(p - whipSwept(SCR_B, grip, aim, left, L.Trigger - 0.01)[n], aim)
	local BU = { size = FX.CrackSize, t = 0, seed = 740, back = unit(d * 0.8 + UP * 0.55) }
	local EB = { id = "crack", count = 85, speed = { 10, 36 }, bias = Vector3.new(d.X * 0.5, 0.35, d.Z * 0.5) }
	local glowAt = Vector3.new(p.X, floorY, p.Z)
	local born = os.clock()
	PD.Play("PyroLashCrack", function(cv, now)
		local a = (now - born) * VFXLibrary.ShotTimeScale()
		if a > 0.8 then return false end
		BU.t = a
		cv:burst(p, a / FX.CrackLife, BU)
		cv:ember_burst(p, a, EB)
		cv:ground_glow(glowAt, 9, exp(-a / 0.2), a, 0.4)
		return true
	end, { Clock = os.clock, own = ctl.Own })
end

local function shrAt(k, i)
	if not k then return 1 end
	return clamp(1 - k * (1 + FR[i]), 0, 1)
end

-- cv:chain's width per link: thinner to the tip, the whole whip's grow, going out tip first, fatter in the sweep
local cwGrow, cwK, cwFat = 1, nil, 1
local function chainWidth(i)
	return FX.RopeW * whipScales[i] * cwGrow * cwFat * shrAt(cwK, i)
end

local LT = { ph = 0, t = 0 }
local CT = { flat = 0.72, side = ZERO, lean = ZERO, curl_to = UP, ph = 0, t = 0 }
local SFT = { seed = 0, lean = ZERO, width = 0, layers = 2, cool = 0 }
local EM_TIP = { id = "tip", count = 14, life = { 0.3, 0.7 }, out = { 0.5, 2.5 }, up = { 1.0, 4.0 }, spread = 0.3, g = 22, kd = 3.0,
	size = { 0.04, 0.1 } }
local EM_MID = { id = "mid", count = 10, life = { 0.3, 0.7 }, out = { 0.5, 2.5 }, up = { 1.0, 4.0 }, spread = 0.3, g = 22, kd = 3.0,
	size = { 0.04, 0.1 } }
local EM_SWEEP = { id = "sweep", count = 150, life = { 0.25, 0.6 }, out = { 1.0, 5.0 }, up = { 0.5, 4.0 }, spread = 0.4 }

--- ls_curtain: THE SWEEP'S CURTAIN OF FIRE. 3 tongues per 2 links (1 per link when thinned) in a flame's proportions,
--- varied by the kit's row_vary at 1.6, wide enough to merge at the rope; each is laid back along the path ITS OWN
--- point of the rope took over the last CA seconds (so no two point the same way), streams back nearly flat off the
--- fast rope and billows up into standing tongues as the whip comes round to the front (+0.09 .. +0.18 s); the tall
--- ones carry the light core. Port: a tongue is one rigid flame laid from its root toward where its tip was (it tilts,
--- it cannot bend along the path); one in four of the plain ones is a Lick curling upward.
local function drawCurtain(ctl, cv, tw, rel, swf, grow, outK, grip, thin, own1)
	local C = curtainStatic(thin and FX.CurtainThin or FX.Curtain)
	local K = FX.CK
	local dA = FX.CA / K
	local aim = ctl.Dir
	local left = Vector3.new(aim.Z, 0, -aim.X)
	local J, HB, X = ctl.J, ctl.HB, ctl.X
	J[0] = ctl.P
	for k = 1, K do
		HB[k] = HB[k] or {}
		J[k] = jointsAt(ctl, grip, aim, left, rel - k * dA, HB[k])
	end
	local J0 = J[0]
	local kr = 0.3 + 0.7 * sst(0.09, 0.18, rel)
	local wk = own1 and WHIP.OwnScale or 1
	for j = 0, C.n - 1 do
		local S = C[j]
		local i0, fw = S.i0, S.fw
		local s0 = shrAt(outK, i0)
		local thc = S.sc * (s0 + (shrAt(outK, i0 + 1) - s0) * fw) * grow
		if thc > 0.04 then
			local X0 = J0[i0]:Lerp(J0[i0 + 1], fw)
			local Lw = S.len * (1 + 0.22 * sin(TAU * 2.5 * tw + S.phF)) * swf
			-- back along the path this point of the rope took, Lw studs (never further than CA seconds)
			local cum, f, prev, last = 0, K, X0, K
			X[0] = X0
			for k = 1, K do
				local Jk = J[k]
				local p = Jk[i0]:Lerp(Jk[i0 + 1], fw)
				X[k] = p
				local seg = (p - prev).Magnitude
				if cum + seg >= Lw then
					f = (k - 1) + (seg > 1e-6 and (Lw - cum) / seg or 0)
					last = k
					break
				end
				cum += seg
				prev = p
			end
			local ia = min(floor(f), last - 1)
			local Xa = X[ia]:Lerp(X[ia + 1], f - ia)
			local fh = f * 0.5
			local ih = min(floor(fh), last - 1)
			local Xh = X[ih]:Lerp(X[ih + 1], fh - ih)
			local c = Xa - X0
			local b = (c * 0.5 - (Xh - X0)) / 0.17                       -- that path's bend -> the tongue's lean
			local bm = b.Magnitude
			if bm > 1e-6 then b = b * min(1, 0.5 * c.Magnitude / bm) end
			local tg = unit(J0[i0 + 1] - J0[i0], aim)
			local a = c - b + UP * (S.upf * thc ^ 0.5 * swf * kr)
			local H = a.Magnitude
			if H > 0.2 then
				local W = min(clamp(0.42 * H * S.w, 0.75, 2.8) * wk, 0.55 * H)
				if W > 0.08 then
					local lt = S.lt + 0.112 * sin(TAU * 1.25 * tw + S.phS)                 -- row_vary's sway at 1.6
					local ln = S.ln + 0.064 * sin(TAU * 1.25 * tw + S.phS * 1.7 + 1.0)
					CT.lean = b / H + tg * (1.2 * lt) + UP * (1.5 * abs(ln))
					CT.side, CT.ph, CT.t = tg, S.phF, tw
					cv:flame(S.kind, X0, a / H, H, W, CT)
				end
			end
		end
	end
end

--- The tip's place at whip-clock time `tq`: closed-form through the driven sweep, its recorded path otherwise.
local function tipAt(ctl, tq)
	local relT = ctl.RelT
	if relT and ctl.Dir and ctl.Grip then
		local x = tq - relT
		if x > 0 and x < WHIP.Snap then
			local aim = ctl.Dir
			return jointsAt(ctl, ctl.Grip, aim, Vector3.new(aim.Z, 0, -aim.X), x, ctl.TB)[WHIP.Links]
		end
	end
	return histAt(ctl.TipHist, tq) or ctl.P[WHIP.Links]
end

--- ls_whip: the rope of fire (one Link per pair of joints, the live chain), a tongue on every link that RISES where
--- the rope is still and LAGS behind it where it moves (small slender licks peeling off sideways on the part hanging
--- from the hand, every other one gone there), the curtain through the sweep (the link tongues give way to it), a
--- streaming tail on the tip along the path the tip took, wisps and sparks shed while it is held, a spray off the tip
--- through the sweep, warm light at the hand and on the floor (at the middle and the tip in the sweep), the path flames.
local function whipDraw(ctl, cv, now, dtc, ts, grow, outK, rel, root, grip, own1)
	local L = T.ScorchingLash
	local n = WHIP.Links
	local P = ctl.P
	local tw = (now - ctl.T0) * ts                                    -- the whip's own clock, from when it was made
	local thin = cv.Density < 0.75
	local released = rel ~= nil and rel >= 0
	local sweeping = released and rel < WHIP.Snap
	local swf = released and sm(rel / 0.05) * (1 - sm((rel - WHIP.Snap) / 0.12)) or 0
	ctl.Grip = grip
	ctl.RelT = released and (tw - rel) or nil
	histPush(ctl.TipHist, tw, P[n])

	-- the rope
	local pts = ctl.Pts
	for i = 0, n do pts[i + 1] = P[i] end
	cwGrow, cwK, cwFat = grow, outK, 1 + 0.7 * swf
	cv:chain(pts, chainWidth, tw, nil)

	-- a tongue on every link
	local look = flatUnit(root.CFrame.LookVector, FWD)
	local back, left = -look, Vector3.new(look.Z, 0, -look.X)
	local Pc, Vs = ctl.Pc, ctl.Vs
	local ease = dtc > 1e-4 and (1 - exp(-dtc / 0.05)) or 0
	local held = 1 - swf
	local arc = 0
	for k = 0, n - 1 do
		local a, b = P[k], P[k + 1]
		local dv = b - a
		local len = dv.Magnitude
		local pc = (a + b) * 0.5
		local prev = Pc[k]
		Pc[k] = pc
		local vs = Vs[k] or ZERO
		if prev and dtc > 1e-4 then
			local raw = (pc - prev) / dtc
			local m = raw.Magnitude
			if m > 330 then raw = raw * (330 / m) end
			vs = vs + (raw - vs) * ease                                -- eased: the rope steps at 120 Hz, not per frame
		end
		Vs[k] = vs
		local arcc = arc + len * 0.5
		arc += len
		if held > 0.03 and not (thin and k % 2 == 1) then
			local S = LINKS[k]
			local thc = S.sc * 0.5 * (shrAt(outK, k) + shrAt(outK, k + 1)) * grow
			if thc > 0.04 then
				local vz = sst(0.55, 0.9, len > 1e-4 and abs(dv.Y) / len or 0) * S.hang     -- 1 = hanging straight down from the hand
				local hk = held * S.base * (1 - 0.2 * vz) * ((k % 2 == 0) and 1 or 1 - 0.9 * vz)
				if hk > 0.06 then
					local spd = vs.Magnitude
					local D0 = unit(UP * (1 - 0.5 * vz) + (left * S.c + back * S.s) * (0.95 * vz) - vs * 0.15 + S.ru)
					local H = (S.h0 + 0.35 * sin(TAU * (0.35 * arcc - 2.5 * tw) + S.ph)) * thc ^ 0.6 * (1 + spd / 40) * 0.95 * hk
					local W = 0.85 * thc * (1 + spd / 150) * hk ^ 0.8 * (1 - 0.55 * vz)
					LT.ph, LT.t = S.ph, tw
					cv:flame(2, pc, D0, H, W, LT)
				end
			end
		end
	end

	if swf > 0.02 and ctl.Dir then drawCurtain(ctl, cv, tw, rel, swf, grow, outK, grip, thin, own1) end

	-- the tip
	local twd = 0.85 * grow * shrAt(outK, n)
	if twd > 0.05 then
		local TT = ctl.TailO
		if not released then
			TT.width, TT.span, TT.t_min, TT.segs = twd, 0.2, 0, nil
			cv:fire_tail(ctl.TipFn, tw, TT)
		elseif rel < 0.06 then
			-- the rope is being taken over from where it lay: no streak yet
		elseif sweeping then
			TT.width, TT.span, TT.t_min, TT.segs = twd * (1 + 1.8 * swf), 0.035, ctl.RelT + WHIP.Blend, nil
			cv:fire_tail(ctl.TipFn, tw, TT)
		else
			-- the recoil. The piece's streak is 0.2 s of the tip's path as one bent ribbon; the recoiling tip covers 40
			-- studs in that time, which as rigid pieces is a 40-stud needle: RecoilSpan of it, in three pieces
			TT.width, TT.span, TT.t_min, TT.segs = twd, FX.RecoilSpan, ctl.RelT + WHIP.Snap, 3
			cv:fire_tail(ctl.TipFn, tw, TT)
		end
	end

	-- what it sheds
	local WO = ctl.WispO
	WO.scale = 0.6 * (own1 and WHIP.OwnScale or 1)
	if not released then
		cv:wisps(ctl.TipFn, tw, 0.3, math.huge, WO)
		if tw > 0.15 and not ctl.OutAt then
			cv:embers(P[n], tw, EM_TIP)
			cv:embers(P[n // 2], tw, EM_MID)
		end
	else
		cv:wisps(ctl.TipFn, tw, 0.3, ctl.RelT, WO)                     -- the ones already peeled off keep rising
		if rel >= 0.05 and rel <= L.Trigger then cv:embers(P[n], tw, EM_SWEEP) end
	end

	-- its light (the tip before the middle: a thinned canvas has two)
	local lv = grow * shrAt(outK, 0)
	LO.t, LO.range = tw, nil
	LO.ph = 0.3
	cv:fire_light(P[0] + UP * 0.3, 260 * lv, LO)
	if sweeping then
		LO.ph = 2.3
		cv:fire_light(P[n] + UP * 0.5, 1100 * lv, LO)
		LO.ph = 1.1
		cv:fire_light(P[n // 2] + UP * 0.5, 800 * lv, LO)
	else
		cv:ground_glow(P[n], 5, 0.7 * lv * shrAt(outK, n), tw, 1.7)
		cv:ground_glow(P[n // 2], 4, 0.45 * lv * shrAt(outK, n // 2), tw, 2.9)
	end

	-- ls_trail: the swept path, a flame where the tip passed, leaning the way it went, rising and cooling, gone in
	-- 0.33 s; each its own height, width, lean and place
	local trail = ctl.Trail
	local i = 1
	while i <= #trail do
		local fl = trail[i]
		local a = (now - fl.born) * ts
		if a >= 0.34 then
			table.remove(trail, i)
		else
			if not (thin and fl.idx % 2 == 1) then
				local v = TRV[fl.idx] or TRV[0]
				local q = a / 0.33
				local hh = FX.TrailH * seqL(FX.Trail, a, 0) * FX.TrailScale * v.h
				SFT.seed, SFT.lean = fl.idx + 400, fl.way * (0.5 * (1 - q) + v.lt) + fl.across * v.ln
				SFT.width, SFT.cool = 0.52 * hh * v.w, 0.25 * q
				cv:standing_flame(fl.pos + UP * (1.2 * a), hh, tw, SFT)
			end
			i += 1
		end
	end
end

--- The whip on `character`, made (or found) and running: the rope, hanging from the grip, stepped and drawn every
--- frame until it has gone out (live whipFor; its controller's fields are live's).
local function whipFor(character, isOwn)
	local ctl = whips[character]
	if ctl then
		if isOwn then ctl.Own = true end
		return ctl
	end
	libs()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local n = WHIP.Links
	ctl = {
		Character = character, Own = isOwn == true, P = {}, Q = {}, Born = os.clock(), Acc = 0, Flame = true,
		T0 = os.clock(), Trail = {}, TipHist = histNew(), Pts = {}, Pc = {}, Vs = {}, Buf = {}, TB = {}, J = {}, HB = {}, X = {},
		TailO = { width = 0, span = 0.2, t_min = 0, rise = 7, seed = 5 }, WispO = { rate = 6, life = 0.55, scale = 0.6, seed = 12 },
	}
	ctl.TipFn = function(tq)
		return tipAt(ctl, tq)
	end
	whips[character] = ctl
	-- it starts hanging behind the hand, and settles from there
	local grip0 = whipGrip(ctl) or root.Position
	local back0 = -flatUnit(root.CFrame.LookVector, FWD)
	local floor0 = WHIP.Calm and whipGround(ctl, root) + WHIP.Ground or nil
	for i = 0, n do
		local f = FR[i] * WHIP.Hang
		if floor0 then
			-- (the piece) straight down to the floor, the rest laid back along it
			local drop = max(grip0.Y - floor0, 0.5)
			ctl.P[i] = Vector3.new(grip0.X, max(grip0.Y - f, floor0), grip0.Z) + back0 * max(f - drop, 0)
		else
			ctl.P[i] = grip0 + Vector3.new(0, -f * 0.8, 0) + back0 * (f * 0.5)
		end
		ctl.Q[i] = ctl.P[i]
	end
	PD.Play("PyroWhip", function(cv, now, dt)
		root = character.Parent and character:FindFirstChild("HumanoidRootPart")
		local grip = root and whipGrip(ctl)
		if ctl.Kill or not grip then return false end
		local ts = VFXLibrary.ShotTimeScale()
		local L = T.ScorchingLash
		local P, Q = ctl.P, ctl.Q
		-- the sweep, on its own clock from the release
		local t = ctl.CrackAt and (now - ctl.CrackAt) * ts or nil
		local stretch = 1
		local driven = false
		if t and t >= 0 and t < WHIP.Snap and ctl.Dir then
			driven = true
			if not ctl.From then
				ctl.From = table.clone(P)                               -- where the rope lay: the drive blends out of it
			end
			local aim = ctl.Dir
			local left = Vector3.new(aim.Z, 0, -aim.X)
			local target = whipSwept(ctl.Buf, grip, aim, left, t)
			local w = clamp(t / WHIP.Blend, 0, 1)
			local from = ctl.From
			for i = 0, n do
				P[i] = from[i]:Lerp(target[i], w)
				Q[i] = P[i]                                             -- it hands back to the rope at rest
			end
			P[0] = grip
			whipTrail(ctl, root.Position, aim, left, P[n], now)
			if t >= L.Trigger and not ctl.Cracked then
				ctl.Cracked = true
				crack(ctl, grip, aim, left, root.Position.Y - FX.Floor)
			end
		elseif t and t >= WHIP.Snap and t < WHIP.Recoil then
			-- the recoil: the rope again, its spacing shrinking from the full reach back to hanging
			local v = (t - WHIP.Snap) / (WHIP.Recoil - WHIP.Snap)
			stretch = (L.Reach / WHIP.Hang) + (1 - L.Reach / WHIP.Hang) * easeOutQuad(v)
		elseif t and t >= WHIP.Recoil and not ctl.Recoiled then
			ctl.Recoiled = true
			if not ctl.Holding and not ctl.OutAt then ctl.OutAt = now end       -- the crack ended the hold: it goes
		end
		if not driven then
			local ground = whipGround(ctl, root)
			ctl.Acc = min(ctl.Acc + dt * ts, WHIP.Step * WHIP.MaxSteps)
			local back = -flatUnit(root.CFrame.LookVector, FWD)
			while ctl.Acc >= WHIP.Step do
				ctl.Acc -= WHIP.Step
				whipStep(ctl, grip, ground, stretch, WHIP.Step, back)
			end
			P[0] = grip
		end
		-- going out: every link shrinks to nothing, the tip end first
		local outK = nil
		if ctl.OutAt then
			outK = (now - ctl.OutAt) * ts / WHIP.Out
			if outK >= 1 then return false end
		end
		local own1 = ctl.Own and firstPerson()
		local grow = seqL(WHIP.PopIn, (now - ctl.Born) * ts, 1) * (own1 and WHIP.OwnScale or 1)
		whipDraw(ctl, cv, now, dt * ts, ts, grow, outK, t, root, grip, own1)
		return true
	end, { Clock = os.clock, own = ctl.Own, MaxLife = math.huge, OnEnd = function()
		if whips[character] == ctl then whips[character] = nil end
	end })
	return ctl
end
Tech.WhipFor = whipFor

--- The whip HELD: `on` hangs it from `character`'s hand (or keeps the one already there); off lets a hold that ended
--- without a crack go. Live LashHold, word for word.
function Tech.LashHold(character, on, t0, isOwn)
	if not (typeof(character) == "Instance" and character.Parent) then return end
	if isOwn == nil then isOwn = isLocal(character) end
	local ctl = whips[character]
	if on then
		if ctl and ctl.CrackAt and not ctl.Recoiled then return end     -- a crack still out: it goes when that is over
		if ctl and ctl.OutAt then
			ctl.OutAt = nil                                             -- going out: back in the hand
			ctl.Born = os.clock()
		end
		ctl = ctl or whipFor(character, isOwn)
		if not ctl then return end
		ctl.Holding = true
		ctl.CrackAt, ctl.From, ctl.Cracked, ctl.Recoiled = nil, nil, nil, nil
	elseif ctl then
		ctl.Holding = false
		if not ctl.CrackAt or ctl.Recoiled then
			ctl.OutAt = ctl.OutAt or os.clock()
		end
	end
end

--- THE SWEEP of `character`'s whip, from the server's `t0` (nil: now -- your own client's release). Live Lash, word
--- for word: a repeat within 0.6 s is ignored; a whip never seen in the hand is made first.
function Tech.Lash(character, t0, dir, isOwn)
	libs()
	if not (typeof(character) == "Instance" and character.Parent) then return end
	if isOwn == nil then isOwn = isLocal(character) end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ctl = whips[character]
	local start = localClock(t0)
	if ctl and ctl.CrackStarted and os.clock() - ctl.CrackStarted < 0.6 then return end      -- this crack, heard again
	ctl = ctl or whipFor(character, isOwn)
	if not ctl then return end
	ctl.CrackStarted = os.clock()
	ctl.CrackAt = start
	local look = flatUnit(root.CFrame.LookVector, FWD)
	ctl.Dir = typeof(dir) == "Vector3" and flatUnit(dir, look) or look
	ctl.Holding = false                                               -- a sweep ends the hold
	ctl.OutAt, ctl.From, ctl.Cracked, ctl.Recoiled = nil, nil, nil, nil
	ctl.TrailNext = nil
end

--- The bodies the server says the crack caught: { Character, Victims = { model, ... }, Positions = { Vector3, ... } }.
--- ls_hit: the kit burst (HitSize; a mini pop from the third body on) on the chest's side toward the caster + sparks,
--- on live's seats; a victim that arrives nil still pops at its Position.
function Tech.LashHit(d)
	libs()
	local caster = typeof(d.Character) == "Instance" and d.Character:FindFirstChild("HumanoidRootPart") or nil
	local victims = type(d.Victims) == "table" and d.Victims or {}
	local positions = type(d.Positions) == "table" and d.Positions or {}
	local pops = {}
	for i = 1, T.ScorchingLash.MaxTargets do
		local model, seen = victims[i], positions[i]
		local torso = typeof(model) == "Instance" and model.Parent
			and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) or nil
		local chest = (torso and (torso.CFrame * CFrame.new(0, FX.HitUp, 0)).Position)
			or (typeof(seen) == "Vector3" and seen + Vector3.new(0, FX.HitChest, 0)) or nil
		if chest then
			local toward = flatUnit((caster and caster.Position or workspace.CurrentCamera.CFrame.Position) - chest, ZERO)
			local k = #pops + 1
			pops[k] = {
				at = chest + toward * FX.HitOut,
				BU = { size = FX.HitSize, t = 0, seed = 750 + 5 * k, back = unit(toward + UP * 0.4), sparks = 0, light = k <= 2 },
				EB = { id = "hit" .. k, count = 22, speed = { 5, 16 }, hemi = toward, life = { 0.25, 0.55 }, size = { 0.05, 0.12 } },
			}
		end
	end
	if #pops == 0 then return end
	local born = os.clock()
	PD.Play("PyroLashHit", function(cv, now)
		local a = (now - born) * VFXLibrary.ShotTimeScale()
		if a > 0.55 then return false end
		for k, p in ipairs(pops) do
			p.BU.t = a
			pop(cv, p.at, a / FX.HitLife, p.BU, k <= 2 and 1 or 0.5)
			cv:ember_burst(p.at, a, p.EB)
		end
		return true
	end, { Clock = os.clock, own = isLocal(d.Character) })
end

----------------------------------------------------------------------------------------------------
-- SCORCHING LASH: the burn stacks
----------------------------------------------------------------------------------------------------
-- ls_stacks on live's startBurn: RX_Burning_Stacks read every frame, one flame per stack on live's UpperTorso seats
-- (right shoulder, left shoulder, a taller one behind the head), popping in per stack, every flame a little bigger
-- with the count, shrinking out together over BurnOut when the burn goes out and popping back if it is lit again
-- meanwhile; not drawn on your own body in your own first person. r2: BurnH 2.75 studs at scale 1, with the light
-- core, leaning out and swaying slowly, two small licks beside each one (fore and aft on a shoulder, either side
-- behind the head; dropped when thinned), sparks rising off them, one warm light per burning body.
local EM_BURN = { id = "burn", count = 8, life = { 0.4, 0.85 }, up = { 3, 9 }, size = { 0.05, 0.12 }, lift = 1.3 }
local burnSerial = 0

--- The burn flames on `model`, following its RX_Burning_Stacks until they have shrunk away.
local function startBurn(model)
	libs()
	local ctl = { Flames = {}, Last = 1, Flame = true }
	burns[model] = ctl
	burnSerial += 1
	local sid = burnSerial % 7
	local slots = FX.BurnSlots
	local SF = { seed = 0, lean = ZERO, layers = "ball" }
	local SL = { seed = 0, lean = ZERO, layers = 2 }
	local EF = { id = EM_BURN.id, count = 8, life = EM_BURN.life, up = EM_BURN.up, size = EM_BURN.size, lift = EM_BURN.lift }
	PD.Play("PyroBurn", function(cv, now)
		local torso = model.Parent and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"))
		if not torso then return false end
		local ts = VFXLibrary.ShotTimeScale()
		local n = clamp(floor(tonumber(model:GetAttribute("RX_Burning_Stacks")) or 0), 0, #slots)
		if n > 0 then
			if ctl.OutAt then                                           -- lit again while going out: they pop back in
				ctl.OutAt = nil
				for _, fl in pairs(ctl.Flames) do fl.Born = now end
			end
			ctl.Last = n
		elseif not ctl.OutAt then
			ctl.OutAt = now
		end
		local out = ctl.OutAt and 1 - (now - ctl.OutAt) * ts / FX.BurnOut or 1
		if out <= 0 then return false end
		for k = 1, #slots do
			local fl = ctl.Flames[k]
			if n > 0 and k <= n and not fl then
				ctl.Flames[k] = { Born = now }
			elseif n > 0 and k > n and fl then                          -- fewer stacks without going out: it goes
				ctl.Flames[k] = nil
			end
		end
		if isLocal(model) and firstPerson() then return true end
		local thin = cv.Density < 0.75
		local tcf = torso.CFrame
		local rgt = flatUnit(tcf.RightVector, Vector3.new(1, 0, 0))
		local fwd = UP:Cross(rgt)
		local lit = 0
		for k, slot in ipairs(slots) do
			local fl = ctl.Flames[k]
			if fl then
				lit += 1
				local s = FX.BurnScale * slot[2] * FX.BurnGrow[ctl.Last] * seqL(FX.BurnPop, (now - fl.Born) * ts, 1) * out
				local p = tcf * slot[1]
				local ln = slot[3]
				local sd = 300 + 7 * k + 31 * sid
				local sway = rgt * (0.09 * sin(TAU * 1.25 * now + 2.1 * k + sid)) + fwd * (0.06 * sin(TAU * 2.5 * now + 1.3 * k + 2.0 * sid))
				local outv = rgt * (0.21 * ln)
				SF.seed, SF.lean = sd, outv + sway
				cv:standing_flame(p, FX.BurnH * s, now, SF)
				if not thin then
					local ax = ln ~= 0 and fwd or rgt
					local hh = FX.BurnH * s
					SL.seed, SL.lean = sd + 3, ax * 0.34 + outv + sway * 1.6
					cv:standing_flame(p + ax * (0.36 * s) - UP * 0.04, hh * (0.55 + 0.08 * sin(TAU * 2.5 * now + k + sid)), now, SL)
					SL.seed, SL.lean = sd + 4, ax * -0.38 + outv + sway * 1.6
					cv:standing_flame(p - ax * (0.32 * s) - UP * 0.04, hh * (0.40 + 0.07 * sin(TAU * 2.5 * now + 2.2 + k)), now, SL)
				end
			end
		end
		if lit > 0 then
			if not ctl.OutAt then
				EF.count = 8 * lit
				cv:ember_field(tcf.Position, 1.7, now, EF)
			end
			LO.t, LO.ph, LO.range = now, sid, nil
			cv:fire_light(tcf.Position + UP * 1.6, 140 * lit * out, LO)
		end
		return true
	end, { Clock = os.clock, own = false, MaxLife = math.huge, OnEnd = function()
		if burns[model] == ctl then burns[model] = nil end
	end })
end
Tech.StartBurn = startBurn

-- Burn stacks and Detonate marks draw themselves off the attributes (live WatchBurnStacks): every player's body and
-- every range dummy is looked at each frame, the list refreshed each second. Started once per client; nothing on the
-- server. PyroFX's own watcher does the same job when startBurn / startMark branch to this module (WIRING 2).
local watching = false
function Tech.WatchBurnStacks()
	if watching or not RunService:IsClient() then return end
	watching = true
	libs()
	local candidates, nextScan = {}, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 1
			candidates = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Character then candidates[#candidates + 1] = plr.Character end
			end
			local ground = workspace:FindFirstChild("TrainingGround")
			if ground then
				for _, h in ipairs(ground:GetDescendants()) do
					if h:IsA("Humanoid") and h.Parent then candidates[#candidates + 1] = h.Parent end
				end
			end
		end
		for _, m in ipairs(candidates) do
			if m.Parent then
				if not burns[m] and (tonumber(m:GetAttribute("RX_Burning_Stacks")) or 0) > 0 then startBurn(m) end
				watchMark(m)
			end
		end
	end)
end

return Tech
