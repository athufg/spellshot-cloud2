--[[
	DashMotor  (ModuleScript)  ->  ReplicatedStorage/Spellshot/DashMotor

	The body's half of Frost Slide, the Mobility slot: the dash itself. Client only. SpellshotInput
	asks for a dash, MovementController gets out of its way (a slide or leap in progress is cancelled
	on Started) and AbilityFX's footfall loop leaves a dashing body alone.

	WHY THE CLIENT MOVES THE BODY
	  The client has network ownership of its own character, so the dash is simulated here and
	  reaches everyone else as ordinary motion. A push applied on the server would fight the client's
	  own simulation and rubber-band, for the same reason the slide's impulse lives on the client
	  (see MovementController). The server never moves anybody for Frost Slide: it checks where the
	  dash STARTED, spends the charge and lays the frozen patch there (AbilityHandler).

	THE MECHANISM
	  A LinearVelocity on an Attachment of its own on the HumanoidRootPart, in world space, with a
	  per-axis force limit. On the ground it pushes across X and Z only, so gravity still acts: a
	  ramp is climbed and a ledge run off mid-dash is fallen from. A dash started in the air pushes
	  on Y as well, towards zero, and so holds the height it began at -- an air dash that sagged
	  would come up short of where it was pointed. The force is AssemblyMass * FORCE_PER_MASS, far
	  past what the Humanoid's own controller applies, so the stick does not steer the dash once it
	  has started. A constraint rather than the slide's velocity write once a Heartbeat because it
	  holds through every physics step in between, where the Humanoid would otherwise spend those
	  steps pulling a speed of more than twice the run back down toward WalkSpeed.

	THE NUMBERS (VFXLibrary.Tuning.FrostSlide, from the blocking pass)
	  DashDistance studs in DashTime seconds: 13 in 0.2, 65 studs/s against the 25 run. A slow
	  scales speed and distance together (cap / SprintSpeed), so a slowed dash takes the same time
	  and covers less ground; under DashMinCap -- a root, a heavy slow -- there is no dash at all.
	  DashMaxTime is the backstop: whatever else happens, the push is gone by then.

	WHERE IT GOES
	  The movement input (Humanoid.MoveDirection: keys, stick or thumbstick, already relative to the
	  camera), else where the camera looks, flattened; locked on the frame the dash starts. A sphere
	  cast shortens the distance up front so the dash stops short of a wall, and a short cast every
	  frame catches whatever has moved into the way since. A hit with a floor-like normal (a ramp,
	  the top of a step) is ground to run over, not a wall, and the cast carries on past it.

	HOW IT ENDS
	  Distance covered; out of time; stopped by something (moving at under BLOCKED_SHARE of the
	  commanded speed for BLOCKED_FRAMES frames running); frozen or slowed under DashMinCap mid-dash;
	  dead; respawned; or moved between zones. The push is removed, and the speed along the dash is
	  handed back at no more than the run -- so a dash is a burst, and never seeds a 65 studs/s slide
	  or leap out of its last frame. Frozen, slowed and a zone move stop the body dead instead, and a
	  dead or replaced body is not touched at all.

	CROSS-SLASH DASH (Zephyr's Primary) runs here too, with a REQUEST SPEC (below); Frost Slide passes none, and none of
	this touches it. Since 2026-09-17 that dash is HELD (the charge lasts as long as the key, the body walking slowly,
	and Launch starts the glide), FREE3D (straight along the aim at any pitch, the height driven too, every surface a
	wall -- but the ground it starts on, which a downward aim skims since 2026-10-07: skimFloor) and THROUGH CHARACTERS
	(no body stops, shortens or ends it).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local VFXLibrary = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("VFXLibrary"))

local MOVE = Config.Movement

local FORCE_PER_MASS = 4000      -- the push, per axis, is the assembly's mass times this
local PROBE_RADIUS = 1           -- the sphere cast ahead of the body
local FLOOR_NORMAL_Y = 0.55      -- a hit at least this flat is ground to run over, not a wall
local WALL_MARGIN = 0.5          -- studs the dash stops short of a wall
local MAX_CAST_STEPS = 4         -- floor hits one cast is carried past before it stops looking
local BLOCK_GRACE = 0.04         -- no stop check this early: the push has not taken hold yet
local BLOCKED_SHARE = 0.45       -- moving at under this share of the commanded speed...
local BLOCKED_FRAMES = 2         -- ...this many frames running: something is in the way
local MAX_BODY_SKIPS = 8         -- ThroughCharacters: characters one cast looks past (not counted as floor steps)
local BODY_SCAN_WIDTH = 7        -- ThroughCharacters: the box around and ahead of the root that finds bodies to pass ...
local BODY_SCAN_HEIGHT = 10      -- ... this tall ...
local BODY_SCAN_AHEAD = 4        -- ... and this far ahead, plus two frames of travel ...
local BODY_SCAN_LEAD = 0.1       -- ... and never less than this many seconds of travel (ASSUMED, 2026-09-17: at the faster
                                 -- Cross-Slash glide a frame that runs long must not carry the body into one unpaired)
local NO_COLLIDE_LINGER = 0.3    -- ThroughCharacters: seconds the no-collide outlasts the dash, to clear a body it ends in
local FEET_LIFT = 0.25           -- Free3D: the feet probe's sphere rides this far above the ground the body stands on
local SKIM_STEP = 2              -- Free3D's skim: ground met no deeper than this under the plane the feet stand on is that
                                 -- same ground (a step down, a dip); deeper is a drop, which a downward aim may still dive into

-- How each ending leaves the body: HALT stops it dead, LET_GO does not touch it (it is dead or no
-- longer ours), and everything else hands the speed back at no more than the run.
local HALT = { Frozen = true, Slowed = true, Zone = true }
local LET_GO = { Died = true, CharacterChanged = true, CharacterRemoving = true }

local DashMotor = {}
DashMotor.Started = Instance.new("BindableEvent")   -- Event: (startPos, dir, dist)
DashMotor.Ended = Instance.new("BindableEvent")     -- Event: (endPos, reason)

local pending = nil   -- { Character, OnStarted, Spec, StartAt, Hold, Held, Zone }: asked for, starts on the next Heartbeat (or at StartAt)
local active = nil    -- the dash in progress (see begin)

-- A REQUEST SPEC (optional; Frost Slide passes none and is unchanged). Cross-Slash Dash's glide, 2026-09-16:
--   Dir        flat unit direction, instead of the movement input / camera (Free3D: kept in 3D)
--   Distance   studs, instead of Tuning.FrostSlide.DashDistance (a slow still scales it)
--   Speed      studs/s at full speed, instead of DashDistance / DashTime
--   MaxTime    the backstop, instead of DashMaxTime
--   MinCap     slowed under this refuses / ends the dash, instead of DashMinCap
--   StartAfter seconds to wait before the push -- a CHARGE: the body is held still meanwhile, and the motor counts
--              as busy (IsActive), so nothing else moves it
--   Exclude    instances the wall casts ignore
-- ...and since 2026-09-17 (Cross-Slash Dash's hold-to-charge, 3D aim and pass-through):
--   Held       true: a charge with no end of its own. The motor is busy (IsActive) and the body held (StartAfter's hold)
--              until Launch(at, fields) says when to start and adds the fields the release decides (Distance, MaxTime,
--              DirAt); dropped -- no dash -- on any rule a dash is refused on (dead, frozen, slowed under MinCap, in the
--              Hub, channeling), a move between zones, or the body going away
--   HoldMove   a share of the run speed the body may walk at under the hold (steered, never sprinting or sliding)
--   OnDropped  fn(reason): a charged request (Held or StartAfter) ended without starting -- dropped, refused on its
--              first frame, or Cancel()led
--   Free3D     true: the dash runs along Dir (or DirAt's answer) at any pitch -- the height is driven too, so gravity
--              waits for the end -- and every surface it would meet is a wall, a ramp and the floor included (the
--              feet are probed as well when it heads down, so it stops standing on the ground rather than driven
--              into it). A surface that cuts it short is reached exactly: the last push only goes as far as the
--              stop (and, since 2026-09-17, an uncut dash's only as far as its distance). At the end only the level
--              part of the speed is handed back, and the body falls from rest. EXCEPT the ground it starts on
--              (2026-10-07, SKIM: skimFloor): from the ground, an aim down into that ground runs along it instead
--   SkimFloor  false: Free3D without the skim (every downward aim from the ground stops where the feet meet the floor)
--   DirAt      fn(root) -> the direction, asked on the frame the dash starts (Free3D)
--   ThroughCharacters  true: characters never stop, shorten or end the dash (2026-09-17). The casts look past anything
--              with a Humanoid, and this body is kept from touching one (NoCollisionConstraints between each of its
--              parts and each of theirs, made on this client only, which simulates its own body) until
--              NO_COLLIDE_LINGER after the dash. Walls and the ground still stop it

local function tuning()
	return VFXLibrary.Tuning.FrostSlide
end

-- the same rule MovementController and the server use: the tighter of the two ability caps
local function capOf(character)
	return math.min(character:GetAttribute("SpeedCapSlow") or math.huge,
		character:GetAttribute("SpeedCapUlt") or math.huge)
end

local function flatUnit(v)
	local h = Vector3.new(v.X, 0, v.Z)
	return h.Magnitude > 1e-3 and h.Unit or nil
end

-- Built fresh for each cast: the FX folder is created lazily, often by the dash's own effects.
-- Nothing in it should stop a body, and nothing should be parented to the camera, but both are cheap
-- to rule out.
local function castParams(character, extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character }
	for _, inst in ipairs(extra or {}) do
		if typeof(inst) == "Instance" then table.insert(exclude, inst) end
	end
	local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if fx then table.insert(exclude, fx) end
	local camera = workspace.CurrentCamera
	if camera then table.insert(exclude, camera) end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

-- the character (a model with a Humanoid) that inst is part of, or nil
-- (2026-10-19, audit P6A-05) Terra's Bulwark Wall is a Model with a Humanoid too, but it is a wall: a model stamped
-- WallOwner (CombatCore.IsWall's rule) is never a body, so a ThroughCharacters dash stops at it and never no-collides it
local function characterOf(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			if model:GetAttribute("WallOwner") ~= nil then return nil end
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

--- How far the body can travel along dir before a sphere of PROBE_RADIUS meets a wall, or nil when
--- nothing is in the way within length. A floor-like hit is carried past: the cast restarts just
--- beyond where it touched, and a shape cast ignores whatever it starts inside, so the same ramp is
--- not found twice. With throughCharacters a character is no wall: its model joins the filter and the
--- cast is made again from the same place. With solid (Free3D) every other hit is a wall, floor-like or not.
local function wallAhead(origin, dir, length, params, throughCharacters, solid)
	local travelled = 0
	local steps, skips = 0, 0
	while steps < MAX_CAST_STEPS do
		local remaining = length - travelled
		if remaining <= 0 then return nil end
		local hit = workspace:Spherecast(origin + dir * travelled, PROBE_RADIUS, dir * remaining, params)
		if not hit then return nil end
		local body = throughCharacters and characterOf(hit.Instance)
		if body then
			skips += 1
			if skips > MAX_BODY_SKIPS then return nil end    -- a crowd: none of it may stop this dash anyway
			params:AddToFilter(body)
		elseif solid or hit.Normal.Y < FLOOR_NORMAL_Y then
			return travelled + hit.Distance
		else
			travelled += hit.Distance + 0.05
			steps += 1
		end
	end
	return nil
end

--- Free3D's casts: the root's sphere, and while the dash heads down a second sphere at the feet (FEET_LIFT above the
--- ground the body stands on), so the dash ends with the body standing on what it came down to. The nearer wins.
local function wallAhead3D(root, hum, dir, length, params, throughCharacters)
	local wall = wallAhead(root.Position, dir, length, params, throughCharacters, true)
	if dir.Y < -1e-3 then
		local drop = hum.HipHeight + root.Size.Y * 0.5 - PROBE_RADIUS - FEET_LIFT
		if drop > 0 then
			local feet = wallAhead(root.Position - Vector3.new(0, drop, 0), dir, length, params, throughCharacters, true)
			if feet and (not wall or feet < wall) then wall = feet end
		end
	end
	return wall
end

--- Free3D's SKIM (2026-10-07): a dash from the GROUND aimed down into that ground runs along it, not into it. To Free3D
--- every surface is a wall, and the feet probe above meets the floor the body stands on after a stud or two of ANY
--- downward aim: Roblox's spawn camera looks 15 degrees down, which puts the crosshair on the floor ~17 studs out, and
--- a fully charged Cross-Slash aimed there ended 0.9 studs from where it began -- its look played the whole glide, its
--- body never left (the look runs on the cast's clock, not on the motor). So when the feet's own sphere, cast along the
--- aim, meets floor-like ground (Normal.Y >= FLOOR_NORMAL_Y) within `length`, and that ground lies no more than SKIM_STEP
--- under the plane the feet stand on, the part of the aim pointing into it is dropped: on flat ground the glide runs
--- level, on a slope along it. Left as they were: a body in the air (its dive onto the floor, ending stood on it, is the
--- point), an aim level or up, a drop deeper than SKIM_STEP (aimed off a ledge at the floor below), and anything steeper
--- than floor-like (a wall). Characters are looked past as wallAhead does (`params` gains them, as it would there).
local function skimFloor(root, hum, dir, length, params, throughCharacters)
	if dir.Y >= -1e-3 or hum.FloorMaterial == Enum.Material.Air then return dir end
	local standing = hum.HipHeight + root.Size.Y * 0.5
	local under = workspace:Raycast(root.Position, Vector3.new(0, -(standing + 1.5), 0), params)
	if not (under and under.Normal.Y >= FLOOR_NORMAL_Y) then return dir end
	local drop = standing - PROBE_RADIUS - FEET_LIFT
	if drop <= 0 then return dir end
	local feet = root.Position - Vector3.new(0, drop, 0)
	local skips = 0
	while true do
		local hit = workspace:Spherecast(feet, PROBE_RADIUS, dir * length, params)
		if not hit then return dir end                                  -- nothing under the aim within reach
		local body = throughCharacters and characterOf(hit.Instance)
		if not body then
			if hit.Normal.Y < FLOOR_NORMAL_Y or (hit.Position - under.Position):Dot(under.Normal) < -SKIM_STEP then
				return dir                                              -- a wall, or a drop to dive into
			end
			local along = dir - hit.Normal * dir:Dot(hit.Normal)
			-- aimed (all but) straight down at the feet: along the way the body faces
			if along.Magnitude < 0.05 then return flatUnit(root.CFrame.LookVector) or dir end
			return along.Unit
		end
		skips += 1
		if skips > MAX_BODY_SKIPS then return dir end
		params:AddToFilter(body)
	end
end

-- Movement rules only. Mana, charges and cooldowns are SpellshotInput's to check, and the server's.
local function refusal(character, minCap)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return "Dead" end
	if player:GetAttribute("Zone") == "Hub" then return "Hub" end
	if capOf(character) < (minCap or tuning().DashMinCap) then return "Slowed" end
	if character:FindFirstChild("IceFrozenState") then return "Frozen" end
	if character:GetAttribute("Channeling") == true then return "Channeling" end
	return nil
end

--- Whether a dash could start now: ok, and the reason when it could not.
function DashMotor.CanStart(character, minCap)
	character = character or player.Character
	local reason = refusal(character, minCap)
	if not reason and (active or pending) then reason = "Dashing" end
	return reason == nil, reason
end

-- a charge waiting to push counts (a held one too): MovementController must not start a slide or a leap under it
function DashMotor.IsActive()
	return active ~= nil or (pending ~= nil and (pending.StartAt ~= nil or pending.Held == true))
end

-- a charged request that ends without a dash tells its caller (spec.OnDropped)
local function dropped(request, reason)
	local spec = request and request.Spec
	if spec and spec.OnDropped then task.spawn(spec.OnDropped, reason) end
end

-- the charge's hold: a flat LinearVelocity toward zero, so the body plants while the forearms cross (a Held charge with
-- HoldMove steers it instead: steerHold)
local function releaseHold(request)
	if request and request.Hold then
		request.Hold:Destroy()
		request.Hold = nil
	end
end

local function holdStill(request, moveShare)
	local root = request.Character and request.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashHoldAttachment"
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashHold"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * FORCE_PER_MASS
	velocity.MaxAxesForce = Vector3.new(force, 0, force)
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = attachment
	attachment.Parent = root
	request.Hold = attachment
	request.HoldVelocity = velocity
	request.HoldShare = moveShare
end

-- HoldMove: every Heartbeat the hold pushes the body where it is steered at that share of its run speed (a slow caps
-- the run as it does everywhere), and toward zero when it is not steered. Its force outweighs the Humanoid's own drive,
-- so nothing faster -- a sprint, a slide -- gets through.
local function steerHold(request)
	local share, velocity = request.HoldShare, request.HoldVelocity
	if not (share and velocity) then return end
	local character = request.Character
	local hum = character:FindFirstChildOfClass("Humanoid")
	local move = hum and hum.MoveDirection or Vector3.zero
	move = Vector3.new(move.X, 0, move.Z)
	if move.Magnitude < 0.1 then
		velocity.VectorVelocity = Vector3.zero
		return
	end
	local run = math.min(MOVE.SprintSpeed * (character:GetAttribute("MoveSpeedMult") or 1), capOf(character))
	velocity.VectorVelocity = move * (run * share)
end

-- ThroughCharacters: this body stops touching `model` until the dash's no-collide is let go
local function passThrough(a, model)
	if model == a.Character or a.Passing[model] then return end
	a.Passing[model] = true
	for _, other in ipairs(model:GetDescendants()) do
		if other:IsA("BasePart") then
			for _, mine in ipairs(a.Mine) do
				local nc = Instance.new("NoCollisionConstraint")
				nc.Part0, nc.Part1 = mine, other
				nc.Parent = a.PassFolder
			end
		end
	end
end

-- the frame a scan box sits in: along the dash, level wherever it can be
local function dashFrame(pos, dir)
	local up = (math.abs(dir.Y) > 0.99) and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	return CFrame.lookAt(pos, pos + dir, up)
end

-- every character about to be touched: around the root and ahead of it by a little more than two frames of travel (at
-- least BODY_SCAN_LEAD seconds of it)
local function scanBodies(a, root, dt)
	local ahead = a.Speed * math.max(dt * 2, BODY_SCAN_LEAD) + BODY_SCAN_AHEAD
	local box = dashFrame(root.Position, a.Dir) * CFrame.new(0, 0, -(ahead - 2) * 0.5)
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(BODY_SCAN_WIDTH, BODY_SCAN_HEIGHT, ahead + 2),
		a.ScanParams)) do
		local model = characterOf(part)
		if model then passThrough(a, model) end
	end
end

-- EVERY part of this body is paired, whatever its CanCollide reads: the Humanoid can make a limb collide while the
-- property says it does not
local function startPassThrough(a)
	a.Passing = {}
	a.Mine = {}
	for _, part in ipairs(a.Character:GetDescendants()) do
		if part:IsA("BasePart") then a.Mine[#a.Mine + 1] = part end
	end
	a.PassFolder = Instance.new("Folder")
	a.PassFolder.Name = "DashPassThrough"
	a.PassFolder.Parent = a.Root
	a.ScanParams = OverlapParams.new()
	a.ScanParams.FilterType = Enum.RaycastFilterType.Exclude
	a.ScanParams.FilterDescendantsInstances = { a.Character }
	scanBodies(a, a.Root, 0)
end

local function releasePassThrough(a)
	local folder = a.PassFolder
	if not folder then return end
	a.PassFolder = nil
	task.delay(NO_COLLIDE_LINGER, function() folder:Destroy() end)
end

local function finish(reason)
	local a = active
	if not a then return end
	active = nil
	if a.DiedConnection then a.DiedConnection:Disconnect() end
	a.Attachment:Destroy()          -- the LinearVelocity is parented to it and goes with it
	releasePassThrough(a)

	local root = a.Root
	if not LET_GO[reason] and root.Parent and a.Humanoid.Health > 0 then
		local v = root.AssemblyLinearVelocity
		local keep = 0
		local sprint = MOVE.SprintSpeed * (a.Character:GetAttribute("MoveSpeedMult") or 1)
		if a.Free then
			-- a 3D dash hands back the level part of its speed along its heading, at no more than the run, and lets go of
			-- the height: the body falls from rest from here, as any body does (straight up or down: nothing kept). An uncut
			-- dash's last push was only trimmed to its end, so it hands back from the dash's own pace, as it always did
			local level = flatUnit(a.Dir)
			if level and not HALT[reason] then
				local from = (a.Trimmed and not a.Cut) and a.Dir * a.Speed or v
				keep = math.max(0, math.min(from:Dot(level), sprint, capOf(a.Character)))
			end
			root.AssemblyLinearVelocity = level and level * keep or Vector3.zero
		else
			if not HALT[reason] then
				local along = v:Dot(a.Dir)    -- Dir is flat, so this is the horizontal speed along the dash
				keep = math.max(0, math.min(along, sprint, capOf(a.Character)))
			end
			root.AssemblyLinearVelocity = Vector3.new(a.Dir.X * keep, v.Y, a.Dir.Z * keep)
		end
	end
	DashMotor.Ended:Fire(root.Position, reason)
end

--- Stops a dash in progress (the speed is handed back as on any ordinary ending), or drops one that
--- was asked for and has not started (its OnDropped hears `reason`).
function DashMotor.Cancel(reason)
	local request = pending
	releaseHold(pending)
	pending = nil
	if request then dropped(request, reason or "Cancelled") end
	finish(reason or "Cancelled")
end

-- Direction comes from Humanoid.MoveDirection, which reads 0 on the render step even mid-stride and
-- is only trusted on Heartbeat (see MovementController) -- which is why a request waits for the next
-- Heartbeat instead of starting on the keypress.
local function sampleDirection(hum, root)
	if hum.MoveDirection.Magnitude > 0.1 then
		local d = flatUnit(hum.MoveDirection)
		if d then return d end
	end
	local camera = workspace.CurrentCamera
	return (camera and flatUnit(camera.CFrame.LookVector)) or flatUnit(root.CFrame.LookVector)
		or Vector3.new(0, 0, -1)
end

local function begin(request, dt)
	local character = request.Character
	local spec = request.Spec or {}
	releaseHold(request)
	-- a frame has passed since the request: it is refused on the same rules if anything changed
	if character ~= player.Character or refusal(character, spec.MinCap) then
		dropped(request, "Refused")
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local S = tuning()

	local cap = capOf(character)
	local scale = (cap == math.huge) and 1 or math.clamp(cap / MOVE.SprintSpeed, 0, 1)
	local speed = (spec.Speed or S.DashDistance / S.DashTime) * scale
	local free = spec.Free3D == true
	local through = spec.ThroughCharacters == true
	local dir
	if free then
		-- the aim, in 3D, taken on this frame
		local want = spec.Dir
		if spec.DirAt then
			local ok, got = pcall(spec.DirAt, root)
			if ok then want = got end
		end
		if typeof(want) == "Vector3" and want.Magnitude > 1e-3 then dir = want.Unit end
	end
	dir = dir or (typeof(spec.Dir) == "Vector3" and flatUnit(spec.Dir)) or sampleDirection(hum, root)
	local startPos = root.Position
	local dist = (spec.Distance or S.DashDistance) * scale
	local params = castParams(character, spec.Exclude)
	-- from the ground, an aim down into that ground skims it (skimFloor) -- before the wall cast, which would stop on it
	if free and spec.SkimFloor ~= false then dir = skimFloor(root, hum, dir, dist + WALL_MARGIN, params, through) end
	local wall
	if free then
		wall = wallAhead3D(root, hum, dir, dist + WALL_MARGIN, params, through)
	else
		wall = wallAhead(startPos, dir, dist + WALL_MARGIN, params, through)
	end
	if wall then dist = math.max(0, math.min(dist, wall - WALL_MARGIN)) end

	local st = hum:GetState()
	local airborne = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
	local force = root.AssemblyMass * FORCE_PER_MASS

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	-- Free3D drives the height on the ground too, which is what holds gravity off for the whole glide
	velocity.MaxAxesForce = (airborne or free) and Vector3.new(force, force, force) or Vector3.new(force, 0, force)
	velocity.VectorVelocity = dir * speed        -- Dir is flat unless Free3D: in the air, Y is held at 0
	-- Free3D already up against a surface (aimed down at the floor it stands on): the first push only reaches the stop
	if free and wall and dist < speed * (dt or 1 / 60) then
		velocity.VectorVelocity = dir * (dist / math.max(dt or 1 / 60, 1 / 240))
	end
	velocity.Parent = attachment
	attachment.Parent = root

	active = {
		Character = character, Humanoid = hum, Root = root,
		Attachment = attachment,
		Origin = startPos, Dir = dir, Speed = speed, Distance = dist,
		Start = os.clock(), Zone = player:GetAttribute("Zone"),
		SlowFrames = 0,
		MaxTime = spec.MaxTime or S.DashMaxTime, MinCap = spec.MinCap or S.DashMinCap, Exclude = spec.Exclude,
		Free = free, Through = through, Velocity = velocity, Cut = wall ~= nil,
	}
	if through then startPassThrough(active) end
	active.DiedConnection = hum.Died:Connect(function()
		if active and active.Humanoid == hum then finish("Died") end
	end)

	DashMotor.Started:Fire(startPos, dir, dist)
	if request.OnStarted then request.OnStarted(startPos, dir, dist) end
end

--- Asks for a dash. Refused (false) on the movement rules above; otherwise it starts on the next
--- Heartbeat, and onStarted(startPos, dir, dist) is called on that frame, before anything else sees it.
--- `spec` (optional) overrides the Frost Slide tuning for this one dash: see REQUEST SPEC at the top.
function DashMotor.Request(onStarted, spec)
	local character = player.Character
	if not DashMotor.CanStart(character, spec and spec.MinCap) then return false end
	pending = { Character = character, OnStarted = onStarted, Spec = spec }
	if spec and spec.Held then
		pending.Held = true
		pending.Zone = player:GetAttribute("Zone")
		holdStill(pending, spec.HoldMove)
	elseif spec and spec.StartAfter and spec.StartAfter > 0 then
		pending.StartAt = os.clock() + spec.StartAfter
		holdStill(pending)
	end
	return true
end

--- Launches a Held request: `fields` (Distance, MaxTime, Dir, DirAt, ...) join its spec, and the dash starts on the first
--- Heartbeat at or after os.clock() `at` (the charge -- and its hold -- runs on until then). False when no held request
--- is waiting (it was dropped, or already launched).
function DashMotor.Launch(at, fields)
	local request = pending
	if not (request and request.Held and not request.StartAt) then return false end
	local spec = table.clone(request.Spec)
	for k, v in pairs(fields or {}) do spec[k] = v end
	request.Spec = spec
	request.StartAt = math.max(at or 0, os.clock())
	return true
end

RunService.Heartbeat:Connect(function(dt)
	if pending then
		local request = pending
		if request.StartAt or request.Held then
			-- the charge: dropped if the body went away, died or was frozen meanwhile; otherwise it waits. A Held one is
			-- dropped on every refusal rule and on a zone move too, and is steered while it waits
			local character = request.Character
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			local reason = nil
			if request.Held then
				reason = (character ~= player.Character and "CharacterChanged") or refusal(character, request.Spec.MinCap)
					or (player:GetAttribute("Zone") ~= request.Zone and "Zone") or nil
			elseif character ~= player.Character or not (hum and hum.Health > 0) or character:FindFirstChild("IceFrozenState") then
				reason = "Dropped"
			end
			if reason then
				releaseHold(request)
				pending = nil
				dropped(request, reason)
				return
			end
			if request.Held then steerHold(request) end
			if not request.StartAt or os.clock() < request.StartAt then return end
		end
		pending = nil
		begin(request, dt)
		return
	end
	local a = active
	if not a then return end

	local character = a.Character
	if character ~= player.Character or not a.Root.Parent then finish("CharacterChanged"); return end
	if a.Humanoid.Health <= 0 then finish("Died"); return end
	if player:GetAttribute("Zone") ~= a.Zone then finish("Zone"); return end
	if character:FindFirstChild("IceFrozenState") then finish("Frozen"); return end
	if capOf(character) < a.MinCap then finish("Slowed"); return end

	local root = a.Root
	local elapsed = os.clock() - a.Start
	local travelled = (root.Position - a.Origin):Dot(a.Dir)

	-- something that has moved into the way since the dash started (a door; a body too, unless the dash passes
	-- through characters -- then every body about to be touched is let through instead) shortens it
	if a.Through then scanBodies(a, root, dt) end
	local params = castParams(character, a.Exclude)
	local wall
	if a.Free then
		wall = wallAhead3D(root, a.Humanoid, a.Dir, a.Speed * dt + 1, params, a.Through)
	else
		wall = wallAhead(root.Position, a.Dir, a.Speed * dt + 1, params, a.Through)
	end
	if wall then
		local short = travelled + math.max(0, wall - WALL_MARGIN)
		if short < a.Distance then a.Distance, a.Cut = short, true end
	end

	-- Free3D: the last push only reaches the end, so the body does not sink a frame's travel into the floor it came down
	-- to before this ends it -- nor, since the Cross-Slash glide got fast (2026-09-17, 110 studs/s), run most of a
	-- frame's travel (up to 3.7 studs at 30 fps) past its charged distance
	local tolerance = 0
	if a.Free then
		tolerance = 0.05
		local remaining = a.Distance - travelled
		if remaining < a.Speed * dt then
			a.Velocity.VectorVelocity = a.Dir * (math.max(0, remaining) / math.max(dt, 1 / 240))
			a.Trimmed = true
		end
	end

	if travelled >= a.Distance - tolerance then finish("Distance"); return end
	if elapsed >= a.MaxTime then finish("Timeout"); return end

	-- pushing at full force and still barely moving: something the casts did not see is in the way (a last push trimmed
	-- to the end of an uncut dash is slow on purpose)
	if elapsed >= BLOCK_GRACE and not (a.Trimmed and not a.Cut)
		and root.AssemblyLinearVelocity:Dot(a.Dir) < a.Speed * BLOCKED_SHARE then
		a.SlowFrames += 1
		if a.SlowFrames >= BLOCKED_FRAMES then finish("Blocked"); return end
	else
		a.SlowFrames = 0
	end
end)

-- never leave a push behind on a body that is going away
player.CharacterRemoving:Connect(function()
	local request = pending
	releaseHold(pending)
	pending = nil
	if request then dropped(request, "CharacterRemoving") end
	finish("CharacterRemoving")
end)

return DashMotor
