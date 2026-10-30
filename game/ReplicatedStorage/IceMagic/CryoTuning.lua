--[[
	CryoTuning  (ModuleScript)  ->  ReplicatedStorage/IceMagic/CryoTuning

	ONE table for the numbers of the rebuilt Cryo Techniques and Ultimate (the owner, 2026-09-24: "implement them in the
	game", with the proposed numbers): Blizzard (a Technique, the Mobility half of the pool), Deep Freeze (a Technique,
	the Defense half) and Mirror Cage (Cryo's Ultimate). They replace Frost Slide, Chill Aura and Cryo Beam.

	Pure data plus two pure helpers, and no requires, so VFXLibrary can read it while it loads (its ability rows take
	their Cooldown / ManaCost / Range from here), AbilityHandler decides gameplay from it and CryoFX draws from it. Change
	a number here and the server, the HUD cooldowns and the visuals all follow.

	Units: studs, seconds, HP (Config.MaxHealth is 150). Speeds are studs/s: walk 16, sprint 25, crouch 8.
]]

local CryoTuning = {}

-- BLIZZARD: a storm dropped where the crosshair points, at most CastRange (20) away (2026-10-19, audit P6B-11: was
-- "where the caster stands", the pre-P29 rule; CastRange = 0 brings it back). Everyone else inside it who may be hurt
-- is slowed and can barely see; the caster and anyone they may not hurt are untouched. No damage: it is control, and
-- the slow is its payoff.
CryoTuning.Blizzard = {
	-- CastRange (2026-10-18, P29; the owner picked 20, the range that left Terra alone in the 3v3 sim): the storm drops
	-- where the crosshair points, at most this far from the caster (the row's Range too). 0 = where the caster stands.
	CastRange = 20,
	Cooldown = 18,
	ManaCost = 28,
	Radius = 32,             -- the zone edge, and the Frost Line ring (the line IS the edge)
	Duration = 6, --[[8 until the 2026-10-17 balance pass]]
	Height = 24,             -- the snow column; the zone counts feet from Below under the centre to Height over it
	Below = 4,
	-- The slow is a CAP (AbilityHandler's applySlow; a percentage slow does not exist in the game): 14 takes a sprint
	-- (25) down by 56% and a walk (16) by 31%. Under 16, so nobody wall-runs through a storm. Until the 2026-10-17
	-- balance pass it was 14, kept at or above the dash threshold (12) on purpose so a dash was a way out; now the storm
	-- is the one zone a chaser cannot dash through (and DashMotor's DashMinCap is 16).
	SlowCap = 11, --[[14 until the 2026-10-17 balance pass]]
	Tick = 0.3,              -- the server re-applies the slow this often...
	SlowHold = 0.45,         -- ...for this long, so walking out ends it within half a second
	FormTime = 0.6,          -- snow and haze come up over this long
	Arcs = 8,                -- the edge line is 8 arcs that go dark one by one, spread over the storm's Duration
	-- what the storm does to the view of someone caught inside (client-side: CryoFX)
	HazeColor = Color3.fromRGB(168, 205, 230),   -- #A8CDE6
	HazeDensity = 0.72,      -- the Atmosphere density inside (the map's own comes back on the way out)
	HazeIn = 0.4,
	HazeOut = 0.7,
	ScreenHaze = 0.8,        -- a light flat haze over the screen, as a transparency (1 = none); the fog does the rest
	-- the storm's snow (CryoFX, play-test fix 3: all of it in round Cylinder volumes). Rates are per second at Graphics
	-- Quality High, scaled by Graphics Quality and halved for somebody else's storm under Reduce Enemy VFX; the whole
	-- storm is then capped at MaxParticles live particles (every rate scaled down together if it would hold more).
	-- At High it holds about 690: wall flecks 20 x 8/s x 2.0 s = 320, wall streaks 20 x 4/s x 1.3 s = 104, the inner
	-- ring 10 x 3.2/s x 2.0 s = 64, the wall puffs 20 x 1.5/s x 1.4 s = 42, flakes 90/s x 1.4 s = 126, haze 4/s x 2.8 s
	-- = 11, powder 6/s x 2.85 s = 17. Low Graphics Quality is about 40% of that; Reduce Enemy VFX halves somebody else's.
	Snow = {
		MaxParticles = 700,
		WallColumns = 20, ThinColumns = 12, WallColumnR = 4.5, WallRate = 8,
		InnerColumns = 10, InnerRingAt = 6, InnerShare = 0.4,      -- a sparser ring inside: the band thins inward
		Stream = 7, Drift = 1.2,  -- studs/s^2 round the ring, and outward (the band thins outward as flecks stream off it)
		FleckSize = { 0.9, 0.5 }, FleckLife = { 1.6, 2.4 },
		StreakRate = 4, StreakSize = { 0.8, 0.6 }, StreakSquash = 1.6, StreakLife = { 1.0, 1.6 },
		PuffRate = 1.5, PuffSize = { 3, 5 }, PuffLife = { 1.2, 1.6 },   -- soft support in the wall: few, small, short
		InsideR = 0.8, FlakeRate = 90, FlakeLife = { 1.0, 1.8 },
		HazeR = 0.7, HazeRate = 4, HazeSize = { 6, 10 }, HazeLife = { 2.4, 3.2 },
		PowderRate = 6,
	},
}

-- DEEP FREEZE: an unseen trap put down at the caster's feet. The first enemy whose feet come within Reach sets it off:
-- a ring bursts out on the ground, and they are sealed in a crystal prison, rooted, for Root seconds. Only the caster
-- is shown where it is.
CryoTuning.DeepFreeze = {
	Cooldown = 16,
	ManaCost = 22,
	Reach = 4,               -- trigger radius, feet to trap point, flat
	Above = 3,               -- a body counts from Below under the trap to Above over it (a jump clears it)
	Below = 1.5,
	ArmTime = 0.5,           -- it is live this long after it goes down
	Life = 20,               -- an untriggered trap melts after this long
	MaxTraps = 1,            -- a new one replaces the caster's old one
	Root = 1.5, --[[2.5 until the 2026-10-17 balance pass]]
	Damage = 10,             -- on the trigger; the root is the payoff
	Immunity = 1.5,          -- after a prison thaws, no trap can take that victim again for this long
	DropLimit = 30,          -- the trap goes to the ground under the caster, at most this far down; none -> refunded
	-- visuals (CryoFX; the Cryo v2 look, 2026-10-08 -- nothing below is read by the server)
	RingRadius = 3.8,        -- the darker frost disc and its one clean Frost Line ring spread this far...
	RingTime = 0.35,         -- ...in this long; then the ring fades out over RingFade (no white-cyan wash)
	RingFade = 0.4,
	SealTime = 0.28,         -- each crystal of the prison grows along its length over about this long
	LineTop = 5.4,           -- the frost skin (white, the Frost Line riding its top edge) climbs the body to here...
	ClimbTime = 0.5,         -- ...in this long, and the line dims to the calm rim once it stops
	CrackTime = 0.7,         -- white cracks race across the prison over the last CrackTime of the root: the warning
}

-- MIRROR CAGE: Cryo's Ultimate. Round 2 (the owner, 2026-09-24): "the ultimate needs to be way bigger since it can
-- also trap multiple enemies ... make it so that the players who are trapped, their reflection is shooting them".
-- It locks the enemy nearest the crosshair (the Earthen Tomb lock) and raises a dome of cut-ice mirror panels round
-- them, about 40 studs across. EVERY enemy inside it when it closes is trapped (rooted). Out of the panels step ice
-- reflections of each trapped player, mirroring them, and the reflections shoot them. The cage breaks when the
-- volley is spent.
CryoTuning.MirrorCage = {
	Range = 60,              -- the lock, from the caster (Cryo Beam's reach)
	RangeSlack = 2,
	LockRadius = 4.5,        -- how far off the aim line a body may be and still be the lock
	Radius = 20,             -- the ground ring (was 7.5)
	TrapBelow = 3,           -- trapped: flat distance under Radius - 1, feet from TrapBelow under the floor...
	TrapAbove = 14,          -- ...to TrapAbove over it (the dome's height)
	MaxVictims = 6,
	-- the dome, three rings of panels: Count, bottom-edge radius (x Radius), bottom-edge height, panel width and
	-- height, tilt in toward the middle (degrees). Every ring leaves its gap facing the caster.
	Rings = {
		{ Count = 14, R = 1.0, Y = -0.2, W = 5.6, H = 7.5, Tilt = 12 },
		{ Count = 10, R = 0.84, Y = 7.0, W = 6.0, H = 7.0, Tilt = 45 },
		{ Count = 5, R = 0.565, Y = 11.6, W = 6.0, H = 5.5, Tilt = 68 },
	},
	PanelThick = 0.9,
	FormTime = 0.7,          -- the dome rises
	EmergeTime = 0.5,        -- the reflections step out of the panels
	VolleyTime = 0.77, --[[1.6 until the 2026-10-17 balance pass: the same 12 bolts land faster, and the root (MirrorCageRoot) is 2.30 s, was 3.13]]        -- and shoot
	ReflectionsPerVictim = 3,
	BoltsPerReflection = 4,  -- 3 x 4 = 12 bolts at each trapped enemy
	BoltDamage = 6,          -- 12 x 6 = 72 on each (Config.MaxHealth 150); the root lets the caster add their own shots
	BoltFlight = 0.18,
	BreakTime = 1.1,         -- the pieces fall for this long, then sink
	RootPad = 0.15,          -- the trapped stay rooted this long after the last bolt
}

--- The bolts at ONE trapped enemy: { Reflection = 1..ReflectionsPerVictim, Fire, Arrive } in seconds from the cast, in
--- order. Every trapped enemy gets the same list. The server deals each bolt's damage on its Arrive; every client
--- draws it leaving that reflection's hand on its Fire. No remote carries it. The reflections take turns.
function CryoTuning.MirrorCageBolts()
	local M = CryoTuning.MirrorCage
	local shots = M.ReflectionsPerVictim * M.BoltsPerReflection
	local start = M.FormTime + M.EmergeTime
	local list = {}
	for n = 0, shots - 1 do
		local fire = start + M.VolleyTime * (n + 0.5) / shots
		list[#list + 1] = { Reflection = n % M.ReflectionsPerVictim + 1, Fire = fire, Arrive = fire + M.BoltFlight }
	end
	return list
end

--- How long the trapped stay rooted, from the cast.
function CryoTuning.MirrorCageRoot()
	local M = CryoTuning.MirrorCage
	return M.FormTime + M.EmergeTime + M.VolleyTime + M.BoltFlight + M.RootPad
end

-- THE LOOK: Cryo v2 "real ice", approved by the developer 2026-10-07 (vfx_blocking/cryo/ice_v2/CRYO_V2_HANDOFF.md and
-- RECIPE.md are the contract). Visual constants only: CryoFX draws from them, the server never reads them.
--   ICE         milky and translucent: Material Ice (never Glass), Transparency 0.3-0.5, mid ice blue at the tips and
--               deep glacier blue at the thick base. Tall thin pointed spikes off CHUNKY base prisms 2-3x wider, a white
--               matte frost mound over the foot. Heights are measured against the 5-stud character.
--   FROST LINE  the ONLY saturated accent: a thin Neon line on the leading edge of spreading frost, dimming to the calm
--               rim the moment the spread stops. At most two things glow in a frame, and the line is always one.
--   FROZEN      pale ice, still readable (play-test fix 2): a pale fill and white rim, crust on the legs to the waist and
--               caps on the head and shoulders, the encasing ice nearly opaque at its base and clear at its top.
CryoTuning.Look = {
	-- the palette (RECIPE.md)
	FrostLine = Color3.fromRGB(63, 224, 255),     -- #3FE0FF: the accent, Neon, only while frost spreads
	FrostLineHot = Color3.fromRGB(141, 243, 255), -- #8DF3FF: its brief flash
	Calm = Color3.fromRGB(36, 95, 154),           -- #245F9A: the line once the spread stops (no glow)
	Frost = Color3.fromRGB(242, 251, 255),        -- #F2FBFF: frost white, matte (Sand), on plain parts
	ClearIce = Color3.fromRGB(189, 235, 250),     -- #BDEBFA
	MidIce = Color3.fromRGB(91, 184, 232),        -- #5BB8E8: crystal tips
	Glacier = Color3.fromRGB(29, 111, 184),       -- #1D6FB8: the thick base
	-- a frozen body (play-test fix 2, 2026-10-08): the shipped Cryo bands -- a pale IceLight fill, IceMid in the shade,
	-- a thin white rim -- so it reads as ice and stays readable as who it is (it was a #1F3F6B navy silhouette)
	FrozenFill = Color3.fromRGB(214, 246, 255),   -- #D6F6FF IceLight: the Highlight fill
	FrozenShade = Color3.fromRGB(63, 182, 240),   -- #3FB6F0 IceMid: the body's own colours go part way to it
	FrozenRim = Color3.fromRGB(255, 255, 255),    -- the Highlight outline
	Ripple = Color3.fromRGB(214, 244, 255),       -- #D6F4FF: the thin ripple rings
	Flash = Color3.fromRGB(115, 214, 255),        -- #73D6FF: the cold PointLight flash on an impact
	FloorIce = Color3.fromRGB(40, 96, 152),       -- darker frosted floor ice (a plain Part, so this IS its colour)
	-- The kit's crystals are drawn through a SpecialMesh (CryoFX take()), which ignores the meshes' baked vertex colours
	-- (a saturated cobalt), so these ARE the colours: pale ice at the tips, mid ice in the spikes, glacier blue in the
	-- chunky bases and the foot of an encasing mass (the reel's ramp #7CC6EE -> #5BB8E8 -> #3A8FD2 -> #1D6FB8).
	TipTint = Color3.fromRGB(184, 228, 249),
	SpikeTint = Color3.fromRGB(170, 220, 247),
	BaseTint = Color3.fromRGB(52, 128, 200),
	DeepTint = Color3.fromRGB(38, 100, 168),
	PanelTint = Color3.fromRGB(186, 225, 246),
	FrostTint = Color3.fromRGB(250, 253, 255),    -- a frost print / drift over its bake
	-- transparency: the ice body 0.3-0.5; encasing ice 0.12 at the base rising to 0.5 at the top
	TipT = 0.3, BodyT = 0.24, BaseT = 0.14,
	EncaseBaseT = 0.12, EncaseMidT = 0.32, EncaseTopT = 0.45,
	SlabT = 0.15, Reflect = 0.15,
	FrostSkinT = 0.2, PrintT = 0.3, FloorT = 0.3, CrustT = 0.5, MarkerT = 0.72,
	PanelT = 0.35, PanelReflect = 0.4, EdgeT = 0.6, CrackT = 0.35,
	-- the line: thickness, the dim (lit -> calm) and the calm rim's transparency
	LineThick = 0.06, LineDimTime = 0.3, LineDimT = 0.35,
	-- a frozen body: the Highlight fill's transparency, how far its colours go toward FrozenShade, how long they take
	-- to come back; and the frost on it -- the shipped crust meshes (ReplicatedStorage.IceMagicMeshes, opaque white
	-- SmoothPlastic, baked bands): plates on every face of the legs to the waist, a mound round the feet, caps on the
	-- head and shoulders once the frost has climbed CapAt of the way. Sizes are x the body part's own.
	FrozenFillT = 0.55, FrozenShadeAmount = 0.3, TintOut = 0.35,
	FrozenCrust = {
		Plates = { "NovaCrust_01", "NovaCrust_02", "NovaCrust_03", "NovaCrust_04" }, PlateThick = 0.12, PlateOver = 1.15,
		Mound = "RimeCrust_01", MoundSize = Vector3.new(3.0, 0.5, 2.2),
		Cap = "NovaCrust_02", CapOver = 1.25, ShoulderCap = "NovaCrust_01", ShoulderOver = 1.25, CapAt = 0.95,
		Pop = 0.12,
	},
	-- the encasing ice (CRYO_V2_HANDOFF "Encasing mass"): Mass crystals H tall rooted within Foot of the body, Spires SH
	-- tall, FootPrisms chunky prisms FootH tall, a Ring of small clusters (RingSize) from RingInner out, Body crystals
	-- sprouting off the body as the line passes, the frost Band under the line, and the body line's half-widths.
	Encase = {
		DeepFreeze = { Mass = 16, H = { 4.0, 6.0 }, Spires = 2, SH = { 6.6, 7.8 }, Foot = 1.5, FootPrisms = 4, FootH = { 2.4, 3.4 },
			Stagger = 0.15, Ring = 8, RingSize = 3.0, RingInner = 2.3, Body = 10, Band = 0.9, LineRX = 1.2, LineRZ = 0.8 },
		-- a Flash Freeze root (the lingering target): the centre mass, 6-7.5 with 8-10 stud spires
		FlashFreeze = { Mass = 18, H = { 6.0, 7.5 }, Spires = 3, SH = { 8.2, 10.0 }, Foot = 1.6, FootPrisms = 4, FootH = { 2.6, 3.6 },
			Stagger = 0.2, Ring = 8, RingSize = 3.6, RingInner = 2.4, Body = 10, Band = 0.9, LineRX = 1.2, LineRZ = 0.8,
			LineTop = 5.4, ClimbTime = 0.6, Seal = 0.3, GrowAt = 0.1, MaxLife = 6 },
	},
	-- Deep Freeze's tap (the caster's own view): a small frost disc with its line and a bloom that melts away
	Tap = { Disc = 1.5, BloomSize = 1.3, Bloom = 6, MeltAt = 0.75, MeltBy = 1.2 },
	-- Icicle Shard's Chill stacks on the victim: frost and crystals climbing the shins (Height = x knee height), the
	-- third stack climbing to the knees in Climb and growing two ankle-cuff clusters
	Chill = {
		Tiers = {
			{ Height = 0.35, Spikes = 3, Bases = 2, HLo = 0.4, HHi = 0.7, Radius = 0.62 },
			{ Height = 0.65, Spikes = 3, Bases = 0, HLo = 0.6, HHi = 1.0, Radius = 0.72 },
			{ Height = 1.0, Cuffs = true },
		},
		Grow = 0.15, Climb = 0.38, CuffSpikes = 2, CuffH = { 0.7, 1.1 }, LineRX = 1.0, LineRZ = 0.7,
	},
	-- Cold Momentum's print: an oval of ragged frost (studs), its Frost Line rim bright for Rim seconds only, gone in Life
	Print = { Length = 0.85, Width = 0.5, Pop = 0.08, Hold = 0.15, Life = 1.0, Rim = 0.2 },
	-- Blizzard's Frost Line ring draws in over DrawTime, then holds at half brightness; the floor whitens over Whiten
	Blizzard = { DrawTime = 1.0, Half = 0.5, Whiten = 3.5 },
	-- Mirror Cage (the reel, vfx_blocking/cryo/ice_v2/4_mirror_cage, mirror_cage.py, on the game's clock): the lock-on
	-- Frost Line circle (LockR) and frost disc at the lock, a ring of crystal clusters round the target (ClusterRing
	-- studs out), and a hemisphere of thick faceted mirror panels on the dome (Radius, centred DomeY over the floor).
	-- Domes: rings of panels { El (elevation, degrees), Count, Plate (circumradius range, studs) }. Every panel faces
	-- the target, condenses out of cold air, ticks onto it, then pulses its outline, flares and fires a bolt into it
	-- from its own centre, round the ring one after another. The kill: every outline flashes, cracks run, FROZEN!; the
	-- panels shatter inward.
	Cage = { Disc = 5.6, DiscTime = 0.7, LockR = 3.2, LockTime = 0.5, Clusters = 10, ClusterAt = 0.15, ClusterRing = 7.1,
		ClusterH = { 2.2, 3.6 }, Pulse = 0.16, KillPulse = 0.3, Band = 0.9, LineRX = 1.2, LineRZ = 0.8,
		DomeY = 2.6, Thick = 0.46, Rim = 0.11,
		Rings = { { El = 9, Count = 14, Plate = { 2.7, 4.1 } }, { El = 36, Count = 10, Plate = { 2.5, 3.9 } },
			{ El = 63, Count = 5, Plate = { 2.3, 3.3 } } },
		FormAt = 0.35, FormSpan = 0.45, Condense = 0.4, AimAt = 0.85, AimEnd = 1.2, FireAt = 1.2, ShotGap = 0.4,
		Shots = 4, RingStep = 0.05, BoltSpeed = 55, Inward = 0.3, ImpactDur = 0.12, MeltTime = 1.3,
		PanelColor = Color3.fromRGB(255, 255, 255), RimColor = Color3.fromRGB(176, 226, 248), RimT = 0.35 },
	-- the flat art (tools/cryo2_textures.py, uploaded 2026-10-08): every image is pale RGBA, tinted where it is used
	Textures = {
		Panel = { "rbxassetid://99610652776320", "rbxassetid://126736397809773", "rbxassetid://72727303821809",
			"rbxassetid://81574342648116" },
		PanelBack = { "rbxassetid://99397017095928", "rbxassetid://139706576898528", "rbxassetid://137288915438539",
			"rbxassetid://111693153212304" },
		Outline = { "rbxassetid://138578514606346", "rbxassetid://129056801208650", "rbxassetid://130779850949995",
			"rbxassetid://128303668369502" },
		OutlineBack = { "rbxassetid://111745751367460", "rbxassetid://93254129295876", "rbxassetid://73706180098073",
			"rbxassetid://112004667672284" },
		Cracks = { "rbxassetid://107332122582456", "rbxassetid://96512827266282", "rbxassetid://71226893490221",
			"rbxassetid://114279757863268" },
		CracksBack = { "rbxassetid://95773686081441", "rbxassetid://109001735455253", "rbxassetid://114356165949215",
			"rbxassetid://133367101394613" },
		FrostDisc = "rbxassetid://120221293491391",
		FrostDiscLight = "rbxassetid://71847264477388",
		Gust = "rbxassetid://78996293947904",
		Vortex = "rbxassetid://115255674088912",
		Snow = "rbxassetid://122832312371920",
		Powder = "rbxassetid://75934343450088",
		Glint = "rbxassetid://138230231025161",
		Ring = "rbxassetid://117828430324386",
	},
	-- MIRROR CAGE REFLECTIONS (play-test fix 4): the caster as a flat pose card in every panel. The art is five tintable
	-- mask atlases on one pixel grid (tools/cryo2_mirror_cards.py, Blender: the uniform R15 body in five poses ->
	-- D:/voltkit_scratch/cryo2_cards/c2_card_*.png, uploaded 2026-10-08; c2_cards_layout.json has the measurements),
	-- each 5 cells of Cell pixels in the order of Poses: Torso, Sleeve, Hand and Base (head, legs) are white masks with
	-- two flat tone bands, tinted with the caster's Element colours; Ink is the outline, tinted InkColor (ice navy, so
	-- it reads as seen in the glass). Height is the card's height as a share of the panel and Drop moves it down (-) or
	-- up; the cards take the caster's own body colours, untinted (the owner's rule, 2026-10-08); T the card's
	-- transparency once surfaced (SurfaceAt..+SurfaceTime after its panel starts to condense); RollSign undoes the
	-- panel's orientation on its Front / Back face (a Back-face gui reads x mirrored) so the figure stands upright in the
	-- world; Idle the poses the panels cycle through;
	-- ThinShare the share of panels that keep a card for somebody else's cage under Reduce Enemy VFX.
	Card = {
		Tex = {
			Torso = "rbxassetid://77001376502232", Sleeve = "rbxassetid://76462384533185",
			Hand = "rbxassetid://82813750158449", Base = "rbxassetid://129000560998566", Ink = "rbxassetid://78052376305722",
		},
		GlareTex = "rbxassetid://115360059554442",   -- c2_glare.png (tools/cryo2_glare.py)
		Cell = Vector2.new(200, 210),
		Poses = { Front = 1, ThreeLeft = 2, ThreeRight = 3, Back = 4, Cast = 5 },
		Idle = { 1, 2, 3, 4 },
		Height = 0.62, Drop = -0.02, Tilt = 6, T = 0.18, SurfaceAt = 0.15, SurfaceTime = 0.35,
		InkColor = Color3.fromRGB(22, 52, 82),
		-- LIVE: the caster's real avatar on every panel's inner face, like the old cage (Max x Graphics Quality, at least
		-- MinMax, the panels the camera sees the inner face of first; ThinMax for somebody else's cage under Reduce Enemy
		-- VFX), built PerFrame a frame; it turns on the trapped AimLead seconds before its panel's first shot, right arm
		-- straight at them (the body turned AimYaw degrees, the right shoulder leading), and every bolt leaves its hand.
		-- In a ViewportFrame Width x Height of the panel, Drop below its centre, surfacing to transparency T, lit neutral
		-- (no tint), framed with Fit margin at FOV.
		Live = { Max = 36, MinMax = 12, ThinMax = 10, AimLead = 0.15, AimYaw = 30, PerFrame = 4, Width = 0.62, Height = 0.7, Drop = 0,
			T = 0.06, FOV = 30, Fit = 1.06, PixelsPerStud = 28, Ambient = Color3.fromRGB(150, 150, 150),
			LightColor = Color3.fromRGB(255, 255, 255), LightDir = Vector3.new(-0.4, -1, -0.6) },
		-- GLARE: c2_glare.png at Size of the panel, transparency T at rest; a bolt flashes it to FlashT, easing back over
		-- FlashTime (Reduce Flashing: CalmFlash of the flash, over CalmTime)
		Glare = { Size = 0.92, T = 0.45, FlashT = 0, FlashTime = 0.14, CalmFlash = 0.35, CalmTime = 0.3, PixelsPerStud = 20 },
		PixelsPerStud = 24, LightInfluence = 0.35, RollSign = { -1, 1 }, ThinShare = 0.35,
	},
	-- each panel texture's polygon (texture space: x right, y up, the farthest corner at 1), for the rim parts
	PanelPoly = {
		{ { 0.869, -0.071 }, { 0.469, 0.970 }, { -0.594, 0.798 }, { -0.925, 0.115 }, { -0.544, -0.800 }, { 0.705, -0.717 } },
		{ { 0.342, 0.806 }, { -0.649, 0.594 }, { -0.970, -0.255 }, { -0.060, -0.940 }, { 0.923, -0.099 } },
		{ { 0.816, 0.108 }, { 0.426, 0.683 }, { -0.124, 0.970 }, { -0.896, 0.295 }, { -0.757, -0.358 }, { -0.149, -0.796 },
			{ 0.743, -0.585 } },
		{ { 0.690, 0.612 }, { -0.107, 0.854 }, { -0.727, 0.574 }, { -0.745, -0.593 }, { 0.155, -0.970 }, { 0.722, -0.467 } },
	},
}

return CryoTuning
