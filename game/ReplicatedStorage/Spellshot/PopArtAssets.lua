--[[
	PopArtAssets  (ModuleScript)  ->  ReplicatedStorage/Spellshot/PopArtAssets

	Uploaded asset ids for the pop-art kit, generated from the Blender render manifests so the
	pixel sizes here are the sizes the art was actually rendered at -- the HUD lays out against
	these numbers rather than against hand-measured guesses, which is what keeps the bar fill
	registered inside its trough.

	Rendered by blender_scripts/build_popart_{hud,status,panels}.py and build_fx_world.py.
	Re-render -> re-upload -> regenerate this file; nothing else needs touching.

	(2026-10-19, audit GA-15) NOT EVERYTHING HERE IS WIRED. Nothing in game/ reads these sections today (a grep for each):
	Overlay.Word, Overlay.Field, Overlay.SubTab, Tile, Banner, Feed, Bar, Chip, ValueBox, Pill, PillDark, Crosshair (the
	art; Size.Crosshair is read), Screen (Haste, Knockback, Pull, MarkedBurst, Vignette), Cleanse, FX, Mana.ConvertArc and
	StatusChip.Shocked. Do not take one for live art without checking what uses it.
]]

return {
	Size = {
		Crosshair = { 62, 62 },
		RoundCounter = { 332, 94 },
		NameTag = { 306, 60 },
		Pill = { 146, 52 },
		PillPassive = { 266, 58 },
		KeyTab = { 100, 48 },
		Slot = { 126, 126 },
		SlotUlt = { 158, 158 },
		Chip = { 68, 68 },
		ValueBox = { 82, 42 },
	},

	-- SliceCenter rects: the flat middle stretches, the inked border never does
	Slice = {
		NameTag = { 26, 22, 26, 22 },
		Pill = { 22, 18, 22, 18 },
		PillPassive = { 34, 22, 34, 22 },
		KeyTab = { 22, 16, 22, 16 },
		Slot = { 33, 33, 33, 33 },
		ValueBox = { 18, 12, 18, 12 },
	},

	Bar = {
		Health = {
			Frame = "rbxassetid://71077006340493",
			Fill = "rbxassetid://77351819168784",
			Size = { 440, 62 },
			Trough = { 396, 30 },
			TroughOffset = { 22, 16 },
		},
		Mana = {
			Frame = "rbxassetid://135913421379437",
			Fill = "rbxassetid://127899888872258",
			Size = { 440, 50 },
			Trough = { 396, 20 },
			TroughOffset = { 22, 15 },
		},
	},

	ValueBox = "rbxassetid://124784050141841",
	Slot = "rbxassetid://90938318975874",
	SlotUlt = "rbxassetid://131949454841914",
	SlotVeil = "rbxassetid://135055419330323",
	KeyTab = "rbxassetid://81529655004324",
	RoundCounter = "rbxassetid://125709854395175",
	NameTag = "rbxassetid://96842281030659",
	Pill = "rbxassetid://74227475907634",
	PillDark = "rbxassetid://113930748525404",
	PillPassive = "rbxassetid://80574137779565",
	Crosshair = "rbxassetid://129468450087606",
	Ready = "rbxassetid://96489541477969",
	Chip = { Health = "rbxassetid://111248610855760", Mana = "rbxassetid://71683168165183" },

	Element = {
		Pyro = "rbxassetid://115282226177431",
		Cryo = "rbxassetid://88411437727295",
		Voltaic = "rbxassetid://77829127282982",
		Terra = "rbxassetid://117299447369485",
		Zephyr = "rbxassetid://91764139450603",
		Aqua = "rbxassetid://91764139450603",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
		Umbra = "rbxassetid://97750539411870",
		Radiant = "rbxassetid://75246195439614",
		Toxin = "rbxassetid://90972336349387",
	},
	Gem = {
		Diamond = {
			Pyro = "rbxassetid://114296630931197",
			Cryo = "rbxassetid://97390605794032",
			Voltaic = "rbxassetid://87497452069087",
			Terra = "rbxassetid://102025143638354",
			Zephyr = "rbxassetid://82550385489674",
			Aqua = "rbxassetid://82550385489674",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://77382638879634",
			Radiant = "rbxassetid://134653989463194",
			Toxin = "rbxassetid://88998440922650",
		},
		Dot = {
			Pyro = "rbxassetid://111949987642664",
			Cryo = "rbxassetid://85916981020133",
			Voltaic = "rbxassetid://134248444838332",
			Terra = "rbxassetid://89977259538381",
			Zephyr = "rbxassetid://88814181343308",
			Aqua = "rbxassetid://88814181343308",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://104939812581266",
			Radiant = "rbxassetid://108048620746248",
			Toxin = "rbxassetid://83358124637801",
		},
	},
	Role = {
		Primary = {
			Pyro = "rbxassetid://107370019109382",
			Cryo = "rbxassetid://92028806855370",
			Voltaic = "rbxassetid://73632644816136",
			Terra = "rbxassetid://114584555601069",
			Zephyr = "rbxassetid://111653775547672",
			Aqua = "rbxassetid://111653775547672",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://113088586868062",
			Radiant = "rbxassetid://94374150038648",
			Toxin = "rbxassetid://76617720757046",
		},
		Mobility = {
			Pyro = "rbxassetid://138854058344727",
			Cryo = "rbxassetid://75651334565795",
			Voltaic = "rbxassetid://120050860988275",
			Terra = "rbxassetid://77609247689252",
			Zephyr = "rbxassetid://102570274376609",
			Aqua = "rbxassetid://102570274376609",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://82346836865598",
			Radiant = "rbxassetid://80774678119403",
			Toxin = "rbxassetid://109715977656543",
		},
		Defense = {
			Pyro = "rbxassetid://138351531767506",
			Cryo = "rbxassetid://80633551263170",
			Voltaic = "rbxassetid://71656193162172",
			Terra = "rbxassetid://77867698037357",
			Zephyr = "rbxassetid://120689304329860",
			Aqua = "rbxassetid://120689304329860",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://83095246198237",
			Radiant = "rbxassetid://134194868709842",
			Toxin = "rbxassetid://125232201209275",
		},
		Ultimate = {
			Pyro = "rbxassetid://84182373009345",
			Cryo = "rbxassetid://85315979744557",
			Voltaic = "rbxassetid://78751740377962",
			Terra = "rbxassetid://72456541927233",
			Zephyr = "rbxassetid://132675295158219",
			Aqua = "rbxassetid://132675295158219",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://102605967413384",
			Radiant = "rbxassetid://107961156392785",
			Toxin = "rbxassetid://124143299151908",
		},
		Passive = {
			Pyro = "rbxassetid://103553619297655",
			Cryo = "rbxassetid://80288770680415",
			Voltaic = "rbxassetid://85833138238876",
			Terra = "rbxassetid://123271733399058",
			Zephyr = "rbxassetid://132045438040864",
			Aqua = "rbxassetid://132045438040864",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://114006157786796",
			Radiant = "rbxassetid://97453195989127",
			Toxin = "rbxassetid://77933158053571",
		},
	},

	-- 01 health bar
	Burn = {
		Crest = { "rbxassetid://132655386995473", "rbxassetid://111163414524160", "rbxassetid://116577870637843", "rbxassetid://110086614548955" },
		Ember = { "rbxassetid://136965966602366", "rbxassetid://70485977978461", "rbxassetid://110945726174109" },
		TickBurst = "rbxassetid://123546996236596",
	},
	Chill = {
		Crust = { "rbxassetid://134417536985950", "rbxassetid://137220136347298", "rbxassetid://99178066362547", "rbxassetid://121281656905245" },
		Krak = "rbxassetid://79887670462963",
	},
	Poison = {
		Overlay = "rbxassetid://124277036689629",
		Bubble = { "rbxassetid://102327298045779", "rbxassetid://134250008632007", "rbxassetid://79461382759779" },
		Punish = "rbxassetid://74630657186723",
	},
	Shock = { "rbxassetid://71332616688771", "rbxassetid://138988983966532", "rbxassetid://71861875914082" },
	Shield = {
		Ring = { "rbxassetid://75618651889006", "rbxassetid://109680857145795", "rbxassetid://136664598748621" },
		Frag = { "rbxassetid://126743387306805", "rbxassetid://71596927896930", "rbxassetid://73121148617506", "rbxassetid://82108945628757", "rbxassetid://128753060914112" },
		ZoneGlow = "rbxassetid://93396788618414",
	},

	-- 02 mana bar
	Mana = {
		Ripple = "rbxassetid://100043685164815",
		ConvertArc = { "rbxassetid://81255319572153", "rbxassetid://139248961309337", "rbxassetid://81819386050792" },
	},

	-- 03 screen-wide
	Screen = {
		Haste = { "rbxassetid://125299780979288", "rbxassetid://124976131116874" },
		Knockback = "rbxassetid://140499569000751",
		Pull = "rbxassetid://104922029625057",
		MarkedBurst = "rbxassetid://79697237678896",
		Vignette = {
			Marked = "rbxassetid://133262004704628",
			Stealth = "rbxassetid://140346657483725",
			VisionDenial = "rbxassetid://99262882948248",
		},
	},
	Cleanse = { "rbxassetid://101896858887672", "rbxassetid://87558916033623", "rbxassetid://111859458882102" },

	-- 04 crosshair & ability icons
	CrosshairStar = { "rbxassetid://78099897522518", "rbxassetid://116986437773083" },
	Charge = { "rbxassetid://82109045837912", "rbxassetid://97415534533874", "rbxassetid://95479672127323", "rbxassetid://114770592501462" },
	Decoy = { "rbxassetid://77989092111610", "rbxassetid://90207610822983", "rbxassetid://119500527116488" },
	-- v2: each chip now carries the status's own mark. v1 was a bare coloured square, which told
	-- you a status had been displaced off the fill but never which one.
	StatusChip = {
		Burning = "rbxassetid://87683105503569",
		Chilled = "rbxassetid://104108968877413",
		Poisoned = "rbxassetid://116804242723453",
		Shocked = "rbxassetid://108862720770391",
		Charged = "rbxassetid://108862720770391",   -- Voltaic's status renamed in manual v0.13 (2026-09-24); same chip
		Shielded = "rbxassetid://117881275827663",
		Marked = "rbxassetid://88425320072925",
	},

	-- rows 02-04: overlays, identity tiles, banners, kill feed
	Overlay = {
		Burst = "rbxassetid://88718198034720",
		SubTab = "rbxassetid://80799166755583",
		Field = {
			Pyro = "rbxassetid://133922828225915",
			Cryo = "rbxassetid://127500574334587",
			Voltaic = "rbxassetid://117718580326969",
			Terra = "rbxassetid://132630641172232",
			Zephyr = "rbxassetid://127022234814723",
			Aqua = "rbxassetid://127022234814723",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://109572645608136",
			Radiant = "rbxassetid://111580736742180",
			Toxin = "rbxassetid://78230548159881",
		},
		Word = {
			Pyro = {
				BURNEDDOWN = "rbxassetid://107780424186324",
				CLUTCH = "rbxassetid://107735957886568",
				DOUBLE = "rbxassetid://119980552820511",
				ELIMINATED = "rbxassetid://76991161509002",
				FIRSTBLOOD = "rbxassetid://135407292625734",
				TRIPLE = "rbxassetid://129145295982860",
				ULTIMATE = "rbxassetid://115460593038829",
			},
			Cryo = {
				CLUTCH = "rbxassetid://89026216075325",
				DOUBLE = "rbxassetid://123217007429696",
				ELIMINATED = "rbxassetid://98979156672436",
				FIRSTBLOOD = "rbxassetid://133150204749775",
				FROZENOUT = "rbxassetid://88824739552709",
				TRIPLE = "rbxassetid://92667163277593",
				ULTIMATE = "rbxassetid://94064943326501",
			},
			Voltaic = {
				ARCSTORM = "rbxassetid://101595025956203",
				CLUTCH = "rbxassetid://71202619188206",
				DOUBLE = "rbxassetid://135377339128325",
				ELIMINATED = "rbxassetid://80434221644764",
				FIRSTBLOOD = "rbxassetid://112976424231965",
				TRIPLE = "rbxassetid://77540939828008",
				ULTIMATE = "rbxassetid://74130577314389",
			},
			Terra = {
				CLUTCH = "rbxassetid://118525692676660",
				DOUBLE = "rbxassetid://90217484243102",
				ELIMINATED = "rbxassetid://115161329053031",
				FIRSTBLOOD = "rbxassetid://88983295619142",
				GROUNDED = "rbxassetid://114806770935577",
				TRIPLE = "rbxassetid://100774509297058",
				ULTIMATE = "rbxassetid://131172673794639",
			},
			Zephyr = {
				BLOWNAWAY = "rbxassetid://98018022381097",
				CLUTCH = "rbxassetid://79882797182426",
				DOUBLE = "rbxassetid://106256142938424",
				ELIMINATED = "rbxassetid://109047721824532",
				FIRSTBLOOD = "rbxassetid://138956204567207",
				TRIPLE = "rbxassetid://140051436714895",
				ULTIMATE = "rbxassetid://118446461095711",
			},
			Umbra = {
				CLUTCH = "rbxassetid://76886323812089",
				DOUBLE = "rbxassetid://106128061055732",
				ELIMINATED = "rbxassetid://114788017885011",
				FIRSTBLOOD = "rbxassetid://98643091071307",
				LIGHTSOUT = "rbxassetid://138656254929865",
				TRIPLE = "rbxassetid://75106696621293",
				ULTIMATE = "rbxassetid://109710316862983",
			},
			Radiant = {
				CLUTCH = "rbxassetid://86145317357104",
				DOUBLE = "rbxassetid://101145307331667",
				ELIMINATED = "rbxassetid://94514711823362",
				FIRSTBLOOD = "rbxassetid://131079681124669",
				JUDGED = "rbxassetid://99552337977230",
				TRIPLE = "rbxassetid://87257367096196",
				ULTIMATE = "rbxassetid://130165533156424",
			},
			-- (2026-10-19, audit GA-15) PLACEHOLDER: CLUTCH, DOUBLE, ELIMINATED, FIRSTBLOOD and ULTIMATE below are VOLTAIC's
			-- ids (copied), so a Toxin word would show Voltaic's lettering; only SPOREWIPE and TRIPLE are Toxin's own. Aqua
			-- has no set at all. Re-render and upload both before anything reads Overlay.Word.
			Toxin = {
				CLUTCH = "rbxassetid://71202619188206",
				DOUBLE = "rbxassetid://135377339128325",
				ELIMINATED = "rbxassetid://80434221644764",
				FIRSTBLOOD = "rbxassetid://112976424231965",
				SPOREWIPE = "rbxassetid://91665372507322",
				TRIPLE = "rbxassetid://97629395853442",
				ULTIMATE = "rbxassetid://74130577314389",
			},
		},
	},
	Tile = {
		Pyro = "rbxassetid://124973932872772",
		Cryo = "rbxassetid://119655478211715",
		Voltaic = "rbxassetid://79462144461439",
		Terra = "rbxassetid://118440039511957",
		Zephyr = "rbxassetid://101648395984379",
		Aqua = "rbxassetid://101648395984379",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
		Umbra = "rbxassetid://137679827551337",
		Radiant = "rbxassetid://75086628267464",
		Toxin = "rbxassetid://115841039944830",
	},
	Banner = { Victory = "rbxassetid://124631703815169", Defeat = "rbxassetid://137561107074436", Eliminated = "rbxassetid://122891509997613" },
	Feed = {
		Panel = "rbxassetid://121085986348713",
		Row = "rbxassetid://113653364201483",
		Chevron = {
			Pyro = "rbxassetid://89928818334581",
			Cryo = "rbxassetid://90529330417190",
			Voltaic = "rbxassetid://138554924609420",
			Terra = "rbxassetid://98192183919738",
			Zephyr = "rbxassetid://90851339234389",
			Aqua = "rbxassetid://90851339234389",   -- PLACEHOLDER (2026-09-24): Zephyr's, until Aqua has its own art
			Umbra = "rbxassetid://86912164686527",
			Radiant = "rbxassetid://86182571964324",
			Toxin = "rbxassetid://114426037823997",
		},
	},

	-- world VFX particle sprites (the meshes are FBX, not ids)
	FX = {
		Flame = { "rbxassetid://72584097689058", "rbxassetid://79053446647534", "rbxassetid://82235146775856" },
		Ember = "rbxassetid://123324199386929",
		ShieldSpark = "rbxassetid://76304655022581",
	},

	-- geometry the reaction layer scales against
	Meta = { CrestW = 460, CrestH = 105, RippleW = 210, RippleH = 44 },
}
