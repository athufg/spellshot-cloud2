--[[
	AltarMoves_Cryo  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarMoves/Cryo

	The Loadout Altar's move previews for Cryo, CONTRACT v2 (2026-10-26, the owner: the showcase's two plain dummies fight
	-- the caster PERFORMS each move of the kit with the game's own cast poses and its REAL VFX, in the wrap being looked
	at, and the target TAKES the hit the way a duel shows it, looping on the stage). AltarShowcase calls Moves[i].Play(stage)
	and keeps the stop() it returns. `stage`: CF (RightVector = caster -> target, LookVector = the camera's side), Floor,
	FloorPart, Caster (= Key: a visible grey R15 mannequin, AllyDummy), Target (a visible dummy under workspace.TrainingGround),
	Parent, Wrap, Player, React (AltarStage: Hit / Knock / Recoil / Reset).
	THE CASTER: ReplicatedStorage.IceMagic.CastPose (the game's own instance) plays the clip AbilityFX plays for each broadcast
	-- IcicleShardR / L (the palm thrust; the shard leaves the hand on its Trigger), FlashFreeze (the slam on VFXLibrary's
	LeadIn), ChillAura (Blizzard and Mirror Cage borrow it). Deep Freeze has none, on purpose (AbilityFX: the trap is unseen,
	and a slam would say where). The VFX are the handlers' calls with AbilityHandler's payloads, aimed from the caster at the
	target the way the crosshair puts them: the shard at the chest, the zones and the cage on the target's floor.
	THE TARGET: the real impact lands on its body (the shard's own ray stops on it -- the dummies take rays), then React.Hit
	with the server's numbers: a shard 8 and its Chill stack; Flash Freeze's contact 10, its root, its shatter 34; Deep
	Freeze's 10 and root (CryoTuning); Mirror Cage's 12 bolts of 6 (CryoTuning). No Cryo move knocks anybody back.
	THE WRAP: CryoWrap's hooks draw every entry point in its CASTER's wrap (W.For), and a dummy is nobody's character, so
	W.For is taught the wrap each preview's caster wears while a preview runs (and put back when none does); the calls made
	here are drawn in it outright (Deep Freeze's tap asks for the local player's wrap, so that one needs it). Default = no wrap.
	SIZES are the real ones but the storm's: Blizzard's payload carries its radius and length (7 studs and 4 s here, not 32
	and 6, so the storm stands round the target and the caster stays out of it). Flash Freeze's zone and Mirror Cage's dome
	keep their 20-stud radius (not payload fields).
	Client only: no remotes, no damage, no server calls.
	THE SKIN (2026-10-26, the showcase skin convention): with stage.Skin on (Frostblade, Snow Globe, Frost Lotus, Frost
	Dragon) the caster wears it -- AltarStage stamps ShowcaseSkin on it, and the kits' On() take it as their wearer -- so
	CryoFX's own skin hooks draw every piece in it. Over a skin the wrap is AltarStage.Look's: stage.Wrap only where
	SkinCatalog.WrapsOverSkin allows it (no Cryo wrap does), else none -- W.For answers nil and the skin's own colours
	stand (never a Default palette forced over it). What the skins need that a duel gives the body and a dummy lacks:
	  * the kit BUILT before the first cast (CryoFX draws a skin only once its kit is Built, and the kits build lazily
	    off the players wearing them): Build asked for at Play and waited for, up to KIT_WAIT;
	  * Frost Lotus's M1 HOLD-AND-PLUCK: AbilityFX's IcicleShard handler plays IcicleShardLotus and stamps FrostLotusHold /
	    FrostLotusPluck (FrostLotusKit.M1 holds the lotus in the left hand off them) -- done here on every shot;
	  * Cold Momentum's window (PassiveActive / PassiveExpires on the body, as the server opens it): Frostblade's Naruto
	    run reads it (FrostbladeKit.Naruto, through CastPose);
	  * Deep Freeze's tap: CryoFX.DeepFreezeArmed draws its skin look off the LOCAL player's body (the tap is shown to its
	    owner alone), so for that one call every Cryo skin kit's On() answers the local body as the caster.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))

-- the server's numbers a client cannot read (AbilityHandler's own Tune table): kept equal to it by hand
local DMG = { Shard = 8, Contact = 10, Shatter = 34 }  -- Tune.ShardDamage, FlashFreezeContactDamage, FlashFreezeShatterDamage

-- the beats, in seconds from each loop's start (the effects' own timing is the modules'; these only space the calls)
local SETTLE = 0.35                         -- the caster's Ready stance blends in before the first cast
local M1 = { Gap = 0.333, Clear = 2.3, Period = 3.0 }   -- three taps (FireInterval 0.333): Chill 1, 2, 3; then it clears
local FF = { Tail = 0.4, Period = 5.6 }     -- the shatter lands 4.88 s in (LeadIn + ExpandTime + RimLinger): the zone's
                                            -- own length, so this loop runs past the others'
local BZ = { Radius = 7, Time = 4.0, Frost = 0.2, Period = 4.4 }   -- the storm sized to the target; the next forms as the
                                            -- last clears (two storm keys: one storm per caster)
local DF = { Step = 4, Walk = 16, Pause = 0.15, Go = 0.12, Hold = 0.6, Period = 4.3 }   -- the caster steps up Step studs
                                            -- and backs off at a walk (16); the target walks in once the trap is armed,
                                            -- and back out Hold after the thaw
local MC_GAP = 0.2                          -- after the cage has melted
local CM = { Radius = 2.4, HitBy = 1.0, Breath = 0.45, Tail = 0.5, Period = 3.4 }   -- the buffed stride: one loop of
                                            -- Radius round the caster's spot over the buff (Passive.Duration); no hit
                                            -- by HitBy, no buff
local SWEEP, SWEEP_R, POP_GRACE = 0.3, 45, 0.6          -- the clean-up after a stop: seconds, studs, seconds
local KIT_WAIT = 6                          -- (2026-10-26) s a skin preview waits for its kit to build before it starts
local CRYO_KITS = { "FrostbladeKit", "FrostLotusKit", "SnowGlobeKit", "FrostDragonKit" }   -- every Cryo skin's kit
-- what this module stamps on the caster for a skin (2026-10-26), cleared at every rest and on stop
local SKIN_ATTRS = { "FrostLotusHold", "FrostLotusPluck", "PassiveActive", "PassiveExpires" }

local Players = game:GetService("Players")

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[AltarMoves.Cryo] " .. msg)
end

-- the real modules, found once (AbilityFX has started CryoFX already; Start is idempotent and installs the wrap hooks)
local K = nil
local function kit()
	if K then return K end
	local ice = ReplicatedStorage:WaitForChild("IceMagic", 10)
	assert(ice, "ReplicatedStorage.IceMagic is missing")
	local VFX = require(ice:WaitForChild("VFXLibrary", 10))
	local CFX = require(ice:WaitForChild("CryoFX", 10))
	pcall(CFX.Start)
	local W = require(ice:WaitForChild("CryoWrap", 10))
	local T = require(ice:WaitForChild("CryoTuning", 10))
	local CP = require(ice:WaitForChild("CastPose", 10))       -- (that instance: a second copy would pose on its own clock)
	K = { VFX = VFX, CFX = CFX, W = W, T = T, CP = CP, Hooked = CFX.WrapInstalled == true and VFX.Wrap == W }
	return K
end

--- CryoWrap's W.For, taught the altar's casters: inside a call made here (Forcing) every caster draws in the preview's
--- wrap; outside one (a shard's impact, a cage's break) a dummy this module registered draws in its preview's wrap; anyone
--- else is CryoWrap's own answer. Put on the module table every Cryo effect reads while a preview runs (wrapRelease).
local function wrapReg(W)
	local reg = rawget(W, "_AltarFor")
	if not reg then
		reg = { Casters = setmetatable({}, { __mode = "k" }), Forcing = false, Forced = nil }
		W._AltarFor = reg
	end
	if not reg.Fn or W.For ~= reg.Fn then
		local base = W.For
		reg.Base = base
		reg.Fn = function(caster)
			if reg.Forcing then return reg.Forced end
			local e = typeof(caster) == "Instance" and reg.Casters[caster]
			if e then return W.Palette(e.Id) end
			return base(caster)
		end
		W.For = reg.Fn
	end
	return reg
end

--- W.For as CryoWrap had it, once no preview has a caster taught (and nothing has wrapped it over ours since)
local function wrapRelease(W)
	local reg = W and rawget(W, "_AltarFor")
	if reg and reg.Fn and W.For == reg.Fn and not reg.Forcing and next(reg.Casters) == nil then
		W.For = reg.Base
		reg.Fn, reg.Base = nil, nil
	end
end

----------------------------------------------------------------------------------------------------
-- the skin (2026-10-26)
----------------------------------------------------------------------------------------------------
--- IceMagic.<name> (a skin kit), required once; nil when it is not in the place
local kitMods = {}
local function kitModule(name)
	local m = kitMods[name]
	if m ~= nil then return m or nil end
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local inst = ice and ice:FindFirstChild(name)
	local ok, mod = pcall(function() return inst and require(inst) end)
	kitMods[name] = (ok and type(mod) == "table") and mod or false
	return kitMods[name] or nil
end

--- the caster's look (AltarStage.Look, the showcase's one rule): Cryo's skin on it (nil = the Default kit) and the wrap
--- drawn (over it) -- "Default" for a wrap SkinCatalog does not let over a skin
local function lookOf(stage, React)
	local wrap = (type(stage.Wrap) == "string" and stage.Wrap ~= "") and stage.Wrap or "Default"
	if type(React) == "table" and type(React.Look) == "function" then
		local ok, skin, w = pcall(React.Look, stage, "Cryo")
		if ok then return skin, w end
	end
	return nil, wrap
end

--- fn(...) with the LOCAL player's body answered as `caster` by every Cryo skin kit's On() -- for the one call whose skin
--- look CryoFX reads off the local body (DeepFreezeArmed: the tap is shown to its owner alone, so it asks the viewer's
--- body which skin it wears). Put straight back (never undoing somebody else's swap).
local function asOwner(caster, fn, ...)
	local lp = Players.LocalPlayer
	local me = lp and lp.Character
	local swapped = {}
	if me then
		for _, name in ipairs(CRYO_KITS) do
			local k = kitModule(name)
			local real = k and k.On
			if type(real) == "function" then
				local fake = function(c, ...) if c == me then return real(caster, ...) end return real(c, ...) end
				k.On = fake
				swapped[#swapped + 1] = { k, real, fake }
			end
		end
	end
	local r = table.pack(pcall(fn, ...))
	for _, e in ipairs(swapped) do
		if e[1].On == e[3] then e[1].On = e[2] end
	end
	if not r[1] then error(r[2], 0) end
	return table.unpack(r, 2, r.n)
end

local function fxFolder()
	local name = (K and K.VFX.Config and K.VFX.Config.FXFolderName) or "IceMagicFX"
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function now() return workspace:GetServerTimeNow() end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function burstRig(c) return string.sub(c.Name, 1, 12) == "CryoBurstRig" and c:IsA("BasePart") end
local function rootOf(m) return typeof(m) == "Instance" and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart) or nil end

--- a body held still: an anchored root keeps the velocity it is given, and CastPose strides any body moving over 2 studs/s
local function still(m)
	local root = rootOf(m)
	if root then pcall(function() root.AssemblyLinearVelocity = Vector3.zero end) end
end

--- the clip clock's scale (IceMagic.CastPoseTimeScale): AbilityFX times the shard's release by it
local function castScale()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local v = ice and ice:GetAttribute("CastPoseTimeScale")
	return (type(v) == "number" and v > 0) and v or 1
end

--- whether `inst` (a part, or a folder of them) is at the stage: an empty folder made while a preview ran counts
local function near(inst, at, r)
	if inst:IsA("BasePart") then return (inst.Position - at).Magnitude <= r end
	local n = 0
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			if (d.Position - at).Magnitude <= r then return true end
			n += 1
			if n >= 24 then return false end
		end
	end
	return n == 0
end

--- CryoFX's feetOf: the root, and where the feet are -- on `floorY` if the rig's HipHeight puts them off it
local function feetOf(model, floorY)
	local root = rootOf(model)
	if not root then return nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local legs = hum and (hum.RigType == Enum.HumanoidRigType.R6 and 2 or hum.HipHeight) or 2
	local feet = root.Position.Y - root.Size.Y / 2 - legs
	if floorY and math.abs(feet - floorY) > 1 then feet = floorY end
	return root, feet
end

--- where `model` stands, as the server sends it (under the root, at the feet)
local function standAt(model, floor)
	local root, feet = feetOf(model, floor.Y)
	if not root then return nil end
	return Vector3.new(root.Position.X, feet, root.Position.Z)
end

--- the point a crosshair on `model` gives: its chest
local function chestOf(model)
	local p = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if p and p:IsA("BasePart") then return p.Position end
	local root = rootOf(model)
	return root and root.Position + Vector3.new(0, 0.6, 0) or model:GetPivot().Position
end

--- the comic FROZEN! over a body (CryoFX popFrozen / AltarStage's held one -> Callouts: a "Popup" on its Head)
local function frozenPop(c)
	if c:IsA("BillboardGui") and c.Name == "Popup" and c:GetAttribute("Style") == "frozen" then
		pcall(function() c:Destroy() end)
	end
end

local Gen, Active = 0, 0                    -- Plays so far; previews running now
local pending = {}                          -- stopped previews whose clean-up has not run yet

----------------------------------------------------------------------------------------------------
-- a preview's run: its dummies, its wrap, what it leaves in the FX folder, and how it ends
----------------------------------------------------------------------------------------------------
local S = {}
S.__index = S

local function newSession(stage, name)
	return setmetatable({
		Stage = stage, Name = name, Dead = false, Rng = Random.new(), WrapId = "Default",
		Enders = {}, Undo = {}, Late = {}, Taught = {}, HomeCF = {},
		Mine = setmetatable({}, { __mode = "k" }), Seen = setmetatable({}, { __mode = "k" }),
	}, S)
end

--- `fn` when the preview stops (at once if it already has); undone last-in first-out
function S:Hold(fn)
	if self.Dead then pcall(fn) return end
	table.insert(self.Undo, fn)
end

--- `fn` first thing on a stop, while the wrap and the dummies are still the preview's (the effects' own early ends)
function S:Ender(fn)
	table.insert(self.Enders, fn)
end

function S:Until(t)
	local dt = t - os.clock()
	if dt > 0 then task.wait(dt) end
	return not self.Dead
end

function S:After(t, fn)
	task.delay(t, function()
		if self.Dead then return end
		local ok, err = pcall(fn)
		if not ok then warnOnce(self.Name .. "after", self.Name .. ": " .. tostring(err)) end
	end)
end

--- fn(...) drawn in this preview's wrap (every W.For inside it answered with it); whatever it adds to the FX folder there
--- and then is this preview's
function S:Call(fn, ...)
	local fx = self.Fx
	local before = {}
	if fx then for _, c in ipairs(fx:GetChildren()) do before[c] = true end end
	local r
	if K.Hooked then
		local reg = self.Reg
		local was, wasP = reg.Forcing, reg.Forced
		reg.Forcing, reg.Forced = true, self.P
		r = table.pack(pcall(fn, ...))
		reg.Forcing, reg.Forced = was, wasP
	else
		r = table.pack(pcall(K.W.Run, self.P, fn, ...))   -- (no hooks installed: the palette held round the call)
	end
	if fx then
		for _, c in ipairs(fx:GetChildren()) do
			if not before[c] then self.Mine[c] = true end
		end
	end
	if not r[1] then error(r[2], 0) end
	return table.unpack(r, 2, r.n)
end

--- fn(...) of this module's own -- a piece CryoFX draws on a PLAYER only, copied here for the dummy -- in the wrap's
--- palette (CryoWrap W.Run: the swapped tables, W.C and W.Lit answer in it)
function S:Draw(fn, ...)
	return self:Call(K.W.Run, self.P, fn, ...)
end

--- the caster's body plays `clip` (CastPose, as AbilityFX plays it for the broadcast)
function S:Pose(clip)
	local c = self.Caster
	if not c then return end
	local ok, err = pcall(K.CP.Play, c, clip)
	if not ok then warnOnce("pose" .. clip, "CastPose " .. clip .. ": " .. tostring(err)) end
end

--- the hit on stage.Target, as a duel shows it (AltarStage React.Hit)
function S:Hit(opts)
	local R = self.React
	if not (R and R.Hit and self.Target) then return end
	local ok, err = pcall(R.Hit, self.Stage, opts)
	if not ok then warnOnce(self.Name .. "hit", self.Name .. " hit: " .. tostring(err)) end
end

--- `model` casts in this preview's wrap (W.For) and counts as nobody's enemy (VFXLibrary.IsEnemy: never thinned by
--- Reduce Enemy VFX -- the preview is the viewer's own move)
function S:Teach(model)
	local reg, me = self.Reg, self
	reg.Casters[model] = { Id = self.WrapId, S = self }
	self.Taught[#self.Taught + 1] = model
	local was = model:GetAttribute("AllyDummy")
	model:SetAttribute("AllyDummy", true)
	self:Hold(function()
		local e = reg.Casters[model]
		if e and e.S == me then reg.Casters[model] = nil end
		if model.Parent then model:SetAttribute("AllyDummy", was) end
	end)
end

--- a wrap's draw failed: the Default from here on
function S:Default()
	self.P, self.WrapId = nil, "Default"
	for _, m in ipairs(self.Taught) do
		local e = self.Reg.Casters[m]
		if e and e.S == self then e.Id = "Default" end
	end
end

--- a bodiless caster (the second storm's key, or the caster when the stage has none), gone with the preview
function S:StandIn(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = self.Stage.Parent
	self:Teach(m)
	self:Hold(function() m:Destroy() end)
	return m
end

--- the floor under `model` (VFXLibrary.GroundBelow, through bodies: the ground a crosshair on it gives the zones)
function S:FloorUnder(model)
	local st = self.Stage
	local root = rootOf(model)
	if not root then return st.Floor end
	local skip = { self.Fx }
	for _, m in ipairs({ self.Caster, self.Target }) do
		if typeof(m) == "Instance" then skip[#skip + 1] = m end
	end
	local ok, p, _, hit = pcall(K.VFX.GroundBelow, root.Position, skip, 30)
	if ok and hit and typeof(p) == "Vector3" then return p end
	return standAt(model, st.Floor) or st.Floor
end

--- `model` walked over `secs`: at(u) is where its root goes (u 0..1), face(u) the flat way it looks; the root carries the
--- travel's velocity, so CastPose's walk cycle strides the legs (an anchored root keeps what it is given -- AltarMoves_Terra).
--- Ends early when stop() says so; onFrame(u) runs every frame. False when the preview stopped.
function S:Walk(model, secs, at, face, stop, onFrame)
	local root = rootOf(model)
	if not root then return not self.Dead end
	local t0 = os.clock()
	local last, lastT = at(0), t0
	while not self.Dead and model.Parent do
		local t = os.clock()
		local u = math.clamp((t - t0) / math.max(secs, 1e-3), 0, 1)
		local p = at(u)
		local f = flat(face(u))
		if f.Magnitude < 1e-3 then f = flat(root.CFrame.LookVector) end
		if f.Magnitude < 1e-3 then f = Vector3.zAxis end
		model:PivotTo(CFrame.lookAt(p, p + f.Unit))
		if t - lastT > 1e-4 then root.AssemblyLinearVelocity = flat(p - last) / (t - lastT) end
		last, lastT = p, t
		if onFrame then
			local ok, err = pcall(onFrame, u)
			if not ok then warnOnce(self.Name .. "frame", self.Name .. ": " .. tostring(err)) end
		end
		if u >= 1 or (stop and stop()) then break end
		RunService.Heartbeat:Wait()
	end
	still(model)
	return not self.Dead
end

--- between loops and on the stop: the caster back on its rest stance (CastPose's Ready), both dummies still, home and
--- facing each other, every status cleared (AltarStage React.Reset)
function S:Rest()
	local c, CP = self.Caster, K and K.CP
	if c and CP then
		pcall(CP.Stop, c)
		pcall(CP.SetBase, c, nil)
		pcall(CP.SetAim, c, nil)
	end
	if c and c.Parent then                  -- (2026-10-26) the skin's stamps off: the lotus let go, the window shut
		for _, a in ipairs(SKIN_ATTRS) do c:SetAttribute(a, nil) end
	end
	for m in pairs(self.HomeCF) do still(m) end
	local R = self.React
	if R and R.Reset then pcall(R.Reset, self.Stage) end
	for m, cf in pairs(self.HomeCF) do
		if m.Parent then pcall(function() m:PivotTo(cf) end) end
	end
end

--- the modules, the wrap, the dummies, the FX folder's watch. False when the preview was stopped while the modules loaded.
function S:Begin()
	kit()
	if self.Dead then return false end
	self.Reg = wrapReg(K.W)
	local st = self.Stage
	self.React = st.React
	if not self.React then
		pcall(function() self.React = require(ReplicatedStorage.Spellshot.AltarStage) end)
	end
	-- (2026-10-26) the look: the skin worn, and the wrap only where it may go over it (AltarStage.Look)
	local skin, id = lookOf(st, self.React)
	self.Skin = skin
	local ok, P = pcall(K.W.Palette, id)
	P = (ok and type(P) == "table") and P or nil
	if id ~= "Default" and not P then
		warnOnce("wrap" .. id, tostring(id) .. " is not a Cryo wrap here - the Default is drawn")
		id = "Default"
	end
	self.P, self.WrapId = P, id
	local R = st.CF.RightVector
	local caster = st.Caster or st.Key
	if typeof(caster) == "Instance" and caster.Parent and rootOf(caster) then
		self.Caster = caster
		self:Teach(caster)
	else
		self.Caster = self:StandIn("AltarCryoCaster")
	end
	local tg = st.Target
	self.Target = (typeof(tg) == "Instance" and tg.Parent and rootOf(tg)) and tg or nil
	-- home: where AltarStage stood each dummy (AltarHome), facing the other along stage.CF's line
	for _, pair in ipairs({ { self.Caster, R }, { self.Target, -R } }) do
		local m = pair[1]
		if m and rootOf(m) then
			local h = m:GetAttribute("AltarHome")
			local p = typeof(h) == "Vector3" and h or m:GetPivot().Position
			self.HomeCF[m] = CFrame.lookAt(p, p + pair[2])
		end
	end
	-- what this preview leaves in the FX folder (every CryoFX / VFXLibrary effect goes there), until its clean-up
	local fx = fxFolder()
	self.Fx = fx
	self.Track = fx.ChildAdded:Connect(function(c)
		if self.Dead and (Gen ~= self.GenAtStop or os.clock() - self.StopAt > SWEEP) then return end
		self.Seen[c] = true
	end)
	-- the stage taken down without a stop (the altar closed): the preview stops with it, never left looping on nothing
	local holder = st.Parent
	if typeof(holder) == "Instance" then
		local gone = holder.AncestryChanged:Connect(function()
			if not holder:IsDescendantOf(game) then self:Stop() end
		end)
		self:Hold(function() gone:Disconnect() end)
	end
	local t = self.Target
	if t then
		-- the frozen look's wrap tag (CryoWrap's hooks write it on whoever an effect freezes) goes back at the clean-up
		local was = t:GetAttribute("CryoWrapBy")
		self.Late[#self.Late + 1] = function() if t.Parent then t:SetAttribute("CryoWrapBy", was) end end
		-- a FROZEN! still to pop from a prison or a cage that was cut short (Deep Freeze pops it 0.45 s in) goes too
		local head = t:FindFirstChild("Head")
		if head then
			self.PopHead = head
			self.PopConn = head.ChildAdded:Connect(function(c)
				if self.Dead and os.clock() - self.StopAt <= POP_GRACE then frozenPop(c) end
			end)
		end
	end
	-- the caster on the stance every body holds (CastPose's Ready), both dummies home: the first cast blends out of it
	if self.Caster then pcall(K.CP.SetStance, self.Caster, "Ready") end
	self:Rest()
	-- (2026-10-26) the skin's kit built before the first cast: CryoFX draws a skin only once its kit is Built, and a kit
	-- builds lazily off the players wearing it -- so Build is asked for here and waited for (KIT_WAIT)
	if skin then
		local kit = kitModule(skin .. "Kit")
		if not kit then
			warnOnce("kit" .. skin, "no IceMagic." .. skin .. "Kit: the " .. skin .. " skin draws the Default")
		elseif not kit.Built then
			if type(kit.Build) == "function" then pcall(kit.Build) end
			local t1 = os.clock() + KIT_WAIT
			while not self.Dead and not kit.Built and not kit.Failed and os.clock() < t1 do task.wait(0.1) end
			if not kit.Built and not self.Dead then
				warnOnce("kitwait" .. skin, skin .. "Kit is not built yet: its pieces draw the Default until it is")
			end
		end
	end
	return not self.Dead
end

--- every piece this preview left in the FX folder, put away (out of the world: CryoFX's and VFXLibrary's own steppers see
--- it gone, finish and pool or free it -- nothing pooled is destroyed under them); with no Cryo preview on, the shared
--- burst rigs near the stage too (their powder)
function S:PutAway()
	local fx = self.Fx
	if not fx then return end
	local at = self.Stage.CF.Position
	local function away(c) pcall(function() c.Parent = nil end) end
	for c in pairs(self.Mine) do
		if c.Parent == fx and c.Name ~= "IcicleShardFX" then away(c) end
	end
	for c in pairs(self.Seen) do
		if c.Parent == fx and c.Name ~= "IcicleShardFX" and near(c, at, SWEEP_R) then away(c) end
	end
	if Active == 0 then
		for _, c in ipairs(fx:GetChildren()) do
			if burstRig(c) and (c.Position - at).Magnitude <= SWEEP_R then away(c) end
		end
	end
end

function S:Sweep()
	if self.Swept then return end
	self.Swept = true
	pending[self] = nil
	pcall(self.PutAway, self)
	if self.Track then self.Track:Disconnect() self.Track = nil end
	table.clear(self.Mine)
	table.clear(self.Seen)
	for _, f in ipairs(self.Late) do pcall(f) end
	table.clear(self.Late)
	if Active == 0 and K then pcall(wrapRelease, K.W) end
end

--- the loop ends; each effect's own early end runs (they fade), the dummies go home and rest, the wrap goes back, and
--- SWEEP later whatever is still on screen is put away. Safe to call twice; returns at once.
function S:Stop()
	if self.Dead then return end
	self.Dead = true
	self.StopAt, self.GenAtStop = os.clock(), Gen
	Active = math.max(0, Active - 1)
	for i = #self.Enders, 1, -1 do
		local ok, err = pcall(self.Enders[i])
		if not ok then warnOnce(self.Name .. "end", self.Name .. " end: " .. tostring(err)) end
	end
	pcall(self.Rest, self)                  -- (while the dummies are still taught: the crust breaks off in the wrap)
	for i = #self.Undo, 1, -1 do pcall(self.Undo[i]) end
	table.clear(self.Enders)
	table.clear(self.Undo)
	if self.PopHead then
		for _, c in ipairs(self.PopHead:GetChildren()) do frozenPop(c) end
	end
	local pc = self.PopConn
	if pc then task.delay(POP_GRACE, function() pc:Disconnect() end) end
	pending[self] = true
	task.delay(SWEEP, function() self:Sweep() end)
end

--- the loop: cast -> hit, rest (React.Reset, the caster's stance), and again every `period` s until the stop; a cycle
--- that errors in a wrap goes on in the Default
local function run(s, cycle, period)
	local fails = 0
	while not s.Dead do
		local c0 = os.clock()
		local ok, err = pcall(cycle, s, c0)
		if s.Dead then return end
		pcall(s.Rest, s)
		if ok then
			fails = 0
		else
			fails += 1
			warnOnce(s.Name .. s.WrapId, s.Name .. " (" .. s.WrapId .. "): " .. tostring(err))
			if s.P then s:Default() end
			if fails >= 3 then return end
		end
		local p = (type(period) == "function") and period(s) or period
		if not s:Until(c0 + math.max(0.5, tonumber(p) or 3)) then return end   -- (never a busy loop)
	end
end

--- Play(stage) -> stop(): returns at once, the preview loops on its own thread
local function preview(name, setup, cycle, period)
	return function(stage)
		local ok, stop = pcall(function()
			for old in pairs(pending) do old:Sweep() end      -- a stopped preview's clean-up goes before anything new is drawn
			Gen += 1
			Active += 1
			local s = newSession(stage, name)
			task.spawn(function()
				local ok2, err = pcall(function()
					if not s:Begin() then return end
					if setup then setup(s) end
					if not s:Until(os.clock() + SETTLE) then return end
					run(s, cycle, period)
				end)
				if not ok2 then warnOnce("play" .. name, name .. ": " .. tostring(err)) end
			end)
			return function() s:Stop() end
		end)
		if ok then return stop end
		warnOnce("play" .. name, name .. ": " .. tostring(stop))
		return function() end
	end
end

-- Flash Freeze's slam (CryoFX.FlashFreezeSlam) puts its late beats on timers nothing can call off: powder over the sheet
-- 1.1 s in, and the rim's break at the zone's end (chunks, powder, a ripple). A preview stopped before them still gets
-- them, so round each beat what it throws (Cryo kit chunks, and the ripple, near that zone) is put away as it comes --
-- the ripple and the shared burst rigs (the powder) only while no Cryo preview is on, since those are anyone's.
local function lateGuard(at, centre, radius)
	task.delay(math.max(0, at - os.clock() - 0.1), function()
		local fx = fxFolder()
		local function close(p) return Vector3.new(p.X - centre.X, 0, p.Z - centre.Z).Magnitude <= radius end
		local add = fx.ChildAdded:Connect(function(c)
			local k = c:IsA("BasePart") and c:GetAttribute("CryoKit")
			if type(k) ~= "string" or not close(c.Position) then return end
			if string.sub(k, 1, 9) == "CK_Chunk_" or (k == "CK_Ring" and Active == 0) then
				pcall(function() c.Parent = nil end)
			end
		end)
		local t1 = os.clock() + 0.45
		local hb
		hb = RunService.Heartbeat:Connect(function()
			if os.clock() > t1 then
				hb:Disconnect()
				add:Disconnect()
				return
			end
			if Active > 0 then return end
			for _, c in ipairs(fx:GetChildren()) do
				if burstRig(c) and close(c.Position) then pcall(function() c.Parent = nil end) end
			end
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- THE SHOT: AbilityFX's IcicleShard handler on the caster -- the palm thrust (CastPose IcicleShardR / L) and, at the
-- clip's Trigger (scaled as AbilityFX scales it), VFXLibrary.FireIcicleShard from that hand at the target's chest (the
-- shard, its Frost Line trail, CryoFX.ShardCast's frost off the palm). Its own ray stops on the target's body
-- (CryoFX.ShardImpact: the chill patch riding the part, splinters, the ripple, the cold flash). onHit(from) runs as it
-- lands: the same ray, cast here, and the flight at the shard's speed (VFXLibrary's flight starts on its first frame).
----------------------------------------------------------------------------------------------------
function S:Shoot(side, onHit)
	local c, tg = self.Caster, self.Target
	local clip = (side == "L") and "IcicleShardL" or "IcicleShardR"
	-- (2026-10-26) FROST LOTUS, as AbilityFX's IcicleShard handler plays it for a wearer: the hold-and-pluck clip, and the
	-- lotus held in the left hand (FrostLotusHold: the last shot + 1 s; FrostLotusPluck: this shot), which FrostLotusKit.M1
	-- layers on the body through CastPose. A dummy never gets them from the handler, so they are stamped here
	local fl = self.Skin == "FrostLotus" and c and kitModule("FrostLotusKit") or nil
	local lotus = K.CP.Clips and K.CP.Clips.IcicleShardLotus
	if fl and type(lotus) == "table" and type(fl.On) == "function" and fl.On(c)
		and (type(fl.PluckOn) ~= "function" or fl.PluckOn()) then
		clip = "IcicleShardLotus"
		local t, keys = now(), lotus.Keys
		local last = (type(keys) == "table" and keys[#keys] and keys[#keys].t) or 0.453
		c:SetAttribute("FrostLotusHold", t + last + 1.0)
		c:SetAttribute("FrostLotusPluck", t + 0.02)
	end
	self:Pose(clip)
	local def = K.CP.Clips and K.CP.Clips[clip]
	self:After(((def and def.Trigger) or 0.12) / castScale(), function()
		local hand = c and (c:FindFirstChild(side == "L" and "LeftHand" or "RightHand")
			or c:FindFirstChild(side == "L" and "Left Arm" or "Right Arm"))
		if not (hand and tg and tg.Parent) then return end
		local from, aim = hand.Position, chestOf(tg)
		self:Call(K.VFX.FireIcicleShard, from, aim, { c }, nil, nil, c)
		if not onHit then return end
		local IS = K.VFX.Tuning.IcicleShard
		local dir = aim - from
		if dir.Magnitude < 0.1 then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { self.Fx or fxFolder(), c }
		local hit = workspace:Raycast(from, dir.Unit * IS.Range, params)
		if hit and hit.Instance:IsDescendantOf(tg) then
			self:After(hit.Distance / (IS.Speed * K.VFX.ShotTimeScale()) + 1 / 60, function() onHit(from) end)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- M1 -- ICICLE SHARD: three taps, right, left, right (S:Shoot), each striking the target: the shard's impact on the body,
-- then the hit -- 8 and a Chill stack, as AbilityHandler's chillFromShard publishes it (CryoFX.ChillStacks through
-- React.Hit: frost climbing the shins, the third to the knees with its ankle cuffs -- the deep slow -- and CHILL xN);
-- then the stacks lapse (React.Reset breaks the crust off) and it goes again.
----------------------------------------------------------------------------------------------------
local function shardCycle(s, c0)
	for n = 1, 3 do
		s:Shoot((n % 2 == 1) and "R" or "L", function(from)
			s:Hit({ Damage = DMG.Shard, From = from, Chill = n })
		end)
		if n < 3 and not s:Until(c0 + n * M1.Gap) then return end
	end
	s:Until(c0 + M1.Clear)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY -- FLASH FREEZE: AbilityFX's FlashFreeze handler -- the caster's slam (CastPose FlashFreeze: the fist up, the
-- smash on LeadIn) and VFXLibrary.CastFlashFreeze on the floor under the target, where the crosshair puts it (the slam,
-- the front, the zone's crystals, CryoFX.FlashFreezeSlam's weather, the rim's break) -- and the server's beats on the
-- target standing in it: the contact as the front reaches it (10), the root a LingerToRoot later (FlashFreezeRoot:
-- CryoFX.Shatter, the encasing ice, held by the frozen state and FROZEN!), and the shatter at the zone's end
-- (FlashFreezeShatter, 34). The zone has no early end, so a stop takes it away at once.
----------------------------------------------------------------------------------------------------
--- when the front (VFXLibrary.FlashFreezeRadiusAt, the server's own curve) reaches `d` studs, from the slam
local function reachTime(d)
	local FFT = K.VFX.Tuning.FlashFreeze
	local t = 0
	while t < FFT.ExpandTime and K.VFX.FlashFreezeRadiusAt(t) < d do t += 0.01 end
	return t
end

local function freezeSetup(s)
	s.Casts = {}
	s:Ender(function()
		s:PutAway()            -- (a slam still to come sees its folder gone, and never comes)
		local t, R = os.clock(), K.VFX.Tuning.FlashFreeze.Radius + 3
		for _, c in ipairs(s.Casts) do
			if t >= c.Slam then
				for _, at in ipairs({ c.Slam + 1.1, c.Break }) do
					if at > t then lateGuard(at, c.Centre, R) end
				end
			end
		end
	end)
end

local function freezeCycle(s, c0)
	local st, c, tg = s.Stage, s.Caster, s.Target
	local FFT = K.VFX.Tuning.FlashFreeze
	local hold = FFT.ExpandTime + FFT.RimLinger
	local centre = s:FloorUnder(tg or c)
	s:Pose("FlashFreeze")
	s:Call(K.VFX.CastFlashFreeze, rootOf(c) or st.FloorPart, s.Rng:NextInteger(1, 2 ^ 30), c, centre)
	local slam = c0 + FFT.LeadIn
	local zoneEnd = slam + hold
	for i = #s.Casts, 1, -1 do
		if s.Casts[i].Break < c0 then table.remove(s.Casts, i) end
	end
	table.insert(s.Casts, { Slam = slam, Break = zoneEnd, Centre = centre })
	local root = rootOf(tg)
	if root then
		local from = (rootOf(c) or root).Position
		local touch = slam + reachTime(flat(root.Position - centre).Magnitude)
		if not s:Until(touch) then return end
		s:Hit({ Damage = DMG.Contact, From = from })
		local rootAt = touch + FFT.LingerToRoot
		if rootAt < zoneEnd then
			if not s:Until(rootAt) then return end
			s:Call(K.CFX.Shatter, tg, false, c)
			s:Hit({ Freeze = zoneEnd - rootAt + 0.1, NoRecoil = true })   -- (the state outlives the shatter: it breaks heavy)
			if not s:Until(zoneEnd) then return end
			s:Call(K.CFX.Shatter, tg, true, c)
			s:Hit({ Damage = DMG.Shatter, From = from })
		end
	end
	s:Until(zoneEnd + FF.Tail)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE 1 -- BLIZZARD: AbilityFX's Blizzard handler -- the caster plants it (CastPose ChillAura) and CryoFX.Blizzard
-- drops the storm on the floor under the target (the snow wall streaming round the ring, the vortex, the eight Frost Line
-- arcs going dark one by one, the frost sheet, the drifts, the gusts; the first arc where the caster faces). The target
-- is caught inside: slowed (no damage, nothing on the body a duel shows but the snow) and snowed on while the storm lasts
-- -- CryoFX's "frost on bodies", which it gives players only, so the same emitter is put on the dummy here. A storm
-- belongs to its caster (a second one ends the first at once), so two keys take turns: the next forms as the last clears.
----------------------------------------------------------------------------------------------------
--- CryoFX.Blizzard's frost on a body caught inside (its local frost(root)), in the wrap's colours
local function stormFrost(root, yaw)
	local H = K.CFX._H
	local Settings = (H and H.Settings) or {}
	local wind = CFrame.Angles(0, yaw + math.rad(90), 0).LookVector
	local att = Instance.new("Attachment")
	att.Name = "BlizzardFrost"
	att.Position = Vector3.new(0, 1.5, 0)
	local e = Instance.new("ParticleEmitter")
	e.Texture = K.T.Look.Textures.Snow
	e.Color = ColorSequence.new(K.W.C(Color3.fromRGB(240, 248, 252)))
	e.LightInfluence, e.LightEmission = 1, 0
	e.Size = NumberSequence.new(0.18)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(2, 4)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = wind * 10
	e.Rate = 25 * math.clamp(Settings.EffectDensity or 1, 0.35, 1.15)
	K.W.Lit(e)
	e.Parent = att
	att.Parent = root
	return att
end

local function stormSetup(s)
	s.Storms = { s.Caster, s:StandIn("AltarCryoStorm") }
	s.StormN = 0
	s:Ender(function()
		if s.Frost then s.Frost:Destroy() s.Frost = nil end
		for _, key in ipairs(s.Storms) do s:Call(K.CFX.BlizzardEnd, { Character = key }) end
	end)
end

local function stormCycle(s, c0)
	local st, tg = s.Stage, s.Target
	s.StormN += 1
	local key = s.Storms[(s.StormN - 1) % #s.Storms + 1]
	local R = st.CF.RightVector                 -- "12 o'clock" of the edge: where the caster faces (along R)
	local yaw = math.atan2(R.X, R.Z)
	s:Pose("ChillAura")
	s:Call(K.CFX.Blizzard, { Character = key, Center = s:FloorUnder(tg or s.Caster), T0 = now(), Duration = BZ.Time,
		Radius = BZ.Radius, Yaw = yaw })
	local root = rootOf(tg)
	if root then
		if not s:Until(c0 + BZ.Frost) then return end
		s.Frost = s:Draw(stormFrost, root, yaw)
		s:Hit({ Chill = 3, NoRecoil = true })   -- (2026-10-26) the storm's chill on the body caught inside (the sweep: no reaction)
	end
	s:Until(c0 + BZ.Time)
	if s.Frost then s.Frost:Destroy() s.Frost = nil end
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE 2 -- DEEP FREEZE: an unseen trap at the caster's feet (castDeepFreeze), no body clip (AbilityFX). The caster
-- steps up into the lane, the trap goes down under it -- the tap and the faint marker its caster alone is shown
-- (CryoFX.DeepFreezeArmed) -- and it backs off. Armed, the target walks in after it; its feet within Reach set it off as
-- AbilityHandler's springTrap does: the marker goes, the prison seals (CryoFX.DeepFreeze: the ripple, the darker frost disc
-- and its Frost Line ring, the encasing crystals, FROZEN!, the cracks, the shatter), 10 and the root (React.Hit: the
-- frozen state). Thawed, the target walks back. CastPose strides both (the target holds the Ready stance while it walks,
-- as every duel body does; handed back on the stop). Trap Ids are negative: never one of the server's.
----------------------------------------------------------------------------------------------------
local trapSeq = 0

local function trapSetup(s)
	local tg = s.Target
	if tg then
		local ok, phase = pcall(K.CP.GetCycle, tg)
		local posed = ok and phase ~= nil                       -- (already a CastPose body: someone else's to hand back)
		pcall(K.CP.SetStance, tg, "Ready")
		if not posed then s:Hold(function() pcall(K.CP.Release, tg) end) end
	end
	s:Ender(function()
		if s.TrapId then s:Call(K.CFX.DeepFreezeGone, { Id = s.TrapId, Reason = "Cleared" }) end
		s.TrapId = nil
		if s.Target then s:Call(K.CFX.DeepFreezeEnd, { Character = s.Caster, Victim = s.Target }) end
	end)
end

local function trapCycle(s, c0)
	local st, D = s.Stage, K.T.DeepFreeze
	local c, tg = s.Caster, s.Target
	local R = st.CF.RightVector
	local cHome = s.HomeCF[c]
	if not cHome then s:Until(c0 + DF.Period - 0.4) return end
	local function faceR() return R end
	local function faceL() return -R end
	-- the caster steps up toward the target, and the trap goes down under its feet
	local stepTime = DF.Step / DF.Walk
	local a, b = cHome.Position, cHome.Position + R * DF.Step
	if not s:Walk(c, stepTime, function(u) return a:Lerp(b, u) end, faceR) then return end
	local pos = s:FloorUnder(c)
	trapSeq += 1
	local id = -(1e9 + trapSeq)
	s.TrapId = id
	local armedAt = os.clock() + D.ArmTime
	-- (2026-10-26) the tap is its owner's view: its skin look read off the local body, answered here as the caster's
	s:Call(asOwner, c, K.CFX.DeepFreezeArmed, { Id = id, Position = pos, T0 = now(), ArmTime = D.ArmTime, Life = D.Life })
	-- it backs off to where it stood, still facing the target
	if not s:Until(os.clock() + DF.Pause) then return end
	if not s:Walk(c, stepTime, function(u) return b:Lerp(a, u) end, faceR) then return end
	local tHome = tg and s.HomeCF[tg]
	if not tHome then s:Until(c0 + DF.Period - 0.4) return end
	-- armed: the target walks in; its feet within Reach of the trap (flat) set it off
	if not s:Until(armedAt + DF.Go) then return end
	local ta = tHome.Position
	local tb = Vector3.new(pos.X, ta.Y, pos.Z)
	local sprung = false
	local function reached()
		local root = rootOf(tg)
		sprung = root ~= nil and flat(root.Position - pos).Magnitude <= D.Reach
		return sprung
	end
	if not s:Walk(tg, flat(tb - ta).Magnitude / DF.Walk, function(u) return ta:Lerp(tb, u) end, faceL, reached) then return end
	if not sprung then return end
	s:Call(K.CFX.DeepFreezeGone, { Id = id, Reason = "Sprung" })
	s.TrapId = nil
	local at = standAt(tg, pos) or pos
	s:Call(K.CFX.DeepFreeze, { Character = c, Victim = tg, Position = pos, At = at, T0 = now(), Duration = D.Root,
		Seed = s.Rng:NextInteger(1, 2 ^ 30) })
	s:Hit({ Damage = D.Damage, Freeze = D.Root, NoRecoil = true })
	-- thawed, it walks back to its spot
	if not s:Until(os.clock() + D.Root + DF.Hold) then return end
	local root = rootOf(tg)
	if not root then return end
	local here = root.Position
	s:Walk(tg, flat(ta - here).Magnitude / DF.Walk, function(u) return here:Lerp(ta, u) end, faceL)
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE -- MIRROR CAGE: AbilityFX's MirrorCage handler -- the caster plants it (CastPose ChillAura) and
-- CryoFX.MirrorCage locks the target and raises the dome round it on its floor (the lock-on, the clusters, the dome of
-- ice-mirror panels carrying the caster's live reflections, the volley of bolts into the trapped body, FROZEN!, the
-- shatter), the gap between two panels facing the caster as the server turns it. The trapped are rooted, never knocked;
-- each bolt's 6 lands on its Arrive (CryoTuning.MirrorCageBolts, the list the server deals by).
----------------------------------------------------------------------------------------------------
--- the cage's whole run: the last bolt lands, the kill, the lunge, the shatter and the melt (CryoFX's own beats)
local function cagePeriod()
	local ok, p = pcall(function()
		local bolts, CG = K.T.MirrorCageBolts(), K.T.Look.Cage
		return bolts[#bolts].Arrive + 0.02 + 0.33 + 0.3 + CG.MeltTime + 0.2 + MC_GAP
	end)
	return (ok and type(p) == "number") and p or 4.5
end

local function cageSetup(s)
	s.CagePeriod = cagePeriod()
	s:Ender(function()
		-- the trapped let go first (no kill flash, no FROZEN!), then the cage breaks now: the lunge, the shatter, the melt
		if s.Target then s:Call(K.CFX.MirrorCageFree, { Character = s.Caster, Victim = s.Target }) end
		s:Call(K.CFX.MirrorCageEnd, { Character = s.Caster })
	end)
end

local function cageCycle(s, c0)
	local st, c, tg = s.Stage, s.Caster, s.Target
	local centre = s:FloorUnder(tg or c)
	local rows = {}
	local stand = tg and standAt(tg, centre)
	if stand then rows[1] = { Model = tg, At = stand } end
	local cr = rootOf(c)
	local toCaster = cr and flat(cr.Position - centre) or -st.CF.RightVector
	s:Pose("ChillAura")
	s:Call(K.CFX.MirrorCage, { Character = c, Center = centre, T0 = now(), Victims = rows,
		Yaw = toCaster.Magnitude > 1e-3 and math.atan2(toCaster.X, toCaster.Z) or 0 })
	if stand then
		local ok, bolts = pcall(K.T.MirrorCageBolts)
		local dmg, from = K.T.MirrorCage.BoltDamage, centre + Vector3.new(0, 3, 0)
		if ok and type(bolts) == "table" then
			for _, b in ipairs(bolts) do
				s:After(b.Arrive, function() s:Hit({ Damage = dmg, From = from, NoRecoil = true }) end)
			end
		end
	end
	s:Until(c0 + s.CagePeriod - MC_GAP)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE -- COLD MOMENTUM: a hit lands (an Icicle Shard: 8 and a Chill stack) and the caster strides under the buff for
-- its Duration (+10 % speed; here one loop round its spot, the stage being small): AbilityFX's footfall watcher puts
-- CryoFX.ColdMomentumMark under the lower foot on every step of CastPose's walk cycle. CryoFX draws the buff itself on a
-- player only (stepColdMomentum), so its ripple and flakes on the trigger, its breath every 0.45 s and its shiver of
-- flakes at the end are drawn here with CryoFX's own helpers (CryoFX._H); its ankle cuffs are not.
----------------------------------------------------------------------------------------------------
--- one beat of CryoFX stepColdMomentum's buff on `c`: "on" (the trigger), "breath", "off" (the shiver)
local function buffBeat(c, floorY, what)
	local H = K.CFX._H
	if not (H and H.burst) then return end
	local root, feet = feetOf(c, floorY)
	if not root then return end
	local d = H.density(c)
	if what == "on" then
		if H.ripple then H.ripple(CFrame.new(root.Position.X, feet + 0.06, root.Position.Z), 0.3, 2.4, 0.5) end
		H.burst(Vector3.new(root.Position.X, feet + 0.6, root.Position.Z), Vector3.yAxis, { Flakes = 5 }, d)
	elseif what == "breath" then
		local head = c:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local lv = head.CFrame.LookVector
			H.burst(head.Position + lv * 0.6 - Vector3.new(0, 0.2, 0), lv + Vector3.new(0, -0.2, 0), { Breath = 2 }, d)
		end
	else
		H.burst(Vector3.new(root.Position.X, feet + 2.5, root.Position.Z), Vector3.yAxis, { Flakes = 18 }, d)
	end
end

local function momentumCycle(s, c0)
	local st, c = s.Stage, s.Caster
	local landed = false
	s:Shoot("R", function(from)
		landed = true
		s:Hit({ Damage = DMG.Shard, From = from, Chill = 1 })
	end)
	while not landed and os.clock() < c0 + CM.HitBy do      -- (the thrust's Trigger and the flight, on their own clocks)
		if not s:Until(os.clock() + 1 / 30) then return end
	end
	if s.Dead then return end
	local home = s.HomeCF[c]
	if not (landed and home) then return end
	local floorY = st.Floor.Y
	local R, L = st.CF.RightVector, st.CF.LookVector
	local okD, dur = pcall(function() return Config.Elements.Cryo.Passive.Duration end)
	dur = (okD and type(dur) == "number" and dur > 0) and dur or 2
	-- (2026-10-26) the window on the body as AbilityHandler opens it: Frostblade's Naruto run reads it (CastPose ->
	-- FrostbladeKit.Naruto); CryoFX / AbilityFX read it off players only, so the Default's buff is still drawn here below
	c:SetAttribute("PassiveActive", true)
	c:SetAttribute("PassiveExpires", now() + dur)
	s:Draw(buffBeat, c, floorY, "on")
	-- one loop: out along R toward the camera's side and back round to its spot, facing the way it walks
	local mid = home.Position + L * CM.Radius
	local nextBreath = os.clock() + 0.2
	s.LastStep = nil
	s:Walk(c, dur,
		function(u) local a = u * 2 * math.pi return mid + (R * math.sin(a) - L * math.cos(a)) * CM.Radius end,
		function(u) local a = u * 2 * math.pi return R * math.cos(a) + L * math.sin(a) end, nil,
		function()
			-- AbilityFX's watcher: a print on each half cycle of the stride, under the lower foot
			local ok, phase, amt = pcall(K.CP.GetCycle, c)
			if ok and phase and amt > 0.5 then
				local step = math.floor(phase / math.pi)
				if s.LastStep and step ~= s.LastStep then
					local left = c:FindFirstChild("LeftFoot") or c:FindFirstChild("Left Leg")
					local right = c:FindFirstChild("RightFoot") or c:FindFirstChild("Right Leg")
					local foot = (left and right) and ((left.Position.Y <= right.Position.Y) and left or right) or (left or right)
					if foot then s:Call(K.CFX.ColdMomentumMark, c, foot, s.Rng) end
				end
				s.LastStep = step
			else
				s.LastStep = nil
			end
			if os.clock() >= nextBreath then
				nextBreath = os.clock() + CM.Breath
				s:Draw(buffBeat, c, floorY, "breath")
			end
		end)
	if s.Dead then return end
	c:SetAttribute("PassiveActive", false)                       -- (the window shuts with the buff)
	s:Draw(buffBeat, c, floorY, "off")
	s:Until(os.clock() + CM.Tail)
end

----------------------------------------------------------------------------------------------------
-- the kit, in the loadout's order; names from SpellshotConfig (Cryo's M1 / Primary / Passive, its default Techniques
-- Blizzard and Deep Freeze -- Config.ElementDefaults.Cryo -- and its Ultimate, Config.ElementUltimate("Cryo"))
----------------------------------------------------------------------------------------------------
local function nameOf(t, key, fallback)
	local ok, n = pcall(function() return t[key].Name end)
	return (ok and type(n) == "string" and n ~= "") and n or fallback
end
local EL = (type(Config.Elements) == "table" and Config.Elements.Cryo) or {}

return {
	Element = "Cryo",
	Moves = {
		{ Key = "IcicleShard", Name = nameOf(EL, "M1", "Icicle Shard"), Slot = "M1",
			Play = preview("Icicle Shard", nil, shardCycle, M1.Period) },
		{ Key = "FlashFreeze", Name = nameOf(EL, "Primary", "Flash Freeze"), Slot = "Primary",
			Play = preview("Flash Freeze", freezeSetup, freezeCycle, FF.Period) },
		{ Key = "Blizzard", Name = nameOf(Config.Mobility, "Blizzard", "Blizzard"), Slot = "Mobility",
			Play = preview("Blizzard", stormSetup, stormCycle, BZ.Period) },
		{ Key = "DeepFreeze", Name = nameOf(Config.Defense, "DeepFreeze", "Deep Freeze"), Slot = "Defense",
			Play = preview("Deep Freeze", trapSetup, trapCycle, DF.Period) },
		{ Key = "MirrorCage", Name = nameOf(Config.Ultimate, "MirrorCage", "Mirror Cage"), Slot = "Ultimate",
			Play = preview("Mirror Cage", cageSetup, cageCycle, function(s) return s.CagePeriod or 4.5 end) },
		{ Key = "ColdMomentum", Name = nameOf(EL, "Passive", "Cold Momentum"), Slot = "Passive",
			Play = preview("Cold Momentum", nil, momentumCycle, CM.Period) },
	},
}
