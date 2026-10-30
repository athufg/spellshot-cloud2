--[[
	VFXLibrary  (ModuleScript)  ->  ReplicatedStorage/IceMagic/VFXLibrary

	SPELLSHOT Cryo kit -- the finalized kit from design manual v0.2, Section 2.

	  Primary Ability   Flash Freeze   CastFlashFreeze(originPart, seed, caster)
	  M1                Icicle Shard   FireIcicleShard (Build Prompt #20 crystal cluster)
	  Mobility / Defense / Ultimate: Blizzard, Deep Freeze and Mirror Cage since 2026-09-24 (the Abilities rows below; drawn
	  by CryoFX). (2026-10-19, audit GB-04) Frost Slide (FrostSlideDashFX / FrostSlidePatch), Chill Aura (CastChillAura /
	  StopChillAura) and Cryo Beam (CryoBeamWindup, CastCryoBeam / Update / Stop) are RETIRED: no row casts them, and the
	  last two sit in do-blocks so their locals stay out of the main chunk's count. Tuning.CryoBeam / Tuning.FrostSlide are
	  still read (CastPose, Viewmodel, DashMotor) -- keep them.

	Glacial Spikes and Diamond Skin were cut with the v0.2 kit and their code is gone rather
	than commented out -- a retired ability that still has a live cast path is exactly the
	"lingering content" the finalize pass was meant to remove. Their meshes are still in the
	place (GlacialSpike_*, ChestPlate, Bracer, ...) and are simply no longer referenced.

	TOON RULES (why things are set the way they are):
	  * Meshes carry 3-step flat colour bands baked into vertex colours in Blender, plus an
	    inverted-hull outline shell.  That shell only reads as an outline while backfaces are
	    culled, so every crystal MeshPart must keep DoubleSided = false.
	  * MeshPart.Color stays white and Material stays SmoothPlastic: any tint multiplies the
	    baked bands, and Ice/Glass/Neon add sparkle or blow-out that destroys the flat read.
	    One deliberate exception: the Frost Slide patch tints its copies of the Flash Freeze sheet
	    and rim crystals (Tuning.FrostSlide.PatchTint) so its ice reads sky blue -- still flat bands:
	    light faces (158,216,245), mid faces and the lip (46,160,231); the Flash Freeze zone itself
	    stays white.
	  * Crystals are opaque.  Transparency lets you see the black inside of the outline shell,
	    so fades are kept short and spikes are hidden by sinking into the ground instead.
	  * Particles use a hard-edged shard sprite, not soft round dust.

	Roblox has no toon/outline post-process (verified: no OutlineEffect / ToonEffect /
	EdgeDetectEffect class exists), which is why the outline is real geometry.

	CRYO v2 (2026-10-08): Flash Freeze, the Icicle Shard shot and the frozen look draw the approved real-ice look
	instead of the toon rules above -- milky translucent Ice-material crystals, a white matte frost skin, and the
	saturated Frost Line (#3FE0FF) as the one accent (vfx_blocking/cryo/ice_v2/CRYO_V2_HANDOFF.md, RECIPE.md).
	See the PRIMARY ABILITY: FLASH FREEZE and M1: ICICLE SHARD sections.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

local VFXLibrary = {}

----------------------------------------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------------------------------------
VFXLibrary.Config = {
	MeshFolderName = "IceMagicMeshes",
	FXFolderName = "IceMagicFX",
	SoundFolderName = "Sounds",

	-- Which local axis of an imported plate MeshPart points AWAY from the body.
	-- Confirmed in Studio with the marker cube: Blender front lands on the MeshPart's -Z.
	PlateFrontAxis = -1,

	-- Flat + untinted so the baked vertex bands survive untouched.
	CrystalMaterial = Enum.Material.SmoothPlastic,
	CrystalColor = Color3.new(1, 1, 1),

	Textures = {
		-- Custom toon sprites (generated locally, uploaded through Studio).
		Shard     = "rbxassetid://98211061341574",    -- chunky angular ice chunk, hard outline
		FrostTile = "rbxassetid://115444386281258",   -- seamless flat ice-crystal ground pattern
		-- Cold Momentum footfall marks: flat comic sprites (tools/make_frost_marks.py)
		FrostMark = { "rbxassetid://137825239084480", "rbxassetid://84586295539491", "rbxassetid://87084861956833" },
		-- Icicle Shard impact: a compact flat frost-burst (tools/make_shard_impact.py)
		ShardBurst = "rbxassetid://93429522929420",
		-- Roblox built-ins, still the right tool for soft volumetrics and glows.
		Fog       = "rbxasset://textures/particles/explosion01_smoke_main.dds",
		Smoke     = "rbxasset://textures/particles/smoke_main.dds",
		Glow      = "rbxasset://textures/particles/explosion01_implosion_main.dds",
		Core      = "rbxasset://textures/particles/explosion01_core_main.dds",
		Sparkle   = "rbxasset://textures/sparkle.png",
		Ring      = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
		Gradient  = "rbxasset://textures/gradient.png",
	},

	-- Real Roblox audio, inserted into ReplicatedStorage.IceMagic.Sounds so the place owns
	-- the playback permission. Swap the assets there, not here.
	Sounds = {
		NovaSlam    = { Name = "SFX_GroundBoom",   Volume = 0.90, Speed = 0.92 },
		NovaFrost   = { Name = "SFX_IceShatter",   Volume = 0.45, Speed = 0.80 },
		Shatter     = { Name = "SFX_IceShatter",   Volume = 0.85, Speed = 1.25, Spread = 0.10 },
		SlideStart  = { Name = "SFX_GlassShatter", Volume = 0.40, Speed = 0.75, Spread = 0.10 },
		-- a Frost Slide patch breaking at the end of its life: the shatter, lighter and quicker
		PatchBreak  = { Name = "SFX_IceShatter",   Volume = 0.35, Speed = 1.35, Spread = 0.10 },
		AuraOn      = { Name = "SFX_IceShatter",   Volume = 0.50, Speed = 0.70 },
		-- the Ultimate windup is the telegraph, so it gets a long descending cue rather than a hit
		UltCharge   = { Name = "SFX_GroundBoom",   Volume = 0.55, Speed = 0.55 },
		UltFire     = { Name = "SFX_GroundBoom",   Volume = 1.00, Speed = 1.30 },
	},

	-- Flat toon palette, matching the bands baked into the meshes.
	Colors = {
		IceDeep  = Color3.fromRGB(14, 79, 168),
		IceMid   = Color3.fromRGB(63, 182, 240),
		IceLight = Color3.fromRGB(214, 246, 255),
		Rim      = Color3.fromRGB(255, 255, 255),
		Outline  = Color3.fromRGB(8, 14, 26),
	},
}

VFXLibrary.Tuning = {
	-- Flash Freeze is the old Absolute Zero asset under its v0.2 name and slot. The zone
	-- behaviour is the manual's: linger past LingerToRoot and you are rooted, and if you are
	-- still frozen when the zone ends it shatters you for ShatterDamage.
	FlashFreeze = {
		-- CastRange (2026-10-18, P29): the zone lands where the crosshair points, at most this far from the caster (the
		-- row's Range, so the client's aim reaches the same). 0 = round the caster's feet, as it was until then.
		CastRange = 20,
		Radius = 20, ExpandTime = 1.0, RimLinger = 3.5, CrustBudget = 60,
		FrozenDuration = 4.0, LeadIn = 0.38,
		LingerToRoot = 1.0,
	},
	-- Cold Momentum's footfall marks (blocking: vfx_blocking/cryo/03_cold_momentum): one per step
	-- while the buff is up, so the trail is dashed by the stride itself.
	ColdMomentum = { MarkLife = 0.85, MarkPop = 0.08, MarkOut = 0.25, MarkWidth = 0.8, MarkLength = 1.4, MarkYaw = 14 },
	-- Frost Slide is a DASH that leaves a trap (blocking: cryo_blocking/block_04_mobility_dash.py). The
	-- travel is only delivery: the patch of ground the caster leaves freezes over, and anyone who steps
	-- on it is frozen on contact -- no slip, no slow. Three charges (see Abilities).
	--   Dash*     the move, run by DashMotor on the caster's own client: DashDistance studs in DashTime,
	--             cut off at DashMaxTime, and refused outright under a DashMinCap speed cap.
	--   Patch*    forms where the dash STARTED, out to PatchRadius over PatchForm (FrostSlidePatchRadiusAt
	--             -- the server's contact test runs on that same curve), and breaks after PatchLife.
	--   Frozen / FreezeImmunity / Contact*   the server's contact freeze: held FrozenDuration, and the
	--             same victim cannot be caught again until FreezeImmunity after the thaw. Standing on the
	--             patch is feet within ContactReach of its rim and between ContactBelow under and
	--             ContactAbove over its surface.
	--   Line*     the solid frost line under each foot, LineSpacing either side of the dash path: LineWidth
	--             of fill on LineInk of outline, held LineHold after the dash, then pulled thin over LineOut.
	--   BreakShards  sprites in the patch's break (halved when thinned).
	--   PatchTint the patch's ice, tinted from the kit's near-white toward sky blue, on the sheet and its
	--             rim crystals alike. It multiplies the baked bands, so light faces read light ice blue, mid
	--             faces and the lip one deeper blue, and the ink stays ink. (Flash Freeze is untouched.)
	--   Crack*    the break is told before it happens: CrackLead seconds before the patch goes, Flash
	--             Freeze's crack ink races across it from the middle, over CrackSpread. Scaled to the patch
	--             the strokes are about a quarter as wide as in the zone: clear up close, thin past ~20 studs.
	FrostSlide = {
		DashDistance = 13, DashTime = 0.2, DashMaxTime = 0.32, DashMinCap = 16,   --[[DashMinCap 12 until the 2026-10-17 balance pass]]
		PatchRadius = 5.5, PatchForm = 0.25, PatchLife = 4.0,
		FrozenDuration = 4.0, FreezeImmunity = 1.2, ContactReach = 0.6, ContactBelow = 1.75, ContactAbove = 1.5,
		LineWidth = 0.34, LineInk = 0.07, LineSpacing = 0.5, LineHold = 0.8, LineOut = 0.25,
		BreakShards = 14, LeadIn = 0,
		PatchTint = Color3.fromRGB(188, 224, 245), CrackLead = 0.6, CrackSpread = 0.22,
	},
	-- Chill Aura v2 (2026-09-14): the reference sequence built to FORM in place (see CastChillAura). Radius, Duration,
	-- TickRate and LeadIn are gameplay (the server reads them); the rest is the look. Piece-by-piece forming and
	-- un-forming windows live in IceMagic.ChillAuraData.
	--   Spin*       rad/s anticlockwise from above, from ChillAuraData.SpinStart: the wind overtakes the crystals
	--   Mist*       the FrostTile disc: radius, tile size (held still while the radius grows), grow and recede windows
	--   Snow*       the Shard flakes: spawn shell radius, band height and base, rate, on/off times
	--   EdgeQuick / OutQuick   un-forming time after an early stop (caster death): the edge, and everything else
	--   OwnWindOut  the caster's OWN swooshes: formed by 0.70, held a moment, then wiped away over this window (s after
	--               the cast) -- in first person they cross the view for the whole zone; everyone else keeps seeing them
	--   HeadTop, FloorProbe, FloorEvery, MaxTilt   the floor under the caster and how far the hit sphere reaches it
	ChillAura = {
		Radius = 8.0, Duration = 6.0, TickRate = 0.35, LeadIn = 0.12,
		SpinOrbit = 0.6, SpinVortex = 1.0,
		MistRadius = 7.5, MistTile = 5, MistLift = 0.012, MistIn = { 0.12, 0.50 }, MistOut = { 5.45, 5.85 },
		SnowShell = 5.5, SnowHeight = 5.2, SnowBase = 0.8, SnowRate = 5, SnowOn = 0.62, SnowOff = 5.35,
		EdgeQuick = 0.15, OutQuick = 0.25, OwnWindOut = { 0.95, 1.30 },
		HeadTop = 5.2, FloorProbe = 14, FloorEvery = 0.1, MaxTilt = 20,
	},
	-- The Ultimate's three beats. Windup is deliberately long and loud: the manual files
	-- Cryo Beam under the same "must be predicted and dodged" philosophy as Meteor Storm.
	-- LevitateHeight / LevitateTime / ChargeTime / FireTime are gameplay (the server reads them); the rest is the v2 look
	-- (see CastCryoBeam; the layout is in IceMagic.CryoBeamData.Look):
	--   *Spin        rad/s: ground ring, rune rings, star (focus / at the hand), vortex, muzzle ring, rings, crown, halo
	--   Grow         studs/s the drawn beam tears out and pulls back at
	--   TileSpeed    studs/s the shard tiles and the swirl travel; RibRoll rad/s the ribbon strands roll; SwirlSpin
	--   RingEvery / RingSpeed, TrailEvery / TrailSpeed   the travelling rings and frost trails
	--   OwnArcWipe / OwnMuzzleWipe   the caster's own arcs and muzzle ring are wiped over these windows (first person)
	--   NearCamera, VictimCut        no crown within NearCamera of your camera; a beam at you stops VictimCut short
	--   StopQuick    un-forming after a stop in the windup; Watchdog: a missing CryoBeamStop is assumed this late
	CryoBeam = {
		LevitateHeight = 4.5, LevitateTime = 0.40, ChargeTime = 1.35, FireTime = 2.4,
		GroundSpin = 1.6, RuneWSpin = -0.9, RuneCSpin = 1.2, StarSpin = 3.0, MuzzleStarSpin = 4.0, VortexSpin = 5.0,
		Grow = 400, TileSpeed = 16, RibRoll = 11.8, SwirlSpin = 8.0, MuzzleSpin = 2.4,
		RingEvery = 0.40, RingSpeed = 45, RingSpin = 3.0, TrailEvery = 0.18, TrailSpeed = 60,
		CrownSpin = 1.2, HaloSpin = -2.0, OwnArcWipe = { 1.05, 1.20 }, OwnMuzzleWipe = { 2.02, 2.12 },
		NearCamera = 4.5, VictimCut = 3.0, StopQuick = 0.20, Watchdog = 0.45, FloorProbe = 30, FloorEvery = 0.1,
	},
	-- Icicle Shard (Build Prompt #20; see FireIcicleShard). Speed and Range are read by the server too.
	IcicleShard = {
		Speed = 200, Range = 120,   --[[one speed for every M1 projectile since 2026-10-17 (200); was 220, and 170 before the balance pass]]
		Merge = 0.1,             -- seconds for the shard you see to ease from the hand onto the true path
		CrystalLength = 3.6,     -- tip to heel of the shard as drawn (CRYO v2: one long thin shard, 3.3-3.9 studs; was 1.5)
		FormTime = 0.06, FormFrom = 0.7,    -- the cluster forms at the hand: scale 0.7 -> 1
		-- your OWN shot flies straight down your crosshair, so past OwnShrinkFrom studs it eases down to
		-- OwnFarScale over OwnShrinkOver studs rather than sitting on the target you are shooting at.
		-- Everybody else sees it full size.
		OwnFarScale = 0.45, OwnShrinkFrom = 12, OwnShrinkOver = 14,
		StreakMax = 4.0,         -- (unused since CRYO v2: the Frost Line Trail replaced the IS_Streak tracer part)
		CastFragments = 0,       -- stray Shard sprites off the palm on release (0 since the grounded pass, 2026-09-24)
		ImpactFragments = 6,     -- the shatter's cap (halved when thinned)
		BurstSize = 2.0,         -- studs across the impact frost-burst at its peak (0.7x thinned)
		BurstNear = 4.0,         -- an impact closer than this to the camera plays at the smallest size
		-- the plain ice rod drawn if the mesh is not in the place
		Length = 3.6, Width = 0.17, Color = Color3.fromRGB(143, 207, 240),
	},
	-- the beam renderer's own numbers, shared by the Ultimate
	Beam = { MaxRange = 60, Smoothing = 0.35 },
	-- FPS readability: the caster's own ground VFX must not become a wall in front of the camera
	Fade = { Near = 4.5, Far = 9.0 },
}

-- Every ability with a cast path, whichever kit it comes from. Role is what the HUD and the input script
-- bind against; the digit-row keybinds the prototype used are gone, because a SPELLSHOT loadout is
-- Role-shaped (M1 / Primary Ability / Mobility / Defense / Ultimate), not a four-slot hotbar.
--   Element     on an M1 or Primary Ability: the Element bundle it comes with
--   no Element  a Technique: its Id is its key in the SpellshotConfig pool, which is what the player's
--               Mobility / Defense / Ultimate attribute holds
-- What a PLAYER holds in a slot is VFXLibrary.AbilityFor(player, role): a Cryo player may run Detonate (with
-- Config.TechniquesOwnElementOnly off; P31, 2026-10-18, keeps each Element to its own). (2026-10-19, audit P4-14)
-- the rebuilt Cryo Techniques' and Ultimate's numbers (2026-09-24): CryoTuning, pure data, no requires
local CRYO = require(script.Parent:WaitForChild("CryoTuning"))
-- ...and Aqua's (2026-09-24): AquaTuning, pure data, no requires
local AQUA = require(script.Parent:WaitForChild("AquaTuning"))
-- ...and Umbra's (2026-09-27): UmbraTuning, pure data, no requires
local UMBRA = require(script.Parent:WaitForChild("UmbraTuning"))
-- ...and Radiant's (2026-09-29): RadiantTuning, pure data, no requires
local RADIANT = require(script.Parent:WaitForChild("RadiantTuning"))
-- ...and Toxin's (2026-09-30): ToxinTuning, pure data, no requires
local TOXIN = require(script.Parent:WaitForChild("ToxinTuning"))

VFXLibrary.Abilities = {
	-- Cryo
	{ Id = "IcicleShard", Element = "Cryo", Role = "M1", Name = "Icicle Shard",
	  -- a RATE, not a cooldown: one shot per click, at most one every FireInterval (3/s).
	  -- ManaCost is a trickle: 2 a shot is 6/s at the fastest tapping, under the 7/s regen, so M1
	  -- alone can never empty the bar, and it is never refused for want of mana.
	  Cooldown = 0, FireInterval = 0.333, ManaCost = 2, Range = 120, Targeted = true, Implemented = true },
	{ Id = "FlashFreeze", Element = "Cryo", Role = "Primary", Name = "Flash Freeze",
	  Cooldown = 14, ManaCost = 30, Range = VFXLibrary.Tuning.FlashFreeze.CastRange, Targeted = true, --[[self-centred until 2026-10-18]]
	  Implemented = true },
	-- 2026-09-24: Blizzard, Deep Freeze and Mirror Cage REPLACE Frost Slide, Chill Aura and Cryo Beam (the owner:
	-- "implement them in the game"). The old three keep their code but have no row, so nothing casts them; keep
	-- Tuning.FrostSlide (DashMotor's default dash) and Tuning.CryoBeam (CastPose and Viewmodel read it on load).
	-- No Element on a Technique row (AbilityFor refuses one). Deep Freeze and Blizzard take the plain cooldown path;
	-- Mirror Cage is ChargeOnCatch: the meter is spent by AbilityHandler only when a cage forms.
	{ Id = "Blizzard",   Role = "Mobility", Name = "Blizzard",
	  Cooldown = CRYO.Blizzard.Cooldown, ManaCost = CRYO.Blizzard.ManaCost,
	  Range = CRYO.Blizzard.CastRange, Targeted = true, --[[self-centred until 2026-10-18]] Implemented = true },
	{ Id = "DeepFreeze", Role = "Defense",  Name = "Deep Freeze",
	  Cooldown = CRYO.DeepFreeze.Cooldown, ManaCost = CRYO.DeepFreeze.ManaCost, Implemented = true },
	{ Id = "MirrorCage", Role = "Ultimate", Name = "Mirror Cage",
	  Range = CRYO.MirrorCage.Range, Targeted = true, ChargeOnCatch = true, Implemented = true },

	-- Pyro (Build Prompt #21 wiring, 2026-09-14): PyroFX draws it, PyroHandler makes it hurt. The numbers
	-- are stand-ins chosen at wiring time; the manual sets none of them.
	{ Id = "Fireball",    Element = "Pyro", Role = "M1", Name = "Fireball",
	  -- a RATE, like Icicle Shard. 3 mana a throw is 5/s at the fastest rate, under the 7/s regen, so the M1
	  -- alone never empties the bar and is never refused for want of mana. Range is only how far the aim ray
	  -- reaches: the shot itself flies straight on past it until its Life runs out (PyroFX.Tuning.Fireball).
	  Cooldown = 0, FireInterval = 0.6, ManaCost = 3, Range = 110, Targeted = true, Implemented = true },
	{ Id = "Immolate",    Element = "Pyro", Role = "Primary", Name = "Immolate",
	  Cooldown = 12, ManaCost = 25, Implemented = true },
	-- CIRCLE: pointed -- the cast carries the ground spot under the crosshair (pulled in to Range), and the hand
	-- draws the circle round it by itself
	{ Id = "RingOfFire",  Role = "Ultimate", Name = "Ring of Fire",
	  Range = 60, Circle = true, Implemented = true },
	-- DETONATE (2026-09-23; a Pyro-ONLY Technique, Pyro's default in Q, since 2026-09-24): marks whoever you last hit with
	-- Fireball or Immolate; the mark explodes after a fuse, harder the lower their health. Precheck: refused at no cost
	-- when there is no target.
	{ Id = "Detonate", Role = "Mobility", Name = "Detonate",
	  Cooldown = 14, ManaCost = 20, Precheck = true, Implemented = true },
	-- SCORCHING LASH (2026-09-23; any Element's Technique with Config.TechniquesOwnElementOnly off -- P31: Pyro's only;
	-- audit P4-14, 2026-10-19 -- Pyro's default in E, since 2026-09-24): HELD since 2026-09-24 --
	-- the key going down puts a burning whip in the hand, coming up cracks it where you aim (35 studs); the cooldown runs
	-- from the release. HoldMax: seconds before a hold lets go by itself. Stacking burn.
	{ Id = "ScorchingLash", Role = "Defense", Name = "Scorching Lash",
	  Cooldown = 5, ManaCost = 12, Held = true, HoldMax = 6, Implemented = true },   --[[Cooldown 2.5 until the 2026-10-17 balance pass]]

	-- Zephyr (2026-09-15): ZephyrFX draws it, ZephyrHandler handles the casts. The M1's and Primary's numbers are stand-ins
	-- picked at build time (ZephyrFX.Tuning.WindBlade / CrossSlash). THE v6 IMPORT (2026-10-06): the glow look replaces
	-- the toon ink (ZephyrDraw), and Skyrider, Gust Pad and Updraft replace Gust Jump and Deflect Gust and unlock the
	-- Passive -- their rows below; their servers are ZephyrSkyriderServer / ZephyrGustPadServer / ZephyrUpdraftServer,
	-- their client halves come in through ZephyrClient, and their numbers are each module's Tuning.
	{ Id = "WindBlade",   Element = "Zephyr", Role = "M1", Name = "Wind Blade",
	  -- a RATE, like the other M1s, and the fastest: 0.8 mana a blade is 6.7/s at the full rate, under the 7/s regen,
	  -- so the M1 alone never empties the bar. Range is the blade's own reach (it wipes there).
	  Cooldown = 0, FireInterval = 0.12, ManaCost = 0.8, Range = 80, Targeted = true, Implemented = true },
	-- Cross-Slash Dash (2026-09-16): charge, glide along the aim with the hands behind, X stamped at the end. The dash is
	-- the caster's client's (DashMotor, with a spec), so SpellshotInput takes it by Id rather than the generic path.
	-- HELD since 2026-09-17 (hold to charge), on SpellshotService's held path: the press pays the mana and starts the
	-- charge, the release launches the dash, and the cooldown runs from the release (or from a charge that was dropped).
	{ Id = "CrossSlashDash", Element = "Zephyr", Role = "Primary", Name = "Cross-Slash Dash",
	  Cooldown = 10, ManaCost = 25, Held = true, Implemented = true },
	-- Updraft (2026-10-06, the v6 import), Zephyr's Passive: no cast, no cooldown and no mana -- a row for Bedrock's reason.
	-- While airborne its holder's damage and Zephyr knockbacks are scaled up (ZephyrUpdraftServer, ZephyrUpdraft.Tuning).
	-- Deflect Gust (2026-09-16) and Gust Jump (2026-09-17) had rows here; both were retired on 2026-10-06 (their code:
	-- ServerStorage.ZephyrKitSuperseded.v6_2026_10_06), replaced by Gust Pad and Skyrider below.
	{ Id = "Updraft", Element = "Zephyr", Role = "Passive", Name = "Updraft", Implemented = true },
	-- Gust Pad (2026-10-06, the v6 import), Zephyr's Defense Technique: a pad pressed into the ground under the crosshair
	-- (Targeted, Range 40: the generic path carries the aim point, ZephyrGustPadServer snaps it to the floor) that
	-- launches whoever steps on it straight up. Precheck (Aftershock's pattern): ZephyrGustPadServer's Precheck_GustPad
	-- refuses a spot with no floor before anything is spent. -- PROVISIONAL (v6 import): Cooldown 14, ManaCost 20, Range 40.
	{ Id = "GustPad", Role = "Defense", Name = "Gust Pad",
	  Cooldown = 14, ManaCost = 20, Targeted = true, Range = 40, Precheck = true, Implemented = true },
	-- Skyrider (2026-10-06, the v6 import), Zephyr's Mobility Technique: summon a bird of wind and ride it. HELD, Gust
	-- Jump's arrangement: the press pays and starts the ride (ZephyrSkyrider's LocalCast, through ZephyrClient), and the
	-- RELEASE -- sent when the ride ends, not when the key comes up -- starts the cooldown; the ride drains mana as it
	-- goes (ZephyrSkyriderServer). -- PROVISIONAL (v6 import): Cooldown 12, ManaCost 15.
	-- Precheck (2026-10-19, audit P4-01): a press the server would refuse (Stunned, Entombed, Hub) is refused before it
	-- is paid. Refused after paying, it was given back without its +6% Ultimate and still broke an Earthen Tomb.
	{ Id = "Skyrider", Role = "Mobility", Name = "Skyrider",
	  Cooldown = 12, ManaCost = 15, Held = true, Precheck = true, Implemented = true },

	-- Terra (2026-09-17): TerraFX draws it, TerraHandler handles the casts. EVERY NUMBER IN THESE ROWS IS NEW --
	-- the manual gives Terra behaviour and no figures, and SpellshotConfig had none for it either (only
	-- SpellshotConfig.Defense.BulwarkWall's 16 s, which the Wall's own row dropped on 2026-09-20 for a mana
	-- drain -- see it below). The rest of each ability's numbers are
	-- TerraFX.Tuning.
	-- Boulder Shot: the game's one CHARGEABLE M1 -- hold to gather, release to throw. FireInterval is the floor
	-- between throws, not a rate to hold down: the charge is the pacing. The slowest M1 there is (Wind Blade 0.12,
	-- Icicle Shard 0.333, Fireball 0.6) and the hardest hitting, which is the manual's read on Terra. ManaCost 4 a
	-- throw is 4.7/s at the fastest possible tapping, under the 7/s regen, so the M1 alone never empties the bar.
	{ Id = "BoulderShot", Element = "Terra", Role = "M1", Name = "Boulder Shot",
	  Cooldown = 0, FireInterval = 0.85, ManaCost = 4, Range = 120, Targeted = true, Implemented = true },
	-- Bulwark Charge: the press charges forward and knocks down whatever it reaches. NEW numbers -- 9 s sits
	-- between Immolate's 12 and Cross-Slash Dash's 10, and 30 mana is the dearest Primary in the game, which is
	-- the trade for a Primary that is an escape, a mitigation window and an opener at once.
	{ Id = "BulwarkCharge", Element = "Terra", Role = "Primary", Name = "Bulwark Charge",
	  Cooldown = 9, ManaCost = 30, Implemented = true },
	-- Bedrock, the Passive: no cast, no cooldown and no mana -- it is a row so AbilityFor(player, "Passive")
	-- resolves it and TerraHandler can tell a Terra apart from anyone else wearing the kit's Techniques.
	{ Id = "Bedrock", Element = "Terra", Role = "Passive", Name = "Bedrock", Implemented = true },
	-- Bulwark Wall (2026-09-19; ON MANA, NOT A COOLDOWN, since 2026-09-20 on request), Terra's Defense Technique -- the one
	-- wall in the game. HELD, on SpellshotService's held path: the key going down raises it and pays; it
	-- stands until the key comes up, until the BAR RUNS DRY (TerraFX.Tuning.BulwarkWall.ManaPerSecond drains while it is
	-- up), or until it has absorbed its WallHP. Cooldown 0: there is none -- mana is the whole limit, so a wall costs what
	-- it is worth rather than locking the slot for 16 s. That SUPERSEDES the manual's 16 s
	-- (SpellshotConfig.Defense.BulwarkWall). ManaCost 10 to raise is PROPOSED (it was 25 when the raise was the whole
	-- cost).
	{ Id = "BulwarkWall", Role = "Defense", Name = "Bulwark Wall",
	  Cooldown = 0, ManaCost = 10, Held = true, Implemented = true },
	-- Aftershock (2026-09-25, on request: "import it in roblox for terra replacing mobility of it"), Terra's Mobility
	-- Technique -- it REPLACES Tremor Vault, whose row, cast path, tuning and look are deleted rather than disabled (the
	-- Glacial Spikes precedent; its TerraVault meshes stay in the place, unreferenced). A PRESS, not a hold: both fists go
	-- into the ground Hit (0.68 s) after the key, and a ring of erupting rock races out 24 studs, throwing back and
	-- interrupting everyone it reaches. TerraHandler hits, TerraFX draws it, and its numbers are TerraFX.Tuning.Aftershock.
	-- Precheck (Detonate's pattern): refused at no cost with no floor under the feet, Entombed, or already in one. Cooldown
	-- 12 is Tremor Vault's (the manual's); ManaCost 20 is PROPOSED.
	{ Id = "Aftershock", Role = "Mobility", Name = "Aftershock",
	  Cooldown = 12, ManaCost = 20, Precheck = true, Implemented = true },
	-- Cyclone (2026-09-17), Zephyr's Ultimate Technique: a tornado at the crosshair's ground spot, steered while it forms,
	-- then pulling and hurting where it formed (ZephyrHandler; ZephyrFX draws it, and its numbers are
	-- ZephyrFX.Tuning.Cyclone). Gated like every Ultimate, by the charge alone. SpellshotInput takes it by Id (the steering).
	-- Range 70 is ASSUMED (the owner's "e.g. 70"; the other pointed Ultimate, Ring of Fire, has 60).
	{ Id = "Cyclone", Role = "Ultimate", Name = "Cyclone",
	  Range = 70, Implemented = true },
	-- Earthen Tomb (2026-09-19; v2, the redesign, the same day), Terra's Ultimate Technique -- it REPLACES Seismic Slam,
	-- which never had a cast path. The cast LOCKS the enemy nearest the aim line and a fissure homes on them; caught, the
	-- target alone is raised in a stone fist and crushed at the top (TerraHandler; TerraFX draws it, its numbers are
	-- TerraFX.Tuning.EarthenTomb). ChargeOnCatch: the charge is checked on the cast and SPENT only when the fissure catches
	-- someone (SpellshotService). Range 40 is PROPOSED: the furthest a target can be to lock at all -- about half again
	-- Bulwark Charge's 26-stud reach, and 0.67 s of fissure at 60 studs/s. (v1 was an aimed line with Range 60.)
	{ Id = "EarthenTomb", Role = "Ultimate", Name = "Earthen Tomb",
	  Range = 40, Targeted = true, ChargeOnCatch = true, Implemented = true },

	-- VOLTAIC (2026-09-25): VoltaicHandler is its server, VoltaicClient its client half; ChainBoltFX / OverchargeFX /
	-- RailspikeFX / VoltOrbFX / VoltaicFX (Cascade) draw it; every number past these rows is VoltaicTuning's (STAND-INs
	-- for the owner to tune). Literal numbers on purpose: this module must not wait on a Voltaic module. Chain Bolt is a
	-- RATE like every M1: 2 mana a shot is 6.25/s at the fastest, under the 7/s regen. SpellshotInput takes Chain Bolt
	-- (fireShard) and Overcharge's dash (tryCast) through VoltaicClient.
	{ Id = "ChainBolt", Element = "Voltaic", Role = "M1", Name = "Chain Bolt",
	  Cooldown = 0, FireInterval = 0.32, ManaCost = 2, Range = 55, Implemented = true },   -- (2026-10-18: 55, VoltaicTuning's; was 30, and 10 until 2026-10-13)
	{ Id = "Overcharge", Element = "Voltaic", Role = "Primary", Name = "Overcharge",
	  Cooldown = 9, ManaCost = 18, Implemented = true },
	{ Id = "ChainReaction", Element = "Voltaic", Role = "Passive", Name = "Chain Reaction", Implemented = true },
	{ Id = "Railspike", Role = "Mobility", Name = "Railspike",
	  Cooldown = 10, ManaCost = 20, Range = 90, Implemented = true },
	{ Id = "VoltOrb", Role = "Defense", Name = "Volt Orb",
	  Cooldown = 12, ManaCost = 20, Range = 60, Targeted = true, Implemented = true },
	{ Id = "Cascade", Role = "Ultimate", Name = "Cascade",
	  Range = 60, Targeted = true, Implemented = true },

	-- AQUA (2026-09-24), manual v0.14: AquaHandler is its server, AquaClient its client half, AquaFX draws it, and every
	-- number is AquaTuning's (stand-ins unless marked there). SpellshotInput takes Riptide by Id (fireShard), and Sidearm's
	-- shot rides on its held release (AquaClient.ReleasePayload). Riding the Current is a row for the same reason Bedrock
	-- is: AbilityFor(player, "Passive") resolves it. Twin Tide and Sidearm are Aqua's only (SpellshotConfig: Exclusive).
	{ Id = "Riptide", Element = "Aqua", Role = "M1", Name = "Riptide",
	  Cooldown = 0, FireInterval = AQUA.Riptide.FireInterval, ManaCost = AQUA.Riptide.ManaCost, Range = AQUA.Riptide.Range,
	  Implemented = true },
	{ Id = "Undertow", Element = "Aqua", Role = "Primary", Name = "Undertow",
	  Cooldown = AQUA.Undertow.Cooldown, ManaCost = AQUA.Undertow.ManaCost, Range = AQUA.Undertow.Range, Targeted = true,
	  Implemented = true },
	{ Id = "RidingTheCurrent", Element = "Aqua", Role = "Passive", Name = "Riding the Current", Implemented = true },
	{ Id = "TwinTide", Role = "Defense", Name = "Twin Tide",
	  Cooldown = AQUA.TwinTide.Cooldown, ManaCost = AQUA.TwinTide.ManaCost, Range = AQUA.TwinTide.Range, Targeted = true,
	  Implemented = true },
	-- HELD: the press pays TapCost; the rest of a charged shot's cost is spent by AquaHandler at the release
	{ Id = "Sidearm", Role = "Defense", Name = "Sidearm",
	  Cooldown = AQUA.Sidearm.Cooldown, ManaCost = AQUA.Sidearm.TapCost, Held = true, HoldMax = AQUA.Sidearm.HoldMax,
	  Implemented = true },
	{ Id = "LeviathansMaw", Role = "Ultimate", Name = "Leviathan's Maw",
	  Range = AQUA.Maw.Range, Targeted = true, Implemented = true },

	-- UMBRA (2026-09-27, the rework; manual v0.16): UmbraHandler is its server, UmbraClient its client half, and every number
	-- is UmbraTuning's (STAND-INs). SpellshotInput takes Shadow Dart (fireShard) through UmbraClient. Shadow Dart is a RATE
	-- like every M1: 5 mana a dart is 3.8/s at the fastest (6.3/s under Eclipse), under the 7/s regen. Unseen is a row for
	-- Bedrock's reason: AbilityFor(player, "Passive") resolves it. Mark's Precheck: a press with nobody to mark costs nothing.
	{ Id = "ShadowDart", Element = "Umbra", Role = "M1", Name = "Shadow Dart",
	  Cooldown = 0, FireInterval = UMBRA.ShadowDart.FireInterval, ManaCost = UMBRA.ShadowDart.ManaCost,
	  Range = UMBRA.ShadowDart.Range, Implemented = true },
	{ Id = "ShadowStep", Element = "Umbra", Role = "Primary", Name = "Shadow Step",
	  Cooldown = UMBRA.ShadowStep.Cooldown, ManaCost = UMBRA.ShadowStep.ManaCost, Range = UMBRA.ShadowStep.AimRange,
	  EscapeCooldown = UMBRA.ShadowStep.EscapeCooldown,   -- the escape charge on the same key (2026-10-18, umbra)
	  -- (2026-10-19, audit GC-07: roots WIN) Precheck: UmbraHandler's Precheck_ShadowStep refuses a rooted, caged,
	  -- Deep-Frozen, Frozen or Entombed body at no cost, either charge
	  Targeted = true, Precheck = true, Implemented = true },
	{ Id = "Unseen", Element = "Umbra", Role = "Passive", Name = "Unseen", Implemented = true },
	{ Id = "Mark", Role = "Mobility", Name = "Mark",
	  Cooldown = UMBRA.Mark.Cooldown, ManaCost = UMBRA.Mark.ManaCost, Range = UMBRA.Mark.Range, Targeted = true,
	  Precheck = true, Implemented = true },
	{ Id = "DecoyDouble", Role = "Defense", Name = "Decoy Double",
	  Cooldown = UMBRA.DecoyDouble.Cooldown, ManaCost = UMBRA.DecoyDouble.ManaCost, Implemented = true },
	{ Id = "Eclipse", Role = "Ultimate", Name = "Eclipse", Implemented = true },
	-- RADIANT (2026-09-29, the rework; manual v0.21): RadiantHandler is its server, RadiantClient its client half, and every
	-- number is RadiantTuning's (PLACEHOLDERS). Light Lance is NOT Held: SpellshotService has no held M1, so its click
	-- starts a channel that runs on its own remote (Shadow Dart's arrangement). Blessing and Position Trade aim off the
	-- crosshair (Targeted); Position Trade and Benediction ask first (Precheck), so a press that cannot happen costs nothing.
	{ Id = "LightLance", Element = "Radiant", Role = "M1", Name = "Light Lance",
	  Cooldown = 0, FireInterval = RADIANT.LightLance.FireInterval, ManaCost = RADIANT.LightLance.StartCost,
	  Range = RADIANT.LightLance.Range, Implemented = true },
	{ Id = "Blessing", Element = "Radiant", Role = "Primary", Name = "Blessing",
	  Cooldown = RADIANT.Blessing.Cooldown, ManaCost = RADIANT.Blessing.ManaCost, Range = RADIANT.Blessing.Range,
	  Targeted = true, Implemented = true },
	{ Id = "OverflowLight", Element = "Radiant", Role = "Passive", Name = "Overflow Light", Implemented = true },
	{ Id = "PositionTrade", Role = "Mobility", Name = "Position Trade",
	  Cooldown = RADIANT.PositionTrade.Cooldown, ManaCost = RADIANT.PositionTrade.ManaCost,
	  Range = RADIANT.PositionTrade.Range, Targeted = true, Precheck = true, Implemented = true },
	-- Benediction is HELD (2026-09-30): the key going down plants the staff, the key coming up ends the channel
	-- (RadiantHandler; SpellshotService asks its Precheck on a held press too)
	{ Id = "Benediction", Role = "Defense", Name = "Benediction",
	  Cooldown = RADIANT.Benediction.Cooldown, ManaCost = RADIANT.Benediction.ManaCost, Precheck = true, Held = true,
	  Implemented = true },
	{ Id = "Halo", Role = "Ultimate", Name = "Halo", Implemented = true },
	-- TOXIN (2026-09-30, the rework; manual v0.15 / v0.17): ToxinHandler is its server, ToxinClient its client half, ToxinFX
	-- draws it, and every number is ToxinTuning's (PROPOSALS). Toxic Bubbles is a RATE like every M1 (SpellshotInput takes it
	-- through ToxinClient.FireM1). Corrosive Cloud's Precheck: a press with no live bubble costs nothing. Symbiosis is a row
	-- for Bedrock's reason. Patient Zero is ChargeOnCatch: the charge is spent only when a target is marked.
	{ Id = "ToxicBubbles", Element = "Toxin", Role = "M1", Name = "Toxic Bubbles",
	  Cooldown = 0, FireInterval = TOXIN.Bubble.FireInterval, ManaCost = TOXIN.Bubble.ManaCost, Range = 120,
	  Implemented = true },
	{ Id = "CorrosiveCloud", Element = "Toxin", Role = "Primary", Name = "Corrosive Cloud",
	  Cooldown = TOXIN.Cloud.Cooldown, ManaCost = TOXIN.Cloud.ManaCost, Precheck = true, Implemented = true },
	{ Id = "Symbiosis", Element = "Toxin", Role = "Passive", Name = "Symbiosis", Implemented = true },
	{ Id = "AntitoxinVent", Role = "Mobility", Name = "Antitoxin Vent",
	  Cooldown = TOXIN.Vent.Cooldown, ManaCost = TOXIN.Vent.ManaCost, Implemented = true },
	{ Id = "AcidRain", Role = "Defense", Name = "Acid Rain",
	  Cooldown = TOXIN.AcidRain.Cooldown, ManaCost = TOXIN.AcidRain.ManaCost, Range = TOXIN.AcidRain.Range, Targeted = true,
	  Implemented = true },
	{ Id = "PatientZero", Role = "Ultimate", Name = "Patient Zero",
	  Range = TOXIN.PatientZero.Range, Targeted = true, ChargeOnCatch = true, Implemented = true },
}

VFXLibrary.AbilityById = {}
VFXLibrary.ElementAbilities = {}      -- [element][role]: the M1 and Primary Ability each Element comes with
for _, a in ipairs(VFXLibrary.Abilities) do
	VFXLibrary.AbilityById[a.Id] = a
	if a.Element then
		VFXLibrary.ElementAbilities[a.Element] = VFXLibrary.ElementAbilities[a.Element] or {}
		VFXLibrary.ElementAbilities[a.Element][a.Role] = a
	end
end

-- Cryo's kit by role (its entries come first), for code that means Cryo's own kit. What a PLAYER is
-- holding is AbilityFor.
VFXLibrary.AbilityByRole = {}
for _, a in ipairs(VFXLibrary.Abilities) do
	if not VFXLibrary.AbilityByRole[a.Role] then VFXLibrary.AbilityByRole[a.Role] = a end
end

--- The ability `player` holds in `role`: the M1 and Primary Ability come with the player's Element, and a
--- Technique is whatever key the player's attribute for that role holds. nil when the slot has no cast path.
local defaultLoadout = nil
function VFXLibrary.AbilityFor(player, role)
	if not defaultLoadout then
		defaultLoadout = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig")).DefaultLoadout
	end
	if role == "M1" or role == "Primary" then
		local kit = VFXLibrary.ElementAbilities[(player and player:GetAttribute("Element")) or defaultLoadout.Element]
		return kit and kit[role] or nil
	end
	-- THE v0.7 LOADOUT (2026-09-24; it replaces the Element-fixed slots of 2026-09-23). The ULTIMATE is the Element's
	-- own (SpellshotConfig.ElementUltimate: the Config.Ultimate entry whose Origin it is); the Ultimate attribute is not
	-- read. The two TECHNIQUE slots (internally "Mobility" = Q and "Defense" = E) share one pool: any Technique row -- no
	-- Element, Role "Mobility" or "Defense" -- fits either, so a row's Role is only its flavour now. An Exclusive
	-- Technique on another Element (Detonate off Pyro) resolves to nothing: the server swaps it out on the Element
	-- change, so this only closes a forced attribute. A Config without ElementUltimate / Technique (this module pushed
	-- first) keeps the old attribute path. Inserted whole, with every line round it untouched (this module is being
	-- edited in Team Create); the require is the module the default loadout above came from, already loaded.
	local config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
	local element = (player and player:GetAttribute("Element")) or defaultLoadout.Element
	if role == "Ultimate" and config.ElementUltimate then
		local own = VFXLibrary.AbilityById[config.ElementUltimate(element) or ""]
		return (own and own.Role == "Ultimate") and own or nil
	end
	local key = (player and player:GetAttribute(role)) or defaultLoadout[role]
	local ability = key and VFXLibrary.AbilityById[key]
	if ability and (role == "Mobility" or role == "Defense") and config.Technique then
		if ability.Element or not (ability.Role == "Mobility" or ability.Role == "Defense") then return nil end
		local entry = config.Technique(key)
		-- P31 (2026-10-18): a Technique off its own Element resolves to nothing (config.ElementMayHold: Origin only)
		if entry and config.ElementMayHold and not config.ElementMayHold(element, key) then return nil end
		if entry and not config.ElementMayHold and entry.Exclusive and entry.Origin ~= element then return nil end --[[the only check until P31, 2026-10-18]]
		return ability
	end
	return (ability and ability.Role == role) and ability or nil
end

--- Which Technique slot ("Mobility" = Q, "Defense" = E) `player` has Technique `id` in, or nil (2026-09-24). Either slot
--- may hold any Technique now, so a script that means ITS OWN ability's slot -- to release a hold, give a cast back,
--- check it is still equipped -- asks this instead of naming a role. A hold in progress wins (the slot whose Holding_
--- names it), so a release still finds the slot the hold began in after a loadout change.
function VFXLibrary.TechniqueSlot(player, id)
	local character = player and player.Character
	for _, slot in ipairs({ "Mobility", "Defense" }) do
		if character and character:GetAttribute("Holding_" .. slot) == id then return slot end
	end
	for _, slot in ipairs({ "Mobility", "Defense" }) do
		local a = VFXLibrary.AbilityFor(player, slot)
		if a and a.Id == id then return slot end
	end
	return nil
end

local C = VFXLibrary.Config
local T = VFXLibrary.Tuning
local COL = C.Colors

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function NS(...)
	local args = { ... }
	if type(args[1]) == "number" then return NumberSequence.new(args[1]) end
	local keys = {}
	for _, kv in ipairs(args) do
		table.insert(keys, NumberSequenceKeypoint.new(kv[1], kv[2], kv[3] or 0))
	end
	return NumberSequence.new(keys)
end

local function CS(...)
	local cols = { ... }
	if #cols == 1 then return ColorSequence.new(cols[1]) end
	local keys = {}
	for i, c in ipairs(cols) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#cols - 1), c))
	end
	return ColorSequence.new(keys)
end

local function NR(a, b) return NumberRange.new(a, b or a) end

local function apply(inst, props)
	for k, v in pairs(props) do inst[k] = v end
	return inst
end

local function new(className, props, parent)
	local inst = Instance.new(className)
	if props then apply(inst, props) end
	if parent then inst.Parent = parent end
	return inst
end

local function fxFolder()
	local f = workspace:FindFirstChild(C.FXFolderName)
	if not f then f = new("Folder", { Name = C.FXFolderName }, workspace) end
	return f
end

local function flat(v)
	local h = Vector3.new(v.X, 0, v.Z)
	return h.Magnitude > 1e-4 and h.Unit or Vector3.new(0, 0, -1)
end

local function tween(inst, seconds, props, style, dir)
	local tw = TweenService:Create(inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function soundFolder()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	return ice and ice:FindFirstChild(C.SoundFolderName)
end

local soundWarned = {}
--- Clones a real Sound asset out of ReplicatedStorage.IceMagic.Sounds and plays it at `parent`.
local function playSound(parent, key)
	local spec = C.Sounds[key]
	if not (spec and parent) then return nil end
	local folder = soundFolder()
	local template = folder and folder:FindFirstChild(spec.Name)
	if not template then
		if not soundWarned[key] then
			soundWarned[key] = true
			warn(("[VFXLibrary] sound '%s' missing from ReplicatedStorage.IceMagic.%s")
				:format(spec.Name, C.SoundFolderName))
		end
		return nil
	end
	local s = template:Clone()
	s.Volume = spec.Volume or 0.5
	local spread = spec.Spread or 0
	s.PlaybackSpeed = (spec.Speed or 1) + (spread > 0 and (math.random() * 2 - 1) * spread or 0)
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, math.min(8, (s.TimeLength > 0 and s.TimeLength or 4) / math.max(0.1, s.PlaybackSpeed) + 0.5))
	return s
end
VFXLibrary.PlaySound = playSound

local function makeRayParams(exclude)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = exclude or {}
	p.RespectCanCollide = true
	p.IgnoreWater = true
	return p
end

--- The ground under `position`, straight down from 6 above it, found THROUGH characters: an enemy, a dummy or
--- someone jumping over you under the probe is stepped past to the floor, never landed on. `exclude` is left as it was.
local function groundBelow(position, exclude, maxDrop)
	local list = table.clone(exclude or {})
	local params = makeRayParams(list)
	local from, drop = position + Vector3.new(0, 6, 0), Vector3.new(0, -(maxDrop or 30), 0)
	for _ = 1, 8 do
		local hit = workspace:Raycast(from, drop, params)
		if not hit then break end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit.Position, hit.Normal, hit.Instance end
		list[#list + 1] = model
		params.FilterDescendantsInstances = list
	end
	return position, Vector3.yAxis, nil
end

VFXLibrary.GroundBelow = groundBelow
VFXLibrary.Flat = flat

local function ghostPart(props, parent)
	return new("Part", apply({
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Massless = true,
	}, props or {}), parent or fxFolder())
end

----------------------------------------------------------------------------------------------------
-- proximity fade: keeps the caster's own VFX from blocking their view in first person
----------------------------------------------------------------------------------------------------
local faded = {}          -- [BasePart] = true
local fadeConn = nil

local function stopFadeLoop()
	if fadeConn then fadeConn:Disconnect(); fadeConn = nil end
end

local function startFadeLoop()
	if fadeConn or not RunService:IsClient() then return end
	fadeConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local origin = cam.CFrame.Position
		local near, far = T.Fade.Near, T.Fade.Far
		local any = false
		for part in pairs(faded) do
			if part.Parent then
				any = true
				local d = (part.Position - origin).Magnitude - part.Size.Magnitude * 0.35
				-- LocalTransparencyModifier is client-only and does not fight the CFrame tweens
				-- or anything the server replicates.
				part.LocalTransparencyModifier = 1 - math.clamp((d - near) / (far - near), 0, 1)
			else
				faded[part] = nil
			end
		end
		if not any then stopFadeLoop() end
	end)
end

--- Register a part so it fades out as the local camera gets close to it.
function VFXLibrary.RegisterProximityFade(part)
	if not RunService:IsClient() then return end
	faded[part] = true
	startFadeLoop()
end

----------------------------------------------------------------------------------------------------
-- mesh lookup (+ primitive fallbacks so the kit still runs before the FBX files are imported)
----------------------------------------------------------------------------------------------------
local warned = {}
local function meshFolder()
	return ReplicatedStorage:FindFirstChild(C.MeshFolderName)
end

local FALLBACKS = {
	Ring   = function() return new("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.47, 40, 40) }) end,
	Aura   = function() return new("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 16, 16) }) end,
	Rune   = function() return new("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6.4, 6.4) }) end,
	Charge = function() return new("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8) }) end,
	Crust  = function() return new("Part", { Size = Vector3.new(2.2, 0.16, 2.2) }) end,
	Rime   = function() return new("Part", { Size = Vector3.new(1.9, 0.6, 1.9) }) end,
	Nozzle = function() return new("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6) }) end,
}

local function getMesh(name, fallbackKind)
	local folder = meshFolder()
	local src = folder and folder:FindFirstChild(name)
	local part
	if src and src:IsA("BasePart") then
		part = src:Clone()
	else
		if not warned[name] then
			warned[name] = true
			warn(("[VFXLibrary] mesh '%s' not found in ReplicatedStorage.%s - using a primitive fallback")
				:format(name, C.MeshFolderName))
		end
		part = FALLBACKS[fallbackKind]()
		part.Name = name
	end
	apply(part, {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Massless = true, Material = C.CrystalMaterial, Color = C.CrystalColor,
		Reflectance = 0, Transparency = 0,
	})
	-- The inverted-hull outline only reads while backfaces are culled.
	pcall(function() part.DoubleSided = false end)
	return part
end
VFXLibrary.GetMesh = getMesh

function VFXLibrary.Preload()
	local folder = meshFolder()
	local assets = {}
	if folder then table.insert(assets, folder) end
	local sf = soundFolder()
	if sf then table.insert(assets, sf) end
	table.insert(assets, C.Textures.Shard)
	table.insert(assets, C.Textures.ShardBurst)
	if #assets > 0 then pcall(function() ContentProvider:PreloadAsync(assets) end) end
	-- (the Cryo Beam warm-up went with the beam: it is retired, Mirror Cage is Cryo's Ultimate, and its kit was moved to
	-- ServerStorage.CryoKitSuperseded on 2026-10-08)
end

----------------------------------------------------------------------------------------------------
-- emitter presets
----------------------------------------------------------------------------------------------------
local E = {}

-- Icicle Shard shatter: the flat outlined Shard sprite untinted (its bands and ink are already in the
-- art), thrown off the surface. LightInfluence 0 keeps it flat whatever the lighting.
function E.ShardFragments()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.Rim), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.36 }, { 1, 0.16 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.3, 0.5), Speed = NR(9, 18), SpreadAngle = Vector2.new(62, 62),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-640, 640),
		Drag = 2.5, Acceleration = Vector3.new(0, -46, 0), Rate = 0, ZOffset = 0.2,
	}
end

-- Icicle Shard frost-burst: one compact flat spike-burst that pops and is gone, `k` x BurstSize across.
-- ZOffset pulls it toward the camera so it is not buried in the wall it hit.
function E.ShardBurst(k)
	local b = T.IcicleShard.BurstSize * (k or 1)
	return {
		Texture = C.Textures.ShardBurst, Color = CS(COL.Rim), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, b * 0.6 }, { 0.35, b }, { 1, b * 1.1 }), Transparency = NS({ 0, 0 }, { 0.7, 0 }, { 1, 1 }),
		Lifetime = NR(0.16), Speed = NR(0), Rotation = NR(0, 360), Rate = 0, ZOffset = 0.6,
	}
end

-- Icicle Shard cast: a couple of small stray fragments drifting off the palm as the cluster forms.
function E.ShardCastBits()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.Rim), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.18 }, { 1, 0.06 }), Transparency = NS({ 0, 0 }, { 0.75, 0 }, { 1, 1 }),
		Lifetime = NR(0.25, 0.4), Speed = NR(2, 5), SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-300, 300),
		Drag = 4, Rate = 0,
	}
end

-- ZEPHYR, WIND BLADE (the M1). Its look is toon meshes and ZephyrFX draws those; these are the two places the
-- upgrade pass asked for particles instead, because a particle may fade over its lifetime and a mesh may not:
--   WindInkSpecks  the flight trail's SECOND layer, shed behind the blade
--   WindShards     the sharp fragments off a character hit, under the flat burst
-- They live here, not in ZephyrFX, because emitter() is what applies Graphics Quality density and Reduce Enemy VFX.
local WIND = { Base = Color3.fromRGB(79, 209, 197), Dark = Color3.fromRGB(18, 92, 89), Ink = Color3.fromRGB(17, 17, 17),
	Light = Color3.fromRGB(255, 255, 255) }

-- A few small black/teal ink specks along the flight: the hard-edged Shard sprite tinted down to ink. At this size
-- and this speed it reads as a fleck off the brush rather than an ice chip. Low rate and a short life on purpose --
-- Wind Blade fires faster than anything else in the game.
function E.WindInkSpecks()
	return {
		Texture = C.Textures.Shard, Color = CS(WIND.Ink, WIND.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.22 }, { 1, 0.05 }), Transparency = NS({ 0, 0.05 }, { 0.5, 0.25 }, { 1, 1 }),
		Lifetime = NR(0.1, 0.18), Speed = NR(1, 4), SpreadAngle = Vector2.new(34, 34),
		EmissionDirection = Enum.NormalId.Back, Rotation = NR(0, 360), RotSpeed = NR(-500, 500),
		Drag = 7, Rate = 26, Enabled = false,
	}
end

-- The impact's fragments: a handful of sharp teal/black chips thrown off the hit, under the flat burst mesh.
function E.WindShards()
	return {
		Texture = C.Textures.Shard, Color = CS(WIND.Base, WIND.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.34 }, { 1, 0.11 }), Transparency = NS({ 0, 0 }, { 0.72, 0 }, { 1, 1 }),
		Lifetime = NR(0.16, 0.28), Speed = NR(10, 21), SpreadAngle = Vector2.new(68, 68),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-720, 720),
		Drag = 3, Acceleration = Vector3.new(0, -42, 0), Rate = 0,
	}
end

-- Chunky angular debris. Hard alpha cut (no soft tail) so it reads as solid chips, not dust.
function E.IceChips()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.IceLight, COL.IceMid), LightEmission = 0.1, LightInfluence = 0.5,
		Size = NS({ 0, 0.55 }, { 0.85, 0.5 }, { 1, 0.4 }), Transparency = NS({ 0, 0 }, { 0.88, 0 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.85), Speed = NR(13, 26), SpreadAngle = Vector2.new(48, 48),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-520, 520),
		Drag = 0.8, Acceleration = Vector3.new(0, -52, 0), Rate = 0,
	}
end

-- Kept deliberately small and short: a toon kit wants a puff of contact, not a soft cloud.
function E.FrostPuff()
	return {
		Texture = C.Textures.Smoke, Color = CS(COL.IceLight, COL.IceMid), LightEmission = 0.1, LightInfluence = 0.2,
		Size = NS({ 0, 1.1 }, { 0.4, 2.3 }, { 1, 2.9 }), Transparency = NS({ 0, 0.55 }, { 0.45, 0.6 }, { 1, 1 }),
		Lifetime = NR(0.4, 0.7), Speed = NR(4, 8), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(-180, 180), RotSpeed = NR(-50, 50),
		Drag = 4.5, Acceleration = Vector3.new(0, -2, 0), Rate = 0, ZOffset = 0.2,
	}
end

-- Flat ground crack ring. VelocityPerpendicular + a hair of speed lays the sprite on the floor.
function E.CrackRing()
	return {
		Texture = C.Textures.Ring, Color = CS(COL.Rim, COL.IceMid), LightEmission = 1, LightInfluence = 0,
		Size = NS({ 0, 1 }, { 1, 7 }), Transparency = NS({ 0, 0.15 }, { 0.55, 0.5 }, { 1, 1 }),
		Lifetime = NR(0.35), Speed = NR(0.05), SpreadAngle = Vector2.new(0, 0),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Rate = 0,
	}
end

function E.Glints()
	return {
		Texture = C.Textures.Sparkle, Color = CS(COL.Rim, COL.IceMid), LightEmission = 1, LightInfluence = 0,
		Size = NS({ 0, 0.85 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 1, 1 }),
		Lifetime = NR(0.3, 0.5), Speed = NR(5, 9), SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NR(-200, 200), Drag = 4, Rate = 0,
	}
end

-- Loose snow, but as angular flakes rather than round dust.
-- Chill Aura's sparse snow: the hard-edged Shard sprite (its bands and ink are in the art, so it goes untinted), no glow,
-- no fade -- it shrinks out -- short-lived, spawned on a cylinder shell around the caster and locked to it so no speck
-- trails outside the zone. (The built-in Sparkle was tried first: without additive glow its texture renders as a dark
-- blurred star, and with the glow it breaks the flat look -- 2026-09-14, in Play.)
function E.AuraSnow()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.Rim), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.34 }, { 1, 0 }), Transparency = NS(0), Lifetime = NR(0.4, 0.6),
		Speed = NR(0.3, 0.9), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Bottom,
		Rotation = NR(0, 360), RotSpeed = NR(-120, 120), Drag = 0.5, Acceleration = Vector3.new(0, -0.8, 0),
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, LockedToPart = true, Rate = 0,
	}
end

-- The frozen body's frost (CRYO v2, 2026-10-08): small matte frost-white flecks, lit, shed off the ice -- not the comic
-- Shard sprite with its ink (only dressFrozen uses this).
function E.SnowChunks()
	return {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = CS(Color3.fromRGB(242, 251, 255)),
		LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.1 }, { 0.2, 0.2 }, { 1, 0.08 }), Transparency = NS({ 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 }),
		Lifetime = NR(1.1, 2.1), Speed = NR(3, 7), SpreadAngle = Vector2.new(38, 38),
		EmissionDirection = Enum.NormalId.Top, Drag = 2.2, Acceleration = Vector3.new(0, -8, 0),
		Rotation = NR(0, 360), RotSpeed = NR(-160, 160), Rate = 0,
	}
end

function E.Shards()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.Rim, COL.IceMid), LightEmission = 0.2, LightInfluence = 0.5,
		Size = NS({ 0, 0.42 }, { 1, 0.24 }), Transparency = NS({ 0, 0 }, { 0.85, 0.1 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.85), Speed = NR(9, 18), SpreadAngle = Vector2.new(55, 55),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-620, 620),
		Drag = 1.2, Acceleration = Vector3.new(0, -42, 0), Rate = 0,
	}
end

function E.FormFlash()
	return {
		Texture = C.Textures.Core, Color = CS(COL.Rim, COL.IceMid), LightEmission = 1, LightInfluence = 0,
		Size = NS({ 0, 0.5 }, { 0.25, 2.4 }, { 1, 0 }), Transparency = NS({ 0, 0.05 }, { 0.5, 0.35 }, { 1, 1 }),
		Lifetime = NR(0.26), Speed = NR(0), Rate = 0, ZOffset = 0.5,
	}
end

function E.BeamFog()
	return {
		Texture = C.Textures.Fog, Color = CS(COL.IceLight, COL.IceMid), LightEmission = 0.15, LightInfluence = 0.05,
		Size = NS({ 0, 1.1 }, { 0.5, 2.4 }, { 1, 3.1 }), Transparency = NS({ 0, 0.82 }, { 0.3, 0.66 }, { 1, 1 }),
		Lifetime = NR(0.7, 1.3), Speed = NR(1, 2.2), SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Drag = 2, Acceleration = Vector3.new(0, -2.5, 0), Rotation = NR(-180, 180), RotSpeed = NR(-25, 25),
		Rate = 0, ZOffset = -0.2,
	}
end

function E.BeamMotes()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.Rim, COL.IceMid), LightEmission = 0.8, LightInfluence = 0,
		Size = NS({ 0, 0 }, { 0.2, 0.26 }, { 1, 0 }), Transparency = NS({ 0, 0.1 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.8), Speed = NR(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rotation = NR(0, 360), RotSpeed = NR(-140, 140), Rate = 0,
	}
end

function E.ImpactGlow()
	return {
		Texture = C.Textures.Glow, Color = CS(COL.Rim, COL.IceMid), LightEmission = 1, LightInfluence = 0,
		Size = NS({ 0, 2 }, { 0.5, 3.1 }, { 1, 1.8 }), Transparency = NS({ 0, 0.45 }, { 0.5, 0.3 }, { 1, 1 }),
		Lifetime = NR(0.22, 0.36), Speed = NR(0), Rate = 0, ZOffset = 0.3,
	}
end

--- Whether this emitter is being hung on somebody else's character. Walks up to the nearest model
--- with a Humanoid: an aura, a status treatment or a hand-welded effect on another player answers
--- yes, a projectile flying loose in the workspace answers no, because at that point there is
--- nothing in the instance tree that says whose it was.
--- (2026-10-19, audit P5F-06) THE ENEMY for Reduce Enemy VFX: a body that is not mine, not a TEAMMATE's (same DuelMatch
--- and MatchTeam, the replicated player attributes Config.MayHurt reads) and not an ally dummy (AllyDummy). Mine is
--- LocalCharacter, or LocalPlayer.Character in the moment before FirstPersonController sets it; nil is nobody's. A Hub
--- player and a training dummy count as before (CryoFX's FBX.Enemy draws the same line). It used to be "anything that
--- is not LocalCharacter", which thinned teammates' heals and zones. Every module that thins "somebody else's" effects
--- should ask this.
function VFXLibrary.IsEnemy(model)
	if typeof(model) ~= "Instance" then return false end
	local players = game:GetService("Players")
	local me = players.LocalPlayer
	if model == VFXLibrary.LocalCharacter or (me ~= nil and model == me.Character) then return false end
	if model:GetAttribute("AllyDummy") then return false end
	local owner = players:GetPlayerFromCharacter(model)
	if not owner then return true end
	if me then
		local match, team = me:GetAttribute("DuelMatch"), me:GetAttribute("MatchTeam")
		if match ~= nil and team ~= nil and owner:GetAttribute("DuelMatch") == match
			and owner:GetAttribute("MatchTeam") == team then
			return false
		end
	end
	return true
end

local function onAnotherPlayer(parent)
	local model = parent and parent:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return VFXLibrary.IsEnemy(model)   -- (2026-10-19, audit P5F-06) was: model ~= VFXLibrary.LocalCharacter
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

--- Every emitter in the library is made here, which is what makes the two settings that thin
--- particles a single change rather than a hundred.
---   GRAPHICS QUALITY scales the continuous Rate of every emitter. Burst counts (:Emit) are left
---   alone deliberately -- a burst is one frame's work and thinning it changes what an ability
---   LOOKS like rather than what it costs.
---   REDUCE ENEMY VFX halves what is left, for emitters attached to another player.
--- Flat light: HubClient's profile for the Hub and the comic maps (no sun, a white Ambient). It already lights the toon
--- meshes at their full baked colour, so an effect's own PointLight or additive sprite pushes them past Bloom's threshold
--- into a white glow (the user: "super bright"). Under it effects make no lights and their additive glow is toned down.
local FLAT_EMISSION, FLAT_BRIGHTNESS = 0.35, 0.7
local function flatLit()
	local a = Lighting.Ambient
	return Lighting.Brightness < 0.05 and a.R + a.G + a.B > 2.7
end
VFXLibrary.FlatLit = flatLit

--- A short flash light for a burst, skipped under flat light (see flatLit).
local function burstLight(parent, props, fadeTime)
	if flatLit() then return nil end
	props.Shadows = false
	-- (2026-10-19, audit P5F-03) Reduce Flashing halves every burst light (Flash Freeze's break / rim wave / press,
	-- the shatter's PointLight)
	if Settings.Get and Settings.Get("ReduceFlashing") and props.Brightness then props.Brightness *= 0.5 end
	local light = new("PointLight", props, parent)
	tween(light, fadeTime, { Brightness = 0 })
	return light
end

local function emitter(parent, preset, extra)
	local pe = new("ParticleEmitter", preset)
	if extra then apply(pe, extra) end
	if flatLit() then
		pe.LightEmission *= FLAT_EMISSION
		pe.Brightness *= FLAT_BRIGHTNESS
	end
	local density = Settings.EffectDensity or 1
	if Settings.ThinEnemyVFX and onAnotherPlayer(parent) then density *= 0.5 end
	if density ~= 1 and pe.Rate > 0 then
		pe.Rate = math.max(1, pe.Rate * density)
	end
	if VFXLibrary.Wrap then VFXLibrary.Wrap.Lit(pe) end      -- (a solid Cryo wrap's light pieces glow: CryoWrap.Lit)
	pe.Parent = parent
	return pe
end

--- Wind Blade's two emitters. ZephyrFX owns the hosts, the pooling and the timing; what it cannot own is emitter(),
--- which is local to this module and is what makes Graphics Quality and Reduce Enemy VFX a single change rather than
--- a hundred. Neither of these decides anything about the M1 -- they hand back a ParticleEmitter and nothing else.
function VFXLibrary.WindBladeInkEmitter(parent)
	return emitter(parent, E.WindInkSpecks())
end

function VFXLibrary.WindBladeShardEmitter(parent)
	return emitter(parent, E.WindShards())
end

-- ZEPHYR, CROSS-SLASH DASH (the Primary), the VFX polish pass (2026-09-17): the release's DEBRIS / INK SPLASH. Every other
-- piece of that look is a flat toon mesh drawn by ZephyrFX; this is particles because a mesh cannot scatter. Both use the
-- hard-edged Shard sprite, held fully opaque and only dropping out at the very end of their life -- chips and flecks,
-- never a soft cloud, never a sparkle, lighting nothing.
function E.CrossSlashShards()
	return {
		Texture = C.Textures.Shard, Color = CS(WIND.Base, WIND.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.62 }, { 1, 0.16 }), Transparency = NS({ 0, 0 }, { 0.85, 0 }, { 1, 1 }),
		Lifetime = NR(0.3, 0.5), Speed = NR(22, 40), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-720, 720),
		Drag = 4, Acceleration = Vector3.new(0, -52, 0), Rate = 0,
	}
end

function E.CrossSlashInk()
	return {
		Texture = C.Textures.Shard, Color = CS(WIND.Ink), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.48 }, { 1, 0.10 }), Transparency = NS({ 0, 0 }, { 0.85, 0 }, { 1, 1 }),
		Lifetime = NR(0.24, 0.42), Speed = NR(14, 30), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 5, Acceleration = Vector3.new(0, -60, 0), Rate = 0,
	}
end

--- The Cross-Slash's debris and ink splash thrown off the X where it stamps, once. `thin` is true for somebody else's
--- cast (Reduce Enemy VFX halves it, as emitter() does for a rate); Graphics Quality scales both counts. `wind`, when
--- given, is a push (studs/s^2) added to each emitter's fall, so the chips and flecks are carried downwind along the dash
--- rather than dropping straight. The host cleans itself up.
function VFXLibrary.CrossSlashDebris(position, thin, shards, flecks, wind)
	if typeof(position) ~= "Vector3" then return end
	local host = new("Part", {
		Name = "CrossSlashDebris", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, CFrame = CFrame.new(position),
	}, fxFolder())
	local att = new("Attachment", nil, host)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	local push = typeof(wind) == "Vector3" and wind or Vector3.zero
	local chips, ink = emitter(att, E.CrossSlashShards()), emitter(att, E.CrossSlashInk())
	chips.Acceleration += push
	ink.Acceleration += push
	chips:Emit(math.max(1, math.floor((shards or 16) * density + 0.5)))
	ink:Emit(math.max(1, math.floor((flecks or 12) * density + 0.5)))
	Debris:AddItem(host, 1.2)
end

-- ZEPHYR, GUST JUMP's chips and ink flecks (E.GustJumpChips / E.GustJumpInk, VFXLibrary.GustJumpChips) were removed with
-- Gust Jump on 2026-10-06 (the v6 import): nothing else used them. The pre-import copy is in the Studio snapshot
-- (D:/voltkit_scratch/_backups/roblox_studio_2026-10-06/VFXLibrary.lua).

-- TERRA (2026-09-17): the rock kit's debris. TerraFX draws every solid piece of Terra from Parts, and this is the
-- part a Part cannot do -- chunks and grit thrown off a boulder where it lands. Both use the hard-edged Shard
-- sprite: angular, opaque until the very end of their life, heavy (they fall fast and do not drift), and lighting
-- nothing. Never a dust cloud -- the manual's read on Terra is weight, and a soft puff is the opposite of weight.
local EARTH = { Base = Color3.fromRGB(130, 107, 36), Light = Color3.fromRGB(204, 186, 92),
	Dark = Color3.fromRGB(51, 33, 13) }

-- (2026-10-25) A TERRA WRAP'S PALETTE (the wrap ladder: SkinCatalog's Burst and Dust fields). Every Terra toon piece
-- below -- TerraRockDebris, TerraBurst, TerraSpark, TerraDustKick -- takes an optional trailing `palette`:
--   { Burst = { Fill = Color3, Edge = Color3 }, Dust = { Light = Color3, Dark = Color3, Pale = Color3 } }
-- i.e. a wrap skin's own two fields (TerraFX passes the wrap's skin table itself: only .Burst and .Dust are read). Each
-- preset keeps its shape -- sprite, sizes, timing and its colour sequence's keys -- and only its EARTH roles are swapped,
-- light for light, for the Dust roles: EARTH.Light -> Dust.Pale, EARTH.Base -> Dust.Light, EARTH.Dark -> Dust.Dark (the
-- burst's body, EARTH.Light, -> Burst.Fill: TerraBurst below). A role the palette leaves out keeps EARTH's. No palette,
-- or one with neither field (Default, anything unwrapped), is exactly as before. An explicit `tint` (a wrap's Chunks /
-- Grit / Chips extras, TerraWrap.Particles) is laid OVER the palette, so where a caller gives one it still wins.
local function terraTint(palette, roles, extra)
	local d = type(palette) == "table" and type(palette.Dust) == "table" and palette.Dust or nil
	if not d then return extra end
	local cols = {}
	for i, r in ipairs(roles) do
		local c = d[(r == "Light" and "Pale") or (r == "Base" and "Light") or "Dark"]
		cols[i] = typeof(c) == "Color3" and c or EARTH[r]
	end
	local merged = { Color = CS(table.unpack(cols)) }
	if extra then
		for k, v in pairs(extra) do merged[k] = v end
	end
	return merged
end

function E.TerraChunks()
	return {
		Texture = C.Textures.Shard, Color = CS(EARTH.Base, EARTH.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.70 }, { 1, 0.22 }), Transparency = NS({ 0, 0 }, { 0.88, 0 }, { 1, 1 }),
		Lifetime = NR(0.34, 0.60), Speed = NR(16, 32), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-420, 420),
		Drag = 2, Acceleration = Vector3.new(0, -90, 0), Rate = 0,
	}
end

function E.TerraGrit()
	return {
		Texture = C.Textures.Shard, Color = CS(EARTH.Light, EARTH.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.30 }, { 1, 0.08 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.22, 0.40), Speed = NR(10, 26), SpreadAngle = Vector2.new(85, 85),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-640, 640),
		Drag = 3, Acceleration = Vector3.new(0, -100, 0), Rate = 0,
	}
end

--- Rock chunks and grit thrown off `position`, once, out along `normal` (the surface a boulder stopped on, so the
--- debris leaves the wall rather than the floor). `thin` is true for somebody else's cast (Reduce Enemy VFX halves
--- it); Graphics Quality scales both counts. The host cleans itself up.
--- `tint` (a Terra wrap, optional): { Chunks = extra, Grit = extra } for the two emitters.
--- (2026-10-25) `palette` (a Terra wrap's, optional -- see terraTint above): the chunks' Base -> Dark and the grit's
--- Light -> Base in its Dust colours; a `tint` given for either emitter is laid over it.
function VFXLibrary.TerraRockDebris(position, thin, chunks, grit, normal, tint, palette)
	if typeof(position) ~= "Vector3" then return end
	local up = (typeof(normal) == "Vector3" and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
	local host = new("Part", {
		Name = "TerraRockDebris", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		CFrame = CFrame.lookAt(position, position + up) * CFrame.Angles(-math.pi / 2, 0, 0),
	}, fxFolder())
	local att = new("Attachment", nil, host)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	local chunk = emitter(att, E.TerraChunks(), terraTint(palette, { "Base", "Dark" }, tint and tint.Chunks))
	local fine = emitter(att, E.TerraGrit(), terraTint(palette, { "Light", "Base" }, tint and tint.Grit))
	chunk:Emit(math.max(1, math.floor((chunks or 14) * density + 0.5)))
	fine:Emit(math.max(1, math.floor((grit or 10) * density + 0.5)))
	Debris:AddItem(host, 1.2)
end

-- TERRA VFX POLISH (2026-09-18). Three more particle pieces for the rock kit, all on the hard-edged sprites:
--   TerraBurst     the game's flat comic burst -- the kit's plain white burst (PopArtAssets.Overlay.Burst: white
--                  body, ink rim and hard shadow baked in) tinted Terra's Light, so the white body takes the colour
--                  and the ink stays ink. Icicle Shard's frost-burst technique: one particle that pops, holds, and
--                  SNAPS SHUT (its size goes to nothing; it never fades).
--   TerraSpark     the "clink" when a Bedrock plate locks: a small burst and a few Light chips off the plate
--   TerraDustKick  Bulwark Charge's footfall: dust and rubble kicked up LOW and back off the floor, never a cloud
-- (TerraShedding, the chips a charged boulder shed in flight, went with the Boulder Shot rework, 2026-09-23: the
-- rework's rock sheds real chips and dust -- BOULDER below.)
local TERRA_BURST = "rbxassetid://88718198034720"

function E.TerraBurst(size)
	return {
		Texture = TERRA_BURST, Color = CS(EARTH.Light), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, size * 0.55 }, { 0.3, size }, { 0.85, size * 1.05 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 1, 0 }),
		Lifetime = NR(0.16), Speed = NR(0), Rotation = NR(-24, 24), Rate = 0, ZOffset = 0.8,
	}
end

function E.TerraSparkChips()
	return {
		Texture = C.Textures.Shard, Color = CS(EARTH.Light), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.30 }, { 1, 0.06 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.14, 0.26), Speed = NR(8, 16), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-500, 500),
		Drag = 6, Acceleration = Vector3.new(0, -40, 0), Rate = 0,
	}
end

function E.TerraDust()
	return {
		Texture = C.Textures.Shard, Color = CS(EARTH.Base, EARTH.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.62 }, { 1, 0.22 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.22, 0.40), Speed = NR(6, 14), SpreadAngle = Vector2.new(40, 75),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-420, 420),
		Drag = 5, Acceleration = Vector3.new(0, -70, 0), Rate = 0,
	}
end

local function terraHost(name, position, up, life)
	local host = new("Part", {
		Name = name, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		CFrame = CFrame.lookAt(position, position + up) * CFrame.Angles(-math.pi / 2, 0, 0),
	}, fxFolder())
	Debris:AddItem(host, life)
	return new("Attachment", nil, host)
end

local function terraUp(v)
	return (typeof(v) == "Vector3" and v.Magnitude > 0.1) and v.Unit or Vector3.yAxis
end

--- One flat comic burst at `position`, `size` studs across at its peak. Reduce Flashing draws it smaller.
--- (2026-10-25) `palette` (a Terra wrap's, optional -- see terraTint): its Burst.Fill is the burst's body in place of
--- EARTH.Light, and its Burst.Edge, when given, a second burst a fifth larger right behind it at the same turn, so the
--- body reads ringed in the edge colour inside the ink (the comic double rim; two particles instead of one, same life).
--- No Burst in it: exactly as before.
function VFXLibrary.TerraBurst(position, size, thin, palette)
	if typeof(position) ~= "Vector3" then return end
	size = size or 2.4
	if thin and Settings.ThinEnemyVFX then size *= 0.8 end
	if Settings.Get and Settings.Get("ReduceFlashing") then size *= 0.75 end
	local att = terraHost("TerraBurst", position, Vector3.yAxis, 0.5)
	local b = type(palette) == "table" and type(palette.Burst) == "table" and palette.Burst or nil
	if not b then
		emitter(att, E.TerraBurst(size)):Emit(1)
		return
	end
	local turn = NR(math.random() * 48 - 24)      -- one turn for both (the preset's own -24..24), so the rim rings the body
	if typeof(b.Edge) == "Color3" then
		emitter(att, E.TerraBurst(size * 1.22), { Color = CS(b.Edge), Rotation = turn, ZOffset = 0.7 }):Emit(1)
	end
	emitter(att, E.TerraBurst(size), { Color = CS(typeof(b.Fill) == "Color3" and b.Fill or EARTH.Light), Rotation = turn })
		:Emit(1)
end

--- The clink: a small burst and a spray of Light chips off `normal`.
--- (2026-10-25) `palette` (a Terra wrap's, optional): the burst's (TerraBurst) and the chips' Light -> Dust.Pale -- under
--- a `tint` (the wrap's Chips), which still wins for the chips.
function VFXLibrary.TerraSpark(position, normal, size, thin, tint, palette)
	if typeof(position) ~= "Vector3" then return end
	VFXLibrary.TerraBurst(position, size or 1.1, thin, palette)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	emitter(terraHost("TerraSpark", position, terraUp(normal), 0.5), E.TerraSparkChips(), terraTint(palette, { "Light" }, tint))
		:Emit(math.max(1, math.floor(5 * density + 0.5)))
end

--- A footfall's dust and rubble, kicked low and back along `back` off the floor at `position`.
--- (2026-10-25) `palette` (a Terra wrap's, optional): the dust's and the rubble's Base -> Dark in its Dust colours.
function VFXLibrary.TerraDustKick(position, back, thin, palette)
	if typeof(position) ~= "Vector3" then return end
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	local dir = terraUp(back) * 0.8 + Vector3.yAxis * 0.6
	local att = terraHost("TerraDustKick", position, dir, 0.6)
	emitter(att, E.TerraDust(), terraTint(palette, { "Base", "Dark" })):Emit(math.max(1, math.floor(6 * density + 0.5)))
	emitter(att, E.TerraChunks(), terraTint(palette, { "Base", "Dark" }, { Speed = NR(8, 16), Size = NS({ 0, 0.45 }, { 1, 0.16 }) }))
		:Emit(math.max(1, math.floor(2 * density + 0.5)))
end

----------------------------------------------------------------------------------------------------
-- TERRA M1, BOULDER SHOT -- THE REWORK (2026-09-23): its particles. THE STYLE EXCEPTION IS M1'S AND AFTERSHOCK'S
----------------------------------------------------------------------------------------------------
-- The owner waived the toon pipeline for Boulder Shot (Opus5-5_Terra_M1_BlenderShowcase.md: physics debris,
-- transparent dust, dynamic lights) -- and, by a later brief (2026-09-25), for Aftershock, Terra's Mobility, whose own
-- earth-only presets are AFTERSHOCK_KIT below; every other Terra piece stays in the toon kit. Built in Blender first
-- (blender_scripts/terra/m1_rework_bl.py, whose P(...) rows these are, Size for Size -- the film drew a Roblox
-- particle's 2 x Size quad) and ported on request. TerraFX's BOULDER section places and times everything; these are
-- only the sprites, here because emitter() lives in this file and is what applies Graphics Quality, Reduce Enemy VFX and
-- the flat-light damping.
--
-- DUST is soft and LIT (LightInfluence 1, Roblox's own smoke): Terra's Light desaturated toward the floor, so it takes
-- the scene's light the way the lit stone does. SPARKS and embers are gold, mostly ALPHA-BLENDED (LightEmission 0.3,
-- Brightness past the Bloom threshold) -- additive yellow over a bright sky sums to white (Ground Surge found it).
-- GRIT is the one hard sprite: TR_M1_Grit (a lit chip, generated by blender_scripts/terra/m1_kit_textures.py).
-- Every Size below is the film's; `extra` rescales it per burst where the rock's own size or the first-person
-- projection sets it (TerraFX passes a scaled Size).
local BOULDER_DUST = Color3.fromRGB(179, 158, 125)
local BOULDER_DUST_DARK = Color3.fromRGB(117, 97, 69)
local BOULDER_GOLD = Color3.fromRGB(255, 214, 102)
local BOULDER_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local BOULDER_GRIT = "rbxassetid://82803520621527"     -- TR_M1_Grit.png (export/terra_kit), uploaded 2026-09-23
local BOULDER_KIT = {}

--- WINDUP: dust pulled in off the floor and up into the rock, the whole charge. A Disc host flat on the floor under
--- the rock, emitting INWARD from its rim with a lift, so it converges and climbs; rate-driven (14 -> 34 a second).
function BOULDER_KIT.Gather()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST_DARK, BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.5 }, { 0.6, 0.9 }, { 1, 0.4 }), Transparency = NS({ 0, 1 }, { 0.25, 0.74 }, { 0.8, 0.82 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.75), Speed = NR(4, 7), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-90, 90),
		Drag = 1, Acceleration = Vector3.new(0, 6, 0), Rate = 14,
	}
end

--- ...and the grit that comes in with it: small chips, pulled in and up faster than the dust.
function BOULDER_KIT.GatherGrit()
	return {
		Texture = BOULDER_GRIT, Color = CS(BOULDER_DUST, BOULDER_DUST_DARK), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.09 }, { 0.8, 0.08 }, { 1, 0 }), Transparency = NS(0),
		Lifetime = NR(0.35, 0.6), Speed = NR(6, 10), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-600, 600),
		Drag = 2.5, Acceleration = Vector3.new(0, 14, 0), Rate = 22,
	}
end

--- A piece tearing out of the floor: a kick of dust where it came up (3 for a cell, 1 for a feeding stone).
function BOULDER_KIT.Kick()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.35 }, { 1, 1.1 }), Transparency = NS({ 0, 1 }, { 0.12, 0.58 }, { 1, 1 }),
		Lifetime = NR(0.5, 0.8), Speed = NR(1.2, 2.8), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-60, 60),
		Drag = 2.5, Acceleration = Vector3.new(0, 0.5, 0), Rate = 0,
	}
end

--- ...and the grit thrown up with it, falling back at the debris' gravity.
function BOULDER_KIT.KickGrit()
	return {
		Texture = BOULDER_GRIT, Color = CS(BOULDER_DUST_DARK, BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.08 }, { 0.75, 0.08 }, { 1, 0 }), Transparency = NS(0),
		Lifetime = NR(0.4, 0.6), Speed = NR(3, 6), SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-600, 600),
		Drag = 0.5, Acceleration = Vector3.new(0, -35, 0), Rate = 0,
	}
end

--- A feeding stone pressed into the rock: a small puff off the surface where it went in.
function BOULDER_KIT.Merge()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.25 }, { 1, 0.7 }), Transparency = NS({ 0, 0.65 }, { 1, 1 }),
		Lifetime = NR(0.25, 0.4), Speed = NR(1.5, 3), SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), Drag = 4, Rate = 0,
	}
end

--- FULL: the squeeze pushes a ring of dust off the rock. A Disc host round the rock, emitting OUTWARD from its rim.
function BOULDER_KIT.Ring()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.5 }, { 1, 1.4 }), Transparency = NS({ 0, 0.66 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.65), Speed = NR(3.5, 5), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), Drag = 3.5, Rate = 0,
	}
end

--- FLIGHT: dust shed off the tumbling rock, 60 a second from a sphere the rock's size, hanging in the air behind it.
function BOULDER_KIT.Trail()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST, BOULDER_DUST_DARK), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 1.2 }, { 1, 3.0 }), Transparency = NS({ 0, 0.60 }, { 0.3, 0.74 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.75), Speed = NR(0.4, 1.6), Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top,
		Rotation = NR(0, 360), RotSpeed = NR(-40, 40), Drag = 2, Acceleration = Vector3.new(0, -0.6, 0), Rate = 60,
	}
end

--- ...and a few embers off its cracks of light.
function BOULDER_KIT.Ember()
	return {
		Texture = BOULDER_SPARKLE, Color = CS(BOULDER_GOLD), LightEmission = 0.3, LightInfluence = 0, Brightness = 3,
		Size = NS({ 0, 0.10 }, { 1, 0.03 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.18, 0.30), Speed = NR(2, 4), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), Drag = 1,
		Acceleration = Vector3.new(0, -35, 0), Rate = 13,
	}
end

--- IMPACT: the cloud off the break, thrown back toward the thrower and up, soft, lit and slow to clear (1.1 - 2 s).
function BOULDER_KIT.Cloud()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 1.3 }, { 0.3, 2.8 }, { 1, 4.6 }), Transparency = NS({ 0, 1 }, { 0.04, 0.28 }, { 0.4, 0.58 }, { 1, 1 }),
		Lifetime = NR(1.1, 2.0), Speed = NR(4, 12), SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-50, 50),
		Drag = 2.8, Acceleration = Vector3.new(0, -0.5, 0), Rate = 0,
	}
end

--- ...the heavier dust that drops out of it onto the floor and rolls out along it.
function BOULDER_KIT.Settle()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 1.2 }, { 1, 3.8 }), Transparency = NS({ 0, 1 }, { 0.1, 0.5 }, { 1, 1 }),
		Lifetime = NR(1.2, 1.9), Speed = NR(2, 5), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-30, 30), Drag = 2.2, Rate = 0,
	}
end

--- ...gold sparks thrown off the break, falling at the debris' gravity.
function BOULDER_KIT.Spark()
	return {
		Texture = BOULDER_SPARKLE, Color = CS(BOULDER_GOLD), LightEmission = 0.3, LightInfluence = 0, Brightness = 3.5,
		Size = NS({ 0, 0.16 }, { 1, 0.05 }), Transparency = NS({ 0, 0 }, { 0.85, 0 }, { 1, 1 }),
		Lifetime = NR(0.25, 0.45), Speed = NR(10, 22), SpreadAngle = Vector2.new(80, 80),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), Drag = 0.6,
		Acceleration = Vector3.new(0, -35, 0), Rate = 0,
	}
end

--- ...one soft gold flash where it broke, a seventh of a second.
function BOULDER_KIT.Flash()
	return {
		Texture = C.Textures.Glow, Color = CS(BOULDER_GOLD), LightEmission = 0.5, LightInfluence = 0, Brightness = 2,
		Size = NS({ 0, 2.2 }, { 1, 4.2 }), Transparency = NS({ 0, 0.55 }, { 1, 0 }),
		Lifetime = NR(0.14), Speed = NR(0), LockedToPart = true, Rate = 0,
	}
end

--- ...and a puff wherever a big piece first lands (TerraFX scales it by the piece).
function BOULDER_KIT.Landing()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.4 }, { 1, 1.4 }), Transparency = NS({ 0, 1 }, { 0.1, 0.6 }, { 1, 1 }),
		Lifetime = NR(0.6, 1.0), Speed = NR(1, 2.5), SpreadAngle = Vector2.new(80, 80),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), Drag = 2.5, Rate = 0,
	}
end

local function boulderDensity(thin)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	return density
end

local function boulderPreset(kind)
	local preset = BOULDER_KIT[kind]
	assert(preset, "[VFXLibrary] no Boulder Shot emitter '" .. tostring(kind) .. "'")
	return preset()
end

--- A running Boulder Shot emitter of `kind` on `parent` (an Attachment, or a BasePart for the shaped ones), through
--- emitter(). The hosts hang in the open, not on a character, so `thin` (somebody else's) halves the rate here, as
--- GroundSurgeEmitter does. The caller stops it (Enabled = false) or destroys its host.
function VFXLibrary.BoulderEmitter(parent, kind, thin, extra)
	local pe = emitter(parent, boulderPreset(kind), extra)
	if thin and Settings.ThinEnemyVFX and pe.Rate > 0 then pe.Rate = math.max(1, pe.Rate * 0.5) end
	return pe
end

--- Re-rates a running Boulder Shot emitter (the windup's gather ramps with the charge), re-applying Graphics Quality
--- and Reduce Enemy VFX. `rate` <= 0 stops it.
function VFXLibrary.BoulderRate(pe, rate, thin)
	if typeof(pe) ~= "Instance" or not pe:IsA("ParticleEmitter") then return end
	pe.Rate = (rate or 0) > 0 and math.max(1, rate * boulderDensity(thin)) or 0
end

--- One-shot: `count` particles of `kind` from `parent`, scaled by Graphics Quality and halved for somebody else's
--- cast. `extra` overrides preset fields (a scaled Size). Returns the emitter, left on its host (the caller's).
function VFXLibrary.BoulderBurst(parent, kind, count, thin, extra)
	local pe = emitter(parent, boulderPreset(kind), extra)
	pe.Rate = 0
	local n = math.floor((count or 1) * boulderDensity(thin) + 0.5)
	-- (2026-10-19, audit P5F-03) Reduce Flashing skips the gold break flash (the emitter is still handed back)
	if kind == "Flash" and Settings.Get and Settings.Get("ReduceFlashing") then n = 0 end
	if n > 0 then pe:Emit(n) end
	return pe
end

----------------------------------------------------------------------------------------------------
-- TERRA MOBILITY, AFTERSHOCK (2026-09-25): its particles. EARTH ONLY
----------------------------------------------------------------------------------------------------
-- Aftershock extends the M1's lit style exception (the brief: Opus5-5_Terra_Aftershock_BlenderShowcase.md) and is STRICTER
-- than it: fully earth-toned, no glow anywhere -- so none of BOULDER_KIT's gold Ember / Spark / Flash, no Neon, no light.
-- These are the showcase's puffs (blender_scripts/terra/aftershock_bl.py, fx_pass: each P(...) row's size and alpha
-- keys, Size for Size, alpha as 1 - Transparency), at about a quarter of the film's count -- TerraFX's Aftershock
-- section places, times and counts them. Dust is soft and LIT (LightInfluence 1, Roblox's smoke), in BOULDER_DUST's
-- colours, which are the film's DUST / DUST_DARK within a few points; grit is TR_M1_Grit, the one hard sprite.
-- The Disc kinds (Kick, Skirt, Front, Haze) emit OUTWARD from the rim of the part they sit on (BOULDER_KIT.Ring's
-- recipe), so the caller sizes that part; the rest emit from a point (an Attachment), along its Top.
local AFTERSHOCK_DUST_PALE = Color3.fromRGB(194, 173, 140)   -- the film's DUST_PALE (0.76, 0.68, 0.55)
local AFTERSHOCK_KIT = {}

--- WINDUP: the ground thumping at each foot on every beat -- a low ring of pale dust pushed out along the floor.
function AFTERSHOCK_KIT.Kick()
	return {
		Texture = C.Textures.Smoke, Color = CS(AFTERSHOCK_DUST_PALE, BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.5 }, { 1, 1.6 }), Transparency = NS({ 0, 0.7 }, { 0.08, 0.3 }, { 1, 1 }),
		Lifetime = NR(0.6, 1.0), Speed = NR(1.4, 3.0), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-60, 60),
		Drag = 2.8, Acceleration = Vector3.new(0, 0.8, 0), Rate = 0,
	}
end

--- THE SLAM: the dome of dust thrown up off both fists, soft, lit and slow to clear (the film's 36; 1.2 - 2.2 s).
function AFTERSHOCK_KIT.Cloud()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 1.0 }, { 0.3, 2.6 }, { 1, 4.2 }), Transparency = NS({ 0, 0.55 }, { 0.03, 0.2 }, { 0.45, 0.58 }, { 1, 1 }),
		Lifetime = NR(1.2, 2.2), Speed = NR(4, 13), SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-40, 40),
		Drag = 2.8, Acceleration = Vector3.new(0, 0.3, 0), Rate = 0,
	}
end

--- ...and the heavy skirt of it thrown flat along the ground, fast (the film's 24 at 10 - 17 studs/s).
function AFTERSHOCK_KIT.Skirt()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.8 }, { 1, 2.8 }), Transparency = NS({ 0, 0.65 }, { 0.04, 0.35 }, { 1, 1 }),
		Lifetime = NR(0.9, 1.5), Speed = NR(10, 17), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-30, 30),
		Drag = 3.2, Acceleration = Vector3.new(0, 0.6, 0), Rate = 0,
	}
end

--- THE RING: the wall of dust the front throws up as it runs. RATE-driven, on a Disc part TerraFX resizes to the front
--- every frame (2 x its radius) and re-rates by the band it swept (the film's 0.22 puffs a square stud, a quarter here).
--- The film's lift (1.5 - 4 studs/s up, then drag) is the Acceleration; TerraFX scales Speed by the front's strength.
function AFTERSHOCK_KIT.Front()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST, BOULDER_DUST:Lerp(BOULDER_DUST_DARK, 0.45)), LightEmission = 0,
		LightInfluence = 1, Size = NS({ 0, 0.7 }, { 0.4, 1.8 }, { 1, 2.8 }),
		Transparency = NS({ 0, 0.8 }, { 0.05, 0.48 }, { 0.5, 0.72 }, { 1, 1 }),
		Lifetime = NR(0.9, 1.7), Speed = NR(2, 6), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-40, 40),
		Drag = 2.2, Acceleration = Vector3.new(0, 2.2, 0), Rate = 0,
	}
end

--- Grit: the hard chips thrown up off the slam, each eruption and the front, falling back at the debris' gravity.
function AFTERSHOCK_KIT.Grit()
	return {
		Texture = BOULDER_GRIT, Color = CS(BOULDER_DUST_DARK, BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.09 }, { 0.8, 0.08 }, { 1, 0 }), Transparency = NS(0),
		Lifetime = NR(0.5, 0.9), Speed = NR(5, 11), SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-600, 600),
		Drag = 0.5, Acceleration = Vector3.new(0, -35, 0), Rate = 0,
	}
end

--- A rock breaking out of the floor, and a rock landing: a puff at the ground (TerraFX scales it by the rock).
function AFTERSHOCK_KIT.Landing()
	return {
		Texture = C.Textures.Smoke, Color = CS(BOULDER_DUST, BOULDER_DUST:Lerp(BOULDER_DUST_DARK, 0.5)), LightEmission = 0,
		LightInfluence = 1, Size = NS({ 0, 0.55 }, { 1, 1.5 }), Transparency = NS({ 0, 1 }, { 0.08, 0.55 }, { 1, 1 }),
		Lifetime = NR(0.7, 1.2), Speed = NR(1, 3.5), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), Drag = 2.6, Rate = 0,
	}
end

--- The haze: a few large, low, long puffs that hang over the broken ground -- the film's dust volume, which Roblox has
--- no way to draw, stood in for by overlapping sprites at a tenth to a fifth of opacity.
function AFTERSHOCK_KIT.Haze()
	return {
		Texture = C.Textures.Smoke, Color = CS(AFTERSHOCK_DUST_PALE, BOULDER_DUST), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 6 }, { 1, 9 }), Transparency = NS({ 0, 1 }, { 0.2, 0.82 }, { 0.6, 0.86 }, { 1, 1 }),
		Lifetime = NR(2.0, 3.0), Speed = NR(0.5, 2), Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-15, 15),
		Drag = 1, Acceleration = Vector3.new(0, 0.3, 0), Rate = 0,
	}
end

local function aftershockPreset(kind)
	local preset = AFTERSHOCK_KIT[kind]
	assert(preset, "[VFXLibrary] no Aftershock emitter '" .. tostring(kind) .. "'")
	return preset()
end

--- A running Aftershock emitter of `kind` on `parent` (an Attachment, or a BasePart for the Disc kinds), through
--- emitter(), so Graphics Quality, Reduce Enemy VFX and the flat-light damping apply. The hosts hang in the open, so
--- `thin` (somebody else's cast) halves the rate here, as BoulderEmitter does. The caller stops it or destroys its host.
function VFXLibrary.AftershockEmitter(parent, kind, thin, extra)
	local pe = emitter(parent, aftershockPreset(kind), extra)
	if thin and Settings.ThinEnemyVFX and pe.Rate > 0 then pe.Rate = math.max(1, pe.Rate * 0.5) end
	return pe
end

--- Re-rates a running Aftershock emitter (the front's wall follows the band it sweeps), re-applying Graphics Quality and
--- Reduce Enemy VFX. `rate` <= 0 stops it.
function VFXLibrary.AftershockRate(pe, rate, thin)
	if typeof(pe) ~= "Instance" or not pe:IsA("ParticleEmitter") then return end
	pe.Rate = (rate or 0) > 0 and math.max(1, rate * boulderDensity(thin)) or 0
end

--- One-shot: `count` particles of `kind` from `parent`, scaled by Graphics Quality and halved for somebody else's cast.
--- `extra` overrides preset fields. Returns the emitter, left on its host (the caller's).
function VFXLibrary.AftershockBurst(parent, kind, count, thin, extra)
	local pe = emitter(parent, aftershockPreset(kind), extra)
	pe.Rate = 0
	local n = math.floor((count or 1) * boulderDensity(thin) + 0.5)
	if n > 0 then pe:Emit(n) end
	return pe
end

-- EARTHEN TOMB (v2, 2026-09-19): the Ultimate's OWN two particle pieces, on the hard-edged Shard sprite, Terra's palette.
-- The meshes do the reading (TerraFX); these are the grit round them -- chips, never a cloud, never a glow.
--   TombGrit     the ground breaking: kicked up where the fissure ploughs, where the plinth erupts and the claws slam
--   TombShatter  the detonation's spray: Light and Base shards thrown hard in every direction, bigger than any other
--                Terra debris -- the hero moment's particle layer, under the stone starburst mesh
function E.TombGrit()
	return {
		Texture = C.Textures.Shard, Color = CS(EARTH.Light, EARTH.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.52 }, { 1, 0.14 }), Transparency = NS({ 0, 0 }, { 0.82, 0 }, { 1, 1 }),
		Lifetime = NR(0.22, 0.42), Speed = NR(9, 22), SpreadAngle = Vector2.new(55, 55),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-600, 600),
		Drag = 3, Acceleration = Vector3.new(0, -95, 0), Rate = 0,
	}
end

function E.TombShards()
	return {
		Texture = C.Textures.Shard, Color = CS(EARTH.Light, EARTH.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 1.1 }, { 1, 0.3 }), Transparency = NS({ 0, 0 }, { 0.85, 0 }, { 1, 1 }),
		Lifetime = NR(0.4, 0.75), Speed = NR(30, 62), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-720, 720),
		Drag = 2.5, Acceleration = Vector3.new(0, -70, 0), Rate = 0,
	}
end

--- The ground breaking at `position`, thrown up along `dir` (the floor's normal, or back along the fissure). `count`
--- chips (default 8); Graphics Quality and Reduce Enemy VFX scale them.
function VFXLibrary.TombGrit(position, dir, thin, count)
	if typeof(position) ~= "Vector3" then return end
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	local up = terraUp(dir) * 0.7 + Vector3.yAxis * 0.7
	emitter(terraHost("TombGrit", position, up, 0.8), E.TombGrit()):Emit(math.max(1, math.floor((count or 8) * density + 0.5)))
end

--- The detonation's shard spray at `position`.
function VFXLibrary.TombShatter(position, thin)
	if typeof(position) ~= "Vector3" then return end
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	local att = terraHost("TombShatter", position + Vector3.new(0, 1, 0), Vector3.yAxis, 1.2)
	emitter(att, E.TombShards()):Emit(math.max(2, math.floor(34 * density + 0.5)))
	emitter(att, E.TombGrit(), { Speed = NR(20, 44), SpreadAngle = Vector2.new(180, 180) }):Emit(math.max(2, math.floor(24 * density + 0.5)))
end

----------------------------------------------------------------------------------------------------
-- VOLTAIC (2026-09-22): the kit's particle support.
----------------------------------------------------------------------------------------------------
-- The Voltaic VFX pass (blender_scripts/voltaic) builds every primary read as a flat toon MESH -- the
-- bolts, the rail, Cascade's cloud. These emitters are SUPPORT ONLY, underneath
-- (GROUND SURGE is the exception since v3: a realistic-lighting build, its particles in their own block below)
-- that: a mesh cannot scatter, and this is the one thing the kit's own modules cannot do for themselves
-- because emitter() is local to this file and is what makes Graphics Quality and Reduce Enemy VFX one
-- change rather than a hundred. Each of these hands back a ParticleEmitter and decides nothing else.
--
-- THE SPRITE IS THE SHARED `Shard`, and that is deliberate. It is the project's hard-edged angular debris
-- sprite, not an ice-specific one -- Zephyr's Wind Blade and Cross-Slash and Terra's grit all already use
-- it tinted to their own palettes. A soft built-in sprite would break the kit's silhouette rule.
-- FLAGGED: the Voltaic build pass asked for a bespoke Voltaic spark sprite. Tinted `Shard` is the
-- consistent answer today; a dedicated sprite is a separate, unmade asset.
local VOLT = { Base = Color3.fromRGB(245, 199, 15), Light = Color3.fromRGB(255, 245, 115),
	Dark = Color3.fromRGB(74, 26, 140) }

--- Chain Bolt's and Railspike's impact sparks: fast, short-lived, hard-edged, thrown straight out of the
--- hit and dropping barely at all -- electricity does not fall the way rock grit does.
function E.VoltSparks()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.44 }, { 1, 0.07 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.18, 0.30), Speed = NR(26, 52), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 6, Acceleration = Vector3.new(0, -18, 0), Rate = 0,
	}
end

--- Railspike's windup: a thin trickle of sparks pulled INWARD toward the gathering node. Rate-driven
--- rather than one-shot, because it runs for the whole charge.
function E.VoltCharge()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.10 }, { 0.4, 0.26 }, { 1, 0.05 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.16, 0.26), Speed = NR(-30, -16), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-700, 700),
		Drag = 2, Acceleration = Vector3.zero, Rate = 34,
	}
end

--- The impact spray for Chain Bolt's hits and Railspike's pierces. One-shot; `count` defaults to 6, the
--- same budget Icicle Shard's impact uses. `thin` is somebody else's cast.
function VFXLibrary.VoltSparkBurst(position, normal, thin, count)
	if typeof(position) ~= "Vector3" then return end
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	local dir = (typeof(normal) == "Vector3" and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
	local host = new("Part", {
		Name = "VoltSparkBurst", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		CFrame = CFrame.lookAt(position, position + dir),
	}, fxFolder())
	emitter(new("Attachment", nil, host), E.VoltSparks()):Emit(math.max(1, math.floor((count or 6) * density + 0.5)))
	Debris:AddItem(host, 0.8)
end

----------------------------------------------------------------------------------------------------
-- GROUND SURGE v3 (2026-09-23): the four-pole cage's particles -- THE KIT'S ONE REALISTIC-LIGHTING EXCEPTION
----------------------------------------------------------------------------------------------------
-- The owner waived the comic pipeline for Ground Surge ALONE (Opus5-5_Voltaic_GroundSurge_Rework: "use whatever real
-- Roblox technique gets there"). v1's eruption motes (E.VoltGroundMotes / VoltGroundBurst) and v2's telegraph sparks
-- (E.VoltSurgeSparks / VoltSurgeSparkEmitter / VoltSurgeSparkRamp) are GONE with the rest of those builds. The cage
-- itself -- Neon poles, Beam arcs, lights -- is drawn by VoltaicFX.GroundSurgePlant; these are its particles, here only
-- because emitter() lives in this file and is what applies Graphics Quality and Reduce Enemy VFX.
--
-- These are SOFT, glowing, transparent sprites on purpose -- the opposite of every other Voltaic preset above, and
-- allowed for this ability only. Roblox's own sparkles_main / implosion / smoke textures (white art, so a tint stays
-- its tint: no blue-banded Shard, no green). Yellow is mostly ALPHA-BLENDED (LightEmission 0.25), not additive:
-- additive yellow over a blue sky sums to white (found on Cascade's realistic test); Brightness carries it past the
-- place's Bloom threshold instead. Nothing here schedules or places anything -- vfx_blocking/voltaic/
-- INTEGRATION_ground_surge_v3.md and VoltaicFX do.
local SURGE_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SURGE_EMISSION = 0.25
local SURGE_KIT = {}

--- Sparks shedding off each pole's tip for as long as the cage is live. Rate-driven: VoltaicFX ramps it with the
--- countdown through GroundSurgeRate.
function SURGE_KIT.PoleSpark()
	return {
		Texture = SURGE_SPARKLE, Color = CS(VOLT.Light, VOLT.Base), LightEmission = SURGE_EMISSION, LightInfluence = 0,
		Brightness = 3, Size = NS({ 0, 0.26 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 0.7, 0 }, { 1, 1 }),
		Lifetime = NR(0.18, 0.40), Speed = NR(4, 12), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-360, 360),
		Drag = 1, Acceleration = Vector3.new(0, -40, 0), Rate = 6,
	}
end

--- A pole landing: a spray of sparks thrown up and out of the strike point, falling hard.
function SURGE_KIT.Impact()
	return {
		Texture = SURGE_SPARKLE, Color = CS(VOLT.Light, VOLT.Base), LightEmission = SURGE_EMISSION, LightInfluence = 0,
		Brightness = 4, Size = NS({ 0, 0.32 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 0.75, 0 }, { 1, 1 }),
		Lifetime = NR(0.25, 0.55), Speed = NR(16, 36), SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-360, 360),
		Drag = 1.5, Acceleration = Vector3.new(0, -70, 0), Rate = 0,
	}
end

--- A landing's flash: one soft disc, big and gone in a tenth of a second, locked to the strike point.
function SURGE_KIT.Flash()
	return {
		Texture = C.Textures.Glow, Color = CS(VOLT.Light), LightEmission = SURGE_EMISSION, LightInfluence = 0,
		Brightness = 4, Size = NS({ 0, 1.4 }, { 1, 3.6 }), Transparency = NS({ 0, 0.15 }, { 1, 1 }),
		Lifetime = NR(0.12, 0.12), Speed = NR(0, 0), LockedToPart = true, Rate = 0,
	}
end

--- Grit and dust kicked off the ground by a landing and by the discharge: grey, lit by the scene, slow to settle.
function SURGE_KIT.Dust()
	return {
		Texture = C.Textures.Smoke, Color = CS(Color3.fromRGB(150, 146, 160)), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 1.0 }, { 1, 3.2 }), Transparency = NS({ 0, 0.55 }, { 1, 1 }),
		Lifetime = NR(0.6, 1.0), Speed = NR(3, 7), SpreadAngle = Vector2.new(85, 85),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-40, 40),
		Drag = 3, Acceleration = Vector3.new(0, 1.5, 0), Rate = 0,
	}
end

--- The discharge: a fountain of sparks thrown UP out of the zone's centre -- a column, not a ring or a starburst.
function SURGE_KIT.Fountain()
	return {
		Texture = SURGE_SPARKLE, Color = CS(VOLT.Light, VOLT.Base), LightEmission = SURGE_EMISSION, LightInfluence = 0,
		Brightness = 5, Size = NS({ 0, 0.36 }, { 0.6, 0.24 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.40, 0.80), Speed = NR(26, 58), SpreadAngle = Vector2.new(38, 38),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-360, 360),
		Drag = 1, Acceleration = Vector3.new(0, -80, 0), Rate = 0,
	}
end

--- The discharge's smoke: grey-violet, lit, rising slowly off the whole floor of the cage and hanging past the end.
function SURGE_KIT.Smoke()
	return {
		Texture = C.Textures.Smoke, Color = CS(Color3.fromRGB(96, 86, 112), Color3.fromRGB(62, 54, 80)),
		LightEmission = 0, LightInfluence = 1, Size = NS({ 0, 2.0 }, { 1, 5.0 }),
		Transparency = NS({ 0, 0.55 }, { 0.3, 0.45 }, { 1, 1 }), Lifetime = NR(1.3, 2.0), Speed = NR(1, 3),
		SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360),
		RotSpeed = NR(-30, 30), Drag = 1, Acceleration = Vector3.new(0, 2.2, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 0,
	}
end

--- The retract: embers drifting up off each pole's foot as it sinks, cooling from yellow to violet.
function SURGE_KIT.Ember()
	return {
		Texture = SURGE_SPARKLE, Color = CS(VOLT.Base, VOLT.Dark), LightEmission = SURGE_EMISSION, LightInfluence = 0,
		Brightness = 2.5, Size = NS({ 0, 0.16 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 0.7, 0.1 }, { 1, 1 }),
		Lifetime = NR(0.5, 0.9), Speed = NR(1.5, 4), SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-120, 120),
		Drag = 0.5, Acceleration = Vector3.new(0, 3, 0), Rate = 14,
	}
end

local function surgeDensity(thin)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	return density
end

--- A running Ground Surge emitter of `kind` on `parent` (an Attachment, or a BasePart for the Box-shaped Smoke),
--- through emitter(). The hosts hang in the open, not on a character, so emitter() cannot tell whose cast it is:
--- `thin` (somebody else's) halves the rate here, exactly as VoltSparkBurst does for its counts. `extra` overrides
--- preset fields. The caller stops it (Enabled = false) or destroys its host.
function VFXLibrary.GroundSurgeEmitter(parent, kind, thin, extra)
	local preset = SURGE_KIT[kind]
	assert(preset, "[VFXLibrary] no Ground Surge emitter '" .. tostring(kind) .. "'")
	local pe = emitter(parent, preset(), extra)
	if thin and Settings.ThinEnemyVFX and pe.Rate > 0 then pe.Rate = math.max(1, pe.Rate * 0.5) end
	return pe
end

--- Re-rates a running Ground Surge emitter (VoltaicFX's countdown ramp). Setting Rate straight would undo Graphics
--- Quality and Reduce Enemy VFX, so both are re-applied here. `rate` <= 0 stops it.
function VFXLibrary.GroundSurgeRate(pe, rate, thin)
	if typeof(pe) ~= "Instance" or not pe:IsA("ParticleEmitter") then return end
	pe.Rate = (rate or 0) > 0 and math.max(1, rate * surgeDensity(thin)) or 0
end

--- One-shot: `count` particles of `kind` from `parent`, scaled by Graphics Quality and halved for somebody else's
--- cast. Returns the emitter (left on its host, which the caller owns and clears).
function VFXLibrary.GroundSurgeBurst(parent, kind, count, thin, extra)
	local preset = SURGE_KIT[kind]
	assert(preset, "[VFXLibrary] no Ground Surge emitter '" .. tostring(kind) .. "'")
	local pe = emitter(parent, preset(), extra)
	pe.Rate = 0
	-- (2026-10-19, audit P5F-03) Reduce Flashing skips the landing's flash disc (the emitter is still handed back)
	if not (kind == "Flash" and Settings.Get and Settings.Get("ReduceFlashing")) then
		pe:Emit(math.max(1, math.floor((count or 1) * surgeDensity(thin) + 0.5)))
	end
	return pe
end

--- Railspike's charge trickle. Returns the emitter so the caller can stop it on release or on an
--- interrupt -- it is rate-driven and will otherwise run forever.
function VFXLibrary.VoltChargeEmitter(parent)
	return emitter(parent, E.VoltCharge())
end

--- Railspike v2's CRACKLE (2026-09-23): chips spitting off the three strands for as long as the strike holds. Same
--- family as VoltSparks -- the Shard sprite, Light -> Base, lighting nothing, held opaque and only dropping out at the
--- very end -- but slow and short-lived: each jumps under a stud off the bundle and snaps out, so the held strike reads
--- as CRACKLING rather than as a second impact. Size HOLDS through half its life and then shrinks (a linear shrink
--- spends a 3-6 frame life as a speck; Ground Surge's sparks found the same). Rendered at duel range in
--- vfx_blocking/voltaic/railspike_v2/. BUDGET: a 26-stud duel shot through one body into a wall 10 studs behind runs
--- 2 knot hosts at 40/s + 2 leg hosts (32/s, 16/s) for 0.40 s -- ~51 chips, ~19 live at once -- before Graphics
--- Quality and Reduce Enemy VFX.
function E.RailspikeCrackle()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.36 }, { 0.5, 0.30 }, { 1, 0.06 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.10, 0.20), Speed = NR(6, 14), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 6, Acceleration = Vector3.new(0, -10, 0), Rate = 40,
	}
end

--- Railspike's crackle for the strike's hold. `parent` is an Attachment on a KNOT (a body the shot went through, or
--- where it stopped -- never the muzzle, where the chips land in the caster's face) or an invisible anchored host Part
--- laid along one LEG of the shot: the caller sizes that box to the leg and turns it to the strands' camera-facing fan
--- (VoltaicFX owns hosts, as for every Voltaic emitter; see INTEGRATION_railspike_v2.md). `rate` overrides the
--- preset's 40/s (a leg host passes 1.6 x its length); `thin` is somebody else's cast -- these hosts are not under a
--- character, so emitter()'s own Reduce Enemy VFX check cannot see it. Returns the emitter, already running: the
--- caller sets Enabled = false when the hold ends and the chips in flight finish on their own (<= 0.2 s).
--- Rate-driven -- it will otherwise run forever.
function VFXLibrary.RailspikeCrackleEmitter(parent, rate, thin)
	if typeof(parent) ~= "Instance" then return nil end
	local preset = E.RailspikeCrackle()
	if type(rate) == "number" and rate > 0 then preset.Rate = rate end
	if thin and Settings.ThinEnemyVFX then preset.Rate *= 0.5 end
	return emitter(parent, preset)
end

----------------------------------------------------------------------------------------------------
-- OVERCHARGE (the Voltaic Primary), v2 (2026-09-23): the dash's particle support and the primed crackle
----------------------------------------------------------------------------------------------------
-- The dash is drawn as a BEAT by flat toon MESHES (export/voltaic/VoltaicBolts.fbx, blender_scripts/voltaic/
-- bolt_family.py): VT_Overcharge_Launch_01 at the origin, the VT_Overcharge_Ghost_R/_L afterimages along the path,
-- VT_Overcharge_Land_R/_L at the end point -- and the primed tell by VT_Overcharge_PrimedBolts_01 on each hand. These
-- emitters are SUPPORT ONLY, in the kit's particle language: the hard-edged `Shard` sprite, Voltaic Light -> Base,
-- LightEmission 0, LightInfluence 0, opaque until a drop-out at the very end of life. No soft texture, no Brightness,
-- no light, no Beam. Nothing here places a mesh or decides a timing: vfx_blocking/voltaic/INTEGRATION_overcharge_v2.md
-- does, and lists every number below as a PROPOSAL with its basis. The review that plays them is
-- blender_scripts/voltaic/anim_overcharge2.py (clips in vfx_blocking/voltaic/overcharge_v2/). Voltaic has no cast
-- path yet; none of this is called by anything.
--
-- THIN: the launch and landing hosts hang in the open, not on a character, so emitter()'s own Reduce Enemy VFX test
-- cannot see whose cast it is -- the caller passes `thin` (somebody else's cast) and counts are halved here, exactly
-- as VoltSparkBurst does. The crackle is parented under a HAND, so emitter() makes that call itself: another player's
-- hand is thinned, your own character's and your own Viewmodel's (under the Camera, no Humanoid) are not.
-- BUDGET at High (EffectDensity 1): launch 8 + landing 10 chips, each gone in <= 0.4 s; the crackle ~4.0 live per
-- hand (24/s x mean life 0.17 s), ~8 for both, for as long as the caster is primed (the cap is 6 s).

local OVERCHARGE = { KickCount = 8, SkidCount = 10, SkidTilt = 35, CrackleSize = { 0.34, 0.28, 0.05 } }

--- The launch: chips kicked BACK down the dash path off the push-off -- fast, short-lived, barely falling.
function E.OverchargeKick()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.50 }, { 1, 0.08 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.16, 0.26), Speed = NR(22, 40), SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 7, Acceleration = Vector3.new(0, -12, 0), Rate = 0,
	}
end

--- The landing: chips sprayed FORWARD and up off the floor where the dash stops -- slower, longer, falling back. The
--- launch kicks back and this skids forward: that pair is what makes the two ends read as a distance travelled.
function E.OverchargeSkid()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.44 }, { 0.5, 0.36 }, { 1, 0.08 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.26, 0.40), Speed = NR(16, 30), SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 3, Acceleration = Vector3.new(0, -45, 0), Rate = 0,
	}
end

--- The primed tell's CRACKLE: small chips spitting off a hand for as long as the next M1 is empowered. Same family as
--- RailspikeCrackle, but per hand and continuous. ZOffset 1.0 draws the chips in front of the PrimedBolts_01 billboard
--- (which sits 0.6 studs toward the camera off the hand) -- at 0.5 the mesh hid most of them. LockedToPart: the chips
--- ride the hand (and the Viewmodel arm) instead of streaming off behind a moving caster as a trail.
function E.OverchargeCrackle()
	local s = OVERCHARGE.CrackleSize
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, s[1] }, { 0.5, s[2] }, { 1, s[3] }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.12, 0.22), Speed = NR(5, 10), SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Front, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 5, Acceleration = Vector3.zero, ZOffset = 1.0, LockedToPart = true, Rate = 24,
	}
end

local function overchargeFlat(dir)
	local d = typeof(dir) == "Vector3" and Vector3.new(dir.X, 0, dir.Z) or Vector3.zero
	return d.Magnitude > 1e-3 and d.Unit or Vector3.new(0, 0, -1)
end

local function overchargeDensity(thin)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	return density
end

local function overchargeHost(name, cf, life)
	local host = new("Part", {
		Name = name, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, CFrame = cf,
	}, fxFolder())
	Debris:AddItem(host, life)
	return new("Attachment", nil, host)
end

--- The launch spray, once, on the dash's first frame. `position`: the dash origin, 2.5 studs up and 0.3 back along the
--- dash (INTEGRATION_overcharge_v2.md section 2); `dir`: the dash direction (flattened here). The chips leave in a 30
--- degree cone round -dir. `count` defaults to 8; `thin` is somebody else's cast.
function VFXLibrary.OverchargeLaunchBurst(position, dir, thin, count)
	if typeof(position) ~= "Vector3" then return end
	local d = overchargeFlat(dir)
	local att = overchargeHost("OverchargeLaunch", CFrame.lookAt(position, position - d), 0.8)
	local n = count or OVERCHARGE.KickCount
	emitter(att, E.OverchargeKick()):Emit(math.max(1, math.floor(n * overchargeDensity(thin) + 0.5)))
end

--- The landing spray, once, on the frame the dash stops. `position`: 0.6 studs ahead of the feet along the dash and
--- 0.4 up (on the CASTER's own client, 2.6 ahead -- at 0.6 the spray goes through their lens); `dir`: the dash
--- direction. The chips leave in a 50 degree cone round the vertical tipped 35 degrees toward `dir`, and fall back.
--- `count` defaults to 10; `thin` is somebody else's cast.
function VFXLibrary.OverchargeLandBurst(position, dir, thin, count)
	if typeof(position) ~= "Vector3" then return end
	local d = overchargeFlat(dir)
	local cf = CFrame.lookAt(position, position + d) * CFrame.Angles(math.rad(-OVERCHARGE.SkidTilt), 0, 0)
	local att = overchargeHost("OverchargeLand", cf, 1.0)
	local n = count or OVERCHARGE.SkidCount
	emitter(att, E.OverchargeSkid()):Emit(math.max(1, math.floor(n * overchargeDensity(thin) + 0.5)))
end

--- The primed crackle on ONE hand. `parent` is an Attachment: on a character, one under RightHand / LeftHand (R15's
--- RightGripAttachment / LeftGripAttachment, or the handler's own); in the caster's own first person, the Viewmodel
--- arm's `CastPoint` (ArmR / ArmL under Camera.SpellshotViewmodel -- Viewmodel.lua moves it every frame). `scale`
--- (default 1) multiplies Size, Speed and ZOffset together, so the chips keep their look at another distance: the
--- Viewmodel passes 0.14 (its hand is ~1.1 studs from the lens). Returns the emitter, already running: the caller
--- sets Enabled = false on the empowered M1's fire frame (or on the 6 s cap, death, or a loadout change) and the
--- chips in flight finish on their own (<= 0.22 s). Rate-driven -- it will otherwise run forever.
function VFXLibrary.OverchargeCrackleEmitter(parent, scale)
	if typeof(parent) ~= "Instance" then return nil end
	local preset = E.OverchargeCrackle()
	local k = (type(scale) == "number" and scale > 0) and scale or 1
	if k ~= 1 then
		local s = OVERCHARGE.CrackleSize
		preset.Size = NS({ 0, s[1] * k }, { 0.5, s[2] * k }, { 1, s[3] * k })
		preset.Speed = NR(5 * k, 10 * k)
		preset.ZOffset = 1.0 * k
	end
	return emitter(parent, preset)
end

----------------------------------------------------------------------------------------------------
-- CASCADE (the Voltaic Ultimate), THE COMIC BUILD (2026-09-23): its particle support
----------------------------------------------------------------------------------------------------
-- The realistic-lighting Cascade that stood here (soft smoke and glow textures, additive yellows pushed past the Bloom,
-- sparkle sprites, VFXLibrary.CascadeEmitter / CascadeColors / CascadeYellowEmission) was REMOVED on 2026-09-23: the owner
-- reverted Cascade to its settled comic spec and ruled realism out for the whole Voltaic kit. Cascade is the flat pipeline
-- now, like every other piece: opaque toon MESHES carry every primary read -- the cloud, its seam glow, the bolts, the tear
-- burst, the impact bursts, the ground crackle (export/voltaic/VoltaicCascade.fbx, blender_scripts/voltaic/cascade3.py).
-- These emitters are SUPPORT ONLY, the one thing a mesh cannot do (scatter), in the kit's own particle language: the
-- hard-edged `Shard` sprite, Voltaic Base/Light, LightEmission 0, LightInfluence 0, fully opaque until it drops out at the
-- very end of its life. Same family as E.VoltSparks. No soft textures, no Brightness, no lights, no Beams.
--
-- THIN: Cascade hangs in the open, not on a character, so emitter()'s own Reduce Enemy VFX test cannot see whose it is.
-- The caller says (`thin` = somebody else's cast) and rates / counts are halved here exactly as emitter() would halve them.
-- Every number is a proposal, matched to the Blender render (vfx_blocking/voltaic/INTEGRATION_cascade_comic.md).

--- The orbiting sparks: shed by a host the handler moves round the storm every frame, so they hang behind it as a
--- dashed arc (a ParticleEmitter cannot steer its particles along a curve; the host does the orbiting). Two emitters per
--- host, one Base and one Light, because the spec's "brightening" is the Light share rising -- CascadeOrbitRamp does it.
function E.CascadeOrbitSparks(color)
	return {
		Texture = C.Textures.Shard, Color = CS(color), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.9 }, { 1, 0.22 }), Transparency = NS({ 0, 0 }, { 0.85, 0 }, { 1, 1 }),
		Lifetime = NR(0.18, 0.26), Speed = NR(0.5, 2), SpreadAngle = Vector2.new(180, 180),
		Rotation = NR(0, 360), RotSpeed = NR(-720, 720), Drag = 2, Acceleration = Vector3.zero, Rate = 0,
	}
end

--- A strike's landing spray: fast, hard-edged, thrown up and out of the ground and falling back.
function E.CascadeImpactSparks()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 1.2 }, { 1, 0.25 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.28, 0.5), Speed = NR(16, 34), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-900, 900),
		Drag = 2.5, Acceleration = Vector3.new(0, -40, 0), Rate = 0,
	}
end

--- A strike's debris: bigger chips kicked up, yellow-lit cooling to violet, heavier than the sparks.
function E.CascadeDebris()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Base, VOLT.Dark), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 1.15 }, { 1, 0.8 }), Transparency = NS({ 0, 0 }, { 0.9, 0 }, { 1, 1 }),
		Lifetime = NR(0.55, 0.85), Speed = NR(9, 18), SpreadAngle = Vector2.new(55, 55),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-500, 500),
		Drag = 1, Acceleration = Vector3.new(0, -55, 0), Rate = 0,
	}
end

--- What a strike leaves: small motes drifting up off the strike point for a beat after the bolt has gone, under the
--- ground-crackle mesh. Rate-driven; the handler switches it off at Tuning.Cascade.MotesUntil and what it made lingers.
function E.CascadeAfterglow()
	return {
		Texture = C.Textures.Shard, Color = CS(VOLT.Light, VOLT.Base), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.48 }, { 1, 0.1 }), Transparency = NS({ 0, 0 }, { 0.8, 0 }, { 1, 1 }),
		Lifetime = NR(0.45, 0.75), Speed = NR(1.5, 4), SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top, Rotation = NR(0, 360), RotSpeed = NR(-300, 300),
		Drag = 1.2, Acceleration = Vector3.new(0, 1.5, 0), Rate = 10,
	}
end

local CASCADE_ORBIT = { Rate = { 22, 70 }, Size = { 0.9, 1.6 }, LightShare = { 0.25, 0.90 } }

local function cascadeDensity(thin)
	local density = Settings.EffectDensity or 1
	if thin and Settings.ThinEnemyVFX then density *= 0.5 end
	return density
end

--- One orbit host's pair of emitters, parented to `parent` (an Attachment on the moving host). Starts at the bottom of
--- its ramp; drive it with CascadeOrbitRamp every frame and end it with CascadeOrbitStop at the release.
function VFXLibrary.CascadeOrbitEmitters(parent, thin)
	local pair = {
		Base = emitter(parent, E.CascadeOrbitSparks(VOLT.Base)),
		Light = emitter(parent, E.CascadeOrbitSparks(VOLT.Light)),
		Thin = thin,
	}
	VFXLibrary.CascadeOrbitRamp(pair, 0)
	return pair
end

--- `u` 0..1 from the sparks' birth (Tuning.Cascade.OrbitFrom) to the release: more of them, bigger, and more of them
--- Light -- the rising intensity the charged hold asks for. The orbit SPEED is the host's, the handler's to move.
function VFXLibrary.CascadeOrbitRamp(pair, u)
	u = math.clamp(u or 0, 0, 1)
	local K = CASCADE_ORBIT
	local rate = (K.Rate[1] + (K.Rate[2] - K.Rate[1]) * u) * cascadeDensity(pair.Thin)
	local share = K.LightShare[1] + (K.LightShare[2] - K.LightShare[1]) * u
	local size = K.Size[1] + (K.Size[2] - K.Size[1]) * u
	local seq = NS({ 0, size }, { 1, size * 0.25 })
	pair.Base.Rate, pair.Light.Rate = rate * (1 - share), rate * share
	pair.Base.Size, pair.Light.Size = seq, seq
end

function VFXLibrary.CascadeOrbitStop(pair)
	pair.Base.Enabled, pair.Light.Enabled = false, false
end

--- One strike's landing: the spark spray and the debris, once. `first` is the opening bolt, which throws more.
function VFXLibrary.CascadeImpact(position, thin, first)
	if typeof(position) ~= "Vector3" then return end
	local density = cascadeDensity(thin)
	local host = new("Part", {
		Name = "CascadeImpact", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
	}, fxFolder())
	local att = new("Attachment", nil, host)
	emitter(att, E.CascadeImpactSparks()):Emit(math.max(1, math.floor((first and 16 or 12) * density + 0.5)))
	emitter(att, E.CascadeDebris()):Emit(math.max(1, math.floor((first and 8 or 6) * density + 0.5)))
	Debris:AddItem(host, 1.2)
end

--- A strike's lingering motes. `parent` should be a small flat Part (~2.4 x 0.2 x 2.4) on the strike point, so they
--- rise from a patch rather than a point. Rate-driven: set Enabled = false at MotesUntil.
function VFXLibrary.CascadeAfterglowEmitter(parent, thin)
	local pe = emitter(parent, E.CascadeAfterglow())
	if thin and Settings.ThinEnemyVFX and pe.Rate > 0 then
		pe.Rate = math.max(1, pe.Rate * 0.5)
	end
	return pe
end

----------------------------------------------------------------------------------------------------
-- PRIMARY ABILITY: FLASH FREEZE
----------------------------------------------------------------------------------------------------
--- Radius of the expanding front at time t. The server re-derives hits from this same curve,
--- so what freezes you is exactly what you saw reach you.
function VFXLibrary.FlashFreezeRadiusAt(t)
	local a = math.clamp(t / T.FlashFreeze.ExpandTime, 0, 1)
	return T.FlashFreeze.Radius * TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
end

--- Where the zone is centred for a caster whose root is at `rootPosition`; the server's zone and every client's
--- drawing both ask here. The ground under the caster, found through characters -- and standing on someone (or just
--- over their head mid-jump) counts as standing where THEY stand, so the zone lands on the floor round their feet
--- instead of falling back to the caster's root, out of the 12-stud probe's reach.
function VFXLibrary.FlashFreezeCentre(rootPosition, exclude)
	local list = table.clone(exclude or {})
	local params = makeRayParams(list)
	local at = rootPosition
	for _ = 1, 8 do
		local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
		local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
		local body = model and model:FindFirstChildOfClass("Humanoid") and model:FindFirstChild("HumanoidRootPart")
		if not body then break end
		-- under the caster's root it is stood on: carry on from its height. Over it (on the caster's head): look past it
		if hit.Position.Y < at.Y then at = Vector3.new(at.X, math.min(at.Y, body.Position.Y), at.Z) end
		list[#list + 1] = model
		params.FilterDescendantsInstances = list
	end
	return groundBelow(at, list, 12)
end

-- THE ZONE is the Build Prompt #19 kit, built and coloured in Blender by
-- blender_scripts/cryo_blocking/final_02_flash_freeze.py and imported into
-- ReplicatedStorage.IceMagicMeshes.FlashFreeze: the ice sheet, clusters of crystals, bold crack
-- ink, and the pieces of the break, every mesh with its colour bands and ink hull baked in.
-- ReplicatedStorage.IceMagic.FlashFreezeData holds the layout, the reveal times and the rigid-body
-- break (simulated in Blender, baked into compact tracks), all in Blender coordinates.
--
-- Blender -> Roblox was measured on the imported FF_AxisMarker (2026-09-13): a point at Blender
-- (x, y, z) lands at MeshPart (-x, z, y). That is a proper rotation (no mirror), so rotations map as
-- axis -> same mapping, angle unchanged, and every imported MeshPart sits on its bounding-box centre.
local FF = { DataName = "FlashFreezeData", MeshFolder = "FlashFreeze" }

local function fromBlender(x, y, z)
	return Vector3.new(-x, z, y)
end

local B64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do B64[string.byte(alphabet, i)] = i - 1 end
end

local function decodeBase64(text)
	local pad = (string.sub(text, -2) == "==") and 2 or ((string.sub(text, -1) == "=") and 1 or 0)
	local out = buffer.create(#text // 4 * 3 - pad)
	local size, o = buffer.len(out), 0
	for i = 1, #text, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local v = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		buffer.writeu8(out, o, v // 65536); o += 1
		if o < size then buffer.writeu8(out, o, (v // 256) % 256); o += 1 end
		if o < size then buffer.writeu8(out, o, v % 256); o += 1 end
	end
	return out
end

local function ffData()
	if FF.Data ~= nil then return FF.Data end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local module = ice and ice:FindFirstChild(FF.DataName)
	if not module then
		warn("[VFXLibrary] IceMagic.FlashFreezeData is missing - Flash Freeze falls back to a plain frozen floor")
		FF.Data = false
		return false
	end
	FF.Data = require(module)
	FF.Tracks = decodeBase64(FF.Data.Tracks)
	FF.Stride = FF.Data.TrackFrames.BytesPerSample * FF.Data.TrackFrames.Count
	return FF.Data
end

--- One piece of the break at `frame` (30 fps frames since the cast): its CFrame relative to the zone
--- and its scale (0 once it has been cleared).
local function ffTrackPose(track, frame)
	local TF = FF.Data.TrackFrames
	local u = math.max(0, (frame - TF.First) / TF.Step)
	local i0 = math.min(math.floor(u), TF.Count - 1)
	local i1 = math.min(i0 + 1, TF.Count - 1)
	local a = math.clamp(u - i0, 0, 1)
	local buf, stride, bps = FF.Tracks, FF.Stride, TF.BytesPerSample
	local function sample(i)
		local o = track * stride + i * bps
		local pos = fromBlender(buffer.readi16(buf, o) / TF.PosQ, buffer.readi16(buf, o + 2) / TF.PosQ, buffer.readi16(buf, o + 4) / TF.PosQ)
		local rv = fromBlender(buffer.readi16(buf, o + 6) / TF.RotQ, buffer.readi16(buf, o + 8) / TF.RotQ, buffer.readi16(buf, o + 10) / TF.RotQ)
		local s = buffer.readu8(buf, o + 12) / 255
		if i == 0 and s == 0 then s = 1 end            -- the frame before the break: still at rest
		local angle = rv.Magnitude
		local cf = angle > 1e-6 and (CFrame.new(pos) * CFrame.fromAxisAngle(rv / angle, angle)) or CFrame.new(pos)
		return cf, s
	end
	local cf0, s0 = sample(i0)
	if i1 == i0 or a <= 0 then return cf0, s0 end
	local cf1, s1 = sample(i1)
	return cf0:Lerp(cf1, a), s0 + (s1 - s0) * a
end

--- How far out each slab lies (0 centre .. 1 rim), from its rest pose: the break reaches it that far into the wave.
local function ffSlabReach(D)
	if FF.SlabReach then return FF.SlabReach end
	local reach = {}
	for _, sl in ipairs(D.Slabs) do
		local cf = ffTrackPose(sl.track, 0)
		reach[sl.mesh] = math.clamp(Vector3.new(cf.X, 0, cf.Z).Magnitude / D.Radius, 0, 1)
	end
	FF.SlabReach = reach
	return reach
end

local function easeOutQuad(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

local function easeOutBack(x, s)
	x = math.clamp(x, 0, 1) - 1
	return x * x * ((s + 1) * x + s) + 1
end

FF.Pool = {}

-- CryoFX (2026-09-24): the grounded Cryo visuals. Looked up when first needed rather than required here, because it
-- requires this module; nil when it is not in the place, and the old look plays.
local cryoFXModule = nil
local function cryoFX()
	if cryoFXModule == nil then
		local m = script.Parent:FindFirstChild("CryoFX")
		local ok, mod = pcall(function() return m and require(m) end)
		cryoFXModule = (ok and mod) or false
	end
	return cryoFXModule or nil
end

-- Cryo's FROSTBLADE skin (2026-10-14): its kunai meshes and who wears it (FrostbladeKit), found lazily like CryoFX
local frostbladeModule = nil
local function frostblade()
	if frostbladeModule == nil then
		local m = script.Parent:FindFirstChild("FrostbladeKit")
		local ok, mod = pcall(function() return m and require(m) end)
		frostbladeModule = (ok and mod) or false
	end
	return frostbladeModule or nil
end

-- ...and Cryo's FROST LOTUS skin (2026-10-15; FrostLotusKit): its M1 shot is the petal dart
local frostLotusModule = nil
local function frostLotus()
	if frostLotusModule == nil then
		local m = script.Parent:FindFirstChild("FrostLotusKit")
		local ok, mod = pcall(function() return m and require(m) end)
		frostLotusModule = (ok and mod) or false
	end
	return frostLotusModule or nil
end

-- ...and Cryo's SNOW GLOBE skin (Epic, 2026-10-15; SnowGlobeKit): its M1 shot is the mini globe, its Flash Freeze the ring
local snowGlobeModule = nil
local function snowGlobe()
	if snowGlobeModule == nil then
		local m = script.Parent:FindFirstChild("SnowGlobeKit")
		local ok, mod = pcall(function() return m and require(m) end)
		snowGlobeModule = (ok and mod) or false
	end
	return snowGlobeModule or nil
end

-- CRYO v2 (2026-10-08): the approved real-ice look (vfx_blocking/cryo/ice_v2: CRYO_V2_HANDOFF.md section 1, RECIPE.md).
-- A VISUAL restyle only: Radius, the front's curve (FlashFreezeRadiusAt, which the server freezes by), LeadIn, ExpandTime,
-- BreakTime, the crack race and the baked slab break are the ones above and in FlashFreezeData.
--   THE FROST LINE  a thin ring of saturated cyan (#3FE0FF) Beams riding the front out to Radius over ExpandTime -- the one
--                   saturated accent. When the spread stops it dims over DimTime to the calm darker-blue rim (#245F9A) and
--                   holds as the zone's edge until the break. It is drawn for everyone, thinned or not.
--   THE FLOOR       FF_Sheet (and its slabs) as darker frosted cracked ice: Ice, tinted down, a little translucent, no gloss.
--                   Not a pale glowing disc.
--   THE CRYSTALS    milky Ice: tall thin pointed spikes (tinted toward mid ice #5BB8E8, Transparency 0.4) off a chunky
--                   six-sided base prism 2-3x wider (toward deep glacier #1D6FB8, nearly solid), and a white matte frost
--                   collar (Snow, #F2FBFF) over each cluster's foot. RimCount clusters at or below waist height (RimH) grow
--                   in a wave round the edge as the line dims; then InCount taller clusters (InH) sprout inside, centre
--                   outward. Each crystal grows along its length (ease-out, staggered); while a cluster grows its collar is a
--                   white-hot Neon flare that cools to frost -- the only other glow, and only then.
--   THE END         the crack ink races across the sheet in the Frost Line's hot end (#8DF3FF) as before; from BreakTime the
--                   shatter runs from the centre to the rim over Wave seconds: every crystal is thrown off, tumbles, lands
--                   and shrinks away, the collars settle into the floor, and the sheet's baked slabs break in the same wave.
--   LIGHT           a calm cold PointLight over the zone while it holds, flashes at the break and as the wave reaches the
--                   rim (none under flat light, see flatLit). Nothing casts a shadow: moving ice would rebuild the shadow map.
-- The crystals are the kit's own FF_Crystal_* meshes (CryoKit's CK_Crystal_* if those are missing), cloned and resized
-- non-uniformly -- no new assets. The layout is fixed (LayoutSeed) and every cast turns it to its seeded angle, as before.
-- GRAPHICS QUALITY / REDUCE ENEMY VFX (`thin`): each cluster keeps two spikes, and the small ones settle instead of flying;
-- an enemy's zone under Reduce Enemy VFX (`bare`) keeps only its Frost Line, its floor and its rim clusters (the edge).
local FF2 = {
	Line = Color3.fromRGB(63, 224, 255),        -- #3FE0FF the Frost Line
	LineHot = Color3.fromRGB(141, 243, 255),    -- #8DF3FF its hot end: the crack race
	Calm = Color3.fromRGB(36, 95, 154),         -- #245F9A the line once the spread stops
	-- the crystals are drawn through a SpecialMesh (ffKitPart), which ignores the meshes' baked cobalt vertex colours,
	-- so these ARE the colours: the reel's ramp #7CC6EE (tips) -> #1D6FB8 (the thick bases)
	Spike = Color3.fromRGB(176, 224, 248),      -- the spikes: pale milky ice
	Deep = Color3.fromRGB(64, 140, 208),        -- the chunky bases: deep glacier, nearly solid
	Floor = Color3.fromRGB(96, 150, 200),       -- the slabs of the break: darker frosted ice
	Frost = Color3.fromRGB(242, 251, 255),      -- #F2FBFF the frost skin
	Hot = Color3.new(1, 1, 1),                  -- the white-hot flare at a growing cluster's foot
	Light = Color3.fromRGB(115, 214, 255),      -- #73D6FF the cold light
	SpikeT = 0.22, BaseT = 0.14, FloorT = 0.15, SpikeGloss = 0.15,
	Disc = "rbxassetid://120221293491391",      -- the fractal frost sheet (tools/cryo2_textures.py c2_frost_disc)
	DiscT = 0.05, DiscTint = Color3.fromRGB(235, 246, 252),
	LineWidth = 0.2, CalmWidth = 0.12, CalmT = 0.3, LineLift = 0.12, LineSegs = 48, DimTime = 0.35, LineOut = 0.3,
	RimCount = 80, RimBand = { 0.9, 0.99 }, RimH = { 1.6, 2.5 }, RimSpikes = 4, RimWave = 0.35,
	InCount = 26, InBand = { 0.2, 0.78 }, InH = { 2.2, 4.6 }, InSpikes = 4, InSpan = 1.3,
	ThinSpikes = 2,
	Wave = 0.4, Gravity = 55, DebrisLife = { 1.0, 1.4 }, DebrisOut = 0.35, CollarOut = 0.3, SmallSpike = 1.2,
	ZoneLight = 1.5, LayoutSeed = 20261008,
}

--- The crystal meshes the clusters are cut from: the kit's own, or CryoKit's if the place has only that.
local function ffCrystalTemplates(src)
	local list = {}
	for _, child in ipairs(src:GetChildren()) do
		if child:IsA("MeshPart") and string.match(child.Name, "^FF_Crystal_%d+$") then list[#list + 1] = child end
	end
	if #list == 0 then
		local folder = meshFolder()
		local kit = folder and folder:FindFirstChild("CryoKit")
		for i = 1, 6 do
			local t = kit and kit:FindFirstChild("CK_Crystal_" .. i)
			if t and t:IsA("MeshPart") then list[#list + 1] = t end
		end
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)        -- the same layout in every place
	return list
end

--- Tips +Y toward the horizontal `dir` by `angle` radians.
local function ffTilt(dir, angle)
	if angle == 0 or dir.Magnitude < 1e-3 then return CFrame.identity end
	return CFrame.fromAxisAngle(Vector3.yAxis:Cross(dir.Unit), angle)
end

--- The template's own footprint shape, `width` across its wider side and `height` long.
local function ffFit(template, width, height)
	local s = template.Size
	local foot = math.max(s.X, s.Z)
	return Vector3.new(s.X / foot * width, height, s.Z / foot * width)
end

--- A kit mesh drawn through a SpecialMesh rather than cloned: a MeshPart's Color multiplies the mesh's baked vertex
--- colours (the pre-v2 toon bake, a saturated cobalt), a FileMesh SpecialMesh takes the part's Color as it is. The
--- part keeps a MeshPart's habits: its Size is what you see (the mesh's Scale follows), centred on the part.
local ffMeshSize = {}
local function ffKitPart(template)
	local wc = VFXLibrary.Wrap and VFXLibrary.Wrap.KitCopy and VFXLibrary.Wrap.KitCopy(template)   -- (a Mythic wrap's gradient copy)
	if wc then return wc end
	local native = ffMeshSize[template]
	if not native then
		local ok, ms = pcall(function() return template.MeshSize end)
		native = (ok and typeof(ms) == "Vector3" and ms.Magnitude > 1e-4) and ms or template.Size
		ffMeshSize[template] = native
	end
	local part = new("Part", {
		Name = template.Name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Massless = true, Transparency = 1, Material = Enum.Material.Ice, Reflectance = 0,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, Size = template.Size,
	})
	local m = new("SpecialMesh", { MeshType = Enum.MeshType.FileMesh, MeshId = template.MeshId }, part)
	local function fit()
		local sz = part.Size
		m.Scale = Vector3.new(sz.X / native.X, sz.Y / native.Y, sz.Z / native.Z)
	end
	fit()
	part:GetPropertyChangedSignal("Size"):Connect(fit)
	return part
end

--- One crystal of a cluster. Kind "Spike" | "Base" | "Collar"; Foot is its foot in the zone's space with +Y its length (an
--- imported MeshPart sits on its bounding-box centre, so it is drawn half its length up from there).
local function ffAddCrystal(set, c, template, kind, foot, size, t0, dur, thinHide, rng, out)
	local part = ffKitPart(template)
	local alpha = 0
	if kind == "Spike" then
		part.Color, part.Reflectance, alpha = FF2.Spike, FF2.SpikeGloss, FF2.SpikeT
	elseif kind == "Base" then
		part.Color, alpha = FF2.Deep, FF2.BaseT
	else
		part.Material, part.Color = Enum.Material.Snow, FF2.Frost
	end
	part.Parent = set.Folder
	set.Alpha[part] = alpha
	set.All[#set.All + 1] = part
	local cr = { Part = part, Kind = kind, Foot = foot, Size = size, T0 = t0, Dur = dur, Thin = thinHide }
	if kind ~= "Collar" then
		-- the break: thrown out and up from where it stood, tumbling until it lands, shrinking away (Life)
		local centre = foot * CFrame.new(0, size.Y * 0.5, 0)
		local heavy = kind == "Base"
		local side = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 0.35
		local v = (out + side) * rng:NextNumber(heavy and 2 or 4, heavy and 4.5 or 9)
			+ Vector3.new(0, rng:NextNumber(heavy and 3 or 6, heavy and 6 or 12), 0)
		local rest = math.min(size.X, size.Z) * 0.5
		local g = FF2.Gravity
		cr.P0, cr.R0, cr.V = centre.Position, centre.Rotation, v
		cr.Land = (v.Y + math.sqrt(v.Y * v.Y + 2 * g * math.max(0, centre.Position.Y - rest))) / g
		local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		cr.Axis = axis.Magnitude > 1e-3 and axis.Unit or Vector3.xAxis
		cr.Spin = rng:NextNumber(4, 10) * (heavy and 0.5 or 1)
		cr.Life = rng:NextNumber(FF2.DebrisLife[1], FF2.DebrisLife[2])
		cr.Small = size.Y < FF2.SmallSpike
	end
	c.Crystals[#c.Crystals + 1] = cr
	return cr
end

--- A cluster at `pos` (on the zone's floor): one chunky base prism, its frost collar, and `nSpikes` thin spikes, the
--- tallest `hc` studs. Rim clusters splay outward (`out`); inner ones stand up with their side spikes leaning off them.
local function ffCluster(set, templates, rng, pos, out, hc, nSpikes, rim, tGrow, R)
	local c = { Pos = pos, Reach = math.clamp(pos.Magnitude / R, 0, 1), T = tGrow, Rim = rim, Crystals = {} }
	local function pick() return templates[rng:NextInteger(1, #templates)] end
	local tangent = Vector3.yAxis:Cross(out)
	local wb = hc * rng:NextNumber(rim and 0.34 or 0.3, rim and 0.42 or 0.4)
	local hb = hc * rng:NextNumber(0.42, 0.56)
	local ba = rng:NextNumber(0, 2 * math.pi)
	local baseLean = rim and out or Vector3.new(math.sin(ba), 0, math.cos(ba))
	local turn = CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	local baseRot = ffTilt(baseLean, math.rad(rng:NextNumber(3, rim and 14 or 9))) * turn
	local baseDur = rng:NextNumber(0.15, 0.22)
	local tpl = pick()
	ffAddCrystal(set, c, tpl, "Base", CFrame.new(pos - Vector3.new(0, hb * 0.12, 0)) * baseRot, ffFit(tpl, wb, hb),
		tGrow, baseDur, false, rng, out)
	ffAddCrystal(set, c, tpl, "Collar", CFrame.new(pos - Vector3.new(0, hb * 0.06, 0)) * baseRot,
		ffFit(tpl, wb * 1.25, hb * 0.32), tGrow, baseDur, false, rng, out)
	local span = wb
	for j = 1, nSpikes do
		local hs = (j == 1) and hc * 0.96 or hc * rng:NextNumber(0.45, 0.82)
		local ws = math.max(0.16, wb / rng:NextNumber(1.5, 2.3)) * ((j == 1) and 1 or rng:NextNumber(0.7, 0.9))
		local oa = rng:NextNumber(0, 2 * math.pi)
		local od = Vector3.new(math.sin(oa), 0, math.cos(oa))
		local off = od * (wb * ((j == 1) and rng:NextNumber(0, 0.12) or rng:NextNumber(0.15, 0.3)))
		local leanDir, lean
		if rim then
			leanDir = out + tangent * rng:NextNumber(-0.5, 0.5) + od * 0.3
			lean = math.rad((j == 1) and rng:NextNumber(18, 32) or rng:NextNumber(28, 52))
		else
			leanDir = (j == 1) and od or (od + out * 0.15)
			lean = math.rad((j == 1) and rng:NextNumber(0, 10) or rng:NextNumber(14, 34))
		end
		local foot = CFrame.new(pos + off + Vector3.new(0, hb * 0.1, 0)) * ffTilt(leanDir, lean)
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
		local st = pick()
		ffAddCrystal(set, c, st, "Spike", foot, ffFit(st, ws, hs), tGrow + j * rng:NextNumber(0.02, 0.05),
			rng:NextNumber(0.18, 0.3), j > FF2.ThinSpikes, rng, out)
		span = math.max(span, (off.Magnitude + math.sin(lean) * hs) * 2)
	end
	c.Box = Vector3.new(span, hc, span)                 -- what ffBlocks tests a camera or a player against
	return c
end

--- The fixed layout: a rim of low clusters in a wave round the edge as the line dims, then taller ones inside.
local function ffLayout(set, D, templates)
	local rng = Random.new(FF2.LayoutSeed)
	local R = D.Radius
	local spreadEnd = D.LeadIn + D.ExpandTime
	for i = 1, FF2.RimCount do
		local a = (i - 1) / FF2.RimCount * 2 * math.pi + rng:NextNumber(-0.05, 0.05)
		local out = Vector3.new(math.sin(a), 0, math.cos(a))
		local r = R * rng:NextNumber(FF2.RimBand[1], FF2.RimBand[2])
		local tg = spreadEnd + FF2.RimWave * (i - 1) / FF2.RimCount + rng:NextNumber(0, 0.03)
		set.Clusters[#set.Clusters + 1] = ffCluster(set, templates, rng, out * r, out,
			rng:NextNumber(FF2.RimH[1], FF2.RimH[2]), FF2.RimSpikes, true, tg, R)
	end
	local r0, r1 = R * FF2.InBand[1], R * FF2.InBand[2]
	for k = 1, FF2.InCount do
		-- a sunflower spread over the inner band, so the clusters neither line up nor clump; taller toward the middle
		local u = (k - 0.5) / FF2.InCount
		local r = math.sqrt(r0 * r0 + (r1 * r1 - r0 * r0) * u) + rng:NextNumber(-0.6, 0.6)
		local a = k * 2.39996 + rng:NextNumber(-0.2, 0.2)
		local out = Vector3.new(math.sin(a), 0, math.cos(a))
		local f = math.clamp((r - r0) / (r1 - r0), 0, 1)
		local hc = math.clamp((FF2.InH[2] + (FF2.InH[1] - FF2.InH[2]) * f) * rng:NextNumber(0.85, 1.05), FF2.InH[1], FF2.InH[2])
		local tg = spreadEnd + 0.05 + FF2.InSpan * (k - 1) / math.max(1, FF2.InCount - 1) + rng:NextNumber(-0.06, 0.06)
		set.Clusters[#set.Clusters + 1] = ffCluster(set, templates, rng, out * r, out, hc, FF2.InSpikes, false, tg, R)
	end
end

--- The Frost Line ring: LineSegs straight camera-facing Beams between attachments on one host, moved out with the front.
local function ffBuildRing(parent)
	local host = ghostPart({ Name = "FrostLine" }, parent)
	local ring = { Host = host, Atts = {}, Dirs = {}, Beams = {}, On = false }
	local n = FF2.LineSegs
	for i = 1, n do
		local a = (i - 1) / n * 2 * math.pi
		ring.Dirs[i] = Vector3.new(math.sin(a), 0, math.cos(a))
		ring.Atts[i] = new("Attachment", { Name = "Line" .. i }, host)
	end
	for i = 1, n do
		ring.Beams[i] = new("Beam", {
			Attachment0 = ring.Atts[i], Attachment1 = ring.Atts[i % n + 1], FaceCamera = true, Segments = 1,
			Width0 = FF2.LineWidth, Width1 = FF2.LineWidth, Color = CS(FF2.Line), LightEmission = 1, LightInfluence = 0,
			Transparency = NS(0), Enabled = false,
		}, host)
	end
	return ring
end

local function ffRingOff(ring)
	if ring.On then
		for _, b in ipairs(ring.Beams) do b.Enabled = false end
		ring.On = false
	end
end

--- The ring at time t: on the front while it races (hot), dimming to the calm rim once the spread stops, out after the
--- break. `D` needs LeadIn, ExpandTime and BreakTime.
local function ffRingPose(ring, D, root, t)
	local r = VFXLibrary.FlashFreezeRadiusAt(t - D.LeadIn)
	if t < D.LeadIn or r < 0.3 or t >= D.BreakTime + FF2.LineOut then
		ffRingOff(ring)
		return
	end
	if ring.At ~= root then
		ring.At = root
		ring.Host.CFrame = root * CFrame.new(0, FF2.LineLift, 0)
	end
	if not ring.On then
		for _, b in ipairs(ring.Beams) do b.Enabled = true end
		ring.On = true
	end
	if r ~= ring.R then
		ring.R = r
		for i, att in ipairs(ring.Atts) do att.Position = ring.Dirs[i] * r end
	end
	local u = math.clamp((t - D.LeadIn - D.ExpandTime) / FF2.DimTime, 0, 1)
	local f = math.clamp((t - D.BreakTime) / FF2.LineOut, 0, 1)
	local key = math.floor(u * 30 + 0.5) * 100 + math.floor(f * 30 + 0.5)
	if key ~= ring.Key then
		ring.Key = key
		local col = CS(FF2.Line:Lerp(FF2.Calm, u))
		local a = FF2.CalmT * u
		local tr = NS(a + (1 - a) * f)
		local w = FF2.LineWidth + (FF2.CalmWidth - FF2.LineWidth) * u
		for _, b in ipairs(ring.Beams) do
			b.Color, b.Transparency, b.LightEmission, b.LightInfluence = col, tr, 1 - u, u
			b.Width0, b.Width1 = w, w
		end
	end
end

local function ffBuildSet()
	local folder = meshFolder()
	local src = folder and folder:FindFirstChild(FF.MeshFolder)
	if not (src and FF.Data) then return nil end
	local set = { Folder = new("Folder", { Name = "FlashFreezeKit" }), Parts = {}, Base = {}, Alpha = {}, All = {}, Clusters = {} }
	for _, template in ipairs(src:GetChildren()) do
		-- the sheet, its crack ink and its slabs; the crystals are cut from the templates below (the old FF_Crystal /
		-- FF_CrystalCrack / FF_Chunk pieces and their baked tracks are no longer drawn)
		local name = template.Name
		if template:IsA("MeshPart") and (name == "FF_Sheet" or string.match(name, "^FF_Ink_") or string.match(name, "^FF_Slab_")) then
			local part
			if name == "FF_Sheet" then
				-- the reel's sheet: the six-fold fractal frost disc with its white crust and ragged edge, one Decal on a
				-- clear flat part sized with the front (ffPose); its colour is the art's, not the toon sheet's bake
				part = new("Part", {
					Name = "FF_Sheet", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
					CastShadow = false, Massless = true, Transparency = 1, Size = Vector3.new(0.1, 0.05, 0.1),
				})
				set.Face = new("Decal", { Name = "Face", Face = Enum.NormalId.Top, Texture = FF2.Disc, Color3 = FF2.DiscTint,
					Transparency = 1 }, part)
			else
				part = ffKitPart(template)
			end
			if name == "FF_Sheet" then
				-- (its Decal carries the look; the part itself stays clear)
			elseif string.match(name, "^FF_Ink_") then
				part.Material, part.Color = Enum.Material.Neon, FF2.LineHot           -- the crack race
			else
				part.Material, part.Color = Enum.Material.Ice, FF2.Floor              -- darker frosted cracked ice
				set.Alpha[part] = FF2.FloorT
			end
			if name == "FF_Sheet" then set.Alpha[part] = 1 end
			part.Parent = set.Folder
			set.Parts[name] = part
			set.Base[name] = part.Size
			set.All[#set.All + 1] = part
		end
	end
	local templates = ffCrystalTemplates(src)
	if #templates > 0 then
		ffLayout(set, FF.Data, templates)
	elseif not warned.FlashFreezeCrystals then
		warned.FlashFreezeCrystals = true
		warn("[VFXLibrary] no FF_Crystal_* / CK_Crystal_* meshes found - Flash Freeze draws its floor and Frost Line only")
	end
	set.Ring = ffBuildRing(set.Folder)
	return set
end

local function ffHideAll(set)
	for _, part in ipairs(set.All) do
		if part.Transparency ~= 1 then part.Transparency = 1 end
		if part.LocalTransparencyModifier ~= 0 then part.LocalTransparencyModifier = 0 end
	end
	if set.Face then set.Face.Transparency = 1 end
	ffRingOff(set.Ring)
	set.Ring.At, set.Ring.R, set.Ring.Key = nil, nil, nil
end

--- Where a crystal must not be drawn for this viewer: the local camera, and every player's root.
--- Crystals don't collide, so a camera that ends up inside a cluster would see only ice, and a
--- player rooted inside one would be hidden from everyone. Such a cluster is hidden outright
--- (LocalTransparencyModifier 1).
local function ffOccluders()
	local cam = workspace.CurrentCamera
	local chars = {}
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		local rootPart = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then chars[#chars + 1] = rootPart.Position end
	end
	return { Camera = cam and cam.CFrame.Position, Characters = chars }
end

local function ffBlocks(occ, basePos, size)
	if not occ then return false end
	local half = math.max(size.X, size.Z) * 0.5
	local function inside(p, margin)
		local d = p - basePos
		return d.Y > -3.5 and d.Y < size.Y + 1 and (d.X * d.X + d.Z * d.Z) < (half + margin) ^ 2
	end
	if occ.Camera and inside(occ.Camera, 0.4) then return true end
	for _, p in ipairs(occ.Characters) do
		if inside(p, 0.6) then return true end
	end
	return false
end

--- A frost collar is a white-hot flare while its cluster grows, and cools to matte frost once it has.
local function ffCollar(part, cooled)
	local mat = cooled and Enum.Material.Snow or Enum.Material.Neon
	if part.Material ~= mat then
		part.Material = mat
		part.Color = cooled and FF2.Frost or FF2.Hot
	end
end

--- Pose a whole kit at time t (seconds since the cast; the same clock as the Blender blocking). `thin`: fewer spikes, and
--- the small ones settle at the break; `bare` (an enemy's zone under Reduce Enemy VFX): only the rim clusters as well.
local function ffPose(set, D, root, t, thin, placed, occ, bare, noCrystals)
	local P, B, M = set.Parts, set.Base, D.Meshes
	local alphaOf = set.Alpha
	local broken = t >= D.BreakTime
	local parts, cframes = {}, {}

	local function place(part, cf, size, visible, static)
		if not part then return end
		if not visible then
			if part.Transparency ~= 1 then part.Transparency = 1 end
			placed[part] = nil
			return
		end
		if size and part.Size ~= size then part.Size = size end
		if not (static and placed[part]) then
			parts[#parts + 1] = part
			cframes[#cframes + 1] = cf
			placed[part] = static or nil
		end
		local a = alphaOf[part] or 0
		if part.Transparency ~= a then part.Transparency = a end
	end

	-- the floor races out under the Frost Line, on the front the server freezes you by
	local sheet = P.FF_Sheet
	if sheet then
		local r = math.max(0.1, VFXLibrary.FlashFreezeRadiusAt(t - D.LeadIn))
		local on = t >= D.LeadIn and not broken
		place(sheet, root * CFrame.new(0, 0.04, 0), Vector3.new(2.2 * r, 0.05, 2.2 * r), on, r >= D.Radius - 1e-3)
		if set.Face then
			local ft = on and FF2.DiscT or 1
			if set.Face.Transparency ~= ft then set.Face.Transparency = ft end
		end
	end
	ffRingPose(set.Ring, D, root, t)

	-- the crack race, group by group outward
	for _, g in ipairs(D.Ink) do
		local c = M[g.mesh].centre
		place(P[g.mesh], root * CFrame.new(fromBlender(c[1], c[2], c[3])), nil, t >= g.t and not broken, true)
	end

	-- the crystals grow, stand, and go in the shatter wave (centre at BreakTime, rim Wave later)
	for _, c in ipairs(set.Clusters) do
		local tb = D.BreakTime + FF2.Wave * c.Reach
		local standing = t >= c.T and t < tb
		local ltm = (standing and ffBlocks(occ, (root * CFrame.new(c.Pos)).Position, c.Box)) and 1 or 0
		local skip = noCrystals or (bare and not c.Rim)
		for _, cr in ipairs(c.Crystals) do
			local part = cr.Part
			if skip or (thin and cr.Thin) or t < cr.T0 then
				place(part, nil, nil, false)
			elseif t < tb then
				local g = math.clamp((t - cr.T0) / cr.Dur, 0, 1)
				if cr.Kind == "Collar" then ffCollar(part, g >= 1) end
				if not (g >= 1 and placed[part]) then
					local k = math.max(0.02, 1 - (1 - g) ^ 3)              -- ease-out along its length
					place(part, root * cr.Foot * CFrame.new(0, cr.Size.Y * k * 0.5, 0),
						Vector3.new(cr.Size.X, cr.Size.Y * k, cr.Size.Z), true, g >= 1)
				end
			else
				local tau = t - tb
				if cr.Kind == "Collar" or (thin and cr.Small) then
					-- the collar (and, thinned, a small spike) settles into the floor rather than flying
					if cr.Kind == "Collar" then ffCollar(part, true) end
					local k = 1 - math.clamp(tau / FF2.CollarOut, 0, 1)
					place(part, root * cr.Foot * CFrame.new(0, cr.Size.Y * k * 0.5, 0),
						Vector3.new(cr.Size.X, math.max(0.02, cr.Size.Y * k), cr.Size.Z), k > 0)
				elseif tau >= cr.Life then
					place(part, nil, nil, false)
				else
					-- thrown: out and up, tumbling until it lands, then shrinking away over DebrisOut
					local tt = math.min(tau, cr.Land)
					local pos = cr.P0 + cr.V * tt - Vector3.new(0, 0.5 * FF2.Gravity * tt * tt, 0)
					local k = math.clamp((cr.Life - tau) / FF2.DebrisOut, 0.02, 1)
					place(part, root * CFrame.new(pos) * CFrame.fromAxisAngle(cr.Axis, cr.Spin * tt) * cr.R0, cr.Size * k, true)
				end
			end
			if part.LocalTransparencyModifier ~= ltm then part.LocalTransparencyModifier = ltm end
		end
	end

	-- the sheet's slabs replace it at the break, each going (on its baked track) as the wave reaches it
	local reach = broken and ffSlabReach(D)
	for _, sl in ipairs(D.Slabs) do
		local part = P[sl.mesh]
		if broken then
			local w = FF2.Wave * (reach[sl.mesh] or 0)
			local cf, s = ffTrackPose(sl.track, (t - w) * D.Fps)
			local cp = M[sl.mesh].centre
			place(part, root * cf * CFrame.new(fromBlender(cp[1], cp[2], cp[3]) * s), B[sl.mesh] * math.max(s, 0.01), s > 0.01)
		else
			place(part, nil, nil, false)
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--- The zone's own calm cold light while it holds, and its flashes at the break and as the wave reaches the rim.
local function ffLights(folder, ground, D)
	if flatLit() then return end
	local host = ghostPart({ Name = "FlashFreezeLight", CFrame = ground * CFrame.new(0, 4, 0) }, folder)
	local light = FF2.Light            -- (read now: the delays below run outside a Cryo wrap's palette)
	local zone = new("PointLight", { Color = light, Brightness = 0, Range = D.Radius + 4, Shadows = false }, host)
	task.delay(math.max(0, D.LeadIn + D.ExpandTime - 0.2), function()
		-- (2026-10-19, audit P5F-03) Reduce Flashing: the zone's calm light at half
		local rf = Settings.Get and Settings.Get("ReduceFlashing")
		if zone.Parent then tween(zone, 0.5, { Brightness = FF2.ZoneLight * (rf and 0.5 or 1) }) end
	end)
	task.delay(D.BreakTime, function()
		if not host.Parent then return end
		tween(zone, 0.6, { Brightness = 0 })
		burstLight(host, { Color = light, Brightness = 3, Range = D.Radius + 6 }, 0.25)
	end)
	task.delay(D.BreakTime + FF2.Wave, function()
		if host.Parent then burstLight(host, { Color = light, Brightness = 2.2, Range = D.Radius + 8 }, 0.25) end
	end)
end

function VFXLibrary.CastFlashFreeze(originPart, seed, casterCharacter, centerAt)
	local rng = Random.new(seed or 0)
	local exclude = { fxFolder() }
	if casterCharacter then table.insert(exclude, casterCharacter) end
	-- centerAt (2026-10-18): the server's own centre, now that the zone lands where the caster aimed; without it (the
	-- capture stages) the zone is drawn round originPart's feet as before
	local center = typeof(centerAt) == "Vector3" and centerAt or VFXLibrary.FlashFreezeCentre(originPart.Position, exclude)
	local ground = CFrame.new(center)
	local folder = new("Folder", { Name = "FlashFreeze" }, fxFolder())
	local R = T.FlashFreeze.Radius
	local dur = T.FlashFreeze.ExpandTime
	local wrap = VFXLibrary.Wrap       -- a Cryo wrap (CryoWrap): its palette rides the delays, the stepper and the pool
	local bind = wrap and wrap.Bind or function(f) return f end

	-- the slam: the existing impact burst and sounds, on the beat the front leaves the hand
	task.delay(T.FlashFreeze.LeadIn, bind(function()
		if not folder.Parent then return end
		local burst = ghostPart({ CFrame = ground * CFrame.new(0, 0.4, 0) }, folder)
		local cfx = cryoFX()
		if cfx and cfx.FlashFreezeSlam then
			cfx.FlashFreezeSlam(burst, ground)          -- grounded (2026-09-24): chunks of the floor and lit dust
		else
			emitter(burst, E.CrackRing(), { Size = NS({ 0, 2 }, { 1, 26 }), Lifetime = NR(0.6) }):Emit(1)
			emitter(burst, E.FrostPuff(), { Speed = NR(12, 22), SpreadAngle = Vector2.new(22, 22) }):Emit(18)
			emitter(burst, E.IceChips(), { Speed = NR(18, 34) }):Emit(26)
			emitter(burst, E.Glints(), { Speed = NR(12, 22) }):Emit(14)
		end
		-- v2: a short cold flash on the press, not a long blue wash (the zone keeps its own calm light, ffLights)
		burstLight(burst, { Color = FF2.Light, Brightness = 3, Range = 24 }, 0.3)
		playSound(burst, "NovaSlam")
		playSound(burst, "NovaFrost")
	end))

	local D = ffData()
	local pool = wrap and wrap.Pool(FF.Pool) or FF.Pool
	local set = D and (table.remove(pool) or ffBuildSet())
	if not set then
		-- the kit is not in the place: keep the zone readable -- the Frost Line on the front, over a plain frosted floor
		local Dx = { LeadIn = T.FlashFreeze.LeadIn, ExpandTime = dur, BreakTime = T.FlashFreeze.LeadIn + dur + T.FlashFreeze.RimLinger }
		local ring = ffBuildRing(folder)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > Dx.BreakTime + FF2.LineOut or not folder.Parent then
				conn:Disconnect()
				return
			end
			ffRingPose(ring, Dx, ground, t)
		end)
		task.delay(T.FlashFreeze.LeadIn, function()
			if not folder.Parent then return end
			local floor = new("Part", {
				Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
				CanTouch = false, CastShadow = false, Material = Enum.Material.Ice, Color = FF2.Floor,
				Transparency = FF2.FloorT, Size = Vector3.new(0.10, 1.2, 1.2),
				CFrame = ground * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2),
			}, folder)
			tween(floor, dur, { Size = Vector3.new(0.10, R * 2, R * 2) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end)
		Debris:AddItem(folder, Dx.BreakTime + FF2.LineOut + 0.2)
		return { Center = center, Radius = R, Duration = dur, Folder = folder, LeadIn = T.FlashFreeze.LeadIn }
	end

	-- Every cast is the same composed zone, turned to a seeded angle so repeats don't line up.
	-- GRAPHICS QUALITY / REDUCE ENEMY VFX: on low density, or for an enemy's cast with Reduce Enemy
	-- VFX on, each cluster keeps two spikes and the small ones settle at the break instead of flying;
	-- an enemy's zone under Reduce Enemy VFX keeps only its Frost Line, its floor and its rim (the edge).
	local root = ground * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local bare = Settings.ThinEnemyVFX and VFXLibrary.IsEnemy(casterCharacter)   -- (2026-10-19, audit P5F-06) an ENEMY's cast
	local thin = (Settings.EffectDensity or 1) < 0.75 or bare
	-- FROSTBLADE (2026-10-14): the zone keeps its floor and its Frost Line, its crystals give way to a few short kunai
	-- planted on the rim (CryoFX.FrostbladeEdge: up as the front reaches the rim, broken on the rim's wave)
	local fb = casterCharacter and frostblade()
	local fbk = fb ~= nil and fb.Built == true and fb.On(casterCharacter)
	if fbk then
		local cfx = cryoFX()
		if cfx and cfx.FrostbladeEdge then
			pcall(cfx.FrostbladeEdge, ground, R, T.FlashFreeze.LeadIn + dur - 0.08, D.BreakTime + FF2.Wave, casterCharacter)
		end
	end
	-- FROST LOTUS (2026-10-15): the crystals give way to a FIELD of lotus blooms unfurling as the wave passes (CryoFX's
	-- LotusField -> FrostLotusFX), each bursting on the rim's wave; the floor and the Frost Line stay
	local fl = casterCharacter and frostLotus()
	local flk = fl ~= nil and fl.Built == true and fl.On(casterCharacter)
	-- SNOW GLOBE (2026-10-15): the ring only -- the crystals give way to the globe's base-disc rim, its snow billowing up
	-- and settling into drifts (the same call: CryoFX.LotusField -> SnowGlobeFX.Field); nothing over a rooted target
	local sgm = casterCharacter and snowGlobe()
	local sgk = sgm ~= nil and sgm.Built == true and sgm.On(casterCharacter)
	-- FROST DRAGON (Mythic, 2026-10-16): the claw slam and the ring of spines (the same call: CryoFX.LotusField ->
	-- FrostDragonFX.Field); the floor, the Frost Line and the rooted body stay the Default's
	local fdmod = casterCharacter and script.Parent:FindFirstChild("FrostDragonKit")
	local okD, fdkit = pcall(function() return fdmod and require(fdmod) end)
	local ddk = okD and fdkit ~= nil and fdkit.Built == true and fdkit.On(casterCharacter)
	if flk or sgk or ddk then
		local cfx = cryoFX()
		if cfx and cfx.LotusField then
			pcall(cfx.LotusField, ground, R, T.FlashFreeze.LeadIn, dur, D.BreakTime, FF2.Wave, casterCharacter)
		end
	end
	local placed = {}
	ffHideAll(set)
	set.Folder.Parent = folder
	ffLights(folder, ground, D)
	local endT = D.Duration + FF2.Wave            -- the wave breaks the rim this much after the data's own end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(bind(function()
		local t = os.clock() - t0
		if t > endT or not folder.Parent then
			conn:Disconnect()
			ffHideAll(set)
			if pcall(function() set.Folder.Parent = nil end) then
				table.insert(pool, set)
			end
			if folder.Parent then folder:Destroy() end
			return
		end
		ffPose(set, D, root, t, thin, placed, ffOccluders(), bare, fbk or flk or sgk or ddk)
		if wrap and wrap.Grade then wrap.Grade(set.Folder) end   -- a Rare Cryo wrap's core-to-edge gradient
		if ddk and fdkit.GradeFF then fdkit.GradeFF(folder) end     -- Frost Dragon: the floor, ring and cracks in pale ice
	end))

	return { Center = center, Radius = R, Duration = dur, Folder = folder, LeadIn = T.FlashFreeze.LeadIn }
end

--- Studio preview: pose a Flash Freeze kit at time t without a cast (Edit mode has no Heartbeat
--- loop to drive it). Returns the preview folder; destroy it when done.
function VFXLibrary.PreviewFlashFreeze(cf, t, seedAngle)
	local D = ffData()
	local set = D and ffBuildSet()
	if not set then return nil end
	set.Folder.Name = "FlashFreezePreview"
	set.Folder.Parent = workspace
	ffPose(set, D, cf * CFrame.Angles(0, seedAngle or 0, 0), t, false, {})
	return set.Folder
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: COLD MOMENTUM
----------------------------------------------------------------------------------------------------
--- One frost mark under a planted foot. The mark is flat 2D art, so it is a sprite decal on an
--- invisible ground plate rather than a mesh: it pops in, holds, and shrinks away.
function VFXLibrary.ColdMomentumMark(character, foot, rng)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and foot) then return end
	local CM = T.ColdMomentum
	local gp, gn, hit = groundBelow(foot.Position, { character, fxFolder() }, 10)   -- casts from 6 above, so 4 below the foot
	if not hit then return end
	local look = flat(rootPart.CFrame.LookVector)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local right = look:Cross(gn)
	if right.Magnitude < 1e-3 then return end
	local cf = CFrame.fromMatrix(gp + gn * 0.03, right.Unit, gn) * CFrame.Angles(0, math.rad(rng:NextNumber(-CM.MarkYaw, CM.MarkYaw)), 0)
	local full = Vector3.new(CM.MarkWidth, 0.05, CM.MarkLength)
	local plate = new("Part", {
		Name = "ColdMomentumMark", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, Massless = true, Transparency = 1, Size = full * Vector3.new(0.4, 1, 0.4), CFrame = cf,
	})
	local art = C.Textures.FrostMark
	new("Decal", { Face = Enum.NormalId.Top, Texture = art[rng:NextInteger(1, #art)] }, plate)
	plate.Parent = fxFolder()
	tween(plate, CM.MarkPop, { Size = full }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(CM.MarkLife - CM.MarkOut, function()
		if plate.Parent then
			tween(plate, CM.MarkOut, { Size = Vector3.new(0.001, 0.05, 0.001) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	Debris:AddItem(plate, CM.MarkLife + 0.05)
end

--- Frozen/slowed state. This is the marker only -- the ice look itself is each viewer's own, drawn
--- by dressFrozen below. One state per character, whichever freeze put it there. The folder carries
--- its end time (the "Until" attribute, os.clock() where this runs -- the server), so a shorter freeze
--- landing on a longer one -- a Frost Slide patch stepped on while a Flash Freeze still holds you --
--- keeps the longer one instead of cutting it short. Everything that ends a freeze ends it by
--- destroying this folder, and the look follows it off.
function VFXLibrary.ApplyFrozenState(character, duration)
	if not character then return end
	if not (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart) then return end
	local now = os.clock()
	local old = character:FindFirstChild("IceFrozenState")
	if old then
		local ends = old:GetAttribute("Until")
		if type(ends) == "number" and ends > now + duration then return old end
		old:Destroy()
	end
	local folder = new("Folder", { Name = "IceFrozenState" }, character)
	folder:SetAttribute("Until", now + duration)
	Debris:AddItem(folder, duration)

	-- ...and let go on death as well (2026-09-21): the only exits were this timer and the zone/round
	-- clear, so a victim killed mid-freeze wore the ice, the snow and the held FROZEN! callout on the
	-- corpse until the timer happened to catch up.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local died = humanoid.Died:Connect(function() folder:Destroy() end)
		folder.Destroying:Connect(function() died:Disconnect() end)
	end
	return folder
end

--- The frozen look, built on each viewer's own client (2026-09-21): it used to be built beside the
--- marker on the server, so one fixed Highlight and emitter replicated to everybody and none of the
--- per-viewer work inside emitter() -- Graphics Quality, Reduce Enemy VFX, the flat-light damping --
--- ever reached the one effect that sits on an enemy body for seconds at a time. Highlight gives a
--- hard graphic edge, matching the toon language. The Highlight lives in the folder so it dies with
--- it; the emitter's attachment has to hang off the root instead, so it is walked off the same
--- signal. A replacement clears the old folder AND its snow emitter first, so overlapping freezes
--- never leave a second emitter running on the root.
local function dressFrozen(folder)
	local character = folder.Parent
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	if not root then return end
	for _, child in ipairs(root:GetChildren()) do
		if child.Name == "FrozenEmitterAttachment" and child:IsA("Attachment") then child:Destroy() end
	end
	-- PLAY-TEST FIX 2 (2026-10-08): the body reads as pale ice, not a dark silhouette. CryoFX draws the frozen look (a
	-- pale Highlight with a white rim, the colours nudged to IceMid, crust on the legs to the waist and caps on the head
	-- and shoulders), held for as long as this folder lives; without CryoFX, just the pale Highlight, which goes with
	-- the folder.
	local cfx = cryoFX()
	if cfx and cfx.FrozenHold then
		cfx.FrozenHold(character, folder, 0.5)
		-- the server destroys the folder; on a client that arrives as a removal (no Destroying), so watch its ancestry
		local gone
		gone = folder.AncestryChanged:Connect(function()
			if folder:IsDescendantOf(game) then return end
			gone:Disconnect()
			cfx.FrozenRelease(character, folder)
		end)
	else
		new("Highlight", {
			FillColor = Color3.fromRGB(214, 246, 255), FillTransparency = 0.55,
			OutlineColor = Color3.new(1, 1, 1), OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = character,
		}, folder)
	end
	local att = new("Attachment", { Name = "FrozenEmitterAttachment" }, root)
	emitter(att, E.SnowChunks(), { Rate = 10, Enabled = true, Speed = NR(0.5, 1.5), Lifetime = NR(1, 1.8) })
	-- the marker's "Until" is the server's os.clock(), which means nothing here, so the attachment
	-- takes its life from the folder rather than from a local timer
	local gone
	gone = folder.AncestryChanged:Connect(function()
		if folder:IsDescendantOf(game) then return end
		gone:Disconnect()
		att:Destroy()
	end)
end

if RunService:IsClient() then
	workspace.DescendantAdded:Connect(function(inst)
		if inst.Name == "IceFrozenState" and inst:IsA("Folder") then dressFrozen(inst) end
	end)
end

----------------------------------------------------------------------------------------------------
-- MOBILITY: FROST SLIDE
----------------------------------------------------------------------------------------------------
-- The brief replaced the manual's slick-trail slide: the caster DASHES, and a medium patch of the
-- ground they just left freezes over. Anyone who steps on it is frozen on contact -- no slip, no slow,
-- a clean freeze. Up to three uses. Blocked in blender_scripts/cryo_blocking/block_04_mobility_dash.py.
-- Two beats, and neither is a hit test (the contact freeze is the server's, AbilityHandler):
--   DASH   FrostSlideDashFX. A spray of chips where the dash leaves the ground, and a solid frost line
--          under each foot along the dash path -- solid on purpose, unlike Cold Momentum's dashed
--          footfall marks. The caster draws their own on the keypress (SpellshotInput); everyone else
--          draws it off the server's broadcast (AbilityFX).
--   PATCH  FrostSlidePatch. Flash Freeze's own ice sheet, scaled down to PatchRadius and ringed with six
--          of the kit's smallest crystals, spreading out from where the dash started. Its clock is the
--          server's (T0 is workspace:GetServerTimeNow()), so every client draws the patch at the radius
--          the server is freezing people by. At PatchLife it breaks: gone at once, shards where it was.
-- Nothing here fades. The meshes are opaque toon meshes, so pieces pop in, grow, shrink or break, and
-- none of it is registered for proximity fade -- that would hide the hazard from the very player who
-- is about to walk onto it.

--- Radius of the patch t seconds after it starts forming. The server's contact test runs on this same
--- curve, so what freezes you is exactly the ice you saw reach you.
function VFXLibrary.FrostSlidePatchRadiusAt(t)
	local S = T.FrostSlide
	local a = math.clamp(t / S.PatchForm, 0, 1)
	return S.PatchRadius * TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

--- A frame lying on the ground at `pos`: +Y up the surface normal, LookVector along `dir` laid onto
--- the surface.
local function surfaceFrame(pos, normal, dir)
	local up = (typeof(normal) == "Vector3" and normal.Magnitude > 1e-3) and normal.Unit or Vector3.yAxis
	local look = flat(typeof(dir) == "Vector3" and dir or Vector3.zero)
	local right = look:Cross(up)
	if right.Magnitude < 1e-3 then right = Vector3.zAxis:Cross(up) end
	if right.Magnitude < 1e-3 then right = Vector3.xAxis end
	return CFrame.fromMatrix(pos, right.Unit, up)
end

--- DASH: the spray where the dash leaves the ground and the two foot lines along its path, laid
--- straight from the start to where the dash is planned to end. `seed` is accepted so the call matches
--- the broadcast; the dash itself has nothing random to agree on.
function VFXLibrary.FrostSlideDashFX(character, startPos, dir, dist, seed)
	if typeof(startPos) ~= "Vector3" then return end
	local S = T.FrostSlide
	local exclude = { fxFolder() }
	if character then table.insert(exclude, character) end
	local along = flat(typeof(dir) == "Vector3" and dir or Vector3.zero)
	dist = math.max(0, tonumber(dist) or 0)
	-- the same 12-stud probe the server finds the patch with, so a dash that leaves a patch leaves lines
	local gp, gn, hit = groundBelow(startPos, exclude, 18)          -- 12 under the start, as the server's patch probe
	-- GRAPHICS QUALITY / REDUCE ENEMY VFX: the spray is skipped; the lines are the read and always draw
	local thin = (Settings.EffectDensity or 1) < 0.75
		or (Settings.ThinEnemyVFX and VFXLibrary.IsEnemy(character))   -- (2026-10-19, audit P5F-06)

	local spray = ghostPart({ Name = "FrostSlideSpray", CFrame = CFrame.new((hit and gp or startPos) + Vector3.new(0, 0.25, 0)) })
	if not thin then
		emitter(spray, E.IceChips(), { Speed = NR(8, 16) }):Emit(10)
		emitter(spray, E.FrostPuff()):Emit(5)
	end
	playSound(spray, "SlideStart")
	Debris:AddItem(spray, 3)

	-- an air dash leaves no lines: there is nothing under the feet to draw them on
	if not hit or dist < 0.2 then return end
	local gp1, _, hit1 = groundBelow(startPos + along * dist, exclude, 18)
	if not hit1 then gp1 = gp + along * dist end              -- off a ledge: carry on level
	local run = gp1 - gp
	local len = run.Magnitude
	if len < 0.2 then return end
	-- tilted to meet the far end if the heights differ, and stood up the start's ground normal
	local frame = CFrame.lookAt(gp, gp1, gn)

	-- One strip of a line, `cap` longer than the drawn length (the ink's LineInk past each end). It is
	-- drawn out from the start over the dash -- Size and CFrame on one easing, so the start end stays
	-- put -- held, then pulled thin to nothing rather than faded.
	local function strip(foot, width, height, lift, colour, cap)
		local base = frame * CFrame.new(foot, lift + height * 0.5, 0)
		local part = new("Part", {
			Name = "FrostSlideLine", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			CastShadow = false, Massless = true, Material = Enum.Material.SmoothPlastic, Color = colour,
			Size = Vector3.new(width, height, 0.05 + cap), CFrame = base * CFrame.new(0, 0, -0.025),
		}, fxFolder())
		tween(part, S.DashTime, { Size = Vector3.new(width, height, len + cap), CFrame = base * CFrame.new(0, 0, -len * 0.5) })
		task.delay(S.DashTime + S.LineHold, function()
			if part.Parent then
				tween(part, S.LineOut, { Size = Vector3.new(0.001, height, len + cap) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		Debris:AddItem(part, S.DashTime + S.LineHold + S.LineOut + 0.05)
	end
	-- a line under each foot: the ink underlay, and the fill standing a hair proud of it so the ink shows
	-- only as the border
	for _, side in ipairs({ 1, -1 }) do
		local foot = side * S.LineSpacing
		strip(foot, S.LineWidth + 2 * S.LineInk, 0.05, 0.02, COL.Outline, 2 * S.LineInk)
		strip(foot, S.LineWidth, 0.06, 0.025, COL.IceLight, 0)
	end
end

-- The patch's rim: six of the Flash Freeze kit's smallest crystals at Scale of their modelled size,
-- stood round At of the radius with a seeded jitter and leaning out, so the edge of the danger reads
-- even from a low angle. The kit roots each crystal a little below the ground (its layout pos z); the
-- same depth, scaled, is used here and read off the data once per mesh.
local RIM = {
	Meshes = { "FF_Crystal_30", "FF_Crystal_16", "FF_Crystal_35", "FF_Crystal_33", "FF_Crystal_31", "FF_Crystal_36" },
	-- tall enough to stand clear of the sheet's own 0.35-0.7 rim lip: at 0.24 they hid inside it
	Scale = 0.5, At = 0.92, Jitter = 0.3, Lean = 14,
	Depth = {},
}

local function rimDepth(D, mesh)
	local depth = RIM.Depth[mesh]
	if depth == nil then
		depth = 0
		for _, cr in ipairs(D.Crystals) do
			if cr.mesh == mesh then depth = cr.pos[3]; break end
		end
		RIM.Depth[mesh] = depth
	end
	return depth
end

local function kitPiece(template)
	local part = template:Clone()
	apply(part, {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Massless = true, Material = C.CrystalMaterial, Color = C.CrystalColor, Reflectance = 0, Transparency = 1,
	})
	pcall(function() part.DoubleSided = false end)       -- the ink hull only reads with backfaces culled
	return part
end

--- PATCH: the frozen ground left where a dash started. `center` and `normal` are the ground the server
--- found, `t0` the server time the patch starts forming; `caster`, when given, is whose dash it was
--- (Reduce Enemy VFX thins the break). Called late -- a joiner, a hitch -- it picks up at the right
--- phase, and past PatchLife it draws nothing.
function VFXLibrary.FrostSlidePatch(center, normal, dir, seed, t0, caster)
	local S = T.FrostSlide
	if typeof(center) ~= "Vector3" or type(t0) ~= "number" then return nil end
	if workspace:GetServerTimeNow() - t0 >= S.PatchLife then return nil end
	local rng = Random.new(seed or 0)
	local ground = surfaceFrame(center, normal, dir) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local folder = new("Folder", { Name = "FrostSlidePatch" }, fxFolder())
	local thin = (Settings.EffectDensity or 1) < 0.75
		or (Settings.ThinEnemyVFX and VFXLibrary.IsEnemy(caster))   -- (2026-10-19, audit P5F-06)

	-- the kit's sheet and rim crystals, cloned; without the kit, a plain frozen disc
	local D = ffData()
	local mf = meshFolder()
	local src = D and mf and mf:FindFirstChild(FF.MeshFolder)
	local sheetTemplate = src and src:FindFirstChild("FF_Sheet")
	local sheet, floor
	local crystals = {}
	if sheetTemplate and sheetTemplate:IsA("MeshPart") and D.Meshes.FF_Sheet then
		sheet = kitPiece(sheetTemplate)
		sheet.Color = S.PatchTint
		sheet.Parent = folder
		for i, name in ipairs(RIM.Meshes) do
			-- the seeded layout is drawn for every slot, so a missing mesh cannot shift the others
			local angle = (i - 1 + rng:NextNumber(-RIM.Jitter, RIM.Jitter)) / #RIM.Meshes * math.pi * 2
			local at = RIM.At * rng:NextNumber(0.94, 1.04)
			local lean = math.rad(RIM.Lean * rng:NextNumber(0.6, 1.3))
			local spin = rng:NextNumber(0, math.pi * 2)
			local template = src:FindFirstChild(name)
			if template and template:IsA("MeshPart") and D.Meshes[name] then
				local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local part = kitPiece(template)
				part.Color = S.PatchTint                    -- the same ice as the sheet they stand on
				part.Parent = folder
				crystals[#crystals + 1] = {
					Part = part, Base = template.Size, Centre = D.Meshes[name].centre, Out = out, At = at,
					-- lean the crystal's up toward `out`, then turn it about its own up
					Tilt = CFrame.fromAxisAngle(Vector3.yAxis:Cross(out), lean) * CFrame.Angles(0, spin, 0),
					Depth = rimDepth(D, name) * RIM.Scale,
				}
			end
		end
	else
		if not warned.FrostSlidePatch then
			warned.FrostSlidePatch = true
			warn(("[VFXLibrary] FF_Sheet not found in ReplicatedStorage.%s.%s - Frost Slide patches fall back to a plain disc")
				:format(C.MeshFolderName, FF.MeshFolder))
		end
		floor = new("Part", {
			Name = "FrostSlidePatchFloor", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false,
			CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic,
			Color = Color3.new(COL.IceLight.R * S.PatchTint.R, COL.IceLight.G * S.PatchTint.G, COL.IceLight.B * S.PatchTint.B),
			Transparency = 1, Size = Vector3.new(0.10, 0.2, 0.2),
			CFrame = ground * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2),
		}, folder)
	end

	-- The patch at `elapsed` seconds since it started forming. The sheet follows the radius curve the
	-- server freezes by, the way ffPose scales the full-size sheet (s = radius / the kit's radius); the
	-- crystals stand at the moving rim and erupt over the same PatchForm, as the kit's crystals do.
	local function pose(elapsed)
		local r = VFXLibrary.FrostSlidePatchRadiusAt(elapsed)
		local shown = elapsed > 0
		if sheet then
			local s = math.max(0.02, r / D.Radius)
			local c, b = D.Meshes.FF_Sheet.centre, sheetTemplate.Size
			sheet.Size = Vector3.new(b.X * s, b.Y, b.Z * s)
			sheet.CFrame = ground * CFrame.new(fromBlender(c[1] * s, c[2] * s, c[3]))
			sheet.Transparency = shown and 0 or 1
		elseif floor then
			floor.Size = Vector3.new(0.10, math.max(0.2, r * 2), math.max(0.2, r * 2))
			floor.Transparency = shown and 0 or 1
		end
		if #crystals == 0 then return end
		local g = math.clamp(elapsed / S.PatchForm, 0, 1)
		local k = RIM.Scale
		local z = k * math.max(0.001, easeOutBack(g, D.EruptBack))
		local xy = k * (0.5 + 0.5 * easeOutQuad(g))
		for _, cr in ipairs(crystals) do
			local c, b = cr.Centre, cr.Base
			local root = ground * CFrame.new(cr.Out * (r * cr.At) + Vector3.new(0, cr.Depth, 0)) * cr.Tilt
			cr.Part.Size = Vector3.new(b.X * xy, b.Y * z, b.Z * xy)
			cr.Part.CFrame = root * CFrame.new(fromBlender(c[1] * xy, c[2] * xy, c[3] * z))
			cr.Part.Transparency = g > 0 and 0 or 1
		end
	end

	-- THE CRACKS. The kit's crack ink is grouped by when each piece of it is reached as the cracks race
	-- out from the middle; scaled to the patch like the sheet (s = PatchRadius / the kit's radius, height
	-- unscaled so the ink stays on the ice), each group is cloned and shown at its turn, the kit's own
	-- 0.2 s of spread fitted into CrackSpread. Nothing is made until the cracks begin.
	-- Thinned (low Graphics Quality, or an enemy's patch with Reduce Enemy VFX), only the groups nearer the
	-- middle are drawn: the rim-side ends and forks are the thinnest strokes and the least readable.
	local cracks = {}
	if sheet and D.Ink and #D.Ink > 0 then
		local first, last = D.Ink[1].t, D.Ink[#D.Ink].t
		for _, g in ipairs(D.Ink) do
			local template = src:FindFirstChild(g.mesh)
			local u = (last > first) and (g.t - first) / (last - first) or 0
			if template and template:IsA("MeshPart") and D.Meshes[g.mesh] and not (thin and u > 0.6) then
				cracks[#cracks + 1] = {
					Template = template, Centre = D.Meshes[g.mesh].centre,
					At = S.PatchLife - S.CrackLead + u * S.CrackSpread,
				}
			end
		end
	end
	local crackNext = 1
	local function crackTo(elapsed)
		local s = S.PatchRadius / D.Radius
		while cracks[crackNext] and elapsed >= cracks[crackNext].At do
			local cr = cracks[crackNext]
			local part = kitPiece(cr.Template)
			local c, b = cr.Centre, cr.Template.Size
			part.Size = Vector3.new(b.X * s, b.Y, b.Z * s)
			part.CFrame = ground * CFrame.new(fromBlender(c[1] * s, c[2] * s, c[3]))
			part.Transparency = 0
			part.Parent = folder
			crackNext += 1
		end
	end

	-- the break: everything goes at once and a burst of shards jumps off where the ice was
	local function shatter()
		local R = S.PatchRadius
		local burst = ghostPart({ Name = "FrostSlidePatchBreak", Size = Vector3.new(R * 1.8, 0.4, R * 1.8),
			CFrame = ground * CFrame.new(0, 0.3, 0) })
		folder:Destroy()
		emitter(burst, E.Shards(), { EmissionDirection = Enum.NormalId.Top, Speed = NR(4, 9),
			SpreadAngle = Vector2.new(45, 45) }):Emit(thin and math.ceil(S.BreakShards / 2) or S.BreakShards)
		playSound(burst, "PatchBreak")
		Debris:AddItem(burst, 2.5)
	end

	-- The server's clock drives every beat. Size and CFrame are written only while the patch is forming;
	-- after that the loop only pops each crack group in at its turn and watches for the break (or for the
	-- FX folder being cleared under it).
	local formed = false
	local e0 = workspace:GetServerTimeNow() - t0
	pose(e0)
	-- called late, inside the crack window: the cracks already due are there on the first drawn frame
	if cracks[crackNext] and e0 >= cracks[crackNext].At then crackTo(e0) end
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not folder.Parent then conn:Disconnect(); return end
		local elapsed = workspace:GetServerTimeNow() - t0
		if elapsed >= S.PatchLife then
			conn:Disconnect()
			shatter()
			return
		end
		if not formed then
			pose(elapsed)
			formed = elapsed >= S.PatchForm
		end
		if cracks[crackNext] and elapsed >= cracks[crackNext].At then crackTo(elapsed) end
	end)
	return folder
end

----------------------------------------------------------------------------------------------------
-- DEFENSE: CHILL AURA
----------------------------------------------------------------------------------------------------
-- "Passive slow-and-freeze zone around you -- a melee deterrent, not a blockable object."
-- CHILL AURA v2 (2026-09-14): the Chill Aura reference sequence, flattened to house style and built to FORM.
-- Nothing is ever drawn larger or smaller than it is: every piece crystallises in place and un-forms the same way.
--   EDGE     the zone edge on the floor at the true radius (corners 8.00). 24 facets grow out of 6 seed corners
--            (the first in front of the caster) and close by 0.30 -- damage can first tick at 0.35. It holds, whole,
--            until the zone ends, then the facets draw back into their seeds.
--   ORBIT    the concentric middle and inner rings (facet by facet from their seeds) and six Icicle crystals (grown
--            from the heel while lifting into two tiers); turns slowly; at the linger the rings draw back and the
--            crystals shrink to their tips as they fall.
--   VORTEX   three swooshes that draw themselves from the ring up and around the caster, chord by chord, turning
--            faster than the orbit; at the linger each is wiped from its base toward its head.
--   MIST     a FrostTile disc on the floor whose radius grows under a tile that stays still (it spreads, it doesn't
--            zoom), then recedes.
--   SNOW     sparse hard-edged Shard flakes on a shell around the caster, off before the zone ends.
--
-- THE KIT: blender_scripts/cryo_blocking/final_chill_aura_v2.py -> IceMagicMeshes.ChillAuraV2 (88 pieces, each in its
-- own frame with +X its growth axis, plus the merged CA2_Edge / CA2_Orbit / CA2_Vortex) and IceMagic.ChillAuraData
-- (the layout and every piece's forming and un-forming window, Blender coordinates, timed for a 6 s aura). Pieces
-- are only drawn while something is forming or un-forming; in between each component is its one merged mesh, which
-- is exactly the union of its pieces, so the swap never shows. Sets of parts are cloned from one prepared prototype
-- and pooled. A kit that does not match the data (a mesh missing or renamed) is refused and the plain ring is used.
--
-- WHO SEES WHAT. Everyone else sees the whole aura for the whole zone. The caster sees it all form -- the forming is
-- their own feedback (an early version hid the caster's swooshes and crystals outright; the forming went unseen) --
-- and then their own swooshes are wiped away soon after, the same base-to-head wipe as the linger (OwnWindOut),
-- because in first person they cross the view; the edge, rings, crystals, mist and snow stay. Thinned (low Graphics
-- Quality, or someone else's aura with Reduce Enemy VFX on) only the edge is drawn -- the zone's edge.
--
-- HONESTY. The hit test is an 8-stud sphere at the caster's HumanoidRootPart. The edge sits on the floor under the
-- caster and, while the caster is up in the air, its reach shrinks (horizontally only) to how far that sphere still
-- touches a standing body -- sqrt(64 - (H - 5.2)^2) for a root H studs over the floor -- so it never promises more
-- than the server hits. The orbit and vortex ride the caster's feet and stay inside the sphere.
--
-- STOPS. The clock is the server's (t0), so a late broadcast picks up at the right phase. A stop (the caster died)
-- freezes whatever was still forming where it was, and every group that had not begun to un-form does so in the
-- same order, compressed into EdgeQuick (the edge) or OutQuick; groups already un-forming finish on their own time.
-- VFXLibrary.ChillAuraClock, when set, replaces the server clock (a review hook for freezing a frame).

VFXLibrary.ActiveAuras = {}

-- (2026-10-19, audit GB-04) RETIRED: no Abilities row casts Chill Aura; its 9 locals are scoped to this do-block so
-- they no longer count against the main chunk's 200 (otherwise unchanged).
do
local CA = { DataName = "ChillAuraData", MeshFolder = "ChillAuraV2", Pool = {}, PoolMax = 10 }
local CA_GROUPS = { "Edge", "Orbit", "Vortex" }

local function caClock()
	return VFXLibrary.ChillAuraClock and VFXLibrary.ChillAuraClock() or workspace:GetServerTimeNow()
end

local function caData()
	if CA.Data ~= nil then return CA.Data end
	CA.Data = false
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local module = ice and ice:FindFirstChild(CA.DataName)
	local folder = meshFolder()
	local src = folder and folder:FindFirstChild(CA.MeshFolder)
	if not (module and src) then
		warn(("[VFXLibrary] IceMagic.%s or %s.%s is missing - Chill Aura falls back to a plain ring")
			:format(CA.DataName, C.MeshFolderName, CA.MeshFolder))
		return false
	end
	local ok, D = pcall(require, module)
	if not ok or type(D) ~= "table" or type(D.Pieces) ~= "table" then
		warn("[VFXLibrary] IceMagic." .. CA.DataName .. " did not load - Chill Aura falls back to a plain ring")
		return false
	end
	-- the kit must match the data: every mesh the data names, as a MeshPart, with a size and centre
	local missing, names = {}, {}
	for _, p in ipairs(D.Pieces) do names[#names + 1] = p.mesh end
	for _, g in ipairs(CA_GROUPS) do names[#names + 1] = D.Merged and D.Merged[g] end
	for i = 1, #D.Pieces + #CA_GROUPS do
		local name = names[i]
		local t = name and src:FindFirstChild(name)
		if not (t and t:IsA("MeshPart") and D.Meshes and D.Meshes[name] and D.Groups and D.Groups.Edge) then
			missing[#missing + 1] = tostring(name)
		end
	end
	if #missing > 0 then
		warn(("[VFXLibrary] %s.%s does not match ChillAuraData (missing: %s) - Chill Aura falls back to a plain ring")
			:format(C.MeshFolderName, CA.MeshFolder, table.concat(missing, ", ", 1, math.min(#missing, 8))))
		return false
	end

	-- one prepared prototype: every set is a single Clone of it
	local proto = new("Folder", { Name = "ChillAura" })
	for _, name in ipairs(names) do
		kitPiece(src:FindFirstChild(name)).Parent = proto
	end
	local mist = new("Part", {
		Name = "CA2_Mist", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
		CanTouch = false, CastShadow = false, Massless = true, Transparency = 1, Size = Vector3.new(0.05, 1, 1),
	}, proto)
	-- only the upward cap (+X, turned up by the placement) carries the tile; the other faces the floor
	new("Texture", { Name = "Tile", Texture = C.Textures.FrostTile, Face = Enum.NormalId.Right,
		StudsPerTileU = T.ChillAura.MistTile, StudsPerTileV = T.ChillAura.MistTile, Transparency = 1 }, mist)
	CA.Proto = proto

	CA.ByGroup = { Edge = {}, Orbit = {}, Vortex = {} }
	for i, p in ipairs(D.Pieces) do
		local q = p.rot
		local axis = fromBlender(q[2], q[3], q[4])
		p.Index = i
		p.CF = CFrame.new(fromBlender(p.pos[1], p.pos[2], p.pos[3])) * CFrame.new(0, 0, 0, axis.X, axis.Y, axis.Z, q[1])
		p.Centre = D.Meshes[p.mesh].centre
		p.Base = src:FindFirstChild(p.mesh).Size
		table.insert(CA.ByGroup[p.group], p)
	end
	CA.MergedOffset, CA.MergedBase = {}, {}
	for _, g in ipairs(CA_GROUPS) do
		local c = D.Meshes[D.Merged[g]].centre
		CA.MergedOffset[g] = fromBlender(c[1], c[2], c[3])
		CA.MergedBase[g] = src:FindFirstChild(D.Merged[g]).Size
	end
	CA.Data = D
	return D
end

local function caAcquireSet(D)
	local set = table.remove(CA.Pool)
	if set then return set end
	local folder = CA.Proto:Clone()
	set = { Folder = folder, Shown = {}, PieceParts = {}, Merged = {}, PiecesOn = {} }
	for _, p in ipairs(D.Pieces) do set.PieceParts[p.Index] = folder:FindFirstChild(p.mesh) end
	for _, g in ipairs(CA_GROUPS) do set.Merged[g] = folder:FindFirstChild(D.Merged[g]) end
	set.Mist = folder:FindFirstChild("CA2_Mist")
	set.MistTile = set.Mist:FindFirstChild("Tile")
	return set
end

local function caShow(set, part, on)
	if set.Shown[part] ~= on then
		set.Shown[part] = on
		part.Transparency = on and 0 or 1
	end
end

local function caReleaseSet(set)
	for part, on in pairs(set.Shown) do
		if on then part.Transparency = 1 end
	end
	table.clear(set.Shown)
	table.clear(set.PiecesOn)
	set.MistTile.Transparency = 1
	set.MistOn, set.MistR, set.EdgeK = false, nil, nil
	if #CA.Pool < CA.PoolMax then
		set.Folder.Parent = nil
		table.insert(CA.Pool, set)
	else
		set.Folder:Destroy()
	end
end

--- How much of a piece is drawn at `e`, the end it grows or shrinks from, its lift, and whether it is un-forming.
--- `shift` moves every un-forming time with the aura's real duration (the data is timed for D.Duration). Stopped
--- (`stop`), forming freezes where it was, and a group that had not started to un-form does it compressed into
--- `quick` from the stop -- shrinking from the end it was growing from if it never finished growing.
local function caPiece(p, e, stop, info, quick, shift)
	local ein = stop and math.min(e, stop) or e
	if ein < p.inT[1] then return 0, p.inPivot, 0 end
	local sIn = easeOutQuad((ein - p.inT[1]) / math.max(1e-6, p.inT[2] - p.inT[1]))
	local lift = -p.rise * (1 - sIn)
	local outStart, outEnd = info.OutStart + shift, info.OutEnd + shift
	local o1, o2 = p.outT[1] + shift, p.outT[2] + shift
	local pivot = p.outPivot
	if stop and stop < outStart then
		local span = math.max(1e-6, outEnd - outStart)
		o1 = stop + (o1 - outStart) / span * quick
		o2 = stop + (o2 - outStart) / span * quick
		if sIn < 1 then pivot = p.inPivot end
	end
	if e >= o1 then
		local u = math.clamp((e - o1) / math.max(1e-6, o2 - o1), 0, 1)
		u *= u
		return sIn * (1 - u), pivot, lift - p.drop * u
	end
	return sIn, p.inPivot, lift
end

--- The plain stand-in when the kit is missing: the old ground ring on the floor for the duration.
local function caFallback(character, root, duration, t0)
	local folder = new("Folder", { Name = "ChillAura" }, fxFolder())
	local ring = getMesh("ChillAuraRing", "Aura")
	ring.Parent = folder
	local handle = { Alive = true, Character = character, Folder = folder, Radius = T.ChillAura.Radius, T0 = t0, StopAt = nil }
	local function finish()
		if not handle.Alive then return end
		handle.Alive = false
		if handle.Connection then handle.Connection:Disconnect() end
		if VFXLibrary.ActiveAuras[character] == handle then VFXLibrary.ActiveAuras[character] = nil end
		folder:Destroy()
	end
	handle.Finish = finish
	handle.Connection = RunService.Heartbeat:Connect(function()
		local e = caClock() - t0
		if not root:IsDescendantOf(workspace) or e >= (handle.StopAt or duration) then finish() return end
		local gp = groundBelow(root.Position, { character, fxFolder() }, 14)
		ring.CFrame = CFrame.new(gp + Vector3.new(0, 0.05, 0))
	end)
	VFXLibrary.ActiveAuras[character] = handle
	return handle
end

--- `duration` and `t0` (the server time of the cast) come from the server's broadcast.
function VFXLibrary.CastChillAura(character, duration, t0)
	VFXLibrary.StopChillAura(character, true)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then return nil end
	local A = T.ChillAura
	duration = duration or A.Duration
	t0 = (type(t0) == "number") and t0 or caClock()
	local D = caData()
	if not D then
		if caClock() - t0 >= duration then return nil end
		return caFallback(character, root, duration, t0)
	end
	local G = D.Groups
	local shift = duration - D.Duration                            -- the data is timed for a D.Duration aura
	local natural = G.Edge.OutEnd + shift                          -- the edge draws back just after the zone ends
	if caClock() - t0 >= natural then return nil end

	local localPlayer = game:GetService("Players").LocalPlayer
	local isCaster = character == VFXLibrary.LocalCharacter or (localPlayer ~= nil and character == localPlayer.Character)
	local thin = (Settings.EffectDensity or 1) < 0.75 or (Settings.ThinEnemyVFX and not isCaster)
	local drawn = { Edge = true, Orbit = not thin, Vortex = not thin }

	--- When group `g` starts to un-form ahead of its own time (nil: it doesn't) and how long that takes: a stop (the
	--- caster died) compresses it, and the caster's own swooshes go soon after they have formed.
	local function earlyOut(g, stop)
		if g == "Vortex" and isCaster and (stop == nil or A.OwnWindOut[1] < stop) then
			return A.OwnWindOut[1], A.OwnWindOut[2] - A.OwnWindOut[1]
		end
		return stop, (g == "Edge") and A.EdgeQuick or A.OutQuick
	end
	local set = caAcquireSet(D)
	set.Folder.Parent = fxFolder()

	-- the edge's first seed faces where the caster was looking: Blender +X is MeshPart -X
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local yaw = math.atan2(look.Z, -look.X)
	local yawCF = CFrame.Angles(0, yaw, 0)

	local snowPart, snow, snowOn = nil, nil, false
	if not thin then
		snowPart = ghostPart({ Name = "ChillAuraSnow", Size = Vector3.new(A.SnowShell * 2, A.SnowHeight, A.SnowShell * 2) }, fxFolder())
		snow = emitter(snowPart, E.AuraSnow(), { Rate = A.SnowRate, Enabled = false })
	end

	local handle = { Alive = true, Character = character, Folder = set.Folder, Radius = A.Radius, T0 = t0, StopAt = nil }
	local rayParams = makeRayParams({ character, fxFolder() })
	local floorY, floorN, nextProbe = nil, Vector3.yAxis, 0
	local soundPlayed = false
	local lastRX, lastRZ, lastFloorY, lastN, lastK = nil, nil, nil, nil, nil
	local floorCF = nil
	local parts, frames = {}, {}
	local finishAt = natural

	local function finish()
		if not handle.Alive then return end
		handle.Alive = false
		if handle.Connection then handle.Connection:Disconnect() end
		if VFXLibrary.ActiveAuras[character] == handle then VFXLibrary.ActiveAuras[character] = nil end
		if snowPart then
			snow.Enabled = false
			Debris:AddItem(snowPart, 0.7)                          -- specks in the air live out their 0.6 s
		end
		caReleaseSet(set)
	end
	handle.Finish = finish

	--- once a stop is known: the aura ends when the last group, compressed or not, has un-formed
	local function endAfterStop(stop)
		local t = stop + A.EdgeQuick
		for _, g in ipairs(CA_GROUPS) do
			if drawn[g] then
				local gStop, quick = earlyOut(g, stop)
				t = math.max(t, (gStop < G[g].OutStart + shift) and (gStop + quick) or (G[g].OutEnd + shift))
			end
		end
		if not thin then
			t = math.max(t, (stop < A.MistOut[1] + shift) and (stop + A.OutQuick) or (A.MistOut[2] + shift))
		end
		return math.min(natural, t)
	end

	local function place(part, cf)
		parts[#parts + 1] = part
		frames[#frames + 1] = cf
	end

	handle.Connection = RunService.Heartbeat:Connect(function()
		local now = caClock()
		local e = now - t0
		local stop = handle.StopAt
		if stop and not handle.EndFixed then
			handle.EndFixed = true
			finishAt = endAfterStop(stop)
		end
		if e >= finishAt or not root:IsDescendantOf(workspace) or not humanoid.Parent then
			finish()
			return
		end
		if e < A.LeadIn then return end
		if not soundPlayed then
			soundPlayed = true
			if e < G.Edge.InEnd + 0.3 and not (stop and stop < A.LeadIn) then playSound(root, "AuraOn") end
		end
		table.clear(parts)
		table.clear(frames)

		-- the floor under the caster (probed 10 times a second on the wall clock) and how far the sphere reaches it
		local wall = os.clock()
		if wall >= nextProbe then
			nextProbe = wall + A.FloorEvery
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -A.FloorProbe, 0), rayParams)
			floorY = hit and hit.Position.Y or nil
			floorN = hit and hit.Normal or Vector3.yAxis
			if floorN.Y < math.cos(math.rad(A.MaxTilt)) then floorN = Vector3.yAxis end
		end
		local rp = root.Position
		local k = 0
		if floorY then
			local over = rp.Y - floorY - A.HeadTop
			k = math.floor(math.sqrt(math.max(0, A.Radius * A.Radius - math.max(0, over) ^ 2)) / A.Radius * 20) / 20
		end
		local floorMoved = rp.X ~= lastRX or rp.Z ~= lastRZ or floorY ~= lastFloorY or floorN ~= lastN
		local edgeChanged = floorMoved or k ~= lastK
		if floorMoved then
			floorCF = floorY and (CFrame.new(rp.X, floorY, rp.Z) * CFrame.fromRotationBetweenVectors(Vector3.yAxis, floorN) * yawCF) or nil
			lastRX, lastRZ, lastFloorY, lastN = rp.X, rp.Z, floorY, floorN
		end
		lastK = k
		-- where the orbit and the wind stand: the floor while the body stands on it (the HipHeight estimate can land a
		-- little under it), the feet once they are clearly off it
		local feet = rp.Y - root.Size.Y * 0.5 - humanoid.HipHeight
		if floorY and feet < floorY + 0.5 then feet = floorY end

		for _, g in ipairs(CA_GROUPS) do
			if drawn[g] then
				local info = G[g]
				local groupCF
				if g == "Edge" then
					groupCF = floorCF
				else
					local spin = ((g == "Orbit") and A.SpinOrbit or A.SpinVortex) * math.max(0, e - D.SpinStart)
					groupCF = CFrame.new(rp.X, feet, rp.Z) * CFrame.Angles(0, yaw + spin, 0)
				end
				local visible = groupCF ~= nil and (g ~= "Edge" or k >= 0.1)
				local gStop, quick = earlyOut(g, stop)
				local outStart, outEnd = info.OutStart + shift, info.OutEnd + shift
				if gStop and gStop < outStart then outStart, outEnd = gStop, gStop + quick end
				local steady = visible and e >= info.InEnd and e < outStart

				-- the merged mesh: drawn whole while the group is formed
				local merged = set.Merged[g]
				if steady then
					local fresh = not set.Shown[merged]
					caShow(set, merged, true)
					if g ~= "Edge" then
						place(merged, groupCF * CFrame.new(CA.MergedOffset[g]))
					elseif fresh or edgeChanged then
						if set.EdgeK ~= k then
							set.EdgeK = k
							local b = CA.MergedBase.Edge
							merged.Size = Vector3.new(b.X * k, b.Y, b.Z * k)   -- reach shrinks, height does not
						end
						local o = CA.MergedOffset.Edge
						place(merged, groupCF * CFrame.new(o.X * k, o.Y, o.Z * k))
					end
				else
					caShow(set, merged, false)
				end

				-- the pieces: only walked while forming or un-forming (and once more to hide them)
				local want = visible and not steady and e < outEnd
				if want or set.PiecesOn[g] then
					set.PiecesOn[g] = want
					local kk = (g == "Edge") and k or 1
					for _, p in ipairs(CA.ByGroup[g]) do
						local part = set.PieceParts[p.Index]
						local s, pivot, lift = 0, 0, 0
						if want then s, pivot, lift = caPiece(p, e, gStop, info, quick, shift) end
						if s > 0.02 then
							local c, base = p.Centre, p.Base
							local cx = (pivot == 1) and (p.len + (c[1] - p.len) * s) or (c[1] * s)
							local lcf = CFrame.new(0, lift, 0) * p.CF * CFrame.new(fromBlender(cx, c[2], c[3]))
							if kk ~= 1 then
								local lp = lcf.Position
								lcf = CFrame.new(lp.X * kk, lp.Y, lp.Z * kk) * lcf.Rotation          -- edge frames are yaw-only
							end
							part.Size = Vector3.new(base.X * s * kk, base.Y, base.Z * kk)
							caShow(set, part, true)
							place(part, groupCF * lcf)
						else
							caShow(set, part, false)
						end
					end
				end
			end
		end

		-- mist: the disc's radius grows under a still tile, and recedes before the edge goes
		if not thin and floorCF and k >= 0.1 then
			local mo1, mo2 = A.MistOut[1] + shift, A.MistOut[2] + shift
			if stop and stop < mo1 then mo1, mo2 = stop, stop + A.OutQuick end
			local ein = stop and math.min(e, stop) or e
			local grow = easeOutQuad((ein - A.MistIn[1]) / (A.MistIn[2] - A.MistIn[1]))
			local recede = math.clamp((e - mo1) / (mo2 - mo1), 0, 1)
			local r = math.floor(A.MistRadius * grow * (1 - recede * recede) * k * 50) / 50
			local on = r > 0.05
			if on ~= set.MistOn then
				set.MistOn = on
				set.MistTile.Transparency = on and 0 or 1
				if on then set.MistR = nil end
			end
			if on and (r ~= set.MistR or edgeChanged) then
				if r ~= set.MistR then
					set.MistR = r
					set.Mist.Size = Vector3.new(0.05, r * 2, r * 2)
					local off = (A.MistTile * 0.5 - r) % A.MistTile       -- the tile stays put as the disc grows
					set.MistTile.OffsetStudsU, set.MistTile.OffsetStudsV = off, off
				end
				place(set.Mist, floorCF * CFrame.new(0, A.MistLift, 0) * CFrame.Angles(0, 0, math.pi / 2))
			end
		elseif set.MistOn then
			set.MistOn = false
			set.MistTile.Transparency = 1
		end

		-- snow: on through the sustain, riding the caster (LockedToPart keeps the specks inside the zone)
		if snow then
			local snowOff = A.SnowOff + shift
			if stop then snowOff = math.min(stop, snowOff) end
			local on = e >= A.SnowOn and e < snowOff
			if on ~= snowOn then
				snowOn = on
				snow.Enabled = on
			end
			if floorMoved or feet ~= handle.SnowFeet then
				handle.SnowFeet = feet
				place(snowPart, CFrame.new(rp.X, feet + A.SnowHeight * 0.5 + A.SnowBase, rp.Z))
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)

	VFXLibrary.ActiveAuras[character] = handle
	return handle
end

--- Ends a character's aura: everything un-forms from where it is (the edge in EdgeQuick, the rest in OutQuick),
--- or with `immediate` it just goes.
function VFXLibrary.StopChillAura(character, immediate)
	local h = VFXLibrary.ActiveAuras[character]
	if not h then return end
	if immediate then
		h.Finish()
		return
	end
	h.StopAt = math.min(h.StopAt or math.huge, math.max(0, caClock() - h.T0))
end
end   -- (2026-10-19, audit GB-04) the Chill Aura do-block

----------------------------------------------------------------------------------------------------
-- ULTIMATE: CRYO BEAM v2
----------------------------------------------------------------------------------------------------
-- The Cryo Beam reference sheet (01 Channel, 02 Focus, 03 Unleash, 04 Sustain, 05 Impact), flattened to house style
-- and approved as a grey checkpoint (2026-09-15: revision 2, variant A, levitation kept). One handle per caster runs
-- the whole thing on the server clock (the T0 of the cast; the payloads carry it):
--   CHANNEL 0-1.05   the ground ring forms from 3 seeds under the lifted caster; ten Icicle crystals grow from the heel
--                    and orbit; a hero crystal stands over the hands; two rune rings form facet by facet; three wind
--                    arcs draw themselves chord by chord beside the hands; a small core point between them.
--   FOCUS 1.05-1.75  the orbit slows to a stop ("everything slows"), the rune rings fold away, the crystals fly into a
--                    sunburst pointing in at a 4-point star, the arcs become a vortex behind it, a needle flare grows.
--                    It holds its last state until the fire arrives.
--   UNLEASH 1.75     the beam tears out at Grow studs/s: ONE uniform cylinder (flat head, no tip) with the effects
--                    round it -- shard tiles and a swirl travelling forward, two ribbon strands rolling, a muzzle ring
--                    that sheds travelling rings, frost trails; the crystals shoot along it and shrink away.
--   IMPACT           on contact a spike crown (every point inside the server's r 4 hit sphere) and a halo facing the
--                    beam; in open air the halo alone marks the live 60-stud tip.
--   END              the crown folds, the beam pulls back into the hand, the hand pieces fold away.
-- GAMEPLAY is the server's and unchanged (AbilityHandler): it hits a r 4 sphere at the END of its own ray from the
-- server's RightHand every 0.15 s. Nothing drawn here decides a hit.
--
-- WHO SEES WHAT. Everyone sees it all, except: the caster in first person sees their own arcs small at the hands
-- (wiped at the start of FOCUS, no vortex), the sunburst ringing the screen edge, a slimmer beam (decoration slimmed
-- with it) from the hand low at the right into the crosshair, its specks only from 6 studs out, and their own muzzle
-- ring wiped soon after the fire. A beam coming at your own camera stops
-- VictimCut studs short of it and draws no crown or halo on you (NearCamera: a crown next to your camera is skipped
-- too). Thinned (low Graphics Quality, or someone else's beam with Reduce Enemy VFX) keeps the ground ring, crystals,
-- star, cylinder, muzzle ring, crown and halo -- no rune rings, arcs, tiles, ribbons, swirl, rings, trails or sprites.
--
-- THE KIT: blender_scripts/cryo_blocking/final_cryo_beam_v2.py -> IceMagicMeshes.CryoBeamV2 (facet / chord / spike
-- pieces, the crystals, merged meshes for every steady group, the core, and tile / ribbon / swirl blocks) and
-- IceMagic.CryoBeamData (pieces, windows, layout in Blender coordinates). A kit that does not match is refused.
-- VFXLibrary.CryoBeamClock, when set, replaces the server clock (a review hook for freezing a frame).

VFXLibrary.ActiveBeams = {}
VFXLibrary.ActiveWindups = VFXLibrary.ActiveBeams   -- one handle now covers the windup and the beam

--- Set by FirstPersonController for the local player: the world CFrame of a viewmodel fingertip ("L" / "R"); the
--- beam and the focus leave from the arms you can see, not the hidden body.
VFXLibrary.LocalBeamOrigin = nil
VFXLibrary.LocalMuzzle = nil
VFXLibrary.LocalCharacter = nil
--- Also set by FirstPersonController, and answering only while the third-person testing view is on
--- (V): the CFrame a shot should be aimed from, which stays at the eye even when the camera has
--- pulled back behind the body. nil means "first person, use the camera" and is the normal state.
VFXLibrary.LocalAimCFrame = nil

-- (2026-10-19, audit GB-04) RETIRED: no Abilities row casts Cryo Beam (Blizzard, Deep Freeze and Mirror Cage replaced
-- it), and its 37 locals are scoped to this do-block so they no longer count against the main chunk's 200 (otherwise
-- unchanged; the VFXLibrary.* fields it defines stay). Moving it out, as Glacial Spikes was, is the fuller fix.
do
local CB = { DataName = "CryoBeamData", MeshFolder = "CryoBeamV2", Pool = {}, PoolMax = 4 }
local CB_BLOCKS = { Tile = { 16, 16, 8, 4, 2, 1 }, Rib = { 8, 8, 4, 2, 1 }, Swirl = { 16, 8, 4, 2, 1 } }
local CB_RINGS, CB_TRAILS = 6, 14
local CB_BLOCK_NAMES, CB_RING_NAMES, CB_TRAIL_NAMES = {}, {}, {}
for kind, list in pairs(CB_BLOCKS) do
	CB_BLOCK_NAMES[kind] = {}
	for i, n in ipairs(list) do
		CB_BLOCK_NAMES[kind][i] = { Part = ("CB_%s%d_%d"):format(kind, n, i), Mesh = ("CB_%s%d"):format(kind, n), N = n }
	end
end
for i = 1, CB_RINGS do CB_RING_NAMES[i] = "CB_TravelRing_" .. i end
for i = 1, CB_TRAILS do CB_TRAIL_NAMES[i] = "CB_Trail_" .. i end
local CB_ARCS = { { "A", "ArcA" }, { "B", "ArcB" }, { "C", "ArcC" } }

-- Blender (x, y, z) -> Roblox (-x, z, y) is a proper rotation P (P = P^-1). A transform authored in Blender numbers,
-- L_B, acts on the converted mesh as P * L_B * P; frames built from world vectors use cbFrame (Blender +X along g,
-- Blender +Z along u) so the two compose: world = cbFrame(o, g, u) * cbR(L_B) * CFrame.new(fromBlender(centre)).
local CB_P = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))

local function cbR(cfB)
	return CB_P * cfB * CB_P
end

local function cbFrame(o, g, u)
	g = g.Unit
	local up = u - g * u:Dot(g)
	if up.Magnitude < 1e-4 then
		up = (math.abs(g.Y) < 0.99) and Vector3.yAxis or Vector3.xAxis
		up = up - g * up:Dot(g)
	end
	return CFrame.fromMatrix(o, -g, up.Unit)
end

local function cbClock()
	return VFXLibrary.CryoBeamClock and VFXLibrary.CryoBeamClock() or workspace:GetServerTimeNow()
end

local function cbSeg(t, a, b)
	if b <= a then return t >= b and 1 or 0 end
	return math.clamp((t - a) / (b - a), 0, 1)
end

local function cbSmooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function cbEaseIn(x)
	x = math.clamp(x, 0, 1)
	return x * x
end

--- Grown fraction of a window: eases out while forming, eases in while un-forming.
local function cbWin(e, inT, outT)
	local s = (e >= inT[1]) and easeOutQuad((e - inT[1]) / math.max(1e-6, inT[2] - inT[1])) or 0
	if outT and e >= outT[1] then
		s *= 1 - cbEaseIn((e - outT[1]) / math.max(1e-6, outT[2] - outT[1]))
	end
	return s
end

local function cbData()
	if CB.Data ~= nil then return CB.Data end
	CB.Data = false
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local module = ice and ice:FindFirstChild(CB.DataName)
	local folder = meshFolder()
	local src = folder and folder:FindFirstChild(CB.MeshFolder)
	if not (module and src) then
		warn(("[VFXLibrary] IceMagic.%s or %s.%s is missing - Cryo Beam draws nothing"):format(CB.DataName,
			C.MeshFolderName, CB.MeshFolder))
		return false
	end
	local ok, D = pcall(require, module)
	if not ok or type(D) ~= "table" or type(D.Pieces) ~= "table" or type(D.Look) ~= "table" then
		warn("[VFXLibrary] IceMagic." .. CB.DataName .. " did not load - Cryo Beam draws nothing")
		return false
	end
	local names = {}
	for _, p in ipairs(D.Pieces) do names[#names + 1] = p.mesh end
	for _, m in pairs(D.Merged) do names[#names + 1] = m end
	for _, s in ipairs({ "CB_Core", "CB_CoreHead", "CB_TravelRing", "CB_Trail", "CB_Tile16", "CB_Tile8", "CB_Tile4",
		"CB_Tile2", "CB_Tile1", "CB_Rib8", "CB_Rib4", "CB_Rib2", "CB_Rib1", "CB_Swirl16", "CB_Swirl8", "CB_Swirl4",
		"CB_Swirl2", "CB_Swirl1" }) do
		names[#names + 1] = s
	end
	local missing = {}
	for _, name in ipairs(names) do
		local t = src:FindFirstChild(name)
		if not (t and t:IsA("MeshPart") and D.Meshes[name]) then missing[#missing + 1] = tostring(name) end
	end
	if #missing > 0 then
		warn(("[VFXLibrary] %s.%s does not match CryoBeamData (missing: %s) - Cryo Beam draws nothing")
			:format(C.MeshFolderName, CB.MeshFolder, table.concat(missing, ", ", 1, math.min(#missing, 8))))
		return false
	end

	-- the prototype set: every piece once, the solids as many times as a set can need them
	local proto = new("Folder", { Name = "CryoBeam" })
	local function add(name, cloneName)
		local part = kitPiece(src:FindFirstChild(name))
		part.Name = cloneName or name
		part.Parent = proto
	end
	for _, p in ipairs(D.Pieces) do add(p.mesh) end
	for _, m in pairs(D.Merged) do add(m) end
	add("CB_Core")
	add("CB_CoreHead")
	add("CB_CoreHead", "CB_CoreBase")                            -- the tube is open: this caps the hand end
	for kind, list in pairs(CB_BLOCKS) do
		for i, n in ipairs(list) do add(("CB_%s%d"):format(kind, n), ("CB_%s%d_%d"):format(kind, n, i)) end
	end
	for i = 1, CB_RINGS do add("CB_TravelRing", "CB_TravelRing_" .. i) end
	for i = 1, CB_TRAILS do add("CB_Trail", "CB_Trail_" .. i) end
	CB.Proto = proto

	CB.ByGroup = {}
	for i, p in ipairs(D.Pieces) do
		local q = p.rot
		local axis = fromBlender(q[2], q[3], q[4])
		p.Index = i
		p.CF = CFrame.new(fromBlender(p.pos[1], p.pos[2], p.pos[3])) * CFrame.new(0, 0, 0, axis.X, axis.Y, axis.Z, q[1])
		p.Centre = D.Meshes[p.mesh].centre
		p.Base = src:FindFirstChild(p.mesh).Size
		CB.ByGroup[p.group] = CB.ByGroup[p.group] or {}
		table.insert(CB.ByGroup[p.group], p)
	end
	CB.Offset, CB.Base = {}, {}
	for name, info in pairs(D.Meshes) do
		local c = info.centre
		CB.Offset[name] = fromBlender(c[1], c[2], c[3])
		local t = src:FindFirstChild(name)
		CB.Base[name] = t and t.Size
	end
	CB.Crystals = {}
	for k = 1, 10 do CB.Crystals[k] = CB.ByGroup.Crystal[k] end
	for _, p in ipairs(CB.ByGroup.Crystal) do
		if p.mesh == "CBH" then CB.Hero = p end
	end
	-- the unleash order of the radial slots: the bottom first, going round
	local order = {}
	for s = 1, 10 do order[#order + 1] = { ((s * 360 / 11) - 180) % 360, s } end
	table.sort(order, function(a, b) return a[1] < b[1] end)
	CB.UnleashOrder = {}
	for i, o in ipairs(order) do CB.UnleashOrder[o[2]] = i - 1 end
	CB.Data = D
	return D
end

local function cbAcquireSet(D)
	local set = table.remove(CB.Pool)
	if not set then
		local folder = CB.Proto:Clone()
		set = { Folder = folder, Parts = {}, Shown = {}, Walked = {}, Hidden = {} }
		for _, child in ipairs(folder:GetChildren()) do set.Parts[child.Name] = child end
	end
	return set
end

local function cbShow(set, part, on)
	if set.Shown[part] ~= on then
		set.Shown[part] = on
		part.Transparency = on and 0 or 1
	end
end

local function cbReleaseSet(set)
	for part, on in pairs(set.Shown) do
		if on then part.Transparency = 1 end
	end
	table.clear(set.Shown)
	table.clear(set.Walked)
	table.clear(set.Hidden)
	if #CB.Pool < CB.PoolMax then
		set.Folder.Parent = nil
		table.insert(CB.Pool, set)
	else
		set.Folder:Destroy()
	end
end

--- A piece grown to `s` along its +X from `pivot`, placed through group frame `G` (a Roblox CFrame), optionally
--- scaled uniformly by `k` about the group origin. Returns false when too small to draw.
local function cbPlacePiece(set, p, G, s, pivot, k, parts, frames)
	local part = set.Parts[p.mesh]
	if s <= 0.02 then
		cbShow(set, part, false)
		return false
	end
	k = k or 1
	local c, base = p.Centre, p.Base
	local cx = (pivot == 1) and (p.len + (c[1] - p.len) * s) or (c[1] * s)
	local lcf = p.CF * CFrame.new(fromBlender(cx, c[2], c[3]))
	if k ~= 1 then lcf = CFrame.new(lcf.Position * k) * lcf.Rotation end
	local key = math.floor(s * 1000 + 0.5) * 1000 + k
	if set.Walked[part] ~= key then
		set.Walked[part] = key
		part.Size = Vector3.new(base.X * s * k, base.Y * k, base.Z * k)
	end
	cbShow(set, part, true)
	parts[#parts + 1] = part
	frames[#frames + 1] = G * lcf
	return true
end

--- A whole mesh (merged group, solid, block) at group frame `G`, scaled uniformly by `k` (sizes written on change).
local function cbPlaceWhole(set, part, name, G, k, parts, frames, stretch)
	k = k or 1
	local base = CB.Base[name]
	local sx = (stretch or 1) * k
	local key = sx * 1000 + k
	if set.Walked[part] ~= key then
		set.Walked[part] = key
		part.Size = Vector3.new(base.X * sx, base.Y * k, base.Z * k)
	end
	local off = CB.Offset[name]
	cbShow(set, part, true)
	parts[#parts + 1] = part
	frames[#frames + 1] = G * CFrame.new(off.X * sx, off.Y * k, off.Z * k)
end

-- ================================================================ windup
local function cbOrbitAngle(U, L, e)
	local O = L.Orbit
	if e < O.Start then return 0 end
	local a = O.Spin * (math.min(e, O.Slow[1]) - O.Start)
	if e > O.Slow[1] then
		local span = O.Slow[2] - O.Slow[1]
		local x = math.min(e, O.Slow[2]) - O.Slow[1]
		a += O.Spin * x - O.Spin * x * x / (2 * span)
	end
	return a
end

--- Blender caster-space vector (x forward, y left, z up) -> world.
local function cbVec(ctx, x, y, z)
	return ctx.Gc:VectorToWorldSpace(fromBlender(x, y, z))
end

local function cbOrbitFrame(ctx, L, k, len, e)
	local slot = L.Crystals[k]
	local a = math.rad(slot.Az) + cbOrbitAngle(nil, L, e)
	local pitch = math.rad(slot.Pitch)
	local out = cbVec(ctx, math.cos(a), -math.sin(a), 0)
	local tang = cbVec(ctx, -math.sin(a), -math.cos(a), 0)
	local d = (tang * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)).Unit
	local mid = ctx.Root + out * slot.R + Vector3.yAxis * slot.Height
	return cbFrame(mid - d * len * 0.5, d, out)
end

local function cbHeroFrame(ctx, L)
	local h = L.Hero.Heel                                      -- ROOT space: x right, y up, -z forward
	local heel = ctx.Gc * fromBlender(-h[3], -h[1], h[2])
	return cbFrame(heel, Vector3.yAxis, ctx.Look)
end

local function cbRadialFrame(ctx, L, slot, len)
	local R = L.Radial
	local centre, n
	if ctx.FP then
		local cam = ctx.Cam
		centre = cam.Position + (ctx.F - cam.Position).Unit * R.FpDistance
		n = cam.LookVector
	else
		n = ctx.N
		centre = ctx.F - n * R.Back
	end
	local up = Vector3.yAxis - n * n.Y
	up = up.Magnitude > 1e-3 and up.Unit or ctx.Look
	local right = n:Cross(up)
	local th = math.rad(slot * 360 / R.Slots)
	local q = up * math.cos(th) + right * math.sin(th)
	return cbFrame(centre + q * (R.Tip + len), -q, n)
end

local function cbBlend(a, b, u, bulge, dir)
	local cf = a:Lerp(b, u)
	if bulge and dir then cf = cf + dir * (bulge * math.sin(math.pi * u)) end
	return cf
end

local function cbPoseCrystal(set, D, L, U, ctx, p, idx, hero, parts, frames)
	local e, stop, FIRE = ctx.E, ctx.Stop, ctx.Fire
	local ef = stop and math.min(e, stop) or e
	local len = p.len
	local fly, slot, start
	if hero then
		fly, slot, start = L.Hero.Fly, 0, cbHeroFrame(ctx, L)
	else
		fly, slot, start = L.Crystals[idx].Fly, idx, cbOrbitFrame(ctx, L, idx, len, ef)
	end
	local s = cbWin(ef, p.inT)
	local lift = (not hero) and (-L.Orbit.Rise * (1 - s)) or 0
	if stop and ctx.PreFire then                                     -- died in the windup: shrink to the tip, dropping
		local k = cbEaseIn(cbSeg(e, stop, stop + U.StopQuick))
		s *= 1 - k
		lift = -0.8 * k
	end
	local G, pivot
	if e < fly[1] or (stop and stop < fly[1]) then
		G, pivot = start, 0
		if lift ~= 0 then G = G + Vector3.new(0, lift, 0) end
	elseif not ctx.Fired then
		local u = cbSmooth(cbSeg(math.min(ef, fly[2]), fly[1], fly[2]))
		local target = cbRadialFrame(ctx, L, slot, len)
		local bd = start.Position - ctx.Root
		G, pivot = cbBlend(start, target, u, 0.4, bd.Magnitude > 1e-3 and bd.Unit or nil), 0
	else
		if stop and ctx.PreFire then
			cbShow(set, set.Parts[p.mesh], false)
			return
		end
		local target = cbRadialFrame(ctx, L, slot, len)
		local ea = ctx.EBeam                                             -- the beam's own clock (fire = FIRE)
		if ctx.FP then
			local u = cbSmooth(cbSeg(ea, FIRE, FIRE + 0.12))
			G = cbBlend(target, cbFrame(ctx.M, ctx.B, Vector3.yAxis), u)
			cbPlacePiece(set, p, G, 1 - cbSeg(ea, FIRE, FIRE + 0.12), 1, 1, parts, frames)
			return
		end
		local uo = hero and 10 or CB.UnleashOrder[slot]
		local t0 = FIRE + 0.012 * uo
		local dU = 1.6 + 0.9 * uo
		local Wb = cbFrame(ctx.M, ctx.B, Vector3.yAxis)
		local az = math.rad(36 * uo)
		local off = (Wb.ZVector * math.cos(az) + Wb.YVector * math.sin(az)) * L.Beam.CrystalRide
		if ea < t0 then
			G, pivot = target, 1
		elseif ea < t0 + 0.08 then
			G, pivot = cbBlend(target, cbFrame(ctx.M + off + ctx.B * dU, ctx.B, Vector3.yAxis),
				cbSmooth(cbSeg(ea, t0, t0 + 0.08))), 1
		else
			local d = dU + U.TrailSpeed * (ea - t0 - 0.08)
			s = 1 - cbSeg(ea, t0 + 0.08, t0 + 0.20)
			if d + len > ctx.D - L.Beam.HeadGap then s = 0 end
			G, pivot = cbFrame(ctx.M + off + ctx.B * d, ctx.B, Vector3.yAxis), 1
		end
	end
	cbPlacePiece(set, p, G, s, pivot, 1, parts, frames)
end

--- A facet / chord group: its merged mesh while steady, its pieces while forming or un-forming.
local function cbGroup(set, D, name, G, e, inEnd, outStart, pieceFn, k, parts, frames)
	local merged = D.Merged[name] and set.Parts[D.Merged[name]]
	local steady = e >= inEnd and e < outStart
	if merged then
		if steady then
			cbPlaceWhole(set, merged, D.Merged[name], G, k, parts, frames)
		else
			cbShow(set, merged, false)
		end
	end
	set.Hidden[name] = nil
	local want = not (merged and steady)
	if want or set.Walked[name] then
		set.Walked[name] = want
		for _, p in ipairs(CB.ByGroup[name]) do
			if want then
				local s, pivot = pieceFn(p)
				cbPlacePiece(set, p, G, s, pivot, k, parts, frames)
			else
				cbShow(set, set.Parts[p.mesh], false)
			end
		end
	end
end

local function cbHideGroup(set, D, name)
	if set.Hidden[name] then return end
	set.Hidden[name] = true
	if D.Merged[name] then cbShow(set, set.Parts[D.Merged[name]], false) end
	for _, p in ipairs(CB.ByGroup[name] or {}) do cbShow(set, set.Parts[p.mesh], false) end
	set.Walked[name] = nil
end

local function cbPoseWindup(set, D, U, ctx, parts, frames)
	local L = D.Look
	local e, stop, FIRE, thin = ctx.E, ctx.Stop, ctx.Fire, ctx.Thin
	local ew = ctx.Fired and e or math.min(e, FIRE - 1e-3)                 -- FOCUS holds until the fire arrives
	local ef = stop and math.min(ew, stop) or ew
	local killed = stop and (ctx.PreFire or stop < 2.10)
	local kill = killed and (1 - cbEaseIn(cbSeg(e, stop, stop + U.StopQuick))) or 1

	-- ground ring on the floor under the caster
	local gGround = D.Groups.CBG
	if ctx.Floor and not (killed and e >= stop + U.StopQuick) and not (not killed and e >= gGround.OutStart + 0.25) then
		local G = ctx.Floor * cbR(CFrame.Angles(0, 0, -U.GroundSpin * ef))
		local g = D.Groups.CBG
		cbGroup(set, D, "CBG", G, e, g.InEnd, killed and stop or g.OutStart, function(p)
			if killed then return cbWin(ef, p.inT) * kill, 0 end
			return cbWin(e, p.inT, p.outT), 0
		end, 1, parts, frames)
	else
		cbHideGroup(set, D, "CBG")
	end

	-- crystals + hero
	for k = 1, 10 do cbPoseCrystal(set, D, L, U, ctx, CB.Crystals[k], k, false, parts, frames) end
	cbPoseCrystal(set, D, L, U, ctx, CB.Hero, 0, true, parts, frames)

	-- rune rings
	for _, spec in ipairs({ { "CBW", L.RuneW, U.RuneWSpin }, { "CBR", L.RuneC, U.RuneCSpin } }) do
		local name, R, spin = spec[1], spec[2], spec[3]
		if thin or e >= D.Groups[name].OutStart + 0.3 then
			cbHideGroup(set, D, name)
		else
			local G = ctx.Gc * cbR(CFrame.new(0, 0, R.Height) * CFrame.Angles(0, math.rad(R.Tilt), 0)
				* CFrame.Angles(0, 0, spin * ef))
			local g = D.Groups[name]
			local outStart = (stop and stop < g.OutStart) and stop or g.OutStart
			cbGroup(set, D, name, G, e, g.InEnd, outStart, function(p)
				if stop and stop < p.outT[1] then return cbWin(ef, p.inT) * kill, 0 end
				return cbWin(e, p.inT, p.outT), 0
			end, 1, parts, frames)
		end
	end

	-- wind arcs: beside the hands, then the vortex (3P); small at the hands and wiped early (1P)
	for _, arc in ipairs(CB_ARCS) do
		local name, group = arc[1], arc[2]
		local A = L.Arcs[name]
		local g = D.Groups[group]
		local wipe = ctx.FP and U.OwnArcWipe or { g.OutStart, g.OutStart + 0.12 }
		if thin or e >= wipe[2] or (stop and e >= stop + U.StopQuick) then
			cbHideGroup(set, D, group)
		else
			local fpLook = ctx.FP and flat(ctx.Cam.LookVector) or nil
			local base = cbFrame(ctx.F, (fpLook and fpLook.Magnitude > 1e-3) and fpLook or ctx.Look, Vector3.yAxis)
			local function chan(t)
				return base * cbR(CFrame.Angles(A.Precess * math.max(0, t - A.Start), 0, 0)
					* CFrame.Angles(0, math.rad(A.Tilt), 0) * CFrame.Angles(0, math.pi / 2, 0))
			end
			local G = chan(ef)
			local k = ctx.FP and L.Focus.FpScale or 1
			if not ctx.FP and ef >= 1.05 then
				local x = math.min(ef, 1.35) - 1.05
				local spin = U.VortexSpin * x * x / (2 * 0.30) + U.VortexSpin * math.max(0, ef - 1.35)
				local focus = cbFrame(ctx.F - ctx.N * A.Back, ctx.N, Vector3.yAxis)
					* cbR(CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, spin))
				G = cbBlend(chan(1.05), focus, cbSmooth(cbSeg(ef, 1.05, 1.35)))
			end
			local outStart = wipe[1]
			if stop and stop < outStart then outStart = stop end
			cbGroup(set, D, group, G, e, g.InEnd, outStart, function(p)
				local i = tonumber(string.sub(p.mesh, -1))
				local s = cbWin(ef, p.inT)
				if stop and stop < wipe[1] then return s * kill, 0 end
				local step = (wipe[2] - wipe[1]) / 5
				local o1 = wipe[1] + step * (i - 1)
				if e >= o1 then return s * (1 - cbEaseIn((e - o1) / step)), 1 end
				return s, 0
			end, k, parts, frames)
		end
	end

	-- star (core point, cross, needle): at the focus, then at the hand once the beam fires
	local k = ctx.FP and L.Focus.FpScale or 1
	local nF = ctx.FP and ctx.Cam.LookVector or ctx.N
	local Gs = cbFrame(ctx.F, nF, Vector3.yAxis)
	local spinStar = U.StarSpin * math.max(0, ef - 1.25)
	if ctx.Fired and not ctx.PreFire then
		local ea = ctx.EBeam
		local Gm = cbFrame(ctx.M + ctx.B * L.Beam.StarAt, ctx.B, Vector3.yAxis)
		Gs = ctx.FP and Gm or cbBlend(Gs, Gm, cbSmooth(cbSeg(ea, FIRE, FIRE + 0.06)))
		spinStar = U.StarSpin * (FIRE - 1.25) + U.MuzzleStarSpin * math.max(0, ea - FIRE)
	end
	Gs = Gs * cbR(CFrame.Angles(spinStar, 0, 0))
	for _, group in ipairs({ "Star", "Needle" }) do
		for _, p in ipairs(CB.ByGroup[group]) do
			local s = cbWin(ef, p.inT)
			if group == "Needle" and ctx.Fired then s *= 1 - cbSeg(ctx.EBeam, FIRE, FIRE + 0.06) end
			s *= kill
			if ctx.HandOut then s *= 1 - cbSeg(ctx.EBeam, ctx.HandOut, ctx.HandOut + 0.08) end
			local kk = (group == "Needle" and ctx.FP) and L.Focus.FpNeedleScale or k
			cbPlacePiece(set, p, Gs, s, 0, kk, parts, frames)
		end
	end
	if D.Merged.Star then cbShow(set, set.Parts[D.Merged.Star], false) end
end

-- ================================================================ beam
--- Hard-edged Shard sprites for the beam: untinted (the bands and ink are in the art), no glow.
function E.CryoBeamShards()
	return {
		Texture = C.Textures.Shard, Color = CS(COL.Rim), LightEmission = 0, LightInfluence = 0,
		Size = NS({ 0, 0.30 }, { 1, 0 }), Transparency = NS(0), Lifetime = NR(0.25, 0.35),
		Rotation = NR(0, 360), RotSpeed = NR(-240, 240), Speed = NR(18, 26), Rate = 0, Drag = 0,
	}
end

local function cbPoseBlocks(set, kind, name, list, count, placeFn, parts, frames, k)
	local placed = 0
	for _, nm in ipairs(CB_BLOCK_NAMES[kind]) do
		local part, n = set.Parts[nm.Part], nm.N
		if count - placed >= n then
			-- k slims a block round the beam's axis only: its length (and so the spacing) stays
			cbPlaceWhole(set, part, nm.Mesh, placeFn(placed), k or 1, parts, frames, k and 1 / k)
			placed += n
		else
			cbShow(set, part, false)
		end
	end
end

local function cbPoseBeam(set, D, U, ctx, parts, frames)
	local L = D.Look
	local Bm = L.Beam
	local FIRE, ea, stop = ctx.Fire, ctx.EBeam, ctx.Stop
	local fired = ctx.Fired and not ctx.PreFire
	local on = fired and ctx.D > 0.02
	local decorate = on and not ctx.Thin
	local W = cbFrame(ctx.M, ctx.B, Vector3.yAxis)
	local Dd, gap = ctx.D, Bm.HeadGap
	local t = math.max(0, ea - FIRE)

	-- the uniform cylinder and its flat head
	local d0, rk = 0, 1
	if ctx.FP then d0, rk = 0.30, Bm.FpRadius end
	local core, head, capBase = set.Parts.CB_Core, set.Parts.CB_CoreHead, set.Parts.CB_CoreBase
	if on and Dd - d0 > 0.05 then
		local len = math.floor((Dd - d0) * 20 + 0.5) / 20
		cbPlaceWhole(set, core, "CB_Core", W * cbR(CFrame.new(d0, 0, 0)), rk, parts, frames, len / rk)
		cbPlaceWhole(set, head, "CB_CoreHead", W * cbR(CFrame.new(Dd, 0, 0)), rk, parts, frames)
		cbPlaceWhole(set, capBase, "CB_CoreHead", W * cbR(CFrame.new(d0, 0, 0) * CFrame.Angles(0, 0, math.pi)), rk,
			parts, frames)
	else
		cbShow(set, core, false)
		cbShow(set, head, false)
		cbShow(set, capBase, false)
	end

	-- shard tiles and the swirl travel forward together; the ribbon strands roll in place. Your own (1P): the
	-- hand is low at the right, so the beam runs diagonally into the crosshair and its first few studs are most of
	-- what you see of it -- the decoration starts near the hand, slimmed round the axis with the cylinder.
	local kd = ctx.FP and rk or nil
	local dec0 = ctx.FP and Bm.FpDecorStart or Bm.DecorStart
	local travelled = U.TileSpeed * t
	local TL, SL, RL = L.Tile, L.Swirl, L.Rib
	local phase = travelled % TL.Period
	local nTiles = decorate and math.max(0, math.floor((Dd - gap - (dec0 + phase) - TL.Length) / TL.Period) + 1) or 0
	cbPoseBlocks(set, "Tile", "Tile", CB_BLOCKS.Tile, nTiles, function(placed)
		return W * cbR(CFrame.new(dec0 + phase + TL.Period * placed, 0, 0))
	end, parts, frames, kd)
	local sPhase = travelled % SL.Period
	local baseId = math.floor(travelled / SL.Period)
	local nSwirl = decorate and math.max(0, math.floor((Dd - gap - (dec0 + sPhase) - SL.Length) / SL.Period) + 1) or 0
	cbPoseBlocks(set, "Swirl", "Swirl", CB_BLOCKS.Swirl, nSwirl, function(placed)
		local ang = math.rad(SL.StepDeg * (placed + 1 - baseId)) + U.SwirlSpin * t
		return W * cbR(CFrame.new(dec0 + sPhase + SL.Period * placed, 0, 0) * CFrame.Angles(ang, 0, 0))
	end, parts, frames, kd)
	local ribStart = ctx.FP and Bm.FpRibStart or Bm.RibStart
	local nRib = decorate and math.max(0, math.floor((Dd - gap - ribStart - RL.Length) / RL.Step) + 1) or 0
	cbPoseBlocks(set, "Rib", "Rib", CB_BLOCKS.Rib, nRib, function(placed)
		return W * cbR(CFrame.new(ribStart + RL.Step * placed, 0, 0) * CFrame.Angles(U.RibRoll * t, 0, 0))
	end, parts, frames, kd)

	-- muzzle ring: forms from 3 seeds at the fire; your own is wiped soon after; folds away once the beam is home
	if fired then
		local ringAt = ctx.FP and Bm.FpMuzzleAt or Bm.MuzzleAt
		local k = ctx.FP and Bm.FpMuzzleScale or 1
		local G = W * cbR(CFrame.new(ringAt, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, U.MuzzleSpin * t))
		local wipe = ctx.FP and U.OwnMuzzleWipe or nil
		local outStart = math.huge
		if wipe then outStart = wipe[1] end
		if ctx.HandOut then outStart = math.min(outStart, ctx.HandOut) end
		local g = D.Groups.CBM
		if (wipe and ea >= wipe[2]) or (ctx.HandOut and ea >= ctx.HandOut + 0.10) then
			cbHideGroup(set, D, "CBM")
		else
			cbGroup(set, D, "CBM", G, ea, FIRE + g.InEnd, outStart, function(p)
				local s = cbWin(ea, { FIRE + p.inT[1], FIRE + p.inT[2] })
				local j = (tonumber(string.sub(p.mesh, -2)) - 1) % 4
				local function fold(w0, step)
					local o1 = w0 + step * (3 - j)
					return 1 - cbEaseIn((ea - o1) / step)
				end
				if wipe and ea >= wipe[1] then s *= math.clamp(fold(wipe[1], (wipe[2] - wipe[1]) / 4), 0, 1) end
				if ctx.HandOut and ea >= ctx.HandOut then s *= math.clamp(fold(ctx.HandOut, 0.02), 0, 1) end
				return s, 0
			end, k, parts, frames)
		end
	else
		cbHideGroup(set, D, "CBM")
	end

	-- travelling rings peel off the muzzle ring; frost trails fly out; both end at the head
	for i = 1, CB_RINGS do
		local part = set.Parts[CB_RING_NAMES[i]]
		local t0 = FIRE + 0.02 + U.RingEvery * (i - 1)
		local d = Bm.MuzzleAt + U.RingSpeed * (ea - t0)
		local k, vis = 1, decorate and ea >= t0 and not (ctx.TEnd and t0 > ctx.TEnd)
		if vis and d >= Dd - gap then
			local tHit = t0 + math.max(0, (Dd - gap - Bm.MuzzleAt) / U.RingSpeed)
			k = 1 - 0.70 * cbSeg(ea, tHit, tHit + 0.06)
			vis = ea <= tHit + 0.06 and Dd - gap >= Bm.MuzzleAt
			d = Dd - gap
		end
		if vis and ctx.FP and d < Bm.FpDecorStart then vis = false end
		if vis then
			cbPlaceWhole(set, part, "CB_TravelRing", W * cbR(CFrame.new(d, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
				* CFrame.Angles(0, 0, U.RingSpin * (ea - t0))), k * (kd or 1), parts, frames)
		else
			cbShow(set, part, false)
		end
	end
	for i = 1, CB_TRAILS do
		local part = set.Parts[CB_TRAIL_NAMES[i]]
		local t0 = FIRE + U.TrailEvery * (i - 1)
		local vis = decorate and ea >= t0 and not (ctx.TEnd and t0 > ctx.TEnd)
		if vis then
			local az = math.rad(137.5 * (i - 1))
			local off = (W.ZVector * math.cos(az) + W.YVector * math.sin(az)) * Bm.TrailRadius * (kd or 1)
			local base = ctx.FP and Bm.FpDecorStart or 1.0
			local grow = cbSeg(ea, t0, t0 + 0.05)
			local rear = base + U.TrailSpeed * math.max(0, ea - t0 - 0.05)
			local length = Bm.TrailLength * grow
			if rear + length >= Dd - gap then
				local tHit = t0 + 0.05 + math.max(0, (Dd - gap - Bm.TrailLength - base) / U.TrailSpeed)
				local sh = 1 - cbSeg(ea, tHit, tHit + 0.05)
				vis = sh > 0.02 and Dd - gap >= base
				length = Bm.TrailLength * sh
				rear = Dd - gap - length
				-- your own: a near hit would push the trail back past the hand, along your arm
				if ctx.FP and rear < base then rear, length = base, Dd - gap - base end
			end
			if vis and length > 0.05 then
				cbPlaceWhole(set, part, "CB_Trail", (W + off) * cbR(CFrame.new(rear, 0, 0)), kd or 1, parts, frames,
					math.floor(length / Bm.TrailLength * 20 + 0.5) / 20 / (kd or 1))
			else
				cbShow(set, part, false)
			end
		else
			cbShow(set, part, false)
		end
	end

	-- impact: crown on a body or a surface, halo facing the beam (in open air, the halo alone at the 60-stud tip)
	local c0 = ctx.ContactAt
	local crownOn = c0 and ctx.Contact ~= "air" and not ctx.Near
	local haloOn = c0 and not ctx.Near
	local tOut = ctx.TEnd
	local Cr, Ha = L.Crown, L.Halo
	if crownOn then
		local centre, axis
		if ctx.Contact == "body" then
			centre, axis = ctx.EHit + ctx.B * Cr.BodyAhead, ctx.B
		else
			centre, axis = ctx.EHit - ctx.Normal * Cr.SurfaceBack, ctx.Normal
		end
		local G = cbFrame(centre, axis, Vector3.yAxis) * cbR(CFrame.Angles(U.CrownSpin * (ea - c0), 0, 0))
		local g = D.Groups.Crown
		cbGroup(set, D, "Crown", G, ea - c0, g.InEnd, tOut and (tOut - c0) or math.huge, function(p)
			local s = cbWin(ea - c0, p.inT)
			if tOut then s *= 1 - cbEaseIn(cbSeg(ea, tOut, tOut + 0.10)) end
			return s, 0
		end, 1, parts, frames)
		if tOut and ea > tOut + 0.12 then cbHideGroup(set, D, "Crown") end
	else
		cbHideGroup(set, D, "Crown")
	end
	if haloOn then
		local centre, axis
		if ctx.Contact == "body" then
			centre, axis = ctx.EHit - ctx.B * Ha.BodyBack, ctx.B
		elseif ctx.Contact == "surface" then
			centre, axis = ctx.EHit + ctx.Normal * Ha.SurfaceOut, ctx.Normal
		else
			centre, axis = ctx.M + ctx.B * ctx.D, ctx.B
		end
		local G = cbFrame(centre, axis, Vector3.yAxis) * cbR(CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.Angles(0, 0, U.HaloSpin * (ea - c0)))
		local g = D.Groups.CBO
		cbGroup(set, D, "CBO", G, ea - c0, g.InEnd, tOut and (tOut - c0) or math.huge, function(p)
			local j = (tonumber(string.sub(p.mesh, -2)) - 1) % 4
			local s = cbWin(ea - c0, p.inT)
			if tOut then
				local o1 = tOut + 0.025 * (3 - j)
				s *= 1 - cbEaseIn(cbSeg(ea, o1, o1 + 0.025))
			end
			return s, 0
		end, 1, parts, frames)
		if tOut and ea > tOut + 0.12 then cbHideGroup(set, D, "CBO") end
	else
		cbHideGroup(set, D, "CBO")
	end
end

-- ================================================================ the handle
local function cbFinish(h)
	if not h.Alive then return end
	h.Alive = false
	if h.Connection then h.Connection:Disconnect() end
	if h.RenderName then RunService:UnbindFromRenderStep(h.RenderName) end
	if VFXLibrary.ActiveBeams[h.Character] == h then VFXLibrary.ActiveBeams[h.Character] = nil end
	for _, part in ipairs(h.Ghosts) do
		for _, pe in ipairs(part:GetDescendants()) do
			if pe:IsA("ParticleEmitter") then pe.Enabled = false end
		end
		Debris:AddItem(part, 0.6)
	end
	cbReleaseSet(h.Set)
end

local function cbClampCone(v, axis, deg)
	if v.Magnitude < 1e-4 then return axis end
	v = v.Unit
	local dot = math.clamp(v:Dot(axis), -1, 1)
	local maxA = math.rad(deg)
	if math.acos(dot) <= maxA then return v end
	local w = v - axis * dot
	w = w.Magnitude > 1e-4 and w.Unit or Vector3.yAxis
	return (axis * math.cos(maxA) + w * math.sin(maxA)).Unit
end

local function cbStart(character, t0)
	local old = VFXLibrary.ActiveBeams[character]
	if old then cbFinish(old) end                                   -- a recast (or a missed stop) replaces it outright
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then return nil end
	local D = cbData()
	if not D then return nil end
	local U = T.CryoBeam
	local localPlayer = game:GetService("Players").LocalPlayer
	local isLocal = character == VFXLibrary.LocalCharacter or (localPlayer ~= nil and character == localPlayer.Character)
	local thin = (Settings.EffectDensity or 1) < 0.75 or (Settings.ThinEnemyVFX and not isLocal)
	local set = cbAcquireSet(D)
	set.Folder.Parent = fxFolder()

	local h = {
		Alive = true, Character = character, Root = root, Humanoid = humanoid, Set = set, T0 = t0, IsLocal = isLocal,
		Thin = thin, Fired = false, StopAt = nil, Target = nil, Aim = nil, DPrev = 0, LastE = nil, Ghosts = {},
		Ctx = {}, NextProbe = 0,
	}
	local look = flat(root.CFrame.LookVector)
	h.Look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	-- drawn through anyone the caster could not hurt, where the server's beam goes too (AbilityHandler)
	local beamExclude = { character, fxFolder() }
	local caster = game:GetService("Players"):GetPlayerFromCharacter(character)
	if caster then
		require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig")).AddUnhurtable(beamExclude, caster)
	end
	h.RayParams = makeRayParams(beamExclude)
	h.RayParams.IgnoreWater = false                                    -- the server's ray stops on water too
	if not thin then
		h.Gather = ghostPart({ Size = Vector3.new(2.4, 2.4, 2.4) }, fxFolder())
		h.GatherFx = emitter(h.Gather, E.CryoBeamShards(), { Rate = 18, Enabled = false, Speed = NR(4.4, 5.2),
			Lifetime = NR(0.22, 0.26), Size = NS({ 0, 0.22 }, { 1, 0 }), Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward })
		h.Down = ghostPart({ Size = Vector3.new(1.6, 0.2, 1.6) }, fxFolder())
		h.DownFx = emitter(h.Down, E.CryoBeamShards(), { Rate = 14, Enabled = false, Speed = NR(4, 6),
			Lifetime = NR(0.30, 0.40), Size = NS({ 0, 0.24 }, { 1, 0 }), EmissionDirection = Enum.NormalId.Bottom })
		h.Body = ghostPart({ Size = Vector3.new(0.8, 0.8, 5) }, fxFolder())
		h.BodyFx = emitter(h.Body, E.CryoBeamShards(), { Rate = 24, Enabled = false, Speed = NR(12, 16),
			Lifetime = NR(0.22, 0.28),
			EmissionDirection = Enum.NormalId.Front, Shape = Enum.ParticleEmitterShape.Box })
		h.BaseRate = h.BodyFx.Rate
		h.Impact = ghostPart({}, fxFolder())
		h.ImpactFx = emitter(h.Impact, E.CryoBeamShards(), { Rate = 10, Enabled = false, Speed = NR(6, 10), Drag = 3,
			Acceleration = Vector3.new(0, -40, 0), Lifetime = NR(0.35, 0.45), Size = NS({ 0, 0.36 }, { 1, 0.14 }),
			SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Front })
		h.Ghosts = { h.Gather, h.Down, h.Body, h.Impact }
	end
	VFXLibrary.ActiveBeams[character] = h

	local parts, frames = {}, {}
	local function step(dt)
		local e = cbClock() - h.T0
		local FIRE = U.LevitateTime + U.ChargeTime
		local END = FIRE + U.FireTime
		if not h.StopAt and e > END + U.Watchdog then h.StopAt, h.PreFire = e, not h.Fired end
		if h.StopAt and not h.FinishAt then
			local s = h.StopAt
			if h.Fired and not h.PreFire then
				h.DStop = h.DPrev
				h.FinishAt = math.max(s, e) + h.DStop / U.Grow + 0.35
			else
				h.FinishAt = s + U.StopQuick + 0.10
			end
		end
		if (h.FinishAt and e >= h.FinishAt) or not root:IsDescendantOf(workspace) or not humanoid.Parent then
			cbFinish(h)
			return
		end
		if e < 0 then return end
		local ctx = h.Ctx
		ctx.E, ctx.Fire, ctx.Stop, ctx.Thin, ctx.Fired, ctx.EBeam = e, FIRE, h.StopAt, h.Thin, h.Fired, e
		ctx.PreFire = h.StopAt ~= nil and h.PreFire == true
		local rp = root.Position
		local rlook = flat(root.CFrame.LookVector)
		ctx.Look = rlook.Magnitude > 1e-3 and rlook.Unit or h.Look
		ctx.Root = rp
		ctx.Gc = cbFrame(rp, ctx.Look, Vector3.yAxis)
		ctx.Cam = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new()
		ctx.FP = h.IsLocal and VFXLibrary.LocalMuzzle ~= nil
		local L = D.Look
		if ctx.FP then
			local l, r = VFXLibrary.LocalMuzzle("L"), VFXLibrary.LocalMuzzle("R")
			ctx.F = (l.Position + r.Position) * 0.5 + ctx.Cam.LookVector * 0.12
		else
			local u = cbSmooth(cbSeg(math.min(e, FIRE), L.Focus.Blend[1], L.Focus.Blend[2]))
			local a, b = L.Focus.Channel, L.Focus.Focus
			local rx, ry, rz = a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u
			ctx.F = ctx.Gc * fromBlender(-rz, -rx, ry)
		end
		-- aim: the latest server-accepted aim point, eased
		local target = h.Target or (ctx.F + ctx.Look * 30)
		h.Aim = h.Aim and h.Aim:Lerp(target, math.clamp(T.Beam.Smoothing * dt * 60, 0, 1)) or target
		ctx.N = cbClampCone(h.Aim - ctx.F, ctx.Look, 35)
		local base
		if ctx.FP then
			base = VFXLibrary.LocalMuzzle("R").Position
		else
			local hand = h.Character:FindFirstChild("RightHand") or h.Character:FindFirstChild("Right Arm")
			base = hand and hand.Position or (ctx.Gc * fromBlender(1.72, -0.70, 0.77))
		end
		local bdir = h.Aim - base
		-- your own: an aim nearer than the hand (a wall at your face) would point the beam back past the lens; it goes
		-- straight ahead into the wall instead
		if ctx.FP and bdir:Dot(ctx.Cam.LookVector) < 0.25 then bdir = ctx.Cam.LookVector end
		ctx.B = bdir.Magnitude > 0.5 and bdir.Unit or ctx.Look
		ctx.M = base + ctx.B * (ctx.FP and 0.08 or 0.35)

		-- the floor under the lifted caster (10 Hz)
		local wall = os.clock()
		if wall >= h.NextProbe then
			h.NextProbe = wall + U.FloorEvery
			-- from just above the body, not 6 over the lifted root (a low ceiling would catch that)
			local gp, gn, inst = groundBelow(rp - Vector3.new(0, 5.5, 0), { h.Character, fxFolder() }, U.FloorProbe + 6)
			if inst and gn.Y < math.cos(math.rad(20)) then gn = Vector3.yAxis end
			local lp = ctx.Look - gn * ctx.Look:Dot(gn)
			h.FloorCF = inst and cbFrame(gp + gn * 0.02, lp.Magnitude > 1e-3 and lp or ctx.Look, gn) or nil
		end
		ctx.Floor = h.FloorCF

		-- the beam: tears out at Grow, shrinks at once to a nearer hit, pulls back at the end
		ctx.D, ctx.HandOut, ctx.TEnd, ctx.ContactAt, ctx.Near = 0, nil, nil, nil, false
		if h.Fired and not ctx.PreFire and e >= FIRE then
			local hit = workspace:Raycast(ctx.M, ctx.B * T.Beam.MaxRange, h.RayParams)
			local dRay = hit and hit.Distance or T.Beam.MaxRange
			local kind = "air"
			if hit then
				local model = hit.Instance:FindFirstAncestorOfClass("Model")
				kind = (model and model:FindFirstChildOfClass("Humanoid")) and "body" or "surface"
			end
			ctx.Contact, ctx.Normal = kind, hit and hit.Normal or -ctx.B
			if h.StopAt and e >= h.StopAt then
				ctx.TEnd = h.StopAt
				ctx.D = math.max(0, (h.DStop or h.DPrev) - U.Grow * (e - h.StopAt))
				ctx.HandOut = h.StopAt + math.max(0, (h.DStop or h.DPrev) - 1.4) / U.Grow
			else
				local grown = h.LastE and (h.DPrev + U.Grow * math.max(0, e - h.LastE)) or U.Grow * (e - FIRE)
				ctx.D = math.min(dRay, grown)
			end
			h.DPrev, h.LastE = ctx.D, e
			ctx.EHit = ctx.M + ctx.B * dRay
			-- contact: when the head arrives; again after a jump of more than 4 studs or a lost contact
			-- (a moving body jitters the hit by a few tenths, and a hit lost for a frame or two keeps its crown)
			-- A new contact (crown and halo form again) when the hit jumps more than 8 studs in a frame -- a sweep, even
			-- at 30 fps, moves it less -- or its kind (body / surface / air) has held different for 0.1 s. A hit lost for
			-- up to 0.1 s close to where it was keeps its crown, drawn where it was, not at the new far hit.
			local arrived = ctx.D >= dRay - 0.5
			if not ctx.TEnd then
				if arrived then
					if h.ContactAt and kind ~= h.ContactKind then
						h.KindSince = h.KindSince or e
					else
						h.KindSince = nil
					end
					local jumped = h.LastHit and (h.LastHit - ctx.EHit).Magnitude > 8
					if not h.ContactAt or jumped or (h.KindSince and e - h.KindSince > 0.10) then
						h.ContactAt, h.ContactKind, h.KindSince = e, kind, nil
					end
					h.LostSince = nil
					h.LastHit, h.LastKind, h.LastNormal = ctx.EHit, kind, ctx.Normal
				else
					h.LostSince = h.LostSince or e
					local near = h.LastHit and (ctx.EHit - h.LastHit).Magnitude <= 8
					if h.ContactAt and near and e - h.LostSince <= 0.10 then
						ctx.EHit, ctx.Contact, ctx.Normal = h.LastHit, h.LastKind, h.LastNormal or ctx.Normal
					else
						h.ContactAt = nil
					end
				end
			end
			ctx.ContactAt = h.ContactAt
			-- your own camera: a beam coming at it stops short, and nothing bursts in your face
			if not h.IsLocal then
				local cam = ctx.Cam.Position
				local tc = (cam - ctx.M):Dot(ctx.B)
				local lateral = ((cam - ctx.M) - ctx.B * tc).Magnitude
				if lateral < 2.5 and tc > 0 and tc < ctx.D + U.VictimCut then
					ctx.D = math.min(ctx.D, math.max(0, tc - U.VictimCut))
					ctx.Near = true
				end
			end
			if (ctx.EHit - ctx.Cam.Position).Magnitude < U.NearCamera then ctx.Near = true end
		end

		table.clear(parts)
		table.clear(frames)
		cbPoseWindup(set, D, U, ctx, parts, frames)
		cbPoseBeam(set, D, U, ctx, parts, frames)

		-- sprites (never thinned-in; never near your own camera)
		if not h.Thin then
			local stopped = h.StopAt and e >= h.StopAt
			h.GatherFx.Enabled = not ctx.FP and e >= 1.05 and e < 1.70 and not stopped
			if h.GatherFx.Enabled then h.Gather.CFrame = CFrame.new(ctx.F) end
			h.DownFx.Enabled = e < 0.45 and not stopped
			if h.DownFx.Enabled then h.Down.CFrame = CFrame.new(rp - Vector3.new(0, 2.4, 0)) end
			local lo = ctx.FP and L.Beam.FpSpeckStart or 1.6                -- your own: no specks near the lens
			local hi = ctx.D - L.Beam.HeadGap
			local bodyOn = h.Fired and not stopped and hi - lo > 5
			h.BodyFx.Enabled = bodyOn
			if bodyOn then
				local band = math.ceil(math.clamp(hi - lo, 1, 60) / 15)
				if band ~= h.Band then
					h.Band = band
					h.BodyFx.Rate = math.max(1, h.BaseRate * band / 4)     -- a Rate write only when the 15-stud band changes
				end
				local len = math.max(0.5, math.floor((hi - 4.5 - lo) * 2) / 2)      -- specks travel <= 4.5 studs
				if len ~= h.BodyLen then
					h.BodyLen = len
					h.Body.Size = Vector3.new(0.8, 0.8, len)
				end
				h.Body.CFrame = CFrame.lookAt(ctx.M + ctx.B * (lo + len * 0.5), ctx.M + ctx.B * (lo + len))
			end
			local impactOn = ctx.ContactAt ~= nil and ctx.Contact ~= "air" and not ctx.Near and not stopped
			if impactOn then                                            -- moved first: the burst must start at the hit
				local back = (ctx.Contact == "body") and -ctx.B or (ctx.Normal * 0.6 - ctx.B * 0.4)
				h.Impact.CFrame = CFrame.lookAt(ctx.EHit, ctx.EHit + back)
				if h.ImpactAt ~= ctx.ContactAt then
					h.ImpactAt = ctx.ContactAt
					local now = os.clock()
					if not h.LastBurst or now - h.LastBurst > 0.25 then
						h.LastBurst = now
						h.ImpactFx:Emit(10)
					end
				end
			end
			h.ImpactFx.Enabled = impactOn
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	if isLocal then
		-- your own: after the camera and the viewmodel have moved this frame (Camera, Camera + 2), or it trails them
		CB.Serial = (CB.Serial or 0) + 1
		h.RenderName = "CryoBeamV2_" .. CB.Serial
		RunService:BindToRenderStep(h.RenderName, Enum.RenderPriority.Camera.Value + 3, step)
	else
		h.Connection = RunService.Heartbeat:Connect(step)
	end
	return h
end

--- CryoBeamWindup at the cast. `t0` is the server time of the cast (the payload's T0); without it the clock starts on
--- arrival. `chargeTime` is kept for the old payload and ignored (the beats come from Tuning.CryoBeam).
function VFXLibrary.CryoBeamWindup(character, chargeTime, t0)
	local h = cbStart(character, (type(t0) == "number") and t0 or cbClock())
	if h and h.Root and cbClock() - h.T0 < 0.3 then playSound(h.Root, "UltCharge") end
	return h
end

--- CryoBeamFire: the beam starts on the same clock (a late message catches up). Without a windup (a joiner, a lost
--- message) the handle starts here, at the fire.
function VFXLibrary.CastCryoBeam(character, targetPosition, t0)
	local U = T.CryoBeam
	local FIRE = U.LevitateTime + U.ChargeTime
	local h = VFXLibrary.ActiveBeams[character]
	if not (h and h.Alive) then
		h = cbStart(character, (type(t0) == "number") and t0 or (cbClock() - FIRE))
		if not h then return nil end
	end
	if h.StopAt and h.PreFire then return h end
	h.Fired = true
	if typeof(targetPosition) == "Vector3" then h.Target = targetPosition end
	if h.Root and math.abs(cbClock() - h.T0 - FIRE) < 0.3 then playSound(h.Root, "UltFire") end
	return h
end

--- CryoBeamAim: the aim the server accepted (during the windup too: the focus turns toward it).
function VFXLibrary.UpdateCryoBeam(character, position)
	local h = VFXLibrary.ActiveBeams[character]
	if h and typeof(position) == "Vector3" then h.Target = position end
end

--- CryoBeamStop: everything un-forms from where it is (`immediate`: just goes).
function VFXLibrary.StopCryoBeam(character, immediate)
	local h = VFXLibrary.ActiveBeams[character]
	if not h then return end
	if immediate then
		cbFinish(h)
		return
	end
	if not h.StopAt then
		-- the un-form starts when the stop is noticed (the payload has no time); a stop before this client saw the
		-- fire un-forms the windup, and a fire arriving after it is ignored
		h.StopAt = math.max(0, cbClock() - h.T0)
		h.PreFire = not h.Fired
	end
end

--- Build the prototype and park one set in the pool (called deferred from Preload on the client).
function VFXLibrary.WarmCryoBeam()
	local D = cbData()
	if D and #CB.Pool == 0 then cbReleaseSet(cbAcquireSet(D)) end
end

VFXLibrary.StopCryoBeamWindup = VFXLibrary.StopCryoBeam
end   -- (2026-10-19, audit GB-04) the Cryo Beam do-block

--- The moment a Flash Freeze victim is caught (heavy = false) or shattered when the zone ends
--- (heavy = true). Two weights of the same effect rather than two effects, because they are the
--- same event twice: the freeze closing, and the freeze paying out.
function VFXLibrary.ShatterFX(character, heavy)
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	if not root then return end
	local burst = ghostPart({ CFrame = root.CFrame }, fxFolder())
	local scale = heavy and 1.0 or 0.45
	emitter(burst, E.Shards(), { Speed = NR(14 * scale, 34 * scale) }):Emit(heavy and 34 or 12)
	emitter(burst, E.IceChips(), { Speed = NR(10 * scale, 26 * scale) }):Emit(heavy and 26 or 10)
	emitter(burst, E.Glints(), { Speed = NR(6, 14) }):Emit(heavy and 18 or 8)
	if heavy then
		-- (2026-10-19, audit P5F-03) Reduce Flashing skips the white form flash (burstLight halves the light itself)
		if not (Settings.Get and Settings.Get("ReduceFlashing")) then
			emitter(burst, E.FormFlash(), { Size = NS({ 0, 1 }, { 0.3, 9 }, { 1, 0 }) }):Emit(1)
		end
		burstLight(burst, { Color = COL.IceLight, Brightness = 5, Range = 18 }, 0.4)
		playSound(burst, "Shatter")
	end
	Debris:AddItem(burst, 2)
end

----------------------------------------------------------------------------------------------------
-- M1: ICICLE SHARD
----------------------------------------------------------------------------------------------------
-- CRYO v2 (2026-10-08): the approved shard (vfx_blocking/cryo/ice_v2: CRYO_V2_HANDOFF.md section 3, RECIPE.md) -- the
-- leanest effect in the kit, because it fires most often. A VISUAL restyle only: Speed, Range, the merge onto the aim line
-- and the hit report are unchanged.
-- The projectile is ReplicatedStorage.IceMagicMeshes.IcicleShard.IS_Cluster (the grounded shard: one ice shard with a
-- snapped tail, its tip at +Y), drawn as milky ICE rather than flat toon bands:
--   BODY    IS_Cluster resized non-uniformly into one long thin faceted shard, CrystalLength x IS2.Width studs, Material
--           Ice at Transparency 0.4, tinted toward mid ice; a lighter tip (a short, slightly narrower copy of the same mesh
--           sharing the point, nearly white) reads through it.
--   GLINT   a white-hot sparkle locked to the point.
--   TRAIL   the Frost Line: a thin cyan Trail (IS2.TrailWidth -> 0 over IS2.TrailLife) off the heel. With the glint it is
--           one of the two things that glow.
--   WAKE    a faint lit vapor wake and a few snow flecks shed off the heel (skipped when thinned).
-- IS_Streak (the old Neon tracer part) is no longer drawn: the Trail is the tracer.
-- Three beats, all client-side replays -- the hit itself is unchanged (SpellshotInput, AbilityHandler):
--   CAST    on the release frame both animation layers already fire it on (Viewmodel ArmClips
--           IcicleShard 0.107 s, CastPose IcicleShardR/L 0.12 s) the shard forms at the hand -- a quick
--           scale-up -- and CryoFX throws a little frost off the palm.
--   FLIGHT  fast and flat. The heel leaves the palm and the tip rides the shot point once the shard has
--           merged onto the aim line. Your own shot shrinks as it goes, so it does not sit on the target
--           under your crosshair. On a hit the shard is gone at once and its trail finishes fading where it
--           stopped (IS2.Linger), then the look goes back to the pool.
--   IMPACT  CryoFX.ShardImpact (splinters off the surface); the old capped sprite shatter below only if CryoFX is
--           missing. Played at this client's own hit moment, and not at all for somebody else's shard landing on you.
-- GRAPHICS QUALITY / REDUCE ENEMY VFX: on low density, or for somebody else's shot with Reduce Enemy
-- VFX on, the wake and flecks are skipped (the shard, its glint and its Frost Line stay) and the impact is thinned.
-- If the mesh is not in the place the shot still flies, as a plain ice rod.
-- Budget per shot: 2 parts, 1 Trail, 3 emitters, all pooled.
--
-- One shared render step moves every shard in flight, so rapid fire costs one binding, not one per
-- shot, and the parts are pooled.
--
-- Tuning hook: a "ShotTimeScale" attribute on ReplicatedStorage.IceMagic slows the whole M1 --
-- the thrust, the fire rate, the release and the shard -- together (0.25 = quarter speed), the same
-- way CastPoseTimeScale slows the body clips. It is how the animation gets filmed: Studio frame
-- grabs top out near 9 fps, which is two frames per thrust at full speed. Defaults to 1.
local shards = {}
local SHARD_STEP = "SpellshotShards"
local shardBound = false

-- Measured off the Blender export (export/icicle_shard/IcicleShard_Data.json). Blender (x, y, z) lands
-- at MeshPart (-x, z, y) and an imported MeshPart sits on its bounding-box centre, so this is where its
-- centre sits from the tip, in the part's own space at the template's size: the flight axis is the part's +Y.
local IS = {
	Folder = "IcicleShard",
	-- 2026-09-24, the grounded shard (cryo3/assets/build_cryokit2.py, CK_IS_Cluster): one lit ice shard 1.5 long with a
	-- snapped tail. v2 scales it (and this offset with it) to CrystalLength x IS2.Width.
	ClusterCentre = Vector3.new(-0.0038, -0.7732, -0.0122),  -- from the shard's tip
	Pool = {},
	PoolMax = 9,                                           -- 3 in flight per shooter at the fastest rate
}

-- The v2 look's own numbers (purely visual; RECIPE.md palette).
local IS2 = {
	Width = 0.17,                                   -- studs across (its length is Tuning.IcicleShard.CrystalLength)
	Body = Color3.fromRGB(184, 226, 248), BodyT = 0.25, Gloss = 0.15,  -- the reel's shard: pale milky ice
	Tip = Color3.fromRGB(236, 250, 255), TipT = 0.15, TipFrac = 0.3, TipWide = 0.92,  -- the lighter tip
	Line = Color3.fromRGB(63, 224, 255), LineHot = Color3.fromRGB(141, 243, 255),     -- the Frost Line #3FE0FF / #8DF3FF
	TrailWidth = 0.05, TrailLife = 0.1, TrailFrom = 0.9,                 -- TrailFrom: where along the shard it leaves
	Frost = Color3.fromRGB(242, 251, 255), Fleck = Color3.fromRGB(214, 244, 255), Glint = Color3.new(1, 1, 1),
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Linger = 0.12,                                  -- after a hit, the trail's last segments finish fading
}

-- the white-hot glint locked to the point
function E.ShardGlint()
	return {
		Texture = IS2.Sparkle, Color = CS(IS2.Glint), LightEmission = 1, LightInfluence = 0,
		Size = NS({ 0, 0.42 }, { 1, 0 }), Transparency = NS({ 0, 0.1 }, { 1, 1 }), Lifetime = NR(0.06, 0.1),
		Speed = NR(0), Rotation = NR(0, 360), RotSpeed = NR(-200, 200), LockedToPart = true, Rate = 24,
		Enabled = false, ZOffset = 0.3,
	}
end

-- the vapor wake off the heel: lit, faint, gone in a third of a second
function E.ShardWake()
	return {
		Texture = C.Textures.Smoke, Color = CS(IS2.Frost), LightEmission = 0, LightInfluence = 1,
		Size = NS({ 0, 0.12 }, { 1, 0.6 }), Transparency = NS({ 0, 0.72 }, { 1, 1 }), Lifetime = NR(0.3, 0.4),
		Speed = NR(0.3, 1.2), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Bottom,
		Rotation = NR(0, 360), RotSpeed = NR(-60, 60), Drag = 3, Rate = 50, Enabled = false,
	}
end

-- a few snow flecks shed off the heel
function E.ShardFlecks()
	return {
		Texture = IS2.Sparkle, Color = CS(IS2.Fleck), LightEmission = 0.3, LightInfluence = 0.6,
		Size = NS({ 0, 0.14 }, { 1, 0 }), Transparency = NS({ 0, 0 }, { 1, 1 }), Lifetime = NR(0.3, 0.4),
		Speed = NR(1, 3), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(0, -6, 0), Drag = 2, Rotation = NR(0, 360), Rate = 9, Enabled = false,
	}
end

function VFXLibrary.ShotTimeScale()
	local ice = game:GetService("ReplicatedStorage"):FindFirstChild("IceMagic")
	local v = ice and ice:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

local function rodFrame(pos, dir)
	-- a Cylinder's axis is its X; turn it to lie along the flight direction
	return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
end

local function smooth(u)
	return u * u * (3 - 2 * u)
end

--- The imported shard template, or nil when the place does not have it.
local function shardTemplates()
	local folder = meshFolder()
	local sub = folder and folder:FindFirstChild(IS.Folder)
	local cluster = sub and sub:FindFirstChild("IS_Cluster")
	if cluster and cluster:IsA("MeshPart") then
		return cluster
	end
	if not warned.IcicleShard then
		warned.IcicleShard = true
		warn(("[VFXLibrary] IS_Cluster not found in ReplicatedStorage.%s.%s - Icicle Shard falls back to a plain rod")
			:format(C.MeshFolderName, IS.Folder))
	end
	return nil
end

--- A copy of the shard mesh as milky ice (drawn through a SpecialMesh, ffKitPart: its Color is the colour, not a tint
--- over the mesh's cobalt bake).
local function iceCopy(template, size, color, alpha)
	local p = ffKitPart(template)
	apply(p, { Material = Enum.Material.Ice, Color = color, Reflectance = IS2.Gloss, Transparency = alpha, Size = size })
	return p
end

--- The trail's two attachments (IS2.TrailWidth apart, across the flight) near the heel and the glint on the point, at
--- shard scale `s`. The body's frame is the shot frame (origin on the point, +Y the flight) shifted by BodyCentre.
local function rigShardLook(look, s)
	local heel = Vector3.new(0, -T.IcicleShard.CrystalLength * IS2.TrailFrom * s, 0) - look.BodyCentre * s
	local half = Vector3.new(IS2.TrailWidth * s * 0.5, 0, 0)
	look.A0.Position = heel + half
	look.A1.Position = heel - half
	look.GlintAt.Position = -look.TipCentre * s
end

-- FROSTBLADE (2026-10-14): the shot is a low-poly ice kunai (FrostbladeKit "Shard": ring, tang, ridged leaf blade, the
-- silver bevel; 0.34 wide, the shard's length), its flats facing the side. The trail, glint, wake and flecks are the
-- Default's; the Tip is an invisible holder for the glint on the point. Its own pool.
-- FROST LOTUS (2026-10-15; Epic: a glowing petal blade, 3 long, five petal motes riding it, FrostLotusKit.Ride): the
-- dart the same way (FrostLotusKit "Dart", its tip on the point, NOT stretched to the shard's length; the trail carries
-- the length), its own pool.
IS.KPool, IS.LPool = {}, {}
local function acquireKunaiLook(lotus)
	local pool = lotus and IS.LPool or IS.KPool
	if VFXLibrary.Wrap then pool = VFXLibrary.Wrap.Pool(pool) end                     -- a Cryo wrap keeps its own looks
	local look = table.remove(pool)
	if look then return look end
	local fb = lotus and frostLotus() or frostblade()
	local k = fb and fb.Kind(lotus and "Dart" or "Shard")
	if not k then return nil end
	local S = T.IcicleShard
	local kl = lotus and 1 or (S.CrystalLength / k.L)
	local stretch = Vector3.new(1, kl, 1)
	local body = k.Body:Clone()
	body.Name = "IcicleShard"
	local tip = new("Part", {
		Name = "IcicleShardTip", Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	})
	local a0 = new("Attachment", { Name = "TrailA" }, body)
	local a1 = new("Attachment", { Name = "TrailB" }, body)
	local glintAt = new("Attachment", { Name = "Glint" }, tip)
	look = {
		Body = body, Tip = tip, A0 = a0, A1 = a1, GlintAt = glintAt, Pool = pool,
		BodyT = (lotus and k.BodyT) or fb.Look.IceT, TipT = 1,      -- (Frost Lotus Epic: its glowing blade's own)
		BodySize = k.Size * stretch, TipSize = tip.Size,
		-- the kunai's tail sits a shard-length behind the point (the shot frame's origin), +Y along the flight
		BodyCentre = (k.BodyOff - Vector3.new(0, k.L, 0)) * stretch, TipCentre = Vector3.zero,
		Trail = new("Trail", {
			Attachment0 = a0, Attachment1 = a1, FaceCamera = true, Lifetime = IS2.TrailLife, MinLength = 0.05,
			WidthScale = NS({ 0, 1 }, { 1, 0 }), Color = CS(IS2.LineHot, IS2.Line), Transparency = NS({ 0, 0 }, { 1, 0.5 }),
			LightEmission = 1, LightInfluence = 0, Enabled = false,
		}, body),
		Glint = emitter(glintAt, E.ShardGlint()),
		Wake = emitter(a0, E.ShardWake()),
		Flecks = emitter(a0, E.ShardFlecks()),
	}
	body.Size = look.BodySize
	rigShardLook(look, 1)
	if lotus and fb.Ride then fb.Ride(look) end    -- Frost Lotus (Epic): the blade's petal motes ride it
	return look
end

-- SNOW GLOBE (2026-10-15): the mini globe (SnowGlobeKit.ShotLook): its base disc the Body and its glass the Tip, the
-- glass's crown on the point; the glowing band and the glass's camera-facing outline ride them (SnowGlobeKit.Ride); the
-- Default's trail, glint and wake, and a short snow trail in place of the flecks. Its own pool.
IS.GPool = {}
local function acquireGlobeLook()
	local pool = VFXLibrary.Wrap and VFXLibrary.Wrap.Pool(IS.GPool) or IS.GPool       -- a Cryo wrap keeps its own looks
	local look = table.remove(pool)
	if look then return look end
	local sg = snowGlobe()
	local g = sg and sg.ShotLook()
	if not g then return nil end
	local a0 = new("Attachment", { Name = "TrailA" }, g.Body)
	local a1 = new("Attachment", { Name = "TrailB" }, g.Body)
	local glintAt = new("Attachment", { Name = "Glint" }, g.Tip)
	look = {
		Body = g.Body, Tip = g.Tip, A0 = a0, A1 = a1, GlintAt = glintAt, Pool = pool,
		BodyT = g.BodyT, TipT = g.TipT, BodySize = g.Body.Size, TipSize = g.Tip.Size,
		BodyCentre = g.BodyCentre, TipCentre = g.TipCentre,
		Band = g.Band, BandRel = g.BandRel, BandSize = g.BandSize, Edge = g.Edge, EdgeSize = g.EdgeSize, EdgeOff = g.EdgeOff,
		Trail = new("Trail", {
			Attachment0 = a0, Attachment1 = a1, FaceCamera = true, Lifetime = IS2.TrailLife, MinLength = 0.05,
			WidthScale = NS({ 0, 1 }, { 1, 0 }), Color = CS(IS2.LineHot, IS2.Line), Transparency = NS({ 0, 0 }, { 1, 0.5 }),
			LightEmission = 1, LightInfluence = 0, Enabled = false,
		}, g.Body),
		Glint = emitter(glintAt, E.ShardGlint()),
		Wake = emitter(a0, E.ShardWake()),
		Flecks = emitter(a0, sg.TrailSnow()),
	}
	rigShardLook(look, 1)
	sg.Ride(look)
	return look
end

--- (2026-10-19, audit P5F-16) a pooled look's emitters were scaled to Graphics Quality once, when made: a look taken from
--- the pool is put back on the CURRENT density (each look remembers the one it is scaled to). Shard looks fly loose, so no
--- Reduce Enemy VFX factor is in that number.
function IS.Redensity(look)
	local d = Settings.EffectDensity or 1
	local was = look.Density or 1
	look.Density = d
	if was == d or was <= 0 then return look end
	for _, key in ipairs({ "Glint", "Wake", "Flecks" }) do
		local pe = look[key]
		if typeof(pe) == "Instance" and pe.Rate > 0 then pe.Rate = math.max(1, pe.Rate * d / was) end
	end
	return look
end

local function acquireShardLook(kunai)
	-- FROST DRAGON (Mythic, 2026-10-16): the Frost Wyrmling (FrostDragonKit.ShotLook / Ride: invisible holders here, the
	-- head, jaw and segments ride them); the Default's trail, glint and wake, and scale chips for the flecks. Its own pool.
	if kunai == "dragon" then
		IS.DPool = IS.DPool or {}
		local pool = VFXLibrary.Wrap and VFXLibrary.Wrap.Pool(IS.DPool) or IS.DPool
		-- (2026-10-19, audit P5F-23) a Cryo wrap over the skin paints the Wyrmling (head, jaw, segments), as the globe and
		-- kunai branches below paint theirs; the holders here are invisible, so the pieces are what PaintKit is given
		local function painted(l)
			local W, w = VFXLibrary.Wrap, l.Wyrm
			if W and type(w) == "table" then
				W.PaintKit(w.Head)
				W.PaintKit(w.Jaw)
				for _, seg in ipairs(w.Segs or {}) do W.PaintKit(seg) end
			end
			return l
		end
		local look = table.remove(pool)
		if look then return painted(IS.Redensity(look)) end
		local m = script.Parent:FindFirstChild("FrostDragonKit")
		local okD, fd = pcall(function() return m and require(m) end)
		local g = okD and fd and fd.ShotLook()
		if g then
			local a0 = new("Attachment", { Name = "TrailA" }, g.Body)
			local a1 = new("Attachment", { Name = "TrailB" }, g.Body)
			local glintAt = new("Attachment", { Name = "Glint" }, g.Tip)
			look = {
				Body = g.Body, Tip = g.Tip, A0 = a0, A1 = a1, GlintAt = glintAt, Pool = pool,
				BodyT = g.BodyT, TipT = g.TipT, BodySize = g.Body.Size, TipSize = g.Tip.Size,
				BodyCentre = g.BodyCentre, TipCentre = g.TipCentre,
				Trail = new("Trail", {
					Attachment0 = a0, Attachment1 = a1, FaceCamera = true, Lifetime = IS2.TrailLife, MinLength = 0.05,
					WidthScale = NS({ 0, 1 }, { 1, 0 }), Color = CS(IS2.LineHot, IS2.Line), Transparency = NS({ 0, 0 }, { 1, 0.5 }),
					LightEmission = 1, LightInfluence = 0, Enabled = false,
				}, g.Body),
				Glint = emitter(glintAt, E.ShardGlint()),
				Wake = emitter(a0, E.ShardWake()),
				Flecks = emitter(a0, fd.TrailChips()),
			}
			rigShardLook(look, 1)
			fd.Ride(look)
			look.Density = Settings.EffectDensity or 1   -- (audit P5F-16) the density its emitters were made at
			return painted(look)
		end
	elseif kunai == "globe" then
		local g = acquireGlobeLook()
		if g then
			if VFXLibrary.Wrap then VFXLibrary.Wrap.PaintKit(g) end                   -- a wrap over the skin
			return g
		end
	elseif kunai then
		local k = acquireKunaiLook(kunai == "lotus")
		if k then
			if VFXLibrary.Wrap then VFXLibrary.Wrap.PaintKit(k) end
			return k
		end
	end
	local pool = VFXLibrary.Wrap and VFXLibrary.Wrap.Pool(IS.Pool) or IS.Pool     -- a Cryo wrap keeps its own looks
	local look = table.remove(pool)
	if look then return IS.Redensity(look) end   -- (2026-10-19, audit P5F-16) on today's Graphics Quality
	local S = T.IcicleShard
	local cluster = shardTemplates()
	if cluster then
		local ts = cluster.Size
		local kl = S.CrystalLength / math.max(ts.Y, 1e-3)
		local kw = IS2.Width / math.max(ts.X, ts.Z, 1e-3)
		local cc = IS.ClusterCentre
		local bodySize = Vector3.new(ts.X * kw, ts.Y * kl, ts.Z * kw)
		local tipSize = Vector3.new(ts.X * kw * IS2.TipWide, ts.Y * kl * IS2.TipFrac, ts.Z * kw * IS2.TipWide)
		local body = iceCopy(cluster, bodySize, IS2.Body, IS2.BodyT)
		if VFXLibrary.Wrap then VFXLibrary.Wrap.Solidify(body) end    -- a Cryo wrap's solid look (Black Ice)
		local tip = iceCopy(cluster, tipSize, IS2.Tip, IS2.TipT)
		if VFXLibrary.Wrap then VFXLibrary.Wrap.Glow(tip) end        -- (its white head glows: self-lit, neutral)
		body.Name, tip.Name = "IcicleShard", "IcicleShardTip"
		local a0 = new("Attachment", { Name = "TrailA" }, body)
		local a1 = new("Attachment", { Name = "TrailB" }, body)
		local glintAt = new("Attachment", { Name = "Glint" }, tip)
		look = {
			Body = body, Tip = tip, A0 = a0, A1 = a1, GlintAt = glintAt,
			BodySize = bodySize, TipSize = tipSize,
			BodyCentre = Vector3.new(cc.X * kw, cc.Y * kl, cc.Z * kw),
			TipCentre = Vector3.new(cc.X * kw * IS2.TipWide, cc.Y * kl * IS2.TipFrac, cc.Z * kw * IS2.TipWide),
			Trail = new("Trail", {
				Attachment0 = a0, Attachment1 = a1, FaceCamera = true, Lifetime = IS2.TrailLife, MinLength = 0.05,
				WidthScale = NS({ 0, 1 }, { 1, 0 }), Color = CS(IS2.LineHot, IS2.Line), Transparency = NS({ 0, 0 }, { 1, 0.5 }),
				LightEmission = 1, LightInfluence = 0, Enabled = false,
			}, body),
			Glint = emitter(glintAt, E.ShardGlint()),
			Wake = emitter(a0, E.ShardWake()),
			Flecks = emitter(a0, E.ShardFlecks()),
		}
		look.Pool = pool
		look.Density = Settings.EffectDensity or 1   -- (audit P5F-16) the density its emitters were made at
		rigShardLook(look, 1)
		return look
	end
	return {
		Rod = new("Part", {
			Name = "IcicleShardRod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(S.Length, S.Width, S.Width),
			Color = S.Color, Material = Enum.Material.Ice, Transparency = IS2.BodyT, Anchored = true, CanCollide = false,
			CanQuery = false, CanTouch = false, CastShadow = false,
		}),
	}
end

local function releaseShardLook(look)
	-- pool it only if both parts can still be unparented: a rod is only the stand-in, and a part
	-- destroyed from outside (the FX folder cleared) cannot come back
	local reusable = not look.Rod and look.Body.Parent ~= nil and look.Tip.Parent ~= nil
		and pcall(function()
			look.Trail.Enabled = false
			look.Glint.Enabled, look.Wake.Enabled, look.Flecks.Enabled = false, false, false
			look.Body.Parent = nil
			look.Tip.Parent = nil
		end)
	local pool = look.Pool or IS.Pool
	if reusable and #pool < IS.PoolMax then
		table.insert(pool, look)
		return
	end
	for _, key in ipairs({ "Body", "Tip", "Rod" }) do
		local part = look[key]
		if part then pcall(function() part:Destroy() end) end
	end
end

--- Where a shot stops: the shard is gone at once, its Frost Line trail finishes fading where it stopped, then the look
--- goes back to the pool.
local function retireShardLook(look)
	if look.Rod then
		releaseShardLook(look)
		return
	end
	pcall(function()
		look.Body.Transparency, look.Tip.Transparency = 1, 1
		look.Glint.Enabled, look.Wake.Enabled, look.Flecks.Enabled = false, false, false
	end)
	task.delay(IS2.Linger, releaseShardLook, look)
end

-- The particle rigs: an Attachment with its emitters, on one invisible host part, reused only once its
-- last particle has died. A shot creates no instances once the rigs exist. (Emitting from one shared
-- emitter would not do: :Emit() spawns where the emitter is when particles next update, so two impacts
-- in the same frame would both land on the second one's spot.) Each burst size is its own emitter,
-- because a live particle follows its emitter's Size.
local shardRigs = { Host = nil, Impact = {}, Cast = {} }

local function takeShardRig(kind, life, build)
	local host = shardRigs.Host
	if not (host and host.Parent) then
		host = ghostPart({ Name = "IcicleShardFX", CFrame = CFrame.new() })
		shardRigs.Host = host
		shardRigs.Impact, shardRigs.Cast = {}, {}         -- the old rigs went with the old host
	end
	local now = os.clock()
	local list = shardRigs[kind]
	for _, rig in ipairs(list) do
		if now - rig.Used > life then
			rig.Used = now
			return rig
		end
	end
	local att = new("Attachment", { Name = kind }, host)
	local rig = build(att)
	rig.Attachment, rig.Used = att, now
	table.insert(list, rig)
	return rig
end

local function impactRig(att)
	return {
		Fragments = emitter(att, E.ShardFragments()),
		Burst = emitter(att, E.ShardBurst(1)),
		BurstThin = emitter(att, E.ShardBurst(0.7)),
		BurstNear = emitter(att, E.ShardBurst(0.35)),
	}
end

local function castRig(att)
	return { Bits = emitter(att, E.ShardCastBits()) }
end

--- IMPACT: the shatter, where this client's shot stopped.
local function shardImpact(hit, sh)
	local S = T.IcicleShard
	-- somebody else's shard landing on YOU: your own hit reactions already show it (with Reduce Flashing
	-- and Status Intensity applied), and a burst on your own head would fill the screen
	local me = VFXLibrary.LocalCharacter
	if not sh.OnHit and me and hit.Instance:IsDescendantOf(me) then return end
	local cfx = cryoFX()
	if cfx and cfx.ShardImpact then
		cfx.ShardImpact(hit, sh.Dir, sh.Thin, sh.Caster)  -- grounded (2026-09-24): splinters of the shard, no sprites
		return
	end
	local rig = takeShardRig("Impact", 0.55, impactRig)
	-- fragments come off the surface, leaning back along the shot
	local out = hit.Normal * 0.75 - sh.Dir * 0.25
	out = out.Magnitude > 1e-3 and out.Unit or -sh.Dir
	local p = hit.Position + hit.Normal * 0.05
	local cam = workspace.CurrentCamera
	local near = cam ~= nil and (p - cam.CFrame.Position).Magnitude < S.BurstNear
	rig.Attachment.WorldCFrame = CFrame.lookAt(p, p + out)
	rig.Fragments:Emit((sh.Thin or near) and math.ceil(S.ImpactFragments / 2) or S.ImpactFragments)
	local burst = near and rig.BurstNear or (sh.Thin and rig.BurstThin or rig.Burst)
	burst:Emit(1)
end

--- Where the shard's parts go this frame. `pos` is the drawn shot point (the path plus the eased hand
--- offset), `w` how much of that offset is left (1 at release, 0 once merged).
local function placeShard(sh, pos, t, w, parts, cframes)
	local S = T.IcicleShard
	local look = sh.Look
	if look.Rod then
		-- like the shard: the heel on the palm at release, the tip on the shot point once merged
		parts[#parts + 1] = look.Rod
		cframes[#cframes + 1] = rodFrame(pos + sh.Dir * (S.Length * (w - 0.5)), sh.Dir)
		return
	end
	-- CAST: forms at the hand
	local u = math.clamp(t / S.FormTime, 0, 1)
	local s = (u >= 1) and 1 or (S.FormFrom + (1 - S.FormFrom) * easeOutQuad(u))
	if sh.OnHit then
		local far = math.clamp((S.Speed * t - S.OwnShrinkFrom) / S.OwnShrinkOver, 0, 1)
		s *= 1 - (1 - S.OwnFarScale) * smooth(far)
	end
	if s ~= sh.Scale then
		sh.Scale = s
		look.Body.Size = look.BodySize * s
		look.Tip.Size = look.TipSize * s
		rigShardLook(look, s)                    -- the trail narrows and the glint stays on the point with it
	end
	-- FLIGHT: the heel on the palm at release, the tip on the shot point once merged, so neither end
	-- ever reaches back toward the camera. The Frost Line trail draws itself off the heel.
	local tip = pos + sh.Dir * (S.CrystalLength * s * w)
	local frame = CFrame.fromMatrix(tip, -sh.Up, sh.Dir)
	parts[#parts + 1] = look.Body
	cframes[#cframes + 1] = frame * CFrame.new(look.BodyCentre * s)
	parts[#parts + 1] = look.Tip
	cframes[#cframes + 1] = frame * CFrame.new(look.TipCentre * s)
end

-- Runs after the camera and the viewmodel have moved for the frame, so every shard is placed against
-- the view that is about to be drawn. (A Heartbeat mover trails a moving camera by a frame, which at
-- slide speed is most of a stud.)
local function stepShards()
	local S = T.IcicleShard
	local now = os.clock()
	local scale = VFXLibrary.ShotTimeScale()
	local cam = workspace.CurrentCamera
	local parts, cframes = {}, {}
	for i = #shards, 1, -1 do
		local sh = shards[i]
		-- the flight clock starts on the shard's first drawn frame, so that frame is at the hand, whenever
		-- this step first runs
		if not sh.T0 then
			sh.T0 = now
		end
		local t = (now - sh.T0) * scale
		local dist = math.min(S.Speed * t, S.Range)
		local from = sh.Origin + sh.Dir * sh.Dist
		local to = sh.Origin + sh.Dir * dist
		local hit = dist > sh.Dist and workspace:Raycast(from, to - from, sh.Params)
		sh.Dist = dist
		local main = sh.Look.Body or sh.Look.Rod
		if hit or dist >= S.Range or not main.Parent then
			table.remove(shards, i)
			-- the hit report first: nothing cosmetic may stand between a hit and the server hearing of it
			if hit and sh.OnHit then task.spawn(sh.OnHit, hit) end
			if main.Parent then retireShardLook(sh.Look) else releaseShardLook(sh.Look) end
			if hit then
				local ok, err = pcall(shardImpact, hit, sh)
				if not ok and not warned.ShardImpact then
					warned.ShardImpact = true
					warn("[VFXLibrary] Icicle Shard impact failed: " .. tostring(err))
				end
			end
		else
			local pos = to
			local w = 1 - smooth(math.clamp(t / S.Merge, 0, 1))
			if sh.Offset then
				-- the shard you see: from the hand onto the true path, carrying the camera's travel while
				-- it merges, so it does not slide off sideways as it leaves a moving player
				if w <= 0 then
					sh.Offset = nil
				else
					local travel = cam and (cam.CFrame.Position - sh.CamStart) or Vector3.zero
					pos += (sh.Offset + travel) * w
				end
			end
			placeShard(sh, pos, t, w, parts, cframes)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if #shards == 0 then
		game:GetService("RunService"):UnbindFromRenderStep(SHARD_STEP)
		shardBound = false
	end
end

--- `origin` -> `target` is the shot itself. `visualFrom`, when given, is where the shard is SEEN to
--- leave (the firing hand, in first person): it starts there and eases onto the true path over
--- Tuning.IcicleShard.Merge seconds. So the shard always leaves the hand and always goes exactly where
--- the crosshair was, however fast the player is moving. Without it, the shard simply flies the path.
--- `onHit(result)`, when given, is called with the RaycastResult where the shard stops: for the local
--- player's own shots that is the shot's hit, reported to the server (SpellshotInput, AbilityHandler).
--- A shot with onHit is this client's own; any other is somebody else's, for Reduce Enemy VFX.
function VFXLibrary.FireIcicleShard(origin, target, exclude, visualFrom, onHit, caster)
	local S = T.IcicleShard
	local dir = target - origin
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	local folder = fxFolder()
	local cam = workspace.CurrentCamera
	-- the fan of crystals stands vertical; straight up or down, it takes the camera's up instead
	local up = Vector3.yAxis - dir * dir.Y
	if up.Magnitude < 0.2 then
		local alt = cam and cam.CFrame.UpVector or Vector3.zAxis
		up = alt - dir * dir:Dot(alt)
		if up.Magnitude < 1e-3 then up = Vector3.xAxis - dir * dir.X end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { folder }
	for _, inst in ipairs(exclude or {}) do list[#list + 1] = inst end
	params.FilterDescendantsInstances = list
	local start = visualFrom or origin
	-- `caster` (their character): a Frostblade wearer's shot is the kunai
	local fb, fl, sgm = caster and frostblade(), caster and frostLotus(), caster and snowGlobe()
	local fdm = caster and script.Parent:FindFirstChild("FrostDragonKit")
	local okF, fdk = pcall(function() return fdm and require(fdm) end)
	fdk = okF and fdk or nil
	local look = acquireShardLook((fdk and fdk.Built and fdk.On(caster) and "dragon") or (fl and fl.On(caster) and "lotus")
		or (sgm and sgm.Built and sgm.On(caster) and "globe")
		or (fb ~= nil and fb.On(caster)))
	if look.Body then
		-- a pooled look comes back hidden from its last hit (retireShardLook)
		look.Body.Transparency, look.Tip.Transparency = look.BodyT or IS2.BodyT, look.TipT or IS2.TipT
	end
	local sh = {
		Look = look, Origin = origin, Dir = dir, Up = up.Unit, Dist = 0, Params = params,
		Offset = visualFrom and (visualFrom - origin) or nil,
		CamStart = cam and cam.CFrame.Position or origin,
		OnHit = onHit, Caster = caster,
		-- (2026-10-19, audit P5F-06 / P5A-12) Reduce Enemy VFX thins an ENEMY's shot only (IsEnemy), not a teammate's;
		-- CryoFX.ShardImpact reads this flag as "an enemy's" too (it also picks the Snow Globe slab tier). No caster: as before.
		Thin = (Settings.EffectDensity or 1) < 0.75
			or (Settings.ThinEnemyVFX and onHit == nil and (caster == nil or VFXLibrary.IsEnemy(caster))),
	}
	-- the release frame, placed before it is parented so a pooled part never flashes where it last was
	local parts, cframes = {}, {}
	placeShard(sh, start, 0, 1, parts, cframes)
	for i, p in ipairs(parts) do
		p.CFrame = cframes[i]
		p.Parent = folder
	end
	if look.Trail then
		-- the trail starts on the release point (never a streak from where a pooled look last was); thinned, the shard
		-- keeps its glint and its Frost Line and drops the wake
		look.Trail:Clear()
		look.Trail.Enabled = true
		for _, pe in ipairs({ look.Glint, look.Wake, look.Flecks }) do pe:Clear() end
		look.Glint.Enabled = true
		look.Wake.Enabled = not sh.Thin
		look.Flecks.Enabled = not sh.Thin
	end
	shards[#shards + 1] = sh
	-- the grounded cast (2026-09-24): frost off the palm (CryoFX); the sprite bits below are off (CastFragments 0)
	local cfx = cryoFX()
	if cfx and cfx.ShardCast then pcall(cfx.ShardCast, start, dir, sh.Thin) end
	-- CAST: two stray fragments off the palm as the cluster forms
	if not sh.Thin and S.CastFragments > 0 then
		local ok = pcall(function()
			local rig = takeShardRig("Cast", 0.45, castRig)
			rig.Attachment.WorldCFrame = CFrame.lookAt(start, start + dir)
			rig.Bits:Emit(S.CastFragments)
		end)
		if not ok and not warned.ShardCast then
			warned.ShardCast = true
			warn("[VFXLibrary] Icicle Shard cast fragments failed")
		end
	end
	if not shardBound then
		shardBound = true
		game:GetService("RunService"):BindToRenderStep(SHARD_STEP, Enum.RenderPriority.Camera.Value + 3, stepShards)
	end
end

--- emitter() for the skin modules (SnowGlobeFX): Graphics Quality, Reduce Enemy VFX and the flat-lit scale stay one change
VFXLibrary.Emitter = emitter

VFXLibrary.WrapTables = { FF2 = FF2, IS2 = IS2 }     -- the palettes a Cryo wrap swaps (CryoWrap; CryoFX.Start installs it)

return VFXLibrary
