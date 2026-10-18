--[[
	CombatFeedback  (Script)  ->  ServerScriptService/CombatFeedback

	The damage number, KO!, CHILL x2, BURN x2 and FROZEN! over a PLAYER.

	WHY THIS EXISTS. Every one of those callouts was built inside TrainingGround and attached only to
	models with the TrainingDummy attribute. Shooting a real player therefore did the full damage,
	stacked Chill and rooted them, and showed absolutely nothing -- which reads exactly like the
	shot not registering, and is why it looked as though hits "work on the NPCs but not on players".
	The callout builder now lives in Spellshot.Callouts and this attaches it to every player.

	SERVER SIDE, so the BillboardGui replicates and everyone sees the same callout over the same
	head at the same moment -- the shooter, the target, and anybody watching.

	WHAT IT DOES NOT DO. It does not decide anything: damage, Chill and the freeze are AbilityHandler's,
	and this only reports them. A player who dies is left dead -- Roblox respawns them -- where a
	training dummy is refilled by the range, which is the one thing that stays the range's own.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Callouts = require(folder:WaitForChild("Callouts"))

local function watch(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not (humanoid and head) then return end

	-- the number. HealthChanged also fires on healing, which is not a hit, so only a drop pops.
	local shown = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		local lost = shown - health
		shown = health
		if lost > 0.05 then
			Callouts.Pop(head, Vector3.new(0, 1.2, 0), tostring(math.floor(lost + 0.5)), "damage")
		end
	end)

	humanoid.Died:Connect(function()
		Callouts.Pop(head, Vector3.new(0, 2.8, 0), "KO!", "ko")
	end)

	-- the M1's Chill stacks as they land: CHILL x1, x2, x3 (the third is the deepest slow, 2026-10-08; it used to root
	-- and leave the word to FROZEN!, which is now kept for real freezes)
	character:GetAttributeChangedSignal("RX_Chilled_Stacks"):Connect(function()
		local n = character:GetAttribute("RX_Chilled_Stacks")
		if n and n >= 1 then
			Callouts.Pop(head, Vector3.new(0, 2.6, 0), "CHILL x" .. n, "chill")
		end
	end)

	-- Scorching Lash's burn stacks as they build (2026-09-23): BURN x1, x2, x3, in a slot of their own ("burn") so a
	-- burn never knocks a CHILL off. Only a RISE pops: the count going back to nothing as the burn goes out says nothing
	local burnShown = character:GetAttribute("RX_Burning_Stacks") or 0
	character:GetAttributeChangedSignal("RX_Burning_Stacks"):Connect(function()
		local n = character:GetAttribute("RX_Burning_Stacks") or 0
		if n > burnShown then
			Callouts.Pop(head, Vector3.new(0, 2.6, 0), "BURN x" .. n, "burn")
		end
		burnShown = n
	end)

	-- FROZEN! stays up for as long as the player is actually frozen, whatever froze it: it follows
	-- the IceFrozenState that VFXLibrary.ApplyFrozenState puts on the character and lets go when
	-- that goes. A re-freeze replaces the state object, so a removal is only believed if nothing
	-- replaced it that frame.
	local releaseFrozen
	local function freezeChanged()
		local frozen = character:FindFirstChild("IceFrozenState") ~= nil
		if frozen and not releaseFrozen then
			releaseFrozen = Callouts.Pop(head, Vector3.new(0, 2.6, 0), "FROZEN!", "frozen", true)
		elseif not frozen and releaseFrozen then
			releaseFrozen()
			releaseFrozen = nil
		end
	end
	character.ChildAdded:Connect(function(c)
		if c.Name == "IceFrozenState" then freezeChanged() end
	end)
	character.ChildRemoved:Connect(function(c)
		if c.Name == "IceFrozenState" then task.defer(freezeChanged) end
	end)
	freezeChanged()
end

local function follow(player)
	if player.Character then task.spawn(watch, player.Character) end
	player.CharacterAdded:Connect(watch)
end

for _, p in ipairs(Players:GetPlayers()) do follow(p) end
Players.PlayerAdded:Connect(follow)
