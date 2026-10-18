--[[
	SkinCatalog  (ModuleScript)  ->  ReplicatedStorage/Spellshot/SkinCatalog

	The ability skins (2026-10-10, the first slice of the reskin system). A skin changes COLOUR only: no shape, timing,
	damage, range, hitbox or hit-feedback value reads anything here.

	  Skins     every skin: Id, DisplayName, and for a coloured one its palette (Stops, in order; Flat = drawn alpha-
	            blended, not additive, so the colours stay saturated in daylight)
	  Offer     Element -> ability key -> the skin Ids that ability offers ("Default" always first). Anything not listed
	            offers Default only. Adding a skin later is data here, not effect code.
	  Kinds     a broadcast kind's prefix -> the ability key it draws (the server stamps the caster's skin Id on it)
	  ElementSkins  Element -> its full SKINS (reworks: shape and colour, one choice for the whole Element; below)

	Choice: one player attribute per ability, Skin_<abilityKey> (the loadout lives in attributes too). Chosen() reads it
	back validated: an ability only takes a skin while it belongs to the caster's own Element (a borrowed Technique keeps
	Default -- FLAGGED, undecided), the Id must be offered, and OwnsSkin must agree (always true for now: the single place
	Sparks or rarity gating will go). Resolve() turns an Id into a palette the effect code draws with; Default -> nil,
	and nil means "draw exactly as before".
]]

local SkinCatalog = {}
local RunService = game:GetService("RunService")

local function hex(h) return Color3.fromHex(h) end

SkinCatalog.Skins = {
	Default = { Id = "Default", DisplayName = "Default" },
	-- the owner's call on the band sheet (2026-10-10): vivid but a little under full saturation, blending smoothly into
	-- the neighbour only (violet never runs back into red: no magenta, which the Sparks mark keeps)
	Rainbow = { Id = "Rainbow", DisplayName = "Rainbow", Flat = true,
		Stops = { hex("#FF4545"), hex("#FF8F1F"), hex("#FFE81F"), hex("#36E06A"), hex("#3B99FF"), hex("#A954FF") } },
	-- TERRA'S FIRST WRAP (2026-10-10): black volcanic glass in three flat bands, a thin pale highlight on its sharpest
	-- facet edges, the ink, and magma fissures -- three hard layers and a soft halo, the one glowing thing. Drawn by
	-- TerraWrap. EVERY VALUE IS A PROPOSAL. Stage Bands are half-widths in studs on the full-size rock, centre out,
	-- before each fissure's taper; Halo = { base, + per CrackGlow }. Neon pushes orange to yellow, so the Neon inputs sit
	-- a little redder than the target hexes in Crack.
	ObsidianMagma = { Id = "ObsidianMagma", DisplayName = "Obsidian Magma",
		Label = { hex("#E5231B"), hex("#FF7A1A") },   -- red to orange only: violet into red reads pink
		Rock = { Shadow = hex("#14101C"), Mid = hex("#2A2236"), Lit = hex("#4A3E5E") },
		RockTint = Color3.new(0.62, 0.58, 0.52),   -- the approved swatch's: sunlit plastic reads the bands near-black
		LitTint = 0.85,    -- the lit band darkened less, so the top facets read (owner, checkpoint 2)
		Rim = hex("#D9CCFF"),   -- the pale silhouette rim: the rock stays readable on dark ground and in shadow
		Highlight = hex("#D9CCFF"), HighlightWidth = 0.05, HighlightEdges = 2,
		Ink = hex("#080E1A"), InkWidth = 0.04,
		Crack = { Outer = hex("#E5231B"), Middle = hex("#FF7A1A"), Core = hex("#FFF1C2") },
		CrackGlow = 0.6,   -- used only while the SkinCatalog script's CrackGlow attribute is unset
		CrackGlowOwn = 0.8,   -- the caster's own view, x CrackGlow (attribute CrackGlowOwn overrides)
		HaloEdge = hex("#140805"),   -- a warm black: red fading through a blue-black read pink at the halo edge
		-- one molten palette for every Terra move (owner, 2026-10-10: "so everyone matches" Aftershock's magma): yellow-
		-- orange where it is hottest, red-orange at the cooling edge (Neon inputs; on screen roughly twice as bright)
		Stages = {
			Low = { Bands = { { 0.022, hex("#8A3A0C") }, { 0.064, hex("#5A1206") } }, Halo = { 0.02, 0.08 },
				HaloCol = hex("#4A1006"), Seam = hex("#5A1206"), Light = 0.35 },
			Mid = { Bands = { { 0.042, hex("#B04A0E") }, { 0.07, hex("#8A1E08") } }, Halo = { 0.03, 0.16 },
				HaloCol = hex("#6A1808"), Seam = hex("#A0280A"), Light = 0.7 },
			Max = { Bands = { { 0.03, hex("#E07A18") }, { 0.07, hex("#C85A10") }, { 0.102, hex("#A0280A") } }, Halo = { 0.04, 0.24 },
				HaloCol = hex("#8A2A08"), Seam = hex("#C85A10"), Light = 1.1 },
		},
		SeamOff = hex("#1A1420"),
		Light = hex("#FF6A1A"),
		HitFlash = hex("#CCBA5C"),   -- Terra's tan Light: the impact flash stays Terra's (the identity anchor)
		Ember = hex("#FF7A1A"), Grit = { hex("#2A2236"), hex("#14101C") },
		-- AFTERSHOCK, BULWARK WALL, EARTHEN TOMB (2026-10-10): their kits are ~1,240 baked meshes, too many to re-make
		-- per client, so the stone keeps its bake under a MeshPart.Color tint, measured per kit so its Light band lands
		-- on the lit obsidian band (its warm brown x a cool tint = violet-black, not mud). Their glowing seams take a
		-- magma ramp (Neon inputs: Ember at rest, Hot at full -- scaled by CrackGlow); the break faces and dead seams
		-- obsidian; Aftershock's underlay (the gaps between its heaved plates) a dim magma, cooling as the scar heals.
		Tint = { TerraWall2 = Color3.new(0.31, 0.28, 0.73), TerraTomb2 = Color3.new(0.265, 0.23, 0.43),
			TerraAftershock = Color3.new(0.16, 0.14, 0.165) },   -- its plate tops bake WHITE and face the sky: darker and neutral, or they read navy
		Seam = { Ember = hex("#A0280A"), Hot = hex("#E07A18"), Inner = hex("#0C090F"), Dead = hex("#0E0B12") },
		Underlay = hex("#6A1808"), UnderlayHot = hex("#C85A10"),   -- cooled red, and the molten orange behind the front
	},
}

-- PYRO'S FIRST WRAP (2026-10-10; bands per the developer's colour change): a flat comic gas-flame. The flame meshes
-- bake a warm-grey luminance ramp that Neon lights orange; the wrap remaps that ramp, by its position Lo..Hi, into four
-- HARD bands (Steps): shell azure #1C6FD8, body aqua #4FD6EE, inner #C4F4FF, core white. The inputs below are what
-- lands on those on screen: fitted to sampled Neon renders (the render crushes dark channels and lifts the dominant
-- one) and divided by the renderer's own 0.88 tint. Lights go #7FD0FF; embers and hit-flash keep Pyro's warm colours.
SkinCatalog.Skins.AzureFlame = { Id = "AzureFlame", DisplayName = "Azure Flame",
	Label = { hex("#1C6FD8"), hex("#4FD6EE"), hex("#C4F4FF") },
	Flame = { Azure = hex("#3C627D"), Sky = hex("#54949B"), Pale = hex("#889FB6"), White = hex("#ECECEC"),
		Lo = 0.29, Hi = 0.56, Steps = { 0.25, 0.55, 0.8 } },
	Light = hex("#7FD0FF"),
}

-- UMBRA'S FIRST WRAP (2026-10-11): Bloodmoon. Umbra's violet ramp turned red, tone for tone, and nothing else: each
-- colour keeps its place in the ramp (hue ~262 -> ~353 at the same value; Shade alone gains saturation, because a
-- light purple turned by hue alone is pink, not crimson). Drawn by UmbraFX: the Shadow block is the wrap.
-- Umbra's strips, ball and screen images carry their violet baked in, so the wrap MULTIPLIES them: RibbonA's Rest and
-- Band are Beam.Color over the A strips; RibbonB.Tint is Beam.Color over the B strips, with Gain (Beam.Brightness)
-- lifting the red back to the strip's own brightness; the three *Tint colours go over the ball sprite and the
-- Eclipse screen layer. In every multiplier Blue >= Green, or a strip's pale edges turn orange once Brightness clips
-- the red. EVERY VALUE IS A PROPOSAL until the owner signs the wrap off.
-- TOXIN'S FIRST WRAP (2026-10-17): Nightshade, Uncommon. One flat palette over the Default shapes: murky greyish plum gas,
-- violet liquid and membrane, a pinker orchid-lilac Virulence (the one saturated spike). Color = the source per family
-- (ToxinTuning.Color's keys); Display = the inputs per material context that show it on screen, from Default's measured
-- target -> input fit per context, the targets lifted by Default's own source -> target brightness. Every hex clears the
-- shipped-hex guard (nearest: LiquidDeep 20/255 from #4A1A6B). Drawn by ToxinWrap. Approved by the owner 2026-10-18.
SkinCatalog.Skins.Nightshade = { Id = "Nightshade", DisplayName = "Nightshade", Rarity = "Uncommon", Wrap = "Toxin",
	Label = { hex("#5A456E"), hex("#9578B3"), hex("#E39BFF") },
	Palette = {
		Color = { Gas = hex("#5A456E"), GasLit = hex("#735A8A"), GasShadow = hex("#3A2B4A"), GasCore = hex("#231A30"),
			Liquid = hex("#7A5599"), LiquidDeep = hex("#3A2A57"), LiquidSpec = hex("#EBDDFA"),
			Membrane = hex("#9578B3"), MembraneHi = hex("#D9C6EE"), Virulence = hex("#E39BFF") },
		Display = {   -- (round 2: 45% less saturated than the first solve -- the grade made it a bright violet)
			Lobe = { GasCore = Color3.fromRGB(117, 104, 121), GasShadow = Color3.fromRGB(140, 122, 144), Gas = Color3.fromRGB(182, 155, 188), GasLit = Color3.fromRGB(203, 174, 211) },
			Particle = { GasCore = Color3.fromRGB(71, 65, 77), GasShadow = Color3.fromRGB(84, 75, 91), Gas = Color3.fromRGB(108, 97, 119), GasLit = Color3.fromRGB(120, 109, 133) },
			Solid = { Liquid = Color3.fromRGB(156, 137, 167), LiquidDeep = Color3.fromRGB(107, 96, 115), LiquidSpec = Color3.fromRGB(243, 240, 249),
				Membrane = Color3.fromRGB(168, 154, 177), MembraneHi = Color3.fromRGB(190, 183, 194) },
			Neon = { Virulence = Color3.fromRGB(173, 118, 193) },
			Glow = { Virulence = Color3.fromRGB(228, 156, 255) },
		} } }

-- TOXIN'S SECOND WRAP (2026-10-18; flattened to the Uncommon tier 2026-10-19): Coral Snake -- a flat palette, one colour
-- per Default colour name in Default's own shade order: the gas black at the core, deep red in shadow, red in the body,
-- lit red on top and in every halo (a yellow halo over red tints the whole cloud orange: the fire read); yellow lives
-- where it cannot smear -- the bubble's rim, the wet highlight and the Virulence spike. No bands, no moved puffs, no
-- extra particles. Bands carries only the gas's inner light (red) and its glow sprite (dark): no hot white core.
SkinCatalog.Skins.CoralSnake = { Id = "CoralSnake", DisplayName = "Coral Snake", Rarity = "Uncommon", Wrap = "Toxin",
	Label = { hex("#D43A2F"), hex("#F0D23C"), hex("#1B1B22") },
	Palette = {
		Bands = { Light = "Gas", Glow = "GasCore" },
		Color = { GasCore = hex("#1B1B22"), GasShadow = hex("#8E1F1A"), Gas = hex("#D43A2F"), GasLit = hex("#E85A55"),
			Liquid = hex("#D43A2F"), LiquidDeep = hex("#1B1B22"), LiquidSpec = hex("#F8EBA6"), Membrane = hex("#D43A2F"),
			MembraneHi = hex("#F0D23C"), Virulence = hex("#FFF6B8") },
		Display = {
			Lobe = { GasCore = Color3.fromRGB(40, 36, 36), GasShadow = Color3.fromRGB(175, 30, 30), Gas = Color3.fromRGB(235, 45, 40), GasLit = Color3.fromRGB(250, 90, 90) },
			Particle = { GasCore = Color3.fromRGB(62, 61, 63), GasShadow = Color3.fromRGB(125, 22, 22), Gas = Color3.fromRGB(170, 32, 30), GasLit = Color3.fromRGB(190, 70, 68) },
			Solid = { Liquid = Color3.fromRGB(235, 45, 40), LiquidDeep = Color3.fromRGB(94, 88, 87), LiquidSpec = Color3.fromRGB(255, 255, 193), Membrane = Color3.fromRGB(235, 45, 40), MembraneHi = Color3.fromRGB(255, 200, 50) },
			Neon = { Virulence = Color3.fromRGB(193, 186, 139) },
			Glow = { Virulence = Color3.fromRGB(255, 246, 184) },
		} } }

-- TOXIN'S THIRD WRAP (2026-10-18): Poison Dart Frog, Rare -- a gradient and finish pass. Cobalt gas graded core to
-- edge (deep cobalt heart, bright lit edge: each lobe by its distance out, its halo and smoke fading to the next band),
-- soft black mottling in the body smoke and the bubble's murk, wet glossy liquid and membrane (Finish: Reflectance),
-- every third droplet a yellow-green speckle, Virulence a white-hot pale lime. Display inputs measured on swatches.
SkinCatalog.Skins.PoisonDartFrog = { Id = "PoisonDartFrog", DisplayName = "Poison Dart Frog", Rarity = "Rare", Wrap = "Toxin",
	Label = { hex("#2F55D6"), hex("#10101A"), hex("#D4E63C") },
	Palette = {
		Bands = { Radial = { { 0.25, "GasCore", "GasShadow", "GasCore", "GasShadow" }, { 0.5, "GasShadow", "Gas", "GasShadow", "Gas", Body = true },
				{ 0.8, "Gas", "GasLit", "Gas", "GasLit", Body = true }, { 9, "GasLit", "GasEdge", "GasLit", "GasEdge", Rim = true } },
			Edge = { "GasLit", "GasEdge", "GasLit", "GasEdge", Rim = true }, Mottle = "Mottle", Blotch = true, Speckle = "Speckle",
			Light = "Gas", Glow = "GasCore", Gloss = { Material = "SmoothPlastic", Reflectance = 0.15 },
			Wave = { Body = { "GasShadow", "Gas", "GasShadow", "Gas" }, Lead = { "GasLit", "GasEdge", "GasLit", "GasEdge", Rim = true },
				Blotch = { "Mottle", "Gas", "Mottle", "Gas" } },
			Mark = { Body = { "GasShadow", "Gas", "GasShadow", "Gas" }, Outer = { "GasLit", "GasEdge", "GasLit", "GasEdge", Rim = true },
				Blotch = { "Mottle", "Gas", "Mottle", "Gas" } },
			Skin = { Seed = 11, Blotches = 7, Dots = 16, Light = Vector3.new(-0.4, 0.75, 0.55), Glint = 0.93,
				BaseColor = "Membrane", BlotchColor = "Mottle", DotColor = "Speckle", GlintColor = "LiquidSpec" } },
		Finish = { Membrane = 0.05, MembraneHi = 0.15, Liquid = 0.35 },
		Color = { GasCore = hex("#14267A"), GasShadow = hex("#1B2F8A"), Gas = hex("#2F55D6"), GasLit = hex("#5F8CF2"), GasEdge = hex("#A9C6FF"),
			Liquid = hex("#2A4CC8"), LiquidDeep = hex("#111C5A"), LiquidSpec = hex("#E6F0FF"), Membrane = hex("#3A62E0"), MembraneHi = hex("#CFE0FF"),
			Mottle = hex("#10101A"), Speckle = hex("#D4E63C"), Virulence = hex("#F4FFB8") },
		Display = {
			Lobe = { GasCore = Color3.fromRGB(26, 36, 88), GasShadow = Color3.fromRGB(36, 50, 112), Gas = Color3.fromRGB(70, 96, 175), GasLit = Color3.fromRGB(150, 185, 250), GasEdge = Color3.fromRGB(205, 225, 255), Mottle = Color3.fromRGB(16, 16, 26) },
			Particle = { GasCore = Color3.fromRGB(61, 68, 94), GasShadow = Color3.fromRGB(68, 76, 104), Gas = Color3.fromRGB(86, 104, 162), GasLit = Color3.fromRGB(140, 165, 235), GasEdge = Color3.fromRGB(205, 212, 255), Mottle = Color3.fromRGB(16, 16, 26) },
			Solid = { Liquid = Color3.fromRGB(71, 90, 158), LiquidDeep = Color3.fromRGB(20, 27, 60), LiquidSpec = Color3.fromRGB(235, 241, 249), Membrane = Color3.fromRGB(89, 111, 180), MembraneHi = Color3.fromRGB(217, 226, 243), Speckle = Color3.fromRGB(230, 222, 60) },
			Neon = { Virulence = Color3.fromRGB(185, 193, 139) }, Glow = { Virulence = Color3.fromRGB(244, 255, 184) },
		} } }

-- TOXIN'S FOURTH WRAP (2026-10-19): Blue-Ringed Octopus, Epic -- murky ochre gas graded from a warm umber core to a lit
-- edge (each lobe by its distance out, lit ForceField rims), soft dark rosette lobes, glossy; the bubble a self-lit
-- (Neon) painted membrane with glowing electric-blue rings over dark rosettes; crisp ring motes that shimmer through the
-- cloud, on its ground stain and round the mark (12% over each effect's Default rate, scaled by Graphics Quality /
-- Reduce Enemy VFX / Reduce Flashing); the wrap's glow breathes (2.25 s, +/-15%, held under Reduce Flashing), apart
-- from Virulence's countdown. Every value a proposal.
SkinCatalog.Skins.BlueRingedOctopus = { Id = "BlueRingedOctopus", DisplayName = "Blue-Ringed Octopus", Rarity = "Epic", Wrap = "Toxin",
	Label = { hex("#B88A2E"), hex("#1E90FF"), hex("#2A1E0A") },
	Palette = {
		-- (checkpoint 2) no dark discs: the core a warm mid-umber, the dark rosette only as small ring centres; warm amber
		-- gas whose lit and edge puffs glow (SelfLit: Neon bodies, unlit smoke); bigger glowing ring motes, a separate
		-- crisp ice-blue shimmer and stain rings inside 14% of each effect's Default rate; the pulse on the rings, the
		-- self-lit amber and the membrane
		-- (checkpoint 3) the glow on the round body lobes only (SelfLit GasLit = the middle band, soft); the ground skirt
		-- and the detonation's edge lobes in Default's hazy translucent shades (no coins)
		Bands = { Radial = { { 0.25, "GasCore", "GasShadow", "GasCore", "GasShadow" }, { 0.5, "GasShadow", "Gas", "GasShadow", "Gas", Body = true },
				{ 0.8, "GasLit", "GasEdge", "GasLit", "GasEdge", Body = true }, { 9, "Gas", "GasLit", "Gas", "GasLit" } },
			Edge = { "GasShadow", "GasShadow", "GasShadow", "GasShadow" }, SelfLit = { GasLit = true },
			-- (checkpoint 5) every puff (the cloud's, the mark's, the detonation's) wears the bubble's painted rings: one painted
			-- copy per puff colour (LobeSkin), each puff turned to its own yaw; no ring particles
			LobeSkin = { Seed = 31, Blotches = 0, Dots = 0, Rings = 7, RingSize = 0.26, Res = { 40, 80 }, Smooth = true, Glint = 2,
				Light = Vector3.new(0, 1, 0), RingCentre = "RingSpot", RingInner = "RingHi", RingColor = "Ring", RingEdge = "RingDeep" },
			Pulse = { Period = 2.25, Amp = 0.16 },
			Light = "Gas", Glow = "GasCore", Gloss = { Material = "SmoothPlastic", Reflectance = 0.12 },
			Wave = { Body = { "GasShadow", "Gas", "GasShadow", "Gas" }, Lead = { "Gas", "GasLit", "Gas", "GasLit" },
				Blotch = { "GasShadow", "Gas", "GasShadow", "Gas" } },
			Mark = { Body = { "GasShadow", "Gas", "GasShadow", "Gas" }, Outer = { "Gas", "GasLit", "Gas", "GasLit" },
				Blotch = { "GasShadow", "Gas", "GasShadow", "Gas" } },
			Skin = { Seed = 23, Blotches = 0, Dots = 0, Rings = 12, RingSize = 0.24, Res = { 64, 128 }, Smooth = true, Light = Vector3.new(-0.4, 0.75, 0.55),
				Glint = 2, Material = "Neon", BaseColor = "Membrane", BlotchColor = "Mottle", DotColor = "Ring", GlintColor = "MembraneHi",
				RingCentre = "RingSpot", RingInner = "RingHi", RingColor = "Ring", RingEdge = "RingDeep" } },
		Finish = { Membrane = 0.05, MembraneHi = 0.15, Liquid = 0.35 },
		Color = { GasCore = hex("#7A5A2A"), GasShadow = hex("#9C7232"), Gas = hex("#C8913A"), GasLit = hex("#E0AE55"), GasEdge = hex("#EEC27A"),
			Liquid = hex("#B98530"), LiquidDeep = hex("#6E4F22"), LiquidSpec = hex("#F5E6B8"), Membrane = hex("#C99A3A"), MembraneHi = hex("#F0DCA0"),
			Mottle = hex("#2A1E0A"), RingSpot = hex("#5A3A14"), Ring = hex("#1E90FF"), RingHi = hex("#9AD8FF"), RingDeep = hex("#0A4FB0"), Shimmer = hex("#BFE6FF"),
			Virulence = hex("#D6F2FF") },
		Display = {
			Lobe = { GasCore = Color3.fromRGB(122, 94, 54), GasShadow = Color3.fromRGB(146, 114, 64), Gas = Color3.fromRGB(172, 140, 90),
				GasLit = Color3.fromRGB(112, 92, 58), GasEdge = Color3.fromRGB(190, 168, 124) },
			Particle = { GasCore = Color3.fromRGB(98, 76, 44), GasShadow = Color3.fromRGB(120, 94, 54), Gas = Color3.fromRGB(148, 118, 68),
				GasLit = Color3.fromRGB(164, 136, 86), GasEdge = Color3.fromRGB(180, 156, 112) },
			Solid = { Liquid = Color3.fromRGB(180, 130, 56), LiquidDeep = Color3.fromRGB(110, 80, 36), LiquidSpec = Color3.fromRGB(240, 228, 196),
				Membrane = Color3.fromRGB(116, 86, 38), MembraneHi = Color3.fromRGB(220, 204, 160), Mottle = Color3.fromRGB(40, 28, 12),
				Ring = Color3.fromRGB(40, 150, 255), RingHi = Color3.fromRGB(200, 236, 255), RingDeep = Color3.fromRGB(14, 76, 196),
				RingSpot = Color3.fromRGB(72, 48, 20), Shimmer = Color3.fromRGB(120, 200, 255) },
			Neon = { Virulence = Color3.fromRGB(162, 183, 193) }, Glow = { Virulence = Color3.fromRGB(214, 242, 255) },
		} } }

SkinCatalog.Skins.Bloodmoon = { Id = "Bloodmoon", DisplayName = "Bloodmoon",
	Label = { hex("#5C1C21"), hex("#E84054"), hex("#FFDEE4") },
	Shadow = {
		Color = { Glint = hex("#FFDEE4"), Shade = hex("#E84054"), Dusk = hex("#5C1C21"), Void = hex("#1A0A0B") },
		RevealColor = hex("#FFB0BE"),      -- Eclipse's outline on revealed enemies: pale rose (Default: light purple)
		RibbonA = { Lit = hex("#FFE8DE"),
			light = { Rest = Color3.fromRGB(229, 79, 82), Band = Color3.fromRGB(255, 170, 166), Untextured = hex("#FFECEE") },
			shadow = { Rest = Color3.fromRGB(207, 62, 70), Band = Color3.fromRGB(255, 88, 100), Untextured = hex("#786464") } },
		RibbonB = { Tint = { light = Color3.fromRGB(255, 85, 72), shadow = Color3.fromRGB(255, 84, 66) },
			Gain = { light = 1.21, shadow = 1.58 },
			Untextured = { light = hex("#E84054"), shadow = hex("#5C1C21") } },
		BallBodyTint = Color3.fromRGB(255, 115, 97),
		-- THE MOON (owner, 2026-10-12: "actual bloodmoon appearance" for the spheres): the round balls -- the dart's
		-- charge ball, the hit's core, Eclipse's core -- wear the engine's own sky moon (no upload), cut to its disc and
		-- shaded from a lit limb to a dark one. The dart's stretched head keeps the tinted ball above.
		BallMoon = { Image = "rbxasset://sky/moon.jpg", RectOffset = Vector2.new(10, 8), RectSize = Vector2.new(109, 111),
			Lit = Color3.fromRGB(255, 104, 96), Dark = Color3.fromRGB(140, 30, 42), Rotation = 55 },
		ShadowSkin = hex("#301115"),       -- the decoy's pieces while they travel
		PulseTint = hex("#FFC6CD"),        -- Eclipse's opening pulse
		Grade = { Ambient = Color3.fromRGB(92, 50, 55), OutdoorAmbient = Color3.fromRGB(100, 58, 63),
			AtmosphereColor = Color3.fromRGB(110, 58, 64), AtmosphereDecay = Color3.fromRGB(70, 26, 31),
			TintColor = Color3.fromRGB(232, 154, 163) },
		VignetteTint = Color3.fromRGB(255, 107, 56), EdgeTint = Color3.fromRGB(255, 92, 84),
	},
}

-- RADIANT'S DEVIL SKIN (2026-10-13; designed and rendered in Blender: radiant_devil_skin_2026_10_12). Red and black
-- only, nothing gold. A SKIN, not a wrap (Rework): every Radiant effect drawn in crimson (flat, and its core stays
-- crimson -- CoreLift 0.12, not white-hot), the staff swapped for the devil trident (Staff = "Devil":
-- RadiantDevilStaffData, built by RadiantAnim), and the rework's own forms (horns, bat wings, chains, maws, the pit and
-- the column: RadiantDevilForge, gated on pal.Id == "Devil" by RadiantFX_Staff / RadiantFX_Hand).
SkinCatalog.Skins.Devil = { Id = "Devil", DisplayName = "Devil", Flat = true, CoreLift = 0.12, Staff = "Devil",
	Rework = true, Blurb = "TRIDENT, HORNS, WINGS, HELLFIRE",
	MaxBright = 1.15, LEScale = 0.25,   -- RadiantDraw's strokes: capped glow, so the crimson never clips to pink-white

	Stops = { hex("#7A0C14"), hex("#C8141C"), hex("#FF4A3A"), hex("#C8141C") },
	Label = { hex("#1A1416"), hex("#7A0C14"), hex("#C8141C"), hex("#FF4A3A") } }

-- CRYO'S FROSTBLADE SKIN (2026-10-14; designed and rendered in Blender: cryo_frostblade_skin_2026_10_14, an Uncommon
-- Element Skin). Every Cryo piece an ICE KUNAI in the shipped v2 ice: the shard, Flash Freeze's pierce, Mirror Cage's
-- ice clones of the caster throwing kunai, Cold Momentum's nicks and its Naruto run, Deep Freeze's trap, Blizzard's
-- fence. No palette (Cryo's colours stay its own): the forms are FrostbladeKit's, gated on FrostbladeKit.On.
SkinCatalog.Skins.Frostblade = { Id = "Frostblade", DisplayName = "Frostblade", Rework = true,
	Blurb = "ICE KUNAI, CLONES, THE NARUTO RUN",
	Label = { hex("#1D6FB8"), hex("#5BB8E8"), hex("#BDEBFA"), hex("#3FE0FF") } }

-- CRYO'S FROST LOTUS SKIN (2026-10-15; designed and rendered in Blender: cryo_frostlotus_skin_2026_10_14; an Epic
-- Element Skin -- the tiers swapped with Snow Globe's). Every Cryo piece soft, curved ice LOTUS PETALS in the shipped v2 ice: the petal dart and the M1 hold-and-pluck,
-- Flash Freeze's field of blooms and the rooted body blossoming, the Mirror Cage of full blooms throwing spiralling
-- petals, the lotus prints, Deep Freeze's lotus trap, the petal storm; dew glints and ice glitter (the Rare layer). No
-- palette (Cryo's colours stay its own): the forms are FrostLotusKit's / FrostLotusFX's, gated on FrostLotusKit.On.
SkinCatalog.Skins.FrostLotus = { Id = "FrostLotus", DisplayName = "Frost Lotus", Rework = true, Rarity = "Epic",
	Blurb = "ICE LOTUS PETALS, A BLOSSOMING FREEZE, DEW AND GLITTER",
	Label = { hex("#1D6FB8"), hex("#8FCBEE"), hex("#EEF9FE"), hex("#3FE0FF") } }

-- CRYO'S SNOW GLOBE SKIN (2026-10-15; designed in Blender: cryo_snowglobe_skin_2026_10_15; a Rare Element Skin
-- -- the tiers swapped with Frost Lotus's).
-- "Shake, swirl, settle": a glass snow globe on a base disc -- the M1 a mini globe that cracks into glass slabs and a
-- snow pile, Flash Freeze's base-disc rim with snow billowing up and settling, snowflake prints, Mirror Cage as one giant
-- globe throwing snowflake darts, Blizzard's rim and pines with a settle-to-clear end. Deep Freeze stays the Default. No
-- palette (Cryo's colours stay its own): the forms are SnowGlobeKit's / SnowGlobeFX's, gated on SnowGlobeKit.On.
SkinCatalog.Skins.SnowGlobe = { Id = "SnowGlobe", DisplayName = "Snow Globe", Rework = true, Rarity = "Rare",
	Blurb = "A GLASS SNOW GLOBE: SHAKE, SWIRL, SETTLE",
	Label = { hex("#0F3459"), hex("#1D6FB8"), hex("#DDF3FD"), hex("#3FE0FF") } }
-- CRYO'S FROST DRAGON SKIN (2026-10-15; IN BUILD -- stage 1, the Mirror Cage's curled dragon; its other pieces draw the
-- Default until their stages land). The Mythic top of Cryo's ladder: one lean western dragon of glowing ice crystal across
-- the kit, in Frost Lotus's luminous style; the forms are FrostDragonKit's / FrostDragonFX's, gated on FrostDragonKit.On.
SkinCatalog.Skins.FrostDragon = { Id = "FrostDragon", DisplayName = "Frost Dragon", Rework = true, Rarity = "Mythic",
	Blurb = "A LIVING GLACIER, AWAKE",
	Label = { hex("#0F3459"), hex("#1D6FB8"), hex("#EEF9FE"), hex("#3FE0FF") } }
-- CRYO'S FIRST WRAP (2026-10-15): one flat palette over the Default Cryo shapes, drawn by CryoWrap (IceMagic) -- pale and
-- cyan-leaning with frost white dominant, so it never reads as Toxin's green. Every colour a PROPOSAL until signed off.
SkinCatalog.Skins.MintRime = { Id = "MintRime", DisplayName = "Mint Rime", Rarity = "Uncommon", Wrap = "Cryo",
	Palette = { Main = hex("#2FD4A0"), Shadow = hex("#0A6B55"), Highlight = hex("#BDF5DC"), Accent = hex("#064236") },
	Art = { Shard = "rbxassetid://78556305339431" } }   -- the Blizzard flecks' painted sprite, remapped (tools/make_wrap_sprites.py)
-- CRYO'S SECOND WRAP (2026-10-15): Deep Glacier -- dense old glacier ice, a deep cobalt Main (lightened from the proposed
-- #2F63D6 to keep Default's shadow-to-mid contrast, 3.4 : 1), navy Shadow, periwinkle Highlight, electric-cyan Accent on
-- the small details only. Every colour a PROPOSAL until signed off.
SkinCatalog.Skins.DeepGlacier = { Id = "DeepGlacier", DisplayName = "Deep Glacier", Rarity = "Uncommon", Wrap = "Cryo",
	Palette = { Main = hex("#3570E8"), Shadow = hex("#1E3592"), Highlight = hex("#A8C6FF"), Accent = hex("#3DDCFF"),
		Rest = "Main" },   -- Rest: the Frost Line at rest (the big rings) takes Main, the cyan Accent stays on small details
	Art = { Shard = "rbxassetid://87388121046905" } }
-- CRYO'S THIRD WRAP (2026-10-15, Rare): Black Ice -- ENTIRELY BLACK reflective wet-asphalt ice (owner, v6): black to
-- charcoal SOLID bodies (Slate, wet Reflectance -- this wrap only), neutral white / silver light on the edges, tips,
-- rings, particles and haze; no blue anywhere (the sky's reflection gives the sheen). A gradient from the core to the
-- edge (CryoWrap: Palette.Edge) with a third stop (Tip). Every colour a PROPOSAL until signed off.
SkinCatalog.Skins.BlackIce = { Id = "BlackIce", DisplayName = "Black Ice", Rarity = "Rare", Wrap = "Cryo",
	Palette = { Main = hex("#0A0A0C"), Shadow = hex("#070709"), Highlight = hex("#F2F4F7"), Accent = hex("#E6E9EE"),
		Edge = { Main = hex("#2A2C31"), Shadow = hex("#1A1B1F"), Tip = hex("#F2F4F7") },
		Silver = hex("#C9CDD3"),   -- the luminous sites (particles, haze, trail, glows, rims): never dark
		-- (2026-10-19, the Rare tier's animated particles) every particle over its life: charcoal ice -> a white glint at
		-- 35% -> silver, so the flecks visibly catch the light as they fly; never ends dark. No extra particles
		Life = { hex("#3A3D44"), hex("#F2F4F7"), hex("#C9CDD3"), At = 0.35 },
		-- the SOLID bodies (round 2, material test 2026-10-16): Foil -- the only built-in that keeps a visible, NEUTRAL
		-- highlight on near-black in this game's lighting (its glints); Reflectance 0: on these materials it adds nothing
		-- to black, and on the SpecialMesh pieces it mirrors the blue sky. RimT 0: the cage rims opaque.
		-- (PBR set for the cage plates, once uploaded: Surface = a SurfaceAppearance template in IceMagic, or Variant =
		-- a MaterialVariant name -- textures/wraps/BlackIce_upload_2026_10_15/)
		Solid = { Color = hex("#0A0A0C"), Material = "Foil", Reflectance = 0, RimT = 0 } },
	-- (the Blizzard fleck: the white snow art until the owner uploads IceShard_BlackIce_edge.png -- a black shard with
	-- bright edges; the Flash Freeze discs: near-black Default art until FrostDisc(Light)_BlackIce_speckle.png)
	Art = { Shard = "rbxassetid://122832312371920" } }

-- EPIC: cherry blossom on frost -- rose core to blush edge, a slow glow pulse, sparkle motes (CryoWrap Epic extras)
SkinCatalog.Skins.SakuraFrost = { Id = "SakuraFrost", DisplayName = "Sakura Frost", Rarity = "Epic", Wrap = "Cryo",
	Palette = { Main = hex("#F06BBA"), Shadow = hex("#D94FA0"), Highlight = hex("#FFF0F7"), Accent = hex("#FFD6EC"),
		Edge = { Main = hex("#FFB3DC"), Shadow = hex("#F06BBA"), Tip = hex("#FFD6EC") },
		Glow = true,   -- self-lit: lit pinks turn lavender in this game's blue ambient (CryoWrap Glow)
		-- SOLID petals (v4): the colour-carrying bodies near-opaque (hit-honest: only ground / thin pieces -- the cage
		-- panels, the coat on a body, the encasing ice and the haze keep Default's); the M1 a thicker, denser shard
		Over = { ["FF2.SpikeT"] = 0.45, ["FF2.BaseT"] = 0.4, ["FF2.FloorT"] = 0, ["FF2.DiscT"] = 0,
			["IS2.BodyT"] = 0, ["IS2.TipT"] = 0, ["IS2.Width"] = 0.28, ["IS2.TrailWidth"] = 0.16, ["Look.FrozenFillT"] = 0.3 },
		OpaqueStyles = { "Slab", "Floor", "EncaseBase", "Frost", "Drift", "Print", "Crust",
			"Calm", "Ripple", "Edge", "Crack" }, OpaqueT = 0,   -- (the coat on a body, the encasing ice and the haze: Default's)
		-- the CRYSTALS (v7): translucent glowing light pink -- bright at the base, near-white toward the rim
		StyleT = { Tip = 0.45, Body = 0.45, Base = 0.4, Chunk = 0.45 },
		Crystal = { Base = hex("#F06BBA"), Body = hex("#FFB3DC"), Tip = hex("#FFE3F1"), WarmG = 0.95, WarmB = 0.8 },
		Twin = true,   -- the ground discs drawn twice (their art is ~40 % alpha)
		Pulse = { Period = 2.25, Amp = 0.15, TipDrift = 0.35 },
		Motes = { Impact = 6, Cast = 5, Edge = 8, EdgeLife = 3.5, Zone = 6, ZoneLife = 4, Size = 0.75 } },
	Art = { Shard = "rbxassetid://122832312371920" } }   -- (white snow art for the storm flecks, tinted by the wrap)

-- MYTHIC: the northern lights (v6, 2026-10-17, from real aurora photographs: pastel, luminous green-to-cyan light -- a
-- curtain's sharp bright lower edge fading softly up, vertical rays, dark gaps between). No violet, lilac or blue-violet
-- anywhere; the green a cool emerald (hue ~150), not Toxin's lime. Every value a PROPOSAL until signed off.
-- NOT in ElementWraps until approved.
SkinCatalog.Skins.Aurora = { Id = "Aurora", DisplayName = "Aurora", Rarity = "Mythic", Wrap = "Cryo",
	Palette = { Main = hex("#5CE8A8"), Shadow = hex("#1E9E72"), Highlight = hex("#E6FFF2"), Accent = hex("#C8FFE6"),
		Edge = { Main = hex("#5AD8F2"), Shadow = hex("#5AE6C0"), Tip = hex("#E6FFF2") },
		Silver = hex("#DDFFF0"),   -- (the light pieces: the cage's glowing edges, the lights, the haze -- white-green)
		Glow = true,
		-- the flow: pale mint, emerald, aqua, cyan, pale cyan-white -- pale bright ends, the saturated middle
		Flow = { Stops = { hex("#A6F5D2"), hex("#5CE8A8"), hex("#5AE6C0"), hex("#5AD8F2"), hex("#D6FBFF") },
			Pos = { 0, 0.35, 0.5, 0.65, 1 }, Period = 6, Span = 1.2, Hold = 0.4, DiscGain = 1 },   -- (aqua short: Zephyr's teal)
		Grad = true,   -- crystals, the M1 body, the shatter shards and the cage plates as vertex-colour copies (CryoAurora)
		Tints = { DiscTint = Color3.new(0.82, 1, 0.92), ArtTint = Color3.new(0.5, 0.95, 0.82), PanelTint = hex("#7FEFD0") },
		-- (v8) the floor: a calm base under the crystals -- "a" clear frosted ice, "b" dark glass, "c" an aurora ring
		-- (CryoAurora.FLOORS; in Studio the workspace attribute AuroraFloor overrides it)
		Floor = "b",                                          -- (recommended: crystals brightest, aurora on dark)
		Over = { ["FF2.SpikeT"] = 0.45, ["FF2.BaseT"] = 0.4, ["FF2.FloorT"] = 0.2, ["FF2.DiscT"] = 0.45,
			["IS2.BodyT"] = 0, ["IS2.TipT"] = 0, ["IS2.Width"] = 0.28, ["IS2.TrailWidth"] = 0.16, ["Look.FrozenFillT"] = 0.3,
			["FF2.RimCount"] = 104, ["FF2.RimH"] = { 1.9, 2.9 } },   -- (rim crystals: 80 -> 104 (+30%), x1.17 tall: tops near waist height, hit-honest)
		OpaqueStyles = { "Slab", "Floor", "EncaseBase", "Frost", "Drift", "Print", "Crust",
			"Calm", "Ripple", "Edge", "Crack" }, OpaqueT = 0,
		StyleT = { Tip = 0.45, Body = 0.45, Base = 0.4, Chunk = 0.45 },
		Twin = false,
		Pulse = { Period = 3, Amp = 0.08, TipDrift = 0 },
		Motes = { Impact = 7, Cast = 5, Edge = 8, EdgeLife = 3.5, Zone = 7, ZoneLife = 4, Size = 0.45 },
		Curtains = { Ribbons = 6, Height = 18, Width = 3.6, T = 0.3, Stars = 4, Life = 5, BZLife = 8, FFR = 1.05, BZR = 0.98, CageR = 0.66,
			Patches = 3, FFDisc = 0.85, BZDisc = 0.8, MCDisc = 0.42 } },   -- (Patches: the low haze's rate)
	Art = { Shard = "rbxassetid://122832312371920" } }

local ALL = { "Default", "Rainbow" }
SkinCatalog.Offer = {
	Radiant = { LightLance = ALL, Blessing = ALL, Halo = ALL, PositionTrade = ALL, Benediction = ALL },
	Pyro = { Fireball = { "Default", "AzureFlame" }, Immolate = { "Default", "AzureFlame" },
		EmberRefund = { "Default", "AzureFlame" }, RingofFire = { "Default", "AzureFlame" },
		HeatRush = { "Default", "AzureFlame" }, Detonate = { "Default", "AzureFlame" },
		CinderShield = { "Default", "AzureFlame" }, ScorchingLash = { "Default", "AzureFlame" } },
	Terra = { BoulderShot = { "Default", "ObsidianMagma" }, BulwarkCharge = { "Default", "ObsidianMagma" },
		Bedrock = { "Default", "ObsidianMagma" }, Aftershock = { "Default", "ObsidianMagma" },
		BulwarkWall = { "Default", "ObsidianMagma" }, EarthenTomb = { "Default", "ObsidianMagma" } },
	Umbra = { ShadowDart = { "Default", "Bloodmoon" }, ShadowStep = { "Default", "Bloodmoon" },
		Eclipse = { "Default", "Bloodmoon" }, Mark = { "Default", "Bloodmoon" }, DecoyDouble = { "Default", "Bloodmoon" } },
}

-- the Element each skinned ability belongs to (a Technique's origin)
SkinCatalog.Origin = { LightLance = "Radiant", Blessing = "Radiant", Halo = "Radiant", PositionTrade = "Radiant",
	Benediction = "Radiant", BoulderShot = "Terra", BulwarkCharge = "Terra", Bedrock = "Terra",
	Aftershock = "Terra", BulwarkWall = "Terra", EarthenTomb = "Terra",
	Fireball = "Pyro", Immolate = "Pyro", EmberRefund = "Pyro", RingofFire = "Pyro", HeatRush = "Pyro", Detonate = "Pyro",
	CinderShield = "Pyro", ScorchingLash = "Pyro",
	ShadowDart = "Umbra", ShadowStep = "Umbra", Eclipse = "Umbra", Mark = "Umbra", DecoyDouble = "Umbra" }
-- (RingofFire: the Loadout keys an Ultimate by its name with the spaces taken out)

-- THE WRAPS CARD'S MARK follows the equipped Element (2026-10-10): its own wrap's mark, or a neutral palette
SkinCatalog.WrapIcon = { Radiant = "Stripes", Pyro = "Drop" }

SkinCatalog.Kinds = {
	RadiantLance = "LightLance", RadiantBlessing = "Blessing", RadiantOverflow = "Blessing", RadiantHalo = "Halo",
	RadiantTrade = "PositionTrade",
	RadiantBenediction = "Benediction",
	BoulderChargeStart = "BoulderShot", BoulderShot = "BoulderShot", BulwarkCharge = "BulwarkCharge",
	BulwarkHit = "BulwarkCharge",
}

function SkinCatalog.AbilityOfKind(kind)
	if type(kind) ~= "string" then return nil end
	for prefix, key in pairs(SkinCatalog.Kinds) do
		if string.sub(kind, 1, #prefix) == prefix then return key end
	end
	return nil
end

function SkinCatalog.Attr(ability) return "Skin_" .. tostring(ability) end

--- The skin Ids `ability` of `element` offers (Default only when it has none of its own).
function SkinCatalog.List(element, ability)
	local e = SkinCatalog.Offer[element]
	return (e and e[ability]) or { "Default" }
end

function SkinCatalog.Allowed(element, ability, id)
	for _, s in ipairs(SkinCatalog.List(element, ability)) do
		if s == id then return true end
	end
	return false
end

--- The gate: whether `player` may wear `skinId`. Every skin is unlocked for everyone for now.
function SkinCatalog.OwnsSkin(player, skinId)
	return SkinCatalog.Skins[skinId] ~= nil
end

-- SKINS (2026-10-13): a whole Element's rework -- new forms, new staff, its own palette -- chosen ONCE per Element
-- (attribute ElementSkin_<Element>), not per ability. Picked on the Loadout's SKINS page (LoadoutRequest
-- "ElementSkin"). While one is on, every ability of that Element draws it.
-- WRAPS ON SKINS (2026-10-14): a colour wrap may be worn OVER a skin. The skin keeps its forms (shapes, staff, forged
-- pieces); the wrap gives the colours. Chosen() then answers "<Skin>+<Wrap>" (e.g. "Devil+Rainbow") and Resolve() turns
-- that into one palette: the wrap's colours with the skin's Id, so every form gate (pal.Id == "Devil") still holds, and
-- .Wrap / .Skin naming the two. A wrap with its own material code (Terra's, Pyro's, Umbra's) does not go over a skin.
SkinCatalog.ElementSkins = { Radiant = { "Default", "Devil" }, Cryo = { "Default", "Frostblade", "SnowGlobe", "FrostLotus", "FrostDragon" } }
-- (each list runs up the rarities, as the Loadout shows it: Default first, then Uncommon, Rare, Epic, Mythic last)

function SkinCatalog.ElementSkinAttr(element) return "ElementSkin_" .. tostring(element) end

function SkinCatalog.ListElementSkins(element)
	return SkinCatalog.ElementSkins[element] or { "Default" }
end

function SkinCatalog.ElementSkinAllowed(element, id)
	return table.find(SkinCatalog.ListElementSkins(element), id) ~= nil
end

--- `player`'s skin for `element`, validated ("Default" when none is on, or it is not theirs to wear).
function SkinCatalog.ElementSkin(player, element)
	if not player or not element then return "Default" end
	local id = player:GetAttribute(SkinCatalog.ElementSkinAttr(element))
	if type(id) ~= "string" or not SkinCatalog.ElementSkinAllowed(element, id) or not SkinCatalog.OwnsSkin(player, id) then
		return "Default"
	end
	return id
end

-- AN ELEMENT'S COLOUR WRAP (2026-10-15, Cryo first): one per Element, worn over the Default shapes or over the Element's
-- skin (CryoWrap paints the skin's pieces). Attribute ElementWrap_<Element>, set through the "ElementWrap" request.
SkinCatalog.ElementWraps = { Cryo = { "Default", "MintRime", "DeepGlacier", "BlackIce", "SakuraFrost" },
	Toxin = { "Default", "Nightshade", "CoralSnake", "PoisonDartFrog" } }   -- (Nightshade, Coral Snake, Poison Dart Frog approved 2026-10-18)
function SkinCatalog.ElementWrapAttr(element) return "ElementWrap_" .. tostring(element) end
function SkinCatalog.ElementWrapAllowed(element, id)
	if id == "Default" then return true end
	local w = SkinCatalog.Skins[id]
	if not (w and w.Wrap == element) then return false end
	for _, v in ipairs(SkinCatalog.ElementWraps[element] or {}) do if v == id then return true end end
	return false
end
--- The wrap `player` wears on `element` ("Default": none)
function SkinCatalog.ElementWrap(player, element)
	if not player or not element then return "Default" end
	local id = player:GetAttribute(SkinCatalog.ElementWrapAttr(element))
	if type(id) ~= "string" or not SkinCatalog.ElementWrapAllowed(element, id) or not SkinCatalog.OwnsSkin(player, id) then
		return "Default"
	end
	return id
end

--- Whether wrap `wrapId` can be worn over a skin: a colour wrap (Stops), not one with its own material code.
function SkinCatalog.WrapsOverSkin(wrapId)
	local w = SkinCatalog.Skins[wrapId]
	return w ~= nil and w.Stops ~= nil and not w.Rework
end

--- A chosen Id split into (skin, wrap): "Devil+Rainbow" -> "Devil", "Rainbow"; a plain Id -> (Id, nil).
function SkinCatalog.Split(id)
	if type(id) ~= "string" then return id, nil end
	local s, w = string.match(id, "^([^+]+)%+(.+)$")
	if s then return s, w end
	return id, nil
end

--- `player`'s chosen skin for `ability`, validated (Default when it is not theirs to wear): their wrap for it, their
--- Element's skin, or both as "<Skin>+<Wrap>" (a colour wrap worn over the skin).
function SkinCatalog.Chosen(player, ability)
	if not player then return "Default" end
	local origin = SkinCatalog.Origin[ability]
	if not origin or player:GetAttribute("Element") ~= origin then return "Default" end
	local full = SkinCatalog.ElementSkin(player, origin)
	local id = player:GetAttribute(SkinCatalog.Attr(ability))
	if type(id) ~= "string" or not SkinCatalog.Allowed(origin, ability, id) or not SkinCatalog.OwnsSkin(player, id) then
		id = "Default"
	end
	if full ~= "Default" then
		if id ~= "Default" and SkinCatalog.WrapsOverSkin(id) then return full .. "+" .. id end
		return full
	end
	return id
end

-- PALETTES: At(u) the colour at u in 0..1 along the bands; Seq(u0, u1) the smooth ColorSequence over that stretch
-- (cached per 1/64 step, so a frame builds none)
local palettes = {}
local Q = 64

local function makePalette(skin)
	local stops = skin.Stops
	local n = #stops
	local p = { Id = skin.Id, Flat = skin.Flat == true, Stops = stops, _seq = {}, CoreLift = skin.CoreLift, Staff = skin.Staff,
		MaxBright = skin.MaxBright, LEScale = skin.LEScale }
	function p.At(u)
		u = math.clamp(u, 0, 1) * (n - 1)
		local i = math.floor(u)
		if i >= n - 1 then return stops[n] end
		return stops[i + 1]:Lerp(stops[i + 2], u - i)
	end
	function p.Seq(u0, u1)
		local q0, q1 = math.floor(math.clamp(u0, 0, 1) * Q + 0.5), math.floor(math.clamp(u1, 0, 1) * Q + 0.5)
		local key = q0 * (Q + 1) + q1
		local s = p._seq[key]
		if s then return s, key end
		local a, b = q0 / Q, q1 / Q
		local kp = { ColorSequenceKeypoint.new(0, p.At(a)) }
		-- a stop inside the stretch keeps its place, so the blend runs through it, not past it
		local lo, hi = math.min(a, b), math.max(a, b)
		for k = 1, n - 2 do
			local su = k / (n - 1)
			if su > lo + 1e-3 and su < hi - 1e-3 then
				kp[#kp + 1] = ColorSequenceKeypoint.new((su - a) / (b - a), stops[k + 1])
			end
		end
		kp[#kp + 1] = ColorSequenceKeypoint.new(1, p.At(b))
		if #kp > 2 and b < a then
			table.sort(kp, function(x, y) return x.Time < y.Time end)
		end
		s = ColorSequence.new(kp)
		p._seq[key] = s
		return s, key
	end
	return p
end

--- The palette `ability` of `element` draws with under skin `id`, or nil for Default (draw exactly as before).
function SkinCatalog.Resolve(element, ability, id)
	if type(id) ~= "string" or id == "Default" then return nil end
	local s, w = SkinCatalog.Split(id)
	if w then                                                         -- a wrap worn over a skin (Chosen: "<Skin>+<Wrap>")
		if not SkinCatalog.ElementSkinAllowed(element, s) then return nil end
		if not (SkinCatalog.Allowed(element, ability, w) and SkinCatalog.WrapsOverSkin(w)) then
			return SkinCatalog.Resolve(element, ability, s)
		end
		local p = palettes[id]
		if p then return p end
		local sk, wr = SkinCatalog.Skins[s], SkinCatalog.Skins[w]
		if not sk then return nil end
		-- the skin's forms and staff, the wrap's colours (and its own tone: core lift, glow cap)
		p = makePalette({ Id = s, Flat = wr.Flat, Stops = wr.Stops, CoreLift = wr.CoreLift, Staff = sk.Staff,
			MaxBright = wr.MaxBright, LEScale = wr.LEScale })
		p.Skin, p.Wrap, p.Key = s, w, id
		palettes[id] = p
		return p
	end
	if not (SkinCatalog.Allowed(element, ability, id) or SkinCatalog.ElementSkinAllowed(element, id)) then return nil end
	local skin = SkinCatalog.Skins[id]
	if skin and (skin.Stages or skin.Flame or skin.Shadow) then return skin end   -- a material wrap (Terra's): its data, drawn by the Element's own code
	if not (skin and skin.Stops) then return nil end
	local p = palettes[id]
	if not p then
		p = makePalette(skin)
		palettes[id] = p
	end
	return p
end

-- THE SKIN HUD SETS (2026-10-14): a full skin's HUD layer -- its ability icons (IconAssets.Ability.Skins[Id]) and its
-- status-bar looks (BarFX variant ids by status kind) -- shown only while that skin is the player's own Element skin, so
-- Default is untouched. A status bar wears the CASTER's skin: the server stamps it on the status as RX_<Status>_Skin.
SkinCatalog.Hud = {
	-- e.g. Skin = { Element = "Cryo", Bar = { chill = "xx" } }
	-- (Snow Globe, now Rare, has no HUD set: its icon art stays in IconAssets.Ability.Skins.SnowGlobe, unmapped)
	FrostLotus = { Element = "Cryo" },        -- (Epic; its icons: IconAssets.Ability.Skins.FrostLotus; no bar accent)
	FrostDragon = { Element = "Cryo" },       -- (Mythic; its icons: IconAssets.Ability.Skins.FrostDragon; bar accent not in yet)
}

--- The HUD set `player` wears for `element` ("Default" when none): their Element skin while `element` is their own
--- Element, if that skin has a HUD set. STUDIO ONLY: the attribute HudSkinPreview_<Element> (set it on the server, so
--- the client and the server's Chill stamp both see it) previews a set nobody can own yet.
function SkinCatalog.HudSkin(player, element)
	if not player or not element or player:GetAttribute("Element") ~= element then return "Default" end
	local id
	if RunService:IsStudio() then
		local pv = player:GetAttribute("HudSkinPreview_" .. element)
		if type(pv) == "string" and SkinCatalog.Hud[pv] and SkinCatalog.Hud[pv].Element == element then id = pv end
	end
	id = id or SkinCatalog.ElementSkin(player, element)
	return SkinCatalog.Hud[id] and id or "Default"
end

--- The BarFX look id a status stamped with `skin` wears for `kind` (nil: the player's own pick).
function SkinCatalog.HudBar(skin, kind)
	local h = SkinCatalog.Hud[skin]
	return h and h.Bar and h.Bar[kind] or nil
end

return SkinCatalog
