--[[
	ZephyrFX_CrossSlash  (ReplicatedStorage.IceMagic.ZephyrFX_CrossSlash, ModuleScript, CLIENT ONLY)   Zephyr v6, 2026-10-06

	The look of Zephyr's Primary, CROSS-SLASH DASH: the v6 glow kit, which REPLACES the toon-ink look outright (the
	owner's decision), ported from its Blender frame functions onto ZephyrDraw (same folder):
	    blender_scripts/zephyr/aqua/cross_slash_v6.py   the takeoff vapor rings, the wrist ribbons through the snap, the
	                                                     lobed vapor dome after the X, the own-view punch and dash streaks,
	                                                     and the aqua light riding charge -> dash -> X
	    blender_scripts/zephyr/aqua/cross_slash_v5.py   the faster fourth charge arm and the dust pulled from the feet, the
	                                                     stronger vapor tunnel, the afterimage, the faint X scuff
	    blender_scripts/zephyr/aqua/cross_slash_v4.py   the charge spiral and its arcs, the dash streak, helix, tunnel and
	                                                     veil, the scuff trench, THE X, its arcs and small vapor ring, the
	                                                     particles
	    blender_scripts/zephyr/spring/cross_slash_dash_bl.py   the timeline (T_GO, T_ARR, T_SNAP0/1, T_S1, T_S2, T_X,
	                                                     T_DIS) and the dash's velocity profile (Demo's ghost)
	Every shape, count, width, envelope and seed in the frame functions below is the Blender script's, quoted where it is
	used (the RadiantFX_Hand precedent). Tuning holds only what the port itself decides -- the own view, the held charge,
	the floor, quality, the Beam knots -- and marks every guess PROVISIONAL (v6 import).

	WHO CALLS IT. ZephyrFX's Cross-Slash functions, and nothing else in play. ZephyrFX keeps everything that is not
	drawing, byte for byte -- the cast's frame (CrossSlashFrame), its clock (CrossSlashTiming / CrossSlashTime) and the
	per-character cast record behind CrossSlash / CrossSlashLaunch / CrossSlashCancel / CrossSlashTimingOf /
	CrossSlashClock, which SpellshotInput, AbilityFX, CastPose, the Viewmodel and ZephyrHandler read -- and hands each
	call here, pcall-guarded. The test harness (ZephyrTestHarness) calls Demo. Nothing runs at require: the module is
	inert on the server, every require is lazy, and the one RenderStep is ZephyrDraw's, bound only while a look lives.

	API   (CrossSlash = require(IceMagic.ZephyrFX_CrossSlash))
	  CrossSlash.Play(character, dir, timing, opts) -> handle | nil
	        a cast's look on `character` (one per character: a new one ends the last). dir: the dash's 3D direction, or
	        nil while the key is held (the charge faces the way the body faces). timing: the cast's
	        ZephyrFX.CrossSlashTiming, the clock the look runs on. opts.Target: a Model to stamp the X on (nothing sends
	        one in play since the dash stopped locking targets). Demo also passes Ghost, Own and FreezeLook.
	  CrossSlash.Launch(character, dir) -> bool   the held cast launched: from here the look runs along `dir`
	  CrossSlash.Cancel(character)               a held cast dropped before its launch: its look ends at once (a
	                                             launched one plays on, as the toon look's did)
	  CrossSlash.Stop(character) / CrossSlash.StopAll() / CrossSlash.Active(character) -> bool
	  CrossSlash.Demo(character, opts) -> { Stop(), Canvas, Handle } | nil   see DEMO;  CrossSlash.StopDemo()
	  CrossSlash.ToKit(t) / CrossSlash.FromKit(b)   the clock map below;  CrossSlash.Beats (the kit's timeline);
	  CrossSlash.Tuning

	THE CLOCK. The look runs on the cast's own clock, ZephyrFX.CrossSlashTime: look seconds from the press, holding at
	HoldPose while the key is held, catching up to ChargeTime by the launch, stretching its glide (ChargeTime ..
	ChargeTime + DashTime) over the charged glide, and 1:1 after it. The kit is written in its own seconds ("b"), so every
	frame maps the look's t onto them, piecewise linear, landing the kit's beats on the game's:
	      look t   0 ......... ChargeTime 0.30 ......... ChargeTime + DashTime 0.80 ......... Trigger 0.92 ......... 1:1
	      kit  b   0 ......... T_GO 0.50 (takeoff) ..... T_ARR 0.76 (arrival) ................ T_X 0.861 (THE X) .... 1:1
	  The launch is the kit's takeoff, the end of the glide its arrival, and the Trigger -- the strike: the arms fling
	  open and the hit is reported -- the X's crossing instant (the flash, the bursts, the dome). The two slices draw from
	  T_S1 / T_S2 (b 0.827 / 0.849, look 0.879 / 0.905), just before it, as the kit's do before its X.
	  What follows the body's own path (the dash ribbons, the tunnel, the wrist ribbons) samples a HISTORY of where the
	  body really was, kept by kit time, so a 12-stud tap and a 40-stud charged glide both trail the kit's share of their
	  dash. What turns (the charge spiral, its arcs) keeps turning through a held charge, where the look's clock stands
	  still: its phase runs on the press's real clock. The kit's arrival speed ramp (0.6x -> 0.2x -> the 0.1x hit-stop ->
	  1.3x) is CAMERA time only: in game nothing slows, and the X's hold (T_X -> T_DIS, 0.33 s) and flash are all that is
	  kept of it.

	WHAT IS DRAWN (kit seconds; the Blender function in brackets)
	  CHARGE  0.10 -> 0.58  [v4 charge, v5 charge] an open spiral round the crossed hands on the chest's forward axis: a
	          white-hot core and three teal arms, 300 deg each, winding in to 0.28 of a radius that tightens 2.6 -> 1.1,
	          plus v5's faster fourth arm; 10 pointed arcs orbiting; dust and specks pulled up off the floor round the
	          feet, puffs drawn in, 8 sparks at 0.30. A HELD charge (no kit beat: the kit's charge is a tap) keeps the
	          wound spiral turning, keeps pulling dust, and glows more the longer it is held (Tuning.Hold*)
	  TAKEOFF 0.49 -> 0.92  [v6 takeoff] two vapor rings round the dash axis left behind at the launch (0.7 -> 3.6 studs),
	          22 puffs thrown back
	  SNAP    0.44 -> 0.90  [v6 trails] a core and a glow ribbon trailing each hand through the snap
	  DASH    0.50 -> 1.36  [v4 dash, v5 dash] the streak (core), 3 helix glow ribbons, 6 + 4 spiralling vapor ribbons (the
	          tunnel), the shimmer veil (Roblox has no refraction: a faint vapor strip, the handoff's stand-in), the scuff
	          trench on the floor, dust / specks / chips / mist peeling off the path
	  THE X   0.83 -> 1.74  [v4 x_stamp] two cuts drawing on tip first and crossing at T_X: each a white-hot core, three
	          teal glow ribbons and a soft wide one, flat in the X's plane; a glow pulse on the crossing (the flash); 16
	          orbiting arcs; ONE small vapor ring (the owner had the two big shock rings removed). It holds 0.33 s, then
	          frays from its ends, drifting apart and sinking
	  AFTER   1.14 -> 2.09  [v5 x_stamp] the afterimage, four soft sheared ribbons thinning; the faint X scuff on the floor
	  DOME    0.86 -> 2.01  [v6 shock] the wide lobed vapor dome: a hemisphere 0.62 high to wide, radius 1.4 -> 7.6 studs
	          over 1.15 s, an open crown, wispy lobes in its alpha; a vapor ring at its foot
	  BURST   at T_X        dust and chips at the feet under the X; chips, sparks, puffs, specks and mist off the crossing
	  LIGHT   one soft aqua PointLight: ahead of the chest through the charge (380 W) and the dash (700 W); at the X its
	          flash (2600 W, tau 0.22 s, with the kit's 900 W flash bulb folded in) and the dome's 260 W tail; range 10,
	          18 from the X. ZephyrDraw turns watts into Brightness (W / 600, capped)
	The look ends at b 3.35 (the scuffs gone) -- longer than the cast record in ZephyrFX, which keeps the toon look's
	1.40 so nothing that asks for a cast's clock sees it any longer than before.

	WHERE THE X STAMPS. The kit stamps its X on dummy 1, which its dash went THROUGH, and skid-turns the caster back to
	face it. The game's strike reaches AHEAD of the body (ZephyrFX.Tuning.CrossSlash Reach / HalfWidth / HalfHeight), and
	the toon look stamped its X there: StopShort ahead of the root as the glide ends, 1.2 up -- or on opts.Target's
	chest. The port keeps the game's spot, so you see your own X in first person where its hit lands. The X's plane faces
	each viewer's camera as it stamps, upright (v4's XN: the FLAT direction to its hero camera) and then stays where it
	is; the dome, the scuff
	and the feet's dust stand on the floor under it (none of the three without a floor within XFloorReach).

	OWN VIEW (your own cast from your own eyes: the camera within OwnNear of your Head)
	  * NO charge spiral: the toon look never drew its charge swirl to a camera that close, and the plan keeps every
	    own-view rule (Tuning.OwnCharge = true draws it round the Viewmodel's fists at the kit's fp 0.55 radius);
	  * the wrist ribbons drawn off the fists in the CAMERA's frame: the arms' snap, not the dash smeared past the lens;
	  * NO core, glow helix or veil down the view axis: the vapor tunnel wraps a path 5 studs ahead of you, so it passes
	    as peripheral streaks (the kit's fp rule); no takeoff rings (they are left behind you);
	  * the X at OwnXScale of its size (it lands a few studs ahead, not on a dummy 15 studs off), the dome at half;
	  * 16 radial dash streaks rushing past the view at 46 studs/s, through the glide;
	  * ZephyrDraw.CameraKick: an FOV punch (+30 %) at takeoff, eased out over the glide, and a 10 % zoom jolt with a
	    0.07 shake on the X. Reduce Flashing is the engine's to apply there; here it softens the X's pulse and flash.

	DEMO (the harness: no server -- the showcase's whole choreography, for a 1:1 look against the v6 reel)
	  CrossSlash.Demo(character, opts) plays a tap -- or opts.Hold seconds of held charge -- as cross_slash_dash_bl stages
	  it: at the nearest training dummy ahead, the dash goes THROUGH it (it stands at the kit's 15 of 21.3 studs, so the
	  dash is 1.42 x its distance, clamped to Min / MaxDistance) and the X lands on its chest; no dummy: the kit's own
	  21.3 studs along the body's facing (opts.Distance overrides). In a running game the bodies really move, on the
	  look's clock, every frame (anchored for the demo; all of it put back by :Stop() or once the look has ended):
	    * the caster runs the kit's root track (root_y: the dip back, the push, the skid, scaled to the dash) with the
	      skid-turn on arrival (yaw_of, SKID_YAW -1.10), on the kit's pose clock (v4's two-frame hit-stop, v5's 0.14 s
	      hold on the slash pose), wearing the CastPose clip (and, own view, the Viewmodel clip) on the same clock;
	    * dummy 1 (an anchored one) is thrown back by the X (DUMMY1: hit, stumble step, catch, settle, x THROW 2.3, the
	      whole body leaning away and twisting) -- local only, nothing is hit;
	    * the camera rides the kit's HERO camera (cross_slash_v4.CAM: the front three-quarter on the caster's lit side,
	      the push-in on the crossed arms, the swing down the dash, the arrival two-shot, the impulse on the X), its FOV
	      the kit's vertical FOV, unless opts.Camera == false or opts.Own (your own first person: the camera stays yours).
	  opts.Move == false keeps the old way: the body stays put and the look's dash runs along a GHOST path (the kit's dash
	  profile from where the body stands). opts.React == false leaves the dummy alone. opts.Freeze = KIT seconds (the v6
	  sheet's panel times: 0.37 the charge, 0.56 the takeoff, 0.66 the snap, 0.87 the X, 1.05 the dome) holds that one
	  frame -- bodies and camera included -- until :Stop(); opts.FreezeLook is the same in look seconds. opts.Pose ~= false
	  plays the body clip and the arms; :Stop() lets every part go.

	ENGINE (ZephyrDraw, reconciled with its header): ZD.Play with this module's own Clock (Freeze for a held frame;
	Own = whose cast, so ZephyrDraw thins only OTHER players' particles under Reduce Enemy VFX and applies Graphics
	Quality to all; Budget "CrossSlash"); cv:Ribbon (pts[1] the head; flat strips through o.side; o.alpha is za's
	zk_alpha, 0.5 nominal, so the kit's values go in as they are; o.t the kit's streak clock, t + i like the kit's);
	cv:RingK; cv:Sheet (the dome: kind "shell" with mat_shell's e0 / e1 / a0, closed, along = "v" for latitude rings);
	cv:Burst / cv:Stream (za.burst's own cone and up: the kit's numbers as they are, up = 0 where a direction already
	lifts); cv:Light (watts; ZephyrDraw calms it under Reduce Flashing); ZD.CameraKick (fov = the kit's lens ratio; the
	takeoff punch held with hold = huge and Release()d at KickRelease). The
	budget is <= 260 Beams and 1 light (Tuning.Budget). Counted in a stub run (a ring as 8 spans), the busiest frame --
	just after the X, with the tunnel still out, the cuts, arcs and the dome's first bands up -- is about 227 Beams; your
	own view about 210. A frame that errors ends the look (ZephyrDraw warns once); the particles, the light, the dome
	sheet and the rings are guarded one by one, so an engine that refuses one of them loses only that part. Nothing here
	can stop or change a cast.

	NOT LIKE BLENDER: Beams, not meshes (no thickness, linear widths between knots, Catmull-Rom through fewer knots:
	Tuning.Points / Spans); the particles are ParticleEmitter bursts at the kit's counts, not its pre-simulated flow field
	(the vortex pull, the dash wake and the X blast become each burst's direction); the dummies' reactions are the game's
	and not drawn; random draws are Random.new with the kit's seeds and ranges, not numpy's exact values.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CrossSlash = {}

----------------------------------------------------------------------------------------------------
-- THE KIT'S TIMELINE (spring/cross_slash_dash_bl.py, s from the Primary press). Not tuning: the frame functions below
-- are written against these exactly as the Blender's are.
----------------------------------------------------------------------------------------------------
local B = {}
B.Dip = 0.40                   -- the dash's anticipation: weight rocks back
B.Go = 0.50                    -- the launch (T_GO)
B.Arr = 0.76                   -- the arrival (T_ARR); the skid runs on to Stop
B.Stop = 0.98
B.Snap0, B.Snap1 = 0.628, 0.700   -- the arms snap out
B.S1 = B.Arr + 2 / 30          -- the tension hold is TWO frames: slice 1 starts drawing here
B.S2 = B.S1 + 0.022            -- slice 2 (they cross)
B.DurS = 0.060                 -- a slice draws on in 60 ms (ease-out: the tip slows into its end)
B.X = B.S2 + 0.0125            -- THE X: the crossing instant (flash, bursts, dome) = the game's Trigger
B.Dis = B.X + 0.33             -- the X has held a beat: it starts to fray
B.DurDis = 0.50
B.End = 3.35                   -- the X scuff gone (2.4 -> 3.3) and the last of the dust: the look ends
B.DashY0, B.DashY1 = -0.30, 21.0   -- the kit's dash line: the dip back, the arrival (21.3 studs)
CrossSlash.Beats = B

----------------------------------------------------------------------------------------------------
-- TUNING: what the port decides (the kit's own numbers live in the frame functions, quoted)
----------------------------------------------------------------------------------------------------
CrossSlash.Tuning = {
	-- OWN VIEW (your own first person)
	OwnNear = 2.5,          -- a camera this close to your own Head is your first person (the body is hidden there)
	OwnCharge = false,      -- the charge spiral and its arcs in your own view. OFF keeps the toon look's own-view rule
	                        -- (its charge swirl was never drawn to a camera that close: "it would be the whole screen");
	                        -- the plan keeps every own-view rule. The kit's fp render does draw it -- true puts it back,
	                        -- at the kit's fp scale:
	OwnChargeScale = 0.55,  -- the kit's fp rule: the charge spiral's radius x this, round the Viewmodel fists ...
	OwnArcScale = 0.6,      -- ... and its arcs x this
	OwnTrailScale = 0.6,    -- PROVISIONAL (v6 import): the wrist ribbons' width x this off the fists (they sit at arm's
	                        -- length from the lens, the kit's fp hands a shoulder-width out to the sides)
	OwnXScale = 0.55,       -- PROVISIONAL (v6 import): your own X's size. The game stamps it StopShort ahead of you, so
	                        -- at the kit's 8 studs a cut it would overflow the screen; 0.55 spans about half the view
	OwnDomeFade = 0.5,      -- the kit's fp rule: the dome at half strength (it grows round you)
	OwnPathAhead = 5.0,     -- the kit's fp rule: the vapor tunnel wraps a path this far ahead of the chest ...
	OwnPathLift = 0.35,     -- ... and this far up
	StreakSpeed = 46,       -- studs/s the radial dash streaks rush past (the kit's 46, on the real clock: the game's
	                        -- glide is not the kit's length, so the kit's clock would race or crawl them)
	-- the takeoff FOV punch (the kit: lens / (1 + 0.3 kick), kick up over T_GO -0.01 .. +0.05, held, down over
	-- T_GO + 0.08 .. T_ARR + 0.05): ZephyrDraw.CameraKick's fov is that same lens ratio. Its rise and its ease-out are
	-- KIT seconds, turned into real seconds at the glide's own pace (a 12-stud tap's glide is 0.11 s, a 40-stud one 0.36 s)
	KickFov = 0.30,         -- +30 %
	KickRise = 0.06,        -- kit s of the attack
	KickRelease = 0.66,     -- PROVISIONAL (v6 import): the kit second the punch lets go (where the kit's smoothstep
	                        -- ease-out has fallen a quarter) ...
	KickDecay = 0.07,       -- ... and its exponential tau after that, kit s (the kit's 0.23 s smoothstep fall ~ 3 tau)
	KickMin = 0.03,         -- real s: no attack or tau shorter than this
	JoltFov = -0.0909,      -- the X: the kit's 10 % zoom jolt, lens x 1.1 = fov 1 / 1.1 - 1 ...
	JoltShake = 0.07,       -- ... a 0.07-stud shake (Viewmodel.Shake, through ZephyrDraw) ...
	JoltDecay = 0.09,       -- ... decaying over the kit's tau 0.09 s (no attack: it hits on the crossing)
	-- THE HELD CHARGE: no kit beat (its charge is a tap). All PROVISIONAL (v6 import)
	HoldGlow = 0.35,        -- the spiral and arcs glow x (1 + HoldGlow x the hold), the hold 0 at a tap, 1 at full charge
	HoldLight = 0.5,        -- the charge light x (1 + HoldLight x the hold)
	HoldDustRate = 10,      -- dust per second per stream (two streams turning round the feet) while the key is held ...
	HoldSpeckRate = 6,      -- ... and specks
	ChargeDust = 10,        -- PROVISIONAL (v6 import): dust per point of the six round the feet (the kit pulls 26 + 36)
	ChargeSpecks = 5,       -- specks per point (the kit's 30)
	-- THE FLOOR
	FloorReach = 6.0,       -- a floor further than this under the HumanoidRootPart is "in the air": no floor dust,
	                        -- trench or trench dust (the root stands ~3 over the floor)
	XFloorReach = 9.0,      -- the floor under the X (no floor within this: no scuff, dome ring or feet dust)
	XDrop = 3.5,            -- no floor under the X: the dome stands this far under its centre (the kit's chest, 3.55)
	TrenchMaxRise = 3.0,    -- the trench stops following a floor that climbs or drops more than this from the launch
	TrenchSteps = 48,       -- one trench burst per stud of glide, at most this many
	DemoReach = 70,         -- Demo looks for a training dummy this far ahead
	-- THE VEIL: the kit's refractive shimmer (no refraction in Roblox) as a faint vapor strip, the handoff's stand-in
	ShimmerAlpha = 0.12,
	-- THE LIGHT (one per look)
	LightColor = Color3.fromRGB(140, 255, 235),   -- the kit's aqua (0.55, 1.0, 0.92)
	LightRange = 10,        -- studs, the chest
	LightRangeX = 18,       -- studs, from the X
	-- QUALITY
	ReducedFlashScale = 0.5,   -- PROVISIONAL (v6 import): Reduce Flashing scales the X's glow pulse and the light's flash
	                        -- spike (ZephyrDraw also calms the whole light: no flicker, x its CalmLight)
	ParticleScale = 1.0,    -- every particle count x this (ZephyrDraw applies Graphics Quality's EffectDensity, and Reduce
	                        -- Enemy VFX to other players' casts: Play is told whose cast it is)
	-- BEAM KNOTS: points sampled per shape, and ZephyrDraw's span cap per ribbon (fewer, wider ribbons over many thin)
	Points = { Spiral = 9, Arc = 6, Path = 7, PathGlow = 6, Trail = 6, Cut = 7, After = 6, Scuff = 5,
		DomeAround = 24, DomeUp = 5 },
	Spans = { Spiral = 8, Arc = 2, Path = 5, Trail = 5, Cut = 4, After = 3, Scuff = 2, Dome = 10, Streak = 1 },
	Budget = { Beams = 260, Lights = 1 },
	MaxLifePad = 4,         -- s past the longest held-and-played look before ZephyrDraw ends it regardless
}
local T = CrossSlash.Tuning

----------------------------------------------------------------------------------------------------
-- LAZY REQUIRES (nothing is required until a look first plays: the module is inert on the server)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[ZephyrFX_CrossSlash] " .. msg)
end

local function iceFolder()
	return ReplicatedStorage:FindFirstChild("IceMagic")
end

--- A getter for a module beside this one: nil while it is not in the place (looked for again next time), and nil for
--- good once it has failed to load (warned once).
local function lazy(name, quiet)
	local cache = nil
	return function()
		if cache ~= nil then return cache or nil end
		local folder = iceFolder()
		local m = folder and folder:FindFirstChild(name)
		if not m then
			if not quiet then warnOnce("missing" .. name, name .. " is not in ReplicatedStorage.IceMagic") end
			return nil
		end
		local ok, res = pcall(require, m)
		if ok and type(res) == "table" then
			cache = res
		else
			cache = false
			warnOnce("load" .. name, name .. " failed to load: " .. tostring(res))
		end
		return cache or nil
	end
end

local ZD = lazy("ZephyrDraw")
local ZFX = lazy("ZephyrFX")
local Viewmodel = lazy("Viewmodel", true)
local CastPose = lazy("CastPose", true)

local settingsMod = nil
local function settings()
	if settingsMod == nil then
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = folder and folder:FindFirstChild("SpellshotSettings")
		local ok, s = false, nil
		if m then ok, s = pcall(require, m) end
		settingsMod = (ok and type(s) == "table") and s or false
	end
	return settingsMod or nil
end

local function reduceFlashing()
	local s = settings()
	if not (s and type(s.Get) == "function") then return false end
	local ok, v = pcall(s.Get, "ReduceFlashing")
	return ok and v == true
end

--- VFXLibrary.ShotTimeScale's own read (the filming slow-down), without requiring VFXLibrary for it.
local function timeScale()
	local folder = iceFolder()
	local v = folder and folder:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

--- ZephyrFX.Tuning.CrossSlash: the cast's numbers (the clock's beats, StopShort, the distances), shared with the server.
local function castTuning()
	local z = ZFX()
	return z and z.Tuning and z.Tuning.CrossSlash or nil
end

----------------------------------------------------------------------------------------------------
-- MATHS (the kit's own curves: pyro_kit / zk)
----------------------------------------------------------------------------------------------------
local UP = Vector3.yAxis
local ZERO = Vector3.zero
local PI = math.pi
local SWEEP = math.rad(300)          -- the charge arms' sweep (arc_pts a0 -> a0 - rad(300))

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

--- pyro_kit.span
local function span(t, a, b)
	if b > a then return clamp01((t - a) / (b - a)) end
	return (t >= b) and 1 or 0
end

--- zk.smooth(x, a, b): smoothstep of x over a .. b
local function sstep(x, a, b)
	local u = clamp01((x - a) / (b - a))
	return u * u * (3 - 2 * u)
end

--- pyro_kit.ease (smoothstep) and ease_out (cubic)
local function ease(u)
	u = clamp01(u)
	return u * u * (3 - 2 * u)
end

local function easeOut(u)
	u = clamp01(u)
	return 1 - (1 - u) ^ 3
end

--- cross_slash_v4.env: up over a .. b, down over c .. d
local function env(t, a, b, c, d)
	return sstep(t, a, b) * (1 - sstep(t, c, d))
end

--- zk.flash_curve
local function flashCurve(t, t0, peak, rise, tau)
	if t < t0 - rise then return 0 end
	if t < t0 then return peak * ease((t - t0 + rise) / rise) end
	return peak * math.exp(-(t - t0) / tau)
end

--- pyro_kit.perp_any in Roblox axes, ZephyrDraw.perp_any's rule: the kit's stage maps (x, y, z) -> (x, z, -y), a
--- proper rotation, so its Z-up is Roblox's UP, its X is Roblox's X, and every cross product and handedness carries over
local function perpAny(a)
	local p = a:Cross(UP)
	if p.Magnitude < 1e-4 then p = a:Cross(Vector3.xAxis) end
	if p.Magnitude < 1e-9 then return Vector3.xAxis end
	return p.Unit
end

local function flat(v)
	local h = Vector3.new(v.X, 0, v.Z)
	return h.Magnitude > 1e-3 and h.Unit or nil
end

----------------------------------------------------------------------------------------------------
-- THE CLOCK MAP (see the header): look seconds <-> kit seconds
----------------------------------------------------------------------------------------------------
--- The kit's time for the look's `t` (S = ZephyrFX.Tuning.CrossSlash, optional).
function CrossSlash.ToKit(t, S)
	S = S or castTuning()
	local C, G, X = S.ChargeTime, S.ChargeTime + S.DashTime, S.Trigger
	if t <= C then return t * B.Go / C end
	if t <= G then return B.Go + (t - C) * (B.Arr - B.Go) / (G - C) end
	if t <= X then return B.Arr + (t - G) * (B.X - B.Arr) / (X - G) end
	return B.X + (t - X)
end

--- The look's time for the kit's `b`.
function CrossSlash.FromKit(b, S)
	S = S or castTuning()
	local C, G, X = S.ChargeTime, S.ChargeTime + S.DashTime, S.Trigger
	if b <= B.Go then return b * C / B.Go end
	if b <= B.Arr then return C + (b - B.Go) * (G - C) / (B.Arr - B.Go) end
	if b <= B.X then return G + (b - B.Arr) * (X - G) / (B.X - B.Arr) end
	return X + (b - B.X)
end

----------------------------------------------------------------------------------------------------
-- THE KIT'S DASH PROFILE (cross_slash_dash_bl._dash_table / root_y): only Demo's ghost moves this way
----------------------------------------------------------------------------------------------------
local dashY, vEnd = nil, 0
local DASH_N = 400

local function dashTable()
	if dashY then return end
	dashY = table.create(DASH_N + 1)
	local s, vPrev = 0, 0
	local dt = (B.Arr - B.Go) / DASH_N
	for i = 0, DASH_N do
		local u = i / DASH_N
		local v = sstep(u, 0, 0.14) * (1 - 0.94 * sstep(u, 0.60, 1.0))   -- the push: in fast, braking into the arrival
		if i > 0 then s += (v + vPrev) * 0.5 * dt end
		dashY[i + 1] = s
		vPrev = v
	end
	local k = (B.DashY1 - B.DashY0) / s
	for i = 1, DASH_N + 1 do dashY[i] = B.DashY0 + dashY[i] * k end
	vEnd = vPrev * k
end

--- How far along the kit's dash line its caster's root is at kit time x (studs of the kit's 21.3).
local function rootY(x)
	dashTable()
	if x < B.Dip then return 0 end
	if x < B.Go then return B.DashY0 * ease(span(x, B.Dip, B.Go)) end
	if x < B.Arr then
		local f = (x - B.Go) / (B.Arr - B.Go) * DASH_N
		local i = math.floor(f)
		return dashY[i + 1] + (dashY[math.min(i + 2, DASH_N + 1)] - dashY[i + 1]) * (f - i)
	end
	local tau = math.min(x, B.Stop) - B.Arr
	local TT = B.Stop - B.Arr
	return B.DashY1 + vEnd * (tau - tau * tau / (2 * TT))             -- the skid
end

----------------------------------------------------------------------------------------------------
-- THE KIT'S SEEDED SETS (drawn once, from the kit's seeds and ranges: identical on every client)
----------------------------------------------------------------------------------------------------
local function gauss(g, sd)
	local u1 = math.max(1e-9, g:NextNumber())
	return sd * math.sqrt(-2 * math.log(u1)) * math.cos(2 * PI * g:NextNumber())
end

--- za.Arcs: pointed arcs (thick to thin, never wide-bellied) orbiting a centre on varied planes, each its own radius,
--- span, angular speed, width, glow and phase, so nothing looks copy-pasted.
local function newArcs(n, seed, r, spanDeg, w, speed, tilt)
	local g = Random.new(seed)
	local set = table.create(n)
	for i = 1, n do
		set[i] = {
			R = g:NextNumber(r[1], r[2]),
			Span = math.rad(g:NextNumber(spanDeg[1], spanDeg[2])),
			W = g:NextNumber(w[1], w[2]) * ((g:NextInteger(1, 3) == 3) and 1.7 or 1.0),   -- rs.choice([1, 1, 1.7])
			Spd = g:NextNumber(speed[1], speed[2]),
			Ph = g:NextNumber(0, 2 * PI),
			T0 = gauss(g, tilt),
			T1 = gauss(g, tilt),
			Glow = g:NextNumber(0.7, 1.5),
			Alpha = g:NextNumber(0.35, 0.8),
			Flick = g:NextNumber(0, 2 * PI),
			Rise = g:NextNumber(-0.25, 0.25),
		}
	end
	return set
end

-- C4: ch_arcs = Arcs(10, seed=11, r=(0.9, 2.2), span=(60, 130), w=(0.04, 0.14), speed=(5, 11), tilt=0.35)
local CHARGE_ARCS = newArcs(10, 11, { 0.9, 2.2 }, { 60, 130 }, { 0.04, 0.14 }, { 5, 11 }, 0.35)
-- C4: x_arcs = Arcs(16, seed=23, r=(1.6, 4.2), span=(40, 120), w=(0.05, 0.2), speed=(3, 8), tilt=0.5)
local X_ARCS = newArcs(16, 23, { 1.6, 4.2 }, { 40, 120 }, { 0.05, 0.20 }, { 3, 8 }, 0.5)

-- C6: the 16 first-person dash streaks, rng(61): (angle round the view, radius, phase, length)
local STREAKS = {}
do
	local g = Random.new(61)
	for i = 1, 16 do
		STREAKS[i] = { A = g:NextNumber(0, 6.28), R = g:NextNumber(1.1, 2.6), Ph = g:NextNumber(0, 14),
			L = g:NextNumber(1.8, 3.6) }
	end
end

-- C4 x_stamp: each cut's three glow ribbons (width, lateral offset, fade, alpha, glow)
local GLOW_W = { 0.55, 0.95, 1.4 }
local GLOW_LAT = { -0.10, 0.12, 0.0 }
local GLOW_F = { 0.85, 0.7, 0.5 }
local GLOW_A = { 0.65, 0.5, 0.35 }
local GLOW_G = { 1.1, 0.95, 0.8 }
local SIDES = { "R", "L" }

----------------------------------------------------------------------------------------------------
-- SHAPES (the kit's helpers, emitting ZephyrDraw ribbons)
----------------------------------------------------------------------------------------------------
--- za.Arcs.draw (spin +1: counter-clockwise about `axis`, the head leading)
local function arcsDraw(cv, set, t, c, axis, fade, scale, speedMul, glow, tag)
	if fade <= 0.003 then return end
	local ax = axis.Unit
	local b0 = perpAny(ax)
	local b1 = ax:Cross(b0)
	local n = T.Points.Arc
	for _, a in ipairs(set) do
		local nn = (ax + b0 * a.T0 + b1 * a.T1).Unit
		local d0 = perpAny(nn)
		local d1 = nn:Cross(d0)
		local a0 = a.Ph + a.Spd * speedMul * t
		local R = a.R * scale
		local pts, w = table.create(n), table.create(n)
		for k = 1, n do
			local s = (k - 1) / (n - 1)
			local ang = a0 - a.Span * s                       -- the head leads, the tail trails behind
			pts[k] = c + (d0 * math.cos(ang) + d1 * math.sin(ang)) * R + nn * (s * a.Rise * R)
			w[k] = a.W * scale * math.sin(PI * clamp01(s * 0.92 + 0.04)) ^ 0.7 * (1 - 0.65 * s)
		end
		local fl = 0.75 + 0.25 * math.sin(t * 9.0 + a.Flick)
		cv:Ribbon(pts, w, "arc", { fade = fade * fl, glow = a.Glow * glow, alpha = a.Alpha, tail = 0.55,
			maxSpans = T.Spans.Arc, tag = tag })
	end
end

--- zk.arc_pts round `axis` through `c` (radius r0 at angle a0 -> r1 at a1, no rise), listed from the a1 end: the kit
--- reverses its charge spirals so the HEAD is the inner end -- the air winding IN.
local function spiralIn(c, axis, start, r0, a0, a1, r1, n)
	local d0 = start - axis * start:Dot(axis)
	d0 = (d0.Magnitude > 1e-6) and d0.Unit or perpAny(axis)
	local d1 = axis:Cross(d0)
	local pts = table.create(n)
	for k = 1, n do
		local s = 1 - (k - 1) / (n - 1)
		local a = a0 + (a1 - a0) * s
		local r = r0 + (r1 - r0) * s
		pts[k] = c + (d0 * math.cos(a) + d1 * math.sin(a)) * r
	end
	return pts
end

--- np.linspace(w0, w1, n) x mul
local function linW(n, w0, w1, mul)
	mul = mul or 1
	local w = table.create(n)
	for k = 1, n do w[k] = (w0 + (w1 - w0) * (k - 1) / (n - 1)) * mul end
	return w
end

--- za.path_ribbon: a ribbon trailing a moving source along its own recent path -- the points fn(now - k dur/(n-1)),
--- the head the newest -- widths wHead -> wTail under the kit's sin^0.35 end taper; off(x, s) shifts each point (x the
--- sample's kit time, s 0 at the head .. 1 at the tail).
local function pathRibbon(cv, fn, now, dur, wHead, wTail, n, off, kind, o)
	local pts, w = table.create(n), table.create(n)
	for k = 1, n do
		local s = (k - 1) / (n - 1)
		local x = now - dur * s
		local p = fn(x)
		if off then p += off(x, s) end
		pts[k] = p
		w[k] = (wHead + (wTail - wHead) * s) * math.sin(PI * (0.02 + 0.96 * s)) ^ 0.35
	end
	cv:Ribbon(pts, w, kind, o)
end

----------------------------------------------------------------------------------------------------
-- THE WORLD: the floor, the body
----------------------------------------------------------------------------------------------------
--- The floor under `from` within `reach` studs: the first collidable hit that is not a character (the caster is never
--- one; a body in the way is stepped past). nil in the air.
local function floorBelow(from, reach, caster)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ex = {}
	if caster then ex[1] = caster end
	for _ = 1, 4 do
		params.FilterDescendantsInstances = ex
		local hit = workspace:Raycast(from, Vector3.new(0, -reach, 0), params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		-- (2026-10-19, audit GC-05) a Bulwark Wall (WallOwner) has a Humanoid but is no body: its top is floor
		if model and model:FindFirstChildOfClass("Humanoid") and model:GetAttribute("WallOwner") == nil then
			ex[#ex + 1] = model
		else
			return hit.Position
		end
	end
	return nil
end

local function handOf(c, side)
	local h = c:FindFirstChild(side == "R" and "RightHand" or "LeftHand")
	if h then return h.Position end
	local arm = c:FindFirstChild(side == "R" and "Right Arm" or "Left Arm")   -- R6: the arm's lower end
	return arm and (arm.CFrame * Vector3.new(0, -0.8, 0)) or nil
end

local function chestOfModel(m)
	local torso = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
	if torso then return torso.Position end
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	return root and root.Position + Vector3.new(0, 1.2, 0) or nil
end

----------------------------------------------------------------------------------------------------
-- THE BODY'S HISTORY, by kit time (what the kit's path_ribbon(fn = chest_at / the wrists) samples)
----------------------------------------------------------------------------------------------------
local HIST_KEEP = 0.7        -- kit seconds kept: the longest trail looks back 0.24 x 1.8 = 0.43

--- One sample per kit instant: a frame whose kit time did not advance (the held charge) overwrites the last one.
local function record(sl, b, root, chest, hr, hl, fr, fl)
	local H = sl.Hist
	local n = #H
	local last = H[n]
	if last and b <= last.B + 1e-6 then
		last.Root, last.Chest, last.R, last.L, last.FR, last.FL = root, chest, hr, hl, fr, fl
		return
	end
	n += 1
	H[n] = { B = b, Root = root, Chest = chest, R = hr, L = hl, FR = fr, FL = fl }
	local drop = 0                                   -- keep one sample older than the window, to interpolate from
	while drop + 2 <= n and H[drop + 2].B < b - HIST_KEEP do drop += 1 end
	if drop > 0 then
		table.move(H, drop + 1, n, 1)
		for k = n - drop + 1, n do H[k] = nil end
	end
end

--- The sampled value `key` at kit time x (clamped to the history's ends), or nil.
local function histAt(sl, key, x)
	local H = sl.Hist
	local n = #H
	if n == 0 then return nil end
	if x >= H[n].B then return H[n][key] end
	if x <= H[1].B then return H[1][key] end
	for i = n - 1, 1, -1 do
		local a = H[i]
		if a.B <= x then
			local c = H[i + 1]
			local va, vc = a[key], c[key]
			if va == nil or vc == nil then return vc or va end
			return va:Lerp(vc, (x - a.B) / math.max(1e-6, c.B - a.B))
		end
	end
	return H[1][key]
end

--- Demo's ghost: the kit's root motion along the dash, scaled to the demo's distance (zero for a real cast).
local function ghostOff(sl, x)
	local g = sl.Ghost
	return g and g.Dir * (rootY(x) * g.Scale) or ZERO
end

local function chestAt(sl, x)
	return (histAt(sl, "Chest", x) or sl.LastChest) + ghostOff(sl, x)
end

local function rootAt(sl, x)
	return (histAt(sl, "Root", x) or sl.LastRoot) + ghostOff(sl, x)
end

--- A hand at kit time x. Your own view: the Viewmodel fist, kept in the CAMERA's frame (the arms' own motion, not the
--- dash carrying them past the lens) and placed off this frame's camera.
local function handAt(sl, side, x, F)
	if F.own and sl.Fists then
		local p = histAt(sl, side == "R" and "FR" or "FL", x)
		if p then return F.camCF:PointToWorldSpace(p) end
	end
	return (histAt(sl, side, x) or sl.LastChest) + ghostOff(sl, x)
end

--- How much longer than a tap the charge was held: 0 at a tap, 1 at FullChargeTime (SpellshotInput's own measure:
--- releaseCrossSlash books LaunchAt = held x scale + (ChargeTime - HoldPose)).
local function holdShare(timing, S, frozen)
	local scale = timeScale()
	local held
	if timing.LaunchAt then
		held = (timing.LaunchAt - (S.ChargeTime - S.HoldPose)) / scale
	elseif frozen then
		return 0
	else
		held = os.clock() - timing.Start
	end
	local from = S.HoldPose / scale
	return clamp01((held - from) / math.max(0.05, S.FullChargeTime - from))
end

----------------------------------------------------------------------------------------------------
-- THE ENGINE'S EXTRAS, guarded: a particle kind, the light, the dome sheet or a ring the engine refuses is warned once and
-- skipped, never the end of the whole look (cv:Ribbon, the workhorse, is not guarded: ZephyrDraw ends a look whose frame
-- errors, and warns)
----------------------------------------------------------------------------------------------------
local function extra(cv, method, ...)
	local f = cv[method]
	if type(f) ~= "function" then
		warnOnce("no" .. method, "ZephyrDraw's canvas has no " .. method .. " - that part is not drawn")
		return
	end
	local ok, err = pcall(f, cv, ...)
	if not ok then
		local kind = ...                                     -- Burst / Stream: one warning per particle kind
		kind = (type(kind) == "string") and kind or ""
		warnOnce("fail" .. method .. kind, "cv:" .. method .. "(" .. kind .. ") failed: " .. tostring(err))
	end
end

--- cv:Burst once per id, the count x the quality multiplier.
local function burst(sl, cv, F, id, kind, pos, n, o)
	if sl.Fired[id] then return end
	sl.Fired[id] = true
	if not pos then return end
	n = math.floor(n * F.pmul + 0.5)
	if n <= 0 then return end
	o.id = id
	o.tag = "particles"
	extra(cv, "Burst", kind, pos, n, o)
end

----------------------------------------------------------------------------------------------------
-- THE BEATS (the kit's frame functions, in kit time F.b)
----------------------------------------------------------------------------------------------------
--- CHARGE [C4.charge + C5.charge]: the open spiral winding in round the crossed hands, its arcs.
local function drawCharge(sl, cv, F)
	local b = F.b
	local e4 = env(b, 0.10, 0.20, B.Go - 0.02, B.Go + 0.08)
	local e5 = env(b, 0.10, 0.18, B.Go - 0.02, B.Go + 0.08)        -- C5's extra arm comes in a touch sooner
	if e4 <= 0.003 and e5 <= 0.003 then return end
	if F.own and not T.OwnCharge then return end                    -- the own-view rule kept (Tuning.OwnCharge)
	local k = sstep(b, 0.12, B.Go)                                  -- winding in: the radius tightens
	local C, ax, start
	if F.own and F.fistR and F.fistL then
		ax, start = F.camCF.LookVector, F.camCF.RightVector
		C = (F.fistR + F.fistL) * 0.5 + ax * 0.35
	else
		ax, start = F.torsoCF.LookVector, F.torsoCF.RightVector   -- the chest's forward axis and its right (R_chest)
		C = (handAt(sl, "R", b, F) + handAt(sl, "L", b, F)) * 0.5 + ax * 0.35
	end
	F.chargeC = C
	local sc = F.own and T.OwnChargeScale or 1
	local hg = 1 + T.HoldGlow * F.hold
	local n = T.Points.Spiral
	if e4 > 0.003 then
		local spin = 9.0 * F.bs + 6.0 * k * k
		for i = 0, 3 do                                             -- the core thread + 3 glow arms
			local a0 = spin + i * 2.1
			local r0 = (2.6 - 1.5 * k) * (1.0 + 0.12 * i) * sc
			local pts = spiralIn(C, ax, start, r0, a0, a0 - SWEEP, r0 * 0.28, n)
			if i == 0 then
				cv:Ribbon(pts, linW(n, 0.10, 0.05), "core", { t = F.bs, fade = e4, glow = 1.0 * hg, tail = 0.5,
					maxSpans = T.Spans.Spiral, tag = "charge" })
			else
				cv:Ribbon(pts, linW(n, 0.55, 0.25, 1 - 0.18 * i), "glow", { t = F.bs + i, fade = e4 * (0.9 - 0.12 * i),
					alpha = 0.62, glow = 0.95 * hg, tail = 0.6, maxSpans = T.Spans.Spiral, tag = "charge" })
			end
		end
		arcsDraw(cv, CHARGE_ARCS, F.bs, C, ax, e4 * 0.9, (1.25 - 0.55 * k) * (F.own and T.OwnArcScale or 1), 1 + k, hg,
			"charge")
	end
	if e5 > 0.003 then                                              -- C5: an extra, faster arm winding in
		local a0 = 16.0 * F.bs + 12.0 * k * k + 1.0
		local r0 = (2.9 - 1.9 * k) * sc
		local pts = spiralIn(C, ax, start, r0, a0, a0 - SWEEP, r0 * 0.25, n)
		cv:Ribbon(pts, linW(n, 0.6, 0.2), "glow", { t = F.bs + 3, fade = e5, alpha = 0.65, glow = 1.2 * hg, tail = 0.55,
			maxSpans = T.Spans.Spiral, tag = "charge" })
	end
end

--- TAKEOFF [C6.v6_takeoff]: the vapor ring burst left behind at the launch (none in your own view: behind you).
local function drawTakeoff(sl, cv, F)
	local b = F.b
	local Lc = sl.LaunchChest
	if F.own or not Lc or b < B.Go - 0.01 or b > B.Go + 0.42 then return end
	local u = span(b, B.Go - 0.01, B.Go + 0.42)
	for i = 0, 1 do
		local ui = clamp01(u * (1.0 + 0.25 * i) - 0.08 * i)
		if ui > 0 and ui < 1 then
			local r = 0.7 + (2.6 + 0.6 * i) * (1 - (1 - ui) ^ 2.2)
			-- the kit: (c.x, c.y - 0.6 - 1.2 ui - 0.5 i, 2.3 - 0.4 ui) about the launch chest c (2.75 over the floor)
			local c = Lc - F.dir * (0.6 + 1.2 * ui + 0.5 * i) - F.up * (0.45 + 0.4 * ui)
			extra(cv, "RingK", c, r, F.dir, (1.0 - 0.6 * ui) * (1 - 0.2 * i), "vapor", { t = b + i,
				fade = (1 - ui) ^ 1.4 * sstep(ui, 0, 0.06), alpha = 0.6, glow = 1.0, tag = "takeoff" })
		end
	end
end

--- SNAP [C6.v6_trails]: motion ribbons off both hands through the snap (core inside glow).
local function drawTrails(sl, cv, F)
	local b = F.b
	local e = env(b, B.Go - 0.06, B.Snap0, B.Arr, B.Arr + 0.14)
	if e <= 0.003 then return end
	local ws = F.own and T.OwnTrailScale or 1
	local n = T.Points.Trail
	for si, side in ipairs(SIDES) do                                -- the kit's i: 0 the right wrist, 1 the left
		local fn = function(x) return handAt(sl, side, x, F) end
		pathRibbon(cv, fn, b, 0.15, 0.55 * ws, 0.05 * ws, n, nil, "glow", { t = b + si - 1, fade = e * 0.9, alpha = 0.6,
			glow = 1.1, tail = 0.7, maxSpans = T.Spans.Trail, tag = "snap" })
		pathRibbon(cv, fn, b, 0.11, 0.13 * ws, 0.02 * ws, n, nil, "core", { t = b + si - 1, fade = e, glow = 1.2,
			tail = 0.6, maxSpans = T.Spans.Trail, tag = "snap" })
	end
end

--- DASH [C4.dash + C5.dash]: the streak, the helix, the vapor tunnel, the veil -- all trailing the chest's own path.
--- Your own view: the tunnel round a path ahead of you, nothing down the view axis.
local function drawDash(sl, cv, F)
	local b = F.b
	local e4 = env(b, B.Go, B.Go + 0.03, B.Arr + 0.05, B.Arr + 0.45)
	local e5 = env(b, B.Go, B.Go + 0.03, B.Arr + 0.05, B.Arr + 0.6)
	if e4 <= 0.003 and e5 <= 0.003 then return end
	local rgt, up, dir = F.right, F.up, F.dir
	local path
	if F.own then
		local shift = dir * T.OwnPathAhead + up * T.OwnPathLift
		path = function(x) return chestAt(sl, x) + shift end
	else
		path = function(x) return chestAt(sl, x) end
	end
	local nP, nG = T.Points.Path, T.Points.PathGlow
	if e4 > 0.003 then
		local dur = math.clamp(b - B.Go, 0.02, 0.20)
		if not F.own then
			for i = 0, 2 do                                         -- the helix: three glow ribbons turning round the path
				local a0 = i * 2.09
				pathRibbon(cv, path, b, dur * (1.1 + 0.15 * i), 0.7 - 0.1 * i, 0.2, nG, function(x, s)
					local a = a0 + 9 * x
					return (rgt * math.cos(a) + up * math.sin(a)) * (0.3 + 0.6 * s)
				end, "glow", { t = b + i, fade = e4 * 0.85, alpha = 0.6, glow = 1.0, tail = 0.7, maxSpans = T.Spans.Path,
					tag = "dash" })
			end
		end
		for i = 0, 5 do                                             -- the vapor tunnel: six ribbons spiralling open
			local a0 = i * 1.047
			pathRibbon(cv, path, b, dur * 1.6, 0.9, 1.8, nP, function(_, s)
				local a, r = a0 + 2.5 * s, 1.0 + 1.6 * s
				return rgt * (math.cos(a) * r) + up * (math.sin(a) * r * 0.9)
			end, "vapor", { t = b + 0.3 * i, fade = e4 * 0.8, alpha = 0.5, glow = 0.9, tail = 0.8, maxSpans = T.Spans.Path,
				tag = "dash" })
		end
		if not F.own then
			pathRibbon(cv, path, b, dur, 0.12, 0.04, nG, nil, "core", { fade = e4, glow = 1.1, tail = 0.7,
				maxSpans = T.Spans.Path, tag = "dash" })
			pathRibbon(cv, path, b, dur * 1.2, 2.6, 2.6, nG, nil, "vapor", { fade = e4, alpha = T.ShimmerAlpha, glow = 0.6,
				maxSpans = T.Spans.Path, tag = "dash" })
		end
	end
	if e5 > 0.003 then                                              -- C5: a stronger tunnel, wider and longer
		local dur = math.clamp(b - B.Go, 0.02, 0.24)
		for i = 0, 3 do
			local a0 = i * 1.571 + 0.5
			pathRibbon(cv, path, b, dur * 1.8, 1.4, 2.6, nP, function(_, s)
				local a = a0 + 3 * s
				return rgt * (math.cos(a) * (1.4 + 2.2 * s)) + up * (math.sin(a) * (1.4 + 2.0 * s))
			end, "vapor", { t = b + i, fade = e5 * 0.85, alpha = 0.6, glow = 1.0, tail = 0.8, maxSpans = T.Spans.Path,
				tag = "dash" })
		end
	end
end

--- TRENCH [C4.scuffs]: the scuff line on the floor from the launch to under the body, fading 1.8 -> 3.2.
local function drawTrench(sl, cv, F)
	local b = F.b
	local tail = sl.LaunchFloor
	if b < B.Go or not tail then return end
	if b <= B.Arr + 0.25 then                                       -- follow the floor under the body through the skid
		local f = floorBelow(F.root, T.FloorReach, sl.Character)
		if f and math.abs(f.Y - tail.Y) <= T.TrenchMaxRise then sl.TrenchHead = f end
	end
	local head = sl.TrenchHead
	if not head then return end
	local along = Vector3.new(head.X - tail.X, 0, head.Z - tail.Z)
	local L = along.Magnitude
	if L < 0.6 then return end
	local fade = 1 - sstep(b, 1.8, 3.2)
	if fade <= 0.003 then return end
	local side = UP:Cross(along / L)
	local n = T.Points.Scuff
	local pts = table.create(n)
	for k = 1, n do
		local s = (k - 1) / (n - 1)
		pts[k] = head:Lerp(tail, s) + side * (0.05 * math.sin(L * (1 - s) * 1.3)) + UP * 0.025
	end
	cv:Ribbon(pts, 0.9, "scuff", { side = side, fade = fade, glow = 0.8, tail = 0.15, maxSpans = T.Spans.Scuff,
		tag = "scuff" })
end

--- Where the X stamps (see the header), its plane facing this viewer's camera, fixed from here on.
local function captureX(sl, F, S)
	if sl.X or F.b < B.S1 - 0.02 then return end
	local dir = F.dir
	local spot = sl.Target and sl.Target.Parent and chestOfModel(sl.Target) or nil
	spot = spot or (F.root + dir * S.StopShort + Vector3.new(0, 1.2, 0))
	-- v4's XN: the flat direction to the camera, so the X stands upright (its cuts on the true diagonals) whatever the
	-- camera's height
	local toCam = F.cam and (F.camCF.Position - spot) or -dir
	local n = flat(toCam) or flat(-dir) or -dir
	local r = UP:Cross(n)                                           -- the X plane's horizontal axis (the kit's XR)
	r = (r.Magnitude > 1e-3) and r.Unit or perpAny(n)
	local floor = floorBelow(spot, T.XFloorReach, sl.Character)
	sl.X = {
		C = spot, N = n, R = r, U = n:Cross(r),
		S = F.own and T.OwnXScale or 1,
		Floor = floor, Base = floor or (spot - UP * T.XDrop),
	}
end

--- THE X [C4.x_stamp + C5.x_stamp]: the two cuts, the arcs, the small vapor ring, the afterimage, the floor scuff.
local function drawX(sl, cv, F)
	local X = sl.X
	if not X then return end
	local b = F.b
	local xs = X.S
	local XC, XN, XR, XU = X.C, X.N, X.R, X.U
	local XL = 7.6 * 1.05 * xs                                      -- C4.XL = X_L x 1.05
	if b >= B.S1 and b <= B.Dis + B.DurDis + 0.05 then
		local kout = ease(span(b, B.Dis, B.Dis + B.DurDis))
		local pulse = 1 + 0.9 * F.rfk * ((b >= B.X - 0.01) and math.exp(-math.max(0, b - B.X) / 0.05) or 0)
		local f = 1 - kout
		local tail = 0.55 + 0.4 * kout
		local n = T.Points.Cut
		for i = 0, 1 do
			local t0 = (i == 0) and B.S1 or B.S2
			local sg = (i == 0) and 1 or -1
			local prog = easeOut(span(b, t0, t0 + B.DurS))
			if prog > 0.01 then
				local d = XR * 0.7071 + XU * (0.7071 * sg)
				local perp = XN:Cross(d)
				local depth = XN * (0.35 * (i - 0.5) * xs)
				local drift = 0.6 * kout * xs
				local sink = UP * (-0.5 * kout * xs)
				local function cut(w0, bow, lat, ext)
					local pts, w = table.create(n), table.create(n)
					local shift = perp * (drift * ((lat >= 0) and 1 or -1)) + sink + depth
					for k = 1, n do
						local s = prog * (1 - (k - 1) / (n - 1))       -- tip first (the head), the start last
						pts[k] = XC + d * ((s - 0.5) * XL * ext) + perp * ((math.sin(PI * s) * bow + lat) * xs) + shift
						w[k] = w0 * math.sin(PI * clamp01(s / math.max(prog, 1e-3) * 0.94 + 0.03)) ^ 0.45
					end
					return pts, w
				end
				local pts, w = cut(0.17 * xs, 0.25, 0, 1)
				cv:Ribbon(pts, w, "core", { side = perp, fade = f, glow = 1.2 * pulse, tail = tail, maxSpans = T.Spans.Cut,
					tag = "x" })
				for j = 1, 3 do
					pts, w = cut(GLOW_W[j] * (1 + 0.4 * kout) * xs, 0.25 + 0.12 * (j - 1), GLOW_LAT[j], 1 + 0.05 * (j - 1))
					cv:Ribbon(pts, w, "glow", { t = b + j, side = perp, fade = f * GLOW_F[j], alpha = GLOW_A[j],
						glow = GLOW_G[j] * pulse, tail = tail, maxSpans = T.Spans.Cut, tag = "x" })
				end
				pts, w = cut(2.6 * (1 + 0.5 * kout) * xs, 0.5, 0, 1.12)   -- the soft wide one
				cv:Ribbon(pts, w, "glow", { t = b + 5, side = perp, fade = f * 0.45, alpha = 0.32, glow = 0.6, tail = 0.7,
					maxSpans = T.Spans.Cut, tag = "x" })
			end
		end
	end
	-- the arcs, flung wider as the X frays
	arcsDraw(cv, X_ARCS, b, XC, XN, env(b, B.X - 0.01, B.X + 0.04, B.Dis, B.Dis + B.DurDis),
		(1 + 0.6 * sstep(b, B.X, B.Dis + B.DurDis)) * xs, 1, 1, "x")
	-- ONE small soft vapor ring (the developer's stage-1 review: the two big shock rings removed)
	local k = span(b, B.X + 0.03, B.X + 0.8)
	if k > 0 and k < 1 then
		extra(cv, "RingK", XC + XN * (0.3 * xs), (1.0 + 2.2 * easeOut(k)) * xs, XN, 1.0 * (1 - 0.5 * k) * xs, "vapor",
			{ fade = (1 - k) * 0.55, alpha = 0.45, tag = "x" })
	end
	-- C5: the afterimage, soft sheared ribbons thinning (camera-facing)
	local u = span(b, B.Dis - 0.05, B.Dis + 0.9)
	if u > 0 and u < 1 then
		local n = T.Points.After
		for i = 0, 3 do
			local sg = (i < 2) and 1 or -1
			local odd = (i % 2 == 1) and 1 or -1
			local d = XR * 0.7071 + XU * (0.7071 * sg)
			local perp = XN:Cross(d)
			local shear = (0.4 + 1.6 * u) * odd
			local pts, w = table.create(n), table.create(n)
			for k2 = 1, n do
				local s = (k2 - 1) / (n - 1)
				pts[k2] = XC + d * ((s - 0.5) * XL * (1.05 + 0.15 * u)) + perp * (shear * (0.3 + s) * xs)
					+ XN * ((0.6 + 0.8 * u) * odd * xs) + UP * (-0.6 * u * xs)
				w[k2] = 1.6 * (1 + u) * xs * math.sin(PI * clamp01(s * 0.94 + 0.03)) ^ 0.5
			end
			cv:Ribbon(pts, w, "glow", { t = b + i, fade = (1 - u) * 0.6, alpha = 0.4, glow = 0.8, tail = 0.7,
				maxSpans = T.Spans.After, tag = "after" })
		end
	end
	-- C5: the faint X scuff on the floor under it
	if b >= B.X and X.Floor then
		local fade = sstep(b, B.X, B.X + 0.1) * (1 - sstep(b, 2.4, 3.3))
		if fade > 0.003 then
			local rh = flat(XR) or perpAny(UP)
			for i = 0, 1 do
				local sg = (i == 1) and 1 or -1
				local d = (rh * 0.7071 + UP:Cross(rh) * (0.7071 * sg)).Unit
				local at = X.Floor + UP * 0.03
				cv:Ribbon({ at + d * (3.4 * xs), at, at - d * (3.4 * xs) }, 0.7 * xs, "scuff", { side = UP:Cross(d),
					fade = fade, glow = 0.9, tail = 0.3, maxSpans = 1, tag = "scuff" })
			end
		end
	end
end

--- DOME [C6.v6_shock]: the wide soft lobed vapor dome after the X, and the ring at its foot.
local function drawDome(sl, cv, F)
	local X = sl.X
	if not X then return end
	local b = F.b
	local u = span(b, B.X, B.X + 1.15)
	if u <= 0 or u >= 1 then return end
	local R = 1.4 + 6.2 * (1 - (1 - u) ^ 2.6)
	local f = sstep(u, 0, 0.05) * (1 - u) ^ 2.2 * (F.own and T.OwnDomeFade or 1)
	if f <= 0.003 then return end
	local D = X.Base
	-- za5's Shell: the kit's 12 x 48 grid -- sa (u) up the height, ph 0 .. 1.3 rad (an open crown), ch (v) round it,
	-- closed -- drawn by ZephyrDraw as latitude rings (along = "v": DomeUp - 1 closed bands round the dome), in the
	-- kit's own material, mat_shell("cs_dome", e0 0.35, e1 1.1, a0 0.45): a soft foot and rim, hotter up the height
	local nu, nv = T.Points.DomeUp, T.Points.DomeAround
	local P, fa = table.create(nu * nv), table.create(nu * nv)
	for i = 1, nu do
		local ph = 1.3 * (i - 1) / (nu - 1)
		local cp, sp = math.cos(ph), math.sin(ph)
		for j = 1, nv do
			local th = 2 * PI * (j - 1) / nv
			local idx = (i - 1) * nv + j
			-- the kit's (R cos ph cos th, R cos ph sin th, 0.05 + 0.62 R sin ph), in Roblox axes (x, z, -y)
			P[idx] = D + Vector3.new(R * cp * math.cos(th), 0.05 + 0.62 * R * sp, -R * cp * math.sin(th))
			-- wispy lobes, not glass
			local lob = 0.5 + 0.5 * math.sin(5 * th + 2.5 * ph + 3.0 * u) * math.sin(3 * th - 1.7 * ph + 1.1)
			fa[idx] = clamp01(0.25 + 0.95 * lob) * (1 - 0.7 * (ph / 1.3) ^ 1.5)
		end
	end
	extra(cv, "Sheet", P, nu, nv, "shell", { closed = true, along = "v", fa = fa, fade = f, alpha = 0.4, glow = 0.95,
		e0 = 0.35, e1 = 1.1, a0 = 0.45, t = b * 1.6, maxSpans = T.Spans.Dome, tag = "dome" })
	if X.Floor then
		extra(cv, "RingK", D + UP * 0.08, R * 1.04, UP, 0.9 * (1 - 0.5 * u), "vapor", { fade = f * 0.9, alpha = 0.5,
			glow = 0.9, tag = "dome" })
	end
end

--- YOUR OWN VIEW [C6.draw's camera punch + C6.v6_fpfx]: the kicks, and the radial dash streaks rushing past the view.
local function drawOwn(sl, cv, F)
	if not F.own or not F.cam then return end
	local b = F.b
	local zd = ZD()
	local kick = zd and zd.CameraKick
	-- real seconds per kit second through the glide (the kit's dash is T_ARR - T_GO = 0.26 kit s, the game's lasts Glide)
	local S = castTuning()
	local glide = (sl.Timing.Glide and sl.Timing.Glide > 0) and sl.Timing.Glide or S.DashTime
	local perKit = glide / timeScale() / (B.Arr - B.Go)
	if b >= B.Go - 0.01 and not sl.Fired.Kick then                 -- the FOV punch at takeoff, held through the dash
		sl.Fired.Kick = true
		if type(kick) == "function" and b < B.Arr then
			local ok, h = pcall(kick, { fov = T.KickFov, rise = math.max(T.KickMin, T.KickRise * perKit), hold = math.huge,
				decay = math.max(T.KickMin, T.KickDecay * perKit) })
			if ok and type(h) == "table" then sl.Kick = h end
		end
	end
	if b >= B.X and not sl.Fired.Jolt then                         -- the zoom jolt and shake on the X
		sl.Fired.Jolt = true
		if type(kick) == "function" and b < B.X + 0.25 then
			pcall(kick, { fov = T.JoltFov, shake = T.JoltShake, rise = 0, hold = 0, decay = T.JoltDecay })
		end
	end
	local e = env(b, B.Go - 0.02, B.Go + 0.04, B.Arr - 0.04, B.Arr + 0.12)
	if e <= 0.003 then return end
	local cf = F.camCF
	local pos, rgt, up, fwd = cf.Position, cf.RightVector, cf.UpVector, cf.LookVector
	for _, st in ipairs(STREAKS) do
		local rad = rgt * math.cos(st.A) + up * math.sin(st.A)
		local d0 = 1.2 + (st.Ph - T.StreakSpeed * F.rt) % 14.0
		local d1 = d0 + st.L
		local fade = e * sstep(d0, 1.2, 2.4)
		if fade > 0.003 then
			cv:Ribbon({ pos + fwd * d0 + rad * (st.R * (1 + 0.06 * d0)), pos + fwd * d1 + rad * (st.R * (1 + 0.06 * d1)) },
				0.035 + 0.02 * st.R, "core", { side = fwd:Cross(rad).Unit, fade = fade, glow = 1.1, tail = 0.5,
					maxSpans = T.Spans.Streak, tag = "own" })
		end
	end
end

--- PARTICLES [C4._particles, C5's pull, C6's takeoff puffs]: each beat's bursts, once, as the kit spawns them.
local function drawParticles(sl, cv, F)
	local b = F.b
	local c = sl.Character
	local lv = flat(F.dir) or Vector3.new(0, 0, -1)
	local rv = UP:Cross(lv)
	-- THE CHARGE: dust and specks pulled up off the floor round the feet (the vortex 0.6 ahead of them turns counter-
	-- clockwise about up, pulls in and lifts), puffs drawn in from above, a few sparks at the crossed hands
	if b >= 0.10 and b < B.Go and not sl.Fired.ChargeFloor then
		sl.Fired.ChargeFloor = true
		local floor = floorBelow(F.root, T.FloorReach, c)
		if floor then
			local centre = floor + lv * 0.6
			for i = 1, 6 do
				local a = (i - 1) * PI / 3 + 0.4
				local radial = lv * math.cos(a) + rv * math.sin(a)
				local tangent = UP:Cross(radial)
				local r = 2.1 + 1.1 * math.sin(i * 2.3)                     -- the kit's 1.0 .. 3.2
				burst(sl, cv, F, "cdust" .. i, "dust", centre + radial * r + UP * 0.15, T.ChargeDust, {
					dir = (tangent * 0.8 - radial * 0.6 + UP).Unit, cone = 0.35, up = 0, speed = { 2, 5 },
					life = { 0.5, 0.9 }, size = { 0.6, 1.2 } })
				burst(sl, cv, F, "cspeck" .. i, "speck", centre + radial * 2.2 + UP * (0.1 + 0.9 * ((i * 0.37) % 1)),
					T.ChargeSpecks, { dir = (tangent * 0.6 - radial * 0.4 + UP).Unit, cone = 0.3, up = 0, speed = { 2, 4 },
						life = { 0.4, 0.8 } })
			end
			for i = 1, 4 do
				local a = (i - 1) * PI / 2 + 1.1
				local radial = lv * math.cos(a) + rv * math.sin(a)
				burst(sl, cv, F, "cpuff" .. i, "puff", centre + radial * 3.0 + UP * (2.6 + 0.4 * i), 2, {
					dir = (UP:Cross(radial) * 0.4 - radial).Unit, cone = 0.2, up = 0, speed = { 3, 5 }, life = { 0.3, 0.6 },
					size = { 0.5, 0.9 } })
			end
		end
	end
	if b >= 0.30 and b < B.Go then
		burst(sl, cv, F, "cspark", "spark", (F.chargeC or F.chest) + UP * 0.6, 8, { speed = { 2, 5 }, life = { 0.3, 0.6 },
			size = { 0.5, 1.0 } })
	end
	-- THE HELD CHARGE: the pull goes on while the key is down (two streams turning round the feet)
	if sl.Timing.LaunchAt == nil and not sl.Freeze and b > 0.2 then
		local floor = floorBelow(F.root, T.FloorReach, c)
		if floor then
			for i = 0, 1 do
				local a = F.bs * 3.0 + i * PI
				local radial = lv * math.cos(a) + rv * math.sin(a)
				local tangent = UP:Cross(radial)
				local p = floor + lv * 0.6 + radial * 2.2 + UP * 0.15
				local dir = (tangent * 0.8 - radial * 0.6 + UP).Unit
				extra(cv, "Stream", "dust", p, T.HoldDustRate * F.pmul, { dir = dir, cone = 0.35, speed = { 2, 4 },
					life = { 0.5, 0.9 }, size = { 0.6, 1.1 }, id = "holdDust" .. i, tag = "particles" })
				extra(cv, "Stream", "speck", p + UP * 0.5, T.HoldSpeckRate * F.pmul, { dir = dir, cone = 0.3,
					speed = { 2, 4 }, life = { 0.4, 0.8 }, id = "holdSpeck" .. i, tag = "particles" })
			end
		end
	end
	-- THE TAKEOFF: 22 puffs thrown back off the launch (C6: tko_puff, normal -y, cone 1.6)
	if b >= B.Go and b < B.Go + 0.3 and sl.LaunchChest then
		burst(sl, cv, F, "tko", "puff", sl.LaunchChest - F.dir * 0.4 - F.up * 1.15, 22, { dir = -F.dir, cone = 1.6,
			speed = { 3, 7 }, life = { 0.4, 0.9 }, up = 0.05, size = { 1.0, 1.9 } })
	end
	-- THE TRENCH: dust and specks peel off the floor as the body passes, chips kicked up, mist in the wake (C4: 46
	-- dust + 46 specks over the kit's 19.5 studs, 10 chips, 6 mist; here per stud of glide)
	if sl.LaunchRoot and b >= B.Go and b <= B.Arr + 0.1 then
		local dist = (F.root - sl.LaunchRoot):Dot(F.dir)
		local last = math.min(math.floor(dist), T.TrenchSteps)
		local floorY = sl.TrenchHead and sl.TrenchHead.Y
		while sl.TrenchK < last do
			sl.TrenchK += 1
			local k = sl.TrenchK
			local p = sl.LaunchRoot + F.dir * k
			if floorY then
				local g = Vector3.new(p.X, floorY + 0.15, p.Z)
				for _, sd in ipairs({ 1, -1 }) do
					burst(sl, cv, F, "tdust" .. k .. sd, "dust", g, 1, { dir = (rv * (5 * sd) + lv * 7 + UP * 1.5).Unit,
						cone = 0.25, up = 0, speed = { 4, 10 }, life = { 0.7, 1.3 }, size = { 0.7, 1.3 } })
				end
				burst(sl, cv, F, "tspeck" .. k, "speck", g, 2, { dir = (lv * 12 + UP * 3.5).Unit, cone = 0.3, up = 0,
					speed = { 8, 16 }, life = { 0.5, 0.7 } })
				if k % 2 == 0 then
					burst(sl, cv, F, "tchip" .. k, "chip", g, 1, { dir = (lv + UP).Unit, cone = 0.4, up = 0,
						speed = { 6, 10 }, life = { 1.2, 1.6 }, size = { 0.6, 1.1 } })
				end
			end
			if k % 3 == 0 then
				burst(sl, cv, F, "tmist" .. k, "mist", p + UP * (-1.5 + 2.0 * ((k * 0.618) % 1)), 1, { dir = lv,
					cone = 0.1, up = 0, speed = { 5, 7 }, life = { 0.6, 0.8 } })
			end
		end
	end
	-- THE X (a cast heard late past the crossing throws nothing, as the toon look's debris did not)
	local X = sl.X
	if X and b >= B.X and b < B.X + 0.25 then
		if X.Floor then
			local feet = X.Floor + UP * 0.3
			burst(sl, cv, F, "xdust", "dust", feet, 34, { speed = { 6, 14 }, life = { 0.8, 1.6 }, up = 0.05,
				size = { 0.8, 1.6 } })
			burst(sl, cv, F, "xchipF", "chip", feet, 18, { speed = { 6, 13 }, life = { 0.8, 1.4 }, up = 0.9 })
		end
		burst(sl, cv, F, "xchip", "chip", X.C, 8, { dir = X.N, cone = 0.9, speed = { 5, 10 }, life = { 0.7, 1.2 } })
		burst(sl, cv, F, "xspark", "spark", X.C, 32, { speed = { 8, 22 }, life = { 0.25, 0.7 }, size = { 0.5, 1.3 } })
		burst(sl, cv, F, "xpuff", "puff", X.C, 16, { speed = { 3, 9 }, life = { 0.5, 1.1 }, size = { 0.6, 1.4 } })
		burst(sl, cv, F, "xspeck", "speck", X.C, 34, { speed = { 10, 24 }, life = { 0.3, 0.7 } })
		if b >= B.X + 0.04 then
			burst(sl, cv, F, "xmist", "mist", X.C, 8, { speed = { 3, 7 }, life = { 0.8, 1.5 }, size = { 1.0, 1.8 } })
		end
	end
end

--- THE LIGHT [C6.draw]: chest -> X; charge 380 W, dash 700 W, the X's flash 2600 W (tau 0.22) + the 900 W bulb, the
--- dome's 260 W tail.
local function drawLight(sl, cv, F)
	local b = F.b
	local ech = env(b, 0.12, 0.30, B.Go, B.Go + 0.1)
	local eda = env(b, B.Go, B.Go + 0.04, B.Arr, B.X)
	local ex = (b >= B.X - 0.005) and math.exp(-math.max(0, b - B.X) / 0.22) or 0
	local tailW = (b > B.X) and (1 - span(b, B.X, B.X + 1.15)) or 0
	local watts = 380 * ech * (1 + T.HoldLight * F.hold) + 700 * eda
		+ (2600 * ex + 900 * flashCurve(b, B.X, 1.0, 0.02, 0.07)) * F.rfk + 260 * tailW
	if watts <= 1 then return end
	local pos
	if b < B.X or not sl.X then
		pos = F.chest + (flat(F.dir) or F.dir) * 0.9 + UP * 0.3        -- the kit: chest + (0, 0.9, 0.3)
	else
		pos = sl.X.C - UP * 0.4                                         -- the kit: XC + (0, 0, -0.4)
	end
	extra(cv, "Light", pos, watts, { range = (b < B.X) and T.LightRange or T.LightRangeX, color = T.LightColor,
		tag = "light" })
end

----------------------------------------------------------------------------------------------------
-- ONE FRAME
----------------------------------------------------------------------------------------------------
local function step(sl, cv, t)
	local c = sl.Character
	local root = c and c.Parent and c:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local zfx = ZFX()
	local S = castTuning()
	if not (zfx and S) then return false end
	local timing = sl.Timing
	-- a charge nobody launched or dropped (a lost broadcast) is let go well after the longest hold, as ZephyrFX lets
	-- its record go
	if not sl.Freeze and timing.LaunchAt == nil and os.clock() - timing.Start > S.MaxHold + 2 then return false end
	local b = CrossSlash.ToKit(t, S)
	if b > B.End then return false end
	-- charging, the look faces the way the body faces (it can turn and walk); from the launch, the dash's own direction
	if not sl.Dir then sl.Level = flat(root.CFrame.LookVector) or sl.Level end
	local dir = sl.Dir or sl.Level
	local frame = zfx.CrossSlashFrame(ZERO, dir)
	local cam = workspace.CurrentCamera
	local camCF = cam and cam.CFrame or CFrame.identity
	local own = false
	if sl.ForceOwn ~= nil then
		own = sl.ForceOwn
	elseif sl.OwnChar and cam then
		local head = c:FindFirstChild("Head")
		own = head ~= nil and (camCF.Position - head.Position).Magnitude < T.OwnNear
	end
	-- sample the body (by kit time)
	local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
	local chest = torso and torso.Position or (root.Position + Vector3.new(0, 1, 0))
	local fr, fl = nil, nil
	if own then
		local vm = Viewmodel()
		if vm and type(vm.GetFistCFrame) == "function" then
			local okR, cfR = pcall(vm.GetFistCFrame, "R")
			local okL, cfL = pcall(vm.GetFistCFrame, "L")
			if okR and okL and typeof(cfR) == "CFrame" and typeof(cfL) == "CFrame" then
				fr, fl = camCF:PointToObjectSpace(cfR.Position), camCF:PointToObjectSpace(cfL.Position)
				sl.Fists = true
			end
		end
	end
	sl.LastChest, sl.LastRoot = chest, root.Position
	record(sl, b, root.Position, chest, handOf(c, "R") or chest, handOf(c, "L") or chest, fr, fl)
	-- this frame's context
	local F = sl.F
	F.b, F.own, F.dir, F.right, F.up = b, own, dir, frame.RightVector, frame.UpVector
	F.cam, F.camCF = cam, camCF
	F.root = root.Position + ghostOff(sl, b)
	F.chest = chest + ghostOff(sl, b)
	F.torsoCF = torso and torso.CFrame or root.CFrame
	F.fistR = fr and camCF:PointToWorldSpace(fr) or nil
	F.fistL = fl and camCF:PointToWorldSpace(fl) or nil
	F.chargeC = nil
	F.rfk = reduceFlashing() and T.ReducedFlashScale or 1
	F.pmul = T.ParticleScale
	F.hold = holdShare(timing, S, sl.Freeze ~= nil)
	-- the turning clock: kit time, plus however long the charge was held with the look's clock standing still
	local r = sl.Freeze or (os.clock() - timing.Start) * timeScale()
	if b < B.Go then sl.Hx = math.max(sl.Hx, r * B.Go / S.ChargeTime - b) end
	F.bs = b + sl.Hx
	F.rt = sl.Freeze or os.clock() * timeScale()                     -- the real clock (the own-view streaks)
	-- the launch, as the kit's takeoff: where the chest, the root and the floor were
	if not sl.LaunchChest and b >= B.Go then
		sl.LaunchChest = chestAt(sl, B.Go)
		sl.LaunchRoot = rootAt(sl, B.Go)
		sl.LaunchFloor = floorBelow(sl.LaunchRoot, T.FloorReach, c)
	end
	captureX(sl, F, S)
	drawCharge(sl, cv, F)
	drawTakeoff(sl, cv, F)
	drawTrails(sl, cv, F)
	drawDash(sl, cv, F)
	drawTrench(sl, cv, F)
	drawX(sl, cv, F)
	drawDome(sl, cv, F)
	drawOwn(sl, cv, F)
	-- the held takeoff punch eases out into the arrival (or at once if the view stopped being your own)
	if sl.Kick and (b >= T.KickRelease or not own) then
		local k = sl.Kick
		sl.Kick = nil
		pcall(function() k:Release() end)
	end
	drawParticles(sl, cv, F)
	drawLight(sl, cv, F)
	return true
end

----------------------------------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------------------------------
local casts = {}             -- [character] = its look (one per character)

local function endLook(sl)
	if casts[sl.Character] == sl then casts[sl.Character] = nil end
	local k = sl.Kick                                               -- a held takeoff punch lets go with its look
	sl.Kick = nil
	if k then pcall(function() k:Release() end) end
	local h = sl.Handle
	if h then pcall(function() h:Stop() end) end
end

--- A cast's look on `character` (see the header). nil when it cannot be drawn: on the server, or without ZephyrDraw.
function CrossSlash.Play(character, dir, timing, opts)
	opts = opts or {}
	if not RunService:IsClient() then return nil end
	if typeof(character) ~= "Instance" or type(timing) ~= "table" then return nil end
	local zd, zfx = ZD(), ZFX()
	if not (zd and zfx and type(zd.Play) == "function") then
		warnOnce("noEngine", "ZephyrDraw is not loaded - the Cross-Slash plays, but it is not drawn")
		return nil
	end
	local S = zfx.Tuning.CrossSlash
	local old = casts[character]
	if old then endLook(old) end
	if dir ~= nil and (typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3) then dir = nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	local player = Players.LocalPlayer
	local sl = {
		Character = character, Timing = timing, Dir = dir and dir.Unit or nil,
		Level = (dir and flat(dir)) or (root and flat(root.CFrame.LookVector)) or Vector3.new(0, 0, -1),
		Target = (typeof(opts.Target) == "Instance" and opts.Target:IsA("Model")) and opts.Target or nil,
		Ghost = opts.Ghost, ForceOwn = opts.Own, Freeze = tonumber(opts.FreezeLook),
		OwnChar = player ~= nil and character == player.Character,
		Hist = {}, Fired = {}, F = {}, Hx = 0, TrenchK = 0,
	}
	local lookEnd = CrossSlash.FromKit(B.End, S)
	local clock
	if sl.Freeze then
		local held = sl.Freeze
		clock = function() return held end
	else
		clock = function() return zfx.CrossSlashTime(timing) end
	end
	local handle = zd.Play("ZephyrCrossSlash", function(cv, t) return step(sl, cv, t) end, {
		Clock = clock,
		Freeze = sl.Freeze,
		Until = (not sl.Freeze) and lookEnd or nil,
		MaxLife = sl.Freeze and 3600 or (S.MaxHold + 2 + lookEnd + T.MaxLifePad),
		Budget = (type(zd.Budgets) == "table" and zd.Budgets.CrossSlash) and "CrossSlash" or T.Budget,
		-- your own cast is never thinned by Reduce Enemy VFX, nor (2026-10-19, audit P5F-06) a teammate's
		Own = sl.OwnChar or (type(zd.Friendly) == "function" and zd.Friendly(character) == true),
		OnEnd = function()
			if casts[character] == sl then casts[character] = nil end
			local k = sl.Kick                                   -- a look that ended early lets its held punch go
			sl.Kick = nil
			if k then pcall(function() k:Release() end) end
		end,
	})
	if not handle then return nil end
	sl.Handle = handle
	casts[character] = sl
	return handle
end

--- The held cast launched: from here the look runs along `dir` (3D). False when no look is running for `character`.
function CrossSlash.Launch(character, dir)
	local sl = casts[character]
	if not sl or typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3 then return false end
	sl.Dir = dir.Unit
	sl.Level = flat(sl.Dir) or sl.Level
	return true
end

--- A held cast dropped before its launch: its look ends at once. A launched one is left to finish.
function CrossSlash.Cancel(character)
	local sl = casts[character]
	if sl and not sl.Dir then endLook(sl) end
end

function CrossSlash.Stop(character)
	local sl = casts[character]
	if sl then endLook(sl) end
end

function CrossSlash.StopAll()
	local list = {}
	for _, sl in pairs(casts) do list[#list + 1] = sl end
	for _, sl in ipairs(list) do endLook(sl) end
end

function CrossSlash.Active(character)
	return casts[character] ~= nil
end

----------------------------------------------------------------------------------------------------
-- DEMO (the test harness: the showcase's whole choreography, no server; see the header)
----------------------------------------------------------------------------------------------------
-- the kit's hero camera (cross_slash_v4.CAM, CamTrack keys): { kit s, position (stage x, y, z), look-at (x, y, z),
-- vertical FOV, the ease INTO this key } -- the front three-quarter on the caster's lit side, the push-in on the crossed
-- arms, the swing to track the dash, the arrival two-shot of the X on dummy 1, the slow drift out
local HERO_CAM = {
	{ -1.00, 9.5, 10.5, 4.4, 0.0, 0.8, 2.8, 40, "lin" },
	{ 0.42, 8.4, 9.2, 4.1, 0.0, 0.9, 3.0, 38, "io" },
	{ 0.62, 10.5, 9.0, 4.4, 0.0, 9.0, 2.9, 46, "io" },
	{ 0.80, 12.5, 9.8, 4.7, 0.0, 17.2, 3.2, 44, "out" },
	{ 1.30, 12.0, 10.6, 4.6, 0.0, 17.4, 3.2, 41, "io" },
	{ 3.20, 12.8, 11.5, 5.0, 0.0, 18.5, 3.0, 40, "io" },
}
local KIT_D1 = 15.0          -- cross_slash_dash_bl.D1: dummy 1 stands 15 studs down the 21.3-stud dash: it is dashed THROUGH
local SKID_YAW = -1.10       -- cross_slash_dash_bl.SKID_YAW: the skid-turn on arrival (toward the camera side)
local THROW = 2.3            -- cross_slash_v4.THROW: dummy 1 is thrown back THROW x the round-2 slide
-- dummy 1's reaction (cross_slash_dash_bl.DUMMY1 on the tc clock): { kit s after T_X, its root's slide back (studs, before
-- THROW), its lean (rad; + forward: the kit's pelvis + spine pitch, halved -- the whole body tips here, since the dummy's
-- joints are not ours to pose), the ease INTO the key }: HIT, the stumble STEP, the CATCH, SETTLE
local D1_TRACK = {
	{ -0.004, 0.00, 0.00, "lin" },
	{ 0.06, 0.70, -0.26, "out" },
	{ 0.30, 1.85, -0.15, "io" },
	{ 0.62, 2.30, 0.03, "io" },
	{ 1.40, 2.42, 0.00, "io" },
}
-- its BACK in the stage: D1_YAW -0.47 turns its front to (+0.45, +0.89), the arrival side; the X shoves it the other way
local D1_BACK_X, D1_BACK_Y = -0.453, -0.892
local DEMO_STEP = "ZephyrCrossSlashDemo"
local DEMO_PRIORITY = Enum.RenderPriority.Camera.Value + 8   -- after the camera, the shoulder shift and the root's
                                                              -- face-the-camera (FirstPersonController, Camera + 2);
                                                              -- before CastPose and ZephyrDraw sample the body

--- zk's eases by name (CamTrack / PoseTrack) and zk.back (ease-out with overshoot)
local function easeIn(u)
	u = clamp01(u)
	return u * u * u
end
local EASES = { lin = clamp01, io = ease, out = easeOut, inn = easeIn }
local function back(u, s)
	s = s or 1.70158
	u = clamp01(u) - 1
	return u * u * ((s + 1) * u + s) + 1
end

--- v4's tc: the actors' two-frame hit-stop at T_X (effects keep running).
local function tcTime(b)
	if b < B.X then return b end
	if b < B.X + 2 / 30 then return B.X end
	return b - 2 / 30
end

--- The caster's pose clock: v5 holds the slash pose 0.14 s from T_X + 2/30, then v4's hit-stop (tc).
local function poseTime(b)
	local a = B.X + 2 / 30
	if b >= a then b = (b < a + 0.14) and a or (b - 0.14) end
	return tcTime(b)
end

--- cross_slash_dash_bl.yaw_of: the skid-turn on arrival, then a small turn back toward the X.
local function yawOf(x)
	return SKID_YAW * back(span(x, 0.69, 0.92), 1.2) + 0.18 * ease(span(x, 1.05, 1.9))
end

--- CamTrack.at: the hero camera at kit time b -> position, look-at (stage), vertical FOV.
local function heroCam(b)
	local k = HERO_CAM
	local a, c, w = k[1], k[1], 0
	if b > k[1][1] then
		a, c = k[#k], k[#k]
		for i = 1, #k - 1 do
			if b <= k[i + 1][1] then
				a, c = k[i], k[i + 1]
				w = EASES[c[9]]((b - a[1]) / math.max(1e-6, c[1] - a[1]))
				break
			end
		end
	end
	local function l(j) return a[j] + (c[j] - a[j]) * w end
	return Vector3.new(l(2), l(3), l(4)), Vector3.new(l(5), l(6), l(7)), l(8)
end

--- Dummy 1's slide (studs, THROW applied), lean and twist at kit time b.
local function dummyReaction(b)
	local x = tcTime(b)
	local rel = x - B.X
	local k = D1_TRACK
	local slide, lean = 0, 0
	if rel >= k[#k][1] then
		slide, lean = k[#k][2], k[#k][3]
	elseif rel > k[1][1] then
		for i = 1, #k - 1 do
			local a, c = k[i], k[i + 1]
			if rel <= c[1] then
				local w = EASES[c[4]]((rel - a[1]) / (c[1] - a[1]))
				slide, lean = a[2] + (c[2] - a[2]) * w, a[3] + (c[3] - a[3]) * w
				break
			end
		end
	end
	local twist = 0.24 * sstep(x, B.X, B.X + 0.30) - 0.10 * sstep(x, B.X + 0.5, B.X + 1.3)
	return slide * THROW, lean, twist
end

--- The showcase's choreography on the real bodies, frame by frame on the look's clock (live in a running game only):
--- the caster's dash down the kit's root track (scaled to the demo's distance) with the skid-turn, dummy 1 thrown back
--- by the X, and the kit's hero camera. Everything is put back by the returned stop function (and by itself once the
--- look has ended). Anchored for the demo: no physics fights the placement, nothing is sent to the server.
local function startChoreo(character, root, target, dir, sy, clock, S, opts)
	local cam = workspace.CurrentCamera
	local useCam = cam ~= nil and opts.Own ~= true and opts.Camera ~= false
	local r0, anchored0 = root.CFrame, root.Anchored
	local floor = floorBelow(r0.Position, T.FloorReach, character)
	local floorY = floor and floor.Y or (r0.Position.Y - 3)
	local p0 = r0.Position
	local base = CFrame.lookAt(p0, p0 + dir)                                  -- the root's own height, facing the dash
	local stage = CFrame.lookAt(Vector3.new(p0.X, floorY, p0.Z), Vector3.new(p0.X + dir.X, floorY, p0.Z + dir.Z))
	-- dummy 1 (a static, anchored one only: a moving dummy is the server's physics)
	local dummy, pivot0, feet, push, axis = nil, nil, nil, nil, nil
	local dRoot = target and (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart)
	if dRoot and dRoot:IsA("BasePart") and dRoot.Anchored and opts.React ~= false then
		dummy, pivot0 = target, target:GetPivot()
		local f = floorBelow(dRoot.Position, T.XFloorReach, nil)
		feet = Vector3.new(dRoot.Position.X, f and f.Y or (dRoot.Position.Y - 3), dRoot.Position.Z)
		push = stage:VectorToWorldSpace(Vector3.new(D1_BACK_X, 0, -D1_BACK_Y))
		push = flat(push) or -dir
		axis = UP:Cross(push).Unit
	end
	-- the camera, and the body shown to it (first person hides it)
	local camType, camSubject, camFov, camCF = nil, nil, nil, nil
	local shown = {}
	if useCam then
		camType, camSubject, camFov, camCF = cam.CameraType, cam.CameraSubject, cam.FieldOfView, cam.CFrame
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then shown[d] = d.LocalTransparencyModifier end
		end
	end
	root.Anchored = true
	local done = false
	local function finish()
		if done then return end
		done = true
		pcall(function() RunService:UnbindFromRenderStep(DEMO_STEP) end)
		pcall(function()
			if root.Parent then
				root.CFrame = r0
				root.AssemblyLinearVelocity = ZERO
				root.Anchored = anchored0
			end
		end)
		if dummy then pcall(function() if dummy.Parent then dummy:PivotTo(pivot0) end end) end
		if useCam then
			pcall(function()
				cam.CameraType = camType
				cam.CameraSubject = camSubject
				cam.FieldOfView = camFov
				if camType == Enum.CameraType.Scriptable then cam.CFrame = camCF end
			end)
			for inst, v in pairs(shown) do
				if inst.Parent then pcall(function() inst.LocalTransparencyModifier = v end) end
			end
		end
	end
	pcall(function() RunService:UnbindFromRenderStep(DEMO_STEP) end)
	RunService:BindToRenderStep(DEMO_STEP, DEMO_PRIORITY, function()
		local ok, err = pcall(function()
			if not (root.Parent and character.Parent) then finish() return end
			local b = CrossSlash.ToKit(clock(), S)
			if b > B.End + 0.05 then finish() return end
			-- the caster: the kit's root track along the dash, the skid-turn on arrival
			local x = poseTime(b)
			root.CFrame = (base + base.LookVector * (rootY(x) * sy)) * CFrame.Angles(0, yawOf(x), 0)
			root.AssemblyLinearVelocity = ZERO
			-- dummy 1, thrown back by the X
			if dummy and dummy.Parent then
				local slide, lean, twist = dummyReaction(b)
				local m = CFrame.new(feet + push * slide) * CFrame.fromAxisAngle(axis, -lean) * CFrame.Angles(0, twist, 0)
					* CFrame.new(-feet)
				dummy:PivotTo(m * pivot0)
			end
			-- the hero camera (its y along the dash scaled with it), the small impulse on the X
			if useCam then
				local pos, look, fov = heroCam(b)
				if b >= B.X then
					local s = 0.10 * math.exp(-(b - B.X) / 0.10)
					pos += Vector3.new(math.sin(b * 91), math.sin(b * 73 + 1), math.sin(b * 67 + 2)) * s
				end
				local wp = stage:PointToWorldSpace(Vector3.new(pos.X, pos.Z, -pos.Y * sy))
				local wl = stage:PointToWorldSpace(Vector3.new(look.X, look.Z, -look.Y * sy))
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = CFrame.lookAt(wp, wl)
				cam.Focus = CFrame.new(wl)
				cam.FieldOfView = fov
				for inst in pairs(shown) do
					if inst.Parent and inst.LocalTransparencyModifier ~= 0 then inst.LocalTransparencyModifier = 0 end
				end
			end
		end)
		if not ok then
			warnOnce("demoStep", "the demo's choreography failed: " .. tostring(err))
			finish()
		end
	end)
	return finish
end

local lastDemo = nil         -- the demo that is up: { Stop(), Canvas, Handle }
--- The nearest living training dummy ahead of `root` (inside 60 degrees of its facing, within DemoReach), and how far.
local function demoTarget(character, root)
	local look = flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local best, bestD = nil, math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d ~= character and d:GetAttribute("TrainingDummy") then
			local h = d:FindFirstChildOfClass("Humanoid")
			local r = d:FindFirstChild("HumanoidRootPart") or d.PrimaryPart
			if h and h.Health > 0 and r then
				local to = r.Position - root.Position
				local fl = Vector3.new(to.X, 0, to.Z)
				local dist = fl.Magnitude
				if dist > 4 and dist < T.DemoReach and dist < bestD and fl.Unit:Dot(look) > 0.5 then
					best, bestD = d, dist
				end
			end
		end
	end
	return best, bestD
end

--- Plays the Cross-Slash on `character` without the server, as the showcase plays it (see the header). opts: Hold (s of
--- held charge, 0 = a tap), Distance (studs, overrides), Own (your own first-person view), Freeze (KIT s: hold that one
--- frame), FreezeLook (the same in look s), Pose (false: no body clip / arms), Move (false: the body stays put and the
--- look runs along a ghost path), Camera (false: keep your camera), React (false: dummy 1 stays put). Returns
--- { Stop(), Canvas, Handle } or nil.
function CrossSlash.Demo(character, opts)
	opts = opts or {}
	if not RunService:IsClient() then return nil end
	local zfx = ZFX()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (zfx and root) then return nil end
	if lastDemo then lastDemo.Stop() end                 -- one demo at a time (its pose, arms and bodies let go first)
	local S = zfx.Tuning.CrossSlash
	local scale = timeScale()
	local own = opts.Own == true
	local move = opts.Move ~= false and RunService:IsRunning()   -- bodies and the camera move only in a running game
	local hold = math.clamp(tonumber(opts.Hold) or 0, 0, S.MaxHold)
	local target, tdist = demoTarget(character, root)
	local kitLen = B.DashY1 - B.DashY0
	local dir, dist
	if target then
		-- the kit's geometry: dummy 1 KIT_D1 down a kitLen dash, so the dash goes THROUGH it and the X lands on it
		local tr = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
		dir = flat(tr.Position - root.Position) or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
		dist = tdist * kitLen / KIT_D1
	else
		dir = flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
		dist = (hold > 0) and (S.MinDistance + (S.MaxDistance - S.MinDistance) * math.clamp(hold / S.FullChargeTime, 0, 1))
			or kitLen
	end
	if tonumber(opts.Distance) then dist = tonumber(opts.Distance) end
	dist = math.clamp(dist, S.MinDistance, S.MaxDistance)
	-- the cast's clock exactly as SpellshotInput books it: a tap launches at ChargeTime, a hold as soon as the wind-up has
	-- played the beat it was held on out, and the glide lasts the distance at the glide's pace
	local timing = zfx.CrossSlashTiming()
	timing.LaunchAt = math.max(S.ChargeTime, hold * scale + (S.ChargeTime - S.HoldPose))
	timing.Glide = dist / (S.DashDistance / S.DashTime) * scale
	local freeze = tonumber(opts.FreezeLook)
	if not freeze and tonumber(opts.Freeze) then freeze = CrossSlash.FromKit(tonumber(opts.Freeze), S) end
	local sy = dist / kitLen                                 -- the stage's dash axis, scaled to this dash
	local ghost = (not move and not own) and { Dir = dir, Scale = sy } or nil
	local clock = freeze and function() return freeze end or function() return zfx.CrossSlashTime(timing) end
	-- the bodies and the camera are placed BEFORE the look's first frame samples them
	local unChoreo = nil
	if move then
		local ok, res = pcall(startChoreo, character, root, target, dir, sy, clock, S, opts)
		if ok then unChoreo = res else warnOnce("demoStart", "the demo's choreography did not start: " .. tostring(res)) end
	end
	local handle = CrossSlash.Play(character, dir, timing, { Target = target, Ghost = ghost, Own = own,
		FreezeLook = freeze })
	if not handle then
		if unChoreo then unChoreo() end
		return nil
	end
	local posed, armed = false, false
	if opts.Pose ~= false then
		local cp = CastPose()
		if cp and type(cp.PlayClocked) == "function" then
			posed = pcall(cp.PlayClocked, character, "CrossSlashDash", clock)
		end
		local vm = own and Viewmodel()
		if vm and type(vm.Play) == "function" then
			armed = pcall(vm.Play, "CrossSlashDash", clock)
		end
	end
	local demo = { Handle = handle, Canvas = handle.Canvas }
	function demo.Stop()
		pcall(function() handle:Stop() end)
		if unChoreo then unChoreo() end
		if posed then
			local cp = CastPose()
			if cp and type(cp.Stop) == "function" then pcall(cp.Stop, character) end
		end
		if armed then
			local vm = Viewmodel()
			if vm and type(vm.CurrentClip) == "function" and vm.CurrentClip() == "CrossSlashDash" then pcall(vm.Stop) end
		end
		if lastDemo == demo then lastDemo = nil end
	end
	lastDemo = demo
	return demo
end

--- Stops the demo that is up, if any (the harness calls this after the handle's own :Stop()).
function CrossSlash.StopDemo()
	if lastDemo then lastDemo.Stop() end
end

return CrossSlash
