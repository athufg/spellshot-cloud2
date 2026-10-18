--[[
	RadiantFloat  (ReplicatedStorage.IceMagic.RadiantFloat, ModuleScript, CLIENT ONLY)   Radiant Phase 5, 2026-09-29

	HALO's float (the owner, confirmed): while the local character's Halo is up -- the replicated HaloUntil attribute
	(server time) is still ahead -- gravity is scaled by RadiantTuning.Halo.FloatGravity (0.5: a VectorForce on the
	HumanoidRootPart holds up the rest, the GustJumpMotor glide's way) and the fall is capped at Halo.FallCap studs/s
	(12: the caster glides down with the wings out). Both end with the Halo (6 s, the 60 HP cap, recast, lost), on
	death, on a new character, or when the player's Element is no longer "Radiant".

	The client owns its character's physics, so this runs where MovementController does, on the same body:
	  - in the air only: on the ground the force is 0 (walking, stepping, the slide and the ground jump are untouched;
	    the jump leaves the ground at its normal speed and then flies under the lighter gravity: apex ~14.4 studs);
	  - suspended while DashMotor or a Skyrider ride (ZephyrClient.IsActive, 2026-10-08; GustJumpMotor before it) move
	    the body (their own forces / velocity writes win), and while
	    any reason given to RadiantFloat.Suspend(reason, true) is held -- MovementController holds "WallRun"
	    during its wall run (wired 2026-09-29) (it rewrites the velocity every Heartbeat, but between its frames the half-gravity force
	    would add a slight upward drift); the double jump / wall jump keep their launch speeds (they go higher);
	  - the cap: v.Y below -FallCap is set back to -FallCap, and at the cap the force carries the full weight so the
	    body does not overshoot between Heartbeats.

	API: RadiantFloat.Start() (idempotent: hooks the local player; call once, e.g. from RadiantClient's init)
	     RadiantFloat.Stop()  RadiantFloat.Suspend(reason, on)  RadiantFloat.IsActive() -> boolean
	Tuning (new fields, proposed): RadiantTuning.Halo.FloatGravity = 0.5, RadiantTuning.Halo.FallCap = 12
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RadiantFloat = {}

local FORCE_NAME, ATT_NAME = "RadiantFloatForce", "RadiantFloatAttachment"
local DEFAULT_GRAVITY, DEFAULT_CAP = 0.5, 12

local player = Players.LocalPlayer
local suspended = {}
local state = { Root = nil, Att = nil, Force = nil, Active = false }
local stepConn, charConn, attrConn, elemConn = nil, nil, nil, nil

-- tuning (read every step, so a live edit applies)
local tuning = nil
local function halo()
	if tuning == nil then
		tuning = false
		local m = script.Parent:FindFirstChild("RadiantTuning")
		if m then
			local ok, t = pcall(require, m)
			if ok and type(t) == "table" then tuning = t end
		end
	end
	return tuning and type(tuning.Halo) == "table" and tuning.Halo or nil
end

-- the motors that own the body while they run (optional: absent modules just never suspend)
-- 2026-10-08: Zephyr's is Skyrider's ride, asked through IceMagic.ZephyrClient.IsActive as MovementController asks it.
-- Spellshot.GustJumpMotor stood here until now; it left with Gust Jump on 2026-10-06, so nothing held the float -- its
-- lift, and its fall cap (12) on a dive that can reach ~31 studs/s -- off under a ride.
-- (IsActive answers for a Gust Pad's launch too -- the grab and the rise to its apex -- so the float adds nothing to that rise.)
local motors = nil
local function motorActive()
	if motors == nil then
		motors = {}
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		for _, at in ipairs({ { folder, "DashMotor" }, { script.Parent, "ZephyrClient" } }) do
			local m = at[1] and at[1]:FindFirstChild(at[2])
			if m then
				local ok, mod = pcall(require, m)
				if ok and type(mod) == "table" and type(mod.IsActive) == "function" then motors[#motors + 1] = mod end
			end
		end
	end
	for _, mod in ipairs(motors) do
		local ok, on = pcall(mod.IsActive)
		if ok and on then return true end
	end
	return false
end

--- remove only what this module made (by reference)
local function clear()
	if state.Force then state.Force:Destroy() end
	if state.Att then state.Att:Destroy() end
	state.Force, state.Att, state.Root, state.Active = nil, nil, nil, false
end

local function haloUp(c)
	if player:GetAttribute("Element") ~= "Radiant" then return false end
	local u = c:GetAttribute("HaloUntil")
	return type(u) == "number" and u > workspace:GetServerTimeNow()
end

local function step()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (c and hum and root and root:IsA("BasePart") and hum.Health > 0 and haloUp(c)) then
		clear()
		if stepConn then
			stepConn:Disconnect()
			stepConn = nil
		end
		return
	end
	if state.Root ~= root or not (state.Force and state.Force.Parent) then
		clear()
		local att = Instance.new("Attachment")
		att.Name = ATT_NAME
		att.Parent = root
		local f = Instance.new("VectorForce")
		f.Name = FORCE_NAME
		f.Attachment0 = att
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Force = Vector3.zero
		f.Parent = root
		state.Root, state.Att, state.Force = root, att, f
	end
	state.Active = true
	local H = halo()
	local gs = H and type(H.FloatGravity) == "number" and H.FloatGravity or DEFAULT_GRAVITY
	local cap = H and type(H.FallCap) == "number" and H.FallCap or DEFAULT_CAP
	-- airborne from the take-off frame: FloorMaterial keeps reporting the floor for ~4 frames after a jump, which cost the
	-- Halo jump ~20% of its apex (+11.6 measured, not +14.4); the Jumping / Freefall states are set on take-off (review
	-- fix 2026-09-29). Otherwise on the ground the force stays 0 (stairs, the slide).
	local st = hum:GetState()
	local airborne = hum.FloorMaterial == Enum.Material.Air
		or st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
	if not airborne or next(suspended) ~= nil or motorActive() then
		if state.Force.Force ~= Vector3.zero then state.Force.Force = Vector3.zero end
		return
	end
	local weight = root.AssemblyMass * workspace.Gravity
	local v = root.AssemblyLinearVelocity
	local lift = weight * (1 - gs)
	if cap > 0 and v.Y <= -cap then
		root.AssemblyLinearVelocity = Vector3.new(v.X, -cap, v.Z)
		lift = weight                                   -- at the cap: no more speed gained between our frames
	end
	local want = Vector3.new(0, lift, 0)
	if state.Force.Force ~= want then state.Force.Force = want end
end

local function wake()
	if not stepConn then stepConn = RunService.Heartbeat:Connect(step) end
end

local function watch(c)
	if attrConn then
		attrConn:Disconnect()
		attrConn = nil
	end
	clear()
	if not c then return end
	attrConn = c:GetAttributeChangedSignal("HaloUntil"):Connect(wake)
	if c:GetAttribute("HaloUntil") then wake() end
end

function RadiantFloat.Start()
	if charConn then return end
	charConn = player.CharacterAdded:Connect(watch)
	elemConn = player:GetAttributeChangedSignal("Element"):Connect(wake)   -- the step drops it when not Radiant
	watch(player.Character)
end

function RadiantFloat.Stop()
	for _, cn in ipairs({ charConn, elemConn, attrConn, stepConn }) do
		if cn then cn:Disconnect() end
	end
	charConn, elemConn, attrConn, stepConn = nil, nil, nil, nil
	clear()
end

--- hold (on = true) or release a reason the float must not act (e.g. "WallRun" from MovementController)
function RadiantFloat.Suspend(reason, on)
	suspended[reason] = on and true or nil
end

function RadiantFloat.IsActive()
	return state.Active
end

return RadiantFloat
