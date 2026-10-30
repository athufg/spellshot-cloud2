--[[
	TerraTestServer  (Script)  ->  ServerScriptService/TerraTestServer

	TEMPORARY, STUDIO ONLY (it returns at once anywhere else). Delete after the Terra pass. The training range's
	practice thrower calls Humanoid:TakeDamage directly (TrainingGround.server.lua:117), so it bypasses CombatCore and
	therefore every mitigation in the
	game -- Bedrock, Bulwark Charge and Blessing alike. To test a mitigation you need damage that goes THROUGH
	CombatCore, which only a server script that can require it can send.

	Trigger: set the player attribute TerraDamage to an amount. The hit is dealt through Core.DealDamage with
	no caster, and TerraDamageResult comes back as "asked X, took Y".
]]

-- (2026-10-19, audit P6A-15) Studio only, as the Voltaic and Zephyr harnesses are: a live server gets no test damage path
if not game:GetService("RunService"):IsStudio() then return end

local Players = game:GetService("Players")
local Core = require(script.Parent:WaitForChild("CombatCore"))

local function watch(player)
	player:GetAttributeChangedSignal("TerraDamage"):Connect(function()
		local amount = player:GetAttribute("TerraDamage")
		if type(amount) ~= "number" or amount <= 0 then return end
		player:SetAttribute("TerraDamage", nil)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (humanoid and humanoid.Health > 0) then return end
		local before = humanoid.Health
		Core.DealDamage(nil, humanoid, amount, {})
		local took = before - humanoid.Health
		player:SetAttribute("TerraDamageResult", string.format("asked %.1f, took %.2f (stacks %s)",
			amount, took, tostring(character:GetAttribute("Bedrock_Stacks"))))
	end)
	-- Bulwark Wall (2026-09-19): WallDamage = an amount dealt to the standing wall through Core.DealDamage, from no caster
	-- (an enemy), coming from WallDamageFrom (a Vector3: which side of the face it lands on). WallDamageResult reports.
	player:GetAttributeChangedSignal("WallDamage"):Connect(function()
		local amount = player:GetAttribute("WallDamage")
		if type(amount) ~= "number" or amount <= 0 then return end
		player:SetAttribute("WallDamage", nil)
		local wall = workspace:FindFirstChild("BulwarkWall")
		local hum = wall and wall:FindFirstChildOfClass("Humanoid")
		if not hum then
			player:SetAttribute("WallDamageResult", "no wall")
			return
		end
		local from = player:GetAttribute("WallDamageFrom")
		local before = hum.Health
		local landed = Core.DealDamage(nil, hum, amount, { Ranged = true, From = typeof(from) == "Vector3" and from or nil })
		player:SetAttribute("WallDamageResult", string.format("asked %.1f, landed %s, wall %.2f -> %.2f", amount,
			tostring(landed), before, hum.Parent and hum.Health or -1))
	end)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
