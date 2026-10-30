--[[
	AltarMoves_Aqua  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Aqua

	The Loadout Altar's move showcase for Aqua, CONTRACT v2 (2026-10-26, the owner: every move PERFORMED on the stage -- a
	visible caster casting it with the game's own third-person cast poses, a visible target taking the hit the way a duel
	shows it -- in the wrap being looked at, looping). One entry per move in kit order; Play(stage) starts that move looping
	on the lead's stage at once and returns stop(). Client only: no remotes, no damage, no hit claims (the OnHit handed to
	AquaFX here only tells stage.React that the hit landed; nothing ever reaches the server).

	THE CASTER is stage.Caster, posed by IceMagic.CastPose (that instance) with the clips AquaClient.Handlers play for
	another player's cast (Aqua borrows them all); each draw leaves at its clip's release beat (Clip.Trigger over the
	IceMagic CastPoseTimeScale -- the clip's own clock, AbilityFX's schedule), from the caster's body, aimed at stage.Target.
	THE TARGET reacts when the hit lands: the move's own impact (the wave's splash on the body, the bullet's splash, the
	bite's ring and spray, the crash) and stage.React.Hit with AquaTuning's numbers and AquaHandler's throws.
	THE WRAP: every draw is AquaFX's own entry point -- the call the move's broadcast handler makes -- run inside AquaWrap's
	own context (AquaWrap.Call with stage.Wrap's palette, as AquaWrap.Install runs a wrapped caster's casts), so the baked
	wrap meshes, the Color swap and AquaWrapLux's Epic / Mythic levers all come from the wrap code. The foam at a rider's
	feet is drawn through AquaWrap.For (Install's hook), so For is swapped for that one synchronous call to answer the
	palette for both dummies. Default runs in a context with no palette (the viewer's own wrap never leaks into it).
	  Riptide           IcicleShardR then L at the M1's FireInterval; each wave from the caster's root along the aim,
	                    through stage.Target (its splash on the body; Damage 12, a recoil), breaking on an invisible
	                    backstop past it
	  Undertow          CycloneForm; at its beat the disc 4.2 studs in front of the caster's eye on the aim (its face
	                    turned DISC_TURN toward the camera, or it is edge-on to it); at SnapTime CycloneRelease and the
	                    pull: stage.Target carried to the floor under the disc (AquaHandler carryDummy's path and hold)
	  Twin Tide         BulwarkWallRaise (let go at 0.8 s, as the handler does); the lane centred on stage.Target along
	                    the caster's aim; at CloseTime the crush (Damage 35, thrown up CrushLift 30)
	  Sidearm           SidearmDraw; the gun drawn in the caster's right hand at the beat (the handler's frame);
	                    the drawn shot DrawTime later, eye to target (Damage 8, thrown KnockBack 38 along + the server's
	                    sidearmKnockUp); Linger, put away. One shot: the knock throws the target out of the next one's line
	  Leviathan's Maw   FlashFreeze and AquaFX.Maw at MAW_RADIUS, aimed MAW_SHORT short of stage.Target (it inside, the
	                    caster outside); the server's beats from here: SetSharks(1) at CloseTime, LungeMany at LungeTime,
	                    BiteMany at BiteTime (BiteDamage 65, thrown up BiteLift 40)
	  Riding the Current  a wet lane (AquaFX.WetLane) under both dummies; the caster RIDES it at SprintSpeed x (1 +
	                    SpeedBonus) with the run's stride and AquaFX.RidingSplash at its feet, out and back; the target,
	                    on the wet ground as the rider comes, SLIPS (SlipUntil; a skid toward the camera's side with foam
	                    at its feet, momentum carrying it; then it steps back). The passive deals no damage: no React.Hit
	(2026-10-26) THE SKIN: the wrap is AltarStage.Look's (over stage.Skin only a wrap SkinCatalog lets over a skin; Aqua
	has no skin yet). Swept for what a cast needs that a dummy lacks: nothing new -- the gun prop is AquaFX.SidearmGun at
	the caster's hand, the rider's foam answers through AquaWrap.For (asRider), SlipUntil is set on the target here.
	Between loops the caster is let go of every clip / base / aim, put back on Ready and home, and stage.React.Reset runs.
	The gameplay colliders the walls and the tank build (invisible, CanCollide) are switched off: a preview never blocks a
	body. stop() ends the loop and every carry, cancels Twin Tide, puts the gun away and drains the tank (GRACE s),
	destroys every piece the preview's calls made and the splash pieces their steppers threw round the stage, lets the
	caster's pose go and resets both dummies.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- EVERY NUMBER HERE IS A PROPOSAL (the moves' own numbers are AquaTuning's, read live)
local GRACE = 0.35            -- stop(): the gun's put-away and the tank's drain run this long, then whatever is left goes
local SWEEP = 80              -- studs: stop() also sweeps the loose splash pieces (AK_* / Aqua* / Lux*) this far round the stage
local BACKSTOP_PAST = 2       -- studs past stage.Target the invisible wall's face stands that Riptide breaks on and a missed
                              -- bullet stops at (kept 0.3 inside the floor slab, never nearer the target than 1.2)
-- Leviathan's Maw is a 44-stud tank in combat (AquaTuning.Maw.Radius 22, the kit modelled at that size). Here it is drawn
-- at this radius so it stands on the stage: AquaFX.Maw reads Radius once, at the call (walls, roof and flood scaled by
-- Radius / 22, the 14-stud height kept), so it is set for that one synchronous call and put straight back. nil = real size.
local MAW_RADIUS = 9
local MAW_SHORT = 2           -- studs: the Maw is aimed this far short of stage.Target, so the shark rises between the two
local DISC_TURN = 40          -- degrees Undertow's disc is turned toward the camera about its own centre (its centre stays on
                              -- the aim). In combat it faces its caster: from the stage's side camera that is edge-on, a line.
                              -- 0 = exactly as cast
local PULL_HOLD = 1.2         -- AquaHandler carryDummy's `back` for Undertow's pull: held at the disc, then home
local RIDE_SHORT = 3.5        -- Riding the Current: the ride stops this far short of stage.Target...
local RIDE_PAUSE = 0.55       -- ...stands this long, and rides back home
local SPLASH_EVERY = 0.16     -- AquaClient's foam cadence for anyone moving on wet ground
local SLIP_SKID = 3           -- the slip: studs the target slides toward the camera's side over SlipTime...
local SLIP_WOBBLE = 9         -- ...degrees it rocks side to side as it goes (fading)...
local SLIP_BACK = 0.45        -- ...and seconds it takes to step back once the slip is over
local PERIOD = {              -- seconds between loops, matched to each move
	Riptide = 2.8, Undertow = 3.9, TwinTide = 4.2, Sidearm = 2.8, Riding = 3.2,
	-- (the Maw: its own EndTime + 0.5 -- the Ultimate runs 5.3 s, longer than the other moves' window)
}

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Aqua] " .. msg)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--- AquaFX, AquaTuning, VFXLibrary, CastPose and AquaWrap, required on first use (inside a Play's own thread, never the
--- caller's); nil when Aqua's draw modules are not in the place: nothing is drawn and nothing errors
local Mods = nil
local function mods()
	if Mods then return Mods end
	local ok, r = pcall(function()
		local ice = ReplicatedStorage:WaitForChild("IceMagic", 10)
		local t = {
			FX = require(ice:WaitForChild("AquaFX", 10)),
			A = require(ice:WaitForChild("AquaTuning", 10)),
			VFX = require(ice:WaitForChild("VFXLibrary", 10)),
			CP = require(ice:WaitForChild("CastPose", 10)),     -- (the IceMagic instance: a second copy runs its own state)
		}
		local okW, W = pcall(function() return require(ice:WaitForChild("AquaWrap", 5)) end)
		t.W = (okW and type(W) == "table" and type(W.Call) == "function") and W or nil
		return t
	end)
	if ok and type(r) == "table" and type(r.FX) == "table" and type(r.A) == "table" and type(r.CP) == "table" then
		Mods = r
		return r
	end
	warnOnce("mods", "Aqua's draw modules or CastPose are missing - nothing drawn (" .. tostring(r) .. ")")
	return nil
end

--- The moves' display names, read from SpellshotConfig (the strings here are only the fallback); its Movement table
--- gives Riding the Current's pace
local Config = nil
do
	local sp = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = sp and sp:FindFirstChild("SpellshotConfig")
	if m then
		local ok, c = pcall(require, m)
		if ok and type(c) == "table" then Config = c end
	end
end
local function nameOf(fallback, read)
	if not Config then return fallback end
	local ok, n = pcall(read, Config)
	return (ok and type(n) == "string" and n ~= "") and n or fallback
end

--- the stage's React (stage.React, else the module itself)
local function reactOf(stage)
	if type(stage.React) == "table" then return stage.React end
	local ok, R = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("AltarStage", 5))
	end)
	return (ok and type(R) == "table") and R or nil
end

--- where a dummy stands at rest: AltarStage's AltarHome position, its current turn
local function homeOf(m)
	local p = m:GetPivot()
	local h = m:GetAttribute("AltarHome")
	return typeof(h) == "Vector3" and (p - p.Position + h) or p
end

----------------------------------------------------------------------------------------------------
-- one preview: its wrap context, the pieces its calls made, the dummies' moves, its loop and its stop
----------------------------------------------------------------------------------------------------
local function session(stage, kind)
	local S = { Stage = stage, Kind = kind, Alive = true, Dead = false, Cycle = 0,
		Owned = {}, Keep = {}, Parts = {}, Conns = {}, Moves = {}, Tides = {}, Guns = {}, Maws = {} }

	--- the modules, the dummies, the wrap and the stage's aim; false when nothing can be drawn
	function S.load()
		local m = mods()
		if not (m and S.Alive) then return false end
		S.FX, S.A, S.W, S.CP, S.VFX = m.FX, m.A, m.W, m.CP, m.VFX
		S.FXName = (m.VFX and m.VFX.Config and m.VFX.Config.FXFolderName) or "IceMagicFX"
		S.React = reactOf(stage)
		local caster, target = stage.Caster or stage.Key, stage.Target
		if not (typeof(caster) == "Instance" and typeof(target) == "Instance") then
			warnOnce("rigs", "the stage has no Caster / Target - nothing drawn")
			return false
		end
		S.Caster, S.Target = caster, target
		local r = flat(stage.CF.RightVector)
		S.Right = r.Magnitude > 1e-3 and r.Unit or Vector3.xAxis
		S.CasterHome, S.TargetHome = homeOf(caster), homeOf(target)
		local apart = (S.TargetHome.Position - stage.Floor):Dot(S.Right)
		S.Apart = apart > 1 and apart or 7
		-- the wrap's palette: nil draws Default (no catalog entry, not an Aqua wrap, or AquaWrap's identity guard refused it).
		-- (2026-10-26) The wrap is AltarStage.Look's: with a skin on (stage.Skin; Aqua has none yet) only a wrap
		-- SkinCatalog lets over a skin (never Aqua's baked ones), else none -- the skin's kit, which the caster wears
		-- (ShowcaseSkin), has the look
		local wrap = stage.Wrap
		if type(S.React) == "table" and type(S.React.Look) == "function" then
			local okL, _, w = pcall(S.React.Look, stage, "Aqua")
			if okL then wrap = w end
		end
		local P = nil
		if S.W and type(wrap) == "string" and wrap ~= "Default" then
			local okP, p = pcall(S.W.Palette, wrap)
			P = (okP and type(p) == "table") and p or nil
			if P then
				if type(S.W.Preload) == "function" then pcall(S.W.Preload, wrap) end   -- its baked set, fetched now
			else
				warnOnce("wrap" .. wrap, "Aqua wrap " .. wrap .. " unavailable - Default drawn")
			end
		end
		-- Caster = the viewer: AquaWrapLux and AquaWrap.Density treat it as their own effect (no Reduce Enemy VFX halving)
		local me = Players.LocalPlayer
		S.Ctx = { P = P, Caster = me and me.Character, Kind = kind }
		return true
	end

	--- the FX folder every AquaFX piece goes into, made if it is not there yet (as AquaFX's fxFolder makes it)
	function S.fx()
		local f = workspace:FindFirstChild(S.FXName)
		if not f then
			f = Instance.new("Folder")
			f.Name = S.FXName
			f.Parent = workspace
		end
		return f
	end

	-- a wave-wall's or the tank's invisible box blocks bodies in combat: never here
	local function offCollider(p)
		if p:IsA("BasePart") and p.Name == "AquaCollider" then p.CanCollide = false end
	end
	local function own(c)
		S.Owned[c] = true
		offCollider(c)
		if c:IsA("Model") then
			for _, d in ipairs(c:GetDescendants()) do offCollider(d) end
			-- (the tank's ceiling is made later, once its roof has closed)
			if c.Name == "AquaMaw" then S.Conns[#S.Conns + 1] = c.DescendantAdded:Connect(offCollider) end
		end
	end

	local function within(fn, ...)
		if S.W then return S.W.Call(S.Ctx, fn, ...) end
		return fn(...)
	end

	--- fn(...) drawn in this preview's wrap. Everything it parents straight into the FX folder is this preview's (the call
	--- is synchronous: nothing else can add to the folder meanwhile). Returns ok, fn's result, the new pieces. A wrap that
	--- breaks the draw falls back to Default (what it made goes, the call is made again); nothing ever errors out.
	function S.call(fn, ...)
		if not S.Alive or type(fn) ~= "function" then return false end
		local f = S.fx()
		local before = {}
		for _, c in ipairs(f:GetChildren()) do before[c] = true end
		local ok, res = pcall(within, fn, ...)
		local new = {}
		for _, c in ipairs(f:GetChildren()) do
			if not before[c] then
				new[#new + 1] = c
				own(c)
			end
		end
		if ok then return true, res, new end
		if S.Ctx.P then
			warnOnce("wrapfail" .. kind, kind .. " in wrap " .. tostring(S.Ctx.P.Id) .. " failed (" .. tostring(res) .. ") - Default drawn")
			for _, c in ipairs(new) do pcall(c.Destroy, c) end
			S.Ctx = { P = nil, Caster = S.Ctx.Caster, Kind = kind }
			return S.call(fn, ...)
		end
		warnOnce("fail" .. kind, kind .. " failed: " .. tostring(res))
		return false
	end

	--- wait until os.clock() reaches t; false the moment the preview is stopped
	function S.sleepUntil(t)
		while S.Alive do
			local left = t - os.clock()
			if left <= 0 then return true end
			task.wait(math.min(left, 0.1))
		end
		return false
	end
	function S.frame()
		task.wait()
		return S.Alive
	end
	--- fn() `dt` seconds on, if the preview is still on the same loop
	function S.after(dt, fn)
		local id = S.Cycle
		task.delay(dt, function()
			if S.Alive and S.Cycle == id then pcall(fn) end
		end)
	end

	----------------------------------------------------------------------------------------------------
	-- the caster's body (CastPose) and the target's hit (stage.React)
	----------------------------------------------------------------------------------------------------
	function S.pose(clip)
		pcall(S.CP.Play, S.Caster, clip)
	end
	--- a clip's release beat, seconds after it starts: its Trigger on the clip's own clock (AbilityFX l.103)
	function S.beat(clip)
		local c = S.CP.Clips and S.CP.Clips[clip]
		local t = (c and tonumber(c.Trigger)) or 0
		local ice = ReplicatedStorage:FindFirstChild("IceMagic")
		local sc = ice and ice:GetAttribute("CastPoseTimeScale")
		sc = (type(sc) == "number" and sc > 0) and sc or 1
		return t / sc
	end
	function S.shotScale()
		local ok, v = pcall(function() return S.VFX.ShotTimeScale() end)
		return (ok and type(v) == "number" and v > 0) and v or 1
	end
	function S.hit(opts)
		if S.Alive and S.React and type(S.React.Hit) == "function" then pcall(S.React.Hit, stage, opts) end
	end
	--- fn(), only for a hit whose part is stage.Target's
	function S.onTarget(fn)
		return function(part)
			if typeof(part) == "RaycastResult" then part = part.Instance end
			if S.Alive and typeof(part) == "Instance" and part:IsDescendantOf(S.Target) then fn() end
		end
	end

	function S.root(model)
		return typeof(model) == "Instance" and model:FindFirstChild("HumanoidRootPart") or nil
	end
	--- an anchored root's velocity back to nothing (the stride and the foam's throw read it)
	function S.still(model)
		local r = S.root(model)
		if r then pcall(function() r.AssemblyLinearVelocity = Vector3.zero end) end
	end
	--- the floor point under stage.Target at rest
	function S.targetFloor()
		local p = S.TargetHome.Position
		return Vector3.new(p.X, stage.Floor.Y, p.Z)
	end

	--- a dummy carried: step(t) every Heartbeat for `duration` seconds, then done(); ended by S.halt (each loop, stop)
	function S.move(duration, step, done)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if not S.Alive then
				conn:Disconnect()
				return
			end
			if t >= duration then
				conn:Disconnect()
				pcall(done)
				return
			end
			local ok, err = pcall(step, t)
			if not ok then
				conn:Disconnect()
				warnOnce("move" .. kind, kind .. " carry failed: " .. tostring(err))
				pcall(done)
			end
		end)
		S.Moves[#S.Moves + 1] = conn
	end
	function S.halt()
		for _, c in ipairs(S.Moves) do pcall(function() c:Disconnect() end) end
		table.clear(S.Moves)
	end

	--- the rest between loops (and at stop): every carry ended, the caster let go of its clip, base and aim, on Ready, home,
	--- the target's slip cleared, and stage.React.Reset (both dummies home, full health, every status gone)
	function S.rest()
		S.halt()
		local c = S.Caster
		if c and c.Parent and S.CP then
			pcall(S.CP.SetAim, c, nil)
			pcall(S.CP.SetBase, c, nil)
			pcall(S.CP.Stop, c)
			pcall(S.CP.SetStance, c, "Ready")
		end
		if c and c.Parent then
			S.still(c)
			if S.CasterHome then pcall(function() c:PivotTo(S.CasterHome) end) end
		end
		local t = S.Target
		if t and t.Parent then
			S.still(t)
			pcall(function() t:SetAttribute("SlipUntil", nil) end)
		end
		local R = S.React or (type(stage.React) == "table" and stage.React) or nil
		if R and type(R.Reset) == "function" then pcall(R.Reset, stage) end
	end

	----------------------------------------------------------------------------------------------------
	-- the stage
	----------------------------------------------------------------------------------------------------
	--- flat unit from the stage to the camera, read at each cast (the view the lead frames the stage in); the stage's
	--- LookVector when there is no camera to read
	function S.toCamera()
		local cam = workspace.CurrentCamera
		local v = cam and flat(cam.CFrame.Position - stage.CF.Position)
		if v and v.Magnitude > 2 then return v.Unit end
		local l = flat(stage.CF.LookVector)
		return l.Magnitude > 1e-3 and l.Unit or Vector3.zAxis
	end

	--- the caster's own shots pass through the caster (and the viewer's body)
	function S.exclude()
		local list = { S.Caster }
		local me = Players.LocalPlayer
		if me and me.Character then list[#list + 1] = me.Character end
		return list
	end

	--- the invisible wall the shots stop at, BACKSTOP_PAST studs past stage.Target (inside the floor slab, so the wave breaks
	--- on the stage, never pouring off its edge onto the room's floor): queried, never collided or touched
	function S.backstop()
		local face = S.Apart + BACKSTOP_PAST
		local fp = stage.FloorPart
		if typeof(fp) == "Instance" and fp:IsA("BasePart") then
			local cf, sz, R = fp.CFrame, fp.Size, S.Right
			local edge = (cf.Position - stage.Floor):Dot(R) + math.abs(cf.RightVector:Dot(R)) * sz.X / 2
				+ math.abs(cf.UpVector:Dot(R)) * sz.Y / 2 + math.abs(cf.LookVector:Dot(R)) * sz.Z / 2
			face = math.max(S.Apart + 1.2, math.min(face, edge - 0.3))
		end
		local p = Instance.new("Part")
		p.Name = "AquaAltarBackstop"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, true, false, false
		p.Transparency = 1
		p.Size = Vector3.new(2, 8, 14)                  -- 2 thick along the flight, from 0.2 to 8.2 over the floor, 14 across
		p.CFrame = CFrame.fromMatrix(stage.Floor + S.Right * (face + 1) + Vector3.new(0, 4.2, 0), S.Right, Vector3.yAxis)
		p.Parent = stage.Parent
		S.Parts[#S.Parts + 1] = p
	end

	--- drop the bookkeeping of what has already ended by itself
	local function prune()
		for c in pairs(S.Owned) do
			if not c.Parent then S.Owned[c], S.Keep[c] = nil, nil end
		end
		for _, list in ipairs({ S.Tides, S.Guns, S.Maws }) do
			for h, m in pairs(list) do
				if not (typeof(m) == "Instance" and m.Parent) then list[h] = nil end
			end
		end
		for _, list in ipairs({ S.Conns, S.Moves }) do
			for i = #list, 1, -1 do
				if not list[i].Connected then table.remove(list, i) end
			end
		end
	end

	--- cycle(t0) every `period` seconds until stopped, each from the rest; a cycle that errors is skipped, the loop goes on
	function S.loop(period, cycle)
		while S.Alive do
			local t0 = os.clock()
			S.Cycle += 1
			prune()
			S.rest()
			local ok, err = pcall(cycle, t0)
			if not ok then warnOnce("cycle" .. kind, kind .. " preview cycle failed: " .. tostring(err)) end
			if not S.sleepUntil(t0 + period) then return end
		end
	end

	local function stopNow()
		S.halt()
		for _, c in ipairs(S.Conns) do pcall(function() c:Disconnect() end) end
		table.clear(S.Conns)
		-- what can end itself: Twin Tide at once (its colliders and its look), the gun put away, the tank opened to drain
		for h in pairs(S.Tides) do pcall(h.Cancel) end
		for gun in pairs(S.Guns) do pcall(gun.Holster) end
		for h in pairs(S.Maws) do pcall(h.Cancel) end
		-- the rest now: every piece the calls made, and the splash pieces their steppers threw round the stage since
		-- (AquaFX and AquaWrapLux name all theirs AK_* / Aqua* / Lux*; nothing else in the folder is touched)
		local f = S.FXName and workspace:FindFirstChild(S.FXName)
		if f then
			local at = stage.CF.Position
			for _, c in ipairs(f:GetChildren()) do
				local n = c.Name
				if S.Owned[c] then
					if not S.Keep[c] then pcall(c.Destroy, c) end
				elseif c:IsA("BasePart") and (string.sub(n, 1, 3) == "AK_" or string.sub(n, 1, 4) == "Aqua" or string.sub(n, 1, 3) == "Lux")
					and (c.Position - at).Magnitude <= SWEEP then
					pcall(c.Destroy, c)
				end
			end
		end
		for _, p in ipairs(S.Parts) do pcall(p.Destroy, p) end
		table.clear(S.Parts)
		-- the dummies: the caster's pose let go, both home and clean
		S.rest()
		-- the gun and the tank: their own exit, then gone (only this preview's own pieces: a preview started meanwhile is
		-- never touched)
		task.delay(GRACE, function()
			for gun in pairs(S.Guns) do pcall(gun.Destroy) end
			for c in pairs(S.Owned) do
				if c.Parent then pcall(c.Destroy, c) end
			end
			table.clear(S.Owned) table.clear(S.Keep) table.clear(S.Guns) table.clear(S.Maws) table.clear(S.Tides)
		end)
	end

	--- stop(): safe any number of times, from anywhere; it never errors
	function S.stop()
		if S.Dead then return end
		S.Dead, S.Alive = true, false
		local ok, err = pcall(stopNow)
		if not ok then warnOnce("stop" .. kind, kind .. " stop failed: " .. tostring(err)) end
	end

	return S
end

--- fn(...) with AquaWrap.For answering this preview's palette for both dummies, for this one synchronous call.
--- AquaWrap.Install draws RidingSplash in the wrap of the body it splashes (W.For), and the dummies are nobody's
--- characters: they would always be Default.
local function asRider(S, fn, ...)
	local W = S.W
	if not (W and type(W.For) == "function") then return fn(...) end
	local real, a, b, P = W.For, S.Caster, S.Target, S.Ctx.P
	W.For = function(c)
		if c == a or c == b then return P end
		return real(c)
	end
	local ok, err = pcall(fn, ...)
	W.For = real
	if not ok then error(err, 0) end
end

----------------------------------------------------------------------------------------------------
-- the moves
----------------------------------------------------------------------------------------------------
-- M1: RIPTIDE. AquaRiptide as another client draws it: the palm thrust (IcicleShardR / L), and at its full extension the
-- wave from the caster's root, flat along the aim, on the floor. Two at the M1's own fastest rate, then a breath. At its
-- real speed (200 studs/s) the crest reaches the target in a few frames: its splash on the body, the recoil, the crash on
-- the backstop, the foam and the wet streak behind it are what stay on screen.
local function riptide(S)
	local R = S.A.Riptide or {}
	local gap = R.FireInterval or 0.667
	S.backstop()
	S.loop(PERIOD.Riptide, function(t0)
		for i, side in ipairs({ "R", "L" }) do
			local at = t0 + (i - 1) * gap
			if not S.sleepUntil(at) then return end
			local clip = "IcicleShard" .. side
			S.pose(clip)
			if not S.sleepUntil(at + S.beat(clip)) then return end
			local root = S.root(S.Caster)
			local origin = root and root.Position or S.CasterHome.Position
			-- (the shooter's own copy, Own: it finds the bodies it runs through; its OnHit only tells the target)
			S.call(S.FX.Riptide, {
				Origin = origin, Dir = S.Right, T0 = workspace:GetServerTimeNow(), Exclude = S.exclude(), Friendly = true,
				Own = true, OnHit = S.onTarget(function() S.hit({ Damage = R.Damage, From = origin }) end),
			})
		end
	end)
end

-- PRIMARY: UNDERTOW. AquaUndertow as another client draws it: the arms circling (CycloneForm) as the disc is drawn in
-- front of the caster's face -- on the server's frame (undertowFrame: DiscDistance along the aim from the eye, DiscDrop
-- under it, pitched at most MaxPitch) -- then at SnapTime AquaUndertowSnap's thrust (CycloneRelease) and the pull: the
-- target carried to the floor under the disc in PullTime with the pull's little hop, held, put back (AquaHandler's
-- range-dummy carry). Undertow does no damage (Undertow.Damage 0); the victim is interrupted, which has no look.
local function undertow(S)
	local U = S.A.Undertow or {}
	--- the server's frame: the eye, the look, the disc's centre, the floor under it (where the caught are pulled)
	local function discFrame()
		local c = S.Caster
		local head = c:FindFirstChild("Head")
		local root = S.root(c)
		local eye = head and head.Position or ((root and root.Position or S.CasterHome.Position) + Vector3.new(0, 1.5, 0))
		local aimPart = S.Target:FindFirstChild("Head") or S.root(S.Target)
		local look = S.Right
		if aimPart and (aimPart.Position - eye).Magnitude > 0.5 then look = (aimPart.Position - eye).Unit end
		local f = flat(look)
		f = f.Magnitude > 0.05 and f.Unit or S.Right
		local maxP = math.rad(U.MaxPitch or 30)
		local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -maxP, maxP)
		look = f * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
		local center = eye + look * (U.DiscDistance or 4.2) - Vector3.new(0, U.DiscDrop or 0.35, 0)
		return eye, look, center, Vector3.new(center.X, S.Stage.Floor.Y, center.Z)
	end
	--- the disc's facing, turned DISC_TURN about the vertical so its drawn face (the one toward -look, its caster's view)
	--- leans toward the camera; the true look when DISC_TURN is 0
	local function shown(look)
		if not DISC_TURN or DISC_TURN == 0 then return look end
		local toCam = S.toCamera()
		local best, score = look, -math.huge
		for _, sgn in ipairs({ 1, -1 }) do
			local v = CFrame.fromAxisAngle(Vector3.yAxis, sgn * math.rad(DISC_TURN)):VectorToWorldSpace(look)
			local s = (-v):Dot(toCam)
			if s > score then best, score = v, s end
		end
		return best
	end
	--- the pull: AquaHandler carryDummy's path for Undertow (flat to the floor under the disc, capped at PullMaxSpeed x
	--- PullTime, the hop PullLift x PullTime x sin), held PULL_HOLD, then home
	local function pull(to)
		local m = S.Target
		if not (m and m.Parent) then return end
		local home = m:GetPivot()
		local root = S.root(m)
		local off = flat(to - (root and root.Position or home.Position))
		local T = math.max(U.PullTime or 0.28, 0.05)
		local cap = (U.PullMaxSpeed or 125) * T
		if off.Magnitude > cap then off = off.Unit * cap end
		local hop = (U.PullLift or 6) * T
		S.move(T + PULL_HOLD, function(t)
			local k = math.min(t, T) / T
			m:PivotTo(home + off * k + Vector3.new(0, hop * math.sin(math.pi * k), 0))
		end, function()
			if m.Parent then m:PivotTo(home) end
		end)
	end
	S.loop(PERIOD.Undertow, function(t0)
		S.pose("CycloneForm")
		local at = t0 + S.beat("CycloneForm")
		if not S.sleepUntil(at) then return end
		local eye, look, center, pullTo = discFrame()
		S.call(S.FX.Undertow, center, shown(look), workspace:GetServerTimeNow(), true)
		-- the snap (AquaHandler: task.delay(SnapTime) after the cast)
		if not S.sleepUntil(at + (U.SnapTime or 0.6)) then return end
		S.pose("CycloneRelease")
		pull(pullTo)
		S.hit({ Damage = U.Damage, From = eye, NoRecoil = true })     -- (the pull carries it: no recoil on top)
	end)
end

-- TECHNIQUE: TWIN TIDE. AquaTwinTide as another client draws it: Bulwark Wall's raise (BulwarkWallRaise, let go 0.8 s on
-- if it is still playing), and the lane on the floor centred on the target, its axis the caster's aim (the server's
-- castTwinTide: flat(center - root)) -- the walls build up either side of it and crash in the middle. Real size (it has
-- no scale: the pose table and the crash flipbook are baked at 22 x 24 x 13). From the stage's side camera the near wall
-- stands between the camera and the lane while it closes. At CloseTime the server crushes whoever is on the line.
local function twinTide(S)
	local W = S.A.TwinTide or {}
	S.loop(PERIOD.TwinTide, function(t0)
		S.pose("BulwarkWallRaise")
		S.after(0.8, function()
			if S.CP.CurrentClip(S.Caster) == "BulwarkWallRaise" then S.CP.Stop(S.Caster) end
		end)
		local at = t0 + S.beat("BulwarkWallRaise")
		if not S.sleepUntil(at) then return end
		local center = S.targetFloor()
		local root = S.root(S.Caster)
		local axis = flat(center - (root and root.Position or S.CasterHome.Position))
		axis = axis.Magnitude > 1 and axis.Unit or S.Right
		local ok, h = S.call(S.FX.TwinTide, center, axis, workspace:GetServerTimeNow(), true)
		if ok and type(h) == "table" and type(h.Cancel) == "function" then S.Tides[h] = h.Model or false end
		if not S.sleepUntil(at + (W.CloseTime or 1.1)) then return end
		S.hit({ Damage = W.CrushDamage, From = center, Knock = Vector3.new(0, W.CrushLift or 30, 0) })
	end)
end

-- TECHNIQUE: SIDEARM. Another player's gun as every client draws it (AquaSidearmHold / AquaSidearm): the hold
-- (SidearmDraw), the gun at the right hand along the body's look, drawn at the clip's beat; the drawn shot DrawTime
-- later (a tap is that one shot) from the eye at the target, drawn from the muzzle, the kick; Linger, put away. The
-- bullet stops on the target's body and splashes there (each client's own copy does: no splash is broadcast); the
-- server's knock throws it KnockBack along the shot and sidearmKnockUp() up.
local function sidearm(S)
	local SA = S.A.Sidearm or {}
	local caster = S.Caster
	--- AquaClient's frame for another player's gun: at the right hand, along the body's look
	local function frame()
		local hand = caster:FindFirstChild("RightHand") or caster:FindFirstChild("Right Arm")
		local root = caster:FindFirstChild("HumanoidRootPart")
		if not (hand and root and caster.Parent) then return nil end
		return CFrame.lookAt(hand.Position, hand.Position + root.CFrame.LookVector)
	end
	--- AquaHandler's sidearmKnockUp: the speed up that keeps a body off the ground KnockAir s at this place's gravity
	local function knockUp()
		local g, h, air = workspace.Gravity, SA.KnockTime or 0.25, SA.KnockAir or 0.55
		if not (g > 0) then return 16 end
		if not (air > h) then return 0 end
		return g * (air - h) ^ 2 / (2 * air)
	end
	S.backstop()
	S.loop(PERIOD.Sidearm, function(t0)
		local scale = S.shotScale()
		S.pose("SidearmDraw")
		local at = t0 + S.beat("SidearmDraw")
		if not S.sleepUntil(at) then return end
		local ok, gun, new = S.call(S.FX.SidearmGun, frame, nil, true)
		if not (ok and type(gun) == "table") then return end
		local model = nil
		for _, c in ipairs(new) do
			if c.Name == "AquaSidearm" then model = c end
		end
		S.Guns[gun] = model or false
		if model then S.Keep[model] = true end
		if not S.sleepUntil(at + (SA.DrawTime or 0.14) / scale) then return end
		local head = caster:FindFirstChild("Head")
		local hold = frame()
		local eye = (head and head.Position) or (hold and hold.Position) or (S.CasterHome.Position + Vector3.new(0, 1.5, 0))
		local aimPart = S.Target:FindFirstChild("UpperTorso") or S.root(S.Target)
		local aim = aimPart and aimPart.Position or (S.targetFloor() + Vector3.new(0, 3, 0))
		local dir = aim - eye
		dir = dir.Magnitude > 0.1 and dir.Unit or S.Right
		local push = flat(dir)
		push = push.Magnitude > 0.1 and push.Unit or Vector3.zero
		local onHit = S.onTarget(function()
			S.hit({ Damage = SA.BulletDamage, From = eye,
				Knock = push * (SA.KnockBack or 38) + Vector3.new(0, knockUp(), 0) })
		end)
		S.call(function()
			local mz = gun.Muzzle()
			gun.Kick()
			if typeof(mz) ~= "Vector3" or (mz - eye).Magnitude > 12 then mz = nil end
			S.FX.FireSlug(eye, dir, 1, S.exclude(), mz, onHit)
		end)
		-- the key up: held out Linger after the shot, then put away (AquaClient's putAwayGun)
		if not S.sleepUntil(os.clock() + (SA.Linger or 0.35) / scale) then return end
		pcall(gun.Holster)
		if S.CP.CurrentClip(caster) == "SidearmDraw" then pcall(S.CP.Stop, caster) end
	end)
end

-- ULTIMATE: LEVIATHAN'S MAW. AquaMaw as another client draws it: Flash Freeze's slam (FlashFreeze) and the whole tank from
-- its server time on the floor aimed at the target, and the three beats the server sends in combat (AquaHandler.castMaw)
-- sent from here on its clock: one shark at CloseTime, its lunge on stage.Target at LungeTime, the bite at BiteTime.
local function maw(S)
	local M = S.A.Maw or {}
	S.loop((M.EndTime or 5.3) + 0.5, function(t0)
		S.pose("FlashFreeze")
		if not S.sleepUntil(t0 + S.beat("FlashFreeze")) then return end   -- (no Trigger: the handler draws on the cast)
		local center = S.targetFloor() - S.Right * MAW_SHORT
		local ok, h, new = false, nil, nil
		local r0 = M.Radius
		if MAW_RADIUS and r0 then M.Radius = MAW_RADIUS end
		pcall(function() ok, h, new = S.call(S.FX.Maw, center, workspace:GetServerTimeNow(), true) end)
		M.Radius = r0
		if not (ok and type(h) == "table") then return end
		local model = nil
		for _, c in ipairs(new or {}) do
			if c.Name == "AquaMaw" then model = c end
		end
		S.Maws[h] = model or false
		if model then S.Keep[model] = true end
		if not S.sleepUntil(t0 + (M.CloseTime or 1.2)) then return end
		S.call(h.SetSharks, 1)
		if not S.sleepUntil(t0 + (M.LungeTime or 3.75)) then return end
		local root = S.root(S.Target)
		S.call(h.LungeMany, { { Target = S.Target, Point = root and root.Position or S.targetFloor() } })
		if not S.sleepUntil(t0 + (M.BiteTime or 4.05)) then return end
		S.call(h.BiteMany, { S.Target })
		S.hit({ Damage = M.BiteDamage, From = center, Knock = Vector3.new(0, M.BiteLift or 40, 0) })
	end)
end

-- PASSIVE: RIDING THE CURRENT. Its visible half: wet ground (the flooded-lane tiles Riptide and Twin Tide leave), the
-- owner RIDING it -- faster (SprintSpeed x (1 + SpeedBonus)), the run's stride, foam at the planted feet at AquaClient's
-- cadence -- and an enemy on it SLIPPING (SlipUntil, low traction: momentum carries the body where it did not mean to go,
-- foam at its feet while it slides). The caster rides out toward the target, stands, rides back home; the target slips
-- as the rider comes. The anchored roots are given the velocity they are moved at, so CastPose strides the run and the
-- foam throws its drops back off it.
local function riding(S)
	local C, R = S.A.Current or {}, S.A.Riptide or {}
	local stage, caster = S.Stage, S.Caster
	local sprint = (Config and type(Config.Movement) == "table" and Config.Movement.SprintSpeed) or 22
	local speed = sprint * (1 + (C.SpeedBonus or 0.25))
	local len = math.max(2, 2 * S.Apart - RIDE_SHORT)
	local function splash(m)
		S.call(function() asRider(S, S.FX.RidingSplash, m) end)
	end
	--- the caster rides `len` studs from `from` along `dir` at the ridden pace, splashing every SPLASH_EVERY; onK(k) each
	--- frame. false the moment the preview stops
	local function ride(from, dir, onK)
		local root = S.root(caster)
		pcall(S.CP.SetStance, caster, "Sprint")
		local t0, dur, nextSplash = os.clock(), len / speed, 0
		while true do
			local k = math.clamp((os.clock() - t0) / dur, 0, 1)
			caster:PivotTo(from + dir * (len * k))
			if root then pcall(function() root.AssemblyLinearVelocity = dir * speed end) end
			if os.clock() >= nextSplash then
				nextSplash = os.clock() + SPLASH_EVERY
				splash(caster)
			end
			if onK then onK(k) end
			if k >= 1 then break end
			if not S.frame() then return false end
		end
		S.still(caster)
		pcall(S.CP.SetStance, caster, "Ready")
		return true
	end
	--- the target slips: slid SLIP_SKID toward the camera's side over SlipTime, easing out (the steer only bends it at
	--- Traction per second), rocking as it goes, foam at its feet while it moves; then it steps back
	local function slip()
		local m = S.Target
		if not (m and m.Parent) then return end
		local home = m:GetPivot()
		local root = S.root(m)
		local side = flat(stage.CF.LookVector)
		side = side.Magnitude > 1e-3 and side.Unit or Vector3.zAxis
		local T = C.SlipTime or 0.8
		pcall(function() m:SetAttribute("SlipUntil", workspace:GetServerTimeNow() + T) end)
		local nextSplash = 0
		S.move(T + SLIP_BACK, function(t)
			if t < T then
				local u = t / T
				local v = side * (2 * SLIP_SKID * (1 - u) / T)
				if root then root.AssemblyLinearVelocity = v end
				local wob = math.rad(SLIP_WOBBLE) * math.sin(t * 17) * (1 - u)
				m:PivotTo(CFrame.new(side * (SLIP_SKID * (1 - (1 - u) * (1 - u)))) * home * CFrame.Angles(0, 0, wob))
				if v.Magnitude > 2 and os.clock() >= nextSplash then
					nextSplash = os.clock() + SPLASH_EVERY
					splash(m)
				end
			else
				if root then root.AssemblyLinearVelocity = Vector3.zero end
				local u = math.clamp((t - T) / SLIP_BACK, 0, 1)
				m:PivotTo(CFrame.new(side * (SLIP_SKID * (1 - u * u * (3 - 2 * u)))) * home)
			end
		end, function()
			S.still(m)
			if m.Parent then m:PivotTo(home) end
			pcall(function() m:SetAttribute("SlipUntil", nil) end)
		end)
	end
	S.loop(PERIOD.Riding, function()
		local home = S.CasterHome
		local a = Vector3.new(home.Position.X, stage.Floor.Y, home.Position.Z)
		local b = S.targetFloor()
		S.call(S.FX.WetLane, (a + b) / 2, S.Right, R.TrailWidth or 6, (b - a).Magnitude + 2, C.WetLife or 3)
		local slipping = false
		if not ride(home, S.Right, function(k)
			if not slipping and k >= 0.55 then
				slipping = true
				slip()
			end
		end) then return end
		if not S.sleepUntil(os.clock() + RIDE_PAUSE) then return end
		local turned = CFrame.new(home.Position + S.Right * len) * (home.Rotation * CFrame.Angles(0, math.pi, 0))
		if not ride(turned, -S.Right) then return end
		caster:PivotTo(home)
	end)
end

--- Play(stage) for one move: the session, its loop on a thread of its own (the first cast starts before Play returns),
--- and the stop
local function play(kind, body)
	return function(stage)
		local S = session(stage, kind)
		task.spawn(function()
			local ok, err = pcall(function()
				if S.load() then body(S) end
			end)
			if not ok then warnOnce("play" .. kind, kind .. ": " .. tostring(err)) end
		end)
		return S.stop
	end
end

return {
	Element = "Aqua",
	Moves = {
		{ Key = "Riptide", Slot = "M1", Play = play("Riptide", riptide),
		  Name = nameOf("Riptide", function(C) return C.Elements.Aqua.M1.Name end) },
		{ Key = "Undertow", Slot = "Primary", Play = play("Undertow", undertow),
		  Name = nameOf("Undertow", function(C) return C.Elements.Aqua.Primary.Name end) },
		{ Key = "TwinTide", Slot = "Mobility", Play = play("TwinTide", twinTide),
		  Name = nameOf("Twin Tide", function(C) return C.Technique("TwinTide").Name end) },
		{ Key = "Sidearm", Slot = "Defense", Play = play("Sidearm", sidearm),
		  Name = nameOf("Sidearm", function(C) return C.Technique("Sidearm").Name end) },
		{ Key = "LeviathansMaw", Slot = "Ultimate", Play = play("LeviathansMaw", maw),
		  Name = nameOf("Leviathan's Maw", function(C) return C.Ultimate.LeviathansMaw.Name end) },
		{ Key = "RidingTheCurrent", Slot = "Passive", Play = play("RidingTheCurrent", riding),
		  Name = nameOf("Riding the Current", function(C) return C.Elements.Aqua.Passive.Name end) },
	},
}
