--[[
	SpellshotInput  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/SpellshotInput

	The only ability-input script. It replaces the ice prototype's AbilityInputController, which
	bound the kit to the digit row 1-4; a SPELLSHOT loadout is Role-shaped, so the binds are
	Role-shaped too:

	  LMB   M1               Icicle Shard -- one shot per click; the arms take turns
	  F     Primary Ability  Flash Freeze
	  Q     Mobility         Frost Slide (or whichever Technique is equipped -- Skyrider's ride: ZephyrClient.TryCast)
	  E     Defense          Chill Aura (or whichever Technique is equipped -- Gust Pad's press: the generic path)
	  R     Ultimate         Cryo Beam (Cyclone: pointed, and steered with the crosshair while it forms -- see tryCyclone)

	WHY F FOR THE PRIMARY ABILITY
	  v0.2 split M1 from the Primary Ability, so the Ability slot needed a key of its own. Q/E/R
	  were already the three Techniques, and the manual's mobile layout gives the Primary Ability
	  "a dedicated button" next to the M1 -- F is the PC equivalent of that, adjacent to the
	  movement keys rather than buried in the digit row.

	M1: ICICLE SHARD
	  Bound to LMB. One click, one shot: holding the button does NOT repeat. Shots are capped at one
	  per FireInterval, and a click that lands early is held over rather than dropped, so fast
	  tapping gives a steady rate. The arms take turns, one palm thrust per shot, and the shard leaves that hand at
	  full extension. The shard's look is still a PLACEHOLDER, but its hit is real: what the rod you
	  see stops on is reported to the server, which checks the claim and applies the damage and the
	  Chill (AbilityHandler).

	AIMING: first person, so the aim ray is taken from the centre of the viewport, i.e. straight
	down the camera's forward vector. There is no third-person shoulder offset to compensate for.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local Viewmodel = require(iceFolder:WaitForChild("Viewmodel"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Settings = require(spellFolder:WaitForChild("SpellshotSettings"))
local castRemote = spellFolder:WaitForChild("CastRequest")
local DashMotor = require(spellFolder:WaitForChild("DashMotor"))
local PyroFX = require(iceFolder:WaitForChild("PyroFX"))
-- Cryo's FROST LOTUS skin (2026-10-15; FrostLotusKit), found lazily: its M1 is the hold-and-pluck
local frostLotusModule = nil
local function frostLotus()
	if frostLotusModule == nil then
		local m = iceFolder:FindFirstChild("FrostLotusKit")
		local ok, mod = pcall(function() return m and require(m) end)
		frostLotusModule = (ok and mod) or false
	end
	return frostLotusModule or nil
end
local ZephyrFX = require(iceFolder:WaitForChild("ZephyrFX"))
local TerraFX = require(iceFolder:WaitForChild("TerraFX"))
-- Aqua (2026-09-24): its client half -- the Riptide click, the arms on its keypresses, Sidearm's shot on the release
local AquaClient = require(iceFolder:WaitForChild("AquaClient"))
-- Voltaic (2026-09-25): its client half. Guarded: a missing or broken module must not take input down for everyone
local VoltaicClient = nil
do
	local m = iceFolder:WaitForChild("VoltaicClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod then VoltaicClient = mod elseif m then warn("[SpellshotInput] VoltaicClient: " .. tostring(mod)) end
end
-- Umbra (2026-09-27): its client half, guarded the same way
local UmbraClient = nil
do
	local m = iceFolder:WaitForChild("UmbraClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod then UmbraClient = mod elseif m then warn("[SpellshotInput] UmbraClient: " .. tostring(mod)) end
end
-- Radiant (2026-09-29): its client half, guarded the same way
local RadiantClient = nil
do
	local m = iceFolder:WaitForChild("RadiantClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod then RadiantClient = mod elseif m then warn("[SpellshotInput] RadiantClient: " .. tostring(mod)) end
end
-- Toxin (2026-09-30): its client half, guarded the same way
local ToxinClient = nil
do
	local m = iceFolder:WaitForChild("ToxinClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod then ToxinClient = mod elseif m then warn("[SpellshotInput] ToxinClient: " .. tostring(mod)) end
end
-- Zephyr (2026-10-06, the v6 import): the client half of Skyrider, Gust Pad and Updraft, guarded the same way
local ZephyrClient = nil
do
	local m = iceFolder:WaitForChild("ZephyrClient", 10)
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and mod then ZephyrClient = mod elseif m then warn("[SpellshotInput] ZephyrClient: " .. tostring(mod)) end
end
local iceRemote = iceFolder:WaitForChild("IceAbilityRemote")

VFXLibrary.Preload()

-- The binds come from the settings, so rebinding a key in the menu takes effect on the next
-- keypress with nothing to restart. Keyed by KeyCode, rebuilt whole on a change rather than edited,
-- which is also what makes two roles sharing a key impossible to leave behind.
local BINDS = {}
local ROLES = { "Primary", "Mobility", "Defense", "Ultimate" }
-- A touch button's press arrives with one of these in place of a KeyCode (TouchControls through TouchBus, 2026-10-04):
-- strings, so no real key can ever match one, and nothing a rebind does can take them away.
local TOUCH_ROLES = { TouchPrimary = "Primary", TouchMobility = "Mobility", TouchDefense = "Defense", TouchUltimate = "Ultimate" }

local function rebuildBinds()
	table.clear(BINDS)
	for _, role in ipairs(ROLES) do
		local key = Settings.KeyCode("Bind_" .. role)
		if key then BINDS[key] = role end
		local pad = Settings.KeyCode("Pad_" .. role)
		if pad then BINDS[pad] = role end
	end
end

for _, role in ipairs(ROLES) do
	Settings.Bind("Bind_" .. role, rebuildBinds)
	Settings.Bind("Pad_" .. role, rebuildBinds)
end

----------------------------------------------------------------------------------------------------
-- HUD feedback
----------------------------------------------------------------------------------------------------
local function slotFrame(role)
	local hud = playerGui:FindFirstChild("SpellshotHUD")
	local cluster = hud and hud:FindFirstChild("AbilityCluster")
	return cluster and cluster:FindFirstChild(role)
end

local function flash(role, denied)
	local frame = slotFrame(role)
	local st = frame and frame:FindFirstChildOfClass("UIStroke")
	if not st then return end
	local original = st.Color
	st.Color = denied and Color3.fromRGB(226, 76, 76) or Color3.new(1, 1, 1)
	st.Thickness = 4
	task.delay(0.16, function()
		if st.Parent then
			st.Color = original
			st.Thickness = 3
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- aiming
----------------------------------------------------------------------------------------------------
--- The frame a shot is aimed from. In first person this IS `camera.CFrame` -- the same value this
--- code read before there was a second camera to choose from -- so first-person aiming is unchanged.
--- In the third-person testing view (FirstPersonController, V) the camera is a dozen studs behind
--- you, and firing from there would move every shot's origin with it, past the distance from your
--- Head that the server will accept. LocalAimCFrame hands back the first-person frame instead, so
--- the shot still leaves your eye. Only the POSITION differs between the two -- the rotation, and so
--- the look direction, is the camera's either way.
local function aimCF()
	local fn = VFXLibrary.LocalAimCFrame
	return (fn and fn()) or camera.CFrame
end

local function aimPoint(range)
	-- the crosshair is dead centre of the screen, which is exactly the camera's look direction -- taken
	-- from the camera itself rather than from ViewportSize, which can misreport in Studio. (In the
	-- third-person testing view the two part company: the direction is still the camera's, the origin
	-- stays at the eye. See aimCF.)
	local acf = aimCF()
	local ray = Ray.new(acf.Position, acf.LookVector)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if player.Character then table.insert(exclude, player.Character) end
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then table.insert(exclude, fx) end
	table.insert(exclude, camera)     -- nothing should be parented to the Camera, but cheap
	-- the crosshair only picks out what this player could hurt (Config.MayHurt): shots, the Cryo Beam and the Ring of
	-- Fire all pass through anyone else, so the point they aim at must too
	Config.AddUnhurtable(exclude, player)
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return hit and hit.Position or (ray.Origin + ray.Direction * (range or 60))
end

----------------------------------------------------------------------------------------------------
-- casting
----------------------------------------------------------------------------------------------------
local function canCast(role, character)
	if not character then return false end
	if role == "Ultimate" then
		return (character:GetAttribute("UltCharge") or 0) >= 1
	end
	-- CD_ is published in SERVER time: os.clock() is a different number on every machine, and only
	-- agreed with the server's in Studio, where both run in one process
	-- AN ESCAPE CHARGE (2026-10-18, umbra): a slot whose row has EscapeCooldown (Umbra's Shadow Step) still goes while its
	-- own cooldown runs, if the escape's (CDEscape_<role>, server time) is ready. The server picks which charge it was
	-- (SpellshotService); this only must not refuse the press. A touch button arrives here the same way as the key.
	if workspace:GetServerTimeNow() < (character:GetAttribute("CD_" .. role) or 0) then
		local row = VFXLibrary.AbilityFor(player, role)
		local esc = row and row.EscapeCooldown
		if not (type(esc) == "number" and esc > 0
			and workspace:GetServerTimeNow() >= (character:GetAttribute("CDEscape_" .. role) or 0)) then
			return false
		end
	end
	--[[if workspace:GetServerTimeNow() < (character:GetAttribute("CD_" .. role) or 0) then return false end   until 2026-10-18]]
	-- Undertow's interrupt (Aqua, 2026-09-24): no casting until it is over
	if workspace:GetServerTimeNow() < (character:GetAttribute("InterruptedUntil") or 0) then return false end
	local ability = VFXLibrary.AbilityFor(player, role)
	-- DETONATE (Pyro's Mobility, 2026-09-23) needs a target: whoever this Pyro last hit with Fireball or Immolate, as
	-- the server publishes it on the caster (DetonateUntil, in server time; nil or past means none). Without one the
	-- key does nothing at all -- no flick, no request. The server's own precheck (PyroHandler) is still the authority,
	-- and since review r1 (2026-09-24) DetonateUntil says exactly what it says, the RANGE included: the server withdraws
	-- it (nil) while the target is beyond Range, so this sees the range too, a replication late.
	if ability and ability.Id == "Detonate"
		and (character:GetAttribute("DetonateUntil") or 0) <= workspace:GetServerTimeNow() then
		return false
	end
	local cost = ability and ability.ManaCost or 0
	return (character:GetAttribute("Mana") or 0) >= cost
end

--- Roles listed in Config.Movement.SlideCastLock are held back while sliding. Nothing is on it today,
--- on purpose: sliding into a Flash Freeze is exactly the kind of movement-plus-ability play the kit
--- should reward, and Frost Slide -- a dash now, not a second slide stacked on the first -- cancels
--- the slide and takes over (MovementController).
local function blockedByMovement(role, character)
	if character:GetAttribute("MoveState") ~= "Slide" then return false end
	local lock = Config.Movement.SlideCastLock
	return lock ~= nil and lock[role] == true
end

local ultChanneling = false

--- The Ultimate's channel, published on the character so other scripts can see it -- SettingsRuntime
--- uses it for the While Channeling sensitivity. An attribute rather than a global because the
--- character is what the state belongs to.
local function setChanneling(v)
	ultChanneling = v
	local character = player.Character
	if character then character:SetAttribute("Channeling", v or nil) end
end

----------------------------------------------------------------------------------------------------
-- charges: Frost Slide's dash
----------------------------------------------------------------------------------------------------
-- An ability with Charges (Frost Slide, today) is gated on its own. The server holds a small stock
-- (Charges_<role>) and the dash is movement this client runs at once (DashMotor), so the gate has to
-- count the dashes the server has not answered yet: two presses inside one round trip would
-- otherwise both read the same stock and the same mana, and dash on a charge that is already gone.
-- Every dash request carries a Seq; the server publishes the last one it answered, accepted or
-- refused (CastSeq_<role>, carried across a respawn), and every Seq this client has sent past that
-- is still in flight and counts against both the stock and the mana.
-- PER ROLE since 2026-09-23 (when Scorching Lash was a second Charges ability; it is HELD since round 2, 2026-09-24,
-- but the per-role counting stays right for any two Charges Techniques in Q and E): the server settles CastSeq_ per
-- role (SpellshotService settleSeq), and one counter shared by every role left each dash on one role counting as "in
-- flight" on the other until that role's next cast, so the other slot under-counted its stock and its mana.
local dashSeq = {}                  -- [role] = numbers every charge request this client sends in that role
local lastDashClock = {}            -- [role] = os.clock() of that role's last charge cast, for its ChargeGap lockout
local seedRng = Random.new()

--- The stock, the ChargeGap and the mana of a Charges ability, counting this client's requests still in flight.
local function chargeStockAllowed(role, character, ability)
	local inFlight = math.max(0, (dashSeq[role] or 0) - (character:GetAttribute("CastSeq_" .. role) or 0))
	if not character:GetAttribute("DevNoCooldowns") then
		local charges = (character:GetAttribute("Charges_" .. role) or ability.Charges) - inFlight
		if charges < 1 then return false end
	end
	-- the ChargeGap on this client's own clock: the server's lockout has not replicated back yet
	if os.clock() < (lastDashClock[role] or -math.huge) + (ability.ChargeGap or 0) then return false end
	if not character:GetAttribute("DevFreeMana") then
		-- the 2 is the server's own grace, for M1 mana spends that have not replicated here yet
		local cost = ability.ManaCost or 0
		if (character:GetAttribute("Mana") or 0) - inFlight * cost < cost - 2 then return false end
	end
	return true
end

local function chargeCastAllowed(role, character, ability)
	if not DashMotor.CanStart(character) then return false end
	return chargeStockAllowed(role, character, ability)
end

--- A charge request is going out in `role`: its Seq, and that role's ChargeGap starts on this client's clock.
local function nextChargeSeq(role)
	dashSeq[role] = (dashSeq[role] or 0) + 1
	lastDashClock[role] = os.clock()
	return dashSeq[role]
end

local function tryChargeCast(role, character, ability)
	if not chargeCastAllowed(role, character, ability) then
		flash(role, true)
		return
	end
	-- The request goes on the frame the dash actually starts, carrying where it started and which way
	-- it went, because that is where the server lays the patch. Your own dash lines are drawn here and
	-- now; everyone else draws them from the server's broadcast (AbilityFX). The slot flash and the arms
	-- wait for that frame too: a dash dropped in the frame between (frozen that instant) shows nothing.
	DashMotor.Request(function(startPos, dir, dist)
		flash(role, false)
		Viewmodel.Play(ability.Id)
		castRemote:FireServer(role, { Seq = nextChargeSeq(role), Start = startPos, Dir = dir, Dist = dist })
		VFXLibrary.FrostSlideDashFX(character, startPos, dir, dist, seedRng:NextInteger(1, 2 ^ 30))
	end)
end

-- The server refused a cast this client let through (a charge or mana it had not counted yet). The
-- dash itself has already happened -- movement is the client's -- but nothing was spent and no patch
-- is laid, so the slot says so.
castRemote.OnClientEvent:Connect(function(action, role)
	if action == "Denied" and type(role) == "string" then flash(role, true) end
end)

----------------------------------------------------------------------------------------------------
-- Pyro: held casts, and the pointed ring
----------------------------------------------------------------------------------------------------
-- What a cast does on THIS client the moment the key goes down, for abilities that need more than their
-- viewmodel clip (the default is Viewmodel.Play(ability.Id)).
-- Cryo Beam's keypress waits this long for the server's CryoBeamWindup before it takes the arms back down:
-- a cast the server turns away sends none. cryoPress numbers the keypresses, cryoHeard is the last one a
-- Windup answered (the listener at the bottom).
local CRYO_WINDUP_WAIT = 0.6
local cryoPress, cryoHeard = 0, 0
-- Mirror Cage (2026-09-24) the same way: the server turns a press with nobody to lock away in silence and spends nothing
-- (ChargeOnCatch), so the press waits for its "MirrorCage" broadcast (the listener at the bottom); none, and the slot flashes.
local CAGE_HEARD_WAIT = 0.6
local cagePress, cageHeard = 0, 0

-- DETONATE and SCORCHING LASH (2026-09-23) are arm SHOTS, and a shot does not hold the M1 off the way a two-arm clip
-- does (Viewmodel.IsPlaying): each holds it off itself, for its clip's length from the press -- the Lash's from the
-- release, its crack, since round 2 (PyroFX.Tuning.<Id>.M1Lock,
-- slowed by ShotTimeScale like the shot). Without it a click mid-swing throws a Fireball that takes that arm off the
-- flick or the whip. See "Pyro: DETONATE and SCORCHING LASH" further down.
-- One lock per technique (review r1, 2026-09-24), so a Detonate press the server never answered can give back its own
-- lock without cutting short a Lash's.
local techM1Until = {}              -- [Id] = os.clock() until which that technique holds the M1 off
local function lockM1(id)
	local T = PyroFX.Tuning[id]
	local clip = Viewmodel.ArmClips[id]
	local length = (T and T.M1Lock) or (clip and clip.Keys[#clip.Keys].t) or 0
	techM1Until[id] = math.max(techM1Until[id] or 0, os.clock() + length / VFXLibrary.ShotTimeScale())
end

-- DETONATE'S ANSWER (review r1, 2026-09-24). The server turns a Detonate press away IN SILENCE -- its precheck refuses
-- before anything is spent, and the generic path sends no Denied -- so the flick the key plays is provisional until the
-- server's own "Detonate" broadcast comes back for this body (the listener in the Pyro section, below).
-- detonatePress numbers the presses and detonateHeard is the last one a broadcast answered, as cryoPress/cryoHeard do
-- for Cryo Beam. A press left unanswered past the wait gives the M1 back and flashes the slot, rather than holding the
-- Fireball off for the whole flick for nothing; and a second press while one is still unanswered is refused, so a double
-- tap inside one round trip -- before CD_ has come back -- neither restarts the flick nor sends a request the server's
-- cooldown would drop. detonateArmUntil: the flick owns the right arm up to its Trigger (armsBusy, below), so a Lash
-- pressed straight after it waits for the mark to go on instead of taking the arm off the flick.
local DETONATE_HEARD_WAIT = 0.6
local detonatePress, detonateHeard, detonateWaitUntil = 0, 0, 0
local detonateArmUntil = 0

--- A Detonate press has gone out and nothing has answered it yet (and the wait for an answer is not over).
local function detonateUnanswered()
	return detonatePress > detonateHeard and os.clock() < detonateWaitUntil
end

-- AFTERSHOCK'S ANSWER (review, 2026-09-25): Terra's Mobility press is provisional the same way (see "TERRA: AFTERSHOCK"
-- further down; the state lives up here because tryCast reads it). A second press while the first is unanswered -- or
-- while this client's own cast is still running (techM1Until.Aftershock) -- is refused, so a double tap inside one round
-- trip neither restarts the arms nor cancels the first press's shakes, and no request goes out for the server to drop.
local aftershockPress, aftershockHeard, aftershockWaitUntil = 0, 0, 0

--- An Aftershock press is still waiting for the server's answer, or this client's own Aftershock is still running.
local function aftershockBusy()
	if aftershockPress > aftershockHeard and os.clock() < aftershockWaitUntil then return true end
	return techM1Until.Aftershock ~= nil and os.clock() < techM1Until.Aftershock
end

local LOCAL_CAST = {
	-- Cryo's rebuilt Techniques and Ultimate (2026-09-24) have no clips of their own yet, so each borrows the nearest one:
	-- Blizzard the Chill Aura push, Deep Freeze the Flash Freeze slam (the trap goes into the floor at your feet), and
	-- Mirror Cage a palm thrust from both hands at the target (the Icicle Shard shot on each arm).
	Blizzard = function() Viewmodel.Play("ChillAura") end,
	DeepFreeze = function() Viewmodel.Play("FlashFreeze") end,
	MirrorCage = function()
		Viewmodel.PlayShot("R", "IcicleShard")
		Viewmodel.PlayShot("L", "IcicleShard")
		cagePress += 1
		local press = cagePress
		task.delay(math.max(CAGE_HEARD_WAIT, 2 * player:GetNetworkPing() + 0.3), function()
			if cageHeard >= press then return end
			flash("Ultimate", true)                                  -- nobody to cage: nothing was spent
		end)
	end,
	-- Cryo Beam: the key plays the WINDUP clip, not the fire clip (which only twitched until the Windup
	-- replaced it). The broadcast asks for the same clip again and Viewmodel's RestartGuard keeps it running.
	CryoBeam = function()
		Viewmodel.Play("CryoBeamCharge")
		cryoPress += 1
		local press = cryoPress
		-- a high ping is not a refusal: wait twice the round trip on top
		task.delay(math.max(CRYO_WINDUP_WAIT, 2 * player:GetNetworkPing() + 0.3), function()
			if cryoHeard >= press then return end
			setChanneling(false)                                     -- M1 and the dash are not left locked
			if Viewmodel.CurrentClip() == "CryoBeamCharge" then Viewmodel.Stop() end
		end)
	end,
	-- Heat Rush has no cast clip: the arms simply run hotter while it is held (PyroFX feeds Viewmodel.SetHeat)
	HeatRush = function() end,
	-- Cinder Shield: the fists punch each other on both arms at once over the hold, and your own full-size
	-- shield forms on the keypress rather than a round trip later
	CinderShield = function(character)
		Viewmodel.Play("CinderShieldHold")
		Viewmodel.PlayShot("R", "CinderShieldBump")
		Viewmodel.PlayShot("L", "CinderShieldBump")
		PyroFX.Shield(character)
	end,
	-- Detonate (Pyro's Mobility, 2026-09-23): the backhand flick, on the right arm, and no M1 until it is over. The
	-- mark itself is the server's (PyroHandler); the flick's look plays from its broadcast (AbilityFX).
	-- The press waits for the server's answer (DETONATE'S ANSWER, above): unanswered, the M1 comes back and the slot flashes.
	Detonate = function(_, role)
		Viewmodel.PlayShot("R", "Detonate")
		lockM1("Detonate")
		local scale = VFXLibrary.ShotTimeScale()
		local clip = Viewmodel.ArmClips.Detonate
		detonateArmUntil = os.clock() + ((clip and clip.Trigger) or PyroFX.Tuning.Detonate.Trigger) / scale
		detonatePress += 1
		local press = detonatePress
		-- a high ping is not a refusal: wait twice the round trip on top (the broadcast goes at the press, not the Trigger,
		-- so the wait is not slowed by ShotTimeScale)
		local wait = math.max(DETONATE_HEARD_WAIT, 2 * player:GetNetworkPing() + 0.3)
		detonateWaitUntil = os.clock() + wait
		task.delay(wait, function()
			if detonateHeard >= press or detonatePress ~= press then return end
			techM1Until.Detonate = nil                         -- the flick was for nothing: the Fireball is free again
			detonateArmUntil = 0
			flash(role or "Mobility", true)                    -- its own slot: Q or E since round 2
		end)
	end,
}

-- Voltaic (2026-09-25): its arms-on-the-keypress casts join LOCAL_CAST, and it gets this script's own gates
if VoltaicClient then
	for id, fn in pairs(VoltaicClient.LocalCast or {}) do LOCAL_CAST[id] = LOCAL_CAST[id] or fn end
	VoltaicClient.Bind({ Flash = flash, CanCast = canCast, AimPoint = aimPoint, BlockedByMovement = blockedByMovement })
end
if UmbraClient then
	-- Umbra's arms-on-the-keypress casts (UmbraAnim, 2026-09-28) join LOCAL_CAST, as Voltaic's do
	for id, fn in pairs(UmbraClient.LocalCast or {}) do LOCAL_CAST[id] = LOCAL_CAST[id] or fn end
	UmbraClient.Bind({ Flash = flash, CanCast = canCast, AimPoint = aimPoint, BlockedByMovement = blockedByMovement })
end
if RadiantClient then
	-- Radiant's casts (do-nothing arms until Phase 4's clips) join LOCAL_CAST, as Umbra's do
	for id, fn in pairs(RadiantClient.LocalCast or {}) do LOCAL_CAST[id] = LOCAL_CAST[id] or fn end
	RadiantClient.Bind({ Flash = flash, CanCast = canCast, AimPoint = aimPoint, BlockedByMovement = blockedByMovement })
end
if ToxinClient then
	-- Toxin's casts (no arms of their own yet) join LOCAL_CAST, as Radiant's do
	for id, fn in pairs(ToxinClient.LocalCast or {}) do LOCAL_CAST[id] = LOCAL_CAST[id] or fn end
	ToxinClient.Bind({ Flash = flash, CanCast = canCast, AimPoint = aimPoint, BlockedByMovement = blockedByMovement })
end
if ZephyrClient then
	-- Zephyr's v6 Techniques (2026-10-06): their arms-on-the-keypress casts (Gust Pad's palm-down press) join LOCAL_CAST and
	-- they get this script's gates, as Radiant's do. A press the generic path cannot carry -- Skyrider's ride, whose
	-- release is the ride's end and whose flap is the key again -- is taken whole before the gate: ZephyrClient.TryCast,
	-- in tryCast below.
	for id, fn in pairs(ZephyrClient.LocalCast or {}) do LOCAL_CAST[id] = LOCAL_CAST[id] or fn end
	ZephyrClient.Bind({ Flash = flash, CanCast = canCast, AimPoint = aimPoint, BlockedByMovement = blockedByMovement })
end

-- HELD abilities running from this client, by role: the key coming up ends them (InputEnded, below)
local heldRole = {}

----------------------------------------------------------------------------------------------------
-- Zephyr: Cross-Slash Dash (the Primary, 2026-09-16; held, aimed in 3D and passing through characters since 2026-09-17)
----------------------------------------------------------------------------------------------------
-- HOLD TO CHARGE. The key going down crosses the forearms and starts the charge: the body walks on at ChargeMoveShare of
-- its pace (DashMotor's Held hold), free to turn and aim, and the cast goes to the server, whose HELD path checks and pays
-- for it (the mana goes on the press). The arms and the look hold the wind-up for as long as the key is down, on the
-- cast's own clock (ZephyrFX.CrossSlashTime). The key coming up -- or MaxHold, by itself -- sets the distance from how long
-- it was held (MinDistance to MaxDistance over FullChargeTime) and launches: no sooner than ChargeTime after the press
-- (a tap), otherwise as soon as the wind-up has played its last beat. On the launch the dash takes the crosshair's point
-- in 3D (AimReach, through nothing but the caster and the characters it may not hurt) and glides the whole charged
-- distance that way, at the glide's pace, straight through any character (DashMotor's Free3D and ThroughCharacters:
-- walls, ramps and the floor stop it -- except that from the ground an aim down into that ground skims along it, its
-- SkimFloor since 2026-10-07: the spawn camera's 15-degree-down look once ended a full charge 0.9 studs out, the look
-- gliding on without the body). The direction DashMotor settles on is the one the launch, the look, the sweep and the
-- strike all use (OnStarted's `dir`). The launch goes to the server as the held cast's release, which starts the
-- cooldown. Every living character the caster may hurt that the GLIDE passes is collected, each once (up to MaxPath),
-- and at the Trigger -- as far past the end of the glide as ever -- the arms fling open, the X stamps, and whoever is in
-- its reach ahead (up to MaxTargets) joins them in one report the server checks (ZephyrHandler).
-- A charge dropped before its launch (died, frozen, slowed under DashMinCap, rooted, moved between zones, the body gone,
-- or the server ending it) launches nothing, and its release still goes, so the cooldown starts. A press the server
-- turns away brings no broadcast back: if none has come by the wait, the charge is dropped and the slot flashes red.
local slashCast = nil               -- this client's Cross-Slash from its press until its strike (or its drop)
local slashPress, slashHeard = 0, 0 -- presses sent, and the last one the server's charge broadcast answered

-- Whether the caster may hurt the character `model`: SpellshotConfig.MayHurt(caster, victim) asks about PLAYERS, so a
-- character with no player (a training dummy) always may, as CombatCore.IsFriendly has it. Without MayHurt in the place,
-- everyone may; the server decides in the end either way
local function mayHurt(model)
	if type(Config.MayHurt) ~= "function" then return true end
	local victim = Players:GetPlayerFromCharacter(model)
	if not victim then return true end
	local ok, may = pcall(Config.MayHurt, player, victim)
	return not ok or may ~= false
end

-- The living characters the caster may hurt inside a box, each model once across the whole cast (`seen`), onto `hits`
-- (up to `cap`) with where this client saw them. The others never take a place on the list.
local function crossSlashCollect(character, box, size, hits, seen, cap)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character }
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then table.insert(exclude, fx) end
	params.FilterDescendantsInstances = exclude
	local looked = {}
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, size, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not looked[model] and not seen[model] then
			looked[model] = true
			local h = model:FindFirstChildOfClass("Humanoid")
			local mroot = h and h.Health > 0 and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
			if mroot and #hits < cap and mayHurt(model) then
				seen[model] = true
				hits[#hits + 1] = { Part = mroot, Position = mroot.Position }
			end
		end
	end
end

-- Each frame of the glide: the characters in the stretch the body swept since the last frame (from `from` to where it
-- is now), as wide and tall as the X's reach, in the dash's frame. Returns where the body is now.
local function crossSlashSweep(character, dir, from, hits, seen)
	local S = ZephyrFX.Tuning.CrossSlash
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return from end
	local to = root.Position
	local mid = (from + to) * 0.5
	local length = math.abs((to - from):Dot(dir)) + 1
	crossSlashCollect(character, ZephyrFX.CrossSlashFrame(mid, dir),
		Vector3.new(S.HalfWidth * 2, S.HalfHeight * 2, length), hits, seen, S.MaxPath)
	return to
end

-- At the Trigger: every character inside the X's reach ahead of the body (Hits), sent with the ones the glide passed
-- (Passed), each with where this client saw it
local function crossSlashStrike(character, dir, passed, seen)
	local S = ZephyrFX.Tuning.CrossSlash
	local root = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) or player.Character ~= character then return end
	local box = ZephyrFX.CrossSlashFrame(root.Position, dir) * CFrame.new(0, 0, -S.Reach * 0.5)
	local hits = {}
	crossSlashCollect(character, box, Vector3.new(S.HalfWidth * 2, S.HalfHeight * 2, S.Reach), hits, seen, S.MaxTargets)
	if #hits + #passed > 0 then
		iceRemote:FireServer("CrossSlashStrike", { Origin = root.Position, Dir = dir, Hits = hits, Passed = passed })
	end
end

-- The dash's direction on the launch: from the root to the crosshair's point, in 3D. The ray passes through the caster,
-- the effects and the characters the caster may not hurt (SpellshotConfig.AddUnhurtable, when the place has it); with
-- nothing within AimReach it takes the ray's far end.
local function crossSlashAim(character, root)
	local S = ZephyrFX.Tuning.CrossSlash
	local cf = aimCF()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character, camera }
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then table.insert(exclude, fx) end
	if type(Config.AddUnhurtable) == "function" then pcall(Config.AddUnhurtable, exclude, player) end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(cf.Position, cf.LookVector * S.AimReach, params)
	local point = hit and hit.Position or (cf.Position + cf.LookVector * S.AimReach)
	local to = point - root.Position
	return (to.Magnitude > 0.5) and to.Unit or cf.LookVector
end

-- The charge ended without a launch. Its release still goes (the cooldown starts) unless the server turned the press away.
local function crossSlashDropped(cast, reason)
	if cast.Over then return end
	cast.Over = true
	if slashCast == cast then slashCast = nil end
	if Viewmodel.CurrentClip() == "CrossSlashDash" then Viewmodel.Stop() end
	ZephyrFX.CrossSlashCancel(cast.Character)
	if reason == "Denied" then
		flash(cast.Role, true)
	else
		castRemote:FireServer(cast.Role, { Release = true, Cancel = true })
	end
end

-- The frame the glide starts (DashMotor's OnStarted): the launch goes to the server, the look turns onto the dash, and
-- the glide is swept every frame -- the frame DashMotor ends it on too -- until the Trigger's strike.
local function crossSlashLaunched(cast, startPos, dir)
	local S = ZephyrFX.Tuning.CrossSlash
	local character = cast.Character
	cast.Launched = true
	castRemote:FireServer(cast.Role, { Release = true, Start = startPos, Dir = dir, Dist = cast.Dist })
	ZephyrFX.CrossSlashLaunch(character, dir)
	local passed, seen = {}, {}
	local last = startPos
	local gliding = true
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if gliding then
			last = crossSlashSweep(character, dir, last, passed, seen)
			gliding = DashMotor.IsActive() and player.Character == character
		end
		if ZephyrFX.CrossSlashTime(cast.Timing) < S.Trigger then return end
		conn:Disconnect()
		cast.Over = true
		if slashCast == cast then slashCast = nil end
		crossSlashStrike(character, dir, passed, seen)
	end)
end

--- The key came up (or MaxHold ran out): the distance is set, and the launch is booked.
local function releaseCrossSlash(role)
	local cast = slashCast
	if not cast or cast.Role ~= role or cast.Released or cast.Over then return end
	cast.Released = true
	local S = ZephyrFX.Tuning.CrossSlash
	local scale = VFXLibrary.ShotTimeScale()
	local held = math.min(os.clock() - cast.Pressed, S.MaxHold)
	local dist = S.MinDistance + (S.MaxDistance - S.MinDistance) * math.clamp(held / S.FullChargeTime, 0, 1)
	local speed = S.DashDistance / S.DashTime
	-- a tap launches at ChargeTime; a hold as soon as the wind-up has played the beat it was held on out
	local launchIn = math.max(S.ChargeTime, held * scale + (S.ChargeTime - S.HoldPose)) / scale
	cast.Dist = dist
	cast.Timing.LaunchAt = (cast.Pressed + launchIn - cast.Timing.Start) * scale
	cast.Timing.Glide = dist / speed * scale
	DashMotor.Launch(cast.Pressed + launchIn, {
		Distance = dist,
		MaxTime = dist / speed + (S.DashMaxTime - S.DashTime),
		DirAt = function(root) return crossSlashAim(cast.Character, root) end,
	})
end

local function tryCrossSlash(role, character, ability)
	local S = ZephyrFX.Tuning.CrossSlash
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or blockedByMovement(role, character) or not canCast(role, character)
		or character:GetAttribute("Holding_" .. role) or (slashCast and not slashCast.Released)
		or not DashMotor.CanStart(character, S.DashMinCap) then
		flash(role, true)
		return
	end
	local cast = { Role = role, Character = character, Pressed = os.clock(), Timing = ZephyrFX.CrossSlashTiming() }
	cast.Timing.Start = cast.Pressed
	local requested = DashMotor.Request(function(startPos, dir)
		crossSlashLaunched(cast, startPos, dir)
	end, {
		Held = true, HoldMove = S.ChargeMoveShare, Free3D = true, ThroughCharacters = true,
		Speed = S.DashDistance / S.DashTime, MinCap = S.DashMinCap,
		OnDropped = function(reason) crossSlashDropped(cast, reason) end,
	})
	if not requested then
		flash(role, true)
		return
	end
	slashCast = cast
	slashPress += 1
	cast.Press = slashPress
	flash(role, false)
	Viewmodel.Play(ability.Id, function() return ZephyrFX.CrossSlashTime(cast.Timing) end)
	castRemote:FireServer(role, {})                    -- the press: SpellshotService's HELD path checks and pays
	ZephyrFX.CrossSlash(character, nil, { Timing = cast.Timing })
	-- no word from the server: the press was turned away. A charge still held is dropped; one already launched has moved
	-- the body (movement is this client's), but the server keeps no slash for it, so it hurts nobody
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	task.delay(math.max(0.6, 2 * ping + 0.3), function()
		if slashHeard >= cast.Press or cast.Over then return end
		if cast.Launched then
			flash(role, true)
		else
			DashMotor.Cancel("Denied")
		end
	end)
end

-- MaxHold: the charge launches by itself
RunService.Heartbeat:Connect(function()
	local cast = slashCast
	if cast and not cast.Released and not cast.Over
		and os.clock() - cast.Pressed >= ZephyrFX.Tuning.CrossSlash.MaxHold then
		releaseCrossSlash(cast.Role)
	end
end)

-- DEFLECT GUST (the parry's press, tryDeflectGust) and GUST JUMP (tryGustJump, the GustJumpMotor hooks, its second jump
-- and THE FLOAT's key switch) were here until 2026-10-06, the v6 import. Gust Pad and Skyrider replace them, and their
-- presses go through ZephyrClient.TryCast (tryCast, below).

-- RING OF FIRE is POINTED (asked for 2026-09-14): the key takes the ground under the crosshair, pulled in to the
-- ability's Range, and the hand draws the circle round it by itself -- the server's broadcast plays the draw for
-- everyone, you included (AbilityFX). No ground to be found there refuses it, with nothing spent.
local function ringCentre(range)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local p = aimPoint(range)
	local from = root.Position
	local flat = Vector3.new(p.X - from.X, 0, p.Z - from.Z)
	if flat.Magnitude > range then
		p = Vector3.new(from.X, p.Y, from.Z) + flat.Unit * range
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { camera }
	if player.Character then table.insert(exclude, player.Character) end
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then table.insert(exclude, fx) end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	-- a spot up in the air (aimed over the horizon) is looked for below eye height, not on a roof above it; and the
	-- ground is found THROUGH characters -- aiming the Ultimate at an enemy puts the circle round their feet, not on
	-- their head
	local top = math.min(p.Y, from.Y + 3) + 4
	for _ = 1, 8 do
		local hit = workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, -80, 0), params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit.Position end
		table.insert(exclude, model)
		params.FilterDescendantsInstances = exclude
	end
	return nil
end

-- ...and until the snap the circle keeps FOLLOWING the crosshair (asked for 2026-09-14). Your own circle is moved
-- here every frame, straight from your aim, and the spot goes to the server SteerInterval apart for everyone else
-- and for where it burns. It lets go LockLead before the snap and sends the last spot, so the circle you last saw
-- is the one that erupts. No ground under the crosshair for a moment leaves the circle where it was.
local STEER_STEP = "SpellshotRingSteer"
local steerBound = false

local function steerRing(range, first)
	local character = player.Character
	local R = PyroFX.Tuning.RingOfFire
	local started = os.clock()
	local seen = false
	local sent, sentAt, last = first, started, first
	if steerBound then RunService:UnbindFromRenderStep(STEER_STEP) end
	steerBound = true
	local function stop()
		RunService:UnbindFromRenderStep(STEER_STEP)
		steerBound = false
		if seen and (last - sent).Magnitude > 0.05 then iceRemote:FireServer("RingOfFireSteer", last) end
	end
	-- after the camera has moved this frame, before PyroFX draws the circle (Camera + 4)
	RunService:BindToRenderStep(STEER_STEP, Enum.RenderPriority.Camera.Value + 3, function()
		local now = os.clock()
		if not PyroFX.RingSteerable(character) then
			-- not heard back yet: wait a moment for the broadcast (none comes if the cast was turned away)
			if seen or now - started > 1 or player.Character ~= character then stop() end
			return
		end
		seen = true
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if player.Character ~= character or not (humanoid and humanoid.Health > 0) then
			stop()
			return
		end
		local spot = ringCentre(range)
		if not spot then return end
		last = spot
		PyroFX.SteerRing(character, spot, true)
		if now - sentAt >= R.SteerInterval and (spot - sent).Magnitude > 0.05 then
			sent, sentAt = spot, now
			iceRemote:FireServer("RingOfFireSteer", spot)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Zephyr: Cyclone (the Ultimate, 2026-09-17)
----------------------------------------------------------------------------------------------------
-- POINTED AND STEERED, the Ring of Fire's way. The key takes the ground under the crosshair (ringCentre, pulled in to the
-- ability's Range); no ground there refuses it, with nothing spent. The arms rise and start circling at once (Viewmodel
-- CycloneForm, looped on ZephyrFX.CycloneLoopClock) and the cast goes to the server, which spends the Ultimate and
-- broadcasts the tornado to everyone, you included (AbilityFX). While it FORMS it follows the crosshair: your own copy is
-- moved here every frame (never faster than the server allows, ZephyrFX), and the spot goes to the server SteerInterval
-- apart; LockLead before touchdown the last spot is sent and the steering stops. A cast the server turns away brings no
-- Cyclone broadcast back: after the wait the arms come down (and a refusal it did send flashes the slot, below).
local CYCLONE_STEER = "SpellshotCycloneSteer"
local cyclonePress, cycloneHeard = 0, 0
local cycloneSteering = false

local function steerCyclone(range, first)
	local character = player.Character
	local C = ZephyrFX.Tuning.Cyclone
	local started = os.clock()
	local seen = false
	local sent, sentAt, last = first, started, first
	if cycloneSteering then RunService:UnbindFromRenderStep(CYCLONE_STEER) end
	cycloneSteering = true
	local function stop()
		RunService:UnbindFromRenderStep(CYCLONE_STEER)
		cycloneSteering = false
		if seen and (last - sent).Magnitude > 0.05 then iceRemote:FireServer("CycloneSteer", last) end
	end
	-- after the camera has moved this frame, before ZephyrFX draws the tornado (Camera + 3)
	RunService:BindToRenderStep(CYCLONE_STEER, Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		local left = ZephyrFX.CycloneFormLeft(character)
		if not left then
			-- not heard back yet: wait a moment for the broadcast (none comes if the cast was turned away)
			if seen or now - started > 1 or player.Character ~= character then stop() end
			return
		end
		seen = true
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if player.Character ~= character or not (humanoid and humanoid.Health > 0) or left <= C.LockLead then
			stop()
			return
		end
		local spot = ringCentre(range)
		if not spot then return end
		last = spot
		ZephyrFX.CycloneSteer(character, spot)
		if now - sentAt >= C.SteerInterval and (spot - sent).Magnitude > 0.05 then
			sent, sentAt = spot, now
			iceRemote:FireServer("CycloneSteer", spot)
		end
	end)
end

local function tryCyclone(role, character, ability)
	local centre = not blockedByMovement(role, character) and canCast(role, character) and ringCentre(ability.Range)
	if not centre then
		flash(role, true)
		return
	end
	flash(role, false)
	local clip = Viewmodel.Clips.CycloneForm
	Viewmodel.Play("CycloneForm", ZephyrFX.CycloneLoopClock(os.clock(), clip.LoopFrom, clip.LoopLength))
	cyclonePress += 1
	local press = cyclonePress
	castRemote:FireServer(role, { Center = centre })
	steerCyclone(ability.Range, centre)
	-- a high ping is not a refusal: wait twice the round trip on top
	task.delay(math.max(ZephyrFX.Tuning.Cyclone.HeardWait, 2 * player:GetNetworkPing() + 0.3), function()
		if cycloneHeard >= press then return end
		if Viewmodel.CurrentClip() == "CycloneForm" then Viewmodel.Stop() end
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: BULWARK CHARGE (Terra)
----------------------------------------------------------------------------------------------------
-- A shouldered charge forward. The movement is this client's, like Frost Slide's dash and Cross-Slash's
-- glide -- a charge that waited for the server would not feel like one -- and the server sweeps its own
-- copy of the body for whoever it reaches (TerraHandler). No hold and no aim: it goes where you face.
local function tryBulwarkCharge(role, character, ability)
	local C = TerraFX.Tuning.BulwarkCharge
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or blockedByMovement(role, character) or not canCast(role, character)
		or not DashMotor.CanStart(character, C.MinCap) then
		flash(role, true)
		return
	end
	local dir = camera.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
	local requested = DashMotor.Request(function(startPos, dashDir, dist)
		-- the charge is under way on this screen; the server hears where it started and which way
		castRemote:FireServer(role, { Start = startPos, Dir = dashDir, Dist = dist })
		flash(role, false)
		-- the ground tears up behind this client's own charge; everyone else's copy starts from the
		-- broadcast (AbilityFX). THE SLOT AND THE TRAIL WAIT FOR THE DASH'S OWN FRAME, as Frost Slide's do
		-- (2026-09-21): started beside the Request instead, the trail read DashMotor.IsActive() as false on
		-- its first tick -- a dash only ASKED for is not active yet -- so it took its teardown branch at
		-- once, cracking the three plates off in the frame they spawned and kicking up no dust at all.
		local until_ = os.clock() + C.MaxTime
		TerraFX.BulwarkTrail(character, function()
			return os.clock() < until_ and DashMotor.IsActive()
		end)
	end, {
		Dir = dir, Distance = C.Distance, Speed = C.Distance / C.Time, MaxTime = C.MaxTime,
		MinCap = C.MinCap, ThroughCharacters = true,
	})
	if not requested then
		flash(role, true)
		return
	end
end

----------------------------------------------------------------------------------------------------
-- Pyro: DETONATE and SCORCHING LASH (phase two, 2026-09-23; Techniques in either keyed slot since round 2, 2026-09-24)
----------------------------------------------------------------------------------------------------
-- Detonate is an ARM SHOT (Viewmodel.ArmClips): the flick on the right arm. The Lash is HELD since round 2: the key going
-- down puts the burning whip in the right hand, drawn back, and points the left at the crosshair (round 3: two HELD
-- shots, ArmClips.ScorchingLashHold and ScorchingLashAim), and coming up SWEEPS it -- ScorchingLash on the right arm, the
-- left pulling back out of its way (ScorchingLashDuck), both shots. So:
--   * A shot does not hold the M1 off by itself, so each sweep does (lockM1, above LOCAL_CAST: M1Lock, the clip's end).
--     While the whip is HELD there is no M1 at all (round 3: both arms are committed, the left one aiming).
--   * A shot played over an arm whose Fireball is still charging lets that Fireball go AT ONCE, out of a half-swung
--     arm (Viewmodel.PlayShot). So a press while either arm is charging one is HELD OVER -- not refused, and not played
--     over it: the cast starts on the first frame both arms are free, at most a Fireball's wind-up later (0.42 s), and
--     the M1 waits for it meanwhile. One press is held at a time, the latest. A Lash whose key comes up while its press
--     is held over is still a tap: it cracks the moment the hold starts.
--   * Ring of Fire's draw owns the right arm for its whole trace (Viewmodel.Tracing): a press then is refused. So is a
--     Detonate press while the whip is in hand (the flick would take the arm off the grip).
--   * Neither crack nor flick has an onRelease, so neither is a PENDING shot, and each would simply replace the other's on
--     the right arm while the first still resolved on its own clock (review r1, 2026-09-24). So each holds the arm to its
--     OWN Trigger -- Detonate by time (detonateArmUntil), a crack until its strike has gone (pendingLashes) -- and a press
--     of either in that span is held over like one behind a charging Fireball.
-- The Lash's STRIKE is decided on this client, the way Cross-Slash's is: whoever this screen shows inside the sector the
-- sweep covers round the flat aim the release carried, at the crack, checked by the server (PyroHandler). It goes on the
-- cast's own clock from the release, never on the shot's release: a shot releases at once when the rig is not built, or
-- when anything else takes that arm.
local ARM_QUEUE_WAIT = 0.5          -- s (ShotTimeScale slows it): the longest a press is held over for a charging shot
local queuedArmCast = nil           -- { Role, Character, Until, TapRelease }: the one press held over
local pendingLashes = {}            -- [n] = a crack between its release and its strike
local lashCracks = 0                -- numbers the cracks
-- THE WHIP IN HAND (round 2): { Role, Character, Pressed (os.clock), Press, Heard } from the press until the key comes
-- up, HoldMax runs out, or the hold is ended without a crack (the server's word, a death, a new body)
local lashHold = nil
local lashPress, lashHeard = 0, 0   -- presses sent, and the last one the server's ScorchingLashHold answered
local LASH_HEARD_WAIT = 0.6
-- the line check starts this far above the root: PyroHandler's LASH_CHEST (PyroFX.Tuning.ScorchingLash.Chest)
local LASH_CHEST = 1.5

--- Whether the M1 must wait: a Detonate or Lash clip is still playing (lockM1), or a press is held over for one, or the
--- whip is in hand (round 3: every M1, whichever it is -- the left arm is aiming).
local function techniqueHoldsM1()
	if queuedArmCast ~= nil or lashHold then return true end
	local now = os.clock()
	for _, untilAt in pairs(techM1Until) do
		if now < untilAt then return true end
	end
	return false
end

--- Whether an arm cast must wait: Detonate's flick short of its Trigger, a crack whose strike has not gone yet (neither
--- depends on the rig: the Lash's strike and the server's order of events do not), or either arm partway through a shot
--- that has not let go (a Fireball charging). Without a rig nothing is played on the arms (PlayShot does nothing), so no
--- shot can be let go early either.
local function armsBusy()
	if os.clock() < detonateArmUntil or next(pendingLashes) ~= nil then return true end
	return Viewmodel.IsBuilt() and (Viewmodel.ShotPending("R") or Viewmodel.ShotPending("L"))
end

--- "go": start the cast now. "held": held over until the arm is free (the Heartbeat after tryCast). "no": refused.
local function armShotGate(role, character)
	if Viewmodel.Tracing() or lashHold then return "no" end
	if armsBusy() then
		queuedArmCast = { Role = role, Character = character,
			Until = os.clock() + ARM_QUEUE_WAIT / VFXLibrary.ShotTimeScale() }
		return "held"
	end
	return "go"
end

--- PyroHandler's lineBlocked on this client's copy of the world: true if something solid that is not a character stands
--- between the two points. A character met on the way is dropped from the ray and it goes on -- except a Bulwark Wall,
--- which carries a Humanoid so that every kit can hurt it, but is COVER.
local function lashLineBlocked(character, from, to, target)
	local list = { character, target, camera }
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then list[#list + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then return false end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) or model:GetAttribute("WallOwner") then return true end
		list[#list + 1] = model
	end
	return false
end

--- At the crack: every other living character this screen shows inside the Lash's SWEEP (round 3, PyroFX.LashSweepHas:
--- SweepFrom .. SweepTo degrees round the flat aim `dir` out to Reach, or within Inner at any angle, root - Down .. root
--- + Up) that the caster may hurt (mayHurt) and has a clear line to from the chest, nearest first, at most MaxTargets,
--- each with where this client saw it. Players and training dummies alike: whatever carries a living Humanoid (a
--- Bulwark Wall has no HumanoidRootPart: its PrimaryPart stands in, as in crossSlashCollect). The shape and the line are
--- the ones PyroHandler checks the claim on, point for point: round the reported root, and from Chest above it.
local function lashTargets(character, root, dir, L)
	local origin = root.Position
	local chest = origin + Vector3.new(0, L.Chest or LASH_CHEST, 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character, camera }
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then table.insert(exclude, fx) end
	params.FilterDescendantsInstances = exclude
	-- one sphere round the caster holds all of the sweep (a body's root is inside a part of it)
	local looked, found = {}, {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(origin, L.Reach + L.Up + 3, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not looked[model] then
			looked[model] = true
			local h = model:FindFirstChildOfClass("Humanoid")
			local mroot = h and h.Health > 0 and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
			if mroot then
				local dist = (mroot.Position - origin).Magnitude
				if PyroFX.LashSweepHas(mroot.Position - origin, dir) and mayHurt(model) then
					found[#found + 1] = { Model = model, Part = mroot, Dist = dist }
				end
			end
		end
	end
	table.sort(found, function(a, b) return a.Dist < b.Dist end)
	local hits = {}
	for _, f in ipairs(found) do
		if #hits >= L.MaxTargets then break end
		local at = f.Part.Position
		if not lashLineBlocked(character, chest, at, f.Model) then
			hits[#hits + 1] = { Part = f.Part, Position = at }
		end
	end
	return hits
end

--- The sweep's strike, Trigger after the release on the cast's own clock: the sector is read off this screen round the
--- flat aim the RELEASE carried (what every client draws the sweep round, and what the server checks), and the report
--- goes even when it caught nobody, so the server can close the lash. Nothing goes for a press the server turned away,
--- or from a body that is gone or dead by now.
local function lashStrike(lash)
	pendingLashes[lash.N] = nil
	if lash.Denied then return end
	local character = lash.Character
	local L = PyroFX.Tuning.ScorchingLash
	local root = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (L and root and hum and hum.Health > 0) or player.Character ~= character then return end
	iceRemote:FireServer("ScorchingLashStrike", {
		Origin = root.Position, Dir = lash.Dir, Hits = lashTargets(character, root, lash.Dir, L),
	})
end

-- the server took this client's Detonate press: the flick the key started is the real one (DETONATE'S ANSWER, above
-- LOCAL_CAST)
iceRemote.OnClientEvent:Connect(function(action, kind, data)
	if action == "VFX" and kind == "Detonate" and type(data) == "table" and data.Character ~= nil
		and data.Character == player.Character then
		detonateHeard = detonatePress
	end
end)

--- The aim the sweep is measured from, FLAT (round 3: the sector lies in the horizontal plane): from the root toward
--- what the crosshair is on (within Reach; the crosshair's own point past it), so that in the third-person view too the
--- sweep is centred on what the crosshair covers. The camera's flat look if that point is too close to give a direction.
local function lashAim(root, L)
	local d = aimPoint(L.Reach) - root.Position
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude > 1 then return d.Unit end
	local look = camera.CFrame.LookVector
	d = Vector3.new(look.X, 0, look.Z)
	if d.Magnitude > 1e-3 then return d.Unit end
	local facing = root.CFrame.LookVector
	return Vector3.new(facing.X, 0, facing.Z).Unit
end

--- The whip in hand ends here without a crack (the server ended it, the body died or changed, the press was never
--- answered): the grip lets go and the whip goes. `flashRole`: the slot to flash red, for a press that came to nothing.
local function dropLashHold(flashRole)
	local h = lashHold
	if not h then return end
	lashHold = nil
	Viewmodel.StopShot("R", "ScorchingLashHold")
	Viewmodel.StopShot("L", "ScorchingLashAim")
	if PyroFX.LashHold then pcall(PyroFX.LashHold, h.Character, false, nil, true) end
	if flashRole then flash(flashRole, true) end
end

--- A TECHNIQUE, Scorching Lash (round 2): HELD, through SpellshotService's held path, which checks the cooldown and the
--- mana and pays on the press (so they are asked here first, as every cooldown cast asks them). The press puts the whip
--- in the right hand, drawn back, and points the left one at the crosshair (round 3) -- the burning whip trailing from the
--- grip for your own view at once -- and goes to the server; the key coming up (releaseLash) sweeps it.
local function tryScorchingLash(role, character, ability)
	local L = PyroFX.Tuning.ScorchingLash
	local root = character:FindFirstChild("HumanoidRootPart")
	-- the whip already in hand (either slot), or this slot still held on the server: nothing starts
	if lashHold or character:GetAttribute("Holding_" .. role) then return end
	-- a channel refuses it; a ROOT does not (a whip is thrown standing still, as every cooldown cast may be)
	if not (L and root) or blockedByMovement(role, character) or ultChanneling
		or character:GetAttribute("ChannelingUlt") == true or not canCast(role, character) then
		flash(role, true)
		return
	end
	local gate = armShotGate(role, character)
	if gate ~= "go" then
		if gate == "no" then flash(role, true) end
		return
	end
	flash(role, false)
	lashPress += 1
	local press = lashPress
	local h = { Role = role, Character = character, Pressed = os.clock(), Press = press }
	lashHold = h
	Viewmodel.PlayShot("R", "ScorchingLashHold")
	Viewmodel.PlayShot("L", "ScorchingLashAim")
	if PyroFX.LashHold then pcall(PyroFX.LashHold, character, true, nil, true) end
	castRemote:FireServer(role, {})
	-- a press the server turns away (a cooldown or the mana this client had not caught up with) brings no
	-- ScorchingLashHold back: after the wait the grip lets go and the slot flashes. A high ping is not a refusal.
	task.delay(math.max(LASH_HEARD_WAIT, 2 * player:GetNetworkPing() + 0.3), function()
		if lashHeard >= press then return end
		if lashHold == h then dropLashHold(role) end
		for _, lash in pairs(pendingLashes) do
			if lash.Press == press then lash.Denied = true end      -- a tap's crack the server never took
		end
	end)
end

--- The key of the Lash came up (or HoldMax ran out): THE SWEEP (round 3). The release goes to the server with the flat
--- aim -- the cooldown starts there -- the sweep plays on the right arm (departing from the grip) with the left pulling
--- back from its aim out of the way (ScorchingLashDuck), the M1 waits out the clip (M1Lock), your own whip is swept at
--- once, and the strike is booked for the Trigger.
local function releaseLash(role)
	local h = lashHold
	if not (h and h.Role == role) then
		-- a press still held over behind a charging shot: it is a tap, and cracks the moment it starts
		if queuedArmCast and queuedArmCast.Role == role then queuedArmCast.TapRelease = true end
		return
	end
	local character = h.Character
	local L = PyroFX.Tuning.ScorchingLash
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (L and root) or player.Character ~= character then
		dropLashHold()
		return
	end
	lashHold = nil
	local dir = lashAim(root, L)
	castRemote:FireServer(role, { Release = true, Dir = dir })
	Viewmodel.PlayShot("R", "ScorchingLash")
	if not Viewmodel.ShotPending("L") then Viewmodel.PlayShot("L", "ScorchingLashDuck") end
	lockM1("ScorchingLash")
	if PyroFX.Lash then pcall(PyroFX.Lash, character, nil, dir, true) end
	lashCracks += 1
	local lash = { N = lashCracks, Press = h.Press, Role = role, Character = character, Dir = dir }
	lash.Denied = lashHeard < h.Press and os.clock() - h.Pressed > math.max(LASH_HEARD_WAIT, 2 * player:GetNetworkPing() + 0.3)
	pendingLashes[lash.N] = lash
	task.delay(L.Trigger / VFXLibrary.ShotTimeScale(), lashStrike, lash)
end

-- The whip in hand, every frame: held to HoldMax (the row's, else Tuning's; slowed by ShotTimeScale as the server's is)
-- it cracks by itself; a body that died or was replaced drops it without a crack.
RunService.Heartbeat:Connect(function()
	local h = lashHold
	if not h then return end
	local hum = h.Character:FindFirstChildOfClass("Humanoid")
	if player.Character ~= h.Character or not h.Character.Parent or not (hum and hum.Health > 0) then
		dropLashHold()
		return
	end
	local row = VFXLibrary.AbilityById.ScorchingLash
	local holdMax = (row and row.HoldMax) or PyroFX.Tuning.ScorchingLash.HoldMax or 6
	if os.clock() - h.Pressed >= holdMax / VFXLibrary.ShotTimeScale() then releaseLash(h.Role) end
end)

-- The server's word on this client's whip: its ScorchingLashHold On answers the press; Off ends a hold the server ended
-- without a crack (a clear, a swap mid-hold, a death) -- the grip lets go here too.
iceRemote.OnClientEvent:Connect(function(action, kind, data)
	if action ~= "VFX" or kind ~= "ScorchingLashHold" or type(data) ~= "table" or data.Character == nil
		or data.Character ~= player.Character then
		return
	end
	if data.On == true then
		lashHeard = lashPress
	elseif lashHold and lashHeard >= lashHold.Press then
		dropLashHold()
	end
end)

local orbAimRole, orbFire = nil, false      -- Volt Orb's hold-to-aim (the role being aimed; the release's pass)

local function tryCast(role)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then return end
	local ability = VFXLibrary.AbilityFor(player, role)
	if not (ability and ability.Implemented) then return end

	-- Scorching Lash is HELD with a crack of its own (round 2): its own branch, ahead of the generic held path
	if ability.Id == "ScorchingLash" then
		tryScorchingLash(role, character, ability)
		return
	end

	-- Voltaic (2026-09-25): Overcharge's dash is this client's (DashMotor), as Bulwark Charge's is
	if VoltaicClient and VoltaicClient.TryCast(role, character, ability) then return end

	-- Zephyr (2026-10-06, the v6 import): a press its piece takes whole (Skyrider's ride, and its gust flap -- the key again
	-- while riding) stops here; anything else (Gust Pad's Targeted press) falls through to the generic path below
	if ZephyrClient and ZephyrClient.TryCast(role, character, ability) then return end

	if ability.Charges then
		tryChargeCast(role, character, ability)
		return
	end

	if ability.Id == "BulwarkCharge" then
		tryBulwarkCharge(role, character, ability)
		return
	end

	if ability.Id == "CrossSlashDash" then
		tryCrossSlash(role, character, ability)
		return
	end

	if ability.Id == "Cyclone" then
		tryCyclone(role, character, ability)
		return
	end

	if ability.Circle then
		local centre = not blockedByMovement(role, character) and canCast(role, character) and ringCentre(ability.Range)
		if not centre then
			flash(role, true)
			return
		end
		flash(role, false)
		castRemote:FireServer(role, { Center = centre })
		steerRing(ability.Range, centre)
		return
	end
	if ability.Held and (heldRole[role] or character:GetAttribute("Holding_" .. role)) then return end

	if blockedByMovement(role, character) or not canCast(role, character) then
		flash(role, true)
		return
	end
	-- Detonate is an arm shot (2026-09-23): held over while a Fireball charges, refused during Ring of Fire's draw -- and
	-- refused while an earlier press is still waiting for the server's answer (review r1: DETONATE'S ANSWER)
	if ability.Id == "Detonate" then
		if detonateUnanswered() then
			flash(role, true)
			return
		end
		local gate = armShotGate(role, character)
		if gate ~= "go" then
			if gate == "no" then flash(role, true) end
			return
		end
	end
	-- Aftershock (2026-09-25 review): refused while an earlier press is unanswered or the own cast still runs
	-- (AFTERSHOCK'S ANSWER)
	if ability.Id == "Aftershock" and aftershockBusy() then
		flash(role, true)
		return
	end
	-- VOLT ORB (2026-10-13): HOLD TO AIM. The press shows the arc (VoltaicClient.AimStart) and sends nothing; the key
	-- coming up throws it (releaseVoltOrb, below, comes back through here with orbFire set).
	if ability.Id == "VoltOrb" and not orbFire and VoltaicClient and VoltaicClient.AimStart then
		if not orbAimRole then
			orbAimRole = role
			VoltaicClient.AimStart(function() return aimPoint(ability.Range or 60) end)
		end
		return
	end
	flash(role, false)

	-- FIRST PERSON ONLY, and immediately -- the arms move on the keypress, not a round trip later.
	-- The third-person body clip is a separate concern and starts from the server's broadcast in
	-- AbilityFX; this script deliberately does not touch it. You cannot see your own body anyway.
	local localCast = LOCAL_CAST[ability.Id] or AquaClient.LocalCast[ability.Id]
	if localCast then localCast(character, role) else Viewmodel.Play(ability.Id) end

	local payload = {}
	if ability.Targeted then payload.Target = aimPoint(ability.Range) end
	castRemote:FireServer(role, payload)
	if ability.Held then heldRole[role] = ability.Id end

	if role == "Ultimate" and ability.Channel then setChanneling(true) end
end

--- The key of a held ability came up: it ends, and its cooldown starts (SpellshotService).
local function releaseHeld(role)
	local id = heldRole[role]
	if not id then return end
	heldRole[role] = nil
	-- a held ability whose release carries a shot (Aqua's Sidearm, 2026-09-24) adds it to the payload
	local payload = { Release = true }
	local extra = AquaClient.ReleasePayload(id, role)
	if extra then
		for k, v in pairs(extra) do payload[k] = v end
	end
	castRemote:FireServer(role, payload)
end
AquaClient.SetReleaser(releaseHeld)       -- a Sidearm held to its HoldMax lets go through here

-- A Detonate or Lash press held over (armShotGate: a Fireball charging, or the other technique short of its Trigger) goes
-- on the first frame both arms are free, through the whole of tryCast again: the cooldown, the mana, the charges and the
-- target are all asked afresh. Held past its wait (a wind-up slowed further than that), or its body gone, it is dropped
-- and the slot says so.
RunService.Heartbeat:Connect(function()
	local q = queuedArmCast
	if not q then return end
	if player.Character ~= q.Character or os.clock() > q.Until then
		queuedArmCast = nil
		flash(q.Role, true)
		return
	end
	if armsBusy() then return end
	queuedArmCast = nil
	tryCast(q.Role)
	if q.TapRelease then releaseLash(q.Role) end     -- its key already came up: a tap (round 2)
end)

----------------------------------------------------------------------------------------------------
-- M1: Icicle Shard
----------------------------------------------------------------------------------------------------
local m1Queued = false
local nextShotAt = 0
local nextSide = "R"
local shotId = 0            -- numbers each release, so the report of what it hit can name it

local function shotInterval()
	local ability = VFXLibrary.AbilityFor(player, "M1")
	-- a faster M1 for a while (Umbra's Eclipse, 2026-09-27): the server's M1RateMult on the character divides it
	local mult = player.Character and player.Character:GetAttribute("M1RateMult")
	if type(mult) ~= "number" or mult <= 0 then mult = 1 end
	return (ability and ability.FireInterval or 0.333) / mult / VFXLibrary.ShotTimeScale()
end

--- M1, Fireball: the punch on the click, the fire gathering on the fist, and the fireball leaving it at full
--- extension, straight down the crosshair. Hands alternate -- except with the Cinder Shield up, when the right hand
--- is holding it: the left throws, and the right swings the shield aside until the release. The hit is
--- reported the way Icicle Shard's is: what your own fireball stops on, checked by the server (PyroHandler).
local function fireFireball(character, ability)
	if Viewmodel.Tracing() then return end
	local shielded = character:GetAttribute("CinderShield") == true or Viewmodel.CurrentClip() == "CinderShieldHold"
	if ultChanneling or (Viewmodel.IsPlaying() and not shielded) then return end
	local side
	if shielded then
		side = "L"
		Viewmodel.PlayShot("R", "CinderShieldAside")
		PyroFX.ShieldAside(character)
	else
		side = nextSide
		nextSide = (side == "R") and "L" or "R"
	end
	local hot = (character:GetAttribute("Stacks_Primary") or 0) > 0
	PyroFX.Charge(character, side, hot, true)
	Viewmodel.PlayShot(side, "Fireball", function(releaseSide)
		if player.Character ~= character then return end
		local muzzle = Viewmodel.GetMuzzleCFrame(releaseSide)
		local eye, dir = aimCF().Position, camera.CFrame.LookVector
		shotId += 1
		local id = shotId
		iceRemote:FireServer("FireballRelease", { Id = id, Origin = eye, Dir = dir })
		-- through anyone this shot could not hurt (Config.MayHurt): a body that cannot take the hit must not stop it
		PyroFX.FireFireball(eye, dir, Config.AddUnhurtable({ character, camera }, player), muzzle.Position, function(hit)
			iceRemote:FireServer("FireballHit", { Id = id, Part = hit.Instance, Position = hit.Position })
		end, hot)
	end)
	castRemote:FireServer("M1", { Target = aimPoint(ability.Range), Side = side, Dir = camera.CFrame.LookVector })
end

--- M1, Wind Blade: a slash, and that stroke's crescent leaves the hand straight down the crosshair. The hands
--- alternate, RIGHT, LEFT, and each hand alternates its stroke: a burst goes RIGHT slashing down on the diagonal, LEFT
--- down, RIGHT up, LEFT up, and round again -- every stroke fires. After its stroke a hand HOLDS on its next stroke's
--- first pose (Viewmodel ArmClips.WindSlashDown/Up) until the clip's HoldUntil, WIND_HOLD, and then eases home. That
--- hold is the one threshold: a hand fired while it is holding plays its other stroke (up after down, down after up),
--- which starts exactly on the pose it is holding; a hand whose hold has ended (on its way home, or home) plays a
--- down-stroke, the opening slash, swung in from wherever the arm is. When neither hand is holding, the next blade is
--- the RIGHT hand's. A hand fires every second blade, so the four-stroke cycle carries on for clicks under
--- WIND_HOLD / 2 apart (0.525 s); slower than that every blade is a down-stroke from a hand that has let go, the hands
--- still taking turns, and at WIND_HOLD apart or slower every blade is the right hand's opening slash.
--- A hand holds only while the viewmodel still plays that shot: a clip that takes the arm (Cross-Slash, the Cinder
--- Shield's hold, a Technique's own arms) ends the hold early, and that hand's next stroke is a down-stroke.
--- With the Cinder Shield up the right hand is holding it, so the left slashes every blade, down and up in turn. The
--- hits are reported the way Icicle Shard's are -- what your own blade passes through (it pierces), checked by the
--- server (ZephyrHandler).
local WIND_HOLD = Viewmodel.ArmClips.WindSlashDown.HoldUntil
local windSide = "R"                -- the hand the next blade goes to while a hold lasts
local windHand = {                  -- each hand's last stroke: when, and which
	R = { At = -math.huge, Stroke = "Up" },
	L = { At = -math.huge, Stroke = "Up" },
}
--- Whether a hand is still holding after its last stroke (clip seconds, so ShotTimeScale slows it with the shot).
local function windHolding(side, now, scale)
	local hand = windHand[side]
	if (now - hand.At) * scale >= WIND_HOLD then return false end
	-- the viewmodel lets go of a hold when something else takes the arm; with no rig the time alone decides
	return not Viewmodel.IsBuilt() or Viewmodel.ShotPlaying(side, "WindSlash" .. hand.Stroke)
end
local function fireWindBlade(character, ability)
	if Viewmodel.Tracing() then return end
	local shielded = character:GetAttribute("CinderShield") == true or Viewmodel.CurrentClip() == "CinderShieldHold"
	if ultChanneling or (Viewmodel.IsPlaying() and not shielded) then return end
	local now = os.clock()
	local scale = VFXLibrary.ShotTimeScale()
	local side
	if shielded then
		side = "L"
	elseif windHolding("R", now, scale) or windHolding("L", now, scale) then
		side = windSide
	else
		side = "R"                  -- both holds are over: a new burst, on the right
	end
	windSide = (side == "R") and "L" or "R"     -- after a shielded blade too: the right hand comes back next
	local hand = windHand[side]
	local stroke = (windHolding(side, now, scale) and hand.Stroke == "Down") and "Up" or "Down"
	hand.At, hand.Stroke = now, stroke
	-- the kit's pre-fire swirl, winding into the slashing palm over the Trigger and handing over to its blade
	-- (2026-10-08: nothing called it, so live play only ever showed the late swirl after the blade had gone).
	-- At the viewmodel's CastPoint, so it rides the flick; the muzzle's position if the rig has none.
	do
		local vm = camera:FindFirstChild("SpellshotViewmodel")
		local arm = vm and vm:FindFirstChild(side == "L" and "ArmL" or "ArmR")
		local ink = arm and arm:FindFirstChild("ArmInk")
		local at = ink and ink:FindFirstChild("CastPoint")
		if not at then
			local ok, cf = pcall(Viewmodel.GetMuzzleCFrame, side)
			at = ok and typeof(cf) == "CFrame" and cf.Position or nil
		end
		if at then pcall(ZephyrFX.WindBladeSwirl, at, side, stroke, camera.CFrame.LookVector) end
	end
	Viewmodel.PlayShot(side, "WindSlash" .. stroke, function(releaseSide)
		if player.Character ~= character then return end
		local muzzle = Viewmodel.GetMuzzleCFrame(releaseSide)
		local eye, dir = aimCF().Position, camera.CFrame.LookVector
		shotId += 1
		local id = shotId
		iceRemote:FireServer("WindBladeRelease", { Id = id, Origin = eye, Dir = dir })
		-- through anyone this blade could not hurt (Config.MayHurt): such a body must neither use up a pierce nor be
		-- reported as a hit
		ZephyrFX.FireWindBlade(eye, dir, Config.AddUnhurtable({ character, camera }, player), muzzle.Position, function(hit)
			iceRemote:FireServer("WindBladeHit", { Id = id, Part = hit.Instance, Position = hit.Position })
		end, releaseSide, stroke)
	end)
	castRemote:FireServer("M1", { Target = aimPoint(ability.Range), Side = side, Stroke = stroke, Dir = camera.CFrame.LookVector })
end

local function fireShard()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then return end
	local ability = VFXLibrary.AbilityFor(player, "M1")
	if not (ability and ability.Implemented) then return end
	-- a Detonate or Scorching Lash clip is playing, or a press is held over for one (2026-09-23): no M1 until it is
	-- done. Like a two-arm clip's gate below, the click is spent, not held over. Nor while the whip is in hand (round 3:
	-- the left arm is aiming, so no M1 goes left-handed any more).
	if techniqueHoldsM1(ability.Id) then return end
	-- Undertow's interrupt (Aqua, 2026-09-24): no M1 until it is over either
	if workspace:GetServerTimeNow() < (character:GetAttribute("InterruptedUntil") or 0) then return end
	-- Voltaic (2026-09-25): Chain Bolt, the hitscan M1 (VoltaicClient draws and claims; VoltaicHandler checks)
	if VoltaicClient and VoltaicClient.FireM1(character, ability) then return end
	-- Umbra (2026-09-27): Shadow Dart, the brace then the dart (UmbraClient flies and claims; UmbraHandler checks)
	if UmbraClient and UmbraClient.FireM1(character, ability) then return end
	if RadiantClient and RadiantClient.FireM1(character, ability) then return end   -- Light Lance: the channel starts
	if ToxinClient and ToxinClient.FireM1(character, ability) then return end       -- Toxic Bubbles: the server's lob
	if ability.Id == "Fireball" then
		fireFireball(character, ability)
		return
	elseif ability.Id == "WindBlade" then
		fireWindBlade(character, ability)
		return
	elseif ability.Id == "Riptide" then
		-- Aqua's M1 (2026-09-24): the arms take turns as Icicle Shard's do, and nothing goes over a two-handed cast
		if ultChanneling or Viewmodel.IsPlaying() or Viewmodel.Tracing() then return end
		local side = nextSide
		nextSide = (side == "R") and "L" or "R"
		AquaClient.FireRiptide(character, side)
		castRemote:FireServer("M1", { Side = side, Dir = camera.CFrame.LookVector })
		return
	end
	-- a two-handed cast owns the arms -- except the Cinder Shield's hold, over which the left hand throws while the
	-- right swings the shield aside (a Cryo player can run Cinder Shield too)
	local shielded = Viewmodel.CurrentClip() == "CinderShieldHold"
	if ultChanneling or (Viewmodel.IsPlaying() and not shielded) or Viewmodel.Tracing() then return end
	local side = nextSide
	local fl = frostLotus()
	local lotus = not shielded and fl ~= nil and fl.On(character) and fl.PluckOn()
	if shielded then
		side = "L"
		Viewmodel.PlayShot("R", "CinderShieldAside")
		PyroFX.ShieldAside(character)
	elseif lotus then
		-- Frost Lotus: the left hand holds the lotus (low, clear of the crosshair) and the right throws every shot; it is
		-- let go 1 s after the last (FrostLotusKit.ViewShot draws the lotus on the left fist and the petal in the right)
		side = "R"
		if not Viewmodel.ShotPlaying("L", "LotusHold") then Viewmodel.PlayShot("L", "LotusHold") end
		fl.ViewShot(Viewmodel.GetFistCFrame, function() Viewmodel.StopShot("L", "LotusHold") end)
	else
		nextSide = (side == "R") and "L" or "R"
	end
	-- The arm moves on the click and the server hears about it at the same moment. The shard is
	-- released on the frame the thrust reaches full extension (the viewmodel calls back). The shot
	-- itself runs from the eye straight down the crosshair, aimed at that instant, so neither the
	-- moving arms nor the player's own movement can bend it; the rod you SEE starts at this hand and
	-- eases onto that line (FireIcicleShard's visualFrom).
	Viewmodel.PlayShot(side, lotus and "IcicleShardLotus" or "IcicleShard", function(releaseSide)
		if player.Character ~= character then return end
		local muzzle = Viewmodel.GetMuzzleCFrame(releaseSide)
		local eye, target = aimCF().Position, aimPoint(ability.Range)
		shotId += 1
		local id = shotId
		-- The server hears about the shot, then about what the rod you see hit (remotes from one client
		-- arrive in order). Your own screen decides the hit because it is the only view that matches
		-- what you aimed at: every client draws moving things about a sixth of a second behind the
		-- server, so the server's own flight missed moving targets you had dead centre. The server
		-- checks each report before it counts (AbilityHandler).
		iceRemote:FireServer("ShardRelease", { Id = id, Origin = eye, Target = target })
		VFXLibrary.FireIcicleShard(eye, target, Config.AddUnhurtable({ character, camera }, player), muzzle.Position, function(hit)
			iceRemote:FireServer("ShardHit", { Id = id, Part = hit.Instance, Position = hit.Position })
		end, character)
	end)
	castRemote:FireServer("M1", { Target = aimPoint(ability.Range), Side = side })
end

local function tryShard()
	local now = os.clock()
	if now < nextShotAt then
		m1Queued = true                   -- early: fire the moment the interval is up
		return
	end
	m1Queued = false
	-- A tap held over fires on the Heartbeat after it came due. Counting the next shot from the due
	-- time rather than from that Heartbeat keeps fast tapping at the full rate; a tap from rest (the
	-- schedule long past) counts from now.
	local due = nextShotAt
	nextShotAt = ((now - due < 0.05) and due or now) + shotInterval()
	fireShard()
end

----------------------------------------------------------------------------------------------------
-- M1: BOULDER SHOT (Terra) -- the one chargeable M1 in the game
----------------------------------------------------------------------------------------------------
-- The button going DOWN gathers a rock in the hand; the button coming UP throws it. A tap still throws a
-- boulder -- the minimum is a rock, not a pebble -- and holding to ChargeTime doubles its damage and nearly
-- doubles its size. Three things happen on the press: the rock starts to gather in this client's own hand, the
-- server is told the hold has started (it checks the charge a release claims against it, and the Passive reads the
-- same state), and the crosshair's charge ring comes up.
--
-- THE REWORK (2026-09-23, built in Blender first: blender_scripts/terra/m1_rework_bl.py). The rock is TerraFX's:
-- eleven pieces torn out of the floor into the fist, growing with the charge, and on the release THE SAME ROCK is
-- thrown -- Charge() returns it and FireBoulder() takes it over, so nothing is swapped. In first person it is drawn
-- at the viewmodel's fist but stands in for the full-sized rock further out along the eye -> fist line (see TerraFX),
-- which is what keeps the held rock and the thrown one a single image. The arm is Viewmodel's BoulderWindup, clocked
-- in seconds from the press, and BoulderThrow from wherever the windup had got to: a tap throws from mid-reach and
-- reads as one pick-up-and-throw; a hold throws from the loaded pose. The mechanic is untouched.
local boulder = { On = false, At = 0, Character = nil, Rock = nil }

local function boulderCharge01()
	if not boulder.On then return 0 end
	return math.clamp((os.clock() - boulder.At) / TerraFX.Tuning.BoulderShot.ChargeTime, 0, 1)
end

--- Where the gathering rock is held, for TerraFX.Charge: the viewmodel's fist and the lens in first person; the
--- body's own hand (and no lens) in the third-person testing view, where the viewmodel is not drawn. It is bound to
--- the CHARACTER that pressed, not to boulder.Character: the release tears the hold down (stopBoulderCharge) before
--- the rock has left the hand, and the rock goes on following the fist through the arm's drive.
local function boulderHand(character)
	if not (character and character.Parent and player.Character == character) then return nil end
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z))
	local fist = Viewmodel.GetFistCFrame and Viewmodel.GetFistCFrame("R")
	if fist then return fist, camera.CFrame.Position, facing end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then return nil end
	return hand.CFrame, nil, facing
end

local function ringCharge(alpha)
	local ring = _G.SpellshotChargeRing
	if type(ring) == "function" then ring(alpha) end
end

local function stopBoulderCharge()
	if not boulder.On then return end
	boulder.On = false
	boulder.Character = nil
	boulder.Rock = nil
	ringCharge(nil)
	-- a charge dropped rather than thrown (death, a lost character): the arm lets go of the hold it is sitting in,
	-- or it would keep the loaded pose for ever. The throw's own clip is not a hold and ends itself.
	if Viewmodel.CurrentClip() == "BoulderWindup" then Viewmodel.Stop() end
	iceRemote:FireServer("BoulderCharge", { On = false })
end

local function startBoulderCharge(character)
	if boulder.On then return end
	boulder.On = true
	boulder.At = os.clock()
	boulder.Character = character
	local at = boulder.At
	Viewmodel.Play("BoulderWindup", function() return os.clock() - at end)
	iceRemote:FireServer("BoulderCharge", { On = true })
	boulder.Rock = TerraFX.Charge(function()
		if not boulder.On or boulder.At ~= at or player.Character ~= boulder.Character then return nil end
		return boulderCharge01()
	end, function() return boulderHand(character) end, { Own = true, Character = character,
		Wrap = require(ReplicatedStorage.Spellshot.SkinCatalog).Chosen(player, "BoulderShot") })
end

--- The throw. The shot leaves the eye straight down the crosshair, as every other M1 does, and the rock you SEE
--- is the one in your hand: it leaves at the top of the arm's drive and runs out onto that line (TerraFX).
local function releaseBoulder()
	local character = boulder.Character
	local charge = boulderCharge01()
	local rock = boulder.Rock
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- THE HOLD IS TORN DOWN AFTER THE RELEASE GOES OUT, not before (2026-09-21). stopBoulderCharge ends with
	-- `BoulderCharge { On = false }` on this same remote, so calling it first meant the server cleared its record of
	-- the hold one message BEFORE BoulderRelease asked it how long the hold was -- chargeHeld came back nil and the
	-- claim was clamped to the 0.1 floor. Every honest throw in the game dealt a tap's damage however long it was
	-- held, and a client that simply never sent the On=false got the full 48: the exploit path was the stronger one.
	-- A DEAD CASTER THROWS NOTHING (2026-09-21): the guard asked whether the character was still hers, and a corpse
	-- still is, so letting go after dying flew a full cosmetic boulder out of the death camera -- arc, burst, debris
	-- and ground crack -- for a shot the server had already refused. The press has always tested the humanoid.
	if not character or player.Character ~= character or not (humanoid and humanoid.Health > 0) then
		stopBoulderCharge()
		return
	end
	local ability = VFXLibrary.AbilityFor(player, "M1")
	if not (ability and ability.Id == "BoulderShot") then stopBoulderCharge() return end
	local now = os.clock()
	if now < nextShotAt then stopBoulderCharge() return end   -- a throw a moment ago: this one is simply dropped
	nextShotAt = now + shotInterval()
	local eye, dir = aimCF().Position, camera.CFrame.LookVector
	-- from wherever the arm is: mid-reach on a tap, loaded on a hold -- and on the shot's clock, so the review
	-- slow-motion (ShotTimeScale) slows the arm with the rock it lets go of
	local thrownAt = os.clock()
	Viewmodel.Play("BoulderThrow", function() return (os.clock() - thrownAt) * VFXLibrary.ShotTimeScale() end)
	shotId += 1
	local id = shotId
	-- the report first, then the flight, as Icicle Shard and Fireball do: the server hears about the release
	-- before anything cosmetic can delay it
	iceRemote:FireServer("BoulderRelease", { Id = id, Origin = eye, Dir = dir, Charge = charge })
	stopBoulderCharge()                                -- ...and only now does the server's record of the hold go
	TerraFX.FireBoulder(eye, dir, charge, Config.AddUnhurtable({ character, camera }, player), rock, function(hit)   -- through teammates, as every other shot (2026-10-18 review; was { character, camera })
		iceRemote:FireServer("BoulderHit", { Id = id, Part = hit.Instance, Position = hit.Position })
	end)
	castRemote:FireServer("M1", { Target = aimPoint(ability.Range), Dir = dir, Charge = charge })
end

-- the ring follows the hold every frame, and a charge that outlives its character -- or its caster -- is dropped
RunService.Heartbeat:Connect(function()
	if not boulder.On then return end
	-- ...AND A DEAD ONE TOO (2026-09-21): this asked only whether the character was still there, and a corpse is,
	-- so dying mid-hold never resolved the charge. The rock went on growing in the dead hand, the ring stayed
	-- pegged on the crosshair, and with no BoulderCharge{On=false} ever sent the server's record of the hold lived
	-- on, which kept Bedrock stacking its plates on the body until the respawn.
	local humanoid = boulder.Character:FindFirstChildOfClass("Humanoid")
	if player.Character ~= boulder.Character or not boulder.Character.Parent
		or not (humanoid and humanoid.Health > 0) then
		stopBoulderCharge()
		return
	end
	ringCharge(boulderCharge01())
end)

----------------------------------------------------------------------------------------------------
-- TERRA: AFTERSHOCK (the Mobility Technique, 2026-09-25; it replaces Tremor Vault)
----------------------------------------------------------------------------------------------------
-- Both fists into the ground: a ring of erupting rock races out from the fists' point. TerraHandler decides every hit on
-- the server's clock, and every client draws the ring from its "Aftershock" broadcast (AbilityFX, TerraFX). The key rides
-- the generic cooldown path (tryCast -> LOCAL_CAST) with an empty payload -- the server trusts nothing in it -- and this
-- is the first-person half, started on the press rather than a round trip later:
--   * a Boulder charge in hand is dropped (both arms slam; the server drops its record too, stopCharge "Interrupted");
--   * the arms play Viewmodel's Aftershock on TerraFX.AftershockClock over this client's own clock from the press: the
--     clip's keys are "sim" seconds, and the clock holds the contact frame through the hitpause (HoldFrames / 60);
--   * no M1 -- and no Boulder charge, which asks the same techniqueHoldsM1 -- until the body is back in the stance: Hit,
--     the hitpause, then Recover, slowed by ShotTimeScale as the clip is;
--   * the camera, all Viewmodel.Shake and all on this client's clock: a thump under the feet on each windup Beat, the
--     slam at contact (sim Hit) and the ring's rumble as the front leaves (after the hitpause). Everybody else's shake
--     comes from TerraFX, scaled by how far they stand from the slam; the caster's own is here, so it lands with the arms.
-- THE PRESS IS PROVISIONAL until the server's own "Aftershock" broadcast comes back for this body: its Precheck (no floor
-- under the feet, entombed, one already running) turns a press away IN SILENCE and spends nothing. So a press left
-- unanswered past the wait -- Cryo Beam's, max(0.6, 2 x ping + 0.3) -- takes the arms down, cancels the
-- shakes still to come (a token), gives the M1 back and flashes the slot. An AftershockEnd for this body (the windup cut
-- before the slam: a death, a clear, an interrupt, a Tomb) does the same without the flash (the listener at the bottom).
-- A second press while one is unanswered or the cast still runs never reaches here (AFTERSHOCK'S ANSWER, up top:
-- aftershockPress / aftershockHeard / aftershockWaitUntil live there, and tryCast refuses it).
local aftershockToken = 0          -- bumped to cancel every shake a press has scheduled

--- This client's own Aftershock is over before its time (refused, or its windup cut): the arms, the shakes and the M1.
local function endOwnAftershock(flashRole)
	aftershockToken += 1
	techM1Until.Aftershock = nil
	if Viewmodel.CurrentClip() == "Aftershock" then Viewmodel.Stop() end
	if flashRole then flash(flashRole, true) end
end

LOCAL_CAST.Aftershock = function(character, role)
	local A = TerraFX.Tuning.Aftershock
	local hold = A.HoldFrames / 60
	stopBoulderCharge()                                  -- nothing to do without a charge up
	local at = os.clock()
	Viewmodel.Play("Aftershock", function()
		return TerraFX.AftershockClock((os.clock() - at) * VFXLibrary.ShotTimeScale())
	end)
	local scale = VFXLibrary.ShotTimeScale()
	techM1Until.Aftershock = math.max(techM1Until.Aftershock or 0, at + (A.Hit + hold + A.Recover) / scale)
	aftershockToken += 1
	local token = aftershockToken
	-- `t`: seconds of the cast's own (ShotTimeScale-slowed) time after the key
	local function shakeAt(t, amp, decay)
		task.delay(t / scale, function()
			if aftershockToken ~= token or player.Character ~= character then return end
			Viewmodel.Shake(amp, decay)
		end)
	end
	for _, beat in ipairs(A.Beats) do shakeAt(beat, A.BeatShake, A.ShakeDecay) end
	shakeAt(A.Hit, A.Shake, A.ShakeDecay)
	shakeAt(A.Hit + hold, A.Rumble, A.RumbleDecay)
	aftershockPress += 1
	local press = aftershockPress
	-- a high ping is not a refusal: wait twice the round trip on top (the broadcast goes at the key, not the slam, so
	-- the wait is not slowed by ShotTimeScale)
	local wait = math.max(0.6, 2 * player:GetNetworkPing() + 0.3)
	aftershockWaitUntil = os.clock() + wait
	task.delay(wait, function()
		if aftershockHeard >= press or aftershockPress ~= press then return end
		endOwnAftershock(role or "Mobility")
	end)
end

-- A click that landed early fires from here when its slot comes round. With M1 AUTO-FIRE on --
-- a touch row, so this is off on a keyboard unless the player has asked for it -- holding the
-- button keeps firing at the M1's own interval instead of asking for one shot per press.
local m1Held = false

RunService.Heartbeat:Connect(function()
	if m1Queued and os.clock() >= nextShotAt then
		tryShard()
	elseif m1Held and Settings.Get("AutoFire") and os.clock() >= nextShotAt then
		tryShard()
	end
end)

----------------------------------------------------------------------------------------------------
-- developer keys
----------------------------------------------------------------------------------------------------
-- The always-on cheat readout that used to live here is gone. Everything it did -- and a great
-- deal it did not -- now lives in DevPanel, hidden behind the ';' toggle, so nothing dev-facing
-- is on screen during normal play. This script is back to being only ability input.

-- (named, 2026-10-04: the touch buttons come in through these same two handlers, see TOUCH below. `fromTouch` marks
-- a press that came off a button rather than a device.)
local function onInputBegan(input, gameProcessed, fromTouch)
	if gameProcessed then return end
	if player:GetAttribute("SettingsOpen") or player:GetAttribute("LoadoutOpen")
		or player:GetAttribute("QuickPlayOpen") or player:GetAttribute("ShopOpen") then return end
	-- the Hub is not a fight: no casting there (HubServer sets Zone; the server refuses Hub casts too)
	if player:GetAttribute("Zone") == "Hub" then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- with the cursor out (Left Alt held, or the dev panel open) a click is for the UI, not a shot
		-- (a finger on the FIRE button has no cursor to be out)
		if not fromTouch and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then return end
		m1Held = true
		-- Terra's M1 is the one that charges: the press gathers, and InputEnded throws
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local ability = VFXLibrary.AbilityFor(player, "M1")
		if ability and ability.Id == "BoulderShot" and ability.Implemented and humanoid and humanoid.Health > 0 then
			-- two-handed: not with Scorching Lash's whip in the right hand, nor over a Detonate / Lash clip (round 2); and
			-- not while interrupted (2026-09-25 review: an Aftershock strike sets InterruptedUntil, and the server's
			-- BoulderCharge goes through Core.CanAct, so a charge drawn here would be one nobody else saw -- fireShard's gate)
			if not techniqueHoldsM1(ability.Id)
				and workspace:GetServerTimeNow() >= (character:GetAttribute("InterruptedUntil") or 0) then
				startBoulderCharge(character)
			end
			return
		end
		tryShard()
		return
	end
	local role = BINDS[input.KeyCode] or TOUCH_ROLES[input.KeyCode]
	if role then tryCast(role) end
end
UserInputService.InputBegan:Connect(onInputBegan)

local function onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		m1Held = false
		if boulder.On then releaseBoulder() end
		if RadiantClient then RadiantClient.ReleaseM1() end                -- Light Lance: letting go ends the channel
	end
	-- a held ability (Heat Rush) ends when its key comes up, wherever the pointer is; a Cross-Slash charge launches
	local role = BINDS[input.KeyCode] or TOUCH_ROLES[input.KeyCode]
	if role then
		if orbAimRole == role then                                             -- Volt Orb: letting go throws it
			orbAimRole = nil
			if VoltaicClient and VoltaicClient.AimStop then VoltaicClient.AimStop() end
			orbFire = true
			tryCast(role)
			orbFire = false
		end
		releaseLash(role)                                                      -- Scorching Lash cracks (round 2)
		releaseHeld(role)
		releaseCrossSlash(role)
	end
end
UserInputService.InputEnded:Connect(onInputEnded)

-- TOUCH (2026-10-04). The on-screen buttons (TouchControls) arrive through TouchBus as the same presses: FIRE is the
-- mouse button, an ability button is its role's key. Down runs the handler above, up the one below it, so a charge and a
-- held ability behave as they do on a key.
do
	local TouchBus = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("TouchBus"))
	local TOUCH_M1 = { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown }
	TouchBus.Event:Connect(function(action, down)
		local input = TOUCH_M1
		if action ~= "M1" then
			if not TOUCH_ROLES["Touch" .. tostring(action)] then return end         -- Jump and Crouch are MovementController's
			input = { UserInputType = Enum.UserInputType.Touch, KeyCode = "Touch" .. action }
		end
		if down then onInputBegan(input, false, true) else onInputEnded(input) end
	end)
end

-- A key that is down when the window loses focus (alt-tab) never gets its InputEnded (2026-09-30 review): every held
-- ability lets go here, as the key coming up would. Else a held Benediction ran on with the caster rooted until the bar
-- emptied, and the first press after coming back was swallowed (heldRole still set).
UserInputService.WindowFocusReleased:Connect(function()
	local roles = {}
	for role in pairs(heldRole) do roles[#roles + 1] = role end
	for _, role in ipairs(roles) do releaseHeld(role) end
end)

----------------------------------------------------------------------------------------------------
-- the Ultimate keeps aiming while it fires
----------------------------------------------------------------------------------------------------
local lastAimSent = 0
RunService.Heartbeat:Connect(function()
	if not ultChanneling then return end
	local character = player.Character
	if not character then setChanneling(false); return end
	if os.clock() - lastAimSent >= 1 / 15 then
		lastAimSent = os.clock()
		iceRemote:FireServer("UltAim", aimPoint((VFXLibrary.AbilityFor(player, "Ultimate") or VFXLibrary.AbilityById.CryoBeam).Range))
	end
end)

----------------------------------------------------------------------------------------------------
-- a HELD ability that keeps aiming (Tremor Vault, 2026-09-20)
----------------------------------------------------------------------------------------------------
-- (2026-09-25: Aftershock replaced Tremor Vault, and nothing sets AimWhileHeld any more. The sender stays, generic and
-- idle, with SpellshotService's Phase "Aim" plumbing, for whichever held ability steers next.)
-- While one runs, where the player LOOKS is where it goes: the flat look direction, 15 times a second, on that
-- ability's own CastRequest. SpellshotService hands it to the ability script (Phase "Aim") and charges nothing
-- for it; the body itself is the server's while it burrows, so this is the only steering it gets.
local lastHeldAim = 0
RunService.Heartbeat:Connect(function()
	local character = player.Character
	if not character or os.clock() - lastHeldAim < 1 / 15 then return end
	for _, role in ipairs(ROLES) do
		local ability = VFXLibrary.AbilityFor(player, role)
		if ability and ability.AimWhileHeld and character:GetAttribute("Holding_" .. role) == ability.Id then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 1e-3 then
				lastHeldAim = os.clock()
				castRemote:FireServer(role, { Aim = flat.Unit })
			end
		end
	end
end)

iceRemote.OnClientEvent:Connect(function(action, kind, data)
	-- the server took this client's Cross-Slash press (tryCrossSlash's wait); a charge it ended itself launches nothing here
	if action == "VFX" and kind == "CrossSlashCharge" and type(data) == "table" and data.Character == player.Character then
		slashHeard = slashPress
	end
	if action == "VFX" and kind == "CrossSlashCancel" and type(data) == "table" and data.Character == player.Character
		and slashCast and not slashCast.Launched and not slashCast.Over then
		DashMotor.Cancel("Server")
	end
	if action == "VFX" and kind == "CryoBeamStop" and type(data) == "table" then
		if data.Character == player.Character then setChanneling(false) end
	end
	-- the server took this client's Mirror Cage (LOCAL_CAST.MirrorCage's wait)
	if action == "VFX" and kind == "MirrorCage" and type(data) == "table" and data.Character == player.Character then
		cageHeard = cagePress
	end
	-- ...and its Cyclone (tryCyclone's wait); a Cyclone it turned away (no ground there, out of reach) flashes the slot
	if action == "VFX" and kind == "Cyclone" and type(data) == "table" and data.Character == player.Character then
		cycloneHeard = cyclonePress
	end
	if action == "VFX" and kind == "CycloneEnd" and type(data) == "table" and data.Character == player.Character
		and data.Refused then
		flash("Ultimate", true)
	end
	-- the server took the Ultimate: the windup the keypress started is the real one (LOCAL_CAST.CryoBeam)
	if action == "VFX" and kind == "CryoBeamWindup" and type(data) == "table" then
		if data.Character == player.Character then
			cryoHeard = cryoPress
			setChanneling(true)                                     -- a Windup that outran the timer puts the channel back
		end
	end
	-- AFTERSHOCK (2026-09-25): the server took this client's press (LOCAL_CAST.Aftershock's wait)...
	if action == "VFX" and kind == "Aftershock" and type(data) == "table" and data.Character ~= nil
		and data.Character == player.Character then
		aftershockHeard = aftershockPress
	end
	-- ...or cut its windup before the slam (a death, a clear, an interrupt, a Tomb): the arms come down, the shakes still
	-- to come are cancelled and the M1 is free again
	if action == "VFX" and kind == "AftershockEnd" and type(data) == "table" and data.Character ~= nil
		and data.Character == player.Character then
		endOwnAftershock()
	end
	-- A BOULDER CHARGE THE SERVER DROPPED ("Interrupted", 2026-09-25: this body's own Aftershock took both arms, or
	-- somebody else's struck it). This client never heard a server-side drop before (the M1 port's known gap), so the rock
	-- stayed in the hand, the ring on the crosshair and the arm wound: the hold is torn down here too, and the windup clip
	-- let go even if the hold was already gone. Only this reason: a "Release" stop answers this client's own throw.
	if action == "VFX" and kind == "BoulderChargeStop" and type(data) == "table" and data.Character ~= nil
		and data.Character == player.Character and data.Reason == "Interrupted" then
		stopBoulderCharge()
		if Viewmodel.CurrentClip() == "BoulderWindup" then Viewmodel.Stop() end
	end
end)
