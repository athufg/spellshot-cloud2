--!nocheck
--[[
	BarFX  (ModuleScript)  ->  ReplicatedStorage.Spellshot.BarFX
	Variants (ModuleScripts) ->  ReplicatedStorage.Spellshot.BarFX.Variants.<kind>_<id>

	FULL-BAR STATUS EFFECTS, round 2 (owner, 2026-09-24: "implement all and give me access in dev tools to be able to use
	them all"). Every status has three looks -- t TAKEOVER (the bar becomes the element), a ASSAULT (the element attacks the
	bar), f LIVING FILL (the fill becomes the element) -- plus "old", StatusReactions' previous treatment. The pick is the
	LocalPlayer attribute BarFX_<kind> ("t" | "a" | "f" | "old"), set from the dev panel; nil means DEFAULT.

	ONE COORDINATE SPACE. The looks were designed on a 640 x 240 bench whose bar interior (inside its ink) is
	x 104..496, y 116..164, the badge x 24..88, y 108..172. Every layer here is a frame spanning that same design space,
	scaled so its bar interior lands exactly on the real HealthBar -- so a variant places everything with design numbers:
	fx.P(x, y) / fx.S(w, h) (or the x/y/w/h fields of the helpers). The layers:
	  fx.back   behind the whole HUD           (ScreenGui DisplayOrder 8)
	  fx.bar    inside the bar interior, clipped to its rounded pill, above the fill and the kit's halftone
	  fx.fill   inside the bar, clipped to the CURRENT HP width (the fill), same design coordinates
	  fx.front  above everything, the HP numeral included (ScreenGui DisplayOrder 21)
	Pixel-valued things (UIStroke thickness, TextSize) are given in DESIGN px and rescaled here on every resize.

	THE STATE a variant sees mirrors the bench: st = { kind, on, s, max, k, t, a, hp, pay, time }, with events
	'on' 'stack' 'tick' 'hit' 'pay' 'end'. It comes from the character's RX_<Kind> attributes (StatusEffects /
	PyroHandler / AbilityHandler write them), or from BarFX.Preview, which plays the bench's own timeline on your bar.
	s is remapped onto the bench's stack scale (burn 3, chill 3, poison 2, charged 3) so every look fills the way it was
	drawn whatever the live preset's MaxStacks; the raw numbers ride along as st.rawS / st.rawMax.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BarFX = {}

BarFX.KINDS = { "burn", "chill", "poison", "charged", "marked", "blessed", "primed", "shield" }
BarFX.RX = { burn = "Burning", chill = "Chilled", poison = "Poisoned", charged = "Charged", marked = "Marked",
	blessed = "Blessed", primed = "Primed", shield = "Shielded" }
BarFX.FROM_RX = {}
for k, rx in pairs(BarFX.RX) do BarFX.FROM_RX[rx] = k end
BarFX.CHOICES = { "t", "a", "f", "old" }
BarFX.DEFAULT = "t"
BarFX.NAMES = {}       -- [kind_id] = title, filled from the variant modules
local BENCH_MAX = { burn = 3, chill = 3, poison = 2, charged = 3, marked = 1, blessed = 1, primed = 1, shield = 1 }
local DEFAULT_MAX = { burn = 3, chill = 3, poison = 1, charged = 4, marked = 1, blessed = 1, primed = 1, shield = 1 }
local LINGER = 0.8            -- a look is kept this long after 'end' so its exit can play
local PAY_HOLD = 0.8          -- a payoff that the server shows only as the flag dropping is held this long

-- design space
local DW, DH = 640, 240
local IX, IY, IW, IH = 104, 116, 392, 48

----------------------------------------------------------------------------------------------------
-- colours (the bench's CSS tokens)
----------------------------------------------------------------------------------------------------
local function hex(h)
	h = h:gsub("#", "")
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
BarFX.hex = hex
local C = {
	ink = "#141414", paper = "#FFFDF8", red = "#E4251F", redD = "#9E1410", mana = "#3B35D8", manaD = "#221E8F", white = "#FFFFFF",
	pyro = "#F25C0D", pyroL = "#FFC74D", pyroD = "#6B1708", pyroY = "#FFE66B",
	cryo = "#40B5F0", cryoL = "#DEF7FF", cryoD = "#0D4FA8", cryoM = "#8FDCFF",
	toxin = "#80D421", toxinL = "#CCF570", toxinD = "#4A1A6B", toxinM = "#2E7D16",
	volt = "#F5C70F", voltL = "#FFF573", voltD = "#4A1A8C", voltM = "#8A4DE8",
	umbra = "#4F2191", umbraL = "#B58CF0", umbraD = "#1E0B3D",
	rad = "#F5C230", radL = "#FFF7D6", radD = "#70520A", radW = "#FFFFFF",
	terra = "#826B24", terraL = "#C9A860", terraD = "#3D2E0C",
	steel = "#8FA3B8", steelL = "#DFE8F2", steelD = "#44566A",
}
for k, v in pairs(C) do C[k] = hex(v) end
BarFX.C = C

----------------------------------------------------------------------------------------------------
-- sprites
----------------------------------------------------------------------------------------------------
local Atlas = { images = {}, sprites = {} }
do
	local ok, a = pcall(function() return require(script:WaitForChild("Atlas", 5)) end)
	if ok and type(a) == "table" then Atlas = a end
end
local DOT_IMAGE = "rbxassetid://0"
do
	local ok, kit = pcall(function() return require(script.Parent:WaitForChild("BarKit", 5)) end)
	if ok and kit and kit.Art and kit.Art.Dot then DOT_IMAGE = kit.Art.Dot end
end
local warnedSprite = {}

----------------------------------------------------------------------------------------------------
-- the HUD surfaces (PopArtHUD builds them with BarKit; re-found whenever the HUD is rebuilt)
----------------------------------------------------------------------------------------------------
local player = Players.LocalPlayer
local H = {}          -- hud, opacity, row, interior, clip, fill, badge, glyph, label, ring
local function findHud()
	local pg = player and player:FindFirstChild("PlayerGui")
	local hud = pg and pg:FindFirstChild("PopArtHUD")
	local row = hud and hud:FindFirstChild("HealthRow", true)
	local interior = row and row:FindFirstChild("HealthBar")
	if not (interior and interior:FindFirstChild("Clip")) then return false end
	H.hud, H.row, H.interior = hud, row, interior
	H.opacity = hud:FindFirstChild("OpacityLayer")
	H.clip = interior.Clip
	H.fill = H.clip:FindFirstChild("Fill")
	H.stroke = interior:FindFirstChildOfClass("UIStroke")
	H.label = interior:FindFirstChild("Label")
	H.badge = row:FindFirstChild("HealthBadge")
	H.badgeStroke = H.badge and H.badge:FindFirstChildOfClass("UIStroke")
	H.glyph = row:FindFirstChild("Glyph")
	H.ring = row:FindFirstChild("HealthPulseRing")
	local corner = interior:FindFirstChildOfClass("UICorner")
	H.radius = corner and corner.CornerRadius or UDim.new(0, 22)
	return true
end
local function hudLive()
	return H.interior and H.interior.Parent and H.hud and H.hud.Parent and H.hud.Enabled
end

----------------------------------------------------------------------------------------------------
-- host layers (made once)
----------------------------------------------------------------------------------------------------
local Host = {}
local Map = { s = 1, x = 0, y = 0, barPx = 1 }
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function screen(name, order)
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then old:Destroy() end
	local g = mk("ScreenGui", { Name = name, ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
	-- the group spans only the design rect (not the screen): a CanvasGroup renders its area every frame
	local group = mk("CanvasGroup", { Name = "Group", BackgroundTransparency = 1 }, g)
	local root = mk("Frame", { Name = "Design", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, group)
	return g, group, root
end
local function buildHosts()
	Host.backGui, Host.backGroup, Host.back = screen("BarFXBack", 8)
	Host.frontGui, Host.frontGroup, Host.front = screen("BarFXFront", 21)
end
-- the two in-bar hosts live inside the HUD's own HealthBar, so they move, scale and fade with it
local unmountAll
local function buildBarHosts()
	if Host.barGroup and Host.barGroup.Parent == H.interior then return end
	if Host.barGroup then unmountAll(); Host.barGroup:Destroy() end
	Map.lastW = nil
	Host.barGroup = mk("CanvasGroup", { Name = "BarFX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9 }, H.interior)
	mk("UICorner", { CornerRadius = H.radius }, Host.barGroup)
	Host.bar = mk("Frame", { Name = "Design", BackgroundTransparency = 1,
		Size = UDim2.fromScale(DW / IW, DH / IH), Position = UDim2.fromScale(-IX / IW, -IY / IH) }, Host.barGroup)
	-- the fill: a clip that tracks the HP width, holding a design frame whose size is re-solved as the clip changes
	Host.fillClip = mk("Frame", { Name = "FillClip", BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1,
		Position = UDim2.fromScale(IX / DW, IY / DH), Size = UDim2.fromScale(IW / DW, IH / DH) }, Host.bar)
	Host.fill = mk("Frame", { Name = "Design", BackgroundTransparency = 1 }, Host.fillClip)
end

-- where the design space sits on screen: solved from the real bar interior every frame (Map is declared with Host)
local function solveMap()
	local p, z = H.interior.AbsolutePosition, H.interior.AbsoluteSize
	local s = z.X / IW
	Map.s = s
	Map.x = p.X - IX * s
	Map.y = p.Y + z.Y * 0.5 - (IY + IH * 0.5) * s
	-- the HealthBar is inside UIScales: one design px there is this many of the bar's own (kit) px
	Map.barPx = (H.interior.Size.X.Offset > 0 and H.interior.Size.X.Offset or 422) / IW
	for _, g in ipairs({ Host.backGroup, Host.frontGroup }) do
		g.Position = UDim2.fromOffset(Map.x, Map.y)
		g.Size = UDim2.fromOffset(DW * s, DH * s)
	end
end
local function setFill(frac)
	frac = math.clamp(frac, 0.002, 1)
	Host.fillClip.Size = UDim2.fromScale(IW * frac / DW, IH / DH)
	Host.fill.Size = UDim2.fromScale(DW / (IW * frac), DH / IH)
	Host.fill.Position = UDim2.fromScale(-IX / (IW * frac), -IY / IH)
end

----------------------------------------------------------------------------------------------------
-- the variant context: helpers and cleanup
----------------------------------------------------------------------------------------------------
local Scaled = {}        -- live list of { obj, prop, design px, layerName }
local function pxFor(layerName)
	if layerName == "bar" or layerName == "fill" then return Map.barPx end
	return Map.s
end
local function rescaleAll()
	for i = #Scaled, 1, -1 do
		local e = Scaled[i]
		if not e.obj.Parent then table.remove(Scaled, i)
		elseif e.prop == "__corner" then e.obj.CornerRadius = UDim.new(0, e.v * pxFor(e.layer))
		else e.obj[e.prop] = e.v * pxFor(e.layer) end
	end
end

-- restyles of the real HUD pieces, stacked per target so two looks can hold one surface and still restore it
local Restyle = { orig = {}, stack = {} }
local function targetOf(name)
	return ({ bar = H.interior, barStroke = H.stroke, fill = H.fill, chip = H.badge, chipStroke = H.badgeStroke,
		glyph = H.glyph, label = H.label, ring = H.ring })[name]
end
local function applyRestyle(name)
	local inst = targetOf(name)
	if not inst then return end
	local orig = Restyle.orig[name] or {}
	for k, v in pairs(orig) do inst[k] = v end
	for _, e in ipairs(Restyle.stack[name] or {}) do
		for k, v in pairs(e.props) do inst[k] = v end
	end
end

local function makeContext(kind, id, isPreview)
	local fx = { kind = kind, id = id, preview = isPreview, C = C, clock = 0 }
	local owned = {}                -- everything to destroy on unmount
	local restyles = {}             -- names this look pushed
	local particles = {}
	local timers = {}
	-- each look gets its own sub-frame in every layer, so unmounting is one Destroy per layer
	for _, name in ipairs({ "back", "bar", "fill", "front" }) do
		local host = Host[name]
		local f = mk("Frame", { Name = kind .. "_" .. id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, host)
		fx[name] = f
		owned[#owned + 1] = f
	end
	local layerOf = {}
	for _, name in ipairs({ "back", "bar", "fill", "front" }) do layerOf[fx[name]] = name end
	local function layerName(parent)
		local p = parent
		while p do
			if layerOf[p] then return layerOf[p] end
			p = p.Parent
		end
		return "front"
	end

	function fx.P(x, y) return UDim2.fromScale(x / DW, y / DH) end
	function fx.S(w, h) return UDim2.fromScale(w / DW, h / DH) end
	-- a pixel-valued property in design px, kept right through resizes
	function fx.px(obj, prop, v)
		local layer = layerName(obj.Parent or obj)
		Scaled[#Scaled + 1] = { obj = obj, prop = prop, v = v, layer = layer }
		obj[prop] = v * pxFor(layer)
	end
	-- the badge's rectangle in design units (the real one, not the bench's)
	function fx.chipRect()
		if not (H.badge and H.badge.Parent) then return 24, 108, 64, 64 end
		local p, z = H.badge.AbsolutePosition, H.badge.AbsoluteSize
		return (p.X - Map.x) / Map.s, (p.Y - Map.y) / Map.s, z.X / Map.s, z.Y / Map.s
	end
	function fx.track(obj) owned[#owned + 1] = obj return obj end

	local function place(o, o2)
		if o2.x then
			o.AnchorPoint = o2.anchor or Vector2.new(0, 0)
			o.Position = fx.P(o2.x, o2.y or 0)
		end
		if o2.w then o.Size = fx.S(o2.w, o2.h or o2.w) end
		if o2.rotation then o.Rotation = o2.rotation end
		if o2.z then o.ZIndex = o2.z end
		if o2.visible ~= nil then o.Visible = o2.visible end
	end

	--- A plain Frame: { x y w h anchor color transparency corner ("pill" or design px) stroke strokeColor rotation z }
	function fx.rect(parent, o)
		o = o or {}
		local f = mk("Frame", { BackgroundColor3 = o.color or C.white, BackgroundTransparency = o.transparency or 0,
			BorderSizePixel = 0 }, parent)
		place(f, o)
		if o.corner then
			local c = mk("UICorner", {}, f)
			if o.corner == "pill" then c.CornerRadius = UDim.new(0.5, 0) else fx.pxUDim(c, o.corner) end
		end
		if o.stroke then fx.stroke(f, o.stroke, o.strokeColor) end
		return f
	end
	function fx.pxUDim(corner, v)
		local layer = layerName(corner.Parent)
		corner.CornerRadius = UDim.new(0, v * pxFor(layer))
		Scaled[#Scaled + 1] = { obj = corner, prop = "__corner", v = v, layer = layer }
	end
	--- An ink UIStroke (design px thick).
	function fx.stroke(obj, thickness, color)
		local s = mk("UIStroke", { Color = color or C.ink, LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = obj:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border }, obj)
		fx.px(s, "Thickness", thickness or 3)
		return s
	end
	--- A sprite from the atlas: fx.sprite(parent, "burn-t/crust", { x y w h anchor color transparency rotation z })
	function fx.sprite(parent, name, o)
		o = o or {}
		local img = mk("ImageLabel", { BackgroundTransparency = 1, ImageColor3 = o.color or C.white,
			ImageTransparency = o.transparency or 0, ScaleType = Enum.ScaleType.Stretch }, parent)
		fx.setSprite(img, name)
		place(img, o)
		return img
	end
	function fx.setSprite(img, name)
		local e = Atlas.sprites[name]
		if not e then
			if not warnedSprite[name] then warnedSprite[name] = true; warn("[BarFX] no sprite " .. tostring(name)) end
			img.Image = ""
			return
		end
		img.Image = Atlas.images[e[1]]
		img.ImageRectOffset = Vector2.new(e[2], e[3])
		img.ImageRectSize = Vector2.new(e[4], e[5])
	end
	--- A flipbook: cycles an ImageLabel through frames at fps (driven by the kit clock).
	function fx.flip(img, names, fps, phase)
		local st = { img = img, names = names, fps = fps or 10, phase = phase or 0, last = nil }
		timers[#timers + 1] = function()
			if not img.Parent then return end
			local i = (math.floor((fx.clock + st.phase) * st.fps) % #names) + 1
			if i ~= st.last then st.last = i; fx.setSprite(img, names[i]) end
		end
		return st
	end
	--- Ben-Day dots over a rectangle: { x y w h color alpha pitch (design px) z }
	function fx.dots(parent, o)
		local d = mk("ImageLabel", { BackgroundTransparency = 1, Image = DOT_IMAGE, ImageColor3 = o.color or C.ink,
			ImageTransparency = 1 - (o.alpha or 0.25), ScaleType = Enum.ScaleType.Tile }, parent)
		place(d, o)
		local pitch = o.pitch or 7
		d.TileSize = UDim2.fromScale(pitch / (o.w or DW), pitch / (o.h or DH))
		return d
	end
	--- Comic lettering: { x y (centre) size (design px) color stroke rotation z life burst burstColor burstW burstH pop }
	function fx.word(parent, text, o)
		o = o or {}
		local holder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = fx.P(o.x or 320, o.y or 60), Size = fx.S(o.burstW or 200, o.burstH or 80),
			Rotation = o.rotation or 0, ZIndex = o.z or 40 }, parent)
		local scale = mk("UIScale", { Scale = 1 }, holder)
		if o.burst then
			local b = fx.sprite(holder, o.burst, { color = o.burstColor })
			b.Size = UDim2.fromScale(1, 1)
		end
		local t = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.LuckiestGuy,
			Text = text, TextColor3 = o.color or C.white, ZIndex = 2 }, holder)
		fx.px(t, "TextSize", o.size or 26)
		fx.stroke(t, o.stroke or 3, o.strokeColor)
		if o.pop ~= false then
			local born = fx.clock
			timers[#timers + 1] = function()
				if not holder.Parent then return end
				local e = fx.clock - born
				-- stepped overshoot pop, 3 frames: 0.35 -> 1.18 -> 1.0
				scale.Scale = (e < 0.05 and 0.35) or (e < 0.1 and 0.8) or (e < 0.16 and 1.18) or 1
			end
		end
		if o.life then task.delay(o.life, function() if holder.Parent then holder:Destroy() end end) end
		return holder, t
	end
	--- Restyle a real HUD piece while this look is mounted: fx.restyle("fill", { BackgroundColor3 = ... })
	--- targets: bar barStroke fill chip chipStroke glyph label ring
	function fx.restyle(name, props)
		local inst = targetOf(name)
		if not inst then return end
		Restyle.orig[name] = Restyle.orig[name] or {}
		for k in pairs(props) do
			if Restyle.orig[name][k] == nil then Restyle.orig[name][k] = inst[k] end
		end
		Restyle.stack[name] = Restyle.stack[name] or {}
		local mine
		for _, e in ipairs(Restyle.stack[name]) do if e.owner == fx then mine = e end end
		if not mine then
			mine = { owner = fx, props = {} }
			table.insert(Restyle.stack[name], mine)
			restyles[#restyles + 1] = name
		end
		for k, v in pairs(props) do mine.props[k] = v end
		applyRestyle(name)
	end
	--- Shake the whole health row (and every layer with it) by up to amp design px for dur seconds.
	function fx.shake(amp, dur)
		BarFX._shake(amp or 3, dur or 0.2)
	end
	--- A simple particle: fx.emit(parent, spriteNameOrNil, { x y w h vx vy gravity life spin color rotation grow z rect })
	function fx.emit(parent, name, o)
		if #particles >= 40 then return end
		local obj
		if name then obj = fx.sprite(parent, name, { color = o.color, z = o.z })
		else obj = fx.rect(parent, { color = o.color or C.white, corner = o.corner, stroke = o.stroke, z = o.z }) end
		obj.AnchorPoint = Vector2.new(0.5, 0.5)
		local p = { obj = obj, x = o.x, y = o.y, vx = o.vx or 0, vy = o.vy or 0, g = o.gravity or 0, life = o.life or 0.6,
			age = 0, spin = o.spin or 0, rot = o.rotation or 0, w = o.w or 8, h = o.h or o.w or 8, grow = o.grow or 0 }
		particles[#particles + 1] = p
		return p
	end
	function fx._stepParticles(dt)
		for i = #particles, 1, -1 do
			local p = particles[i]
			p.age += dt
			if p.age >= p.life or not p.obj.Parent then
				if p.obj.Parent then p.obj:Destroy() end
				table.remove(particles, i)
			else
				p.vy += p.g * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.rot += p.spin * dt
				local k = 1 + p.grow * (p.age / p.life)
				p.obj.Position = fx.P(p.x, p.y)
				p.obj.Size = fx.S(p.w * k, p.h * k)
				p.obj.Rotation = p.rot
			end
		end
		for _, t in ipairs(timers) do t() end
	end
	--- helpers for comic timing
	function fx.stepped(t, fps) return math.floor(t * fps) / fps end
	function fx.lerp(a, b, t) return a + (b - a) * t end
	function fx.clamp(v, a, b) return math.clamp(v, a, b) end
	function fx.rand(seed) -- deterministic 0..1 from an integer seed
		local x = math.sin(seed * 12.9898 + 78.233) * 43758.5453
		return x - math.floor(x)
	end

	--- Drop this look's restyle of one HUD piece (or all of them): the piece goes back to what it was.
	function fx.unrestyle(name)
		for idx = #restyles, 1, -1 do
			local n = restyles[idx]
			if name == nil or n == name then
				local list = Restyle.stack[n]
				for i = #list, 1, -1 do if list[i].owner == fx then table.remove(list, i) end end
				applyRestyle(n)
				if #list == 0 then Restyle.orig[n] = nil end
				table.remove(restyles, idx)
			end
		end
	end
	function fx._destroy()
		fx.unrestyle()
		for _, p in ipairs(particles) do if p.obj.Parent then p.obj:Destroy() end end
		for _, o in ipairs(owned) do if o.Parent then o:Destroy() end end
		table.clear(particles); table.clear(timers)
	end
	return fx
end

----------------------------------------------------------------------------------------------------
-- variants
----------------------------------------------------------------------------------------------------
local VariantsFolder = script:FindFirstChild("Variants")
local Loaded = {}
function BarFX.Variant(kind, id)
	local key = kind .. "_" .. id
	if Loaded[key] ~= nil then return Loaded[key] or nil end
	local m = VariantsFolder and VariantsFolder:FindFirstChild(key)
	local ok, v = false, nil
	if m then ok, v = pcall(require, m) end
	if not ok and m then warn("[BarFX] " .. key .. " failed to load: " .. tostring(v)) end
	Loaded[key] = (ok and type(v) == "table" and v.mount) and v or false
	if Loaded[key] and v.title then BarFX.NAMES[key] = v.title end
	return Loaded[key] or nil
end

function BarFX.Choice(kind)
	local v = player and player:GetAttribute("BarFX_" .. kind)
	if v == nil then return BarFX.DEFAULT end
	return v
end
function BarFX.SetChoice(kind, id)
	player:SetAttribute("BarFX_" .. kind, id)
end

----------------------------------------------------------------------------------------------------
-- state: from the character's attributes, or from a preview timeline
----------------------------------------------------------------------------------------------------
local folder = ReplicatedStorage:FindFirstChild("Spellshot")
local function liveMax(kind)
	local rx = BarFX.RX[kind]
	local m = folder and folder:GetAttribute("StatusMax_" .. rx)
	return m or DEFAULT_MAX[kind]
end

-- the bench's timelines (bench/template.html), for previews
local TL = {
	burn    = { max = 3, loop = 10.4, stacks = { 1.0, 2.4, 3.8 }, tickEvery = 0.5, ["end"] = 8.8, drainFrom = 3.8 },
	chill   = { max = 3, loop = 7.0,  stacks = { 1.0, 2.2 }, pay = { 3.4, 4.9 }, ["end"] = 4.9, drainFrom = 2.2, window = 5 },
	poison  = { max = 2, loop = 9.6,  stacks = { 1.0, 2.6 }, tickEvery = 1.0, ["end"] = 7.6, drainFrom = 2.6 },
	charged = { max = 3, loop = 6.8,  stacks = { 1.0, 2.1, 3.2 }, pay = { 4.3, 5.3 }, ["end"] = 5.3, drainFrom = 3.2, window = 5 },
	marked  = { max = 1, loop = 7.6,  stacks = { 1.0 }, pay = { 5.6, 6.3 }, ["end"] = 6.3, drainFrom = 1.0, window = 8 },
	blessed = { max = 1, loop = 7.2,  stacks = { 1.0 }, hits = { 2.4, 3.6, 4.8 }, pay = { 4.8, 5.5 }, ["end"] = 5.5, absorb = true },
	shield  = { max = 1, loop = 7.2,  stacks = { 1.0 }, hits = { 2.4, 3.6, 4.8 }, pay = { 4.8, 5.5 }, ["end"] = 5.5, absorb = true },
	primed  = { max = 1, loop = 8.6,  stacks = { 1.0 }, pay = { 7.0, 7.8 }, ["end"] = 7.8, drainFrom = 1.0, fuse = 6.0 },
}
BarFX.TIMELINES = TL
function BarFX.TimelineState(kind, time)
	local T = TL[kind]
	local x = time % T.loop
	local on = x >= T.stacks[1] and x < T["end"]
	local s = 0
	for _, at in ipairs(T.stacks) do if x >= at then s += 1 end end
	local pay = T.pay ~= nil and x >= T.pay[1] and x < T.pay[2]
	if pay and kind == "chill" then s = 3 end
	if not on then s = 0 end
	local t = 0
	if on then
		if T.absorb then t = 1
		elseif kind == "primed" then t = math.max(0, 1 - (x - T.stacks[1]) / T.fuse)
		elseif kind == "chill" and pay then t = 1 - (x - T.pay[1]) / (T.pay[2] - T.pay[1])
		elseif kind == "marked" then t = math.max(0, 1 - (x - T.drainFrom) / T.window)
		else
			local span = T["end"] - T.drainFrom
			t = x < T.drainFrom and 1 or math.max(0, 1 - (x - T.drainFrom) / span)
			if kind == "chill" or kind == "charged" then
				local lastAt = 0
				for _, a in ipairs(T.stacks) do if x >= a then lastAt = a end end
				t = math.max(0, 1 - (x - lastAt) / T.window)
			end
		end
	end
	local a = 0
	if T.absorb and on then
		local n = 0
		for _, h in ipairs(T.hits) do if x >= h then n += 1 end end
		a = math.max(0, 1 - n / 3)
	end
	local hp = 0.78
	if T.tickEvery and on then hp -= 0.012 * math.floor((x - T.stacks[1]) / T.tickEvery) * (kind == "poison" and 2 or 1) end
	if kind == "chill" or kind == "charged" then hp -= 0.05 * math.min(s, 3) end
	if kind == "primed" and x >= T.pay[1] then hp -= 0.24 end
	if kind == "marked" and x >= T.pay[1] then hp -= 0.2 end
	if T.absorb and x >= T.pay[1] then hp -= 0.06 end
	return { kind = kind, on = on, s = s, max = T.max, k = s / T.max, t = t, a = a, hp = math.max(0.05, hp), pay = pay,
		time = x, rawS = s, rawMax = T.max, preview = true }
end
local function timelineEvents(kind, p, n)
	local T, out = TL[kind], {}
	if not p then return out end
	if not p.on and n.on then out[#out + 1] = "on" end
	if n.s > p.s and n.on and not n.pay then out[#out + 1] = "stack" end
	if n.pay and not p.pay then out[#out + 1] = "pay" end
	if p.on and not n.on then out[#out + 1] = "end" end
	if T.tickEvery and n.on and p.on and math.floor((n.time - T.stacks[1]) / T.tickEvery) > math.floor((p.time - T.stacks[1]) / T.tickEvery) then
		out[#out + 1] = "tick"
	end
	if T.hits then for _, h in ipairs(T.hits) do if p.time < h and n.time >= h and n.on then out[#out + 1] = "hit" end end end
	return out
end

-- live state from attributes. Per kind a little memory: the amount's peak, when it came on, a held payoff.
local Mem = {}
local function liveState(kind, character, humanoid, now, serverNow)
	local rx = "RX_" .. BarFX.RX[kind]
	local m = Mem[kind] or {}
	Mem[kind] = m
	local on = character:GetAttribute(rx) == true
	local rawS = character:GetAttribute(rx .. "_Stacks")
	local expires = character:GetAttribute(rx .. "_Expires")
	local total = character:GetAttribute(rx .. "_Total")
	local amount = character:GetAttribute(rx .. "_Amount")
	local hp = humanoid and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
	local events = {}
	local rawMax = liveMax(kind)
	local visMax = (kind == "charged") and math.max(1, rawMax - 1) or rawMax   -- Charged discharges ON its max stack
	if on then
		rawS = tonumber(rawS) or 1
		local t = 1
		if expires and total and total > 0 then t = math.clamp((expires - serverNow) / total, 0, 1) end
		local pay = false
		if kind == "chill" and rawS >= rawMax then pay = true end
		local a = 0
		if kind == "blessed" or kind == "shield" then
			amount = tonumber(amount) or 0
			if not m.on or amount > (m.peak or 0) then m.peak = amount end
			if m.on and m.amount and amount < m.amount - 0.01 then events[#events + 1] = "hit" end
			a = (m.peak and m.peak > 0) and math.clamp(amount / m.peak, 0, 1) or 1
			m.amount = amount
		end
		local s
		if pay then s = BENCH_MAX[kind] else s = math.clamp(math.ceil(rawS / visMax * BENCH_MAX[kind] - 1e-6), 1, BENCH_MAX[kind]) end
		if not m.on then events[#events + 1] = "on" end
		if m.on and s > (m.s or 0) and not pay then events[#events + 1] = "stack" end
		if pay and not m.pay then events[#events + 1] = "pay" end
		if (kind == "burn" or kind == "poison") and m.on and m.hp and hp < m.hp - 0.001 then events[#events + 1] = "tick" end
		m.on, m.s, m.pay, m.t, m.a, m.hp, m.expires = true, s, pay, t, a, hp, expires
		m.since = m.since or now
		m.holdUntil = nil
		return { kind = kind, on = true, s = s, max = BENCH_MAX[kind], k = s / BENCH_MAX[kind], t = t, a = a, hp = hp, pay = pay,
			time = now - m.since, rawS = rawS, rawMax = rawMax }, events
	end
	-- off. Did it just drop in a way that IS its payoff (the server shows these only as the flag falling)?
	if m.on then
		m.on = false
		local early = m.expires and (m.expires - serverNow) > 0.25
		local payoff = (kind == "charged" and early) or (kind == "marked" and early)
			or ((kind == "blessed" or kind == "shield") and (m.amount or 1) <= 0.01)
			or (kind == "primed" and m.expires and math.abs(m.expires - serverNow) < 0.5)
		m.since = nil
		if payoff then
			m.holdUntil = now + PAY_HOLD
			events[#events + 1] = "pay"
		else
			events[#events + 1] = "end"
			m.s, m.pay = 0, false
		end
	end
	if m.holdUntil then
		if now < m.holdUntil then
			return { kind = kind, on = true, s = BENCH_MAX[kind], max = BENCH_MAX[kind], k = 1, t = 0, a = 0, hp = hp, pay = true,
				time = 0, rawS = 0, rawMax = rawMax }, events
		end
		m.holdUntil = nil
		m.s, m.pay = 0, false
		events[#events + 1] = "end"
	end
	return { kind = kind, on = false, s = 0, max = BENCH_MAX[kind], k = 0, t = 0, a = 0, hp = hp, pay = false, time = 0,
		rawS = 0, rawMax = rawMax }, events
end

----------------------------------------------------------------------------------------------------
-- the driver
----------------------------------------------------------------------------------------------------
local Active = {}       -- [kind] = { id, fx, look, endedAt, lastSt }  (declared at the driver)
local Preview = {}      -- [kind] = { t0, id (nil = the pick), loops, prev }
local shakeState = { amp = 0, untilT = 0, base = nil }

function BarFX._shake(amp, dur)
	shakeState.amp = math.max(shakeState.amp, amp)
	shakeState.untilT = math.max(shakeState.untilT, os.clock() + dur)
end
local function stepShake(now)
	if not (H.row and H.row.Parent) then return end
	if now < shakeState.untilT then
		shakeState.base = shakeState.base or H.row.Position
		local a = shakeState.amp * Map.barPx
		local f = math.floor(now * 30)
		local dx = (((f * 7919) % 13) / 6 - 1) * a
		local dy = (((f * 104729) % 11) / 5 - 1) * a * 0.6
		H.row.Position = shakeState.base + UDim2.fromOffset(dx, dy)
	elseif shakeState.base then
		H.row.Position = shakeState.base
		shakeState.base = nil
		shakeState.amp = 0
	end
end

local function unmount(kind)
	local a = Active[kind]
	if not a then return end
	if a.look and a.look.destroy then pcall(a.look.destroy) end
	a.fx._destroy()
	Active[kind] = nil
end
function unmountAll()
	for _, k in ipairs(BarFX.KINDS) do unmount(k) end
end
local function mount(kind, id, isPreview)
	local V = BarFX.Variant(kind, id)
	if not V then return nil end
	local fx = makeContext(kind, id, isPreview)
	local ok, look = pcall(V.mount, fx)
	if not ok then
		warn("[BarFX] " .. kind .. "_" .. id .. " mount: " .. tostring(look))
		fx._destroy()
		return nil
	end
	Active[kind] = { id = id, fx = fx, look = look or {} }
	return Active[kind]
end

--- Play the bench timeline of `kind` on your own bar with look `id` (nil = your pick). holdAt (seconds) stops the
--- timeline at that moment and keeps it there until StopPreview -- the words and particles already launched play out.
--- startAt jumps into the timeline (the stacks before it are not replayed as events).
function BarFX.Preview(kind, id, loops, holdAt, startAt)
	Preview[kind] = { t0 = os.clock() - (startAt or 0), id = id, loops = loops or 1, prev = nil, holdAt = holdAt }
	unmount(kind)
end
function BarFX.StopPreview(kind)
	if kind then Preview[kind] = nil; unmount(kind) return end
	for k in pairs(Preview) do Preview[k] = nil; unmount(k) end
end
--- Show A, then B, then C, one loop each.
function BarFX.Compare(kind)
	task.spawn(function()
		for _, id in ipairs({ "t", "a", "f" }) do
			BarFX.Preview(kind, id, 1)
			task.wait(TL[kind].loop)
			if not Preview[kind] or Preview[kind].id ~= id then return end
		end
		BarFX.StopPreview(kind)
	end)
end

-- A SKIN'S STATUS LOOK (2026-10-14): a status stamped with its caster's skin (RX_<Status>_Skin, written by the server)
-- wears that skin's look in place of the DEFAULT one (SkinCatalog.HudBar: skin + status kind -> a variant id). A dev-panel
-- pick other than the Default, and every preview, are left alone.
local SkinCat
local function skinLook(kind, character)
	local skin = character:GetAttribute("RX_" .. BarFX.RX[kind] .. "_Skin")
	if type(skin) ~= "string" then return nil end
	if SkinCat == nil then
		local ok, m = pcall(function() return require(folder:WaitForChild("SkinCatalog", 2)) end)
		SkinCat = ok and type(m) == "table" and m or false
	end
	return SkinCat and SkinCat.HudBar and SkinCat.HudBar(skin, kind) or nil
end

local lastClock, sweepAt
local function step()
	local now = os.clock()
	local dt = lastClock and math.min(0.1, now - lastClock) or 0
	lastClock = now
	if not hudLive() then
		if not findHud() or not hudLive() then
			if Host.backGui then Host.backGui.Enabled = false; Host.frontGui.Enabled = false end
			return
		end
	end
	buildBarHosts()
	Host.backGui.Enabled, Host.frontGui.Enabled = true, true
	-- the HUD's own opacity (Settings) and the status intensity setting
	local groupT = H.opacity and H.opacity:IsA("CanvasGroup") and H.opacity.GroupTransparency or 0
	Host.backGroup.GroupTransparency = groupT
	Host.frontGroup.GroupTransparency = groupT
	local sz = H.interior.AbsoluteSize
	if sz.X ~= Map.lastW or sz.Y ~= Map.lastH or H.interior.AbsolutePosition ~= Map.lastP then
		Map.lastW, Map.lastH, Map.lastP = sz.X, sz.Y, H.interior.AbsolutePosition
		solveMap()
		rescaleAll()
	end
	stepShake(now)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local serverNow = workspace:GetServerTimeNow()
	for _, kind in ipairs(BarFX.KINDS) do
		local st, events
		local pv = Preview[kind]
		if pv then
			local t = now - pv.t0
			local T = TL[kind]
			if pv.holdAt and t > pv.holdAt then t = pv.holdAt end
			if not pv.holdAt and t >= T.loop * pv.loops then
				Preview[kind] = nil
				st, events = { kind = kind, on = false, s = 0, max = T.max, k = 0, t = 0, a = 0, hp = 0.78, pay = false, time = 0 }, { "end" }
			else
				st = BarFX.TimelineState(kind, t)
				-- the real bar keeps showing your real health, so the look is given the same number
				st.hp = humanoid and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
				events = timelineEvents(kind, pv.prev, st)
				pv.prev = st
			end
		elseif character then
			st, events = liveState(kind, character, humanoid, now, serverNow)
		end
		if st then
			local id = (pv and pv.id) or BarFX.Choice(kind)
			if not pv and id == BarFX.DEFAULT and character then id = skinLook(kind, character) or id end
			local a = Active[kind]
			if a and a.id ~= id then unmount(kind); a = nil end
			if id ~= "old" then
				-- back on while its exit was playing: start the look fresh (its restyles were dropped at 'end')
				if st.on and a and a.endedAt then unmount(kind); a = nil end
				if st.on and not a then a = mount(kind, id, pv ~= nil) end
				if a then
					a.fx.clock += dt
					if st.on then a.endedAt = nil end
					for _, e in ipairs(events) do
						if e == "end" then a.endedAt = now; a.fx.unrestyle() end
						if a.look.event then
							local ok, err = pcall(a.look.event, e, st)
							if not ok then warn("[BarFX] " .. kind .. "_" .. a.id .. " event " .. e .. ": " .. tostring(err)) end
						end
					end
					if a.look.update then
						local ok, err = pcall(a.look.update, st, dt)
						if not ok then warn("[BarFX] " .. kind .. "_" .. a.id .. " update: " .. tostring(err)); a.look.update = nil end
					end
					a.fx._stepParticles(dt)
					if a.endedAt and now - a.endedAt > LINGER and not st.on then unmount(kind) end
				end
			elseif a then
				unmount(kind)
			end
		end
	end
	-- the fill layer is cut to the real bar's own fill, so a look's fill and the HUD's never disagree
	setFill((H.clip and H.interior.Size.X.Offset > 0) and H.clip.Size.X.Offset / H.interior.Size.X.Offset or 1)
	-- words and strokes that were destroyed leave entries behind; sweep them now and then
	sweepAt = (sweepAt or 0) + 1
	if sweepAt % 240 == 0 then rescaleAll() end
end
BarFX._step = step

local started = false
function BarFX.Start()
	if started then return end
	started = true
	buildHosts()
	-- a pick changed: remount on the next frame
	player.AttributeChanged:Connect(function(name)
		local kind = name:match("^BarFX_(%w+)$")
		if kind and Active[kind] then unmount(kind) end
	end)
	player.CharacterAdded:Connect(function()
		for _, k in ipairs(BarFX.KINDS) do unmount(k); Mem[k] = nil end
	end)
	-- A command channel for tools that cannot require this module (Studio's MCP runs in a VM of its own):
	-- LocalPlayer attribute BarFXCommand = "preview burn [t|a|f]" | "hold burn t 4.2" | "compare burn" | "stop"
	player:GetAttributeChangedSignal("BarFXCommand"):Connect(function()
		local cmd = player:GetAttribute("BarFXCommand")
		if type(cmd) ~= "string" or cmd == "" then return end
		player:SetAttribute("BarFXCommand", nil)
		local w = {}
		for part in cmd:gmatch("%S+") do w[#w + 1] = part end
		local verb, kind, id = w[1], w[2], w[3]
		if verb == "stop" then BarFX.StopPreview(kind)
		elseif not TL[kind] then warn("[BarFX] command: unknown status " .. tostring(kind))
		elseif verb == "preview" then BarFX.Preview(kind, id, tonumber(w[4]) or 1)
		elseif verb == "hold" then
			-- run the last 0.7 s up to the moment, so the events there (a payoff, a stack) still fire
			local at = tonumber(w[4]) or 2
			BarFX.Preview(kind, id, 1, at, math.max(0, at - 0.7))
		elseif verb == "compare" then BarFX.Compare(kind) end
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then warn("[BarFX] step: " .. tostring(err)) end
	end)
end

return BarFX
