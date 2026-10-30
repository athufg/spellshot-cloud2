--[[
	LoadoutDressingBuild  (ModuleScript, EDIT-TIME TOOL)  ->  ServerStorage/LoadoutDressingBuild

	Builds (or rebuilds) ArcaneObservatoryHub.LoadoutDressing (2026-10-27, the owner's brief): set dressing round the
	Loadout room's 3-slot stone counter (Coll_furn_0263, merged into the hub meshes; it STAYS, and HubLoadoutCounter fills
	its three slots with the player's loadout), and a light for the Loadout book's desk lamp. Run it in Studio's Edit
	DataModel:
	    require(game.ServerStorage.LoadoutDressingBuild)()
	It replaces the old model (keeping its LoadoutBook child, the imported book: (2026-10-27) install_book.lua), so edit
	the numbers here and re-run rather than hand-editing the parts. Nothing calls it at
	run time; the model is ModelStreamingMode Persistent (as Fires and CrystalSpin are) so every client has it.

	THE SPOT, measured 2026-10-27 from the hub's own triangles, in the counter's frame (Tuning.Frame: +X along the
	colonnade, +Z back to the pillars, -Z out to the altar ring, y 0 = the floor): pillar B's plinth (x +-1.65, z 1.62..4.92,
	shaft axis z 3.27) stands right behind the counter (x +-3.42, z -1.45..1.47).
	  LoadoutBanner   a navy swallowtail banner hung from a gold collar and rod round pillar B (over the counter), gold
	                  borders and tassels, a gold ring and four-point star emblem with a chevron under it
	  BookLampLight   a warm SpotLight in the Loadout book's desk-lamp glow, aimed down at the pages (the lamp had none;
	                  HubLoadoutBook animates the pages under it)
	(2026-10-27) The TomeShelf, TrophyPedestal and Crates this built over the counter's spot are gone: the counter was
	kept, and they stood in it.
	Colours are the hub meshes' own (Trim_Gold, Gold_Trim, Cloth_Navy), so the hub's grade turns them navy and gold
	exactly as it does the merged furniture round them.
]]

local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Name = "LoadoutDressing",
	-- the counter's collider frame (Coll_furn_0263: centre 7937.62, 8023.42, yaw 10)
	Frame = CFrame.new(7937.618, 0, 8023.416) * CFrame.Angles(0, math.rad(10), 0),
	Gold = Color3.fromHex("be8c3c"),      -- OBS_Trim_Gold
	Yellow = Color3.fromHex("ffd342"),    -- OBS_Gold_Trim (the ceiling's bright gold)
	Navy = Color3.fromHex("1b2440"),      -- OBS_Cloth_Navy
	-- the banner, in the frame: its plane (in front of pillar B's shaft, r ~0.93), half width, the swallowtail's notch and
	-- tips, the rod, the collar and the emblem's centre (heights)
	Banner = { Z = 2.25, Half = 0.72, Bottom = 7.7, Tip = 7.05, Top = 11.75, Collar = 11.95, Emblem = 10.15 },
	-- the book lamp (measured: OBS_Lantern_Glow_01's 100-triangle cell, 7933.24..7933.54, 4.27..4.57, 7999.29..7999.59),
	-- aimed at the middle of the open pages' top face. It casts no shadow (the glow box would hide it), so its Range stops
	-- short of the lectern's foot (3.6 below): further, it lights the foot and the floor through the lectern
	Lamp = { At = Vector3.new(7933.39, 4.42, 7999.44), Aim = Vector3.new(7933.44, 3.55, 7999.67),
		Color = Color3.fromRGB(255, 190, 110), Brightness = 3, Range = 3.1, Angle = 100 },
}

return function()
	local hub = workspace:FindFirstChild(Tuning.Hub)
	if not hub then return "no " .. Tuning.Hub end
	local old = hub:FindFirstChild(Tuning.Name)
	-- (2026-10-27) the imported Loadout book (hub/loadout_book_2026_10_27/import/install_book.lua) lives in this model and
	-- is not built here: it is carried over into the rebuilt one
	local book = old and old:FindFirstChild("LoadoutBook")
	if book then book.Parent = nil end
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = Tuning.Name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local L = Tuning.Frame
	local count = 0

	local function group(name, parent)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent or model
		return m
	end
	local function part(parent, name, size, cf, colour, props, class)
		local p = Instance.new(class or "Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, colour
		p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in pairs(props or {}) do p[k] = v end
		p.Parent = parent
		count += 1
		return p
	end
	-- Roblox cylinders lie along their own X: these turn one upright, or along the frame's Z
	local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
	local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)     -- (its +X end then points to -Z, the front)
	local function cyl(parent, name, len, dia, cf, colour, props)
		local p = part(parent, name, Vector3.new(len, dia, dia), cf, colour, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function ball(parent, name, dia, cf, colour, props)
		local p = part(parent, name, Vector3.one * dia, cf, colour, props)
		p.Shape = Enum.PartType.Ball
		return p
	end
	--- a square turned 45 degrees in its own XY plane (the hub's gold star-diamonds)
	local function diamond(parent, name, size, cf, colour)
		return part(parent, name, Vector3.new(size, size, 0.03), cf * CFrame.Angles(0, 0, math.rad(45)), colour)
	end
	--- a right triangle (a WedgePart) in `base`'s space: the right angle at R, one leg `a` long along u, the other `b`
	--- long along v (u, v unit and square). A wedge's right angle is at its local (y -h/2, z +d/2), legs along +Y and -Z.
	local function tri(parent, name, base, R, u, a, v, b, thick, colour)
		return part(parent, name, Vector3.new(thick, a, b), base * CFrame.fromMatrix(R + u * (a / 2) + v * (b / 2), v:Cross(u), u),
			colour, nil, "WedgePart")
	end

	----------------------------------------------------------------------------------------------------
	-- THE LOADOUT BANNER: on pillar B over the shelf, facing the altar (-Z); 1.44 wide, 7.05..11.83
	----------------------------------------------------------------------------------------------------
	local ban = group("LoadoutBanner")
	local B = Tuning.Banner
	local X, Y = Vector3.xAxis, Vector3.yAxis
	cyl(ban, "Collar", 0.22, 1.98, L * CFrame.new(0, B.Collar, 3.27) * UPRIGHT, Tuning.Gold)
	local face = L * CFrame.new(0, 0, B.Z)               -- the banner's plane; its front looks to -Z
	cyl(ban, "Rod", 1.96, 0.1, face * CFrame.new(0, B.Top + 0.03, -0.03), Tuning.Gold)
	for _, sx in ipairs({ -1, 1 }) do
		ball(ban, "RodEnd", 0.2, face * CFrame.new(sx * 1.03, B.Top + 0.03, -0.03), Tuning.Yellow)
	end
	part(ban, "Cloth", Vector3.new(2 * B.Half, B.Top - B.Bottom, 0.05), face * CFrame.new(0, (B.Top + B.Bottom) / 2, 0), Tuning.Navy)
	tri(ban, "TailL", face, Vector3.new(-B.Half, B.Bottom, 0), -Y, B.Bottom - B.Tip, X, B.Half, 0.05, Tuning.Navy)
	tri(ban, "TailR", face, Vector3.new(B.Half, B.Bottom, 0), -Y, B.Bottom - B.Tip, -X, B.Half, 0.05, Tuning.Navy)
	local FZ = -0.032                                     -- trim on the cloth's front face (it is at -0.025)
	--- a gold stripe on the cloth from (x1, y1) to (x2, y2)
	local function stripe(name, x1, y1, x2, y2, width, colour)
		local d = Vector2.new(x2 - x1, y2 - y1)
		return part(ban, name, Vector3.new(d.Magnitude, width, 0.014),
			face * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, FZ) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), colour)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(ban, "Edge", Vector3.new(0.07, B.Top - B.Tip, 0.014), face * CFrame.new(sx * (B.Half - 0.035), (B.Top + B.Tip) / 2, FZ), Tuning.Gold)
		ball(ban, "Tassel", 0.15, face * CFrame.new(sx * (B.Half - 0.03), B.Tip - 0.02, 0), Tuning.Yellow)
		-- along the swallowtail's slope (tip -> notch), set in onto the cloth by half its width
		local dx, dy = -sx * B.Half, B.Bottom - B.Tip
		local len = math.sqrt(dx * dx + dy * dy)
		local nx, ny = sx * dy / len * 0.035, -sx * dx / len * 0.035
		stripe("TailEdge", sx * B.Half + nx, B.Tip + ny, nx, B.Bottom + ny, 0.07, Tuning.Gold)
	end
	part(ban, "TopBand", Vector3.new(2 * B.Half, 0.08, 0.014), face * CFrame.new(0, B.Top - 0.3, FZ), Tuning.Gold)
	stripe("Chevron", -0.36, 9.2, 0.02, 8.86, 0.07, Tuning.Gold)
	stripe("Chevron", 0.36, 9.2, -0.02, 8.86, 0.07, Tuning.Gold)
	diamond(ban, "ChevronStar", 0.14, face * CFrame.new(0, 8.55, -0.04), Tuning.Yellow)
	-- the emblem: a gold ring (a gold disc under a navy one) and a four-point star of two crossed thin rhombi
	local E = face * CFrame.new(0, B.Emblem, 0)
	cyl(ban, "EmblemRing", 0.02, 1.08, E * CFrame.new(0, 0, -0.035) * ALONG_Z, Tuning.Yellow)
	cyl(ban, "EmblemField", 0.012, 0.82, E * CFrame.new(0, 0, -0.051) * ALONG_Z, Tuning.Navy)
	local at0 = Vector3.new(0, 0, -0.063)
	for _, q in ipairs({ { Y, X }, { Y, -X }, { -Y, X }, { -Y, -X } }) do
		tri(ban, "Star", E, at0, q[1], 0.33, q[2], 0.085, 0.012, Tuning.Yellow)
		tri(ban, "Star", E, at0, q[2], 0.33, q[1], 0.085, 0.012, Tuning.Yellow)
	end

	----------------------------------------------------------------------------------------------------
	-- THE BOOK LAMP'S LIGHT: a SpotLight in the desk lamp's glow, down onto the Loadout book
	----------------------------------------------------------------------------------------------------
	local Lp = Tuning.Lamp
	local lamp = part(model, "BookLampLight", Vector3.one * 0.2, CFrame.lookAt(Lp.At, Lp.Aim), Color3.new(1, 1, 1),
		{ Transparency = 1, CanQuery = false, CastShadow = false })
	local spot = Instance.new("SpotLight")
	spot.Name = "LampLight"
	spot.Face, spot.Angle, spot.Range, spot.Brightness = Enum.NormalId.Front, Lp.Angle, Lp.Range, Lp.Brightness
	spot.Color, spot.Shadows = Lp.Color, false
	spot.Parent = lamp

	if book then book.Parent = model end
	model.Parent = hub
	return string.format("built %s: %d parts%s", model:GetFullName(), count, book and " (the LoadoutBook model kept)" or "")
end
