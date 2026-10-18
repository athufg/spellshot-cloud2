--[[
	ToxinTuning  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ToxinTuning

	Every number in TOXIN's reworked kit (manual v0.15, with the v0.17 Technique decisions), in one table the server
	(ToxinHandler) and the clients (ToxinClient, ToxinFX) both read. Pure data, no requires.

	EVERY GAMEPLAY NUMBER HERE IS A PROPOSAL (2026-09-30, the first playable build): the manual gives behaviour and no
	figures. They were picked against the live kits (150 health; Riptide 12 a hit, Leviathan's Maw's bite 65, the
	Poisoned status's own preset numbers in StatusEffects) and are for the owner to tune in play.

	DECIDED (the owner, this build): Toxic Bubbles STOPS at the first enemy it hits; Patient Zero is VARIANT B (constant
	radius, damage and duration scale with the target's allies near it).

	The COLOURS are LOCKED (vfx_blocking/toxin/TOXIN_KIT_SPEC.md, v4 Part A). Toxin's shipped identity colours #80D421,
	#CCF570 and #4A1A6B are UI and uniform only: ToxinFX refuses to draw any colour within 12/255 of them (its guard runs
	over this whole palette on load).
]]

local T = {}

T.Color = {
	-- gas / haze: clouds, Patient Zero's aura and detonation, Acid Rain's cloud
	Gas = Color3.fromRGB(75, 90, 42),          -- #4B5A2A
	GasLit = Color3.fromRGB(94, 111, 53),      -- #5E6F35
	GasShadow = Color3.fromRGB(46, 58, 26),    -- #2E3A1A
	GasCore = Color3.fromRGB(28, 36, 16),      -- #1C2410
	-- viscous liquid: drops, residue, splats, Acid Rain's globs
	Liquid = Color3.fromRGB(107, 122, 30),     -- #6B7A1E
	LiquidDeep = Color3.fromRGB(61, 70, 16),   -- #3D4610
	LiquidSpec = Color3.fromRGB(232, 242, 160),-- #E8F2A0 (the wet highlight)
	-- membrane: the Toxic Bubble only
	Membrane = Color3.fromRGB(143, 168, 62),   -- #8FA83E
	MembraneHi = Color3.fromRGB(201, 224, 119),-- #C9E077
	-- Virulence: Neon or light only
	Virulence = Color3.fromRGB(195, 232, 46),  -- #C3E82E
	-- Antitoxin Vent's mask: solid greens, and the lenses (the one glass-like detail)
	MaskBody = Color3.fromRGB(56, 111, 28),    -- #386F1C
	MaskDark = Color3.fromRGB(31, 66, 20),     -- #1F4214
	MaskPale = Color3.fromRGB(86, 144, 46),    -- #56902E
	Lens = Color3.fromRGB(30, 42, 22),         -- #1E2A16
	-- the Passive's self-damage tell (a screen tint, unlit)
	Desat = Color3.fromRGB(138, 148, 136),     -- #8A9488
}

-- the hexes NOTHING drawn may come near (UI and uniform only)
T.Shipped = { Color3.fromRGB(128, 212, 33), Color3.fromRGB(204, 245, 112), Color3.fromRGB(74, 26, 107) }

--[[ THE DISPLAY TABLE (2026-10-01, round 2 of the showcase match): the Blender kit's disp_lin, for Roblox.
	T.Color above stays the SOURCE: every effect names its colour by those locked hexes. This table is the INPUT ToxinFX
	actually builds with, per material context, so the place DISPLAYS that source as the showcase shows it on screen. The
	place's lighting and grade are shared by every Element and stay untouched: noon sun (55 deg up), a blue ambient, and
	SkylineGrade +0.35 saturation -- which turned the locked olives into saturated greens on screen.

	HOW IT WAS MEASURED: a swatch board on the Training Ground in Play (a client-side board, gone with the session), lit
	from the SIDE (view perpendicular to the sun: the average of a front-lit and a back-lit view), under the real lighting
	and grade: 12 probe inputs each as SmoothPlastic, Plaster and smoke-textured particles (LightInfluence 1, opaque), and 6
	Neon probes. Each swatch's displayed pixels were averaged (the central 55% of the disc), an affine model
	displayed = M * input + b was fitted per material (mean abs error: SmoothPlastic 7.6, Plaster 7.9, particles 6.5, Neon
	20 -- Neon clips toward white), and inverted for the targets below. Examples of what the locked hexes displayed as,
	side-lit: Gas #4B5A2A as Plaster -> #011700, as particles -> #2A5600; Membrane #8FA83E as SmoothPlastic -> #4A8400;
	Virulence #C3E82E as Neon -> #F9FB00. ForceField displayed near-white at every input (it reads emissive): dropped.

	TARGETS (the showcase's on-screen colours, measured from the renders by the lead and from the v4 frames):
	  gas body #626C47, lit crown #6E7A4F, base / shadow #3F4A2C, the deep core #2F3822 (darker than the base)
	  Virulence glow #B9E761 at its steady level
	  liquid #6B7A3A, its deep core #3F4A22, the pale wet highlight #D8E2A8
	  membrane #85945A through the middle, #949F76 at the lighter rim (c6_4)
	  the Vent's mask #5F8C3C (c2_2 / c2_7, the unlit green), dark #2F4A22, pale #7FA555
	The glow context (additive particles and PointLights) was not on the board: it is set against the cloud's measured
	glow patch instead. Every input below also passes the shipped-hex guard (ToxinFX checks the table on load). ]]
local rgb = Color3.fromRGB
T.Display = {
	-- gas lobes (Plaster, matte)
	-- (round 3: shifted toward green after the lead's read of a khaki cast -- membrane and liquid red -10% (membrane green
	-- lifted); the gas red -6% only: at -10% the cloud body measured #506F46 against the #626C47 target, too green. Was: a
	-- khaki cast on sun-facing surfaces; the membrane's green lifted too)
	Lobe = {
		GasCore = rgb(111, 114, 77), GasShadow = rgb(133, 134, 90), Gas = rgb(176, 169, 123), GasLit = rgb(192, 185, 134),
	},
	-- smoke particles on the gas (LightInfluence 1), the ground patch, the threads
	Particle = {
		GasCore = rgb(67, 72, 49), GasShadow = rgb(78, 84, 58), Gas = rgb(102, 108, 79), GasLit = rgb(111, 118, 86),
	},
	-- SmoothPlastic solids: liquid, the membrane, the mask
	Solid = {
		Liquid = rgb(151, 158, 97), LiquidDeep = rgb(107, 115, 69), LiquidSpec = rgb(235, 250, 196),
		Membrane = rgb(176, 190, 124), MembraneHi = rgb(189, 200, 146),
		MaskBody = rgb(167, 176, 101), MaskDark = rgb(108, 116, 68), MaskPale = rgb(198, 198, 124),
	},
	-- Neon: the lens rings, the canister seams, the Corroded rim line
	Neon = { Virulence = rgb(140, 175, 80) },   -- the solve gave (63,123,54) for a lit sphere; a thin ring or line shows
	                                             -- Neon nearer its raw colour (it read pure green), so this is set by eye on the ring
	-- additive glow particles and PointLights (judged on the cloud's glow patch, not solved)
	Glow = { Virulence = rgb(185, 225, 100) },   -- round 3: brighter, so the core patch reads (still 19+ off #CCF570)
}

-- M1: TOXIC BUBBLES. A membrane sac lobbed down the aim; it stops at the first enemy it hits (a direct hit pops it: a
-- single-target poison tick). A miss onto the ground rests there for RestLife, then expires. While one of the caster's
-- bubbles exists (flying or resting), Primary converts it.
T.Bubble = {
	ManaCost = 3,              -- PROPOSAL a throw (5.5/s at the fastest rate, under the 7/s regen)
	FireInterval = 0.55,       -- PROPOSAL (between Fireball's 0.6 and Icicle Shard's 0.333)
	Speed = 200, --[[one speed for every M1 projectile since 2026-10-17; was 90, and 60 before the balance pass]]                -- PROPOSAL studs/s out of the hand
	Gravity = 14,              -- PROPOSAL studs/s^2: a light lob (a flat throw from eye height carries ~50 studs)
	Radius = 1.0,              -- PROPOSAL the sac's radius, for hits (the look is drawn at this size)
	FlightLife = 2.5,          -- s: a bubble still flying this long (over a drop) just bursts, harmless
	Damage = 9,                -- PROPOSAL a direct hit's pop
	PoisonStacks = 1,          -- the Poisoned stacks a direct hit applies (StatusEffects' preset runs the DoT)
	RestLife = 4.5,            -- PROPOSAL s a missed bubble rests before it expires
	MaxLive = 6,               -- a caster's bubbles at once (the oldest resting one expires early)
	OriginSlack = 6,           -- server: studs the claimed release point may sit off the server's head (+ movement)
	StartAhead = 1.5,          -- studs in front of the eye where the sac forms
}

-- PRIMARY: CORROSIVE CLOUD. Converts the caster's newest live bubble into a lingering cloud at that exact point.
-- Precheck: with no live bubble the press costs nothing.
T.Cloud = {
	ManaCost = 25,             -- PROPOSAL (Undertow's and Immolate's 25)
	Cooldown = 9,              -- PROPOSAL
	Radius = 9,                -- PROPOSAL studs, flat
	Above = 8,                 -- the zone's top above the higher of the conversion point and the floor under it
	Below = 2,                 -- ...and its bottom under that floor
	FloorReach = 14,           -- a conversion in the air pools onto a floor this far below (else it hangs where it was)
	Duration = 6,              -- PROPOSAL s
	FormTime = 0.6,            -- s: the tear and the engorgement (the zone hurts from the tear on)
	Tick = 0.5,                -- s between ticks
	TickDamage = 3,            -- PROPOSAL a tick (6/s) on every enemy inside, plus the Poisoned refresh below
	PoisonStacks = 1,          -- a tick applies/refreshes this many Poisoned stacks (lingers after leaving)
}

-- PASSIVE: SYMBIOSIS. DoT the Toxin applies (Poisoned ticks, cloud ticks) heals it by a share of the health removed.
-- And the kit's baseline rule: Toxin takes REDUCED (not zero) damage from its own poison and clouds.
T.Symbiosis = {
	Lifesteal = 0.30,          -- PROPOSAL of the health a DoT tick actually removed
	ThreadEvery = 0.8,         -- s: the lifesteal thread is drawn at most this often per target
	SelfDamageMult = 0.40,     -- PROPOSAL own poison / cloud damage on yourself (0 while Antitoxin Vent is on)
	SelfTellEvery = 0.45,      -- s: the self-damage screen tell's shortest gap
}

-- ULTIMATE: PATIENT ZERO. Marks the enemy nearest the aim line; a telegraphed, growing aura with an accelerating
-- Virulence pulse, then a solid fuse; it detonates a poison cloud on wherever the target is at that moment.
-- VARIANT B: the radius is constant; damage and duration scale with the target's allies within AllyRadius (every other
-- body the caster may hurt -- in a duel or a team fight, the target's side). ChargeOnCatch: no target, no charge spent.
T.PatientZero = {
	Range = 60,                -- PROPOSAL the furthest a target can be marked
	LockRadius = 7,            -- PROPOSAL studs off the aim line a target may be
	Telegraph = 3.5,           -- PROPOSAL s from the mark to the detonation
	Fuse = 0.35,               -- the last part of it: the solid fuse (the pulse stops, held at full)
	PulseFrom = 0.6,           -- Hz at the mark
	PulseTo = 4.6,             -- Hz just before the fuse
	AuraFrom = 1.6,            -- studs, the aura's radius at the mark...
	AuraTo = 3.4,              -- ...and at the fuse
	Radius = 20,               -- PROPOSAL the detonation's radius (constant: Variant B). 2026-10-01: 12 -> 20 (owner: "the ult should be way larger"); 2.2x Corrosive Cloud, the Blender showcase's ratio
	BurstDamage = 18,          -- PROPOSAL the detonation's hit, unscaled (1v1)
	CloudDuration = 5,         -- PROPOSAL s the cloud lingers, unscaled
	CloudTickDamage = 4,       -- PROPOSAL a 0.5 s tick (8/s), unscaled -- plus the Poisoned refresh
	AllyRadius = 16,           -- PROPOSAL studs round the target an ally counts
	AllyCap = 3,               -- PROPOSAL at most this many allies scale it
	DamagePerAlly = 0.35,      -- PROPOSAL +35% burst and tick damage per ally
	DurationPerAlly = 1.5,     -- PROPOSAL +1.5 s cloud per ally
}

-- TECHNIQUE: ANTITOXIN VENT (the Mobility half of the pool, where Overgrowth Vault was). A gas mask; on cast an instant
-- cleanse of the caster's OWN poison, then zero self-damage from their own poison and free passage through their own
-- clouds while it is on. Own poison only: it never touches an enemy Toxin's poison.
T.Vent = {
	ManaCost = 20,             -- PROPOSAL
	Cooldown = 16,             -- PROPOSAL (Antidote Cloak was 17)
	Duration = 6,              -- PROPOSAL s the mask is on
	DoTReduction = 0.30,       -- while the mask is on, every DoT tick on you (burn, poison, clouds) hurts this much less
	                           -- (2026-10-17, the owner's pick: before, the Vent did nothing against a non-Toxin)
	AssembleTime = 0.35,       -- s: the mask drops on, then the lenses light
}

-- TECHNIQUE: ACID RAIN (the Defense half of the pool, where Antidote Cloak was). A poison downpour over a chosen area:
-- a light direct tick on everyone caught, and a stacking vulnerability ("Corroded") that amplifies Toxin's poison.
T.AcidRain = {
	ManaCost = 30,             -- PROPOSAL
	Cooldown = 14,             -- PROPOSAL
	Range = 50,                -- PROPOSAL
	Radius = 10,               -- PROPOSAL studs, flat
	Height = 14,               -- the cloud's height over the ground; the rain hurts from the floor to it
	GatherTime = 0.7,          -- s the cloud gathers before the first drops land
	RainTime = 4,              -- PROPOSAL s of downpour
	Tick = 1,                  -- s between ticks (4 ticks)
	TickDamage = 6, --[[4 until the 2026-10-17 balance pass]]            -- PROPOSAL the light direct tick
	VulnPerStack = 0.12,       -- PROPOSAL +12% Toxin poison damage per stack
	VulnMaxStacks = 4,         -- PROPOSAL
	VulnDuration = 6,          -- PROPOSAL s, refreshed by each stack
}

return T
