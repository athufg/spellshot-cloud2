--[[
	AquaFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/AquaFX

	Aqua's visuals, v2 (2026-09-25): built on the AQUA KIT -- detailed Blender meshes (vmarm/aqua_kit, piece_<id>.py,
	merged by build_aquakit.py) in ReplicatedStorage.IceMagicMeshes.AquaKit. The Studio-Part blockout this replaces was
	rejected by the owner as blocky ("supposed to be detailed and done in blender").

	TRACK 1, the build prompt's recipe (the same construction as Terra's Boulder Shot and Cryo's kit):
	  solid  opaque MeshParts, SmoothPlastic, WHITE Part colour over baked vertex colour (tone + AO), CastShadow on
	  glass  Leviathan's Maw's wave-walls and the roof they curl into ONLY: the same, see-through at WallTransparency
	         (SmoothPlastic, never Glass: Glass hides everything transparent behind it), CastShadow off (a see-through
	         part still casts a solid shadow)
	  line   the TIDELINE: baked white, drawn Neon #3CE8E0 while its water moves and dark (SmoothPlastic) the instant it
	         stops; the wet ground's edge carries a DIM one
	Every kit part carries its manifest data as attributes (studio_place_kit.luau): OriginFromPivot (where the Blender
	origin sits from the MeshPart's centre, in its own axes), TemplateSize, and P_<name> points (hinge, muzzle, drips).
	place() puts a part's ORIGIN at a CFrame, at a scale -- that is the only way anything here is positioned.

	Solid-to-the-body pieces (Twin Tide's walls, the tank's walls and roof) are each client's own local copy and are
	blocked by INVISIBLE box colliders (CanCollide, NoWallRun -- MovementController will not wall-run them), never by
	collision on the meshes themselves (a precise hull on a big mesh froze Studio once). Everything lives in the FX
	folder, so shots and the crosshair pass through it: Bulwark Wall stays the one sightline block (Pillar 4).
	A missing kit piece is skipped with one warning: gameplay never waits on a look.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local A = require(iceFolder:WaitForChild("AquaTuning"))
local COL = A.Color

local AquaFX = {}

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
--- The FX folder, made if it is not there yet (as VFXLibrary makes it). Never `workspace` as a stand-in: every probe here
--- EXCLUDES this folder, and excluding the workspace excludes the whole world.
local function fxFolder()
	local f = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
	if not f then
		f = Instance.new("Folder")
		f.Name = VFXLibrary.Config.FXFolderName
		f.Parent = workspace
	end
	return f
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function easeOut(t)
	t = clamp01(t)
	return 1 - (1 - t) * (1 - t)
end

local function smooth(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AquaFX] " .. msg)
end

--- Characters and the FX folder out of a floor probe.
local function floorParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { fxFolder(), workspace.CurrentCamera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	if extra then for _, e in ipairs(extra) do exclude[#exclude + 1] = e end end
	params.FilterDescendantsInstances = exclude
	return params
end

--- A ray that sees through every body (a character, a training dummy) but not a Bulwark Wall, which is cover. It adds
--- what it passes to `params`, so a wave's probes skip the same bodies from then on.
local function castThroughBodies(origin, direction, params)
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		local mdl = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (mdl and mdl:FindFirstChildOfClass("Humanoid")) or mdl:GetAttribute("WallOwner") then return hit end
		params:AddToFilter(mdl)
	end
	return nil
end

local function floorAt(point, above, below, params)
	return castThroughBodies(point + Vector3.new(0, above or 4, 0), Vector3.new(0, -((above or 4) + (below or 12)), 0),
		params or floorParams())
end

local function model(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = fxFolder()
	return m
end

----------------------------------------------------------------------------------------------------
-- the kit: templates, clones, placement
----------------------------------------------------------------------------------------------------
local KIT_FOLDER = "AquaKit"
local HIDE = CFrame.new(0, -10000, 0)

local function template(name)
	local meshes = ReplicatedStorage:FindFirstChild(VFXLibrary.Config.MeshFolderName or "IceMagicMeshes")
		or ReplicatedStorage:FindFirstChild("IceMagicMeshes")
	local kit = meshes and meshes:FindFirstChild(KIT_FOLDER)
	local t = kit and kit:FindFirstChild(name)
	if t and t:IsA("MeshPart") then return t end
	warnOnce("kit" .. name, name .. " not found in ReplicatedStorage.IceMagicMeshes." .. KIT_FOLDER .. " - that piece is skipped")
	return nil
end

--- Set a kit part's look by kind: "solid", "glass", "line" (Tideline lit), "dim" (the wet trail's line), "dark" (gone dark).
local function setKind(p, kind)
	if kind == "solid" or kind == "glass" then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.new(1, 1, 1)
		p.Transparency = (kind == "glass") and A.Maw.WallTransparency or 0
		p.CastShadow = (kind == "solid")
	elseif kind == "line" then
		p.Material = Enum.Material.Neon
		p.Color = COL.Tideline
		p.Transparency = 0
		p.CastShadow = false
	elseif kind == "dim" then
		p.Material = Enum.Material.Neon
		p.Color = COL.TidelineDim
		p.Transparency = 0
		p.CastShadow = false
	elseif kind == "dark" then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = COL.TidelineDark
		p.Transparency = 0
		p.CastShadow = false
	end
end

--- A fresh clone of kit piece `name`, anchored, touching nothing, parented to `parent` (default the FX folder).
local function take(name, kind, parent)
	local t = template(name)
	if not t then return nil end
	local p = t:Clone()
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
	p.Reflectance = 0
	pcall(function() p.DoubleSided = false end)
	setKind(p, kind or t:GetAttribute("Kind") or "solid")
	p.CFrame = HIDE
	p.Parent = parent or fxFolder()
	return p
end

local function scaleVec(s)
	if typeof(s) == "Vector3" then return s end
	return Vector3.new(s or 1, s or 1, s or 1)
end

--- Put kit part `p`'s ORIGIN at `originCF`, `s` times its template size (a number, or a Vector3 per axis).
local function place(p, originCF, s)
	if not p then return end
	local sv = scaleVec(s)
	local ts = p:GetAttribute("TemplateSize") or p.Size
	local ofp = p:GetAttribute("OriginFromPivot") or Vector3.zero
	p.Size = Vector3.new(math.max(0.02, ts.X * sv.X), math.max(0.02, ts.Y * sv.Y), math.max(0.02, ts.Z * sv.Z))
	p.CFrame = originCF * CFrame.new(-ofp * sv)
end

--- Where named point `name` (P_<name>) of kit part `p` is in the world, for the part as it stands at scale `s`.
local function pointOf(p, name, s)
	local v = p:GetAttribute("P_" .. name)
	if not v then return nil end
	return p.CFrame * CFrame.new(v * scaleVec(s))
end

--- An invisible box that blocks bodies (this client's own copy): the collision for a wave-wall or the tank.
local function collider(size, cf, parent)
	local c = Instance.new("Part")
	c.Name = "AquaCollider"
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, true, false, false, false
	c.Transparency = 1
	c.Size = size
	c.CFrame = cf
	c:SetAttribute("NoWallRun", true)
	c.Parent = parent or fxFolder()
	return c
end

local function destroyAll(list)
	for _, p in pairs(list) do
		if typeof(p) == "Instance" and p.Parent then p:Destroy() end
	end
end

local function randomUnitFlat()
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- WATER SPLASHES (the owner, 2026-09-25: "just in general everywhere make water splashes etc because water is like a
-- liquid"). Every thrown bit of water splashes where it lands, every impact throws a crown and drops, and the running
-- pieces (Riptide's crest, Twin Tide's walls, the gun) shed spray as they go. All of it from kit meshes already in the
-- game (the crowns AK_WG_Splash / AK_SA_Splash, the drops AK_WG_Drop, the foam AK_RT_Foam_n), and CAPPED: past
-- SPLASH_CAP live pieces the optional spray is skipped, so a busy fight on a phone never piles up hundreds of parts.
local SPLASH_CAP = 150
local live = 0
-- 2026-10-08: thrown water falls at the KIT's gravity, never the world's. Every `gravity` handed to fling is a share of
-- KIT_GRAVITY (196.2, what the world's was when those shares were picked); it was a share of workspace.Gravity, so when
-- the world's went to 64 for the bodies' jumps every chunk, drop and drip here fell three times slower.
local KIT_GRAVITY = 196.2

--- A crown of water standing on a surface (its up = the surface `normal`, default straight up), `size` times the kit
--- mesh: it bursts up fast and sinks away over `life`. mesh: "AK_WG_Splash" (the small crown, 188 tris, default) or
--- "AK_SA_Splash" (the big one, for the loud hits only).
local function crown(position, size, normal, mesh, life)
	if live >= SPLASH_CAP then return end
	local up = (typeof(normal) == "Vector3" and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
	local p = take(mesh or "AK_WG_Splash", "solid")
	if not p then return end
	live += 1
	local side = math.abs(up.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
	local fwd = up:Cross(side).Unit
	local cf = CFrame.fromMatrix(position, fwd:Cross(up), up) * CFrame.Angles(0, math.random() * 6.28, 0)
	life = life or 0.34
	local t0 = os.clock()
	place(p, cf, size * 0.35)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		if e > life or not p.Parent then
			conn:Disconnect()
			live -= 1
			if p.Parent then p:Destroy() end
			return
		end
		local g = e < 0.07 and (0.35 + 0.65 * easeOut(e / 0.07)) or math.max(0.05, 1 - smooth((e - 0.1) / (life - 0.1)))
		place(p, cf, size * g)
	end)
end

--- A thrown kit chunk (foam, spray, rock, mist, drop): a rigid piece flying under part-gravity, tumbling, shrinking away
--- over `life`. No fade: things leave by shrinking (Track 1 -- nothing goes see-through). WATER (every chunk unless
--- `dry`, e.g. Leviathan's Maw's rocks) SPLASHES where it lands: it is gone into a small crown the moment it meets the
--- world (bodies and the FX folder are passed through) -- or, given `waterY`, the moment it falls to that height (a
--- drop coming down on the Maw's flood splashes on its surface, not on the floor under it).
--- `gravity` is the piece's share of KIT_GRAVITY (default 0.45), not of the world's gravity (2026-10-08).
--- `opts` (optional; nil from every caller but Twin Tide's crash, whose drops come off the Mantaflow sim on arcs of their
--- own -- tt_sim_drops.json. With it nil, nothing here behaves any differently):
---   Aim = true      no tumble: the piece's head (-Z, the round end of AK_WG_Drop / AK_RT_Foam_n) is AIMED along its
---                   velocity every frame and it is stretched along it by 1 + min(speed, 60) / 30 (the manifest's rule)
---   Drag = k        linear drag, a = gravity - k * v (the hanging foam flecks: 1.2 /s)
---   Tail = s        shrink only over the last `s` seconds of `life` (0: never); without it, from 45% of `life` as ever
---   Land = { Size, Mesh, At, Life }   the end of `life` IS its landing, known in advance (the sim's arc meeting the
---                   flipbook's water, which no ray can hit): gone into a crown of `Size` (Mesh default AK_WG_Splash) at
---                   `At` (default: where it is); with no Size it is simply gone (absorbed)
---   Shadow = false  casts no shadow (review round 2: thrown drops' shadows crawling over the walls' faces)
local function fling(name, at, velocity, size, life, spin, gravity, dry, waterY, opts)
	if live >= SPLASH_CAP then return end
	local p = take(name, "solid")
	if not p then return end
	live += 1
	local s0 = size or 1
	local t0 = os.clock()
	local rot = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
	local pos = at
	local v = velocity
	local g = gravity or 0.45
	local w = spin or 6
	local params = (not dry) and floorParams() or nil
	local aim = opts and opts.Aim
	local drag = opts and opts.Drag
	local tail = opts and opts.Tail
	local land = opts and opts.Land
	if opts and opts.Shadow == false then p.CastShadow = false end
	-- where it is now, `k` times its size: aimed along its travel and stretched by its speed, or tumbling
	local function pose(k)
		if aim then
			local sp = v.Magnitude
			if sp > 1e-3 then
				local dir = v / sp
				rot = CFrame.lookAt(Vector3.zero, dir, (math.abs(dir.Y) > 0.99) and Vector3.zAxis or Vector3.yAxis)
			end
			local st = 1 + math.min(sp, 60) / 30
			place(p, CFrame.new(pos) * rot, Vector3.new(s0 * k, s0 * k, s0 * k * st))
		else
			place(p, CFrame.new(pos) * rot, s0 * k)
		end
	end
	pose(1)
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local e = os.clock() - t0
		if e > life or not p.Parent then
			conn:Disconnect()
			live -= 1
			if p.Parent then
				if land and land.Size and e > life then
					-- its known landing: the arc has met the water
					crown(land.At or pos, land.Size, Vector3.yAxis, land.Mesh, land.Life)
				end
				p:Destroy()
			end
			return
		end
		v += Vector3.new(0, -KIT_GRAVITY * g * dt, 0)
		if drag then v -= v * math.min(1, drag * dt) end
		local step = v * dt
		if params and v.Y < 0 then
			local hit = workspace:Raycast(pos, step, params)
			if waterY and pos.Y > waterY and pos.Y + step.Y <= waterY then
				hit = { Position = Vector3.new(pos.X, waterY, pos.Z), Normal = Vector3.yAxis }
			end
			if hit then
				conn:Disconnect()
				live -= 1
				-- the landing: a crown the size of what fell (a drop's is a flick of water, a foam chunk's a splash)
				local ps = p.Size.Magnitude
				p:Destroy()
				crown(hit.Position, math.clamp(ps * 0.9, 0.22, 0.9), hit.Normal, nil, 0.26)
				return
			end
		end
		pos += step
		if not aim then rot = rot * CFrame.Angles(dt * w, dt * w * 0.7, 0) end
		local k
		if tail then
			k = (tail > 0) and math.max(0.05, 1 - smooth((e - (life - tail)) / tail)) or 1
		else
			k = math.max(0.05, 1 - smooth((e - life * 0.45) / (life * 0.55)))
		end
		pose(k)
	end)
	return p
end

--- `n` drops thrown from `at`: up to `upSpeed` along `up` (default straight up) and up to `outSpeed` round it, each
--- `size` times AK_WG_Drop (0.13 x 0.22), each splashing where it lands.
local function spray(at, n, upSpeed, outSpeed, size, up, life, waterY)
	up = (typeof(up) == "Vector3" and up.Magnitude > 0.1) and up.Unit or Vector3.yAxis
	for _ = 1, n do
		local v = up * (upSpeed * (0.55 + 0.45 * math.random())) + randomUnitFlat() * (outSpeed * (0.3 + 0.7 * math.random()))
		fling("AK_WG_Drop", at, v, (size or 1.6) * (0.75 + 0.5 * math.random()), life or 0.9, 5, 0.5, false, waterY)
	end
end

----------------------------------------------------------------------------------------------------
-- RIDING THE CURRENT: the wet ground (the trail, puddles, the flooded lane) and the foot splash
----------------------------------------------------------------------------------------------------
local STREAK_LEN = 2.4                -- AK_WG_Streak_n's length: the tile the trail is laid in
local streakPick = 0

--- One wet segment: kit streak + its dim edge line, origin on the floor at `cf` (looking along the trail), `width`
--- studs wide (the tile is 6), shrinking in width over the last 0.6 s of `life`.
local function streakTile(cf, width, life, lengthScale)
	streakPick = streakPick % 3 + 1
	local tile = take("AK_WG_Streak_" .. streakPick, "solid")
	local edge = take("AK_WG_StreakEdge_" .. streakPick, "dim")
	if not tile then return end
	local wx = width / 6
	local ly = lengthScale or 1
	place(tile, cf, Vector3.new(wx, 1, ly))
	place(edge, cf, Vector3.new(wx, 1, ly))
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		if e > life or not tile.Parent then
			conn:Disconnect()
			destroyAll({ tile, edge })
			return
		end
		local k = clamp01((life - e) / 0.6)
		if k < 1 then
			place(tile, cf, Vector3.new(math.max(0.02, wx * k), 1, ly))
			place(edge, cf, Vector3.new(math.max(0.02, wx * k), 1, ly))
		end
	end)
end

--- A wet patch on the floor, radius `radius`, for `life`, shrinking away over its last 0.6 s.
function AquaFX.Puddle(center, radius, life)
	life = life or A.Current.WetLife
	local v = math.random(1, 2)
	local pool = take("AK_WG_Puddle_" .. v, "solid")
	local edge = take("AK_WG_PuddleEdge_" .. v, "dim")
	if not pool then return end
	local cf = CFrame.new(center) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	place(pool, cf, Vector3.new(radius, 1, radius))
	place(edge, cf, Vector3.new(radius, 1, radius))
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - t0
		if e > life or not pool.Parent then
			conn:Disconnect()
			destroyAll({ pool, edge })
			return
		end
		local k = clamp01((life - e) / 0.6)
		if k < 1 then
			local r = math.max(0.02, radius * k)
			place(pool, cf, Vector3.new(r, 1, r))
			place(edge, cf, Vector3.new(r, 1, r))
		end
	end)
	return pool
end

--- A flooded lane (Twin Tide's): wet tiles laid along `axis`, `width` wide and `length` long, for `life`.
function AquaFX.WetLane(center, axis, width, length, life)
	axis = flat(axis).Unit
	local n = math.max(1, math.floor(length / STREAK_LEN + 0.5))
	local ls = length / (n * STREAK_LEN)
	for i = 1, n do
		local at = center + axis * ((i - 0.5) * STREAK_LEN * ls - length / 2) + Vector3.new(0, 0.03, 0)
		streakTile(CFrame.lookAt(at, at + axis), width, life, ls)
	end
end

--- Foam at the planted foot of anyone riding their own current (the passive's visible half): the kit's crown splash,
--- shrinking away over 0.35 s, and a couple of drops thrown back.
function AquaFX.RidingSplash(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then return end
	-- the floor under the body, found by a ray (a rig's HipHeight is not where its feet are on every rig)
	local g = floorAt(root.Position, 0.5, 8)
	local feet = g and g.Position or (root.Position - Vector3.new(0, root.Size.Y / 2 + hum.HipHeight, 0))
	-- a little to one side each step, where a foot plants
	local side = root.CFrame.RightVector * ((math.random() < 0.5) and -0.5 or 0.5)
	feet += Vector3.new(side.X, 0, side.Z)
	local back = -flat(root.AssemblyLinearVelocity)
	back = back.Magnitude > 1 and back.Unit or Vector3.zero
	local splash = take("AK_WG_Splash", "solid")
	if splash then
		-- a crown round the foot, 1.35x the kit's 1.2: at 1x a 1-stud leg stands in it and hides it
		local cf = CFrame.new(feet + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
		local t0 = os.clock()
		place(splash, cf, 0.9)
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local e = os.clock() - t0
			if e > 0.38 or not splash.Parent then
				conn:Disconnect()
				if splash.Parent then splash:Destroy() end
				return
			end
			local s = e < 0.08 and (0.9 + 0.45 * e / 0.08) or math.max(0.05, 1.35 * (1 - (e - 0.08) / 0.3))
			place(splash, cf, s)
		end)
	end
	for _ = 1, 2 do
		local v = back * (3 + math.random() * 3) + Vector3.new(math.random() * 2 - 1, 5 + math.random() * 3, math.random() * 2 - 1)
		fling("AK_WG_Drop", feet + Vector3.new(0, 0.4, 0), v, 1, 0.4, 3, 0.3)
	end
end

----------------------------------------------------------------------------------------------------
-- M1: RIPTIDE -- the whitewater crescent, run along the floor
----------------------------------------------------------------------------------------------------
-- Three roll stages of the same crescent (AK_RT_Wave_1..3, each with its Tideline lip AK_RT_Lip_n) are swapped every
-- STAGE_TIME so the crest reads as rolling; at a wall, an edge or its range the wave is swapped for AK_RT_Break (the
-- crash, no lip: the water has stopped) and throws foam.
local STAGE_TIME = 0.07

--- Run a wave. opts: Origin (the caster's root), Dir (flat unit), T0 (server time of the release), Own (the shooter's
--- own copy: it looks for bodies), Exclude (what it passes through), OnHit(part, position) for each new body.
function AquaFX.Riptide(opts)
	local R = A.Riptide
	local dir = flat(opts.Dir)
	if dir.Magnitude < 0.1 then return end
	dir = dir.Unit
	local params = floorParams(opts.Exclude)
	local startFlat = flat(opts.Origin) + dir * R.StartAhead
	local first = floorAt(Vector3.new(startFlat.X, opts.Origin.Y, startFlat.Z), 3, 12, params)
	if not first then return end
	local y = first.Position.Y
	local m = model("AquaRiptide")
	local waves, lips = {}, {}
	for i = 1, 3 do
		waves[i] = take("AK_RT_Wave_" .. i, "solid", m)
		lips[i] = take("AK_RT_Lip_" .. i, "line", m)
	end
	if not waves[1] then
		m:Destroy()
		return
	end

	-- every copy sees the bodies it runs through (each splashes); only the shooter's own copy REPORTS them
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	do
		local ex = { fxFolder(), workspace.CurrentCamera }
		for _, e in ipairs(opts.Exclude or {}) do ex[#ex + 1] = e end
		overlap.FilterDescendantsInstances = ex
	end
	local hit = {}
	local count = 0
	local sprayDue = 0
	local rightV = dir:Cross(Vector3.yAxis)

	local dist = 0
	local laid = 0
	-- a wave from a message that arrived late starts where it would be now
	local late = math.max(0, serverNow() - (opts.T0 or serverNow()))
	local scale = VFXLibrary.ShotTimeScale()
	local ended = false
	local stage = 0
	local t0 = os.clock()
	local conn

	local function show(frontCF)
		local s = math.floor((os.clock() - t0) / (STAGE_TIME / scale)) % 3 + 1
		for i = 1, 3 do
			if i == s then
				place(waves[i], frontCF)
				if lips[i] then place(lips[i], frontCF) end
			elseif i == stage then
				waves[i].CFrame = HIDE
				if lips[i] then lips[i].CFrame = HIDE end
			end
		end
		stage = s
	end

	local function finish(at)
		if ended then return end
		ended = true
		conn:Disconnect()
		m:Destroy()
		-- THE BREAK: the crest crashes forward into foam; the Tideline is gone (the water has stopped)
		local brk = take("AK_RT_Break", "solid")
		local cf = CFrame.lookAt(at, at + dir)
		local bt = os.clock()
		if brk then
			place(brk, cf, Vector3.new(1, 0.6, 0.9))
			local c2
			c2 = RunService.Heartbeat:Connect(function()
				local e = os.clock() - bt
				if e > 0.45 or not brk.Parent then
					c2:Disconnect()
					if brk.Parent then brk:Destroy() end
					return
				end
				local grow = easeOut(e / 0.1)
				local sink = smooth((e - 0.2) / 0.25)
				place(brk, cf * CFrame.new(0, -1.2 * sink, 0), Vector3.new(1, (0.6 + 0.4 * grow) * (1 - 0.6 * sink), 0.9 + 0.1 * grow))
			end)
		end
		for i = 1, 7 do
			local v = dir * (4 + math.random() * 8) + randomUnitFlat() * (3 + math.random() * 4)
				+ Vector3.new(0, 10 + math.random() * 8, 0)
			fling("AK_RT_Foam_" .. ((i - 1) % 4 + 1), at + Vector3.new(0, 1.5, 0) + randomUnitFlat() * math.random() * 3, v,
				1, 0.55, 7, 0.45)
		end
		-- the crash throws water: a big crown on the spot and a spray of drops forward and up
		crown(at + dir * 0.6, 1.1, nil, "AK_SA_Splash", 0.45)
		spray(at + Vector3.new(0, 1.2, 0), 9, 15, 9, 2.2)
	end

	local lastY = y
	local lastFront = Vector3.new(startFlat.X, y, startFlat.Z)
	show(CFrame.lookAt(lastFront, lastFront + dir))
	conn = RunService.Heartbeat:Connect(function(dt)
		if not m.Parent then
			conn:Disconnect()
			return
		end
		local step = R.Speed * scale * (dt + late)
		late = 0
		local nd = math.min(R.Range - R.StartAhead, dist + step)
		local fx = startFlat + dir * nd
		local front, frontY, broke = nil, lastY, false
		-- the floor under the new front: a rise too steep is a wall, a drop too deep is an edge
		local g = floorAt(Vector3.new(fx.X, lastY, fx.Z), R.StepUp + 0.5, R.StepDown, params)
		if not g or g.Position.Y - lastY > R.StepUp then
			front, broke = lastFront, true
		else
			-- a wall across the line, at knee height
			local from = lastFront + Vector3.new(0, 1.2, 0)
			local to = Vector3.new(fx.X, g.Position.Y + 1.2, fx.Z)
			local wall = castThroughBodies(from, to - from, params)
			if wall and math.abs(wall.Normal.Y) < 0.5 then
				front, broke = Vector3.new(wall.Position.X, lastY, wall.Position.Z), true
				nd = dist + flat(front - lastFront).Magnitude
			else
				front, frontY = Vector3.new(fx.X, g.Position.Y, fx.Z), g.Position.Y
			end
		end
		if not broke then
			show(CFrame.lookAt(front, front + dir))
			-- spray off the crest as it runs, left behind it and flung out past the horns, splashing where it lands
			sprayDue += dt
			while sprayDue >= 0.035 do
				sprayDue -= 0.035
				local u = math.random() * 2 - 1
				local at = front + rightV * (u * R.Width * 0.42) - dir * (0.3 + 1.6 * u * u)
					+ Vector3.new(0, R.Height * (0.75 - 0.4 * u * u) * (0.8 + 0.3 * math.random()), 0)
				local v = dir * (R.Speed * scale * (0.3 + 0.3 * math.random())) + rightV * (u * (3 + math.random() * 5))
					+ Vector3.new(0, 4 + math.random() * 6, 0)
				if math.random() < 0.4 then
					fling("AK_RT_Foam_" .. math.random(1, 2), at, v, 1.2 + 0.4 * math.random(), 0.8, 6, 0.5)
				else
					fling("AK_WG_Drop", at, v, 3 + 1.2 * math.random(), 0.8, 5, 0.5)
				end
			end
		end
		-- the wet streak behind it, laid in the kit's tile length
		while laid + STREAK_LEN <= nd do
			local s = laid + STREAK_LEN / 2
			local p = startFlat + dir * s
			local gy = floorAt(Vector3.new(p.X, lastY, p.Z), 3, 6, params)
			if gy then
				local at = Vector3.new(p.X, gy.Position.Y + 0.03, p.Z)
				streakTile(CFrame.lookAt(at, at + dir), R.TrailWidth, A.Current.WetLife)
			end
			laid += STREAK_LEN
		end
		-- bodies in the crest's box, up to where it broke: each one it runs through SPLASHES (every copy), and the
		-- shooter's copy reports them (up to Pierce)
		if count < R.Pierce then
			local mid = (lastFront + front) / 2
			local boxCF = CFrame.lookAt(mid + Vector3.new(0, R.Height / 2, 0), mid + Vector3.new(0, R.Height / 2, 0) + dir)
			local parts = workspace:GetPartBoundsInBox(boxCF, Vector3.new(R.Width, R.Height, (front - lastFront).Magnitude + 1.6), overlap)
			for _, p in ipairs(parts) do
				local mdl = p:FindFirstAncestorOfClass("Model")
				local hum = mdl and mdl:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and not hit[mdl] and count < R.Pierce then
					hit[mdl] = true
					count += 1
					if opts.Own and opts.OnHit then task.spawn(opts.OnHit, p, p.Position) end
					local body = mdl:FindFirstChild("HumanoidRootPart") or p
					local at = Vector3.new(body.Position.X, frontY, body.Position.Z)
					crown(at + dir * 0.4, 1.0, nil, "AK_SA_Splash", 0.4)
					spray(at + Vector3.new(0, 1.8, 0), 7, 13, 7, 2, (dir * 0.5 + Vector3.yAxis).Unit)
				end
			end
		end
		if broke then
			finish(front)
			return
		end
		lastFront, lastY, dist = front, frontY, nd
		if nd >= R.Range - R.StartAhead - 0.01 then finish(front) end
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: UNDERTOW -- the whirlpool the hand draws in front of your face; the snap; the burst
----------------------------------------------------------------------------------------------------
-- The owner (2026-09-25, with a reference clip): "IT SHOULD BE INFRONT OF YOUR FACE, YOUR HANDS DOING THE CIRCULAR ARC",
-- the pull "stays in front of you". The disc stands up DiscDistance in front of the caster's eye, facing them
-- (vmarm/aqua_kit/piece_ut.py v4 -- this runs the same timeline as its previews). Its frame: CFrame.lookAt(centre,
-- centre + look), so local +X is the caster's right, +Y up, +Z toward the caster. Clock angle phi: 0 = up, CLOCKWISE
-- as the caster sees it. The hand starts low right (PHI0) and draws ARC degrees clockwise: the outer arm appears
-- stretch by stretch behind the head (AK_UT_Arm_1..11, each with its Tideline AK_UT_ArmLine_n, grown in about its own
-- centre), spiralling INWARD from R0 to R1 -- a spiral never closes, so the ring stays open where it began. The head
-- (AK_UT_Head + the bright tip AK_UT_HeadLine) is the water at the hand. The inner arms (AK_UT_Inner_1..3) swirl in
-- behind it and the eye (AK_UT_Eye) opens; droplets are thrown off the head. When the hand stops, the disc keeps
-- turning with the sweep's momentum, faster toward the snap; at the snap the Tidelines flare white, the disc cinches,
-- and it blows apart into mist chunks and droplets.
local UT_R0, UT_R1, UT_PHI0, UT_ARC, UT_ARMS = 2.7, 1.95, 135, 330, 11
local UT_POP = 0.08
local UT_TIP = Color3.fromRGB(151, 218, 250)           -- #97DAFA: paler than the Tideline so the tip still stands out (owner blues, 2026-09-26)
local UT_FLASH = Color3.fromRGB(183, 222, 248)

local function utSweep(t)
	local U = A.Undertow
	local T = U.ConjureTime
	local u = clamp01(t / T)
	local k = U.SweepEndSpeed * T / UT_ARC
	return (k - 2) * u ^ 3 + (3 - k) * u ^ 2
end

local function utSpin(t)
	local U = A.Undertow
	if t <= U.ConjureTime then return 0 end
	local d = math.min(t, U.SnapTime) - U.ConjureTime
	return U.SweepEndSpeed * d + 0.5 * U.SweepAccel * d * d
end

--- When the head reaches arm position s (0..1).
local function utWhen(s)
	local T = A.Undertow.ConjureTime
	if s <= 0 then return 0 end
	if s >= 1 then return T end
	local lo, hi = 0, T
	for _ = 1, 30 do
		local mid = (lo + hi) / 2
		if utSweep(mid) < s then lo = mid else hi = mid end
	end
	return hi
end

--- The arm's point and frame at s, in the disc's own frame.
local function utArm(s)
	local phi = math.rad(UT_PHI0 + UT_ARC * s)
	local r = UT_R0 - (UT_R0 - UT_R1) * s
	local radial = Vector3.new(math.sin(phi), math.cos(phi), 0)
	local tangent = Vector3.new(math.cos(phi), -math.sin(phi), 0)
	return Vector3.new(r * math.sin(phi), r * math.cos(phi), -0.12 * s), radial, tangent, r, phi
end

--- A kit part grown about its OWN centre (its pivot) by `pop`, the whole shrunk about the disc by `cinch`.
local function placeAboutPivot(p, originCF, cinch, pop)
	if not p then return end
	local ts = p:GetAttribute("TemplateSize") or p.Size
	local ofp = p:GetAttribute("OriginFromPivot") or Vector3.zero
	local s = math.max(0.02, cinch * pop)
	p.Size = Vector3.new(math.max(0.02, ts.X * s), math.max(0.02, ts.Y * s), math.max(0.02, ts.Z * s))
	p.CFrame = originCF * CFrame.new(-ofp * cinch)
end

--- The whole Undertow from its server time: the disc at `center`, facing back along `look` (toward the caster).
--- Returns a handle: Head() -> the world point of the water at the hand (the caster's own arm follows it).
function AquaFX.Undertow(center, look, t0)
	local U = A.Undertow
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
	look = look.Unit
	local m = model("AquaUndertow")
	local DS = U.DiscScale or 1
	local discCF = CFrame.lookAt(center, center + look)
	local arms, lines = {}, {}
	for k = 1, UT_ARMS do
		arms[k] = take("AK_UT_Arm_" .. k, "solid", m)
		lines[k] = take("AK_UT_ArmLine_" .. k, "line", m)
	end
	local head = take("AK_UT_Head", "solid", m)
	local tip = take("AK_UT_HeadLine", "line", m)
	if tip then tip.Color = UT_TIP end
	local inner = {}
	for i = 1, 3 do inner[i] = take("AK_UT_Inner_" .. i, "solid", m) end
	local eye = take("AK_UT_Eye", "solid", m)
	local drops = {}
	local nextDrop = 0
	local start = os.clock() - math.max(0, serverNow() - (t0 or serverNow()))
	local snapped = false
	local headWorld = center
	local handle = {}
	local conn

	local function burst(baseCF)
		-- the disc is gone into chunks: mist and droplets thrown out in its plane and toward the caster
		for i = 1, 20 do
			local phi = i / 20 * math.pi * 2 + math.random() * 0.3
			local r = (1.2 + math.random() * 1.8) * DS
			local rad = Vector3.new(math.sin(phi), math.cos(phi), 0)
			local at = baseCF * (rad * r)
			-- out in the disc's plane, only a little toward the caster (thrown straight at the lens they filled the view)
			local v = baseCF:VectorToWorldSpace(rad * (12 + math.random() * 10) + Vector3.new(0, 2 + math.random() * 3, 0.5 + math.random() * 2))
			fling("AK_UT_Mist_" .. ((i - 1) % 4 + 1), at, v, 0.8 + math.random() * 0.4, 0.55, 6, 0.35)
		end
		for i = 1, 10 do
			local phi = i / 10 * math.pi * 2 + math.random() * 0.5
			local rad = Vector3.new(math.sin(phi), math.cos(phi), 0)
			local at = baseCF * (rad * (2.0 + math.random() * 0.8) * DS)
			local v = baseCF:VectorToWorldSpace(rad * (16 + math.random() * 10) + Vector3.new(0, 3, 0.5 + math.random() * 1.5))
			fling("AK_UT_Droplet_" .. ((i - 1) % 4 + 1), at, v, 1, 0.5, 8, 0.4)
		end
	end

	conn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local e = now - start
		if not m.Parent then
			conn:Disconnect()
			return
		end
		local sHead = utSweep(e)
		local cinch = 1 - 0.06 * smooth((e - U.ConjureTime) / (U.SnapTime - U.ConjureTime))
		if e >= U.SnapTime then cinch = 0.92 end
		cinch *= DS                                                    -- the whole disc at DiscScale
		local baseCF = discCF * CFrame.Angles(0, 0, -math.rad(utSpin(e)))
		if e >= U.SnapTime + 0.08 then
			if not snapped then
				snapped = true
				burst(baseCF)
				for _, d in ipairs(drops) do if d.Part.Parent then d.Part:Destroy() end end
				table.clear(drops)
				m:ClearAllChildren()
			end
			if e >= U.EndTime then
				conn:Disconnect()
				m:Destroy()
			end
			return
		end
		local flare = e >= U.SnapTime
		-- the outer arm, stretch by stretch as the head passes
		for k = 1, UT_ARMS do
			local g = easeOut((e - utWhen((k - 0.5) / UT_ARMS)) / UT_POP)
			if g > 0.01 then
				local pop = 0.25 + 0.75 * g
				placeAboutPivot(arms[k], baseCF, cinch, pop)
				placeAboutPivot(lines[k], baseCF, cinch, pop)
				if lines[k] then lines[k].Color = flare and UT_FLASH or COL.Tideline end
			end
		end
		-- the head: the water at the hand
		local p, radial, tangent = utArm(math.min(sHead, 1))
		local grow = 0.35 + 0.65 * easeOut(e / 0.1)
		local headCF = baseCF * CFrame.new(p * cinch) * CFrame.fromMatrix(Vector3.zero, -radial, Vector3.zAxis, -tangent)
		place(head, headCF, grow * cinch)
		place(tip, headCF, grow * cinch)
		if tip then tip.Color = flare and UT_FLASH or UT_TIP end
		headWorld = headCF.Position
		-- the inner arms swirl in behind it, turning in from further round and larger; the eye opens
		for i, sStart in ipairs({ 0.40, 0.62, 0.84 }) do
			local g = easeOut((e - utWhen(sStart)) / 0.26)
			if g > 0.01 and inner[i] then
				place(inner[i], baseCF * CFrame.Angles(0, 0, math.rad(55 * (1 - g))), (1 + 0.3 * (1 - g)) * cinch)
			end
		end
		local ge = easeOut((e - 0.2) / 0.25)
		if ge > 0.01 then place(eye, baseCF, (0.3 + 0.7 * ge) * cinch) end
		-- droplets thrown off the head while it draws, each gone in a quarter second
		if e < U.ConjureTime and now >= nextDrop then
			nextDrop = now + 0.024
			local dp = take("AK_UT_Droplet_" .. math.random(1, 4), "solid", m)
			if dp then
				drops[#drops + 1] = { Part = dp, S = sHead, Born = now, A = math.random(), B = math.random() }
			end
		end
		for i = #drops, 1, -1 do
			local d = drops[i]
			local pd = (now - d.Born) / 0.26
			if pd >= 1 then
				d.Part:Destroy()
				table.remove(drops, i)
			else
				local _, _, _, r, phi = utArm(d.S)
				phi += math.rad(10 * pd)
				local rd = Vector3.new(math.sin(phi), math.cos(phi), 0)
				local tg = Vector3.new(math.cos(phi), -math.sin(phi), 0)
				local rr = r + (0.5 + 0.9 * d.A) * pd
				local pos = Vector3.new(rr * math.sin(phi), rr * math.cos(phi), 0.2 + (0.4 + 1.2 * d.B) * pd) * DS
				local fwd = (tg + rd * 0.6).Unit
				place(d.Part, baseCF * CFrame.lookAt(pos, pos + fwd, Vector3.zAxis), (0.55 * (1 - pd) + 0.1) * DS)
			end
		end
	end)

	function handle.Head()
		return headWorld
	end
	return handle
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: TWIN TIDE -- two tsunamis build up, rush in and crash into each other
----------------------------------------------------------------------------------------------------
-- v4 (round 5, 2026-09-26): the Blender rebuild the owner approved after the rigid version (one pre-curled mesh scaled
-- in place) was turned down. His notes on the way here: "animate their build up", "they are way too sloww", "what is
-- the middle thing that comes out of ground?? remove it. Only the 2 tsunamis crashing with eachother is the reason for
-- damage", "make reastic water physics for when the tsunamis crash", "The wiggle the waves have is not realistic, remove
-- the wiggle", "why is the water so white? Make it blue", "Remove the claws first" -- and a small splash. Two halves on
-- one clock (seconds after the cast, the server's T0):
--   THE WALLS  0 - 1.10 s. Two SKINNED walls posed bone by bone every frame from the pose table the Blender build wrote
--             (AquaTTPose = vmarm/aqua_kit/tt_pose.luau, the evaluator; AquaTTPoseTable = tt_pose_table.luau, its data,
--             format "tt_pose v4.1"): a hump swelling out of the ground, the face standing up, the lip pitching over
--             the lane and meeting the other lip at the seam at CloseTime. Each wall shows one of four colour stages of
--             the same 64-bone rig (AK_TT_Wall_1..4: TTPose.wallStage, held per phase -- the cycling read as a shimmer),
--             with its Tideline (AK_TT_Lip) and crest foam cap (AK_TT_Cap) on rigs of their own, and closes on the lane
--             as TTPose.travel says. At the pinch the foam collar (AK_TT_Collar) bridges the lips and the jet
--             (AK_TT_Jet_1..4, rigid stages) squirts up out of it with ONE flash; drops pinch off the claws where the
--             table still has any (TTPose.dropCount: 0 since the claws went).
--   THE CRASH  1.10 - 2.95 s. Frame 1 of a Mantaflow flipbook replaces all of that at CloseTime -- the server's crush
--             there is the only damage and is not touched -- AK_TT_Sim_01..37 at 20 fps, one visible at a time: the
--             curtain thrown up from the seam, folding over, landing, the flood running out and draining into puddles.
--             Its Tideline rides the moving edge (AK_TT_SimLine_NN) and goes dark when the water stops; the sim's own
--             drops, hanging foam flecks and second-slam crowns come at their times (AquaTTSimData, converted from
--             manifests/tt_sim.json + tt_sim_drops.json). Then the ground stays wet (AquaFX.WetLane over the flood's
--             footprint) for as long as the server keeps the lane slippery. NB: only that long -- not that wide. The
--             flood's reach is ~42 x 54 but the server's slip strip (castTwinTide's addStrip) is still the 22 x 24 lane,
--             so the outer wet tiles do not slip: an open owner call (NOTES.md, open risks); layWet(e, false) is the
--             lane-sized alternative.
-- The colour is baked (the owner's blues). The Twin Tide lines are Neon #2690E4 and go dark navy #0C4A92, the flash is
-- Neon #4FBDF6 -- never white (the builder's manifests; every other Aqua line keeps the kit's Tideline). Nothing here is
-- see-through. Each wall blocks bodies with an invisible box collider (this client's own copy) while it stands. A
-- message that lands within TT_BUILD_LEAD of the handover (a hitch, a slow link) skips the walls and their colliders and
-- starts on the flipbook: the walls would show for a few frames, at the price of every skinned clone at once.
-- SIDES: "side +1" is the wall on the caster's LEFT. Its axes are the flipbook's (the seam frame, seam[1]), whose +X
-- then runs back down the lane toward the caster -- where the builder's approved "game camera" stood (Blender
-- (-27, -1.5, 8) = +27 along that X, eye 8: tt_sim_sheet / rig_video) -- so the caster sees the crash the way it was
-- reviewed. The pose table is the same for both walls; turned 180 degrees, the far one peels from the other end.
-- Each side's skinned pieces (its four stages, its lip, its cap) live in a Model of their own (AquaTwinTideSide+1 / -1,
-- beside the effect's model in the FX folder, not inside it): a skinned MeshPart can be bound to a same-named Bone
-- anywhere in its Model (that is how a rig's bones may hang under another part), and both sides show the same stage,
-- lip and cap -- the same bone names -- at once. A top-level Model per side keeps every name unique however far up the
-- engine looks. The collar is one of a kind and stays in the effect's model; finish() destroys all three.
-- COST: only the SHOWING pieces are posed, and each (chain, column) is evaluated once a frame and shared by both walls
-- and both lips: 168 Bone.Transform writes from 49 evaluations a frame until the cap shows (0.69 s), 252 from 91 until
-- the collar (1.05 s), 273 from 112 until the handover, none after it (a flipbook frame is one CFrame write in 50 ms).
-- (With the claw chains posed -- a table that still throws claw drops, TTPose.dropCount > 0 -- 196/63, 280/105,
-- 301/126.) Every client gets every cast (the server broadcasts to all) and the Hub and the arenas share one server,
-- thousands of studs apart: a cast further than TT_FAR from both this client's camera and its body is not drawn.
local TT_LINE = Color3.fromRGB(38, 144, 228)          -- #2690E4 Neon: the Twin Tide lines (manifests line_colour)
local TT_LINE_DARK = Color3.fromRGB(12, 74, 146)      -- #0C4A92 SmoothPlastic: a line gone dark (line_colour_dark)
local TT_FLASH = Color3.fromRGB(79, 189, 246)         -- #4FBDF6 Neon: the jet's one flash (tt_jet.json flash_colour)
local TT_STAGES = 4                                   -- AK_TT_Wall_1..4
local TT_COLLIDER_T = 2.4                             -- the invisible box: this thick, W.Length long, W.Height tall...
local TT_COLLIDER_RISE = 0.35                         -- ...standing once the wall is this share of its height up
local TT_BUILD_PER_BEAT = 3                           -- kit clones made a Heartbeat over the approach...
local TT_BUILD_LEAD = 0.15                            -- ...and made at once when needed within this many seconds
local TT_DROP_W = 0.13                                -- AK_WG_Drop's width at scale 1 (manifests/wg.json: 0.1299)
local TT_FOAM_LEN = { 0.42, 0.58, 0.75, 0.9 }         -- AK_RT_Foam_1..4's length at scale 1 (manifests/rt.json)
local TT_SA_W = 2.52                                  -- AK_SA_Splash's width at scale 1 (manifests/sa.json: 2.5235)
local TT_SLAM_ACROSS = 1.5                            -- studs across per unit of crownScale (2.6 -> "~3-4 across")
local TT_LAND_CROWN = 1                               -- a sim drop landing on the pool: AK_SA_Splash "~1x"
local TT_WET_LEAD = 0.25                              -- the wet ground goes down this long before the last frame goes
local TT_PROBE = true                                 -- TT* attributes on the model every frame, for the Play test
local TT_FAR = 600                                    -- studs: a cast further than this from camera and body is not drawn
-- chains left at rest WHILE THE TABLE HAS NO CLAW DROPS (TTPose.dropCount 0 -- the evaluator's own word for "the walls
-- have no claws", v4 round 3, the owner: "Remove the claws first"): their bones then carry no weights, so posing them
-- would be 14 evaluations and 28 bone writes a frame for nothing (manifests/tt_rig.json: "writing their Transforms is
-- harmless and skipping them ... is fine"). A table that still throws claw drops has claws: then they are posed.
local TT_UNPOSED = { Claw = true, ClawTip = true }

--- The pose evaluator, its table and the flipbook data, required on first use. A module that is not there yet is looked
--- for again at the next cast; one that fails to load, or a table this code does not drive, turns Twin Tide's drawing off
--- for the session. Either way ONE warning and the cast draws nothing: the server's crush never waits on a look.
local ttMods = nil                                    -- nil: not loaded yet; false: off for good; else { Pose, Table, Sim }
local function ttLoad()
	if ttMods ~= nil then return ttMods or nil end
	local poseMod = iceFolder:FindFirstChild("AquaTTPose")
	local tableMod = iceFolder:FindFirstChild("AquaTTPoseTable")
	if not (poseMod and tableMod) then
		warnOnce("ttMissing", "Twin Tide: ReplicatedStorage.IceMagic.AquaTTPose / AquaTTPoseTable not found - "
			.. "Twin Tide is not drawn")
		return nil
	end
	local ok, pose, tbl = pcall(function()
		return require(poseMod), require(tableMod)
	end)
	if not ok then
		warnOnce("ttLoad", "Twin Tide: the pose modules failed to load (" .. tostring(pose) .. ") - Twin Tide is not drawn")
		ttMods = false
		return nil
	end
	local good = type(pose) == "table" and type(pose.transform) == "function" and type(pose.wallStage) == "function"
		and type(tbl) == "table" and type(tbl.format) == "string" and string.find(tbl.format, "^tt_pose v4") ~= nil
		and type(tbl.columns) == "table" and type(tbl.stages) == "table" and type(tbl.stages.keys) == "table"
	if not good then
		warnOnce("ttFormat", "Twin Tide: AquaTTPoseTable is not a 'tt_pose v4.x' table with stages.keys (format "
			.. tostring(type(tbl) == "table" and tbl.format) .. ") - copy tt_pose.luau and tt_pose_table.luau TOGETHER. "
			.. "Twin Tide is not drawn")
		ttMods = false
		return nil
	end
	-- the flipbook's data is optional: without it the skinned walls play the whole table out and the lane goes wet
	local sim = nil
	local simMod = iceFolder:FindFirstChild("AquaTTSimData")
	if simMod then
		local ok2, s = pcall(require, simMod)
		if ok2 and type(s) == "table" and type(s.frames) == "table" and #s.frames > 0 then
			sim = s
		else
			warnOnce("ttSim", "Twin Tide: AquaTTSimData failed to load (" .. tostring(s) .. ") - the crash flipbook is skipped")
		end
	else
		warnOnce("ttSim", "Twin Tide: ReplicatedStorage.IceMagic.AquaTTSimData not found - the crash flipbook is skipped")
	end
	ttMods = { Pose = pose, Table = tbl, Sim = sim }
	return ttMods
end

--- Put SKINNED kit part `p`'s ORIGIN at `originCF` at the size it was imported at. Size is never written: a skinned part
--- must never be resized (it would scale the skin away from its bones). Only the walls, lips, caps and collar come here;
--- the rigid pieces (the jets, their rim lines, the flipbook frames and their SimLines) go through place() at scale 1
--- like the rest of the kit -- Size = TemplateSize, so a rigid piece imported at the wrong scale is still drawn right.
local function pin(p, originCF)
	if not p then return end
	local ofp = p:GetAttribute("OriginFromPivot") or Vector3.zero
	p.CFrame = originCF * CFrame.new(-ofp)
end

--- A Twin Tide line lit (Neon, `colour` or #2690E4) or gone dark (SmoothPlastic navy #0C4A92).
local function ttLine(p, lit, colour)
	if not p then return end
	setKind(p, lit and "line" or "dark")
	p.Color = lit and (colour or TT_LINE) or TT_LINE_DARK
end

--- A skinned Twin Tide piece's bones, found by class wherever they sit (the importer may nest them by hierarchy or
--- flatten them) and parsed ONCE (TTPose.parse). Only the bones the table drives are kept (a chain the table has no keys
--- for, or one in `unposed` -- the weightless claw bones -- is simply left at rest). Each keeps its REST in the part's
--- space, read from the bones' own CFrames before any Transform is written (the same as part.CFrame:Inverse() *
--- bone.WorldCFrame then): a non-identity rest rotation is honoured as the evaluator's header says, restRot:Inverse() *
--- T * restRot. If every bone hangs under its table parent (Face under Foot, ...), a Transform is written as it comes
--- (Direct); if the importer flattened them, each bone's pose is composed down its chain (tbl.hierarchy) instead.
local function ttRig(p, TTPose, TABLE, unposed)
	local list, byBone, byKey, rest = {}, {}, {}, {}
	local function restOf(b)
		local r = rest[b]
		if r then return r end
		local parent = b.Parent
		r = ((parent and parent:IsA("Bone")) and restOf(parent) or CFrame.identity) * b.CFrame
		rest[b] = r
		return r
	end
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("Bone") then
			local chain, col = TTPose.parse(d.Name)
			local column = chain and col and TABLE.columns[col]
			if column and column.keys and column.keys[chain] and not (unposed and unposed[chain]) then
				local ra = restOf(d)
				local b = { Bone = d, Chain = chain, Column = col, Key = chain .. col, RestAbs = ra, Local = d.CFrame }
				local _, angle = ra.Rotation:ToAxisAngle()
				if math.abs(angle) > 1e-3 then
					b.Rest, b.RestInv = ra.Rotation, ra.Rotation:Inverse()
				end
				list[#list + 1] = b
				byBone[d] = b
				byKey[b.Key] = b
			end
		end
	end
	local H = TABLE.hierarchy or {}
	local direct = true
	for _, b in ipairs(list) do
		local pc = H[b.Chain]
		b.LParent = pc and byKey[pc .. b.Column] or nil        -- the parent the table poses it under
		b.AParent = byBone[b.Bone.Parent] or nil               -- the parent it really hangs under (nil: a root, the part)
		if b.AParent ~= b.LParent then direct = false end
		b.RelRest = (b.LParent and b.LParent.RestAbs:Inverse() or CFrame.identity) * b.RestAbs
		b.InvRestAbs = b.RestAbs:Inverse()
		local depth, c = 0, b.Chain
		while H[c] and depth < 16 do
			c = H[c]
			depth += 1
		end
		b.Depth = depth
	end
	table.sort(list, function(a, b) return a.Depth < b.Depth end)
	return { List = list, Direct = direct, Pose = {}, Count = #list }
end

--- One frame's pose written to a rig's bones. `T(b)` is the table's Transform for bone b's (chain, column) this frame.
--- Returns how many bones were written.
local function poseRig(rig, T)
	local list = rig.List
	if rig.Direct then
		for _, b in ipairs(list) do
			local cf = T(b)
			if b.Rest then cf = b.RestInv * cf * b.Rest end
			b.Bone.Transform = cf
		end
	else
		-- flattened: the pose in the part's space, parent before child (the list is sorted by chain depth), then the
		-- Transform that puts the bone there from where it really hangs
		local P = rig.Pose
		for _, b in ipairs(list) do
			local cf = T(b)
			if b.Rest then cf = b.RestInv * cf * b.Rest end
			local lp = b.LParent
			local abs = (lp and (P[lp] or lp.RestAbs) or CFrame.identity) * b.RelRest * cf
			P[b] = abs
			local q = b.AParent
			if q then
				b.Bone.Transform = ((P[q] or q.RestAbs) * b.Local):Inverse() * abs
			else
				b.Bone.Transform = b.InvRestAbs * abs
			end
		end
	end
	return #list
end

--- The Twin Tide kit preloaded once a session, off the main thread, so the first cast does not pop in piece by piece.
--- (VFXLibrary.Preload already hands the whole IceMagicMeshes folder over at start-up; this is the same for just these
--- pieces, in case it has not got to them.)
local function ttPreload()
	if not RunService:IsClient() then return end
	task.spawn(function()
		if not game:IsLoaded() then game.Loaded:Wait() end
		local mods = ttLoad()
		local meshes = ReplicatedStorage:FindFirstChild(VFXLibrary.Config.MeshFolderName or "IceMagicMeshes")
		local kit = meshes and meshes:FindFirstChild(KIT_FOLDER)
		if not kit then return end
		local names = { "AK_TT_Lip", "AK_TT_Cap", "AK_TT_Collar", "AK_WG_Drop", "AK_SA_Splash" }
		for n = 1, TT_STAGES do table.insert(names, "AK_TT_Wall_" .. n) end
		for n = 1, 4 do
			table.insert(names, "AK_TT_Jet_" .. n)
			table.insert(names, "AK_TT_JetLine_" .. n)
			table.insert(names, "AK_RT_Foam_" .. n)
		end
		if mods and mods.Sim then
			for _, f in ipairs(mods.Sim.frames) do
				table.insert(names, f.mesh)
				if f.line then table.insert(names, f.line) end
			end
		end
		local list = {}
		for _, n in ipairs(names) do
			local t = kit:FindFirstChild(n)
			if t then list[#list + 1] = t end
		end
		if #list > 0 then
			pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
		end
	end)
end
ttPreload()

--- Is the lane at `center` further than TT_FAR from this client's camera AND its body? Then nothing here can be seen,
--- and the colliders (which only ever block this client's own body) cannot be reached before the walls go.
local function ttFar(center)
	local cam = workspace.CurrentCamera
	local camCF = cam and cam.CFrame
	if not camCF or (camCF.Position - center).Magnitude <= TT_FAR then return false end
	local me = Players.LocalPlayer
	local root = me and me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	return not (root and (root.Position - center).Magnitude <= TT_FAR)
end

--- Twin Tide on the lane centred at `center` (on the floor), running along `axis`, cast at server time `t0`. Returns the
--- effect's model (nil when nothing is drawn).
function AquaFX.TwinTide(center, axis, t0)
	local mods = ttLoad()
	if not mods then return nil end
	local TTPose, TABLE, SIM = mods.Pose, mods.Table, mods.Sim
	local W = A.TwinTide
	axis = flat(axis)
	if axis.Magnitude < 1e-3 then return nil end
	axis = axis.Unit
	-- a cast in another zone (or far across one) costs this client nothing: see COST in the header
	if ttFar(center) then return nil end
	local right = axis:Cross(Vector3.yAxis)
	local TR = TABLE.travel or {}
	local closeT = TR.closeTime or TABLE.closeTime or W.CloseTime
	if math.abs(closeT - W.CloseTime) > 1e-3 then
		warnOnce("ttClose", ("Twin Tide: AquaTuning CloseTime %.2f is not the pose table's %.2f - the walls meet at %.2f, "
			.. "the crush lands at %.2f"):format(W.CloseTime, closeT, closeT, W.CloseTime))
	end
	local startT = os.clock() - math.max(0, serverNow() - (t0 or serverNow()))
	local J = TABLE.jet
	local handT = SIM and SIM.frames[1].t or math.huge                -- the flipbook takes over here (CloseTime)
	local simEnd = SIM and (SIM.frames[#SIM.frames].t + (SIM.frameTime or 0.05)) or 0
	local fallEnd = math.max(TABLE.endTime or closeT, J and J.stop or 0) -- no flipbook: the table is played out
	-- the server's wet strip (castTwinTide) ends here: the wet ground we leave ends with it
	local wetEnd = W.CloseTime + W.HoldTime + W.SinkTime + A.Current.WetLife
	-- the sides (see the header): side +1 on the caster's LEFT, toP pointing from the seam at it; each wall's SEAM frame is
	-- its rotation at the lane's centre on the floor (seam[1]: the collar's, the jet's and every flipbook frame's)
	local toP = -right
	local seam = { [1] = CFrame.lookAt(center, center - toP), [-1] = CFrame.lookAt(center, center + toP) }
	local fp = SIM and SIM.footprint and SIM.footprint.pool

	--- The wet ground left behind, until the server's strip dries: over the flood's footprint once there was a flood,
	--- else over the lane (as before).
	local function layWet(e, flooded)
		local life = wetEnd - e
		if life < 0.3 then return end
		if flooded and fp then
			AquaFX.WetLane(seam[1] * fp.centre, axis, fp.across, fp.along, life)
		else
			AquaFX.WetLane(center, axis, W.StartGap, W.Length, life)
		end
	end

	-- a message this late (a joiner, a hitch) finds the crash over: only the wet ground is left to lay
	local e0 = os.clock() - startT
	if e0 >= (SIM and simEnd or fallEnd) then
		layWet(e0, SIM ~= nil)
		return nil
	end

	local m = model("AquaTwinTide")
	local walls = {}
	for _, side in ipairs({ 1, -1 }) do
		-- this side's skinned pieces, in a top-level Model of their own so their bone names are unique where they are
		-- looked up (see the header); destroyed with the effect's model in finish()
		local rig = model(("AquaTwinTideSide%+d"):format(side))
		walls[#walls + 1] = {
			Side = side, Rig = rig, Stages = {}, Lip = nil, Cap = nil,
			Col = collider(Vector3.new(W.Length, W.Height, TT_COLLIDER_T), HIDE, m),
			Showing = nil, ShowingN = 0, CapShown = false, ColOn = false, LipLit = true, Drops = {},
		}
	end
	local collar, collarShown = nil, false
	local jets, jetLines = {}, {}
	local frames, lines = {}, {}
	local rigsDirect, rigsFlat = 0, 0

	-- THE CLAW DROPS' COUNT (TTPose.dropCount), read before any rig is parsed: 0 means the walls have no claws, so their
	-- weightless Claw/ClawTip bones are left at rest (TT_UNPOSED); any other count means claws, and they are posed.
	local nDrops, clawEnd = 0, -1
	do
		local okN, n = pcall(TTPose.dropCount, TABLE)
		if okN and type(n) == "number" and n > 0 then
			nDrops = n
			for _, d in ipairs(TABLE.drops.list) do clawEnd = math.max(clawEnd, d.e + TABLE.drops.life) end
		end
	end
	local unposed = (nDrops == 0) and TT_UNPOSED or nil

	--- A skinned piece: cloned into `parent` (default the effect's model), rid of anything that could animate it over
	--- us, its bones parsed.
	local function rigged(name, kind, parent)
		local p = take(name, kind, parent or m)
		if not p then return nil end
		for _, d in ipairs(p:GetDescendants()) do
			if d.Parent and (d:IsA("Animator") or d:IsA("AnimationController") or d:IsA("Humanoid")) then
				warnOnce("ttAnim" .. name, name .. " carries a " .. d.ClassName .. " (the importer's): removed from the "
					.. "clone - remove it from the kit")
				d:Destroy()
			end
		end
		-- never resized here, so an import at the wrong scale would show as it came: say so once
		local ts = p:GetAttribute("TemplateSize")
		if typeof(ts) == "Vector3" and (p.Size - ts).Magnitude > 0.01 * ts.Magnitude then
			warnOnce("ttSize" .. name, ("%s is %s but its TemplateSize is %s - a skinned part is never resized, so it is "
				.. "drawn at the imported size: re-import it at 1 m = 1 stud"):format(name, tostring(p.Size), tostring(ts)))
		end
		local rig = ttRig(p, TTPose, TABLE, unposed)
		if rig.Count == 0 then
			warnOnce("ttBones" .. name, name .. " has no bones the pose table drives (C<n>_<Chain>...) - it is shown unposed")
		end
		if rig.Direct then rigsDirect += 1 else rigsFlat += 1 end
		if TT_PROBE then
			m:SetAttribute("TTRigsDirect", rigsDirect)
			m:SetAttribute("TTRigsFlat", rigsFlat)
		end
		return { Part = p, Rig = rig }
	end

	-- THE BUILD: every clone is queued for the window it is needed in and made a few a Heartbeat over the approach (the
	-- 65 flipbook parts included), so the handover never waits on a clone; anything needed within TT_BUILD_LEAD is made
	-- at once, and anything whose window has passed (a late start) is never made -- each colour stage has its own window
	-- (from its key to the next key: TTPose.wallStage's rule), so a late start never clones a stage it will not show.
	local queue, qi = {}, 1
	local function later(need, untilT, fn)
		queue[#queue + 1] = { Need = need, Until = untilT, Fn = fn }
	end
	local rigUntil = SIM and handT or fallEnd
	-- a start this close to the handover (a hitch, a slow link) goes straight to the flipbook: the walls would show for a
	-- few frames at most, and every skinned piece they need would have to be cloned at once, on a client already behind
	local rigOn = (SIM == nil) or e0 <= handT - TT_BUILD_LEAD
	local stageFrom, stageUntil = {}, {}
	do
		local K = table.clone(TABLE.stages.keys)
		table.sort(K, function(a, b) return a[1] < b[1] end)
		for i, k in ipairs(K) do
			local n = k[2]
			local from = (i == 1) and 0 or k[1]                    -- the first key's stage shows from the cast
			local to = math.min(K[i + 1] and K[i + 1][1] or rigUntil, rigUntil)
			stageFrom[n] = math.min(stageFrom[n] or math.huge, from)
			stageUntil[n] = math.max(stageUntil[n] or -math.huge, to)
		end
	end
	if rigOn then
		for _, w in ipairs(walls) do
			for n, from in pairs(stageFrom) do
				later(from, stageUntil[n], function() w.Stages[n] = rigged("AK_TT_Wall_" .. n, "solid", w.Rig) end)
			end
			later(0, rigUntil, function()
				w.Lip = rigged("AK_TT_Lip", "line", w.Rig)
				if w.Lip then ttLine(w.Lip.Part, true) end
			end)
			if TABLE.cap then
				later(TABLE.cap.show, rigUntil, function()
					w.Cap = rigged("AK_TT_Cap", "solid", w.Rig)
					-- review round 2: "Stop the claw meshes and the thrown lip drops from casting shadows ... Keep the wall
					-- bodies casting shadows" -- and with the claws gone the builder found the crawl on the far wall's
					-- inner face (0.83-0.96 s) is "the lip's and the cap's own cast shadow ... The reviewer's CastShadow
					-- note would cover it" (noclaw.json). The Tideline is shadowless already (a line); the cap is not.
					if w.Cap then w.Cap.Part.CastShadow = false end
				end)
			end
		end
		if TABLE.collar then
			later(TABLE.collar.show, rigUntil, function() collar = rigged("AK_TT_Collar", "solid") end)
		end
		if J and J.stages then
			for n, s in ipairs(J.stages) do
				later(s.e, math.min(J.stop, rigUntil), function()
					jets[n] = take(s.mesh or ("AK_TT_Jet_" .. n), "solid", m)
					jetLines[n] = take(s.line or ("AK_TT_JetLine_" .. n), "line", m)
					ttLine(jetLines[n], true)
				end)
			end
		end
	end
	if TT_PROBE then m:SetAttribute("TTRigOn", rigOn) end
	if SIM then
		local ft = SIM.frameTime or 0.05
		for k, f in ipairs(SIM.frames) do
			later(f.t, f.t + ft, function()
				frames[k] = take(f.mesh, "solid", m)
				if f.line then
					lines[k] = take(f.line, "line", m)
					ttLine(lines[k], true, SIM.lineColour)
				end
			end)
		end
	end
	table.sort(queue, function(a, b) return a.Need < b.Need end)
	local function build(e)
		local made = 0
		while qi <= #queue do
			local q = queue[qi]
			if made >= TT_BUILD_PER_BEAT and q.Need > e + TT_BUILD_LEAD then break end
			qi += 1
			if e <= q.Until then
				q.Fn()
				made += 1
			end
		end
	end

	-- THE POSE, this frame: each (chain, column) evaluated once and shared by both walls, both lips (the lip's bones
	-- take "the SAME Transforms as the wall's bones of the same column and chain") and anything else posed this frame
	local curE, stamp, evals, writes = 0, 0, 0, 0
	local cacheCF, cacheAt = {}, {}
	local function T(b)
		local key = b.Key
		if cacheAt[key] ~= stamp then
			cacheCF[key] = TTPose.transform(TABLE, b.Chain, b.Column, curE)
			cacheAt[key] = stamp
			evals += 1
		end
		return cacheCF[key]
	end
	local function pose(piece)
		if piece and piece.Rig then writes += poseRig(piece.Rig, T) end
	end
	-- how far out of the ground the walls are: the middle column's Foot carries the whole wall's rise (tbl.liftChains)
	local riseCol = math.max(1, math.floor((#TABLE.columns + 1) / 2))
	local riseRef = (TABLE.columns[riseCol] and TABLE.columns[riseCol].keys.Foot)
		and { Key = "Foot" .. riseCol, Chain = "Foot", Column = riseCol } or nil

	--- The showing colour stage; a missing one (no template) is stood in for by the nearest one that was made.
	local function stagePiece(w, n)
		if w.Stages[n] then return w.Stages[n], n end
		for d = 1, TT_STAGES do
			if w.Stages[n - d] then return w.Stages[n - d], n - d end
			if w.Stages[n + d] then return w.Stages[n + d], n + d end
		end
		return nil, 0
	end

	-- THE WALLS, one frame
	local jetShown, jetFlash, jetLineShown, flashDone, flashes = 0, false, 0, false, 0
	local function wallsFrame(e)
		local off = TTPose.travel(e, TR.closeTime, TR.start, TR.meet, TR.hold, TR.tau)
		local stage = TTPose.wallStage(TABLE, e)
		local lipLit, jetLit = TTPose.lines(TABLE, e)
		local capOn = TTPose.capOn(TABLE, e)
		local standing = false
		if e < closeT then
			if riseRef then
				standing = (W.Height + T(riseRef).Position.Y) / W.Height >= TT_COLLIDER_RISE
			else
				standing = e >= 0.1
			end
		end
		for _, w in ipairs(walls) do
			local base = center + toP * (w.Side * off)
			local originCF = CFrame.lookAt(base, base - toP * w.Side)
			-- the stage showing: its bones written BEFORE it is shown, then the one it replaces hidden
			local piece, n = stagePiece(w, stage)
			if piece then
				pose(piece)
				pin(piece.Part, originCF)
			end
			if w.Showing ~= piece then
				if w.Showing then w.Showing.Part.CFrame = HIDE end
				w.Showing, w.ShowingN = piece, n
			end
			-- its Tideline: lit while the water moves, dark from lines.lipDarkAt
			if w.Lip then
				pose(w.Lip)
				pin(w.Lip.Part, originCF)
				if w.LipLit ~= lipLit then
					w.LipLit = lipLit
					ttLine(w.Lip.Part, lipLit)
				end
			end
			-- the crest foam cap
			if w.Cap then
				if capOn then
					pose(w.Cap)
					pin(w.Cap.Part, originCF)
					w.CapShown = true
				elseif w.CapShown then
					w.Cap.Part.CFrame = HIDE
					w.CapShown = false
				end
			end
			-- the collider, while the wall stands (as before: from a third of its height up to the meeting)
			if standing then
				w.Col.CFrame = originCF * CFrame.new(0, W.Height / 2, 0)
				w.ColOn = true
			elseif w.ColOn then
				w.Col.CFrame = HIDE
				w.ColOn = false
			end
		end
		-- the foam collar bridging the lips, in the seam frame; its bones run on world time (tbl.unwarpedChains)
		if collar then
			if TTPose.collarOn(TABLE, e) then
				pose(collar)
				pin(collar.Part, seam[1])
				collarShown = true
			elseif collarShown then
				collar.Part.CFrame = HIDE
				collarShown = false
			end
		end
		-- the jet: one stage at a time, at scale 1, in the seam frame; its ONE flash latched so it shows on at least one
		-- frame however the Heartbeats fall (it lasts 0.02 s), Neon #4FBDF6, never white
		local st, fl = TTPose.jet(TABLE, e)
		if st > 0 and not flashDone and J and J.flash and e >= J.flash.e then fl = true end
		if fl and st > 0 then
			if not flashDone then flashes += 1 end
			flashDone = true
		end
		if st ~= jetShown then
			local old = jets[jetShown]
			if old then
				old.CFrame = HIDE
				if jetFlash then setKind(old, "solid") end
			end
			jetFlash = false
			if jets[st] then place(jets[st], seam[1], 1) end
			jetShown = st
		end
		local want = fl and st > 0
		if jets[st] and want ~= jetFlash then
			if want then
				jets[st].Material = Enum.Material.Neon
				jets[st].Color = TT_FLASH
			else
				setKind(jets[st], "solid")
			end
			jetFlash = want
		end
		-- its rim line, the leading edge once the lips go dark
		local ls = (jetLit and st > 0) and st or 0
		if ls ~= jetLineShown then
			if jetLines[jetLineShown] then jetLines[jetLineShown].CFrame = HIDE end
			if jetLines[ls] then place(jetLines[ls], seam[1], 1) end
			jetLineShown = ls
		end
	end

	--- Every rig piece away at the handover (they are destroyed with the model at the end).
	local function hideRig()
		for _, w in ipairs(walls) do
			for _, s in pairs(w.Stages) do s.Part.CFrame = HIDE end
			if w.Lip then w.Lip.Part.CFrame = HIDE end
			if w.Cap then w.Cap.Part.CFrame = HIDE end
			w.Col.CFrame = HIDE
			w.Showing, w.ShowingN, w.ColOn, w.CapShown = nil, 0, false, false
		end
		if collar then collar.Part.CFrame = HIDE end
		for _, p in pairs(jets) do p.CFrame = HIDE end
		for _, p in pairs(jetLines) do p.CFrame = HIDE end
	end

	-- THE CLAW DROPS (TTPose.drop): capped pieces, each wall's list in its own seam frame, aimed and stretched by the
	-- evaluator. None while the table has none (dropCount 0 since the claws went; nDrops is read above); a loop that
	-- runs no times. A drop still in the air at the last Heartbeat before clawEnd is ended by the next call, so the calls
	-- go on while any is live (TTPose.drop is false past its life).
	local clawLive = 0
	local function clawDrops(e)
		for _, w in ipairs(walls) do
			for i = 1, nDrops do
				local on, cf, sc = TTPose.drop(TABLE, i, e)
				local p = w.Drops[i]
				if on then
					if not p and live < SPLASH_CAP then           -- the pool full: this one is skipped
						p = take("AK_WG_Drop", "solid", m)
						if p then
							live += 1
							clawLive += 1
							p.CastShadow = false                     -- review round 2: no drop shadows crawling on the face
							w.Drops[i] = p
						end
					end
					if p then place(p, seam[w.Side] * cf, sc) end
				elseif p then
					p:Destroy()
					live -= 1
					clawLive -= 1
					w.Drops[i] = nil
				end
			end
		end
	end

	-- THE FLIPBOOK, one frame: frame k over [t_k, t_k+1), one visible at a time; a frame that is missing holds the one
	-- before it. The first frame shown IS the handover: every rig piece goes at once.
	local handedOver = false
	local simK, shownFrame, shownLine, lineDark = 0, nil, nil, false
	local function simStep(e)
		local F = SIM.frames
		local k = simK
		while k < #F and e >= F[k + 1].t do k += 1 end
		if k == simK or k == 0 then return end
		simK = k
		local part = frames[k]
		if part then
			place(part, seam[1], 1)
			if shownFrame and shownFrame ~= part then shownFrame.CFrame = HIDE end
			shownFrame = part
			if not handedOver then
				handedOver = true
				hideRig()
			end
		end
		if not handedOver then return end
		-- the Tideline on the moving edge; the frame its water stops the last one goes dark, and then it is gone
		local lp = lines[k]
		if lp then
			place(lp, seam[1], 1)
			if shownLine and shownLine ~= lp then shownLine.CFrame = HIDE end
			shownLine, lineDark = lp, false
		elseif shownLine and not F[k].line then
			if not lineDark then
				ttLine(shownLine, false)
				lineDark = true
			else
				shownLine.CFrame = HIDE
				shownLine = nil
			end
		end
	end

	-- THE SIM'S OWN WATER, thrown at its times (tt_sim_drops.json), in the seam frame. Capped: past the kit's SPLASH_CAP
	-- the optional pieces go first -- the rain, then the islands, then the rim (the manifest's order) -- and the foam
	-- flecks with the rain. The gravities are the sim's own, absolute (fling multiplies KIT_GRAVITY).
	local function simDrop(d, gravity)
		local room = (d.src == "rain" and 20) or (d.src == "island" and 10) or 0
		if live >= SPLASH_CAP - room then return end
		local g = (gravity or 117.72) / KIT_GRAVITY
		local at = seam[1] * d.pos
		local v = seam[1]:VectorToWorldSpace(d.vel)
		local s = 2 * d.radius / TT_DROP_W                           -- AK_WG_Drop 2 x radius wide
		if d.landOn == "none" then
			-- still in the air when the sim ended: an ordinary drop, splashing wherever it comes down
			fling("AK_WG_Drop", at, v, s, 1.5, 0, g, false, nil, { Aim = true, Shadow = false })
		else
			-- the sim's arc meets the flipbook's water at landT, a surface no ray can hit: the landing is known -- a small
			-- crown on the pool, or simply gone into a mound
			local land = (d.landOn == "pool")
				and { Size = TT_LAND_CROWN, Mesh = "AK_SA_Splash", At = seam[1] * d.landPos, Life = 0.3 } or {}
			fling("AK_WG_Drop", at, v, s, math.max(0.03, d.landT - d.t), 0, g, true, nil,
				{ Aim = true, Tail = 0, Land = land, Shadow = false })
		end
	end
	local function simFleck(d, FL)
		if live >= SPLASH_CAP - 20 then return end
		local n, best = 1, math.huge
		for i, len in ipairs(TT_FOAM_LEN) do
			if math.abs(len - d.size) < best then n, best = i, math.abs(len - d.size) end
		end
		-- foam that HANGS: 0.25 g with drag, a slow tumble, shrinking over its last 0.3 s
		fling("AK_RT_Foam_" .. n, seam[1] * d.pos, seam[1]:VectorToWorldSpace(d.vel), d.size / TT_FOAM_LEN[n], d.hang, 1.5,
			(FL.gravity or 49.05) / KIT_GRAVITY, true, nil, { Drag = FL.drag or 1.2, Tail = 0.3, Shadow = false })
	end
	local di, fi, si = 1, 1, 1
	local function simSpawns(e)
		local D = SIM.drops
		if D and D.list then
			while di <= #D.list and D.list[di].t <= e do
				local d = D.list[di]
				di += 1
				if e - d.t < 0.2 and e < d.landT then simDrop(d, D.gravity) end
			end
		end
		local FL = SIM.flecks
		if FL and FL.list then
			while fi <= #FL.list and FL.list[fi].t <= e do
				local d = FL.list[fi]
				fi += 1
				if e - d.t < 0.2 then simFleck(d, FL) end
			end
		end
		-- the second slam: the falling curtain hits the pool -- crowns sitting on it, "~3-4 studs across" (v4: smaller)
		local S = SIM.slam
		if S then
			while si <= #S and S[si].t <= e do
				local ev = S[si]
				si += 1
				if e - ev.t < 0.2 then
					crown(seam[1] * ev.pos, ev.crownScale * TT_SLAM_ACROSS / TT_SA_W, Vector3.yAxis, "AK_SA_Splash", 0.5)
				end
			end
		end
	end

	-- THE END: everything this made goes with the model and the two side models (the flung water was never its own: it
	-- lives out its arc)
	local done, wetLaid = false, false
	local conn
	local function finish(e, wet)
		if done then return end
		done = true
		if conn then conn:Disconnect() end
		for _, w in ipairs(walls) do
			for i in pairs(w.Drops) do w.Drops[i] = nil end
		end
		live -= clawLive
		clawLive = 0
		if m.Parent then m:Destroy() end
		for _, w in ipairs(walls) do
			if w.Rig.Parent then w.Rig:Destroy() end
		end
		if wet and not wetLaid then
			wetLaid = true
			layWet(e, handedOver or (SIM ~= nil and e >= simEnd))
		end
	end

	-- the jet's flash (1.08 s, 0.02 s long) is owed before the handover: at a low frame rate no Heartbeat may fall inside
	-- it, and the frame at 1.10 would hand over first -- so the walls get that one frame more to draw it (only within
	-- 0.1 s of the handover: a late start never brings the walls back for it)
	local flashDue = rigOn and J and J.flash and J.stages and #J.stages > 0 and J.flash.e < handT

	local function step()
		local e = os.clock() - startT
		curE = e
		stamp += 1
		evals, writes = 0, 0
		build(e)
		local owed = flashDue and not flashDone and not handedOver and e < handT + 0.1
		if SIM and e >= handT and not owed then simStep(e) end
		if rigOn and not handedOver then wallsFrame(e) end
		if rigOn and nDrops > 0 and (e <= clawEnd or clawLive > 0) then clawDrops(e) end
		if handedOver then simSpawns(e) end
		local endT = handedOver and simEnd or fallEnd
		-- the wet ground goes down under the torn puddles just before the last frame goes, so no dry floor shows
		if not wetLaid and e >= endT - (handedOver and TT_WET_LEAD or 0) then
			wetLaid = true
			layWet(e, handedOver)
		end
		if TT_PROBE then
			m:SetAttribute("TTE", math.floor(e * 1000 + 0.5) / 1000)
			m:SetAttribute("TTStage", handedOver and 0 or (walls[1].ShowingN or 0))
			m:SetAttribute("TTBones", writes)
			m:SetAttribute("TTEvals", evals)
			m:SetAttribute("TTSimFrame", handedOver and simK or 0)
			m:SetAttribute("TTBuilt", qi - 1)
			m:SetAttribute("TTQueue", #queue)
			m:SetAttribute("TTFlashes", flashes)
			m:SetAttribute("TTLive", live)
		end
		if e >= endT then finish(e, true) end
	end

	local function guarded()
		local ok, err = pcall(step)
		if not ok then
			warnOnce("ttStep", "Twin Tide stopped drawing: " .. tostring(err))
			finish(os.clock() - startT, true)
		end
	end
	conn = RunService.Heartbeat:Connect(function()
		if done then return end
		if not m.Parent then
			finish(os.clock() - startT, false)
			return
		end
		guarded()
	end)
	guarded()                                                -- the first frame now: bones written before anything shows
	return m
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: SIDEARM -- the water-gun drawn and held out, its shots, drops dripping; the bullets and their splashes
----------------------------------------------------------------------------------------------------
--- The gun, built round a frame the caller supplies every frame -- where the HAND holds it (first person: the
--- viewmodel's right fist, aimed at the crosshair; third person: the body's right hand) -- `k` times full size.
--- AK_SA_Gun + the spinning AK_SA_Coil + the muzzle's Tideline AK_SA_Muzzle, and drops forming and falling from its
--- drip points (the owner: "water drops dripping for extra feeling"). The owner, 2026-09-25: "it should look like you
--- hold out a gun and then shoot". So it is:
---   DRAWN    over DrawTime it forms out of water in the hand -- from a third of its size, swung up from low and tipped
---            down into the aim, the coil spinning hard, drops shaken off it;
---   HELD OUT every shot KICKS it (back and up, easing home in 0.12 s), flashes the muzzle's Tideline white and throws a
---            puff of spray off the muzzle;
---   CHARGED  (first person, SetPalm) the other hand charges it again after every shot -- the owner, 2026-09-25: "match it
---            for when he shoots and the hand then like charges the gun with aqua power ... dont make it those goofy
---            bullets". The shot SPENDS it: the Tidelines drop to dim and the barrel coil slows. A swirl of water (a second
---            AK_SA_Coil) gathers round the fist as the hand winds back, leaves the hand as the palm drives onto the
---            reservoir, wraps the reservoir spinning and is forced in (it shrinks inside); the Tidelines light as it
---            goes in and the coil speeds up; READY is a white flash, and the next shot leaves from a full gun. No drops.
---   PUT AWAY (Holster) it drops and shrinks into water over HolsterTime, shedding drops, and is gone.
--- Placed from its own render step AFTER the arms (Camera + 3; the viewmodel's Update is Camera + 2): on a plain
--- RenderStepped it stood on LAST frame's fist under THIS frame's camera -- a frame of your own motion off the hand,
--- 0.4 stud at a run (the owner, 2026-09-25: "if you are running and hold the gun, the hand animation is like very
--- bugged").
--- Returns { Kick(), Muzzle(), Reservoir(), SetPalm(fn), ChargeUntil(t), Phase(), BodyOffset(now), Holster(), Destroy() }.
local DRIPS = { "drip_1", "drip_2", "drip_3", "drip_4" }
local FLASH = Color3.fromRGB(183, 222, 248)
local gunSteps = 0           -- each gun binds its own uniquely named render step

-- THE CHARGE. Phase marks run 0 (a shot just left) .. 1 (charged).
local RES_C = Vector3.new(0, 0.43, 0.44)   -- the reservoir's centre from the hand-hold, gun units (piece_sa.py rc)
local CH = {
	Form = 0.13,       -- the swirl gathers round the fist from here...
	Transfer = 0.30,   -- ...leaves the hand for the reservoir as the palm drives in...
	Sink = 0.42,       -- ...wraps it and is forced in...
	Ready = 0.83,      -- ...and is gone into it: READY
	HandScale = 0.82,  -- AK_SA_Coil round the fist, absolute (a helix r ~0.25 over the forearm's corners)
	HandBack = 0.2,    -- its centre this far down the forearm from the fingertips
	WrapScale = 1.55,  -- round the reservoir, x the gun's scale (a helix r 0.47 over the reservoir's 0.40)
	InScale = 1.0,     -- shrunk to this it is inside the reservoir
	LitFrom = 0.42,    -- the Tidelines: dim from the shot, brightening from here...
	LitFull = 0.80,    -- ...to full here
	Flash = 0.07,      -- READY's white flash, seconds
}

function AquaFX.SidearmGun(frameFn, k)
	local S = A.Sidearm
	k = k or 1
	local m = model("AquaSidearm")
	local gun = take("AK_SA_Gun", "solid", m)
	local coil = take("AK_SA_Coil", "solid", m)
	local muzzle = take("AK_SA_Muzzle", "line", m)
	if muzzle then muzzle.Color = COL.TidelineDim end
	local ts = VFXLibrary.ShotTimeScale()
	local born = os.clock()
	local lastShot = -10
	local holsterAt = nil
	local spin = 0
	local last = os.clock()
	local handle = {}
	local lastFrame = nil
	local shook = false
	local dead = false
	-- a drop per drip point: forming (AK_SA_Drip_1 grows on the point), then falling (AK_SA_Drip_2)
	local drips = {}
	for i, pname in ipairs(DRIPS) do
		drips[i] = { Point = pname, Next = os.clock() + 0.15 + i * 0.23 + math.random() * 0.3, Forming = nil, Born = 0 }
	end
	-- the charge: 0 = spent (a shot just left), 1 = charged; it reaches 1 at Deadline. Born charged: the gun forms out of
	-- the hand's water. Palm = nil (other players' guns, third person): no charge is drawn.
	local charge = { Phase = 1, Deadline = nil, Palm = nil, Spin = 0, ReadyAt = -10, Fallback = false }
	local swirl, resLine = nil, nil

	local function frame()
		local ok, cf = pcall(frameFn)
		return ok and cf or nil
	end

	local function dropFall(at, s)
		local p = take("AK_SA_Drip_2", "solid")
		if not p then return end
		local v = Vector3.new(0, -1, 0)
		local pos = at
		local b0 = os.clock()
		local c
		c = RunService.Heartbeat:Connect(function(dt)
			local e = os.clock() - b0
			if e > 0.7 or not p.Parent then
				c:Disconnect()
				if p.Parent then p:Destroy() end
				return
			end
			v += Vector3.new(0, -KIT_GRAVITY * 0.4 * dt, 0)
			pos += v * dt
			place(p, CFrame.new(pos), s * math.max(0.1, 1 - smooth((e - 0.45) / 0.25)))
		end)
	end

	--- The gun body relative to the frame it is held by -- the draw, the kick, the holster -- and its size.
	local function bodyOffset(now)
		local d = easeOut((now - born) / (S.DrawTime / ts))
		local h = holsterAt and smooth((now - holsterAt) / (S.HolsterTime / ts)) or 0
		local low = (1 - d) + h
		local kk = clamp01(1 - (now - lastShot) / 0.12)
		kk = kk * kk
		local drawCF = CFrame.new(0, -0.55 * k * low, 0.15 * k * low) * CFrame.Angles(math.rad(-40) * low, 0, 0)
		local kickCF = CFrame.new(0, 0.04 * k * kk, 0.22 * k * kk) * CFrame.Angles(math.rad(9) * kk, 0, 0)
		return drawCF * kickCF, k * (0.35 + 0.65 * d) * (1 - 0.85 * h), d, h
	end
	--- Where the gun stands this frame, and at what size.
	local function pose(cf, now)
		local off, s, d, h = bodyOffset(now)
		return cf * off, s, d, h
	end

	local function chargeTone(now)
		if now - lastShot < 0.05 or now - charge.ReadyAt < CH.Flash then return FLASH end
		return COL.TidelineDim:Lerp(COL.Tideline, smooth((charge.Phase - CH.LitFrom) / (CH.LitFull - CH.LitFrom)))
	end

	--- The charge this frame: its clock, the reservoir's Tideline, the swirl (hand -> reservoir -> in).
	local function drawCharge(cf, s, h, now, dt)
		-- the clock arrives at 1 exactly at the deadline (the next shot, or the gun being put away), whatever the rate:
		-- 0.625 s held, 0.31 s after a tap. Past due (the key came up late): it finishes in 0.1 s.
		local was = charge.Phase
		if was < 1 then
			local due = charge.Deadline or (lastShot + (1 / S.FireRate) / ts)
			local left = due - now
			charge.Phase = math.min(1, was + dt * (left > dt and (1 - was) / left or 10))
			if was < CH.Ready and charge.Phase >= CH.Ready then charge.ReadyAt = now end
		end
		local ph = charge.Phase
		charge.Spin += dt * ts * (18 + 14 * ph)                        -- faster as it is forced in
		local resCF = cf * CFrame.new(RES_C * s)
		-- the reservoir's Tideline (AK_SA_ResLine: its origin is the hand-hold, like the gun's; until it is uploaded, a
		-- second muzzle ring stands in round the reservoir)
		if resLine then
			if charge.Fallback then place(resLine, resCF, s * CH.WrapScale) else place(resLine, cf, s) end
			if h > 0 then
				if resLine.Material ~= Enum.Material.SmoothPlastic then setKind(resLine, "dark") end
			else
				resLine.Color = chargeTone(now)
			end
		end
		if not swirl then return end
		local okP, palm = pcall(charge.Palm)
		if not okP or typeof(palm) ~= "CFrame" then palm = nil end
		if h > 0 or ph < CH.Form or ph >= CH.Ready or (not palm and ph < CH.Sink) then
			swirl.CFrame = HIDE
			return
		end
		local spinCF = CFrame.Angles(0, 0, charge.Spin)                 -- about its own Z: the forearm, then the barrel
		if ph < CH.Transfer then
			-- 1. it gathers round the fist as the hand winds back
			local g = easeOut((ph - CH.Form) / (CH.Transfer - CH.Form))
			place(swirl, palm * CFrame.new(0, 0, CH.HandBack) * spinCF, CH.HandScale * (0.2 + 0.8 * g))
		elseif ph < CH.Sink then
			-- 2. the palm drives in; the swirl leaves the hand for the reservoir, turning onto the barrel's axis
			local u = smooth((ph - CH.Transfer) / (CH.Sink - CH.Transfer))
			local handCF = palm * CFrame.new(0, 0, CH.HandBack)
			place(swirl, handCF:Lerp(resCF, u) * spinCF, CH.HandScale + (CH.WrapScale * s - CH.HandScale) * u)
		else
			-- 3. wrapped round the reservoir, spinning, forced in: it shrinks inside and is gone at READY
			local v = smooth((ph - CH.Sink) / (CH.Ready - CH.Sink))
			place(swirl, resCF * spinCF, s * (CH.WrapScale + (CH.InScale - CH.WrapScale) * v))
		end
	end

	gunSteps += 1
	local stepName = "AquaSidearmGun_" .. gunSteps
	RunService:BindToRenderStep(stepName, Enum.RenderPriority.Camera.Value + 3, function()
		if dead then return end
		local now = os.clock()
		local dt = now - last
		last = now
		if not m.Parent then                                   -- removed from outside: unbind, or this step runs forever
			handle.Destroy()
			return
		end
		local base = frame()
		if not base then
			-- no hand to hold it any more (another player left or respawned mid-hold): once it is being put away it is simply
			-- gone -- before, the step returned here every frame and the gun hung frozen in the air for the whole session
			if holsterAt and now - holsterAt >= S.HolsterTime / ts then handle.Destroy() end
			return
		end
		local cf, s, d, h = pose(base, now)
		lastFrame = cf
		if gun then place(gun, cf, s) end
		-- shaken off as it forms: water falling away from the hand
		if not shook and d > 0.5 then
			shook = true
			spray(cf.Position, 3, 3, 3, 1.6 * k, nil, 0.8)
		end
		-- the coil sleeve rides the barrel (its gun_origin point sits on the gun's origin); it spins hard while the gun
		-- forms and while it fires -- charged by the hand, it slows when a shot spends it and speeds up as it charges
		local firing = now - lastShot < (1 / S.FireRate + 0.1) / ts
		local rate = (d < 1 or (not charge.Palm and firing)) and 16 or 2
		if charge.Palm and d >= 1 then rate = 2 + 16 * charge.Phase * charge.Phase end
		spin += dt * rate
		if coil then
			local g = coil:GetAttribute("P_gun_origin") or Vector3.zero
			local coilPivot = cf * CFrame.new(-g * s)
			local ofp = coil:GetAttribute("OriginFromPivot") or Vector3.zero
			local axisCF = coilPivot * CFrame.new(ofp * s)
			place(coil, axisCF * CFrame.Angles(0, 0, spin), s)
		end
		if muzzle and gun then
			local mz = pointOf(gun, "muzzle", s)
			if mz then place(muzzle, mz, s) end
			if h > 0 then
				setKind(muzzle, "dark")                        -- being put away: the water has stopped
			elseif charge.Palm then
				muzzle.Color = chargeTone(now)                 -- flash at the shot, dim (spent), lit as it charges, READY
			elseif now - lastShot < 0.05 then
				muzzle.Color = FLASH
			elseif firing then
				muzzle.Color = COL.Tideline
			else
				muzzle.Color = COL.TidelineDim
			end
		end
		if charge.Palm then drawCharge(cf, s, h, now, dt) end
		-- the drips
		if gun and h == 0 then
			for _, dr in ipairs(drips) do
				local at = pointOf(gun, dr.Point, s)
				if at then
					if dr.Forming then
						local age = now - dr.Born
						local g = clamp01(age / 0.45)
						-- it hangs with its top at the point: its centre half a drop below
						place(dr.Forming, CFrame.new(at.Position - Vector3.new(0, 0.09 * s * g, 0)), s * math.max(0.1, g))
						if age >= 0.45 then
							dr.Forming:Destroy()
							dr.Forming = nil
							dropFall(at.Position - Vector3.new(0, 0.1 * s, 0), s)
							dr.Next = now + 0.25 + math.random() * 0.6
						end
					elseif now >= dr.Next then
						dr.Forming = take("AK_SA_Drip_1", "solid", m)
						dr.Born = now
					end
				end
			end
		end
		if holsterAt and h >= 1 then
			-- gone into water
			spray(cf.Position, 4, 2, 3, 1.3 * k, nil, 0.8)
			handle.Destroy()
		end
	end)

	--- A shot leaves: the kick, the white flash on the muzzle's Tideline, spray off the muzzle; it spends the charge.
	function handle.Kick()
		lastShot = os.clock()
		charge.Phase, charge.Deadline = 0, nil
		if muzzle and muzzle.Parent then
			local mz = muzzle.CFrame
			local look = mz.LookVector
			for _ = 1, 2 do
				local v = look * (10 + math.random() * 6) + randomUnitFlat() * 2 + Vector3.new(0, 1.5 + math.random() * 2, 0)
				fling("AK_WG_Drop", mz.Position + look * 0.1, v, 1.2 * k, 0.5, 5, 0.5)
			end
		end
	end
	function handle.Muzzle()
		if muzzle and muzzle.Parent then return muzzle.Position end
		return lastFrame and lastFrame.Position or Vector3.zero
	end
	--- The reservoir's centre in the world (this frame's).
	function handle.Reservoir()
		if lastFrame then
			local _, s = bodyOffset(os.clock())
			return (lastFrame * CFrame.new(RES_C * s)).Position
		end
		return gun and gun.Position or Vector3.zero
	end
	--- First person: the other hand charges the gun after every shot. fn() -> the left fist's CFrame (nil = none now).
	function handle.SetPalm(fn)
		charge.Palm = fn
		if fn and not swirl then
			swirl = take("AK_SA_Coil", "solid", m)
			if swirl then swirl.CFrame = HIDE end
			-- the reservoir's own Tideline (AK_SA_ResLine, on the reservoir's swirl bands). No stand-in until it is uploaded:
			-- a second muzzle ring round the reservoir read in play as a dark hood when dim and a white glare at the flash
			resLine = template("AK_SA_ResLine") and take("AK_SA_ResLine", "line", m) or nil
			if resLine then resLine.Color = COL.Tideline end
		end
	end
	--- The charge must be full by `t` (os.clock): the next shot while held, else the moment the gun is put away.
	function handle.ChargeUntil(t)
		charge.Deadline = t
	end
	--- 0 = spent (a shot just left) .. 1 = charged; 1 for a gun no hand charges.
	function handle.Phase()
		return charge.Palm and charge.Phase or 1
	end
	--- The gun body's offset from its held frame at `now` (the draw, the kick, the holster): AquaClient's gun hold puts
	--- the left hand on the gun body, kick and all.
	function handle.BodyOffset(now)
		return (bodyOffset(now or os.clock()))
	end
	--- Put it away: it drops and shrinks into water over HolsterTime, then is gone.
	function handle.Holster()
		if not holsterAt then holsterAt = os.clock() end
	end
	function handle.Destroy()
		if dead then return end
		dead = true
		pcall(RunService.UnbindFromRenderStep, RunService, stepName)
		m:Destroy()
	end
	return handle
end

--- One bullet: straight from `origin` along `dir` (the eye's line), drawn from `visualFrom` (the muzzle) easing onto it.
--- Every bullet is the same now (BulletScale; the owner: "make the bullets smaller", and the bigger first shot is gone);
--- `n` is its number in its hold, for the puddles. onHit(result) for the shooter's own copy; every copy stops on what it
--- meets and splashes, and sheds drops over its first stretch (water, not a pellet).
function AquaFX.FireSlug(origin, dir, n, exclude, visualFrom, onHit)
	local S = A.Sidearm
	n = (type(n) == "number" and n >= 1) and n or 2
	dir = dir.Unit
	local size = S.BulletScale
	local m = model("AquaSlug")
	local body = take("AK_SA_Slug", "solid", m)
	local lip = take("AK_SA_SlugLip", "line", m)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { fxFolder(), workspace.CurrentCamera }
	for _, e in ipairs(exclude or {}) do ex[#ex + 1] = e end
	params.FilterDescendantsInstances = ex
	local travelled = 0
	local from = visualFrom or origin
	local scale = VFXLibrary.ShotTimeScale()
	local roll = 0
	local shed = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not m.Parent then
			conn:Disconnect()
			return
		end
		local step = S.Speed * scale * dt
		local a = origin + dir * travelled
		local hit = workspace:Raycast(a, dir * step, params)
		local b = hit and hit.Position or (a + dir * step)
		travelled += step
		roll += dt * 14
		-- drawn from the muzzle, merging onto the true line over the first 8 studs
		local merge = clamp01(travelled / 8)
		local drawn = b + (from - origin) * (1 - merge)
		local cf = CFrame.lookAt(drawn, drawn + dir) * CFrame.Angles(0, 0, roll)
		place(body, cf, size)
		place(lip, cf, size)
		shed += dt
		if travelled > 5 and travelled < 30 and shed >= 0.05 then
			shed = 0
			local v = dir * (S.Speed * scale * 0.12) + randomUnitFlat() * 1.5 + Vector3.new(0, -1 + math.random() * 2, 0)
			fling("AK_WG_Drop", drawn - dir * 0.4 * size, v, 1.4, 0.5, 5, 0.5)
		end
		if hit or travelled >= S.Range then
			conn:Disconnect()
			m:Destroy()
			if hit and onHit then task.spawn(onHit, hit) end
			AquaFX.Splash(b, true, hit and hit.Normal, (n - 1) % S.PuddleEvery == 0)
		end
	end)
end

--- The impact: a crown standing on the surface it hit (its up = the surface normal) -- the big crown for the drawn
--- shot, the small one for a rapid bullet -- drops thrown off it, and, when `puddle`, a wet puddle on the floor under it.
function AquaFX.Splash(position, first, normal, puddle)
	local up = (typeof(normal) == "Vector3" and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
	if first then
		crown(position, 0.55, up, "AK_SA_Splash", 0.42)
		spray(position + up * 0.25, 5, 9, 4, 1.8, up, 0.7)
	else
		crown(position, 0.75, up, nil, 0.3)
		spray(position + up * 0.2, 2, 7, 3, 1.5, up, 0.6)
	end
	if puddle then
		local g = floorAt(position, 2, 8)
		if g then AquaFX.Puddle(g.Position, A.Sidearm.PuddleRadius, A.Current.WetLife) end
	end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: LEVIATHAN'S MAW -- the slam, the flood, the glass tank, the shark
----------------------------------------------------------------------------------------------------
-- 20 AK_LM_Wall panels (glass) rise out of the floor round the circle, each with its Tideline AK_LM_Rim along the top;
-- 20 AK_LM_Roof tongues (glass) grow inward from the wall tops to the peak; the flood (AK_LM_Flood, opaque) rises to
-- FloodDepth. THE SHARKS -- one for every enemy the tank closed on (the owner, 2026-09-25: "if more than 1 person is in
-- the shark tank, more than 1 shark will appear and each will get hit separately"): each its shade (AK_LM_Shade)
-- circling under the surface, then its fin (AK_LM_Fin), then the full shark (AK_LM_Shark + the hinged AK_LM_Jaw)
-- lunging at its own enemy; every bite rings AK_LM_Ring and bursts AK_LM_Spray_2 where it lands.
local WALL_UP = 14.93            -- AK_LM_Wall's height above its origin (the mesh), for rising and sinking
local JAW_OPEN = math.rad(35)

--- The whole ultimate from its server time. Returns a handle: SetSharks(n) when the tank closes on n enemies,
--- LungeMany({ {Target, Point}, ... }) when the server names each shark's enemy, BiteMany(models) when they land
--- (Lunge(model, point) / Bite(model) are the one-shark forms).
function AquaFX.Maw(center, t0)
	local M = A.Maw
	local m = model("AquaMaw")
	local R = M.Radius
	local N = M.Panels
	local start = os.clock() - math.max(0, serverNow() - (t0 or serverNow()))
	local rs = R / 22                          -- the kit is modelled at radius 22
	local hs = M.WallHeight / 14               -- ...and walls 14 tall

	-- THE SLAM: Terra-faceted debris and whitewater plumes off the ground
	for i = 1, 9 do
		local v = randomUnitFlat() * (8 + math.random() * 10) + Vector3.new(0, 18 + math.random() * 12, 0)
		fling("AK_LM_Rock_" .. ((i - 1) % 3 + 1), center + Vector3.new(0, 1, 0), v, 1, 0.9, 5, 0.5, true)
	end
	spray(center + Vector3.new(0, 1, 0), 12, 20, 11, 2.4)                -- and the water thrown up with them
	for i = 1, 3 do
		local p = take("AK_LM_Spray_1", "solid", m)
		if p then
			local at = center + randomUnitFlat() * (1 + math.random() * 3)
			local cf = CFrame.new(at) * CFrame.Angles(0, math.random() * 6.28, 0)
			local b0 = os.clock()
			local c
			c = RunService.Heartbeat:Connect(function()
				local e = os.clock() - b0
				if e > 0.7 or not p.Parent then
					c:Disconnect()
					if p.Parent then p:Destroy() end
					return
				end
				local g = easeOut(e / 0.15)
				local down = smooth((e - 0.3) / 0.4)
				place(p, cf * CFrame.new(0, -3 * down, 0), Vector3.new(1, math.max(0.05, (0.3 + 0.7 * g) * (1 - 0.7 * down)), 1) * (0.9 + i * 0.1))
			end)
		end
	end

	-- THE FLOOD (opaque): its origin is the water surface; its body reaches down past the floor
	local flood = take("AK_LM_Flood", "solid", m)

	-- THE WALLS and THE ROOF: the one see-through thing in Aqua's kit. Each blocked by an invisible collider.
	local panels = {}
	for i = 1, N do
		local a = (i - 1) / N * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = center + out * R
		panels[i] = {
			Base = base,
			Wall = take("AK_LM_Wall", "glass", m),
			Roof = take("AK_LM_Roof", "glass", m),
			Rim = take("AK_LM_Rim", "line", m),
			Col = collider(Vector3.new(2 * math.pi * R / N + 0.6, M.WallHeight, 1.4), HIDE, m),
		}
	end
	local ceiling = nil                          -- the roof's collider, once it has closed

	-- THE SHARKS: one to start; SetSharks adds one per trapped enemy, each on its own circle (phase, radius, direction)
	local sharks = {}
	local function addShark()
		local i = #sharks + 1
		sharks[i] = {
			Shade = take("AK_LM_Shade", "solid", m), Fin = take("AK_LM_Fin", "solid", m),
			Shark = take("AK_LM_Shark", "solid", m), Jaw = take("AK_LM_Jaw", "solid", m),
			Phase = (i - 1) * 2.4, RMul = 1 - 0.2 * ((i - 1) % 3), Dir = (i % 2 == 0) and -1 or 1,
			SprayAt = 0, Lunge = nil, Bit = false,
		}
		return sharks[i]
	end
	addShark()

	local lastBite = nil   -- os.clock of the bite
	local rimState = "line"
	local splashedUp, splashedDown = false, false
	local handle = {}

	local function setRim(state)
		if state == rimState then return end
		rimState = state
		for _, p in ipairs(panels) do
			if p.Rim then setKind(p.Rim, state) end
		end
	end

	local function placeShark(s, cf, open)
		if not s.Shark then return end
		place(s.Shark, cf)
		if s.Jaw then
			local hinge = pointOf(s.Shark, "jaw_hinge", 1)
			if hinge then place(s.Jaw, hinge * CFrame.Angles(-open, 0, 0)) end
		end
	end

	local conn
	conn = RunService.Heartbeat:Connect(function()
		local e = os.clock() - start
		if not m.Parent then
			conn:Disconnect()
			return
		end
		-- flood level
		local rise = easeOut(e / M.FloodTime)
		local drain = smooth((e - M.ReleaseTime) / (M.EndTime - M.ReleaseTime))
		local depth = M.FloodDepth * rise * (1 - drain)
		local surfaceY = center.Y + depth
		if flood then
			-- the surface starts 0.6 under the floor (fringe hidden) and rises to FloodDepth; the drain takes it back down
			local level = -0.6 + (depth + 0.6) * math.min(1, rise * 1.4) * (1 - drain)
			place(flood, CFrame.new(center.X, center.Y + level, center.Z), Vector3.new(rs, 1, rs))
		end

		-- walls rise out of the floor (0.15 .. 0.6 of CloseTime), the roof grows in (.. CloseTime); release reverses
		local wallUp = smooth((e - 0.15) / (M.CloseTime * 0.6 - 0.15)) * (1 - drain)
		local roofIn = smooth((e - M.CloseTime * 0.55) / (M.CloseTime * 0.45))
		local roofOut = smooth((e - M.ReleaseTime) / 0.35)
		local curl = roofIn * (1 - roofOut)
		local drop = WALL_UP * hs * (1 - wallUp)
		-- the walls tear up out of the flood (a crown at every panel's foot) and crash back down into it at the release
		if not splashedUp and wallUp > 0.08 then
			splashedUp = true
			for i, p in ipairs(panels) do
				crown(Vector3.new(p.Base.X, surfaceY, p.Base.Z), 2.2, nil, (i % 4 == 0) and "AK_SA_Splash" or nil, 0.55)
			end
		end
		if not splashedDown and drain > 0.25 then
			splashedDown = true
			for i, p in ipairs(panels) do
				crown(Vector3.new(p.Base.X, center.Y, p.Base.Z), 2.4, nil, (i % 4 == 2) and "AK_SA_Splash" or nil, 0.6)
				if i % 2 == 0 then spray(p.Base + Vector3.new(0, 2, 0), 3, 12, 7, 2.6) end
			end
		end
		for _, p in ipairs(panels) do
			local cf = CFrame.lookAt(p.Base, Vector3.new(center.X, p.Base.Y, center.Z)) * CFrame.new(0, -drop, 0)
			place(p.Wall, cf, Vector3.new(rs, hs, 1))
			place(p.Rim, cf, Vector3.new(rs, hs, 1))
			p.Col.CFrame = (wallUp > 0.05) and (cf * CFrame.new(0, M.WallHeight / 2, 0)) or HIDE
			if p.Roof then
				if curl > 0.01 then
					place(p.Roof, cf * CFrame.new(0, M.WallHeight, 0), Vector3.new(rs, hs, rs) * math.max(0.03, curl))
				else
					p.Roof.CFrame = HIDE
				end
			end
		end
		-- the roof's collider: a ceiling over the tank while it is closed (no leaving by jumping)
		if curl > 0.9 and not ceiling then
			ceiling = collider(Vector3.new(1, R * 2, R * 2), CFrame.new(center + Vector3.new(0, M.WallHeight + 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), m)
			ceiling.Shape = Enum.PartType.Cylinder
		elseif curl <= 0.9 and ceiling then
			ceiling:Destroy()
			ceiling = nil
		end
		-- the rim is lit while the walls move, dark once the tank has closed, lit again as it opens
		local moving = (e < M.CloseTime) or (e >= M.ReleaseTime and e < M.EndTime)
		if not lastBite or os.clock() - lastBite > 0.25 then setRim(moving and "line" or "dark") end

		-- each shark: a dark shape circling under the surface from the close, its fin from SharkRise; then its lunge
		for _, s in ipairs(sharks) do
			if e >= M.CloseTime and not s.Lunge and e < M.ReleaseTime then
				local circleR = R * (0.55 - 0.2 * smooth((e - M.SharkRise) / (M.LungeTime - M.SharkRise))) * s.RMul
				local a = s.Dir * e * 2.2 + s.Phase
				local pos = center + Vector3.new(math.cos(a) * circleR, 0, -math.sin(a) * circleR)
				local tangent = Vector3.new(-math.sin(a), 0, -math.cos(a)) * s.Dir
				local at = Vector3.new(pos.X, surfaceY - 0.08, pos.Z)
				if s.Shade then place(s.Shade, CFrame.lookAt(at, at + tangent)) end
				if s.Fin and e >= M.SharkRise then
					local finUp = easeOut((e - M.SharkRise) / 0.25)
					local fAt = Vector3.new(pos.X, surfaceY - 3.15 * (1 - finUp), pos.Z)
					place(s.Fin, CFrame.lookAt(fAt, fAt + tangent))
					-- the fin cuts the surface: a wake of drops thrown off it, landing back on the water
					if finUp > 0.5 and os.clock() >= s.SprayAt then
						s.SprayAt = os.clock() + 0.08
						spray(Vector3.new(pos.X, surfaceY + 0.3, pos.Z) - tangent * 0.8, 2, 6, 3.5, 2.2, nil, 0.8, surfaceY)
					end
				end
			elseif not s.Lunge and e >= M.ReleaseTime then
				if s.Shade then s.Shade.CFrame = HIDE end           -- a shark with no enemy left dives away at the release
				if s.Fin then s.Fin.CFrame = HIDE end
			end
			local L = s.Lunge
			if L then
				if s.Shade then s.Shade.CFrame = HIDE end
				if s.Fin then s.Fin.CFrame = HIDE end
				-- up out of the water at From, arcing onto its enemy's point, jaws open until the bite
				local le = os.clock() - L.At
				local dur = M.BiteTime - M.LungeTime + 0.25
				local k = clamp01(le / dur)
				local p0, p1 = L.From, L.Point
				local arc = Vector3.new(0, 5 * math.sin(math.pi * math.min(1, k * 1.2)), 0)
				local pos = p0:Lerp(p1, math.min(1, k * 1.25)) + arc
				local fall = clamp01((le - dur) / 0.4)
				pos -= Vector3.new(0, 7 * fall, 0)
				local look = flat(p1 - p0).Magnitude > 0.1 and flat(p1 - p0).Unit or Vector3.xAxis
				local cf = CFrame.lookAt(pos, pos + look + Vector3.new(0, 0.6 * (1 - k * 2), 0))
				placeShark(s, cf, s.Bit and 0 or JAW_OPEN)
				if fall >= 1 then
					if s.Shark then s.Shark.CFrame = HIDE end
					if s.Jaw then s.Jaw.CFrame = HIDE end
				end
			end
		end
		if e >= M.EndTime then
			conn:Disconnect()
			m:Destroy()
			AquaFX.Puddle(center, R, M.WetAfter)
		end
	end)

	function handle.SetSharks(n)
		n = math.clamp(tonumber(n) or 1, 1, A.Maw.MaxSharks)
		while #sharks < n do addShark() end
	end

	--- Each listed enemy gets a shark of its own (more are added if the tank's count was short): up out of the water
	--- behind its enemy, arcing onto it. An empty list sends one shark at the centre.
	function handle.LungeMany(list)
		if type(list) ~= "table" or #list == 0 then list = { { Point = center } } end
		for i, item in ipairs(list) do
			if i > A.Maw.MaxSharks then break end
			local s = sharks[i] or addShark()
			if not s.Lunge then
				local target = typeof(item.Point) == "Vector3" and item.Point or center
				local model = typeof(item.Target) == "Instance" and item.Target or nil
				local root = model and model:FindFirstChild("HumanoidRootPart")
				if root then target = root.Position end
				local away = flat(target - center)
				away = away.Magnitude > 0.5 and away.Unit or Vector3.xAxis
				local from = Vector3.new(target.X, center.Y - 1.5, target.Z) - away * 7
				s.Lunge = { Point = target, At = os.clock(), From = from, Target = model }
				for _ = 1, 6 do
					local v = randomUnitFlat() * (4 + math.random() * 5) + Vector3.new(0, 12 + math.random() * 8, 0)
					fling("AK_RT_Foam_" .. math.random(1, 4), from + Vector3.new(0, 1.5, 0), v, 1.2, 0.6, 6, 0.45, false,
						center.Y + M.FloodDepth)
				end
			end
		end
	end

	function handle.Lunge(targetModel, point)
		handle.LungeMany({ { Target = targetModel, Point = point } })
	end

	local function biteBurst(at)
		local ring = take("AK_LM_Ring", "line")
		if ring then
			ring.Color = Color3.fromRGB(183, 222, 248)
			local rcf = CFrame.new(at.X, center.Y + M.FloodDepth + 0.05, at.Z)
			local f0 = os.clock()
			local fc
			fc = RunService.Heartbeat:Connect(function()
				local fe = os.clock() - f0
				if fe > 0.35 or not ring.Parent then
					fc:Disconnect()
					if ring.Parent then ring:Destroy() end
					return
				end
				place(ring, rcf, Vector3.new(1.5 + fe * 22, 1 + fe * 3, 1.5 + fe * 22))
			end)
		end
		spray(Vector3.new(at.X, center.Y + M.FloodDepth + 0.5, at.Z), 14, 22, 12, 2.8, nil, 1.4, center.Y + M.FloodDepth)
		local burst = take("AK_LM_Spray_2", "solid")
		if burst then
			local bcf = CFrame.new(at.X, center.Y + M.FloodDepth, at.Z) * CFrame.Angles(0, math.random() * 6.28, 0)
			local b0 = os.clock()
			local bc
			bc = RunService.Heartbeat:Connect(function()
				local e = os.clock() - b0
				if e > 0.6 or not burst.Parent then
					bc:Disconnect()
					if burst.Parent then burst:Destroy() end
					return
				end
				local g = easeOut(e / 0.12)
				local down = smooth((e - 0.25) / 0.35)
				place(burst, bcf * CFrame.new(0, -2.5 * down, 0), Vector3.new(1, math.max(0.05, (0.3 + 0.7 * g) * (1 - 0.6 * down)), 1) * 1.2)
			end)
		end
	end

	--- Every lunging shark snaps its jaws shut on its own enemy: THE ONE LOUD BEAT -- a Tideline flash round the rim, and
	--- a ring, a foam crown and spray at every bite.
	function handle.BiteMany(_bitten)
		lastBite = os.clock()
		setRim("line")
		for _, p in ipairs(panels) do
			if p.Rim then p.Rim.Color = Color3.fromRGB(183, 222, 248) end
		end
		task.delay(0.25, function()
			for _, p in ipairs(panels) do
				if p.Rim and p.Rim.Parent then p.Rim.Color = COL.Tideline end
			end
		end)
		local any = false
		for _, s in ipairs(sharks) do
			if s.Lunge and not s.Bit then
				s.Bit = true
				any = true
				local at = s.Lunge.Point
				local root = s.Lunge.Target and s.Lunge.Target:FindFirstChild("HumanoidRootPart")
				if root then at = root.Position end
				biteBurst(at)
			end
		end
		if not any then biteBurst(center) end
	end

	function handle.Bite(targetModel)
		handle.BiteMany({ targetModel })
	end

	return handle
end

return AquaFX
