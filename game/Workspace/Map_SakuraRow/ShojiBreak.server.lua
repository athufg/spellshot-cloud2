--[[
	ShojiBreak (Map_SakuraRow): the shoji windows break when a player runs into them.

	Every window is a Model with the attribute Shoji. Its Paper part fills the opening and collides; its
	Trigger part is a non-colliding box round the Paper, reaching 4 studs out on both sides. A player whose
	root is inside a Trigger and moving INTO the panel at BREAK_SPEED or faster breaks it: the panel goes
	see-through and stops colliding, a few paper and lattice bits fly the way they were going, and the
	model's Broken attribute turns true so it never fires again.

	- BREAK_SPEED is the movement kit's WallRunMinSpeed (16 today): breaking through is the same commitment
	  as catching a wall.
	- The speed is read on the approach, not on contact: a body that touches a solid panel has already been
	  stopped by it.
	- Only the part of the velocity INTO the panel counts, so a wall run along the building passes a window
	  without breaking it.
	- A broken window stays broken for the life of the server. There is no round reset.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, config = pcall(require, ReplicatedStorage.Spellshot.SpellshotConfig)
local BREAK_SPEED = ok and config.Movement and config.Movement.WallRunMinSpeed or 16

local map = script.Parent
local rng = Random.new()
local watching = {} -- [shoji] = { [character] = true } while that player's body is inside its Trigger

-- How fast `root` is moving into the panel, and which way "into" is (0 when moving away or along it).
local function speedInto(shoji, root)
	local paper = shoji.Paper
	local n = paper.CFrame.LookVector
	local side = (paper.Position - root.Position):Dot(n)
	local vn = root.AssemblyLinearVelocity:Dot(n)
	if side * vn <= 0 then return 0, n end
	return math.abs(vn), vn > 0 and n or -n
end

local function shatter(shoji, dir, speed)
	shoji:SetAttribute("Broken", true)
	watching[shoji] = nil
	local paper = shoji.Paper
	local wood = shoji.Bar_V1.Color
	for _, p in ipairs(shoji:GetChildren()) do
		if p:IsA("BasePart") then
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	for i = 1, 8 do
		local bit = Instance.new("Part")
		if i <= 5 then
			bit.Name = "PaperBit"
			bit.Size = Vector3.new(rng:NextNumber(0.6, 1.4), rng:NextNumber(0.6, 1.4), 0.1)
			bit.Color = paper.Color
		else
			bit.Name = "LatticeBit"
			bit.Size = Vector3.new(0.25, rng:NextNumber(1, 2.5), 0.25)
			bit.Color = wood
		end
		bit.Material = Enum.Material.SmoothPlastic
		bit.CanQuery = false
		bit.CanTouch = false
		bit.CFrame = paper.CFrame * CFrame.new(rng:NextNumber(-2, 2), rng:NextNumber(-2.5, 2.5), 0)
			* CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), 0)
		bit.Parent = shoji
		bit.AssemblyLinearVelocity = dir * speed * rng:NextNumber(0.5, 0.9)
			+ Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(3, 10), rng:NextNumber(-5, 5))
		bit.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		Debris:AddItem(bit, 3)
	end
end

-- Touched only starts the watch; the check runs every frame while the body stays inside, so a player who
-- stood in the box and then sprinted at the panel still breaks it.
local function onTouched(shoji, hit)
	if shoji:GetAttribute("Broken") then return end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not (character and Players:GetPlayerFromCharacter(character)) then return end -- players only
	watching[shoji] = watching[shoji] or {}
	watching[shoji][character] = true
end

for _, shoji in ipairs(map:GetDescendants()) do
	if shoji:IsA("Model") and shoji:GetAttribute("Shoji") then
		shoji.Trigger.Touched:Connect(function(hit)
			onTouched(shoji, hit)
		end)
	end
end

RunService.Heartbeat:Connect(function()
	for shoji, characters in pairs(watching) do
		local trigger = shoji.Trigger
		-- the root sits inside the body, a little in from where the limbs first touch
		local half = trigger.Size / 2 + Vector3.new(1.5, 3, 1.5)
		for character in pairs(characters) do
			local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rel = root and trigger.CFrame:PointToObjectSpace(root.Position)
			if not rel or not humanoid or humanoid.Health <= 0
				or math.abs(rel.X) > half.X or math.abs(rel.Y) > half.Y or math.abs(rel.Z) > half.Z then
				characters[character] = nil
			else
				local speed, dir = speedInto(shoji, root)
				if speed >= BREAK_SPEED then
					shatter(shoji, dir, speed)
					break
				end
			end
		end
		if watching[shoji] and next(characters) == nil then watching[shoji] = nil end
	end
end)
