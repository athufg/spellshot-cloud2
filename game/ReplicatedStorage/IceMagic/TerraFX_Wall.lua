--[[
	TerraFX_Wall  (ModuleScript)  ->  ReplicatedStorage/IceMagic/TerraFX_Wall

	Terra's BULWARK WALL, the rework's look (blender_scripts/terra/bulwark_wall_bl.py, vfx_blocking/terra/wall/rework/),
	brought into the game 2026-10-09 to the port's contract (vfx_blocking/terra/WALL_TOMB_PORT_SPEC.md). TerraFX keeps
	the hooks (WallRaise / WallHit / WallDrop) and hands them here while Available() is true; until the kit and its data
	are in the place it keeps the old toon look. GAMEPLAY IS UNTOUCHED: the server's body, HP pool, timings and
	broadcasts are the live ones (TerraHandler), this draws over them.

	THE KIT (export/terra_kit/TerraWall2.fbx, imported into ReplicatedStorage.EarthMagicMeshes.TerraWall2 by the
	integrator; the generated ReplicatedStorage.Spellshot.BulwarkWallKitData):
	  BW_Slab_nn (+_Lit/_Dead)        the twelve whole slabs: what stands while a slab is untouched
	  BW_Cnn_kk (+_Brk/_Lit/_Dead)     each slab's coarse cut (6-10 pieces): what it breaks into when it lands
	  BW_T_nn (+_Brk/_Lit/_Dead)       ONE fine cut (the Blender demo slab's 40 pieces, with its four cumulative damage
	                                   stages and knock-offs), scaled onto whichever slab is struck
	  BW_Pebble_nn                     chips off a hit
	Every piece is a charged-rock piece (ChargedRock, the live Boulder Shot's recipe: baked stone, Neon seams).
	PLACEMENT IS READ OFF THE IMPORT, against BW_Origin (the M1 / Aftershock rule: nothing about the layout copied into
	code) -- each part's frame relative to the origin, through KitData.Turn onto the server's wall frame. The data gives
	the MOTION (the template's stage tables and knock-offs, the coarse cuts' names, the ground's throws).

	THE BEATS (t from the server's T0 at ShotTimeScale, so a late join catches up):
	  Raise   the whole wall in ONE stack (the Blender build; the live stagger is Tuning RiseSpread / CourseLag) out of
	          a dark slot, outBack(1.2) from 9 below at 0.06 over 0.26 -- the slot's plates thrown aside, the rim heaved
	  Hit     the NEAREST standing slab (the live WallHit's pick) jolts, flares and advances ONE damage stage (cap 4) --
	          its first hit swaps the whole slab for the scaled fine cut; the stage's knock-offs fly; dust and pebbles at
	          the point. A hit from behind the wall uses the stage table mirrored front to back. Up to 3 slabs show
	          their damage at once; a 4th fresh slab takes the template of the least damaged (which goes back whole).
	  Broken  every damaged slab bursts toward the side away from its hitter; every other slab is let go on a wave
	          (28 studs/s from the worst impact), TOPPLES WHOLE, and breaks into its coarse cut where it lands (a bottom
	          slab hinges over its foot edge; now and then one stays wedged and crumbles where it stands at +1.0)
	  Sink    (Released / Empty / Lost) a give, then the whole stack down 10 over 0.9 s (smoothstep^1.15)
	The rubble rests, then sinks into the floor (the lit pieces' rule: nothing fades).

	THE BUDGET (the contract: at most 160 visual parts per wall at once). Stones are never hidden; the strips and the
	fracture faces are shown by priority (ChargedRock.Show) whenever the set changes -- a loose piece's fracture faces
	first (without them it is open), then the lit seams, then the dead ones. A fine cut that cannot fit is not drawn
	(the slab stays whole); a slab whose coarse cut cannot fit lands whole.

	NO PHYSICS: every part anchored and inert in the FX folder, flown by script (ballistic, g 35, one floor probe per
	stud travelled, bounce and friction), one BulkMoveTo a frame for every wall, on this module's own render step
	("SpellshotTerraWall", bound only while a wall is drawn -- the contract gives each module its own BulkMoveTo).
	NOT PORTED (the contract, decision 7): the caster's flinch / recoil / press-down poses, the hitpause, the camera
	shake. The Blender boulders are not ported either: the hits are whatever really hits the wall.
	WRAPS (2026-10-25, the ladder's round 2; each on its own skin field, so Default and Obsidian Magma are as before): the
	wall's stone in the wrap's material (Stone, ChargedRock's grey copies: prewarmed at the raise, the kit's ground plates
	cloned plain -- they keep the floor's colour), Epic crystals on its pieces (CrystalsBaked: a "Crystal" part the budget
	shows like the strips), Mythic molten break faces (Core, in ChargedRock), the break's ground ring (Shock) and star
	embers rising off the standing wall (Drift). The void and the slot stay Default (readability).
	EVERY NUMBER HERE IS A PROPOSAL (the Blender build's, unless a comment says otherwise).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerraFX_Wall = {}

TerraFX_Wall.Tuning = {
	MeshFolder = "EarthMagicMeshes",
	Kit = "TerraWall2",             -- ReplicatedStorage.EarthMagicMeshes.TerraWall2
	Origin = "BW_Origin",           -- the kit's origin marker: the wall's base centre
	Data = "BulwarkWallKitData",    -- ReplicatedStorage.Spellshot (or .IceMagic).BulwarkWallKitData
	MaxParts = 160,                 -- visual parts per wall at once (the contract: a third of the Blender peak)
	MaxStruck = 3,                  -- slabs showing the fine cut at once
	Late = 0.35,                    -- a one-shot beat (dust, a knock-off's flight) this late is skipped
	MaxHold = 30,                   -- 2026-10-23: unused; a standing wall waits for the server's WallDrop (stepWall)

	-- THE RAISE (bulwark_wall_bl.py rise_raw: -9 * (1 - outBack(u, 1.2)), u = (t - 0.06) / 0.26; hidden at -9.5 before)
	RiseAt = 0.06, RiseTime = 0.26, RiseDepth = 9, RiseOver = 1.2, RiseHidden = 9.5,
	RiseSpread = 0, CourseLag = 0,  -- the live stagger (0.028 s/stud, 0.03 s/course); the Blender build is one stack

	-- A HIT: the struck slab jolts away from the hitter, the rest tremble (the Blender build; its sin rate is ours)
	JoltAmp = 0.05, JoltTau = 0.05, JoltW = 45, JoltFor = 0.4,
	JoltOther = 0.008, TrembleAmp = 0.006, TrembleTau = 0.08,
	-- ...and the damage stage snaps in: 0.03 s, then a 0.25 overshoot ringing at 50 rad/s (Damage's snap)
	Snap = 0.03, Over = 0.25, OverTau = 0.05, OverW = 50, Settle = 0.45,
	-- stage 4's failing top creeps on (Blender (0, +0.015, -0.05) over 3.05 -> 3.65; kit axes: down, out the front)
	SagCreep = Vector3.new(0, -0.05, 0.015), SagTime = 0.6,
	HitPebbles = 2,                 -- BW_Pebble chips off every hit (+1 from stage 2)
	HitPuffs = 6, HitGrit = 10, SpallPuffs = 3,

	-- LOOSE ROCK (knock-offs, the burst, the collapse): ballistic on the debris' gravity
	Gravity = 35, Bounce = 0.25, Friction = 0.6, RestSpeed = 1.5,
	ChipHold = 1.4,                 -- a knock-off or pebble rests this long on the floor, then sinks into it
	RubbleHold = 2.5,               -- ...the collapse's rubble (the scuffs' own hold)
	SinkAway = 0.6,                 -- how long a resting piece takes to sink out of sight
	BigVol = 0.15,                  -- a piece this big (cubic studs) puffs dust where it first lands

	-- THE BREAK (WallDrop "Broken"): the struck slabs burst away from their hitter (Blender: toward the caster)
	BurstNear = 0.7, BurstNearV = { 2.5, 4.5 }, BurstFarV = { 0.8, 2.2 }, BurstUp = 0.8,
	BurstRadial = { 1, 3.5 }, BurstSpin = { 3, 9 },
	-- ...and the rest go on a wave (28 studs/s, KitData.Collapse.WaveSpeed when it is given), toppling whole:
	-- v = (away 0.4-1.4, up 0-0.8, side 0.8-2.0), w = (side 0.9-2.0 about the wall's line, +-0.3 yaw, +-0.4 roll)
	WaveSpeed = 28, WaveLag = 0.03,
	TopAway = { 0.4, 1.4 }, TopUp = { 0, 0.8 }, TopSide = { 0.8, 2.0 }, TopSpin = { 0.9, 2.0 }, TopYaw = 0.3, TopRoll = 0.4,
	BottomForward = 0.7,            -- a bottom slab falls forward (toward the enemy) this often; the courses above always
	HingeAcc = 19,                  -- a bottom slab hinges over its foot edge: theta'' = HingeAcc (0.15 + sin theta)
	HingeLand = 1.35,               -- ...and lands at this tilt (rad): its top meets the floor
	WedgeChance = 0.3, WedgeAt = 1.0, -- a bottom slab stays wedged in its slot this often, and crumbles at break + 1.0
	LandMin = 0.12,                 -- a toppling slab cannot land sooner (its rooted foot starts under the floor)
	CoarseKick = { 0.5, 1.5 }, CoarseSpin = { 2, 6 },
	BreakCloud = 8, BreakGrit = 16, BreakSkirt = 10, BreakHaze = 3, LandPuffs = 3, LandGrit = 6,

	-- THE SINK (Released / Empty / Lost): a 0.05 give, then down 10 over 0.9 s (smoothstep^1.15); SinkTime was live 0.35
	SinkGive = 0.05, SinkGiveTime = 0.1, SinkLead = 0.06, SinkTime = 0.9, SinkDepth = 10, SinkPow = 1.15,
	SinkTremble = 0.012, SinkPuffs = 2, HomePuffs = 8,

	-- THE GROUND (KitData.Ground; each piece optional): the slot's plates thrown aside, the rim heaved, a dark void
	SlotAt = 0.033, SlotMax = 12, SlotHold = 1.6,
	RimMax = 16, RimLinger = 1.2, RimLingerBroken = 2.2, RimSinkTime = 0.4,
	SlotHalf = Vector3.new(6.15, 0, 0.86),   -- the slot (12.3 x 1.72): the void under it
	Void = Color3.fromRGB(38, 28, 19),        -- Aftershock's VOID
	PlateTone = Color3.fromRGB(136, 117, 94), -- a plate's top when the floor gives no colour (Aftershock's PlateTop)
	RaiseDustPoints = 5, RaisePuffs = 3, RaiseGrit = 5,

	-- SCUFFS: the live TR_M1_Scuff decal
	Scuff = "rbxassetid://102375587925629",
	FaceScuff = 1.6, FaceScuffAlpha = 0.7,   -- one on each damaged slab, riding its crater ("subtle", the notes)
	GroundScuffMax = 6,                      -- under the toppled slabs, 1.3x the slab (3.5-5.0 across)
}
local W = TerraFX_Wall.Tuning

local DEFAULT_TURN = CFrame.Angles(0, math.pi, 0)   -- the M1 / Aftershock kits' measured turn; KitData.Turn wins
local IDENT = CFrame.new()
local STASH = CFrame.new(0, 5e4, 0)
local BIND = "SpellshotTerraWall"
local OPTIONAL = { "Brk", "Lit", "Dead" }
-- the budget's priorities per optional part, by what the piece is doing (higher shows first)
-- (2026-10-25, round 2) Crystal: an Epic wrap's crystal on the piece (ChargedRock CrystalsBaked), only where one exists
local PRIO = {
	Whole = { Lit = 60, Dead = 25, Crystal = 50 },
	Tpl = { Lit = 55, Brk = 30, Dead = 15, Crystal = 35 },
	Fly = { Brk = 70, Lit = 45, Dead = 12, Crystal = 40 },
	Rest = { Brk = 65, Lit = 40, Dead = 8, Crystal = 30 },
}
-- emitter kinds that emit from the host's rim (VFXLibrary: A = AFTERSHOCK_KIT, B = BOULDER_KIT)
local DISC = { AKick = true, ASkirt = true, AHaze = true, AFront = true, BRing = true, BSettle = true }

----------------------------------------------------------------------------------------------------
-- plumbing
----------------------------------------------------------------------------------------------------
local CR, VFX, Settings = nil, nil, nil
local function libs()
	if VFX then return end
	local ice = ReplicatedStorage:WaitForChild("IceMagic")
	VFX = require(ice:WaitForChild("VFXLibrary"))
	local ok, s = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	end)
	Settings = ok and s or {}
	local m = ice:FindFirstChild("ChargedRock")
	if m and m:IsA("ModuleScript") then
		local ok2, mod = pcall(require, m)
		CR = ok2 and mod or nil
	end
end

local function fxFolder()
	local name = (VFX and VFX.Config and VFX.Config.FXFolderName) or "IceMagicFX"
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[TerraFX_Wall] " .. msg)
end

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end
local function span(t, a, b)
	if b <= a then return t >= b and 1 or 0 end
	return clamp01((t - a) / (b - a))
end
local function outBack(u, s)
	u = math.clamp(u, 0, 1) - 1
	return 1 + (s + 1) * u * u * u + s * u * u
end
local function U(rng, r) return rng:NextNumber(r[1], r[2]) end
local function randUnit(rng)
	while true do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if v.Magnitude > 0.05 and v.Magnitude <= 1 then return v.Unit end
	end
end
local function vec(v) return typeof(v) == "Vector3" and v or Vector3.zero end
--- The mirror front to back (kit Z) of a rigid transform: M C M with M = diag(1, 1, -1).
local function mirror(c)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
	return CFrame.new(x, y, -z, r00, r01, -r02, r10, r11, -r12, -r20, -r21, r22)
end
--- A frame at `pos` whose UpVector is `n` (an emitter's Top, a decal's face).
local function upFrame(pos, n)
	n = n.Magnitude > 1e-4 and n.Unit or Vector3.yAxis
	local ref = math.abs(n.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	return CFrame.fromMatrix(pos, ref:Cross(n).Unit, n)
end
--- How far a box of half-size `half` at rotation `cf` hangs below its centre (a little under: the stone is inside it).
local function reachOf(cf, half)
	return 0.85 * (math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z)
end
local function trembleV(t, amp, seed)
	return Vector3.new(math.sin(t * 113 + seed) + 0.5 * math.sin(t * 171 + 2 * seed), math.sin(t * 131 + 1.7 + seed) * 0.6,
		math.sin(t * 97 + 3.1 + seed)) * amp
end
--- The stage snap: an ease in over Snap, then the overshoot ringing out (1 at rest).
local function snapCurve(a)
	if a <= 0 then return 0 end
	if a < W.Snap then return math.sin(0.5 * math.pi * a / W.Snap) end
	return 1 + W.Over * math.exp(-a / W.OverTau) * math.sin(W.OverW * (a - W.Snap))
end
--- TerraFX's scuff alpha: in over 0.05-0.14, held to 2.5, gone by 3.3 (charged_rock.scuff_alpha).
local function scuffAlpha(a)
	if a < 0.05 then return 0 end
	if a < 0.14 then return 0.95 * (a - 0.05) / 0.09 end
	if a < 2.5 then return 0.95 end
	return 0.95 * (1 - span(a, 2.5, 3.3))
end

-- the floor: a probe straight down from just above `pos`, looking through the FX folder, every player and any body with
-- a Humanoid (a dummy, the wall's own server body); `fallback` when there is none
local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude
local floorRayAt = 0
local function floorAt(pos, fallback)
	local now = os.clock()
	if now >= floorRayAt then
		floorRayAt = now + 0.5
		local list = { fxFolder() }
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character then list[#list + 1] = pl.Character end
		end
		floorRay.FilterDescendantsInstances = list
	end
	local from, dir = pos + Vector3.new(0, 2.5, 0), Vector3.new(0, -40, 0)
	for _ = 1, 3 do
		local hit = workspace:Raycast(from, dir, floorRay)
		if not hit then return fallback, nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit.Position.Y, hit end
		floorRay:AddToFilter(model)
	end
	return fallback, nil
end

----------------------------------------------------------------------------------------------------
-- the kit and its data, read once (re-read if the kit is re-imported; a missing kit is retried every 2 s)
----------------------------------------------------------------------------------------------------
local kitCache, kitTried = nil, -math.huge

local function findData()
	for _, folderName in ipairs({ "Spellshot", "IceMagic" }) do
		local f = ReplicatedStorage:FindFirstChild(folderName)
		local m = f and f:FindFirstChild(W.Data)
		if m and m:IsA("ModuleScript") then
			local ok, d = pcall(require, m)
			if ok and type(d) == "table" and type(d.Slabs) == "table" then return d end
		end
	end
	return nil
end

local function loadKit()
	if kitCache then
		if kitCache.Model.Parent then return kitCache end
		kitCache = nil
	end
	local now = os.clock()
	if now < kitTried + 2 then return nil end
	kitTried = now
	libs()
	if not CR then
		warnOnce("cr", "ReplicatedStorage.IceMagic.ChargedRock not found -- the old wall look stays")
		return nil
	end
	local data = findData()
	local folder = ReplicatedStorage:FindFirstChild(W.MeshFolder)
	local model = folder and folder:FindFirstChild(W.Kit)
	local origin = model and model:FindFirstChild(W.Origin, true)
	if not (data and origin and origin:IsA("BasePart")) then
		warnOnce("kit", ("%s.%s (with %s) or %s not found -- the old wall look stays"):format(W.MeshFolder, W.Kit, W.Origin, W.Data))
		return nil
	end
	local o = origin.CFrame
	-- a kit part's frame relative to the origin (kit axes) and its size, or nil
	local function rest(name)
		if type(name) ~= "string" then return nil, nil end
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then return o:ToObjectSpace(p.CFrame), p.Size end
		return nil, nil
	end
	local kit = { Model = model, Data = data, Turn = typeof(data.Turn) == "CFrame" and data.Turn or DEFAULT_TURN,
		Slabs = {}, Pebbles = {}, Slot = {}, Rim = {}, Tpl = nil }
	local tplData = type(data.Template) == "table" and data.Template or nil
	-- with no Template.Home the fine cut's frame is its pieces' box, unturned; the whole slabs are then unturned too, so
	-- the two agree (each slab's few tenths of a degree of tilt live in its baked mesh)
	local useTilt = tplData ~= nil and typeof(tplData.Home) == "CFrame"
	for i = 1, 12 do
		local d = type(data.Slabs[i]) == "table" and data.Slabs[i] or {}
		local name = type(d.Name) == "string" and d.Name or ("BW_Slab_%02d"):format(i)
		local r, size = rest(name)
		if not r then
			warnOnce("slab" .. i, ("'%s' not found in %s -- the old wall look stays"):format(name, W.Kit))
			return nil
		end
		local ks = { I = i, Name = name, Rest = r, Size = size, Data = d, Coarse = {} }
		ks.Course = type(d.Course) == "number" and math.clamp(math.floor(d.Course), 1, 3)
			or math.clamp(math.floor(r.Y / 2.8) + 1, 1, 3)
		ks.Frame = CFrame.new(r.Position) * ((useTilt and typeof(d.Home) == "CFrame") and d.Home.Rotation or IDENT)
		for _, c in ipairs(type(d.Coarse) == "table" and d.Coarse or {}) do
			if type(c) == "table" then
				local cr, csize = rest(c.Name)
				if cr then
					ks.Coarse[#ks.Coarse + 1] = { Name = c.Name, FromStone = r:Inverse() * cr, Vol = csize.X * csize.Y * csize.Z * 0.5 }
				end
			end
		end
		kit.Slabs[i] = ks
	end
	-- what each slab stands on: KitData's Under, or the course below overlapping it along the wall
	for _, ks in ipairs(kit.Slabs) do
		local under = {}
		if type(ks.Data.Under) == "table" then
			for _, j in ipairs(ks.Data.Under) do
				if kit.Slabs[j] then under[#under + 1] = kit.Slabs[j] end
			end
		else
			for _, o2 in ipairs(kit.Slabs) do
				if o2.Course == ks.Course - 1 and math.abs(o2.Rest.X - ks.Rest.X) < (o2.Size.X + ks.Size.X) / 2 - 0.05 then
					under[#under + 1] = o2
				end
			end
		end
		ks.Under = under
	end

	-- THE FINE CUT. Its frame (TF) is the box of its imported pieces (or Template.Home when the exporter gives one); each
	-- piece's stone frame in it (R) is what the stage tables move: a stage is a rigid motion of the whole piece in the
	-- template slab's frame, applied on the left (D[st] * R), so it moves the imported stone frame as it moves the cell.
	if tplData and type(tplData.Pieces) == "table" then
		local list = {}
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, e in ipairs(tplData.Pieces) do
			if type(e) == "table" then
				local r, size = rest(e.Name)
				if r then
					local h = size / 2
					lo, hi = lo:Min(r.Position - h), hi:Max(r.Position + h)
					local stages, prev = {}, IDENT
					for st = 1, 4 do
						local c = type(e.Stage) == "table" and e.Stage[st] or nil
						if typeof(c) == "CFrame" then prev = c end
						stages[st] = prev
					end
					local rel = nil
					if type(e.Release) == "table" and type(e.Release.Hit) == "number" then
						rel = { Hit = math.clamp(math.floor(e.Release.Hit), 1, 4), Kind = tostring(e.Release.Kind or "chip"),
							V = vec(e.Release.V), W = vec(e.Release.W) }
					end
					list[#list + 1] = { Name = e.Name, KitRest = r, Size = size, Sag = e.Sag == true, Stage = stages, Release = rel,
						Vol = type(e.Vol) == "number" and e.Vol or size.X * size.Y * size.Z * 0.5,
						Phase = type(e.Phase) == "number" and e.Phase or nil }
				end
			end
		end
		if #list > 0 then
			local TF = useTilt and tplData.Home or CFrame.new((lo + hi) / 2)
			local tsize = hi - lo
			local half = tsize / 2
			for _, E in ipairs(list) do E.R = TF:ToObjectSpace(E.KitRest) end
			-- the impact (the template's frame, on its FRONT face, +Z): Template.Impact read as the template's frame, or as
			-- the kit's (the demo slab where it stands), whichever lands inside the slab; else the first chips' middle
			local function inside(p)
				return math.abs(p.X) <= half.X + 0.3 and math.abs(p.Y) <= half.Y + 0.3 and math.abs(p.Z) <= half.Z + 0.3
			end
			local imp = nil
			if typeof(tplData.Impact) == "Vector3" then
				if inside(tplData.Impact) then
					imp = tplData.Impact
				elseif inside(TF:PointToObjectSpace(tplData.Impact)) then
					imp = TF:PointToObjectSpace(tplData.Impact)
				end
			end
			if not imp then
				local sum, n = Vector3.zero, 0
				for _, E in ipairs(list) do
					if E.Release and E.Release.Hit == 1 then
						sum += E.R.Position
						n += 1
					end
				end
				imp = n > 0 and Vector3.new(sum.X / n, sum.Y / n, half.Z) or Vector3.new(0, 0, half.Z)
			end
			-- A HIT FROM BEHIND mirrors the stage table front to back (the contract). Its knock-offs come off the BACK face:
			-- each front knock-off's release goes to the piece nearest its mirror image, velocities mirrored (V by M, the
			-- spin as the pseudovector it is, -M W) -- so a chip still leaves the face that was hit
			local order = {}
			for _, E in ipairs(list) do
				if E.Release then order[#order + 1] = E end
			end
			table.sort(order, function(a, b) return a.Release.Hit < b.Release.Hit end)
			local taken = {}
			for _, E in ipairs(order) do
				local target = Vector3.new(E.R.X, E.R.Y, -E.R.Z)
				local best, bd = nil, math.huge
				for _, Q in ipairs(list) do
					if not taken[Q] then
						local d = (Q.R.Position - target).Magnitude
						if d < bd then best, bd = Q, d end
					end
				end
				if best then
					taken[best] = true
					local v, w = E.Release.V, E.Release.W
					best.MRelease = { Hit = E.Release.Hit, Kind = E.Release.Kind, V = Vector3.new(v.X, v.Y, -v.Z),
						W = Vector3.new(-w.X, -w.Y, w.Z) }
				end
			end
			kit.Tpl = { Pieces = list, Size = tsize, Impact = imp }
		end
	end
	if not kit.Tpl then warnOnce("tpl", "no fine cut (KitData.Template / BW_T_nn) -- hits flare and jolt but do not crack") end

	for i = 1, 64 do
		local n = ("BW_Pebble_%02d"):format(i)
		if not model:FindFirstChild(n, true) then break end
		kit.Pebbles[#kit.Pebbles + 1] = n
	end

	-- THE GROUND (optional): the slot's plates (Name, Rel, V, W) and the rim (Name, Rel, and Lift / Roll / At / Sag when
	-- the exporter gives them -- derived from the Blender build's formulas otherwise), each thinned evenly to its cap
	local g = type(data.Ground) == "table" and data.Ground or {}
	local function thinned(src, cap)
		local out = {}
		if type(src) ~= "table" or #src == 0 then return out end
		local stepBy = math.max(1, #src / cap)
		local k = 1
		while k <= #src + 1e-6 and #out < cap do
			out[#out + 1] = src[math.floor(k)]
			k += stepBy
		end
		return out
	end
	for _, e in ipairs(thinned(g.Slot, W.SlotMax)) do
		if type(e) == "table" then
			local r, size = rest(e.Name)
			if r then kit.Slot[#kit.Slot + 1] = { Name = e.Name, Rest = r, Size = size, V = vec(e.V), W = vec(e.W) } end
		end
	end
	for _, e in ipairs(thinned(g.Rim, W.RimMax)) do
		if type(e) == "table" then
			local r, size = rest(e.Name)
			if r then
				local d = math.abs(r.Z)
				local k = clamp01((d - W.SlotHalf.Z) / 1.9)
				kit.Rim[#kit.Rim + 1] = { Name = e.Name, Rest = r, Size = size,
					Lift = type(e.Lift) == "number" and e.Lift or 0.27 * (1 - 0.8 * k),
					Roll = type(e.Roll) == "number" and e.Roll or 0,
					RollK = type(e.Roll) ~= "number" and math.rad(4) * (1 - k) or 0,
					At = type(e.At) == "number" and e.At or 0.11 + (d - W.SlotHalf.Z) * 0.02,
					Sag = type(e.Sag) == "number" and e.Sag or 0.17 * (1 - 0.7 * k) }
			end
		end
	end
	-- (2026-10-25, round 2) the wrap ladder's Stone and crystals (ChargedRock.KitHint): the ground's plates are the floor,
	-- not the wall's stone (no grey copy is built for them; Raise clones them plain); a stone's strata height is over
	-- BW_Origin; its crystal grows out of a face the wall shows -- the front (kit +Z) or the back, whichever half of its
	-- slab it is in (either for a whole slab), and the top of the top course
	if type(CR.KitHint) == "function" then
		local ground = { [W.Origin] = true }
		for _, list in ipairs({ g.Slot, g.Rim }) do
			if type(list) == "table" then
				for _, e in ipairs(list) do
					if type(e) == "table" and type(e.Name) == "string" then ground[e.Name] = true end
				end
			end
		end
		local mid, topY = {}, -math.huge     -- [name] = the kit-Z of the middle of the slab the piece is cut from
		for _, ks in ipairs(kit.Slabs) do
			topY = math.max(topY, ks.Rest.Y + ks.Size.Y / 2)
			mid[ks.Name] = ks.Rest.Z
			for _, c in ipairs(ks.Coarse) do mid[c.Name] = ks.Rest.Z end
		end
		if kit.Tpl then
			local z = 0
			for _, E in ipairs(kit.Tpl.Pieces) do z += E.KitRest.Z end
			z /= #kit.Tpl.Pieces
			for _, E in ipairs(kit.Tpl.Pieces) do mid[E.Name] = z end
		end
		local front, back = o:VectorToWorldSpace(Vector3.zAxis), o:VectorToWorldSpace(-Vector3.zAxis)
		local up = o:VectorToWorldSpace(Vector3.yAxis)
		pcall(CR.KitHint, model, {
			Skip = ground,
			Height = function(stone) return o:PointToObjectSpace(stone.Position).Y end,
			Faces = function(stone)
				local r = o:ToObjectSpace(stone.CFrame)
				local s = stone.Size
				local dz = r.Z - (mid[stone.Name] or 0)
				local out = {}
				if dz > -0.2 then out[#out + 1] = front end
				if dz < 0.2 then out[#out + 1] = back end
				local top = r.Y + 0.5 * (math.abs(r.RightVector.Y) * s.X + math.abs(r.UpVector.Y) * s.Y + math.abs(r.LookVector.Y) * s.Z)
				if top >= topY - 0.45 then out[#out + 1] = up end
				return out
			end,
		})
	end
	kitCache = kit
	return kit
end

--- The kit and its data are both in the place (TerraFX keeps the old look otherwise).
function TerraFX_Wall.Available()
	return loadKit() ~= nil
end

----------------------------------------------------------------------------------------------------
-- one wall
----------------------------------------------------------------------------------------------------
local walls = {}                       -- [owner character] = the wall being drawn
local moveList, moveCFs = {}, {}       -- this frame's one BulkMoveTo, every wall
local bound = false
local stepAll

local function fxTime(fx, ts)
	return ((ts or workspace:GetServerTimeNow()) - fx.T0) * VFX.ShotTimeScale()
end

local function ensureBound()
	if bound then return end
	bound = true
	-- after CastPose (Character + 1) and beside TerraFX's own step (Character + 2)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Character.Value + 2, function() stepAll() end)
end

--- `count` particles of VFXLibrary's `lib` ("A" Aftershock / "B" Boulder Shot) preset `kind` at `cf` (its Up is the
--- emission's Top; a Disc kind from the host's rim, `radius` across) -- TerraFX's asBurst, on this wall's own host.
local function burst(fx, lib, kind, cf, count, scale, radius)
	local h = fx.Host
	if not (h and h.Parent) then return end
	h.CFrame = cf
	if radius then h.Size = Vector3.new(radius * 2, 0.2, radius * 2) end
	scale = math.max(0.1, math.floor((scale or 1) * 10 + 0.5) / 10)
	local key = lib .. kind .. "@" .. scale
	-- (2026-10-25) a wrap's Dust (SkinCatalog Dust) recolours the kind's Default dust roles, its sequence kept
	-- (ChargedRock.DustColor). fx.Emitters is this cast's own; the wrap's key in the emitter's is belt and braces.
	local dw = fx.Wrap and fx.Wrap.Skin.Dust and fx.Wrap
	if dw then key ..= "#" .. dw.Key end
	local pe = fx.Emitters[key]
	if not pe then
		local fn = lib == "A" and VFX.AftershockBurst or VFX.BoulderBurst
		local cs = dw and CR.DustColor(dw, lib, kind)
		local ok, made = pcall(fn, DISC[lib .. kind] and h or fx.Point, kind, 0, fx.Thin, cs and { Color = cs } or nil)
		if not (ok and made) then return end
		pe = made
		pe.Rate = 0
		if scale ~= 1 then
			local keys = {}
			for i, kp in ipairs(pe.Size.Keypoints) do
				keys[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale)
			end
			pe.Size = NumberSequence.new(keys)
			pe.Speed = NumberRange.new(pe.Speed.Min * scale, pe.Speed.Max * scale)
		end
		pe.TimeScale = VFX.ShotTimeScale()
		fx.Emitters[key] = pe
	end
	local density = (Settings.EffectDensity or 1) * ((fx.Thin and Settings.ThinEnemyVFX) and 0.5 or 1)
	local n = math.floor(count * density + 0.5)
	if n > 0 then pe:Emit(n) end
	-- (2026-10-25) a wrap's added Layers (Rare+): each layer's Share.Wall of this burst's own count, from TerraWrap's
	-- pooled hosts at `cf` (the raw count: TerraWrap applies Graphics Quality and Reduce Enemy VFX itself, once)
	local sk = fx.Wrap and fx.Wrap.Skin
	if sk and sk.Layers then
		local TW = CR.TerraWrap()
		if TW then pcall(TW.LayerBurst, sk, "Wall", count, nil, cf, fx.Thin) end
	end
end

--- A scuff decal on a thin inert part (its Top), hidden until placed.
local function newScuff(fx, size, kind)
	local p = Instance.new("Part")
	p.Name = "TerraWallScuff"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Transparency = 1
	p.Size = Vector3.new(size, 0.05, size)
	p.CFrame = STASH
	local d = Instance.new("Decal")
	d.Texture = W.Scuff
	d.Face = Enum.NormalId.Top
	d.Transparency = 1
	-- (2026-10-25) a wrap's Scuff (SkinCatalog Scuff) tints the print: Decal.Color3 multiplies the texture
	local tone = fx.Wrap and fx.Wrap.Skin.Scuff
	if typeof(tone) == "Color3" then d.Color3 = tone end
	d.Parent = p
	p.Parent = fxFolder()
	local sc = { Part = p, Decal = d, Kind = kind, Alpha = 0 }
	fx.Scuffs[#fx.Scuffs + 1] = sc
	return sc
end

local function dropScuff(fx, sc)
	if not sc then return end
	pcall(function() sc.Part:Destroy() end)
	local i = table.find(fx.Scuffs, sc)
	if i then table.remove(fx.Scuffs, i) end
end

local function setScuffAlpha(sc, alpha)
	alpha = math.floor(alpha * 50 + 0.5) / 50
	if sc.Alpha ~= alpha then
		sc.Alpha = alpha
		sc.Decal.Transparency = 1 - alpha
	end
end

--- Stones on screen, plus the wall's other visible parts (scuffs, the void).
local function stoneCount(fx)
	local n = #fx.Scuffs + (fx.Void and 1 or 0)
	for _, s in ipairs(fx.Slabs) do
		if s.Whole then n += 1 end
		if s.Tpl then
			for _, tp in ipairs(s.Tpl.Pieces) do
				if tp.Piece then n += 1 end
			end
		end
	end
	for _, b in ipairs(fx.Loose) do
		if b.Piece then n += 1 end
	end
	for _, r in ipairs(fx.Rim) do
		if r.Piece then n += 1 end
	end
	return n
end

--- THE BUDGET: every optional part (fracture faces, lit and dead seams) shown by priority until the wall's parts reach
--- MaxParts. Run whenever the set of pieces changes. A part it shows snaps to its stone (ChargedRock.Show).
local function rebalance(fx)
	local cand = {}
	local function add(piece, prio, bonus)
		for _, kind in ipairs(OPTIONAL) do
			if piece[kind] and prio[kind] then cand[#cand + 1] = { piece, kind, prio[kind] + bonus } end
		end
		if piece.Crystal and prio.Crystal then cand[#cand + 1] = { piece, "Crystal", prio.Crystal + bonus } end
	end
	for _, s in ipairs(fx.Slabs) do
		if s.Whole then add(s.Whole, PRIO.Whole, 0) end
		if s.Tpl then
			for _, tp in ipairs(s.Tpl.Pieces) do
				if tp.Piece then add(tp.Piece, PRIO.Tpl, tp.Near * 10) end
			end
		end
	end
	for _, b in ipairs(fx.Loose) do
		if b.Piece then add(b.Piece, b.State == "fly" and PRIO.Fly or PRIO.Rest, math.min(b.Vol or 0, 1) * 5) end
	end
	table.sort(cand, function(a, b) return a[3] > b[3] end)
	local room = W.MaxParts - stoneCount(fx)
	for i, c in ipairs(cand) do
		local piece, kind = c[1], c[2]
		local on = i <= room
		local part = piece[kind]
		local was = not piece.Off[part]
		CR.Show(piece, kind, on)
		if on and not was then part.CFrame = piece.Stone.CFrame * piece.Rel[part] end
	end
end

--- Room for `need` more stones: resting rubble goes first (smallest first). False if there is still none.
local function makeRoom(fx, need)
	local free = W.MaxParts - stoneCount(fx)
	if free >= need then return true end
	local resting = {}
	for _, b in ipairs(fx.Loose) do
		if b.Piece and (b.State == "rest" or b.State == "sink") then resting[#resting + 1] = b end
	end
	table.sort(resting, function(a, b) return (a.Vol or 0) < (b.Vol or 0) end)
	for _, b in ipairs(resting) do
		if free >= need then break end
		CR.Release(b.Piece)
		b.Piece = nil
		free += 1
	end
	return free >= need
end

--- A loose piece, flown from `cf` (the stone's world frame) at world `v` / `w`, placed this frame.
local function addLoose(fx, piece, cf, v, w, kind, t)
	local b = { Piece = piece, CF = cf, V = v, W = w, Kind = kind, Half = piece.Stone.Size / 2, State = "fly", Born = t,
		Hold = W.RubbleHold, Vol = 0, Mode = "none", LevelAt = t, Sustain = 0, HitAt = -math.huge, LandMin = 0, Sunk = 0 }
	-- a piece that starts under the floor (the bottom course is rooted 0.5 into its slot) eases up to it rather than
	-- popping: its floor starts that far down and comes back over 0.4 s
	local fy = floorAt(cf.Position, fx.FloorY)
	b.FloorY, b.ProbeX, b.ProbeZ = fy, cf.Position.X, cf.Position.Z
	b.Sunk = math.min(0, cf.Position.Y - reachOf(cf, b.Half) - fy)
	fx.Loose[#fx.Loose + 1] = b
	CR.Place(piece, cf, moveList, moveCFs)
	return b
end

-- (2026-10-19, audit P5B-05) Reduce Flashing: a broken piece's level and every hit flare at half (the Tomb halves its
-- levels the same way, TerraFX_Tomb); the standing slabs' damage-stage glow is left whole (it is the wall's health read)
local function flareK()
	return (CR and CR.Calm and CR.Calm()) and 0.5 or 1
end

local function looseLevel(b, t)
	local L = 0
	if b.Mode == "at" then
		L = CR.AtBreak(b.Sustain, t - b.LevelAt)
	elseif b.Mode == "after" then
		L = CR.AfterBreak(t - b.LevelAt)
	end
	return (L + CR.AfterHit(t - b.HitAt)) * flareK()
end

----------------------------------------------------------------------------------------------------
-- the standing wall
----------------------------------------------------------------------------------------------------
local function riseY(s, t)
	local start = W.RiseAt + W.RiseSpread * math.abs(s.K.Rest.X) + W.CourseLag * (3 - s.K.Course)
	if t < start then return -W.RiseHidden end
	local u = (t - start) / W.RiseTime
	if u >= 1 then return 0 end
	return -W.RiseDepth * (1 - outBack(u, W.RiseOver))
end

local function sinkY(a)
	if a < 0 then return 0 end
	local give = a < W.SinkGiveTime and W.SinkGive * math.sin(math.pi * a / W.SinkGiveTime) or 0
	return give - W.SinkDepth * smooth((a - W.SinkLead) / W.SinkTime) ^ W.SinkPow
end

--- A standing slab's offset in the kit frame at `t`: the raise, the sink, its own jolt and the wall's tremble.
local function slabOffset(fx, s, t)
	local x, y, z = 0, riseY(s, t), 0
	if fx.SinkAt then
		local a = t - fx.SinkAt
		y += sinkY(a)
		if (a >= 0 and a < 0.1) or (a > 0.8 * W.SinkTime and a < W.SinkLead + W.SinkTime + 0.2) then
			local tr = trembleV(t, W.SinkTremble, s.K.I)
			x, y, z = x + tr.X, y + tr.Y, z + tr.Z
		end
	end
	local a = t - s.JoltAt
	if a >= 0 and a < W.JoltFor then
		z += s.JoltAmp * s.JoltDir * math.exp(-a / W.JoltTau) * math.sin(W.JoltW * a)
	end
	local b = t - fx.HitAt
	if b >= 0 and b < W.JoltFor and s.JoltAt ~= fx.HitAt then
		z += W.JoltOther * fx.HitDir * math.exp(-b / W.JoltTau) * math.sin(W.JoltW * b)
		local tr = trembleV(b, W.TrembleAmp * math.exp(-b / W.TrembleTau), s.K.I)
		x, y, z = x + tr.X, y + tr.Y, z + tr.Z
	end
	return Vector3.new(x, y, z)
end

--- A fine-cut piece's stage motion D at `t` (the template's frame; mirrored for a hit from behind): the snap from the
--- last stage to this one, and stage 4's creep.
local function stageD(s, E, t)
	local st = s.Stage
	if st <= 0 then return IDENT end
	local a = t - s.StageAt
	local cur = E.Stage[st]
	local D = cur
	if a < W.Snap + W.Settle then
		local prev = s.PrevStage > 0 and E.Stage[s.PrevStage] or IDENT
		local f = snapCurve(a)
		D = CFrame.new(prev.Position:Lerp(cur.Position, f)) * prev.Rotation:Lerp(cur.Rotation, math.min(f, 1))
	end
	if st >= 4 and E.Sag then D = CFrame.new(W.SagCreep * span(a, 0, W.SagTime)) * D end
	if s.Tpl.Mirror then D = mirror(D) end
	return D
end

--- ...scaled onto the struck slab (positions per axis; the piece itself is resized by ChargedRock.Scale).
local function scaled(c, k)
	return CFrame.new(c.Position * k) * c.Rotation
end

local function tplPose(s, tp, t)
	return scaled(stageD(s, tp.E, t) * tp.E.R, s.Tpl.K)
end

local function slabLevel(s, t)
	local SL = CR.STAGE_LEVEL
	local L = SL[s.Stage + 1] or 0
	if s.Stage > 0 and s.Tpl then
		local a = t - s.StageAt
		if a < W.Snap then
			local p = SL[s.PrevStage + 1] or 0
			L = p + (L - p) * clamp01(a / W.Snap)
		end
	end
	return L + CR.AfterHit(t - s.HitAt) * flareK()
end

local function placeStanding(fx, s, t)
	local off = slabOffset(fx, s, t)
	local tpl = s.Tpl
	local animating = tpl and (t - s.StageAt) < math.max(W.Snap + W.Settle, (s.Stage >= 4) and W.SagTime or 0)
	if animating or off ~= s.LastOff then
		s.LastOff = off
		local base = fx.K * CFrame.new(off)
		if s.Whole then CR.Place(s.Whole, base * s.K.Rest, moveList, moveCFs) end
		if tpl then
			local B = base * s.K.Frame
			for _, tp in ipairs(tpl.Pieces) do
				if tp.Piece then CR.Place(tp.Piece, B * tplPose(s, tp, t), moveList, moveCFs) end
			end
			local sc = tpl.Scuff
			if sc and sc.Host then
				local n = #moveList + 1
				moveList[n], moveCFs[n] = sc.Part, B * scaled(stageD(s, sc.Host.E, t) * sc.T, tpl.K)
			end
		end
	end
	if tpl and tpl.Scuff then setScuffAlpha(tpl.Scuff, W.FaceScuffAlpha * span(t - tpl.FirstAt, 0.05, 0.14)) end
	local lvl = slabLevel(s, t)
	if s.Whole then CR.SetLevel(s.Whole, lvl, t) end
	if tpl then
		for _, tp in ipairs(tpl.Pieces) do
			if tp.Piece then CR.SetLevel(tp.Piece, lvl, t) end
		end
	end
end

--- The slab back to its whole mesh: its fine cut released (the 4th-slab rule, or the end of the wall).
local function dropTemplate(fx, s)
	local tpl = s.Tpl
	if not tpl then return end
	for _, tp in ipairs(tpl.Pieces) do
		if tp.Piece then
			CR.Release(tp.Piece)
			tp.Piece = nil
		end
	end
	dropScuff(fx, tpl.Scuff)
	s.Tpl = nil
end

local function revert(fx, s)
	dropTemplate(fx, s)
	s.Stage, s.PrevStage = 0, 0
	s.Whole = CR.Clone(fx.Kit.Model, s.K.Name, fx.Wrap)
	s.LastOff = nil
end

--- The fine cut onto slab `s`, scaled to it, mirrored for a hit from behind; its whole mesh released. False (and the slab
--- stays whole) when the budget cannot take its stones.
local function fitTemplate(fx, s, back)
	local kt = fx.Kit.Tpl
	if not kt then return false end
	if not makeRoom(fx, #kt.Pieces - (s.Whole and 1 or 0)) then return false end
	local k = s.K.Size / kt.Size
	local imp = back and Vector3.new(kt.Impact.X, kt.Impact.Y, -kt.Impact.Z) or kt.Impact
	local tpl = { Pieces = {}, K = k, Mirror = back, Imp = imp, FirstAt = s.StageAt }
	local host, hostD = nil, math.huge
	for _, E in ipairs(kt.Pieces) do
		local piece = CR.Clone(fx.Kit.Model, E.Name, fx.Wrap)
		if piece then
			if E.Phase then piece.Phase = E.Phase end
			CR.Scale(piece, k)
			local d = ((E.R.Position - imp) * k).Magnitude
			local tp = { E = E, Piece = piece, Near = clamp01(1 - d / 1.3) }
			tpl.Pieces[#tpl.Pieces + 1] = tp
			-- the face scuff rides the piece nearest the impact that is never knocked off
			if not (back and E.MRelease or E.Release) and d < hostD then host, hostD = tp, d end
		end
	end
	if s.Whole then
		CR.Release(s.Whole)
		s.Whole = nil
	end
	s.Tpl = tpl
	s.LastOff = nil
	if host then
		local n = Vector3.new(0, 0, back and -1 or 1)
		local sc = newScuff(fx, W.FaceScuff, "face")
		sc.Host = host
		sc.T = upFrame(imp + n * 0.03, n) * CFrame.Angles(0, fx.Rng:NextNumber(0, 2 * math.pi), 0)
		tpl.Scuff = sc
	end
	return true
end

--- A knock-off: piece `tp` of slab `s` let go at its pose now, at its release's velocity (the template's frame).
local function knockOff(fx, s, tp, rel, th, t, late)
	local piece = tp.Piece
	tp.Piece = nil
	if not piece then return end
	if late then
		CR.Release(piece)
		return
	end
	local B = fx.K * CFrame.new(slabOffset(fx, s, t)) * s.K.Frame
	local R = B.Rotation
	local b = addLoose(fx, piece, B * tplPose(s, tp, t), R * rel.V, R * rel.W, "chip", t)
	b.Mode, b.Sustain, b.LevelAt, b.HitAt = "at", CR.STAGE_LEVEL[s.Stage + 1] or 0, th, th
	b.Vol, b.Hold, b.LandMin = tp.E.Vol, W.ChipHold, 0.05
end

local function throwPebbles(fx, point, out, n, t)
	local kit = fx.Kit
	if #kit.Pebbles == 0 or n <= 0 or not makeRoom(fx, n) then return end
	local rng = fx.Rng
	for _ = 1, n do
		local piece = CR.Clone(kit.Model, kit.Pebbles[rng:NextInteger(1, #kit.Pebbles)], fx.Wrap)
		if piece then
			local side = randUnit(rng)
			local cf = CFrame.new(point + out * 0.15) * CFrame.fromAxisAngle(randUnit(rng), rng:NextNumber(0, 2 * math.pi))
			local v = out * rng:NextNumber(3, 7) + Vector3.new(0, rng:NextNumber(0.5, 2.5), 0) + side * rng:NextNumber(0.5, 1.5)
			local b = addLoose(fx, piece, cf, v, randUnit(rng) * rng:NextNumber(8, 16), "pebble", t)
			b.Hold, b.Vol = W.ChipHold, 0
		end
	end
end

----------------------------------------------------------------------------------------------------
-- the collapse
----------------------------------------------------------------------------------------------------
local function groundScuff(fx, pos, width, t)
	local count = 0
	for _, sc in ipairs(fx.Scuffs) do
		if sc.Kind == "ground" then count += 1 end
	end
	if count >= W.GroundScuffMax then return end
	local y, hit = floorAt(pos, fx.FloorY)
	local n = hit and hit.Normal or Vector3.yAxis
	local sc = newScuff(fx, math.clamp(1.3 * width, 3.5, 5.0), "ground")
	sc.At = t
	local cf = upFrame(Vector3.new(pos.X, y + 0.03, pos.Z), n) * CFrame.Angles(0, fx.Rng:NextNumber(0, 2 * math.pi), 0)
	local i = #moveList + 1
	moveList[i], moveCFs[i] = sc.Part, cf
end

--- A falling slab meets the floor: its coarse cut is let go there (v + w x r, a kick, a spin), or -- with no room in the
--- budget -- it stays whole and bounces to rest. Both take the break's flare and ember from now.
local function landSlab(fx, b, t)
	local s = b.Slab
	b.Landed, b.Kind = true, "whole"
	b.Mode, b.LevelAt = "after", t
	local p0 = b.CF.Position
	if not fx.Late then
		local y = b.FloorY or fx.FloorY
		local size = s.K.Size
		burst(fx, "A", "Landing", CFrame.new(p0.X, y + 0.2, p0.Z), W.LandPuffs, math.clamp(size.X / 3, 0.6, 1.6))
		burst(fx, "A", "Grit", CFrame.new(p0.X, y + 0.2, p0.Z), W.LandGrit, 1)
		groundScuff(fx, p0, size.X, t)
	end
	local coarse = s.K.Coarse
	if #coarse == 0 or not makeRoom(fx, #coarse - 1) then return end
	local rng = fx.Rng
	local stoneCF = b.CF
	for _, c in ipairs(coarse) do
		local piece = CR.Clone(fx.Kit.Model, c.Name, fx.Wrap)
		if piece then
			local cf = stoneCF * c.FromStone
			local r = cf.Position - p0
			local out = Vector3.new(r.X, 0, r.Z)
			out = out.Magnitude > 1e-3 and out.Unit or Vector3.zero
			local v = Vector3.new(b.V.X * 0.5, math.abs(b.V.Y) * W.Bounce, b.V.Z * 0.5) + b.W:Cross(r) * 0.3
				+ out * U(rng, W.CoarseKick) + Vector3.new(0, U(rng, W.CoarseKick), 0)
			local nb = addLoose(fx, piece, cf, v, b.W * 0.5 + randUnit(rng) * U(rng, W.CoarseSpin), "coarse", t)
			nb.Mode, nb.LevelAt, nb.Vol, nb.LandMin = "after", t, c.Vol, 0.05
		end
	end
	CR.Release(b.Piece)
	b.Piece = nil
	rebalance(fx)
end

--- An unhit slab let go on the wave: it topples WHOLE -- a bottom slab hinging over its foot edge, the courses above
--- flying -- and breaks where it lands.
local function topple(fx, s, t)
	if s.Down then return end
	s.Down = true
	if not s.Whole then return end
	local rng, ks = fx.Rng, s.K
	local off = slabOffset(fx, s, t)
	local cf = fx.K * CFrame.new(off) * ks.Rest
	local side = (ks.Course >= 2 or rng:NextNumber() < W.BottomForward) and 1 or -1
	local away = (ks.Rest.X - fx.BreakCentre.X) >= 0 and 1 or -1
	local vK = Vector3.new(away * U(rng, W.TopAway), U(rng, W.TopUp), side * U(rng, W.TopSide))
	local wK = Vector3.new(side * U(rng, W.TopSpin), rng:NextNumber(-W.TopYaw, W.TopYaw), rng:NextNumber(-W.TopRoll, W.TopRoll))
	local R = fx.K.Rotation
	local b = addLoose(fx, s.Whole, cf, R * vK, R * wK, "slab", t)
	b.Slab, b.LandMin, b.Vol = s, W.LandMin, ks.Size.X * ks.Size.Y * ks.Size.Z
	s.Whole = nil
	if ks.Course == 1 then
		local c = ks.Rest.Position + off
		b.Hinge = { H = fx.K * Vector3.new(c.X, 0, c.Z + side * ks.Size.Z / 2), A = R * (Vector3.xAxis * side), Theta = 0,
			Omega = math.abs(wK.X), CF0 = cf }
	end
	if not fx.Late then
		burst(fx, "A", "Kick", CFrame.new(fx.K * Vector3.new(ks.Rest.X, 0.15, side * W.SlotHalf.Z)), 2, 1, 0.5)
	end
end

--- A bottom slab wedged in its slot crumbles where it stands.
local function crumble(fx, s, t)
	if s.Down then return end
	s.Down = true
	if not s.Whole then return end
	local cf = fx.K * CFrame.new(slabOffset(fx, s, t)) * s.K.Rest
	local b = addLoose(fx, s.Whole, cf, Vector3.zero, Vector3.zero, "slab", t)
	b.Slab, b.Vol = s, s.K.Size.X * s.K.Size.Y * s.K.Size.Z
	s.Whole = nil
	landSlab(fx, b, t)
	if b.Piece then
		b.State, b.RestAt = "rest", t
	end
end

--- A damaged slab bursts: every piece still on it let go AWAY from its hitter (Blender: toward the caster), the ones
--- near the impact fastest, spread radially from it.
local function burstSlab(fx, s, t)
	local tpl = s.Tpl
	local rng = fx.Rng
	local B = fx.K * CFrame.new(slabOffset(fx, s, t)) * s.K.Frame
	local R = B.Rotation
	local mz = tpl.Mirror and -1 or 1
	for _, tp in ipairs(tpl.Pieces) do
		local piece = tp.Piece
		if piece then
			tp.Piece = nil
			local rel = (tp.E.R.Position - tpl.Imp) * tpl.K
			local near = rel.Magnitude < W.BurstNear
			local radial = Vector3.new(rel.X, rel.Y, 0)
			radial = radial.Magnitude > 1e-3 and radial.Unit or Vector3.zero
			local vK = Vector3.new(0, rng:NextNumber(-W.BurstUp, W.BurstUp), -mz * U(rng, near and W.BurstNearV or W.BurstFarV))
				+ radial * U(rng, W.BurstRadial)
			local b = addLoose(fx, piece, B * tplPose(s, tp, t), R * vK, R * (randUnit(rng) * U(rng, W.BurstSpin)), "burst", t)
			b.Mode, b.Sustain, b.LevelAt, b.HitAt = "at", CR.STAGE_LEVEL[s.Stage + 1] or 0, t, s.HitAt
			b.Vol, b.LandMin = tp.E.Vol, 0.06
		end
	end
	dropScuff(fx, tpl.Scuff)
	s.Tpl = nil
	s.Down = true
end

----------------------------------------------------------------------------------------------------
-- stepping
----------------------------------------------------------------------------------------------------
local function stepBallistic(fx, b, t, dt)
	b.V -= Vector3.new(0, W.Gravity * dt, 0)
	local pos = b.CF.Position + b.V * dt
	local rot = b.CF.Rotation
	local wm = b.W.Magnitude
	if wm > 1e-3 then rot = CFrame.fromAxisAngle(b.W / wm, wm * dt) * rot end
	if math.abs(pos.X - b.ProbeX) + math.abs(pos.Z - b.ProbeZ) > 1 then
		b.FloorY = floorAt(pos, fx.FloorY)
		b.ProbeX, b.ProbeZ = pos.X, pos.Z
	end
	local floorY = b.FloorY + b.Sunk * (1 - span(t - b.Born, 0, 0.4))
	local reach = reachOf(rot, b.Half)
	if pos.Y - reach <= floorY and b.V.Y < 0 and t - b.Born >= b.LandMin then
		pos = Vector3.new(pos.X, floorY + reach, pos.Z)
		b.CF = CFrame.new(pos) * rot
		if b.Kind == "slab" then
			landSlab(fx, b, t)
			if not b.Piece then return end
		elseif not b.Landed then
			b.Landed = true
			if (b.Vol or 0) >= W.BigVol and not fx.Late and fx.Puffs < 3 then
				fx.Puffs += 1
				burst(fx, "A", "Landing", CFrame.new(pos.X, floorY + 0.15, pos.Z), 1, 0.6)
			end
		end
		if -b.V.Y > W.RestSpeed then
			b.V = Vector3.new(b.V.X * W.Friction, -b.V.Y * W.Bounce, b.V.Z * W.Friction)
			b.W *= 0.5
		else
			b.V, b.W = Vector3.zero, Vector3.zero
			b.State, b.RestAt = "rest", t
		end
		return
	end
	b.CF = CFrame.new(pos) * rot
end

local function stepHinge(fx, b, t, dt)
	local h = b.Hinge
	h.Omega += W.HingeAcc * (0.15 + math.sin(h.Theta)) * dt
	h.Theta = math.min(h.Theta + h.Omega * dt, W.HingeLand)
	b.CF = CFrame.new(h.H) * CFrame.fromAxisAngle(h.A, h.Theta) * CFrame.new(-h.H) * h.CF0
	if h.Theta >= W.HingeLand then
		b.V = (h.A * h.Omega):Cross(b.CF.Position - h.H)
		b.W = h.A * h.Omega
		b.Hinge = nil
		landSlab(fx, b, t)
	end
end

local function stepLoose(fx, t, dt)
	local i = 1
	while i <= #fx.Loose do
		local b = fx.Loose[i]
		local moved = false
		if b.Piece and b.State == "hold" then
			if t >= b.FlyAt then
				b.State, b.Born = "fly", t
			end
		end
		if b.Piece and b.State == "fly" then
			moved = true
			if b.Hinge then stepHinge(fx, b, t, dt) else stepBallistic(fx, b, t, dt) end
		elseif b.Piece and b.State == "rest" then
			if t - b.RestAt >= b.Hold then
				b.State, b.SinkAt, b.SinkFrom = "sink", t, b.CF
				b.SinkBy = reachOf(b.CF, b.Half) * 2 + 0.2
			end
		elseif b.Piece and b.State == "sink" then
			local u = (t - b.SinkAt) / W.SinkAway
			if u >= 1 then
				CR.Release(b.Piece)
				b.Piece = nil
			else
				b.CF = b.SinkFrom - Vector3.new(0, b.SinkBy * u * u, 0)
				moved = true
			end
		end
		if b.Piece then
			if moved then CR.Place(b.Piece, b.CF, moveList, moveCFs) end
			CR.SetLevel(b.Piece, looseLevel(b, t), t)
			i += 1
		else
			table.remove(fx.Loose, i)
		end
	end
end

--- A rim plate: heaved on its far edge as the wall comes through (keeping 70%), slumped at the end, then sunk away.
local function rimPose(fx, r, t)
	local d = r.D
	local a = t - d.At
	local heave = 0
	if a >= 1.2 then
		heave = d.Lift * 0.7
	elseif a > 0 then
		heave = d.Lift * (1 - math.exp(-a / 0.08)) * (1 + 0.15 * math.exp(-a / 0.15) * math.sin(25 * a))
			* (1 - 0.3 * smooth(span(a, 0.1, 0.6)))
	end
	local down = 0
	if fx.EndAt then
		local e = t - fx.EndAt
		down = d.Sag * smooth(span(e, 0.15, 1.05))
		if fx.RimGoneAt and t > fx.RimGoneAt then
			down += (d.Size.Y + 0.3) * span(t, fx.RimGoneAt, fx.RimGoneAt + W.RimSinkTime) ^ 2
		end
	end
	local rest = d.Rest
	local sideZ = rest.Z >= 0 and 1 or -1
	local halfZ = math.max(d.Size.Z / 2, 0.1)
	local hinge = Vector3.new(rest.X, rest.Y, rest.Z + sideZ * halfZ)
	local theta = sideZ * math.atan2(heave, 2 * halfZ)
	local roll = d.Lift > 0 and (d.Roll + r.RollSign * d.RollK) * heave / d.Lift or 0
	return CFrame.new(0, -down, 0) * CFrame.new(hinge) * CFrame.Angles(theta, 0, 0) * CFrame.new(-hinge) * rest
		* CFrame.Angles(0, 0, roll)
end

local function stepRim(fx, t)
	for _, r in ipairs(fx.Rim) do
		if r.Piece then
			if fx.RimGoneAt and t >= fx.RimGoneAt + W.RimSinkTime then
				CR.Release(r.Piece)
				r.Piece = nil
			else
				local pose = rimPose(fx, r, t)
				if pose ~= r.Last then
					r.Last = pose
					CR.Place(r.Piece, fx.K * pose, moveList, moveCFs)
				end
			end
		end
	end
end

local function stepScuffs(fx, t)
	for i = #fx.Scuffs, 1, -1 do
		local sc = fx.Scuffs[i]
		if sc.Kind == "ground" then
			local a = t - sc.At
			if a >= 3.3 then
				pcall(function() sc.Part:Destroy() end)
				table.remove(fx.Scuffs, i)
			else
				setScuffAlpha(sc, scuffAlpha(a))
			end
		end
	end
end

local function raiseDust(fx)
	local size = typeof(fx.Kit.Data.Size) == "Vector3" and fx.Kit.Data.Size or Vector3.new(12.3, 8.4, 1.6)
	local half, n = size.X / 2, W.RaiseDustPoints
	for i = 0, n - 1 do
		local x = -half + (i + 0.5) * (2 * half / n)
		for _, side in ipairs({ -1, 1 }) do
			local p = fx.K * Vector3.new(x, 0.15, side * W.SlotHalf.Z)
			burst(fx, "A", "Kick", CFrame.new(p), W.RaisePuffs, 1, 0.5)
			burst(fx, "A", "Grit", CFrame.new(p), W.RaiseGrit, 1)
		end
	end
end

local function sinkDust(fx, home)
	if home then
		local base = CFrame.new(fx.K * Vector3.new(0, 0.2, 0))
		burst(fx, "A", "Skirt", base, W.HomePuffs, 0.8, W.SlotHalf.X)
		burst(fx, "A", "Haze", base, 2, 1, 4)
		return
	end
	local n = W.RaiseDustPoints
	for i = 0, n - 1 do
		local x = -W.SlotHalf.X + (i + 0.5) * (2 * W.SlotHalf.X / n)
		for _, side in ipairs({ -1, 1 }) do
			burst(fx, "A", "Kick", CFrame.new(fx.K * Vector3.new(x, 0.15, side * W.SlotHalf.Z)), W.SinkPuffs, 0.8, 0.5)
		end
	end
end

-- (2026-10-25, round 2) a Mythic wall's Drift on (its own rate, as TerraWrap made it) or off; written on a change only
local function driftOn(fx, on)
	local dr = fx.Drift
	if not dr or dr.On == on then return end
	dr.On = on
	pcall(function() dr.E.Rate = on and dr.Rate or 0 end)
end

--- Everything of a wall gone at once: pieces back to their pools, scuffs, the void and (once its dust is out) the host.
local function teardown(fx)
	if fx.Gone then return end
	fx.Gone = true
	-- (2026-10-25, round 2) the Drift stops now and its host goes with the dust host (its embers rise out first)
	local dr = fx.Drift
	if dr then
		driftOn(fx, false)
		task.delay(3, function() pcall(function() dr.Host:Destroy() end) end)
	end
	if walls[fx.Key] == fx then walls[fx.Key] = nil end
	for _, s in ipairs(fx.Slabs) do
		if s.Whole then CR.Release(s.Whole) end
		s.Whole = nil
		dropTemplate(fx, s)
	end
	for _, b in ipairs(fx.Loose) do
		if b.Piece then CR.Release(b.Piece) end
	end
	for _, r in ipairs(fx.Rim) do
		if r.Piece then CR.Release(r.Piece) end
	end
	for _, sc in ipairs(fx.Scuffs) do pcall(function() sc.Part:Destroy() end) end
	if fx.Void then pcall(function() fx.Void:Destroy() end) end
	local host = fx.Host
	if host then task.delay(3, function() pcall(function() host:Destroy() end) end) end
end

local function sinkWall(fx, tr, late)
	fx.State, fx.SinkAt, fx.EndAt = "Sink", tr, tr
	fx.Late = late
	driftOn(fx, false)                          -- (2026-10-25, round 2: no-op without a Drift)
	fx.RimGoneAt = tr + W.SinkLead + W.SinkTime + W.RimLinger
	for _, b in ipairs(fx.Loose) do b.Hold = math.min(b.Hold, 0.2) end
	if not late then sinkDust(fx, false) end
end

local function stepWall(fx, now)
	local t = fxTime(fx)
	local dt = math.clamp((now - fx.Now) * VFX.ShotTimeScale(), 0, 0.1)
	fx.Now = now
	fx.Puffs = 0
	if fx.State == "Up" then
		local c = fx.Character
		-- 2026-10-23: no MaxHold sink: the server's wall has no time cap (FREE MANA holds it for good), so the look waits
		-- for its WallDrop as the collider does; only the caster's body gone takes it down here
		if not (typeof(c) == "Instance" and c.Parent) then sinkWall(fx, t, true) end
	end
	if not fx.RaiseDust and t >= W.RiseAt then
		fx.RaiseDust = true
		if t < W.RiseAt + W.Late then raiseDust(fx) end
	end
	if fx.Void and not fx.VoidPlaced and t >= W.SlotAt then
		fx.VoidPlaced = true
		local i = #moveList + 1
		moveList[i], moveCFs[i] = fx.Void, fx.K * CFrame.new(0, 0.03, 0)
	end
	-- (2026-10-25, round 2) a Mythic wall's Drift: on once it has risen, for as long as it stands
	if fx.Drift then driftOn(fx, fx.State == "Up" and t >= W.RiseAt + W.RiseTime) end
	-- the break's wave
	local changed = false
	for i = #fx.Pending, 1, -1 do
		local p = fx.Pending[i]
		if t >= p.At then
			table.remove(fx.Pending, i)
			if p.Wedge then crumble(fx, p.Slab, t) else topple(fx, p.Slab, t) end
			changed = true
		end
	end
	-- the sink's end: the stack is under the floor
	if fx.SinkAt and not fx.SinkDone and t >= fx.SinkAt + W.SinkLead + W.SinkTime + 0.05 then
		fx.SinkDone = true
		if not fx.Late then sinkDust(fx, true) end
		for _, s in ipairs(fx.Slabs) do
			if s.Whole then CR.Release(s.Whole) end
			s.Whole = nil
			dropTemplate(fx, s)
			s.Down = true
		end
		changed = true
	end
	if fx.Void and fx.RimGoneAt and t >= fx.RimGoneAt + W.RimSinkTime then
		pcall(function() fx.Void:Destroy() end)
		fx.Void = nil
	end
	local standing = false
	for _, s in ipairs(fx.Slabs) do
		if not s.Down then
			standing = true
			placeStanding(fx, s, t)
		end
	end
	local before = #fx.Loose
	stepLoose(fx, t, dt)
	stepRim(fx, t)
	stepScuffs(fx, t)
	if changed or #fx.Loose ~= before then rebalance(fx) end
	if fx.State == "Up" then return true end
	if standing or #fx.Loose > 0 or #fx.Pending > 0 or #fx.Scuffs > 0 then return true end
	for _, r in ipairs(fx.Rim) do
		if r.Piece then return true end
	end
	return false
end

stepAll = function()
	local now = os.clock()
	for _, fx in pairs(walls) do
		local ok, alive = pcall(stepWall, fx, now)
		if not ok then
			warnOnce("step", "a wall's step failed: " .. tostring(alive))
			teardown(fx)
		elseif not alive then
			teardown(fx)
		end
	end
	if #moveList > 0 then
		local ok = pcall(function() workspace:BulkMoveTo(moveList, moveCFs, Enum.BulkMoveMode.FireCFrameChanged) end)
		if not ok then
			-- a part released since it was queued (a wall torn down between frames): move the rest
			local parts, cfs = {}, {}
			for i, p in ipairs(moveList) do
				if p.Parent then
					parts[#parts + 1] = p
					cfs[#cfs + 1] = moveCFs[i]
				end
			end
			pcall(function() workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end)
		end
		table.clear(moveList)
		table.clear(moveCFs)
	end
	if next(walls) == nil and bound then
		bound = false
		RunService:UnbindFromRenderStep(BIND)
	end
end

----------------------------------------------------------------------------------------------------
-- the hooks (TerraFX hands WallRaise / WallHit / WallDrop here while Available())
----------------------------------------------------------------------------------------------------
--- RAISE at `cf` (the server's wall foot, LookVector = its front, the enemy's side), on the server's clock from `t0`.
--- `size` is the server body's (TR_Wall_Slab_01..12's box): the kit is drawn at its own size over it.
function TerraFX_Wall.Raise(character, cf, size, t0)
	if typeof(cf) ~= "CFrame" then return end
	local kit = loadKit()
	if not kit then return end
	-- the server drops the old wall ("Released") before it raises a new one: a wall still sinking or collapsing finishes
	-- under its own key; one still standing (no drop came) goes at once
	local old = walls[character]
	if old then
		walls[character] = nil
		if old.State == "Up" then
			teardown(old)
		else
			old.Key = old
			walls[old] = old
		end
	end
	t0 = type(t0) == "number" and t0 or workspace:GetServerTimeNow()
	local local_ = Players.LocalPlayer
	local fx = { Character = character, Key = character, CF = cf, K = cf * kit.Turn, T0 = t0, Kit = kit, ServerSize = size,
		Wrap = CR and CR.WrapOf(character, "BulwarkWall"),   -- the caster's wrap (SkinCatalog), or nil: Default
		-- (2026-10-19, audit P5F-06) Reduce Enemy VFX's "an enemy's": VFXLibrary.IsEnemy (a teammate's wall is whole)
		Thin = if VFX and type(VFX.IsEnemy) == "function" then VFX.IsEnemy(character) else not (local_ and character == local_.Character),
		Slabs = {}, Loose = {}, Rim = {}, Scuffs = {}, Pending = {},
		Emitters = {}, State = "Up", HitAt = -math.huge, HitDir = -1, Now = os.clock(), Puffs = 0,
		Rng = Random.new(math.floor(t0 * 1000) % 2147483647) }
	-- (2026-10-25, round 2) a wrap's Stone: the kit's grey copies queued now (ChargedRock; cheap once they are built) --
	-- the slabs cloned below ask for theirs first
	local sk = fx.Wrap and fx.Wrap.Skin
	if sk and sk.Stone and type(CR.Prewarm) == "function" then pcall(CR.Prewarm, kit.Model) end
	local fy, hit = floorAt(cf.Position + Vector3.new(0, 0.5, 0), cf.Position.Y)
	fx.FloorY = fy
	local tone = W.PlateTone
	if hit and hit.Instance:IsA("BasePart") and not hit.Instance:IsA("Terrain") then tone = hit.Instance.Color end
	local host = Instance.new("Part")
	host.Name = "TerraWallFX"
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow = true, false, false, false, false
	host.Transparency = 1
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.CFrame = cf
	host.Parent = fxFolder()
	fx.Host = host
	local point = Instance.new("Attachment")
	point.Parent = host
	fx.Point = point
	-- (2026-10-25, round 2) MYTHIC Drift: star embers rising off the standing wall -- TerraWrap's emitter on a host the
	-- wall's size, rated while the wall stands (stepWall), zeroed at its sink or break, gone with it (teardown)
	if sk and type(sk.Drift) == "table" then
		local TW = CR.TerraWrap and CR.TerraWrap()
		if TW and type(TW.DriftSet) == "function" then
			local size = typeof(kit.Data.Size) == "Vector3" and kit.Data.Size or Vector3.new(12.3, 8.4, 1.6)
			local dh = Instance.new("Part")
			dh.Name = "TerraWallDrift"
			dh.Anchored, dh.CanCollide, dh.CanQuery, dh.CanTouch, dh.CastShadow = true, false, false, false, false
			dh.Transparency = 1
			dh.Size = size
			dh.CFrame = fx.K * CFrame.new(0, size.Y / 2, 0)
			dh.Parent = fxFolder()
			local ok, pe = pcall(TW.DriftSet, sk, dh, fx.Thin)
			if ok and typeof(pe) == "Instance" and pe:IsA("ParticleEmitter") then
				fx.Drift = { Host = dh, E = pe, Rate = pe.Rate, On = false }
				pe.Rate = 0
			else
				dh:Destroy()
			end
		end
	end
	for i, ks in ipairs(kit.Slabs) do
		local s = { K = ks, Whole = CR.Clone(kit.Model, ks.Name, fx.Wrap), Stage = 0, PrevStage = 0, StageAt = -math.huge,
			HitAt = -math.huge, JoltAt = -math.huge, JoltAmp = 0, JoltDir = -1, Down = false }
		if not s.Whole then s.Down = true end
		fx.Slabs[i] = s
	end
	-- the ground: the dark slot, its plates (thrown aside as the wall comes through), the heaved rim
	local t = fxTime(fx)
	local void = Instance.new("Part")
	void.Name = "TerraWallVoid"
	void.Anchored, void.CanCollide, void.CanQuery, void.CanTouch, void.CastShadow = true, false, false, false, false
	void.Material = Enum.Material.SmoothPlastic
	void.Color = W.Void
	void.Size = Vector3.new(W.SlotHalf.X * 2, 0.04, W.SlotHalf.Z * 2)
	void.CFrame = STASH
	void.Parent = fxFolder()
	fx.Void = void
	if t < W.SlotAt + W.Late then
		for _, e in ipairs(kit.Slot) do
			local piece = CR.Clone(kit.Model, e.Name, fx.Wrap, true)   -- (plain: the floor, not the wall's stone)
			if piece then
				piece.Stone.Color = tone
				local R = fx.K.Rotation
				local b = addLoose(fx, piece, fx.K * e.Rest, R * e.V, R * e.W, "plate", t)
				b.State, b.FlyAt, b.Hold, b.LandMin = "hold", W.SlotAt, W.SlotHold, 0.1
				b.Vol = e.Size.X * e.Size.Y * e.Size.Z
			end
		end
	end
	for _, e in ipairs(kit.Rim) do
		local piece = CR.Clone(kit.Model, e.Name, fx.Wrap, true)     -- (plain: the floor, not the wall's stone)
		if piece then
			piece.Stone.Color = tone
			fx.Rim[#fx.Rim + 1] = { D = e, Piece = piece, RollSign = fx.Rng:NextNumber() < 0.5 and -1 or 1 }
		end
	end
	walls[fx.Key] = fx
	rebalance(fx)
	ensureBound()
end

--- A HIT at `point` (the server's, on the face) at server time `t0`: the nearest standing slab jolts, flares and takes
--- one damage stage. `left` (the pool's share left) is not the stage: a slab's stage counts the hits it took.
function TerraFX_Wall.Hit(character, point, left, t0)
	local fx = walls[character]
	if not (fx and fx.State == "Up" and typeof(point) == "Vector3") then return end
	local th = fxTime(fx, type(t0) == "number" and t0 or nil)
	local t = fxTime(fx)
	local late = t - th > W.Late
	local kp = fx.K:PointToObjectSpace(point)
	local back = kp.Z < 0             -- kit +Z is the front (the enemy's side): a hit from the caster's side is behind
	local best, bd = nil, math.huge
	for _, s in ipairs(fx.Slabs) do
		if not s.Down then
			local c = s.K.Rest.Position
			local d = (Vector2.new(c.X, c.Y) - Vector2.new(kp.X, kp.Y)).Magnitude
			if d < bd then best, bd = s, d end
		end
	end
	if not best then return end
	local s = best
	local dirZ = back and 1 or -1     -- away from the hitter
	fx.HitAt, fx.HitDir = th, dirZ
	s.JoltAt, s.JoltAmp, s.JoltDir, s.HitAt = th, W.JoltAmp, dirZ, th
	if s.Stage < 4 then
		local fresh = false
		if not s.Tpl and fx.Kit.Tpl then
			local struck = {}
			for _, o in ipairs(fx.Slabs) do
				if o.Tpl and not o.Down then struck[#struck + 1] = o end
			end
			if #struck >= W.MaxStruck then
				-- the 4th fresh slab takes the template of the least damaged (its oldest hit on a tie), which goes back whole
				table.sort(struck, function(a, b)
					if a.Stage ~= b.Stage then return a.Stage < b.Stage end
					return a.HitAt < b.HitAt
				end)
				revert(fx, struck[1])
			end
			s.StageAt = th
			fresh = fitTemplate(fx, s, back)
		end
		-- a fresh fine cut starts at rest (whatever hits the slab took while the budget had no room for it)
		s.PrevStage = (s.Tpl and not fresh) and s.Stage or 0
		s.Stage += 1
		s.StageAt = th
		if s.Tpl then
			for _, tp in ipairs(s.Tpl.Pieces) do
				local rel = s.Tpl.Mirror and tp.E.MRelease or tp.E.Release
				if rel and rel.Hit <= s.Stage and tp.Piece then knockOff(fx, s, tp, rel, th, t, late) end
			end
		end
	end
	if not late then
		local out = fx.K:VectorToWorldSpace(Vector3.new(0, 0, back and -1 or 1))
		burst(fx, "B", "Landing", upFrame(point + out * 0.3, out), W.HitPuffs, 0.8)
		burst(fx, "B", "KickGrit", upFrame(point + out * 0.2, out), W.HitGrit, 1)
		if s.Stage >= 3 then
			burst(fx, "A", "Landing", upFrame(point - out * (s.K.Size.Z + 0.1), -out), W.SpallPuffs, 0.7)
		end
		throwPebbles(fx, point, out, W.HitPebbles + (s.Stage >= 2 and 1 or 0), t)
	end
	rebalance(fx)
end

--- DOWN at server time `t0`. "Broken": the damaged slabs burst and the rest collapse on the wave; any other reason
--- (Released / Empty / Lost): the stack sinks back into the floor.
function TerraFX_Wall.Drop(character, reason, t0)
	local fx = walls[character]
	if not (fx and fx.State == "Up") then return end
	local td = fxTime(fx, type(t0) == "number" and t0 or nil)
	local t = fxTime(fx)
	local late = t - td > W.Late
	if reason ~= "Broken" then
		sinkWall(fx, td, late)
		return
	end
	fx.State, fx.BreakAt, fx.EndAt, fx.Late = "Broken", td, td, late
	fx.RimGoneAt = td + W.RimLingerBroken
	driftOn(fx, false)                          -- (2026-10-25, round 2: no-op without a Drift)
	-- the wave runs from the worst damage (the slab with the most hits, the latest of those), else the wall's middle
	local worst = nil
	for _, s in ipairs(fx.Slabs) do
		if s.Tpl and not s.Down and (not worst or s.Stage > worst.Stage or (s.Stage == worst.Stage and s.HitAt > worst.HitAt)) then
			worst = s
		end
	end
	local centre = worst and (worst.K.Frame * (worst.Tpl.Imp * worst.Tpl.K)) or Vector3.new(0, 4, 0)
	local fromBehind = worst ~= nil and worst.Tpl.Mirror
	fx.BreakCentre = centre
	local speed = W.WaveSpeed
	local collapse = fx.Kit.Data.Collapse
	if type(collapse) == "table" and type(collapse.WaveSpeed) == "number" and collapse.WaveSpeed > 0 then
		speed = collapse.WaveSpeed
	end
	local at = {}
	for _, s in ipairs(fx.Slabs) do
		if s.Tpl and not s.Down then
			at[s.K] = td
			burstSlab(fx, s, t)
		end
	end
	-- the rest by course, bottom up: a slab goes no later than the slabs it stands on
	local order = {}
	for _, s in ipairs(fx.Slabs) do
		if not s.Down then order[#order + 1] = s end
	end
	table.sort(order, function(a, b) return a.K.Course < b.K.Course end)
	for _, s in ipairs(order) do
		local ta = td + W.WaveLag + (s.K.Rest.Position - centre).Magnitude / speed
		for _, u in ipairs(s.K.Under) do
			if at[u] then ta = math.min(ta, at[u]) end
		end
		at[s.K] = ta
		local wedge = s.K.Course == 1 and fx.Rng:NextNumber() < W.WedgeChance
		fx.Pending[#fx.Pending + 1] = { At = wedge and (td + W.WedgeAt) or ta, Slab = s, Wedge = wedge }
	end
	if not late then
		local c = fx.K * centre
		-- the cloud goes the way the burst does: away from the hitter
		local toward = fx.K:VectorToWorldSpace(Vector3.new(0, 0, fromBehind and 1 or -1))
		burst(fx, "B", "Cloud", CFrame.lookAt(c, c + toward), W.BreakCloud, 1)
		burst(fx, "A", "Grit", upFrame(c, toward + Vector3.yAxis), W.BreakGrit, 1)
		local base = CFrame.new(fx.K * Vector3.new(0, 0.2, 0))
		burst(fx, "A", "Skirt", base, W.BreakSkirt, 1, 3)
		burst(fx, "A", "Haze", base, W.BreakHaze, 1, 5)
		-- (2026-10-25, round 2) MYTHIC Shock: the break's ring on the floor under its worst damage (TerraWrap draws it
		-- by the settings: thinner / off at LOW, no flash under Reduce Flashing)
		local sk = fx.Wrap and fx.Wrap.Skin
		local R = sk and type(sk.Shock) == "table" and type(sk.Shock.Radius) == "table" and tonumber(sk.Shock.Radius.Wall)
		if R and R > 0 then
			local TW = CR.TerraWrap and CR.TerraWrap()
			if TW and type(TW.Shockwave) == "function" then
				pcall(TW.Shockwave, sk, CFrame.new(c.X, fx.FloorY + 0.03, c.Z), R, fx.Thin)
			end
		end
	end
	rebalance(fx)
end

return TerraFX_Wall
