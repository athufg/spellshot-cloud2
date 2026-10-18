--[[
	AllyDummies  (Script)  ->  ServerScriptService/AllyDummies

	ALLY DUMMIES (2026-09-30, the owner: "add few ally dummies too so i can test our radiant/other future support
	elements on them"). Practice ALLIES for every support kit, not a Radiant special case.

	An ally dummy is a Model with a Humanoid, a Head, a HumanoidRootPart and these attributes:
	  AllyDummy = true
	  Zone, Map  where it stands, the same values a player carries there ("Arena" / "TrainingGround" on the range)
	What that means is decided once, in CombatCore, for every kit:
	  Core.IsFriendly  true for everyone: nothing may hurt one (no damage, no hostile status)
	  Core.IsAllyOf    true for a player in its Zone and party (Core.SameParty: its Map, and no duel): so Blessing,
	                   Benediction, Halo's share and anything a future support kit gives allies reaches it
	  Core.Heal        heals it (only TrainingDummy, the enemy dummies, is refused)
	Position Trade may swap with one (RadiantHandler's swappable asks Core.IsAllyOf). A heal's "+N" is RadiantHandler's
	heal readout (Core.OnHeal), not this script's.

	This script only keeps them TESTABLE: the ink-outlined bar over the head (the enemy dummies' style, "ALLY DUMMY" in
	teal), and a slow drain so there is always something to heal. They start at CONFIG.StartPct of MaxHealth, lose
	CONFIG.DrainPerSecond down to CONFIG.FloorPct, never die and never refill.

	On the range: workspace.TrainingGround.AllyDummies (Ally_Near1, Ally_Near2 within Benediction's 25 studs of the
	spawn pad; Ally_Far 33 studs out, past it).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))

local CONFIG = {
	StartPct = 0.50,         -- health at setup, a fraction of MaxHealth (a player's: Config.MaxHealth)
	FloorPct = 0.25,         -- the drain stops here, and nothing takes one lower: they never die
	DrainPerSecond = 4,      -- health lost per second while above the floor; only a heal raises it again
	Tick = 0.25,             -- seconds between drain steps
}

local INK = Color3.fromRGB(17, 17, 17)
local WHITE = Color3.new(1, 1, 1)
local TEAL = Color3.fromRGB(38, 196, 186)

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local done = setmetatable({}, { __mode = "k" })

local function setup(model)
	if done[model] or not model:IsA("Model") then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and head and root) then return end
	done[model] = true

	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth * CONFIG.StartPct
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	-- the bar: the enemy dummies' (TrainingGround), in studs so it shrinks with distance, teal and titled ALLY DUMMY
	local bb = make("BillboardGui", {
		Name = "AllyDummyBar", Adornee = head, Size = UDim2.fromScale(3.6, 1.1), StudsOffset = Vector3.new(0, 2.1, 0),
		LightInfluence = 0, MaxDistance = 160,
	}, head)
	local title = make("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.42), Font = Enum.Font.GothamBlack,
		Text = "ALLY DUMMY", TextColor3 = TEAL, TextScaled = true,
	}, bb)
	make("UIStroke", { Color = INK, Thickness = 1.2 }, title)
	local trough = make("Frame", {
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromScale(0.04, 0.5), Size = UDim2.fromScale(0.92, 0.46),
	}, bb)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, trough)
	make("UIStroke", { Color = INK, Thickness = 1.5 }, trough)
	local fill = make("Frame", { BackgroundColor3 = TEAL, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, trough)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, fill)
	local number = make("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.9), Position = UDim2.fromScale(0, 0.05),
		Font = Enum.Font.LuckiestGuy, Text = "", TextColor3 = WHITE, TextScaled = true, ZIndex = 2,
	}, trough)
	make("UIStroke", { Color = INK, Thickness = 1 }, number)

	local function floorHealth()
		return humanoid.MaxHealth * CONFIG.FloorPct
	end
	local function refresh()
		fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		number.Text = tostring(math.max(0, math.floor(humanoid.Health + 0.5)))
	end
	humanoid.HealthChanged:Connect(function(health)
		refresh()
		-- nothing should hurt one (Core.IsFriendly), but anything that did is put back to the floor: they never die
		if health < floorHealth() - 1e-3 then
			task.defer(function()
				if humanoid.Health < floorHealth() then humanoid.Health = floorHealth() end
			end)
		end
	end)
	refresh()

	task.spawn(function()
		while model.Parent do
			task.wait(CONFIG.Tick)
			local f = floorHealth()
			if humanoid.Health > f then
				humanoid.Health = math.max(f, humanoid.Health - CONFIG.DrainPerSecond * CONFIG.Tick)
			end
		end
	end)
end

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("AllyDummy") then setup(d) end
end
workspace.DescendantAdded:Connect(function(d)
	-- a model's parts arrive after the model itself: give it a moment before looking for its Humanoid
	if d:IsA("Model") and d:GetAttribute("AllyDummy") then task.defer(setup, d) end
end)
