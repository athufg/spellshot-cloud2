--[[
	UmbraHandler  (Script)  ->  ServerScriptService/UmbraHandler

	The gameplay side of UMBRA, reworked (manual v0.16 kit lock, v0.17 direction; build prompt Opus55_Umbra_Rework_Build.md,
	Phase 2, 2026-09-27). UmbraClient is its client half. Every number is UmbraTuning's (ReplicatedStorage.IceMagic, pure
	data, the same table the clients read), and every one is a STAND-IN. Before this, Umbra existed only as config text:
	Mark for Death, Nightfall and Fade Step never had a cast path (retired: ServerStorage.UmbraKitSuperseded).

	THE DESIGN LAW (the owner): Shadow Dart is the real damage. Shadow Step, Eclipse and Decoy Double deal none; Mark's
	payoff rides on the marker's own hit.

	  M1        SHADOW DART     a CHARGED dart (Phase 4: the owner's 2.3 s from click to release). The click's CastRequest
	                            (SpellshotService: the rate and the mana) starts the charge here -- told to everyone
	                            (ShadowDartCharge) and remembered, so the release must end a charge this server saw start and
	                            come no sooner than it could have been gathered (Windup / M1RateMult, less ChargeSlack).
	                            Then Icicle Shard's two messages:
	                            ShadowDartRelease (the eye and the aim: the fire-rate bucket, the eye against the server's
	                            head) then ShadowDartHit (the part and the point: on the line, no sooner than the dart could
	                            fly there, CheckTarget and Blocked with Wind Blade's second chances). The M1's CastRequest
	                            (rate, mana) is SpellshotService's; this ignores it.
	  PASSIVE   UNSEEN          a Shadow Dart on an UNAWARE target does Unseen.Bonus more: Umbra is more than UnawareAngle
	                            off the way the target faces (flat), or Eclipse is up. PassiveProc (server time) marks it.
	  PRIMARY   SHADOW STEP     no dash: the server picks the spot (toward the crosshair, at most Distance, short of walls,
	                            onto a floor, with headroom), the body dissolves, and DissolveTime later it is moved there.
	                            VEILED (VeiledUntil, server time) from the dissolve to VeilTime after: CombatCore.IsVeiled
	                            keeps new target locks (Earthen Tomb, Mirror Cage) off the body, and a fissure already homing
	                            on it loses it. Nowhere to go (too short, no floor): the cast is given back.
	                            (2026-10-18, umbra; handoff #8) THE DIVE REWARD: the cooldown is DiveCooldown, not
	                            Cooldown, when the step comes within DiveWindow after a hit of Umbra's landed on an enemy,
	                            or a hit lands within DiveWindow after the step (the running cooldown is cut to end at the
	                            cast + DiveCooldown, once per cast). THE ESCAPE BLINK: a second charge on the same key,
	                            picked by SpellshotService (payload.Escape) -- the same step on its own cooldown, no reward.
	                            A press while a step is still dissolving is given back whole (no double spend on a tap).
	  TECHNIQUE MARK            the enemy nearest the aim line (Earthen Tomb's lock rule). Stacks ripen one per StackEvery
	                            to MaxStacks; full and left alone for ExpireAfterFull, it goes. The MARKER's next real hit on
	                            it spends it (a CombatCore modifier, before any shield): HeadBonus[stacks] on a headshot,
	                            BodyBonus[stacks] otherwise. Self-only -- a teammate's hit neither spends nor gains it.
	                            Kit-owned status "Marked" (Chill's arrangement): this script writes RX_Marked and its
	                            suffixes, so the victim's BarFX look and the HUD read it as before. HUNTED! pops over them.
	                            Precheck: a press with nobody to mark costs nothing.
	  TECHNIQUE DECOY DOUBLE    a stationary copy of the caster peels off to the side (DecoyOwner = the caster's UserId;
	                            friendly to them as a Bulwark Wall is). It breaks on the first damage it takes -- the Tell --
	                            or at Duration. Deals nothing.
	  ULTIMATE  ECLIPSE         the charge is spent on the cast (SpellshotService). First the WINDUP (Phase 4, WindupTime):
	                            the caster is held in place (SpeedCapUlt 0) pressing the mass -- the Ultimate's telegraph,
	                            EclipseCharge to everyone; dying or being cleared in it cancels it (EclipseCancel). Then,
	                            for Duration: every enemy counts as
	                            unaware, Shadow Dart fires FireRateMult faster (M1RateMult on the character, read by
	                            SpellshotService's M1 gate, this bucket and the client's own rate), and EclipseStart tells
	                            every client: the world darkens for everyone in the duel, the reveal outline is the caster's.

	HEAD vs BODY: isHeadshot below is the ONLY place in the game that tells where a shot landed, and it is asked only when a
	Shadow Dart hits a body carrying its shooter's own Mark (the owner: scoped to Mark, not a general system). Any other hit
	on a marked body is a body hit, so another Element holding Mark only ever gets the body bonus.

	THE TELL: UmbraExposedAt (server time) on the caster's character whenever concealment breaks -- a dart released, a dart
	landing, the decoy failing. The clients light the Tell from it (Phase 3 draws the real one).

	Server -> client (AbilityFX -> UmbraClient.Handlers): ("VFX", kind, data) on IceAbilityRemote, to everyone:
	  ShadowDartCharge, ShadowDart, ShadowDartHit, ShadowStepOut / ShadowStepIn, MarkApplied / MarkStack / MarkEnd,
	  DecoySpawn / DecoyBreak, EclipseCharge / EclipseCancel / EclipseStart / EclipseEnd.
	Client -> server (IceAbilityRemote): ShadowDartRelease, ShadowDartHit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local T = require(iceFolder:WaitForChild("UmbraTuning"))         -- pure data; the clients read the same table
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local giveBack = spellFolder:WaitForChild("GiveBack")            -- (player, role, true): the cast back, and its Ultimate charge
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Core = require(script.Parent:WaitForChild("CombatCore"))

local remote = Core.Remote
local broadcast = Core.Broadcast
local ABILITY = VFXLibrary.AbilityById

----------------------------------------------------------------------------------------------------
-- helpers (Voltaic's, the same rules)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[UmbraHandler] " .. tostring(msg))
end

-- HUNTED! goes through the same module FROZEN! and ARCSTORM! do. Guarded: a word is not worth the kit.
local Callouts = nil
do
	local ok, mod = pcall(function()
		return require(spellFolder:WaitForChild("Callouts", 10))
	end)
	if ok and type(mod) == "table" then
		Callouts = mod
	else
		warnOnce("callouts", "Callouts unavailable, Mark will not pop HUNTED!: " .. tostring(mod))
	end
end

local function holds(player, role, id)
	local a = VFXLibrary.AbilityFor(player, role)
	return a ~= nil and a.Id == id
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function timeScale()
	return VFXLibrary.ShotTimeScale()
end

local function pingOf(player)
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	return ping
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

local function eyeOf(character, root)
	local head = character:FindFirstChild("Head")
	return head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
end

local function eyeNear(player, character, humanoid, root, origin)
	local speed = math.max(root.AssemblyLinearVelocity.Magnitude, humanoid.WalkSpeed)
	local allowance = T.ShadowDart.OriginSlack + speed * (0.35 + pingOf(player))
	return (origin - eyeOf(character, root)).Magnitude <= allowance
end

local function worldParams(extra, respectCollide)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = respectCollide == true
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	if extra then
		for _, inst in ipairs(extra) do exclude[#exclude + 1] = inst end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

--- A ray that sees through every body (a character, a dummy, a decoy) but not a Bulwark Wall, which is cover.
local function castThroughBodies(origin, direction, params)
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) or model:GetAttribute("WallOwner") then return hit end
		params:AddToFilter(model)
	end
	return nil
end

local function onPart(part, position, pad)
	local lp = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2 + Vector3.new(pad, pad, pad)
	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

local function validClaimPart(part, position)
	return typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(workspace)
		and Core.ValidVector(position)
end

--- Core.CheckTarget with Wind Blade's SECOND CHANCE (a contact on a limb or the head can sit outside the root's reach).
local function checkClaim(part, position, shooterCharacter)
	local reason, model, humanoid = Core.CheckTarget(part, position, shooterCharacter)
	if reason == "rej_moved" and onPart(part, position, 1) then
		reason = nil
		model = part:FindFirstAncestorOfClass("Model")
		humanoid = model and model:FindFirstChildOfClass("Humanoid")
		Core.CountShot("save_moved")
	end
	return reason, model, humanoid
end

--- Core.Blocked with Wind Blade's SECOND CHANCE: also tried from where the server has the shooter's head.
local function claimBlocked(shot, along, position, skip)
	if not Core.Blocked(shot, along, skip) then return false end
	local head = shot.Character:FindFirstChild("Head")
	if head then
		local rel = position - head.Position
		local d = rel.Magnitude
		if d > 0.5 and not Core.Blocked({ Origin = head.Position, Dir = rel / d, Character = shot.Character }, d, skip) then
			Core.CountShot("save_blocked")
			return false
		end
	end
	return true
end

local function exposed(character)
	if character and character.Parent then character:SetAttribute("UmbraExposedAt", serverNow()) end
end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local buckets = {}      -- [player] = { Tokens, At }: Shadow Dart's fire-rate check
local shots = {}        -- [player] = { [id] = { Origin, Dir, At, Life, Character, Scale } }, awaiting their hit
local eclipses = {}     -- [player] = { Character, Until, Epoch }
local marks = {}        -- [victim humanoid] = the mark record (see MARK)
local markOf = {}       -- [marker player] = victim humanoid: one mark per marker
local decoys = {}       -- [player] = { Model, Humanoid, Character, Until, Epoch, Conns }
local steps = {}        -- [player] = { Character, Epoch }: a Shadow Step between its dissolve and its re-form
local charges = {}      -- [player] = { At (os.clock), Due (seconds), Character }: a Shadow Dart charge awaiting its release
local windups = {}      -- [player] = { Character, Stamp }: an Eclipse between the cast and the open
local dives = {}        -- [player] = { Character, HitAt, StepAt, StepRole, StepCut }: the dive reward's clocks (2026-10-18, umbra)

----------------------------------------------------------------------------------------------------
-- ULTIMATE: ECLIPSE's window (Unseen and Shadow Dart read it)
----------------------------------------------------------------------------------------------------
local function eclipseOn(player, character)
	local e = eclipses[player]
	return e ~= nil and e.Character == character and Core.Epoch(player) == e.Epoch and serverNow() < e.Until
end

local function endEclipse(player, reason)
	local e = eclipses[player]
	if not e then return end
	eclipses[player] = nil
	local character = e.Character
	if character and character.Parent then
		if character:GetAttribute("EclipseUntil") == e.Until then character:SetAttribute("EclipseUntil", nil) end
		character:SetAttribute("M1RateMult", nil)
	end
	broadcast("EclipseEnd", { Character = character, Caster = player.UserId, Reason = reason })
end

--- The caster's hold in place for the windup comes off -- only while it is still OURS (the one SpeedCapUlt slot is shared
--- with Terra's and Cryo's holds, each of which clears only its own).
local function releaseHold(w)
	local c = w.Character
	if c and c.Parent and c:GetAttribute("UmbraHold") == w.Stamp then
		c:SetAttribute("UmbraHold", nil)
		if c:GetAttribute("SpeedCapUlt") == 0 then c:SetAttribute("SpeedCapUlt", nil) end
	end
end

local function cancelWindup(player, reason)
	local w = windups[player]
	if not w then return end
	windups[player] = nil
	releaseHold(w)
	broadcast("EclipseCancel", { Character = w.Character, Caster = player.UserId, Reason = reason })
	broadcast("EclipseEnd", { Character = w.Character, Caster = player.UserId, Reason = reason })   -- the press lets go
end

local function openEclipse(player, character)
	local E = T.Eclipse
	local now = serverNow()
	local e = { Character = character, Until = now + E.Duration / timeScale(), Epoch = Core.Epoch(player) }
	eclipses[player] = e
	character:SetAttribute("EclipseUntil", e.Until)
	character:SetAttribute("M1RateMult", E.FireRateMult)
	broadcast("EclipseStart", {
		Character = character, Caster = player.UserId, Zone = player:GetAttribute("Zone"), Map = player:GetAttribute("Map"),
		T0 = now, Until = e.Until,
	})
end

local function castEclipse(player, character, humanoid, root, payload, role)
	endEclipse(player, "Recast")
	cancelWindup(player, "Recast")
	local windup = (T.Eclipse.WindupTime or 0) / timeScale()
	if windup <= 0 then return openEclipse(player, character) end
	local now = serverNow()
	local w = { Character = character, Stamp = now }
	windups[player] = w
	character:SetAttribute("SpeedCapUlt", 0)
	character:SetAttribute("UmbraHold", now)
	local epoch = Core.Epoch(player)
	broadcast("EclipseCharge", { Character = character, Caster = player.UserId, T0 = now, Windup = windup })
	task.delay(windup, function()
		if windups[player] ~= w then return end
		windups[player] = nil
		releaseHold(w)
		if Core.Epoch(player) ~= epoch or player.Character ~= character or not (humanoid.Parent and humanoid.Health > 0) then
			broadcast("EclipseCancel", { Character = character, Caster = player.UserId, Reason = "Lost" })
			broadcast("EclipseEnd", { Character = character, Caster = player.UserId, Reason = "Lost" })
			return
		end
		openEclipse(player, character)
	end)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: UNSEEN
----------------------------------------------------------------------------------------------------
--- Whether `target` is unaware of the caster: Eclipse is up, or the caster is more than UnawareAngle off the way the
--- target faces (flat). A first-person body faces its camera's yaw, so this is "not on their screen" in practice.
local function unaware(player, casterChar, target)
	if eclipseOn(player, casterChar) then return true end
	local troot, croot = rootOf(target), rootOf(casterChar)
	if not (troot and croot) then return false end
	local face = flat(troot.CFrame.LookVector)
	local to = flat(croot.Position - troot.Position)
	if face.Magnitude < 1e-3 or to.Magnitude < 1e-3 then return false end
	return face.Unit:Dot(to.Unit) < math.cos(math.rad(T.Unseen.UnawareAngle))
end

----------------------------------------------------------------------------------------------------
-- HEAD vs BODY -- MARK ONLY (see the header). Nowhere else in the game asks where a shot landed.
----------------------------------------------------------------------------------------------------
--- A claimed Shadow Dart contact counts as a HEADSHOT when the client claims the target's Head part and the point is on
--- that head as the server has it: tight vertically (the head is the top of the body; only a jump or a fall moves it
--- much between the two views), with the usual trailing allowance sideways.
local function isHeadshot(model, part, position)
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then return false end
	-- the head's hitbox twin (HitboxScale, 2026-10-17) is the head too, at its own bigger size
	local box = head
	if part ~= head then
		if not (part:GetAttribute("HitboxOf") == "Head" and part:IsDescendantOf(model)) then return false end
		box = part
	end
	local root = rootOf(model)
	local vel = root and root.AssemblyLinearVelocity or Vector3.zero
	local rel = position - head.Position
	local halfY = box.Size.Y / 2 + 0.35 + math.abs(vel.Y) * 0.25
	local halfXZ = math.max(box.Size.X, box.Size.Z) / 2 + 0.6 + flat(vel).Magnitude * 0.25
	return math.abs(rel.Y) <= halfY and flat(rel).Magnitude <= halfXZ
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: MARK (kit-owned status "Marked")
----------------------------------------------------------------------------------------------------
-- rec = { Marker, MarkerEpoch, Model, Humanoid, VictimEpoch, T0, Stacks, Total, Expires } (server times)
local function victimEpoch(model)
	local p = model and Players:GetPlayerFromCharacter(model)
	return p and Core.Epoch(p) or nil
end

--- the flag LAST on, FIRST off: the order every other writer of an RX_ status uses (StatusEffects.publish)
local function publishMark(rec)
	local model = rec.Model
	if not (model and model.Parent) then return end
	model:SetAttribute("RX_Marked_Element", "Umbra")
	model:SetAttribute("RX_Marked_Stacks", rec.Stacks)
	model:SetAttribute("RX_Marked_Expires", rec.Expires)
	model:SetAttribute("RX_Marked_Total", rec.Total)
	model:SetAttribute("RX_Marked", true)
end

local function unpublishMark(model)
	if not (model and model.Parent) then return end
	model:SetAttribute("RX_Marked", false)
	for _, s in ipairs({ "_Stacks", "_Expires", "_Total", "_Element" }) do model:SetAttribute("RX_Marked" .. s, nil) end
end

local function clearMark(humanoid, reason)
	local rec = marks[humanoid]
	if not rec then return end
	marks[humanoid] = nil
	if markOf[rec.Marker] == humanoid then markOf[rec.Marker] = nil end
	unpublishMark(rec.Model)
	broadcast("MarkEnd", { Victim = rec.Model, Marker = rec.Marker.UserId, Reason = reason, Stacks = rec.Stacks })
end

local function clearMarksBy(player, reason)
	local h = markOf[player]
	if h then clearMark(h, reason) end
end

--- THE LOCK: Earthen Tomb's rule -- the enemy nearest the aim line out of the caster's eye, within LockRadius of it, in
--- front, within Range (+ RangeSlack), nothing solid between. Never a veiled body.
local function acquireMark(player, character, root, aimAt)
	local M = T.Mark
	local eye = eyeOf(character, root)
	local aim = Core.ValidVector(aimAt) and (aimAt - eye) or root.CFrame.LookVector
	if aim.Magnitude < 1e-3 then aim = root.CFrame.LookVector end
	aim = aim.Unit
	local range = M.Range + M.RangeSlack
	local best, bestPerp, bestDist = nil, math.huge, math.huge
	for hum, model in pairs(Core.HumanoidsNear(root.Position, range + 4, character)) do
		local r = rootOf(model)
		if r and hum.Health > 0 and not Core.IsWall(model) and not Core.IsFriendly(player, model) and not Core.IsVeiled(model) then
			local rel = r.Position - eye
			local along = rel:Dot(aim)
			local perp = (rel - aim * along).Magnitude
			local dist = flat(r.Position - root.Position).Magnitude
			if along > 0 and perp <= M.LockRadius and dist <= range
				and (perp < bestPerp - 0.25 or (perp < bestPerp + 0.25 and dist < bestDist))
				and not Core.Blocked({ Origin = eye, Dir = rel.Unit, Character = character }, rel.Magnitude, model) then
				best, bestPerp, bestDist = model, perp, dist
			end
		end
	end
	return best
end

local function castMark(player, character, humanoid, root, payload, role)
	local model = acquireMark(player, character, root, payload.Target)
	if not model then
		giveBack:Fire(player, role, true)          -- the precheck saw someone who has since gone: nothing spent
		return
	end
	local vhum = model:FindFirstChildOfClass("Humanoid")
	if not vhum then return end
	clearMarksBy(player, "Replaced")          -- one mark per marker
	if marks[vhum] then clearMark(vhum, "Replaced") end
	local M = T.Mark
	local scale = timeScale()
	local now = serverNow()
	local total = ((M.MaxStacks - 1) * M.StackEvery + M.ExpireAfterFull) / scale
	local rec = {
		Marker = player, MarkerEpoch = Core.Epoch(player), Model = model, Humanoid = vhum, VictimEpoch = victimEpoch(model),
		T0 = now, Scale = scale, Stacks = 1, Total = total, Expires = now + total,
	}
	marks[vhum] = rec
	markOf[player] = vhum
	publishMark(rec)
	broadcast("MarkApplied", { Character = character, Victim = model, T0 = now, Total = total, MaxStacks = M.MaxStacks })
	if Callouts then
		local head = model:FindFirstChild("Head") or rootOf(model)
		if head then pcall(Callouts.Pop, head, Vector3.new(0, 1.2, 0), "HUNTED!", "hunted") end
	end
end

-- The mark's check: someone was found to mark. Answered BEFORE SpellshotService charges the cast (its Precheck path).
do
	local check = spellFolder:FindFirstChild("Precheck_Mark")
	if not check then
		check = Instance.new("BindableFunction")
		check.Name = "Precheck_Mark"
		check.Parent = spellFolder
	end
	check.OnInvoke = function(player, role, payload)
		local character, _, root = Core.CanAct(player)
		if not character then return false end
		return acquireMark(player, character, root, type(payload) == "table" and payload.Target or nil) ~= nil
	end
end

-- THE PAYOFF: the MARKER's next real hit on the marked body (not a DoT tick, not anyone else's). -10 runs before every
-- soak, so a shield in front of a marked target loses its share of the bonus too. info.Head is set only by Shadow Dart.
Core.AddModifier(-10, function(victim, amount, info, caster)
	local rec = marks[victim]
	if not rec or amount <= 0 or (info and info.DoT) or caster ~= rec.Marker then return amount end
	local head = info and info.Head == true
	local bonus = (head and T.Mark.HeadBonus or T.Mark.BodyBonus)[rec.Stacks] or 0
	if info then
		info.MarkBonus = bonus
		info.MarkStacks = rec.Stacks
	end
	clearMark(victim, head and "Headshot" or "Body")
	return amount + bonus
end)

local function stepMark(humanoid, rec, now)
	local model = rec.Model
	if not (model.Parent and humanoid.Parent == model and humanoid.Health > 0) then return clearMark(humanoid, "Gone") end
	if not rec.Marker.Parent or Core.Epoch(rec.Marker) ~= rec.MarkerEpoch then return clearMark(humanoid, "MarkerCleared") end
	if rec.VictimEpoch ~= nil and victimEpoch(model) ~= rec.VictimEpoch then return clearMark(humanoid, "Cleared") end
	if now >= rec.Expires then return clearMark(humanoid, "Expired") end
	local M = T.Mark
	local stacks = math.min(M.MaxStacks, 1 + math.floor((now - rec.T0) * rec.Scale / M.StackEvery))
	if stacks ~= rec.Stacks then
		rec.Stacks = stacks
		publishMark(rec)
		broadcast("MarkStack", { Victim = model, Stacks = stacks, Full = stacks >= M.MaxStacks })
	end
end

----------------------------------------------------------------------------------------------------
-- M1: SHADOW DART
----------------------------------------------------------------------------------------------------
local function rateMult(character)
	local m = character and character:GetAttribute("M1RateMult")
	return (type(m) == "number" and m > 0) and m or 1
end

--- One dart per FireInterval (divided by Eclipse's multiplier) on average; the bucket earns a dart 8% sooner than the
--- client may fire and holds Bucket, so jitter is never thrown away and only real over-rate is refused.
local function takeToken(player, character)
	local D = T.ShadowDart
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { Tokens = D.Bucket, At = now }
		buckets[player] = b
	end
	local interval = D.FireInterval / rateMult(character) * 0.92 / timeScale()
	b.Tokens = math.min(D.Bucket, b.Tokens + (now - b.At) / interval)
	b.At = now
	if b.Tokens < 1 then return false end
	b.Tokens -= 1
	return true
end

--- The click, already paid for by SpellshotService (the rate and the mana): the charge starts. Everyone is told
--- (ShadowDartCharge: the gather on the body), and it is remembered, so the release that ends it can be checked.
local function castDartCharge(player, character, humanoid, root, payload, role)
	if role ~= "M1" then return end
	local due = T.ShadowDart.Windup / rateMult(character) / timeScale()
	charges[player] = { At = os.clock(), Due = due, Character = character }
	exposed(character)                                             -- the Tell: the brace is the shot's own telegraph
	broadcast("ShadowDartCharge", { Character = character, T0 = serverNow(), Windup = due, Mult = rateMult(character) })
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "ShadowDartRelease" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "ShadowDart") then return end
	local character, humanoid, root = Core.CanAct(player)
	if not character then return end
	local origin, target, id = a.Origin, a.Target, a.Id
	if not (Core.ValidVector(origin) and Core.ValidVector(target)) or type(id) ~= "number" then return end
	-- THE CHARGE: a release ends a charge this server saw start, and comes no sooner than it could have been gathered
	local c = charges[player]
	if not (c and c.Character == character) then
		Core.CountShot("rej_nocharge")
		return
	end
	local held = os.clock() - c.At
	if held < c.Due - T.ShadowDart.ChargeSlack then
		Core.CountShot("rej_early_charge")                      -- kept: a legitimate release can still end it
		return
	end
	charges[player] = nil
	if held > c.Due + T.ShadowDart.ChargeGiveUp then
		Core.CountShot("rej_stale_charge")
		return
	end
	if not takeToken(player, character) then
		Core.CountShot("rej_rate")
		return
	end
	if not eyeNear(player, character, humanoid, root, origin) then
		Core.CountShot("rej_origin")
		return
	end
	local dir = target - origin
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	local mine = shots[player]
	if not mine then
		mine = {}
		shots[player] = mine
	end
	local now = os.clock()
	for oldId, shot in pairs(mine) do
		if now - shot.At > shot.Life then mine[oldId] = nil end
	end
	local scale = timeScale()
	mine[id] = { Origin = origin, Dir = dir, At = now, Character = character, Scale = scale,
		Life = T.ShadowDart.Range / (T.ShadowDart.Speed * scale) + 1.5 }
	Core.CountShot("release")
	exposed(character)                                             -- the Tell: a shot fired
	broadcast("ShadowDart", { Character = character, Origin = origin, Dir = dir, Id = id, T0 = serverNow() })
end)

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "ShadowDartHit" or type(a) ~= "table" then return end
	local mine = shots[player]
	local shot = mine and type(a.Id) == "number" and mine[a.Id]
	if not shot then
		Core.CountShot("rej_noshot")
		return
	end
	mine[a.Id] = nil                                               -- one hit per dart
	local D = T.ShadowDart
	local now = os.clock()
	if now - shot.At > shot.Life then
		Core.CountShot("rej_late")
		return
	end
	local part, position = a.Part, a.Position
	if not validClaimPart(part, position) then
		Core.CountShot("rej_badpart")
		return
	end
	local rel = position - shot.Origin
	local along = rel:Dot(shot.Dir)
	if along < -0.5 or along > D.Range + 1.5 or (rel - shot.Dir * along).Magnitude > D.HitSlack + D.Radius then
		Core.CountShot("rej_offline")
		return
	end
	if now - shot.At < along / (D.Speed * shot.Scale) - 0.25 then
		Core.CountShot("rej_early")
		return
	end
	local reason, model, hum = checkClaim(part, position, shot.Character)
	if reason then
		Core.CountShot(reason)
		return
	end
	if claimBlocked(shot, math.max(along, 0), position, hum and model or part) then
		Core.CountShot("rej_blocked")
		return
	end
	Core.CountShot("hit")
	local out = { Character = shot.Character, Id = a.Id, Point = position }
	if hum then
		Core.CountShot("hit_char")
		local unaw = unaware(player, shot.Character, model)
		local amount = D.Damage * (unaw and (1 + T.Unseen.Bonus) or 1)
		local info = { Ranged = true, From = shot.Origin, Source = "ShadowDart", Unaware = unaw }
		-- the head is asked ONLY for a body carrying this shooter's own Mark (see HEAD vs BODY)
		local rec = marks[hum]
		if rec and rec.Marker == player then info.Head = isHeadshot(model, part, position) end
		local before = hum.Health
		if Core.DealDamage(player, hum, amount, info) then
			if hum.Health >= before then Core.CountShot("dmg_soaked") end
			if unaw and shot.Character.Parent then shot.Character:SetAttribute("PassiveProc", serverNow()) end
			out.Victim, out.Unaware, out.Head, out.MarkBonus = model, unaw, info.Head, info.MarkBonus
		else
			Core.CountShot("rej_friendly")
		end
	else
		Core.CountShot("hit_world")
	end
	exposed(shot.Character)                                        -- the Tell: a hit landed
	Core.ShotImpact:Fire(part, position, player)
	broadcast("ShadowDartHit", out)
end)

----------------------------------------------------------------------------------------------------
-- PRIMARY: SHADOW STEP
----------------------------------------------------------------------------------------------------
--- Where a step toward `aimAt` re-forms the body: the root's spot, or nil when there is nowhere to go.
local function stepDestination(character, humanoid, root, aimAt)
	local S = T.ShadowStep
	local eye = eyeOf(character, root)
	local aim = Core.ValidVector(aimAt) and flat(aimAt - eye) or flat(root.CFrame.LookVector)
	if aim.Magnitude < 1e-3 then aim = flat(root.CFrame.LookVector) end
	if aim.Magnitude < 1e-3 then return nil end
	local dir = aim.Unit
	local want = S.Distance
	if Core.ValidVector(aimAt) then
		local d = flat(aimAt - root.Position).Magnitude
		if d - S.AimPad >= S.MinDistance then want = math.min(want, d - S.AimPad) end
	end
	-- stop short of the first wall at waist height (bodies are seen through: you may step past someone)
	local params = worldParams({ character }, true)
	local wall = castThroughBodies(root.Position, dir * want, params)
	if wall then want = (wall.Position - root.Position):Dot(dir) - S.WallPad end
	local rootAbove = humanoid.HipHeight + root.Size.Y / 2
	-- back off 2 studs at a time until the spot has a floor and headroom
	local dist = want
	while dist >= S.MinDistance do
		local spot = root.Position + dir * dist
		local floor = castThroughBodies(spot + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), worldParams({ character }, true))
		if floor then
			local at = floor.Position + Vector3.new(0, rootAbove, 0)
			local roof = castThroughBodies(floor.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, S.Clearance, 0),
				worldParams({ character }, true))
			if not roof then return at, dir end
		end
		dist -= 2
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- THE DIVE REWARD (2026-10-18, umbra; handoff #8, exactly as the 3v3 sim's P27 "half cooldown" modelled it)
----------------------------------------------------------------------------------------------------
-- Shadow Step's cooldown is DiveCooldown instead of Cooldown when (a) it is cast within DiveWindow after Umbra landed a
-- hit on an enemy, or (b) Umbra lands a hit within DiveWindow after casting it -- then the running cooldown is cut to end
-- at the cast + DiveCooldown, once per cast. Never below DiveCooldown. The NORMAL cast only: the escape charge keeps its own
-- cooldown and never earns it. It writes CD_<role> the way Pyro's Ember Refund does; a CD_ already at or under the target
-- (dev no-cooldowns, a cleared cooldown) is left alone. DiveCooldown >= Cooldown, or DiveWindow 0, turns it off.
local function diveOn()
	local S = T.ShadowStep
	return type(S.DiveCooldown) == "number" and type(S.DiveWindow) == "number" and S.DiveWindow > 0
		and S.DiveCooldown < S.Cooldown
end

local function diveRecord(player, character)
	local d = dives[player]
	if not d or d.Character ~= character then
		d = { Character = character }
		dives[player] = d
	end
	return d
end

--- The running cooldown cut to end at castAt + DiveCooldown, if it ends later than that. true when it was cut.
local function diveCut(character, role, castAt)
	local target = castAt + T.ShadowStep.DiveCooldown
	local readyAt = character:GetAttribute("CD_" .. role) or 0
	if readyAt <= target then return false end
	character:SetAttribute("CD_" .. role, math.max(serverNow(), target))
	return true
end

--- (a), at the cast: SpellshotService has just stamped CD_ = now + Cooldown; a hit within DiveWindow before makes it
--- DiveCooldown, and CDTotal_ with it, so the slot's sweep runs the 5 s from full. Either way the cast opens (b)'s window.
local function diveOnCast(player, character, role)
	if not diveOn() then return end
	local now = serverNow()
	local d = diveRecord(player, character)
	d.StepAt, d.StepRole, d.StepCut = now, role, false
	if d.HitAt and now - d.HitAt <= T.ShadowStep.DiveWindow then
		d.StepCut = true
		if diveCut(character, role, now) then character:SetAttribute("CDTotal_" .. role, T.ShadowStep.DiveCooldown) end
	end
end

-- Every landed hit of an Umbra holding Shadow Step: on an enemy body (not a wall, not a decoy, not a burn tick; a dummy
-- counts, a soaked hit counts -- it landed). Marks the hit for (a), and is (b) inside the window after a cast. The cut
-- mid-run leaves CDTotal_ alone, so the sweep jumps forward the way Ember Refund's does.
Core.OnHitLanded(function(caster, humanoid, amount, info)
	if not diveOn() then return end
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	if (info and info.DoT) or type(amount) ~= "number" or amount <= 0 then return end
	local character = caster.Character
	local model = humanoid and humanoid.Parent
	if not (character and character.Parent and model) or model == character then return end
	if Core.IsWall(model) or model:GetAttribute("DecoyOwner") then return end
	if not holds(caster, "Primary", "ShadowStep") then return end
	local now = serverNow()
	local d = diveRecord(caster, character)
	d.HitAt = now
	if d.StepAt and not d.StepCut and now - d.StepAt <= T.ShadowStep.DiveWindow then
		d.StepCut = true
		diveCut(character, d.StepRole or "Primary", d.StepAt)
	end
end)

local function castShadowStep(player, character, humanoid, root, payload, role)
	local S = T.ShadowStep
	-- THE ESCAPE (2026-10-18, umbra): payload.Escape is SpellshotService's word, never the client's -- this press spent the
	-- escape charge. The same step in every way below; it only gives back its own charge, and earns no dive reward.
	local escape = payload.Escape == true
	-- A press while a step is still dissolving (a double tap: the normal cast, the escape a moment later) is given back
	-- whole: it would replace the first step's record, and two charges would buy one blink (2026-10-18, umbra).
	local busy = steps[player]
	if busy and busy.Character == character and busy.Epoch == Core.Epoch(player) then
		giveBack:Fire(player, role, true, escape)
		return
	end
	local dest, dir = stepDestination(character, humanoid, root, payload.Target)
	if not dest then
		giveBack:Fire(player, role, true, escape)                        -- nowhere to step: nothing spent (the escape's own charge, 2026-10-18)
		--[[giveBack:Fire(player, role, true)   until 2026-10-18]]
		return
	end
	if not escape then diveOnCast(player, character, role) end      -- (2026-10-18, umbra)
	local scale = timeScale()
	local now = serverNow()
	local dissolve = S.DissolveTime / scale
	local veiled = now + dissolve + S.VeilTime / scale
	character:SetAttribute("VeiledUntil", veiled)
	local epoch = Core.Epoch(player)
	steps[player] = { Character = character, Epoch = epoch }
	broadcast("ShadowStepOut", { Character = character, From = root.Position, To = dest, T0 = now, Dissolve = dissolve,
		VeiledUntil = veiled, Escape = escape or nil })                  -- Escape: which charge (2026-10-18; no client reads it yet)
	task.delay(dissolve, function()
		local s = steps[player]
		if not s or s.Character ~= character then return end
		steps[player] = nil
		if Core.Epoch(player) ~= epoch or not (character.Parent and humanoid.Health > 0 and root.Parent) then return end
		local face = flat(root.CFrame.LookVector)
		if face.Magnitude < 1e-3 then face = dir end
		character:PivotTo(CFrame.lookAt(dest, dest + face.Unit))
		root.AssemblyLinearVelocity = Vector3.zero
		broadcast("ShadowStepIn", { Character = character, At = dest, T0 = serverNow(), VeiledUntil = veiled })
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: DECOY DOUBLE
----------------------------------------------------------------------------------------------------
local decoyFolder = workspace:FindFirstChild("UmbraDecoys")
if not decoyFolder then
	decoyFolder = Instance.new("Folder")
	decoyFolder.Name = "UmbraDecoys"
	decoyFolder.Parent = workspace
end

local function removeDecoy(player, reason)
	local d = decoys[player]
	if not d then return end
	decoys[player] = nil
	for _, c in ipairs(d.Conns) do c:Disconnect() end
	local root = d.Model and rootOf(d.Model)
	broadcast("DecoyBreak", { Owner = d.Character, Decoy = d.Model, At = root and root.Position or nil, Reason = reason })
	if reason == "Hit" then exposed(d.Character) end               -- the Tell: the illusion failed
	local model = d.Model
	task.delay(0.35, function()                                    -- a beat for the break to be drawn on it
		if model and model.Parent then model:Destroy() end
	end)
end

local function castDecoy(player, character, humanoid, root, payload, role)
	removeDecoy(player, "Recast")
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = was
	if not (ok and copy) then
		warnOnce("decoyclone", "Decoy Double could not copy the body: " .. tostring(copy))
		giveBack:Fire(player, role, true)
		return
	end
	-- a body, not a player: no scripts, no tools, no force field, no sounds of its own
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound") then d:Destroy() end
	end
	-- none of the body's state comes with it: statuses (RX_*), mana, cooldowns, the veil, Eclipse
	for attr in pairs(copy:GetAttributes()) do copy:SetAttribute(attr, nil) end
	local chum = copy:FindFirstChildOfClass("Humanoid")
	local croot = rootOf(copy)
	if not (chum and croot) then
		copy:Destroy()
		giveBack:Fire(player, role, true)
		return
	end
	copy.Name = character.Name
	copy:SetAttribute("DecoyOwner", player.UserId)
	chum.MaxHealth = Config.MaxHealth
	chum.Health = Config.MaxHealth
	chum.BreakJointsOnDeath = false
	-- it peels off to the side of Umbra (the side with room), stands on the floor, and never moves
	local side = root.CFrame.RightVector
	local base = root.Position + side * T.DecoyDouble.Offset
	local wall = castThroughBodies(root.Position, side * (T.DecoyDouble.Offset + 1), worldParams({ character }, true))
	if wall then base = root.Position - side * T.DecoyDouble.Offset end
	copy:PivotTo(CFrame.lookAt(base, base + flat(root.CFrame.LookVector)))
	croot.Anchored = true
	copy.Parent = decoyFolder
	local d = { Model = copy, Humanoid = chum, Character = character, Epoch = Core.Epoch(player),
		Until = serverNow() + T.DecoyDouble.Duration / timeScale(), Conns = {} }
	decoys[player] = d
	local full = chum.Health
	d.Conns[#d.Conns + 1] = chum.HealthChanged:Connect(function(h)
		if h < full - 0.01 and decoys[player] == d then removeDecoy(player, "Hit") end
	end)
	broadcast("DecoySpawn", { Owner = character, Decoy = copy, At = base, T0 = serverNow() })
end

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
-- Shadow Dart's CastRequest (SpellshotService's rate and mana) only STARTS the charge; the dart is ShadowDartRelease.
local casts = {
	ShadowDart = castDartCharge,                               -- the M1's click: the charge (the dart is ShadowDartRelease)
	ShadowStep = castShadowStep,
	Mark = castMark,
	DecoyDouble = castDecoy,
	Eclipse = castEclipse,
}

performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then return end
	local ok, err = pcall(fn, player, character, humanoid, root, type(payload) == "table" and payload or {}, role)
	if not ok then warnOnce("cast" .. ability.Id, ability.Id .. " failed: " .. tostring(err)) end
end)

----------------------------------------------------------------------------------------------------
-- the Heartbeat: marks ripening and expiring, Eclipse's end, the decoy's clock
----------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	if next(marks) == nil and next(eclipses) == nil and next(decoys) == nil then return end
	local now = serverNow()
	for humanoid, rec in pairs(marks) do
		local ok, err = pcall(stepMark, humanoid, rec, now)
		if not ok then
			warnOnce("stepmark", "Mark step failed: " .. tostring(err))
			marks[humanoid] = nil
			if markOf[rec.Marker] == humanoid then markOf[rec.Marker] = nil end
			pcall(unpublishMark, rec.Model)
		end
	end
	for player, e in pairs(eclipses) do
		if not eclipseOn(player, e.Character) then endEclipse(player, "Expired") end
	end
	for player, d in pairs(decoys) do
		if now >= d.Until then
			removeDecoy(player, "Expired")
		elseif not (d.Model.Parent and d.Humanoid.Health > 0) then
			removeDecoy(player, "Gone")
		elseif Core.Epoch(player) ~= d.Epoch or player.Character ~= d.Character then
			removeDecoy(player, "Cleared")
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
local function endAll(player, reason)
	charges[player] = nil
	cancelWindup(player, reason)
	endEclipse(player, reason)
	clearMarksBy(player, reason)
	removeDecoy(player, reason)
	steps[player] = nil
	dives[player] = nil                                            -- the dive reward's clocks (2026-10-18, umbra)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum and marks[hum] then clearMark(hum, reason) end
	if character and character.Parent then character:SetAttribute("VeiledUntil", nil) end
end

local function watchCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function()
		if player.Character == character then endAll(player, "Died") end
	end)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		endAll(player, "Died")
	end)
	if player.Character then task.spawn(watchCharacter, player, player.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	endAll(player, "Left")
	buckets[player] = nil
	shots[player] = nil
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): everything this player has running ends, and
-- a mark on them goes.
Core.OnClear(function(player)
	endAll(player, "Clear")
	shots[player] = nil
end)

print("[UmbraHandler] ready")
