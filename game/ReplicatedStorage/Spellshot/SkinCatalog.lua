--[[
	SkinCatalog  (ModuleScript)  ->  ReplicatedStorage/Spellshot/SkinCatalog

	The ability skins (2026-10-10, the first slice of the reskin system). No timing, damage, range, hitbox or
	hit-feedback value reads anything here. (2026-10-19, audit P5C-15 / P5F-20) "colour only" holds for the per-ability
	colour wraps alone: an Element SKIN (Rework = true: Devil, Frostblade, Frost Lotus, Snow Globe, Frost Dragon) replaces
	the FORMS as well -- shapes, staff, forged pieces -- and some Cryo wraps also change opacity and the shard's drawn width
	(Palette.Over / OpaqueStyles, audit P5A-18). What the opponent sees can therefore differ by cosmetic.

	  Skins     every skin: Id, DisplayName, and for a coloured one its palette (Stops, in order). Flat is carried onto
	            the palette (p.Flat) but no draw code reads it today: RadiantDraw tones a skin's strokes with MaxBright /
	            LEScale instead (it was meant as "drawn alpha-blended, not additive")
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
	-- (2026-10-25) UNCOMMON, and an ELEMENT wrap like Umbra's (2026-10-19) and Pyro's (2026-10-24): Rarity / Wrap set,
	-- worn on every Radiant ability through the caster's one ElementWrap_Radiant (Studio: WrapStudio on the character),
	-- its per-ability Offer rows gone. Its tone is untouched (no CoreLift / MaxBright / LEScale: the faint, white-hot
	-- pastel look the owner may revisit separately). Palette is the WRAPS card's four swatches only.
	Rainbow = { Id = "Rainbow", DisplayName = "Rainbow", Flat = true, Rarity = "Uncommon", Wrap = "Radiant",
		Stops = { hex("#FF4545"), hex("#FF8F1F"), hex("#FFE81F"), hex("#36E06A"), hex("#3B99FF"), hex("#A954FF") },
		Palette = { Main = hex("#3B99FF"), Shadow = hex("#A954FF"), Highlight = hex("#FFE81F"), Accent = hex("#FF4545") } },
	-- TERRA'S FIRST WRAP (2026-10-10): black volcanic glass in three flat bands, a thin pale highlight on its sharpest
	-- facet edges, the ink, and magma fissures -- three hard layers and a soft halo, the one glowing thing. Drawn by
	-- TerraWrap. EVERY VALUE IS A PROPOSAL. Stage Bands are half-widths in studs on the full-size rock, centre out,
	-- before each fissure's taper; Halo = { base, + per CrackGlow }. Neon pushes orange to yellow, so the Neon inputs sit
	-- a little redder than the target hexes in Crack.
	-- (2026-10-25) UNCOMMON, and an ELEMENT wrap like Umbra's (2026-10-19), Pyro's and Radiant's: Rarity / Wrap set, worn
	-- through the caster's one ElementWrap_Terra (Studio: a WrapStudio attribute on the caster) on all six abilities, as
	-- before; its per-ability Offer rows are gone. Still live (ElementWraps.Terra), as it was. Palette is the WRAPS card's
	-- four swatches only: TerraWrap / ChargedRock / TerraFX draw from Rock, Stages, Seam and Tint.
	ObsidianMagma = { Id = "ObsidianMagma", DisplayName = "Obsidian Magma", Rarity = "Uncommon", Wrap = "Terra",
		Palette = { Main = hex("#4A3E5E"), Shadow = hex("#2A2236"), Highlight = hex("#FF7A1A"), Accent = hex("#E5231B") },
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
		HitFlash = hex("#FF9A3A"),   -- (2026-10-25: was #CCBA5C, Terra's own tan Light -- the impact flashed Default gold; now a magma ember)
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
		-- (2026-10-25, fix pass) THE BAKED KITS' STONE (Wall, Tomb, Aftershock, and the Tomb's debris and chips): the owner
		-- wants them glassy black volcanic rock, not the maroon bake under Tint. ChargedRock puts each piece on a shared
		-- greyscale copy of its mesh (the bake's grain kept as light / dark, x0.55-1.0) and colours it from Stone; Tint
		-- above stays what a piece draws until its copy is built. Tones are ON-SCREEN targets on lit SmoothPlastic, bottom
		-- to top, one per Band studs of the kit: faint black-violet flow bands. An Uncommon recolour: no Pieces, no
		-- material, no Reflectance (a near-black mirror reads sky-blue); the glass is SmoothPlastic's own sheen on the
		-- near-black, the molten red is the seams' (Seam), as before. (guard: nothing darker than #2E2A38, whose darkest
		-- grain holds 14 off Umbra Dark #0D0817 -- the first draft's #2A2434 at x0.52 landed 11 from it)
		Stone = { Tones = { hex("#322C3C"), hex("#3C3448"), hex("#2E2A38"), hex("#40384E") }, Band = 1.4, Jitter = 0.05,
			Kits = { TerraWall2 = true, TerraTomb2 = true } },
		-- the comic TerraBurst (every Bulwark clink, knockdown and plate drop; Default's Terra-Light tan): molten orange,
		-- the Ember above. Fill only: Default's burst is ONE particle in one colour, and an Edge makes VFXLibrary draw a
		-- second, larger burst behind it -- an extra particle and a second shade, both above Uncommon (a flat recolour,
		-- particle delta 0). (guard: 30 off Pyro Base #F25C0D; it was the Ember #FF7A1A, nudged bluer while an Edge blend
		-- was guarded against it)
		Burst = { Fill = hex("#FF7A22") },
		-- (2026-10-25, fix pass) its dust too: volcanic ash, not Default tan (Bulwark footfalls, the Boulder's gather / trail /
		-- impact clouds, the Wall / Tomb / Aftershock puffs)
		Dust = { Light = hex("#6E6478"), Dark = hex("#3E3646"), Pale = hex("#8C8296") },
	},
}

-- (2026-10-25) TERRA'S LADDER, staged for the owner's review: NOT selectable (commented out of ElementWraps.Terra)
-- until approved. Every value a proposal. Drawn like Obsidian Magma -- TerraWrap from Rock / Stages / HaloEdge (the
-- Boulder Shot cells and pebbles, the Bulwark / Bedrock plates), ChargedRock from Tint / Seam (Aftershock, Bulwark Wall,
-- Earthen Tomb) -- plus the tier fields only these four carry (Dust, Scuff; Veins, Facets, Crystals, Pulse, Flow,
-- Layers, Streak), each read only when present, so Default and Obsidian Magma draw exactly as before. Stage Bands,
-- Seam, Crystals and Underlay are Neon INPUTS (about half the on-screen target); Crack documents the targets; Label and
-- Palette are the WRAPS card's swatches only. Every colour, every product (RockTint / LitTint, the Wall / Tomb bake x
-- Tint, Aftershock's white tops x Tint, Flow x Pulse, crystal Glow x Pulse) and 21 steps of every blend clear the 12/255
-- guard against all nine Elements' Base / Light / Dark; no magenta. (guard: ...) notes log each value moved for it. The
-- exceptions, FLAGGED at each Tint: Terra's own baked earth (Aftershock's plate walls and rocks, the Tomb's clod) under
-- a few of the tints, where no tint in the wrap's colour clears it.
-- SANDSTONE, Uncommon: pale rosy-peach desert sand (paler and pinker than Terra's olive-gold), matte; its fissures a
-- soft sun-warmed peach-amber, still charge-readable. A recolour only: the dust and scuffs take the sand too (Dust,
-- Scuff); nothing added, no pulse. Wall / Tomb tints can only darken their maroon bake: a pale tan is unreachable there.
SkinCatalog.Skins.Sandstone = { Id = "Sandstone", DisplayName = "Sandstone", Rarity = "Uncommon", Wrap = "Terra",
	Palette = { Main = hex("#D9B48E"), Shadow = hex("#8E6650"), Highlight = hex("#FFE6C8"), Accent = hex("#F0A060") },
	Label = { hex("#E8C8A4"), hex("#C99E78") },
	Rock = { Shadow = hex("#9C7458"), Mid = hex("#D4AC88"), Lit = hex("#F0D4B4") },   -- (checkpoint 1: read tan-brown; paler)
	RockTint = Color3.new(0.92, 0.9, 0.88),
	LitTint = 0.9,
	-- (guard: the warm darks sat on Terra Dark #33210D. Rim, HaloEdge, the Low / Mid HaloCol and Seam.Dead now carry
	-- blue >= 26 -- a hair rosier -- so neither they nor any halo or heal blend through them comes within 12 of it)
	Rim = hex("#3A241A"),   -- (a pale rock needs a DARK silhouette rim; guard: was #3A2418)
	Highlight = hex("#FFF2E3"), HighlightWidth = 0.05, HighlightEdges = 2,   -- (guard: #FFF2DE sat 8 from Radiant Light #FFF7D6)
	Ink = hex("#261A12"), InkWidth = 0.04,   -- (guard: was #2A1A12, 9 from Terra Dark)
	Crack = { Outer = hex("#C8703C"), Middle = hex("#F0A060"), Core = hex("#FFE6C0") },
	CrackGlow = 0.6,
	CrackGlowOwn = 0.8,
	HaloEdge = hex("#6A5A4A"),   -- (checkpoint 3: #6A5A4A renders as the lit sand itself; checkpoint 2: #8A6A52; was #2A161A, which outlined every crack in black; guard: was #2A160C)
	Stages = {
		Low = { Bands = { { 0.012, hex("#605448") }, { 0.026, hex("#54483C") } }, Halo = { 0.012, 0.03 },
			HaloCol = hex("#6A5A4A"), Seam = hex("#54483C"), Light = 0.3 },   -- (guard: HaloCol was #3A2012)
		Mid = { Bands = { { 0.014, hex("#7A7064") }, { 0.03, hex("#605244") } }, Halo = { 0.012, 0.03 },
			HaloCol = hex("#6A5A4A"), Seam = hex("#6A5A4A"), Light = 0.6 },   -- (guard: HaloCol was #4E2A16)
		Max = { Bands = { { 0.016, hex("#8C8276") }, { 0.036, hex("#6A5A4A") } }, Halo = { 0.012, 0.035 },   -- (checkpoint 2: a cream crack fading into the sand -- no burnt outline)
			HaloCol = hex("#6A5A4A"), Seam = hex("#8C8276"),   -- (checkpoint 3: near-neutral inputs: Neon renders them cream, not orange)
			 Light = 1.0 },
	},
	SeamOff = hex("#5A4030"),
	Light = hex("#FFE2C0"),
	HitFlash = hex("#FFD8B0"),
	Ember = hex("#E89A60"), Grit = { hex("#C9A07A"), hex("#8E6650") },
	Dust = { Light = hex("#D2B496"), Dark = hex("#9A7660"), Pale = hex("#E4CCB0") },
	Scuff = hex("#C9A07A"),
	-- (guard: TerraTomb2 was (1, 0.9, 0.8), as the Wall's -- the Tomb's clod (ET_SlabClod, Terra's baked soil) sat 10 from
	-- Terra Dark on its darker faces (x0.93); a rosier tint there, its caps a shade pinker than the Wall's)
	-- FLAGGED, not fixed: Aftershock's plates bake Terra's own soil on their walls, and under any sand tint the darker
	-- soil lands 3-5 from Terra Dark. Clearing it needs red <= 0.56 (Default's own PlateTop tan) or green <= 0.42 / blue
	-- >= 0.89 (pink or lavender plate tops): the owner's call
	Tint = { TerraWall2 = Color3.new(1, 0.9, 0.8), TerraTomb2 = Color3.new(1, 0.81, 0.89),
		TerraAftershock = Color3.new(0.8, 0.66, 0.52) },
	Seam = { Ember = hex("#54483C"), Hot = hex("#8C8276"), Inner = hex("#B0906C"), Dead = hex("#8A6E54") },   -- (checkpoint 8: Inner / Dead sand-brown: a dark Dead drew black cracks all over the Wall)   -- (checkpoint 7: the Wall / Tomb seams lit orange-red; the cracks' cream)   -- (guard: Dead was #3A2418)
	Underlay = hex("#6A5A4A"), UnderlayHot = hex("#8C8276"),   -- (checkpoint 7: Aftershock's Neon underlay read as lava; cream)
	-- (2026-10-25, fix pass) THE BAKED KITS' STONE (Obsidian Magma's Stone has the mechanism): the light tan / beige
	-- LAYERED sedimentary stone the Tint could never reach -- four strata tones, on-screen targets, cycling every 0.9 stud
	-- up the kit (about nine courses on the 8.4-stud Wall). Still a matte Uncommon recolour: no Pieces, no material.
	-- (guard: blue >= 116 holds every tone 29+ off Terra Light #CCBA5C; the darkest's x0.53 grain holds 26 off Terra Base)
	Stone = { Tones = { hex("#E0A870"), hex("#EAB884"), hex("#D49C64"), hex("#F0C490") }, Band = 0.9, Jitter = 0.04,   -- (checkpoint 9: more saturated -- the sky ambient on the Wall's vertical faces turned the pale tones grey #64686C; only the saturated one stayed tan)   -- (checkpoint 8: warmer and lighter -- the Wall's shaded faces read grey)
		Kits = { TerraWall2 = true, TerraTomb2 = true } },
	-- the comic TerraBurst: pale sand (Palette Highlight). Fill only, as Obsidian Magma's: an Edge is a second burst
	-- particle, above Uncommon
	Burst = { Fill = hex("#FFE6C8") },
}
-- RUSTED IRON ORE, Rare: dull grey-brown stone with rust-orange veins bleeding short rust streaks down the rock (Veins),
-- two raw steel facets per cell (Facets: Metal on MEDIUM and up, else plain), a restrained forge rust-orange glow in
-- the cracks, and rust flecks shed at +7% of every Default site (Layers). No pulse, no flow.
SkinCatalog.Skins.RustedIronOre = { Id = "RustedIronOre", DisplayName = "Rusted Iron Ore", Rarity = "Rare", Wrap = "Terra",
	Palette = { Main = hex("#625850"), Shadow = hex("#3C3430"), Highlight = hex("#C0561E"), Accent = hex("#A9B0B8") },
	Label = { hex("#C0561E"), hex("#8A8078") },
	Rock = { Shadow = hex("#3A302A"), Mid = hex("#54463C"), Lit = hex("#746252") },   -- (pass 3: dark rusted iron -- the mid grey-brown read flat beside Magma's near-black)   -- (checkpoint 6: a mid grey-brown -- #806A56 lit read dark brown; checkpoint 4 white was the face-sized facets, not the stone)   -- (checkpoint 1: read near-black; lighter)
	RockTint = Color3.new(0.88, 0.86, 0.84),
	LitTint = 0.88,
	Rim = hex("#D8DCE0"),
	Highlight = hex("#C8CCD0"), HighlightWidth = 0.05, HighlightEdges = 2,
	Ink = hex("#141512"), InkWidth = 0.04,   -- (guard: #141012 sat 8 from Umbra Dark #0D0817)
	Crack = { Outer = hex("#D86A20"), Middle = hex("#F58A30"), Core = hex("#FFD098") },   -- (pass 3: molten orange to yellow-white, not Magma's red)
	CrackGlow = 0.6,
	CrackGlowOwn = 0.8,
	-- (guard: the halo's dark rust blends crossed Terra Dark #33210D. Kept below green 21 while red passes 39-63: the
	-- HaloEdge a redder black, the Mid / Max HaloCol a touch redder)
	HaloEdge = hex("#6A5C50"),   -- (checkpoint 2: was #1A080C, a black outline that read as burnt lava cracks; guard: was #1A100C)
	Stages = {
		Low = { Bands = { { 0.02, hex("#D88838") }, { 0.05, hex("#B86A28") } }, Halo = { 0.015, 0.05 },
			HaloCol = hex("#4A3A2E"), Seam = hex("#B86A28"), Light = 0.35 },   -- (pass 3: light warm inputs, dark warm Neon renders red here; the stone-coloured halo kept, narrower than Magma's)
		Mid = { Bands = { { 0.04, hex("#F08A38") }, { 0.07, hex("#C86A28") } }, Halo = { 0.02, 0.1 },
			HaloCol = hex("#5A4434"), Seam = hex("#E07A30"), Light = 0.7 },   -- (guard: HaloCol was #3A160A)
		Max = { Bands = { { 0.03, hex("#FFB868") }, { 0.06, hex("#F08830") }, { 0.09, hex("#C86418") } }, Halo = { 0.03, 0.14 },   -- (pass 3: molten gold-orange bands; a narrower halo than Magma's)   -- (checkpoint 2: thin dim copper lines -- the veins carry the look)
			HaloCol = hex("#6A503A"), Seam = hex("#F58A30"),   -- (checkpoint 4: this place's Neon turns a dark warm input saturated red -- amber-copper inputs, a stone-coloured halo edge)
			 Light = 1.1 },   -- (guard: HaloCol was #5A2410)
	},
	SeamOff = hex("#2A2220"),
	Light = hex("#FF8A4A"),
	HitFlash = hex("#FFB080"),
	Ember = hex("#E8742C"), Grit = { hex("#625850"), hex("#3C3430") },
	Dust = { Light = hex("#8A7A6C"), Dark = hex("#5A4C42"), Pale = hex("#A89888") },
	Scuff = hex("#7A5A48"),
	Veins = { PerArea = 1.0, Width = 0.09, Core = hex("#D88A3E"), Edge = hex("#B4703A"),   -- (checkpoint 4: lit plastic still drew the edge dark; ochre-orange both)
		   -- (checkpoint 1: barely read; wider, denser)
		 Kink = 1, Branch = 0.5,
		Steps = { 4, 6 }, Seed = 4211,
		Streak = { Chance = 0.9, Length = { 0.3, 0.7 }, Width = 0.05, Core = hex("#C47A3A"), Edge = hex("#A06438") } },
	Facets = { Count = 2, Inset = 0.45, Color = hex("#C8CED6"),   -- (checkpoint 5: a small steel patch in each face; at the full face (Inset 0.92) the rock read as sheet metal)
		 Material = "Metal", Reflectance = 0.08, MinQ = 0.75 },
	Layers = {
		{ Name = "RustFleck", Kind = "Fleck", Texture = "Grit", Color = { hex("#C0561E"), hex("#7A3418"), hex("#3C3430") },
			Size = { 0.2, 0.08 }, Life = { 0.6, 1.2 }, Speed = { 1, 4 }, Drag = 2, Accel = Vector3.new(0, -8, 0),
			LightEmission = 0, LightInfluence = 1,
			Share = { Hold = 0.04, Flight = 0.04, Impact = 0.04, Plate = 0.04, Wall = 0.04, Tomb = 0.04, Aftershock = 0.04 } },
		-- (pass 3) hot slag chips: lit (a Rare's particles never glow), orange cooling to iron -- the animated layer
		-- (with RustFleck, 8% of Default)
		{ Name = "SlagChip", Kind = "Fleck", Texture = "Grit", Color = { hex("#FFC070"), hex("#E08A38"), hex("#5A4A40") },
			Size = { 0.16, 0.05 }, Life = { 0.5, 1.0 }, Speed = { 3, 7 }, Drag = 1.5, Accel = Vector3.new(0, -14, 0),
			LightEmission = 0, LightInfluence = 1,
			Share = { Hold = 0.04, Flight = 0.04, Impact = 0.04, Plate = 0.04, Wall = 0.04, Tomb = 0.04, Aftershock = 0.04 } },
	},
	-- the maroon Wall / Tomb body reads as dark oxide, the tan caps go rust-orange-brown. (guard: red was 0.85 -- the
	-- kit's cap #CCBA5C at its darkest grain (x0.82) landed 12 from Terra Base #826B24)
	-- (guard: TerraAftershock was (0.42, 0.38, 0.36) -- the plates' baked soil walls and the rocks' broken stone landed
	-- 9 from Terra Dark; a shade darker, the plate tops now Rock Mid's grey-brown)
	-- FLAGGED, not fixed: the Tomb's clod (ET_SlabClod, Terra's baked soil) x TerraTomb2 lands 4-6 from Terra Dark; no
	-- rust tint clears it (green <= 0.45 with red 1: vivid orange caps): the owner's call
	Tint = { TerraWall2 = Color3.new(0.86, 0.62, 0.55), TerraTomb2 = Color3.new(0.86, 0.62, 0.55),
		TerraAftershock = Color3.new(0.21, 0.17, 0.15) },   -- (pass 3: dark rusted iron plates: the flat grey dome had no contrast)
	Seam = { Ember = hex("#B05E24"), Hot = hex("#FFA048"), Inner = hex("#3C3430"), Dead = hex("#2A2220") },   -- (pass 3: molten orange seams on the Wall / Tomb)   -- (checkpoint 7: red on the Wall / Tomb; the fissures' amber-copper)
	Underlay = hex("#C86418"), UnderlayHot = hex("#F0B060"),   -- (pass 3 on screen: #C89048 rendered yellow #F5D918, toward Default's gold; Magma's own rim input lands orange)   -- (pass 3: amber-orange fissures, a gold hot rim -- Magma's are red / orange; light warm inputs so the heal never passes red)   -- (checkpoint 7: Aftershock's underlay read as lava; copper)
	-- (2026-10-25, fix pass) THE BAKED KITS' STONE (mechanism at Obsidian Magma's Stone): dark grey-brown iron strata,
	-- and the Rare texture -- by piece, rust-orange patina, old darker rust, and raw iron (Metal; a mid grey, so the small
	-- Reflectance reads as a sheen, not a sky mirror). Shares are of all the kit's pieces; the rest take the strata.
	-- (guard: the old rust was #7E4630 -- its x0.51 grain held only 13 off Terra Dark #33210D; a shade lighter, 17)
	Stone = { Tones = { hex("#5E5650"), hex("#6A605A"), hex("#544C48"), hex("#766A62") }, Band = 1.2, Jitter = 0.08,   -- (pass 3: darker iron, the patina pieces carry the rust)   -- (checkpoint 8: lighter -- shaded faces read navy)
		Pieces = {
			{ Share = 0.2, Tone = hex("#D08850") },   -- rust-orange patina (checkpoint 9: #C0642E graded to blood red #4A0100 in shade)
			{ Share = 0.12, Tone = hex("#A87048") },   -- old rust, darker (checkpoint 9: was #9A5A38)
			{ Share = 0.1, Tone = hex("#A89484"), Material = "Metal", Reflectance = 0 },   -- raw iron (checkpoint 9: #8C9096 mirrored the sky navy; warmer, no Reflectance)
		},
		Kits = { TerraWall2 = true, TerraTomb2 = true } },
	Burst = { Fill = hex("#FFB080"), Edge = hex("#C0561E") },   -- a forge-hot clink, a rust edge (HitFlash, Highlight)
}
-- AMETHYST GEODE, Epic: a grey chalcedony shell split by violet light; faceted violet crystal clusters burst out of it
-- (Crystals: Neon, hard face steps, pale lilac tips, never a hitbox); a slow 2.25 s breath on the crystals, fissures and
-- the light (Pulse); violet shimmer motes at +12% (Layers). Blue-violet inputs throughout: a redder violet ramp passes
-- through Umbra's Base / Light and Voltaic / Toxin's Dark, and the render reads violet bluer still -- recheck on screen
-- and redden only where the guard allows. The darks under the glow are NEUTRAL near-blacks, not violet-blacks.
SkinCatalog.Skins.AmethystGeode = { Id = "AmethystGeode", DisplayName = "Amethyst Geode", Rarity = "Epic", Wrap = "Terra",
	-- (guard: Main was #8A5CE8 -- the card's Highlight -> Main name gradient ran 8 from Umbra Light #B58CF0)
	Palette = { Main = hex("#8A5CFC"), Shadow = hex("#3A3640"), Highlight = hex("#E2D8FF"), Accent = hex("#605C66") },
	Label = { hex("#9A80F8"), hex("#605C66") },
	Rock = { Shadow = hex("#3A3444"), Mid = hex("#585068"), Lit = hex("#7A7090") },   -- (pass 3: a dark geode crust for the violet light to cut through)   -- (checkpoint 1: read navy-black; a grey shell)
	RockTint = Color3.new(0.86, 0.84, 0.88),
	LitTint = 0.88,
	Rim = hex("#E2D8FF"),
	Highlight = hex("#D8D0E8"), HighlightWidth = 0.05, HighlightEdges = 2,
	Ink = hex("#121514"), InkWidth = 0.04,   -- (guard: #121014 sat 8 from Umbra Dark #0D0817)
	-- (guard: Middle was #9A78F0 -- its blend into Core ran 7 from Umbra Light; Crack is documentation, no reader)
	Crack = { Outer = hex("#6A40D0"), Middle = hex("#9A78FD"), Core = hex("#E8DCFF") },
	CrackGlow = 0.6,
	CrackGlowOwn = 0.8,
	-- (guard: the halo's dark blends, dimmed by the breath, ran 9-12 from Umbra Dark: HaloEdge and the Low HaloCol keep
	-- red >= 28, so a 0.94 breath still holds them 13 off it)
	HaloEdge = hex("#282424"),   -- (pass 3: at a 0.88 breath #1C1616 sat 12 off Umbra Dark)   -- (guard: was #161616)
	Stages = {
		Low = { Bands = { { 0.025, hex("#5A38D8") }, { 0.06, hex("#3A1C98") } }, Halo = { 0.02, 0.08 },
			HaloCol = hex("#1C0C30"), Seam = hex("#2A1468"), Light = 0.35 },   -- (guard: HaloCol was #160C30)
		Mid = { Bands = { { 0.045, hex("#8A6CF8") }, { 0.075, hex("#5A38D8") } }, Halo = { 0.035, 0.16 },
			HaloCol = hex("#1E1048"), Seam = hex("#5A38D8"), Light = 0.7 },
		-- (guard: the outer band was #40249E -- the breath dimmed it to 12 from Voltaic Dark #4A1A8C)
		Max = { Bands = { { 0.035, hex("#E8DCFF") }, { 0.07, hex("#A88CFF") }, { 0.105, hex("#7A58F0") }, { 0.13, hex("#4A2CB8") } }, Halo = { 0.04, 0.24 },
			HaloCol = hex("#2A1668"), Seam = hex("#A88CFF"), Light = 1.25 },   -- (pass 3: four bands: denser crystal light than Rust)
	},
	SeamOff = hex("#2A2630"),
	Light = hex("#A070FF"),
	HitFlash = hex("#D8C8FF"),
	Ember = hex("#9A70F0"), Grit = { hex("#605C66"), hex("#3A3640") },
	Dust = { Light = hex("#9A96A0"), Dark = hex("#5E5A66"), Pale = hex("#B4B0BA") },
	Scuff = hex("#6A6670"),
	Crystals = { Variants = 3, Prisms = { 3, 5 }, Sides = 6, Length = { 0.5, 1.1 }, Radius = { 0.09, 0.18 },   -- (checkpoint 1: read as sparkles; bigger)
		 Splay = 0.55,
		PerCell = 1, PerPlate = 1, Sink = 0.3, Size = 1.3,
		-- (guard: Tip was #C4A0FA -- Glow x the breath (~0.91-0.95) dimmed it to 8 from Umbra Light #B58CF0)
		Base = hex("#24106A"), Body = hex("#5A38D8"), BodyLit = hex("#7A58F0"), Tip = hex("#C4AAFA"),
		Glow = { Off = 0.45, Low = 0.6, Mid = 0.8, Max = 1.0 } },
	Pulse = { Period = 2.25, Amp = 0.06 },   -- (Amp is an input: a Neon body swings ~2.6x on screen, ~+-15%)
	Layers = {
		-- (guard: the middle stop was #9A80F8 -- the first segment's blend ran 10 from Umbra Light)
		{ Name = "AmethystMote", Kind = "Mote", Texture = "Sparkle", Color = { hex("#E2D8FF"), hex("#9A80FD"), hex("#5A38D8") },
			Size = { 0.32, 0.06 }, Life = { 0.8, 1.6 }, Speed = { 0.5, 2 }, Drag = 2, Accel = Vector3.new(0, 0.6, 0),
			LightEmission = 0.3, LightInfluence = 0,
			Share = { Hold = 0.12, Flight = 0.12, Impact = 0.12, Plate = 0.12, Wall = 0.12, Tomb = 0.12, Aftershock = 0.12 } },
	},
	-- neutral grey Wall / Tomb caps (the maroon body goes near-black under the cool tint). (guard: was (0.42, 0.42, 0.9)
	-- -- the body x tint, #18080E, sat 11 from Umbra Dark; red lifted to 0.47 and green with it, so the caps stay grey)
	-- (guard: TerraAftershock was (0.36, 0.34, 0.4) -- the plates' darker baked soil walls landed 10-12 from Umbra Dark;
	-- blue <= 0.315 clears them, the whole tint a shade darker so the tops stay a faintly cool grey)
	Tint = { TerraWall2 = Color3.new(0.47, 0.47, 0.9), TerraTomb2 = Color3.new(0.47, 0.47, 0.9),
		TerraAftershock = Color3.new(0.21, 0.14, 0.16) },   -- (pass 3: a dark mauve crust: the grey-violet dome had no contrast; anything more violet-black over the warm bake meets Umbra Dark)
	Seam = { Ember = hex("#5A38D8"), Hot = hex("#C0C8FF"), Inner = hex("#3A3640"), Dead = hex("#24202A") },   -- (pass 3: seams glow at rest)
	-- (guard: Underlay was #3A1C88 -- its blend into UnderlayHot ran through Voltaic Dark #4A1A8C and, breathing, Umbra
	-- Base #4F2191: bluer, so blue leads red past both)
	Underlay = hex("#5A3CE8"), UnderlayHot = hex("#E0D0FF"),   -- (pass 3: a white-violet hot rim; the heal step at 0.36 sat 12 off Umbra Base)   -- (checkpoint 9: #3A1C98 rendered pure blue, the same as Meteorite's; #7848E8 rendered fuchsia #EA35FE -- this place's Neon swings on red; midway, every blend step and its x0.7 breath 18+ off Umbra)
	-- (2026-10-25, fix pass) THE BAKED KITS' STONE (mechanism at Obsidian Magma's Stone): a grey geode shell in strata,
	-- and by piece violet crystal facets (Glass, lit) and a few crystals lit from within (Neon: that Tone is a Neon INPUT,
	-- about half its on-screen colour, as Crystals' are). (guard: the Neon piece was #5E40D8 -- at x0.71 grain it sat
	-- within 12 of Umbra Base #4F2191 on all three channels; bluer and greener, 15 off it, clear of Voltaic / Toxin Dark)
	Stone = { Tones = { hex("#7A6A80"), hex("#887890"), hex("#6E5E76"), hex("#968AA0") }, Band = 1.1, Jitter = 0.06,   -- (pass 3: a darker shell under the crystals)   -- (checkpoint 9: a warm violet-grey shell -- the cool grey still read navy #293769 in shade)   -- (checkpoint 8: a lighter shell -- shaded faces read navy)
		Pieces = {
			{ Share = 0.18, Tone = hex("#A878E8"), Material = "Glass" },   -- violet crystal facets (checkpoint 9: #9A78E8 rendered blue in shade)
			{ Share = 0.06, Tone = hex("#8058F0"), Material = "Neon" },   -- (pass 3: #8048F0's grain sat 8 off Umbra Base)   -- crystal glowing through the shell (Epic) (checkpoint 9: #6048E8 read indigo; guard: grain 15 off Toxin)
		},
		Kits = { TerraWall2 = true, TerraTomb2 = true } },
	-- pale lilac, a violet edge (Rim, the Mote's middle). (guard: Edge was #9A80FD -- the blend from Fill passed 13 from
	-- Umbra Light #B58CF0; full blue holds it 15 off)
	Burst = { Fill = hex("#E2D8FF"), Edge = hex("#9A80FF") },
	-- EPIC, the luminous layer over Rare on every move: the Crystals clusters above (TerraWrap.CrystalTemplates) grown out
	-- of 10% of the Wall / Tomb / Aftershock stone pieces on their top-facing side, 0.6 of the piece (kept small: the
	-- Wall's silhouette and the Tomb's heap around its target stay readable), at Glow 0.85 with the Pulse on top
	-- (x0.75-0.85 on the Wall / Tomb, where ChargedRock breathes it DOWN from Glow by up to 2 x Amp; x0.80-0.90 on
	-- Aftershock's rocks, TerraWrap.GlowMul: the clusters' Base / Body / BodyLit / Tip clear the guard through both,
	-- nearest the Tip, 15 off Umbra Light); and at the Boulder Shot impact
	-- 6 crystal shards flung out with the debris (x EffectDensity), 0.55 of a cluster, gone by 1 s
	CrystalsBaked = { PerPiece = 0.45, Size = 0.75, Glow = 1.0 },   -- (pass 3: more, brighter clusters)   -- (checkpoint 8: 0.1 x 12 slabs grew one or none)
	Shatter = { Count = 6, Size = 0.55, Life = 1 },
	-- (pass 3, Epic) drifting crystal motes off the standing Wall, the risen Tomb and the Aftershock scar: steady (Mote),
	-- so Reduce Flashing keeps them; rate x Density
	Drift = { Rate = 2, Kind = "Mote", Colors = { hex("#E8DCFF"), hex("#A88CFF") }, Size = { 0.32, 0.06 }, Life = { 1.2, 2.0 },
		Speed = { 0.4, 1.0 }, Accel = Vector3.new(0, 0.5, 0) },
}
-- METEORITE CORE, Mythic: dark iron-nickel with a fine straight steel etch (Veins, Kink 0.12: Widmanstatten-like), split
-- by blue-white starmetal fissures that FLOW (one world field drifting through every vein, Flow) and breathe (Pulse);
-- star twinkles glint on the surface and a fine star-dust drifts off it (Layers, +27%); in flight it streaks like a
-- falling star (Streak, a light-layer Trail). Clearly above Amethyst, and cool where Obsidian Magma's lava is hot.
-- Its blue-white keeps off Cryo Light #DEF7FF and Zephyr's white (#E8F0FF would not).
SkinCatalog.Skins.MeteoriteCore = { Id = "MeteoriteCore", DisplayName = "Meteorite Core", Rarity = "Mythic", Wrap = "Terra",
	Palette = { Main = hex("#363A44"), Shadow = hex("#1E2028"), Highlight = hex("#E4E2FF"), Accent = hex("#7A98FF") },
	Label = { hex("#7A98FF"), hex("#363A44") },
	Rock = { Shadow = hex("#1E2028"), Mid = hex("#363A44"), Lit = hex("#5A5E68") },
	RockTint = Color3.new(0.8, 0.8, 0.82),
	LitTint = 0.9,
	Rim = hex("#B8C4E8"),
	Highlight = hex("#B4BCCC"), HighlightWidth = 0.05, HighlightEdges = 2,
	Ink = hex("#0A0C0A"), InkWidth = 0.04,   -- (guard: #0A0C12 sat 5 from Umbra Dark #0D0817; both render black)
	Crack = { Outer = hex("#3A5CD8"), Middle = hex("#7A98FF"), Core = hex("#EEEAFF") },
	CrackGlow = 0.6,
	CrackGlowOwn = 0.8,
	-- (guard: was #141820 -- the flow's cool end (x0.55, x0.62, x0.9) and the breath dimmed the halo's edge to 6 from Umbra
	-- Dark; a bluer near-black holds blue >= 36 through the whole halo)
	HaloEdge = hex("#14183A"),   -- (pass 3: blue lifted: the breath x the Flow's cool end sat close to Umbra Dark)
	Stages = {
		Low = { Bands = { { 0.02, hex("#1A2C78") }, { 0.058, hex("#0E1844") } }, Halo = { 0.02, 0.06 },
			HaloCol = hex("#0E1638"), Seam = hex("#14205A"), Light = 0.35 },
		Mid = { Bands = { { 0.04, hex("#7A98FF") }, { 0.066, hex("#3A5CD8") } }, Halo = { 0.04, 0.18 },
			HaloCol = hex("#121E50"), Seam = hex("#3A5CD8"), Light = 0.75 },   -- (pass 3: a brighter half-charge -- it only matched Magma's)
		Max = { Bands = { { 0.026, hex("#E4E2FF") }, { 0.048, hex("#7A98FF") }, { 0.074, hex("#3A5CD8") }, { 0.1, hex("#22389A") } },
			Halo = { 0.06, 0.32 }, HaloCol = hex("#1A2A70"), Seam = hex("#7A98FF"), Light = 1.35 },   -- (pass 3: the widest glow in the ladder)
	},
	SeamOff = hex("#22252E"),
	Light = hex("#8AA8FF"),
	HitFlash = hex("#E4E2FF"),
	Ember = hex("#9AB4FF"), Grit = { hex("#363A44"), hex("#1E2028") },
	Dust = { Light = hex("#6A6E78"), Dark = hex("#3A3E48"), Pale = hex("#8A8E98") },
	Scuff = hex("#3A3E48"),
	Veins = { PerArea = 1.4, Width = 0.018, Core = hex("#8A92A0"), Kink = 0.12, Branch = 0.2, Steps = { 5, 8 }, Seed = 7703 },   -- (one band: no Edge, no Streak)
	Pulse = { Period = 2.25, Amp = 0.06 },   -- (pass 3: the core breathes at the Epic limit, 0.44 Hz ~+-15%, flat under Reduce Flashing)
	Flow = { A = Color3.new(0.55, 0.62, 0.9), B = Color3.new(1, 1, 1), Scale = 0.25, Speed = 0.6, Steps = 24, Hold = 0.5 },
	Layers = {
		{ Name = "StarTwinkle", Kind = "Twinkle", Texture = "Sparkle", Color = { hex("#EEEAFF"), hex("#8AA8FF") },
			Size = { 0.8, 0.1 }, Life = { 0.5, 1.0 }, Speed = { 0.2, 1 }, Drag = 3, Accel = Vector3.new(0, 0.4, 0),
			LightEmission = 1, LightInfluence = 0, Shape = "Sphere", Surface = true,
			Share = { Hold = 0.15, Flight = 0.15, Impact = 0.15, Plate = 0.15, Wall = 0.15, Tomb = 0.15, Aftershock = 0.15 } },
		{ Name = "StarDust", Kind = "Mote", Texture = "Sparkle", Color = { hex("#EEEAFF"), hex("#7A98FF"), hex("#3A5CD8") },   -- (pass 3: white-hot sparks RISING off the surface, big enough to read)
			Size = { 0.45, 0.06 }, Life = { 0.8, 1.6 }, Speed = { 0.5, 2.5 }, Drag = 2, Accel = Vector3.new(0, 1.5, 0),
			LightEmission = 1, LightInfluence = 0,
			Share = { Hold = 0.07, Flight = 0.07, Impact = 0.07, Plate = 0.07, Wall = 0.07, Tomb = 0.07, Aftershock = 0.07 } },   -- (pass 3: share moved to the visible Drift embers: Layers 22% + Drift)
	},
	Streak = { Colors = { hex("#EEEAFF"), hex("#7A98FF"), hex("#22389A") }, Width = 1.4, Life = 0.3, LightEmission = 1, MinQ = 0.75 },
	-- black iron Wall / Tomb body, near-neutral dark-grey caps. (guard: red was 0.3 -- the pebbles' baked break #4E321A
	-- x tint sat 10 from Umbra Dark #0D0817; the caps go a shade warmer, which the sky's blue cast evens out)
	-- FLAGGED, not fixed: Terra's baked soil (Aftershock's plate walls, the Tomb's clod) and Aftershock's broken-stone
	-- rocks under these tints sit 7-12 from Umbra Dark -- all under the grade's #141414 crush, black on screen as Umbra
	-- Dark is. Clearing them takes a far darker Aftershock tint (x0.5, near-black tops) or a lighter neutral grey (about
	-- (0.31, 0.29, 0.31), Amethyst's), and red ~0.43 on TerraTomb2 (warmer caps): the owner's call
	Tint = { TerraWall2 = Color3.new(0.34, 0.32, 0.62), TerraTomb2 = Color3.new(0.34, 0.32, 0.62),
		TerraAftershock = Color3.new(0.12, 0.12, 0.1) },   -- (pass 3: black iron plates, the darkest dome)
	Seam = { Ember = hex("#4A64F0"), Hot = hex("#E4E2FF"), Inner = hex("#363A44"), Dead = hex("#22252E") },   -- (pass 3: white-hot at full)
	Underlay = hex("#2C4CD0"), UnderlayHot = hex("#E4E2FF"),   -- (pass 3 on screen: #3A6CFF rendered cyan #00ABFD, Cryo Base's hue; #22389A was pure blue)   -- (pass 3: bright blue fissures, a white-hot rim)
	-- (2026-10-25, fix pass) THE BAKED KITS' STONE (mechanism at Obsidian Magma's Stone): dark blue-black pitted meteorite
	-- rock in strata (the grain reads as the pits), and by piece metallic iron-nickel (Metal; only the brighter one takes
	-- a hair of Reflectance -- a near-black mirror reads sky-blue). (guard: no tone darker than #2A2E3A, whose x0.52
	-- grain holds 16 off Umbra Dark #0D0817)
	Stone = { Tones = { hex("#2E3240"), hex("#363A48"), hex("#2A2E3A"), hex("#3C4250") }, Band = 1.3, Jitter = 0.06,
		Pieces = {
			{ Share = 0.16, Tone = hex("#5C6270"), Material = "Metal" },   -- iron-nickel
			{ Share = 0.08, Tone = hex("#7E8494"), Material = "Metal", Reflectance = 0.04 },   -- bright etched iron
		},
		Kits = { TerraWall2 = true, TerraTomb2 = true } },
	Burst = { Fill = hex("#EEEAFF"), Edge = hex("#7A98FF") },   -- star-white, a starmetal-blue edge (Crack Core, Middle)
	-- MYTHIC, the signature over Epic on every move. Core: every Brk (fracture) face of the Wall / Tomb pieces Neon Color
	-- always -- the crashed star's heat in every break -- ramping to HotColor in the flares (Neon INPUTS, as Stages':
	-- Stages.Mid's seam and Seam.Hot; guard-checked through the Flow and the Pulse too). Shock: a flat Neon ring at each
	-- impact moment, Colors[1] -> [2] over Life, Radius per moment kept inside the moment's own footprint (Boulder: about
	-- the rock; Bulwark: the shoulder box; Tomb: its ~14-stud blast; Aftershock: the slam only -- its real front races out
	-- to 24 at ~34 studs/s and this ring, ~9 studs/s, is left behind it). Drift: sparse star embers off a standing Wall,
	-- a risen Tomb pillar and the Aftershock scar (Size start / finish, Life min / max; Kind = "Mote": TerraWrap.DriftSet
	-- twinkles a Drift without it and draws none under Reduce Flashing -- these hold steady and stay). Rate is per host
	-- before density: the Mythic budget (+25-30%) is mostly the Layers' 0.27 already -- measure it.
	Core = { Brk = true, Color = hex("#3A58E8"), HotColor = hex("#E4E2FF") },   -- (pass 3: a white-hot core in every fracture)
	-- (checkpoint 8: the 0.5 s ring fading to a dark blue barely read; star-white to starmetal blue, longer, wider)
	Shock = { Colors = { hex("#EEEAFF"), hex("#8AA8FF") }, Life = 1.0, Width = 1.6,   -- (pass 3: bolder impact rings; the Tomb's +1 only, for readability; Aftershock's is clamped to 2 x Inner in code)
		Radius = { Boulder = 7, BulwarkHit = 6, Wall = 9, Tomb = 10, Aftershock = 7 } },
	Drift = { Rate = 4, Kind = "Mote", Colors = { hex("#EEEAFF"), hex("#8AA8FF"), hex("#3A5CD8") }, Size = { 0.8, 0.12 }, Life = { 1.2, 2.2 },   -- (pass 3: embers you can see rising, white-hot cooling blue)
		Speed = { 0.6, 1.6 }, Accel = Vector3.new(0, 1.0, 0) },
}

-- PYRO'S FIRST WRAP (2026-10-10; bands per the developer's colour change): a flat comic gas-flame. The flame meshes
-- bake a warm-grey luminance ramp that Neon lights orange; the wrap remaps that ramp, by its position Lo..Hi, into four
-- HARD bands (Steps): shell azure #1C6FD8, body aqua #4FD6EE, inner #C4F4FF, core white. The inputs below are what
-- lands on those on screen: fitted to sampled Neon renders (the render crushes dark channels and lifts the dominant
-- one) and divided by the renderer's own 0.88 tint. Lights go #7FD0FF. (2026-10-19, audit P5B-13) the embers of a
-- wrapped flame canvas go white-hot to azure in hard steps (PyroDraw's wrapEmberSeq; an Embers list here would override
-- it), not Pyro's warm colours. The wrap draws in the FLAME look only (PyroDraw): the toon look ignores it.
-- (2026-10-24) UNCOMMON, and an ELEMENT wrap like Umbra's (2026-10-19), Cryo's and Toxin's: Rarity / Wrap set, drawn
-- for the caster's ElementWrap_Pyro (Studio: a WrapStudio attribute on the caster) on the same six flame-look abilities
-- as before; its per-ability Offer rows are gone. Still live (ElementWraps.Pyro), as it was. Palette is the WRAPS card's
-- four swatches only: PyroDraw draws from Flame.
SkinCatalog.Skins.AzureFlame = { Id = "AzureFlame", DisplayName = "Azure Flame", Rarity = "Uncommon", Wrap = "Pyro",
	-- (2026-10-25) the toon look (IGNITE!): Pyro's Dark / EmberRed / Base / Light /
	-- WhiteHot in this wrap's colours (PyroDraw.WrapPiece, PyroFX's heat ramp)
	ToonRamp = { hex("#0E2F66"), hex("#1C6FD8"), hex("#4FD6EE"), hex("#C4F4FF"), hex("#F0FAFF") },
	Palette = { Main = hex("#4FD6EE"), Shadow = hex("#1C6FD8"), Highlight = hex("#C4F4FF"), Accent = hex("#7FD0FF") },
	Label = { hex("#1C6FD8"), hex("#4FD6EE"), hex("#C4F4FF") },
	-- (2026-10-27, the owner: the fireball read greyish) the bands were near grey (Sky s0.46, Pale s0.25, White s0): the
	-- Ball and Tail meshes sit mostly in Sky / Pale / White, so the big shapes went grey-teal while the small licks still
	-- read blue. Saturated like the other ladders' bands, toward Palette. Was Azure #3C627D, Sky #54949B, Pale #889FB6,
	-- White #ECECEC
	Flame = { Azure = hex("#1E4C8C"), Sky = hex("#2A86C0"), Pale = hex("#5CC4E4"), White = hex("#CFF2FF"),
		Lo = 0.29, Hi = 0.56, Steps = { 0.25, 0.55, 0.8 } },
	Light = hex("#7FD0FF"),
}

-- (2026-10-24) PYRO'S LADDER, live in ElementWraps.Pyro since 2026-10-24 (approved by the owner after the round 3-4
-- checkpoints). Drawn by PyroDraw from Flame (four bands remapped onto the flame meshes' baked ramp,
-- at Azure Flame's Lo / Hi / Steps), Light and Embers, plus the upper tiers' fields (PyroDraw: THE UPPER TIERS' LEVERS).
-- Flame holds the display inputs (what the vertices carry, fitted to the Neon render like Azure Flame's); Label and
-- Palette (the WRAPS card's swatches) are the intended on-screen colours.
-- ASHFIRE, Uncommon: a smouldering grey-charcoal flame, dull red embers. Flat: four hard bands, hard-step embers, nothing
-- added (0%), no pulse -- Default's shapes and counts.
SkinCatalog.Skins.Ashfire = { Id = "Ashfire", DisplayName = "Ashfire", Rarity = "Uncommon", Wrap = "Pyro",
	-- (2026-10-25) the toon look (IGNITE!): Pyro's Dark / EmberRed / Base / Light /
	-- WhiteHot in this wrap's colours (PyroDraw.WrapPiece, PyroFX's heat ramp)
	ToonRamp = { hex("#2B2826"), hex("#8A3424"), hex("#5E5853"), hex("#B8B0A8"), hex("#E6E0D8") },
	Label = { hex("#5E5853"), hex("#9A928A"), hex("#2B2826") },
	Palette = { Main = hex("#5E5853"), Shadow = hex("#2B2826"), Highlight = hex("#D8D0C6"), Accent = hex("#A8402A") },
	Flame = { Azure = hex("#515051"), Sky = hex("#6D6B6C"), Pale = hex("#8C8A8A"), White = hex("#AFABAA"),   -- (round 5: neutral -- round 3 read taupe, round 4 blue-grey)
		Lo = 0.29, Hi = 0.56, Steps = { 0.25, 0.55, 0.8 } },
	-- (2026-10-25, the owner: Ashfire still showed Pyro's impact colour) the light was dull red: on a tan body or the blue
	-- floor it read as Pyro's orange. Now ash-grey; the embers start pale ash and only smoulder dull red at the end
	Light = hex("#C9C2BA"),
	Embers = { hex("#D8D0C6"), hex("#9A928A"), hex("#6E2A20"), hex("#2C1E1C") },
}
-- SOLAR FLARE, Rare: white-gold superheated fire. The Rare pass: graded bands (Smooth), embers blending white to amber
-- over their life with a streaked finish, and thin white-gold sparks at +6% of each ember site. No glow boost.
SkinCatalog.Skins.SolarFlare = { Id = "SolarFlare", DisplayName = "Solar Flare", Rarity = "Rare", Wrap = "Pyro",
	-- (2026-10-25) the toon look (IGNITE!): Pyro's Dark / EmberRed / Base / Light /
	-- WhiteHot in this wrap's colours (PyroDraw.WrapPiece, PyroFX's heat ramp)
	ToonRamp = { hex("#8A4A08"), hex("#D98A14"), hex("#FFDA66"), hex("#FFF0B0"), hex("#FFFCE8") },
	Label = { hex("#FFDA66"), hex("#FFF0B0"), hex("#E8A317") },
	Palette = { Main = hex("#FFDA66"), Shadow = hex("#E8A317"), Highlight = hex("#FFFCE8"), Accent = hex("#FFE6A8") },
	-- (round 3, the owner on the showreel: still Default's orange-yellow on the normal moves) WHITE-HOT: the bands moved
	-- down the ramp so most of every flame is the white core and the gold / amber is a thin rim (Steps 0.12 / 0.3 / 0.5,
	-- was 0.25 / 0.55 / 0.8), the rim deeper amber for contrast; its own Tint keeps a flame white as it cools (Default's
	-- cooling darkens and reddens a flame, which is what made the small ones read as Default); a whiter light, 1.2x
	Flame = { Azure = hex("#8A4A08"), Sky = hex("#C8A040"), Pale = hex("#E4DCC0"), White = hex("#F2F2EC"),
		Lo = 0.29, Hi = 0.56, Steps = { 0.12, 0.3, 0.5 }, Smooth = 0.1 },
	Tint = { Normal = 1, Hot = 1, CoolStep = 0.2, Cool = { 0.985, 0.975, 0.965 } },
	Light = hex("#FFF0C0"), LightK = 1.2,
	Embers = { hex("#FFFBEA"), hex("#FFE79A"), hex("#FFAE28"), hex("#D9801A") }, EmberSmooth = true,
	EmberFinish = { LightEmission = 1, Squash = 1.2 },
	Extra = { { Name = "SolarSpark", Share = 0.06, Burst = 0.06, Colors = { hex("#FFFCE8"), hex("#FFD86A") },
		Size = { 0.12, 0.02 }, Life = { 0.25, 0.5 }, Speed = { 14, 26 }, Spread = 60, Squash = 2.5, Rise = -10, Drag = 3,
		LightEmission = 1 } },
}
-- PHOENIX, Epic: a gold-to-crimson flame (graded: gold-white core, gold, crimson body, deep crimson shell; the orange
-- between gold and crimson kept narrow), breathing (2.25 s, +/-15%) with a brighter light, and drifting ember FEATHERS (a
-- painted feather image) at +12% of each ember site's own count: thinner on LOW / MEDIUM, fuller on ULTRA.
SkinCatalog.Skins.Phoenix = { Id = "Phoenix", DisplayName = "Phoenix", Rarity = "Epic", Wrap = "Pyro",
	-- (2026-10-25) the toon look (IGNITE!): Pyro's Dark / EmberRed / Base / Light /
	-- WhiteHot in this wrap's colours (PyroDraw.WrapPiece, PyroFX's heat ramp)
	ToonRamp = { hex("#4A0C2C"), hex("#9E0E2C"), hex("#D8213A"), hex("#FFAA2A"), hex("#FFEDBA") },
	Label = { hex("#D8213A"), hex("#FFAA2A"), hex("#9E0E2C") },
	Palette = { Main = hex("#D8213A"), Shadow = hex("#9E0E2C"), Highlight = hex("#FFAA2A"), Accent = hex("#FFEDBA") },
	Flame = { Azure = hex("#4A0C2C"), Sky = hex("#74144A"), Pale = hex("#B88018"), White = hex("#DDB060"),   -- (round 3, the owner: "too close to Default": deeper, bluer crimson, a GOLD core, no white)
		Lo = 0.29, Hi = 0.56, Steps = { 0.25, 0.55, 0.8 }, Smooth = 0.12 },
	Light = hex("#FFC27A"), LightK = 1.3, Pulse = { Period = 2.25, Amp = 0.15 },
	Embers = { hex("#FFEDBA"), hex("#FFAA2A"), hex("#E0303C"), hex("#6E0A22") }, EmberSmooth = true,
	-- (round 3, the owner: the feathers did not read) the FEATHERS are Phoenix's mark: big gold Neon feather meshes shed off
	-- the flame body itself -- every flame of every move, the Fireball's charge and flight included -- that drift away on
	-- their own for ~3 s, fluttering, gold turning crimson as they burn out. PerPart a second per flame drawn, at least
	-- MinRate a second per effect, x EffectDensity.
	-- (round 3, the owner on the showreel: on normal moves the feathers hid the fight) by the ability's tier (PyroFX
	-- forTier): the Basics small and close, the Technique a step up, the Ultimate (Ring of Fire) the full flight below
	ShedScale = { Basic = { Size = 0.32, Rate = 0.35, Speed = 0.3, Life = 0.55, Rise = 0.4 },
		Technique = { Size = 0.55, Rate = 0.6, Speed = 0.55, Life = 0.75, Rise = 0.65 } },
	Shed = { { Name = "PhoenixFeather", Kind = "Mesh", Mesh = "Feather", PerPart = 0.18, MinRate = 24, Burst = 0.25,
		Colors = { hex("#FFD060"), hex("#FFD060"), hex("#FFA020"), hex("#E2324A"), hex("#8A1430") },
		Size = { 3.4, 2.0 }, Life = { 3.0, 4.0 }, Speed = { 11, 17 }, Spread = 65, Rise = 2.0, Drag = 0.75, Spin = 50, Sway = 1.2 } },   -- (round 6: a flight at the cast and the eruption, thrown up clear of the flames)
}
-- VOID FLAME, Mythic: black fire round a deep violet-indigo core (never magenta: every hue sits blue of Umbra's violet).
-- An Epic's breath and stronger light, plus two signature levers in Pyro's own shapes and ember texture: FLOW (one slow
-- world field drifting the core between indigo and violet through the whole fire) and TWINKLES (sparse pale-violet star
-- glints, 18%) with rising black soot (9%): +27% of each ember site. Its embers read as soot (LightEmission 0.15).
SkinCatalog.Skins.VoidFlame = { Id = "VoidFlame", DisplayName = "Void Flame", Rarity = "Mythic", Wrap = "Pyro",
	-- (2026-10-25) the toon look (IGNITE!): Pyro's Dark / EmberRed / Base / Light /
	-- WhiteHot in this wrap's colours (PyroDraw.WrapPiece, PyroFX's heat ramp)
	ToonRamp = { hex("#120826"), hex("#2A1260"), hex("#4B2FD0"), hex("#9C86FF"), hex("#D8CCFF") },
	Label = { hex("#4B2FD0"), hex("#C8B8FF"), hex("#120826") },
	Palette = { Main = hex("#4B2FD0"), Shadow = hex("#120826"), Highlight = hex("#C8B8FF"), Accent = hex("#7B4DFF") },
	Flame = { Azure = hex("#000000"), Sky = hex("#34164F"), Pale = hex("#6446B2"), White = hex("#9D92D3"),   -- (round 4: core hue 261 (r2) / 237 (r3) measured; aimed ~251)
		Lo = 0.29, Hi = 0.56, Steps = { 0.25, 0.55, 0.8 }, Smooth = 0.16 },
	Light = hex("#7B4DFF"), LightK = 1.2, Pulse = { Period = 2.5, Amp = 0.15 },
	Flow = { A = Color3.new(0.75, 0.75, 1), B = Color3.new(0.94, 0.7, 0.965), Scale = 0.12, Speed = 0.7 },
	Embers = { hex("#D8CCFF"), hex("#6E4CF0"), hex("#24124F"), hex("#050308") }, EmberSmooth = true,
	EmberFinish = { LightEmission = 0.15 },
	Extra = {
		{ Name = "VoidTwinkle", Twinkle = true, Facing = true, Share = 0.06, Burst = 0.06, Colors = { hex("#EDE6FF"), hex("#9C86FF") },
			Size = { 0.38, 0.06 }, Life = { 0.6, 1.2 }, Speed = { 1, 5 }, Rise = 1, Drag = 3, LightEmission = 1, Brightness = 4 },
	},
	-- (round 3, the owner: "just a recolor, not Mythic") CURSED FIRE that burns UP and away: ASH FLAKES -- jagged Neon flakes,
	-- black at the heart, their rims lit violet -- torn off the flames, rising fast and spinning while they cool to black and
	-- crumble; and VOID WISPS -- black smoke clinging to the flames, streaming up off every tongue. Both shed off the flame
	-- body (every move, the Fireball included), x EffectDensity.
	-- (round 3, the owner on the showreel: on normal moves the smoke and shards swallowed the screen) by tier, as Phoenix's
	ShedScale = { Basic = { Size = 0.3, Rate = 0.3, Speed = 0.3, Life = 0.55, Rise = 0.35 },
		-- (round 4, the owner: Ember Refund came out a faint wisp on the chest) a little fuller and longer-lived than the other
		-- Basics: ~1.4x the size, ~1.8x the rate, the same low lift so it stays under the nameplates
		EmberRefund = { Size = 0.42, Rate = 0.55, Speed = 0.32, Life = 0.65, Rise = 0.35 },
		Technique = { Size = 0.55, Rate = 0.55, Speed = 0.55, Life = 0.75, Rise = 0.6 } },
	Shed = {
		{ Name = "VoidAsh", Kind = "Mesh", Mesh = "Flake", PerPart = 0.12, MinRate = 12, Burst = 0.25,
			Colors = { hex("#B8A0FF"), hex("#8C6CF8"), hex("#4B2FD0"), hex("#24124F"), hex("#000000") },   -- (round 5: violet rims, not white)
			Size = { 1.7, 0.35 }, Life = { 1.8, 2.8 }, Speed = { 7, 12 }, Spread = 45, Rise = 6, Drag = 0.8, Spin = 140, Sway = 0.7, Fade = 0.8 },   -- (round 6: thrown up fast)
		{ Name = "VoidWisp", Kind = "Smoke", PerPart = 0.18, MinRate = 12, Burst = 0.15, Texture = "rbxasset://textures/particles/smoke_main.dds",
			Colors = { hex("#1E0A3C"), hex("#050505") }, Alpha = 0.05, LightInfluence = 0,
			Size = { 2.2, 6 }, Life = { 1.6, 2.4 }, Speed = { 2, 4 }, Spread = 25, Rise = 6, Drag = 1.2, Spin = 40 },   -- (round 5: billowing higher)   -- (round 4: unlit and near-opaque -- lit, the smoke washed out in daylight)
	},
}

-- UMBRA'S FIRST WRAP (2026-10-11): Bloodmoon. Umbra's violet ramp turned red, tone for tone, and nothing else: each
-- colour keeps its place in the ramp (hue ~262 -> ~353 at the same value; Shade alone gains saturation, because a
-- light purple turned by hue alone is pink, not crimson). Drawn by UmbraFX: the Palette block is the wrap.
-- Umbra's strips, ball and screen images carry their violet baked in, so the wrap MULTIPLIES them: RibbonA's Rest and
-- Band are Beam.Color over the A strips; RibbonB.Tint is Beam.Color over the B strips, with Gain (Beam.Brightness)
-- lifting the red back to the strip's own brightness; the three *Tint colours go over the ball sprite and the
-- Eclipse screen layer. In every multiplier Blue >= Green, or a strip's pale edges turn orange once Brightness clips
-- the red. EVERY VALUE IS A PROPOSAL until the owner signs the wrap off.
-- (2026-10-19) UNCOMMON, and an ELEMENT wrap like Cryo's and Toxin's: Rarity / Wrap set, the block renamed Palette, drawn
-- for the caster's ElementWrap_Umbra (Studio: a WrapStudio attribute on the caster); its per-ability Offer rows are gone.
-- Still awaiting the owner's sign-off: NOT in ElementWraps until approved.
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

-- TOXIN'S FOURTH WRAP (2026-10-19): Octopus (was Blue-Ringed Octopus; rings dropped 2026-10-19 for rust blotches + cream sucker dots), Epic -- murky ochre gas graded from a warm umber core to a lit
-- edge (each lobe by its distance out, lit ForceField rims), soft dark rosette lobes, glossy; the bubble a self-lit
-- (Neon) painted membrane with glowing electric-blue rings over dark rosettes; every puff wearing the bubble's painted
-- rings (checkpoint 5: no ring particles; the mote / ring / stain Bands keys ToxinFX can read are set by no wrap --
-- 2026-10-19, audit P5B-12); the wrap's glow breathes (2.25 s, +/-15%, held under Reduce Flashing), apart
-- from Virulence's countdown. Every value a proposal. NOT in ElementWraps until approved (2026-10-19, audit P5F-22).
SkinCatalog.Skins.Octopus = { Id = "Octopus", DisplayName = "Octopus", Rarity = "Epic", Wrap = "Toxin",
	Label = { hex("#C23A28"), hex("#F4C8B0"), hex("#8A1F16") },   -- (2026-10-20: the rust-red octopus and its peach suckers)
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
			-- (checkpoint 6, owner 2026-10-19) the blue-ring motif dropped: a real octopus's skin instead -- rust mottled
			-- blotches over the amber, small pale cream sucker dots (soft-edged: ToxinFX paintC)
			LobeSkin = { Seed = 31, Blotches = 8, Dots = 48, DotRows = 8, DotSize = 0.15, DotCup = 0.55, Spread = true, SeedPerKey = true, EdgeSoft = 0.06, Rings = 0, Res = { 40, 80 }, Texture = true, TexRes = { 20, 40 }, TexSize = { 512, 256 }, Smooth = true, Glint = 2,
				Light = Vector3.new(0, 1, 0), BlotchColor = "Rust", DotColor = "Sucker", BlotchTint = { 0.82, 0.5, 0.38 }, DotMix = 1 },
			Pulse = { Period = 2.25, Amp = 0.08 },   -- (2026-10-20: a quieter breath, was 0.16)
			Light = "Gas", Glow = "GasCore", Gloss = { Material = "SmoothPlastic", Reflectance = 0.02 },   -- (2026-10-20: matte, was 0.12)
			Wave = { Body = { "GasShadow", "Gas", "GasShadow", "Gas" }, Lead = { "Gas", "GasLit", "Gas", "GasLit" },
				Blotch = { "GasShadow", "Gas", "GasShadow", "Gas" } },
			Mark = { Body = { "GasShadow", "Gas", "GasShadow", "Gas" }, Outer = { "Gas", "GasLit", "Gas", "GasLit" },
				Blotch = { "GasShadow", "Gas", "GasShadow", "Gas" } },
			Skin = { Seed = 23, Blotches = 10, Dots = 72, DotRows = 10, DotSize = 0.19, DotCup = 0.45, Spread = true, EdgeSoft = 0.06, Rings = 0, Res = { 64, 128 }, Texture = true, TexRes = { 20, 40 }, TexSize = { 512, 256 }, Smooth = true, Light = Vector3.new(-0.4, 0.75, 0.55),
				Glint = 2, Material = "SmoothPlastic", BaseColor = "Membrane", BlotchColor = "Rust", DotColor = "Sucker", GlintColor = "MembraneHi", BlotchTint = { 0.82, 0.5, 0.38 }, DotMix = 1 } },
		Finish = { Membrane = 0.05, MembraneHi = 0.15, Liquid = 0.35 },
		Color = { GasCore = hex("#8A1F16"), GasShadow = hex("#A42C1E"), Gas = hex("#C23A28"), GasLit = hex("#D65A44"), GasEdge = hex("#E2826A"), Liquid = hex("#B0331F"), LiquidDeep = hex("#6C1622"), LiquidSpec = hex("#F6D6C8"), Membrane = hex("#C0402C"), MembraneHi = hex("#F0B8A4"), Mottle = hex("#2A1E0A"), Rust = hex("#7A2414"), Sucker = hex("#F4C8B0"), Shimmer = hex("#BFE6FF"), Virulence = hex("#D6F2FF") },
		Display = {   -- (2026-10-19 rust-red recolour, Studio only: inputs solved from the measured red swatch boards; GasLit Neon at round 4's luminance)
			Lobe = { GasCore = Color3.fromRGB(189, 101, 70), GasShadow = Color3.fromRGB(218, 116, 80), Gas = Color3.fromRGB(253, 129, 90), GasLit = Color3.fromRGB(113, 46, 44), GasEdge = Color3.fromRGB(255, 185, 141) },
			Particle = { GasCore = Color3.fromRGB(161, 86, 60), GasShadow = Color3.fromRGB(185, 99, 68), Gas = Color3.fromRGB(215, 110, 76), GasLit = Color3.fromRGB(109, 46, 35), GasEdge = Color3.fromRGB(217, 157, 120) },
			Solid = { Liquid = Color3.fromRGB(233, 123, 82), LiquidDeep = Color3.fromRGB(156, 86, 74), Rust = Color3.fromRGB(173, 109, 64), Membrane = Color3.fromRGB(253, 129, 90), Mottle = Color3.fromRGB(40, 28, 12), LiquidSpec = Color3.fromRGB(246, 214, 200), MembraneHi = Color3.fromRGB(226, 173, 154), Sucker = Color3.fromRGB(255, 196, 160), Shimmer = Color3.fromRGB(120, 200, 255) },
			Neon = { Virulence = Color3.fromRGB(162, 183, 193) }, Glow = { Virulence = Color3.fromRGB(214, 242, 255) },
		} } }

SkinCatalog.Skins.Bloodmoon = { Id = "Bloodmoon", DisplayName = "Bloodmoon", Rarity = "Uncommon", Wrap = "Umbra",
	Label = { hex("#5C1C21"), hex("#E84054"), hex("#FFDEE4") },
	Palette = {
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
		-- charge ball, the hit's core, Eclipse's core -- wear the engine's own sky moon (no upload), cut to its disc under
		-- ONE flat Tint (2026-10-19: it was shaded lit limb 255,104,96 to dark limb 140,30,42 by a UIGradient -- a Rare
		-- lever; Tint = that gradient's mean over the disc, so the moon keeps its average colour). The dart's stretched
		-- head keeps the tinted ball above.
		BallMoon = { Image = "rbxasset://sky/moon.jpg", RectOffset = Vector2.new(10, 8), RectSize = Vector2.new(109, 111),
			Tint = Color3.fromRGB(196, 66, 70) },
		ShadowSkin = hex("#301115"),       -- the decoy's pieces while they travel
		PulseTint = hex("#FFC6CD"),        -- Eclipse's opening pulse
		Grade = { Ambient = Color3.fromRGB(92, 50, 55), OutdoorAmbient = Color3.fromRGB(100, 58, 63),
			AtmosphereColor = Color3.fromRGB(110, 58, 64), AtmosphereDecay = Color3.fromRGB(70, 26, 31),
			TintColor = Color3.fromRGB(232, 154, 163) },
		VignetteTint = Color3.fromRGB(255, 107, 56), EdgeTint = Color3.fromRGB(255, 92, 84),
	},
}

-- UMBRA'S SECOND WRAP (2026-10-19): Ashen, RARE. True greyscale, no hue at all: obsidian black to bone white. Umbra's
-- strips, ball and screen images carry violet baked in, so the multipliers below (RibbonA / RibbonB / the *Tint) are
-- greenish ON PURPOSE: each cancels its own image's violet (fitted to that image's pixels) so the RENDERED colour is grey;
-- Color, Ramp and Ash hold the intended greys. The Rare levers: Ramp (every ribbon graded along its length: a light one
-- bone at its head -> ash at its tail, a shadow one charcoal -> ash), Finish (the decoy's travelling
-- pieces in Foil, glossy obsidian with neutral glints, Reflectance 0: a glossy black mirrors the sky and reads blue),
-- Mark (the lit Mark marker's gloss, its input warmed so it renders grey), Ash (pale ash flecks drifting off every ribbon's
-- head, 8% of that ribbon's Default quads, bone -> ash -> charcoal over each fleck's life, through the density helper).
-- Every grey stays between #151515 and #F2F2F2 (greys 11-20 sit within 12 of Umbra's Dark #0D0817, 243-255 within 12
-- of Zephyr's Light #FFFFFF). EVERY VALUE IS A PROPOSAL until the owner signs it off; listed in ElementWraps since 2026-10-19 for the
-- owner's in-game review, NOT approved. ROUND 2 (R2U, 2026-10-19, the owner: every tier read "just a recolor"): pushed to
-- the Rare ceiling with Mottle (static blotches along every ribbon), Finish.Pieces (the decoy's pieces as an obsidian /
-- graphite / bone mosaic in Foil / Basalt / Sandstone) and Mark (veined Marble); Ash stays at its +8 % ceiling.
-- (A multiply cannot grey a two-tone violet strip exactly: each multiplier is its image's best compromise, fitted to its
-- pixels, and the residual tint is measured on the checkpoint sheet. Greyscale copies of the eight baked images are made
-- locally and wait for the owner's yes to upload.)
SkinCatalog.Skins.Ashen = { Id = "Ashen", DisplayName = "Ashen", Rarity = "Rare", Wrap = "Umbra",
	Label = { hex("#1C1C1C"), hex("#8C8C8C"), hex("#E6E6E6") },
	Palette = {
		Color = { Glint = hex("#EBEBEB"), Shade = hex("#B4B4B4"), Dusk = hex("#363636"), Void = hex("#1C1C1C") },
		RevealColor = hex("#E6E6E6"),      -- Eclipse's outline on revealed enemies: bone (Default: light purple)
		RibbonA = { Lit = Color3.fromRGB(226, 255, 201),
			light = { Rest = Color3.fromRGB(203, 230, 181), Band = Color3.fromRGB(226, 255, 201), Untextured = hex("#C8C8C8") },
			shadow = { Rest = Color3.fromRGB(117, 128, 102), Band = Color3.fromRGB(199, 217, 173), Untextured = hex("#3A3A3A") } },
		RibbonB = { Tint = { light = Color3.fromRGB(211, 255, 168), shadow = Color3.fromRGB(183, 255, 124) },
			Gain = { light = 1.5, shadow = 1.2 },
			Untextured = { light = hex("#B4B4B4"), shadow = hex("#363636") } },
		BallBodyTint = Color3.fromRGB(240, 225, 180),   -- the ball sprite's blue-black, neutral (2026-10-19 rework: was 255,235,167, a warm cream reading as gold, not neutral -- still wants a swatch-ball recalibration pass against the live sprite's rendered pixel, this was a clean-grey placeholder; UR 2026-10-19 calibrated it on swatch balls in Training Ground light: 205,205,205 rendered the body #060515, navy, with a blue-grey rim, sat 0.14; 255,235,167 #0C080B with a warm rim, 0.08; 240,225,180 #0A080E with a neutral rim, 0.02: kept)
		ShadowSkin = hex("#1E1E1E"),       -- the decoy's pieces while they travel: obsidian
		PulseTint = hex("#E0E0E0"),        -- Eclipse's opening pulse
		Grade = { Ambient = Color3.fromRGB(60, 60, 60), OutdoorAmbient = Color3.fromRGB(68, 68, 68),
			AtmosphereColor = Color3.fromRGB(72, 72, 72), AtmosphereDecay = Color3.fromRGB(38, 38, 38),
			TintColor = Color3.fromRGB(200, 200, 200) },   -- Eclipse's world grade: the map in greyscale
		VignetteTint = Color3.fromRGB(137, 255, 76), EdgeTint = Color3.fromRGB(206, 255, 160),
		-- (the gradient: light ribbons bone at the head -> ash at the tail, shadow ribbons charcoal at the head -> ash at the
		-- tail, so the set runs black-to-bone and every ribbon meets ash where it fades)
		Ramp = { light = { Head = Color3.fromRGB(242, 242, 242), Mid = Color3.fromRGB(146, 146, 146), Tail = Color3.fromRGB(51, 51, 51), At = 0.5 },
			shadow = { Head = Color3.fromRGB(51, 51, 51), Mid = Color3.fromRGB(146, 146, 146), Tail = Color3.fromRGB(242, 242, 242), At = 0.5 } },   -- 2026-10-19 rework: both ribbons now sweep the same true charcoal(51)<->bone(242) range (was 77-242 / 128-242: the shadow ribbon's old 128 head read as mid-grey, not charcoal, and neither hit the full range), ratio 4.75:1 each (was 3.1:1 / 1.9:1)
		Finish = { Material = "Foil", Reflectance = 0, Pieces = { { Color = Color3.fromRGB(30, 30, 30), Material = "Foil", Reflectance = 0 },
			{ Color = Color3.fromRGB(90, 90, 90), Material = "Basalt", Reflectance = 0 }, { Color = Color3.fromRGB(205, 192, 170), Material = "Sandstone", Reflectance = 0 } } },
		-- (R2U round 2: Pieces -- the decoy's travelling pieces as a crisp mosaic, one look per body part: obsidian Foil,
		-- graphite Basalt, bone Sandstone; the material pass visible in sunlight, black at Reflectance 0. Mottle -- N crisp
		-- blotches painted along every ribbon, fixed in its length: charcoal on the light ribbons, pale ash on the shadow ones)
		Mottle = { N = 4, Width = 0.09, Edge = 0.2, Depth = 1, Min = 0.06, Max = 0.7, light = Color3.fromRGB(40, 40, 40), shadow = Color3.fromRGB(230, 230, 230) },
		Mark = { Lit = Color3.fromRGB(198, 178, 150), Reflectance = 0.12, Material = "Marble" },   -- (R2U round 2: veined Marble at 0.12; at 0.2 SmoothPlastic the marker mirrored the sky, #97A6BD)   -- the lit marker: a warm input renders neutral grey (2026-10-19 rework: Reflectance 0.12 -> 0.2, a touch more glossy-obsidian pop; this site is a warm mid-grey, not near-black, so this stays clear of the sky-mirror trap)
		Ash = { Share = 0.08, Texture = "rbxasset://textures/particles/SquareParticle.png",
			Colors = { Birth = Color3.fromRGB(235, 235, 235), Mid = Color3.fromRGB(160, 160, 160), Death = Color3.fromRGB(72, 72, 72) },
			At = 0.45, Alpha = 0.15, Size = 0.46, Flutter = 6, Life = { 2.0, 3.0 }, Speed = { 0.4, 1.0 }, Rise = 0.8, Drag = 1.6,
			Spin = 120, Near = 4 },   -- (Near: a ribbon head nearer the camera than this, in studs, sheds none: no flecks in the lens) (2026-10-19 rework: Size 0.32->0.46, Near 6->4 for legibility at 30% scale; Share stays at the +8% ceiling, untouched)
	},
}

-- UMBRA, EPIC (2026-10-19, agent U2): Wisplight -- a will-o'-wisp's corpse-light: a clean, saturated jade-cyan (hue ~162:
-- not Toxin's olive or lime, not Aqua's cyan), the dark silk deep teal, the glints pale mint; glowing and breathing like
-- a dying lure. Drawn by UmbraFX (the Palette block is the wrap). Epic = everything a Rare Umbra wrap has -- the ribbon
-- gradient (Ramp: bright head, dim teal tail), the decoy pieces' finish (Finish: Neon, self-lit), colour over life on
-- its particles -- plus Glow (every ribbon brighter with a LightEmission floor, every ball's rim/halo and light
-- brighter; Glow.Flare caps the Tell's additive flare so it stays jade), Pulse (2.25 s, +-15 %, held under Reduce
-- Flashing), Motes (pale-mint shimmer riding every ribbon's head at Share of its Default quads, plus a Burst share put out
-- at once where each ribbon is born -- the cast, the impact, the break, the open -- through the density helper; peak
-- Share + Burst = 15 % since round 2, 14.5 % before) and MarkGlow (the Mark marker self-lit, with a breathing jade light). (2026-10-19 rework, UR:
-- the owner's "not many effects": bigger, brighter, longer-lived motes, the bursts, the flare cap, the marker glow
-- with its own Neon inputs, Finish.Land so the Neon decoy pieces land matte instead of glowing lime;
-- Ramp heads 240,255,245 so no input sits within 12 of Zephyr's Light.) The violet baked into Umbra's strips and images is
-- cancelled by the multipliers (RibbonA.Rest, RibbonB.Tint, the tints) and the gains lift the green back. Every value
-- a PROPOSAL until signed off; listed in ElementWraps since 2026-10-19 for the owner's review, NOT approved.
-- ROUND 2 (R2U, 2026-10-19, still "not many effects"): pushed to the Epic ceiling -- motes 14 % steady + a 1 % burst at every
-- ribbon's birth (peak ~15 %), 30 % bigger and brighter; the shadow ribbons glow too (Gain 1.25, LightEmission floor
-- 0.25, under the Flare cap); the balls' rim/halo and light and the marker's light brighter (Ball 1.45, Light 1.8, MarkGlow 1.2).
SkinCatalog.Skins.Wisplight = { Id = "Wisplight", DisplayName = "Wisplight", Rarity = "Epic", Wrap = "Umbra",
	Label = { hex("#0E4C44"), hex("#3CF09B"), hex("#D6FFEC") },
	Palette = {
		Color = { Glint = hex("#D6FFEC"), Shade = hex("#3CF09B"), Dusk = hex("#0E4C44"), Void = hex("#021C16") },
		RevealColor = hex("#7CF5D2"),      -- Eclipse's outline on revealed enemies: pale jade (Default: light purple)
		RibbonA = { Lit = Color3.fromRGB(150, 255, 160),
			light = { Rest = Color3.fromRGB(80, 255, 80), Band = Color3.fromRGB(110, 255, 125), Untextured = hex("#4FF0C0") },
			shadow = { Rest = Color3.fromRGB(36, 255, 148), Band = Color3.fromRGB(77, 255, 191), Untextured = hex("#0E4C44") } },
		RibbonB = { Tint = { light = Color3.fromRGB(90, 255, 90), shadow = Color3.fromRGB(26, 255, 92) },
			Gain = { light = 1.38, shadow = 2.6 },
			Untextured = { light = hex("#4FF0C0"), shadow = hex("#0E4C44") } },
		BallBodyTint = Color3.fromRGB(120, 255, 215),
		ShadowSkin = hex("#187864"),       -- the decoy's pieces while they travel (Neon: Finish)
		Finish = { Material = "Neon", Reflectance = 0, Land = "SmoothPlastic" },   -- (Land: the pieces land matte, so the Neon never glows lime through the recolour to the body)
		-- (the gradient, per kind: every ribbon brightest at its head -- the lure -- dimming to a low teal at its tail)
		Ramp = { light = { Head = Color3.fromRGB(240, 255, 245), Mid = Color3.fromRGB(209, 230, 222), Tail = Color3.fromRGB(92, 122, 112), At = 0.45 },
			shadow = { Head = Color3.fromRGB(240, 255, 245), Mid = Color3.fromRGB(196, 216, 210), Tail = Color3.fromRGB(84, 110, 104), At = 0.5 } },
		PulseTint = hex("#C8FFEA"),        -- Eclipse's opening pulse
		Grade = { Ambient = Color3.fromRGB(40, 78, 70), OutdoorAmbient = Color3.fromRGB(46, 88, 78),
			AtmosphereColor = Color3.fromRGB(50, 102, 90), AtmosphereDecay = Color3.fromRGB(18, 56, 48),
			TintColor = Color3.fromRGB(160, 232, 210) },
		VignetteTint = Color3.fromRGB(51, 255, 77), EdgeTint = Color3.fromRGB(77, 255, 140),
		-- EPIC: the glow (A ribbons take Gain as their calibrated brightness; B ribbons Gain x RibbonB.Gain)
		Glow = { Gain = { light = 1.45, shadow = 1.25 }, Emission = { light = 0.35, shadow = 0.25 }, Ball = 1.45, Light = 1.8,
			Flare = 0.45 },   -- (Ball 1.8 clipped the jade rim to cyan-white; Flare: no ribbon's LightEmission above 0.45, the flag W1 fix)
		Pulse = { Period = 2.25, Amp = 0.15 },
		MarkGlow = { Light = 1.2, Range = 7, Lit = Color3.fromRGB(22, 124, 92), Dim = Color3.fromRGB(12, 74, 50), Color = Color3.fromRGB(40, 230, 175) },   -- (the marker's Neon inputs: Shade #3CF09B as Neon rendered #21FEFE, cyan)
		Motes = { Colors = { Birth = Color3.fromRGB(204, 255, 208), Mid = Color3.fromRGB(92, 244, 160), Death = Color3.fromRGB(30, 120, 100) },   -- (UR: 110,246,204 rendered hue 174, cyan; this renders ~160, jade)
			Name = "UmbraMotes", Share = 0.14, Burst = 0.01, Texture = "rbxasset://textures/particles/sparkles_main.dds",
			At = 0.45, Alpha = 0.08, Size = 0.65, Flutter = 3, Life = { 1.2, 2.0 }, Speed = { 0.5, 1.3 }, Rise = 1.1, Drag = 1.5,
			Spin = 60, Emission = 0.6, Brightness = 1.7, Near = 3 },   -- (R2U round 2: Share 0.12 -> 0.14 + Burst 0.025 -> 0.01, the top of the Epic band; Size 0.5 -> 0.65, Brightness 1.5 -> 1.7)
	} }

-- UMBRA, MYTHIC (2026-10-19, agent U2; reworked to WHITE AND GOLD the same day by UR, the owner's call: the first pass's
-- black and violet read as "same colour, more effects of default"): Umbral Eclipse -- a total eclipse worn on every move.
-- Void black stays the base (the dart's head a black disc and, since round 2, the round balls crystal orbs; the shadow ribbons a neutral near-black at every phase: Flow.Grey); the corona flowing through it is
-- platinum white and gold, the dominant hue; Baily's beads, gold-white glints, flicker on its edge; the balls' limb is a
-- thin gold ring. Drawn by UmbraFX. Two FULL signature levers: FLOW (the corona's Ink -> Pearl -> Platinum -> Gold run along
-- every ribbon and back, drifting one cycle per Flow.Period s, each ribbon Flow.Spread behind the one before; the decoy's
-- pieces and Eclipse's screen edges read it too) and TWINKLE (Baily's-bead glints riding every ribbon's head at Share of
-- its Default quads, density-scaled). Plus everything an Epic wrap has (Glow, Pulse, Motes with their Burst, MarkGlow)
-- and a Rare's finish (Metal). The white is a cool platinum and the gold keeps some blue, so no stop, no step between any
-- two stops and no display input comes within 12/255 of ANY Element's Base, Light or Dark (Radiant's warm white #FFF7D6
-- and gold #F5C230, Zephyr's #FFFFFF, Cryo's #DEF7FF and Terra's #CCBA5C sit closest). RibbonA and RibbonB.Tint cancel the
-- violet baked into Umbra's strips (fitted on swatches), so the flow renders as its own colours. Every value a PROPOSAL
-- until signed off; listed in ElementWraps since 2026-10-19 for the owner's review, NOT approved. ROUND 2 (R2U, 2026-10-19):
-- the round balls are a CRYSTAL ORB (BallOrb, the texture-reassignment pilot: the engine's own rbxasset images layered
-- inside the ball, white and gold, nothing uploaded); twinkles 18 % (0.65 studs) and motes 11 % + a 1 % burst: the Mythic ceiling.
SkinCatalog.Skins.UmbralEclipse = { Id = "UmbralEclipse", DisplayName = "Umbral Eclipse", Rarity = "Mythic", Wrap = "Umbra",
	Label = { hex("#1A1A1C"), hex("#E2E6EC"), hex("#FCC064") },
	Palette = {
		Color = { Glint = hex("#E2E6EC"), Shade = hex("#FCC064"), Dusk = hex("#2E2E32"), Void = hex("#060606") },
		RevealColor = hex("#FAE2AA"),      -- Eclipse's outline on revealed enemies: gold-white (Default: light purple)
		Rim = hex("#FCCE78"),               -- the balls' limb: a thin gold ring (the diamond ring)
		RibbonA = { Lit = Color3.fromRGB(218, 255, 167),
			light = { Rest = Color3.fromRGB(196, 230, 151), Band = Color3.fromRGB(218, 255, 167), Untextured = hex("#E2E6EC") },
			shadow = { Rest = Color3.fromRGB(96, 128, 60), Band = Color3.fromRGB(163, 217, 102), Untextured = hex("#2E2E32") } },
		RibbonB = { Tint = { light = Color3.fromRGB(211, 255, 168), shadow = Color3.fromRGB(163, 255, 104) },
			Gain = { light = 1.5, shadow = 1.2 },
			Untextured = { light = hex("#E2E6EC"), shadow = hex("#2E2E32") } },
		BallBodyTint = Color3.fromRGB(248, 230, 174),   -- the ball sprite's blue-black, rendered neutral black (swatch-fitted)
		ShadowSkin = hex("#FFE2BE"),       -- (x the flow) the decoy's pieces while they travel (warm: lit platinum drifts blue)
		Finish = { Material = "Metal", Reflectance = 0 },   -- (Metal: gold metal at the flow's gold, neutral at its platinum)
		PulseTint = hex("#FFE8BE"),
		Grade = { Ambient = Color3.fromRGB(44, 42, 40), OutdoorAmbient = Color3.fromRGB(50, 48, 46),
			AtmosphereColor = Color3.fromRGB(64, 60, 54), AtmosphereDecay = Color3.fromRGB(24, 22, 20),
			TintColor = Color3.fromRGB(236, 230, 220) },   -- Eclipse's world grade: a darkened, faintly warm world
		VignetteTint = Color3.fromRGB(137, 255, 76), EdgeTint = Color3.fromRGB(206, 255, 160),
		-- MYTHIC lever 1: the flow (the corona: void ink -> pearl -> platinum -> gold and back along each ribbon, over strips
		-- made neutral by RibbonA / RibbonB.Tint;
		-- Period 18 s keeps the fastest 1 s change under 25 %)
		Flow = { Stops = { Ink = Color3.fromRGB(26, 26, 28), Pearl = Color3.fromRGB(150, 150, 156), Platinum = Color3.fromRGB(226, 230, 236), Gold = Color3.fromRGB(252, 192, 100) },
			Order = { "Ink", "Pearl", "Platinum", "Gold" }, Along = 1, Period = 18, Spread = 0.7,
			Grey = { shadow = 1 } },   -- (Grey: the shadow ribbons take the flow's luminance only, so they stay the neutral void)
		-- MYTHIC lever 2: Baily's beads (gold-white glints on the corona's edge; the mechanics as before, bigger and a touch denser)
		Twinkle = { Colors = { Birth = Color3.fromRGB(255, 232, 170), Mid = Color3.fromRGB(250, 204, 112), Death = Color3.fromRGB(100, 100, 104) },
			Name = "UmbraTwinkle", Share = 0.18, Texture = "rbxasset://textures/particles/sparkles_main.dds",
			At = 0.35, Alpha = 0, Size = 0.65, Flutter = 4, Life = { 0.35, 0.7 }, Speed = { 0, 0.15 }, Rise = 0, Drag = 4,
			Spin = 0, Emission = 1, Brightness = 1.5, Near = 3 },
		-- Epic levers kept
		Glow = { Gain = { light = 1.6, shadow = 1.4 }, Emission = { light = 0.5, shadow = 0.1 }, Ball = 1.3, Light = 1.4 },   -- (light 1.6: the platinum glows white, the gold stays gold)
		Pulse = { Period = 2.5, Amp = 0.1 },
		-- THE CRYSTAL ORB (R2U round 2, the texture-reassignment pilot, round balls only: charge, hit core, Eclipse core):
		-- the engine's own images layered inside the ball sprite -- a glowing core, smoke light drifting gold <-> platinum,
		-- two lights orbiting inside the glass, refracted arcs and a glinting glass shell (the ForceField sphere art), a
		-- highlight. Nothing uploaded.
		BallOrb = { Layers = {
			{ Image = "rbxasset://textures/particles/explosion01_implosion_main.dds", Color = Color3.fromRGB(236, 232, 222), Size = 0.62 },
			{ Image = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(252, 192, 100), Color2 = Color3.fromRGB(226, 230, 236), Period = 18, Size = 0.95, Spin = 30 },
			{ Image = "rbxasset://textures/particles/explosion01_implosion_main.dds", Color = Color3.fromRGB(252, 192, 100), Size = 0.34, Orbit = { R = 0.2, Speed = 110, Tilt = 0.45 } },
			{ Image = "rbxasset://textures/particles/explosion01_implosion_main.dds", Color = Color3.fromRGB(226, 230, 236), Size = 0.26, Orbit = { R = 0.16, Speed = -80, Tilt = 0.5 } },
			{ Image = "rbxasset://textures/particles/forcefield_vortex_main.dds", Color = Color3.fromRGB(252, 192, 100), Size = 0.74, Spin = -22 },
			{ Image = "rbxasset://textures/particles/forcefield_vortex_main.dds", Color = Color3.fromRGB(226, 230, 236), Size = 1.0, Spin = 12 },
			{ Image = "rbxasset://textures/particles/explosion01_implosion_main.dds", Color = Color3.fromRGB(226, 230, 236), Size = 0.22, X = -0.17, Y = -0.2 },
		} },
		MarkGlow = { Light = 0.9, Range = 6, Lit = Color3.fromRGB(140, 110, 64), Dim = Color3.fromRGB(76, 72, 64), Color = Color3.fromRGB(236, 224, 196) },   -- (the marker's Neon inputs: #FCC064 as Neon blew out to #FEFEBD)
		Motes = { Colors = { Birth = Color3.fromRGB(236, 232, 222), Mid = Color3.fromRGB(244, 194, 100), Death = Color3.fromRGB(48, 48, 52) },
			Name = "UmbraMotes", Share = 0.11, Burst = 0.01, Texture = "rbxasset://textures/particles/sparkles_main.dds",
			At = 0.4, Alpha = 0.1, Size = 0.4, Flutter = 3, Life = { 1.2, 2.0 }, Speed = { 0.4, 1.0 }, Rise = 0.6, Drag = 1.5,
			Spin = 60, Emission = 0.5, Brightness = 1.4, Near = 3 },
	} }

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
SkinCatalog.Skins.Frostblade = { Id = "Frostblade", DisplayName = "Frostblade", Rework = true, Rarity = "Uncommon",   -- (2026-10-19, audit P5F-22: the tier its comment names)
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
-- CRYO'S FROST DRAGON SKIN (2026-10-15). (2026-10-19, audit P5A-23) stages 1-4 are built in FrostDragonFX -- the
-- Mirror Cage's curled dragon, the M1 Wyrmling, Flash Freeze's claw slam, the Blizzard's dragons, Cold Momentum's claw
-- prints, Deep Freeze's breath -- plus its kill effect (FrostDragonKillFX); not yet signed off as finished, and it is
-- selectable live (ElementSkins). The Mythic top of Cryo's ladder: one lean western dragon of glowing ice crystal across
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
-- In ElementWraps since 2026-10-20 (the owner: "import it." after the crystal-flow fix).
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

-- (2026-10-25) RADIANT'S LADDER, live in ElementWraps.Radiant since 2026-10-25 (approved by the owner after the polish
-- pass and Moonlight's rounds 3-5). Each is a palette RadiantDraw paints the Default forms with (Stops along the
-- strokes; CoreLift / MaxBright / LEScale its tone) plus a Look block (RadiantDraw: THE LADDER'S LOOKS) that nothing
-- but these wraps sets -- Rainbow and the Devil skin draw exactly as before. All four sit away from Radiant's own warm
-- white-gold (Base #F5C230, Light #FFF7D6): cool silver, jewel glass, an indigo night, a cycling cool opal.
-- MOONLIGHT, Uncommon: pale silver and cool blue-white, flat -- two near stops, the Trade body glow silver, nothing added.
SkinCatalog.Skins.Moonlight = { Id = "Moonlight", DisplayName = "Moonlight", Rarity = "Uncommon", Wrap = "Radiant", Flat = true,
	-- (round 2: the first pass washed to Default's white under the white-hot core and bloom -- deeper silver-blue stops,
	-- a cool, lower core and a brightness cap so the colour holds)
	-- (round 3, 2026-10-25 polish pass, the owner: Moonlight's Halo and Blessing read as Default's white-gold. The stops were
	-- ~25-30% saturated and 65% additive over the bright sky, so every hue went white. Now steel-blue silver stops, a
	-- near-opaque blend (LEScale 0.12: the hue stays the hue over the sky) and a low cool core. Still a flat recolour.)
	-- (round 4, 2026-10-25, the owner: round 3 "looks superbad" -- thin scratchy lines. LEScale 0.12 and the MaxBright cap took
	-- away the additive glow and bloom that make Default's ring and wings read solid. Now Default's own blend and
	-- brightness (no LEScale, no MaxBright: the same weight), the cool read carried by deep saturated blue stops that stay
	-- blue once added onto the sky, and a blue-white core.)
	-- (round 5, 2026-10-25, the owner: "it looks similar to starlight" -- fully GREY now: every colour R = G = B, the value
	-- range kept (mid-grey sleeve, light-grey core); the blend and brightness of round 4 untouched, so the weight holds)
	-- (the first greys #9A9A9A / #C2C2C2 / #7C7C7C with a #E0E0E0 core read as plain white, next to Default's white: the
	-- value range pushed darker, still R = G = B)
	Stops = { hex("#6A6A6A"), hex("#9C9C9C"), hex("#555555") },
	CoreLift = 0.2, LEScale = 0.7, MaxBright = 1.7,   -- (the owner: "reduce glow, so many grey pops" -- 70% of Default's blend, a
	-- brightness cap: the glare and white bloom pops go, the ring and wings stay solid; 50% / 1.5 went thin again)
	Look = { CoreTo = hex("#D0D0D0"), BodyGlow = hex("#8C8C8C") },
	Palette = { Main = hex("#B4B4B4"), Shadow = hex("#7C7C7C"), Highlight = hex("#E0E0E0"), Accent = hex("#9A9A9A") },
}
-- STAINED GLASS, Rare: jewel panels -- ruby, sapphire, emerald, amethyst -- run along every stroke as hard-edged facets
-- with dark lead lines between them (the finish); the core is the glass lit from behind (CoreLift 0.35); sparkles and
-- lights take the jewels. Partly alpha-blended (LEScale 0.6) so the jewels keep their colour. No glow boost, no pulse.
SkinCatalog.Skins.StainedGlass = { Id = "StainedGlass", DisplayName = "Stained Glass", Rarity = "Rare", Wrap = "Radiant",
	Flat = true, Stops = { hex("#C8102E"), hex("#1F4FD0"), hex("#12A05A"), hex("#7B2FC8") },
	CoreLift = 0.35, LEScale = 0.45,   -- (polish 2026-10-25: 0.6 -> 0.45, Lead 0.1 -> 0.16 and darker: crisper facets)
	Look = { BodyGlow = hex("#1F4FD0"), Facets = { Len = 1.3, Lead = 0.16, LeadColor = hex("#0D0F15"),
		Colors = { hex("#C8102E"), hex("#1F4FD0"), hex("#12A05A"), hex("#7B2FC8") } } },
	Palette = { Main = hex("#1F4FD0"), Shadow = hex("#15171E"), Highlight = hex("#12A05A"), Accent = hex("#C8102E") },
}
-- STARLIGHT, Epic: a deep indigo-navy night on every form (alpha-blended, LEScale 0.3, so the dark reads), its core a cool
-- starlight glow (CoreTo), glowing pinpoint stars set along the strokes (Stars: Rate of the spans x Graphics Quality),
-- a slow breath (2.25 s, +/-15%), starlight lights and Trade glow.
SkinCatalog.Skins.Starlight = { Id = "Starlight", DisplayName = "Starlight", Rarity = "Epic", Wrap = "Radiant", Flat = true,
	Stops = { hex("#1A2350"), hex("#2A2F78"), hex("#1C1C48") },
	CoreLift = 0.5, LEScale = 0.3, MaxBright = 1.55,   -- (polish 2026-10-25: 1.4 -> 1.55, stars 0.16/0.22/2.4 -> 0.22/0.25/2.8)
	Look = { CoreTo = hex("#AFC4FF"), LightColor = hex("#B8C8FF"), BodyGlow = hex("#2A2F78"), Pulse = { Period = 2.25, Amp = 0.15 },
		Stars = { Rate = 0.22, Size = 0.25, Color = hex("#F2F0FF"), Bright = 2.8 } },
	Palette = { Main = hex("#2A2F78"), Shadow = hex("#1A2350"), Highlight = hex("#F2F0FF"), Accent = hex("#AFC4FF") },
}
-- PRISM BLOOM, Mythic: opal -- cool blue, pale rose, mint, periwinkle -- that FLOWS: the palette slides along every
-- stroke, one slow pass in 12 s (fewer, coarser steps on LOW / MEDIUM), an opal-white core, a breath, and TWINKLES
-- (sparse glints that flash and fade). No magenta: the pink is a pale rose (#F4A6D6, the Sparks mark is #E91E8C).
SkinCatalog.Skins.PrismBloom = { Id = "PrismBloom", DisplayName = "Prism Bloom", Rarity = "Mythic", Wrap = "Radiant", Flat = true,
	-- (round 4, 2026-10-25, the owner: "fix prism bloom" -- rendered, round 3 was ~62% blue with pink and green ~4% each:
	-- two of its five stops were blue, the blends ran through lavender and grey, and the additive blend over the blue sky
	-- and floor turned every hue blue-white.) Now pink and green are held as long as the blue between them, the blend is
	-- near-opaque (LEScale 0.1, so a hue stays that hue over the sky) and bright (MaxBright 2.4), the core barely lifted.
	-- Measured in Play, Default-relative: pink ~31% / green ~30% / blue ~30% of the colour the effect adds.
	Stops = { hex("#FF7FAE"), hex("#FF7FAE"), hex("#4C8DFF"), hex("#3DEB8C"), hex("#3DEB8C") },
	CoreLift = 0.05, LEScale = 0.1, MaxBright = 2.4,
	-- (polish 2026-10-25: Cycle 10 -> 7 s, Pulse Amp 0.12 -> 0.16, twinkles Rate 0.2 -> 0.24 and Bright 2.8 -> 3.2)
	Look = { CoreTo = hex("#EEEAFF"), BodyGlow = hex("#B6B8FF"), Cycle = { Period = 7 }, Pulse = { Period = 2.5, Amp = 0.16 },
		Stars = { Rate = 0.24, Size = 0.24, Color = hex("#F4EEFF"), Bright = 3.2, Twinkle = true } },
	-- (BodyGlow: the fallback only -- RadiantFX_Hand runs Position Trade's body flash through the cycle for a Cycle look)
	Palette = { Main = hex("#4C8DFF"), Shadow = hex("#8A86FF"), Highlight = hex("#FF7FAE"), Accent = hex("#3DEB8C") },
}



SkinCatalog.Offer = {
	-- (Radiant: no per-ability rows since 2026-10-25 -- its wraps are Element wraps (ElementWraps.Radiant), worn on all
	-- five abilities; the server still stamps the caster's wrap on each broadcast through Chosen)
	-- (Pyro: no per-ability rows since 2026-10-24 -- its wraps are Element wraps (ElementWraps.Pyro), drawn on the six
	-- flame-look abilities -- PyroFX wrapOf)
	-- (Terra: no per-ability rows since 2026-10-25 -- its wraps are Element wraps (ElementWraps.Terra), worn on all six
	-- abilities; the server still stamps the caster's wrap on Boulder Shot / Bulwark broadcasts through Chosen)
	-- (Umbra: no per-ability rows since 2026-10-19 -- its wraps are Element wraps, offered through ElementWraps once approved)
}

-- the Element each skinned ability belongs to (a Technique's origin)
SkinCatalog.Origin = { LightLance = "Radiant", Blessing = "Radiant", Halo = "Radiant", PositionTrade = "Radiant",
	Benediction = "Radiant", BoulderShot = "Terra", BulwarkCharge = "Terra", Bedrock = "Terra",
	Aftershock = "Terra", BulwarkWall = "Terra", EarthenTomb = "Terra",
	Fireball = "Pyro", Immolate = "Pyro", EmberRefund = "Pyro", RingofFire = "Pyro", Detonate = "Pyro",
	ScorchingLash = "Pyro",
	ShadowDart = "Umbra", ShadowStep = "Umbra", Eclipse = "Umbra", Mark = "Umbra", DecoyDouble = "Umbra" }
-- (RingofFire: the Loadout keys an Ultimate by its name with the spaces taken out)

-- THE WRAPS CARD'S MARK follows the equipped Element (2026-10-10): its own wrap's mark, or a palette -- neutral for an
-- Element with no wraps, in its wraps' colours for one that has some (2026-10-19, audit GA-14; WrapsOf below)
SkinCatalog.WrapIcon = { Radiant = "Stripes", Pyro = "Drop" }

SkinCatalog.Kinds = {
	RadiantLance = "LightLance", RadiantBlessing = "Blessing", RadiantOverflow = "Blessing", RadiantHalo = "Halo",
	RadiantTrade = "PositionTrade",
	RadiantBenediction = "Benediction",
	BoulderChargeStart = "BoulderShot", BoulderShot = "BoulderShot", BulwarkCharge = "BulwarkCharge",
	BulwarkHit = "BulwarkCharge",
}

--- (2026-10-19, audit P5F-22) the LONGEST matching prefix wins: pairs() has no order, so two overlapping prefixes would
--- otherwise resolve differently from run to run
function SkinCatalog.AbilityOfKind(kind)
	if type(kind) ~= "string" then return nil end
	local best, bestLen = nil, 0
	for prefix, key in pairs(SkinCatalog.Kinds) do
		if #prefix > bestLen and string.sub(kind, 1, #prefix) == prefix then
			best, bestLen = key, #prefix
		end
	end
	return best
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
-- TOXIN'S PIXEL POTION SKIN (2026-10-20; an UNCOMMON Element Skin, Frostblade's tier): every Toxin piece one blocky,
-- Minecraft-style voxel potion bottle -- the M1's bubble, Corrosive Cloud's lobes, Symbiosis's thread heads, Patient Zero's
-- mark and burst, the Antitoxin Vent's face bottle, Acid Rain's cloud and rain. No palette (Toxin's colours stay its own):
-- the forms are PixelPotionKit's, drawn by ToxinFX's hooks gated on PixelPotionKit.On. Approved by the owner 2026-10-20:
-- live in Toxin's SKINS page (in Studio a StudioSkin = "PixelPotion" body still stands in for tests).
SkinCatalog.Skins.PixelPotion = { Id = "PixelPotion", DisplayName = "Pixel Potion", Rework = true, Rarity = "Uncommon",
	Blurb = "VOXEL POTION BOTTLES, EVERYWHERE",
	Label = { hex("#3D4610"), hex("#6B7A1E"), hex("#C9E077"), hex("#E8F2A0") } }
SkinCatalog.ElementSkins.Toxin = { "Default", "PixelPotion" }      -- (2026-10-20, owner approved)
-- SCORPION (2026-10-21; Toxin's RARE Element skin -- planned Epic, demoted when Witch's Brew took Epic): one chitin-plate
-- and venom-glass family with seam-only glow -- a cracking venom gland for the M1, an etched, chitin-dusted miasma, a
-- venom thread for the siphon, a sigil ring and a ground-tail stab for the Ultimate -- and the one flagged avatar piece:
-- a segmented tail at the lower back that performs only in the Ultimate, Acid Rain and the Vent (the owner's one-off
-- exception at Rare, not a precedent). Drawn by ScorpionKit + ScorpionFX through ToxinFX's skin hooks, gated on
-- ScorpionKit.On. Rare: no Hud entry, no IconAssets set. NOT in ElementSkins until the owner approves the checkpoint
-- (in Studio a StudioSkin = "Scorpion" body stands in).
SkinCatalog.Skins.Scorpion = { Id = "Scorpion", DisplayName = "Scorpion", Rework = true, Rarity = "Rare",
	Blurb = "A TAIL THAT STINGS: CRACK, ETCH, STAB, RAIN",
	Label = { hex("#1A1208"), hex("#3E2B14"), hex("#8FAE2A"), hex("#D8EC7A") } }   -- (amber-black chitin, venom green)
-- (2026-10-21) Scorpion approved by the owner: live in ElementSkins.Toxin below
-- WITCH'S BREW (2026-10-20; Toxin's EPIC Element skin -- promoted from the Rare plan; Scorpion takes Rare): a worn
-- cauldron-backpack (the one flagged avatar-reaching exception, owner-asked), all purple over black iron: a tumbling brew
-- glob, a simmering pot of bubbles for the cloud with a steam tether, a siphon ribbon, the Vent's herb tossed from the
-- pouch into the brew with ward-vapor over the mouth, the cauldron clamped onto the Ultimate's target's head, Acid Rain
-- boiling over. Drawn by WitchsBrewKit + WitchsBrewFX through ToxinFX's BREW hooks, gated on WitchsBrewKit.On.
-- Approved by the owner 2026-10-20 (checkpoint round 6b): live in Toxin's SKINS page (in Studio a StudioSkin =
-- "WitchsBrew" body still stands in for tests; HudSkinPreview_Toxin = "WitchsBrew" previews the HUD set).
SkinCatalog.Skins.WitchsBrew = { Id = "WitchsBrew", DisplayName = "Witch's Brew", Rework = true, Rarity = "Epic",
	Blurb = "A CAULDRON ON YOUR BACK: SPLASH, STEEP, STIR, ERUPT",
	Label = { hex("#1E1230"), hex("#3A1F66"), hex("#7A46E0"), hex("#D9C6FF") } }   -- (the kit's purples: iron, cloth, brew, steam)
SkinCatalog.ElementSkins.Toxin = { "Default", "PixelPotion", "Scorpion", "WitchsBrew" }   -- (2026-10-21, owner approved Scorpion)
-- HYDRA (2026-10-21; Toxin's MYTHIC Element skin, its top tier): one venomous many-headed serpent across the whole kit --
-- a shoulder head that bites-and-spits the M1 and exhales the cloud, a throat vein that feeds on Symbiosis, three heads
-- that bite the mark on and strike the burst, a hinged hydra-skull faceplate for the Vent, small heads spitting Acid
-- Rain -- plus its kill effect (HydraKillHook + HydraFX, "The Hydra's Due"). Drawn by HydraKit + HydraFX through
-- ToxinFX's skin hooks, gated on HydraKit.On. Its HUD set is mapped (2026-10-23: SkinCatalog.Hud.Hydra +
-- IconAssets.Ability.Skins.Hydra, placeholder ids until the owner uploads the art; preview in Studio with
-- HudSkinPreview_Toxin = "Hydra"). LIVE in ElementSkins.Toxin since 2026-10-23 (the owner put it in the skins section).
SkinCatalog.Skins.Hydra = { Id = "Hydra", DisplayName = "Hydra", Rework = true, Rarity = "Mythic",
	Blurb = "MANY HEADS, ONE VENOM: BITE, COIL, STRIKE",
	Label = { hex("#0E1A10"), hex("#244028"), hex("#8CAF50"), hex("#E2DABA") } }   -- (jade scale, venom glow, ivory fang)
SkinCatalog.ElementSkins.Toxin = { "Default", "PixelPotion", "Scorpion", "WitchsBrew", "Hydra" }   -- (2026-10-23, the owner: "make it in skin sections too")
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

-- AQUA'S WRAPS (2026-10-19, agent A1; drawn by IceMagic.AquaWrap). Aqua's colours are baked in its kit meshes' vertex
-- colours, so a wrap is a vertex ramp: Water runs Default's blue family by its lightness (Default luma 0-255: the wet
-- ground ~13, the navy trough ~64, the body ~122, the lit blue ~162, the palest ~213) onto the named Tone colours, Foam
-- takes the pale vertices as they lose saturation; Color = AquaTuning.Color keys (the Tideline-family lines). Tone holds
-- the DISPLAY inputs (what the vertices carry), measured on swatches under the map light. NOT in ElementWraps until the
-- owner approves the checkpoint.
-- Riptide Jade, Uncommon: a flat recolour -- jade-teal water in Default's own shade order, sandy-tan foam, and the
-- Tideline-family lines in the water's own jade (R2A 2026-10-19: the owner found the amber accent line looked bad, so it
-- is no longer a separate accent -- like Default's light-blue line, it is its own water's lit colour). Shark, fin, jaw and
-- rocks keep Default. No new pieces.
SkinCatalog.Skins.RiptideJade = { Id = "RiptideJade", DisplayName = "Riptide Jade", Rarity = "Uncommon", Wrap = "Aqua",
	Label = { hex("#00BE9B"), hex("#EBD7AA"), hex("#46DEA0") },
	Palette = {
		Tone = { Wet = hex("#18301F"), Deep = hex("#1B4434"), Body = hex("#3DAC80"), Lit = hex("#62CB84"), Top = hex("#A2DE9E"),
			FoamShade = hex("#D2A874"), Foam = hex("#F6C27E") },
		Water = { { 13, "Wet" }, { 64, "Deep" }, { 122, "Body" }, { 162, "Lit" }, { 213, "Top" } },
		Foam = { { 170, "FoamShade" }, { 213, "Foam" } }, FoamSat = { 0.6, 0.35 },
		Color = { Tideline = hex("#4E7D6F"), TidelineDim = hex("#436058"), TidelineDark = hex("#1B4434"),   -- (Neon inputs: render the lit
			UndertowTip = hex("#5D8073"), Flash = hex("#678476"), TwinLine = hex("#497468"), TwinLineDark = hex("#2B5E4A"),   -- jade ~#2BE4BD, dim
			TwinFlash = hex("#4E7D6F") } } }   -- #0E8A72, tips #67E6C8 / #8CEBD2, Twin lines the body #1AC9A6; the dark ones lit SmoothPlastic)
-- Deep Brine, Rare: a gradient and finish pass -- near-black indigo-violet in the depths lightening to grey-green at the
-- surface (the water ramp), a gloss on the wet pieces (Gloss: Reflectance where Default's lightness is at least MinY),
-- kelp-brown rocks (Debris) and drifting sediment and bubble trails (Drift: Share of each effect's Default pieces, carried
-- per caster and effect; R2A 2026-10-19: twice the size, longer lives, a short trail each, so they read in play view). The
-- Tideline-family lines are a pale lavender-silver (R2A: their sea-glass green read as a saturated green border).
SkinCatalog.Skins.DeepBrine = { Id = "DeepBrine", DisplayName = "Deep Brine", Rarity = "Rare", Wrap = "Aqua",
	Label = { hex("#20163E"), hex("#7AA08C"), hex("#6B4A24") },
	Palette = {
		Tone = { Wet = hex("#221C2C"), Deep = hex("#3A2C48"), Body = hex("#706870"), Lit = hex("#839478"), Top = hex("#A2B28C"),
			FoamShade = hex("#9AA484"), Foam = hex("#B8C89D"), KelpDark = hex("#3A2A20"), Kelp = hex("#664B2C"), KelpLit = hex("#7E603A"),
			Sediment = hex("#735534"), SedimentMid = hex("#5C432C"), SedimentEnd = hex("#45341F"),
			Bubble = hex("#AAB894"), BubbleMid = hex("#C8CCA6"), BubbleEnd = hex("#DCDCBA") },
		Water = { { 13, "Wet" }, { 64, "Deep" }, { 122, "Body" }, { 162, "Lit" }, { 213, "Top" } },
		Foam = { { 170, "FoamShade" }, { 213, "Foam" } },
		Debris = { { 40, "KelpDark" }, { 80, "Kelp" }, { 120, "KelpLit" } },
		Mesh = { AK_LM_Rock = "Debris" }, SimTint = hex("#FF3D36"),   -- (a multiply: the flipbook's blue x this = near-black indigo-violet)
		Gloss = { Reflectance = 0.25, MinY = 140 },
		Drift = { Share = 0.08, Sediment = { "Sediment", "SedimentMid", "SedimentEnd" }, Bubble = { "Bubble", "BubbleMid", "BubbleEnd" },
			SedimentSize = 0.42, SedimentLife = 2.4, Sink = 0.9, BubbleSize = 0.45, BubbleLife = 2.2, Rise = 3, BubbleGloss = 0.3,
			Trail = { Life = 0.5, T = 0.35, Width = 0.8 } },
		Color = { Tideline = hex("#747B7A"), TidelineDim = hex("#4A494E"), TidelineDark = hex("#2A2530"),   -- (Neon inputs: render
			UndertowTip = hex("#79817E"), Flash = hex("#7D8680"), TwinLine = hex("#686D70"), TwinLineDark = hex("#37294A"),   -- #C8C6E6, #3A3852,
			TwinFlash = hex("#747B7A") } } }   -- tips #D8D6F0 / #E6E4F6, Twin lines #A09EC4: pale lavender-silver)

-- Moonjelly, Epic: bioluminescent jellyfish light -- deep midnight water whose lit body glows a soft cyan-white and
-- breathes (Glow: self-lit, Pulse: 2.25 s, +-15% on screen), drifting plankton motes (Motes) and a few rising bubbles (Drift):
-- 4% + 11% = 15% of each effect's Default pieces (R2A 2026-10-19: motes at the top of the band, 0.5 studs, longer lives). Cryo's identity is a hard rim light; this is a slow breathing glow.
-- DISPLAY INPUTS: the self-lit pieces (Neon) render through the place's steep grade (~x4 contrast, red crushed), so the
-- ramp and line hexes are the calibrated inputs; the rendered targets are in the comments (A2 swatches 2026-10-19).
SkinCatalog.Skins.Moonjelly = { Id = "Moonjelly", DisplayName = "Moonjelly", Rarity = "Epic", Wrap = "Aqua",
	Label = { hex("#081A40"), hex("#E8FEFF"), hex("#9AF0F4") },
	Palette = {
		Tone = { Wet = hex("#0A1428"), WetEdge = hex("#10203A"),                 -- (the wet ground: lit, dark navy)
			Deep = hex("#5B5868"), Body = hex("#738BA1"), Lit = hex("#ABD8CC"), Top = hex("#C8E3D3"),   -- renders #081A40 / #2A62A8 / #9AF0F4 / #DDFCFF
			FoamShade = hex("#B8DCCF"), Foam = hex("#CCE4D4"),                    -- renders #B8F4F8 / #E8FEFF
			Plankton = hex("#7A8C83"), PlanktonMid = hex("#5F7F7C"), PlanktonEnd = hex("#485D6C"),   -- renders #D6FCFF / #6FE0F0 / #2A78C8
			Speck = hex("#2E5E9A"), SpeckMid = hex("#3C78B0"), SpeckEnd = hex("#1E3E70"),
			Bubble = hex("#9EE6F0"), BubbleMid = hex("#C8F6F6"), BubbleEnd = hex("#C8F4FA") },
		Water = { { 13, "Wet" }, { 42, "WetEdge" }, { 64, "Deep" }, { 122, "Body" }, { 162, "Lit" }, { 213, "Top" } },
		Foam = { { 170, "FoamShade" }, { 213, "Foam" } },
		StandIn = hex("#FFE6C4"), SimTint = hex("#FFE6C4"),   -- (R2A: off Radiant's Light #FFF7D6)   -- (a piece whose copy is not built, and the Twin Tide flipbook frames
		                                                         -- AquaWrap never copies: this multiply over Default's blue, glowing)
		Glow = { NeonK = 0.62, Skip = { "AK_WG_Puddle", "AK_WG_Streak", "AK_LM_Shade" } },
		Pulse = { Period = 2.25, Amp = 0.058 },   -- (+-15% ON SCREEN: the grade swings a Neon body ~2.6x its brightness change; 0.15 rendered +-39%)
		Motes = { Share = 0.11, Size = 0.5, Life = 2.6, Speed = 1.2, Rise = 0.35, Spread = 1.8,
			Colours = { "Plankton", "PlanktonMid", "PlanktonEnd" } },
		Drift = { Share = 0.04, Sediment = { "Speck", "SpeckMid", "SpeckEnd" }, Bubble = { "Bubble", "BubbleMid", "BubbleEnd" },
			SedimentSize = 0.16, SedimentLife = 1.6, Sink = 0.6, BubbleSize = 0.18, BubbleLife = 1.3, Rise = 3.5, BubbleGloss = 0.2 },
		Color = { Tideline = hex("#63857E"), TidelineDim = hex("#435258"), TidelineDark = hex("#10243E"),   -- render #7FF0F4 / #1A5A78 / lit
			UndertowTip = hex("#768B83"), Flash = hex("#7F8E83"), TwinLine = hex("#547779"), TwinLineDark = hex("#182452"),   -- #C8FAFF / #E8FEFF / #4AC8EA
			TwinFlash = hex("#6B8780") } } }   -- renders #9CF4F8
-- Maelstrom, Mythic: a dark teal-violet-black vortex whose colour FLOWS (R2A 2026-10-19, rebuilt after the owner saw no
-- flow: the first field drifted ~0.5 studs/s and read as a still tint). Flow: one world-space field -- streaks laid along
-- one current, colour carried down them at Speed studs/s and the cycle sliding -- painted per vertex into the wrap's own
-- copies of the big bodies (no extra copies); every other water piece takes the field at its centre. Windblown spray
-- curtains coloured from the field (Curtains: the light layers), and the Epic levers in its own colours. Extra pieces:
-- 5% bubbles + 8% glints + 17% spray = 30% of each effect's Default pieces. Display inputs as Moonjelly's (rendered targets
-- in the comments).
SkinCatalog.Skins.Maelstrom = { Id = "Maelstrom", DisplayName = "Maelstrom", Rarity = "Mythic", Wrap = "Aqua",
	Label = { hex("#08090C"), hex("#00706A"), hex("#6A44D0") },
	Palette = {
		Tone = { Wet = hex("#000A0C"), WetEdge = hex("#001418"),   -- (R2A: both off Umbra's Dark #0D0817)
			Deep = hex("#616164"), Body = hex("#698387"), Lit = hex("#729B9E"), Top = hex("#96BBB8"),   -- renders #021014 / #0C5060 / #1A7C90 / #64B0C0
			FoamShade = hex("#A7C4BC"), Foam = hex("#C4DBCE"),                    -- renders #8CBCC4 / #C8E2E6
			Violet = hex("#867CAE"), Violet2 = hex("#8E86B6"), DeepViolet = hex("#6A6280"), Void = hex("#635E61"), Teal = hex("#67928D"),
			Crest = hex("#7AC1AE"),   -- render #5A34C0 / #6A44D0 / #1C0C5A / #08090C / #00706A / #1EC8AA (R2A: teal and crest moved
			                          -- off Zephyr's Base #4FD1C5 and Dark #125C59, the deep violet bluer, off Umbra's purple; it keeps the
			                          -- violet side purple: without it the grade turned violet-into-black navy)
			ShowViolet = hex("#5A34C0"), ShowViolet2 = hex("#6A44D0"), ShowDeepViolet = hex("#1C0C5A"), ShowVoid = hex("#00080A"),
			ShowTeal = hex("#00706A"), ShowCrest = hex("#14AAA0"),   -- (the curtains: Beams take the rendered colours)
			Glint = hex("#72767F"), GlintMid = hex("#5D7877"), GlintEnd = hex("#514D69"),   -- render #C4B4FF / #6FC8E0 / #5A3CC0
			Spray = hex("#C4DCD8"), SprayMid = hex("#9ABEBA"), SprayEnd = hex("#6E8E96"),
			Speck = hex("#2A3040"), SpeckMid = hex("#3A3A5C"), SpeckEnd = hex("#1C1C30"),
			Bubble = hex("#8CC8C2"), BubbleMid = hex("#B2DCD6"), BubbleEnd = hex("#D2ECE8") },
		Water = { { 13, "Wet" }, { 42, "WetEdge" }, { 64, "Deep" }, { 122, "Body" }, { 162, "Lit" }, { 213, "Top" } },
		Foam = { { 170, "FoamShade" }, { 213, "Foam" } },
		StandIn = hex("#FFF0A0"), SimTint = hex("#FFF0A0"),
		Glow = { NeonK = 0.6, Skip = { "AK_WG_Puddle", "AK_WG_Streak", "AK_LM_Shade" } },
		Pulse = { Period = 3, Amp = 0.03 },   -- (about +-8% on screen, Aurora's lighter breath)
		Motes = { Share = 0.08, Size = 0.32, Life = 2.2, Speed = 1.4, Rise = 0.4, Spread = 2, Colours = { "Glint", "GlintMid", "GlintEnd" } },
		Drift = { Share = 0.05, Sediment = { "Speck", "SpeckMid", "SpeckEnd" }, Bubble = { "Bubble", "BubbleMid", "BubbleEnd" },
			SedimentSize = 0.16, SedimentLife = 1.4, Sink = 0.8, BubbleSize = 0.18, BubbleLife = 1.2, Rise = 4, BubbleGloss = 0.15 },
		-- (R2A: a CYCLE -- teal, a bright crest, teal, a thin black void, deep violet, violet, bright violet and back through the
		-- void -- so teal and violet never blend, and the colour never jumps. Pos spaces the stops by how far the inputs move,
		-- so no point changes faster than Aurora's 25% a second at the field's top rate)
		Flow = { Stops = { "Teal", "Crest", "Crest", "Teal", "Void", "DeepViolet", "Violet", "Violet2", "Violet2", "Violet", "DeepViolet", "Void", "Teal" },
			Pos = { 0, 0.115, 0.185, 0.3, 0.41, 0.475, 0.593, 0.615, 0.685, 0.708, 0.82, 0.885, 1 }, Linear = true,
			Show = { "ShowTeal", "ShowCrest", "ShowCrest", "ShowTeal", "ShowVoid", "ShowDeepViolet", "ShowViolet", "ShowViolet2", "ShowViolet2",
				"ShowViolet", "ShowDeepViolet", "ShowVoid", "ShowTeal" },
			Dir = { 0.8, 0.35, 0.5 }, Across = 22, Vert = 16, Warp = 1.1, WarpL = 18,   -- (the bands: along the current, cached)
			Cycle = 0.08, Speed = 6, Wave = 24, Bend = 0.6, BrightAmp = 0.04, HueAmp = 0,   -- (the bands slide ~1.8 studs/s; a light
			                                                                       -- swell runs down the current at 6 studs/s)
			TintMix = 0.9, Shade = 0.35, Hues = { { 150, 200 }, { 225, 290 } },
			Big = { "AK_RT_Wave", "AK_RT_Break", "AK_TT_Wall", "AK_TT_Lip", "AK_TT_Cap", "AK_TT_Collar", "AK_TT_Jet", "AK_LM_Flood",
				"AK_LM_Wall", "AK_LM_Roof", "AK_UT_Inner", "AK_UT_Eye", "AK_UT_Head", "AK_SA_Coil" },
			Budget = { 1500, 750, 0 } },   -- (vertices painted a frame by Graphics Quality: each copy is refreshed often enough that
			                                   -- no repaint steps a vertex more than a few percent)
		Curtains = { On = { AK_RT_Wave = 2, AK_TT_Lip = 5, AK_LM_Rim = 8 }, Height = 9, Lean = 0.6, Back = 1.2, T = 0.15,
			Speed = 0.6, Sway = 1.6, Curl = 2.2, Fan = 2, WidthK = 1.3, Emission = 0.8, Influence = 0.15, Brightness = 2.4,
			Lift = 0.12, LiftUp = 0.12 },   -- (R2A: brighter, denser, the field's colour kept in them: light layers, not fog)
		Spray = { Share = 0.17, Size = 0.3, Life = 0.9, Wind = 14, Drag = 1.4, Gravity = 22, Colours = { "Spray", "SprayMid", "SprayEnd" } },
		Color = { Tideline = hex("#587779"), TidelineDim = hex("#424854"), TidelineDark = hex("#0C1A22"),   -- render #5AC8E8 / #1E3870 / lit
			UndertowTip = hex("#6A827D"), Flash = hex("#737880"), TwinLine = hex("#476764"), TwinLineDark = hex("#141E3A"),   -- #9CE4F0 / #C8BCFF / #1E9EA0
			TwinFlash = hex("#5D7977") } } }   -- renders #6CCCE0

-- AN ELEMENT'S COLOUR WRAP (2026-10-15, Cryo first): one per Element, worn over the Default shapes or over the Element's
-- skin (CryoWrap paints the skin's pieces). Attribute ElementWrap_<Element>, set through the "ElementWrap" request.
SkinCatalog.ElementWraps = { Cryo = { "Default", "MintRime", "DeepGlacier", "BlackIce", "SakuraFrost", "Aurora" },   -- (Aurora: imported 2026-10-20 at the owner's word, "import it.")
	Toxin = { "Default", "Nightshade", "CoralSnake", "PoisonDartFrog", "Octopus" },   -- (Octopus: Studio only, for the owner to test, 2026-10-19)   -- (Nightshade, Coral Snake, Poison Dart Frog approved 2026-10-18)
	-- Aqua and Umbra ladders: listed 2026-10-19 at the owner's word ("import both to studio, better to decide that way")
	-- so they can be tried from the WRAPS page. NOT approved yet: remove any the owner rejects before publishing.
	Aqua = { "Default", "RiptideJade", "DeepBrine", "Moonjelly", "Maelstrom" },
	Umbra = { "Default", "Bloodmoon", "Ashen", "Wisplight", "UmbralEclipse" },
	-- (2026-10-24) Pyro moved here from Offer (Azure Flame was already live per ability). The rest of its ladder -- Ashfire,
	-- Solar Flare, Phoenix, Void Flame -- approved by the owner 2026-10-24 after the round 3-4 checkpoints ("make them in
	-- wraps section for pyro")
	Pyro = { "Default", "AzureFlame", "Ashfire", "SolarFlare", "Phoenix", "VoidFlame" },
	-- (2026-10-25) Terra moved here from Offer: Obsidian Magma was already live per ability, so it stays live. The ladder's
	-- other four are staged for the owner's review, NOT selectable until approved:
	-- "Sandstone", "RustedIronOre", "AmethystGeode", "MeteoriteCore"
	Terra = { "Default", "ObsidianMagma" },
	-- (2026-10-25) Radiant moved here from Offer (Rainbow was already live per ability). The rest of its ladder --
	-- Moonlight, Stained Glass, Starlight, Prism Bloom -- approved by the owner 2026-10-25 after the polish / Moonlight
	-- rounds ("finalise all the wraps for radiant ... make them in wraps section for radiant")
	Radiant = { "Default", "Rainbow", "Moonlight", "StainedGlass", "Starlight", "PrismBloom" } }
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

--- (2026-10-19, audit GA-14) every wrap Id `element` offers, Default left out: its Element-wide wraps (ElementWraps)
--- first, then any per-ability one (Offer), each once. The WRAPS card's mark reads it.
function SkinCatalog.WrapsOf(element)
	local out, seen = {}, { Default = true }
	local function add(id)
		if not seen[id] then seen[id] = true; out[#out + 1] = id end
	end
	for _, id in ipairs(SkinCatalog.ElementWraps[element] or {}) do add(id) end
	local offer = SkinCatalog.Offer[element] or {}
	local keys = {}
	for key in pairs(offer) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		for _, id in ipairs(offer[key]) do add(id) end
	end
	return out
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
-- (2026-10-25) an Element whose wraps are Element wraps but whose clients take the wrap's id from the server's stamp
-- (Radiant: RadiantHandler stamps data.Skin = Chosen(...)): Chosen reads its one ElementWrap_<Element> (Studio: a
-- WrapStudio attribute on the character previews any wrap of the Element, a staged one included), and Resolve takes
-- any wrap of that Element. (2026-10-25) Terra too: TerraHandler stamps data.Skin = Chosen(...) on Boulder Shot / Bulwark,
-- and every client-side Terra resolve (TerraFX, ChargedRock, SpellshotInput) goes through Chosen / Resolve.
SkinCatalog.ElementWrapped = { Radiant = true, Terra = true }
local function elementWrapOf(element, id)
	local w = type(id) == "string" and SkinCatalog.Skins[id]
	return SkinCatalog.ElementWrapped[element] == true and type(w) == "table" and w.Wrap == element
end
function SkinCatalog.Chosen(player, ability)
	if not player then return "Default" end
	local origin = SkinCatalog.Origin[ability]
	if not origin or player:GetAttribute("Element") ~= origin then return "Default" end
	local full = SkinCatalog.ElementSkin(player, origin)
	local id = player:GetAttribute(SkinCatalog.Attr(ability))
	if type(id) ~= "string" or not SkinCatalog.Allowed(origin, ability, id) or not SkinCatalog.OwnsSkin(player, id) then
		id = "Default"
	end
	if SkinCatalog.ElementWrapped[origin] then
		id = SkinCatalog.ElementWrap(player, origin)
		local ch = game:GetService("RunService"):IsStudio() and player.Character
		local ws = ch and ch:GetAttribute("WrapStudio")
		if ws == "Default" or elementWrapOf(origin, ws) then id = ws end
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
		MaxBright = skin.MaxBright, LEScale = skin.LEScale, Look = skin.Look }   -- (Look: 2026-10-25, the Radiant ladder)
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
		if not ((SkinCatalog.Allowed(element, ability, w) or elementWrapOf(element, w)) and SkinCatalog.WrapsOverSkin(w)) then
			return SkinCatalog.Resolve(element, ability, s)
		end
		local p = palettes[id]
		if p then return p end
		local sk, wr = SkinCatalog.Skins[s], SkinCatalog.Skins[w]
		if not sk then return nil end
		-- the skin's forms and staff, the wrap's colours (and its own tone: core lift, glow cap)
		p = makePalette({ Id = s, Flat = wr.Flat, Stops = wr.Stops, CoreLift = wr.CoreLift, Staff = sk.Staff,
			MaxBright = wr.MaxBright, LEScale = wr.LEScale, Look = wr.Look })
		p.Skin, p.Wrap, p.Key = s, w, id
		palettes[id] = p
		return p
	end
	if not (SkinCatalog.Allowed(element, ability, id) or SkinCatalog.ElementSkinAllowed(element, id)
		or elementWrapOf(element, id)) then return nil end
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
	WitchsBrew = { Element = "Toxin" },       -- (Epic; its icons: IconAssets.Ability.Skins.WitchsBrew -- placeholders until the art; no bar accent)
	Hydra = { Element = "Toxin" },            -- (Mythic; its icons: IconAssets.Ability.Skins.Hydra -- placeholders until the art; no bar accent)
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

-- TOXIN'S MYTHIC WRAP (2026-10-20, Studio checkpoint): pH Indicator -- universal indicator paper. One shared, slow field
-- carries every gas / liquid / membrane piece through the scale (acid red-orange -> amber -> green -> basic teal; Flow),
-- bright crisp fizz motes pop where one band shades into the next (Flow.Fizz, +25-30% of each effect's Default rate),
-- a glossy litmus-paper sheen on the liquid and membrane (Finish), and Patient Zero's mark sweeps the scale with its
-- countdown (teal early, amber, red-orange at detonation) wearing a printed reference chart (Bands.Chart, static print).
-- Every value a proposal. NOT in ElementWraps until approved.
local function rgbc(r, g, b) return Color3.fromRGB(r, g, b) end
SkinCatalog.Skins.PHIndicator = { Id = "PHIndicator", DisplayName = "pH Indicator", Rarity = "Mythic", Wrap = "Toxin",
	Label = { hex("#E8402A"), hex("#8CC23A"), hex("#3ADEC0") },
	Palette = {
		Bands = { Radial = { { 0.22, "GasCore", "GasCore", "GasCore", "GasShadow" }, { 0.45, "GasShadow", "Gas", "GasShadow", "Gas", Body = true },
				{ 0.72, "GasLit", "GasLit", "GasLit", "GasEdge", Body = true }, { 9, "GasEdge", "GasEdge", "GasEdge", "GasEdge" } },
			Edge = { "GasEdge", "GasEdge", "GasEdge", "GasEdge" }, SelfLit = { GasLit = true },   -- (core acidic -> edge basic)
			Pulse = { Period = 2.4, Amp = 0.1 },
			Gloss = { Material = "SmoothPlastic", Reflectance = 0.06 },
			Flow = { Period = 18, Wave = 16, WaveY = 10, Hold = 0.35, Pos = { 0, 0.34, 0.67, 1 },
				Stops = {
					Lobe = { rgbc(255, 110, 80), rgbc(255, 180, 90), rgbc(150, 205, 95), rgbc(70, 225, 170) },
					Particle = { rgbc(217, 94, 68), rgbc(217, 153, 77), rgbc(128, 174, 81), rgbc(60, 191, 145) },
					Solid = { rgbc(245, 100, 72), rgbc(248, 172, 82), rgbc(142, 198, 88), rgbc(62, 214, 162) },
					Neon = { rgbc(128, 40, 28), rgbc(128, 88, 26), rgbc(76, 108, 34), rgbc(30, 120, 100) },
					Glow = { rgbc(255, 120, 90), rgbc(255, 200, 110), rgbc(170, 235, 120), rgbc(110, 245, 205) } },
				Fizz = { Share = 0.27, MarkShare = 0.34, BubbleRate = 1.6, Size = 0.55, Shares = { ToxinPZMass = 0.47, ToxinPZWave = 0.27, ToxinAcidRainCloud = 0.31 } },
				Sweep = { U0 = 0.92, U1 = 0.03 } },
			Chart = { Texture = true, TexRes = { 20, 40 }, TexSize = { 512, 256 }, Chart = true, Seed = 1, Blotches = 0, Dots = 0, Rings = 0,
				Res = { 8, 16 }, Glint = 2, Light = Vector3.new(0, 1, 0),
				Swatch = { rgbc(232, 64, 42), rgbc(232, 118, 42), rgbc(232, 170, 42), rgbc(186, 196, 58), rgbc(140, 194, 58), rgbc(78, 206, 132), rgbc(58, 214, 184) } } },
		Finish = { Membrane = 0.18, MembraneHi = 0.25, Liquid = 0.4 },   -- (a sheen past Poison Dart Frog's; more mirrors the blue sky into pink on the red end)
		Color = { GasCore = hex("#3E6E3A"), GasShadow = hex("#4F8A40"), Gas = hex("#6FA83E"), GasLit = hex("#8CC23A"), GasEdge = hex("#3ADEC0"),
			Liquid = hex("#E89A2A"), LiquidDeep = hex("#8A3A1C"), LiquidSpec = hex("#F8E8C8"), Membrane = hex("#E8402A"), MembraneHi = hex("#F6D0A0"),
			Mottle = hex("#2A3A2A"), Shimmer = hex("#DFFFF2"), Virulence = hex("#A8F0C8") },
		Display = {
			Lobe = { GasCore = rgbc(93, 127, 59), GasShadow = rgbc(117, 159, 74), Gas = rgbc(140, 190, 88), GasLit = rgbc(76, 108, 34), GasEdge = rgbc(70, 225, 170) },
			Particle = { GasCore = rgbc(79, 108, 50), GasShadow = rgbc(99, 135, 63), Gas = rgbc(119, 161, 75), GasLit = rgbc(110, 150, 70), GasEdge = rgbc(60, 191, 145) },
			Solid = { Liquid = rgbc(248, 172, 82), LiquidDeep = rgbc(150, 70, 40), LiquidSpec = rgbc(248, 232, 200), Membrane = rgbc(245, 100, 72),
				MembraneHi = rgbc(240, 210, 170), Mottle = rgbc(42, 58, 42), Shimmer = rgbc(200, 255, 230) },
			Neon = { Virulence = rgbc(120, 190, 150) }, Glow = { Virulence = rgbc(168, 240, 200) },
		} } }

return SkinCatalog
