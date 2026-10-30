--[[
	AltarStage  (ModuleScript)  ->  ReplicatedStorage/Spellshot/AltarStage

	THE LOADOUT SHOWCASE'S COMBAT SANDBOX (2026-10-26, the owner): two plain Roblox mannequin dummies on the showcase
	chamber's stage -- a CASTER that performs a move with the game's own cast poses (CastPose) and VFX, and a TARGET
	that takes the hit the way a duel shows it. Client only: nothing here touches the server, a Player, or damage.

	A duel's victim reads from three places (mapped 2026-10-26); each has its stand-in here:
	  * the hit's own impact VFX: the move module draws it (the same calls the Element's AbilityFX handler makes);
	  * Callouts pops over the head: the damage number, KO!, and status words (BURN xN, CHILL xN, FROZEN!, ...);
	  * status looks on the body, driven the duel's way: RX_Burning_Stacks / RX_Staggered on a Humanoid model under
	    workspace.TrainingGround (PyroFX.WatchBurnStacks / TerraFX.WatchStagger already watch exactly there),
	    CryoFX.ChillStacks for the chill crust, VFXLibrary.ApplyFrozenState for the freeze;
	  * knockback: the server launches a dummy by carrying it along its velocity under gravity (AquaHandler carryDummy);
	    the same carry here. The game has no flinch clip, so a hit without knockback gets a short recoil (a lean back
	    and settle), the minimum that reads as "it landed".
	The move modules (AltarMoves/<Element>) call React.Hit at the moment their real hit lands.

	THE CASTER'S SKIN (2026-10-26, the showcase skin convention): when stage.Skin names a skin (not nil / "Default"), the
	caster dummy WEARS it -- attributes ShowcaseSkin and StudioSkin = the id, set before it is parented (so a kit's
	ChildAdded / DescendantAdded watcher sees it on arrival) -- and every skin kit treats a non-player model so marked as
	its wearer. S.WearSkin(stage, id) changes it on a standing caster; S.Clear takes it off before the dummies go.
	S.Look(stage, element) is the one rule every move module draws by: the skin (validated against
	SkinCatalog.ElementSkins[element]) and the wrap drawn over it -- stage.Wrap goes on top of a skin only where
	SkinCatalog.WrapsOverSkin allows it (a colour wrap), else "Default" (the skin's own look).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local S = {}

-- EVERY NUMBER HERE IS A PROPOSAL
S.Tuning = {
	Apart = 7,               -- studs from the stage centre to each dummy, along stage.CF.RightVector
	Gravity = 196.2,
	Back = 0.6,              -- a knocked dummy rests this long where it lands, then is set home
	Recoil = { Lean = 11, Out = 0.08, Settle = 0.3 },   -- degrees; seconds
	Grey = Color3.fromRGB(163, 162, 165),
	RootLift = 3.192,        -- studs from the floor to a dummy's root centre (the mannequin's feet on the floor)
}

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local Callouts = nil
pcall(function() Callouts = require(spell:WaitForChild("Callouts", 5)) end)
local function ice(name)
	local f = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = f and f:FindFirstChild(name)
	if not m then return nil end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end
-- (2026-10-26) the catalog, for the skin rule (S.Look); nil while it cannot be read: every skin then reads as Default.
-- Never waits (S.Look runs inside a move's Play)
local Catalog = nil
local function catalog()
	if Catalog == nil then
		local m = spell:FindFirstChild("SkinCatalog")
		if not m then return nil end                     -- (not replicated yet: asked again next time)
		local ok, mod = pcall(require, m)
		Catalog = (ok and type(mod) == "table") and mod or false
	end
	return Catalog or nil
end
local SKIN_ATTRS = { "ShowcaseSkin", "StudioSkin" }      -- (2026-10-26) what a worn skin is stamped as on the caster

----------------------------------------------------------------------------------------------------
-- the dummies
----------------------------------------------------------------------------------------------------
--- a plain mannequin (HubLifeMannequin, re-greyed), root anchored, standing at `floor` facing `look`, under the
--- TrainingGround folder (where the duel's status watchers look for dummies). `attrs` (optional, 2026-10-26): attributes
--- stamped on the model BEFORE it is parented (a skin kit's watcher sees them the moment it arrives)
function S.Dummy(name, floor, look, attrs)
	local src = spell:FindFirstChild("HubLifeMannequin")
	if not src then return nil end
	local m = src:Clone()
	m.Name = name
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color, d.Material = S.Tuning.Grey, Enum.Material.SmoothPlastic
			d.CanCollide, d.CanTouch, d.CastShadow = false, false, true
			d.CanQuery = true                               -- (a projectile's own ray stops on the body, as on a player)
			d.Transparency = d.Name == "HumanoidRootPart" and 1 or 0
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local h = m:FindFirstChildOfClass("Humanoid")
	if not h then
		h = Instance.new("Humanoid")
		h.RigType = Enum.HumanoidRigType.R15
		h.Parent = m
	end
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.MaxHealth, h.Health = 100, 100
	pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
	local root = m:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
		m.PrimaryPart = root
		-- (2026-10-27) the legs' length: the mannequin carries no Humanoid and a new one's HipHeight is 0, so every effect
		-- that finds the feet as root - half the root - HipHeight (CryoFX's encasing ice, TerraFX, PyroFX, ZephyrFX, ...)
		-- put them 2 studs up the shins -- Flash Freeze's crystal stood off the floor
		h.HipHeight = S.Tuning.RootLift - root.Size.Y / 2
	end
	local at = floor + Vector3.new(0, S.Tuning.RootLift, 0)
	m:PivotTo(CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))   -- (placed first: it arrives where it stands)
	m:SetAttribute("AltarHome", m:GetPivot().Position)
	for k, v in pairs(attrs or {}) do m:SetAttribute(k, v) end
	local folder = workspace:FindFirstChild("TrainingGround")
	m.Parent = folder or workspace
	return m
end

----------------------------------------------------------------------------------------------------
-- the caster's skin (2026-10-26, the showcase skin convention: see the header)
----------------------------------------------------------------------------------------------------
--- the skin id `id` names, or nil (nil, "", "Default" or not a string: the Default kit)
local function skinId(id)
	return (type(id) == "string" and id ~= "" and id ~= "Default") and id or nil
end

--- What the caster wears for `element`: its skin (nil = the Default kit) and the wrap drawn (over it): stage.Wrap, or
--- "Default" when a skin is on and SkinCatalog does not let that wrap go over a skin (WrapsOverSkin: only a colour wrap
--- does; a wrap with its own material code never). A skin that is not one of `element`'s (SkinCatalog.ElementSkins) is
--- no skin. `element` nil: the skin is taken as it is.
function S.Look(stage, element)
	local wrap = (type(stage) == "table" and type(stage.Wrap) == "string" and stage.Wrap ~= "") and stage.Wrap or "Default"
	local skin = type(stage) == "table" and skinId(stage.Skin) or nil
	if not skin then return nil, wrap end
	local Cat = catalog()
	if element and Cat then
		local ok, allowed = pcall(Cat.ElementSkinAllowed, element, skin)
		if not (ok and allowed) then return nil, wrap end
	end
	if wrap ~= "Default" and element == "Radiant" then   -- (2026-10-27) Cryo / Toxin wraps paint a skin's pieces, as in a duel
		local ok, over = pcall(function() return Cat and Cat.WrapsOverSkin(wrap) end)
		if not (ok and over) then wrap = "Default" end
	end
	return skin, wrap
end

--- the caster wears skin `id` (nil / "Default": none) -- ShowcaseSkin and StudioSkin on stage.Caster -- and stage.Skin
--- says so (a move started from now on draws it; one running keeps the look it started with)
function S.WearSkin(stage, id)
	if type(stage) ~= "table" then return end
	local skin = skinId(id)
	stage.Skin = skin or "Default"
	local m = stage.Caster
	if typeof(m) ~= "Instance" then return end
	for _, a in ipairs(SKIN_ATTRS) do m:SetAttribute(a, skin) end
end

--- both dummies for a stage: the caster on the left of the centre (along -RightVector), the target on the right. The
--- caster wears stage.Skin (2026-10-26), stamped before it is parented
function S.Pair(stage)
	local r = stage.CF.RightVector
	local skin = skinId(stage.Skin)
	-- (AllyDummy: Reduce Enemy VFX must not thin the move we are showing)
	local cattrs = { AllyDummy = true }
	if skin then
		for _, a in ipairs(SKIN_ATTRS) do cattrs[a] = skin end
		if type(stage.Wrap) == "string" and stage.Wrap ~= "Default" then cattrs.ShowcaseWrap = stage.Wrap end   -- (2026-10-27)
	end
	local caster = S.Dummy("AltarCaster", stage.Floor - r * S.Tuning.Apart, r, cattrs)
	local target = S.Dummy("AltarTarget", stage.Floor + r * S.Tuning.Apart, -r)
	return caster, target
end

----------------------------------------------------------------------------------------------------
-- the reactions
----------------------------------------------------------------------------------------------------
local carried = setmetatable({}, { __mode = "k" })
local function homeOf(m)
	local h = m:GetAttribute("AltarHome")
	local p = m:GetPivot()
	return h and (p - p.Position + h) or p
end

--- throw the target: carried along `velocity` (studs/s) under gravity, rests, then set home (the dummy launch)
function S.Knock(stage, velocity)
	local m = stage and stage.Target
	if not m or not m.Parent or carried[m] then return end
	local home = homeOf(m)
	local g = S.Tuning.Gravity
	local air = math.clamp(2 * math.max(velocity.Y, 4) / g, 0.35, 1.4)
	carried[m] = true
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if not m.Parent or not carried[m] then
			conn:Disconnect()
			carried[m] = nil
			return
		end
		if t >= air + S.Tuning.Back then
			conn:Disconnect()
			carried[m] = nil
			m:PivotTo(home)
			return
		end
		local u = math.min(t, air)
		local off = Vector3.new(velocity.X * u, math.max(0, velocity.Y * u - 0.5 * g * u * u), velocity.Z * u)
		-- a thrown body tips back with the throw and rights itself on landing
		local tip = (t < air) and math.sin(math.min(1, t / air) * math.pi) * math.rad(-24) or 0
		m:PivotTo((home + off) * CFrame.Angles(tip, 0, 0))
	end)
end

--- the stand-in flinch: a quick lean away from the hit and a settle
function S.Recoil(stage, from)
	local m = stage and stage.Target
	if not m or not m.Parent or carried[m] then return end
	local home = homeOf(m)
	local R = S.Tuning.Recoil
	local away = from and (home.Position - from) or -home.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 1e-3 then away = -home.LookVector end
	local axis = away.Unit:Cross(Vector3.yAxis)
	carried[m] = true
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if not m.Parent or not carried[m] then
			conn:Disconnect()
			carried[m] = nil
			return
		end
		local k = (t < R.Out) and (t / R.Out) or math.max(0, 1 - (t - R.Out) / R.Settle)
		k = k * k * (3 - 2 * k)
		m:PivotTo(CFrame.fromAxisAngle(axis, math.rad(-R.Lean) * k) * (home - home.Position) + home.Position + away.Unit * 0.25 * k)
		if t >= R.Out + R.Settle then
			conn:Disconnect()
			carried[m] = nil
			m:PivotTo(home)
		end
	end)
end

local function pop(m, offset, text, style, held)
	local head = m and m:FindFirstChild("Head")
	if not (Callouts and head) then return nil end
	local ok, release = pcall(Callouts.Pop, head, offset, text, style, held)
	return ok and release or nil
end

--- the hit, as a duel shows it to everyone watching. opts (all optional):
---   Damage = n            the damage number pop ("damage")
---   From = Vector3        where the hit came from (the recoil leans away from it)
---   Knock = Vector3       a launch velocity (studs/s); else a recoil
---   NoRecoil = true       neither (a hit that holds the victim in place: a freeze, a tomb)
---   Stagger = s           RX_Staggered for s seconds (the dizzy stars)
---   Burn = stacks         RX_Burning_Stacks (cleared after BurnFor, default 3 s) and the BURN xN pop
---   Chill = stacks        the chill crust (CryoFX.ChillStacks) and the CHILL xN pop
---   Freeze = s            the frozen state (VFXLibrary.ApplyFrozenState) and the held FROZEN! pop
---   Word = text, Style = callout style   any other status word (e.g. "POISON", "poison")
function S.Hit(stage, opts)
	local m = stage and stage.Target
	if not m or not m.Parent then return end
	m:SetAttribute("AltarHits", (m:GetAttribute("AltarHits") or 0) + 1)   -- (2026-10-26) a count the sweep reads
	opts = opts or {}
	local h = m:FindFirstChildOfClass("Humanoid")
	if opts.Damage and opts.Damage > 0 then
		pop(m, Vector3.new(0, 1.2, 0), tostring(math.floor(opts.Damage + 0.5)), "damage")
		if h then h.Health = math.max(1, h.Health - opts.Damage) end
	end
	if opts.Knock then
		S.Knock(stage, opts.Knock)
	elseif not opts.NoRecoil then
		S.Recoil(stage, opts.From)
	end
	if opts.Stagger then
		m:SetAttribute("RX_Staggered", true)
		task.delay(opts.Stagger, function() if m.Parent then m:SetAttribute("RX_Staggered", false) end end)
	end
	if opts.Burn then
		m:SetAttribute("RX_Burning_Stacks", opts.Burn)
		pop(m, Vector3.new(0, 2.6, 0), "BURN x" .. opts.Burn, "burn")
		local stamp = os.clock()
		m:SetAttribute("AltarBurnStamp", stamp)
		task.delay(opts.BurnFor or 3, function()
			if m.Parent and m:GetAttribute("AltarBurnStamp") == stamp then m:SetAttribute("RX_Burning_Stacks", nil) end
		end)
	end
	if opts.Chill then
		local CryoFX = ice("CryoFX")
		if CryoFX then pcall(CryoFX.ChillStacks, { Character = m, Stacks = opts.Chill, Caster = stage.Caster }) end
		pop(m, Vector3.new(0, 2.6, 0), "CHILL x" .. opts.Chill, "chill")
	end
	if opts.Freeze then
		local VFX = ice("VFXLibrary")
		if VFX then pcall(VFX.ApplyFrozenState, m, opts.Freeze) end
		local release = pop(m, Vector3.new(0, 2.6, 0), "FROZEN!", "frozen", true)
		if release then task.delay(opts.Freeze, function() pcall(release) end) end
	end
	if opts.Word then
		pop(m, Vector3.new(0, 2.6, 0), opts.Word, opts.Style or "damage")
	end
	if h and h.Health <= 1 then h.Health = h.MaxHealth end   -- (the dummy never falls: the next loop starts fresh)
end

--- both dummies back to how they started: home, full health, every status cleared (a preview's stop calls this)
function S.Reset(stage)
	for _, m in ipairs({ stage and stage.Caster, stage and stage.Target }) do
		if m and m.Parent then
			carried[m] = nil
			m:PivotTo(homeOf(m))
			for _, a in ipairs({ "RX_Staggered", "RX_Burning_Stacks", "RX_Chilled_Stacks", "AltarBurnStamp", "MoveState" }) do
				m:SetAttribute(a, nil)
			end
			local frozen = m:FindFirstChild("IceFrozenState")
			if frozen then frozen:Destroy() end
			local CryoFX = ice("CryoFX")
			if CryoFX and m == stage.Target then pcall(CryoFX.ChillStacks, { Character = m, Stacks = 0, Caster = stage.Caster }) end
			local h = m:FindFirstChildOfClass("Humanoid")
			if h then h.Health = h.MaxHealth end
		end
	end
end

--- the dummies gone (the showcase calls this when a preview ends or the chamber closes); the caster's skin taken off
--- first (2026-10-26), so a kit watching the attribute lets go of it before the model goes
function S.Clear(stage)
	local CastPose = ice("CastPose")
	for _, m in ipairs({ stage and stage.Caster, stage and stage.Target }) do
		if m then
			carried[m] = nil
			for _, a in ipairs(SKIN_ATTRS) do pcall(m.SetAttribute, m, a, nil) end
			pcall(m.SetAttribute, m, "ShowcaseWrap", nil)
			if CastPose then pcall(CastPose.Release, m) end
			Debris:AddItem(m, 0)
		end
	end
end

return S
