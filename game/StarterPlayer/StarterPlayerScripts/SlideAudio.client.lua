--[[
	SlideAudio  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/SlideAudio

	A slide sounds like a slide, and stops sounding like a jog.

	THE BUG THIS FIXES. Roblox's own character sounds are driven by the Humanoid's state and its
	speed, not by what the game thinks you are doing -- so sliding with W still held kept the
	Running loop going and you slid across the floor to the sound of footsteps.

	EVERY CHARACTER, NOT JUST YOURS. The MoveState attribute is replicated, so this watches all of
	them and plays for each: you hear other players slide, positionally, and they hear you. It is
	still entirely client-side -- the sounds are local instances -- which is why the server does not
	have to know or care.

	WHY NOT PLAY IT FROM THE SERVER. A server-created Sound would replicate and be heard by
	everyone, which sounds like the same thing, but it would also cost a round trip before your own
	slide made a noise. Your slide starts on the keypress; so does its sound.

	The clip is a body sliding on dirt (Pro Sound Effects, via the Creator Store) and runs 2 s
	against a 1.1 s slide, so it is faded and stopped when the slide ends rather than left to ring
	on. It is not looped: a slide is one gesture.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local template = ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("Sounds"):WaitForChild("SFX_Slide")

local VOLUME = 0.55
local FADE = 0.18

-- what is currently sliding, so a character that dies mid-slide still gets tidied up
local live = {}          -- [character] = { sound = Sound, running = Sound, wasVolume = number }

local function stop(character)
	local rec = live[character]
	if not rec then return end
	live[character] = nil
	if rec.running and rec.running.Parent then
		rec.running.Volume = rec.wasVolume
	end
	local s = rec.sound
	if s and s.Parent then
		TweenService:Create(s, TweenInfo.new(FADE), { Volume = 0 }):Play()
		task.delay(FADE + 0.02, function()
			if s.Parent then s:Destroy() end
		end)
	end
end

local function start(character)
	if live[character] then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Roblox's own sounds are made by RbxCharacterSounds a moment after the character loads, and
	-- they live on the root part. Silence the footsteps for the length of the slide and put the
	-- volume back exactly as it was -- never assume it was 1.
	local running = root:FindFirstChild("Running")
	local wasVolume = running and running.Volume or 0
	if running then running.Volume = 0 end

	local s = template:Clone()
	s.Name = "SpellshotSlide"
	s.Volume = VOLUME
	s.PlaybackSpeed = 0.92 + math.random() * 0.16     -- so two slides in a row are not one sample twice
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 90
	s.Parent = root
	s:Play()

	live[character] = { sound = s, running = running, wasVolume = wasVolume }
end

local function watch(character)
	local function look()
		if character:GetAttribute("MoveState") == "Slide" then
			start(character)
		else
			stop(character)
		end
	end
	character:GetAttributeChangedSignal("MoveState"):Connect(look)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then stop(character) end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function() stop(character) end)
	end
	look()
end

local function follow(player)
	if player.Character then task.defer(watch, player.Character) end
	player.CharacterAdded:Connect(function(character)
		-- the root and the Humanoid are both wanted, and neither is there on the first frame
		character:WaitForChild("HumanoidRootPart", 10)
		watch(character)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do follow(p) end
Players.PlayerAdded:Connect(follow)
