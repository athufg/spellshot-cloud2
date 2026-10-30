--[[
	AltarMoves_Terra  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Terra

	The Loadout Altar showcase's Terra page (2026-10-26, the owner: the altar plays every move of the Element on the
	dais, in the wrap being looked at; CONTRACT v2 the same day: a caster you can see PERFORMS each move on a target you
	can see, which takes the hit the way a duel shows it). Moves = Terra's kit in loadout order -- Boulder Shot, Bulwark
	Charge, Aftershock, Bulwark Wall, Earthen Tomb, Bedrock (its M1 / Primary / Passive, Config.ElementDefaults.Terra, its
	own Ultimate). Each Play(stage) loops one cast -> hit beat on the stage's two mannequins (AltarStage):
	  * stage.Caster CASTS with the game's own third-person body: CastPose (ReplicatedStorage.IceMagic.CastPose -- the one
	    instance AbilityFX drives) playing the clips AbilityFX and CastPose.Start play off TerraHandler's broadcasts:
	    BoulderWindup (clocked from the press) -> BoulderThrow, Aftershock on TerraFX.AftershockClock, BulwarkWallRaise
	    held, EarthenTombSlam -> EarthenTombRaise on the climb's own clock. Bulwark Charge has no clip: the body runs
	    (the root carries the run's speed, so CastPose strides). The real TerraFX draw goes off on that clip's beat with
	    AbilityFX's payload shapes, aimed from the caster at the target.
	  * stage.Target TAKES it: the move's own impact look on or at it, then stage.React.Hit with TerraHandler's numbers
	    (TerraFX.Tuning): Boulder Shot ChargeDamage(charge); Bulwark Charge 35, Staggered 1.2 s and thrown 30 along / 14
	    up; Aftershock 20 and thrown 36 / 22 x the front's strength where it stood; Earthen Tomb ridden up on the slab
	    (TombRise) and burst for 50 x 1.5 with ENTOMBED!. Bulwark Wall hits nobody: its turn has the target throw Boulder
	    Shot taps that break on the wall (TerraFX.WallHit off the server's own hit point), as an enemy's shots do.
	Every round starts from rest: React.Reset, the caster back on its mark and on CastPose's Ready stance. stop() ends it
	at once -- the loop, every FX handle, the poses (CastPose Stop / SetBase(nil) / SetAim(nil); a target this page posed
	is handed back, CastPose.Release), the dummies reset, the WrapOf hook taken off -- and is safe to call twice. Client
	only: no remotes, no damage, nothing the server hears of. Nothing here clones or hides a rig any more.

	THE WRAP (stage.Wrap) reaches every draw of the caster's two ways, as it does in combat:
	  * the Boulder Shot kit's pieces (the rock, Bulwark Charge's armour and knockdown, Bedrock's plates) take TerraWrap's
	    BUILT set, handed straight in as a table (every one of those calls takes a set as well as an id -- AbilityFX's
	    d.Skin). It is the set at the viewer's own glow (TerraWrap.Glow(skin, true)) -- the one TerraFX.WatchWraps builds
	    for its wearer -- so a preview of your own wrap builds nothing twice. While it builds (EditableMesh copies) the
	    first round waits for it rather than drawing Default; one that never comes (no mesh budget, no TerraM1 kit) draws
	    Default, and every later round tries again.
	  * the ChargedRock kits (Aftershock, Bulwark Wall, Earthen Tomb) read theirs through ChargedRock.WrapOf(character),
	    which knows only players (and Studio's WrapStudio). So while one of those previews runs WrapOf is wrapped: the
	    stage's caster (and the Tomb's spare key) get the wrap built exactly as WrapOf builds it for the wearer's own view
	    (mirrorWrapOf, below), every other character goes to the real WrapOf. The wrapper comes off when the last preview
	    stops.
	The target's own Boulder Shots on the Wall's turn are an enemy's: Default, never the wrap being looked at.
(2026-10-26) THE SKIN: the wrap is AltarStage.Look's -- with stage.Skin on (Terra has none in SkinCatalog yet) a Terra
wrap never goes over it (WrapsOverSkin), and the WrapOf wrapper then leaves the caster to the real WrapOf rather than
forcing "Default" over the skin the caster wears (ShowcaseSkin). Swept for what a cast needs that a dummy lacks:
nothing new -- the clips CastPose.Start plays off a Terra's attributes (the Wall's brace, the Tomb's phases) are
played by hand, Bedrock is called for the caster, Staggered reaches the stars through TrainingGround (React.Hit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local WRAP_WAIT = 5            -- s the first round waits for a wrap's Boulder Shot set to build before drawing Default
local HUB = "ArcaneObservatoryHub"       -- (HubLife.Hub) left out of every throw's hit test, with every player

----------------------------------------------------------------------------------------------------
-- modules, found lazily (only ever from a move's own loop thread: Play never waits, nor does stop)
----------------------------------------------------------------------------------------------------
local mods = {}
local warned = {}

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Terra] " .. tostring(msg))
end

--- IceMagic's (or Spellshot's) module `name`, required once; nil when it is not there or failed. `wait` false: only
--- what is already in the tree (a stop must never wait on anything)
local function need(name, home, wait)
	local m = mods[name]
	if m ~= nil then return m or nil end
	home = home or "IceMagic"
	local folder = ReplicatedStorage:FindFirstChild(home)
	if not folder and wait ~= false then folder = ReplicatedStorage:WaitForChild(home, 5) end
	local inst = folder and folder:FindFirstChild(name)
	if not inst and folder and wait ~= false then inst = folder:WaitForChild(name, 5) end
	if not inst then return nil end
	local ok, mod = pcall(require, inst)
	mods[name] = (ok and type(mod) == "table") and mod or false
	if not mods[name] then warnOnce("req:" .. name, name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

local function flat(v, fallback)
	local f = typeof(v) == "Vector3" and Vector3.new(v.X, 0, v.Z) or Vector3.zero
	return f.Magnitude > 1e-3 and f.Unit or fallback
end

local function now() return workspace:GetServerTimeNow() end

--- the review slow-motion (VFXLibrary.ShotTimeScale): every beat TerraHandler times runs this much slower in real time
local function timeScale()
	local V = need("VFXLibrary", nil, false)
	local ok, s = pcall(function() return V.ShotTimeScale() end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

local function rootOf(m)
	return typeof(m) == "Instance" and m:FindFirstChild("HumanoidRootPart") or nil
end

--- where a body is aimed at: its chest (a crosshair on a body), else its root
local function aimPoint(m)
	local p = typeof(m) == "Instance" and (m:FindFirstChild("UpperTorso") or rootOf(m)) or nil
	return p and p.Position or nil
end

--- where a dummy stands at rest: the mark AltarStage stamped (AltarHome, its root) turned to face `look`, else where
--- it is now
local function restCF(m, look)
	if typeof(m) ~= "Instance" then return nil end
	local h = m:GetAttribute("AltarHome")
	if typeof(h) ~= "Vector3" then return m:GetPivot() end
	return CFrame.lookAt(h, h + look)
end

--- CastPose[fn](...) on the live CastPose (IceMagic's, the instance AbilityFX poses every body with), never erroring
--- into the move
local function pose(fn, ...)
	local CP = need("CastPose", nil, false)
	local f = CP and CP[fn]
	if type(f) ~= "function" then return nil end
	local ok, r = pcall(f, ...)
	return ok and r or nil
end

--- a clip's release beat (CastPose.Clips[name].Trigger), or `fallback` when CastPose cannot say
local function clipTrigger(name, fallback)
	local CP = need("CastPose", nil, false)
	local c = CP and type(CP.Clips) == "table" and CP.Clips[name]
	return (type(c) == "table" and type(c.Trigger) == "number") and c.Trigger or fallback
end

----------------------------------------------------------------------------------------------------
-- the previews running, and the WrapOf wrapper for their casters
----------------------------------------------------------------------------------------------------
local lives = {}                                          -- [life] = true while that preview runs
local previewWrap = setmetatable({}, { __mode = "k" })    -- [caster or key] = the wrap id it wears ("Default": none)
local shim = {}                                           -- { CR, Live, Fn } while WrapOf is wrapped
local mirrored = {}                                       -- [ChargedRock's own cache key] = a WrapOf object

--- previewWrap rebuilt from the previews still running; the wrapper taken off when none is. (2026-10-26) A preview in
--- a skin with no wrap over it is left out: forcing "Default" there would draw the Default over the skin, so its casters
--- go to the real WrapOf (whatever the skin's kit says for its wearer)
local function rewear()
	table.clear(previewWrap)
	for life in pairs(lives) do
		if not (life.Skin and life.Wrap == "Default") then
			for _, m in ipairs(life.Casters) do previewWrap[m] = life.Wrap end
		end
	end
	if next(lives) == nil and shim.CR then
		if shim.CR.WrapOf == shim.Fn then shim.CR.WrapOf = shim.Live end   -- (never undo somebody else's wrapper)
		table.clear(shim)
	end
end

--- ChargedRock.WrapOf's own build, line for line, for a preview caster wearing `id`: the same Resolve, the same Tn over
--- ChargedRock.Tuning, the same ladder fields (Pulse / Flow / Layers / Core), at the WEARER'S OWN view (CrackGlowOwn) --
--- and the same cache key ("<Id>+<glow>"), so its pooled pieces are the ones the wearer's own casts use. Keep it in step
--- with ChargedRock.WrapOf.
local function mirrorWrapOf(CR, id, ability)
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local mod = spell and spell:FindFirstChild("SkinCatalog")
	local S = mod and require(mod)
	if type(S) ~= "table" then return nil end
	local skin = S.Resolve("Terra", ability, id)
	if not (type(skin) == "table" and skin.Tint and skin.Seam) then return nil end
	local g = mod:GetAttribute("CrackGlow")
	if type(g) ~= "number" then g = skin.CrackGlow or 0.6 end
	local k = mod:GetAttribute("CrackGlowOwn")
	g *= (type(k) == "number" and k) or skin.CrackGlowOwn or 0.8
	local key = skin.Id .. "+" .. math.floor(math.clamp(g, 0, 1) * 20 + 0.5)
	local w = mirrored[key]
	if w then return w end
	local sm = skin.Seam
	w = { Key = key, Skin = skin, Tint = skin.Tint, Tn = setmetatable({ EmberColour = sm.Ember,
		Gold = sm.Ember:Lerp(sm.Hot, math.clamp(0.4 + g, 0, 1)), Inner = sm.Inner, Dead = sm.Dead },
		{ __index = CR.Tuning }) }
	if skin.Pulse or skin.Flow or skin.Layers then
		local TW = type(CR.TerraWrap) == "function" and CR.TerraWrap() or nil
		local Tn = w.Tn
		local pz = skin.Pulse
		if type(pz) == "table" and type(pz.Period) == "number" and pz.Period > 0 then
			Tn.PulseHz = 1 / pz.Period
			if type(pz.Amp) == "number" then Tn.PulseA = pz.Amp end
		end
		if TW and type(skin.Flow) == "table" and type(TW.FlowMul) == "function" then Tn.Flow = skin.Flow end
		if TW and (skin.Pulse or skin.Flow) and type(TW.Calm) == "function" then Tn.WrapCalm = TW.Calm end
	end
	local core = skin.Core
	if type(core) == "table" and core.Brk and typeof(core.Color) == "Color3" then
		w.Tn.Core = { Color = core.Color, Hot = typeof(core.HotColor) == "Color3" and core.HotColor or w.Tn.Gold }
	end
	mirrored[key] = w
	return w
end

--- ChargedRock.WrapOf wrapped (once, while previews run): a caster in previewWrap gets its preview's wrap, any other
--- character the real WrapOf. Its callers (TerraFX_Wall.Raise, TerraFX_Tomb's newFx, TerraFX's Aftershock asNew) all go
--- through the module table at the cast, so the wrapper reaches every one of them.
local function ensureShim(CR)
	if shim.CR or type(CR) ~= "table" or type(CR.WrapOf) ~= "function" then return end
	local live = CR.WrapOf
	local function wrapOf(character, ability)
		local id = typeof(character) == "Instance" and previewWrap[character] or nil
		if id == nil then return live(character, ability) end
		if id == "Default" then return nil end
		local ok, w = pcall(mirrorWrapOf, CR, id, ability)
		return ok and w or nil                                -- (a failed mirror draws Default)
	end
	shim.CR, shim.Live, shim.Fn = CR, live, wrapOf
	CR.WrapOf = wrapOf
end

--- The Boulder Shot kit's built set for this preview's wrap (nil: Default), waiting up to `wait` s for it to build
--- (0: one look, no wait).
local function wrapSetFor(TF, life, wait)
	local id = life.Wrap
	if id == "Default" then return nil end
	local folder = ReplicatedStorage:FindFirstChild("EarthMagicMeshes")
	local kit = folder and folder:FindFirstChild("TerraM1")
	if not (kit and kit:FindFirstChild("TR_M1_Origin", true)) then return nil end   -- (no mesh kit: no wrap is ever built)
	local TW = need("TerraWrap")
	local okS, skin = pcall(function() return TW.Skin("BoulderShot", id) end)
	if not (okS and type(skin) == "table") then return nil end
	local okG, glow = pcall(TW.Glow, skin, true)                        -- the wearer's own view: WatchWraps' set
	if not okG then glow = nil end
	local t0 = os.clock()
	while true do
		local ok, set = pcall(TF.WrapSet, id, glow)
		if ok and type(set) == "table" then return set end
		if life.Dead or os.clock() - t0 >= wait then return nil end
		task.wait(0.25)
	end
end

----------------------------------------------------------------------------------------------------
-- one preview: its life, its rounds, its stop
----------------------------------------------------------------------------------------------------
local function begin(stage)
	local caster = stage.Caster or stage.Key
	local R = flat(stage.CF.RightVector, Vector3.zAxis)
	-- (2026-10-26) the look, AltarStage.Look's one rule: the skin worn (Terra has none in SkinCatalog yet) and the wrap
	-- drawn -- over a skin only a wrap SkinCatalog lets over one (WrapsOverSkin: never Terra's material wraps)
	local skin, wrap = nil, (type(stage.Wrap) == "string" and stage.Wrap ~= "") and stage.Wrap or "Default"
	local React = stage.React
	if type(React) == "table" and type(React.Look) == "function" then
		local ok, s, w = pcall(React.Look, stage, "Terra")
		if ok then skin, wrap = s, w end
	end
	local life = { Dead = false, Stage = stage, Caster = caster, Target = stage.Target, R = R, React = stage.React,
		Clean = {}, Shots = {}, Casters = { caster }, Skin = skin, Wrap = wrap }
	life.Home = restCF(caster, R)                              -- the caster's mark, facing the target
	lives[life] = true
	rewear()
	return life
end

--- the stage's reaction call `fn` (React.Hit / React.Reset), never erroring into the move
local function react(life, fn, opts)
	local R = life.React
	local f = type(R) == "table" and R[fn]
	if type(f) == "function" then pcall(f, life.Stage, opts) end
end

local function hit(life, opts) react(life, "Hit", opts) end

--- REST, between rounds and on stop: both dummies home and whole (React.Reset), the caster off every clip, base and
--- aim, on the Ready stance, standing on its mark facing the target, its root still
local function rest(life)
	local c = life.Caster
	if typeof(c) ~= "Instance" then return end
	pose("Stop", c)
	pose("SetBase", c, nil)
	pose("SetAim", c, nil)
	pose("SetStance", c, "Ready")
	react(life, "Reset")
	if c.Parent and life.Home then
		pcall(function()
			c:PivotTo(life.Home)
			local r = rootOf(c)
			if r then r.AssemblyLinearVelocity = Vector3.zero end
		end)
	end
end

--- stop(): the loop told to end, every clean-up the move registered run (newest first), the dummies back at rest, a
--- target this page posed handed back to its rig. Safe to call twice; never waits.
local function finish(life)
	if life.Dead then return end
	life.Dead = true
	for i = #life.Clean, 1, -1 do
		local ok, err = pcall(life.Clean[i])
		if not ok then warnOnce("clean", "clean-up: " .. tostring(err)) end
	end
	table.clear(life.Clean)
	pcall(rest, life)
	if life.PosedTarget and typeof(life.Target) == "Instance" then
		pose("Stop", life.Target)
		pose("Release", life.Target)                            -- (off CastPose's Ready stance: back to the plain rig)
	end
	lives[life] = nil
	rewear()
end

--- A round's rock gone: once it has broken (still held, its own step drops it on the next frame; in flight, it meets
--- what it was thrown at inside a tenth of a second), its model, hosts and marks are destroyed.
--- (Only a broken rock: TerraFX's aftermath checks every part's Parent; the in-hand and in-flight steps do not.)
local function retire(shot, tries)
	local rock = shot.Rock
	if type(rock) ~= "table" then return end
	if not rock.Broken and tries < 30 then
		task.delay(0.1, retire, shot, tries + 1)
		return
	end
	pcall(function()
		for _, m in ipairs(rock.Marks or {}) do m.Host:Destroy() end
		if rock.ImpactHost then rock.ImpactHost:Destroy() end
		if rock.BurstHost then rock.BurstHost:Destroy() end
		if rock.Model then rock.Model:Destroy() end
	end)
end

--- every rock this preview threw or holds: held ones let go (they fall apart in the hand), then all of them retired
local function dropShots(life)
	for _, s in ipairs(life.Shots) do
		s.Drop = true
		retire(s, 0)
	end
	table.clear(life.Shots)
end

--- rounds long over: their rock is gone, so they are forgotten
local function pruneShots(life)
	for i = #life.Shots, 1, -1 do
		local rk = life.Shots[i].Rock
		if not (type(rk) == "table" and rk.Model and rk.Model.Parent) then table.remove(life.Shots, i) end
	end
end

--- Play's shape for every move: `body(life)` runs on its own thread (Play returns at once); its stop() is returned.
local function run(name, stage, body)
	local okB, life = pcall(begin, stage)
	if not okB then
		warnOnce(name, name .. ": " .. tostring(life))
		return function() end
	end
	table.insert(life.Clean, function() dropShots(life) end)
	task.spawn(function()
		local ok, err = pcall(function()
			life.React = life.React or need("AltarStage", "Spellshot")   -- (contract v2 always hands it in)
			need("CastPose")                                            -- (resolved here, so pose() never waits)
			need("VFXLibrary")
			if not life.Dead then body(life) end
		end)
		if not ok and not life.Dead then warnOnce(name, name .. ": " .. tostring(err)) end
	end)
	return function() pcall(finish, life) end
end

--- `cycle(n)` every `period` s until stop, each round from rest (a cycle that fails says so once, and the next round
--- tries again)
local function loop(life, name, period, cycle)
	local n = 0
	while not life.Dead do
		n += 1
		local t0 = os.clock()
		pcall(rest, life)
		local ok, err = pcall(cycle, n)
		if not ok and not life.Dead then warnOnce(name, name .. ": " .. tostring(err)) end
		if life.Dead then return end
		task.wait(math.max(period - (os.clock() - t0), 0.03))
	end
end

--- waits `s` s; false when the preview was stopped meanwhile (the caller's beat must not fire)
local function sleep(life, s)
	task.wait(math.max(s, 0))
	return not life.Dead
end

-- ====================================================================================================
-- THE THROW: one Boulder Shot from a body's own hand (M1, Bedrock, and the target's taps on the Wall)
-- ====================================================================================================
-- AbilityFX's draw of anybody's throw but your own, beat for beat. BoulderChargeStart: the body's windup clocked in
-- seconds from the press (CastPose BoulderWindup -- the reach, the core landing on the palm at its Trigger, the arm
-- cocked and WOUND at a full charge, held) while TerraFX.Charge gathers the rock on that body's right hand (bodyHand:
-- the hand's frame, no eye, the flat facing) out of the floor. BoulderShot: BoulderThrow from wherever the body is,
-- and TerraFX.FireBoulder flying THAT rock from the head down the aim, through the thrower (shotExclude: a body with no
-- player is { c }), breaking on the first thing it meets -- on a body, the crater at its feet. `OnHit(result, shot)` is
-- told the moment it breaks (FireBoulder's own onHit).
local BS_FULL_HOLD = 0.25      -- s held past a full charge before the release, so the squeeze ring at full reads first

local function bodyHand(c)
	return function()
		if not c.Parent then return nil end
		local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		local root = c:FindFirstChild("HumanoidRootPart")
		if not (hand and hand.Parent and root) then return nil end
		local look = root.CFrame.LookVector
		return hand.CFrame, nil, CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
	end
end

local function shotExclude(who)
	local list = { who }
	local hub = workspace:FindFirstChild(HUB)
	if hub then list[#list + 1] = hub end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then list[#list + 1] = pl.Character end
	end
	return list
end

--- `who` gathers for `hold` s and throws at `aim()`; o = { Set (the wrap's built set, nil Default), Thin, OnHit }.
--- Returns the shot { Rock, U, Origin } once the rock has left the hand, or nil when the preview stopped first.
local function boulder(life, who, hold, aim, o)
	local TF = need("TerraFX")
	local B = TF.Tuning.BoulderShot
	local t0 = os.clock()
	local shot = { At = t0 }
	life.Shots[#life.Shots + 1] = shot
	pose("PlayClocked", who, "BoulderWindup", function() return os.clock() - t0 end)
	shot.Rock = TF.Charge(function()
		if life.Dead or shot.Drop or not who.Parent then return nil end   -- nil: the hold is over, the rock falls apart
		return math.clamp((os.clock() - t0) / B.ChargeTime, 0, 1)
	end, bodyHand(who), { Thin = o.Thin == true, Character = who, Wrap = o.Set })
	if not sleep(life, hold) then return nil end
	local ok, err = pcall(function()
		local rock = shot.Rock
		local head = who:FindFirstChild("Head") or rootOf(who)
		local goal = aim()
		if not (head and goal) then error("no head or no aim", 0) end
		local origin = head.Position
		local dir = goal - origin
		if dir.Magnitude < 0.5 then error("aimed at itself", 0) end
		shot.Origin = origin
		shot.U = (type(rock) == "table" and type(rock.U) == "number") and rock.U or math.clamp(hold / B.ChargeTime, 0, 1)
		local live = (type(rock) == "table" and not rock.Broken and not rock.Thrown) and rock or nil
		local hand = who:FindFirstChild("RightHand")
		pose("Play", who, "BoulderThrow")                     -- the body throws for every client, as AbilityFX's does
		TF.FireBoulder(origin, dir.Unit, shot.U, shotExclude(who), live or (hand and hand.Position) or nil,
			function(result)
				if life.Dead or not o.OnHit then return end
				local okH, errH = pcall(o.OnHit, result, shot)
				if not okH then warnOnce("hit", "on hit: " .. tostring(errH)) end
			end, o.Set)
	end)
	if not ok then
		shot.Drop = true                                        -- (never leave a rock held for good)
		error(err, 0)
	end
	return shot
end

--- the target's reaction to a Boulder Shot that broke on it: TerraHandler's ChargeDamage at the throw's charge (no
--- knock, no status: the server deals the damage and nothing else), so a lean away from the thrower
local function boulderStrikes(life, TF)
	return function(result, shot)
		local t = life.Target
		if not (typeof(t) == "Instance" and result.Instance and result.Instance:IsDescendantOf(t)) then return end
		hit(life, { Damage = TF.ChargeDamage(shot.U), From = shot.Origin })
	end
end

-- ====================================================================================================
-- M1: BOULDER SHOT
-- ====================================================================================================
-- The caster holds a full charge -- the windup reaching down, the rock torn out of the dais onto its palm, the feeders
-- pressed in, the cracks lighting at the tiers, the arm wound and trembling -- and throws it at the target, where it
-- breaks back into its pieces (the dust, sparks, flash, rubble and crater are the break's own) and the target takes
-- the full charge's 48. (Bedrock's plates, which a full hold also builds, are the Passive's page.)
local BS_PERIOD = 3.1          -- s a round: the 1.1 s charge, the hold, the throw and its 0.83 s follow-through, the break

local function playBoulderShot(stage)
	return run("BoulderShot", stage, function(life)
		local TF = need("TerraFX")
		if not (TF and typeof(life.Caster) == "Instance" and rootOf(life.Target)) then return end
		local B = TF.Tuning.BoulderShot
		local set = wrapSetFor(TF, life, WRAP_WAIT)
		local strikes = boulderStrikes(life, TF)
		loop(life, "BoulderShot", BS_PERIOD, function()
			pruneShots(life)
			set = set or wrapSetFor(TF, life, 0)
			boulder(life, life.Caster, B.ChargeTime + BS_FULL_HOLD, function() return aimPoint(life.Target) end,
				{ Set = set, Thin = false, OnHit = strikes })
		end)
	end)
end

-- ====================================================================================================
-- PRIMARY: BULWARK CHARGE
-- ====================================================================================================
-- The real charge's look, as AbilityFX draws somebody else's: TerraFX.BulwarkTrail on the charging body (three of
-- Bedrock's plates snapping onto its front, the footfalls tearing up dust) for as long as the dash runs, and
-- TerraFX.BulwarkHit -- the flat comic knockdown burst of rock -- at the target's root the moment the shoulder's box
-- reaches it (TerraHandler's sweep: Reach ahead of the root). The charge has no clip: the body RUNS -- its anchored root
-- carries the run's velocity, so CastPose strides on the Sprint stance (and the wrap's seams light with the pace) --
-- carried along the stage by PivotTo. The target takes 35, goes Staggered (the stars) and is thrown 30 along the
-- charge and 14 up; the caster runs on through, then walks back to its mark.
local BC_RUN = 12              -- studs it runs: through the target's reach and on, as the live charge runs through bodies
local BC_SPEED = 30            -- studs/s; the live pace is Distance / Time = 42 over 26 studs -- a 12-stud run at that is
                               -- a blink, so the stage's run is a touch slower
local BC_BRACE = 0.12          -- s the armour flies in before the feet go
local BC_BACK_AT = 1.25        -- s after the brace begins the caster turns and walks back to its mark
local BC_WALK = 14             -- studs/s, the walk back
local BC_PERIOD = 3.0          -- s a round: the brace, the 0.4 s run, the throw and its stars, the walk back

local function playBulwarkCharge(stage)
	return run("BulwarkCharge", stage, function(life)
		local TF = need("TerraFX")
		local caster, root = life.Caster, rootOf(life.Caster)
		if not (TF and root and rootOf(life.Target) and life.Home) then return end
		local C = TF.Tuning.BulwarkCharge
		local R = life.R
		local home = life.Home
		local live = nil                                               -- this round's charge: { On }
		table.insert(life.Clean, function()
			if live then live.On = false end                           -- (the armour cracks off)
			pose("SetStance", caster, "Ready")
		end)
		local set = wrapSetFor(TF, life, WRAP_WAIT)
		loop(life, "BulwarkCharge", BC_PERIOD, function()
			set = set or wrapSetFor(TF, life, 0)
			local troot = rootOf(life.Target)
			if not troot then return end
			local hitAt = (troot.Position - home.Position):Dot(R) - C.Reach   -- the shoulder's box meets them here
			local t0 = os.clock()
			local charge = { On = true }
			live = charge
			TF.BulwarkTrail(caster, function() return charge.On and not life.Dead end, set)
			local ok, err = pcall(function()
				if not sleep(life, BC_BRACE) then return end
				pose("SetStance", caster, "Sprint")
				local x, last, struck = 0, os.clock(), false
				while x < BC_RUN do
					task.wait()
					if life.Dead then return end
					local t = os.clock()
					x = math.min(BC_RUN, x + BC_SPEED * (t - last))
					last = t
					caster:PivotTo(home + R * x)
					root.AssemblyLinearVelocity = R * BC_SPEED          -- (an anchored root keeps it; CastPose and the trail read it)
					if not struck and x >= hitAt then
						struck = true
						-- TerraHandler's sweep, on the dummy: BulwarkHit at their root (the set itself: no second, own-view
						-- build), then the hit -- the damage, Staggered, and thrown along the charge and up
						TF.BulwarkHit(troot.Position, R, false, set)
						hit(life, { Damage = C.Damage, From = root.Position, Stagger = C.Stagger,
							Knock = R * C.Knock + Vector3.new(0, C.KnockLift, 0) })
					end
				end
			end)
			charge.On = false
			pose("SetStance", caster, "Ready")
			if not life.Dead then root.AssemblyLinearVelocity = Vector3.zero end
			if not ok then error(err, 0) end
			-- ...and back to its mark at a walk, turned round (CastPose strides off the root's speed)
			if not sleep(life, BC_BACK_AT - (os.clock() - t0)) then return end
			local from = caster:GetPivot().Position
			local gap = Vector3.new(home.Position.X - from.X, 0, home.Position.Z - from.Z)
			local dist = gap.Magnitude
			if dist > 0.2 then
				local back = gap.Unit
				local turned = CFrame.lookAt(from, from + back)
				local d, last = 0, os.clock()
				while d < dist do
					task.wait()
					if life.Dead then return end
					local t = os.clock()
					d = math.min(dist, d + BC_WALK * (t - last))
					last = t
					caster:PivotTo(turned + back * d)
					root.AssemblyLinearVelocity = back * BC_WALK
				end
			end
			root.AssemblyLinearVelocity = Vector3.zero
			caster:PivotTo(home)
		end)
	end)
end

-- ====================================================================================================
-- MOBILITY: AFTERSHOCK
-- ====================================================================================================
-- The real cast: the caster's body on CastPose's Aftershock clip, clocked as AbilityFX clocks every Terra's
-- (TerraFX.AftershockClock: the fists overhead, the drive, the contact frame HELD through the hitpause), and
-- TerraFX.Aftershock from the fists' point -- Reach ahead of its root, on the floor -- with the same T0 (the windup's
-- thumps under the feet, the ring of erupting rock racing out on TerraHandler's own curve, the scar healing). The
-- moment the front comes within BodyRadius of the target (AftershockFrontT, the curve the server hits on),
-- TerraFX.AftershockStrike throws the shard up under them and they take 20 and are thrown out from the centre and up
-- (36 / 22 x AftershockStrength where they stood, never under KnockMin).
local AS_PERIOD = 4.0          -- s a round: the 0.68 s windup, the hitpause, the ring, the throw (a cast is gone ~4.7 s
                               -- in; rounds overlap, each its own plate set)

local function playAftershock(stage)
	return run("Aftershock", stage, function(life)
		local TF, CR = need("TerraFX"), need("ChargedRock")
		local caster = life.Caster
		if not (TF and typeof(caster) == "Instance" and rootOf(life.Target) and life.Home) then return end
		if CR then ensureShim(CR) end
		local A = TF.Tuning.Aftershock
		local R = life.R
		local casts = {}
		table.insert(life.Clean, function()
			for _, h in ipairs(casts) do pcall(h.Stop) end             -- (asTeardown: everything of a cast at once)
			table.clear(casts)
		end)
		-- the server's At: the floor Reach ahead of the root along its flat facing
		local hp = life.Home.Position
		local centre = Vector3.new(hp.X, stage.Floor.Y, hp.Z) + R * A.Reach
		loop(life, "Aftershock", AS_PERIOD, function()
			for i = #casts, 1, -1 do
				if casts[i].Dead then table.remove(casts, i) end
			end
			local troot = rootOf(life.Target)
			if not troot then return end
			local tp = troot.Position
			local feet = Vector3.new(tp.X, stage.Floor.Y, tp.Z)          -- the victim's feet, on the floor
			local out = flat(feet - centre, R)
			local r = Vector3.new(feet.X - centre.X, 0, feet.Z - centre.Z).Magnitude
			local t0 = now()
			pose("PlayClocked", caster, "Aftershock", function()
				return TF.AftershockClock((now() - t0) * timeScale())
			end)
			local h = TF.Aftershock(caster, centre, R, t0, { Own = false, Thin = false, Seed = math.random(1, 2 ^ 30) })
			if type(h) ~= "table" then return end
			casts[#casts + 1] = h
			-- the front leaves after the slam's hitpause and reaches the target's body FrontT(r - BodyRadius) later
			local reach = math.max(0, r - A.BodyRadius)
			if not sleep(life, (A.Hit + A.HoldFrames / 60 + TF.AftershockFrontT(reach)) / timeScale()) then return end
			if h.Dead then return end
			TF.AftershockStrike(caster, life.Target, feet, out, now())
			local k = math.max(A.KnockMin, TF.AftershockStrength(r))
			hit(life, { Damage = A.Damage, From = centre,
				Knock = out * (A.KnockOut * k) + Vector3.new(0, A.KnockLift * k, 0) })
		end)
	end)
end

-- ====================================================================================================
-- DEFENSE: BULWARK WALL
-- ====================================================================================================
-- The real wall: the caster's hand calls it up and braces behind it (CastPose BulwarkWallRaise, a held clip, played
-- and let go by hand the way CastPose.Start does off Holding_Defense), and TerraFX.WallRaise on its beat -- TerraFX_Wall's
-- rework while its kit is in: the stack slamming up out of its slot WallAhead in front of Terra, facing where she faces,
-- the floor plates thrown aside. The wall hits nobody; what it does is stop shots, so on its turn the TARGET fights:
-- three Boulder Shot taps (its own windup and throw, an enemy's Default rock) that break on the wall's body -- the
-- invisible box the server stands there, a Humanoid on it as on the server's -- each landing as TerraFX.WallHit at
-- the server's own point (the thrower's side of the face) with the health left (WallHP less each tap's ChargeDamage).
-- Then down: "Broken" every other round (the damaged slabs burst, the rest topple), let go between ("Released": the
-- stack sinks back into the floor), the brace released with it.
local WALL_PERIOD = 4.2
local WALL_YAW = math.rad(30)  -- the caster (and so the wall) turned this far toward the camera's side, so the face the
                               -- hits land on and show their damage on is seen, not edge-on; it still stands square
                               -- between the two
local WALL_SHOTS = { 0.35, 1.05, 1.75 }   -- s after the press each of the target's taps begins
local WALL_TAP = 0.3           -- s each tap is held: past Core (the rock whole), a third of the way to full
local WALL_DOWN = 2.7          -- s after the press it comes down
local WALL_FAST = 2.0          -- stop(): the let-go is dated this far back, so the wall's own sink is all but over at once
                               -- (a wall already Broken finishes its rubble on its own: those pieces are ChargedRock's pool)

--- the wall body's size, as TerraHandler takes it: BulwarkWallKitData with the rework's kit in, else the old slabs' box,
--- else the kit's build numbers
local function wallSize()
	local kits = ReplicatedStorage:FindFirstChild("EarthMagicMeshes")
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local data = spell and spell:FindFirstChild("BulwarkWallKitData")
	if data and kits and kits:FindFirstChild("TerraWall2") then
		local ok, d = pcall(require, data)
		if ok and type(d) == "table" and typeof(d.Size) == "Vector3" then
			return Vector3.new(d.Size.X, d.Size.Y + (tonumber(d.Foot) or 0), d.Size.Z)
		end
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for n = 1, 12 do
		local p = kits and kits:FindFirstChild(("TR_Wall_Slab_%02d"):format(n), true)
		if p and p:IsA("BasePart") then
			local c, h = p:GetPivot().Position, p.Size / 2
			lo, hi = lo:Min(c - h), hi:Max(c + h)
		end
	end
	if hi.X > lo.X then return hi - lo end
	return Vector3.new(12.4, 8.4, 1.7)
end

--- the server's wall body on the stage: an anchored, raycastable, invisible box on its foot `cf`, with a Humanoid (what
--- every hit in the game damages), so the rock breaks on it as on the real one
local function wallBody(stage, cf, size, hp)
	local m = Instance.new("Model")
	m.Name = "BulwarkWall"
	local body = Instance.new("Part")
	body.Name = "WallBody"
	body.Size = size
	body.CFrame = cf * CFrame.new(0, size.Y / 2, 0)
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch, body.CastShadow = true, false, true, false, false
	body.Transparency = 1
	body.Parent = m
	local hum = Instance.new("Humanoid")
	hum.MaxHealth, hum.Health = hp, hp
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	pcall(function() hum.EvaluateStateMachine = false end)
	hum.Parent = m
	m.PrimaryPart = body
	m.Parent = stage.Parent
	return m, body
end

--- TerraHandler's WallHit point: the attacker's side of the face, `from` (where the shot came from) projected onto it
local function wallPoint(cf, size, from)
	local rel = cf:PointToObjectSpace(from)
	return cf:PointToWorldSpace(Vector3.new(
		math.clamp(rel.X, -size.X / 2 + 0.6, size.X / 2 - 0.6),
		math.clamp(rel.Y, 0.6, size.Y - 0.6),
		rel.Z < 0 and -size.Z / 2 or size.Z / 2))
end

local function playBulwarkWall(stage)
	return run("BulwarkWall", stage, function(life)
		local TF, CR = need("TerraFX"), need("ChargedRock")
		local caster, target = life.Caster, life.Target
		if not (TF and typeof(caster) == "Instance" and rootOf(target) and life.Home) then return end
		if CR then ensureShim(CR) end
		local W = TF.Tuning.BulwarkWall
		local R = life.R
		local F = flat(stage.CF.LookVector, R:Cross(Vector3.yAxis))
		local face = (R * math.cos(WALL_YAW) + F * math.sin(WALL_YAW)).Unit
		local hp0 = life.Home.Position
		local braced = CFrame.lookAt(hp0, hp0 + face)               -- Terra, turned to where the wall will face
		local base = Vector3.new(hp0.X, stage.Floor.Y, hp0.Z) + face * W.WallAhead
		local wallCF = CFrame.lookAt(base, base + face)             -- its LookVector is its front: the face the enemy sees
		local size = wallSize()
		local up, model, body = false, nil, nil
		life.PosedTarget = true                                    -- (stop hands its rig back)
		table.insert(life.Clean, function()
			if model then model:Destroy() end
			model, body = nil, nil
			if up then
				up = false
				TF.WallDrop(caster, "Released", now() - WALL_FAST)
			end
		end)
		local trigger = clipTrigger("BulwarkWallRaise", 0.06)
		loop(life, "BulwarkWall", WALL_PERIOD, function(n)
			pruneShots(life)
			if model then model:Destroy() end
			model, body = nil, nil
			caster:PivotTo(braced)
			pose("Play", caster, "BulwarkWallRaise")                -- the hand driving up out of the ground, then the brace
			-- the slabs leave the floor on the hand's beat (the clip's Trigger against the wall's RiseTime)
			if not sleep(life, trigger / timeScale()) then return end
			TF.WallRaise(caster, wallCF, now())
			up = true
			model, body = wallBody(stage, wallCF, size, W.WallHP)
			local health = W.WallHP
			local t = trigger
			for _, at in ipairs(WALL_SHOTS) do
				if not sleep(life, at - t) then return end
				t = at + WALL_TAP
				boulder(life, target, WALL_TAP, function() return aimPoint(caster) end, {
					Thin = true,                                       -- (an enemy's: Reduce Enemy VFX thins it)
					OnHit = function(result, shot)
						if not (body and result.Instance == body and up) then return end
						health = math.max(0.01, health - TF.ChargeDamage(shot.U))
						TF.WallHit(caster, wallPoint(wallCF, size, shot.Origin), health / W.WallHP, now())
					end,
				})
			end
			if not sleep(life, WALL_DOWN - t) then return end
			up = false
			TF.WallDrop(caster, (n % 2 == 1) and "Broken" or "Released", now())
			pose("Stop", caster)                                     -- (the hold is over: the brace lets go)
			if model then model:Destroy() end
			model, body = nil, nil
		end)
	end)
end

-- ====================================================================================================
-- ULTIMATE: EARTHEN TOMB
-- ====================================================================================================
-- The real Tomb, beat by beat on TerraHandler's schedule, with the caster's body on the poses CastPose.Start gives a
-- Terra off her TombPhase (played by hand: a dummy has no phase): the two-arm SMASH (EarthenTombSlam, held) while the
-- cast is live -- TombCast: the grip, then the crack homing from the caster's feet to the target's -- then, when its
-- head is within CatchReach x CatchMargin of them (the server's verdict), TombCatch (the slab tears loose and climbs,
-- the heap erupts round them, the boulders close in) and the HAUL (EarthenTombRaise, clocked by the climb itself:
-- TombRise of its fraction). The target RIDES the slab up on that same curve (the server holds the body on it), takes
-- the burst at the top -- TombBurst, 50 x CritMultiplier and ENTOMBED!, held in place -- and rides it back down
-- (TombDescend, h x (1 - u^2)). Two keys take turns (a Tomb is drawn per caster, and a new cast by the same caster ends
-- the old one at once), so each round's descent and rubble play out while the next one casts.
local TOMB_HEIGHT = 4          -- studs the slab climbs here; the live climb is EarthenTomb.RiseHeight (12), which carries
                               -- the target, the heap and its burst out of the dais's frame
local TOMB_PERIOD = 3.8        -- s a round: grip + crack ~0.3, the climb 1.6, the beat at the top 0.45, the descent 0.8

local function rise01(u)       -- TerraFX.TombRise: the climb the server, the slab and the pose all share
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) ^ 2.2
end

local function playEarthenTomb(stage)
	return run("EarthenTomb", stage, function(life)
		local TF, CR = need("TerraFX"), need("ChargedRock")
		local caster, victim = life.Caster, life.Target
		local vroot = rootOf(victim)
		if not (TF and typeof(caster) == "Instance" and vroot and life.Home) then return end
		local spare = Instance.new("Model")                            -- the second key: only ever a table key
		spare.Name = "TerraTombCaster"
		spare:SetAttribute("AllyDummy", true)                          -- (drawn whole, as the caster's own are)
		spare.Parent = stage.Parent
		table.insert(life.Clean, function() spare:Destroy() end)
		table.insert(life.Casters, spare)
		rewear()
		if CR then ensureShim(CR) end
		local ride = nil                                               -- this round's lift of the target
		table.insert(life.Clean, function()
			if ride then ride:Disconnect() end
			ride = nil
			TF.TombEnd(caster)                                         -- (everything of a Tomb, at once)
			TF.TombEnd(spare)
		end)
		local E = TF.Tuning.EarthenTomb
		local hp = life.Home.Position
		local from = Vector3.new(hp.X, stage.Floor.Y, hp.Z)            -- the caster's feet, on the floor
		local vHome = restCF(victim, -life.R)
		local at = Vector3.new(vHome.X, stage.Floor.Y, vHome.Z)        -- the target's
		local face = flat(from - at, -life.R)                          -- the heap's lit side toward Terra
		local dist = Vector3.new(at.X - from.X, 0, at.Z - from.Z).Magnitude
		loop(life, "EarthenTomb", TOMB_PERIOD, function(n)
			local key = (n % 2 == 1) and caster or spare
			local s = timeScale()
			-- TombPhase "Cast": the smash, and the crack leaving her hands GripTime in (the clip's own Trigger)
			pose("Play", caster, "EarthenTombSlam")
			TF.TombCast(key, victim, from, now(), E.GripTime, E.FissureSpeed, E.CatchReach)
			local reach = E.CatchReach * (E.CatchMargin or 1)
			if not sleep(life, (E.GripTime + math.max(0, dist - reach) / E.FissureSpeed) / s) then return end
			-- TombPhase "Rise": caught. The slab climbs, her arm hauls on the climb's clock, and the target rides it
			local caught = now()
			TF.TombCatch(key, victim, at, face, caught, E.RiseTime, TOMB_HEIGHT)
			local function climbed() return rise01((now() - caught) * timeScale() / E.RiseTime) end
			pose("PlayClocked", caster, "EarthenTombRaise", climbed)
			local down = nil                                           -- the descent's T0, once it starts
			if ride then ride:Disconnect() end
			ride = RunService.Heartbeat:Connect(function()
				if life.Dead or not victim.Parent then return end
				local h
				if down then
					local u = math.clamp((now() - down) * timeScale() / E.DescendTime, 0, 1)
					h = TOMB_HEIGHT * (1 - u * u)
				else
					h = TOMB_HEIGHT * climbed()
				end
				victim:PivotTo(vHome + Vector3.new(0, h, 0))
			end)
			if not sleep(life, E.RiseTime / s) then return end
			-- TombPhase "Burst": still caught at the top -- the crit and the payoff word; her pose lets go
			TF.TombBurst(key, vroot.Position, true)
			pose("Stop", caster)
			hit(life, { Damage = E.BurstDamage * E.CritMultiplier, From = from, NoRecoil = true,
				Word = "ENTOMBED!", Style = "entombed" })
			if not sleep(life, E.BurstHold / s) then return end
			down = now()
			TF.TombDescend(key, down, E.DescendTime, TOMB_HEIGHT)
			-- held a moment at the bottom before letting go (TerraHandler's DescendTime + 0.2)
			if not sleep(life, (E.DescendTime + 0.2) / s) then return end
			if ride then ride:Disconnect() end
			ride = nil
			victim:PivotTo(vHome)
		end)
	end)
end

-- ====================================================================================================
-- PASSIVE: BEDROCK
-- ====================================================================================================
-- The real shell: TerraFX.Bedrock(character, stacks), which the game calls every frame for every Terra off their
-- Bedrock_Stacks (TerraFX.WatchBedrock -- players only, so this preview calls it for the caster), the stacks counted
-- TerraHandler's way: one per StackEvery while COMMITTED to an attack. The commit shown is the one it was made for, a
-- Boulder Shot held to full (five stacks in exactly the 1.1 s charge: the plates ringing in one by one, the ink pulse
-- at five), then thrown at the target (which takes it, as on the M1's page); the shell holds for Lapse after the
-- commit ends and then comes off together, every plate cracking away, newest first.
local BR_BARE = 0.5            -- s bare before the next commit

local function playBedrock(stage)
	return run("Bedrock", stage, function(life)
		local TF = need("TerraFX")
		local caster = life.Caster
		if not (TF and typeof(caster) == "Instance" and rootOf(life.Target)) then return end
		local Bd, B = TF.Tuning.Bedrock, TF.Tuning.BoulderShot
		local set = wrapSetFor(TF, life, WRAP_WAIT)
		if life.Dead then return end                                   -- (2026-10-26) stopped during the wait: finish() already ran
		local shell = { From = nil, Till = nil, Set = set }            -- the commit: began, ended (os.clock)
		local conn = RunService.Heartbeat:Connect(function()
			if life.Dead then return end
			local n = 0
			if shell.From then
				local t = os.clock()
				if shell.Till and t - shell.Till >= Bd.Lapse then
					shell.From, shell.Till = nil, nil                  -- lapsed: they go together, not one by one
				else
					n = math.min(Bd.MaxStacks, math.floor(((shell.Till or t) - shell.From) / Bd.StackEvery + 1e-6))
				end
			end
			pcall(TF.Bedrock, caster, n, shell.Set)
		end)
		table.insert(life.Clean, function()
			conn:Disconnect()
			pcall(TF.Bedrock, caster, 0)                               -- the shell comes off, newest plate first
		end)
		local strikes = boulderStrikes(life, TF)
		local hold = B.ChargeTime + BS_FULL_HOLD
		loop(life, "Bedrock", hold + Bd.Lapse + BR_BARE, function()
			pruneShots(life)
			if not set then
				set = wrapSetFor(TF, life, 0)
				shell.Set = set                                        -- (a shell takes its wrap when it is made)
			end
			shell.From, shell.Till = os.clock(), nil
			boulder(life, caster, hold, function() return aimPoint(life.Target) end,
				{ Set = set, Thin = false, OnHit = strikes })
			shell.Till = os.clock()                                    -- the throw: the commit is over
		end)
	end)
end

-- ====================================================================================================
-- the kit
-- ====================================================================================================
local Config = nil
do
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = spell and spell:FindFirstChild("SpellshotConfig")
	if m then pcall(function() Config = require(m) end) end
end

--- a display name off SpellshotConfig (`get` reads it), or `fallback` when the config cannot say
local function nameOf(get, fallback)
	local ok, n = pcall(get)
	return (ok and type(n) == "string" and n ~= "") and n or fallback
end

return {
	Element = "Terra",
	Moves = {
		{ Key = "BoulderShot", Slot = "M1", Play = playBoulderShot,
			Name = nameOf(function() return Config.Elements.Terra.M1.Name end, "Boulder Shot") },
		{ Key = "BulwarkCharge", Slot = "Primary", Play = playBulwarkCharge,
			Name = nameOf(function() return Config.Elements.Terra.Primary.Name end, "Bulwark Charge") },
		{ Key = "Aftershock", Slot = "Mobility", Play = playAftershock,
			Name = nameOf(function() return Config.Mobility.Aftershock.Name end, "Aftershock") },
		{ Key = "BulwarkWall", Slot = "Defense", Play = playBulwarkWall,
			Name = nameOf(function() return Config.Defense.BulwarkWall.Name end, "Bulwark Wall") },
		{ Key = "EarthenTomb", Slot = "Ultimate", Play = playEarthenTomb,
			Name = nameOf(function() return Config.Ultimate.EarthenTomb.Name end, "Earthen Tomb") },
		{ Key = "Bedrock", Slot = "Passive", Play = playBedrock,
			Name = nameOf(function() return Config.Elements.Terra.Passive.Name end, "Bedrock") },
	},
}
