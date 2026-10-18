-- TEMPORARY Blue-Ringed Octopus checkpoint stage (Claude, 2026-10-19): remove when done
local Players = game:GetService("Players")
while not workspace:GetAttribute("StageReady") do task.wait(0.2) end
task.wait(1)
local S = Vector3.new(-90, 0, -45)
local st = workspace.WrapStage
local base = st.Caster
base.Archivable = true
local WR = { false, "Nightshade", "PoisonDartFrog", "BlueRingedOctopus" }
local X = { -21, -7, 7, 21 }
local C, V = {}, {}
for i = 1, 4 do
	local d = base:Clone() d.Name = "Cast" .. i d:SetAttribute("WrapStudio", WR[i] or nil) d.Parent = st
	d:PivotTo(CFrame.lookAt(S + Vector3.new(X[i], 3, 0), S + Vector3.new(X[i], 3, 40))) C[i] = d
	local v = base:Clone() v.Name = "Vic" .. i v:SetAttribute("WrapStudio", nil) v.Parent = st
	v:PivotTo(CFrame.lookAt(S + Vector3.new(X[i], 3, 8), S + Vector3.new(X[i], 3, 40))) V[i] = v
end
base:PivotTo(CFrame.new(S + Vector3.new(0, -50, 0)))
do   -- (streaming: the dummies and the showcase in Persistent models, so every client has them)
	local box = Instance.new("Model") box.Name = "_StageP" box.ModelStreamingMode = Enum.ModelStreamingMode.Persistent box.Parent = workspace
	for i = 1, 4 do C[i].Parent = box V[i].Parent = box end
	local sc = Instance.new("Model") sc.Name = "_ShowcaseSrv" sc.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local fl = Instance.new("Part") fl.Anchored = true fl.CanCollide = false fl.Size = Vector3.new(200, 0.2, 200) fl.CFrame = CFrame.new(-90, 0.05, -45)
	fl.Color = Color3.fromHex("#C9C2B8") fl.Material = Enum.Material.SmoothPlastic fl.Transparency = 1 fl.Parent = sc
	local sk = Instance.new("Part") sk.Anchored = true sk.CanCollide = false sk.CastShadow = false sk.Size = Vector3.new(400, 160, 1) sk.CFrame = CFrame.new(-90, 60, -100)
	sk.Color = Color3.fromHex("#B9C4CC") sk.Material = Enum.Material.SmoothPlastic sk.Transparency = 1 sk.Parent = sc
	sc.Parent = workspace
	workspace:GetAttributeChangedSignal("Showcase"):Connect(function() local on = workspace:GetAttribute("Showcase") fl.Transparency = on and 0 or 1 sk.Transparency = on and 0 or 1 end)
end
local Core = require(game:GetService("ServerScriptService"):FindFirstChild("CombatCore", true) or game:GetService("ReplicatedStorage"):FindFirstChild("CombatCore", true))
local B = Core.Broadcast
local now = function() return workspace:GetServerTimeNow() end
local id = 70000 + math.random(1, 900) * 40
local sync = game.ReplicatedStorage.Spellshot:FindFirstChild("SettingsSync")
local IR = game.ReplicatedStorage:FindFirstChild("IceAbilityRemote", true)
local function tag(n) workspace:SetAttribute("ShotTag", n) end
local function cam(e, l) workspace:SetAttribute("CamPinEye", S + e) workspace:SetAttribute("CamPinLook", S + l) end
local function WIDE() cam(Vector3.new(0, 5.5, 30), Vector3.new(0, 2.6, 4)) end   -- (about a player's eye)
local function each(f, set) for _, i in ipairs(set or { 1, 2, 3, 4 }) do f(i) end end
local function clouds(set, r, at)
	each(function(i) id += 1 local c = at or (S + Vector3.new(X[i], 0, 4))
		B("ToxinCloud", { Character = C[i], Id = id, Point = c, Center = c, Radius = r or 6, T0 = now(), FormTime = 0.25, Duration = 4, Kind = "Corrosive" }) end, set)
end
local function bubbles(set, vel, g)
	local ids = {}
	each(function(i) id += 1 ids[i] = id
		B("ToxinBubble", { Character = C[i], Id = id, Origin = S + Vector3.new(X[i] * 0.45, 1.8, 0), Vel = vel or Vector3.new(0, 5, 1.5), G = g or 14, T0 = now() }) end, set)
	return ids
end
local function pops(ids, set) each(function(i) B("ToxinBubblePop", { Id = ids[i], Position = S + Vector3.new(X[i] * 0.45, 1.32, 1.2) }) end, set) end
local function marks(set) each(function(i) B("ToxinPZMark", { Character = C[i], Target = V[i], T0 = now(), Telegraph = 3.5, Fuse = 0.35 }) end, set) end
local function bursts(set)
	each(function(i) id += 1 local c = V[i].HumanoidRootPart.Position - Vector3.new(0, 3, 0)
		B("ToxinPZBurst", { Character = C[i], Target = V[i], Position = c, Center = c, Radius = 6, Allies = {}, Duration = 3, CloudId = id, T0 = now() }) end, set)
end
local function ribbons(set) each(function(i) B("ToxinLifesteal", { From = V[i], To = C[i], Healed = 4 }) end, set) end

local function sheet(b)
	cam(Vector3.new(0, 3.4, 13), Vector3.new(0, 2.6, 0)) task.wait(0.3)
	tag(b + 1) local ids = bubbles() task.wait(0.8) tag(0) pops(ids) tag(b + 2) task.wait(1.2) tag(0) task.wait(1)
	WIDE() clouds() tag(b + 3) task.wait(2.6) tag(0) task.wait(3.5)
	tag(b + 4) marks() task.wait(1.4) tag(b + 5) task.wait(2.3) tag(0)
	bursts() tag(b + 6) task.wait(1.2) tag(0) task.wait(4.6)
	for k, i in ipairs({ 1, 4 }) do                               -- (the ribbon, close from the side: Default, then the Octopus)
		cam(Vector3.new(X[i] + 7, 4.2, 4), Vector3.new(X[i], 3, 4)) task.wait(0.3) tag(b + 6 + k) ribbons({ i }) task.wait(1) tag(0) task.wait(0.4)
	end
end

local function run()
	local pl = Players:GetPlayers()[1]
	workspace:SetAttribute("Showcase", true) task.wait(0.5)
	sheet(0)                                                     -- 1-8: the showcase stage
	workspace:SetAttribute("Showcase", false) task.wait(0.5)
	sheet(8)                                                     -- 9-16: the real map
	if sync then sync:FireClient(pl, { ColorblindSafe = true }) end
	WIDE() task.wait(0.3) clouds() marks() tag(17) task.wait(1.4) tag(0) task.wait(1.6) tag(18) task.wait(0.6) tag(0)
	if sync then sync:FireClient(pl, { ColorblindSafe = false }) end
	task.wait(4)
	-- 17: Cryo Default (Flash Freeze, left), the Octopus cloud (middle), Voltaic Default (Volt Orb burst, right)
	cam(Vector3.new(0, 12, 34), Vector3.new(0, 1, 4)) task.wait(0.3)
	if IR then IR:FireAllClients("VFX", "FlashFreeze", { Caster = C[1], OriginPart = C[1].HumanoidRootPart, Seed = 7 }) end
	clouds({ 4 }, 6, S + Vector3.new(4, 0, 4))
	B("VoltOrbBurst", { Character = C[3], At = S + Vector3.new(16, 0.5, 6), Normal = Vector3.new(0, 1, 0), Air = false, T0 = now() })
	B("RingOfFire", { Character = C[2], Center = S + Vector3.new(-6, 0, 14), Radius = 4, Hot = false, T0 = now(), Start = 0 })
	tag(19) task.wait(1.6) tag(0) task.wait(6)
	-- 18: the Octopus cloud overhead (full size)
	cam(Vector3.new(0, 30, 10), Vector3.new(0, 0, 3)) task.wait(0.3)
	clouds({ 4 }, 9, S + Vector3.new(0, 0, 3)) tag(20) task.wait(2.6) tag(0) task.wait(4)
	-- 19: the pulse (a slow Octopus bubble, close), 20: Reduce Flashing on
	cam(Vector3.new(9.45, 2.6, 6), Vector3.new(9.45, 2.4, 0)) task.wait(0.3)
	bubbles({ 4 }, Vector3.new(0, 0.12, 0), 0.01) tag(21) task.wait(9) tag(0)
	if sync then sync:FireClient(pl, { ReduceFlashing = true }) end
	task.wait(0.3) bubbles({ 4 }, Vector3.new(0, 0.12, 0), 0.01) task.wait(0.5) tag(22) task.wait(1.2) tag(0)   -- (a fresh bubble under Reduce Flashing)
	if sync then sync:FireClient(pl, { ReduceFlashing = false }) end
	workspace:SetAttribute("BroDone", true)
end
workspace:SetAttribute("BroGo", false)
workspace:GetAttributeChangedSignal("BroGo"):Connect(function()
	if workspace:GetAttribute("BroGo") then workspace:SetAttribute("BroGo", false) task.spawn(run) end
end)
workspace:SetAttribute("BroReady", true)
