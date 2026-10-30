--[[
	RadiantHandler  (Script)  ->  ServerScriptService/RadiantHandler

	The gameplay side of RADIANT, reworked (manual v0.19-v0.21; build prompt Opus55_Radiant_Rework_Build.md, Phase 3,
	2026-09-29). RadiantClient is its client half. Every number is RadiantTuning's (ReplicatedStorage.IceMagic, pure
	data) and every one is a PLACEHOLDER. Before this, Radiant existed only as config text (Light Lance, Blessing,
	Afterglow, Radiant Judgment, Lightstep and Cleansing Ring never had a cast path; the retired entries are recorded in
	ServerStorage.RadiantKitSuperseded). Visuals here are PLACEHOLDERS too (RadiantFX): Phase 4 designs the real ones.

	  M1        LIGHT LANCE     a HELD CHANNEL BEAM. SpellshotService has no held M1, so this is Shadow Dart's shape: the
	                            click's CastRequest (the M1 rate gate, StartCost) starts the channel here, the client then
	                            streams RadiantLanceAim (the aim, and the body its own ray touches: part + point) and sends
	                            RadiantLanceStop on letting go. Every Tick the server deals damage to the CLAIMED body --
	                            a claim is checked like any shot (CheckTarget's position history, on the aim line from the
	                            client's Origin -- within OriginSlack of the head -- within HitSlack, Blocked) and counts
	                            for ClaimFresh. Damage ramps DpsStart -> DpsMax over
	                            RampTime on ONE target. Mana drains ManaPerSecond (SpendMana); empty, dead, cleared,
	                            planted (Benediction) or in Halo's windup, the beam stops.
	  PRIMARY   BLESSING        the ally nearest the aim line (Mark's lock rule, inverted) gets StatusEffects' Blessed
	                            shield (its live preset's absorb and duration); with no ally there, the caster does.
	  PASSIVE   OVERFLOW LIGHT  StatusEffects.OnLapse: a Blessed shield from a Radiant that runs out its WHOLE duration with
	                            absorb left heals whoever had it by that leftover x ConvertPct. Emptied or cleared: nothing.
	  ULTIMATE  HALO            the charge is spent on the cast (SpellshotService). The WINDUP (the staff's spiral) caps the
	                            caster's speed at WindupSpeed; then for Duration (HaloUntil on the character, server time)
	                            every point of health the caster's damage removes (CombatCore's info.Removed) also heals,
	                            x HealPct, shared evenly by the caster and every ally within TeamRadius, up to HealCap in
	                            all per Halo (then it ends). ADDITIVE: enemies
	                            still take all of it (the manual; the concern about the health economy is flagged, not
	                            decided here).
	  TECHNIQUE POSITION TRADE  the body nearest the aim line -- ally, enemy or training dummy -- and the caster dissolve for
	                            DissolveTime, then each is moved to where the other stood, keeping its own facing.
	                            Precheck: a press with nobody to swap with costs nothing. An enemy's Decoy Double counts as
	                            somebody (2026-10-19, audit P5C-05): the press is paid, and the trade breaks the decoy
	                            instead of moving anyone.
	  TECHNIQUE BENEDICTION     HELD (2026-09-30: the owner, "as long as u hold it, it can be used"): the press pays the
	                            start cost (SpellshotService's held path) and roots the caster (SpeedCapUlt 0, and a jump
	                            lock through AbilityHandler's JumpLock bindable); WindUp later the staff is planted (T0),
	                            then a heal pulse every PulseEvery goes to every ally within Radius (or the caster when none
	                            is), mana draining ManaPerSecond, for as long as the key is held. It ends on the release
	                            (a tap still pulses once), an interrupt, an empty bar, the leash, the floor going, death, a
	                            clear, a new Epoch, or MaxChannel; the cooldown starts when it ends.

	ALLIES: an ally is another player's living body, in the caster's Zone (never the Hub) and PARTY (the same Map and
	DuelMatch: maps are shared by several matches), that the caster may not hurt (CombatCore.IsFriendly) -- so in a 1v1
	duel there are none, and Blessing and Benediction fall back to the caster. (2026-10-19, audit P3-24) Team matches
	exist since 2026-10-18: teammates are allies through Config.MayHurt's MatchTeam clause (IsFriendly -> IsAllyOf), not
	through Roblox Teams. Position Trade takes a player only from the caster's own MATCH (the opponent, or a teammate) --
	never a Solo Test stranger on the same map (2026-10-19, audit P1-14) -- and never over a drop (FloorProbe, both ends).
	The rule is
	CombatCore.IsAllyOf (2026-09-30), shared by every support kit; it also counts the range's ALLY DUMMIES
	(ServerScriptService.AllyDummies), so Blessing, Benediction, Halo's share and Position Trade can be practised solo.

	HEALS go through CombatCore.Heal (the game's one heal, added with this kit): clamped to MaxHealth, never on the dead,
	walls, decoys or training dummies. A "+N" pops over the healed body (RadiantHandler's heal readout, Callouts style
	"heal", coalesced so a stream of small heals reads as a few numbers).

	Server -> client (AbilityFX -> RadiantClient.Handlers): ("VFX", kind, data) on IceAbilityRemote, to everyone:
	  RadiantLanceOn / RadiantLance / RadiantLanceOff, RadiantBlessing, RadiantOverflow, RadiantHaloCharge /
	  RadiantHaloCancel / RadiantHaloStart / RadiantHaloEnd, RadiantTradeOut / RadiantTradeIn, RadiantBenedictionStart /
	  RadiantBenedictionPulse / RadiantBenedictionEnd.
	Client -> server (IceAbilityRemote): RadiantLanceAim, RadiantLanceStop.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local T = require(iceFolder:WaitForChild("RadiantTuning"))       -- pure data; the clients read the same table
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local giveBack = spellFolder:WaitForChild("GiveBack")            -- (player, role, true): the cast back, and its Ultimate charge
local spendMana = spellFolder:WaitForChild("SpendMana")          -- (player, amount)
local releaseHold = spellFolder:WaitForChild("ReleaseHold", 15)  -- (player, role): a HELD ability ended here (Benediction)
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Core = require(script.Parent:WaitForChild("CombatCore"))
local Status = require(script.Parent:WaitForChild("StatusEffects"))

local remote = Core.Remote
-- every Radiant broadcast carries its caster's skin Id for the ability it draws (SkinCatalog: Default when none, or
-- when the ability is not theirs to skin); every client, the caster's too, draws with it. Colour only.
local SkinCatalog = require(spellFolder:WaitForChild("SkinCatalog"))
local function broadcast(kind, data)
	if type(data) == "table" and data.Skin == nil then
		local ability = SkinCatalog.AbilityOfKind(kind)
		local c = ability and data.Character
		local plr = typeof(c) == "Instance" and Players:GetPlayerFromCharacter(c) or nil
		if plr then data.Skin = SkinCatalog.Chosen(plr, ability) end
	end
	return Core.Broadcast(kind, data)
end

----------------------------------------------------------------------------------------------------
-- helpers (Umbra's, the same rules)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[RadiantHandler] " .. tostring(msg))
end

-- the jump half of a root has ONE writer, AbilityHandler (its setJumpLock); Benediction asks it through this bindable
local jumpLock = spellFolder:WaitForChild("JumpLock", 15)
if not jumpLock then warnOnce("jumplock", "JumpLock bindable missing: Benediction roots walking only") end

-- the heal readout goes through the same module every other popup does. Guarded: a number is not worth the kit.
local Callouts = nil
do
	local ok, mod = pcall(function()
		return require(spellFolder:WaitForChild("Callouts", 10))
	end)
	if ok and type(mod) == "table" then
		Callouts = mod
		if type(mod.Styles) == "table" and not mod.Styles.heal then
			local H = T.HealPop
			mod.Styles.heal = { TextSize = H.TextSize, Stroke = H.Stroke, Color = H.Colour, Tilt = 4, Life = H.Life,
				Shift = Vector2.new(-0.6, -0.4), Slot = "heal" }
		end
	else
		warnOnce("callouts", "Callouts unavailable, heals will not pop: " .. tostring(mod))
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

local function pingOf(player)
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	return ping
end

--- The start of a client's aim line (review fix 2026-09-29): its ray leaves the eye in first person but the camera focus,
--- ~3 studs off the head, in the third-person view, so a claim is checked on the client's OWN line. Accepted within
--- OriginSlack of the server's head plus what a lagging body covers (UmbraHandler's rule); nil sent -> the head;
--- false -> too far.
local function aimOrigin(player, character, humanoid, root, origin)
	local head = eyeOf(character, root)
	if origin == nil then return head end
	if not Core.ValidVector(origin) then return false end
	local speed = Core.TrailSpeed(root, humanoid and humanoid.WalkSpeed or 0)
	if (origin - head).Magnitude > T.LightLance.OriginSlack + speed * (0.35 + Core.Lag(pingOf(player))) then return false end
	return origin
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

--- Two in the same PARTY (the same map and the same duel; Solo Test counts): CombatCore.SameParty since 2026-09-30.
local sameParty = Core.SameParty

--- An ALLY of `player` (see the header): CombatCore.IsAllyOf since 2026-09-30 -- another player's living body in the
--- caster's Zone and party, never the Hub, that the caster may not hurt; or an ally dummy in the caster's Zone and party.
local function isAlly(player, model)
	return Core.IsAllyOf(player, model)
end

--- Something solid under `root` within `depth` studs (every body, the FX and the model itself are seen through): a swap
--- never drops anyone over a drop, and the staff is planted on the ground.
local function floorBelow(model, root, depth)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local exclude = { model }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(root.Position, Vector3.new(0, -depth, 0), params) ~= nil
end

--- The body nearest the aim line out of the eye (Mark's lock rule): in front, within LockRadius of the line and range
--- of the caster, in sight, and accepted by `accept(model, humanoid)`. Walls and veiled bodies never; a Decoy Double
--- only when `accept` takes it (2026-10-19, audit P5C-05: an enemy's, for Position Trade -- Blessing's ally test never
--- does), so skipping decoys here no longer tells a Radiant which body is the illusion.
local function pickOnAim(player, character, root, aimAt, range, lockRadius, accept)
	local eye = eyeOf(character, root)
	local aim = Core.ValidVector(aimAt) and (aimAt - eye) or root.CFrame.LookVector
	if aim.Magnitude < 1e-3 then aim = root.CFrame.LookVector end
	aim = aim.Unit
	local best, bestPerp, bestDist = nil, math.huge, math.huge
	for hum, model in pairs(Core.HumanoidsNear(root.Position, range + 4, character)) do
		local r = rootOf(model)
		if r and hum.Health > 0 and model ~= character and not Core.IsWall(model)
			and not Core.IsVeiled(model) and accept(model, hum) then
			local rel = r.Position - eye
			local along = rel:Dot(aim)
			local perp = (rel - aim * along).Magnitude
			local dist = (r.Position - root.Position).Magnitude
			if along > 0 and perp <= lockRadius and dist <= range
				and (perp < bestPerp - 0.25 or (perp < bestPerp + 0.25 and dist < bestDist))
				and not Core.Blocked({ Origin = eye, Dir = rel.Unit, Character = character }, rel.Magnitude, model) then
				best, bestPerp, bestDist = model, perp, dist
			end
		end
	end
	return best
end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------
local lances = {}        -- [player] = { Character, Epoch, Aim, AimAt, Claim, RampModel, RampStart, LastOn, Acc, SentAt }
local aimBuckets = {}    -- [player] = { Tokens, At }: the aim stream's rate
local earlyStops = {}    -- [player] = LanceId: a Stop that overtook its own beam's click
local windups = {}       -- [player] = { Character, Stamp }: Halo's windup
local halos = {}         -- [player] = { Character, Until, Epoch }: Halo's window
local trades = {}        -- [player] = { Character, Epoch }: a Position Trade between its dissolve and its swap
local plants = {}        -- [player] = { Character, Humanoid, Epoch, Stamp, At, T0, Pulses, Next, Interval, Role, Released,
                         --   FloorAt, MaxUntil }: Benediction (held: open until it ends, see stepPlant)

----------------------------------------------------------------------------------------------------
-- the heal readout: "+N" over a healed body, coalesced (Halo's stream of small heals reads as a few numbers)
----------------------------------------------------------------------------------------------------
local healSums = {}      -- [humanoid] = { Sum, At }
local HEAL_POP_EVERY = 0.35

Core.OnHeal(function(healer, humanoid, healed)
	local rec = healSums[humanoid]
	if not rec then
		rec = { Sum = 0, At = os.clock() }
		healSums[humanoid] = rec
	end
	rec.Sum += healed
end)

local function flushHeals(force)
	local now = os.clock()
	for humanoid, rec in pairs(healSums) do
		if force or now - rec.At >= HEAL_POP_EVERY then
			healSums[humanoid] = nil
			local model = humanoid.Parent
			local head = model and model:FindFirstChild("Head")
			local n = math.floor(rec.Sum + 0.5)
			if Callouts and head and n >= 1 then
				pcall(Callouts.Pop, head, Vector3.new(0, 1.6, 0), "+" .. n, "heal")
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- M1: LIGHT LANCE
----------------------------------------------------------------------------------------------------
local function stopLance(player, reason)
	local L = lances[player]
	if not L then return end
	lances[player] = nil
	broadcast("RadiantLanceOff", { Character = L.Character, Reason = reason, Id = L.Id })
end

--- Every beam carries the caster's own number (payload.LanceId, echoed in On / RadiantLance / Off, and in the client's
--- Stop), so a message about the LAST beam never ends the next one.
local function castLance(player, character, humanoid, root, payload, role)
	if role ~= "M1" then return end
	local id = type(payload.LanceId) == "number" and payload.LanceId or nil
	-- its Stop already came (the two travel on different remotes, so a quick tap's Stop can overtake its click)
	local stoppedEarly = id ~= nil and earlyStops[player] == id
	if stoppedEarly then earlyStops[player] = nil end
	if stoppedEarly or plants[player] or windups[player] then
		-- refused (planted, or Halo's windup): the caster's client drew a beam on the click -- it is told to drop it
		remote:FireClient(player, "VFX", "RadiantLanceOff", { Character = character, Reason = "Refused", Id = id })
		return
	end
	-- a new click while the server still runs the last beam (its Stop may land after this click): the new one wins
	if lances[player] then stopLance(player, "Replaced") end
	local now = os.clock()
	lances[player] = {
		Id = id, Character = character, Epoch = Core.Epoch(player), Aim = root.CFrame.LookVector, AimAt = now,
		Claim = nil, RampModel = nil, RampStart = now, LastOn = 0, Acc = 0, SentAt = 0, LosAt = 0, LosOk = true,
	}
	broadcast("RadiantLanceOn", { Character = character, T0 = serverNow(), Id = id })
end

local function takeAimToken(player)
	local rate = T.LightLance.AimRate * 2
	local now = os.clock()
	local b = aimBuckets[player]
	if not b then
		b = { Tokens = rate * 0.5, At = now }
		aimBuckets[player] = b
	end
	b.Tokens = math.min(rate * 0.5, b.Tokens + (now - b.At) * rate)
	b.At = now
	if b.Tokens < 1 then return false end
	b.Tokens -= 1
	return true
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action == "RadiantLanceStop" then
		if not Core.Allow(player, "LanceStop", 10, 15) then return end   -- (2026-10-19, audit P1-07) no unthrottled reflector
		local L = lances[player]
		if L and (type(a) ~= "table" or a.Id == nil or a.Id == L.Id) then
			stopLance(player, "Released")
		elseif type(a) == "table" and type(a.Id) == "number" and not (L and a.Id < (L.Id or 0)) then
			earlyStops[player] = a.Id                   -- a Stop for a beam not started yet: its click will not start it
		end
		return
	end
	if action ~= "RadiantLanceAim" or type(a) ~= "table" then return end
	local L = lances[player]
	if not L then return end
	if not takeAimToken(player) then return end
	local character, humanoid, root = Core.CanAct(player)
	if not character or character ~= L.Character then return end
	local dir = a.Dir
	if not (Core.ValidVector(dir) and dir.Magnitude > 0.5 and dir.Magnitude < 1.5) then return end
	dir = dir.Unit
	local now = os.clock()
	L.AimAt = now                                    -- a report from a body that can act keeps the beam alive...
	-- ...but it only steers the beam if it is (roughly) where this body faces: the root turns to the camera's yaw in
	-- both views, and lags it by a ping on a fast flick -- then the claim is dropped, not the beam
	local f, d = flat(root.CFrame.LookVector), flat(dir)
	if f.Magnitude > 1e-3 and d.Magnitude > 1e-3 and (f.Unit - d.Unit).Magnitude > T.LightLance.AimSlack then
		Core.CountShot("rej_lance_aim")
		L.Claim = nil
		return
	end
	L.Aim = dir
	-- the claim: the body the client's own beam touches, checked like any shot
	local part, position = a.Part, a.Position
	if part == nil then
		L.Claim = nil
		return
	end
	if not validClaimPart(part, position) then return end
	local eye = aimOrigin(player, character, humanoid, root, a.Origin)
	if not eye then
		Core.CountShot("rej_origin")
		return
	end
	local rel = position - eye
	local along = rel:Dot(dir)
	local S = T.LightLance
	if along < -0.5 or along > S.Range + 2 or (rel - dir * along).Magnitude > S.HitSlack then
		Core.CountShot("rej_lance_offline")
		return
	end
	local reason, model, hum = checkClaim(part, position, character)
	if reason then
		Core.CountShot(reason)
		return
	end
	if not hum then
		L.Claim = nil                                                  -- the world: the beam stops on a wall
		return
	end
	if claimBlocked({ Origin = eye, Dir = dir, Character = character }, math.max(along, 0), position, model) then
		Core.CountShot("rej_lance_blocked")
		return
	end
	L.Claim = { Model = model, Humanoid = hum, At = now, Point = position }
end)

local function stepLance(player, L, dt)
	local character, _, root = Core.CanAct(player)
	if not character or character ~= L.Character or Core.Epoch(player) ~= L.Epoch then
		return stopLance(player, "Lost")
	end
	if not holds(player, "M1", "LightLance") then return stopLance(player, "Swapped") end
	if plants[player] or windups[player] then return stopLance(player, "Busy") end
	local S = T.LightLance
	local now = os.clock()
	if now - L.AimAt > 1.0 then return stopLance(player, "NoAim") end    -- the client stopped reporting
	local scale = timeScale()
	spendMana:Fire(player, S.ManaPerSecond * dt * scale)
	if (character:GetAttribute("Mana") or 0) <= 0.01 then return stopLance(player, "Empty") end
	-- the claimed target, while fresh and still in reach of the beam
	local eye = eyeOf(character, root)
	local c = L.Claim
	local victim = nil
	if c and now - c.At <= S.ClaimFresh and c.Humanoid.Parent and c.Humanoid.Health > 0 then
		local r = rootOf(c.Model)
		if r and (r.Position - eye).Magnitude <= S.Range + 4.5 then victim = c end
	end
	-- the claim's point was checked for cover, but a beam lasts: the server's own line to the BODY (its root, else its
	-- head) must be open too, asked at most every 0.1 s -- a claimed point in the open beside a hidden body deals nothing
	if victim then
		if L.LosModel ~= victim.Model or now - L.LosAt >= 0.1 then
			L.LosModel, L.LosAt = victim.Model, now
			local function blockedTo(part)
				if not part then return true end
				local rel = part.Position - eye
				local dist = rel.Magnitude
				return dist > 0.5 and Core.Blocked({ Origin = eye, Dir = rel / dist, Character = character }, dist, victim.Model)
			end
			L.LosOk = not (blockedTo(rootOf(victim.Model)) and blockedTo(victim.Model:FindFirstChild("Head")))
		end
		if not L.LosOk then victim = nil end
	end
	local frac = 0
	if victim then
		if L.RampModel ~= victim.Model or now - L.LastOn > S.RampGrace / scale then
			L.RampModel, L.RampStart = victim.Model, now
		end
		L.LastOn = now
		frac = math.clamp((now - L.RampStart) * scale / S.RampTime, 0, 1)
	end
	-- damage in ticks of Tick (scaled time)
	L.Acc += dt
	local tick = S.Tick / scale
	while L.Acc >= tick do
		L.Acc -= tick
		if victim and victim.Humanoid.Health > 0 then
			local dps = S.DpsStart + (S.DpsMax - S.DpsStart) * frac
			Core.DealDamage(player, victim.Humanoid, dps * S.Tick,
				{ Ranged = true, Beam = true, From = eye, Source = "LightLance" })
		end
	end
	-- the beam, to everyone (the placeholder draws it)
	if now - L.SentAt >= 1 / S.BroadcastRate then
		L.SentAt = now
		broadcast("RadiantLance", {
			Character = character, Dir = L.Aim, Victim = victim and victim.Model or nil,
			Point = victim and victim.Point or nil, Ramp = frac, Id = L.Id,
		})
	end
end

local function castLanceCharge(player, character, humanoid, root, payload, role)
	castLance(player, character, humanoid, root, payload, role)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: BLESSING
----------------------------------------------------------------------------------------------------
local function castBlessing(player, character, humanoid, root, payload, role)
	local B = T.Blessing
	local target = pickOnAim(player, character, root, payload.Target, B.Range + B.RangeSlack, B.LockRadius,
		function(model) return isAlly(player, model) end)
	local rec = nil
	if target then
		local hum = target:FindFirstChildOfClass("Humanoid")
		rec = hum and Status.Apply(player, hum, "Blessed", {})
	end
	if not rec then
		target = character
		rec = Status.Apply(player, humanoid, "Blessed", {})
	end
	if not rec then
		giveBack:Fire(player, role, true)                                  -- nothing took it: nothing spent
		return
	end
	broadcast("RadiantBlessing", { Character = character, Target = target, T0 = serverNow() })
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: OVERFLOW LIGHT
----------------------------------------------------------------------------------------------------
Status.OnLapse(function(humanoid, kind, rec)
	if kind ~= "Blessed" then return end
	local caster = rec.Caster
	if not (typeof(caster) == "Instance" and caster:IsA("Player") and caster.Parent) then return end
	if caster:GetAttribute("Element") ~= "Radiant" then return end               -- Overflow Light is Radiant's passive
	-- the caster was cleared since (back to the Hub, a round reset): a shield left behind converts nothing
	if rec.CasterEpoch ~= nil and Core.Epoch(caster) ~= rec.CasterEpoch then return end
	local amount = (rec.Amount or 0) * T.OverflowLight.ConvertPct
	if amount < T.OverflowLight.MinHeal then return end
	local healed = Core.Heal(caster, humanoid, amount, { Source = "OverflowLight" })
	if healed <= 0 then return end
	local cc = caster.Character
	if cc and cc.Parent then cc:SetAttribute("PassiveProc", serverNow()) end
	-- (2026-10-19, audit P5C-12) the CASTER's Blessing skin, named here: the helper would stamp the recipient's
	broadcast("RadiantOverflow", { Character = humanoid.Parent, Caster = caster.UserId, Amount = healed,
		Skin = SkinCatalog.Chosen(caster, "Blessing") })
end)

----------------------------------------------------------------------------------------------------
-- ULTIMATE: HALO
----------------------------------------------------------------------------------------------------
local function haloOn(player)
	local h = halos[player]
	return h ~= nil and player.Character == h.Character and Core.Epoch(player) == h.Epoch and serverNow() < h.Until
end

local function endHalo(player, reason)
	local h = halos[player]
	if not h then return end
	halos[player] = nil
	local c = h.Character
	if c and c.Parent and c:GetAttribute("HaloUntil") == h.Until then c:SetAttribute("HaloUntil", nil) end
	broadcast("RadiantHaloEnd", { Character = c, Caster = player.UserId, Reason = reason })
end

--- The windup's speed cap comes off -- only while it is still OURS (SpeedCapUlt is one slot shared by every kit).
local function releaseWindupHold(w)
	local c = w.Character
	if c and c.Parent and c:GetAttribute("RadiantHaloHold") == w.Stamp then
		c:SetAttribute("RadiantHaloHold", nil)
		if c:GetAttribute("SpeedCapUlt") == T.Halo.WindupSpeed then c:SetAttribute("SpeedCapUlt", nil) end
	end
end

local function cancelWindup(player, reason)
	local w = windups[player]
	if not w then return end
	windups[player] = nil
	releaseWindupHold(w)
	broadcast("RadiantHaloCancel", { Character = w.Character, Caster = player.UserId, Reason = reason })
end

local function openHalo(player, character)
	local now = serverNow()
	local h = { Character = character, Until = now + T.Halo.Duration / timeScale(), Epoch = Core.Epoch(player), Healed = 0 }
	halos[player] = h
	character:SetAttribute("HaloUntil", h.Until)
	broadcast("RadiantHaloStart", { Character = character, Caster = player.UserId, T0 = now, Until = h.Until })
end

local function castHalo(player, character, humanoid, root, payload, role)
	if plants[player] or (character:GetAttribute("SpeedCapUlt") ~= nil and character:GetAttribute("RadiantHaloHold") == nil) then
		-- planted (the staff is in the ground), or another kit's hold owns the one speed-cap slot (Aftershock's root): the
		-- charge SpellshotService just spent goes back
		character:SetAttribute("UltCharge", 1)
		return
	end
	endHalo(player, "Recast")
	cancelWindup(player, "Recast")
	stopLance(player, "Halo")
	local windup = (T.Halo.Windup or 0) / timeScale()
	if windup <= 0 then return openHalo(player, character) end
	local now = serverNow()
	local w = { Character = character, Stamp = now }
	windups[player] = w
	character:SetAttribute("SpeedCapUlt", T.Halo.WindupSpeed)
	character:SetAttribute("RadiantHaloHold", now)
	local epoch = Core.Epoch(player)
	broadcast("RadiantHaloCharge", { Character = character, Caster = player.UserId, T0 = now, Windup = windup })
	task.delay(windup, function()
		if windups[player] ~= w then return end
		windups[player] = nil
		releaseWindupHold(w)
		if Core.Epoch(player) ~= epoch or player.Character ~= character or not (humanoid.Parent and humanoid.Health > 0) then
			broadcast("RadiantHaloCancel", { Character = character, Caster = player.UserId, Reason = "Lost" })
			return
		end
		openHalo(player, character)
	end)
end

-- the conversion: every hit the caster lands ON A PLAYER while Halo is up heals by the health it actually removed.
-- Dummies, Bulwark Walls and decoys convert nothing (a dummy refills: beaming one would be free healing mid-duel).
Core.OnHitLanded(function(caster, humanoid, amount, info)
	if not (typeof(caster) == "Instance" and caster:IsA("Player")) then return end
	if not haloOn(caster) then return end
	local removed = type(info) == "table" and info.Removed or 0
	if type(removed) ~= "number" or removed <= 0 then return end
	local victim = humanoid.Parent and Players:GetPlayerFromCharacter(humanoid.Parent)
	if not victim or victim == caster then return end                              -- players only; never yourself
	local character = caster.Character
	if not character then return end
	local myHum = character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)
	if not (myHum and root and myHum.Health > 0) then return end
	local recipients = { myHum }
	for hum, model in pairs(Core.HumanoidsNear(root.Position, T.Halo.TeamRadius, character)) do
		if isAlly(caster, model) then recipients[#recipients + 1] = hum end
	end
	-- HealCap (the owner, 2026-09-29): one Halo heals at most this much, counted as health actually restored. Spent,
	-- the Halo ends (its ring comes down), so the tell never shows a Halo that no longer does anything.
	local h = halos[caster]
	local budget = (T.Halo.HealCap or math.huge) - h.Healed
	if budget <= 0 then return endHalo(caster, "Spent") end
	local share = math.min(removed * T.Halo.HealPct, budget) / #recipients
	for _, hum in ipairs(recipients) do
		h.Healed += Core.Heal(caster, hum, share, { Source = "Halo" })
	end
	-- Phase 5: the heal share's flicker (halo -> the allies it healed) on every client, at most every 0.25 s per Halo
	if #recipients > 1 and serverNow() - (h.ShareAt or -math.huge) >= 0.25 then
		h.ShareAt = serverNow()
		local models = {}
		for i = 2, #recipients do models[#models + 1] = recipients[i].Parent end
		broadcast("RadiantHaloShare", { Character = character, Caster = caster.UserId, Targets = models })
	end
	if h.Healed >= (T.Halo.HealCap or math.huge) - 1e-3 then endHalo(caster, "Spent") end
end)

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: POSITION TRADE
----------------------------------------------------------------------------------------------------
--- A body Position Trade may take: a player of the caster's own match (the opponent, or a teammate -- never someone in
--- another match on a shared map, nor a Solo Test stranger: audit P1-14), a training dummy, or an ally dummy of the
--- caster's (Core.IsAllyOf, 2026-09-30).
--- No other NPC is fair game.
local function swappable(player, model)
	-- (2026-10-19, audit P5C-05) an enemy's Decoy Double answers exactly as the body it copies would, so the free
	-- precheck can no longer tell the two apart; the trade itself then breaks it (castPositionTrade)
	local decoyOwner = model:GetAttribute("DecoyOwner")
	if decoyOwner then
		local owner = Players:GetPlayerByUserId(decoyOwner)
		return owner ~= nil and owner ~= player and owner.Character ~= nil and owner.Character ~= model
			and not Core.IsFriendly(player, model) and swappable(player, owner.Character)
	end
	if model:GetAttribute("Burrowed") then return false end
	local other = Players:GetPlayerFromCharacter(model)
	if other then
		local zone = player:GetAttribute("Zone")
		-- (2026-10-19, audit P1-14) and a MATCH: two players in no duel (Solo Test) are one party but may not hurt each
		-- other, and a server PivotTo of a stranger is griefing. sameParty already makes the two DuelMatch values equal
		return zone ~= "Hub" and other:GetAttribute("Zone") == zone and sameParty(player, other)
			and player:GetAttribute("DuelMatch") ~= nil
	end
	return model:GetAttribute("TrainingDummy") ~= nil or Core.IsAllyOf(player, model)
end

--- The swap's target, or nil. Both ends must stand over ground (FloorProbe): nobody is ever swapped out over a drop.
local function tradeTarget(player, character, root, aimAt)
	local P = T.PositionTrade
	if not floorBelow(character, root, P.FloorProbe) then return nil end
	return pickOnAim(player, character, root, aimAt, P.Range + P.RangeSlack, P.LockRadius, function(model)
		local r = rootOf(model)
		return swappable(player, model) and r ~= nil and floorBelow(model, r, P.FloorProbe)
	end)
end

do
	local check = spellFolder:FindFirstChild("Precheck_PositionTrade")
	if not check then
		check = Instance.new("BindableFunction")
		check.Name = "Precheck_PositionTrade"
		check.Parent = spellFolder
	end
	check.OnInvoke = function(player, role, payload)
		local character, _, root = Core.CanAct(player)
		if not character or plants[player] or trades[player] then return false end
		return tradeTarget(player, character, root, type(payload) == "table" and payload.Target or nil) ~= nil
	end
end

-- 2026-10-23: an ANCHORED range dummy goes back to where it stood TRADE_DUMMY_RETURN s after the swap, once no player
-- stands on that spot (Cyclone's DummyReturn rule); before, it stayed where the trade left it for the session
local TRADE_DUMMY_RETURN = 3
local dummyHome = setmetatable({}, { __mode = "k" })   -- [dummy] = { Pivot, At (its root), Token }, from its FIRST trade
local function returnTradedDummy(model)
	local entry = dummyHome[model]
	if not entry then return end
	entry.Token += 1
	local token = entry.Token
	task.delay(TRADE_DUMMY_RETURN, function()
		while dummyHome[model] == entry and entry.Token == token and model.Parent do
			local busy = false
			for _, pl in ipairs(Players:GetPlayers()) do
				local r = pl.Character and rootOf(pl.Character)
				if r and (r.Position - entry.At).Magnitude < 4 then busy = true end
			end
			if not busy then
				dummyHome[model] = nil
				model:PivotTo(entry.Pivot)
				return
			end
			task.wait(0.5)
		end
	end)
end

local function castPositionTrade(player, character, humanoid, root, payload, role)
	local target = tradeTarget(player, character, root, payload.Target)
	if not target or plants[player] or trades[player] then
		giveBack:Fire(player, role, true)
		return
	end
	local tRoot = rootOf(target)
	local tHum = target:FindFirstChildOfClass("Humanoid")
	if not (tRoot and tHum) then
		giveBack:Fire(player, role, true)
		return
	end
	local dissolve = T.PositionTrade.DissolveTime / timeScale()
	local epoch = Core.Epoch(player)
	local tr = { Character = character, Epoch = epoch }
	trades[player] = tr
	broadcast("RadiantTradeOut", { Character = character, Other = target, From = root.Position, To = tRoot.Position,
		T0 = serverNow(), Dissolve = dissolve })
	task.delay(dissolve, function()
		if trades[player] ~= tr then return end
		trades[player] = nil
		-- (2026-10-19, audit P5C-05) the trade reached an enemy's Decoy Double: the illusion fails (UmbraHandler breaks it
		-- on DecoyTraded and the Tell lights), nobody moves, and the cast stays spent -- the price the real body's swap paid
		if target:GetAttribute("DecoyOwner") then
			if Core.Epoch(player) == epoch and player.Character == character and humanoid.Parent and humanoid.Health > 0
				and target.Parent then
				target:SetAttribute("DecoyTraded", true)
			end
			broadcast("RadiantTradeIn", { Character = character, Other = target, Cancelled = true })
			return
		end
		if Core.Epoch(player) ~= epoch or player.Character ~= character or not (humanoid.Parent and humanoid.Health > 0)
			or not (target.Parent and tHum.Health > 0 and tRoot.Parent) or not swappable(player, target) then
			broadcast("RadiantTradeIn", { Character = character, Other = target, Cancelled = true })
			return
		end
		-- the ground again, at the swap itself (a jump off an edge during the dissolve): no ground, no swap, nothing spent
		local P = T.PositionTrade
		if not (floorBelow(character, root, P.FloorProbe) and floorBelow(target, tRoot, P.FloorProbe)) then
			broadcast("RadiantTradeIn", { Character = character, Other = target, Cancelled = true })
			giveBack:Fire(player, role, true)
			return
		end
		-- where each stands NOW (the other may have moved during the dissolve), each keeping its own facing
		local a, b = root.CFrame, tRoot.CFrame
		local aTo = CFrame.new(b.Position) * (a - a.Position)
		local bTo = CFrame.new(a.Position) * (b - b.Position)
		-- each model's pivot keeps its offset from its root (a character's pivot IS its root; a dummy's may not be)
		-- (2026-10-19, audit P1-03) both are server moves: the movement guard lets each body be (a dummy is not guarded)
		Core.AllowMove(character)
		Core.AllowMove(target)
		if tRoot.Anchored and target:GetAttribute("TrainingDummy") ~= nil and not dummyHome[target] then   -- (2026-10-23)
			dummyHome[target] = { Pivot = target:GetPivot(), At = tRoot.Position, Token = 0 }
		end
		character:PivotTo(aTo * (root.CFrame:Inverse() * character:GetPivot()))
		target:PivotTo(bTo * (tRoot.CFrame:Inverse() * target:GetPivot()))
		root.AssemblyLinearVelocity = Vector3.zero
		if not tRoot.Anchored then tRoot.AssemblyLinearVelocity = Vector3.zero end
		broadcast("RadiantTradeIn", { Character = character, Other = target, A = aTo.Position, B = bTo.Position,
			T0 = serverNow() })
		returnTradedDummy(target)
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: BENEDICTION
----------------------------------------------------------------------------------------------------
--- The cooldown from NOW (the channel's end): the release had it stamped already when the key came up before the
--- channel could end (a tap plants and pulses once after it), so it is stamped again here -- SpellshotService's rule
--- (serverNow + the row's Cooldown; none with DevNoCooldowns).
local function stampCooldown(p)
	local c = p.Character
	if not (c and c.Parent and p.Role) then return end
	local row = VFXLibrary.AbilityById.Benediction
	local cd = (row and row.Cooldown) or T.Benediction.Cooldown
	c:SetAttribute("CDTotal_" .. p.Role, cd)
	c:SetAttribute("CD_" .. p.Role, c:GetAttribute("DevNoCooldowns") and 0 or (serverNow() + cd))
end

local function endPlant(player, reason)
	local p = plants[player]
	if not p then return end
	plants[player] = nil
	local c = p.Character
	if c and c.Parent and c:GetAttribute("RadiantPlant") == p.Stamp then
		c:SetAttribute("RadiantPlant", nil)
		if c:GetAttribute("SpeedCapUlt") == 0 then c:SetAttribute("SpeedCapUlt", nil) end
	end
	if jumpLock and p.Humanoid.Parent then jumpLock:Fire(p.Humanoid, "RadiantPlant", false) end
	broadcast("RadiantBenedictionEnd", { Character = c, Caster = player.UserId, Reason = reason, N = p.Pulses })
	-- the cooldown starts now: a key still down lets go through SpellshotService (ReleaseHold: Holding_ clears, CD_ is
	-- stamped, and the Release it fires back finds no plant); a key already up is re-stamped from here
	if p.Role and c and c.Parent then
		if c:GetAttribute("Holding_" .. p.Role) == "Benediction" and releaseHold then
			releaseHold:Fire(player, p.Role)
		elseif p.Released then
			stampCooldown(p)
		end
	end
end

--- The staff can go into the ground: nothing of Radiant's already running, on the ground (FloorProbe), and the one
--- speed-cap slot free (another kit's hold -- Aftershock's root -- would fight the plant's root over it).
local function mayPlant(player, character, root)
	return not plants[player] and not windups[player] and not trades[player]
		and character:GetAttribute("SpeedCapUlt") == nil
		and floorBelow(character, root, T.Benediction.FloorProbe)
end

do
	local check = spellFolder:FindFirstChild("Precheck_Benediction")
	if not check then
		check = Instance.new("BindableFunction")
		check.Name = "Precheck_Benediction"
		check.Parent = spellFolder
	end
	check.OnInvoke = function(player, role, payload)
		local character, _, root = Core.CanAct(player)
		return character ~= nil and mayPlant(player, character, root)
	end
end

local function castBenediction(player, character, humanoid, root, payload, role)
	-- the key came up (SpellshotService's endHold): the channel ends now -- or, a tap, after its first pulse (stepPlant)
	if payload.Phase == "Release" then
		local p = plants[player]
		if not p or p.Character ~= character then return end
		p.Released = true
		if p.Pulses >= 1 then endPlant(player, "Released") end
		return
	end
	if payload.Phase ~= nil and payload.Phase ~= "Start" then return end
	if not mayPlant(player, character, root) then
		giveBack:Fire(player, role, true)
		return
	end
	stopLance(player, "Planted")
	local B = T.Benediction
	local scale = timeScale()
	local now = serverNow()
	local interval = (B.PulseEvery or 0.5) / scale
	local windup = math.max(0, B.WindUp or 0) / scale
	local t0 = now + windup                                              -- the staff hits the ground
	local row = VFXLibrary.AbilityById.Benediction
	local p = { Character = character, Humanoid = humanoid, Epoch = Core.Epoch(player), Stamp = now, At = root.Position,
		T0 = t0, Pulses = 0, Next = t0 + interval, Interval = interval, Role = role, FloorAt = now,
		-- a row that is not Held has no release coming: it plants and pulses once, as a tap does
		Released = not (row and row.Held),
		MaxUntil = (B.MaxChannel or 0) > 0 and (t0 + B.MaxChannel / scale) or nil }
	plants[player] = p
	character:SetAttribute("SpeedCapUlt", 0)
	character:SetAttribute("RadiantPlant", now)
	if jumpLock then jumpLock:Fire(humanoid, "RadiantPlant", true) end
	root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	-- Phase 5: the allies in range at the plant, so every client draws their Bond threads on with the range ring
	local allies = {}
	for _, model in pairs(Core.HumanoidsNear(root.Position, B.Radius, character)) do
		if isAlly(player, model) then allies[#allies + 1] = model end
	end
	-- T0 = the plant (press + WindUp), WindUp and Every in real seconds; no Until: the channel is open until the End
	broadcast("RadiantBenedictionStart", { Character = character, Caster = player.UserId, At = root.Position, T0 = t0,
		TPress = now, WindUp = windup, Every = interval, Allies = allies })
end

local function pulseBenediction(player, p)
	local B = T.Benediction
	local character = p.Character
	local targets = {}
	for hum, model in pairs(Core.HumanoidsNear(p.At, B.Radius, character)) do
		if isAlly(player, model) then
			Core.Heal(player, hum, B.HealPerPulse, { Source = "Benediction" })
			targets[#targets + 1] = model                                    -- an ally in range counts, healed to full or not
		end
	end
	local self = #targets == 0
	if self then Core.Heal(player, p.Humanoid, B.HealPerPulse, { Source = "Benediction" }) end
	broadcast("RadiantBenedictionPulse", { Character = character, Caster = player.UserId, At = p.At, Targets = targets,
		Self = self, N = p.Pulses })
end

local function stepPlant(player, p, now, dt)
	if Core.Epoch(player) ~= p.Epoch or player.Character ~= p.Character or not (p.Humanoid.Parent and p.Humanoid.Health > 0) then
		return endPlant(player, "Lost")
	end
	-- an interrupt (Undertow, an Aftershock strike: InterruptedUntil) ends the channel, the wind-up included: its
	-- ReleaseHold only marks a plant that has not pulsed yet Released, a tap, which still healed once up to 1 s after
	-- the press (2026-09-30 review). endPlant restamps the cooldown.
	if serverNow() < (p.Character:GetAttribute("InterruptedUntil") or 0) then return endPlant(player, "Interrupted") end
	-- the caster is anchored to the planted staff: moved away from it (knocked, swapped, a client that walks anyway),
	-- the channel ends -- no pulse follows the caster around
	local r = rootOf(p.Character)
	if not r or flat(r.Position - p.At).Magnitude > T.Benediction.LeashRadius then return endPlant(player, "Moved") end
	-- the root is ours while planted: another kit's release that cleared the shared cap does not free the caster
	if p.Character:GetAttribute("RadiantPlant") == p.Stamp and p.Character:GetAttribute("SpeedCapUlt") ~= 0 then
		p.Character:SetAttribute("SpeedCapUlt", 0)
	end
	-- the ground under the caster, now and then (a platform gone, a launch the leash has not caught yet)
	if now >= p.FloorAt then
		p.FloorAt = now + 0.2
		if not floorBelow(p.Character, r, T.Benediction.FloorProbe) then return endPlant(player, "Floor") end
	end
	if now < p.T0 then return end                                        -- the wind-up: rooted, nothing drains yet
	local B = T.Benediction
	if (B.ManaPerSecond or 0) > 0 then spendMana:Fire(player, B.ManaPerSecond * dt * timeScale()) end
	while now >= p.Next and plants[player] == p do
		p.Pulses += 1
		pulseBenediction(player, p)
		p.Next += p.Interval
	end
	if plants[player] ~= p or p.Pulses < 1 then return end               -- a tap still gets its first pulse
	if p.Released then return endPlant(player, "Released") end
	if (p.Character:GetAttribute("Mana") or 0) <= 0.01 then return endPlant(player, "Empty") end
	if p.MaxUntil and now >= p.MaxUntil then return endPlant(player, "Max") end
end

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
local casts = {
	LightLance = castLanceCharge,                       -- the M1's click: the channel's start (the rest is its remote)
	Blessing = castBlessing,
	PositionTrade = castPositionTrade,
	Benediction = castBenediction,
	Halo = castHalo,
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
-- the Heartbeat: beams, Halo's end, Benediction's pulses, the heal readout
----------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	if next(healSums) ~= nil then flushHeals(false) end
	if next(lances) == nil and next(halos) == nil and next(plants) == nil then return end
	for player, L in pairs(lances) do
		local ok, err = pcall(stepLance, player, L, dt)
		if not ok then
			warnOnce("steplance", "Light Lance step failed: " .. tostring(err))
			stopLance(player, "Error")
		end
	end
	for player in pairs(halos) do
		if not haloOn(player) then endHalo(player, "Expired") end
	end
	local now = serverNow()
	for player, p in pairs(plants) do
		local ok, err = pcall(stepPlant, player, p, now, dt)
		if not ok then
			warnOnce("stepplant", "Benediction step failed: " .. tostring(err))
			endPlant(player, "Error")
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
local function endAll(player, reason)
	stopLance(player, reason)
	cancelWindup(player, reason)
	endHalo(player, reason)
	endPlant(player, reason)
	trades[player] = nil
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
	aimBuckets[player] = nil
	earlyStops[player] = nil
end)

-- Leaving the arena, or a duel round being reset (CombatCore.ClearPlayer): everything this player has running ends.
Core.OnClear(function(player)
	endAll(player, "Clear")
end)

print("[RadiantHandler] ready")
