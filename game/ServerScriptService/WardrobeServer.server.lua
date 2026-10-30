--[[
	WardrobeServer  (Script)  ->  ServerScriptService/WardrobeServer

	THE CHARACTER EDITOR'S SERVER (2026-10-28): the accessory catalog's mirror for clients, who owns what, and the one
	authority on what each player wears. The editor itself (the mirror, the camera, the panel) is the client's:
	StarterPlayerScripts.WardrobeEditor. The shared names and rules: ReplicatedStorage.Spellshot.Wardrobe.

	THE CATALOG. ServerStorage.Accessories is the data (hub/accessories_2026_10_28). It is mirrored, cloned, into
	ReplicatedStorage.Spellshot.WardrobeCatalog (the client draws its list and thumbnails from that) and re-mirrored a
	moment after anything in ServerStorage.Accessories changes. Equipping always clones from ServerStorage, never from
	the mirror.

	OWNERSHIP. Not tracked anywhere yet: PlayerData saves Sparks and owned Elements only, and nothing sells an accessory.
	So on a live server every accessory is LOCKED (OwnedAccessories = ""), and the panel shows its Sparks price
	(SparkPrice, unset on all 30 today: the panel says TBD) and sends the player to the Shop.
	STUDIO TEST OVERRIDE: in a Studio play test every accessory counts as owned (OwnedAccessories = "*"), so the equip
	flow can be tried. Set STUDIO_TEST_OWN_ALL = false to see the locked rows in Studio (or write the player's
	OwnedAccessories attribute from the Server command bar: "" none, "*" all, or ids joined by ",").
	BACKEND NEEDED: an Owned set of AccessoryIds in PlayerData's save, a Sparks purchase path (EconomyRequest), and the
	worn set saved too -- today the worn set lasts for the session.

	WEARING. The remote ReplicatedStorage.Spellshot.WardrobeRequest (RemoteFunction):
	  client -> server   InvokeServer("Equip", accessoryId) | InvokeServer("Unequip", accessoryId) | InvokeServer("Skin", index)
	  server -> client   ok (bool), code (string), worn ("id,id"): code "ok" | "locked" | "unknown" | "busy" | "away"
	                     (not in the Hub, or in a duel) | "nobody" (no living character)
	One item per category; Hats and Hair take each other off (Wardrobe.Exclusive). The worn set lives here per player
	for the session and is put back on every new character and after every UniformStamp (UniformAvatar's
	ApplyDescription drops accessories on an Element change). The worn copy carries Wardrobe = <AccessoryId> and
	SpellshotOutfit = false: UniformAvatar's strip keeps it, ElementCoat's coat re-dress leaves it alone (see Wardrobe).
	A Glow on an ElementTint item takes the wearer's Element colour.

	SKIN TONE (2026-10-28). InvokeServer("Skin", index): index into Wardrobe.SkinTones (an integer, 1..#SkinTones; else
	"unknown"), free for everyone, the same "busy" / "away" rules as an equip. Writes the player's SkinTone attribute (the
	tone's hex) and paints that player's head and both hands at once; UniformAvatar keeps the tone on every respawn, Element
	change and UniformStamp. Session only: BACKEND NEEDED -- SkinTone in PlayerData's save.

	OUTFITS (2026-10-29). ServerStorage.Outfits (hub/outfits_2026_10_28, built by install_outfits.lua; may be absent:
	then the OUTFITS row is empty) is mirrored, cloned and without its emitters, into ReplicatedStorage.Spellshot.
	OutfitCatalog the same way (re-mirrored a moment after any change, and when the folder appears).
	  InvokeServer("EquipOutfit", outfitId) | InvokeServer("UnequipOutfit", outfitId): the same "busy" / "away" rules and
	  replies as an accessory; "locked" when not owned. Writes the player's Outfit attribute (unset = the coat); ElementCoat
	  dresses it at once (every piece, instead of the Element coat) and on every UniformStamp. One outfit at a time; the
	  worn accessories stay on top. An Element outfit equipped on another Element is kept and dresses when the player is
	  that Element (ElementCoat's ELEMENT_LOCK). OWNERSHIP: the accessories' switch -- OwnedOutfits = "*" while FREE_ALL
	  (or in a Studio test with STUDIO_TEST_OWN_ALL), else "" (every outfit locked: the panel shows its RobuxPrice).
	  BACKEND NEEDED: a Robux product per outfit (RobuxProductId; MarketplaceService receipts -> an owned set in
	  PlayerData) and the worn outfit saved. Session only today.

	OUTFIT HEAD-PIECES (2026-10-29, hub/outfit_heads_2026_10_29). Each outfit's head-piece is an ordinary Hat
	(ServerStorage.Accessories.Hats, attribute OutfitHead = <OutfitId>; the outfit Folder's HeadPiece = its AccessoryId).
	It is owned with its outfit (Wardrobe.Owns). When ElementCoat dresses an outfit (the character's DressedOutfit
	attribute: an EquipOutfit, a join or Element change that brings the outfit on), its head-piece goes on through
	equipItem -- the very path of a clicked Hat: the Hats slot takes it, Hair comes off (Wardrobe.Exclusive), nothing else
	changes. ONCE per outfit equip (headFor): a respawn, an Element round trip or a re-stamp never forces it back, so a
	swap to any other owned Hat or Hair afterwards stays; equipping the outfit again (or another) puts it on again.
	(2026-10-29, the owner) Unequipping the outfit takes its pieces off with it (head-piece and extras, each only if it
	is still the one worn in its slot: a hat swapped in since stays); equipping another outfit takes the old one's off.
	Server-side callers (tests, a future purchase flow): ServerStorage.WardrobeApi (BindableFunction), Invoke(player, what,
	id) = the remote's verbs and replies, without the MIN_GAP rate limit.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local W = require(spell:WaitForChild("Wardrobe"))
local Config = require(spell:WaitForChild("SpellshotConfig"))

-- STUDIO TEST OVERRIDE (2026-10-28): see the header. Live servers ignore it.
local STUDIO_TEST_OWN_ALL = true
local FREE_ALL = true   -- (2026-10-28, the owner) every accessory is free for everyone for now (live too); false = the real ownership

local MIN_GAP = 0.12                    -- fastest a client may ask (a click a row)
local SOURCE = ServerStorage:WaitForChild("Accessories", 60)
if not SOURCE then
	warn("[WardrobeServer] ServerStorage.Accessories is missing: the Wardrobe has no catalog")
	SOURCE = Instance.new("Folder")
end

----------------------------------------------------------------------------------------------------
-- the catalog's mirror for clients
----------------------------------------------------------------------------------------------------
local mirror = spell:FindFirstChild(W.CatalogName)
if mirror then mirror:Destroy() end
mirror = Instance.new("Folder")
mirror.Name = W.CatalogName
mirror.Parent = spell

local byId = {}           -- AccessoryId -> the ServerStorage Accessory

local function cleanCopy(acc)
	local c = acc:Clone()
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	return c
end

local function publish()
	table.clear(byId)
	local fresh = {}
	for _, cat in ipairs(SOURCE:GetChildren()) do
		if cat:IsA("Folder") then
			local f = Instance.new("Folder")
			f.Name = cat.Name
			for _, acc in ipairs(cat:GetChildren()) do
				if acc:IsA("Accessory") and acc:FindFirstChild("Handle") then
					local id = acc:GetAttribute("AccessoryId") or acc.Name
					if byId[id] then
						warn("[WardrobeServer] two accessories share AccessoryId " .. tostring(id) .. ": the second is skipped")
					else
						byId[id] = acc
						local c = cleanCopy(acc)
						if c:GetAttribute("AccessoryId") == nil then c:SetAttribute("AccessoryId", id) end
						if c:GetAttribute("Category") == nil then c:SetAttribute("Category", cat.Name) end
						c.Parent = f
					end
				end
			end
			fresh[#fresh + 1] = f
		end
	end
	mirror:ClearAllChildren()
	for _, f in ipairs(fresh) do f.Parent = mirror end
	mirror:SetAttribute("Version", (mirror:GetAttribute("Version") or 0) + 1)
	mirror:SetAttribute("Items", (function() local n = 0 for _ in pairs(byId) do n += 1 end return n end)())
end
publish()

-- a change to the data re-mirrors it (once, a moment after the last change)
local pending = false
local function soon()
	if pending then return end
	pending = true
	task.delay(0.5, function()
		pending = false
		publish()
	end)
end
SOURCE.DescendantAdded:Connect(soon)
SOURCE.DescendantRemoving:Connect(soon)
for _, d in ipairs(SOURCE:GetDescendants()) do
	if d:IsA("Accessory") then d.AttributeChanged:Connect(soon) end
end
SOURCE.DescendantAdded:Connect(function(d)
	if d:IsA("Accessory") then d.AttributeChanged:Connect(soon) end
end)

----------------------------------------------------------------------------------------------------
-- (2026-10-29) the outfits' mirror: ServerStorage.Outfits -> ReplicatedStorage.Spellshot.OutfitCatalog
----------------------------------------------------------------------------------------------------
local outfitMirror = spell:FindFirstChild(W.OutfitCatalogName)
if outfitMirror then outfitMirror:Destroy() end
outfitMirror = Instance.new("Folder")
outfitMirror.Name = W.OutfitCatalogName
outfitMirror.Parent = spell

local outfitById = {}     -- OutfitId -> the ServerStorage Folder

local function outfitSource()
	local f = ServerStorage:FindFirstChild("Outfits")
	return (f and f:IsA("Folder")) and f or nil
end

local function publishOutfits()
	table.clear(outfitById)
	local fresh, n = {}, 0
	local src = outfitSource()
	for _, f in ipairs(src and src:GetChildren() or {}) do
		if f:IsA("Folder") and f:FindFirstChildWhichIsA("Accessory") then
			local id = f:GetAttribute("OutfitId") or f.Name
			if outfitById[id] then
				warn("[WardrobeServer] two outfits share OutfitId " .. tostring(id) .. ": the second is skipped")
			else
				outfitById[id] = f
				local ok, c = pcall(function() return f:Clone() end)
				if ok and c then
					for _, d in ipairs(c:GetDescendants()) do
						-- (the clients' copy is for the panel's thumbnails: no code, no emitters)
						if d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") then d:Destroy() end
					end
					if c:GetAttribute("OutfitId") == nil then c:SetAttribute("OutfitId", id) end
					fresh[#fresh + 1] = c
					n += 1
				end
			end
		end
	end
	outfitMirror:ClearAllChildren()
	for _, c in ipairs(fresh) do c.Parent = outfitMirror end
	outfitMirror:SetAttribute("Version", (outfitMirror:GetAttribute("Version") or 0) + 1)
	outfitMirror:SetAttribute("Items", n)
end

local outfitConns, outfitPending = {}, false
local function outfitsSoon()
	if outfitPending then return end
	outfitPending = true
	task.delay(0.5, function()
		outfitPending = false
		publishOutfits()
	end)
end
local function hookOutfits()
	for _, c in ipairs(outfitConns) do c:Disconnect() end
	table.clear(outfitConns)
	local src = outfitSource()
	if src then
		outfitConns[#outfitConns + 1] = src.DescendantAdded:Connect(outfitsSoon)
		outfitConns[#outfitConns + 1] = src.DescendantRemoving:Connect(outfitsSoon)
		local function watchFolder(f)
			if f:IsA("Folder") then outfitConns[#outfitConns + 1] = f.AttributeChanged:Connect(outfitsSoon) end
		end
		for _, f in ipairs(src:GetChildren()) do watchFolder(f) end
		outfitConns[#outfitConns + 1] = src.ChildAdded:Connect(watchFolder)
	end
	publishOutfits()
end
hookOutfits()
ServerStorage.ChildAdded:Connect(function(c) if c.Name == "Outfits" then task.defer(hookOutfits) end end)
ServerStorage.ChildRemoved:Connect(function(c) if c.Name == "Outfits" then task.defer(hookOutfits) end end)

----------------------------------------------------------------------------------------------------
-- who owns what, who wears what
----------------------------------------------------------------------------------------------------
local worn = {}           -- player -> { [Category] = AccessoryId }

local function categoryOf(id)
	local acc = byId[id]
	if not acc then return nil end
	return acc:GetAttribute("Category") or (acc.Parent and acc.Parent.Name)
end

local function publishWorn(player)
	local ids = {}
	for _, cat in ipairs(W.CategoriesIn(SOURCE)) do
		local id = worn[player] and worn[player][cat]
		if id then ids[#ids + 1] = id end
	end
	player:SetAttribute(W.WornAttr, table.concat(ids, ","))
end

local function tintOf(player)
	local def = Config.Elements[player:GetAttribute("Element") or Config.DefaultLoadout.Element]
	return def and def.Base
end

--- the worn copy: the data's Accessory, marked, never in the way of play
local function wornCopy(id, player)
	local c = cleanCopy(byId[id])
	c:SetAttribute(W.Mark, id)
	c:SetAttribute("SpellshotOutfit", false)        -- (kept by UniformAvatar, left alone by ElementCoat: see Wardrobe)
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.Anchored = false, false, false, true, false
		end
	end
	local glow = c:FindFirstChild("Glow")
	local tint = tintOf(player)
	if glow and glow:IsA("BasePart") and c:GetAttribute("ElementTint") and tint then glow.Color = tint end
	return c
end

local dressing = setmetatable({}, { __mode = "k" })
--- put the character in step with the worn set: take off what is not worn, put on what is missing, re-tint
local function dress(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0 and character.Parent) then return end
	if dressing[character] then return end
	dressing[character] = true
	local want = {}
	for _, id in pairs(worn[player] or {}) do
		if byId[id] then want[id] = true end
	end
	local have = {}
	for _, a in ipairs(character:GetChildren()) do
		if a:IsA("Accessory") then
			local id = a:GetAttribute(W.Mark)
			if id ~= nil then
				if want[id] and not have[id] then have[id] = a else a:Destroy() end
			end
		end
	end
	local tint = tintOf(player)
	for id in pairs(want) do
		local a = have[id]
		if not a then
			a = wornCopy(id, player)
			local ok, err = pcall(function() humanoid:AddAccessory(a) end)
			if not ok then
				warn("[WardrobeServer] could not put on " .. id .. ": " .. tostring(err))
				a:Destroy()
			end
		elseif a:GetAttribute("ElementTint") and tint then
			local glow = a:FindFirstChild("Glow")
			if glow and glow:IsA("BasePart") then glow.Color = tint end
		end
	end
	dressing[character] = nil
end

--- (2026-10-29) THE equip of one item (a click in the panel, or an outfit's head-piece): owned, its category's slot,
--- the exclusive categories cleared, the body dressed, the worn set published
local function equipItem(player, id)
	if not W.Owns(player, id, byId[id]) then return false, "locked" end
	local cat = categoryOf(id)
	local set = worn[player]
	if not set then
		set = {}
		worn[player] = set
	end
	set[cat] = id
	for _, other in ipairs(W.Exclusive[cat] or {}) do set[other] = nil end
	dress(player)
	publishWorn(player)
	return true, "ok"
end

-- (2026-10-29) outfit head-pieces: see the header
local headFor = setmetatable({}, { __mode = "k" })   -- player -> the OutfitId whose head-piece was put on for this equip

local function headPieceOf(outfitId)
	local f = outfitById[outfitId]
	local id = f and f:GetAttribute(W.HeadPieceAttr)
	if type(id) == "string" and byId[id] then return id end
	for aid, acc in pairs(byId) do
		if acc:GetAttribute(W.HeadAttr) == outfitId then return aid end
	end
	return nil
end

local function autoHead(player, outfitId)
	if type(outfitId) ~= "string" or headFor[player] == outfitId then return end
	local id = headPieceOf(outfitId)
	if not id then return end
	headFor[player] = outfitId
	local ok, code = equipItem(player, id)
	if not ok then warn("[WardrobeServer] head-piece " .. id .. " for " .. outfitId .. ": " .. tostring(code)) end
end

--- (2026-10-30) the pieces an outfit puts on: its head-piece (stripPieces takes them off again)
local function piecesOf(outfitId)
	local id = headPieceOf(outfitId)
	return id and { id } or {}
end

--- (2026-10-29, the owner) an outfit's pieces off again: each only if it is still the one worn in its slot
local function stripPieces(player, outfitId)
	local set = worn[player]
	if not (set and type(outfitId) == "string") then return end
	local changed = false
	for _, pid in ipairs(piecesOf(outfitId)) do
		local cat = categoryOf(pid)
		if set[cat] == pid then
			set[cat] = nil
			changed = true
		end
	end
	if changed then
		dress(player)
		publishWorn(player)
	end
end

local function watch(player, character)
	-- (2026-10-29) ElementCoat names the outfit it dressed on this body: its head-piece goes on (once per outfit equip)
	character:GetAttributeChangedSignal(W.DressedOutfitAttr):Connect(function()
		autoHead(player, character:GetAttribute(W.DressedOutfitAttr))
	end)
	if character:GetAttribute(W.DressedOutfitAttr) ~= nil then
		task.defer(autoHead, player, character:GetAttribute(W.DressedOutfitAttr))
	end
	-- UniformAvatar's stamp lands after its ApplyDescription (which drops accessories): dress after it
	character:GetAttributeChangedSignal("UniformStamp"):Connect(function()
		task.defer(dress, player)
	end)
	-- anything else that takes a worn copy off (a strip, a coat re-dress) gets it put back, a moment later
	local again = false
	character.ChildRemoved:Connect(function(c)
		if again or not c:IsA("Accessory") or c:GetAttribute(W.Mark) == nil then return end
		again = true
		task.delay(0.25, function()
			again = false
			if player.Character == character then dress(player) end
		end)
	end)
	if character:GetAttribute("UniformStamp") then task.defer(dress, player) end
	task.delay(3, function() if player.Character == character then dress(player) end end)   -- (a stamp that never came)
end

local function onPlayer(player)
	worn[player] = worn[player] or {}
	player:SetAttribute(W.OwnedAttr, (FREE_ALL or (STUDIO_TEST_OWN_ALL and RunService:IsStudio())) and "*" or "")
	-- (2026-10-29) the outfits: the same switch
	player:SetAttribute(W.OutfitOwnedAttr, (FREE_ALL or (STUDIO_TEST_OWN_ALL and RunService:IsStudio())) and "*" or "")
	publishWorn(player)
	player.CharacterAdded:Connect(function(character) watch(player, character) end)
	if player.Character then watch(player, player.Character) end
	-- the Element's colour on the tinted glows (the UniformStamp re-dress covers a respawn; this, a change in place)
	player:GetAttributeChangedSignal("Element"):Connect(function() task.defer(dress, player) end)
	-- (2026-10-29) a new outfit (or none): its head-piece is due again when it dresses
	player:GetAttributeChangedSignal(W.OutfitAttr):Connect(function() headFor[player] = nil end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	worn[p] = nil
	headFor[p] = nil
end)

----------------------------------------------------------------------------------------------------
-- the remote
----------------------------------------------------------------------------------------------------
local remote = spell:FindFirstChild(W.RemoteName)
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = W.RemoteName
	remote.Parent = spell
end

local lastAt = setmetatable({}, { __mode = "k" })
local function handle(player, what, id, trusted)
	local function reply(ok, code)
		return ok, code, player:GetAttribute(W.WornAttr) or ""
	end
	local now = os.clock()
	if not trusted then
		if now - (lastAt[player] or 0) < MIN_GAP then return reply(false, "busy") end
		lastAt[player] = now
	end
	if what == "Skin" then
		-- (2026-10-28) the skin tone: a palette index, every tone free; no living body needed (the next spawn wears it)
		if type(id) ~= "number" or id ~= id or id % 1 ~= 0 or not W.SkinTones[id] then return reply(false, "unknown") end
		local zone = player:GetAttribute("Zone")
		if (zone ~= nil and zone ~= "Hub") or player:GetAttribute("DuelMatch") ~= nil then return reply(false, "away") end
		local tone = W.SkinTones[id]
		player:SetAttribute(W.SkinAttr, tone.Hex)
		if player.Character then W.PaintSkin(player.Character, tone.Color) end   -- (UniformAvatar repaints it too, on the change)
		return reply(true, "ok")
	end
	if what == "EquipOutfit" or what == "UnequipOutfit" then
		-- (2026-10-29) a full-body outfit: the player's Outfit attribute; ElementCoat dresses it (instead of the coat)
		if type(id) ~= "string" then return reply(false, "unknown") end
		local wearing = player:GetAttribute(W.OutfitAttr) == id
		if what == "EquipOutfit" and not outfitById[id] then return reply(false, "unknown") end
		if what == "UnequipOutfit" and not (wearing or outfitById[id]) then return reply(false, "unknown") end
		local zone = player:GetAttribute("Zone")
		if (zone ~= nil and zone ~= "Hub") or player:GetAttribute("DuelMatch") ~= nil then return reply(false, "away") end
		if what == "EquipOutfit" then
			if not W.OwnsOutfit(player, id) then return reply(false, "locked") end
			local prev = player:GetAttribute(W.OutfitAttr)
			if prev ~= nil and prev ~= id then stripPieces(player, prev) end
			player:SetAttribute(W.OutfitAttr, id)
			-- (2026-10-29) the head-piece comes with it: when ElementCoat dresses it (a new outfit), or now (already on)
			headFor[player] = nil
			local character = player.Character
			if character and character:GetAttribute(W.DressedOutfitAttr) == id then autoHead(player, id) end
		elseif wearing then
			player:SetAttribute(W.OutfitAttr, nil)
			stripPieces(player, id)
			headFor[player] = nil
		end
		return reply(true, "ok")
	end
	if type(id) ~= "string" or not byId[id] then return reply(false, "unknown") end
	local zone = player:GetAttribute("Zone")
	if (zone ~= nil and zone ~= "Hub") or player:GetAttribute("DuelMatch") ~= nil then return reply(false, "away") end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then return reply(false, "nobody") end
	local cat = categoryOf(id)
	local set = worn[player]
	if not set then
		set = {}
		worn[player] = set
	end
	if what == "Equip" then
		return reply(equipItem(player, id))
	elseif what == "Unequip" then
		if set[cat] == id then set[cat] = nil end
	else
		return reply(false, "unknown")
	end
	dress(player)
	publishWorn(player)
	return reply(true, "ok")
end
remote.OnServerInvoke = function(player, what, id)
	return handle(player, what, id, false)
end

-- (2026-10-29) the same verbs for server scripts (tests, a future purchase flow): no rate limit
local api = ServerStorage:FindFirstChild("WardrobeApi")
if not (api and api:IsA("BindableFunction")) then
	api = Instance.new("BindableFunction")
	api.Name = "WardrobeApi"
	api.Parent = ServerStorage
end
api.OnInvoke = function(player, what, id)
	return handle(player, what, id, true)
end
