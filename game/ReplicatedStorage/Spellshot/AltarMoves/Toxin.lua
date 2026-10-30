--[[
	AltarMoves_Toxin  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Toxin

	THE LOADOUT SHOWCASE'S MOVE PREVIEWS for TOXIN, contract v2 (2026-10-26, the owner: the caster PERFORMS each move of
	the kit on a target that TAKES the hit, with the real effects, in the wrap being looked at, looping). Client only: no
	remotes, no damage that decides anything. Each Moves entry's Play(stage) loops one move on the AltarStage sandbox
	(stage.Caster / Target: two visible mannequins under workspace.TrainingGround, 14 studs apart along stage.CF.RightVector;
	stage.React: the target's reactions) until the stop() it returns is called.

	Every draw is the move's own ToxinFX.Handlers entry -- the call ToxinClient makes for the server's broadcast -- fed the
	broadcast ToxinHandler would send (Character = stage.Caster), inside ToxinWrap.With({ P = the wrap's palette, Mine =
	true }), the scope ToxinWrap.Run gives a wrapped caster's cast; pieces ToxinFX draws later re-enter it (Capture / With).
	The glue below only plays the server's part: the ids, the timing, the hit -- and the target's side of it, through
	React.Hit with ToxinTuning's own numbers (StatusEffects' Poisoned preset A where it is the server's: 6 a second).
	  TOXIC BUBBLES    two throws, right hand then left (FireInterval apart): ToxinBubble out of the hand at the victim's
	                   chest, ToxinBubblePop where the server's sweep would stop it; Damage 9 and POISON each
	  CORROSIVE CLOUD  the same throw, converted just short of the victim (ToxinBubbleConvert + ToxinCloud): the zone's
	                   ticks of 3 every 0.5 s from FormTime, POISON refreshed at most every 1.5 s (the server's rule)
	  ANTITOXIN VENT   ToxinVent on the caster, turned three-quarters to the camera so the mask's face reads, then back;
	                   the full cleanse (eight tendrils). It touches no enemy: the target only watches
	  ACID RAIN        ToxinAcidRain over the victim's spot (the hold puff off the raised hand, the cloud, the globs);
	                   ticks of 6 a second, each a CORRODED stack (ToxinVuln / ToxinVulnUntil: the glaze) + ToxinAcidTick
	  PATIENT ZERO     ToxinPZMark thrown onto the victim, the telegraph, ToxinPZBurst on it: 18, POISON, then the mass's
	                   ticks of 4
	  SYMBIOSIS        a throw poisons the victim; each Poisoned tick (6) heals the caster 30%: ToxinLifesteal's thread
	THE BODY (CastPose, the IceMagic.CastPose instance): Toxin's Default kit has NO third-person clip of its own (ToxinClient
	plays first-person arms only). The throws are Icicle Shard's palm thrust (IcicleShardR / L, released at its Trigger) --
	the shot ToxinClient's own arms borrow for Toxic Bubbles; the rest are the only Toxin cast poses CastPose has, the
	Hydra skin's body clips, each started from the hook HydraFX starts it from (see CLIP).
	SIZES: the live Corrosive Cloud (radius 9), Acid Rain (10, 14 high) and Patient Zero (20) outgrow the stage, so their
	broadcasts carry the SHOW sizes below (each handler reads d.Radius / d.Height), sized to take in the target and leave
	the caster outside. The bubble is the live shot slowed (VFXLibrary.ShotTimeScale's rule: velocity x s, gravity x s^2):
	at 200 studs/s it crosses the stage in 2 frames.
	CLEANUP: ToxinFX parents its pieces to workspace.IceMagicFX and makes some LATER (a landed drop's splat, Acid Rain's
	globs, the Corroded glaze). A preview owns what its calls made, plus any Toxin piece that appears near its stage while
	it runs and for a short tail after stop() (unless a newer Toxin preview holds the stage by then). stop() ends through
	the module's own endings first (the pop, CloudEnd, PZCancel, VentEnd), then destroys the rest 0.4 s later; the caster
	goes back to its rest stance and its place, the target is React.Reset.
	THE SKIN (2026-10-26, the showcase skin convention): with stage.Skin on (Pixel Potion, Scorpion, Witch's Brew, Hydra)
	the caster wears it -- AltarStage stamps ShowcaseSkin on it and the kits' On() take it as their wearer -- so
	ToxinFX's skin hooks draw every piece in it. The scope is what ToxinWrap.paletteFor gives that wearer: the wrap only
	where AltarStage.Look lets it over the skin (SkinCatalog.WrapsOverSkin: no Toxin wrap), else the skin's own palette
	(Witch's Brew: WitchsBrewKit.WrapPalette, its purples on the Default pieces) or none -- never a Default palette
	forced over the skin. The kit is asked to build (Prepare) at Play and waited for, up to KIT_WAIT. A skin whose hooks
	pose the body themselves (HydraFX / WitchsBrewFX: the Hydra* / WB* clips, started with the draw) is left to them:
	the Default's stand-in clips (the thrust, and the Hydra clips for Witch's Brew) are not played over them (SKIN_BODY).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ELEMENT = "Toxin"

-- the preview's own numbers (the live ones, in ToxinTuning / StatusEffects, beside each). EVERY NUMBER HERE IS A PROPOSAL
local SHOW = {
	BubbleSpeed = 14,        -- studs/s down the stage (live T.Bubble.Speed 200); the lob's gravity scales with it (x s^2)
	ReleaseAhead = 0.8,      -- studs in front of the hand where the sac forms (live: StartAhead 1.5 off the eye)
	M1Volley = 2,            -- throws a loop, FireInterval apart (live T.Bubble.FireInterval 0.55)
	M1Every = 2.8,
	ConvertShort = 3.0,      -- studs short of the victim's chest where the Primary press converts the sac
	CloudRadius = 6,         -- (live T.Cloud.Radius 9)
	CloudLinger = 1.8,       -- s the cloud holds once formed (live T.Cloud.Duration 6)
	CloudEvery = 4.0,
	VentOn = 2.4,            -- s the mask is worn (live T.Vent.Duration 6)
	VentTurn = 50,           -- degrees the caster turns toward the camera for it (its face is the mask's)
	TurnTime = 0.3,          -- s each way
	VentEvery = 3.8,
	RainRadius = 5,          -- (live T.AcidRain.Radius 10)
	RainHeight = 6.5,        -- the cloud's underside over the floor (live 14)
	RainFor = 2.3,           -- s of downpour after the gather (live T.AcidRain.RainTime 4): two 1 s ticks
	VulnHold = 1.2,          -- s each CORRODED stack holds past its tick (live T.AcidRain.VulnDuration 6): gone before the next loop
	RainEvery = 4.5,         -- (the cloud ends 3.2 s in and fades 1.6 s: gone as the next one gathers)
	PZTelegraph = 2.8,       -- s from the mark to the burst, fuse included (live 3.5; the 0.6/1.8/4.6 Hz gears are fractions)
	PZRadius = 7,            -- the burst's wave and mass (live T.PatientZero.Radius 20)
	PZCloud = 1.0,           -- s the mass lingers (live CloudDuration 5)
	PZForm = 0.25,           -- s to the mass's first tick (ToxinHandler's detonate: FormTime 0.25)
	PZEvery = 4.4,
	PoisonTick = 6,          -- a Poisoned tick (StatusEffects preset A, server only: TickDamage 6, Interval 1)
	PoisonEvery = 1.0,
	PoisonRefresh = 1.5,     -- a zone's POISON re-pops at most this often a body (ToxinHandler's cloudTick)
	SymTicks = 2,            -- Poisoned ticks a Symbiosis loop shows
	SymEvery = 4.0,
	Reach = 18,              -- studs round stage.CF inside which a Toxin piece counts as this preview's
}

-- the caster's body for each move (CastPose.Clips). At = the clip time the move's broadcast goes out (HydraFX starts each
-- Hydra clip from the same hook as the draw; Rain and Patient Zero wait for the key that sells it).
local CLIP = {
	Throw = { R = "IcicleShardR", L = "IcicleShardL" },         -- (released at the clip's own Trigger, 0.12)
	Cloud = { Name = "HydraExhale", At = 0 },                    -- the conversion press (HydraFX.Cloud: the cast)
	Vent = { Name = "HydraVent", At = 0 },                       -- the hand draws the mask down (HydraFX.Vent)
	Rain = { Name = "HydraRain", At = 0.22 },                    -- both arms to the sky (its 0.22 key): the puff on the hand
	PZ = { Name = "HydraPZ", At = 0.30, Slam = 3.5 },            -- the throw (its 0.30 key) .. the slam (3.5 = live Telegraph)
	Gulp = { Name = "HydraGulp" },                               -- the chest opens to the thread (HydraFX.Lifesteal)
}

-- (2026-10-26) a skin whose own hooks pose the caster (HydraFX's body() / WitchsBrewFX's body(), started with the draw):
-- the CLIP beats here they cover, which this module then leaves to them (Hydra's other beats ARE its clips: kept, so
-- the show's clocked Patient Zero still lands its slam on the shorter telegraph)
local SKIN_BODY = {
	Hydra = { Throw = true },                                                    -- (HydraSpit with the bubble)
	WitchsBrew = { Throw = true, Cloud = true, Vent = true, Rain = true, PZ = true, Gulp = true },   -- (the WB* clips)
}
local KIT_WAIT = 6           -- (2026-10-26) s a skin preview waits for its kit to build before it starts

-- display names: SpellshotConfig's (read without waiting), these if it cannot be read
local NAMES = { ToxicBubbles = "Toxic Bubbles", CorrosiveCloud = "Corrosive Cloud", AntitoxinVent = "Antitoxin Vent",
	AcidRain = "Acid Rain", PatientZero = "Patient Zero", Symbiosis = "Symbiosis" }
pcall(function()
	local sp = ReplicatedStorage:FindFirstChild("Spellshot")
	local m = sp and sp:FindFirstChild("SpellshotConfig")
	local Config = m and require(m)
	if type(Config) ~= "table" then return end
	local function set(key, row) if type(row) == "table" and type(row.Name) == "string" then NAMES[key] = row.Name end end
	local e = Config.Elements and Config.Elements[ELEMENT]
	if type(e) == "table" then set("ToxicBubbles", e.M1) set("CorrosiveCloud", e.Primary) set("Symbiosis", e.Passive) end
	set("AntitoxinVent", Config.Mobility and Config.Mobility.AntitoxinVent)
	set("AcidRain", Config.Defense and Config.Defense.AcidRain)
	set("PatientZero", Config.Ultimate and Config.Ultimate.PatientZero)
end)

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves_Toxin] " .. tostring(msg))
end

-- the real modules, found on the first preview (inside its own thread: Play never waits)
local L = nil                -- { H = ToxinFX.Handlers, T = ToxinTuning, W = ToxinWrap|nil, Cat = SkinCatalog|nil, CP = CastPose|nil }
local function lib()
	if L then return L end
	local ice = ReplicatedStorage:WaitForChild("IceMagic", 10)
	assert(ice, "ReplicatedStorage.IceMagic is missing")
	local FX = require(ice:WaitForChild("ToxinFX", 10))
	local T = require(ice:WaitForChild("ToxinTuning", 10))
	assert(type(FX) == "table" and type(FX.Handlers) == "table" and type(T) == "table", "ToxinFX / ToxinTuning unreadable")
	local okW, W = pcall(function() return require(ice:WaitForChild("ToxinWrap", 5)) end)
	local okC, Cat = pcall(function() return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog", 5)) end)
	-- (that exact instance: a second copy of CastPose would run its own state and its own RenderStep)
	local okP, CP = pcall(function() return require(ice:WaitForChild("CastPose", 5)) end)
	L = { H = FX.Handlers, T = T,
		W = (okW and type(W) == "table" and type(W.With) == "function") and W or nil,   -- (none: everything draws Default)
		Cat = (okC and type(Cat) == "table") and Cat or nil,
		CP = (okP and type(CP) == "table" and type(CP.Play) == "function" and type(CP.Clips) == "table") and CP or nil }
	if not L.CP then warnOnce("pose", "CastPose unavailable: the caster casts standing still") end
	return L
end

--- the palette ToxinWrap.paletteFor picks for a caster wearing `id` (nil = Default)
local function paletteOf(id)
	local s = L.Cat and type(id) == "string" and id ~= "Default" and type(L.Cat.Skins) == "table" and L.Cat.Skins[id]
	return (type(s) == "table" and s.Wrap == ELEMENT and type(s.Palette) == "table") and s.Palette or nil
end

--- (2026-10-26) IceMagic.<skin>Kit, required once; nil when it is not in the place
local kits = {}
local function kitOf(skin)
	local k = kits[skin]
	if k ~= nil then return k or nil end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild(skin .. "Kit")
	local ok, mod = pcall(function() return m and require(m) end)
	kits[skin] = (ok and type(mod) == "table") and mod or false
	return kits[skin] or nil
end

--- (2026-10-26) the caster's look (AltarStage.Look, the showcase's one rule): Toxin's skin on it (nil = the Default kit)
--- and the wrap drawn (over it) -- "Default" for a wrap SkinCatalog does not let over a skin
local function lookOf(stage, React)
	local wrap = (type(stage.Wrap) == "string" and stage.Wrap ~= "") and stage.Wrap or "Default"
	if type(React) == "table" and type(React.Look) == "function" then
		local ok, skin, w = pcall(React.Look, stage, ELEMENT)
		if ok then return skin, w end
	end
	return nil, wrap
end

--- every colour ToxinFX can paint a plain part in this scope: the source table, the display inputs, and the wrap's own
--- (how a late splat / glob is told from another module's part in the same folder)
local function coloursOf(P)
	local list = {}
	local function add(tbl)
		if type(tbl) ~= "table" then return end
		for _, c in pairs(tbl) do if typeof(c) == "Color3" then list[#list + 1] = c end end
	end
	add(L.T.Color)
	for _, tbl in pairs(L.T.Display or {}) do add(tbl) end
	if P then
		add(P.Color)
		for _, tbl in pairs(type(P.Display) == "table" and P.Display or {}) do add(tbl) end
	end
	return list
end

-- the broadcasts' ids: negative, so never a server bubble / cloud (positive), nor HubShowcaseM1's (from -1e9)
local seq = 0
local function newId()
	seq += 1
	return -2e9 - seq
end

local function partOf(model, ...)
	if typeof(model) ~= "Instance" then return nil end
	for _, n in ipairs({ ... }) do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then return p end
	end
	return nil
end
local function chestOf(model) return partOf(model, "UpperTorso", "Torso", "HumanoidRootPart") end
local function rootOf(model) return partOf(model, "HumanoidRootPart", "UpperTorso", "Torso") end
local function now() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- ====================================================================================================
-- THE CASTER'S BODY (CastPose)
-- ====================================================================================================
--- a clip time as seconds on the wall clock (CastPoseTimeScale slows the body; AbilityFX schedules a release the same way)
local function beat(t)
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local k = ice and ice:GetAttribute("CastPoseTimeScale")
	return t / ((type(k) == "number" and k > 0) and k or 1)
end

--- a clip's release beat (its Trigger), or `fallback`
local function trigger(clip, fallback)
	local c = L.CP and L.CP.Clips[clip]
	return (type(c) == "table" and type(c.Trigger) == "number") and c.Trigger or fallback or 0
end

-- ====================================================================================================
-- THE PREVIEW SESSION: one per Play -- its scope, what it made, the round it is on
-- ====================================================================================================
local Session = {}
Session.__index = Session
local live = setmetatable({}, { __mode = "k" })   -- [stage.Parent] = the newest Toxin preview running on that stage

--- a wait that ends early (false) the moment the preview is stopped
function Session:Sleep(sec)
	local untilT = os.clock() + sec
	while self.Alive do
		local left = untilT - os.clock()
		if left <= 0 then return true end
		task.wait(math.min(left, 0.1))
	end
	return false
end

--- `fn` `sec` from now, inside this round only (a beat still pending when the round ends, or the preview stops, is dropped)
function Session:After(sec, fn)
	local round = self.Round
	task.spawn(function()
		if not self:Sleep(sec) or self.Round ~= round then return end
		local ok, err = pcall(fn)
		if not ok then warnOnce("after:" .. self.Move.Key, self.Move.Key .. " beat failed: " .. tostring(err)) end
	end)
end

--- the caster plays `clip` (on `clock`, if given: CastPose.PlayClocked); guarded. `beat` (2026-10-26): the CLIP beat it
--- stands in for -- skipped when the worn skin's own hooks pose that beat (SKIN_BODY)
function Session:Pose(clip, clock, beat)
	local CP = L.CP
	if beat and self.Yield and self.Yield[beat] then return end
	if not (CP and self.Alive and typeof(self.Caster) == "Instance" and self.Caster.Parent) then return end
	local ok, err = pcall(clock and CP.PlayClocked or CP.Play, self.Caster, clip, clock)
	if not ok then warnOnce("pose:" .. clip, "CastPose " .. clip .. ": " .. tostring(err)) end
end

--- the caster back on its rest stance: the clip let go, no base, no aim
function Session:Unpose()
	local CP = L and L.CP
	local c = self.Caster
	if not (CP and typeof(c) == "Instance" and c.Parent) then return end
	pcall(CP.Stop, c)
	pcall(CP.SetBase, c, nil)
	pcall(CP.SetAim, c, nil)
end

--- the target takes the hit (React.Hit), while the preview runs
function Session:Hit(opts)
	if not self.Alive then return end
	local R = self.React
	if not (R and type(R.Hit) == "function") then return end
	local ok, err = pcall(R.Hit, self.Stage, opts)
	if not ok then warnOnce("hit", "React.Hit failed: " .. tostring(err)) end
end

--- the POISON word for a fresh application: always for a direct hit (`force`, StatusEffects pops every Apply), else only
--- when the last one on the target is PoisonRefresh old (a zone's refresh rule)
function Session:Poison(force)
	local t = os.clock()
	if not force and t - self.PoisonAt < SHOW.PoisonRefresh then return nil end
	self.PoisonAt = t
	return "POISON"
end

--- between rounds (and at the end): the caster on its rest stance and its own place, the target React.Reset (home, full
--- health, statuses off), and the Corroded stacks the glaze reads cleared
function Session:Rest()
	self:Unpose()
	local t = self.Target
	if typeof(t) == "Instance" and t.Parent then
		t:SetAttribute("ToxinVuln", nil)
		t:SetAttribute("ToxinVulnUntil", nil)
	end
	local R = self.React
	if R and type(R.Reset) == "function" then pcall(R.Reset, self.Stage) end
	-- (Reset keeps a body's facing: a turned caster, or a target caught mid-recoil, is put back square here)
	for m, cf in pairs(self.Homes) do
		if m.Parent then pcall(m.PivotTo, m, cf) end
	end
	self.PoisonAt = -99
end

--- one broadcast `d` drawn by handler `f`, in the preview's scope; every new piece it parents to the FX folder (and, with
--- `terrain`, every Attachment it puts on Terrain: the threads) is the preview's. Errors are passed on, after the record.
function Session:Call(f, d, terrain)
	if type(f) ~= "function" then error("handler missing", 0) end
	local fx = workspace:FindFirstChild("IceMagicFX")
	local before, tBefore = {}, nil
	if fx then for _, c in ipairs(fx:GetChildren()) do before[c] = true end end
	if terrain then
		tBefore = {}
		for _, c in ipairs(workspace.Terrain:GetChildren()) do tBefore[c] = true end
	end
	local W = L.W
	local ok, err = pcall(function()
		if W then W.With(self.Scope, f, d) else f(d) end           -- (With puts ToxinTuning back even on an error)
	end)
	fx = workspace:FindFirstChild("IceMagicFX")
	if fx then
		for _, c in ipairs(fx:GetChildren()) do if not before[c] then self.Items[c] = true end end
		self:Watch(fx)
	end
	if tBefore then
		for _, c in ipairs(workspace.Terrain:GetChildren()) do
			if not tBefore[c] and c:IsA("Attachment") then self.Items[c] = true end
		end
	end
	if not ok then error(err, 0) end
end

--- the pieces ToxinFX makes later, from its own updaters: watched as they arrive in the FX folder
function Session:Watch(fx)
	if self.Conn then return end
	self.Fx = fx
	self.Conn = fx.ChildAdded:Connect(function(c)
		local plain = c:IsA("BasePart") and c.Name == "Part"          -- (ToxinFX's parts keep the default name)
		if plain or ((c:IsA("Folder") or c:IsA("Model")) and string.sub(c.Name, 1, 5) == "Toxin") then
			if not self:Settle(c) then self.Pending[c] = os.clock() + 0.6 end   -- (not placed yet: looked at again)
		end
	end)
	self.Beat = RunService.Heartbeat:Connect(function() self:Tick() end)
end

function Session:Unwatch()
	if self.Conn then self.Conn:Disconnect() self.Conn = nil end
	if self.Beat then self.Beat:Disconnect() self.Beat = nil end
	table.clear(self.Pending)
end

--- whether any part of `c` sits on this stage (a fresh piece waits at the world origin until its updater places it)
function Session:Near(c)
	local list = c:IsA("BasePart") and { c } or c:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") then
			local d = p.Position - self.Centre
			if math.abs(d.Y) < 24 and Vector2.new(d.X, d.Z).Magnitude < SHOW.Reach then return true end
		end
	end
	return false
end

--- a plain part is Toxin's only as ToxinFX's ball(): a sphere mesh, in one of this scope's colours
function Session:Ours(p)
	local m = p:FindFirstChildOfClass("SpecialMesh")
	if not (m and m.MeshType == Enum.MeshType.Sphere) then return false end
	local c = p.Color
	for _, k in ipairs(self.Colours or {}) do
		if math.abs(c.R - k.R) < 0.006 and math.abs(c.G - k.G) < 0.006 and math.abs(c.B - k.B) < 0.006 then return true end
	end
	return false
end

--- a watched piece: true once decided (claimed, or not ours), false while it is still unplaced
function Session:Settle(c)
	if c.Parent ~= self.Fx then return true end                    -- (gone, or moved elsewhere by its maker)
	if not self:Near(c) then return false end
	if c:IsA("BasePart") and not self:Ours(c) then return true end
	if self.Alive then
		self.Items[c] = true
	else
		local newer = live[self.Home]
		if not (newer and newer ~= self and newer.Alive) then pcall(c.Destroy, c) end   -- (a newer preview here owns it)
	end
	return true
end

function Session:Tick()
	local t = os.clock()
	for c, untilT in pairs(self.Pending) do
		if self:Settle(c) or t > untilT then self.Pending[c] = nil end
	end
	if t >= self.PruneAt then                                      -- (what ToxinFX has already ended)
		self.PruneAt = t + 2
		for c in pairs(self.Items) do if c.Parent == nil then self.Items[c] = nil end end
	end
	if not self.Alive and t > self.LateUntil then self:Unwatch() end
end

function Session:Stop()
	if not self.Alive then return end                              -- (a second stop: nothing)
	self.Alive = false
	self.Round += 1                                                -- (every beat still pending is dropped)
	if live[self.Home] == self then live[self.Home] = nil end
	if self.Gone then self.Gone:Disconnect() self.Gone = nil end
	if L then
		local ok, err = pcall(self.Move.Halt, self)                  -- the module's own endings: the fades
		if not ok then warnOnce("halt:" .. self.Move.Key, self.Move.Key .. " end failed: " .. tostring(err)) end
	end
	self:Rest()
	self.LateUntil = math.max(self.LateUntil, os.clock() + (self.Move.Tail or 1.8))
	task.delay(0.4, function()
		for c in pairs(self.Items) do
			if c:IsA("Attachment") then                              -- (a thread's points: ToxinFX ends them itself, under 1 s)
				for _, b in ipairs(c:GetChildren()) do if b:IsA("Beam") then b.Enabled = false end end
			else
				pcall(c.Destroy, c)
			end
		end
		table.clear(self.Items)
	end)
end

-- ====================================================================================================
-- THE SERVER'S PART: the throw, the zones, the ends
-- ====================================================================================================
--- castBubble's broadcast, from the caster's `side` hand at its release: the sac forms just ahead of it and flies at the
--- victim's chest. Returns the shot.
local function throw(s, side)
	local B = L.T.Bubble
	local R = s.Stage.CF.RightVector
	local hand = side == "L" and partOf(s.Caster, "LeftHand", "Left Arm") or partOf(s.Caster, "RightHand", "Right Arm")
	local from = hand and hand.Position or (s.Centre - R * 6)
	local chest = chestOf(s.Target)
	local aim = chest and chest.Position or (s.Centre + R * 7)
	local dir = aim - from
	dir = dir.Magnitude > 0.1 and dir.Unit or R
	local start = from + dir * SHOW.ReleaseAhead                   -- (the release, arm out)
	local k = SHOW.BubbleSpeed / (B.Speed or 200)                  -- (the live shot's time scale)
	local shot = { Id = newId(), Start = start, Dir = dir, Vel = dir * SHOW.BubbleSpeed, G = (B.Gravity or 14) * k * k,
		Chest = chest, R = B.Radius or 1 }
	s.Bubbles[shot.Id] = true
	s:Call(L.H.ToxinBubble, { Id = shot.Id, Character = s.Caster, Origin = start, Vel = shot.Vel, G = shot.G, T0 = now() })
	return shot
end

--- the sac's centre `t` s into its flight (ToxinHandler's bubblePos)
local function sacAt(shot, t)
	return shot.Start + shot.Vel * t - Vector3.new(0, 0.5 * shot.G * t * t, 0)
end

--- s from the release to where the server's sweep first touches the chest (the sphere against the torso's box)
local function hitTime(shot)
	local dist = 11
	local c = shot.Chest
	if c and c.Parent then
		local d = shot.Dir
		local cf = c.CFrame
		local half = math.abs(cf.LookVector:Dot(d)) * c.Size.Z * 0.5 + math.abs(cf.RightVector:Dot(d)) * c.Size.X * 0.5
			+ math.abs(cf.UpVector:Dot(d)) * c.Size.Y * 0.5
		dist = math.max(1, (c.Position - shot.Start):Dot(d) - half - shot.R)
	end
	return dist / SHOW.BubbleSpeed
end

--- the direct hit: the pop on the chest (the burst, the flung drops, the residue down the body), Damage and POISON
local function popOn(s, shot, t)
	s.Bubbles[shot.Id] = nil
	s:Call(L.H.ToxinBubblePop, { Id = shot.Id, Character = s.Caster, Position = sacAt(shot, t) + shot.Dir * shot.R,
		Target = s.Target })
	s:Hit({ Damage = L.T.Bubble.Damage, From = shot.Start, Word = s:Poison(true), Style = "poison" })
end

--- whether the target's root stands in a zone round `centre` (flat `radius`; from 3 under to `height` over its floor)
local function inside(s, centre, radius, height)
	local r = rootOf(s.Target)
	if not r then return false end
	local d = r.Position - centre
	return flat(d).Magnitude <= radius and d.Y >= -3 and d.Y <= (height or 10)
end

--- a poison zone's ticks on the target (cloudTick): the first `first` s on, then every `every` s while inside `span`;
--- `recoil`: the first tick that lands leans the body (a gas does not shove; the first bite still reads)
local function zoneTicks(s, centre, radius, first, span, every, damage, recoil)
	if not s:Sleep(first) then return end
	local k = 0
	while k * every < span - 1e-3 do
		if k > 0 and not s:Sleep(every) then return end
		if inside(s, centre, radius) then
			s:Hit({ Damage = damage, From = centre, NoRecoil = not recoil, Word = s:Poison(false), Style = "poison" })
			recoil = false
		end
		k += 1
	end
end

--- every bubble still out: dropped without a burst (a Pop with no Position: ToxinFX drops its record and its sac)
local function popAll(s)
	for id in pairs(s.Bubbles) do pcall(s.Call, s, L.H.ToxinBubblePop, { Id = id }) end
	table.clear(s.Bubbles)
end

--- every cloud this preview made: ToxinCloudEnd (a live one fades fast; an ended one just leaves ToxinFX's table)
local function endClouds(s)
	for id in pairs(s.Clouds) do pcall(s.Call, s, L.H.ToxinCloudEnd, { Id = id, Reason = "Expired" }) end
	table.clear(s.Clouds)
end

--- the caster's pivot turned from its home toward the camera by at most `deg` (flat)
local function towardCamera(s, deg)
	local home = s.Homes[s.Caster] or s.Caster:GetPivot()
	local cam = workspace.CurrentCamera
	local f = flat(home.LookVector)
	local to = flat(cam and (cam.CFrame.Position - home.Position) or -s.Stage.CF.LookVector)
	if f.Magnitude < 1e-3 or to.Magnitude < 1e-3 then return home end
	f, to = f.Unit, to.Unit
	local a = math.min(math.acos(math.clamp(f:Dot(to), -1, 1)), math.rad(deg))
	return home * CFrame.Angles(0, (f:Cross(to).Y >= 0) and a or -a, 0)
end

--- the caster eased round to `cf` over `dur` s (false: stopped on the way)
local function turnTo(s, cf, dur)
	local m = s.Caster
	if not (cf and m and m.Parent) then return s.Alive end
	local from, t0 = m:GetPivot(), os.clock()
	while s.Alive and m.Parent do
		local k = math.min(1, (os.clock() - t0) / math.max(dur, 1e-3))
		m:PivotTo(from:Lerp(cf, k * k * (3 - 2 * k)))
		if k >= 1 then return true end
		RunService.Heartbeat:Wait()
	end
	return false
end

-- ====================================================================================================
-- THE MOVES: Every (s, one round start to the next), Cycle(s) (one cast -> hit; may wait inside), Halt(s) (the ends),
-- Tail (s after stop that late pieces are still caught)
-- ====================================================================================================
local MOVES = {}

-- M1: TOXIC BUBBLES -- the palm thrust, right then left, each sac popping on the victim's chest
MOVES.ToxicBubbles = {
	Every = SHOW.M1Every, Tail = 1.8,
	Cycle = function(s)
		for i = 1, SHOW.M1Volley do
			if i > 1 and not s:Sleep(L.T.Bubble.FireInterval or 0.55) then return end
			local side = (i % 2 == 1) and "R" or "L"
			local clip = CLIP.Throw[side]
			s:Pose(clip, nil, "Throw")                               -- (2026-10-26: a skin's own body yields it)
			if not s:Sleep(beat(trigger(clip, 0.12))) then return end
			local shot = throw(s, side)
			local t = hitTime(shot)
			s:After(t, function() popOn(s, shot, t) end)
		end
	end,
	Halt = function(s) popAll(s) end,
}

-- PRIMARY: CORROSIVE CLOUD -- the same throw, converted just short of the victim (castCloud's two broadcasts); the zone
-- bites from FormTime on
MOVES.CorrosiveCloud = {
	Every = SHOW.CloudEvery, Tail = 1.9,
	Cycle = function(s)
		endClouds(s)                                                  -- (the last round's, faded by now)
		local C = L.T.Cloud
		local clip = CLIP.Throw.R
		s:Pose(clip, nil, "Throw")
		if not s:Sleep(beat(trigger(clip, 0.12))) then return end
		local shot = throw(s, "R")
		local t = math.max(0.15, hitTime(shot) - SHOW.ConvertShort / SHOW.BubbleSpeed)
		if not s:Sleep(t) then return end
		s:Pose(CLIP.Cloud.Name, nil, "Cloud")                         -- (the press: the body exhales the cloud)
		if CLIP.Cloud.At > 0 then
			if not s:Sleep(beat(CLIP.Cloud.At)) then return end
			t += beat(CLIP.Cloud.At)
		end
		local point = sacAt(shot, t)
		s.Bubbles[shot.Id] = nil
		s:Call(L.H.ToxinBubbleConvert, { Id = shot.Id, Character = s.Caster, Position = point })
		local id = newId()
		s.Clouds[id] = true
		local centre = Vector3.new(point.X, s.Floor.Y, point.Z)
		local form = C.FormTime or 0.6
		s:Call(L.H.ToxinCloud, { Character = s.Caster, Id = id, Point = point, Center = centre, Radius = SHOW.CloudRadius,
			T0 = now(), FormTime = form, Duration = SHOW.CloudLinger, Kind = "Corrosive" })
		zoneTicks(s, centre, SHOW.CloudRadius, form, SHOW.CloudLinger, C.Tick or 0.5, C.TickDamage or 3, true)
	end,
	Halt = function(s)
		popAll(s)
		endClouds(s)
	end,
}

-- MOBILITY: ANTITOXIN VENT -- the caster turns three-quarters to the camera, pulls the mask on (the full cleanse), wears
-- it, and turns back once it has dropped off. It touches no enemy.
MOVES.AntitoxinVent = {
	Every = SHOW.VentEvery, Tail = 0.6,
	Cycle = function(s)
		if not turnTo(s, towardCamera(s, SHOW.VentTurn), SHOW.TurnTime) then return end
		s:Pose(CLIP.Vent.Name, nil, "Vent")
		if CLIP.Vent.At > 0 and not s:Sleep(beat(CLIP.Vent.At)) then return end
		s.Vented = true
		-- Cleansed > 0: the full cleanse, eight tendrils (none poisoned draws three)
		s:Call(L.H.ToxinVent, { Character = s.Caster, T0 = now(), Duration = SHOW.VentOn, Cleansed = 1 })
		if not s:Sleep(SHOW.VentOn + 0.25) then return end         -- (the mask drops itself at its Duration)
		s.Vented = false
		turnTo(s, s.Homes[s.Caster], SHOW.TurnTime)
	end,
	Halt = function(s)
		if not s.Vented then return end
		s.Vented = false
		pcall(s.Call, s, L.H.ToxinVentEnd, { Character = s.Caster })   -- (the fast drop: lenses dark, off the face)
	end,
}

-- DEFENSE: ACID RAIN -- the arms thrown up, the downpour over the victim's spot; every Tick a light hit and a CORRODED
-- stack (the server's addVuln: the attributes the glaze reads, then ToxinAcidTick). No end broadcast: a stopped rain's
-- late globs are caught by the tail.
MOVES.AcidRain = {
	Every = SHOW.RainEvery, Tail = 1.2,
	Cycle = function(s)
		local A = L.T.AcidRain
		s:Pose(CLIP.Rain.Name, nil, "Rain")
		if not s:Sleep(beat(CLIP.Rain.At)) then return end
		local centre = s.TargetFloor
		local gather = A.GatherTime or 0.7
		local tick = A.Tick or 1
		s.RainEnd = os.clock() + gather + SHOW.RainFor
		s:Call(L.H.ToxinAcidRain, { Character = s.Caster, Center = centre, Radius = SHOW.RainRadius, Height = SHOW.RainHeight,
			T0 = now(), Gather = gather, RainTime = SHOW.RainFor })
		local done = 0
		for k = 0, math.max(1, math.floor(SHOW.RainFor / tick + 0.5)) - 1 do
			local at = gather + tick * (k + 0.5)
			if not s:Sleep(at - done) then return end
			done = at
			local hit = {}
			if inside(s, centre, SHOW.RainRadius, SHOW.RainHeight) then
				local n = math.min(A.VulnMaxStacks or 4, k + 1)
				s.Target:SetAttribute("ToxinVulnUntil", now() + SHOW.VulnHold)
				s.Target:SetAttribute("ToxinVuln", n)
				s:Hit({ Damage = A.TickDamage or 6, From = centre, NoRecoil = k > 0, Word = n > 1 and ("CORRODED x" .. n) or "CORRODED",
					Style = "poison" })
				hit[1] = s.Target
			end
			s:Call(L.H.ToxinAcidTick, { Character = s.Caster, Center = centre, Hit = hit })   -- (the glaze creeps down the body)
		end
	end,
	Halt = function(s)
		s.LateUntil = os.clock() + math.max(0, (s.RainEnd or 0) - os.clock()) + 1.2
	end,
}

-- ULTIMATE: PATIENT ZERO -- the body summons, throws the mark, squeezes through the telegraph and slams on the burst (the
-- clip runs on a clock that lands its 3.5 s slam on the show's shorter telegraph); the burst and the mass's ticks
MOVES.PatientZero = {
	Every = SHOW.PZEvery, Tail = 1.8,
	Cycle = function(s)
		endClouds(s)
		local P = L.T.PatientZero
		local a, slam, tel = CLIP.PZ.At, CLIP.PZ.Slam, SHOW.PZTelegraph
		local t0 = os.clock()
		s:Pose(CLIP.PZ.Name, function()
			local u = os.clock() - t0
			if u <= a then return u end
			if u <= a + tel then return a + (u - a) * (slam - a) / tel end
			return slam + (u - a - tel)
		end, "PZ")
		if not s:Sleep(a) then return end
		s.Marked = true
		s:Call(L.H.ToxinPZMark, { Character = s.Caster, Target = s.Target, T0 = now(), Telegraph = tel, Fuse = P.Fuse })
		if not s:Sleep(tel) then return end
		s.Marked = false
		local r = rootOf(s.Target)
		local pos = r and r.Position or (s.TargetFloor + Vector3.new(0, 3.2, 0))
		local centre = Vector3.new(pos.X, s.Floor.Y, pos.Z)
		local id = newId()
		s.Clouds[id] = true
		s:Call(L.H.ToxinPZBurst, { Character = s.Caster, Target = s.Target, Position = pos, Center = centre,
			Radius = SHOW.PZRadius, Allies = 0, Duration = SHOW.PZCloud, CloudId = id, T0 = now() })
		s:Hit({ Damage = P.BurstDamage or 18, Word = s:Poison(true), Style = "poison" })   -- (no From: it bursts on the body)
		zoneTicks(s, centre, SHOW.PZRadius, SHOW.PZForm, SHOW.PZCloud, L.T.Cloud.Tick or 0.5, P.CloudTickDamage or 4, false)
	end,
	Halt = function(s)
		if s.Marked then
			s.Marked = false
			pcall(s.Call, s, L.H.ToxinPZCancel, { Character = s.Caster, Target = s.Target })
		end
		endClouds(s)
		-- the wreath rides the victim, which is put back (and then cleared) now: it goes at once
		for c in pairs(s.Items) do if c.Name == "ToxinPZMark" then pcall(c.Destroy, c) end end
	end,
}

-- PASSIVE: SYMBIOSIS -- a throw poisons the victim; each Poisoned tick heals the caster a share of it: the thread out of
-- the victim into the caster's chest, the chest opening to it (the self-damage tell is a screen tint: not a stage effect)
MOVES.Symbiosis = {
	Every = SHOW.SymEvery, Tail = 1.0,
	Cycle = function(s)
		local clip = CLIP.Throw.R
		s:Pose(clip, nil, "Throw")
		if not s:Sleep(beat(trigger(clip, 0.12))) then return end
		local shot = throw(s, "R")
		local t = hitTime(shot)
		if not s:Sleep(t) then return end
		popOn(s, shot, t)
		local CP = L.CP
		for _ = 1, SHOW.SymTicks do
			if not s:Sleep(SHOW.PoisonEvery) then return end
			s:Hit({ Damage = SHOW.PoisonTick, NoRecoil = true })       -- (a DoT tick: the number only)
			if CP and type(CP.CurrentClip) == "function" and CP.CurrentClip(s.Caster) == nil then s:Pose(CLIP.Gulp.Name, nil, "Gulp") end
			s:Call(L.H.ToxinLifesteal, { From = s.Target, To = s.Caster,
				Healed = SHOW.PoisonTick * ((L.T.Symbiosis and L.T.Symbiosis.Lifesteal) or 0.3) }, true)
		end
	end,
	Halt = function(s) popAll(s) end,
}

-- ====================================================================================================
-- THE LOOP
-- ====================================================================================================
local function run(s)
	local ok, err = pcall(lib)
	if not (ok and L) then
		warnOnce("lib", "Toxin's effects are unavailable, nothing drawn: " .. tostring(err))
		return
	end
	if not s.Alive then return end
	-- (2026-10-26) the look: the skin worn, and the wrap only where AltarStage.Look lets it over the skin
	local skin, wrap = lookOf(s.Stage, s.React)
	s.Skin, s.Yield = skin, skin and SKIN_BODY[skin] or nil
	local P = paletteOf(wrap)
	if wrap and wrap ~= "Default" and not P then warnOnce("wrap:" .. tostring(wrap), "wrap " .. tostring(wrap) .. " is not a Toxin wrap - Default drawn") end
	local kit = skin and kitOf(skin) or nil
	if skin and not kit then warnOnce("kit:" .. skin, "no IceMagic." .. skin .. "Kit: the " .. skin .. " skin draws the Default") end
	-- a wearer with no wrap over the skin draws the Default pieces in the skin's own palette where it has one (ToxinWrap
	-- paletteFor's rule: Witch's Brew -> WitchsBrewKit.WrapPalette), never the Default's colours forced over it
	if not P and kit and type(kit.WrapPalette) == "table" then P = kit.WrapPalette end
	s.Scope = { P = P, Mine = true }                                 -- (Mine: drawn at full density, as one's own cast)
	s.Colours = coloursOf(s.Scope.P)
	-- the kit built before the first cast (its hooks draw the stand-ins until it is): Prepare asked for, waited for
	if kit and kit.Built == false then
		if type(kit.Prepare) == "function" then pcall(kit.Prepare) end
		local t1 = os.clock() + KIT_WAIT
		while s.Alive and not kit.Built and not kit.Failed and os.clock() < t1 do task.wait(0.1) end
		if not s.Alive then return end
	elseif kit and type(kit.Prepare) == "function" then
		pcall(kit.Prepare)                                           -- (a kit with no Built flag: its build started now)
	end
	local mv, fails = s.Move, 0
	while s.Alive do
		local t0 = os.clock()
		s.Round += 1
		s:Rest()                                                      -- (the last round's hit, statuses and pose cleared)
		local okC, e = pcall(mv.Cycle, s)
		if not s.Alive then break end
		if okC then
			fails = 0
		else
			pcall(mv.Halt, s)                                           -- (this round's leftovers: a sac still out, a mark)
			-- (a failing wrap is NOT dropped to Default: a selected wrap is never shown as Default; it is retried)
			fails += 1
			warnOnce("cycle:" .. mv.Key .. ":" .. tostring(wrap), mv.Key .. " in " .. tostring(wrap) .. " failed: " .. tostring(e))
			if fails >= 3 then                                          -- (skipped quietly: the stop still cleans up)
				s:Rest()
				return
			end
		end
		if not s:Sleep(math.max(0.05, t0 + mv.Every - os.clock())) then break end
	end
end

local function start(stage, key)
	local mv = MOVES[key]
	mv.Key = key
	local s
	local ok, err = pcall(function()
		assert(type(stage) == "table" and typeof(stage.CF) == "CFrame" and typeof(stage.Floor) == "Vector3", "no stage")
		local caster = stage.Caster or stage.Key
		local target = stage.Target
		assert(typeof(caster) == "Instance" and typeof(target) == "Instance", "no caster / target on the stage")
		local react = stage.React
		if type(react) ~= "table" then                                 -- (the contract's field; the module itself if it is missing)
			local sp = ReplicatedStorage:FindFirstChild("Spellshot")
			local m = sp and sp:FindFirstChild("AltarStage")
			local okR, mod = pcall(function() return m and require(m) end)
			react = (okR and type(mod) == "table") and mod or nil
		end
		local tp = target:GetPivot().Position
		s = setmetatable({
			Stage = stage, Move = mv, Caster = caster, Target = target, React = react,
			Centre = stage.CF.Position, Floor = stage.Floor, TargetFloor = Vector3.new(tp.X, stage.Floor.Y, tp.Z),
			Home = typeof(stage.Parent) == "Instance" and stage.Parent or stage,
			Homes = { [caster] = caster:GetPivot(), [target] = target:GetPivot() },   -- (where the two stand: put back each round)
			Alive = true, Round = 0, PoisonAt = -99, Scope = { P = nil, Mine = true }, Items = {}, Pending = {},
			Bubbles = {}, Clouds = {}, LateUntil = 0, PruneAt = 0,
		}, Session)
		live[s.Home] = s
		if typeof(stage.Parent) == "Instance" then                     -- (the stage torn down without a stop: stop anyway)
			s.Gone = stage.Parent.Destroying:Connect(function() s:Stop() end)
		end
		task.spawn(run, s)
	end)
	if not ok then
		warnOnce("start:" .. key, key .. " could not start: " .. tostring(err))
		if s then pcall(s.Stop, s) end
		return function() end
	end
	return function() pcall(s.Stop, s) end
end

local function entry(key, slot)
	return { Key = key, Name = NAMES[key], Slot = slot, Play = function(stage) return start(stage, key) end }
end

return {
	Element = ELEMENT,
	Moves = {
		entry("ToxicBubbles", "M1"),
		entry("CorrosiveCloud", "Primary"),
		entry("AntitoxinVent", "Mobility"),
		entry("AcidRain", "Defense"),
		entry("PatientZero", "Ultimate"),
		entry("Symbiosis", "Passive"),
	},
}
