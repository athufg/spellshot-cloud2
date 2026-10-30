--[[
	OutfitSway (LocalScript, StarterPlayerScripts) -- 2026-10-29, the owner's brief: the Frostbound Sovereign's royal cape
	(and the Crimson Carnival Jester's bell tails) trail and billow as the wearer moves and turns, never a rigid mesh.

	Roblox has no cloth simulation for accessories, so (the brief's own fallback) the pieces are skinned meshes
	(hub/outfit_extras_2026_10_29: an armature, root "CapeRoot" / "TailRoot", bone chains <Root-prefix><Column><Row>,
	e.g. CapeL1..CapeL4) and this script swings their bones, on this client, about the wearer's own axes,
	for every character in view:
	  * two damped springs per rig, driven by the wearer's own motion: LIFT (the hem trails back and up with forward
	    speed, flutters when airborne) and SWAY (it swings out against a turn or a sidestep);
	  * each row bends a little more than the one above (Weight), with a slow travelling ripple that grows with speed;
	  * hard caps (MaxLift / MaxSway): the cape never flies up over the wearer's head or across a neighbour's view.
	Bone.Transform only (client-side, nothing replicates). Nothing beyond Tuning.Far studs from the camera; every
	rig at rest when its wearer stands still.

	PATCH 2 (2026-10-30, installed):
	
	with ONE change: a rig whose Accessory carries SwayTowardBodyMaxDeg (install_capes_p2.lua sets 1.0 on the Thunder
	Regalia cape, which hangs only ~0.06-0.13 off the jacket: +2 deg per bone already touches the hip) never swings a
	bone toward the wearer's body by more than that many degrees (each bone's pitch is clamped; the bones compound down
	the chain, exactly as the designer measured it). Lift away from the body and the sideways sway are unchanged.
	Positive pitch = toward the body (about the wearer's Right axis, a hanging hem moves forward, -Z).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Far = 140,                      -- studs from the camera: further away nothing is swung
	LiftPerSpeed = 0.035,           -- radians of lift per stud/s of forward speed
	LiftBack = 0.02,                -- walking backwards pushes the hem forward (less)
	LiftAir = 0.25,                 -- extra lift while falling / jumping (scaled by vertical speed)
	MaxLift = math.rad(62),         -- the hem never rises past this
	SwayPerSide = 0.03,             -- radians of sway per stud/s of sideways speed
	SwayPerTurn = 0.10,             -- radians of sway per rad/s of turn
	MaxSway = math.rad(24),
	Spring = { K = 38, C = 7.5 },   -- stiffness / damping of both springs (under-damped: a little overshoot)
	Weight = { 0.35, 0.65, 0.85, 1.0 },   -- share of the swing each row adds (top -> hem)
	Ripple = { Amp = math.rad(5), PerSpeed = 0.012, Rate = 6.5, Lag = 0.9 },   -- the travelling flutter
	Idle = { Amp = math.rad(1.6), Rate = 1.4 },   -- a faint breathing so it never reads as rigid
	Sign = { Lift = -1, Sway = 1 },  -- about the wearer's Right (lift: - = hem back) and Look (sway) axes
}

local rigs = {}   -- [rootBone] = rig

local function chainsOf(root)
	local prefix = root.Name:gsub("Root$", "")
	local cols = {}
	for _, b in ipairs(root.Parent:GetDescendants()) do
		if b:IsA("Bone") then
			local col, row = string.match(b.Name, "^" .. prefix .. "([LMR])(%d+)$")
			if col then
				cols[col] = cols[col] or {}
				cols[col][tonumber(row)] = b
			end
		end
	end
	local out = {}
	for col, list in pairs(cols) do
		local chain = {}
		for i = 1, #list do
			if list[i] then chain[#chain + 1] = list[i] end
		end
		out[#out + 1] = { Col = col, Bones = chain }
	end
	return out
end

local function track(root)
	if rigs[root] or not root:IsA("Bone") then return end
	local model = root:FindFirstAncestorOfClass("Model")
	-- (2026-10-30, Patch 2) a per-cape cap on the swing toward the body, in degrees per bone (nil = no cap)
	local acc = root:FindFirstAncestorOfClass("Accessory")
	local toward = acc and acc:GetAttribute("SwayTowardBodyMaxDeg")
	rigs[root] = { Root = root, Chains = chainsOf(root), Lift = 0, LiftV = 0, Sway = 0, SwayV = 0, Phase = math.random() * 6,
		Model = model, LastYaw = nil, Toward = type(toward) == "number" and math.rad(math.max(0, toward)) or nil }
	root.AncestryChanged:Connect(function()
		if not root:IsDescendantOf(workspace) then
			rigs[root] = nil
		end
	end)
end

local function scan(inst)
	if inst:IsA("Bone") and (inst.Name == "CapeRoot" or inst.Name == "TailRoot") then
		task.defer(track, inst)
	end
end

local function watchCharacter(ch)
	for _, d in ipairs(ch:GetDescendants()) do scan(d) end
	ch.DescendantAdded:Connect(scan)
end

local function watchPlayer(p)
	if p.Character then watchCharacter(p.Character) end
	p.CharacterAdded:Connect(watchCharacter)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

local function spring(x, v, target, dt)
	local a = Tuning.Spring.K * (target - x) - Tuning.Spring.C * v
	v += a * dt
	return x + v * dt, v
end

-- (2026-10-29, Play test) the character's Animator resets every Bone.Transform in PreAnimation, every frame: a write in
-- RenderStepped was gone before it rendered. PreSimulation runs after the Animator and its write is what renders.
RunService.PreSimulation:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local t = os.clock()
	for root, r in pairs(rigs) do
		local hrp = r.Model and r.Model:FindFirstChild("HumanoidRootPart")
		if not (hrp and root.Parent) then continue end
		if (hrp.Position - camPos).Magnitude > Tuning.Far then continue end
		local cf = hrp.CFrame
		local vel = hrp.AssemblyLinearVelocity
		local fwd = vel:Dot(cf.LookVector)
		local side = vel:Dot(cf.RightVector)
		local _, yaw = cf:ToOrientation()
		local turn = 0
		if r.LastYaw then
			local d = (yaw - r.LastYaw + math.pi) % (2 * math.pi) - math.pi
			turn = d / math.max(dt, 1e-3)
		end
		r.LastYaw = yaw
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local lift = (fwd >= 0 and fwd * Tuning.LiftPerSpeed or fwd * Tuning.LiftBack) + math.abs(vel.Y) * Tuning.LiftAir * 0.1
		lift = math.clamp(lift, -Tuning.MaxLift * 0.3, Tuning.MaxLift)
		local sway = math.clamp(-side * Tuning.SwayPerSide - turn * Tuning.SwayPerTurn, -Tuning.MaxSway, Tuning.MaxSway)
		r.Lift, r.LiftV = spring(r.Lift, r.LiftV, lift, dt)
		r.Sway, r.SwayV = spring(r.Sway, r.SwayV, sway, dt)
		local L = math.clamp(r.Lift, -Tuning.MaxLift * 0.3, Tuning.MaxLift)
		local S = math.clamp(r.Sway, -Tuning.MaxSway, Tuning.MaxSway)
		local rip = Tuning.Ripple.Amp * math.min(1, speed * Tuning.Ripple.PerSpeed * 10)
		local idle = Tuning.Idle.Amp * math.sin(t * Tuning.Idle.Rate + r.Phase)
		for _, ch in ipairs(r.Chains) do
			local colPh = (ch.Col == "L" and 0.6) or (ch.Col == "R" and -0.6) or 0
			for i, b in ipairs(ch.Bones) do
				local w = Tuning.Weight[i] or 1
				local wave = rip * math.sin(t * Tuning.Ripple.Rate - i * Tuning.Ripple.Lag + colPh + r.Phase)
				local pitch = Tuning.Sign.Lift * (L * w * (i == 1 and 1 or 0.55) + wave + idle * w)
				if r.Toward and pitch > r.Toward then pitch = r.Toward end   -- (Patch 2) never further into the body
				local roll = Tuning.Sign.Sway * S * w * (i == 1 and 1 or 0.5)
				-- (2026-10-29) about the WEARER's axes, carried into the bone's own frame: the import may turn bone axes
				-- (the FBX landed half-turned), so the bone-local X / Z cannot be trusted
				local base = (b.WorldCFrame * b.Transform:Inverse()).Rotation
				b.Transform = CFrame.fromAxisAngle(base:VectorToObjectSpace(cf.RightVector), pitch)
					* CFrame.fromAxisAngle(base:VectorToObjectSpace(cf.LookVector), roll)
			end
		end
	end
end)
