--[[
	FrostDragonKillHook (Script) -> ServerScriptService/FrostDragonKillHook

	The Frost Dragon (Mythic) kill effect's one hook: on a kill by a Frost Dragon caster, stamp the killer's character with
	KillFX (the kill's server time) and KillFXVictim (the victim model's name). Attributes replicate to every client, and
	each client's FrostDragonKillFX plays "Dragon's Pass" there -- the way Pyro's kill visual rides PassiveProc.
	Cosmetic only: no damage, timing or state is read or changed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

Core.OnKill(function(caster, victimHumanoid)
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	local character = caster.Character
	local victim = victimHumanoid and victimHumanoid.Parent
	if not (character and character.Parent and victim) or victim == character then return end
	if (caster:GetAttribute("Element") or "Cryo") ~= "Cryo" then return end          -- (a borrowed Cryo Technique: Default)
	if SkinCatalog.ElementSkin(caster, "Cryo") ~= "FrostDragon" then return end
	-- the victim by reference (a dummy lives inside workspace.TrainingGround, and names repeat), then by name, then the stamp
	local ref = character:FindFirstChild("KillFXVictimRef") or Instance.new("ObjectValue")
	ref.Name = "KillFXVictimRef"
	ref.Value = victim
	ref.Parent = character
	character:SetAttribute("KillFXVictim", victim.Name)
	character:SetAttribute("KillFX", workspace:GetServerTimeNow())
end)
