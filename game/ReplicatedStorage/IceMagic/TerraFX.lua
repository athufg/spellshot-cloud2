--[[
	TerraFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/TerraFX

	The Terra kit's visuals, and the numbers both sides share (Tuning), which TerraHandler on the server requires
	so the client and the server throw the same boulder along the same arc.

	  Boulder Shot   the M1, reworked 2026-09-23 (the kit's one realistic-lighting exception): Charge (eleven pieces
	                 torn out of the floor into the hand, a rock that grows with the charge), FireBoulder (the same rock
	                 thrown along the game's arc, and broken back into its pieces where it stops)
	  Bulwark Wall   the Defense (2026-09-19): the kit's twelve slabs raised, cracked hit by hit, broken or sunk
	  Aftershock     the Mobility (2026-09-25; it replaces Tremor Vault, and extends the M1's realistic-lighting
	                 exception, earth-toned and with no glow): both fists into the ground, and a ring of erupting rock
	                 racing out 24 studs -- the ground plates heaved by the front, the rock thrown out of it, the scar healing
	  Earthen Tomb   the Ultimate (v2, 2026-09-19): the homing fissure, the stone fist, the burst -- its own kit

	MESHES FIRST, PARTS AS THE FALLBACK (VFX polish, 2026-09-18). The Quarry Slab kit (blender_scripts/terra,
	export/terra_kit/TerraKit.fbx) imported into ReplicatedStorage.EarthMagicMeshes gives every rock, plate,
	star and crack its baked Dark / Base / Light bands and an inverted-hull ink outline, as the Cryo, Pyro and
	Zephyr kits have. Until it is imported each piece falls back to the Parts it was first built from:
	flat SmoothPlastic, opaque, one tone per facet, and a Highlight per rock for its ink (fill off, DepthMode
	Occluded). The Part look is the kit running, not the kit finished -- a Part has no backface culling, so it
	cannot carry a hull, and the Highlights were not drawing in the recorded tests.

	Also here: Bedrock's shell, Bulwark Charge's armour and footfalls, and the Staggered stars (each section says
	what it draws), and TerraFX.CameraPunch -- the kit's impact punch through the Viewmodel's own camera path.

	Nothing here fades: a rock that must go shrinks or is destroyed outright. (The two lit pieces, Boulder Shot and
	Aftershock, sink their rubble into the floor; only their dust, their marks and Aftershock's dark underlay fade.)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerraFX = {}

----------------------------------------------------------------------------------------------------
-- tuning (read by TerraHandler too). EVERY NUMBER HERE IS NEW (2026-09-17): the design manual gives
-- Terra behaviour and no figures, and SpellshotConfig had none either. They are calibrated against the
-- built Cryo and Pyro kits -- Terra throws slower and hits harder than either -- and are meant to be tuned.
----------------------------------------------------------------------------------------------------
TerraFX.Tuning = {
	BoulderShot = {
		-- THE CHARGE. Releasing instantly still throws a proper boulder: MinScale is a rock, not a pebble, and
		-- MinDamage is already the hardest M1 hit in the game (Fireball's direct is 18, Icicle Shard's 12).
		-- Holding to ChargeTime doubles the damage and nearly doubles the rock.
		ChargeTime = 1.10,          -- seconds of hold to reach full
		MinDamage = 24, MaxDamage = 48,
		MinScale = 1.00, MaxScale = 1.85,      -- x RockSize: 2.2 studs across at a tap, 4.1 at full
		RockSize = 2.2,
		-- THE FLIGHT. A thrown rock, so it drops: it has to be led, like the manual's Fireball lob. The heavier
		-- it was the slower it left the hand (until 2026-10-17; now every charge flies at the shared M1 speed).
		MinSpeed = 200, MaxSpeed = 200,   --[[one speed for every M1 projectile since 2026-10-17 (the owner: charge time may differ, speed should not); was 108 / 86]]
		Gravity = 26,               -- studs/s^2 of drop
		Life = 2.4,                 -- seconds before it burns out (it has already fallen a long way by then)
		Radius = 1.1,               -- x scale: the slack the server's line check allows for the rock's own size
		-- THE PRE-REWORK LOOK (2026-09-18), no longer drawn: the held rock pushed out to HandForward and drawn at
		-- HandScale, a 3.2 rad/s tumble, 14 chunks and 10 grit. Kept because the rework's Blender film and its
		-- continuity chart model the old build from them (blender_scripts/terra/m1_rework_bl.py, m1_rework_chart.py).
		HandForward = 3.4, HandDown = 1.0, HandSide = 1.5, HandScale = 0.5,
		Spin = 3.2,
		Chunks = 14, Grit = 10,
		BurstTime = 0.22,
		-- THE REWORK'S LOOK (2026-09-23; Opus5-5_Terra_M1_BlenderShowcase.md, built in Blender first and brought in
		-- on request). LOOK ONLY -- the server reads none of it. EVERY NUMBER BELOW IS A PROPOSAL (the film's T).
		-- 1 WINDUP: the rock's eleven pieces tear out of the floor and are whole by Core -- the tap window, so a tap
		-- still throws a whole rock -- and Feeders more stones rise and are pressed into it from FeedFrom to FeedTo
		-- of the charge's seconds, each swelling it a step.
		Core = 0.18, Feeders = 24, FeedFrom = 0.14, FeedTo = 0.98,
		-- 2 THROW: the button comes up and the arm drives; the rock you SEE leaves the hand Trigger later, at the top
		-- of the drive (Viewmodel / CastPose BoulderThrow's Trigger). The shot itself left on the button.
		Trigger = 0.05,
		-- 3 FLIGHT: a real tumble (Spin 3.2 turned the rock 48 degrees in a whole flight), and what it sheds a second
		VisualSpin = 12, TrailChips = 45, TrailDust = 60,
		-- First person, the held rock is drawn at the fist but STANDS IN for the rock at its true size FPDepth studs
		-- out along the eye -> fist line, and it is out on the game's own line FPMerge after it leaves the hand. The
		-- film's 8.2 (FULL / 0.5) made it a quarter of the frame's height at full charge through a 90-degree lens; the
		-- game's is 110 degrees, and at the fist's corner of that wide a view the rock came out at a third of the
		-- height (measured in Play, 2026-09-23). 11 puts it back at the film's quarter.
		FPDepth = 11, FPMerge = 0.20,
		-- 4 IMPACT: the rock breaks back into its pieces, plus chunks and grit, falling at DebrisGravity (studs/s^2:
		-- 9.81 m/s^2 at 0.28 m a stud; the workspace's 196.2 is held back by a force); Settle after the hit it is
		-- all held and sunk into the floor over Sink, and the scuff it left holds to Scuff and clears in 0.8 s.
		DebrisGravity = 35, DebrisChunks = 14, DebrisGrit = 30, Settle = 1.8, Sink = 0.5, Scuff = 2.5,
	},

	-- PRIMARY: BULWARK CHARGE. A shouldered charge forward that knocks down whatever it reaches. The
	-- movement is the caster's own client (DashMotor, as Frost Slide and Cross-Slash Dash are); the server
	-- sweeps its OWN copy of the body while it runs, so what gets knocked down is what the server saw the
	-- charger reach, not what the charger claimed.
	BulwarkCharge = {
		Distance = 26, Time = 0.62, MaxTime = 0.95, MinCap = 16, --[[12 until the 2026-10-17 balance pass]]
		Reduction = 0.40,           -- share taken off every hit while the charge runs: this is the "with
		                            -- damage reduction" half of the manual's line
		Damage = 35,
		Reach = 3.6, HalfWidth = 3.2, HalfHeight = 4.5,   -- the shoulder's box, around the charger
		Stagger = 1.20,             -- seconds of Staggered on whoever it knocks down
		Knock = 30, KnockLift = 14, -- studs/s along the charge, and up, thrown into the victim
		TrailEvery = 0.05, TrailLife = 0.45, TrailBack = 1.6,
	},

	-- PASSIVE: BEDROCK. Two layers, as the manual describes it. FLAT is always on while you are Terra --
	-- the reason a slow Element survives being walked at. STACKS build only while you are committed to an
	-- attack: charging a Boulder Shot, or mid Bulwark Charge. Commit longer, take less.
	Bedrock = {
		Flat = 0.10,                -- share taken off every hit, always, while playing Terra
		PerStack = 0.04,            -- ...and this much more per stack
		MaxStacks = 5,              -- so 30% at full: flat 10 + 20
		StackEvery = 0.22,          -- seconds of committing per stack gained
		Lapse = 2.5,                -- stacks fall off this long after you stop committing (Icicle Shard's
		                            -- stack-lapse shape, at a value of its own)
		-- The shell: plates that assemble around the chest, one per stack, each a slab with an ink outline.
		-- Not a bubble and not a glow -- armour arriving.
		PlateRadius = 2.6, PlateRise = 0.55, PlateTime = 0.12,
		-- Each plate CURVES round the body it rings (2026-09-18) instead of standing flat beside it: it bends
		-- on a circle PlateBend studs across the ring's own radius, so it sits flush on the ring it orbits, and
		-- it is PlateFacets flat columns -- a couple of shallow folds, still cut stone, never a smooth arc.
		PlateBend = 2.6, PlateFacets = 3,
	},

	-- DEFENSE: BULWARK WALL (2026-09-19). The one wall in the game. Its design, as the kit's showcase set it down: a
	-- channelled HOLD, capped, that BREAKS ON DAMAGE; the cooldown (SpellshotConfig.Defense.BulwarkWall, the manual's 16 s)
	-- starts when it drops, whichever way. EVERY OTHER NUMBER HERE IS A PROPOSAL.
	BulwarkWall = {
		-- 2026-09-20, on request: NO COOLDOWN and NO TIME CAP. The wall stands for as long as the key is held and the bar
		-- can pay for it. ManaPerSecond MUST stay above SpellshotConfig.ManaRegenPerSecond (7) or a wall could be held for
		-- ever: at 20 the net is 13 a second, so a full bar buys ~6.9 s and she comes up with nothing left to cast with.
		ManaPerSecond = 20,
		WallAhead = 5.5,           -- studs from Terra's root to the wall's middle: the showcase's placement
		WallHP = 200,              -- what it absorbs before it breaks: four full Boulder Shots (48) and change, ~17 Icicle
		                           -- Shards; a whole Cryo Beam (~110) cannot break it alone
		-- the look (TerraFX only): the showcase's timings -- the slabs slam up from the middle out, a course at a time
		RiseTime = 0.26, RiseDepth = 9, RiseSpread = 0.028, CourseLag = 0.03, SinkTime = 0.35,
	},

	-- MOBILITY: AFTERSHOCK (2026-09-25, on request: "import it in roblox for terra replacing mobility of it"). It REPLACES
	-- Tremor Vault (the burrow-and-pop of 2026-09-19), whose tuning is deleted with it. Built in Blender first
	-- (blender_scripts/terra/aftershock_bl.py, whose table T these are; notes in vfx_blocking/terra/aftershock/) and brought
	-- in to the port's contract (vfx_blocking/terra/aftershock/PORT_SPEC.md): both fists into the ground in front of her,
	-- and a ring of erupting rock races out and throws back everyone it reaches. TerraHandler hits on the ring's curve
	-- (TerraFX.AftershockFrontR, below) and every client draws on the same curve and the same clock. Cooldown 12 is
	-- Tremor Vault's (the manual's); EVERY NUMBER HERE IS A PROPOSAL.
	-- BUDGET per cast at High (every client): ~162 ground plates (one pooled set, PoolMax 2 -- never cloned per cast once
	-- warm), ~80 erupting rocks (x EffectDensity, x0.5 for somebody else's), ~30 grit, the dark underlay, one decal, ~12
	-- emitters on 3 hosts; no physics -- every piece anchored, inert and flown by script; one BulkMoveTo a frame, plates
	-- that have come to rest skipped; ~250 one-off floor probes (a plate's or a rock's as the front reaches it, spread over
	-- the ring's 0.7 s) and none in flight; everything gone about 4.7 s after the key.
	Aftershock = {
		-- THE CAST (both sides). Seconds from the key going down ("sim" time -- see AftershockClock for the hitpause)
		Rise = 0.40,            -- both arms are overhead
		Top = 0.54,             -- ...held there, weight back, trembling, until the drive
		Hit = 0.68,             -- both fists meet the ground: the telegraph, key to impact
		HoldFrames = 4,         -- THE HITPAUSE: the contact frame held 4/60 s -- everything after Hit is 4/60 s later in real time
		FistsUp = 0.30,         -- s after Hit the fists leave the ground
		Recover = 0.95,         -- s after Hit the caster is back in the stance
		Beats = { 0.10, 0.24, 0.37, 0.49 },   -- the ground thumping under the feet in the windup
		Reach = 2.15,           -- studs ahead of the root (flat facing): where both fists land = the ring's centre
		GroundBelow = 3.5,      -- the floor must be within this under the feet, or the cast is refused at no cost
		RootUntil = 0.30,       -- the caster is held in place from the key to Hit + this (SpeedCapUlt 0)
		-- THE RING (both sides: the server's hit and every client's drawing use the same curve)
		Radius = 24,            -- studs from the centre
		RingTime = 0.70,        -- s the front takes to reach Radius
		EndSpeed = 0.45,        -- ...arriving at this fraction of its launch speed (speed falls linearly): launch 47.3, edge 21.3
		Crater = 2.4, CraterDepth = 0.42,
		Inner = 3.2,            -- rock erupts from this radius out
		-- THE HIT (server)
		Damage = 20,
		BodyRadius = 1.2,       -- a body is struck when the front comes within this of its root (flat distance)
		HitBelow = 3.0,         -- feet this far below the centre's floor ...
		HitAbove = 3.0,         -- ...to this far above it are struck: jump the front to dodge it (Earthen Tomb's "jump it")
		KnockOut = 36,          -- launch away from the centre, studs/s, x the front's strength there (never below KnockMin)
		KnockLift = 22,
		KnockMin = 0.62,
		KnockTime = 0.22,       -- s the victim's own mover drives the launch (AquaTuning's Sidearm.KnockTime pattern)
		KnockForcePerMass = 1400,
		InterruptTime = 0.5,    -- no casting for this long after the strike (InterruptedUntil), and any hold is ended
		-- THE LOOK (clients)
		Rocks = 80,             -- erupting rocks at EffectDensity 1 (x EffectDensity, x0.5 when Thin)
		SpikeShare = 0.15,
		RockSize = { 0.7, 1.6 }, SpikeSize = { 1.6, 2.6 },
		RockUp = { 12, 20 }, SpikeUp = { 15, 22 }, RockOut = { 2.5, 6.5 },   -- x strength(r)
		DebrisGravity = 35, Bounce = 0.25, Slide = 0.6, Rest = 0.8,
		PlateLift = 0.06,       -- plates rest this far above the floor: a crust laid OVER it, since a Part floor cannot be cut
		PlateTolerance = 0.8,   -- a plate whose own floor is further than this from the centre's floor is not drawn
		                        -- (above it; below it the underlay's band, AS.PlateSnap, bounds it -- 2026-09-25)
		FeetClear = 1.25,       -- plates within this of the caster's feet stay level (cracked, not heaved)
		Scar = 2.0,             -- the scar holds this long after the front stops...
		Settle = 0.8,           -- ...then the plates sink and the rubble sinks over this
		Sink = 0.6,
		HealDelay = 0.35, Heal = 0.8,   -- ...and the cracks fill (the dark underlay fades) over this, this long after
		                                -- (2026-09-25: the underlay takes the crust's colour over HealDelay as the plates
		                                -- sink, then fades over Heal; the scuff fades with it)
		Shake = 0.5, ShakeDecay = 0.22,       -- the slam, on the caster's camera (and x falloff on others' within ShakeReach)
		Rumble = 0.10, RumbleDecay = 0.45,    -- the ring's rumble
		BeatShake = 0.035, StrikeShake = 0.12, ShakeReach = 40,
		StrikeSpike = 2.8, StrikeLean = 24,   -- the shard that comes up under a struck body (degrees)
	},

	-- ULTIMATE: EARTHEN TOMB (v2, the redesign, 2026-09-19) -- replaces Seismic Slam, which never had a cast path, and the
	-- first Earthen Tomb. EVERY NUMBER HERE IS A PROPOSAL. Terra locks a target and takes hold of the floor; a fissure homes
	-- on them (jump it, or be caught); caught, the target ALONE is raised in a stone fist (the escape window) and crushed at
	-- the top. TerraHandler runs it; the times are REAL seconds at ShotTimeScale 1 (the review slow-motion scales both sides).
	EarthenTomb = {
		-- THE LOCK (the ability row's Range, 40, is the reach: the game has no shared targeted-range constant; every
		-- ability row carries its own Range, the field aimPoint and ClampTarget read)
		LockRadius = 4.5,           -- the enemy nearest the aim line and within this of it: Cross-Slash Dash's LockRadius
		RangeSlack = 2,             -- studs past Range the server still accepts: the caster's view is a moment old
		-- THE FISSURE
		GripTime = 0.12,            -- Terra's hands reach the floor before the crack leaves them: the pose lands first
		FissureSpeed = 60,          -- studs/s, re-aimed every tick. 2.4x a sprint (25), so running never outruns it; 20
		                            -- studs in 0.33 s, the full 40 in 0.67 s (v1 took 0.45 s whatever the range)
		MaxTravel = 1.6,            -- seconds: a crack that still has not caught up gives out (a dash chain, a long fall)
		CatchReach = 2.0,           -- the VISUAL: the head's footprint (1.0) and a body's half-width (1.0) touching...
		CatchMargin = 1.075,        -- ...and the hitbox 7.5% past it (2.15 studs), for a turn taken between two ticks
		GroundTolerance = 1.5,      -- feet no more than this off the floor are STANDING; any higher -- a plain jump
		                            -- clears it for ~0.48 s of its 0.54 s -- is airborne, and airborne dodges
		-- THE TOMB: slower and heavier now that only the target rides it
		RiseTime = 1.6,             -- the climb (v1 1.2): the escape window, and the weight
		RiseHeight = 12,            -- studs (v1 10)
		Converge = 0.6,             -- the boulders start closing this long before the top (v1 0.4)
		BurstDamage = 50,           -- x CritMultiplier = 75 on the burst: a guaranteed critical hit
		CritMultiplier = 1.5,
		BurstHold = 0.45,           -- the beat held at the top after the burst (v1 0.3)
		DescendTime = 0.8,          -- the pillar coming down with the target on it (v1 0.6)
		EscapeDescendTime = 0.35,   -- ...and empty, straight away, after an escape: nothing left to wait on
		-- the look (TerraFX only)
		SegmentEvery = 1.4,         -- studs between crack segments laid behind the head (each 1.5 long)
		MarkFrom = 1.4, MarkTo = 3.6,   -- the warning under the target: studs across when the head leaves, when it arrives
		-- THE HEAP (v2.1, 2026-09-20; it replaces the claw): 30 rocks, rim to chest, laid by ENCASE below
		EncaseEruptAt = 0.02,       -- the loose stones and the bottom ring break out of the stone this long after the catch,
		EncaseRingLag = 0.05,       -- each ring above this much after the one below,
		EncaseJitter = 0.03,        -- each rock up to this much more, so a ring rolls up rather than popping as one;
		EncaseEruptTime = 0.18,     -- a rock's punch up to ~7% past its place and back (the heap is up ~0.43 s in)
		EncaseBlowLife = 0.6,       -- the burst (or an escape) throws the heap off, out and up, shrinking away over this
		BlastScale = 1.3,           -- the detonation, x its ~11-stud mesh: ~14 studs, well past the body it breaks on
	},
}

local T = TerraFX.Tuning

----------------------------------------------------------------------------------------------------
-- palette and plumbing
----------------------------------------------------------------------------------------------------
-- Terra's shipped three (SpellshotConfig.Elements.Terra), read from the config so a palette change follows.
local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
local TERRA = Config.Elements.Terra
local COL = { Base = TERRA.Base, Light = TERRA.Light, Dark = TERRA.Dark, Ink = Color3.new(0, 0, 0) }

local VFXLibrary, Settings, Viewmodel = nil, nil, nil
local function libs()
	if not VFXLibrary then
		local ice = ReplicatedStorage:WaitForChild("IceMagic")
		VFXLibrary = require(ice:WaitForChild("VFXLibrary"))
		Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
		local ok, vm = pcall(require, ice:WaitForChild("Viewmodel"))
		Viewmodel = ok and vm or nil
	end
end

----------------------------------------------------------------------------------------------------
-- the Quarry Slab kit's meshes (VFX polish pass, 2026-09-18)
----------------------------------------------------------------------------------------------------
-- blender_scripts/terra/build_terra_kit.py -> export/terra_kit/TerraKit.fbx, imported (Import 3D, studs, Merge
-- Meshes off) into ReplicatedStorage.EarthMagicMeshes as MeshParts: white, SmoothPlastic, DoubleSided off. Their
-- three tone bands are baked into the vertex colours and their ink is an inverted hull, so a piece is only ever
-- cloned and placed -- never tinted, never faded. Until the kit is imported every piece falls back to the Parts
-- below, which keeps the kit running with the old look rather than breaking.
local MESH_FOLDER = "EarthMagicMeshes"
-- Pieces are placed by their PIVOT. The importer bakes each Blender object's rotation into the mesh and leaves the
-- object's frame, turned 90 degrees for Blender's Z-up, in PivotOffset -- so after EVERY Import 3D of the kit run
-- tools/terra_fix_pivots.lua once (Edit), which rewrites each pivot to the piece's own frame: LookVector = its
-- Blender -Y (a plate's outside, a star's face), UpVector = its Blender +Z. (Imported and fixed 2026-09-19.)
-- MESH_TURN is left for any further correction a re-export might need.
local MESH_TURN = CFrame.new()
-- once per MISSING MESH, not once per session (2026-09-21): a single boolean meant a kit that was present but
-- only partly imported said one line and then quietly drew Parts for everything else that was missing, which is
-- the shape of how wrong-looking assets got into this game unnoticed once already
local meshWarned = {}

--- A copy of one kit mesh, anchored and inert, or nil when the kit is not imported.
local function kitMesh(name, wrap)
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	-- a Terra wrap's recoloured copy of the piece, when it has one (TerraWrap: same mesh, size and pivot)
	local src = (wrap and wrap.Kit and wrap.Kit[name]) or (folder and folder:FindFirstChild(name, true))
	if not (src and src:IsA("BasePart")) then
		if folder and not meshWarned[name] then
			meshWarned[name] = true
			warn(("[TerraFX] '%s' not found in ReplicatedStorage.%s -- falling back to Parts"):format(name, MESH_FOLDER))
		end
		return nil
	end
	local p = src:Clone()
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	-- ...and the toon rules are asserted on the CLONE rather than trusted to the import (2026-09-21). The outline
	-- is inverted-hull geometry, so it only reads if the lit copy stays white SmoothPlastic and single-sided, and
	-- the tone bands are baked into the vertex colours -- a tint, a Neon/Glass/Ice material or any transparency
	-- multiplies them away or shows the black inside of the hull. Cryo's own getMesh has always normalised its
	-- clones this way; Terra's never did, which is how a Terra asset reached the game in the wrong material.
	p.Color = Color3.new(1, 1, 1)
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency, p.Reflectance = 0, 0
	if p:IsA("MeshPart") then p.DoubleSided = false end
	p:SetAttribute("BaseSize", src.Size)
	return p
end

--- Resizes a kit mesh to `k` times its imported size (per axis when k is a Vector3).
local function meshScale(p, k)
	local base = p:GetAttribute("BaseSize") or p.Size
	p.Size = typeof(k) == "Vector3" and base * k or base * k
end

--- A camera punch for whoever is near an impact, fading out to nothing at `reach` studs. It goes through the
--- Viewmodel's own punch, so the Camera Shake setting scales it and Reduce Flashing takes it away.
local function punchNear(position, amount, reach)
	libs()
	local cam = workspace.CurrentCamera
	if not (Viewmodel and Viewmodel.Punch and cam and typeof(position) == "Vector3") then return end
	local d = (cam.CFrame.Position - position).Magnitude
	if d >= reach then return end
	Viewmodel.Punch(amount * (1 - d / reach))
end
TerraFX.CameraPunch = punchNear

-- THE 2026-10-09 REWORKS (vfx_blocking/terra/WALL_TOMB_PORT_SPEC.md): Bulwark Wall and Earthen Tomb are drawn by
-- IceMagic.TerraFX_Wall / TerraFX_Tomb (the Blender reworks, charged rock v1.4) whenever their kit and data are in the
-- place (.Available()); the functions below keep their signatures and hand over. The choice is made once per cast (the
-- raise / the cast) so a wall or tomb is never drawn half by one look and half by the other. Without the new kit the
-- old look below plays unchanged.
local newLookCache = {}
local function newLook(name)
	local m = newLookCache[name]
	if m == nil then
		local ice = ReplicatedStorage:FindFirstChild("IceMagic")
		local s = ice and ice:FindFirstChild(name)
		if not s then return nil end
		local ok, mod = pcall(require, s)
		m = (ok and type(mod) == "table") and mod or false
		if not ok then warn("[TerraFX] " .. name .. " failed to load: " .. tostring(mod)) end
		newLookCache[name] = m
	end
	if m and type(m.Available) == "function" then
		local ok, yes = pcall(m.Available)
		if ok and yes then return m end
	end
	return nil
end
local wallLook = setmetatable({}, { __mode = "k" })   -- [caster] = the module drawing that wall, or false (the old look)
local tombLook = setmetatable({}, { __mode = "k" })   -- [caster] = the module drawing that tomb, or false
local function lookFor(map, character, name)
	local m = map[character]
	if m == nil then
		m = newLook(name) or false
		map[character] = m
	end
	return m or nil
end

local function fxFolder()
	libs()
	local name = VFXLibrary.Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local effects, bound = {}, false
local function step()
	local now = os.clock()
	for i = #effects, 1, -1 do
		local ok, keep = pcall(effects[i], now)
		if not ok or keep == false then table.remove(effects, i) end
	end
end

--- Runs fn(now) every frame until it returns false.
local function addEffect(fn)
	table.insert(effects, fn)
	if not bound then
		bound = true
		-- after CastPose poses the bodies (Character + 1) -- a rock held in a body's hand is placed off THIS frame's
		-- hand, not last frame's -- and so still after the viewmodel's arms (Camera + 2) (2026-09-23)
		RunService:BindToRenderStep("SpellshotTerraFX", Enum.RenderPriority.Character.Value + 2, step)
	end
end

----------------------------------------------------------------------------------------------------
-- the rock
----------------------------------------------------------------------------------------------------
-- ONE ROCK, SEVEN FACETS (Boulder Shot's Part fallback, used only while the TerraM1 mesh kit is not imported), authored
-- in a 1-stud cube and scaled per use. Sizes and angles are deliberately
-- uneven -- a rock that reads as faceted has no two planes the same -- and every facet is axis-tilted so the
-- silhouette is angular from every side. Tone is by facing: the skyward planes take Light, the flanks Base,
-- the underside and the deep cuts Dark, which is the same three-band read the toon meshes bake in.
local FACETS = {
	{ p = Vector3.new(0, 0, 0),           s = Vector3.new(0.86, 0.72, 0.80), r = Vector3.new(0, 18, 0),   t = "Base" },
	{ p = Vector3.new(0.10, 0.30, -0.06), s = Vector3.new(0.62, 0.34, 0.58), r = Vector3.new(-14, 40, 8), t = "Light" },
	{ p = Vector3.new(-0.26, 0.16, 0.22), s = Vector3.new(0.42, 0.44, 0.38), r = Vector3.new(22, -28, 16), t = "Light" },
	{ p = Vector3.new(0.30, -0.06, 0.26), s = Vector3.new(0.40, 0.52, 0.34), r = Vector3.new(-8, -52, -12), t = "Base" },
	{ p = Vector3.new(-0.30, -0.12, -0.24), s = Vector3.new(0.38, 0.40, 0.44), r = Vector3.new(12, 34, -20), t = "Base" },
	{ p = Vector3.new(0.04, -0.34, 0.02), s = Vector3.new(0.66, 0.30, 0.62), r = Vector3.new(10, -12, 6),  t = "Dark" },
	{ p = Vector3.new(-0.02, 0.06, -0.36), s = Vector3.new(0.46, 0.36, 0.30), r = Vector3.new(-18, 8, 24), t = "Dark" },
}

local function inert(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0
	p.Transparency = 0
	return p
end

--- Moves a rock (or a plate -- anything in the { Model, Pieces } shape) so its centre sits at `cf`. A kit mesh is
--- moved by its PIVOT, which the importer keeps at the Blender origin, so a cracked half lands where it sat in
--- the whole plate rather than at its own bounding box.
local function placeRock(rock, cf)
	for _, e in ipairs(rock.Pieces) do
		if e.pivot then
			e.part:PivotTo(cf * e.cf)
		else
			e.part.CFrame = cf * e.cf
		end
	end
end
TerraFX.PlaceRock = placeRock

local function destroyRock(rock)
	if rock and rock.Model then rock.Model:Destroy() end
end
TerraFX.DestroyRock = destroyRock

----------------------------------------------------------------------------------------------------
-- M1: BOULDER SHOT -- the maths both sides share
----------------------------------------------------------------------------------------------------
--- The charge `u` (0..1) as the rock's size, its damage and its speed. One place, so the server's damage and
--- the client's rock can never disagree about what a charge was worth.
function TerraFX.ChargeScale(u)
	local B = T.BoulderShot
	return B.RockSize * (B.MinScale + (B.MaxScale - B.MinScale) * math.clamp(u or 0, 0, 1))
end

function TerraFX.ChargeDamage(u)
	local B = T.BoulderShot
	return B.MinDamage + (B.MaxDamage - B.MinDamage) * math.clamp(u or 0, 0, 1)
end

function TerraFX.BoulderVelocity(dir, u)
	local B = T.BoulderShot
	local speed = B.MinSpeed + (B.MaxSpeed - B.MinSpeed) * math.clamp(u or 0, 0, 1)
	return dir.Unit * speed
end

--- Earthen Tomb's climb: the share of RiseHeight reached `u` of the way through the rise -- a hard shove off the
--- ground that settles into the top. The server moves the bodies and every client moves the pillars by this one curve.
function TerraFX.TombRise(u)
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) ^ 2.2
end

--- Where a boulder launched from `origin` at `v0` is `t` seconds in: a thrown arc, not a straight line.
function TerraFX.BoulderPoint(origin, v0, t)
	return origin + v0 * t + Vector3.new(0, -0.5 * T.BoulderShot.Gravity * t * t, 0)
end

----------------------------------------------------------------------------------------------------
-- MOBILITY: AFTERSHOCK -- the maths both sides share (2026-09-25)
----------------------------------------------------------------------------------------------------
-- aftershock_bl.py's front_r / front_t / strength, ported exactly: the front's speed falls LINEARLY from its launch V0 to
-- EndSpeed x V0 over RingTime, so it is out fast off the slam and still travelling when it stops at Radius. TerraHandler
-- hits on these and every client draws on them, on the same clock (AftershockRingTau), so the drawn front and the hits
-- agree. Pure functions of Tuning: safe on the server, where TerraFX is required for its numbers.

--- The front's launch speed V0 and its slow-down KD = 1 - EndSpeed.
local function aftershockFront()
	local A = T.Aftershock
	local KD = 1 - A.EndSpeed
	return A, KD, A.Radius / (A.RingTime * (1 - KD / 2))
end

--- Studs: the front's radius `tau` seconds after it LEAVES (tau clamped to [0, RingTime]).
function TerraFX.AftershockFrontR(tau)
	local A, KD, V0 = aftershockFront()
	tau = math.clamp(tau or 0, 0, A.RingTime)
	return V0 * (tau - KD * tau * tau / (2 * A.RingTime))
end

--- Seconds after it leaves that the front reaches radius `r` (r clamped to [0, Radius]).
function TerraFX.AftershockFrontT(r)
	local A, KD, V0 = aftershockFront()
	r = math.clamp(r or 0, 0, A.Radius)
	if KD < 1e-6 then return r / V0 end               -- EndSpeed 1: a front that never slows
	return A.RingTime / KD * (1 - math.sqrt(math.max(0, 1 - 2 * KD * r / (V0 * A.RingTime))))
end

--- How hard the ground is thrown at radius `r`: the front's speed there over its launch speed, softened (^0.6) --
--- 1 at the centre, ~0.62 at the edge.
function TerraFX.AftershockStrength(r)
	local A, KD = aftershockFront()
	local speed = 1 - KD * math.clamp(TerraFX.AftershockFrontT(r), 0, A.RingTime) / A.RingTime
	return math.max(0, speed) ^ 0.6
end

--- THE HITPAUSE. `t` = real seconds since the key (or since T0, x ShotTimeScale) -> the "sim" seconds the clips and the
--- windup look run on: the contact frame is HELD HoldFrames/60 s, so everything after Hit is that much later in real time.
function TerraFX.AftershockClock(t)
	local A = T.Aftershock
	local hold = A.HoldFrames / 60
	if t < A.Hit then return t end
	if t < A.Hit + hold then return A.Hit end
	return t - hold
end

--- `t` (real seconds since T0, x ShotTimeScale) -> seconds since the front LEFT (negative before it leaves). The ring
--- leaves AFTER the hitpause, on both sides.
function TerraFX.AftershockRingTau(t)
	local A = T.Aftershock
	return t - A.Hit - A.HoldFrames / 60
end

----------------------------------------------------------------------------------------------------
-- M1: BOULDER SHOT -- the look: THE REWORK (2026-09-23)
----------------------------------------------------------------------------------------------------
-- Built to Opus5-5_Terra_M1_BlenderShowcase.md in Blender first (blender_scripts/terra/m1_rework_bl.py; the film and
-- its notes are vfx_blocking/terra/m1_rework/) and brought into the game on request ("keep the new design and new
-- animation and import it"). It REPLACES the 2026-09-18 look whole. That look swapped in a different mesh at each
-- charge tier, re-sized the held rock in 4% steps, and in first person drew the held rock at half size and replaced it
-- with a full-sized one on the release frame -- the rock doubled in one frame. That is what read as the rock
-- "cross-fading between poses", and all three are designed out here.
--
-- ONE ROCK, FIRST FRAME TO LAST. The rock is the kit's TR_Boulder_L cut into eleven pieces (export/terra_kit/
-- TerraM1.fbx, imported into EarthMagicMeshes.TerraM1). The same pieces the whole way: they tear out of the floor and
-- lock together in the hand by Core (0.18 s, the tap window, so a tap still throws a whole rock); the rock GROWS with
-- the charge, never swapped, while Feeders more stones rise and are pressed into it one after another; the zigzag
-- cracks of light ignite at the kit's tiers; it flies; and it breaks back into those same pieces. Charge() returns
-- the rock and FireBoulder() takes it over -- nothing is rebuilt at the release.
--
-- THE STYLE EXCEPTION IS M1'S -- AND, BY A LATER BRIEF (2026-09-25), AFTERSHOCK'S: lit stone (no ink hull), Neon seams
-- and cracks, soft lit dust, PointLights, a bloom kick, and debris flown by script (anchored and inert, falling at
-- DebrisGravity -- the port's review replaced the real physics it first had; see "the break" below). Aftershock takes
-- the lit stone, the lit dust and the scripted debris and none of the glow: no Neon, no light, no bloom, no gold.
-- Every other Terra piece stays in the toon kit.
--
-- FIRST PERSON: the held rock is drawn at the fist, but it STANDS IN for a rock at its true size FPDepth studs out along
-- the eye -> fist line (a rock k times the size at k times the distance is the same picture). Its size on screen is
-- set by the charge, not by where the arm happens to be, and everything flying to it or off it is drawn through the
-- same projection -- so on the release it simply runs out onto the game's own line (by FPMerge), the same rock getting
-- further away on every frame. The server's line and its hit test are untouched.
--
-- WHAT IS NOT THE FILM'S: the release. The film held the button to a showcase 1.30 s; the game lets go whenever the
-- player does. So a release before the rock is whole hurries every piece still on its way in to be home by the time the
-- rock leaves the hand (Trigger after the button), and a stone that has not left the floor by then never does.

local BS = T.BoulderShot
local FULL = 4.1                              -- TR_Boulder_L across: the size the kit's pieces are modelled at
local GOLD = Color3.fromRGB(255, 214, 102)    -- the glow of the cracks: Terra's Light pushed to a lit gold (the film's)
local INNER = Color3.fromRGB(107, 79, 43)     -- a fresh break, before it glows
local WHITE = Color3.new(1, 1, 1)
local M1_KIT = "TerraM1"
-- The mesh import leaves the kit's frame as Studio's importer turned it; this carries the rock's own frame (the film's:
-- LookVector = the thrower's forward, UpVector = up) onto it. Measured on the import (2026-09-23,
-- tools/terra_m1_kit_setup.lua against TerraM1_manifest.json): a Blender (x, y, z) arrives as (-x, z, y), and the film's
-- frame is (x, z, -y) -- half a turn about up.
local KIT_TURN = CFrame.Angles(0, math.pi, 0)
-- The rework's decals, drawn by m1_rework_bl.make_marks() (export/terra_kit), uploaded 2026-09-23.
local M1_TEXTURES = {
	Scuff = "rbxassetid://102375587925629",   -- TR_M1_Scuff: the crater a boulder leaves
	Divot = "rbxassetid://70521802119621",    -- TR_M1_Divot: where a stone tore out of the floor
}
local SPIN_BACK = Vector3.new(0, 0, -1)       -- the film's second slow turn, about the thrower's forward

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end
local function span(t, a, b)
	if b <= a then return t >= b and 1 or 0 end
	return clamp01((t - a) / (b - a))
end
local function bez(a, c, b, u) return a * ((1 - u) ^ 2) + c * (2 * u * (1 - u)) + b * (u * u) end
local function randUnit(rng)
	while true do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if v.Magnitude > 0.05 and v.Magnitude <= 1 then return v.Unit end
	end
end
--- A cubic Hermite from p0 (slope m0) to p1 (slope m1) over h seconds, at s = 0..1 of the way.
local function hermite(p0, m0, p1, m1, s, h)
	local s2, s3 = s * s, s * s * s
	return p0 * (2 * s3 - 3 * s2 + 1) + m0 * h * (s3 - 2 * s2 + s) + p1 * (-2 * s3 + 3 * s2) + m1 * h * (s3 - s2)
end
--- The film's arm tremble under the weight: a few incommensurate sines, so it never settles into a visible cycle.
local function tremble(t, amp, seed)
	seed = seed or 0
	return Vector3.new(math.sin(t * 113 + seed) + 0.5 * math.sin(t * 171 + 2 * seed),
		math.sin(t * 131 + 1.7 + seed) * 0.6,
		math.sin(t * 97 + 3.1 + seed) + 0.4 * math.sin(t * 203 + seed)) * amp
end
--- Flat facing (a rotation) along `v`: the frame the rock's rest turn and the pieces' ground ring are laid out in.
local function flatFacing(v)
	local f = Vector3.new(v.X, 0, v.Z)
	f = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
	return CFrame.lookAt(Vector3.zero, f)
end

----------------------------------------------------------------------------------------------------
-- the kit
----------------------------------------------------------------------------------------------------
-- Every piece of the imported rock is read once, against the TR_M1_Origin marker (the rock's centre in Blender): its
-- frame and size relative to the rock, at full size. The import arrives ASSEMBLED, so nothing about the cut is copied
-- into code. Without the import, the seven-facet Part rock above stands in, one facet per piece (the kit's rule:
-- meshes first, Parts as the fallback).
local boulderKitCache = nil
local function boulderKit()
	if boulderKitCache then return boulderKitCache end
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local model = folder and folder:FindFirstChild(M1_KIT)
	local origin = model and model:FindFirstChild("TR_M1_Origin", true)
	local kit = { Cells = {}, Pebbles = {}, Mesh = false }
	if origin then
		local o = origin.CFrame
		for i = 1, 64 do
			local cellPart = model:FindFirstChild(("TR_M1_Cell_%02d"):format(i), true)
			if not cellPart then break end
			local cell = { Centre = o:PointToObjectSpace(cellPart.Position), Parts = {} }
			for _, kind in ipairs({ "Cell", "Seam", "CrackA", "CrackB" }) do
				local p = model:FindFirstChild(("TR_M1_%s_%02d"):format(kind, i), true)
				if p and p:IsA("BasePart") then
					cell.Parts[#cell.Parts + 1] = { Kind = kind, Source = p, Rel = o:ToObjectSpace(p.CFrame), Size = p.Size }
				end
			end
			kit.Cells[i] = cell
		end
		for i = 1, 64 do
			local p = model:FindFirstChild(("TR_M1_Pebble_%02d"):format(i), true)
			if not (p and p:IsA("BasePart")) then break end
			kit.Pebbles[i] = { Source = p, Size = p.Size / math.max(p.Size.X, p.Size.Y, p.Size.Z) }
		end
		kit.Mesh = #kit.Cells > 0 and #kit.Pebbles > 0
	end
	if not kit.Mesh then
		if folder and not meshWarned[M1_KIT] then
			meshWarned[M1_KIT] = true
			warn(("[TerraFX] '%s' not found in ReplicatedStorage.%s -- Boulder Shot falls back to Parts"):format(M1_KIT, MESH_FOLDER))
		end
		kit.Cells, kit.Pebbles = {}, {}
		for i, f in ipairs(FACETS) do
			local rel = CFrame.new(f.p * FULL) * CFrame.Angles(math.rad(f.r.X), math.rad(f.r.Y), math.rad(f.r.Z))
			kit.Cells[i] = { Centre = f.p * FULL, Parts = { { Kind = "Cell", Rel = rel, Size = f.s * FULL, Tone = f.t } } }
		end
		kit.Pebbles[1] = { Size = Vector3.new(1, 0.72, 0.8), Tone = "Base" }
	end
	-- the rock's half-extents at full size, off every piece's box: the shape the feeding stones land on
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, cell in ipairs(kit.Cells) do
		for _, e in ipairs(cell.Parts) do
			local h = e.Size / 2
			lo, hi = lo:Min(e.Rel.Position - h), hi:Max(e.Rel.Position + h)
		end
	end
	kit.Half = (hi - lo) / 2
	boulderKitCache = kit
	return kit
end

--- A fresh copy of one kit piece, anchored and inert until the break. The stone keeps its baked vertex colours
--- (white, SmoothPlastic); the seams and the cracks of light are driven by glow() below.
-- WRAPS (SkinCatalog, 2026-10-10): a wrap Id -> TerraWrap's built set for this kit (nil while it builds, for Default,
-- or with the mesh APIs off: the rock then draws exactly as before). A set table passes straight through.
local TerraWrap = nil
local plateStage, wrapOf          -- (defined with the plates, below; Bulwark Charge uses them first)
local function wrapFor(id, kit, own)
	if type(id) == "table" then return id end
	if type(id) ~= "string" or id == "Default" or not kit.Mesh then return nil end
	TerraWrap = TerraWrap or require(script.Parent:WaitForChild("TerraWrap"))
	return TerraWrap.Get(id, kit, nil, own)
end
local function wrapFx(rock, kind)
	return rock.Wrap and TerraWrap and TerraWrap.Particles(rock.Wrap, kind) or nil
end

local function m1Piece(entry)
	local p
	if entry.Source then
		p = entry.Source:Clone()
	else
		p = Instance.new("Part")
		p.Size = entry.Size
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, true, false
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency, p.Reflectance = 0, 0
	if p:IsA("MeshPart") then p.DoubleSided = false end
	local kind = entry.Kind
	p.Color = (kind == "Seam" and INNER) or ((kind == "CrackA" or kind == "CrackB") and COL.Light)
		or (entry.Tone and COL[entry.Tone]) or WHITE
	if kind ~= "Cell" and kind ~= nil then p.CastShadow = false end
	return p
end

----------------------------------------------------------------------------------------------------
-- one rock
----------------------------------------------------------------------------------------------------
--- The rock's size (a share of FULL) `t` seconds after the press: ChargeScale of the charge, a swell as each stone
--- lands, and one hard squeeze at full.
local function sizeAt(rock, t)
	local s = TerraFX.ChargeScale(rock.U) / FULL
	for _, tm in ipairs(rock.Merges) do
		if t >= tm and t < tm + 0.09 then s *= 1 + 0.035 * (1 - (t - tm) / 0.09) end
	end
	local full = rock.FullAt
	if full and t >= full and t < full + 0.10 then s *= 1 - 0.05 * math.sin(math.pi * (t - full) / 0.10) end
	return s
end

--- How far apart the pieces sit (1 = touching): loose as they land, squeezed together by the charge.
local function spreadAt(rock, t)
	local g = 1.10 + (1.016 - 1.10) * smooth(span(t, BS.Core - 0.04, BS.ChargeTime))
	local full = rock.FullAt
	if full and t >= full and t < full + 0.10 then g -= 0.012 * math.sin(math.pi * (t - full) / 0.10) end
	return g
end

--- The seams' and the two tiers' glow: the seams brighten as the rock compresses and flare as each stone lands; the
--- cracks light at the kit's tiers (a third and two thirds of the charge) with a flare; the break spikes all of it and
--- it goes out -- stone again.
local function glowAt(rock, t)
	local u = rock.U
	local seam = t >= 0.10 and (0.5 + 1.7 * smooth(u)) or 0
	for _, tm in ipairs(rock.Merges) do
		if t >= tm and t < tm + 0.08 then seam += 1.2 * (1 - (t - tm) / 0.08) end
	end
	local full = rock.FullAt
	if full and t >= full and t < full + 0.16 then seam += 3.0 * (1 - (t - full) / 0.16) end
	local c = {}
	for n, tier in ipairs({ 1 / 3, 2 / 3 }) do
		local lit = rock.TierAt[n]
		if u >= tier and not lit then
			lit = t
			rock.TierAt[n] = t
		end
		c[n] = lit and (1.3 + 1.1 * smooth(u) + 3.0 * math.max(0, 1 - (t - lit) / 0.14)) or 0
	end
	return seam, c[1], c[2]
end

--- The colour a lit part shows at glow `v`: its own stone colour up to the gold, then past it toward white.
local function glowColour(v, base)
	if v <= 2.2 then return base:Lerp(GOLD, clamp01(v / 2.2)) end
	return GOLD:Lerp(WHITE, math.clamp((v - 2.2) / 4, 0, 0.55))
end

local function setGlow(e, v, base)
	local key = v > 0.05 and math.floor(v * 16 + 0.5) or -1
	if e.Glow == key then return end
	e.Glow = key
	if key < 0 then
		e.Part.Material = Enum.Material.SmoothPlastic
		e.Part.Color = base
	else
		e.Part.Material = Enum.Material.Neon
		e.Part.Color = glowColour(v, base)
	end
end

--- A wrapped rock's glow: a static brightness per stage -- the kit's own tiers (Low, Mid from the first, Max from the
--- second) -- never a flare, a flicker or a pulse; the fissures and seams of a loose piece stay dark until it is locked
--- in, and the break puts them out a fifth of a second later, as the stone goes cold.
local function wrapGlow(rock, t)
	local set = rock.Wrap
	local stage = (rock.TierAt[2] and "Max") or (rock.TierAt[1] and "Mid") or "Low"
	if rock.Broken and os.clock() - rock.BrokeAt > 0.2 then stage = nil end
	local prof = stage and set.Skin.Stages[stage]
	for _, cell in ipairs(rock.Cells) do
		local docked = rock.Broken or (cell.DockedAt ~= nil and t >= cell.DockedAt)
		local want = (prof and docked) and stage or "Off"
		for _, e in ipairs(cell.Parts) do
			if e.Glow ~= want and (e.Kind == "Seam" or e.Kind == "Fissure") then
				e.Glow = want
				if e.Kind == "Seam" then
					e.Part.Material = want == "Off" and Enum.Material.SmoothPlastic or Enum.Material.Neon
					e.Part.Color = want == "Off" and set.Skin.SeamOff or prof.Seam
				elseif want == "Off" then
					e.Part.Transparency = 1
				else
					local size = e.Part.Size
					pcall(function() e.Part:ApplyMesh(e.Stages[want]) end)
					e.Part.Size = size
					e.Part.Transparency = 0
				end
			end
		end
	end
	if rock.Light then
		local near = (rock.Eye and (rock.K or 1) < 0.999) and (0.2 + 0.8 * smooth(((rock.K or 1) - 0.3) / 0.7)) or 1
		rock.Light.Brightness = prof and prof.Light * (0.25 + 1.25 * set.Glow) * (rock.Thin and 0.8 or 1) * near or 0
	end
end

--- Every seam and crack on the rock at these glows. `docked`: a loose piece's seams stay dark until it is locked in.
local function applyGlow(rock, seam, c2, c3, t)
	if rock.Wrap then return wrapGlow(rock, t) end
	for _, cell in ipairs(rock.Cells) do
		local dock = cell.DockedAt and clamp01((t - cell.DockedAt) / 0.08) or 0
		if rock.Broken then dock = 1 end
		for _, e in ipairs(cell.Parts) do
			if e.Kind == "Seam" then
				setGlow(e, seam * dock, INNER)
			elseif e.Kind == "CrackA" then
				setGlow(e, c2, COL.Light)
			elseif e.Kind == "CrackB" then
				setGlow(e, c3, COL.Light)
			end
		end
	end
	if rock.Light then
		-- FIRST PERSON (the Play test, 2026-09-23): the held rock is drawn a stud from the lens, and at the film's
		-- brightness its light blew the viewmodel's arms -- which carry their own calibrated light -- past the place's
		-- Bloom threshold into a white dome. Near the lens it is a fifth of that, rising to full as the rock gets out
		-- to its own size (k -> 1).
		local near = (rock.Eye and (rock.K or 1) < 0.999) and (0.2 + 0.8 * smooth(((rock.K or 1) - 0.3) / 0.7)) or 1
		rock.Light.Brightness = rock.Broken and 0 or (1.2 + 0.5 * (c2 + c3) + 0.25 * seam) * (rock.Thin and 0.8 or 1) * near
	end
end

-- the bulk move: every anchored piece of every rock goes through one BulkMoveTo a frame
local moveParts, moveCFs = {}, {}
local function queueMove(part, cf)
	moveParts[#moveParts + 1] = part
	moveCFs[#moveCFs + 1] = cf
end
local function flushMoves()
	if #moveParts == 0 then return end
	workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(moveParts)
	table.clear(moveCFs)
end

--- Draws `pos` at k times its distance from `eye` (first person); k = 1 or no eye is the point itself.
local function project(eye, pos, k)
	if not eye or k >= 0.9999 then return pos end
	return eye + (pos - eye) * k
end

--- One piece of a cell at `frame` (the cell's centre and turn), the rock at size share `s`, drawn at k from `eye`.
local function placePiece(e, cellCentre, frame, s, k, eye)
	local shadow = e.Kind == "Cell" and not (eye and k < 0.9999)
	if e.Shadow ~= shadow then
		e.Shadow = shadow
		e.Part.CastShadow = shadow
	end
	local cf = frame * CFrame.new((e.Rel.Position - cellCentre) * s) * e.Rel.Rotation
	local scale = s * (eye and k or 1)
	if eye and k < 0.9999 then cf = cf.Rotation + project(eye, cf.Position, k) end
	if not e.Scale or math.abs(e.Scale - scale) > 0.01 * scale then
		e.Scale = scale
		e.Part.Size = e.Size * scale
	end
	queueMove(e.Part, cf)
end

local function placeCell(cell, frame, s, k, eye)
	for _, e in ipairs(cell.Parts) do placePiece(e, cell.Centre, frame, s, k, eye) end
end

--- Where the (virtual) rock sits for this frame, from the hand the caller follows. First person: `cf` is the fist
--- (Viewmodel.GetFistCFrame: forearm tip, LookVector along the forearm) and `eye` the lens -- the rock is the film's
--- virtual anchor, FPDepth out along the eye -> fist line, drawn back onto the fist at k. Third person: `cf` is the
--- body's hand, and the rock sits off the fingertips, clear of the hand by its own half-size.
local function anchorOf(rock, s)
	local cf, eye, facing = rock.Hand()
	if not cf then return nil end
	facing = facing or flatFacing(cf.LookVector)
	if rock.Exact then return cf.Position, 1, nil, facing end
	if eye then
		local tip = cf.Position
		local r = (tip - eye).Magnitude / BS.FPDepth * 1.6 * s
		local c = tip + cf.LookVector * (0.55 * r) + cf.UpVector * (0.10 * r)
		local k = math.max(0.02, (c - eye).Magnitude / BS.FPDepth)
		return eye + (c - eye) / k, k, eye, facing
	end
	local r = 0.5 * FULL * s * 0.8
	return (cf * CFrame.new(0, -(0.3 + r), 0)).Position, 1, nil, facing
end

--- How far a piece has come on its way in (0..1), `t` seconds after the press. After the button comes up, whatever is
--- still on its way is hurried home by the time the rock leaves the hand.
local function progress(rock, ts, ta, t)
	local tu = rock.Tu
	if tu and t > tu then
		local from = ts >= tu and 0 or clamp01((tu - ts) / (ta - ts))
		if from >= 1 then return 1 end
		return from + (1 - from) * clamp01((t - tu) / (BS.Trigger * 0.9))
	end
	return clamp01((t - ts) / (ta - ts))
end

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude

--- The floor under `p`, or nil. `body`: a character to see through as well (the one the rock just broke on). It is
--- searched from a little above `p` -- or, in first person, from the eye's height when the virtual anchor sits below
--- the floor -- and never from high up, so a roof, a canopy or a ceiling over the thrower is never taken for the floor.
local function floorUnder(rock, p, body)
	local list = { fxFolder() }
	if rock.Character then list[#list + 1] = rock.Character end
	if body then list[#list + 1] = body end
	floorParams.FilterDescendantsInstances = list
	local top = p.Y + 1.5
	if rock.Eye then top = math.max(top, math.min(rock.Eye.Y, p.Y + 8)) end
	return workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, -(top - p.Y) - 16, 0), floorParams)
end

-- A burst host: one invisible part per rock, moved to wherever the next burst goes. The Disc kinds emit from the
-- part (a disc in its XZ plane, `radius` across it); the rest from a point at its centre, an Attachment -- an emitter
-- on a bare Part would scatter from the whole of its box.
local DISC_KINDS = { Ring = true, Settle = true }
local function burstHost(rock)
	if rock.BurstHost and rock.BurstHost.Parent then return rock.BurstHost end
	local h = inert(Instance.new("Part"))
	h.Name = "BoulderBurst"
	h.Transparency = 1
	h.Size = Vector3.new(1, 0.2, 1)
	h.CastShadow = false
	h.Parent = fxFolder()
	rock.BurstHost = h
	rock.BurstPoint = Instance.new("Attachment")
	rock.BurstPoint.Parent = h
	rock.Emitters = {}
	return h
end

--- `count` particles of `kind` at `cf` (a Disc burst lies in cf's XZ plane, `radius` across it), sized by `scale`.
--- A particle's Size and Speed are read off its emitter for its whole life, so every size gets an emitter of its own
--- (in steps of a tenth) rather than one emitter re-sized under the puffs it already let go.
local function burst(rock, kind, cf, count, scale, radius)
	local h = burstHost(rock)
	h.CFrame = cf
	if radius then h.Size = Vector3.new(radius * 2, 0.2, radius * 2) end
	scale = math.max(0.1, math.floor((scale or 1) * 10 + 0.5) / 10)
	local key = kind .. "@" .. scale
	local pe = rock.Emitters[key]
	if not pe then
		pe = VFXLibrary.BoulderBurst(DISC_KINDS[kind] and h or rock.BurstPoint, kind, 0, rock.Thin, wrapFx(rock, kind))
		pe.Rate = 0
		if scale ~= 1 then
			local keys = {}
			for i, kp in ipairs(pe.Size.Keypoints) do
				keys[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale)
			end
			pe.Size = NumberSequence.new(keys)
			pe.Speed = NumberRange.new(pe.Speed.Min * scale, pe.Speed.Max * scale)
		end
		rock.Emitters[key] = pe
	end
	local density = (Settings.EffectDensity or 1) * ((rock.Thin and Settings.ThinEnemyVFX) and 0.5 or 1)
	local n = math.floor(count * density + 0.5)
	if n > 0 then pe:Emit(n) end
end

-- the rework's decals: a flat invisible host on the surface, the decal on its top face. Faded by the rock's own step.
local function decalAt(rock, position, normal, size, texture, spin)
	local up = (typeof(normal) == "Vector3" and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
	local side = math.abs(up.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local right = up:Cross(side).Unit
	local host = inert(Instance.new("Part"))
	host.Name = "BoulderMark"
	host.Transparency = 1
	host.Size = Vector3.new(size, 0.05, size)
	host.CFrame = CFrame.fromMatrix(position + up * 0.03, right, up) * CFrame.Angles(0, spin or 0, 0)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = texture
	d.Transparency = 1
	d.Parent = host
	host.Parent = fxFolder()
	return { Host = host, Decal = d }
end

--- A piece leaving the floor: where it comes up (on the ring round the rock, on the real floor), the kick of dust and
--- grit, and the divot it leaves.
local function startPiece(rock, piece, A, facing, isCell)
	local rngv = rock.Rng
	local out = facing.RightVector * math.cos(piece.Ang) + facing.LookVector * math.sin(piece.Ang)
	local ground = A + out * piece.Rad
	local hit = floorUnder(rock, ground)
	piece.G = hit and hit.Position or Vector3.new(ground.X, A.Y - 3, ground.Z)
	piece.N = hit and hit.Normal or Vector3.yAxis
	if not hit then return end
	local up = CFrame.lookAt(piece.G, piece.G + piece.N) * CFrame.Angles(-math.pi / 2, 0, 0)
	burst(rock, "Kick", up + piece.N * 0.15, isCell and 3 or 1)
	burst(rock, "KickGrit", up + piece.N * 0.05, isCell and 4 or 2)
	if isCell or not rock.Thin then
		local m = decalAt(rock, piece.G, piece.N, 1.5, M1_TEXTURES.Divot, rngv:NextNumber(0, 6.28))
		m.Born = os.clock()
		m.Life = 1.0
		m.Alpha = function(a) return 0.85 * (1 - span(a, 0.55, 1.0)) * span(a, 0, 0.05) end
		table.insert(rock.Marks, m)
	end
end

local function sideOf(v)
	local s = v:Cross(Vector3.yAxis)
	return s.Magnitude > 1e-3 and s.Unit or Vector3.xAxis
end

--- A new rock: the plan for every piece, nothing drawn yet. opts: Hand (as anchorOf reads it), Thin, Own, Character,
--- Assembled (a whole rock straight away -- nothing was gathered on this client), U (its charge, when Assembled).
local function newBoulder(opts)
	local kit = boulderKit()
	local wrap = wrapFor(opts.Wrap, kit, opts.Own)
	local rng = Random.new()
	local model = Instance.new("Model")
	model.Name = "TerraBoulder"
	model.Parent = fxFolder()
	local rock = {
		Kit = kit, Model = model, Rng = rng, Hand = opts.Hand, Thin = opts.Thin == true, Own = opts.Own == true,
		Character = opts.Character, T0 = os.clock(), U = opts.U or 0, Cells = {}, Feeders = {}, Merges = {},
		Arrivals = {}, TierAt = {}, Marks = {}, Debris = {}, Grit = {}, Assembled = opts.Assembled == true,
		Wrap = wrap, Pebbles = wrap and #wrap.Pebbles > 0 and wrap.Pebbles or kit.Pebbles,
	}
	if wrap then
		-- the pale rim round the whole rock's silhouette (owner, checkpoint 2): a dark rock stays visible -- and
		-- dodgeable -- on dark ground and in shadow. One Highlight per rock, gone at the break.
		local rim = Instance.new("Highlight")
		rim.FillTransparency = 1
		rim.OutlineColor = wrap.Skin.Rim
		rim.OutlineTransparency = 0
		rim.DepthMode = Enum.HighlightDepthMode.Occluded
		rim.Adornee = model
		rim.Parent = model
		rock.Rim = rim
	end
	-- the cells: nearest the centre first, all home by Core
	local order = {}
	for i in ipairs(kit.Cells) do order[i] = i end
	table.sort(order, function(a, b) return kit.Cells[a].Centre.Magnitude < kit.Cells[b].Centre.Magnitude end)
	for n, i in ipairs(order) do
		local src = kit.Cells[i]
		local parts = {}
		local wc = wrap and wrap.Cells[i]
		for _, e in ipairs(src.Parts) do
			if wc and e.Kind == "Cell" then
				parts[#parts + 1] = { Part = m1Piece(wc.Stone), Rel = wc.Stone.Rel, Size = wc.Stone.Size, Kind = "Cell" }
			elseif not (wc and (e.Kind == "CrackA" or e.Kind == "CrackB")) then
				-- (a wrap's fissures stand in for the kit's cracks of light)
				parts[#parts + 1] = { Part = m1Piece(e), Rel = e.Rel, Size = e.Size, Kind = e.Kind }
			end
		end
		if wc and wc.Fissure then
			local p = m1Piece({ Source = wc.Fissure.Low, Kind = "Fissure" })
			p.Material = Enum.Material.Neon
			p.Transparency = 1
			parts[#parts + 1] = { Part = p, Rel = wc.Fissure.Rel, Size = wc.Fissure.Size, Kind = "Fissure",
				Stages = wc.Fissure, Glow = "Off" }
		end
		rock.Cells[i] = {
			Centre = src.Centre, Parts = parts,
			Ts = rng:NextNumber(0, 0.04), Ta = 0.10 + (BS.Core - 0.10) * (n - 1) / math.max(1, #order - 1),
			Q0 = CFrame.fromAxisAngle(randUnit(rng), rng:NextNumber(1, 3)),
			Ang = rng:NextNumber(-1.2, 2.4), Rad = rng:NextNumber(2.2, 4.0), Lift = rng:NextNumber(1.0, 2.2),
		}
		if rock.Assembled then
			rock.Cells[i].DockedAt = -1
			for _, e in ipairs(parts) do e.Part.Parent = model end
		end
	end
	-- the feeding stones, while the button is held
	if not rock.Assembled then
		for j = 0, BS.Feeders - 1 do
			local ts = BS.FeedFrom + (BS.FeedTo - BS.FeedFrom) * (j + rng:NextNumber(-0.3, 0.3)) / BS.Feeders
			rock.Feeders[#rock.Feeders + 1] = {
				Ts = ts, Ta = ts + rng:NextNumber(0.20, 0.32), Size = rng:NextNumber(0.30, 0.62),
				Pebble = rock.Pebbles[rng:NextInteger(1, #rock.Pebbles)],
				Ang = rng:NextNumber(-1.6, 2.8), Rad = rng:NextNumber(3.0, 6.2), Lift = rng:NextNumber(1.2, 2.8),
				Dir = randUnit(rng), Q0 = CFrame.fromAxisAngle(randUnit(rng), rng:NextNumber(0, 6)),
				Spin = randUnit(rng), SpinRate = rng:NextNumber(4, 9),
			}
		end
	end
	-- the rock's own light, riding its centre: its cracks light the hand that holds it
	local host = inert(Instance.new("Part"))
	host.Name = "BoulderCore"
	host.Transparency = 1
	host.Shape = Enum.PartType.Ball
	host.Size = Vector3.one * 2
	host.CastShadow = false
	host.Parent = model
	rock.Host = host
	if not VFXLibrary.FlatLit() then
		local light = Instance.new("PointLight")
		light.Color = wrap and wrap.Skin.Light or GOLD
		light.Range = 8
		light.Brightness = 0
		light.Shadows = false
		light.Parent = host
		rock.Light = light
	end
	return rock
end

--- The film's strain: how hard the arm is working to hold it -- building with the charge, peaking on the full hold.
local function strainAt(rock, t)
	if rock.Tu then return 0 end
	return 0.35 * span(t, BS.Core, BS.ChargeTime) + 0.65 * span(t, BS.ChargeTime - 0.05, BS.ChargeTime + 0.05)
end

--- The arm taking the weight: a small sag as each piece lands, settling.
local function dipsAt(rock, t)
	local d = 0
	for _, list in ipairs({ rock.Arrivals, rock.Merges }) do
		for _, tm in ipairs(list) do
			if t >= tm and t < tm + 0.12 then d += 0.05 * math.sin(math.pi * (t - tm) / 0.12) end
		end
	end
	return d
end

--- The caster's own arm under the rock (first person): the film's tremble and dips, through Viewmodel's arm offset.
local function armLoad(rock)
	local t = os.clock() - rock.T0
	local j = tremble(t, 0.010 * strainAt(rock, t), 2.0)
	return { X = j.X, Y = j.Y - dipsAt(rock, t) * 0.25 }
end

local function releaseArm(rock)
	if rock.Own and rock.ArmHeld and Viewmodel and Viewmodel.SetArmOffset then
		rock.ArmHeld = false
		Viewmodel.SetArmOffset("R", nil)
	end
end

--- The gathering emitters: dust and grit pulled in off the floor under the rock, and their ramp with the charge.
local function gatherStep(rock, A, t)
	if rock.Assembled then return end
	if not rock.Gather then
		local h = inert(Instance.new("Part"))
		h.Name = "BoulderGather"
		h.Transparency = 1
		h.CastShadow = false
		h.Size = Vector3.new(8, 0.2, 8)
		h.Parent = rock.Model
		rock.Gather = h
		rock.GatherDust = VFXLibrary.BoulderEmitter(h, "Gather", rock.Thin)
		rock.GatherGrit = VFXLibrary.BoulderEmitter(h, "GatherGrit", rock.Thin, wrapFx(rock, "GatherGrit"))
	end
	local on = t >= 0.02 and not rock.Tu
	local rate = on and (14 + 20 * span(t, 0, BS.ChargeTime)) or 0
	VFXLibrary.BoulderRate(rock.GatherDust, rate, rock.Thin)
	VFXLibrary.BoulderRate(rock.GatherGrit, rate * 1.6, rock.Thin)
	if on then
		local f = floorUnder(rock, A)
		local at = f and f.Position or (A - Vector3.new(0, 2, 0))
		queueMove(rock.Gather, CFrame.new(at + Vector3.new(0, 0.3, 0)))
	end
end

--- Every piece of the rock for this frame, wherever the rock is: in the hand (updateHeld) or out on its line
--- (flyBoulder). A piece still on its way in -- a cell, or a feeding stone -- keeps flying into the rock where it is NOW,
--- so a release while pieces are arriving does not snap them home or drop them in mid-air; they land on the rock as it
--- leaves. `A` is the rock's centre (the virtual one in first person), drawn at k from `eye`.
local function placePieces(rock, t, A, rot, s, g, k, eye, facing)
	local rockCF = CFrame.new(A) * rot
	for _, cell in ipairs(rock.Cells) do
		local started = rock.Assembled or t >= cell.Ts or (rock.Tu ~= nil and t > rock.Tu)
		if started and not cell.Shown then
			-- parented on its first started frame, whether it is on its way in or already home (a release in the same
			-- frame as the press can bring a piece in finished)
			cell.Shown = true
			for _, e in ipairs(cell.Parts) do e.Part.Parent = rock.Model end
		end
		if started then
			local dock = rockCF * CFrame.new(cell.Centre * (s * g))
			local u = rock.Assembled and 1 or progress(rock, cell.Ts, cell.Ta, t)
			if u >= 1 then
				if not cell.DockedAt then
					cell.DockedAt = t
					table.insert(rock.Arrivals, t)
				end
				placeCell(cell, dock, s, k, eye)
			else
				if not cell.G then startPiece(rock, cell, A, facing, true) end
				-- up out of the floor under where the rock will be, and in on a swinging curve
				local ue = u ^ 1.6
				local D = dock.Position
				local Gs = cell.G - cell.N * 0.35
				local Cc = (Gs + D) / 2 + Vector3.yAxis * cell.Lift + sideOf(D - Gs) * 0.9
				local frame = CFrame.new(bez(Gs, Cc, D, ue)) * cell.Q0:Lerp(dock.Rotation, smooth(ue))
				placeCell(cell, frame, s, 1 + (k - 1) * smooth(ue), eye)
			end
		end
	end
	-- the feeding stones: rise, swing in, pressed into the surface and gone
	for _, f in ipairs(rock.Feeders) do
		if not f.Done then
			local started = t >= f.Ts and not (rock.Tu and f.Ts > rock.Tu)
			if rock.Tu and f.Ts > rock.Tu then f.Done = true end
			if started then
				if not f.Part then
					f.Part = m1Piece(f.Pebble)
					f.Part.CastShadow = false
					f.Part.Parent = rock.Model
					startPiece(rock, f, A, facing, false)
				end
				local d = rot:VectorToWorldSpace(f.Dir)
				local H = rock.Kit.Half
				local sup = math.sqrt((H.X * f.Dir.X) ^ 2 + (H.Y * f.Dir.Y) ^ 2 + (H.Z * f.Dir.Z) ^ 2)
				local surf = A + d * (sup * s * g)
				local u = progress(rock, f.Ts, f.Ta, t)
				local cf, scale, kk
				if u < 1 then
					local ue = u ^ 1.7
					local Gs = f.G - f.N * 0.2
					local Cc = (Gs + surf) / 2 + Vector3.yAxis * f.Lift + sideOf(surf - Gs) * 1.4
					cf = CFrame.new(bez(Gs, Cc, surf, ue))
						* CFrame.fromAxisAngle(f.Spin, f.SpinRate * (t - f.Ts) * (1 - 0.6 * ue)) * f.Q0
					scale, kk = f.Size, 1 + (k - 1) * smooth(ue)
				else
					if not f.MergeAt then
						f.MergeAt = t
						table.insert(rock.Merges, t)
						local at = project(eye, surf, k)
						burst(rock, "Merge", CFrame.lookAt(at, at + d) * CFrame.Angles(-math.pi / 2, 0, 0), 3, k)
					end
					local m = (t - f.MergeAt) / 0.07
					if m >= 1 then
						f.Part:Destroy()
						f.Part, f.Done = nil, true
					else
						cf = CFrame.new(surf - d * (f.Size * 0.6 * m))
							* CFrame.fromAxisAngle(f.Spin, f.SpinRate * (f.Ta - f.Ts) * 0.4) * f.Q0
						scale, kk = f.Size * math.max(0.05, 1 - m), k
					end
				end
				if cf and f.Part then
					local drawn = scale * (eye and kk or 1)
					if eye and kk < 0.9999 then cf = cf.Rotation + project(eye, cf.Position, kk) end
					f.Part.Size = f.Pebble.Size * drawn
					queueMove(f.Part, cf)
				end
			end
		end
	end
end

--- One frame of the rock in the hand: the pieces coming in and the ones home, the stones feeding it, its turn, its
--- glow and light, the dust. False when there is no hand any more.
local function updateHeld(rock, now)
	local t = now - rock.T0
	if not rock.FullAt and rock.U >= 1 and not rock.Tu then rock.FullAt = t end
	local s = sizeAt(rock, t)
	local g = spreadAt(rock, t)
	local A, k, eye, facing = anchorOf(rock, s)
	if not A then return false end
	-- the slow turn it gathers with, from a start with the gold cap turned away from the thrower
	local rot = facing * CFrame.Angles(0, math.pi + 0.9 * t, 0) * CFrame.fromAxisAngle(SPIN_BACK, 0.35 * t) * KIT_TURN
	rock.A, rock.K, rock.Eye, rock.Facing, rock.Rot, rock.S, rock.Gs = A, k, eye, facing, rot, s, g
	placePieces(rock, t, A, rot, s, g, k, eye, facing)
	-- FULL: the squeeze pushes a ring of dust off it
	if rock.FullAt and not rock.RingDone then
		rock.RingDone = true
		local at = project(eye, A, k)
		burst(rock, "Ring", CFrame.new(at) * facing.Rotation, 12, s * k, 1.6 * s * k)
	end
	gatherStep(rock, A, t)
	local seam, c2, c3 = glowAt(rock, t)
	applyGlow(rock, seam, c2, c3, t)
	if rock.Light then rock.Light.Range = eye and (8 * k + 1.5) or 8 end
	queueMove(rock.Host, CFrame.new(project(eye, A, k)))
	return true
end

----------------------------------------------------------------------------------------------------
-- the break, and what is left of it
----------------------------------------------------------------------------------------------------
-- THE DEBRIS IS FLOWN HERE, not handed to the engine (the port's review, 2026-09-23). The film threw its pieces as
-- rigid bodies, and the first port did too -- unanchored, colliding parts on each client. Two things rule that out in
-- this game: the one body a client simulates is its own player's, so a rock breaking ON a player shoved them out of
-- their own debris; and a colliding part cannot be CanQuery = false, so the rubble became floor and wall to every
-- movement probe and ground test in the game. So each piece -- a cell with its seam and cracks, or a pebble -- is an
-- anchored, inert part flown by this step: falling at DebrisGravity, raycast against the world (never a player's
-- body), bouncing off it with the film's restitution (0.25) and friction, tumbling, and coming to rest. What is lost
-- is pieces stacking on one another; at 35 studs/s^2 they are down and still inside a second either way.
local DEBRIS_BOUNCE, DEBRIS_SLIDE, DEBRIS_REST = 0.25, 0.6, 0.8
local debrisParams = RaycastParams.new()
debrisParams.FilterType = Enum.RaycastFilterType.Exclude
local debrisFilterAt = 0

--- How far a piece's box hangs out from its centre along `n` -- a little under the box, since the stone sits inside it.
local function reachAlong(d, n)
	local R, h = d.F, d.Half
	return 0.85 * (math.abs(R.RightVector:Dot(n)) * h.X + math.abs(R.UpVector:Dot(n)) * h.Y + math.abs(R.LookVector:Dot(n)) * h.Z)
end

--- A piece joins the flown debris: `parts` are { Part, Off } at offsets from its frame `f`; `half` its box.
local function addDebris(rock, parts, f, vel, spin, half, big)
	table.insert(rock.Debris, { Parts = parts, F = f, V = vel, W = spin, Half = half, Big = big, Born = os.clock(),
		Size = math.max(half.X, half.Y, half.Z) })
end

--- One step of every piece of a rock's debris: fall, meet the world, bounce, tumble, rest; a puff where a big one first
--- lands. `a` is seconds since the break (nil before it): from Settle on they are held and sunk into the floor.
local function stepDebris(rock, now, a)
	local dt = math.min(now - (rock.DebrisStep or now), 1 / 20)
	rock.DebrisStep = now
	if now >= debrisFilterAt then
		debrisFilterAt = now + 0.5
		local list = { fxFolder() }
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character then list[#list + 1] = pl.Character end
		end
		debrisParams.FilterDescendantsInstances = list
	end
	local sinkU = a and span(a, BS.Settle, BS.Settle + BS.Sink) or 0
	for _, d in ipairs(rock.Debris) do
		local root = d.Parts[1].Part
		if root.Parent then
			if sinkU > 0 then
				d.Sink = d.Sink or d.F
				if sinkU >= 1 then
					for _, e in ipairs(d.Parts) do e.Part:Destroy() end
				else
					local f = d.Sink - Vector3.new(0, d.Size * 2.2 * sinkU * sinkU, 0)
					for _, e in ipairs(d.Parts) do queueMove(e.Part, f * e.Off) end
				end
			elseif not d.Rest and dt > 0 then
				d.V -= Vector3.new(0, BS.DebrisGravity * dt, 0)
				local from = d.F.Position
				local step = d.V * dt
				local to = from + step
				local contact
				if step.Magnitude > 1e-4 then
					local dir = step.Unit
					local hit = workspace:Raycast(from, dir * (step.Magnitude + reachAlong(d, dir)), debrisParams)
					if hit then
						contact = hit
						to = hit.Position + hit.Normal * reachAlong(d, hit.Normal)
					end
				end
				if not contact then
					local down = reachAlong(d, Vector3.yAxis)
					local hit = workspace:Raycast(to + Vector3.new(0, 0.2, 0), Vector3.new(0, -(down + 0.25), 0), debrisParams)
					if hit and d.V.Y <= 0 then
						contact = hit
						to = hit.Position + hit.Normal * reachAlong(d, hit.Normal)
					end
				end
				if contact then
					local n = contact.Normal
					local vn = d.V:Dot(n)
					if vn < 0 then
						local tangent = d.V - n * vn
						d.V = tangent * DEBRIS_SLIDE - n * vn * DEBRIS_BOUNCE
						d.W *= DEBRIS_SLIDE
					end
					if d.Big and not d.Landed and n.Y > 0.6 and now - d.Born > 0.05 then
						d.Landed = true
						burst(rock, "Landing", CFrame.new(contact.Position + n * 0.15), 2, math.clamp(d.Size * 2.2, 0.5, 2.5))
					end
					if d.V.Magnitude < DEBRIS_REST and n.Y > 0.6 then
						d.Rest = true
						d.V, d.W = Vector3.zero, Vector3.zero
					end
				end
				local turn = d.W.Magnitude > 1e-3 and CFrame.fromAxisAngle(d.W.Unit, d.W.Magnitude * dt) or CFrame.new()
				d.F = CFrame.new(to) * turn * d.F.Rotation
				for _, e in ipairs(d.Parts) do queueMove(e.Part, d.F * e.Off) end
				if now - d.Born > 6 then
					for _, e in ipairs(d.Parts) do e.Part:Destroy() end   -- fell off the world: gone
				end
			end
		end
	end
end

--- A cell leaves the rock as one piece: its seam and cracks carried with its stone.
local function launchCell(rock, cell, vel, spin)
	local root = cell.Parts[1].Part
	local f = root.CFrame
	local parts = {}
	for _, e in ipairs(cell.Parts) do parts[#parts + 1] = { Part = e.Part, Off = f:ToObjectSpace(e.Part.CFrame) } end
	addDebris(rock, parts, f, vel, spin, root.Size / 2, true)
end

--- A pebble thrown off the rock (a chunk at the break, a chip in flight), `size` studs across.
local function throwPebble(rock, at, size, vel, spin, big)
	local pb = rock.Pebbles[rock.Rng:NextInteger(1, #rock.Pebbles)]
	local p = m1Piece(pb)
	p.Size = pb.Size * size
	local f = CFrame.new(at) * CFrame.fromAxisAngle(randUnit(rock.Rng), rock.Rng:NextNumber(0, 6))
	p.CFrame = f
	p.Parent = rock.Model
	addDebris(rock, { { Part = p, Off = CFrame.new() } }, f, vel, spin, p.Size / 2, big)
end

--- Grit: too small for the physics to be worth it, so it is flown here -- falling at DebrisGravity, bouncing low off
--- the floor it was thrown over and skidding to a stop (the film's Grit).
local function throwGrit(rock, at, vel, size, floorY)
	local pb = rock.Pebbles[rock.Rng:NextInteger(1, #rock.Pebbles)]
	local p = m1Piece(pb)
	p.CastShadow = false
	p.Size = pb.Size * size
	p.Parent = rock.Model
	table.insert(rock.Grit, { Part = p, P = at, V = vel, Size = size, Floor = floorY,
		Q = CFrame.fromAxisAngle(randUnit(rock.Rng), rock.Rng:NextNumber(0, 6)),
		W = randUnit(rock.Rng) * rock.Rng:NextNumber(10, 30) })
end

-- THE BLOOM KICK (the film's +0.35, gone in ~0.15 s): one kick at a time across every rock, on the place's own
-- BloomEffect, put back exactly as it was. Reduce Flashing takes it away, and only a break near the camera kicks.
local bloom = { Effect = nil, Base = 0, Until = 0 }
local function bloomKick(position)
	if Settings.Get and Settings.Get("ReduceFlashing") then return end
	-- not in first person: the viewmodel's arms sit a stud from the lens in their own calibrated light, and a kick
	-- blooms them white long before it does anything to a break twenty studs out (the Play test, 2026-09-23)
	if Viewmodel and Viewmodel.GetFistCFrame and Viewmodel.GetFistCFrame("R") then return end
	local cam = workspace.CurrentCamera
	if not (cam and (cam.CFrame.Position - position).Magnitude < 60) then return end
	local Lighting = game:GetService("Lighting")
	local fx = Lighting:FindFirstChildOfClass("BloomEffect")
	if not (fx and fx.Enabled) then return end
	if bloom.Effect ~= fx or os.clock() > bloom.Until then
		bloom.Effect, bloom.Base = fx, fx.Intensity
	end
	local born = os.clock()
	bloom.Until = born + 0.3
	addEffect(function(now)
		if bloom.Effect ~= fx or not fx.Parent then return false end
		local a = now - born
		if a >= 0.3 then
			if now >= bloom.Until then fx.Intensity = bloom.Base end
			return false
		end
		fx.Intensity = bloom.Base + 0.35 * math.exp(-a / 0.06)
		return true
	end)
end

local aftermath                               -- forward: the step that runs a broken rock to its end

--- THE BREAK. `hit` is the RaycastResult the throw stopped on (nil for a rock that burnt out or was dropped), `body`
--- the character model it stopped on, `dir` the throw. The rock breaks back into its own pieces -- plus chunks and
--- grit -- and the impact's dust, sparks, flash, light and marks go off where it struck.
local function breakBoulder(rock, hit, body, dir, quiet)
	if rock.Broken then return end
	rock.Broken = true
	rock.BrokeAt = os.clock()
	if rock.Rim then rock.Rim:Destroy() rock.Rim = nil end
	releaseArm(rock)
	if quiet and not hit and rock.Eye and (rock.K or 1) < 0.999 then
		-- dropped in the caster's own first-person hand (death, a lost character): it was only ever a picture at the
		-- fist, and its pieces would fall from the rock it stood in for, out in the world. It just goes.
		for _, m in ipairs(rock.Marks) do m.Host:Destroy() end
		if rock.BurstHost then rock.BurstHost:Destroy() end
		rock.Model:Destroy()
		return
	end
	local rng = rock.Rng
	local fwd = dir and Vector3.new(dir.X, 0, dir.Z) or Vector3.zero
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zero
	local s = rock.S or TerraFX.ChargeScale(rock.U) / FULL
	local P = rock.P or rock.A or rock.Host.Position
	local rot = rock.Rot or CFrame.new()
	local hp = hit and hit.Position or P
	if hit and ((rock.K or 1) < 0.999 or not rock.Flight) then
		-- struck before it was out on its line (first person, or a target within the Trigger's reach of the hand): the
		-- pieces break where it struck, full size -- never in the thrower's hand while the impact goes off at the target
		P = hp - (dir and dir.Unit or Vector3.zero) * (0.4 * FULL * s)
	end
	rock.Eye = nil
	local vr = rock.Vel or (dir and dir.Unit * 86 or Vector3.zero)
	-- the cells, where they are now, at full size, then off
	local rockCF = CFrame.new(P) * rot
	for _, cell in ipairs(rock.Cells) do
		if cell.Parts[1].Part.Parent then
			local frame = rockCF * CFrame.new(cell.Centre * (s * (rock.Gs or 1.016)))
			for _, e in ipairs(cell.Parts) do
				e.Scale = nil
				placePiece(e, cell.Centre, frame, s, 1, nil)
			end
		end
	end
	flushMoves()
	for _, f in ipairs(rock.Feeders) do
		if f.Part then f.Part:Destroy() f.Part = nil end
		f.Done = true
	end
	for _, cell in ipairs(rock.Cells) do
		if cell.Parts[1].Part.Parent then
			local p = cell.Parts[1].Part.Position
			local v
			if quiet then
				v = randUnit(rng) * rng:NextNumber(1, 3) + Vector3.new(0, rng:NextNumber(0, 2), 0) + vr * 0.1
			else
				local rdir = p - hp
				rdir = rdir.Magnitude > 1e-3 and rdir.Unit or randUnit(rng)
				local ahead = rdir:Dot(fwd)
				if ahead > 0 then rdir = (rdir - fwd * ahead * 1.3).Unit end
				-- it arrives at 86 studs/s: the pieces burst -- off what it hit, back toward the thrower, up and out
				v = rdir * rng:NextNumber(6, 11) + Vector3.new(0, rng:NextNumber(2.5, 5.5), 0)
					+ vr * rng:NextNumber(0.02, 0.05) - fwd * rng:NextNumber(2, 5)
			end
			launchCell(rock, cell, v, randUnit(rng) * rng:NextNumber(6, 15))
		end
	end
	-- the rock's own emitters stop; its light goes with the glow
	if rock.Trail then rock.Trail.Enabled = false end
	if rock.Embers then rock.Embers.Enabled = false end
	VFXLibrary.BoulderRate(rock.GatherDust, 0, rock.Thin)
	VFXLibrary.BoulderRate(rock.GatherGrit, 0, rock.Thin)
	local floorHit = floorUnder(rock, hp, body)
	rock.FloorY = floorHit and floorHit.Position.Y or nil
	if not quiet then
		local H = rock.Kit.Half
		local thinK = rock.Thin and 0.5 or 1
		-- chunks: broken out of the rock's body, thrown harder
		for _ = 1, math.floor(BS.DebrisChunks * thinK + 0.5) do
			local l = Vector3.new(rng:NextNumber(-0.6, 0.6) * H.X, rng:NextNumber(-0.6, 0.6) * H.Y, rng:NextNumber(-0.5, 0.5) * H.Z)
			local p = rockCF * (l * s)
			local rdir = (p - hp - fwd * 0.4)
			rdir = rdir.Magnitude > 1e-3 and rdir.Unit or randUnit(rng)
			local ahead = rdir:Dot(fwd)
			if ahead > 0 then rdir = (rdir - fwd * ahead * 1.3).Unit end
			throwPebble(rock, p, rng:NextNumber(0.35, 0.80),
				rdir * rng:NextNumber(8, 14) + Vector3.new(0, rng:NextNumber(2.5, 6), 0), randUnit(rng) * rng:NextNumber(6, 16), true)
		end
		-- grit, thrown fast off the point of the hit
		for _ = 1, math.floor(BS.DebrisGrit * thinK + 0.5) do
			local d = randUnit(rng)
			local ahead = d:Dot(fwd)
			if ahead > 0 then d = d - fwd * ahead * 1.5 end
			d = (d - fwd * 0.6 + Vector3.new(0, 0.35, 0))
			d = d.Magnitude > 1e-3 and d.Unit or Vector3.yAxis
			throwGrit(rock, hp + d * 0.3, d * rng:NextNumber(8, 16), rng:NextNumber(0.07, 0.16), rock.FloorY)
		end
		-- the dust: the cloud thrown back toward the thrower, the heavy dust dropping out of it, the sparks, the flash
		local back = fwd.Magnitude > 0 and -fwd or (hit and hit.Normal or Vector3.yAxis)
		local look = (back * 1.3 + Vector3.new(0, 0.2, 0)).Unit
		local host = inert(Instance.new("Part"))
		host.Name = "BoulderImpact"
		host.Transparency = 1
		host.CastShadow = false
		host.Shape = Enum.PartType.Ball
		host.Size = Vector3.one * 1.6
		host.CFrame = CFrame.lookAt(hp + back * 0.3, hp + back * 0.3 + look)
		host.Parent = fxFolder()
		rock.ImpactHost = host
		VFXLibrary.BoulderBurst(host, "Cloud", 21, rock.Thin,
			{ Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume })
		VFXLibrary.BoulderBurst(host, "Cloud", 5, rock.Thin, { Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Color = ColorSequence.new(Color3.fromRGB(117, 97, 69)) })
		local sparkLook = (back * 0.7 + Vector3.new(0, 0.4, 0)).Unit
		local sparks = Instance.new("Attachment")
		sparks.CFrame = host.CFrame:ToObjectSpace(CFrame.lookAt(hp, hp + sparkLook))
		sparks.Parent = host
		VFXLibrary.BoulderBurst(sparks, "Spark", 16, rock.Thin, wrapFx(rock, "Spark"))
		local centre = Instance.new("Attachment")
		centre.Parent = host
		VFXLibrary.BoulderBurst(centre, "Flash", 1, false, wrapFx(rock, "Flash"))
		if rock.FloorY then
			local fy = rock.FloorY
			local at = Vector3.new(hp.X, fy + 0.4, hp.Z) + back * 0.8
			task.delay(0.1, function()
				if not rock.Model.Parent then return end
				burst(rock, "Settle", CFrame.new(at), 10, 1, 1.5)
			end)
		end
		-- the flash: a gold light that lights the floor and whoever was hit, a thirtieth of a second, then gone
		if not VFXLibrary.FlatLit() then
			local fl = Instance.new("PointLight")
			fl.Color = rock.Wrap and rock.Wrap.Skin.HitFlash or GOLD
			fl.Range = 16
			fl.Brightness = 9 * (rock.Thin and 0.7 or 1) * ((Settings.Get and Settings.Get("ReduceFlashing")) and 0.4 or 1)
			fl.Shadows = false
			local la = Instance.new("Attachment")
			la.CFrame = host.CFrame:ToObjectSpace(CFrame.new(hp + back * 1.0 + Vector3.new(0, 0.3, 0)))
			la.Parent = host
			fl.Parent = la
			rock.Flash = fl
			rock.FlashBase = fl.Brightness
		end
		bloomKick(hp)
		punchNear(hp, 0.3, 30)
		-- THE MARKS: a scuff in the floor (at the feet of whoever it hit, a little toward the thrower) and a dusty mark
		-- where it struck a body
		if hit then
			local markAt, markUp
			if body and floorHit then
				markAt, markUp = floorHit.Position + back * 1.2, floorHit.Normal
				local f2 = floorUnder(rock, markAt, body)
				if f2 then markAt, markUp = f2.Position, f2.Normal end
			elseif not body then
				markAt, markUp = hit.Position, hit.Normal
			end
			if markAt then
				local m = decalAt(rock, markAt, markUp, 5.5, M1_TEXTURES.Scuff, rng:NextNumber(0, 6.28))
				m.Born = os.clock()
				m.Life = BS.Scuff + 0.8
				m.Alpha = function(a) return 0.95 * span(a, 0.05, 0.14) * (1 - span(a, BS.Scuff, BS.Scuff + 0.8)) end
				table.insert(rock.Marks, m)
			end
			if body and hit.Instance then
				local m = decalAt(rock, hit.Position, hit.Normal, 1.6, M1_TEXTURES.Scuff, rng:NextNumber(0, 6.28))
				m.Born = os.clock()
				m.Life = 2.2
				m.Alpha = function(a) return 0.9 * (1 - span(a, 1.2, 2.2)) end
				m.Follow = hit.Instance
				m.Offset = hit.Instance.CFrame:ToObjectSpace(m.Host.CFrame)
				table.insert(rock.Marks, m)
			end
		end
	end
	addEffect(function(now) return aftermath(rock, now) end)
end

--- What is left of a broken rock, every frame: the glow going out, the flash, the grit, a puff where each big piece
--- first lands, the marks fading, and -- Settle after the break -- everything anchored and sunk into the floor. Nothing
--- fades but the dust and the marks.
aftermath = function(rock, now)
	local a = now - rock.BrokeAt
	local dt = math.min(now - (rock.LastStep or now), 1 / 20)
	rock.LastStep = now
	-- the energy goes out of it in the break, and it is stone again
	local seam = a < 0.30 and 3.0 * math.exp(-a / 0.05) or 0
	local lit = a < 0.25 and math.exp(-a / 0.05) or 0
	applyGlow(rock, seam, rock.TierAt[1] and lit * 2.4 or 0, rock.TierAt[2] and lit * 2.4 or 0, a)
	if rock.Flash then
		rock.Flash.Brightness = a < 0.03 and rock.FlashBase or rock.FlashBase * math.exp(-(a - 0.03) / 0.07)
		if a > 0.5 then rock.Flash:Destroy() rock.Flash = nil end
	end
	local sink0 = BS.Settle
	stepDebris(rock, now, a)
	-- the grit, flown by hand
	for _, gr in ipairs(rock.Grit) do
		local p = gr.Part
		if p.Parent then
			gr.V -= Vector3.new(0, BS.DebrisGravity * dt, 0)
			gr.P += gr.V * dt
			if gr.Floor and gr.P.Y < gr.Floor + gr.Size * 0.4 then
				gr.P = Vector3.new(gr.P.X, gr.Floor + gr.Size * 0.4, gr.P.Z)
				gr.V = Vector3.new(gr.V.X * 0.6, math.abs(gr.V.Y) * 0.25, gr.V.Z * 0.6)
				gr.W *= 0.6
			end
			if gr.W.Magnitude > 1e-3 then gr.Q = CFrame.fromAxisAngle(gr.W.Unit, gr.W.Magnitude * dt) * gr.Q end
			local u = span(a, sink0, sink0 + BS.Sink)
			if u >= 1 or (not gr.Floor and a > 1.5) then
				p:Destroy()
			else
				queueMove(p, CFrame.new(gr.P - Vector3.new(0, gr.Size * 2.2 * u * u, 0)) * gr.Q)
			end
		end
	end
	-- the marks
	local marksLeft = false
	for _, m in ipairs(rock.Marks) do
		if m.Host.Parent then
			local ma = now - m.Born
			if ma >= m.Life then
				m.Host:Destroy()
			else
				marksLeft = true
				m.Decal.Transparency = 1 - m.Alpha(ma)
				if m.Follow then
					if m.Follow.Parent then queueMove(m.Host, m.Follow.CFrame * m.Offset) else m.Host:Destroy() end
				end
			end
		end
	end
	flushMoves()
	if a >= sink0 + BS.Sink + 0.05 and not marksLeft then
		if rock.ImpactHost then rock.ImpactHost:Destroy() end
		if rock.BurstHost then rock.BurstHost:Destroy() end
		rock.Model:Destroy()
		return false
	end
	return true
end

--- A divot's own fade, while the rock it came from is still in the hand (the aftermath takes over after the break).
local function fadeMarks(rock, now)
	for _, m in ipairs(rock.Marks) do
		if m.Host.Parent then
			local a = now - m.Born
			if a >= m.Life then m.Host:Destroy() else m.Decal.Transparency = 1 - m.Alpha(a) end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- the charge and the throw
----------------------------------------------------------------------------------------------------
--- The rock being gathered. `getCharge` is asked every frame for the charge so far (0..1) and returns nil when the
--- hold is over without a throw (the rock is then dropped: it falls apart where it is). `hand` is asked for where it
--- is held: (cf, eye, facing) -- the caster's own fist and eye in first person (see anchorOf), or a body's hand and
--- no eye. opts: Own (the caster's own: the viewmodel arm takes its weight), Thin (somebody else's: Reduce Enemy
--- VFX), Character (left out of the floor probes). Returns the rock, which FireBoulder takes over on the throw.
function TerraFX.Charge(getCharge, hand, opts)
	libs()
	opts = opts or {}
	local rock = newBoulder({ Hand = hand, Thin = opts.Thin, Own = opts.Own, Character = opts.Character, Wrap = opts.Wrap })
	if rock.Own and Viewmodel and Viewmodel.SetArmOffset then
		rock.ArmHeld = true
		Viewmodel.SetArmOffset("R", function() return armLoad(rock) end)
	end
	addEffect(function(now)
		if rock.Thrown then return false end
		local u = getCharge()
		if u ~= nil then rock.U = math.clamp(u, 0, 1) end
		if u == nil or not updateHeld(rock, now) then
			breakBoulder(rock, nil, nil, nil, true)          -- dropped: it falls apart in the hand
			return false
		end
		fadeMarks(rock, now)
		flushMoves()
		return true
	end)
	return rock
end

--- The rock's first frame out of the hand: where it was, and how it will run onto the game's line.
local function beginFlight(rock, origin, v0, dir)
	local speed = v0.Magnitude
	local F = { Origin = origin, V0 = v0, Dir = dir, Speed = speed, S = rock.S, G = rock.Gs, Rot = rock.Rot }
	local A = rock.A
	F.FP = rock.Eye ~= nil
	if F.FP then
		local off = A - origin
		F.D0 = off:Dot(dir)
		F.Q0 = off - dir * F.D0
		F.K0 = rock.K
	else
		F.Off = A - TerraFX.BoulderPoint(origin, v0, BS.Trigger)
	end
	-- mostly topspin: turning over toward the target
	local facing = flatFacing(dir)
	F.Axis = facing:VectorToWorldSpace(Vector3.new(-1, 0.30, -0.15)).Unit
	-- the gathering is over: its emitters stop, the half-merged stones go, and the flight's own dust and embers start
	VFXLibrary.BoulderRate(rock.GatherDust, 0, rock.Thin)
	VFXLibrary.BoulderRate(rock.GatherGrit, 0, rock.Thin)
	local sz = rock.S
	rock.Host.Size = Vector3.one * (2.2 * sz)
	-- (first person, the trail waits until the rock is drawn at its own size: puffs let go at k < 1 would hang full-size
	-- beside the lens -- flyBoulder switches it on)
	rock.Trail = VFXLibrary.BoulderEmitter(rock.Host, "Trail", rock.Thin, {
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * sz), NumberSequenceKeypoint.new(1, 3.0 * sz) }),
		Rate = BS.TrailDust,
	})
	rock.Trail.Enabled = not F.FP
	local ea = Instance.new("Attachment")
	ea.Parent = rock.Host
	rock.Embers = VFXLibrary.BoulderEmitter(ea, "Ember", rock.Thin, wrapFx(rock, "Ember"))
	rock.NextChip = BS.Trigger + 0.06
	rock.Flight = F
	return F
end

local MAX_CHIPS = 14                          -- chips one rock sheds in flight, at most

--- One frame of the flight, `t` seconds down the game's line (button-up = 0). Until Trigger the rock is still in the
--- hand (the arm's drive); then it leaves and runs onto the line.
local function flyBoulder(rock, now, t)
	local tv = t - BS.Trigger
	if tv < 0 or not rock.A then
		if rock.Tu == nil then rock.Tu = now - rock.T0 end
		if not updateHeld(rock, now) and not rock.A then return end
		if tv < 0 then return end
	end
	local F = rock.Flight or beginFlight(rock, rock.LineOrigin, rock.LineV0, rock.LineDir)
	local eye = F.FP and workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or nil
	local w = 1 - math.min(tv / 0.1, 1)
	local P, k
	if F.FP then
		local depth
		if tv >= BS.FPMerge then
			depth = F.Speed * t
		else
			-- the depth along the line runs from where it was held -- leaving at 25 studs/s -- onto the line itself at
			-- FPMerge, at the line's own speed, never slowing; the sideways offset eases out over 0.1 s
			depth = hermite(F.D0, 25, F.Speed * (BS.FPMerge + BS.Trigger), F.Speed, tv / BS.FPMerge, BS.FPMerge)
		end
		P = F.Origin + F.Dir * depth + F.Q0 * (w * w) + Vector3.new(0, -0.5 * BS.Gravity * t * t, 0)
		k = F.K0 + (1 - F.K0) * smooth(tv / 0.1)
	else
		P = TerraFX.BoulderPoint(F.Origin, F.V0, t) + F.Off * (w * w)
		k = 1
	end
	local rot = CFrame.fromAxisAngle(F.Axis, BS.VisualSpin * tv) * F.Rot
	rock.P, rock.Rot, rock.K, rock.Eye = P, rot, k, eye
	rock.Vel = F.V0 + Vector3.new(0, -BS.Gravity * t, 0)
	placePieces(rock, now - rock.T0, P, rot, F.S, F.G, k, eye, rock.Facing or flatFacing(F.Dir))
	queueMove(rock.Host, CFrame.new(project(eye, P, k)))
	if rock.Light then rock.Light.Range = eye and (8 * k + 1.5) or 8 end
	if rock.Trail and not rock.Trail.Enabled and k >= 0.99 then rock.Trail.Enabled = true end
	-- the glow rides it, flickering; the chips peel off it and fall for real
	local seam, c2, c3 = glowAt(rock, now - rock.T0)
	applyGlow(rock, seam * (1 + 0.15 * math.sin(now * 90)), c2, c3, now - rock.T0)
	local rng = rock.Rng
	local rate = BS.TrailChips * ((rock.Thin and Settings.ThinEnemyVFX) and 0.5 or 1) * (Settings.EffectDensity or 1)
	-- the film's 45 a second over the film's quarter-second flight is a dozen chips; a throw into the sky flies the whole
	-- 2.4 s Life, and at that rate would leave a hundred pieces to fly and settle on every client
	rock.Chips = rock.Chips or 0
	while rate > 0 and rock.NextChip <= t and rock.Chips < MAX_CHIPS do
		rock.Chips += 1
		rock.NextChip += 1 / rate * rng:NextNumber(0.6, 1.4)
		local v = rock.Vel
		local vu = v.Magnitude > 1e-3 and v.Unit or F.Dir
		local dl = randUnit(rng)
		dl = (dl - vu * (dl:Dot(vu) * 0.6)).Unit
		local local_ = rot:VectorToObjectSpace(dl)
		local H = rock.Kit.Half
		local sup = math.sqrt((H.X * local_.X) ^ 2 + (H.Y * local_.Y) ^ 2 + (H.Z * local_.Z) ^ 2)
		throwPebble(rock, P + dl * (sup * F.S * 0.92), rng:NextNumber(0.16, 0.32),
			v * rng:NextNumber(0.25, 0.40) + dl * rng:NextNumber(2, 5) + Vector3.new(0, rng:NextNumber(0, 2), 0),
			randUnit(rng) * rng:NextNumber(10, 25), false)
	end
	fadeMarks(rock, now)
	stepDebris(rock, now, nil)
end

--- Builds every wrap a player has chosen for Boulder Shot as soon as it is chosen (their attribute replicates), so
--- the first cast seen already wears it. TerraWrap.Get only starts a build; it never yields here.
function TerraFX.WatchWraps()
	local function watch(pl)
		local function check()
			for _, a in ipairs({ "BoulderShot", "BulwarkCharge", "Bedrock" }) do
				local id = pl:GetAttribute("Skin_" .. a)
				if type(id) == "string" and id ~= "Default" then wrapFor(id, boulderKit(), pl == Players.LocalPlayer) end
			end
		end
		for _, a in ipairs({ "BoulderShot", "BulwarkCharge", "Bedrock" }) do
			pl:GetAttributeChangedSignal("Skin_" .. a):Connect(check)
		end
		-- the caster's own: every Terra wrap starts building the moment they are Terra (2026-10-10: built only on the
		-- pick, the first casts after it drew Default while it built), so it is ready before they open WRAPS
		if pl == Players.LocalPlayer then
			local function own()
				if pl:GetAttribute("Element") ~= "Terra" then return end
				local ok, S = pcall(require, ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))
				if not ok then return end
				for _, id in ipairs(S.List("Terra", "BoulderShot")) do
					if id ~= "Default" then wrapFor(id, boulderKit(), true) end
				end
			end
			pl:GetAttributeChangedSignal("Element"):Connect(own)
			own()
		end
		check()
	end
	for _, pl in ipairs(Players:GetPlayers()) do task.spawn(watch, pl) end
	Players.PlayerAdded:Connect(watch)
end

--- A built wrap set at an explicit CrackGlow (the review sheets'), or nil while it builds.
function TerraFX.WrapSet(id, glow)
	TerraWrap = TerraWrap or require(script.Parent:WaitForChild("TerraWrap"))
	return TerraWrap.Get(id, boulderKit(), glow)
end

--- The throw. Flies the arc from `origin`, and stops on the first thing it meets: `onHit` (the shooter's own client
--- only) is called with the RaycastResult before anything cosmetic happens, so the server hears about the hit first.
--- THE LINE AND ITS HIT TEST ARE THE MECHANIC and are unchanged: from the eye, down the crosshair, at the charge's speed,
--- dropping at Gravity. `from` is what is thrown: the rock Charge() returned (the same pieces fly on), or -- nothing
--- gathered on this client -- a Vector3 (a whole rock straight out of that hand) or nil.
function TerraFX.FireBoulder(origin, dir, charge, exclude, from, onHit, wrap)
	libs()
	local B = T.BoulderShot
	if dir.Magnitude < 0.1 then return end
	local u = math.clamp(charge or 0, 0, 1)
	local v0 = TerraFX.BoulderVelocity(dir.Unit, u)
	local rock = (type(from) == "table" and from.Model and not from.Thrown and not from.Broken) and from or nil
	if not rock then
		-- nothing live to throw: a whole rock leaves the hand it was given, or -- a dead rock (dropped before this could
		-- take it) or nothing at all -- a little way out along the line, never inside the lens
		local at = typeof(from) == "Vector3" and from or (origin + dir.Unit * 4)
		local facing = flatFacing(dir)
		rock = newBoulder({ Assembled = true, U = u, Thin = onHit == nil, Wrap = wrap,
			Hand = function() return CFrame.new(at) * facing, nil, facing end })
		rock.Exact = true
		rock.T0 = os.clock() - 5                 -- whole, and past every beat of the gathering
		for n, tier in ipairs({ 1 / 3, 2 / 3 }) do
			if u >= tier then rock.TierAt[n] = -10 end   -- its cracks already lit, without the flare
		end
	end
	rock.Thrown = true
	releaseArm(rock)
	rock.LineOrigin, rock.LineV0, rock.LineDir = origin, v0, dir.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { fxFolder() }
	for _, inst in ipairs(exclude or {}) do list[#list + 1] = inst end
	params.FilterDescendantsInstances = list
	local start = os.clock()
	local lastT = 0
	rock.Tu = start - rock.T0
	addEffect(function(now)
		local t = math.min((now - start) * VFXLibrary.ShotTimeScale(), B.Life)
		local a = TerraFX.BoulderPoint(origin, v0, lastT)
		local b = TerraFX.BoulderPoint(origin, v0, t)
		local hit = t > lastT and workspace:Raycast(a, b - a, params)
		lastT = t
		if hit or t >= B.Life then
			if hit then
				if onHit then task.spawn(onHit, hit) end
				local model = hit.Instance:FindFirstAncestorOfClass("Model")
				local body = model and model:FindFirstChildOfClass("Humanoid") and model or nil
				breakBoulder(rock, hit, body, dir.Unit, false)
			else
				breakBoulder(rock, nil, nil, dir.Unit, true)   -- burnt out: it just falls apart where it is
			end
			flushMoves()
			return false
		end
		flyBoulder(rock, now, t)
		flushMoves()
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: BULWARK CHARGE
----------------------------------------------------------------------------------------------------
--- One angular slab of rock torn out of the ground, left where it was and sinking back into it. Every
--- solid piece of this kit is one of these: a flat-toned Part with an ink silhouette.
local function slab(cf, size, tone)
	local part = inert(Instance.new("Part"))
	part.Name = "TerraSlab"
	part.Size = size
	part.Color = COL[tone]
	part.CFrame = cf
	part.Parent = fxFolder()
	local ink = Instance.new("Highlight")
	ink.FillTransparency = 1
	ink.OutlineColor = COL.Ink
	ink.OutlineTransparency = 0
	ink.DepthMode = Enum.HighlightDepthMode.Occluded
	ink.Adornee = part
	ink.Parent = part
	return part
end

-- VFX POLISH (2026-09-18). The charge reads as TERRA PLOUGHING THROUGH THE FLOOR -- dust and rubble kicked up low
-- off every footfall, no more slabs dropping out of nowhere -- and its damage reduction reads as PLATES GOING UP:
-- three of Bedrock's own plates, smaller, snap onto the charger's front for as long as the charge runs, each with
-- Bedrock's clink, and crack off when it ends. Damage reduction is plates everywhere in this kit, never a tint.
-- (The plate helpers live in the Bedrock section below, so they are reached through TerraFX.Plate / DropPlate.)
local STEP_EVERY = 0.09               -- seconds between footfalls at the charge's pace: a look, not a number the charge uses
local ARMOUR = {                      -- the charge's plates on the torso: where, and turned how far off straight ahead
	{ Vector3.new(0, 0.25, -1.1), 0 },
	{ Vector3.new(-1.0, 0.7, -0.75), math.rad(38) },
	{ Vector3.new(1.0, 0.7, -0.75), math.rad(-38) },
}

--- The charge's look, for as long as `alive()` keeps returning true: the armour and the footfalls. (Still named
--- BulwarkTrail -- the caster's input and AbilityFX both call it by that name.)
function TerraFX.BulwarkTrail(character, alive, wrap)
	libs()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local torso = character:FindFirstChild("UpperTorso") or root
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local own = Players.LocalPlayer ~= nil and character == Players.LocalPlayer.Character
	local thin = not own
	-- the caster's wrap: from the broadcast for somebody else's charge, from their own choice for the caster's
	wrap = wrapFor(wrap, boulderKit(), own) or (wrap == nil and wrapOf(character, "BulwarkCharge", own)) or nil
	local fullSpeed = T.BulwarkCharge.Distance / T.BulwarkCharge.Time
	local plates = {}
	for i, a in ipairs(ARMOUR) do
		plates[i] = {
			plate = TerraFX.Plate(Vector3.new(1.5, 1.9, 0.42), (i == 1) and "Light" or "Base", own, i + 1, 0.9, wrap),
			at = a[1], yaw = a[2], born = os.clock() + (i - 1) * 0.04,
		}
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fxFolder() }
	local nextStep, foot = os.clock(), 1
	addEffect(function(now)
		if not (root.Parent and alive()) then
			-- the charge is over: the armour cracks off, one plate after another
			local fwd = torso.Parent and torso.CFrame.LookVector or Vector3.yAxis
			for i, p in ipairs(plates) do
				TerraFX.DropPlate(p.plate, fwd, (i - 1) * 0.05, thin)
			end
			return false
		end
		-- THE ARMOUR: each plate flies in from further out over 0.09 s and locks with the clink
		local body = torso.CFrame
		-- a wrap's seams follow the charge's speed: Low, Mid, Max at a third and three quarters of full pace
		local sp = root.AssemblyLinearVelocity.Magnitude / fullSpeed
		local stage = (sp >= 0.75 and "Max") or (sp >= 0.35 and "Mid") or "Low"
		for _, p in ipairs(plates) do
			plateStage(p.plate, p.locked and stage or nil)
			local u = math.clamp((now - p.born) / 0.09, 0, 1)
			local cf = body * CFrame.new(p.at * (1 + 1.2 * (1 - u))) * CFrame.Angles(0, p.yaw, 0)
			placeRock(p.plate, cf)
			if u >= 1 and not p.locked then
				p.locked = true
				if not own then
					VFXLibrary.TerraSpark(cf.Position + cf.LookVector * 0.25, cf.LookVector, 0.9, thin, wrapFx({ Wrap = wrap }, "Chips"))
				end
			end
		end
		-- THE FOOTFALLS: left, right, left -- dust and rubble thrown low and back off the floor under each
		if now >= nextStep then
			nextStep = now + STEP_EVERY
			foot = -foot
			local hip = humanoid and humanoid.HipHeight or 2
			local from = root.Position + root.CFrame.RightVector * 0.55 * foot
			local hit = workspace:Raycast(from, Vector3.new(0, -(root.Size.Y * 0.5 + hip + 2), 0), params)
			if hit then
				VFXLibrary.TerraDustKick(hit.Position + Vector3.new(0, 0.15, 0), -root.CFrame.LookVector, thin)
			end
		end
		return true
	end)
end

--- The knockdown: a hard, flat burst of rock where the shoulder met them. Comic, angular, one frame of
--- geometry rather than a glow -- the Element's own version of the impact-burst the other kits stamp.
function TerraFX.BulwarkHit(position, dir, thin, wrap)
	libs()
	-- a wrap (the broadcast's): obsidian spikes in the wrap's bands, ink #080E1A, obsidian chunks and ember grit; the
	-- dust burst stays Terra's tan
	wrap = wrapFor(wrap, boulderKit(), not thin)
	local fwd = (typeof(dir) == "Vector3" and dir.Magnitude > 0.1) and dir.Unit or Vector3.zAxis
	local right = fwd:Cross(Vector3.yAxis)
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = right:Cross(fwd).Unit
	local spikes = {}
	for i = 1, 7 do
		local ang = (i - 4) * 0.42
		local out = (right * math.sin(ang) + up * math.cos(ang)).Unit
		local len = 2.6 + math.random() * 1.6
		spikes[i] = slab(
			CFrame.lookAt(position + out * 1.2 + fwd * 0.2, position + out * 6),
			Vector3.new(0.5 + math.random() * 0.3, 0.5, len),
			(i % 2 == 0) and "Light" or "Base")
		if wrap then
			local s, R, tint = wrap.Skin, wrap.Skin.Rock, wrap.Skin.RockTint
			-- a lit Part reads a band lighter than the same colour baked in a mesh: one band down, near-black
			local c = (i % 2 == 0) and R.Mid or R.Shadow
			spikes[i].Color = Color3.new(c.R * tint.R, c.G * tint.G, c.B * tint.B)
			local ink = spikes[i]:FindFirstChildOfClass("Highlight")
			if ink then ink.OutlineColor = s.Ink end
		end
	end
	if VFXLibrary.TerraRockDebris then
		VFXLibrary.TerraRockDebris(position, thin == true, 18, 12, fwd,
			wrap and { Chunks = wrapFx({ Wrap = wrap }, "Chunks"), Grit = wrapFx({ Wrap = wrap }, "Grit") } or nil)
	end
	-- VFX polish: the CONTACT -- the flat comic burst right where the shoulder landed, and a camera punch for
	-- whoever is near it (Camera Shake scales it; Reduce Flashing takes it away)
	VFXLibrary.TerraBurst(position - fwd * 0.5 + up * 0.3, 3.6, thin == true)
	punchNear(position, 0.5, 28)
	local born = os.clock()
	addEffect(function(now)
		local t = (now - born) / 0.26
		if t >= 1 then
			for _, p in ipairs(spikes) do p:Destroy() end
			return false
		end
		-- the burst throws OUT and shrinks back in: a stamp, not a puff
		for i, p in ipairs(spikes) do
			local s = 1 - t * t
			local base = 2.6 + (i % 3) * 0.5
			p.Size = Vector3.new(0.5 * s + 0.1, 0.5 * s + 0.1, base * (0.6 + 0.9 * (1 - t)))
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- STAGGERED: the tell over a staggered head (VFX polish, 2026-09-18)
----------------------------------------------------------------------------------------------------
-- Bulwark Charge raises Staggered through CombatCore AND the reaction layer's own flag, RX_Staggered, on whatever
-- it knocks down -- a player or a range dummy. Every client draws three comic stars circling that head from the
-- flag (no remote), as Bedrock's plates are drawn from Bedrock_Stacks. The staggered player's OWN screen gets the
-- reaction layer's displacement fan instead (StatusReactions, the Knockback pulse), not stars round their camera.
local dazed = setmetatable({}, { __mode = "k" })     -- [model] = { Stars = {...}, Born = t, Gone = t or nil }

local function starPiece()
	local p = kitMesh("TR_StaggerStar")
	if p then
		p.Parent = fxFolder()
		return p, true
	end
	local part = inert(Instance.new("Part"))
	part.Name = "StaggerStar"
	part.Size = Vector3.new(0.42, 0.42, 0.14)
	part.Color = COL.Light
	part.Parent = fxFolder()
	return part, false
end

local function updateDazed(model, on, now, camPos)
	local d = dazed[model]
	local head = model:FindFirstChild("Head")
	if on and head and not d then
		d = { Stars = {}, Born = now }
		for i = 1, 3 do
			local p, isMesh = starPiece()
			d.Stars[i] = { part = p, mesh = isMesh, base = p.Size }
		end
		dazed[model] = d
	end
	if not d then return end
	if not on and not d.Gone then d.Gone = now end
	local k
	if d.Gone then
		-- they go the way meshes go: shrinking away, never fading
		k = 1 - (now - d.Gone) / 0.15
		if k <= 0 or not head then
			for _, s in ipairs(d.Stars) do s.part:Destroy() end
			dazed[model] = nil
			return
		end
	else
		k = math.clamp((now - d.Born) / 0.1, 0, 1)
	end
	if not head then return end
	local top = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.55, 0)
	for i, s in ipairs(d.Stars) do
		local a = now * 5 + i * (2 * math.pi / 3)
		local pos = top + Vector3.new(math.cos(a) * 1.0, math.sin(now * 7 + i) * 0.12, math.sin(a) * 1.0)
		s.part.Size = s.base * math.max(0.02, k)
		local cf = CFrame.lookAt(pos, camPos) * CFrame.Angles(0, 0, now * 4 + i)
		if s.mesh then
			s.part:PivotTo(cf * MESH_TURN)
		else
			s.part.CFrame = cf * CFrame.Angles(0, 0, math.rad(45))
		end
	end
end

--- Every staggered head's stars, from their own RX_Staggered. Started once per client (AbilityFX).
function TerraFX.WatchStagger()
	if TerraFX._watchingStagger then return end
	TerraFX._watchingStagger = true
	libs()
	local candidates, nextScan = {}, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 1
			candidates = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Character and plr ~= Players.LocalPlayer then candidates[#candidates + 1] = plr.Character end
			end
			local tg = workspace:FindFirstChild("TrainingGround")
			if tg then
				for _, h in ipairs(tg:GetDescendants()) do
					if h:IsA("Humanoid") and h.Parent then candidates[#candidates + 1] = h.Parent end
				end
			end
		end
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		for _, m in ipairs(candidates) do
			if m.Parent then updateDazed(m, m:GetAttribute("RX_Staggered") == true, now, camPos) end
		end
		for m in pairs(dazed) do
			if not m.Parent then updateDazed(m, false, now, camPos) end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: BEDROCK
----------------------------------------------------------------------------------------------------
-- The shield's plates, driven off the character's own replicated attributes rather than a broadcast: every
-- client watches Bedrock_Stacks on every character, so a Terra walking past with four plates up is legible
-- without a remote per stack. One plate per stack, assembling around the chest at shoulder height, each a
-- slab of rock curved round the body with an ink outline: armour, not a bubble.
-- ...and held strongly, swept by the watcher below (2026-09-21): weak keys let a dead character's entry be
-- collected before anything took its plates off, and a plate lives in the FX folder rather than under the body,
-- so the only handle on it went with the key and the plates stayed in the world for the rest of the session.
local shells = {}                                      -- [character] = { Plates = {}, Shown = n }

--- One plate, in the rock's shape ({ Model, Pieces }) so placeRock moves it: it faces along its CFrame's LookVector
--- and its two edges curve back toward the body. With the kit imported it is a kit mesh, TR_Plate_01..04 by
--- `variant` -- its three tone bands baked, its ink a hull. Without it, the Part plate: `size` (width, height,
--- thickness) bent round a vertical axis PlateBend studs behind it as PlateFacets flat columns under one
--- Highlight. `scale` draws it smaller -- Bulwark Charge's armour wears these same plates.
---
--- `own` marks the local player's own plates. In first person they sit at eye level, 2.6 studs from the lens,
--- and walled the view off (2026-09-18), so they go through VFXLibrary.RegisterProximityFade like every other
--- piece of the caster's own nearby VFX: close to the camera they are not drawn for their owner, while every
--- other client still sees the full shell. The owner reads the stacks off the HUD's passive chip.
local function curvedPlate(size, tone, own, variant, scale, wrap)
	libs()
	scale = scale or 1
	variant = ((variant or 1) - 1) % 4 + 1
	local model = Instance.new("Model")
	model.Name = "BedrockPlate"
	local mesh = kitMesh(("TR_Plate_%02d"):format(variant), wrap)
	if mesh then
		meshScale(mesh, scale)
		mesh.Parent = model
		if own then VFXLibrary.RegisterProximityFade(mesh) end
		local pieces = { { part = mesh, cf = MESH_TURN, pivot = true } }
		-- a wrap's magma seam on the plate (dark until plateStage lights it)
		local cracks = wrap and wrap.PlateCracks and wrap.PlateCracks[variant]
		local crack = nil
		if cracks then
			crack = cracks.Low:Clone()
			crack.Anchored, crack.CanCollide, crack.CanQuery, crack.CanTouch, crack.CastShadow = true, false, false, false, false
			crack.Material = Enum.Material.Neon
			crack.Transparency = 1
			meshScale(crack, scale)
			crack.Parent = model
			if own then VFXLibrary.RegisterProximityFade(crack) end
			pieces[2] = { part = crack, cf = MESH_TURN, pivot = true, crack = true }
		end
		model.Parent = fxFolder()
		return { Model = model, Pieces = pieces, Own = own, Mesh = true, Variant = variant, Scale = scale, Wrap = wrap,
			Crack = crack, Cracks = cracks }
	end
	local B = T.Bedrock
	size = size * scale
	local n = math.max(1, B.PlateFacets)
	local bend = B.PlateBend * scale
	local width = size.X / n
	local step = width / bend                  -- radians round the axis per column
	local pieces = {}
	for i = 1, n do
		local part = inert(Instance.new("Part"))
		part.Name = "Column" .. i
		-- a sliver wider than its share of the arc, so the outside of each fold closes rather than showing
		-- a hairline of whatever is behind it
		part.Size = Vector3.new(width + size.Z * step, size.Y, size.Z)
		part.Color = COL[tone]
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		local ang = (i - (n + 1) / 2) * step
		pieces[i] = { part = part, cf = CFrame.new(0, 0, bend) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -bend) }
		if own then VFXLibrary.RegisterProximityFade(part) end
	end
	local ink = Instance.new("Highlight")
	ink.Name = "Ink"
	ink.FillTransparency = 1
	ink.OutlineColor = COL.Ink
	ink.OutlineTransparency = 0
	ink.DepthMode = Enum.HighlightDepthMode.Occluded
	ink.Adornee = model
	ink.Parent = model
	model.Parent = fxFolder()
	return { Model = model, Pieces = pieces, Ink = ink, Own = own, Variant = variant, Scale = scale }
end
TerraFX.Plate = curvedPlate

--- A wrapped plate's magma seam at `stage` (Low / Mid / Max), or dark (nil). Static per stage: no flicker.
plateStage = function(plate, stage)
	local c = plate.Crack
	if not c or plate.Stage == stage then return end
	plate.Stage = stage
	if stage then
		local size = c.Size
		pcall(function() c:ApplyMesh(plate.Cracks[stage]) end)
		c.Size = size
		c.Transparency = 0
	else
		c.Transparency = 1
	end
end

--- The wrap `character`'s player wears on `ability` (their own replicated choice, SkinCatalog), as a built set or nil.
local SkinCatalog = nil
wrapOf = function(character, ability, own)
	local plr = character and Players:GetPlayerFromCharacter(character)
	if not plr then return nil end
	SkinCatalog = SkinCatalog or require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))
	return wrapFor(SkinCatalog.Chosen(plr, ability), boulderKit(), own)
end

--- A plate CRACKING and falling away (VFX polish, 2026-09-18): in two along its break -- the kit's
--- TR_Plate_0n_A / _B halves -- or, as Parts, apart at its folds. Each piece is flung a little out, tumbles, drops
--- through the floor and shrinks to nothing: a mesh sinks or wipes, it never fades. `delay` holds the plate where
--- it is first, so a whole shell comes off one plate at a time, the way it went on.
local function dropPlate(plate, out, delay, thin)
	libs()
	local held = {}
	for i, e in ipairs(plate.Pieces) do
		held[i] = e.pivot and e.part:GetPivot() or e.part.CFrame
	end
	local born = os.clock() + (delay or 0)
	local list = nil
	local rnd = Random.new()
	out = (typeof(out) == "Vector3" and out.Magnitude > 0.1) and out.Unit or Vector3.yAxis
	addEffect(function(now)
		if now < born then return true end
		if not list then
			-- the break: the halves (or the Part columns) take over from the whole plate
			list = {}
			local halves = nil
			if plate.Mesh then
				local a = kitMesh(("TR_Plate_%02d_A"):format(plate.Variant), plate.Wrap)
				local b = kitMesh(("TR_Plate_%02d_B"):format(plate.Variant), plate.Wrap)
				if a and b then halves = { a, b } end
			end
			local at = held[1].Position
			if halves then
				plate.Model:Destroy()
				for i, h in ipairs(halves) do
					meshScale(h, plate.Scale or 1)
					h:PivotTo(held[1])
					h.Parent = fxFolder()
					if plate.Own then VFXLibrary.RegisterProximityFade(h) end
					list[i] = { part = h, pivot = true, cf = held[1] }
				end
			else
				if plate.Ink then plate.Ink:Destroy() end
				for i, e in ipairs(plate.Pieces) do
					list[i] = { part = e.part, pivot = e.pivot, cf = held[i] }
				end
			end
			for _, p in ipairs(list) do
				p.base = p.part.Size
				p.v = out * rnd:NextNumber(3, 6)
					+ Vector3.new(rnd:NextNumber(-2.5, 2.5), rnd:NextNumber(2, 5), rnd:NextNumber(-2.5, 2.5))
				p.axis = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1)).Unit
				p.spin = rnd:NextNumber(4, 9)
			end
			if not plate.Own then VFXLibrary.TerraSpark(at + out * 0.3, out, 0.9, thin, wrapFx(plate, "Chips")) end
		end
		local t = now - born
		local k = t < 0.38 and 1 or 1 - (t - 0.38) / 0.2
		if k <= 0 then
			for _, p in ipairs(list) do p.part:Destroy() end
			plate.Model:Destroy()
			return false
		end
		for _, p in ipairs(list) do
			local pos = p.cf.Position + p.v * t + Vector3.new(0, -35 * t * t, 0)
			local cf = CFrame.new(pos) * p.cf.Rotation * CFrame.fromAxisAngle(p.axis, p.spin * t)
			p.part.Size = p.base * math.max(k, 0.02)
			if p.pivot then p.part:PivotTo(cf) else p.part.CFrame = cf end
		end
		return true
	end)
end
TerraFX.DropPlate = dropPlate

local INK_COL = Color3.fromRGB(17, 17, 17)

--- FULL STACK (VFX polish, 2026-09-18): the whole set's outline swells once -- a black copy of every plate, a
--- little larger and just behind it, popped out and gone in a fifth of a second. Ink, not light: it reads as the
--- armour snapping shut, for whoever is looking at this Terra.
local function inkPulse(shell)
	local copies = {}
	for _, plate in ipairs(shell.Plates) do
		for _, e in ipairs(plate.Pieces) do
			if e.crack then continue end
			local c = e.part:Clone()
			for _, ch in ipairs(c:GetChildren()) do ch:Destroy() end
			c.Color = INK_COL
			c.Parent = fxFolder()
			copies[#copies + 1] = { part = c, src = e.part, base = e.part.Size }
		end
	end
	local born = os.clock()
	addEffect(function(now)
		local t = (now - born) / 0.22
		if t >= 1 then
			for _, c in ipairs(copies) do c.part:Destroy() end
			return false
		end
		local k = 1.28 - 0.16 * t
		for _, c in ipairs(copies) do
			if c.src.Parent then
				c.part.Size = Vector3.new(c.base.X * k, c.base.Y * k, c.base.Z * 0.7)
				c.part.CFrame = c.src.CFrame * CFrame.new(0, 0, 0.22)
			end
		end
		return true
	end)
end

--- Everything on `character` comes off, newest plate first -- the reverse of how they went on.
local function clearShell(character, thin)
	local shell = shells[character]
	if not shell then return end
	shells[character] = nil
	local n = #shell.Plates
	for i = n, 1, -1 do
		local plate = shell.Plates[i]
		dropPlate(plate, plate.Out, (n - i) * 0.07, thin)
	end
end

--- Draws `stacks` plates on `character`, adding and removing them as the count moves. Called every frame by
--- the watcher below; cheap when nothing has changed.
function TerraFX.Bedrock(character, stacks, wrap)
	libs()
	local B = T.Bedrock
	local own = Players.LocalPlayer ~= nil and character == Players.LocalPlayer.Character
	local thin = not own
	if stacks <= 0 then
		clearShell(character, thin)
		return
	end
	local root = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
	if not root then
		clearShell(character, thin)
		return
	end
	local shell = shells[character]
	if not shell then
		shell = { Plates = {}, Born = os.clock(), Wrap = wrapFor(wrap, boulderKit(), own) or wrapOf(character, "Bedrock", own) }
		shells[character] = shell
	end
	-- add or drop plates to match the count
	while #shell.Plates < stacks do
		local i = #shell.Plates + 1
		shell.Plates[i] = curvedPlate(Vector3.new(1.5, 1.9, 0.42), (i % 2 == 0) and "Light" or "Base", own, i, nil, shell.Wrap)
		shell.At = os.clock()
	end
	local dropped = 0
	while #shell.Plates > stacks do
		local plate = table.remove(shell.Plates)
		dropPlate(plate, plate.Out, dropped * 0.07, thin)
		dropped += 1
		shell.Full = false
	end
	-- and place them: a ring around the chest, each plate facing out, the newest still swinging into line
	local n = #shell.Plates
	local u = math.clamp((os.clock() - (shell.At or 0)) / B.PlateTime, 0, 1)
	for i, plate in ipairs(shell.Plates) do
		local ang = (i - 1) / math.max(1, n) * math.pi * 2 + os.clock() * 0.25
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local radius = B.PlateRadius * (i == n and (0.55 + 0.45 * u) or 1)
		local at = root.Position + out * radius + Vector3.new(0, B.PlateRise, 0)
		placeRock(plate, CFrame.lookAt(at, at + out) * CFrame.Angles(0, 0, math.rad(12 * (i % 3 - 1))))
		plate.Out = out
		-- a faded plate's outline goes with it, so an owner never sees an ink silhouette of armour that
		-- is not drawn
		if plate.Own and plate.Ink then
			plate.Ink.Enabled = plate.Pieces[1].part.LocalTransparencyModifier < 0.99
		end
		-- the CLINK: the moment a plate swings home into the ring, a small hard burst off its face. Every stack
		-- gained gets its own beat. (Not for the owner: their plates are not drawn for them.)
		if not plate.Locked and (i < n or u >= 1) then
			plate.Locked = true
			if i == n and not own then
				VFXLibrary.TerraSpark(at + out * 0.3, out, 1.1, thin, wrapFx(shell, "Chips"))
			end
		end
		-- a wrap: every plate locked in lights its magma seam, brighter with the stacks (1 Low, 2-3 Mid, 4+ Max)
		plateStage(plate, plate.Locked and ((n >= 4 and "Max") or (n >= 2 and "Mid") or "Low") or nil)
	end
	if n >= B.MaxStacks and not shell.Full and shell.Plates[n].Locked then
		shell.Full = true
		if not own then inkPulse(shell) end
	end
end

--- Every character's plates, from their own attributes. Started once per client (AbilityFX).
function TerraFX.WatchBedrock()
	if TerraFX._watching then return end
	TerraFX._watching = true
	RunService.Heartbeat:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local c = plr.Character
			if c and c.Parent then
				local stacks = c:GetAttribute("Bedrock_Stacks") or 0
				if stacks > 0 or shells[c] then TerraFX.Bedrock(c, stacks) end
			end
		end
		-- and the ones that went away (2026-09-21): the sweep was forward-only, over live characters, so a Terra
		-- whose body was destroyed or swapped with stacks still up -- the round reset rebuilds it well inside
		-- Bedrock's 2.5 s lapse -- was never visited again and left her plates hanging in the FX folder
		for c in pairs(shells) do
			if not c.Parent then clearShell(c, true) end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- DEFENSE: BULWARK WALL -- the look (2026-09-19)
----------------------------------------------------------------------------------------------------
-- The kit's twelve modular slabs (TR_Wall_Slab_01..12) and three broken halves (TR_Wall_Broken_01..03), drawn over the
-- server's invisible wall body, and moved the way the kit's showcase proposed (showcase_terra.py, shot_wall):
--   WallRaise   the slabs SLAM up out of the floor from the middle outward, a course at a time, overshooting and
--               settling, rubble kicked off the base
--   WallHit     every hit: a burst and shard chips on the attacker's side of the face, and the slab nearest it cracks
--               to one of the broken halves -- it loses its top
--   WallDrop    BROKEN: one big burst across the face, hard dust low and wide, every slab toppling out and shrinking
--               away; let go (key up, an empty bar, owner gone): the slabs sink back into the floor
-- The slabs sit exactly where the imported kit placed them relative to one another, so the wall is the kit's wall.
-- No camera punch on the break (the showcase had one): the kit-wide punch/hit-stop pass is paused.
local wallFx = {}          -- [owner character] = the wall being drawn
local WALL_ROWS = 2.8      -- a course's height (build_terra_kit.py: 8.4 / 3)
local wallLayout

--- Each slab's place in the wall's own frame (X along it, Y up from its foot, -Z its front), read off the imported kit;
--- the kit's build numbers if it is not imported.
local function layoutWall()
	if wallLayout then return wallLayout end
	local kit = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local found, lo, hi = {}, Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for n = 1, 12 do
		local p = kit and kit:FindFirstChild(("TR_Wall_Slab_%02d"):format(n), true)
		if p and p:IsA("BasePart") then
			local c = p:GetPivot().Position
			found[n] = { At = c, Size = p.Size }
			lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
		end
	end
	wallLayout = {}
	if next(found) then
		local centre = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
		for n = 1, 12 do
			local f = found[n]
			if f then
				local off = f.At - centre
				wallLayout[#wallLayout + 1] = { N = n, Offset = off, Size = f.Size, Row = math.clamp(math.floor(off.Y / WALL_ROWS), 0, 2) }
			end
		end
	else
		local courses = { { 3.2, 2.8, 3.3, 2.7 }, { 1.9, 3.1, 3.0, 4.0 }, { 3.4, 2.9, 2.6, 3.1 } }
		local n = 0
		for row, widths in ipairs(courses) do
			local total, x = 0, 0
			for _, w in ipairs(widths) do total += w end
			x = -total / 2
			for _, w in ipairs(widths) do
				n += 1
				wallLayout[#wallLayout + 1] = { N = n, Offset = Vector3.new(x + w / 2, (row - 0.5) * WALL_ROWS, 0),
					Size = Vector3.new(w - 0.12, WALL_ROWS - 0.12, 1.6), Row = row - 1 }
				x += w
			end
		end
	end
	return wallLayout
end

local function wallSlab(n, size)
	local p = kitMesh(("TR_Wall_Slab_%02d"):format(n))
	if p then
		p.Parent = fxFolder()
		return p
	end
	p = inert(Instance.new("Part"))
	p.Size = size
	p.Color = COL.Base
	p.Parent = fxFolder()
	return p
end

local function wallBroken(k, width)
	local p = kitMesh(("TR_Wall_Broken_%02d"):format(k))
	if p then
		p.Parent = fxFolder()
		meshScale(p, Vector3.new(width / p:GetAttribute("BaseSize").X, 1, 1))
		return p
	end
	p = inert(Instance.new("Part"))
	p.Size = Vector3.new(width, 1.3, 1.5)
	p.Color = COL.Dark
	p.Parent = fxFolder()
	return p
end

local function outBack(u, s)
	u = math.clamp(u, 0, 1) - 1
	return 1 + (s + 1) * u * u * u + s * u * u
end

--- Everything of a wall still drawn, gone at once.
local function clearWall(character)
	local fx = wallFx[character]
	if not fx then return end
	wallFx[character] = nil
	fx.State = "Gone"
	for _, s in ipairs(fx.Slabs) do
		s.Piece:Destroy()
		if s.Broken then s.Broken:Destroy() end
	end
end

--- RAISE: the slabs slam up at `cf` (the wall's foot, facing its front) on the server's clock.
function TerraFX.WallRaise(character, cf, T0)
	wallLook[character] = newLook("TerraFX_Wall") or false
	if wallLook[character] then return wallLook[character].Raise(character, cf, nil, T0) end
	libs()
	clearWall(character)
	local B = T.BulwarkWall
	local thin = character ~= Players.LocalPlayer.Character
	-- the slabs' baked lit face (their front, -Z) is turned to THIS client's camera, as the Tomb's blast is (litToward):
	-- the slabs have no lit back, so the caster behind her own wall saw a black one (Play test, 2026-09-19). Decided once,
	-- at the raise; the wall's body, the server's, does not turn. Hits, the break and the sink all draw from this frame.
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - cf.Position):Dot(cf.LookVector) < 0 then
		cf = cf * CFrame.Angles(0, math.pi, 0)
	end
	local fx = { Character = character, CF = cf, T0 = T0, Slabs = {}, State = "Up", Thin = thin }
	wallFx[character] = fx
	for _, L in ipairs(layoutWall()) do
		local s = { L = L, Piece = wallSlab(L.N, L.Size),
			Start = B.RiseSpread * math.abs(L.Offset.X) + B.CourseLag * (2 - L.Row), Kicked = false }
		s.Home = cf * CFrame.new(L.Offset)
		s.Piece:PivotTo(s.Home - Vector3.new(0, B.RiseDepth + 2, 0))
		fx.Slabs[#fx.Slabs + 1] = s
	end
	addEffect(function()
		if wallFx[character] ~= fx or fx.State ~= "Up" then return false end
		local t = (workspace:GetServerTimeNow() - T0) * VFXLibrary.ShotTimeScale()
		local settled = true
		for _, s in ipairs(fx.Slabs) do
			if not s.Cracked then
				local u = (t - s.Start) / B.RiseTime
				local z = u < 0 and -(B.RiseDepth + 2) or -B.RiseDepth * (1 - outBack(u, 1.2))
				s.Piece:PivotTo(s.Home + Vector3.new(0, z, 0))
				if u < 1.3 then settled = false end
				if u >= 0 and not s.Kicked and s.L.Row == 0 then
					s.Kicked = true
					local foot = (cf * CFrame.new(s.L.Offset.X, 0.2, 0)).Position
					VFXLibrary.TerraDustKick(foot, cf.LookVector * (s.L.Offset.X > 0 and 1 or -1), thin)
				end
			end
		end
		-- ...and retires once they have (2026-09-21): the `or fx.State == "Up"` this used to carry was always true
		-- past the guard above, so the raise kept rewriting twelve pivots a frame for the wall's whole life. WallHit
		-- and WallDrop move the slabs themselves and do not need it alive.
		return not settled
	end)
end

--- A HIT at `point`: a burst and chips there, and the nearest whole slab cracks to a broken half.
function TerraFX.WallHit(character, point, left)
	do local nl = lookFor(wallLook, character, "TerraFX_Wall") if nl then return nl.Hit(character, point, left) end end
	libs()
	local fx = wallFx[character]
	if not (fx and fx.State == "Up" and typeof(point) == "Vector3") then return end
	local out = fx.CF:VectorToWorldSpace(Vector3.new(0, 0, fx.CF:PointToObjectSpace(point).Z < 0 and -1 or 1))
	VFXLibrary.TerraBurst(point + out * 0.4, 2.4, fx.Thin)
	VFXLibrary.TerraRockDebris(point, fx.Thin, 6, 8, out)
	local rel = fx.CF:PointToObjectSpace(point)
	local best, bestD = nil, math.huge
	for _, s in ipairs(fx.Slabs) do
		if not s.Cracked then
			local d = (Vector3.new(s.L.Offset.X, s.L.Offset.Y, 0) - Vector3.new(rel.X, rel.Y, 0)).Magnitude
			if d < bestD then best, bestD = s, d end
		end
	end
	if not best then return end
	-- the slab loses its top: a broken half, stretched to its width, standing where its foot was
	best.Cracked = true
	fx.Cracks = (fx.Cracks or 0) + 1
	best.Broken = wallBroken(1 + fx.Cracks % 3, best.L.Size.X)
	local low = best.L.Offset.Y - WALL_ROWS / 2 + 0.66
	best.Broken:PivotTo(fx.CF * CFrame.new(best.L.Offset.X, low, best.L.Offset.Z))
	best.Piece:PivotTo(best.Home - Vector3.new(0, 60, 0))      -- the whole slab is gone; the half stands in
end

--- DOWN, however it went. "Broken": the big burst and every slab toppling out; otherwise they sink back into the floor.
function TerraFX.WallDrop(character, reason)
	do local nl = lookFor(wallLook, character, "TerraFX_Wall") if nl then wallLook[character] = nil return nl.Drop(character, reason) end end
	libs()
	local fx = wallFx[character]
	if not fx then return end
	wallFx[character] = nil
	fx.State = "Gone"
	local cf, thin = fx.CF, fx.Thin
	local rnd = Random.new()
	if reason == "Broken" then
		local face = cf * CFrame.new(0, 4.2, -1.0)
		VFXLibrary.TerraBurst(face.Position, 8.5, thin)
		VFXLibrary.TerraRockDebris((cf * CFrame.new(0, 1.2, -0.8)).Position, thin, 16, 24, cf.LookVector)
		for i = 1, 10 do
			local foot = (cf * CFrame.new(rnd:NextNumber(-6, 6), 0.2, 0)).Position
			VFXLibrary.TerraDustKick(foot, cf.LookVector * (rnd:NextNumber() < 0.5 and 1 or -1), thin)
		end
		local born = os.clock()
		local moving = {}
		for _, s in ipairs(fx.Slabs) do
			for _, p in ipairs({ s.Cracked and s.Broken or s.Piece }) do
				local side = rnd:NextNumber() < 0.5 and 1 or -1
				local axis = Vector3.new(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1))
				moving[#moving + 1] = { P = p, CF = p:GetPivot(), Lag = 0.03 * (2 - s.L.Row),
					V = cf.LookVector * side * rnd:NextNumber(3, 6) + cf.RightVector * rnd:NextNumber(-2, 2)
						+ Vector3.new(0, rnd:NextNumber(2, 5), 0),
					Axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.xAxis, Spin = rnd:NextNumber(2, 4),
					Base = p:IsA("BasePart") and p.Size or nil }
			end
			if s.Cracked then s.Piece:Destroy() end
		end
		addEffect(function(now)
			local done = true
			for _, m in ipairs(moving) do
				if m.P.Parent then
					local k = math.max(0, (now - born) * VFXLibrary.ShotTimeScale() - m.Lag)
					local shrink = k < 0.45 and 1 or 1 - (k - 0.45) / 0.25
					if shrink <= 0 then
						m.P:Destroy()
					else
						done = false
						if m.Base then m.P.Size = m.Base * math.max(shrink, 0.02) end
						local pos = m.CF.Position + m.V * k + Vector3.new(0, -30 * k * k, 0)
						m.P:PivotTo(CFrame.new(pos) * CFrame.fromAxisAngle(m.Axis, m.Spin * k) * m.CF.Rotation)
					end
				end
			end
			return not done
		end)
	else
		local pieces = {}
		for _, s in ipairs(fx.Slabs) do
			pieces[#pieces + 1] = s.Cracked and s.Broken or s.Piece
			if s.Cracked then s.Piece:Destroy() end
		end
		for i = 1, 5 do
			local foot = (cf * CFrame.new(-6 + i * 2.4 - 1.2, 0.2, 0)).Position
			VFXLibrary.TerraDustKick(foot, cf.LookVector * (i % 2 == 0 and 1 or -1), thin)
		end
		local list, born = {}, os.clock()
		for _, p in ipairs(pieces) do list[#list + 1] = { P = p, CF = p:GetPivot() } end
		addEffect(function(now)
			local u = math.clamp((now - born) * VFXLibrary.ShotTimeScale() / T.BulwarkWall.SinkTime, 0, 1)
			for _, e in ipairs(list) do
				if e.P.Parent then e.P:PivotTo(e.CF - Vector3.new(0, (T.BulwarkWall.RiseDepth + 1) * u * u, 0)) end
			end
			if u >= 1 then
				for _, e in ipairs(list) do e.P:Destroy() end
				return false
			end
			return true
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: EARTHEN TOMB -- the look (v2, the redesign, 2026-09-19)
----------------------------------------------------------------------------------------------------
-- Drawn from TerraHandler's broadcasts, every beat on the server's clock (T0) at the review slow-motion's scale. It is
-- the Tomb's OWN kit (blender_scripts/terra/build_terra_tomb.py -> export/terra_kit/TerraTomb.fbx in EarthMagicMeshes),
-- nothing borrowed from Terra's other pieces -- or Parts until that is imported. Nothing fades: what goes sinks back
-- into the floor, shrinks away or breaks up.
--   TombCast     after the grip, a head of stone splinters HOMES on the target's feet -- simulated here at the server's
--                speed on the server's clock, toward wherever this client sees the target -- and lays a crack of light
--                behind it round every turn it takes. Under the target a star of light GROWS as the head closes: from
--                the lock on, "this is about to reach you", every frame.
--   TombMiss     dodged or called off: the head crumbles and the crack closes back into the floor, head first
--   TombCatch    the plinth punches up under the target and a HEAP of rocks breaks up out of its stone round them --
--                loose stones over the rim and the bottom ring first, each ring smaller and further in, the last at
--                the chest; the plinth climbs by TombRise, and Converge before the top the boulders close in
--                (v2.1, 2026-09-20: the heap replaces v2's claw)
--   TombBreak    got out: the heap is thrown off and the boulders crumble
--   TombBurst    the hero moment: the boulders meet and detonate -- the stone starburst, splinters, a Shard spray
--   TombDescend  the pillar comes down (with the target on it, or empty after an escape), then sinks into the floor
local tombFx = {}           -- [caster character] = the Tomb being drawn
-- 2026-09-20, on request: the platform has no support at all any more -- the column is gone from the mesh and the slab
-- HOVERS -- and the whole entombing structure (the slab and the heap of rocks on it) is drawn 40% bigger.
local TOMB_SCALE = 1.4      -- the entombing structure, x its built size: the slab, the heap, and the heap's layout
local PILLAR_DEPTH = 6      -- how far the slab sinks to be gone below the floor (3.5 studs thick, 4.9 at TOMB_SCALE)
-- THE HEAP (v2.1): every rock's place, in the TARGET's frame at the plinth's standing surface (LookVector their facing
-- at the catch), so the heap is built round their body whichever way they stand -- wide where their arms are, stepping
-- in toward the chest in front and behind. The bottom ring's outer faces sit on the rim; ring -1 is the loose stones
-- spilled over it. The rocks are lit from above (tops Light, every side Base), so they need no turning to a camera.
-- GENERATED by blender_scripts/terra/tomb_encase_lua.py from build_terra_tomb.encase_slots -- do not edit by hand.
-- { Shape = TR_Tomb_Rock_0n, Ring (-1 the scree), Scale, Z (studs above the standing surface), Height (studs, as
--   scaled), CF (in the target's frame at the standing surface: LookVector their facing) }
local ENCASE = {
	{ Shape = 1, Ring = 0, Scale = 1.3924, Z = 0.4038, Height = 1.3924, CF = CFrame.new(-1.4903, 0.4038, -0.3317, 0.0854, 0.0457, -0.9953, 0.1261, 0.9904, 0.0563, 0.9883, -0.1303, 0.0788) },
	{ Shape = 3, Ring = 0, Scale = 1.2205, Z = 0.3824, Height = 1.0374, CF = CFrame.new(-1.4029, 0.3824, 0.7157, 0.2796, -0.0909, -0.9558, -0.0058, 0.9953, -0.0964, 0.9601, 0.0324, 0.2777) },
	{ Shape = 4, Ring = 0, Scale = 1.3385, Z = 0.2793, Height = 1.4724, CF = CFrame.new(-0.4448, 0.2793, 1.4941, 0.924, -0.0386, -0.3803, 0.0196, 0.9984, -0.0537, 0.3818, 0.0422, 0.9233) },
	{ Shape = 1, Ring = 0, Scale = 1.1737, Z = 0.2619, Height = 1.1737, CF = CFrame.new(0.7278, 0.2619, 1.4395, 0.9489, 0.042, 0.3126, -0.0756, 0.9925, 0.096, -0.3062, -0.1148, 0.945) },
	{ Shape = 3, Ring = 0, Scale = 1.3974, Z = 0.4532, Height = 1.1878, CF = CFrame.new(1.5106, 0.4532, 0.5417, 0.3511, -0.0611, 0.9343, -0.0672, 0.9937, 0.0902, -0.9339, -0.0945, 0.3448) },
	{ Shape = 4, Ring = 0, Scale = 1.2455, Z = 0.3949, Height = 1.3701, CF = CFrame.new(1.5185, 0.3949, -0.5452, -0.2184, -0.0282, 0.9755, 0.0804, 0.9957, 0.0468, -0.9726, 0.0886, -0.2151) },
	{ Shape = 1, Ring = 0, Scale = 1.1921, Z = 0.3771, Height = 1.1921, CF = CFrame.new(0.5306, 0.3771, -1.5525, -0.9202, -0.0781, 0.3835, -0.0915, 0.9957, -0.017, -0.3805, -0.0507, -0.9234) },
	{ Shape = 3, Ring = 0, Scale = 1.3112, Z = 0.4515, Height = 1.1145, CF = CFrame.new(-0.8349, 0.4515, -1.4432, -0.9131, 0.0239, -0.4069, 0.0369, 0.999, -0.0241, 0.406, -0.037, -0.9131) },
	{ Shape = 1, Ring = 1, Scale = 1.0779, Z = 1.364, Height = 1.0779, CF = CFrame.new(-1.5492, 1.364, 0.1973, 0.3499, 0.0916, -0.9323, 0.0436, 0.9925, 0.1139, 0.9358, -0.0805, 0.3433) },
	{ Shape = 4, Ring = 1, Scale = 1.1098, Z = 1.2262, Height = 1.2208, CF = CFrame.new(-0.8439, 1.2262, 1.0992, 0.6759, 0.0399, -0.7359, 0.1221, 0.9787, 0.1652, 0.7268, -0.2015, 0.6567) },
	{ Shape = 3, Ring = 1, Scale = 1.0127, Z = 1.3298, Height = 0.8608, CF = CFrame.new(0.3915, 1.3298, 1.3559, 0.9226, -0.0525, 0.3821, -0.0067, 0.9884, 0.152, -0.3856, -0.1428, 0.9116) },
	{ Shape = 2, Ring = 1, Scale = 0.9425, Z = 1.3498, Height = 1.3666, CF = CFrame.new(1.6393, 1.3498, 0.3915, 0.3259, -0.1338, 0.9359, -0.0709, 0.9837, 0.1653, -0.9427, -0.1202, 0.3111) },
	{ Shape = 1, Ring = 1, Scale = 1.1653, Z = 1.3504, Height = 1.1653, CF = CFrame.new(1.2778, 1.3504, -0.661, -0.6817, -0.0258, 0.7312, -0.0454, 0.9989, -0.0072, -0.7303, -0.0381, -0.6821) },
	{ Shape = 4, Ring = 1, Scale = 1.1548, Z = 1.2716, Height = 1.2703, CF = CFrame.new(0.246, 1.2716, -1.3566, -0.9433, 0.1192, 0.3099, 0.1304, 0.9913, 0.0156, -0.3054, 0.0551, -0.9506) },
	{ Shape = 3, Ring = 1, Scale = 1.1573, Z = 1.3904, Height = 0.9837, CF = CFrame.new(-0.8718, 1.3904, -1.1508, -0.6035, 0.1465, -0.7838, 0.0485, 0.9879, 0.1473, 0.7959, 0.0509, -0.6033) },
	{ Shape = 4, Ring = 2, Scale = 0.7989, Z = 2.2354, Height = 0.8788, CF = CFrame.new(-0.9961, 2.2354, 0.6815, 0.7685, 0.146, -0.623, -0.0718, 0.9872, 0.1427, 0.6358, -0.0649, 0.7691) },
	{ Shape = 1, Ring = 2, Scale = 0.8236, Z = 2.1334, Height = 0.8236, CF = CFrame.new(0.2587, 2.1334, 1.2134, 0.9988, 0.0261, -0.0411, -0.0193, 0.9875, 0.1562, 0.0447, -0.1552, 0.9869) },
	{ Shape = 2, Ring = 2, Scale = 1.0066, Z = 2.2248, Height = 1.4596, CF = CFrame.new(1.6255, 2.2248, 0.4279, 0.1133, -0.0445, 0.9926, -0.1276, 0.9901, 0.0589, -0.9853, -0.1333, 0.1065) },
	{ Shape = 4, Ring = 2, Scale = 0.7972, Z = 2.317, Height = 0.8769, CF = CFrame.new(1.0019, 2.317, -0.7871, -0.7421, -0.0822, 0.6652, 0.0556, 0.9815, 0.1833, -0.6679, 0.173, -0.7238) },
	{ Shape = 1, Ring = 2, Scale = 0.8128, Z = 2.2354, Height = 0.8128, CF = CFrame.new(-0.1824, 2.2354, -1.257, -0.9345, 0.1519, -0.3219, 0.1208, 0.986, 0.1145, 0.3348, 0.0681, -0.9398) },
	{ Shape = 2, Ring = 2, Scale = 0.8035, Z = 2.2978, Height = 1.1651, CF = CFrame.new(-1.0817, 2.2978, -0.498, -0.3025, 0.0226, -0.9529, -0.0037, 0.9997, 0.0248, 0.9532, 0.011, -0.3023) },
	{ Shape = 2, Ring = 3, Scale = 0.7451, Z = 3.1305, Height = 1.0803, CF = CFrame.new(0.0362, 3.1305, 1.0529, 0.9943, -0.056, -0.0903, 0.0582, 0.9981, 0.022, 0.0889, -0.0272, 0.9957) },
	{ Shape = 4, Ring = 3, Scale = 0.6953, Z = 3.044, Height = 0.7648, CF = CFrame.new(1.5912, 3.044, 0.4257, 0.1522, 0.0249, 0.988, 0.054, 0.998, -0.0335, -0.9869, 0.0584, 0.1505) },
	{ Shape = 2, Ring = 3, Scale = 0.8246, Z = 3.0433, Height = 1.1956, CF = CFrame.new(0.6893, 3.0433, -0.8069, -0.6544, -0.0944, 0.7502, 0.009, 0.9911, 0.1325, -0.7561, 0.0935, -0.6478) },
	{ Shape = 1, Ring = 3, Scale = 0.7435, Z = 2.9178, Height = 0.7435, CF = CFrame.new(-0.6345, 2.9178, -0.9029, -0.8374, -0.057, -0.5436, -0.0791, 0.9967, 0.0173, 0.5409, 0.0575, -0.8391) },
	{ Shape = 4, Ring = 3, Scale = 0.7177, Z = 3.1719, Height = 0.7894, CF = CFrame.new(-1.356, 3.1719, 0.4253, 0.4142, 0.1212, -0.9021, -0.0593, 0.9926, 0.1061, 0.9082, 0.0095, 0.4183) },
	{ Shape = 3, Ring = -1, Scale = 0.72, Z = -0.42, Height = 0.612, CF = CFrame.new(-2.0182, -0.42, 0.0855, -0.1336, -0.4653, -0.875, 0, 0.8829, -0.4695, 0.991, -0.0627, -0.1179) },
	{ Shape = 4, Ring = -1, Scale = 0.66, Z = -0.5, Height = 0.726, CF = CFrame.new(0.1465, -0.5, 2.0448, 0.9698, 0.1144, 0.2152, 0, 0.8829, -0.4695, -0.2437, 0.4553, 0.8563) },
	{ Shape = 3, Ring = -1, Scale = 0.7, Z = -0.4, Height = 0.595, CF = CFrame.new(1.98, -0.4, -0.0014, -0.243, 0.4554, 0.8565, 0, 0.8829, -0.4695, -0.97, -0.1141, -0.2145) },
	{ Shape = 4, Ring = -1, Scale = 0.62, Z = -0.48, Height = 0.682, CF = CFrame.new(-0.0616, -0.48, -2.0591, -0.9609, 0.13, 0.2444, 0, 0.8829, -0.4695, -0.2768, -0.4511, -0.8484) },
}

--- A rock breaking out of the stone: fast, easing into ~7% past its place by 65% of the way, then settling back.
local function punchCurve(u)
	u = math.clamp(u, 0, 1)
	if u < 0.65 then
		return 1.07 * (1 - (1 - u / 0.65) ^ 2)
	end
	local k = (u - 0.65) / 0.35
	return 1.07 - 0.07 * (k * k * (3 - 2 * k))
end

local function tombClock(T0)
	return (workspace:GetServerTimeNow() - (T0 or 0)) * VFXLibrary.ShotTimeScale()
end

local function flatUnit(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or (fallback or Vector3.zAxis)
end

local tombRay = RaycastParams.new()
tombRay.FilterType = Enum.RaycastFilterType.Exclude

--- The floor under `p` on this client (characters, `skip` and the FX folder are not floor), or `p` itself.
local function floorAt(p, skip)
	local list = { fxFolder() }
	if skip then list[#list + 1] = skip end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then list[#list + 1] = pl.Character end
	end
	tombRay.FilterDescendantsInstances = list
	local hit = workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, -24, 0), tombRay)
	return hit and hit.Position or p
end

local function tombPart(size, tone, parent, cf, shape)
	local p = inert(Instance.new("Part"))
	if shape then p.Shape = shape end
	p.Size = size
	p.Color = COL[tone]
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- The Part stand-ins, each a Model pivoted where its kit piece is (the plinth at the middle of its standing surface, a
-- rock at its middle, ground pieces at their middle on the floor), all facing -Z.
local function partModel(build)
	local m = Instance.new("Model")
	build(m)
	m.WorldPivot = CFrame.new()
	m.Parent = fxFolder()
	return m
end

local function partPlinth()
	return partModel(function(m)
		tombPart(Vector3.new(4.2, 16.5, 4.2), "Base", m, CFrame.new(0, -8.25, 0))
		tombPart(Vector3.new(4.9, 0.6, 4.9), "Light", m, CFrame.new(0, -0.3, 0))
	end)
end

local function partRock()
	local p = tombPart(Vector3.new(1.1, 1.0, 1.0), "Base", fxFolder(), CFrame.new())
	p:SetAttribute("BaseSize", p.Size)          -- scalePiece scales from it every frame, not from last frame's size
	return p
end

local function partCrack()
	return partModel(function(m)
		tombPart(Vector3.new(1.0, 0.1, 1.5), "Dark", m, CFrame.new(0, 0.05, 0))
		tombPart(Vector3.new(0.35, 0.12, 1.5), "Light", m, CFrame.new(0, 0.09, 0))
	end)
end

local function partHead()
	return partModel(function(m)
		tombPart(Vector3.new(0.6, 2.6, 0.5), "Light", m, CFrame.new(0, 1.0, 0) * CFrame.Angles(math.rad(-26), 0, 0))
		for s = -1, 1, 2 do
			tombPart(Vector3.new(0.5, 1.9, 0.4), "Base", m, CFrame.new(s * 0.6, 0.7, 0.3)
				* CFrame.Angles(math.rad(-18), 0, math.rad(-s * 22)))
		end
	end)
end

local function partMark()
	return partModel(function(m)
		tombPart(Vector3.new(0.05, 2, 2), "Light", m, CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	end)
end

local function partBoulder()
	return tombPart(Vector3.new(1.0, 0.85, 0.8), "Base", fxFolder(), CFrame.new())
end

local function partShard()
	return tombPart(Vector3.new(0.45, 0.9, 0.35), "Light", fxFolder(), CFrame.new())
end

local function partBlast()
	return partModel(function(m)
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			tombPart(Vector3.new(0.9, 0.9, 5), "Light", m, CFrame.Angles(math.sin(i) * 0.5, a, 0) * CFrame.new(0, 0, -3))
		end
		tombPart(Vector3.new(2.2, 2.2, 2.2), "Base", m, CFrame.new())
	end)
end

local function tombPiece(name, fallback)
	local p = kitMesh(name)
	if p then
		p.Parent = fxFolder()
		return p
	end
	return fallback()
end

--- Resizes a Tomb piece to `k` x its imported size about its PIVOT (a kit mesh's size is about its box's middle, so
--- its pivot offset is scaled with it); a Part stand-in scales as a model, uniformly.
local function scalePiece(p, k)
	if p:IsA("BasePart") then
		local base = p:GetAttribute("BasePivot")
		if not base then
			base = p.PivotOffset
			p:SetAttribute("BasePivot", base)
		end
		meshScale(p, k)
		local s = typeof(k) == "Vector3" and k or Vector3.new(k, k, k)
		p.PivotOffset = CFrame.new(base.Position * s) * base.Rotation
	else
		p:ScaleTo(math.max(0.02, typeof(k) == "Vector3" and k.X or k))
	end
end

--- Sends pieces down into the floor over `time` and removes them: how a Terra piece leaves.
local function sinkAway(pieces, time, depth)
	local list = {}
	for _, p in ipairs(pieces) do
		if p and p.Parent then list[#list + 1] = { P = p, CF = p:GetPivot() } end
	end
	if #list == 0 then return end
	local born = os.clock()
	addEffect(function(now)
		local u = math.clamp((now - born) / time, 0, 1)
		for _, e in ipairs(list) do
			if e.P.Parent then e.P:PivotTo(e.CF - Vector3.new(0, depth * u * u, 0)) end
		end
		if u >= 1 then
			for _, e in ipairs(list) do e.P:Destroy() end
			return false
		end
		return true
	end)
end

--- Shrinks a piece away to nothing where it stands over `time`, and removes it.
local function shrinkAway(p, time)
	if not (p and p.Parent) then return end
	local born = os.clock()
	local isPart = p:IsA("BasePart")
	local s0 = isPart and p.Size or p:GetScale()
	local cf = p:GetPivot()
	addEffect(function(now)
		if not p.Parent then return false end
		local u = math.clamp((now - born) / time, 0, 1)
		if u >= 1 then
			p:Destroy()
			return false
		end
		local k = math.max(0.02, 1 - u * u)
		if isPart then p.Size = s0 * k else p:ScaleTo(s0 * k) end
		p:PivotTo(cf)
		return true
	end)
end

--- The crack closes back into the floor, from the head end to Terra's.
local function closeCrack(segments, delay)
	local n = #segments
	for i, s in ipairs(segments) do
		task.delay((delay or 0) + (n - i) * 0.012, function() sinkAway({ s.Piece }, 0.22, 0.9) end)
	end
end

--- Everything of a Tomb's still standing, gone at once (a new cast by the same caster, or a caster who left).
function TerraFX.TombEnd(character)
	do local nl = lookFor(tombLook, character, "TerraFX_Tomb") if nl then tombLook[character] = nil return nl.End(character) end end
	local fx = tombFx[character]
	if not fx then return end
	tombFx[character] = nil
	fx.State = "Gone"
	for _, s in ipairs(fx.Segments or {}) do s.Piece:Destroy() end
	for _, k in ipairs({ "Head", "Mark", "Plinth" }) do
		if fx[k] then fx[k]:Destroy() end
	end
	for _, r in ipairs(fx.Rocks or {}) do r.Piece:Destroy() end
	for _, b in ipairs(fx.Boulders or {}) do b.Piece:Destroy() end
end

--- CAST: the lock is on `victim`; after `grip`, the fissure leaves `from` (Terra's feet) and homes on them at `speed`.
function TerraFX.TombCast(character, victim, from, T0, grip, speed, reach)
	tombLook[character] = newLook("TerraFX_Tomb") or false
	if tombLook[character] then return tombLook[character].Cast(character, victim, from, T0, grip, speed, reach) end
	libs()
	TerraFX.TombEnd(character)
	local E = T.EarthenTomb
	local vroot = victim and victim:FindFirstChild("HumanoidRootPart")
	if not (vroot and typeof(from) == "Vector3") then return end
	local thin = character ~= Players.LocalPlayer.Character
	local fx = { Character = character, Victim = victim, State = "Cast", Segments = {}, T0 = T0, Thin = thin,
		Grip = grip or E.GripTime, Speed = speed or E.FissureSpeed, Reach = reach or E.CatchReach,
		HeadAt = from, Last = from, Dir = flatUnit(vroot.Position - from), Sim = 0 }
	fx.StartDist = math.max(1, Vector3.new(vroot.Position.X - from.X, 0, vroot.Position.Z - from.Z).Magnitude)
	tombFx[character] = fx
	fx.Head = tombPiece("TR_Tomb_CrackHead", partHead)
	fx.Head:PivotTo(CFrame.new(from - Vector3.new(0, 6, 0)))       -- under the floor until the grip lands
	fx.Mark = tombPiece("TR_Tomb_Mark", partMark)
	fx.Goal = floorAt(vroot.Position, victim)
	fx.Mark:PivotTo(CFrame.new(fx.Goal - Vector3.new(0, 6, 0)))
	addEffect(function()
		if tombFx[character] ~= fx or fx.State ~= "Cast" then return false end
		local t = tombClock(T0)
		local vr = victim.Parent and victim:FindFirstChild("HumanoidRootPart")
		if vr then fx.Goal = floorAt(vr.Position, victim) end
		local goal = fx.Goal
		-- the head, stepped forward to the fissure's own clock -- so a broadcast that arrives late catches up in one go
		local want = math.clamp(t - fx.Grip, 0, E.MaxTravel)
		local moved = false
		while fx.Sim < want - 1e-4 do
			local dt = math.min(1 / 60, want - fx.Sim)
			fx.Sim += dt
			local to = Vector3.new(goal.X - fx.HeadAt.X, 0, goal.Z - fx.HeadAt.Z)
			local dist = to.Magnitude
			if dist <= fx.Reach then break end
			fx.Dir = to.Unit
			fx.HeadAt += fx.Dir * math.min(fx.Speed * dt, dist - fx.Reach)
			moved = true
		end
		if moved then fx.HeadAt = floorAt(fx.HeadAt, victim) end
		if t >= fx.Grip then
			-- the crack, laid SegmentEvery behind the head wherever it has been, each piece heaved up out of the floor
			while true do
				local gap = Vector3.new(fx.HeadAt.X - fx.Last.X, 0, fx.HeadAt.Z - fx.Last.Z)
				if gap.Magnitude < E.SegmentEvery then break end
				local d = gap.Unit
				local nextAt = fx.Last + d * E.SegmentEvery
				local mid = floorAt((fx.Last + nextAt) / 2, victim)
				local i = #fx.Segments + 1
				local piece = tombPiece(("TR_Tomb_Crack_%02d"):format(1 + i % 2), partCrack)
				local cf = CFrame.lookAt(mid, mid + d) * CFrame.Angles(0, (i % 2 == 0) and math.pi or 0, 0)
				piece:PivotTo(cf - Vector3.new(0, 0.6, 0))
				fx.Segments[i] = { Piece = piece, CF = cf, Born = t }
				if i % 3 == 1 then VFXLibrary.TombGrit(mid, -d, thin) end
				fx.Last = Vector3.new(nextAt.X, mid.Y, nextAt.Z)
			end
			for _, s in ipairs(fx.Segments) do
				if not s.Up then
					local k = math.clamp((t - s.Born) / 0.06, 0, 1)
					s.Piece:PivotTo(s.CF - Vector3.new(0, 0.6 * (1 - k), 0))
					s.Up = k >= 1
				end
			end
			fx.Head:PivotTo(CFrame.lookAt(fx.HeadAt, fx.HeadAt + fx.Dir))
		end
		-- THE WARNING under the target: it grows from MarkFrom to MarkTo studs across as the head closes, and shivers
		local left = Vector3.new(goal.X - fx.HeadAt.X, 0, goal.Z - fx.HeadAt.Z).Magnitude
		local close = 1 - math.clamp((left - fx.Reach) / math.max(1, fx.StartDist - fx.Reach), 0, 1)
		local across = (E.MarkFrom + (E.MarkTo - E.MarkFrom) * close ^ 0.8) * (1 + 0.06 * math.sin(t * 38))
		scalePiece(fx.Mark, Vector3.new(across / 2, 1, across / 2))
		fx.Mark:PivotTo(CFrame.new(goal + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, t * 0.8, 0))
		if t > fx.Grip + E.MaxTravel + 1.0 then TerraFX.TombMiss(character) end   -- the verdict never came
		return true
	end)
end

--- DODGED (or called off): the head crumbles where it stopped and the crack closes back into the floor.
function TerraFX.TombMiss(character, at)
	do local nl = lookFor(tombLook, character, "TerraFX_Tomb") if nl then return nl.Miss(character, at) end end
	libs()
	local fx = tombFx[character]
	if not fx then return end
	if fx.State ~= "Cast" then
		-- the server broadcasts TombMiss from whatever phase its error recovery ran in, and this used to return
		-- and do nothing (2026-09-21): the plinth, the heap and the boulders were left in the FX folder being
		-- pivoted every frame for the rest of the session. TombEnd clears a Tomb from any phase.
		TerraFX.TombEnd(character)
		return
	end
	tombFx[character] = nil
	fx.State = "Gone"
	local tip = typeof(at) == "Vector3" and at or fx.HeadAt
	VFXLibrary.TombGrit(tip + Vector3.new(0, 0.3, 0), Vector3.yAxis, fx.Thin, 10)
	sinkAway({ fx.Head }, 0.25, 3)
	shrinkAway(fx.Mark, 0.18)
	closeCrack(fx.Segments)
end

--- CATCH: the plinth erupts under the target at `at`, its lit side turned along `face` (toward Terra), and climbs.
function TerraFX.TombCatch(character, victim, at, face, T0, rise, height)
	do local nl = lookFor(tombLook, character, "TerraFX_Tomb") if nl then return nl.Catch(character, victim, at, face, T0, rise, height) end end
	libs()
	local E = T.EarthenTomb
	local fx = tombFx[character]
	if not fx then
		fx = { Character = character, Segments = {}, Thin = character ~= Players.LocalPlayer.Character }
		tombFx[character] = fx
	end
	if typeof(at) ~= "Vector3" then return end
	local thin = fx.Thin
	fx.State, fx.CatchT0, fx.Rise, fx.Height, fx.Victim, fx.H = "Rise", T0, rise, height, victim, 0
	if fx.Head then
		fx.Head:Destroy()                  -- it reached them: the head becomes the eruption
		fx.Head = nil
	end
	if fx.Mark then
		shrinkAway(fx.Mark, 0.12)
		fx.Mark = nil
	end
	closeCrack(fx.Segments, 0.35)
	fx.Segments = {}
	fx.BaseCF = CFrame.lookAt(at, at + flatUnit(typeof(face) == "Vector3" and face or Vector3.zAxis))
	fx.Plinth = tombPiece("TR_Tomb_Plinth", partPlinth)
	scalePiece(fx.Plinth, TOMB_SCALE)
	-- the heap is laid round the target's own body: the facing the server turns them to at the catch, which is the
	-- one it ships as `face`. Sampling the victim's own root here (2026-09-21) raced that turn -- the AlignOrientation
	-- was still swinging them round -- so the heap sat across the chest instead of the arms, at a different angle on
	-- every client, and pointed a different way from the plinth.
	fx.Facing = fx.BaseCF.LookVector
	fx.Rocks, fx.RingsUp = {}, {}
	local jitter = Random.new()
	for i, slot in ipairs(ENCASE) do
		local piece = tombPiece(("TR_Tomb_Rock_%02d"):format(slot.Shape), partRock)
		scalePiece(piece, slot.Scale * TOMB_SCALE * 0.6)
		piece:PivotTo(fx.BaseCF - Vector3.new(0, 40, 0))            -- under the floor until its turn
		local axis = Vector3.new(jitter:NextNumber(-1, 1), jitter:NextNumber(-1, 1), jitter:NextNumber(-1, 1))
		fx.Rocks[i] = { Piece = piece, Slot = slot,
			Start = E.EncaseEruptAt + math.max(slot.Ring, 0) * E.EncaseRingLag + jitter:NextNumber(0, E.EncaseJitter),
			-- from under the plinth's top at its own spot (its top 0.3 below the surface), whatever its ring
			Travel = TOMB_SCALE * math.max(slot.Z + slot.Height / 2 + 0.3, slot.Height + 0.3),
			-- its place in the heap, moved out and up with the rest of the structure
			Rel = CFrame.new(slot.CF.Position * TOMB_SCALE) * slot.CF.Rotation,
			Axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.xAxis }
	end
	fx.HeapUpAt = E.EncaseEruptAt + 3 * E.EncaseRingLag + E.EncaseJitter + E.EncaseEruptTime
	fx.Boulders = {}
	VFXLibrary.TombGrit(at + Vector3.new(0, 0.3, 0), Vector3.yAxis, thin, 18)
	local rnd = Random.new()
	local mine = victim == Players.LocalPlayer.Character
	addEffect(function()
		if tombFx[character] ~= fx or fx.State == "Gone" then return false end
		local t = tombClock(fx.CatchT0)
		local h
		if fx.State == "Descent" then
			local u = math.clamp(tombClock(fx.DescT0) / fx.DescTime, 0, 1)
			h = fx.DescFrom * (1 - u * u)
			if u >= 1 then
				-- down; now on into the floor, with any rocks still on it
				tombFx[character] = nil
				fx.State = "Gone"
				local pieces = { fx.Plinth }
				for _, r in ipairs(fx.Rocks) do pieces[#pieces + 1] = r.Piece end
				sinkAway(pieces, 0.4, PILLAR_DEPTH)
				return false
			end
		else
			h = height * TerraFX.TombRise(t / rise)
		end
		fx.H = h
		-- THE ERUPTION: the plinth punches up out of the floor over its first 0.1 s...
		local punch = (1 - math.clamp(t / 0.1, 0, 1)) ^ 2
		local base = fx.BaseCF + Vector3.new(0, h - 5 * punch, 0)
		fx.Plinth:PivotTo(base)
		-- ...and THE HEAP breaks up out of its stone round the target: each rock punched up from under the top at its own
		-- spot, through the rocks already up, tumbling into its place; grit as each ring breaks out, and more at the chest
		-- when the last is in
		local frame = CFrame.lookAt(base.Position, base.Position + fx.Facing)
		for _, r in ipairs(fx.Rocks) do
			local u = (t - r.Start) / E.EncaseEruptTime
			if r.Up then
				r.Piece:PivotTo(frame * r.Rel)
			elseif u < 0 then
				r.Piece:PivotTo(frame * CFrame.new(0, -r.Travel, 0) * r.Rel)           -- waiting inside the stone
			else
				local p = punchCurve(u)
				scalePiece(r.Piece, r.Slot.Scale * TOMB_SCALE * (0.6 + 0.4 * math.clamp(u / 0.5, 0, 1)))
				r.Piece:PivotTo(frame * CFrame.new(0, -r.Travel * (1 - p), 0) * r.Rel
					* CFrame.fromAxisAngle(r.Axis, (1 - math.min(p, 1)) * 0.7))
				r.Up = u >= 1
				local ring = r.Slot.Ring
				if ring >= 0 and not fx.RingsUp[ring] then
					fx.RingsUp[ring] = true
					VFXLibrary.TombGrit(base.Position + Vector3.new(0, r.Slot.Z * TOMB_SCALE, 0), Vector3.yAxis, thin, 5)
				end
			end
		end
		if t >= fx.HeapUpAt and not fx.Slammed then
			fx.Slammed = true
			VFXLibrary.TombGrit(base.Position + Vector3.new(0, 3.4, 0), Vector3.yAxis, thin, 10)
		end
		-- THE CONVERGENCE: eight boulders close on the target's chest from every side, Converge before the top
		local tc = rise - E.Converge
		local chest = base.Position + Vector3.new(0, 3.2, 0)
		if t >= tc and fx.State == "Rise" and #fx.Boulders == 0 then
			for i = 1, 8 do
				local d = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-0.3, 0.8), rnd:NextNumber(-1, 1))
				d = d.Magnitude > 0.1 and d.Unit or Vector3.yAxis
				local piece = tombPiece(("TR_Tomb_Boulder_%02d"):format(1 + i % 3), partBoulder)
				scalePiece(piece, rnd:NextNumber(1.8, 2.5))
				local axis = d:Cross(Vector3.yAxis)
				fx.Boulders[i] = { Piece = piece, Dir = d, Spin = rnd:NextNumber(3, 7),
					Axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.xAxis }
			end
		end
		if fx.State == "Rise" then
			local e = math.clamp((t - tc) / E.Converge, 0, 1)
			for _, b in ipairs(fx.Boulders) do
				local r = 13 * (1 - e * e) + (mine and 3.2 or 1.9)     -- your own chest: they stop short of your eyes
				b.Piece:PivotTo(CFrame.new(chest + b.Dir * r) * CFrame.fromAxisAngle(b.Axis, b.Spin * t))
			end
		end
		-- the verdict never came: the same watchdog the cast loop carries, which this one was missing (2026-09-21).
		-- The descent retires itself, but a Tomb left standing in Rise or Broken -- a caster who left, a teardown
		-- broadcast whose Character had already replicated away -- had nothing that could ever end it.
		if fx.State ~= "Descent" and t > rise + E.BurstHold + E.DescendTime + 1.5 then
			TerraFX.TombEnd(character)
			return false
		end
		return true
	end)
end

--- The heap thrown off: every rock still on the plinth flies out from its middle and up from where it is (`power` x),
--- tumbling, and shrinks away -- the pillar is left bare under the target.
local function blowRocks(fx, power)
	local rocks = fx.Rocks or {}
	fx.Rocks = {}
	local centre = fx.Plinth and fx.Plinth.Parent and fx.Plinth:GetPivot().Position
	local rnd = Random.new()
	local list = {}
	for _, r in ipairs(rocks) do
		if r.Piece.Parent then
			local cf = r.Piece:GetPivot()
			local out = centre and flatUnit(cf.Position - centre, Vector3.xAxis) or Vector3.xAxis
			local axis = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1))
			list[#list + 1] = { P = r.Piece, CF = cf, S = r.Slot.Scale * TOMB_SCALE, Spin = rnd:NextNumber(5, 11),
				Axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.xAxis,
				V = (out * rnd:NextNumber(10, 18) + Vector3.new(0, rnd:NextNumber(4, 12), 0)) * power }
		end
	end
	if #list == 0 then return end
	local life = T.EarthenTomb.EncaseBlowLife
	local born = os.clock()
	addEffect(function(now)
		local t = (now - born) * VFXLibrary.ShotTimeScale()
		if t >= life then
			for _, e in ipairs(list) do
				if e.P.Parent then e.P:Destroy() end
			end
			return false
		end
		local k = 1 - math.clamp((t - 0.35) / (life - 0.35), 0, 1)
		for _, e in ipairs(list) do
			if e.P.Parent then
				scalePiece(e.P, e.S * math.max(0.02, k))
				e.P:PivotTo(CFrame.new(e.CF.Position + e.V * t + Vector3.new(0, -17.5 * t * t, 0))
					* CFrame.fromAxisAngle(e.Axis, e.Spin * t) * e.CF.Rotation)
			end
		end
		return true
	end)
end

--- GOT OUT: the heap is thrown off (gentler than the burst's) and the boulders crumble where they are.
function TerraFX.TombBreak(character, reason)
	do local nl = lookFor(tombLook, character, "TerraFX_Tomb") if nl then return nl.Break(character, reason) end end
	libs()
	local fx = tombFx[character]
	if not (fx and fx.Rocks) then return end
	blowRocks(fx, 0.7)
	for _, b in ipairs(fx.Boulders or {}) do
		if b.Piece.Parent then VFXLibrary.TombGrit(b.Piece:GetPivot().Position, Vector3.yAxis, true, 3) end
		shrinkAway(b.Piece, 0.2)
	end
	fx.Boulders = {}
	if fx.Plinth then VFXLibrary.TombGrit(fx.Plinth:GetPivot().Position + Vector3.new(0, 1, 0), Vector3.yAxis, fx.Thin, 12) end
	fx.State = "Broken"
end

-- The kit bakes its three bands against one key light, fixed in each piece's own frame: up and toward its LookVector
-- (build_terra_kit.py KEY (0.30, -0.45, 0.84), carried into the pivot frame the import fix sets). The detonation is
-- turned so that lit side faces THIS client's camera -- a starburst any other way round shows its Dark side to someone,
-- and the first recording showed exactly that. It spins about the key, so it stays lit while it turns.
local KIT_KEY = Vector3.new(-0.30, 0.84, -0.45).Unit
local function litToward(at, eye)
	local look = CFrame.lookAt(at, eye)
	local toward = Vector3.new(0, 0, -1)
	local axis = KIT_KEY:Cross(toward)
	local angle = math.acos(math.clamp(KIT_KEY:Dot(toward), -1, 1))
	return axis.Magnitude > 1e-4 and look * CFrame.fromAxisAngle(axis.Unit, angle) or look
end

--- The detonation: the stone starburst popped at `at`, `size` x its mesh, held, then shrunk to nothing.
local function blast(at, size)
	local p = tombPiece("TR_Tomb_Blast", partBlast)
	local born = os.clock()
	local cam = workspace.CurrentCamera
	local spin0 = math.random() * 6.28
	addEffect(function(now)
		if not p.Parent then return false end
		local t = (now - born) * VFXLibrary.ShotTimeScale()
		local k
		if t < 0.07 then
			k = 0.35 + 0.65 * (t / 0.07)
		elseif t < 0.17 then
			k = 1
		elseif t < 0.5 then
			local u = (t - 0.17) / 0.33
			k = 1 - u * u
		else
			p:Destroy()
			return false
		end
		scalePiece(p, size * math.max(0.02, k))
		local eye = cam and cam.CFrame.Position or (at + Vector3.new(0, 0, 10))
		p:PivotTo(litToward(at, eye) * CFrame.fromAxisAngle(KIT_KEY, spin0 + t * 0.9))
		return true
	end)
end

--- The splinters the detonation throws: out and up, tumbling, falling, shrinking away.
local function throwShards(at, thin)
	local n = math.max(3, math.floor(12 * (Settings.EffectDensity or 1) * ((thin and Settings.ThinEnemyVFX) and 0.5 or 1) + 0.5))
	local rnd = Random.new()
	for i = 1, n do
		local p = tombPiece(("TR_Tomb_Shard_%02d"):format(1 + i % 3), partShard)
		local s = rnd:NextNumber(1.2, 1.9)
		scalePiece(p, s)
		local a = i / n * math.pi * 2 + rnd:NextNumber(-0.25, 0.25)
		local v = Vector3.new(math.cos(a), 0, math.sin(a)) * rnd:NextNumber(26, 42) + Vector3.new(0, rnd:NextNumber(6, 18), 0)
		local axis = Vector3.new(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1))
		axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.xAxis
		local spin, born, pos = rnd:NextNumber(6, 14), os.clock(), at
		addEffect(function(now)
			if not p.Parent then return false end
			local t = (now - born) * VFXLibrary.ShotTimeScale()
			if t >= 0.7 then
				p:Destroy()
				return false
			end
			local here = pos + v * t + Vector3.new(0, -35 * t * t, 0)
			if t > 0.4 then scalePiece(p, s * math.max(0.02, 1 - (t - 0.4) / 0.3)) end
			p:PivotTo(CFrame.new(here) * CFrame.fromAxisAngle(axis, spin * t))
			return true
		end)
	end
end

--- BURST: the hero moment -- the boulders meet and detonate, bigger than the body they break on.
function TerraFX.TombBurst(character, position, hit)
	do local nl = lookFor(tombLook, character, "TerraFX_Tomb") if nl then return nl.Burst(character, position, hit) end end
	libs()
	local E = T.EarthenTomb
	local fx = tombFx[character]
	local local_ = Players.LocalPlayer.Character
	local mine = fx ~= nil and fx.Victim == local_
	if fx then
		for _, b in ipairs(fx.Boulders or {}) do b.Piece:Destroy() end
		fx.Boulders = {}
		fx.State = "Hold"
		blowRocks(fx, 1)                                  -- the heap blown off by it
	end
	if typeof(position) ~= "Vector3" then return end
	local thin = character ~= local_
	local at = position + Vector3.new(0, 0.4, 0)
	local size = E.BlastScale
	local cam = workspace.CurrentCamera
	if mine and cam then
		-- your own, in front of your eyes and smaller: a starburst round your head is the inside of its ink
		at = cam.CFrame.Position + cam.CFrame.LookVector * 9
		size *= 0.45
	end
	if Settings.Get and Settings.Get("ReduceFlashing") then size *= 0.75 end
	if thin and Settings.ThinEnemyVFX then size *= 0.85 end
	blast(at, size)
	throwShards(position + Vector3.new(0, 0.6, 0), thin)
	VFXLibrary.TombShatter(position, thin)
end

--- DESCENT: the pillar comes down from `from` studs over `time` (with the target on it, or empty), then sinks away.
function TerraFX.TombDescend(character, T0, time, from)
	do local nl = lookFor(tombLook, character, "TerraFX_Tomb") if nl then return nl.Descend(character, T0, time, from) end end
	libs()
	local fx = tombFx[character]
	if not fx then return end
	if fx.State == "Cast" then
		TerraFX.TombMiss(character)
		return
	end
	fx.State, fx.DescT0, fx.DescTime, fx.DescFrom = "Descent", T0, math.max(0.05, time or 0.5), fx.H or from or 0
end

----------------------------------------------------------------------------------------------------
-- MOBILITY: AFTERSHOCK -- the look (2026-09-25)
----------------------------------------------------------------------------------------------------
-- It REPLACES Tremor Vault's look (VaultSink / VaultPop, deleted with the ability rather than disabled -- the Glacial
-- Spikes precedent; the TerraVault meshes stay in the place, unreferenced). Built in Blender first
-- (blender_scripts/terra/aftershock_bl.py) and brought in to vfx_blocking/terra/aftershock/PORT_SPEC.md. Drawn from
-- TerraHandler's broadcasts, for every client the caster's own included, on the SERVER's clock: t = (GetServerTimeNow() -
-- T0) x ShotTimeScale; the windup and the slam run on `sim` = AftershockClock(t), which HOLDS the contact frame
-- HoldFrames/60 s (the hitpause); the ring runs on tau = AftershockRingTau(t) -- the expression TerraHandler hits on, so
-- the drawn front and the hits agree. The beats:
--   WINDUP     the ground thumping at each of her feet on every Beats[k]
--   THE SLAM   at sim Hit: the dome of dust and its skirt, grit thrown, the crater's scuff -- and every emitter of the cast
--              stopped (TimeScale 0) through the hold, so the first puffs freeze with the pose, as the film's do
--   THE RING   the TerraAftershock kit's 162 ground plates, laid exactly as the film's Ground (one fixed layout, turned
--              to a yaw seeded by the server, so casts don't repeat), each hidden until the front's skin reaches it and
--              then posed by Ground.slab_matrix's own law -- the bulge that lifts and rocks it as the front runs under it,
--              the heave and tilt it keeps, the crater's plates driven down -- over a dark underlay that follows the
--              skin, so the cracks between them read open; ~80 rocks driven up out of the floor along the front and flown
--              by script; the travelling wall of dust
--   AFTERMATH  the scar held Scar s; then the plates and the rubble sink into the floor while the cracks fill (the
--              underlay, left at the floor, takes the crust's colour over HealDelay, then fades over Heal -- the film's
--              void filling and the ground healing), the scuff fades, and the plates go back to their pool
-- A FLOOR CANNOT BE CUT, so the broken ground is a crust laid OVER it (PlateLift) with the dark underlay just under the
-- crust's top: the plates are the ground, the underlay the gaps between them. What the crust cannot do is go DOWN: the
-- crater's plates, driven down CraterDepth as the film's are, go under the real floor, and the crater reads as the dark
-- of the underlay with the scuff over it.
-- THE CAMERA: somebody else's slam shakes this client's camera by its distance (Viewmodel.Shake, which the Camera Shake
-- setting scales and Reduce Flashing takes away); the caster's own shake is SpellshotInput's, on the local clock from the
-- key, so it is not doubled here.
local AS = {
	Kit = "TerraAftershock",            -- ReplicatedStorage.EarthMagicMeshes.TerraAftershock (imported by the integrator)
	Data = "AftershockKitData",         -- ReplicatedStorage.Spellshot.AftershockKitData (GENERATED by aftershock_kit_export.py)
	-- The kit's +Z is the caster's forward in the film (Blender +Y; the importer lands Blender (x, y, z) as (-x, z, y)), so
	-- half a turn about up carries it onto a cast frame whose LookVector is her facing -- the M1 kit's turn. TO BE
	-- CONFIRMED at the import: tools/terra_aftershock_kit_setup.lua prints plate offsets to check against the data's C.
	Turn = CFrame.Angles(0, math.pi, 0),
	PoolMax = 2,                        -- plate sets kept for reuse: two Terras at once never clone 162 plates mid-fight
	-- MeshPart.Color MULTIPLIES the kit's vertex colours: the plates' white tops take this earth; their baked soil walls
	-- come out a darker soil. (SmoothPlastic: whether vertex colours survive another material is untested.)
	PlateTop = Color3.fromRGB(136, 117, 94),
	Void = Color3.fromRGB(38, 28, 19),  -- the dark underlay: the film's VOID
	Stone = Color3.fromRGB(133, 115, 94),     -- the Part fallback's rock (the film's STONE; the kit's rocks are baked)
	PlateSink = 0.6,                    -- the settle takes the plates this far below PlateLift: under the floor, gone
	UnderThick = 0.04,
	-- (2026-09-25) THE UNDERLAY'S BAND. The underlay is ONE flat disc at the centre's floor + 0.03, so nothing drawn may
	-- sit under its top: a plate (or a rock) whose own floor lies up to this far BELOW the centre's is rested at the
	-- centre's floor instead (the crust bridges a seam or a small step -- its 0.9-deep walls still reach its own floor),
	-- and one lower than that is not drawn, the underlay stopping short of it (see asPlates). PlateTolerance still
	-- bounds a floor ABOVE the centre's (the disc lies hidden under that). EVERY NUMBER HERE IS A PROPOSAL.
	PlateSnap = 0.25,
	ProbeCap = 24,                      -- plate floor probes a frame at most (a late join's first frame would do all 162)
	Late = 0.35,                        -- a one-shot beat this late (a late join) is skipped rather than fired
	RockLate = 0.6,                     -- ...and a rock this long after its eruption
	FPThin = 0.3,                       -- first person: the slam's dust sits at the lens, drawn at this share
	RowStep = 2.4,                      -- studs between the rings of eruptions (the film's 1.5 at four times the rock)
	FrontDensity = 0.055,               -- the front's dust: puffs a square stud it sweeps (the film's 0.22, a quarter)
	FeetKick = 4,                       -- Kick puffs at each foot on the last beat (the film's 6, the first beats fewer)
	SlamGrit = 20,                      -- flown grit off the slam (the film's 60)
	StrikeUp = 18, StrikeOut = 8, StrikeBack = 1.3, StrikeDecay = 0.12,   -- the film's Plan.strike, and its shake's decay
	Disc = { Kick = true, Skirt = true, Haze = true },   -- the kinds that emit from the host's rim (sized by the caller)
	Handles = {},                       -- [caster character] = the cast being drawn
	Pool = {},
	Warned = {},
	KitCache = nil,
	Ray = RaycastParams.new(),
	RayAt = 0,
}
AS.Ray.FilterType = Enum.RaycastFilterType.Exclude

--- The generated plate data, or nil (warned once) until it is in ReplicatedStorage.Spellshot. Not cached as missing, so
--- a module that arrives later is still picked up.
local function asData()
	local folder = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = folder and folder:FindFirstChild(AS.Data)
	if m and m:IsA("ModuleScript") then
		local ok, data = pcall(require, m)
		if ok and type(data) == "table" and type(data.Plates) == "table" then return data end
	end
	if not AS.Warned.Data then
		AS.Warned.Data = true
		warn(("[TerraFX] ReplicatedStorage.Spellshot.%s not found -- Aftershock draws no ground plates"):format(AS.Data))
	end
	return nil
end

-- THE KIT is read once, the M1 boulderKit() way: each plate's PIVOT (its centroid on its top face) off the imported model
-- against AS_Origin, so nothing about the layout is copied into code -- the data gives only the motion numbers. Plate i
-- is AS_Plate_%03d with i - 1. Without the import (or for any piece missing from it) a Part stands in, sized from the
-- data: the plate's radial extent by the width of its ring's share of the circle, 0.9 deep, its top at the pivot. The
-- stand-ins are boxes where the plates are Voronoi cells, so they read as tiles -- the kit running, not the kit finished.
local function aftershockKit()
	if AS.KitCache then return AS.KitCache end
	local data = asData()
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local model = folder and folder:FindFirstChild(AS.Kit)
	local origin = model and model:FindFirstChild("AS_Origin", true)
	local kit = { Plates = {}, Blocks = {}, Spikes = {} }
	local missing = 0
	if data then
		local depth = (type(data.Ring) == "table" and data.Ring.PlateDepth) or 0.9
		local perRing = {}
		for _, pd in ipairs(data.Plates) do perRing[pd.Ring] = (perRing[pd.Ring] or 0) + 1 end
		for i, pd in ipairs(data.Plates) do
			local src = origin and model:FindFirstChild(("AS_Plate_%03d"):format(i - 1), true)
			if src and src:IsA("BasePart") then
				kit.Plates[i] = { Data = pd, Source = src, Pivot = origin.CFrame:ToObjectSpace(src.CFrame * src.PivotOffset),
					FromPivot = src.PivotOffset:Inverse(), Size = src.Size }
			else
				missing += 1
				local c = Vector3.new(pd.C[1], 0, pd.C[2])
				local out = c.Magnitude > 1e-3 and c.Unit or Vector3.zAxis
				local radial, across
				if pd.Ring == 0 then
					radial = (pd.RIn + pd.ROut) * 0.8
					across = radial
				else
					radial = math.clamp((pd.ROut - pd.RIn) * 0.8, 0.5, 4)
					across = math.clamp(2 * math.pi * pd.Rc / (perRing[pd.Ring] or 1) * 0.8, 0.5, 6)
				end
				kit.Plates[i] = { Data = pd, Pivot = CFrame.lookAt(c, c + out), FromPivot = CFrame.new(0, -depth / 2, 0),
					Size = Vector3.new(across, depth, radial) }
			end
		end
		for _, rd in ipairs(type(data.Rocks) == "table" and data.Rocks or {}) do
			local src = model and model:FindFirstChild(rd.Name, true)
			local e
			if src and src:IsA("BasePart") then
				e = { Source = src, Size = src.Size / math.max(src.Size.X, src.Size.Y, src.Size.Z) }
			else
				missing += 1
				e = { Size = typeof(rd.Size) == "Vector3" and rd.Size or Vector3.one }
			end
			table.insert(rd.Kind == "spike" and kit.Spikes or kit.Blocks, e)
		end
	end
	if #kit.Blocks == 0 then kit.Blocks[1] = { Size = Vector3.new(1, 0.52, 0.8) } end
	if #kit.Spikes == 0 then kit.Spikes[1] = { Size = Vector3.new(0.45, 1, 0.36) } end
	if (missing > 0 or not origin) and folder and not meshWarned[AS.Kit] then
		meshWarned[AS.Kit] = true
		warn(("[TerraFX] '%s' not found (or incomplete) in ReplicatedStorage.%s -- Aftershock falls back to Parts")
			:format(AS.Kit, MESH_FOLDER))
	end
	if data then AS.KitCache = kit end
	return kit
end

--- A fresh copy of one kit piece (a plate or a rock), anchored and inert, lit stone that casts its shadow. A kit rock
--- keeps its baked vertex colours (white); a plate takes the earth `tone` over its white top.
local CRLib = nil
local function chargedRockLib()
	CRLib = CRLib or require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("ChargedRock"))
	return CRLib
end

local function asPiece(e, size, tone)
	local p
	if e.Source then
		p = e.Source:Clone()
	else
		p = Instance.new("Part")
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, true, true
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency, p.Reflectance = 0, 0
	if p:IsA("MeshPart") then p.DoubleSided = false end
	p.Color = tone or (e.Source and WHITE) or AS.Stone
	p.Size = size and e.Size * size or e.Size
	return p
end

--- A set of the kit's plates, hidden, from the pool or built (the Cryo Flash Freeze / Chill Aura pattern): 162 MeshParts
--- are cloned once per set for the session, not once per cast.
local function asAcquire(kit, wrap)
	while #AS.Pool > 0 do
		local set = table.remove(AS.Pool)
		if set.Kit == kit and set.Wrap == wrap and set.Parts[1] and set.Parts[1].Parent == set.Folder then return set end
		pcall(function() set.Folder:Destroy() end)
	end
	local set = { Kit = kit, Wrap = wrap, Folder = Instance.new("Folder"), Parts = {} }
	set.Folder.Name = "AftershockPlates"
	for i, e in ipairs(kit.Plates) do
		-- a wrap's plates: the bake under the kit's obsidian tint (SkinCatalog) instead of PlateTop
		local p = asPiece(e, nil, wrap and wrap.Tint.TerraAftershock or AS.PlateTop)
		p.Transparency = 1
		p.Parent = set.Folder
		set.Parts[i] = p
	end
	return set
end

local function asRelease(set)
	for _, p in ipairs(set.Parts) do
		if p.Transparency ~= 1 then p.Transparency = 1 end
	end
	if #AS.Pool < AS.PoolMax and set.Parts[1] and pcall(function() set.Folder.Parent = nil end)
		and set.Parts[1].Parent == set.Folder then
		table.insert(AS.Pool, set)
	else
		pcall(function() set.Folder:Destroy() end)
	end
end

--- The floor under `p`, searched down `len` studs from height `top` -- which the caller sets just above the floor it
--- expects, never from high up, so a roof or a bridge over the ring is never taken for its ground (the M1 floor probe's
--- lesson). The FX folder and every player are not floor; a dummy or a wall standing on it is looked through.
local function asFloor(p, top, len)
	local now = os.clock()
	if now >= AS.RayAt then
		AS.RayAt = now + 0.5
		local list = { fxFolder() }
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character then list[#list + 1] = pl.Character end
		end
		AS.Ray.FilterDescendantsInstances = list
	end
	local from, dir = Vector3.new(p.X, top, p.Z), Vector3.new(0, -len, 0)
	for _ = 1, 3 do
		local hit = workspace:Raycast(from, dir, AS.Ray)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit end
		AS.Ray:AddToFilter(model)
	end
	return nil
end

--- How far a piece at rotation `cf` hangs below its centre -- a little under its box, since the stone sits inside it.
local function asReach(cf, half)
	return 0.85 * (math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z)
end

--- Where a body's feet are, on the floor: R15's feet, R6's legs, or either side of the root.
local function asFeet(character)
	local out = {}
	if not (typeof(character) == "Instance" and character.Parent) then return out end
	for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then out[#out + 1] = p.Position - p.CFrame.UpVector * (p.Size.Y / 2) end
	end
	if #out == 0 then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, s in ipairs({ -1, 1 }) do
				out[#out + 1] = root.Position + root.CFrame.RightVector * (0.85 * s) - Vector3.new(0, 3, 0)
			end
		end
	end
	return out
end

--- `count` particles of `kind` at `cf` (a Disc kind from the host's rim, `radius` across it; the rest from its centre,
--- along cf's Up), sized by `scale` -- M1's burst(), on the cast's own host, with AFTERSHOCK_KIT's presets. `variant` +
--- `extra` make an emitter of their own (a darker cloud, the strike's). Every emitter joins the cast's list, so the
--- hitpause and the review slow-motion reach it (TimeScale).
local function asBurst(fx, kind, cf, count, scale, radius, variant, extra)
	local h = fx.BurstHost
	h.CFrame = cf
	if radius then h.Size = Vector3.new(radius * 2, 0.2, radius * 2) end
	scale = math.max(0.1, math.floor((scale or 1) * 10 + 0.5) / 10)
	local key = kind .. (variant or "") .. "@" .. scale
	local pe = fx.Emitters[key]
	if not pe then
		pe = VFXLibrary.AftershockBurst(AS.Disc[kind] and h or fx.BurstPoint, kind, 0, fx.Thin, extra)
		pe.Rate = 0
		if scale ~= 1 then
			local keys = {}
			for i, kp in ipairs(pe.Size.Keypoints) do
				keys[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale)
			end
			pe.Size = NumberSequence.new(keys)
			pe.Speed = NumberRange.new(pe.Speed.Min * scale, pe.Speed.Max * scale)
		end
		pe.TimeScale = fx.TimeScale or 1
		fx.Emitters[key] = pe
		table.insert(fx.EmitterList, pe)
	end
	local density = (Settings.EffectDensity or 1) * ((fx.Thin and Settings.ThinEnemyVFX) and 0.5 or 1)
	local n = math.floor(count * density + 0.5)
	if n > 0 then pe:Emit(n) end
end

--- A shake on this client's camera through the Viewmodel's own path, fading out to nothing at ShakeReach from `from`
--- (nil: no falloff -- the body it hit is this client's).
local function asShake(amp, decay, from)
	if not (Viewmodel and Viewmodel.Shake) then return end
	local k = 1
	if from then
		local cam = workspace.CurrentCamera
		if not cam then return end
		k = 1 - (cam.CFrame.Position - from).Magnitude / T.Aftershock.ShakeReach
	end
	if k > 0 then Viewmodel.Shake(amp * k, decay) end
end

--- Everything of one cast gone at once: its plates back to the pool, its rocks, grit, hosts, underlay and mark destroyed.
local function asTeardown(fx)
	if fx.Dead then return end
	fx.Dead = true
	if fx.Character and AS.Handles[fx.Character] == fx then AS.Handles[fx.Character] = nil end
	if fx.Set then
		asRelease(fx.Set)
		fx.Set = nil
	end
	if fx.Model then fx.Model:Destroy() end
end

--- One cast's own folder and burst host.
local function asNew(character, thin, seed)
	local fx = { Character = character, Thin = thin, Rng = Random.new(seed), Kit = aftershockKit(), Born = os.clock(),
		Wrap = chargedRockLib().WrapOf(character, "Aftershock"),   -- the caster's wrap (SkinCatalog), or nil
		Rocks = {}, Grit = {}, Plates = {}, Beat = {}, Emitters = {}, EmitterList = {} }
	local model = Instance.new("Folder")
	model.Name = "Aftershock"
	model.Parent = fxFolder()
	fx.Model = model
	local h = inert(Instance.new("Part"))
	h.Name = "AftershockBurst"
	h.Transparency = 1
	h.Size = Vector3.new(1, 0.2, 1)
	h.Parent = model
	fx.BurstHost = h
	fx.BurstPoint = Instance.new("Attachment")
	fx.BurstPoint.Parent = h
	return fx
end

--- Runs `frame(fx, now)` every frame through the kit's one render step until it returns false, then tears the cast
--- down. An error stops the cast AND says so once (the step's own pcall would drop it silently, leaving its parts).
local function asRun(fx, frame)
	addEffect(function(now)
		if fx.Dead then return false end
		local ok, keep = pcall(frame, fx, now)
		if not ok then
			table.clear(moveParts)
			table.clear(moveCFs)
			if not AS.Warned.Step then
				AS.Warned.Step = true
				warn("[TerraFX] Aftershock's look stopped on an error: " .. tostring(keep))
			end
		end
		if not ok or keep == false then
			asTeardown(fx)
			return false
		end
		return true
	end)
end

--- THE ROCKS, every frame: each driven up out of the floor at its launch velocity, unslowed, until it is clear (the film's
--- kin/release), then flown here -- AFTERSHOCK'S OWN STEPPER, so M1's stepDebris and its look are untouched: falling at
--- DebrisGravity, bouncing off the PLANE of the floor it came out of (+ PlateLift, the crust it broke) with Bounce and
--- Slide, tumbling, coming to Rest; a puff where a big one first lands; from its SinkFrom, sunk into the floor over Sink
--- and gone. No raycast in flight: one floor probe each, when it erupts. Resting rocks are not moved. A rock's clock is
--- its own T0 (the server's), less Off: the ring's rocks run on tau less their eruption time, a strike's from the strike.
--- Returns whether any rock is still to come or still there.
local function asRocks(fx, serverNow, scale, dt)
	local A = T.Aftershock
	local busy = false
	for _, rk in ipairs(fx.Rocks) do
		if not rk.Done then
			busy = true
			local age = (serverNow - rk.T0) * scale - rk.Off
			if age >= 0 and not rk.Part then
				local hit = age <= AS.RockLate
					and asFloor(rk.Pos, rk.RefY + A.PlateTolerance + 0.5, 2 * A.PlateTolerance + 1.5)
				-- (2026-09-25) the ring's own rocks (Snap; RefY the centre's floor) refuse a floor more than AS.PlateSnap
				-- below the centre's, as the plates do: the rock would come to rest under the underlay's top. (A strike's
				-- shard keeps the wider band: its RefY is the victim's feet, not the disc's floor.)
				local dy = hit and hit.Position.Y - rk.RefY
				if not hit or math.abs(dy) > A.PlateTolerance + 0.5 or (rk.Snap and dy < -AS.PlateSnap)
					or hit.Normal.Y < 0.75 then
					rk.Done = true          -- late, or no floor there (a ledge, a wall, a slope): it never comes up
				else
					local fy = hit.Position.Y
					local p = asPiece(rk.Entry, rk.Size, fx.Wrap and fx.Wrap.Tint.TerraAftershock or nil)
					if rk.Size < 1 then p.CastShadow = false end
					rk.Half = p.Size / 2
					-- ...and one a little below it lands on the crust's plane, never under the underlay
					rk.Plane = (rk.Snap and math.max(fy, rk.RefY) or fy) + A.PlateLift
					rk.P0 = Vector3.new(rk.Pos.X, fy - 0.02 - asReach(rk.Q, rk.Half), rk.Pos.Z)
					rk.F = CFrame.new(rk.P0) * rk.Q
					rk.Phase = "Rise"
					p.CFrame = rk.F
					p.Parent = fx.Model
					rk.Part = p
					-- the eruption: a spurt of dust and crumbs where it breaks out
					local g = CFrame.new(rk.Pos.X, fy + 0.35, rk.Pos.Z)
					asBurst(fx, "Landing", g, 2, rk.Size < 1.2 and 0.9 or 1.5)
					asBurst(fx, "Grit", g, 3, 1)
				end
			end
			local p = rk.Part
			if p and not rk.Done then
				if not p.Parent then
					rk.Done = true
				elseif age >= rk.SinkFrom then
					local u = span(age, rk.SinkFrom, rk.SinkFrom + A.Sink)
					if u >= 1 then
						p:Destroy()
						rk.Done = true
					else
						rk.SinkCF = rk.SinkCF or rk.F
						queueMove(p, rk.SinkCF - Vector3.new(0, rk.Size * 2.2 * u * u, 0))
					end
				elseif rk.Phase == "Rise" then
					local w = rk.W.Magnitude
					local rot = w > 1e-4 and CFrame.fromAxisAngle(rk.W.Unit, w * age) * rk.Q or rk.Q
					local pos = rk.P0 + rk.V * age
					rk.F = CFrame.new(pos) * rot
					if pos.Y - asReach(rot, rk.Half) > rk.Plane + 0.03 then
						rk.Phase = "Fly"
						rk.FlyAt = age
						if rk.ReleaseV then rk.V = rk.ReleaseV end    -- a strike gave the rest of its speed to the body
					end
					queueMove(p, rk.F)
				elseif rk.Phase == "Fly" and dt > 0 then
					rk.V -= Vector3.new(0, A.DebrisGravity * dt, 0)
					local w = rk.W.Magnitude
					local rot = w > 1e-4 and CFrame.fromAxisAngle(rk.W.Unit, w * dt) * rk.F.Rotation or rk.F.Rotation
					local pos = rk.F.Position + rk.V * dt
					local down = asReach(rot, rk.Half)
					if pos.Y - down < rk.Plane then
						pos = Vector3.new(pos.X, rk.Plane + down, pos.Z)
						if rk.V.Y < 0 then
							rk.V = Vector3.new(rk.V.X * A.Slide, -rk.V.Y * A.Bounce, rk.V.Z * A.Slide)
							rk.W *= A.Slide
							if rk.Big and not rk.Landed then
								rk.Landed = true
								asBurst(fx, "Landing", CFrame.new(pos.X, rk.Plane + 0.3, pos.Z), 2, rk.Size < 1.6 and 0.9 or 1.5)
							end
						end
						if rk.V.Magnitude < A.Rest then
							rk.Phase = "Rest"
							rk.V, rk.W = Vector3.zero, Vector3.zero
						end
					end
					rk.F = CFrame.new(pos) * rot
					queueMove(p, rk.F)
					if age - (rk.FlyAt or 0) > 6 then       -- still going after 6 s: it left the world
						p:Destroy()
						rk.Done = true
					end
				end
			end
		end
	end
	return busy
end

--- THE PLATES, every frame from the front's first frame: Ground.slab_matrix, ported exactly, per plate --
---   a bulge exp(-x^2) at x = (tau - Tau) / Dl, lifting it H and rocking it Tp x 2.3 x x exp(-x^2) as the front runs
---   under it; the heave Hres (with its wobble) and the tilt Tr it keeps, eased on; the outward shove Sh; the crater's
---   plates driven down D and tilted Tc instead; every kept term times the settle factor --
--- the tilt about r_hat x up, so + lifts the plate's OUTER edge. Each plate is hidden until the front's skin reaches its
--- inner radius, probed for its own floor once then (and dropped where there is none within PlateTolerance above the
--- centre's or AS.PlateSnap below it, or it is steeper than the normal's Y 0.75 -- a drop below capping the underlay's
--- radius, fx.UnderCap), and left alone once it has come to rest. Plates within
--- FeetClear of her feet at the slam crack but stay level (the film's rule, measured on the real feet, not the film's
--- stance: the crater's plates still drop, as the film's do). Returns the settle's sink and the skin's radius.
local function asPlates(fx, tau)
	local A = T.Aftershock
	local skin = math.max(TerraFX.AftershockFrontR(tau) * (1 + 1 / A.Radius), A.Crater * (1 - (1 - clamp01(tau / 0.033)) ^ 3))
	local tSet = A.RingTime + A.Scar
	local su = smooth(span(tau, tSet, tSet + A.Settle))
	local settle = 1 - su
	local sinkD = (A.PlateLift + AS.PlateSink) * su * su
	local settling, sunk = tau >= tSet, su >= 1
	if not (fx.Set and fx.Set.Folder.Parent) then return sinkD, skin end
	local probes = 0
	for _, pl in ipairs(fx.Plates) do
		local e = pl.E
		local pd = e.Data
		-- (2026-09-25) at most ProbeCap probes a frame: a client that joins after the front has gone out would otherwise
		-- probe every plate on its first frame; the rest wait (hidden) for the next frames
		if not pl.Probed and skin >= pd.RIn and probes < AS.ProbeCap then
			pl.Probed = true
			probes += 1
			local wp = fx.Frame * e.Pivot
			local hit = asFloor(wp.Position, fx.FloorY + A.PlateTolerance + 0.5, 2 * A.PlateTolerance + 1)
			local dy = hit and hit.Position.Y - fx.FloorY
			if hit and dy <= A.PlateTolerance and dy >= -AS.PlateSnap and hit.Normal.Y >= 0.75 then
				pl.Ok = true
				-- (2026-09-25) never under the underlay's top: a floor a little below the centre's is bridged at the
				-- centre's height (AS.PlateSnap)
				pl.Rest = Vector3.new(wp.X, math.max(hit.Position.Y, fx.FloorY) + A.PlateLift, wp.Z)
				local flat = Vector3.new(wp.X - fx.At.X, 0, wp.Z - fx.At.Z)
				pl.Rhat = flat.Magnitude > 1e-3 and flat.Unit or fx.Face
				pl.Axis = pl.Rhat:Cross(Vector3.yAxis)
				pl.Rot = wp.Rotation
				if not pd.Crater then
					local box = CFrame.new(pl.Rest) * pl.Rot * e.FromPivot
					local half = e.Size / 2
					for _, f in ipairs(fx.Feet or {}) do
						local l = box:PointToObjectSpace(Vector3.new(f.X, pl.Rest.Y, f.Z))
						local d = Vector3.new(math.max(0, math.abs(l.X) - half.X), math.max(0, math.abs(l.Y) - half.Y),
							math.max(0, math.abs(l.Z) - half.Z))
						if d.Magnitude < A.FeetClear then
							pl.Level = true
							break
						end
					end
				end
			elseif not (hit and dy > 0) then
				-- (2026-09-25) no floor here, or one that falls away below the band (a step down, a ledge, a slope): the
				-- underlay is one flat disc at the centre's floor and would float over it, so it stops short of this
				-- plate. (A floor ABOVE the centre's hides the disc under itself, and needs no cap.)
				fx.UnderCap = math.min(fx.UnderCap or math.huge, pd.RIn)
			end
		end
		if pl.Ok then
			local part = pl.Part
			if sunk then
				if not pl.Gone then
					pl.Gone = true
					part.Transparency = 1       -- under the floor: nothing left to draw
				end
			else
				if not pl.Shown then
					pl.Shown = true
					part.Transparency = 0
				end
				if settling and not pl.Settling then
					pl.Settling = true
					pl.Static = false
				end
				if not pl.Static then
					local lift, th, sh, still = 0, 0, 0, true
					if pd.Crater then
						local a0 = math.max(0, tau)
						local dep = -pd.D * (1 - math.exp(-a0 / 0.022)) * (1 + 0.16 * math.exp(-a0 / 0.09) * math.sin(a0 * 55))
						lift = dep * settle
						th = pd.Tc * (1 - math.exp(-a0 / 0.03)) * settle
						still = a0 > 0.45
					elseif not pl.Level then
						local a, dl = tau - pd.Tau, pd.Dl
						if a >= -3 * dl then
							local x = a / dl
							local bump = math.exp(-x * x)
							local on = smooth((a + dl) / (2 * dl))
							local wob = 1 + (a > 0 and 0.35 * math.exp(-a / 0.07) * math.cos(a * pd.Wob) or 0)
							lift = pd.H * bump + pd.Hres * on * wob * settle
							th = pd.Tp * 2.3 * x * bump + pd.Tr * on * settle
							sh = pd.Sh * on * settle
						end
						still = a > math.max(3 * dl, 0.45)
					end
					local pos = pl.Rest + pl.Rhat * sh + Vector3.new(0, lift - sinkD, 0)
					local rot = math.abs(th) > 1e-5 and CFrame.fromAxisAngle(pl.Axis, th) * pl.Rot or pl.Rot
					queueMove(part, CFrame.new(pos) * rot * e.FromPivot)
					pl.Static = still and not settling
				end
			end
		end
	end
	return sinkD, skin
end

--- THE SLAM, once, at sim Hit (the first frame of the hold): the ring's pieces laid out, and -- unless this client only
--- heard of the cast after it (a late join) -- the dust, the grit and the shake.
local function asSlam(fx, t)
	local A = T.Aftershock
	local rng = fx.Rng
	local at, fy = fx.At, fx.FloorY
	local late = t - A.Hit > AS.Late
	-- first person: the slam is 2.15 studs ahead of her feet and 4.5 below the lens, so its dust fills the screen
	fx.FP = fx.Own and Viewmodel ~= nil and Viewmodel.GetFistCFrame ~= nil and Viewmodel.GetFistCFrame("R") ~= nil
	local k = fx.FP and AS.FPThin or 1
	local character = fx.Character
	local root = typeof(character) == "Instance" and character:FindFirstChild("HumanoidRootPart")
	fx.Feet = asFeet(character)
	-- THE PLATES: one pooled set, the kit's one layout in the cast's frame (taken at the key by TerraFX.Aftershock, so a
	-- set that has to be built is built in the windup, not on this frame; only parented here)
	fx.Frame = CFrame.lookAt(at, at + fx.Face) * CFrame.Angles(0, fx.Yaw, 0) * AS.Turn
	if not fx.Set and #fx.Kit.Plates > 0 then fx.Set = asAcquire(fx.Kit, fx.Wrap) end
	if fx.Set then
		local set = fx.Set
		set.Folder.Parent = fxFolder()
		for i, e in ipairs(fx.Kit.Plates) do fx.Plates[i] = { Part = set.Parts[i], E = e } end
	end
	-- THE UNDERLAY: the dark under the crust, its top at floor + 0.03 (the plates' at + PlateLift), grown with the skin.
	-- (2026-09-25) Only under a plate set: it is the gaps between plates, and with no plates (no AftershockKitData here)
	-- it would lie as a bare near-black disc the ring's width for the whole scar. It never moves: no plate is rested
	-- under its top (AS.PlateSnap), and it stops short of the first plate whose floor falls away (fx.UnderCap).
	if fx.Set then
		local u = inert(Instance.new("Part"))
		u.Name = "AftershockUnderlay"
		u.Shape = Enum.PartType.Cylinder
		u.Color = fx.Wrap and fx.Wrap.Skin.Underlay or AS.Void
		-- a wrap: the gaps between the heaved plates are magma (Neon) -- molten orange just behind the racing front (this
		-- disc), cooled to red inside it (a second disc a hair above, trailing the front) -- and go dark as the scar heals
		if fx.Wrap then
			u.Material = Enum.Material.Neon
			u.Color = fx.Wrap.Skin.UnderlayHot
		end
		u.Transparency = 1
		u.Size = Vector3.new(AS.UnderThick, 0.2, 0.2)
		u.CFrame = CFrame.new(at.X, fy + 0.03 - AS.UnderThick / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
		u.Parent = fx.Model
		if fx.Wrap then
			-- (cloned only now, laid flat and in place: a clone taken before u was placed stood up at the world origin)
			local c = u:Clone()
			c.Name = "AftershockUnderlayCool"
			c.Color = fx.Wrap.Skin.Underlay
			c.CFrame = u.CFrame + Vector3.new(0, 0.012, 0)
			c.Parent = fx.Model
			fx.UnderCool = c
		end
		fx.Underlay, fx.UnderT, fx.UnderFill = u, 1, 0
	end
	-- THE FRONT's wall of dust (and its grit): a Disc host the front's size, re-rated by the band it sweeps
	local h = inert(Instance.new("Part"))
	h.Name = "AftershockFront"
	h.Transparency = 1
	h.Size = Vector3.new(0.4, 0.2, 0.4)
	h.CFrame = CFrame.new(at.X, fy + 0.35, at.Z)
	h.Parent = fx.Model
	fx.FrontHost = h
	fx.FrontDust = VFXLibrary.AftershockEmitter(h, "Front", fx.Thin)
	fx.FrontGrit = VFXLibrary.AftershockEmitter(h, "Grit", fx.Thin, { Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface })
	for _, pe in ipairs({ fx.FrontDust, fx.FrontGrit }) do
		pe.Rate = 0
		pe.TimeScale = fx.TimeScale or 1
		table.insert(fx.EmitterList, pe)
	end
	-- THE ROCKS: Rocks x EffectDensity (x0.5 for somebody else's), in rings from Inner out, each ring's share by its
	-- length, jittered round and out as the film's Plan lays them, seeded by the server so every client erupts the same
	-- ring; none within 3.6 studs of her root (the film's rule: not up round the caster, nor through the lens)
	local R = A.Radius
	local n = math.floor(A.Rocks * (Settings.EffectDensity or 1) * (fx.Thin and 0.5 or 1) + 0.5)
	local rows, total = {}, 0
	local r0 = A.Inner
	while r0 <= R - 0.35 do
		rows[#rows + 1] = r0
		total += r0
		r0 += AS.RowStep
	end
	local hold = A.Hit + A.HoldFrames / 60
	-- (2026-09-25) each ring's share rounded on the running total, so the rings sum to n exactly: no floor per ring,
	-- which at a low EffectDensity erupted nearly twice the scaled budget (a ring whose share rounds to 0 is skipped)
	local cum, placed = 0, 0
	for _, r in ipairs(n > 0 and rows or {}) do
		cum += r
		local cnt = math.floor(n * cum / total + 0.5) - placed
		placed += cnt
		if cnt <= 0 then continue end
		local ph = rng:NextNumber(0, 2 * math.pi)
		for j = 0, cnt - 1 do
			local rr = math.clamp(r + rng:NextNumber(-0.45, 0.45), A.Inner, R - 0.3)
			local ang = ph + (j + rng:NextNumber(-0.35, 0.35)) * 2 * math.pi / cnt
			local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local pos = at + out * rr
			local spike = rng:NextNumber() < A.SpikeShare
			local range = spike and A.SpikeSize or A.RockSize
			local size = rng:NextNumber(range[1], range[2]) * (1.12 - 0.32 * rr / R)
			local st = TerraFX.AftershockStrength(rr)
			local up = spike and A.SpikeUp or A.RockUp
			local axis = out:Cross(Vector3.yAxis)          -- the tangent: a turn about it lifts the outer side
			local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.3), 0)
			local q = spike and CFrame.fromAxisAngle(axis, math.rad(rng:NextNumber(8, 30))) * yaw
				or CFrame.fromAxisAngle(randUnit(rng), math.rad(rng:NextNumber(0, 9))) * yaw
			local v = out * (rng:NextNumber(A.RockOut[1], A.RockOut[2]) * st) + axis * rng:NextNumber(-1.2, 1.2)
				+ Vector3.new(0, rng:NextNumber(up[1], up[2]) * st, 0)
			local w = randUnit(rng) * (spike and rng:NextNumber(1, 4) or rng:NextNumber(3, 9))
			local te = TerraFX.AftershockFrontT(rr) + rng:NextNumber(0, 0.012)
			local list = spike and fx.Kit.Spikes or fx.Kit.Blocks
			local pick = list[rng:NextInteger(1, #list)]
			local near = root and (Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)).Magnitude < 3.6
			if not near then
				table.insert(fx.Rocks, { Entry = pick, Size = size, Pos = pos, RefY = fy, Snap = true, T0 = fx.T0, Off = hold + te,
					SinkFrom = A.RingTime + A.Scar - te, V = v, W = w, Q = q, Big = spike or size > 1.1 })
			end
		end
	end
	-- THE SCUFF under the fists (M1's crater mark): its face at floor + 0.045, over the underlay's top and under the
	-- plates' -- it shows in the crater and the cracks, and on the floor itself once the scar has sunk; faded in the heal
	local m = decalAt(fx, Vector3.new(at.X, fy - 0.01, at.Z), Vector3.yAxis, 5, M1_TEXTURES.Scuff, rng:NextNumber(0, 6.28))
	m.Host.Parent = fx.Model
	fx.Mark, fx.MarkT = m, 1
	if late then return end
	-- THE DUST: the dome, a darker share of it, the first fast puff off the fists, the skirt thrown along the ground, and
	-- the haze left hanging over it (the film's 36 / 14 / 24, about half)
	local dome = CFrame.new(at.X, fy + 0.6, at.Z)
	asBurst(fx, "Cloud", dome, 18 * k, 1)
	asBurst(fx, "Cloud", dome, 4 * k, 1, nil, "Dark", { Color = ColorSequence.new(Color3.fromRGB(117, 97, 69)) })
	asBurst(fx, "Cloud", dome, 8 * k, 1, nil, "Puff", {
		Color = ColorSequence.new(Color3.fromRGB(194, 173, 140)), Lifetime = NumberRange.new(0.5, 0.8),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 2.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.4, 0.5),
			NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(6, 11), Drag = 5, SpreadAngle = Vector2.new(85, 85) })
	asBurst(fx, "Skirt", CFrame.new(at.X, fy + 0.4, at.Z), 12 * k, 1, 1.2)
	asBurst(fx, "Haze", CFrame.new(at.X, fy + 3, at.Z), 3 * k, 1, 3)
	asBurst(fx, "Grit", CFrame.new(at.X, fy + 0.1, at.Z), 12, 1)
	-- THE GRIT, flown: crumbs of the kit's crust thrown off the fists, bouncing low off the floor, sunk with the rubble
	local ng = math.floor(AS.SlamGrit * (Settings.EffectDensity or 1) * (fx.Thin and 0.5 or 1) + 0.5)
	for _ = 1, ng do
		local d = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 2.0), rng:NextNumber(-1, 1)).Unit
		local blocks = fx.Kit.Blocks
		local size = rng:NextNumber(0.1, 0.2)
		local p = asPiece(blocks[rng:NextInteger(1, #blocks)], size, fx.Wrap and fx.Wrap.Tint.TerraAftershock or nil)
		p.CastShadow = false
		local pos = Vector3.new(at.X, fy + 0.1, at.Z) + d * 0.6
		local q = CFrame.fromAxisAngle(randUnit(rng), rng:NextNumber(0, 6))
		p.CFrame = CFrame.new(pos) * q
		p.Parent = fx.Model
		table.insert(fx.Grit, { Part = p, P = pos, V = d * rng:NextNumber(5, 14), Size = size, Q = q,
			W = randUnit(rng) * rng:NextNumber(8, 20) })
	end
	if not fx.Own then asShake(A.Shake, A.ShakeDecay, at) end
end

--- The ring's clock (tau) at which a cast is over: the scar held, then the longest of the settle, the heal and the
--- rubble's sink. asFrame ends a cast here, and TerraFX.Aftershock refuses one a late joiner hears of after it.
local function asEndTau()
	local A = T.Aftershock
	return A.RingTime + A.Scar + math.max(A.Settle, A.HealDelay + A.Heal, A.Sink) + 0.1
end

--- One frame of a cast, on the server's clock.
local function asFrame(fx, now)
	if not (fx.Model and fx.Model.Parent) then return false end      -- the FX folder was cleared under it
	local A = T.Aftershock
	local scale = VFXLibrary.ShotTimeScale()
	local serverNow = workspace:GetServerTimeNow()
	local t = (serverNow - fx.T0) * scale
	local held = t >= A.Hit and t < A.Hit + A.HoldFrames / 60
	-- THE HITPAUSE: every emitter of the cast stopped through the hold (and at the review slow-motion's pace otherwise),
	-- and nothing flown moves
	local ts = held and 0 or scale
	if ts ~= fx.TimeScale then
		fx.TimeScale = ts
		for _, pe in ipairs(fx.EmitterList) do pe.TimeScale = ts end
	end
	local dt = held and 0 or math.min(now - (fx.LastStep or now), 1 / 20) * scale
	fx.LastStep = now
	local sim = TerraFX.AftershockClock(t)
	if sim < A.Hit then
		-- THE WINDUP: the ground thumping at each foot, harder each beat
		for i, b in ipairs(A.Beats) do
			if not fx.Beat[i] and sim >= b then
				fx.Beat[i] = true
				if sim - b <= AS.Late then
					local power = 0.55 + 0.45 * (i - 1) / math.max(1, #A.Beats - 1)
					for _, f in ipairs(asFeet(fx.Character)) do
						local hit = asFloor(f, f.Y + 0.6, 2.5)
						local g = hit and hit.Position or f
						asBurst(fx, "Kick", CFrame.new(g + Vector3.new(0, 0.3, 0)), AS.FeetKick * power, 1, 0.5)
						asBurst(fx, "Grit", CFrame.new(g + Vector3.new(0, 0.05, 0)), 2, 1)
					end
				end
			end
		end
		return true
	end
	if not fx.Slammed then
		fx.Slammed = true
		asSlam(fx, t)
	end
	local tau = TerraFX.AftershockRingTau(t)
	local tSet = A.RingTime + A.Scar
	local k = fx.FP and AS.FPThin or 1
	if tau >= 0 then
		if not fx.Rumbled then
			fx.Rumbled = true
			if not fx.Own and tau <= AS.Late then asShake(A.Rumble, A.RumbleDecay, fx.At) end
		end
		local _, skin = asPlates(fx, tau)
		-- the underlay follows the skin (stopping short of a floor that falls away), and in the aftermath the cracks
		-- fill: (2026-09-25) it stays at the floor -- riding the plates down took it under the floor in the settle's
		-- first quarter, before its heal had begun, so HealDelay and Heal showed nothing -- and takes the crust's colour
		-- over HealDelay as the plates sink into it (the film's void filling), then fades over Heal (the ground healing)
		local u = fx.Underlay
		if u then
			local r = math.clamp(math.min(skin, fx.UnderCap or math.huge), 0.1, A.Radius + 1)
			if math.abs(r - (fx.UnderR or 0)) > 0.01 * r then
				fx.UnderR = r
				u.Size = Vector3.new(AS.UnderThick, 2 * r, 2 * r)
			end
			local cool = fx.UnderCool
			if cool then
				-- the hot band: the last 3.5 studs behind the front, closing up over 0.8 s once the ring stops
				local rc = math.max(0.05, r - 3.5 * (1 - span(tau, A.RingTime, A.RingTime + 0.8)))
				if math.abs(rc - (fx.UnderRC or 0)) > 0.01 * r then
					fx.UnderRC = rc
					cool.Size = Vector3.new(AS.UnderThick, 2 * rc, 2 * rc)
				end
				if cool.Transparency ~= u.Transparency then cool.Transparency = u.Transparency end
			end
			local fill = smooth(span(tau, tSet, tSet + A.HealDelay))
			if math.abs(fill - fx.UnderFill) > 0.01 or (fill >= 1 and fx.UnderFill < 1) then
				fx.UnderFill = fill
				if fx.Wrap then
					local sk = fx.Wrap.Skin
					local m = fill < 0.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic
					u.Color = sk.UnderlayHot:Lerp(sk.Seam.Dead, fill)
					u.Material = m
					if cool then
						cool.Color = sk.Underlay:Lerp(sk.Seam.Dead, fill)
						cool.Material = m
					end
				else
					u.Color = AS.Void:Lerp(AS.PlateTop, fill)
				end
			end
			local heal = span(tau, tSet + A.HealDelay, tSet + A.HealDelay + A.Heal)
			if heal ~= fx.UnderT then
				fx.UnderT = heal
				u.Transparency = heal
			end
		end
		-- the front's wall of dust, the band it sweeps: rate 2 pi r v x FrontDensity, thrown harder where it is strong
		if tau <= A.RingTime then
			local _, KD, V0 = aftershockFront()
			local fr = math.max(0.2, TerraFX.AftershockFrontR(tau))
			fx.FrontHost.Size = Vector3.new(2 * fr, 0.2, 2 * fr)
			local v = V0 * (1 - KD * tau / A.RingTime)
			local rate = AS.FrontDensity * 2 * math.pi * fr * v
			VFXLibrary.AftershockRate(fx.FrontDust, rate, fx.Thin)
			VFXLibrary.AftershockRate(fx.FrontGrit, rate * 1.2, fx.Thin)
			local st = (v / V0) ^ 0.6
			if math.abs(st - (fx.FrontSt or 0)) > 0.04 then
				fx.FrontSt = st
				fx.FrontDust.Speed = NumberRange.new(2 * st, 6 * st)
				fx.FrontGrit.Speed = NumberRange.new(4 * st, 12 * st)
			end
		elseif not fx.FrontOff then
			fx.FrontOff = true
			VFXLibrary.AftershockRate(fx.FrontDust, 0, fx.Thin)
			VFXLibrary.AftershockRate(fx.FrontGrit, 0, fx.Thin)
		end
		-- the haze left hanging over the broken ground halfway out, and a last breath of dust as the rubble sinks
		if not fx.HazeMid and tau >= A.RingTime * 0.5 then
			fx.HazeMid = true
			if tau - A.RingTime * 0.5 <= AS.Late then
				asBurst(fx, "Haze", CFrame.new(fx.At.X, fx.FloorY + 3, fx.At.Z), 4 * k, 1,
					math.max(1, TerraFX.AftershockFrontR(tau) * 0.7))
			end
		end
		if not fx.Breath and tau >= tSet + 0.05 then
			fx.Breath = true
			for _, rk in ipairs(fx.Rocks) do
				if rk.Part and not rk.Done and rk.Phase == "Rest" and fx.Rng:NextNumber() < 0.4 then
					local p = rk.F.Position
					asBurst(fx, "Landing", CFrame.new(p.X, rk.Plane + 0.3, p.Z), 1, 0.9)
				end
			end
		end
	end
	asRocks(fx, serverNow, scale, dt)
	-- the flown grit: a low bounce off the floor's plane, a skid to rest, sunk with the rubble
	local sinkU = span(tau, tSet, tSet + A.Sink)
	for _, g in ipairs(fx.Grit) do
		local p = g.Part
		if p.Parent then
			local moved = false
			if not g.Rest and dt > 0 then
				g.V -= Vector3.new(0, A.DebrisGravity * dt, 0)
				g.P += g.V * dt
				if g.W.Magnitude > 1e-3 then g.Q = CFrame.fromAxisAngle(g.W.Unit, g.W.Magnitude * dt) * g.Q end
				local floor = fx.FloorY + A.PlateLift + g.Size * 0.35
				if g.P.Y < floor then
					g.P = Vector3.new(g.P.X, floor, g.P.Z)
					if math.abs(g.V.Y) < 1.2 then
						g.Rest = true
						g.V = Vector3.zero
					else
						g.V = Vector3.new(g.V.X * 0.55, -g.V.Y * 0.3, g.V.Z * 0.55)
						g.W *= 0.5
					end
				end
				moved = true
			end
			if sinkU >= 1 then
				p:Destroy()
			elseif moved or sinkU > 0 then
				queueMove(p, CFrame.new(g.P - Vector3.new(0, g.Size * 1.4 * sinkU * sinkU, 0)) * g.Q)
			end
		end
	end
	-- the scuff: in as the crater opens, out as the ground heals
	local mark = fx.Mark
	if mark and mark.Host.Parent then
		local tr = 1 - 0.95 * span(tau, 0, 0.1) * (1 - span(tau, tSet + A.HealDelay, tSet + A.HealDelay + A.Heal))
		if math.abs(tr - fx.MarkT) > 0.01 or (tr >= 1 and fx.MarkT < 1) then
			fx.MarkT = tr
			mark.Decal.Transparency = tr
		end
	end
	flushMoves()
	return tau < asEndTau()
end

--- AFTERSHOCK: `character` slams both fists into the ground at `at` (the ring's centre, on the floor), facing `face`, the
--- key having gone down at server time `T0`. opts: { Own = the caster is this client, Seed = the server's integer (the
--- layout's yaw and the rocks), Thin = somebody else's cast }. Returns the cast (`.Stop()` ends it), or nil if it is long
--- over by the time this client hears of it (the late-join rule: nothing is drawn).
function TerraFX.Aftershock(character, at, face, T0, opts)
	libs()
	if typeof(at) ~= "Vector3" or type(T0) ~= "number" then return nil end
	opts = type(opts) == "table" and opts or {}
	local t = (workspace:GetServerTimeNow() - T0) * VFXLibrary.ShotTimeScale()
	-- (2026-09-25) the late-join rule, at the cast's own end (asEndTau): inside the spec's bound (Hit + RingTime + Scar +
	-- Settle + Heal + 1), but a cast heard of between the two was built whole only for its first frame to tear it down
	if TerraFX.AftershockRingTau(t) >= asEndTau() then return nil end
	local lp = Players.LocalPlayer
	local thin = opts.Thin
	if thin == nil then thin = not (lp and character == lp.Character) end
	local seed = type(opts.Seed) == "number" and math.floor(opts.Seed) or math.random(1, 2 ^ 30)
	local fx = asNew(character, thin, seed)
	local root = typeof(character) == "Instance" and character:FindFirstChild("HumanoidRootPart")
	fx.At, fx.T0, fx.Own, fx.FloorY = at, T0, opts.Own == true, at.Y
	fx.Face = flatUnit(typeof(face) == "Vector3" and face or (root and root.CFrame.LookVector) or Vector3.zero,
		-Vector3.zAxis)
	fx.Yaw = fx.Rng:NextNumber(0, 2 * math.pi)
	if character then
		local old = AS.Handles[character]
		if old and not old.Slammed then asTeardown(old) end       -- a windup nobody ended: this cast supersedes it
		AS.Handles[character] = fx
	end
	-- (2026-09-25) the plate set is taken now, at the key: a set the pool cannot give (a second cast at once, or the warm-up
	-- not done) costs its 162 clones in the windup rather than on the slam's first frame; asSlam only parents it, and a
	-- windup cut short returns it to the pool with the rest (asTeardown)
	if #fx.Kit.Plates > 0 then fx.Set = asAcquire(fx.Kit, fx.Wrap) end
	asRun(fx, asFrame)
	fx.Stop = function() asTeardown(fx) end
	return fx
end

--- THE STRIKE: the ring reached `victim`, whose feet are at `at`, `dir` flat out from the centre, at server time `T0`. A
--- StrikeSpike shard comes up under them, leaning StrikeLean degrees out along `dir` -- the rock that throws them -- and
--- is flown like the ring's rocks once it has given them its speed; dust thrown out along the strike, grit, and a shake
--- if the body is this client's. The shard sinks with the ring's rubble (or on its own, if the ring is not drawn here).
--- (2026-09-25) The lean's sign: the turn is -StrikeLean about dir x up (= +StrikeLean about up x dir), which carries the
--- spike's long axis (+Y) OUT along dir -- its base StrikeBack studs inward of the feet, its tip over and past the victim.
--- (+StrikeLean about dir x up, the ring's own spikes' sense, tipped it back toward the centre, away from the body.)
function TerraFX.AftershockStrike(character, victim, at, dir, T0)
	libs()
	if typeof(at) ~= "Vector3" then return end
	local A = T.Aftershock
	local scale = VFXLibrary.ShotTimeScale()
	local serverNow = workspace:GetServerTimeNow()
	T0 = type(T0) == "number" and T0 or serverNow
	if (serverNow - T0) * scale > 1 then return end                  -- stale: the shard would be down already
	dir = flatUnit(typeof(dir) == "Vector3" and dir or Vector3.zero, Vector3.zAxis)
	local lp = Players.LocalPlayer
	local fx = character and AS.Handles[character]
	local alone = not (fx and not fx.Dead and fx.Slammed)
	if alone then
		fx = asNew(character, not (lp and character == lp.Character), math.random(1, 2 ^ 30))
		fx.TimeScale = scale
	end
	local rng = fx.Rng
	local sinkFrom = alone and A.Scar or (fx.T0 - T0) * scale + A.Hit + A.HoldFrames / 60 + A.RingTime + A.Scar
	local v = dir * AS.StrikeOut + Vector3.new(0, AS.StrikeUp, 0)
	local spikes = fx.Kit.Spikes
	table.insert(fx.Rocks, { Entry = spikes[rng:NextInteger(1, #spikes)], Size = A.StrikeSpike, Pos = at - dir * AS.StrikeBack,
		RefY = at.Y, T0 = T0, Off = 0, SinkFrom = sinkFrom, V = v, ReleaseV = v * 0.32 + dir, W = randUnit(rng) * 0.6,
		Q = CFrame.fromAxisAngle(dir:Cross(Vector3.yAxis), -math.rad(A.StrikeLean)) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0),
		Big = true })
	local body = at + Vector3.new(0, 1.2, 0)
	asBurst(fx, "Cloud", CFrame.lookAt(body, body + (dir * 0.6 + Vector3.yAxis).Unit) * CFrame.Angles(-math.pi / 2, 0, 0),
		10, 1, nil, "Strike", {
			Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(3, 8), Drag = 3.5, SpreadAngle = Vector2.new(60, 60),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.06, 0.45),
				NumberSequenceKeypoint.new(1, 1) }) })
	asBurst(fx, "Grit", CFrame.lookAt(body, body + (dir + Vector3.yAxis * 0.8).Unit) * CFrame.Angles(-math.pi / 2, 0, 0), 10, 1)
	if victim and lp and victim == lp.Character then asShake(A.StrikeShake, AS.StrikeDecay) end
	if alone then
		asRun(fx, function(f, now)
			if not (f.Model and f.Model.Parent) then return false end
			local s = VFXLibrary.ShotTimeScale()
			if s ~= f.TimeScale then
				f.TimeScale = s
				for _, pe in ipairs(f.EmitterList) do pe.TimeScale = s end
			end
			local dt = math.min(now - (f.LastStep or now), 1 / 20) * s
			f.LastStep = now
			local busy = asRocks(f, workspace:GetServerTimeNow(), s, dt)
			flushMoves()
			return busy or now - f.Born < 1.5
		end)
	end
end

--- The windup was cut before the slam (TerraHandler: died, cleared, interrupted, entombed): that caster's cast goes at once.
function TerraFX.AftershockEnd(character, reason)
	local fx = character and AS.Handles[character]
	if fx then asTeardown(fx) end
end

-- THE KIT IS WARMED UP FRONT. ZephyrFX measured it (2026-09-17): a MeshPart cloned for the first time can draw nothing
-- for about half a second -- longer than a plate's clink or a boulder tier -- and only hidden clones kept in the workspace
-- cured it. So every client keeps one invisible, untouchable clone of each Terra piece for the session, in a folder of
-- its own (not the FX folder, which gets cleared). (The TerraAftershock kit, once imported, adds its 162 plates and 12
-- rocks here too -- 175 hidden parts a client, which keeps its meshes loaded so a plate set's clones draw at once.)
-- (2026-09-25) The cache only preloads the meshes; it builds no plate set. So once it is in, one Aftershock plate set is
-- built into AS.Pool here, at load, and the first cast of the session takes it rather than cloning 162 MeshParts itself.
if RunService:IsClient() then
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(MESH_FOLDER, 30)
		if not folder then return end
		if not workspace:FindFirstChild("TerraMeshCache") then
			local cache = Instance.new("Folder")
			cache.Name = "TerraMeshCache"
			for _, t in ipairs(folder:GetDescendants()) do
				if t:IsA("BasePart") then
					local p = t:Clone()
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
					p.Transparency = 1
					p.Parent = cache
				end
			end
			cache.Parent = workspace
		end
		-- the pool's first set: only once the plate data is in (a kit read without it is not cached, and would warn), and
		-- only if no cast has already built one
		local shared = ReplicatedStorage:WaitForChild("Spellshot", 30)
		if not (shared and shared:WaitForChild(AS.Data, 30)) then return end
		task.defer(function()
			if #AS.Pool > 0 then return end
			local kit = aftershockKit()
			if #kit.Plates > 0 and #AS.Pool == 0 then table.insert(AS.Pool, asAcquire(kit)) end
		end)
	end)
end

return TerraFX
