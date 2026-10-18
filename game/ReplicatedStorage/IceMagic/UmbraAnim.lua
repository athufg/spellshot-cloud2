--[[
	UmbraAnim  (ModuleScript)  ->  ReplicatedStorage/IceMagic/UmbraAnim

	EVERY UMBRA ANIMATION, AND ONLY THAT (Phase 4 stage A, 2026-09-28). Which clip plays on which body, when, and on which
	clock: the caster's first-person arms (Viewmodel) from the KEYPRESS, every body in the world (CastPose, the caster's own
	included, for the third-person view) from the SERVER'S BROADCASTS. The clips themselves are CastPose.Clips.Umbra* and
	Viewmodel.Clips / ArmClips.Umbra* (castpose_umbra_clips.luau, viewmodel_umbra_clips.luau); the decoy's idle is
	UmbraDecoyPoser's. No VFX here, and no VFX code may play an Umbra clip: one owner, so nothing is played twice.

	WIRING (see TRIGGERS.md for the exact lines):
	  UmbraAnim.Start()                once, on the client (UmbraClient's load): its own listener on IceAbilityRemote for
	                                   the Umbra broadcasts below, and UmbraDecoyPoser.Start()
	  UmbraAnim.LocalCast              { ShadowStep, Mark, DecoyDouble, Eclipse } -> fn(character, role): the keypress's
	                                   arms. SpellshotInput's LOCAL_CAST takes them (through UmbraClient.LocalCast, the
	                                   way VoltaicClient's are merged)
	  UmbraAnim.LocalDartCharge(c)     the Shadow Dart click (UmbraClient.FireM1): plays the arms' charge; RETURNS the real
	                                   seconds from now to the release, the one number FireM1 must wait
	  UmbraAnim.DartChargeTime(c)      that same number, without playing anything
	  UmbraAnim.DartMayStart()         FireM1's arms gate, in place of Viewmodel.IsPlaying(): true when no two-arm clip
	                                   holds the arms, or when the one that does is an Umbra clip past the point a dart may
	                                   cut it (the dart's own recovery, which FireInterval 2.6 < the clip's 2.8 must cut)
	  UmbraAnim.OwnStepLandedAt()      os.clock() when this client's last Shadow Step re-formed (nil while it has not) --
	                                   for a first-person smoke that should open on the same frame as the arms

	BROADCASTS HEARD (UmbraHandler's, all "VFX" on IceAbilityRemote):
	  ShadowDartCharge  NEW, asked of the server (TRIGGERS.md): { Character, T0, Mult } on the accepted click
	  ShadowDart        the release (existing)
	  MarkApplied       the mark (existing)
	  ShadowStepOut / ShadowStepIn   the dissolve / the re-form (existing)
	  EclipseCharge     NEW, asked of the server: { Character, Caster, T0 } on the cast, with EclipseStart moved to the
	                    end of UmbraTuning.Eclipse.WindupTime. Without it, EclipseStart is the cast and the open plays on it
	  EclipseStart / EclipseEnd      (existing)
	  DecoySpawn        (existing)

	CLOCKS. Every body clip runs from the moment its broadcast is RECEIVED (os.clock), not from the server's T0: the thing
	it has to line up with -- the dart drawn at the release, the body moved by the step, the decoy peeling -- also reaches
	this client one latency after the server, so receipt time keeps the arm and the effect together on every client, and
	it is exactly what AbilityFX's own CastPose.Play calls do. Clocks carry VFXLibrary.ShotTimeScale (the M1 slow-motion
	hook the server scales Umbra by), and the dart's M1RateMult (Eclipse's 1.5x).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local T = require(iceFolder:WaitForChild("UmbraTuning"))

local UmbraAnim = {}
UmbraAnim.LocalCast = {}

----------------------------------------------------------------------------------------------------
-- modules, found lazily and guarded (never a wait on the input path)
----------------------------------------------------------------------------------------------------
local mods = {}
local function need(name)
	if mods[name] ~= nil then return mods[name] or nil end
	local m = iceFolder:FindFirstChild(name) or spellFolder:FindFirstChild(name)
	local ok, mod = pcall(function()
		return m and require(m)
	end)
	mods[name] = (ok and type(mod) == "table" and mod) or false
	if not ok then warn("[UmbraAnim] " .. name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[UmbraAnim] " .. tostring(msg))
end

local function isModel(v)
	return typeof(v) == "Instance" and v:IsA("Model")
end

--- VFXLibrary.ShotTimeScale(): 1 in play, below 1 to film in slow motion. The server scales Umbra's times by it too.
local function shotScale()
	local V = need("VFXLibrary")
	local ok, s = pcall(function()
		return V and V.ShotTimeScale()
	end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

--- Eclipse's faster M1 (the server's M1RateMult on the character, 1.5 while it runs).
local function rateMult(character)
	local m = character and character:GetAttribute("M1RateMult")
	return (type(m) == "number" and m > 0) and m or 1
end

--- How long a keypress waits for the server's answer before it takes the arms back: CRYO_WINDUP_WAIT's rule, a high
--- ping is not a refusal.
local function heardWait()
	local ping = 0
	pcall(function()
		ping = player:GetNetworkPing()
	end)
	return math.max(0.6, 2 * ping + 0.3)
end

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

----------------------------------------------------------------------------------------------------
-- playing
----------------------------------------------------------------------------------------------------
-- The two-arm clip this module last started, and its clock -- so DartMayStart can tell how far into it the arms are.
local vmNow = nil       -- { Name, Clock }

local function vmPlay(name, clock)
	local VM = need("Viewmodel")
	if not (VM and VM.Clips and VM.Clips[name]) then
		warnOnce("vm" .. name, "Viewmodel.Clips." .. name .. " is missing: install viewmodel_umbra_clips")
		return
	end
	local start = os.clock()
	VM.Play(name, clock)
	vmNow = { Name = name, Clock = clock or function() return os.clock() - start end }
end

local function vmStopIf(name)
	local VM = need("Viewmodel")
	if VM and VM.CurrentClip() == name then VM.Stop() end
end

local function bodyPlay(character, name, clock)
	local CP = need("CastPose")
	if not (CP and isModel(character)) then return end
	if not (CP.Clips and CP.Clips[name]) then
		warnOnce("cp" .. name, "CastPose.Clips." .. name .. " is missing: install castpose_umbra_clips")
		return
	end
	if clock then
		CP.PlayClocked(character, name, clock)
	else
		CP.Play(character, name)
	end
end

local function bodyStopIf(character, name)
	local CP = need("CastPose")
	if CP and isModel(character) and CP.CurrentClip(character) == name then CP.Stop(character) end
end

----------------------------------------------------------------------------------------------------
-- M1: SHADOW DART
----------------------------------------------------------------------------------------------------
--- The click to the release, in real seconds, for this body now: Windup (OWNER 2.3) over ShotTimeScale and M1RateMult,
--- so ~1.53 s under Eclipse. The arms' clip (Trigger = Windup) reaches its release on exactly this beat.
function UmbraAnim.DartChargeTime(character)
	return T.ShadowDart.Windup / (shotScale() * rateMult(character))
end

--- The click (UmbraClient.FireM1): the arms' 2.3 s charge, on a clock running ShotTimeScale x M1RateMult fast. The
--- multiplier is read ONCE, at the click: a dart charged as Eclipse ends finishes at the speed it started. Returns the
--- real seconds to the release.
function UmbraAnim.LocalDartCharge(character)
	local k = shotScale() * rateMult(character)
	local t0 = os.clock()
	vmPlay("UmbraShadowDart", function()
		return (os.clock() - t0) * k
	end)
	return T.ShadowDart.Windup / k
end

-- How far into each two-arm Umbra clip a new dart may take the arms (clip seconds): "Trigger" is the clip's own
-- Trigger, the dart's release -- its recovery is what a FireInterval (2.6) shorter than the clip (2.8) cuts. The
-- others: the open once it has settled, the step once the arms are rising, the peel once it is held. The Eclipse
-- charge is not here: no dart while the Ultimate is being pressed.
local CUT_FROM = {
	UmbraShadowDart = "Trigger",
	UmbraEclipseOpen = 0.32,
	UmbraShadowStep = 0.30,
	UmbraDecoyDouble = 0.28,
	UmbraDecoyDoubleL = 0.28,
}

--- FireM1's arms gate, in place of `Viewmodel.IsPlaying()`: may a Shadow Dart start now?
function UmbraAnim.DartMayStart()
	local VM = need("Viewmodel")
	if not VM then return true end
	if VM.Tracing() then return false end
	if not VM.IsPlaying() then return true end
	local cur = VM.CurrentClip()
	local cut = cur and CUT_FROM[cur]
	if cut == nil or not vmNow or vmNow.Name ~= cur then return false end
	if cut == "Trigger" then cut = (VM.Clips[cur] and VM.Clips[cur].Trigger) or math.huge end
	local ok, t = pcall(vmNow.Clock)
	return ok and type(t) == "number" and t >= cut
end

-- Every body's charge, anchored so the release can move it without restarting the clip: clip time = Offset +
-- (now - Base) * K. Weak keys: a body that is gone takes its anchor with it.
local dartBody = setmetatable({}, { __mode = "k" })

local function dartClock(a)
	return function()
		return a.Offset + (os.clock() - a.Base) * a.K
	end
end

-- ShadowDartCharge (NEW): the accepted click. Every body -- the shooter's own too -- plays the whole charge.
local function onDartCharge(d)
	local c = d.Character
	if not isModel(c) then return end
	local mult = (type(d.Mult) == "number" and d.Mult > 0) and d.Mult or rateMult(c)
	local a = { Base = os.clock(), Offset = 0, K = shotScale() * mult }
	dartBody[c] = a
	bodyPlay(c, "UmbraShadowDart", dartClock(a))
end

-- ShadowDart: the release, as the server heard it. A body already charging is RE-ANCHORED on its release key (the
-- same play: the arm snaps as the dart appears here, whatever the two clocks drifted); a body with no charge playing
-- (the server does not send ShadowDartCharge yet, or it was lost) plays from the release on -- the snap and the
-- follow-through, which is what the dart's broadcast has always been able to show.
local function onDartRelease(d)
	local c = d.Character
	if not isModel(c) then return end
	local CP = need("CastPose")
	local W = T.ShadowDart.Windup
	local a = dartBody[c]
	if a and CP and CP.CurrentClip(c) == "UmbraShadowDart" then
		a.Base, a.Offset = os.clock(), W
		return
	end
	a = { Base = os.clock(), Offset = W, K = shotScale() * rateMult(c) }
	dartBody[c] = a
	bodyPlay(c, "UmbraShadowDart", dartClock(a))
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: MARK
----------------------------------------------------------------------------------------------------
-- The keypress: the left arm points (an arm shot, so a dart charging on the right is left alone). A press the server
-- turns away (nobody to mark: its precheck refuses in silence) has still pointed -- 0.36 s, and it spent nothing.
UmbraAnim.LocalCast.Mark = function()
	local VM = need("Viewmodel")
	if not (VM and VM.ArmClips and VM.ArmClips.UmbraMark) then
		warnOnce("vmMark", "Viewmodel.ArmClips.UmbraMark is missing: install viewmodel_umbra_clips")
		return
	end
	VM.PlayShot("L", "UmbraMark")
end

-- MarkApplied: the marker's body points, on every client (the marker's own for the third-person view).
local function onMarkApplied(d)
	bodyPlay(d.Character, "UmbraMark")
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: SHADOW STEP
----------------------------------------------------------------------------------------------------
-- A step's clip time runs in real time (scaled) up to just inside its re-form key (0.12, = DissolveTime and the end of
-- the viewmodel's HideArms window), HOLDS there until the body has really been moved, and runs on from there. So the
-- first-person arms stay gone until the view has jumped (keypress + round trip + DissolveTime, not a fixed 0.12), and a
-- body re-forms where it now stands, never at the old spot. "Moved" is the root within LAND_NEAR of the broadcast's To
-- (MinDistance is 4, so the old spot never counts); ShadowStepIn only shortens the wait for that to a CFrame's
-- replication (IN_GRACE); and every hold gives up (GiveUpAt): a refused step (nowhere to go, given back in silence) or
-- a body the server never moved comes back where it is.
local STEP_AT = 0.12
local HOLD_AT = STEP_AT - 1e-3
local LAND_NEAR = 2
local IN_GRACE = 0.15

local function stepClock(s)
	return function()
		local now = os.clock()
		if not s.LandedAt then
			if (s.Landed and s.Landed()) or now >= s.GiveUpAt then s.LandedAt = now end
		end
		if s.LandedAt then
			local at = math.min((s.LandedAt - s.Base) * s.K, HOLD_AT)
			return at + (now - s.LandedAt) * s.K
		end
		return math.min((now - s.Base) * s.K, HOLD_AT)
	end
end

local function nearTo(s, model)
	return function()
		local root = rootOf(model)
		return root ~= nil and typeof(s.To) == "Vector3" and (root.Position - s.To).Magnitude < LAND_NEAR
	end
end

local ownStep = nil                                      -- the last keypress's step
local bodyStep = setmetatable({}, { __mode = "k" })       -- [character] = its step, from ShadowStepOut

UmbraAnim.LocalCast.ShadowStep = function(character)
	local now = os.clock()
	local s = { Base = now, K = shotScale(), GiveUpAt = now + heardWait() }
	s.Landed = nearTo(s, character)
	ownStep = s
	vmPlay("UmbraShadowStep", stepClock(s))
end

function UmbraAnim.OwnStepLandedAt()
	return ownStep and ownStep.LandedAt or nil
end

local function onStepOut(d)
	local c = d.Character
	if not isModel(c) then return end
	local now = os.clock()
	local dissolve = (type(d.Dissolve) == "number" and d.Dissolve) or (T.ShadowStep.DissolveTime / shotScale())
	-- this client's own keypress: now it is real, and it knows where the body is going
	local own = ownStep
	if c == player.Character and own and not own.LandedAt and now - own.Base < heardWait() + 0.5 then
		own.To = d.To
		own.GiveUpAt = now + dissolve + 0.6
	end
	local s = { Base = now, K = shotScale(), To = d.To, GiveUpAt = now + dissolve + 0.6 }
	s.Landed = nearTo(s, c)
	bodyStep[c] = s
	bodyPlay(c, "UmbraShadowStep", stepClock(s))
end

local function onStepIn(d)
	local c = d.Character
	if not isModel(c) then return end
	local now = os.clock()
	local function heard(s)
		if not s or s.LandedAt then return end
		if typeof(d.At) == "Vector3" then s.To = d.At end
		s.GiveUpAt = math.min(s.GiveUpAt, now + IN_GRACE)
	end
	heard(bodyStep[c])
	if c == player.Character then heard(ownStep) end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: ECLIPSE
----------------------------------------------------------------------------------------------------
-- The keypress presses the mass (a held clip); the open plays on the server's EclipseStart. With the server change asked
-- for (EclipseCharge on the cast, EclipseStart WindupTime later) the press is held through the whole telegraph; without
-- it EclipseStart IS the cast, so the press lasts a round trip and opens -- a squeeze and a spread, matching the
-- mechanics, which are live from that moment.
local eclipsePress = nil                                 -- { At, Heard } for the last keypress
local chargeToken = setmetatable({}, { __mode = "k" })   -- [character] = the charge a backstop may let go of

UmbraAnim.LocalCast.Eclipse = function()
	local p = { At = os.clock(), Heard = false }
	eclipsePress = p
	vmPlay("UmbraEclipseCharge")
	-- no answer: the cast was refused (the charge not ready, a cast the server turned away) -- the arms come home
	task.delay(heardWait(), function()
		if p.Heard or eclipsePress ~= p then return end
		vmStopIf("UmbraEclipseCharge")
	end)
end

local function onEclipseCharge(d)
	local c = d.Character
	if not isModel(c) then return end
	bodyPlay(c, "UmbraEclipseCharge")
	if c == player.Character then
		if eclipsePress then eclipsePress.Heard = true end
		local VM = need("Viewmodel")
		if VM and VM.CurrentClip() ~= "UmbraEclipseCharge" then vmPlay("UmbraEclipseCharge") end
	end
	-- backstop: a press no open ever follows (the caster gone mid-windup, a lost EclipseStart) lets go in time
	local token = {}
	chargeToken[c] = token
	task.delay(T.Eclipse.WindupTime / shotScale() + heardWait() + 0.5, function()
		if chargeToken[c] ~= token then return end
		chargeToken[c] = nil
		bodyStopIf(c, "UmbraEclipseCharge")
		if c == player.Character then vmStopIf("UmbraEclipseCharge") end
	end)
end

local function onEclipseStart(d)
	local c = d.Character
	if not isModel(c) then return end
	chargeToken[c] = nil
	bodyPlay(c, "UmbraEclipseOpen")
	if c == player.Character then
		if eclipsePress then eclipsePress.Heard = true end
		vmPlay("UmbraEclipseOpen")
	end
end

local function onEclipseEnd(d)
	local c = d.Character
	if not isModel(c) then return end
	-- a windup cut short (a recast, a death, a round reset) must not leave the hands pressed together
	chargeToken[c] = nil
	bodyStopIf(c, "UmbraEclipseCharge")
	if c == player.Character then vmStopIf("UmbraEclipseCharge") end
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: DECOY DOUBLE
----------------------------------------------------------------------------------------------------
-- The copy stands on Umbra's RIGHT (UmbraHandler.castDecoy: RightVector * Offset), unless a wall is there, when it goes
-- on the LEFT -- and the cue's arm opens toward it. The keypress PREDICTS the side with the server's own test (a ray from
-- the root, Offset + 1 studs to the right, through bodies, stopped by anything that collides and by a Bulwark Wall);
-- every body reads it off the broadcast's At.
local function predictDecoySide(character)
	local root = rootOf(character)
	if not root then return "R" end
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	local V = need("VFXLibrary")
	local fx = workspace:FindFirstChild((V and V.Config and V.Config.FXFolderName) or "IceMagicFX")
	if fx then exclude[#exclude + 1] = fx end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = exclude
	local dir = root.CFrame.RightVector * (T.DecoyDouble.Offset + 1)
	for _ = 1, 8 do
		local hit = workspace:Raycast(root.Position, dir, params)
		if not hit then return "R" end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) or model:GetAttribute("WallOwner") then return "L" end
		params:AddToFilter(model)
	end
	return "R"
end

local function decoySide(owner, at)
	local root = rootOf(owner)
	if not (root and typeof(at) == "Vector3") then return "R" end
	return ((at - root.Position):Dot(root.CFrame.RightVector) < 0) and "L" or "R"
end

UmbraAnim.LocalCast.DecoyDouble = function(character)
	vmPlay(predictDecoySide(character) == "L" and "UmbraDecoyDoubleL" or "UmbraDecoyDouble")
end

local function onDecoySpawn(d)
	local owner = d.Owner
	if isModel(owner) then
		bodyPlay(owner, decoySide(owner, d.At) == "L" and "UmbraDecoyDoubleL" or "UmbraDecoyDouble")
	end
	local P = need("UmbraDecoyPoser")
	if P and isModel(d.Decoy) then P.Pose(d.Decoy) end
end

----------------------------------------------------------------------------------------------------
-- the listener
----------------------------------------------------------------------------------------------------
local HANDLERS = {
	ShadowDartCharge = onDartCharge,
	ShadowDart = onDartRelease,
	MarkApplied = onMarkApplied,
	ShadowStepOut = onStepOut,
	ShadowStepIn = onStepIn,
	EclipseCharge = onEclipseCharge,
	EclipseStart = onEclipseStart,
	EclipseEnd = onEclipseEnd,
	DecoySpawn = onDecoySpawn,
}

local started = false

--- Once, on the client. Its own OnClientEvent connection, alongside AbilityFX's: a RemoteEvent fires every connection,
--- so the VFX handlers and these never have to know about each other.
function UmbraAnim.Start()
	if started then return end
	started = true
	local P = need("UmbraDecoyPoser")
	if P then P.Start() end
	task.spawn(function()
		local remote = iceFolder:WaitForChild("IceAbilityRemote", 30)
		if not remote then
			warnOnce("remote", "IceAbilityRemote not found: no Umbra body animations will play")
			return
		end
		remote.OnClientEvent:Connect(function(action, kind, data)
			if action ~= "VFX" then return end
			local fn = HANDLERS[kind]
			if not (fn and type(data) == "table") then return end
			task.spawn(function()
				local ok, err = pcall(fn, data)
				if not ok then warnOnce("h" .. kind, kind .. " failed: " .. tostring(err)) end
			end)
		end)
	end)
end

return UmbraAnim
