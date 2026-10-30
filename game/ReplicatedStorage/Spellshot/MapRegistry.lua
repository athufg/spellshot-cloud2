--[[
	MapRegistry  (ModuleScript)  ->  ReplicatedStorage/Spellshot/MapRegistry

	The maps a match can be played on. HubServer reads it to run the map vote and to find where each map puts
	people; MapVote draws its cards from what the server sends; HubClient reads the lighting and the sky.

	  Id         what the vote and the player's "Map" attribute carry
	  Name, Sub  the vote card's title and its small line
	  Image      the vote card's picture (a capture of the map in Studio)
	  Accent     the card's colour, one of Quick Play's accents: "Gold" | "Cyan" (red stays the primary action's)
	  Model      the map's Model in workspace. Its Marks folder holds A and B (the two duel ends) and Solo.
	             The Training Ground has none: HubServer keeps its marks round the arena's SpawnLocation.
	  FlatLight  the map's colours are baked comic bands, like the Hub's, so its players get flat light
	  Light      the opposite: a map lit for real, carrying the Lighting properties to hold while a
	             player is on it. { Props = { ... }, Atmosphere = { Density, Haze, Glare }, Sun = bool }.
	             Set Light OR FlatLight, never both -- FlatLight puts Brightness at 0 and Ambient at
	             white, which is the one thing a map whose look is made of light cannot survive.
	  Sky        the six skybox faces, swapped in on the client while the player is on the map
	  Vote       false keeps a map out of the vote (the Training Grounds: its Hub gate is the way in)
	  Practice   true: offered to a Solo Test only, never to a Duel or team match (2026-10-19, audit P1-04: the
	             range's refilling dummies fed Ultimate charge and passives mid-match, and its thrower hit duellists)

	HubSky is the sky HubClient applies while the player is in the Hub (UNIVERSAL_SKY, the arenas' shared sky).
	(2026-10-19, audit P6A-20)

	A map whose Model is missing from workspace is left out of the vote.
]]

local MapRegistry = {}

-- the Open Academy's six skybox faces (render_skybox.py, rendered over the Hub's centre, placed as Shattered Neon City's).
-- Sky v7 (horizon #6AA1EF, 2026-09-17), shared by the Hub, the Training Grounds and the Ascendant Bastion
local ACADEMY_SKY = {
	Lf = "rbxassetid://96010916973055",    -- sky_px
	Rt = "rbxassetid://75991416797460",    -- sky_nx
	Bk = "rbxassetid://89502360522348",    -- sky_ny
	Ft = "rbxassetid://129383442666177",   -- sky_py
	Up = "rbxassetid://113790226637556",   -- sky_pz
	Dn = "rbxassetid://132071480871625",   -- sky_nz
}

-- ONE SKY AND ONE LIGHT FOR THE WHOLE GAME (2026-09-22; sky v15 2026-09-23). Rivals has a universal skybox; so does SPELLSHOT.
-- v15 follows the owner's build prompt "Painted, Non-Realistic Skybox + Contained Sun Glow" and seven Rivals frames
-- (N/E/S/W, up, toward and away from the sun; one of them shows a faint face seam, so Rivals' sky is a painted cube):
--   * PAINTED, not rendered: vmarm/rivals_sky/paint_sky.py paints every face pixel from its 3D direction, so the six
--     faces are one function and cannot seam. Clouds are hand-placed painted shapes -- big soft masses with brushed
--     edges, heaps with flat bottoms, separate small puffs, a few swept wisps -- lit lavender in shade, pinkish white on
--     top, glowing where they sit near the sun. Below the horizon: a cloud sea of heaps over deep blue, with stratus
--     streaks, closing to a lavender band at the horizon.
--   * colours are authored as what Roblox SHOWS (measured off the Rivals frames) and converted through the measured
--     texel -> screen curve (texel 253 shows as 222, which is why Rivals' whites stop at 224).
--   * a CONTAINED sun: a white core ~2.5 deg across fading by ~10 deg (Rivals measured the same), soft painted shafts
--     falling from it onto the sea; Lighting's own sun is solved onto exactly that direction, so the engine disc, the
--     sun rays and the shadows all agree. Cool throughout: no warm tint anywhere.
--   * no cloud geometry in the maps any more (moved to ServerStorage._superseded_clouds_2026_09_23) and the engine's
--     Terrain.Clouds off: the sky carries every cloud.
local UNIVERSAL_SKY = {
	Lf = "rbxassetid://88034724114989",    -- sky_px
	Rt = "rbxassetid://123983190577995",    -- sky_nx
	Bk = "rbxassetid://74901666592754",   -- sky_ny
	Ft = "rbxassetid://124492010024137",    -- sky_py (the sun is on this face)
	Up = "rbxassetid://121028586376279",   -- sky_pz, rotated 90 CCW before upload
	Dn = "rbxassetid://116949883408372",    -- sky_nz, rotated 90 CW before upload
	-- v17 (2026-09-23): the sunset palette out of the clouds -- neutral white tops, blue-grey shade, softer billow shading.
	-- v16, if ever wanted: Lf 74770479813737 Rt 82977189045949 Bk 86835776550719 Ft 125122225925950 Up 97672464419689 Dn 104904831743123
	-- v16 (2026-09-23, owner: "too sparse", "sun glow doesn't match"): a mid-level cloud layer all round (gameplay view 42% -> 66%
	-- cloud; RIVALS 47-77%) and RIVALS' sun as measured LIVE -- a flat sky-white disc to 3 deg and its cyan halo ring by ring.
	-- v15d, if ever wanted: Lf 122571884642275 Rt 80770612982964 Bk 77400092616247 Ft 86308245999547 Up 134494198546360 (Dn same)
	-- v15d = after two independent review rounds (crisp painted edges, a layered sea, no ripple lines, a broken horizon).
	-- v15b (round-1 fixes), if ever wanted: Lf 130971249475689 Rt 73858035524179 Bk 75304031219327 Ft 72998286491945
	-- Up 81656016641520 Dn 71780012526559
	-- v15 first cut (review round 1 failed its cloud sea and puffs), if ever wanted: Lf 89960955483483 Rt 81329823838776
	-- Bk 117000340562377 Ft 72401980469442 Up 132534274046743 Dn 90504519839881
	-- v14 (3D toon heaps, wide sun wash), if ever wanted back: Lf 104140146474011 Rt 102990656131214
	-- Bk 119738184821867 Ft 117845150820582 Up 121623160003530 Dn 103225654721058
}
local UNIVERSAL_LIGHT = {
	Props = {
		-- AFTERNOON, NOT SUNSET (2026-09-23; the owner: "ours looks like a sunset... a headache... RIVALS looks like some
		-- afternoon time"). Measured on 262 frames of the owner's own RIVALS play against Play captures of ours: RIVALS'
		-- lit whites are neutral (#E3E3E4) and its shade is BLUE (R-B -24, green >= red); ours had pink whites (#E6DDDF)
		-- and mauve shade (R-B +17) from a violet fill, a low 20-deg sun and a lavender-shaded sky. Now:
		--  * the light comes from high up (55 deg, ClockTime 12.558 / latitude -10.60, same azimuth as the painted sun, whose
		--    disc stays where it is) so floors are lit, not raked;
		--  * the sun is a little weaker and the fill is azure, so shade reads as blue sky light and nothing reads warm;
		--  * a whisper of cyan tint and +0.12 exposure put lit whites on RIVALS' neutral white.
		-- Measured in Play after: lit #E1E4E7-#E3E5E8, shade #979EAE (R-B -23) facing the sun.
		-- The previous rig (sun 20 deg, Brightness 2.5, violet fill) is in ServerStorage.MapRegistryBackup_v16_2026_09_23.
		Brightness = 1.7,
		GlobalShadows = true,
		ShadowSoftness = 0.6,
		Ambient = Color3.fromRGB(108, 125, 157),
		OutdoorAmbient = Color3.fromRGB(112, 131, 166),
		EnvironmentDiffuseScale = 0.6,
		-- 0: environment specular greyed the ink and glinted facets (the owner's "sheen"); every map mesh is matte too
		EnvironmentSpecularScale = 0,
		ExposureCompensation = 0.12,
		ColorShift_Top = Color3.fromRGB(246, 250, 255),
		ColorShift_Bottom = Color3.new(0, 0, 0),
		ClockTime = 12.558,
		GeographicLatitude = -10.60,
	},
	-- Haze stays 0 (it paints over the sky's cloud sea). Offset 0.3 / Density 0.3 fade distant islands and towers into a
	-- pale blue-white like RIVALS' far city, instead of leaving them dark silhouettes; Decay no longer periwinkle.
	-- Density 0.3 -> 0.22 (same night): 0.3 greyed everything past ~100 studs and read as dull
	Atmosphere = { Density = 0.22, Offset = 0.3, Haze = 0, Glare = 0,
		Color = Color3.fromRGB(214, 222, 232), Decay = Color3.fromRGB(150, 170, 198) },
	-- the engine's sun disc stays HIDDEN: the skybox paints RIVALS' measured sun (flat sky-white disc + cyan halo)
	Sun = false,
	-- no Clouds entry on purpose: the painted sky carries every cloud, so HubClient turns the engine's layer off
	Effects = {
		Bloom = { Enabled = true, Intensity = 0.6, Size = 24, Threshold = 1.6 },   -- the sun's core and Neon, never a lit wall
		-- OFF: the engine sun (55 deg) is no longer where the painted sun is, and RIVALS' shafts measured almost nil
		SunRays = { Enabled = false, Intensity = 0.003, Spread = 0.8 },
		ColorCorrection = { Enabled = true, Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(250, 253, 255) },
		-- colours pop (2026-09-23, owner: "the maps have lost their saturation... make colours pop"): +0.35 saturation
		-- and a touch of contrast; the pass before only carried +0.1
		SkylineGrade = { Enabled = true, Saturation = 0.35, Contrast = 0.06, TintColor = Color3.new(1, 1, 1) },
		DepthOfField = { Enabled = false },
	},
}
MapRegistry.Universal = { Sky = UNIVERSAL_SKY, Light = UNIVERSAL_LIGHT }

MapRegistry.List = {
	{
		Id = "TrainingGround", Name = "TRAINING GROUND", Sub = "THE RANGE · DUMMIES · TARGET BOARDS",
		Image = "rbxassetid://119978552509610", Accent = "Gold", Practice = true,
	},
	{
		Id = "ShatteredNeonCity", Name = "SHATTERED NEON CITY", Sub = "ROOFTOPS · TWO LANES · STAIRWELLS",
		Image = "rbxassetid://78226145122488", Accent = "Cyan", Model = "Map_ShatteredNeonCity", Light = UNIVERSAL_LIGHT,
		-- its own painted sky (the far neon city in the faces) is superseded by the universal one; the ids, if it is
		-- ever wanted back: Lf 129379291514915 Rt 123440429421348 Bk 75332569450395 Ft 128829621817021 Up 88892695565644 Dn 110406877559767
		Sky = UNIVERSAL_SKY,
	},
}

-- the Open Academy's portal island (the user, 2026-09-14: a much bigger training ground, reached by a portal): a sandbox,
-- never in the vote
table.insert(MapRegistry.List, {
	Id = "TrainingGrounds", Name = "THE TRAINING GROUNDS", Sub = "TARGET RANGE · DUMMY FIELD · MOVEMENT COURSE",
	Accent = "Gold", Model = "Map_TrainingGrounds", Light = UNIVERSAL_LIGHT, Vote = false, Sky = UNIVERSAL_SKY,
})
-- the Hub too: ACADEMY_SKY (v7, its painted far islands and cities) is superseded by the universal sky; kept above
-- so it can be pointed at again
MapRegistry.HubSky = UNIVERSAL_SKY

-- imported 2026-09-17 (Build Prompts #26, #27, #29), each parked far from the others: Bastion (8000, 0, 0), Skyline
-- (-8000, 0, 0), Quarry (8000, 0, -8000). Their skies are Blender cube renders placed as Shattered Neon City's.
table.insert(MapRegistry.List, {
	Id = "AscendantBastion", Name = "ASCENDANT BASTION", Sub = "WALLED ARENA · TOWERS · THE CORE",
	Image = "rbxassetid://134056420136373", Accent = "Gold", Model = "Map_AscendantBastion", Light = UNIVERSAL_LIGHT,
	Sky = UNIVERSAL_SKY,
})
table.insert(MapRegistry.List, {
	Id = "SkylineConcept", Name = "SKYLINE · CONCEPT", Sub = "TOWERS · BRIDGES · A LONG WAY DOWN",
	Image = "rbxassetid://102741855854809", Accent = "Cyan", Model = "Map_SkylineConcept",
	-- VARIANT A: the concept poster, 1:1. Measured off it rather than eyeballed -- the panel is 54%
	-- azure, 33% near-grey, 1.5% gold, median value 0.965, and its saturated blues run value
	-- 0.31-0.85 at saturation 0.38-0.72. One hue family, many rungs. It is monochrome and it works,
	-- which is the thing an earlier pass got wrong by hunting for a second hue.
	--
	-- The ink hull is ON here, recoloured navy #293547 -- the poster's own line colour, measured, at
	-- 4% coverage. This style has line work; it is simply not comic line work, which is near-black
	-- and rings every shape.
	-- its flat rig and paler poster sky (Lf 89654309347747 Rt 136489535870750 Bk 91477077361985 Ft 93534921418894
	-- Up 126118075253385 Dn 119251137429390) are superseded by the universal rig
	Light = UNIVERSAL_LIGHT,
	Sky = UNIVERSAL_SKY,
})
table.insert(MapRegistry.List, {
	Id = "SkylineRivals", Name = "SKYLINE · RIVALS", Sub = "TOWERS · BRIDGES · A LONG WAY DOWN",
	Image = "rbxassetid://102741855854809", Accent = "Cyan", Model = "Map_SkylineRivals",
	-- VARIANT B: the same blue/grey/gold identity, built the way Marvel Rivals builds a palette --
	-- measured from the owner's own 60 s of Museum of Contemplation: median saturation 0.467 with
	-- 59.7% of pixels past 0.40. So the blues commit instead of tinting, the mid-tones carry colour
	-- rather than running to near-white, and the shadow end goes deep and blue rather than pale.
	-- NO ink hull: this register carries form on colour and relief, not on a drawn line.
	-- its flat rig and the v8 sky (Lf 72520178771409 Rt 117899637767277 Bk 118376841619495 Ft 73017965838877
	-- Up 106052329770506 Dn 91610163938101) are superseded by the universal rig, which keeps the engine clouds
	-- and replaces the ladder with the one measured off eleven captures (v8 was too saturated, too flat in value,
	-- painted lavender into the open sky and held its sun 58 deg up where no Rivals capture puts it)
	Light = UNIVERSAL_LIGHT,
	Sky = UNIVERSAL_SKY,
})
table.insert(MapRegistry.List, {
	Id = "ElementalQuarry", Name = "THE ELEMENTAL QUARRY", Sub = "THE PIT · LAVA · ICE FALLS · THE CORE",
	Image = "rbxassetid://80539083870055", Accent = "Gold", Model = "Map_ElementalQuarry", Light = UNIVERSAL_LIGHT,
	-- its own painted sky (Lf 87189468279448 Rt 103530321790394 Bk 84434037696196 Ft 98868327881546 Up 73705324259912
	-- Dn 137136115227104) is superseded by the universal one
	Sky = UNIVERSAL_SKY,
})

-- Sakura Row (2026-10-16), built from the owner's concept "5. THE JINJA PLAZA"; the owner asked for SUNSET instead of the
-- concept's night. Its own rig, not the universal afternoon one: a low warm sun raking the plaza, a warm-violet fill, warm
-- haze, and painted sky v16 (pink-topped clouds, the 'sunset palette' the universal sky dropped on 2026-09-23; already
-- uploaded, so no new assets). The engine sun sits on the painted sun's bearing but lower (11 deg against its 20) for long
-- golden shadows; its disc stays hidden so the painted sun is the only one. (The engine's no-skybox sky was tried in
-- Edit first: Roblox's stock blue sky, not a sunset.)
local SAKURA_SUNSET_LIGHT = {
	Props = {
		Brightness = 2.2,
		GlobalShadows = true,
		ShadowSoftness = 0.25,
		Ambient = Color3.fromRGB(92, 72, 92),
		OutdoorAmbient = Color3.fromRGB(140, 106, 118),
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0,
		ExposureCompensation = 0.1,
		ColorShift_Top = Color3.fromRGB(255, 190, 130),
		ColorShift_Bottom = Color3.new(0, 0, 0),
		ClockTime = 15.10,
		GeographicLatitude = -50,
	},
	Atmosphere = { Density = 0.32, Offset = 0.1, Haze = 1.8, Glare = 0.6,
		Color = Color3.fromRGB(255, 186, 150), Decay = Color3.fromRGB(112, 86, 140) },
	Sun = false,
	Effects = {
		Bloom = { Enabled = true, Intensity = 0.8, Size = 28, Threshold = 1.2 },
		SunRays = { Enabled = false },
		ColorCorrection = { Enabled = true, Brightness = 0, Contrast = 0.05, Saturation = 0.1, TintColor = Color3.fromRGB(255, 240, 228) },
		SkylineGrade = { Enabled = false },
		DepthOfField = { Enabled = false },
	},
}
-- NIGHT (2026-10-16, the owner: "Keep it night time like the concept img"). Blue hour just after dusk, the sun 11 deg below
-- the horizon: its painted night sky (SAKURA_NIGHT_SKY below, the moon painted in) goes deep indigo with faint stars
-- (2026-10-19, audit P6A-20: it was Roblox's own sky, Sky = false, before SAKURA_NIGHT_SKY); a cool moonlit fill keeps the plaza readable for a fight, and the warmth comes from the map's
-- own lanterns (146 PointLights, warm Neon glow, softly lit shoji paper). The sunset rig above is kept, unused.
local SAKURA_NIGHT_LIGHT = {
	Props = {
		Brightness = 1.2,
		GlobalShadows = true,
		ShadowSoftness = 0.4,
		Ambient = Color3.fromRGB(70, 78, 118),
		OutdoorAmbient = Color3.fromRGB(96, 106, 158),
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0,
		ExposureCompensation = 0,
		ColorShift_Top = Color3.fromRGB(150, 170, 230),
		ColorShift_Bottom = Color3.new(0, 0, 0),
		-- a DAYTIME clock on purpose: Roblox darkens a skybox when its sun is down, which turned the painted sky black.
		-- The 'sun' here is moonlight: weak, cool, and solved onto the painted moon (0.545, 0.530, 0.650), 0.03 deg off.
		ClockTime = 8.945,
		GeographicLatitude = 64,
	},
	Atmosphere = { Density = 0.35, Offset = 0.15, Haze = 0.6, Glare = 0,
		Color = Color3.fromRGB(60, 70, 110), Decay = Color3.fromRGB(30, 34, 60) },
	Sun = false,   -- the moon is painted into SAKURA_NIGHT_SKY
	Effects = {
		Bloom = { Enabled = true, Intensity = 0.6, Size = 24, Threshold = 1.6 },   -- Neon only: lit skin and walls never bloom
		SunRays = { Enabled = false },
		ColorCorrection = { Enabled = true, Brightness = 0.02, Contrast = 0.08, Saturation = 0.1, TintColor = Color3.fromRGB(235, 240, 255) },
		SkylineGrade = { Enabled = false },
		DepthOfField = { Enabled = false },
	},
}
-- Painted night sky (2026-10-16, owner: "add stars etc, its too black... background imagery like mt fuji"):
-- vmarm/rivals_sky/paint_night_sakura.py. Indigo to a lavender-rose horizon glow, a star field + Milky Way, a full moon
-- at Roblox (0.545, 0.530, 0.650), Mt Fuji on +Z (behind the shrine, peak 10 deg), mountain ranges round the horizon and a
-- misty valley with town lights below it.
local SAKURA_NIGHT_SKY = {
	Lf = "rbxassetid://103820005921535", Rt = "rbxassetid://127059648468912", Ft = "rbxassetid://119399964437588",
	Bk = "rbxassetid://108586176348954", Up = "rbxassetid://128813798267123", Dn = "rbxassetid://123781288054070",
}
local SAKURA_SKY = {   -- painted sky v16 (the sunset look's sky)
	Lf = "rbxassetid://74770479813737", Rt = "rbxassetid://82977189045949", Bk = "rbxassetid://86835776550719",
	Ft = "rbxassetid://125122225925950", Up = "rbxassetid://97672464419689", Dn = "rbxassetid://104904831743123",
}
table.insert(MapRegistry.List, {
	Id = "SakuraRow", Name = "SAKURA ROW", Sub = "SHRINE · ALLEYS · ROOFTOPS · NIGHT",
	-- no Image yet: MapVote draws the card without a picture until a capture is uploaded
	Accent = "Gold", Model = "Map_SakuraRow", Light = SAKURA_NIGHT_LIGHT, Sky = SAKURA_NIGHT_SKY,   -- sunset: Light = SAKURA_SUNSET_LIGHT, Sky = SAKURA_SKY
})

table.insert(MapRegistry.List, {
	Id = "MarketHall", Name = "MARKET HALL", Sub = "IRON HALL · CUSTOMS POSTS · SERVICE ALLEYS",
	-- 2026-10-21: F7 inside-out team map, a 19th-century port market at midday, parked at (-8000, 0, 0). No Image yet:
	-- MapVote draws the card without a picture. Midday = the universal daytime rig and painted sky.
	Accent = "Gold", Model = "Map_MarketHall", Light = UNIVERSAL_LIGHT, Sky = UNIVERSAL_SKY,
})

table.insert(MapRegistry.List, {
	Id = "JungleRuins", Name = "JUNGLE RUINS", Sub = "BUDDHA PLAZA · JUNGLE TRAILS · CREEK",
	-- 2026-10-22: F8 open-arena team map (built for 5v5, plays at the current team size), curved jungle trails into a ruin
	-- plaza with the Buddha and waterfall, parked at (0, 0, 8000). Vegetation is cloned per instance (coarse leaf clumps on
	-- every tier, owner's pick); Vegetation/Detail and Visual/Detail carry QualityLayer = "detail" for HIGH/ULTRA gating
	-- (MapQualityGate). Card: the plaza render, uploaded 2026-10-22. Midday = the universal daytime rig.
	Image = "rbxassetid://131756816686209", Accent = "Gold", Model = "Map_JungleRuins", Light = UNIVERSAL_LIGHT, Sky = UNIVERSAL_SKY,
})

-- Alpine Monastery (2026-10-28): the snow map, a 3v3 two-layer team map (a courtyard round the bell tower; timber walkways
-- and rope bridges above it, reached only by the one stair at the tower), parked at (16000, 0, 0). No Image yet: MapVote
-- draws the card without a picture. Its own painted DAY skybox, made the way SAKURA_NIGHT_SKY was
-- (vmarm/alpine/v1/art/sky/paint_alpine_sky.py; backup SPELLSHOT_Backup/maps/alpine_monastery/sky_v1): a spire to the
-- north (+Z, team A's view), an Everest-like wall to the south (-Z, team B's), a sea of cloud east and west, and the sun
-- glow painted at Roblox (0.369, 0.766, -0.527).
local ALPINE_SKY = {
	Lf = "rbxassetid://78956404398235", Rt = "rbxassetid://73959757354485", Ft = "rbxassetid://105908798236979",
	Bk = "rbxassetid://75273860887178", Up = "rbxassetid://89203194486396", Dn = "rbxassetid://129818625212726",
}
-- the universal afternoon rig with two changes: the sun solved onto the painted glow (0.00 deg off), and a distance fade
-- coloured like the painted horizon band. Offset 0.15 (universal 0.3) lets the painted ranges and cloud sea show at the
-- horizon; Density stays the universal 0.22 (the sky recipe's 0.28 is close to the 0.3 that read dull in game).
local ALPINE_LIGHT = table.clone(UNIVERSAL_LIGHT)
ALPINE_LIGHT.Props = table.clone(UNIVERSAL_LIGHT.Props)
ALPINE_LIGHT.Props.ClockTime = 10.284
ALPINE_LIGHT.Props.GeographicLatitude = -8.30
ALPINE_LIGHT.Atmosphere = { Density = 0.22, Offset = 0.15, Haze = 0, Glare = 0,
	Color = Color3.fromRGB(184, 204, 220), Decay = Color3.fromRGB(148, 172, 206) }
table.insert(MapRegistry.List, {
	Id = "AlpineMonastery", Name = "ALPINE MONASTERY", Sub = "BELL TOWER · WALKWAYS · ROPE BRIDGES",
	Accent = "Cyan", Model = "Map_AlpineMonastery", Light = ALPINE_LIGHT, Sky = ALPINE_SKY,
})
-- (2026-10-28) Skyline v2: the 3v3 team rework of Skyline (towers rev C, dressed in the SKYLINE · RIVALS look),
-- built headless in vmarm\skyline_v2 and imported at (-16000, 0, 0). Practice until the owner has played it, so
-- Solo Test only. The Spire terrace's south edge is the wind edge (StarterPlayerScripts.WindEdgeBoost).
table.insert(MapRegistry.List, {
	Id = "SkylineV2", Name = "SKYLINE · V2", Sub = "TOWERS · BRIDGES · THE WIND EDGE",
	Accent = "Cyan", Model = "Map_SkylineV2", Practice = true, Light = UNIVERSAL_LIGHT, Sky = UNIVERSAL_SKY,
})
local byId = {}
for _, m in ipairs(MapRegistry.List) do
	byId[m.Id] = m
end

function MapRegistry.Get(id)
	return byId[id]
end

return MapRegistry
