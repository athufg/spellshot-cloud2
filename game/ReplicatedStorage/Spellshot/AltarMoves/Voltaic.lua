--[[
	AltarMoves_Voltaic  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Voltaic

	The Loadout Altar's showcase of VOLTAIC's kit, contract v2 (2026-10-26, the owner: a move preview is a little duel --
	the caster PERFORMS the move with the game's own third-person cast poses and the target TAKES it, on a loop -- not
	the effects alone off invisible rigs). Moves = the default kit in slot order: Chain Bolt (M1), Overcharge (Primary),
	Railspike (Technique 1), Volt Orb (Technique 2), Cascade (Ultimate), Chain Reaction (Passive).

	THE STAGE is the showcase's (AltarStage): stage.Caster, a visible grey R15 mannequin 7 studs left of centre facing
	+stage.CF.RightVector (AllyDummy), and stage.Target 7 studs right facing it, under workspace.TrainingGround. Nothing
	here clones, hides or parents a rig; stage.Key is read only as the caster's old name.

	EACH Play(stage), every PERIOD[move] shot seconds (2.8-4.5, the move's length and a beat) until the returned stop():
	  1 stage.React.Reset, and the caster on its rest stance (CastPose Stop, SetBase nil, SetAim nil);
	  2 the caster casts with the clip VoltaicClient.Handlers plays on an onlooker's screen, through CastPose (the one
	    instance, ReplicatedStorage.IceMagic.CastPose): IcicleShardR / L (Chain Bolt), FrostSlide (Overcharge's dash),
	    RailspikeSurge (held) then RailspikeThrow, FireballR (Volt Orb), CascadeSummon (Cascade);
	  3 the move's FX at the clip's release beat (CastPose.Clips[clip].Trigger, in shot seconds: / ShotTimeScale), through
	    the SAME calls and payload shapes the Handlers make from the broadcast -- ChainBoltFX.Fire, OverchargeFX.Cast /
	    SetPrimed / Release, RailspikeFX.Charge / Fire, VoltOrbFX.Windup / Throw / Burst, VoltaicFX.CascadeGather /
	    CascadeStrike / CascadeEnd, ChainBoltFX.Discharge, VFXLibrary.VoltSparkBurst -- aimed from the caster's eye at the
	    target's chest, the shot's point found by the same sphere / ray VoltaicClient casts;
	  4 the target takes the hit as it lands, on VoltaicTuning's numbers by VoltaicHandler's rules: Chain Bolt 10 and a
	    CHARGE xN stack, Railspike 30, Volt Orb 28 falling to 14 by flat distance (+8 on a direct hit), Cascade 14 a
	    strike. Charged filling (StatusMax_Charged, the server's preset) goes off as in a 1v1 duel -- the self-zap
	    (StatusDischarge alone), ZAP!, AloneDamage -- and Chain Reaction answers on the caster. Voltaic knocks nobody
	    back, so every hit is React.Hit's recoil.
	stop() cancels the loop thread at once, ends every FX handle, the primed tell and a windup still up, puts the caster
	on its stance and resets the stage; it never waits, and twice is fine.

	WRAPS. Voltaic has none (no SkinCatalog.ElementWraps.Voltaic, no Offer row, no draw hook in its FX modules), so
	stage.Wrap draws Default; a wrap id passed anyway warns once.

	STAGING (every choice below is the preview's, never the move's):
	  * One target, but Chain Bolt chains: its legs jump on to CHAIN, fixed points behind the target where the next bodies
	    would stand (ChainLegs for the M1, PrimedLegs for Overcharge's primed bolt). Chain Reaction is the 1v1 duel's:
	    bolts onto the target alone until Charged fills.
	  * Overcharge dashes DASH_SHARE of the gap (7 of the 14 studs; the live 11 would land in the target's face) in the
	    live dash time, the tell confirmed at TellDelay as the server's OverchargePrimed does, then the primed bolt; the
	    caster is set back where it stood DASH_BACK after it (React.Reset would at the next loop anyway).
	  * Volt Orb is lobbed onto the floor ORB_SHORT short of the target in ORB_FLIGHT s under the live Gravity (the live
	    48 studs/s carries it ~30 studs). It forms in the fist from the clip's start (VoltOrbFX.Windup, as on the caster's
	    own screen) and leaves on FireballR's punch: the VoltOrbThrow goes out ReleaseAt ahead of the clip's Trigger.
	  * Cascade is aimed at the target's feet; its five CascadeStrike payloads go out at the server's strike times
	    (VoltaicFX.Tuning.Cascade.Strikes), each on the target (the zone's least-struck body). The storm is left to run out
	    on its own clock (STORM_KEEP) past the next loop's start.
	Every Play is pcall-guarded and so is every FX call: a missing module warns once and that part is skipped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EL = "Voltaic"
local UP = Vector3.yAxis

-- the stage layout (studs; "along" = stage.CF.RightVector, caster -> target; "toward" = stage.CF.LookVector, the
-- camera's side)
local CHAIN = {                         -- the chain's further bodies, from the Target's root: along, up, toward
	Vector3.new(-1.5, 0.30, -5.5),
	Vector3.new(-6.5, 0.10, -7.5),
	Vector3.new(-11.0, 0.35, -4.5),
}
local LEAD = 0.35                       -- s before the first cast: the caster's body blends onto CastPose's Ready stance
local DASH_SHARE = 0.5                  -- Overcharge's dash: this share of the caster -> target gap (at most the live Distance)
local PRIMED_HOLD = 0.85                -- s the confirmed tell stands before the primed bolt spends it
local DASH_BACK = 0.6                   -- s after the primed bolt: the caster is set back where it stood
local RAIL_PAST = 4                     -- Railspike's line ends this far past the Target's root (in the air: its end knot)
local ORB_FLIGHT = 0.70                 -- Volt Orb: s from the release to the floor
local ORB_SHORT = 2.2                   -- ...landing this far short of the Target's root: a floor burst, the Target Nearest
local ZAP_AFTER = 0.06                  -- s from the filling bolt's hit to its discharge (the two pops a beat apart)
local STORM_KEEP = 5.4                  -- s a Cascade storm is left to run out (its clock ends ~5.1) before a flush ends it
-- the loops: shot seconds from one cast to the next (the move's own length and a beat of rest)
local PERIOD = { ChainBolt = 2.8, Overcharge = 3.0, Railspike = 2.8, VoltOrb = 3.8, Cascade = 4.5, ChainReaction = 3.2 }

-- the live numbers, for a place where VoltaicTuning / VFXLibrary / CastPose / VoltaicFX cannot be read
local FALLBACK = {
	ChainBolt = { Range = 55, HitRadius = 0.865, Damage = 10, ChainLegs = 1, PrimedLegs = 3, Charged = true },
	Overcharge = { Distance = 11, Time = 0.16, TellDelay = 0.23 },
	Railspike = { ChargeTime = 0.55, Damage = 30 },
	VoltOrb = { ReleaseAt = 0.12, Gravity = 72, Fuse = 1.25, HitRadius = 1.0, HandOffset = Vector3.new(0.9, -0.7, -1.4),
		StrikeDelay = 0.12, DamageRadius = 7.5, CenterDamage = 28, EdgeDamage = 14, DirectBonus = 8 },
	Cascade = { StrikeDamage = 14 },
}
local FIRE_INTERVAL = 0.32              -- VFXLibrary's ChainBolt row: the M1's rate
local TRIGGER = { IcicleShardR = 0.12, IcicleShardL = 0.12, FrostSlide = 0, RailspikeSurge = 0.55, FireballR = 0.42,
	CascadeSummon = 0.50 }             -- CastPose.Clips[clip].Trigger
local CASCADE_STRIKES = { 1.7333, 1.80, 1.8667, 1.9667, 2.0333 }   -- VoltaicFX.Tuning.Cascade.Strikes (Windup + StormStrikes)
local CASCADE_BELLY = 14                -- VoltaicFX.Tuning.Cascade.BellyHeight: where a strike comes from
-- Charged (StatusEffects.Presets, server-only) by the Spellshot.StatusPreset attribute: { MaxStacks, AloneDamage } -- the
-- 1v1 discharge's self-damage. MaxStacks is read live from Spellshot.StatusMax_Charged when the server has published it.
local CHARGED = { A = { 4, 7 }, B = { 3, 7 }, C = { 3, 6 } }
local BOLT_HIT = 2 / 60                 -- ChainBoltFX: leg 1 one frame after the fire (Leg1), the impact one after that

----------------------------------------------------------------------------------------------------
-- plumbing: lazy modules (nothing waits at require time), guarded calls, one warning a key
----------------------------------------------------------------------------------------------------
local mods, missedAt, warned = {}, {}, {}

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Voltaic] " .. msg)
end

--- IceMagic.<name>, required on first use; a miss is looked for again every 5 s.
local function need(name)
	local m = mods[name]
	if m then return m end
	if missedAt[name] and os.clock() - missedAt[name] < 5 then return nil end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local inst = ice and ice:FindFirstChild(name)
	local ok, res = false, "not in ReplicatedStorage.IceMagic"
	if inst and inst:IsA("ModuleScript") then ok, res = pcall(require, inst) end
	if ok and type(res) == "table" then
		mods[name] = res
		return res
	end
	missedAt[name] = os.clock()
	warnOnce("need:" .. name, name .. " unavailable (" .. tostring(res) .. "): that part of the preview is skipped")
	return nil
end

--- name.fn(...) guarded: a missing function or an error in it warns once and gives nil.
local function fx(name, fn, ...)
	local m = need(name)
	local f = m and m[fn]
	if type(f) ~= "function" then
		if m then warnOnce("fn:" .. name .. "." .. fn, name .. "." .. fn .. " does not exist") end
		return nil
	end
	local ok, res = pcall(f, ...)
	if not ok then
		warnOnce("err:" .. name .. "." .. fn, name .. "." .. fn .. " errored: " .. tostring(res))
		return nil
	end
	return res
end

--- VoltaicTuning[section][key], else the live value it had when this was written (FALLBACK).
local function tun(section, key)
	local T = need("VoltaicTuning")
	local s = T and T[section]
	local v = type(s) == "table" and s[key] or nil
	if v == nil and FALLBACK[section] then v = FALLBACK[section][key] end
	return v
end

local function num(section, key, default)
	return tonumber(tun(section, key)) or default
end

--- VFXLibrary.ShotTimeScale through the kit (a slowed review slows the loops with the effects), or 1.
local function timeScale()
	local K = need("VoltaicKit")
	local ok, s = pcall(function() return K.timeScale() end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

local function now() return workspace:GetServerTimeNow() end

local function fxFolder()
	local K = need("VoltaicKit")
	local ok, f = pcall(function() return K.fxFolder() end)
	return (ok and typeof(f) == "Instance") and f or nil
end

--- The M1's fire interval (VFXLibrary's ChainBolt row).
local function fireInterval()
	local V = need("VFXLibrary")
	local row = V and type(V.AbilityById) == "table" and V.AbilityById.ChainBolt
	return (type(row) == "table" and tonumber(row.FireInterval)) or FIRE_INTERVAL
end

--- Charged's MaxStacks and the 1v1 discharge's AloneDamage, as the server's live preset has them.
local function chargedNumbers()
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local row = CHARGED[spell and spell:GetAttribute("StatusPreset") or "A"] or CHARGED.A
	local max = tonumber(spell and spell:GetAttribute("StatusMax_Charged")) or row[1]
	return math.clamp(math.floor(max), 1, 8), row[2]
end

-- the display names are SpellshotConfig's (the literal only stands in where it cannot be read)
local Config = nil
do
	local spell = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = spell and spell:FindFirstChild("SpellshotConfig")
	if m and m:IsA("ModuleScript") then
		local ok, c = pcall(require, m)
		if ok and type(c) == "table" then Config = c end
	end
end

local function nameOf(slot, key, fallback)
	local ok, n = pcall(function()
		if slot == "M1" or slot == "Primary" or slot == "Passive" then return Config.Elements[EL][slot].Name end
		return Config[slot][key].Name                      -- Config.Mobility / Defense / Ultimate
	end)
	return (ok and type(n) == "string" and n ~= "") and n or fallback
end

----------------------------------------------------------------------------------------------------
-- the body: CastPose, the one instance at ReplicatedStorage.IceMagic.CastPose (a second copy would run its own state)
----------------------------------------------------------------------------------------------------
--- The caster's body clip, as VoltaicClient.Handlers plays it on an onlooker's screen (CastPose.Play).
local function pose(model, clip)
	if typeof(model) ~= "Instance" then return end
	fx("CastPose", "Play", model, clip)
end

--- A clip's release beat in shot seconds (CastPose.Clips[clip].Trigger).
local function triggerOf(clip)
	local CP = need("CastPose")
	local c = CP and type(CP.Clips) == "table" and CP.Clips[clip]
	return (type(c) == "table" and tonumber(c.Trigger)) or TRIGGER[clip] or 0
end

--- The body on its rest stance: a held clip let go, no base, no aim. (On a body CastPose has not met yet SetBase
--- registers it: it blends onto the Ready stance.)
local function rest(model)
	if typeof(model) ~= "Instance" then return end
	local CP = need("CastPose")
	if not CP then return end
	if type(CP.Stop) == "function" then pcall(CP.Stop, model) end
	if type(CP.SetBase) == "function" then pcall(CP.SetBase, model, nil) end
	if type(CP.SetAim) == "function" then pcall(CP.SetAim, model, nil) end
end

----------------------------------------------------------------------------------------------------
-- the stage
----------------------------------------------------------------------------------------------------
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function casterOf(S) return S.Caster or S.Key end

--- The stage's centre and its two level axes: along (caster -> target) and toward (the camera's side).
local function axes(S)
	local cf = S.CF
	local along = flat(cf.RightVector)
	along = along.Magnitude > 1e-3 and along.Unit or Vector3.xAxis
	local toward = flat(cf.LookVector)
	toward = toward.Magnitude > 1e-3 and toward.Unit or UP:Cross(along)
	return cf.Position, along, toward
end

local function bodyPart(model, name)
	local p = typeof(model) == "Instance" and model:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end

--- A rig's root position (its pivot without one), or nil.
local function rootOf(model)
	local r = bodyPart(model, "HumanoidRootPart")
	if r then return r.Position end
	if typeof(model) == "Instance" and model:IsA("Model") then
		local ok, cf = pcall(model.GetPivot, model)
		if ok then return cf.Position end
	end
	return nil
end

--- Where a shot at a body is aimed: its chest (UpperTorso; the root without one).
local function chestOf(model)
	local p = bodyPart(model, "UpperTorso") or bodyPart(model, "Torso")
	if p then return p.Position end
	return rootOf(model)
end

--- The eye a Voltaic shot leaves from (VoltaicClient's aim origin): the caster's head.
local function eyeOf(S)
	local caster = casterOf(S)
	local head = bodyPart(caster, "Head")
	if head then return head.Position end
	local C, along = axes(S)
	return (rootOf(caster) or (C - along * 7)) + UP * 1.5
end

--- One of the caster's hands as VoltaicClient.Handlers.ChainReaction finds it (the kit's muzzle, else the hand part).
local function handPos(model, side)
	if typeof(model) ~= "Instance" then return nil end
	local K = need("VoltaicKit")
	local ok, p = pcall(function() return K.muzzle(model, side) end)
	if ok and typeof(p) == "Vector3" then return p end
	local hand = bodyPart(model, side == "R" and "RightHand" or "LeftHand")
	return hand and hand.Position or nil
end

--- What a preview shot passes through: the caster, the camera and the FX (VoltaicClient's ownExclude, less the team).
local function shotParams(S)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {}
	local caster = casterOf(S)
	if typeof(caster) == "Instance" then ex[#ex + 1] = caster end
	if workspace.CurrentCamera then ex[#ex + 1] = workspace.CurrentCamera end
	local folder = fxFolder()
	if folder then ex[#ex + 1] = folder end
	params.FilterDescendantsInstances = ex
	return params
end

--- Chain Bolt's claimed hit: the eye's sphere (HitRadius) down the aim at the Target's chest, as VoltaicClient.FireM1
--- casts it -- its first touch on the Target, else the chest itself. nil without a Target.
local function claimOn(S, eye)
	local target = S.Target
	local chest = chestOf(target)
	if not chest then return nil end
	local d = chest - eye
	if d.Magnitude < 1e-3 then return chest end
	local reach = math.min(num("ChainBolt", "Range", 55), d.Magnitude + 4)
	local ok, hit = pcall(workspace.Spherecast, workspace, eye, num("ChainBolt", "HitRadius", 0.865), d.Unit * reach,
		shotParams(S))
	if ok and hit and hit.Instance:IsDescendantOf(target) then return hit.Position end
	return chest
end

--- Where a ray from `origin` along `dir` first touches `model` (Railspike's entry point), or nil when it passes by.
local function entryOn(model, origin, dir, dist)
	if typeof(model) ~= "Instance" then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local ok, hit = pcall(workspace.Raycast, workspace, origin, dir * dist, params)
	if ok and hit then return hit.Position end
	local r = rootOf(model)
	if not r then return nil end
	local along = (r - origin):Dot(dir) - 0.5               -- (its near side, as RailspikeFX probes a body with no point)
	if along > 0.5 and along < dist - 1 and (origin + dir * (along + 0.5) - r).Magnitude < 2 then
		return origin + dir * along
	end
	return nil
end

--- Points[1] = the claimed hit, then `legs` of CHAIN (the further bodies the bolt chains to) at the height of the body
--- the chain leaves.
local function chainPoints(S, A, legs)
	local points = { A }
	local tr = rootOf(S.Target)
	if not tr then return points end
	local _, along, toward = axes(S)
	for i = 1, math.clamp(legs or 0, 0, #CHAIN) do
		local o = CHAIN[i]
		local p = tr + along * o.X + toward * o.Z
		points[#points + 1] = Vector3.new(p.X, tr.Y + o.Y, p.Z)
	end
	return points
end

-- the reactions: stage.React (AltarStage); required here only if a stage comes without it
local stageLib = nil
local function reactOf(S)
	if type(S) == "table" and type(S.React) == "table" then return S.React end
	if stageLib == nil then
		stageLib = false
		local spell = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = spell and spell:FindFirstChild("AltarStage")
		if m and m:IsA("ModuleScript") then
			local ok, r = pcall(require, m)
			if ok and type(r) == "table" then stageLib = r end
		end
		if not stageLib then warnOnce("react", "stage.React is missing and AltarStage cannot be read: the target will not react") end
	end
	return stageLib or nil
end

--- React[fn](stage, ...) guarded.
local function callReact(S, fn, ...)
	local R = reactOf(S)
	local f = R and R[fn]
	if type(f) ~= "function" then return end
	local ok, err = pcall(f, S, ...)
	if not ok then warnOnce("react:" .. fn, "React." .. fn .. " errored: " .. tostring(err)) end
end

----------------------------------------------------------------------------------------------------
-- one preview: its handles, its loop, its stop
----------------------------------------------------------------------------------------------------
local function endHandle(h)
	if type(h) ~= "table" then return end
	local f = h.Destroy or h.Stop
	if type(f) == "function" then pcall(f, h) end
end

local function newPreview(S)
	local P = { Alive = true, OnStop = nil, Thread = nil, Stacks = 0, Home = nil }
	local held = {}                                       -- [handle] = os.clock() from which a flush may end it
	local sparks = setmetatable({}, { __mode = "k" })     -- VoltSparkBurst hosts started on this stage
	local conns = {}
	local C = S.CF.Position                               -- (read first: a stage without it fails before anything starts)
	local caster = casterOf(S)
	if typeof(caster) == "Instance" and caster:GetAttribute("AllyDummy") == nil then
		caster:SetAttribute("AllyDummy", true)              -- (the contract's: Reduce Enemy VFX must not thin the move shown)
	end
	-- VFXLibrary.VoltSparkBurst's hosts sit loose in the FX folder (Debris ends them at 0.8 s, nothing hands them back):
	-- the ones that start on this stage are swept up at stop()
	local folder = fxFolder()
	if folder then
		conns[#conns + 1] = folder.ChildAdded:Connect(function(c)
			if c.Name == "VoltSparkBurst" and c:IsA("BasePart") and (c.Position - C).Magnitude < 30 then sparks[c] = true end
		end)
	end

	--- Keeps an FX handle to end at stop(), or at the first cycle start `keep` real seconds on (default: the next one).
	--- One made after stop() ends at once.
	function P.Hold(h, keep)
		if type(h) ~= "table" then return h end
		if not P.Alive then
			endHandle(h)
			return h
		end
		held[h] = os.clock() + (keep or 0) / timeScale()
		return h
	end

	--- The last cycles' handles that have had their time, ended (a finished one ignores it).
	function P.Flush()
		local t = os.clock()
		for h, from in pairs(held) do
			if t >= from then
				held[h] = nil
				endHandle(h)
			end
		end
	end

	--- Waits `s` SHOT seconds (one frame for nil); false once stop() has been called.
	function P.Wait(s)
		if not P.Alive then return false end
		if s and s > 0 then task.wait(s / timeScale()) else RunService.Heartbeat:Wait() end
		return P.Alive
	end

	--- Waits until `s` SHOT seconds after the os.clock() `c0` (at once if that is past); false once stopped.
	function P.Until(c0, s)
		if not P.Alive then return false end
		local left = s / timeScale() - (os.clock() - c0)
		if left > 1e-3 then task.wait(left) end
		return P.Alive
	end

	--- The caster `offset` studs from where this cycle found it.
	function P.Move(offset)
		if not (P.Alive and P.Home) or typeof(caster) ~= "Instance" then return end
		pcall(caster.PivotTo, caster, P.Home + offset)
	end

	--- React.Hit on the Target while the preview runs.
	function P.Hit(opts)
		if P.Alive then callReact(S, "Hit", opts) end
	end

	function P.Stop()
		if not P.Alive then return end
		P.Alive = false
		local th = P.Thread
		if th and th ~= coroutine.running() then pcall(task.cancel, th) end
		if P.OnStop then pcall(P.OnStop) end
		for h in pairs(held) do endHandle(h) end
		table.clear(held)
		for c in pairs(sparks) do pcall(c.Destroy, c) end
		for _, c in ipairs(conns) do c:Disconnect() end
		table.clear(conns)
		rest(caster)
		callReact(S, "Reset")
	end

	return P
end

--- Plays `cycle(P, S, c0)` -- one cast of the move and its hit -- after LEAD and then every PERIOD[label] shot seconds
--- until the returned stop(): before each, the stage reset and the caster on its stance. A cycle that errors warns
--- once and the loop carries on.
local function run(S, label, cycle, onStop)
	local P = newPreview(S)
	if onStop then P.OnStop = function() onStop(P, S) end end
	if S.Wrap ~= nil and S.Wrap ~= "Default" then
		warnOnce("wrap:" .. tostring(S.Wrap), "Voltaic has no wraps (no ElementWraps.Voltaic): '" .. tostring(S.Wrap)
			.. "' is drawn as Default")
	end
	local caster = casterOf(S)
	rest(caster)                                          -- (registers the body: on the Ready stance by the first cast)
	P.Thread = task.spawn(function()
		if not P.Wait(LEAD) then return end
		while P.Alive do
			local c0 = os.clock()
			P.Flush()
			P.Stacks = 0
			callReact(S, "Reset")
			rest(caster)
			local ok, cf = pcall(function() return caster:GetPivot() end)
			P.Home = ok and cf or nil
			local fine, err = pcall(cycle, P, S, c0)
			if not fine then warnOnce("cycle:" .. label, label .. " preview failed: " .. tostring(err)) end
			if not P.Until(c0, PERIOD[label] or 3.5) then break end
		end
	end)
	return P.Stop
end

----------------------------------------------------------------------------------------------------
-- the hits
----------------------------------------------------------------------------------------------------
--- ChainReaction { Character, Ready } as VoltaicClient.Handlers.ChainReaction draws it: VoltSparkBurst off both hands,
--- 10 sparks (Ready: the cut left Overcharge ready, as it is for a caster who has not spent it).
local function chainReaction(P, S)
	local V = need("VFXLibrary")
	if not (P.Alive and V and type(V.VoltSparkBurst) == "function") then return end
	local caster = casterOf(S)
	local thin = false
	if type(V.IsEnemy) == "function" then
		local ok, e = pcall(V.IsEnemy, caster)
		thin = ok and e == true
	end
	for _, side in ipairs({ "R", "L" }) do
		local pos = handPos(caster, side)
		if pos then pcall(V.VoltSparkBurst, pos, UP, thin, 10) end
	end
end

--- A Chain Bolt landing on the Target (VoltaicHandler: Damage, then StatusEffects.Apply "Charged"): the number and
--- CHARGE xN -- or, on the last stack, the 1v1 discharge (nobody else in ChainRange: StatusDischarge { From } alone,
--- ChainBoltFX.Discharge's self-zap, ZAP! and AloneDamage) and Chain Reaction on the caster (Status.OnChargedFull).
local function boltHit(P, S, from)
	if not P.Alive then return end
	local damage = num("ChainBolt", "Damage", 10)
	if tun("ChainBolt", "Charged") == false then
		P.Hit({ Damage = damage, From = from })
		return
	end
	local max, alone = chargedNumbers()
	P.Stacks += 1
	if P.Stacks < max then
		P.Hit({ Damage = damage, From = from, Word = "CHARGE x" .. P.Stacks, Style = "charged" })
		return
	end
	P.Stacks = 0
	P.Hit({ Damage = damage, From = from })
	if not P.Wait(ZAP_AFTER) then return end
	P.Hold(fx("ChainBoltFX", "Discharge", S.Target, nil))
	P.Hit({ Damage = alone, NoRecoil = true, Word = "ZAP!", Style = "charged" })
	chainReaction(P, S)
end

--- One Chain Bolt as an onlooker sees it (VoltaicClient.Handlers.ChainBolt): the palm thrust (IcicleShardR / L) and, at
--- its release beat, the broadcast's draw -- Origin the eye, Points the claimed hit on the Target then `legs` of CHAIN,
--- Hits the Target. ChainBoltFX takes the caster's `side` hand for leg 1 (the thrust has it out in front) and tracks it.
--- A primed bolt spends the tell first: OverchargeFX.Release while it still stands, then SetPrimed false. The Target
--- takes it as the impact lands. False once stopped.
local function fireBolt(P, S, side, legs, primed)
	local caster = casterOf(S)
	local clip = "IcicleShard" .. side
	pose(caster, clip)
	if not P.Wait(triggerOf(clip)) then return false end
	local eye = eyeOf(S)
	local A = claimOn(S, eye)
	if not A then return true end                         -- (no Target: the arm thrusts at nothing)
	local _, along = axes(S)
	local points = chainPoints(S, A, legs)
	local d = points[1] - eye
	local data = {
		Character = caster, Origin = eye, Dir = d.Magnitude > 1e-3 and d.Unit or along, Side = side,
		End = points[1], Hits = { S.Target }, Points = points, Primed = primed == true, T0 = now(),
	}
	if primed then
		P.Hold(fx("OverchargeFX", "Release", caster, side, nil, points, { T0 = data.T0, End = data.End }))
		fx("OverchargeFX", "SetPrimed", caster, false)
	end
	P.Hold(fx("ChainBoltFX", "Fire", data, {}))
	if not P.Wait(BOLT_HIT) then return false end
	boltHit(P, S, eye)
	return P.Alive
end

----------------------------------------------------------------------------------------------------
-- the moves
----------------------------------------------------------------------------------------------------
--- CHAIN BOLT (M1): a volley as the clicks fire it -- right hand, left, right, FireInterval apart -- each hitscan onto
--- the Target's chest and on along ChainLegs of CHAIN; every bolt a hit and a Charged stack.
local function chainBoltCycle(P, S, c0)
	local legs = num("ChainBolt", "ChainLegs", 1)
	local every = fireInterval()
	for i = 1, 3 do
		if not P.Until(c0, (i - 1) * every) then return end
		if not fireBolt(P, S, i % 2 == 1 and "R" or "L", legs, false) then return end
	end
end

--- OVERCHARGE (Primary): the dash as an onlooker sees it -- FrostSlide on the body and OverchargeFX.Cast on the
--- broadcast's From / To on the clip's first beat (Trigger 0), the body carried along it in the live dash Time so the
--- tell climbs onto it where it lands -- the server's OverchargePrimed On at TellDelay (SetPrimed true), the tell held,
--- then spent by a primed Chain Bolt of PrimedLegs chain legs (the bolt is the only hit: the dash goes through bodies).
local function overchargeCycle(P, S, c0)
	local caster = casterOf(S)
	local r0, tr = rootOf(caster), rootOf(S.Target)
	if not (r0 and P.Home) then return end
	local _, along = axes(S)
	local gap = tr and flat(tr - r0):Dot(along) or 14
	local dist = math.clamp(gap * DASH_SHARE, 1, math.max(1, num("Overcharge", "Distance", 11)))
	pose(caster, "FrostSlide")
	if not P.Until(c0, triggerOf("FrostSlide")) then return end
	local t0 = os.clock()
	fx("OverchargeFX", "Cast", { Character = caster, From = r0, To = r0 + along * dist, T0 = now() })
	local dashT = num("Overcharge", "Time", 0.16)
	repeat
		local u = math.clamp((os.clock() - t0) * timeScale() / dashT, 0, 1)
		P.Move(along * (dist * u))
	until u >= 1 or not P.Wait()
	if not P.Until(t0, num("Overcharge", "TellDelay", 0.23)) then return end
	fx("OverchargeFX", "SetPrimed", caster, true)
	if not P.Wait(PRIMED_HOLD) then return end
	if not fireBolt(P, S, "R", num("ChainBolt", "PrimedLegs", 3), true) then return end
	if not P.Wait(DASH_BACK) then return end              -- (the bolt's leg rides the hand: the caster stays put for it)
	P.Move(Vector3.zero)                                  -- back where it stood, settled before the next dash
end

--- RAILSPIKE (Technique): RailspikeChargeStart as an onlooker gets it (RailspikeSurge held on the body,
--- RailspikeFX.Charge off both hands), then at the surge's release beat (Trigger = ChargeTime) the RailspikeShot: the
--- windup handed over (stopped, as the Handler stops it), RailspikeThrow, and the line from the eye through the Target's
--- chest to RAIL_PAST beyond it (in the air: its end knot, no wall), the Target pierced from its near side.
local function railspikeCycle(P, S, c0)
	local caster = casterOf(S)
	pose(caster, "RailspikeSurge")
	local charge = P.Hold(fx("RailspikeFX", "Charge", caster, { T0 = now() }))
	if not P.Until(c0, triggerOf("RailspikeSurge")) then return end
	if type(charge) == "table" then
		local f = charge.Stop or charge.Destroy
		if type(f) == "function" then pcall(f, charge) end
	end
	pose(caster, "RailspikeThrow")
	local eye = eyeOf(S)
	local _, along = axes(S)
	local tr, chest = rootOf(S.Target), chestOf(S.Target)
	local aim = chest or (eye + along * 14)
	local dir = (aim - eye).Magnitude > 1e-3 and (aim - eye).Unit or along
	local dist = math.max(1, ((tr or aim) - eye):Dot(dir) + RAIL_PAST)
	local hits, points = {}, {}
	local entry = entryOn(S.Target, eye, dir, dist)
	if entry then hits[1], points[1] = S.Target, entry end
	P.Hold(fx("RailspikeFX", "Fire", {
		Character = caster, Origin = eye, Dir = dir, Dist = dist, Hits = hits, Points = points, T0 = now(),
	}, {}))
	if entry then
		if not P.Wait() then return end                   -- (drawn on the fire frame; the damage is the claim's, at once)
		P.Hit({ Damage = num("Railspike", "Damage", 30), From = eye })
	end
	P.Wait(1.0)
end

--- VOLT ORB (Technique): FireballR on the body with the orb forming in its fist (VoltOrbFX.Windup), the VoltOrbThrow
--- ReleaseAt ahead of the punch so the orb leaves the hand at the clip's Trigger (From = the head + HandOffset, the
--- server's), the stage lob onto the floor short of the Target, then its VoltOrbBurst where the flight stops -- stepped
--- the way the orb sweeps its own (a HitRadius spherecast through all but the FX, the caster and the camera) -- with
--- the Target as its Nearest (Direct if the orb touched it). StrikeDelay later the Target takes VoltaicHandler's
--- orbDamage: CenterDamage falling to EdgeDamage by flat distance, plus DirectBonus on a direct hit.
local function voltOrbCycle(P, S, c0)
	local caster = casterOf(S)
	local head = bodyPart(caster, "Head") or bodyPart(caster, "HumanoidRootPart")
	if not head then return end
	local _, along = axes(S)
	local g, fuse, rad = num("VoltOrb", "Gravity", 72), num("VoltOrb", "Fuse", 1.25), num("VoltOrb", "HitRadius", 1)
	local releaseIn = num("VoltOrb", "ReleaseAt", 0.12)
	pose(caster, "FireballR")
	P.Hold(fx("VoltOrbFX", "Windup", caster, { T0 = now() }))
	if not P.Until(c0, math.max(0, triggerOf("FireballR") - releaseIn)) then return end
	local hand = tun("VoltOrb", "HandOffset")
	hand = typeof(hand) == "Vector3" and hand or FALLBACK.VoltOrb.HandOffset
	local from = head.Position + CFrame.lookAt(Vector3.zero, along):VectorToWorldSpace(hand)
	-- the stage lob: to the floor ORB_SHORT short of the Target in ORB_FLIGHT s, under the live Gravity
	local tr = rootOf(S.Target)
	local land = tr and (Vector3.new(tr.X, S.Floor.Y, tr.Z) - along * ORB_SHORT) or (S.Floor + along * 4.8)
	local tf = ORB_FLIGHT
	local dy = (land.Y + rad) - from.Y
	local vel = flat(land - from) / tf + UP * ((dy + 0.5 * g * tf * tf) / tf)
	local t0 = now()
	P.Hold(fx("VoltOrbFX", "Throw", {
		Character = caster, From = from, Vel = vel, T0 = t0, ReleaseAt = t0 + releaseIn / timeScale(),
		Gravity = g, Fuse = fuse, Seed = math.random(1, 1073741823),
	}))
	local c1 = os.clock()
	-- where it stops (the flight in shot time, 60 Hz, as VoltaicHandler steps it)
	local params = shotParams(S)
	local last, at, normal, air, tHit, inst = from, nil, UP, true, fuse, nil
	local t = 0
	while t < fuse do
		t = math.min(fuse, t + 1 / 60)
		local pos = from + vel * t - UP * (0.5 * g * t * t)
		local ok, hit = false, nil
		if (pos - last).Magnitude > 1e-3 then ok, hit = pcall(workspace.Spherecast, workspace, last, rad, pos - last, params) end
		if ok and hit then
			at, normal, air, tHit, inst = hit.Position + hit.Normal * 0.5, hit.Normal, false, t, hit.Instance
			break
		end
		last = pos
	end
	at = at or (from + vel * fuse - UP * (0.5 * g * fuse * fuse))
	local target = S.Target
	local direct = (inst and typeof(target) == "Instance" and inst:IsDescendantOf(target)) and target or nil
	local radius = num("VoltOrb", "DamageRadius", 7.5)
	local nearest = (tr and (tr - at).Magnitude < radius) and target or nil
	if not P.Until(c1, releaseIn + tHit) then return end
	P.Hold(fx("VoltOrbFX", "Burst", {
		Character = caster, At = at, Normal = normal, Direct = direct, Nearest = nearest, Air = air, T0 = now(),
	}))
	if not P.Wait(num("VoltOrb", "StrikeDelay", 0.12)) then return end
	if tr and (direct or nearest) then
		local d = math.min(flat(tr - at).Magnitude, radius)
		local center, edge = num("VoltOrb", "CenterDamage", 28), num("VoltOrb", "EdgeDamage", 14)
		P.Hit({
			Damage = center - (center - edge) * (d / radius) + (direct and num("VoltOrb", "DirectBonus", 8) or 0),
			From = at,
		})
	end
	P.Wait(2.3)                                           -- VoltOrbFX.Tuning.End: the afterglow is out by +2.2
end

--- CASCADE (Ultimate): CascadeSummon on the body and CascadeGather at the Target's feet on the same beat (the storm's
--- own clock from T0 holds the charge in the hands to the clip's Trigger = its Windup), then the five CascadeStrikes at
--- the server's strike times -- the zone's least-struck body, so the Target every time, at the ground below its root --
--- each taken as StrikeDamage from the storm's belly, and the CascadeEnd after the fifth. The storm runs out on its
--- own (~5.1 s), past the next loop's start.
local function cascadeCycle(P, S, c0)
	local caster = casterOf(S)
	local VFX = need("VoltaicFX")
	local CT = VFX and type(VFX.Tuning) == "table" and type(VFX.Tuning.Cascade) == "table" and VFX.Tuning.Cascade or {}
	local strikes = (type(CT.Strikes) == "table" and #CT.Strikes > 0) and CT.Strikes or CASCADE_STRIKES
	local belly = tonumber(CT.BellyHeight) or CASCADE_BELLY
	local tr = rootOf(S.Target)
	local point = tr and Vector3.new(tr.X, S.Floor.Y, tr.Z) or S.Floor
	pose(caster, "CascadeSummon")
	local t0 = now()
	P.Hold(fx("VoltaicFX", "CascadeGather", { Character = caster, Point = point, T0 = t0 }), STORM_KEEP)
	local damage = num("Cascade", "StrikeDamage", 14)
	for n = 1, #strikes do
		if not P.Until(c0, strikes[n]) then return end
		fx("VoltaicFX", "CascadeStrike", { Character = caster, Point = point, N = n, At = point, T0 = t0 })
		if tr then P.Hit({ Damage = damage, From = point + UP * belly }) end
	end
	fx("VoltaicFX", "CascadeEnd", { Character = caster, T0 = t0 })
	P.Wait(0.3)
end

--- CHAIN REACTION (Passive): Charged filled on the Target the way a 1v1 duel fills it -- Chain Bolts onto it alone,
--- FireInterval apart, until its stacks are full (StatusMax_Charged) -- and what fires on that hit: the Target's
--- discharge (StatusDischarge alone: the self-zap, ZAP!, AloneDamage) and ChainReaction on the caster (sparks off both
--- hands: MaxStackCut came off Overcharge's cooldown).
local function chainReactionCycle(P, S, c0)
	local full = chargedNumbers()
	local every = fireInterval()
	for i = 1, full do
		if not P.Until(c0, (i - 1) * every) then return end
		if not fireBolt(P, S, i % 2 == 1 and "R" or "L", 0, false) then return end
	end
	P.Wait(0.8)
end

----------------------------------------------------------------------------------------------------
-- the kit
----------------------------------------------------------------------------------------------------
local function entry(key, slot, fallback, cycle, onStop)
	return {
		Key = key, Name = nameOf(slot, key, fallback), Slot = slot,
		Play = function(stage)
			local ok, stop = pcall(run, stage, key, cycle, onStop)
			if ok and type(stop) == "function" then return stop end
			warnOnce("play:" .. key, key .. " preview did not start: " .. tostring(stop))
			return function() end
		end,
	}
end

return {
	Element = EL,
	Moves = {
		entry("ChainBolt", "M1", "Chain Bolt", chainBoltCycle),
		entry("Overcharge", "Primary", "Overcharge", overchargeCycle, function(_, S)
			fx("OverchargeFX", "SetPrimed", casterOf(S), false)   -- a tell still up (or still owed) goes with the preview
		end),
		entry("Railspike", "Mobility", "Railspike", railspikeCycle, function(_, S)
			fx("RailspikeFX", "ChargeStop", casterOf(S))          -- a windup still up goes too
		end),
		entry("VoltOrb", "Defense", "Volt Orb", voltOrbCycle),
		entry("Cascade", "Ultimate", "Cascade", cascadeCycle),
		entry("ChainReaction", "Passive", "Chain Reaction", chainReactionCycle),
	},
}
