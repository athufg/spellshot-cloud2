--[[
	HubLifeServer  (Script)  ->  ServerScriptService/HubLifeServer

	THE HUB, ALIVE -- the one server piece (2026-10-25, the owner's hub-rebuild brief, step 3): the Loadout altar's prompt
	("G - Loadout Altar - Choose Techniques", made by HubServer on its TechniqueTablePrompt anchor) moves from over the
	altar to beside the Loadout Keeper (HubLife.NPC.Keeper), so it fires on the NPC's proximity; the altar stays as
	dressing. The prompt itself, its texts, its reach and what it opens are HubServer's and are not touched. HubNPCs (on each
	client) hides it until the Keeper's greet has landed.
	Runs only while HubLife.On() (Studio until the owner's review): on a published server the prompt stays over the altar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubLife = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("HubLife"))
if not HubLife.On() then return end

local hub = workspace:WaitForChild(HubLife.Hub, 60)
local anchor = hub and hub:WaitForChild("TechniqueTablePrompt", 60)
if anchor and anchor:IsA("BasePart") then
	anchor:SetAttribute("HubLifeHome", anchor.Position)
	anchor.CFrame = HubLife.NPC.Keeper.CFrame * HubLife.NPC.Keeper.PromptAt
end
