--[[
	SpellshotConfig  (ModuleScript)  ->  ReplicatedStorage/Spellshot/SpellshotConfig

	Single source of truth for the Element roster, the Technique pool, the status effect vocabulary, the
	movement numbers and every uploaded icon id.

	(2026-10-19, audit P4-14 / P6B-01 / P6B-11) READ THE HISTORY BELOW AS HISTORY. Since P31 (2026-10-18, the owner:
	Techniques swap within your own Element only) Config.TechniquesOwnElementOnly is on: every Element holds only its OWN
	Techniques (Config.ElementMayHold), two slots (Q / E), so the "shared pools", "any Element may equip it" and "a Cryo
	running Scorching Lash" below describe the game with that flag off.

	SOURCE: SPELLSHOT -- Elemental Duels, Full Design Manual **v0.2**.

	WHAT v0.2 CHANGED (this file was written against v0.1 and has been rebuilt):
	  * M1 is now a separate slot from the Primary Ability. v0.1 conflated them under "Primary";
	    an Element now fixes THREE things -- M1 (basic attack), Primary Ability (a signature
	    battle ability) and Passive -- so the HUD carries six slots, not five.
	  * Every entry in all three Technique pools was renamed and redesigned so no two entries in
	    a pool share a verb (manual, Pillar 4). Notably there is now exactly ONE blocking wall in
	    the whole game (Terra's Bulwark Wall), where v0.1 had several.
	  * Terra's Boulder Shot is a charge-and-release M1 -- the only chargeable M1 in the game.
	    That settles the open question the HUD work left behind: the crosshair charge indicator
	    has a real consumer, so it stays.

	THE v0.7 LOADOUT (the owner's call, 2026-09-24; it replaces the 2026-09-23 Element-fixed slots): M1,
	Primary, Passive AND ULTIMATE come with the Element -- its Ultimate is the Config.Ultimate entry whose
	Origin it is. The other two slots are TWO EQUAL TECHNIQUE SLOTS over ONE pool (Config.Mobility and
	Config.Defense together): any Technique goes in either, never the same one in both, and a Technique
	is still keyed by its ORIGIN Element for colour -- a Cryo running Scorching Lash (with the P31 flag off)
	genuinely should see an orange slot.
	Players never read "Mobility" or "Defense" any more (Config.SlotLabel); the words stay
	only as the internal names of the Q and E slots and of the two halves of the pool. An Element may
	name DEFAULT Techniques (Config.ElementDefaults: Pyro -> Detonate + Scorching Lash), equipped when a
	player becomes it, and a Technique may be kept to its own Element (Exclusive: Detonate, Pyro only).

	ICONS are rendered from blender_scripts/build_icons.py through one shared camera/light rig.
]]

local Config = {}

----------------------------------------------------------------------------------------------------
-- combat baselines (manual, Section 3 + Appendix)
----------------------------------------------------------------------------------------------------
Config.MaxHealth = 150         -- the manual says 100; raised to 150 on request (2026-09-12)
Config.MaxMana = 100
Config.ManaRegenPerSecond = 7
-- The Ultimate charges from damage, taken and dealt alike (manual, Section 3): this share of a full meter per point of
-- health a hit actually removes. SpellshotService counts the taking, CombatCore the dealing.
Config.UltChargePerDamage = 1 / 260
-- Health never regenerates on its own (2026-09-16, on request): only healing abilities heal.
-- SpellshotService also removes Roblox's default Health script, which would.

----------------------------------------------------------------------------------------------------
-- movement (manual, Section 3: "uniform base move speed across all elements")
----------------------------------------------------------------------------------------------------
-- The manual sets the philosophy but no numbers, so the pace is taken from RIVALS, measured off a
-- capture (see MovementController): a run of ~7 eye-heights a second -- ~30 studs/s at our eye
-- height -- and a one-second slide that holds ~1.4x that the whole way, with a slide-jump that keeps
-- it. The slide and slide-jump speeds below are all set as multiples of sprint, so they move with it.
Config.Movement = {
	BaseWalkSpeed = 16,          -- Roblox default; the uniform baseline every Element shares
	SprintSpeed = 22,            -- 2026-10-21 "slow the running even more": 25 -> 22 (25 was asked for 2026-09-12; RIVALS' pace is 30)
	CrouchSpeed = 8,             -- half base; the trade you make for the smaller silhouette
	CrouchHipHeight = 0.9,       -- R15 default is ~2.0, so this genuinely lowers head and hitbox
	CrouchCameraDip = -1.15,     -- Humanoid.CameraOffset, so the default camera follows it

	SlideDuration = 1.6,         -- the LONGEST a slide runs (2026-10-04: up from 1.1; RIVALS' is ~1.0 s). ~53 studs at full length
	SlideSpeed = 35,             -- entry: 1.4x the 25 run (or your current speed, if faster)
	SlideEndSpeed = 28,          -- and still ABOVE the run when it ends: a slide never costs you speed
	SlideHold = 2.5,             -- speed = end + (entry - end) * (1 - t^hold). Over 1 the curve HOLDS the
	                             -- entry speed and gives ground only in the last third. Averages ~33.
	                             -- (2026-09-14, "make the slide faster than running": the 2026-09-12
	                             -- 27 -> 18 at 0.75 averaged ~22, slower than just running.)
	-- (no SlideCooldown any more: the backstop from a slide's start is SlideDuration + SlideRegap, so it follows the duration)
	SlideRegap = 0.1,            -- seconds from a slide's END (key let go, slide-jump, a wall) to the next one's start
	SlideMinSpeed = 12,          -- must actually be moving to slide, not crouch-jump in place
	-- The first-person slide camera, MEASURED off a RIVALS capture (see MovementController):
	SlideTilt = 6.5,             -- degrees of camera roll, held for the whole slide
	SlideTiltRamp = 0.13,        -- seconds to bank in, and again to level out (~4 frames)
	SlideCameraDip = -0.45,      -- Humanoid.CameraOffset during a slide, ON TOP of the hip-height
	                             -- drop; together they put the eye at ~2/3 of standing height
	-- Slide-jump: jumping during a slide ends it in a boosted leap (see MovementController).
	-- FLATTER AND LONGER (asked for 2026-09-12): speed taken out of the vertical and put into the
	-- horizontal. The apex drops 9 -> 6, which is a fifth less upward launch, and the carried speed
	-- rises so the leap covers about a quarter more ground. This is the SLIDE-jump only: it writes
	-- the launch velocity itself and never touches Humanoid.JumpHeight, so an ordinary jump is
	-- exactly what it was.
	-- (2026-10-05, "too much height gain, sacrifice that for some lateral gain": 6.0 -> 4.0, and the speeds below up again)
	SlideJumpHeight = 4.0,       -- studs at the apex, measured from STANDING height (a normal jump: 7.2)
	-- Retuned with the run: the old 41-52 out of a 25 run was too fast to shoot from, which is
	-- what it was reported as. The apex is unchanged, so the arc lasts as long and covers less.
	-- The boost and the clamps are set so jumping EARLY in the slide still carries further than
	-- jumping late (35 + 20 = 55, clamped to 50, against 28 + 20 = 48): the timing is worth something.
	SlideJumpMinSlide = 0.25,    -- seconds of sliding that earn the full leap; jumping sooner gets a share of the boost (none at 0)
	-- (all three up 20% on 2026-10-05, asked for with the lower gravity: "the boost should be more". Were 20 / 40 / 50.)
	-- (and up again the same day with the lower apex: 24 / 48 / 60 -> 32 / 56 / 70)
	-- (down on 2026-10-17, the balance pass: 32 / 56 / 70 -> 22 / 42 / 52. The shared chase chain ran ~59 studs/s, so
	-- whoever chased always caught up. CHANGES_2026-10-17_balance_pass.md has every change of that pass.)
	SlideJumpBoost = 22,         -- studs/s added to the slide's current speed at takeoff...
	SlideJumpMinSpeed = 42,      -- ...never below this (1.68x the run)...
	SlideJumpMaxSpeed = 52,      -- ...and never above this (2.08x the run)
	-- 10, not 1.2 (2026-10-05, "speed should be constant in jumps"): with the lower gravity a slide-jump and a double
	-- jump fly for 1.7 s, and the hold used to run out in mid-air. It now only ends on landing.
	SlideJumpAirHold = 10,       -- the launch speed is HELD while airborne (a long fall: this long)...
	SlideJumpLandBleed = 0.35,   -- ...then eases back to sprint over this long after landing

	-- AIR AND WALLS (2026-09-14: "add wall running, double jump by normal and also if you jump while
	-- wall running, you get a slightly stronger jump"). Every player has these; they are not Techniques.
	-- See MovementController.
	AirJumps = 1,                -- jumps in the air before landing or catching a wall: a double jump
	DoubleJumpHeight = 4.5,      -- studs the air jump rises (a ground jump: 7.2). Was 6.5 until 2026-10-05: less height, see SlideJumpHeight
	WallRunMinSpeed = 16,        -- moving slower than this along a wall, it can't be caught
	WallRunSpeed = 30,           -- speed along the wall: at least this (the run is 25), more if you came in faster
	WallRunTime = 1.4,           -- the longest a single wall run lasts
	WallRunGravity = 0.3,        -- share of gravity while on the wall: you sink slowly
	WallRunLift = 4,             -- upward speed on catching a wall, so a catch mid-fall still reads as a run
	WallRunMaxFall = 10,         -- never sinking faster than this on the wall
	WallRunReach = 2.6,          -- studs from the body's centre to a wall you can catch (the torso is 2 wide)
	WallRunStick = 2,            -- studs/s pressed into the wall, so a seam doesn't knock you off
	WallRunRegrab = 0.45,        -- the wall you just left can't be caught again this soon; the one across can
	WallRunTilt = 10,            -- degrees the camera banks away from the wall
	WallRunTiltRamp = 0.15,      -- seconds to bank in, and again to level out
	WallJumpHeight = 8.6,        -- a jump off a wall run: a little stronger than a ground jump's 7.2
	WallJumpPush = 22,           -- studs/s away from the wall...
	WallJumpKeep = 0.2,          -- ...held this long against air steering, so the kick is felt
	-- Roles that cannot be cast out of a slide. Empty since Frost Slide became a dash rather than a
	-- second slide (the double-distance problem the lock existed for); kept as a table because the
	-- input script still asks it.
	SlideCastLock = {},

	-- MOVEMENT MODE (2026-10-18, movement switch; the owner's decision for team mode: "switch only, keep full, but keep
	-- jumping by default, one jump only"). "Full" is the game as it was: slide, slide-jump, wall run, wall jump, double jump.
	-- "RunningOnly" keeps the run, the crouch and ONE ordinary ground jump and nothing else: the crouch key only crouches,
	-- and there is no slide-jump, wall run, wall jump or air jump. Walk and sprint speeds and every kit's own mobility
	-- (Shadow Step, Skyrider, Bulwark Charge, Cross-Slash, Gust Pad...) are the same in both. A dev switches it LIVE with
	-- the workspace attribute "MovementMode" (the dev panel's MOVEMENT row, through MovementModeServer), because an edit
	-- here from the command bar during Play never reaches the game: clients read that attribute first and this second.
	Mode = "Full",
	-- (2026-10-18, movement switch review) false by default, as the brief asks: RunningOnly hides the touch slide button.
	-- Safe now that hiding it also drops a Toggle Crouch latch (TouchControls -> TouchBus "CrouchClear").
	RunningOnlyTouchCrouch = false,  --[[true until 2026-10-18]] -- RunningOnly on touch: true keeps the SLIDE / CROUCH button as a crouch-only button; false hides it
}

-- (2026-10-19, audit P1-03) THE SERVER'S MOVEMENT GUARD (CombatCore, "movement"). Each player's body moves on its own
-- client, so a modified client could teleport, out-run every legal speed, or walk out of a root. On every Heartbeat the
-- server measures each living player's FLAT (XZ) speed over the last Window seconds -- vertical is never judged (falls,
-- launches) -- against BaseSpeed, or FastSpeed while the body is in a fast state (a Skyrider ride, a knock or pull --
-- KnockedUntil --, a held Technique, or a cast in the last FastAfterCast seconds), and a jump of more than MinStep studs over that
-- speed is counted in ServerStorage.ShotStats ("move_snap") and, while Enforce is on, put back where it last stood.
-- Enforce = false only counts (read move_snap against play before turning it on for real). Server moves of a body open a
-- Grace window (CombatCore.AllowMove), and a body the server holds (CombatCore.HoldBody: roots, the Tomb) is the
-- server's own physics and is not judged. Conservative on purpose: every legal speed sits well under these (sprint 25,
-- slide-jump at most 52, a Skyrider boost ~75, Undertow's pull 125 under its KnockedUntil).
Config.MovementGuard = {
	Enabled = true,
	Enforce = false,        -- (import 2026-10-19) count-only until move_snap has been read against real play; then true
	BaseSpeed = 90,          -- studs/s, flat
	FastSpeed = 170,         -- studs/s, flat, in a fast state
	FastAfterCast = 1.5,     -- seconds after a cast (the character's CastAt, SpellshotService) that still count as fast
	MinStep = 10,            -- studs: a move shorter than this is never judged
	Grace = 1.0,             -- seconds CombatCore.AllowMove leaves a body alone by default
	-- (the two below are the guard's own: the speed is measured over a window, not frame to frame, so replication arriving
	-- in bursts averages out, and a steady speed hack is seen as well as a teleport)
	Window = 0.5,            -- seconds: the speed is taken from where the body stood at least this long ago
	MaxGap = 3,              -- seconds: the longest a position that never changed counts for (standing still, then a jump)
}

----------------------------------------------------------------------------------------------------
-- developer conveniences
----------------------------------------------------------------------------------------------------
-- A dev does not want to farm damage for 40 seconds every time they want to look at the Cryo
-- Beam. FreeUltimate keeps the charge meter pinned at 100%, so R is always castable and never
-- spends anything -- the ability itself runs exactly as it does in a real match, which is the
-- point: this changes the RESOURCE, not the behaviour, so what you are testing is still the
-- shipping ability.
--
-- WHO COUNTS AS A DEV
--   In Studio, whoever is playing. In a live server, only the place's owner (checked against
--   game.CreatorId, so there is no user id to keep in sync here) and only if AllowInLiveGame is
--   turned on. It is off for live by default so a published build cannot hand a player an
--   Ultimate on tap.
Config.Dev = {
	AllowInStudio = true,        -- Studio playtests are always dev
	-- ON so that TEAM TEST works. A Team Test session runs on a real Roblox server, where
	-- RunService:IsStudio() is false, so with this off the dev panel opened and every button it
	-- pressed was dropped on the floor. It still only ever grants the place owner (and anything
	-- listed in UserIds below) -- but turn it off before the game is public.
	AllowInLiveGame = true,
	UserIds = {                  -- extra dev accounts: [123456] = true
		[2800693640] = true,     -- GotYouGang ("Nightmare"), collaborator: dev tools in live and Team Test servers (owner, 2026-09-24)
	},

	-- starting state; every one of these is togglable in-game with the keys below
	FreeUltimate = true,         -- Ultimate always charged, casting never spends it
	FreeMana = false,            -- abilities cost no mana
	NoCooldowns = false,         -- Q/E/F come back instantly

	-- 2026-10-23: Studio Play (RunService:IsStudio()) saves Sparks and owned Elements to a separate TEST DataStore
	-- ("SpellshotPlayerData_StudioTest", PlayerData), so a test never changes a real save. false = Studio reads and
	-- writes the real save again. Live servers and Team Test (not IsStudio) always use the real one.
	StudioTestSave = true,

	Keys = {                     -- hints for the on-screen readout; the binds live in SpellshotInput
		FillUlt = "]",
		ToggleFreeUlt = "`",
		ToggleNoCooldowns = "[",
		ToggleFreeMana = "'",
	},
}

--- Whether player `caster`'s abilities may touch player `victim` (2026-09-16, on request): never anyone in the Hub -- it
--- is not a place for fighting -- and another player only as an opponent in the same duel, so in a Solo Test (the
--- Training Grounds or any map) players cannot hurt each other. Training dummies are not players and take everything.
--- Zone and DuelMatch are replicated player attributes, so this is the same answer on the server (CombatCore.IsFriendly)
--- and on every client (a shot flies through a body it could not hurt: Config.AddUnhurtable).
--- TEAMMATES (2026-10-18, team mode): in the same match, two players with the same "MatchTeam" (DuelMatch sets it, "A" or
--- "B", and clears it with "DuelMatch") may not hurt each other either. So IsFriendly calls a teammate friendly -- no
--- damage, CC, status or reaction -- and CombatCore.IsAllyOf calls them an ally, for Radiant's heals and shields.
function Config.MayHurt(caster, victim)
	if victim:GetAttribute("Zone") == "Hub" then return false end
	if caster == victim then return true end
	local match = caster:GetAttribute("DuelMatch")
	--[[return match ~= nil and match == victim:GetAttribute("DuelMatch") until 2026-10-18 team mode]]
	if match == nil or match ~= victim:GetAttribute("DuelMatch") then return false end
	local team = caster:GetAttribute("MatchTeam")
	return team == nil or team ~= victim:GetAttribute("MatchTeam")
end

--- Appends to `list` the character of every other player `caster` may not hurt, and returns it: a ray or shot filter
--- that passes through them.
function Config.AddUnhurtable(list, caster)
	for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
		if other ~= caster and other.Character and not Config.MayHurt(caster, other) then
			list[#list + 1] = other.Character
		end
	end
	return list
end

--- Whether `player` counts as a dev: in Studio everyone playing (a test can set the player's "DevOff" attribute to try
--- what a regular player gets -- Studio only), in a live server only the place's owner or a UserIds entry, and only
--- while AllowInLiveGame is on. The server's answer is the one that counts: SpellshotService's dev tools and the duel's
--- BACK TO HUB gate both ask this.
function Config.IsDev(player)
	local dev = Config.Dev
	if game:GetService("RunService"):IsStudio() then
		return dev.AllowInStudio ~= false and player:GetAttribute("DevOff") ~= true
	end
	if not dev.AllowInLiveGame then return false end
	if dev.UserIds and dev.UserIds[player.UserId] then return true end
	-- game.CreatorId is the owner for a user-owned place, and the group id for a group place; only the former
	-- identifies a person, so a group place needs an explicit UserIds entry
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

----------------------------------------------------------------------------------------------------
-- the Duel's rounds (Build Prompt #24; DuelMatch runs them)
----------------------------------------------------------------------------------------------------
Config.Duel = {
	FirstTo = 5,             -- round wins that take the match
	RoundEndPause = 2,       -- seconds from a round's result to the next round's wipe
	MatchEndHold = 4,        -- seconds the match's result stays up before both go back to the Hub
	ForfeitHold = 3,         -- the same, when the other duellist left
	SwapFromRound = 3,       -- rounds before this keep round 1's marks; from it, every round flips a coin to swap them
	SwapChance = 0.5,
	StartTimeout = 15,       -- the longest a round waits for both duellists to be rebuilt on their marks
	RoundTime = 90,          -- seconds a round runs before its clock settles it: the larger share of health left takes it
	                         -- (equal shares: a draw). 0 turns the clock off. Added 2026-10-17 (balance pass).
	-- (2026-10-19, audit P3-13) a draw scores nobody, so a match whose rounds kept drawing (two sides that never engage)
	-- never ended, and only a dev may leave one. After this many rounds PLAYED the match ends anyway: more round wins takes
	-- it, equal wins are a draw. 15 leaves room for six draws in a full 5-4; 0 turns the cap off. A team match reads it
	-- here unless Config.Team names its own. PROPOSED: the owner may prefer a sudden-death or damage-dealt tiebreak.
	MaxRounds = 15,
}

----------------------------------------------------------------------------------------------------
-- team matches (2026-10-18, team mode). The owner's call: "Team-comp only: one mode, one ruleset; drop 1v1 Duel as a
-- parallel mode", scoped that day to "3v3s on the duel loop but only in menu, ignore hub". Quick Play's queue fills to
-- two teams of Size and DuelMatch runs them on the duel's loop; the Hub's duel pads still start a 1v1 on Config.Duel.
-- A team match reads a round rule here first and Config.Duel's when this leaves it out (DuelMatch's rule()), so any of
-- Config.Duel's keys (RoundEndPause, MatchEndHold, ForfeitHold, SwapFromRound, SwapChance, StartTimeout) may be added
-- here to give the team match its own. The format is not final: these are the knobs.
----------------------------------------------------------------------------------------------------
Config.Team = {
	Size = 3,                -- players a team; Quick Play's queue starts a match at 2 x Size (1: a 1v1, for a 2-client test)
	FirstTo = 5,             -- round wins that take a team match
	RoundTime = 90,          -- seconds before the clock settles a round: the larger TEAM health share takes it (the sum of
	                         -- its health over the sum of its max health; a player who is down or gone counts 0 of their
	                         -- max); equal shares are a draw. 0 turns the clock off. A round otherwise ends when one team
	                         -- is all down (last team standing); nobody comes back mid-round.
	SpawnSpacing = 6,        -- studs between teammates on their mark, side by side across the line from one mark to the other
	SpawnFloorDrop = 10,     -- how far below its spot a teammate's floor may be; no floor, or a wall between the spot and the
	                         -- mark, puts that teammate on the mark itself
	VoteSeconds = 15,        -- the map vote before a team match (a pad duel's is HubServer's 12)
}

----------------------------------------------------------------------------------------------------
-- matchmaking across servers (2026-10-28, the owner: "it should be matches from all server (preferring same region
-- server but still if not found then any server to server)", with SEPARATE MATCH SERVERS). ServerScriptService.Matchmaker
-- runs it; HubServer hands it every QUEUE while Mode is "Global". Studio: teleports do not work there, so a match whose
-- players are all in the Studio server runs in it; the workspace attribute "MM_SimulateMatchServer" (Studio only, set it
-- true during Play; off by default) makes the Studio server act as a match server for the players present, and its trip
-- home is logged instead of teleported.
----------------------------------------------------------------------------------------------------
Config.Matchmaking = {
	Mode = "Global",         -- "Global": one queue for every server, each match in its own reserved server.
	                         -- "Local": the queue before 2026-10-28, this server's players only (the kill switch)
	WidenAfter = 20,         -- seconds a ticket matches only its own region; after that also anyone who has waited as long
	ArriveTimeout = 45,      -- seconds a match server waits for its players before it starts (or calls the match off)
	MinPerTeam = 2,          -- at ArriveTimeout, a team with fewer here than this (never more than Team.Size) calls it off
	PollEvery = 2.5,         -- seconds between matchmaker turns (only servers with someone queued take part)
	TicketTTL = 120,         -- a ticket its server stops refreshing (the server is gone) expires after this
	RefreshEvery = 20,       -- how often a server refreshes its own players' tickets
	LockTTL = 6,             -- the matchmaker lock's life; whoever holds it renews it every turn
	RecordTTL = 900,         -- a match record's life (15 min)
	Store = "SPELLSHOT_MM_v1", -- MemoryStore and MessagingService names start with this (Studio adds "_Studio")
	DefaultRegion = "OT",    -- the region of a country the table below does not list
	-- the player's country (LocalizationService:GetCountryRegionForPlayerAsync, ISO 3166 codes) to a matchmaking region
	Regions = {
		NA = { "US", "CA", "MX", "PR", "GT", "BZ", "SV", "HN", "NI", "CR", "PA", "CU", "DO", "HT", "JM", "BS", "TT", "BB",
			"BM", "KY", "VI", "GU", "AG", "LC", "VC", "GD", "DM", "KN", "AW", "CW" },
		SA = { "BR", "AR", "CL", "CO", "PE", "VE", "EC", "BO", "PY", "UY", "GY", "SR", "GF", "FK" },
		EU = { "GB", "IE", "FR", "DE", "NL", "BE", "LU", "CH", "AT", "IT", "ES", "PT", "DK", "NO", "SE", "FI", "IS", "PL",
			"CZ", "SK", "HU", "SI", "HR", "BA", "RS", "ME", "MK", "AL", "XK", "GR", "BG", "RO", "MD", "UA", "BY", "LT",
			"LV", "EE", "RU", "TR", "CY", "MT", "AD", "MC", "SM", "VA", "LI", "GI", "FO", "GL", "GE", "AM", "AZ" },
		ME = { "AE", "SA", "QA", "KW", "BH", "OM", "IL", "PS", "JO", "LB", "SY", "IQ", "IR", "YE", "EG", "LY", "TN", "DZ",
			"MA", "SD", "ZA", "NG", "KE", "GH", "ET", "TZ", "UG", "SN", "CI", "CM", "AO", "ZW", "ZM", "MZ", "BW", "NA",
			"MU", "RW", "MG" },
		AS = { "IN", "PK", "BD", "LK", "NP", "BT", "MV", "AF", "JP", "KR", "CN", "TW", "HK", "MO", "MN", "SG", "MY", "TH",
			"VN", "PH", "ID", "KH", "LA", "MM", "BN", "TL", "KZ", "UZ", "KG", "TJ", "TM" },
		OC = { "AU", "NZ", "FJ", "PG", "NC", "PF", "WS", "TO", "VU", "SB" },
	},
}

----------------------------------------------------------------------------------------------------
-- hitboxes (2026-10-17, the owner: "increase the hitbox of the characters by 30% (increase for dummies too so i can
-- test)"). ServerScriptService.HitboxScale gives every body part of every character and dummy an invisible twin.
-- The same day every M1 projectile got ONE speed, 200 studs/s (the owner: charge times may differ, speed should not):
-- VFXLibrary IcicleShard, PyroFX Fireball, ToxinTuning Bubble, AquaTuning Riptide, TerraFX BoulderShot (both charges),
-- ZephyrFX WindBlade, UmbraTuning ShadowDart. Chain Bolt and Light Lance are hitscan and stay so.
----------------------------------------------------------------------------------------------------
Config.Hitbox = {
	Scale = 2.0,             -- each body part's hitbox is this times the part's size in every direction (1 = off).
	                         -- 1.3 at first, 2.0 later the same day (the owner: "i think this would get us around rivals")
	ShowAlpha = 0.6,         -- how see-through the hitboxes draw while workspace's "ShowHitboxes" attribute is true
}

----------------------------------------------------------------------------------------------------
-- palette
----------------------------------------------------------------------------------------------------
-- Base/light pairs match the Blender palettes the icons were rendered with, so a slot's border
-- and its icon are the same hue rather than two nearby blues.
Config.Elements = {
	Pyro = {
		Order = 1, Display = "Pyro", Archetype = "Aggro/DPS",
		Base = Color3.fromRGB(242, 92, 13), Light = Color3.fromRGB(255, 199, 77), Dark = Color3.fromRGB(107, 23, 8),
		M1 = { Name = "Fireball", Desc = "Straight shot, splash on impact" },
		Primary = { Name = "Immolate", Desc = "Buffs your next 3 M1 hits with bonus burn damage" },
		Passive = { Name = "Ember Refund", Desc = "Dropping an enemy under 30% health refunds 30% of Immolate's cooldown", Display = "Proc" },
	},
	Cryo = {
		Order = 2, Display = "Cryo", Archetype = "Control/Zone",
		Base = Color3.fromRGB(64, 181, 240), Light = Color3.fromRGB(222, 247, 255), Dark = Color3.fromRGB(13, 79, 168),
		-- (2026-10-19, audit P3-24 / P6B-11) "3 stacks briefly roots" until then: the third stack is a deep slow since 2026-10-08
		M1 = { Name = "Icicle Shard", Desc = "Fast flat trajectory, low damage, stacks Chill; 3 stacks is a deep slow" },
		Primary = { Name = "Flash Freeze", Desc = "Ground zone: linger past 1s and you are rooted, then shattered if still frozen when it ends" },
		Passive = { Name = "Cold Momentum", Desc = "+10% move speed for 2s after landing any hit", Display = "Timer", Duration = 2,
			SpeedBonus = 0.10 },
	},
	Voltaic = {
		Order = 3, Display = "Voltaic", Archetype = "High-skill snowball",
		Base = Color3.fromRGB(245, 199, 15), Light = Color3.fromRGB(255, 245, 115), Dark = Color3.fromRGB(74, 26, 140),
		M1 = { Name = "Chain Bolt", Desc = "Instant hitscan out to 55 studs, auto-chains to a second enemy" }, -- ("very short range" until 2026-10-18: 30 -> 55; "short range" until 2026-10-19, audit P6B-11)
		Primary = { Name = "Overcharge", Desc = "Instant short dash; your next M1 chains to 2 extra targets" },
		Passive = { Name = "Chain Reaction", Desc = "Filling Charged on an enemy takes 2 s off Overcharge's cooldown", Display = "Proc" },
	},
	Terra = {
		Order = 4, Display = "Terra", Archetype = "Aggressive tank",
		Base = Color3.fromRGB(130, 107, 36), Light = Color3.fromRGB(204, 186, 92), Dark = Color3.fromRGB(51, 33, 13),
		-- the only chargeable M1 in the game; this is what the crosshair charge ring exists for
		M1 = { Name = "Boulder Shot", Desc = "Hold to charge, release early for less damage", Chargeable = true },
		Primary = { Name = "Bulwark Charge", Desc = "Charges forward with damage reduction, knocks down whatever it hits" },
		Passive = { Name = "Bedrock", Desc = "Stacking shield while charging M1 or mid-Bulwark Charge", Display = "Stacks" },
	},
	Zephyr = {
		Order = 5, Display = "Zephyr", Archetype = "Mobility/Flank",
		Base = Color3.fromRGB(79, 209, 197), Light = Color3.fromRGB(255, 255, 255), Dark = Color3.fromRGB(18, 92, 89),
		M1 = { Name = "Wind Blade", Desc = "Very high fire rate, low damage, pierces through a line" },
		Primary = { Name = "Cross-Slash Dash", Desc = "Crosses the arms, dashes at a target with the hands behind, then flings them open to slash an X through it" },
		-- Updraft (the v6 import, 2026-10-06) takes the manual's text: bonus damage and bonus knockback while airborne
		-- (ZephyrUpdraftServer; its numbers are IceMagic.ZephyrUpdraft.Tuning). It was "No fall damage, faster air
		-- control" (v0.3), which nothing ever implemented. Display stays "None": nothing publishes PassiveActive for it yet.
		Passive = { Name = "Updraft", Desc = "Bonus damage and bonus knockback while airborne", Display = "None" },
	},
	-- UMBRA, reworked 2026-09-27 (manual v0.16): Mobility, less kinetic than Zephyr and paid back in damage. Shadow Step
	-- replaces Mark for Death (retired: ServerStorage.UmbraKitSuperseded), which never had a cast path.
	Umbra = {
		Order = 6, Display = "Umbra", Archetype = "Mobility",
		Base = Color3.fromRGB(79, 33, 145), Light = Color3.fromRGB(181, 140, 240), Dark = Color3.fromRGB(13, 8, 23),
		M1 = { Name = "Shadow Dart", Desc = "Slowest fire rate, highest single-shot damage; a true sniper" },
		Primary = { Name = "Shadow Step", Desc = "Dissolve and re-form a short way off, out of sight and out of every lock for a moment" },
		Passive = { Name = "Unseen", Desc = "Shadow Dart hits harder on a target that is not looking at you", Display = "State" },
	},
	Radiant = {
		Order = 7, Display = "Radiant", Archetype = "Support",
		Base = Color3.fromRGB(245, 194, 48), Light = Color3.fromRGB(255, 247, 214), Dark = Color3.fromRGB(112, 82, 10),
		M1 = { Name = "Light Lance", Desc = "Held channel-beam; damage ramps the longer it stays on one target" },
		Primary = { Name = "Blessing", Desc = "Shields an ally or self for a chunk of absorb damage" },
		-- 2026-09-29 (the rework; manual v0.20): Overflow Light replaces Afterglow (retired: ServerStorage.RadiantKitSuperseded)
		Passive = { Name = "Overflow Light", Desc = "A Blessing shield that lasts its whole duration heals whoever had it with what is left", Display = "None" },
	},
	-- TOXIN, reworked 2026-09-30 (manual v0.15 / v0.17): a bubble-into-cloud loop, pure toxic gas. Toxic Bubbles replaces
	-- Spore Burst, and Corrosive Cloud keeps its name but converts your bubble instead of surrounding you (the old text is
	-- retired: ServerStorage.ToxinKitSuperseded). Base / Light / Dark are UI and uniform only -- never an effect's colour.
	Toxin = {
		Order = 8, Display = "Toxin", Archetype = "Control/Zone",
		Base = Color3.fromRGB(128, 212, 33), Light = Color3.fromRGB(204, 245, 112), Dark = Color3.fromRGB(74, 26, 107),
		M1 = { Name = "Toxic Bubbles", Desc = "Lob a bubble of poison: it pops on the first enemy it hits, or rests where it lands for a few seconds" },
		Primary = { Name = "Corrosive Cloud", Desc = "Turns your bubble -- in flight or resting -- into a lingering poison cloud right where it is" },
		Passive = { Name = "Symbiosis", Desc = "Poison you apply heals you slightly; your own poison hurts you less, but still hurts", Display = "None" },
	},
	-- AQUA (manual v0.14, built 2026-09-24): the first post-launch Element, the Season 1 "9th Element" slot. Control/Zone,
	-- with Cryo and Toxin. Its colours are STAND-INS (the water's teal-blue, and the Tideline accent #3CE8E0 as Light).
	Aqua = {
		Order = 9, Display = "Aqua", Archetype = "Control/Zone",
		Base = Color3.fromRGB(38, 140, 176), Light = Color3.fromRGB(60, 232, 224), Dark = Color3.fromRGB(14, 58, 80),
		M1 = { Name = "Riptide", Desc = "A crescent of whitewater surged along the ground; aim it, and jump it" },
		Primary = { Name = "Undertow", Desc = "A vortex in front of you snaps enemies near it to its own centre and interrupts them" },
		Passive = { Name = "Riding the Current", Desc = "Your abilities leave wet ground: faster for you on it, an enemy on it slips", Display = "State" },
	},
}

Config.ElementOrder = { "Pyro", "Cryo", "Voltaic", "Terra", "Zephyr", "Umbra", "Radiant", "Toxin", "Aqua" }

--- Slot order, left to right, as the HUD draws it.
Config.Roles = { "M1", "Primary", "Mobility", "Defense", "Ultimate", "Passive" }

--- The two Technique slots by their INTERNAL names (Q and E by default; the binds are the player's). The names are the
--- old role words and stay, because every script and the collaborators' kits key on them; a player only ever reads
--- SlotLabel (2026-09-24: "don't call them mobility and defence, they aren't terms anymore").
Config.TechniqueSlots = { "Mobility", "Defense" }
Config.SlotLabel = {
	M1 = "M1", Primary = "Primary Ability", Mobility = "Technique 1", Defense = "Technique 2",
	Ultimate = "Ultimate", Passive = "Passive",
}

----------------------------------------------------------------------------------------------------
-- the Technique pool (manual v0.2, Section 2) -- Origin drives the icon colour
----------------------------------------------------------------------------------------------------
-- (2026-10-19, audit P4-14) Since P31 (2026-10-18) each Element holds only the entries whose Origin it is
-- (Config.ElementMayHold, below); "any Element may equip it" in a comment here means with TechniquesOwnElementOnly off.
-- Every entry was checked against the others in its pool for the "distinct verb" rule, so the
-- Desc text below is deliberately the mechanic that makes it different, not flavour.
-- Since v0.7 (2026-09-24) Mobility and Defense are ONE pool split in two halves: an entry from either half goes in
-- either Technique slot (Config.Technique finds it). The half is still its flavour -- a movement Technique or a
-- defensive one -- which the HUD glyph and Earthen Tomb's escape (TerraHandler) read.
-- Exclusive = true: only the Origin Element may equip it (Detonate reads Pyro's own Fireball and Immolate hits).
Config.Mobility = {
	-- Blizzard (2026-09-24) REPLACES Frost Slide. Cooldown is documentation; the row's (CryoTuning) is charged.
	-- (2026-10-19, audit P6B-11) Desc was "where you stand ... for 8 seconds": CryoTuning has CastRange 20 (P29) and Duration 6
	Blizzard        = { Name = "Blizzard",         Origin = "Cryo",    Desc = "A storm at your crosshair, up to 20 studs away: everyone else inside is slowed and can barely see, for 6 seconds", Cooldown = 18 },
	-- Railspike (2026-09-25) REPLACES Chain Lurch, which never had a cast path. Cooldown is documentation; the row's is charged.
	Railspike       = { Name = "Railspike",        Origin = "Voltaic", Desc = "A short windup, then a bolt that pierces everyone in a 90-stud line", Cooldown = 10 },
	-- Aftershock (2026-09-25) REPLACES Tremor Vault: its burrow and its cast path are gone (the TerraVault meshes stay in
	-- the place, unreferenced). A movement Technique by its half of the pool, though what it moves is everyone else.
	-- Cooldown is documentation; the row's (VFXLibrary) is charged.
	Aftershock      = { Name = "Aftershock",       Origin = "Terra",   Desc = "Both fists into the ground: a ring of erupting rock races out and throws back everyone it reaches", Cooldown = 12 },
	-- Skyrider (2026-10-06, the Zephyr v6 import) REPLACES Gust Jump (retired: ServerStorage.ZephyrKitSuperseded.v6_2026_10_06).
	-- HELD like Gust Jump: the press pays and starts the ride, the ride's end starts the cooldown. Cooldown is
	-- documentation; the row's (VFXLibrary) is charged.
	Skyrider        = { Name = "Skyrider",         Origin = "Zephyr",  Desc = "Summon a bird of wind and ride it: fly where you look, flap a gust that throws enemies back; it drains mana until you jump off", Cooldown = 12 },
	-- Mark (2026-09-27) REPLACES Fade Step (retired: ServerStorage.UmbraKitSuperseded). Offense/setup by flavour, in this
	-- half because Fade Step was. Cooldown is documentation; the row's (UmbraTuning) is charged.
	Mark            = { Name = "Mark",             Origin = "Umbra",   Desc = "Mark a target; it ripens over a few seconds. Your own next hit spends it -- a headshot for the most", Cooldown = 14 },
	PositionTrade   = { Name = "Position Trade",   Origin = "Radiant", Desc = "Instantly swap places with any target in range: an ally, an enemy, a dummy", Cooldown = 14 },   -- replaced Lightstep (2026-09-29)
	-- Antitoxin Vent (2026-09-30, manual v0.15/v0.17) REPLACES Overgrowth Vault (retired: ServerStorage.ToxinKitSuperseded).
	-- Self-risk by flavour, in this half because Overgrowth Vault was. Cooldown is documentation; the row's (ToxinTuning) is charged.
	AntitoxinVent   = { Name = "Antitoxin Vent",   Origin = "Toxin",   Desc = "A gas mask: cleanses your own poison at once, then your own poison and clouds cannot touch you while it is on, and every DoT hurts you 30% less", Cooldown = 16 },
	-- Pyro's second (2026-09-23; in the pool since 2026-09-24). Pyro's default, and Pyro's ONLY.
	Detonate        = { Name = "Detonate",         Origin = "Pyro",    Desc = "Marks whoever you last hit with Fireball or Immolate; after a short fuse it explodes, harder the lower their health", Cooldown = 14, Exclusive = true },
}

Config.Defense = {
	-- Deep Freeze (2026-09-24) REPLACES Chill Aura.
	DeepFreeze    = { Name = "Deep Freeze",    Origin = "Cryo",    Desc = "An unseen trap at your feet: whoever sets it off is sealed in a crystal prison, rooted", Cooldown = 16 },
	-- Volt Orb (2026-09-25) REPLACES Static Field, which never had a cast path. Cooldown is documentation; the row's is charged.
	VoltOrb       = { Name = "Volt Orb",       Origin = "Voltaic", Desc = "Lob a crackling orb: it bursts into lightning on contact or when its fuse runs out", Cooldown = 12 },
	BulwarkWall   = { Name = "Bulwark Wall",   Origin = "Terra",   Desc = "The one wall in the game -- full projectile/sightline block", Cooldown = 16 },
	-- Gust Pad (2026-10-06, the Zephyr v6 import) REPLACES Deflect Gust (retired: ServerStorage.ZephyrKitSuperseded.v6_2026_10_06).
	-- Cooldown is documentation; the row's (VFXLibrary) is charged.
	GustPad       = { Name = "Gust Pad",       Origin = "Zephyr",  Desc = "Press a gust pad into the ground at your crosshair: you and any enemy who steps on it are launched straight up -- teammates are spared", Cooldown = 14 },
	-- (2026-10-19, audits P5E-04 / P3-18) the Desc said "friend or foe": since P1-14 a pad launches its caster, enemies and
	-- dummies, never a player the caster may not hurt (a teammate, a Solo Test stranger)
	DecoyDouble   = { Name = "Decoy Double",   Origin = "Umbra",   Desc = "Stationary illusion -- the only misdirection tool in the game", Cooldown = 20 },
	Benediction   = { Name = "Benediction",    Origin = "Radiant", Desc = "Plant your staff: rays heal every ally near you, or you when none are near. You are rooted while it lasts", Cooldown = 17 },   -- replaced Cleansing Ring (2026-09-29)
	-- Acid Rain (2026-09-30, manual v0.15/v0.17) REPLACES Antidote Cloak (retired: ServerStorage.ToxinKitSuperseded).
	-- Offense/setup by flavour, in this half because Antidote Cloak was. Cooldown is documentation; the row's is charged.
	AcidRain      = { Name = "Acid Rain",      Origin = "Toxin",   Desc = "A poison downpour on a spot: a light tick on everyone under it, and stacks that make Toxin's poison hit them harder", Cooldown = 14 },
	-- Pyro's second (2026-09-23; in the pool since 2026-09-24): Pyro's default (any Element could equip it before P31).
	-- Cooldown is documentation; the row's (VFXLibrary, 5 since the 2026-10-17 balance pass) is charged.
	ScorchingLash = { Name = "Scorching Lash", Origin = "Pyro",    Desc = "Hold to carry a burning whip; let go to crack it where you aim, up to 35 studs; each hit stacks a burn (up to 3)", Cooldown = 5 },   --[[2.5 until 2026-10-19, audit P4-14 / P6B-11]]
	-- Aqua's two (2026-09-24): "Aqua-pure" in the manual, so Aqua's ONLY (Exclusive), and Aqua's defaults. Cooldowns are
	-- documentation; the rows' (AquaTuning) are charged.
	TwinTide      = { Name = "Twin Tide",      Origin = "Aqua",    Desc = "Two wave-walls close in on a lane from either side; whoever is caught where they meet is crushed", Cooldown = 16, Exclusive = true },
	Sidearm       = { Name = "Sidearm",        Origin = "Aqua",    Desc = "A water-gun: draw it and fire, or hold to rapid-fire (every bullet costs mana)", Cooldown = 0.9, Exclusive = true },
}

Config.Ultimate = {
	-- (2026-10-27) Heat Rush is gone, and with it the only source of Heat: the Ring is always the one size
	RingOfFire      = { Name = "Ring of Fire",     Origin = "Pyro",    Desc = "Point at the ground: your hand draws a circle of fire there, and a snap erupts it" },
	-- Mirror Cage (2026-09-24) REPLACES Cryo Beam: the only Origin = "Cryo" entry, so it is Cryo's (ElementUltimate).
	MirrorCage      = { Name = "Mirror Cage",      Origin = "Cryo",    Desc = "Locks a target and cages them in a dome of ice panels that volley bolts at them" },
	-- Cascade (2026-09-25) REPLACES Thunderclap, which never had a cast path: the only Origin = "Voltaic" entry, so Voltaic's.
	Cascade         = { Name = "Cascade",          Origin = "Voltaic", Desc = "Mark a spot: a storm gathers overhead, then five bolts strike whoever is still under it" },
	-- Earthen Tomb (2026-09-19) REPLACES Seismic Slam, which never had a cast path. The name is a working name.
	EarthenTomb     = { Name = "Earthen Tomb",     Origin = "Terra",   Desc = "Locks a target; a fissure hunts them down -- jump it, or be raised in a stone fist and crushed" },
	Cyclone         = { Name = "Cyclone",          Origin = "Zephyr",  Desc = "Pulls and juggles into a cluster; sets teammates up" },
	-- Eclipse (2026-09-27, a working name) REPLACES Nightfall (retired: ServerStorage.UmbraKitSuperseded): the only
	-- Origin = "Umbra" entry, so it is Umbra's (ElementUltimate).
	Eclipse         = { Name = "Eclipse",          Origin = "Umbra",   Desc = "The world goes dark: every enemy is unaware, revealed to you through walls, and your darts fly faster" },
	Halo            = { Name = "Halo",             Origin = "Radiant", Desc = "For a few seconds, the damage you deal also heals your team; all of it to you when you are alone" },   -- replaced Radiant Judgment (2026-09-29); working name
	-- Patient Zero (2026-09-30, a working name) REPLACES Bloom (retired: ServerStorage.ToxinKitSuperseded): the only
	-- Origin = "Toxin" entry, so it is Toxin's (ElementUltimate). Variant B: constant radius, scaling damage and duration.
	PatientZero     = { Name = "Patient Zero",     Origin = "Toxin",   Desc = "Mark a target with a growing, quickening aura; it bursts into a poison cloud wherever they are -- worse the more of their allies are near" },
	LeviathansMaw   = { Name = "Leviathan's Maw",  Origin = "Aqua",    Desc = "The flood rises and wave-walls close overhead into a glass tank; a shark circles beneath, then lunges" },
}

----------------------------------------------------------------------------------------------------
-- the v0.7 loadout: the Element's own Ultimate, two Technique slots over one pool (the owner, 2026-09-24)
----------------------------------------------------------------------------------------------------
-- "M1, Passive, Primary and Ult stay locked to the element, those 2 abilities are swappable with other element's."
-- This REPLACES the 2026-09-23 Element-fixed slots (Config.ElementSlots / FixedSlot, which cast Detonate and Scorching
-- Lash whatever the player had picked). Now both are ordinary Techniques in the pool, Pyro EQUIPS them by default
-- (ElementDefaults), and a Pyro may swap either out like any other Technique. Every script reads a slot through
-- VFXLibrary.AbilityFor, and SpellshotService / HubServer change an Element only through ApplyElement below.

local OTHER_SLOT = { Mobility = "Defense", Defense = "Mobility" }

--- The Techniques an Element puts in the slots when a player BECOMES it (a pick in the loadout menu, a Hub shrine, the
--- dev panel, and on joining for the default Element). An Element with no entry leaves the player's Techniques alone.
Config.ElementDefaults = {
	Pyro = { Mobility = "Detonate", Defense = "ScorchingLash" },
	-- the owner, 2026-09-24: Blizzard in the first Technique slot, Deep Freeze in the second
	Cryo = { Mobility = "Blizzard", Defense = "DeepFreeze" },
	Aqua = { Mobility = "TwinTide", Defense = "Sidearm" },
	-- 2026-09-25: becoming Terra equips Terra's own two -- Aftershock (which replaced Tremor Vault) and Bulwark Wall
	Terra = { Mobility = "Aftershock", Defense = "BulwarkWall" },
	-- 2026-09-25: becoming Voltaic equips Voltaic's own two -- Railspike and Volt Orb
	Voltaic = { Mobility = "Railspike", Defense = "VoltOrb" },
	-- 2026-09-27: becoming Umbra equips Umbra's own two -- Mark (which replaced Fade Step) and Decoy Double
	Umbra = { Mobility = "Mark", Defense = "DecoyDouble" },
	-- 2026-09-29: becoming Radiant equips Radiant's own two -- Position Trade (which replaced Lightstep) and Benediction
	-- (which replaced Cleansing Ring)
	Radiant = { Mobility = "PositionTrade", Defense = "Benediction" },
	-- 2026-09-30: becoming Toxin equips Toxin's own two -- Antitoxin Vent (which replaced Overgrowth Vault) and Acid Rain
	-- (which replaced Antidote Cloak)
	Toxin = { Mobility = "AntitoxinVent", Defense = "AcidRain" },
	-- 2026-10-08: becoming Zephyr equips Zephyr's own two -- Skyrider (which replaced Gust Jump) and Gust Pad (which
	-- replaced Deflect Gust). The row was missing, so a Cryo who picked Zephyr kept Blizzard and Deep Freeze
	Zephyr = { Mobility = "Skyrider", Defense = "GustPad" },
}

--- Techniques that left the pool, and what took each one's place (the Zephyr v6 import, 2026-10-06). Loadouts are not
--- saved anywhere (the attributes are set fresh on joining, SpellshotService), so nothing stored can name one; this only
--- catches a stale attribute on its way through TechniquesFor -- an Element change maps it to its successor, where it
--- would otherwise drop to the default. VFXLibrary.AbilityFor resolves a retired key to nothing (no row), so a slot
--- still naming one is simply empty until then.
Config.RetiredTechniques = {
	GustJump = "Skyrider",
	DeflectGust = "GustPad",
	-- (2026-10-27, the owner) Heat Rush and Cinder Shield left the game; Pyro's other two take their slots
	HeatRush = "Detonate",
	CinderShield = "ScorchingLash",
}

--- Technique `key`'s pool entry, and the half of the pool it sits in ("Mobility" / "Defense"); nil for anything else.
function Config.Technique(key)
	if type(key) ~= "string" then return nil end
	if Config.Mobility[key] then return Config.Mobility[key], "Mobility" end
	if Config.Defense[key] then return Config.Defense[key], "Defense" end
	return nil
end

--- Whether a player of `element` may hold Technique `key` at all. Since 2026-10-18 (P31, the owner: Techniques swap
--- within your own Element only, never across) a Technique belongs to its Origin Element alone, so Bulwark Wall, Twin
--- Tide or any other can never leave home. Every loadout path asks this one function: the Loadout menu's rows, the
--- server's LoadoutRequest (MayEquip), the dev panel, TechniquesFor on an Element change, and VFXLibrary.AbilityFor
--- at cast time. TechniquesOwnElementOnly = false puts the shared pool back (every Technique fits every Element,
--- except an Exclusive one, which only its Origin may hold: Detonate, Twin Tide, Sidearm).
Config.TechniquesOwnElementOnly = true
function Config.ElementMayHold(element, key)
	local entry = Config.Technique(key)
	if entry == nil then return false end
	if Config.TechniquesOwnElementOnly then return entry.Origin == element end
	return entry.Exclusive ~= true or entry.Origin == element
end

--- Whether a player of `element` may EQUIP Technique `key` (in either slot): allowed for the Element, and built.
function Config.MayEquip(element, key)
	local entry, half = Config.Technique(key)
	return entry ~= nil and Config.ElementMayHold(element, key) and Config.IsPartBuilt(entry.Origin, half)
end

--- The Element's own Ultimate: the key of the Config.Ultimate entry whose Origin it is (nil when it has none).
function Config.ElementUltimate(element)
	for key, entry in pairs(Config.Ultimate) do
		if entry.Origin == element then return key end
	end
	return nil
end

--- The two Techniques a player holding `mobility` / `defense` ends up with on becoming `element`: the Element's
--- defaults (ElementDefaults) where it names them, else what they hold -- unless that is not allowed for the new
--- Element (Detonate off Pyro) or would put one Technique in both slots, when it goes back to
--- Config.DefaultLoadout's for that slot (the other slot's default, or the first equippable, if that is taken).
function Config.TechniquesFor(element, mobility, defense)
	mobility = Config.RetiredTechniques[mobility] or mobility       -- a retired Technique held: its successor
	defense = Config.RetiredTechniques[defense] or defense
	local defaults = Config.ElementDefaults[element] or {}
	local out = {
		Mobility = defaults.Mobility or mobility or Config.DefaultLoadout.Mobility,
		Defense = defaults.Defense or defense or Config.DefaultLoadout.Defense,
	}
	for _, slot in ipairs(Config.TechniqueSlots) do
		local other = OTHER_SLOT[slot]
		if not defaults[slot] and (not Config.ElementMayHold(element, out[slot]) or out[slot] == out[other]) then
			local candidates = { Config.DefaultLoadout[slot], Config.DefaultLoadout[other] }
			local rest = {}
			for _, half in ipairs(Config.TechniqueSlots) do
				for key in pairs(Config[half]) do rest[#rest + 1] = key end
			end
			table.sort(rest)                   -- pairs() order is not stable
			for _, key in ipairs(rest) do candidates[#candidates + 1] = key end
			out[slot] = nil
			for _, key in ipairs(candidates) do
				if key ~= out[other] and Config.MayEquip(element, key) then
					out[slot] = key
					break
				end
			end
		end
	end
	return out.Mobility, out.Defense
end

--- SERVER: `player` becomes `element` -- the Element, its Techniques (TechniquesFor) and its own Ultimate. The Ultimate
--- attribute is only kept in step for anything still reading it: VFXLibrary.AbilityFor ignores it. Returns the display
--- names of the Techniques that CHANGED, for the caller's message.
function Config.ApplyElement(player, element)
	local held = {
		Mobility = player:GetAttribute("Mobility") or Config.DefaultLoadout.Mobility,
		Defense = player:GetAttribute("Defense") or Config.DefaultLoadout.Defense,
	}
	local mobility, defense = Config.TechniquesFor(element, held.Mobility, held.Defense)
	player:SetAttribute("Element", element)
	player:SetAttribute("Mobility", mobility)
	player:SetAttribute("Defense", defense)
	player:SetAttribute("Ultimate", Config.ElementUltimate(element))
	local changed = {}
	for slot, key in pairs({ Mobility = mobility, Defense = defense }) do
		local entry = Config.Technique(key)
		if key ~= held[slot] and entry then changed[#changed + 1] = entry.Name end
	end
	table.sort(changed)
	return changed
end

----------------------------------------------------------------------------------------------------
-- status effects
----------------------------------------------------------------------------------------------------
-- The manual had no status-effect section when this was written (it has one since v0.13, "Elemental Application";
-- the numbers are ServerScriptService.StatusEffects'), so this vocabulary is derived from the kits themselves: every
-- entry is the readable name of something an existing M1/Primary/Technique already does. (2026-10-19, audit P6B-11)
-- `Element` is the Element that CAUSED it, which drives the tag's colour and icon.
Config.Statuses = {
	Burning   = { Element = "Pyro",    Label = "BURNING",  Source = "Immolate-buffed Fireball / Ring of Fire" },
	Chilled   = { Element = "Cryo",    Label = "CHILLED",  Source = "Icicle Shard / Blizzard slow" },
	Rooted    = { Element = "Cryo",    Label = "ROOTED",   Source = "Flash Freeze linger" },
	Slipping  = { Element = "Cryo",    Label = "SLIPPING", Source = "No current source" },
	-- manual v0.13 (2026-09-24): Voltaic's status is CHARGED (was SHOCKED, which nothing ever applied). Its numbers and
	-- the others' live in ServerScriptService.StatusEffects.
	Charged   = { Element = "Voltaic", Label = "CHARGED",  Source = "Chain Bolt (stacks; discharges at max)" },
	Revealed  = { Element = "Voltaic", Label = "REVEALED", Source = "Static Field" },
	Staggered = { Element = "Terra",   Label = "STAGGERED",Source = "Bulwark Charge knockdown" },
	-- a working name: held on Earthen Tomb's pillar. MOVEMENT only -- the entombed can still attack, and a Technique from
	-- the movement half of the pool breaks it when the server accepts the press (TerraHandler's CCBreak) -- all but
	-- Aftershock, Detonate, Scorching Lash, Blizzard and Railspike, which are no escape (2026-10-19, audit P4-14: this
	-- named only Aftershock). Skyrider and Shadow Step are refused outright while Entombed, before they are paid (their
	-- Prechecks: audits P4-01 / GC-07), so they are no escape either (2026-10-19, audit P4-03)
	Entombed  = { Element = "Terra",   Label = "ENTOMBED", Source = "Earthen Tomb" },
	Airborne  = { Element = "Zephyr",  Label = "AIRBORNE", Source = "Cyclone juggle" },
	Marked    = { Element = "Umbra",   Label = "MARKED",   Source = "Mark" },
	-- Purified (Cleansing Ring's cleanse) retired 2026-09-29 with the Radiant rework: nothing applies it any more
	Blessed   = { Element = "Radiant", Label = "BLESSED",  Source = "Blessing shield", Benign = true },
	Poisoned  = { Element = "Toxin",   Label = "POISONED", Source = "Toxic Bubbles / Corrosive Cloud / Patient Zero" },
	-- Snared's source, Overgrowth Vault's vine, was retired with the Toxin rework (2026-09-30): nothing applies it any more
	Snared    = { Element = "Toxin",   Label = "SNARED",   Source = "No current source" },
}

----------------------------------------------------------------------------------------------------
-- icon lookup (filled in by the uploader; see roblox/IconAssets.lua)
----------------------------------------------------------------------------------------------------
Config.Icons = { Element = {}, Role = {}, HUD = {} }

--- Element logo for a given Element name.
function Config.ElementLogo(element)
	return Config.Icons.Element[element] or ""
end

--- Slot icon for a role, in an Element's palette.
--- M1 deliberately uses the ELEMENT LOGO rather than a role glyph. The role glyph set has five
--- entries (Primary/Mobility/Defense/Ultimate/Passive) and v0.2 added a sixth slot; the manual
--- also says an opponent's M1 is what identifies their Element at a glance, so the Element's own
--- logo is the honest icon for that slot rather than a sixth abstract glyph.
function Config.RoleIcon(role, element)
	if role == "M1" then
		return Config.ElementLogo(element)
	end
	local byRole = Config.Icons.Role[role]
	return byRole and byRole[element] or ""
end

--- Which Element's colours a given slot should use.
--- M1, Primary Ability, Passive and (v0.7, 2026-09-24) Ultimate are Element-locked; the two
--- Technique slots follow the equipped Technique's origin, whichever half of the pool it is from.
function Config.SlotElement(loadout, role)
	if role == "M1" or role == "Primary" or role == "Passive" or role == "Ultimate" then
		return loadout.Element
	end
	local entry = Config.Technique(loadout[role])
	return entry and entry.Origin or loadout.Element
end

function Config.ElementColor(element)
	local e = Config.Elements[element]
	return e and e.Base or Color3.fromRGB(200, 200, 200)
end

--- Display name for whatever is in a slot, for tooltips and the kit readout.
function Config.SlotName(loadout, role)
	local elem = Config.Elements[loadout.Element]
	if role == "M1" then return elem and elem.M1.Name or "" end
	if role == "Primary" then return elem and elem.Primary.Name or "" end
	if role == "Passive" then return elem and elem.Passive.Name or "" end
	if role == "Ultimate" then
		local own = Config.Ultimate[Config.ElementUltimate(loadout.Element) or ""]
		return own and own.Name or ""
	end
	local entry = Config.Technique(loadout[role])
	return entry and entry.Name or ""
end

--- The shipped loadout. This is the finalized Cryo kit, and every entry in it is actually
--- implemented -- which is the reason it is a fixed kit rather than the random Technique draw
--- that stood here before. Drawing at random from the pools now would hand out Techniques with
--- no cast path behind them.
Config.DefaultLoadout = {
	Element = "Cryo",
	Mobility = "Blizzard",
	Defense = "DeepFreeze",
	Ultimate = "MirrorCage",
}

--- WHICH ELEMENTS ARE ACTUALLY BUILT. Cryo and Pyro were the first (wired 2026-09-14); since 2026-09-30 all nine are
--- (the lines below add each as it landed). The loadout menu greys out anything not listed and the server checks this
--- again before it will equip anything, because a player in an unbuilt Element would be holding abilities that do
--- nothing. (2026-10-19, audit P6B-11: this said "the other six ... have no cast path behind them".)
Config.BuiltElements = { Cryo = true, Pyro = true, Zephyr = true, Terra = true, Aqua = true }

-- Voltaic (2026-09-25): selectable -- the whole kit is live (Chain Bolt, Overcharge, Chain Reaction, Railspike, Volt Orb,
-- Cascade). Kill switch: remove this line AND set the Voltaic rows' Implemented (VFXLibrary) to false.
Config.BuiltElements.Voltaic = true

-- Umbra (2026-09-27, the rework): selectable -- the whole kit is live (Shadow Dart, Shadow Step, Unseen, Mark, Decoy Double,
-- Eclipse). Kill switch: remove this line AND set the Umbra rows' Implemented (VFXLibrary) to false.
Config.BuiltElements.Umbra = true

-- Radiant (2026-09-29, the rework): selectable -- the whole kit's MECHANICS are live (Light Lance, Blessing, Overflow Light,
-- Position Trade, Benediction, Halo); its visuals are Phase 3 placeholders (RadiantFX) until Phases 4-5. Kill switch:
-- remove this line AND set the Radiant rows' Implemented (VFXLibrary) to false.
Config.BuiltElements.Radiant = true

-- Toxin (2026-09-30, the rework): selectable -- the whole kit is live (Toxic Bubbles, Corrosive Cloud, Symbiosis, Antitoxin
-- Vent, Acid Rain, Patient Zero). Kill switch: remove this line AND set the Toxin rows' Implemented (VFXLibrary) to false.
Config.BuiltElements.Toxin = true

function Config.IsBuilt(element)
	return Config.BuiltElements[element] == true
end

--- An Element that is selectable but only PARTLY built: the kit parts listed are live, and anything else of that
--- Element's -- its missing M1/Primary/Passive, and its Techniques in the three pools -- stays locked. Zephyr
--- (2026-09-15): Wind Blade, and Cross-Slash Dash since 2026-09-16; Deflect Gust (Defense) since later that day, whose
--- parry so far only has the training range's thrower to catch; Gust Jump (Mobility) since 2026-09-17, and Cyclone
--- (Ultimate) since later that day. THE v6 IMPORT (2026-10-06): Skyrider and Gust Pad replace Gust Jump and Deflect Gust,
--- and Updraft (the Passive) unlocks -- bonus damage and knockback while airborne (ZephyrUpdraftServer). The whole kit.
Config.PartialKits = {
	Zephyr = { M1 = true, Primary = true, Passive = true, Defense = true, Mobility = true, Ultimate = true },
	-- Terra (2026-09-17): Boulder Shot first, the game's one chargeable M1, then Bulwark Charge and Bedrock; Earthen
	-- Tomb (Ultimate, 2026-09-19, replacing the never-wired Seismic Slam); Bulwark Wall (Defense) and Tremor Vault
	-- (Mobility), 2026-09-19, Tremor Vault replaced by Aftershock on 2026-09-25. The whole kit.
	Terra = { M1 = true, Primary = true, Passive = true, Defense = true, Mobility = true, Ultimate = true },
	-- Voltaic (2026-09-25): the whole kit, all at once (the import and the build landed the same day)
	Voltaic = { M1 = true, Primary = true, Passive = true, Defense = true, Mobility = true, Ultimate = true },
}

--- Whether one part of an Element's kit is live. `part` is a role: "M1", "Primary", "Passive", or the pool a
--- Technique of that Element sits in ("Mobility" / "Defense" / "Ultimate").
function Config.IsPartBuilt(element, part)
	if not Config.IsBuilt(element) then return false end
	local partial = Config.PartialKits[element]
	return partial == nil or partial[part] == true
end

--- Whether a Technique is built: it is in the pool for that slot -- for either Technique slot, the whole Technique
--- pool (v0.7, 2026-09-24) -- and its origin Element has built its half of the pool. Whether a given ELEMENT may equip
--- it (Detonate is Pyro's only) is MayEquip.
function Config.IsTechniqueBuilt(role, key)
	if role == "Ultimate" then
		local entry = Config.Ultimate[key]
		return entry ~= nil and Config.IsPartBuilt(entry.Origin, role)
	end
	if role ~= "Mobility" and role ~= "Defense" then return false end
	local entry, half = Config.Technique(key)
	return entry ~= nil and Config.IsPartBuilt(entry.Origin, half)
end

local function randomKey(pool, rng)
	local keys = {}
	for k in pairs(pool) do keys[#keys + 1] = k end
	table.sort(keys)                       -- pairs() order is not stable; sort so the pick is seeded
	return keys[rng:NextInteger(1, #keys)]
end

--- A loadout with the given Element and one randomly drawn Technique per pool. Kept for the
--- Convergence "all-loadouts-random" modifier (manual, Section 4) and for pool testing; nothing
--- in normal play calls it, because most of what it can draw is not built yet.
function Config.RandomLoadout(element, seed)
	local rng = Random.new(seed or (os.clock() * 1e6) % 2 ^ 31)
	return {
		Element = element or "Cryo",
		Mobility = randomKey(Config.Mobility, rng),
		Defense = randomKey(Config.Defense, rng),
		Ultimate = randomKey(Config.Ultimate, rng),
	}
end

return Config
