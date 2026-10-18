--[[
	ZephyrFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ZephyrFX

	The Zephyr kit's shared front door for its M1, Primary and Ultimate: ZephyrFX.Tuning (shared with ZephyrHandler, the
	server, which reads every gameplay number in it) and the public functions ZephyrHandler, SpellshotInput and AbilityFX
	call -- FireWindBlade, CrossSlash / CrossSlashLaunch / CrossSlashCancel / CrossSlashFrame / CrossSlashTiming /
	CrossSlashTime / CrossSlashTimingOf / CrossSlashClock, Cyclone / CycloneSteer / CycloneFormLeft / CycloneActive /
	CycloneEnd / CycloneLoopClock, and CyclonePullVelocity (the one rule a body caught by a Cyclone follows, on its own
	client or, for a dummy, on the server).

	THE v6 IMPORT (2026-10-06; vfx_blocking/zephyr/aqua_v6/ROBLOX_IMPORT_PLAN.md). The owner's call: the v6 GLOW look
	replaces the toon-ink look outright. What is DRAWN moved out of this module; what is PLAYED did not:
	  WIND BLADE       ZephyrFX_WindBlade   the lens sliver, core thread and teal rim, accent arcs, spiral wake, vapor trail,
	                                        ripple and impact rings, floor scratches, the cut line, the release puff
	  CROSS-SLASH DASH ZephyrFX_CrossSlash  the charge spiral, takeoff vapor ring, wrist ribbons, vapor tunnel, the X (core
	                                        and sleeve, no big rings), afterimage, scuff, the lobed vapor dome
	  CYCLONE          ZephyrFX_Cyclone     the bulging funnel of thick blade ribbons over a dim core, glare, flares, base
	                                        disc, ground ring, the juggle pulses, debris, and your own edge glare
	Each is drawn on IceMagic.ZephyrDraw (a fork of RadiantDraw: pooled textured Beams, soft aqua PointLights, the NOT
	NEON palette -- core #EFFFFB, light #9CE6DF, main #4FD1C5, edge #2FB5A8, shadow #1F6F6A, deep #125C59, glint
	#FFF3C4: a white-hot core inside a teal sleeve, never neon lime, never a blown-out blob). The functions here keep
	their signatures, return values and every side effect that is not drawing -- the Wind Blade's sweep and its onHit,
	the Cross-Slash clocks, the Cyclone clocks and CyclonePullVelocity -- and hand the drawing to their piece module.
	Every piece module also has Demo(character, opts) for the test harness (StarterPlayerScripts.ZephyrTestHarness).

	RETIRED with the import: DEFLECT GUST (Defense) and GUST JUMP (Mobility) -- their sections, Tuning.Deflect and
	Tuning.GustJump are gone from here. SKYRIDER and GUST PAD replace them and UPDRAFT (the Passive) gets its gameplay;
	those three are modules of their own (ZephyrSkyrider, ZephyrGustPad, ZephyrUpdraft), merged for the client by
	IceMagic.ZephyrClient and served by their own Scripts. The toon assets this module placed (the ink kit's meshes, its
	data and placer, the mesh caches) and the pre-import module itself were removed from the place on 2026-10-09; their
	scripts and an asset-id manifest are kept on disk (D:/_spellshot_cleanup_2026-10-08/studio_zephyr_old).

	Client-side drawing is never required on the server: the piece modules are looked up lazily, and every call into
	them is guarded, so a missing or failing look never stops a blade, a dash or a Cyclone from working.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ZephyrFX = {}

ZephyrFX.Tuning = {
	-- M1, Wind Blade: THE SHOT. ZephyrHandler (the server) reads Speed, Range, Pierce, Damage and HitSlack; the casting
	-- clients read Trigger. Since the v6 import (2026-10-06) the blade itself -- its flight, its sweep and its look -- is
	-- IceMagic.ZephyrFX_WindBlade, which reads these from here; its LOOK's numbers are that module's own Tuning (the toon
	-- kit's draw / wipe / stretch / impact / flash / swirl / ink numbers went with the toon look).
	WindBlade = {
		Speed = 200,           -- studs/s (one speed for every M1 projectile since 2026-10-17; was 240)
		Range = 80,            -- studs: where it wipes if it has not been stopped
		Pierce = 3,            -- characters one blade can pass through and hurt
		Damage = 3,            -- per character (server)
		Trigger = 0.06,        -- the slash's release, s (both animation layers)
		Merge = 0.08,          -- hand -> shot line, s
		-- and your OWN blade's trail: it runs from the blade back toward your camera, so its near end was the biggest thing
		-- on screen while the crescent flew small under the crosshair. Everybody else still sees it, side-on, where it reads
		-- (v6: the vapor wake and the spiral wake)
		OwnTrail = true,       -- 2026-10-08: your own blade keeps its vapor and spiral wakes, as the kit draws it
		OwnFarScale = 3.2,     -- 2026-10-09: 1.0 -> 3.2 (FOV 90 vs the kit's 70, and fights at 30-80 studs, not the kit's 12) -- your own blade's size once it is well away ...
		OwnShrinkFrom = 6,     -- ... starting this far out (studs) ...   (10 -> 6, 2026-10-09)
		OwnShrinkOver = 24,    -- ... over this much further              (18 -> 24, 2026-10-09)
		-- 2026-10-09, YOUR OWN VIEW (the blade flies down your eye line): the crescent's sweep is turned toward the
		-- screen (OwnSweepMix of the flight direction, the rest across the view; 1 = the kit's, edge-on to you), it stays
		-- solid to OwnFadeFrom studs and is gone by OwnFadeTo (everyone else's: the kit's 26 -> 70), and its vapor wake
		-- starts OwnWakeFrom studs out at OwnWakeTail of the tail width, so it no longer buries the blade
		OwnSweepMix = 0.2,
		OwnHitNear = 15, OwnHitScaleMax = 3, OwnCutTau = 1.5,   -- your own hits: x(distance / 15) up to x3, the cut fades 1.5x slower
		OwnFadeFrom = 55, OwnFadeTo = 95,
		OwnWakeFrom = 6, OwnWakeTail = 0.5,
		HitSlack = 1.5,        -- server: how far off the line a reported hit may sit (studs)
		-- THE BLADE'S WIDTH (2026-09-17, the hit-registration fix). The crescent is drawn wide and, over its first
		-- Merge seconds, from the HAND -- but what decided the hit was a HAIRLINE ray down the exact crosshair, so a
		-- blade seen sweeping through a body took nothing and nothing was even reported: no ShotStats row moved, which
		-- is why two passes over the server's checks found nothing to fix. Bodies are now caught by a SPHERE of this
		-- radius swept down the same line; walls still stop the blade on the hairline, so it never dies on a doorframe.
		-- Keep HitRadius UNDER HitSlack: the contact reported sits at most HitRadius off the line, and the server
		-- refuses anything past HitSlack (rej_offline).
		HitRadius = 1.1,       -- studs (ASSUMED): half the blade's working width against a body
	},
	-- (DEFENSE, Deflect Gust's Tuning.Deflect was here until 2026-10-06; Gust Pad replaced it -- ZephyrGustPad.Tuning.)
	-- PRIMARY, Cross-Slash Dash (2026-09-16): the approved choreography (blender_scripts/zephyr/primary_blocking.py,
	-- primary_vfx.py). Seconds are cast time (the LOOK's clock, below); every gameplay number is a stand-in.
	-- HOLD TO CHARGE (2026-09-17, the owner's call): the key down starts the charge, the key up launches the dash, and the
	-- time the key was held sets the distance. The approved clock is kept for a tap; a longer hold holds it on HoldPose
	-- until the release, and the glide part of it (ChargeTime to ChargeTime + DashTime) is stretched over however long the
	-- charged glide lasts (CrossSlashTime, below), so every beat after it -- the X, the Trigger -- keeps its place relative
	-- to the end of the glide. The hold and aim numbers marked ASSUMED are the build's guesses, not decided.
	CrossSlash = {
		ChargeTime = 0.30,     -- forearms cross; the shortest charge: a tap launches here (both animation layers)
		HoldPose = 0.28,       -- ASSUMED: the look's clock holds here while the key is held (the arms' SlashGather key)
		FullChargeTime = 1.0,  -- ASSUMED: the key held this long charges the full distance (the brief's "ChargeTime 1.0")
		MaxHold = 1.5,         -- ASSUMED: held this long, the dash launches by itself
		MinDistance = 12,      -- ASSUMED: studs at no charge (a slow shortens it, as it does Frost Slide's) ...
		MaxDistance = 40,      -- ASSUMED: ... and at full charge, in a straight line along the aim
		ChargeMoveShare = 0.40, -- ASSUMED: while charging the body moves at this share of its run speed (no sprint, no slide)
		AimReach = 400,        -- ASSUMED: studs the crosshair ray looks for the aimed point (nothing: its far end)
		MaxPath = 6,           -- ASSUMED: characters the glide can report (the X's own MaxTargets are counted apart)
		DashDistance = 55,     -- the glide's pace: DashDistance studs ... (ASSUMED: 22 until 2026-09-17, when the owner
		                       -- asked for a "very quicker" dash: 2.5 times the pace, a full 40 studs in 0.36 s)
		DashTime = 0.50,       -- ... in DashTime: 110 studs/s, whatever the distance (the look's glide is DashTime long).
		                       -- Only the pace: every glide time is its distance over this (SpellshotInput, AbilityFX,
		                       -- ZephyrHandler), and the look's glide beats stretch over it
		DashMaxTime = 0.70,    -- the push is gone DashMaxTime - DashTime after the glide should have ended, whatever else happens
		DashMinCap = 16, --[[12 until the 2026-10-17 balance pass]]       -- slowed under this: no dash (and so no cast); under it while charging, the charge is dropped
		LockRange = 30,        -- unused since 2026-09-17: the dash locks no target now (it passes through characters)
		LockRadius = 4.5,      -- unused since 2026-09-17 (as LockRange)
		StopShort = 3.5,       -- the X's stamp, this far ahead of the body as the glide ends (ZephyrFX_CrossSlash reads it;
		                       -- it no longer shortens the dash)
		Trigger = 0.92,        -- the X leaves the crossed hands and stamps: the strike (both layers)
		Reach = 8,             -- the strike, from the caster's root: this far ahead ...
		HalfWidth = 4,         -- ... this far either side ...
		HalfHeight = 4.5,      -- ... and this far up and down (the glide's corridor is as wide and tall)
		Damage = 30,           -- per character (server)
		MaxTargets = 4,        -- characters the X can report
		-- THE LOOK's numbers are ZephyrFX_CrossSlash.Tuning since the v6 import (2026-10-06): the toon look's that stood
		-- here -- the load, braid and X fling, the polish pass's ring, swirl, streaks, impact frame, flash and debris, the
		-- after-X trim's switches -- went with the toon look (ServerStorage.ZephyrKitSuperseded.v6_2026_10_06 keeps it).
		-- One number of theirs stays, because it was never only the look's:
		RecordEnd = 1.40,      -- the look's clock (s) at which a cast's record is let go, so CrossSlashTimingOf /
		                       -- CrossSlashClock answer for exactly as long as before: where the toon look ended (its X
		                       -- wiped from 1.15 over 0.20, + 0.05). The v6 look itself plays on past it (its dome, scuffs)
	},
	-- (MOBILITY, Gust Jump's Tuning.GustJump was here until 2026-10-06; Skyrider replaced it -- ZephyrSkyrider.Tuning.)
}

----------------------------------------------------------------------------------------------------
-- client helpers
----------------------------------------------------------------------------------------------------
local warned = {}
local VFXLibrary = nil
local SpellshotSettings = nil

local function lib()
	if not VFXLibrary then
		VFXLibrary = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("VFXLibrary"))
	end
	return VFXLibrary
end

--- The settings store, or false when the place does not have it (never waits, as the Cross-Slash's Reduce Flashing
--- read never did).
local function settings()
	if SpellshotSettings == nil then
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = folder and folder:FindFirstChild("SpellshotSettings")
		SpellshotSettings = m and require(m) or false
	end
	return SpellshotSettings
end

local function timeScale()
	return lib().ShotTimeScale()
end

local function fxFolder()
	local name = lib().Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function smooth(u)
	return u * u * (3 - 2 * u)
end

----------------------------------------------------------------------------------------------------
-- M1: WIND BLADE
----------------------------------------------------------------------------------------------------
-- THE v6 IMPORT (2026-10-06): the blade lives in IceMagic.ZephyrFX_WindBlade -- its flight down the crosshair, the hit
-- sweep and onHit (moved there verbatim: the sphere of HitRadius for bodies, the hairline for the world, Pierce bodies,
-- the report before anything cosmetic, the WB_ probe counts), the own-view rules, and its v6 glow look on ZephyrDraw
-- (blender_scripts/zephyr/aqua/wind_blade_v6.py: the lens sliver, core thread and teal rim, accent arcs, the vapor and
-- spiral wakes, ripple and impact rings, floor scratches, the cut line, the hand swirl and release puff, one shared
-- aqua light). The two functions below keep their signatures and hand straight over. Tuning.WindBlade stays above:
-- ZephyrHandler (the server) reads its gameplay numbers, and the piece module reads them from there too. The toon kit
-- it replaced (ZephyrWindBladeVFX_Kit placed through InkStroke from ZephyrInkData, its ink-speck and shard emitter
-- rigs, the hand flash) is no longer drawn from anywhere.
local windBladeModule = nil

--- IceMagic.ZephyrFX_WindBlade, or nil while the place does not have it (never cached as missing, so a module still
--- replicating at the first click is picked up by the next one). `quiet` skips the warning (the warm-up below).
local function windBlade(quiet)
	if windBladeModule then return windBladeModule end
	local folder = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = folder and folder:FindFirstChild("ZephyrFX_WindBlade")
	if not m then
		if not quiet and not warned.WindBladeModule then
			warned.WindBladeModule = true
			warn("[ZephyrFX] IceMagic.ZephyrFX_WindBlade is not in the place - the Wind Blade neither flies nor hits")
		end
		return nil
	end
	local ok, mod = pcall(require, m)
	if ok and type(mod) == "table" then
		windBladeModule = mod
		return mod
	end
	if not warned.WindBladeLoad then
		warned.WindBladeLoad = true
		warn("[ZephyrFX] IceMagic.ZephyrFX_WindBlade failed to load: " .. tostring(mod))
	end
	return nil
end

--- THE PRE-FIRE SWIRL at a casting hand (ZephyrFX_WindBlade.WindBladeSwirl). Called at the press -- one line at the
--- slash's start in whatever drives the cast -- it winds into the palm over the press-to-release lead and hands over to
--- that hand's blade; a release with no swirl ahead of it plays one just after instead (the old SwirlGap rule), so it
--- never doubles up.
function ZephyrFX.WindBladeSwirl(position, side, stroke, dir)
	local m = windBlade()
	if m then return m.WindBladeSwirl(position, side, stroke, dir) end
end

--- `origin` along `dir` is the shot itself; `visualFrom`, when given, is where the blade is SEEN to leave (the
--- slashing hand in first person): it starts there and eases onto the true line over Merge. `onHit(result)`, when
--- given, is called for every character the blade passes through and for what finally stops it: that makes it this
--- client's own shot, reported to the server. `side` is the slashing hand ("L" / "R") and `stroke` its direction
--- ("Down" / "Up"). Flown, swept and drawn by ZephyrFX_WindBlade.FireWindBlade.
function ZephyrFX.FireWindBlade(origin, dir, exclude, visualFrom, onHit, side, stroke)
	local m = windBlade()
	if m then return m.FireWindBlade(origin, dir, exclude, visualFrom, onHit, side, stroke) end
end

-- Warmed up on the client as this loads: ZephyrFX used to build the blade's body registry (every Humanoid's model, for
-- the wide sweep) at require, and the piece module builds it at ITS require -- so the first blade of a session does not
-- pay for that workspace scan.
if RunService:IsClient() then
	task.defer(windBlade, true)
end
-- (The toon pool helpers that lived here -- pools / release, capped by Tuning.WindBlade.PoolMax, and pop -- went with
-- the toon looks of all three sections, 2026-10-06.)

----------------------------------------------------------------------------------------------------
-- PRIMARY: CROSS-SLASH DASH
----------------------------------------------------------------------------------------------------
-- THE LOOK is v6 since 2026-10-06 (the owner's call: the glow look replaces the toon-ink look outright), and it is
-- IceMagic.ZephyrFX_CrossSlash's: blender_scripts/zephyr/aqua/cross_slash_v6.py (on v5, v4 and the spring build's
-- timeline) ported onto ZephyrDraw -- the charge spiral winding into the crossed hands and the dust pulled from the feet,
-- the takeoff vapor rings, the wrist ribbons through the snap, the vapor tunnel and the dash ribbons, THE X (two cuts, a
-- white-hot core in a teal sleeve, a flash, one small vapor ring: no big rings), the afterimage, the floor scuffs, the
-- lobed vapor dome, dust and chips, one aqua light; and in your own view the FOV punch and the radial dash streaks. Its
-- numbers are ZephyrFX_CrossSlash.Tuning, and its header maps the kit's seconds onto this section's clock: the launch is
-- the kit's takeoff, the end of the glide its arrival, the Trigger its X.
--
-- WHAT STAYS HERE is everything that is not drawing, unchanged:
--   CrossSlashFrame     the cast's frame (SpellshotInput's hit boxes and ZephyrHandler's checks both build it)
--   CrossSlashTiming /  the cast's clock, shared by the look, the body clip (CastPose) and the first-person arms
--   CrossSlashTime      (Viewmodel)
--   THE CAST RECORD     one per character, behind CrossSlash / CrossSlashLaunch / CrossSlashCancel / CrossSlashTimingOf /
--                       CrossSlashClock. It lives exactly as long as the toon look's did -- the body gone, a charge nobody
--                       launched or dropped MaxHold + 2 s after its press, or its clock past Tuning RecordEnd -- and
--                       answers the same whether or not the look could be drawn
-- Each call hands the look its part through crossSlashDraw: on a client only, the module required on first use and every
-- call guarded, so a look that is missing or fails never touches the cast.
local slashes = {}            -- the cast records: { Character, Dir (nil until the launch), Timing, Target }
local crossSlashLook = nil    -- IceMagic.ZephyrFX_CrossSlash: nil = not looked for yet, false = not in the place / failed
local crossSlashWarned = {}

--- Calls the v6 look's `name`(...) on a client, guarded: required on first use (never on the server, never at require),
--- one warning if it is missing or a call fails, and nothing else -- the cast plays undrawn.
local function crossSlashDraw(name, ...)
	if not RunService:IsClient() then return end
	if crossSlashLook == nil then
		local folder = ReplicatedStorage:FindFirstChild("IceMagic")
		local m = folder and folder:FindFirstChild("ZephyrFX_CrossSlash")
		if not m then
			if not crossSlashWarned.missing then
				crossSlashWarned.missing = true
				warn("[ZephyrFX] IceMagic.ZephyrFX_CrossSlash is not in the place - the Cross-Slash dashes and hits, undrawn")
			end
			return
		end
		local ok, mod = pcall(require, m)
		crossSlashLook = (ok and type(mod) == "table") and mod or false
		if not crossSlashLook then
			warn("[ZephyrFX] ZephyrFX_CrossSlash failed to load - the Cross-Slash is undrawn: " .. tostring(mod))
		end
	end
	local fn = crossSlashLook and crossSlashLook[name]
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok and not crossSlashWarned[name] then
		crossSlashWarned[name] = true
		warn("[ZephyrFX] ZephyrFX_CrossSlash." .. name .. " failed: " .. tostring(err))
	end
end

-- Warmed up on the client as this loads (2026-10-08), as the Wind Blade is above: the look and the engine it draws on
-- (ZephyrDraw) used to be required by the FIRST press of a session, inside the key's own handler -- in Studio 60-90 ms of
-- compile alone -- so that frame ran long, the key coming up was seen a frame late, and the hold SpellshotInput measures
-- from the press (28 studs of charge a second) sent the first dash a couple of studs further than every later tap.
-- Looked for quietly: a module that is not here yet is required by the first press, as before.
if RunService:IsClient() then
	task.defer(function()
		local folder = ReplicatedStorage:FindFirstChild("IceMagic")
		if not (folder and folder:FindFirstChild("ZephyrFX_CrossSlash")) then return end
		crossSlashDraw("Warm")                 -- requires the look; it has no Warm, so nothing is called
		local engine = folder:FindFirstChild("ZephyrDraw")
		if engine then pcall(require, engine) end
	end)
end

--- The Cross-Slash's frame at `pos`, looking along `dir` (a 3D unit vector): its RightVector is level whenever it can
--- be, and a dash straight up or down takes world Z as its up. The caster's hit boxes (SpellshotInput) and the server's
--- checks (ZephyrHandler) both build it here, so they agree at any pitch.
function ZephyrFX.CrossSlashFrame(pos, dir)
	local up = (math.abs(dir.Y) > 0.99) and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	return CFrame.lookAt(pos, pos + dir, up)
end

--- A cast's clock, shared by the look, the body clip (CastPose) and the first-person arms (Viewmodel): Start is the
--- os.clock() of the press; LaunchAt (the look's seconds from the press to the launch) and Glide (the look's seconds the
--- charged glide lasts) are filled in when they are known -- by the caster on the release, by everybody else from the
--- launch broadcast. `late` puts the press that many seconds in the past.
function ZephyrFX.CrossSlashTiming(late)
	return { Start = os.clock() - math.max(0, late or 0), LaunchAt = nil, Glide = nil }
end

--- The look's time for `timing` now (`now`: os.clock(), optional). While the key is held (no LaunchAt) it runs up to
--- HoldPose and holds there. After the release it catches up to ChargeTime by the launch -- a tap, launched at
--- ChargeTime, never held, so its clock is the approved one exactly -- and from the launch it runs the look's glide
--- (ChargeTime to ChargeTime + DashTime) over the charged glide's Glide seconds, and everything after the glide at the
--- normal rate.
function ZephyrFX.CrossSlashTime(timing, now)
	local S = ZephyrFX.Tuning.CrossSlash
	local r = ((now or os.clock()) - timing.Start) * timeScale()
	local launchAt = timing.LaunchAt
	if not launchAt then return math.min(r, S.HoldPose) end
	if r < launchAt then
		if r <= S.HoldPose then return r end
		return math.max(S.HoldPose, r - math.max(0, launchAt - S.ChargeTime))   -- held, then the last of the charge
	end
	local g = r - launchAt
	local glide = (timing.Glide and timing.Glide > 0) and timing.Glide or S.DashTime
	if g < glide then return S.ChargeTime + g * S.DashTime / glide end
	return S.ChargeTime + S.DashTime + (g - glide)
end

--- `character`'s cast record and its index, or nil. A record past its end is let go on the way, at the toon look's own
--- ends, unchanged (it checked them every frame; they are checked here whenever a record is asked for): the body gone, a
--- charge nobody launched or dropped (a lost broadcast) well after the longest hold, or the clock past RecordEnd.
local function slashOf(character)
	local S = ZephyrFX.Tuning.CrossSlash
	local now = os.clock()
	for i = #slashes, 1, -1 do
		local sl = slashes[i]
		local c = sl.Character
		local root = c and c.Parent and c:FindFirstChild("HumanoidRootPart")
		local stale = sl.Timing.LaunchAt == nil and now - sl.Timing.Start > S.MaxHold + 2
		if not root or stale or ZephyrFX.CrossSlashTime(sl.Timing, now) > S.RecordEnd then
			table.remove(slashes, i)
		elseif c == character then
			return sl, i
		end
	end
	return nil
end

--- Plays a Cross-Slash on `character`: its cast record, and its look (ZephyrFX_CrossSlash.Play). opts: Timing (the
--- cast's clock, CrossSlashTiming; without one the cast is a tap already launched, the approved fixed clock), Target (a
--- character model to stamp the X on, or nil -- nothing sends one since the dash stopped locking targets), Late (seconds
--- this cast is already under way, for a broadcast heard a round trip late; only used when no Timing is given). `dir` is
--- the dash's direction in 3D, or nil while the key is still held: CrossSlashLaunch gives it on the launch, and until
--- then the look faces the way the body faces.
function ZephyrFX.CrossSlash(character, dir, opts)
	opts = opts or {}
	if not character then return end
	if dir ~= nil then
		if typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3 then return end
		dir = dir.Unit
	end
	local timing = opts.Timing
	if not timing then
		timing = ZephyrFX.CrossSlashTiming(opts.Late)
		timing.LaunchAt, timing.Glide = ZephyrFX.Tuning.CrossSlash.ChargeTime, ZephyrFX.Tuning.CrossSlash.DashTime
		dir = dir or Vector3.new(0, 0, -1)
	end
	-- one per character: a new cast replaces the last (the look module ends that character's last look itself)
	for i = #slashes, 1, -1 do
		if slashes[i].Character == character then table.remove(slashes, i) end
	end
	local target = (typeof(opts.Target) == "Instance" and opts.Target:IsA("Model")) and opts.Target or nil
	slashes[#slashes + 1] = { Character = character, Dir = dir, Timing = timing, Target = target }
	crossSlashDraw("Play", character, dir, timing, { Target = target })
end

--- The launch of `character`'s held Cross-Slash: from here its look runs along `dir` (3D). The cast's Timing has had its
--- LaunchAt and Glide filled in by the caller. False when no cast is running for that character.
function ZephyrFX.CrossSlashLaunch(character, dir)
	local sl = slashOf(character)
	if not (sl and typeof(dir) == "Vector3" and dir.Magnitude > 1e-3) then return false end
	sl.Dir = dir.Unit
	crossSlashDraw("Launch", character, sl.Dir)
	return true
end

--- A held Cross-Slash dropped before its launch (died, rooted, moved between zones, let go of by the server): its record
--- and its look end at once. A launched one is left to finish.
function ZephyrFX.CrossSlashCancel(character)
	local sl, i = slashOf(character)
	if sl and not sl.Dir then
		table.remove(slashes, i)
		crossSlashDraw("Cancel", character)
	end
end

--- `character`'s running Cross-Slash clock, or nil.
function ZephyrFX.CrossSlashTimingOf(character)
	local sl = slashOf(character)
	return sl and sl.Timing or nil
end

--- A clock for the body clip and the arms (CastPose.PlayClocked, Viewmodel.Play): the look's time of the Cross-Slash
--- `character` is running now. It keeps its own hold on that cast's Timing, so it runs on after the look has ended.
function ZephyrFX.CrossSlashClock(character)
	local timing = ZephyrFX.CrossSlashTimingOf(character)
	if not timing then return nil end
	return function() return ZephyrFX.CrossSlashTime(timing) end
end

----------------------------------------------------------------------------------------------------
-- DEFENSE: DEFLECT GUST and MOBILITY: GUST JUMP -- retired 2026-10-06 (the v6 import)
----------------------------------------------------------------------------------------------------
-- Deflect Gust's parry mark (DeflectParry, DeflectSwing, DeflectTrail) and Gust Jump's look (GustJump, GustJumpHover,
-- GustJumpHoverEnd, GustJumpLand), with their toon helpers and mesh caches, were here. Gust Pad and Skyrider replace them:
-- IceMagic.ZephyrGustPad and IceMagic.ZephyrSkyrider (+ ZephyrFX_Skyrider) draw those, reached through ZephyrClient, not
-- this module. The pre-import module is ServerStorage.ZephyrKitSuperseded.v6_2026_10_06.ZephyrFX_toon_2026_10_06.

----------------------------------------------------------------------------------------------------
-- ULTIMATE: CYCLONE (2026-09-17; the look is v6 since 2026-10-06)
----------------------------------------------------------------------------------------------------
-- THE PLAY is unchanged and stays here: Tuning.Cyclone (the cast, the steering, the catch, the pull -- ZephyrHandler,
-- SpellshotInput and AbilityFX read it), CyclonePullVelocity (the one rule a caught body follows, on its own client or, for
-- an unanchored dummy, the server), CycloneLoopClock (the circling arms' clock) and this client's copy of each cast's clock
-- (CycloneFormLeft: the caster's steering stops on it). Every number is a stand-in.
--   FORM      from the cast (the server's broadcast) for FormTime, following its caster's crosshair (SteerSpeed at most, as
--             the server allows; everybody else's copy eases after the spots at SteerEase)
--   ACTIVE    from touchdown (CycloneActive, where the server fixed it) for ActiveTime, pulling and juggling
--   END       CycloneEnd: unwinding (the look only: nothing is caught or hurt in it), or gone at once
-- THE LOOK is IceMagic.ZephyrFX_Cyclone (the v6 tornado: blender_scripts/zephyr/aqua/cyclone_v6.py on the spring build's
-- clock), which replaced the toon Cyclone kit (InkStroke meshes; retired to ServerStorage.ZephyrKitSuperseded.v6_2026_10_06).
-- Cyclone / CycloneSteer / CycloneActive / CycloneEnd keep their signatures, keep the clock below and hand the drawing to it,
-- guarded: a look that is missing or fails never touches the cast. Its own numbers are ZephyrFX_Cyclone.Tuning.
ZephyrFX.Tuning.Cyclone = {
	-- the cast (server, ZephyrHandler). All ASSUMED (2026-09-17): the manual says "pulls and juggles into a cluster; sets
	-- teammates up", the owner "a tornado at the aimed point" that "you can move until it's forming"
	RangeSlack = 8,        -- studs past the ability's Range (its VFXLibrary row) a spot is still taken: the server's copy trails
	FormTime = 1.2,        -- s: the tornado forms, following the crosshair
	FormMoveShare = 0.5,   -- the caster's speed cap while it forms, as a share of the base walk (sprinting included)
	ActiveTime = 4,        -- s: standing where it formed, pulling and hurting (the unwind after it is the look's alone:
	                       -- ZephyrFX_Cyclone.Tuning.ReleaseTime -- the toon's UnwindTime 0.5 went with the toon look)
	SteerInterval = 1 / 15, -- the caster's client sends its spot this often ...
	SteerRate = 30,        -- ... the server takes at most this many a second (a bucket of 3) ...
	SteerSpeed = 60,       -- ... and moves the tornado no faster than this along the ground (studs/s) ...
	SteerSlack = 3,        -- ... plus this much for jitter, counting at most SteerWindow seconds since the last spot taken
	SteerWindow = 0.25,
	LockLead = 0.08,       -- the caster stops steering this long before touchdown, and sends its last spot
	SteerEase = 18,        -- everybody else's copy eases to the spots it hears at this rate (1/s)
	HeardWait = 0.6,       -- the key's arms wait this long (or two round trips) for the server's broadcast
	-- what it catches (server): a standing cylinder on the ground spot
	Radius = 26,           -- studs round the axis (16 -> 26, 2026-09-17: "increase tornado's pull range") ...
	DummyReturn = 2,       -- s after a lifted training dummy is let go before it is put back on its spot (ZephyrHandler)
	HoldSlack = 5,         -- ... and this much further for someone already caught (the orbit swings them about;
	                       -- 3 -> 5, kept in step with the wider orbit). ZephyrHandler reads both and nothing
	                       -- else: the catch cylinder is Radius, 26, or Radius + HoldSlack, 31, for a body in it
	Height = 26,           -- studs above the ground spot (a root higher than this is not caught) ...
	Below = 3,             -- ... and below it
	PullInterval = 0.1,    -- s between catch checks
	PullSend = 0.2,        -- a caught player is told again this often ...
	PullHold = 0.45,       -- ... and their client keeps pulling this long after each message (one lost message is no gap)
	TickInterval = 0.5,    -- s between damage ticks ...
	Damage = 6,            -- ... this much each (48 over the 4 s for someone held throughout)
	FirstTick = 0.25,      -- s after touchdown, the first tick
	StatusTime = 0.8,      -- the AIRBORNE tag, refreshed on every tick that lands
	-- the pull (CyclonePullVelocity, below)
	EyeRadius = 3,         -- a body is drawn in to this far from the axis, not onto it
	PullGain = 2.5,        -- inward speed per stud outside the eye (1/s) ...
	PullSpeed = 22,        -- ... never more than this (studs/s; the run is 25)
	OrbitSpeed = 14,       -- studs/s round the axis, anticlockwise seen from above (the logo's way)
	LiftTime = 0.6,        -- s to rise to the juggle height after being caught
	JuggleHeight = 9,      -- studs the feet are held over the ground spot ...
	JuggleBob = 2.5,       -- ... bobbing this far up and down ...
	JugglePeriod = 1.1,    -- ... this often (s)
	RootLift = 3,          -- the root's height over the feet (HipHeight 2 plus half the root; not measured)
	LiftGain = 4,          -- vertical speed per stud off the height (1/s) ...
	LiftSpeed = 30,        -- ... up to this rising ...
	MaxFall = 20,          -- ... and this falling
	ForcePerMass = 4000,   -- the mover's force on each axis, per unit of mass (DashMotor's)
	ReleaseSpeed = 20,     -- a body let go keeps at most this speed: dropped, not flung
	-- the broadcasts' catch-up (client: AbilityFX and the look)
	LateMax = 0.5,         -- a broadcast heard late is caught up by at most this (s)
	-- (the toon look's numbers -- Scale, the floor / dust / funnel draw times, the spins, the touchdown pop, the debris,
	-- Lost, WarmMeshes -- went with the toon look on 2026-10-06; the v6 look's are ZephyrFX_Cyclone.Tuning)
}

--- The velocity a body caught by a Cyclone is driven at: drawn in toward the eye, carried round the axis, and lifted to the
--- juggle height, bobbing. `held` is how long it has been caught (s), `seed` staggers the bob between bodies. Shared: a
--- caught player's own client applies it to its body, the server to an unanchored dummy.
function ZephyrFX.CyclonePullVelocity(position, center, held, seed)
	local C = ZephyrFX.Tuning.Cyclone
	local rel = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local d = rel.Magnitude
	local out = d > 1e-3 and rel / d or Vector3.xAxis
	-- anticlockwise seen from above (+Y toward the viewer): +X turns toward -Z
	local around = Vector3.new(out.Z, 0, -out.X)
	local inward = -out * math.clamp((d - C.EyeRadius) * C.PullGain, -C.PullSpeed, C.PullSpeed)
	local lift = math.clamp(held / C.LiftTime, 0, 1)
	local height = C.JuggleHeight * lift
		+ C.JuggleBob * lift * math.sin((held + (seed or 0)) * 2 * math.pi / C.JugglePeriod)
	local vy = math.clamp((center.Y + height - (position.Y - C.RootLift)) * C.LiftGain, -C.MaxFall, C.LiftSpeed)
	return inward + around * (C.OrbitSpeed * math.clamp(d / C.EyeRadius, 0, 1)) + Vector3.new(0, vy, 0)
end

--- A clip clock that plays a clip's lead-in once and then loops [from, from + length) for as long as the clip is held
--- (the Cyclone's circling arms: Viewmodel.Play and CastPose.PlayClocked take it). `start` is the os.clock() the clip
--- began at, `late` how far into the cast that already was.
function ZephyrFX.CycloneLoopClock(start, from, length, late)
	local t0 = start - (late or 0)
	return function()
		local t = os.clock() - t0
		if t < from or not length or length <= 0 then return t end
		return from + (t - from) % length
	end
end

-- THIS CLIENT'S CLOCK OF EACH CAST: the cast's Start (minus Late), the touchdown it heard (ActiveAt) and the end (EndAt)
-- -- exactly what the toon look kept for CycloneFormLeft, without the look. Weak keys: a character that is gone takes its
-- entry with it.
local cyclones = setmetatable({}, { __mode = "k" })    -- [character] = { Start, ActiveAt, EndAt }
local cycloneLook = nil       -- IceMagic.ZephyrFX_Cyclone: nil = not looked for yet, false = not in the place / failed
local cycloneWarned = {}

--- Calls the v6 look's `name`(...) on a client, guarded: required on first use (never on the server, never at require),
--- one warning if it is missing or a call fails, and nothing else -- the cast plays undrawn.
local function cycloneDraw(name, ...)
	if not RunService:IsClient() then return end
	if cycloneLook == nil then
		local folder = ReplicatedStorage:FindFirstChild("IceMagic")
		local m = folder and folder:FindFirstChild("ZephyrFX_Cyclone")
		if not m then
			if not cycloneWarned.missing then
				cycloneWarned.missing = true
				warn("[ZephyrFX] IceMagic.ZephyrFX_Cyclone is not in the place - the Cyclone pulls and hurts, undrawn")
			end
			return
		end
		local ok, mod = pcall(require, m)
		cycloneLook = (ok and type(mod) == "table") and mod or false
		if not cycloneLook then warn("[ZephyrFX] ZephyrFX_Cyclone failed to load - the Cyclone is undrawn: " .. tostring(mod)) end
	end
	local fn = cycloneLook and cycloneLook[name]
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok and not cycloneWarned[name] then
		cycloneWarned[name] = true
		warn("[ZephyrFX] ZephyrFX_Cyclone." .. name .. " failed: " .. tostring(err))
	end
end

--- A Cyclone for `character`, from its cast: forming at `center`. opts: Late (seconds the cast is already under way), Own
--- (the caster's own copy: its steering is taken as it comes, not eased). A new cast replaces the last one.
function ZephyrFX.Cyclone(character, center, opts)
	opts = opts or {}
	if not character or typeof(center) ~= "Vector3" then return end
	local C = ZephyrFX.Tuning.Cyclone
	cyclones[character] = { Start = os.clock() - math.clamp(opts.Late or 0, 0, C.LateMax) }
	cycloneDraw("Cyclone", character, center, opts)
end

--- Where `character`'s forming Cyclone is being steered to (the caster's own crosshair, or a spot the server passed on).
--- Ignored once it has touched down (the look's copy follows it; the server keeps its own).
function ZephyrFX.CycloneSteer(character, center)
	local cy = character and cyclones[character]
	if cy and not cy.ActiveAt and not cy.EndAt and typeof(center) == "Vector3" then
		cycloneDraw("CycloneSteer", character, center)
	end
end

--- Seconds of forming left on this client's copy of `character`'s Cyclone (0 once its time is up), or nil when there is
--- none forming -- the caster's steering asks it.
function ZephyrFX.CycloneFormLeft(character)
	local cy = character and cyclones[character]
	if not cy or cy.ActiveAt or cy.EndAt then return nil end
	return math.max(0, ZephyrFX.Tuning.Cyclone.FormTime - (os.clock() - cy.Start))
end

--- Touchdown, where the server fixed it (`late`: how long ago). A Cyclone this client missed the cast of starts here,
--- formed.
function ZephyrFX.CycloneActive(character, center, late)
	if not character or typeof(center) ~= "Vector3" then return end
	local C = ZephyrFX.Tuning.Cyclone
	late = math.clamp(late or 0, 0, C.LateMax)
	local cy = cyclones[character]
	if not cy or cy.EndAt then
		cy = { Start = os.clock() - C.FormTime - late }
		cyclones[character] = cy
	end
	cy.ActiveAt = os.clock() - late
	cycloneDraw("CycloneActive", character, center, late)
end

--- The end: `instant` takes it away now (a new cast, leaving the arena, a round reset); otherwise it unwinds (the look's
--- release: nothing is caught or hurt in it).
function ZephyrFX.CycloneEnd(character, instant)
	local cy = character and cyclones[character]
	if cy then
		if instant then
			cyclones[character] = nil
		elseif not cy.EndAt then
			cy.EndAt = os.clock()
		end
	end
	cycloneDraw("CycloneEnd", character, instant)
end

-- (Gust Jump's mesh warm-up -- the hidden clones in workspace.ZephyrMeshCache -- went with Gust Jump on 2026-10-06; the
-- folder is retired to ServerStorage.ZephyrKitSuperseded.v6_2026_10_06.)

return ZephyrFX
