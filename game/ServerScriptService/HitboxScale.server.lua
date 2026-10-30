--[[
	HitboxScale  (Script)  ->  ServerScriptService/HitboxScale

	BIGGER HITBOXES (2026-10-17, the owner: "increase the hitbox of the characters by 30% (increase for dummies too so
	i can test)"). Every visible body part of every character and dummy -- any Model with a Humanoid in workspace, but a
	Bulwark Wall -- gets an invisible TWIN: Config.Hitbox.Scale times the part's size in every direction, welded on at the
	same centre. Shots and spatial queries hit a twin; nothing collides with it or touches it, and it weighs nothing.
	Every kit finds whose body it hit with FindFirstAncestorOfClass("Model"), so a twin counts as that body. Umbra's
	isHeadshot takes a twin whose HitboxOf is "Head" as the head, and CombatCore's REACH grows by the same scale.

	Twins sit in a Folder "Hitboxes" in the model, named "<part>Hitbox", with HitboxOf = the part's name and the tag
	"Hitbox". They stay at Transparency 1 -- this script puts back anything that changes it, as HitboxGuard does on each
	client -- or at Config.Hitbox.ShowAlpha while workspace's "ShowHitboxes" attribute is true (for testing).
	A body part replaced later (UniformAvatar's ApplyDescription) gets a new twin; a twin goes with its part.
	AREA EFFECTS TOO (2026-10-19, audit P3-16: written down, not changed -- the owner's call). A twin is CanQuery, so every
	area check that asks for parts in a radius (CombatCore.HumanoidsNear: Flash Freeze, Fireball splash, Volt Orb, Charged
	discharge and Chain Bolt legs, the clouds, pads and zones) reaches a body up to (Scale - 1) x half a part further out;
	the checks that measure root distance (Cascade, Combustion, Deep Freeze, Blizzard) do not, and nor do raycasts that
	respect CanCollide (twins never collide). To keep areas at 1x, HumanoidsNear would skip parts tagged "Hitbox".
	A DEAD PLAYER's body stops answering queries (2026-10-19, audit P6B-10): CanQuery off on its parts and twins.
	To take it out: Config.Hitbox.Scale = 1 (nothing is built), or delete this and StarterPlayerScripts.HitboxGuard.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
local H = Config.Hitbox or {}
local SCALE = H.Scale or 1
if SCALE == 1 then return end

local TAG = "Hitbox"

local function alpha()
	return workspace:GetAttribute("ShowHitboxes") == true and (H.ShowAlpha or 0.6) or 1
end

local function isBody(part)
	return part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1
end

local twins = setmetatable({}, { __mode = "k" })     -- [body part] = its twin

local function addTwin(model, folder, part)
	if twins[part] and twins[part].Parent then return end
	local t = Instance.new("Part")
	t.Name = part.Name .. "Hitbox"
	t.Size = part.Size * SCALE
	t.CFrame = part.CFrame
	t.Color = Color3.fromRGB(255, 70, 70)
	t.Material = Enum.Material.SmoothPlastic
	t.Transparency = alpha()
	t.CanCollide, t.CanTouch, t.CanQuery = false, false, true
	t.Massless, t.Anchored, t.CastShadow = true, false, false
	t.CollisionGroup = part.CollisionGroup
	t:SetAttribute("HitboxOf", part.Name)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = part, t
	weld.Parent = t
	CollectionService:AddTag(t, TAG)
	t.Parent = folder
	twins[part] = t
	t:GetPropertyChangedSignal("Transparency"):Connect(function()
		local want = alpha()
		if t.Transparency ~= want then t.Transparency = want end
	end)
	part:GetPropertyChangedSignal("Size"):Connect(function() t.Size = part.Size * SCALE end)
	part:GetPropertyChangedSignal("CollisionGroup"):Connect(function() t.CollisionGroup = part.CollisionGroup end)
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(model) then t:Destroy() end
	end)
end

local done = setmetatable({}, { __mode = "k" })

local function setup(model)
	if done[model] or not model:IsA("Model") or model:GetAttribute("WallOwner") then return end
	done[model] = true
	-- a copy of a body (a decoy) arrives with the original's twins but none of their guards: build its own
	local old = model:FindFirstChild("Hitboxes")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Hitboxes"
	folder.Parent = model
	for _, c in model:GetChildren() do
		if isBody(c) then addTwin(model, folder, c) end
	end
	model.ChildAdded:Connect(function(c)
		if isBody(c) then
			task.defer(function()
				if c.Parent == model and folder.Parent == model then addTwin(model, folder, c) end
			end)
		end
	end)
	-- (2026-10-19, audit P6B-10 / GC-01) a body is scenery, not cover (manual, Section 3): once a PLAYER's character is
	-- dead, no part of it -- the twins above all -- answers a ray or an overlap, so in a team round the body (which stays
	-- until the next round's LoadCharacter) no longer eats shots. Dummies are left alone: they refill rather than die.
	-- (Roblox ignores CanQuery on a part that still collides, so a corpse's own colliding parts keep answering; the 2x
	-- twins, which never collide, were the wide blocker.)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and Players:GetPlayerFromCharacter(model) then
		humanoid.Died:Once(function()
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then pcall(function() d.CanQuery = false end) end
			end
		end)
	end
end

local function onHumanoid(humanoid)
	local model = humanoid.Parent
	if model and model:IsDescendantOf(workspace) then setup(model) end
end

for _, d in workspace:GetDescendants() do
	if d:IsA("Humanoid") then onHumanoid(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then task.defer(onHumanoid, d) end
end)

workspace:GetAttributeChangedSignal("ShowHitboxes"):Connect(function()
	local a = alpha()
	for _, t in CollectionService:GetTagged(TAG) do
		if t:IsA("BasePart") then t.Transparency = a end
	end
end)
