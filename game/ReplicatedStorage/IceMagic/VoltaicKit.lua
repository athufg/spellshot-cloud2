--[[
	VoltaicKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/VoltaicKit

	The Voltaic kit's shared client helpers (2026-09-25): the one place ChainBoltFX, OverchargeFX, RailspikeFX, VoltOrbFX,
	VoltaicFX's Cascade and VoltaicClient get their colours, textures, kit meshes, placement maths, settings reads,
	clock, lights, Bloom kick, camera punch, hand points and the core+glow Beam chain from -- so six modules written in
	parallel draw as one kit. The API is fixed by D:\voltkit_scratch\castable\CONTRACT.md section 4; every name there is
	here with exactly that signature. A few optional trailing arguments and small extras are added (marked EXTRA); none
	changes what a contract call does.

	LOAD-TIME SAFETY. Requiring this module does nothing but GetService: no require, no WaitForChild, no LocalPlayer, no
	camera. The server may require it (VoltaicHandler reads clock / timeScale). Everything it needs is fetched LAZILY
	through Kit.libs(), which pcall-requires VFXLibrary, Viewmodel (client only), SpellshotSettings and SpellshotConfig
	with a timed WaitForChild the first time and a plain FindFirstChild on every later try; a missing module is warned
	about once and degrades -- nothing here errors because something optional is absent. Camera-dependent helpers read
	workspace.CurrentCamera when they are called.

	KIT MESHES. ReplicatedStorage.VoltaicMeshes.{VoltaicBolts, VoltaicTechniques, VoltaicCascade, VoltaicVoltOrb}, imported
	2026-09-25: Blender (x, y, z) -> Roblox (-x, z, y), so KIT_TURN is the identity. Every part's own rotation is identity
	and its PivotOffset.Position is the Blender ORIGIN relative to the bounding-box centre; the pivot's 90-degree X
	rotation is an importer artefact and is dropped. So a piece is placed by its pivot:
	    part.Size   = BaseSize * scale
	    part.CFrame = cf * KIT_TURN * CFrame.new(-BasePivot * scale)          (Kit.placeAt)
	which puts the authored origin on cf.Position with cf's rotation (a Cascade bolt's origin is at its TOP, 7.29 studs
	above its centre -- placed by centre it would hang that far low). Toon pieces are white SmoothPlastic with the tones
	in their vertex colours, asserted on every clone; they fade by shrinking or sinking, never by Transparency, and are
	never mirrored by a negative scale (the _L / _R variants are built). The Volt Orb's plates and core are the one
	exception: Neon, coloured at runtime, so Kit.orbMesh clones them without the toon assert.

	THE BEAM CHAIN (Kit.BeamChain) is the re-lit look Chain Bolt's bolts and Volt Orb's arcs and bolts are drawn with
	(VOLT_ORB_showcase.md "Beams, textured and continuous"; chain_bolt_bl.py / volt_orb_bl.py strip()): per segment a thin
	CORE Beam (VT_VoltOrb_Core: flat along its length, a soft-edged plateau across it, LightEmission 1 so it clips toward
	white-hot) and a wide GLOW Beam (VT_VoltOrb_Glow: bright centre, a long tail to nothing, LightEmission 0.55 -- half
	additive so it reads as light, half alpha so it stays yellow on a blue sky), both FaceCamera, TextureMode Stretch,
	Segments 4 (a tapered single-quad Beam maps its texture affinely and the glow's ridge bends into straight fins).
	Consecutive segments share their Attachments, all on one host Part. Where the polyline turns more than 60 degrees ON
	SCREEN the chain BREAKS: both ends at that joint narrow to 30 % and a small round glow cap (the implosion sprite,
	additive, 0.8 x the glow width) sits over the joint -- two square Beam ends otherwise leave a hard V-notch outside the
	turn. The glow Beams draw at 0.85 of the core's opacity (VoltaicFX's GLOW_ALPHA). On a flat-lit map every emission
	is x0.35 and every Brightness x0.7 (VFXLibrary's FLAT_EMISSION / FLAT_BRIGHTNESS rule for its own emitters).

	SETTINGS. Reduce Flashing (Kit.reduceFlashing) removes the Bloom kick here and the camera punch in the Viewmodel;
	everything else it calms is the caller's (bolts x0.85, flashes x0.6 ...). Thin enemy VFX (Kit.thin) is a flag the
	caller passes on. Flat-lit maps get no PointLights (Kit.light returns nil) and the tone-down above. Daylight halves
	every PointLight. All client timing is SHOT time: Kit.clock is real elapsed seconds MULTIPLIED by
	VFXLibrary.ShotTimeScale() (the house rule: AbilityFX's Aftershock clock, TerraFX, PyroFX), matching the server,
	which divides every delay by it -- so a 0.25 review runs everything at quarter speed together. The Bloom kick's
	decay ages the same way, so it is stretched in slow motion too. (CONTRACT.md section 4 wrote "/ timeScale()"; that
	ran the clients 16x ahead of the server at 0.25. The meaning -- seconds of shot time since T0 -- is unchanged.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Kit = {}

----------------------------------------------------------------------------------------------------
-- the palette and the textures
----------------------------------------------------------------------------------------------------
-- SpellshotConfig.Elements.Voltaic (Base / Light / Dark), plus the re-lit pieces' violets (VOLT_ORB_showcase.md).
Kit.COL = {
	Base = Color3.fromRGB(245, 199, 15),
	Light = Color3.fromRGB(255, 245, 115),
	Dark = Color3.fromRGB(74, 26, 140),
	Violet = Color3.fromRGB(30, 13, 54),        -- the Volt Orb plates' violet-black Neon; a cooled Chain Bolt chip
	Shadow = Color3.fromRGB(0x1E, 0x0A, 0x38),  -- #1E0A38
	Seam = Color3.fromRGB(0x9B, 0x5C, 0xF0),    -- #9B5CF0, the blue-violet crack light (red kept under blue: never pink)
	White = Color3.new(1, 1, 1),
}
local COL = Kit.COL

-- Blender (x, y, z) arrives as Roblox (-x, z, y) (measured on the import, 2026-09-25): no extra turn.
Kit.KIT_TURN = CFrame.new()

-- Uploaded 2026-09-25 (D:\voltkit_scratch\voltaic_image_ids.json; the six VT_VoltOrb_* equal VoltOrbKitData.Textures).
Kit.Tex = {
	Core = "rbxassetid://102210169003750",       -- VT_VoltOrb_Core: a Beam's hot core
	Glow = "rbxassetid://129508273132543",       -- VT_VoltOrb_Glow: a Beam's soft glow
	SeamHot = "rbxassetid://122249739400933",    -- VT_VoltOrb_SeamHot: the crack's scrolling hot spots (TextureMode Wrap)
	Facet = "rbxassetid://83418169017395",       -- VT_VoltOrb_Facet: a plate's face light
	Depth = "rbxassetid://116977746800786",      -- VT_VoltOrb_Depth: a plate's violet depths
	Scorch = "rbxassetid://89619194850911",      -- VT_VoltOrb_Scorch: the crater Decal
	StarCore = "rbxassetid://110430773837940",   -- VT_ChainBolt_StarCore: the relay star, core
	StarGlow = "rbxassetid://132652911289230",   -- VT_ChainBolt_StarGlow: the relay star, glow
	Implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",   -- = VFXLibrary Textures.Glow
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local Tex = Kit.Tex

-- VFXLibrary's flat-light tone-down for its emitters (VFXLibrary.lua, FLAT_EMISSION / FLAT_BRIGHTNESS)
local FLAT_EMISSION, FLAT_BRIGHTNESS = 0.35, 0.7

----------------------------------------------------------------------------------------------------
-- warnings and the lazy requires
----------------------------------------------------------------------------------------------------
local warned = {}

--- Warns once per `key` for the whole session.
function Kit.warnOnce(key, msg)
	key = tostring(key)
	if warned[key] then return end
	warned[key] = true
	msg = tostring(msg or key)
	if msg:sub(1, 1) ~= "[" then msg = "[VoltaicKit] " .. msg end
	warn(msg)
end

local LIB_WAIT = 5          -- seconds: the ONE timed wait a missing folder or module is given
local LIB_RETRY = 2         -- seconds between later FindFirstChild retries of something still missing
local lib = {}              -- key -> the required module table
local libRetry = {}         -- key -> os.clock() before which a failed lookup is not tried again
local libWaited = {}        -- key -> a timed wait has already been spent on it

local function child(parent, name, key)
	local c = parent:FindFirstChild(name)
	if c or libWaited[key] then return c end
	libWaited[key] = true
	return parent:WaitForChild(name, LIB_WAIT)
end

local function fetch(key, folderName, moduleName)
	local m = lib[key]
	if m then return m end
	if libRetry[key] and os.clock() < libRetry[key] then return nil end
	local folder = child(ReplicatedStorage, folderName, "folder:" .. folderName)
	local inst = folder and child(folder, moduleName, key)
	if inst and inst:IsA("ModuleScript") then
		local ok, res = pcall(require, inst)
		if ok and type(res) == "table" then
			lib[key] = res
			return res
		end
		Kit.warnOnce("lib:" .. key, ("[VoltaicKit] %s.%s failed to load: %s"):format(folderName, moduleName, tostring(res)))
	else
		Kit.warnOnce("lib:" .. key, ("[VoltaicKit] ReplicatedStorage.%s.%s is missing -- degrading without it")
			:format(folderName, moduleName))
	end
	libRetry[key] = os.clock() + LIB_RETRY
	return nil
end

--- VFXLibrary, Viewmodel|nil, Settings|nil, Config|nil -- lazy, cached, pcall-required. Viewmodel is client only.
--- VFXLibrary is nil only if the place itself is broken; every helper below copes with that.
function Kit.libs()
	local V = fetch("VFXLibrary", "IceMagic", "VFXLibrary")
	local VM = RunService:IsClient() and fetch("Viewmodel", "IceMagic", "Viewmodel") or nil
	local S = fetch("Settings", "Spellshot", "SpellshotSettings")
	local C = fetch("Config", "Spellshot", "SpellshotConfig")
	return V, VM, S, C
end

----------------------------------------------------------------------------------------------------
-- instances
----------------------------------------------------------------------------------------------------
local FX_FOLDER = "IceMagicFX"     -- = VFXLibrary.Config.FXFolderName: the folder VoltaicFX and VFXLibrary use

--- The shared FX folder (workspace.IceMagicFX), made if it is missing.
function Kit.fxFolder()
	local V = lib.VFXLibrary
	local name = (V and V.Config and V.Config.FXFolderName) or FX_FOLDER
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function inert(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	return p
end

--- An invisible, anchored, inert 0.2-stud Part in the FX folder: a host for attachments, emitters and lights.
function Kit.host(name, cf)
	local p = inert(Instance.new("Part"))
	p.Name = name or "VoltHost"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new()
	p.Parent = Kit.fxFolder()
	return p
end

--- An Attachment on `parent`, at `worldPos` (world space).
function Kit.attach(parent, worldPos)
	local a = Instance.new("Attachment")
	a.Parent = parent
	if typeof(worldPos) == "Vector3" then a.WorldPosition = worldPos end
	return a
end

----------------------------------------------------------------------------------------------------
-- kit meshes: clone, assert, place by pivot
----------------------------------------------------------------------------------------------------
local MESH_ROOT = "VoltaicMeshes"
local ORB_KIT = "VoltaicVoltOrb"
local WHITE = Color3.new(1, 1, 1)
-- part -> { Size = BaseSize, Pivot = BasePivot, Scale = the last scale written, S = it as a Vector3 }. Weak keys: a
-- destroyed piece is collected. The attributes carry the same numbers for anything cloned elsewhere.
local meta = setmetatable({}, { __mode = "k" })

local function findPiece(kit, name)
	local root = ReplicatedStorage:FindFirstChild(MESH_ROOT)
	local folder = root and root:FindFirstChild(kit)
	local src = folder and folder:FindFirstChild(name, true)
	if src and src:IsA("BasePart") then return src end
	Kit.warnOnce("mesh:" .. tostring(kit) .. "/" .. tostring(name),
		("[VoltaicKit] '%s' not found in ReplicatedStorage.%s.%s -- that piece is skipped"):format(
			tostring(name), MESH_ROOT, tostring(kit)))
	return nil
end

local function clonePiece(src)
	local c = src:Clone()
	if not c then
		Kit.warnOnce("clone:" .. src:GetFullName(), "[VoltaicKit] " .. src:GetFullName() .. " cannot be cloned (Archivable off)")
		return nil
	end
	local p = inert(c)
	local pivot = src.PivotOffset.Position
	p.PivotOffset = CFrame.new(pivot)            -- the importer's 90-degree pivot ROTATION means nothing: dropped
	p:SetAttribute("BaseSize", src.Size)
	p:SetAttribute("BasePivot", pivot)
	meta[p] = { Size = src.Size, Pivot = pivot, Scale = 1, S = Vector3.one }
	return p
end

--- A copy of one toon kit piece, not parented (the caller parents it), or nil (warned once) when it is not imported.
--- The toon rules are ASSERTED on the clone rather than trusted to the import: white, SmoothPlastic, opaque, no
--- reflectance, single-sided -- a tint, a Neon material or any transparency multiplies the baked tones away.
function Kit.kitMesh(kit, name)
	local src = findPiece(kit, name)
	if not src then return nil end
	local c = src.Color
	if c.R < 0.999 or c.G < 0.999 or c.B < 0.999 or src.Material ~= Enum.Material.SmoothPlastic or src.Transparency ~= 0
		or src.Reflectance ~= 0 or (src:IsA("MeshPart") and src.DoubleSided) then
		Kit.warnOnce("toon:" .. tostring(kit) .. "/" .. tostring(name),
			("[VoltaicKit] %s.%s breaks the toon rules in the import (fixed on the clone)"):format(tostring(kit), tostring(name)))
	end
	local p = clonePiece(src)
	if not p then return nil end
	p.Color = WHITE
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency, p.Reflectance = 0, 0
	if p:IsA("MeshPart") and p.DoubleSided then
		local ok = pcall(function() p.DoubleSided = false end)
		if not ok then Kit.warnOnce("doublesided", "[VoltaicKit] MeshPart.DoubleSided is not writable at runtime") end
	end
	return p
end

--- A copy of one Volt Orb piece (VO_Plate_01..20, VO_Core, VO_Kernel) WITHOUT the toon assert: the orb is Neon and is
--- coloured at runtime by the caller. Inert and anchored, BaseSize / BasePivot set, not parented.
function Kit.orbMesh(name)
	local src = findPiece(ORB_KIT, name)
	return src and clonePiece(src) or nil
end

local function baseOf(part)
	local m = meta[part]
	if not m then
		local size, pivot = part:GetAttribute("BaseSize"), part:GetAttribute("BasePivot")
		m = { Size = typeof(size) == "Vector3" and size or part.Size,
			Pivot = typeof(pivot) == "Vector3" and pivot or Vector3.zero, Scale = nil, S = Vector3.one }
		meta[part] = m
	end
	return m
end

-- Size (and the pivot offset, so GetPivot() stays the authored origin) follow `scale`; written only when it changes.
local function rescale(part, m, scale)
	if m.Scale == scale then return end
	local s = typeof(scale) == "Vector3" and scale or Vector3.one * (tonumber(scale) or 1)
	m.Scale, m.S = scale, s
	part.Size = m.Size * s
	part.PivotOffset = CFrame.new(m.Pivot * s)
end

--- Places a kit piece by its PIVOT (its Blender origin): Size = BaseSize * scale, and the origin lands on cf.Position
--- with cf's rotation. `scale` is a number or a Vector3 (per axis), default 1. THIS is how every kit piece is placed.
function Kit.placeAt(part, cf, scale)
	if not (part and typeof(cf) == "CFrame") then return end
	local m = baseOf(part)
	rescale(part, m, scale or 1)
	part.CFrame = cf * Kit.KIT_TURN * CFrame.new(-(m.Pivot * m.S))
end

--- Places a kit piece by its bounding-box CENTRE: Size = BaseSize * scale, CFrame = cf.
function Kit.placeCentre(part, cf, scale)
	if not (part and typeof(cf) == "CFrame") then return end
	rescale(part, baseOf(part), scale or 1)
	part.CFrame = cf
end

----------------------------------------------------------------------------------------------------
-- camera-facing frames
----------------------------------------------------------------------------------------------------
--- A camera-facing frame at `pos`: the piece's readable face (-Z) toward the camera, its X level, then rolled.
function Kit.billboard(pos, roll)
	local cam = workspace.CurrentCamera
	if not cam then return CFrame.new(pos) * CFrame.Angles(0, 0, roll or 0) end
	local away = pos - cam.CFrame.Position
	away = away.Magnitude > 1e-4 and away.Unit or cam.CFrame.LookVector
	local vX = Vector3.yAxis:Cross(away)
	vX = vX.Magnitude > 1e-4 and vX.Unit or Vector3.xAxis
	return CFrame.fromMatrix(pos, vX, away:Cross(vX).Unit) * CFrame.Angles(0, 0, roll or 0)
end

--- The stretch frame for a piece laid from `a` to `b`: at the midpoint, +X along a -> b, the face (-Z) turned to the
--- camera (the plate's plane holds the line and faces the lens as squarely as the line allows).
function Kit.stretchFrame(a, b)
	local cam = workspace.CurrentCamera
	local mid = (a + b) / 2
	local d = b - a
	local dir
	if d.Magnitude > 1e-4 then
		dir = d.Unit
	else
		dir = cam and cam.CFrame.RightVector or Vector3.xAxis
	end
	local away = cam and (mid - cam.CFrame.Position) or Vector3.new(0, 0, -1)
	away -= dir * away:Dot(dir)
	if away.Magnitude < 1e-4 then
		away = dir:Cross(Vector3.yAxis)
		if away.Magnitude < 1e-4 then away = dir:Cross(Vector3.xAxis) end
	end
	return CFrame.fromMatrix(mid, dir, away.Unit:Cross(dir).Unit)
end

----------------------------------------------------------------------------------------------------
-- settings, light, time
----------------------------------------------------------------------------------------------------
--- Is this the local player's own character? (false on the server)
function Kit.isOwn(character)
	local lp = Players.LocalPlayer
	return character ~= nil and lp ~= nil and lp.Character == character
end

--- (2026-10-19, audit P5F-06) An ENEMY's cast -- what Reduce Enemy VFX thins: VFXLibrary.IsEnemy (not yours, not a
--- teammate's in your match, not an ally dummy's), or "not yours" when VFXLibrary cannot be read.
function Kit.isEnemy(character)
	local V = Kit.libs()
	if V and type(V.IsEnemy) == "function" then
		local ok, v = pcall(V.IsEnemy, character)
		if ok then return v == true end
	end
	return not Kit.isOwn(character)
end

--- Draw this cast thin? An enemy's cast with Reduce Enemy VFX on, or Graphics Quality's density under 0.6.
--- (2026-10-19, audit P5D-07) For a module's OWN geometry tiers only: VFXLibrary's `thin` argument means "an enemy's
--- cast" (it applies both settings itself), so pass it `Kit.isEnemy(character)`, never this.
function Kit.thin(character)
	local _, _, S = Kit.libs()
	if not S then return false end
	if (tonumber(S.EffectDensity) or 1) < 0.6 then return true end
	-- (2026-10-19, audit P5F-06) was `not Kit.isOwn(character)`: a teammate's cast thinned as an enemy's
	return S.ThinEnemyVFX == true and Kit.isEnemy(character)
end

--- The Reduce Flashing setting (false when Settings cannot be read).
function Kit.reduceFlashing()
	local _, _, S = Kit.libs()
	if not (S and S.Get) then return false end
	local ok, v = pcall(S.Get, "ReduceFlashing")
	return ok and v == true
end

--- HubClient's flat-light profile (no sun, a white Ambient): no PointLights, toned-down additive glow.
function Kit.flatLit()
	local V = Kit.libs()
	if V and V.FlatLit then
		local ok, v = pcall(V.FlatLit)
		if ok then return v == true end
	end
	local a = Lighting.Ambient
	return Lighting.Brightness < 0.05 and a.R + a.G + a.B > 2.7
end

--- A lit map in daytime: every PointLight at half (the Training Grounds' floor blew out at full).
function Kit.daylight()
	if Kit.flatLit() then return false end
	local t = Lighting.ClockTime
	return t >= 7 and t <= 17
end

--- EXTRA: the factor a light's Brightness should carry right now -- 0 flat-lit, 0.5 in daylight, else 1. For a caller
--- that animates a Kit.light's Brightness after making it.
function Kit.lightK()
	if Kit.flatLit() then return 0 end
	return Kit.daylight() and 0.5 or 1
end

function Kit.serverNow()
	return workspace:GetServerTimeNow()
end

--- VFXLibrary.ShotTimeScale() (the slow-motion review's factor), or 1.
function Kit.timeScale()
	local V = Kit.libs()
	if V and V.ShotTimeScale then
		local ok, v = pcall(V.ShotTimeScale)
		if ok and type(v) == "number" and v > 0 then return v end
		return 1
	end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local v = ice and ice:GetAttribute("ShotTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

--- Seconds of SHOT time since the server time T0 (a broadcast's T0): real elapsed x timeScale(), the house rule, so
--- a 0.25 review reads a quarter of the real seconds (the server divides its delays by the same factor). 0 when T0
--- is not a number.
function Kit.clock(T0)
	T0 = tonumber(T0)
	if not T0 then return 0 end
	return (Kit.serverNow() - T0) * Kit.timeScale()
end

--- A shadowless PointLight on `parent` (a Part or an Attachment), or nil on a flat-lit map. Halved in daylight.
function Kit.light(parent, brightness, range, color)
	if not parent or Kit.flatLit() then return nil end
	local l = Instance.new("PointLight")
	l.Name = "VoltLight"
	l.Shadows = false
	l.Brightness = math.max(0, tonumber(brightness) or 1) * (Kit.daylight() and 0.5 or 1)
	l.Range = math.clamp(tonumber(range) or 8, 0, 60)
	l.Color = typeof(color) == "Color3" and color or COL.Light
	l.Parent = parent
	return l
end

----------------------------------------------------------------------------------------------------
-- the first-person viewmodel
----------------------------------------------------------------------------------------------------
local function firstPerson(side)
	local _, VM = Kit.libs()
	if not (VM and VM.GetFistCFrame) then return VM ~= nil end
	local ok, cf = pcall(VM.GetFistCFrame, side == "L" and "L" or "R")
	return ok and cf ~= nil
end

--- EXTRA: is the first-person viewmodel on screen? (TerraFX's bloomKick test: a fist frame exists only in first person
--- with the rig built.)
function Kit.viewmodelUp()
	return RunService:IsClient() and (firstPerson("R") or firstPerson("L"))
end

--- A camera punch for the local player, fading to nothing at `reach` studs from `pos` -- through Viewmodel.Punch, so the
--- Camera Shake setting scales it and Reduce Flashing removes it.
function Kit.punchNear(pos, amount, reach)
	if typeof(pos) ~= "Vector3" or not RunService:IsClient() then return end
	local _, VM = Kit.libs()
	local cam = workspace.CurrentCamera
	if not (VM and VM.Punch and cam) then return end
	reach = tonumber(reach) or 0
	local d = (cam.CFrame.Position - pos).Magnitude
	if reach <= 0 or d >= reach then return end
	pcall(VM.Punch, (tonumber(amount) or 0) * (1 - d / reach))
end

--- The first-person arm's CastPoint Attachment (Viewmodel.lua buildArm: SpellshotViewmodel.ArmR / ArmL, re-aimed every
--- frame; there is no getter). nil in the third-person view -- the rig is still posed there, in mid-air before the lens --
--- and when the rig is not built. Re-fetch after a Viewmodel rebuild (a respawn makes new arms).
function Kit.castPoint(side)
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("SpellshotViewmodel")
	local arm = vm and vm:FindFirstChild(side == "L" and "ArmL" or "ArmR")
	local cp = arm and arm:FindFirstChild("CastPoint", true)
	if not (cp and cp:IsA("Attachment")) then return nil end
	if not firstPerson(side) then return nil end
	return cp
end

local GRIP = {
	R = { Name = "RightGripAttachment", Parts = { "RightHand", "Right Arm" }, X = 1 },
	L = { Name = "LeftGripAttachment", Parts = { "LeftHand", "Left Arm" }, X = -1 },
}

local function gripOf(character, side)
	local g = GRIP[side]
	for _, partName in ipairs(g.Parts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local a = part:FindFirstChild(g.Name)
			if a and a:IsA("Attachment") then return a end
			local own = part:FindFirstChild("Voltaic" .. g.Name)
			if own then return own end
			own = Instance.new("Attachment")                 -- the palm end of the hand / arm
			own.Name = "Voltaic" .. g.Name
			own.Position = Vector3.new(0, -part.Size.Y * 0.5, 0)
			own.Parent = part
			return own
		end
	end
	-- no hands at all (a dummy of plain parts): a point off the root at hand height
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not (root and root:IsA("BasePart")) then return nil end
	local own = root:FindFirstChild("VoltaicHand" .. side)
	if not own then
		own = Instance.new("Attachment")
		own.Name = "VoltaicHand" .. side
		own.Position = Vector3.new(1.2 * g.X, -0.4, -0.6)
		own.Parent = root
	end
	return own
end

--- { R = Attachment, L = Attachment }: the character's grip attachments (RightGripAttachment / LeftGripAttachment on
--- R15 hands or R6 arms), with a fallback attachment made once on the hand, arm or root. Empty for no character.
function Kit.hands(character)
	local out = {}
	if typeof(character) ~= "Instance" then return out end
	out.R = gripOf(character, "R")
	out.L = gripOf(character, "L")
	return out
end

--- Where a cast leaves the caster: the local player's first-person muzzle (Viewmodel.GetMuzzleCFrame), else the hand's
--- grip -- what every other client sees.
function Kit.muzzle(character, side)
	side = side == "L" and "L" or "R"
	if Kit.isOwn(character) and firstPerson(side) then
		local _, VM = Kit.libs()
		if VM and VM.GetMuzzleCFrame then
			local ok, cf = pcall(VM.GetMuzzleCFrame, side)
			if ok and typeof(cf) == "CFrame" then return cf.Position end
		end
	end
	if typeof(character) == "Instance" then
		local h = gripOf(character, side)
		if h then return h.WorldPosition end
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then return head.Position end
	end
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

----------------------------------------------------------------------------------------------------
-- the Bloom kick
----------------------------------------------------------------------------------------------------
-- One kick at a time on the place's own BloomEffect: overlapping kicks take the max, and the effect is put back
-- exactly as it was. If something else (a map's lighting profile) writes the effect mid-kick, its value becomes the
-- new base. SKIPPED under Reduce Flashing and while the first-person viewmodel is up (TerraFX.lua bloomKick: the kick
-- blooms the arms white long before it does anything to a hit twenty studs out -- the Play test, 2026-09-23).
local bloom = { Fx = nil, Kicks = {}, Conn = nil, Base = {}, Wrote = {}, Uses = {} }
local BLOOM_PROPS = { "Intensity", "Size", "Threshold" }
local MAX_KICKS = 8

local function bloomRestore()
	local fx = bloom.Fx
	if fx and fx.Parent then
		for _, prop in ipairs(BLOOM_PROPS) do
			if bloom.Uses[prop] and bloom.Base[prop] ~= nil then fx[prop] = bloom.Base[prop] end
		end
	end
	table.clear(bloom.Kicks)
	table.clear(bloom.Wrote)
	table.clear(bloom.Uses)
end

local function bloomStop()
	bloomRestore()
	if bloom.Conn then
		bloom.Conn:Disconnect()
		bloom.Conn = nil
	end
	bloom.Fx = nil
end

local function bloomCapture(fx)
	bloom.Fx = fx
	for _, prop in ipairs(BLOOM_PROPS) do bloom.Base[prop] = fx[prop] end
	table.clear(bloom.Wrote)
end

local function bloomStep()
	local fx = bloom.Fx
	if not (fx and fx.Parent) then
		bloomStop()
		return
	end
	local now, ts = os.clock(), Kit.timeScale()
	local add = { Intensity = 0, Size = 0, Threshold = 0 }
	local kicks = bloom.Kicks
	for i = #kicks, 1, -1 do
		local k = kicks[i]
		local age = (now - k.Born) * ts                   -- shot seconds: a 0.25 review decays 4x slower
		local e = age <= k.Hold and 1 or math.exp(-(age - k.Hold) / k.Tau)
		if e < 0.01 then
			table.remove(kicks, i)
		else
			add.Intensity = math.max(add.Intensity, k.Intensity * e)
			add.Size = math.max(add.Size, k.Size * e)
			add.Threshold = math.min(add.Threshold, k.Threshold * e)
		end
	end
	if #kicks == 0 then
		bloomStop()
		return
	end
	for _, prop in ipairs(BLOOM_PROPS) do
		if bloom.Uses[prop] then
			local wrote = bloom.Wrote[prop]
			if wrote ~= nil and math.abs(fx[prop] - wrote) > 1e-3 then bloom.Base[prop] = fx[prop] end
			fx[prop] = bloom.Base[prop] + add[prop]
			bloom.Wrote[prop] = fx[prop]              -- read back: the engine clamps (Intensity, Threshold, Size)
		end
	end
end

--- A local Bloom kick: Intensity + `add` and Size + `sizeAdd`, held `hold` seconds (EXTRA, default one 60 Hz frame),
--- then decaying with time constant `tau` (shot time). EXTRA `thresholdAdd` (<= 0) drops the Threshold as well (Volt
--- Orb's burst). Skipped under Reduce Flashing, while the first-person viewmodel is up (EXTRA `anyView` = true: a
--- caller that fades its own kick out near the viewer asks through that rule -- Cascade's THE FLASH and its
--- set-flash, CascadeFX), on the server, and when the place has no enabled BloomEffect.
function Kit.bloomPulse(add, sizeAdd, tau, hold, thresholdAdd, anyView)
	if not RunService:IsClient() then return end
	if Kit.reduceFlashing() or (Kit.viewmodelUp() and anyView ~= true) then return end
	local fx = Lighting:FindFirstChildOfClass("BloomEffect")
	if not (fx and fx.Enabled) then return end
	add, sizeAdd = math.max(0, tonumber(add) or 0), math.max(0, tonumber(sizeAdd) or 0)
	thresholdAdd = math.min(0, tonumber(thresholdAdd) or 0)
	if add <= 0 and sizeAdd <= 0 and thresholdAdd >= 0 then return end
	if bloom.Fx ~= fx or #bloom.Kicks == 0 then
		if bloom.Fx and bloom.Fx ~= fx then bloomRestore() end
		bloomCapture(fx)
	end
	if add > 0 then bloom.Uses.Intensity = true end
	if sizeAdd > 0 then bloom.Uses.Size = true end
	if thresholdAdd < 0 then bloom.Uses.Threshold = true end
	if #bloom.Kicks >= MAX_KICKS then table.remove(bloom.Kicks, 1) end
	table.insert(bloom.Kicks, { Born = os.clock(), Intensity = add, Size = sizeAdd, Threshold = thresholdAdd,
		Tau = math.max(1e-3, tonumber(tau) or 0.06), Hold = math.max(0, tonumber(hold) or 1 / 60) })
	if not bloom.Conn then
		bloom.Conn = RunService.RenderStepped:Connect(function()
			local ok, err = pcall(bloomStep)
			if not ok then
				Kit.warnOnce("bloom", "[VoltaicKit] Bloom kick stopped: " .. tostring(err))
				pcall(bloomStop)
			end
		end)
	end
	pcall(bloomStep)                                      -- on this frame, not the next
end

----------------------------------------------------------------------------------------------------
-- lightning's shape
----------------------------------------------------------------------------------------------------
local function perp(d, rng)
	local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local p = r - d * r:Dot(d)
	if p.Magnitude > 1e-4 then return p.Unit end
	p = d:Cross(Vector3.yAxis)
	if p.Magnitude < 1e-4 then p = d:Cross(Vector3.xAxis) end
	return p.Unit
end

--- Midpoint displacement from `a` to `b`: `depth` halvings (2^depth segments), each midpoint kicked sideways by
--- 0.35..1 x `amp`, the kick falling to `kick` (default 0.6) of itself per level -- big jogs with finer crackle inside
--- them (chain_bolt_bl.py / volt_orb_bl.py jag()). Returns the polyline { a, ..., b }. `rng` is a Random.
function Kit.jag(a, b, depth, amp, rng, kick)
	rng = rng or Random.new()
	kick = tonumber(kick) or 0.6
	depth = math.clamp(math.floor(tonumber(depth) or 0), 0, 8)
	local out = { a }
	local function sub(p, q, dep, am)
		if dep == 0 then
			out[#out + 1] = q
			return
		end
		local d = q - p
		local len = d.Magnitude
		local m = (p + q) / 2
		if len > 1e-4 then m += perp(d / len, rng) * rng:NextNumber(0.35, 1) * am end
		sub(p, m, dep - 1, am * kick)
		sub(m, q, dep - 1, am * kick)
	end
	sub(a, b, depth, tonumber(amp) or 0)
	return out
end

----------------------------------------------------------------------------------------------------
-- THE BEAM CHAIN: core + glow textured Beams along a polyline (see the header)
----------------------------------------------------------------------------------------------------
local BeamChain = {}
BeamChain.__index = BeamChain
Kit.BeamChain = BeamChain

-- Every field a `look` table may override.
local LOOK = {
	CoreTexture = Tex.Core, GlowTexture = Tex.Glow,
	CoreEmission = 1, GlowEmission = 0.55,      -- LightEmission: the core additive, the glow half and half
	GlowAlpha = 0.85,                           -- the glow's opacity at the core's full strength (VoltaicFX GLOW_ALPHA)
	CoreWidth = 0.12, GlowWidth = 1.2,          -- the widths Set uses when it is given none
	TextureMode = Enum.TextureMode.Stretch, TextureLength = 1, TextureSpeed = 0,
	Segments = 4, FaceCamera = true,
	CoreZ = 0.02, GlowZ = 0,                    -- ZOffset: the core sorts in front of its own glow
	Break = 60,                                 -- degrees on screen: a sharper joint breaks (false / 0: never)
	BreakWidth = 0.3,                           -- both ends' share of their width at a broken joint
	Caps = true, CapTexture = Tex.Implosion,    -- the round glow over a broken joint...
	CapScale = 0.8, CapBright = 0.6, CapEmission = 1, CapMin = 0.05,   -- ...0.8 x the glow width, 0.6 x its Brightness
	FlatTone = true,                            -- on a flat-lit map: emission x0.35, Brightness x0.7
	Name = "VoltBeamChain",
}

local function textureMode(v)
	if typeof(v) == "EnumItem" then return v end
	local ok, e = pcall(function() return Enum.TextureMode[v] end)
	return ok and e or Enum.TextureMode.Stretch
end

local function newBeam(a0, a1, tex, emission, zoff, L, parent)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = L.FaceCamera
	b.Segments = L.Segments
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.Texture = tex
	b.TextureMode = L.TextureMode
	b.TextureLength = L.TextureLength
	b.TextureSpeed = L.TextureSpeed
	b.LightEmission, b.LightInfluence = emission, 0
	b.ZOffset = zoff
	b.Width0, b.Width1 = 0, 0
	b.Enabled = false
	b.Parent = parent
	return b
end

--- A chain of up to `maxSegments` segments (maxSegments + 1 points) under `parent` (default the FX folder). `look`
--- overrides any field of LOOK above. Destroy it when done (or destroy its parent).
function BeamChain.new(parent, maxSegments, look)
	local n = math.clamp(math.floor(tonumber(maxSegments) or 1), 1, 256)
	local L = table.clone(LOOK)
	if type(look) == "table" then
		for k, v in pairs(look) do L[k] = v end
	end
	L.TextureMode = textureMode(L.TextureMode)
	L.Segments = math.clamp(math.floor(tonumber(L.Segments) or 4), 1, 100)
	L.FaceCamera = L.FaceCamera ~= false
	local flat = L.FlatTone ~= false and Kit.flatLit()
	local host = inert(Instance.new("Part"))
	host.Name = tostring(L.Name)
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Transparency = 1
	host.CFrame = CFrame.new()          -- unrotated; Set moves it onto the chain (Origin) when the chain is far from it
	local self = setmetatable({
		Host = host, Origin = Vector3.zero, Atts = {}, Core = {}, Glow = {}, CapPool = {}, Max = n, N = 0, Shown = 0,
		CapsShown = 0,
		L = L, EmK = flat and FLAT_EMISSION or 1, BrK = flat and FLAT_BRIGHTNESS or 1,
		Visible = true, Dead = false, Brk = {}, Sides = {},
		Lk = { cc = nil, gc = nil, cb = -1, gb = -1, a = -1, csq = nil, gsq = nil, ct = nil, gt = nil, capB = 0 },
	}, BeamChain)
	for i = 1, n + 1 do
		local a = Instance.new("Attachment")
		a.Name = "P" .. i
		a.Parent = host
		self.Atts[i] = a
	end
	for i = 1, n do
		self.Glow[i] = newBeam(self.Atts[i], self.Atts[i + 1], L.GlowTexture, L.GlowEmission * self.EmK, L.GlowZ, L, host)
		self.Core[i] = newBeam(self.Atts[i], self.Atts[i + 1], L.CoreTexture, L.CoreEmission * self.EmK, L.CoreZ, L, host)
	end
	self:Look(COL.Light, COL.Base, 1, 1, 1)
	host.Parent = parent or Kit.fxFolder()
	return self
end

local function widthAt(w, i, default)
	local t = type(w)
	if t == "number" then return w end
	if t == "table" then return tonumber(w[i]) or tonumber(w[#w]) or default end
	return default
end

-- The cap pool is made lazily: most chains never break.
local function capAt(self, k)
	local cap = self.CapPool[k]
	if cap then return cap end
	local L, lk = self.L, self.Lk
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "Cap" .. k .. "a", "Cap" .. k .. "b"
	a0.Parent, a1.Parent = self.Host, self.Host
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.Texture = L.CapTexture
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.LightEmission, b.LightInfluence = L.CapEmission * self.EmK, 0
	b.ZOffset = L.CoreZ
	b.Color = lk.gsq or ColorSequence.new(COL.Base)
	b.Transparency = lk.gt or NumberSequence.new(0)
	b.Brightness = lk.capB
	b.Enabled = false
	b.Parent = self.Host
	cap = { A0 = a0, A1 = a1, Beam = b }
	self.CapPool[k] = cap
	return cap
end

--- Lays the chain along `points` (world Vector3s; up to maxSegments + 1 are used) with per-POINT widths: `coreWidths`
--- and `glowWidths` are each a number (every point) or a list (point i's width; a short list repeats its last). Segment
--- i runs from point i (Width0) to point i+1 (Width1); segments past the last point are disabled.
function BeamChain:Set(points, coreWidths, glowWidths)
	if self.Dead then return end
	local np = 0
	if type(points) == "table" then
		local lim = math.min(#points, self.Max + 1)
		while np < lim and typeof(points[np + 1]) == "Vector3" do np += 1 end
	end
	if np < 2 then
		self:Hide()
		return
	end
	if not self.Host.Parent then return end          -- its parent was destroyed under it: nothing left to draw
	local L, atts = self.L, self.Atts
	-- the host rides along with the chain (unrotated), so every Attachment sits near its part: Position = world - Origin
	local o = self.Origin
	if (points[1] - o).Magnitude > 128 then
		o = points[1]
		self.Origin = o
		self.Host.CFrame = CFrame.new(o)
	end
	for i = 1, np do atts[i].Position = points[i] - o end
	local segs = np - 1

	-- where the chain breaks: the turn between two segments' ON-SCREEN sides (the segment crossed with the view ray)
	local brk, sides = self.Brk, self.Sides
	table.clear(brk)
	local limit = tonumber(L.Break) or 0
	if limit > 0 and segs >= 2 then
		local cosLimit = math.cos(math.rad(limit))
		local cam = workspace.CurrentCamera
		local eye = cam and cam.CFrame.Position
		for i = 1, segs do
			local p, q = points[i], points[i + 1]
			local d = q - p
			local sd
			if d.Magnitude > 1e-6 then
				if eye then
					sd = d:Cross(eye - (p + q) / 2)
				else
					sd = d
				end
			end
			sides[i] = (sd and sd.Magnitude > 1e-6) and sd.Unit or false
		end
		for j = 2, segs do
			local s0, s1 = sides[j - 1], sides[j]
			if s0 and s1 and s0:Dot(s1) < cosLimit then brk[j] = true end
		end
	end

	local bw = tonumber(L.BreakWidth) or 0.3
	local dc, dg = L.CoreWidth, L.GlowWidth
	local on = self.Visible
	for i = 1, segs do
		local c, g = self.Core[i], self.Glow[i]
		local c0, c1 = widthAt(coreWidths, i, dc), widthAt(coreWidths, i + 1, dc)
		local g0, g1 = widthAt(glowWidths, i, dg), widthAt(glowWidths, i + 1, dg)
		if brk[i] then c0, g0 = c0 * bw, g0 * bw end
		if brk[i + 1] then c1, g1 = c1 * bw, g1 * bw end
		c.Width0, c.Width1 = c0, c1
		g.Width0, g.Width1 = g0, g1
		if c.Enabled ~= on then c.Enabled = on end
		if g.Enabled ~= on then g.Enabled = on end
	end
	for i = segs + 1, self.Shown do
		self.Core[i].Enabled = false
		self.Glow[i].Enabled = false
	end
	self.Shown, self.N = segs, np

	-- the round caps over the broken joints
	local used = 0
	if L.Caps and on and next(brk) then
		local cam = workspace.CurrentCamera
		local right = cam and cam.CFrame.RightVector or Vector3.xAxis
		local capMin = tonumber(L.CapMin) or 0.05
		for j = 2, segs do
			if brk[j] then
				local w = widthAt(glowWidths, j, dg)
				if w > capMin then
					used += 1
					local cap = capAt(self, used)
					local size = w * L.CapScale
					local q = points[j] - o
					cap.A0.Position = q - right * (size / 2)
					cap.A1.Position = q + right * (size / 2)
					cap.Beam.Width0, cap.Beam.Width1 = size, size
					if not cap.Beam.Enabled then cap.Beam.Enabled = true end
				end
			end
		end
	end
	for k = used + 1, self.CapsShown do
		local cap = self.CapPool[k]
		if cap then cap.Beam.Enabled = false end
	end
	self.CapsShown = used
end

--- The chain's look: core and glow colours, their Brightness, and `alpha` (1 = full, 0 = gone; the glow draws at
--- GlowAlpha of it). Cheap to call every frame: nothing is written unless it changed.
function BeamChain:Look(coreColor, glowColor, coreBright, glowBright, alpha)
	if self.Dead then return end
	local L, lk = self.L, self.Lk
	coreColor = typeof(coreColor) == "Color3" and coreColor or COL.Light
	glowColor = typeof(glowColor) == "Color3" and glowColor or COL.Base
	coreBright = math.max(0, tonumber(coreBright) or 1) * self.BrK
	glowBright = math.max(0, tonumber(glowBright) or 1) * self.BrK
	alpha = math.clamp(tonumber(alpha) or 1, 0, 1)
	local newC, newG = lk.cc ~= coreColor, lk.gc ~= glowColor
	local newCB, newGB = math.abs(lk.cb - coreBright) > 0.005, math.abs(lk.gb - glowBright) > 0.005
	local newA = math.abs(lk.a - alpha) > 0.002
	if not (newC or newG or newCB or newGB or newA) then return end
	if newC then lk.cc, lk.csq = coreColor, ColorSequence.new(coreColor) end
	if newG then lk.gc, lk.gsq = glowColor, ColorSequence.new(glowColor) end
	if newA then
		lk.a = alpha
		lk.ct = NumberSequence.new(1 - alpha)
		lk.gt = NumberSequence.new(1 - alpha * (tonumber(L.GlowAlpha) or 0.85))
	end
	lk.cb, lk.gb = coreBright, glowBright
	lk.capB = glowBright * (tonumber(L.CapBright) or 0.6)
	for i = 1, self.Max do
		local c, g = self.Core[i], self.Glow[i]
		if newC then c.Color = lk.csq end
		if newG then g.Color = lk.gsq end
		if newA then
			c.Transparency = lk.ct
			g.Transparency = lk.gt
		end
		if newCB then c.Brightness = coreBright end
		if newGB then g.Brightness = glowBright end
	end
	for _, cap in pairs(self.CapPool) do
		local b = cap.Beam
		if newG then b.Color = lk.gsq end
		if newA then b.Transparency = lk.gt end
		if newGB then b.Brightness = lk.capB end
	end
	-- fully faded: disable instead of drawing at Transparency 1 (and back on when it returns)
	local vis = alpha > 0.003
	if vis ~= self.Visible then
		self.Visible = vis
		for i = 1, self.Shown do
			self.Core[i].Enabled = vis
			self.Glow[i].Enabled = vis
		end
		if not vis then
			for k = 1, self.CapsShown do
				local cap = self.CapPool[k]
				if cap then cap.Beam.Enabled = false end
			end
			self.CapsShown = 0
		end
	end
end

--- Hides every segment and cap (the chain stays, ready for the next Set).
function BeamChain:Hide()
	if self.Dead then return end
	for i = 1, self.Shown do
		self.Core[i].Enabled = false
		self.Glow[i].Enabled = false
	end
	for k = 1, self.CapsShown do
		local cap = self.CapPool[k]
		if cap then cap.Beam.Enabled = false end
	end
	self.Shown, self.CapsShown, self.N = 0, 0, 0
end

--- Destroys the chain and everything it made. Safe to call twice.
function BeamChain:Destroy()
	if self.Dead then return end
	self.Dead = true
	if self.Host then self.Host:Destroy() end
	table.clear(self.Atts)
	table.clear(self.Core)
	table.clear(self.Glow)
	table.clear(self.CapPool)
end

return Kit
