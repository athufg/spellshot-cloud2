--[[
	AquaHandler  (Script)  ->  ServerScriptService/AquaHandler

	The gameplay side of AQUA, the first post-launch Element (manual v0.14, Section 2; build prompt
	Opus55_Aqua_Element_Build.md, Phase 2, 2026-09-24). AquaFX draws it; AquaClient is its client half. Every number is
	AquaTuning's (shared with the clients) and every one is a stand-in unless marked there.

	WHERE CASTS COME FROM: SpellshotService checks and pays for the cast, then fires PerformCast; each kit's script acts
	only on its own ability Ids. Damage goes through CombatCore, so Ultimate charge, shields, Mark and Blessing all apply
	as for every other kit.

	  M1   RIPTIDE   a crescent of whitewater surged along the floor, straight down the aim. The shooter's client runs the
	                 wave and reports each body it passes through (RiptideRelease / RiptideHit, Wind Blade's arrangement:
	                 the release is rate-checked and its origin held to the server's body, each claim to the wave's line,
	                 its width, the time it could have taken to get there and the crest's height -- a body whose feet are
	                 over the crest has jumped it). It pierces: each body once, up to Pierce. It lays a wet streak.
	                 THE WET HOOK: every Riptide hit that lands ends in onRiptideHit below, and fires the BindableEvent
	                 ReplicatedStorage.Spellshot.AquaRiptideHit (caster, humanoid, info). The Wet status (a separate build)
	                 hooks there; nothing here applies a status.
	  PRIMARY  UNDERTOW  (the owner's redo, 2026-09-25: "in front of your face", "stays in front of you") the caster's hand
	                 draws a whirlpool disc in the air DiscDistance in front of the eye. At SnapTime every enemy in front
	                 (within Reach, inside ConeAngle of the aim, not behind a wall) is pulled to the floor under the disc --
	                 right up to the caster -- and INTERRUPTED: any held ability ends (its
	                 cooldown starts) and casting is refused for InterruptTime (InterruptedUntil, which SpellshotService's
	                 gate and CombatCore.CanAct honour). A caught player's own client moves its body (AquaPull, sent to
	                 them alone; Cyclone's arrangement); an unanchored dummy is moved here. Leaves a wet puddle.
	  PASSIVE  RIDING THE CURRENT  every Aqua ability lays wet ground for WetLife. The caster standing on their OWN wet
	                 ground is faster (MoveSpeedMult, which SpellshotService and MovementController already apply); an
	                 enemy on it SLIPS: SlipUntil (server time) on their body, which their own client turns into low
	                 traction (AquaClient) -- the owner: "very hard to walk... tough to redirect yourself but you still can".
	  ULTIMATE LEVIATHAN'S MAW  pointed: at the crosshair's ground spot the flood rises and a ring of wave-walls closes
	                 overhead into a glass tank (Radius). The walls are every client's own local copy, solid, so the
	                 bodies inside cannot leave (a client moves its own body, and collides with its own walls). Who is
	                 inside at CloseTime is trapped, and one shark circles for each (the owner, 2026-09-25); at LungeTime
	                 EVERY trapped enemy still inside gets its own shark (up to MaxSharks, nearest the centre first), and at
	                 BiteTime each is bitten separately (BiteDamage, thrown up); anyone past the cap takes SurgeDamage. The floor is wet (enemies slip) until WetAfter past the release.
	  TECHNIQUE TWIN TIDE  a lane at the crosshair, along the aim: two walls StartGap apart close on its centre line
	                 over CloseTime (each client's own solid copy again, Height tall and not wall-runnable). Whoever is
	                 within CrushHalfWidth of the line when they meet is crushed (CrushDamage, thrown up). Wet lane.
	  TECHNIQUE SIDEARM  HELD (SpellshotService's held path; the owner's rework, 2026-09-25): the press pays TapCost and
	                 draws the gun; its first shot leaves DrawTime later (a tap is that one shot). Held on, it rapid-fires
	                 FireRate bullets a second, each paying BulletCost here (SpendMana). Every shot is its own message
	                 (SidearmShot: the draw, the rate and the mana checked), every hit is reported and checked like
	                 Fireball's; the release only ends the hold. Every bullet that lands knocks its target back (2026-09-25).

	Server -> client (AbilityFX -> AquaClient): ("VFX", kind, data) on IceAbilityRemote -- Aqua* kinds to everyone, and
	AquaPull / AquaKnock / AquaInterrupted to the one player they move.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local A = require(iceFolder:WaitForChild("AquaTuning"))
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local performCast = spellFolder:WaitForChild("PerformCast")
local releaseHold = spellFolder:WaitForChild("ReleaseHold")
local spendMana = spellFolder:WaitForChild("SpendMana")
local Core = require(script.Parent:WaitForChild("CombatCore"))

local remote = Core.Remote
local broadcast = Core.Broadcast

-- THE WET HOOK (see the header): other server scripts listen here for every Riptide hit that lands.
local riptideHitEvent = spellFolder:FindFirstChild("AquaRiptideHit")
if not riptideHitEvent then
	riptideHitEvent = Instance.new("BindableEvent")
	riptideHitEvent.Name = "AquaRiptideHit"
	riptideHitEvent.Parent = spellFolder
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function holds(player, role, id)
	local a = VFXLibrary.AbilityFor(player, role)
	return a ~= nil and a.Id == id
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function tell(player, kind, data)
	pcall(function() remote:FireClient(player, "VFX", kind, data) end)
end

--- A ray that sees through every body (a character, a training dummy) but not a Bulwark Wall, which is cover.
local function castThroughBodies(origin, direction, params)
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		local mdl = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (mdl and mdl:FindFirstChildOfClass("Humanoid")) or mdl:GetAttribute("WallOwner") then return hit end
		params:AddToFilter(mdl)
	end
	return nil
end

local function worldParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	local fx = Core.FxFolder()
	if fx then exclude[#exclude + 1] = fx end
	if extra then exclude[#exclude + 1] = extra end
	params.FilterDescendantsInstances = exclude
	return params
end

--- The floor under `point` (from a little above it), ignoring bodies and the FX folder; nil over nothing.
local function groundBelow(point, reach)
	local hit = castThroughBodies(point + Vector3.new(0, 6, 0), Vector3.new(0, -(reach or 40), 0), worldParams())
	return hit and hit.Position or nil
end

--- A spot the caster aimed at, held to `range` and put down on the floor.
local function aimedGround(root, target, range)
	local spot = Core.ClampTarget(root, target, range)
	return groundBelow(spot, 60) or spot
end

local function feetY(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root then return nil end
	return root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 2)
end

--- A dummy the server simulates is moved here; a body a client simulates is that client's (it is sent a message).
local function serverOwned(root)
	if root.Anchored then return false end
	local ok, owner = pcall(function() return root:GetNetworkOwner() end)
	return ok and owner == nil
end

local function moveDummy(root, velocity, seconds, forcePerMass)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AquaMoveAttachment"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "AquaMove"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * forcePerMass
	mover.MaxAxesForce = Vector3.new(force, force, force)
	mover.VectorVelocity = velocity
	mover.Parent = attachment
	attachment.Parent = root
	task.delay(seconds, function() attachment:Destroy() end)
end

--- A range dummy the server holds fixed (Anchored) takes no mover: it is CARRIED by its pivot along `path(t)` (an offset
--- from where it stood) for `seconds`, then put back where it stood `back` seconds later -- Earthen Tomb's arrangement
--- (TerraHandler.hold), so the range shows a pull or a throw without the dummy wandering off its spot.
local carried = setmetatable({}, { __mode = "k" })
local function carryDummy(model, path, seconds, back)
	if carried[model] then return end
	local home = model:GetPivot()
	carried[model] = true
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if not model.Parent then
			conn:Disconnect()
			carried[model] = nil
			return
		end
		if t >= seconds + back then
			conn:Disconnect()
			model:PivotTo(home)
			carried[model] = nil
			return
		end
		model:PivotTo(home + path(math.min(t, seconds)))
	end)
end

--- Throw a body: its own client if it is a player's, the server's mover if it is a dummy.
local function launch(model, velocity)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then return end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		tell(victim, "AquaKnock", { Velocity = velocity, Until = serverNow() + A.Sidearm.KnockTime })
	elseif serverOwned(root) then
		moveDummy(root, velocity, A.Sidearm.KnockTime, A.Sidearm.KnockForcePerMass)
	elseif root.Anchored then
		-- a range dummy: flown on the throw's arc until it comes back down to where it stood
		local g = workspace.Gravity
		local air = math.clamp(2 * math.max(velocity.Y, 0) / g, 0.35, 1.4)
		carryDummy(model, function(t)
			return Vector3.new(velocity.X * t, math.max(0, velocity.Y * t - 0.5 * g * t * t), velocity.Z * t)
		end, air, 0.6)
	end
end

--- The Sidearm knock's speed UP (2026-10-08): sized at workspace.Gravity, never written as studs/s, by the TIME it keeps
--- a body off the ground (Sidearm.KnockAir) -- not by its height, as today's first fix had it: the tuned height at this
--- place's gravity is 0.84 s in the air, longer than the gap between bullets (1 / FireRate = 0.625 s), so a held Sidearm
--- caught the body still up and lifted it again, bullet after bullet. The mover holds the speed for KnockTime (h), the
--- body coasts up speed / g more and falls from speed x h + speed^2 / 2g: air = h + speed / g + sqrt(2 x apex / g),
--- which solves to speed = g x (air - h)^2 / (2 x air). One velocity, whichever way launch() then throws it (a player's
--- own client, the server's mover, a range dummy's arc).
local function sidearmKnockUp()
	local g, h, air = workspace.Gravity, A.Sidearm.KnockTime, A.Sidearm.KnockAir or 0.55   -- (or: a tuning copy without it)
	if not (g > 0) then return 16 end                         -- a zero-gravity test place: a sane pop, not a divide
	if not (air > h) then return 0 end                        -- no time in the air past the mover's own hold: no pop
	return g * (air - h) ^ 2 / (2 * air)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: RIDING THE CURRENT -- the wet ground every Aqua ability lays
----------------------------------------------------------------------------------------------------
-- A zone is a STRIP (a to b, HalfWidth either side; a Riptide streak is laid at the wave's speed, so a point on it is
-- wet from when the wave passed it) or a DISK. Both dry WetLife after they were laid (a disk: at Dry).
local zones = {}
local riding = {}                                      -- [player] = os.clock() the buff holds until
local slipImmune = setmetatable({}, { __mode = "k" })  -- [humanoid] = os.clock() it can slip again

local function addStrip(owner, a, b, half, speed, y, life)
	local d = flat(b - a)
	local len = d.Magnitude
	if len < 0.5 then return end
	local now = os.clock()
	table.insert(zones, {
		Owner = owner, Kind = "Strip", A = a, Dir = d / len, Len = len, Half = half, Y = y,
		T0 = now, Speed = speed, Life = life or A.Current.WetLife,
		Mid = a + d / 2, Reach = len / 2 + half + 3,
		Dry = now + len / speed + (life or A.Current.WetLife),
	})
end

local function addDisk(owner, center, radius, from, dry)
	table.insert(zones, {
		Owner = owner, Kind = "Disk", Center = center, Radius = radius, Y = center.Y,
		From = from, Dry = dry, Mid = center, Reach = radius + 3,
	})
end

--- Is this body standing on the zone right now: over it, wet at that point, and on the floor rather than above it.
local function onZone(z, model, now)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then return false end
	local p = root.Position
	if z.Kind == "Strip" then
		local rel = flat(p - z.A)
		local s = rel:Dot(z.Dir)
		if s < 0 or s > z.Len then return false end
		if (rel - z.Dir * s).Magnitude > z.Half then return false end
		local wetAt = z.T0 + s / z.Speed
		if now < wetAt or now > wetAt + z.Life then return false end
	else
		if now < z.From or now > z.Dry then return false end
		if flat(p - z.Center).Magnitude > z.Radius then return false end
	end
	local feet = feetY(model)
	if not feet then return false end
	-- on the floor under it (a jump over the wet, or a floor above or below, is not on it)
	local ground = groundBelow(Vector3.new(p.X, feet + 1, p.Z), 10)
	if not ground then return false end
	if feet - ground.Y > A.Current.ContactAbove then return false end
	return math.abs(ground.Y - z.Y) < 6
end

local function setRiding(player, on)
	local c = player.Character
	if not c then return end
	if (c:GetAttribute("AquaRiding") == true) == on then return end
	c:SetAttribute("AquaRiding", on or nil)
	c:SetAttribute("PassiveActive", on)
	c:SetAttribute("MoveSpeedMult", on and (1 + A.Current.SpeedBonus) or nil)
end

local function slip(humanoid, model, now)
	if now < (slipImmune[humanoid] or 0) then return end
	slipImmune[humanoid] = now + A.Current.SlipTime + A.Current.SlipImmunity
	model:SetAttribute("SlipUntil", serverNow() + A.Current.SlipTime)
end

local nextTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextTick then return end
	nextTick = now + A.Current.Tick
	for i = #zones, 1, -1 do
		if now > zones[i].Dry or not zones[i].Owner.Parent then table.remove(zones, i) end
	end
	local onOwn = {}
	for _, z in ipairs(zones) do
		local owner = z.Owner
		local oc = owner.Character
		if oc and owner:GetAttribute("Element") == "Aqua" and not onOwn[owner] and onZone(z, oc, now) then
			onOwn[owner] = true
		end
		for humanoid, model in pairs(Core.HumanoidsNear(z.Mid, z.Reach, oc)) do
			if not Core.IsWall(model) and not Core.IsFriendly(owner, model) and onZone(z, model, now) then
				slip(humanoid, model, now)
			end
		end
	end
	for owner in pairs(onOwn) do
		riding[owner] = now + A.Current.OwnerGrace
		setRiding(owner, true)
	end
	for owner, untilT in pairs(riding) do
		if not onOwn[owner] and now > untilT then
			riding[owner] = nil
			setRiding(owner, false)
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- M1: RIPTIDE
----------------------------------------------------------------------------------------------------
--- Every Riptide hit that lands ends here. THE WET HOOK: the Wet status build applies its stack from the event.
local function onRiptideHit(caster, humanoid, model, info)
	riptideHitEvent:Fire(caster, humanoid, { Model = model, Position = info.Position, Shot = info.Shot })
end

-- The click relays the wave, so every client can run it from the same spot along the same line.
local function castRiptide(player, character, humanoid, root, payload)
	local dir = payload.Dir
	if Core.ValidVector(dir) and flat(dir).Magnitude > 0.1 then
		dir = flat(dir).Unit
	else
		dir = flat(root.CFrame.LookVector).Unit
	end
	broadcast("AquaRiptide", {
		Character = character, Origin = root.Position, Dir = dir, T0 = serverNow(),
		Side = (payload.Side == "L") and "L" or "R",
	})
end

local shots = {}             -- [player] = { [id] = { Origin, Dir, At, Life, End, Character, Hit = {[model] = true}, Count } }
local buckets = {}           -- [player] = { Tokens, At }: the fire-rate check

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "RiptideRelease" or type(a) ~= "table" then return end
	if player:GetAttribute("Zone") == "Hub" then return end
	if not holds(player, "M1", "Riptide") then return end
	local character, humanoid, root = Core.CanAct(player)
	if not character then return end
	local origin, dir, id = a.Origin, a.Dir, a.Id
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or type(id) ~= "number" or flat(dir).Magnitude < 0.1 then
		return
	end
	local R = A.Riptide
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { Tokens = 2, At = now }
		buckets[player] = b
	end
	local interval = R.FireInterval * 0.92 / VFXLibrary.ShotTimeScale()
	b.Tokens = math.min(3, b.Tokens + (now - b.At) / interval)
	b.At = now
	if b.Tokens < 1 then
		Core.CountShot("rej_rate")
		return
	end
	b.Tokens -= 1
	-- the wave starts at the shooter's own body, allowing for the server's copy of a moving player trailing the real one
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	local speed = math.max(root.AssemblyLinearVelocity.Magnitude, humanoid.WalkSpeed)
	if (origin - root.Position).Magnitude > 6 + speed * (0.35 + ping) then
		Core.CountShot("rej_origin")
		return
	end
	dir = flat(dir).Unit
	-- where the wave breaks: the first solid thing on its line at waist height, on the server's world
	local shot = { Origin = origin, Dir = dir, Character = character }
	local reach = R.Range
	do
		-- (from StepUp over the waist: the wave climbs steps and ramps a flat ray at the waist would stop on)
		local hit = castThroughBodies(origin + Vector3.new(0, R.StepUp, 0), dir * R.Range, worldParams(character))
		if hit then reach = (hit.Position - origin):Dot(dir) end
	end
	local mine = shots[player]
	if not mine then
		mine = {}
		shots[player] = mine
	end
	for oldId, s in pairs(mine) do
		if now - s.At > s.Life then mine[oldId] = nil end
	end
	shot.At, shot.Hit, shot.Count, shot.End = now, {}, 0, reach
	shot.Life = R.Range / (R.Speed * VFXLibrary.ShotTimeScale()) + 1.0
	mine[id] = shot
	Core.CountShot("release")
	-- the wet streak it lays (Riding the Current), at the wave's own pace
	local floor = groundBelow(origin, 12)
	if floor then
		local a0 = Vector3.new(origin.X, floor.Y, origin.Z) + dir * R.StartAhead
		addStrip(player, a0, a0 + dir * math.max(0, reach - R.StartAhead), R.TrailWidth / 2, R.Speed, floor.Y)
	end
end)

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "RiptideHit" or type(a) ~= "table" then return end
	local mine = shots[player]
	local shot = mine and type(a.Id) == "number" and mine[a.Id]
	if not shot then
		Core.CountShot("rej_noshot")
		return
	end
	local R = A.Riptide
	local now = os.clock()
	if now - shot.At > shot.Life then
		mine[a.Id] = nil
		Core.CountShot("rej_late")
		return
	end
	local part, position = a.Part, a.Position
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
		or not Core.ValidVector(position) then
		Core.CountShot("rej_badpart")
		return
	end
	-- inside the crescent's path, flat: along the line, no wider than the wave (and its slack) ...
	local rel = flat(position - shot.Origin)
	local along = rel:Dot(shot.Dir)
	if along < -1 or along > math.min(R.Range, shot.End) + 2 or (rel - shot.Dir * along).Magnitude > R.Width / 2 + R.HitSlack then
		Core.CountShot("rej_offline")
		return
	end
	-- ... and no sooner than the wave could have surged there
	if now - shot.At < along / (R.Speed * VFXLibrary.ShotTimeScale()) - 0.25 then
		Core.CountShot("rej_early")
		return
	end
	local reason, model, humanoid = Core.CheckTarget(part, position, shot.Character)
	if reason == "rej_moved" then
		local lp = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2 + Vector3.new(1, 1, 1)
		if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then
			reason = nil
			model = part:FindFirstAncestorOfClass("Model")
			humanoid = model and model:FindFirstChildOfClass("Humanoid")
		end
	end
	if reason then
		Core.CountShot(reason)
		return
	end
	if not humanoid then
		Core.CountShot("hit_world")
		return                                      -- the wave breaks on the world client-side; nothing to apply here
	end
	if shot.Hit[model] then
		Core.CountShot("rej_repeat")
		return
	end
	-- THE CREST: a body whose feet are over it has jumped the wave
	local feet = feetY(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local ground = root and groundBelow(Vector3.new(root.Position.X, (feet or root.Position.Y) + 1, root.Position.Z), 12)
	if feet and ground and feet - ground.Y > R.Height + R.HeightSlack then
		Core.CountShot("rej_over")
		return
	end
	Core.CountShot("hit")
	Core.CountShot("hit_char")
	shot.Hit[model] = true
	shot.Count += 1
	if shot.Count >= R.Pierce then mine[a.Id] = nil end
	if Core.DealDamage(player, humanoid, R.Damage, { Ranged = true, From = shot.Origin, Source = "Riptide" }) then
		onRiptideHit(player, humanoid, model, { Position = position, Shot = a.Id })
	else
		Core.CountShot("rej_friendly")
	end
end)

----------------------------------------------------------------------------------------------------
-- PRIMARY: UNDERTOW
----------------------------------------------------------------------------------------------------
local ROLES = { "M1", "Primary", "Mobility", "Defense", "Ultimate" }

--- End whatever the body is holding (its cooldown starts, as a release would start it) and refuse casts a moment.
local function interrupt(victim)
	local c = victim.Character
	if not c then return end
	for _, role in ipairs(ROLES) do
		if c:GetAttribute("Holding_" .. role) then releaseHold:Fire(victim, role) end
	end
	local untilT = serverNow() + A.Undertow.InterruptTime
	c:SetAttribute("InterruptedUntil", untilT)
	tell(victim, "AquaInterrupted", { Until = untilT })
end

--- The disc's frame, from the caster's eye and aim: it stands up DiscDistance in front of the eye (tilting with the aim
--- only up to MaxPitch), and `pullTo` is the floor under it -- where the caught are pulled, right in front of the caster.
local function undertowFrame(character, root, target)
	local U = A.Undertow
	local head = character:FindFirstChild("Head")
	local eye = head and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local look = root.CFrame.LookVector
	if Core.ValidVector(target) and (target - eye).Magnitude > 0.5 then look = (target - eye).Unit end
	local f = flat(look)
	if f.Magnitude < 0.05 then f = flat(root.CFrame.LookVector) end
	f = f.Unit
	local maxP = math.rad(U.MaxPitch)
	local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -maxP, maxP)
	look = f * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
	local center = eye + look * U.DiscDistance - Vector3.new(0, U.DiscDrop, 0)
	local pullTo = groundBelow(center, 30) or Vector3.new(center.X, root.Position.Y - 3, center.Z)
	return eye, look, center, pullTo
end

--- The snap: every enemy in FRONT of the caster -- within Reach along the aim, inside ConeAngle of it, and not behind a
--- wall -- is pulled to the floor under the disc (the owner: "stays in front of you": right up to you) and interrupted.
local function snapUndertow(player, character, eye, look, center)
	local U = A.Undertow
	local tanA = math.tan(math.rad(U.ConeAngle))
	local caught = {}
	for humanoid, model in pairs(Core.HumanoidsNear(eye + look * (U.Reach / 2), U.Reach / 2 + U.Reach * tanA + U.CatchSlack, character)) do
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if root and not Core.IsWall(model) and not Core.IsFriendly(player, model) then
			local d = root.Position - eye
			local along = d:Dot(look)
			local lateral = (d - look * along).Magnitude
			local inCone = along > 0.5 and along <= U.Reach + U.CatchSlack and lateral <= along * tanA + U.CatchSlack
			if inCone then
				local wall = castThroughBodies(eye, d, worldParams(character))
				if wall and (wall.Position - eye).Magnitude < d.Magnitude - 1.5 then inCone = false end
			end
			if inCone then
				caught[#caught + 1] = model
				local victim = Players:GetPlayerFromCharacter(model)
				if victim then
					tell(victim, "AquaPull", { Caster = character, Center = center, Until = serverNow() + U.PullTime + 0.1 })
					interrupt(victim)
				elseif serverOwned(root) then
					local v = flat(center - root.Position) / U.PullTime
					if v.Magnitude > U.PullMaxSpeed then v = v.Unit * U.PullMaxSpeed end
					moveDummy(root, v + Vector3.new(0, U.PullLift, 0), U.PullTime, U.PullForcePerMass)
				elseif root.Anchored then
					-- a range dummy: carried to the centre (with the pull's little hop), held there, put back
					local to = flat(center - root.Position)
					if to.Magnitude > U.PullMaxSpeed * U.PullTime then to = to.Unit * U.PullMaxSpeed * U.PullTime end
					carryDummy(model, function(t)
						local k = t / U.PullTime
						return to * k + Vector3.new(0, U.PullLift * U.PullTime * math.sin(math.pi * k), 0)
					end, U.PullTime, 1.2)
				end
				if U.Damage > 0 then Core.DealDamage(player, humanoid, U.Damage, { Source = "Undertow" }) end
			end
		end
	end
	broadcast("AquaUndertowSnap", { Character = character, Center = center, Caught = caught })
	local now = os.clock()
	addDisk(player, center, U.PuddleRadius, now, now + A.Current.WetLife)
end

local function castUndertow(player, character, humanoid, root, payload)
	local eye, look, disc, pullTo = undertowFrame(character, root, payload.Target)
	broadcast("AquaUndertow", { Character = character, Center = disc, Look = look, T0 = serverNow() })
	local epoch = Core.Epoch(player)
	task.delay(A.Undertow.SnapTime, function()
		if Core.Epoch(player) ~= epoch or player.Character ~= character then return end
		snapUndertow(player, character, eye, look, pullTo)
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: TWIN TIDE
----------------------------------------------------------------------------------------------------
local function castTwinTide(player, character, humanoid, root, payload)
	local W = A.TwinTide
	local center = aimedGround(root, payload.Target, W.Range)
	local axis = flat(center - root.Position)
	if axis.Magnitude < 1 then axis = flat(root.CFrame.LookVector) end
	axis = axis.Unit
	broadcast("AquaTwinTide", { Character = character, Center = center, Axis = axis, T0 = serverNow() })
	-- the lane is flooded from the cast until WetLife past the sink
	local life = W.CloseTime + W.HoldTime + W.SinkTime + A.Current.WetLife
	addStrip(player, center - axis * (W.Length / 2), center + axis * (W.Length / 2), W.StartGap / 2, 1e6, center.Y, life)
	local epoch = Core.Epoch(player)
	task.delay(W.CloseTime, function()
		if Core.Epoch(player) ~= epoch then return end
		local right = axis:Cross(Vector3.yAxis)
		local crushed = {}
		for hum, model in pairs(Core.HumanoidsNear(center + Vector3.new(0, W.Height / 2, 0), W.Length / 2 + W.Height, character)) do
			local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if r and not Core.IsWall(model) and not Core.IsFriendly(player, model) then
				local d = r.Position - center
				if math.abs(d:Dot(axis)) <= W.Length / 2 + 1 and math.abs(d:Dot(right)) <= W.CrushHalfWidth + W.CrushSlack
					and d.Y >= -3 and d.Y <= W.Height then
					crushed[#crushed + 1] = model
					if Core.DealDamage(player, hum, W.CrushDamage, { Source = "TwinTide" }) then
						launch(model, Vector3.new(0, W.CrushLift, 0))
					end
				end
			end
		end
		broadcast("AquaTwinTideCrash", { Character = character, Center = center, Axis = axis, Caught = crushed })
	end)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: SIDEARM
----------------------------------------------------------------------------------------------------
-- The owner (2026-09-25): the press draws the gun and its first shot leaves DrawTime later ("hold out a gun and then
-- shoot"); held on, it rapid-fires, every bullet paying BulletCost ("rapid fires bullets but takes mana in return").
-- The press pays TapCost through SpellshotService's held path, and that buys the drawn shot. Each shot is its own
-- message the moment it leaves (SidearmShot): the drawn one must come about DrawTime after the press (a tap's key may
-- already be up); a rapid one only while the key is down, no faster than FireRate (a token bucket, so network jitter
-- passes and a faster client does not), and only if the bar can pay -- this spends it. Each hit is reported and checked
-- like Fireball's, and every bullet that lands knocks its target back (the owner: "all bullets should do knockback").
local sidearmHolds = {}       -- [player] = { Start, Character, Held, ReleasedAt, Shots, Tokens, At }
local slugs = {}              -- [player] = { [id] = { Origin, Dir, Damage, Puddle, At, Life, Character } }
local lastPuddle = {}         -- [player] = { At, Position }: the wet disks under the splashes, not one per bullet

local function castSidearm(player, character, humanoid, root, payload)
	if payload.Phase == "Start" then
		local now = os.clock()
		sidearmHolds[player] = { Start = now, Character = character, Held = true, Shots = 0, Tokens = 1, At = now }
		broadcast("AquaSidearmHold", { Character = character, On = true, T0 = serverNow() })
		return
	end
	if payload.Phase ~= "Release" then return end
	local h = sidearmHolds[player]
	if h and h.Held then
		h.Held = false
		h.ReleasedAt = os.clock()
	end
	broadcast("AquaSidearmHold", { Character = character, On = false })
end

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "SidearmShot" or type(a) ~= "table" then return end
	local S = A.Sidearm
	local character, humanoid, root = Core.AliveCharacter(player)
	local h = sidearmHolds[player]
	if not (character and h and h.Character == character) then
		Core.CountShot("rej_nohold")
		return
	end
	local origin, dir, id = a.Origin, a.Dir, a.Id
	if not (Core.ValidVector(origin) and Core.ValidVector(dir)) or type(id) ~= "number" or dir.Magnitude < 0.1 then return end
	local now = os.clock()
	local ts = VFXLibrary.ShotTimeScale()
	local first = h.Shots == 0
	if first then
		-- the drawn shot: DrawTime after the press, give or take the network
		local since = now - h.Start
		if since < S.DrawTime / ts - 0.12 or since > S.DrawTime / ts + 1.5 then
			Core.CountShot("rej_draw")
			return
		end
	else
		-- a rapid bullet: only while the key is down (a moment's grace for one sent just before the release)
		if not h.Held and now - (h.ReleasedAt or 0) > 0.25 then
			Core.CountShot("rej_released")
			return
		end
		h.Tokens = math.min(2, h.Tokens + (now - h.At) * S.FireRate * ts * 1.1)
		h.At = now
		if h.Tokens < 1 then
			Core.CountShot("rej_rate")
			return
		end
		if not character:GetAttribute("DevFreeMana") then
			if (character:GetAttribute("Mana") or 0) < S.BulletCost then
				Core.CountShot("rej_mana")
				return
			end
		end
		h.Tokens -= 1
	end
	local head = character:FindFirstChild("Head")
	local ping = 0
	pcall(function() ping = player:GetNetworkPing() end)
	local speed = math.max(root.AssemblyLinearVelocity.Magnitude, humanoid.WalkSpeed)
	if (origin - (head and head.Position or root.Position)).Magnitude > 6 + speed * (0.35 + ping) then
		Core.CountShot("rej_origin")
		return
	end
	if not first and not character:GetAttribute("DevFreeMana") then
		spendMana:Fire(player, S.BulletCost)
	end
	h.Shots += 1
	local n = h.Shots
	local mine = slugs[player]
	if not mine then
		mine = {}
		slugs[player] = mine
	end
	for oldId, s in pairs(mine) do
		if now - s.At > s.Life then mine[oldId] = nil end
	end
	mine[id] = {
		Origin = origin, Dir = dir.Unit, At = now, Character = character,
		Damage = S.BulletDamage,                      -- every bullet the same (the 12-damage first shot is gone)
		Life = S.Range / (S.Speed * ts) + 1.0,
	}
	broadcast("AquaSidearm", { Character = character, Origin = origin, Dir = dir.Unit, N = n })
end)

remote.OnServerEvent:Connect(function(player, action, a)
	if action ~= "SidearmHit" or type(a) ~= "table" then return end
	local mine = slugs[player]
	local shot = mine and type(a.Id) == "number" and mine[a.Id]
	if not shot then
		Core.CountShot("rej_noshot")
		return
	end
	local S = A.Sidearm
	local now = os.clock()
	mine[a.Id] = nil                                -- one bullet, one hit
	if now - shot.At > shot.Life then
		Core.CountShot("rej_late")
		return
	end
	local part, position = a.Part, a.Position
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace)
		or not Core.ValidVector(position) then
		Core.CountShot("rej_badpart")
		return
	end
	local rel = position - shot.Origin
	local along = rel:Dot(shot.Dir)
	if along < 0 or along > S.Range + 1 or (rel - shot.Dir * along).Magnitude > S.HitSlack then
		Core.CountShot("rej_offline")
		return
	end
	if now - shot.At < along / (S.Speed * VFXLibrary.ShotTimeScale()) - 0.25 then
		Core.CountShot("rej_early")
		return
	end
	local reason, model, humanoid = Core.CheckTarget(part, position, shot.Character)
	if reason == "rej_moved" then
		local lp = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2 + Vector3.new(1, 1, 1)
		if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then
			reason = nil
			model = part:FindFirstAncestorOfClass("Model")
			humanoid = model and model:FindFirstChildOfClass("Humanoid")
		end
	end
	if reason then
		Core.CountShot(reason)
		return
	end
	if Core.Blocked(shot, along, humanoid and model or part) then
		Core.CountShot("rej_blocked")
		return
	end
	Core.CountShot("hit")
	local splashAt = position
	if humanoid then
		Core.CountShot("hit_char")
		-- every bullet that lands knocks its target back along the shot (the owner, 2026-09-25: "all bullets should do
		-- knockback"): AquaKnock to a player's own client, the server's mover on a dummy
		if Core.DealDamage(player, humanoid, shot.Damage, { Ranged = true, From = shot.Origin, Source = "Sidearm" }) then
			local push = flat(shot.Dir)
			push = push.Magnitude > 0.1 and push.Unit or Vector3.zero
			launch(model, push * S.KnockBack + Vector3.new(0, sidearmKnockUp(), 0))
		end
		local r = model:FindFirstChild("HumanoidRootPart")
		local g = r and groundBelow(r.Position, 10)
		if g then splashAt = g end
	else
		Core.CountShot("hit_world")
	end
	-- (every client's own copy of the bullet splashes where it stops, so no splash is broadcast.) The wet ground under
	-- the splashes: one disk per spot, not one per rapid bullet
	local lp = lastPuddle[player]
	if not lp or now - lp.At > 0.4 or (lp.Position - splashAt).Magnitude > S.PuddleRadius then
		lastPuddle[player] = { At = now, Position = splashAt }
		addDisk(player, splashAt, S.PuddleRadius, now, now + A.Current.WetLife)
	end
end)

----------------------------------------------------------------------------------------------------
-- ULTIMATE: LEVIATHAN'S MAW
----------------------------------------------------------------------------------------------------
local function castMaw(player, character, humanoid, root, payload)
	local M = A.Maw
	local center = aimedGround(root, payload.Target, M.Range)
	broadcast("AquaMaw", { Character = character, Center = center, T0 = serverNow() })
	local start = os.clock()
	addDisk(player, center, M.Radius, start + M.FloodTime, start + M.ReleaseTime + M.WetAfter)
	local epoch = Core.Epoch(player)
	local inside = {}           -- [model] = humanoid: who the tank closed on
	local function within(model, extra)
		local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not r then return nil end
		local d = r.Position - center
		local dist = flat(d).Magnitude
		if dist <= M.Radius + extra and d.Y >= -4 and d.Y <= M.WallHeight + M.RoofRise then return dist end
		return nil
	end
	task.delay(M.CloseTime, function()
		if Core.Epoch(player) ~= epoch then return end
		local n = 0
		for hum, model in pairs(Core.HumanoidsNear(center + Vector3.new(0, M.WallHeight / 2, 0), M.Radius + M.WallHeight, character)) do
			if not Core.IsWall(model) and not Core.IsFriendly(player, model) and within(model, -0.5) then
				inside[model] = hum
				n += 1
			end
		end
		-- one shark circles under the flood for every enemy trapped (the owner, 2026-09-25), up to MaxSharks
		broadcast("AquaMawTrapped", { Character = character, Center = center, Count = math.clamp(n, 1, M.MaxSharks) })
	end)
	task.delay(M.LungeTime, function()
		if Core.Epoch(player) ~= epoch then return end
		-- EVERY trapped enemy still inside gets a shark of its own (the owner: "if more than 1 person is in the shark tank,
		-- more than 1 shark will appear and each will get hit separately"), nearest the centre first, up to MaxSharks;
		-- anyone past the cap takes the surge instead
		local targets = {}
		for model, hum in pairs(inside) do
			local dist = hum.Health > 0 and model.Parent and within(model, 2)
			if dist then targets[#targets + 1] = { Model = model, Hum = hum, Dist = dist } end
		end
		table.sort(targets, function(a, b) return a.Dist < b.Dist end)
		local list = {}
		for i, t in ipairs(targets) do
			if i > M.MaxSharks then break end
			local r = t.Model:FindFirstChild("HumanoidRootPart") or t.Model.PrimaryPart
			list[#list + 1] = { Target = t.Model, Point = r and r.Position or center }
		end
		broadcast("AquaMawLunge", { Character = character, Center = center, Targets = list })
		task.delay(M.BiteTime - M.LungeTime, function()
			if Core.Epoch(player) ~= epoch then return end
			local bitten = {}
			for i, t in ipairs(targets) do
				if t.Hum.Health > 0 and t.Model.Parent and within(t.Model, 2) then
					if i <= M.MaxSharks then
						if Core.DealDamage(player, t.Hum, M.BiteDamage, { Source = "LeviathansMaw" }) then
							launch(t.Model, Vector3.new(0, M.BiteLift, 0))
							bitten[#bitten + 1] = t.Model
						end
					else
						Core.DealDamage(player, t.Hum, M.SurgeDamage, { Source = "LeviathansMaw" })
					end
				end
			end
			broadcast("AquaMawBite", { Character = character, Center = center, Bitten = bitten })
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- dispatch
----------------------------------------------------------------------------------------------------
local casts = {
	Riptide = castRiptide,
	Undertow = castUndertow,
	TwinTide = castTwinTide,
	Sidearm = castSidearm,
	LeviathansMaw = castMaw,
}

performCast.Event:Connect(function(player, role, ability, payload)
	local fn = ability and casts[ability.Id]
	if not fn then return end
	local character, humanoid, root = Core.AliveCharacter(player)
	if not character then
		if ability.Id == "Sidearm" then sidearmHolds[player] = nil end
		return
	end
	fn(player, character, humanoid, root, type(payload) == "table" and payload or {})
end)

-- a Sidearm held past HoldGiveUp with no release (a client that never lets go) is ended; a hold let go is forgotten a
-- moment after its drawn shot could still have come
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, h in pairs(sidearmHolds) do
		if h.Held and now - h.Start > A.Sidearm.HoldGiveUp then
			h.Held = false
			h.ReleasedAt = now
			local slot = VFXLibrary.TechniqueSlot(player, "Sidearm")
			if slot then releaseHold:Fire(player, slot) end
		elseif not h.Held and now - math.max(h.ReleasedAt or 0, h.Start + A.Sidearm.DrawTime + 1.5) > 1 then
			sidearmHolds[player] = nil
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------------------------------------
local function forget(player)
	shots[player] = nil
	buckets[player] = nil
	slugs[player] = nil
	sidearmHolds[player] = nil
	lastPuddle[player] = nil
	for i = #zones, 1, -1 do
		if zones[i].Owner == player then table.remove(zones, i) end
	end
	if riding[player] then
		riding[player] = nil
		setRiding(player, false)
	end
end

Players.PlayerRemoving:Connect(function(player)
	forget(player)
end)

-- Leaving the arena, or a duel round being reset: waves and slugs in flight land nowhere, every wet patch dries, the
-- buff ends; anything scheduled (a snap, a crush, a bite) checks the epoch and does nothing.
Core.OnClear(function(player)
	forget(player)
	local c = player.Character
	if c then
		c:SetAttribute("SlipUntil", nil)
		c:SetAttribute("InterruptedUntil", nil)
	end
end)
