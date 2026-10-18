--[[
	UniformAvatar  (Script)  ->  ServerScriptService/UniformAvatar

	Every player renders with the same body, regardless of the avatar they own -- the RIVALS
	model, confirmed from the reference screenshot where several different accounts all show the
	same simplified blocky character.

	WHICH RIG, AND WHY THIS ONE
	  A uniform R15 blocky rig at scale 1, recoloured per Element. Not a bespoke custom mesh rig.
	  Reasons, in order:
	    * The manual already specifies this shape: character skins are "full-body reskins per
	      element ... recolors the base humanoid, doesn't change hitbox" (Section 7). A uniform
	      base humanoid that gets recoloured IS the documented cosmetic model, so matching
	      RIVALS' exact proportions would put the art ahead of the design doc for no gameplay
	      gain.
	    * Hitbox consistency is the actual competitive requirement, and it comes from the uniform
	      SCALE, not from the specific mesh -- a bought Rthro body is a different hitbox to a
	      classic one, and that is what has to stop.
	    * The default blocky R15 rig is what you get for free with appearance loading off, so
	      there is no asset to upload, moderate, or keep in sync.
	  If a custom SPELLSHOT body mesh is authored later, the only change needed here is a
	  HumanoidDescription carrying its part ids -- everything else in this file still applies.

	HOW IT IS ENFORCED (three layers, because any one of them can be bypassed)
	  1. StarterPlayer.LoadCharacterAppearance = false, so the avatar is never fetched at all.
	  2. ApplyDescription with a fixed, code-built HumanoidDescription -- no asset ids anywhere in
	     it, which resolves to the stock blocky R15 parts at uniform scale.
	  3. A DescendantAdded watcher that strips anything that turns up afterwards (an Accessory
	     from a tool, a Shirt from another script).
]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))

-- Belt and braces: this is also set on the StarterPlayer instance in the place file, but setting
-- it here means a fresh copy of the place still behaves correctly.
StarterPlayer.LoadCharacterAppearance = false

----------------------------------------------------------------------------------------------------
-- the uniform body
----------------------------------------------------------------------------------------------------
local BODY = {
	-- Head and legs stay a neutral slate on every Element, so the SILHOUETTE is identical and
	-- only the torso/arms carry the Element read. Head especially: a headshot target that
	-- changes colour by Element would be a legibility advantage for some Elements.
	Neutral = Color3.fromRGB(58, 64, 78),
}

-- The Element read is split across three tones rather than painting the whole upper body one
-- colour. The reason is first person: the viewmodel clones these same arm limbs and holds them
-- a stud from the lens, so a full-saturation arm becomes a slab of flat colour across a third of
-- the screen. Torso carries the identity at range (biggest surface), the sleeve is the dark step
-- down, and the hand is the light step up so the casting palm still reads against it.
local function bodyTones(element)
	local def = Config.Elements[element] or Config.Elements[Config.DefaultLoadout.Element]
	return {
		Torso = def.Base,
		Sleeve = def.Dark,
		Hand = def.Light,
	}
end

-- R15 exposes one arm colour per side in a HumanoidDescription, so the sleeve/hand split has to
-- be painted onto the individual limbs afterwards.
local HAND_PARTS = { "LeftHand", "RightHand" }
local SLEEVE_PARTS = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }

local SCALES = {
	BodyTypeScale = 0,     -- 0 = classic blocky proportions, not Rthro
	ProportionScale = 0,
	HeadScale = 1,
	DepthScale = 1,
	WidthScale = 1,
	HeightScale = 1,
}

local function buildDescription(element)
	local desc = Instance.new("HumanoidDescription")
	for k, v in pairs(SCALES) do
		desc[k] = v
	end
	local tones = bodyTones(element or Config.DefaultLoadout.Element)
	desc.HeadColor = BODY.Neutral
	desc.TorsoColor = tones.Torso
	desc.LeftArmColor = tones.Sleeve
	desc.RightArmColor = tones.Sleeve
	desc.LeftLegColor = BODY.Neutral
	desc.RightLegColor = BODY.Neutral
	-- every id left at 0: no clothes, no accessories, no bought body parts, stock R15 geometry
	return desc
end

local STRIP = { "Accessory", "Shirt", "Pants", "ShirtGraphic", "CharacterMesh", "BodyColors" }

local function stripAppearance(character)
	for _, d in ipairs(character:GetDescendants()) do
		for _, class in ipairs(STRIP) do
			if d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
end

local function applyUniform(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	stripAppearance(character)
	local element = player:GetAttribute("Element") or Config.DefaultLoadout.Element
	local ok, err = pcall(function()
		humanoid:ApplyDescription(buildDescription(element))
	end)
	local tones = bodyTones(element)
	if not ok then
		-- ApplyDescription can fail on a character that is being removed mid-call; the colours
		-- still matter, so fall back to writing them directly.
		warn("[UniformAvatar] ApplyDescription failed: " .. tostring(err))
		local colors = Instance.new("BodyColors")
		colors.HeadColor3 = BODY.Neutral
		colors.TorsoColor3 = tones.Torso
		colors.LeftArmColor3 = tones.Sleeve
		colors.RightArmColor3 = tones.Sleeve
		colors.LeftLegColor3 = BODY.Neutral
		colors.RightLegColor3 = BODY.Neutral
		colors.Parent = character
	end

	for _, name in ipairs(SLEEVE_PARTS) do
		local part = character:FindFirstChild(name)
		if part then part.Color = tones.Sleeve end
	end
	for _, name in ipairs(HAND_PARTS) do
		local part = character:FindFirstChild(name)
		if part then part.Color = tones.Hand end
	end

	-- Anything that arrives later gets removed. Deferred because a just-parented Accessory has
	-- not finished welding itself yet, and destroying it mid-weld logs an error.
	character.DescendantAdded:Connect(function(d)
		for _, class in ipairs(STRIP) do
			if d:IsA(class) then
				task.defer(function()
					if d.Parent then d:Destroy() end
				end)
				return
			end
		end
	end)
end

local function onPlayer(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		applyUniform(player, character)
	end)
	player.CharacterAdded:Connect(function(character)
		-- With LoadCharacterAppearance off, CharacterAppearanceLoaded may never fire, so this is
		-- the path that actually runs in normal play.
		task.defer(applyUniform, player, character)
	end)
	if player.Character then
		task.defer(applyUniform, player, player.Character)
	end
	-- re-tint if the Element changes between rounds without a respawn
	player:GetAttributeChangedSignal("Element"):Connect(function()
		if player.Character then
			task.defer(applyUniform, player, player.Character)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
