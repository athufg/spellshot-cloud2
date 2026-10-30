--[[
	CryoFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/CryoFX

	Cryo's visuals in the approved Cryo v2 "real ice" look (2026-10-08; the contract is vfx_blocking/cryo/ice_v2/
	CRYO_V2_HANDOFF.md and RECIPE.md, every number is CryoTuning.Look):
	  ICE         milky and translucent: Material Ice (never Glass) at Transparency 0.3-0.5, mid ice blue at the tips and
	              deep glacier blue at the thick base. Every cluster is tall, thin, pointed spikes growing off CHUNKY base
	              prisms 2-3x wider, with a white matte frost mound (Sand, opaque) over the foot. A crystal grows along its
	              length (ease-out, staggered), a small white-hot sliver at its base fading as it grows. Ice casts no shadow.
	  FROST LINE  the ONLY saturated accent: a thin Neon line in #3FE0FF on the leading edge of spreading frost, dimming to
	              the calm #245F9A (no glow) once the spread stops. At most two things glow in a frame and the line is
	              always one of them; there is no inner glow anywhere.
	  FROZEN      a frozen body reads as pale ice and stays readable (play-test fix 2, 2026-10-08): a pale Highlight with a
	              white rim, its colours nudged to IceMid, crust plates on the legs to the waist and caps on the head
	              and shoulders, climbing with the Frost Line; the encasing crystals stand round it.
	  FLOORS      darker frosted ice with a white crust and ragged frost fingers -- never a pale glowing disc.
	  HIT FEEL    a cold PointLight flash, a thin ripple ring, ice shards, chips, powder and flakes. Nothing pops off:
	              everything melts, shrinks or dissolves.

	What it draws (all from server broadcasts; AbilityFX hands them over, nothing here decides gameplay):
	  Blizzard      the storm (snow curtain, haze, the whiteout for anyone caught inside) inside a ring of 8 Frost Line
	                arcs that draws in, holds at half brightness, and steps down to the calm rim one arc a second
	  Deep Freeze   the caster's own tap (a small frost disc and a bloom that melts) and faint marker; on the trigger a
	                ripple, a darker frost disc with one clean Frost Line ring that fades, and the encasing ice: chunky
	                foot prisms, crystals 4-6 studs round the body, 1-2 spires, crystals sprouting off the body as the
	                frost climbs it under the line, the body tinted dark blue; white cracks race, then it shatters
	  Mirror Cage   a frost disc at the lock, crystal clusters round the dome's floor, thick faceted ice-mirror panels
	                (Ice, Reflectance 0.4, Transparency 0.35) with a faint edge and 1-2 cracks, their outline pulsing in
	                the Frost Line as each shot leaves, the trapped body's frost climbing through the volley, the break
	  Chill         the Icicle Shard's stacks as frost and crystals climbing the shins; the third climbs to the knees and
	                grows two ankle-cuff clusters
	  Cold Momentum a thin ragged frost print under each footfall with a Frost Line rim for 0.2 s, frost cuffs at the
	                ankles draining over the 2 s buff, breath puffs
	  Freeze beats  the root (a Flash Freeze root grows the encasing ice round the target) and the shatter
	  Flash Freeze  the slam's burst (the zone itself is VFXLibrary's)
	  Icicle Shard  the impact and the cast's frost (the shot itself is VFXLibrary's)

	Meshes: ReplicatedStorage.IceMagicMeshes.CryoKit (crystals, chunks, splinters, prints, rings, arcs, panels). A kit
	MeshPart's Color multiplies its baked vertex colours; the Frost Line pieces are baked white and drawn Neon in the line
	colour. Frost, floors and edges are plain Parts. If a piece is missing it is skipped quietly: gameplay never waits on
	a look. Particle counts and the optional pieces go through the Graphics Quality / Reduce Enemy VFX scaling
	(density, thinFor; "enemy" is FBX.Enemy = VFXLibrary.IsEnemy: not mine, not a teammate's, judged by the CASTER).
	(2026-10-19, audit P5A-23) Not everything: a skin's set pieces such as Frost Dragon's Blizzard dragons stay whole
	(only their emitters scale); the skin modules thin their own extras through CryoFX._H (thinFor / density / isEnemy).

	Numbers: CryoTuning (the one table the server reads too; the look is CryoTuning.Look). Times on the wire are SERVER
	time (T0), so a late message catches up instead of starting late.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local CryoTuning = require(iceFolder:WaitForChild("CryoTuning"))

local CryoFX = {}
CryoFX.Tuning = CryoTuning

if not RunService:IsClient() then
	-- the server reads CryoTuning directly; nothing below may run there (it would build parts nobody sees)
	return CryoFX
end

local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))
local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

local player = Players.LocalPlayer
local B, D, M = CryoTuning.Blizzard, CryoTuning.DeepFreeze, CryoTuning.MirrorCage

-- Cryo's FROSTBLADE skin (2026-10-14; FrostbladeKit, the contract vfx_blocking/cryo/cryo_frostblade_skin_2026_10_14/
-- HANDOFF_SPEC.md): for a caster who wears it, the pieces below draw ice KUNAI in place of the Default's crystals and
-- panels -- the pierce and the low shatter (Flash Freeze), the trap (Deep Freeze), the ice clones throwing kunai (Mirror
-- Cage), the nicks in the prints (Cold Momentum), the fence (Blizzard). Missing module or meshes not built yet: Default.
-- (one table, FBX, for all of it: this module is near Luau's limit of 200 top-level locals -- 196 on 2026-10-19; add
-- new helpers to FBX or to a do-block, never as another top-level local)
local FBX = { Module = nil, C = function(c) return c end, Bind = function(f) return f end, Lit = function(e) return e end, WrapRun = function(_, f, ...) return f(...) end }   -- C / Bind: CryoWrap's once CryoFX.Start installs it
--- the kit, or nil
function FBX.Kit()
	if FBX.Module == nil then
		local m = iceFolder:FindFirstChild("FrostbladeKit")
		local ok, mod = pcall(function() return m and require(m) end)
		FBX.Module = (ok and mod) or false
	end
	return FBX.Module or nil
end
--- whether `caster` (a character) draws Frostblade on this client, and the kit
function FBX.On(caster)
	local k = FBX.Kit()
	return (k ~= nil and caster ~= nil and k.Built == true and k.On(caster)) or false, k
end
-- Cryo's FROST LOTUS skin (2026-10-15; FrostLotusKit + FrostLotusFX, the contract vfx_blocking/cryo/
-- cryo_frostlotus_skin_2026_10_14/HANDOFF_SPEC.md): the same hooks draw lotus blooms -- the Flash Freeze field and the
-- rooted body blossoming, the Mirror Cage's blooms and spiralling petal bolts, the lotus prints, the Deep Freeze trap,
-- the petal storm, the dart's hit bloom. The piece logic lives in FrostLotusFX (handed this module's helpers, CryoFX._H).
function FBX.LotusKit()
	if FBX.LotusModule == nil then
		local m = iceFolder:FindFirstChild("FrostLotusKit")
		local ok, mod = pcall(function() return m and require(m) end)
		FBX.LotusModule = (ok and mod) or false
	end
	return FBX.LotusModule or nil
end
function FBX.LotusOn(caster)
	local k = FBX.LotusKit()
	return (k ~= nil and caster ~= nil and k.Built == true and k.On(caster)) or false, k
end
function FBX.Lotus()
	if FBX.LFX == nil then
		local m = iceFolder:FindFirstChild("FrostLotusFX")
		local ok, mod = pcall(function() return m and require(m) end)
		FBX.LFX = (ok and mod and FBX.LotusKit()) and mod or false
		if FBX.LFX then FBX.LFX.Init(CryoFX._H, FBX.LotusKit()) end
	end
	return FBX.LFX or nil
end
-- Cryo's FROST DRAGON skin (Mythic, 2026-10-15; FrostDragonKit + FrostDragonFX + FrostDragonData, vfx_blocking/cryo/
-- cryo_frostdragon_skin_2026_10_15): FrostDragonFX takes FrostLotusFX's Mirror Cage calls (stage 1: the curled dragon);
-- its other pieces are still the Default.
function FBX.DragonKit()
	if FBX.DragonModule == nil then
		local m = iceFolder:FindFirstChild("FrostDragonKit")
		local ok, mod = pcall(function() return m and require(m) end)
		FBX.DragonModule = (ok and mod) or false
	end
	return FBX.DragonModule or nil
end
function FBX.DragonOn(caster)
	local k = FBX.DragonKit()
	return (k ~= nil and caster ~= nil and k.Built == true and k.On(caster)) or false, k
end
function FBX.Dragon()
	if FBX.DFX == nil then
		local m = iceFolder:FindFirstChild("FrostDragonFX")
		local ok, mod = pcall(function() return m and require(m) end)
		FBX.DFX = (ok and mod and FBX.DragonKit()) and mod or false
		if FBX.DFX then FBX.DFX.Init(CryoFX._H, FBX.DragonKit()) end
	end
	return FBX.DFX or nil
end
-- Cryo's SNOW GLOBE skin (Rare, 2026-10-15 -- audit P5A-23: was "Epic"; SnowGlobeKit + SnowGlobeFX, vfx_blocking/cryo/cryo_snowglobe_skin_2026_10_15):
-- SnowGlobeFX takes the same calls as FrostLotusFX, so each Frost Lotus hook asks for whichever skin the caster wears.
-- Deep Freeze is not hooked: it stays the Default.
function FBX.Globe(caster)
	if FBX.GFX == nil then
		local m, k = iceFolder:FindFirstChild("SnowGlobeFX"), iceFolder:FindFirstChild("SnowGlobeKit")
		local ok, mod = pcall(function() return m and k and require(m) end)
		FBX.GFX = (ok and mod) or false
		FBX.GK = FBX.GFX and require(k) or nil                  -- its kit (the freeze plumbing's "GlobeFF", "SG_" pieces)
		if FBX.GFX then FBX.GFX.Init(CryoFX._H, FBX.GK) end
	end
	return (FBX.GFX and caster ~= nil and FBX.GFX.On(caster)) and FBX.GFX or nil
end
local L = CryoTuning.Look

----------------------------------------------------------------------------------------------------
-- palette and materials (CryoTuning.Look)
----------------------------------------------------------------------------------------------------
local COL = {
	Line = L.FrostLine, Hot = L.FrostLineHot, Calm = L.Calm, Frost = L.Frost, Clear = L.ClearIce,
	Ripple = L.Ripple, Flash = L.Flash, White = Color3.new(1, 1, 1),
}

local ICE, SAND, NEON, PLASTIC = Enum.Material.Ice, Enum.Material.Sand, Enum.Material.Neon, Enum.Material.SmoothPlastic

-- every look a piece can take: { Material, Color, Transparency, Reflectance }
local STYLE = {
	Tip = { ICE, L.TipTint, L.TipT, L.Reflect },                 -- a thin spike
	Body = { ICE, L.SpikeTint, L.BodyT, L.Reflect },             -- a spike in a cluster
	Base = { ICE, L.BaseTint, L.BaseT, L.Reflect * 0.5 },        -- a chunky base prism
	EncaseBase = { ICE, L.BaseTint, L.EncaseBaseT, 0.05 },       -- the encasing mass: opaque at the foot...
	EncaseMid = { ICE, L.SpikeTint, L.EncaseMidT, L.Reflect },
	EncaseTop = { ICE, L.TipTint, L.EncaseTopT, L.Reflect },     -- ...clear at the top
	Chunk = { ICE, L.TipTint, L.BodyT, L.Reflect },
	Slab = { ICE, L.DeepTint, L.SlabT, 0.05 },                   -- a piece of the darker frozen floor
	Frost = { SAND, L.Frost, 0.02, 0 },                          -- a frost mound
	Skin = { SAND, L.Frost, L.FrostSkinT, 0 },                   -- frost on a body
	Coat = { ICE, L.TipTint, 0.3, L.Reflect },                   -- the ice coat over a body (Mirror Cage)
	Cuff = { SAND, L.Frost, 0.1, 0 },
	Print = { SAND, L.FrostTint, L.PrintT, 0 },                  -- a ragged frost print (a kit mesh over its bake)
	Drift = { SAND, L.FrostTint, 0, 0 },
	Floor = { ICE, L.FloorIce, L.FloorT, 0.05 },                 -- the darker frosted floor ice
	Crust = { SAND, L.Frost, L.CrustT, 0 },
	Panel = { ICE, L.PanelTint, L.PanelT, L.PanelReflect },      -- a Mirror Cage panel
	Edge = { PLASTIC, L.ClearIce, L.EdgeT, 0 },                  -- its faint edge highlight
	Crack = { PLASTIC, L.Frost, L.CrackT, 0 },                   -- a soft crack in it
	Ripple = { PLASTIC, L.Ripple, 0.4, 0 },
	Flare = { NEON, COL.White, 0.1, 0 },                         -- the white-hot base of a growing crystal
	HotCrack = { NEON, COL.White, 0.2, 0 },                      -- the racing cracks before a shatter
	Line = { NEON, L.FrostLine, 0, 0 },                          -- the Frost Line
	Kunai = { ICE, COL.White, 0.25, 0.15 },                      -- a Frostblade kunai piece (FrostbladeKit)
	Calm = { PLASTIC, L.Calm, L.LineDimT, 0 },                   -- the line at rest
}

local function dress(p, style, transparency)
	local s = STYLE[style] or STYLE.Body
	if p.Material ~= s[1] then p.Material = s[1] end
	p.Color = s[2]
	p.Transparency = transparency or s[3]
	p.Reflectance = s[4]
	p.CastShadow = false
	return p
end

local SOUNDS = {
	Shatter = { Name = "SFX_IceShatter", Volume = 0.85, Speed = 1.25 },
	Root = { Name = "SFX_IceShatter", Volume = 0.35, Speed = 1.6 },
	Slam = { Name = "SFX_GroundBoom", Volume = 0.5, Speed = 0.6 },
	Seal = { Name = "SFX_IceShatter", Volume = 0.7, Speed = 0.7 },
	Form = { Name = "SFX_GlassShatter", Volume = 0.5, Speed = 1.4 },
	Break = { Name = "SFX_IceShatter", Volume = 0.9, Speed = 1.0 },
	Bolt = { Name = "SFX_GlassShatter", Volume = 0.12, Speed = 2.0 },
}

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[CryoFX] " .. msg)
end

-- A test hook (tools: the Studio playtest captures): CryoFX.DebugHold(true) stops every effect's clock where it
-- stands, so one beat can be looked at; DebugHold(false) lets it run on. Nothing in the game calls it.
local holdAt = nil

local function serverNow()
	return holdAt or workspace:GetServerTimeNow()
end

function CryoFX.DebugHold(on)
	holdAt = on and workspace:GetServerTimeNow() or nil
end

local function fxFolder()
	local name = VFXLibrary.Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function smooth(u)
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function easeOut(u)
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) * (1 - u) * (1 - u)
end

local function dirAt(a)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

--- A body's root and where its feet are (the server measures them the same way).
local function feetOf(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root then return nil end
	local legs = hum and (hum.RigType == Enum.HumanoidRigType.R6 and 2 or hum.HipHeight) or 2
	return root, root.Position.Y - root.Size.Y / 2 - legs
end

--- How tall a body stands over its feet (the top of its highest part), 2..7.
local function bodyTop(model, feet)
	local top = 0
	for _, bp in ipairs(model:GetChildren()) do
		if bp:IsA("BasePart") and bp.Name ~= "HumanoidRootPart" then
			top = math.max(top, bp.Position.Y + bp.Size.Y / 2 - feet)
		end
	end
	return (top < 2) and 5 or math.min(top, 7)
end

local function isDead(model)
	if model.Parent == nil then return true end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health <= 0
end

--- (2026-10-19, audit P5A-12) "enemy" for Reduce Enemy VFX: a body that is not mine and not a TEAMMATE's (same
--- DuelMatch, Config.MayHurt false: 2v2 / Squad Clash). Anyone else (a Hub player, a dummy) counts as before.
function FBX.Enemy(character)
	-- (2026-10-19, audit P5F-06) one rule for every module: VFXLibrary's (also spares an AllyDummy); the body below is
	-- the fallback for a VFXLibrary without it
	if VFXLibrary.IsEnemy then return VFXLibrary.IsEnemy(character) end
	if character == nil then return false end
	local me = VFXLibrary.LocalCharacter or player.Character
	if character == me then return false end
	local pl = Players:GetPlayerFromCharacter(character)
	local match = pl and player and pl:GetAttribute("DuelMatch")
	if match ~= nil and match == player:GetAttribute("DuelMatch") then
		local ok, may = pcall(Config.MayHurt, pl, player)
		if ok and may == false then return false end
	end
	return true
end

--- Graphics Quality / Reduce Enemy VFX: low density, or an enemy's effect with Reduce Enemy VFX on.
local function thinFor(character)
	return (Settings.EffectDensity or 1) < 0.75
		or (Settings.ThinEnemyVFX and FBX.Enemy(character)) or false
end

--- The emitter count scale: Graphics Quality (0.4 .. 1), halved for an enemy's effect under Reduce Enemy VFX.
local function density(character)
	local d = math.clamp(Settings.EffectDensity or 1, 0.4, 1)
	if Settings.ThinEnemyVFX and FBX.Enemy(character) then d *= 0.5 end
	return d
end

local function playSound(parent, key)
	local s = SOUNDS[key]
	local folder = iceFolder:FindFirstChild(VFXLibrary.Config.SoundFolderName)
	local src = s and folder and folder:FindFirstChild(s.Name)
	if not (src and src:IsA("Sound")) then return end
	local snd = src:Clone()
	snd.Volume = s.Volume
	snd.PlaybackSpeed = s.Speed
	snd.Parent = parent
	snd:Play()
	task.delay(4, function() snd:Destroy() end)
end

--- An invisible anchored host (a sound, a light, an emitter) at `cf`.
local function host(cf, parent)
	local p = Instance.new("Part")
	p.Name = "CryoFXHost"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = parent or fxFolder()
	return p
end

--- The cold flash of an impact: a PointLight that dies off fast (RECIPE: #73D6FF, about 3 -> 0 in 0.2 s).
local function lightFlash(parent, brightness, range, fade)
	if Lighting.Brightness < 0.05 then return end       -- the flat comic light profile: a light only greys it
	-- (2026-10-19, audit P5A-09) Reduce Flashing: the flash at 40%, fading half as fast (the skin paths' `calm` rule)
	if Settings.Get and Settings.Get("ReduceFlashing") then brightness, fade = brightness * 0.4, fade * 2 end
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows = COL.Flash, brightness, range, false
	l.Parent = parent
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - t0) / fade
		if u >= 1 or not l.Parent then
			conn:Disconnect()
			l:Destroy()
			return
		end
		l.Brightness = brightness * (1 - u) * (1 - u)
	end)
end

local function flashAt(pos, brightness, range, fade)
	local h = host(CFrame.new(pos))
	lightFlash(h, brightness, range, fade)
	task.delay(fade + 0.1, function() h:Destroy() end)
	return h
end

--- Cold mist: big soft lit puffs rolling low over a floor. `hostPart` is a box the size of the floor it covers; the rate
--- starts at 0 and the caller turns it on and off.
local function mistEmitter(hostPart, sizeLo, sizeHi, transparency)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(COL.Frost)
	e.LightInfluence, e.LightEmission = 1, 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sizeLo), NumberSequenceKeypoint.new(1, sizeHi) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, transparency or 0.75),
		NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(2.5, 3.2)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.Acceleration = Vector3.new(0, -0.3, 0)
	e.SpreadAngle = Vector2.new(70, 70)
	e.RotSpeed = NumberRange.new(-8, 8)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	FBX.Lit(e)
	e.Parent = hostPart
	return e
end

----------------------------------------------------------------------------------------------------
-- the kit, plain parts and the pools
----------------------------------------------------------------------------------------------------
local KIT_FOLDER = "CryoKit"

local function template(name)
	local meshes = ReplicatedStorage:FindFirstChild(VFXLibrary.Config.MeshFolderName)
	local kit = meshes and meshes:FindFirstChild(KIT_FOLDER)
	local t = kit and kit:FindFirstChild(name)
	if t and t:IsA("MeshPart") then return t end
	warnOnce("kit" .. name, ("%s not found in ReplicatedStorage.%s.%s - that piece is skipped"):format(
		name, VFXLibrary.Config.MeshFolderName, KIT_FOLDER))
	return nil
end

-- plain parts: frost and floors want their exact colour, which a kit mesh's bake would tint
local PLAIN = { ["@Block"] = true, ["@Cyl"] = true, ["@Mound"] = true }

local function newPlain(kind)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = true, false, false, false, true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if kind == "@Cyl" then
		p.Shape = Enum.PartType.Cylinder                       -- its axis is X
	elseif kind == "@Mound" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere                       -- squashed by the part's size: a low mound
		m.Parent = p
	end
	p.Name = "Cryo" .. kind:sub(2)
	return p
end

local pools = {}                 -- [name] = { parts }

--- A kit piece drawn through a SpecialMesh rather than cloned as a MeshPart. A MeshPart's Color MULTIPLIES the mesh's
--- baked vertex colours, and the CryoKit was baked a saturated cobalt (the pre-v2 toon look), so no Color could make
--- the reel's pale milky ice; a FileMesh SpecialMesh ignores the bake and takes the part's Color, Material and
--- Transparency as they are. The part keeps a MeshPart's habits: its Size is what you see (the mesh's Scale follows
--- it), and the mesh sits on the part's centre.
local meshSizes = {}

local function kitPart(t)
	local native = meshSizes[t]
	if not native then
		local ok, ms = pcall(function() return t.MeshSize end)
		native = (ok and typeof(ms) == "Vector3" and ms.Magnitude > 1e-4) and ms or t.Size
		meshSizes[t] = native
	end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = true, false, false, false, true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Name = t.Name
	local m = Instance.new("SpecialMesh")
	m.Name = "KitMesh"
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = t.MeshId
	local function fit()
		local s = p.Size
		m.Scale = Vector3.new(s.X / native.X, s.Y / native.Y, s.Z / native.Z)
	end
	p.Size = t.Size
	fit()
	p:GetPropertyChangedSignal("Size"):Connect(fit)
	m.Parent = p
	return p
end

--- A kit piece (or a plain "@Block" / "@Cyl" / "@Mound"), anchored and inert, dressed in `style`.
local function take(name, style)
	local wk = FBX.Wrap and FBX.Wrap.KitTake and FBX.Wrap.KitTake(name, style, dress, template)   -- (a Mythic wrap's gradient copy)
	if wk then return wk end
	local pool = pools[name]
	local p = pool and table.remove(pool)
	if not p then
		if PLAIN[name] then
			p = newPlain(name)
		elseif string.sub(name, 1, 3) == "FL_" then
			local kit = FBX.LotusKit()
			local o = kit and kit.New(string.sub(name, 4))
			if not o then return nil end
			p = o.Body
		elseif string.sub(name, 1, 3) == "SG_" then
			local o = FBX.GK and FBX.GK.New(string.sub(name, 4))
			if not o then return nil end
			p = o.Body
		elseif string.sub(name, 1, 3) == "FB_" then
			local kit = FBX.Kit()
			local o = kit and kit.New(string.sub(name, 4))
			if not o then return nil end
			p = o.Body
		else
			local t = template(name)
			if not t then return nil end
			p = kitPart(t)
		end
		p:SetAttribute("CryoKit", name)
	end
	p.LocalTransparencyModifier = 0
	dress(p, style or "Body")
	return p
end

local function give(p)
	if not p then return end
	local tr = p:FindFirstChild("CryoTrail")
	if tr and tr:IsA("Trail") then
		tr.Enabled = false
		pcall(function() tr:Clear() end)
	end
	for _, ch in ipairs(p:GetChildren()) do
		if ch:IsA("Light") then ch:Destroy() end
	end
	local name = p:GetAttribute("CryoKit")
	if not name or not pcall(function() p.Parent = nil end) then
		pcall(function() p:Destroy() end)
		return
	end
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	if #pool < (PLAIN[name] and 160 or 60) then table.insert(pool, p) else p:Destroy() end
end

local templateSize = setmetatable({}, { __index = function(self, name)
	local t = template(name)
	local s = t and t.Size or Vector3.one
	rawset(self, name, s)
	return s
end })

----------------------------------------------------------------------------------------------------
-- one render step for everything that moves: steppers push (part, cframe) pairs and are dropped when they
-- return false. One BulkMoveTo a frame for the lot.
----------------------------------------------------------------------------------------------------
local steppers = {}
local bound = false
local STEP = "SpellshotCryoFX"
local movedParts, movedCFrames = {}, {}

local function step(dt)
	table.clear(movedParts)
	table.clear(movedCFrames)
	local now = os.clock()
	for i = #steppers, 1, -1 do
		local fn = steppers[i]
		local ok, keep = pcall(fn, now, dt, movedParts, movedCFrames)
		if not ok then
			warnOnce("step" .. tostring(keep), "an effect stopped: " .. tostring(keep))
			table.remove(steppers, i)
		elseif not keep then
			table.remove(steppers, i)
		end
	end
	if #movedParts > 0 then
		workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function run(fn)
	fn = FBX.Bind(fn)                 -- a wrapped caster's effect keeps its palette every frame (CryoWrap)
	steppers[#steppers + 1] = fn
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 4, step)
	end
end

----------------------------------------------------------------------------------------------------
-- THE FROST LINE. `glow` 0..2: 1 = lit (#3FE0FF), above 1 toward its flash (#8DF3FF), below 1 dimming toward the calm
-- rim, 0 = the calm rim (SmoothPlastic #245F9A, no glow). `fade` 0..1 takes it away.
----------------------------------------------------------------------------------------------------
local function lineLook(p, glow, fade)
	fade = fade or 0
	local rest = L.LineDimT * (1 - math.clamp(glow, 0, 1))
	local t = rest + (1 - rest) * fade
	if glow > 0.02 then
		if p.Material ~= NEON then p.Material = NEON end
		local c = (glow > 1) and COL.Line:Lerp(COL.Hot, math.min(glow - 1, 1)) or COL.Calm:Lerp(COL.Line, glow)
		if p.Color ~= c then p.Color = c end
	else
		local rm = STYLE.Calm[1]                -- (SmoothPlastic; a solid wrap's line glows at rest too: CryoWrap)
		if p.Material ~= rm then p.Material = rm end
		if p.Color ~= COL.Calm then p.Color = COL.Calm end
	end
	if math.abs(p.Transparency - t) > 1e-3 then p.Transparency = t end
end

--- A Frost Line ring (the kit's unit ring) round `cf`: half-widths rx / rz in studs.
local function placeRing(p, cf, rx, rz, thick, parts, cframes)
	local full = templateSize.CK_Ring
	local s = Vector3.new(full.X * math.max(0.02, rx), thick or L.LineThick, full.Z * math.max(0.02, rz))
	if p.Size ~= s then p.Size = s end
	parts[#parts + 1] = p
	cframes[#cframes + 1] = cf
end

----------------------------------------------------------------------------------------------------
-- THE SHARED EMITTER RIG: one anchored host with one emitter per kind (powder, chips, flakes, glints, breath). A burst
-- moves the host and Emits; the particles live in the world, so the host is free again at once. Counts go through the
-- Graphics Quality / Reduce Enemy VFX scale.
----------------------------------------------------------------------------------------------------
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local NS, NK, NR = NumberSequence.new, NumberSequenceKeypoint.new, NumberRange.new

local KINDS = {
	-- soft swirling powder snow (lit, matte)
	Powder = { Speed = { 2, 5 }, Props = {
		Texture = SMOKE, Color = ColorSequence.new(COL.Frost), LightInfluence = 1, LightEmission = 0,
		Transparency = NS({ NK(0, 0.3), NK(1, 1) }), Size = NS({ NK(0, 0.9), NK(1, 2.6) }), Lifetime = NR(1.0, 1.5),
		SpreadAngle = Vector2.new(75, 75), Drag = 3, Acceleration = Vector3.new(0, 0.6, 0),
		RotSpeed = NR(-70, 70), Rotation = NR(0, 360) } },
	-- small ice chips, falling hard
	Chips = { Speed = { 6, 13 }, Props = {
		Texture = SQUARE, Color = ColorSequence.new(COL.Clear, L.MidIce), LightInfluence = 1, LightEmission = 0,
		Transparency = NS({ NK(0, 0.1), NK(0.8, 0.25), NK(1, 1) }), Size = NS({ NK(0, 0.16), NK(1, 0.06) }),
		Lifetime = NR(0.5, 0.9), SpreadAngle = Vector2.new(55, 55), Drag = 1, Acceleration = Vector3.new(0, -40, 0),
		RotSpeed = NR(-400, 400), Rotation = NR(0, 360) } },
	-- snowflakes drifting down
	Flakes = { Speed = { 1, 3.5 }, Props = {
		Texture = SPARKLE, Color = ColorSequence.new(COL.Frost), LightInfluence = 0.5, LightEmission = 0.1,
		Transparency = NS({ NK(0, 0.2), NK(0.7, 0.35), NK(1, 1) }), Size = NS({ NK(0, 0.22), NK(1, 0.12) }),
		Lifetime = NR(1.0, 1.8), SpreadAngle = Vector2.new(80, 80), Drag = 2, Acceleration = Vector3.new(0, -2.5, 0),
		RotSpeed = NR(-90, 90), Rotation = NR(0, 360) } },
	-- 4-point sparkles on an impact (brief)
	Glints = { Speed = { 3, 8 }, Props = {
		Texture = SPARKLE, Color = ColorSequence.new(COL.White), LightInfluence = 0, LightEmission = 0.5,
		Transparency = NS({ NK(0, 0), NK(1, 1) }), Size = NS({ NK(0, 0.4), NK(1, 0) }), Lifetime = NR(0.25, 0.55),
		SpreadAngle = Vector2.new(70, 70), Drag = 4, RotSpeed = NR(-200, 200), Rotation = NR(0, 360) } },
	-- cold vapor / breath
	Breath = { Speed = { 1, 2.2 }, Props = {
		Texture = SMOKE, Color = ColorSequence.new(COL.Frost), LightInfluence = 1, LightEmission = 0,
		Transparency = NS({ NK(0, 0.55), NK(1, 1) }), Size = NS({ NK(0, 0.25), NK(1, 0.9) }), Lifetime = NR(0.6, 1.0),
		SpreadAngle = Vector2.new(25, 25), Drag = 3, Acceleration = Vector3.new(0, 0.5, 0),
		RotSpeed = NR(-40, 40), Rotation = NR(0, 360) } },
}

local rigHost, rigEm = nil, {}

local function rig()
	if rigHost and rigHost.Parent then return rigHost end
	rigHost = host(CFrame.new(), fxFolder())
	rigHost.Name = "CryoBurstRig"
	rigEm = {}
	for kind, spec in pairs(KINDS) do
		local e = Instance.new("ParticleEmitter")
		e.Name = kind
		for k, v in pairs(spec.Props) do e[k] = v end
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 0
		e.Enabled = false
		e.Parent = rigHost
		rigEm[kind] = e
	end
	return rigHost
end

--- A frame at `pos` whose +Y is `dir` (the emitters fire along +Y).
local function aimUp(pos, dir)
	if not dir or dir.Magnitude < 1e-3 then return CFrame.new(pos) end
	dir = dir.Unit
	if dir.Y > 0.98 then return CFrame.new(pos) end
	if dir.Y < -0.98 then return CFrame.new(pos) * CFrame.Angles(math.pi, 0, 0) end
	return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end

--- A burst through the shared rig: `counts` = { Powder = n, Chips = n, ... }, times `dens` (density()); `speed` scales
--- the kinds' own speeds.
local function burst(pos, dir, counts, dens, speed)
	local ok = pcall(function()
		local h, em = rig(), rigEm
		if FBX.Wrap and FBX.Wrap.Active then h, em = FBX.Wrap.Rig(KINDS, host, fxFolder) end   -- a wrap's own rig
		h.CFrame = aimUp(pos, dir or Vector3.yAxis)
		dens = dens or density(nil)
		for kind, n in pairs(counts) do
			local e, spec = em[kind], KINDS[kind]
			local k = math.floor(n * dens + 0.5)
			if e and k > 0 then
				local s = speed or 1
				e.Speed = NR(spec.Speed[1] * s, spec.Speed[2] * s)
				e:Emit(k)
			end
		end
	end)
	if not ok then warnOnce("burst", "a particle burst failed") end
end

--- A thin ripple ring (#D6F4FF) spreading on a surface: `cf`'s +Y is the surface normal.
local function ripple(cf, r0, r1, dur, alpha)
	local p = take("CK_Ring", "Ripple")
	if not p then return nil end
	local full = templateSize.CK_Ring
	alpha = alpha or 0.4
	p.Transparency = alpha
	p.Size = Vector3.new(full.X * r0, 0.04, full.Z * r0)
	p.CFrame = cf
	p.Parent = fxFolder()
	local born = os.clock()
	run(function()
		local u = (os.clock() - born) / dur
		if u >= 1 or not p.Parent then
			give(p)
			return false
		end
		local r = r0 + (r1 - r0) * easeOut(u)
		p.Size = Vector3.new(full.X * r, 0.04, full.Z * r)
		p.Transparency = alpha + (1 - alpha) * u * u
		return true
	end)
	return p
end

----------------------------------------------------------------------------------------------------
-- DEBRIS: pieces thrown, falling under a light gravity, bouncing once on the ground they started over, then melting
-- (shrinking and clearing) away over their last moments
----------------------------------------------------------------------------------------------------
local GRAVITY = 70
local debris = {}

local function throw(name, cf, vel, spin, life, size, groundY, style, transparency)
	local p = take(name, style or "Chunk")
	if not p then return end
	if transparency then p.Transparency = transparency end
	size = size or templateSize[name]
	p.Size = size
	p.CFrame = cf
	p.Parent = fxFolder()
	debris[#debris + 1] = {
		P = p, Pos = cf.Position, Rot = cf.Rotation, Vel = vel, Spin = spin, Born = os.clock(), Life = life,
		Size = size, Ground = groundY, Half = math.min(size.X, size.Y, size.Z) * 0.5, Bounced = false, T = p.Transparency,
	}
end

local function groundY(pos, exclude)
	local p, _, hit = VFXLibrary.GroundBelow(pos, exclude or { fxFolder() }, 40)
	return hit and p.Y or (pos.Y - 40)
end

run(function(now, dt, parts, cframes)
	for i = #debris, 1, -1 do
		local d = debris[i]
		local age = now - d.Born
		if age >= d.Life or not d.P.Parent then
			table.remove(debris, i)
			give(d.P)
		else
			if not d.Resting then
				d.Vel -= Vector3.new(0, GRAVITY * dt, 0)
				d.Pos += d.Vel * dt
				if d.Spin.Magnitude > 1e-3 then
					d.Rot = CFrame.fromAxisAngle(d.Spin.Unit, d.Spin.Magnitude * dt) * d.Rot
				end
				if d.Pos.Y - d.Half < d.Ground then
					d.Pos = Vector3.new(d.Pos.X, d.Ground + d.Half, d.Pos.Z)
					if d.Bounced or math.abs(d.Vel.Y) < 4 then
						d.Resting = true
					else
						d.Bounced = true
						d.Vel = Vector3.new(d.Vel.X * 0.35, -d.Vel.Y * 0.3, d.Vel.Z * 0.35)
						d.Spin *= 0.4
					end
				end
			end
			local out = d.Life - age
			if out < 0.35 then
				-- melting: smaller and clearer to nothing
				local k = out / 0.35
				d.P.Size = d.Size * math.max(0.05, 0.4 + 0.6 * k)
				d.P.Transparency = d.T + (1 - d.T) * (1 - k)
			end
			parts[#parts + 1] = d.P
			cframes[#cframes + 1] = CFrame.new(d.Pos) * d.Rot
		end
	end
	return true
end)

local CHUNKS = { "CK_Chunk_1", "CK_Chunk_2", "CK_Chunk_3", "CK_Chunk_4" }
local SPLINTERS = { "CK_IS_Splinter_1", "CK_IS_Splinter_2", "CK_IS_Splinter_3" }

--- `count` chunks thrown out of the box `cf` / `extent`, outward from `center`.
local function burstChunks(rng, center, cf, extent, count, speed, up, sizeLo, sizeHi, gy, style)
	for _ = 1, count do
		local offset = Vector3.new(rng:NextNumber(-1, 1) * extent.X, rng:NextNumber(-1, 1) * extent.Y, rng:NextNumber(-1, 1) * extent.Z)
		local pos = (cf * CFrame.new(offset)).Position
		local out = flat(pos - center)
		out = out.Magnitude > 1e-3 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1) + 0.01).Unit
		local s = rng:NextNumber(sizeLo, sizeHi)
		local rot = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		throw(CHUNKS[rng:NextInteger(1, #CHUNKS)], CFrame.new(pos) * rot,
			out * rng:NextNumber(speed * 0.55, speed) + Vector3.new(0, rng:NextNumber(up * 0.5, up), 0),
			Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * rng:NextNumber(4, 12),
			rng:NextNumber(1.1, 1.7), Vector3.one * s, gy, style or "Chunk")
	end
end

----------------------------------------------------------------------------------------------------
-- CRYSTALS: a "set" is a list of crystals that grow along their length (ease-out, staggered), with a white-hot sliver
-- at the base of the big ones while they grow; a set can be snapped (tops thrown, stumps left) and sunk (melted away).
--   record = { P, Kit, Style, Base (its foot; +Y along it), Size (full), Delay, Dur, T (its transparency), Flare, Mode }
----------------------------------------------------------------------------------------------------
local function crystalName(rng)
	return "CK_Crystal_" .. rng:NextInteger(1, 6)
end

--- The template's own footprint shape, `w` studs across and `h` long (a MeshPart resizes freely: thin spikes and chunky
--- prisms from the same six crystals).
local function crystalSize(name, w, h)
	local s = templateSize[name]
	local foot = math.max(s.X, s.Z, 1e-3)
	return Vector3.new(s.X / foot * w, h, s.Z / foot * w)
end

--- A foot frame at `pos`: +Y tipped `tilt` radians toward the horizontal `out`, turned `spin` round itself.
local function footFrame(pos, out, tilt, spin)
	local o = flat(out or Vector3.zero)
	local cf = CFrame.new(pos)
	if o.Magnitude > 1e-3 and math.abs(tilt) > 1e-4 then
		cf *= CFrame.fromAxisAngle(Vector3.yAxis:Cross(o.Unit), tilt)
	end
	return cf * CFrame.Angles(0, spin or 0, 0)
end

--- A frame at `pos` with +Y along `up`.
local function upFrame(pos, up, spin)
	up = up.Unit
	local r = up:Cross(Vector3.zAxis)
	if r.Magnitude < 1e-3 then r = up:Cross(Vector3.xAxis) end
	return CFrame.fromMatrix(pos, r.Unit, up) * CFrame.Angles(0, spin or 0, 0)
end

local function addCrystal(set, name, style, base, size, delay, dur, parent, flare, mode)
	local p = take(name, style)
	if not p then return nil end
	local c = {
		P = p, Kit = (not PLAIN[name]) and name or nil, Style = style, Base = base, Size = size, Delay = delay,
		Dur = math.max(0.05, dur), T = p.Transparency, Flare = flare, Mode = mode,
	}
	p.Transparency = 1                                   -- hidden until it starts to grow
	p.Size = size * Vector3.new(1, 0.03, 1)
	p.CFrame = base
	p.Parent = parent
	set[#set + 1] = c
	return c
end

--- Grow a set to time `t` (seconds on the set's own clock). Returns true while anything is still growing.
local function growStep(set, t, parts, cframes, thin)
	local busy = false
	for _, c in ipairs(set) do
		if not c.Done then
			local u = (t - c.Delay) / c.Dur
			if u <= 0 then
				busy = true
			else
				c.Started = true
				local k = easeOut(u)
				if c.P.Transparency ~= c.T then c.P.Transparency = c.T end
				local s = c.Size * Vector3.new(1, math.max(0.03, k), 1)
				c.P.Size = s
				parts[#parts + 1] = c.P
				cframes[#cframes + 1] = (c.Mode == "centre") and c.Base or (c.Base * CFrame.new(0, s.Y * 0.5, 0))
				-- the white-hot sliver at the base of a growing crystal, fading as it grows
				if c.Flare and not thin and u < 1 and not c.FlareP and not c.FlareDone then
					local fp = take("@Cyl", "Flare")
					if fp then
						local w = math.max(c.Size.X, c.Size.Z) * 1.1
						fp.Size = Vector3.new(0.06, w, w)
						fp.CFrame = c.Base * CFrame.Angles(0, 0, math.pi / 2)
						fp.Parent = c.P.Parent
						c.FlareP = fp
					end
				end
				if c.FlareP then c.FlareP.Transparency = 0.1 + 0.9 * math.min(u, 1) end
				if u >= 1 then
					c.Done = true
					c.FlareDone = true
					if c.FlareP then
						give(c.FlareP)
						c.FlareP = nil
					end
				else
					busy = true
				end
			end
		end
	end
	return busy
end

--- Snap a set: every big kit crystal leaves a stump and its top is thrown out from `centre`; `keep` is the share of
--- tops thrown (the rest just stand and sink). Small ones and plain parts simply melt with the sink.
local function snapSet(set, centre, gy, rng, speed, keep)
	for _, c in ipairs(set) do
		if c.FlareP then
			give(c.FlareP)
			c.FlareP = nil
		end
		c.Done = true
		local h = c.P.Size.Y
		c.Stump = h
		if c.Started and c.Kit and h > 0.7 and rng:NextNumber() < (keep or 1) then
			local stump = math.min(h * 0.45, rng:NextNumber(0.25, 0.7))
			local top = h - stump
			local cf = c.Base * CFrame.new(0, stump + top * 0.5, 0)
			local out = flat(cf.Position - centre)
			out = out.Magnitude > 1e-3 and out.Unit or Vector3.xAxis
			throw(c.Kit, cf, out * rng:NextNumber(speed * 0.5, speed) + Vector3.new(0, rng:NextNumber(3, 8), 0),
				out:Cross(Vector3.yAxis) * rng:NextNumber(3, 7), rng:NextNumber(1.0, 1.4), Vector3.new(c.Size.X, top, c.Size.Z),
				gy, c.Style, c.T)
			c.Stump = stump
		end
	end
end

--- Stop a set where it stands (for a melt rather than a shatter).
local function holdSet(set)
	for _, c in ipairs(set) do
		if c.FlareP then
			give(c.FlareP)
			c.FlareP = nil
		end
		c.Done = true
		c.Stump = c.P.Size.Y
	end
end

--- Sink a snapped or held set: `u` 0..1, the stumps going down into the floor and clearing as they go.
local function sinkSet(set, u, parts, cframes)
	for _, c in ipairs(set) do
		if c.Started then
			local s, cf
			if c.Mode == "centre" then
				s = Vector3.new(c.Size.X * (1 - 0.4 * u), math.max(0.02, c.Size.Y * (1 - u)), c.Size.Z * (1 - 0.4 * u))
				cf = c.Base
			else
				local hh = math.max(0.02, (c.Stump or c.Size.Y) * (1 - u))
				s = Vector3.new(c.Size.X, hh, c.Size.Z)
				cf = c.Base * CFrame.new(0, hh * 0.5, 0)
			end
			c.P.Size = s
			c.P.Transparency = c.T + (1 - c.T) * u * u
			parts[#parts + 1] = c.P
			cframes[#cframes + 1] = cf
		end
	end
end

local function dropSet(set)
	for _, c in ipairs(set) do
		give(c.P)
		if c.FlareP then give(c.FlareP) end
		c.FlareP = nil
	end
	table.clear(set)
end

--- A cluster (CRYO_V2_HANDOFF "Clusters"): 1-2 chunky six-sided base prisms carrying tall thin pointed spikes that lean
--- out, and a frost mound over the foot. `size` = the tallest spike (the base prisms are 0.32-0.5 of it tall and
--- 0.34-0.46 of it across, the spikes 0.14-0.22 of their own length across).
---   o = { Spikes, Bases, Mound, Out (lean direction), Delay, Stagger, Dur, Flare, BaseStyle, SpikeStyle }
local function cluster(set, rng, at, size, o, parent)
	local delay, stagger, dur = o.Delay or 0, o.Stagger or 0.03, o.Dur or 0.25
	local out = o.Out and flat(o.Out) or Vector3.zero
	local bases = {}
	for k = 1, math.max(1, o.Bases or 1) do
		local a = rng:NextNumber(0, 2 * math.pi)
		local off = (k == 1) and Vector3.zero or dirAt(a) * size * rng:NextNumber(0.12, 0.25)
		local name = crystalName(rng)
		local h = size * rng:NextNumber(0.42, 0.6)
		local w = size * rng:NextNumber(0.3, 0.4) * ((k == 1) and 1 or 0.8)
		local cf = footFrame(at + off - Vector3.new(0, 0.05, 0), out + off, rng:NextNumber(0, 0.22), rng:NextNumber(0, 2 * math.pi))
		addCrystal(set, name, o.BaseStyle or "Base", cf, crystalSize(name, w, h), delay - 0.02 + (k - 1) * stagger, dur * 0.8,
			parent, o.Flare, nil)
		bases[#bases + 1] = { CF = cf, H = h, W = w }
	end
	for i = 1, o.Spikes or 2 do
		local f = (i == 1) and 1 or ((i == 2) and rng:NextNumber(0.55, 0.85) or rng:NextNumber(0.3, 0.6))
		local h = size * f
		local w = h * rng:NextNumber(0.14, 0.22)
		local b = bases[rng:NextInteger(1, #bases)]
		local a = rng:NextNumber(0, 2 * math.pi)
		local side = dirAt(a)
		-- points at the top: each spike grows out of a base prism's upper half, leaning out
		local pos = (b.CF * CFrame.new(side * (b.W * rng:NextNumber(0.1, 0.3)) + Vector3.new(0, b.H * rng:NextNumber(0.25, 0.55), 0))).Position
		local lean = (i == 1) and rng:NextNumber(0.03, 0.15) or rng:NextNumber(0.12, 0.45)
		local name = crystalName(rng)
		addCrystal(set, name, o.SpikeStyle or "Body", footFrame(pos, side + out * 0.4, lean, rng:NextNumber(0, 2 * math.pi)),
			crystalSize(name, w, h), delay + i * stagger, dur * (0.8 + 0.4 * f), parent, false, nil)
	end
	if o.Mound then
		-- a low frost mound over the foot (the reel's: size x 0.1 + 0.15 tall), the base prisms standing out of it
		local w = size * rng:NextNumber(0.5, 0.62)
		addCrystal(set, "@Mound", "Frost", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
			Vector3.new(w, size * 0.12 + 0.1, w * rng:NextNumber(0.7, 1)), delay - 0.03, 0.18, parent, false, "centre")
	end
end

--- Crystals sprouting off a body's surface (not the head), each starting as the climbing line passes its foot.
local BODY_FACES = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis, Vector3.yAxis }

local function bodyCrystals(set, rng, model, feet, top, n, parent, climbAt, climbTime)
	local list, weights, total = {}, {}, 0
	for _, bp in ipairs(model:GetChildren()) do
		if bp:IsA("BasePart") and bp.Name ~= "HumanoidRootPart" and bp.Name ~= "Head" and bp.Transparency < 0.9 then
			local s = bp.Size
			local a = (s.X + s.Z) * s.Y
			list[#list + 1] = bp
			weights[#weights + 1] = a
			total += a
		end
	end
	if total <= 0 then return end
	local made, tries = 0, 0
	while made < n and tries < n * 5 do
		tries += 1
		local r, bp = rng:NextNumber(0, total), nil
		for i, w in ipairs(weights) do
			r -= w
			if r <= 0 then
				bp = list[i]
				break
			end
		end
		bp = bp or list[#list]
		local nl = BODY_FACES[rng:NextInteger(1, #BODY_FACES)]
		local s = bp.Size
		local lp = Vector3.new(
			nl.X ~= 0 and nl.X * s.X / 2 or rng:NextNumber(-0.45, 0.45) * s.X,
			nl.Y ~= 0 and nl.Y * s.Y / 2 or rng:NextNumber(-0.45, 0.45) * s.Y,
			nl.Z ~= 0 and nl.Z * s.Z / 2 or rng:NextNumber(-0.45, 0.45) * s.Z)
		local wp = bp.CFrame:PointToWorldSpace(lp)
		local z = wp.Y - feet
		if z >= 0.1 and z <= top then
			local nw = bp.CFrame:VectorToWorldSpace(nl)
			local axis = nw * 0.6 + Vector3.yAxis * 0.4
				+ Vector3.new(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.25, 0.25))
			if axis.Magnitude > 1e-3 then
				local h = rng:NextNumber(0.6, 2.0)
				local name = crystalName(rng)
				addCrystal(set, name, "Tip", upFrame(wp - nw * 0.06, axis, rng:NextNumber(0, 2 * math.pi)),
					crystalSize(name, h * rng:NextNumber(0.14, 0.22), h),
					climbAt + (z / top) * climbTime + rng:NextNumber(0, 0.06), 0.2, parent, false, nil)
				made += 1
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- FROST SKIN: white matte frost (Sand) hugging each body part between two world heights. Used as the band riding just
-- under a climbing Frost Line, and as the Chill crust (from the feet up).
----------------------------------------------------------------------------------------------------
local function skinNew(model, parent, maxHi, style, transparency)
	local s = { Items = {}, Parent = parent, MaxHi = maxHi, Style = style or "Skin", T = transparency or L.FrostSkinT }
	for _, bp in ipairs(model:GetChildren()) do
		if bp:IsA("BasePart") and bp.Name ~= "HumanoidRootPart" and bp.Transparency < 0.9 and bp.Size.Magnitude < 10 then
			s.Items[#s.Items + 1] = { Src = bp }
		end
	end
	return s
end

local function skinStep(s, lo, hi, fade, parts, cframes)
	if s.MaxHi then hi = math.min(hi, s.MaxHi) end
	local t = s.T + (1 - s.T) * fade
	for _, it in ipairs(s.Items) do
		local bp, shown = it.Src, false
		if bp.Parent and fade < 1 then
			local cf, sz = bp.CFrame, bp.Size
			local ext = math.abs(cf.RightVector.Y) * sz.X / 2 + math.abs(cf.UpVector.Y) * sz.Y / 2 + math.abs(cf.LookVector.Y) * sz.Z / 2
			local bottom = cf.Position.Y - ext
			local a, b = math.max(bottom, lo), math.min(cf.Position.Y + ext, hi)
			if ext > 1e-3 and b - a > 0.04 then
				local p = it.P
				if not p then
					p = take("@Block", s.Style)
					if p then
						p.Parent = s.Parent
						it.P = p
					end
				end
				if p then
					shown = true
					local fa, fb = (a - bottom) / (2 * ext), (b - bottom) / (2 * ext)
					local sign = (cf.UpVector.Y >= 0) and 1 or -1
					local size = Vector3.new(sz.X + 0.08, math.max(0.05, sz.Y * (fb - fa)), sz.Z + 0.08)
					if p.Size ~= size then p.Size = size end
					if p.Transparency ~= t then p.Transparency = t end
					parts[#parts + 1] = p
					cframes[#cframes + 1] = cf * CFrame.new(0, sign * (-sz.Y / 2 + sz.Y * (fa + fb) / 2), 0)
				end
			end
		end
		if not shown and it.P and it.P.Transparency ~= 1 then it.P.Transparency = 1 end
	end
end

local function skinDrop(s)
	if not s then return end
	for _, it in ipairs(s.Items) do
		if it.P then give(it.P) end
		it.P = nil
	end
end

----------------------------------------------------------------------------------------------------
-- THE FROZEN LOOK (play-test fix 2, approved 2026-10-08): a frozen body reads as pale ice and stays readable as WHO it
-- is. It used to go a dark navy silhouette (a #1F3F6B Highlight at 0.3 plus every part pulled 85% to the same navy).
--   TINT    a pale IceLight Highlight fill (Look.FrozenFill at FrozenFillT) with a thin white rim, and the body's own
--           colours nudged toward IceMid (FrozenShadeAmount), so lit faces read pale and shaded faces blue -- the closest
--           Roblox gets to the toon bands without a shader. Clothing and decals keep their pattern under it.
--   FROST   the shipped crust meshes, opaque white SmoothPlastic with their baked bands (never made transparent: the
--           inverted hull would show black): plates on every face of the legs up to the waist, a mound round the feet,
--           flat caps on the head and the shoulders. They appear as the frost climbs past them (the Frost Line's
--           direction) and go top-down as it lets go. Nothing covers the body above the waist except the caps.
-- Frozen is identified by shape first (crust, caps, the crystal cluster, FROZEN!); colour is secondary.
-- Every freeze goes through setTint(model, key, level): Flash Freeze and Deep Freeze (their encasing ice climbs it, and
-- the server's IceFrozenState holds it via CryoFX.FrozenHold), Mirror Cage (its volley climbs it). Several holders may
-- hold one body; the highest wins. Colours come back exactly; a value somebody else sets meanwhile (an appearance
-- reload) becomes the new base instead of being overwritten.
----------------------------------------------------------------------------------------------------
local tints = {}                 -- [model] = { Holders = { [key] = level | { Start, Dur } }, Level, Items, Look }
local FZ = L.FrozenCrust

local function tintItems(model)
	local items = {}
	for _, inst in ipairs(model:GetDescendants()) do
		local prop
		if inst:IsA("BasePart") then
			if inst.Name ~= "HumanoidRootPart" and inst.Transparency < 0.95 and inst:GetAttribute("CryoKit") == nil
				and inst:GetAttribute("CryoFrost") == nil then prop = "Color" end
		elseif inst:IsA("Clothing") or inst:IsA("Decal") then
			prop = "Color3"
		elseif inst:IsA("SpecialMesh") then
			prop = "VertexColor"
		end
		if prop then
			local ok, v = pcall(function() return inst[prop] end)
			if ok and v ~= nil then items[#items + 1] = { I = inst, K = prop, Orig = v } end
		end
	end
	return items
end

-- (2026-10-19, audit P5A-17) SHADE / SHADE_MUL were never read (applyTint reads L.FrozenShade live, so a wrap's swap
-- shows): removed, two of this module's 200 top-level locals back

--- Two colours the same to within 8-bit storage (a part's Color reads back quantized a frame later, so an exact compare
--- took our own write for somebody else's and re-based on it every frame -- the tint compounded all the way to the
--- target and never came back; that was much of the old "black silhouette").
local function sameColour(a, b)
	return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
end

local function applyTint(e, level)
	local amt = level * L.FrozenShadeAmount
	for _, it in ipairs(e.Items) do
		local inst = it.I
		if inst.Parent then
			local cur = inst[it.K]
			if it.Last ~= nil and not sameColour(cur, it.Last) then it.Orig = cur end
			local v
			if level <= 0 then
				v = it.Orig
			elseif it.K == "Color" then
				v = it.Orig:Lerp(L.FrozenShade, amt)              -- (read now: a wrap swaps it)
			elseif it.K == "Color3" then
				local o = it.Orig
				local fs = L.FrozenShade
				v = o:Lerp(Color3.new(o.R * fs.R, o.G * fs.G, o.B * fs.B), amt)
			else
				local fs = L.FrozenShade
				v = it.Orig:Lerp(it.Orig * Vector3.new(fs.R, fs.G, fs.B), amt)
			end
			inst[it.K] = v
			it.Last = (level > 0) and inst[it.K] or nil     -- read back: a part's Color is stored at 8 bits a channel
		end
	end
end

local LEGS = { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }
local SHOULDERS = { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }

local function crustTemplate(name)
	local meshes = ReplicatedStorage:FindFirstChild(VFXLibrary.Config.MeshFolderName)
	local t = meshes and meshes:FindFirstChild(name)
	if t and t:IsA("MeshPart") then return t end
	warnOnce("crust" .. name, ("%s not found in ReplicatedStorage.%s - the frozen crust skips it"):format(name,
		VFXLibrary.Config.MeshFolderName))
	return nil
end

--- The pale Highlight and the crust pieces for one frozen body (built once, the first time it is held).
local function frozenLookNew(model)
	local look = { Pieces = {} }
	local hl = Instance.new("Highlight")
	hl.Name = "CryoFrozenLook"
	hl.FillColor, hl.FillTransparency = L.FrozenFill, 1
	hl.OutlineColor, hl.OutlineTransparency = L.FrozenRim, 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	look.Highlight = hl
	local root, feet = feetOf(model)
	if not root then return look end
	local top = bodyTop(model, feet)
	local isMe = model == player.Character
	local few = (Settings.EffectDensity or 1) < 0.75
	local rng = Random.new(#model.Name * 7919 + 13)
	local function add(name, part, off, size, show)
		local t = crustTemplate(name)
		if not t then return end
		local p = t:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = true, false, false, false, true, false
		p.Transparency = 1
		p:SetAttribute("CryoFrost", true)
		if FBX.Wrap then FBX.Wrap.PaintKit({ P = { p } }) end      -- (the frost crust in the caster's wrap)
		p.Size = size
		p.Parent = fxFolder()
		look.Pieces[#look.Pieces + 1] = { P = p, Part = part, Off = off, Size = size, Show = show }
	end
	-- plates on every face of the legs, to the waist (front and back only on low graphics)
	for _, name in ipairs(LEGS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local s = part.Size
			local show = math.clamp((part.Position.Y - s.Y / 2 - feet) / top, 0, 1)
			local faces = { { Vector3.new(0, 0, -1), s.X, s.Z }, { Vector3.new(0, 0, 1), s.X, s.Z } }
			if not few then
				faces[3] = { Vector3.new(1, 0, 0), s.Z, s.X }
				faces[4] = { Vector3.new(-1, 0, 0), s.Z, s.X }
			end
			for _, f in ipairs(faces) do
				local n = f[1]
				local off = CFrame.lookAt(n * (f[3] / 2 + 0.04), n * 2) * CFrame.Angles(math.rad(90), 0, 0)
					* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
				add(FZ.Plates[rng:NextInteger(1, #FZ.Plates)], part, off, Vector3.new(f[2] * FZ.PlateOver, FZ.PlateThick, s.Y * 1.05), show)
			end
		end
	end
	-- the mound round the feet, under the root (upright with it)
	local rootH = root.Position.Y - feet
	add(FZ.Mound, root, CFrame.new(0, -rootH + FZ.MoundSize.Y * 0.4, 0), FZ.MoundSize, 0)
	-- caps on the head and the shoulders (not in the victim's own view: they would sit in its camera)
	if not isMe then
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			add(FZ.Cap, head, CFrame.new(0, head.Size.Y / 2 + 0.06, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
				Vector3.new(head.Size.X * FZ.CapOver, FZ.PlateThick + 0.02, head.Size.Z * FZ.CapOver), FZ.CapAt)
		end
		for _, name in ipairs(SHOULDERS) do
			local arm = model:FindFirstChild(name)
			if arm and arm:IsA("BasePart") then
				add(FZ.ShoulderCap, arm, CFrame.new(0, arm.Size.Y / 2 + 0.05, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					Vector3.new(arm.Size.X * FZ.ShoulderOver, FZ.PlateThick, arm.Size.Z * FZ.ShoulderOver), FZ.CapAt)
			end
		end
	end
	return look
end

local function frozenLookStep(look, level, now, parts, cframes)
	local hl = look.Highlight
	if hl then
		local ft = 1 - (1 - L.FrozenFillT) * level
		if math.abs(hl.FillTransparency - ft) > 1e-3 then hl.FillTransparency = ft end
		local ot = 1 - level
		if math.abs(hl.OutlineTransparency - ot) > 1e-3 then hl.OutlineTransparency = ot end
	end
	for _, pc in ipairs(look.Pieces) do
		local on = level > 0.01 and level >= pc.Show and pc.Part.Parent ~= nil
		if on then
			if not pc.At then pc.At = now end
			local k = 0.35 + 0.65 * easeOut((now - pc.At) / FZ.Pop)
			local size = pc.Size * k
			if pc.P.Size ~= size then pc.P.Size = size end
			if pc.P.Transparency ~= 0 then pc.P.Transparency = 0 end
			parts[#parts + 1] = pc.P
			cframes[#cframes + 1] = pc.Part.CFrame * pc.Off
		else
			pc.At = nil
			if pc.P.Transparency ~= 1 then pc.P.Transparency = 1 end
		end
	end
end

local function frozenLookDrop(look)
	if not look then return end
	if look.Highlight then look.Highlight:Destroy() end
	for _, pc in ipairs(look.Pieces) do pc.P:Destroy() end
	table.clear(look.Pieces)
end

--- Hold `model` frozen to `level` (0..1, how far the frost has climbed) under `key`; nil lets go (it eases back over
--- Look.TintOut). `level` may also be { Start = os.clock(), Dur = seconds }: a climb from 0 to 1 over Dur.
local function setTint(model, key, level)
	if not model then return end
	local e = tints[model]
	if level == nil then
		if e then e.Holders[key] = nil end
		return
	end
	if not e then
		e = { Holders = {}, Level = 0, Items = tintItems(model) }
		tints[model] = e
	end
	e.Holders[key] = (type(level) == "table") and level or math.clamp(level, 0, 1)
end

--- The server's frozen state (VFXLibrary's IceFrozenState, dressed on every client) holds the frozen look through here:
--- `climb` seconds for the frost to reach the top, then held until FrozenRelease.
function CryoFX.FrozenHold(model, key, climb)
	setTint(model, key, { Start = os.clock(), Dur = math.max(0.05, climb or 0.5) })
end

function CryoFX.FrozenRelease(model, key)
	setTint(model, key, nil)
end

run(function(now, dt, parts, cframes)
	for model, e in pairs(tints) do
		if not model.Parent then
			frozenLookDrop(e.Look)
			tints[model] = nil
		else
			local target = 0
			for _, lv in pairs(e.Holders) do
				if type(lv) == "table" then lv = math.clamp((now - lv.Start) / lv.Dur, 0, 1) end
				target = math.max(target, lv)
			end
			local lvl = (target >= e.Level) and target or math.max(target, e.Level - dt / L.TintOut)
			if lvl > 0 and not e.Look then
				local ok, look = pcall(FBX.WrapRun, model, frozenLookNew, model)
				e.Look = ok and look or { Pieces = {} }
				if not ok then warnOnce("frozenlook", "frozen look: " .. tostring(look)) end
			end
			if math.abs(lvl - e.Level) > 0.004 or (lvl <= 0 and e.Level > 0) then
				e.Level = lvl
				local ok, err = pcall(FBX.WrapRun, model, applyTint, e, lvl)
				if not ok then warnOnce("tint", "frozen tint: " .. tostring(err)) end
			end
			if e.Look then
				local ok, err = pcall(FBX.WrapRun, model, frozenLookStep, e.Look, e.Level, now, parts, cframes)
				if not ok then warnOnce("frozenstep", "frozen look: " .. tostring(err)) end
			end
			if e.Level <= 0 and next(e.Holders) == nil then
				frozenLookDrop(e.Look)
				tints[model] = nil
			end
		end
	end
	return true
end)

----------------------------------------------------------------------------------------------------
-- THE FROST DISC (floors; the reel's FrostDisc): the six-fold fractal frost sheet with its white crust and ragged,
-- fingered edge (one Decal, c2_frost_disc, on the top of a clear flat part), spreading from the centre with the Frost
-- Line on its edge -- then the line dims (and fades, if `RingFade`). It melts by clearing and shrinking a little.
--   o = { R, Spread, RingFade (nil: the dimmed ring stays until the melt), Melt, Parent, Tex, Tint, T (its opacity floor) }
----------------------------------------------------------------------------------------------------
local TEX = L.Textures

local function plainPart(name, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = true, false, false, false, true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--- The comic FROZEN! burst over a body (the reel's payoff word; Callouts' "frozen" style, popped on this client only).
local Callouts
local function popFrozen(model)
	if not Callouts then
		local f = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = f and f:FindFirstChild("Callouts")
		local ok, mod = pcall(function() return m and require(m) end)
		Callouts = ok and mod or false
	end
	local head = model and model:FindFirstChild("Head")
	if Callouts and head then pcall(Callouts.Pop, head, Vector3.new(0, 2.6, 0), "FROZEN!", "frozen") end
end

--- A clear flat part carrying a texture on its top face (a frost disc, a ring, the storm's floor): `size` x 0.05 x `size`.
local function decalDisc(tex, tint, parent)
	local p = Instance.new("Part")
	p.Name = "CryoDisc"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = true, false, false, false, true, false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.05, 0.1)
	local d = Instance.new("Decal")
	d.Name = "Face"
	d.Face = Enum.NormalId.Top
	d.Texture = tex
	-- (no tint given: white over the painted art -- in a wrap, the wrap's disc tint, so Deep Freeze's and the cage's floors
	-- follow it)
	d.Color3 = tint or (FBX.Wrap and FBX.Wrap.Active and FBX.C(Color3.fromRGB(226, 243, 252))) or COL.White
	d.Transparency = 1
	d.Parent = p
	p.Parent = parent or fxFolder()
	return p, d
end

local function floorNew(center, rng, o)
	local fl = { C = center, O = o, Spin = rng:NextNumber(0, 2 * math.pi) }
	fl.Disc, fl.Face = decalDisc(o.Tex or TEX.FrostDisc, o.Tint, o.Parent)
	fl.Disc.CFrame = CFrame.new(center)
	fl.Ring = take("CK_Ring", "Line")
	if fl.Ring then
		fl.Ring.Transparency = 1
		fl.Ring.CFrame = CFrame.new(center)
		fl.Ring.Parent = o.Parent
	end
	return fl
end

--- `age` on the disc's own clock; returns false once it has melted.
local function floorStep(fl, age, parts, cframes)
	local o, c = fl.O, fl.C
	local melt = fl.MeltAt and smooth((age - fl.MeltAt) / o.Melt) or 0
	local still = age > o.Spread + L.LineDimTime + (o.RingFade or 0) + 0.05 and not fl.MeltAt
	if still and fl.Placed then return true end                -- spread, dimmed and holding: nothing moves
	fl.Placed = still
	local r = math.max(0.05, o.R * easeOut(age / o.Spread) * (1 - 0.12 * melt))
	if fl.Disc then
		local sz = Vector3.new(2.2 * r, 0.05, 2.2 * r)           -- the texture's edge sits at 0.9 of its half-width
		if fl.Disc.Size ~= sz then fl.Disc.Size = sz end
		local t = (o.T or 0.05) + (1 - (o.T or 0.05)) * melt
		if math.abs(fl.Face.Transparency - t) > 1e-3 then fl.Face.Transparency = t end
		parts[#parts + 1] = fl.Disc
		cframes[#cframes + 1] = CFrame.new(c + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, fl.Spin, 0)
	end
	-- the line: lit on the spreading edge, dimming the moment the spread stops
	if fl.Ring then
		local fade = math.max(o.RingFade and smooth((age - o.Spread) / o.RingFade) or 0, melt)
		if fade >= 1 then
			if fl.Ring.Transparency ~= 1 then fl.Ring.Transparency = 1 end
		else
			lineLook(fl.Ring, o.Glow or (1 - smooth((age - o.Spread) / L.LineDimTime)), fade)
			placeRing(fl.Ring, CFrame.new(c + Vector3.new(0, 0.07, 0)), r, r, L.LineThick, parts, cframes)
		end
	end
	return melt < 1
end

local function floorDrop(fl)
	if not fl then return end
	if fl.Disc then fl.Disc:Destroy() end
	give(fl.Ring)
	fl.Disc, fl.Ring = nil, nil
end

----------------------------------------------------------------------------------------------------
-- THE ENCASING ICE (CRYO_V2_HANDOFF "Encasing mass" and "Frozen target"): chunky foot prisms (nearly opaque) with
-- frost mounds, tall crystals rooted round the body fused into one faceted mass, 1-3 clear spires, a ring of small
-- clusters leaning out round it, crystals sprouting off the body as the line passes; white frost riding just under
-- the climbing Frost Line, the body tinted dark blue under it. The victim's own view keeps only the low pieces, so a
-- frozen player can still see to shoot.
--   P = Look.Encase.*; o = { Parent, IsMe, Thin, Caster, LineTop, ClimbAt, ClimbTime, Seal, GrowAt, CrackAt, CrackTime }
----------------------------------------------------------------------------------------------------
local encases = {}               -- [model] = enc (Deep Freeze prisons and Flash Freeze roots)

local function encaseNew(model, at, rng, P, o)
	local enc = { Model = model, At = at, P = P, O = o, Set = {}, Key = {}, Cracks = {} }
	local root, feet = feetOf(model)
	enc.Feet = feet or at.Y
	enc.Top = math.min(o.LineTop, bodyTop(model, enc.Feet) * 1.04)
	local look = root and flat(root.CFrame.LookVector) or Vector3.zero
	enc.Look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local parent, thin, isMe = o.Parent, o.Thin, o.IsMe
	local g0, seal = o.GrowAt, o.Seal
	if o.FB then
		-- FROSTBLADE: no crystals. Flash Freeze ("Pierce"): big kunai through the body and small ones lodged in it; Deep
		-- Freeze ("Trap"): blades springing up round the feet and small ones lodged. The frozen coat, its tint and the Frost
		-- Line stay the Default's. Never on the victim's own client (they would sit in its camera).
		enc.Kunai = {}
		-- the body as this client draws it now: floor pieces built round it (Slide) follow its flat position from here, so a
		-- moving victim -- drawn a replication delay behind where the server stops it -- does not walk out of them
		enc.Root, enc.Root0 = root, root and root.Position
		-- (Snow Globe's "GlobeFF" rides the same path: small flakes over the body, SnowGlobeKit.BodyBlooms)
		local lotus = o.FB == "LotusFF" or o.FB == "LotusDF" or o.FB == "GlobeFF"
		-- (Frost Dragon's "DragonDF": crystal scales laid over the body, FrostDragonFX.EncaseKit)
		local kit = (o.FB == "DragonDF" and FBX.Dragon() and FBX.Dragon().EncaseKit)
			or (lotus and ((o.FB == "GlobeFF" and FBX.GK) or FBX.LotusKit())) or FBX.Kit()
		enc.Kit = kit
		if kit and not isMe then
			local tier = kit.Tier(Settings.EffectDensity, thin)
			local spots = {}
			local function add(list)
				for _, sp in ipairs(list) do spots[#spots + 1] = sp end
			end
			if lotus then
				-- FROST LOTUS: mini lotus blooms all over the body, a wave from the feet up -- capped, and fewer once many
				-- bodies are frozen in view; Deep Freeze: a wide lotus opening under the feet as well
				local n = kit.BodyLotus[tier]
				local frozen = 0
				for _ in pairs(encases) do frozen += 1 end
				if frozen >= kit.BodyCrowdAt then n = math.min(n, kit.BodyLotusCrowd) end
				add(kit.BodyBlooms(model, n, 0))
				if o.FB == "LotusDF" then
					add({ { Kind = "TrapBloom", K = kit.BloomFrame(Vector3.new(root and root.Position.X or at.X, at.Y + 0.05,
						root and root.Position.Z or at.Z), Vector3.yAxis), S = 2.2, Grow = true, Slide = true, Delay = 0, Dur = 0.25 } })
				end
			elseif o.FB == "DragonDF" then
				add(kit.Scales(model, at, tier, o.Caster))
			elseif o.FB == "Pierce" then
				add(kit.Pierce(model, kit.PierceBig[tier]))
				add(kit.Stuck(model, kit.StuckSmall[tier], 0.2, 5))
			else
				add(kit.Trap(model, at, kit.TrapBlades[tier]))
				add(kit.Stuck(model, kit.TrapStuck[tier], 0.15, 7))
			end
			for _, sp in ipairs(spots) do
				local kn = kit.New(sp.Kind, parent)
				if kn then
					kit.Fade(kn, 1)
					sp.O = kn
					sp.Delay = (sp.Delay or 0) + g0
					enc.Kunai[#enc.Kunai + 1] = sp
				end
			end
		end
		enc.Line = take("CK_Ring", "Line")
		if enc.Line then
			enc.Line.Transparency = 1
			enc.Line.CFrame = CFrame.new(at)
			enc.Line.Parent = parent
		end
		return enc
	end
	-- the mass at the base: chunky prisms round the feet, frost heaped over them
	local nf = thin and math.max(2, P.FootPrisms - 1) or P.FootPrisms
	for k = 1, nf do
		local a = 2 * math.pi * k / nf + rng:NextNumber(-0.5, 0.5)
		local dir = dirAt(a)
		local name = crystalName(rng)
		local h = rng:NextNumber(P.FootH[1], P.FootH[2])
		if isMe then h = math.min(h, 2.2) end
		local w = 2 * rng:NextNumber(0.55, 0.85)
		local pos = at + dir * P.Foot * rng:NextNumber(0.6, 1.0) - Vector3.new(0, 0.1, 0)
		addCrystal(enc.Set, name, "EncaseBase", footFrame(pos, dir, rng:NextNumber(0.05, 0.25), rng:NextNumber(0, 2 * math.pi)),
			crystalSize(name, w, h), g0, seal * 0.8, parent, true, nil)
		if not thin then
			local mw = w * 1.5
			addCrystal(enc.Set, "@Mound", "Frost", CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
				Vector3.new(mw, h * 0.4, mw * 0.85), g0 - 0.02, 0.2, parent, false, "centre")
		end
	end
	if not isMe then
		-- the encasing mass: tall crystals rooted round the body, nearly upright, overlapping into one block
		for _ = 1, (thin and math.ceil(P.Mass / 2) or P.Mass) do
			local dir = dirAt(rng:NextNumber(0, 2 * math.pi))
			local h = rng:NextNumber(P.H[1], P.H[2])
			local name = crystalName(rng)
			addCrystal(enc.Set, name, "EncaseMid",
				footFrame(at + dir * P.Foot * rng:NextNumber(0.4, 1.0) - Vector3.new(0, 0.1, 0), dir, rng:NextNumber(0.06, 0.32), rng:NextNumber(0, 2 * math.pi)),
				crystalSize(name, 2 * h * rng:NextNumber(0.15, 0.21), h), g0 + rng:NextNumber(0, P.Stagger), seal, parent, false, nil)
		end
		-- the spires: the clear top of the mass
		local ns = thin and 1 or P.Spires
		for i = 1, ns do
			local dir = dirAt(2 * math.pi * i / ns + rng:NextNumber(-0.6, 0.6))
			local h = rng:NextNumber(P.SH[1], P.SH[2])
			local name = crystalName(rng)
			addCrystal(enc.Set, name, "EncaseTop",
				footFrame(at + dir * P.Foot * 0.7 * rng:NextNumber(0.4, 1.0) - Vector3.new(0, 0.1, 0), dir, rng:NextNumber(0.03, 0.12), rng:NextNumber(0, 2 * math.pi)),
				crystalSize(name, 2 * h * rng:NextNumber(0.08, 0.11), h), g0 + rng:NextNumber(0, P.Stagger) + 0.08, seal, parent, true, nil)
		end
		if not thin then bodyCrystals(enc.Set, rng, model, enc.Feet, enc.Top, P.Body, parent, o.ClimbAt, o.ClimbTime) end
	end
	-- the base ring: small clusters leaning out round the block (low, so the victim's own view keeps them)
	local nr = thin and math.ceil(P.Ring / 2) or P.Ring
	for i = 1, nr do
		local dir = dirAt((i + rng:NextNumber(-0.3, 0.3)) * 2 * math.pi / nr)
		cluster(enc.Set, rng, at + dir * (P.RingInner + rng:NextNumber(0, 0.8)), P.RingSize * rng:NextNumber(0.5, 1.0),
			{ Spikes = thin and 1 or 2, Bases = 1, Mound = false, Out = dir, Delay = g0 + 0.05 + i * 0.02, Stagger = 0.03, Dur = 0.2 }, parent)
	end
	-- the frost skin (only the legs in the victim's own view: anything higher sits in their camera) and the body line
	-- (the frost on the body is the frozen look's crust -- legs to the waist, caps -- held through setTint below)
	enc.Line = take("CK_Ring", "Line")
	if enc.Line then
		enc.Line.Transparency = 1
		enc.Line.CFrame = CFrame.new(at)
		enc.Line.Parent = parent
	end
	return enc
end

--- White cracks racing across the biggest crystals (the warning before the break).
local function encaseCracks(enc, rng)
	local big = {}
	for _, c in ipairs(enc.Set) do
		if c.Kit and c.Started and c.Size.Y > 1.8 then big[#big + 1] = c end
	end
	table.sort(big, function(a, b) return a.Size.Y > b.Size.Y end)
	for i = 1, math.min(#big, enc.O.Thin and 3 or 6) do
		local c = big[i]
		local p = take("@Block", "HotCrack")
		if p then
			local side = (rng:NextNumber() < 0.5) and -1 or 1
			p.Transparency = 1
			p.Parent = enc.O.Parent
			-- on one face (its local X), running across it at a slant (turned about X, so it stays in the face)
			enc.Cracks[#enc.Cracks + 1] = {
				P = p, C = c, Len = rng:NextNumber(0.8, 1.8),
				Local = CFrame.new(side * c.Size.X * 0.46, c.Size.Y * rng:NextNumber(0.2, 0.6), 0)
					* CFrame.Angles(rng:NextNumber(-1.1, 1.1), 0, 0),
			}
		end
	end
end

local function encaseStep(enc, age, parts, cframes)
	local o, P = enc.O, enc.P
	local broke = enc.BrokeAt ~= nil
	-- the climb: the frost and its line go up the body (fast at first, easing in)
	local cu = math.clamp((age - o.ClimbAt) / o.ClimbTime, 0, 1)
	local h = enc.Top * (1 - (1 - cu) ^ 1.6)
	if not broke then
		growStep(enc.Set, age, parts, cframes, o.Thin)
		setTint(enc.Model, enc.Key, cu)
		if enc.Kunai and #enc.Kunai > 0 then
			local kit = enc.Kit or FBX.Kit()
			for _, kn in ipairs(enc.Kunai) do
				local u = (age - kn.Delay) / kn.Dur
				if u > 0 then
					kit.Fade(kn.O, 0)
					if kn.Part and kn.Part.Parent then
						kn.Base = kn.Part.CFrame * kn.Rel
					elseif kn.Slide and enc.Root and enc.Root.Parent
						and (enc.Root.Position - enc.Root0).Magnitude < 12 then       -- (further = a respawn / teleport: stay)
						kn.Base = kn.K + (enc.Root.Position - enc.Root0) * Vector3.new(1, 0, 1)
					end
					local base = kn.Base or kn.K
					if base and kn.Grow then                          -- a lotus bloom sprouts out of the body
						kit.Place(kn.O, base, parts, cframes, (kn.S or 1) * math.max(0.02, easeOut(math.min(u, 1))))
					elseif base then
						-- driven in along its length (a lodged one a little, from the tang end); a trap blade rises out of the floor
						local back = ((kn.Kind == "Small") and 0.6 or kn.L) * (1 - easeOut(math.min(u, 1)))
						kit.Place(kn.O, base * CFrame.new(0, -back, 0), parts, cframes, kn.S or 1, kn.SY or 1)
					end
				end
			end
		end
	end
	local fade = broke and smooth((age - enc.BrokeAt) / 0.35) or 0
	local feet = enc.Feet
	if enc.Skin then skinStep(enc.Skin, feet + h - P.Band, feet + h, fade, parts, cframes) end
	if enc.Line then
		if cu <= 0 or fade >= 1 then
			if enc.Line.Transparency ~= 1 then enc.Line.Transparency = 1 end
		elseif not (enc.LinePlaced and cu >= 1 and age > o.ClimbAt + o.ClimbTime + L.LineDimTime and not broke) then
			lineLook(enc.Line, (cu < 1) and 1 or (1 - smooth((age - o.ClimbAt - o.ClimbTime) / L.LineDimTime)), fade)
			local y = feet + math.max(0.05, h)
			placeRing(enc.Line, CFrame.lookAt(Vector3.new(enc.At.X, y, enc.At.Z), Vector3.new(enc.At.X, y, enc.At.Z) + enc.Look),
				P.LineRX, P.LineRZ, L.LineThick, parts, cframes)
			enc.LinePlaced = cu >= 1
		end
	end
	-- the warning: white cracks race across the block
	if o.CrackAt and not broke then
		if age >= o.CrackAt and not enc.Cracked then
			enc.Cracked = true
			encaseCracks(enc, Random.new())
		end
		if enc.Cracked then
			local u = easeOut((age - o.CrackAt) / math.max(0.1, o.CrackTime or 0.6))
			for _, ck in ipairs(enc.Cracks) do
				if ck.P.Transparency ~= STYLE.HotCrack[3] then ck.P.Transparency = STYLE.HotCrack[3] end
				ck.P.Size = Vector3.new(0.05, math.max(0.05, ck.Len * u), 0.04)
				parts[#parts + 1] = ck.P
				cframes[#cframes + 1] = ck.C.Base * ck.Local
			end
		end
	end
	if broke then
		-- shattered: the stumps stand a moment, then sink; melted: everything goes down at once
		local u = smooth((age - enc.BrokeAt - (enc.Melting and 0 or 0.7)) / (enc.Melting and 0.7 or 0.6))
		sinkSet(enc.Set, u, parts, cframes)
		if age > enc.BrokeAt + 1.5 then
			dropSet(enc.Set)
			skinDrop(enc.Skin)
			give(enc.Line)
			for _, ck in ipairs(enc.Cracks) do give(ck.P) end
			table.clear(enc.Cracks)
			setTint(enc.Model, enc.Key, nil)
			return false
		end
	end
	return true
end

--- Break the ice (`heavy`: it shatters, tops thrown, shards, powder and a cold flash) or melt it (it sinks away).
--- FROSTBLADE's shatter (kit/fb_ff.py, fb_df.py): LOW and OUTWARD -- heavy ice chunks thrown out from the body, falling
--- and settling in the frost, shards, powder and flakes driven out sideways, one kunai piece per big blade (every other
--- trap blade); nothing rises above the head. The Default's ripple and cold flash.
function FBX.Shatter(enc)
	local kit = enc.Kit or FBX.Kit()
	local rng = Random.new()
	local dens = density(enc.O.Caster)
	local tier = kit.Tier(Settings.EffectDensity, enc.O.Thin)
	local c = Vector3.new(enc.At.X, enc.Feet, enc.At.Z)
	local piece = kit.ShatterPiece or "FB_Frag"
	local frag = kit.Kind(kit.ShatterPiece and "Mote" or "Frag")
	-- (2026-10-19, audit P5A-07) the fragment's size from whichever shape the kit builds (Snow Globe's kinds are layered,
	-- no Size), and a stand-in when neither is there, so the throw below never does arithmetic on nil
	local fsize = frag and (frag.Size or (frag.Layers and frag.Layers[1] and frag.Layers[1].Size)) or Vector3.new(0.6, 1, 0.6)
	local nTrap = 0
	for _, kn in ipairs(enc.Kunai) do
		if kn.Kind == "Trap" then nTrap += 1 end
		local petal = kit.ShatterPiece ~= nil and (kn.Kind == "TrapBloom" or rng:NextNumber() < 0.5)
		if frag and (petal or kn.Kind == "Big" or (kn.Kind == "Trap" and nTrap % 2 == 1)) and kn.O.Body.Transparency < 1 then
			local mid = kn.O.Body.Position
			local out = flat(mid - c)
			out = out.Magnitude > 1e-3 and out.Unit or dirAt(rng:NextNumber(0, 2 * math.pi))
			local y = math.clamp(mid.Y, c.Y + 0.6, c.Y + 2.6)
			throw(piece, CFrame.new(mid.X, y, mid.Z) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
				out * rng:NextNumber(3, 6) * (petal and 0.6 or 1) + Vector3.new(0, rng:NextNumber(1, 3) * (petal and 0.6 or 1), 0),
				Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 7, rng:NextNumber(1.2, 1.6),
				fsize * (petal and rng:NextNumber(0.3, 0.45) or rng:NextNumber(1.4, 2.0)), c.Y, "Kunai")
		end
	end
	burstChunks(rng, c, CFrame.new(c + Vector3.new(0, 1.8, 0)), Vector3.new(0.5, 1.3, 0.4),
		(kit.ShatterChunks or { 8, 5, 3 })[tier] or 3, 7, 4,         -- (2026-10-19, audit P5A-07) a kit without counts: Frostblade's
		0.55, 1.05, c.Y, "Chunk")
	for k = 0, 5 do
		local dir = dirAt(k * math.pi / 3 + rng:NextNumber(0, 0.5)) + Vector3.new(0, 0.25, 0)
		burst(c + Vector3.new(0, 0.7 + 0.6 * (k % 3), 0), dir, { Chips = 8, Powder = 2, Flakes = 2 }, dens, 0.8)
	end
	ripple(CFrame.new(c + Vector3.new(0, 0.06, 0)), 0.8, 5.5, 0.7)
	flashAt(c + Vector3.new(0, 1.6, 0), 3, 16, 0.25)
end

local function encaseBreak(enc, age, heavy)
	if enc.BrokeAt then return end
	enc.BrokeAt = age
	setTint(enc.Model, enc.Key, nil)
	for _, ck in ipairs(enc.Cracks) do give(ck.P) end
	table.clear(enc.Cracks)
	if enc.Kunai then
		local kit = enc.Kit or FBX.Kit()
		-- (2026-10-19, audit P5A-07) a skin shatter that fails (or no kit) falls through to the Default's heavy shatter
		-- below (bursts, ripple, cold flash) instead of ending the freeze with nothing drawn
		local shattered = false
		if heavy and kit then
			local ok, err = pcall(FBX.Shatter, enc)
			if not ok then warnOnce("fbshatter", "frostblade shatter: " .. tostring(err)) end
			shattered = ok
		end
		if kit then for _, kn in ipairs(enc.Kunai) do kit.Drop(kn.O) end end
		table.clear(enc.Kunai)
		if heavy and shattered then return end
	end
	if heavy then
		local rng = Random.new()
		local dens = density(enc.O.Caster)
		snapSet(enc.Set, enc.At, enc.Feet, rng, 9, enc.O.Thin and 0.5 or 1)
		for k = 0, 3 do
			burst(enc.At + Vector3.new(0, 0.6 + 1.5 * k, 0), Vector3.yAxis, { Chips = 10, Powder = 6, Glints = 6, Flakes = 4 }, dens, 1.3)
		end
		ripple(CFrame.new(enc.At + Vector3.new(0, 0.06, 0)), 0.8, 5.5, 0.7)
		flashAt(enc.At + Vector3.new(0, 2.5, 0), 3, 16, 0.25)
	else
		enc.Melting = true
		holdSet(enc.Set)
		burst(enc.At + Vector3.new(0, 1, 0), Vector3.yAxis, { Powder = 6, Breath = 6 }, density(enc.O.Caster))
	end
end

----------------------------------------------------------------------------------------------------
-- FREEZE BEATS: someone caught (heavy = false) and the Flash Freeze shatter (heavy = true). A caught body grows the
-- encasing ice (the zone's lingering target), held while the server's frozen state is. (The shard's third Chill stack
-- no longer comes through here: it is a deep slow since 2026-10-08, drawn by its crust -- see CHILL below.)
----------------------------------------------------------------------------------------------------

local function flashFreezeEncase(character, root, caster)
	local P = L.Encase.FlashFreeze
	local _, feet = feetOf(character)
	local at = Vector3.new(root.Position.X, feet or (root.Position.Y - 3), root.Position.Z)
	local isMe = character == player.Character
	local thin = thinFor(caster)                -- (2026-10-19, audit P5A-12) thinned by its CASTER, as Deep Freeze's is
	local folder = Instance.new("Folder")
	folder.Name = "FlashFreezeIce"
	folder.Parent = fxFolder()
	local enc = encaseNew(character, at, Random.new(), P, {
		Parent = folder, IsMe = isMe, Thin = thin, Caster = caster, LineTop = P.LineTop, ClimbAt = 0, ClimbTime = P.ClimbTime,
		Seal = P.Seal, GrowAt = P.GrowAt, FB = (FBX.LotusOn(caster) and "LotusFF") or (FBX.On(caster) and "Pierce")
			or (FBX.Globe(caster) and "GlobeFF") or nil,
	})
	encases[character] = enc
	local t0 = os.clock()
	local goneAt = nil
	run(function(now, dt, parts, cframes)
		local age = now - t0
		if not enc.BrokeAt then
			-- held while the server's frozen state is on the body (a grace for it to arrive, and for a shatter to follow)
			if character:FindFirstChild("IceFrozenState") then
				enc.SeenState = true
				goneAt = nil
			elseif enc.SeenState or age > 0.6 then
				goneAt = goneAt or age
			end
			if enc.Break or isDead(character) or age > P.MaxLife or (goneAt and age - goneAt > 0.3) then
				encaseBreak(enc, age, enc.Break == "heavy")
			end
		end
		if not encaseStep(enc, age, parts, cframes) then
			folder:Destroy()
			if encases[character] == enc then encases[character] = nil end
			return false
		end
		return true
	end)
end

--- `caster`: who froze them (Flash Freeze's broadcasts carry it), for their skin.
function CryoFX.Shatter(character, heavy, caster)
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	if not root then return end
	local enc = encases[character]
	local dens = density(caster)                    -- (2026-10-19, audit P5A-12) thinned by the caster, not the victim
	local _, feet = feetOf(character)
	local base = Vector3.new(root.Position.X, feet or (root.Position.Y - 3), root.Position.Z)
	if heavy then
		local h = host(root.CFrame)
		playSound(h, "Shatter")
		task.delay(1, function() h:Destroy() end)
		if enc and not enc.BrokeAt then
			enc.Break = "heavy"                         -- the ice goes with a bang (its own shards, powder and flash)
			return
		end
		local rng = Random.new()
		local thin = thinFor(caster)
		local gy = groundY(root.Position, { character, fxFolder() })
		burstChunks(rng, root.Position, root.CFrame, Vector3.new(0.8, 1.6, 0.5), thin and 6 or 12, 18, 14, 0.3, 0.7, gy, "Chunk")
		for k = 0, 2 do
			burst(base + Vector3.new(0, 0.8 + 1.4 * k, 0), Vector3.yAxis, { Chips = 10, Powder = 5, Glints = 5, Flakes = 5 }, dens, 1.3)
		end
		ripple(CFrame.new(base + Vector3.new(0, 0.06, 0)), 0.8, 5.5, 0.7)
		flashAt(root.Position, 3, 16, 0.25)
		return
	end
	-- caught: a ripple at the feet and a pop of powder
	ripple(CFrame.new(base + Vector3.new(0, 0.06, 0)), 0.4, 3.4, 0.6)
	burst(base + Vector3.new(0, 0.4, 0), Vector3.yAxis, { Powder = 8, Flakes = 6, Chips = 6 }, dens)
	if not enc then
		local ok, err = pcall(flashFreezeEncase, character, root, caster)
		if not ok then warnOnce("ffencase", "frozen ice: " .. tostring(err)) end
	end
end

--- Flash Freeze's slam (VFXLibrary.CastFlashFreeze calls this on the beat the front leaves the hand; the zone, its light
--- and its sounds are VFXLibrary's): a ripple out of the press, powder and chips off the floor, pieces of the darker
--- frozen floor thrown; mist, sparkles and ripples over the sheet while it holds; a ring of powder at the break.
function CryoFX.FlashFreezeSlam(burstPart, ground)
	local rng = Random.new()
	local thin = (Settings.EffectDensity or 1) < 0.75
	local dens = density(nil)
	local gy = ground.Position.Y
	local FFT = VFXLibrary.Tuning.FlashFreeze
	local R = FFT.Radius
	local hold = FFT.ExpandTime + FFT.RimLinger                    -- the slam to the break
	ripple(ground * CFrame.new(0, 0.06, 0), 0.6, R * 0.4, 0.6)
	burst(ground.Position + Vector3.new(0, 0.3, 0), Vector3.yAxis, { Powder = 12, Chips = 16, Flakes = 6 }, dens, 1.4)
	burstChunks(rng, ground.Position - Vector3.new(0, 1, 0), ground * CFrame.new(0, 0.4, 0), Vector3.new(2.2, 0.2, 2.2),
		thin and 3 or 6, 22, 15, 0.45, 1.0, gy, "Slab")
	-- the zone's weather while it holds
	local mistHost = host(ground * CFrame.new(0, 0.9, 0))
	mistHost.Size = Vector3.new(R * 1.5, 1.2, R * 1.5)
	local mist = mistEmitter(mistHost, 6, 12, 0.75)
	local sparkle
	if not thin then
		sparkle = Instance.new("ParticleEmitter")
		for k, v in pairs(KINDS.Glints.Props) do sparkle[k] = v end
		sparkle.LightEmission = 0.3
		sparkle.Speed = NR(0.2, 0.6)
		sparkle.Lifetime = NR(0.4, 0.8)
		sparkle.Rate = 0
		FBX.Lit(sparkle)
		sparkle.Parent = mistHost
	end
	task.delay(FFT.ExpandTime * 0.6, function()
		mist.Rate = thin and 5 or 10
		if sparkle then sparkle.Rate = 7 * dens end
	end)
	-- powder where the crystals erupt (about 1.1-1.3 s after the slam, over the middle of the sheet)
	task.delay(1.1, FBX.Bind(function()
		for _ = 0, (thin and 3 or 7) do
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(R * 0.2, R * 0.75)
			burst((ground * CFrame.new(math.sin(a) * r, 0.6, math.cos(a) * r)).Position, Vector3.yAxis, { Powder = 3 }, dens)
		end
	end))
	-- thin ripples across the sheet every 0.75 s
	if not thin then
		local rp = FBX.Bind(ripple)          -- (the loop waits, so only the ripple itself carries the wrap)
		task.spawn(function()
			local t = 0.75
			while t < hold - 0.3 do
				task.wait(0.75)
				if not mistHost.Parent then return end
				local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, R * 0.6)
				rp(ground * CFrame.new(math.sin(a) * r, 0.06, math.cos(a) * r), 0.3, 3, 0.6)
				t += 0.75
			end
		end)
	end
	task.delay(hold - 0.3, function()
		mist.Rate = 0
		if sparkle then sparkle.Rate = 0 end
	end)
	task.delay(hold, FBX.Bind(function()
		for k = 0, (thin and 5 or 11) do
			local a = k * 2 * math.pi / (thin and 6 or 12)
			burst((ground * CFrame.new(math.sin(a) * R * 0.7, 0.6, math.cos(a) * R * 0.7)).Position, Vector3.yAxis,
				{ Powder = 3, Chips = 3 }, dens)
		end
		burstChunks(Random.new(), ground.Position - Vector3.new(0, 1, 0), ground * CFrame.new(0, 0.6, 0), Vector3.new(R * 0.6, 0.3, R * 0.6),
			thin and 4 or 8, 14, 12, 0.35, 0.8, gy, "Slab")
		ripple(ground * CFrame.new(0, 0.06, 0), 1, R, 0.8, 0.5)
	end))
	task.delay(hold + 3.5, function() mistHost:Destroy() end)
end

--- FROSTBLADE's zone edge (kit/fb.py edge_blades): a few short kunai planted point-down on the zone's rim, flats facing
--- out, leaning out, ring pommels up -- rising out of the floor as the front reaches the rim (`growAt`, seconds after the
--- cast), breaking on the Default's wave (`breakAt`): a piece and a few crumbs each. The low tier's count under Reduce
--- Enemy VFX (2026-10-19, audit P5A-12: it used to vanish, while the Default keeps its rim clusters).
function CryoFX.FrostbladeEdge(ground, R, growAt, breakAt, caster)
	local kit = FBX.Kit()
	if not (kit and kit.Kind("Edge")) then return end
	local folder = Instance.new("Folder")
	folder.Name = "FrostbladeEdge"
	folder.Parent = fxFolder()
	local c = ground.Position
	local fs = kit.FieldScale or 1                       -- (2026-10-15) denser and bigger: FieldBlades by tier, FieldScale
	local L, bury = kit.Kinds.Edge.L * fs, 0.5 * fs
	local n = kit.FieldBlades and kit.FieldBlades[kit.Tier(Settings.EffectDensity, Settings.ThinEnemyVFX and FBX.Enemy(caster))] or kit.EdgeBlades
	local blades = {}
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / n + 0.35
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local tg = Vector3.new(-math.sin(a), 0, math.cos(a))
		local g = c + d * (R - 0.5)
		local up = Vector3.yAxis * math.cos(0.18) + d * math.sin(0.18)
		local o = kit.New("Edge", folder)
		if o then
			kit.Fade(o, 1)
			local frac = k / n
			blades[#blades + 1] = { O = o, K = kit.Frame(g + up * (L - bury), -up, tg), At = g, Out = d,
				Delay = math.min(frac, 1 - frac) * 0.7 }
		end
	end
	local frag = kit.Kind("Frag")
	local t0 = os.clock()
	run(function(now, dt, parts, cframes)
		local t = now - t0
		if t >= breakAt or not folder.Parent then
			if folder.Parent then
				local rng = Random.new()
				for _, b in ipairs(blades) do
					if frag and b.O.Body.Transparency < 1 then
						throw("FB_Frag", CFrame.new(b.At + Vector3.new(0, 0.9, 0)) * CFrame.Angles(rng:NextNumber(0, 6.28), 0, rng:NextNumber(0, 6.28)),
							b.Out * rng:NextNumber(3, 5) + Vector3.new(0, rng:NextNumber(2, 4), 0),
							Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 6, 1.2,
							frag.Size * 1.3, c.Y, "Kunai")
						burst(b.At + Vector3.new(0, 0.6, 0), b.Out + Vector3.new(0, 0.3, 0), { Chips = 2, Powder = 1 }, density(caster), 0.8)
					end
				end
			end
			for _, b in ipairs(blades) do kit.Drop(b.O) end
			folder:Destroy()
			return false
		end
		for _, b in ipairs(blades) do
			local u = (t - growAt - b.Delay) / 0.16
			if u > 0 then
				kit.Fade(b.O, 0)
				-- its +Y runs down into the floor: it rises out of the frost by its exposed length
				kit.Place(b.O, b.K * CFrame.new(0, (L - bury) * (1 - easeOut(math.min(u, 1))), 0), parts, cframes, fs)
			end
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- ICICLE SHARD: the leanest effect. The shot and its tracer are VFXLibrary's; VFXLibrary's shardImpact hands the hit
-- over here. Impact: two splinters of milky ice, chips, a little powder and flakes, a thin ripple on the surface and a
-- cold flash -- about three parts and the shared emitters.
----------------------------------------------------------------------------------------------------
function CryoFX.ShardImpact(hit, dir, thin, caster)
	-- Frost Lotus: a tiny bloom opens on the hit; Snow Globe: the globe cracks (slabs, a snow pile)
	local lfx = caster and ((FBX.DragonOn(caster) and FBX.Dragon()) or (FBX.LotusOn(caster) and FBX.Lotus()) or FBX.Globe(caster))
	if lfx then
		-- (2026-10-19, audit P5A-06) a failing skin hook now says so once instead of vanishing (warnOnce: no new local)
		local ok, err = pcall(lfx.HitBloom, hit, dir, thin, caster)
		if not ok then warnOnce("hitbloom", "skin hit bloom: " .. tostring(err)) end
	end
	local S = VFXLibrary.Tuning.IcicleShard
	local out = hit.Normal * 0.75 - dir * 0.25
	out = out.Magnitude > 1e-3 and out.Unit or -dir
	local p = hit.Position + hit.Normal * 0.08
	local cam = workspace.CurrentCamera
	local near = cam ~= nil and (p - cam.CFrame.Position).Magnitude < S.BurstNear
	local rng = Random.new()
	local k = near and 0.5 or 1
	local dens = math.clamp(Settings.EffectDensity or 1, 0.4, 1) * (thin and 0.5 or 1)
	local gy = p.Y - 6
	local probe = workspace:Raycast(p + Vector3.new(0, 0.5, 0), Vector3.new(0, -8, 0))
	if probe then gy = probe.Position.Y end
	for _ = 1, (thin or near) and 1 or 2 do
		local v = (out + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.3, 0.6), rng:NextNumber(-0.6, 0.6))).Unit
		local name = SPLINTERS[rng:NextInteger(1, #SPLINTERS)]
		throw(name, CFrame.lookAt(p, p + v), v * rng:NextNumber(8, 16) * k,
			Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 10,
			rng:NextNumber(0.45, 0.7), templateSize[name] * rng:NextNumber(0.8, 1.1) * k, gy, "Tip")
	end
	burst(p, out, { Chips = near and 2 or 4, Powder = near and 1 or 2, Flakes = (thin or near) and 0 or 4 }, dens, k)
	if thin or near then return end
	-- on the surface: a thin ripple (with the cold flash on it); on the world, a small splash of rime that melts away
	local n = hit.Normal
	local t = n:Cross(Vector3.yAxis)
	if t.Magnitude < 1e-3 then t = n:Cross(Vector3.xAxis) end
	local surface = CFrame.fromMatrix(hit.Position + n * 0.03, t.Unit, n)
	local ring = ripple(surface, 0.15, 1.2, 0.35, 0.4)
	if ring then lightFlash(ring, 3, 8, 0.2) end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") and hit.Instance:IsA("BasePart") then
		-- the reel's Chill patch: a round fractal frost mark where it struck, the Frost Line round it only while it
		-- spreads, riding the body part it landed on, melting away
		local part = hit.Instance
		local rel = part.CFrame:ToObjectSpace(surface)
		local patch, face = decalDisc(TEX.FrostDisc, FBX.C(Color3.fromRGB(226, 243, 252)), fxFolder())
		local rim = take("CK_Ring", "Line")
		if rim then rim.Parent = fxFolder() end
		local t0 = os.clock()
		run(function(now, dt, parts, cframes)
			local age = now - t0
			if age >= 1.8 or not part.Parent then
				patch:Destroy()
				give(rim)
				return false
			end
			local r = 0.5 * easeOut(age / 0.12)
			local sz = Vector3.new(math.max(0.05, 2.2 * r), 0.05, math.max(0.05, 2.2 * r))
			if patch.Size ~= sz then patch.Size = sz end
			face.Transparency = 0.08 + 0.92 * smooth((age - 1.1) / 0.7)
			local cf = part.CFrame * rel
			parts[#parts + 1] = patch
			cframes[#cframes + 1] = cf * CFrame.new(0, 0.02, 0)
			if rim then
				if age < 0.45 then
					lineLook(rim, 1 - smooth((age - 0.12) / 0.2), smooth((age - 0.25) / 0.2))
					placeRing(rim, cf * CFrame.new(0, 0.04, 0), r, r, 0.04, parts, cframes)
				elseif rim.Transparency ~= 1 then
					rim.Transparency = 1
				end
			end
			return true
		end)
	else
		local splash = take("CK_CM_Print", "Print")
		if splash then
			local full = Vector3.new(0.9, 0.05, 0.6) * rng:NextNumber(0.8, 1.2)
			splash.Size = full * 0.3
			splash.CFrame = surface * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			splash.Parent = fxFolder()
			local t0 = os.clock()
			run(function(now)
				local age = now - t0
				if age >= 1.4 or not splash.Parent then
					give(splash)
					return false
				end
				local kk = (age < 0.08) and (0.3 + 0.7 * age / 0.08) or 1
				splash.Size = full * Vector3.new(kk, 1, kk)
				splash.Transparency = L.PrintT + (1 - L.PrintT) * smooth((age - 0.6) / 0.8)
				return true
			end)
		end
	end
end

--- The shard leaving the palm (VFXLibrary.FireIcicleShard calls this on the release frame): a few chips and a puff of
--- cold vapor off the hand, along the shot.
function CryoFX.ShardCast(from, dir, thin)
	if thin then return end
	local cam = workspace.CurrentCamera
	local near = cam ~= nil and (from - cam.CFrame.Position).Magnitude < 3
	burst(from, dir, { Chips = near and 2 or 4, Breath = near and 1 or 4 }, math.clamp(Settings.EffectDensity or 1, 0.4, 1), near and 0.5 or 1)
end

----------------------------------------------------------------------------------------------------
-- COLD MOMENTUM: a thin ragged frost print under each footfall, its Frost Line rim bright for a moment only, and the
-- print fading in about a second. Under Reduce Enemy VFX, somebody else's prints are all that shows (no rim).
----------------------------------------------------------------------------------------------------
function CryoFX.ColdMomentumMark(character, foot, rng)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and foot) then return end
	local CM = VFXLibrary.Tuning.ColdMomentum
	local PR = L.Print
	local gp, gn, hit = VFXLibrary.GroundBelow(foot.Position, { character, fxFolder() }, 10)
	if not hit then return end
	local look = flat(rootPart.CFrame.LookVector)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local right = look.Unit:Cross(gn)
	if right.Magnitude < 1e-3 then return end
	-- toes turned out a little, the left foot one way and the right the other
	local toe = (foot.Name:find("Left") and 1 or -1) * 0.07
	local cf = CFrame.fromMatrix(gp + gn * 0.03, right.Unit, gn)
		* CFrame.Angles(0, toe + math.rad(rng:NextNumber(-CM.MarkYaw, CM.MarkYaw) * 0.5), 0)
		* CFrame.Angles(0, math.pi / 2, 0)                         -- the print's long axis is its X
	local p = take("CK_CM_Print", "Print")
	if not p then return end
	local full = Vector3.new(PR.Length, 0.04, PR.Width)
	p.Size = full * Vector3.new(0.6, 1, 0.6)
	p.CFrame = cf
	p.Parent = fxFolder()
	-- FROSTBLADE: two crossed blade nicks cut into the print (deep glassy ice), scaling and fading with it
	local fbk, kit = FBX.On(character)
	local nick = fbk and kit.New("Nick", fxFolder()) or nil
	-- FROST LOTUS: a small flat bloom on the print, petals drifting up; SNOW GLOBE: a snowflake print
	local lfx = (not fbk) and ((FBX.DragonOn(character) and FBX.Dragon()) or (FBX.LotusOn(character) and FBX.Lotus()) or FBX.Globe(character)) or nil
	-- (2026-10-19, audit P5A-12) the skin print hears whether it is thinned (its petals, chips or star pop go)
	if lfx then pcall(lfx.Print, cf, PR, thinFor(character)) end
	local rim
	if not (Settings.ThinEnemyVFX and FBX.Enemy(character)) then
		rim = take("CK_Ring", "Line")
		if rim then
			local rs = templateSize.CK_Ring
			rim.Size = Vector3.new(rs.X * PR.Length * 0.55, 0.03, rs.Z * PR.Width * 0.6)
			rim.CFrame = cf * CFrame.new(0, 0.01, 0)
			rim.Parent = fxFolder()
		end
	end
	local t0 = os.clock()
	run(function(now, dt, parts, cframes)
		local age = now - t0
		if age >= PR.Life or not p.Parent then
			give(p)
			if rim then give(rim) end
			if nick then kit.Drop(nick) end
			return false
		end
		local k = (age < PR.Pop) and (0.6 + 0.4 * easeOut(age / PR.Pop)) or 1
		p.Size = full * Vector3.new(k, 1, k)
		local fade = smooth((age - PR.Hold) / (PR.Life - PR.Hold))
		p.Transparency = L.PrintT + (1 - L.PrintT) * fade
		if nick then
			kit.Fade(nick, fade)
			kit.Place(nick, cf * CFrame.new(0, 0.012, 0), parts, cframes, k)
		end
		if rim then
			if age >= PR.Rim then
				give(rim)
				rim = nil
			else
				lineLook(rim, 1, smooth((age - PR.Rim * 0.5) / (PR.Rim * 0.5)))
			end
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- BLIZZARD
----------------------------------------------------------------------------------------------------
local storms = {}                -- [caster character] = storm

-- ...and the whiteout, for this client alone when its own body is inside somebody else's storm. The haze is the
-- map's own Atmosphere, thickened and turned to the storm's colour, then given back exactly as it was: the values
-- are put back only if nobody else changed them meanwhile (HubClient sets the Atmosphere when a map changes).
local haze = { Level = 0, Saved = nil, Written = nil, Made = nil, Gui = nil }

local function atmosphere()
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a then return a end
	if not haze.Made then
		haze.Made = Instance.new("Atmosphere")
		haze.Made.Density, haze.Made.Offset, haze.Made.Haze, haze.Made.Glare = 0, 0, 0, 0
		haze.Made.Parent = Lighting
	end
	return haze.Made
end

local ATM_KEYS = { "Density", "Offset", "Haze", "Glare", "Color", "Decay" }

local function atmSnapshot(a)
	local s = {}
	for _, k in ipairs(ATM_KEYS) do s[k] = a[k] end
	return s
end

local function sameAtm(a, s)
	if not s then return false end
	for _, k in ipairs(ATM_KEYS) do
		local v = a[k]
		if typeof(v) == "number" then
			if math.abs(v - s[k]) > 1e-3 then return false end
		elseif v ~= s[k] then
			return false
		end
	end
	return true
end

local function lerpNum(a, b, t) return a + (b - a) * t end

local function hazeGui()
	if haze.Gui and haze.Gui.Parent then return haze.Gui end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local g = Instance.new("ScreenGui")
	g.Name = "CryoWhiteout"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = -1000                     -- under every HUD: the storm blinds the world, not the health bar
	local f = Instance.new("Frame")
	f.Name = "Haze"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = B.HazeColor
	f.BackgroundTransparency = 1
	f.Parent = g
	g.Parent = pg
	haze.Gui = g
	return g
end

--- Is this client's body inside a storm that may hurt it? The same test the server slows by.
local function insideStorm()
	local me = player.Character
	local root = me and me:FindFirstChild("HumanoidRootPart")
	local hum = me and me:FindFirstChildOfClass("Humanoid")
	if not (root and hum) or hum.Health <= 0 then return false end
	local now = serverNow()
	for casterChar, s in pairs(storms) do
		if casterChar ~= me and now >= s.T0 and now < s.T0 + s.Duration and not s.Ended then
			local caster = Players:GetPlayerFromCharacter(casterChar)
			if not caster or Config.MayHurt(caster, player) then
				local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
				local d = flat(root.Position - s.Center).Magnitude
				if d <= s.Radius and feet >= s.Center.Y - B.Below and feet <= s.Center.Y + B.Height then
					return true
				end
			end
		end
	end
	return false
end

local function stepHaze(dt)
	local target = insideStorm() and 1 or 0
	if target == 0 and haze.Level == 0 then return end
	local rate = target > haze.Level and (1 / B.HazeIn) or (1 / B.HazeOut)
	haze.Level = math.clamp(haze.Level + math.sign(target - haze.Level) * rate * dt, 0, 1)
	if math.abs(haze.Level - target) < 0.02 then haze.Level = target end
	local a = atmosphere()
	if haze.Written and not sameAtm(a, haze.Written) then
		haze.Saved = atmSnapshot(a)                      -- somebody else set it (a map change): theirs is the base now
	end
	if not haze.Saved then haze.Saved = atmSnapshot(a) end
	local s, u = haze.Saved, smooth(haze.Level)
	a.Density = lerpNum(s.Density, B.HazeDensity, u)
	a.Offset = lerpNum(s.Offset, 0, u)
	a.Haze = lerpNum(s.Haze, 3, u)
	a.Glare = lerpNum(s.Glare, 0, u)
	a.Color = s.Color:Lerp(B.HazeColor, u)
	a.Decay = s.Decay:Lerp(B.HazeColor, u)
	haze.Written = atmSnapshot(a)
	local g = hazeGui()
	if g then g.Haze.BackgroundTransparency = lerpNum(1, B.ScreenHaze, u) end
	if haze.Level == 0 then
		-- out of the storm: the map's own values are back (the lerp's end), and ours are forgotten
		if haze.Made then
			haze.Made:Destroy()
			haze.Made = nil
		end
		haze.Saved, haze.Written = nil, nil
		if g then g.Haze.BackgroundTransparency = 1 end
	end
end

--- `d` = { Character, Center, T0, Yaw, Duration, Radius }
-- THE STORM (the reel: vfx_blocking/cryo/ice_v2/5_blizzard, blizzard.py), on the server's clock (Duration). From far
-- away it reads as a storm: a round wall of driven snow streaming round the zone (round particle columns, play-test
-- fix 3 -- no Beams or boxes, which read as flat walls and corners), a cloud vortex over it, the Frost Line ring on
-- the floor (8 arcs, bright while they draw, then half, stepping down to the calm rim one a second so the edge still
-- tells the storm's time), a frost sheet whitening the floor, drifts on the
-- windward side. Inside: driven flakes, powder swirls, gusts sweeping across, the whiteout and the frosted edge for
-- anyone caught in it. The cast: a cloud swirl forming over the caster. The end: the wind drops, the snow thins, the
-- wall and the vortex clear, the floor melts back.
local BZ_WALL_H = 16                 -- the reel's wall (HW), shorter than the zone's Height (the column the server counts)

function CryoFX.Blizzard(d)
	local caster = d.Character
	if not (caster and typeof(d.Center) == "Vector3") then return end
	local duration = d.Duration or B.Duration
	local R = d.Radius or B.Radius
	if serverNow() > d.T0 + duration then return end
	if storms[caster] then CryoFX.BlizzardEnd({ Character = caster, Instant = true }) end
	local thin = thinFor(caster)
	local density = math.clamp(Settings.EffectDensity or 1, 0.35, 1.15) * (thin and 0.5 or 1)
	local folder = Instance.new("Folder")
	folder.Name = "Blizzard"
	folder.Parent = fxFolder()
	local c = d.Center
	local yaw = d.Yaw or 0
	local BL = L.Blizzard
	local s = { Folder = folder, Center = c, T0 = d.T0, Duration = duration, Radius = R, Arcs = {}, Drifts = {}, Emitters = {} }
	storms[caster] = s
	local FORM, FULL = B.FormTime, B.FormTime + 1.4
	local THIN = duration - 1.8

	-- THE VORTEX: cloud spirals turning over the wall's top (two discs for its funnel), and the cast swirl
	local function vortexDisc(radius)
		local p = plainPart("CryoVortex", folder)
		p.Transparency = 1
		p.Size = Vector3.new(2 * radius, 0.05, 2 * radius)
		local faces = {}
		for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
			local dc = Instance.new("Decal")
			dc.Face, dc.Texture, dc.Transparency = face, TEX.Vortex, 1
			dc.Color3 = FBX.C(Color3.fromRGB(213, 231, 243))
			dc.Parent = p
			faces[#faces + 1] = dc
		end
		return { P = p, Faces = faces, R = radius }
	end
	local vortex = vortexDisc(R * 1.04)
	local eye = (not thin) and vortexDisc(R * 0.62) or nil
	local swirl = vortexDisc(1)

	-- THE FLOOR: the frost sheet spreading out to the ring and whitening over the storm, breaking up at the end
	local floor, floorFace = decalDisc(TEX.FrostDiscLight, FBX.C(Color3.fromRGB(170, 205, 230)), folder)
	floor.CFrame = CFrame.new(c + Vector3.new(0, 0.02, 0))

	-- THE EDGE: 8 Frost Line arcs, the first centred on where the caster faced
	local arcSize = templateSize.CK_BZ_Arc
	local arcT = template("CK_BZ_Arc")
	local ofp = arcT and arcT:GetAttribute("OriginFromPivot") or Vector3.new(0.8747, 0, -0.334)
	for k = 0, B.Arcs - 1 do
		local p = take("CK_BZ_Arc", "Line")
		if p then
			p.Transparency = 1
			p.Size = Vector3.new(arcSize.X * R, 0.12, arcSize.Z * R)
			local theta = yaw + math.pi / 2 - math.rad(20.8) - k * (2 * math.pi / B.Arcs)
			p.CFrame = CFrame.new(c + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, theta, 0)
				* CFrame.new(-ofp.X * R, 0, -ofp.Z * R)
			p.Parent = folder
			s.Arcs[k + 1] = p
		end
	end
	-- FROSTBLADE: the fence (kit/fb_bz.py) -- big kunai planted point-down just OUTSIDE the Frost Line ring (inside it the
	-- wall and the haze would swallow them; 2026-10-19, audit P5A-22: 0.3 studs out, was 1.4, so the solid fence marks
	-- the edge), leaning out, ring pommels up, rising out of the floor round the ring as it
	-- draws and melting as the storm thins; and every 8th fleck of the wall a kunai (the count unchanged), when the
	-- sprite is in the place (FrostbladeKit.Look.KunaiSprite)
	local fbk, fbKit = FBX.On(caster)
	-- FROST LOTUS: petals and glitter, not snow; SNOW GLOBE: the rim, the pines, white flecks, the settle-to-clear tell
	s.Lotus = (not fbk) and ((FBX.DragonOn(caster) and FBX.Dragon()) or (FBX.LotusOn(caster) and FBX.Lotus()) or FBX.Globe(caster)) or nil
	if fbk then
		s.Fence = {}
		local n = fbKit.RingBlades[fbKit.Tier(Settings.EffectDensity, thin)]
		local Lk, bury = fbKit.Kinds.Ring.L, 1.6
		for k = 0, n - 1 do
			local a = yaw - k * 2 * math.pi / n
			local dv = Vector3.new(math.sin(a), 0, math.cos(a))
			local tg = Vector3.new(math.cos(a), 0, -math.sin(a))
			local up = Vector3.yAxis * math.cos(0.12) + dv * math.sin(0.12)
			local o = fbKit.New("Ring", folder)
			if o then
				fbKit.Fade(o, 1)
				s.Fence[#s.Fence + 1] = { O = o, K = fbKit.Frame(c + dv * (R + 0.3) + up * (Lk - bury), -up, tg),
					At = FORM + BL.DrawTime * k / n, Up = Lk - bury }
			end
		end
		s.KunaiSprite = fbKit.Look.KunaiSprite
	end

	-- THE STORM'S BODY (play-test fix 3, 2026-10-08: it read as a box -- a 16-sided wall of flat Beams with bright seams
	-- at every join, a 12-sided ring of flat emitter boxes, and square snow and haze volumes whose corners stuck out of
	-- the ring). Everything that holds snow is round now: Cylinder-shaped emitters (ShapeStyle Volume) on round hosts.
	--   THE WALL   a ring of WallColumns columns at the radius, each a Cylinder volume WallColumnR wide, streaming hard
	--              angular flecks (the Shard sprite) round the ring on the wind; a sparser ring InnerRingAt inside, so the
	--              band thins inward, and the flecks drift a little outward as they stream, so it thins outward too --
	--              no hard edge either side. A few small soft puffs in the columns give the band body (support only).
	--   INSIDE     driven flakes and a little low haze, each in a Cylinder volume inside the ring. The "can barely see" is
	--              the screen-space whiteout on the victim's own client (stepHaze), not world geometry.
	-- Every rate scales with Graphics Quality and Reduce Enemy VFX (`density`), and the whole storm is capped at
	-- Blizzard.Snow.MaxParticles live particles: if the rates would hold more, they are all scaled down to fit.
	local SN = B.Snow
	local wind = CFrame.Angles(0, yaw + math.rad(90), 0).LookVector
	local SHARD = (VFXLibrary.Config.Textures and VFXLibrary.Config.Textures.Shard) or TEX.Snow
	local wallH = BZ_WALL_H
	local function roundHost(r, h, at)
		local p = host(CFrame.new(at), folder)
		p.Size = Vector3.new(2 * r, h, 2 * r)
		return p
	end
	local function emitter(parent, rate, life, props)
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Cylinder
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e.Texture = SHARD
		e.Color = ColorSequence.new(FBX.C(Color3.fromRGB(240, 248, 253)), FBX.C(Color3.fromRGB(205, 228, 244)))
		e.LightInfluence, e.LightEmission = 0.7, 0
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0),
			NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(life[1], life[2])
		e.Rotation = NumberRange.new(0, 360)
		e.Rate = 0
		for k, v in pairs(props) do e[k] = v end
		FBX.Lit(e)
		e.Parent = parent
		s.Emitters[#s.Emitters + 1] = { E = e, Rate = rate * density, Life = (life[1] + life[2]) / 2 }
		return e
	end
	local cols = {}
	local function ring(n, rr, rate, withPuffs)
		for i = 0, n - 1 do
			local a = (i + 0.5) * 2 * math.pi / n
			local dir = Vector3.new(math.sin(a), 0, math.cos(a))
			local tangent = Vector3.new(math.cos(a), 0, -math.sin(a))                -- round the ring, with the wall's turn
			local col = roundHost(SN.WallColumnR, wallH, c + dir * rr + Vector3.new(0, wallH / 2, 0))
			cols[#cols + 1] = { P = col, Dir = dir, R = rr }
			local fleck = {
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, SN.FleckSize[1]), NumberSequenceKeypoint.new(1, SN.FleckSize[2]) }),
				Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-220, 220),
				Acceleration = tangent * SN.Stream + dir * SN.Drift + Vector3.new(0, -0.4, 0),
				LightInfluence = 0.45, LightEmission = 0.12,
			}
			if s.Lotus then s.Lotus.StormFleck(fleck, tangent, wind) end
			if s.KunaiSprite then
				-- Frostblade: every 8th fleck a small kunai whirling with the rest (3x a fleck's size)
				emitter(col, rate * 7 / 8, SN.FleckLife, fleck)
				local kf = table.clone(fleck)
				kf.Texture = s.KunaiSprite
				kf.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, SN.FleckSize[1] * 3), NumberSequenceKeypoint.new(1, SN.FleckSize[2] * 3) })
				emitter(col, rate / 8, SN.FleckLife, kf)
			else
				emitter(col, rate, SN.FleckLife, fleck)
			end
			if withPuffs then
				-- driven snow: the same hard flecks stretched along their flight (they read from range, where a fleck alone
				-- is a pixel)
				emitter(col, SN.StreakRate, SN.StreakLife, {
					Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(SN.StreakSquash),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, SN.StreakSize[1]), NumberSequenceKeypoint.new(1, SN.StreakSize[2]) }),
					Speed = NumberRange.new(SN.Stream * 0.4, SN.Stream * 0.7), SpreadAngle = Vector2.new(25, 25),
					Acceleration = tangent * SN.Stream * 1.6 + dir * SN.Drift + Vector3.new(0, -0.3, 0),
					EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 0),
					LightInfluence = 0.45, LightEmission = 0.12,
				})
			end
			if withPuffs then
				emitter(col, SN.PuffRate, SN.PuffLife, {
					Texture = TEX.Powder, Color = ColorSequence.new(B.HazeColor), LightInfluence = 1,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, SN.PuffSize[1]), NumberSequenceKeypoint.new(1, SN.PuffSize[2]) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55),
						NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
					Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-20, 20),
					Acceleration = tangent * SN.Stream * 0.6,
				})
			end
		end
	end
	ring(thin and SN.ThinColumns or SN.WallColumns, R, SN.WallRate, not thin)
	if not thin then ring(SN.InnerColumns, R - SN.InnerRingAt, SN.WallRate * SN.InnerShare, false) end
	local inner = roundHost(R * SN.InsideR, 9, c + Vector3.new(0, 4.5, 0))
	local flakes = emitter(inner, SN.FlakeRate, SN.FlakeLife, {
		EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.18) }),
		Acceleration = wind * 9 + Vector3.new(0, -1, 0), Drag = 0.3, RotSpeed = NumberRange.new(-90, 90),
	})
	local hazeHost = roundHost(R * SN.HazeR, 8, c + Vector3.new(0, 4, 0))
	emitter(hazeHost, SN.HazeRate, SN.HazeLife, {
		Texture = TEX.Powder, Color = ColorSequence.new(B.HazeColor), LightInfluence = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, SN.HazeSize[1]), NumberSequenceKeypoint.new(1, SN.HazeSize[2]) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.65),
			NumberSequenceKeypoint.new(0.7, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(0.5, 1.5), Acceleration = wind * 2, RotSpeed = NumberRange.new(-10, 10),
	})
	do                                                             -- powder swirls low over the floor
		local e = mistEmitter(inner, 4, 9, 0.7)
		e.Shape = Enum.ParticleEmitterShape.Cylinder
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Acceleration = wind * 3
		s.Emitters[#s.Emitters + 1] = { E = e, Rate = SN.PowderRate * density, Life = 2.85 }
	end
	-- the cap: every rate scaled down together if the storm would hold more than MaxParticles at once
	do
		local live = 0
		for _, em in ipairs(s.Emitters) do live += em.Rate * em.Life end
		local k = (live > SN.MaxParticles) and (SN.MaxParticles / live) or 1
		for _, em in ipairs(s.Emitters) do em.Rate *= k end
		s.Budget = math.floor(math.min(live, SN.MaxParticles) + 0.5)
	end
	local anchor = host(CFrame.new(c), folder)                     -- the gusts' attachments

	-- GUSTS: three times a storm, pale streaks sweep across with the wind and the flakes are flung harder
	local gusts = { FULL + 0.6, FULL + 2.0, FULL + 3.2 }
	local gustBeams = {}
	if not thin then
		for i = 1, 6 do
			local a0 = Instance.new("Attachment")
			a0.Parent = anchor
			local a1 = Instance.new("Attachment")
			a1.Parent = anchor
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = TEX.Gust
			b.TextureMode = Enum.TextureMode.Stretch
			b.FaceCamera = true
			b.Width0, b.Width1 = 0.5, 0.2
			b.Color = ColorSequence.new(FBX.C(Color3.fromRGB(236, 246, 252)))
			b.LightEmission, b.LightInfluence = 0.3, 0.6
			b.Transparency = NumberSequence.new(1)
			FBX.Lit(b)
			b.Parent = anchor
			gustBeams[i] = { B = b, A0 = a0, A1 = a1 }
		end
	end

	-- DRIFTS of driven snow on the windward side, rising out of the floor
	local rng = Random.new(math.floor(d.T0 * 1000) % 2 ^ 30)
	local windward = -wind
	for _ = 1, (thin and 3 or 7) do
		local name = "CK_BZ_Drift_" .. rng:NextInteger(1, 3)
		local p = take(name, "Drift")
		if p then
			local a = math.atan2(windward.X, windward.Z) + rng:NextNumber(-0.9, 0.9)
			local r = R - rng:NextNumber(2.5, 7)
			local at = c + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
			local gy = groundY(at + Vector3.new(0, 2, 0))
			local size = templateSize[name] * rng:NextNumber(1.0, 1.6)
			p.Size = size * Vector3.new(1, 0.05, 1)
			p.CFrame = CFrame.new(at.X, gy, at.Z) * CFrame.Angles(0, a + rng:NextNumber(-0.4, 0.4), 0)
			p.Parent = folder
			s.Drifts[#s.Drifts + 1] = { P = p, Size = size, Ground = gy, CF = p.CFrame }
		end
	end

	-- FROST ON BODIES: anyone caught inside is snowed on for as long as they stay
	s.Frosted = {}                                                  -- [character] = the snow emitter on them
	s.FrostTick = 0
	local casterPlayer = Players:GetPlayerFromCharacter(caster)
	local function insideThis(character)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and hum) or hum.Health <= 0 or character == caster then return nil end
		local victim = Players:GetPlayerFromCharacter(character)
		if casterPlayer and victim and not Config.MayHurt(casterPlayer, victim) then return nil end
		local feet = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
		if flat(root.Position - c).Magnitude <= R and feet >= c.Y - B.Below and feet <= c.Y + B.Height then return root end
		return nil
	end
	local function frost(root)
		local att = Instance.new("Attachment")
		att.Name = "BlizzardFrost"
		att.Position = Vector3.new(0, 1.5, 0)
		local e = Instance.new("ParticleEmitter")
		e.Texture = TEX.Snow
		e.Color = ColorSequence.new(FBX.C(Color3.fromRGB(240, 248, 252)))
		e.LightInfluence, e.LightEmission = 1, 0
		e.Size = NumberSequence.new(0.18)
		e.Lifetime = NumberRange.new(0.5, 0.8)
		e.Speed = NumberRange.new(2, 4)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = wind * 10
		e.Rate = 25 * density
		FBX.Lit(e)
		e.Parent = att
		att.Parent = root
		return att
	end

	local h = host(CFrame.new(c + Vector3.new(0, 2, 0)), folder)
	playSound(h, "Slam")

	s.Step = function(now, dt, parts, cframes)
		local age = serverNow() - s.T0
		-- frost on whoever is inside, checked five times a second
		if now - s.FrostTick > 0.2 then
			s.FrostTick = now
			local live = not s.Ended and age < s.Duration
			local seen = {}
			if live then
				for _, plr in ipairs(Players:GetPlayers()) do
					local root = insideThis(plr.Character)
					if root then
						seen[plr.Character] = true
						local att = s.Frosted[plr.Character]
						if not (att and att.Parent) then s.Frosted[plr.Character] = frost(root) end
					end
				end
			end
			for character, att in pairs(s.Frosted) do
				if not seen[character] then
					att:Destroy()
					s.Frosted[character] = nil
				end
			end
		end
		local endAt = s.Ended and s.EndAge or s.Duration
		local thinAt = s.Ended and s.EndAge or THIN
		local endSpan = s.Ended and 1.2 or (s.Duration - THIN)
		local form = smooth((age - FORM) / (FULL - FORM))
		local str = form * (1 - smooth((age - thinAt) / endSpan))
		-- the wall rises (0.4 -> 1 of its height): the round columns grow with it
		local wh = BZ_WALL_H * (0.4 + 0.6 * form)
		if math.abs((s.WallH or -1) - wh) > 0.05 then
			s.WallH = wh
			for _, col in ipairs(cols) do
				col.P.Size = Vector3.new(col.P.Size.X, wh, col.P.Size.Z)
				col.P.CFrame = CFrame.new(c + col.Dir * col.R + Vector3.new(0, wh / 2, 0))
			end
		end
		-- the vortex over the wall's top, turning; the eye a little lower and faster; the cast swirl over the caster
		do
			local vt = 1 - 0.9 * str
			for _, dc in ipairs(vortex.Faces) do dc.Transparency = vt end
			parts[#parts + 1] = vortex.P
			cframes[#cframes + 1] = CFrame.new(c + Vector3.new(0, wh + 0.3, 0)) * CFrame.Angles(0, -0.35 * age, 0)
			if eye then
				for _, dc in ipairs(eye.Faces) do dc.Transparency = 1 - 0.6 * str end
				parts[#parts + 1] = eye.P
				cframes[#cframes + 1] = CFrame.new(c + Vector3.new(0, wh - 2.2, 0)) * CFrame.Angles(0, -0.6 * age + 1.3, 0)
			end
			local sw = smooth((age - 0.15) / 0.7) * (1 - smooth((age - FULL) / 0.8))
			local rr = 4 + 10 * sw
			swirl.P.Size = Vector3.new(2 * rr, 0.05, 2 * rr)
			for _, dc in ipairs(swirl.Faces) do dc.Transparency = 1 - 0.8 * sw end
			parts[#parts + 1] = swirl.P
			cframes[#cframes + 1] = CFrame.new(c + Vector3.new(0, 9, 0)) * CFrame.Angles(0, -1.2 * age, 0)
		end
		-- the floor: the frost sheet spreading to the ring over 3.5 s and whitening; breaking up and clearing at the end
		do
			local fr = (R + 1.5) * easeOut((age - FORM) / 3.5)
			local white = 0.6 * smooth((age - FULL) / math.max(0.5, THIN - 0.6 - FULL))
			local brk = smooth((age - thinAt) / endSpan)
			floor.Size = Vector3.new(math.max(0.1, 2.2 * fr), 0.05, math.max(0.1, 2.2 * fr))
			floorFace.Color3 = FBX.C(Color3.fromRGB(170, 205, 230)):Lerp(FBX.C(Color3.fromRGB(246, 251, 254)), white / 0.6)
			floorFace.Transparency = (fr <= 0.05) and 1 or math.min(1, 0.5 - 0.3 * white / 0.6 + 0.5 * brk + (1 - form) * 0.3)
		end
		-- snow up with the storm, thinning at the end; a gust flings the flakes harder
		local g = 0
		for _, gt in ipairs(gusts) do g += math.exp(-((age - gt) / 0.35) ^ 2) end
		for _, em in ipairs(s.Emitters) do
			local r = em.Rate * str
			if math.abs(em.E.Rate - r) > 0.5 then em.E.Rate = r end
		end
		flakes.Acceleration = wind * (9 * (1 + 1.8 * g)) * (1 - 0.8 * smooth((age - thinAt) / endSpan)) + Vector3.new(0, -1, 0)
		-- the gust streaks: six pale lines sweeping across with the wind, a second each
		for i, gb in ipairs(gustBeams) do
			local on = false
			for _, gt in ipairs(gusts) do
				local u2 = (age - gt + 0.5) / 1.0
				if u2 >= 0 and u2 < 1 and str > 0.1 then
					local side = wind:Cross(Vector3.yAxis)
					local x0 = -R + 2 * R * u2 + i * 1.5
					local p0 = wind * x0 + side * (-14 + i * 5.5) + Vector3.new(0, 1.2 + 1.3 * (i % 3), 0)
					gb.A0.Position = p0
					gb.A1.Position = p0 - wind * 9 + Vector3.new(0, math.sin(i) * 0.6, 0)
					gb.B.Transparency = NumberSequence.new(1 - 0.55 * math.sin(math.pi * u2))
					on = true
				end
			end
			if not on then gb.B.Transparency = NumberSequence.new(1) end
		end
		-- the ring: arc k draws in at its share of DrawTime from the form, lit; the whole ring then settles to half
		-- brightness; arc k steps down to the calm rim on its second; at the end the rail fades
		local fadeEnd = smooth((age - endAt) / 1.2)
		for k, p in ipairs(s.Arcs) do
			local drawAt = FORM + BL.DrawTime * (k - 1) / #s.Arcs
			local goes = s.Duration * k / #s.Arcs
			if s.Ended then goes = math.min(goes, s.EndAge) end
			if age < drawAt then
				if p.Transparency ~= 1 then p.Transparency = 1 end
			else
				local glow
				if age < goes then
					glow = 1 - (1 - BL.Half) * smooth((age - FORM - BL.DrawTime) / 0.5)
				else
					glow = BL.Half * (1 - smooth((age - goes) / 0.25))
				end
				lineLook(p, glow, fadeEnd)
			end
		end
		-- Frostblade's fence: up in the ring's drawing order, melting (clearing and sinking a little) as the storm thins
		if s.Fence then
			local melt = smooth((age - thinAt) / endSpan)
			for _, b in ipairs(s.Fence) do
				local u = (age - b.At) / 0.3
				if u > 0 and melt < 1 then
					fbKit.Fade(b.O, melt)
					fbKit.Place(b.O, b.K * CFrame.new(0, b.Up * ((1 - easeOut(math.min(u, 1))) + 0.35 * melt), 0), parts, cframes)
				else
					fbKit.Fade(b.O, 1)
				end
			end
		end
		-- drifts rise over the form, and sink at the end
		local rise = smooth((age - FORM) / 2.5)
		local sink = smooth((age - thinAt - 0.6) / 1.0)
		local k = math.max(0.02, rise * (1 - sink))
		for _, dr in ipairs(s.Drifts) do
			dr.P.Size = dr.Size * Vector3.new(1, k, 1)
			parts[#parts + 1] = dr.P
			cframes[#cframes + 1] = dr.CF * CFrame.new(0, dr.Size.Y * k * 0.5 - 0.05, 0)
		end
		if age > endAt + 1.6 then
			for _, p in ipairs(s.Arcs) do give(p) end
			for _, dr in ipairs(s.Drifts) do give(dr.P) end
			for _, att in pairs(s.Frosted) do att:Destroy() end
			folder:Destroy()
			if storms[caster] == s then storms[caster] = nil end
			return false
		end
		return true
	end
	run(s.Step)
	if s.Lotus then pcall(s.Lotus.Storm, s, c, R, FORM, caster, wind) end      -- Frost Lotus: petal streaks on the wind
end

--- The storm ends early (the caster died, left the arena, a round reset): everything goes dark and settles now.
function CryoFX.BlizzardEnd(d)
	local s = d.Character and storms[d.Character]
	if not s or s.Ended then return end
	s.Ended = true
	s.EndAge = serverNow() - s.T0
end

----------------------------------------------------------------------------------------------------
-- THE FROSTED EDGE: this client's own screen while its body is held in ice (a Deep Freeze prison, a Mirror Cage).
-- Four frost-coloured bands creep in from the edges and thaw back out when the hold ends. Under every HUD, like the
-- whiteout, so the health bar stays readable.
----------------------------------------------------------------------------------------------------
local frostEdge = { Gui = nil, Until = 0, Level = 0 }

local function frostEdgeGui()
	if frostEdge.Gui and frostEdge.Gui.Parent then return frostEdge.Gui end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local g = Instance.new("ScreenGui")
	g.Name = "CryoFrostEdge"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = -999
	local specs = {
		{ Pos = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.22), Rot = 90 },
		{ Pos = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(1, 0.22), Rot = -90 },
		{ Pos = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.16, 1), Rot = 0 },
		{ Pos = UDim2.fromScale(0.84, 0), Size = UDim2.fromScale(0.16, 1), Rot = 180 },
	}
	for i, sp in ipairs(specs) do
		local f = Instance.new("Frame")
		f.Name = "Edge" .. i
		f.Position, f.Size = sp.Pos, sp.Size
		f.BorderSizePixel = 0
		f.BackgroundColor3 = COL.Frost
		f.BackgroundTransparency = 1
		local grad = Instance.new("UIGradient")
		grad.Rotation = sp.Rot
		grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.55, 0.7),
			NumberSequenceKeypoint.new(1, 1) })
		grad.Color = ColorSequence.new(Color3.fromRGB(240, 248, 252), L.MidIce)
		grad.Parent = f
		f.Parent = g
	end
	g.Parent = pg
	frostEdge.Gui = g
	return g
end

--- Hold this client's screen frosted until server time `untilT`.
local function frostScreen(untilT)
	frostEdge.Until = math.max(frostEdge.Until, untilT)
end

local function stepFrostEdge(dt)
	local target = (serverNow() < frostEdge.Until or haze.Level > 0.4) and 1 or 0
	if target == 0 and frostEdge.Level == 0 then return end
	local rate = target > frostEdge.Level and 5 or 1.6            -- snaps on, thaws off
	frostEdge.Level = math.clamp(frostEdge.Level + math.sign(target - frostEdge.Level) * rate * dt, 0, 1)
	local g = frostEdgeGui()
	if not g then return end
	for _, f in ipairs(g:GetChildren()) do
		if f:IsA("Frame") then f.BackgroundTransparency = 1 - frostEdge.Level * 0.85 end
	end
end

----------------------------------------------------------------------------------------------------
-- DEEP FREEZE
----------------------------------------------------------------------------------------------------
local markers = {}               -- [trap Id] = marker (this client's own traps only)

--- The caster's own trap (the server sends this to them alone): the tap's small frost disc with its Frost Line and a
--- bloom of crystals that melts away by about 1.2 s, then only a faint calm ring at the reach, for the caster to find it.
function CryoFX.DeepFreezeArmed(d)
	if typeof(d.Position) ~= "Vector3" then return end
	local T0 = d.T0 or serverNow()
	local TP = L.Tap
	local pos = d.Position
	local folder = Instance.new("Folder")
	folder.Name = "DeepFreezeTrap"
	folder.Parent = fxFolder()
	local mk = { Id = d.Id, Folder = folder }
	markers[d.Id] = mk
	local thin = (Settings.EffectDensity or 1) < 0.75
	local rng = Random.new(tonumber(d.Id) or 1)
	local fl, bloom, melting = nil, nil, false
	local bloomK = nil
	if serverNow() - T0 < TP.MeltAt then
		fl = floorNew(pos, rng, { R = TP.Disc, Spread = 0.3, RingFade = 0.5, Crust = 0.6, Fingers = thin and 2 or 5,
			Melt = TP.MeltBy - TP.MeltAt, Parent = folder })
		local fbk, kit = FBX.On(player.Character)
		if fbk then
			-- FROSTBLADE: three tiny kunai sprout point-down round the trap and melt on the same beat
			bloomK = {}
			for k = 0, 2 do
				local a = 2 * math.pi * k / 3 + 0.5
				local dv = Vector3.new(math.cos(a), 0, math.sin(a))
				local g = pos + dv * 0.45
				local up = Vector3.yAxis * math.cos(0.3) + dv * math.sin(0.3)
				local o = kit.New("Tiny", folder)
				if o then
					kit.Fade(o, 1)
					bloomK[#bloomK + 1] = { O = o, K = kit.Frame(g + up * 0.75, -up, Vector3.new(-dv.Z, 0, dv.X)), Delay = 0.04 * k }
				end
			end
		elseif FBX.LotusOn(player.Character) and FBX.Lotus() then
			pcall(FBX.Lotus().Tap, pos, folder, TP, T0)               -- FROST LOTUS: three tiny blooms sprout and melt
		else
			bloom = {}
			cluster(bloom, rng, pos, TP.BloomSize, { Spikes = thin and 3 or TP.Bloom, Bases = 1, Mound = not thin, Delay = 0,
				Stagger = 0.03, Dur = 0.16, Flare = not thin }, folder)
		end
		burst(pos + Vector3.new(0, 0.2, 0), Vector3.yAxis, { Glints = 4, Breath = 3 }, math.clamp(Settings.EffectDensity or 1, 0.4, 1))
	end
	local ring = take("CK_Ring", "Calm")
	if ring then
		ring.Transparency = 1
		ring.Size = Vector3.new(templateSize.CK_Ring.X * D.Reach, 0.02, templateSize.CK_Ring.Z * D.Reach)
		ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.03, 0))
		ring.Parent = folder
	end
	run(function(now, dt, parts, cframes)
		local age = serverNow() - T0
		if markers[d.Id] ~= mk then
			floorDrop(fl)
			if bloom then dropSet(bloom) end
			if bloomK then for _, b in ipairs(bloomK) do FBX.Kit().Drop(b.O) end end
			give(ring)
			folder:Destroy()
			return false
		end
		if bloomK then
			local kit = FBX.Kit()
			local melt = smooth((age - TP.MeltAt) / (TP.MeltBy - TP.MeltAt))
			for _, b in ipairs(bloomK) do
				local u = (age - b.Delay) / 0.14
				if u > 0 and melt < 1 then
					kit.Fade(b.O, melt)
					kit.Place(b.O, b.K * CFrame.new(0, 0.75 * (1 - easeOut(math.min(u, 1))) + 0.3 * melt, 0), parts, cframes)
				end
			end
			if age > TP.MeltBy + 0.05 then
				for _, b in ipairs(bloomK) do kit.Drop(b.O) end
				bloomK = nil
			end
		end
		if fl then
			if age >= TP.MeltAt and not fl.MeltAt then fl.MeltAt = TP.MeltAt end
			if not floorStep(fl, age, parts, cframes) then
				floorDrop(fl)
				fl = nil
			end
		end
		if bloom then
			if age < TP.MeltAt then
				growStep(bloom, age, parts, cframes, thin)
			else
				if not melting then
					melting = true
					holdSet(bloom)
				end
				sinkSet(bloom, smooth((age - TP.MeltAt) / (TP.MeltBy - TP.MeltAt)), parts, cframes)
				if age > TP.MeltBy + 0.05 then
					dropSet(bloom)
					bloom = nil
				end
			end
		end
		-- the caster's faint marker comes up as the trap arms, after the bloom
		if ring then
			local u = smooth((age - TP.MeltAt) / math.max(0.05, d.ArmTime or D.ArmTime))
			local t = 1 - (1 - L.MarkerT) * u
			if math.abs(ring.Transparency - t) > 1e-3 then ring.Transparency = t end
		end
		return true
	end)
end

function CryoFX.DeepFreezeGone(d)
	if d.Id ~= nil then markers[d.Id] = nil end
end

--- `d` = { Character, Victim, Position (the trap), At (the victim's feet), T0, Duration, Seed }
function CryoFX.DeepFreeze(d)
	local victim = d.Victim
	if not (victim and typeof(d.Position) == "Vector3" and typeof(d.At) == "Vector3") then return end
	local duration = d.Duration or D.Root
	if serverNow() > d.T0 + duration + 0.5 then return end
	if encases[victim] then encases[victim].Break = true end
	local rng = Random.new(d.Seed or 1)
	local isMe = victim == player.Character
	local thin = thinFor(d.Character)
	local folder = Instance.new("Folder")
	folder.Name = "DeepFreeze"
	folder.Parent = fxFolder()
	local at = d.At
	local enc = encaseNew(victim, at, rng, L.Encase.DeepFreeze, {
		Parent = folder, IsMe = isMe, Thin = thin, Caster = d.Character, LineTop = D.LineTop, ClimbAt = 0,
		ClimbTime = D.ClimbTime, Seal = D.SealTime, GrowAt = 0.05, CrackAt = duration - D.CrackTime, CrackTime = D.CrackTime - 0.1,
		FB = (FBX.DragonOn(d.Character) and FBX.Dragon() and "DragonDF") or (FBX.LotusOn(d.Character) and "LotusDF")
			or (FBX.On(d.Character) and "Trap") or nil,
	})
	encases[victim] = enc

	-- the floor: a darker frosted disc and its one clean Frost Line ring, spreading, the ring fading when it stops
	local fl = floorNew(at, rng, { R = D.RingRadius, Spread = D.RingTime, RingFade = D.RingFade, Crust = 0.7,
		Fingers = thin and 3 or 7, Melt = 1.2, Parent = folder })
	-- the trigger's hit: a ripple and a pop of powder at the feet
	if serverNow() - d.T0 < 0.3 then
		local dens = density(d.Character)
		ripple(CFrame.new(at + Vector3.new(0, 0.06, 0)), 0.4, 3.4, 0.6)
		burst(at + Vector3.new(0, 0.3, 0), Vector3.yAxis, { Powder = 12, Flakes = 10 }, dens)
	end
	-- cold mist pooled at the prison's foot while it holds
	local mistHost = host(CFrame.new(at + Vector3.new(0, 0.7, 0)), folder)
	mistHost.Size = Vector3.new(7, 1, 7)
	local mist = mistEmitter(mistHost, 2.5, 5, 0.65)
	mist.Rate = thin and 4 or 8

	local h = host(CFrame.new(at + Vector3.new(0, 2, 0)), folder)
	playSound(h, "Seal")
	if isMe and _G.SpellshotReactions and _G.SpellshotReactions.Pulse then
		pcall(_G.SpellshotReactions.Pulse, "Krak")
	end
	if isMe then frostScreen(d.T0 + duration) end

	local popped = serverNow() - d.T0 > 0.6
	run(function(now, dt, parts, cframes)
		local age = serverNow() - d.T0
		if not popped and age >= 0.45 then                  -- the reel: FROZEN! as the prison locks
			popped = true
			if not isDead(victim) then popFrozen(victim) end
		end
		if (enc.Break or isDead(victim) or age >= duration) and not enc.BrokeAt then
			encaseBreak(enc, age, true)
			fl.MeltAt = age + 0.15
			mist.Rate = 0
			playSound(h, "Break")
		end
		floorStep(fl, age, parts, cframes)
		if not encaseStep(enc, age, parts, cframes) then
			floorDrop(fl)
			folder:Destroy()
			if encases[victim] == enc then encases[victim] = nil end
			return false
		end
		return true
	end)
end

function CryoFX.DeepFreezeEnd(d)
	local enc = d.Victim and encases[d.Victim]
	if enc then enc.Break = true end
end

----------------------------------------------------------------------------------------------------
-- MIRROR CAGE (the reel: vfx_blocking/cryo/ice_v2/4_mirror_cage, blender_scripts/cryo/ice2/mirror_cage.py), on the
-- game's clock: the trapped are rooted for CryoTuning.MirrorCageRoot() and the server's damage bolts land on
-- MirrorCageBolts(); the beats below are fitted round them.
--   LOCK-ON    a Frost Line circle draws round the target, a frost disc spreads under it, a ripple runs out
--   ERUPT      a ring of crystal clusters erupts round the target
--   FORMATION  a hemisphere of thick faceted ice-mirror panels condenses out of cold air on the dome (MirrorCage.Radius,
--              centred Look.Cage.DomeY over the floor, the gap between two panels facing the caster), each facing in
--   AIM        the panels tick onto the target in four steps
--   FIRING     round each ring one after another, every panel pulses the Frost Line round its outline, flares at its
--              centre and sends a thin ice bolt with a cyan trail into the target nearest it; the target ices over
--   THE KILL   every outline flashes, cracks run through the glass, a cold flash, FROZEN!
--   SHATTER    the panels lunge in, shrink and burst into shards and powder, the clusters break, the disc melts
-- A panel is a clear flat part with the panel art (c2_panel_*) on both faces, its outline (a SurfaceGui each, for the
-- pulse) and its cracks (a Decal each), and a rim of thin Ice blocks along the art's polygon for the plate's thickness.
-- On low graphics, or somebody else's cage under Reduce Enemy VFX: no top ring, no rims, half the shots.
----------------------------------------------------------------------------------------------------
local cages = {}                 -- [caster character] = cage
local CG = L.Cage

--- A Frost Line Trail on a bolt (made once per pooled part, cleared and switched off when it goes back).
local function boltTrail(p)
	local tr = p:FindFirstChild("CryoTrail")
	if tr then return tr end
	local a0 = Instance.new("Attachment")
	a0.Name = "CryoTrail0"
	a0.Position = Vector3.new(0, 0.05, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Name = "CryoTrail1"
	a1.Position = Vector3.new(0, -0.05, 0)
	a1.Parent = p
	tr = Instance.new("Trail")
	tr.Name = "CryoTrail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(COL.Line)
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	tr.Lifetime = 0.08
	tr.FaceCamera = true
	tr.Enabled = false
	tr.Parent = p
	return tr
end

--- One mirror panel: art variant `var` (1-4), circumradius `R` studs. Its own frame: -Z (the Front face) toward the
--- target, the art's x running along the part's -X (a Decal on the Front face reads its texture mirrored in X).
local function newPanel(var, R, parent, thin)
	local P = plainPart("CagePanel", parent)
	P.Transparency = 1
	P.Size = Vector3.new(2 * R, 2 * R, CG.Thick)
	local pn = { P = P, R = R, Var = var, Faces = {}, Outlines = {}, Guis = {}, Cracks = {}, Rims = {}, Scale = 1 }
	local sides = {
		{ Enum.NormalId.Front, TEX.Panel[var], TEX.Outline[var], TEX.Cracks[var] },
		{ Enum.NormalId.Back, TEX.PanelBack[var], TEX.OutlineBack[var], TEX.CracksBack[var] },
	}
	for _, side in ipairs(sides) do
		local d = Instance.new("Decal")
		d.Face, d.Texture, d.Color3, d.Transparency = side[1], side[2], CG.PanelColor, 1
		d.Parent = P
		pn.Faces[#pn.Faces + 1] = d
		local ck = Instance.new("Decal")
		ck.Face, ck.Texture, ck.Transparency, ck.ZIndex = side[1], side[4], 1, 2
		ck.Parent = P
		pn.Cracks[#pn.Cracks + 1] = ck
		local g = Instance.new("SurfaceGui")
		g.Face = side[1]
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Brightness = 2
		g.Enabled = false
		local im = Instance.new("ImageLabel")
		im.Size = UDim2.fromScale(1, 1)
		im.BackgroundTransparency = 1
		im.Image = side[3]
		im.ImageColor3 = COL.Line
		im.ImageTransparency = 1
		im.Parent = g
		g.Parent = P
		pn.Guis[#pn.Guis + 1] = g
		pn.Outlines[#pn.Outlines + 1] = im
	end
	pn.Plate = FBX.Wrap and FBX.Wrap.Plate and FBX.Wrap.Plate(var, R, parent, CG.Thick)   -- (a solid wrap: Black Ice)
	if not thin then
		local poly = L.PanelPoly[var]
		local n = #poly
		for i = 1, n do
			local a, b = poly[i], poly[i % n + 1]
			local pa = Vector3.new(-a[1] * R, a[2] * R, 0)
			local pb = Vector3.new(-b[1] * R, b[2] * R, 0)
			local e = pb - pa
			local len = e.Magnitude
			e = e.Unit
			local nrm = Vector3.new(e.Y, -e.X, 0)
			local mid = (pa + pb) / 2
			if nrm:Dot(mid) > 0 then nrm = -nrm end                -- in toward the middle of the plate
			local depth = 0.16
			local rim = plainPart("CageRim", parent)
			rim.Material = ICE
			rim.Color = CG.RimColor
			rim.Reflectance = 0.2
			rim.Transparency = 1
			rim.Size = Vector3.new(len + 0.06, depth, CG.Thick)
			pn.Rims[#pn.Rims + 1] = { P = rim, Off = CFrame.fromMatrix(mid + nrm * (depth / 2), e, nrm), Len = len + 0.06, Depth = depth }
		end
	end
	return pn
end

--- Show a panel at frame `cf`, scaled `scale`, its art at opacity `a` (0..1).
local function panelLook(pn, a)
	local t = 1 - 0.95 * a
	if math.abs((pn.LookA or -1) - a) < 1e-3 then return end
	pn.LookA = a
	for _, d in ipairs(pn.Faces) do d.Transparency = pn.Plate and 1 or t end
	if pn.Plate then pn.Plate.P.Transparency = 1 - 0.84 * a end      -- (the art's own opacity: hit-honest)
	local rt = 1 - (1 - CG.RimT) * a
	for _, r in ipairs(pn.Rims) do r.P.Transparency = rt end
end

local function panelPlace(pn, cf, scale, parts, cframes)
	if scale ~= pn.Scale then
		pn.Scale = scale
		pn.P.Size = Vector3.new(2 * pn.R * scale, 2 * pn.R * scale, CG.Thick * scale)
		for _, r in ipairs(pn.Rims) do r.P.Size = Vector3.new(r.Len * scale, r.Depth * scale, CG.Thick * scale) end
		local pl = pn.Plate
		if pl then pl.P.Size = Vector3.new(pl.W * pn.R * scale, pl.H * pn.R * scale, pl.T * scale) end
	end
	parts[#parts + 1] = pn.P
	cframes[#cframes + 1] = cf
	if pn.Plate then
		parts[#parts + 1] = pn.Plate.P
		cframes[#cframes + 1] = cf * CFrame.new(pn.Plate.O * (pn.R * scale))
	end
	for _, r in ipairs(pn.Rims) do
		parts[#parts + 1] = r.P
		local off = r.Off
		cframes[#cframes + 1] = cf * (scale == 1 and off or (CFrame.new(off.Position * scale) * off.Rotation))
	end
	pn.Now = cf
end

--- The outline pulse: `v` 0..1 (1 = the line at full strength).
local function panelPulse(pn, v)
	v = math.clamp(v, 0, 1)
	if math.abs((pn.PulseV or -1) - v) < 0.01 then return end
	pn.PulseV = v
	local on = v > 0.01
	for _, g in ipairs(pn.Guis) do if g.Enabled ~= on then g.Enabled = on end end
	for _, im in ipairs(pn.Outlines) do im.ImageTransparency = 1 - v end
end

local function panelCracks(pn, v)
	local t = 1 - 0.9 * math.clamp(v, 0, 1)
	if math.abs((pn.CrackV or -1) - t) < 0.01 then return end
	pn.CrackV = t
	for _, d in ipairs(pn.Cracks) do d.Transparency = t end
end

local function panelDrop(pn)
	pn.Dropped = true
	if pn.Live then pcall(function() pn.Live.Gui:Destroy() end) end
	pn.Live = nil
	pcall(function() pn.P:Destroy() end)
	if pn.Plate then pcall(function() pn.Plate.P:Destroy() end) end
	for _, r in ipairs(pn.Rims) do pcall(function() r.P:Destroy() end) end
	table.clear(pn.Rims)
end

--- THE REFLECTIONS (play-test fix 4). The panels nearest the camera show the caster's real avatar (LIVE REFLECTIONS,
--- below); every other kept panel shows a flat pose card of the body in the caster's own body colours (the Element
--- colours only when there is no body on this client), untinted. The card art is five mask layers (tools/cryo2_mirror_cards.py: torso, sleeve, hand, base = head and
--- legs, and the ink outline), each an atlas of the five poses (Look.Card.Poses), tinted here. A card stands upright in the
--- world whatever the panel's roll, with a small tilt of its own; each panel takes a different idle pose.
local CARD = L.Card
local CARD_LAYERS = { "Torso", "Sleeve", "Hand", "Base", "Ink" }    -- drawn in this order: the ink on top
local NEUTRAL_BODY = Color3.fromRGB(58, 64, 78)                      -- UniformAvatar's head and legs

local function casterTones(casterChar)
	local plr = casterChar and Players:GetPlayerFromCharacter(casterChar)
	local el = plr and plr:GetAttribute("Element")
	local def = (el and Config.Elements[el]) or Config.Elements.Cryo
	return { Base = NEUTRAL_BODY, Torso = def.Base, Sleeve = def.Dark, Hand = def.Light, Ink = CARD.InkColor }
end

local function reflectionPose(pn, pose)
	if not pn.Cards or pn.Pose == pose then return end
	pn.Pose = pose
	local off = Vector2.new((pose - 1) * CARD.Cell.X, 0)
	for _, card in ipairs(pn.Cards) do
		for _, im in ipairs(card.Layers) do im.ImageRectOffset = off end
	end
end

local function addReflection(pn, pose, tilt, tones)
	pn.Cards = {}
	-- on the inner face only, the one facing the trapped (the owner, 2026-10-08: "show the reflection on the front ones
	-- facing the enemy"); the outer face stays plain glass
	for i, face in ipairs({ Enum.NormalId.Front }) do
		local g = Instance.new("SurfaceGui")
		g.Name = "Reflection"
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = CARD.PixelsPerStud
		g.LightInfluence = CARD.LightInfluence
		g.ZOffset = 1
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5 + CARD.Drop)
		holder.Size = UDim2.fromScale(CARD.Height * CARD.Cell.X / CARD.Cell.Y, CARD.Height)
		holder.Rotation = tilt
		holder.Parent = g
		local layers = {}
		for z, key in ipairs(CARD_LAYERS) do
			local im = Instance.new("ImageLabel")
			im.Name = key
			im.BackgroundTransparency = 1
			im.Size = UDim2.fromScale(1, 1)
			im.Image = CARD.Tex[key]
			im.ImageRectSize = CARD.Cell
			im.ImageColor3 = tones[key]
			im.ImageTransparency = 1
			im.ZIndex = z
			im.Parent = holder
			layers[#layers + 1] = im
		end
		g.Parent = pn.P
		pn.Cards[i] = { Gui = g, Holder = holder, Layers = layers, Sign = CARD.RollSign[i] }
	end
	pn.Tilt = tilt
	pn.Pose = nil
	reflectionPose(pn, pose)
end

--- Keep a panel's reflection standing upright in the world, however the panel is aimed and rolled: world up, seen on
--- the panel's face, is at angle atan2(-x, y) from the face's up (x, y in the panel's own frame); a SurfaceGui on the
--- Back face reads x mirrored, hence the per-face sign.
local function reflectionUpright(pn, cf)
	local up = cf:VectorToObjectSpace(Vector3.yAxis)
	if math.abs(up.X) + math.abs(up.Y) < 1e-3 then return end
	pn.Roll = math.deg(math.atan2(up.X, up.Y))
	if pn.Live and not pn.Live.Aimed then pn.Live.VP.Rotation = CARD.RollSign[1] * pn.Roll + (pn.Tilt or 0) end
	for _, card in ipairs(pn.Cards or {}) do card.Holder.Rotation = card.Sign * pn.Roll + (pn.Tilt or 0) end
end

local function reflectionLook(pn, a)
	if pn.Live then
		local t = 1 - (1 - CARD.Live.T) * a
		if math.abs((pn.LiveT or -1) - t) > 1e-3 then
			pn.LiveT = t
			pn.Live.VP.ImageTransparency = t
		end
	end
	if not pn.Cards then return end
	local t = 1 - (1 - CARD.T) * a
	if math.abs((pn.CardT or -1) - t) < 1e-3 then return end
	pn.CardT = t
	for _, card in ipairs(pn.Cards) do
		for _, im in ipairs(card.Layers) do im.ImageTransparency = t end
	end
end

----------------------------------------------------------------------------------------------------
-- LIVE REFLECTIONS (the owner's hard rule, 2026-10-08): a reflection is the caster's REAL avatar exactly as it looks
-- right now -- skin, face, hair, clothing, every accessory, any cosmetic -- with no recolour and no tint, and no
-- per-item code: whatever the character wears comes along. The glass, the glare and the edge sell the mirror.
--   ONE CLONE PER CAST, on each client, from the character this client sees, stripped (scripts, sounds, emitters,
--   lights, name tag and billboards, force field, every Highlight and our frozen state -- a frosted caster does not
--   mirror frost -- the Animator, every joint and constraint) and anchored, inert, shadowless, CanQuery off. Our frozen
--   tint is undone on it. Its rest pose comes from its own joints (any rig: R15, R6, anything welded to it), so the
--   five poses -- the same definitions the cards were drawn from (tools/cryo2_mirror_cards.py POSES) -- bend its
--   limbs about their joints and carry whatever hangs off them.
--   SHOWN in a ViewportFrame (with a WorldModel, so layered clothing deforms) on the face of a panel toward this
--   client's camera, on the Live.Max panels nearest the camera (fewer at lower Graphics Quality); every other kept
--   panel shows the flat card, recoloured to the caster's own body colours. A ViewportFrame lives in a SurfaceGui
--   adorned to its panel from PlayerGui (one per live panel: one ViewportFrame cannot draw on two surfaces). The
--   template is copied once per live panel. Everything is destroyed with the cage.
--   FALLBACK: no character on this client (left, not streamed in), no root, or any error -> the cards.
----------------------------------------------------------------------------------------------------
local LIVE, GLARE = CARD.Live, CARD.Glare

-- the five poses, ported from the card script (Blender: x = the character's left, -y its forward, z up) to the
-- character's own Roblox frame (x = its right, -z its forward, y up): (x, y, z) -> (-x, z, y)
local function b2r(x, y, z) return Vector3.new(-x, z, y) end
--- a limb hanging, swung `fwd` degrees forward (negative = back; 180 = straight up) and `out` degrees from the midline;
--- side +1 = the character's left, -1 its right
local function limbDir(fwd, out, side)
	local f, o = math.rad(fwd), math.rad(out)
	return Vector3.new(-side * math.sin(o), -math.cos(f) * math.cos(o), -math.sin(f) * math.cos(o))
end
local DOWN = Vector3.new(0, -1, 0)
local POSE = {}
POSE[1] = { Yaw = 20, Rot = {}, Twist = {}, Dir = {                                             -- front
	RightUpperArm = limbDir(0, 8, -1), LeftUpperArm = limbDir(0, 8, 1),
	RightUpperLeg = limbDir(0, 8, -1), LeftUpperLeg = limbDir(0, 8, 1), RightFoot = DOWN, LeftFoot = DOWN } }
POSE[3] = { Yaw = 50, Rot = { LowerTorso = { 5, 0, 0 } }, Twist = { RightUpperArm = 8 }, Dir = { -- three-quarter right
	RightUpperArm = limbDir(40, 2, -1), RightLowerArm = limbDir(96, -14, -1),
	LeftUpperArm = limbDir(36, 5, 1), LeftLowerArm = limbDir(100, 3, 1),
	RightUpperLeg = limbDir(-30, 7, -1), LeftUpperLeg = limbDir(14, 8, 1), RightFoot = DOWN, LeftFoot = DOWN } }
do                                                                                              -- three-quarter left
	local src, m = POSE[3], { Yaw = -50, Rot = {}, Twist = {}, Dir = {} }
	local function sw(n) return (n:gsub("Right", "\0"):gsub("Left", "Right"):gsub("%z", "Left")) end
	for n, v in pairs(src.Dir) do m.Dir[sw(n)] = Vector3.new(-v.X, v.Y, v.Z) end
	for n, r in pairs(src.Rot) do m.Rot[sw(n)] = { r[1], -r[2], -r[3] } end
	for n, t in pairs(src.Twist) do m.Twist[sw(n)] = -t end
	POSE[2] = m
end
POSE[4] = { Yaw = 160, Rot = { LowerTorso = { 0, -5, 0 } }, Twist = {}, Dir = {                 -- back
	RightUpperArm = limbDir(180, 9, -1), LeftUpperArm = limbDir(0, 8, 1), LeftLowerArm = limbDir(88, 4, 1),
	LeftUpperLeg = limbDir(0, -3, 1), LeftLowerLeg = limbDir(0, -3, 1),
	RightUpperLeg = limbDir(10, 8, -1), RightLowerLeg = limbDir(-8, 11, -1), RightFoot = DOWN, LeftFoot = DOWN } }
POSE[5] = { Yaw = 0, Rot = { LowerTorso = { 8, -3, 18 }, Head = { -6, 0, -3 } }, Twist = { RightUpperArm = 22 }, Dir = { -- cast
	RightUpperArm = b2r(-0.50, -1.0, 0.30), RightHand = b2r(-0.45, -1.0, 0.76),
	LeftUpperArm = b2r(-0.10, 0.85, -0.55), LeftLowerArm = b2r(-0.70, 0.50, -0.50),
	RightUpperLeg = b2r(-0.30, -0.15, -1.0), RightLowerLeg = b2r(-0.24, 0.0, -1.0),
	LeftUpperLeg = b2r(0.30, 0.18, -1.0), LeftLowerLeg = b2r(0.26, 0.32, -1.0), RightFoot = DOWN, LeftFoot = DOWN } }
-- the reflection's stance before it aims: facing out of the glass at the trapped, arms down
local IDLE = { Yaw = 0, Rot = {}, Twist = {}, Dir = {
	RightUpperArm = limbDir(0, 8, -1), LeftUpperArm = limbDir(0, 8, 1),
	RightUpperLeg = limbDir(0, 6, -1), LeftUpperLeg = limbDir(0, 6, 1), RightFoot = DOWN, LeftFoot = DOWN } }
-- an R6 body's parts answer to the R15 segment that carries them
local R6_KEY = { Torso = "LowerTorso", ["Right Arm"] = "RightUpperArm", ["Left Arm"] = "LeftUpperArm",
	["Right Leg"] = "RightUpperLeg", ["Left Leg"] = "LeftUpperLeg" }

--- Blender Euler XYZ (degrees) as a rotation in the character's Roblox frame
local function eulerB(r)
	return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(r[3])) * CFrame.fromAxisAngle(Vector3.zAxis, math.rad(r[2]))
		* CFrame.fromAxisAngle(-Vector3.xAxis, math.rad(r[1]))
end

local function fromTo(a, b)
	local c = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if c.Magnitude < 1e-5 then return (dot > 0) and CFrame.identity or CFrame.fromAxisAngle(Vector3.xAxis, math.pi) end
	return CFrame.fromAxisAngle(c.Unit, math.acos(dot))
end

local STRIP_CLASSES = { "LuaSourceContainer", "Sound", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Trail", "Beam",
	"Light", "BillboardGui", "ForceField", "Highlight", "Animator", "AnimationController", "ProximityPrompt",
	"ClickDetector", "BodyMover", "Explosion" }

local function pathKeys(root)
	local keys, seen = {}, {}
	for _, inst in ipairs(root:GetDescendants()) do
		local names, x = {}, inst
		while x and x ~= root do
			table.insert(names, 1, x.Name .. ":" .. x.ClassName)
			x = x.Parent
		end
		local k = table.concat(names, "/")
		seen[k] = (seen[k] or 0) + 1
		keys[inst] = k .. "#" .. seen[k]
	end
	return keys
end

--- The rig of a (cloned) body: every part's rest frame relative to the root, its parent and joint pivot, from its own
--- joints -- a Motor6D or Weld places its other part through C0 / C1, an AnimationConstraint (the newer avatar joints)
--- through its two attachments (the live Transform, the animation, is left out of both), a WeldConstraint keeps the
--- offset it has now; a part reached by no joint keeps its place on the body.
local function rigOf(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return nil end
	local parts, isPart = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then parts[#parts + 1] = d; isPart[d] = true end
	end
	local edges = {}
	local function add(e)
		edges[e.P0] = edges[e.P0] or {}; table.insert(edges[e.P0], e)
		edges[e.P1] = edges[e.P1] or {}; table.insert(edges[e.P1], e)
	end
	for _, j in ipairs(model:GetDescendants()) do
		if j:IsA("JointInstance") and j.Part0 and j.Part1 and isPart[j.Part0] and isPart[j.Part1] then
			add({ P0 = j.Part0, P1 = j.Part1, C0 = j.C0, C1 = j.C1, Motor = j:IsA("Motor6D") })
		elseif j:IsA("AnimationConstraint") and j.Attachment0 and j.Attachment1 then
			local a0, a1 = j.Attachment0, j.Attachment1
			if isPart[a0.Parent] and isPart[a1.Parent] then
				add({ P0 = a0.Parent, P1 = a1.Parent, C0 = a0.CFrame, C1 = a1.CFrame, Motor = true })
			end
		elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 and isPart[j.Part0] and isPart[j.Part1] then
			add({ P0 = j.Part0, P1 = j.Part1, Rel = j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame) })
		end
	end
	local rig = { Root = root, Parts = parts, Rest = { [root] = CFrame.identity }, Parent = {}, Pivot = {}, Motor = {}, Order = { root } }
	local qi = 1
	while qi <= #rig.Order do
		local a = rig.Order[qi]
		qi += 1
		for _, e in ipairs(edges[a] or {}) do
			local b = (e.P0 == a) and e.P1 or e.P0
			if not rig.Rest[b] then
				local ra = rig.Rest[a]
				if e.C0 then
					if e.P0 == a then
						rig.Rest[b] = ra * e.C0 * e.C1:Inverse()
						rig.Pivot[b] = (ra * e.C0).Position
					else
						rig.Rest[b] = ra * e.C1 * e.C0:Inverse()
						rig.Pivot[b] = (ra * e.C1).Position
					end
				else
					rig.Rest[b] = (e.P0 == a) and (ra * e.Rel) or (ra * e.Rel:Inverse())
					rig.Pivot[b] = rig.Rest[b].Position
				end
				rig.Parent[b], rig.Motor[b] = a, e.Motor == true
				rig.Order[#rig.Order + 1] = b
			end
		end
	end
	for _, p in ipairs(parts) do
		if not rig.Rest[p] then
			rig.Rest[p] = root.CFrame:ToObjectSpace(p.CFrame)
			rig.Parent[p], rig.Pivot[p] = root, rig.Rest[p].Position
			rig.Order[#rig.Order + 1] = p
		end
	end
	return rig
end

--- The viewport camera that frames the box lo..hi (the figure faces -Z, the camera looks at it along +Z), for a frame
--- of `aspect` width / height; Cx..Dist say where it is, for mapping a point of the figure onto the glass.
local function frameView(lo, hi, aspect)
	local c, size = (lo + hi) / 2, hi - lo
	local tf = math.tan(math.rad(LIVE.FOV / 2))
	local dist = LIVE.Fit * math.max(size.Y / 2 / tf, size.X / 2 / (tf * aspect)) + size.Z / 2
	return { Cam = CFrame.lookAt(Vector3.new(c.X, c.Y, c.Z - dist), c), Cx = c.X, Cy = c.Y, Cz = c.Z, Dist = dist }
end

--- One pose of a rig: every part's frame (in rig.Parts order), feet on y = 0 and centred (or moved by `shiftIn`, to
--- share another pose's frame), its box and the viewport view that frames it.
local function poseRig(rig, pose, aspect, shiftIn)
	local R, G = { [rig.Root] = CFrame.identity }, { [rig.Root] = CFrame.identity }
	for _, p in ipairs(rig.Order) do
		if p ~= rig.Root then
			local par = rig.Parent[p]
			local Rp = R[par]
			local Rl = CFrame.identity
			if rig.Motor[p] then
				local key = R6_KEY[p.Name] or p.Name
				local dir = pose.Dir[key]
				-- the limb's own axis at rest (down, unless the body's bind pose bends it), turned onto `dir`
				local axis = rig.Rest[p]:VectorToWorldSpace(DOWN)
				if dir then
					Rl = fromTo(axis, Rp:VectorToObjectSpace(dir.Unit))
				elseif pose.Rot[key] then
					Rl = eulerB(pose.Rot[key])
				end
				if pose.Twist[key] then Rl = Rl * CFrame.fromAxisAngle(axis, math.rad(pose.Twist[key])) end
			end
			local Rc = Rp * Rl
			local q = rig.Pivot[p]
			R[p] = Rc
			G[p] = CFrame.new(G[par] * q) * Rc * CFrame.new(-q)
		end
	end
	local yaw = CFrame.Angles(0, math.rad(pose.Yaw), 0)
	local cfs = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for i, p in ipairs(rig.Parts) do
		local cf = yaw * G[p] * rig.Rest[p]
		cfs[i] = cf
		if p ~= rig.Root and p.Transparency < 0.99 then
			local s = p.Size / 2
			for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }) do
				local w = cf * (s * c)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	if lo.X == math.huge then return nil end
	local shift = shiftIn or CFrame.new(-(lo.X + hi.X) / 2, -lo.Y, -(lo.Z + hi.Z) / 2)
	for i, cf in ipairs(cfs) do cfs[i] = shift * cf end
	lo, hi = shift * lo, shift * hi
	return { CF = cfs, Lo = lo, Hi = hi, Shift = shift, View = frameView(lo, hi, aspect) }
end

--- The caster's mirror template for this cast: the stripped clone and its five poses; nil when there is no body here.
local function buildTemplate(character)
	if not (typeof(character) == "Instance" and character.Parent) then return nil end
	if not (character:FindFirstChild("HumanoidRootPart") and character:FindFirstChildOfClass("Humanoid")) then return nil end
	local was = character.Archivable
	pcall(function() character.Archivable = true end)
	local ok, clone = pcall(function() return character:Clone() end)
	pcall(function() character.Archivable = was end)
	if not (ok and clone) then return nil end
	-- our frozen tint is undone on the copy (the caster's own colours, not the ice)
	local e = tints[character]
	if e then
		local ok2, err = pcall(function()
			local src, dst, inv = pathKeys(character), pathKeys(clone), {}
			for inst, k in pairs(dst) do inv[k] = inst end
			for _, it in ipairs(e.Items) do
				local twin = src[it.I] and inv[src[it.I]]
				if twin then twin[it.K] = it.Orig end
			end
		end)
		if not ok2 then warnOnce("mirrortint", "mirror tint undo: " .. tostring(err)) end
	end
	local rig = rigOf(clone)
	if not rig then
		clone:Destroy()
		return nil
	end
	for _, inst in ipairs(clone:GetDescendants()) do
		local kill = inst:IsA("JointInstance") or inst:IsA("Constraint") or (inst:IsA("Folder") and inst.Name == "IceFrozenState")
		if not kill then
			for _, cls in ipairs(STRIP_CLASSES) do
				if inst:IsA(cls) then kill = true break end
			end
		end
		if kill then pcall(function() inst:Destroy() end) end
	end
	for k in pairs(clone:GetAttributes()) do clone:SetAttribute(k, nil) end
	for _, p in ipairs(rig.Parts) do
		if p.Parent then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
			p.LocalTransparencyModifier = 0
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			hum.NameDisplayDistance, hum.HealthDisplayDistance = 0, 0
			hum.EvaluateStateMachine = false
		end)
	end
	clone.Name = "MirrorReflection"
	-- the parts in the order a copy of the template lists them, and their poses
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then parts[#parts + 1] = d end
	end
	rig.Parts = parts
	local aspect = LIVE.Width / LIVE.Height
	local idle = poseRig(rig, IDLE, aspect)
	if not idle then
		clone:Destroy()
		return nil
	end
	-- the shooting hand: its tip (the end its limb points along)
	local handIdx, handOff
	for i, p in ipairs(parts) do
		if p.Name == "RightHand" or (p.Name == "Right Arm" and not handIdx) then
			handIdx, handOff = i, Vector3.new(0, -p.Size.Y / 2, 0)
		end
	end
	return { Model = clone, Count = #parts, Rig = rig, Aspect = aspect, Idle = idle, HandIdx = handIdx, HandOff = handOff }
end

local function mirrorHolder()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local h = pg:FindFirstChild("CryoMirrors")
	if not h then
		h = Instance.new("Folder")
		h.Name = "CryoMirrors"
		h.Parent = pg
	end
	return h
end

--- A live reflection on panel `pn`: a copy of the template in a ViewportFrame on the face toward this camera.
local function addLive(pn, tmpl, tilt)
	local holder = mirrorHolder()
	if not holder then return false end
	local g = Instance.new("SurfaceGui")
	g.Name = "LiveReflection"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = LIVE.PixelsPerStud
	g.LightInfluence = 0
	g.ZOffset = 1
	g.ResetOnSpawn = false
	g.Adornee = pn.P
	local vp = Instance.new("ViewportFrame")
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.5 + LIVE.Drop)
	vp.Size = UDim2.fromScale(LIVE.Width, LIVE.Height)
	vp.BackgroundTransparency = 1
	vp.ImageTransparency = 1
	vp.Ambient, vp.LightColor, vp.LightDirection = LIVE.Ambient, LIVE.LightColor, LIVE.LightDir
	vp.Parent = g
	local wm = Instance.new("WorldModel")
	wm.Parent = vp
	local fig = tmpl.Model:Clone()
	local parts = {}
	for _, d in ipairs(fig:GetDescendants()) do
		if d:IsA("BasePart") then parts[#parts + 1] = d end
	end
	if #parts ~= tmpl.Count then
		fig:Destroy()
		g:Destroy()
		return false
	end
	fig.Parent = wm
	local cam = Instance.new("Camera")
	cam.FieldOfView = LIVE.FOV
	cam.Parent = vp
	vp.CurrentCamera = cam
	g.Parent = holder
	pn.Live = { Gui = g, VP = vp, WM = wm, Parts = parts, Cam = cam, Tmpl = tmpl }
	pn.Tilt = tilt
	pcall(function() wm:BulkMoveTo(parts, tmpl.Idle.CF, Enum.BulkMoveMode.FireCFrameChanged) end)
	cam.CFrame = tmpl.Idle.View.Cam
	return true
end

--- The reflection turns on the trapped: its right arm straight at `target` (world), the camera framing both stances
--- (so it does not jump). The figure's axes are the panel's own, turned by the ViewportFrame's Rotation.
local AIM_KEYS = { "RightUpperArm", "RightLowerArm", "RightHand" }
local function liveAim(pn, target)
	local lv = pn.Live
	if not (lv and pn.Now) or lv.Aimed then return end
	local tmpl = lv.Tmpl
	local R = math.rad(lv.VP.Rotation)
	local rel = pn.Now:VectorToObjectSpace(target - pn.Now.Position)
	local d = Vector3.new(rel.X * math.cos(R) + rel.Y * math.sin(R), -rel.X * math.sin(R) + rel.Y * math.cos(R), rel.Z)
	d = (d.Magnitude > 1e-3) and d.Unit or Vector3.new(0, 0, -1)
	-- a shooter's stance: turned AimYaw, the right shoulder leading, so the arm reads; the arm itself still on `d`
	local pose = { Yaw = LIVE.AimYaw, Rot = { LowerTorso = { 4, 0, 0 } }, Twist = {}, Dir = {
		LeftUpperArm = limbDir(-25, 14, 1), LeftLowerArm = limbDir(40, 10, 1), RightUpperLeg = limbDir(-12, 6, -1),
		LeftUpperLeg = limbDir(14, 6, 1), RightFoot = DOWN, LeftFoot = DOWN } }
	local body = CFrame.Angles(0, -math.rad(LIVE.AimYaw), 0):VectorToWorldSpace(d)
	for _, k in ipairs(AIM_KEYS) do pose.Dir[k] = body end
	local aim = poseRig(tmpl.Rig, pose, tmpl.Aspect, tmpl.Idle.Shift)
	if not aim then return end
	local view = frameView(tmpl.Idle.Lo:Min(aim.Lo), tmpl.Idle.Hi:Max(aim.Hi), tmpl.Aspect)
	pcall(function() lv.WM:BulkMoveTo(lv.Parts, aim.CF, Enum.BulkMoveMode.FireCFrameChanged) end)
	lv.Cam.CFrame = view.Cam
	lv.View = view
	lv.HandFig = tmpl.HandIdx and (aim.CF[tmpl.HandIdx] * tmpl.HandOff) or nil
	lv.Aimed = true
end

--- Where the aimed reflection's hand shows on the glass (world), for its bolts to leave from.
local function handOnGlass(pn)
	local lv = pn.Live
	if not (lv and lv.Aimed and lv.HandFig and pn.Now) then return nil end
	local h, V = lv.HandFig, lv.View
	local k = V.Dist / math.max(0.2, h.Z - V.Cz + V.Dist)
	local sc = pn.P.Size.Y * LIVE.Height / (2 * V.Dist * math.tan(math.rad(LIVE.FOV / 2)))
	local a, b = (h.X - V.Cx) * k * sc, (h.Y - V.Cy) * k * sc
	local R = math.rad(lv.VP.Rotation)
	local x, y = a * math.cos(R) - b * math.sin(R), a * math.sin(R) + b * math.cos(R)
	return pn.Now * Vector3.new(x, y - LIVE.Drop * pn.P.Size.Y, -pn.P.Size.Z / 2 - 0.15)
end

--- The caster's body colours for the flat cards on the far panels (shirt on the torso and sleeves, skin on the hands,
--- the legs on the head-and-legs layer); our frozen tint is looked through. nil when there is no body here.
local function avatarTones(character)
	if not (typeof(character) == "Instance" and character.Parent) then return nil end
	local orig = {}
	local e = tints[character]
	if e then
		for _, it in ipairs(e.Items) do if it.K == "Color" then orig[it.I] = it.Orig end end
	end
	local function col(...)
		for _, n in ipairs({ ... }) do
			local p = character:FindFirstChild(n)
			if p and p:IsA("BasePart") then return orig[p] or p.Color end
		end
		return nil
	end
	local torso = col("UpperTorso", "Torso")
	if not torso then return nil end
	return {
		Torso = torso, Sleeve = col("RightUpperArm", "Right Arm") or torso, Hand = col("RightHand", "Right Arm") or torso,
		Base = col("LeftUpperLeg", "Left Leg") or torso, Ink = CARD.InkColor,
	}
end

--- The glare: hard white diagonal streaks over the panel's face toward this camera, at the same world angle on every
--- panel (Look.Card.Glare; tools/cryo2_glare.py, its streaks inside 0.35 of the image, so at Size they stay inside the
--- smallest panel outline at any roll).
local function addGlare(pn)
	local g = Instance.new("SurfaceGui")
	g.Name = "Glare"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = GLARE.PixelsPerStud
	g.LightInfluence = 0
	g.ZOffset = 2
	local im = Instance.new("ImageLabel")
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = UDim2.fromScale(0.5, 0.5)
	im.Size = UDim2.fromScale(GLARE.Size, GLARE.Size)
	im.BackgroundTransparency = 1
	im.Image = CARD.GlareTex
	im.ImageColor3 = Color3.new(1, 1, 1)
	im.ImageTransparency = 1
	im.Parent = g
	g.Parent = pn.P
	pn.Glare = { Gui = g, Im = im }
end

--- Which face of a panel this client's camera sees (Front faces the target), and the gui rotations that go with it:
--- every reflection stands upright and every glare lies at the same angle AS THIS VIEWER SEES THEM (the camera's up
--- projected onto the panel; on the steep top ring, world-up laid the figures on their sides).
local function panelView(pn, eye, camUp)
	if not pn.Now then return end
	local front = (eye - pn.Now.Position):Dot(pn.Now.LookVector) >= 0
	local face = front and Enum.NormalId.Front or Enum.NormalId.Back
	local sign = front and CARD.RollSign[1] or CARD.RollSign[2]
	if pn.Face ~= face then
		pn.Face = face
		if pn.Glare then pn.Glare.Gui.Face = face end
		pn.ViewRoll = nil
	end
	local up = pn.Now:VectorToObjectSpace(camUp)
	local roll = (math.abs(up.X) + math.abs(up.Y) > 1e-3) and math.deg(math.atan2(up.X, up.Y)) or (pn.Roll or 0)
	if not pn.ViewRoll or math.abs(pn.ViewRoll - roll) > 1 then
		pn.ViewRoll = roll
		if pn.Glare then pn.Glare.Im.Rotation = sign * roll end
	end
end

--- The glare at panel opacity `a` (0..1), flashing `flash` (0..1) as a bolt leaves.
local function glareStep(pn, a, flash)
	if not pn.Glare then return end
	local base = 1 - (1 - GLARE.T) * a
	local t = base - (base - GLARE.FlashT) * flash * a
	if math.abs((pn.GlareT or -1) - t) > 0.005 then
		pn.GlareT = t
		pn.Glare.Im.ImageTransparency = t
	end
end


--- `d` = { Character (the caster), Center, Yaw (toward the caster), T0, Victims = { { Model, At }, ... } }
----------------------------------------------------------------------------------------------------
-- FROSTBLADE'S CAGE (kit/fb_mc.py; the developer's direction, 2026-10-14): the panels give way to SMALL ICE CLONES OF
-- THE CASTER (FrostbladeKit.CloneScale), one per panel in its place -- the lowest ring standing on the floor at its
-- panel's bearing, the higher rings leaping where their panels hang -- each condensing on its panel's beat, facing the
-- trapped, readying a kunai on the aim and THROWING one on each of its panel's fire times (the bolts are kunai with the
-- Frost Line on their leading edges; flight, spacing and count are the Default's). They shatter at the impact. The copy
-- is the mirror template (buildTemplate: the caster stripped and anchored) turned to clear ice; the poses bend it about
-- its own joints like the reflections'. Graphics Quality: a clone per panel / the lowest ring only / 6 of it, a clone
-- then throwing its neighbours' kunai too (the bolt count never changes).
----------------------------------------------------------------------------------------------------
FBX.PH = {
	Stand = {},
	Ready = { Dir = { RightUpperArm = limbDir(150, 25, -1), RightLowerArm = limbDir(175, 10, -1),
		LeftUpperArm = limbDir(80, 10, 1), LeftLowerArm = limbDir(85, 5, 1) } },
	Wind = { Dir = { RightUpperArm = limbDir(195, 25, -1), RightLowerArm = limbDir(215, 10, -1),
		LeftUpperArm = limbDir(85, 12, 1), LeftLowerArm = limbDir(88, 6, 1) }, Rot = { LowerTorso = { -6, 0, -10 } } },
	Release = { Dir = { RightUpperArm = limbDir(95, 8, -1), RightLowerArm = limbDir(92, 4, -1),
		LeftUpperArm = limbDir(-20, 20, 1), LeftLowerArm = limbDir(-10, 15, 1) }, Rot = { LowerTorso = { 12, 0, 8 } } },
	Follow = { Dir = { RightUpperArm = limbDir(50, 0, -1), RightLowerArm = limbDir(40, 0, -1),
		LeftUpperArm = limbDir(-25, 20, 1), LeftLowerArm = limbDir(-15, 15, 1) }, Rot = { LowerTorso = { 16, 0, 10 } } },
}
-- the high rings leap: knees up
FBX.AIR = { Dir = { RightUpperLeg = limbDir(70, 8, -1), RightLowerLeg = limbDir(-15, 5, -1),
	LeftUpperLeg = limbDir(45, 8, 1), LeftLowerLeg = limbDir(-25, 5, 1) } }

function FBX.Pose(base, over)
	local p = { Yaw = 0, Rot = table.clone(base.Rot or {}), Twist = table.clone(base.Twist or {}), Dir = table.clone(base.Dir or {}) }
	for k, v in pairs(over.Dir or {}) do p.Dir[k] = v end
	for k, v in pairs(over.Rot or {}) do p.Rot[k] = v end
	return p
end

FBX.STRIP = { "Decal", "Texture", "SurfaceAppearance", "Clothing", "ShirtGraphic", "BodyColors" }
--- The template turned to clear ice (face, clothing and textures off), hidden until it condenses, at clone scale.
function FBX.IceModel(model, kit, S)
	for _, inst in ipairs(model:GetDescendants()) do
		local kill = false
		for _, cls in ipairs(FBX.STRIP) do
			if inst:IsA(cls) then kill = true break end
		end
		if kill then
			pcall(function() inst:Destroy() end)
		elseif inst:IsA("BasePart") then
			inst.Material, inst.Color, inst.Reflectance = Enum.Material.Ice, kit.Look.Clone, kit.Look.Reflect
			if FBX.Wrap then FBX.Wrap.Solidify(inst) end          -- (a solid wrap: glossy black statues)
			inst.Transparency = 1
			if inst:IsA("MeshPart") then pcall(function() inst.TextureID = "" end) end
		elseif inst:IsA("SpecialMesh") then
			pcall(function() inst.TextureId = "" end)
		end
	end
	if not pcall(function() model:ScaleTo(S) end) then
		for _, inst in ipairs(model:GetDescendants()) do
			if inst:IsA("BasePart") then
				inst.Size *= S
			elseif inst:IsA("SpecialMesh") and inst.MeshType == Enum.MeshType.FileMesh then
				inst.Scale *= S
			end
		end
	end
end

function FBX.CageSetup(cage, caster, aimAt, center, gy, thin)
	local kit = FBX.Kit()
	local tmpl = buildTemplate(caster)
	if not tmpl then return end
	cage.Template = tmpl                                         -- destroyed with the cage
	local S = kit.CloneScale
	local stand = poseRig(tmpl.Rig, IDLE, 1)
	if not stand then return end
	-- every phase on the floor and in the air, once, all on the standing pose's footing
	local poses = { G = {}, A = {} }
	for name, over in pairs(FBX.PH) do
		local pg = FBX.Pose(IDLE, over)
		local g = poseRig(tmpl.Rig, pg, 1, stand.Shift)
		local a = poseRig(tmpl.Rig, FBX.Pose(pg, FBX.AIR), 1, stand.Shift)
		poses.G[name] = g and g.CF or stand.CF
		poses.A[name] = a and a.CF or stand.CF
	end
	local vis = {}
	for i, part in ipairs(tmpl.Rig.Parts) do vis[i] = part.Transparency < 0.99 end
	local ice = tmpl.Model:Clone()
	FBX.IceModel(ice, kit, S)
	cage.HandIdx, cage.HandOff = tmpl.HandIdx, tmpl.HandOff
	-- who gets a clone
	local tier = kit.Tier(Settings.EffectDensity, thin)
	local low, own = {}, {}
	for _, pn in ipairs(cage.Panels) do
		if pn.Ring == 1 then low[#low + 1] = pn end
	end
	if tier == 1 then
		for _, pn in ipairs(cage.Panels) do own[pn] = true end
	elseif tier == 2 then
		for _, pn in ipairs(low) do own[pn] = true end
	else
		local stepN = math.max(1, #low / 6)
		for j = 0, 5 do
			local pn = low[math.floor(j * stepN) + 1]
			if pn then own[pn] = true end
		end
	end
	cage.Clones = {}
	local holders = {}
	for _, pn in ipairs(cage.Panels) do
		if own[pn] then
			local air = pn.Ring > 1
			-- the lowest ring on the floor at the panel's bearing; the rest leaping, the chest where the panel hung
			local feet = air and (pn.Pos - Vector3.new(0, 3.2 * S, 0)) or Vector3.new(pn.Pos.X, gy, pn.Pos.Z)
			local face = Vector3.new(aimAt.X, feet.Y, aimAt.Z)
			local W = ((face - feet).Magnitude > 1e-3) and CFrame.lookAt(feet, face) or CFrame.new(feet)
			local m = ice:Clone()
			local parts = {}
			for _, dd in ipairs(m:GetDescendants()) do
				if dd:IsA("BasePart") then parts[#parts + 1] = dd end
			end
			m.Name = "FrostbladeClone"
			m.Parent = cage.Folder
			local cl = { Model = m, Parts = parts, Vis = vis, W = W, S = S, Poses = air and poses.A or poses.G, Form = pn.Form,
				Fires = {}, Held = kit.New("Bolt", cage.Folder) }
			if cl.Held then kit.Fade(cl.Held, 1) end
			pn.Clone = cl
			cage.Clones[#cage.Clones + 1] = cl
			holders[#holders + 1] = pn
		end
	end
	ice:Destroy()
	-- a panel without a clone throws from the nearest one by bearing
	for _, pn in ipairs(cage.Panels) do
		if not pn.Clone then
			local best, bd
			local mine = flat(pn.Pos - center)
			for _, h in ipairs(holders) do
				local theirs = flat(h.Pos - center)
				local dd = (mine.Magnitude > 1e-3 and theirs.Magnitude > 1e-3) and (theirs.Unit - mine.Unit).Magnitude or 0
				if not bd or dd < bd then best, bd = h, dd end
			end
			pn.Clone = best and best.Clone or nil
		end
		if pn.Clone then
			for _, f in ipairs(pn.Fires) do table.insert(pn.Clone.Fires, f) end
		end
	end
	-- each clone's beats: it stands, readies on the aim, then winds up, throws and follows through on every fire time
	for _, cl in ipairs(cage.Clones) do
		table.sort(cl.Fires)
		local keys = { { cl.Form, "Stand" }, { math.max(cl.Form + 0.1, CG.AimAt), "Ready" } }
		for _, f in ipairs(cl.Fires) do
			keys[#keys + 1] = { f - 0.14, "Ready" }
			keys[#keys + 1] = { f - 0.05, "Wind" }
			keys[#keys + 1] = { f, "Release" }
			keys[#keys + 1] = { f + 0.1, "Follow" }
			keys[#keys + 1] = { f + 0.38, "Ready" }
		end
		table.sort(keys, function(a, b) return a[1] < b[1] end)
		cl.Keys = keys
	end
end

function FBX.Phase(cl, age)
	local keys = cl.Keys
	if age <= keys[1][1] then return keys[1][2], keys[1][2], 0 end
	for j = 1, #keys - 1 do
		local a, b = keys[j], keys[j + 1]
		if age >= a[1] and age < b[1] then
			return a[2], b[2], smooth((age - a[1]) / math.max(1e-3, b[1] - a[1]))
		end
	end
	local z = keys[#keys][2]
	return z, z, 0
end

function FBX.CloneStep(cage, age, parts, cframes, aimAt)
	local kit = FBX.Kit()
	for _, cl in ipairs(cage.Clones) do
		if age >= cl.Form - 0.05 then
			local S = cl.S
			local t = 1 - (1 - kit.Look.CloneT) * math.max(0, easeOut((age - cl.Form) / CG.Condense))
			if math.abs(t - (cl.T or -1)) > 0.01 then
				cl.T = t
				for i, part in ipairs(cl.Parts) do
					if cl.Vis[i] then part.Transparency = t end
				end
			end
			local a, b, w = FBX.Phase(cl, age)
			local A, Bp = cl.Poses[a], cl.Poses[b]
			local function at(i)
				local cf = (w > 0) and A[i]:Lerp(Bp[i], w) or A[i]
				return cl.W * CFrame.new(cf.Position * S) * cf.Rotation
			end
			for i, part in ipairs(cl.Parts) do
				if cl.Vis[i] then
					parts[#parts + 1] = part
					cframes[#cframes + 1] = at(i)
				end
			end
			if cage.HandIdx then cl.Hand = at(cage.HandIdx) * (cage.HandOff * S) end
			-- the next kunai in its hand until it is thrown
			if cl.Held then
				local hold = false
				for _, f in ipairs(cl.Fires) do
					if age >= f - 0.32 and age < f then
						hold = true
						break
					end
				end
				if hold and cl.Hand then
					local dv = (aimAt - cl.Hand).Unit
					kit.Fade(cl.Held, 0)
					kit.Place(cl.Held, kit.Frame(cl.Hand - dv * (kit.Kinds.Bolt.L * 0.5 * S), dv, Vector3.yAxis), parts, cframes, S)
				else
					kit.Fade(cl.Held, 1)
				end
			end
		end
	end
end

function FBX.CloneDrop(cl)
	pcall(function() cl.Model:Destroy() end)
	if cl.Held then FBX.Kit().Drop(cl.Held) end
end

function CryoFX.MirrorCage(d)
	if typeof(d.Center) ~= "Vector3" then return end
	local rows = d.Victims
	if type(rows) ~= "table" then
		rows = d.Victim and { { Model = d.Victim, At = d.Center } } or {}
	end
	local total = CryoTuning.MirrorCageRoot()
	if serverNow() > d.T0 + total + 1.5 then return end
	local key = d.Character or d
	if cages[key] then cages[key].Break = true end
	local rng = Random.new(math.floor((d.T0 or 0) * 1000) % 2 ^ 30)
	local thin = thinFor(d.Character)
	local dens = density(d.Character)
	local fbk = FBX.On(d.Character)                     -- Frostblade: ice clones of the caster throwing kunai, no panels
	-- (2026-10-19, audit P5A-15) the clones are copies of the caster's body (buildTemplate): with no body on this client
	-- (streamed out, dead, not loaded) there is nothing to copy, so the cage draws the Default's panels, not no dome
	if fbk and not (d.Character.Parent and d.Character:FindFirstChild("HumanoidRootPart")
		and d.Character:FindFirstChildOfClass("Humanoid")) then fbk = false end
	-- Frost Lotus: a full bloom in every place; Snow Globe: one giant globe (lfk: the skin's FX module)
	local lfk = (not fbk) and ((FBX.DragonOn(d.Character) and FBX.Dragon()) or (FBX.LotusOn(d.Character) and FBX.Lotus())
		or FBX.Globe(d.Character)) or nil
	local folder = Instance.new("Folder")
	folder.Name = "MirrorCage"
	folder.Parent = fxFolder()
	local center = d.Center
	local yaw = d.Yaw or 0
	local gy = center.Y
	local C = center + Vector3.new(0, CG.DomeY, 0)
	local aimAt = C + Vector3.new(0, 0.3, 0)
	local bolts = CryoTuning.MirrorCageBolts()
	local killAt = (bolts[#bolts] and bolts[#bolts].Arrive or (total - 0.2)) + 0.02
	local impAt = killAt + 0.33
	local cage = { Folder = folder, Panels = {}, T0 = d.T0, Flying = {}, Set = {}, Victims = {}, KillAt = killAt, ImpAt = impAt,
		Caster = d.Character }
	cages[key] = cage

	-- the trapped
	for _, row in ipairs(rows) do
		local model = row.Model
		if model == player.Character then frostScreen(d.T0 + total) end
		if typeof(model) == "Instance" and model.Parent and typeof(row.At) == "Vector3" then
			local v = { Model = model, At = row.At, Gone = false, Key = {} }
			local _, feet = feetOf(model)
			v.Top = math.min(D.LineTop, bodyTop(model, feet or row.At.Y) * 1.04)
			v.Line = take("CK_Ring", "Line")
			if v.Line then
				v.Line.Transparency = 1
				v.Line.Parent = folder
			end
			cage.Victims[#cage.Victims + 1] = v
		end
	end

	-- the dome: rings of panels on the hemisphere, the caster's line of sight passing between two of them
	local g = 0
	for ri, ring in ipairs(CG.Rings) do
		if not (thin and ri == #CG.Rings) then
			local n = ring.Count
			local step = 2 * math.pi / n
			local a0 = yaw + step * 0.5 + ((ri % 2 == 0) and step * 0.5 or 0)
			for k = 0, n - 1 do
				local az = a0 + k * step + rng:NextNumber(-0.08, 0.08)
				local el = math.rad(ring.El) + rng:NextNumber(-0.05, 0.05)
				local rr = M.Radius * rng:NextNumber(0.95, 1.05)
				local pos = C + dirAt(az) * (math.cos(el) * rr) + Vector3.new(0, math.sin(el) * rr, 0)
				local size = rng:NextInteger(0, 3)
				local R = ring.Plate[1] + (ring.Plate[2] - ring.Plate[1]) * size / 3
				local var = rng:NextInteger(1, 4)
				local pn = (fbk or lfk) and { R = R, Var = var, Rims = {}, Scale = 1 } or newPanel(var, R, folder, thin)
				g += 1
				pn.Pos, pn.Index, pn.Ring = pos, g, ri
				pn.Spin = 0.4 * g
				pn.Sign = (g % 2 == 0) and 1 or -1
				pn.Form = CG.FormAt + CG.FormSpan * ((k + (ri - 1) * 0.5) / n)
				pn.Vapor = false
				-- its shots: round the ring one after another, every ShotGap
				pn.Fires = {}
				for s = 0, CG.Shots - 1 do
					if not (thin and s % 2 == 1) then
						local f = CG.FireAt + (k % 8) * CG.RingStep + (ri - 1) * 0.12 + s * CG.ShotGap
						if f < killAt - 0.1 then pn.Fires[#pn.Fires + 1] = f end
					end
				end
				pn.NextFire = 1
				-- the trapped body nearest it is the one it fires at
				local best, bestD
				for _, v in ipairs(cage.Victims) do
					local dd = flat(pos - v.At).Magnitude
					if not bestD or dd < bestD then best, bestD = v, dd end
				end
				pn.Victim = best
				cage.Panels[#cage.Panels + 1] = pn
				if fbk or lfk then
					pn.Now = CFrame.lookAt(pos, aimAt)
				else
					pn.P.CFrame = CFrame.new(pos)
					for _, r in ipairs(pn.Rims) do r.P.CFrame = CFrame.new(pos) end
				end
			end
		end
	end

	-- the reflections of the caster: on every panel at High, on fewer at lower Graphics Quality or for somebody else's
	-- cage under Reduce Enemy VFX -- the panels nearest this client's camera keep theirs, the far ones go first
	if not (fbk or lfk) then
		local share = math.clamp(Settings.EffectDensity or 1, 0.3, 1)
		if thin then share = math.min(share, CARD.ThinShare) end
		local cam = workspace.CurrentCamera
		local eye = cam and cam.CFrame.Position or center
		local order = table.clone(cage.Panels)
		-- the reflections are on the inner faces: the panels whose inner face this camera sees come first, nearest first
		local function seen(pn) return (eye - pn.Pos):Dot(aimAt - pn.Pos) > 0 end
		table.sort(order, function(a, b)
			local sa, sb = seen(a), seen(b)
			if sa ~= sb then return sa end
			return (a.Pos - eye).Magnitude < (b.Pos - eye).Magnitude
		end)
		local keep = math.ceil(#order * share)
		local liveMax = thin and LIVE.ThinMax
			or math.clamp(math.floor(LIVE.Max * math.clamp(Settings.EffectDensity or 1, 0, 1) + 0.5), LIVE.MinMax, LIVE.Max)
		local tmpl
		if keep > 0 and liveMax > 0 then
			local ok, t = pcall(buildTemplate, d.Character)
			if ok then tmpl = t else warnOnce("mirrortmpl", "mirror template: " .. tostring(t)) end
		end
		cage.Template = tmpl
		local tones = avatarTones(d.Character) or casterTones(d.Character)
		cage.Tones = tones
		cage.LiveQueue = {}
		local shift = rng:NextInteger(0, 3)
		for i = 1, keep do
			local pn = order[i]
			local idle = CARD.Idle[(pn.Index + shift) % #CARD.Idle + 1]
			pn.Idle, pn.Tilt = idle, rng:NextNumber(-CARD.Tilt, CARD.Tilt)
			if tmpl and #cage.LiveQueue < liveMax then
				-- built a few a frame (LIVE.PerFrame), well before the panels form: no hitch on the cast frame
				cage.LiveQueue[#cage.LiveQueue + 1] = pn
			else
				addReflection(pn, idle, pn.Tilt, tones)
			end
			-- it turns on the trapped just before its own first shot: the panels' firing order staggers them
			pn.SnapAt = math.max(CG.AimEnd, (pn.Fires[1] or CG.FireAt) - LIVE.AimLead)
		end
	end
	if fbk then
		local ok, err = pcall(FBX.CageSetup, cage, d.Character, aimAt, center, gy, thin)
		if not ok then warnOnce("fbcage", "frostblade cage: " .. tostring(err)) end
	elseif lfk then
		local ok, err = pcall(lfk.CageSetup, cage, aimAt, thin, center, gy)
		if not ok then warnOnce("flcage", "frost lotus cage: " .. tostring(err)) end
	else
		for _, pn in ipairs(cage.Panels) do addGlare(pn) end
	end

	-- the lock-on Frost Line circle, the frost disc, the clusters, the mist, a light on the target
	local lock = take("CK_Ring", "Line")
	if lock then
		lock.Transparency = 1
		lock.Parent = folder
	end
	-- a skin's ground (lfk.Ground, optional; Frost Dragon's): the disc's art / tint / opacity, the rings' glow, the clusters' styles
	local gd = (lfk and lfk.Ground) or {}
	local fl = floorNew(center, rng, { R = CG.Disc, Spread = CG.DiscTime, RingFade = gd.RingFade, Melt = CG.MeltTime, Parent = folder,
		Tex = gd.Tex and (TEX[gd.Tex] or gd.Tex), Tint = gd.Tint, T = gd.T, Glow = gd.Glow })
	local nc = thin and math.ceil(CG.Clusters / 2) or CG.Clusters
	for i = 1, nc do
		local dir = dirAt(yaw + (i - 0.5) * 2 * math.pi / nc + rng:NextNumber(-0.15, 0.15))
		local at = center + dir * CG.ClusterRing * rng:NextNumber(0.9, 1.1)
		cluster(cage.Set, rng, Vector3.new(at.X, gy, at.Z), rng:NextNumber(CG.ClusterH[1], CG.ClusterH[2]), {
			Spikes = thin and 3 or rng:NextInteger(4, 6), Bases = rng:NextInteger(1, 2), Mound = true, Out = dir,
			Delay = CG.ClusterAt + i * 0.025, Stagger = 0.02, Dur = 0.22, Flare = false, BaseStyle = gd.Base, SpikeStyle = gd.Spike }, folder)
	end
	local mistHost = host(CFrame.new(center + Vector3.new(0, 1, 0)), folder)
	mistHost.Size = Vector3.new(M.Radius * 1.6, 1.2, M.Radius * 1.6)
	local mist = mistEmitter(mistHost, 6, 12, 0.8)
	local h = host(CFrame.new(aimAt), folder)
	local light
	if Lighting.Brightness >= 0.05 then
		light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = COL.Flash, 0, 16, false
		light.Parent = h
	end
	playSound(h, "Form")

	local function chestOf(v)
		local r = v.Model:FindFirstChild("HumanoidRootPart") or v.Model.PrimaryPart
		return r and (r.Position + Vector3.new(0, 0.6, 0)) or (v.At + Vector3.new(0, 3, 0))
	end

	local function freeVictim(v)
		if v.Gone then return end
		v.Gone = true
		v.FreedAt = serverNow() - cage.T0
		setTint(v.Model, v.Key, nil)
	end
	cage.Free = freeVictim

	local lastBoltSound = 0
	local burstDone, killed, broke = false, false, false
	local ripple1 = false

	-- (2026-10-19, audit P5A-13) the cage's end, every piece guarded: run on its last frame, and also when a frame errors
	-- (a skin's hook), so the folder, the panels and blooms and the victims' frozen tint never stay behind on screen
	local function finish()
		for _, v in ipairs(cage.Victims) do
			pcall(skinDrop, v.Skin)
			pcall(give, v.Line)
			pcall(setTint, v.Model, v.Key, nil)
		end
		for _, fly in ipairs(cage.Flying) do
			pcall(function() if fly.O then (fly.Kit or FBX.Kit()).Drop(fly.O) else give(fly.P) end end)
		end
		for _, cl in ipairs(cage.Clones or {}) do pcall(FBX.CloneDrop, cl) end
		if cage.Blooms and lfk then pcall(lfk.CageDrop, cage) end
		pcall(dropSet, cage.Set)
		pcall(floorDrop, fl)
		pcall(give, lock)
		task.delay(2, function() folder:Destroy() end)
		for _, pn in ipairs(cage.Panels) do pcall(panelDrop, pn) end
		if cage.Template then pcall(function() cage.Template.Model:Destroy() end) end
		cage.Template = nil
		if cages[key] == cage then cages[key] = nil end
	end

	local function frame(now, dt, parts, cframes)
		local age = serverNow() - cage.T0
		if cage.Break and not broke and age < cage.ImpAt then
			cage.ImpAt = age
			cage.KillAt = math.min(cage.KillAt, age)
		end
		local kA, iA = cage.KillAt, cage.ImpAt

		-- lock-on: the Frost Line drawing round the target, bright while it draws, then dimming
		if lock then
			local u = math.clamp(age / CG.LockTime, 0, 1)
			if age < iA and u > 0 then
				lineLook(lock, gd.Glow or (1 - smooth((age - CG.LockTime) / 0.4) * 0.8), smooth((age - 0.9) / 0.4))
				local r = CG.LockR * (0.35 + 0.65 * easeOut(u))
				placeRing(lock, CFrame.new(center + Vector3.new(0, 0.09, 0)), r, r, L.LineThick, parts, cframes)
			elseif lock.Transparency ~= 1 then
				lock.Transparency = 1
			end
		end
		if not ripple1 and age >= CG.ClusterAt then
			ripple1 = true
			ripple(CFrame.new(center + Vector3.new(0, 0.1, 0)), 0.5, CG.ClusterRing * 1.4, 0.7, 0.45)
		end
		if not floorStep(fl, age, parts, cframes) and broke then
			floorDrop(fl)
		end
		if not broke then
			growStep(cage.Set, age, parts, cframes, thin)
			mist.Rate = (age > CG.FormAt and age < kA) and 8 * dens or 0
		end

		-- the live reflections still to build (a card where one cannot be)
		local q = cage.LiveQueue
		if q and #q > 0 then
			for _ = 1, LIVE.PerFrame do
				local pn = table.remove(q, 1)
				if not pn then break end
				if not pn.Dropped then
					local ok, res = pcall(addLive, pn, cage.Template, pn.Tilt)
					if not ok then warnOnce("mirrorlive", "live reflection: " .. tostring(res)) end
					if not (ok and res == true) then addReflection(pn, pn.Idle, pn.Tilt, cage.Tones) end
					if pn.Now then reflectionUpright(pn, pn.Now) end
				end
			end
		end

		-- the panels
		if not broke then
			local aimU = math.clamp((age - CG.AimAt) / (CG.AimEnd - CG.AimAt), 0, 1)
			local tick = math.floor(aimU * 4) / 4 + 0.25 * smooth((aimU * 4 - math.floor(aimU * 4)) / 0.25)
			local off = (1 - math.min(1, tick)) * 0.5
			local kill = smooth((age - kA) / 0.15)
			local impU = smooth((age - iA) / CG.ImpactDur)
			local moving = age < CG.AimEnd + 0.05 or age >= iA
			local cam = workspace.CurrentCamera
			local eye = cam and cam.CFrame.Position or center
			local camUp = cam and cam.CFrame.UpVector or Vector3.yAxis
			local calm = Settings.Get and Settings.Get("ReduceFlashing")
			for _, pn in ipairs(cage.Panels) do
				local cond = easeOut((age - pn.Form) / CG.Condense)
				if fbk or lfk then
					-- no panel: its clone is drawn below (a breath of vapor where it condenses)
					if age >= pn.Form - 0.12 and not pn.Vapor and not thin and pn.Clone and pn.Clone.Form == pn.Form then
						pn.Vapor = true
						burst(pn.Clone.W.Position + Vector3.new(0, 1, 0), (aimAt - pn.Pos), { Breath = 3, Powder = 1 }, dens, 0.6)
					end
				else
					if age >= pn.Form - 0.12 and not pn.Vapor and not thin then
						pn.Vapor = true
						burst(pn.Pos, (aimAt - pn.Pos), { Breath = 3, Powder = 1 }, dens, 0.6)
					end
					if age < pn.Form then
						panelLook(pn, 0)
					else
						panelLook(pn, cond * (1 - impU * 0.5))
						reflectionLook(pn, smooth((age - pn.Form - CARD.SurfaceAt) / CARD.SurfaceTime) * (1 - impU))
						if moving or not pn.Now then
							local pos = pn.Pos + (aimAt - pn.Pos) * CG.Inward * impU
							local cf = CFrame.lookAt(pos, aimAt) * CFrame.Angles(off * pn.Sign, 0, 0) * CFrame.Angles(0, 0, pn.Spin)
							panelPlace(pn, cf, (0.85 + 0.15 * cond) * (1 - 0.6 * impU), parts, cframes)
							reflectionUpright(pn, cf)
						end
						panelView(pn, eye, camUp)
					end
					if pn.SnapAt and not pn.Snapped and age >= pn.SnapAt then
						pn.Snapped = true
						reflectionPose(pn, CARD.Poses.Cast)
						local v = pn.Victim
						if v and v.Gone then v = nil end
						pcall(liveAim, pn, v and chestOf(v) or aimAt)
					end
				end
				-- its shots: the outline pulse, the centre flare, a bolt into the trapped body nearest it
				local pulse = 0
				while pn.Fires[pn.NextFire] and pn.Fires[pn.NextFire] <= age do
					local f = pn.Fires[pn.NextFire]
					pn.NextFire += 1
					local v = pn.Victim
					if v and v.Gone then
						v = nil
						for _, o in ipairs(cage.Victims) do if not o.Gone then v = o break end end
						pn.Victim = v
					end
					if v and pn.Now and age - f < 0.1 then
						-- the bolt leaves the reflection's hand, where it shows on the glass (Frostblade: the clone's hand)
						local from = (lfk and lfk.BoltFrom(pn, aimAt)) or (fbk and ((pn.Clone and pn.Clone.Hand) or pn.Pos))
							or handOnGlass(pn) or (pn.Now.Position + (aimAt - pn.Now.Position).Unit * (CG.Thick + 0.2))
						local to = chestOf(v) + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.9, 0.4), rng:NextNumber(-0.3, 0.3))
						local kn = (fbk and FBX.Kit().New("Bolt", folder)) or (lfk and lfk.NewBolt(folder)) or nil
						if kn then
							local tr = boltTrail(kn.Body)
							pcall(function() tr:Clear() end)
							tr.Enabled = true
							-- (Frost Lotus: the bolt leaves its petal, but flies on the Default's time -- TimeFrom -- so it lands on its beat)
							local tf = (lfk and lfk.TimeFrom and lfk.TimeFrom(pn, aimAt)) or from
							cage.Flying[#cage.Flying + 1] = { O = kn, From = from, To = to, Fire = f, Dur = (to - tf).Magnitude / CG.BoltSpeed,
								Kit = lfk and lfk.Kit or FBX.Kit(), Spiral = lfk }
							if lfk then pcall(lfk.Peel, from) end              -- the petal peels; the bloom regrows it
						end
						local p = (not (fbk or lfk)) and take("CK_MC_Bolt", "Tip") or nil
						if p then
							p.Transparency = 0.25
							p.Size = Vector3.new(0.16, 0.16, 1.4)
							p.CFrame = CFrame.lookAt(from, to)
							p.Parent = folder
							local tr = boltTrail(p)
							pcall(function() tr:Clear() end)
							tr.Enabled = true
							cage.Flying[#cage.Flying + 1] = { P = p, From = from, To = to, Fire = f, Dur = (to - from).Magnitude / CG.BoltSpeed }
						end
						if not thin then burst(from, to - from, { Glints = 1 }, dens) end
						if now - lastBoltSound > 0.12 then
							lastBoltSound = now
							playSound(h, "Bolt")
						end
					end
				end
				if not (fbk or lfk) then
					local flash = 0
					local ft = calm and GLARE.CalmTime or GLARE.FlashTime
					for _, f in ipairs(pn.Fires) do
						if f <= age then
							pulse += math.exp(-(age - f) / CG.Pulse)
							flash = math.max(flash, math.exp(-(age - f) / ft))
						end
					end
					glareStep(pn, (age < pn.Form) and 0 or cond * (1 - impU), flash * (calm and GLARE.CalmFlash or 1))
					-- (2026-10-19, audit P5A-09) no ~10 Hz flicker on the kill outline under Reduce Flashing
					local flick = calm and 0.85 or 0.75 + 0.25 * math.sin(age * 61 + pn.Index * 1.7)
					local kp = (age >= kA) and (math.exp(-(age - kA) / CG.KillPulse) * 0.9 + 0.35) * flick or 0
					panelPulse(pn, (age < iA) and math.max(math.min(1, pulse) * 0.95, kp * kill) or 0)
					panelCracks(pn, smooth((age - kA) / (iA - kA)))
				end
			end
			if fbk and cage.Clones then FBX.CloneStep(cage, age, parts, cframes, aimAt) end
			if lfk and cage.Blooms then lfk.CageStep(cage, age, parts, cframes, CG.Condense, impU) end
			if light then
				local fl2 = 0
				for _, fly in ipairs(cage.Flying) do if age - fly.Fire < fly.Dur + 0.08 then fl2 += 1 end end
				light.Brightness = (age >= kA and age < iA) and 3 * (1 - smooth((age - kA) / 0.3)) + 1 or math.min(1.5, fl2 * 0.25)
			end
		end

		-- the kill: a cold flash on the trapped, FROZEN!
		if not killed and age >= kA then
			killed = true
			for _, v in ipairs(cage.Victims) do
				if not v.Gone and not isDead(v.Model) then
					flashAt(chestOf(v), 3, 14, 0.3)
					popFrozen(v.Model)
				end
			end
		end

		-- the shatter: past the lunge every panel bursts inward into shards and powder; the clusters break
		if not burstDone and age >= iA + CG.ImpactDur then
			burstDone = true
			broke = true
			local r2 = Random.new()
			for i, pn in ipairs(cage.Panels) do
				local at = pn.Now and pn.Now.Position or pn.Pos
				local inward = (aimAt - at).Unit
				if pn.Now and not (fbk or lfk) then
					local n = thin and 2 or 5
					for k = 1, n do
						local name = (k % 2 == 0) and CHUNKS[r2:NextInteger(1, #CHUNKS)] or SPLINTERS[r2:NextInteger(1, #SPLINTERS)]
						local sz = (k % 2 == 0) and Vector3.one * r2:NextNumber(0.35, 0.7)
							or templateSize[name] * r2:NextNumber(2.2, 3.6)
						local off = Vector3.new(r2:NextNumber(-1, 1), r2:NextNumber(-1, 1), r2:NextNumber(-1, 1)) * pn.R * 0.4
						throw(name, CFrame.new(at + off) * CFrame.Angles(r2:NextNumber(0, 6.3), r2:NextNumber(0, 6.3), 0),
							(inward + Vector3.new(r2:NextNumber(-0.6, 0.6), r2:NextNumber(-0.3, 0.6), r2:NextNumber(-0.6, 0.6))) * r2:NextNumber(4, 9),
							Vector3.new(r2:NextNumber(-1, 1), r2:NextNumber(-1, 1), r2:NextNumber(-1, 1)) * 8, r2:NextNumber(0.9, 1.3), sz, gy, "Body")
					end
					if not thin or i % 2 == 0 then burst(at, inward, { Chips = 6, Powder = 2 }, dens) end
				end
				panelDrop(pn)
			end
			table.clear(cage.Panels)
			for i, cl in ipairs(cage.Clones or {}) do
				local at = cl.W * Vector3.new(0, 1.6 * cl.S, 0)
				local inward = (aimAt - at).Unit
				for k = 1, (thin and 2 or 4) do
					local name = (k % 2 == 0) and CHUNKS[r2:NextInteger(1, #CHUNKS)] or SPLINTERS[r2:NextInteger(1, #SPLINTERS)]
					local sz = (k % 2 == 0) and Vector3.one * r2:NextNumber(0.3, 0.55) or templateSize[name] * r2:NextNumber(1.8, 2.8)
					local off = Vector3.new(r2:NextNumber(-1, 1), r2:NextNumber(-1, 1), r2:NextNumber(-1, 1)) * cl.S
					throw(name, CFrame.new(at + off) * CFrame.Angles(r2:NextNumber(0, 6.3), r2:NextNumber(0, 6.3), 0),
						(inward + Vector3.new(r2:NextNumber(-0.6, 0.6), r2:NextNumber(-0.3, 0.6), r2:NextNumber(-0.6, 0.6))) * r2:NextNumber(4, 9),
						Vector3.new(r2:NextNumber(-1, 1), r2:NextNumber(-1, 1), r2:NextNumber(-1, 1)) * 8, r2:NextNumber(0.9, 1.3), sz, gy, "Body")
				end
				if not thin or i % 2 == 0 then burst(at, inward, { Chips = 6, Powder = 2 }, dens) end
				FBX.CloneDrop(cl)
			end
			cage.Clones = nil
			if cage.Blooms and lfk then pcall(lfk.CageBurst, cage, aimAt, gy, thin) end
			snapSet(cage.Set, center, gy, r2, 5, thin and 0.5 or 1)
			burst(C, Vector3.yAxis, { Flakes = 20, Powder = 6 }, dens, 1.2)
			ripple(CFrame.new(center + Vector3.new(0, 0.1, 0)), 0.8, M.Radius * 1.05, 0.8, 0.4)
			fl.MeltAt = age + 0.3
			mist.Rate = 0
			if light then light.Brightness = 0 end
			for _, v in ipairs(cage.Victims) do setTint(v.Model, v.Key, nil) end
			playSound(h, "Break")
		end

		-- the trapped ice over through the volley: the coat climbing under the Frost Line, the body going dark under it
		for _, v in ipairs(cage.Victims) do
			if not v.Gone and isDead(v.Model) then freeVictim(v) end
			local root, feet = feetOf(v.Model)
			local endFade = broke and smooth((age - iA - CG.ImpactDur) / 0.35) or 0
			if v.Gone then endFade = math.max(endFade, smooth((age - (v.FreedAt or age)) / 0.35)) end
			if root and feet and endFade < 1 then
				local cu = math.clamp((age - CG.FireAt) / (kA - CG.FireAt), 0, 1)
				local hh = v.Top * cu
				if not broke and not v.Gone then setTint(v.Model, v.Key, cu) end
				if v.Skin then skinStep(v.Skin, feet - 0.05, feet + hh, endFade, parts, cframes) end
				if v.Line then
					if cu <= 0 then
						if v.Line.Transparency ~= 1 then v.Line.Transparency = 1 end
					else
						local look = flat(root.CFrame.LookVector)
						look = look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
						local y = feet + math.max(0.05, hh)
						lineLook(v.Line, (cu < 1) and 1 or (1 - smooth((age - kA) / L.LineDimTime)), endFade)
						placeRing(v.Line, CFrame.lookAt(Vector3.new(root.Position.X, y, root.Position.Z),
							Vector3.new(root.Position.X, y, root.Position.Z) + look), CG.LineRX, CG.LineRZ, L.LineThick, parts, cframes)
					end
				end
			else
				if v.Skin then skinStep(v.Skin, 0, -1, 1, parts, cframes) end
				if v.Line and v.Line.Transparency ~= 1 then v.Line.Transparency = 1 end
			end
		end

		-- the bolts in flight
		for i = #cage.Flying, 1, -1 do
			local fly = cage.Flying[i]
			local u = (age - fly.Fire) / fly.Dur
			if u >= 1 or broke then
				table.remove(cage.Flying, i)
				if fly.O then (fly.Kit or FBX.Kit()).Drop(fly.O) else give(fly.P) end
				if u >= 1 and fly.Spiral then pcall(fly.Spiral.Strike, fly.To, thin, dens) end
				if u >= 1 and not thin then
					local dir = (fly.To - fly.From).Unit
					burst(fly.To, -dir, { Chips = 2, Glints = 1 }, dens)
				end
			else
				local pos = fly.From:Lerp(fly.To, u)
				if fly.Spiral then
					fly.Spiral.PlaceBolt(fly, u, parts, cframes)
				elseif fly.O then
					local kit, dir = FBX.Kit(), (fly.To - fly.From).Unit
					kit.Place(fly.O, kit.Frame(pos - dir * (kit.Kinds.Bolt.L * 0.5), dir, Vector3.yAxis), parts, cframes)
				else
					parts[#parts + 1] = fly.P
					cframes[#cframes + 1] = CFrame.lookAt(pos, fly.To)
				end
			end
		end

		if broke then
			sinkSet(cage.Set, smooth((age - iA - CG.ImpactDur - 0.5) / 0.6), parts, cframes)
		end
		if broke and age > iA + 0.3 + CG.MeltTime + 0.2 then
			finish()
			return false
		end
		return true
	end

	run(function(now, dt, parts, cframes)
		local ok, keep = pcall(frame, now, dt, parts, cframes)
		if ok then return keep end
		warnOnce("cagestep", "Mirror Cage stopped: " .. tostring(keep))
		finish()
		return false
	end)
end

--- The cage ends early (the caster left the arena, a round reset, everyone in it gone): it breaks for everyone now.
function CryoFX.MirrorCageEnd(d)
	local cage = d.Character and cages[d.Character]
	if cage then cage.Break = true end
end

--- One trapped body is let go early (they were cleared or left): their frost fades, the others stay trapped.
function CryoFX.MirrorCageFree(d)
	local cage = d.Character and cages[d.Character]
	if not (cage and cage.Free) then return end
	for _, v in ipairs(cage.Victims) do
		if v.Model == d.Victim then cage.Free(v) end
	end
end

----------------------------------------------------------------------------------------------------
-- CHILL: the Icicle Shard's stacks on the victim's body (AbilityHandler broadcasts "ChillStacks" with each change).
-- Each stack climbs the frost further up the shins (white frost from the feet up, the Frost Line on its top edge only
-- while it climbs, then the calm rim) and grows a few small crystals; the third climbs to the knees in Look.Chill.Climb
-- and grows two ankle-cuff clusters (a chunky base prism, spikes, a frost mound).
----------------------------------------------------------------------------------------------------
local crusts = {}                -- [model] = crust
local CH = L.Chill

--- The knees, over the feet.
local function kneeHeight(model, feet)
	local ll = model:FindFirstChild("LeftLowerLeg") or model:FindFirstChild("RightLowerLeg")
	if ll and ll:IsA("BasePart") then return math.clamp(ll.Position.Y + ll.Size.Y / 2 - feet, 0.8, 3) end
	local leg = model:FindFirstChild("Left Leg") or model:FindFirstChild("Right Leg")
	if leg and leg:IsA("BasePart") then return math.clamp(leg.Size.Y * 0.55, 0.8, 3) end
	return 1.4
end

local function crustBase(root, feet)
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
	local at = Vector3.new(root.Position.X, feet, root.Position.Z)
	return CFrame.lookAt(at, at + look)
end

local function crustFor(model)
	local c = crusts[model]
	if c and not c.Gone then return c end
	local folder = Instance.new("Folder")
	folder.Name = "ChillCrust"
	folder.Parent = fxFolder()
	local root, feet = feetOf(model)
	c = {
		Folder = folder, Stacks = 0, Crystals = {}, Line = nil, Changed = os.clock(), Rng = Random.new(),
		H = 0, From = 0, To = 0, Climb = CH.Grow, Knee = (root and feet) and kneeHeight(model, feet) or 1.4,
		Skin = skinNew(model, folder, nil),
	}
	crusts[model] = c
	run(function(now, dt, parts, cframes)
		local rt, ft = feetOf(model)
		if not rt or not model.Parent then
			c.Stacks = 0
			c.Gone = true
		end
		if c.Gone then
			for _, cr in ipairs(c.Crystals) do give(cr.P) end
			skinDrop(c.Skin)
			if c.Line then give(c.Line) end
			folder:Destroy()
			if crusts[model] == c then crusts[model] = nil end
			return false
		end
		local base = crustBase(rt, ft)
		for _, cr in ipairs(c.Crystals) do
			local u = (now - cr.Born) / cr.Dur
			if u > 0 then
				local k = easeOut(u)
				if cr.P.Transparency ~= cr.T then cr.P.Transparency = cr.T end
				local s = cr.Size * Vector3.new(1, math.max(0.03, k), 1)
				cr.P.Size = s
				parts[#parts + 1] = cr.P
				cframes[#cframes + 1] = (cr.Mode == "centre") and (base * cr.Local) or (base * cr.Local * CFrame.new(0, s.Y * 0.5, 0))
			end
		end
		-- the frost and its line climb to the stack's height
		local since = now - c.Changed
		c.H = c.From + (c.To - c.From) * easeOut(since / c.Climb)
		skinStep(c.Skin, ft - 0.2, ft + c.H, 0, parts, cframes)
		if c.Line and c.Stacks > 0 then
			local glow = (since < c.Climb) and 1 or (1 - smooth((since - c.Climb) / L.LineDimTime))
			lineLook(c.Line, glow, 0)
			placeRing(c.Line, base * CFrame.new(0, math.max(0.05, c.H), 0), CH.LineRX, CH.LineRZ, L.LineThick, parts, cframes)
		end
		return true
	end)
	return c
end

--- One crust crystal, relative to the body's foot frame: `loc` is its foot (+Y along it).
local function crustCrystal(c, name, style, loc, size, born, dur, mode)
	local p = take(name, style)
	if not p then return end
	local t = p.Transparency
	p.Transparency = 1
	p.Size = size * Vector3.new(1, 0.03, 1)
	p.Parent = c.Folder
	c.Crystals[#c.Crystals + 1] = { P = p, Kit = (not PLAIN[name]) and name or nil, Style = style, Size = size, Local = loc,
		Born = born, Dur = dur, T = t, Mode = mode }
end

local function addTier(c, model, tier, thin)
	local T = CH.Tiers[tier]
	local rng = c.Rng
	local now = os.clock()
	if T.Cuffs then
		-- two ankle-cuff clusters: a chunky base prism, spikes leaning out, a frost mound
		local rt, ft = feetOf(model)
		local base = rt and crustBase(rt, ft)
		for side = -1, 1, 2 do
			local foot = model:FindFirstChild(side < 0 and "LeftFoot" or "RightFoot")
				or model:FindFirstChild(side < 0 and "Left Leg" or "Right Leg")
			local off = Vector3.new(side * 0.5, 0, 0)
			if base and foot and foot:IsA("BasePart") then
				local lp = base:PointToObjectSpace(foot.Position)
				off = Vector3.new(lp.X, 0, lp.Z)
			end
			local out = Vector3.new(side, 0, 0)
			local name = crystalName(rng)
			crustCrystal(c, name, "Base", footFrame(off, out, rng:NextNumber(0.05, 0.2), rng:NextNumber(0, 6.28)),
				crystalSize(name, rng:NextNumber(0.5, 0.6), rng:NextNumber(0.45, 0.6)), now, 0.2)
			for i = 1, (thin and 1 or CH.CuffSpikes) do
				local a = rng:NextNumber(-1.2, 1.2)
				local dir = Vector3.new(side * math.cos(a), 0, math.sin(a))
				local hh = rng:NextNumber(CH.CuffH[1], CH.CuffH[2]) * ((i == 1) and 1 or 0.7)
				local nm = crystalName(rng)
				crustCrystal(c, nm, "Body", footFrame(off + dir * 0.2 + Vector3.new(0, 0.15, 0), dir, rng:NextNumber(0.25, 0.6), rng:NextNumber(0, 6.28)),
					crystalSize(nm, hh * rng:NextNumber(0.14, 0.2), hh), now + 0.03 * i, 0.22)
			end
			if not thin then
				crustCrystal(c, "@Mound", "Frost", CFrame.new(off), Vector3.new(0.95, 0.4, 0.8), now - 0.02, 0.18, "centre")
			end
		end
		return
	end
	for b = 1, (thin and math.min(1, T.Bases) or T.Bases) do
		local a = (b - 0.5) * math.pi + rng:NextNumber(-0.4, 0.4)
		local dir = dirAt(a)
		local name = crystalName(rng)
		crustCrystal(c, name, "Base", footFrame(dir * T.Radius * 0.8, dir, rng:NextNumber(0.05, 0.2), rng:NextNumber(0, 6.28)),
			crystalSize(name, rng:NextNumber(0.3, 0.38), rng:NextNumber(0.22, 0.32)), now, 0.15)
	end
	local n = thin and math.max(1, T.Spikes - 1) or T.Spikes
	for i = 1, n do
		local a = (i - 1 + rng:NextNumber(-0.3, 0.3)) * 2 * math.pi / n + tier * 0.6
		local dir = dirAt(a)
		local hh = rng:NextNumber(T.HLo, T.HHi)
		local name = crystalName(rng)
		local y = (tier - 1) * c.Knee * 0.3 + rng:NextNumber(0, 0.15)
		crustCrystal(c, name, "Tip", footFrame(dir * T.Radius + Vector3.new(0, y, 0), dir, math.rad(rng:NextNumber(12, 28)), rng:NextNumber(0, 6.28)),
			crystalSize(name, hh * rng:NextNumber(0.14, 0.2), hh), now + (i - 1) * 0.02, CH.Grow)
	end
end

local function setCrust(model, stacks, caster)
	if model == player.Character then return end        -- your own is on your health bar (StatusReactions)
	local c = crusts[model]
	if stacks <= 0 then
		if not c then return end
		-- the crust breaks off: every crystal thrown clear (melting as it lands), a puff of powder, the frost and the
		-- line gone with it
		local root, feet = feetOf(model)
		if root then
			local rng = Random.new()
			for _, cr in ipairs(c.Crystals) do
				if cr.Kit and cr.P.Transparency < 1 then
					local cf = cr.P.CFrame
					local out = flat(cf.Position - root.Position)
					out = out.Magnitude > 1e-3 and out.Unit or Vector3.xAxis
					throw(cr.Kit, cf, out * rng:NextNumber(3, 6) + Vector3.new(0, rng:NextNumber(2, 5), 0),
						out:Cross(Vector3.yAxis) * rng:NextNumber(4, 9), rng:NextNumber(0.5, 0.8), cr.P.Size, feet, cr.Style, cr.T)
				end
			end
			burst(Vector3.new(root.Position.X, feet + 0.6, root.Position.Z), Vector3.yAxis, { Powder = 3, Chips = 5 }, density(nil))
		end
		for _, cr in ipairs(c.Crystals) do give(cr.P) end
		c.Crystals = {}
		c.Stacks = 0
		c.Gone = true
		return
	end
	c = crustFor(model)
	local s = math.min(stacks, 3)
	if s ~= c.Stacks then
		c.From = c.H
		c.To = CH.Tiers[s].Height * c.Knee
		c.Climb = (s >= 3) and CH.Climb or CH.Grow
		c.Changed = os.clock()
	end
	if not c.Line then
		c.Line = take("CK_Ring", "Line")
		if c.Line then
			c.Line.Transparency = 1
			c.Line.CFrame = CFrame.new(model:GetPivot().Position)
			c.Line.Parent = c.Folder
		end
	end
	-- add the tiers this stack count has and the crust does not yet
	-- (2026-10-19, audit P5A-12) Reduce Enemy VFX thins an ENEMY shooter's chill only, not every chill (yours included)
	local thin = thinFor(caster)
	for tier = c.Stacks + 1, s do addTier(c, model, tier, thin) end
	c.Stacks = s
end

function CryoFX.ChillStacks(d)
	if not d.Character then return end
	local stacks = tonumber(d.Stacks) or 0
	setCrust(d.Character, stacks, d.Caster)
end

----------------------------------------------------------------------------------------------------
-- COLD MOMENTUM'S BUFF: on the trigger a ripple at the feet and a few flakes; while it runs, white frost cuffs round
-- each ankle draining toward the shin and the heel, and a puff of breath every 0.45 s; at its end a shiver of flakes.
-- Under Reduce Enemy VFX somebody else's buff shows only its prints.
----------------------------------------------------------------------------------------------------
local cm = {}                    -- [character] = { Loops, Folder, NextBreath }
local ANKLE_SEGS = 12

local function ankleLoops(st, character)
	if st.Loops then return st.Loops end
	local folder = Instance.new("Folder")
	folder.Name = "ColdMomentumFrost"
	folder.Parent = fxFolder()
	st.Folder = folder
	st.Loops = {}
	for _, legName in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do
		local leg = character:FindFirstChild(legName) or character:FindFirstChild(legName:find("Left") and "Left Leg" or "Right Leg")
		if leg then
			local segs = {}
			for i = 1, ANKLE_SEGS do
				local seg = take("@Block", "Cuff")
				if seg then
					seg.Parent = folder
					segs[#segs + 1] = seg
				end
			end
			st.Loops[#st.Loops + 1] = { Leg = leg, Segs = segs, R6 = leg.Name:find(" ") ~= nil }
		end
	end
	return st.Loops
end

local function dropColdMomentum(character, shiver)
	local st = cm[character]
	if not st then return end
	cm[character] = nil
	if st.Loops then
		for _, loop in ipairs(st.Loops) do
			for _, seg in ipairs(loop.Segs) do give(seg) end
		end
	end
	if st.Folder then st.Folder:Destroy() end
	if shiver and character.Parent then
		local root, feet = feetOf(character)
		if root then burst(Vector3.new(root.Position.X, feet + 2.5, root.Position.Z), Vector3.yAxis, { Flakes = 18 }, density(character)) end
	end
end

local function stepColdMomentum(parts, cframes)
	local now = serverNow()
	local clock = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local on = c and c:GetAttribute("PassiveActive") == true and (plr:GetAttribute("Element") or "Cryo") == "Cryo"
		local mine = c == player.Character
		local thin = Settings.ThinEnemyVFX and not mine and FBX.Enemy(c)   -- (2026-10-19, audit P5A-12) not a teammate's
		if on then
			local st = cm[c]
			if not st then
				st = { NextBreath = clock + 0.2 }
				cm[c] = st
				if not thin then
					local root, feet = feetOf(c)
					if root then
						ripple(CFrame.new(root.Position.X, feet + 0.06, root.Position.Z), 0.3, 2.4, 0.5)
						burst(Vector3.new(root.Position.X, feet + 0.6, root.Position.Z), Vector3.yAxis, { Flakes = 5 }, density(c))
					end
				end
			end
			if not mine and not thin then
				local total = Config.Elements.Cryo.Passive.Duration
				local f = math.clamp(((c:GetAttribute("PassiveExpires") or now) - now) / total, 0, 1)
				local root = c:FindFirstChild("HumanoidRootPart")
				local fwd = root and flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
				if fwd.Magnitude < 1e-3 then fwd = Vector3.new(0, 0, -1) end
				for _, loop in ipairs(ankleLoops(st, c)) do
					local leg = loop.Leg
					if leg.Parent then
						local r = math.max(leg.Size.X, leg.Size.Z) / 2 + 0.05
						local up = loop.R6 and 0.35 or 0.15
						local cf = leg.CFrame * CFrame.new(0, -leg.Size.Y / 2 + up, 0)
						local chord = 2 * r * math.sin(math.pi / ANKLE_SEGS) * 1.04
						for i, seg in ipairs(loop.Segs) do
							local ang = (i - 0.5) * 2 * math.pi / ANKLE_SEGS
							local dir = (cf * CFrame.Angles(0, ang, 0)).LookVector
							-- frost left within f * 90 deg of the shin (front) or the heel (back)
							local fd = flat(dir)
							local toFront = fd.Magnitude > 1e-3 and math.deg(math.acos(math.clamp(fd.Unit:Dot(fwd.Unit), -1, 1))) or 0
							local off = math.min(toFront, 180 - toFront)
							local t = (off <= f * 90) and STYLE.Cuff[3] or 1
							if seg.Transparency ~= t then seg.Transparency = t end
							if t < 1 then
								seg.Size = Vector3.new(chord, 0.12, 0.06)
								parts[#parts + 1] = seg
								cframes[#cframes + 1] = cf * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -r)
							end
						end
					end
				end
				-- breath
				if clock >= st.NextBreath then
					st.NextBreath = clock + 0.45
					local head = c:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						local lv = head.CFrame.LookVector
						burst(head.Position + lv * 0.6 - Vector3.new(0, 0.2, 0), lv + Vector3.new(0, -0.2, 0), { Breath = 2 }, density(c))
					end
				end
			end
		elseif c and cm[c] then
			dropColdMomentum(c, not thin)
		end
	end
	for character in pairs(cm) do
		if not character.Parent then dropColdMomentum(character, false) end
	end
end

----------------------------------------------------------------------------------------------------
-- start: the per-frame watchers (the whiteout, the frosted edge, Cold Momentum's buff). AbilityFX calls this once.
----------------------------------------------------------------------------------------------------
local started = false
-- what FrostLotusFX draws with (FBX.Lotus hands it over once): this module's own helpers
CryoFX._H = { run = run, take = take, give = give, throw = throw, burst = burst, ripple = ripple, flashAt = flashAt,
	fxFolder = fxFolder, density = density, thinFor = thinFor, flat = flat, smooth = smooth, easeOut = easeOut, dirAt = dirAt,
	host = host, serverNow = serverNow, Settings = Settings, VFXLibrary = VFXLibrary, STYLE = STYLE,
	isEnemy = FBX.Enemy }                -- (2026-10-19, audit P5A-12) the skins' "enemy" test: not me and not a teammate

--- Flash Freeze's zone for a Frost Lotus caster (VFXLibrary.CastFlashFreeze): the field of blooms (FrostLotusFX.Field)
function CryoFX.LotusField(ground, R, leadIn, expand, breakTime, wave, caster)
	local lfx = (FBX.DragonOn(caster) and FBX.Dragon()) or (FBX.LotusOn(caster) and FBX.Lotus()) or FBX.Globe(caster)   -- (Frost Dragon's claw slam, Snow Globe's rim)
	if lfx then lfx.Field(ground, R, leadIn, expand, breakTime, wave, caster) end
end

function CryoFX.Start()
	if started then return end
	started = true
	pcall(function()                  -- Cryo's colour wraps (CryoWrap): the palette tables a wrap swaps, and the entry points
		local w = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("CryoWrap"))
		local vt = VFXLibrary.WrapTables or {}
		w.Install({ CryoFX = CryoFX, VFXLibrary = VFXLibrary, Tables = { { L, "Look" }, { COL, "COL" }, { STYLE, "STYLE" },
			{ KINDS, "KINDS" }, { B, "Blizzard" }, { vt.FF2, "FF2" }, { vt.IS2, "IS2" } },
			Art = { { VFXLibrary.Config.Textures, "Shard", "Shard" }, { TEX, "FrostDisc", "FrostDisc" },
				{ TEX, "FrostDiscLight", "FrostDiscLight" }, { vt.FF2, "Disc", "FrostDisc" } },
			Kits = (function()                          -- the skins' kits (the same module copies their pieces come from)
				local t = {}
				for _, nm in ipairs({ "FrostLotusKit", "FrostbladeKit", "SnowGlobeKit", "FrostDragonKit" }) do
					local m = ReplicatedStorage:WaitForChild("IceMagic"):FindFirstChild(nm)
					local ok, k = pcall(function() return m and require(m) end)
					if ok and k then
						t[#t + 1] = k
						-- (2026-10-19) a kit that lets go of its meshes (MeshBudget) takes take()'s pooled pieces of it along
						local pre = ({ FrostLotusKit = "FL_", FrostbladeKit = "FB_", SnowGlobeKit = "SG_" })[nm]
						if pre and k.OnRelease then
							k.OnRelease(function()
								for nmPool, pool in pairs(pools) do
									if string.sub(nmPool, 1, 3) == pre then
										for _, p in ipairs(pool) do pcall(function() p:Destroy() end) end
										pools[nmPool] = nil
									end
								end
							end)
						end
					end
				end
				return t
			end)() })
		FBX.Wrap, FBX.C, FBX.Bind, FBX.Lit, FBX.WrapRun = w, w.C, w.Bind, w.Lit, w.RunFor
	end)
	task.spawn(FBX.Globe)        -- Snow Globe's kit builds its meshes now, so a first cast is not the Default while it builds
	task.spawn(FBX.DragonKit)    -- (and Frost Dragon's)
	-- the flat art loads up front, so a first cast doesn't draw clear panels and bare floors while it downloads
	task.spawn(function()
		local list = {}
		for _, v in pairs(TEX) do
			if type(v) == "table" then
				for _, id in ipairs(v) do
					local dcl = Instance.new("Decal")
					dcl.Texture = id
					list[#list + 1] = dcl
				end
			else
				local dcl = Instance.new("Decal")
				dcl.Texture = v
				list[#list + 1] = dcl
			end
		end
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
	end)
	run(function(now, dt, parts, cframes)
		local ok, err = pcall(stepHaze, dt)
		if not ok then warnOnce("haze", "whiteout: " .. tostring(err)) end
		ok, err = pcall(stepFrostEdge, dt)
		if not ok then warnOnce("frostedge", "frosted edge: " .. tostring(err)) end
		ok, err = pcall(stepColdMomentum, parts, cframes)
		if not ok then warnOnce("coldmomentum", "cold momentum: " .. tostring(err)) end
		return true
	end)
end

return CryoFX
