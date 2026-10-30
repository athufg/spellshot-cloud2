-- WindEdgeBoost (2026-10-28, the owner's Skyline v2 wind edge). The Spire terrace's south edge blows wind out over the
-- gap; jumping off it throws you down onto Centre's terrace. Zones are parts tagged WindEdgeBoost (Skyline v2's
-- assembler makes them), each with a LaunchDir attribute (world Vector3) and optional LaunchSpeed / LaunchUp.
--  * ONLY a jump you make yourself launches (the owner, after playing: "it should be if you jump yourself manually").
--    Walking onto the edge, stepping off it or falling past it does nothing; a jump while moving away from the edge
--    doesn't launch either.
--  * In the air the Humanoid steers you back toward MoveDirection * WalkSpeed (MovementController's own notes), so a
--    single push bleeds away, and with no key held it brakes to nothing. Like the slide-leap, the push is HELD: the
--    flat velocity is rewritten every frame until you land, or for MAX_FLIGHT at most.
--  * Numbers: about 47 across and 28 down onto the middle of Centre's terrace at Gravity 64 -- up 36 gives 1.65 s of
--    air, so 28 studs/s along the edge's outward direction.
--  * The wind is drawn here, on each client: thin white lines streaming off the edge, rippling and curving down into
--    the gap -- trails on moving points, the way stylised games draw wind; never a fixed shape (the owner: "it should
--    be like good looking flowing wind"). Particle streaks were tried first and read as scratches. Tested in Play
--    2026-10-28: a jump from the edge lands mid-terrace on Centre (z 74.8 from the edge at 114.5) in 1.66 s; standing
--    on the edge for 5 s does nothing.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TAG = "WindEdgeBoost"
local SPEED, UP = 28, 36
local MAX_FLIGHT = 2.5
local REACH = 2.5                -- how far past the edge a jump still counts (the jump can start just over it)
local LINES_PER_SECOND = 13      -- wind lines across one edge
local NEAR = 320                 -- the wind is only drawn while you're this close to it

local player = Players.LocalPlayer
local flight = nil               -- { Dir, Speed, Start } while a launch is being carried

local function launchDir(zone)
	local d = zone:GetAttribute("LaunchDir")
	d = typeof(d) == "Vector3" and d or -zone.CFrame.LookVector
	d = Vector3.new(d.X, 0, d.Z)
	return d.Magnitude > 1e-3 and d.Unit or nil
end

local function zoneAt(pos)
	for _, z in ipairs(CollectionService:GetTagged(TAG)) do
		if z:IsA("BasePart") and z:IsDescendantOf(workspace) then
			local p = z.CFrame:PointToObjectSpace(pos)
			local h = z.Size / 2
			if math.abs(p.X) <= h.X + REACH and math.abs(p.Z) <= h.Z + REACH and p.Y >= -h.Y - 1 and p.Y <= h.Y + 4 then
				return z
			end
		end
	end
	return nil
end

local function hook(character)
	flight = nil
	local hum = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (hum and root) then return end
	hum.StateChanged:Connect(function(_, new)
		if new ~= Enum.HumanoidStateType.Jumping or flight then return end
		local zone = zoneAt(root.Position)
		local d = zone and launchDir(zone)
		if not d then return end
		if hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection.Unit:Dot(d) < -0.3 then return end   -- jumping back in
		flight = { Dir = d, Speed = zone:GetAttribute("LaunchSpeed") or SPEED, Start = os.clock() }
		root.AssemblyLinearVelocity = d * flight.Speed + Vector3.new(0, zone:GetAttribute("LaunchUp") or UP, 0)
	end)
end
if player.Character then task.spawn(hook, player.Character) end
player.CharacterAdded:Connect(hook)

RunService.Heartbeat:Connect(function()
	if not flight then return end
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local t = os.clock() - flight.Start
	if not (root and hum and hum.Health > 0) or t > MAX_FLIGHT or (t > 0.25 and hum.FloorMaterial ~= Enum.Material.Air) then
		flight = nil
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(flight.Dir.X * flight.Speed, v.Y, flight.Dir.Z * flight.Speed)
end)

-- ------------------------------------------------------------------ the wind lines (this client only)
local UP_V = Vector3.new(0, 1, 0)
local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end
local fx = Instance.new("Folder")
fx.Name = "WindEdgeFX"
fx.Parent = workspace            -- made by this client, so the server never sees these parts
local edges = {}                 -- zone -> { Dir, Side, Width, Acc, Runners }

local function track(zone)
	if not zone:IsA("BasePart") or edges[zone] then return end
	local d = launchDir(zone)
	if not d then return end
	local side = d:Cross(UP_V).Unit
	local ld, ls = zone.CFrame:VectorToObjectSpace(d), zone.CFrame:VectorToObjectSpace(side)
	local h = zone.Size / 2
	edges[zone] = {
		Dir = d, Side = side, Acc = 0, Runners = {},
		Reach = math.abs(ld.X) * h.X + math.abs(ld.Z) * h.Z,          -- centre to the launch-side face
		Width = math.abs(ls.X) * zone.Size.X + math.abs(ls.Z) * zone.Size.Z,
	}
end
local function untrack(zone)
	local e = edges[zone]
	if not e then return end
	for _, r in ipairs(e.Runners) do r.Part:Destroy() end
	edges[zone] = nil
end
for _, z in ipairs(CollectionService:GetTagged(TAG)) do track(z) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

local function newLine(e)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow, part.Transparency, part.Size = false, 1, Vector3.new(0.2, 0.2, 0.2)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.22, 0), Vector3.new(0, -0.22, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime, tr.MinLength, tr.FaceCamera = 0.55, 0.05, true
	tr.WidthScale = NumberSequence.new({ kp(0, 0.15), kp(0.35, 1), kp(1, 0.1) })
	tr.Transparency = NumberSequence.new({ kp(0, 1), kp(0.12, 0.25), kp(0.7, 0.6), kp(1, 1) })
	tr.Color = ColorSequence.new(Color3.fromRGB(240, 252, 255))
	tr.LightEmission = 0.45
	tr.Parent = part
	return {
		Part = part, T0 = os.clock(), Dur = 0.9 + math.random() * 0.45,
		X = (math.random() - 0.5) * e.Width, Y0 = 0.6 + math.random() * 2.6,
		Dist = 22 + math.random() * 12, Drop = 9 + math.random() * 9,
		Wob = 0.5 + math.random() * 1.1, Freq = 5 + math.random() * 4, Ph = math.random() * 6.28,
	}
end

RunService.Heartbeat:Connect(function(dt)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	for zone, e in pairs(edges) do
		if not zone:IsDescendantOf(workspace) then
			untrack(zone)
		else
			local base = zone.Position + e.Dir * e.Reach - UP_V * (zone.Size.Y / 2)   -- the middle of the edge, at floor
			if root and (root.Position - zone.Position).Magnitude < NEAR then
				e.Acc += dt * LINES_PER_SECOND
				while e.Acc >= 1 do
					e.Acc -= 1
					local r = newLine(e)
					r.Part.CFrame = CFrame.new(base + e.Side * r.X + UP_V * r.Y0 - e.Dir * 2)
					r.Part.Parent = fx
					table.insert(e.Runners, r)
				end
			else
				e.Acc = 0
			end
			for i = #e.Runners, 1, -1 do
				local r = e.Runners[i]
				local s = (now - r.T0) / r.Dur
				if s >= 1 then
					r.Part:Destroy()
					table.remove(e.Runners, i)
				else
					local wob = math.sin(r.Freq * s * r.Dur + r.Ph) * r.Wob * s
					r.Part.CFrame = CFrame.new(base + e.Side * (r.X + wob) + e.Dir * (-2 + r.Dist * s)
						+ UP_V * (r.Y0 - r.Drop * s * s))
				end
			end
		end
	end
end)
