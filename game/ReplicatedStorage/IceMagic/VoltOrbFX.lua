--[[
	VoltOrbFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/VoltOrbFX

	VOLT ORB, Voltaic's Defense technique (2026-09-25): a crackling orb lobbed on a real arc that bursts into lightning on
	contact or when its fuse runs out. The Studio port of the Blender showcase -- vfx_blocking/voltaic/VOLT_ORB_showcase.md
	and blender_scripts/voltaic/volt_orb_bl.py (its T table is Tuning below, under the same names; its OrbFX / orb_draw /
	seam_beams / core_crack_beams / Burst / impact_frame / shard_state are ported function for function). Like Chain
	Bolt's re-lit look, this is the kit's RE-LIT exception: Neon parts, textured Beams, soft sprites, PointLights and a
	Bloom kick -- Overcharge, Railspike and Cascade have since been re-lit the same way (OverchargeFX, RailspikeFX,
	CascadeFX).

	THE API (D:\voltkit_scratch\castable\CONTRACT.md section 6)
	  Windup(character, opts) -> handle   the 0.31 s in the hand. opts.Own (the local caster's own cast), opts.T0 (the
	                                      press in server time; default now). handle:Stop() pops it, handle:Destroy()
	                                      removes it at once (VoltaicClient stops an own windup the server never threw).
	  Throw(data)    VoltOrbThrow { Character, From, Vel, T0, ReleaseAt, Gravity, Fuse, Seed }: the flight on the
	                 broadcast path From + Vel*t + 0.5*(0, -Gravity, 0)*t^2, t = SHOT seconds since ReleaseAt. The local
	                 caster's own Windup handle is ADOPTED (the orb in its hand flies); anyone else's orb is made here and
	                 its windup drawn skipping ahead from T0.
	  Burst(data)    VoltOrbBurst { Character, At, Normal, Direct, Nearest, Air, T0 }: contact -> crack -> break -> the
	                 violet release -> three strikes -> afterglow, on the burst's own clock from T0.
	  Fizzle(data)   VoltOrbFizzle { Character, At? }: a small pop, and the orb is gone.
	  EXTRA  SetRibbonNormal("Y" | "Z") -- see FACE BEAMS below; for the harness's one-face check (design step 6.1).

	THE ORB. Built ONCE as a template from ReplicatedStorage.VoltaicMeshes.VoltaicVoltOrb (VO_Core, VO_Kernel,
	VO_Plate_01..20 via VoltaicKit.orbMesh: Neon, the plates Color3 (30, 13, 54), the core Neon Dark x 0.12-0.22) and
	ReplicatedStorage.Spellshot.VoltOrbKitData, then CLONED per cast. Every plate sits rigidly where the import put it
	relative to VO_Core's pivot (the orb's centre); each piece is placed by its PIVOT (VoltaicKit.placeAt semantics:
	cf * KIT_TURN * CFrame.new(-BasePivot * scale)), all 22 in one workspace:BulkMoveTo per frame.
	  FACE BEAMS (2 per plate: the light, Tex.Facet LightEmission 0.85, and the depth, Tex.Depth 0.6, sharing their two
	  attachments; ZOffset keeps the light over the depth). A Beam triangle: Attachment0 on the base edge (Width0 = W0),
	  Attachment1 at the apex (Width1 = 0), FaceCamera false, Segments 32. The data's A0 / A1 lie on the plate's FLAT
	  plane, 0.12-0.23 studs UNDER the curved plate (measured on the import: plate pivots sit 0.49-0.59 from the centre of
	  a 0.70 ball) -- drawn there they would be hidden inside it. So (showcase flag 10) both ends are pushed out radially
	  to the ball + FaceLift, the Beam is bowed along its length on the great circle between them (CurveSize = the cubic
	  Bezier handle 4/3 tan(theta/4) r, each attachment's X axis on the arc's tangent), and its width is the base edge
	  pushed out too, FaceSpread of the way (1 = the plate's full angular width, whose corners then float ~0.08 off the
	  ball; 0 = the flat W0). The ribbon must lie IN the plate: the Roblox docs (Beam, Beams guide) say only that a
	  FaceCamera=false Beam "is oriented by its attachments" and that CurveSize runs along each attachment's X axis --
	  they never name the axis its width lies across. RibbonNormal = "Y" takes the attachment's Y (SecondaryAxis) as the
	  ribbon's normal (width along its Z); "Z" swaps them. Both frames keep X on the curve, so the flip is the only
	  unknown. UNVERIFIED IN ENGINE: check one plate (design step 6.1) and flip with SetRibbonNormal if it stands on edge.
	  THE CRACKS: 30 great-circle arcs (VoltOrbKitData.Seams, orb-local to the core's pivot), each a core + glow Beam
	  pair (FaceCamera, Tex.SeamHot, Wrap, TextureLength 1.4) bowed along its arc with CurveSize, riding the core and
	  pushed out as the plates breathe; the hot spots scroll (TextureSpeed, neighbours opposite ways) 0.9 -> 7.5 studs/s
	  with the fuse. Under them the same 30 arcs on the core carry the VIOLET core-crack pair (the forming core in the
	  hand, the release at the break), off otherwise.
	  THE COUNTDOWN is the material: faces 1.9 -> 5.0 and toward Light, each shimmering on its own phase; the violet
	  depths go dark at 72 % of the fuse and ignite yellow at 80 %; the surge 3 -> 9 Hz dipping 30 %; the crackle 1 -> 6
	  slots of small forked arcs (Kit.BeamChain) held to the shell, always one alive, placed on the side facing THIS
	  client's camera; a Base corona and the violet halo (BillboardGuis, the halo capped at 1.8 x its height over the
	  floor); the orb's yellow and violet PointLights.

	FIRST PERSON (showcase flag 7). The local caster's orb in the hand is drawn at the viewmodel fist but STANDS IN for
	an orb of true size FPDepth studs out along the eye -> fist line (TerraFX's Boulder Shot rule): drawn scale =
	distance from the eye / FPDepth. After the release it runs out onto the server's path over FPMerge keeping that
	rule, so it simply grows to true size as it leaves. Lights sit at the virtual (true-size) position.

	CLOCKS. Everything is SHOT time: (server time - T0) x VFXLibrary.ShotTimeScale() (the house rule: AbilityFX's
	Aftershock clock, VoltaicHandler's own orb stepping). NOT VoltaicKit.clock, which DIVIDES by the time scale (the
	contract's formula) and would run 4x fast at a 0.25 review -- flagged. Emitters take TimeScale, Beam scroll speeds
	are scaled. The orb flies the broadcast path exactly; each client also sweeps its own copy (HitRadius 1.0) and holds
	the orb at its own contact (or at the fuse) until the server's Burst arrives; with no Burst by Fuse + Linger it is
	removed silently.

	THE BURST (showcase section 3 "The impact"): contact -- the flash sprite, the flash light (18 / 24, 1.3 over the
	crater), half the Bloom kick, a camera punch; the CRACK (0.09 s: the orb kicks up to 1.45 on a floor, swells 8 %,
	plates shoved 0.25, every face floods, cracks widen and blaze, 3 more wild arc slots, the violet light 5.6 / 11.2);
	the BREAK (the 20 plates fly as shrapnel carrying their face Beams, cooling Light -> Base -> dark -> dim violet,
	shrinking, skidding to rest on their lowest corner on a floor); the RELEASE (0.09-0.17: the violet core bursts out
	with its 30 violet cracks, swelling 1.8x and shrinking away, the Dark implosion sprite 1.6 -> 8.5, the violet light
	8 / 16); STRIKES per the Strikes table (bolts via Kit.BeamChain: a white-hot core in a wide Base glow, the glow held
	off the release within 1.6 studs until 0.17; 5 floor + 3 air + one into the Nearest body, then 3+2, 2+1; an
	air-burst, a body struck directly or a wall hit spreads every way (showcase flag 3), a wall's bolts turned back out
	of it, every bolt stopped on the first geometry it would enter, the floor found through any bodies); four bolt
	PointLights 60 % down strike 1's longest floor bolts that outlast the last bolt
	by 0.5 s; the full Bloom kick at 0.17 (near and on screen only); the AFTERGLOW (a floor burst only): the Tex.Scorch
	Decal 7.5 studs gone by +1.75 s, strike 1's floor bolts pressed flat to their inner 55 % as glowing cracks cooling
	yellow -> dark -> violet (never through pink), a flat glow pool, smouldering embers, a cooling after-light.
	Particles come ONLY from VFXLibrary: GroundSurgeBurst / GroundSurgeEmitter (Voltaic's soft sparkle / glow / smoke
	presets, re-tuned through their `extra` argument to the showcase's ORB_KIT) and VoltSparkBurst (the fizzle's pop).

	SETTINGS. Reduce Flashing: CalmStrikes / CalmAirStrikes (one restrike, no dark gap; a single strike in the air),
	bolts x0.65, flash and bolt lights x0.6, the contact sprite x0.75, no Bloom, no camera punch, the surge (and each
	face's shimmer) at most 4 Hz and 12 % deep. Thin enemy VFX (VoltaicKit.thin): half the crackle slots, trail and
	sheds, 4 windup arcs, 0.6 of the bolts and no forks (bar the one into a body), 3 burned cracks without forks, the
	violet core cracks' core layer only, the shards without their depth; particle counts halved by VFXLibrary. Flat-lit
	maps: no PointLights (VoltaicKit.light returns nil), Beams and emitters toned down by the Kit / VFXLibrary.
	Daylight: every light x0.5 and no Bloom Threshold drop.

	BUDGET (hard caps, one orb at High; "Beams" counts core and glow halves separately):
	  static     40 face (20 light + 20 depth), 60 crack, 60 violet core-crack (lit only in the windup and the release)
	  crackle    MaxCrackle 8 slots (thin 4): each an 8-segment arc + a 2-segment fork = 20 -> <= 160
	  windup     7 arcs (thin 4), 4 + 2 segments = 12 each -> <= 84, 0.00-0.14 s; the SAME pool then carries the trail
	  trail      MaxTendrils 6 live (thin 3), 4 + 2 segments -> <= 72
	  bolts      MaxBoltSlots 9 (thin 6): an 8-segment bolt + one 4-segment fork = 24 each -> <= 216 (showcase: <= 280); a
	             restrike reuses strike 1's slots (the showcase's depth-4 fine bolts are drawn at depth 3, one fork each)
	  afterglow  5 burned cracks (thin 3), 4 + 2 segments -> <= 60, plus 1 pool Beam
	  (plus Kit.BeamChain's round caps over sharply broken joints, a few dozen at most)
	  MEASURED (a sandboxed run of this file, enabled Beams counted every frame, 2026-09-25): windup ~180, flight
	  ~200, the crack ~260, strike 1's first frames ~384 (the release's 60 violet cracks + 40 shard faces + strike 1's
	  bolts + the 60 burned-crack Beams revealing + caps -- above the showcase's ~320 estimate, which listed the burned
	  cracks under the afterglow), the afterglow ~76. Thin: flight ~158, the burst ~188.
	  PointLights <= 7 per orb at once: 2 while the orb lives; at the burst flash + violet + 4 bolt lights +
	  after-light (measured: 7). Two casters' bursts overlapping add up (no cross-orb cap).
	The bolt slots are pre-made one per frame during the flight, so the burst frame does not build 200 Beams.
	Cut first if frames drop: the burned cracks' forks, the crackle's forks, MaxBoltSlots.

	LOAD SAFETY. Requiring this module does nothing but GetService (the server may require it: every API returns nil
	there). VoltaicKit and VoltOrbKitData are fetched lazily with timed waits the first time a function is called; a
	missing piece is warned about once and degrades (no meshes: no body; no kit data: no body and no crackle; no Kit:
	nothing). Every per-frame step runs in one BindToRenderStep after the viewmodel, pcall-guarded per orb: an orb whose
	frame errors is removed with everything it made. Each orb's instances live in one Folder under the Kit's FX folder
	(with a Debris backstop), destroyed when it ends, when its caster is gone before the release, or on a new cast.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local VoltOrbFX = {}

----------------------------------------------------------------------------------------------------
-- THE TUNING: volt_orb_bl.py's T (every number a PROPOSAL, 2026-09-24), plus the port's own (marked PORT).
-- Seconds are SHOT seconds: from the press (1-2), from the release (3), from contact (4).
----------------------------------------------------------------------------------------------------
VoltOrbFX.Tuning = {
	-- 1 WINDUP
	Windup = 0.06, Throw = 0.06,                 -- (2026-10-13 hold-to-aim) formed at 0.06, released at 0.12 (VoltaicTuning.VoltOrb.ReleaseAt)
	WindupArcs = 7, WindupArcFrom = { 1.6, 2.6 }, WindupArcStart = { 0.0, 0.05 }, WindupArcLife = 0.13,
	WindupArc = { 0.06, 0.45, 1.8, 1.4 },        -- core width, glow width, core Brightness, glow Brightness
	WindupFork = 0.4, WindupMotes = 24, Implode = { 0.02, 0.20 },
	KernelAt = 0.05, CoreGrow = { 0.08, 0.20 }, FacetsIn = { 0.13, 0.245 }, FacetFly = 0.07, FacetFrom = 1.4,
	PalmLight = 0.5, PalmViolet = 2.0,
	HandLift = 0.9, HandAhead = 0.4,             -- PORT: third person, the orb's centre over / ahead of the right grip
	FPDepth = 6.0, FPLift = 0.55, FPAhead = 0.45, FPMerge = 0.20,   -- PORT: first person (see the header)
	Merge = 0.06,                                -- PORT: third person, hand -> the server's path after the release
	GiveUp = 3.0,                                -- PORT: an own windup never thrown pops this long after 0.31
	-- 2 THE ORB
	Radius = 0.70, CoreScale = 0.88,
	CoreDark = { 0.12, 0.22 },
	FacetGlow = { 1.9, 5.0 }, DepthGlow = { 1.6, 0.8, 1.6 }, DepthIgnite = { 0.72, 0.80 },
	FacetShimmer = { 0.22, 1.5, 5.5 }, FacetHot = 0.55,
	FaceLift = 0.012,                            -- studs the face light lies off the ball (volt_orb_bl FACET_LIFT)
	FaceSpread = 0.5,                            -- PORT: the face triangle's base edge, flat W0 (0) -> the plate's full width (1)
	RibbonNormal = "Y",                          -- PORT: the attachment axis a FaceCamera=false Beam's ribbon faces (header)
	SeamCore = { 0.075, 2.6, 4.6 }, SeamGlow = { 0.46, 0.85, 1.6 }, SeamHot = { 1.4, 0.9, 7.5 },
	PulseHz = { 3.0, 9.0 }, PulseDepth = 0.30, CalmPulseHz = 4.0, CalmPulseDepth = 0.12,
	Breathe = 0.05, Strain = 0.035, Spin = { 2.5, 6.5 },
	Crackle = { 1, 6 }, CrackleLife = { { 0.08, 0.14 }, { 0.03, 0.055 } }, CrackleRest = { { 0.0, 0.05 }, { 0.0, 0.012 } },
	CrackleLen = { 0.28, 0.62 }, CrackleBow = { 0.04, 0.10 }, CrackleFork = { 0.5, 0.10, 0.22 },
	CrackleCore = { 0.05, 3.2 }, CrackleGlow = { 0.30, 1.5 }, CrackleUp = 0.7, Touch = { 0.14, 2.2 },
	OrbLight = { 6.0, 24.0 }, OrbLightUp = 0.20, CoreLight = { 1.6, 7.0 },
	Halo = { 2.6, 0.45, 2.5 }, Corona = { 0.95, 1.5 },
	LayoutSeed = 3,                              -- the plates' breathe / twist / shimmer phases (volt_orb_bl ORB_SEED)
	-- 3 FLIGHT (the path is the server's: VoltOrbThrow's From, Vel, Gravity, Fuse)
	Gravity = 72, Fuse = 1.25, HitRadius = 1.0, Linger = 0.5,
	TrailRate = 70, TrailLife = { 0.04, 0.08 }, TrailLen = { 0.8, 2.0 }, TrailFork = 0.5, TrailGap = { 0.8, 1.3 },
	TrailScreen = 1.6, TrailCore = { 0.07, 2.0 }, TrailGlow = { 0.8, 1.0 }, ShedRate = 30, ShedBack = { 2.5, 3.5 },
	-- 4 IMPACT
	Crack = 0.09, CrackShove = 0.25, CrackLift = 1.45,
	Strikes = { { 0.12, 0.25, 1.0 }, { 0.27, 0.35, 0.65 }, { 0.37, 0.43, 0.4 } },
	CalmStrikes = { { 0.12, 0.29, 1.0 }, { 0.29, 0.40, 0.6 } },
	AirStrikes = { { 0.12, 0.25, 1.0 }, { 0.25, 0.34, 0.6 } },
	CalmAirStrikes = { { 0.12, 0.32, 1.0 } },
	CalmBolts = 0.65, StrikeBolts = { { 5, 3 }, { 3, 2 }, { 2, 1 } },
	BoltLen = { 5.0, 8.5 }, BoltReveal = 0.035, BoltShape = { 3, 0.24, 0.70 },
	BoltCore = { 0.12, 4.0 }, BoltGlow = { 2.0, 1.3 }, BoltLight = { 4.8, 9.0, 0.50, 4 },
	Forks = { 1, 2 }, TargetReach = 7.5,
	ShardSpeed = { 8.0, 15.0 }, ShardLift = { 3.0, 7.0 }, AirShardLift = { 1.0, 3.0 }, ShardSpin = { 10.0, 25.0 },
	ShardLife = 0.45, ShardGravity = 60.0,
	Sparks = 34, Embers = 18, Smoke = 5, Dust = 4, HitSparks = 8,
	FlashLight = { 18.0, 24.0, 0.30 }, Relight = 0.7, ReleaseClear = 1.6, FloorGlow = 0.8, Release = 0.03,
	BurstLight = { 8.0, 16.0, 0.45 }, AfterLight = { 1.1, 9.0, 1.7 },
	Scorch = 7.5, ScorchIn = 0.05, ScorchHold = 0.60, ScorchFade = 1.20,
	CrackReach = 0.55, CrackGlow = { 0.16, 0.75 }, CrackBright = { { 2.2, 1.4 }, { 1.5, 1.0 } },
	CrackCool = { 0.40, 1.00 }, CrackFade = { 0.45, 1.75 },
	PoolGlow = { 3.2, 1.60 }, SmolderRate = 16, SmolderFor = 1.2,
	-- the Bloom kick at strike 1 (x0.5 at contact): Intensity +, Size + (Roblox units: Blender's 0.50 -> 0.65 ~ 24 -> 31),
	-- tau, hold, Threshold - (none in daylight). Lighting.ExposureCompensation's +0.15 is NOT ported (no Kit API).
	Bloom = { 0.9, 7, 0.06, 0.035, 0.15 },
	BloomReach = { 20, 90 },                     -- PORT: full within 20 studs of the camera, none past 90 (flag 8)
	Punch = { 0.10, 40 },                        -- PORT: Viewmodel.Punch at contact (the showcase's Shake 0.10), reach
	Reroll = 1 / 30,
	End = 2.2,                                   -- PORT: after contact everything (the last smoulder included) is gone
	-- BUDGET caps (header)
	MaxCrackle = 8, MaxTendrils = 6, MaxBoltSlots = 9, MaxBurned = 5,
	Backstop = 20,                               -- PORT: Debris removes an orb's folder after this, whatever happened
}
local T = VoltOrbFX.Tuning

----------------------------------------------------------------------------------------------------
-- plumbing: the lazy Kit and data, warnings
----------------------------------------------------------------------------------------------------
local TAU = 2 * math.pi
local SPIN_AXIS = Vector3.new(0.85, 0.40, 0.30).Unit
local WHITE_HOT = Color3.fromRGB(255, 251, 199)       -- Light 60 % of the way to white: a bolt's / an arc's core
local VIOLET_HOT = Color3.new(0.50, 0.36, 1.0)        -- the core's crack light: blue-violet, red under blue (never pink)
local BODY = Color3.fromRGB(30, 13, 54)               -- the plates: Neon at Dark taken down to violet-black
local STEP_NAME = "VoltOrbFX"

local Kit, Data = nil, nil
local COL, TEX = nil, nil
local kitRetry, dataRetry = 0, 0
local warned = {}

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[VoltOrbFX] " .. msg)
end

local function kit()
	if Kit then return Kit end
	if os.clock() < kitRetry then return nil end
	kitRetry = os.clock() + 5
	local ice = ReplicatedStorage:FindFirstChild("IceMagic") or ReplicatedStorage:WaitForChild("IceMagic", 3)
	local mod = ice and (ice:FindFirstChild("VoltaicKit") or ice:WaitForChild("VoltaicKit", 3))
	if not mod then
		warnOnce("kit", "ReplicatedStorage.IceMagic.VoltaicKit is missing: Volt Orb draws nothing")
		return nil
	end
	local ok, k = pcall(require, mod)
	if not ok or type(k) ~= "table" or type(k.COL) ~= "table" then
		warnOnce("kitreq", "VoltaicKit failed to load: " .. tostring(k))
		return nil
	end
	Kit, COL = k, k.COL
	return Kit
end

local function kitData()
	if Data then return Data end
	if os.clock() < dataRetry then return nil end
	dataRetry = os.clock() + 10
	local sp = ReplicatedStorage:FindFirstChild("Spellshot") or ReplicatedStorage:WaitForChild("Spellshot", 3)
	local mod = sp and (sp:FindFirstChild("VoltOrbKitData") or sp:WaitForChild("VoltOrbKitData", 3))
	if not mod then
		warnOnce("data", "ReplicatedStorage.Spellshot.VoltOrbKitData is missing: the orb's body and crackle are skipped")
		return nil
	end
	local ok, d = pcall(require, mod)
	if not ok or type(d) ~= "table" or type(d.Facets) ~= "table" or type(d.Seams) ~= "table" then
		warnOnce("datareq", "VoltOrbKitData failed to load: " .. tostring(d))
		return nil
	end
	Data = d
	return Data
end

--- The textures: the Kit's ids, VoltOrbKitData's as the fallback.
local function textures()
	if TEX then return TEX end
	local kt = (Kit and type(Kit.Tex) == "table") and Kit.Tex or {}
	local dt = (Data and type(Data.Textures) == "table") and Data.Textures or {}
	local implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds"
	TEX = {
		Core = kt.Core or dt.Core, Glow = kt.Glow or dt.Glow, SeamHot = kt.SeamHot or dt.SeamHot,
		Facet = kt.Facet or dt.Facet, Depth = kt.Depth or dt.Depth, Scorch = kt.Scorch or dt.Scorch,
		Implosion = kt.Implosion or implosion,
	}
	return TEX
end

local function vfx()
	if not Kit then return nil end
	local ok, V = pcall(Kit.libs)
	return ok and V or nil
end

----------------------------------------------------------------------------------------------------
-- small maths
----------------------------------------------------------------------------------------------------
local function lerp(a, b, u) return a + (b - a) * u end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function span(t, a, b)
	if b == a then return t >= b and 1 or 0 end
	return clamp01((t - a) / (b - a))
end
local function ease(u) u = clamp01(u) return u * u * (3 - 2 * u) end
local function easeOut(u) u = clamp01(u) return 1 - (1 - u) ^ 3 end
local function easeIn(u) u = clamp01(u) return u * u end
local function pick(rng, p) return rng:NextNumber(p[1], p[2]) end

local function anyPerp(d)
	local p = d:Cross(Vector3.yAxis)
	if p.Magnitude < 1e-4 then p = d:Cross(Vector3.xAxis) end
	return p.Unit
end

local function randUnit(rng)
	for _ = 1, 12 do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local m = v.Magnitude
		if m > 1e-3 and m <= 1 then return v / m end
	end
	return Vector3.yAxis
end

--- A random unit vector square to `d`; its part along `flatN` squashed to `flat` of itself (arcs hugging a floor).
local function perpOf(d, rng, flatN, flat)
	local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local p = r - d * r:Dot(d)
	if flatN then p -= flatN * (p:Dot(flatN) * (1 - flat)) end
	if p.Magnitude < 1e-4 then return anyPerp(d) end
	return p.Unit
end

--- Lightning's shape (volt_orb_bl.py jag): midpoint displacement, `depth` halvings, each midpoint kicked sideways by
--- 0.35..1 x `amp`, the kick `kick` (0.55) of itself per level. `surf` = { P, N, Y }: a midpoint that falls under Y
--- studs above the plane (P, N) is reflected back up (the kit's floorY rule). `flatN` / `flat`: see perpOf.
local function jag(a, b, depth, amp, rng, surf, flatN, flat, kick)
	kick = kick or 0.55
	local out = { a }
	local function sub(p, q, dep, am)
		if dep == 0 then
			out[#out + 1] = q
			return
		end
		local d = q - p
		local len = d.Magnitude
		local m = (p + q) / 2
		if len > 1e-4 then m += perpOf(d / len, rng, flatN, flat) * rng:NextNumber(0.35, 1) * am end
		if surf then
			local h = (m - surf.P):Dot(surf.N)
			if h < surf.Y then m += surf.N * ((surf.Y - h) * 1.3) end
		end
		sub(p, m, dep - 1, am * kick)
		sub(m, q, dep - 1, am * kick)
	end
	sub(a, b, depth, amp)
	return out
end

--- The first `u` of a polyline -- a chain lit attachment by attachment, the last one part-way. nil under 2 points.
local function reveal(pts, u)
	if not pts then return nil end
	if u >= 1 then return pts end
	local segs = #pts - 1
	local x = clamp01(u) * segs
	local k = math.floor(x)
	local out = table.move(pts, 1, k + 1, 1, {})
	if k < segs and x > k then out[#out + 1] = pts[k + 1]:Lerp(pts[k + 2], x - k) end
	return #out >= 2 and out or nil
end

--- Seen from `eye`, does every point land at least r studs (at the orb's depth) off `center`? The wake is per client: a
--- tendril behind the orb in 3D still sits ON it for a camera looking down the throw -- the cartoon fuse again.
local function screenClear(pts, center, eye, r)
	if not eye then return true end
	local axis = center - eye
	local dist = axis.Magnitude
	if dist < 1e-3 then return true end
	axis /= dist
	for _, q in ipairs(pts) do
		local v = q - eye
		local dz = v:Dot(axis)
		if dz > 0.1 and ((eye + v * (dist / dz)) - center).Magnitude < r then return false end
	end
	return true
end

local function scaleC(c, k)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

-- ColorSequence / NumberSequence caches: the per-frame looks write only quantized values, so these stay small.
local csCache, csCount = {}, 0
local function colorKey(c)
	return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end
local function CS1(c)
	local key = colorKey(c)
	local s = csCache[key]
	if not s then
		if csCount > 2048 then
			table.clear(csCache)
			csCount = 0
		end
		s = ColorSequence.new(c)
		csCache[key] = s
		csCount += 1
	end
	return s, key
end

local nsCache = {}
local function alphaKey(a) return math.floor(clamp01(a) * 200 + 0.5) end
--- Transparency for opacity `a` (1 = full), quantized to 1/200.
local function NSa(a)
	local key = alphaKey(a)
	local s = nsCache[key]
	if not s then
		s = NumberSequence.new(1 - key / 200)
		nsCache[key] = s
	end
	return s, key
end

local seamNsCache = {}
--- A crack glow's Transparency: `a` x GLOW_ALPHA along it, half that at its two ends (the junctions glow, not pile up).
local function NSseam(a)
	local key = alphaKey(a)
	local s = seamNsCache[key]
	if not s then
		local full, half = 1 - 0.85 * key / 200, 1 - 0.85 * 0.5 * key / 200
		s = NumberSequence.new({
			NumberSequenceKeypoint.new(0, half), NumberSequenceKeypoint.new(0.18, full),
			NumberSequenceKeypoint.new(0.82, full), NumberSequenceKeypoint.new(1, half),
		})
		seamNsCache[key] = s
	end
	return s
end

--- A NumberSequence from { {t, v, envelope?}, ... } (t from 0 to 1).
local function NS(list, k)
	k = k or 1
	local kps = table.create(#list)
	for i, p in ipairs(list) do kps[i] = NumberSequenceKeypoint.new(p[1], p[2] * k, (p[3] or 0) * k) end
	return NumberSequence.new(kps)
end

--- Yellow cooling into violet WITHOUT passing through pink: dim, dark for a beat, then violet (volt_orb_bl cool()).
local function cool(u)
	u = clamp01(u)
	if u < 0.45 then return COL.Base, lerp(1.0, 0.3, u / 0.45) end
	if u < 0.52 then return COL.Dark, 0.0 end
	return COL.Dark, lerp(0.0, 0.8, math.min(1, (u - 0.52) / 0.13))
end

--- An attachment frame for a FaceCamera=false Beam: X along the curve (CurveSize's axis), the ribbon lying across
--- `normal` (T.RibbonNormal says which attachment axis the engine takes as that normal -- see the header).
local function ribbonFrame(pos, along, normal)
	local x = along.Magnitude > 1e-6 and along.Unit or anyPerp(normal)
	local n = normal - x * normal:Dot(x)
	n = n.Magnitude > 1e-6 and n.Unit or anyPerp(x)
	if T.RibbonNormal == "Z" then return CFrame.fromMatrix(pos, x, n:Cross(x)) end
	return CFrame.fromMatrix(pos, x, n)
end

local function scaledCF(cf, k) return CFrame.new(cf.Position * k) * cf.Rotation end

----------------------------------------------------------------------------------------------------
-- THE ORB'S LAYOUT (VoltOrbKitData + the import) AND THE TEMPLATE, both built once
----------------------------------------------------------------------------------------------------
-- GEO: R, V (the 12 crack junctions, orb-local), E (the 30 cracks as vertex pairs), seams[j] (unit-ball frames),
-- facets[i] (a plate: its pivot P, normal N, face Beam frames, random breathe / twist / phase, landing corners).
local GEO = nil
local TEMPLATE = nil
local templateRetry = 0

local function pivotOf(p)
	local bp = p:GetAttribute("BasePivot")
	bp = typeof(bp) == "Vector3" and bp or p.PivotOffset.Position
	return p.CFrame:PointToWorldSpace(bp), bp
end

local function sizeOf(p)
	local s = p:GetAttribute("BaseSize")
	return typeof(s) == "Vector3" and s or p.Size
end

local function inertNeon(p, color)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0
	p.Reflectance = 0
end

local function newFaceBeam(a0, a1, texture, emission, zoff, width, curve, parent, name)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = false
	b.Segments = 32
	b.Texture = texture or ""
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.LightEmission, b.LightInfluence = emission, 0
	b.ZOffset = zoff
	b.Width0, b.Width1 = width, 0
	b.CurveSize0, b.CurveSize1 = curve, curve
	b.Color = ColorSequence.new(COL.Base)
	b.Transparency = NumberSequence.new(0)
	b.Brightness = 1
	b.Parent = parent
	return b
end

local function newCrackBeam(a0, a1, color, width, curve, zoff, segments, enabled, parent, name)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = segments
	b.Texture = TEX.SeamHot or ""
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = T.SeamHot[1]
	b.TextureSpeed = 0
	b.LightEmission, b.LightInfluence = 1, 0
	b.ZOffset = zoff
	b.Width0, b.Width1 = width, width
	b.CurveSize0, b.CurveSize1 = curve, curve
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new(0)
	b.Brightness = 1
	b.Enabled = enabled
	b.Parent = parent
	return b
end

local function newSprite(parent, name, color, brightness)
	local g = Instance.new("BillboardGui")
	g.Name = name
	g.LightInfluence = 0
	g.Brightness = brightness
	g.AlwaysOnTop = false
	g.ClipsDescendants = false
	g.Size = UDim2.new(1, 0, 1, 0)
	g.Enabled = false
	local img = Instance.new("ImageLabel")
	img.Name = "Glow"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.Implosion
	img.ImageColor3 = color
	img.Parent = g
	g.Parent = parent
	if parent:IsA("Attachment") then g.Adornee = parent end
	return g
end

--- GEO from VoltOrbKitData (the crack network). Needs only the data; the plates join it in buildTemplate.
local function buildGeo()
	if GEO then return GEO end
	local D = kitData()
	if not D then return nil end
	local V, E = {}, {}
	local function vid(p)
		for i, q in ipairs(V) do
			if (q - p).Magnitude < 1e-3 then return i end
		end
		V[#V + 1] = p
		return #V
	end
	for _, S in ipairs(D.Seams) do
		if type(S) == "table" and typeof(S[1]) == "Vector3" and typeof(S[2]) == "Vector3" then
			local a, b = vid(S[1]), vid(S[2])
			if a ~= b then E[#E + 1] = { a, b } end
		end
	end
	if #V < 4 or #E < 3 then
		warnOnce("geo", "VoltOrbKitData.Seams is too small to draw an orb")
		return nil
	end
	local R = 0
	for _, v in ipairs(V) do R += v.Magnitude end
	R /= #V
	-- each crack as a unit-ball arc: its two ends' frames (X on the great circle's tangent, running a -> b) and the
	-- cubic Bezier handle that bows a Beam onto the circle; scaled by whatever radius it is drawn at
	local seams = {}
	for j, e in ipairs(E) do
		local A, B = V[e[1]], V[e[2]]
		local n0, n1 = A.Unit, B.Unit
		local c = math.clamp(n0:Dot(n1), -1, 1)
		local th = math.acos(c)
		local t0 = n1 - n0 * c
		t0 = t0.Magnitude > 1e-6 and t0.Unit or anyPerp(n0)
		local t1 = n1 * c - n0
		t1 = t1.Magnitude > 1e-6 and t1.Unit or anyPerp(n1)
		seams[j] = { U0 = CFrame.fromMatrix(n0, t0, n0), U1 = CFrame.fromMatrix(n1, t1, n1), H = 4 / 3 * math.tan(th / 4),
			Sign = (j % 2 == 0) and 1 or -1 }
	end
	GEO = { R = R, V = V, E = E, seams = seams, facets = {} }
	return GEO
end

--- The template: the core, the kernel, the plates (each with its face light + depth Beams), the cracks and core cracks
--- on the core, the halo, the corona and the crackle's touch sprites. Cloned per cast.
local function buildTemplate()
	if TEMPLATE then return TEMPLATE end
	if os.clock() < templateRetry then return nil end
	templateRetry = os.clock() + 10
	local K = kit()
	local G = buildGeo()
	if not (K and G) then return nil end
	textures()
	local D = Data
	local core = K.orbMesh("VO_Core")
	if not core then
		warnOnce("core", "VO_Core is not in ReplicatedStorage.VoltaicMeshes.VoltaicVoltOrb: the orb's body is skipped")
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "VoltOrb"
	local coreWorld, coreBP = pivotOf(core)
	inertNeon(core, scaleC(COL.Dark, T.CoreDark[1]))
	core.Name = "VO_Core"
	core.CFrame = CFrame.new(-coreBP)
	core.Parent = model
	G.core = { Base = coreBP, Size = sizeOf(core) }

	local kernel = K.orbMesh("VO_Kernel")
	if kernel then
		local _, kbp = pivotOf(kernel)
		inertNeon(kernel, COL.Light)
		kernel.Name = "VO_Kernel"
		kernel.Transparency = 1
		kernel.CFrame = CFrame.new(-kbp)
		kernel.Parent = model
		G.kernel = { Base = kbp, Size = sizeOf(kernel) }
	end

	-- the plates and their face Beam triangles
	local rng = Random.new(T.LayoutSeed)
	local Rl = G.R + T.FaceLift
	for i, F in ipairs(D.Facets) do
		local part = (type(F) == "table" and type(F.Plate) == "string") and K.orbMesh(F.Plate) or nil
		if part and typeof(F.A0) == "Vector3" and typeof(F.A1) == "Vector3" and typeof(F.N) == "Vector3"
			and type(F.W0) == "number" then
			local world, bp = pivotOf(part)
			local P = world - coreWorld
			local N = F.N.Unit
			inertNeon(part, BODY)
			part.Name = "Plate" .. i
			part.CFrame = CFrame.new(P - bp)
			-- the flat triangle's base midpoint and apex, pushed out onto the lifted ball
			local a0, a1 = P + F.A0, P + F.A1
			local n0, n1 = a0.Unit, a1.Unit
			local med = a1 - a0
			med = med.Magnitude > 1e-6 and med.Unit or anyPerp(N)
			local u = N:Cross(med)
			u = u.Magnitude > 1e-6 and u.Unit or anyPerp(med)
			local bl, br = a0 - u * (F.W0 / 2), a0 + u * (F.W0 / 2)
			local full = (bl.Unit * Rl - br.Unit * Rl).Magnitude
			local W = lerp(F.W0, full, T.FaceSpread)
			local c = math.clamp(n0:Dot(n1), -1, 1)
			local H = 4 / 3 * math.tan(math.acos(c) / 4) * Rl
			local t0 = n1 - n0 * c
			t0 = t0.Magnitude > 1e-6 and t0.Unit or med
			local t1 = n1 * c - n0
			t1 = t1.Magnitude > 1e-6 and t1.Unit or med
			-- plate-local: orb-local q sits at q - P + BasePivot in the part (its rotation is the orb's)
			local cf0 = ribbonFrame(n0 * Rl - P + bp, t0, n0)
			local cf1 = ribbonFrame(n1 * Rl - P + bp, t1, n1)
			local att0, att1 = Instance.new("Attachment"), Instance.new("Attachment")
			att0.Name, att1.Name = "F0", "F1"
			att0.CFrame, att1.CFrame = cf0, cf1
			att0.Parent, att1.Parent = part, part
			newFaceBeam(att0, att1, TEX.Depth, 0.6, 0, W, H, part, "Depth")
			newFaceBeam(att0, att1, TEX.Facet, 0.85, 0.01, W, H, part, "Facet")
			part.Parent = model
			local size = sizeOf(part)
			local corners = {}
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						corners[#corners + 1] = Vector3.new(size.X * sx, size.Y * sy, size.Z * sz) - bp
					end
				end
			end
			G.facets[#G.facets + 1] = {
				Name = part.Name, P = P, N = N, Dist = P.Magnitude, Base = bp, Size = size, F0 = cf0, F1 = cf1, W = W, H = H,
				Breathe = rng:NextNumber(0.7, 1.3), Twist = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(1.0, 2.2),
				Phase = rng:NextNumber(0, TAU), Corners = corners,
			}
		else
			if part then part:Destroy() end
			warnOnce("plate" .. i, "Volt Orb plate " .. tostring(type(F) == "table" and F.Plate or i) .. " is missing: skipped")
		end
	end

	-- the cracks (lit, riding the plates' breath) and the core's violet cracks (the windup and the release)
	for j, S in ipairs(G.seams) do
		local r = G.R
		local sa, sb = Instance.new("Attachment"), Instance.new("Attachment")
		sa.Name, sb.Name = "S" .. j .. "a", "S" .. j .. "b"
		sa.CFrame, sb.CFrame = scaledCF(S.U0, r), scaledCF(S.U1, r)
		sa.Parent, sb.Parent = core, core
		newCrackBeam(sa, sb, COL.Base, T.SeamGlow[1], S.H * r, 0, 8, true, core, "S" .. j .. "g")
		newCrackBeam(sa, sb, COL.Light, T.SeamCore[1], S.H * r, 0.02, 8, true, core, "S" .. j .. "c")
		local rk = G.R * T.CoreScale * 1.01
		local ka, kb = Instance.new("Attachment"), Instance.new("Attachment")
		ka.Name, kb.Name = "K" .. j .. "a", "K" .. j .. "b"
		ka.CFrame, kb.CFrame = scaledCF(S.U0, rk), scaledCF(S.U1, rk)
		ka.Parent, kb.Parent = core, core
		newCrackBeam(ka, kb, COL.Dark, 0.5 * T.CoreScale, S.H * rk, 0, 6, false, core, "K" .. j .. "g")
		newCrackBeam(ka, kb, VIOLET_HOT, 0.07 * T.CoreScale, S.H * rk, 0.02, 6, false, core, "K" .. j .. "c")
	end

	-- the halo (alpha-blended violet aura), the corona (Base glow bleeding past the silhouette), the touch sprites
	newSprite(core, "Halo", COL.Dark, T.Halo[3])
	newSprite(core, "Corona", COL.Base, T.Corona[2])
	for k = 1, T.MaxCrackle * 2 do
		local a = Instance.new("Attachment")
		a.Name = "T" .. k
		a.Parent = core
		newSprite(a, "Touch", COL.Light, T.Touch[2])
	end
	TEMPLATE = { Model = model }
	return TEMPLATE
end

--- One orb's copy of the template, with every piece it draws looked up once.
local function cloneOrb(folder)
	local tpl = buildTemplate()
	if not tpl then return nil end
	local m = tpl.Model:Clone()
	local core = m:FindFirstChild("VO_Core")
	if not core then
		m:Destroy()
		return nil
	end
	local P = { Model = m, Core = core, Kernel = m:FindFirstChild("VO_Kernel"), Plates = {}, Seams = {}, Cracks = {},
		Touch = {}, CoreK = 1, KernelK = 1, SeamR = GEO.R, CrackR = GEO.R * T.CoreScale * 1.01,
		SeamOff = Vector3.zero, CrackOff = Vector3.zero, CoreL = {}, HaloL = {}, CoronaL = {} }
	for i, G in ipairs(GEO.facets) do
		local part = m:FindFirstChild(G.Name)
		if part then
			P.Plates[i] = { Part = part, A0 = part:FindFirstChild("F0"), A1 = part:FindFirstChild("F1"),
				Facet = part:FindFirstChild("Facet"), Depth = part:FindFirstChild("Depth"), K = 1, Vis = true, L = {} }
		end
	end
	for j in ipairs(GEO.seams) do
		P.Seams[j] = { A0 = core:FindFirstChild("S" .. j .. "a"), A1 = core:FindFirstChild("S" .. j .. "b"),
			Core = core:FindFirstChild("S" .. j .. "c"), Glow = core:FindFirstChild("S" .. j .. "g") }
		P.Cracks[j] = { A0 = core:FindFirstChild("K" .. j .. "a"), A1 = core:FindFirstChild("K" .. j .. "b"),
			Core = core:FindFirstChild("K" .. j .. "c"), Glow = core:FindFirstChild("K" .. j .. "g") }
	end
	P.Halo = core:FindFirstChild("Halo")
	P.HaloImg = P.Halo and P.Halo:FindFirstChild("Glow")
	P.Corona = core:FindFirstChild("Corona")
	P.CoronaImg = P.Corona and P.Corona:FindFirstChild("Glow")
	for k = 1, T.MaxCrackle * 2 do
		local a = core:FindFirstChild("T" .. k)
		local g = a and a:FindFirstChild("Touch")
		if g then
			g.Adornee = a
			P.Touch[k] = { Att = a, Gui = g, Img = g:FindFirstChild("Glow"), On = false, L = {} }
		end
	end
	P.SeamL, P.CrackL = {}, {}
	m.Parent = folder
	return P
end

----------------------------------------------------------------------------------------------------
-- particles (VFXLibrary's Voltaic soft presets only) and sprites
----------------------------------------------------------------------------------------------------
--- One-shot `count` of VFXLibrary.GroundSurgeBurst's `kind`, re-tuned by `extra`, run at the orb's time scale.
local function burstFx(O, parent, kind, count, extra)
	local V = vfx()
	if not (V and V.GroundSurgeBurst and parent) then return nil end
	local ok, pe = pcall(V.GroundSurgeBurst, parent, kind, count, O.Thin, extra)
	if not ok then
		warnOnce("burst:" .. kind, "VFXLibrary.GroundSurgeBurst(" .. kind .. ") failed: " .. tostring(pe))
		return nil
	end
	if pe and O.Ts ~= 1 then pe.TimeScale = O.Ts end
	return pe
end

local function emitterFx(O, parent, kind, extra)
	local V = vfx()
	if not (V and V.GroundSurgeEmitter and parent) then return nil end
	local ok, pe = pcall(V.GroundSurgeEmitter, parent, kind, O.Thin, extra)
	if not ok then
		warnOnce("emit:" .. kind, "VFXLibrary.GroundSurgeEmitter(" .. kind .. ") failed: " .. tostring(pe))
		return nil
	end
	if pe and O.Ts ~= 1 then pe.TimeScale = O.Ts end
	return pe
end

--- A locked glow sprite (the Flash preset: the implosion disc) -- the implode, the lock, the contact flash, the burst.
local function spriteFx(O, parent, size0, size1, tr, life, color, emission, bright)
	return burstFx(O, parent, "Flash", 1, {
		Size = NS({ { 0, size0 }, { 1, size1 } }), Transparency = NS(tr), Lifetime = NumberRange.new(life),
		Color = ColorSequence.new(color), LightEmission = emission, Brightness = bright, LockedToPart = true,
		Speed = NumberRange.new(0), Rate = 0,
	})
end

local HARD_COOL = nil
local function hardCool()
	if not HARD_COOL then
		HARD_COOL = ColorSequence.new({
			ColorSequenceKeypoint.new(0, COL.Base), ColorSequenceKeypoint.new(0.55, COL.Base),
			ColorSequenceKeypoint.new(0.56, COL.Dark), ColorSequenceKeypoint.new(1, COL.Dark),
		})
	end
	return HARD_COOL
end

local function sparkExtra(spread)
	return {
		Color = ColorSequence.new(COL.Light, COL.Base), Brightness = 4,
		Size = NS({ { 0, 0.30 }, { 0.7, 0.26 }, { 1, 0 } }), Transparency = NS({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(spread, spread),
		Drag = 1.2, Acceleration = Vector3.new(0, -45, 0), EmissionDirection = Enum.NormalId.Top, Rate = 0,
	}
end

--- An attachment on `host` at `pos` whose +Y (a Top-emitting emitter's direction) points along `up`.
local function upAttach(host, pos, up)
	local a = Instance.new("Attachment")
	a.Parent = host
	local u = up.Magnitude > 1e-4 and up.Unit or Vector3.yAxis
	a.WorldCFrame = CFrame.fromMatrix(pos, anyPerp(u), u)
	return a
end

local function newHost(O, name, cf)
	local ok, h = pcall(Kit.host, name, cf)
	if not ok or not h then
		h = Instance.new("Part")
		h.Name = name
		h.Size = Vector3.new(0.2, 0.2, 0.2)
		h.Transparency = 1
		h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.CastShadow = true, false, false, false, false
		h.CFrame = cf
	end
	h.Parent = O.Folder
	return h
end

local function newLight(parent, range, color)
	if not (Kit and Kit.light) then return nil end
	local ok, l = pcall(Kit.light, parent, 0, range, color)
	return ok and l or nil
end

----------------------------------------------------------------------------------------------------
-- the Beam chains (Kit.BeamChain: core + glow textured Beams) and the port's own flat chain for the burned cracks
----------------------------------------------------------------------------------------------------
local function newChain(O, segs)
	if not (Kit and Kit.BeamChain and Kit.BeamChain.new) then return nil end
	local ok, ch = pcall(Kit.BeamChain.new, O.Folder, segs)
	if not ok then
		warnOnce("chain", "Kit.BeamChain.new failed: " .. tostring(ch))
		return nil
	end
	return ch
end

--- Draws `pts` on chain `ch` with the showcase's look: widths tapering by `taper` along it, the glow tapering off over
--- the last ~15 % at each end to `ends`, and (`root`) held off the release round a centre until it ends.
local function chainDraw(ch, buf, pts, cw, gw, taper, cb, gb, alpha, cc, gc, rootC, rootR, ends)
	if not ch then return end
	if not pts or #pts < 2 or alpha <= 0.003 then
		ch:Hide()
		return
	end
	ends = ends or 0.35
	local n = #pts
	local seg = n - 1
	local cws, gws = buf.c, buf.g
	table.clear(cws)
	table.clear(gws)
	for i = 1, n do
		local k = i - 1
		local wk = 1 - taper * k / math.max(1, seg)
		local e = math.min(1, ends + (1 - ends) * math.min(k, seg - k) / math.max(1, 0.15 * seg))
		cws[i] = cw * wk
		local g = gw * wk * e
		if rootC then g *= clamp01((pts[i] - rootC).Magnitude / rootR) end
		gws[i] = g
	end
	ch:Look(cc, gc, cb, gb, alpha)
	ch:Set(pts, cws, gws)
end

local function newBuf() return { c = {}, g = {} } end

-- A flat Beam chain lying ON a surface (FaceCamera false, oriented by ribbonFrame): the burned cracks and the pool.
local function flatBeam(a0, a1, texture, emission, zoff, parent)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = false
	b.Segments = 4
	b.Texture = texture or ""
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.LightEmission, b.LightInfluence = emission, 0
	b.ZOffset = zoff
	b.Enabled = false
	b.Parent = parent
	return b
end

local function newFlat(parent, segs, flatK)
	local F = { Atts = {}, Core = {}, Glow = {}, N = segs, Shown = 0, Look = {}, FlatK = flatK }
	for i = 1, segs + 1 do
		local a = Instance.new("Attachment")
		a.Parent = parent
		F.Atts[i] = a
	end
	for i = 1, segs do
		F.Glow[i] = flatBeam(F.Atts[i], F.Atts[i + 1], TEX.Glow, 0.55 * flatK, 0, parent)
		F.Core[i] = flatBeam(F.Atts[i], F.Atts[i + 1], TEX.Core, 1 * flatK, 0.02, parent)
	end
	return F
end

local function flatSet(F, pts, normal, cw, gw, taper)
	local n = pts and math.min(#pts, F.N + 1) or 0
	if n < 2 then
		for i = 1, F.Shown do F.Core[i].Enabled, F.Glow[i].Enabled = false, false end
		F.Shown = 0
		return
	end
	local seg = n - 1
	for i = 1, n do
		local p = pts[i]
		local along = (i < n) and (pts[i + 1] - p) or (p - pts[i - 1])
		if i > 1 and i < n then along = pts[i + 1] - pts[i - 1] end
		F.Atts[i].WorldCFrame = ribbonFrame(p, along, normal)
	end
	for i = 1, seg do
		local k0, k1 = (i - 1) / math.max(1, seg), i / math.max(1, seg)
		local e0 = math.min(1, 0.35 + 0.65 * math.min(i - 1, seg - i + 1) / math.max(1, 0.15 * seg))
		local e1 = math.min(1, 0.35 + 0.65 * math.min(i, seg - i) / math.max(1, 0.15 * seg))
		local c, g = F.Core[i], F.Glow[i]
		c.Width0, c.Width1 = cw * (1 - taper * k0), cw * (1 - taper * k1)
		g.Width0, g.Width1 = gw * (1 - taper * k0) * e0, gw * (1 - taper * k1) * e1
		c.Enabled, g.Enabled = F.On ~= false, F.On ~= false
	end
	for i = seg + 1, F.Shown do F.Core[i].Enabled, F.Glow[i].Enabled = false, false end
	F.Shown = seg
end

local function flatLook(F, color, cb, gb, alpha)
	local L = F.Look
	local key = colorKey(color)
	local on = alpha > 0.005 and (cb > 0.005 or gb > 0.005)
	if on ~= F.On then
		F.On = on
		for i = 1, F.Shown do F.Core[i].Enabled, F.Glow[i].Enabled = on, on end
	end
	if not on then return end
	local ak = alphaKey(alpha)
	if L.key == key and math.abs((L.cb or -1) - cb) < 0.02 and math.abs((L.gb or -1) - gb) < 0.02 and L.ak == ak then return end
	L.key, L.cb, L.gb, L.ak = key, cb, gb, ak
	local cs = CS1(color)
	local ct = NSa(alpha)
	local gt = NSa(alpha * 0.85)
	for i = 1, F.N do
		local c, g = F.Core[i], F.Glow[i]
		c.Color, g.Color = cs, cs
		c.Brightness, g.Brightness = cb * F.FlatK, gb * F.FlatK
		c.Transparency, g.Transparency = ct, gt
	end
end

----------------------------------------------------------------------------------------------------
-- the live orbs
----------------------------------------------------------------------------------------------------
local live = {}          -- [orb] = true
local pending = {}       -- [character] = orb: a windup not yet thrown
local flying = {}        -- [character] = orb: thrown, not yet burst
local bound = false
local stepAll            -- (forward: the render step, below)
local fizzleOrb          -- (forward: the pop, below)

local function unbind()
	if not bound then return end
	bound = false
	pcall(RunService.UnbindFromRenderStep, RunService, STEP_NAME)
end

local function ensureBound()
	if bound then return end
	bound = true
	-- after the camera and the viewmodel (Camera + 2) have moved: the orb in a first-person fist is placed against the
	-- view about to be drawn
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 3, stepAll)
end

local function destroyOrb(O)
	if O.dead then return end
	O.dead = true
	live[O] = nil
	if O.Character then
		if pending[O.Character] == O then pending[O.Character] = nil end
		if flying[O.Character] == O then flying[O.Character] = nil end
	end
	for _, list in ipairs({ O.Crk, O.Pool, O.Bolts }) do
		for _, sl in ipairs(list) do
			if sl.Main then pcall(sl.Main.Destroy, sl.Main) end
			if sl.Fork then pcall(sl.Fork.Destroy, sl.Fork) end
		end
	end
	if O.Folder then O.Folder:Destroy() end
end

--- A new orb (its folder, a copy of the template, its lights and hosts). opt: Own, T0 (the windup's start in server
--- time), Seed, Late (made at a burst: formed, no windup), At (where a late one is).
local function newOrb(character, opt)
	local K = Kit
	local folder = Instance.new("Folder")
	folder.Name = "VoltOrb"
	folder.Parent = K.fxFolder()
	Debris:AddItem(folder, T.Backstop)
	local seed = tonumber(opt.Seed) or math.random(1, 1000000000)
	local okThin, thin = pcall(K.thin, character)
	local okCalm, calm = pcall(K.reduceFlashing)
	local O = {
		Character = character, Own = opt.Own == true, Thin = okThin and thin == true, Calm = okCalm and calm == true,
		Folder = folder, T0w = opt.T0, Seed = seed, Rng = Random.new(seed), Late = opt.Late == true, Ts = 1,
		angle = Random.new(seed + 3):NextNumber(0, TAU), phase = -math.pi / 2, p = 0, glow = 1, hotRate = 0,
		rot = CFrame.identity, view = nil, lt = 0, LastOs = os.clock(), fired = {},
		slots = {}, flare = {}, touches = {}, tendrils = {}, Crk = {}, Pool = {}, Bolts = {},
		accTrail = 0, accShed = 0, FloorH = 6, floorAt = -1, s = 1, DrawC = opt.At,
		Bulk = { parts = {}, cfs = {} },
	}
	O.maxCrackle = O.Thin and math.ceil(T.MaxCrackle / 2) or T.MaxCrackle
	O.maxTendrils = O.Thin and math.ceil(T.MaxTendrils / 2) or T.MaxTendrils
	O.maxBolts = O.Thin and 6 or T.MaxBoltSlots
	O.Handle = {
		Character = character,
		Stop = function() fizzleOrb(O, nil) end,
		Destroy = function() destroyOrb(O) end,
	}
	if GEO or buildGeo() then
		O.P = cloneOrb(folder)
		if O.P and O.Thin then
			-- thin: the violet core cracks draw their core layer only
			for _, S in ipairs(O.P.Cracks) do
				if S.Glow then
					S.Glow:Destroy()
					S.Glow = nil
				end
			end
		end
		for i = 1, #GEO.facets do O.flare[i] = 0 end
		-- the plates land one after another across FacetsIn, in a shuffled order
		local n = #GEO.facets
		local order = {}
		for i = 1, n do order[i] = i end
		local r = Random.new(seed + 41)
		for i = n, 2, -1 do
			local j = r:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		O.arrive = {}
		for k, i in ipairs(order) do
			O.arrive[i] = T.FacetsIn[1] + (T.FacetsIn[2] - T.FacetsIn[1]) * (k - 1) / math.max(1, n - 1)
		end
	end
	-- the orb's two lights ride a host at its TRUE centre (in first person the drawn orb is a stand-in)
	local at = opt.At or Vector3.zero
	O.LightHost = newHost(O, "VoltOrbLight", CFrame.new(at))
	O.OrbLight = newLight(O.LightHost, T.OrbLight[2], COL.Base)
	O.CoreLight = newLight(O.LightHost, T.CoreLight[2], COL.Dark)
	-- the palm host: the inward motes' sphere, the implode / lock sprites
	O.Hand = newHost(O, "VoltOrbHand", CFrame.new(at))
	O.HandAtt = Instance.new("Attachment")
	O.HandAtt.Parent = O.Hand
	-- the spherecast that finds this client's own contact
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { K.fxFolder() }
	if character then ex[#ex + 1] = character end
	if workspace.CurrentCamera then ex[#ex + 1] = workspace.CurrentCamera end
	params.FilterDescendantsInstances = ex
	O.Params = params
	live[O] = true
	ensureBound()
	return O
end

----------------------------------------------------------------------------------------------------
-- 2 THE ORB: its life (the tumble, the surge, the crackle) and its draw -- volt_orb_bl OrbFX.step / orb_draw
----------------------------------------------------------------------------------------------------
local function crackleArc(O, t, f)
	local r, G = O.Rng, GEO
	local la = lerp(T.CrackleLife[1][1], T.CrackleLife[2][1], f)
	local lb = lerp(T.CrackleLife[1][2], T.CrackleLife[2][2], f)
	local life = r:NextNumber(math.min(la, lb), math.max(la, lb))
	local a, q, b
	for _ = 1, 16 do
		-- charge gathers at the junctions and along the cracks: one end there, the other a short hop away
		if r:NextNumber() < 0.55 then
			a = G.V[r:NextInteger(1, #G.V)]
		else
			local e = G.E[r:NextInteger(1, #G.E)]
			a = G.V[e[1]]:Lerp(G.V[e[2]], r:NextNumber(0.15, 0.85))
		end
		local d = a.Unit
		q = (a + perpOf(d, r) * pick(r, T.CrackleLen)).Unit
		b = q * G.R
		-- per client: new arcs go on the side facing THIS camera (one arc in the hand on the far side is a gap)
		local seen = O.view == nil or math.min(d:Dot(O.view), q:Dot(O.view)) > 0.2
		local L = (b - a).Magnitude
		if seen and L > T.CrackleLen[1] * 0.8 and L < T.CrackleLen[2] * 1.3 then break end
	end
	local n = a.Unit + b.Unit
	n = n.Magnitude > 1e-4 and n.Unit or a.Unit
	return { t0 = t, life = life, a = a, b = b, bow = pick(r, T.CrackleBow), seed = r:NextInteger(1, 1000000),
		fork = r:NextNumber() < T.CrackleFork[1], fl = r:NextNumber(T.CrackleFork[2], T.CrackleFork[3]), side = perpOf(n, r),
		fi = -1 }
end

--- Re-jagged every 60 Hz frame: the two ends stay put on the crystal, the zigzag between runs ACROSS the surface.
local function cracklePts(A, fi)
	local rr = Random.new(A.seed * 31 + fi)
	local a, b = A.a, A.b
	local R = GEO.R
	local pts = jag(a, b, 3, 0.30 * (b - a).Magnitude, rr, nil, nil, nil, 0.6)
	local bow = A.bow * rr:NextNumber(0.7, 1.2)
	local n = #pts
	local out = table.create(n)
	for i, q in ipairs(pts) do
		local lift = bow * math.sin(math.pi * (i - 1) / (n - 1)) + rr:NextNumber(0, 0.02)
		out[i] = q.Unit * (R + 0.015 + lift)
	end
	local fork = nil
	if A.fork then
		local fb = out[rr:NextInteger(4, 6)]
		local fd = A.side * (rr:NextNumber() < 0.5 and -1 or 1) + (b - a).Unit * rr:NextNumber(-0.5, 0.5)
		fd = fd.Magnitude > 1e-4 and fd.Unit or A.side
		local fp = jag(fb, fb + fd * A.fl, 1, 0.35 * A.fl, rr)
		fork = table.create(#fp)
		for i, q in ipairs(fp) do fork[i] = q.Unit * (R + 0.015 + bow * 0.5 * (1 - (i - 1) / (#fp - 1)) + 0.01) end
	end
	return out, fork
end

--- The orb's state for one frame. f: 0..1 of the fuse. wild: 0..1 at the crack. want: the windup's slot override.
local function orbStep(O, t, f, dt, spinRate, wild, want, viewW)
	O.angle += spinRate * dt
	O.rot = CFrame.fromAxisAngle(SPIN_AXIS, O.angle)
	O.view = viewW and O.rot:VectorToObjectSpace(viewW) or nil
	local hz = lerp(T.PulseHz[1], T.PulseHz[2], f ^ 1.5)
	local depth = T.PulseDepth
	if O.Calm then hz, depth = math.min(hz, T.CalmPulseHz), T.CalmPulseDepth end
	O.phase += TAU * hz * dt
	local p = (0.5 + 0.5 * math.sin(O.phase)) ^ 1.5            -- it dwells low and surges
	O.p, O.glow = p, 1 - depth * (1 - p)
	O.hotRate = lerp(T.SeamHot[2], T.SeamHot[3], f ^ 1.2) * (1 + 1.5 * wild)
	if not GEO then return end
	-- the crackle's slots: a finished arc's slot rests, then fires again somewhere else; never none alive
	local n = want or math.floor(lerp(T.Crackle[1], T.Crackle[2], f ^ 1.3) + 0.5)
	n += math.floor(3 * wild + 0.5)
	if O.Thin then n = math.ceil(n / 2) end
	n = math.clamp(n, 0, O.maxCrackle)
	local slots = O.slots
	while #slots < n do slots[#slots + 1] = { rest = t + O.Rng:NextNumber(0, 0.03) } end
	for i = #slots, n + 1, -1 do slots[i] = nil end
	local ra = lerp(T.CrackleRest[1][1], T.CrackleRest[2][1], f)
	local rb = lerp(T.CrackleRest[1][2], T.CrackleRest[2][2], f)
	local any = false
	for _, S in ipairs(slots) do
		local A = S.arc
		if A and t - A.t0 >= A.life then
			S.arc = nil
			S.rest = A.t0 + A.life + O.Rng:NextNumber(math.min(ra, rb), math.max(ra, rb))
		end
		if not S.arc and t >= S.rest then S.arc = crackleArc(O, t, f) end
		if S.arc then any = true end
	end
	if #slots > 0 and not any then slots[1].arc = crackleArc(O, t, f) end
	-- this frame's arcs, and the faces they land on flaring
	local up = (1 + T.CrackleUp * f) * (1 + 0.4 * wild)
	local fi = math.floor(t * 60)
	local flare = O.flare
	for i = 1, #flare do flare[i] = 0 end
	table.clear(O.touches)
	for _, S in ipairs(slots) do
		local A = S.arc
		if A then
			if A.fi ~= fi then
				A.fi = fi
				A.pts, A.forkPts = cracklePts(A, fi)
				A.k = up * Random.new(A.seed + fi):NextNumber(0.8, 1.1)
			end
			local u = (t - A.t0) / A.life
			A.alpha = u < 0.7 and 1 or math.max(0, (1 - u) / 0.3)
			local kk = A.alpha * A.k
			O.touches[#O.touches + 1] = { A.a, kk }
			O.touches[#O.touches + 1] = { A.b, kk }
			for i, Gf in ipairs(GEO.facets) do
				if (A.a - Gf.P).Magnitude < 0.42 or (A.b - Gf.P).Magnitude < 0.42 then
					flare[i] = math.max(flare[i], math.min(1, kk / up))
				end
			end
		end
	end
end

local function queue(O, part, cf)
	local B = O.Bulk
	B.parts[#B.parts + 1] = part
	B.cfs[#B.cfs + 1] = cf
end

local function flush(O)
	local B = O.Bulk
	if #B.parts > 0 then
		local ok = pcall(workspace.BulkMoveTo, workspace, B.parts, B.cfs, Enum.BulkMoveMode.FireCFrameChanged)
		if not ok then
			for i, part in ipairs(B.parts) do part.CFrame = B.cfs[i] end
		end
	end
	table.clear(B.parts)
	table.clear(B.cfs)
end

local function placeCF(cf, base, k)
	return cf * Kit.KIT_TURN * CFrame.new(-base * k)
end

--- A plate's scale: its Size, its two face attachments and its face Beams' widths and bow (only when it changed).
local function plateScale(Op, G, k)
	if math.abs(k - Op.K) <= 0.004 * k then return end
	Op.K = k
	Op.Part.Size = G.Size * k
	if Op.A0 then Op.A0.CFrame = scaledCF(G.F0, k) end
	if Op.A1 then Op.A1.CFrame = scaledCF(G.F1, k) end
	local w, h = G.W * k, G.H * k
	if Op.Facet then Op.Facet.Width0, Op.Facet.CurveSize0, Op.Facet.CurveSize1 = w, h, h end
	if Op.Depth then Op.Depth.Width0, Op.Depth.CurveSize0, Op.Depth.CurveSize1 = w, h, h end
end

local function plateShow(Op, on)
	if Op.Vis == on then return end
	Op.Vis = on
	Op.Part.Transparency = on and 0 or 1
	if Op.Facet then Op.Facet.Enabled = on end
	if Op.Depth then Op.Depth.Enabled = on end
end

--- A plate's two face Beams: its light (colour, Brightness, opacity) and its depth. Written only on change.
local function faceLook(Op, gc, gb, ga, dc, db, da)
	local L = Op.L
	if Op.Facet then
		local key = colorKey(gc)
		if L.gk ~= key then
			L.gk = key
			Op.Facet.Color = CS1(gc)
		end
		if math.abs((L.gb or -1) - gb) > 0.02 then
			L.gb = gb
			Op.Facet.Brightness = gb
		end
		local ak = alphaKey(ga)
		if L.ga ~= ak then
			L.ga = ak
			Op.Facet.Transparency = NSa(ga)
		end
	end
	if Op.Depth then
		local on = db > 0.01
		if Op.Depth.Enabled ~= on then Op.Depth.Enabled = on end
		if on then
			local key = colorKey(dc)
			if L.dk ~= key then
				L.dk = key
				Op.Depth.Color = CS1(dc)
			end
			if math.abs((L.db or -1) - db) > 0.02 then
				L.db = db
				Op.Depth.Brightness = db
			end
			local ak = alphaKey(da)
			if L.da ~= ak then
				L.da = ak
				Op.Depth.Transparency = NSa(da)
			end
		end
	end
end

local function bodyColor(part, L, color)
	local key = colorKey(color)
	if L.bk ~= key then
		L.bk = key
		part.Color = color
	end
end

--- The cracks down the plates' seams: sat at radius `r`, with this frame's look. a <= 0.01 hides them.
local function seamsDraw(O, r, cw, gw, cb, gb, a, cc, speed)
	local P = O.P
	local L = P.SeamL
	local on = a > 0.01
	if on ~= L.on then
		L.on = on
		for _, S in ipairs(P.Seams) do
			if S.Core then S.Core.Enabled = on end
			if S.Glow then S.Glow.Enabled = on end
		end
	end
	if not on then return end
	local off = GEO.core.Base * P.CoreK                    -- part-local = orb-local + the core's pivot offset
	if math.abs(r - P.SeamR) > 0.0015 or (off - P.SeamOff).Magnitude > 0.001 then
		P.SeamR, P.SeamOff = r, off
		for j, Sg in ipairs(GEO.seams) do
			local S = P.Seams[j]
			if S.A0 then S.A0.CFrame = CFrame.new(off) * scaledCF(Sg.U0, r) end
			if S.A1 then S.A1.CFrame = CFrame.new(off) * scaledCF(Sg.U1, r) end
			local h = Sg.H * r
			if S.Core then S.Core.CurveSize0, S.Core.CurveSize1 = h, h end
			if S.Glow then S.Glow.CurveSize0, S.Glow.CurveSize1 = h, h end
		end
	end
	local wChanged = math.abs((L.cw or -1) - cw) > 0.002 or math.abs((L.gw or -1) - gw) > 0.006
	local bChanged = math.abs((L.cb or -1) - cb) > 0.03 or math.abs((L.gb or -1) - gb) > 0.02
	local ck = colorKey(cc)
	local ak = alphaKey(a)
	local sp = math.floor(speed * 10 + 0.5) / 10
	local cChanged, aChanged, sChanged = L.ck ~= ck, L.ak ~= ak, L.sp ~= sp
	if not (wChanged or bChanged or cChanged or aChanged or sChanged) then return end
	L.cw, L.gw, L.cb, L.gb, L.ck, L.ak, L.sp = cw, gw, cb, gb, ck, ak, sp
	local cs = cChanged and CS1(cc) or nil
	local ct = aChanged and NSa(a) or nil
	local gt = aChanged and NSseam(a) or nil
	for j, S in ipairs(P.Seams) do
		local c, g = S.Core, S.Glow
		if c and g then
			if wChanged then
				c.Width0, c.Width1 = cw, cw
				g.Width0, g.Width1 = gw, gw
			end
			if bChanged then
				c.Brightness = cb
				g.Brightness = gb
			end
			if cs then c.Color = cs end
			if ct then
				c.Transparency = ct
				g.Transparency = gt
			end
			if sChanged then
				local v = sp * GEO.seams[j].Sign
				c.TextureSpeed, g.TextureSpeed = v, v
			end
		end
	end
end

--- The core's own violet cracks at the core's scale cs (x CoreScale already): the forming core, the release.
local function cracksDraw(O, cs, k, speed)
	local P = O.P
	local L = P.CrackL
	local on = k > 0.01 and cs > 0.01
	if on ~= L.on then
		L.on = on
		for _, S in ipairs(P.Cracks) do
			if S.Core then S.Core.Enabled = on end
			if S.Glow then S.Glow.Enabled = on end
		end
	end
	if not on then return end
	local r = GEO.R * cs * 1.01
	local off = GEO.core.Base * P.CoreK
	if math.abs(r - P.CrackR) > 0.0015 or (off - P.CrackOff).Magnitude > 0.001 then
		P.CrackR, P.CrackOff = r, off
		for j, Sg in ipairs(GEO.seams) do
			local S = P.Cracks[j]
			if S.A0 then S.A0.CFrame = CFrame.new(off) * scaledCF(Sg.U0, r) end
			if S.A1 then S.A1.CFrame = CFrame.new(off) * scaledCF(Sg.U1, r) end
			local h = Sg.H * r
			if S.Core then S.Core.CurveSize0, S.Core.CurveSize1 = h, h end
			if S.Glow then S.Glow.CurveSize0, S.Glow.CurveSize1 = h, h end
		end
	end
	local cw, gw = 0.07 * cs, 0.50 * cs
	local cb, gb = 1.4 * k, 1.8 * k
	local sp = math.floor(speed * 10 + 0.5) / 10
	if math.abs((L.cw or -1) - cw) < 0.002 and math.abs((L.cb or -1) - cb) < 0.03 and L.sp == sp then return end
	L.cw, L.cb, L.sp = cw, cb, sp
	local tl = T.SeamHot[1] * math.max(0.1, cs)
	for j, S in ipairs(P.Cracks) do
		local v = sp * GEO.seams[j].Sign
		local c, g = S.Core, S.Glow
		if c then c.Width0, c.Width1, c.Brightness, c.TextureLength, c.TextureSpeed = cw, cw, cb, tl, v end
		if g then g.Width0, g.Width1, g.Brightness, g.TextureLength, g.TextureSpeed = gw, gw, gb, tl, v end
	end
end

local function spriteSet(gui, img, L, size, alpha, bright)
	local on = alpha > 0.01 and size > 0.01 and bright > 0.02     -- (Brightness 0 draws black, not nothing)
	if gui.Enabled ~= on then gui.Enabled = on end
	if not on then return end
	if math.abs((L.size or -1) - size) > 0.01 then
		L.size = size
		gui.Size = UDim2.new(size, 0, size, 0)
	end
	local ak = alphaKey(alpha)
	if L.ak ~= ak then
		L.ak = ak
		img.ImageTransparency = 1 - ak / 200
	end
	if math.abs((L.br or -1) - bright) > 0.03 then
		L.br = bright
		gui.Brightness = bright
	end
end

--- Hides every crackle chain from slot `from` on.
local function crackleHide(O, from)
	for i = from, #O.Crk do
		local sl = O.Crk[i]
		if sl.Main then sl.Main:Hide() end
		if sl.Fork then sl.Fork:Hide() end
	end
end

local function crackleSlot(O, i)
	local sl = O.Crk[i]
	if sl then return sl end
	sl = { Main = newChain(O, 8), Fork = newChain(O, 2), Bm = newBuf(), Bf = newBuf() }
	O.Crk[i] = sl
	return sl
end

--- The whole orb for one frame at centre C, drawn scale s (volt_orb_bl orb_frame): body and face lights, the cracks,
--- the core (and its violet cracks while forming), the kernel, the crackle and its touches, the halo, the corona.
--- formT: seconds into the windup while it is still forming; crack: 0..1 across the impact's crack.
local function drawOrb(O, F, C, s, f, formT, crack, wild, dt, spinRate, want, viewW)
	local fk = clamp01(f)
	orbStep(O, O.lt, fk, dt, spinRate, wild, want, viewW)
	O.DrawC, O.s = C, s
	local P = O.P
	local orbCF = CFrame.new(C) * O.rot
	local p = crack > 0 and 1 or O.p
	local glow = crack > 0 and 1 or O.glow
	if P and GEO then
		-- the plates, each carrying its face's light and depth
		local base = lerp(T.FacetGlow[1], T.FacetGlow[2], fk ^ 1.3) * glow
		local shHz = lerp(T.FacetShimmer[2], T.FacetShimmer[3], fk)
		local shDepth = T.FacetShimmer[1]
		if O.Calm then shHz, shDepth = math.min(shHz, T.CalmPulseHz), math.min(shDepth, T.CalmPulseDepth) end
		local hot = T.FacetHot * fk * fk
		local d0, d1, ia, ib = T.DepthGlow[1], T.DepthGlow[2], T.DepthIgnite[1], T.DepthIgnite[2]
		-- the depths: violet, straining with the surge, then dark for a beat and IGNITED yellow (a switch, never a blend)
		local dc, db
		if fk < ia then
			dc, db = COL.Dark, lerp(d0, d1, fk / ia) * (0.7 + 0.3 * p)
		elseif fk < ib then
			dc, db = COL.Dark, d1 * (1 - (fk - ia) / (ib - ia))
		else
			dc, db = COL.Base, T.DepthGlow[3] * ease((fk - ib) / (1 - ib))
		end
		db *= 1 - easeOut(crack)
		local t = O.lt
		local shove = T.CrackShove * easeOut(crack)
		for i, G in ipairs(GEO.facets) do
			local Op = P.Plates[i]
			if Op then
				local off = T.Breathe * p * G.Breathe + T.Strain * fk + shove
				local twist, pscale, ga = 0, 1, 1
				local shim = 1 - shDepth * (0.5 + 0.5 * math.sin(TAU * shHz * t + G.Phase))
				local fl = O.flare[i] or 0
				local gb = base * shim * (1 + 0.7 * fl) * (1 + 1.3 * easeOut(crack))
				local gc = COL.Base:Lerp(COL.Light, clamp01(hot + 0.5 * fl + 0.7 * crack))
				local visible = true
				if formT then
					local af = O.arrive[i] or T.FacetsIn[2]
					local u = span(formT, af - T.FacetFly, af)
					if u <= 0 then
						visible = false
					else
						local e = easeOut(u)
						off += (1 - e) * (T.FacetFrom - 1) * G.Dist
						twist = (1 - e) * G.Twist
						pscale = lerp(0.6, 1.0, e)
						local lock = formT >= af and (1 - span(formT, af, af + 0.05)) or 0
						gc = gc:Lerp(COL.Light, 0.8 * lock)
						gb *= 1 + 1.2 * lock
						ga = lerp(0.4, 1.0, e)
					end
				end
				plateShow(Op, visible)
				if visible then
					local k = s * pscale
					plateScale(Op, G, k)
					local pivot = orbCF * CFrame.new((G.P + G.N * off) * s)
					if twist ~= 0 then pivot *= CFrame.fromAxisAngle(G.N, twist) end
					queue(O, Op.Part, placeCF(pivot, G.Base, k))
					bodyColor(Op.Part, Op.L, BODY)
					faceLook(Op, gc, gb, ga, dc, db, ga)
				end
			end
		end
		-- the core deep in the cracks: Neon Dark x 0.12-0.22, pulsing; forming, a dark violet core growing in the palm
		local coreS = 1
		local coreCol = scaleC(COL.Dark, lerp(T.CoreDark[1], T.CoreDark[2], p))
		if formT then
			coreCol = scaleC(COL.Dark, 0.45):Lerp(coreCol, ease(span(formT, T.FacetsIn[1] + 0.03, T.Windup)))
			coreS = formT >= T.CoreGrow[1] and lerp(0.35, 1.0, easeOut(span(formT, T.CoreGrow[1], T.CoreGrow[2]))) or 0
		end
		-- (always moved, hidden or not: the cracks, the halo, the corona and the touches ride it)
		local core = P.Core
		local coreOn = coreS > 0.01
		local ck = math.max(0.01, coreS * s)
		if math.abs(ck - P.CoreK) > 0.004 * ck then
			P.CoreK = ck
			core.Size = GEO.core.Size * ck
		end
		queue(O, core, placeCF(orbCF, GEO.core.Base, ck))
		if coreOn then bodyColor(core, P.CoreL, coreCol) end
		local ctr = coreOn and 0 or 1
		if core.Transparency ~= ctr then core.Transparency = ctr end
		-- the kernel: the bright seed of the windup
		local kernel = P.Kernel
		if kernel and GEO.kernel then
			local kk = 0
			if formT and formT < T.Windup + 0.02 then
				local ks = easeOut(span(formT, T.KernelAt, T.KernelAt + 0.06))
				kk = ks * (1 - 0.3 * span(formT, 0.18, T.Windup))
			end
			local on = kk > 0.01
			local ktr = on and 0 or 1
			if kernel.Transparency ~= ktr then kernel.Transparency = ktr end
			if on then
				local k = kk * s
				if math.abs(k - P.KernelK) > 0.004 * k then
					P.KernelK = k
					kernel.Size = GEO.kernel.Size * k
				end
				queue(O, kernel, placeCF(orbCF, GEO.kernel.Base, k))
			end
		end
		-- the cracks: light escaping, brighter, wider and faster as the fuse runs down; blazing at the crack
		local a = formT and span(formT, T.FacetsIn[1] + 0.03, T.Windup) or 1
		local lift = 1 + (T.Breathe * O.p + T.Strain * fk) / GEO.R + 0.35 * easeOut(crack)
		local ramp = fk ^ 1.2
		seamsDraw(O, GEO.R * lift * s,
			T.SeamCore[1] * (1 + 0.6 * crack) * s, T.SeamGlow[1] * (1 + 0.5 * crack) * s,
			lerp(T.SeamCore[2], T.SeamCore[3], ramp) * glow * (1 + 0.8 * crack),
			lerp(T.SeamGlow[2], T.SeamGlow[3], ramp) * glow * (1 + 0.6 * crack),
			a, COL.Light:Lerp(WHITE_HOT, clamp01(0.6 * fk + crack)), O.hotRate / T.SeamHot[1] * O.Ts)
		-- the forming core's own violet cracks, gone as the plates close over it
		if formT and coreS > 0.01 then
			cracksDraw(O, coreS * T.CoreScale * s,
				(0.7 + 0.3 * O.p) * (1 - ease(span(formT, T.FacetsIn[1] + 0.02, T.Windup))), O.hotRate / T.SeamHot[1] * O.Ts)
		elseif not O.Releasing then
			cracksDraw(O, 0, 0, 0)
		end
		-- the halo (violet aura, alpha-blended) and the corona (Base glow round the silhouette)
		local hs, ha = T.Halo[1], T.Halo[2] * (0.6 + 0.4 * p)
		local corona = T.Corona[2] * glow * lerp(1.0, 1.6, fk) * (1 + crack)
		if formT then
			hs, ha = lerp(0.9, T.Halo[1], span(formT, T.KernelAt, T.Windup)), T.Halo[2] * math.min(1, formT / 0.08)
			corona *= span(formT, T.FacetsIn[1], T.Windup)
		end
		if crack > 0 then hs, ha = hs * (1 + 0.6 * crack), math.min(1, ha * (1 + 0.8 * crack)) end
		if P.Halo and P.HaloImg then
			spriteSet(P.Halo, P.HaloImg, P.HaloL, math.min(hs * 2 * s, 1.8 * math.max(0.2, O.FloorH)), ha, T.Halo[3])
		end
		if P.Corona and P.CoronaImg then
			spriteSet(P.Corona, P.CoronaImg, P.CoronaL, T.Corona[1] * 2 * s * (1 + 0.4 * crack), 1, corona)
		end
	end
	-- the crackle: white-hot arcs in a Base glow, x1.7 by the fuse's end, held to the crystal
	if GEO then
		for i, S in ipairs(O.slots) do
			local A = S.arc
			local sl = crackleSlot(O, i)
			if A and A.pts then
				local wpts = table.create(#A.pts)
				for j, q in ipairs(A.pts) do wpts[j] = orbCF:PointToWorldSpace(q * s) end
				chainDraw(sl.Main, sl.Bm, wpts, T.CrackleCore[1] * (1 + 0.4 * wild) * s, T.CrackleGlow[1] * (1 + 0.3 * wild) * s,
					0.2, T.CrackleCore[2] * A.k, T.CrackleGlow[2] * A.k, A.alpha, WHITE_HOT, COL.Base)
				if A.forkPts then
					local fp = table.create(#A.forkPts)
					for j, q in ipairs(A.forkPts) do fp[j] = orbCF:PointToWorldSpace(q * s) end
					chainDraw(sl.Fork, sl.Bf, fp, T.CrackleCore[1] * 0.7 * s, T.CrackleGlow[1] * 0.7 * s, 0.6,
						T.CrackleCore[2] * A.k * 0.8, T.CrackleGlow[2] * A.k * 0.8, A.alpha, WHITE_HOT, COL.Base)
				elseif sl.Fork then
					sl.Fork:Hide()
				end
			else
				if sl.Main then sl.Main:Hide() end
				if sl.Fork then sl.Fork:Hide() end
			end
		end
		crackleHide(O, #O.slots + 1)
		-- the touches: a small hot spot where each arc meets the crystal
		if P then
			local n = 0
			local off = GEO.core.Base * P.CoreK                 -- part-local = orb-local + the core's pivot offset
			for _, tc in ipairs(O.touches) do
				if tc[2] > 0.02 and n < #P.Touch then
					n += 1
					local Tt = P.Touch[n]
					Tt.Att.Position = tc[1] * 1.04 * s + off
					spriteSet(Tt.Gui, Tt.Img, Tt.L, T.Touch[1] * 2 * s, math.min(1, tc[2]), T.Touch[2])
					Tt.On = true
				end
			end
			for k = n + 1, #P.Touch do
				local Tt = P.Touch[k]
				if Tt.On then
					Tt.On = false
					Tt.Gui.Enabled = false
				end
			end
		end
	end
	flush(O)
end

--- Hides everything the orb's shell draws (at the break, a fizzle's end).
local function hideShell(O)
	if O.P then
		local P = O.P
		seamsDraw(O, P.SeamR, 0, 0, 0, 0, 0, COL.Light, 0)
		if P.Halo then P.Halo.Enabled = false end
		if P.Corona then P.Corona.Enabled = false end
		for _, Tt in ipairs(P.Touch) do
			Tt.On = false
			Tt.Gui.Enabled = false
		end
		if P.Kernel then P.Kernel.Transparency = 1 end
	end
	table.clear(O.slots)
	crackleHide(O, 1)
end

----------------------------------------------------------------------------------------------------
-- 1 THE WINDUP extras: arcs reeled into the palm, the inward motes, the implosion, the lock
----------------------------------------------------------------------------------------------------
local function poolSlot(O, i)
	local sl = O.Pool[i]
	if sl then return sl end
	sl = { Main = newChain(O, 4), Fork = newChain(O, 2), Bm = newBuf(), Bf = newBuf(), Busy = false }
	O.Pool[i] = sl
	return sl
end

local function windupArcs(O, C, s)
	if O.warcs then return end
	local wr = Random.new(O.Seed + 11)
	local n = O.Thin and 4 or T.WindupArcs
	local head = O.Character and O.Character:FindFirstChild("Head")
	local headPos = (not O.FP) and head and head:IsA("BasePart") and head.Position or nil
	O.warcs = {}
	for k = 1, n do
		local d, r0
		for _ = 1, 12 do
			d = randUnit(wr)
			if d.Y < -0.4 then d = Vector3.new(d.X, d.Y * -0.5, d.Z).Unit end
			r0 = pick(wr, T.WindupArcFrom)
			if not headPos or ((C + d * r0 * s) - headPos).Magnitude > 1.3 then break end   -- not out of the head
		end
		O.warcs[k] = {
			s = lerp(T.WindupArcStart[1], T.WindupArcStart[2], (k - 1) / math.max(1, n - 1)) + wr:NextNumber(-0.012, 0.012),
			d = d, r0 = r0, swirl = wr:NextNumber(0.6, 1.1) * (wr:NextNumber() < 0.5 and -1 or 1),
			seed = wr:NextInteger(1, 1000000), fork = wr:NextNumber() < T.WindupFork,
		}
	end
end

local function drawWindup(O, C, s, wt)
	local cw, gw, cb, gb = T.WindupArc[1], T.WindupArc[2], T.WindupArc[3], T.WindupArc[4]
	local rerollN = math.floor(wt / T.Reroll)
	for k, A in ipairs(O.warcs) do
		local sl = poolSlot(O, k)
		local u = (wt - A.s) / T.WindupArcLife
		local drawn = false
		if u >= 0 and u < 1 then
			local r = lerp(A.r0, 0.25, u ^ 1.4) * s
			local dd = CFrame.fromAxisAngle(Vector3.yAxis, A.swirl * u):VectorToWorldSpace(A.d)
			local ar = Random.new(A.seed + rerollN)
			local pts = jag(C + dd * r, C, 2, 0.30 * r, ar, nil, nil, nil, 0.6)
			-- gone before it is short (a lone shrinking arc with a sparkle at its tip is a burning fuse)
			local a = u < 0.40 and 1 or math.max(0, (0.65 - u) / 0.25)
			local shown = reveal(pts, span(u, 0, 0.22))
			if shown and a > 0 then
				drawn = true
				sl.Busy = true
				chainDraw(sl.Main, sl.Bm, shown, cw * s, gw * s, 0.3, lerp(cb * 0.8, cb, u), gb, a, COL.Light, COL.Base)
				if A.fork and u > 0.2 then
					local fb = pts[2]
					local out = fb - C
					out = out.Magnitude > 1e-4 and out.Unit or Vector3.yAxis
					local fd = out:Cross(Vector3.yAxis)
					fd = fd.Magnitude > 1e-3 and fd.Unit or anyPerp(out)
					local fe = fb + (fd * 0.6 + out * 0.5).Unit * 0.4 * r
					chainDraw(sl.Fork, sl.Bf, jag(fb, fe, 1, 0.12 * r, ar), cw * 0.7 * s, gw * 0.7 * s, 0.5, cb * 0.8, gb, a,
						COL.Light, COL.Base)
				elseif sl.Fork then
					sl.Fork:Hide()
				end
			end
		end
		if not drawn then
			if sl.Main then sl.Main:Hide() end
			if sl.Fork then sl.Fork:Hide() end
			sl.Busy = false
		end
	end
	-- the inward motes (a Sphere emitter on the palm host, in three bursts over 0.00-0.10) and the implosion sprite
	for b = 1, 3 do
		local at = (b - 1) * 0.05
		local key = "mote" .. b
		if not O.fired[key] and wt >= at then
			O.fired[key] = true
			if wt - at < 0.05 then
				local r = 2.1 * s
				O.Hand.Size = Vector3.one * (2 * r)
				burstFx(O, O.Hand, "PoleSpark", math.ceil(T.WindupMotes / 3), {
					Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = NumberRange.new(r / 0.17, r / 0.10),
					SpreadAngle = Vector2.new(0, 0),
					Lifetime = NumberRange.new(0.10, 0.17), Acceleration = Vector3.zero, Drag = 0,
					Size = NS({ { 0, 0.06 }, { 0.4, 0.14, 0.03 }, { 1, 0.06 } }, s),
					Transparency = NS({ { 0, 1 }, { 0.2, 0 }, { 1, 0 } }), LockedToPart = true, Brightness = 4,
					Color = ColorSequence.new(COL.Light, COL.Base), Rate = 0,
				})
			end
		end
	end
	if not O.fired.implode and wt >= T.Implode[1] then
		O.fired.implode = true
		if wt - T.Implode[1] < 0.06 then
			spriteFx(O, O.HandAtt, 2.6 * s, 0.5 * s, { { 0, 0.85 }, { 0.8, 0.45 }, { 1, 1 } }, T.Implode[2] - T.Implode[1],
				COL.Light, 0.25, 2.5)
		end
	end
end

local function endWindup(O)
	if O.windupDone then return end
	O.windupDone = true
	for _, sl in ipairs(O.Pool) do
		if sl.Main then sl.Main:Hide() end
		if sl.Fork then sl.Fork:Hide() end
		sl.Busy = false
	end
end

----------------------------------------------------------------------------------------------------
-- where the orb is: the hand (third person, first person) and the flight
----------------------------------------------------------------------------------------------------
local function pathPos(th, t)
	return th.From + th.Vel * t + Vector3.new(0, -0.5 * th.Gravity * t * t, 0)
end

local function pathVel(th, t)
	return th.Vel + Vector3.new(0, -th.Gravity * t, 0)
end

--- The orb in the hand: centre to draw at, drawn scale, and the TRUE centre (lights). First person: the stand-in.
local function handAnchor(O, F)
	if O.Own and F.fist and F.eye then
		O.FP = true
		local fist = F.fist
		local tip = fist.Position
		local k0 = math.clamp((tip - F.eye).Magnitude / T.FPDepth, 0.02, 1)
		local c = tip + fist.LookVector * (T.FPAhead * T.Radius * k0) + fist.UpVector * (T.FPLift * T.Radius * k0)
		local s = math.clamp((c - F.eye).Magnitude / T.FPDepth, 0.02, 1)
		O.LastHand = c
		return c, s, F.eye + (c - F.eye) / s
	end
	O.FP = false
	local ch = O.Character
	local g = O.Grip
	if ch and not (g and g.Parent) and os.clock() >= (O.gripRetry or 0) then
		O.gripRetry = os.clock() + 0.5
		local ok, hands = pcall(Kit.hands, ch)
		g = ok and type(hands) == "table" and hands.R or nil
		O.Grip = g
	end
	if g and g.Parent then
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local fwd = (root and root:IsA("BasePart")) and root.CFrame.LookVector or Vector3.zero
		local c = g.WorldPosition + Vector3.yAxis * T.HandLift + fwd * T.HandAhead
		O.LastHand = c
		return c, 1, c
	end
	local c = O.LastHand or (O.Throw and O.Throw.From) or O.DrawC or Vector3.zero
	return c, 1, c
end

local function floorProbe(O, C)
	if O.lt < O.floorAt then return end
	O.floorAt = O.lt + 0.1
	local hit = workspace:Raycast(C, Vector3.new(0, -40, 0), O.Params)
	O.FloorH = hit and math.max(0.2, C.Y - hit.Position.Y) or 20
end

----------------------------------------------------------------------------------------------------
-- 3 FLIGHT extras: the trail's tendrils (never on the orb on this client's screen) and the shed sparkles
----------------------------------------------------------------------------------------------------
local function spawnTendril(O, C, vd, reach, s, eye)
	local tr = O.Rng
	for _ = 1, 6 do
		local back = (-vd + perpOf(vd, tr) * tr:NextNumber(0, 0.5)).Unit
		local s0 = C + back * (reach + pick(tr, T.TrailGap) * s)
		local dirv = -vd * 0.5 + randUnit(tr) * 0.9
		dirv = dirv.Magnitude > 1e-4 and dirv.Unit or -vd
		local dp = dirv:Dot(-vd)
		if dp < 0.5 then dirv = (dirv - vd * ((0.5 - dp) * 1.6)).Unit end       -- always leading AWAY from the orb
		local L = pick(tr, T.TrailLen) * s
		local base = jag(s0, s0 + dirv * L, 2, 0.35 * L, tr)
		local fork = nil
		if tr:NextNumber() < T.TrailFork then
			local fb = base[3]
			local fd = dirv + randUnit(tr) * 0.9
			fd = fd.Magnitude > 1e-4 and fd.Unit or dirv
			local fL = L * tr:NextNumber(0.35, 0.6)
			fork = jag(fb, fb + fd * fL, 1, 0.3 * fL, tr)
		end
		local all = table.clone(base)
		if fork then table.move(fork, 1, #fork, #all + 1, all) end
		if screenClear(all, C, eye, T.TrailScreen * reach) then
			-- drawn from its far end, so its taper leaves the end nearest the orb the thinnest
			local rev = table.create(#base)
			for i = #base, 1, -1 do rev[#rev + 1] = base[i] end
			return { t0 = O.lt, life = pick(tr, T.TrailLife), base = rev, fork = fork, L = L, seed = tr:NextInteger(1, 1000000) }
		end
	end
	return nil
end

local function stepTendrils(O, s)
	local fi = math.floor(O.lt * 60)
	for idx = #O.tendrils, 1, -1 do
		local td = O.tendrils[idx]
		local age = O.lt - td.t0
		local sl = td.slot
		if age >= td.life or age < -0.05 then
			if sl.Main then sl.Main:Hide() end
			if sl.Fork then sl.Fork:Hide() end
			sl.Busy = false
			table.remove(O.tendrils, idx)
		else
			local cr = Random.new(td.seed + fi)              -- nudged every frame, so it crackles
			local n = #td.base
			local pts = table.create(n)
			for k, q in ipairs(td.base) do
				pts[k] = (k == 1 or k == n) and q or q + randUnit(cr) * 0.07 * td.L
			end
			local thin = (age / td.life < 0.6) and 1 or 0.55
			chainDraw(sl.Main, sl.Bm, pts, T.TrailCore[1] * thin * s, T.TrailGlow[1] * s, 0.7, T.TrailCore[2], T.TrailGlow[2], 1,
				COL.Light, COL.Base)
			if td.fork then
				local m = #td.fork
				local fp = table.create(m)
				for k, q in ipairs(td.fork) do
					fp[k] = (k == 1 or k == m) and q or q + randUnit(cr) * 0.05 * td.L
				end
				chainDraw(sl.Fork, sl.Bf, fp, T.TrailCore[1] * 0.7 * thin * s, T.TrailGlow[1] * 0.7 * s, 0.5, T.TrailCore[2],
					T.TrailGlow[2], 1, COL.Light, COL.Base)
			elseif sl.Fork then
				sl.Fork:Hide()
			end
		end
	end
end

local function density(O)
	local _, _, S = Kit.libs()
	local d = (S and tonumber(S.EffectDensity)) or 1
	return math.clamp(d, 0.1, 1) * (O.Thin and 0.5 or 1)
end

local function trailAndShed(O, F, C, s, vd, dt)
	local reach = GEO and GEO.R * s or T.Radius * s
	local dens = density(O)
	O.accTrail += T.TrailRate * dt * dens
	while O.accTrail >= 1 do
		O.accTrail -= 1
		if #O.tendrils < O.maxTendrils then
			local slot = nil
			for i = 1, O.maxTendrils do
				local sl = poolSlot(O, i)
				if not sl.Busy then
					slot = sl
					break
				end
			end
			if slot then
				local td = spawnTendril(O, C, vd, reach, s, F.eye)
				if td then
					slot.Busy = true
					td.slot = slot
					O.tendrils[#O.tendrils + 1] = td
				end
			end
		end
	end
	O.accShed += T.ShedRate * dt * dens
	while O.accShed >= 1 do
		O.accShed -= 1
		local q = C - vd * (reach + pick(O.Rng, T.ShedBack) * s) + randUnit(O.Rng) * 0.5 * s
		if screenClear({ q }, C, F.eye, T.TrailScreen * reach) then
			if O.Shed == nil then
				O.ShedAtt = Instance.new("Attachment")
				O.ShedAtt.Parent = O.LightHost
				O.Shed = emitterFx(O, O.ShedAtt, "PoleSpark", {
					Rate = 0, Size = NS({ { 0, 0.18, 0.04 }, { 1, 0 } }), Transparency = NS({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
					Lifetime = NumberRange.new(0.16, 0.32), Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180),
					Drag = 2, Acceleration = Vector3.new(0, -10, 0), Brightness = 3, Color = ColorSequence.new(COL.Light, COL.Base),
				}) or false
			end
			if O.Shed then
				O.ShedAtt.WorldPosition = q
				O.Shed:Emit(1)
			end
		end
	end
end

--- Bolt slots for the burst, made one per frame during the flight (and any still missing at the burst).
local function boltSlot(O, i)
	local sl = O.Bolts[i]
	if sl then return sl end
	sl = { Main = newChain(O, 8), Fork = newChain(O, 4), Bm = newBuf(), Bf = newBuf() }
	O.Bolts[i] = sl
	return sl
end

----------------------------------------------------------------------------------------------------
-- the orb in the hand and in the air, for one frame
----------------------------------------------------------------------------------------------------
local function stepOrb(O, F, dt)
	local th = O.Throw
	local wt = O.lt
	local tf = th and (F.now - th.ReleaseAt) * F.ts or nil
	local held = not tf or tf < 0
	if held then
		local ch = O.Character
		if not (ch and ch.Parent) then return false end                 -- the caster is gone before the release
		if not th and wt > T.Windup + T.Throw + T.GiveUp then
			fizzleOrb(O, nil)
			return not O.dead
		end
	elseif tf > th.Fuse + T.Linger then
		return false                                                      -- no Burst came: removed silently
	end
	local formT = (not O.Late and wt >= 0 and wt < T.Windup + T.Throw) and wt or nil
	local f, C, s, Lc = 0, nil, 1, nil
	local vd = nil
	if held then
		C, s, Lc = handAnchor(O, F)
	else
		-- the server's path; this client's own swept sphere holds it at its own contact until the Burst comes
		if not O.ContactT and tf <= th.Fuse then
			local pos = pathPos(th, tf)
			local stepV = pos - O.LastPos
			if stepV.Magnitude > 1e-3 then
				local ok, hit = pcall(workspace.Spherecast, workspace, O.LastPos, T.HitRadius, stepV, O.Params)
				if ok and hit then
					O.ContactT = tf
					O.ContactPos = O.LastPos + stepV.Unit * hit.Distance
				else
					O.LastPos = pos
				end
			end
		end
		local tc = math.min(tf, th.Fuse, O.ContactT or math.huge)
		f = tc / th.Fuse
		local truePos = O.ContactPos or pathPos(th, tc)
		vd = pathVel(th, tc)
		vd = vd.Magnitude > 1e-3 and vd.Unit or Vector3.new(0, 0, -1)
		local merge = O.FP and T.FPMerge or T.Merge
		local u = span(tf, 0, merge)
		if u < 1 and not O.Late then
			local hc = handAnchor(O, F)
			C = hc:Lerp(truePos, ease(u))
		else
			C = truePos
		end
		s = (O.FP and F.eye) and math.clamp((C - F.eye).Magnitude / T.FPDepth, 0.02, 1) or 1
		Lc = truePos
	end
	floorProbe(O, C)
	local view = F.eye and (F.eye - C)
	view = (view and view.Magnitude > 1e-3) and view.Unit or nil
	local want = nil
	if formT and formT < T.Windup then want = formT < 0.17 and 0 or 1 end   -- the first arc crackles at 0.17
	drawOrb(O, F, C, s, f, formT, 0, 0, dt, held and T.Spin[1] or T.Spin[2], want, view)
	-- the palm host rides the drawn orb; the lights ride the true one
	O.Hand.CFrame = CFrame.new(C)
	O.LightHost.CFrame = CFrame.new(Lc)
	local ramp = ease(span(wt, 0.03, T.Windup))
	local light
	if not tf or tf < 0.08 then
		light = T.PalmLight * ramp
	else
		light = lerp(T.PalmLight, T.OrbLight[1], ease(span(tf, 0.08, 0.2)))  -- up once it is ~2 studs clear of the hand
	end
	light *= 1 + T.OrbLightUp * f ^ 1.3
	local vk = lerp(T.PalmViolet, 1, ease(span(wt, T.Windup, T.Windup + T.Throw)))
	if O.OrbLight then O.OrbLight.Brightness = light * F.dayK end
	if O.CoreLight then O.CoreLight.Brightness = T.CoreLight[1] * (0.3 + 0.7 * O.p) * ramp * vk * F.dayK end
	-- 1 the windup's arcs, motes, implosion; the lock as it forms
	if not O.Late and wt < T.Windup + 0.02 then
		windupArcs(O, C, s)
		drawWindup(O, C, s, wt)
	else
		endWindup(O)
	end
	if not O.fired.lock and not O.Late and wt >= T.Windup then
		O.fired.lock = true
		if wt - T.Windup < 0.08 then
			spriteFx(O, O.HandAtt, 0.8 * s, 2.0 * s, { { 0, 0.35 }, { 1, 1 } }, 0.09, COL.Light, 0.25, 3.0)
		end
	end
	-- 3 the wake, while it flies
	if not held and not O.ContactT and tf < th.Fuse and O.windupDone then trailAndShed(O, F, C, s, vd, dt) end
	stepTendrils(O, s)
	if not held and #O.Bolts < O.maxBolts then boltSlot(O, #O.Bolts + 1) end
	return true
end

----------------------------------------------------------------------------------------------------
-- 4 THE BURST -- volt_orb_bl Burst / impact_frame / shard_state
----------------------------------------------------------------------------------------------------
local function rootOf(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then return nil end
	local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if r and r:IsA("BasePart") then return r.Position end
	local ok, cf = pcall(model.GetPivot, model)
	return ok and cf.Position or nil
end

--- Where a bolt from I.C toward `e` stops: on the first geometry in the way (not bodies' own clearance), 0.08 off it.
local function obstruct(I, e)
	local d = e - I.C
	if d.Magnitude < 0.05 then return e end
	local hit = workspace:Raycast(I.C, d, I.Params)
	if hit then return hit.Position + hit.Normal * 0.08 end
	return e
end

local function clampSurf(I, e, low)
	local S = I.Surf
	if not S then return e end
	local h = (e - S.P):Dot(S.N)
	if low or h < 0.08 then return e - S.N * (h - 0.08) end
	return e
end

local function makeBolts(I, w, seed)
	local r = Random.new(seed + 100 * w)
	local sb = T.StrikeBolts[math.min(w, #T.StrikeBolts)]
	local nLow, nHigh = sb[1], sb[2]
	if I.Mode ~= "ground" then nLow, nHigh = 0, sb[1] + sb[2] + 1 end
	if I.Thin then nLow, nHigh = math.ceil(nLow * 0.6), math.ceil(nHigh * 0.6) end
	local out = {}
	local phi0 = r:NextNumber(0, TAU)
	for k = 1, nLow + nHigh do
		local low = k <= nLow
		local phi, el
		if low then
			phi, el = phi0 + TAU * (k - 1) / nLow + r:NextNumber(-0.3, 0.3), 0
		elseif I.Mode == "ground" then
			phi, el = r:NextNumber(0, TAU), math.rad(r:NextNumber(30, 72))
		else
			phi, el = r:NextNumber(0, TAU), math.asin(r:NextNumber(-0.8, 1.0))
		end
		local L = r:NextNumber(T.BoltLen[1], T.BoltLen[2]) * (w == 1 and 1 or 0.8)
		local dir = I.E1 * (math.cos(el) * math.cos(phi)) + I.Up * math.sin(el) + I.E2 * (math.cos(el) * math.sin(phi))
		if I.Mode == "wall" and dir:Dot(I.N) < 0 then dir = (dir - I.N * (2 * dir:Dot(I.N))).Unit end   -- out of the wall
		local e = obstruct(I, clampSurf(I, I.C + dir * L, low))
		local forks = {}
		local nf = r:NextInteger(T.Forks[1], T.Forks[2])
		local fk = { at = r:NextNumber(0.3, 0.7), ang = math.rad(r:NextNumber(25, 45)) * (r:NextNumber() < 0.5 and -1 or 1),
			frac = r:NextNumber(0.30, 0.45), seed = r:NextInteger(1, 1000000) }
		if nf >= 1 and not I.Thin then forks[1] = fk end                  -- one fork per bolt (budget); none thin
		out[#out + 1] = { e = e, low = low, L = (e - I.C).Magnitude, forks = forks, seed = r:NextInteger(1, 1000000),
			bold = w == 1 }
	end
	if w == 1 and I.Target then
		out[#out + 1] = { e = I.Target, low = false, L = (I.Target - I.C).Magnitude, target = true, bold = true,
			seed = r:NextInteger(1, 1000000),
			forks = { { at = 0.5, ang = math.rad(35), frac = 0.3, seed = r:NextInteger(1, 1000000) } } }
	end
	-- the orb's own slot cap (thin 6): drop regular bolts first, so the target bolt (appended last) stays
	while #out > (I.MaxBolts or T.MaxBoltSlots) do table.remove(out, 1) end
	return out
end

local function boltPts(I, spec, n)
	if spec.n == n then return spec.pts end
	spec.n = n
	local rr = Random.new(spec.seed + n * 13)
	local L = math.max(0.5, spec.L)
	local surf = I.Surf and { P = I.Surf.P, N = I.Surf.N, Y = spec.low and 0.06 or 0.10 } or nil
	local flatN = spec.low and I.Surf and I.Surf.N or nil
	if spec.bold then
		local depth, amp, kick = T.BoltShape[1], T.BoltShape[2], T.BoltShape[3]
		spec.pts = jag(I.C, spec.e, depth, amp * L, rr, surf, flatN, 0.35, kick)
	elseif spec.low then
		spec.pts = jag(I.C, spec.e, 3, 0.14 * L, rr, surf, flatN, 0.35)
	else
		spec.pts = jag(I.C, spec.e, 3, 0.16 * L, rr, surf)
	end
	spec.forkPts = nil
	return spec.pts
end

local function forkPts(I, spec, pts, fk, n)
	if spec.forkPts then return spec.forkIdx, spec.forkPts end
	local idx = math.clamp(math.floor(fk.at * (#pts - 1) + 0.5), 1, #pts - 2)
	local base = pts[idx + 1]
	local dirv = spec.e - I.C
	dirv = dirv.Magnitude > 1e-4 and dirv.Unit or I.Up
	local axis = perpOf(dirv, Random.new(fk.seed), spec.low and I.Surf and I.Surf.N or nil, 0.2)
	local fd = CFrame.fromAxisAngle(axis, fk.ang):VectorToWorldSpace(dirv)
	local fend = base + fd * spec.L * fk.frac
	fend = clampSurf(I, fend, spec.low)
	local surf = I.Surf and { P = I.Surf.P, N = I.Surf.N, Y = 0.06 } or nil
	spec.forkIdx = idx
	spec.forkPts = jag(base, fend, 2, 0.18 * spec.L * fk.frac, Random.new(fk.seed + n * 7), surf)
	return idx, spec.forkPts
end

local function lightSpots(I)
	local specs = {}
	for _, sp in ipairs(I.Specs[1] or {}) do
		if not sp.target and (I.Mode ~= "ground" or sp.low) then specs[#specs + 1] = sp end
	end
	if #specs == 0 then
		for _, sp in ipairs(I.Specs[1] or {}) do
			if not sp.target then specs[#specs + 1] = sp end
		end
	end
	table.sort(specs, function(a, b) return a.L > b.L end)
	local out = {}
	local n = T.BoltLight[4]
	for _, sp in ipairs(specs) do
		local q = I.C:Lerp(sp.e, 0.6)
		if I.Surf then
			local h = (q - I.Surf.P):Dot(I.Surf.N)
			if h < 0.8 then q += I.Surf.N * (0.8 - h) end
		end
		out[#out + 1] = q
	end
	if I.Target then
		local toC = I.C - I.Target
		toC = toC.Magnitude > 1e-3 and toC.Unit or I.Up
		while #out > n - 1 do table.remove(out) end
		out[#out + 1] = I.Target + toC * 2.5            -- washes the body rather than burning a slit into it
	end
	while #out > n do table.remove(out) end
	return out
end

--- Strike 1's floor bolts pressed flat and cut to their inner CrackReach: the cracks the scorch keeps glowing in.
local function scorchLines(I)
	local out = {}
	local S = I.Surf
	local g = I.Floor
	local n = 0
	for _, spec in ipairs(I.Specs[1] or {}) do
		if spec.low and n < (I.Thin and 3 or T.MaxBurned) then
			n += 1
			local rr = Random.new(spec.seed + 555)
			local ep = spec.e - S.N * (spec.e - g):Dot(S.N)
			local e = g + (ep - g) * T.CrackReach
			local L = (e - g).Magnitude
			local pts = jag(g, e, 2, 0.15 * L, rr, nil, S.N, 0)
			local line = { pts = pts }
			local fk = spec.forks[1]
			if fk and not I.Thin then
				local base = pts[math.clamp(math.floor(fk.at * (#pts - 1) + 0.5), 2, #pts - 2) + 1]
				local dir = e - g
				dir = dir.Magnitude > 1e-4 and dir.Unit or I.E1
				local fd = CFrame.fromAxisAngle(S.N, fk.ang):VectorToWorldSpace(dir)
				local fe = base + fd * L * fk.frac
				line.fork = jag(base, fe, 1, 0.18 * L * fk.frac, rr, nil, S.N, 0)
			end
			out[#out + 1] = line
		end
	end
	return out
end

--- The Bloom kick for this client, scaled by how near the burst is and zero when it is off screen (flag 8).
local function bloomScale(F, pos)
	local cam = F.cam
	if not (cam and F.eye) then return 0 end
	local k = 1 - span((pos - F.eye).Magnitude, T.BloomReach[1], T.BloomReach[2])
	if k <= 0 then return 0 end
	local v, on = cam:WorldToViewportPoint(pos)
	if not on or v.Z <= 0 then return 0 end
	return k
end

local function kick(O, F, pos, share)
	if O.Calm then return end
	local k = bloomScale(F, pos) * share
	if k <= 0.02 then return end
	local B = T.Bloom
	local thr = F.dayK < 1 and 0 or -B[5] * k                 -- a bright sky sits near the threshold: no drop by day
	pcall(Kit.bloomPulse, B[1] * k, B[2] * k, B[3], B[4], thr)
end

local function startImpact(O, data, T0)
	local K = Kit
	local at = data.At
	local nrm = (typeof(data.Normal) == "Vector3" and data.Normal.Magnitude > 0.1) and data.Normal.Unit or Vector3.yAxis
	-- a body struck directly takes the air-burst's every-way spread (showcase flag 3: the burst is designed for a floor)
	local air = data.Air == true or (typeof(data.Direct) == "Instance" and data.Direct:IsA("Model"))
	local I = { T0 = T0, fired = {}, Mode = air and "air" or (nrm.Y > 0.6 and "ground" or "wall"), N = nrm, C0 = at,
		Thin = O.Thin, MaxBolts = O.maxBolts, from = O.DrawC or at, fromS = O.s or 1, flatK = 1, lastRev = -1 }
	-- what the bolts see: everything but the FX, the camera and the caster (a bolt may end on another body)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { K.fxFolder() }
	if O.Character then ex[#ex + 1] = O.Character end
	if workspace.CurrentCamera then ex[#ex + 1] = workspace.CurrentCamera end
	params.FilterDescendantsInstances = ex
	I.Params = params
	-- ...and the floor probe sees through every body as well (a head is not the floor)
	local probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	local pex = table.clone(ex)
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then pex[#pex + 1] = pl.Character end
	end
	for _, m in ipairs({ data.Direct, data.Nearest }) do
		if typeof(m) == "Instance" and m:IsA("Model") then pex[#pex + 1] = m end
	end
	probe.FilterDescendantsInstances = pex
	-- the surface: the floor under a ground burst, the wall of a wall hit, the floor (if near) under an air-burst
	if I.Mode == "wall" then
		I.Surf = { P = at - nrm * 0.5, N = nrm }
	else
		local reach = air and 30 or 4
		local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -(reach + 1), 0), probe)
		if hit then
			I.Surf = { P = hit.Position, N = hit.Normal.Magnitude > 0.1 and hit.Normal.Unit or Vector3.yAxis }
		elseif not air then
			I.Surf = { P = at - nrm * 0.5, N = nrm }
		end
	end
	if I.Mode ~= "wall" and I.Surf then I.FloorY = I.Surf.P.Y end
	if I.Mode == "wall" then
		local hit = workspace:Raycast(at, Vector3.new(0, -30, 0), probe)
		if hit then I.FloorY = hit.Position.Y end
	end
	-- the break's centre: on a floor the cracking orb kicks up to CrackLift
	if I.Mode == "ground" then
		local S = I.Surf
		local h = (at - S.P):Dot(S.N)
		I.C = S.P + S.N * math.max(T.CrackLift, h) + (at - S.P - S.N * h)
		I.Up = S.N
		I.Floor = S.P + (at - S.P - S.N * h) + S.N * 0.05
	else
		I.C = at
		I.Up = Vector3.yAxis
	end
	I.E1 = anyPerp(I.Up)
	I.E2 = I.Up:Cross(I.E1)
	local calm = O.Calm
	if I.Mode == "ground" then
		I.Strikes = calm and T.CalmStrikes or T.Strikes
	else
		I.Strikes = calm and T.CalmAirStrikes or T.AirStrikes
	end
	I.ReleaseEnd = T.Crack + T.Release + 0.05
	-- the body the first strike's extra bolt goes into
	for _, m in ipairs({ data.Nearest, data.Direct }) do
		local p = rootOf(m)
		if p and (p - I.C).Magnitude < T.TargetReach then
			I.Target = p
			break
		end
	end
	local seed = O.Seed + 77
	I.Specs = {}
	for w = 1, #I.Strikes do I.Specs[w] = makeBolts(I, w, seed) end
	I.Spots = lightSpots(I)
	-- the instances: one host at the burst, its lights (<= 7 with none of the orb's left), the afterglow's pieces
	if O.OrbLight then O.OrbLight:Destroy() end
	if O.CoreLight then O.CoreLight:Destroy() end
	O.OrbLight, O.CoreLight = nil, nil
	local host = newHost(O, "VoltOrbBurst", CFrame.new(I.C))
	I.Host = host
	local flashPos = I.Mode == "ground" and (at + I.Up * 1.3) or at
	I.FlashLight = newLight(Kit.attach(host, flashPos), T.FlashLight[2], COL.Light)
	I.CoreAtt = Kit.attach(host, I.C)
	I.CoreLight = newLight(I.CoreAtt, T.CoreLight[2] * 1.6, COL.Dark)
	I.BoltLights = {}
	for j, q in ipairs(I.Spots) do I.BoltLights[j] = newLight(Kit.attach(host, q), T.BoltLight[2], COL.Light) end
	I.SparkAtt = upAttach(host, I.C, I.Up)
	local ok, flat = pcall(K.flatLit)
	I.flatK = (ok and flat) and 0.35 or 1
	if I.Mode == "ground" then
		I.Lines = scorchLines(I)
		I.Flats = {}
		for j, line in ipairs(I.Lines) do
			I.Flats[j] = { Main = newFlat(host, 4, I.flatK), Fork = line.fork and newFlat(host, 2, I.flatK) or nil }
		end
		I.AfterLight = newLight(Kit.attach(host, I.Floor + I.Up * 0.55), T.AfterLight[2], COL.Base)
		-- the soot Decal: a thin invisible part lying on the floor, a random turn
		local sc = Instance.new("Part")
		sc.Name = "VoltOrbScorch"
		sc.Anchored, sc.CanCollide, sc.CanQuery, sc.CanTouch, sc.CastShadow = true, false, false, false, false
		sc.Transparency = 1
		sc.Size = Vector3.new(T.Scorch, 0.05, T.Scorch)
		local look = CFrame.fromAxisAngle(I.Up, O.Rng:NextNumber(0, TAU)):VectorToWorldSpace(I.E1)
		sc.CFrame = CFrame.fromMatrix(I.Floor - I.Up * 0.02, look, I.Up)
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = TEX.Scorch or ""
		decal.Transparency = 1
		decal.Parent = sc
		sc.Parent = O.Folder
		I.Decal = decal
		-- the flat pool of afterglow in the crater
		local pa0, pa1 = Instance.new("Attachment"), Instance.new("Attachment")
		pa0.Parent, pa1.Parent = host, host
		local half = T.PoolGlow[1] / 2
		pa0.WorldCFrame = ribbonFrame(I.Floor + I.Up * 0.03 - I.E1 * half, I.E1, I.Up)
		pa1.WorldCFrame = ribbonFrame(I.Floor + I.Up * 0.03 + I.E1 * half, I.E1, I.Up)
		local pool = flatBeam(pa0, pa1, TEX.Implosion, 1 * I.flatK, 0, host)
		pool.Width0, pool.Width1 = T.PoolGlow[1], T.PoolGlow[1]
		I.Pool = pool
	end
	-- the rest of the bolt slots, if the flight was too short to make them
	local need = 0
	for _, list in ipairs(I.Specs) do need = math.max(need, #list) end
	for i = #O.Bolts + 1, need do boltSlot(O, i) end
	O.I = I
	O.Hand.CFrame = CFrame.new(I.C)
end

--- The plates as shrapnel, thrown along their normals at the break.
local function breakShell(O, I)
	I.broke = true
	hideShell(O)
	local sr = Random.new(O.Seed + 61)
	local lift = I.Mode == "ground" and T.ShardLift or T.AirShardLift
	I.Shards = {}
	if O.P and GEO then
		for i, G in ipairs(GEO.facets) do
			if O.P.Plates[i] then
				local nw = O.rot:VectorToWorldSpace(G.N)
				I.Shards[i] = {
					p0 = I.C + O.rot:VectorToWorldSpace((G.P + G.N * T.CrackShove) * 1.08),
					v = nw * pick(sr, T.ShardSpeed) + Vector3.new(0, pick(sr, lift), 0),
					axis = randUnit(sr), w = pick(sr, T.ShardSpin), life = T.ShardLife * sr:NextNumber(0.8, 1.2),
					R0 = O.rot, corners = G.Corners,
				}
			end
		end
	end
	-- the violet core's release sprite
	spriteFx(O, I.CoreAtt, 1.6, 8.5, { { 0, 0.1 }, { 0.5, 0.45 }, { 1, 1 } }, 0.45, COL.Dark, 0, 3.0)
end

local function shardDraw(O, I, i, S, sd)
	local Op = O.P.Plates[i]
	local G = GEO.facets[i]
	local u = sd / S.life
	if u >= 1 then
		plateShow(Op, false)
		return
	end
	local g = T.ShardGravity
	local pos = S.p0 + S.v * sd + Vector3.new(0, -0.5 * g * sd * sd, 0)
	local spin = S.w * sd
	local sc = lerp(1.0, 0.08, easeIn(u))
	if I.FloorY and pos.Y < I.FloorY + 0.1 then
		-- a shard is a Part: it lands, skids a little and stops, resting on its lowest corner
		local a, b, c = -0.5 * g, S.v.Y, S.p0.Y - (I.FloorY + 0.1)
		local tc = math.max(0, (-b - math.sqrt(math.max(0, b * b - 4 * a * c))) / (2 * a))
		local dtc = math.max(0, sd - tc)
		local slide = (1 - math.exp(-8 * dtc)) / 8
		local h = Vector3.new(S.v.X, 0, S.v.Z)
		pos = S.p0 + S.v * tc + Vector3.new(0, -0.5 * g * tc * tc, 0) + h * slide
		spin = S.w * (tc + slide)
		local Rl = CFrame.fromAxisAngle(S.axis, spin) * S.R0
		local low = math.huge
		for _, cv in ipairs(S.corners) do low = math.min(low, Rl:VectorToWorldSpace(cv).Y) end
		pos = Vector3.new(pos.X, I.FloorY + 0.02 - low * sc, pos.Z)
	end
	-- its face's glow cools with it: white-hot -> Base, then (never through pink) dark and up into dim violet
	local col, k
	if u < 0.3 then
		col, k = COL.Light:Lerp(COL.Base, u / 0.3), lerp(2.6, 1.6, u / 0.3)
	else
		col, k = cool(span(u, 0.3, 0.9))
		k = math.max(k, 0.35) * 1.6
	end
	plateShow(Op, true)
	plateScale(Op, G, sc)
	queue(O, Op.Part, placeCF(CFrame.new(pos) * CFrame.fromAxisAngle(S.axis, spin) * S.R0, G.Base, sc))
	bodyColor(Op.Part, Op.L, scaleC(BODY, 1 - 0.8 * span(u, 0.15, 0.7)))
	-- (thin: the shards carry their light only, no violet depth)
	faceLook(Op, col, k, 1 - span(u, 0.35, 0.75), COL.Dark, I.Thin and 0 or 0.8 * (1 - span(u, 0, 0.5)), 1)
end

local function drawBolts(O, I, d)
	local n = math.floor(d / T.Reroll)
	local used = 0
	for w, S in ipairs(I.Strikes) do
		local a, b, k = S[1], S[2], S[3]
		if d >= a and d < b then
			local rev = w == 1 and span(d, a, a + T.BoltReveal) or span(d, a - 1 / 60, a + 0.02)
			local fade = span(d, a + (b - a) * 0.6, b)
			local kb = k * (O.Calm and T.CalmBolts or 1)
			local rootC = (w == 1 and d < I.ReleaseEnd) and I.C or nil
			for j, spec in ipairs(I.Specs[w]) do
				local sl = boltSlot(O, j)
				used = math.max(used, j)
				local pts = boltPts(I, spec, n)
				local shown = reveal(pts, rev)
				-- two layers: a thin white-hot core, soft-edged, inside a wide Base glow that fades to nothing
				chainDraw(sl.Main, sl.Bm, shown, T.BoltCore[1] * k * (1 - 0.4 * fade), T.BoltGlow[1] * math.sqrt(k), 0.55,
					T.BoltCore[2] * kb, T.BoltGlow[2] * kb * (spec.low and T.FloorGlow or 1), 1 - 0.8 * fade, WHITE_HOT, COL.Base,
					rootC, T.ReleaseClear)
				local fk = spec.forks[1]
				local drewFork = false
				if fk and #pts >= 4 then
					local idx, fp = forkPts(I, spec, pts, fk, n)
					local x = rev * (#pts - 1)
					if x > idx then
						drewFork = true
						chainDraw(sl.Fork, sl.Bf, reveal(fp, clamp01((x - idx) / 2)), T.BoltCore[1] * 0.6 * k * (1 - 0.4 * fade),
							T.BoltGlow[1] * 0.65 * math.sqrt(k), 0.6, T.BoltCore[2] * 0.8 * kb, T.BoltGlow[2] * 0.8 * kb,
							1 - 0.8 * fade, WHITE_HOT, COL.Base)
					end
				end
				if not drewFork and sl.Fork then sl.Fork:Hide() end
			end
			break
		end
	end
	for j = used + 1, #O.Bolts do
		local sl = O.Bolts[j]
		if sl.Main then sl.Main:Hide() end
		if sl.Fork then sl.Fork:Hide() end
	end
end

local function stepImpact(O, F, dt)
	local I = O.I
	local d = (F.now - I.T0) * F.ts
	if d >= T.End then return false end
	local calmK = O.Calm and 0.6 or 1
	local dayK = F.dayK
	local s1a, s1b = I.Strikes[1][1], I.Strikes[1][2]
	-- CONTACT and THE CRACK: the orb kicks up, swells, its plates shoved out, every face flooding, the arcs wild
	if d < T.Crack then
		local u = d / T.Crack
		local e = easeOut(u)
		local Cu = I.from:Lerp(I.C, e)
		local sc = lerp(I.fromS, 1, e) * (1 + 0.08 * e)
		local view = F.eye and (F.eye - Cu)
		view = (view and view.Magnitude > 1e-3) and view.Unit or nil
		drawOrb(O, F, Cu, sc, 1, nil, u, 1, dt, T.Spin[2] * 0.25, nil, view)
		if I.CoreLight then
			I.CoreAtt.WorldPosition = Cu
			I.CoreLight.Range = T.CoreLight[2] * 1.6
			I.CoreLight.Brightness = T.CoreLight[1] * 3.5 * dayK
		end
		if not I.fired.hit then
			I.fired.hit = true
			local att = Kit.attach(I.Host, I.C0)
			spriteFx(O, att, 0.6 * (O.Calm and 0.75 or 1), 1.4 * (O.Calm and 0.75 or 1), { { 0, 0.2 }, { 1, 1 } }, 0.05,
				COL.Light, 0.25, 3.0)
			kick(O, F, I.C0, 0.5)
			if not O.Calm then pcall(Kit.punchNear, I.C0, T.Punch[1], T.Punch[2]) end
		end
	else
		if not I.broke then
			breakShell(O, I)
			O.Releasing = true
		end
		local e = d - T.Crack
		local relT = T.Release + 0.05
		if O.P and GEO then
			-- THE RELEASE: the violet core bursts out of the broken shell, swelling 1.8x and shrinking away
			local P = O.P
			if e < relT then
				local k = e / relT
				local csK = k < 0.45 and lerp(1.0, 1.8, easeOut(k / 0.45)) or lerp(1.8, 0.1, easeIn((k - 0.45) / 0.55))
				local core = P.Core
				local kk = math.max(0.01, csK)
				if math.abs(kk - P.CoreK) > 0.004 * kk then
					P.CoreK = kk
					core.Size = GEO.core.Size * kk
				end
				if core.Transparency ~= 0 then core.Transparency = 0 end
				bodyColor(core, P.CoreL, scaleC(COL.Dark, 0.35))
				queue(O, core, placeCF(CFrame.new(I.C) * O.rot, GEO.core.Base, kk))
				cracksDraw(O, csK * T.CoreScale, 1 - span(k, 0.55, 1.0), 3.0 * O.Ts / T.SeamHot[1])
				if P.Halo and P.HaloImg then
					spriteSet(P.Halo, P.HaloImg, P.HaloL, T.Halo[1] * 1.4 * 2, 0.8 * (1 - k), T.Halo[3])
				end
			elseif not I.released then
				I.released = true
				O.Releasing = false
				P.Core.Transparency = 1
				cracksDraw(O, 0, 0, 0)
				if P.Halo then P.Halo.Enabled = false end
			end
			for i, S in pairs(I.Shards) do shardDraw(O, I, i, S, e) end
			flush(O)
		end
		if I.CoreLight then
			local bl = T.BurstLight
			I.CoreAtt.WorldPosition = I.C
			I.CoreLight.Range = bl[2]
			I.CoreLight.Brightness = e < bl[3] and bl[1] * (1 - e / bl[3]) ^ 2 * dayK or 0
		end
	end
	stepTendrils(O, 1)
	-- the sparks come with the first bolts, not over the violet
	if not I.fired.sparks and d >= s1a then
		I.fired.sparks = true
		if d - s1a < 0.15 then
			local ground = I.Mode == "ground"
			burstFx(O, I.SparkAtt, "Impact", T.Sparks, sparkExtra(ground and 100 or 180))
			burstFx(O, I.SparkAtt, "Ember", T.Embers, {
				Color = hardCool(), Brightness = 2.5, Size = NS({ { 0, 0.24 }, { 0.6, 0.20 }, { 1, 0 } }),
				Transparency = NS({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }), Lifetime = NumberRange.new(0.6, 1.1),
				Speed = NumberRange.new(5, 12), SpreadAngle = ground and Vector2.new(100, 100) or Vector2.new(180, 180),
				Drag = 0.8, Acceleration = Vector3.new(0, -18, 0), EmissionDirection = Enum.NormalId.Top, Rate = 0,
			})
			if ground then
				local box = newHost(O, "VoltOrbSmoke", CFrame.fromMatrix(I.Floor + I.Up * 0.4, I.E1, I.Up))
				box.Size = Vector3.new(2, 0.6, 2)
				burstFx(O, box, "Smoke", T.Smoke, { Size = NS({ { 0, 1.4 }, { 1, 3.6 } }), Lifetime = NumberRange.new(1.2, 1.8) })
				burstFx(O, upAttach(I.Host, I.Floor + I.Up * 0.15, I.Up), "Dust", T.Dust,
					{ Size = NS({ { 0, 0.9 }, { 1, 2.6 } }) })
			end
			if I.Target then
				local dir = I.Target - I.C
				burstFx(O, upAttach(I.Host, I.Target, dir.Magnitude > 1e-3 and dir or I.Up), "Impact", T.HitSparks,
					sparkExtra(100))
			end
		end
	end
	-- the bolts
	drawBolts(O, I, d)
	local lastStrike = I.Strikes[#I.Strikes][2]
	-- THE AFTERGLOW (a floor burst): soot, the burned cracks cooling, the pool, the smoulder, the after-light
	if I.Mode == "ground" and d >= T.Crack then
		if I.Decal then
			local sa = span(d, T.Crack, T.Crack + T.ScorchIn) * (1 - span(d, T.ScorchHold, T.ScorchHold + T.ScorchFade))
			local tr = math.floor((1 - sa) * 100 + 0.5) / 100
			if I.Decal.Transparency ~= tr then I.Decal.Transparency = tr end
		end
		local ccol, ck
		if d < T.CrackCool[1] then
			ccol, ck = COL.Light:Lerp(COL.Base, span(d, T.Crack, T.CrackCool[1])), 1
		else
			ccol, ck = cool(span(d, T.CrackCool[1], T.CrackCool[2]))
		end
		local sl = span(d, lastStrike, lastStrike + 0.2)
		local cb = lerp(T.CrackBright[1][1], T.CrackBright[2][1], sl) * ck
		local gb = lerp(T.CrackBright[1][2], T.CrackBright[2][2], sl) * ck
		local ca = 1 - span(d, T.CrackFade[1], T.CrackFade[2])
		local rev = span(d, T.Crack, T.Crack + 0.06)
		local revK = math.floor(rev * 30 + 0.5)
		for j, line in ipairs(I.Lines or {}) do
			local Fl = I.Flats[j]
			if revK ~= I.lastRev then
				flatSet(Fl.Main, reveal(line.pts, rev), I.Up, T.CrackGlow[1], T.CrackGlow[2], 0.6)
				if Fl.Fork then flatSet(Fl.Fork, rev >= 0.5 and reveal(line.fork, (rev - 0.5) * 2) or nil, I.Up,
					T.CrackGlow[1] * 0.7, T.CrackGlow[2] * 0.7, 0.6) end
			end
			flatLook(Fl.Main, ccol, cb, gb, ca)
			if Fl.Fork then flatLook(Fl.Fork, ccol, cb, gb, ca) end
		end
		I.lastRev = revK
		if I.Pool then
			local pa = 0.9 * (1 - span(d, 0.2, T.PoolGlow[2]))
			local pc, pk
			if d < 0.3 then
				pc, pk = COL.Light:Lerp(COL.Base, d / 0.3), 1
			else
				pc, pk = cool(span(d, 0.3, 1.2))
			end
			local on = pa > 0.005 and pk > 0.01
			if I.Pool.Enabled ~= on then I.Pool.Enabled = on end
			if on then
				I.Pool.Color = CS1(pc)
				I.Pool.Brightness = 2.5 * pk * I.flatK
				I.Pool.Transparency = NSa(pa)
			end
		end
		if d < T.SmolderFor then
			if I.Smolder == nil then
				local plate = newHost(O, "VoltOrbSmolder", CFrame.fromMatrix(I.Floor + I.Up * 0.1, I.E1, I.Up))
				plate.Size = Vector3.new(4.4, 0.2, 4.4)
				I.Smolder = emitterFx(O, plate, "Ember", {
					Color = hardCool(), Brightness = 2.5, Size = NS({ { 0, 0.16 }, { 1, 0 } }),
					Transparency = NS({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }), Lifetime = NumberRange.new(0.5, 0.9),
					Speed = NumberRange.new(1.5, 4), SpreadAngle = Vector2.new(30, 30), Drag = 0.5,
					Acceleration = Vector3.new(0, 3, 0), EmissionDirection = Enum.NormalId.Top, Rate = T.SmolderRate,
				}) or false
				I.smolderAt = 0
			end
			if I.Smolder and d >= I.smolderAt then
				I.smolderAt = d + 0.1
				local V = vfx()
				if V and V.GroundSurgeRate then pcall(V.GroundSurgeRate, I.Smolder, T.SmolderRate * (1 - d / T.SmolderFor), O.Thin) end
			end
		elseif I.Smolder then
			I.Smolder.Enabled = false
			I.Smolder = false
		end
		if I.AfterLight then
			local ak = T.AfterLight
			local acol, akk = cool(span(d, 0.2, 1.2))
			I.AfterLight.Color = acol
			I.AfterLight.Brightness = ak[1] * (1 - span(d, 0.1, ak[3])) * akk * dayK
		end
	end
	-- the flash light: on at contact, held through the crack, dipped for the release, relit by strike 1, then decaying;
	-- each restrike spikes it
	if I.FlashLight then
		local fl = T.FlashLight
		local b
		if d < T.Crack then
			b = fl[1] * lerp(1.0, 0.85, d / T.Crack)
		elseif d < s1a then
			b = fl[1] * 0.3
		elseif d < s1b then
			local rl = I.ReleaseEnd
			if d < rl then
				b = fl[1] * lerp(0.3, T.Relight, ease(span(d, s1a, rl)))
			else
				b = fl[1] * lerp(T.Relight, 0.5, (d - rl) / math.max(1e-6, s1b - rl))
			end
		else
			local e = (d - s1b) / fl[3]
			b = e < 1 and fl[1] * 0.5 * (1 - e) ^ 2 or 0
		end
		for w = 2, #I.Strikes do
			local S = I.Strikes[w]
			if d >= S[1] and d < S[2] then b = math.max(b, fl[1] * 0.5 * S[3] * (1 - (d - S[1]) / (S[2] - S[1])) ^ 2) end
		end
		I.FlashLight.Brightness = b * dayK * calmK
	end
	-- the bolts' own lights where they land: on with strike 1, re-lit by each restrike, held through the gaps,
	-- outlasting the last bolt by BoltLight's seconds
	if #I.BoltLights > 0 then
		local bl = T.BoltLight
		local lk = 0
		for w, S in ipairs(I.Strikes) do
			if d >= S[1] and d < S[2] then
				lk = math.max(lk, S[3] * (0.85 + 0.15 * Random.new(math.floor(d / T.Reroll) * 3 + w):NextNumber()))
			end
		end
		if d >= s1a and d < lastStrike then
			lk = math.max(lk, 0.55)
		elseif d >= lastStrike then
			local e2 = (d - lastStrike) / bl[3]
			lk = e2 < 1 and 0.55 * (1 - e2) ^ 1.5 or 0
		end
		if d >= s1a and d < s1a + T.BoltReveal then lk *= span(d, s1a + 0.4 * T.BoltReveal, s1a + T.BoltReveal) end
		for _, L in ipairs(I.BoltLights) do L.Brightness = bl[1] * lk * dayK * calmK end
	end
	-- the full Bloom kick as the violet release ends (strike 1's bolts still at full)
	if not I.fired.bloom and d >= I.ReleaseEnd then
		I.fired.bloom = true
		if d - I.ReleaseEnd < 0.1 then kick(O, F, I.C, 1) end
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- the fizzle, and the one step for every live orb
----------------------------------------------------------------------------------------------------
fizzleOrb = function(O, at)
	if O.dead or O.Fizz or O.I then return end
	if O.Character then
		if pending[O.Character] == O then pending[O.Character] = nil end
		if flying[O.Character] == O then flying[O.Character] = nil end
	end
	local pos = at or O.DrawC
	if not pos then                                   -- never drawn: nothing to pop
		destroyOrb(O)
		return
	end
	O.Fizz = { t = 0, at = pos, s = O.s or 1 }
	local V = vfx()
	if V and V.VoltSparkBurst then pcall(V.VoltSparkBurst, pos, Vector3.yAxis, O.Thin, 5) end
	O.Hand.CFrame = CFrame.new(pos)
	spriteFx(O, O.HandAtt, 0.4 * O.Fizz.s, 1.1 * O.Fizz.s, { { 0, 0.3 }, { 1, 1 } }, 0.08, COL.Light, 0.25, 2.5)
	if O.OrbLight then O.OrbLight.Brightness = 0 end
	if O.CoreLight then O.CoreLight.Brightness = 0 end
	for _, td in ipairs(O.tendrils) do td.life = 0 end
	endWindup(O)
end

local function stepFizzle(O, F, dt)
	local z = O.Fizz
	z.t += dt
	local k = 1 - span(z.t, 0, 0.08)
	if k <= 0.02 or not z.at then return false end
	drawOrb(O, F, O.DrawC or z.at, math.max(0.02, z.s * k), 0, nil, 0, 0, dt, T.Spin[1], 0, nil)
	stepTendrils(O, z.s)
	return true
end

local F = {}

local function stepOne(O)
	if O.dead or not O.Folder.Parent then return false end
	local dt = math.clamp((F.os - O.LastOs) * F.ts, 0, 0.1)
	O.LastOs = F.os
	O.Ts = F.ts
	O.lt = (F.now - O.T0w) * F.ts
	if O.Fizz then return stepFizzle(O, F, dt) end
	if O.I then return stepImpact(O, F, dt) end
	return stepOrb(O, F, dt)
end

stepAll = function()
	if not next(live) or not Kit then
		unbind()
		return
	end
	F.now = Kit.serverNow()
	local okTs, ts = pcall(Kit.timeScale)
	F.ts = (okTs and type(ts) == "number" and ts > 0) and ts or 1
	F.os = os.clock()
	local cam = workspace.CurrentCamera
	F.cam = cam
	F.eye = cam and cam.CFrame.Position or nil
	local okDay, day = pcall(Kit.daylight)
	F.dayK = (okDay and day) and 0.5 or 1
	F.fist = nil
	local _, VM = Kit.libs()
	if VM and VM.GetFistCFrame then
		local ok, cf = pcall(VM.GetFistCFrame, "R")
		if ok and typeof(cf) == "CFrame" then F.fist = cf end
	end
	for O in pairs(live) do
		local ok, keep = pcall(stepOne, O)
		if not ok then
			warnOnce("step", "a Volt Orb frame failed; that orb was removed: " .. tostring(keep))
			destroyOrb(O)
		elseif not keep then
			destroyOrb(O)
		end
	end
	if not next(live) then unbind() end
end

----------------------------------------------------------------------------------------------------
-- THE API (CONTRACT section 6)
----------------------------------------------------------------------------------------------------
local function ready()
	if not RunService:IsClient() then return false end
	local K = kit()
	if not K then return false end
	buildGeo()
	textures()
	return true
end

--- The orb forming in `character`'s right hand: 0-0.31 s (arcs reeled in, the kernel, the core growing, the plates
--- flying in and locking, the palm light), then held formed until its VoltOrbThrow adopts it. opts.Own: the local
--- caster's own cast (the first-person stand-in); opts.T0: the press in server time. Returns the handle
--- ({ Stop, Destroy, Character }), or nil.
function VoltOrbFX.Windup(character, opts)
	if typeof(character) ~= "Instance" or not ready() then return nil end
	opts = type(opts) == "table" and opts or {}
	local old = pending[character]
	if old then destroyOrb(old) end
	local own = opts.Own == true
	if not own then
		local ok, v = pcall(Kit.isOwn, character)
		own = ok and v == true
	end
	local O = newOrb(character, { Own = own, T0 = tonumber(opts.T0) or Kit.serverNow() })
	pending[character] = O
	return O.Handle
end

--- VoltOrbThrow: the flight. Adopts this caster's windup if one is in the hand; otherwise makes the orb, its windup
--- drawn from the cast's T0 (skipping ahead by however late this arrived).
function VoltOrbFX.Throw(data)
	if type(data) ~= "table" or not ready() then return nil end
	local c = data.Character
	if typeof(c) ~= "Instance" or typeof(data.From) ~= "Vector3" or typeof(data.Vel) ~= "Vector3" then return nil end
	local now = Kit.serverNow()
	local okTs, ts = pcall(Kit.timeScale)
	ts = (okTs and type(ts) == "number" and ts > 0) and ts or 1
	local th = {
		From = data.From, Vel = data.Vel,
		Gravity = tonumber(data.Gravity) or T.Gravity, Fuse = tonumber(data.Fuse) or T.Fuse,
	}
	th.ReleaseAt = tonumber(data.ReleaseAt) or ((tonumber(data.T0) or now) + (T.Windup + T.Throw) / ts)
	if (now - th.ReleaseAt) * ts > th.Fuse + T.Linger then return nil end   -- long over: draw nothing stale
	local O = pending[c]
	if O and (O.dead or O.Throw or O.Fizz or O.I) then O = nil end
	if O then
		pending[c] = nil
	else
		local okOwn, own = pcall(Kit.isOwn, c)
		O = newOrb(c, { Own = okOwn and own == true, T0 = tonumber(data.T0) or (th.ReleaseAt - (T.Windup + T.Throw) / ts),
			Seed = tonumber(data.Seed) })
	end
	-- one live orb per caster (the server fizzles the old one; an old flight still drawn here goes quietly)
	local prev = flying[c]
	if prev and prev ~= O and not prev.I then destroyOrb(prev) end
	flying[c] = O
	O.Throw = th
	O.LastPos = th.From
	return O.Handle
end

--- VoltOrbBurst: the impact at data.At on its own clock from data.T0. Carries on from this caster's orb when it is
--- drawn here; otherwise (a late client) the formed orb appears at At and breaks.
function VoltOrbFX.Burst(data)
	if type(data) ~= "table" or typeof(data.At) ~= "Vector3" or not ready() then return nil end
	local now = Kit.serverNow()
	local okTs, ts = pcall(Kit.timeScale)
	ts = (okTs and type(ts) == "number" and ts > 0) and ts or 1
	local T0 = tonumber(data.T0) or now
	if (now - T0) * ts >= T.End - 0.05 then return nil end
	local c = typeof(data.Character) == "Instance" and data.Character or nil
	local O = c and (flying[c] or pending[c]) or nil
	if O and (O.dead or O.I or O.Fizz) then O = nil end
	if O then
		if flying[c] == O then flying[c] = nil end
		if pending[c] == O then pending[c] = nil end
		endWindup(O)
	else
		O = newOrb(c, { Own = false, T0 = T0 - 10, Late = true, At = data.At })
		O.DrawC, O.s = data.At, 1
		O.windupDone = true
	end
	startImpact(O, data, T0)
	return O.Handle
end

--- VoltOrbFizzle: a small pop and the orb is gone. With At (it had been thrown) the flying orb is the one meant;
--- without, the one in the hand. With no orb drawn here, just the pop at At.
function VoltOrbFX.Fizzle(data)
	if type(data) ~= "table" or not ready() then return end
	local c = typeof(data.Character) == "Instance" and data.Character or nil
	local at = typeof(data.At) == "Vector3" and data.At or nil
	local O = nil
	if c then
		if at then
			O = flying[c] or pending[c]
		else
			O = pending[c] or flying[c]
		end
	end
	if O and not O.I and not O.dead then
		fizzleOrb(O, at)
		return
	end
	if at then
		local V = vfx()
		local okThin, thin = pcall(Kit.thin, c)
		if V and V.VoltSparkBurst then pcall(V.VoltSparkBurst, at, Vector3.yAxis, okThin and thin, 5) end
	end
end

--- EXTRA (the harness's one-face check, design step 6.1): which attachment axis a FaceCamera=false Beam's ribbon faces,
--- "Y" or "Z". Rebuilds the template; orbs already drawn keep theirs.
function VoltOrbFX.SetRibbonNormal(axis)
	if axis ~= "Y" and axis ~= "Z" then return false end
	if T.RibbonNormal == axis then return true end
	T.RibbonNormal = axis
	if TEMPLATE then TEMPLATE.Model:Destroy() end
	TEMPLATE = nil
	templateRetry = 0
	if GEO then GEO.facets = {} end
	return true
end

return VoltOrbFX
