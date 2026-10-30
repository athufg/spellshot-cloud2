--[[
	HubShowcase  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubShowcase

	THE WRAP SHOWCASE by the Store (2026-10-25, the owner's hub-rebuild brief, step 4). Client only, runs only while
	HubLife.On() (Studio until the owner's review). It SHOWS wraps; it never equips or sells one.

	  * A plinth in the hub's pillar materials (dark stone foot, pale stone shaft, gold bands, a stone cap) beside the
	    Store's bowl gate, with a glow band under its cap.
	  * On it, the R15 mannequin (the NPCs' body) holding the wrap's REAL M1 projectile: its Element's own combat draw in
	    that wrap (HubShowcaseM1, one display per Element), held static in its hands (2026-10-26, the owner: no stand-in
	    sphere).
	  * The plinth's glow band and light take the wrap's main colour; a floating nameplate turns to the viewer with the
	    wrap's name, its rarity in the rarity colour (the shop's rarity mark) and its Element.
	  * Every Hold seconds it moves to the next wrap: the plate pops out and back in, the held M1 swaps at the low point.
	WHICH WRAPS: SHOWCASE below, in order, keeping only the ones that are LIVE (in SkinCatalog.ElementWraps) and Rare or
	higher. The owner's examples come first: Phoenix, Meteorite Core, Prism Bloom -- Meteorite Core is staged, not live
	(2026-10-25), so it is skipped until it is.
	A wrap whose Element has no M1 display in HubShowcaseM1 is left out of the rotation (never drawn as a stand-in).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
local K = require(spell:WaitForChild("HubLifeKit"))
local SkinCatalog = require(spell:WaitForChild("SkinCatalog"))

local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	At = Vector3.new(8009.5, 0, 7965.5),           -- floor point (clear floor beside the Store's bowl gate)
	FaceTo = Vector3.new(8000, 0, 8000),            -- turned to the plaza
	Plinth = { Height = 1.8, Foot = 3.9, Shaft = 3.0, Cap = 3.6 },
	Colours = { Foot = "44464F", Shaft = "D8D8D2", Cap = "8A8C97", Gold = "BE8C3C" },   -- the hub's own stone and trim
	Body = Color3.fromHex("C9C6BE"),
	Orb = { Radius = 0.7, Above = 0.5, Forward = 0.95, Bob = 0.1, Spin = 0.8, Motes = 7 },     -- (held at the chest, clear of the face)
	Hold = 6.0,
	Plate = { Size = Vector2.new(6.6, 2.1), Above = 1.9, PPS = 60 },
	Light = { Range = 10, Brightness = 1.4 },
	Near = 60, Far = 80,            -- the held M1 is drawn only while the camera is this close (budget + draw cost)
	Offset = { Aqua = Vector3.new(0, -2.2, -1.6) },   -- Riptide is a floor wave: held low, in front of the plinth (in the plinth's space)
}
-- (2026-10-26) the held prop is each wrap's REAL M1, and a wrapped M1 builds that wrap's EditableMesh copies. Measured in
-- Studio: cycling every live wrap filled the client's mesh budget (Void Flame drew nothing on the second pass, Toxin's skin
-- builds failed). Pyro's sets are LRU-evicted (two kept) and Cryo's copies are handed back after its turn (CryoWrap.MakeRoom);
-- Aqua's and Toxin's wrap copies are never released (no MeshBudget give-back in AquaWrap / ToxinWrap), so whatever the
-- pedestal built for them would stay all session and could starve a player's own skin or wrap in a match. Until those
-- modules can give their copies back, the rotation is: one Pyro wrap, two Cryo, and every Radiant and Umbra wrap (their
-- M1s -- the Light Lance beam, the Shadow Dart -- build no meshes). Two full cycles: no budget errors.
local SHOWCASE = { "Phoenix", "MeteoriteCore", "Meteorite", "PrismBloom", "Aurora", "UmbralEclipse", "Starlight", "SakuraFrost",
	"Wisplight", "StainedGlass", "Ashen" }
local RANK = { Rare = 1, Epic = 2, Mythic = 3 }

-- the pose: presenting the orb in both hands (forearms forward and up, hands in front of the chest)
local POSE = {
	LeftShoulder = CFrame.Angles(math.rad(24), 0, math.rad(14)),
	RightShoulder = CFrame.Angles(math.rad(24), 0, math.rad(-14)),
	LeftElbow = CFrame.Angles(math.rad(62), 0, 0),
	RightElbow = CFrame.Angles(math.rad(62), 0, 0),
	LeftWrist = CFrame.Angles(math.rad(-30), 0, math.rad(-10)),
	RightWrist = CFrame.Angles(math.rad(-30), 0, math.rad(10)),
	Neck = CFrame.Angles(math.rad(-16), 0, 0),
	Waist = CFrame.Angles(math.rad(-3), 0, 0),
}

----------------------------------------------------------------------------------------------------
-- the live wraps, and the four colours each is drawn in
----------------------------------------------------------------------------------------------------
local function c3(v) return typeof(v) == "Color3" and v or nil end
local function firstColour(t, depth)
	if type(t) ~= "table" or (depth or 0) > 3 then return nil end
	for _, v in pairs(t) do
		if typeof(v) == "Color3" then return v end
	end
	for _, v in pairs(t) do
		local x = firstColour(v, (depth or 0) + 1)
		if x then return x end
	end
	return nil
end
local function lum(c) return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B end
local function swatch(s)
	local P = type(s.Palette) == "table" and s.Palette or {}
	local main, hi, sh, acc = c3(P.Main), c3(P.Highlight), c3(P.Shadow), c3(P.Accent) or c3(P.Silver)
	if type(s.Stops) == "table" and #s.Stops >= 3 then
		main = main or c3(s.Stops[math.ceil(#s.Stops / 2)])
		hi = hi or c3(s.Stops[1])
		sh = sh or c3(s.Stops[#s.Stops])
	end
	if type(s.Label) == "table" and #s.Label >= 3 then
		-- a Label strip runs dark -> mid -> bright for the Aqua wraps, main -> highlight -> shadow for Pyro's
		local a, b, c = c3(s.Label[1]), c3(s.Label[2]), c3(s.Label[3])
		if a and b and c then
			local sorted = { a, b, c }
			table.sort(sorted, function(x, y) return lum(x) < lum(y) end)
			sh, main, hi = sh or sorted[1], main or sorted[2], hi or sorted[3]
		end
	end
	main = main or firstColour(P.Color) or firstColour(P.Glow) or firstColour(P.Tints) or hi or sh or Color3.fromHex("CCCCCC")
	hi = hi or main:Lerp(Color3.new(1, 1, 1), 0.5)
	sh = sh or main:Lerp(Color3.new(0, 0, 0), 0.55)
	acc = acc or hi
	if lum(main) < 0.08 then main = main:Lerp(hi, 0.45) end      -- (the grade crushes near-black to 0)
	if lum(sh) < 0.035 then sh = sh:Lerp(main, 0.35) end
	return { Main = main, Hi = hi, Shadow = sh, Accent = acc }
end
local function liveWraps()
	local live = {}
	local wraps = SkinCatalog.ElementWraps or {}
	local skins = SkinCatalog.Skins or {}
	for _, id in ipairs(SHOWCASE) do
		local s = skins[id]
		local el = s and s.Wrap
		if s and el and RANK[s.Rarity or ""] then
			for _, w in ipairs(wraps[el] or {}) do
				if w == id then
					live[#live + 1] = { Id = id, Name = s.DisplayName or id, Rarity = s.Rarity, Element = el, Swatch = swatch(s) }
					break
				end
			end
		end
	end
	return live
end
local WRAPS = liveWraps()
if #WRAPS == 0 then
	warn("[HubShowcase] no live Rare+ wraps from SHOWCASE: nothing to show")
	return
end

----------------------------------------------------------------------------------------------------
-- the plinth
----------------------------------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "HubLife_Showcase"
folder.Parent = workspace
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	if not props.Parent then p.Parent = folder end
	return p
end
local PL = Tuning.Plinth
local base = CFrame.lookAt(Tuning.At, Vector3.new(Tuning.FaceTo.X, Tuning.At.Y, Tuning.FaceTo.Z))
local hex = Color3.fromHex
part({ Name = "Plinth_Foot", Size = Vector3.new(PL.Foot, 0.4, PL.Foot), Color = hex(Tuning.Colours.Foot), CFrame = base * CFrame.new(0, 0.2, 0), CanCollide = true })
part({ Name = "Plinth_Shaft", Size = Vector3.new(PL.Shaft, PL.Height - 0.75, PL.Shaft), Color = hex(Tuning.Colours.Shaft),
	CFrame = base * CFrame.new(0, 0.4 + (PL.Height - 0.75) / 2, 0), CanCollide = true })
part({ Name = "Plinth_Gold", Size = Vector3.new(PL.Shaft + 0.12, 0.12, PL.Shaft + 0.12), Color = hex(Tuning.Colours.Gold), CFrame = base * CFrame.new(0, 0.55, 0) })
local glowBand = part({ Name = "Plinth_Glow", Size = Vector3.new(PL.Shaft + 0.1, 0.16, PL.Shaft + 0.1), Material = Enum.Material.Neon,
	Color = WRAPS[1].Swatch.Main, CFrame = base * CFrame.new(0, PL.Height - 0.43, 0) })
part({ Name = "Plinth_Cap", Size = Vector3.new(PL.Cap, 0.35, PL.Cap), Color = hex(Tuning.Colours.Cap), CFrame = base * CFrame.new(0, PL.Height - 0.175, 0), CanCollide = true })
local glowLight = Instance.new("PointLight")
glowLight.Range, glowLight.Brightness, glowLight.Shadows, glowLight.Color = Tuning.Light.Range, Tuning.Light.Brightness, false, WRAPS[1].Swatch.Main
glowLight.Parent = glowBand

----------------------------------------------------------------------------------------------------
-- the mannequin, posed once
----------------------------------------------------------------------------------------------------
local rig = HubLife.Mannequin()
if not rig then return end
rig.Model.Name = "HubLife_ShowcaseMannequin"
for _, p in ipairs(rig.Model:GetDescendants()) do
	if p:IsA("BasePart") and p ~= rig.Root then
		p.Color = Tuning.Body
		p.Material = Enum.Material.SmoothPlastic
		p.CastShadow = true
	end
end
rig.Model.Parent = folder
local rootCF = base * CFrame.new(0, PL.Height + 3.192, 0)      -- (the root stands 3.192 over the feet: HubLife.NPC)
local parts, cfs = {}, {}
local posed = HubLife.Pose(rig, rootCF, POSE, parts, cfs)
workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
local lh, rh = rig.Model:FindFirstChild("LeftHand"), rig.Model:FindFirstChild("RightHand")
local handsAt = (posed[lh].Position + posed[rh].Position) / 2
local orbHome = handsAt + Vector3.new(0, Tuning.Orb.Above, 0) + base.LookVector * Tuning.Orb.Forward

----------------------------------------------------------------------------------------------------
-- the held projectile: the wrap's REAL M1 (HubShowcaseM1: each Element's own combat draw, in that wrap), held static in
-- the mannequin's hands, flying across the plinth so its shape shows side-on from the plaza
----------------------------------------------------------------------------------------------------
local M1 = require(spell:WaitForChild("HubShowcaseM1"))
local Budget = HubLife.Budget()
local heldFolder = Instance.new("Folder")
heldFolder.Name = "HubLife_ShowcaseHeld"
heldFolder.Parent = folder
local held, pending = nil, nil      -- held = { Handle, T0 }; pending = the wrap waiting to be drawn
-- Cryo's wrapped M1 builds heavy per-mesh copies (Aurora's are per-cell): when a Cryo wrap leaves the pedestal its copies
-- go back (CryoWrap.MakeRoom, the same give-back MeshBudget uses), so they never starve a worn skin or the next wrap
local CryoWrap = nil
pcall(function() CryoWrap = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("CryoWrap", 5)) end)
local function release()
	if held then
		pcall(held.Handle.Destroy)
		if held.Element == "Cryo" and CryoWrap and CryoWrap.MakeRoom then pcall(CryoWrap.MakeRoom) end
		held = nil
	end
end
local function draw(w)
	release()
	local fn = M1[w.Element]
	if not fn then return false end
	local off = Tuning.Offset[w.Element]
	local cf = CFrame.lookAt(orbHome, orbHome + base.RightVector)
	if off then
		local at = orbHome + base:VectorToWorldSpace(off)
		cf = CFrame.lookAt(at, at + base.RightVector)
	end
	local ok, h = pcall(fn, w.Id, cf, heldFolder)
	if not ok or type(h) ~= "table" then
		warn("[HubShowcase] " .. w.Id .. ": its M1 did not draw: " .. tostring(h))
		return false
	end
	held = { Handle = h, T0 = os.clock(), Element = w.Element }
	return true
end
-- asked to show a wrap: drawn now if the camera is near and no worn skin's mesh build runs, else when it is
local function hold(w)
	release()
	pending = w
	return true
end
-- only wraps whose Element has its M1 display (never a stand-in shape)
do
	local keep = {}
	for _, w in ipairs(WRAPS) do
		if M1[w.Element] then keep[#keep + 1] = w else warn("[HubShowcase] no M1 display for " .. w.Element .. ": " .. w.Id .. " left out") end
	end
	WRAPS = keep
	if #WRAPS == 0 then return end
end

----------------------------------------------------------------------------------------------------
-- the nameplate: a floating plaque that turns to the viewer
----------------------------------------------------------------------------------------------------
local PT = Tuning.Plate
local plate = part({ Name = "HubLife_ShowcasePlate", Transparency = 1, Size = Vector3.new(PT.Size.X, PT.Size.Y, 0.05) })
local plateHome = posed[rig.Model:FindFirstChild("Head")].Position + Vector3.new(0, PT.Above, 0)
local sg = K.make("SurfaceGui", { Name = "Plate", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	PixelsPerStud = PT.PPS, LightInfluence = 0, MaxDistance = 90, Adornee = plate, ResetOnSpawn = false }, Players.LocalPlayer:WaitForChild("PlayerGui"))
local W_PX, H_PX = PT.Size.X * PT.PPS, PT.Size.Y * PT.PPS
local holder = K.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5) }, sg)
local popScale = K.make("UIScale", { Scale = 1 }, holder)
local _, face = K.slab(holder, UDim2.fromOffset(W_PX - 12, H_PX - 12), UDim2.fromOffset(6, 6), K.C.Card, 2, 9, 4, 6)
K.halftone(face, 0.9, K.C.Ink, 10, 3)
local nameLabel = K.display(face, { Name = "WrapName", Text = "", TextSize = 46, Position = UDim2.fromOffset(16, 6),
	Size = UDim2.new(1, -32, 0, 58), TextScaled = true, ZIndex = 6 }, 3, K.C.Ink, K.C.Card:Lerp(K.C.Ink, 0.28))
local nameBack = nil
for _, l in ipairs(face:GetChildren()) do
	if l:IsA("TextLabel") and l ~= nameLabel and l.Name == "WrapName" then nameBack = l end
end
local tagRow = K.make("Frame", { Name = "Tags", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, H_PX - 12 - 9 - 46),
	Size = UDim2.new(1, -32, 0, 36), ZIndex = 5 }, face)
K.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, tagRow)
local rarityHolder = K.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, tagRow)
local elementTag = K.make("TextLabel", { BackgroundTransparency = 1, FontFace = K.MONO, TextSize = 26, TextColor3 = K.C.LockedInk, Text = "",
	Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 6 }, tagRow)

----------------------------------------------------------------------------------------------------
-- showing a wrap
----------------------------------------------------------------------------------------------------
local current = nil
local function show(w)
	current = w
	local S = w.Swatch
	hold(w)
	glowBand.Color = S.Main
	glowLight.Color = S.Main
	nameLabel.Text = string.upper(w.Name)
	if nameBack then nameBack.Text = string.upper(w.Name) end
	for _, c in ipairs(rarityHolder:GetChildren()) do c:Destroy() end
	K.rarityChip(rarityHolder, w.Rarity, 0, 0, 36, 24, 6)
	local def = K.element(w.Element)
	elementTag.Text = string.upper((def and def.Display) or w.Element) .. " WRAP"
	folder:SetAttribute("Showing", w.Id)
end

local popK = 1                 -- the plate's scale (the swap pops it out and back; the held M1 swaps at the low point)
local index = 1
show(WRAPS[index])
task.spawn(function()
	while folder.Parent do
		task.wait(Tuning.Hold)
		if #WRAPS > 1 then
			local t0 = os.clock()
			while os.clock() - t0 < 0.22 do
				popK = 1 - (os.clock() - t0) / 0.22
				task.wait()
			end
			popK = 0
			index = index % #WRAPS + 1
			show(WRAPS[index])
			t0 = os.clock()
			while os.clock() - t0 < 0.38 do
				local k = (os.clock() - t0) / 0.38
				popK = TweenService:GetValue(k, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				task.wait()
			end
			popK = 1
		end
	end
end)

local moveParts, moveCFs = {}, {}
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if not HubLife.Close() then return end
	local t = os.clock() - t0
	local k = math.max(0.01, popK)
	table.clear(moveParts)
	table.clear(moveCFs)
	local camPos = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
	local dist = camPos and (camPos - orbHome).Magnitude or math.huge
	if held and dist > Tuning.Far then
		pending = current
		release()
	elseif pending and dist < Tuning.Near and not (Budget and Budget.Busy()) then
		local w = pending
		pending = nil
		if not draw(w) then folder:SetAttribute("Failed_" .. w.Id, true) end
	end
	if held and held.Handle.Update then
		local ok, err = pcall(held.Handle.Update, os.clock() - held.T0)
		if not ok then
			warn("[HubShowcase] " .. tostring(current and current.Id) .. ": " .. tostring(err))
			pcall(held.Handle.Destroy)
			held = nil
		end
	end
	-- the plate turns (flat) to the camera, with the pop
	local cam = workspace.CurrentCamera
	local look = cam and (cam.CFrame.Position - plateHome) or base.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or base.LookVector
	moveParts[#moveParts + 1] = plate
	moveCFs[#moveCFs + 1] = CFrame.lookAt(plateHome, plateHome + dir)
	workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
	popScale.Scale = 0.6 + 0.4 * k
	holder.Visible = popK > 0.02
end)
folder:SetAttribute("Wraps", #WRAPS)
folder:SetAttribute("Ready", true)
