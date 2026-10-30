--[[
	AltarMoves_Pyro  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Pyro

	THE LOADOUT ALTAR'S MOVE PREVIEWS for PYRO, contract v2 (2026-10-26, the owner: each move of the Element's kit played
	the way a duel shows it -- a caster PERFORMING it with the game's own third-person cast poses, the move's real effects
	in the wrap being looked at, and a target TAKING the hit). Client only: no remotes, no damage, no hit that decides
	anything. Each Moves entry's Play(stage) loops one move on the showcase's stage until the stop() it returns is called.
	The stage (AltarShowcase buildStage + AltarStage.Pair) carries two VISIBLE grey mannequins under
	workspace.TrainingGround: stage.Caster at Floor - RightVector*7 facing the target (AllyDummy), stage.Target at Floor +
	RightVector*7 facing back; stage.React is AltarStage (Hit / Knock / Recoil / Reset). Nothing is cloned or hidden.

	EVERY BEAT IS THE GAME'S OWN. The body: CastPose (ReplicatedStorage.IceMagic.CastPose, the very instance AbilityFX
	drives, so its RenderStep poses the caster like any player's body) playing the clips AbilityFX's Pyro handlers play,
	on their beats. The effects: the PyroFX entry each handler calls, with the handler's payload, on the clip's Trigger /
	ShotTimeScale, aimed from the caster at the target, run inside PyroDraw.WithWrap(the wrap's tier copy) -- what PyroFX's
	own withWrap does for a caster wearing stage.Wrap (wrapOf + forTier are locals there, so forTier is copied below). The
	hit: what PyroHandler does when it lands -- its numbers from PyroFX.Tuning, burns as Burn stacks -- shown on the target
	through stage.React.Hit, the frame it lands. Pyro has no knockback anywhere: every hit is the recoil.
	  FIREBALL        a right punch then a left (FireballR / FireballL), each the Charge on that fist and FireFireball on the
	                  Trigger from the hand (0.45 past it, as AbilityFX launches) at the target's chest. The ball's own ray
	                  stops on the target's body and its own burst goes off; Hit Direct (18) that frame. THE SHOT SLOWED: 200
	                  studs/s crosses the stage in two frames, so PyroFX.FireballVelocity answers SHOW.BallSpeed for the
	                  length of the call (both looks read it once, at the throw); Life, the tail, wisps and burst are live
	  IMMOLATE        the Immolate clip and the motes (Stacks_Primary 3), then three buffed (Hot) throws: each that lands
	                  spends a mote, 3 -> 0, and burns the target, as PyroHandler's landFireball does
	  DETONATE        a Fireball hit first (the mark goes on whoever you last hit), then the Detonate flick, DetonateMark (the
	                  Flame Crown) on the target on the Trigger, DetonateBlast at the end of the fuse for Base + Bonus by the
	                  target's missing health (PyroHandler's explode). Every other loop the target is already low (KillHealth)
	                  and it kills: KABOOM! and KO!
	  SCORCHING LASH  ScorchingLashHold (SetBase) with the whip held, then the ScorchingLash sweep aimed at the target and
	                  LashHit on the crack (the Trigger) when the target is inside LashSweepHas; Hit 12 and a burn stack
	  RING OF FIRE    pointed at the target's feet: the drawing arm follows the point (SetAim), RingOfFireSettle as the
	                  circle closes, RingOfFirePoint, and the eruption on the snap (DrawTime + SettleTime + SnapBeat), where
	                  LockRing pins it and the target inside takes Damage (55) and a burn. Drawn at SHOW.RingRadius to fit
	                  the stage (the live 17.5 would swallow the caster too)
	  EMBER REFUND    the Passive: the target already near the line (RefundHealth), a Fireball takes it under Below (30%)
	                  and the refund flares on the caster, its streak from the target (PyroHandler's LowHealth rule)
	THE BURN FLAMES on the target are PyroFX.WatchBurnStacks' (off RX_Burning_Stacks, which React.Hit sets), and that
	watcher wears only a PLAYER caster's wrap. With a wrap on (and the flame look in force) the preview lights them itself,
	PyroFlame_Tech.StartBurn under the wrap in the same frame as the attribute, so the watcher finds them lit (both looks
	share burnControllers) and leaves them; Default leaves them to the watcher.
	STOP. The loop thread and every beat it scheduled are cancelled; every PyroDraw.Play an entry starts inside the
	preview's own call is recorded (PyroDraw.Play is wrapped for the length of each call, recording that thread's only) and
	Stopped; IGNITE!, a toon piece made in the call, is destroyed; the whip is let go,
	the mark fizzled, the caster's attributes cleared and its body put back on the Ready stance at home; React.Reset.
	What nothing can reach runs out its own short life: the Fireball's impact burst (<= 0.93 s), KABOOM! (<= 0.55 s), the
	Lash's crack (<= 0.8 s) -- and the dummies themselves go with AltarStage.Clear right after.
	WRAPS. A wrap's 45 flame copies (and its toon copies) build in the background: a preview waits up to SHOW.WarmWait for
	them, then starts anyway -- PyroDraw draws Default until the set is in, and every later loop's canvases pick it up.
	(2026-10-26) The wrap is AltarStage.Look's: with a skin on (stage.Skin -- Pyro has none in SkinCatalog yet) a Flame
	wrap never goes over it (WrapsOverSkin), so the entries run bare and the skin's own kit, which the caster wears
	(ShowcaseSkin), has the look. Swept for what a cast needs that a dummy lacks: nothing new -- the burn
	flames and the whip / mark attributes are already stood in for here (above).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ELEMENT = "Pyro"

-- the preview's own numbers (the live ones beside each)
local SHOW = {
	BallSpeed = 32,          -- studs/s the Fireball flies here (live Tuning.Fireball.Speed 200); HubShowcaseM1's held ball
	                         -- lays its tail out at this speed too
	VolleyGap = 0.55,        -- s between the Fireball preview's right punch and its left
	ThrowAt = { 0.7, 1.3, 1.9 },   -- s after the Immolate cast that each buffed throw starts (R, L, R)
	DetonateAfter = 0.25,    -- s after the Fireball lands that Detonate is pressed
	KillHealth = 25,         -- Detonate's killing loops: the target starts this low (under FullAt: the full Base + Bonus)
	RefundHealth = 45,       -- Ember Refund: the target starts here, over Below (30) until one Direct (18) lands
	LashHold = 1.0,          -- s the whip is held before the sweep (live: as long as the key is down, up to 6)
	RingRadius = 5,          -- the Ring of Fire's circle round the target (live Tuning.RingOfFire.Radius 17.5)
	WarmWait = 2.0,          -- s a preview waits for its wrap's copies before it starts anyway
	-- s from one loop's start to the next, matched to each move's own length
	Every = { Fireball = 2.8, Immolate = 4.2, Detonate = 4.0, ScorchingLash = 3.2,
		RingOfFire = 3.8, EmberRefund = 3.0 },
}

-- the ability name PyroFX's wrap tiers go by (its ENTRY table), where it differs from the move's key
local ABILITY = { RingOfFire = "RingofFire" }
-- the moves whose wrap paints toon pieces taken once at their start (IGNITE!): their copies are waited for
local TOON_WAIT = { RingOfFire = true }
-- what the preview sets on the caster (the server's attributes), cleared between loops and on stop
local OWN_ATTRS = { "Stacks_Primary" }

-- display names: SpellshotConfig's (read without waiting), these if it cannot be read
local NAMES = { Fireball = "Fireball", Immolate = "Immolate", Detonate = "Detonate",
	ScorchingLash = "Scorching Lash", RingOfFire = "Ring of Fire", EmberRefund = "Ember Refund" }
pcall(function()
	local sp = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = sp and sp:FindFirstChild("SpellshotConfig")
	local Config = m and require(m)
	if type(Config) ~= "table" then return end
	local function set(key, row) if type(row) == "table" and type(row.Name) == "string" then NAMES[key] = row.Name end end
	local e = Config.Elements and Config.Elements[ELEMENT]
	if type(e) == "table" then set("Fireball", e.M1) set("Immolate", e.Primary) set("EmberRefund", e.Passive) end
	set("Detonate", Config.Mobility and Config.Mobility.Detonate)
	set("ScorchingLash", Config.Defense and Config.Defense.ScorchingLash)
	set("RingOfFire", Config.Ultimate and Config.Ultimate.RingOfFire)
end)

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Pyro] " .. tostring(msg))
end

-- the real modules, found on the first preview (inside its own thread: Play never waits). CP is the CastPose instance
-- AbilityFX requires (one module, one state: a second copy would run its own RenderStep against the same joints)
local PyroFX, PD, VFX, Skins, CP = nil, nil, nil, nil, nil
local Tech = nil                 -- PyroFlame_Tech, optional: the wrapped burn flames (StartBurn)
local function libs()
	if PyroFX then return true end
	local ok, a, b, c, d, e = pcall(function()
		local ice = ReplicatedStorage:WaitForChild("IceMagic", 10)
		local spell = ReplicatedStorage:WaitForChild("Spellshot", 10)
		return require(ice:WaitForChild("PyroFX", 10)), require(ice:WaitForChild("PyroDraw", 10)),
			require(ice:WaitForChild("VFXLibrary", 10)), require(spell:WaitForChild("SkinCatalog", 10)),
			require(ice:WaitForChild("CastPose", 10))
	end)
	if not (ok and type(a) == "table" and type(b) == "table" and type(c) == "table" and type(d) == "table"
		and type(e) == "table") then
		warnOnce("libs", "PyroFX / PyroDraw / VFXLibrary / SkinCatalog / CastPose unreadable; nothing played: " .. tostring(a))
		return false
	end
	PyroFX, PD, VFX, Skins, CP = a, b, c, d, e
	pcall(function()
		local m = ReplicatedStorage.IceMagic:FindFirstChild("PyroFlame_Tech")
		local t = m and require(m)
		if type(t) == "table" and type(t.StartBurn) == "function" then Tech = t end
	end)
	return true
end

local function flat(v, fallback)
	local h = Vector3.new(v.X, 0, v.Z)
	return h.Magnitude > 1e-3 and h.Unit or fallback
end

local function shotScale()
	local ok, s = pcall(VFX.ShotTimeScale)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

--- a clip's release beat (CastPose.Clips[clip].Trigger), `fallback` (the Tuning's twin) if the clip is not there
local function trig(clip, fallback)
	local c = CP and type(CP.Clips) == "table" and CP.Clips[clip]
	return (type(c) == "table" and type(c.Trigger) == "number") and c.Trigger or fallback
end

local function now() return workspace:GetServerTimeNow() end

----------------------------------------------------------------------------------------------------
-- the wrap: SkinCatalog's entry as PyroFX's withWrap hands it to PyroDraw
----------------------------------------------------------------------------------------------------
local TIER = { RingofFire = "Ultimate", ScorchingLash = "Technique" }   -- PyroFX's TIER: the rest are Basics
local tierCopies = {}
--- the wrap `id` for Pyro's `ability`, nil = Default. PyroFX's local forTier, copied: the tier's ShedScale (an ability's own
--- entry wins) shrinks the wrap's Shed layers; same Id, so PyroDraw draws it from the same mesh set
local function wrapFor(id, ability)
	if type(id) ~= "string" or id == "Default" then return nil end
	local w = type(Skins.Skins) == "table" and Skins.Skins[id]
	if type(w) ~= "table" or w.Wrap ~= ELEMENT or not w.Flame then return nil end
	local S, shed = w.ShedScale, w.Shed
	local tier = TIER[ability] or "Basic"
	local f = S and shed and (S[ability] or S[tier])
	if not f then return w end
	if S[ability] then tier = ability end
	local key = w.Id .. "/" .. tier
	if tierCopies[key] then return tierCopies[key] end
	local list = {}
	for i, L in ipairs(shed) do
		local c = table.clone(L)
		c.Name = L.Name .. "@" .. tier
		c.Size = { L.Size[1] * f.Size, L.Size[2] * f.Size }
		c.Speed = { L.Speed[1] * (f.Speed or 1), L.Speed[2] * (f.Speed or 1) }
		c.Life = { L.Life[1] * (f.Life or 1), L.Life[2] * (f.Life or 1) }
		c.Rise = (L.Rise or 0) * (f.Rise or 1)
		c.PerPart = L.PerPart and L.PerPart * f.Rate
		c.MinRate = L.MinRate and L.MinRate * f.Rate
		c.Burst = L.Burst and L.Burst * f.Rate
		list[i] = c
	end
	local v = setmetatable({ Shed = list, Tier = tier }, { __index = w })
	tierCopies[key] = v
	return v
end

-- PyroFX's TOON_PIECES (local there): the toon meshes with Pyro's colours baked in, copied per wrap (its ToonRamp)
local TOON_PIECES = { "RingOfFireIgnite" }

--- (2026-10-26) the wrap drawn, by AltarStage.Look's one rule: stage.Wrap -- or, with a skin on (stage.Skin; Pyro has
--- none yet), only a wrap SkinCatalog lets over a skin (WrapsOverSkin: never a Flame wrap), else "Default": nil here,
--- so each entry runs bare and the skin's own look stands (no Default palette forced over it)
local function lookWrap(S)
	local st = S.Stage
	local R = st.React
	if type(R) == "table" and type(R.Look) == "function" then
		local ok, _, w = pcall(R.Look, st, ELEMENT)
		if ok then return w end
	end
	return st.Wrap
end

--- the move's wrap and its burns' (the burn a Pyro lights wears the Basics' tier; the Lash's its own), from the look
local function resolveWrap(S)
	S.LookKey = tostring(S.Stage.Wrap) .. "|" .. tostring(S.Stage.Skin)   -- (2026-10-26: a skin change re-resolves too)
	local id = lookWrap(S)
	S.WrapId = id
	S.Wrap = wrapFor(id, S.Ability)
	S.BurnWrap = wrapFor(id, S.Key == "ScorchingLash" and "ScorchingLash" or "Immolate")
end

--- starts the wrap's flame copies (and its toon copies, PyroFX's prewarmToon) and waits, up to WarmWait, until a canvas
--- made now would wear it -- and, `toon`, until the toon copies are in too (pieces taken once, at an effect's start)
local function warm(S, toon)
	local w = S.Wrap
	if not w then return end
	pcall(PD.PrewarmWrap, w)
	local folder = ReplicatedStorage:FindFirstChild("FireMagicMeshes")
	local function toonIn()
		if not (w.ToonRamp and folder) then return true end
		local all = true
		for _, n in ipairs(TOON_PIECES) do
			local src = folder:FindFirstChild(n)
			if src and src:IsA("MeshPart") then
				local ok, t = pcall(PD.WrapPiece, w, src)
				if not (ok and t) then all = false end
			end
		end
		return all
	end
	local toonOk = toonIn()
	local deadline = os.clock() + SHOW.WarmWait
	while not S.Dead and os.clock() < deadline do
		local ok, cv = pcall(PD.new, "PyroAltarProbe", { own = true, wrap = w })
		local flameOk = not ok or cv.Wrap ~= nil                  -- (no canvas at all: nothing to wait for)
		if ok then pcall(function() cv:Destroy() end) end
		if flameOk and (toonOk or not toon) then return end
		task.wait(0.1)
		if toon and not toonOk then toonOk = toonIn() end
	end
end

--- a wrap picked while the preview runs: the next loop wears it (its copies build behind; Default until they are in)
local function rewrap(S)
	if tostring(S.Stage.Wrap) .. "|" .. tostring(S.Stage.Skin) == S.LookKey then return end
	resolveWrap(S)
	if S.Wrap then pcall(PD.PrewarmWrap, S.Wrap) end
end

----------------------------------------------------------------------------------------------------
-- one real PyroFX entry, under the preview's wrap, its handles recorded
----------------------------------------------------------------------------------------------------
-- the toon pieces PyroFX makes whole (not pooled) inside an entry, which the preview may destroy on stop()
local OWN_PIECES = { RingOfFireIgnite = true, RingOfFireSeal = true, RingOfFireEruption = true,
	RingOfFireEruptionHot = true }

local function fxFolder()
	local name = type(VFX.Config) == "table" and VFX.Config.FXFolderName
	return type(name) == "string" and workspace:FindFirstChild(name) or nil
end

--- the hooks one call swapped in (PyroDraw.Play's recorder, the slowed FireballVelocity), put back -- by the call itself,
--- or by stop() if the call's thread was cancelled inside it
local function unhook(S)
	local h = S.Hook
	if not h then return end
	S.Hook = nil
	if PD.Play == h.Tap then PD.Play = h.Play end
	if h.Slow and PyroFX.FireballVelocity == h.Slow then PyroFX.FireballVelocity = h.Vel end
end

--- `fn(...)` (a PyroFX entry) under the wrap `w` (nil: Default); records the PyroDraw.Play handles it starts on this thread
--- and the whole toon pieces it adds to the FX folder. `speed`: PyroFX.FireballVelocity answers this many studs/s
--- meanwhile. -> whether it ran (a failure is warned once and skipped)
local function fx(S, w, speed, fn, ...)
	if S.Dead or type(fn) ~= "function" then return false end
	local folder = fxFolder()
	local before = {}
	if folder then
		for _, c in ipairs(folder:GetChildren()) do if OWN_PIECES[c.Name] then before[c] = true end end
	end
	local play, me, plays = PD.Play, coroutine.running(), S.Plays
	local function tap(...)
		local h = play(...)
		if coroutine.running() == me and type(h) == "table" then plays[#plays + 1] = h end
		return h
	end
	local hook = { Play = play, Tap = tap }
	PD.Play = tap
	if speed then
		hook.Vel = PyroFX.FireballVelocity
		hook.Slow = function(dir) return dir * speed end
		PyroFX.FireballVelocity = hook.Slow
	end
	S.Hook = hook
	local ok, err
	if w then ok, err = pcall(PD.WithWrap, w, fn, ...) else ok, err = pcall(fn, ...) end
	if S.Hook == hook then unhook(S) end
	folder = fxFolder()
	if folder then
		for _, c in ipairs(folder:GetChildren()) do
			if OWN_PIECES[c.Name] and not before[c] then S.Pieces[#S.Pieces + 1] = c end
		end
	end
	if not ok then warnOnce("call:" .. S.Key, S.Key .. ": " .. tostring(err)) end
	return ok
end

--- the usual call: the move's own wrap
local function call(S, fn, ...)
	return fx(S, S.Wrap, nil, fn, ...)
end

--- a CastPose call on the caster (guarded: a pose that fails never stops the move)
local function pose(S, name, ...)
	local f = CP and CP[name]
	if type(f) == "function" then pcall(f, S.Caster, ...) end
end

--- stage.React's `name` (AltarStage) on the stage, guarded
local function react(S, name, ...)
	local R = S.Stage.React
	local f = type(R) == "table" and R[name]
	if type(f) ~= "function" then return end
	local ok, err = pcall(f, S.Stage, ...)
	if not ok then warnOnce("react:" .. name, "React." .. name .. ": " .. tostring(err)) end
end

--- waits `dt`; false once the preview has been stopped (the loop's thread is cancelled then anyway)
local function sleep(S, dt)
	if dt > 0 then task.wait(dt) end
	return not S.Dead
end

--- `fn` in `dt` seconds, on a thread the preview owns (cancelled between loops and on stop)
local function later(S, dt, fn)
	if S.Dead then return end
	local th = task.delay(math.max(0, dt), function()
		if S.Dead then return end
		local ok, err = pcall(fn)
		if not ok then warnOnce("beat:" .. S.Key, S.Key .. ": " .. tostring(err)) end
	end)
	S.Threads[#S.Threads + 1] = th
end

local function cancelThreads(S)
	local me = coroutine.running()
	for _, th in ipairs(S.Threads) do
		if th ~= me then pcall(task.cancel, th) end
	end
	table.clear(S.Threads)
end

----------------------------------------------------------------------------------------------------
-- the stage: the two dummies, where they stand, how they are set back
----------------------------------------------------------------------------------------------------
--- the stage's frame: R (caster -> target), L (toward the camera), the caster's home (AltarHome, facing R), the roots
local function geometry(S)
	local st = S.Stage
	local c, t = st.Caster, st.Target
	if not (typeof(c) == "Instance" and typeof(t) == "Instance") then return false end
	local root, troot = c:FindFirstChild("HumanoidRootPart"), t:FindFirstChild("HumanoidRootPart")
	if not (root and troot and c:FindFirstChildOfClass("Humanoid")) then return false end
	S.Caster, S.Target, S.Root, S.TRoot = c, t, root, troot
	S.R = flat(st.CF.RightVector, Vector3.zAxis)
	S.L = flat(st.CF.LookVector, Vector3.xAxis)
	local home = c:GetAttribute("AltarHome")
	S.Home = typeof(home) == "Vector3" and home or root.Position
	S.HomeCF = CFrame.lookAt(S.Home, S.Home + S.R)
	S.FloorY = typeof(st.Floor) == "Vector3" and st.Floor.Y or (troot.Position.Y - 3.192)
	return true
end

local function alive(S)
	local f = S.Stage.Parent
	return typeof(f) == "Instance" and f:IsDescendantOf(workspace) and S.Caster.Parent ~= nil and S.Target.Parent ~= nil
end

--- the target's chest: where a shot is aimed
local function chest(S)
	local ut = S.Target:FindFirstChild("UpperTorso")
	if ut and ut:IsA("BasePart") then return ut.Position end
	return S.TRoot.Position + Vector3.new(0, 0.5, 0)
end

--- the caster on its rest: no clip, no base, no aim, the Ready stance, stood at home facing the target
local function rest(S)
	pose(S, "SetAim", nil)
	pose(S, "SetBase", nil)
	pose(S, "Stop")
	pose(S, "SetStance", "Ready")
	if S.Root and S.Root.Parent then S.Root.AssemblyLinearVelocity = Vector3.zero end
	if S.Caster.Parent then S.Caster:PivotTo(S.HomeCF) end
end

--- between loops: the last loop's beats cancelled, both dummies reset (React.Reset), the caster's attributes off, rest
local function between(S)
	cancelThreads(S)
	react(S, "Reset")
	for _, a in ipairs(OWN_ATTRS) do S.Caster:SetAttribute(a, nil) end
	rest(S)
	S.BurnLit = false
end

--- the hit landing on the target: React.Hit with `opts` -- and, with a burn and a wrap on, the burn flames lit under the
--- wrap in this same frame (see THE BURN FLAMES above)
local function hit(S, opts)
	react(S, "Hit", opts)
	if not (opts.Burn and S.BurnWrap and Tech and not S.BurnLit) then return end
	local ok, look = pcall(function() return PyroFX.CurrentLook and PyroFX.CurrentLook() end)
	if ok and look == "flame" then
		S.BurnLit = true
		fx(S, S.BurnWrap, nil, Tech.StartBurn, S.Target)
	end
end

--- the ray the Fireball's own flight casts (the FX folder and the thrower excluded), to know where and when it stops
local function rayFrom(S, from, dir, len)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { S.Caster }
	local f = fxFolder()
	if f then list[#list + 1] = f end
	params.FilterDescendantsInstances = list
	return workspace:Raycast(from, dir * len, params)
end

----------------------------------------------------------------------------------------------------
-- a preview: one move looping on the stage, and everything it made
----------------------------------------------------------------------------------------------------
local function prune(S)
	for i = #S.Plays, 1, -1 do if S.Plays[i].Dead then table.remove(S.Plays, i) end end
	for i = #S.Pieces, 1, -1 do if not S.Pieces[i].Parent then table.remove(S.Pieces, i) end end
end

--- Play for one move: setup(S) once, then cycle(S, n) every SHOW.Every[key] s on its own thread, until stop()
local function run(stage, key, setup, cycle)
	local S = { Stage = stage, Key = key, Ability = ABILITY[key] or key, Dead = false, Plays = {}, Pieces = {}, Threads = {} }
	local function stop()
		if S.Dead then return end
		S.Dead = true
		local th = S.Thread
		if th and th ~= coroutine.running() then pcall(task.cancel, th) end
		cancelThreads(S)
		if PD then unhook(S) end
		for _, h in ipairs(S.Plays) do pcall(function() h:Stop() end) end      -- PyroDraw ends them next frame
		for _, p in ipairs(S.Pieces) do pcall(function() p:Destroy() end) end
		table.clear(S.Plays)
		table.clear(S.Pieces)
		local c, t = S.Caster, S.Target
		if c and PyroFX then
			pcall(function()
				if c.Parent then
					PyroFX.LashHold(c, false, nil, false)                    -- a held whip goes
				end
			end)
		end
		if t and PyroFX then pcall(PyroFX.DetonateFizzle, { Victim = t }) end   -- a mark mid-fuse goes out
		if c then
			for _, a in ipairs(OWN_ATTRS) do pcall(c.SetAttribute, c, a, nil) end   -- the motes spend
			pcall(rest, S)
		end
		react(S, "Reset")
	end
	S.Thread = task.spawn(function()
		if not libs() then return end
		local ok, err = pcall(function()
			if not geometry(S) then
				warnOnce("stage", "the stage has no Caster / Target with a root and a Humanoid; nothing played")
				return
			end
			S.Caster:SetAttribute("WrapStudio", nil)                     -- (PyroFX's Studio wrap override: the wrap is ours)
			rest(S)                                                      -- (the body on CastPose from the first frame)
			resolveWrap(S)
			warm(S, TOON_WAIT[key])
			if S.Dead then return end
			if setup then setup(S) end
			local n = 0
			while not S.Dead do
				-- the stage folder or a dummy gone first (the altar closed): the preview stops itself
				if not alive(S) then
					stop()
					break
				end
				n += 1
				local t0 = os.clock()
				rewrap(S)
				between(S)
				local ok2, err2 = pcall(cycle, S, n)
				if not ok2 then warnOnce("cycle:" .. key, key .. ": " .. tostring(err2)) end
				prune(S)
				task.wait(math.max(0.1, t0 + SHOW.Every[key] - os.clock()))
			end
		end)
		if not ok and not S.Dead then warnOnce("run:" .. key, key .. ": " .. tostring(err)) end
	end)
	return stop
end

----------------------------------------------------------------------------------------------------
-- the moves
----------------------------------------------------------------------------------------------------
--- one Fireball as handlers.Fireball plays it for someone else's throw: the punch on the body, the Charge on that fist,
--- and on the Trigger the ball from the hand (0.45 past it) at the target's chest, excluding the thrower (shotExclude).
--- `onLand(at, from)`: the frame the ball's own ray stops on the target (found here with the same ray)
local function throw(S, side, hot, onLand)
	local c = S.Caster
	local clip = "Fireball" .. side
	local F = PyroFX.Tuning.Fireball
	pose(S, "Play", clip)
	call(S, PyroFX.Charge, c, side, hot, false)
	later(S, trig(clip, F.Trigger) / shotScale(), function()
		local hand = c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
		if not (hand and hand.Parent) then return end
		local from = (hand.CFrame * CFrame.new(0, -0.45, 0)).Position
		local d = chest(S) - from
		if d.Magnitude < 0.5 then return end
		local dir = d.Unit
		local stopAt = rayFrom(S, from, dir, SHOW.BallSpeed * F.Life)
		fx(S, S.Wrap, SHOW.BallSpeed, PyroFX.FireFireball, from, dir, { c }, nil, nil, hot)
		if onLand and stopAt and stopAt.Instance:IsDescendantOf(S.Target) then
			later(S, (stopAt.Position - from).Magnitude / SHOW.BallSpeed / shotScale(), function()
				onLand(stopAt.Position, from)
			end)
		end
	end)
end

-- M1, FIREBALL (AbilityFX handlers.Fireball; PyroHandler landFireball: Direct on the body hit)
local function fireballCycle(S)
	local F = PyroFX.Tuning.Fireball
	local function land(_, from) hit(S, { Damage = F.Direct, From = from }) end
	throw(S, "R", false, land)
	if not sleep(S, SHOW.VolleyGap) then return end
	throw(S, "L", false, land)
end

-- PRIMARY, IMMOLATE (handlers.Immolate): the cast and the motes; then each buffed hit spends one and lights the burn
local function immolateCycle(S)
	local c = S.Caster
	local F = PyroFX.Tuning.Fireball
	c:SetAttribute("Stacks_Primary", PyroFX.Tuning.Immolate.Stacks)
	pose(S, "Play", "Immolate")
	if not call(S, PyroFX.Immolate, c, now()) then return end
	local t0 = os.clock()
	local burning = false
	for i, at in ipairs(SHOW.ThrowAt) do
		if not sleep(S, t0 + at - os.clock()) then return end
		local hot = (c:GetAttribute("Stacks_Primary") or 0) > 0       -- (the server's Hot: a stack left at the throw)
		throw(S, (i % 2 == 1) and "R" or "L", hot, function(_, from)
			local left = c:GetAttribute("Stacks_Primary") or 0
			if left > 0 then c:SetAttribute("Stacks_Primary", left - 1) end   -- the next mote shrinks out and pops
			hit(S, { Damage = F.Direct, From = from, Burn = (left > 0 and not burning) and 1 or nil })
			if left > 0 then burning = true end
		end)
	end
end

-- MOBILITY, DETONATE (handlers.Detonate / DetonateMark / DetonateBlast; PyroHandler castDetonate / explode)
local function detonate(S)
	local c, t = S.Caster, S.Target
	local D = PyroFX.Tuning.Detonate
	local ts = shotScale()
	pose(S, "Play", "Detonate")
	call(S, PyroFX.DetonateFlick, c, now())
	later(S, trig("Detonate", D.Trigger) / ts, function()
		local fuse = D.Fuse / ts
		call(S, PyroFX.DetonateMark, { Character = c, Victim = t, Position = S.TRoot.Position, T0 = now(), Fuse = fuse })
		later(S, fuse, function()
			-- Base + Bonus by missing health, read the moment it goes off (FullAt or lower: the whole Bonus)
			local hum = t:FindFirstChildOfClass("Humanoid")
			local health = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 1
			local amount = D.Base + D.Bonus * math.min(1, (1 - health) / (1 - D.FullAt))
			local lethal = hum ~= nil and hum.Health - amount <= 0
			call(S, PyroFX.DetonateBlast, { Character = c, Victim = t, Position = S.TRoot.Position, Amount = amount,
				Scale = (amount - D.Base) / D.Bonus, Lethal = lethal, T0 = now() })
			hit(S, { Damage = amount, Word = lethal and "KO!" or nil, Style = lethal and "ko" or nil })
		end)
	end)
end
local function detonateCycle(S, n)
	local F = PyroFX.Tuning.Fireball
	local hum = S.Target:FindFirstChildOfClass("Humanoid")
	if n % 2 == 0 and hum then hum.Health = SHOW.KillHealth end     -- every other loop it kills: KABOOM!
	throw(S, "R", false, function(_, from)
		hit(S, { Damage = F.Direct, From = from })                    -- the qualifying hit: now it may be marked
		later(S, SHOW.DetonateAfter, function() detonate(S) end)
	end)
end


-- DEFENSE, SCORCHING LASH (handlers.ScorchingLashHold / ScorchingLash / ScorchingLashHit; PyroHandler: Damage + a stack)
local function lashCycle(S)
	local c, root = S.Caster, S.Root
	local L = PyroFX.Tuning.ScorchingLash
	pose(S, "Play", "ScorchingLashHold")
	pose(S, "SetBase", "ScorchingLashHold")
	call(S, PyroFX.LashHold, c, true, now(), false)
	if not sleep(S, SHOW.LashHold) then return end
	-- the release: the flat aim at the target, the hold's base let go, the sweep round the right side and across the front
	local aim = flat(S.TRoot.Position - root.Position, S.R)
	pose(S, "SetBase", nil)
	pose(S, "Play", "ScorchingLash")
	call(S, PyroFX.Lash, c, now(), aim, false)
	if not sleep(S, trig("ScorchingLash", L.Trigger) / shotScale()) then return end
	local tr = S.TRoot
	if S.Target.Parent and PyroFX.LashSweepHas(tr.Position - root.Position, aim) then
		call(S, PyroFX.LashHit, { Character = c, Victims = { S.Target }, Positions = { tr.Position } })
		hit(S, { Damage = L.Damage, From = root.Position, Burn = 1 })
	end
end


-- ULTIMATE, RING OF FIRE (handlers.RingOfFire / RingOfFireLock; PyroHandler castRingOfFire): pointed at the target's feet
local function ringCycle(S)
	local c, root = S.Caster, S.Root
	local R = PyroFX.Tuning.RingOfFire
	local tp = S.TRoot.Position
	local centre = Vector3.new(tp.X, S.FloorY, tp.Z)
	call(S, PyroFX.RingOfFire, c, centre, SHOW.RingRadius, false, now(), PyroFX.RingStartAngle(centre, root.Position),
		function(point) if not S.Dead then pose(S, "SetAim", point) end end)
	later(S, R.DrawTime, function()
		pose(S, "SetAim", nil)
		pose(S, "Play", "RingOfFireSettle")
	end)
	later(S, R.DrawTime + R.SettleTime, function() pose(S, "Play", "RingOfFirePoint") end)
	-- the eruption, on the point's ignition frame: whoever stands inside the circle (and the burn height) is burnt
	later(S, R.DrawTime + R.SettleTime + trig("RingOfFirePoint", R.SnapBeat), function()
		call(S, PyroFX.LockRing, c, centre)
		local d = S.TRoot.Position - centre
		if Vector3.new(d.X, 0, d.Z).Magnitude <= SHOW.RingRadius and d.Y >= -2 and d.Y <= R.Height then
			hit(S, { Damage = R.Damage, From = centre, Burn = 1 })
		end
	end)
end

-- PASSIVE, EMBER REFUND (handlers.EmberRefund; PyroHandler: a hit taking an enemy from Below or over to under it)
local function refundCycle(S)
	local c = S.Caster
	local F, E = PyroFX.Tuning.Fireball, PyroFX.Tuning.EmberRefund
	local hum = S.Target:FindFirstChildOfClass("Humanoid")
	local kill = E.Trigger == "Kill"                                  -- (the rule before 2026-10-17: a kill)
	if hum then hum.Health = kill and F.Direct or SHOW.RefundHealth end
	throw(S, "R", false, function(_, from)
		local max = hum and hum.MaxHealth or 100
		local before = hum and hum.Health or max
		local after = before - F.Direct
		hit(S, { Damage = F.Direct, From = from, Word = (kill and after <= 0) and "KO!" or nil, Style = "ko" })
		local fired = kill and after <= 0 or (not kill and before >= E.Below * max and after < E.Below * max)
		if fired then call(S, PyroFX.EmberRefund, c, S.TRoot.Position) end   -- From: where the enemy was hit
	end)
end

-- Play(stage) -> stop(): never errors into the caller (a preview that cannot start returns a stop that does nothing)
local function entry(key, setup, cycle)
	return function(stage)
		local ok, stop = pcall(run, stage, key, setup, cycle)
		if ok and type(stop) == "function" then return stop end
		warnOnce("play:" .. key, key .. ": " .. tostring(stop))
		return function() end
	end
end

local function move(key, slot, setup, cycle)
	return { Key = key, Name = NAMES[key], Slot = slot, Play = entry(key, setup, cycle) }
end

return {
	Element = ELEMENT,
	Moves = {
		move("Fireball", "M1", nil, fireballCycle),
		move("Immolate", "Primary", nil, immolateCycle),
		move("Detonate", "Mobility", nil, detonateCycle),
		move("ScorchingLash", "Defense", nil, lashCycle),
		move("RingOfFire", "Ultimate", nil, ringCycle),
		move("EmberRefund", "Passive", nil, refundCycle),
	},
}
