--[[
	TerraFX_Tomb  (ModuleScript)  ->  ReplicatedStorage/IceMagic/TerraFX_Tomb

	Terra's Ultimate, Earthen Tomb: THE REWORKED LOOK (2026-10-09). Built in Blender first (blender_scripts/terra/
	earthen_tomb_bl.py, notes in vfx_blocking/terra/tomb/rework/) and brought in to vfx_blocking/terra/
	WALL_TOMB_PORT_SPEC.md. TerraFX keeps the hooks AbilityFX calls (TombCast ... TombDescend, TombEnd) and hands each one
	here while Available() is true; until then it draws its own v2 look. GAMEPLAY IS UNTOUCHED: TerraHandler runs the cast,
	and every number the server reads stays in TerraFX.Tuning.EarthenTomb. Nothing in this file is read by the server.

	The pieces are the TerraTomb2 kit (EarthMagicMeshes.TerraTomb2, export/terra_kit/TerraTomb2.fbx), every rock in the
	charged-rock material through ChargedRock (stone + break faces + Lit / Dead crack strips; spec v1.4, restrained: no
	lights, no white cores). Their layout and timing come from the generated ReplicatedStorage.Spellshot.EarthenTombKitData.
	Every beat runs on the server's clock (T0) x the review slow-motion, as the live Tomb does, so a late joiner catches up.

	  Cast      after the grip, the crack runs from her hands to the target's feet -- the live homing head, simulated here at
	            the server's speed toward wherever this client sees the target -- a dark gap laid behind it, dust and grit
	            off it; as it reaches them the ground splits round their feet and loose pebbles rattle
	  Miss      the gap closes back into the floor, head first; the pebbles settle and sink
	  Catch     THE TEAR: the slab of ground under them tears loose and climbs (TombRise, the live curve), leaving the dark
	            mouth of its hole; THE HEAP erupts out of the slab's top ring by ring (shins, hips, chest, head, peak), each
	            rock punched up through the crust, tumbling into its place; the pebbles are flung; earth falls off the
	            slab's underside. 0.4 s in, THE BOULDERS are torn out of the ground round them and climb to their gather
	            points, and Converge before the top they close in on the chest, faster and faster, and slam home (a hit
	            flare on them and the heap rocks they strike)
	  Burst     every piece of the heap and the boulders is thrown off (scripted ballistic flights with one floor probe
	            each -- no physics), their breaks flaring gold and cooling to the ember they keep; dust dome and skirt,
	            grit, chips; scuffs where the big pieces first land. The slab rings under the bare target and holds
	  Break     (an escape) the heap is thrown off gentler and the boulders crumble where they are
	  Descend   the slab comes down into its hole and seats with a thud and a skirt of dust; it then sinks away, the mouth
	            heals, and the rubble sinks into the floor

	ONE STEPPER: a single Heartbeat connection while any Tomb is drawn (none bound to RenderStep), and ONE BulkMoveTo a
	frame for every piece of every Tomb. Every visual part is Anchored and inert (no collide / query / touch) in the FX
	folder; nothing is simulated by the engine.

	BUDGET (contract: at most 260 visual parts at once): the 149 stones (117 heap pieces, 32 boulder pieces) always draw;
	the crack strips and break faces are granted in priority order into what is left -- before the burst Lit strips on
	the boulders and on the heap rocks facing this camera, then Dead strips; at the burst the Dead strips are retired and
	the break faces (the flare) take their place, biggest pieces first. Somebody else's Tomb (not yours, not on you) draws
	at MaxPartsThin.

	WRAPS (2026-10-25, the ladder's round 2; each on its own skin field, so Default and Obsidian Magma are as before): the
	heap, the boulders, the clod, the pebbles and the chips in the wrap's material (Stone, ChargedRock's grey copies,
	prewarmed when the cast's look is made), Epic crystals on the pieces (CrystalsBaked: a fifth part kind, "Crystal",
	granted from the same budget), Mythic molten break faces (Core, in ChargedRock), the burst's ground ring (Shock) and
	star embers rising off the risen pillar (Drift; not on your own Tomb). The gap, the head, the mark and the mouth stay
	Default: they are the telegraph.

	OUT OF SCOPE here (contract section 0.7): the caster's poses, the hitpause, the film's 0.06 s later burst (the live
	burst time is kept), any server change.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tomb = {}

----------------------------------------------------------------------------------------------------
-- tuning. LOOK ONLY -- the server reads none of it. EVERY NUMBER HERE IS A PROPOSAL (2026-10-09): the film's own
-- (earthen_tomb_bl.T / Plan, via D:/voltkit_scratch/terra_port/map/tomb_build.md) unless a comment says otherwise.
----------------------------------------------------------------------------------------------------
Tomb.Tuning = {
	Kit = "TerraTomb2",             -- ReplicatedStorage.EarthMagicMeshes.TerraTomb2 (Import 3D by the integrator)
	Data = "EarthenTombKitData",    -- ReplicatedStorage.Spellshot.EarthenTombKitData (GENERATED by earthen_tomb_kit_export.py)
	Origin = "ET_Origin",           -- the kit's origin marker: every piece's rest is read against it (the M1 / Aftershock way)
	Clod = "ET_SlabClod",           -- the torn-earth clod, if the data does not name it
	PebblePattern = "^ET_Pebble_%d+$",

	-- THE SLAB AND THE HEAP
	Lift = 0.05,            -- the slab and the mouth sit this far over the floor: a floor cannot be cut (Aftershock's PlateLift)
	ChestUp = 3.2,          -- the chest the boulders close on: the slab's top + this (the film's and the live code's)
	EruptTime = 0.18,       -- a heap rock's punch (= the live EncaseEruptTime; TerraFX's value is read when present)
	ShowLead = 0.03,        -- a rock is drawn this long before its punch (inside the slab, under its crust)
	Tumble = 0.7,           -- rad of tumble a rock comes up with, eased out by its punch
	Pull = 0.5,             -- rings 1-3 wait this far in toward the body, eased out with the punch
	TravelPad = 0.12,       -- a waiting rock's top sits this far under the slab's top
	-- (2026-10-09) The rework's heap covers the head (rings 4 and 5). On the victim's own client those two rings are not
	-- drawn: in first person they sit round the lens and would black the view out for the whole climb.
	OwnHideRings = { [4] = true, [5] = true },
	RockX = 2.2, RockY = 1.6,           -- deg: the slab's rocking in flight (sin(2.3 a + 0.4) about X, sin(1.7 a + 1.9) about Y)
	RockIn = 0.35, RockOut = 0.42,      -- ...eased in over this from the tear, out over this from the descent
	Tremble = 0.03, TrembleHz = 28, TrembleUntil = 0.06,  -- studs: the tear's shudder (the film's 0.03, a fast buzz here)
	BurstDip = 0.24, BurstDipTau = 0.12, BurstDipW = 28,  -- the slab rings under the burst: -0.24 e^(-a/0.12) sin(28 a)
	Thud = 0.10, ThudTau = 0.06,                          -- the seat: -0.10 e^(-b/0.06) sin(min(b/0.04, 1) pi)

	-- THE BOULDERS
	CtrlUp = { 1, 3 },      -- the tear-out's Bezier control: straight over the buried start, this far over the gather height
	BoulderSpin = { 3.2, 6.6 },   -- rad/s, when the data gives none
	OwnStop = 4.4,          -- your own chest: no boulder stops nearer than this (the live code's "stop short of your eyes")

	-- THE BURST (Aftershock's flown-rock law: no physics, one floor probe each)
	HeapOut = { 10, 16 }, HeapUp = { 4, 12 },   -- the data's Burst.HeapOut / HeapUp replace these when present
	RingUp = 1.5,           -- ...+ this much up a ring
	TowardDot = 0.8, TowardCaster = 0.55,   -- a piece thrown at the caster is thrown this much softer
	HeapJitter = 1.0,
	BoulderOut = { 12, 20 }, BoulderUp = { 4, 10 }, BoulderJitter = 2.0,
	Spin = { 4, 10 },
	BreakPower = 0.7,       -- an escape throws the heap at this (the live blowRocks(0.7))
	CrumbleOut = { 1.5, 4 }, CrumbleUp = { 1, 3 },   -- ...and the boulders just come apart and drop
	Gravity = 35, Bounce = 0.25, Slide = 0.6, Rest = 0.8,
	ProbeAbove = 4, ProbeDepth = 14,   -- a landing probe starts this far over the catch's floor and looks this far down
	RubbleHold = 2.6,       -- s after the burst the rubble lies (the film's clip ends with it lying)...
	SinkStagger = 0.35, Sink = 0.6,    -- ...then sinks into the floor over this (staggered)
	Chips = 10, ChipOut = { 18, 28 }, ChipUp = { 2, 6 },   -- the splinters drawn as parts (the rest are grit)
	LandPuffs = 30,         -- landing puffs a cast at most (a piece's first contact faster than LandSpeed)
	LandSpeed = 6,

	-- SCUFFS (the M1's decal), where the biggest pieces first touch the floor
	Scuffs = 12, BoulderScuffs = 10, ScuffK = 1.3, ScuffSize = { 2.1, 2.7 },
	ScuffIn = { 0.05, 0.14 }, ScuffOut = { 2.5, 3.3 }, ScuffAlpha = 0.95,
	ScuffTexture = "rbxassetid://102375587925629",

	-- THE DESCENT AND THE CLEAN-UP
	ClodHold = 0.6, ClodSink = 0.7, ClodDepth = 4.6,   -- the seated slab holds, then sinks this far into its hole...
	HealDelay = 0.35, Heal = 0.8,                      -- ...and the mouth fades this long after, over this

	-- THE CRACK RUN
	SegmentLen = 1.5,
	GapFrom = 0.10, GapTo = 0.24, GapRamp = 18.7,      -- the gap widens along the run (the film's 0.10 -> 0.24)
	Void = Color3.fromRGB(38, 28, 19),                 -- the dark of the gap and the mouth (the film's VOID)
	ArriveSlack = 1.0,      -- the head within Reach + this of the feet: the split round them
	Pebbles = 6, PebbleR = { 3.6, 5.1 }, PebbleHops = { 0.01, 0.045, 0.08 }, PebbleKick = 2.8,
	PebbleOut = { 3, 6 }, PebbleUp = { 5, 9 }, PebbleSink = { 1.2, 1.6 },

	-- BUDGETS
	MaxParts = 260,         -- the contract's cap: visual parts at once
	MaxPartsThin = 200,     -- somebody else's Tomb (not yours, not on you)
	ReserveFX = 22,         -- kept free before the burst for the chips and the scuffs
	CloneCap = 12,          -- pieces cloned a frame at most (the cast pre-clones; the pool makes later casts free)
	Late = 0.35,            -- a one-shot beat this late (a late join) is skipped
	LevelHz = 30,           -- charged-rock writes a second, outside the flares
	FPThin = 0.3,           -- first person: the dust at your own chest drawn at this share (it sits at the lens)
	-- (2026-10-25, round 2) a Mythic wrap's Drift (TerraWrap.DriftSet): its host round the heap, this far over the slab's top
	DriftSize = Vector3.new(4.4, 5, 4.4), DriftUp = 2.6,

	-- SHAKES: the film's (amp, decay), through the Viewmodel's own path; others' by distance out to ShakeReach
	ShakeReach = 40,
	ShakePlant = { 0.05, 0.12 }, ShakeArrive = { 0.04, 0.12 }, ShakeTear = { 0.26, 0.30 }, ShakeSealed = { 0.05, 0.10 },
	ShakeTop = { 0.12, 0.12 }, ShakeBurst = { 0.32, 0.24 }, ShakeRumble = { 0.12, 0.55 }, ShakeLand = { 0.14, 0.25 },
}
local TU = Tomb.Tuning

-- the server's numbers (TerraFX.Tuning.EarthenTomb), as they stand on 2026-10-09: used only if TerraFX cannot be read
local LIVE_DEFAULT = {
	GripTime = 0.12, FissureSpeed = 60, MaxTravel = 1.6, CatchReach = 2.0, SegmentEvery = 1.4,
	RiseTime = 1.6, RiseHeight = 12, Converge = 0.6, BurstHold = 0.45, DescendTime = 0.8, EscapeDescendTime = 0.35,
	EncaseEruptTime = 0.18,
}

-- (2026-10-25, round 2) "Crystal": an Epic wrap's crystal on a piece (ChargedRock CrystalsBaked) -- hidden, shown and
-- moved like the strips; Default and every other wrap have none, so nothing changes for them
local KINDS = { "Stone", "Brk", "Lit", "Dead", "Crystal" }
local DISC = { Kick = true, Skirt = true, Haze = true }

----------------------------------------------------------------------------------------------------
-- plumbing
----------------------------------------------------------------------------------------------------
local VFXLibrary, Settings, Viewmodel = nil, nil, nil
local function libs()
	if not VFXLibrary then
		local ice = ReplicatedStorage:WaitForChild("IceMagic")
		VFXLibrary = require(ice:WaitForChild("VFXLibrary"))
		Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
		local ok, vm = pcall(require, ice:WaitForChild("Viewmodel"))
		Viewmodel = ok and vm or nil
	end
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[TerraFX_Tomb] " .. msg)
end

-- ChargedRock (the WALL builder's shared module, contract section 3): required lazily, not cached as missing
local CR = nil
local function chargedRock()
	if CR then return CR end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild("ChargedRock")
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok and type(mod) == "table" and type(mod.Clone) == "function" then
			CR = mod
		end
	end
	return CR
end

-- TerraFX.Tuning.EarthenTomb, read LAZILY: TerraFX requires this module, so it is only read from inside a hook, once
-- TerraFX has finished loading. Not cached as missing.
local liveE = nil
local function liveTuning()
	if liveE then return liveE end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild("TerraFX")
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok and type(mod) == "table" and type(mod.Tuning) == "table" and type(mod.Tuning.EarthenTomb) == "table" then
			liveE = setmetatable({}, { __index = function(_, k)
				local v = mod.Tuning.EarthenTomb[k]
				if v == nil then v = LIVE_DEFAULT[k] end
				return v
			end })
		end
	end
	return liveE or LIVE_DEFAULT
end

local function fxFolder()
	libs()
	local name = VFXLibrary.Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(u) u = clamp01(u) return u * u * (3 - 2 * u) end
local function span(t, a, b) return clamp01((t - a) / (b - a)) end
local function bez(a, c, b, u) return a * ((1 - u) ^ 2) + c * (2 * u * (1 - u)) + b * (u * u) end
-- TerraFX.TombRise: the climb both the server and the poses use. Copied, not required (see liveTuning) -- DO NOT DIVERGE
local function rise01(u) u = clamp01(u) return 1 - (1 - u) ^ 2.2 end
-- the film's punch: up fast, ~3% past its place, and back
local function punch(u)
	if u <= 0 then return 0 end
	u = math.min(u, 1)
	return (1 - (1 - u) ^ 3) * (1 + 0.07 * math.sin(math.pi * u))
end
local function flatUnit(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or (fallback or Vector3.zAxis)
end
local function between(rng, r) return rng:NextNumber(r[1], r[2]) end
local function randUnit(rng)
	for _ = 1, 8 do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local m = v.Magnitude
		if m > 0.1 and m <= 1 then return v / m end
	end
	return Vector3.xAxis
end
--- How far a box at rotation `cf` reaches below (or above) its centre -- a little under its box, the stone sits inside it.
local function reach(cf, half)
	return 0.85 * (math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z)
end
local function range2(t, fallback)
	if type(t) == "table" and tonumber(t[1]) and tonumber(t[2]) then return { tonumber(t[1]), tonumber(t[2]) } end
	return fallback
end
local function inertPart()
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Reflectance, p.Transparency = 0, 0
	return p
end

-- THE FLOOR, the Aftershock probe's way: searched down from just over the floor we expect, never from high up (a roof
-- is never taken for the ground); the FX folder and every player are not floor; a dummy or a wall is looked through.
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
local rayAt = 0
local function probe(p, top, len)
	local now = os.clock()
	if now >= rayAt then
		rayAt = now + 0.5
		local list = { fxFolder() }
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character then list[#list + 1] = pl.Character end
		end
		ray.FilterDescendantsInstances = list
	end
	local from, dir = Vector3.new(p.X, top, p.Z), Vector3.new(0, -len, 0)
	for _ = 1, 3 do
		local hit = workspace:Raycast(from, dir, ray)
		if not hit then return nil end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit end
		ray:AddToFilter(model)
	end
	return nil
end
local function floorAt(p)
	local hit = probe(p, p.Y + 3, 24)
	return hit and hit.Position or p
end

----------------------------------------------------------------------------------------------------
-- the kit and its data
----------------------------------------------------------------------------------------------------
local function kitModel()
	local folder = ReplicatedStorage:FindFirstChild("EarthMagicMeshes")
	return folder and folder:FindFirstChild(TU.Kit)
end

local function kitData()
	local folder = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = folder and folder:FindFirstChild(TU.Data)
	if m and m:IsA("ModuleScript") then
		local ok, data = pcall(require, m)
		if ok and type(data) == "table" and type(data.Heap) == "table" then return data end
	end
	return nil
end

--- The kit, its data and ChargedRock are all in place: TerraFX hands the Tomb's hooks here. Otherwise it keeps its own.
function Tomb.Available()
	return kitModel() ~= nil and kitData() ~= nil and chargedRock() ~= nil
end

-- THE LAYOUT, read once per kit + data. Each piece's REST is read off the imported kit against ET_Origin (nothing about
-- the kit's assembly is copied into code), then registered onto the data's frame: the data says where each rock and
-- boulder IS and how it moves; the kit says how its pieces sit together. A group's pieces are kept as offsets from
-- their own mean. If the import and the data disagree beyond a yaw + shift (a mirrored axis, a wrong origin), the
-- data's Rel are used instead and that is said once.
local layoutCache = nil

local function halfHeight(cf, size)
	return 0.5 * (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z)
end

local function buildLayout(kit, data)
	local origin = kit:FindFirstChild(TU.Origin, true)
	if not (origin and origin:IsA("BasePart")) then
		origin = nil
		warnOnce("Origin", ("'%s' not found in EarthMagicMeshes.%s -- pieces placed from EarthenTombKitData's Rel"):format(
			TU.Origin, TU.Kit))
	end
	local sources = {}
	for _, d in ipairs(kit:GetDescendants()) do
		if d:IsA("BasePart") and not sources[d.Name] then sources[d.Name] = d end
	end
	local function has(name) return sources[name] ~= nil end
	local missing = 0

	-- every piece of a group: { Name, Kit (rest vs the origin, or nil), Data (rest from the data), Size, Phase, Has* }
	local function collect(list, groupRel)
		local out = {}
		for _, pd in ipairs(type(list) == "table" and list or {}) do
			if type(pd) == "table" and type(pd.Name) == "string" then
				local s = sources[pd.Name]
				if s then
					local rel = typeof(pd.Rel) == "CFrame" and pd.Rel or CFrame.new()
					out[#out + 1] = {
						Name = pd.Name, Size = s.Size, Phase = tonumber(pd.Phase),
						Kit = origin and origin.CFrame:ToObjectSpace(s.CFrame) or nil,
						RelData = rel, GroupRel = groupRel,
						HasBrk = has(pd.Name .. "_Brk"), HasLit = has(pd.Name .. "_Lit"), HasDead = has(pd.Name .. "_Dead"),
					}
				else
					missing += 1
				end
			end
		end
		return out
	end

	local L = { Kit = kit, Data = data, Rocks = {}, Boulders = {}, Pebbles = {},
		Turn = typeof(data.Turn) == "CFrame" and data.Turn or CFrame.Angles(0, math.pi, 0) }
	local rocks, boulders = {}, {}
	for r, rd in ipairs(data.Heap) do
		if type(rd) == "table" then
			local rel = typeof(rd.Rel) == "CFrame" and rd.Rel or nil
			local pieces = collect(rd.Pieces, rel)
			if #pieces > 0 then
				rocks[#rocks + 1] = { Index = r, Ring = math.clamp(math.floor(tonumber(rd.Ring) or 1), 1, 5),
					EruptAt = tonumber(rd.EruptAt), Rel = rel, Pieces = pieces }
			end
		end
	end
	for b, bd in ipairs(type(data.Boulders) == "table" and data.Boulders or {}) do
		if type(bd) == "table" and typeof(bd.From) == "Vector3" and typeof(bd.Gather) == "Vector3"
			and typeof(bd.StopAt) == "Vector3" then
			local pieces = collect(bd.Pieces, nil)
			if #pieces > 0 then
				boulders[#boulders + 1] = { Index = b, TearAt = tonumber(bd.TearAt) or 0.45, From = bd.From,
					Gather = bd.Gather, StopAt = bd.StopAt, Spin = tonumber(bd.Spin),
					Axis = (typeof(bd.Axis) == "Vector3" and bd.Axis.Magnitude > 0.1) and bd.Axis.Unit or nil, Pieces = pieces }
			end
		end
	end
	if #rocks == 0 then
		warnOnce("NoHeap", "EarthenTombKitData's Heap names no piece found in the kit -- the Tomb draws nothing")
		return nil
	end

	-- the data's own rest for a heap piece: the rock's Rel x the piece's Rel (relative to the rock, as the Wall's Coarse
	-- are to their slab) -- or, if the piece Rel turn out to be absolute (their mean far from the rock's), as they are
	for _, rk in ipairs(rocks) do
		local rel = rk.Rel or CFrame.new()
		local sumA, sumB = Vector3.zero, Vector3.zero
		for _, pc in ipairs(rk.Pieces) do
			sumA += (rel * pc.RelData).Position
			sumB += pc.RelData.Position
		end
		local n = #rk.Pieces
		local absolute = rk.Rel ~= nil and (sumB / n - rel.Position).Magnitude < (sumA / n - rel.Position).Magnitude
		for _, pc in ipairs(rk.Pieces) do pc.DataRest = absolute and pc.RelData or rel * pc.RelData end
	end
	for _, bo in ipairs(boulders) do
		for _, pc in ipairs(bo.Pieces) do pc.DataRest = pc.RelData end
	end

	-- REGISTER the import onto the data: the yaw + shift that best carries each rock's kit centre onto its data centre
	local corr, useKit = CFrame.new(), origin ~= nil
	if origin then
		local P, Q = {}, {}
		for _, rk in ipairs(rocks) do
			if rk.Rel then
				local s = Vector3.zero
				for _, pc in ipairs(rk.Pieces) do s += pc.Kit.Position end
				P[#P + 1] = s / #rk.Pieces
				Q[#Q + 1] = rk.Rel.Position
			end
		end
		if #P >= 3 then
			local mp, mq = Vector3.zero, Vector3.zero
			for i = 1, #P do mp += P[i]; mq += Q[i] end
			mp /= #P
			mq /= #Q
			local sc, ss = 0, 0
			for i = 1, #P do
				local p, q = P[i] - mp, Q[i] - mq
				sc += p.X * q.X + p.Z * q.Z
				ss += p.Z * q.X - p.X * q.Z
			end
			local yaw = math.atan2(ss, sc)
			local rot = CFrame.Angles(0, yaw, 0)
			local shift = mq - rot * mp
			local before, after = 0, 0
			for i = 1, #P do
				before += (P[i] - Q[i]).Magnitude
				after += ((rot * P[i] + shift) - Q[i]).Magnitude
			end
			before /= #P
			after /= #P
			if after > 0.6 then
				useKit = false
				warnOnce("Register", ("the kit's pieces and EarthenTombKitData disagree (%.2f studs a rock after the best yaw "
					.. "+ shift) -- using the data's Rel; check ET_Origin and Turn"):format(after))
			elseif before > 0.25 and before > after * 1.5 then
				corr = CFrame.new(shift) * rot
				warnOnce("Shift", ("the kit's pieces sit %.2f studs off EarthenTombKitData -- corrected by %.1f deg and "
					.. "(%.2f, %.2f, %.2f); check ET_Origin and Turn"):format(before, math.deg(yaw), shift.X, shift.Y, shift.Z))
			end
		end
	end
	local function restOf(pc) return (useKit and pc.Kit) and corr * pc.Kit or pc.DataRest end

	local maxVol = 1e-3
	local function finishGroup(pieces, centreOverride)
		local sum = Vector3.zero
		for _, pc in ipairs(pieces) do
			pc.Rest = restOf(pc)
			sum += pc.Rest.Position
			pc.Vol = pc.Size.X * pc.Size.Y * pc.Size.Z
			maxVol = math.max(maxVol, pc.Vol)
		end
		local mean = sum / #pieces
		local top = -math.huge
		for _, pc in ipairs(pieces) do
			pc.Off = CFrame.new(-mean) * pc.Rest
			top = math.max(top, pc.Off.Position.Y + halfHeight(pc.Rest, pc.Size))
		end
		return centreOverride or mean, top
	end
	for _, rk in ipairs(rocks) do
		local centre, top = finishGroup(rk.Pieces, rk.Rel and rk.Rel.Position or nil)
		local ring = rk.Ring
		L.Rocks[#L.Rocks + 1] = {
			Index = rk.Index, Ring = ring, Centre = centre, Pieces = rk.Pieces,
			EruptAt = rk.EruptAt or (0.02 + (ring - 1) * 0.05),
			Travel = math.max(0.3, centre.Y + top + TU.TravelPad),
			Pull = ring <= 3 and -flatUnit(centre, Vector3.zAxis) * TU.Pull or Vector3.zero,
		}
	end
	for _, bo in ipairs(boulders) do
		finishGroup(bo.Pieces, nil)
		L.Boulders[#L.Boulders + 1] = bo
	end
	for _, rk in ipairs(L.Rocks) do for _, pc in ipairs(rk.Pieces) do pc.VolN = pc.Vol / maxVol end end
	for _, bo in ipairs(L.Boulders) do for _, pc in ipairs(bo.Pieces) do pc.VolN = pc.Vol / maxVol end end

	-- the scuffs go where the biggest pieces first land: the ten biggest boulder pieces and the two biggest heap pieces
	local bp, hp = {}, {}
	for _, bo in ipairs(L.Boulders) do for _, pc in ipairs(bo.Pieces) do bp[#bp + 1] = pc end end
	for _, rk in ipairs(L.Rocks) do for _, pc in ipairs(rk.Pieces) do hp[#hp + 1] = pc end end
	table.sort(bp, function(a, b) return a.Vol > b.Vol end)
	table.sort(hp, function(a, b) return a.Vol > b.Vol end)
	for i = 1, math.min(TU.BoulderScuffs, #bp) do bp[i].Scuff = true end
	for i = 1, math.min(TU.Scuffs - TU.BoulderScuffs, #hp) do hp[i].Scuff = true end

	-- the heap rocks the boulders slam into (the film strikes six): for each boulder, the nearest rock above the shins
	-- to where it stops
	for _, bo in ipairs(L.Boulders) do
		local stop = Vector3.new(0, TU.ChestUp, 0) + bo.StopAt
		local best, bestD = nil, math.huge
		for _, rk in ipairs(L.Rocks) do
			if rk.Ring >= 2 then
				local d = (rk.Centre - stop).Magnitude
				if d < bestD then best, bestD = rk, d end
			end
		end
		if best then best.Struck = true end
	end

	-- the slab: its clod, its depth, and the mouth's size from its outline
	local slab = type(data.Slab) == "table" and data.Slab or {}
	local clodName = type(slab.Clod) == "string" and slab.Clod or TU.Clod
	local cs = sources[clodName]
	if cs then
		local rest
		if useKit and origin then
			rest = corr * origin.CFrame:ToObjectSpace(cs.CFrame)
		else
			rest = CFrame.new(0, -cs.Size.Y / 2, 0)
		end
		L.Clod = { Name = clodName, Rest = rest }
	else
		missing += 1
	end
	L.Depth = tonumber(slab.Depth) or 3.95
	local sum, n = 0, 0
	for _, p in ipairs(type(slab.Outline) == "table" and slab.Outline or {}) do
		if typeof(p) == "Vector2" then
			sum += p.Magnitude
			n += 1
		end
	end
	L.MouthR = n > 0 and (sum / n) * 0.97 or 3.0

	for name, s in pairs(sources) do
		if string.match(name, TU.PebblePattern) and s:IsA("BasePart") then L.Pebbles[#L.Pebbles + 1] = name end
	end
	table.sort(L.Pebbles)

	local burst = type(data.Burst) == "table" and data.Burst or {}
	L.HeapOut = range2(burst.HeapOut, TU.HeapOut)
	L.HeapUp = range2(burst.HeapUp, TU.HeapUp)

	if missing > 0 then
		warnOnce("Missing", ("%d piece(s) named in %s are not in EarthMagicMeshes.%s -- they are not drawn"):format(
			missing, TU.Data, TU.Kit))
	end
	return L
end

local function layout()
	local kit, data = kitModel(), kitData()
	if not (kit and data) then return nil end
	if layoutCache and layoutCache.Kit == kit and layoutCache.Data == data then return layoutCache end
	local ok, L = pcall(buildLayout, kit, data)
	if not ok then
		warnOnce("Layout", "could not read the kit: " .. tostring(L))
		return nil
	end
	layoutCache = L
	return L
end

----------------------------------------------------------------------------------------------------
-- pieces, the part count, the moves
----------------------------------------------------------------------------------------------------
local tombs = {}            -- [caster character] = the Tomb being drawn
local moveParts, moveCFs = {}, {}

local function move(p, cf)
	moveParts[#moveParts + 1] = p
	moveCFs[#moveCFs + 1] = cf
end

--- Every shown part of a ChargedRock piece to the move list, the stone at `cf` and the rest where they sit on it.
--- (ChargedRock.Place moves every part; a part this module has not shown is parented to nil, so it is skipped here.)
local function placePiece(pc, cf)
	local s = pc.Stone
	if s.Parent then move(s, cf) end
	local rel = pc.Rel or {}
	for i = 2, #KINDS do
		local p = pc[KINDS[i]]
		if p and p.Parent then move(p, cf * (rel[p] or CFrame.new())) end
	end
end

--- The same, set at once: for a piece shown from a broadcast handler (outside the stepper), so it never draws a frame
--- where the kit left it.
local function placeNow(pc, cf)
	pc.Stone.CFrame = cf
	local rel = pc.Rel or {}
	for i = 2, #KINDS do
		local p = pc[KINDS[i]]
		if p then p.CFrame = cf * (rel[p] or CFrame.new()) end
	end
end

local function show(fx, p)
	if p and p.Parent ~= fx.Folder then
		p.Parent = fx.Folder
		fx.Count += 1
	end
end

local function hide(fx, p)
	if p and fx.Folder and p.Parent == fx.Folder then
		p.Parent = nil
		fx.Count -= 1
	end
end

--- A fresh ChargedRock piece, every part hidden (this module shows them, part by part, against the budget).
local function cloneRaw(fx, name)
	local ok, pc = pcall(CR.Clone, fx.L.Kit, name, fx.Wrap)
	if not (ok and type(pc) == "table" and pc.Stone) then
		if not ok then warnOnce("Clone", "ChargedRock.Clone failed: " .. tostring(pc)) end
		return nil
	end
	for _, k in ipairs(KINDS) do
		local p = pc[k]
		if p then p.Parent = nil end
	end
	fx.Owned[pc] = true
	return pc
end

local function takePiece(fx, name)
	local list = fx.Pre[name]
	local pc = list and table.remove(list)
	return pc or cloneRaw(fx, name)
end

local function releasePiece(fx, pc)
	if not (pc and fx.Owned[pc]) then return end
	fx.Owned[pc] = nil
	for _, k in ipairs(KINDS) do hide(fx, pc[k]) end
	pcall(CR.Release, pc)
end

local function destroyPart(fx, p)
	if not p then return end
	hide(fx, p)
	p:Destroy()
end

----------------------------------------------------------------------------------------------------
-- dust, grit, shakes (VFXLibrary's AFTERSHOCK_KIT: earth only, Roblox's smoke and TR_M1_Grit)
----------------------------------------------------------------------------------------------------
--- `count` particles of `kind` at `at` (a Disc kind from the host's rim, `radius` across it; the rest from its centre,
--- along its Up), sized by `scale` -- Aftershock's asBurst on this cast's own host. `tag` + `extra` make an emitter of
--- their own (wider or faster grit).
local function puff(fx, kind, at, count, scale, radius, tag, extra, min)
	local h = fx.Host
	if not (h and h.Parent) or count <= 0 then return end
	h.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
	if radius then h.Size = Vector3.new(radius * 2, 0.2, radius * 2) end
	scale = math.max(0.1, math.floor((scale or 1) * 10 + 0.5) / 10)
	local key = kind .. (tag or "") .. "@" .. scale
	-- (2026-10-25) a wrap's Dust (SkinCatalog Dust) recolours the kind's Default dust roles, its sequence kept
	-- (ChargedRock.DustColor), merged into a COPY of `extra` (WIDE and BLAST are shared). fx.Emitters is this cast's
	-- own; the wrap's key in the emitter's is belt and braces.
	local dw = fx.Wrap and fx.Wrap.Skin.Dust and fx.Wrap
	if dw then key ..= "#" .. dw.Key end
	local pe = fx.Emitters[key]
	if not pe then
		local cs = dw and not (extra and extra.Color) and CR.DustColor(dw, "A", kind)
		if cs then
			local merged = { Color = cs }
			for f, v in pairs(extra or {}) do merged[f] = v end
			extra = merged
		end
		local ok, res = pcall(VFXLibrary.AftershockBurst, DISC[kind] and h or fx.Point, kind, 0, fx.Thin, extra)
		if not (ok and res) then return end
		pe = res
		pe.Rate = 0
		if scale ~= 1 then
			local keys = {}
			for i, kp in ipairs(pe.Size.Keypoints) do
				keys[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale)
			end
			pe.Size = NumberSequence.new(keys)
			pe.Speed = NumberRange.new(pe.Speed.Min * scale, pe.Speed.Max * scale)
		end
		pe.TimeScale = fx.STS or 1
		fx.Emitters[key] = pe
	end
	local density = (Settings.EffectDensity or 1) * ((fx.Thin and Settings.ThinEnemyVFX) and 0.5 or 1)
	local n = math.max(min or 0, math.floor(count * density + 0.5))   -- (`min`: a telegraph's floor, 2026-10-19 P5B-07)
	if n > 0 then pe:Emit(n) end
	-- (2026-10-25) a wrap's added Layers (Rare+): each layer's Share.Tomb of this puff's own count, from TerraWrap's
	-- pooled hosts at `at` (the raw count: TerraWrap applies Graphics Quality and Reduce Enemy VFX itself, once)
	local sk = fx.Wrap and fx.Wrap.Skin
	if sk and sk.Layers then
		local TW = CR.TerraWrap()
		if TW then pcall(TW.LayerBurst, sk, "Tomb", count, nil, at, fx.Thin) end
	end
end

local BOILS = { 0.1, 0.25, 0.4 }    -- s after the tear: the hole boils dust as the slab leaves it
local WIDE = { SpreadAngle = Vector2.new(70, 70) }
local BLAST = { SpreadAngle = Vector2.new(180, 180), Speed = NumberRange.new(6, 16) }

--- A shake on this client's camera through the Viewmodel's own path (the Camera Shake setting scales it); somebody
--- else's Tomb fades out to nothing at ShakeReach from `at`.
local function shake(fx, pair, at)
	if not (Viewmodel and Viewmodel.Shake) then return end
	local k = 1
	if not fx.Mine and at then
		local cam = workspace.CurrentCamera
		if not cam then return end
		k = 1 - (cam.CFrame.Position - at).Magnitude / TU.ShakeReach
	end
	if k > 0 then Viewmodel.Shake(pair[1] * k, pair[2]) end
end

--- A one-shot beat: true the first time `clock` passes `at`, unless it passed it more than Late ago (a late join).
local function beat(fx, key, at, clock)
	if fx.Beats[key] or clock < at then return false end
	fx.Beats[key] = true
	return clock - at <= TU.Late
end

----------------------------------------------------------------------------------------------------
-- the cast's lifetime
----------------------------------------------------------------------------------------------------
local function newFx(character, victim, L)
	libs()
	local me = Players.LocalPlayer and Players.LocalPlayer.Character
	local fx = { Character = character, Victim = victim, L = L, E = liveTuning(),
		Wrap = CR and CR.WrapOf(character, "EarthenTomb"),   -- the caster's wrap (SkinCatalog), or nil: Default
		Mine = victim ~= nil and victim == me, Count = 0, LT = 0, STS = VFXLibrary.ShotTimeScale(),
		Owned = {}, Pre = {}, PreList = {}, PreIdx = 1, Items = {}, Order = {}, OrderIdx = 1, Rocks = {}, Boulders = {},
		Segments = {}, Pebbles = {}, Flyers = {}, Extra = {}, Scuffs = {}, ScuffsMade = 0, LandPuffs = 0,
		Queue = {}, Beats = {}, Emitters = {}, StonesLeft = 0, LevelAt = 0 }
	fx.Thin = character ~= me and not fx.Mine
	fx.Budget = fx.Thin and TU.MaxPartsThin or TU.MaxParts
	-- (2026-10-25, round 2) a wrap's Stone: the kit's grey copies queued now (ChargedRock; cheap once they are built) --
	-- the pieces the cast clones ahead ask for theirs first
	if fx.Wrap and fx.Wrap.Skin.Stone and type(CR.Prewarm) == "function" then pcall(CR.Prewarm, L.Kit) end
	local folder = Instance.new("Folder")
	folder.Name = "EarthenTomb"
	folder.Parent = fxFolder()
	fx.Folder = folder
	local h = inertPart()
	h.Name = "TombDust"
	h.Transparency = 1
	h.Size = Vector3.new(1, 0.2, 1)
	h.Parent = folder
	fx.Host = h
	fx.Point = Instance.new("Attachment")
	fx.Point.Parent = h
	return fx
end

--- Everything of one Tomb gone: every piece back to ChargedRock's pool, every part of its own destroyed. `abrupt`
--- (TombEnd, an error) takes the dust with it; otherwise the host waits out its puffs.
local function teardown(fx, abrupt)
	if fx.Dead then return end
	fx.Dead = true
	if tombs[fx.Character] == fx then tombs[fx.Character] = nil end
	if fx.Drift then pcall(function() fx.Drift.E.Rate = 0 end) end   -- (2026-10-25, round 2: the folder takes its host)
	local owned = {}
	for pc in pairs(fx.Owned) do owned[#owned + 1] = pc end
	for _, pc in ipairs(owned) do releasePiece(fx, pc) end
	for _, s in ipairs(fx.Segments) do if s.Part then s.Part:Destroy() end end
	for _, s in ipairs(fx.Scuffs) do if s.Part then s.Part:Destroy() end end
	if fx.Mouth then fx.Mouth:Destroy() end
	fx.Segments, fx.Scuffs, fx.Mouth = {}, {}, nil
	local folder = fx.Folder
	if abrupt then
		folder:Destroy()
	else
		task.delay(3.5, function() folder:Destroy() end)
	end
end

-- the one stepper (a Heartbeat connection while anything is drawn)
local conn = nil
local frame -- forward

local function stepAll(dt)
	libs()
	local now = workspace:GetServerTimeNow()
	local sts = VFXLibrary.ShotTimeScale()
	for _, fx in pairs(tombs) do
		local mark = #moveParts
		fx.STS = sts
		local ok, keep = pcall(frame, fx, now, dt * sts)
		if not ok then
			for i = #moveParts, mark + 1, -1 do
				moveParts[i] = nil
				moveCFs[i] = nil
			end
			warnOnce("Step", "the Tomb's look stopped on an error: " .. tostring(keep))
			teardown(fx, true)
		elseif keep == false then
			teardown(fx, false)
		end
	end
	if #moveParts > 0 then
		local ok, err = pcall(workspace.BulkMoveTo, workspace, moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
		if not ok then warnOnce("Move", "BulkMoveTo failed: " .. tostring(err)) end
		table.clear(moveParts)
		table.clear(moveCFs)
	end
	if next(tombs) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

local function ensureStepper()
	if not conn then conn = RunService.Heartbeat:Connect(stepAll) end
end

----------------------------------------------------------------------------------------------------
-- the flown pieces (Aftershock's law: falling at Gravity, bouncing off the floor's plane with Bounce and Slide,
-- tumbling, coming to Rest; one floor probe each, ahead of where it will land; resting pieces are not moved)
----------------------------------------------------------------------------------------------------
local function addScuff(fx, pos, footprint)
	if fx.ScuffsMade >= TU.Scuffs or fx.Count >= fx.Budget then return end
	fx.ScuffsMade += 1
	local size = math.clamp(TU.ScuffK * footprint, TU.ScuffSize[1], TU.ScuffSize[2])
	local p = inertPart()
	p.Name = "TombScuff"
	p.Transparency = 1
	p.Size = Vector3.new(size, 0.05, size)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, fx.FlyRng:NextNumber(0, 2 * math.pi), 0)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = TU.ScuffTexture
	d.Transparency = 1
	-- (2026-10-25) a wrap's Scuff (SkinCatalog Scuff) tints the print: Decal.Color3 multiplies the texture
	local tone = fx.Wrap and fx.Wrap.Skin.Scuff
	if typeof(tone) == "Color3" then d.Color3 = tone end
	d.Parent = p
	show(fx, p)
	fx.Scuffs[#fx.Scuffs + 1] = { Part = p, Decal = d, Born = fx.LT }
end

--- A piece let go: `it` (an item, or a pebble / chip's own record) flies from its CFrame at `v`, spinning at `w`.
local function fling(fx, it, v, w, sinkAt)
	local size = it.P.Size
	local fl = { It = it, PC = it.PC, CF = it.CF, V = v, W = w, Half = size / 2, RefY = fx.FloorY, Phase = "Fly",
		Born = fx.LT, SinkAt = sinkAt, SinkDepth = math.max(size.X, size.Y, size.Z) * 1.2 + 0.3,
		Scuff = it.P.Scuff, Foot = math.max(size.X, size.Z) }
	it.Flyer = fl
	fx.Flyers[#fx.Flyers + 1] = fl
	return fl
end

local function flyStep(fx, fl, dt)
	if fl.Done then return end
	if not (fl.PC and fx.Owned[fl.PC]) then
		fl.Done = true
		return
	end
	if fl.Phase ~= "Sink" and fx.LT >= fl.SinkAt then
		fl.Phase = "Sink"
		fl.SinkFrom = fl.CF
	end
	if fl.Phase == "Sink" then
		local u = (fx.LT - fl.SinkAt) / TU.Sink
		if u >= 1 then
			releasePiece(fx, fl.PC)
			if fl.It then fl.It.Gone = true end
			fl.Done = true
			return
		end
		placePiece(fl.PC, fl.SinkFrom - Vector3.new(0, fl.SinkDepth * u * u, 0))
		return
	end
	if fl.Phase == "Rest" or dt <= 0 then return end
	fl.V -= Vector3.new(0, TU.Gravity * dt, 0)
	local w = fl.W.Magnitude
	local rot = w > 1e-4 and CFrame.fromAxisAngle(fl.W.Unit, w * dt) * fl.CF.Rotation or fl.CF.Rotation
	local pos = fl.CF.Position + fl.V * dt
	-- the floor, probed once: where it will come down on the catch's floor, from just over it
	if not fl.Probed and fl.V.Y < 0 and pos.Y < fl.RefY + 8 then
		fl.Probed = true
		local vy, dy = -fl.V.Y, math.max(0, pos.Y - fl.RefY)
		local tl = (-vy + math.sqrt(vy * vy + 2 * TU.Gravity * dy)) / TU.Gravity
		local land = pos + Vector3.new(fl.V.X, 0, fl.V.Z) * tl
		local hit = probe(land, fl.RefY + TU.ProbeAbove, TU.ProbeDepth)
		fl.Plane = (hit and hit.Normal.Y > 0.5) and hit.Position.Y or (fl.RefY - 60)
	end
	local plane = fl.Plane or (fl.RefY - 60)
	local down = reach(rot, fl.Half)
	if pos.Y - down < plane then
		pos = Vector3.new(pos.X, plane + down, pos.Z)
		if fl.V.Y < 0 then
			if not fl.Landed then
				fl.Landed = true
				local at = Vector3.new(pos.X, plane, pos.Z)
				if fl.Scuff then addScuff(fx, at, fl.Foot) end
				if fl.V.Magnitude > TU.LandSpeed and fx.LandPuffs < TU.LandPuffs then
					fx.LandPuffs += 1
					puff(fx, "Landing", at + Vector3.new(0, 0.3, 0), 1, fl.Scuff and 1.3 or 0.8)
				end
			end
			fl.V = Vector3.new(fl.V.X * TU.Slide, -fl.V.Y * TU.Bounce, fl.V.Z * TU.Slide)
			fl.W *= TU.Slide
		end
		if fl.V.Magnitude < TU.Rest then
			fl.Phase = "Rest"
			fl.V, fl.W = Vector3.zero, Vector3.zero
		end
	end
	fl.CF = CFrame.new(pos) * rot
	placePiece(fl.PC, fl.CF)
	if fl.It then fl.It.CF = fl.CF end
	if fx.LT - fl.Born > 6 and fl.Phase == "Fly" then fl.SinkAt = fx.LT end     -- still falling after 6 s: it left the world
end

----------------------------------------------------------------------------------------------------
-- the budget: which crack strips and break faces draw
----------------------------------------------------------------------------------------------------
--- Plans the strips: before the burst (`after` false) Lit then Dead, boulders first, the heap rocks facing this camera
--- before the far side; after it, the break faces (biggest pieces, boulders first), then any Lit not yet drawn, then
--- Dead. Only the first `room` entries are ever granted, so a strip planned in never loses its place to one planned out.
local function planStrips(fx, after, room)
	local q = {}
	-- (2026-10-25, round 2) an Epic wrap's crystals (ChargedRock CrystalsBaked) take the same room: after the Lit strips,
	-- ahead of the Dead; on your own Tomb none on the boulders or the rings round your head (they would sit at the lens)
	local cw = fx.Wrap and type(fx.Wrap.Skin.CrystalsBaked) == "table" and type(CR.HasCrystal) == "function" and fx.Wrap
	for _, it in ipairs(fx.Items) do
		local P = it.P
		local cry = cw and not (fx.Mine and (it.Boulder or (it.Rock and it.Rock.L.Ring >= 3)))
			and CR.HasCrystal(cw, fx.L.Kit, it.Name)
		if not after then
			if it.Boulder then
				if P.HasLit then q[#q + 1] = { It = it, Kind = "Lit", W = 10 + P.VolN } end
				if P.HasDead then q[#q + 1] = { It = it, Kind = "Dead", W = 4 + P.VolN } end
				if cry then q[#q + 1] = { It = it, Kind = "Crystal", W = 8 + P.VolN } end
			else
				local f = it.Rock.Facing or 0
				if P.HasLit then q[#q + 1] = { It = it, Kind = "Lit", W = 5 + 2 * f + P.VolN * 0.1 } end
				if P.HasDead then q[#q + 1] = { It = it, Kind = "Dead", W = 2 + 2 * f + P.VolN * 0.1 } end
				if cry then q[#q + 1] = { It = it, Kind = "Crystal", W = 4.5 + 2 * f + P.VolN * 0.1 } end
			end
		elseif it.Flyer and it.PC and not it.Gone then
			if P.HasBrk then q[#q + 1] = { It = it, Kind = "Brk", W = (it.Boulder and 20 or 12) + P.VolN } end
			if P.HasLit and not (it.PC.Lit and it.PC.Lit.Parent) then q[#q + 1] = { It = it, Kind = "Lit", W = 6 + P.VolN } end
			if P.HasDead then q[#q + 1] = { It = it, Kind = "Dead", W = 3 + P.VolN } end
			if cry and not (it.PC.Crystal and it.PC.Crystal.Parent) then
				q[#q + 1] = { It = it, Kind = "Crystal", W = 8 + P.VolN }
			end
		end
	end
	table.sort(q, function(a, b) return a.W > b.W end)
	for i = #q, math.max(0, room) + 1, -1 do q[i] = nil end
	fx.Queue = q
end

local function grant(fx)
	local reserve = fx.Thrown and (TU.Scuffs - fx.ScuffsMade) or (fx.StonesLeft + TU.ReserveFX)
	local room = fx.Budget - fx.Count - reserve
	if room <= 0 then return end
	for _, e in ipairs(fx.Queue) do
		if room <= 0 then break end
		if not e.Done then
			local it = e.It
			if it.Gone or not it.PC or not fx.Owned[it.PC] then
				if it.Gone or it.PC then e.Done = true end
			elseif it.Shown then
				local p = it.PC[e.Kind]
				if p and p.Parent ~= fx.Folder then
					-- where it sits on its stone NOW: this frame's moves are already queued without it
					if it.CF then p.CFrame = it.CF * ((it.PC.Rel or {})[p] or CFrame.new()) end
					show(fx, p)
					room -= 1
				end
				e.Done = true
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- the charged rock's levels (charged_rock.py v1.4 through ChargedRock): 0 from the eruption to the slam; the slam's
-- hit flare on the boulders and the heap rocks they strike; at the burst every piece's break flare, cooling to the ember
-- it keeps -- a level it carried into the break decaying under it
----------------------------------------------------------------------------------------------------
local function levelOf(fx, it)
	if it.BreakAt then return CR.AtBreak(it.Sustained or 0, fx.LT - it.BreakAt) end
	if it.HitAt and fx.C and fx.C >= it.HitAt then return CR.AfterHit(fx.C - it.HitAt) end
	return 0
end

local function updateLevels(fx, now)
	local hot = (fx.C ~= nil and fx.Rise ~= nil and fx.C >= fx.Rise - 0.02 and fx.C < fx.Rise + 0.4)
		or (fx.ThrownLT ~= nil and fx.LT - fx.ThrownLT < 0.5)
	local clock = os.clock()
	if not hot and clock - fx.LevelAt < 1 / TU.LevelHz then return end
	fx.LevelAt = clock
	local reduce = Settings.Get and Settings.Get("ReduceFlashing")
	local function apply(it)
		local pc = it.PC
		-- (2026-10-25, round 2: an Epic crystal breathes in SetLevel too -- a piece with one but no strip is levelled)
		if pc and not it.Gone and fx.Owned[pc] and pc.Stone.Parent and (pc.Lit or pc.Brk or pc.Crystal) then
			local lv = levelOf(fx, it)
			if reduce and lv > 0 then lv *= 0.5 end
			CR.SetLevel(pc, lv, now)
		end
	end
	for _, it in ipairs(fx.Items) do apply(it) end
	for _, it in ipairs(fx.Extra) do apply(it) end
end

----------------------------------------------------------------------------------------------------
-- the cast: the crack run
----------------------------------------------------------------------------------------------------
local function addSegment(fx, mid, d, run)
	local w = TU.GapFrom + (TU.GapTo - TU.GapFrom) * clamp01(run / TU.GapRamp)
	local p = inertPart()
	p.Name = "TombGap"
	p.Color = TU.Void
	p.Size = Vector3.new(w, 0.06, TU.SegmentLen)
	local yaw = (fx.SegRng:NextNumber() - 0.5) * 0.24
	local cf = CFrame.lookAt(mid, mid + d) * CFrame.Angles(0, yaw, 0) + Vector3.new(0, 0.02, 0)
	p.CFrame = cf - Vector3.new(0, 0.1, 0)
	show(fx, p)
	fx.Segments[#fx.Segments + 1] = { Part = p, CF = cf, Born = fx.LT }
	-- (2026-10-19, audit P5B-07) the run's dust is its telegraph: at least one of each per segment, whatever the
	-- Graphics Quality or Reduce Enemy VFX (at LOW + thinned both used to round to none)
	puff(fx, "Landing", mid + Vector3.new(0, 0.2, 0), 1, 0.7, nil, nil, nil, 1)
	puff(fx, "Grit", mid + Vector3.new(0, 0.1, 0), 2, 1, nil, nil, nil, 1)
end

-- (2026-10-19, audit P5B-07) the telegraph the port dropped (the old look's TR_Tomb_CrackHead and its Mark): a dark head
-- at the crack's tip, a little wider than the gap, and a mark at the target's feet growing from MarkFrom to MarkTo
-- studs across as the head closes in -- "it is about to reach you" reads with no dust at all. Plain parts, the gap's Void.
local TELL = { HeadW = 0.55, HeadL = 1.1, HeadH = 0.14, MarkFrom = 1.4, MarkTo = 3.6, MarkT = 0.45 }
local function tellStep(fx, goal)
	if not fx.TellHead then
		local h = inertPart()
		h.Name, h.Color, h.Size = "TombHead", TU.Void, Vector3.new(TELL.HeadW, TELL.HeadH, TELL.HeadL)
		local m = inertPart()
		m.Name, m.Shape, m.Color, m.Transparency = "TombMark", Enum.PartType.Cylinder, TU.Void, TELL.MarkT
		fx.TellHead, fx.TellMark = h, m
		fx.TellDist = math.max(1, Vector3.new(goal.X - fx.From.X, 0, goal.Z - fx.From.Z).Magnitude)
		show(fx, h)
		show(fx, m)
	end
	local d = fx.Dir or Vector3.zAxis
	fx.TellHead.CFrame = CFrame.lookAt(fx.HeadAt, fx.HeadAt + d) + Vector3.new(0, 0.05, 0)
	local left = Vector3.new(goal.X - fx.HeadAt.X, 0, goal.Z - fx.HeadAt.Z).Magnitude
	local r = TELL.MarkFrom + (TELL.MarkTo - TELL.MarkFrom) * (1 - math.clamp(left / fx.TellDist, 0, 1))
	fx.TellMark.Size = Vector3.new(0.05, r, r)
	fx.TellMark.CFrame = CFrame.new(goal + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end
local function tellDrop(fx)
	if not fx.TellHead then return end
	destroyPart(fx, fx.TellHead)
	destroyPart(fx, fx.TellMark)
	fx.TellHead, fx.TellMark = nil, nil
end

--- Closes the gap back into the floor, head first, starting `delay` from now.
local function closeSegments(fx, delay)
	local n = #fx.Segments
	for i, s in ipairs(fx.Segments) do
		if not s.CloseAt then s.CloseAt = fx.LT + delay + (n - i) * 0.012 end
	end
end

local function segmentsStep(fx)
	local keep = {}
	for _, s in ipairs(fx.Segments) do
		local gone = false
		if s.CloseAt then
			local u = (fx.LT - s.CloseAt) / 0.22
			if u >= 1 then
				destroyPart(fx, s.Part)
				gone = true
			elseif u > 0 then
				move(s.Part, s.CF - Vector3.new(0, 0.14 * u * u, 0))
			end
		elseif not s.Up then
			local k = clamp01((fx.LT - s.Born) / 0.06)
			move(s.Part, s.CF - Vector3.new(0, 0.1 * (1 - k), 0))
			s.Up = k >= 1
		end
		if not gone then keep[#keep + 1] = s end
	end
	fx.Segments = keep
end

--- The loose pebbles round the feet as the crack reaches them: up out of the cracks, rattling three times.
local function spawnPebbles(fx, centre)
	local L = fx.L
	if #L.Pebbles == 0 then return end
	local rng = fx.SegRng
	for i = 1, TU.Pebbles do
		local name = L.Pebbles[(i - 1) % #L.Pebbles + 1]
		local pc = takePiece(fx, name)
		if pc then
			local a = rng:NextNumber(0, 2 * math.pi)
			local base = floorAt(centre + Vector3.new(math.cos(a), 0, math.sin(a)) * between(rng, TU.PebbleR))
			local rot = CFrame.fromAxisAngle(randUnit(rng), rng:NextNumber(0, math.pi))
			local size = pc.Stone.Size
			local down = reach(rot, size / 2)
			local cf = CFrame.new(base + Vector3.new(0, -0.2 * down, 0)) * rot
			placeNow(pc, cf)
			show(fx, pc.Stone)
			fx.Pebbles[#fx.Pebbles + 1] = { PC = pc, P = { Size = size }, Base = base, Rot = rot, Down = down,
				Y = -1.2 * down, VY = 0, K = 1, Start = fx.LT, CF = cf }
		end
	end
end

local function pebblesStep(fx, dt)
	local rng = fx.SegRng
	for _, pb in ipairs(fx.Pebbles) do
		if not pb.Flyer and fx.Owned[pb.PC] then
			local age = fx.LT - pb.Start
			while TU.PebbleHops[pb.K] and age >= TU.PebbleHops[pb.K] do
				pb.VY = math.max(pb.VY, TU.PebbleKick * rng:NextNumber(0.5, 1))
				pb.K += 1
				pb.Kicked = true
			end
			pb.VY -= TU.Gravity * dt
			pb.Y += pb.VY * dt
			local floorY = pb.Kicked and 0 or -1.2 * pb.Down
			if pb.Y < floorY then
				pb.Y = floorY
				pb.VY = 0
			end
			pb.CF = CFrame.new(pb.Base + Vector3.new(0, pb.Y + pb.Down, 0)) * pb.Rot
			placePiece(pb.PC, pb.CF)
		end
	end
end

--- The pebbles thrown at the tear (out from the feet, up), or settled and sunk on a miss.
local function releasePebbles(fx, centre, thrown)
	local rng = fx.SegRng
	for _, pb in ipairs(fx.Pebbles) do
		if not pb.Flyer and fx.Owned[pb.PC] then
			pb.CF = pb.CF or CFrame.new(pb.Base + Vector3.new(0, pb.Down, 0)) * pb.Rot
			local fl
			if thrown then
				local out = flatUnit(pb.Base - centre, Vector3.xAxis)
				fl = fling(fx, pb, out * between(rng, TU.PebbleOut) + Vector3.new(0, between(rng, TU.PebbleUp), 0),
					randUnit(rng) * between(rng, TU.Spin), fx.LT + between(rng, TU.PebbleSink))
			else
				fl = fling(fx, pb, Vector3.zero, Vector3.zero, fx.LT + 0.1)
				fl.Phase = "Rest"
			end
			fl.RefY, fl.Plane, fl.Probed = pb.Base.Y, pb.Base.Y, true
			pb.Flyer = fl
		end
	end
end

local function castStep(fx, now)
	local E = fx.E
	local t = (now - fx.T0) * fx.STS
	local victim = fx.Victim
	local vr = victim and victim.Parent and victim:FindFirstChild("HumanoidRootPart")
	if vr then fx.Goal = floorAt(vr.Position) end
	local goal = fx.Goal
	-- the head, stepped forward to the fissure's own clock (the live code's loop) -- a late broadcast catches up in one go
	local want = math.clamp(t - fx.Grip, 0, E.MaxTravel)
	local moved = false
	while fx.Sim < want - 1e-4 do
		local dt = math.min(1 / 60, want - fx.Sim)
		fx.Sim += dt
		local to = Vector3.new(goal.X - fx.HeadAt.X, 0, goal.Z - fx.HeadAt.Z)
		local dist = to.Magnitude
		if dist <= fx.Reach then break end
		fx.Dir = to.Unit
		fx.HeadAt += fx.Dir * math.min(fx.Speed * dt, dist - fx.Reach)
		moved = true
	end
	if moved then fx.HeadAt = floorAt(fx.HeadAt) end
	if t >= fx.Grip then
		-- both palms into the ground: a low kick of dust where the crack leaves them
		if beat(fx, "Plant", fx.Grip, t) then
			puff(fx, "Kick", fx.From + Vector3.new(0, 0.15, 0), 4, 1, 1.0)
			shake(fx, TU.ShakePlant, fx.From)
		end
		-- the gap, laid SegmentEvery behind the head wherever it has been
		while true do
			local gap = Vector3.new(fx.HeadAt.X - fx.Last.X, 0, fx.HeadAt.Z - fx.Last.Z)
			if gap.Magnitude < E.SegmentEvery then break end
			local d = gap.Unit
			local nextAt = fx.Last + d * E.SegmentEvery
			local mid = floorAt((fx.Last + nextAt) / 2)
			fx.Run += E.SegmentEvery
			addSegment(fx, mid, d, fx.Run)
			fx.Last = Vector3.new(nextAt.X, mid.Y, nextAt.Z)
		end
		tellStep(fx, goal)                                          -- (2026-10-19, audit P5B-07) the head and the mark
	end
	-- THE SPLIT round the feet as the head reaches them, and the pebbles rattling
	local left = Vector3.new(goal.X - fx.HeadAt.X, 0, goal.Z - fx.HeadAt.Z).Magnitude
	if not fx.Arrived and t >= fx.Grip and left <= fx.Reach + TU.ArriveSlack then
		fx.Arrived = true
		puff(fx, "Kick", goal + Vector3.new(0, 0.15, 0), 5, 1, 1.6)
		puff(fx, "Grit", goal + Vector3.new(0, 0.1, 0), 4, 1, nil, "Wide", WIDE)
		shake(fx, TU.ShakeArrive, goal)
		spawnPebbles(fx, goal)
	end
	if t > fx.Grip + E.MaxTravel + 1.0 then Tomb.Miss(fx.Character) end   -- the verdict never came
end

--- Pre-clones the pieces the catch will need, CloneCap a frame (while the crack runs), so the catch never clones 600
--- parts in one frame; after the catch the same cap keeps cloning ahead of the eruption.
local function cloneAhead(fx)
	local n = 0
	if fx.State == "Cast" then
		while n < TU.CloneCap and fx.PreList[fx.PreIdx] do
			local name = fx.PreList[fx.PreIdx]
			fx.PreIdx += 1
			local pc = cloneRaw(fx, name)
			if pc then
				fx.Pre[name] = fx.Pre[name] or {}
				table.insert(fx.Pre[name], pc)
			end
			n += 1
		end
	elseif fx.State == "Rise" then
		while n < TU.CloneCap and fx.Order[fx.OrderIdx] do
			local it = fx.Order[fx.OrderIdx]
			fx.OrderIdx += 1
			if not it.PC and not it.Gone then
				it.PC = takePiece(fx, it.Name)
				n += 1
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- the catch: the tear, the heap, the boulders
----------------------------------------------------------------------------------------------------
local function showItem(fx, it)
	if it.Shown or it.Gone then return end
	it.Shown = true
	fx.StonesLeft -= 1
	if not it.PC then it.PC = takePiece(fx, it.Name) end
	local pc = it.PC
	if not pc then return end
	if it.P.Phase then pc.Phase = it.P.Phase end
	show(fx, pc.Stone)
	CR.SetLevel(pc, 0, workspace:GetServerTimeNow())
end

--- Builds the cast's rocks and boulders off the layout. Every random draw is made for EVERY rock and boulder in the
--- layout's order, drawn here or not, from a seed every client shares (the catch's T0), so every client's heap tumbles
--- and every boulder flies the same way.
local function buildCast(fx)
	local L, rng, E = fx.L, fx.Rng, fx.E
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position
	local ground = fx.CF * L.Turn
	fx.EruptTime = E.EncaseEruptTime or TU.EruptTime
	for _, rk in ipairs(L.Rocks) do
		local axis = randUnit(rng)
		local rock = { L = rk, Axis = axis, Items = {}, Hidden = (fx.Mine and TU.OwnHideRings[rk.Ring]) and true or false }
		if not rock.Hidden then
			-- the heap is sealed when its last drawn rock is home: grit and a shudder at the chest
			fx.SealedAt = math.max(fx.SealedAt or 0, rk.EruptAt + fx.EruptTime)
			local wc = ground * rk.Centre
			rock.Facing = eye and flatUnit(wc - fx.CF.Position):Dot(flatUnit(eye - wc)) or 0
			for _, pd in ipairs(rk.Pieces) do
				local it = { Name = pd.Name, P = pd, Rock = rock, ShowAt = rk.EruptAt - TU.ShowLead }
				rock.Items[#rock.Items + 1] = it
				fx.Items[#fx.Items + 1] = it
			end
		end
		fx.Rocks[#fx.Rocks + 1] = rock
	end
	local tconv = fx.Rise - E.Converge
	local chestConv = Vector3.new(0, TU.Lift + fx.Height * rise01(tconv / fx.Rise) + TU.ChestUp, 0)
	for _, bl in ipairs(L.Boulders) do
		local axis = randUnit(rng)
		local spin = rng:NextNumber(TU.BoulderSpin[1], TU.BoulderSpin[2])
		local up = between(rng, TU.CtrlUp)
		local toS = bl.Gather - chestConv
		local stop = bl.StopAt.Magnitude
		local bo = { L = bl, Axis = bl.Axis or axis, Spin = bl.Spin or spin, Items = {},
			TearAt = math.min(bl.TearAt, tconv - 0.15),
			Ctrl = Vector3.new(bl.From.X, bl.Gather.Y + up, bl.From.Z),
			R0 = math.max(toS.Magnitude, 0.1), DirS = toS.Magnitude > 1e-3 and toS.Unit or Vector3.yAxis,
			DirE = stop > 1e-3 and bl.StopAt.Unit or Vector3.yAxis,
			REnd = fx.Mine and math.max(stop, TU.OwnStop) or stop }
		for _, pd in ipairs(bl.Pieces) do
			local it = { Name = pd.Name, P = pd, Boulder = bo, ShowAt = bo.TearAt - 0.02 }
			bo.Items[#bo.Items + 1] = it
			fx.Items[#fx.Items + 1] = it
		end
		fx.Boulders[#fx.Boulders + 1] = bo
	end
	fx.StonesLeft = #fx.Items
	for i, it in ipairs(fx.Items) do fx.Order[i] = it end
	table.sort(fx.Order, function(a, b) return a.ShowAt < b.ShowAt end)
	-- the hit flare's targets: the boulders, and the rocks they slam into
	for _, rock in ipairs(fx.Rocks) do
		if rock.L.Struck then for _, it in ipairs(rock.Items) do it.HitAt = fx.Rise end end
	end
	for _, bo in ipairs(fx.Boulders) do for _, it in ipairs(bo.Items) do it.HitAt = fx.Rise end end
end

--- The slab's height (studs over the floor) at catch time `c`, and the descent's age (nil before it).
local function slabHeight(fx, c, now)
	if fx.DescT0 then
		local age = (now - fx.DescT0) * fx.STS
		local u = clamp01(age / fx.DescTime)
		return fx.DescFrom * (1 - u * u), age, u
	end
	return fx.Height * rise01(c / fx.Rise), nil, nil
end

--- Everything thrown off at once: the burst (`power` 1) or an escape (`crumble`: the heap at BreakPower, the boulders
--- coming apart where they are). Every draw from the burst's own seed, in the layout's order.
local function throwAll(fx, crumble)
	local rng = fx.FlyRng
	local power = crumble and TU.BreakPower or 1
	local L = fx.L
	local toCaster = fx.CF.LookVector
	local axisPos = fx.CF.Position
	local chest = fx.CF.Position + Vector3.new(0, TU.Lift + (fx.H or 0) + TU.ChestUp, 0)
	local sinkBase = fx.LT + TU.RubbleHold
	fx.Thrown, fx.ThrownLT = true, fx.LT
	-- the levels first: whatever a piece carries into the break decays under it
	for _, it in ipairs(fx.Items) do
		if it.Shown and it.PC then
			it.Sustained = levelOf(fx, it)
			it.BreakAt = fx.LT
		end
	end
	for _, rock in ipairs(fx.Rocks) do
		rock.Thrown = true
		local byName = {}
		for _, it in ipairs(rock.Items) do byName[it.Name] = it end
		for _, pd in ipairs(rock.L.Pieces) do
			local out, up = between(rng, L.HeapOut), between(rng, L.HeapUp)
			local jit, spin = randUnit(rng), randUnit(rng) * between(rng, TU.Spin)
			local stagger = rng:NextNumber(0, TU.SinkStagger)
			local it = byName[pd.Name]
			if it and it.Shown and it.PC and it.CF and fx.Owned[it.PC] then
				local dirw = flatUnit(it.CF.Position - axisPos, toCaster)
				if dirw:Dot(toCaster) > TU.TowardDot then out *= TU.TowardCaster end
				local v = (dirw * out + Vector3.new(0, up + TU.RingUp * (rock.L.Ring - 1), 0) + jit * TU.HeapJitter) * power
				fling(fx, it, v, spin, sinkBase + stagger)
			end
		end
	end
	for _, bo in ipairs(fx.Boulders) do
		bo.Thrown = true
		for _, it in ipairs(bo.Items) do
			local out = between(rng, crumble and TU.CrumbleOut or TU.BoulderOut)
			local up = between(rng, crumble and TU.CrumbleUp or TU.BoulderUp)
			local jit, spin = randUnit(rng), randUnit(rng) * between(rng, TU.Spin)
			local stagger = rng:NextNumber(0, TU.SinkStagger)
			if it.Shown and it.PC and it.CF and fx.Owned[it.PC] then
				local line = flatUnit((bo.CF and bo.CF.Position or it.CF.Position) - chest, toCaster)
				local v = line * out + Vector3.new(0, up, 0) + jit * (crumble and 0.5 or TU.BoulderJitter)
				fling(fx, it, v, spin, sinkBase + stagger)
			end
		end
	end
	-- anything not yet drawn never will be
	for _, it in ipairs(fx.Items) do
		if not it.Shown then
			it.Gone = true
			if it.PC then releasePiece(fx, it.PC) end
		end
	end
	fx.StonesLeft = 0
	-- the budget turns over: the Dead strips go, the break faces (the flare) come in
	for _, it in ipairs(fx.Items) do
		if it.PC and not it.Gone then hide(fx, it.PC.Dead) end
	end
end

--- The splinters drawn as parts: the kit's pebbles, thrown flat and fast off the chest, following the break's curve.
local function throwChips(fx, at)
	local L = fx.L
	if #L.Pebbles == 0 then return end
	local rng = fx.FlyRng
	local n = math.floor(TU.Chips * (Settings.EffectDensity or 1) * ((fx.Thin and Settings.ThinEnemyVFX) and 0.5 or 1) + 0.5)   -- (2026-10-19, audit P5B-16)
	for i = 1, n do
		if fx.Count >= fx.Budget - (TU.Scuffs - fx.ScuffsMade) then break end
		local pc = takePiece(fx, L.Pebbles[(i - 1) % #L.Pebbles + 1])
		if pc then
			local a = rng:NextNumber(0, 2 * math.pi)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local it = { PC = pc, P = { Size = pc.Stone.Size }, CF = CFrame.new(at + dir * 0.6) * CFrame.Angles(a, a * 2, 0),
				BreakAt = fx.LT, Sustained = 0, Shown = true }
			placeNow(pc, it.CF)
			show(fx, pc.Stone)
			fx.Extra[#fx.Extra + 1] = it
			fling(fx, it, dir * between(rng, TU.ChipOut) + Vector3.new(0, between(rng, TU.ChipUp), 0),
				randUnit(rng) * rng:NextNumber(8, 16), fx.LT + TU.RubbleHold + rng:NextNumber(0, TU.SinkStagger))
		end
	end
end

local function catchStep(fx, now, dt)
	local L, E = fx.L, fx.E
	local c = (now - fx.CatchT0) * fx.STS
	fx.C = c
	local h, descAge, descU = slabHeight(fx, c, now)
	fx.H = h
	local floor = fx.CF.Position
	local ground = fx.CF * L.Turn

	-- THE SLAB'S OWN MOTION: the tear's shudder, the rocking in flight, the burst's ring, the seat's thud, the sink away
	local dy = 0
	if c < TU.TrembleUntil + 0.06 then
		dy += TU.Tremble * math.sin(c * 2 * math.pi * TU.TrembleHz) * (1 - span(c, TU.TrembleUntil, TU.TrembleUntil + 0.06))
	end
	local rockK = smooth(c / TU.RockIn) * (descAge and (1 - smooth(descAge / TU.RockOut)) or 1)
	if fx.SeatLT then rockK = 0 end
	local ax = math.rad(TU.RockX) * math.sin(2.3 * c + 0.4) * rockK
	local ay = math.rad(TU.RockY) * math.sin(1.7 * c + 1.9) * rockK
	if fx.ThrownLT and not fx.Escaped then
		local a = fx.LT - fx.ThrownLT
		dy -= TU.BurstDip * math.exp(-a / TU.BurstDipTau) * math.sin(TU.BurstDipW * a)
	end
	if fx.SeatLT then
		local b = fx.LT - fx.SeatLT
		dy -= TU.Thud * math.exp(-b / TU.ThudTau) * math.sin(math.min(b / 0.04, 1) * math.pi)
		local su = span(fx.LT, fx.SeatLT + TU.ClodHold, fx.SeatLT + TU.ClodHold + TU.ClodSink)
		dy -= TU.ClodDepth * su * su
	end
	local slab = fx.CF * CFrame.new(0, TU.Lift + h + dy, 0) * CFrame.Angles(ax, ay, 0) * L.Turn
	-- (2026-10-25, round 2) a Mythic Tomb's Drift rides the slab, on through the rise and the hold
	local dr = fx.Drift
	if dr then
		move(dr.Host, slab * CFrame.new(0, TU.DriftUp, 0))
		local on = (fx.State == "Rise" or fx.State == "Hold") and not fx.DescT0
		if on ~= dr.On then
			dr.On = on
			pcall(function() dr.E.Rate = on and dr.Rate or 0 end)
		end
	end

	-- THE TEAR (c = 0): the slab torn loose, dust off the seam, the hole's dark mouth
	if beat(fx, "Tear", 0, c) then
		puff(fx, "Skirt", floor + Vector3.new(0, 0.2, 0), 12, 1, 3.2)
		puff(fx, "Grit", floor + Vector3.new(0, 0.2, 0), 24, 1, nil, "Wide", WIDE)
		shake(fx, TU.ShakeTear, floor)
	end
	for i, at in ipairs(BOILS) do
		if beat(fx, "Boil" .. i, at, c) and not fx.DescT0 then puff(fx, "Cloud", floor + Vector3.new(0, 0.3, 0), 1, 0.8) end
	end
	-- earth falling off the slab's underside as it climbs
	if c < 0.8 and not fx.DescT0 then
		fx.NextUnder = fx.NextUnder or 0.05
		if c >= fx.NextUnder then
			if c - fx.NextUnder <= TU.Late then
				local under = (slab * CFrame.new(0, -L.Depth * 0.75, 0)).Position
				puff(fx, "Grit", under, 2, 1)
				puff(fx, "Landing", under, 1, 0.8)
			end
			fx.NextUnder = c + 0.12
		end
	end
	if fx.Clod and fx.Clod.PC and fx.Owned[fx.Clod.PC] then placePiece(fx.Clod.PC, slab * L.Clod.Rest) end

	-- THE HEAP: each rock punched up from under the slab's top at its own spot, through the crust, tumbling into its
	-- place; grit as each ring breaks out, more at the chest once the last is in
	for _, rock in ipairs(fx.Rocks) do
		if not rock.Hidden and not rock.Thrown then
			local rk = rock.L
			local u = (c - rk.EruptAt) / fx.EruptTime
			if c >= rk.EruptAt - TU.ShowLead then
				for _, it in ipairs(rock.Items) do showItem(fx, it) end
				local cf
				if u >= 1 then
					cf = slab * CFrame.new(rk.Centre)
				else
					local p = punch(u)
					local pos = rk.Centre + Vector3.new(0, -rk.Travel * (1 - p), 0) + rk.Pull * (1 - p)
					cf = slab * CFrame.new(pos) * CFrame.fromAxisAngle(rock.Axis, TU.Tumble * (1 - math.min(p, 1)))
				end
				for _, it in ipairs(rock.Items) do
					if it.PC and not it.Flyer and fx.Owned[it.PC] then
						it.CF = cf * it.P.Off
						placePiece(it.PC, it.CF)
					end
				end
				if u >= 0 and beat(fx, "Ring" .. rk.Ring, rk.EruptAt, c) then
					local at = (slab * CFrame.new(0, math.max(0, rk.Centre.Y), 0)).Position
					local k = (fx.Mine and rk.Ring >= 3) and TU.FPThin or 1
					puff(fx, "Grit", at, 4 * k, 1, nil, "Wide", WIDE)
					puff(fx, "Landing", at, 1, 0.8)
				end
			end
		end
	end
	if fx.SealedAt and not fx.Thrown and beat(fx, "Sealed", fx.SealedAt, c) then
		local chest = (slab * CFrame.new(0, TU.ChestUp, 0)).Position
		local k = fx.Mine and TU.FPThin or 1
		puff(fx, "Landing", chest, 2 * k, 1)
		puff(fx, "Grit", chest, 5 * k, 1, nil, "Wide", WIDE)
		shake(fx, TU.ShakeSealed, chest)
	end

	-- THE BOULDERS: torn out of the ground round them and up to their gather points, then (Converge before the top)
	-- closing on the chest from there, faster and faster, about the climbing chest; their spin frozen at the slam
	local tconv = fx.Rise - E.Converge
	local chestK = Vector3.new(0, TU.Lift + h + TU.ChestUp, 0)
	for _, bo in ipairs(fx.Boulders) do
		if not bo.Thrown then
			local bl = bo.L
			if c >= bo.TearAt - 0.02 then
				for _, it in ipairs(bo.Items) do showItem(fx, it) end
				local pos
				if c < tconv then
					local v = clamp01((c - bo.TearAt) / (tconv - bo.TearAt))
					pos = bez(bl.From, bo.Ctrl, bl.Gather, 1 - (1 - v) ^ 2)
				else
					local e = clamp01((c - tconv) / E.Converge)
					local r = bo.REnd + (bo.R0 - bo.REnd) * (1 - e * e)
					local dir = bo.DirS:Lerp(bo.DirE, e)
					dir = dir.Magnitude > 1e-3 and dir.Unit or bo.DirE
					pos = chestK + dir * r
				end
				local spinT = math.max(0, math.min(c, fx.Rise) - bo.TearAt)
				bo.CF = ground * CFrame.new(pos) * CFrame.fromAxisAngle(bo.Axis, bo.Spin * spinT)
				for _, it in ipairs(bo.Items) do
					if it.PC and not it.Flyer and fx.Owned[it.PC] then
						it.CF = bo.CF * it.P.Off
						placePiece(it.PC, it.CF)
					end
				end
				if beat(fx, "Tear" .. bl.Index, bo.TearAt, c) then
					local at = ground * Vector3.new(bl.From.X, 0, bl.From.Z) + Vector3.new(0, 0.3, 0)
					puff(fx, "Landing", at, 3, 1.4)
					puff(fx, "Grit", at, 6, 1, nil, "Wide", WIDE)
				end
			end
		end
	end
	-- THE SLAM: the boulders home on the heap at the top (their hit flare is in levelOf)
	if fx.State == "Rise" and #fx.Boulders > 0 and beat(fx, "Slam", fx.Rise, c) then
		local chest = (ground * chestK)
		shake(fx, TU.ShakeTop, chest)
		for _, bo in ipairs(fx.Boulders) do
			if bo.CF then
				puff(fx, "Landing", bo.CF.Position, 1, 1)
				puff(fx, "Grit", bo.CF.Position, 2, 1, nil, "Wide", WIDE)
			end
		end
	end

	-- THE DESCENT: seated home -- the thud, the skirt of dust; anything still riding it goes down with it
	if descU and descU >= 1 and not fx.SeatLT then
		fx.SeatLT = fx.LT
		if (now - fx.DescT0) * fx.STS - fx.DescTime <= TU.Late then
			puff(fx, "Skirt", floor + Vector3.new(0, 0.2, 0), 10, 1, 3.3)
			puff(fx, "Grit", floor + Vector3.new(0, 0.2, 0), 10, 1, nil, "Wide", WIDE)
			puff(fx, "Haze", floor + Vector3.new(0, 0.3, 0), 2, 1, 4)
			shake(fx, TU.ShakeLand, floor)
		end
		for _, bo in ipairs(fx.Boulders) do
			if not bo.Thrown then
				for _, it in ipairs(bo.Items) do if it.PC then releasePiece(fx, it.PC) end it.Gone = true end
				bo.Thrown = true
			end
		end
	end
	if fx.SeatLT then
		local sinkAt = fx.SeatLT + TU.ClodHold
		if fx.LT >= sinkAt + TU.ClodSink and not fx.ClodGone then
			fx.ClodGone = true
			if fx.Clod and fx.Clod.PC then releasePiece(fx, fx.Clod.PC) end
			for _, it in ipairs(fx.Items) do
				if not it.Flyer and not it.Gone then
					it.Gone = true
					if it.PC then releasePiece(fx, it.PC) end
				end
			end
		end
		-- THE MOUTH heals: it fades as the slab sinks away
		if fx.Mouth then
			local hu = span(fx.LT, sinkAt + TU.HealDelay, sinkAt + TU.HealDelay + TU.Heal)
			if hu >= 1 then
				destroyPart(fx, fx.Mouth)
				fx.Mouth = nil
			else
				fx.Mouth.Transparency = smooth(hu)
			end
		end
	end

	-- the verdict never came (the live watchdog): a Tomb left standing with no descent is ended outright
	if not fx.DescT0 and c > fx.Rise + E.BurstHold + E.DescendTime + 1.5 then
		return false
	end
	return true
end

local function scuffsStep(fx)
	local keep = {}
	for _, s in ipairs(fx.Scuffs) do
		local a = fx.LT - s.Born
		if a >= TU.ScuffOut[2] then
			destroyPart(fx, s.Part)
		else
			local alpha = TU.ScuffAlpha * span(a, TU.ScuffIn[1], TU.ScuffIn[2]) * (1 - span(a, TU.ScuffOut[1], TU.ScuffOut[2]))
			s.Decal.Transparency = 1 - alpha
			keep[#keep + 1] = s
		end
	end
	fx.Scuffs = keep
end

frame = function(fx, now, dt)
	if fx.Dead then return false end
	fx.LT += dt
	cloneAhead(fx)
	if fx.State == "Cast" then castStep(fx, now) end
	if fx.Dead then return false end
	if fx.State ~= "Cast" then tellDrop(fx) end                   -- (2026-10-19, audit P5B-07) gone on the catch or miss
	segmentsStep(fx)
	pebblesStep(fx, dt)
	if fx.CatchT0 then
		if catchStep(fx, now, dt) == false then return false end
	end
	local alive = 0
	for _, fl in ipairs(fx.Flyers) do
		flyStep(fx, fl, dt)
		if not fl.Done then alive += 1 end
	end
	if alive == 0 and #fx.Flyers > 0 then fx.Flyers = {} end
	scuffsStep(fx)
	if CR then updateLevels(fx, now) end
	grant(fx)
	-- done: a miss once its gap and pebbles are gone; a Tomb once it has sunk away, healed and its rubble has gone
	if fx.State == "Missed" then
		return #fx.Segments > 0 or alive > 0
	end
	if fx.CatchT0 and fx.ClodGone and not fx.Mouth and alive == 0 and #fx.Scuffs == 0 and #fx.Segments == 0 then
		return false
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- the hooks (TerraFX's TombCast ... TombEnd hand over here; the same arguments as the live functions)
----------------------------------------------------------------------------------------------------
--- Everything of a Tomb's still standing, gone at once (a new cast by the same caster, or a caster who left).
function Tomb.End(character)
	local fx = tombs[character]
	if fx then teardown(fx, true) end
end

--- CAST: the lock is on `victim`; after `grip`, the crack leaves `from` (Terra's feet) and homes on them at `speed`.
function Tomb.Cast(character, victim, from, T0, grip, speed, reach)
	libs()
	Tomb.End(character)
	if not chargedRock() then return end
	local L = layout()
	local vroot = victim and victim:FindFirstChild("HumanoidRootPart")
	if not (L and vroot and typeof(from) == "Vector3") then return end
	local fx = newFx(character, victim, L)
	local E = fx.E
	fx.State, fx.T0 = "Cast", T0 or workspace:GetServerTimeNow()
	fx.Grip, fx.Speed, fx.Reach = grip or E.GripTime, speed or E.FissureSpeed, reach or E.CatchReach
	fx.From, fx.HeadAt, fx.Last, fx.Sim, fx.Run = from, from, from, 0, 0
	fx.Dir = flatUnit(vroot.Position - from)
	fx.Goal = floorAt(vroot.Position)
	fx.SegRng = Random.new()
	-- what the catch will need, in the order it will need it: the clod, the pebbles, the heap by eruption, the boulders
	local list = fx.PreList
	if L.Clod then list[#list + 1] = L.Clod.Name end
	for i = 1, (#L.Pebbles > 0) and TU.Pebbles or 0 do list[#list + 1] = L.Pebbles[(i - 1) % #L.Pebbles + 1] end
	local rocks = table.clone(L.Rocks)
	table.sort(rocks, function(a, b) return a.EruptAt < b.EruptAt end)
	for _, rk in ipairs(rocks) do
		if not (fx.Mine and TU.OwnHideRings[rk.Ring]) then
			for _, pd in ipairs(rk.Pieces) do list[#list + 1] = pd.Name end
		end
	end
	for _, bo in ipairs(L.Boulders) do for _, pd in ipairs(bo.Pieces) do list[#list + 1] = pd.Name end end
	tombs[character] = fx
	ensureStepper()
end

--- DODGED (or called off): the gap closes back into the floor, head first, and the pebbles settle and sink.
function Tomb.Miss(character, at)
	libs()
	local fx = tombs[character]
	if not fx then return end
	if fx.State ~= "Cast" then
		-- the server sends TombMiss from whatever phase its error recovery ran in (the live 2026-09-21 fix): end it
		teardown(fx, true)
		return
	end
	fx.State = "Missed"
	local tip = typeof(at) == "Vector3" and at or fx.HeadAt
	puff(fx, "Grit", tip + Vector3.new(0, 0.3, 0), 10, 1, nil, "Wide", WIDE)
	puff(fx, "Landing", tip + Vector3.new(0, 0.3, 0), 2, 1)
	closeSegments(fx, 0)
	releasePebbles(fx, fx.Goal or tip, false)
	for _, list in pairs(fx.Pre) do
		for _, pc in ipairs(list) do releasePiece(fx, pc) end
	end
	fx.Pre = {}
end

--- CATCH: the slab tears loose under the target at `at` (the heap laid round them facing `face`, toward Terra) and
--- climbs `height` studs over `rise` s by TombRise.
function Tomb.Catch(character, victim, at, face, T0, rise, height)
	libs()
	if typeof(at) ~= "Vector3" then return end
	local L = layout()
	local fx = tombs[character]
	if not (L and chargedRock()) then
		if fx then teardown(fx, true) end
		return
	end
	local E = liveTuning()
	T0 = T0 or workspace:GetServerTimeNow()
	rise, height = rise or E.RiseTime, height or E.RiseHeight
	-- a late join past the top: the burst has gone, draw nothing (the live rule: nothing past the effect's end)
	if (workspace:GetServerTimeNow() - T0) * VFXLibrary.ShotTimeScale() > rise then
		if fx then teardown(fx, true) end
		return
	end
	if fx and fx.State ~= "Cast" then
		teardown(fx, true)
		fx = nil
	end
	if not fx then
		fx = newFx(character, victim, L)
		fx.SegRng = Random.new()
		tombs[character] = fx
	end
	local me = Players.LocalPlayer and Players.LocalPlayer.Character
	fx.Victim = victim or fx.Victim
	fx.Mine = fx.Victim ~= nil and fx.Victim == me
	fx.Thin = character ~= me and not fx.Mine
	fx.Budget = fx.Thin and TU.MaxPartsThin or TU.MaxParts
	fx.E = E
	fx.State, fx.CatchT0, fx.Rise, fx.Height = "Rise", T0, math.max(0.1, rise), height
	fx.CF = CFrame.lookAt(at, at + flatUnit(typeof(face) == "Vector3" and face or Vector3.zAxis))
	fx.FloorY = at.Y
	local seed = math.floor((T0 * 1000) % 2147483646) + 1
	fx.Rng, fx.FlyRng = Random.new(seed), Random.new(seed + 7919)
	-- the crack has done its work: it closes, head first; the split happens now if the head had not got there
	closeSegments(fx, 0.1)
	if not fx.Arrived then
		fx.Arrived = true
		puff(fx, "Kick", at + Vector3.new(0, 0.15, 0), 5, 1, 1.6)
		if #fx.Pebbles == 0 and (workspace:GetServerTimeNow() - T0) * VFXLibrary.ShotTimeScale() <= TU.Late then
			spawnPebbles(fx, at)
		end
	end
	releasePebbles(fx, at, true)
	buildCast(fx)
	-- the clod and the mouth of its hole
	if L.Clod then
		local pc = takePiece(fx, L.Clod.Name)
		if pc then
			placeNow(pc, fx.CF * CFrame.new(0, TU.Lift, 0) * L.Turn * L.Clod.Rest)
			show(fx, pc.Stone)
			fx.Clod = { PC = pc }
		end
	end
	local m = inertPart()
	m.Name = "TombMouth"
	m.Shape = Enum.PartType.Cylinder
	m.Color = TU.Void
	m.Size = Vector3.new(0.04, L.MouthR * 2, L.MouthR * 2)
	m.CFrame = fx.CF * CFrame.new(0, TU.Lift * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	show(fx, m)
	fx.Mouth = m
	-- (2026-10-25, round 2) MYTHIC Drift: star embers rising off the risen pillar -- TerraWrap's emitter on a host round
	-- the heap (catchStep moves and rates it); never on your own Tomb (it would sit at the lens); gone with the folder
	local sk = fx.Wrap and fx.Wrap.Skin
	if sk and type(sk.Drift) == "table" and not fx.Mine and not fx.Drift then
		local TW = CR.TerraWrap and CR.TerraWrap()
		if TW and type(TW.DriftSet) == "function" then
			local dh = inertPart()
			dh.Name = "TombDrift"
			dh.Transparency = 1
			dh.Size = TU.DriftSize
			dh.CFrame = fx.CF * CFrame.new(0, TU.Lift + TU.DriftUp, 0)
			dh.Parent = fx.Folder
			local ok, pe = pcall(TW.DriftSet, sk, dh, fx.Thin)
			if ok and typeof(pe) == "Instance" and pe:IsA("ParticleEmitter") then
				fx.Drift = { Host = dh, E = pe, Rate = pe.Rate, On = false }
				pe.Rate = 0
			else
				dh:Destroy()
			end
		end
	end
	-- the strips before the burst: what is left after every stone, the clod, the mouth and the chips' and scuffs' room
	planStrips(fx, false, fx.Budget - #fx.Items - 2 - TU.ReserveFX)
	ensureStepper()
end

--- GOT OUT: the heap is thrown off (gentler than the burst's) and the boulders come apart where they are.
function Tomb.Break(character, reason)
	libs()
	local fx = tombs[character]
	if not (fx and fx.CatchT0) or fx.State ~= "Rise" or fx.Thrown then return end
	fx.State, fx.Escaped = "Broken", true
	throwAll(fx, true)
	local chest = fx.CF.Position + Vector3.new(0, TU.Lift + (fx.H or 0) + TU.ChestUp, 0)
	puff(fx, "Grit", chest, 12, 1, nil, "Wide", WIDE)
	puff(fx, "Landing", chest, 3, 1.2)
	planStrips(fx, true, fx.Budget - fx.Count - TU.Scuffs)
end

--- BURST: the hero moment -- the heap and the boulders thrown off the target, their breaks flaring and cooling to embers.
function Tomb.Burst(character, position, hit)
	libs()
	local fx = tombs[character]
	if not (fx and fx.CatchT0) or fx.State ~= "Rise" or fx.Thrown then return end
	fx.State = "Hold"
	throwAll(fx, false)
	local chest = fx.CF.Position + Vector3.new(0, TU.Lift + (fx.H or 0) + TU.ChestUp, 0)
	local floor = fx.CF.Position
	local k = fx.Mine and TU.FPThin or 1
	puff(fx, "Cloud", chest, 5 * k, 1)
	puff(fx, "Grit", chest, 40 * k, 1, nil, "Blast", BLAST)
	puff(fx, "Skirt", floor + Vector3.new(0, 0.2, 0), 6, 1, 3)
	puff(fx, "Haze", floor + Vector3.new(0, 0.3, 0), 3, 1, 4)
	shake(fx, TU.ShakeBurst, chest)
	shake(fx, TU.ShakeRumble, chest)
	-- (2026-10-25, round 2) MYTHIC Shock: the burst's ring on the floor under the pillar (TerraWrap draws it by the
	-- settings: thinner / off at LOW, no flash under Reduce Flashing)
	local sk = fx.Wrap and fx.Wrap.Skin
	local R = sk and type(sk.Shock) == "table" and type(sk.Shock.Radius) == "table" and tonumber(sk.Shock.Radius.Tomb)
	if R and R > 0 then
		local TW = CR.TerraWrap and CR.TerraWrap()
		if TW and type(TW.Shockwave) == "function" then
			pcall(TW.Shockwave, sk, CFrame.new(floor + Vector3.new(0, 0.03, 0)), R, fx.Thin)
		end
	end
	throwChips(fx, chest)
	planStrips(fx, true, fx.Budget - fx.Count - (TU.Scuffs - fx.ScuffsMade))
end

--- DESCENT: the slab comes down from `from` studs over `time` (with the target on it, or empty after an escape).
function Tomb.Descend(character, T0, time, from)
	libs()
	local fx = tombs[character]
	if not fx then return end
	if fx.State == "Cast" then
		Tomb.Miss(character)
		return
	end
	if not fx.CatchT0 or fx.DescT0 then return end
	fx.DescT0 = T0 or workspace:GetServerTimeNow()
	fx.DescTime = math.max(0.05, time or fx.E.DescendTime)
	fx.DescFrom = fx.H or from or 0
end

return Tomb
