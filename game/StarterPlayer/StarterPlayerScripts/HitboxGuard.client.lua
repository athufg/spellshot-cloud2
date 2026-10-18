--[[
	HitboxGuard  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HitboxGuard

	Keeps the hitbox twins (ServerScriptService.HitboxScale, 2026-10-17) invisible on this client: a local script that
	fades or restores a body by setting Transparency on all its parts would otherwise show them. They draw at
	Config.Hitbox.ShowAlpha instead while workspace's "ShowHitboxes" attribute is true (for testing).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
local H = Config.Hitbox or {}

local function alpha()
	return workspace:GetAttribute("ShowHitboxes") == true and (H.ShowAlpha or 0.6) or 1
end

local function guard(t)
	if not t:IsA("BasePart") then return end
	t.Transparency = alpha()
	t:GetPropertyChangedSignal("Transparency"):Connect(function()
		local want = alpha()
		if t.Transparency ~= want then t.Transparency = want end
	end)
end

for _, t in CollectionService:GetTagged("Hitbox") do guard(t) end
CollectionService:GetInstanceAddedSignal("Hitbox"):Connect(guard)

workspace:GetAttributeChangedSignal("ShowHitboxes"):Connect(function()
	local a = alpha()
	for _, t in CollectionService:GetTagged("Hitbox") do
		if t:IsA("BasePart") then t.Transparency = a end
	end
end)
