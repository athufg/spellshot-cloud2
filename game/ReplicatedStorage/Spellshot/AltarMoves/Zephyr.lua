--[[
	AltarMoves_Zephyr  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Zephyr

	The Loadout Showcase's PREVIEW MOVES for Zephyr, AltarMoves contract v2 (2026-10-26, the owner: the caster PERFORMS
	each move for real on the stage's visible target, which takes the hit the way a duel shows it, looping). AltarShowcase
	builds the stage before Play (stage.CF / Floor / FloorPart / Caster / Target / Parent / Wrap / React: AltarStage's
	two mannequins) and calls Moves[i].Play(stage) -> stop(). The caster wears the game's own third-person cast poses
	(IceMagic.CastPose, the very instance AbilityFX drives) and fires each move's real VFX on its clip's release beat, with
	the calls and payloads the game's broadcasts use -- AbilityFX's inline Zephyr handlers (Wind Blade, Cross-Slash,
	Cyclone: their few lines of glue repeated here) and ZephyrClient.Handlers (Skyrider, Gust Pad, Updraft: called
	straight) -- aimed at the target. The target answers through stage.React with the server's own numbers (ZephyrFX /
	ZephyrSkyrider / ZephyrGustPad / ZephyrUpdraft Tuning, read live). Client only: no remotes, nothing sent. Zephyr has
	NO WRAPS (SkinCatalog.ElementWraps has no Zephyr row, and no Zephyr draw module has a wrap hook), so stage.Wrap is not
	read: every move draws Default (a wrap id other than "Default" is warned about once).

	  WIND BLADE        a burst of 6 at the kit's 8 a second, R / L alternating, each hand Down, Up ... (SpellshotInput's
	                    order). Per shot AbilityFX's WindBlade handler: the flick clip (Solo, then chained inside the last
	                    shot's HoldUntil), the swirl winding into that palm, a Trigger later the blade from the Head down
	                    the aim at the target's chest, eased off the hand. Its own sweep cuts the target (the cut line,
	                    the impact ring, the debris); as its flight reaches the chest, React.Hit with WindBlade.Damage
	                    (3; Wind Blade pushes nothing)
	  CROSS-SLASH DASH  a tap, booked as SpellshotInput books one: the press (ZephyrFX.CrossSlash with the target to stamp
	                    the X on, CastPose CrossSlashDash on the cast's own clock), the launch at ChargeTime
	                    (CrossSlashLaunch), the glide -- MinDistance at the glide's pace, the caster carried along it
	                    every frame (DashMotor's straight run), stopping just short of the target -- and at the Trigger
	                    the X on the target's chest: React.Hit, CrossSlash.Damage (30; no push)
	  SKYRIDER          SkyriderStart (the bird gathers, SkyriderMount): the caster lifted onto it over SummonTime, then
	                    drifting slowly at the target; SkyriderGust (the flap, SkyriderGust) aimed from the bird's chest
	                    at the target; the server's launch and cone front (ConeTau): SkyriderGustHit on the target and
	                    React.Hit, Gust.Damage 12, knocked KnockOut 55 out / KnockUp 20 up; SkyriderEnd (the dismount:
	                    the bird breaks into wisps, SkyriderFall) and the drop to the floor
	  GUST PAD          GustPad pressed under the target's feet (the caster's kneeling press, the pad's bloom); armed,
	                    the target is on it: GustPadStep (the coil -- the target wears GustPadLaunch, as a player does),
	                    the launch Coil later: GustPadLaunch (the column) and React.Knock straight up at LaunchSpeed() (a
	                    launch is not a hit: no damage); GustPadEnd before the next loop
	  CYCLONE           AbilityFX's three beats on the caster (CycloneForm's circling arms on the loop clock, touchdown's
	                    CycloneRelease, the unwind) on the ground under the target. From touchdown the target is caught
	                    and moved by the server's own rule for a dummy (ZephyrFX.CyclonePullVelocity: in, round and up);
	                    every tick React.Hit, Cyclone.Damage 6, held in place (NoRecoil), with the look's juggle pulse and
	                    sparks on it (ZephyrFX_Cyclone.Pulse); at the end it is let go (ReleaseSpeed, under gravity)
	  UPDRAFT           the showcase's jump on the caster: CastPose UpdraftJump on the hero clock, the body carried along
	                    updraft_bl's own arc (V0 / Air / Drift / the root's yaw keys, ZephyrUpdraft.Tuning.Tell.Demo),
	                    the LIVE tell reading it (ZephyrUpdraft's airborne watcher, put on the caster through Demo's Jump
	                    path); at THE FLICK a Wind Blade from the right hand into the target, and on the hit the server's
	                    UpdraftHit (the pulse up the helix, the mark on the victim) and React.Hit, WindBlade.Damage x
	                    Updraft's DamageMult (3 x 1.25)

	Every Play returns at once (its preview runs on its own thread) and loops the whole cast -> hit beat until stop(), with
	stage.React.Reset, both dummies' facings put back and the caster on its rest stance between loops. stop() ends the
	loop and every timer and frame step, takes each look down (an instant end where the look offers one, else its own
	short unwind: a Gust Pad's 0.4 s, the Updraft tell's landing thin), lets go of the caster's clips (CastPose Stop /
	SetBase nil / SetAim nil) and of the target's (Gust Pad's, CastPose.Release), and puts both dummies home
	(React.Reset); safe twice, and the stage folder going away calls it too. A missing or failing module costs only its
	own preview (one warning). With no Caster / Target on the stage (the showcase's idle-M1 path never calls
	AltarStage.Pair), a preview stands its own pair up through stage.React.Pair and clears it on stop.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UP = Vector3.yAxis
local ZERO = Vector3.zero

-- EVERY NUMBER HERE IS A PROPOSAL: the loops' lengths and the staging are the preview's; every look, hit and knock number
-- is read from its own module at run time
local Tuning = {
	WindBlade = { Shots = 6, Rate = 0.125, Period = 2.8 },   -- a burst at the kit's 8 a second (the row's FireInterval
	                                                          --   0.12), then the guard eases down and a beat of air
	CrossSlash = {
		Period = 3.6,          -- the look plays ~3.4 s (ZephyrFX_CrossSlash's Beats.End, 3.35 kit s)
		Distance = nil,        -- studs; nil = a tap (CrossSlash.MinDistance, 12): the glide stops ~2 studs short of the
		                       --   target and the X lands on its chest. A longer one is booked as that much held charge
	},
	Skyrider = {
		Period = 4.2, GustAt = 1.1, EndAt = 2.5,   -- s from the press: the flap, the dismount (its wisps ~1 s, the fall)
		Clearance = nil,       -- studs, the bird's back over the floor; nil = the ride's floor rule (Skyrider MinClearance,
		                       --   6) -- the cruise's 9 lifts the rider past the top of the altar's frame
		Drift = 3,             -- studs/s the ride drifts at the target once summoned (the ride's 60 would leave the dais in a
		                       --   quarter second); under 4, so the bird still heads the way the root faces
		LiftFrom = 0.32,       -- share of SummonTime the lift waits (CastPose SkyriderMount's CROUCH key, 0.14 of 0.44)
	},
	GustPad = { Period = 3.4, EndAt = 2.6 },   -- s from the press: the pad's end (its own 0.4 s unwind follows)
	Cyclone = {
		Period = 4.5,
		Hold = 1.9,            -- s it stands after touchdown (the game's ActiveTime 4, cut): ticks at 0.25, 0.75, 1.25, 1.75
		Seed = 0.4,            -- the caught body's bob phase (the server draws one in 0 .. JugglePeriod)
	},
	Updraft = { Period = 3.6, Rise = 1 },      -- Rise: share of the hero arc's height (1 = updraft_bl's 7-stud apex)
	Floor = Vector3.new(30, 1, 14),            -- the stand-in landing slab (only when stage.FloorPart does not collide)
	FramePriority = Enum.RenderPriority.Camera.Value + 8,   -- the bodies are moved after the camera, before CastPose
	                                                        --   (Character + 1) and ZephyrDraw (Character + 3) sample them
}

----------------------------------------------------------------------------------------------------
-- the kit's names (SpellshotConfig's display names; the Keys are the abilities' VFXLibrary row Ids)
----------------------------------------------------------------------------------------------------
local NAMES = {}
do
	local ok, Config = pcall(function()
		local sp = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = sp and sp:FindFirstChild("SpellshotConfig")
		return m and require(m)
	end)
	if ok and type(Config) == "table" then
		local el = Config.Elements and Config.Elements.Zephyr
		local function entry(pool, key) return type(pool) == "table" and type(pool[key]) == "table" and pool[key].Name end
		NAMES.WindBlade = el and entry(el, "M1")
		NAMES.CrossSlashDash = el and entry(el, "Primary")
		NAMES.Updraft = el and entry(el, "Passive")
		NAMES.Skyrider = entry(Config.Mobility, "Skyrider")
		NAMES.GustPad = entry(Config.Defense, "GustPad")
		NAMES.Cyclone = entry(Config.Ultimate, "Cyclone")
	end
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Zephyr] " .. msg)
end

local mods = {}
--- IceMagic.<name>, required once; nil while it is not in the place (looked for again next time), and for good once it
--- failed to load. May wait up to 5 s for a module still replicating: only ever called on a preview's own thread, never
--- from stop() (which reads only what is cached).
local function need(name)
	local m = mods[name]
	if m ~= nil then return m or nil end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic") or ReplicatedStorage:WaitForChild("IceMagic", 5)
	local inst = ice and (ice:FindFirstChild(name) or ice:WaitForChild(name, 5))
	if not inst then
		warnOnce("missing" .. name, "IceMagic." .. name .. " is not in the place - its part of the preview is skipped")
		return nil
	end
	local ok, mod = pcall(require, inst)
	mods[name] = (ok and type(mod) == "table") and mod or false
	if not mods[name] then warnOnce("load" .. name, name .. " failed to load: " .. tostring(mod)) end
	return mods[name] or nil
end
--- the same module if it is already loaded, else nil -- never waits (the stop path)
local function cached(name)
	return mods[name] or nil
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

--- VFXLibrary.ShotTimeScale's read (the filming slow-down): the casts' own beats are divided by it, as AbilityFX's are.
local function timeScale()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local v = ice and ice:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function smooth(u)
	u = clamp01(u)
	return u * u * (3 - 2 * u)
end
--- `v` along the ground, as a unit vector (nil when it has no length there)
local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return (f.Magnitude > 1e-3) and f.Unit or nil
end

local function partOf(model, name)
	local p = model and model:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end
local function rootOf(model)
	return partOf(model, "HumanoidRootPart")
end
local function handOf(model, side)
	return partOf(model, side == "L" and "LeftHand" or "RightHand")
end
local function chestOf(model)
	local p = partOf(model, "UpperTorso") or rootOf(model)
	return p and p.Position or nil
end

--- Where a dummy stands at rest: AltarStage's AltarHome (the spot it was stood on), in the facing it has now.
local function homeOf(model)
	local p = model:GetPivot()
	local h = model:GetAttribute("AltarHome")
	return (typeof(h) == "Vector3") and (p.Rotation + h) or p
end

--- The body clip (CastPose, the IceMagic instance AbilityFX drives), as the ability's broadcast plays it; `clock` for a
--- clocked clip. Guarded.
local function pose(model, clip, clock)
	local CP = need("CastPose")
	if not (CP and model) then return end
	local ok, err
	if clock then
		ok, err = pcall(CP.PlayClocked, model, clip, clock)
	else
		ok, err = pcall(CP.Play, model, clip)
	end
	if not ok then warnOnce("pose" .. clip, "CastPose " .. clip .. ": " .. tostring(err)) end
end

--- The caster back on its rest stance: its clip let go (CastPose.Stop), no base to rest on, no aim.
local function rest(model)
	local CP = cached("CastPose")
	if not (CP and model) then return end
	pcall(CP.Stop, model)
	pcall(CP.SetBase, model, nil)
	pcall(CP.SetAim, model, nil)
end

--- stage.React.<fn>(stage, ...), guarded.
local function react(stage, fn, ...)
	local R = stage.React
	local f = type(R) == "table" and R[fn]
	if type(f) ~= "function" then return end
	local ok, err = pcall(f, stage, ...)
	if not ok then warnOnce("react" .. fn, "React." .. fn .. ": " .. tostring(err)) end
end

--- A Zephyr broadcast as AbilityFX dispatches it: ZephyrClient.Handlers[kind] (the three pieces merged, each guarded),
--- else `piece`'s own Handlers[kind]. `quick`: from cached modules only (the stop path never waits). One warning when the
--- kind has no handler or it fails.
local function broadcast(piece, kind, data, quick)
	local get = quick and cached or need
	local ZC = get("ZephyrClient")
	local fn = ZC and type(ZC.Handlers) == "table" and ZC.Handlers[kind]
	if type(fn) ~= "function" then
		local P = get(piece)
		fn = P and type(P.Handlers) == "table" and P.Handlers[kind]
	end
	if type(fn) ~= "function" then
		if not quick then warnOnce("kind" .. kind, "no handler for " .. kind .. " - that beat is skipped") end
		return
	end
	local ok, err = pcall(fn, data)
	if not ok then warnOnce("handler" .. kind, kind .. ": " .. tostring(err)) end
end

--- What a preview blade must never touch: the caster, and every real player's body (a passer-by on the line).
local function shotExclude(stage)
	local list = { stage.Caster }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list + 1] = p.Character end
	end
	return list
end

--- The aim from `from` at the target's chest (the eye line a shooter's crosshair puts on it), and that chest.
local function aimAt(stage, from)
	local chest = chestOf(stage.Target)
	local d = chest and (chest - from)
	if d and d.Magnitude > 1e-3 then return d.Unit, chest end
	return stage.CF.RightVector, chest
end

----------------------------------------------------------------------------------------------------
-- the run: one preview's loop, beats, frame steps and clean-ups
----------------------------------------------------------------------------------------------------
--- A preview's life, ended once by Stop (safe twice; the stage folder going away calls it too). Defer(fn) keeps a
--- clean-up, run newest first on Stop (at once when it has already stopped: a setup that waited past a stop). Beat
--- counts the loops: a timer or a frame step from an older loop never runs into the next one.
local stepSeq = 0
local function newRun(stage, name)
	local run = { Dead = false, Name = name, Undo = {}, Beat = 0, Steps = {}, Home = nil }
	function run.Defer(fn)
		if run.Dead then
			pcall(fn)
		else
			table.insert(run.Undo, fn)
		end
	end
	local function unbind(id)
		if not run.Steps[id] then return end
		run.Steps[id] = nil
		pcall(RunService.UnbindFromRenderStep, RunService, id)
	end
	--- fn(dt) every frame (a render step at FramePriority) for this loop, until it returns false, the loop moves on or
	--- the run ends. A failing step is one warning and ends itself.
	function run.Frame(fn)
		if run.Dead then return end
		stepSeq += 1
		local id = "AltarMovesZephyr" .. stepSeq
		local beat = run.Beat
		run.Steps[id] = true
		local ok, err = pcall(RunService.BindToRenderStep, RunService, id, Tuning.FramePriority, function(dt)
			if run.Dead or run.Beat ~= beat then
				unbind(id)
				return
			end
			local ok2, res = pcall(fn, dt)
			if not ok2 then
				warnOnce("frame" .. name, name .. " frame: " .. tostring(res))
				unbind(id)
			elseif res == false then
				unbind(id)
			end
		end)
		if not ok then
			run.Steps[id] = nil
			warnOnce("bind" .. name, name .. ": no frame step: " .. tostring(err))
		end
	end
	function run.Stop()
		if run.Dead then return end
		run.Dead = true
		run.Beat += 1
		if run.Conn then run.Conn:Disconnect() end
		for id in pairs(run.Steps) do pcall(RunService.UnbindFromRenderStep, RunService, id) end
		table.clear(run.Steps)
		for i = #run.Undo, 1, -1 do
			local ok, err = pcall(run.Undo[i])
			if not ok then warnOnce("stop" .. name, name .. " stop: " .. tostring(err)) end
		end
		table.clear(run.Undo)
	end
	if typeof(stage.Parent) == "Instance" then run.Conn = stage.Parent.Destroying:Connect(run.Stop) end
	return run
end

--- fn() `delay` real seconds from now, unless the run has ended or moved on to its next loop by then (guarded: a failing
--- beat is one warning).
local function after(run, delay, fn)
	local beat = run.Beat
	task.delay(math.max(0, delay), function()
		if run.Dead or run.Beat ~= beat then return end
		local ok, err = pcall(fn)
		if not ok then warnOnce("beat" .. run.Name, run.Name .. ": " .. tostring(err)) end
	end)
end

--- Both dummies as they started: React.Reset (home, full health, every status cleared), the facings they were given put
--- back, the caster on its rest stance and its root still. Between loops and on stop.
local function settle(stage, run)
	react(stage, "Reset")
	local caster, target = stage.Caster, stage.Target
	rest(caster)
	local home = run.Home
	if home then
		if caster and caster.Parent then pcall(caster.PivotTo, caster, home.Caster) end
		if target and target.Parent then pcall(target.PivotTo, target, home.Target) end
	end
	local root = rootOf(caster)
	if root then root.AssemblyLinearVelocity = ZERO end
end

--- beat() now, then every `period` real seconds -- settled first each time -- until the run ends or a dummy is gone.
local function loop(run, stage, period, beat)
	while not run.Dead do
		if not (stage.Caster and stage.Caster.Parent and stage.Target and stage.Target.Parent) then
			run.Stop()
			return
		end
		run.Beat += 1
		settle(stage, run)
		local t0 = os.clock()
		local ok, err = pcall(beat)
		if not ok then warnOnce("loop" .. run.Name, run.Name .. ": " .. tostring(err)) end
		while not run.Dead and os.clock() - t0 < period do task.wait(0.05) end
	end
end

--- The stage's caster and target (v2); the v1 name stage.Key is taken for the caster. With neither (the showcase's
--- idle-M1 path never stands a pair up), a pair of the preview's own through stage.React.Pair -- read through a view of
--- the stage, so the showcase's table is never written -- and the clean-up that clears it.
local function withPair(stage)
	local caster, target = stage.Caster or stage.Key, stage.Target
	if typeof(caster) == "Instance" and typeof(target) == "Instance" then
		if stage.Caster == caster then return stage, nil end
		return setmetatable({ Caster = caster }, { __index = stage }), nil
	end
	local React = stage.React
	if type(React) ~= "table" then
		local ok, mod = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("AltarStage", 5))
		end)
		React = (ok and type(mod) == "table") and mod or nil
	end
	if not (React and type(React.Pair) == "function" and typeof(stage.CF) == "CFrame" and typeof(stage.Floor) == "Vector3") then
		return nil, nil
	end
	local ok, c, t = pcall(React.Pair, stage)
	if not (ok and c and t) then
		if ok then
			if c then c:Destroy() end
			if t then t:Destroy() end
		end
		return nil, nil
	end
	local view = setmetatable({ Caster = c, Key = c, Target = t, React = React }, { __index = stage })
	return view, function()
		if type(React.Clear) == "function" then pcall(React.Clear, view) end
	end
end

--- A move's Play: its preview starts on its own thread (it runs at once, up to its first wait) and its stop comes back.
--- Never errors into the caller: a failing start returns a stop that does nothing.
local function preview(name, setup)
	local function start(stage0)
		local run = newRun(type(stage0) == "table" and stage0 or {}, name)
		if type(stage0) ~= "table" then
			run.Stop()
			return run.Stop
		end
		task.spawn(function()
			local ok, err = pcall(function()
				if run.Dead then return end
				if stage0.Wrap ~= nil and stage0.Wrap ~= "Default" then
					warnOnce("wrap", "Zephyr has no wraps - '" .. tostring(stage0.Wrap) .. "' is shown as Default")
				end
				local stage, clearPair = withPair(stage0)
				if clearPair then run.Defer(clearPair) end
				if not stage then
					warnOnce("stage" .. name, name .. ": the stage has no caster / target, and none could be stood up")
					run.Stop()
					return
				end
				if run.Dead then return end
				run.Home = { Caster = homeOf(stage.Caster), Target = homeOf(stage.Target) }
				run.Defer(function() settle(stage, run) end)
				setup(stage, run)
			end)
			if not ok then warnOnce("play" .. name, name .. " preview: " .. tostring(err)) end
		end)
		return function()
			local ok, err = pcall(run.Stop)
			if not ok then warnOnce("stop" .. name, name .. " stop: " .. tostring(err)) end
		end
	end
	return function(stage)
		local ok, stop = pcall(start, stage)
		if ok and type(stop) == "function" then return stop end
		warnOnce("start" .. name, name .. " could not start: " .. tostring(stop))
		return function() end
	end
end

--- The dais the caster lands on: the watchers that see a landing (Updraft's floor cast, Skyrider's dismount ray) only
--- count what a foot can stand on (RespectCanCollide). stage.FloorPart (the chamber's StageTop) does; a stand-in slab,
--- invisible, at the floor's height, only when it does not.
local function landingFloor(stage, run)
	local fp = stage.FloorPart
	if typeof(fp) == "Instance" and fp:IsA("BasePart") and fp.CanCollide and fp.CanQuery then return end
	local p = Instance.new("Part")
	p.Name = "AltarZephyrFloor"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, true, false, false
	p.Transparency, p.Size = 1, Tuning.Floor
	p.CFrame = stage.CF.Rotation + (stage.Floor - UP * (Tuning.Floor.Y * 0.5))
	p.Parent = stage.Parent
	run.Defer(function() p:Destroy() end)
end

----------------------------------------------------------------------------------------------------
-- one Wind Blade (the M1's, and Updraft's flick)
----------------------------------------------------------------------------------------------------
local shotAt = setmetatable({}, { __mode = "k" })   -- [caster] = os.clock() of its last Wind Blade (AbilityFX's windShotAt)

--- One Wind Blade as AbilityFX's WindBlade handler plays somebody else's, from `side`'s hand stroking `stroke`: the body's
--- flick (chained into the last shot inside the clip's HoldUntil, else Solo) unless opts.NoClip, the swirl winding into
--- that palm, a Trigger later the blade from the Head down the aim at the target's chest, eased off the hand
--- (visualFrom). As its flight reaches the chest (Speed x ShotTimeScale: the server's own timing check) the target takes
--- it -- React.Hit with opts.Damage (default WindBlade.Damage) -- and opts.OnHit(origin) runs.
local function windBlade(run, stage, side, stroke, opts)
	local ZFX = need("ZephyrFX")
	if not ZFX then return end
	opts = opts or {}
	local caster = stage.Caster
	local WB = ZFX.Tuning.WindBlade
	if not opts.NoClip then
		local CP = need("CastPose")
		local now = os.clock()
		local last = shotAt[caster]
		shotAt[caster] = now
		local clip = CP and type(CP.Clips) == "table" and CP.Clips.WindBladeDownR
		local hold = (clip and clip.HoldUntil) or 1.05
		local chained = last ~= nil and (now - last) * timeScale() < hold
		pose(caster, "WindBlade" .. stroke .. side .. (chained and "" or "Solo"))
	end
	local head = partOf(caster, "Head")
	local dir0 = aimAt(stage, head and head.Position or caster:GetPivot().Position)
	local hand = handOf(caster, side)
	if hand then pcall(ZFX.WindBladeSwirl, hand, side, stroke, dir0) end
	after(run, (WB.Trigger or 0.06) / timeScale(), function()
		local h = handOf(caster, side)
		local hd = partOf(caster, "Head")
		local origin = (hd and hd.Position) or (h and h.Position)
		if not origin then return end
		local dir, chest = aimAt(stage, origin)
		ZFX.FireWindBlade(origin, dir, shotExclude(stage), (hd and h) and h.Position or nil, nil, side, stroke)
		local along = chest and math.max(0, (chest - origin):Dot(dir)) or 0
		after(run, along / ((WB.Speed or 200) * timeScale()), function()
			react(stage, "Hit", { Damage = opts.Damage or WB.Damage, From = origin })
			if opts.OnHit then opts.OnHit(origin) end
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- M1: WIND BLADE
----------------------------------------------------------------------------------------------------
-- A burst from the caster's hands, alternating R / L from the right, each hand's strokes Down, Up, Down ... (SpellshotInput's
-- order); the first slash of a burst is the Solo clip (nothing to chain from), the rest chain, as AbilityFX picks them.
local function playWindBlade(stage, run)
	if not need("ZephyrFX") or run.Dead then return end
	local W = Tuning.WindBlade
	loop(run, stage, W.Period, function()
		local strokes = { R = "Down", L = "Down" }
		local scale = timeScale()
		for j = 0, W.Shots - 1 do
			local side = (j % 2 == 0) and "R" or "L"
			local stroke = strokes[side]
			strokes[side] = (stroke == "Down") and "Up" or "Down"
			after(run, j * W.Rate / scale, function() windBlade(run, stage, side, stroke) end)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: CROSS-SLASH DASH
----------------------------------------------------------------------------------------------------
-- The two broadcasts' calls (AbilityFX's CrossSlashCharge / CrossSlashDash), on a cast booked as SpellshotInput books it:
-- the press starts the cast's clock (its look and the body clip both run on it); the release sets the distance from the
-- hold (a tap: MinDistance) and launches no sooner than ChargeTime; the glide lasts the distance at the glide's pace, the
-- body carried along it in a straight line (DashMotor's run: the root anchored, moved every frame); the strike is the
-- moment the look's clock passes the Trigger (SpellshotInput's crossSlashStrike), and the server's damage lands on it.
local function playCrossSlash(stage, run)
	local ZFX = need("ZephyrFX")
	local CS = need("ZephyrFX_CrossSlash")
	if not ZFX or run.Dead then return end
	local caster, target = stage.Caster, stage.Target
	run.Defer(function()
		if CS and type(CS.Stop) == "function" then pcall(CS.Stop, caster) end   -- the look gone at once
	end)
	loop(run, stage, Tuning.CrossSlash.Period, function()
		if CS and type(CS.Stop) == "function" then pcall(CS.Stop, caster) end
		local S = ZFX.Tuning.CrossSlash
		local scale = timeScale()
		local home = run.Home.Caster
		local dir = flat(run.Home.Target.Position - home.Position) or flat(stage.CF.RightVector) or Vector3.xAxis
		local dist = math.clamp(Tuning.CrossSlash.Distance or S.MinDistance, S.MinDistance, S.MaxDistance)
		-- the hold that charges that distance (the caster's rule, read backwards: a tap's is 0)
		local span = S.MaxDistance - S.MinDistance
		local held = (span > 0) and (dist - S.MinDistance) / span * S.FullChargeTime or 0
		local pace = S.DashDistance / S.DashTime
		-- THE PRESS (CrossSlashCharge): the cast's clock and record, the look (its X stamped on the target), the body
		local timing = ZFX.CrossSlashTiming()
		ZFX.CrossSlash(caster, nil, { Timing = timing, Target = target })
		pose(caster, "CrossSlashDash", ZFX.CrossSlashClock(caster))
		-- THE LAUNCH (CrossSlashDash): a tap at ChargeTime, a hold once the wind-up has played the beat it was held on out
		local launchIn = math.max(S.ChargeTime, held * scale + (S.ChargeTime - S.HoldPose)) / scale
		after(run, launchIn, function()
			timing.LaunchAt = (os.clock() - timing.Start) * scale
			timing.Glide = dist / pace * scale
			ZFX.CrossSlashLaunch(caster, dir)
			pose(caster, "CrossSlashDash", ZFX.CrossSlashClock(caster))
			-- the glide: the whole distance at the glide's pace, straight along the dash
			local from = caster:GetPivot()
			local t0, glide = os.clock(), dist / pace
			run.Frame(function()
				local u = clamp01((os.clock() - t0) / glide)
				caster:PivotTo(from + dir * (dist * u))
				return u < 1
			end)
		end)
		-- THE STRIKE: the arms fling open, the X stamps, and the target takes the cut
		run.Frame(function()
			if not timing.LaunchAt or ZFX.CrossSlashTime(timing) < S.Trigger then return true end
			local root = rootOf(caster)
			react(stage, "Hit", { Damage = S.Damage, From = root and root.Position or nil })
			return false
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- MOBILITY: SKYRIDER
----------------------------------------------------------------------------------------------------
-- The broadcasts every client hears (ZephyrSkyrider.Handlers through ZephyrClient: the bird and the rider's clips), and
-- the rider's motor done here, since a dummy has no client of its own to fly it: the summon lifts the root to the ride
-- height over SummonTime, then the ride drifts at the target; the root's velocity is set to its real motion every frame,
-- which the bird reads for its heading and pitch, as it reads a replicated rider's. The flap: SkyriderGust aimed from the
-- bird's chest (the cone's apex, the server's ApexAhead / ApexUp) at the target, then the server's launch -- the cone from
-- the root as it is then, the front reaching the target ConeTau later -- SkyriderGustHit and the knock. The dismount:
-- SkyriderEnd (wisps, the fall clip that holds until the landing ray finds the dais) and the drop, DropKeep of the drift.
local function playSkyrider(stage, run)
	local SR = need("ZephyrSkyrider")
	if not (SR and type(SR.Tuning) == "table") or run.Dead then return end
	local FX = need("ZephyrFX_Skyrider")
	need("ZephyrClient")
	if run.Dead then return end
	local caster, target = stage.Caster, stage.Target
	local K, Tu = Tuning.Skyrider, SR.Tuning
	local G = type(Tu.Gust) == "table" and Tu.Gust or {}
	local below = Tu.SeatBelowRoot or 2.4
	local summon = Tu.SummonTime or 0.44
	landingFloor(stage, run)
	run.Defer(function()
		if FX and type(FX.Stop) == "function" then pcall(FX.Stop, caster) end   -- the bird gone at once
	end)
	--- the cone's apex: the drawn bird's chest, ahead of the seat along the flight (the root's velocity along the ground,
	--- its look when slow) -- ZephyrSkyriderServer's launch
	local function apexOf(root, fallback)
		local v = root.AssemblyLinearVelocity
		local heading = (Vector3.new(v.X, 0, v.Z).Magnitude > 4) and flat(v) or flat(root.CFrame.LookVector)
		heading = heading or fallback
		return root.Position + UP * ((G.ApexUp or -0.5) - below) + heading * (G.ApexAhead or 4.8)
	end
	loop(run, stage, K.Period, function()
		if FX and type(FX.Stop) == "function" then pcall(FX.Stop, caster) end    -- the last loop's wisps, if any
		local home = run.Home.Caster
		local R = flat(run.Home.Target.Position - home.Position) or flat(stage.CF.RightVector) or Vector3.xAxis
		local standY = home.Position.Y
		local rideY = stage.Floor.Y + (K.Clearance or Tu.MinClearance or 6) + below
		local g = math.max(workspace.Gravity, 1)
		local ride = { X = 0, Y = standY, Vy = 0, Drop = false }
		-- THE PRESS (SkyriderStart): the bird gathers out of the air under the root, the rider hops on and kneels
		broadcast("ZephyrSkyrider", "SkyriderStart", { Caster = caster, T0 = serverNow() })
		-- THE MOTOR: the summon's lift, the ride's drift, and after the dismount the drop
		local t0 = os.clock()
		local last = home.Position
		run.Frame(function(dt)
			local root = rootOf(caster)
			if not root then return false end
			local t = os.clock() - t0
			local vx = 0
			if ride.Drop then
				vx = K.Drift * (Tu.DropKeep or 0.6)
				ride.Vy -= g * dt
				ride.Y += ride.Vy * dt
			else
				-- lifted from the mount clip's crouch (its first 0.14 of 0.44) to the tuck, as the bird comes under
				ride.Y = standY + (rideY - standY) * smooth((t - summon * K.LiftFrom) / (summon * (1 - K.LiftFrom)))
				if t > summon then vx = K.Drift end
			end
			local landed = ride.Drop and ride.Y <= standY
			if landed then ride.Y = standY end
			ride.X += vx * dt
			local pos = Vector3.new(home.Position.X, ride.Y, home.Position.Z) + R * ride.X
			caster:PivotTo(home.Rotation + pos)
			root.AssemblyLinearVelocity = (landed or dt <= 0) and ZERO or (pos - last) / dt
			last = pos
			return not landed
		end)
		-- THE FLAP (SkyriderGust): the wind-up and stroke, aimed at the target's chest from the bird's
		after(run, K.GustAt, function()
			local root, chest = rootOf(caster), chestOf(target)
			if not (root and chest) then return end
			local apex = apexOf(root, R)
			local dir = ((chest - apex).Magnitude > 1e-3) and (chest - apex).Unit or R
			broadcast("ZephyrSkyrider", "SkyriderGust", { Caster = caster, Dir = dir, T0 = serverNow() })
			-- THE LAUNCH (the server's, WindUp + Launch after the press): who the cone holds, struck as its front arrives
			after(run, (G.WindUp or 0.2) + (G.Launch or 0.04), function()
				local r2, vroot = rootOf(caster), rootOf(target)
				if not (r2 and vroot) then return end
				local apex2 = apexOf(r2, R)
				local d = vroot.Position - apex2
				local along = d:Dot(dir)
				local pad = G.BodyPad or 1.5
				if along <= 0 or along > (G.Range or 22) + pad
					or (d - dir * along).Magnitude > along * math.tan(math.rad(G.HalfAngle or 28)) + pad then
					return                                                 -- outside the cone: the server strikes nobody
				end
				local tau = (type(SR.ConeTau) == "function") and SR.ConeTau(math.max(0.5, along - 0.9)) or 0.3
				after(run, tau, function()
					local vr = rootOf(target)
					if not vr then return end
					broadcast("ZephyrSkyrider", "SkyriderGustHit",
						{ Caster = caster, Victim = target, At = vr.Position, T0 = serverNow() })
					local away = flat(vr.Position - apex2) or flat(dir) or R
					react(stage, "Hit", { Damage = G.Damage or 12, From = apex2,
						Knock = away * (G.KnockOut or 55) + UP * (G.KnockUp or 20) })
				end)
			end)
		end)
		-- THE DISMOUNT (SkyriderEnd, the jump off): the bird breaks into wisps, the body falls to the dais
		after(run, K.EndAt, function()
			ride.Drop = true
			broadcast("ZephyrSkyrider", "SkyriderEnd", { Caster = caster, Reason = "Jump", T0 = serverNow() })
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- DEFENSE: GUST PAD
----------------------------------------------------------------------------------------------------
-- The server's broadcasts, played by hand: the press aimed at the target (the pad on the floor under its feet: the
-- server's floor-under-the-crosshair rule, through bodies), the step when the pad arms (the target stands on it), the
-- launch Coil later -- the body thrown straight up at LaunchSpeed (an anchored dummy is carried up its arc and put back:
-- React.Knock), its horizontal speed kept at KeptFlat (none: it stands still) -- and its end before the next press. The
-- target wears GustPadLaunch on the step's clock, as the handler dresses a player stepped on (it leaves dummies alone:
-- CastPose would keep posing them, so this one is let go on stop). Pad ids are negative, so a server pad (positive ids)
-- is never touched.
local padSeq = 0
local function playGustPad(stage, run)
	local GP = need("ZephyrGustPad")
	if not (GP and type(GP.Tuning) == "table") or run.Dead then return end
	need("ZephyrClient")
	if run.Dead then return end
	local caster, target = stage.Caster, stage.Target
	local K, GT = Tuning.GustPad, GP.Tuning
	local live, posed = {}, false
	run.Defer(function()
		for id in pairs(live) do
			broadcast("ZephyrGustPad", "GustPadEnd", { Pad = id, Reason = "Cleared", T0 = serverNow() }, true)
		end
		table.clear(live)
		local CP = cached("CastPose")
		if posed and CP then pcall(CP.Release, target) end           -- the target's joints handed back
	end)
	loop(run, stage, K.Period, function()
		for id in pairs(live) do                                       -- the last loop's pad, if it is still down
			broadcast("ZephyrGustPad", "GustPadEnd", { Pad = id, Reason = "Replaced", T0 = serverNow() })
		end
		table.clear(live)
		padSeq += 1
		local id = -(1e6 + padSeq)
		live[id] = true
		local th = run.Home.Target.Position
		-- THE PRESS (GustPad): the caster's kneeling press, the pad blooming under the target's feet
		broadcast("ZephyrGustPad", "GustPad", {
			Caster = caster, Position = Vector3.new(th.X, stage.Floor.Y, th.Z), T0 = serverNow(),
			Life = GT.Life, Pad = id, Radius = GT.Radius,
		})
		-- THE STEP (the server's scan, once the pad is armed): the ripple and the coil
		after(run, GT.ArmTime or 0.26, function()
			local s0 = serverNow()
			local coil = GT.Coil or 0.26
			broadcast("ZephyrGustPad", "GustPadStep", { Pad = id, Character = target, T0 = s0, At = s0 + coil })
			pose(target, "GustPadLaunch", function() return serverNow() - s0 end)
			posed = true
			-- THE LAUNCH: the column, and the body thrown straight up
			after(run, coil, function()
				local speed = (type(GP.LaunchSpeed) == "function" and GP.LaunchSpeed()) or 46
				react(stage, "Knock", UP * speed)
				broadcast("ZephyrGustPad", "GustPadLaunch", { Pad = id, Character = target, T0 = serverNow() })
			end)
		end)
		-- THE END: the pad unwinds (its own 0.4 s), so the next press blooms on a clean floor
		after(run, K.EndAt, function()
			live[id] = nil
			broadcast("ZephyrGustPad", "GustPadEnd", { Pad = id, Reason = "Expired", T0 = serverNow() })
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: CYCLONE
----------------------------------------------------------------------------------------------------
-- AbilityFX's three handlers on the caster -- Cyclone (CycloneForm on the loop clock, the look forming), CycloneActive
-- FormTime later (touchdown; CycloneRelease, the palms driven at it), CycloneEnd (formed: the unwind; the release clip
-- plays out) -- on the ground under the target, where the crosshair puts it (the server grounds the spot through
-- bodies). From touchdown the server catches the target and moves it as it moves a dummy it owns: every frame
-- ZephyrFX.CyclonePullVelocity (in to the eye, round the axis, lifted to the juggle height and bobbing), carried here by
-- its pivot. Every TickInterval from FirstTick the tick lands: React.Hit (held in the funnel: NoRecoil) and the look's
-- juggle pulse with sparks on the body (ZephyrFX_Cyclone.Pulse: the server sends no tick, and its own watcher only
-- reads TrainingDummy-stamped bodies). At the end the body is let go -- at most ReleaseSpeed, then gravity -- and lands.
local function playCyclone(stage, run)
	local ZFX = need("ZephyrFX")
	if not (ZFX and type(ZFX.Tuning.Cyclone) == "table") then return end
	local look = need("ZephyrFX_Cyclone")
	if run.Dead then return end
	local caster, target = stage.Caster, stage.Target
	local K = Tuning.Cyclone
	run.Defer(function() pcall(ZFX.CycloneEnd, caster, true) end)   -- gone at once
	loop(run, stage, K.Period, function()
		pcall(ZFX.CycloneEnd, caster, true)                          -- the last loop's unwind, if any, gone
		local C = ZFX.Tuning.Cyclone
		local thome = run.Home.Target
		local centre = Vector3.new(thome.Position.X, stage.Floor.Y, thome.Position.Z)
		-- THE CAST (Cyclone): the arms up and circling (looped while it forms), the tornado forming at the spot
		local CP = need("CastPose")
		local clip = CP and type(CP.Clips) == "table" and CP.Clips.CycloneForm
		if clip then pose(caster, "CycloneForm", ZFX.CycloneLoopClock(os.clock(), clip.LoopFrom, clip.LoopLength, 0)) end
		ZFX.Cyclone(caster, centre, { Late = 0, Own = false })
		-- TOUCHDOWN (CycloneActive)
		after(run, C.FormTime, function()
			ZFX.CycloneActive(caster, centre, 0)
			pose(caster, "CycloneRelease")
			local tr = rootOf(target)
			if not tr then return end
			-- the catch: the target pulled in, round and up, frame by frame, until it is let go and lands
			local body = { P = tr.Position, V = ZERO, Since = os.clock(), Let = false }
			local rot, standY = thome.Rotation, thome.Position.Y
			local g = math.max(workspace.Gravity, 1)
			run.Frame(function(dt)
				dt = math.min(dt, 0.1)
				if body.Let then
					body.V -= UP * (g * dt)
				else
					body.V = ZFX.CyclonePullVelocity(body.P, centre, os.clock() - body.Since, K.Seed)
				end
				body.P += body.V * dt
				local landed = false
				if body.P.Y <= standY then                               -- the floor holds the feet
					body.P = Vector3.new(body.P.X, standY, body.P.Z)
					landed = body.Let
				end
				target:PivotTo(rot + body.P)
				return not landed
			end)
			-- THE TICKS
			local hold = math.min(K.Hold, C.ActiveTime or K.Hold)
			local t = C.FirstTick or 0.25
			while t < hold do
				after(run, t, function()
					react(stage, "Hit", { Damage = C.Damage, From = centre, NoRecoil = true })
					local r = rootOf(target)
					if look and type(look.Pulse) == "function" then pcall(look.Pulse, caster, r and r.Position or nil) end
				end)
				t += C.TickInterval or 0.5
			end
			-- THE END (CycloneEnd, formed): it unwinds, and everyone is let go -- dropped, not flung
			after(run, hold, function()
				ZFX.CycloneEnd(caster, false)
				body.Let = true
				local most = C.ReleaseSpeed or 20
				if body.V.Magnitude > most then body.V = body.V.Unit * most end
			end)
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: UPDRAFT
----------------------------------------------------------------------------------------------------
-- {t, value} keys, smoothstepped between neighbours, held past either end (ZephyrUpdraft's own, for the root's yaw)
local function keyed(keys, t)
	if type(keys) ~= "table" or #keys == 0 then return 0 end
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b[1] then
			local a = keys[i - 1]
			return a[2] + (b[2] - a[2]) * smooth((t - a[1]) / math.max(1e-6, b[1] - a[1]))
		end
	end
	return keys[#keys][2]
end

-- The showcase's jump (updraft_bl's hero shot: the dip, the push, riding the wind, the wind-up, THE FLICK, the fall, the
-- landing squash) on the caster: CastPose UpdraftJump on the hero clock (clip time = showcase time + ClipOffset), the
-- body carried along the hero's arc (V0 / Air / Drift, the root's yaw keys about its facing at the target) -- the same
-- numbers ZephyrUpdraft.Demo lifts its own body by. The tell is the LIVE one: Demo's Jump path puts the caster on the
-- airborne watcher for its JumpWatch (renewed every loop), which reads the real take-off, height, apex and landing off the
-- moving body (its floor cast needs a dais that collides: landingFloor). At the release (Rel) the flick's Wind Blade
-- leaves the right hand for the target's chest; its hit is an airborne one, so the server raises it (DamageMult) and
-- broadcasts UpdraftHit -- the pulse climbing the helix, the mark on the victim.
local function playUpdraft(stage, run)
	local U = need("ZephyrUpdraft")
	local ZFX = need("ZephyrFX")
	if not (U and type(U.Demo) == "function") or run.Dead then return end
	need("ZephyrClient")
	if run.Dead then return end
	local caster, target = stage.Caster, stage.Target
	local K = Tuning.Updraft
	local UT = type(U.Tuning) == "table" and U.Tuning or {}
	local TL = type(UT.Tell) == "table" and UT.Tell or {}
	local DM = type(TL.Demo) == "table" and TL.Demo or {}
	local V0, TA = DM.V0 or 20, DM.Air or 1.398
	local Gb = 2 * V0 / TA                                   -- the Blender jump's gravity (updraft_bl's zk.G)
	local from, rel, tail = DM.From or -0.5, DM.Rel or 0.66, DM.Tail or 1.3
	local offset, drift = DM.ClipOffset or 0.3, DM.Drift or 1.2
	local clipName = (type(TL.Pose) == "table" and TL.Pose.Jump) or "UpdraftJump"
	local mult = (type(UT.DamageMult) == "number") and UT.DamageMult or 1.25
	landingFloor(stage, run)
	local watch = nil
	run.Defer(function()
		if watch and type(watch.Stop) == "function" then pcall(watch.Stop) end   -- off the watcher: the tell thins away
		watch = nil
	end)
	loop(run, stage, K.Period, function()
		-- the LIVE tell on the caster (the watcher, forced on for JumpWatch)
		if watch and type(watch.Stop) == "function" then pcall(watch.Stop) end
		watch = U.Demo(caster, { Jump = true })
		local home = run.Home.Caster
		local ahead = flat(home.LookVector) or flat(stage.CF.RightVector) or Vector3.xAxis
		local scale = timeScale()
		local t0 = os.clock()
		local function showT() return from + (os.clock() - t0) * scale end
		pose(caster, clipName, function() return math.max(0, showT() + offset) end)
		-- the body along the hero's arc
		run.Frame(function()
			local t = showT()
			local z = (t > 0 and t < TA) and (V0 * t - 0.5 * Gb * t * t) * K.Rise or 0
			local pos = home.Position + ahead * (drift * math.clamp(t, 0, TA)) + UP * z
			caster:PivotTo(CFrame.new(pos) * CFrame.Angles(0, keyed(DM.Yaw, t), 0) * home.Rotation)
			return t < TA + tail
		end)
		-- THE FLICK: the swirl a Trigger ahead of the release, the blade at Rel, the aerial hit
		if ZFX then
			local relIn = (rel - from) / scale
			local trigger = (ZFX.Tuning.WindBlade.Trigger or 0.06) / scale
			after(run, relIn - trigger, function()
				windBlade(run, stage, "R", "Down", {
					NoClip = true,                                   -- the hero clip flicks the arm itself
					Damage = (ZFX.Tuning.WindBlade.Damage or 3) * mult,
					OnHit = function()
						local vr = rootOf(target)
						broadcast("ZephyrUpdraft", "UpdraftHit", {
							Character = caster, At = vr and (vr.Position + UP * 0.2) or nil, T0 = serverNow(), Victim = target,
						})
					end,
				})
			end)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- THE KIT (the AltarMoves contract)
----------------------------------------------------------------------------------------------------
return {
	Element = "Zephyr",
	Moves = {
		{ Key = "WindBlade", Name = NAMES.WindBlade or "Wind Blade", Slot = "M1",
		  Play = preview("WindBlade", playWindBlade) },
		{ Key = "CrossSlashDash", Name = NAMES.CrossSlashDash or "Cross-Slash Dash", Slot = "Primary",
		  Play = preview("CrossSlashDash", playCrossSlash) },
		{ Key = "Skyrider", Name = NAMES.Skyrider or "Skyrider", Slot = "Mobility",
		  Play = preview("Skyrider", playSkyrider) },
		{ Key = "GustPad", Name = NAMES.GustPad or "Gust Pad", Slot = "Defense",
		  Play = preview("GustPad", playGustPad) },
		{ Key = "Cyclone", Name = NAMES.Cyclone or "Cyclone", Slot = "Ultimate",
		  Play = preview("Cyclone", playCyclone) },
		{ Key = "Updraft", Name = NAMES.Updraft or "Updraft", Slot = "Passive",
		  Play = preview("Updraft", playUpdraft) },
	},
}
