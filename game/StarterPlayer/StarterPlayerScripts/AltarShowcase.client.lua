--[[
	AltarShowcase  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/AltarShowcase

	THE LOADOUT SHOWCASE (2026-10-26, the owner; v2): interacting with the Loadout Altar CUTS -- behind the hub's own ink
	wipe (HubWipe) -- to the showcase's dedicated room, workspace.LoadoutShowcaseChamber (ShowcaseChamberBuild), where the
	pedestal rig (HubShowcaseM1) holds the equipped Element's M1 in its selected wrap on the centre pedestal.
	  * THE PIECE turns on a slow turntable (the camera orbits the room); click-drag orbits it with weight (the drag
	    feeds a velocity that eases out on release).
	  * ELEMENTS (rail): the piece breaks apart in its own Element's language and reforms in the new one's; the room's
	    mood parts (Mood = Base/Light/Dark), its lights and the soft corona behind the piece (the hub crystal's own
	    breathing radial bloom) drift to the new Element's colours.
	  * WRAPS: rarity tiles (HubLifeKit's ladder); a tile shows and equips the wrap (switching Element first if needed).
	  * IT OPENS WITH NOTHING PICKED (2026-10-27, the owner), not even the equipped Element: the panel is the Element rail
	    alone, and the WRAPS | SKINS list opens out beside it once an Element is clicked. Until then the pedestal stands
	    empty, the room's mood is neutral and PREVIEW MOVES lists nothing (2026-10-27, the owner: nothing picked,
	    nothing shown); clicking the picked Element again closes the column. The lobby never equips an Element (2026-10-27, the owner: you pick what you fight with in the game), so the
	    rail has no EQUIPPED tag, and a wrap or skin is set on its own Element, whichever one you play.
	  * PREVIEW MOVES: the pedestal sinks into the stage, two mannequins step in (AltarStage), and the move module
	    (AltarMoves/<Element>) has the caster perform the move for real -- cast poses, VFX, the selected wrap -- on the
	    target, which takes the hit; it loops. Closing the list or changing Element clears them and raises the pedestal.
	  * OUT: Esc / the X / TECHNIQUES (then the flat menu): the wipe again, and the player's own camera back.
	Studio check hook: PlayerGui.AltarShowcase.Command:Fire("open" | "close" | "element", el | "wrap", id | "move", i | "dropdown" | "orbit", deg/s
  | "fit", Vector2 (lay the screen out for that screen size; no arg = the real screen)).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local AssetService = game:GetService("AssetService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
local K = require(spell:WaitForChild("HubLifeKit"))
local Config = require(spell:WaitForChild("SpellshotConfig"))
local Skins = require(spell:WaitForChild("SkinCatalog"))
local Economy = require(spell:WaitForChild("EconomyConfig"))
local M1 = require(spell:WaitForChild("HubShowcaseM1"))
local loadoutRemote = spell:WaitForChild("LoadoutRequest")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Chamber = "LoadoutShowcaseChamber", Centre = Vector3.new(8000, 0, 4000),   -- (ShowcaseChamberBuild's room)
	Lift = 7.6,                                   -- the piece floats this high over the room's floor (over the pedestal cap)
	Face = Vector3.new(0, 0, 1),                  -- the camera's home side
	Dist = 15, Height = 2.2, FOV = 46, Aside = -2.6,   -- framing: studs out, studs over the piece, degrees, the rail's offset
	MoveDist = 27, MoveHeight = -0.8, Spin = 7,   -- move previews are seen from further back; the turntable, degrees a second
	In = 0.9, Out = 0.35, Sink = 4.2, SinkTime = 0.6,   -- the push after the cut; the pedestal's sink for previews
	Orbit = { Yaw = 1e9, PitchLo = -12, PitchHi = 60, Gain = 0.32, Friction = 3.4,   -- degrees; Gain: degrees per px of drag
		Sway = 16, SwayHz = 0.05, SwayAfter = 1.6 },                                   -- the idle sway, once the hand lets go for SwayAfter s
	Mood = { Time = 0.9, Tint = 0.14, Spot = 3.2, Rim = 2.4 },
	Corona = { W = 13, H = 13, Alpha = { 0.55, 0.32 }, Period = 5, Res = 256 },   -- the hub crystal's breathing bloom
	Ambient = Color3.fromRGB(42, 42, 52),         -- the room's own dark (the hub's flat light is set aside while open)
	Swap = { Out = 0.3, In = 0.34, Ring = 11 },
	Canvas = Vector2.new(1920, 1080),             -- the reference screen: every block is laid out in these px at Scale 1
	MinScale = 0.55, MinWidth = 1300,             -- (2026-10-26 fix pass) the scale's floor (phones), the reference width kept
}
local C = {
	RedInk = Color3.fromRGB(200, 30, 26), Green = Color3.fromRGB(126, 204, 36),   -- the Loadout's own (LoadoutMenu's C)
}

local CENTRE = Tuning.Centre + Vector3.new(0, Tuning.Lift, 0)
local AltarStage = require(spell:WaitForChild("AltarStage"))

local function elementDef(el)
	local d = K.element(el)
	return d or { Base = K.C.Grey, Light = K.C.White, Dark = K.C.Ink, Display = el }
end
local function owns(el)
	local set = Economy.ParseOwned(player:GetAttribute("OwnedElements"))
	return set[el] == true
end
local function currentElement()
	return player:GetAttribute("Element") or Config.DefaultLoadout.Element
end
local function equippedWrap(el)
	local ok, id = pcall(Skins.ElementWrap, player, el)
	return ok and id or "Default"
end
local function equippedSkin(el)
	local ok, id = pcall(Skins.ElementSkin, player, el)
	return ok and id or "Default"
end
local function skinsOf(el)
	return (Skins.ElementSkins and Skins.ElementSkins[el]) or { "Default" }
end
local function wrapsOf(el)
	local list = (Skins.ElementWraps and Skins.ElementWraps[el]) or { "Default" }
	return list
end
local function wrapInfo(id)
	if id == "Default" then return "DEFAULT", nil end
	local s = Skins.Skins and Skins.Skins[id]
	return string.upper(s and s.DisplayName or id), s and s.Rarity
end

----------------------------------------------------------------------------------------------------
-- painted once per client: the corona (the hub crystal's radial bloom: white, alpha (1 - r^2)^2.4)
----------------------------------------------------------------------------------------------------
local corona = nil
local function coronaImage()
	if corona then return corona end
	local n = Tuning.Corona.Res
	local ok, im = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(n, n) }) end)
	if not ok or not im then return nil end
	local buf = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local u, v = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
			local r2 = u * u + v * v
			local o = (y * n + x) * 4
			buffer.writeu8(buf, o, 255)
			buffer.writeu8(buf, o + 1, 255)
			buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, r2 < 1 and math.floor((1 - r2) ^ 2.4 * 255 + 0.5) or 0)
		end
	end
	im:WritePixelsBuffer(Vector2.zero, im.Size, buf)
	corona = im
	return im
end

----------------------------------------------------------------------------------------------------
-- the stage: the chamber's parts the showcase drives (built in Edit by ShowcaseChamberBuild), plus what it adds
----------------------------------------------------------------------------------------------------
local stageFolder, anchor, lights, stage, room = nil, nil, nil, nil, nil
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Transparency = true, false, false, false, false, 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	for k, v in pairs(props) do p[k] = v end
	p.Parent = stageFolder
	return p
end
local function buildStage()
	local chamber = workspace:FindFirstChild(Tuning.Chamber) or workspace:WaitForChild(Tuning.Chamber, 5)
	stageFolder = Instance.new("Folder")
	stageFolder.Name = "AltarShowcaseStage"
	stageFolder.Parent = workspace
	anchor = part({ Name = "Centre", CFrame = CFrame.new(CENTRE) })
	room = { Mood = {}, Pedestal = {}, Lights = {} }
	for _, d in ipairs(chamber and chamber:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			if d:GetAttribute("Mood") then room.Mood[#room.Mood + 1] = d end
			if d:GetAttribute("Pedestal") then room.Pedestal[d] = d.CFrame end
		elseif d:IsA("Light") then
			room.Lights[d.Name] = d
		end
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "AltarShowcaseMood"
	grade.Parent = Lighting
	-- the soft corona behind the piece (camera-facing; breathes on the crystal's cycle)
	local bb = Instance.new("BillboardGui")
	bb.Adornee, bb.Size, bb.LightInfluence, bb.AlwaysOnTop = anchor, UDim2.fromScale(Tuning.Corona.W, Tuning.Corona.H), 0, false
	bb.Parent = anchor
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency, img.Size, img.ImageTransparency = 1, UDim2.fromScale(1, 1), 1
	local im = coronaImage()
	if im then img.ImageContent = Content.fromObject(im) end
	img.Parent = bb
	lights = { Grade = grade, Corona = img, CoronaBB = bb }
	-- the move previews' stage (AltarMoves contract v2): the caster -> target axis runs along world X
	local floorY = Tuning.Centre.Y + 1.65
	local floorPart = chamber and chamber:FindFirstChild("StageTop")
	stage = {
		CF = CFrame.fromMatrix(Tuning.Centre + Vector3.new(0, floorY + 3.2, 0), Vector3.new(1, 0, 0), Vector3.yAxis),
		Floor = Tuning.Centre + Vector3.new(0, floorY, 0), FloorPart = floorPart, Parent = stageFolder, Wrap = "Default", Player = player,
		React = AltarStage,
	}
end
local pedTweens = {}
local function clearStage()
	for _, tw in pairs(pedTweens) do tw:Cancel() end
	table.clear(pedTweens)
	if stage and stage.Caster then AltarStage.Clear(stage) end
	if lights and lights.Grade then lights.Grade:Destroy() end
	if room then for p, cf in pairs(room.Pedestal) do p.CFrame = cf end end
	if stageFolder then stageFolder:Destroy() end
	stageFolder, anchor, lights, stage, room = nil, nil, nil, nil, nil
end
--- the pedestal sinks into the stage for a move preview (true) or rises back for the M1
local function pedestal(down)
	if not room then return end
	for p, cf in pairs(room.Pedestal) do
		if pedTweens[p] then pedTweens[p]:Cancel() end
		pedTweens[p] = TweenService:Create(p, TweenInfo.new(Tuning.SinkTime, Enum.EasingStyle.Quad, down and Enum.EasingDirection.In or Enum.EasingDirection.Out),
			{ CFrame = down and (cf - Vector3.new(0, Tuning.Sink, 0)) or cf })
		pedTweens[p]:Play()
	end
end

----------------------------------------------------------------------------------------------------
-- the mood: the room's mood parts, its lights, the corona and the grade drift to an Element's colours
----------------------------------------------------------------------------------------------------
--- (2026-10-27, the owner: "the glow should be of the wrap") the room's mood colours for what is shown: the wrap's (else
--- the skin's) own catalog colours -- its Label, else its Palette -- the most vivid as Base, the lightest as Light, the
--- darkest as Dark; the Element's own when it has neither. A dark look (Void Flame, Black Ice) is lifted so it still glows.
local lookCache = {}
local function lookDef(el, wrap, skin)
	local id = (type(wrap) == "string" and wrap ~= "Default" and wrap) or (type(skin) == "string" and skin ~= "Default" and skin) or nil
	local s = id and Skins.Skins and Skins.Skins[id]
	if type(s) ~= "table" then return elementDef(el) end
	if lookCache[id] then return lookCache[id] end
	local cols = {}
	local function add(c)
		if typeof(c) == "Color3" then cols[#cols + 1] = c
		elseif type(c) == "string" then pcall(function() cols[#cols + 1] = Color3.fromHex(c) end) end
	end
	if type(s.Label) == "table" then for _, c in ipairs(s.Label) do add(c) end end
	if #cols == 0 and type(s.Palette) == "table" then
		for _, k in ipairs({ "Highlight", "Main", "Base", "Accent", "Shadow", "Dark", "Light" }) do add(s.Palette[k]) end
	end
	if #cols == 0 then return elementDef(el) end
	local function lum(c) return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end
	local function vivid(c) local _, sat, v = c:ToHSV() return sat * v end
	local base, light, dark = cols[1], cols[1], cols[1]
	for _, c in ipairs(cols) do
		if vivid(c) > vivid(base) then base = c end
		if lum(c) > lum(light) then light = c end
		if lum(c) < lum(dark) then dark = c end
	end
	local h, sat, v = base:ToHSV()
	if v < 0.6 then base = Color3.fromHSV(h, sat, 0.6) end
	if lum(light) < 0.45 then light = base:Lerp(Color3.new(1, 1, 1), 0.35) end
	local d = { Base = base, Light = light, Dark = dark, Display = id }
	lookCache[id] = d
	return d
end
local moodKey = nil
local function moodTo(el, instant, wrap, skin)
	if not lights or not room then return end
	local key = tostring(el) .. "/" .. tostring(wrap) .. "/" .. tostring(skin)
	if key == moodKey and not instant then return end
	moodKey = key
	local d = lookDef(el, wrap, skin)
	local ti = TweenInfo.new(instant and 0 or Tuning.Mood.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, p in ipairs(room.Mood) do
		local m = p:GetAttribute("Mood")
		local c = (m == "Light" and d.Base) or (m == "Dark" and d.Dark) or d.Base:Lerp(d.Dark, 0.45)   -- (Neon blooms: one step darker than the swatch)
		TweenService:Create(p, ti, { Color = c }):Play()
	end
	local L = room.Lights
	if L.Key then TweenService:Create(L.Key, ti, { Color = K.C.White:Lerp(d.Light, 0.25) }):Play() end
	if L.RimA then TweenService:Create(L.RimA, ti, { Color = d.Base, Brightness = Tuning.Mood.Rim }):Play() end
	if L.RimB then TweenService:Create(L.RimB, ti, { Color = d.Light, Brightness = Tuning.Mood.Rim * 0.8 }):Play() end
	if L.Fill then TweenService:Create(L.Fill, ti, { Color = d.Dark:Lerp(d.Base, 0.5) }):Play() end
	if L.PedestalGlow then TweenService:Create(L.PedestalGlow, ti, { Color = d.Light:Lerp(d.Base, 0.4) }):Play() end
	TweenService:Create(lights.Grade, ti, { TintColor = K.C.White:Lerp(d.Light, Tuning.Mood.Tint), Contrast = 0.08, Saturation = 0.08 }):Play()
	TweenService:Create(lights.Corona, ti, { ImageColor3 = d.Light:Lerp(d.Base, 0.35) }):Play()
end

----------------------------------------------------------------------------------------------------
-- the swap's language: each Element breaks apart (and comes together) its own way, behind a comic POP ring
----------------------------------------------------------------------------------------------------
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local STYLE = {
	-- Speed studs/s, Acc studs/s^2, Life s, Size start/end, Streak = squash (a velocity-aligned streak), N particles
	Pyro = { N = 60, Speed = { 6, 13 }, Acc = Vector3.new(0, 11, 0), Drag = 2.4, Life = { 0.5, 1.1 }, Size = { 0.5, 0 } },        -- embers rise
	Cryo = { N = 46, Speed = { 4, 9 }, Acc = Vector3.new(0, -9, 0), Drag = 1.6, Life = { 0.6, 1.0 }, Size = { 0.45, 0 } },        -- frost glints fall
	Voltaic = { N = 44, Speed = { 18, 30 }, Acc = Vector3.zero, Drag = 5, Life = { 0.16, 0.34 }, Size = { 0.45, 0.1 }, Streak = -2.6 }, -- sparks crack out
	Terra = { N = 26, Speed = { 3, 6 }, Acc = Vector3.new(0, -30, 0), Drag = 0.6, Life = { 0.6, 0.9 }, Size = { 0.4, 0.25 }, Chips = 12 }, -- crumbs fall
	Zephyr = { N = 40, Speed = { 10, 16 }, Acc = Vector3.zero, Drag = 3, Life = { 0.35, 0.65 }, Size = { 0.55, 0.2 }, Streak = -2.2, Swirl = true }, -- gusts whip round
	Umbra = { N = 46, Speed = { 4, 9 }, Acc = Vector3.new(0, 2, 0), Drag = 2.2, Life = { 0.5, 1.0 }, Size = { 0.6, 0 } },         -- shadow motes scatter
	Radiant = { N = 50, Speed = { 5, 10 }, Acc = Vector3.zero, Drag = 3, Life = { 0.45, 0.85 }, Size = { 0.7, 0 } },             -- light motes flare out
	Toxin = { N = 40, Speed = { 2, 6 }, Acc = Vector3.new(0, 7, 0), Drag = 1.2, Life = { 0.7, 1.2 }, Size = { 0.55, 0.15 } },    -- bubbles drift up
	Aqua = { N = 48, Speed = { 6, 11 }, Acc = Vector3.new(0, -42, 0), Drag = 0.8, Life = { 0.5, 0.9 }, Size = { 0.4, 0.2 }, Streak = -1.4 }, -- drops fall
}
local function breakApart(el, inward)
	if not anchor then return end
	local S = STYLE[el] or STYLE.Radiant
	local d = elementDef(el)
	local a = Instance.new("Attachment")
	a.Parent = anchor
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Rate, e.Enabled = 0, false
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, d.Light), ColorSequenceKeypoint.new(0.5, d.Base), ColorSequenceKeypoint.new(1, d.Dark) })
	e.LightEmission, e.LightInfluence = (el == "Umbra") and 0 or 0.8, 0
	e.Speed = NumberRange.new(S.Speed[1] * (inward and 0.6 or 1), S.Speed[2] * (inward and 0.6 or 1))
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration, e.Drag = S.Acc, S.Drag
	e.Lifetime = NumberRange.new(S.Life[1], S.Life[2])
	e.Size = NumberSequence.new(S.Size[1], S.Size[2])
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.RotSpeed = NumberRange.new(-180, 180)
	if S.Streak then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(S.Streak)
	end
	if S.Swirl then e.RotSpeed = NumberRange.new(0) end
	e.Parent = a
	e:Emit(inward and math.floor(S.N * 0.6) or S.N)
	-- Terra's crumbs are real chips that tumble and bounce on the dais
	if S.Chips and not inward then
		for i = 1, S.Chips do
			local c = Instance.new("Part")
			c.Size = Vector3.new(1, 1, 1) * (0.25 + math.random() * 0.4)
			c.Color = (i % 3 == 0) and d.Light or ((i % 2 == 0) and d.Base or d.Dark)
			c.Material = Enum.Material.Slate
			c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false
			c.CFrame = CFrame.new(CENTRE + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			c.AssemblyLinearVelocity = Vector3.new(math.random() * 10 - 5, math.random() * 6, math.random() * 10 - 5)
			c.Parent = stageFolder
			task.delay(1.1, function()
				if c.Parent then
					TweenService:Create(c, TweenInfo.new(0.35), { Transparency = 1, Size = c.Size * 0.3 }):Play()
					task.delay(0.36, function() c:Destroy() end)
				end
			end)
		end
	end
	-- the corona flares as the piece breaks (and swells back as it forms): soft light, no flat overlay
	if lights and lights.CoronaBB then
		local bb = lights.CoronaBB
		local big, home = UDim2.fromScale(Tuning.Corona.W * 1.6, Tuning.Corona.H * 1.6), UDim2.fromScale(Tuning.Corona.W, Tuning.Corona.H)
		bb.Size = inward and home or big
		TweenService:Create(bb, TweenInfo.new(inward and Tuning.Swap.In or Tuning.Swap.Out * 2, Enum.EasingStyle.Sine), { Size = inward and big or home }):Play()
		if inward then task.delay(Tuning.Swap.In, function() if bb.Parent then TweenService:Create(bb, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = home }):Play() end end) end
	end
	task.delay(S.Life[2] + 0.3, function() a:Destroy() end)
end

----------------------------------------------------------------------------------------------------
-- the piece: the pedestal rig's M1 (HubShowcaseM1), or one of AltarMoves' looping move previews
----------------------------------------------------------------------------------------------------
local view = { El = nil, Wrap = "Default", Skin = "Default", Tab = "Wraps", Move = nil }
-- view.El is the PICKED Element, nil until one is clicked (2026-10-27); the piece, the mood and the moves show shownEl()
-- -- the picked Element only (2026-10-27, the owner): nil shows nothing (an empty pedestal, a neutral room)
local function shownEl() return view.El end
local makeRoom, releaseSkins
local piece = { El = nil, Wrap = nil, Move = nil, Handle = nil, Stop = nil, T0 = 0 }
local movesCache = {}
local function movesOf(el)
	if not el then return nil end
	if movesCache[el] ~= nil then return movesCache[el] or nil end
	local folder = spell:FindFirstChild("AltarMoves")
	local m = folder and folder:FindFirstChild(el)
	local ok, mod = false, nil
	if m then ok, mod = pcall(require, m) end
	movesCache[el] = (ok and type(mod) == "table" and type(mod.Moves) == "table") and mod or false
	return movesCache[el] or nil
end
local function clearPiece()
	if piece.Handle then pcall(piece.Handle.Destroy) end
	if piece.Stop then pcall(piece.Stop) end
	if stage and stage.Caster then
		AltarStage.Clear(stage)
		stage.Caster, stage.Target, stage.Key = nil, nil, nil
	end
	if piece.El == "Cryo" and piece.Handle then
		pcall(function() require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("CryoWrap")).MakeRoom() end)
	end
	piece.Handle, piece.Stop = nil, nil
end
local function drawPiece(el, wrap, move)
	if piece.Handle or piece.Stop then clearPiece() end
	piece.El, piece.Wrap, piece.Move, piece.T0 = el, wrap, move, os.clock()
	if not el then return end                    -- (2026-10-27) nothing picked: the pedestal stands empty
	if stage then stage.Wrap, stage.Skin = wrap, view.Skin end
	local mod = movesOf(el)
	if move and mod and mod.Moves[move] then
		-- two mannequins step onto the stage; the caster performs the move on the target
		stage.Caster, stage.Target = AltarStage.Pair(stage)
		stage.Key = stage.Caster
		local ok, stop = pcall(mod.Moves[move].Play, stage)
		piece.Stop = ok and stop or nil
		return
	end
	local draw = M1[el]
	if draw then
		local cf = CFrame.lookAt(CENTRE, CENTRE + stage.CF.RightVector)
		local ok, h = pcall(draw, wrap, cf, stageFolder, view.Skin ~= "Default" and view.Skin or nil)
		if ok and h then
			piece.Handle = h
			return
		end
	end
	-- no pedestal draw for this Element: its own M1 preview, looping
	if mod and mod.Moves[1] then
		local ok, stop = pcall(mod.Moves[1].Play, stage)
		piece.Stop = ok and stop or nil
	end
end

--- an Element's optional wrap mesh copies, let go (Cryo / Terra keep theirs until asked; Pyro's PyroDraw is an LRU)
function makeRoom(el)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local name = ({ Cryo = "CryoWrap", Terra = "TerraWrap" })[el]
	local m = name and ice and ice:FindFirstChild(name, true)
	if m then pcall(function() require(m).MakeRoom() end) end
end

--- the skin kits (the EditableMesh-heavy ones, Cryo's and Toxin's): every one not shown lets go now (a kit a player wears, or that is
--- building, keeps its meshes), the shared optional copies make room, and the shown skin's kit starts (or retries) its build
local SKIN_KITS = { FrostbladeKit = "Cryo", FrostLotusKit = "Cryo", SnowGlobeKit = "Cryo", FrostDragonKit = "Cryo",
	HydraKit = "Toxin", ScorpionKit = "Toxin", WitchsBrewKit = "Toxin", PixelPotionKit = "Toxin" }
function releaseSkins()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	if not ice then return end
	local want
	for name, kitEl in pairs(SKIN_KITS) do
		local m = ice:FindFirstChild(name)
		local ok, kit = pcall(require, m)
		if ok and type(kit) == "table" then
			if kit.Id == view.Skin and shownEl() == kitEl then want = kit
			elseif kit.ReleaseNow then pcall(kit.ReleaseNow) end
		end
	end
	local mb = ice:FindFirstChild("MeshBudget")
	if mb then pcall(function() require(mb).MakeRoom() end) end
	if want and not want.Built then pcall(want.Build or want.Prepare) end   -- (Toxin's kits rebuild through Prepare)
	return want == nil or want.Built == true
end

local swapToken = 0
--- break the piece apart in its Element's language, drift the mood, reform as the new piece in ITS language
local function swapTo(el, wrap, move)
	swapToken += 1
	local my = swapToken
	local old = piece.El
	task.spawn(function()
		if old then breakApart(old, false) end
		task.wait(Tuning.Swap.Out)
		if my ~= swapToken or not stage then return end
		clearPiece()
		if old and old ~= el then makeRoom(old) end
		releaseSkins()
		pedestal(move ~= nil)
		moodTo(el, false, wrap, view.Skin)         -- (nil: the neutral room, elementDef's fallback; the wrap's colours, 2026-10-27)
		if el then breakApart(el, true) end
		drawPiece(el, wrap, move)                  -- (PERF TEST 2026-10-27: drawn at the inward burst, not after it)
	end)
end

----------------------------------------------------------------------------------------------------
-- the UI (HubLifeKit: the hub's slabs, LuckiestGuy display, GothamBlack, RobotoMono labels, the rarity ladder)
----------------------------------------------------------------------------------------------------
local gui = K.make("ScreenGui", { Name = "AltarShowcase", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 42, Enabled = false }, playerGui)
local command = K.make("BindableEvent", { Name = "Command" }, gui)
-- (2026-10-26 fix pass: scale) ONE UIScale governs the whole screen, and the canvas COVERS the screen in reference px
-- (1080 tall at Scale 1): each block keeps its own reference-px layout but hangs from a screen edge. It was a fixed
-- 1920 x 1080 box letterboxed into the middle, which drew everything at ~0.36 on a phone in landscape (0.44 in Studio's
-- wide test window) and left the screen's sides empty. fit(), under the blocks, picks the scale.
local canvas = K.make("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(Tuning.Canvas.X, Tuning.Canvas.Y) }, gui)
local canvasScale = K.make("UIScale", {}, canvas)
-- the canvas under Roblox's top bar (its buttons sit top left): the panel, the X and Preview Moves hang from its top
local safe = K.make("Frame", { Name = "Safe", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, canvas)
local function text(parent, props)
	local l = K.make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = K.C.Ink, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, v in pairs(props) do l[k] = v end
	return l
end
local function hit(parent, z)
	return K.make("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z or 20 }, parent)
end
--- (2026-10-26 fix pass) the padlock, drawn big enough to read as a lock and nothing else: a cream shackle arch over a
--- cream body with an ink keyhole, 22 x 26 (it was a 10 px ring over a 14 px block, which read as a settings glyph)
local function padlock(parent, z, order)
	local g = K.make("Frame", { Name = "Padlock", BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 26), ZIndex = z, LayoutOrder = order or 0 }, parent)
	local shackle = K.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(12, 18), ZIndex = z }, g)
	K.corner(shackle, 6)
	K.make("UIStroke", { Color = K.C.CreamText, Thickness = 3 }, shackle)
	local body = K.make("Frame", { BackgroundColor3 = K.C.CreamText, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 11), Size = UDim2.fromOffset(22, 15), ZIndex = z + 1 }, g)
	K.corner(body, 3)
	local hole = K.make("Frame", { BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 3), Size = UDim2.fromOffset(6, 6), ZIndex = z + 2 }, body)
	K.corner(hole, 3)
	K.make("Frame", { BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(2, 5), ZIndex = z + 2 }, body)
	return g
end
--- the padlock alone on an ink plate (a locked row with no price: NO SKINS YET)
local function lockBadge(parent, x, y, z)
	local plate = K.make("Frame", { Name = "Lock", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(36, 36), ZIndex = z }, parent)
	K.corner(plate, 6)
	padlock(plate, z + 1).Position = UDim2.fromOffset(7, 5)
	return plate
end
--- the Sparks mark (the shop chip's cut: a magenta four-arm sparkle, each arm fading to its tip; no Rotation, so it is
--- safe in the scrolling lists)
local SPARKS = Color3.fromHex("E91E8C")
local TO_TIPS = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
local function sparksMark(parent, s, z, order)
	local b = K.make("Frame", { Name = "SparksIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(s, s), ZIndex = z, LayoutOrder = order or 0 }, parent)
	b:SetAttribute("Currency", "Sparks")
	local th = math.max(3, math.floor(s * 0.24 + 0.5))
	for _, tall in ipairs({ true, false }) do
		local arm = K.make("Frame", { BackgroundColor3 = SPARKS, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = tall and UDim2.fromOffset(th, s) or UDim2.fromOffset(math.floor(s * 0.7 + 0.5), th), ZIndex = z }, b)
		K.make("UIGradient", { Transparency = TO_TIPS, Rotation = tall and 90 or 0 }, arm)
	end
	local core = math.max(4, math.floor(s * 0.34 + 0.5))
	K.corner(K.make("Frame", { BackgroundColor3 = SPARKS, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(core, core), ZIndex = z }, b), core // 2)
	return b
end
-- (2026-10-26 fix pass) what a locked row costs. An Element's is the game's own price (EconomyConfig, Sparks). Wraps and
-- skins have no price anywhere yet (SkinCatalog.OwnsSkin lets everyone wear everything), so theirs is the Design
-- Manual's Section 8 tier range in Robux, flagged TBD on the pill: a placeholder, not a final number.
local TIER_RANGE = {
	Wrap = { Uncommon = "100\u{2013}150", Rare = "200\u{2013}300", Epic = "350\u{2013}500", Mythic = "600\u{2013}900" },
	Skin = { Uncommon = "350\u{2013}500", Rare = "600\u{2013}800", Epic = "900\u{2013}1,200", Mythic = "1,500\u{2013}2,200" },
}
local function commas(n)
	local s = tostring(math.floor(n))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then return s end
	end
end
local function elementPrice(el)
	local ok, p = pcall(Economy.PriceOf, el)
	if ok and type(p) == "number" then return { Currency = "Sparks", Amount = commas(p) } end
	return { Currency = "Sparks", Amount = "?", TBD = true }
end
local function lookPrice(kind, rarity)
	local r = rarity and TIER_RANGE[kind] and TIER_RANGE[kind][rarity]
	return r and { Currency = "Robux", Amount = r, TBD = true } or nil
end
local ROBUX = "rbxasset://textures/ui/common/robux@3x.png"   -- (the shop's CardKit mark)
--- a locked row's tag: an ink pill holding the padlock (if locked) and the price (the mark, the amount, a gold TBD on a
--- placeholder). Placed by its right edge at `pos`; returns the pill and its width in reference px.
local function pricePill(parent, price, locked, pos, h, z)
	local pill = K.make("Frame", { Name = "Price", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = pos,
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z }, parent)
	K.corner(pill, 6)
	K.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9) }, pill)
	K.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }, pill)
	local w = 17
	if locked then
		padlock(pill, z + 1, 1)
		w += 22
	end
	if price then
		local ms, ts = math.floor(h * 0.55), math.floor(h * 0.52)
		if price.Currency == "Robux" then
			K.make("ImageLabel", { Name = "RobuxIcon", BackgroundTransparency = 1, Image = ROBUX, ImageColor3 = K.C.CreamText, Size = UDim2.fromOffset(ms, ms),
				ZIndex = z + 1, LayoutOrder = 2 }, pill)
		else
			sparksMark(pill, ms, z + 1, 2)
		end
		text(pill, { Name = "Amount", Text = price.Amount, TextColor3 = K.C.CreamText, TextSize = ts, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, h), ZIndex = z + 1, LayoutOrder = 3 })
		w += (locked and 5 or 0) + ms + 5 + TextService:GetTextSize(price.Amount, ts, Enum.Font.GothamBlack, Vector2.new(1e4, 1e4)).X
		if price.TBD then
			local fs = math.floor(h * 0.42)
			text(pill, { Name = "TBD", FontFace = K.MONO, Text = "TBD", TextColor3 = K.C.Gold, TextSize = fs, AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, h), ZIndex = z + 1, LayoutOrder = 4 })
			w += 5 + TextService:GetTextSize("TBD", fs, Enum.Font.RobotoMono, Vector2.new(1e4, 1e4)).X
			pill:SetAttribute("Placeholder", true)
		end
	end
	return pill, w
end

-- the panel, left, under the top bar: one framed ink slab (halftone, a gold keyline). (2026-10-26 fix pass) its title bar
-- is the old floating nameplate (the Element, the wrap / skin, the rarity), docked flush in the panel's top; under it the
-- Element rail and the WRAPS | SKINS list, headed the same way (headerTab), each scrolling when the screen is too short
local panelHolder, panelFace = K.slab(safe, UDim2.new(0, 770, 1, -24), UDim2.fromOffset(24, 0), K.C.Ink, 1, 10, 4, 10)
K.halftone(panelFace, 0.9, Color3.fromRGB(60, 66, 96), 8, 2)
local keyline = K.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 1, -14), ZIndex = 3 }, panelFace)
K.corner(keyline, 7)
K.make("UIStroke", { Color = K.C.Gold, Thickness = 2, Transparency = 0.25 }, keyline)
local plate = K.make("Frame", { Name = "TitleBar", BackgroundColor3 = K.C.Card, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 16),
	Size = UDim2.new(1, -32, 0, 96), ZIndex = 4 }, panelFace)
K.corner(plate, 6)
K.outline(plate, 3)
K.halftone(plate, 0.9, K.C.Ink, 10, 5)
local title = K.display(plate, { Text = "", TextSize = 46, Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -36, 0, 54), ZIndex = 8 }, 4, K.C.Ink, K.C.Card:Lerp(K.C.Ink, 0.28))
local titleBack = nil
for _, c in ipairs(plate:GetChildren()) do if c:IsA("TextLabel") and c ~= title and c.Font == Enum.Font.LuckiestGuy then titleBack = c end end
local tagRow = K.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 28), ZIndex = 8 }, plate)
K.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center }, tagRow)
local tag = text(tagRow, { FontFace = K.MONO, TextSize = 20, TextColor3 = K.C.LockedInk, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), ZIndex = 9, LayoutOrder = 1 })
local tagChip = nil
local function scrollList(parent)
	return K.make("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
		CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = K.C.Gold,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ZIndex = 5 }, parent)
end
local rail = K.make("Frame", { Name = "Rail", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 134), Size = UDim2.new(0, 350, 1, -160), ZIndex = 5 }, panelHolder)
local railList = scrollList(rail)
local railRows = {}
local wrapsPanel = K.make("Frame", { Name = "Wraps", BackgroundTransparency = 1, Position = UDim2.fromOffset(372, 134), Size = UDim2.new(0, 372, 1, -160), ZIndex = 5 }, panelHolder)
local tabs = {}
local wrapTiles = scrollList(wrapsPanel)
-- (2026-10-27, the owner) nothing picked: the panel narrows to the rail alone and the WRAPS | SKINS column hides; the
-- first pick widens the panel again, and since the holder clips, the column is revealed as the panel opens out
panelHolder.ClipsDescendants = true
local PANEL_W = { Rail = 394, Full = 770 }   -- the rail alone (18 + 350 + a margin + the shadow), and the whole panel
local picked = nil
local function setPicked(on, instant)
	if picked == on then return end
	picked = on
	local size = UDim2.new(0, on and PANEL_W.Full or PANEL_W.Rail, 1, -24)
	if instant then
		panelHolder.Size = size
		wrapsPanel.Visible = on
		return
	end
	-- opening shows the column at once (the widening reveals it); closing keeps it until the panel has narrowed over it
	if on then wrapsPanel.Visible = true end
	local tw = TweenService:Create(panelHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = size })
	tw.Completed:Connect(function() if picked == false then wrapsPanel.Visible = false end end)
	tw:Play()
end
-- Preview Moves, right, under the X. (2026-10-26 fix pass) the same gold slab, size and type as TECHNIQUES: two peer
-- actions, one weight (it was an ink slab, which read as a dim ghost button beside the gold one). The dropdown runs
-- down to TECHNIQUES and scrolls past that.
local right = K.make("Frame", { Name = "Moves", BackgroundTransparency = 1, Position = UDim2.new(1, -364, 0, 96), Size = UDim2.new(0, 340, 1, -96) }, safe)
local movesBtnHolder, movesBtn = K.slab(right, UDim2.fromOffset(340, 70), UDim2.fromOffset(0, 0), K.C.Gold, 6, 6, 3, 4)
local movesWord = text(movesBtn, { Font = Enum.Font.Bangers, Text = "PREVIEW MOVES  \u{25BE}", TextColor3 = K.C.Ink, TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
local movesHit = hit(movesBtnHolder)
local dropdown = K.make("Frame", { Name = "Dropdown", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(0, 340, 1, -190),
	Visible = false, ClipsDescendants = true }, right)
local dropList = K.make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = K.C.Gold }, dropdown)
-- the corner buttons and the hint: the X top right under the top bar, TECHNIQUES bottom right, the hint centred in the
-- gap between the panel and the right column
local closeHolder, closeFace = K.slab(safe, UDim2.fromOffset(70, 70), UDim2.new(1, -94, 0, 0), K.C.Ink, 6, 6, 3, 4)
text(closeFace, { Font = Enum.Font.LuckiestGuy, Text = "X", TextColor3 = K.C.CreamText, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
local closeHit = hit(closeHolder)
local loadoutHolder, loadoutFace = K.slab(canvas, UDim2.fromOffset(340, 70), UDim2.new(1, -364, 1, -94), K.C.Gold, 6, 6, 3, 4)
text(loadoutFace, { Font = Enum.Font.Bangers, Text = "TECHNIQUES", TextColor3 = K.C.Ink, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
local loadoutHit = hit(loadoutHolder)
local hintHolder, hintFace = K.slab(canvas, UDim2.fromOffset(250, 44), UDim2.new(0.5, 90, 1, -68), K.C.Ink, 6, 4, 2, 4)
text(hintFace, { FontFace = K.MONO, Text = "DRAG TO ORBIT", TextColor3 = K.C.CreamText, TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
local slideIn = {   -- each block's home position and where it waits off-screen (the Scale part carries the screen edge)
	{ panelHolder, UDim2.fromOffset(24, 0), UDim2.fromOffset(-820, 0) },
	{ right, UDim2.new(1, -364, 0, 96), UDim2.new(1, 40, 0, 96) },
	{ closeHolder, UDim2.new(1, -94, 0, 0), UDim2.new(1, -94, 0, -260) },
	{ loadoutHolder, UDim2.new(1, -364, 1, -94), UDim2.new(1, -364, 1, 60) },
	{ hintHolder, UDim2.new(0.5, 90, 1, -68), UDim2.new(0.5, 90, 1, 60) },
}
local function slideUI(show, delay)
	for i, s in ipairs(slideIn) do
		local ti = show and TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (delay or 0) + i * 0.04)
			or TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(s[1], ti, { Position = show and s[2] or s[3] }):Play()
	end
end
for _, s in ipairs(slideIn) do s[1].Position = s[3] end

-- the scale: the screen's height over the 1080 reference, never under MinScale (a phone in landscape stays legible and
-- its rows tappable) and never so big the panel and the right column stop fitting side by side (MinWidth). A Vector2
-- lays out for a screen of that size (the Studio check's "fit"); false goes back to the real screen.
local fitSize = nil
local function fit(size)
	if typeof(size) == "Vector2" then fitSize = size elseif size == false then fitSize = nil end
	local v = fitSize or gui.AbsoluteSize
	if v.X < 2 or v.Y < 2 then v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Tuning.Canvas end
	if v.X < 2 or v.Y < 2 then v = Tuning.Canvas end   -- (the camera's ViewportSize can read 1 x 1 in Studio)
	local s = math.min(math.max(v.Y / Tuning.Canvas.Y, Tuning.MinScale), v.X / Tuning.MinWidth)
	canvasScale.Scale = s
	canvas.Size = UDim2.fromOffset(v.X / s, v.Y / s)
	-- clear Roblox's top bar (its buttons sit over the panel's corner otherwise)
	local top = math.max(24, (GuiService.TopbarInset.Max.Y + 12) / s)
	safe.Position = UDim2.fromOffset(0, top)
	safe.Size = UDim2.new(1, 0, 1, -top)
	-- the hint only where the gap between the panel (794) and the right column (364 from the edge) can hold it
	hintHolder.Visible = v.X / s - 364 - 794 >= 270
end
fit()

----------------------------------------------------------------------------------------------------
-- state + painting the UI from it
----------------------------------------------------------------------------------------------------
local refreshWraps, refreshRail, refreshPlate, refreshMoves

function refreshPlate()
	local el = shownEl()
	local mod = movesOf(el)
	local mv = view.Move and mod and mod.Moves[view.Move]
	if not view.El and not mv then
		-- nothing picked yet (2026-10-27): the title bar asks for a pick rather than naming one
		title.Text = "LOADOUT"
		if titleBack then titleBack.Text = title.Text end
		tag.Text = "PICK AN ELEMENT"
		if tagChip then tagChip:Destroy() tagChip = nil end
		return
	end
	local d = elementDef(el)
	title.Text = string.upper(d.Display or el)
	if titleBack then titleBack.Text = title.Text end
	local name, rarity = wrapInfo(view.Wrap)
	if view.Skin ~= "Default" then name, rarity = wrapInfo(view.Skin) end
	tag.Text = mv and ("PREVIEW  ·  " .. string.upper(mv.Name)) or (name .. "  ·  " .. ((view.Skin ~= "Default" and (view.Wrap ~= "Default" and ("SKIN + " .. string.upper((wrapInfo(view.Wrap)))) or "SKIN")) or (view.Wrap == "Default" and "STANDARD") or "WRAP"))
	if tagChip then tagChip:Destroy() tagChip = nil end
	if rarity and not mv then
		tagChip = K.rarityChip(tagRow, rarity, 0, 0, 28, 16, 9)
		tagChip.LayoutOrder = 2
	end
end

-- the round icon well every row carries: a fill, a heavy ink ring, the logo / art, or a LuckiestGuy initial
local function iconWell(parent, size, x, y, fill, image, initial, z)
	local well = K.make("Frame", { Name = "Icon", BackgroundColor3 = fill, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size), ZIndex = z }, parent)
	K.make("UICorner", { CornerRadius = UDim.new(1, 0) }, well)
	K.outline(well, 3)
	if image then
		K.make("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.74, 0.74), ZIndex = z + 1 }, well)
	elseif initial then
		text(well, { Font = Enum.Font.LuckiestGuy, Text = initial, TextColor3 = K.wordOn(fill), TextSize = math.floor(size * 0.5),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 2), ZIndex = z + 1 })
	end
	return well
end
--- a wrap's swatch: its own colours as hard comic bands across the well (Label, else the palette's main colours)
local function swatchOf(id, el)
	local cols = {}
	local s = Skins.Skins and Skins.Skins[id]
	local function add(c)
		if typeof(c) == "Color3" then cols[#cols + 1] = c
		elseif type(c) == "string" then pcall(function() cols[#cols + 1] = Color3.fromHex(c) end) end
	end
	if s and type(s.Label) == "table" then for _, c in ipairs(s.Label) do add(c) end end
	if #cols == 0 and s and type(s.Palette) == "table" then
		for _, k in ipairs({ "Highlight", "Main", "Base", "Shadow", "Dark", "Light" }) do add(s.Palette[k]) end
	end
	if #cols == 0 then
		local d = elementDef(el)
		cols = { d.Light, d.Base, d.Dark }
	end
	local n = math.min(#cols, 3)
	local keys = {}
	for i = 1, n do
		keys[#keys + 1] = ColorSequenceKeypoint.new((i - 1) / n, cols[i])
		keys[#keys + 1] = ColorSequenceKeypoint.new(math.min(1, i / n - 0.001), cols[i])
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, cols[n])
	return ColorSequence.new(keys)
end
local Icons = nil
pcall(function() Icons = require(spell:WaitForChild("IconAssets", 5)) end)
--- a skin's own art: its HUD set's Ultimate icon (else Primary), nil if it has none (the well falls back to the Element's logo)
local function skinArt(id)
	local t = Icons and Icons.Ability and Icons.Ability.Skins and Icons.Ability.Skins[id]
	if type(t) ~= "table" then return nil end
	for _, k in ipairs({ "Ultimate", "Primary", "Technique" }) do
		for _, v in pairs(type(t[k]) == "table" and t[k] or {}) do
			if type(v) == "string" and v ~= "" then return v end
		end
	end
	return nil
end

--- a row's presence: selected rows swell, glow in their colour and sit forward; hovered rows lift
local function rowState(row, selected, glowColour)
	row.Selected = selected
	TweenService:Create(row.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = selected and 1.06 or 1 }):Play()
	row.Glow.Color = glowColour
	TweenService:Create(row.Glow, TweenInfo.new(0.18), { Transparency = selected and 0 or 1 }):Play()
	TweenService:Create(row.Holder, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(row.X + (selected and 14 or 0), row.Y) }):Play()
end
local ROW_X = 8   -- (2026-10-26 fix pass) rows sit in from their scrolling list's edge, so a swollen row isn't clipped
local RAIL_W, TILE_W = 304, 326   -- the rail's rows, the WRAPS | SKINS rows (a selected row swells 6% and steps right 14)
local function makeRow(parent, w, h, y, fill, z)
	local holder, face = K.slab(parent, UDim2.fromOffset(w, h), UDim2.fromOffset(ROW_X, y), fill, z, 6, 3, 8)
	local scale = K.make("UIScale", {}, holder)
	local glow = K.make("UIStroke", { Thickness = 5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, face)
	K.halftone(face, 0.9, K.C.Ink, 7, z + 1)
	local row = { Holder = holder, Face = face, Scale = scale, Glow = glow, X = ROW_X, Y = y, Selected = false }
	local h2 = hit(holder)
	h2.MouseEnter:Connect(function() if not row.Selected then TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.03 }):Play() end end)
	h2.MouseLeave:Connect(function() if not row.Selected then TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end end)
	row.Hit = h2
	return row
end
local function equippedTag(parent, z)
	local eq = K.make("Frame", { Name = "Equipped", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = z, Visible = false }, parent)
	K.corner(eq, 4)
	K.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, eq)
	text(eq, { Text = "EQUIPPED", TextColor3 = C.Green, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), ZIndex = z + 1 })
	return eq
end

function refreshRail()
	for el, row in pairs(railRows) do
		local d = elementDef(el)
		local locked = not owns(el)
		local sel = el == view.El
		row.Face.BackgroundColor3 = locked and K.C.Track or (sel and d.Base or K.C.Card)
		row.Word.TextColor3 = locked and K.C.Grey or (sel and K.wordOn(d.Base) or K.C.Ink)
		row.Lock.Visible = locked
		-- the name gives way to what sits on the row's right: the price (locked) or EQUIPPED
		local avail = RAIL_W - 78 - (locked and row.LockW or 0)
		row.Word.Size = UDim2.new(0, avail, 1, -4)
		local size = 25
		while size > 16 and TextService:GetTextSize(row.Word.Text, size, Enum.Font.LuckiestGuy, Vector2.new(1e4, 100)).X > avail do size -= 1 end
		row.Word.TextSize = size
		local art = row.Icon:FindFirstChild("Art")
		if art then art.ImageTransparency = locked and 0.45 or 0 end
		rowState(row, sel, d.Light)
	end
end

local function buildRail()
	-- the game's own Element list (SpellshotConfig.ElementOrder): a new Element appears here with no change to this file
	for i, el in ipairs(Config.ElementOrder) do
		local d = elementDef(el)
		local row = makeRow(railList, RAIL_W, 64, 8 + (i - 1) * 72, K.C.Card, 4)
		-- (2026-10-27) 44 inside the row's 58-tall face, ring included, so the well clears the row's border top and bottom
		row.Icon = iconWell(row.Face, 44, 8, 7, d.Base, K.logoFor(el), string.sub(d.Display or el, 1, 1), 8)
		row.Word = text(row.Face, { Font = Enum.Font.LuckiestGuy, Text = string.upper(d.Display or el), TextSize = 25, Position = UDim2.fromOffset(68, 4),
			Size = UDim2.new(1, -150, 1, -4), ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
		-- (2026-10-26 fix pass) a locked Element shows the padlock AND its price, the game's own (EconomyConfig, Sparks)
		row.Lock, row.LockW = pricePill(row.Face, elementPrice(el), true, UDim2.new(1, -10, 0.5, 0), 34, 10)
		row.Hit.MouseButton1Click:Connect(function() command:Fire("element", el) end)
		railRows[el] = row
	end
	railList.CanvasSize = UDim2.fromOffset(0, 8 + #Config.ElementOrder * 72 + 4)
end

--- (2026-10-26 fix pass) the one header both of the panel's lists use: a Bangers tab on a slab. The live tab is red ink
--- and lifted; an idle tab is Card with Ink type (it was LockedInk, the kit's locked colour, and read as unavailable).
--- The rail has one tab, ELEMENTS, always live (it was a flat red banner beside the WRAPS | SKINS switcher).
local function headerTab(parent, word, x, w)
	local holder, face = K.slab(parent, UDim2.fromOffset(w, 48), UDim2.fromOffset(x, 0), K.C.Card, 6, 5, 3, 4)
	local label = text(face, { Font = Enum.Font.Bangers, Text = word, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 9 })
	return { Holder = holder, Face = face, Label = label, X = x }
end
local function tabLook(t, on)
	t.Face.BackgroundColor3 = on and C.RedInk or K.C.Card
	t.Label.TextColor3 = on and K.C.CreamText or K.C.Ink
	TweenService:Create(t.Holder, TweenInfo.new(0.15), { Position = UDim2.fromOffset(t.X, on and -4 or 0) }):Play()
end
tabLook(headerTab(rail, "ELEMENTS", 0, 170), true)
local function tabButton(word, x)
	local t = headerTab(wrapsPanel, word, x, 150)
	hit(t.Holder).MouseButton1Click:Connect(function() command:Fire("tab", word == "WRAPS" and "Wraps" or "Skins") end)
	return t
end
tabs.Wraps = tabButton("WRAPS", 0)
tabs.Skins = tabButton("SKINS", 162)

local tileConns = {}
function refreshWraps()
	for _, c in ipairs(tileConns) do c:Disconnect() end
	table.clear(tileConns)
	wrapTiles:ClearAllChildren()
	for name, t in pairs(tabs) do tabLook(t, name == view.Tab) end
	local el = view.El
	if not el then   -- (2026-10-27) nothing picked: the column is hidden, so it holds nothing
		wrapTiles.CanvasSize = UDim2.new()
		return
	end
	local d = elementDef(el)
	local locked = not owns(el)
	local skins = view.Tab == "Skins"
	local list = skins and skinsOf(el) or wrapsOf(el)
	local worn = skins and equippedSkin(el) or equippedWrap(el)
	local shown = skins and view.Skin or view.Wrap
	-- an Element with no skins yet: one row in the Loadout's own unbuilt / locked style (Track face, Grey word, padlock)
	if skins and #list <= 1 then
		local row = makeRow(wrapTiles, TILE_W, 76, 8, K.C.Track, 4)
		iconWell(row.Face, 56, 8, 7, K.C.Track:Lerp(K.C.Ink, 0.2), K.logoFor(el), string.sub(d.Display or el, 1, 1), 8)
		text(row.Face, { Font = Enum.Font.LuckiestGuy, Text = "NO SKINS YET", TextColor3 = K.C.Grey, TextSize = 22, Position = UDim2.fromOffset(74, 8), Size = UDim2.fromOffset(200, 30), ZIndex = 8 })
		text(row.Face, { FontFace = K.MONO, Text = "COMING SOON", TextColor3 = K.C.LockedInk, TextSize = 15, Position = UDim2.fromOffset(74, 42), Size = UDim2.fromOffset(200, 20), ZIndex = 8 })
		lockBadge(row.Face, TILE_W - 10 - 36, 20, 10)
		wrapTiles.CanvasSize = UDim2.fromOffset(0, 96)
		return
	end
	for i, id in ipairs(list) do
		local name, rarity = wrapInfo(id)
		local R = rarity and K.Rarity[rarity]
		local spine = R and R.Color or d.Base
		local row = makeRow(wrapTiles, TILE_W, 76, 8 + (i - 1) * 84, locked and K.C.Track or K.C.Card, 4)
		-- the rarity spine: a thick band of the rarity colour down the left, under the icon
		local band = K.make("Frame", { BackgroundColor3 = locked and K.C.Grey or spine, BorderSizePixel = 0, Size = UDim2.new(0, 36, 1, 0), ZIndex = 6 }, row.Face)
		K.corner(band, 8)
		local icon
		if skins then
			icon = iconWell(row.Face, 56, 8, 7, id == "Default" and d.Base or K.C.Ink, (id ~= "Default" and skinArt(id)) or K.logoFor(el), string.sub(name, 1, 1), 8)
		else
			icon = iconWell(row.Face, 56, 8, 7, K.C.White, nil, nil, 8)
			K.make("UIGradient", { Color = swatchOf(id, el), Rotation = 35 }, icon)
		end
		text(row.Face, { Text = name, TextColor3 = locked and K.C.Grey or K.C.Ink, TextSize = 20, Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -86, 0, 28),
			ZIndex = 8, TextTruncate = Enum.TextTruncate.AtEnd })
		if rarity then
			K.rarityChip(row.Face, rarity, 74, 42, 22, 14, 8)
		else
			text(row.Face, { FontFace = K.MONO, Text = skins and (id == "Default" and "BASE KIT" or "SKIN") or "STANDARD", TextColor3 = K.C.LockedInk, TextSize = 16, Position = UDim2.fromOffset(74, 42), Size = UDim2.fromOffset(150, 22), ZIndex = 8 })
		end
		local eq = equippedTag(row.Face, 9)
		eq.Position = UDim2.new(1, -10, 0, 53)
		eq.Visible = id == worn   -- (each Element wears its own wrap and skin, whichever Element you play)
		-- (2026-10-26 fix pass) the price, in EQUIPPED's slot: a locked Element's looks carry the padlock, and a priced look
		-- not being worn shows its price (a TBD placeholder until looks are sold)
		local price = id ~= "Default" and lookPrice(skins and "Skin" or "Wrap", rarity) or nil
		if locked or (price and not eq.Visible) then pricePill(row.Face, price, locked, UDim2.new(1, -10, 0, 53), 30, 10) end
		rowState(row, id == shown, R and R.Color:Lerp(K.C.White, 0.3) or d.Light)
		tileConns[#tileConns + 1] = row.Hit.MouseButton1Click:Connect(function() command:Fire(skins and "skin" or "wrap", id) end)
	end
	wrapTiles.CanvasSize = UDim2.fromOffset(0, 8 + #list * 84 + 4)
end

local moveConns = {}
function refreshMoves()
	for _, c in ipairs(moveConns) do c:Disconnect() end
	table.clear(moveConns)
	dropList:ClearAllChildren()
	local mod = view.El and movesOf(view.El) or nil      -- (2026-10-27) nothing picked: an empty list
	local list = mod and mod.Moves or {}
	for i, mv in ipairs(list) do
		local sel = view.Move == i
		local holder, face = K.slab(dropList, UDim2.fromOffset(340, 60), UDim2.fromOffset(0, (i - 1) * 66), sel and K.C.Pill or K.C.Card, 4, 5, 3, 4)
		local stroke = face:FindFirstChildOfClass("UIStroke")
		if sel and stroke then stroke.Color, stroke.Thickness = C.RedInk, 4 end
		text(face, { Text = string.upper(mv.Name or "?"), TextSize = 21, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 28), ZIndex = 8,
			TextTruncate = Enum.TextTruncate.AtEnd })
		text(face, { FontFace = K.MONO, Text = string.upper(mv.Slot or ""), TextColor3 = K.C.LockedInk, TextSize = 15, Position = UDim2.fromOffset(14, 32),
			Size = UDim2.new(1, -28, 0, 20), ZIndex = 8 })
		local h = hit(holder)
		moveConns[#moveConns + 1] = h.MouseButton1Click:Connect(function() command:Fire("move", i) end)
	end
	if #list == 0 then
		text(dropList, { FontFace = K.MONO, Text = view.El and "NO PREVIEWS YET" or "PICK AN ELEMENT", TextColor3 = K.C.CreamText, TextSize = 18, Size = UDim2.fromOffset(340, 30) })
	end
	dropList.CanvasSize = UDim2.fromOffset(0, #list * 66)
end

local function setDropdown(open)
	dropdown.Visible = open
	movesWord.Text = open and "PREVIEW MOVES  \u{25B4}" or "PREVIEW MOVES  \u{25BE}"
	if open then
		refreshMoves()
		dropList.Position = UDim2.fromOffset(0, -40)
		TweenService:Create(dropList, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
	end
end

----------------------------------------------------------------------------------------------------
-- the camera: push in, orbit with weight, sway when idle, push back out
----------------------------------------------------------------------------------------------------
local cam = { D = Tuning.Dist, H = Tuning.Height, Yaw = 0, Pitch = 8, VYaw = 0, VPitch = 0, Drag = false, LastInput = 0, Mode = "off", T0 = 0, From = nil, FromFOV = 70 }
local function orbitCF(yaw, pitch)
	local base = math.atan2(Tuning.Face.X, Tuning.Face.Z)
	local rot = CFrame.Angles(0, base + math.rad(yaw), 0) * CFrame.Angles(math.rad(-pitch), 0, 0)
	local look = CENTRE + Vector3.new(0, cam.H - Tuning.Height, 0)
	local pos = look + rot:VectorToWorldSpace(Vector3.new(0, 0, cam.D))
	return CFrame.lookAt(pos, look) * CFrame.new(Tuning.Aside, 0, 0)
end
local function ease(t) return t < 0.5 and 16 * t ^ 5 or 1 - (-2 * t + 2) ^ 5 / 2 end   -- quint in-out

local savedLTM = setmetatable({}, { __mode = "k" })
local function hidePart(d, on)
	if on then
		if savedLTM[d] == nil then savedLTM[d] = d.LocalTransparencyModifier end
		d.LocalTransparencyModifier = 1
	elseif savedLTM[d] ~= nil then
		d.LocalTransparencyModifier = savedLTM[d]
		savedLTM[d] = nil
	end
end
local function viewmodelHide(on)
	local c = workspace.CurrentCamera
	for _, d in ipairs(c and c:GetDescendants() or {}) do
		if d:IsA("BasePart") then hidePart(d, on) end
	end
	for _, m in ipairs(workspace:GetChildren()) do
		if m.Name:find("Viewmodel") then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then hidePart(d, on) end
			end
		end
	end
end

local STEP = "AltarShowcaseCamera"
local function stepCamera(dt)
	local c = workspace.CurrentCamera
	if not c or cam.Mode == "off" then return end
	c.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	viewmodelHide(true)
	local now = os.clock()
	local O = Tuning.Orbit
	if not cam.Drag then
		local k = math.exp(-O.Friction * dt)
		cam.VYaw *= k
		cam.VPitch *= k
	end
	-- the turntable: the M1 turns slowly once the hand lets go; a move preview drifts back to its side view
	local idle = math.clamp((now - cam.LastInput - O.SwayAfter) / 2.5, 0, 1)
	if view.Move and not cam.Held then
		local home = math.floor(cam.Yaw / 360 + 0.5) * 360
		cam.Yaw += (home - cam.Yaw) * (1 - math.exp(-1.2 * dt)) * idle
	else
		cam.Yaw += Tuning.Spin * idle * dt
	end
	cam.Yaw += cam.VYaw * dt
	cam.Pitch = math.clamp(cam.Pitch + cam.VPitch * dt, O.PitchLo, O.PitchHi)
	local wantD = view.Move and Tuning.MoveDist or Tuning.Dist
	local wantH = view.Move and Tuning.MoveHeight or Tuning.Height
	local k = 1 - math.exp(-2.6 * dt)
	cam.D += (wantD - cam.D) * k
	cam.H += (wantH - cam.H) * k
	local target = orbitCF(cam.Yaw, cam.Pitch)
	if cam.Mode == "in" then
		local e = ease(math.clamp((now - cam.T0) / Tuning.In, 0, 1))
		c.CFrame = cam.From:Lerp(target, e)
		c.FieldOfView = 70 + (Tuning.FOV - 70) * e
		if e >= 1 then cam.Mode = "on" end
	else
		c.CFrame = target
		c.FieldOfView = Tuning.FOV
	end
	-- the corona breathes on the hub crystal's cycle
	if lights and lights.Corona then
		local b = 0.5 - 0.5 * math.cos(2 * math.pi * now / Tuning.Corona.Period)
		local A = Tuning.Corona.Alpha
		lights.Corona.ImageTransparency = A[1] + (A[2] - A[1]) * b
		local pg = room and room.Lights.PedestalGlow
		if pg then pg.Brightness = 1.2 + 1.4 * b end
	end
	if piece.Handle then pcall(piece.Handle.Update, now - piece.T0) end
end

local function overUI(pos)
	local inset = game:GetService("GuiService"):GetGuiInset()
	local at = Vector2.new(pos.X, pos.Y) + inset
	for _, f in ipairs({ panelHolder, movesBtnHolder, closeHolder, loadoutHolder }) do
		local a, z = f.AbsolutePosition, f.AbsoluteSize
		if at.X >= a.X and at.X <= a.X + z.X and at.Y >= a.Y and at.Y <= a.Y + z.Y then return true end
	end
	return dropdown.Visible and (function()
		local a, z = dropdown.AbsolutePosition, dropdown.AbsoluteSize
		return at.X >= a.X and at.X <= a.X + z.X and at.Y >= a.Y and at.Y <= a.Y + z.Y
	end)()
end
UserInputService.InputBegan:Connect(function(input, processed)
	if cam.Mode ~= "on" and cam.Mode ~= "in" then return end
	if overUI(input.Position) then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		cam.Drag = true
		cam.Held = true
		cam.LastPos = input.Position
		cam.VYaw, cam.VPitch = 0, 0
		cam.LastInput = os.clock()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not cam.Drag then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		-- (2026-10-27) a free mouse reports Delta 0: the move is the change in Position since the last event
		local d = input.Delta
		if d.Magnitude < 1e-3 and cam.LastPos then d = input.Position - cam.LastPos end
		cam.LastPos = input.Position
		local dt = math.max(1 / 240, os.clock() - cam.LastInput)
		cam.LastInput = os.clock()
		-- the drag sets a velocity (degrees / s) the frame step integrates: weight, not a 1:1 spin
		cam.VYaw = cam.VYaw * 0.5 + (-d.X * Tuning.Orbit.Gain / dt) * 0.5
		cam.VPitch = cam.VPitch * 0.5 + (d.Y * Tuning.Orbit.Gain * 0.6 / dt) * 0.5
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		cam.Drag = false
		cam.LastInput = os.clock()
	end
end)

----------------------------------------------------------------------------------------------------
-- open / close: the hub's ink wipe covers the cut both ways; the hub's flat light, HUD and prompts stand down
----------------------------------------------------------------------------------------------------
local isOpen = false
local saved = { Guis = {}, Light = {} }
local function wipe(what, label)
	local g = playerGui:FindFirstChild("HubWipe")
	local cmd = g and g:FindFirstChild("Command")
	if cmd then cmd:Fire(what, label) end
	return cmd ~= nil
end
local function hud(off)
	if off then
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Name ~= "HubWipe" and g.Enabled then
				saved.Guis[g] = true
				g.Enabled = false
			end
		end
	else
		for g in pairs(saved.Guis) do
			if g.Parent then g.Enabled = true end
		end
		table.clear(saved.Guis)
	end
end
local function roomLight(on)
	if on then
		saved.Light = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
		Lighting.Ambient, Lighting.OutdoorAmbient = Tuning.Ambient, Tuning.Ambient
	elseif saved.Light.Ambient then
		Lighting.Ambient, Lighting.OutdoorAmbient = saved.Light.Ambient, saved.Light.OutdoorAmbient
		saved.Light = {}
	end
end

local function openShowcase()
	if isOpen then return end
	isOpen = true
	player:SetAttribute("LoadoutOpen", true)
	ProximityPromptService.Enabled = false
	local covered = wipe("cover", "LOADOUT!")
	cam.FromFOV = workspace.CurrentCamera.FieldOfView
	task.delay(covered and 0.34 or 0, function()
		if not isOpen then return end
		buildStage()
		roomLight(true)
		hud(true)
		cam.D, cam.H, cam.Yaw, cam.Pitch, cam.VYaw, cam.VPitch, cam.Drag = Tuning.Dist, Tuning.Height, 0, 8, 0, 0, false
		cam.From = orbitCF(-35, 18) * CFrame.new(0, 2, 14)   -- the push after the cut: from high and wide, onto the piece
		cam.LastInput, cam.Mode, cam.T0 = os.clock(), "in", os.clock()
		RunService:BindToRenderStep(STEP, Enum.RenderPriority.Last.Value + 20, stepCamera)
		ContextActionService:BindActionAtPriority("AltarShowcaseLeave", function(_, state)
			if state == Enum.UserInputState.Begin then command:Fire("close") end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
		-- (2026-10-27, the owner) nothing picked, not even the equipped Element: the rail alone, an empty pedestal, a
		-- neutral room
		view.El = nil
		view.Wrap, view.Skin = "Default", "Default"
		view.Move = nil
		setDropdown(false)
		setPicked(false, true)
		refreshRail()
		refreshWraps()
		refreshPlate()
		fit()
		gui.Enabled = true
		moodTo(shownEl(), true, view.Wrap, view.Skin)
		drawPiece(shownEl(), view.Wrap, nil)   -- (PERF TEST 2026-10-27: drawn behind the wipe, there on the reveal)
		task.wait(0.05)
		wipe("reveal")
		slideUI(true, 0.25)
		task.wait(0.35)
		if isOpen and stage then
			-- (the hub's own displays -- the Store's wrap mannequin holds a whole Pyro wrap set -- go idle once the camera
			-- leaves the hub: let them give their meshes back for the skins shown here)
			task.delay(2, function() if isOpen then releaseSkins() end end)
		end
	end)
end

local function closeShowcase(thenLoadout)
	if not isOpen or cam.Mode == "out" then return end
	swapToken += 1
	cam.Mode = "out"
	slideUI(false)
	setDropdown(false)
	local covered = wipe("cover", "BACK TO THE HUB")
	task.delay(covered and 0.34 or 0, function()
		RunService:UnbindFromRenderStep(STEP)
		ContextActionService:UnbindAction("AltarShowcaseLeave")
		clearPiece()
		clearStage()
		roomLight(false)
		local c = workspace.CurrentCamera
		if c then
			c.CameraType = Enum.CameraType.Custom
			c.FieldOfView = cam.FromFOV
		end
		viewmodelHide(false)
		hud(false)
		gui.Enabled = false
		cam.Mode = "off"
		piece.El = nil
		view.Move = nil
		ProximityPromptService.Enabled = true
		player:SetAttribute("LoadoutOpen", nil)
		isOpen = false
		task.wait(0.05)
		wipe("reveal")
		if thenLoadout then
			local lm = playerGui:FindFirstChild("LoadoutMenu")
			local cmd = lm and lm:FindFirstChild("Command")
			if cmd then cmd:Fire("open") end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- commands (the buttons and the Studio check hook)
----------------------------------------------------------------------------------------------------
local function equip(kind, el, id)
	if not owns(el) then return false end
	-- (2026-10-27, the owner) the lobby never equips an Element (you pick it in the game): the wrap or skin is set on its
	-- own Element, which needn't be the one you play
	loadoutRemote:FireServer(kind, el, id)
	return true
end

command.Event:Connect(function(what, arg)
	if what == "open" then
	if what == "move" or what == "element" then cam.Held = false end   -- (2026-10-27) a new preview starts on its side view
		openShowcase()
	elseif what == "close" then
		closeShowcase(false)
	elseif what == "fit" then                                      -- (Studio check: lay out for a screen of arg's size)
		fit(arg or false)
	elseif not isOpen then
		return
	elseif what == "element" and arg and arg == view.El then
		-- (2026-10-27, the owner) the picked Element clicked again closes its WRAPS | SKINS column; the pedestal empties and
		-- the room goes neutral (the column keeps its tiles while the panel narrows over them)
		view.El = nil
		local el = nil
		view.Wrap, view.Skin = "Default", "Default"
		local moved = view.Move ~= nil
		view.Move = nil
		setDropdown(false)
		setPicked(false)
		refreshRail()
		refreshPlate()
		if moved or piece.El ~= el or piece.Wrap ~= view.Wrap then swapTo(el, view.Wrap, nil) end
	elseif what == "element" and arg and arg ~= view.El then
		view.El = arg
		view.Wrap = equippedWrap(arg)
		view.Skin = equippedSkin(arg)
		local moved = view.Move ~= nil
		view.Move = nil
		setDropdown(false)
		setPicked(true)
		refreshRail()
		refreshWraps()
		refreshPlate()
		-- (the first pick is often the equipped Element, already on the pedestal: no swap then)
		if moved or piece.El ~= arg or piece.Wrap ~= view.Wrap then swapTo(view.El, view.Wrap, nil) end
	elseif what == "wrap" and arg and view.El then
		local changed = arg ~= view.Wrap or view.Move ~= nil
		view.Wrap = arg
		equip("ElementWrap", view.El, arg)
		view.Move = nil
		if dropdown.Visible then refreshMoves() end
		refreshWraps()
		refreshPlate()
		if changed then swapTo(view.El, view.Wrap, nil) end
	elseif what == "skin" and arg and view.El and table.find(skinsOf(view.El), arg) then
		local changed = arg ~= view.Skin or view.Move ~= nil
		view.Skin = arg
		equip("ElementSkin", view.El, arg)
		view.Move = nil
		if dropdown.Visible then refreshMoves() end
		refreshWraps()
		refreshPlate()
		if changed then swapTo(view.El, view.Wrap, nil) end
		-- the skin left behind is still "worn" until the server's ElementSkin_ attribute lands, so its kit kept its meshes
		-- on the swap's own pass: ask again until the shown skin's kit is built (or 12 s, or another pick)
		local el, id = view.El, arg
		task.spawn(function()
			for _ = 1, 8 do
				task.wait(1.5)
				if not isOpen or view.El ~= el or view.Skin ~= id then return end
				if releaseSkins() then return end
			end
		end)
	elseif what == "tab" and (arg == "Wraps" or arg == "Skins") then
		view.Tab = arg
		refreshWraps()
	elseif what == "move" and arg and view.El then
		if view.Move == arg then view.Move = nil else view.Move = arg end
		refreshMoves()
		refreshPlate()
		swapTo(shownEl(), view.Wrap, view.Move)
	elseif what == "orbit" and type(arg) == "number" then          -- (Studio check: a flick of arg degrees a second)
		cam.VYaw, cam.LastInput = arg, os.clock()
	elseif what == "dropdown" then
		local open = not dropdown.Visible
		setDropdown(open)
		if not open and view.Move then
			view.Move = nil
			refreshPlate()
			swapTo(shownEl(), view.Wrap, nil)
		end
	end
end)
movesHit.MouseButton1Click:Connect(function() command:Fire("dropdown") end)
closeHit.MouseButton1Click:Connect(function() command:Fire("close") end)
loadoutHit.MouseButton1Click:Connect(function() closeShowcase(true) end)
buildRail()

-- the equipped marks follow the server
player.AttributeChanged:Connect(function(name)
	if not isOpen then return end
	if name == "Element" or name == "OwnedElements" then
		refreshRail()
		refreshWraps()
	elseif string.sub(name, 1, 12) == "ElementWrap_" or string.sub(name, 1, 12) == "ElementSkin_" then
		refreshWraps()
	end
end)
player.CharacterRemoving:Connect(function() if isOpen then closeShowcase(false) end end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() fit() end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit() end)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() fit() end)
gui:SetAttribute("Ready", true)
