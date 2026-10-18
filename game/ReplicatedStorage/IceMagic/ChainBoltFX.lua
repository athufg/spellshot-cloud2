--[[
	ChainBoltFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ChainBoltFX

	Voltaic's M1, CHAIN BOLT, RE-LIT (2026-09-25). The Roblox port of blender_scripts/voltaic/chain_bolt_bl.py (its T
	table, leg_shape / branch / lay / jog_axis / widths, bolt_beams, cast_frame and shard_look) and of
	vfx_blocking/voltaic/CHAIN_BOLT_showcase.md (timings, per-beat build, budget and flags). It keeps the comic build's
	shapes and its fast timing, but draws them with Roblox's emissive toolkit instead of flat toon plates. The zigzags
	are baked in IceMagic.ChainBoltShapes, the comic meshes' exact silhouettes. Only the per-cast jitter is rolled here,
	from a Random seeded per cast (the broadcast's T0 and the caster), so every client draws the same bolt for one cast.
	Every bolt is drawn with VoltaicKit.BeamChain: a thin hot core (VT_VoltOrb_Core) inside a wide soft glow
	(VT_VoltOrb_Glow).

	FIVE BEATS, in SHOT time from the press: real seconds x VFXLibrary.ShotTimeScale, as PyroFX and AbilityFX count it.
	A slowed review slows all of it together, and every emitter's TimeScale with it.
	  1 CAST PULSE  0.000  3 small arcs, then 2 on the next frame, spit off the palm, re-jagged every 60 Hz frame. Also a
	                       palm glow sprite and a PointLight on the arm (2.5, range 6). Two frames in all: the hand reads
	                       charged one frame before the bolt exists.
	  2 THE BOLT    0.017  Leg 1, hand to hit, is at full length and full intensity on its first frame (x1.12 snap, then
	                       +-8 % flicker per 60 Hz frame). Core in Light (3.4), glow in Base (1.3, 3.1 x the stroke).
	                       It is held 0.06 s, then wiped onto the target over 0.02 s, with a PointLight at mid-leg while
	                       it is up. Its start rides the caster's hand (the first-person muzzle for the local caster).
	  3 THE CHAIN   +0.067 Each chain leg comes 4 frames after the last, from the relay to the next body. It is paler and
	                       hotter (glow in Light, core at 4.0): a second event, not leg 1 twice. A primed bolt has up to
	                       3 chain legs.
	  4 IMPACT      +0.017 One frame after its leg:
	                         * the relay star: two particles (StarCore and StarGlow), each Emit(1) at ZOffset 1.2,
	                           0.70 -> 1.18, rolled 18 deg (primary) or 58 deg (chain) +-12, 0.10 s;
	                         * a flash PointLight at 9, range 12, for ONE frame, then 55 % decaying over 0.10 s,
	                           placed 2.4 studs back toward the shooter;
	                         * on the caster's own first hit only, a Bloom kick (+0.5 Intensity, +0.1 Size, tau 0.05).
	                           VoltaicKit.bloomPulse skips it under Reduce Flashing and while the first-person arms are
	                           up (they bloom white).
	  5 DEBRIS            5 shards a hit. Each is a Neon chip, Light on its first drawn frame and then violet-black,
	                       inside a ForceField shell (x1.12) whose edge cools Light -> Base -> dark -> Dark. They are
	                       thrown by anim_chain_bolt's throw_dirs on an ease-out, in the screen plane, sag at -18
	                       studs/s^2, and shrink away in 0.23 s.

	API (D:\voltkit_scratch\castable\CONTRACT.md section 6). Every call returns a handle with :Destroy(), or nil.
	  FireLocal(character, side, fromPos, toPos, opts)
	      The caster's predicted cast: the pulse and leg 1, drawn on the fire frame. opts, all optional:
	        Hit = true, or Part = the claimed BasePart of a character: also draw the predicted impact on toPos.
	        Wall = true (+ Normal): sparks on toPos for a whiff that hit geometry.
	        Thin = true: force the thin look.
	  Fire(data, opts)
	      The ChainBolt broadcast { Character, Origin, Dir, Side, End, Hits, Points, Primed, T0 }.
	      Without opts.SkipFirst it draws the whole cast from the caster's hand (data.Origin when no hand is found near
	      it). With opts.SkipFirst (this client's own FireLocal already drew leg 1), it joins that local cast and draws:
	        * the chain legs, 4 frames apart, from Points[i-1] to Points[i];
	        * an impact at every body point, with impact A skipped when FireLocal predicted it.
	      A whiff (no Hits) draws no star: only sparks at End when End falls short of Range (a wall).
	  Discharge(fromModel, toModel)
	      StatusDischarge: one chain-leg bolt root to root plus VoltSparkBurst at To. With no To, a self-zap burst on From.
	  Review(originPos, points, opts?)
	      HARNESS ONLY. The full cast on a fixed origin, every point a hit, drawn as the caster's own (Bloom included).
	      opts: Thin, Calm (force Reduce Flashing on or off), Seed.
	  Clear()
	      EXTRA: destroys every cast in flight.

	SETTINGS.
	  * Reduce Flashing: no Bloom; the flash is x0.6 and eased in (half on its first frame); bolts, pulse, palm glow and
	    star are x0.85.
	  * Thin (VoltaicKit.thin: another player's cast with Reduce Enemy VFX, or a low Graphics Quality): 2 shards a hit
	    instead of 5, fewer pulse and self-zap arcs, and no leg lights (the showcase's first lights to drop).
	  * Flat-lit maps: no PointLights (VoltaicKit.light returns nil), and every emission x0.35 / Brightness x0.7.
	    BeamChain does the same for its Beams.
	  * Daylight: every light x0.5 (VoltaicKit.light).

	PLUMBING.
	  * One BindToRenderStep runner at RenderPriority.Last (after the camera and the viewmodel) steps every cast, each
	    one in a pcall. A frame that errors clears its cast. Every cast also has a watchdog deadline, and a Debris
	    backstop on its folder, so nothing is orphaned.
	  * BeamChains and shard parts are POOLED, as the showcase's budget asks. An idle pooled piece is parented to nil,
	    so workspace.IceMagicFX goes back to its pre-cast count once a cast ends.
	  * Nothing happens at require time. VoltaicKit, VoltaicTuning and ChainBoltShapes are required lazily, with timed
	    waits. If the shapes are missing, a stand-in zigzag is drawn with one warning. If the kit is missing, nothing is
	    drawn, with one warning.

	FLAGS (the owner's to check in Studio).
	  1 The shards are Neon WedgeParts, not VT_ChainBolt_Spark_01..03. Those hulls carry the comic ink shell and flat
	    normals (showcase flag 10). The ForceField shell's animated pattern on a 0.1-stud wedge is unverified. The shell
	    fades by Transparency: it is not a toon mesh.
	  2 The chip is Light on its first DRAWN frame. shard_look's u < 0.07 is shorter than a 60 Hz frame, so at the
	    game's rate it would never show.
	  3 Leg 1 leaves the caster's hand, not data.Origin (the eye). Origin is used when no hand is found within 12 studs.
	  4 Kit.billboard is not used: the star is a camera-facing particle, and its small comic offset is put in camera
	    space.
	  5 The shot clock is local (shotClock below), not VoltaicKit.clock. The contract's Kit.clock = elapsed / scale runs a
	    ShotTimeScale 0.25 review 4x FAST, the opposite of the game's convention (elapsed x scale; delays / scale).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ChainBoltFX = {}

----------------------------------------------------------------------------------------------------
-- The numbers: chain_bolt_bl.py's T, as the Roblox port reads them. Seconds of SHOT time from the press unless named;
-- a "frame" is one 60 Hz game frame. EVERY NUMBER IS A PROPOSAL (2026-09-25). ChainDelay and Range are replaced by
-- VoltaicTuning.ChainBolt's own values when that module loads, so the server's chain and the drawing cannot drift.
----------------------------------------------------------------------------------------------------
ChainBoltFX.Tuning = {
	-- 1 CAST PULSE: two frames from the press, the bolt on the second
	PulseArcs = { 3, 2 },          -- arcs on the pulse's first / second frame (its length = the pulse's frames)
	ThinPulseArcs = { 2, 1 },
	PulseAlpha = { 1.0, 0.7 },
	PulseArcLen = { 0.40, 0.75 },  -- studs from the palm
	PulseArc = { 0.05, 0.40, 3.2, 1.5 },    -- core width, glow width, core Brightness, glow Brightness
	PulseCone = 75,                -- degrees round the aim the arcs spit out in
	HandGlow = { { 0.42, 2.6 }, { 0.26, 2.0 } },   -- the palm sprite (Size, Brightness): the pulse / under the bolt's root
	HandZ = 0.55,                  -- its ZOffset: toward the camera, clear of the hand
	HandLight = { 2.5, 6.0 },      -- PointLight at the palm through the pulse (Brightness, Range); 0.4 of it one frame more

	-- 2 THE BOLT: hitscan, full length and intensity on its first frame
	Leg1 = 1 / 60,                 -- the press -> the bolt (the pulse's one-frame lead; 0 puts it on the pulse's first)
	Hold = 0.06, Wipe = 0.02,      -- full for 0.06 s, then wiped onto the target
	CoreK = 0.38,                  -- core Beam width / the stroke (the comic's nested cream bolt)
	GlowK = 3.1,                   -- glow Beam width / the stroke
	Bolt = { 3.4, 1.3 },           -- leg 1: core Brightness (Light), glow Brightness (Base)
	Snap = 1.12,                   -- x on the bolt's first frame
	Flicker = 0.08,                -- +- per 60 Hz frame after it
	LegLight = { 3.0, 4.0 },       -- the PointLight at each leg's middle while it is up: Brightness, Range (+ half the leg)
	ForkBright = 0.9,              -- a fork's Brightness x this

	-- 3 THE CHAIN: a second event, later, paler and hotter
	ChainDelay = 4 / 60,           -- leg to leg: four frames (VoltaicTuning.ChainBolt.ChainDelay replaces it)
	Chain = { 4.0, 1.25 },         -- core Brightness (Light), glow Brightness (Light)
	RelayOut = 0.30,               -- a chain leg leaves the relay this far toward its next body (the comic RELAY_OUT)

	-- 4 IMPACT: one frame after its leg
	ImpactAfter = 1 / 60,
	Star = { 0.02, 0.06, 0.02 },   -- pop / hold / fade (0.10 s: the comic NODE_LIFE)
	StarSize = 1.36,               -- particle Size (half the quad) of the authored star: STAR_TEX_R 1.6 x R 0.85
	StarPop = { 0.70, 1.18 },      -- x StarSize, popped up with ease_out_back
	StarZ = 1.2,                   -- ZOffset: toward the camera, clear of the body it hit
	StarCore = 2.6, StarGlow = 1.5, -- Brightness: core (Light, additive; x1.1 on a chain hit), glow (Base; a chain hit's Light)
	StarGlowEmission = 0.75,       -- more additive than a Beam glow (at 0.55 its alpha half laid Base over a tan body as beige)
	StarRoll = { 18, 58 },         -- degrees: the primary hit, a chain hit
	StarRollJitter = 12,           -- +- degrees, per cast
	StarOff = { 0.10, 0.05 },      -- studs right / up of the hit, in camera space (the comic NODE's placement)
	Flash = { 9.0, 12.0, 0.10 },   -- the hit's PointLight (Light): Brightness for ONE frame, Range, then decays over this
	FlashAfter = 0.55,             -- ...from this share of it
	FlashBack = 2.4,               -- studs back toward the shooter from the hit point: outside the body it hit
	Bloom = { 0.5, 0.10, 0.05 },   -- the caster's own first hit: Bloom Intensity +, Size +, then decaying with this tau
	CalmFlash = 0.6,               -- Reduce Flashing: the flash x this, eased in over two frames; no Bloom
	CalmBolt = 0.85,               -- ...and every bolt, arc, glow and star Brightness x this

	-- 5 DEBRIS: anim_chain_bolt.py's shards, a hot edge cooling as they fall
	Shards = 5, ThinShards = 2,
	Spark = { 0.02, 0.09, 0.12 },  -- pop / hold / shrink (0.23 s: gone before the next shot lands)
	SparkThrow = { 0.42, 2.15 },   -- studs from the hit, ease_out_cubic (the far end x each shard's gain)
	ShardDrop = 18.0,              -- studs/s^2 (VFXLibrary.VoltSparks' own Acceleration)
	ShardToward = 0.45,            -- studs toward the camera (the comic throw's depth offset)
	ShellScale = 1.12,             -- the ForceField shell round the chip
	Rim = { 2.4, 1.1, 1.5 },       -- the edge's strength: white-hot, at Base before the switch, the violet at its peak
	Sparks = { { 0.76, 0.115 }, { 0.58, 0.140 }, { 0.88, 0.095 } },   -- spark_pts(40..42): length, width (studs)
	WhiffSparks = 4,               -- VoltSparkBurst count where a whiff hits a wall

	-- DISCHARGE (StatusDischarge)
	DischargeSparks = 6, SelfZapSparks = 8,
	ZapArcs = { 3, 2, 1 }, ThinZapArcs = { 2, 1 }, ZapAlpha = { 1.0, 0.8, 0.6 },
	ZapLen = { 1.2, 2.2 }, ZapArc = { 0.08, 0.70, 3.4, 1.3 },

	-- plumbing
	Range = 55, --[[30, and 10 before that, until 2026-10-18]] -- VoltaicTuning.ChainBolt.Range replaces it (55 since handoff #7)
	HandSlack = 12,                -- studs: a hand further than this from the cast's origin is not trusted
	Stale = 1.0,                   -- shot seconds: a broadcast older than this on arrival is not drawn
	LocalMatch = 1.0,              -- server seconds: a broadcast joins the caster's own FireLocal made within this
	MergeWithin = 0.5,             -- shot seconds: ...and only while that cast is this young
	MaxLife = 1.6,                 -- shot seconds: the watchdog on any one cast
}
local T = ChainBoltFX.Tuning

local TOL = 0.25 / 60              -- a quarter frame: "on this frame" allowance against float drift in the clock
local FRAME_TOL = 0.25             -- the same, in frames
local ARC_SEGS = 4                 -- jag depth 2: four segments an arc
local POOL_CAP = 16                -- idle BeamChains kept per size
local SHARD_POOL_CAP = 40          -- idle shard pairs kept
local RUNNER = "SpellshotChainBoltFX"

----------------------------------------------------------------------------------------------------
-- plumbing: lazy requires (nothing at load)
----------------------------------------------------------------------------------------------------
local Kit, VFXLibrary, COL, SHAPE = nil, nil, nil, nil
local CHAIN_DELAY, RANGE = T.ChainDelay, T.Range
local retryAt = 0
local warned = {}

local function warnOnce(key, msg)
	if Kit and Kit.warnOnce then
		Kit.warnOnce("ChainBoltFX:" .. key, "[ChainBoltFX] " .. msg)
		return
	end
	if warned[key] then return end
	warned[key] = true
	warn("[ChainBoltFX] " .. msg)
end

--- IceMagic.<name>, pcall-required: a plain FindFirstChild first, then one timed wait.
local function requireIce(name, wait)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic") or ReplicatedStorage:WaitForChild("IceMagic", wait)
	if not ice then return nil end
	local m = ice:FindFirstChild(name) or ice:WaitForChild(name, wait)
	if not (m and m:IsA("ModuleScript")) then return nil end
	local ok, res = pcall(require, m)
	if ok and type(res) == "table" then return res end
	warnOnce("req:" .. name, ("IceMagic.%s failed to load: %s"):format(name, tostring(res)))
	return nil
end

local normalizeShapes -- defined with the shapes below

--- Loads VoltaicKit (required), VoltaicTuning and ChainBoltShapes (optional) once. False while the kit is missing.
local function libs()
	if Kit then return true end
	if os.clock() < retryAt then return false end
	local k = requireIce("VoltaicKit", 3)
	if not (k and k.BeamChain and k.clock and k.host and k.light) then
		retryAt = os.clock() + 5
		warnOnce("kit", "IceMagic.VoltaicKit is missing or failed to load: Chain Bolt draws nothing until it is back")
		return false
	end
	Kit, COL = k, k.COL
	-- warm the kit's own lazy requires here, where a timed wait may yield (the render-step runner must never yield)
	local ok, v = pcall(k.libs)
	VFXLibrary = ok and v or nil
	local tuning = requireIce("VoltaicTuning", 2)
	local cb = tuning and tuning.ChainBolt
	if type(cb) == "table" then
		CHAIN_DELAY = tonumber(cb.ChainDelay) or CHAIN_DELAY
		RANGE = tonumber(cb.Range) or RANGE
	else
		warnOnce("tuning", "IceMagic.VoltaicTuning.ChainBolt is missing: using ChainDelay 4/60 and Range 55")
	end
	SHAPE = normalizeShapes(requireIce("ChainBoltShapes", 2))
	return true
end

local function vfx()
	if VFXLibrary then return VFXLibrary end
	local ok, v = pcall(Kit.libs)
	VFXLibrary = ok and v or nil
	return VFXLibrary
end

-- The kit's settings reads, never allowed to break a cast
local function kitFlag(fn, ...)
	if not fn then return false end
	local ok, v = pcall(fn, ...)
	return ok and v == true
end

--- Seconds of SHOT time since the server time `t0`: real seconds x ShotTimeScale. This is the game's own convention
--- (PyroFX, AbilityFX: `(now - start) * ShotTimeScale()`), under which every server delay is divided by it, so a 0.25
--- review plays 4x slower. It is built from VoltaicKit.serverNow / timeScale rather than VoltaicKit.clock, whose
--- contract formula DIVIDES by the scale and would run a slowed review 4x FAST (flagged).
local function shotClock(t0)
	return (Kit.serverNow() - t0) * Kit.timeScale()
end

----------------------------------------------------------------------------------------------------
-- small maths
----------------------------------------------------------------------------------------------------
local function lerp(a, b, u) return a + (b - a) * u end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function span(t, a, b) return clamp01((t - a) / (b - a)) end
local function easeInQuad(u) u = clamp01(u) return u * u end
local function easeOutCubic(u) u = clamp01(u) return 1 - (1 - u) ^ 3 end

local function easeOutBack(x)
	x = clamp01(x) - 1
	return 1 + 2.70158 * x ^ 3 + 1.70158 * x ^ 2
end

--- anim_lib.pulse, e seconds in: 0 -> 1 over `up` (ease_out_back), held, 1 -> 0 over `down`; -1 outside it.
local function pulse(e, up, hold, down)
	if e < 0 then return -1 end
	if e < up then return easeOutBack(e / up) end
	if e < up + hold then return 1 end
	if e < up + hold + down then return 1 - easeInQuad((e - up - hold) / down) end
	return -1
end

local function perpAny(a)
	local p = a:Cross(Vector3.yAxis)
	if p.Magnitude < 1e-4 then p = a:Cross(Vector3.xAxis) end
	return p.Unit
end

--- A random direction within `spread` degrees of `axis` (uniform over the cap).
local function coneDir(axis, spread, r)
	local ct = 1 - r:NextNumber() * (1 - math.cos(math.rad(spread)))
	local st = math.sqrt(math.max(0, 1 - ct * ct))
	local ph = r:NextNumber(0, 2 * math.pi)
	local b = perpAny(axis)
	local c = axis:Cross(b)
	return (axis * ct + b * (st * math.cos(ph)) + c * (st * math.sin(ph))).Unit
end

--- anim_chain_bolt.face_roll(): the zigzag's plane turned to the camera. Its jog axis is the bolt's direction crossed
--- with the direction AWAY from the camera, square to the bolt.
local function jogAxis(a, b, d, camPos)
	local away = (a + b) / 2 - camPos
	away -= d * away:Dot(d)
	if away.Magnitude < 1e-6 then away = perpAny(d) end
	return d:Cross(away.Unit)
end

--- ribbon()'s outline as per-point Beam widths: the stroke falling to `taper` of itself down the run, a point at the end.
local function widths(n, stroke, taper)
	local w = table.create(n + 1)
	for i = 0, n do w[i + 1] = i < n and stroke * (1 - (1 - taper) * i / n) or 0 end
	return w
end

local function rootOf(model)
	if typeof(model) ~= "Instance" then return nil end
	if model:IsA("BasePart") then return model end
	local r = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if not (r and r:IsA("BasePart")) and model:IsA("Model") then r = model.PrimaryPart end
	if r and r:IsA("BasePart") then return r end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function isBodyPart(part)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then return false end
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function seedFrom(t, model)
	local s = math.floor((tonumber(t) or os.clock()) * 1000) % 1000000
	if typeof(model) == "Instance" then
		local name = model.Name
		for i = 1, math.min(#name, 24) do s = (s * 31 + string.byte(name, i)) % 1000003 end
	end
	return s + 1
end

----------------------------------------------------------------------------------------------------
-- THE SHAPES: ChainBoltShapes' baked legs (see its header for the frame), or a stand-in if the module is missing
----------------------------------------------------------------------------------------------------
-- bolt_family.build()'s arguments, for the stand-in only (Luau's Random cannot reproduce the Python seeds)
local FALLBACK_LEGS = {
	[1] = { Length = 10, Kinks = 5, Lean = 0.55, Stroke = 0.52, Native = 10.2949, Seed = 17,
		Forks = { { At = 2, Length = 1.90, Lean = 0.28, Seed = 3 }, { At = 5, Length = 1.50, Lean = 0.24, Seed = 6 } } },
	[2] = { Length = 8, Kinks = 6, Lean = 0.40, Stroke = 0.42, Native = 8.2783, Seed = 29,
		Forks = { { At = 3, Length = 1.20, Lean = 0.22, Seed = 11 } } },
}
local FALLBACK_CONST = { Taper = 0.72, ForkW = 0.46, ForkTaper = 0.30, ForkYaw = 24,
	Jit = { Jog = { 0.72, 1.28 }, Along = 0.20, ForkYaw = 9, ForkLen = { 0.85, 1.15 } } }

--- volt_lib.bolt_spine in Luau (the stand-in): down -Z, jogging alternately by `lean`, the ends on the axis.
local function boltSpine(length, kinks, lean, rng)
	local pts, n = {}, kinks + 1
	local side = rng:NextNumber() < 0.5 and 1 or -1
	for i = 0, n do
		local amp = lean * rng:NextNumber(0.62, 1)
		if i == 0 or i == n then amp = 0 end
		pts[#pts + 1] = Vector3.new(side * amp, 0, -i / n * length)
		side = -side
	end
	return pts
end

local function pointList(list)
	if type(list) ~= "table" then return nil end
	local out = {}
	for i, p in ipairs(list) do
		if typeof(p) ~= "Vector3" then return nil end
		out[i] = Vector3.new(p.X, 0, p.Z)
	end
	return #out >= 2 and out or nil
end

local function bakedLeg(S, k)
	local L = type(S) == "table" and type(S.Legs) == "table" and S.Legs[k]
	if type(L) ~= "table" then return nil end
	local spine = pointList(L.Spine)
	local native, stroke = tonumber(L.Native), tonumber(L.Stroke)
	if not (spine and native and native > 0.1 and stroke and stroke > 0) then return nil end
	local length = tonumber(L.Length) or -spine[#spine].Z
	if not (length and length > 0.1) then return nil end
	local forks = {}
	if type(L.Forks) == "table" then
		for _, F in ipairs(L.Forks) do
			local at, sub = tonumber(F.At), pointList(F.Sub)
			if at and sub and spine[at] then forks[#forks + 1] = { at = at, sub = sub } end
		end
	end
	return { spine = spine, length = length, native = native, stroke = stroke, forks = forks }
end

local function fallbackLeg(k)
	local D = FALLBACK_LEGS[k]
	local spine = boltSpine(D.Length, D.Kinks, D.Lean, Random.new(D.Seed))
	local forks = {}
	for _, F in ipairs(D.Forks) do
		local sub = boltSpine(F.Length, math.max(1, math.floor(#spine / 3)), F.Lean, Random.new(F.Seed))
		forks[#forks + 1] = { at = F.At, sub = sub }
	end
	return { spine = spine, length = D.Length, native = D.Native, stroke = D.Stroke, forks = forks }
end

local function pairOf(v, default)
	if type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then return { tonumber(v[1]), tonumber(v[2]) } end
	return default
end

function normalizeShapes(S)
	local out = { legs = {} }
	for k = 1, 2 do
		out.legs[k] = bakedLeg(S, k)
		if not out.legs[k] then
			warnOnce("shapes", "IceMagic.ChainBoltShapes is missing or malformed: drawing a stand-in zigzag "
				.. "(regenerate it with tools/gen_chain_bolt_shapes.py)")
			out.legs[k] = fallbackLeg(k)
		end
	end
	local C = type(S) == "table" and S or {}
	local J = type(C.Jit) == "table" and C.Jit or {}
	local FC, FJ = FALLBACK_CONST, FALLBACK_CONST.Jit
	out.taper = tonumber(C.Taper) or FC.Taper
	out.forkW = tonumber(C.ForkW) or FC.ForkW
	out.forkTaper = tonumber(C.ForkTaper) or FC.ForkTaper
	out.forkYaw = tonumber(C.ForkYaw) or FC.ForkYaw
	out.jit = { jog = pairOf(J.Jog, FJ.Jog), along = tonumber(J.Along) or FJ.Along,
		forkYaw = tonumber(J.ForkYaw) or FJ.ForkYaw, forkLen = pairOf(J.ForkLen, FJ.ForkLen) }
	return out
end

--- One leg's silhouette for one cast (chain_bolt_bl.leg_shape(k, jr)). This is the baked shape with its per-cast
--- jitter, in the spine frame (x = the jog, z = -along), plus its Beam widths:
---   * every interior spine point's jog is scaled and its corner slid along the run;
---   * each fork is folded back ACROSS the spine from its jittered base, turned +-ForkYaw and scaled in length
---     (Sub's z), its own jogs scaled.
local function castShape(k, rng)
	local B, J = SHAPE.legs[k], SHAPE.jit
	local src = B.spine
	local n = #src - 1
	local step = B.length / n
	local spine = table.create(n + 1)
	for i, p in ipairs(src) do
		if i == 1 or i == n + 1 then
			spine[i] = p
		else
			spine[i] = Vector3.new(p.X * rng:NextNumber(J.jog[1], J.jog[2]), 0,
				p.Z + rng:NextNumber(-1, 1) * J.along * step)
		end
	end
	local w = widths(n, B.stroke, SHAPE.taper)
	local core, glow = table.create(n + 1), table.create(n + 1)
	for i = 0, n do
		core[i + 1] = w[i + 1] * T.CoreK
		-- the glow opens out of the palm (or the relay): its first point at 0.35
		glow[i + 1] = w[i + 1] * T.GlowK * lerp(0.35, 1, clamp01(i / math.max(1, 0.15 * n)))
	end
	local forks = {}
	for _, F in ipairs(B.forks) do
		local base = spine[F.at]
		local yaw = math.rad(SHAPE.forkYaw + rng:NextNumber(-1, 1) * J.forkYaw) * (base.X >= 0 and -1 or 1)
		local lenK = rng:NextNumber(J.forkLen[1], J.forkLen[2])
		local c, s = math.cos(yaw), math.sin(yaw)
		local pts = table.create(#F.sub)
		for j, q in ipairs(F.sub) do
			local qx, qz = q.X * rng:NextNumber(J.jog[1], J.jog[2]), q.Z * lenK
			pts[j] = base + Vector3.new(qx * c - qz * s, 0, qx * s + qz * c)
		end
		local m = #pts - 1
		local fw = widths(m, B.stroke * SHAPE.forkW, SHAPE.forkTaper)
		local fc, fg = table.create(m + 1), table.create(m + 1)
		for i = 1, m + 1 do
			fc[i] = fw[i] * T.CoreK
			fg[i] = i == 1 and 0 or fw[i] * T.GlowK      -- the fork's glow grows out of the bolt (Width0 = 0)
		end
		forks[#forks + 1] = { pts = pts, core = fc, glow = fg }
	end
	return { spine = spine, core = core, glow = glow, forks = forks, length = B.length, native = B.native }
end

--- chain_bolt_bl.lay(): spine-frame points onto the leg a -> b. The comic mesh's frame (length centred on the midpoint,
--- the jog across) is aimed along the leg, and only its length is stretched: the jog stays in studs.
local function lay(src, mid, d, kLen, half, jog)
	local out = table.create(#src)
	for i, q in ipairs(src) do out[i] = mid + d * ((-q.Z - half) * kLen) + jog * q.X end
	return out
end

----------------------------------------------------------------------------------------------------
-- the pools: BeamChains (by size) and shard pairs. An idle piece is parented to nil.
----------------------------------------------------------------------------------------------------
local chainPool = {}    -- [maxSegments] = { entry }
local shardPool = {}    -- { entry }

local function dropEntry(e)
	pcall(function()
		if e.kind == "chain" then
			e.chain:Destroy()
			e.folder:Destroy()
		else
			e.chip:Destroy()
			e.shell:Destroy()
		end
	end)
end

--- A BeamChain of `maxSeg` segments under `parent`. BeamChain.new puts its own host under the entry's Folder; that
--- Folder is what moves in and out of the pool. A chain made on a flat-lit map carries that map's tone-down, so an
--- idle chain from the other kind of map is not reused.
local function takeChain(maxSeg, parent)
	local flat = kitFlag(Kit.flatLit)
	local list = chainPool[maxSeg]
	while list and #list > 0 do
		local e = table.remove(list)
		if e.flat == flat and pcall(function() e.folder.Parent = parent end) and e.folder.Parent == parent then
			return e
		end
		dropEntry(e)
	end
	local folder = Instance.new("Folder")
	folder.Name = "ChainBoltBeams"
	folder.Parent = parent
	return { kind = "chain", folder = folder, chain = Kit.BeamChain.new(folder, maxSeg), max = maxSeg, flat = flat }
end

local function giveChain(e)
	local ok = pcall(function()
		e.chain:Hide()
		e.folder.Parent = nil
	end)
	local list = chainPool[e.max]
	if not list then
		list = {}
		chainPool[e.max] = list
	end
	if ok and #list < POOL_CAP then list[#list + 1] = e else dropEntry(e) end
end

local function newWedge(name, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material = material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Reflectance = 0
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Transparency = 1
	return p
end

local function takeShard(parent)
	while #shardPool > 0 do
		local e = table.remove(shardPool)
		if pcall(function()
			e.chip.Parent = parent
			e.shell.Parent = parent
		end) then
			e.body = nil
			return e
		end
		dropEntry(e)
	end
	local e = { kind = "shard", chip = newWedge("ChainBoltChip", Enum.Material.Neon),
		shell = newWedge("ChainBoltEdge", Enum.Material.ForceField) }
	e.chip.Parent, e.shell.Parent = parent, parent
	return e
end

local function giveShard(e)
	local ok = pcall(function()
		e.chip.Transparency, e.shell.Transparency = 1, 1
		e.chip.Parent, e.shell.Parent = nil, nil
	end)
	if ok and #shardPool < SHARD_POOL_CAP then shardPool[#shardPool + 1] = e else dropEntry(e) end
end

----------------------------------------------------------------------------------------------------
-- particles: the palm glow and the relay star
----------------------------------------------------------------------------------------------------
local function emitter(att, name, tex, color, emission, bright, zoff, cast)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.Texture = tex
	pe.Color = ColorSequence.new(color)
	pe.LightEmission, pe.LightInfluence = emission * cast.emK, 0
	pe.Brightness = bright * cast.brK
	pe.Speed = NumberRange.new(0)
	pe.RotSpeed = NumberRange.new(0)
	pe.Drag = 0
	pe.Acceleration = Vector3.zero
	pe.ZOffset = zoff
	pe.Orientation = Enum.ParticleOrientation.FacingCamera
	pe.Rate = 0
	pe.Enabled = false
	pe.TimeScale = math.clamp(cast.ts, 0.01, 1)
	pe.Parent = att
	return pe
end

--- The palm sprite: one particle `life` long, locked to the hand host (which rides the hand every frame).
local function palmEmitter(att, size, bright, life, cast)
	local pe = emitter(att, "PalmGlow", Kit.Tex.Implosion, COL.Light, 1, bright, T.HandZ, cast)
	pe.Size = NumberSequence.new(size)
	pe.Transparency = NumberSequence.new(0)
	pe.Lifetime = NumberRange.new(life)
	pe.Rotation = NumberRange.new(0, 360)
	pe.LockedToPart = true
	return pe
end

--- The star's Size and Transparency over its life: T.Star's pulse (ease_out_back pop, hold, then fading as it
--- shrinks back), sampled into keypoints.
local function starSequences()
	local up, hold, down = T.Star[1], T.Star[2], T.Star[3]
	local life = math.max(1e-3, up + hold + down)
	local R, s0, s1 = T.StarSize, T.StarPop[1], T.StarPop[2]
	local times, sks = {}, {}
	local function add(tt, sk)
		local u = math.clamp(tt / life, 0, 1)
		if #times > 0 and u <= times[#times] + 1e-4 then return end
		times[#times + 1], sks[#sks + 1] = u, sk
	end
	add(0, 0)
	for i = 1, 4 do add(up * i / 4, easeOutBack(i / 4)) end
	add(up + hold, 1)
	for i = 1, 3 do
		local x = i / 3
		add(up + hold + down * x, 1 - x * x)
	end
	times[#times] = 1
	local fadeFrom = (up + hold) / life
	local size, alpha = {}, {}
	for i, u in ipairs(times) do
		size[i] = NumberSequenceKeypoint.new(u, R * (s0 + (s1 - s0) * sks[i]))
		alpha[i] = NumberSequenceKeypoint.new(u, u > fadeFrom + 1e-4 and clamp01(1 - sks[i]) or 0)
	end
	return NumberSequence.new(size), NumberSequence.new(alpha), life
end

local function starEmitter(att, name, tex, color, emission, bright, zoff, roll, cast)
	local size, alpha, life = starSequences()
	local pe = emitter(att, name, tex, color, emission, bright, zoff, cast)
	pe.Size, pe.Transparency = size, alpha
	pe.Lifetime = NumberRange.new(life)
	pe.Rotation = NumberRange.new(roll)
	pe.LockedToPart = false
	return pe
end

--- chain_bolt_bl.shard_look(u): the chip's colour, the edge's colour, its strength and its alpha at share u of its
--- life. The chip's Light -> violet-black is a SET (a tween passes through olive). The edge cools Light -> Base (both
--- yellow: a tween), goes dark for a beat, and comes up Dark: a SWITCH, never a blend (Base -> Dark in RGB is salmon).
local function shardLook(u)
	local body = u < 0.07 and COL.Light or COL.Violet
	local wh, base, vi = T.Rim[1], T.Rim[2], T.Rim[3]
	local rim, k
	if u < 0.25 then
		rim, k = COL.Light, lerp(wh, wh * 0.8, u / 0.25)
	elseif u < 0.55 then
		local v = (u - 0.25) / 0.30
		rim, k = COL.Light:Lerp(COL.Base, v), lerp(wh * 0.8, base, v)
	elseif u < 0.62 then
		rim, k = COL.Dark, 0
	else
		rim, k = COL.Dark, vi * math.min(1, (u - 0.62) / 0.12)
	end
	return body, rim, k, 1 - span(u, 0.82, 1.0)
end

----------------------------------------------------------------------------------------------------
-- A CAST: everything one Chain Bolt draws, on its own shot clock, stepped by the one runner
----------------------------------------------------------------------------------------------------
local Cast = {}
Cast.__index = Cast

local active = {}       -- [cast] = true
local bound = false

local function runner()
	local now = os.clock()
	for cast in pairs(active) do
		if now > cast.deadline then
			cast:Destroy()
		else
			local ok, err = pcall(cast.step, cast)
			if not ok then
				warnOnce("step", "a Chain Bolt frame failed and its cast was cleared: " .. tostring(err))
				cast:Destroy(true)
			end
		end
	end
	if bound and next(active) == nil then
		bound = false
		pcall(RunService.UnbindFromRenderStep, RunService, RUNNER)
	end
end

--- o = { seed, character?, side?, own?, thin?, calm?, from (Vector3), track? }
local function newCast(o)
	local folder = Instance.new("Folder")
	folder.Name = "ChainBolt"
	folder.Parent = Kit.fxFolder()
	local ts = math.max(0.01, Kit.timeScale())
	local calm, flat = o.calm == true, kitFlag(Kit.flatLit)
	local self = setmetatable({
		folder = folder, born = Kit.serverNow(), ts = ts,
		seed = o.seed, rng = Random.new(o.seed * 7919 + 13),
		character = o.character, side = o.side == "L" and "L" or "R",
		own = o.own == true, thin = o.thin == true, calm = calm, kb = calm and T.CalmBolt or 1,
		emK = flat and 0.35 or 1, brK = flat and 0.7 or 1,
		from = o.from, lastHand = o.from, track = o.track == true and typeof(o.character) == "Instance",
		legs = {}, arcs = {}, impacts = {}, held = {}, nLegs = 0, nImpacts = 0,
		bloomed = false, dead = false, rig = nil,
	}, Cast)
	self.handUntil = T.Leg1 + T.Hold + T.Wipe + 0.05
	self.host = Kit.host("ChainBoltHost", CFrame.new(o.from))
	self.host.Parent = folder
	local life = T.MaxLife / ts
	self.deadline = os.clock() + life + 0.5
	Debris:AddItem(folder, life + 2)             -- the backstop: even a runner that never ran cannot orphan it
	return self
end

function Cast:take(maxSeg)
	local e = takeChain(maxSeg, self.folder)
	self.held[e] = true
	return e
end

function Cast:takeShard()
	local e = takeShard(self.folder)
	self.held[e] = true
	return e
end

function Cast:give(e)
	if not (e and self.held[e]) then return end
	self.held[e] = nil
	if e.kind == "chain" then giveChain(e) else giveShard(e) end
end

--- Clears everything at once. `poison`: a frame failed, so the pooled pieces are destroyed, not put back.
function Cast:Destroy(poison)
	if self.dead then return end
	self.dead = true
	active[self] = nil
	for e in pairs(self.held) do
		if poison then dropEntry(e) elseif e.kind == "chain" then giveChain(e) else giveShard(e) end
	end
	table.clear(self.held)
	pcall(function() self.folder:Destroy() end)
end

function Cast:start()
	if self.dead then return end
	active[self] = true
	if not bound then
		bound = true
		RunService:BindToRenderStep(RUNNER, Enum.RenderPriority.Last.Value, runner)
	end
	local ok, err = pcall(self.step, self)          -- on this frame, not the next
	if not ok then
		warnOnce("step", "a Chain Bolt frame failed and its cast was cleared: " .. tostring(err))
		self:Destroy(true)
	end
end

--- Where leg 1 leaves: the caster's muzzle / grip, tracked while leg 1 is up. `from` when there is no trusted hand.
function Cast:handPos(t)
	if self.track and t < self.handUntil then
		local ok, m = pcall(Kit.muzzle, self.character, self.side)
		if ok and typeof(m) == "Vector3" and (m - self.from).Magnitude < T.HandSlack then
			self.lastHand = m
		end
	end
	return self.lastHand
end

-- 1 CAST PULSE: the palm's glow and light (the arcs are addArcs) -----------------------------------------------------
function Cast:addRig(toward)
	local part = Kit.host("ChainBoltHand", CFrame.new(self.from))
	part.Parent = self.folder
	local att = Instance.new("Attachment")
	att.Parent = part
	local frames = #(self.thin and T.ThinPulseArcs or T.PulseArcs)
	local g1 = palmEmitter(att, T.HandGlow[1][1], T.HandGlow[1][2] * self.kb, frames / 60, self)
	local g2 = palmEmitter(att, T.HandGlow[2][1], T.HandGlow[2][2] * self.kb, T.Hold, self)
	local aim = toward - self.from
	aim = aim.Magnitude > 1e-3 and aim.Unit or Vector3.zAxis
	local la = Instance.new("Attachment")
	la.Position = Vector3.new(0, 0.2, 0) - aim * 0.3     -- on the sleeve, just behind the palm
	la.Parent = part
	local light = Kit.light(la, T.HandLight[1], T.HandLight[2], COL.Light)
	self.rig = { part = part, glow2 = g2, light = light, frames = frames,
		dayK = light and light.Brightness / T.HandLight[1] or 1 }
	g1:Emit(1)
end

function Cast:stepRig(t, hand)
	local R = self.rig
	R.part.CFrame = CFrame.new(hand)
	local f = math.floor(t * 60 + FRAME_TOL)
	if R.light then
		if f > R.frames then
			R.light:Destroy()
			R.light = nil
		else
			R.light.Brightness = T.HandLight[1] * (f < R.frames and 1 or 0.4) * R.dayK
		end
	end
	return f <= R.frames
end

--- Small arcs re-jagged every 60 Hz frame: the cast pulse off the palm, or Discharge's self-zap. A = { t0, counts,
--- alphas, len, cone?, toward? (else any direction), jitter, core, glow, cb, gb, salt, at? (else the hand) }.
function Cast:addArcs(A)
	A.done, A.f, A.chains, A.rel = false, nil, {}, {}
	self.arcs[#self.arcs + 1] = A
end

function Cast:stepArcs(A, t, hand)
	local f = math.floor((t - A.t0) * 60 + FRAME_TOL)
	if f < 0 then return end
	if f >= #A.counts then
		for _, e in ipairs(A.chains) do self:give(e) end
		A.chains, A.done = {}, true
		return
	end
	local centre = A.at or hand
	if A.f ~= f then
		A.f = f
		local rr = Random.new(self.seed * 131 + A.salt * 17 + f)
		local count = A.counts[f + 1]
		local aim = A.toward and (A.toward - centre)
		aim = (aim and aim.Magnitude > 1e-3) and aim.Unit or nil
		table.clear(A.rel)
		for j = 1, count do
			local len = rr:NextNumber(A.len[1], A.len[2])
			local p0 = rr:NextUnitVector() * A.jitter
			local dir = (aim and A.cone) and coneDir(aim, A.cone, rr) or rr:NextUnitVector()
			A.rel[j] = Kit.jag(p0, p0 + dir * len, 2, 0.35 * len, rr)     -- relative to the centre: it rides the hand
		end
		while #A.chains < count do A.chains[#A.chains + 1] = self:take(ARC_SEGS) end
	end
	local alpha = A.alphas[f + 1] or 1
	for j, e in ipairs(A.chains) do
		local rel = A.rel[j]
		if rel and #rel >= 2 then
			local n = math.min(#rel, ARC_SEGS + 1)
			local pts, cw, gw = table.create(n), table.create(n), table.create(n)
			for i = 1, n do
				local u = (i - 1) / (n - 1)
				pts[i] = centre + rel[i]
				cw[i] = A.core * (1 - 0.6 * u)
				gw[i] = A.glow * (1 - 0.5 * u)
			end
			e.chain:Set(pts, cw, gw)
			e.chain:Look(COL.Light, COL.Base, A.cb * self.kb, A.gb * self.kb, alpha)
		else
			e.chain:Hide()
		end
	end
end

-- 2 / 3 THE LEGS ------------------------------------------------------------------------------------------------------
--- kind 1 = the bolt (Legs[1], glow in Base), 2 = a chain leg (Legs[2], glow in Light). `a` nil = the caster's hand.
function Cast:addLeg(kind, a, b, t0)
	self.nLegs += 1
	local L = { n = self.nLegs, kind = kind, a = a, b = b, t0 = t0, shape = castShape(kind == 1 and 1 or 2, self.rng),
		glowColor = kind == 1 and COL.Base or COL.Light, bright = kind == 1 and T.Bolt or T.Chain,
		on = false, done = false, fN = nil, kk = 1, drawn = false }
	self.legs[#self.legs + 1] = L
	return L
end

function Cast:legOn(L, a)
	L.on = true
	local S = L.shape
	L.spineE = self:take(#S.spine - 1)
	L.forkE = {}
	for i, F in ipairs(S.forks) do L.forkE[i] = self:take(#F.pts - 1) end
	if not self.thin then
		local b0 = T.LegLight[1] * self.kb
		L.att = Kit.attach(self.host, (a + L.b) / 2)
		L.light = Kit.light(L.att, b0, T.LegLight[2] + 0.5 * (L.b - a).Magnitude, COL.Light)
		L.dayK = L.light and L.light.Brightness / b0 or 1
	end
	if L.kind == 1 and self.rig then self.rig.glow2:Emit(1) end   -- the palm glow under the bolt's root
end

function Cast:endLeg(L)
	L.done = true
	if L.spineE then self:give(L.spineE) end
	for _, e in ipairs(L.forkE or {}) do self:give(e) end
	L.spineE, L.forkE = nil, nil
	if L.att then L.att:Destroy() end
	L.att, L.light = nil, nil
end

--- chain_bolt_bl.bolt_beams(): leg L, e seconds after it came up, as core + glow Beam chains down its spine and forks.
function Cast:stepLeg(L, t, hand, camPos)
	local e = t - L.t0
	if e < -TOL then return end
	if e >= T.Hold + T.Wipe then
		self:endLeg(L)
		return
	end
	e = math.max(0, e)
	local a, b = L.a or hand, L.b
	if not L.on then self:legOn(L, a) end
	local L0 = (b - a).Magnitude
	if L0 < 0.05 then
		L.spineE.chain:Hide()
		for _, fe in ipairs(L.forkE) do fe.chain:Hide() end
		return
	end
	local d = (b - a) / L0
	if e >= T.Hold then
		-- the wipe: squashed onto the target, which it leaves last (the comic flash_leg)
		local len = math.min(L0, math.max(0.25, L0 * (1 - easeInQuad((e - T.Hold) / T.Wipe))))
		a = b - d * len
	end
	local Lw = (b - a).Magnitude
	local mid = (a + b) / 2
	local jog = jogAxis(a, b, d, camPos)
	local S = L.shape
	local kLen, half = Lw / S.native, S.length / 2

	-- full on its first frame (x Snap), then +-Flicker per 60 Hz frame
	local fN = math.floor(e * 60 + 1e-6)
	if L.fN ~= fN then
		L.fN = fN
		local k = (fN == 0 or not L.drawn) and T.Snap
			or 1 + T.Flicker * Random.new(self.seed * 977 + L.n * 31 + fN):NextNumber(-1, 1)
		L.kk = self.kb * k
	end
	L.drawn = true
	local cb, gb = L.bright[1] * L.kk, L.bright[2] * L.kk

	local pts = lay(S.spine, mid, d, kLen, half, jog)
	L.spineE.chain:Set(pts, S.core, S.glow)
	L.spineE.chain:Look(COL.Light, L.glowColor, cb, gb, 1)
	for i, F in ipairs(S.forks) do
		local fe = L.forkE[i]
		fe.chain:Set(lay(F.pts, mid, d, kLen, half, jog), F.core, F.glow)
		fe.chain:Look(COL.Light, L.glowColor, cb * T.ForkBright, gb * T.ForkBright, 1)
	end
	if L.light then
		L.att.WorldPosition = (pts[1] + pts[#pts]) / 2 + Vector3.new(0, 0.3, 0)
		L.light.Brightness = T.LegLight[1] * self.kb * L.dayK
	end
end

-- 4 / 5 IMPACTS -------------------------------------------------------------------------------------------------------
--- A hit: the star, the flash, the Bloom (own, first), the shards. `from` = where its leg came from (nil: the hand).
function Cast:addImpact(at, from, t0, chain)
	self.nImpacts += 1
	local I = { style = "hit", n = self.nImpacts, at = at, from = from, t0 = t0, chain = chain == true,
		roll = (chain and T.StarRoll[2] or T.StarRoll[1]) + self.rng:NextNumber(-1, 1) * T.StarRollJitter,
		fired = false, done = false, life = 0 }
	self.impacts[#self.impacts + 1] = I
	return I
end

--- Sparks only (VFXLibrary.VoltSparkBurst): a whiff on a wall, or a discharge's landing.
function Cast:addSpark(at, normal, t0, count)
	local I = { style = "spark", at = at, normal = normal, t0 = t0, count = count, fired = false, done = false, life = 0 }
	self.impacts[#self.impacts + 1] = I
	return I
end

function Cast:fireImpact(I, hand, camCF)
	I.fired = true
	if I.style == "spark" then
		local V = vfx()
		if V and V.VoltSparkBurst then pcall(V.VoltSparkBurst, I.at, I.normal, not self.own, I.count) end
		return
	end
	local from = I.from or hand
	local dir = I.at - from
	dir = dir.Magnitude > 1e-3 and dir.Unit or camCF.LookVector

	-- the relay star: glow under core, both toward the camera by ZOffset
	local host = Kit.host("ChainBoltStar",
		CFrame.new(I.at + camCF.RightVector * T.StarOff[1] + camCF.UpVector * T.StarOff[2]))
	host.Parent = self.folder
	local att = Instance.new("Attachment")
	att.Parent = host
	local starLife
	local glow = starEmitter(att, "StarGlow", Kit.Tex.StarGlow or Kit.Tex.Implosion, I.chain and COL.Light or COL.Base,
		T.StarGlowEmission, T.StarGlow * self.kb, T.StarZ, I.roll, self)
	local core = starEmitter(att, "StarCore", Kit.Tex.StarCore or Kit.Tex.Implosion, COL.Light, 1,
		T.StarCore * self.kb * (I.chain and 1.1 or 1), T.StarZ + 0.01, I.roll, self)
	starLife = glow.Lifetime.Max
	glow:Emit(1)
	core:Emit(1)

	-- the flash: one frame at full, then decaying, 2.4 studs back toward the shooter
	local b0 = self.calm and T.Flash[1] * T.CalmFlash * 0.5 or T.Flash[1]
	I.att = Kit.attach(self.host, I.at - dir * T.FlashBack)
	I.light = Kit.light(I.att, b0, T.Flash[2], COL.Light)
	I.dayK = I.light and I.light.Brightness / b0 or 1
	I.flashFrames = 0

	-- Bloom: the caster's own first hit only (the kit skips it under Reduce Flashing and in first person)
	if self.own and not self.bloomed then
		self.bloomed = true
		if not self.calm then pcall(Kit.bloomPulse, T.Bloom[1], T.Bloom[2], T.Bloom[3]) end
	end

	-- the shards: anim_chain_bolt.throw_dirs, authored in the screen plane (x right, z up, y into the screen)
	local shardLife = T.Spark[1] + T.Spark[2] + T.Spark[3]
	local count = self.thin and T.ThinShards or T.Shards
	if count > 0 then
		local rnd = Random.new(self.seed * 31 + I.n)
		local right, up, look = camCF.RightVector, camCF.UpVector, camCF.LookVector
		I.look = look
		I.shards = {}
		for i = 0, count - 1 do
			local ang = (i + rnd:NextNumber(-0.18, 0.18)) / count * 2 * math.pi + 0.55
			local d = right * math.cos(ang) + look * rnd:NextNumber(-0.55, 0.30) + up * (math.sin(ang) + 0.28)
			d = d.Magnitude > 1e-4 and d.Unit or up
			local dims = T.Sparks[i % #T.Sparks + 1]
			I.shards[#I.shards + 1] = { e = self:takeShard(), d = d, gain = rnd:NextNumber(0.82, 1.25),
				len = dims[1], wid = dims[2], up = math.abs(d.Y) > 0.95 and right or Vector3.yAxis, shown = false }
		end
	end
	I.shardLife = shardLife
	I.life = math.max(starLife, 1 / 60 + T.Flash[3], count > 0 and shardLife or 0)
end

function Cast:endImpact(I)
	I.done = true
	if I.att then I.att:Destroy() end
	I.att, I.light = nil, nil
	for _, S in ipairs(I.shards or {}) do self:give(S.e) end
	I.shards = nil
end

function Cast:stepImpact(I, t, hand, camCF)
	local age = t - I.t0
	if age < -TOL then return end
	if not I.fired then self:fireImpact(I, hand, camCF) end
	age = math.max(0, age)
	if age >= I.life then
		self:endImpact(I)
		return
	end

	if I.light then
		local F1, fb, fd = 1 / 60, T.Flash[1], T.Flash[3]
		local after = math.max(0, age - F1)
		if after >= fd then
			I.att:Destroy()
			I.att, I.light = nil, nil
		else
			local first = I.flashFrames == 0 or age < F1 - TOL      -- ONE frame at full, whatever the frame rate
			local fall = (1 - clamp01(after / fd)) ^ 2
			local b
			if self.calm then
				b = fb * T.CalmFlash * (first and 0.5 or fall)
			else
				b = first and fb or fb * T.FlashAfter * fall
			end
			I.light.Brightness = b * I.dayK
			I.flashFrames += 1
		end
	end

	if I.shards then
		local life = I.shardLife
		local u = age / life
		local sk = math.max(0, pulse(age, T.Spark[1], T.Spark[2], T.Spark[3]))
		local bodyCol, rimCol, rimK, rimA = shardLook(u)
		local rimOpacity = rimA * clamp01(rimK / T.Rim[1])
		local sag = Vector3.new(0, -0.5 * T.ShardDrop * age * age, 0) - I.look * T.ShardToward
		local reach = easeOutCubic(u)
		for _, S in ipairs(I.shards) do
			local chip, shell = S.e.chip, S.e.shell
			local k = sk * S.gain
			if age >= life or k < 0.02 then
				if chip.Transparency ~= 1 then chip.Transparency = 1 end
				if shell.Transparency ~= 1 then shell.Transparency = 1 end
			else
				local r = lerp(T.SparkThrow[1], T.SparkThrow[2] * S.gain, reach)
				local p = I.at + S.d * r + sag
				local len, wid = S.len * k, S.wid * k
				-- the sliver runs out from p along its throw: thick at the tail, the wedge's edge at the tip
				local cf = CFrame.lookAt(p + S.d * (len / 2), p + S.d * len, S.up)
				local size = Vector3.new(wid * 1.7, wid * 2, len)
				chip.Size, chip.CFrame = size, cf
				shell.Size, shell.CFrame = size * T.ShellScale, cf
				-- white-hot on its first DRAWN frame (u < 0.07 is shorter than a 60 Hz frame), then violet-black
				local bc = S.shown and bodyCol or COL.Light
				S.shown = true
				if S.e.body ~= bc then
					S.e.body = bc
					chip.Color = bc
				end
				if chip.Transparency ~= 0 then chip.Transparency = 0 end
				shell.Color = rimCol
				shell.Transparency = 1 - rimOpacity
			end
		end
	end
end

-- the frame -----------------------------------------------------------------------------------------------------------
function Cast:step()
	if self.dead then return end
	local t = shotClock(self.born)
	local cam = workspace.CurrentCamera
	local camCF = cam and cam.CFrame or CFrame.new()
	local hand = self:handPos(t)
	local live = false
	if self.rig and self:stepRig(t, hand) then live = true end
	for _, A in ipairs(self.arcs) do
		if not A.done then
			live = true
			self:stepArcs(A, t, hand)
		end
	end
	for _, L in ipairs(self.legs) do
		if not L.done then
			live = true
			self:stepLeg(L, t, hand, camCF.Position)
		end
	end
	for _, I in ipairs(self.impacts) do
		if not I.done then
			live = true
			self:stepImpact(I, t, hand, camCF)
		end
	end
	if not live then self:Destroy() end
end

----------------------------------------------------------------------------------------------------
-- building a cast
----------------------------------------------------------------------------------------------------
function Cast:addPulse(toward)
	self:addRig(toward)
	self:addArcs({ t0 = 0, counts = self.thin and T.ThinPulseArcs or T.PulseArcs, alphas = T.PulseAlpha,
		len = T.PulseArcLen, cone = T.PulseCone, toward = toward, jitter = 0.06,
		core = T.PulseArc[1], glow = T.PulseArc[2], cb = T.PulseArc[3], gb = T.PulseArc[4], salt = 1 })
end

--- A chain leg from the relay at `prev` to the body at `cur`, and that body's impact one frame after it.
function Cast:addChainLeg(prev, cur, t0)
	local d = cur - prev
	local a = prev
	if d.Magnitude > 1e-3 then
		a = prev + d.Unit * math.min(T.RelayOut, d.Magnitude * 0.25) + Vector3.new(0, 0.05, 0)
	end
	self:addLeg(2, a, cur, t0)
	self:addImpact(cur, prev, t0 + T.ImpactAfter, true)
end

local function handle(cast)
	return { Destroy = function() cast:Destroy() end }
end

-- The caster's own FireLocal casts, oldest first, for their broadcast to join: [character or "self"] = { rec }
local recent = {}

local function recentKey(character)
	return typeof(character) == "Instance" and character or "self"
end

local function pushRecent(character, rec)
	local key = recentKey(character)
	for k, list in pairs(recent) do
		for i = #list, 1, -1 do
			if rec.at - list[i].at > 2 then table.remove(list, i) end
		end
		if #list == 0 and k ~= key then recent[k] = nil end
	end
	local list = recent[key] or {}
	recent[key] = list
	list[#list + 1] = rec
end

local function takeRecent(character)
	local list = recent[recentKey(character)]
	if not list then return nil end
	local now = Kit.serverNow()
	while #list > 0 do
		local rec = table.remove(list, 1)
		if now - rec.at <= T.LocalMatch then return rec end
	end
	return nil
end

local function vectors(list)
	local out = {}
	if type(list) == "table" then
		for _, p in ipairs(list) do
			if typeof(p) ~= "Vector3" then break end
			out[#out + 1] = p
		end
	end
	return out
end

----------------------------------------------------------------------------------------------------
-- THE API
----------------------------------------------------------------------------------------------------
--- The caster's predicted cast, drawn on the fire frame: the pulse at the palm, leg 1 from the muzzle to `toPos` one
--- frame later. opts.Hit (or opts.Part on a character) also draws the predicted impact; opts.Wall (+ opts.Normal) the
--- wall sparks of a whiff. The server's ChainBolt broadcast then joins this cast (Fire with SkipFirst).
function ChainBoltFX.FireLocal(character, side, fromPos, toPos, opts)
	if not RunService:IsClient() then return nil end
	if typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then return nil end
	if not libs() then return nil end
	opts = type(opts) == "table" and opts or {}
	local now = Kit.serverNow()
	local char = typeof(character) == "Instance" and character or nil
	if char then pcall(Kit.muzzle, char, side) end        -- warm the kit's hand lookup outside the render step
	local cast = newCast({ seed = seedFrom(now, char), character = char, side = side, own = true,
		thin = opts.Thin == true or kitFlag(Kit.thin, char), calm = kitFlag(Kit.reduceFlashing),
		from = fromPos, track = char ~= nil })
	cast:addPulse(toPos)
	cast:addLeg(1, nil, toPos, T.Leg1)
	local predicted = false
	if opts.Hit == true or isBodyPart(opts.Part) then
		cast:addImpact(toPos, nil, T.Leg1 + T.ImpactAfter, false)
		predicted = true
	elseif opts.Wall == true then
		local n = typeof(opts.Normal) == "Vector3" and opts.Normal or (fromPos - toPos)
		cast:addSpark(toPos, n, T.Leg1 + T.ImpactAfter, T.WhiffSparks)
	end
	pushRecent(char, { at = now, predicted = predicted, cast = cast })
	cast:start()
	return handle(cast)
end

--- The ChainBolt broadcast (CONTRACT section 5). opts.SkipFirst: this client's FireLocal drew leg 1, so only the
--- chain legs and the impacts are drawn, joined onto that local cast. opts.Own forces the caster's-own treatment.
function ChainBoltFX.Fire(data, opts)
	if not RunService:IsClient() or type(data) ~= "table" then return nil end
	if not libs() then return nil end
	opts = type(opts) == "table" and opts or {}
	if type(data.T0) == "number" and shotClock(data.T0) > T.Stale then return nil end   -- stale: draw nothing
	local character = typeof(data.Character) == "Instance" and data.Character or nil
	local points = vectors(data.Points)
	local endPos = typeof(data.End) == "Vector3" and data.End or nil
	if #points == 0 and endPos then points[1] = endPos end
	if #points == 0 then return nil end
	local hits = type(data.Hits) == "table" and #data.Hits or 0
	local origin = typeof(data.Origin) == "Vector3" and data.Origin or nil
	local dir = typeof(data.Dir) == "Vector3" and data.Dir.Magnitude > 1e-3 and data.Dir.Unit or nil
	local shooter = origin or (dir and points[1] - dir * 4) or nil
	local own = opts.Own == true or kitFlag(Kit.isOwn, character)
	local thin = kitFlag(Kit.thin, character)
	local calm = kitFlag(Kit.reduceFlashing)
	local wall = hits == 0 and origin ~= nil and (points[1] - origin).Magnitude < RANGE - 0.3
	local wallNormal = origin and (origin - points[1]) or (dir and -dir) or Vector3.yAxis

	if opts.SkipFirst then
		local rec = takeRecent(character)
		local cast, t = rec and rec.cast, 0
		if cast and not cast.dead then
			t = shotClock(cast.born)
			if t > T.MergeWithin then cast = nil end
		else
			cast = nil
		end
		local fresh = cast == nil
		if fresh then
			cast = newCast({ seed = seedFrom(data.T0 or Kit.serverNow(), character), character = character,
				side = data.Side, own = own, thin = thin, calm = calm, from = points[1], track = false })
		end
		if hits > 0 and not (rec and rec.predicted) then
			cast:addImpact(points[1], fresh and shooter or nil, fresh and 0 or math.max(t, T.Leg1 + T.ImpactAfter), false)
		end
		-- joined late (a round trip after leg 1): the first chain leg comes up on the next frame, so its impact still
		-- lands one frame after it
		local first = fresh and 0 or math.max(t + 1 / 60 - TOL, T.Leg1 + CHAIN_DELAY)
		for i = 2, #points do cast:addChainLeg(points[i - 1], points[i], first + (i - 2) * CHAIN_DELAY) end
		if fresh then cast:start() end
		return handle(cast)
	end

	-- everyone else's cast (or an unpredicted own one): the whole thing, from the caster's hand
	local hand
	if character then
		local ok, m = pcall(Kit.muzzle, character, data.Side)
		if ok and typeof(m) == "Vector3" and (not origin or (m - origin).Magnitude < T.HandSlack) then hand = m end
	end
	local from = hand or origin
	local cast = newCast({ seed = seedFrom(data.T0 or Kit.serverNow(), character), character = character,
		side = data.Side, own = own, thin = thin, calm = calm, from = from or points[1], track = hand ~= nil })
	if from then
		cast:addPulse(points[1])
		cast:addLeg(1, nil, points[1], T.Leg1)
	end
	if hits > 0 then
		cast:addImpact(points[1], not from and shooter or nil, T.Leg1 + T.ImpactAfter, false)
	elseif wall then
		cast:addSpark(points[1], wallNormal, T.Leg1 + T.ImpactAfter, T.WhiffSparks)
	end
	for i = 2, #points do cast:addChainLeg(points[i - 1], points[i], T.Leg1 + (i - 1) * CHAIN_DELAY) end
	cast:start()
	return handle(cast)
end

--- StatusDischarge { From, To? }: a chain-leg bolt from From's root to To's plus VoltSparkBurst on To. With no To, a
--- self-zap: a burst of arcs off From's root and a spark burst.
function ChainBoltFX.Discharge(fromModel, toModel)
	if not RunService:IsClient() then return nil end
	if not libs() then return nil end
	local fr = rootOf(fromModel)
	if not fr then return nil end
	local a = fr.Position
	local tr = rootOf(toModel)
	local own = kitFlag(Kit.isOwn, fromModel) or kitFlag(Kit.isOwn, toModel)
	local thin = kitFlag(Kit.thin, fromModel) and (tr == nil or kitFlag(Kit.thin, toModel))
	local cast = newCast({ seed = seedFrom(Kit.serverNow(), fromModel), own = own, thin = thin,
		calm = kitFlag(Kit.reduceFlashing), from = a, track = false })
	if tr and (tr.Position - a).Magnitude > 0.1 then
		local b = tr.Position
		cast:addLeg(2, a, b, 0)
		cast:addSpark(b, a - b, T.ImpactAfter, T.DischargeSparks)
	else
		cast:addArcs({ t0 = 0, counts = thin and T.ThinZapArcs or T.ZapArcs, alphas = T.ZapAlpha, len = T.ZapLen,
			jitter = 0.3, at = a, core = T.ZapArc[1], glow = T.ZapArc[2], cb = T.ZapArc[3], gb = T.ZapArc[4], salt = 2 })
		cast:addSpark(a, Vector3.yAxis, 0, T.SelfZapSparks)
	end
	cast:start()
	return handle(cast)
end

--- HARNESS ONLY: the whole cast from a fixed `originPos` through `points` (every one a hit), drawn as the caster's own.
--- opts: Thin, Calm (true / false forces Reduce Flashing's look; nil reads the setting), Seed.
function ChainBoltFX.Review(originPos, points, opts)
	if not RunService:IsClient() then return nil end
	if typeof(originPos) ~= "Vector3" then return nil end
	if not libs() then return nil end
	opts = type(opts) == "table" and opts or {}
	local pts = vectors(points)
	if #pts == 0 then return nil end
	local calm = opts.Calm
	if calm == nil then calm = kitFlag(Kit.reduceFlashing) end
	local cast = newCast({ seed = tonumber(opts.Seed) or seedFrom(Kit.serverNow(), nil), own = true,
		thin = opts.Thin == true, calm = calm == true, from = originPos, track = false })
	cast:addPulse(pts[1])
	cast:addLeg(1, nil, pts[1], T.Leg1)
	cast:addImpact(pts[1], nil, T.Leg1 + T.ImpactAfter, false)
	for i = 2, #pts do cast:addChainLeg(pts[i - 1], pts[i], T.Leg1 + (i - 1) * CHAIN_DELAY) end
	cast:start()
	return handle(cast)
end

--- EXTRA: clears every cast in flight (a round reset, the harness).
function ChainBoltFX.Clear()
	for cast in pairs(active) do cast:Destroy() end
end

return ChainBoltFX
