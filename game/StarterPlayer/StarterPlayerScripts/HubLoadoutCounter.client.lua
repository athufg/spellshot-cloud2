--[[
	HubLoadoutCounter (LocalScript, StarterPlayerScripts) -- 2026-10-27, the owner's brief: the 3-slot stone counter
	north of the Loadout altar (merged into the hub meshes, collider Coll_furn_0263; its geometry and material stay as
	they are) shows THIS player's equipped loadout instead of three black wells. Left to right as you face it from the
	altar ring (looking north): Mobility, Defense, Ultimate, the Loadout menu's own order.

	Per slot, on this client only:
	  * a glowing well floor: Neon in the slot's Element colour (a borrowed Technique wears its origin's, as on the
	    HUD), just over the black floor (OBS_Screen_Dark_01, top y 2.37) and inside the white rim, breathing slowly;
	  * an icon card floating over it: a thin gold plate with a SurfaceGui (LightInfluence 0): a gold frame, a navy field
	    tinted by the Element, the ability's icon (as the HUD picks it: the skin's HUD set > IconAssets.Ability > the
	    Role glyph), tilted back Tuning.Tilt toward a player standing in front, bobbing and swaying gently;
	  * a soft PointLight in the Element colour over the well, and faint motes rising out of it.
	THE LOADOUT is the player's attributes (the server's, Config.ApplyElement): Element, Mobility and Defense (pool keys,
	Config.Technique), and the Element's own Ultimate (Config.ElementUltimate; the Ultimate attribute only mirrors it).
	Config.DefaultLoadout until they arrive. It updates live when any of them, or an ElementSkin_ / HudSkinPreview_
	attribute (a skin's HUD icons), changes.
	One BulkMoveTo a frame for the three cards; nothing moves and no mote rises while the camera is far
	(HubLife.Close, Tuning.FarAway).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
if not workspace:WaitForChild(HubLife.Hub, 60) then return end
local Config = require(spell:WaitForChild("SpellshotConfig"))
local Icons = require(spell:WaitForChild("IconAssets"))
local Art = require(spell:WaitForChild("PopArtAssets"))
local SkinCatalog = require(spell:WaitForChild("SkinCatalog"))

local player = Players.LocalPlayer

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	-- the counter's frame (Coll_furn_0263: centre 7937.618, 8023.416, yaw 10; y 0 = the floor; its front looks to -Z)
	Frame = CFrame.new(7937.618, 0, 8023.416) * CFrame.Angles(0, math.rad(10), 0),
	-- the three black slot floors, measured 2026-10-27 from OBS_Screen_Dark_01's triangles: 1.32 square at these x,
	-- z -0.528, top y 2.37 (the white rims stand to 2.41). +X is the viewer's left
	SlotX = { Mobility = 2.15, Defense = 0, Ultimate = -2.15 },
	SlotZ = -0.528,
	Floor = 2.37,
	Well = 1.26, WellThick = 0.02,
	WellGlow = { 0.3, 0.55 },       -- the well's Transparency, breathing between these (over the black floor: a deep glow)
	Breathe = 2.8,                  -- seconds a breath
	Card = 0.9, CardThick = 0.04,
	CardUp = 0.8,                   -- the card's centre over the floor
	Tilt = 35,                      -- degrees the card leans back, its face toward a player at the front
	Bob = 0.05, BobSpeed = 1.3,     -- studs, radians a second
	Sway = 7, Roll = 2.5, SwaySpeed = 0.6,   -- degrees, radians a second
	Gold = Color3.fromHex("be8c3c"),         -- OBS_Trim_Gold (the plate's edges and back)
	CardFrame = HubLife.TrimYellow,          -- the card's gold frame
	Field = Color3.fromHex("1b2440"),        -- OBS_Cloth_Navy, tinted by the Element
	Tint = 0.3,
	Px = 200,                                -- SurfaceGui pixels a stud
	Light = { Up = 0.5, Brightness = 0.5, Range = 2.6 },   -- soft: brighter or wider floods the pillars and trim cyan
	Mote = { Rate = 4, Life = { 1.2, 2.0 }, Speed = { 0.35, 0.6 }, Size = 0.08 },
	FarAway = 70,                            -- studs from the counter: nothing moves past this
}
local ROLES = { "Mobility", "Defense", "Ultimate" }
local F = Tuning.Frame
local CENTRE = F * Vector3.new(0, Tuning.Floor, Tuning.SlotZ)

local ABILITY = Icons.Ability or {}
local OWN = { Technique = ABILITY.Technique or {}, Ultimate = ABILITY.Ultimate or {} }
local SKINNED = ABILITY.Skins or {}

----------------------------------------------------------------------------------------------------
-- the loadout and its icons (PopArtHUD's rules)
----------------------------------------------------------------------------------------------------
local function loadout()
	local d = Config.DefaultLoadout
	local el = player:GetAttribute("Element") or d.Element
	return {
		Element = el,
		Mobility = player:GetAttribute("Mobility") or d.Mobility,
		Defense = player:GetAttribute("Defense") or d.Defense,
		Ultimate = Config.ElementUltimate(el) or player:GetAttribute("Ultimate") or d.Ultimate,
	}
end

local function skinIcon(elem, pool, key)
	local ok, hs = pcall(SkinCatalog.HudSkin, player, elem)
	local t = ok and hs ~= "Default" and SKINNED[hs] and SKINNED[hs][pool]
	local id = t and t[key]
	return (type(id) == "string" and id ~= "") and id or nil
end

local function roleGlyph(role, elem)
	local a = Art.Role and Art.Role[role]
	local b = Icons.Role and Icons.Role[role]
	return (a and a[elem]) or (b and b[elem]) or ""
end

--- the icon for `role` in loadout `l`, and the Element whose colours it wears
local function iconFor(l, role)
	local elem = Config.SlotElement(l, role)
	local key = l[role]
	if role == "Ultimate" then
		return (key and (skinIcon(elem, "Ultimate", key) or OWN.Ultimate[key])) or roleGlyph("Ultimate", elem), elem
	end
	local _, half = Config.Technique(key)
	return (key and (skinIcon(elem, "Technique", key) or OWN.Technique[key])) or roleGlyph(half or role, elem), elem
end

----------------------------------------------------------------------------------------------------
-- the slots
----------------------------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "HubLoadoutCounter"

local function part(name, size, cf, colour, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local function corner(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local slots = {}
for i, role in ipairs(ROLES) do
	local base = F * CFrame.new(Tuning.SlotX[role], Tuning.Floor, Tuning.SlotZ)
	local s = { Role = role, Phase = i * 2.1 }

	-- the well's glowing floor, inside the white rim
	s.Well = part("Well_" .. role, Vector3.new(Tuning.Well, Tuning.WellThick, Tuning.Well),
		base * CFrame.new(0, Tuning.WellThick / 2 + 0.003, 0), Color3.new(1, 1, 1), Enum.Material.Neon)
	s.Well.Transparency = Tuning.WellGlow[1]

	-- the light and the motes, from a point over the well
	local at = Instance.new("Attachment")
	at.Name = "Glow"
	at.Position = Vector3.new(0, Tuning.Light.Up, 0)
	at.Parent = s.Well
	s.Light = Instance.new("PointLight")
	s.Light.Brightness, s.Light.Range, s.Light.Shadows = Tuning.Light.Brightness, Tuning.Light.Range, false
	s.Light.Parent = at
	local m = Tuning.Mote
	s.Motes = Instance.new("ParticleEmitter")
	s.Motes.Name = "Motes"
	s.Motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	s.Motes.Shape = Enum.ParticleEmitterShape.Box
	s.Motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	s.Motes.EmissionDirection = Enum.NormalId.Top
	s.Motes.Rate = m.Rate
	s.Motes.Lifetime = NumberRange.new(m.Life[1], m.Life[2])
	s.Motes.Speed = NumberRange.new(m.Speed[1], m.Speed[2])
	s.Motes.SpreadAngle = Vector2.new(12, 12)
	s.Motes.Drag = 0.6
	s.Motes.Rotation = NumberRange.new(0, 360)
	s.Motes.RotSpeed = NumberRange.new(-60, 60)
	s.Motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, m.Size), NumberSequenceKeypoint.new(1, 0) })
	s.Motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.25),
		NumberSequenceKeypoint.new(1, 1) })
	s.Motes.LightEmission, s.Motes.LightInfluence = 1, 0
	s.Motes.Parent = s.Well

	-- the icon card: a gold plate, its front a SurfaceGui
	s.Base = base * CFrame.new(0, Tuning.CardUp, 0)
	s.Card = part("Card_" .. role, Vector3.new(Tuning.Card, Tuning.Card, Tuning.CardThick),
		s.Base * CFrame.Angles(math.rad(Tuning.Tilt), 0, 0), Tuning.Gold)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Tuning.Px
	gui.LightInfluence = 0
	gui.ClipsDescendants = true
	gui.Parent = s.Card
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Tuning.CardFrame
	frame.BorderSizePixel = 0
	corner(frame, 0.08)
	frame.Parent = gui
	s.Field = Instance.new("Frame")
	s.Field.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Field.Position = UDim2.fromScale(0.5, 0.5)
	s.Field.Size = UDim2.fromScale(0.86, 0.86)
	s.Field.BorderSizePixel = 0
	corner(s.Field, 0.06)
	s.Stroke = Instance.new("UIStroke")
	s.Stroke.Thickness = 4
	s.Stroke.Parent = s.Field
	s.Field.Parent = frame
	s.Icon = Instance.new("ImageLabel")
	s.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Icon.Position = UDim2.fromScale(0.5, 0.5)
	s.Icon.Size = UDim2.fromScale(0.86, 0.86)
	s.Icon.BackgroundTransparency = 1
	s.Icon.ScaleType = Enum.ScaleType.Fit
	s.Icon.Parent = s.Field
	slots[i] = s
end

-- (2026-10-27, the owner) a SHOWCASE, not the loadout: players only pick an Element before a match, so there is no
-- equipped technique to show. Each card cycles on its own clock through every Element's abilities (its Mobility,
-- Defense and Ultimate, Config.ElementDefaults / ElementUltimate), and its well, light, motes and frame take the colour
-- of the Element that ability belongs to. The swap: the icon fades out, the colours slide over, the new icon fades in.
local TweenService = game:GetService("TweenService")
local POOL = {}
for _, el in ipairs(Config.ElementOrder or {}) do
	local d = Config.ElementDefaults and Config.ElementDefaults[el] or {}
	local entries = { { "Mobility", d.Mobility, OWN.Technique }, { "Defense", d.Defense, OWN.Technique },
		{ "Ultimate", Config.ElementUltimate(el), OWN.Ultimate } }
	for _, e in ipairs(entries) do
		local icon = (e[2] and e[3][e[2]]) or roleGlyph(e[1], el)
		if type(icon) == "string" and icon ~= "" then POOL[#POOL + 1] = { Icon = icon, Element = el } end
	end
end
local CYCLE = { Hold = 4.2, Stagger = 1.4, Fade = 0.22, Slide = 0.45 }
local slideInfo = TweenInfo.new(CYCLE.Slide, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function paint(s, entry, instant)
	local c = Config.ElementColor(entry.Element)
	s.Motes.Color = ColorSequence.new(c, Color3.new(1, 1, 1))
	local goals = {
		{ s.Well, { Color = c } }, { s.Light, { Color = c } }, { s.Stroke, { Color = c } },
		{ s.Field, { BackgroundColor3 = Tuning.Field:Lerp(c, Tuning.Tint) } },
	}
	for _, g in ipairs(goals) do
		if instant then
			for k, v in pairs(g[2]) do g[1][k] = v end
		else
			TweenService:Create(g[1], slideInfo, g[2]):Play()
		end
	end
end

--- the next entry for slot `s`: a different Element from its last and from the other cards' current ones
local function pick(s)
	local busy = {}
	for _, o in ipairs(slots) do if o ~= s and o.Entry then busy[o.Entry.Element] = true end end
	for _ = 1, #POOL do
		s.Next = s.Next % #POOL + 1
		local e = POOL[s.Next]
		if not busy[e.Element] and (not s.Entry or e.Element ~= s.Entry.Element) then return e end
	end
	s.Next = s.Next % #POOL + 1
	return POOL[s.Next]
end

for i, s in ipairs(slots) do
	s.Next = (i - 1) * math.max(1, math.floor(#POOL / 3))
	s.Entry = pick(s)
	s.Icon.Image = s.Entry.Icon
	paint(s, s.Entry, true)
end
folder.Parent = workspace

if #POOL > 1 then
	for i, s in ipairs(slots) do
		task.spawn(function()
			task.wait(CYCLE.Hold + (i - 1) * CYCLE.Stagger)
			while true do
				local e = pick(s)
				TweenService:Create(s.Icon, TweenInfo.new(CYCLE.Fade), { ImageTransparency = 1 }):Play()
				task.wait(CYCLE.Fade)
				s.Entry = e
				s.Icon.Image = e.Icon
				paint(s, e, false)
				TweenService:Create(s.Icon, TweenInfo.new(CYCLE.Fade), { ImageTransparency = 0 }):Play()
				task.wait(CYCLE.Hold + CYCLE.Fade)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- the motion
----------------------------------------------------------------------------------------------------
local parts, cfs = {}, {}
for i, s in ipairs(slots) do parts[i] = s.Card end
local TILT, SWAY, ROLL = math.rad(Tuning.Tilt), math.rad(Tuning.Sway), math.rad(Tuning.Roll)
local live = true

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local near = cam ~= nil and HubLife.Close() and (cam.CFrame.Position - CENTRE).Magnitude < Tuning.FarAway
	if near ~= live then
		live = near
		for _, s in ipairs(slots) do s.Motes.Enabled = near end
	end
	if not near then return end
	local t = os.clock()
	local g = Tuning.WellGlow
	for i, s in ipairs(slots) do
		local ph = s.Phase
		cfs[i] = s.Base * CFrame.new(0, math.sin(t * Tuning.BobSpeed + ph) * Tuning.Bob, 0)
			* CFrame.Angles(0, math.sin(t * Tuning.SwaySpeed + ph * 1.7) * SWAY, 0)
			* CFrame.Angles(TILT, 0, 0)
			* CFrame.Angles(0, 0, math.sin(t * Tuning.SwaySpeed * 0.8 + ph * 0.9) * ROLL)
		s.Well.Transparency = g[1] + (g[2] - g[1]) * (0.5 + 0.5 * math.sin(t * 2 * math.pi / Tuning.Breathe + ph))
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
