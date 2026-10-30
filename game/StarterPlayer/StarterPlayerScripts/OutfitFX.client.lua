--[[
	OutfitFX  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/OutfitFX

	AN OUTFIT'S FEW EMITTERS, KEPT HONEST (2026-10-29; OUTFIT_SPEC section 4.6). A premium Outfit (ServerStorage.Outfits,
	worn by ElementCoat instead of the Element coat) may carry up to two tiny ParticleEmitters -- embers / glints, marked
	with the attribute OutfitFX = true by install_outfits.lua. On every client, each one is:
	  * OFF while its wearer is dead (a corpse does not smoulder; the round's body lies until the next spawn);
	  * OFF on the local player's own body in FIRST PERSON: FirstPersonController hides the body with
	    LocalTransparencyModifier, which does not stop particles, so specks would float at the lens. First person = the
	    camera within FP_DIST of the head (FirstPersonController's LockFirstPerson camera sits in the head; third person,
	    the Wardrobe editor and the showcase cameras stand well off it);
	  * otherwise ON (the server's value: install_outfits leaves them enabled).
	Client-side writes never replicate: each viewer decides for themselves. Nothing here exists until an outfit is worn.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FP_DIST = 2.5          -- studs from the head: closer = first person
local EVERY = 0.1            -- seconds between checks

local tracked = {}           -- [ParticleEmitter] = the character it is on

local function consider(d, character)
	if d:IsA("ParticleEmitter") and d:GetAttribute("OutfitFX") then tracked[d] = character end
end

local function watchCharacter(character)
	for _, d in ipairs(character:GetDescendants()) do consider(d, character) end
	character.DescendantAdded:Connect(function(d) consider(d, character) end)
end
local function watchPlayer(p)
	if p.Character then watchCharacter(p.Character) end
	p.CharacterAdded:Connect(watchCharacter)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

local function alive(character)
	local h = character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and h:GetState() ~= Enum.HumanoidStateType.Dead
end

local function firstPerson(character)
	if character ~= player.Character then return false end
	local cam = workspace.CurrentCamera
	local head = character:FindFirstChild("Head")
	return cam ~= nil and head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < FP_DIST
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < EVERY or next(tracked) == nil then return end
	acc = 0
	local state = {}      -- [character] = on (each character worked out once)
	for e, character in pairs(tracked) do
		if not e:IsDescendantOf(workspace) then
			tracked[e] = nil
		else
			local on = state[character]
			if on == nil then
				on = alive(character) and not firstPerson(character)
				state[character] = on
			end
			if e.Enabled ~= on then e.Enabled = on end
		end
	end
end)
