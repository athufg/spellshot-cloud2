--[[
	AltarMoves_Umbra  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Umbra

	The Loadout Altar showcase's Umbra kit, CONTRACT v2 (2026-10-26, the owner: at the altar every move of the Element
	is PERFORMED by a visible caster on a visible target, in the wrap being looked at). Moves = Umbra's six, M1 first:
	{ Key, Name, Slot, Play(stage) -> stop() }. The lead's AltarShowcase builds the stage before Play: stage.Caster (a grey
	R15 mannequin, AllyDummy, 7 studs along -RightVector, facing the target) and stage.Target (7 studs along +RightVector,
	facing the caster), both under workspace.TrainingGround and both left visible. Each Play loops the move's whole
	cast -> hit beat until stop(). Client only: no remotes, no server damage, no hit tests.

	THE BODY. The caster performs with the game's own third-person clips (ReplicatedStorage.IceMagic.CastPose, that one
	instance), played exactly as UmbraAnim plays them off the server's broadcasts (UmbraAnim's handlers are local, so the
	calls are repeated here): UmbraShadowDart on the charge's clock (Trigger = UmbraTuning.ShadowDart.Windup, x
	M1RateMult under Eclipse), UmbraMark, UmbraShadowStep on stepClock (held just short of the re-form until the body has
	moved), UmbraEclipseCharge (Hold) then UmbraEclipseOpen, UmbraDecoyDouble; the decoy copy idles on UmbraDecoyReady,
	looped the way UmbraDecoyPoser loops it. The VFX are UmbraFX's real entry points, called with UmbraClient's payloads
	at the clip's own beats (DartCharge, Dart, Hit, MarkHeadshot, StepOut, DecoyPeel / DecoyBreak, Eclipse, Tell).

	THE TARGET reacts the way a duel shows it (stage.React = AltarStage): React.Hit with the real numbers from
	UmbraTuning -- Shadow Dart 65 (no knockback: the recoil), Unseen x1.25 = 81, the Mark HEADSHOT 65 + HeadBonus[stacks]
	(215 at full), HUNTED! ("hunted") on the mark -- and Eclipse's reveal outline on it while the domain stands.

	THE WRAP. UmbraFX takes its wrap from the caster's PLAYER (wrapOf -> ElementWrap_Umbra), so a mannequin on its own
	always draws Default. But UmbraFX's driver steps every effect with CUR = that effect's Wrap, and run() stamps each
	effect it starts with CUR (UmbraFX's own WRAPS contract). So each preview is clocked by ONE inert carrier effect --
	an UmbraFX.Dart that is never moved, which draws nothing -- whose Wrap is the wrap's Palette and whose Step is this
	preview's clock: every entry point it calls is built, and every effect it starts is stepped, under the wrap. Only the
	Mark marker and the Eclipse reveal (UmbraClient's / UmbraFX's local-player code) are mirrored here, in the wrap's
	colours. No wrap, an unknown id or another Element's wrap: Default (warned once). (2026-10-26) The wrap is
	AltarStage.Look's: over a skin (stage.Skin; Umbra has none yet) only a wrap SkinCatalog lets over one, which no
	Umbra wrap is -- so no palette rides the carrier and the skin the caster wears (ShowcaseSkin) keeps its look.
	Swept for what a cast needs that a dummy lacks: nothing new -- the marker and the reveal (local-player code) are
	mirrored here already, the double is posed by hand, the step's hide is done here.

	WHAT EACH PLAYS (R = stage.CF.RightVector, the caster -> target axis):
	  Shadow Dart   the 2.3 s charge on the caster's right hand, the release (the Tell), the dart into the target's
	                chest, the hit's curls; the target takes 65 and recoils.                                  every 3.6 s
	  Shadow Step   the cue, the unravel, the re-form 2.5 studs short of the target (stepDestination's AimPad); a
	                turn, the second charge's blink back home, a turn back to the target.                     every 3.0 s
	  Mark          the left arm points: the marker over the target's head + HUNTED!; it ripens 1 -> 3 while a dart
	                charges; the HEADSHOT payoff at the head (MarkEnd: the marker goes), 215.                 every 4.2 s
	  Decoy Double  the caster turns to the camera; the double peels off its RIGHT (between it and the target),
	                stands in the Ready idle, takes the target's hit and breaks lit (the Tell); a turn back.  every 3.6 s
	  Eclipse       the held press, the open (vortex, ground wave, pulse, wisps), the target outlined (the reveal),
	                then a 1.5x-quick Shadow Dart into it, unaware: 81. The V4 world grade and the screen layer are
	                left out: they would darken the whole hub and the viewer's screen.                       every 4.5 s
	  Unseen        no look of its own (it is damage): the target turns its back, the dart lands unaware, 81. every 3.6 s
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- the dart's flight speed here (studs/s, x ShotTimeScale): the live dart flies 200 (UmbraTuning ShadowDart.Speed), which
-- crosses this 14-stud stage in 4 frames, too quick to see the braid; 60 shows it for ~13 frames, about what a 30-stud
-- duel shot shows. Set it to T.ShadowDart.Speed for the true pace.
local DART_SHOW_SPEED = 60
local SETTLE = 0.5               -- the first beat waits this long after Play: the caster blends onto the Ready stance
local TURN_TIME = 0.25           -- a body turning to a new facing (anchored: no stride, a turn in place)
local STEP_TURN_AT = 0.95        -- Shadow Step: the caster turns for home this long after the first step...
local STEP_BACK_AT = 1.25        -- ...blinks home on the second charge (EscapeCooldown's, the same key)...
local STEP_FACE_AT = 1.9         -- ...and turns back to the target
local STEP_HOLD_AT = 0.12 - 1e-3 -- UmbraAnim's HOLD_AT: the step clip's re-form key (0.12), held until the body moves
local MARK_DART_AT = 0.4         -- Mark: the dart's click this long after the point (UmbraMark is 0.36 s; full at ~2.1)
local DECOY_HOLD = 2.0           -- Decoy Double: the double stands this long after the cast before it is hit
local DECOY_GONE = 0.35          -- ...and goes this long after its break (UmbraHandler.removeDecoy's beat)
local DECOY_TURN_BACK = 0.55     -- ...and the caster turns back to the target this long after the break
local ECLIPSE_HOLD = 2.6         -- Eclipse: the domain's length after the open (7 s in a duel)
local ECLIPSE_DART_AT = 0.45     -- ...and the Eclipse-quick dart's click this long after the open
local UNSEEN_TURN = 0.4          -- Unseen: the target turns its back over this long, once, at Play

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Umbra] " .. tostring(msg))
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function unitOr(v, fallback)
	if v.Magnitude > 1e-4 then return v.Unit end
	return fallback
end

----------------------------------------------------------------------------------------------------
-- the kit, found once (never at require time: the lead requires this before a stage exists)
----------------------------------------------------------------------------------------------------
local kit = nil
local function loadKit()
	if kit then return kit end
	local ok, res = pcall(function()
		local ice = ReplicatedStorage:WaitForChild("IceMagic", 10)
		local spell = ReplicatedStorage:WaitForChild("Spellshot", 10)
		assert(ice and spell, "ReplicatedStorage.IceMagic / Spellshot missing")
		local UFX = require(ice:WaitForChild("UmbraFX", 10))
		local T = require(ice:WaitForChild("UmbraTuning", 10))
		-- the game's own CastPose instance (a second copy would run its own state and fight it for the joints)
		local okP, CP = pcall(function() return require(ice:WaitForChild("CastPose", 10)) end)
		local okC, SC = pcall(function() return require(spell:WaitForChild("SkinCatalog", 10)) end)
		local okS, ST = pcall(function()
			local m = spell:FindFirstChild("SpellshotSettings")
			return m and require(m)
		end)
		return { UFX = UFX, T = T, Ice = ice, CP = (okP and type(CP) == "table") and CP or nil,
			SC = (okC and type(SC) == "table") and SC or nil, Settings = (okS and type(ST) == "table") and ST or nil }
	end)
	if not ok or type(res) ~= "table" or type(res.UFX) ~= "table" or type(res.T) ~= "table" then
		warnOnce("kit", "UmbraFX / UmbraTuning unavailable, nothing drawn: " .. tostring(res))
		return nil
	end
	if not res.CP then warnOnce("castpose", "CastPose unavailable: the caster stands still, the VFX still play") end
	kit = res
	return kit
end

--- the wrap's Palette block (what UmbraFX's wrapOf returns for a caster wearing it), nil = Default
local function paletteOf(K, wrapId)
	if type(wrapId) ~= "string" or wrapId == "Default" then return nil end
	local Skins = K.SC and K.SC.Skins
	local s = type(Skins) == "table" and Skins[wrapId] or nil
	if type(s) == "table" and s.Wrap == "Umbra" and type(s.Palette) == "table" then return s.Palette end
	warnOnce("wrap:" .. wrapId, "wrap " .. wrapId .. " is not an Umbra wrap: Default drawn")
	return nil
end

--- VFXLibrary.ShotTimeScale(), read the way it reads it (the filming slow-down every Umbra clock carries)
local function shotScale(K)
	local v = K.Ice:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

--- Reduce Flashing, read at most once a second (UmbraFX pulseK's own read, Studio stand-in included)
local rfAt, rfOn = -10, false
local function reduceFlashing(K)
	local now = os.clock()
	if now - rfAt > 1 then
		rfAt = now
		local S = K.Settings
		local ok, v = pcall(function() return S and S.Get and S.Get("ReduceFlashing") end)
		rfOn = (ok and v == true) or (RunService:IsStudio() and workspace:GetAttribute("StudioReduceFlashing") == true)
	end
	return rfOn
end

local function materialOf(name)
	if type(name) ~= "string" then return nil end
	local ok, m = pcall(function() return Enum.Material[name] end)
	return ok and m or nil
end

----------------------------------------------------------------------------------------------------
-- THE RUNNER: one per Play. Its clock is the carrier's Step (inside UmbraFX's driver, under the wrap): the loop's
-- restarts, timed events (at) and per-frame tickers (tick) all run there. Every effect handle it starts (keep) and every
-- instance it makes (made) is ended by stop(), and the dummies go back where the lead stood them.
----------------------------------------------------------------------------------------------------
local function at(R, delay, fn)
	R.Seq += 1
	R.Events[#R.Events + 1] = { At = os.clock() + delay, Seq = R.Seq, Fn = fn }
end
local function tick(R, fn)
	R.Ticks[#R.Ticks + 1] = fn
end
--- how: nil (cut at once), "charge" (DartCharge's own unlit fade), "eclipse" (End's fade, or Cancel in the windup)
local function keep(R, h, how)
	if type(h) == "table" and rawget(h, "Step") ~= nil then R.Handles[#R.Handles + 1] = { H = h, How = how } end
	return h
end
local function made(R, inst)
	R.Made[#R.Made + 1] = inst
	return inst
end

--- a CastPose call on a body, guarded: a pose that fails is warned once and never takes the preview (or its wrap) down
local function pose(R, fn, model, ...)
	local CP = R.CP
	local f = CP and CP[fn]
	if type(f) ~= "function" or typeof(model) ~= "Instance" or not model.Parent then return end
	local ok, err = pcall(f, model, ...)
	if not ok then warnOnce("pose:" .. fn, "CastPose." .. fn .. " failed: " .. tostring(err)) end
end
--- the clip's own number (its Trigger, its LoopLength), or `fallback` with the clip missing
local function clipField(R, clip, field, fallback)
	local c = R.CP and R.CP.Clips and R.CP.Clips[clip]
	local v = type(c) == "table" and c[field] or nil
	return type(v) == "number" and v or fallback
end

--- the target's reaction (AltarStage), guarded the same way
local function react(R, opts)
	local React = R.Stage.React
	if not (type(React) == "table" and type(React.Hit) == "function") then return end
	local ok, err = pcall(React.Hit, R.Stage, opts)
	if not ok then warnOnce("react", "React.Hit failed: " .. tostring(err)) end
end
local function resetDummies(R)
	local React = R.Stage.React
	if type(React) == "table" and type(React.Reset) == "function" then
		local ok, err = pcall(React.Reset, R.Stage)
		if not ok then warnOnce("reset", "React.Reset failed: " .. tostring(err)) end
	end
end

--- where body `m` rests between beats: the pivot the lead stood it on, or the one this move gave it (Unseen's turn)
local function restOf(R, m)
	return (R.Rest[m]) or (R.Homes[m] and R.Homes[m].Pivot)
end
local function home(R, m)
	local cf = restOf(R, m)
	if cf and m.Parent then m:PivotTo(cf) end
end
--- the pivot that stands body `m` with its root over `pos` (its own height kept), facing `face` (flat)
local function standCF(R, m, pos, face)
	local h = R.Homes[m]
	if not h then return nil end
	local p = Vector3.new(pos.X, h.Root.Position.Y, pos.Z)
	return CFrame.lookAt(p, p + flat(face)) * h.Root:ToObjectSpace(h.Pivot)
end
local function stand(R, m, pos, face)
	local cf = standCF(R, m, pos, face)
	R.Turning[m] = nil                                               -- (a turn still running would pull it back)
	if cf and m.Parent then m:PivotTo(cf) end
end
--- turn body `m` in place to face `face` over `dur` (a smoothstep yaw; the next beat or turn cancels it)
local function turnTo(R, m, face, dur)
	local root = m.Parent and m:FindFirstChild("HumanoidRootPart")
	local to = root and standCF(R, m, root.Position, face)
	if not to then return end
	local from = m:GetPivot()
	local token = {}
	R.Turning[m] = token
	local t0 = os.clock()
	tick(R, function(now)
		if R.Turning[m] ~= token or not m.Parent then return false end
		local u = math.clamp((now - t0) / math.max(dur, 1e-3), 0, 1)
		m:PivotTo(from:Lerp(to, u * u * (3 - 2 * u)))
		if u >= 1 then R.Turning[m] = nil end
		return u < 1
	end)
end

--- the caster gone from view and back (UmbraClient's hide: every other client's view of a stepping body)
local function vanish(R, on)
	local m = R.Caster
	if not (m and m.Parent) then return end
	R.Hidden = on
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = on and 1 or 0 end
	end
end

--- the caster let go: every hold, base and aim CastPose may have on it (contract v2's stop)
local function releaseCaster(R)
	local m = R.Caster
	pose(R, "Stop", m)
	pose(R, "SetBase", m, nil)
	pose(R, "SetAim", m, nil)
end

--- between beats: both dummies back to how the lead stood them (React.Reset: home, full health, statuses cleared), the
--- caster visible and on its rest stance, any turn still running cancelled
local function beat(R)
	table.clear(R.Turning)
	resetDummies(R)
	home(R, R.Caster)
	home(R, R.Target)
	if R.Hidden then vanish(R, false) end
	if R.CP and R.Caster.Parent then
		local ok, cur = pcall(R.CP.CurrentClip, R.Caster)
		if ok and cur ~= nil then pose(R, "Stop", R.Caster) end
	end
end

local function endHandle(k)
	local h = k.H
	if h.Dead then return end
	if k.How == "charge" then
		h:Cancel()                                            -- (DartCharge.CancelFade, 0.1 s)
	elseif k.How == "eclipse" and h.OpenAt then
		h:End(os.clock())                                     -- the domain fades...
		task.delay(0.4, function() h.MaxLife = -1 end)         -- ...and is cut before its wisps' last 0.1
	elseif k.How == "eclipse" then
		h:Cancel()                                            -- (Eclipse.CancelFade, 0.2 s)
	else
		h.MaxLife = -1                                        -- the driver stops it next step; its Stop frees everything
	end
end

local function stopRun(R)
	if R.Stopped then return end
	R.Stopped, R.Dead = true, true
	if R.Conn then R.Conn:Disconnect() end
	table.clear(R.Events)
	table.clear(R.Ticks)
	table.clear(R.Turning)
	for _, k in ipairs(R.Handles) do pcall(endHandle, k) end
	table.clear(R.Handles)
	for _, inst in ipairs(R.Made) do pcall(function() inst:Destroy() end) end
	table.clear(R.Made)
	if R.Template then pcall(function() R.Template:Destroy() end) end
	pcall(vanish, R, false)
	pcall(releaseCaster, R)
	for m, h in pairs(R.Homes) do pcall(function() if m.Parent then m:PivotTo(h.Pivot) end end) end
	pcall(resetDummies, R)
	if R.Pump and not R.Pump.Dead then R.Pump.MaxLife = -1 end   -- the carrier frees its (never shown) ball and ribbons
end

--- a failure: warned once; under a wrap the preview falls back to Default from here on
local function failed(R, where, err)
	warnOnce(R.Id .. ":" .. where, R.Id .. " " .. where .. " failed" .. (R.P and " (Default from now on)" or "")
		.. ": " .. tostring(err))
	if R.P then
		R.P = nil
		if R.Pump then R.Pump.Wrap = nil end
	end
end

--- the carrier's Step: CUR is R.P for all of it (the driver set it from the carrier's Wrap)
local function pumpStep(R, now, dt)
	if R.Dead then return false end
	if R.Next > 0 and now >= R.Next then
		R.Next = now + R.Period
		R.Loop += 1
		for i = #R.Handles, 1, -1 do
			if R.Handles[i].H.Dead then table.remove(R.Handles, i) end
		end
		-- a last beat's leftovers (every period outlasts its beat, so normally none): its instances (a marker, a double,
		-- an outline), its pending events and its tickers go before the next beat starts
		for _, inst in ipairs(R.Made) do pcall(function() inst:Destroy() end) end
		table.clear(R.Made)
		table.clear(R.Events)
		table.clear(R.Ticks)
		local okB, errB = pcall(beat, R)
		if not okB then warnOnce(R.Id .. ":beat", R.Id .. " reset failed: " .. tostring(errB)) end
		local ok, err = pcall(R.Cycle, R, R.Loop)
		if not ok then failed(R, "loop", err) end
	end
	if #R.Events > 0 then
		local due, later = {}, {}
		for _, ev in ipairs(R.Events) do
			if ev.At <= now then due[#due + 1] = ev else later[#later + 1] = ev end
		end
		if #due > 0 then
			R.Events = later
			table.sort(due, function(a, b) return a.At < b.At or (a.At == b.At and a.Seq < b.Seq) end)
			for _, ev in ipairs(due) do
				if R.Dead then break end
				local ok, err = pcall(ev.Fn)
				if not ok then failed(R, "event", err) end
			end
		end
	end
	local ticks = R.Ticks
	for i = #ticks, 1, -1 do
		if R.Dead then break end
		local fn = ticks[i]
		local ok, more = pcall(fn, now, dt)
		if not ok then failed(R, "tick", more) end
		if (not ok or more == false) and ticks[i] == fn then table.remove(ticks, i) end
	end
	return not R.Dead
end

--- the carrier: an UmbraFX.Dart with no owner (no wrap of its own) that is never moved, so it never draws
local function startPump(R)
	local ok, c = pcall(R.UFX.Dart, nil)
	if not ok or type(c) ~= "table" or rawget(c, "Step") == nil then return false end
	c.Name = "AltarUmbraClock"
	c.Wrap = R.P
	c.MaxLife = math.huge                                     -- (E.MaxLife would tear it down after 12 s)
	c.Step = function(_, now, dt) return pumpStep(R, now, dt) end
	R.Pump = c
	return true
end

--- `setup(R)` (optional) runs once, when the kit is in and before the first beat: a move's one-time staging (it draws
--- nothing, so it needs no wrap)
local function preview(stage, id, period, cycle, setup)
	local caster = stage.Caster or stage.Key
	local target = stage.Target
	if not (typeof(caster) == "Instance" and typeof(target) == "Instance") then
		warnOnce("nostage:" .. id, id .. ": the stage has no Caster / Target (contract v2): nothing played")
		return function() end
	end
	local R = { Id = id, Stage = stage, Caster = caster, Target = target, Period = period, Cycle = cycle, Dead = false,
		Loop = 0, Next = 0, Seq = 0, Events = {}, Ticks = {}, Handles = {}, Made = {}, Homes = {}, Rest = {}, Turning = {},
		Hidden = false }
	for _, m in ipairs({ caster, target }) do
		local root = m:FindFirstChild("HumanoidRootPart")
		if root then R.Homes[m] = { Pivot = m:GetPivot(), Root = root.CFrame } end
	end
	local C = stage.CF.Position
	local right = unitOr(flat(stage.CF.RightVector), Vector3.xAxis)
	R.G = { C = C, R = right, L = unitOr(flat(stage.CF.LookVector), Vector3.yAxis:Cross(right).Unit),
		FloorY = typeof(stage.Floor) == "Vector3" and stage.Floor.Y or C.Y - 3.2 }
	if typeof(stage.Parent) == "Instance" then
		R.Conn = stage.Parent.Destroying:Connect(function() stopRun(R) end)   -- never a loop left running on nothing
	end
	task.spawn(function()
		local ok, err = pcall(function()
			local K = loadKit()
			if R.Dead or not K then return end
			if not K.UFX.Enabled() then
				warnOnce("off", "UmbraTuning has no FX block: Umbra draws nothing")
				return
			end
			R.K, R.UFX, R.T, R.CP = K, K.UFX, K.T, K.CP
			-- (2026-10-26) the wrap by AltarStage.Look's one rule: with a skin on (stage.Skin; Umbra has none yet) only a
			-- wrap SkinCatalog lets over a skin (never Umbra's) -- else no palette: the carrier's nil Wrap keeps CUR, and
			-- the skin the caster wears (ShowcaseSkin) has the look
			local wrap = stage.Wrap
			local React = stage.React
			if type(React) == "table" and type(React.Look) == "function" then
				local okL, _, w = pcall(React.Look, stage, "Umbra")
				if okL then wrap = w end
			end
			R.P = paletteOf(K, wrap)
			if setup then
				local okS, errS = pcall(setup, R)
				if not okS then warnOnce("setup:" .. id, id .. " staging failed: " .. tostring(errS)) end
			end
			-- the caster registered on CastPose now, so it is standing on the Ready stance when the first beat plays
			pose(R, "SetStance", caster, "Ready")
			R.Next = os.clock() + SETTLE
			-- the supervisor: the carrier made again should anything (UmbraFX.StopAll) take it
			while not R.Dead do
				if not (R.Pump and not R.Pump.Dead) and not startPump(R) then
					warnOnce("pump", "UmbraFX.Dart gave no effect: nothing drawn")
					return
				end
				task.wait(0.5)
			end
		end)
		if not ok then warnOnce("setup:" .. id, id .. " setup failed: " .. tostring(err)) end
	end)
	return function() stopRun(R) end
end

----------------------------------------------------------------------------------------------------
-- M1: SHADOW DART (also Mark's payoff, Eclipse's quickened shot and Unseen's demonstration)
----------------------------------------------------------------------------------------------------
local function eyeOf(model)
	local head = model:FindFirstChild("Head")
	if head then return head.Position end
	local root = model:FindFirstChild("HumanoidRootPart")
	return root and root.Position + Vector3.new(0, 1.5, 0) or nil
end

--- where a shot from `eye` meets `name` of `model`: the part's centre pulled `inset` studs back toward the shooter
local function hitPoint(model, name, eye, inset)
	local p = model:FindFirstChild(name) or model:FindFirstChild("HumanoidRootPart")
	if not (p and p:IsA("BasePart")) then return nil end
	return p.Position - unitOr(p.Position - eye, Vector3.zero) * inset
end

--- One Shadow Dart from the caster, as UmbraClient.FireM1 fires it and UmbraAnim poses it: the body's UmbraShadowDart on
--- the charge's clock (x `mult`, Eclipse's M1RateMult) and the charge on its right hand -- both reach the release on the
--- same beat, Windup / (ShotTimeScale x mult) -- then the release (the ball collapses lit, the Tell), the dart leaving the
--- ball and easing onto the eye's line over FX.Dart.EaseOver studs (flyDart's own path), and at the contact Impact, the
--- Tell and onHit(point, dir, flightTime, eye).
local function shoot(R, partName, mult, onHit)
	local UFX, T, caster, victim = R.UFX, R.T, R.Caster, R.Target
	local scale = shotScale(R.K)
	local k = scale * (mult or 1)
	local due = T.ShadowDart.Windup / k
	local t0 = os.clock()
	pose(R, "PlayClocked", caster, "UmbraShadowDart", function() return (os.clock() - t0) * k end)   -- ShadowDartCharge
	local charge = keep(R, UFX.DartCharge(caster, t0, due), "charge")
	at(R, due, function()                                        -- ShadowDart: the release, on the clip's Trigger
		local eye = eyeOf(caster)
		local point = eye and hitPoint(victim, partName, eye, partName == "Head" and 0.55 or 0.5)
		local line = (eye and point) and point - eye or Vector3.zero
		if line.Magnitude < 0.5 then
			charge:Cancel()
			return
		end
		local dist, dir = line.Magnitude, line.Unit
		local from = charge:BallPosition()
		if typeof(from) ~= "Vector3" then
			local hand = caster:FindFirstChild("RightHand")
			from = hand and hand.Position or eye
		end
		charge:Release()
		UFX.Tell(caster, "Fire")
		local look = keep(R, UFX.Dart(caster))
		local ease = (T.FX and T.FX.Dart and T.FX.Dart.EaseOver) or 12
		local function visAt(x) return from:Lerp(eye, math.clamp(x / ease, 0, 1)) + dir * x end
		local travelled, t1 = 0, os.clock()
		local function place()
			local vis = visAt(travelled)
			local ahead = visAt(travelled + 0.05) - vis
			look:Move(vis, unitOr(ahead, dir), travelled)
		end
		place()                                               -- (on the ball this frame, as the release draws it)
		tick(R, function(now, dt)
			travelled += DART_SHOW_SPEED * scale * math.clamp(dt or 0, 0, 0.1)
			if travelled < dist then
				place()
				return true
			end
			look:Impact(point, dir)
			UFX.Tell(caster, "Hit")
			onHit(point, dir, now - t1, eye)
			return false
		end)
	end)
end

--- the dart's damage on a body: UmbraTuning's Damage, x (1 + Unseen.Bonus) when it is unaware (UmbraHandler's own sum)
local function dartDamage(R, unaware)
	local T = R.T
	local d = T.ShadowDart.Damage or 65
	if unaware then d *= 1 + ((T.Unseen and T.Unseen.Bonus) or 0.25) end
	return d
end

local function dartCycle(R)
	shoot(R, "UpperTorso", 1, function(point, dir, flight, eye)
		keep(R, R.UFX.Hit(point, dir, { Owner = R.Caster, FlightTime = flight }))
		react(R, { Damage = dartDamage(R, false), From = eye })   -- no knockback: the recoil
	end)
end

--- PASSIVE: UNSEEN -- the dart on an UNAWARE target (more than Unseen.UnawareAngle off its facing): its back turned
local function unseenSetup(R)
	local m = R.Target
	local h = R.Homes[m]
	if not h then return end
	R.Rest[m] = standCF(R, m, h.Root.Position, R.G.R)            -- facing away from the caster, for every beat
	turnTo(R, m, R.G.R, UNSEEN_TURN)
end

local function unseenCycle(R)
	shoot(R, "UpperTorso", 1, function(point, dir, flight, eye)
		keep(R, R.UFX.Hit(point, dir, { Owner = R.Caster, FlightTime = flight }))
		react(R, { Damage = dartDamage(R, true), From = eye })    -- 65 x 1.25: the Unseen bonus
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: SHADOW STEP
----------------------------------------------------------------------------------------------------
--- One step, as the server and UmbraAnim play it: ShadowStepOut (From / To are ROOT positions; UmbraFX finds the floor
--- RootAboveFloor below), the body's cue on stepClock, the body gone at the drawing's HideAt beat (UmbraClient's hide),
--- moved at the re-form (DissolveTime: the server's PivotTo) and shown again there (ShadowStepIn).
local function blink(R, from, to, face)
	local T, caster = R.T, R.Caster
	local scale = shotScale(R.K)
	local dissolve = T.ShadowStep.DissolveTime / scale
	local t0 = os.clock()
	local movedAt = nil
	pose(R, "PlayClocked", caster, "UmbraShadowStep", function()
		local now = os.clock()
		if movedAt then return math.min((movedAt - t0) * scale, STEP_HOLD_AT) + (now - movedAt) * scale end
		return math.min((now - t0) * scale, STEP_HOLD_AT)
	end)
	keep(R, R.UFX.StepOut(caster, from, to, { Start = t0, Dissolve = dissolve }))
	local S = T.FX and T.FX.Step
	local hideAfter = (S and S.HideAt and S.SpecDissolve) and (S.HideAt / S.SpecDissolve * dissolve) or 0
	at(R, hideAfter, function() vanish(R, true) end)
	at(R, dissolve, function()
		stand(R, caster, to, face)
		movedAt = os.clock()
		vanish(R, false)
	end)
end

local function stepCycle(R)
	local G, T, caster = R.G, R.T, R.Caster
	local h = R.Homes[caster]
	if not h then return end
	local S = T.ShadowStep
	local from = h.Root.Position
	-- stepDestination: toward the aim (the target), stopped AimPad short of what it aims at, capped at Distance
	local troot = R.Target:FindFirstChild("HumanoidRootPart")
	local aim = troot and troot.Position or (from + G.R * 14)
	local d = flat(aim - from).Magnitude
	local want = S.Distance or 22
	if d - (S.AimPad or 2.5) >= (S.MinDistance or 4) then want = math.min(want, d - (S.AimPad or 2.5)) end
	local into = from + G.R * want
	blink(R, from, into, G.R)
	-- the second charge (the escape blink, same key): turn for home, blink back, face the target again
	at(R, STEP_TURN_AT, function() turnTo(R, caster, -G.R, TURN_TIME) end)
	at(R, STEP_BACK_AT, function()
		local root = caster:FindFirstChild("HumanoidRootPart")
		blink(R, root and root.Position or into, from, -G.R)
	end)
	at(R, STEP_FACE_AT, function() turnTo(R, caster, G.R, TURN_TIME) end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: MARK -- the marker is UmbraClient.anchorFor's (a local there), mirrored line for line in the wrap's colours
----------------------------------------------------------------------------------------------------
local function markColour(R, k)
	local c = R.P and R.P.Color
	return (type(c) == "table" and typeof(c[k]) == "Color3") and c[k] or R.T.Color[k]
end

--- UmbraFX.MarkPulse for the wrap: the Epic+ marker light's breathing (1 with no Pulse, held under Reduce Flashing)
local function markPulse(R)
	local Pu = R.P and R.P.Pulse
	if type(Pu) ~= "table" or reduceFlashing(R.K) then return 1 end
	return 1 + Pu.Amp * math.sin(2 * math.pi * os.clock() / Pu.Period)
end

--- anchorFor(victim, stacks)'s look: size by stacks, Dusk -> Shade when full, a Rare wrap's lit finish, an Epic+ glow
local function markStacks(R, a, stacks)
	local full = stacks >= R.T.Mark.MaxStacks
	local s = 0.35 + 0.15 * stacks
	a.Size = Vector3.new(s, s, s)
	a.Color = full and markColour(R, "Shade") or markColour(R, "Dusk")
	local fin = full and R.P and R.P.Mark or nil
	local lit = type(fin) == "table" and typeof(fin.Lit) == "Color3"
	if lit then a.Color = fin.Lit end
	a.Reflectance = (lit and type(fin.Reflectance) == "number") and fin.Reflectance or 0
	a.Material = (lit and materialOf(fin.Material)) or Enum.Material.SmoothPlastic
	local mg = R.P and R.P.MarkGlow
	if type(mg) == "table" and type(mg.Light) == "number" then
		a.Material = Enum.Material.Neon
		a.Reflectance = 0
		local nl = full and mg.Lit or mg.Dim
		if typeof(nl) == "Color3" then a.Color = nl end
		local gl = a:FindFirstChild("UmbraMarkGlow")
		if not gl then
			gl = Instance.new("PointLight")
			gl.Name = "UmbraMarkGlow"
			gl.Shadows = false
			gl.Parent = a
		end
		gl.Color = typeof(mg.Color) == "Color3" and mg.Color or markColour(R, "Shade")
		gl.Range = mg.Range or 8
		a:SetAttribute("GlowLight", mg.Light)
	end
end

local function markAnchor(R, victim)
	local head = victim:FindFirstChild("Head")
	if not head then return nil end
	local a = Instance.new("Part")
	a.Name = "UmbraMarkAnchor"
	a.Shape = Enum.PartType.Block
	a.Material = Enum.Material.SmoothPlastic
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
	a.CFrame = CFrame.new(head.Position + Vector3.new(0, 2.2, 0))
	markStacks(R, a, 1)
	a.Parent = R.Stage.Parent
	made(R, a)
	tick(R, function()
		if not (a.Parent and head.Parent) then return false end
		a.CFrame = CFrame.new(head.Position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(math.rad(45), os.clock() * 1.5, math.rad(45))
		local gl = a:FindFirstChild("UmbraMarkGlow")
		if gl then gl.Brightness = (a:GetAttribute("GlowLight") or 0) * markPulse(R) end
		return true
	end)
	return a
end

local function markCycle(R)
	local T = R.T
	local scale = shotScale(R.K)
	local M = T.Mark
	local a, stacks = nil, 1
	pose(R, "Play", R.Caster, "UmbraMark")                           -- the left arm points
	at(R, clipField(R, "UmbraMark", "Trigger", 0.08) / scale, function()   -- MarkApplied, on the point
		a = markAnchor(R, R.Target)
		react(R, { Word = "HUNTED!", Style = "hunted", NoRecoil = true })
		local every = M.StackEvery / scale
		for s = 2, M.MaxStacks do                                    -- MarkStack: one a StackEvery, light when full
			at(R, every * (s - 1), function()
				stacks = s
				if a and a.Parent then markStacks(R, a, s) end
			end)
		end
	end)
	at(R, MARK_DART_AT, function()
		shoot(R, "Head", 1, function(point, dir, flight, eye)
			keep(R, R.UFX.MarkHeadshot(point, dir, { Owner = R.Caster, FlightTime = flight }))
			if a then a:Destroy() end                                -- MarkEnd: the payoff's look is the hit's
			local bonus = (type(M.HeadBonus) == "table" and M.HeadBonus[stacks]) or 0
			react(R, { Damage = dartDamage(R, false) + bonus, From = eye })   -- the -10 modifier: Damage + HeadBonus[stacks]
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: DECOY DOUBLE
----------------------------------------------------------------------------------------------------
--- the double's template: a copy of the caster taken at Play, its joints at REST (CastPose writes the posed values into
--- the live caster's joints, so a copy of the posed body would fold its pose into the copy's rest -- the server's copy
--- never has that problem: client writes do not replicate)
local function decoySetup(R)
	local m = R.Caster
	pose(R, "Release", m)                                            -- (every joint handed back first, should it be posed)
	local was = m.Archivable
	m.Archivable = true
	local ok, copy = pcall(function() return m:Clone() end)
	m.Archivable = was
	if ok and copy then R.Template = copy end
end

--- the double: a copy of the caster (as UmbraHandler.castDecoy clones the body) on pivot `cf`, the caster's facing.
--- Its Humanoid and joints stay, so CastPose poses it; it is not queried (nothing here aims at it)
local function makeDecoy(R, cf)
	local src = R.Template
	if not src then return nil end
	local ok, copy = pcall(function() return src:Clone() end)
	if not (ok and copy) then return nil end
	copy.Name = "UmbraAltarDecoy"
	copy:SetAttribute("AltarHome", nil)
	copy:SetAttribute("ShowcaseSkin", nil)                          -- (2026-10-26) the copy is nobody's wearer: a skin kit
	copy:SetAttribute("StudioSkin", nil)                            -- would dress it as a second caster
	copy:SetAttribute("AllyDummy", true)
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			d.LocalTransparencyModifier = 0
		end
	end
	copy:PivotTo(cf)
	copy.Parent = R.Stage.Parent
	return made(R, copy)
end

--- UmbraDecoyPoser's loop clock: [0, LoopFrom) once, then [LoopFrom, LoopFrom + LoopLength) round and round
local function loopClock(from, length)
	local t0 = os.clock()
	return function()
		local t = os.clock() - t0
		if t < from or length <= 0 then return t end
		return from + (t - from) % length
	end
end

local function decoyCycle(R, loop)
	local G, T, caster = R.G, R.T, R.Caster
	-- the caster turns to the camera, so the double peels off its RIGHT (castDecoy: RightVector x Offset) across the view
	turnTo(R, caster, G.L, TURN_TIME)
	at(R, TURN_TIME, function()
		local root = caster:FindFirstChild("HumanoidRootPart")
		local faced = root and standCF(R, caster, root.Position, G.L)
		if not faced then return end
		stand(R, caster, root.Position, G.L)                         -- (the turn's last frame, exactly)
		local side = CFrame.lookAt(Vector3.zero, G.L).RightVector
		local decoy = makeDecoy(R, faced + side * ((T.DecoyDouble and T.DecoyDouble.Offset) or 3.8))
		if not decoy then return end
		pose(R, "Play", caster, "UmbraDecoyDouble")                  -- DecoySpawn: the caster's cue...
		pose(R, "PlayClocked", decoy, "UmbraDecoyReady",               -- ...and the copy's idle (UmbraDecoyPoser)
			loopClock(clipField(R, "UmbraDecoyReady", "LoopFrom", 0), clipField(R, "UmbraDecoyReady", "LoopLength", 4)))
		keep(R, R.UFX.DecoyPeel(caster, decoy, { Start = os.clock() }))
		at(R, DECOY_HOLD, function()                                -- DecoyBreak "Hit": the target's shot finds the copy
			local root = decoy.Parent and decoy:FindFirstChild("HumanoidRootPart")
			if not root then return end
			local troot = R.Target:FindFirstChild("HumanoidRootPart")
			local toward = troot and unitOr(flat(troot.Position - root.Position), side) or side
			local hitAt = root.Position + toward * 0.8 + Vector3.new(0, 0.5, 0)
			keep(R, R.UFX.DecoyBreak(decoy, { Owner = caster, HitAt = hitAt, Seed = 7919 * loop, Lit = true }))
			R.UFX.Tell(caster, "Decoy")
			at(R, DECOY_GONE, function() decoy:Destroy() end)
			at(R, DECOY_TURN_BACK, function() turnTo(R, caster, G.R, TURN_TIME) end)
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: ECLIPSE
----------------------------------------------------------------------------------------------------
--- run fn with the dummies out of every ray (the domain's floor ray and wall checks would stop on a queryable body)
local function unqueried(models, fn)
	local saved = {}
	for _, m in ipairs(models) do
		if typeof(m) == "Instance" then
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.CanQuery then
					saved[p] = true
					p.CanQuery = false
				end
			end
		end
	end
	local ok, err = pcall(fn)
	for p in pairs(saved) do p.CanQuery = true end
	if not ok then error(err, 0) end
end

--- UmbraFX's reveal on one body (RevealStart is the local player's, ranged off its own character, which is in the hub):
--- the same light-purple outline through walls, in the wrap's RevealColor
local function revealOn(R, m)
	local h = Instance.new("Highlight")
	h.Name = "UmbraReveal"
	h.Adornee = m
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	local rc = R.P and R.P.RevealColor
	h.OutlineColor = typeof(rc) == "Color3" and rc or R.T.Eclipse.RevealColor or markColour(R, "Shade")
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = R.Stage.Parent
	return made(R, h)
end

local function eclipseCycle(R)
	local T, caster = R.T, R.Caster
	local scale = shotScale(R.K)
	local windup = (T.Eclipse.WindupTime or 1) / scale
	pose(R, "Play", caster, "UmbraEclipseCharge")                    -- EclipseCharge: the held press
	local h = keep(R, R.UFX.Eclipse(caster, { Start = os.clock(), Windup = windup }), "eclipse")
	at(R, windup, function()                                        -- EclipseStart: as everyone in the duel sees it
		pose(R, "Play", caster, "UmbraEclipseOpen")
		local now = os.clock()
		local hold = ECLIPSE_HOLD / scale
		unqueried({ caster, R.Target }, function()
			h:Open(now, now + hold, { Domain = true })
		end)
		local outline = revealOn(R, R.Target)                       -- every enemy revealed to the caster
		at(R, hold, function() outline:Destroy() end)
		-- every enemy unaware, and Shadow Dart FireRateMult quicker: the dart the domain is for
		at(R, ECLIPSE_DART_AT, function()
			shoot(R, "UpperTorso", T.Eclipse.FireRateMult or 1.5, function(point, dir, flight, eye)
				keep(R, R.UFX.Hit(point, dir, { Owner = caster, FlightTime = flight }))
				react(R, { Damage = dartDamage(R, true), From = eye })
			end)
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- the kit
----------------------------------------------------------------------------------------------------
local Config = nil
do
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = spell and spell:FindFirstChild("SpellshotConfig")
	local ok, c = pcall(function() return m and require(m) end)
	Config = (ok and type(c) == "table") and c or nil
end

--- a display name from SpellshotConfig along the path given, else `fallback`
local function nameOf(fallback, ...)
	local v = Config
	for _, k in ipairs({ ... }) do
		if type(v) ~= "table" then return fallback end
		v = v[k]
	end
	return type(v) == "string" and v or fallback
end

local function entry(key, slot, name, period, cycle, setup)
	return {
		Key = key, Name = name, Slot = slot,
		Play = function(stage)
			local ok, stop = pcall(preview, stage, key, period, cycle, setup)
			if ok and type(stop) == "function" then
				return function() pcall(stop) end
			end
			warnOnce("play:" .. key, key .. " could not start: " .. tostring(stop))
			return function() end
		end,
	}
end

return {
	Element = "Umbra",
	Moves = {
		entry("ShadowDart", "M1", nameOf("Shadow Dart", "Elements", "Umbra", "M1", "Name"), 3.6, dartCycle),
		entry("ShadowStep", "Primary", nameOf("Shadow Step", "Elements", "Umbra", "Primary", "Name"), 3.0, stepCycle),
		entry("Mark", "Mobility", nameOf("Mark", "Mobility", "Mark", "Name"), 4.2, markCycle),
		entry("DecoyDouble", "Defense", nameOf("Decoy Double", "Defense", "DecoyDouble", "Name"), 3.6, decoyCycle, decoySetup),
		entry("Eclipse", "Ultimate", nameOf("Eclipse", "Ultimate", "Eclipse", "Name"), 4.5, eclipseCycle),
		entry("Unseen", "Passive", nameOf("Unseen", "Elements", "Umbra", "Passive", "Name"), 3.6, unseenCycle, unseenSetup),
	},
}
