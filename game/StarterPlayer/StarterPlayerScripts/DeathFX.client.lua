--[[
	DeathFX  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/DeathFX

	What a death sounds and looks like, on every client, for every player's character: nothing you
	can hear, one thing you can see.

	SOUND. Roblox injects RbxCharacterSounds into every client's PlayerScripts. It builds an
	unreplicated Sound (an AudioPlayer on the new audio API) named "Died" under each character's
	HumanoidRootPart and plays it when the Humanoid enters the Dead state -- the "oof". The instance
	is fully configured before it is parented and its Volume is never written again, so pinning
	Volume to 0 the moment it appears is the whole fix. Forking RbxCharacterSounds instead would take
	footsteps, jump and land down with it; those are left exactly as they were. The server never sees
	these sounds, so this can only be done per client.

	EFFECT. One flat comic stamp: the kit's plain white impact burst (PopArtAssets.Overlay.Burst, the
	image behind the training dummies' KO! callout) pops once over the body and cuts. Same for every
	Element. Under Reduce Flashing it is half the size and half the opacity, with no pop (2026-10-19). Fired from Humanoid.Died, which every client already receives -- no remote, no server
	change.

	EXACTLY ONCE. One hook per character model, and Died:Once on it. Nothing is written to any
	character part, so there is nothing to restore on respawn; the stamp's Attachment is on Debris,
	and dies with the corpse anyway if that goes first.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("PopArtAssets"))
-- (2026-10-19, audit P6B-19 / P5F-03) Reduce Flashing calms the stamp (see stamp)
local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

local STAMP_LIFE = 0.45   -- seconds the burst is on screen
local STAMP_SIZE = 5.6    -- studs across once settled: about one character tall

local hooked = setmetatable({}, { __mode = "k" })   -- [character] = true

----------------------------------------------------------------------------------------------------
-- the stock death sound
----------------------------------------------------------------------------------------------------
-- Matched by name and class, not by position, so this does not depend on where the stock script
-- parents it.
local function muteDied(inst)
	if inst.Name == "Died" and (inst:IsA("Sound") or inst:IsA("AudioPlayer")) then
		inst.Volume = 0
	end
end

local function muteAll(character)
	for _, d in ipairs(character:GetDescendants()) do
		muteDied(d)
	end
end

----------------------------------------------------------------------------------------------------
-- the stamp
----------------------------------------------------------------------------------------------------
local function stamp(root)
	local att = Instance.new("Attachment")
	att.Name = "DeathBurst"
	att.Parent = root

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Art.Overlay.Burst
	pe.LightEmission = 0          -- alpha-blended, so the ink rim stays ink
	pe.LightInfluence = 0         -- unlit: flat colour
	-- (2026-10-19, audit P6B-19 / P5F-03) Reduce Flashing: half the size and half the opacity, held flat -- no scale pop
	-- (FrostDragonKillFX's calm rule)
	local calm = Settings.Get and Settings.Get("ReduceFlashing")
	if calm then
		pe.Size = NumberSequence.new(STAMP_SIZE * 0.5)
	else
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, STAMP_SIZE * 0.4),
			NumberSequenceKeypoint.new(0.2, STAMP_SIZE * 1.15),   -- overshoot
			NumberSequenceKeypoint.new(0.5, STAMP_SIZE),          -- settle
			NumberSequenceKeypoint.new(1, STAMP_SIZE),
		})
	end
	local base = calm and 0.5 or 0
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, base),
		NumberSequenceKeypoint.new(0.92, base),
		NumberSequenceKeypoint.new(1, 1),                     -- hard cut, no tail
	})
	pe.Lifetime = NumberRange.new(STAMP_LIFE)
	pe.Speed = NumberRange.new(0)
	pe.Rotation = NumberRange.new(-3)    -- fixed, so the baked drop shadow keeps pointing down-right
	pe.RotSpeed = NumberRange.new(0)
	pe.ZOffset = 1                       -- in front of the torso it sits inside
	pe.Enabled = false                   -- never emits on its own; Emit below is the only particle
	pe.Parent = att

	pe:Emit(1)
	Debris:AddItem(att, STAMP_LIFE + 0.5)
end

----------------------------------------------------------------------------------------------------
-- per character
----------------------------------------------------------------------------------------------------
local function watch(character)
	if hooked[character] then return end
	hooked[character] = true

	-- connect first, scan second, with no yield between: silent whichever of this script and
	-- RbxCharacterSounds got to the character first
	character.DescendantAdded:Connect(muteDied)
	muteAll(character)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.Died:Once(function()
		muteAll(character)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then stamp(root) end
	end)
end

local function hook(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(watch, character)
	end)
	if player.Character then task.spawn(watch, player.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do hook(p) end
Players.PlayerAdded:Connect(hook)
