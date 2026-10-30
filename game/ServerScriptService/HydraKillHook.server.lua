--[[
	HydraKillHook (Script) -> ServerScriptService/HydraKillHook

	The Hydra (Toxin's Mythic) kill effect's one hook, on FrostDragonKillHook's pattern: on a kill by a Hydra caster,
	stamp the killer's character with HydraKillFX (the kill's server time), HydraKillFXVictim (the victim model's name)
	and HydraKillFXVictimRef (an ObjectValue: the victim itself -- a dummy's name can repeat). Attributes replicate to
	every client, and each client's HydraFX plays "The Hydra's Due" there. Its own attribute names, not KillFX: Frost
	Dragon's client effect listens on KillFX. Cosmetic only: no damage, timing or state is read or changed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(script.Parent:WaitForChild("CombatCore"))
local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

Core.OnKill(function(caster, victimHumanoid)
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	local character = caster.Character
	local victim = victimHumanoid and victimHumanoid.Parent
	if not (character and character.Parent and victim) or victim == character then return end
	if caster:GetAttribute("Element") ~= "Toxin" then return end                    -- (a borrowed Toxin Technique: Default)
	if SkinCatalog.ElementSkin(caster, "Toxin") ~= "Hydra" then return end
	-- the victim by reference (a dummy lives inside workspace.TrainingGround, and names repeat), then by name, then the stamp
	local ref = character:FindFirstChild("HydraKillFXVictimRef") or Instance.new("ObjectValue")
	ref.Name = "HydraKillFXVictimRef"
	ref.Value = victim
	ref.Parent = character
	character:SetAttribute("HydraKillFXVictim", victim.Name)
	character:SetAttribute("HydraKillFX", workspace:GetServerTimeNow())
end)
