--[[
	IconAssets  (ModuleScript)  ->  ReplicatedStorage/Spellshot/IconAssets

	Uploaded asset ids for the icon set rendered by blender_scripts/build_icons.py.
	Kept separate from SpellshotConfig so re-rendering the art only touches this file.

	  Element[<Element>]        -- the 8 Element logos
	  Role[<Role>][<Element>]   -- 5 ability-role glyphs x 8 Element palettes (HUD slots)
	  HUD                       -- the comic health/mana bar art
	  Ability                   -- one icon per ability (2026-10-06), see below

	All 48 icons come off one Blender camera/light rig, so they share a render angle, an outline
	weight and a colour treatment. This is the SECOND upload of that set: the first render was
	rejected as "rough / not smooth", and the rig was rebuilt to supersample 4x before
	downsampling and to raise the segment counts on every curved run. The HUD bar art is a
	separate rig (an ortho front view rather than a 3/4 angle -- see build_hud_bars.py) because
	it is UI furniture seen dead-on, not an object seen in the world.

	EXCEPT THE 8 ELEMENT LOGOS, replaced 2026-09-13: flat pop-art logos drawn by element_logos_v2/
	(Build Prompt 17 -- the variations picked off the concept sheet), not the Blender rig. The 40
	role glyphs and the HUD bar art are still the Blender set. The Blender Element ids are kept in
	asset_manifest.json under "Element_blender_2026-09-09" if they are ever wanted back.
]]

return {
	Element = {
		Pyro    = "rbxassetid://130389704231772",   -- variation 1
		Cryo    = "rbxassetid://114087404434526",   -- variation 2
		Voltaic = "rbxassetid://93665291516779",    -- variation 2
		Terra   = "rbxassetid://82316909276985",    -- variation 3
		Zephyr  = "rbxassetid://88913973979961",    -- variation 1
		Aqua    = "rbxassetid://88913973979961",   -- PLACEHOLDER: Zephyr's, until Aqua has its own
		Umbra   = "rbxassetid://102056654131849",   -- variation 1
		Radiant = "rbxassetid://94631631053912",    -- variation 3
		Toxin   = "rbxassetid://100939666418347",   -- variation 2
	},

	Role = {
		Primary = {
			Pyro    = "rbxassetid://118810702222429",
			Cryo    = "rbxassetid://71971556972977",
			Voltaic = "rbxassetid://107435685627986",
			Terra   = "rbxassetid://73816239451306",
			Zephyr  = "rbxassetid://90745809129297",
			Aqua    = "rbxassetid://90745809129297",   -- PLACEHOLDER: Zephyr's, until Aqua has its own
			Umbra   = "rbxassetid://86104699105930",
			Radiant = "rbxassetid://116065485590852",
			Toxin   = "rbxassetid://96648153280679",
		},
		Mobility = {
			Pyro    = "rbxassetid://115260474265581",
			Cryo    = "rbxassetid://91181171428199",
			Voltaic = "rbxassetid://86366990389259",
			Terra   = "rbxassetid://93423362081530",
			Zephyr  = "rbxassetid://113751007368104",
			Aqua    = "rbxassetid://113751007368104",   -- PLACEHOLDER: Zephyr's, until Aqua has its own
			Umbra   = "rbxassetid://104408709809651",
			Radiant = "rbxassetid://126974105330892",
			Toxin   = "rbxassetid://91248126540849",
		},
		Defense = {
			Pyro    = "rbxassetid://130381523635981",
			Cryo    = "rbxassetid://71548574671878",
			Voltaic = "rbxassetid://126470287690629",
			Terra   = "rbxassetid://134300318206376",
			Zephyr  = "rbxassetid://80709412723826",
			Aqua    = "rbxassetid://80709412723826",   -- PLACEHOLDER: Zephyr's, until Aqua has its own
			Umbra   = "rbxassetid://103359948382944",
			Radiant = "rbxassetid://90946522434617",
			Toxin   = "rbxassetid://82842688476903",
		},
		Ultimate = {
			Pyro    = "rbxassetid://123764933328282",
			Cryo    = "rbxassetid://101088486002359",
			Voltaic = "rbxassetid://133590079093203",
			Terra   = "rbxassetid://93996791931675",
			Zephyr  = "rbxassetid://126394888143475",
			Aqua    = "rbxassetid://126394888143475",   -- PLACEHOLDER: Zephyr's, until Aqua has its own
			Umbra   = "rbxassetid://119198289373634",
			Radiant = "rbxassetid://99651628214553",
			Toxin   = "rbxassetid://108084259458137",
		},
		Passive = {
			Pyro    = "rbxassetid://138361971772109",
			Cryo    = "rbxassetid://85087406778216",
			Voltaic = "rbxassetid://127502194760807",
			Terra   = "rbxassetid://77480577841105",
			Zephyr  = "rbxassetid://88803447543021",
			Aqua    = "rbxassetid://88803447543021",   -- PLACEHOLDER: Zephyr's, until Aqua has its own
			Umbra   = "rbxassetid://74889946674040",
			Radiant = "rbxassetid://116115920061663",
			Toxin   = "rbxassetid://78300168311737",
		},
	},

	-- ONE ICON PER ABILITY (2026-10-06): flat pop-art, drawn by the Element logos' own Python library
	-- (SPELLSHOT_Backup/ability_icons_2026_10_06/, 512 px). The HUD shows one in a slot in place of the Role
	-- glyph; an ability with no entry here keeps its Role glyph. Keys: Primary by Element, Technique and
	-- Ultimate by their SpellshotConfig pool key. M1 and Passive icons exist as artwork but have no HUD slot.
	Ability = {
		-- Pyro and Zephyr have no ability icons yet (their kits were still being settled): they keep the Role glyphs.
		Primary = {
			Cryo    = "rbxassetid://115181131668705",     -- Flash Freeze
			Voltaic = "rbxassetid://109554112590241",     -- Overcharge
			Terra   = "rbxassetid://97572326072118",      -- Bulwark Charge
			Umbra   = "rbxassetid://89657342423788",      -- Shadow Step
			Radiant = "rbxassetid://136250956788940",     -- Blessing
			Toxin   = "rbxassetid://135743787911274",     -- Corrosive Cloud
			Aqua    = "rbxassetid://72276813374666",      -- Undertow
		},
		Technique = {
			Blizzard      = "rbxassetid://125215096835248",
			DeepFreeze    = "rbxassetid://79221468640950",
			Railspike     = "rbxassetid://140564025292444",
			VoltOrb       = "rbxassetid://103872177826464",
			Aftershock    = "rbxassetid://109630216394685",
			BulwarkWall   = "rbxassetid://96419718612326",
			Mark          = "rbxassetid://89597830397955",
			DecoyDouble   = "rbxassetid://105306665874260",
			PositionTrade = "rbxassetid://97577641426550",
			Benediction   = "rbxassetid://78190113930515",
			AntitoxinVent = "rbxassetid://114140624491284",
			AcidRain      = "rbxassetid://127173070608973",
			TwinTide      = "rbxassetid://121990028377455",
			Sidearm       = "rbxassetid://89997226091196",
		},
		Ultimate = {
			MirrorCage    = "rbxassetid://135553447978023",
			Cascade       = "rbxassetid://87691585884922",
			EarthenTomb   = "rbxassetid://95587748907836",
			Eclipse       = "rbxassetid://113188793651152",
			Halo          = "rbxassetid://73034608373304",
			PatientZero   = "rbxassetid://119536529236279",
			LeviathansMaw = "rbxassetid://136479911681805",
		},
		-- SKIN HUD SETS (2026-10-14): a full Element skin's own icons, by skin Id, keyed like the tables above. Shown only
		-- while that skin is the player's own Element skin (SkinCatalog.HudSkin); an empty id keeps the Default icon.
		Skins = {
			-- Cryo SNOW GLOBE (Rare since the tiers swapped with Frost Lotus, 2026-10-15; cryo_snowglobe_hud_2026_10_15/icons).
			-- (2026-10-19, audit P5F-20) the skin is built and selectable, but as a Rare it has no HUD set: SkinCatalog.Hud has
			-- no SnowGlobe row, so this set shows nowhere, not even through the Studio preview (HudSkinPreview_Cryo, which
			-- only previews a Hud row). Kept for a Hud row if the tier gets one. Art with no HUD slot:
			-- M1 Icicle Shard rbxassetid://126924652328679, Passive Cold Momentum rbxassetid://70744676230592.
			-- FROST LOTUS (Epic, 2026-10-15; cryo_frostlotus_hud_2026_10_15/icons): its HUD set (SkinCatalog.Hud.FrostLotus)
			FrostLotus = {
				Primary = { Cryo = "rbxassetid://109070719732675" },                     -- Flash Freeze
				Technique = { Blizzard = "rbxassetid://72329550845528", DeepFreeze = "rbxassetid://71905630518052" },
				Ultimate = { MirrorCage = "rbxassetid://139037953639263" },
			},
			SnowGlobe = {
				Primary = { Cryo = "rbxassetid://74657465569393" },                      -- Flash Freeze
				Technique = { Blizzard = "rbxassetid://78231659168921", DeepFreeze = "rbxassetid://116482158942331" },
				Ultimate = { MirrorCage = "rbxassetid://111685182068419" },
			},
			-- FROST DRAGON (Mythic, 2026-10-17; cryo_frostdragon_hud_2026_10_15/icons): its HUD set (SkinCatalog.Hud.FrostDragon)
			FrostDragon = {
				Primary = { Cryo = "rbxassetid://95989905494488" },                      -- Flash Freeze
				Technique = { Blizzard = "rbxassetid://98260135176650", DeepFreeze = "rbxassetid://132365833202978" },
				Ultimate = { MirrorCage = "rbxassetid://80026946183434" },
			},
			-- Witch's Brew (Toxin, Epic, 2026-10-20): mapped, art TODO -- the owner uploads it; "" keeps the Default icon
			WitchsBrew = {
				Primary = { Toxin = "" },                                                -- TODO Corrosive Cloud
				Technique = { AntitoxinVent = "", AcidRain = "" },                       -- TODO
				Ultimate = { PatientZero = "" },                                         -- TODO
			},
			-- Hydra (Toxin, Mythic, 2026-10-23): toxin_hydra_hud_2026_10_23/icons/Hydra_<Key>.png (512 px RGBA), uploaded at
			-- the owner's request. Studio preview before the skin is selectable: HudSkinPreview_Toxin = "Hydra" (server-side)
			Hydra = {
				Primary = { Toxin = "rbxassetid://120553229254496" },                    -- Corrosive Cloud (Hydra_CorrosiveCloud.png)
				Technique = {
					AntitoxinVent = "rbxassetid://90041594066581",                      -- Antitoxin Vent (Hydra_AntitoxinVent.png)
					AcidRain = "rbxassetid://75906842347848",                            -- Acid Rain (Hydra_AcidRain.png)
				},
				Ultimate = { PatientZero = "rbxassetid://113771187534479" },            -- Patient Zero (Hydra_PatientZero.png)
			},
		},
	},

	-- comic health/mana bars, rendered by blender_scripts/build_hud_bars.py.
	-- Sizes are baked in: Frame 364x72 (health) / 364x70 (mana), Fill 315x27 / 315x25,
	-- Burst 170x170. MatchHUD's BAR_ART table must match these or the fill misses the trough.
	HUD = {
		FrameHealth = "rbxassetid://130961122599923",
		FrameMana   = "rbxassetid://71320689890572",
		FillHealth  = "rbxassetid://86488869566933",
		FillMana    = "rbxassetid://127321433086293",
		Burst       = "rbxassetid://99133783983357",
	},
}
