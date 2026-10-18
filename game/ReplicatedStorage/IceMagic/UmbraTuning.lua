--[[
	UmbraTuning  (ModuleScript)  ->  ReplicatedStorage/IceMagic/UmbraTuning

	Every number of UMBRA's kit (manual v0.16/v0.17, reworked 2026-09-27), pure data with no requires: VFXLibrary's rows,
	UmbraHandler (the server) and UmbraClient (the clients) all read this one table. Every number is a STAND-IN for the
	owner to tune unless it says OWNER. Units: studs, seconds, HP (Config.MaxHealth is 150). Walk 16, sprint 25.

	THE DESIGN LAW (the owner): Shadow Dart is Umbra's real damage. Everything else buffs it or sets it up. So the Primary,
	the Ultimate and Decoy Double deal no damage at all, and Mark's payoff only ever rides on the marker's own hit.
]]

local T = {}

-- M1: SHADOW DART -- the slowest M1 and the hardest single hit. PHASE 4 (2026-09-28): the OWNER set the charge, click to
-- release, at 2.3 s ("the time to shoot when u press till the bullet shoots ... should be 2.3 sec"). FireInterval follows
-- (the charge plus a short recovery), and Damage rose so the kit's real damage source is not a third of every other M1's
-- (42 every 2.6 s would be ~16/s): 65 is 3 hits to a full 150, 2 when unaware (x1.25). Both STAND-INs, flagged to the owner.
-- Under Eclipse the whole cycle runs M1RateMult faster (the charge ~1.53 s, the interval ~1.73 s). 5 mana a dart is ~1.9/s.
T.ShadowDart = {
	FireInterval = 2.6,      -- seconds between clicks (the charge is inside it)
	ManaCost = 5,
	Range = 160,             -- how far the dart flies before it is spent
	Speed = 200,             -- studs/s: 160 studs in 0.8 s -- a sniper's shot that still travels (one M1 speed since 2026-10-17; was 240)
	Damage = 65,
	Windup = 2.3,            -- OWNER: the click to the release; the gather, the held brace, then the snap
	ChargeSlack = 0.25,      -- the server accepts a release this much before the charge is due (jitter), no earlier
	ChargeGiveUp = 2.0,      -- a charge with no release this long after it was due is dropped
	Radius = 0.35,           -- the dart's thickness for the hit ray
	Bucket = 1.5,            -- the server's fire-rate bucket (shots of slack for jitter)
	OriginSlack = 6,         -- the claimed eye may be this far from the server's head, plus speed * (0.35 + ping)
	HitSlack = 1.6,          -- a claimed point may sit this far off the dart's line
}

-- PASSIVE: UNSEEN -- bonus damage on an UNAWARE target, Shadow Dart only (it buffs the M1's hit; it is not a hit of its own).
-- UNAWARE (the owner left the definition to me, "balance it"): Umbra is outside the target's view -- more than
-- UnawareAngle degrees off the way the target faces, flat. In first person a body faces the camera's yaw
-- (FirstPersonController), so 60 is roughly "off the edge of their screen" at the default field of view. Eclipse makes
-- every enemy count as unaware.
T.Unseen = {
	Bonus = 0.25,            -- +25% of the dart's damage
	UnawareAngle = 60,
}

-- PRIMARY: SHADOW STEP -- no dash: the body dissolves where it stands and re-forms at the destination. The server picks
-- the destination (toward the crosshair, capped at Distance, stopped short of walls, onto a floor) and moves the body.
-- VEILED from the dissolve until VeilTime after the re-form: no new target lock may pick Umbra (Earthen Tomb, Mirror
-- Cage), and a fissure already homing on them loses them.
T.ShadowStep = {
	Cooldown = 10, ManaCost = 20,
	Distance = 22,           -- the furthest a step goes
	MinDistance = 4,         -- a step shorter than this is refused and given back (nowhere to go)
	AimPad = 2.5,            -- aimed at something nearer than Distance, the step stops this far short of it (never inside a body)
	AimRange = 60,           -- how far the crosshair's aim point is read
	DissolveTime = 0.12,     -- dissolve to re-form: near-instant, no travel arc
	VeilTime = 0.6,          -- after the re-form
	WallPad = 2.0,           -- stop this far short of a wall
	Clearance = 5.5,         -- the body needs this much headroom where it re-forms
	-- THE DIVE REWARD (2026-10-18, umbra; handoff #8, the 3v3 sim's P27 "half cooldown"): the 10 s cooldown is DiveCooldown
	-- instead when the step is cast within DiveWindow after Umbra landed a hit on an enemy, or when Umbra lands one within
	-- DiveWindow after casting it (the running cooldown is then cut to end at the cast + DiveCooldown, once per cast). The
	-- normal cast only, never below DiveCooldown. DiveCooldown = Cooldown turns it off. UmbraHandler applies it.
	DiveWindow = 2,
	DiveCooldown = 5,
	-- THE ESCAPE BLINK (2026-10-18, umbra; the owner: "same key, second charge"): a second, independent charge. While
	-- the step's own cooldown runs and this one is ready, the press is the same blink (same rules, look, veil and mana)
	-- and starts THIS cooldown instead. Both ready: the normal step. Neither touches the other; no dive reward on it.
	-- 0 disables it. SpellshotService picks which (CDEscape_Primary), through VFXLibrary's row.
	EscapeCooldown = 6,
}

-- TECHNIQUE: MARK (replaces Fade Step in the pool). Self-only: only the marker's OWN hit cashes it (the owner). Stacks
-- ripen one per StackEvery up to MaxStacks; a full mark left alone for ExpireAfterFull goes. The marker's next real hit
-- on the marked target spends it: a HEADSHOT (Shadow Dart only -- the one place the game tells head from body) adds
-- HeadBonus[stacks], anything else BodyBonus[stacks]. OWNER: 150 on the head at full stacks. The body values are mine.
T.Mark = {
	Cooldown = 14, ManaCost = 18,
	Range = 120, LockRadius = 7, RangeSlack = 6,   -- Earthen Tomb's lock rule: nearest the aim line, in sight
	StackEvery = 1.0, MaxStacks = 3,
	ExpireAfterFull = 5.0,
	HeadBonus = { 50, 100, 150 },
	BodyBonus = { 10, 20, 30 },
	HuntedHold = 2.2,        -- how long HUNTED! stays up over the target (the owner: "there for a bit of time")
}

-- TECHNIQUE: DECOY DOUBLE (kept, mechanically unchanged: a stationary illusion). Numbers new -- the config only ever had
-- Cooldown 20. It carries a player's full health (so the first hit's number reads like a real body's) and breaks on the
-- first damage it takes -- the Tell -- or at Duration.
T.DecoyDouble = {
	Cooldown = 20, ManaCost = 18,
	Duration = 8,
	Offset = 3.8,            -- it peels off to the side, this far from Umbra's root (3.3 still let the hands graze)
}

-- ULTIMATE: ECLIPSE -- no damage. For Duration: every enemy counts as unaware (Unseen), every enemy is revealed to Umbra
-- alone through walls, and Shadow Dart fires FireRateMult times as fast. The world darkens for EVERYONE in the duel (the
-- owner); the reveal outline is Umbra's alone.
T.Eclipse = {
	WindupTime = 1.0,        -- the held beat: the caster presses the mass, held in place (the Ultimate's telegraph)
	Duration = 7,
	FireRateMult = 1.5,      -- 1.3 s -> 0.87 s between darts
	RevealMax = 20,          -- outlines at most this many bodies (a client may draw about 31 Highlights)
	RevealRange = 250,
}

-- stand-in looks (Phase 3 replaces every one with the obsidian kit): the palette of manual v0.17
T.Color = {
	Glint = Color3.fromRGB(232, 222, 255),   -- pale lavender-white: rare highlights, the Tell lit
	Shade = Color3.fromRGB(181, 140, 240),   -- #B58CF0, the established Umbra colour, used sparingly; the reveal outline (OWNER)
	Dusk = Color3.fromRGB(52, 28, 92),       -- deep violet
	Void = Color3.fromRGB(16, 10, 26),       -- near-black, violet-tinted: the dominant tone
}

----------------------------------------------------------------------------------------------------
-- PHASE 4 (2026-09-28): THE APPROVED LOOK -- paste this block into UmbraTuning just above `return T`.
-- UmbraFX (ReplicatedStorage.IceMagic.UmbraFX) reads every number below. Sources: Phase 3 agent A rounds 3-4
-- (A_r3/umbra_ribbons_buildspec_r3.json, A_r4/umbra_ribbons_buildspec_r4.json: the dart's charge, the dart, the hit,
-- the ball recipe) and agent B rounds 3-4 (B_r3/UmbraB_r3_BuildSpec.json, B_r4/UmbraB_r4_BuildSpec.json: Shadow Step,
-- Decoy Double option A, Eclipse), plus the owner's final calls of 2026-09-28 (marked OWNER).
-- Timing, size, colour, strength and the per-ribbon tables are here; the ribbon EQUATIONS (the curves' own shape
-- coefficients, e.g. a spiral's 0.5 per radian) stay beside their formulas in UmbraFX, quoted from the specs.
----------------------------------------------------------------------------------------------------

-- OWNER: the reveal outline during Eclipse is LIGHT PURPLE #B58CF0 (not glint)
T.Eclipse.RevealColor = Color3.fromRGB(181, 140, 240)

-- Texture asset ids (uploaded 2026-09-28; the two Ball*Map entries are for the template only and stay nil until it is
-- built): nil until uploaded ("rbxassetid://<id>" or the bare number). A nil texture degrades: a Beam with
-- no texture still draws its colour, a ball with no rim image gets a thin stroked ring, the screen layer is skipped.
T.Textures = {
	RibbonLightA = "rbxassetid://109931227427807",       -- A_r3/textures/umbra_ribbon_light_r3.png   256x64: the dart's charge, streamers, hit
	RibbonShadowA = "rbxassetid://95722712098758",      -- A_r3/textures/umbra_ribbon_shadow_r3.png  256x64
	RibbonLightB = "rbxassetid://139533447815380",       -- B_r3/kit/UM_Ribbon_Light_r3.png           512x64: Shadow Step, Decoy Double, Eclipse
	RibbonShadowB = "rbxassetid://85128829169473",      -- B_r3/kit/UM_Ribbon_Shadow_r3.png          512x64
	BallRimHalo = "rbxassetid://89938070210326",        -- A_r4/textures/umbra_ball_rimhalo_r4.png   256x256: every ball's rim + halo billboard
	BallBody1P = "rbxassetid://86732871924210",         -- ballsprite/umbra_ball_body_1p.png         512x512: the r4 ball as the video drew it, 1P angle
	BallBody3P = "rbxassetid://140188709218430",        -- ballsprite/umbra_ball_body_3p.png         512x512: the same, 3P angle (every other view)
	EclipseVignette = "rbxassetid://113967916062480",    -- B_r4/kit/UM_EclipseVignette_r4.png        1024x1024: the screen layer's vignette
	EclipseEdge = "rbxassetid://87743960734720",        -- B_r4/kit/UM_EdgeRibbon_r4.png             1024x128: the screen layer's four edge strips
	-- INSTALL TIME ONLY: the ball template's SurfaceAppearance maps (a game script may not write them; set in Edit mode)
	BallColorMap = nil,       -- A_r4/textures/umbra_ball_color_r4.png     64x64, flat #100A1A
	BallRoughnessMap = nil,   -- A_r4/textures/umbra_ball_roughness_r4.png 64x64, flat 0.08
}

T.FX = {
	-- THE ENGINE: one render step for every live effect, pooled Beams and Attachments
	Engine = {
		RenderPriority = 3,           -- Enum.RenderPriority.Camera + 3: after the Viewmodel (Camera + 2) placed the arms
		CullDistance = 400,           -- a world effect this far from the camera draws nothing (its clock still runs)
		PoolBeams = 96,               -- spare Beams kept for reuse (the Eclipse open peaks at 48 + the domain's 12)
		PoolAttachments = 144,
		MaxLife = 12,                 -- any effect is torn down this long after it began (seconds / ShotTimeScale)
		-- STUDIO CHECKS (Phase 3 could not verify these; each is a one-number fix):
		CurveSize1Sign = 1,           -- -1 if a ribbon bows the wrong way at its trailing end
		WidthOnSecondaryAxis = true,  -- false if an A-style strip (FaceCamera off: the charge, the hit) shows edge-on
		TextureSpeedSign = 1,         -- -1 if a B-style running band flows toward the ribbon's tail instead of its head
		-- (satin edges running lengthwise on the A strips: upload A_r3's *_rot90.png under the same Textures keys instead)
	},

	-- AGENT A'S RIBBONS: the colour is Beam.Color x the texture; the running band is a lift in the Color sequence
	RibbonA = {
		Segments = 16,
		Lit = Color3.fromRGB(255, 255, 255),         -- the band at full Tell
		BrightnessGain = 3.5,                        -- Brightness = 1 + 3.5 L (4.5 lit)
		light = { Rest = Color3.fromRGB(186, 178, 204), Band = Color3.fromRGB(232, 222, 255), Emission = 0.30, EmissionGain = 0.50,
			Untextured = Color3.fromRGB(199, 161, 240) },   -- the strip's body colour, multiplied in while no strip is uploaded
		shadow = { Rest = Color3.fromRGB(159, 129, 192), Band = Color3.fromRGB(199, 161, 240), Emission = 0.00, EmissionGain = 0.45,
			Untextured = Color3.fromRGB(67, 44, 98) },
	},

	-- AGENT B'S RIBBONS: colour and band are baked in the texture (Color white), TextureSpeed runs the band
	RibbonB = {
		Quiet = { light = 0.2, shadow = 0.0 },       -- LightEmission at rest
		Flare = { light = 0.7, shadow = 0.0 },       -- ...at a full Tell (shadow stays 0: dark silk rimmed with glint)
		Transparency = { { 0, 1 }, { 0.28, 0.22 }, { 0.86, 0.08 }, { 1, 0.45 } },   -- f = 0 tail .. 1 head
		SpeedJitter = 0.05,                          -- each ribbon's TextureSpeed +-5% (no texture offset exists)
		Untextured = { light = Color3.fromRGB(181, 140, 240), shadow = Color3.fromRGB(52, 28, 92) },   -- no strip yet: flat body colours
	},

	-- THE TELL (OWNER: ribbons and the balls' rims flare glint when concealment breaks -- dart fired, hit landed, decoy
	-- failing -- and are subdued otherwise). A's envelopes are a hold then an exponential decay; B's rises, holds, falls.
	Tell = {
		Release = { Hold = 0.06, Decay = 0.20 },     -- the dart fired (a dart inside ~25 studs is lit its whole flight)
		Hit = { Hold = 0.06, Decay = 0.12 },         -- a hit landed
		Flare = { Rise = 0.04, Hold = 0.22, Fall = 0.45 },   -- B: the decoy failing
		BodyLight = { Brightness = 2, Range = 7, Time = 0.35 },   -- a glint on the chest for others (Brightness 0: off)
	},

	-- THE BALL RECIPE (A_r4, all four balls): glossy void MeshPart + rim/halo billboard + a small violet light
	Ball = {
		RimExtent = 1.4,              -- the rim image's half width, in ball radii
		AttachK = 0.5,                -- the billboard sits this many radii toward the camera
		LightBrightness = 0.5,        -- B0 (x the ball's growth); tune against A_r4/umbra_ball_r3_vs_r4.png
		LightRangeK = 17,             -- Range = 17 x the ball's full radius x its scale
		TellLightGain = 1.0,          -- OWNER: the balls flare with the Tell -- the light doubles and the rim goes glint
		FallbackReflectance = 0.15,   -- no template AND no body sprite: a SmoothPlastic sphere with this Reflectance
		ShadowOnly = 0.98,            -- with the body sprite: the third-person part's Transparency (it only casts the shadow)
		MaxDistance = 250,            -- the rim billboard's
		Template = "UmbraBall",       -- ReplicatedStorage.IceMagicMeshes.UmbraKit.<this>
	},

	-- M1 SHADOW DART, THE CHARGE (A_r3 charge): four ribbons spiral in along the forearm and loop the forming ball
	DartCharge = {
		SpecWindup = 2.30,            -- the drawing's clock: the real charge (Windup / M1RateMult) is mapped onto it
		Palm = Vector3.new(0, -0.36, -0.14),        -- 3P: RightHand-local
		LowerArm = Vector3.new(0, 0.4, 0),          -- 3P: the arm polyline's points, part-local
		UpperArm = Vector3.new(0, 0.45, 0),
		FistBall = Vector3.new(0.04, 0.18, -0.03),  -- 1P: at the right fist's tip (arm tip frame; 0.09 hid it in the fist, 0.22 floated, 0.16 sliced: the owner, 09-30)
		AttachK1P = 2.4,                            -- 1P: the ball's billboard sits this many radii toward the camera, in front of the knuckles (see Ball:put)
		Scale1P = { K = 0.5, Near = 1.25, Min = 0.3, Power = 1.6 },   -- S = K clamp(dist / Near, Min, 1) ^ Power
		CoreRadius = 0.23, CoreFrom = 0.35, CoreGrow = 1.25, CoreCollapse = 0.05, CoreSpin = 0.8,
		Births3P = { 0.08, 0.34, 0.60, 0.86 },
		Births1P = { 0.10, 0.32, 0.54, 0.76 },
		SpiralIn = 0.80,              -- D: the spiral-in along the forearm
		Length = 0.55,                -- Lr: a ribbon is its head's last 0.55 s of path
		Orbit = 0.60,                 -- the loop's radius (x S)
		Tighten = { From = 1.95, To = 2.28, By = 0.10 },   -- the enemy's "about to fire" cue (no flash)
		Collapse = 0.08,              -- the loops collapse at the release (lit)
		Twist = 0.9,                  -- the silk twist (radians)
		Width = { light = 0.24, shadow = 0.30 },
		Ribbons = {
			{ Kind = "shadow", Normal = Vector3.new(0.25, 1, 0.15), Precess = Vector3.new(1, 0.2, 0) },
			{ Kind = "light", Normal = Vector3.new(1, 0.35, 0.45), Precess = Vector3.new(0, 1, 0.3) },
			{ Kind = "shadow", Normal = Vector3.new(-0.55, 0.45, 1), Precess = Vector3.new(0.3, 0, 1) },
			{ Kind = "light", Normal = Vector3.new(0.7, -0.55, 0.65), Precess = Vector3.new(0.6, 0.6, -0.4) },
		},
		LastFor = 0.12,               -- after the release everything is gone by then
		CancelFade = 0.1,             -- a charge dropped without a release (death, respawn) fades this fast, unlit
	},

	-- M1 SHADOW DART, IN FLIGHT (A_r3 dart + A_r4 head): a glossy void teardrop and three braided streamers
	Dart = {
		HeadSize = Vector3.new(0.28, 0.28, 0.72),   -- full size, x sd
		GrowOver = 5, GrowFrom = 0.35,              -- sd = 0.35 + 0.65 clamp(travelled / 5, 0, 1)
		LightRadius = 0.192,                        -- the head's equivalent radius, for the light's Range
		Kinds = { "light", "shadow", "light" },
		Width = { light = 0.17, shadow = 0.20 },
		Length = 5,                   -- the streamers' length, x sd
		Lead = 0.2,                   -- they start this far behind the head (x sd)
		Amp = 0.30, Braid = 0.8, Spin = 2.5,   -- the braid's radius (x sd), turns along it, turns per second
		BandSpeed = 3.0, BandSpacing = 1.2,
		PourTime = 0.12, GoneAfter = 0.16,     -- at the impact the streamers pour in, then are gone
		EaseOver = 12,                -- the visual eases from the hand onto the eye's line over this many studs
	},

	-- THE HIT (A_r3 hit + A_r4 core): five unequal curls unfurl over the side facing the shooter and dissolve
	Hit = {
		Life = 0.62,
		CoreRadius = 0.17, CoreBloom = 0.05, CoreHold = 0.10, CoreClose = 0.16, CoreSpin = 1.5, CoreOut = 0.03,
		Inset = 0.02,                 -- the splash's root sits this far out of the surface, toward the shooter
		CurlK = 0.5, CurlTurn = 270,  -- the tightening spiral: e^-0.5 per radian, 270 degrees
		Reach = 1.5, SizeK = 1.35,    -- rho = 1.35 size; outward 1.5 rho
		Run = 0.30,                   -- the heads' run (cubic ease out)
		DissolveFrom = 0.16, DissolveTime = 0.34, DissolveOver = 1.15, Soft = 0.9,
		Spin = 0.5, Phase = 0.4,
		Grow = 0.12,
		BandRun = 2.2, BandWidth = 0.55, BandLitWidth = 2.2,
		Width = { light = 0.26, shadow = 0.32 },
		Ribbons = {
			{ Azimuth = 0.00, Kind = "light", Size = 1.10, Delay = 0.00, Swirl = 0.70, Rise = 0.85 },
			{ Azimuth = 0.36, Kind = "shadow", Size = 1.00, Delay = 0.00, Swirl = -0.45, Rise = 0.60 },
			{ Azimuth = 0.64, Kind = "light", Size = 0.92, Delay = 0.00, Swirl = 0.40, Rise = 1.00 },
			{ Azimuth = 0.17, Kind = "shadow", Size = 0.74, Delay = 0.03, Swirl = -0.60, Rise = 0.50 },
			{ Azimuth = 0.50, Kind = "shadow", Size = 0.70, Delay = 0.04, Swirl = 0.55, Rise = 0.75 },
		},
	},

	-- OWNER: the Mark HEADSHOT payoff -- the hit's curls at the head, brighter, with a glint flash. Short and quiet.
	MarkHeadshot = {
		Size = 1.15,                  -- the curls' size x this
		Brightness = 1.35,            -- the curls' Brightness x this
		Hold = 0.10, Decay = 0.18,    -- the curls stay lit a little longer than a plain hit
		FlashBrightness = 5, FlashRange = 9, FlashRise = 0.03, FlashFall = 0.18,
		FlashSize = { From = 1.0, To = 2.4 },   -- a glint disc (the rim image in glint) that swells and fades
	},

	-- PRIMARY SHADOW STEP (B_r3): unravel here, weave there, nothing between; the stepper sees a silk iris
	Step = {
		SpecDissolve = 0.12,          -- the drawing's re-form beat: the real Dissolve is mapped onto it
		RootAboveFloor = 3.0,
		HideAt = 0.05,                -- others: the body vanishes at this beat of the drawing (the cue plays first)
		LandWait = 0.6,               -- the stepper's veil waits at most this long past the dissolve for the view to jump
		Origin = {
			Life = 0.5, Span = 0.3, Segments = 12, TextureSpeed = 1.3, Width = 0.95,
			Kinds = { "shadow", "light", "shadow", "light", "shadow" },
			Dy = { -0.5, 0.6, -0.45, 0.55, -0.6 },
			Tilt = { 0.55, 0.5, 0.6, 0.45, 0.5 },
		},
		Destination = {
			Life = 0.56, Segments = 12, TextureSpeed = 1.3, Width = 0.62,
			Kinds = { "shadow", "light", "shadow", "light", "shadow" },
			Hs = { 0.9, -0.8, 0.7, -0.9, 0.8 },
			Tilt = 0.45,
		},
		Veil = {
			Life = 0.45, Span = 0.08, Segments = 12, TextureSpeed = 1.3, Width = 0.62,
			Kinds = { "shadow", "shadow", "light", "shadow" },
			Phi0 = { 0.6, 2.2, 3.75, 5.3 },
			Depth = 1.8, Aspect = 1.78,
		},
		Arms = { Life = 0.34, Span = 0.08, Segments = 14, TextureSpeed = 1.3, Width = 0.22, Kinds = { R = "light", L = "shadow" } },
	},

	-- TECHNIQUE DECOY DOUBLE (B_r3, OWNER: option A -- once peeled it looks exactly like Umbra; Offset 3.8 is DecoyDouble's)
	Decoy = {
		ShadowSkin = Color3.fromRGB(27, 17, 48),    -- #1B1130 while a piece travels
		Peel = { Stagger = 0.16, Travel = 0.26, Lift = 0.12, Tilt = 10, Scale = 1.04, Recolour = 0.18 },
		Streamers = {
			Span = 0.24, Segments = 14, TextureSpeed = 1.4, Width = 0.45, Amp = 1.2, Wave = 0.35,
			Kinds = { "light", "light", "light", "shadow", "light", "shadow" },
			Anchors = {   -- { part, part-local fraction of its half size }
				{ "Head", Vector3.new(0.6, 0.85, 0) }, { "RightUpperArm", Vector3.new(0.5, 0.95, 0) },
				{ "RightHand", Vector3.new(0.95, -0.3, 0) }, { "UpperTorso", Vector3.new(0.95, -0.6, 0.5) },
				{ "LeftUpperArm", Vector3.new(-0.4, 0.95, 0) }, { "RightLowerLeg", Vector3.new(0.95, 0, 0.3) },
			},
			Billow = {    -- the free ends' drift, in the caster's frame
				Vector3.new(-0.2, 0.8, -0.6), Vector3.new(0.1, 0.7, -0.7), Vector3.new(0.4, -0.3, -0.85),
				Vector3.new(0.2, -0.4, -0.9), Vector3.new(-0.1, 0.75, -0.65), Vector3.new(0.3, -0.2, -0.9),
			},
		},
		Break = {
			Life = 0.5, Span = 0.26, Segments = 12, TextureSpeed = 1.6, Width = 0.50,
			Parts = { "UpperTorso", "UpperTorso", "Head", "RightUpperArm", "LeftUpperArm", "RightLowerLeg", "LeftLowerLeg", "LowerTorso" },
			Kinds = { "light", "shadow", "shadow", "light", "shadow", "shadow", "light", "shadow" },
			Speed = { 15, 20 }, Spin = { 6.5, 9.0 }, Damp = 2.6, Fan = 2.2, Jitter = 0.2, Lift = 0.6, Spread = 0.35,
			Fallback = Vector3.new(-1.3, 0.5, -0.7),   -- the hit point in the decoy's frame when none is known
		},
		Arm1P = {     -- the caster's first-person cast: a shadow-skin copy of the right arm slides out of the right edge
			Life = 0.36, Slide = 0.30, Span = 0.16, Segments = 14, TextureSpeed = 1.4, Width = 0.30,
			Idle = { X = 1.055, Y = -1.307, Z = -0.634, Pitch = 68.2, Yaw = 27.7, Roll = -11.8, Wrist = 0 },   -- Viewmodel POSE.Idle.R
			Move = { X = 2.6, Y = -0.1, Z = 0.15, Yaw = -35, Roll = 12 },
			Kinds = { "light", "shadow" },
			Anchors = { Vector3.new(0.19, 0.12, -1.0), Vector3.new(0.19, 0.12, -0.25) },
		},
	},

	-- ULTIMATE ECLIPSE (B_r3 vortex + B_r4 world/screen; OWNER: grade V4, the caster's screen lighter, enemies' stronger)
	Eclipse = {
		SpecWindup = 1.0,             -- the drawing's open: the real windup (Eclipse.WindupTime) is mapped onto it
		CancelFade = 0.2,             -- EclipseCancel (died or cleared in the windup): the vortex and core go this fast
		Vortex = {
			Span = 0.3, Segments = 14, TextureSpeed = 1.1,
			Kinds = { "shadow", "light", "shadow", "shadow", "light", "shadow" },
			Z0 = { 1.4, -1.1, 0.9, -1.5, 1.2, -0.8 },
			Axis3P = Vector3.new(0.75, 0.25, -0.6), Axis1P = Vector3.new(0.3, 0.25, 1.0),
			Scale1P = 0.42,
			Width3P = 0.40, Width1P = 0.15,
			Precession = 0.8,
			Swell = 0.6, SwellFlare = 0.2, SwellTime = 0.45,   -- the open's shade swell (not the Tell: no glint)
		},
		Core = { Diameter = 0.84, Press = 0.14, Radius3P = 0.36, Radius1P = 0.15 },
		Wave = {
			Life = 1.65, Span = 0.22, Segments = 16, TextureSpeed = 1.6, Width = 0.9, Count = 12,
			Start = 1.2, Reach = 60, Rate = 1.2, Height = 0.45, Ripple = 0.18, Curl = 0.55,
		},
		Pulse = {
			Rise = 0.06, Fall = 0.45,
			Tint = Color3.fromRGB(216, 198, 255), Brightness = 0.015, Saturation = 0.10,
			LightBrightness = 3, LightRange = 60, LightHeight = 7,
		},
		Wisps = {
			Span = 2.6, Segments = 14, TextureSpeed = 0.6, Width = 0.55, Alpha = 0.7, FadeIn = 0.9, FadeOut = 0.5,
			Centres = {   -- in the caster's frame at the open (x right, y up, -z facing), ray-checked against walls
				{ Vector3.new(-6.5, 4.8, 9.0), "shadow" }, { Vector3.new(6.0, 5.6, 14.0), "light" },
				{ Vector3.new(-1.0, 7.0, 22.0), "shadow" }, { Vector3.new(-5.0, 6.0, -9.0), "shadow" },
				{ Vector3.new(6.0, 4.6, -13.0), "light" }, { Vector3.new(0.5, 8.0, -20.0), "shadow" },
			},
			Loop = Vector3.new(3.0, 1.3, 1.2),
			WallPad = 3,
		},
		-- OWNER "V4": the world grade for everyone in the duel, tweened in and back to the map's OWN values (recorded at
		-- the start, never assumed)
		Grade = {
			InTime = 0.35, OutTime = 0.5,
			Lighting = { Brightness = 0.6, ExposureCompensation = -0.35,
				Ambient = Color3.fromRGB(62, 50, 92), OutdoorAmbient = Color3.fromRGB(70, 58, 100) },
			Atmosphere = { Density = 0.38, Color = Color3.fromRGB(74, 58, 110), Decay = Color3.fromRGB(40, 26, 70), Haze = 1.2 },
			ColorCorrection = { Brightness = -0.04, Contrast = 0.22, Saturation = -0.85, TintColor = Color3.fromRGB(176, 154, 232) },
		},
		-- OWNER: the caster gets the lighter screen layer, enemies inside the stronger one (videos 5 and 5b)
		Screen = {
			DisplayOrder = -1,        -- under the HUD
			Stagger = 0.04, SlideIn = 0.40, FadeIn = 0.12, OutStagger = 0.03, Out = 0.5,
			VignetteIn = 0.38, VignetteDelay = 0.02, BreatheFrom = 0.4, BreathePeriod = 3.2, BreatheVignette = 0.10,
			Along = 0.10, Drift = 0.04, DriftPeriod = 5.5, Swing = 14, Whip = 1.6, StripLength = 0.80,
			StripFade = { { 0, 1 }, { 0.28, 0 }, { 0.72, 0 }, { 1, 1 } },   -- each strip's UIGradient: segments, never a frame
			caster = { Vignette = 0.45, Strip = 0.40, Thick = 0.12, Inset = 0.04, Flow = 0.07, Breathe = 0.0 },
			enemy = { Vignette = 0.12, Strip = 0.15, Thick = 0.16, Inset = 0.06, Flow = 0.09, Breathe = 0.012 },
		},
	},
}

return T
