--[[
	HubStoreFront (LocalScript, StarterPlayerScripts) -- 2026-10-29, the owner's brief: the Store wing as a storefront.

	ArcaneObservatoryHub.StoreFront (hub/store_front_2026_10_29: built in Blender, install_store_front.lua) on this client:
	  * the HERO display at the wing's door shows the Shop's single most premium item, LIVE: the Shop's own catalog
	    (StarterGui.SpellshotShop.Catalog ITEMS) in the Shop's own standard sort (CardKit.sorted "rarity": Mythic first,
	    then price high to low), its first item -- the marquee its name, the lectern its rarity / Element / kind / price
	    (CardKit.price), the crystal, its light and its sparkles the Element's colours (CardKit.EL). The crystal turns and
	    bobs; its two rings precess about it, the beads riding the inner one.
	  * the FEATURED stage where the astronomer clutter stood shows the Shop's headline BUNDLE, LIVE (a category Daily
	    Deals never shows): the first bundle of the catalog's first bundle group (the Shop's MYTHICAL VARIETY row) -- its
	    name, line, price and was-price. Its chest turns slowly and bobs; three tokens ride the orbit ring.
	  Re-read every 5 s, so a new rotation or catalog shows. One BulkMoveTo a frame, nothing while the camera is far
	  (HubLife.Close); Reduce Flashing (HubLife.Calm) halves every motion.
	The display cases, the islands and the banners are representative props: static, drawn by the install.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end

local hub = workspace:WaitForChild(HubLife.Hub, 60)
local sf = hub and hub:WaitForChild("StoreFront", 60)
if not sf then return end
local hero, feat = sf:WaitForChild("StoreHero", 30), sf:WaitForChild("StoreFeatured", 30)
if not (hero and feat) then return end

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Poll = 5,                                     -- seconds between catalog reads
	Gem = { Spin = 0.55, Bob = 0.12, BobRate = 1.3 },
	RingA = { Precess = 0.75, Spin = 1.6 },       -- rad/s: the ring's plane about the vertical; the beads along it
	RingB = { Precess = -0.5 },
	Chest = { Spin = 0.32, Bob = 0.08, BobRate = 1.1 },
	Orbit = 0.55,                                 -- rad/s: the tokens round the orbit ring
	RingANormal = Vector3.new(-0.0906, 0.3635, 0.9272),   -- the inner ring's normal in the hero's frame (store_models.py)
	Gold = Color3.fromHex("f2c870"),
	Ink = Color3.new(0, 0, 0),
}

local function find(model, name)
	local p = model:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end

----------------------------------------------------------------------------------------------------
-- motion
----------------------------------------------------------------------------------------------------
local gemC = sf:GetAttribute("HeroGem")
local chestC = sf:GetAttribute("FeatChest")
local orbitC = sf:GetAttribute("FeatOrbit")
local orbitN = sf:GetAttribute("FeatOrbitNormal")
orbitN = (orbitN and orbitC) and (orbitN - feat.WorldPivot.Position).Unit or Vector3.yAxis
local ringAN = hero.WorldPivot.Rotation * Tuning.RingANormal

local movers = {}   -- { part, base CFrame, kind }
local function add(model, name, kind)
	local p = find(model, name)
	if p then table.insert(movers, { p, p.CFrame, kind }) end
end
add(hero, "HeroGem_Shell", "gem")
add(hero, "HeroGem_Core", "gem")
add(hero, "HeroRingA", "ringA")
add(hero, "HeroRingA_Beads", "beads")
add(hero, "HeroRingB", "ringB")
for _, n in ipairs({ "FeatChest_Wood", "FeatChest_Gold", "FeatChest_Lock", "FeatChest_Coins", "FeatChest_Gem", "FeatChest_Gems" }) do
	add(feat, n, "chest")
end
for _, n in ipairs({ "FeatToken_Coin", "FeatToken_CoinStar", "FeatToken_Gem", "FeatToken_Scroll", "FeatToken_ScrollGold", "FeatToken_ScrollRibbon" }) do
	add(feat, n, "token")
end

local function about(c, axis, a)
	return CFrame.new(c) * CFrame.fromAxisAngle(axis, a) * CFrame.new(-c)
end

local parts, cfs = {}, {}
for i, m in ipairs(movers) do parts[i] = m[1] end
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if not (gemC and chestC and orbitC) or not HubLife.Close() then return end
	local k = HubLife.Calm() and 0.5 or 1
	local t = (os.clock() - t0) * k
	local G, C = Tuning.Gem, Tuning.Chest
	local gemCF = CFrame.new(0, G.Bob * k * math.sin(t * G.BobRate / k), 0) * about(gemC, Vector3.yAxis, t * G.Spin)
	local precA = about(gemC, Vector3.yAxis, t * Tuning.RingA.Precess)
	local spinA = about(gemC, ringAN, t * Tuning.RingA.Spin)
	local precB = about(gemC, Vector3.yAxis, t * Tuning.RingB.Precess)
	local chestCF = CFrame.new(0, C.Bob * k * math.sin(t * C.BobRate / k), 0) * about(chestC, Vector3.yAxis, t * C.Spin)
	local orbit = about(orbitC, orbitN, t * Tuning.Orbit)
	for i, m in ipairs(movers) do
		local kind, base = m[3], m[2]
		cfs[i] = (kind == "gem" and gemCF * base) or (kind == "ringA" and precA * base) or (kind == "beads" and precA * spinA * base)
			or (kind == "ringB" and precB * base) or (kind == "chest" and chestCF * base) or (orbit * base)
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)

----------------------------------------------------------------------------------------------------
-- the Shop's data on the hero and the featured stage
----------------------------------------------------------------------------------------------------
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local shop = playerGui:WaitForChild("SpellshotShop", 60)
if not shop then return end
local okC, Cat = pcall(require, shop:WaitForChild("Catalog", 20))
local okK, K = pcall(require, shop:WaitForChild("CardKit", 20))
if not (okC and type(Cat) == "table") then
	warn("[HubStoreFront] the Shop's Catalog is unreadable: the hero and the featured stage keep their placeholders")
	return
end
if not (okK and type(K) == "table") then K = nil end

local LUCKY = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BANGERS = Font.new("rbxasset://fonts/families/Bangers.json")
local GOTHAM = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local function canvas(model, name)
	local p = model:FindFirstChild("Canvas_" .. name)
	local g = p and p:FindFirstChild("Face")
	if not g then return nil end
	for _, c in ipairs(g:GetChildren()) do c:Destroy() end
	return g, Vector2.new(p.Size.X * g.PixelsPerStud, p.Size.Y * g.PixelsPerStud)
end
local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextScaled = true
	for k, v in pairs(props) do
		if k ~= "Stroke" then t[k] = v end
	end
	if props.Stroke then
		local s = Instance.new("UIStroke")
		s.Thickness = props.Stroke
		s.Color = Tuning.Ink
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	t.Parent = parent
	return t
end
local function fmt(n)
	if K and K.fmt then return K.fmt(n) end
	return tostring(n)
end
local function rarity(r)
	local R = K and K.RARITY and K.RARITY[r]
	return (R and R.c) or Tuning.Gold, (R and R.word) or string.upper(tostring(r or ""))
end
--- the currency mark and the amount (the Shop's own CardKit.price), else plain text
local function price(parent, x, y, p, size)
	if type(p) ~= "table" then return end
	if K and K.price and pcall(K.price, parent, x, y, p, size, Tuning.Gold, 5) then return end
	text(parent, { Text = (p[1] == "Robux" and "R$ " or "") .. fmt(p[2]) .. (p[1] == "Sparks" and " SPARKS" or ""), FontFace = GOTHAM,
		TextColor3 = Tuning.Gold, Size = UDim2.fromOffset(size * 6, size), Position = UDim2.fromOffset(x, y),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
end

--- the Shop's single most premium item: its own standard sort, first
local function topItem()
	local items = Cat.ITEMS
	if type(items) ~= "table" or #items == 0 then return nil end
	if K and K.sorted then
		local ok, s = pcall(K.sorted, items, "rarity")
		if ok and type(s) == "table" and s[1] then return s[1] end
	end
	return items[1]
end

--- the Shop's headline bundle: the first bundle of its first bundle group
local function topBundle()
	local list, groups = Cat.BUNDLES, Cat.BUNDLE_GROUPS
	if type(list) ~= "table" or #list == 0 then return nil end
	local key = type(groups) == "table" and groups[1] and groups[1].key
	for _, b in ipairs(list) do
		if b.group == key then return b end
	end
	return list[1]
end

local function tintHero(el)
	local E = K and K.EL and K.EL[el]
	if not E then return end
	local shell, core = find(hero, "HeroGem_Shell"), find(hero, "HeroGem_Core")
	if shell then shell.Color = E.light end
	if core then core.Color = E.base end
	local l = hero:FindFirstChild("Light_HeroGemLight")
	l = l and l:FindFirstChildOfClass("PointLight")
	if l then l.Color = E.base end
	local em = hero:FindFirstChild("Emit_HeroSparkle")
	em = em and em:FindFirstChildOfClass("ParticleEmitter")
	if em then em.Color = ColorSequence.new(E.light, E.base) end
end

local function drawHero(it)
	local rc, rword = rarity(it.rarity)
	for _, side in ipairs({ "HeroMarquee_Front", "HeroMarquee_Back" }) do
		local g, px = canvas(hero, side)
		if g then
			text(g, { Text = "★ FEATURED  ·  " .. rword .. " ★", FontFace = BANGERS, TextColor3 = rc, Size = UDim2.new(1, -20, 0.3, 0),
				Position = UDim2.new(0, 10, 0.04, 0), Stroke = math.max(2, px.Y * 0.025) })
			text(g, { Text = string.upper(tostring(it.name)), FontFace = LUCKY, TextColor3 = Color3.new(1, 1, 1),
				Size = UDim2.new(1, -24, 0.6, 0), Position = UDim2.new(0, 12, 0.35, 0), Stroke = math.max(3, px.Y * 0.05) })
		end
	end
	local g, px = canvas(hero, "HeroLectern_PlaqueCanvas")
	if g then
		local H = px.Y
		local sub = string.upper(tostring(it.el or "") .. "  ·  " .. tostring(it.kind or ""))
		text(g, { Text = rword, FontFace = BANGERS, TextColor3 = rc, Size = UDim2.fromOffset(px.X * 0.46, H * 0.26),
			Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
		text(g, { Text = sub, FontFace = GOTHAM, TextColor3 = Color3.fromHex("cfd6e6"), Size = UDim2.fromOffset(px.X * 0.5, H * 0.2),
			Position = UDim2.fromOffset(px.X * 0.48, 9), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5 })
		text(g, { Text = string.upper(tostring(it.name)), FontFace = LUCKY, TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(px.X - 20, H * 0.32), Position = UDim2.fromOffset(10, H * 0.31),
			TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5 })
		price(g, 12, math.floor(H * 0.68), it.price, math.floor(H * 0.26))
	end
	tintHero(it.el)
	hero:SetAttribute("ShowingItem", tostring(it.id))
end

local function drawBundle(b)
	local rc, rword = rarity(b.rarity)
	local g, px = canvas(feat, "FeatLectern_PlaqueCanvas")
	if not g then return end
	local H = px.Y
	text(g, { Text = "FEATURED BUNDLE", FontFace = BANGERS, TextColor3 = rc, Size = UDim2.fromOffset(px.X * 0.6, H * 0.22),
		Position = UDim2.fromOffset(10, 5), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
	if b.limited then
		text(g, { Text = "LIMITED", FontFace = BANGERS, TextColor3 = Color3.fromHex("ff5a4e"), Size = UDim2.fromOffset(px.X * 0.3, H * 0.2),
			Position = UDim2.fromOffset(px.X * 0.7 - 10, 6), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2 })
	end
	text(g, { Text = string.upper(tostring(b.name)), FontFace = LUCKY, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(px.X - 20, H * 0.3), Position = UDim2.fromOffset(10, H * 0.25), TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 2.5 })
	text(g, { Text = tostring(b.line or rword), FontFace = GOTHAM, TextColor3 = Color3.fromHex("cfd6e6"),
		Size = UDim2.fromOffset(px.X - 20, H * 0.15), Position = UDim2.fromOffset(10, H * 0.56), TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 1.5 })
	price(g, 12, math.floor(H * 0.74), b.price, math.floor(H * 0.22))
	if b.was then
		local w = text(g, { Text = "WAS " .. fmt(b.was), FontFace = GOTHAM, TextColor3 = Color3.fromHex("9aa3b5"),
			Size = UDim2.fromOffset(px.X * 0.36, H * 0.17), Position = UDim2.fromOffset(px.X * 0.64 - 12, H * 0.77),
			TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5 })
		local strike = Instance.new("Frame")
		strike.BackgroundColor3 = Color3.fromHex("ff5a4e")
		strike.BorderSizePixel = 0
		strike.AnchorPoint = Vector2.new(0, 0.5)
		strike.Size = UDim2.new(1, 0, 0, 3)
		strike.Position = UDim2.fromScale(0, 0.5)
		strike.Parent = w
	end
	feat:SetAttribute("ShowingBundle", tostring(b.id))
end

local shownItem, shownBundle
while true do
	local it = topItem()
	if it and it.id ~= shownItem then
		local ok, e = pcall(drawHero, it)
		if ok then shownItem = it.id else warn("[HubStoreFront] hero: " .. tostring(e)) end
	end
	local b = topBundle()
	if b and b.id ~= shownBundle then
		local ok, e = pcall(drawBundle, b)
		if ok then shownBundle = b.id else warn("[HubStoreFront] featured: " .. tostring(e)) end
	end
	task.wait(Tuning.Poll)
end
