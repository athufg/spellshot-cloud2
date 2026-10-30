--[[
	VoltaicClient  (ModuleScript)  ->  ReplicatedStorage/IceMagic/VoltaicClient

	Voltaic's client half (2026-09-25, the castable pass; the AquaClient pattern). VoltaicHandler is the server; ChainBoltFX,
	OverchargeFX, RailspikeFX, VoltOrbFX and VoltaicFX (Cascade) draw; this module is what a client DOES. Two scripts require
	it and share the one copy a client has:

	  SpellshotInput  Bind (its own gates: flash, canCast, aimPoint, blockedByMovement), FireM1 (the Chain Bolt branch of
	                  fireShard), TryCast (Overcharge's dash, ahead of the generic path) and LocalCast (the arms on the
	                  keypress for Railspike, Volt Orb and Cascade, merged into its LOCAL_CAST).
	  AbilityFX       Handlers: every Voltaic broadcast (and StatusDischarge, which had no handler), drawn for every
	                  character. What the local caster already drew on its own click or key is skipped for that body.

	CHAIN BOLT (M1) is HITSCAN: the click is the shot. The arm thrusts (Icicle Shard's borrowed shot, cosmetic, no
	onRelease), a 0.865-radius sphere is cast 10 studs from the eye down the crosshair, the claim goes to the server
	("ChainBoltFire") and leg 1 is drawn at once from the muzzle to the claimed point (ChainBoltFX.FireLocal). The server
	checks it, chains it and broadcasts ChainBolt; the chained legs are drawn from that. Any M1 fired while primed spends
	the prime, so the primed tell ends on this click (predicted), not a round trip later.

	OVERCHARGE (Primary) is Bulwark Charge's dash (tryBulwarkCharge): DashMotor moves the body, and on the dash's first
	frame the cast goes out with where it started ({Start, Dir, Dist}) and the dash look is drawn HERE, on that frame, from
	those numbers -- everyone else draws it from the broadcast. The primed tell is predicted: TellDelay after the dash
	started, IF this client has heard its own Overcharge broadcast by then (else the moment it does). An M1 fired before
	the tell shows still spends it.

	RAILSPIKE (Technique) is a fixed ChargeTime windup on a press. The key starts the arms (RailspikeSurge: both arms out
	at shoulder height, well apart -- the viewmodel's and the body's) and the charge look; at ChargeTime -- but never before the server's own RailspikeChargeStart for this body has come
	back -- the eye's ray is cast through every body in the line to the first wall, the claim goes out ("RailspikeFire")
	and the shot is drawn from it here. Unanswered within twice the round trip (+0.3 s), the windup is dropped and the slot
	flashes; a death, a respawn, an interrupt or the server's RailspikeChargeStop drops it too.

	VOLT ORB (Technique): hold the key to aim (the arc, VOLT ORB AIM below), the throw on release (Fireball's arm shot,
	borrowed; 2026-10-19, audit P5D-18) and the orb's windup in the hand; the flight
	is the server's VoltOrbThrow. CASCADE (Ultimate): its own summon (CascadeSummon: both arms overhead; the hands
	are CascadeFX's, from the server's CascadeGather). Both flash the slot when the server never
	answers (a refused Volt Orb, a Cascade with no ground -- its charge is given back).

	LOAD-TIME SAFETY. SpellshotInput requires this on its load path, so NOTHING here waits at require time: every other
	module (VFXLibrary, Viewmodel, CastPose, Config, DashMotor, the FX modules, VoltaicTuning, VoltaicKit) is required
	lazily through need(), which never waits on the input path (FindFirstChild; the background preload below is the only
	place with a WaitForChild, and it has a timeout). A missing or broken module warns once and that part degrades.
	Every clip this kit borrows is checked by name once, in the background, with a warn only (a dedicated clip pass is
	still to come).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local VoltaicClient = {}
VoltaicClient.LocalCast = {}
VoltaicClient.Handlers = {}

----------------------------------------------------------------------------------------------------
-- lazy modules (never a wait on the input path)
----------------------------------------------------------------------------------------------------
-- Where each module lives: IceMagic (this module's own folder) or Spellshot.
local WHERE = {
	VFXLibrary = "IceMagic", Viewmodel = "IceMagic", CastPose = "IceMagic", PyroFX = "IceMagic",
	VoltaicTuning = "IceMagic", VoltaicKit = "IceMagic", VoltaicFX = "IceMagic",
	ChainBoltFX = "IceMagic", OverchargeFX = "IceMagic", RailspikeFX = "IceMagic", VoltOrbFX = "IceMagic",
	SpellshotConfig = "Spellshot", DashMotor = "Spellshot",
}

local mods = {}              -- [name] = the module table once required
local failed = {}            -- [name] = true (require errored: never retried) or os.clock() of the last miss (retried)
local warnedAt = {}          -- [key] = os.clock() of the last warn for it

local function warnEvery(key, msg, every)
	local now = os.clock()
	local last = warnedAt[key]
	if last and (every == nil or now - last < every) then return end
	warnedAt[key] = now
	warn("[VoltaicClient] " .. msg)
end

local function folderOf(where, wait)
	if where == "IceMagic" then
		local parent = script.Parent
		if parent and parent.Name == "IceMagic" then return parent end
	end
	return ReplicatedStorage:FindFirstChild(where) or (wait and ReplicatedStorage:WaitForChild(where, wait)) or nil
end

--- The module `name`, required on first use. `wait` (seconds) is only ever passed off the input path.
local function need(name, wait)
	local m = mods[name]
	if m then return m end
	local f = failed[name]
	if f == true then return nil end
	if f and not wait and os.clock() - f < 2 then return nil end   -- a miss is looked for again every 2 s, not every call
	local folder = folderOf(WHERE[name] or "IceMagic", wait)
	local inst = folder and (folder:FindFirstChild(name) or (wait and folder:WaitForChild(name, wait))) or nil
	if not inst then
		failed[name] = os.clock()
		warnEvery("missing:" .. name, name .. " is not in " .. tostring(WHERE[name] or "IceMagic") .. " (yet): that part is skipped")
		return nil
	end
	local ok, res = pcall(require, inst)
	if not ok or type(res) ~= "table" then
		failed[name] = true
		warnEvery("broken:" .. name, name .. " failed to load: " .. tostring(res))
		return nil
	end
	failed[name] = nil
	mods[name] = res
	return res
end

--- Call `name`.`fn`(...) guarded: a missing function or an error in it warns (rate-limited) and returns nil.
local function fx(name, fn, ...)
	local m = need(name)
	local f = m and m[fn]
	if type(f) ~= "function" then
		if m then warnEvery("nofn:" .. name .. "." .. fn, name .. "." .. fn .. " does not exist") end
		return nil
	end
	local ok, a, b = pcall(f, ...)
	if not ok then
		warnEvery("err:" .. name .. "." .. fn, name .. "." .. fn .. " errored: " .. tostring(a), 5)
		return nil
	end
	return a, b
end

--- OverchargeFX.Release (the primed shot's release beat), only when the loaded OverchargeFX has it: an older build
--- without it is skipped silently.
local function overchargeRelease(...)
	local m = need("OverchargeFX")
	if not (m and type(m.Release) == "function") then return end
	fx("OverchargeFX", "Release", ...)
end

-- VoltaicTuning's client-side numbers, used only until the module is there (a place without it still plays)
local FALLBACK = {
	ChainBolt = { Range = 55, --[[30 until 2026-10-18 (handoff #7); 10 until earlier that day]] HitRadius = 0.865 },
	Overcharge = { Distance = 11, Time = 0.16, MaxTime = 0.30, MinCap = 16, --[[12 until the 2026-10-17 balance pass]] ThroughCharacters = true,
		PrimedFor = 6.0, TellDelay = 0.23 },
	Railspike = { ChargeTime = 0.55, Range = 90, MaxPierce = 6 },
}
local function tune(section)
	local T = need("VoltaicTuning")
	local s = T and T[section]
	if type(s) == "table" then return s end
	return FALLBACK[section] or {}
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function serverNow()
	return workspace:GetServerTimeNow()
end

local function timeScale()
	local V = need("VFXLibrary")
	local ok, s = pcall(function() return V and V.ShotTimeScale() end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

--- The frame this client's shots leave from: the eye, even in the third-person testing view (SpellshotInput.aimCF).
local function aimCF()
	local V = need("VFXLibrary")
	local fn = V and V.LocalAimCFrame
	local ok, cf = false, nil
	if type(fn) == "function" then ok, cf = pcall(fn) end
	return (ok and typeof(cf) == "CFrame") and cf or workspace.CurrentCamera.CFrame
end

--- Your own shots pass through yourself, the camera, the FX and everyone you may not hurt (Config.MayHurt).
local function ownExclude(character)
	local list = { character, workspace.CurrentCamera }
	local V = need("VFXLibrary")
	local fxName = V and V.Config and V.Config.FXFolderName or "IceMagicFX"
	local folder = workspace:FindFirstChild(fxName)
	if folder then list[#list + 1] = folder end
	local Config = need("SpellshotConfig")
	if Config and type(Config.AddUnhurtable) == "function" then
		pcall(Config.AddUnhurtable, list, player)
	end
	return list
end

local function iceRemote()
	local folder = folderOf("IceMagic")
	return folder and folder:FindFirstChild("IceAbilityRemote") or nil
end

local function castRemote()
	local folder = folderOf("Spellshot")
	return folder and folder:FindFirstChild("CastRequest") or nil
end

--- A high ping is not a refusal: an answer is waited for twice the round trip on top (SpellshotInput's rule).
local function heardWait()
	local ok, ping = pcall(function() return player:GetNetworkPing() end)
	return math.max(0.6, 2 * ((ok and ping) or 0) + 0.3)
end

--- The third-person body clip (CastPose), for every body: its RestartGuard keeps a second ask from restarting it.
local function pose(character, clip)
	if typeof(character) ~= "Instance" then return end
	fx("CastPose", "Play", character, clip)
end

--- Stop a handle an FX module gave back (method or closure style). True when it had a way to stop.
local function stopHandle(h)
	if type(h) ~= "table" then return false end
	local f = h.Stop or h.Destroy
	if type(f) ~= "function" then return false end
	local ok, err = pcall(f, h)
	if not ok then warnEvery("handle", "stopping an FX handle errored: " .. tostring(err), 5) end
	return true
end

--- The first-person clip `name` is playing (nil-safe).
local function clipIs(name)
	local VM = need("Viewmodel")
	if not VM then return false end
	local ok, cur = pcall(VM.CurrentClip)
	return ok and cur == name
end

--- Whether `character` may act right now, as CombatCore.CanAct asks it (alive, not underground, no round-reset lock,
--- no interrupt) -- the server stops a Railspike windup on exactly this.
local function mayAct(character)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (hum and hum.Health > 0 and character.Parent) then return false end
	if character:GetAttribute("Burrowed") then return false end
	if player:GetAttribute("CastLocked") then return false end
	if serverNow() < (character:GetAttribute("InterruptedUntil") or 0) then return false end
	return true
end

-- Records of what this client drew itself, so the matching broadcast does not draw it twice: os.clock() stamps, the
-- oldest taken first; one older than `life` is dropped (its broadcast never came -- a refused claim).
local function takeRecent(list, life)
	local now = os.clock()
	while list[1] and now - list[1] > life do table.remove(list, 1) end
	if list[1] then
		table.remove(list, 1)
		return true
	end
	return false
end

local ownBolts = {}          -- Chain Bolt leg 1 drawn on the click
local ownDashes = {}         -- Overcharge's dash look drawn on the dash's first frame
local ownRails = {}          -- Railspike shots drawn on the fire

----------------------------------------------------------------------------------------------------
-- Bind: SpellshotInput's own gates
----------------------------------------------------------------------------------------------------
local bound = nil            -- { Flash, CanCast, AimPoint, BlockedByMovement }

function VoltaicClient.Bind(fns)
	if type(fns) ~= "table" then return end
	bound = {
		Flash = type(fns.Flash) == "function" and fns.Flash or nil,
		CanCast = type(fns.CanCast) == "function" and fns.CanCast or nil,
		AimPoint = type(fns.AimPoint) == "function" and fns.AimPoint or nil,
		BlockedByMovement = type(fns.BlockedByMovement) == "function" and fns.BlockedByMovement or nil,
	}
end

local function flash(role, denied)
	if bound and bound.Flash and role then pcall(bound.Flash, role, denied) end
end

----------------------------------------------------------------------------------------------------
-- OVERCHARGE's prime, as this client sees its own
----------------------------------------------------------------------------------------------------
-- own = { Press, Character, StartedAt, TellAt, Until, HeardBy, Heard, Shown, Consumed, Cancelled }: the last dash this
-- client started. HeardBy: when an unanswered dash counts as refused. Heard: its Overcharge broadcast came back. Consumed: an M1 has spent it here (the server spends it on the same
-- shot). Cancelled: the server said it is over (OverchargePrimed Off), or the body is gone.
local own = nil
local ownPress = 0

local function showOwnTell(press)
	local o = own
	if not o or o.Press ~= press or not o.Heard or o.Shown or o.Consumed or o.Cancelled then return end
	if player.Character ~= o.Character or os.clock() > o.Until then return end
	o.Shown = true
	fx("OverchargeFX", "SetPrimed", o.Character, true)
end

--- Whether `character` (this client's) is primed now: the server's attribute, the tell on screen, or a dash of its own
--- whose prime has not been spent or ended yet (the attribute is a round trip behind the dash).
local function ownPrimed(character)
	local untilT = character:GetAttribute("VoltPrimedUntil") or player:GetAttribute("VoltPrimedUntil")
	if type(untilT) == "number" and untilT > serverNow() then return true end
	local ofx = mods.OverchargeFX
	if ofx and type(ofx.IsPrimed) == "function" then
		local ok, on = pcall(ofx.IsPrimed, character)
		if ok and on then return true end
	end
	-- a dash not yet heard counts only until an answer is overdue: past HeardBy with no Overcharge broadcast the server
	-- refused it (mana, CastLocked, Burrowed, a Hub race, or VoltaicHandler's GiveBack) and nothing was primed. A late
	-- broadcast still sets Heard, and counts again from then.
	local o = own
	if o == nil or o.Character ~= character or o.Consumed or o.Cancelled then return false end
	if not o.Heard and os.clock() > (o.HeardBy or 0) then return false end
	return os.clock() < o.Until
end

----------------------------------------------------------------------------------------------------
-- M1: CHAIN BOLT
----------------------------------------------------------------------------------------------------
local nextSide = "R"

--- SpellshotInput's fireShard hands every click here first: false unless the M1 is Chain Bolt. The click is spent
--- (true) even when a two-handed cast holds it off, as every other M1's is.
function VoltaicClient.FireM1(character, ability)
	if type(ability) ~= "table" or ability.Id ~= "ChainBolt" then return false end
	if not (character and character.Parent) or player.Character ~= character then return true end
	local VM = need("Viewmodel")
	local C = tune("ChainBolt")

	-- a two-handed cast owns the arms
	if VM and VM.Tracing() then return true end
	if character:GetAttribute("Channeling") then return true end
	if VM and VM.IsPlaying() then return true end
	local side = nextSide
	nextSide = (side == "R") and "L" or "R"
	-- the thrust is cosmetic: the shot is hitscan, and goes on this frame
	if VM then VM.PlayShot(side, "IcicleShard") end

	local camera = workspace.CurrentCamera
	local eye = aimCF().Position
	local dir = camera.CFrame.LookVector
	local range = C.Range or 10
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ownExclude(character)
	local hit = workspace:Spherecast(eye, C.HitRadius or 0.865, dir * range, params)
	local toPos = hit and hit.Position or (eye + dir * range)
	-- what the sphere met: a body (a Humanoid's model, live or not) or the world. Only a LIVE body is predicted as a hit
	-- (the server counts no hit on a dead one and chains nothing from it); geometry is a whiff on a wall
	local hitModel, hitLive = nil, false
	if hit then
		local m = hit.Instance:FindFirstAncestorOfClass("Model")
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		if hum then
			hitModel = m
			hitLive = hum.Health > 0
		end
	end

	-- the PAID cast first (2026-10-19, audit P1-12): the server lets a bolt fire only once its M1 CastRequest has been
	-- accepted and charged (CombatCore.TakePaidM1), and remotes from one client arrive in the order they were sent
	local cast = castRemote()
	if cast then cast:FireServer("M1", { Side = side, Dir = dir }) end
	local remote = iceRemote()
	if remote then
		remote:FireServer("ChainBoltFire", {
			Id = "ChainBolt", Origin = eye, Dir = dir, Side = side,
			Part = hit and hit.Instance or nil, Position = hit and hit.Position or nil,
		})
	else
		warnEvery("noremote", "IceAbilityRemote is missing: the Chain Bolt claim was not sent", 5)
	end

	-- leg 1, this frame, from the hand to what was claimed (the chain comes back in the broadcast)
	local primed = ownPrimed(character)
	local muzzle = eye
	if VM then
		local ok, m = pcall(VM.GetMuzzleCFrame, side)
		if ok and typeof(m) == "CFrame" then muzzle = m.Position end
	end
	table.insert(ownBolts, os.clock())
	-- FireLocal's own fields (ChainBoltFX 1209-1231): Hit = true predicts the impact on the fire frame (the broadcast then
	-- skips it); Wall = true draws a whiff's sparks, which only FireLocal can draw for the caster (Fire's SkipFirst path
	-- has no wall branch). Part is passed only with a live body: FireLocal also predicts a hit on any body Part.
	fx("ChainBoltFX", "FireLocal", character, side, muzzle, toPos, {
		Own = true, Primed = primed,
		Hit = hitLive, Part = hitLive and hit.Instance or nil,
		Wall = hit ~= nil and hitModel == nil, Normal = hit and hit.Normal or nil,
	})

	-- any M1 while primed spends the prime: the tell goes on this frame, not a round trip later
	if primed then
		local o = own
		if o and o.Character == character then o.Consumed = true end
		-- the release on this click, drawn while the tell it spends still stands (it freezes the tendrils' routes)
		overchargeRelease(character, side, muzzle, { toPos }, { Own = true })
		fx("OverchargeFX", "SetPrimed", character, false)
	end

	return true
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: OVERCHARGE (tryBulwarkCharge's shape, SpellshotInput 896-928)
----------------------------------------------------------------------------------------------------
--- SpellshotInput's tryCast hands every press here first: false unless the ability is Overcharge (or before Bind).
function VoltaicClient.TryCast(role, character, ability)
	if not bound then return false end
	if type(ability) ~= "table" or ability.Id ~= "Overcharge" then return false end
	local O = tune("Overcharge")
	local DashMotor = need("DashMotor")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local blocked = bound.BlockedByMovement and bound.BlockedByMovement(role, character)
	local canCast = (bound.CanCast == nil) or bound.CanCast(role, character)
	if not root or not DashMotor or blocked or not canCast or not DashMotor.CanStart(character, O.MinCap) then
		flash(role, true)
		return true
	end
	-- where you face, flattened (Bulwark Charge's rule)
	local look = workspace.CurrentCamera.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
	-- onStarted runs inside DashMotor's own Heartbeat: nothing in it may throw into the motor
	local function onStarted(startPos, dashDir, dist)
		if player.Character ~= character then return end
		-- the dash is under way on this screen; the server hears where it started and which way
		local cast = castRemote()
		if cast then cast:FireServer(role, { Start = startPos, Dir = dashDir, Dist = dist }) end
		flash(role, false)
		local VM = need("Viewmodel")
		if VM then VM.Play("FrostSlide") end
		-- this client's own dash look, on the dash's own frame, from the numbers the server is told (everyone else draws
		-- the same numbers from the broadcast)
		local now = os.clock()
		local scale = timeScale()
		table.insert(ownDashes, now)
		fx("OverchargeFX", "Cast", {
			Character = character, From = startPos, To = startPos + dashDir * dist, T0 = serverNow(), Own = true,
		})
		-- the prime: shown TellDelay after this frame, if the server's Overcharge for it has come back by then
		ownPress += 1
		local press = ownPress
		-- no local tell is owed by the Cast above (Own = true: OverchargeFX 534-538); HeardBy ends the prediction of a
		-- dash the server never answers (ownPrimed)
		own = {
			Press = press, Character = character, StartedAt = now,
			TellAt = now + (O.TellDelay or 0.23) / scale, Until = now + ((O.PrimedFor or 6) + 0.5) / scale,
			HeardBy = now + heardWait(),
		}
		task.delay((O.TellDelay or 0.23) / scale, showOwnTell, press)
	end
	local requested = DashMotor.Request(function(startPos, dashDir, dist)
		local ok, err = pcall(onStarted, startPos, dashDir, dist)
		if not ok then warnEvery("dash", "Overcharge's dash start errored: " .. tostring(err), 5) end
	end, {
		Dir = dir, Distance = O.Distance, Speed = O.Distance / O.Time, MaxTime = O.MaxTime,
		MinCap = O.MinCap, ThroughCharacters = O.ThroughCharacters ~= false,
	})
	if not requested then flash(role, true) end
	return true
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: RAILSPIKE (a fixed windup on a press)
----------------------------------------------------------------------------------------------------
-- rail = { Character, Role, Start, FireAt, GiveUpAt, Heard, Handle, Conn }: this client's windup, from the press to the
-- fire (or its drop)
local rail = nil

--- Let a body go of Railspike's held windup pose (CastPose RailspikeSurge is a Hold clip: nothing else releases it) --
--- only if that is still what it is doing.
local function releaseSurgeBody(c)
	local CP = need("CastPose")
	if typeof(c) ~= "Instance" or not CP or type(CP.CurrentClip) ~= "function" then return end
	local ok, cur = pcall(CP.CurrentClip, c)
	if ok and cur == "RailspikeSurge" then pcall(CP.Stop, c) end
end

local function endRail(r, reason)
	if not r then return end
	if rail == r then rail = nil end
	if r.Conn then
		r.Conn:Disconnect()
		r.Conn = nil
	end
	stopHandle(r.Handle)
	r.Handle = nil
	if r.Fired then return end
	if clipIs("RailspikeSurge") then
		local VM = need("Viewmodel")
		if VM then VM.Stop() end
	end
	-- the body was posed on the press (LocalCast): a drop the server never answered sends no RailspikeChargeStop
	releaseSurgeBody(r.Character)
	if reason == "unanswered" then flash(r.Role, true) end
end

--- The shot: the eye's ray through every body in the line (each once, up to MaxPierce) to the first wall, claimed to the
--- server and drawn here from the claim.
local function fireRail(r)
	local character = r.Character
	local R = tune("Railspike")
	local range = R.Range or 90
	local maxPierce = R.MaxPierce or 6
	local camera = workspace.CurrentCamera
	local eye = aimCF().Position
	local dir = camera.CFrame.LookVector
	local exclude = ownExclude(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local claims, models, points = {}, {}, {}
	local endPos = eye + dir * range
	for _ = 1, maxPierce + 12 do
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(eye, dir * range, params)
		if not hit then break end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if not hum then
			endPos = hit.Position                          -- the world: the rail stops here
			break
		end
		if model:GetAttribute("WallOwner") then
			-- a Bulwark Wall is cover that takes the hit (CombatCore.Blocked): claimed, and the rail stops on it
			if #claims < maxPierce then
				claims[#claims + 1] = { Part = hit.Instance, Position = hit.Position }
				models[#models + 1] = model
				points[#points + 1] = hit.Position
			end
			endPos = hit.Position
			break
		end
		if hum.Health > 0 and #claims < maxPierce then
			claims[#claims + 1] = { Part = hit.Instance, Position = hit.Position }
			models[#models + 1] = model
			points[#points + 1] = hit.Position
		end
		exclude[#exclude + 1] = model                      -- pierce: on through this body
	end
	local dist = math.max(0, (endPos - eye):Dot(dir))

	local remote = iceRemote()
	if remote then
		remote:FireServer("RailspikeFire", { Origin = eye, Dir = dir, Hits = claims, End = endPos })
	else
		warnEvery("noremote", "IceAbilityRemote is missing: the Railspike claim was not sent", 5)
	end
	r.Fired = true
	endRail(r, "fired")
	local VM = need("Viewmodel")
	if VM then
		VM.Stop()                                            -- the held RailspikeSurge
		VM.PlayShot("R", "RailspikeThrow")                   -- both hands drive the surge out (arm shots: the M1 is free)
		VM.PlayShot("L", "RailspikeThrow")
	end
	pose(character, "RailspikeThrow")                        -- the body at once (the third-person view)
	table.insert(ownRails, os.clock())
	fx("RailspikeFX", "Fire", {
		Character = character, Origin = eye, Dir = dir, Dist = dist, Hits = models, Points = points,
		End = endPos, T0 = serverNow(),
	}, { Own = true })
end

local function railStep(r)
	if rail ~= r then
		endRail(r, "replaced")
		return
	end
	local c = r.Character
	if player.Character ~= c or not mayAct(c) then
		endRail(r, "stopped")
		return
	end
	local now = os.clock()
	if r.Heard and now >= r.FireAt then
		fireRail(r)
	elseif not r.Heard and now >= r.GiveUpAt then
		endRail(r, "unanswered")
	end
end

VoltaicClient.LocalCast.Railspike = function(character, role)
	if rail then return end                                -- one windup at a time (the server keeps the first too)
	local R = tune("Railspike")
	local scale = timeScale()
	local now = os.clock()
	local charge = (R.ChargeTime or 0.55) / scale
	local r = {
		Character = character, Role = role, Start = now, FireAt = now + charge,
		GiveUpAt = now + math.max(charge, heardWait()), Heard = false,
	}
	rail = r
	local VM = need("Viewmodel")
	if VM then VM.Play("RailspikeSurge") end
	pose(character, "RailspikeSurge")                        -- the body at once (the third-person view)
	r.Handle = fx("RailspikeFX", "Charge", character, { Own = true, T0 = serverNow() })
	r.Conn = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(railStep, r)
		if not ok then
			warnEvery("railstep", "Railspike windup step errored: " .. tostring(err), 5)
			endRail(r, "error")
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: VOLT ORB, and the ULTIMATE: CASCADE (the arms on the key; everything else is the server's)
----------------------------------------------------------------------------------------------------
-- orb = { Press, Character, Role, Handle, Heard }: the windup in this client's hand until its VoltOrbThrow hands it over
local orb = nil
local orbPress = 0

--- An own windup given up: stopped through its handle, or fizzled when the handle has no way to stop.
local function dropOrb(o)
	if not o then return end
	if orb == o then orb = nil end
	if not stopHandle(o.Handle) and o.Character then
		fx("VoltOrbFX", "Fizzle", { Character = o.Character })
	end
	o.Handle = nil
end

VoltaicClient.LocalCast.VoltOrb = function(character, role)
	if orb and orb.Character == character then dropOrb(orb) end
	local VM = need("Viewmodel")
	if VM then VM.PlayShot("R", "Fireball") end
	orbPress += 1
	local o = { Press = orbPress, Character = character, Role = role, Heard = false }
	orb = o
	o.Handle = fx("VoltOrbFX", "Windup", character, { Own = true, T0 = serverNow() })
	task.delay(heardWait(), function()
		if orb ~= o or o.Heard then return end
		dropOrb(o)
		flash(role, true)                                  -- the server never threw it: nothing was spent
	end)
end

local cascadePress, cascadeHeard = 0, 0

VoltaicClient.LocalCast.Cascade = function(_, role)
	local VM = need("Viewmodel")
	if VM then VM.Play("CascadeSummon") end
	cascadePress += 1
	local press = cascadePress
	task.delay(heardWait(), function()
		if cascadeHeard >= press then return end
		flash(role or "Ultimate", true)                    -- no storm (no ground there): the charge was given back
	end)
end

----------------------------------------------------------------------------------------------------
-- this client's own body: a death, a new body or a new Element ends what it had running
----------------------------------------------------------------------------------------------------
local function endOwn(character, all)
	-- (2026-10-19, audit P5D-10) a death, a new body or a new Element also takes down a Volt Orb aim arc still up (the
	-- key's release may never come); through the module table, as the aim section is declared further down
	if VoltaicClient.AimStop then VoltaicClient.AimStop() end
	if rail then endRail(rail, "ended") end
	if all and orb then dropOrb(orb) end
	local o = own
	if o then
		o.Cancelled = true
		own = nil
		if mods.OverchargeFX then fx("OverchargeFX", "SetPrimed", o.Character, false) end
	end
	if character and mods.OverchargeFX then fx("OverchargeFX", "SetPrimed", character, false) end
end

-- What the server's broadcasts mean for this client's OWN presses (bookkeeping only; the drawing is Handlers'). A
-- listener of its own, so a press is answered even while AbilityFX's merge of Handlers is not in the place yet.
local function onOwnBroadcast(kind, d)
	local c = d.Character
	if c == nil or c ~= player.Character then return end
	if kind == "Overcharge" then
		local o = own
		if o and o.Character == c and not o.Heard then
			o.Heard = true
			if os.clock() >= o.TellAt then showOwnTell(o.Press) end
		end
	elseif kind == "OverchargePrimed" then
		if d.On ~= true and own and own.Character == c then own.Cancelled = true end
	elseif kind == "RailspikeChargeStart" then
		if rail and rail.Character == c then rail.Heard = true end
	elseif kind == "RailspikeChargeStop" then
		if rail and rail.Character == c then endRail(rail, "server") end
	elseif kind == "VoltOrbThrow" then
		if orb and orb.Character == c then orb.Heard = true end
	elseif kind == "CascadeGather" then
		cascadeHeard = cascadePress
	end
end

if player then
	local function watch(character)
		local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if not hum then return end
		hum.Died:Connect(function()
			endOwn(character, true)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		endOwn(nil, true)
		task.spawn(watch, character)
	end)
	if player.Character then task.spawn(watch, player.Character) end
	-- a new Element ends the prime and the windup (the loadout change the server ends them on too)
	player:GetAttributeChangedSignal("Element"):Connect(function()
		endOwn(player.Character, false)
	end)
	-- (2026-10-19, audit P5D-10) alt-tab: the key-up is lost with the focus, so the aim arc goes with it
	game:GetService("UserInputService").WindowFocusReleased:Connect(function()
		if VoltaicClient.AimStop then VoltaicClient.AimStop() end
	end)

	-- off the load path: the own-press listener, the core modules, and the borrowed clips checked by name (warn only)
	task.spawn(function()
		local ice = folderOf("IceMagic", 10)
		local remote = ice and ice:WaitForChild("IceAbilityRemote", 30)
		if remote then
			remote.OnClientEvent:Connect(function(action, kind, data)
				if action ~= "VFX" or type(data) ~= "table" or type(kind) ~= "string" then return end
				local ok, err = pcall(onOwnBroadcast, kind, data)
				if not ok then warnEvery("own", "own-press bookkeeping errored: " .. tostring(err), 5) end
			end)
		else
			warnEvery("noremote", "IceAbilityRemote never appeared: own presses cannot be answered")
		end
	end)
	task.spawn(function()
		local VM = need("Viewmodel", 10)
		local CP = need("CastPose", 10)
		need("VFXLibrary", 10)
		need("SpellshotConfig", 10)
		need("DashMotor", 10)
		local missing = {}
		local function check(tbl, where, names)
			if type(tbl) ~= "table" then
				missing[#missing + 1] = where .. " (the table itself)"
				return
			end
			for _, n in ipairs(names) do
				if tbl[n] == nil then missing[#missing + 1] = where .. "." .. n end
			end
		end
		if VM then
			check(VM.Clips, "Viewmodel.Clips", { "RailspikeSurge", "FrostSlide", "CascadeSummon" })
			check(VM.ArmClips, "Viewmodel.ArmClips", { "IcicleShard", "Fireball", "RailspikeThrow" })
		end
		if CP then
			check(CP.Clips, "CastPose.Clips",
				{ "IcicleShardR", "IcicleShardL", "FrostSlide", "RailspikeSurge", "RailspikeThrow", "FireballR",
					"CascadeSummon" })
		end
		if #missing > 0 then
			warn("[VoltaicClient] borrowed clips missing (those beats play nothing): " .. table.concat(missing, ", "))
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- the broadcasts (AbilityFX hands every Voltaic kind here, and StatusDischarge)
----------------------------------------------------------------------------------------------------
local H = VoltaicClient.Handlers
local otherRails = setmetatable({}, { __mode = "k" })   -- [character] = the charge handle this client started for it

local function isModel(v)
	return typeof(v) == "Instance" and v:IsA("Model")
end

-- Chain Bolt: the body's palm thrust for everyone; the chain for everyone, leg 1 skipped for the shooter who drew it
H.ChainBolt = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local mine = c == player.Character
	pose(c, "IcicleShard" .. ((d.Side == "L") and "L" or "R"))
	if d.Primed == true then
		if mine and own and own.Character == c then own.Consumed = true end
		-- everyone else's release; the shooter drew its own on the click (FireM1), so it is never drawn twice
		if not mine then overchargeRelease(c, d.Side, nil, d.Points, { T0 = d.T0, End = d.End }) end
		fx("OverchargeFX", "SetPrimed", c, false)          -- the primed shot is the tell's end, for everyone
	end
	if typeof(d.Origin) ~= "Vector3" or type(d.Points) ~= "table" then return end
	local skip = mine and takeRecent(ownBolts, 1.0)
	fx("ChainBoltFX", "Fire", d, { SkipFirst = skip, Own = mine })
end

-- Charged's discharge (StatusEffects): the arc from the discharging body to the next, or a zap on itself
H.StatusDischarge = function(d)
	if not isModel(d.From) then return end
	fx("ChainBoltFX", "Discharge", d.From, isModel(d.To) and d.To or nil)
end

-- Overcharge: the body's dash pose for everyone; the dash look for everyone but the dasher who drew it on its frame
H.Overcharge = function(d)
	local c = d.Character
	if not isModel(c) or typeof(d.From) ~= "Vector3" or typeof(d.To) ~= "Vector3" then return end
	pose(c, "FrostSlide")
	if c == player.Character and takeRecent(ownDashes, 1.5) then return end
	fx("OverchargeFX", "Cast", d)
end

H.OverchargePrimed = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local on = d.On == true
	if on and c == player.Character then
		local o = own
		-- this client already spent it (the server's On was sent before it heard the shot), or was told it is over
		if o and o.Character == c and (o.Consumed or o.Cancelled) then return end
		if o and o.Character == c then o.Shown = true end
	end
	fx("OverchargeFX", "SetPrimed", c, on)
end

-- Chain Reaction: a kill refunded Overcharge -- sparks off both hands (bigger when it made the Primary ready)
H.ChainReaction = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local V = need("VFXLibrary")
	if not V then return end
	local Kit = need("VoltaicKit")
	-- (2026-10-19, audit P5D-07) VFXLibrary's `thin` means "somebody else's cast" (it applies Reduce Enemy VFX and the
	-- Graphics Quality density itself); Kit.thin also says yes on LOW for your own, which halved your sparks twice
	-- (2026-10-19, audit P5F-06) ...and only an ENEMY's (VFXLibrary.IsEnemy): a teammate's sparks are not halved either
	local thin = if type(V.IsEnemy) == "function" then V.IsEnemy(c) else c ~= player.Character
	for _, side in ipairs({ "R", "L" }) do
		local pos = nil
		if Kit and type(Kit.muzzle) == "function" then
			local ok, p = pcall(Kit.muzzle, c, side)
			if ok and typeof(p) == "Vector3" then pos = p end
		end
		if not pos then
			local hand = c:FindFirstChild(side == "R" and "RightHand" or "LeftHand")
				or c:FindFirstChild(side == "R" and "Right Arm" or "Left Arm")
			pos = hand and hand.Position
		end
		if pos then
			local ok, err = pcall(V.VoltSparkBurst, pos, Vector3.yAxis, thin, d.Ready and 10 or 6)
			if not ok then warnEvery("err:ChainReaction", "VoltSparkBurst errored: " .. tostring(err), 5) end
		end
	end
end

-- Railspike: the windup (not for the caster, whose own started on the key -- body pose and all), its stop, and the shot
-- (not for the caster, who drew it and posed its body from its own claim; a second play of the same body clip a round
-- trip later would restart it past CastPose's RestartGuard on a slow connection)
H.RailspikeChargeStart = function(d)
	local c = d.Character
	if not isModel(c) then return end
	if rail and rail.Character == c then return end
	-- (2026-10-19, audit P5D-17) our own body with no live local windup: this press was already given up here (its
	-- answer came after GiveUpAt) and cannot fire, so no stuck observer windup is drawn on our hands
	if c == player.Character then return end
	pose(c, "RailspikeSurge")
	stopHandle(otherRails[c])
	otherRails[c] = fx("RailspikeFX", "Charge", c, { Own = c == player.Character, T0 = d.T0 })
end

H.RailspikeChargeStop = function(d)
	local c = d.Character
	if not isModel(c) then return end
	stopHandle(otherRails[c])
	otherRails[c] = nil
	fx("RailspikeFX", "ChargeStop", c)
	releaseSurgeBody(c)
end

H.RailspikeShot = function(d)
	local c = d.Character
	if not isModel(c) then return end
	stopHandle(otherRails[c])
	otherRails[c] = nil
	if c == player.Character and takeRecent(ownRails, 3.0) then return end
	pose(c, "RailspikeThrow")
	if typeof(d.Origin) ~= "Vector3" or typeof(d.Dir) ~= "Vector3" then return end
	fx("RailspikeFX", "Fire", d, { Own = c == player.Character })
end

-- Volt Orb: the throw for everyone (the caster's flight takes over the windup in its hand), the burst and the fizzle
H.VoltOrbThrow = function(d)
	local c = d.Character
	if not isModel(c) or typeof(d.From) ~= "Vector3" or typeof(d.Vel) ~= "Vector3" then return end
	pose(c, "FireballR")
	if orb and orb.Character == c then
		orb.Heard = true
		orb = nil                                          -- VoltOrbFX carries the windup on into the flight
	end
	fx("VoltOrbFX", "Throw", d)
end

H.VoltOrbBurst = function(d)
	if typeof(d.At) ~= "Vector3" then return end
	fx("VoltOrbFX", "Burst", d)
end

H.VoltOrbFizzle = function(d)
	local c = d.Character
	if isModel(c) and orb and orb.Character == c then orb = nil end
	fx("VoltOrbFX", "Fizzle", d)
end

-- Cascade: the point for everyone; the storm, its five strikes and its fade (VoltaicFX)
H.CascadeGather = function(d)
	if typeof(d.Point) ~= "Vector3" then return end
	if isModel(d.Character) then pose(d.Character, "CascadeSummon") end
	fx("VoltaicFX", "CascadeGather", d)
end

H.CascadeStrike = function(d)
	if typeof(d.Point) ~= "Vector3" or typeof(d.At) ~= "Vector3" then return end
	fx("VoltaicFX", "CascadeStrike", d)
end

H.CascadeEnd = function(d)
	fx("VoltaicFX", "CascadeEnd", d)
end

----------------------------------------------------------------------------------------------------
-- VOLT ORB AIM (2026-10-13): while the key is held, a see-through arc shows where the orb will go -- the server's own
-- throw (castVoltOrb: the look to the crosshair point held to Range, pitched up by Lift, clamped to MinElev..MaxElev,
-- from the hand, Speed, Gravity, to the Fuse), stopped at the first thing it would hit, with the blast's radius on the
-- ground there. Letting go throws (SpellshotInput). Local only: parts under the camera, never touched or queried.
----------------------------------------------------------------------------------------------------
local AIM_DOTS, AIM_DT = 28, 0.045
local aimConn, aimParts, aimRing = nil, nil, nil

local function aimClear()
	if aimConn then aimConn:Disconnect() aimConn = nil end
	if aimParts then for _, p in ipairs(aimParts) do p:Destroy() end aimParts = nil end
	if aimRing then aimRing:Destroy() aimRing = nil end
end

local function aimPart(shape, size, transparency)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(170, 130, 255)
	p.Transparency = transparency
	p.Name = "VoltOrbAim"
	p.Parent = workspace.CurrentCamera
	return p
end

--- Start drawing the aim arc; aimTarget() gives the crosshair's world point (SpellshotInput's aimPoint).
function VoltaicClient.AimStart(aimTarget)
	aimClear()
	aimParts = {}
	for i = 1, AIM_DOTS do
		local s = 0.34 - 0.18 * (i - 1) / AIM_DOTS
		aimParts[i] = aimPart(Enum.PartType.Ball, Vector3.new(s, s, s), 0.45)
	end
	aimRing = aimPart(Enum.PartType.Cylinder, Vector3.new(0.08, 1, 1), 0.78)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	aimConn = RunService.RenderStepped:Connect(function()
		local ch = player.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local head = ch and ch:FindFirstChild("Head") or root
		local T = need("VoltaicTuning")
		if not (root and head and T and T.VoltOrb) then return end
		local V = T.VoltOrb
		local target = aimTarget()
		local off = target - root.Position
		local rng = V.Range or 60
		if off.Magnitude > rng then target = root.Position + off.Unit * rng end
		local look = target - head.Position
		look = look.Magnitude > 0.1 and look.Unit or root.CFrame.LookVector
		local across = Vector3.new(look.X, 0, look.Z)
		if across.Magnitude < 0.05 then across = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) end
		across = across.Magnitude > 0.05 and across.Unit or Vector3.new(0, 0, -1)
		local elev = math.clamp(math.asin(math.clamp(look.Y, -1, 1)) + math.rad(V.Lift), math.rad(V.MinElev), math.rad(V.MaxElev))
		local vel = (across * math.cos(elev) + Vector3.yAxis * math.sin(elev)) * V.Speed
		local from = head.Position + CFrame.lookAt(Vector3.zero, across):VectorToWorldSpace(V.HandOffset)
		params.FilterDescendantsInstances = ownExclude(ch)   -- the orb flies through teammates, so the arc does too (2026-10-18 review)
		local last, landed, normal = from, nil, Vector3.yAxis
		local fuse = V.Fuse or 1.25
		for i = 1, AIM_DOTS do
			local t = math.min(fuse, i * fuse / AIM_DOTS)
			local pos = from + vel * t + Vector3.new(0, -0.5 * V.Gravity * t * t, 0)
			if not landed then
				local hit = workspace:Raycast(last, pos - last, params)
				if hit then landed, normal = hit.Position, hit.Normal end
			end
			local p = aimParts[i]
			if landed then
				p.Transparency = 1
			else
				p.Transparency = 0.45
				p.CFrame = CFrame.new(pos)
			end
			last = pos
		end
		local at = landed or last
		local r = (V.DamageRadius or 7.5) * 2
		aimRing.Size = Vector3.new(0.08, r, r)
		aimRing.CFrame = CFrame.lookAt(at + normal * 0.05, at + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
	end)
end

function VoltaicClient.AimStop()
	aimClear()
end

--- (2026-10-19, audit P5D-10) Is the aim arc up? SpellshotInput resets its held Volt Orb role when this is false.
function VoltaicClient.Aiming()
	return aimConn ~= nil
end

return VoltaicClient
