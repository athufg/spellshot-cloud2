--[[
	OverchargeFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/OverchargeFX

	Overcharge (Voltaic's Primary: an 11-stud dash in 0.16 s, then the next M1 is primed), RE-LIT (2026-09-26). The
	Roblox port of blender_scripts/voltaic/overcharge_bl.py, pass 4 (its T table, launch_frame, plan_streak /
	streak_frame, land_frame, Route / plan_tendrils / route_at / pulse_bump / drift_at / tendril_world / draw_tendril,
	strand_path and release_frame) and of vfx_blocking/voltaic/OVERCHARGE_showcase.md. It replaces the comic v2 build
	whole: no kit meshes and no VFXLibrary emitters. Every element is light, drawn with ChainBoltFX's toolkit.

	THE LAYERING (the showcase's beam(), per arc). A CORE BeamChain on every point of the jagged path (VT_VoltOrb_Core,
	Light, LightEmission 1) and a GLOW BeamChain on every gstep-th point (VT_VoltOrb_Glow, Base, LightEmission 0.55,
	0.85 opacity, its ends pushed 35 % of its width past the core's). The tendrils add a HAZE on the glow's points
	(3x its width, LightEmission 0.35, 0.30 of the glow's opacity). Per point: widths, Transparency ('k') and colour
	toward white ('wh'). A dying arc is an EMBER: a Dark core with a faint #7A4AD0 halo. A joint that turns more than 60
	degrees on screen breaks, keeping 85 % of its width, under a soft round cap. Glow sprites are camera-facing Beam
	quads (SOFT_TEX). Light on the world: PointLights and, for the caster alone, Bloom kicks.

	THE BEATS, in SHOT time from this client hearing the Overcharge broadcast (the dash's first frame). Shot time is
	Kit.clock (real seconds x ShotTimeScale). A "frame" is one 60 Hz game frame, and every drawn state changes on it.
	  1 LAUNCH   0.000-0.050  10 arcs out of the body's surface at the start point, x1.15 on the press frame, then x0.55
	                          and detached, then violet embers, then gone. A chest glow (frame 0, ZOffset 2.5), a flash
	                          light 7 / 14 (then x0.10 at Range 3.5, 1.5 studs BEHIND the start point, then off), and Bloom.
	  2 STREAK   0.017-0.217  Two short jagged fragments a frame (one on the arrival frame), 40 % stood across the path as
	                          rungs, at the silhouette's heights, within 0.3 of its line. Each lives 3 frames: full; x0.6
	                          wide at half brightness; ember. Every fragment's whole extent sits 0.3 studs behind the
	                          rearmost limb along the dash axis: the caster's own real parts on its own client, else the
	                          body placed from the broadcast's From / To at the live dash's constant speed.
	  3 LANDING  0.167-0.263  7 floor arcs ahead of the feet (Brightness 4), 2 frames then embers. A floor flash 5 / 9 at
	                          foot + dir + 0.3 up, and Bloom. Two arcs run out to the sides: the tendrils climb out of their
	                          tips (36 / 64 / 84 / 96 % of the climb over frames 10-13).
	  4 PRIMED   0.233 -> the M1   One tendril per arm, shoulder -> hand. Each is a Route (6 control points round the arm
	                          axis, jagged, a primary fork, a twig and 4 prongs at the hand) that DRIFTS (one phase per side),
	                          CRAWLS toward the hand, CRACKLES every frame, SNAPS every 0.10-0.22 s from a shuffled bag (the
	                          sides never within 2 frames; the old route as a one-frame ember) and PULSES shoulder -> hand
	                          (0.32-0.50 s on the right side's clock, the left half a period behind). A hand glow swells
	                          with the pulse, and there is a PointLight per tendril. No countdown. It still ends on
	                          PrimedFor: the watchdog, 6.45 s after the last On.
	  5 RELEASE  M1 +0 / +1   Frame 0: the frozen routes as violet embers riding the arm now, two gather arcs converging
	                          on the hand, the hand flare. Frame 1: two strands at half brightness to 55 % of the bolt and
	                          one comet head, no round glow. Nothing from frame 2: the hit is Chain Bolt's plain one.
	Placement: the dash beats come from the broadcast (From / To, floors found once). The tendrils ride the REAL rig every
	frame. The showcase's arm (shoulder (1.5, 3.75), elbow 1.10 below, hand tip 2.47) is mapped piecewise onto R15's
	UpperArm / LowerArm (R6: the Arm): shoulder = the upper arm's top, hand = Kit.hands' grip. Points above the shoulder
	stay in the root's frame. An observer's tendrils start on the broadcast's To and settle onto the replicated body
	over 0.25 s (it lags a 0.16 s move).

	API (the contract of the comic build, kept; plus Release).
	  Cast(data)        The Overcharge broadcast { Character, From, To, T0 } (From / To are the root's start and end). T0
	                    only drops a stale one. Own = true marks VoltaicClient's own predicted dash, which owes no local
	                    tell. Everyone else's owes one at TellDelay (0.23) unless SetPrimed(Character, false) comes first.
	                    At the landing frame it starts the climb as an UNCONFIRMED tell. That tell lapses at
	                    max(TellDelay, 0.233) + Hold unless SetPrimed(Character, true) confirms it.
	  SetPrimed(c, on)  on = true confirms the climbing tell, re-confirms a live one (the watchdog restarts) or starts
	                    one whole. An On within OffGuard of this client's own Off (and no newer cast) is ignored.
	                    on = false ends it: the M1, the ChainBolt broadcast, OverchargePrimed Off, a loadout change.
	  IsPrimed(c)       Whether a confirmed tell is up.
	  Release(character, side, fromPos, points, opts)   The primed shot's release. Call it BEFORE SetPrimed(c, false):
	                    it freezes the tell's routes. side "R" / "L" (L mirrors the gather). fromPos is the firing hand
	                    (nil: Kit.muzzle). points = the ChainBolt Points (Points[1] = A or End). opts: T0 (drops a stale
	                    broadcast), End. It draws only its own layers; ChainBoltFX draws the bolt. Returns a handle, or
	                    nil when there is no tell and this client already ended the prime since the last cast it heard
	                    (a second M1 inside the round trip, while VoltPrimedUntil still reads true).
	  Clear()           EXTRA: destroys everything in flight.
	First person (not built in the showcase; chosen here, tuned in Studio 2026-09-26): your own tendrils ride the
	Viewmodel's forearms (Kit.castPoint) at FpScale 0.45, only their forearm half, on the forearm's surface (FpLateral),
	thin (FpWidth), with the prongs at half length (FpProng: past the fist is into the view) and the hand glow. There
	is no climb, no haze, no fork, no micro-arc and no light there, and the landing arcs fade near the lens. The
	release's flare is x0.45, with embers on the forearms and no gather arcs.

	SETTINGS.
	  * Reduce Flashing: every Beam x0.85 (CalmBeam); flashes x0.6, eased in; no Bloom; the slow snap bag (0.20-0.40 s)
	    whose snaps DISSOLVE (the old route at 50 % for a frame, not an ember); crackle and micro-arcs halved; no snap flash;
	    (2026-10-19, audit P5D-04) a steady tendril Brightness (no per-frame Flicker) and the pulse's whitening halved.
	  * Thin (Kit.thin: Reduce Enemy VFX, low quality): 5 launch arcs, 4 landing arcs, one streak fragment a frame and no
	    forks; the tendrils lose the haze, the micro-arcs and every minor light (dash, tendrils, climb), run at jag
	    depth 1 (one sub-point a span: 11 main points, not 21; the forks one level shallower; showcase flag 7) and
	    crackle at 30 Hz. The tendrils themselves are NEVER dropped: they are the opponent's warning.
	  * Flat-lit maps: BeamChain tones its own Beams down; the sprites are emission x0.35 / Brightness x0.7; no
	    PointLights (Kit.light returns nil).
	  * Daylight (Kit.daylight): every glow and haze Brightness x1.8 (DayGlow); every PointLight x0.5 (Kit.light).

	BUDGET (visible Beams: this port draws the showcase's beam() layers one for one; each chain's unused layer is
	unparented). Hold, both tendrils: about 143 (core 84, glow 43, haze 14, embers about 2), 173 on a snap frame. Plus 10
	sprite quads (2 hand glows, 8 soft caps), the break caps, and 2 PointLights. Thin: about 86 + 10 quads, no lights
	(core about 52, glow about 32, embers about 2).
	Launch: 162 for 3 frames (194 with the streak's first fragments). Streak: about 80. Landing: 84 for 2 frames (175
	with the climb). Release: 78 on the flare frame (embers 54, gather 24) and 71 on the comet frame (strands 59,
	comet 12). Lights at once: at most 4 in the dash, 1 at the release.

	DEVIATIONS from the showcase.
	  1 The glow sprites are Beam quads, not ParticleEmitters: they change Size and Brightness every frame and must
	    vanish on an exact frame. The showcase's ZOffset is done in the placement (the same push toward the eye at
	    constant screen size).
	  2 Random draws are per cast (seeded from T0 and the caster, so every client draws one cast alike). The showcase's
	    fixed seeds made one fixed look.
	  3 Bloom kicks only for the caster's own dash (ChainBoltFX's rule; every player's dash blooming everyone's screen is
	    noise). The frame-0 launch light sits 0.6 toward the viewer (the showcase's +z faced its side camera). The
	    caster's own first-person view skips the chest glow (it would sit on the lens) and fades each launch arc by its
	    nearest point to the camera (gone within 1.5 studs, whole past 3), the comic build's proximity fade on Beams.
	  4 Observers' streak clearance uses the showcase figure's own rear offset (1.0 standing -> 1.68 swept), measured
	    back from the body placed LINEARLY over Time (the live DashMotor speed), not on the showcase's easeOutQuad
	    stand-in, which runs up to ~2.8 studs ahead of the real body. A wall-shortened dash arrives early; the linear
	    curve then lags it, so the fragments only sit further back. The dash light rides the same curve (and, on the
	    caster's own client, never ahead of its real root minus 1.5).
	  5 The climb is an unconfirmed tell from the landing frame (0.167), because the live TellDelay is 0.23. For the
	    caster, if its own Overcharge broadcast comes back later than TellDelay (ping > ~0.2 s), the climb lapses at
	    0.283 and the tell returns whole when the broadcast arrives.
	  6 Release: ChainBoltFX's jittered leg-1 points cannot be read, so the strands and the comet lie on the STRAIGHT
	    hand -> Points[1] line. The head is at the middle of the 4th of 6 equal parts (0.583): the "mid-segment holding
	    55 %" rule on a 6-segment bolt. An M1 before 0.233 draws the flare only (showcase flag 4). A whiff runs the
	    strands to End.
	  7 The ember halo uses the glow texture at LightEmission 0.55 (the showcase's ember material was 0.5).
	  8 Tendril widths are in studs, not scaled by avatar size (their placement is).

	FLAGS (the owner's to check in Studio).
	  1 SOFT_TEX: VT_Overcharge_Soft is uploaded (rbxassetid://130067461865773); nil falls back to Kit.Tex.Implosion.
	  2 Compiled with Studio's own compiler on 2026-09-26 (luau_compile_check.py): OK.
	  3 A shot the server refuses (its prime cleared, no bolt) gets no collapse: the tell ends on OverchargePrimed Off.
	  4 First person is this port's own design (above), to be judged in play.
	  5 The strands and the comet do not sit on Chain Bolt's zigzag (deviation 6).
	  6 The caster's climb shows before the server has accepted the dash (4 frames), so a refused dash shows them.
	  7 The hold is heavy for a per-player effect (showcase flag 7); the pulse rewrites Beam sequences as it passes.
	  8 The buff reads untimed, but the live 6 s PrimedFor cap still ends it (showcase flag 1).
	  9 The Viewmodel frame is assumed from Viewmodel.lua: CastPoint 0.05 past the fist tip, LookVector along the forearm.

	PLUMBING (ChainBoltFX's). Nothing happens at require time. VoltaicKit and VoltaicTuning are required lazily, with
	timed waits, on the first call. One BindToRenderStep runner at RenderPriority.Last (after the camera and the
	Viewmodel) steps every dash, tell and release, each in a pcall. A frame that errors clears its object. Every object
	has a watchdog deadline, and dashes and releases a Debris backstop. The BeamChains and sprite quads are POOLED; an
	idle piece is parented to nil. On the server every public function is a no-op.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local OverchargeFX = {}

-- VT_Overcharge_Soft (export/voltaic/VT_Overcharge_Soft.png), uploaded 2026-09-26. nil would draw with VoltaicKit.Tex.Implosion.
local SOFT_TEX = "rbxassetid://130067461865773"

----------------------------------------------------------------------------------------------------
-- The numbers: overcharge_bl.py's T, pass 4. Seconds of SHOT time; a "frame" is one 60 Hz game frame. EVERY NUMBER IS
-- A PROPOSAL (2026-09-25). DashTime / TellDelay / Watchdog are replaced by VoltaicTuning.Overcharge's Time / TellDelay /
-- Watchdog when that module loads.
----------------------------------------------------------------------------------------------------
OverchargeFX.Tuning = {
	-- the live rules
	DashTime = 0.16,               -- 11 studs at one constant speed (DashMotor's LinearVelocity; the mechanic, unchanged)
	TellDelay = 0.23,              -- the local tell's confirmation after the dash (the server's OverchargePrimed rule)
	Watchdog = 6.45,               -- the 6 s PrimedFor cap + 0.45: a confirmed tell ends this long after its last On
	Stale = 1.0,                   -- a broadcast older than this (by its server T0) draws nothing
	OffGuard = 0.5,                -- an On this soon after this client's own Off (and no newer cast) is ignored
	HandRetry = 0.25,              -- real seconds between looks for a missing hand
	HandSlack = 12,                -- studs: a hand further than this from the release's fromPos is not trusted
	Hold = 0.05,                   -- an unconfirmed climb stays up this long past max(TellDelay, grown)
	Settle = 0.25,                 -- after the landing: an observer's tendrils slide from To onto the replicated body
	StreakRear = { 1.0, 1.68 },    -- observers: studs from the body back to its rearmost limb, standing / swept
	Recover = 0.10,                -- the showcase figure standing back up after the arrival
	MaxLife = 1.2,                 -- the watchdog on a dash or a release

	-- 1 LAUNCH
	LaunchArcs = 10, ThinLaunchArcs = 5,
	LaunchLen = { 1.4, 2.5 },      -- studs, from the body's surface (+0.4) to the tip
	LaunchForward = 0.55,          -- no arc points further forward than this (cos)
	LaunchFork = 0.45,             -- share of arcs with a fork
	LaunchArc = { 0.10, 0.85, 3.6, 1.5 },   -- core width, glow width, core Brightness, glow Brightness
	LaunchFade = { 1.15, 0.55 },   -- x brightness on frames 0 / 1; frame 2 is the ember
	LaunchDetach = { 0.0, 0.40, 0.70 },     -- share of each arc gone from its root, frames 0 / 1 / 2
	LaunchReach = { 1.0, 1.15, 1.28 },      -- x its length the tip has flown out to
	Chest = 2.9,                   -- studs above the floor
	LaunchGlow = { 1.1, 2.0, 2.5 },         -- the chest glow on frame 0: Size, Brightness, ZOffset
	LaunchFlash = { 7.0, 14.0, 3.5 },       -- Brightness, Range on the press frame, Range after
	LaunchFlashK = { 1.0, 0.10, 0.0 }, CalmLaunchFlashK = { 0.5, 0.10, 0.0 },
	LaunchBloom = { 0.45, 0.10, 0.05 },     -- Intensity +, Size +, tau

	-- 2 DASH STREAK
	StreakLen = { 0.6, 1.1 }, RungLen = { 0.5, 0.8 },
	StreakRung = 0.40,             -- share stood across the path
	StreakBehind = 0.40,           -- studs behind the body's back
	StreakBands = { 0.95, 1.9, 2.8, 3.6, 4.55 },   -- knee, hip, chest, shoulder, head
	StreakSide = 0.30,
	StreakArc = { 0.055, 0.50, 3.2, 1.8 },
	StreakMid = { 0.60, 0.50 },    -- the middle frame: width x, Brightness x
	DashLight = { 0.9, 4.0 },      -- 1.5 behind the body at knee height

	-- 3 LANDING
	LandArcs = 7, ThinLandArcs = 4,   -- 2 of them the tendrils' roots
	LandReach = { 1.7, 2.2 }, LandSpread = 110,
	LandArc = { 0.075, 0.60, 4.0, 1.4 },
	LandFade = { 1.0, 0.55 },
	LandFlash = { 5.0, 9.0, 0.08 },
	LandBloom = { 0.25, 0.06, 0.04 },
	Grow = 4 / 60,                 -- the climb: whole at 0.233

	-- 4 PRIMED
	Tendril = { 0.075, 0.62, 3.2, 1.25 },   -- core width, glow width, core Brightness, glow Brightness
	Haze = 3.0,                    -- the haze's width, x the glow's
	Fork = { 0.050, 0.42 },        -- a twig's / prong's core and glow width
	Radius = 0.78, KeepOut = 0.62, GlowOff = 0.12,
	SnapBag = { 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22 },
	CalmSnapBag = { 0.20, 0.24, 0.28, 0.32, 0.36, 0.40 },
	SnapApart = 2,                 -- frames: the two sides never snap closer than this
	SnapBoost = 1.22, Ember = 0.40,
	Drift = { 55.0, 1.1, 0.12, 0.9 },       -- degrees (period s), studs up/down (period s)
	DriftPhase = { R = { 0.4, 2.1 }, L = { 2.9, 0.7 } },
	Crawl = { 2.0, 0.45 },         -- studs/s toward the hand, capped
	Crackle = 0.045, Flicker = 0.08,
	PulseEvery = { 0.32, 0.50 }, PulseTravel = 0.14, PulseGlow = 1.0, PulseWhite = 0.85, PulseCore = 0.6,
	MicroArcs = { 0.35, 0.45, 0.20 },       -- chance of 0 / 1 / 2 micro-arcs per tendril per frame
	MicroLen = { 0.22, 0.50 },
	MicroArc = { 0.032, 0.22, 2.4, 1.0 },
	TendrilLight = { 2.2, 6.5 },   -- PointLight per tendril (Brightness, Range)
	HandGlow = { 0.30, 0.9, 0.8 }, -- Size, Brightness, ZOffset
	FpScale = 0.45,                -- first person: the tendril's scale on the Viewmodel's forearm
	-- first person, measured in Studio 2026-09-26: the forearm is 1-1.8 studs from the lens, so at FpScale alone the
	-- showcase's spread round the arm and its glow filled half the screen. Off-axis offsets and widths are cut further.
	FpLateral = 0.70,              -- x FpScale: the route's offsets round the forearm axis (0.25 studs: on the
	                               -- Viewmodel forearm's surface -- its block is 0.38 x 0.31; nearer, the arm hides it)
	FpProng = 0.5,                 -- first person: the share of each hand prong drawn (past the fist is INTO the view)
	FpWidth = 0.22,                -- the core / glow / prong / hand-glow widths (instead of FpScale)
	FpFrom = 2.75,                 -- ...drawn below this height of the showcase's arm (its forearm half)

	-- 5 RELEASE
	HandFlare = { 0.80, 2.6, 0.8 },         -- Size, Brightness, ZOffset
	EmberGather = 0.70,
	Comet = { 0.55, 0.16, 0.20, 0.95 },     -- head at this share, its length (share), core / glow width at the head
	StrandR = { 0.45, 0.15 },      -- studs off the spine: full (15 % down), at A; 0 at the palm
	StrandTurns = 1.25,
	BoltSegs = 6,                  -- the placeholder bolt's segments (Chain Bolt's leg 1: 5 kinks)

	-- settings
	CalmFlash = 0.6, CalmBeam = 0.85, DayGlow = 1.8,
}
local T = OverchargeFX.Tuning

local F = 1 / 60
local TOL = 0.25 / 60              -- a quarter frame: "on this frame" against float drift in the clock
local FRAME_TOL = 0.25
local GLOW_ALPHA = 0.85            -- VoltaicFX's GLOW_ALPHA (= BeamChain's GlowAlpha)
local HAZE_SHARE = 0.30            -- the haze's opacity, x the glow's
local HAZE_LE = 0.35
local EMBER_HALO = Color3.fromRGB(122, 74, 208)
local WHITE = Color3.new(1, 1, 1)
local FLAT_EMISSION, FLAT_BRIGHTNESS = 0.35, 0.7
local S0X, S0Y = 1.5, 3.75         -- the showcase's resting shoulder (body-local, studs above the feet)
local UP_LEN, LO_LEN = 1.10, 1.37  -- its arm: shoulder -> elbow, elbow -> hand tip
local RIDE_TOP, RIDE_BLEND = 3.95, 0.45   -- to_world(): points below RIDE_TOP ride the arm, fully RIDE_BLEND lower
local ELBOW_BLEND = 0.25           -- studs of the showcase arm either side of the elbow over which the frames blend
local SHOULDER_DROP = 0.22         -- the showcase's shoulder sits this far below the arm's top
local ROUTE_N = 6
local CLASSES = { 2, 4, 8, 12, 16, 24, 32, 48 }
local POOL_CAP, SPRITE_POOL_CAP = 24, 40
local SHIFTS = { 1, -1, 2, -2, 3, -3, 4, -4 }
local SIGNS = { 1, -1 }
local RUNNER = "SpellshotOverchargeFX"

----------------------------------------------------------------------------------------------------
-- plumbing: lazy requires (nothing at load)
----------------------------------------------------------------------------------------------------
local Kit, COL, VFXLibrary, TUN, SOFT, LOOKS = nil, nil, nil, nil, nil, nil
local retryAt = 0
local warned = {}

local function warnOnce(key, msg)
	if Kit and Kit.warnOnce then
		Kit.warnOnce("OverchargeFX:" .. key, "[OverchargeFX] " .. msg)
		return
	end
	if warned[key] then return end
	warned[key] = true
	warn("[OverchargeFX] " .. msg)
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

-- the chain kinds: core (glow layer unparented), glow (core layer unparented), halo (its core layer re-textured as the
-- haze); a P kind is painted per segment (the showcase's per-point k / wh)
local SPARE = { core = "Glow", coreP = "Glow", glow = "Core", glowP = "Core" }
local PAINTED = { coreP = true, glowP = true, haloP = true }

local function buildLooks()
	local base = { BreakWidth = 0.85, CapTexture = SOFT, CapScale = 1.1, CapBright = 0.5, Name = "OverchargeChain" }
	local core = table.clone(base)
	core.Caps = false
	local halo = table.clone(base)
	halo.CoreTexture = Kit.Tex.Glow
	halo.CoreEmission = HAZE_LE
	halo.CoreZ, halo.GlowZ = 0, 0.01
	halo.GlowAlpha = 1 / HAZE_SHARE          -- Look's alpha is the haze's opacity; the glow's is 1 / 0.30 of it
	LOOKS = { core = core, coreP = core, glow = base, glowP = base, halo = halo, haloP = halo }
end

--- Loads VoltaicKit (required) and VoltaicTuning (optional) once. False while the kit is missing.
local function libs()
	if Kit then return true end
	if os.clock() < retryAt then return false end
	local k = requireIce("VoltaicKit", 3)
	if not (k and k.BeamChain and k.clock and k.host and k.light and k.jag and k.Tex) then
		retryAt = os.clock() + 5
		warnOnce("kit", "IceMagic.VoltaicKit is missing or failed to load: Overcharge draws nothing until it is back")
		return false
	end
	Kit, COL = k, k.COL
	SOFT = SOFT_TEX or k.Tex.Implosion
	local ok, v = pcall(k.libs)             -- warm the kit's own lazy requires here, where a timed wait may yield
	VFXLibrary = ok and v or nil
	local tuning = requireIce("VoltaicTuning", 2)
	if type(tuning) == "table" and type(tuning.Overcharge) == "table" then
		TUN = tuning.Overcharge
	else
		warnOnce("tuning", "IceMagic.VoltaicTuning.Overcharge is missing: using Time 0.16, TellDelay 0.23, Watchdog 6.45")
	end
	buildLooks()
	return true
end

local function tun(key, fallback)
	local v = TUN and TUN[key]
	return (type(v) == "number" and v > 0) and v or fallback
end

-- The kit's settings reads, never allowed to break a frame
local function kitFlag(fn, ...)
	if not fn then return false end
	local ok, v = pcall(fn, ...)
	return ok and v == true
end

----------------------------------------------------------------------------------------------------
-- small maths
----------------------------------------------------------------------------------------------------
local function lerp(a, b, u) return a + (b - a) * u end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end       -- the showcase's ease()
local function easeOutQuad(u) u = clamp01(u) return 1 - (1 - u) * (1 - u) end

local function safeUnit(v, fallback)
	local m = v.Magnitude
	if m > 1e-6 then return v / m end
	return fallback
end

local function perpAny(a)
	local p = a:Cross(Vector3.yAxis)
	if p.Magnitude < 1e-4 then p = a:Cross(Vector3.xAxis) end
	return p.Unit
end

--- A random direction square to `d` (the showcase's perp()).
local function perpRand(d, rng)
	local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local p = r - d * r:Dot(d)
	if p.Magnitude > 1e-4 then return p.Unit end
	return perpAny(d)
end

local function towardCamH(p, camPos, dist)
	local d = camPos - p
	d = Vector3.new(d.X, 0, d.Z)
	return d.Magnitude > 1e-3 and d.Unit * dist or Vector3.zero
end

local function arclen(pts)
	local acc = table.create(#pts)
	acc[1] = 0
	for i = 2, #pts do acc[i] = acc[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	return acc
end

--- The polyline between arc lengths s0 < s1, its ends interpolated: (points, their arc lengths).
local function cutPath(pts, acc, s0, s1)
	if s1 - s0 < 1e-5 or #pts < 2 then return {}, {} end
	local function at(s)
		for i = 2, #acc do
			if s <= acc[i] + 1e-9 then
				local seg = acc[i] - acc[i - 1]
				local u = seg < 1e-9 and 0 or (s - acc[i - 1]) / seg
				return pts[i - 1]:Lerp(pts[i], u)
			end
		end
		return pts[#pts]
	end
	local out, ss = { at(s0) }, { s0 }
	for i = 1, #pts do
		if s0 + 1e-6 < acc[i] and acc[i] < s1 - 1e-6 then
			out[#out + 1] = pts[i]
			ss[#ss + 1] = acc[i]
		end
	end
	out[#out + 1] = at(s1)
	ss[#ss + 1] = s1
	return out, ss
end

--- Width per point: `taper` of it lost down the run, `tip` of it at both free ends (Width0 / Width1 of the end Beams).
local function endsProfile(n, w, taper, tip)
	local out = table.create(n)
	for i = 1, n do
		local u = n > 1 and (i - 1) / (n - 1) or 0
		out[i] = (i == 1 or i == n) and w * tip or w * (1 - taper * u)
	end
	return out
end

--- The glow's attachments: every gstep-th point, and the last.
local function thinIdx(n, gstep)
	local idx = {}
	for i = 1, n, gstep do idx[#idx + 1] = i end
	if (n - 1) % gstep ~= 0 then idx[#idx + 1] = n end
	return idx
end

local function shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function sample(list, n, rng)
	local c = shuffle(table.clone(list), rng)
	local out = table.create(n)
	for i = 1, n do out[i] = c[i] end
	return out
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

local function seedFrom(t, model)
	local s = math.floor((tonumber(t) or os.clock()) * 1000) % 1000000
	if typeof(model) == "Instance" then
		local name = model.Name
		for i = 1, math.min(#name, 24) do s = (s * 31 + string.byte(name, i)) % 1000003 end
	end
	return s + 1
end

local function alive(character)
	if not (character and character.Parent) then return false end
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum == nil or (hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead)
end

local function bodyPart(character, name)
	local p = character:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end

--- Studs from a character's root down to its feet (R15: HipHeight + half the root; else 3).
local function rootDrop(character)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and bodyPart(character, "HumanoidRootPart")
	if hum and root and hum.RigType == Enum.HumanoidRigType.R15 then return hum.HipHeight + root.Size.Y / 2 end
	return 3
end

local function firstPersonNow()
	local lp = Players.LocalPlayer
	if lp and lp.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
	return kitFlag(Kit.viewmodelUp)
end

----------------------------------------------------------------------------------------------------
-- the pools: BeamChains (by kind and size) and sprite quads. An idle piece is parented to nil.
----------------------------------------------------------------------------------------------------
local chainPool = {}    -- [kind] = { [class] = { entry } }
local spritePool = {}

local function classFor(nseg)
	for _, c in ipairs(CLASSES) do
		if nseg <= c then return c end
	end
	return CLASSES[#CLASSES]
end

local function dropEntry(e)
	pcall(function()
		e.chain:Destroy()
		e.folder:Destroy()
	end)
end

--- A BeamChain of kind `kind` and `cls` segments under `parent`. A chain made on a flat-lit map carries that map's
--- tone-down, so an idle chain from the other kind of map is not reused. The layer the kind does not draw is unparented.
local function takeChain(kind, cls, parent, flat)
	local byKind = chainPool[kind]
	local list = byKind and byKind[cls]
	while list and #list > 0 do
		local e = table.remove(list)
		if e.flat == flat and pcall(function() e.folder.Parent = parent end) and e.folder.Parent == parent then
			return e
		end
		dropEntry(e)
	end
	local folder = Instance.new("Folder")
	folder.Name = "OverchargeBeams"
	folder.Parent = parent
	local chain = Kit.BeamChain.new(folder, cls, LOOKS[kind])
	local spare = SPARE[kind]
	if spare and type(chain[spare]) == "table" then
		for _, b in ipairs(chain[spare]) do b.Parent = nil end
	end
	return { kind = kind, cls = cls, folder = folder, chain = chain, flat = flat,
		paint = PAINTED[kind] and { c = {}, g = {}, h = {}, col = nil } or nil }
end

local function giveChain(e)
	local ok = pcall(function()
		e.chain:Hide()
		e.folder.Parent = nil
	end)
	local byKind = chainPool[e.kind]
	if not byKind then
		byKind = {}
		chainPool[e.kind] = byKind
	end
	local list = byKind[e.cls]
	if not list then
		list = {}
		byKind[e.cls] = list
	end
	if ok and #list < POOL_CAP then list[#list + 1] = e else dropEntry(e) end
end

--- A glow sprite: a camera-facing Beam quad (BeamChain's cap technique) on its own tiny host.
local function takeSprite(parent, flat)
	while #spritePool > 0 do
		local s = table.remove(spritePool)
		if s.flat == flat and pcall(function() s.host.Parent = parent end) and s.host.Parent == parent then return s end
		pcall(function() s.host:Destroy() end)
	end
	local host = Kit.host("OverchargeGlow", CFrame.new())
	host.Parent = parent
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = host, host
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.Texture = SOFT
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.LightEmission = flat and FLAT_EMISSION or 1
	b.LightInfluence = 0
	b.ZOffset = 0
	b.Width0, b.Width1 = 0, 0
	b.Enabled = false
	b.Parent = host
	return { host = host, a0 = a0, a1 = a1, beam = b, flat = flat, size = -1, tr = -1, br = -1, col = nil }
end

local function giveSprite(s)
	local ok = pcall(function()
		s.beam.Enabled = false
		s.host.Parent = nil
	end)
	if ok and #spritePool < SPRITE_POOL_CAP then
		spritePool[#spritePool + 1] = s
	else
		pcall(function() s.host:Destroy() end)
	end
end

--- The showcase's per-point k (opacity) and wh (toward white) as per-segment sequences on `beams`, written only where
--- they changed. `cache` holds what each segment last got; `col` nil paints the opacity alone.
local function paint(beams, cache, n, a, ks, col, whs)
	for i = 1, n - 1 do
		local b = beams[i]
		if not b then return end
		local j = (i - 1) * 4
		local o0 = math.clamp(a * (ks and ks[i] or 1), 0, 1)
		local o1 = math.clamp(a * (ks and ks[i + 1] or 1), 0, 1)
		if math.abs((cache[j + 1] or -9) - o0) > 0.004 or math.abs((cache[j + 2] or -9) - o1) > 0.004 then
			b.Transparency = NumberSequence.new(1 - o0, 1 - o1)
			cache[j + 1], cache[j + 2] = o0, o1
		end
		if col then
			local w0 = math.clamp(whs and whs[i] or 0, 0, 1)
			local w1 = math.clamp(whs and whs[i + 1] or 0, 0, 1)
			if math.abs((cache[j + 3] or -9) - w0) > 0.004 or math.abs((cache[j + 4] or -9) - w1) > 0.004 then
				b.Color = ColorSequence.new(col:Lerp(WHITE, w0), col:Lerp(WHITE, w1))
				cache[j + 3], cache[j + 4] = w0, w1
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- THE CANVAS: what a dash, a tell and a release share -- groups of pooled chains and sprites reused frame to frame,
-- named lights, and the showcase's beam() / sprite()
----------------------------------------------------------------------------------------------------
local Canvas = {}
Canvas.__index = Canvas

local NO_OPTS = {}
local EMBER = { ember = true }
local EMBER3 = { ember = true, gstep = 3 }
local GSTEP2 = { gstep = 2 }
local GSTEP3 = { gstep = 3 }

--- ShotTimeScale now (the slow-motion review's factor, re-read: the DevPanel can change it mid-effect).
local function liveScale()
	local okT, ts = pcall(Kit.timeScale)
	return math.max(0.01, (okT and type(ts) == "number") and ts or 1)
end

function Canvas:initCanvas(name, character, at)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Kit.fxFolder()
	self.folder = folder
	self.host = Kit.host(name .. "Lights", CFrame.new(typeof(at) == "Vector3" and at or Vector3.zero))
	self.host.Parent = folder
	self.groups, self.lights = {}, {}
	self.drawN, self.dead, self.ctx = 0, false, nil
	self.calm = kitFlag(Kit.reduceFlashing)
	self.kb = self.calm and T.CalmBeam or 1
	self.flat = kitFlag(Kit.flatLit)
	self.glowK = kitFlag(Kit.daylight) and T.DayGlow or 1
	self.thin = kitFlag(Kit.thin, character)
	self.ts = liveScale()
end

function Canvas:group(name)
	local g = self.groups[name]
	if not g then
		g = { used = 0, e = {}, su = 0, s = {} }
		self.groups[name] = g
	end
	return g
end

function Canvas:beginFrame(ctx)
	self.drawN += 1
	self.ctx = ctx
	for _, g in pairs(self.groups) do
		g.used, g.su = 0, 0
	end
end

--- Hides what this frame did not draw (kept for the next), and puts out the lights it did not set.
function Canvas:endFrame()
	for _, g in pairs(self.groups) do
		for i = g.used + 1, #g.e do g.e[i].chain:Hide() end
		for i = g.su + 1, #g.s do
			local b = g.s[i].beam
			if b.Enabled then b.Enabled = false end
		end
	end
	for _, L in pairs(self.lights) do
		if L.light and L.frame ~= self.drawN and L.light.Brightness ~= 0 then L.light.Brightness = 0 end
	end
end

--- The group's next chain slot, of `kind` and big enough for `nseg` segments (last frame's, when it matches).
function Canvas:take(g, kind, nseg)
	local cls = classFor(nseg)
	g.used += 1
	local e = g.e[g.used]
	if e and e.kind == kind and e.cls == cls then return e end
	if e then giveChain(e) end
	e = takeChain(kind, cls, self.folder, self.flat)
	g.e[g.used] = e
	return e
end

--- overcharge_bl.beam(): one arc. cw / gw: a number (tapered to 0 at both ends) or a list per point. o (optional):
--- a (alpha), k / wh / gwk (lists per point), gstep (2), haze (0), ember, gpts (the glow's own path), coreOnly.
function Canvas:beam(g, pts, cw, gw, cc, cb, gc, gb, o)
	local n = #pts
	if n < 2 then return end
	o = o or NO_OPTS
	local gstep = o.gstep or 2
	if n <= 4 then gstep = 1 end                          -- a short arc keeps every attachment for its glow too
	local a = o.a or 1
	local ks, whs = o.k, o.wh
	local cwl = type(cw) == "table" and cw or endsProfile(n, cw, 0.45, 0)

	if o.ember then
		-- a dying arc: a Dark core and a faint lifted-violet halo (never a flat painted line)
		local e = self:take(g, "core", n - 1)
		e.chain:Set(pts, cwl, 0)
		e.chain:Look(cc or COL.Dark, cc or COL.Dark, cb, 0, a)
		local idx = thinIdx(n, gstep)
		local m = #idx
		if m >= 3 then
			local hp, hw = table.create(m), table.create(m)
			for j = 1, m do
				local i = idx[j]
				hp[j] = pts[i]
				hw[j] = (j == 1 or j == m) and 0 or (cwl[i] or 0) * 3 + 0.05
			end
			local h = self:take(g, "glow", m - 1)
			h.chain:Set(hp, 0, hw)
			h.chain:Look(EMBER_HALO, EMBER_HALO, 0, cb * 0.8, 0.15 * a / GLOW_ALPHA)
		end
		return
	end

	if not o.coreOnly and gw ~= nil and (type(gw) == "table" or gw > 0) then
		-- the glow on the thinned path, its ends pushed out 35 % of its width so it closes round
		local idx = thinIdx(n, gstep)
		local m = #idx
		local src = o.gpts or pts
		local gwl = type(gw) == "table" and gw or endsProfile(n, gw, 0.35, 0)
		local gwk = o.gwk
		local base, gp = table.create(m), table.create(m)
		for j = 1, m do
			local i = idx[j]
			base[j] = (gwl[i] or 0) * (gwk and gwk[i] or 1)
			gp[j] = src[i] or pts[i]
		end
		local w0 = math.max(m > 2 and base[2] or base[1], 1e-3)
		local w1 = math.max(m > 2 and base[m - 1] or base[m], 1e-3)
		local e0, e1 = gp[1] - gp[2], gp[m] - gp[m - 1]
		if e0.Magnitude > 1e-6 then gp[1] = gp[1] + e0.Unit * (0.35 * w0) end
		if e1.Magnitude > 1e-6 then gp[m] = gp[m] + e1.Unit * (0.35 * w1) end
		local widths, gk
		if m == 2 then
			local mx, sum = 0, 0
			for i = 1, n do
				mx = math.max(mx, gwl[i] or 0)
				sum += gwk and gwk[i] or 1
			end
			gp = { gp[1], (gp[1] + gp[2]) / 2, gp[2] }
			widths = { 0, mx * sum / n, 0 }
			if ks then gk = { ks[1], (ks[1] + ks[n]) / 2, ks[n] } end
		else
			widths = table.create(m)
			for j = 1, m do widths[j] = (j == 1 or j == m) and 0 or base[j] end
			if ks then
				gk = table.create(m)
				for j = 1, m do gk[j] = ks[idx[j]] end
			end
		end
		local glowB = gb * self.glowK
		local hz = o.haze or 0
		local ng = #gp
		if hz > 0 then
			local e = self:take(g, gk and "haloP" or "halo", ng - 1)
			local hw = table.create(ng)
			for j = 1, ng do hw[j] = widths[j] * hz end
			e.chain:Set(gp, hw, widths)
			if gk then
				e.chain:Look(gc, gc, glowB * 0.45, glowB, GLOW_ALPHA * HAZE_SHARE)
				paint(e.chain.Core, e.paint.h, ng, a * GLOW_ALPHA * HAZE_SHARE, gk, nil, nil)
				paint(e.chain.Glow, e.paint.g, ng, a * GLOW_ALPHA, gk, nil, nil)
			else
				e.chain:Look(gc, gc, glowB * 0.45, glowB, GLOW_ALPHA * HAZE_SHARE * a)
			end
		else
			local e = self:take(g, gk and "glowP" or "glow", ng - 1)
			e.chain:Set(gp, 0, widths)
			if gk then
				e.chain:Look(gc, gc, 0, glowB, 1)
				paint(e.chain.Glow, e.paint.g, ng, a * GLOW_ALPHA, gk, nil, nil)
			else
				e.chain:Look(gc, gc, 0, glowB, a)
			end
		end
	end

	local painted = ks ~= nil or whs ~= nil
	local e = self:take(g, painted and "coreP" or "core", n - 1)
	e.chain:Set(pts, cwl, 0)
	if painted then
		-- the Look's alpha stays 1 on a painted chain, so it never overwrites the painted sequences
		e.chain:Look(cc, cc, cb, 0, 1)
		local P = e.paint
		if P.col ~= cc then
			P.col = cc
			table.clear(P.c)
		end
		paint(e.chain.Core, P.c, n, a, ks, cc, whs)
	else
		e.chain:Look(cc, cc, cb, 0, a)
	end
end

--- overcharge_bl.sprite(): a soft glow `quad` studs across at `pos`, pushed z studs toward the eye at the same size on
--- screen (a ParticleEmitter's ZOffset).
function Canvas:sprite(g, pos, quad, col, alpha, bright, z)
	local ctx = self.ctx
	local d = ctx.camPos - pos
	local dist = d.Magnitude
	local size = quad
	if z and z > 0 and dist > 1e-6 then
		local zz = math.min(z, dist * 0.6)
		pos += d / dist * zz
		size = quad * (dist - zz) / dist
	end
	g.su += 1
	local s = g.s[g.su]
	if not s then
		s = takeSprite(self.folder, self.flat)
		g.s[g.su] = s
	end
	s.host.CFrame = CFrame.new(pos)
	local half = ctx.right * (size * 0.5)
	s.a0.Position = -half
	s.a1.Position = half
	local b = s.beam
	if math.abs(s.size - size) > 1e-4 then
		b.Width0, b.Width1 = size, size
		s.size = size
	end
	if s.col ~= col then
		b.Color = ColorSequence.new(col)
		s.col = col
	end
	local tr = 1 - clamp01(alpha)
	if math.abs(s.tr - tr) > 0.003 then
		b.Transparency = NumberSequence.new(tr)
		s.tr = tr
	end
	local br = math.max(0, bright) * (self.flat and FLAT_BRIGHTNESS or 1)
	if math.abs(s.br - br) > 0.005 then
		b.Brightness = br
		s.br = br
	end
	if not b.Enabled then b.Enabled = true end
end

--- The named PointLight at `pos` this frame (made on first use; none on a flat-lit map; halved in daylight).
function Canvas:light(key, pos, bright, range)
	local L = self.lights[key]
	if not L then
		L = {}
		local att = Kit.attach(self.host, pos)
		local l = Kit.light(att, 1, range, COL.Light)
		if l then
			L.att, L.light, L.dayK = att, l, l.Brightness
		else
			att:Destroy()
		end
		self.lights[key] = L
	end
	L.frame = self.drawN
	local l = L.light
	if not l then return end
	L.att.WorldPosition = pos
	local v = math.max(0, bright) * L.dayK
	if math.abs(l.Brightness - v) > 1e-3 then l.Brightness = v end
	range = math.clamp(range, 0, 60)
	if math.abs(l.Range - range) > 1e-3 then l.Range = range end
end

--- Clears everything at once. `poison`: a frame failed, so the pooled pieces are destroyed, not put back.
function Canvas:Destroy(poison)
	if self.dead then return end
	self.dead = true
	if self.onDestroy then pcall(self.onDestroy, self) end
	for _, g in pairs(self.groups) do
		for _, e in ipairs(g.e) do
			if poison then dropEntry(e) else giveChain(e) end
		end
		for _, s in ipairs(g.s) do
			if poison then pcall(function() s.host:Destroy() end) else giveSprite(s) end
		end
		table.clear(g.e)
		table.clear(g.s)
	end
	pcall(function() self.folder:Destroy() end)
end

----------------------------------------------------------------------------------------------------
-- ONE runner for everything, at RenderPriority.Last (after the camera and the Viewmodel's arms)
----------------------------------------------------------------------------------------------------
local objs = {}
local bound = false
local ctx = { cam = nil, camPos = Vector3.zero, right = Vector3.xAxis }

local function fillCtx()
	local cam = workspace.CurrentCamera
	ctx.cam = cam
	if cam then
		local cf = cam.CFrame
		ctx.camPos, ctx.right = cf.Position, cf.RightVector
	end
end

local function stepOne(o)
	local ok, res = pcall(o.step, o, ctx)
	if not ok then
		warnOnce("step", "an Overcharge frame failed and its effect was cleared: " .. tostring(res))
		o:Destroy(true)
		return false
	end
	return res == true
end

local function runner()
	fillCtx()
	local now = os.clock()
	for i = #objs, 1, -1 do
		local o = objs[i]
		local keep = (not o.dead) and now <= o.deadline and stepOne(o)
		if not keep then
			table.remove(objs, i)
			if not o.dead then o:Destroy() end
		end
	end
	if bound and #objs == 0 then
		bound = false
		pcall(RunService.UnbindFromRenderStep, RunService, RUNNER)
	end
end

function Canvas:start()
	if self.dead then return end
	objs[#objs + 1] = self
	if not bound then
		bound = true
		RunService:BindToRenderStep(RUNNER, Enum.RenderPriority.Last.Value, runner)
	end
	fillCtx()
	if not stepOne(self) and not self.dead then self:Destroy() end      -- on this frame, not the next
end

local function handle(o)
	return { Destroy = function() o:Destroy() end }
end

-- per character: the tell (climbing or confirmed), the dash whose local +TellDelay tell is still owed, and the server
-- times this client last heard a cast / last ended a tell (weak: a character that is gone takes its rows with it)
local primed = {}
local pending = setmetatable({}, { __mode = "k" })
local lastCast = setmetatable({}, { __mode = "k" })
local lastOff = setmetatable({}, { __mode = "k" })

----------------------------------------------------------------------------------------------------
-- THE ARM: the showcase's arm space (body-local, x right, y up from the feet, z BACK) mapped onto a real arm
----------------------------------------------------------------------------------------------------
local ARMS = {
	R = { Upper = "RightUpperArm", Lower = "RightLowerArm", R6 = "Right Arm" },
	L = { Upper = "LeftUpperArm", Lower = "LeftLowerArm", R6 = "Left Arm" },
}

--- The out / back axes round an arm segment running down `d`: `right` made square to it, and out x (-d).
local function armFrame(d, right)
	local o = right - d * right:Dot(d)
	o = o.Magnitude > 1e-3 and o.Unit or perpAny(d)
	return o, o:Cross(-d)
end

--- A body's arm this frame into R: shoulder S (the upper arm's top), the elbow, the hand (Kit.hands' grip); the root's
--- frame for what sits above the shoulder. `delta` shifts it all (an observer's settle). False with no root.
local function bodyRig(R, character, sd, sign, grip, delta)
	local root = bodyPart(character, "HumanoidRootPart")
	if not root then return false end
	local rcf = root.CFrame
	local right, up = rcf.RightVector, rcf.UpVector
	local A = ARMS[sd]
	local upper, lower = bodyPart(character, A.Upper), bodyPart(character, A.Lower)
	local S, E, width
	if upper and lower then
		local ucf, hy = upper.CFrame, upper.Size.Y * 0.5
		S = ucf * Vector3.new(0, hy - SHOULDER_DROP, 0)
		E = (ucf * Vector3.new(0, -hy, 0) + lower.CFrame * Vector3.new(0, lower.Size.Y * 0.5, 0)) * 0.5
		width = upper.Size.X
	else
		local arm = bodyPart(character, A.R6)
		if arm then
			S = arm.CFrame * Vector3.new(0, arm.Size.Y * 0.5 - SHOULDER_DROP, 0)
			width = arm.Size.X
		else
			S = rcf * Vector3.new(sign * S0X, S0Y - 3, 0)
			width = 1
		end
	end
	local H = (grip and grip.Parent) and grip.WorldPosition or (S - up * (UP_LEN + LO_LEN))
	if not E then E = S:Lerp(H, UP_LEN / (UP_LEN + LO_LEN)) end
	if delta then S += delta; E += delta; H += delta end
	local v1, v2 = E - S, H - E
	local d1 = safeUnit(v1, -up)
	local d2 = safeUnit(v2, d1)
	R.S, R.d1, R.d2 = S, d1, d2
	R.k1 = math.clamp(v1.Magnitude / UP_LEN, 0.4, 2.5)
	R.k2 = math.clamp(v2.Magnitude / LO_LEN, 0.4, 2.5)
	R.kl = math.clamp(width, 0.6, 1.6)
	R.sx = sign * S0X
	R.right, R.up, R.back = right, up, -rcf.LookVector
	R.o1, R.b1 = armFrame(d1, right)
	R.o2, R.b2 = armFrame(d2, right)
	R.w = 1
	return true
end

--- Your own first-person arm (Viewmodel's CastPoint: 0.05 past the fist, LookVector along the forearm), at FpScale:
--- the showcase's hand tip on the CastPoint, its arm running back up the forearm.
local function fpRig(R, cp, sign, camRight)
	local cf = cp.WorldCFrame
	local look = cf.LookVector
	local kv = T.FpScale
	local S = cf.Position - look * ((UP_LEN + LO_LEN) * kv)
	local o, b = armFrame(look, camRight)
	R.S, R.d1, R.d2 = S, look, look
	R.k1, R.k2, R.kl = kv, kv, kv * T.FpLateral
	R.sx = sign * S0X
	R.right, R.up, R.back = o, -look, b
	R.o1, R.b1, R.o2, R.b2 = o, b, o, b
	R.w = T.FpWidth
	return true
end

--- overcharge_bl.to_world() on a real arm: a body-local point, riding the arm below RIDE_TOP (blended over RIDE_BLEND).
local function mapPoint(R, p)
	local dy = p.Y - S0Y
	local lat, dep = (p.X - R.sx) * R.kl, p.Z * R.kl
	local w = clamp01((RIDE_TOP - p.Y) / RIDE_BLEND)
	local body = nil
	if w < 1 then body = R.S + R.right * lat + R.up * (dy * R.k1) + R.back * dep end
	if w <= 0 then return body end
	local s = -dy                                         -- showcase studs down the arm from the shoulder
	local base
	if s <= UP_LEN then
		base = R.S + R.d1 * (s * R.k1)
	else
		base = R.S + R.d1 * (UP_LEN * R.k1) + R.d2 * ((s - UP_LEN) * R.k2)
	end
	local o, b = R.o1, R.b1
	local u = (s - (UP_LEN - ELBOW_BLEND)) / (2 * ELBOW_BLEND)
	if u >= 1 then
		o, b = R.o2, R.b2
	elseif u > 0 then
		o = safeUnit(R.o1:Lerp(R.o2, u), R.o2)
		b = safeUnit(R.b1:Lerp(R.b2, u), R.b2)
	end
	local arm = base + o * lat + b * dep
	if w >= 1 then return arm end
	return body:Lerp(arm, w)
end

local function mapList(R, list, from)
	local out = table.create(math.max(0, #list - from + 1))
	for i = from, #list do out[#out + 1] = mapPoint(R, list[i]) end
	return out
end

--- The first point at or below showcase height y (first person draws the arm from there).
local function firstBelow(list, y)
	for i, p in ipairs(list) do
		if p.Y <= y then return i end
	end
	return #list
end

--- The body's grip attachment for side S (cached; a lost one is looked for again every HandRetry).
local function gripFor(character, S)
	local g = S.grip
	if g and g.Parent and g:IsDescendantOf(character) then return g end
	if os.clock() < (S.gripRetry or 0) then return nil end
	S.gripRetry = os.clock() + T.HandRetry
	local ok, hands = pcall(Kit.hands, character)
	g = ok and type(hands) == "table" and hands[S.sd] or nil
	S.grip = (typeof(g) == "Instance" and g:IsA("Attachment")) and g or nil
	return S.grip
end

----------------------------------------------------------------------------------------------------
-- A ROUTE (overcharge_bl.Route): one tendril path, body-local -- control points round the arm from the shoulder
-- (never above the shoulder line) down over the outside of the arm to the hand, jagged; a primary fork, a twig, 4 prongs
----------------------------------------------------------------------------------------------------
local Route = {}
Route.__index = Route

function Route.new(sign, seed, grown)
	local rr = Random.new(seed)
	local self = setmetatable({ sign = sign, seed = seed, grown = grown == true }, Route)
	local ySh, yHd = rr:NextNumber(3.72, 3.9), rr:NextNumber(1.05, 1.5)
	local ph0 = rr:NextNumber(45, 100) * (rr:NextNumber() < 0.5 and 1 or -1)
	local ph1 = -ph0 * rr:NextNumber(0.7, 1.1)
	self.ctrl = table.create(ROUTE_N)
	for i = 0, ROUTE_N - 1 do
		local u = i / (ROUTE_N - 1)
		local inner = i > 0 and i < ROUTE_N - 1
		local y = lerp(ySh, yHd, u) + (inner and rr:NextNumber(-0.14, 0.14) or 0)
		local ph = lerp(ph0, ph1, u) + (inner and rr:NextNumber(-14, 14) or 0)
		self.ctrl[i + 1] = { y, ph, T.Radius + rr:NextNumber(-0.05, 0.10) }
	end
	self.sub = table.create(ROUTE_N - 1)
	for i = 1, ROUTE_N - 1 do
		local w = table.create(6)
		for j = 1, 6 do w[j] = rr:NextNumber(-1, 1) end
		self.sub[i] = w
	end
	-- the primary fork rooted below the elbow (control 3 or 4, 0-based), aimed out and down, bending back to the hand
	self.primary = { (rr:NextNumber() < 0.5 and 3 or 4) + 1, rr:NextNumber(0.9, 1.3), rr:NextNumber(-60, -15),
		rr:NextInteger(0, 1000000) }
	self.twig = { (rr:NextNumber() < 0.5 and 1 or 2) + 1, rr:NextNumber(0.35, 0.6), rr:NextNumber(-40, -10),
		rr:NextInteger(0, 1000000) }
	self.prongs = {
		{ rr:NextNumber(-55, -35), rr:NextNumber(0.45, 0.8) }, { rr:NextNumber(-20, -5), rr:NextNumber(0.45, 0.8) },
		{ rr:NextNumber(5, 20), rr:NextNumber(0.45, 0.8) }, { rr:NextNumber(35, 55), rr:NextNumber(0.45, 0.8) },
	}
	return self
end

function Route:axisX(y)
	return self.sign * (y < 3.6 and 1.5 or lerp(1.5, 1.15, clamp01((y - 3.6) / 0.6)))
end

function Route:point(y, ph, r)
	if y < 3.8 then ph = math.clamp(ph, -120, 120) end     -- never on the inside, against the torso
	local a = math.rad(ph)
	return Vector3.new(self:axisX(y) + self.sign * r * math.cos(a), y, -r * math.sin(a))
end

function Route:outward(p)
	local v = Vector3.new(p.X - self:axisX(p.Y), 0, p.Z)
	return v.Magnitude > 1e-4 and v.Unit or Vector3.new(self.sign, 0, 0)
end

function Route:keepOut(p)
	local ax = self:axisX(p.Y)
	local v = Vector3.new(p.X - ax, 0, p.Z)
	if v.Magnitude < T.KeepOut and p.Y < 4.0 then
		v = (v.Magnitude > 1e-4 and v.Unit or Vector3.new(self.sign, 0, 0)) * T.KeepOut
		return Vector3.new(ax + v.X, p.Y, v.Z)
	end
	return p
end

--- The control points, drifted (degrees round the arm, studs up / down) and crawled (dy), under the shoulder line.
function Route:controls(drift, ydr, dy)
	drift, ydr, dy = drift or 0, ydr or 0, dy or 0
	local out = table.create(ROUTE_N)
	for i, c in ipairs(self.ctrl) do
		local u = (i - 1) / (ROUTE_N - 1)
		out[i] = self:point(math.min(3.9, c[1] + ydr * (1 - u) + dy), c[2] + drift * (0.5 + 0.5 * u), c[3])
	end
	return out
end

--- (main shoulder -> hand, primary fork, twig, prongs), body-local, for 60 Hz frame `cf`. age: seconds this route has
--- lived (it crawls down the arm meanwhile). thin (Kit.thin: showcase flag 7, "jag depth 1"): one sub-point a span
--- (11 main points, not 21) and the forks one jag level shallower.
function Route:build(cf, crackle, drift, ydr, age, thin)
	local C = self:controls(drift, ydr, -math.min(T.Crawl[2], T.Crawl[1] * math.max(0, age)))
	local cr = Random.new(self.seed * 31 + cf * 977)
	local main = { C[1] }
	for i = 1, ROUTE_N - 1 do
		local a, b = C[i], C[i + 1]
		local d = b - a
		local L = d.Magnitude
		local dn = L > 1e-6 and d / L or Vector3.new(0, -1, 0)
		local n1 = perpAny(dn)
		local n2 = dn:Cross(n1)
		local w = self.sub[i]
		for j = 0, 2 do
			if not thin or j == 1 then
				local u = (j + 1) / 4
				local amp = 0.30 * L * (j == 1 and 1 or 0.55)
				local p = a:Lerp(b, u) + (n1 * w[2 * j + 1] + n2 * w[2 * j + 2]) * amp
				p += Vector3.new(cr:NextNumber(-1, 1), cr:NextNumber(-1, 1), cr:NextNumber(-1, 1)) * crackle
				main[#main + 1] = self:keepOut(p)
			end
		end
		main[#main + 1] = b
	end
	local function fork(spec, frOff, bend)
		local base = C[spec[1]]
		local out = self:outward(base)
		local tl = math.rad(spec[3])
		local flen = spec[2]
		local d = (out * math.cos(tl) + Vector3.new(0, math.sin(tl), 0)).Unit
		local fr = Random.new(spec[4] + cf * 13 + frOff)
		local depth = thin and 1 or 2
		if not bend then return Kit.jag(base, base + d * flen, depth, 0.26 * flen, fr) end
		local p1 = base + d * (flen * 0.55)                 -- out, then bending back down the arm toward the hand
		local d2 = safeUnit(d * 0.35 + Vector3.new(0, -0.65, 0) - out * 0.25, Vector3.new(0, -1, 0))
		local p2 = p1 + d2 * (flen * 0.45)
		local A = Kit.jag(base, p1, depth, 0.2 * flen, fr)
		local B = Kit.jag(p1, p2, 1, 0.12 * flen, fr)
		for k = 2, #B do A[#A + 1] = B[k] end
		return A
	end
	local primary = fork(self.primary, 0, true)
	local twig = fork(self.twig, 7, false)
	local tip = main[#main]
	local dn = safeUnit(main[#main] - main[#main - (thin and 2 or 3)], Vector3.new(0, -1, 0))   -- from the last span
	local out = self:outward(tip)
	local prongs = table.create(#self.prongs)
	for j, pr in ipairs(self.prongs) do
		local a = math.rad(pr[1])
		local q = safeUnit(dn * math.cos(a) + out * math.sin(a), dn)
		local fr = Random.new(self.seed + (j - 1) * 101 + cf)
		prongs[j] = Kit.jag(tip, tip + q * pr[2], 1, 0.22 * pr[2], fr)
	end
	return main, primary, twig, prongs
end

function Route:midLocal()
	local c = self.ctrl[3]
	return self:point(c[1], c[2], c[3] + 0.5)
end

--- How far apart two routes' control points sit (a snap nearly onto the old route is re-rolled).
local function routeGap(a, b)
	if not b then return math.huge end
	local ca, cb = a:controls(), b:controls()
	local sum = 0
	for i = 1, ROUTE_N do sum += (ca[i] - cb[i]).Magnitude end
	return sum / ROUTE_N
end

----------------------------------------------------------------------------------------------------
-- 4 THE PRIMED TELL
----------------------------------------------------------------------------------------------------
local Tell = setmetatable({}, { __index = Canvas })
Tell.__index = Tell

local function frameCeil(t) return math.ceil(t * 60 - 1e-4) end

local function bagNext(S)
	if S.bagI > #S.bag then
		S.bag = shuffle(table.clone(S.bagSrc), S.rng)
		S.bagI = 1
	end
	local v = S.bag[S.bagI]
	S.bagI += 1
	return v
end

--- The right side's snap frames, generated at least past frame `upto`.
function Tell:extendRight(upto)
	local R, rF = self.sides.R, self.rF
	local guard = 0
	while (#rF == 0 or rF[#rF] <= upto) and guard < 64 do
		guard += 1
		rF[#rF + 1] = frameCeil(R.acc)
		R.acc += bagNext(R)
	end
end

--- No right-side snap within SnapApart frames of frame c.
function Tell:free(c)
	local apart = T.SnapApart + 0.5
	self:extendRight(c + T.SnapApart + 1)
	local rF = self.rF
	for i = #rF, 1, -1 do
		local r = rF[i]
		if math.abs(c - r) < apart then return false end
		if r < c - apart - 1 then break end
	end
	return true
end

--- The left side's next snap: its own bag, shifted by the fewest frames that clear the right side while its interval
--- stays inside the bag's range (plan_tendrils' de-conflict).
function Tell:nextLeft()
	local L = self.sides.L
	local c = frameCeil(L.acc)
	L.acc += bagNext(L)
	local lo, hi = self.bagLo, self.bagHi
	if L.prevF then c = math.max(c, L.prevF + lo) end
	if not self:free(c) then
		for _, sh in ipairs(SHIFTS) do
			local cand = c + sh
			local gap = L.prevF and cand - L.prevF or nil
			if gap == nil or (gap >= lo and gap <= hi) then
				if self:free(cand) then
					c = cand
					break
				end
			end
		end
	end
	L.prevF = c
	return c
end

function Tell:nextSnap(S)
	if S.sign > 0 then
		S.nextI += 1
		local guard = 0
		while #self.rF < S.nextI and guard < 8 do
			guard += 1
			self:extendRight(self.rF[#self.rF] or 0)
		end
		return self.rF[S.nextI]
	end
	return self:nextLeft()
end

--- Snaps side S to a new route on every due frame (a fresh seed each; a null snap is re-rolled).
function Tell:advance(S, fno)
	local guard = 0
	while S.nextF and fno >= S.nextF and guard < 16 do
		guard += 1
		S.k += 1
		local seed = S.seed0 + 17 * S.k
		local r = Route.new(S.sign, seed, false)
		for _ = 1, 6 do
			if routeGap(r, S.route) >= 0.4 then break end
			seed += 7919
			r = Route.new(S.sign, seed, false)
		end
		S.prev, S.route, S.snapF = S.route, r, S.nextF
		S.emberF = nil                                     -- owed: the first drawn 60 Hz frame at or after the snap
		S.nextF = self:nextSnap(S)
		S.geoF = nil
	end
end

--- The latest pulse start at or before tq: the right side's own clock, the left half a period behind on it.
function Tell:pulseStart(sign, tq)
	local P = self.pulses
	local guard = 0
	while P[#P] <= tq + 1 and guard < 64 do
		guard += 1
		P[#P + 1] = P[#P] + self.prng:NextNumber(T.PulseEvery[1], T.PulseEvery[2])
	end
	while #P > 4 and P[3] < tq - 1 do table.remove(P, 1) end
	local best = nil
	for i = 1, #P do
		local s = nil
		if sign > 0 then
			s = P[i]
		elseif P[i + 1] then
			s = (P[i] + P[i + 1]) / 2
		end
		if s and s <= tq + 1e-9 then best = s end
	end
	return best
end

--- pulse_bump(): the pulse running shoulder -> hand, a bump per point (0..1).
local function bumps(st, tq, us, n)
	local out = table.create(n, 0)
	if not st or tq - st > T.PulseTravel then return out end
	local c = (tq - st) / T.PulseTravel * 1.3 - 0.15
	for i = 1, n do
		local x = (us[i] - c) / 0.13
		out[i] = math.exp(-x * x)
	end
	return out
end

--- This 60 Hz frame's shape of side S (body-local): re-rolled only when the frame changes; mapped every render frame.
function Tell:shape(S, fno, tq)
	local route = S.route
	local cf = self.thin and (fno - fno % 2) or fno          -- thin: crackle at 30 Hz
	local dd, dp, yd, yp = T.Drift[1], T.Drift[2], T.Drift[3], T.Drift[4]
	local drift = dd * math.sin(2 * math.pi * tq / dp + S.phase[1])
	local ydr = yd * math.sin(2 * math.pi * tq / yp + S.phase[2])
	local main, primary, twig, prongs = route:build(cf, T.Crackle * (self.calm and 0.5 or 1), drift, ydr,
		tq - S.snapF / 60, self.thin)
	-- the glow chain stands GlowOff further off the arm than the core
	local glow = table.create(#main)
	for i, p in ipairs(main) do
		glow[i] = p + route:outward(p) * T.GlowOff + Vector3.new(0, p.Y > 3.8 and 0.08 or 0, 0)
	end
	S.geo = { main = main, glow = glow, primary = primary, twig = twig, prongs = prongs }
	-- the snap's ember / boost on the first 60 Hz frame drawn at or after it (a client under 60 fps may skip the due
	-- frame itself), for exactly one frame
	if S.emberF == nil and not route.grown and fno >= S.snapF then S.emberF = fno end
	S.snapNow = S.emberF == fno
	S.prevMain = nil
	if S.snapNow and S.prev then
		S.prevMain = (S.prev:build(cf - 1, T.Crackle, drift, ydr, 1.0, self.thin))
	end
	local fl = Random.new(self.seed * 13 + S.sign * 7 + fno * 131)
	S.kk = self.kb * (1 + T.Flicker * fl:NextNumber(-1, 1)) * ((S.snapNow and not self.calm) and T.SnapBoost or 1)
	S.flick = 1 + 0.1 * fl:NextNumber(-1, 1)
	-- (2026-10-19, audit P5D-04) Reduce Flashing: a steady tendril, no +-Flicker re-rolled every frame
	if self.calm then S.kk, S.flick = self.kb, 1 end
	S.pulseAt = self:pulseStart(S.sign, tq)
	S.geoF = fno
end

--- An observer's settle: the broadcast's To minus the replicated root, fading out over Settle after the landing.
function Tell:settle(t)
	if self.own or not self.to then return nil end
	local w = 1 - clamp01((t - self.tLandF) / T.Settle)
	if w <= 0 then return nil end
	local root = bodyPart(self.character, "HumanoidRootPart")
	if not root then return nil end
	local d = self.to - root.Position
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude > 12 then return nil end
	return d * w
end

--- floor (the landing's root arc tip) -> up the outside of the leg -> the hand -> up the arm -> the shoulder.
function Tell:climbPath(S, route, mainW)
	local cf, sign = self.landCF, S.sign
	local floor = cf * Vector3.new(2.0 * sign, 0.10, 1.2)
	local leg = cf * Vector3.new(1.35 * sign, 0.95, 0.45)
	local fr = Random.new(route.seed * 7 + 5)
	local out = Kit.jag(floor, leg, 2, 0.20, fr)
	local up = Kit.jag(leg, mainW[#mainW], 2, 0.22, fr)
	for i = 2, #up do out[#out + 1] = up[i] end
	for i = #mainW - 1, 1, -1 do out[#out + 1] = mainW[i] end
	return out
end

--- overcharge_bl.draw_tendril(), one side, this render frame.
function Tell:drawSide(S, fno, tq, t, c)
	self:advance(S, fno)
	local fp, R = self.fp, S.rig
	if fp then
		local ok, cp = pcall(Kit.castPoint, S.sd)
		if not (ok and typeof(cp) == "Instance") then return end
		fpRig(R, cp, S.sign, c.right)
	elseif not bodyRig(R, self.character, S.sd, S.sign, gripFor(self.character, S), self:settle(t)) then
		return
	end
	if S.geoF ~= fno then self:shape(S, fno, tq) end
	local G, route = S.geo, S.route
	local g = self:group(S.sd)
	local ws = R.w
	local cw, gw, cb, gb = T.Tendril[1] * ws, T.Tendril[2] * ws, T.Tendril[3], T.Tendril[4]
	local kk = S.kk
	local from = fp and firstBelow(G.main, T.FpFrom) or 1
	local mainW = mapList(R, G.main, from)
	if #mainW < 2 then return end
	local glowW = mapList(R, G.glow, from)
	local handW = mainW[#mainW]
	local climbing = tq < self.tGrown - TOL
	local growW = nil
	if not fp and self.landCF and (climbing or route.grown) then growW = self:climbPath(S, route, mainW) end

	-- 3 -> 4 THE CLIMB (frames 10-13): revealed root first
	if climbing then
		if not growW then return end
		local reveal = easeOutQuad((tq - self.tLandF + F) / (T.Grow + F))
		local acc = arclen(growW)
		local pts, ss = cutPath(growW, acc, 0, math.max(0.05, acc[#acc] * reveal))
		local n = #pts
		if n < 2 then return end
		local total = math.max(1e-6, ss[n])
		local cwl, ks, whs = table.create(n), table.create(n), table.create(n)
		for i = 1, n do
			local u = ss[i] / total
			cwl[i] = cw * ((i == 1 and 0.2) or (i == n and 1.1) or 1)
			ks[i] = 0.8 + 0.4 * u * u
			whs[i] = 0.7 * u ^ 4
		end
		self:beam(g, pts, cwl, gw, COL.Light, cb * kk, COL.Base, gb * kk, { gstep = 3, k = ks, wh = whs })
		-- the climbing head's glow only above the hip, and only on the side facing the eye
		local head = pts[n]
		local feet = self.landCF.Position
		local out = Vector3.new(head.X - feet.X, 0, head.Z - feet.Z)
		local toCam = Vector3.new(c.camPos.X - feet.X, 0, c.camPos.Z - feet.Z)
		local facing = out.Magnitude < 1e-4 or toCam.Magnitude < 1e-4 or out.Unit:Dot(toCam.Unit) > -0.2
		if head.Y > feet.Y + 2.0 and facing then
			self:sprite(g, head, 0.55 * 2, COL.Light, 1, 1.4 * self.kb, 0.6)
		end
		if not self.thin then
			local lp = head + (out.Magnitude > 1e-4 and out.Unit * 0.5 or Vector3.zero)
			self:light(S.lightKey, lp, T.TendrilLight[1] * self.kb, T.TendrilLight[2])
		end
		return
	end

	-- 4 THE HOLD. The grown route keeps its climb until its first snap: one continuous event.
	local main = growW or mainW
	local n = #main
	local acc = arclen(main)
	local total = math.max(1e-6, acc[n])
	local us = table.create(n)
	for i = 1, n do us[i] = acc[i] / total end
	local bump = bumps(S.pulseAt, tq, us, n)
	-- the steady opacity gradient: the arc-length share measured once per route (its first drawn frame), so the 60 Hz
	-- crackle / drift / crawl do not jitter it and the paint cache really skips a segment outside the pulse; the
	-- pulse alone rides the live share
	local grown = growW ~= nil
	local ku = S.ku
	if not ku or S.kuRoute ~= route or S.kuGrown ~= grown or #ku ~= n then
		ku = table.clone(us)
		S.ku, S.kuRoute, S.kuGrown = ku, route, grown
	end
	local cwl, ks, whs, gwk = table.create(n), table.create(n), table.create(n), table.create(n)
	for i = 1, n do
		-- thinner at the shoulder, fullest at the hand; the pulse swells the core, whitens it and widens the glow
		local base = (i == 1 or i == n) and cw * 0.25 or cw * (1 + 0.25 * us[i])
		cwl[i] = base * (1 + T.PulseCore * bump[i])
		ks[i] = 0.75 + 0.25 * ku[i]
		whs[i] = T.PulseWhite * bump[i] * (self.calm and 0.5 or 1)   -- (2026-10-19, audit P5D-04) halved under calm
		gwk[i] = 1 + T.PulseGlow * bump[i]
	end
	local haze = (self.thin or fp) and 0 or T.Haze
	self:beam(g, main, cwl, gw, COL.Light, cb * kk, COL.Base, gb * kk,
		{ gstep = 3, haze = haze, k = ks, wh = whs, gwk = gwk, gpts = (growW == nil) and glowW or nil })

	-- the forks, and soft caps over their roots, the hand's prong root and the shoulder end
	local primaryW = (not fp) and mapList(R, G.primary, 1) or nil     -- first person: no forks (they fill the lens)
	local twigW = (not fp) and mapList(R, G.twig, 1) or nil
	local capB = gb * kk * 0.6 * self.glowK
	if primaryW then self:sprite(g, primaryW[1], gw * 0.9, COL.Base, GLOW_ALPHA, capB, 0.3) end
	if twigW then self:sprite(g, twigW[1], gw * 0.9, COL.Base, GLOW_ALPHA, capB, 0.3) end
	self:sprite(g, handW, gw * 0.9, COL.Base, GLOW_ALPHA, capB, 0.3)
	if not fp then self:sprite(g, mainW[1], gw * 0.9, COL.Base, GLOW_ALPHA, capB, 0.3) end
	if primaryW then
		self:beam(g, primaryW, cw * 0.9, gw * 0.85, COL.Light, cb * kk * 0.95, COL.Base, gb * kk * 0.95, GSTEP2)
	end
	local fcw, fgw = T.Fork[1] * ws, T.Fork[2] * ws
	if twigW then self:beam(g, twigW, fcw, fgw, COL.Light, cb * kk * 0.9, COL.Base, gb * kk * 0.9, GSTEP2) end
	for _, pr in ipairs(G.prongs) do
		local pw = mapList(R, pr, 1)
		if fp and #pw > 2 then
			pw = table.move(pw, 1, math.max(2, math.ceil(#pw * T.FpProng)), 1, {})
		end
		self:beam(g, pw, fcw * 1.1, fgw, COL.Light, cb * kk * 0.9, COL.Base, gb * kk * 0.9, GSTEP2)
	end

	-- the abandoned route: a violet ember for one frame -- or, under Reduce Flashing, a dissolve (the old one at 50 %)
	if S.snapNow and S.prevMain then
		local pw = mapList(R, S.prevMain, fp and firstBelow(S.prevMain, T.FpFrom) or 1)
		if self.calm then
			self:beam(g, pw, cw, gw, COL.Light, cb * self.kb * 0.5, COL.Base, gb * self.kb * 0.5, GSTEP3)
		else
			self:beam(g, pw, cw * 0.8, 0, COL.Dark, 3.0 * T.Ember * self.kb, nil, 0, EMBER3)
		end
	end

	-- micro-arcs spitting off (not in first person: a random direction at the lens reads as a scratch on the screen)
	if not self.thin and not fp and n >= 4 then
		local mr = Random.new(self.seed * 17 + S.sign * 1009 + fno * 37)
		local x, p = mr:NextNumber(), T.MicroArcs
		local nm = (x < p[1] and 0) or (x < p[1] + p[2] and 1) or 2
		if self.calm then nm = math.floor(nm / 2) end
		local mcw, mgw, mcb, mgb = T.MicroArc[1] * ws, T.MicroArc[2] * ws, T.MicroArc[3], T.MicroArc[4]
		for _ = 1, nm do
			local p0 = main[mr:NextInteger(3, n - 1)]
			local d = mr:NextUnitVector()
			local L = mr:NextNumber(T.MicroLen[1], T.MicroLen[2]) * ws
			self:beam(g, Kit.jag(p0, p0 + d * L, 1, 0.3 * L, mr), mcw, mgw, COL.Light, mcb * self.kb, COL.Base,
				mgb * self.kb)
		end
	end

	-- the hand glow on the route's hand root, swelling with the pulse arriving
	local pe = bump[n]
	self:sprite(g, handW, T.HandGlow[1] * (1 + 0.6 * pe) * 2 * ws, COL.Light, 1,
		T.HandGlow[2] * self.kb * (1 + 0.5 * pe) * S.flick, T.HandGlow[3] * ws)
	if not self.thin and not fp then
		self:light(S.lightKey, mapPoint(R, route:midLocal()), T.TendrilLight[1] * kk, T.TendrilLight[2])
	end
end

function Tell:step(c)
	if self.dead then return false end
	if not alive(self.character) then return false end
	local t = Kit.clock(self.born)
	local left
	if self.confirmed then
		left = self.watchdog - Kit.clock(self.watchFrom)
		if left <= 0 then return false end
	elseif t > self.provUntil then
		return false                                      -- a climb nobody confirmed
	else
		left = self.provUntil - t
	end
	-- the runner's real-time backstop follows the LIVE ShotTimeScale (a slow-motion review may start mid-tell); the
	-- shot-time checks above are the real limit
	self.ts = liveScale()
	self.deadline = os.clock() + (left + 1) / self.ts
	if not c.cam then return true end
	local fno = math.floor(t * 60 + FRAME_TOL)
	local tq = fno / 60
	self:beginFrame(c)
	if tq >= self.tLandF - TOL then
		self.fp = self.own and firstPersonNow()
		self:drawSide(self.sides.R, fno, tq, t, c)
		self:drawSide(self.sides.L, fno, tq, t, c)
	end
	self:endFrame()
	return true
end

function Tell:confirm()
	self.confirmed = true
	self.watchFrom = Kit.serverNow()
	self.ts = liveScale()
	self.deadline = os.clock() + (self.watchdog + 1) / self.ts
end

--- The routes as they stand (body-local), for the release: its embers ride the arm as it is when it fires.
function Tell:freeze()
	local out = {}
	for _, sd in ipairs({ "R", "L" }) do
		local S = self.sides[sd]
		if S.geo and S.geo.main then
			out[#out + 1] = { sd = sd, sign = S.sign, main = S.geo.main, grip = S.grip, gripRetry = 0, rig = {} }
		end
	end
	return out
end

function Tell:onDestroy()
	for _, cn in ipairs(self.conns) do cn:Disconnect() end
	table.clear(self.conns)
	if primed[self.character] == self then primed[self.character] = nil end
end

--- A tell on `character`. From a dash (`dash`): the climb, on the dash's clock and seed, UNCONFIRMED until
--- SetPrimed(true). Without one: whole at once, its clock set as if grown now.
local function newTell(character, dash)
	local self = setmetatable({}, Tell)
	self:initCanvas("OverchargePrimed", character, dash and dash.to or nil)
	self.character = character
	self.own = kitFlag(Kit.isOwn, character)
	self.watchdog = tun("Watchdog", T.Watchdog)
	local landF = math.ceil(tun("Time", T.DashTime) * 60 - 1e-6)
	self.tLandF = landF / 60
	self.tGrown = self.tLandF + T.Grow
	self.confirmed = false
	self.conns = {}
	self.rF = {}
	if dash then
		self.born, self.seed, self.landCF, self.to = dash.born, dash.seed, dash.landCF, dash.to
		self.provUntil = math.max(tun("TellDelay", T.TellDelay), self.tGrown) + T.Hold
	else
		self.born = Kit.serverNow() - self.tGrown / self.ts
		self.seed = seedFrom(Kit.serverNow(), character)
		self.provUntil = self.tGrown + T.Hold
	end
	self.deadline = os.clock() + 2 / self.ts
	local bag = self.calm and T.CalmSnapBag or T.SnapBag
	local lo, hi = math.huge, 0
	for _, v in ipairs(bag) do
		lo = math.min(lo, v)
		hi = math.max(hi, v)
	end
	self.bagLo, self.bagHi = math.round(lo * 60), math.round(hi * 60)
	self.sides = {}
	for _, sd in ipairs({ "R", "L" }) do
		local sign = sd == "R" and 1 or -1
		local seed0 = self.seed * 7 + (sign > 0 and 4001 or 5003)
		local S = { sd = sd, sign = sign, seed0 = seed0, rng = Random.new(seed0), bagSrc = bag, bag = {}, bagI = 1,
			k = 0, route = Route.new(sign, seed0, dash ~= nil), prev = nil, snapF = landF, emberF = false, nextF = nil,
			nextI = 1,
			prevF = nil, phase = T.DriftPhase[sd], rig = {}, grip = nil, gripRetry = 0, geoF = nil, geo = nil,
			lightKey = "tendril" .. sd }
		S.acc = self.tGrown + S.rng:NextNumber(0.06, 0.14)
		self.sides[sd] = S
	end
	self:extendRight(0)
	self.sides.R.nextF = self.rF[1]
	self.sides.L.nextF = self:nextLeft()
	self.prng = Random.new(self.sides.R.seed0 + 99)
	self.pulses = { self.tGrown }
	-- death or removal ends it at once (the runner would also catch both on its next frame)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		self.conns[#self.conns + 1] = hum.Died:Connect(function() self:Destroy() end)
	end
	self.conns[#self.conns + 1] = character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then self:Destroy() end
	end)
	return self
end

----------------------------------------------------------------------------------------------------
-- 1-3 THE DASH: launch, streak, landing (placed from the broadcast)
----------------------------------------------------------------------------------------------------
local Dash = setmetatable({}, { __index = Canvas })
Dash.__index = Dash

local LENS_NEAR, LENS_FAR = 1.5, 3.0   -- studs from the camera: an arc's nearest point fades from 0 here to 1 there

--- The alpha of a polyline seen from the lens at `cam`: 0 when any of it comes within LENS_NEAR, 1 past LENS_FAR
--- (VFXLibrary's Fade.Near / Far ramp, applied through the beam alpha).
local function lensFade(pts, cam)
	local dmin = math.huge
	for i = 1, #pts - 1 do
		local p, ab = pts[i], pts[i + 1] - pts[i]
		local l2 = ab:Dot(ab)
		local u = l2 > 1e-9 and clamp01((cam - p):Dot(ab) / l2) or 0
		dmin = math.min(dmin, (p + ab * u - cam).Magnitude)
	end
	return clamp01((dmin - LENS_NEAR) / (LENS_FAR - LENS_NEAR))
end

--- The body's share of the dash at shot time t: the LIVE motion, not the showcase's easeOutQuad stand-in. DashMotor
--- drives one constant LinearVelocity (Distance / Time), so the root moves linearly over Time. A dash a wall cut short
--- reaches its end sooner than this, so the curve can only lag the real body (the streak's clamp only errs further back).
function Dash:dashU(t)
	return t > 0 and clamp01(t / self.dashTime) or 0
end

--- A point `along` studs down the dash from the start's floor, `y` above the floor under it, `lat` to its right.
function Dash:pathPoint(along, y, lat)
	local rise = (self.floorTo.Y - self.floorFrom.Y) * clamp01(along / math.max(self.L, 1e-3))
	return self.floorFrom + self.dir * along + self.right * lat + Vector3.new(0, y + rise, 0)
end

--- The caster's own rearmost limb along the dash axis (its real parts), or nil.
function Dash:ownRear()
	local c = self.character
	if not (c and c.Parent) then return nil end
	local d, best = self.dir, nil
	for _, p in ipairs(c:GetChildren()) do
		if p:IsA("BasePart") then
			local cf, s = p.CFrame, p.Size * 0.5
			local ext = math.abs(cf.RightVector:Dot(d)) * s.X + math.abs(cf.UpVector:Dot(d)) * s.Y
				+ math.abs(cf.LookVector:Dot(d)) * s.Z
			local along = (p.Position - self.floorFrom):Dot(d) - ext
			if best == nil or along < best then best = along end
		end
	end
	return best
end

--- A streak fragment is stamped once, in world space, the first frame it is drawn: at least 0.3 studs behind the
--- rearmost limb along the dash axis, whatever the camera.
function Dash:stamp(fr)
	local rear = self.own and self:ownRear() or nil
	if not rear then
		local tb = fr.f * F
		local k = tb < self.dashTime and smooth(tb / (2 * F)) or 1 - smooth((tb - self.dashTime) / T.Recover)
		rear = self.L * self:dashU(tb) - lerp(T.StreakRear[1], T.StreakRear[2], k)
	end
	local cx = math.min(fr.cx, rear - 0.3 - fr.ext)
	fr.c = self:pathPoint(cx, fr.y, fr.z)
	fr.dw = safeUnit(self.dir * fr.d.X + Vector3.yAxis * fr.d.Y + self.right * fr.d.Z, self.dir)
	fr.stamped = true
end

-- 1 LAUNCH ------------------------------------------------------------------------------------------------------------
function Dash:drawLaunch(f, c)
	if f < 0 or f > 2 then return end
	local g = self:group("launch")
	local cw, gw, cb, gb = T.LaunchArc[1], T.LaunchArc[2], T.LaunchArc[3], T.LaunchArc[4]
	-- the caster's own first-person launch: the arcs are rooted round the body the camera sits in, so each fades out
	-- near the lens (the comic build's proximity fade; RegisterProximityFade cannot fade Beams)
	local lens = self.own and firstPersonNow()
	for i, A in ipairs(self.launch) do
		local fr = Random.new(self.seed * 131 + i * 17 + f * 7919)
		local a = A.root + A.d * (A.len * T.LaunchDetach[f + 1])
		local b = A.root + A.d * (A.len * T.LaunchReach[f + 1])
		local pts = Kit.jag(a, b, 3, 0.26 * A.len, fr)
		local al = lens and lensFade(pts, c.camPos) or 1
		if f < 2 then
			local k = T.LaunchFade[f + 1] * self.kb
			local wk = f == 0 and 1 or 0.75
			if al > 0.01 then
				self:beam(g, pts, cw * wk, gw * wk, COL.Light, cb * k, COL.Base, gb * k, al < 1 and { a = al } or nil)
			end
			if A.fork then
				local j = math.clamp(math.floor(#pts / 2) + 1 + fr:NextInteger(-1, 1), 1, #pts)
				local fd = (A.d + perpRand(A.d, fr) * 0.9).Unit
				local fp = Kit.jag(pts[j], pts[j] + fd * (A.len * 0.42), 2, 0.12 * A.len, fr)
				local fa = lens and math.min(al, lensFade(fp, c.camPos)) or 1
				if fa > 0.01 then
					self:beam(g, fp, cw * wk * 0.7, gw * wk * 0.7, COL.Light, cb * k * 0.9, COL.Base, gb * k * 0.9,
						fa < 1 and { a = fa } or nil)
				end
			end
		elseif al > 0.01 then
			-- the outer tips, cooling
			self:beam(g, pts, cw * 0.6, 0, COL.Dark, 3.0 * 0.45 * self.kb, nil, 0,
				al < 1 and { ember = true, a = al } or EMBER)
		end
	end
	-- the chest glow on the press frame only, drawn in front of the torso (not on the caster's own first-person lens)
	if f == 0 and not (self.own and firstPersonNow()) then
		self:sprite(g, self.chest, T.LaunchGlow[1] * 2, COL.Light, 1, T.LaunchGlow[2] * self.kb, T.LaunchGlow[3])
	end
	-- the flash: at the chest, then x0.10 at Range 3.5 behind the start point (clear of the caster), then off
	local k = (self.calm and T.CalmLaunchFlashK or T.LaunchFlashK)[f + 1] * (self.calm and T.CalmFlash or 1)
	local pos = f == 0 and self.chest + towardCamH(self.chest, c.camPos, 0.6) or self.cf0 * Vector3.new(0, 0.6, 1.5)
	self:light("launch", pos, T.LaunchFlash[1] * k, f == 0 and T.LaunchFlash[2] or T.LaunchFlash[3])
end

-- 2 STREAK -------------------------------------------------------------------------------------------------------------
function Dash:drawStreak(fno)
	local g = self:group("streak")
	local cw, gw, cb, gb = T.StreakArc[1], T.StreakArc[2], T.StreakArc[3], T.StreakArc[4]
	local kb = self.kb
	for _, fr in ipairs(self.streak) do
		local age = fno - fr.f
		if age >= 0 and age < 3 then
			if not fr.stamped then self:stamp(fr) end
			local rng = Random.new(fr.seed + age * 7919)
			local half = fr.dw * (fr.len / 2)
			local pts = Kit.jag(fr.c - half, fr.c + half, 3, 0.30 * fr.len, rng)
			if age == 2 then
				self:beam(g, pts, cw * 0.9, 0, COL.Dark, 3.2 * 0.45 * kb, nil, 0, EMBER)
			else
				local wk, bk = 1, 1
				if age == 1 then wk, bk = T.StreakMid[1], T.StreakMid[2] end
				self:beam(g, pts, cw * wk, gw * wk, COL.Light, cb * bk * kb, COL.Base, gb * bk * kb)
				if fr.fork then
					local j = math.min(#pts, 4 + rng:NextInteger(0, 2))
					local q = pts[j] + perpRand(fr.dw, rng) * rng:NextNumber(0.2, 0.3)
					self:beam(g, Kit.jag(pts[j], q, 1, 0.08, rng), cw * wk * 0.7, gw * wk * 0.6, COL.Light,
						cb * bk * kb * 0.9, COL.Base, gb * bk * kb * 0.9)
				end
			end
		end
	end
end

-- 3 LANDING ------------------------------------------------------------------------------------------------------------
function Dash:drawLanding(fno, tq)
	local fl = fno - self.landF
	if fl >= 0 and fl <= 2 then
		local g = self:group("land")
		local cw, gw, cb, gb = T.LandArc[1], T.LandArc[2], T.LandArc[3], T.LandArc[4]
		-- the caster's own first person: arcs near the lens fade out, as the launch's do (seen in Studio: the landing
		-- burst covered the target for its 3 frames)
		local cam = (self.own and firstPersonNow()) and workspace.CurrentCamera or nil
		local camPos = cam and cam.CFrame.Position or nil
		for i, A in ipairs(self.landArcs) do
			local fr = Random.new(self.seed * 137 + i * 17 + fl * 7919)
			local len = (A.b - A.a).Magnitude
			if fl == 2 then
				if not A.root then                          -- the roots have become the tendrils
					local pts = Kit.jag(A.a:Lerp(A.b, 0.45), A.b, 2, 0.2 * len, fr)
					local al = camPos and lensFade(pts, camPos) or 1
					if al > 0.01 then
						self:beam(g, pts, cw * 0.6, 0, COL.Dark, 3.0 * 0.4 * self.kb, nil, 0,
							al < 1 and { ember = true, a = al } or EMBER)
					end
				end
			else
				local pts = Kit.jag(A.a, A.b, 3, 0.22 * len, fr)
				local k = T.LandFade[fl + 1] * self.kb
				local wk = fl == 0 and 1 or 0.7
				local al = camPos and lensFade(pts, camPos) or 1
				if al > 0.01 then
					self:beam(g, pts, cw * wk, gw * wk, COL.Light, cb * k, COL.Base, gb * k, al < 1 and { a = al } or nil)
				end
			end
		end
	end
	-- the floor flash: one frame full, then half decaying (Reduce Flashing: half, eased in)
	local fb, range, fd = T.LandFlash[1], T.LandFlash[2], T.LandFlash[3]
	local e = tq - self.tLandF
	if e > -TOL and e < F + fd then
		e = math.max(0, e)
		local b
		local fall = (1 - clamp01((e - F) / fd)) ^ 2
		if self.calm then
			b = fb * T.CalmFlash * (e < F - TOL and 0.5 or fall)
		else
			b = e < F - TOL and fb or fb * 0.5 * fall
		end
		self:light("land", self.foot + self.dir * 1.0 + Vector3.new(0, 0.3, 0), b, range)
	end
end

function Dash:step(c)
	if self.dead then return false end
	local t = Kit.clock(self.born)
	local fno = math.floor(t * 60 + FRAME_TOL)
	local tq = fno / 60
	local ch = self.character

	-- the landing frame starts the climb: an unconfirmed tell (not after an Off heard since this cast, nor over a live one)
	if not self.tellMade and fno >= self.landF then
		self.tellMade = true
		if ch and alive(ch) then
			local off, live = lastOff[ch], primed[ch]
			if not (off and off >= self.born) and not (live and not live.dead) then
				local tell = newTell(ch, self)
				primed[ch] = tell
				tell:start()
			end
		end
	end
	-- the tell, locally, at TellDelay if OverchargePrimed has not brought it yet (and no Off has cancelled it)
	if not self.told and t >= self.tellDelay then
		self.told = true
		if ch and pending[ch] == self then
			pending[ch] = nil
			if alive(ch) then OverchargeFX.SetPrimed(ch, true) end
		end
	end

	if not c.cam then return t < self.life end
	self:beginFrame(c)
	self:drawLaunch(fno, c)
	self:drawStreak(fno)
	if not self.thin and tq >= 0 and tq < self.dashTime + 0.05 then
		-- 1.5 studs behind the body at knee height: it lights the floor under the trail, never the torso
		local k = tq < self.dashTime and 1 or 1 - (tq - self.dashTime) / 0.05
		local along = self.L * self:dashU(tq) - 1.5
		if self.own then
			-- the caster's own client: never ahead of its real root (1.5 behind it along the dash)
			local root = ch and bodyPart(ch, "HumanoidRootPart")
			if root then along = math.min(along, (root.Position - self.floorFrom):Dot(self.dir) - 1.5) end
		end
		self:light("dash", self:pathPoint(along, 0.8, 0), T.DashLight[1] * k, T.DashLight[2])
	end
	self:drawLanding(fno, tq)
	self:endFrame()

	-- Bloom: the caster's own dash only (the kit skips it under Reduce Flashing and in first person)
	if self.own and not self.calm then
		if not self.bloomL and fno <= 1 then
			self.bloomL = true
			pcall(Kit.bloomPulse, T.LaunchBloom[1], T.LaunchBloom[2], T.LaunchBloom[3], 0)
		end
		if not self.bloomD and fno >= self.landF and fno <= self.landF + 1 then
			self.bloomD = true
			pcall(Kit.bloomPulse, T.LandBloom[1], T.LandBloom[2], T.LandBloom[3], 0)
		end
	end
	return t < self.life
end

function Dash:onDestroy()
	local ch = self.character
	if ch and pending[ch] == self then pending[ch] = nil end
end

--- Where the floor is under a root position (VFXLibrary.GroundBelow through bodies; else the root's own drop).
local function floorFinder(character)
	local exclude = { Kit.fxFolder() }
	if workspace.CurrentCamera then exclude[#exclude + 1] = workspace.CurrentCamera end
	if character then exclude[#exclude + 1] = character end
	local dropY = rootDrop(character)
	return function(p)
		local V = VFXLibrary
		if V and type(V.GroundBelow) == "function" then
			local ok, hit, _, inst = pcall(V.GroundBelow, p, exclude)
			if ok and typeof(hit) == "Vector3" and inst ~= nil then return hit end
		end
		return p - Vector3.new(0, dropY, 0)
	end
end

--- The dash's plans, rolled once per cast: the launch arcs, the streak fragments, the landing arcs.
function Dash:plan()
	local seed = self.seed
	-- 1 LAUNCH: all round, weighted back down the path; each root on the body's surface
	local rr = Random.new(seed * 3 + 101)
	local DIRL = Vector3.new(0, 0, -1)
	local chestL = Vector3.new(0, T.Chest, 0)
	self.launch = {}
	for i = 1, (self.thin and T.ThinLaunchArcs or T.LaunchArcs) do
		local d = DIRL
		for _ = 1, 40 do
			d = (rr:NextUnitVector() - DIRL * 0.30).Unit
			if d:Dot(DIRL) < T.LaunchForward then break end
		end
		local h = rr:NextNumber(-1.2, 1.3)
		local len = rr:NextNumber(T.LaunchLen[1], T.LaunchLen[2])
		local fork = rr:NextNumber() < T.LaunchFork
		local dx, dz = math.abs(d.X), math.abs(d.Z)
		local exit = math.min(dx > 1e-3 and 2.0 / dx or 1e9, dz > 1e-3 and 0.5 / dz or 1e9, 3.0)
		local dh = Vector3.new(d.X, 0, d.Z)
		local rootL = chestL + Vector3.new(0, h, 0) + (dh.Magnitude > 1e-3 and dh * exit or Vector3.zero) + d * 0.4
		self.launch[i] = { root = self.cf0 * rootL, d = self.cf0:VectorToWorldSpace(d), len = len, fork = fork }
	end
	self.chest = self.cf0 * chestL

	-- 2 STREAK: two fragments a frame the body moves (one on the arrival frame), in the stretch its back just swept
	local rs = Random.new(seed * 5 + 303)
	local nf = self.landF
	local L = self.L
	self.streak = {}
	for f = 1, nf do
		local xNow = L * self:dashU(math.min(f * F, self.dashTime))
		local xPrev = L * self:dashU((f - 1) * F)
		local backNow, backPrev = xNow - 0.5, xPrev - 0.5
		local n = (f < nf and not self.thin) and 2 or 1
		local bands = sample(T.StreakBands, n, rs)
		for j = 1, n do
			local rung = rs:NextNumber() < T.StreakRung
			local len = rung and rs:NextNumber(T.RungLen[1], T.RungLen[2]) or rs:NextNumber(T.StreakLen[1], T.StreakLen[2])
			local halfX = rung and 0.15 or len / 2
			local hi = backNow - T.StreakBehind - halfX
			local lo = math.min(backPrev - halfX, hi) - 0.3
			local cx = rs:NextNumber(lo, hi)
			local y = bands[j] + rs:NextNumber(-0.18, 0.18)
			local z = rs:NextNumber(-T.StreakSide, T.StreakSide) * 0.6
			local d -- (along the dash, up, to its right)
			if rung then
				d = Vector3.new(rs:NextNumber(-0.35, 0.35), 1, rs:NextNumber(-0.35, 0.35)).Unit
			else
				local pitch, yaw = math.rad(rs:NextNumber(-35, 35)), math.rad(rs:NextNumber(-12, 12))
				d = Vector3.new(math.cos(pitch) * math.cos(yaw), math.sin(pitch), math.cos(pitch) * math.sin(yaw))
			end
			-- its whole extent along the dash: the length, its 30 % jag, a fork
			local ext = math.abs(d.X) * len / 2 + 0.3 * len * math.sqrt(math.max(0, 1 - d.X * d.X)) + 0.3
			self.streak[#self.streak + 1] = { f = f, cx = cx, y = y, z = z, d = d, len = len, ext = ext,
				seed = rs:NextInteger(0, 1000000), fork = (not self.thin) and rs:NextNumber() < 0.5, stamped = false }
		end
	end

	-- 3 LANDING: two roots straight out to the sides and back (the tendrils climb from their tips), the rest ahead
	local rl = Random.new(seed * 11 + 202)
	local cf = self.landCF
	self.landArcs = {}
	for _, s in ipairs(SIGNS) do
		self.landArcs[#self.landArcs + 1] = { a = cf * Vector3.new(0.55 * s, 0.10, 0.25),
			b = cf * Vector3.new(2.0 * s, 0.10, 1.2), root = true }
	end
	for _ = 1, (self.thin and T.ThinLandArcs or T.LandArcs) - 2 do
		local yaw = math.rad(rl:NextNumber(-T.LandSpread, T.LandSpread))
		local d = Vector3.new(math.sin(yaw), 0, -math.cos(yaw))
		local r1 = rl:NextNumber(T.LandReach[1], T.LandReach[2])
		local a = d * 0.6 + Vector3.new(0, 0.10, -0.2)
		local b = d * r1 + Vector3.new(0, rl:NextNumber(0.10, 0.35), -0.2)
		self.landArcs[#self.landArcs + 1] = { a = cf * a, b = cf * b, root = false }
	end
end

----------------------------------------------------------------------------------------------------
-- 5 THE RELEASE
----------------------------------------------------------------------------------------------------
local Release = setmetatable({}, { __index = Canvas })
Release.__index = Release

--- The firing hand: the caster's muzzle / grip while it stays near fromPos, else fromPos.
function Release:hand()
	local ok, m = pcall(Kit.muzzle, self.character, self.sd)
	if ok and typeof(m) == "Vector3" and (m - self.from).Magnitude < T.HandSlack then self.lastHand = m end
	return self.lastHand
end

--- Two short arcs converging on the hand from in front of the body: the firing side's up from the hip, the other
--- across the chest under the raised arm (mirrored for a left-hand shot).
function Release:drawGather(H)
	local ch = self.character
	local root = bodyPart(ch, "HumanoidRootPart")
	if not root then return end
	local rcf = root.CFrame
	local feet = CFrame.new(rcf.Position - rcf.UpVector * rootDrop(ch)) * rcf.Rotation
	local s = self.sign
	local g = self:group("G")
	local cw, gw, cb, gb = T.Tendril[1], T.Tendril[2], T.Tendril[3], T.Tendril[4]
	for i = 1, 2 do
		local start, mid
		if i == 1 then
			start, mid = feet * Vector3.new(1.3 * s, 1.5, -1.3), feet * Vector3.new(1.1 * s, 2.7, -1.5)
		else
			start, mid = feet * Vector3.new(-1.6 * s, 2.3, -1.1), feet * Vector3.new(0.6 * s, 2.5, -1.9)
		end
		local rr = Random.new(self.seed + 3100 + (i == 1 and 1 or -1))
		local pts = Kit.jag(start, mid, 2, 0.22, rr)
		local b = Kit.jag(mid, H, 2, 0.2, rr)
		for j = 2, #b do pts[#pts + 1] = b[j] end
		local n = #pts
		local cwl, whs = table.create(n), table.create(n)
		for j = 1, n do
			local u = (j - 1) / (n - 1)
			cwl[j] = cw * (j == 1 and 0.2 or 0.7 + 0.6 * u)
			whs[j] = 0.8 * u ^ 3
		end
		self:beam(g, pts, cwl, gw, COL.Light, cb * self.kb * 1.1, COL.Base, gb * self.kb * 1.1, { gstep = 2, wh = whs })
	end
end

--- Frame 0, the press: the hold routes as violet embers riding the arm now, the gather, the hand flare.
function Release:drawPress(H, c)
	local fp = self.own and firstPersonNow()
	local sc = fp and T.FpScale or 1
	if not self.early then
		local g = self:group("E")
		local cw = T.Tendril[1]
		for _, Fz in ipairs(self.frozen) do
			local R = Fz.rig
			local ok
			if fp then
				local okc, cp = pcall(Kit.castPoint, Fz.sd)
				ok = okc and typeof(cp) == "Instance" and fpRig(R, cp, Fz.sign, c.right)
			else
				ok = bodyRig(R, self.character, Fz.sd, Fz.sign, gripFor(self.character, Fz), nil)
			end
			if ok then
				local pw = mapList(R, Fz.main, fp and firstBelow(Fz.main, T.FpFrom) or 1)
				self:beam(g, pw, cw * 1.4 * R.w, 0, COL.Dark, 3.0 * T.EmberGather * self.kb, nil, 0, EMBER3)
			end
		end
		if not fp then self:drawGather(H) end
	end
	self:sprite(self:group("F"), H, T.HandFlare[1] * 2 * sc, COL.Light, 1, T.HandFlare[2] * self.kb, T.HandFlare[3] * sc)
	self:light("hand", H + Vector3.new(0, 0.3, 0) + towardCamH(H, c.camPos, 0.5),
		T.TendrilLight[1] * 1.3 * self.kb, T.TendrilLight[2])
end

--- Frame 1: the bolt is on and the body bare. Two strands wound round the hand -> A line, pinched to the palm, at half
--- brightness to 55 %, and one comet head stretched along it (strand_path / release_frame on the straight line).
function Release:drawCharge(H, c)
	local A = self.target
	if not A then return end
	local total = (A - H).Magnitude
	if total < 0.5 then return end
	local d = (A - H) / total
	local kb = self.kb
	local cw, gw, cb, gb = T.Tendril[1], T.Tendril[2], T.Tendril[3], T.Tendril[4]
	local nd = T.BoltSegs * 6
	local dense = table.create(nd + 1)
	for i = 0, nd do dense[i + 1] = H:Lerp(A, i / nd) end
	local g = self:group("S")
	local camPos = c.camPos
	local away = (H + A) / 2 - camPos
	away -= d * away:Dot(d)
	local n1 = d:Cross(safeUnit(away, perpAny(d)))           -- Chain Bolt's jog axis: square to the bolt and the view
	local n2 = d:Cross(n1)
	local at = T.Comet[1]
	for _, sign in ipairs(SIGNS) do
		local rr = Random.new(self.seed + 4242 + sign)
		local th0 = sign > 0 and 0 or math.pi
		local path = table.create(nd + 1)
		for i = 1, nd + 1 do
			local s = (i - 1) / nd
			local th = th0 + 2 * math.pi * T.StrandTurns * s
			local r = s < 0.15 and (s / 0.15) * T.StrandR[1] or lerp(T.StrandR[1], T.StrandR[2], (s - 0.15) / 0.85)
			local jit = Vector3.new(rr:NextNumber(-1, 1), rr:NextNumber(-1, 1), rr:NextNumber(-1, 1))
				* ((i > 1 and i <= nd) and 0.10 or 0)
			path[i] = dense[i] + (n1 * math.cos(th) + n2 * math.sin(th)) * r + jit
		end
		local acc = arclen(path)
		local pts = cutPath(path, acc, 0, acc[#acc] * at)
		local n = #pts
		if n >= 2 then
			local cwl = table.create(n)
			for i = 1, n do cwl[i] = cw * 0.8 * (i == 1 and 0.2 or 1) end
			self:beam(g, pts, cwl, gw * 0.7, COL.Light, cb * kb * 0.5, COL.Base, gb * kb * 0.5, GSTEP2)
		end
	end
	-- the comet: its head at the middle of the bolt segment that holds 55 %, tapering back to a point, no round glow
	local accD = arclen(dense)
	local len = accD[#accD]
	local j = math.max(1, math.ceil(at * T.BoltSegs - 1e-6))
	local head = len * (j - 0.5) / T.BoltSegs
	local pts, ss = cutPath(dense, accD, math.max(0, head - len * T.Comet[2]), head)
	local n = #pts
	if n < 2 then return end
	local toward = safeUnit(camPos - H, Vector3.zero) * 0.25
	local span = math.max(1e-6, ss[n] - ss[1])
	local cwl, gwl, ks, whs = table.create(n), table.create(n), table.create(n), table.create(n)
	for i = 1, n do
		pts[i] = pts[i] + toward
		local u = (ss[i] - ss[1]) / span
		cwl[i] = (i > 1 and i < n) and T.Comet[3] * (0.15 + 0.85 * u) or 0
		gwl[i] = T.Comet[4] * (0.35 + 0.65 * u)
		ks[i] = 0.6 + 0.4 * u
		whs[i] = u ^ 1.5
	end
	self:beam(g, pts, cwl, gwl, COL.Light, 3.8 * kb, COL.Light, 1.6 * kb, { gstep = 1, k = ks, wh = whs })
	self:light("hand", pts[n], T.TendrilLight[1] * kb, T.TendrilLight[2])
end

function Release:step(c)
	if self.dead then return false end
	local t = Kit.clock(self.born)
	-- at most one beat per render: under 60 fps (or after a hitch) frame 1 is still drawn once before the end
	local f = math.min(math.floor(t * 60 + FRAME_TOL), (self.lastF or -1) + 1)
	if f >= 2 then return false end                      -- frame 2 on: nothing (the hit is Chain Bolt's plain one)
	if not c.cam then return true end
	self.lastF = f
	self:beginFrame(c)
	local H = self:hand()
	if f <= 0 then
		self:drawPress(H, c)
	elseif not self.early then
		self:drawCharge(H, c)
	end
	self:endFrame()
	return true
end

----------------------------------------------------------------------------------------------------
-- THE API
----------------------------------------------------------------------------------------------------
--- Plays the dash beats. data = the Overcharge broadcast { Character, From: Vector3, To: Vector3, T0 } (From / To are the
--- root's start and end; T0 only drops a stale one; Own = true marks VoltaicClient's own predicted dash). Starts the
--- climb at the landing, and owes the local tell at TellDelay unless SetPrimed(Character, false) comes first -- except
--- for an Own cast, whose tell is VoltaicClient's (it waits for the server's broadcast).
function OverchargeFX.Cast(data)
	if not RunService:IsClient() then return end
	if type(data) ~= "table" or typeof(data.From) ~= "Vector3" or typeof(data.To) ~= "Vector3" then return end
	if not libs() then return end
	if type(data.T0) == "number" and Kit.clock(data.T0) > T.Stale then return end
	local character = (typeof(data.Character) == "Instance" and data.Character:IsA("Model")) and data.Character or nil
	local from, to = data.From, data.To
	local flatD = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local root = character and bodyPart(character, "HumanoidRootPart")
	local dir
	if flatD.Magnitude > 1e-3 then
		dir = flatD.Unit
	else
		local look = root and root.CFrame.LookVector
		look = look and Vector3.new(look.X, 0, look.Z)
		dir = (look and look.Magnitude > 1e-3) and look.Unit or Vector3.new(0, 0, -1)
	end
	local floorAt = floorFinder(character)
	local floorFrom, floorTo = floorAt(from), floorAt(to)

	local self = setmetatable({}, Dash)
	self:initCanvas("Overcharge", character, from)
	self.character = character
	self.own = character ~= nil and kitFlag(Kit.isOwn, character)
	self.seed = seedFrom(data.T0 or Kit.serverNow(), character)
	self.born = Kit.serverNow()
	self.dir, self.L, self.to = dir, flatD.Magnitude, to
	self.floorFrom, self.floorTo = floorFrom, floorTo
	self.cf0 = CFrame.lookAt(floorFrom, floorFrom + dir)
	self.right = self.cf0.RightVector
	self.landCF = CFrame.lookAt(floorTo, floorTo + dir)
	self.foot = floorTo + Vector3.new(0, 0.12, 0) + dir * 0.2
	self.dashTime = tun("Time", T.DashTime)
	self.landF = math.ceil(self.dashTime * 60 - 1e-6)
	self.tLandF = self.landF / 60
	self.tellDelay = tun("TellDelay", T.TellDelay)
	self.life = math.max(self.tLandF + F + T.LandFlash[3] + F, self.tLandF + 3 * F, self.tellDelay) + F
	self.deadline = os.clock() + (self.life + 0.5) / self.ts
	Debris:AddItem(self.folder, (self.life + 2) / self.ts)   -- the backstop: even a runner that never ran cannot orphan it
	self:plan()
	if character then
		if data.Own ~= true then pending[character] = self end
		lastCast[character] = self.born
	end
	self:start()
end

--- The primed tell on `character`: on = true confirms the climb, re-confirms a live tell (the watchdog restarts) or
--- starts one whole; on = false ends it (the M1, the ChainBolt broadcast, OverchargePrimed Off, a loadout change) and
--- cancels a local one still owed by Cast.
function OverchargeFX.SetPrimed(character, on)
	if not RunService:IsClient() then return end
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return end
	if not libs() then return end
	local live = primed[character]
	if live and live.dead then
		primed[character] = nil
		live = nil
	end
	if on then
		-- the server's late On for a prime this client's own M1 already spent (its Off came after the last cast heard)
		local offAt, castAt = lastOff[character], lastCast[character]
		if offAt and (castAt == nil or offAt > castAt) and Kit.clock(offAt) < T.OffGuard then return end
		pending[character] = nil
		if live then
			live:confirm()
			return
		end
		if not alive(character) then return end
		local tell = newTell(character, nil)
		tell:confirm()
		primed[character] = tell
		tell:start()
	else
		pending[character] = nil
		lastOff[character] = Kit.serverNow()
		if live then live:Destroy() end
	end
end

--- Whether the tell is up on `character` right now (a climb not yet confirmed does not count).
function OverchargeFX.IsPrimed(character)
	local live = character and primed[character]
	return live ~= nil and not live.dead and live.confirmed == true
end

--- The primed shot's release (showcase beat 5), drawn from the press: call it BEFORE SetPrimed(character, false), so
--- the tell's routes can be frozen. side "R" / "L" (the firing hand); fromPos the hand (nil: Kit.muzzle); points the
--- ChainBolt Points (Points[1] = A, or End). opts: T0 (a broadcast's: a stale one draws nothing), End.
function OverchargeFX.Release(character, side, fromPos, points, opts)
	if not RunService:IsClient() then return nil end
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return nil end
	if not libs() then return nil end
	opts = type(opts) == "table" and opts or {}
	if type(opts.T0) == "number" and Kit.clock(opts.T0) > T.Stale then return nil end
	local sd = side == "L" and "L" or "R"
	local hand = typeof(fromPos) == "Vector3" and fromPos or nil
	if not hand then
		local ok, m = pcall(Kit.muzzle, character, sd)
		hand = (ok and typeof(m) == "Vector3") and m or nil
	end
	if not hand then return nil end
	local pts = vectors(points)
	local target = pts[1] or (typeof(opts.End) == "Vector3" and opts.End or nil)
	-- the tell's routes as they stand (it is still up: SetPrimed(false) comes after this call)
	local tell = primed[character]
	local live = tell ~= nil and not tell.dead
	-- no tell, and this client already ended the prime since the last cast it heard (its own earlier M1 spent it): a
	-- second M1 inside the round trip still reads the server's VoltPrimedUntil, but there is nothing left to release
	local offAt, castAt = lastOff[character], lastCast[character]
	if not live and offAt and (castAt == nil or offAt > castAt) then return nil end
	local frozen, early = {}, false
	if live then
		frozen = tell:freeze()
		early = Kit.clock(tell.born) < tell.tGrown - TOL      -- an M1 still climbing: the flare alone
	elseif lastCast[character] then
		-- no tell yet: an M1 in the dash itself (before the climb) is early too
		local grown = math.ceil(tun("Time", T.DashTime) * 60 - 1e-6) / 60 + T.Grow
		early = Kit.clock(lastCast[character]) < grown - TOL
	end
	local self = setmetatable({}, Release)
	self:initCanvas("OverchargeRelease", character, hand)
	self.character, self.sd, self.sign = character, sd, sd == "L" and -1 or 1
	self.own = kitFlag(Kit.isOwn, character)
	self.from, self.lastHand, self.target = hand, hand, target
	self.frozen, self.early = frozen, early
	self.seed = seedFrom(opts.T0 or Kit.serverNow(), character)
	self.born = Kit.serverNow()
	self.deadline = os.clock() + T.MaxLife / self.ts + 0.5
	Debris:AddItem(self.folder, T.MaxLife / self.ts + 2)
	self:start()
	return handle(self)
end

--- EXTRA: clears everything in flight (a round reset, a harness).
function OverchargeFX.Clear()
	for i = #objs, 1, -1 do
		local o = objs[i]
		if not o.dead then o:Destroy() end
	end
	table.clear(pending)
end

return OverchargeFX
