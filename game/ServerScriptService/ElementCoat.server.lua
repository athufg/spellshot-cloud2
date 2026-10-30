--[[
	ElementCoat  (Script)  ->  ServerScriptService/ElementCoat

	THE DEFAULT SKIN (2026-10-27): every player wears their Element's coat over UniformAvatar's stock body. One coat
	geometry for all nine Elements (standing ribbed collar, zip + flat pull tab, sleeves ending above the elbow in a
	folded ribbed cuff, a long body open at the front below the waist, a ribbed hem); each Element's colourway is baked
	into its mesh's vertex colour, with the inverted-hull ink outline. Sources: SPELLSHOT_Backup/default_skin_jacket.

	The coats are LAYERED CLOTHING Accessories in ServerStorage.ElementCoats ("Coat_<Element>"). Their inner cage IS
	the stock body's own cage, so the wrap leaves each coat exactly as modelled and it follows the body as it moves.
	Re-dressed on every UniformStamp (UniformAvatar's "colours have landed" stamp, after its ApplyDescription, which
	drops accessories), so an Element change swaps the coat.

	OUTFITS (2026-10-29): a premium full-body Outfit is worn INSTEAD of the coat. The player attribute "Outfit"
	(Wardrobe.OutfitAttr, written by WardrobeServer from the Wardrobe's OUTFITS row) names one: the Folder
	ServerStorage.Outfits.<OutfitId> (hub/outfits_2026_10_28, OUTFIT_SPEC.md; built by install_outfits.lua) holds up to
	16 rigid Accessories, one per slot, and EVERY one of them is put on, each onto its own R15 part
	(Handle.OutfitAnchor onto <BodyPart>.<BodyAttachment>) through a SOCKET (2026-10-29, see wear below): 8 of the 16
	body attachments share their name with a neighbour part, so the piece never matches by the body's own names. The coat comes back when there is no outfit, the outfit is not owned
	(Wardrobe.OwnsOutfit: the accessories' switch), its folder is missing or broken, or -- ELEMENT_LOCK -- the outfit
	has an Element (its colours are that Element's, e.g. Magma Warlord = Pyro) and the player is another Element right
	now: the body's Element read never lies. An outfit whose Element is "None" dresses every Element.
	Re-dressed on every UniformStamp as the coat is, and at once when "Outfit" or the owned set changes. A stamp that
	finds the right things already on (a skin-tone change stamps without an ApplyDescription) changes nothing.
	The Wardrobe's accessories (Hair, Hats, Masks, Glasses, Pendants) stay on top: WardrobeServer marks its worn copies
	SpellshotOutfit = false, so the clear below leaves them alone.
	(2026-10-29) The character attribute DressedOutfit (Wardrobe.DressedOutfitAttr) names the outfit dressed on it (unset
	= the coat): WardrobeServer puts that outfit's head-piece Hat on when it first dresses (hub/outfit_heads_2026_10_29).

	THE OUTFIT MUST NOT INTERFERE WITH GAMEPLAY (the owner):
	  * the Handle never collides, touches or answers a query and weighs nothing: shots land on the body and its twins
	    (an outfit's every part is CanCollide / CanQuery / CanTouch false and Massless -- install_outfits.lua -- and
	    this script makes sure of it again on every worn copy)
	  * an Accessory is not a direct BasePart child of the character, so HitboxScale gives it no twin
	  * UniformAvatar strips every Accessory but one marked SpellshotOutfit
	  * first person: FirstPersonController hides every descendant of the local character, the coat included;
	    StarterPlayerScripts.OutfitFX turns an outfit's few emitters off there (and on a dead wearer)
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COATS = ServerStorage:WaitForChild("ElementCoats")
local ELEMENT_LOCK = false   -- (2026-10-30, the owner: any outfit on any Element; was true) (2026-10-29) an Element outfit dresses only its own Element (false = any Element)

-- (2026-10-29) the Wardrobe's names and its ownership rule; never a hard dependency: without it, the coat for all
local W, Config = nil, nil
do
	local spell = ReplicatedStorage:WaitForChild("Spellshot", 10)
	local okW, w = pcall(function() return require(spell:WaitForChild("Wardrobe", 10)) end)
	if okW and type(w) == "table" and w.OwnsOutfit then W = w else warn("[ElementCoat] no Wardrobe outfit rules: the coat for all") end
	local okC, c = pcall(function() return require(spell:WaitForChild("SpellshotConfig", 10)) end)
	if okC and type(c) == "table" then Config = c end
end
local OUTFIT_ATTR = W and W.OutfitAttr or "Outfit"
local OWNED_ATTR = W and W.OutfitOwnedAttr or "OwnedOutfits"
local DRESSED = "Dressed"   -- on every Accessory this script puts on: "Coat:<name>" / "Outfit:<id>" (what it is part of)
local DRESSED_OUTFIT = W and W.DressedOutfitAttr or "DressedOutfit"   -- (2026-10-29) on the character: the outfit worn

local function markOutfit(character, id)
	if character:GetAttribute(DRESSED_OUTFIT) ~= id then character:SetAttribute(DRESSED_OUTFIT, id) end
end

--- the outfit this player should be wearing now (its ServerStorage Folder), else nil = the coat
local function outfitFor(player)
	if not W then return nil end
	local id = player:GetAttribute(OUTFIT_ATTR)
	if type(id) ~= "string" or id == "" then return nil end
	local root = ServerStorage:FindFirstChild("Outfits")
	local f = root and root:FindFirstChild(id)
	if not (f and f:IsA("Folder")) then return nil end
	if not W.OwnsOutfit(player, id) then return nil end
	local el = W.OutfitElement(f)
	if ELEMENT_LOCK and el and el ~= player:GetAttribute("Element") then return nil end
	return f
end

local function pieces(folder)
	local list = {}
	for _, a in ipairs(folder:GetChildren()) do
		if a:IsA("Accessory") and a:GetAttribute("SpellshotOutfit") and a:FindFirstChild("Handle") then list[#list + 1] = a end
	end
	return list
end

local function tintOf(player)
	local def = Config and Config.Elements and Config.Elements[player:GetAttribute("Element") or ""]
	return def and def.Base
end

--- (2026-10-29) the socket a piece is put on by: an attachment on its body part at its body attachment, named for that
--- pair, so the name is unique on the body (no pendant, hat or neighbour part can take it)
local function socketName(part, att)
	return "OutfitSocket_" .. part.Name .. "_" .. att.Name
end

--- one outfit piece onto a character (OUTFIT_SPEC 7.2)
--- (2026-10-29, the owner: the pieces fell off) in play the Humanoid re-attaches every Accessory added to the
--- character: it clears any weld it did not make and, finding no attachment of a matching name, welds the piece to the
--- HEAD. So the piece is put on the Humanoid's own way, by a matching name: the body part gets the socket at the body
--- attachment and the Handle the same name at OutfitAnchor, and AddAccessory welds it exactly where OUTFIT_SPEC puts it
local function wear(character, humanoid, template, key, tint)
	local acc = template:Clone()
	local handle = acc:FindFirstChild("Handle")
	local anchor = handle and handle:FindFirstChild("OutfitAnchor")
	local part = character:FindFirstChild(tostring(acc:GetAttribute("BodyPart")))
	local att = part and part:FindFirstChild(tostring(acc:GetAttribute("BodyAttachment")))
	if not (anchor and anchor:IsA("Attachment") and part and part:IsA("BasePart") and att and att:IsA("Attachment")) then
		acc:Destroy()
		return nil
	end
	acc:SetAttribute(DRESSED, key)
	for _, d in ipairs(acc:GetDescendants()) do
		if d:IsA("BasePart") then   -- (belt and braces: never in the way of play, whatever the template says)
			d.CanCollide, d.CanQuery, d.CanTouch, d.Massless, d.Anchored = false, false, false, true, false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	if acc:GetAttribute("ElementTint") and tint then
		local glow = acc:FindFirstChild("Glow")
		if glow and glow:IsA("BasePart") then glow.Color = tint end
	end
	local name = socketName(part, att)
	local socket = part:FindFirstChild(name)
	if not (socket and socket:IsA("Attachment")) then
		socket = Instance.new("Attachment")
		socket.Name = name
		socket.Parent = part
	end
	socket.CFrame = att.CFrame
	local plug = Instance.new("Attachment")
	plug.Name = name
	plug.CFrame = anchor.CFrame
	plug.Parent = handle
	handle.CFrame = part.CFrame * att.CFrame * anchor.CFrame:Inverse()
	humanoid:AddAccessory(acc)
	return acc
end

local function dress(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and character.Parent) then return end
	local outfit = outfitFor(player)
	local coat = (not outfit) and COATS:FindFirstChild("Coat_" .. tostring(player:GetAttribute("Element"))) or nil
	local key = outfit and ("Outfit:" .. outfit.Name) or (coat and ("Coat:" .. coat.Name)) or nil
	local want = outfit and #pieces(outfit) or (coat and 1 or 0)

	-- (2026-10-29) already wearing exactly that (a skin-tone stamp, a repeated stamp): leave it on
	local worn, intact = {}, key ~= nil
	for _, a in ipairs(character:GetChildren()) do
		if a:IsA("Accessory") and a:GetAttribute("SpellshotOutfit") then
			worn[#worn + 1] = a
			if a:GetAttribute(DRESSED) ~= key then intact = false end
			local h = a:FindFirstChild("Handle")
			-- (the Humanoid's own attach: a RigidConstraint from the Handle's socket plug to the body part's socket)
			local w = h and h:FindFirstChild("AccessoryRigidConstraint")
			local on = w and w:IsA("RigidConstraint") and w.Attachment1 and w.Attachment1.Parent
			if not (on and on.Parent == character) then intact = false end
		end
	end
	if intact and #worn == want then
		markOutfit(character, outfit and outfit.Name or nil)
		return
	end

	for _, a in ipairs(worn) do a:Destroy() end
	if outfit then
		local tint, n = tintOf(player), 0
		for _, t in ipairs(pieces(outfit)) do
			if wear(character, humanoid, t, key, tint) then n += 1 end
		end
		if n > 0 then
			markOutfit(character, outfit.Name)
			return
		end
		warn("[ElementCoat] outfit " .. outfit.Name .. " put nothing on: the coat instead")
		for _, a in ipairs(character:GetChildren()) do
			if a:IsA("Accessory") and a:GetAttribute(DRESSED) == key then a:Destroy() end
		end
		coat = COATS:FindFirstChild("Coat_" .. tostring(player:GetAttribute("Element")))
		key = coat and ("Coat:" .. coat.Name) or nil
	end
	markOutfit(character, nil)
	if coat then
		local c = coat:Clone()
		c:SetAttribute(DRESSED, key)
		humanoid:AddAccessory(c)
	end
end

local function watch(player, character)
	character:GetAttributeChangedSignal("UniformStamp"):Connect(function()
		dress(player, character)
	end)
	if character:GetAttribute("UniformStamp") then dress(player, character) end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		watch(player, character)
	end)
	if player.Character then watch(player, player.Character) end
	-- (2026-10-29) a new outfit (or none), or a change in what the player owns: dress now, on a body that is dressed
	-- already (an undressed one is dressed by its first stamp)
	local function again()
		local character = player.Character
		if character and character:GetAttribute("UniformStamp") then task.defer(dress, player, character) end
	end
	player:GetAttributeChangedSignal(OUTFIT_ATTR):Connect(again)
	player:GetAttributeChangedSignal(OWNED_ATTR):Connect(again)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
