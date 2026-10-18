--[[
	RadiantClient  (ModuleScript)  ->  ReplicatedStorage/IceMagic/RadiantClient

	The client half of RADIANT (RadiantHandler is the server; Phase 3 of the rework, 2026-09-29). Required by
	SpellshotInput (LocalCast, Bind, FireM1, ReleaseM1) and AbilityFX (Handlers), the way UmbraClient is.

	  LIGHT LANCE   FireM1 claims the M1 click for Light Lance: it sends the M1 CastRequest (SpellshotService's rate gate
	                and StartCost; RadiantHandler starts the channel) and then, every 1/AimRate while the button is held,
	                RadiantLanceAim { Dir, Part?, Position? } -- the aim, and the body this client's own beam touches
	                (a thin spherecast that passes through everyone you may not hurt). Letting go sends RadiantLanceStop.
	                The server can stop it too (empty mana, planted, Halo's windup, death): RadiantLanceOff ends it here.
	                The caster's own beam is drawn from this client's aim every frame; everyone else's from the server's
	                RadiantLance broadcasts.
	  THE REST      Blessing, Position Trade, Benediction and Halo use SpellshotInput's generic cast path (their rows are
	                Targeted where they aim). LocalCast plays RadiantAnim's arms and body on the keypress.

	VISUALS (Phase 5, 2026-09-29: the owner-confirmed Phase 4 round-3 designs; the Phase 3 placeholder RadiantFX is
	retired to ServerStorage.RadiantKitSuperseded.phase5_2026_09_29):
	  RadiantFX_Staff   Light Lance's beam, Halo (spiral, halo, wings), Benediction (sigil, column, pulses)
	  RadiantFX_Hand    Blessing's Seraph Seal, Overflow Light, Position Trade
	  RadiantAnim       every Radiant body's clips, the first-person arms, the staff prop and its glow (own listener)
	  RadiantFloat      Halo's float: gravity x FloatGravity and the FallCap while HaloUntil is ahead (own character)
	All are started from here (client only) and every call is guarded: a failing or missing module draws nothing and
	never stops a mechanic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local RadiantClient = {}
RadiantClient.LocalCast = {}
RadiantClient.Handlers = {}

----------------------------------------------------------------------------------------------------
-- modules, found lazily (never a wait on the input path)
----------------------------------------------------------------------------------------------------
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local T = require(iceFolder:WaitForChild("RadiantTuning"))
local mods = {}
local function need(name)
	if mods[name] ~= nil then return mods[name] or nil end
	local m = iceFolder:FindFirstChild(name) or spellFolder:FindFirstChild(name)
	local ok, mod = pcall(function() return m and require(m) end)
	mods[name] = (ok and mod) or false
	if not ok then warn("[RadiantClient] " .. name .. ": " .. tostring(mod)) end
	return mods[name] or nil
end

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[RadiantClient] " .. tostring(msg))
end

-- an inert handle, for when RadiantFX is not there: every method a no-op
local NULL = setmetatable({}, { __index = function() return function() return nil end end })

--- <module>.<fn>(...), guarded: a missing module or function, or an error in it, draws nothing
local function kit(modName, fn, ...)
	local F = need(modName)
	local f = F and F[fn]
	if type(f) ~= "function" then return NULL end
	local ok, res = pcall(f, ...)
	if not ok then
		warnOnce(modName .. ":" .. fn, modName .. "." .. fn .. " failed: " .. tostring(res))
		return NULL
	end
	return res or NULL
end

-- SKINS: the palette an ability draws with (the broadcast's Skin Id; nil = Default), handed to the effects it starts
local function skinned(ability, skinId, fn, ...)
	local S, RD = need("SkinCatalog"), need("RadiantDraw")
	local pal = S and ability and S.Resolve("Radiant", ability, skinId) or nil
	if pal and RD and RD.WithPalette then return RD.WithPalette(pal, fn, ...) end
	return fn(...)
end

--- <module>.Handlers[kind](d), guarded the same way
local function handle(modName, kind, d)
	local F = need(modName)
	local f = F and type(F.Handlers) == "table" and F.Handlers[kind]
	if type(f) ~= "function" then return end
	local S = need("SkinCatalog")
	local ok, err = pcall(skinned, S and S.AbilityOfKind(kind), type(d) == "table" and d.Skin or nil, f, d)
	if not ok then warnOnce(modName .. ":" .. kind, modName .. " " .. kind .. " failed: " .. tostring(err)) end
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

--- Your own beam passes through yourself, the camera, the FX and everyone you may not hurt.
local function ownExclude(character)
	local list = { character, workspace.CurrentCamera, fxFolder() }
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

local bound = {}
function RadiantClient.Bind(fns)
	bound = type(fns) == "table" and fns or {}
end

-- the arms (and the body where the cast is instant) on the keypress: RadiantAnim's. Filled now, synchronously
-- (SpellshotInput copies LocalCast once, at require); RadiantAnim itself is found on the first press.
for _, id in ipairs({ "Blessing", "PositionTrade", "Benediction", "Halo" }) do
	RadiantClient.LocalCast[id] = function(character, role)
		local A = need("RadiantAnim")
		local f = A and type(A.LocalCast) == "table" and A.LocalCast[id]
		if type(f) ~= "function" then return end
		local ok, err = pcall(f, character, role)
		if not ok then warnOnce("cast:" .. id, "RadiantAnim.LocalCast." .. id .. " failed: " .. tostring(err)) end
	end
end

----------------------------------------------------------------------------------------------------
-- LIGHT LANCE (own)
----------------------------------------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local lance = nil          -- { Id, Character, Beam, SentAt, Start, Heard, Conn }
local lanceSeq = 0

-- the button, as THIS module sees it: SpellshotInput can fire a click it queued (inside FireInterval) after the button
-- is already up, which would start a beam nobody holds -- a beam needs the button down, now
local pressed = false
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then pressed = true end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then pressed = false end
end)
UserInputService.WindowFocusReleased:Connect(function()
	pressed = false                                    -- a release lost with the window's focus
end)

-- The engine's own state first: SpellshotInput's InputBegan (which calls FireM1) can run BEFORE this module's, so on the
-- very click `pressed` may not be set yet. `pressed` is only the fallback where there is no mouse.
-- the on-screen FIRE button (TouchControls through TouchBus, 2026-10-04) is the same button on a touch screen
local TouchBus = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("TouchBus"))

local function buttonDown()
	if TouchBus.Down.M1 then return true end
	if UserInputService.MouseEnabled then
		local ok, down = pcall(function()
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end)
		if ok then return down == true end
	end
	return pressed
end

--- What this client's beam touches: the first body (or wall) along the aim within Range.
local function lanceRay(character)
	local acf = aimCF()
	local eye, dir = acf.Position, acf.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ownExclude(character)
	local hit = workspace:Spherecast(eye, 0.6, dir * T.LightLance.Range, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	return eye, dir, hit, (hum and hum.Health > 0) and model or nil
end

local function endLance(tellServer)
	local L = lance
	if not L then return end
	lance = nil
	if L.Conn then L.Conn:Disconnect() end
	L.Beam:Destroy()                                  -- the release tail (RadiantFX_Staff)
	kit("RadiantAnim", "LanceEnd", L.Character)
	if tellServer then
		local r = iceRemote()
		if r then r:FireServer("RadiantLanceStop", { Id = L.Id }) end
	end
end

function RadiantClient.FireM1(character, ability)
	if type(ability) ~= "table" or ability.Id ~= "LightLance" then return false end
	if lance then return true end                                        -- already channelling: an autofire repeat
	if not (character and character.Parent) or player.Character ~= character then return true end
	if not buttonDown() then return true end                             -- a queued click fired after letting go
	-- the staff is in the ground (Benediction) or in Halo's windup: the server would refuse the beam
	if character:GetAttribute("RadiantPlant") or character:GetAttribute("RadiantHaloHold") then return true end
	if bound.CanCast and not bound.CanCast("M1", character) then
		if bound.Flash then bound.Flash("M1", true) end
		return true
	end
	-- the click pays (SpellshotService: the rate and StartCost) and starts the channel on the server, under this
	-- beam's own number (every message about it carries the number, so a late one about the last beam is ignored)
	lanceSeq += 1
	local cast = castRemote()
	if cast then cast:FireServer("M1", { LanceId = lanceSeq }) end
	local L = { Id = lanceSeq, Character = character, SentAt = 0, Start = os.clock(), Heard = false }
	local S = need("SkinCatalog")
	L.Beam = skinned("LightLance", S and S.Chosen(Players.LocalPlayer, "LightLance"), kit, "RadiantFX_Staff", "LanceBeam",
		character, true)
	lance = L
	kit("RadiantAnim", "LanceBegin", character)
	L.Conn = RunService.Heartbeat:Connect(function()
		if lance ~= L then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not (character.Parent and player.Character == character and hum and hum.Health > 0) then
			return endLance(true)
		end
		if not buttonDown() then return endLance(true) end
		-- the server never started it (its M1 gate, a cast lock): no word of this beam within a round trip -> drop it
		if not L.Heard and os.clock() - L.Start > 0.6 + 2 * player:GetNetworkPing() then return endLance(true) end
		local eye, dir, hit, body = lanceRay(character)
		local to = hit and hit.Position or (eye + dir * T.LightLance.Range)
		L.Beam:Aim(eye, to, body ~= nil)
		local now = os.clock()
		if now - L.SentAt >= 1 / T.LightLance.AimRate then
			L.SentAt = now
			local r = iceRemote()
			if r then
				-- Origin: where this ray starts (the eye in first person, the camera focus ~3 studs off the head in the
				-- third-person view), so the server checks the claim on the same line (review fix 2026-09-29)
				if body then
					r:FireServer("RadiantLanceAim", { Dir = dir, Origin = eye, Part = hit.Instance, Position = hit.Position })
				else
					r:FireServer("RadiantLanceAim", { Dir = dir, Origin = eye })
				end
			end
		end
	end)
	return true
end

function RadiantClient.ReleaseM1()
	endLance(true)
end

----------------------------------------------------------------------------------------------------
-- Handlers: the server's broadcasts, drawn for everyone (RadiantFX_Staff / RadiantFX_Hand; RadiantAnim poses the
-- bodies from its own listener)
----------------------------------------------------------------------------------------------------
local H = RadiantClient.Handlers
-- keyed by character, weakly: a body that goes without its End / Off never keeps its handle alive
local WEAK = { __mode = "k" }
local beams = setmetatable({}, WEAK)          -- [character] = { Beam, Dir, Point, Ramp, Conn } for OTHER casters' beams

--- a message about the caster's OWN beam: true when it is about the beam running now (or carries no number)
local function aboutOwnLance(d)
	return lance ~= nil and (d.Id == nil or d.Id == lance.Id)
end

local function isOwn(character)
	return character ~= nil and character == player.Character
end

local function headOf(model)
	return model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

H.RadiantLanceOn = function(d)
	local c = d.Character
	if not c then return end
	if isOwn(c) then
		if aboutOwnLance(d) then lance.Heard = true end
		return
	end
	local old = beams[c]
	if old then
		if old.Conn then old.Conn:Disconnect() end
		old.Beam:Destroy(true)                        -- replaced: gone at once, no tail
	end
	local b = { Beam = skinned("LightLance", d.Skin, kit, "RadiantFX_Staff", "LanceBeam", c, false, { T0 = d.T0 }),
		Dir = nil, Point = nil, Ramp = 0 }
	beams[c] = b
	b.Conn = RunService.RenderStepped:Connect(function()
		if beams[c] ~= b then return end
		if not c.Parent then
			b.Conn:Disconnect()
			b.Beam:Destroy(true)
			beams[c] = nil
			return
		end
		local head = headOf(c)
		if not (head and b.Dir) then return end
		local from = head.Position
		local to = b.Point or (from + b.Dir * T.LightLance.Range)
		b.Beam:Aim(from, to, b.Point ~= nil, b.Ramp)
	end)
end

H.RadiantLance = function(d)
	local c = d.Character
	if not c then return end
	if isOwn(c) then
		if aboutOwnLance(d) then
			lance.Heard = true
			lance.Beam:SetRamp(d.Ramp or 0)
		end
		return
	end
	local b = beams[c]
	if not b then
		H.RadiantLanceOn(d)
		b = beams[c]
	end
	if b and typeof(d.Dir) == "Vector3" then
		b.Dir = d.Dir
		b.Point = typeof(d.Point) == "Vector3" and d.Point or nil
		b.Ramp = type(d.Ramp) == "number" and d.Ramp or 0
	end
end

H.RadiantLanceOff = function(d)
	local c = d.Character
	if isOwn(c) then
		-- the server ended it (empty, planted, Halo, death, refused): nothing to send -- unless it is about an older beam
		if aboutOwnLance(d) then endLance(false) end
		return
	end
	local b = c and beams[c]
	if b then
		beams[c] = nil
		if b.Conn then b.Conn:Disconnect() end
		b.Beam:Destroy()
	end
end

-- Blessing, Overflow Light, Position Trade: RadiantFX_Hand
for _, kind in ipairs({ "RadiantBlessing", "RadiantOverflow", "RadiantTradeOut", "RadiantTradeIn" }) do
	H[kind] = function(d) handle("RadiantFX_Hand", kind, d) end
end

-- Halo and Benediction: RadiantFX_Staff (it keeps its own per-character state)
for _, kind in ipairs({ "RadiantHaloCharge", "RadiantHaloCancel", "RadiantHaloStart", "RadiantHaloEnd",
	"RadiantBenedictionStart", "RadiantBenedictionPulse", "RadiantBenedictionEnd" }) do
	H[kind] = function(d) handle("RadiantFX_Staff", kind, d) end
end

-- Benediction's allies in range at the plant (the server's list): RadiantFX_Staff's Allies anchor reads it
local benAllies = setmetatable({}, WEAK)
H.RadiantBenedictionStart = function(d)
	if d.Character then benAllies[d.Character] = type(d.Allies) == "table" and d.Allies or nil end
	handle("RadiantFX_Staff", "RadiantBenedictionStart", d)
end

-- Halo's heal share (the allies a hit under the Halo just healed): the flicker from the halo to them
H.RadiantHaloShare = function(d)
	if d.Character and type(d.Targets) == "table" then kit("RadiantFX_Staff", "HaloShare", d.Character, d.Targets) end
end

----------------------------------------------------------------------------------------------------
-- Phase 5: the kit starts with this module, on the client, off the require path
----------------------------------------------------------------------------------------------------
local function ownFirstPersonPalm(c)
	if c ~= player.Character then return nil end
	local V = need("Viewmodel")
	local fn = V and V.GetFistCFrame
	if type(fn) ~= "function" then return nil end
	local ok, cf = pcall(fn, "L")
	if ok and typeof(cf) == "CFrame" then return cf.Position, cf.LookVector end
	return nil
end

if RunService:IsClient() and player then
	task.defer(function()
		local A = need("RadiantAnim")
		if A and type(A.Start) == "function" then
			local ok, err = pcall(A.Start)
			if not ok then warnOnce("anim", "RadiantAnim.Start failed: " .. tostring(err)) end
		end
		local S = need("RadiantFX_Staff")
		if S and type(S.SetAnchors) == "function" then
			-- the staff glow has ONE writer, RadiantAnim (the owner's per-piece rules), so no Lines anchor here
			pcall(S.SetAnchors, {
				Tip = function(c) return A and A.StaffPoint(c, "tip") or nil end,
				Palm = ownFirstPersonPalm,              -- nil: the body's LeftHand
				Allies = function(c) return benAllies[c] end,
			})
			-- the effect pool is filled only once some player's Element is Radiant (this one's or anyone's): a match with
			-- no Radiant never makes it (review fix 2026-09-29)
			if type(S.Prewarm) == "function" then
				local warmed = false
				local conns = {}
				local function check(p)
					if warmed or p:GetAttribute("Element") ~= "Radiant" then return end
					warmed = true
					for _, cn in ipairs(conns) do cn:Disconnect() end
					table.clear(conns)
					pcall(S.Prewarm)
				end
				local function hook(p)
					if warmed then return end
					conns[#conns + 1] = p:GetAttributeChangedSignal("Element"):Connect(function() check(p) end)
					check(p)
				end
				conns[#conns + 1] = Players.PlayerAdded:Connect(hook)
				for _, p in ipairs(Players:GetPlayers()) do hook(p) end
			end
		end
		-- THE DEVIL SKIN (2026-10-13): the moment the local player wears it (the Loadout's SKINS page), its forms are built
		-- ahead -- the staff's and the hand's -- so the first Devil cast of each piece shows them from frame one
		do
			local lp = Players.LocalPlayer
			local devilWarmed = false
			local function warmDevil()
				if devilWarmed or lp:GetAttribute("ElementSkin_Radiant") ~= "Devil" then return end
				devilWarmed = true
				task.defer(function()
					if S and type(S.PrewarmDevil) == "function" then pcall(S.PrewarmDevil) end
					local H = need("RadiantFX_Hand")
					if H and type(H.PrewarmDevil) == "function" then pcall(H.PrewarmDevil) end
				end)
			end
			lp:GetAttributeChangedSignal("ElementSkin_Radiant"):Connect(warmDevil)
			warmDevil()
		end
		local Hd = need("RadiantFX_Hand")
		if Hd and A and type(Hd.SetStaffHook) == "function" then
			-- a hand piece's staff moment: the staff hides with the body (Trade) and lends its tip to the aura
			Hd.SetStaffHook(function(c, key, level, visible)
				A.SetStaffHidden(c, level ~= nil and visible == false, key)
				if level == nil or visible == false then return nil end
				return A.StaffPoint(c, "tip")
			end)
		end
		local F = need("RadiantFloat")
		if F and type(F.Start) == "function" then
			local ok, err = pcall(F.Start)
			if not ok then warnOnce("float", "RadiantFloat.Start failed: " .. tostring(err)) end
		end
	end)
end

return RadiantClient
