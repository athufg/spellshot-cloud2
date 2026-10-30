--[[
	UmbraClient  (ModuleScript)  ->  ReplicatedStorage/IceMagic/UmbraClient          PHASE 4 (2026-09-28), replaces Phase 2's

	UMBRA's client half. UmbraHandler is the server. SpellshotInput requires this (guarded, like VoltaicClient) for the
	Shadow Dart click and binds its own gates; AbilityFX merges Handlers for every Umbra broadcast. Every number is
	UmbraTuning's. What changed from Phase 2, and nothing else:
	  THE LOOK    every stand-in (the dark ball, the puff, the chest light, the ColorCorrection darkening) is gone: each
	              broadcast and each local click now drives UmbraFX (ReplicatedStorage.IceMagic.UmbraFX), the approved Phase 3
	              look. UmbraFX missing or broken: the kit plays exactly as before, it just draws nothing.
	  THE CHARGE  the OWNER's 2.3 s from click to release: Windup, divided by the character's M1RateMult (Eclipse's 1.5x:
	              ~1.53 s) and by ShotTimeScale -- the very number UmbraHandler.castDartCharge counts, so the release it checks
	              (no sooner than Due - ChargeSlack) is the one this client sends.
	  THE BODY    no clip is played here: every Umbra animation is UmbraAnim's (ReplicatedStorage.IceMagic.UmbraAnim, the
	              animation agent's module) -- started once below, its LocalCast merged into ours, its LocalDartCharge playing
	              the arms at the click and its DartMayStart gating the click. Without UmbraAnim the Phase 2 gate stands.
	KEPT EXACTLY: the dart's two claims (ShadowDartRelease { Id, Origin = the eye, Target } on the release,
	ShadowDartHit { Id, Part, Position } on contact, UmbraHandler checks both), ownExclude, Bind, and FireM1's contract
	with SpellshotInput (true when the ability is Shadow Dart, whether or not a dart went; false otherwise). The Mark
	marker is still the TEMP placeholder anchor (the owner: keep it).

	  FireM1(character, ability) -> true if it was Shadow Dart. The click pays (CastRequest "M1": SpellshotService's rate
	      and mana; UmbraHandler starts the charge from it and tells everyone, ShadowDartCharge). The charge gathers on the
	      viewmodel's right fist (UmbraFX.DartCharge) for the charge time, then the dart leaves the EYE down the crosshair
	      (VFXLibrary.LocalAimCFrame, so the third-person test view shoots true too), drawn from the ball. This client flies
	      it and claims what it touched; the hit and the Tell are drawn at once, the server's word adds the Mark payoff.
	  Bind(fns)   SpellshotInput's own gates: Flash, CanCast, AimPoint, BlockedByMovement.
	  LocalCast   UmbraAnim's keypress arms (SpellshotInput merges it into LOCAL_CAST: one line there, see NEEDS.md).
	  Handlers    ShadowDartCharge / ShadowDart / ShadowDartHit / ShadowStepOut / ShadowStepIn / MarkApplied / MarkStack /
	              MarkEnd / DecoySpawn / DecoyBreak / EclipseCharge / EclipseCancel / EclipseStart / EclipseEnd.

	CLOCKS. A broadcast's drawing starts when this client RECEIVES it (os.clock), as UmbraAnim's body clips do: what it
	lines up with (a body moved, a dart released, a decoy made) reaches this client one latency after the server too.
	ECLIPSE for the viewer: the vortex is drawn for everyone near; the world grade (V4), the pulse, the ground wave, the
	wisps and the screen layer for everyone in the caster's arena (Zone and Map), the caster's own screen the lighter one
	and every enemy's the stronger; the light-purple outline on every enemy, through walls, on the CASTER's client only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local UmbraClient = {}
UmbraClient.LocalCast = {}
UmbraClient.Handlers = {}

----------------------------------------------------------------------------------------------------
-- modules, found lazily (never a wait on the input path)
----------------------------------------------------------------------------------------------------
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local T = require(iceFolder:WaitForChild("UmbraTuning"))
local mods = {}
local function need(name)
	if mods[name] ~= nil then return mods[name] or nil end
	local m = iceFolder:FindFirstChild(name) or spellFolder:FindFirstChild(name)
	local ok, mod = pcall(function() return m and require(m) end)
	mods[name] = (ok and mod) or false
	if not ok then warn("[UmbraClient] " .. name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[UmbraClient] " .. tostring(msg))
end

-- an inert handle, for when UmbraFX is not there: every method a no-op
local NULL = setmetatable({}, { __index = function() return function() return nil end end })

--- UmbraFX.<fn>(...), guarded: a missing module or function, or an error in it, draws nothing and never stops a mechanic
local function fx(fn, ...)
	local F = need("UmbraFX")
	local f = F and F[fn]
	if type(f) ~= "function" then return NULL end
	local ok, res = pcall(f, ...)
	if not ok then
		warnOnce("fx:" .. fn, "UmbraFX." .. fn .. " failed: " .. tostring(res))
		return NULL
	end
	return res or NULL
end

--- UmbraAnim.<fn>(...), guarded; `ok` false when the module or the function is not there or it errored
local function anim(fn, ...)
	local A = need("UmbraAnim")
	local f = A and A[fn]
	if type(f) ~= "function" then return false, nil end
	local ok, res = pcall(f, ...)
	if not ok then warnOnce("anim:" .. fn, "UmbraAnim." .. fn .. " failed: " .. tostring(res)) end
	return ok, res
end

-- UmbraAnim: its own broadcast listener, and its keypress arms joining our LocalCast (SpellshotInput merges ours)
task.spawn(function()
	local A = need("UmbraAnim")
	if not A then return end
	anim("Start")
	for id, fn in pairs(type(A.LocalCast) == "table" and A.LocalCast or {}) do
		UmbraClient.LocalCast[id] = UmbraClient.LocalCast[id] or fn
	end
end)

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function timeScale()
	local V = need("VFXLibrary")
	local ok, s = pcall(function() return V and V.ShotTimeScale() end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

local function rateMult(character)
	local m = character and character:GetAttribute("M1RateMult")
	return (type(m) == "number" and m > 0) and m or 1
end

local function aimCF()
	local V = need("VFXLibrary")
	local fn = V and V.LocalAimCFrame
	local ok, cf = false, nil
	if type(fn) == "function" then ok, cf = pcall(fn) end
	return (ok and typeof(cf) == "CFrame") and cf or workspace.CurrentCamera.CFrame
end

local function fxFolder()
	local V = need("VFXLibrary")
	local name = V and V.Config and V.Config.FXFolderName or "IceMagicFX"
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

--- Your own darts pass through yourself, the camera, the FX, your own decoy and everyone you may not hurt.
local function ownExclude(character)
	local list = { character, workspace.CurrentCamera, fxFolder() }
	local decoys = workspace:FindFirstChild("UmbraDecoys")
	if decoys then
		for _, d in ipairs(decoys:GetChildren()) do
			if d:GetAttribute("DecoyOwner") == player.UserId then list[#list + 1] = d end
		end
	end
	local Config = need("SpellshotConfig")
	if Config and type(Config.AddUnhurtable) == "function" then pcall(Config.AddUnhurtable, list, player) end
	return list
end

local function iceRemote()
	return iceFolder:FindFirstChild("IceAbilityRemote")
end

local function castRemote()
	return spellFolder:FindFirstChild("CastRequest")
end

local function isModel(v)
	return typeof(v) == "Instance" and v:IsA("Model")
end

--- whether this viewer's own arms are the viewmodel's (first person); the local body's effects go on them then
local function localFirstPerson()
	local F = need("UmbraFX")
	local ok, v = pcall(function() return F and F.LocalFirstPerson() end)
	return ok and v == true
end

----------------------------------------------------------------------------------------------------
-- THE DART'S FLIGHT: flown here every Heartbeat (the claim is this client's), drawn by UmbraFX.Dart
----------------------------------------------------------------------------------------------------
local flights = setmetatable({}, { __mode = "k" })    -- [shooter character] = { [id] = flight }: to snap a remote dart

--- A dart in flight: drawn only (another body's shot, onHit nil) or flown and claimed (your own). The visual leaves
--- `visualFrom` (the charge ball) and eases onto the eye's line over FX.Dart.EaseOver studs, as Phase 2's did.
local function flyDart(from, dir, visualFrom, exclude, onHit, owner, id)
	local D = T.ShadowDart
	local ease = (T.FX and T.FX.Dart and T.FX.Dart.EaseOver) or 12
	local scale = timeScale()
	local look = fx("Dart", owner)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	local travelled = 0
	local flight = { Dir = dir, Start = os.clock(), Done = false }
	local conn
	local function finish()
		flight.Done = true
		if conn then
			conn:Disconnect()
			conn = nil
		end
		local mine = owner and flights[owner]
		if mine and id then mine[id] = nil end
	end
	local function visAt(x)
		local k = math.clamp(x / ease, 0, 1)
		return (visualFrom and visualFrom:Lerp(from, k) or from) + dir * x
	end
	--- the server's word on where a drawn-only dart stopped
	function flight.Snap(point)
		if flight.Done then return end
		finish()
		look:Impact(point, dir)
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = D.Speed * scale * dt
		local a = from + dir * travelled
		local hit = workspace:Spherecast(a, D.Radius, dir * step, params)
		travelled += step
		if hit then
			finish()
			look:Impact(hit.Position, dir)
			if onHit then onHit(hit, os.clock() - flight.Start) end
			return
		end
		if travelled >= D.Range then
			finish()
			look:Expire()
			return
		end
		local vis = visAt(travelled)
		local ahead = visAt(travelled + 0.05) - vis
		look:Move(vis, ahead.Magnitude > 1e-6 and ahead.Unit or dir, travelled)
	end)
	if owner and id ~= nil then
		flights[owner] = flights[owner] or {}
		flights[owner][id] = flight
	end
	return flight
end

----------------------------------------------------------------------------------------------------
-- Bind: SpellshotInput's own gates
----------------------------------------------------------------------------------------------------
local bound = {}
function UmbraClient.Bind(fns)
	if type(fns) == "table" then bound = fns end
end

----------------------------------------------------------------------------------------------------
-- MARK: the TEMP placeholder anchor (the owner: keep it until Mark's own look)
----------------------------------------------------------------------------------------------------
-- (2026-10-19, audit P5C-17) weak-keyed: a victim model gone from memory takes its entry with it
local anchors = setmetatable({}, { __mode = "k" })
local function anchorFor(victim, stacks)
	local head = victim and victim:FindFirstChild("Head")
	if not head then return end
	local a = anchors[victim]
	if not a then
		a = Instance.new("Part")
		a.Name = "UmbraMarkAnchor"
		a.Shape = Enum.PartType.Block
		a.Material = Enum.Material.SmoothPlastic
		a.Color = T.Color.Dusk
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
		a.Parent = fxFolder()
		anchors[victim] = a
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not (a.Parent and head.Parent) then
				-- (2026-10-19, audit P5C-17) a MarkEnd that never comes (the victim left or streamed out): the anchor goes
				-- with the head, and predictHeadshot stops counting the model as marked
				conn:Disconnect()
				if anchors[victim] == a then anchors[victim] = nil end
				if a.Parent then a:Destroy() end
				return
			end
			a.CFrame = CFrame.new(head.Position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(math.rad(45), os.clock() * 1.5, math.rad(45))
			local gl = a:FindFirstChild("UmbraMarkGlow")            -- an Epic+ wrap's marker light, breathing (UR 2026-10-19)
			if gl then
				local k = fx("MarkPulse", player.Character)
				gl.Brightness = (a:GetAttribute("GlowLight") or 0) * (type(k) == "number" and k or 1)
			end
		end)
	end
	local s = 0.35 + 0.15 * (stacks or 1)
	a.Size = Vector3.new(s, s, s)
	-- the marker wears its owner's Umbra wrap (an Element wrap, through UmbraFX.Palette), else Umbra's own colours
	local pal = fx("Palette", player.Character)
	if typeof(pal.Dusk) ~= "Color3" then pal = T.Color end
	a.Color = (stacks or 1) >= T.Mark.MaxStacks and pal.Shade or pal.Dusk
	-- a Rare wrap's finish on the marker once it turns light (full stacks): its own display input and gloss; a dark
	-- marker stays matte (a glossy black mirrors the sky)
	local fin = (stacks or 1) >= T.Mark.MaxStacks and fx("MarkFinish", player.Character) or nil
	local lit = type(fin) == "table" and typeof(rawget(fin, "Lit")) == "Color3"
	if lit then a.Color = fin.Lit end
	a.Reflectance = (lit and type(rawget(fin, "Reflectance")) == "number") and fin.Reflectance or 0
	-- (Mark.Material, R2U 2026-10-19: the lit marker in a real material, e.g. veined stone; none: SmoothPlastic as before)
	local mat = lit and rawget(fin, "Material")
	a.Material = (type(mat) == "string" and Enum.Material[mat]) or Enum.Material.SmoothPlastic
	-- an Epic+ wrap's glow (UmbraFX.MarkGlow = { Light, Range }): the marker self-lit (Neon) with a light in the wrap's
	-- Shade, breathing with its Pulse (above); a lower-tier wrap or Default keeps the plain marker
	local mg = fx("MarkGlow", player.Character)
	if type(rawget(mg, "Light")) == "number" then
		a.Material = Enum.Material.Neon
		a.Reflectance = 0
		-- (Neon renders far brighter and bluer than its input: the wrap's own Neon display inputs, Lit at full stacks)
		local nl = (stacks or 1) >= T.Mark.MaxStacks and rawget(mg, "Lit") or rawget(mg, "Dim")
		if typeof(nl) == "Color3" then a.Color = nl end
		local gl = a:FindFirstChild("UmbraMarkGlow")
		if not gl then
			gl = Instance.new("PointLight")
			gl.Name = "UmbraMarkGlow"
			gl.Shadows = false
			gl.Parent = a
		end
		gl.Color = typeof(rawget(mg, "Color")) == "Color3" and mg.Color or pal.Shade
		gl.Range = rawget(mg, "Range") or 8
		a:SetAttribute("GlowLight", mg.Light)
	end
end

--- whether a contact on `part` is, as far as this client can tell, the Mark HEADSHOT payoff: the head of a body carrying
--- this client's own mark (the server's isHeadshot decides; this only picks the look drawn at once)
local function predictHeadshot(part)
	-- a head's hitbox twin (HitboxScale, 2026-10-17) counts as the head
	if not (typeof(part) == "Instance" and (part:GetAttribute("HitboxOf") or part.Name) == "Head") then return false end
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and anchors[model] ~= nil
end

----------------------------------------------------------------------------------------------------
-- M1: SHADOW DART
----------------------------------------------------------------------------------------------------
local shotId = 0
local charging = nil          -- { Start, Due, Look, Character } during the charge
local ownDarts = {}           -- [id] = { At, Dir, Head }: darts this client flew itself (their broadcasts are not drawn twice)

--- The charge time the server counts: Windup / M1RateMult / ShotTimeScale (UmbraHandler.castDartCharge's own Due)
local function chargeTime(character)
	return T.ShadowDart.Windup / rateMult(character) / timeScale()
end

function UmbraClient.FireM1(character, ability)
	if type(ability) ~= "table" or ability.Id ~= "ShadowDart" then return false end
	if not (character and character.Parent) or player.Character ~= character or charging then return true end
	-- the arms gate: UmbraAnim's (it lets a dart cut its own recovery, which FireInterval 2.6 < the clip's 2.8 needs),
	-- else Phase 2's
	local okGate, may = anim("DartMayStart")
	if okGate then
		if may == false then return true end
	else
		local VM = need("Viewmodel")
		if VM and (VM.Tracing() or VM.IsPlaying()) then return true end
	end
	local D = T.ShadowDart
	-- the click pays (SpellshotService: the rate and the mana) and starts the charge on the server (ShadowDartCharge)
	local cast = castRemote()
	if cast then cast:FireServer("M1", { Side = "R" }) end
	-- THE CHARGE: the arms (UmbraAnim, which returns its own release time) and the gather on the fist
	local due = chargeTime(character)
	local okArms, armsDue = anim("LocalDartCharge", character)
	if okArms and type(armsDue) == "number" and armsDue > 0 then
		due = math.max(due, armsDue)           -- never sooner than the server will accept
	end
	local start = os.clock()
	local c = { Start = start, Due = due, Character = character }
	c.Look = fx("DartCharge", character, start, due)
	charging = c

	local function release()
		if charging ~= c then return end
		-- the server counted a longer charge (Eclipse ended between the click and its arrival): wait it out
		local left = c.Start + c.Due - os.clock()
		if left > 0.004 then
			task.delay(left, release)
			return
		end
		charging = nil
		local hum = character:FindFirstChildOfClass("Humanoid")
		if player.Character ~= character or not character.Parent or not (hum and hum.Health > 0) then
			c.Look:Cancel()
			return
		end
		local acf = aimCF()
		local eye = acf.Position
		local target = bound.AimPoint and bound.AimPoint(D.Range) or (eye + acf.LookVector * D.Range)
		local dir = target - eye
		if dir.Magnitude < 0.1 then
			c.Look:Cancel()
			return
		end
		dir = dir.Unit
		shotId += 1
		local id = shotId
		local mine = { At = os.clock(), Dir = dir, Head = false }
		ownDarts[id] = mine
		local remote = iceRemote()
		if remote then remote:FireServer("ShadowDartRelease", { Id = id, Origin = eye, Target = target }) end
		-- the look: the ball collapses lit, the Tell, and the dart leaves the ball
		local from = c.Look:BallPosition()
		c.Look:Release()
		fx("Tell", character, "Fire")
		flyDart(eye, dir, typeof(from) == "Vector3" and from or nil, ownExclude(character), function(hit, flightTime)
			if remote then remote:FireServer("ShadowDartHit", { Id = id, Part = hit.Instance, Position = hit.Position }) end
			fx("Tell", character, "Hit")
			if predictHeadshot(hit.Instance) then
				mine.Head = true
				fx("MarkHeadshot", hit.Position, dir, { Owner = character, FlightTime = flightTime })
			else
				fx("Hit", hit.Position, dir, { Owner = character, FlightTime = flightTime })
			end
		end, character, id)
		-- old records go (a dart that never hit)
		for oldId, rec in pairs(ownDarts) do
			if os.clock() - rec.At > 5 then ownDarts[oldId] = nil end
		end
	end
	task.delay(due, release)
	return true
end

----------------------------------------------------------------------------------------------------
-- Handlers (AbilityFX merges these)
----------------------------------------------------------------------------------------------------
local H = UmbraClient.Handlers
local remoteCharges = setmetatable({}, { __mode = "k" })   -- [character] = its charge's look (another body's)

--- the click's charge on every body (NEW broadcast: { Character, T0, Windup } -- or { Mult } in the animation agent's
--- draft; both are read)
H.ShadowDartCharge = function(d)
	local c = d.Character
	if not isModel(c) then return end
	local due = tonumber(d.Windup)
	if not due then due = T.ShadowDart.Windup / (tonumber(d.Mult) or rateMult(c)) / timeScale() end
	if c == player.Character then
		-- ours has been drawn since the click; only a longer charge the server counts moves our release
		if charging and charging.Character == c and due > charging.Due + 0.02 then
			charging.Due = due
			charging.Look:SetDue(due)
		end
		return
	end
	local old = remoteCharges[c]
	if old then old:Cancel() end
	remoteCharges[c] = fx("DartCharge", c, os.clock(), due)
end

--- the release: the Tell, and another body's dart leaving its ball
H.ShadowDart = function(d)
	local c = d.Character
	if not isModel(c) then return end
	if c == player.Character then return end                         -- the shooter drew its own
	fx("Tell", c, "Fire")
	local charge = remoteCharges[c]
	local from = nil
	if charge then
		remoteCharges[c] = nil
		from = charge:BallPosition()
		charge:Release()
	end
	if typeof(from) ~= "Vector3" then
		local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		from = hand and hand.Position or nil
	end
	if typeof(d.Origin) ~= "Vector3" or typeof(d.Dir) ~= "Vector3" or d.Dir.Magnitude < 1e-3 then return end
	flyDart(d.Origin, d.Dir.Unit, from, { c, fxFolder() }, nil, c, d.Id)
end

--- the server's word on a hit: another body's splash (ours was drawn at our own contact) and the Mark headshot payoff
H.ShadowDartHit = function(d)
	local shooter = d.Character
	if typeof(d.Point) ~= "Vector3" then return end
	local own = isModel(shooter) and shooter == player.Character
	local flight = isModel(shooter) and flights[shooter] and flights[shooter][d.Id] or nil
	local rec = own and ownDarts[d.Id] or nil
	local dir = (rec and rec.Dir) or (flight and flight.Dir) or nil
	if not dir and isModel(shooter) then
		local head = shooter:FindFirstChild("Head")
		dir = head and (d.Point - head.Position) or nil
		dir = (dir and dir.Magnitude > 1e-3) and dir.Unit or nil
	end
	dir = dir or Vector3.zAxis
	local headshot = d.Head == true and (tonumber(d.MarkBonus) or 0) > 0
	if own then
		-- drawn at the contact; only a headshot this client did not foresee is added
		if headshot and not (rec and rec.Head) then fx("MarkHeadshot", d.Point, dir, { Owner = shooter }) end
		ownDarts[d.Id] = nil
		return
	end
	local flightTime = flight and (os.clock() - flight.Start) or nil
	if flight then flight.Snap(d.Point) end
	if isModel(shooter) then fx("Tell", shooter, "Hit") end
	if headshot then
		fx("MarkHeadshot", d.Point, dir, { Owner = shooter, FlightTime = flightTime })
	else
		fx("Hit", d.Point, dir, { Owner = shooter, FlightTime = flightTime })
	end
end

-- SHADOW STEP: the body is gone from every other view between the dissolve and the re-form
local hidden = {}
local function hide(c, on)
	if not isModel(c) or c == player.Character then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = on and 1 or 0 end
	end
	hidden[c] = on or nil
end

H.ShadowStepOut = function(d)
	local c = d.Character
	local dissolve = tonumber(d.Dissolve) or (T.ShadowStep.DissolveTime / timeScale())
	local mine = c == player.Character
	local fp = mine and localFirstPerson()
	fx("StepOut", c, d.From, d.To, { Start = os.clock(), Dissolve = dissolve, FirstPerson = fp,
		LandedAt = fp and function()
			local ok, at = anim("OwnStepLandedAt")
			return ok and at or nil
		end or nil })
	-- others see the cue first (the knees give), then the body is gone (the drawing's HideAt beat)
	local S = T.FX and T.FX.Step
	local hideAfter = S and (S.HideAt / S.SpecDissolve * dissolve) or 0
	local token = {}
	hidden[c] = token
	task.delay(hideAfter, function()
		if hidden[c] == token then hide(c, true) hidden[c] = token end
	end)
	task.delay(math.max(0.3, dissolve + 0.4), function()      -- a backstop if the re-form never comes
		if hidden[c] == token then hide(c, false) end
	end)
end

H.ShadowStepIn = function(d)
	local c = d.Character
	hidden[c] = nil                                           -- a hide still pending is cancelled
	hide(c, false)
end

-- MARK: the HUNTED! pop and the victim's bar look are the server's attributes and Callouts; the marker's anchor is here
H.MarkApplied = function(d)
	if d.Character == player.Character and isModel(d.Victim) then anchorFor(d.Victim, 1) end
end

H.MarkStack = function(d)
	if anchors[d.Victim] then anchorFor(d.Victim, d.Stacks) end
end

H.MarkEnd = function(d)
	local a = anchors[d.Victim]
	if a then
		anchors[d.Victim] = nil
		a:Destroy()                                           -- the payoff's look is the hit's (ShadowDartHit)
	end
end

-- DECOY DOUBLE: the peel (everyone; the caster's arm copy in first person) and the break (the Tell when it was hit)
H.DecoySpawn = function(d)
	if not isModel(d.Decoy) then return end
	local mine = d.Owner == player.Character
	fx("DecoyPeel", d.Owner, d.Decoy, { Start = os.clock(), FirstPerson = mine and localFirstPerson() })
end

H.DecoyBreak = function(d)
	local hitBy = d.Reason == "Hit"
	if isModel(d.Decoy) then
		fx("DecoyBreak", d.Decoy, { Owner = d.Owner, HitAt = d.HitAt, Seed = d.Seed, Lit = hitBy })
	end
	if hitBy and isModel(d.Owner) then fx("Tell", d.Owner, "Decoy") end
end

----------------------------------------------------------------------------------------------------
-- ECLIPSE
----------------------------------------------------------------------------------------------------
local eclipseLooks = {}       -- [caster UserId] = its UmbraFX.Eclipse handle
local darkBy = {}             -- [caster UserId] = a token: which Eclipses graded this view

local function undarken(caster, token)
	if darkBy[caster] and (token == nil or darkBy[caster] == token) then
		darkBy[caster] = nil
		fx("GradePop", caster)
	end
end

local function enemyBodies()
	local out = {}
	local Config = need("SpellshotConfig")
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if p ~= player and c and (not Config or not Config.MayHurt or Config.MayHurt(player, p)) then out[#out + 1] = c end
	end
	local range = workspace:FindFirstChild("TrainingGround")
	if range then
		for _, d in ipairs(range:GetDescendants()) do
			if d:IsA("Humanoid") and d.Parent:IsA("Model") then out[#out + 1] = d.Parent end
		end
	end
	local decoys = workspace:FindFirstChild("UmbraDecoys")
	if decoys then
		for _, d in ipairs(decoys:GetChildren()) do
			if d:GetAttribute("DecoyOwner") ~= player.UserId then out[#out + 1] = d end
		end
	end
	return out
end

--- the Eclipse's look for a caster, made on its windup (EclipseCharge) or, with none heard, on its open
local function lookFor(d, windup)
	local key = d.Caster
	local h = key ~= nil and eclipseLooks[key] or nil
	if h then return h end
	local c = d.Character
	if not isModel(c) then return NULL end
	h = fx("Eclipse", c, { Start = os.clock(), Windup = windup,
		FirstPerson = c == player.Character and localFirstPerson() })
	if key ~= nil then eclipseLooks[key] = h end
	return h
end

--- the windup (NEW broadcast: { Character, Caster, T0, Windup } -- or { OpenAt } in the animation agent's draft)
H.EclipseCharge = function(d)
	local key = d.Caster
	if key ~= nil and eclipseLooks[key] then
		eclipseLooks[key]:Cancel()
		eclipseLooks[key] = nil
	end
	local windup = tonumber(d.Windup)
	if not windup and tonumber(d.OpenAt) and tonumber(d.T0) then windup = d.OpenAt - d.T0 end
	lookFor(d, windup or (T.Eclipse.WindupTime / timeScale()))
end

--- died or cleared in the windup (NEW broadcast: { Character, Caster, Reason })
H.EclipseCancel = function(d)
	local key = d.Caster
	local h = key ~= nil and eclipseLooks[key] or nil
	if h then
		eclipseLooks[key] = nil
		h:Cancel()
	end
end

H.EclipseStart = function(d)
	local c = d.Character
	local mine = c == player.Character
	local same = player:GetAttribute("Zone") == d.Zone and player:GetAttribute("Map") == d.Map
	local inArena = mine or (same and d.Zone ~= "Hub")
	-- the screen layer: the caster the lighter, an enemy inside the stronger (a teammate, should one exist, the lighter)
	local who = nil
	if mine then
		who = "caster"
	elseif inArena then
		local casterPlayer = isModel(c) and Players:GetPlayerFromCharacter(c) or nil
		local Config = need("SpellshotConfig")
		local hostile = true
		if casterPlayer and Config and type(Config.MayHurt) == "function" then
			local ok, may = pcall(Config.MayHurt, casterPlayer, player)
			hostile = not ok or may == true
		end
		who = hostile and "enemy" or "caster"
	end
	local duration = (tonumber(d.Until) and tonumber(d.T0)) and (d.Until - d.T0) or (T.Eclipse.Duration / timeScale())
	local now = os.clock()
	local look = lookFor(d, 0)
	look:Open(now, now + duration, { Domain = inArena, Screen = who })
	-- the world grade (V4), for everyone in the arena
	if inArena and d.Caster ~= nil then
		undarken(d.Caster)
		local token = {}
		darkBy[d.Caster] = token
		fx("GradePush", d.Caster)
		-- a backstop for a lost EclipseEnd
		task.delay(duration + 1, function() undarken(d.Caster, token) end)
	end
	-- the reveal: the caster's alone
	if mine then
		fx("RevealStart", d.Until or (serverNow() + T.Eclipse.Duration), enemyBodies)
	end
end

H.EclipseEnd = function(d)
	local key = d.Caster
	local h = key ~= nil and eclipseLooks[key] or nil
	if h then
		eclipseLooks[key] = nil
		h:End(os.clock())
	end
	if key ~= nil then undarken(key) end
	-- (2026-10-19, audit P5C-13) by UserId too: a body already replaced by the time EclipseEnd lands still stops it
	if d.Character == player.Character or d.Caster == player.UserId then fx("RevealStop") end
end

-- (2026-10-19, audit P5C-13) a new body of ours never keeps an old Eclipse's through-walls outlines
player.CharacterAdded:Connect(function() fx("RevealStop") end)

return UmbraClient
