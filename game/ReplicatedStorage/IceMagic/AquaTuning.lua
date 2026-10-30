--[[
	AquaTuning  (ModuleScript)  ->  ReplicatedStorage/IceMagic/AquaTuning

	Every number in Aqua's kit (manual v0.14, Section 2; build prompt Opus55_Aqua_Element_Build.md, 2026-09-24), in one
	table the server (AquaHandler) and the clients (AquaClient, AquaFX) both read. Pure data, no requires.

	WHERE THE NUMBERS COME FROM. The build prompt gave playtest STARTING numbers, marked below as PROMPT. Everything else
	it left open and is marked STAND-IN: picked at build time against the live kits, to be tuned in play. Nothing here is
	final. The owner's answers to the Phase 1 audit are marked OWNER.
]]

local T = {}

-- The shape-stage palette (Phase 3): one placeholder look, opaque, Part colour. The real palette -- baked vertex colour
-- with tone and AO, the build prompt's Phase 4 -- replaces these.
-- OWNER (2026-09-26): "why is the water so white? Make it blue. Slightly darker blue. All around. Use the blue i sent in
-- the img", then "yes make the other aqua moves blue too". The image (a HUD bar drawn as waves) samples to #2690E4 main,
-- #1C74C3 mid, #0C4A92 navy, #4FBDF6 light, #B7DEF8 pale -- so the water went from teal and foam-white to these blues
-- (was Body 46,128,150 / Foam 226,244,240 / Trough 30,74,88 / Wet 24,48,56), and the Tideline accent with it (was the
-- prompt's cyan #3CE8E0, dim 22,96,94, dark 26,58,62): one constant each if the owner wants the cyan back.
T.Color = {
	Body = Color3.fromRGB(38, 144, 228),       -- #2690E4, the owner's blue: the body of the water
	Foam = Color3.fromRGB(183, 222, 248),      -- #B7DEF8, pale blue, only on broken water (no white)
	Trough = Color3.fromRGB(12, 74, 146),      -- #0C4A92, the navy trough
	Wet = Color3.fromRGB(20, 44, 74),          -- wet ground: dark navy and damp
	Tideline = Color3.fromRGB(79, 189, 246),   -- the accent, #4FBDF6 (the image's light wave-top blue), Neon while the water moves
	TidelineDim = Color3.fromRGB(20, 70, 120), -- the trail's dim ambient line (still Neon, low brightness)
	TidelineDark = Color3.fromRGB(18, 40, 70), -- the line gone dark: motion stopped (SmoothPlastic)
	Shark = Color3.fromRGB(34, 44, 52),
	Teeth = Color3.fromRGB(236, 232, 220),
	Debris = Color3.fromRGB(104, 98, 90),
	-- 2026-10-19 (the wrap plumbing): the line accents AquaFX kept as its own constants, moved here unchanged so one
	-- table holds every colour AquaFX draws in code (AquaWrap swaps a wrap's into it while that wrap's effect draws)
	UndertowTip = Color3.fromRGB(151, 218, 250), -- #97DAFA Undertow's arm tips: paler than the Tideline so the tip stands out
	Flash = Color3.fromRGB(183, 222, 248),       -- #B7DEF8 a line's flare: Undertow's flash, the gun's muzzle, the Maw's ring/rim
	TwinLine = Color3.fromRGB(38, 144, 228),     -- #2690E4 Neon: the Twin Tide lines (manifests line_colour)
	TwinLineDark = Color3.fromRGB(12, 74, 146),  -- #0C4A92 SmoothPlastic: a Twin Tide line gone dark (line_colour_dark)
	TwinFlash = Color3.fromRGB(79, 189, 246),    -- #4FBDF6 Neon: the jet's one flash (tt_jet.json flash_colour)
}

-- M1: Riptide. A crescent of whitewater surged along the ground; an aimed skillshot that follows the floor.
T.Riptide = {
	ManaCost = 4,              -- PROMPT ~4 a cast
	FireInterval = 0.667,      -- PROMPT up to ~1.5 casts a second: 6 mana/s at the fastest, under the 7/s regen
	Speed = 200, --[[one speed for every M1 projectile since 2026-10-17; was 100, and 70 before the balance pass]]                -- STAND-IN studs/s along the ground
	Range = 70,                -- STAND-IN studs
	Width = 7,                 -- STAND-IN the crescent's span, tip to tip
	Height = 3.5,              -- STAND-IN the crest above the floor: a jump clears it
	Damage = 12,               -- STAND-IN each character it passes through, once
	Pierce = 4,                -- STAND-IN characters one wave can hurt
	StartAhead = 2.5,          -- studs in front of the caster where it forms
	StepUp = 3,                -- a rise steeper than this in one step is a wall: the wave breaks on it
	StepDown = 8,              -- a drop deeper than this and the wave pours off the edge and is gone
	HitSlack = 2.5,            -- server: studs of lateral slack on a claimed hit (body width, a moving target)
	HeightSlack = 1.5,         -- server: studs over the crest a victim's feet may be and still be caught
	TrailWidth = 6,            -- the wet streak it leaves (Riding the Current)
}

-- Primary: Undertow. OWNER (2026-09-25, with a reference clip): "IT SHOULD BE INFRONT OF YOUR FACE, YOUR HANDS DOING THE
-- CIRCULAR ARC", and the pull: "stays in front of you". Your right hand draws a whirlpool disc in the air in front of
-- your face; at the snap every enemy in front of you (a cone along your aim) is pulled into it -- right up to you -- and
-- interrupted.
T.Undertow = {
	ManaCost = 25,             -- PROMPT ~25
	Cooldown = 9,              -- STAND-IN (between Bulwark Charge's 9 and Immolate's 12)
	Range = 36, --[[30 until the 2026-10-17 balance pass: now Undertow's Reach]]                -- the aim point the client sends (VFXLibrary row): only its DIRECTION is used now
	ConjureTime = 0.4,         -- PROMPT the hand draws the disc over this
	SnapTime = 0.6,            -- PROMPT the pull snaps here
	EndTime = 0.9,             -- STAND-IN the burst is over (the disc blows apart right after the snap)
	DiscDistance = 4.2,        -- OWNER "the spiral should be made closer to you" (was 6): the disc hangs this far in front
	                           -- of the caster's eye...
	DiscDrop = 0.35,           -- ...this much below the eye line
	DiscScale = 0.8,           -- ...drawn at this size (the kit's disc is 2.7 across the arm): closer at full size it
	                           -- covered 33 degrees of the 35-degree half view, at 0.8 it covers about 27 (was 24)
	MaxPitch = 30,             -- degrees the disc tilts with the aim, at most (it stands up)
	Reach = 36,                -- OWNER "the range of the primary should be increased" (was 24; STAND-IN) enemies this
	                           -- far in front of you are caught...
	ConeAngle = 35,            -- STAND-IN ...within this many degrees of your aim, and not through walls
	CatchSlack = 1.5,          -- server: the server's copy of a moving body trails the real one
	SweepEndSpeed = 260,       -- look: deg/s the disc turns at when the hand stops drawing...
	SweepAccel = 700,          -- ...and turns faster by this, deg/s^2, until the snap
	PullTime = 0.28,           -- STAND-IN the pull takes this long
	PullMaxSpeed = 125,        -- STAND-IN studs/s at most (was 85: over PullTime that carried a body only 24 studs, so
	                           -- with Reach 36 the far ones stopped short; 125 carries 35)
	PullLift = 6,              -- STAND-IN a little lift so the pull doesn't drag bodies into the floor
	PullForcePerMass = 900,    -- the mover's force, per unit of the body's mass
	InterruptTime = 0.5,       -- STAND-IN no casting for this long after the snap (and any hold is ended)
	Damage = 0,                -- the prompt gives Undertow no damage; kept as a knob
	PuddleRadius = 6,          -- the wet puddle left under the disc (Riding the Current)
}

-- Passive: Riding the Current. Your abilities leave wet ground; on your own you are faster, and an enemy on it slips.
T.Current = {
	SpeedBonus = 0.25,         -- STAND-IN +25% move speed while on your own wet ground
	WetLife = 3,               -- PROMPT the trail lasts ~3 s after it is laid
	SlipTime = 0.8,            -- PROMPT ~0.8 s
	SlipImmunity = 0.3,        -- STAND-IN after a slip ends; standing in it again slips again
	-- OWNER (2026-09-24): "very hard to walk... tough to redirect yourself but you still can". Low traction, not a
	-- lock: momentum carries you, and the keys bend it slowly. Traction is per second: the share of the gap between
	-- where you are going and where you are steering that closes each second (normal walking is effectively instant).
	-- On the ground only: in the air the slip stands down, so it can never fight a wall run or a double jump (both set
	-- the body's velocity themselves); landing while it lasts picks it up again from the velocity you land with.
	Traction = 1.3,            -- STAND-IN
	SlipForcePerMass = 3000,   -- the mover's grip, per unit of mass: it must beat the Humanoid's own walking
	ContactAbove = 3.5,        -- a body's feet this far above wet ground are over it, not on it (a jump clears it)
	ContactBelow = 2,
	OwnerGrace = 0.25,         -- the buff holds this long after you step off, so a seam between patches doesn't flicker it
	Tick = 1 / 20,             -- the server checks contact this often
}

-- Ultimate: Leviathan's Maw. Slam; the flood rises and a ring of wave-walls closes overhead into a glass tank; a shark
-- circles under the floor and lunges for the finish.
T.Maw = {
	Range = 45,                -- STAND-IN it is pointed, like Ring of Fire (60) and Cyclone (70)
	Radius = 22,               -- PROMPT ~22 studs
	WallHeight = 14,           -- STAND-IN the tank's wall before the roof curls in
	RoofRise = 7,              -- STAND-IN the roof climbs this much more to its peak: no leaving by jumping
	FloodTime = 0.6,           -- STAND-IN the flood rises over this
	FloodDepth = 1.4,          -- STAND-IN
	CloseTime = 1.2,           -- STAND-IN the walls have closed overhead by here: who is inside is trapped
	SharkRise = 3.3,           -- STAND-IN the fin breaks the surface
	LungeTime = 3.75,          -- STAND-IN the full shark breaks the surface and lunges (the server names its target)
	BiteTime = 4.05,           -- STAND-IN the bite lands (PROMPT: the lunge fires in the last ~1 s)
	ReleaseTime = 4.6,         -- PROMPT the tank holds ~4-5 s, then releases
	EndTime = 5.3,             -- the walls are down and the flood drained
	BiteDamage = 65,           -- STAND-IN a shark's bite, on its enemy
	MaxSharks = 6,             -- OWNER (2026-09-25): one shark per trapped enemy, each bitten separately; at most this many
	SurgeDamage = 25,          -- STAND-IN anyone trapped past MaxSharks takes this when the sharks bite
	BiteLift = 40,             -- STAND-IN the bitten are thrown up
	Panels = 20,               -- the wall ring's panels
	WallTransparency = 0.45,   -- THE ONE EXCEPTION (manual v0.14): the tank's wave-walls are see-through. Walls only.
	WetAfter = 3,              -- the floor stays wet this long after the release
}

-- Technique: Twin Tide. Two lower, narrower wave-walls close in on a lane from either side.
T.TwinTide = {
	ManaCost = 30, --[[40 until the 2026-10-17 balance pass]]             -- PROMPT ~40
	Cooldown = 16,             -- STAND-IN (Bulwark Wall's and Deep Freeze's 16)
	Range = 40,                -- STAND-IN the lane's centre can be this far off
	Length = 24,               -- STAND-IN the lane, along the aim
	StartGap = 22,             -- STAND-IN the walls start this far apart
	Height = 13,               -- OWNER (2026-09-24): 13 studs. A jump + double jump rises ~13.7, flagged.
	Thickness = 2,
	CloseTime = 1.1,           -- OWNER (2026-09-25) "they are way too sloww": the walls meet 1.1 s after the cast (was 2.5)
	BuildTime = 0.45,          -- the walls BUILD UP out of the ground over this as they start to close (the owner: "animate
	                           -- their build up")
	HoldTime = 0.35,           -- STAND-IN the walls stand met this long
	SinkTime = 0.6,            -- STAND-IN then sink away
	CrushHalfWidth = 5, --[[3.5 until the 2026-10-17 balance pass]]      -- STAND-IN who is this close to the centre line when they meet is crushed
	CrushSlack = 1.5,          -- server: the server's copy of a moving body trails the real one
	CrushDamage = 35,          -- STAND-IN
	CrushLift = 30,            -- STAND-IN the crushed are thrown up
}

-- Technique: Sidearm. A held water-gun. OWNER (2026-09-25) replaced the charge: "for the Tap move, it should look like
-- you hold out a gun and then shoot" and "if u keep holding it rapid fires bullets but takes mana in return", and "make
-- the bullets smaller". So: the press DRAWS the gun and holds it out, the first shot leaves DrawTime later (a tap is that
-- one shot); held on, it fires FireRate bullets a second, each paying BulletCost, until the key comes up or the mana runs
-- out; then the gun stays out Linger and is put away. The charged slug, and the launch that only it had, are gone.
T.Sidearm = {
	-- OWNER (2026-09-25, round 3): "make it much slower since all bullets should do knockback", "the first 12 dmg thing,
	-- remove that from the gun and its animation like it holds forward for a moment". Every shot is now the same bullet,
	-- slow, and every one that lands knocks its target back.
	TapCost = 6,               -- the press pays this (its VFXLibrary row's ManaCost) and it buys the first bullet
	DrawTime = 0.14,           -- STAND-IN the gun is drawn and held out this long before the first shot
	FireRate = 1.6,            -- OWNER "much slower": bullets a second while held (was 4, and 7 before that)
	BulletCost = 4, --[[6 until the 2026-10-17 balance pass]]            -- STAND-IN mana each bullet after the first (about 10 a second held, near the 7/s regen)
	Linger = 0.35,             -- STAND-IN after the last shot the gun stays out this long...
	HolsterTime = 0.15,        -- ...then is put away over this
	HoldMax = 12,              -- STAND-IN held this long, the hold lets go by itself
	HoldGiveUp = 15,           -- server: a hold with no release this long is ended
	Cooldown = 0.9,            -- STAND-IN from the release
	Speed = 160,               -- STAND-IN studs/s
	Range = 110,               -- STAND-IN
	BulletDamage = 8,          -- STAND-IN every bullet (the 12-damage first shot is gone)
	BulletScale = 0.5,         -- OWNER "make the bullets smaller": AK_SA_Slug drawn at this (was 1 to 1.6)
	KnockBack = 38,            -- OWNER "all bullets should do knockback": studs/s along the shot...
	KnockAir = 0.55,           -- ...and up: SECONDS the pop keeps a body off the ground (STAND-IN numbers). 2026-10-08: a
	                           -- time, where it was KnockUp = 16 studs/s. That was tuned at Gravity 196.2: 4.65 studs up,
	                           -- 0.55 s in the air -- down again before the next bullet (1 / FireRate = 0.625 s). At this
	                           -- place's 64 the same 16 hung a body 0.93 s, and sized to the same HEIGHT (KnockRise 4.65,
	                           -- today's first fix) still 0.84 s: a held Sidearm caught it in the air and lifted it again,
	                           -- bullet after bullet. AquaHandler sizes the speed to this time at workspace.Gravity (5.2
	                           -- studs/s at 64, a 1.5-stud pop). Keep it under 1 / FireRate
	PuddleEvery = 2,           -- a wet puddle under every other bullet's splash (and the first)
	KnockTime = 0.25,          -- every Aqua throw: held this long, then physics carries it
	KnockForcePerMass = 1400,
	HitSlack = 2.5,
	PuddleRadius = 2.2,
}

return T
