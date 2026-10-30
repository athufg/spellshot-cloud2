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

	SKIN TONE (2026-10-28): the bare skin -- the head and both hands (Wardrobe.SkinParts) -- is the player's own tone, the
	SkinTone attribute WardrobeServer writes from the Wardrobe editor's SKIN palette (Wardrobe.SkinTones; unset = the
	default #EAB892). Used on every spawn, Element change and UniformStamp, and repainted (head + hands only, no
	ApplyDescription) the moment it changes. Session only: PlayerData does not save it yet.
]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
-- (2026-10-28) the skin palette (the Wardrobe's shared rules). Never a hard dependency: without it every body keeps the
-- default tone below and the uniform still goes on
local Wardrobe = nil
do
	local m = ReplicatedStorage.Spellshot:WaitForChild("Wardrobe", 10)
	local ok, w = pcall(function() return m and require(m) end)
	if ok and type(w) == "table" and w.SkinOf then Wardrobe = w else warn("[UniformAvatar] no Wardrobe module: default skin for all") end
end
local SKIN_ATTR = Wardrobe and Wardrobe.SkinAttr or "SkinTone"

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
	-- (2026-10-27, the owner) skin is skin: the head and the hands are one warm skin tone on every player (the hub NPCs'
	-- tone), so the silhouette still reads the same on every Element
	-- (2026-10-28) ...now the DEFAULT: each player picks their own tone at the Wardrobe (skinOf below)
	Skin = Color3.fromHex("EAB892"),
}

--- (2026-10-28) the player's chosen skin tone (the SkinTone attribute, checked against the palette), else the default
local function skinOf(player)
	if not Wardrobe then return BODY.Skin end
	local ok, _, colour = pcall(Wardrobe.SkinOf, player)
	return (ok and typeof(colour) == "Color3") and colour or BODY.Skin
end

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

local function buildDescription(element, skin)
	local desc = Instance.new("HumanoidDescription")
	for k, v in pairs(SCALES) do
		desc[k] = v
	end
	local tones = bodyTones(element or Config.DefaultLoadout.Element)
	desc.HeadColor = skin or BODY.Skin   -- (2026-10-28) the player's tone
	desc.TorsoColor = tones.Torso
	desc.LeftArmColor = tones.Sleeve
	desc.RightArmColor = tones.Sleeve
	desc.LeftLegColor = BODY.Neutral
	desc.RightLegColor = BODY.Neutral
	-- every id left at 0: no clothes, no accessories, no bought body parts, stock R15 geometry
	return desc
end

local STRIP = { "Accessory", "Shirt", "Pants", "ShirtGraphic", "CharacterMesh", "BodyColors" }

--- (2026-10-27) the game's own outfit stays: ElementCoat dresses every player in their Element's coat, an Accessory
--- marked SpellshotOutfit (layered clothing; no collision, query or hitbox twin) -- it and everything in it are kept
local function outfit(d)
	local a = d:IsA("Accessory") and d or d:FindFirstAncestorOfClass("Accessory")
	return a ~= nil and a:GetAttribute("SpellshotOutfit") ~= nil
end

local function stripAppearance(character)
	for _, d in ipairs(character:GetDescendants()) do
		for _, class in ipairs(STRIP) do
			if d:IsA(class) and not outfit(d) then
				d:Destroy()
				break
			end
		end
	end
end

local stripWatched = setmetatable({}, { __mode = "k" })   -- characters whose strip watcher is already connected

local function applyUniform(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	stripAppearance(character)
	local element = player:GetAttribute("Element") or Config.DefaultLoadout.Element
	local skin = skinOf(player)   -- (2026-10-28)
	local ok, err = pcall(function()
		humanoid:ApplyDescription(buildDescription(element, skin))
	end)
	local tones = bodyTones(element)
	if not ok then
		-- ApplyDescription can fail on a character that is being removed mid-call; the colours
		-- still matter, so fall back to writing them directly.
		warn("[UniformAvatar] ApplyDescription failed: " .. tostring(err))
		local colors = Instance.new("BodyColors")
		colors.HeadColor3 = skin
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
		if part then part.Color = skin end   -- (2026-10-27) was tones.Hand; (2026-10-28) the player's tone
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then head.Color = skin end   -- (2026-10-28, belt and braces over HeadColor)
	-- (2026-10-19, audit P5F-11) a stamp AFTER the colours are written: a client's per-viewer repaint (Colorblind-Safe,
	-- SettingsRuntime) listens for it, so the server's writes no longer land on top of the client's paint after an
	-- Element change or a slow ApplyDescription
	if character.Parent then
		character:SetAttribute("UniformStamp", (character:GetAttribute("UniformStamp") or 0) + 1)
	end

	-- Anything that arrives later gets removed. Deferred because a just-parented Accessory has
	-- not finished welding itself yet, and destroying it mid-weld logs an error.
	-- (2026-10-19, audit P5F-11) once per character: every Element change used to stack another connection
	if stripWatched[character] then return end
	stripWatched[character] = true
	character.DescendantAdded:Connect(function(d)
		for _, class in ipairs(STRIP) do
			if d:IsA(class) then
				task.defer(function()
					if d.Parent and not outfit(d) then d:Destroy() end
				end)
				return
			end
		end
	end)
end

--- (2026-10-28) a new skin tone in place: the head and both hands only (no ApplyDescription, so nothing worn drops),
--- then the stamp, so the clients' repaint and the Wardrobe's re-dress follow as they do after a full uniform write
local function repaintSkin(player, character)
	if not (character and character.Parent and player.Character == character) then return end
	if not character:FindFirstChildOfClass("Humanoid") then return end
	local skin = skinOf(player)
	for _, name in ipairs({ "Head", "LeftHand", "RightHand" }) do   -- (Wardrobe.SkinParts)
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then part.Color = skin end
	end
	local bc = character:FindFirstChildOfClass("BodyColors")
	if bc then bc.HeadColor3 = skin end
	character:SetAttribute("UniformStamp", (character:GetAttribute("UniformStamp") or 0) + 1)
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
	-- (2026-10-28) a new skin tone (the Wardrobe's SKIN palette): repaint the bare skin in place
	player:GetAttributeChangedSignal(SKIN_ATTR):Connect(function()
		if player.Character then
			task.defer(repaintSkin, player, player.Character)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
