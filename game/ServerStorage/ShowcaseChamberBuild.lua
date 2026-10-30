--[[
	ShowcaseChamberBuild  (ModuleScript, EDIT-TIME TOOL)  ->  ServerStorage/ShowcaseChamberBuild

	Builds (or rebuilds) workspace.LoadoutShowcaseChamber -- the Loadout Showcase's own room (2026-10-26, the owner:
	"a dedicated showcase chamber ... built as a stage, not a lived-in space", no hub props). Run it in Studio's Edit
	DataModel:  require(game.ServerStorage.ShowcaseChamberBuild)()  -- it replaces the old model, so edit the numbers
	here and re-run rather than hand-editing the parts. Nothing calls it at run time.

	THE ROOM (centre Tuning.Centre, far from every map; ModelStreamingMode Persistent so every client has it):
	  * a dark round floor; a two-tier stage -- an ink plinth ring, a cream comic-print stage top (halftone dots),
	    a gold lip, a Neon mood ring -- and the centre PEDESTAL (ink column, cream cap, mood ring) that holds the M1;
	  * a ring of tall wall slabs, ink and navy alternating, with a Neon mood strip in every seam, a cream comic
	    "panel border" band near the top, halftone on every slab, and one LOADOUT wordmark panel;
	  * a dark ceiling with a Neon mood ring over the pedestal and the KEY spotlight in it.
	Every part the showcase recolours per Element carries attribute Mood = "Base" | "Light" | "Dark"; the pedestal's
	parts carry Pedestal = true (it sinks into the stage for move previews). Lights are named Key / RimA / RimB / Fill.
]]

local Tuning = {
	Centre = Vector3.new(8000, 0, 4000),
	FloorR = 44, StageR = 15, TopR = 10.5, WallR = 36, WallH = 24, Slabs = 18, CeilY = 26,
	Ink = Color3.fromRGB(17, 17, 17), Night = Color3.fromRGB(21, 21, 28), Navy = Color3.fromRGB(27, 36, 64),
	Card = Color3.fromRGB(246, 243, 235), Cream = Color3.fromRGB(250, 244, 232), Gold = Color3.fromRGB(255, 211, 66),
	Mood = Color3.fromRGB(245, 184, 0),   -- the resting mood colour (the showcase tints it per Element)
	DOT = "rbxassetid://82944445925061",  -- the game's halftone cell (HubLifeKit K.DOT)
}

return function()
	local old = workspace:FindFirstChild("LoadoutShowcaseChamber")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "LoadoutShowcaseChamber"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local C = Tuning.Centre

	local function part(name, size, cf, colour, props)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, colour
		p.Anchored, p.CanCollide, p.CastShadow, p.TopSurface, p.BottomSurface = true, true, true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in pairs(props or {}) do
			if k == "Mood" or k == "Pedestal" then p:SetAttribute(k, v) else p[k] = v end
		end
		p.Parent = model
		return p
	end
	-- a flat disc / ring slab: Roblox cylinders lie along X, so turn them upright
	local UP = CFrame.Angles(0, 0, math.rad(90))
	local function disc(name, r, h, y, colour, props)
		local p = part(name, Vector3.new(h, 2 * r, 2 * r), CFrame.new(C + Vector3.new(0, y + h / 2, 0)) * UP, colour, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function halftone(p, face, colour, alpha, pitch)
		local sg = Instance.new("SurfaceGui")
		sg.Face, sg.SizingMode, sg.PixelsPerStud, sg.LightInfluence = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 20, 1
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency, img.Size, img.Image = 1, UDim2.fromScale(1, 1), Tuning.DOT
		img.ImageColor3, img.ImageTransparency, img.ScaleType, img.TileSize = colour, alpha, Enum.ScaleType.Tile, UDim2.fromOffset(pitch, pitch)
		img.Parent = sg
		sg.Parent = p
		return sg
	end

	-- the floor and the stage
	disc("Floor", Tuning.FloorR, 1, -1, Tuning.Night)
	disc("PlinthInk", Tuning.StageR + 0.8, 1.0, 0, Tuning.Ink)
	disc("Plinth", Tuning.StageR, 1.25, 0, Color3.fromRGB(34, 35, 44))
	disc("PlinthLip", Tuning.StageR + 0.25, 0.27, 1.25, Tuning.Gold:Lerp(Tuning.Ink, 0.35))
	local top = disc("StageTop", Tuning.TopR, 0.4, 1.25, Color3.fromRGB(206, 200, 186))
	halftone(top, Enum.NormalId.Right, Tuning.Ink, 0.86, 18)   -- (an upright cylinder's top is its Right face)
	disc("StageRing", Tuning.TopR + 0.35, 0.33, 1.28, Tuning.Mood, { Material = Enum.Material.Neon, Mood = "Base", CanCollide = false })
	disc("StageRingInk", Tuning.TopR + 0.75, 0.3, 1.27, Tuning.Ink, { CanCollide = false })

	-- the pedestal (sinks into the stage for move previews; the M1 floats over its cap)
	disc("PedestalColumn", 2.0, 3.0, 1.65, Tuning.Ink, { Pedestal = true })
	disc("PedestalCap", 2.6, 0.45, 4.65, Tuning.Card, { Pedestal = true })
	disc("PedestalCapInk", 2.75, 0.2, 4.6, Tuning.Ink, { Pedestal = true })
	disc("PedestalRing", 2.15, 0.2, 2.8, Tuning.Mood, { Material = Enum.Material.Neon, Mood = "Light", Pedestal = true, CanCollide = false })
	disc("PedestalFoot", 2.9, 0.4, 1.65, Tuning.Gold, { Pedestal = true })
	disc("PedestalBandLo", 2.08, 0.16, 2.35, Tuning.Mood, { Material = Enum.Material.Neon, Mood = "Base", Pedestal = true, CanCollide = false })
	disc("PedestalBandHi", 2.08, 0.12, 4.2, Tuning.Mood, { Material = Enum.Material.Neon, Mood = "Base", Pedestal = true, CanCollide = false })
	disc("PedestalLens", 2.25, 0.06, 5.1, Tuning.Mood, { Material = Enum.Material.Neon, Mood = "Light", Pedestal = true, CanCollide = false, Transparency = 0.25 })
	local glowHolder = disc("PedestalGlowHolder", 0.2, 0.1, 5.4, Tuning.Ink, { Pedestal = true, Transparency = 1, CanCollide = false, CanQuery = false })
	local pg = Instance.new("PointLight")
	pg.Name, pg.Range, pg.Brightness, pg.Shadows, pg.Color = "PedestalGlow", 9, 1.6, false, Tuning.Mood
	pg.Parent = glowHolder

	-- the walls: tall slabs in a ring, ink and navy alternating, a Neon mood strip in each seam
	local n = Tuning.Slabs
	local arc = 2 * math.pi * Tuning.WallR / n
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local cf = CFrame.lookAt(C + dir * Tuning.WallR + Vector3.new(0, Tuning.WallH / 2 - 1, 0), C + Vector3.new(0, Tuning.WallH / 2 - 1, 0))
		local slab = part("Wall_" .. i, Vector3.new(arc - 0.9, Tuning.WallH, 2), cf, (i % 2 == 0) and Tuning.Ink or Tuning.Navy, { CastShadow = false })
		halftone(slab, Enum.NormalId.Front, (i % 2 == 0) and Tuning.Navy or Tuning.Ink, 0.55, 26)
		-- the comic panel border: a cream band near the top with an ink keyline under it
		part("Band_" .. i, Vector3.new(arc - 0.9, 1.6, 0.4), cf * CFrame.new(0, Tuning.WallH / 2 - 4, -1.15), Tuning.Cream, { CanCollide = false, CastShadow = false })
		part("Keyline_" .. i, Vector3.new(arc - 0.9, 0.35, 0.4), cf * CFrame.new(0, Tuning.WallH / 2 - 5.1, -1.15), Tuning.Ink, { CanCollide = false, CastShadow = false })
		-- the seam strip (mood)
		local b = (i + 1) / n * 2 * math.pi
		local sd = Vector3.new(math.cos(b), 0, math.sin(b))
		part("Seam_" .. i, Vector3.new(0.7, Tuning.WallH - 6, 0.7),
			CFrame.lookAt(C + sd * (Tuning.WallR - 0.6) + Vector3.new(0, (Tuning.WallH - 6) / 2, 0), C + Vector3.new(0, (Tuning.WallH - 6) / 2, 0)),
			Tuning.Mood, { Material = Enum.Material.Neon, Mood = (i % 3 == 0) and "Light" or "Base", CanCollide = false, CastShadow = false })
		-- a low mood skirt along the floor (the wall's foot light)
		part("Skirt_" .. i, Vector3.new(arc - 0.9, 0.4, 0.5), cf * CFrame.new(0, -Tuning.WallH / 2 + 1.2, -1.3), Tuning.Mood,
			{ Material = Enum.Material.Neon, Mood = "Dark", CanCollide = false, CastShadow = false })
	end
	-- (2026-10-27, the owner: "close the environment completely") an outer shell behind the slabs, from the floor to past
	-- the ceiling: the sky showed through the band between the slabs' tops (WallH - 1) and the ceiling, and the gaps between slabs
	local shellR = Tuning.WallR + 1.6
	local shellW = 2 * shellR * math.tan(math.pi / n) + 0.3     -- (overlapping at the corners)
	local shellH = Tuning.CeilY + 1.2 + 1
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local y = shellH / 2 - 1
		part("Shell_" .. i, Vector3.new(shellW, shellH, 1), CFrame.lookAt(C + dir * shellR + Vector3.new(0, y, 0), C + Vector3.new(0, y, 0)),
			Tuning.Night, { CastShadow = false })
	end

	-- the LOADOUT wordmark panel, on the wall the camera sees behind the piece at its home angle
	local homeDir = Vector3.new(0, 0, -1)
	local wcf = CFrame.lookAt(C + homeDir * (Tuning.WallR - 1.6) + Vector3.new(0, 15.5, 0), C + Vector3.new(0, 15.5, 0))
	local plate = part("WordmarkPlate", Vector3.new(26, 6.2, 0.5), wcf, Tuning.Card, { CanCollide = false })
	part("WordmarkInk", Vector3.new(27.2, 7.4, 0.4), wcf * CFrame.new(0, 0, 0.2), Tuning.Ink, { CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face, sg.SizingMode, sg.PixelsPerStud, sg.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 30, 0
	for k, spec in ipairs({ { Tuning.Ink:Lerp(Tuning.Card, 0.28), 10 }, { Tuning.Ink, 0 } }) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency, l.Font, l.Text, l.TextScaled = 1, Enum.Font.LuckiestGuy, "LOADOUT", true
		l.TextColor3, l.Size, l.Position, l.ZIndex = spec[1], UDim2.fromScale(0.94, 0.86), UDim2.new(0.03, spec[2], 0.07, spec[2]), k
		l.Parent = sg
	end
	sg.Parent = plate

	-- the ceiling, its mood ring and the key light
	disc("Ceiling", Tuning.WallR + 2, 1.2, Tuning.CeilY, Tuning.Night, { CastShadow = false })
	disc("CeilingRing", 7, 0.3, Tuning.CeilY - 0.3, Tuning.Mood, { Material = Enum.Material.Neon, Mood = "Light", CanCollide = false, CastShadow = false })
	disc("CeilingWell", 6.4, 0.32, Tuning.CeilY - 0.32, Tuning.Ink, { CanCollide = false, CastShadow = false })
	local keyPart = part("KeyLight", Vector3.new(1, 1, 1), CFrame.lookAt(C + Vector3.new(0, Tuning.CeilY - 1, 0), C), Tuning.Ink,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local key = Instance.new("SpotLight")
	key.Name, key.Face, key.Angle, key.Range, key.Brightness, key.Shadows, key.Color = "Key", Enum.NormalId.Front, 30, 40, 2.6, true, Color3.fromRGB(255, 246, 230)
	key.Parent = keyPart
	for _, spec in ipairs({ { "RimA", Vector3.new(-6, 3, 6) }, { "RimB", Vector3.new(6, 3, -6) }, { "Fill", Vector3.new(0, 12, 0) } }) do
		local holder = part(spec[1] .. "Holder", Vector3.new(1, 1, 1), CFrame.new(C + spec[2]), Tuning.Ink,
			{ Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
		local l = Instance.new("PointLight")
		l.Name, l.Range, l.Brightness, l.Shadows, l.Color = spec[1], spec[1] == "Fill" and 40 or 16, spec[1] == "Fill" and 0.6 or 1.6, false, Tuning.Mood
		l.Parent = holder
	end

	model.Parent = workspace
	return model
end
