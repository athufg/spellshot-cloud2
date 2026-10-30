--[[
	VoltaicTestHarness  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/VoltaicTestHarness

	TEMPORARY, STUDIO ONLY (it returns at once anywhere else). Delete, or leave IsStudio-guarded, after the Voltaic pass.
	Studio's script sandbox cannot send a mouse press (VirtualInputManager needs RobloxScript capability; synthetic mouse
	input never reaches UserInputService) and cannot fire a remote, so an automated Play test of the Chain Bolt click has
	to run from inside the game. This drives the kit through VoltaicClient's OWN entry points -- the same functions
	SpellshotInput calls -- and writes what happened onto the player for the test to read back
	(modelled on tools/terra_test_harness.client.lua).

	TRIGGER: set the player attribute VoltTest (from the Client datamodel; client writes do not replicate, which is the
	point). It runs once per write and clears itself. The answer goes to VoltTestResult and the Output ("[VoltaicTestHarness]").
	  "m1"              VoltaicClient.FireM1 once (the fireShard branch, minus SpellshotInput's own rate gate)
	  "m1xN"            N clicks, 0.4 s apart (over the 0.32 s FireInterval, so the server's rate gate never drops one)
	  "primary"         VoltaicClient.TryCast("Primary", ...) -- Overcharge's dash; false until SpellshotInput has Bound
	  "aim:<Dummy>"     turn the camera once onto that dummy's root (HubClient's own method: first person keeps the camera's
	                    heading, so a server PivotTo alone is turned back), and pin it for "look:" (player attr VoltDummy)
	  "look:<what>"     play a piece's LOOK as somebody else's cast on the pinned dummy (or the nearest), with fake data,
	                    through VoltaicClient.Handlers -- nothing reaches the server, nobody is struck:
	                      chainbolt (ChainBoltFX.Review from your hand onto the dummy and its nearest neighbour),
	                      chainboltprimed (the same, 3 chain legs), chainboltdummy (the dummy's own shot, the handler path),
	                      discharge (StatusDischarge onto its nearest neighbour), overcharge, railspike, voltorb, cascade
	  "dev:<Action>"    a dev-panel action by name through DevRequest (e.g. dev:ClearCooldowns, dev:ToggleFreeMana)
	  "loadout"         LoadoutRequest("Element", "Voltaic") -- the real pick path -- and what the server made of it
	  "clearlog"        empties VoltClientLog

	LOGS (player attributes, read back with execute_luau on the Client):
	  VoltClientLog  every Voltaic broadcast this client receives, and each harness action: "<os.clock()> <Kind> <summary>"
	                 (" | "-separated, the last LOG_MAX). T0 / ReleaseAt / Until print as seconds relative to the moment
	                 received (negative: in the past). In Studio the server and client share one process, so os.clock() here
	                 lines up with the setup's VoltLog.
	  VoltFxCount    workspace.IceMagicFX's descendant count every 0.1 s, "<os.clock()>:<count>", the last 15 s
	  VoltFxNow      the latest count; VoltFxPeak the highest since the last VoltTest trigger
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic", 30)
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot", 30)
if not (iceFolder and spellFolder) then
	warn("[VoltaicTestHarness] IceMagic / Spellshot never appeared: harness off")
	return
end

local KINDS = {
	ChainBolt = true, StatusDischarge = true, Overcharge = true, OverchargePrimed = true, ChainReaction = true,
	RailspikeChargeStart = true, RailspikeChargeStop = true, RailspikeShot = true,
	VoltOrbThrow = true, VoltOrbBurst = true, VoltOrbFizzle = true,
	CascadeGather = true, CascadeStrike = true, CascadeEnd = true,
}
local LOG_MAX = 250
local FX_SAMPLES = 150              -- 15 s at 0.1 s

----------------------------------------------------------------------------------------------------
-- the log
----------------------------------------------------------------------------------------------------
local log = {}
local function note(s)
	table.insert(log, string.format("%.3f %s", os.clock(), s))
	while #log > LOG_MAX do table.remove(log, 1) end
	player:SetAttribute("VoltClientLog", table.concat(log, " | "))
end

local function say(text)
	player:SetAttribute("VoltTestResult", text)
	print("[VoltaicTestHarness] " .. text)
	note("SAY " .. text)
end

local function fmt(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "Vector3" then
		return string.format("(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
	elseif t == "Instance" then
		return v.Name
	elseif t == "number" then
		return string.format("%.3f", v)
	elseif t == "boolean" or t == "string" then
		return tostring(v)
	elseif t == "table" then
		if depth > 2 then return "{..}" end
		local parts = {}
		if #v > 0 then
			for i, x in ipairs(v) do
				if i > 8 then
					parts[#parts + 1] = "+" .. (#v - 8)
					break
				end
				parts[#parts + 1] = fmt(x, depth + 1)
			end
		else
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. fmt(v[k], depth + 1) end
		end
		return "[" .. table.concat(parts, " ") .. "]"
	end
	return t
end

local TIME_KEYS = { T0 = true, ReleaseAt = true, Until = true }
local function summary(d)
	local keys = {}
	for k in pairs(d) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	local now = workspace:GetServerTimeNow()
	local parts = {}
	for _, k in ipairs(keys) do
		local v = d[k]
		if TIME_KEYS[k] and type(v) == "number" then
			parts[#parts + 1] = string.format("%s=%+.3f", k, v - now)
		else
			parts[#parts + 1] = k .. "=" .. fmt(v)
		end
	end
	return table.concat(parts, " ")
end

-- every Voltaic broadcast, as it arrives
task.spawn(function()
	local remote = iceFolder:WaitForChild("IceAbilityRemote", 30)
	if not remote then
		warn("[VoltaicTestHarness] IceAbilityRemote never appeared: no broadcast log")
		return
	end
	remote.OnClientEvent:Connect(function(action, kind, data)
		if action ~= "VFX" or not KINDS[kind] or type(data) ~= "table" then return end
		local ok, text = pcall(summary, data)
		note(kind .. " " .. (ok and text or ("<summary failed: " .. tostring(text) .. ">")))
	end)
end)

-- the FX folder's size, every 0.1 s
local fxSamples = {}
local fxPeak = 0
task.spawn(function()
	while true do
		local ok, err = pcall(function()
			local folder = workspace:FindFirstChild("IceMagicFX")
			local n = folder and #folder:GetDescendants() or 0
			table.insert(fxSamples, string.format("%.1f:%d", os.clock(), n))
			while #fxSamples > FX_SAMPLES do table.remove(fxSamples, 1) end
			if n > fxPeak then fxPeak = n end
			player:SetAttribute("VoltFxNow", n)
			player:SetAttribute("VoltFxPeak", fxPeak)
			player:SetAttribute("VoltFxCount", table.concat(fxSamples, " "))
		end)
		if not ok then warn("[VoltaicTestHarness] FX count failed: " .. tostring(err)) end
		task.wait(0.1)
	end
end)

----------------------------------------------------------------------------------------------------
-- the modules (found with timeouts, never at the top)
----------------------------------------------------------------------------------------------------
local cache = {}
local function mod(folder, name)
	if cache[name] then return cache[name] end
	local inst = folder:FindFirstChild(name) or folder:WaitForChild(name, 10)
	if not inst then return nil end
	local ok, m = pcall(require, inst)
	if ok and type(m) == "table" then
		cache[name] = m
		return m
	end
	warn("[VoltaicTestHarness] " .. name .. " failed to load: " .. tostring(m))
	return nil
end
local function client() return mod(iceFolder, "VoltaicClient") end
local function vfx() return mod(iceFolder, "VFXLibrary") end

local function timeScale()
	local V = vfx()
	local ok, s = pcall(function() return V and V.ShotTimeScale() end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

local function now() return workspace:GetServerTimeNow() end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

----------------------------------------------------------------------------------------------------
-- dummies
----------------------------------------------------------------------------------------------------
local function dummies()
	local list = {}
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("TrainingDummy") and m:FindFirstChild("HumanoidRootPart")
			and m:FindFirstChildOfClass("Humanoid") then
			list[#list + 1] = m
		end
	end
	return list
end

local function dummyNamed(name)
	for _, m in ipairs(dummies()) do
		if m.Name == name then return m end
	end
	local any = workspace:FindFirstChild(name, true)
	if any and any:IsA("Model") and any:FindFirstChild("HumanoidRootPart") then return any end
	return nil
end

--- The pinned dummy (VoltDummy, set by "aim:"), else the nearest living one.
local function source()
	local pinned = player:GetAttribute("VoltDummy")
	local m = type(pinned) == "string" and dummyNamed(pinned) or nil
	if m then return m end
	local from = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not from then return nil end
	local best, bestD = nil, math.huge
	for _, d in ipairs(dummies()) do
		local h = d:FindFirstChildOfClass("Humanoid")
		local dist = (d.HumanoidRootPart.Position - from.Position).Magnitude
		if h.Health > 0 and dist < bestD then best, bestD = d, dist end
	end
	return best
end

--- The other dummies, nearest to `from` first.
local function others(src, from)
	local list = {}
	for _, d in ipairs(dummies()) do
		if d ~= src then list[#list + 1] = d end
	end
	table.sort(list, function(a, b)
		return (a.HumanoidRootPart.Position - from).Magnitude < (b.HumanoidRootPart.Position - from).Magnitude
	end)
	return list
end

local function groundBelow(pos, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { workspace.CurrentCamera }
	for _, x in ipairs(exclude or {}) do list[#list + 1] = x end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then list[#list + 1] = p.Character end
	end
	for _, d in ipairs(dummies()) do list[#list + 1] = d end
	local fx = workspace:FindFirstChild("IceMagicFX")
	if fx then list[#list + 1] = fx end
	params.FilterDescendantsInstances = list
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0)), hit and hit.Normal or Vector3.yAxis
end

--- The sideways direction across this player's view at `from` (so a look test is seen side-on, not head-on).
local function across(from)
	local cam = workspace.CurrentCamera.CFrame.Position
	local to = flat(cam - from)
	if to.Magnitude < 0.1 then return Vector3.new(1, 0, 0) end
	return to.Unit:Cross(Vector3.yAxis).Unit
end

local function handler(kind, data)
	local VC = client()
	local fn = VC and VC.Handlers and VC.Handlers[kind]
	if type(fn) ~= "function" then
		say("no VoltaicClient.Handlers." .. kind)
		return false
	end
	note("LOOK " .. kind .. " " .. summary(data))
	local ok, err = pcall(fn, data)
	if not ok then say(kind .. " handler errored: " .. tostring(err)) end
	return ok
end

----------------------------------------------------------------------------------------------------
-- the modes
----------------------------------------------------------------------------------------------------
local function fireM1(n)
	local VC, V = client(), vfx()
	local character = player.Character
	if not (VC and V and character) then say("no VoltaicClient / VFXLibrary / character") return end
	local ability = V.AbilityFor(player, "M1")
	if not (ability and ability.Id == "ChainBolt") then
		say("M1 is " .. tostring(ability and ability.Id) .. ", not ChainBolt (Element " .. tostring(player:GetAttribute("Element")) .. ")")
		return
	end
	for i = 1, n do
		if player.Character ~= character then break end
		local ok, took = pcall(VC.FireM1, character, ability)
		note(string.format("M1 %d/%d FireM1 -> %s", i, n, ok and tostring(took) or ("ERROR " .. tostring(took))))
		if i < n then task.wait(0.4) end
	end
	say(string.format("m1 x%d sent (Implemented=%s)", n, tostring(ability.Implemented)))
end

local function primary()
	local VC, V = client(), vfx()
	local character = player.Character
	if not (VC and V and character) then say("no VoltaicClient / VFXLibrary / character") return end
	local ability = V.AbilityFor(player, "Primary")
	local ok, took = pcall(VC.TryCast, "Primary", character, ability)
	if not ok then
		say("TryCast errored: " .. tostring(took))
	elseif took then
		say("primary: TryCast took it (" .. tostring(ability and ability.Id) .. ")")
	else
		say("primary: TryCast returned false -- not Bound yet (SpellshotInput's Voltaic hook) or Primary is "
			.. tostring(ability and ability.Id))
	end
end

local function aim(name)
	local d = dummyNamed(name)
	if not d then say("aim: no dummy named " .. name .. " (streamed in?)") return end
	player:SetAttribute("VoltDummy", d.Name)
	RunService.RenderStepped:Wait()                       -- after a server PivotTo the camera catches up first
	local cam = workspace.CurrentCamera
	local target = d.HumanoidRootPart.Position
	local pos = cam.CFrame.Position
	cam.CFrame = CFrame.lookAt(pos, target)
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	local want = (target - cam.CFrame.Position).Unit
	local err = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(want), -1, 1)))
	say(string.format("aim %s: %.1f studs, %.2f deg off after two frames", d.Name, (target - pos).Magnitude, err))
end

local function lookChainBolt(src, legs)
	local CB = mod(iceFolder, "ChainBoltFX")
	if not (CB and type(CB.Review) == "function") then say("no ChainBoltFX.Review") return end
	local VM = mod(iceFolder, "Viewmodel")
	local origin = workspace.CurrentCamera.CFrame.Position
	if VM then
		local ok, m = pcall(VM.GetMuzzleCFrame, "R")
		if ok and typeof(m) == "CFrame" then origin = m.Position end
	end
	local points = { src.HumanoidRootPart.Position }
	local seen = { [src] = true }
	local at = src.HumanoidRootPart.Position
	for _ = 1, legs do
		local nextOne = nil
		for _, d in ipairs(others(src, at)) do
			if not seen[d] and (d.HumanoidRootPart.Position - at).Magnitude <= 8 then
				nextOne = d
				break
			end
		end
		if not nextOne then break end
		seen[nextOne] = true
		at = nextOne.HumanoidRootPart.Position
		points[#points + 1] = at
	end
	note("LOOK ChainBoltFX.Review " .. fmt(origin) .. " -> " .. fmt(points))
	local ok, err = pcall(CB.Review, origin, points)
	say(ok and string.format("chain bolt look onto %s, %d point(s)", src.Name, #points)
		or ("ChainBoltFX.Review errored: " .. tostring(err)))
end

local function lookChainBoltDummy(src)
	local head = src:FindFirstChild("Head") or src.HumanoidRootPart
	local list = others(src, src.HumanoidRootPart.Position)
	local first = list[1]
	if not first then say("chainboltdummy: no second dummy") return end
	local origin = head.Position
	local dir = (first.HumanoidRootPart.Position - origin).Unit
	local hits, points = { first }, { first.HumanoidRootPart.Position }
	local second = list[2]
	if second and (second.HumanoidRootPart.Position - first.HumanoidRootPart.Position).Magnitude <= 8 then
		hits[2], points[2] = second, second.HumanoidRootPart.Position
	end
	handler("ChainBolt", {
		Character = src, Origin = origin, Dir = dir, Side = "R", End = points[1], Hits = hits, Points = points,
		Primed = false, T0 = now(),
	})
	say(string.format("chain bolt from %s onto %s (%d hit)", src.Name, first.Name, #hits))
end

local function lookDischarge(src)
	local to = others(src, src.HumanoidRootPart.Position)[1]
	handler("StatusDischarge", { From = src, To = to })
	say("discharge from " .. src.Name .. " to " .. tostring(to and to.Name))
end

local function lookOvercharge(src)
	local from = src.HumanoidRootPart.Position
	local dir = across(from)
	local t0 = now()
	handler("Overcharge", { Character = src, From = from, To = from + dir * 11, T0 = t0 })
	local scale = timeScale()
	task.delay(0.23 / scale, function()
		handler("OverchargePrimed", { Character = src, On = true, Until = t0 + 6 / scale })
	end)
	task.delay(2.5 / scale, function()
		handler("OverchargePrimed", { Character = src, On = false })
	end)
	say("overcharge look from " .. src.Name .. " (primed until +2.5 s)")
end

--- The eye's pierce ray the way VoltaicClient.fireRail casts it, from `origin` along `dir`, the shooter excluded.
local function pierce(src, origin, dir, range)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { src, workspace.CurrentCamera }
	local fx = workspace:FindFirstChild("IceMagicFX")
	if fx then exclude[#exclude + 1] = fx end
	local hits, points = {}, {}
	local endPos = origin + dir * range
	for _ = 1, 16 do
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(origin, dir * range, params)
		if not hit then break end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			endPos = hit.Position
			break
		end
		if #hits < 6 then
			hits[#hits + 1] = model
			points[#points + 1] = hit.Position
		end
		exclude[#exclude + 1] = model
	end
	return hits, points, math.max(0, (endPos - origin):Dot(dir))
end

local function lookRailspike(src)
	local t0 = now()
	handler("RailspikeChargeStart", { Character = src, T0 = t0 })
	local scale = timeScale()
	task.delay(0.55 / scale, function()
		if not src.Parent then return end
		local head = src:FindFirstChild("Head") or src.HumanoidRootPart
		local origin = head.Position
		local target = others(src, src.HumanoidRootPart.Position)[1]
		local dir = target and (target.HumanoidRootPart.Position - origin).Unit
			or flat(src.HumanoidRootPart.CFrame.LookVector).Unit
		local hits, points, dist = pierce(src, origin, dir, 60)
		handler("RailspikeShot", {
			Character = src, Origin = origin, Dir = dir, Dist = dist, Hits = hits, Points = points, T0 = now(),
		})
	end)
	say("railspike look from " .. src.Name .. " (the shot at +0.55 s)")
end

local function lookVoltOrb(src)
	local head = src:FindFirstChild("Head") or src.HumanoidRootPart
	local dir = across(src.HumanoidRootPart.Position)
	-- (2026-10-19, audit P5D-19) the throw's numbers are VoltaicTuning.VoltOrb's, as the server's: ReleaseAt has been 0.12
	-- since the 2026-10-13 hold-to-aim (this faked 0.31); the build-time numbers are the fallbacks
	local VO = (mod(iceFolder, "VoltaicTuning") or {}).VoltOrb or {}
	local elev = math.rad(VO.Lift or 52)
	local vel = (dir * math.cos(elev) + Vector3.yAxis * math.sin(elev)) * (VO.Speed or 48)
	local from = head.Position + CFrame.lookAt(Vector3.zero, dir):VectorToWorldSpace(Vector3.new(0.9, -0.7, -1.4))
	local scale = timeScale()
	local t0 = now()
	local releaseAt = t0 + (VO.ReleaseAt or 0.12) / scale
	local gravity, fuse = VO.Gravity or 72, VO.Fuse or 1.25
	handler("VoltOrbThrow", {
		Character = src, From = from, Vel = vel, T0 = t0, ReleaseAt = releaseAt, Gravity = gravity, Fuse = fuse,
		Seed = math.random(1, 2 ^ 30),
	})
	-- where it lands: the flight stepped the way the server steps it (shot time), against the world
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { src, workspace.CurrentCamera }
	local fx = workspace:FindFirstChild("IceMagicFX")
	if fx then exclude[#exclude + 1] = fx end
	params.FilterDescendantsInstances = exclude
	local last, at, normal, air, tHit = from, nil, Vector3.yAxis, true, fuse
	local step = 1 / 60
	local t = 0
	while t < fuse do
		t = math.min(fuse, t + step)
		local pos = from + vel * t + Vector3.new(0, -0.5 * gravity * t * t, 0)
		local delta = pos - last
		if delta.Magnitude > 1e-3 then
			local hit = workspace:Spherecast(last, 1.0, delta, params)
			if hit then
				at, normal, air, tHit = hit.Position + hit.Normal * 0.5, hit.Normal, false, t
				break
			end
		end
		last = pos
	end
	if not at then at = from + vel * fuse + Vector3.new(0, -0.5 * gravity * fuse * fuse, 0) end
	local nearest, bestD = nil, 7.5
	for _, d in ipairs(dummies()) do
		if d ~= src then
			local dd = (d.HumanoidRootPart.Position - at).Magnitude
			if dd < bestD then nearest, bestD = d, dd end
		end
	end
	local burstAt = releaseAt + tHit / scale
	task.delay(math.max(0, burstAt - now()), function()
		handler("VoltOrbBurst", {
			Character = src, At = at, Normal = normal, Direct = nil, Nearest = nearest, Air = air, T0 = now(),
		})
	end)
	say(string.format("volt orb look from %s: %s %.2f s after release, %.1f studs out", src.Name,
		air and "fuse" or "contact", tHit, flat(at - from).Magnitude))
end

local function lookCascade(src)
	local point = groundBelow(src.HumanoidRootPart.Position, {})
	-- (2026-10-19, audit P5D-19) Strikes are from the CAST since the windup moved in front of the storm (Windup 0.50 +
	-- StormStrikes); the fallback was the storm-only clock
	local strikes = { 1.7333, 1.80, 1.8667, 1.9667, 2.0333 }
	local zone = 11
	local VFX = mod(iceFolder, "VoltaicFX")
	local C = VFX and VFX.Tuning and VFX.Tuning.Cascade
	if C then
		if not C.Strikes and type(C.StormStrikes) == "table" and type(C.Windup) == "number" then
			strikes = {}
			for i, s in ipairs(C.StormStrikes) do strikes[i] = C.Windup + s end
		end
		strikes = C.Strikes or strikes
		zone = C.ZoneRadius or zone
	end
	local spread = { { 0.84, 0 }, { 0.46, 144 }, { 0.78, 288 }, { 0.55, 72 }, { 0.66, 216 } }
	local VT = mod(iceFolder, "VoltaicTuning")
	if VT and VT.Cascade and type(VT.Cascade.Spread) == "table" then spread = VT.Cascade.Spread end
	local scale = timeScale()
	local t0 = now()
	handler("CascadeGather", { Character = src, Point = point, T0 = t0 })
	local count = {}
	for n = 1, #strikes do
		task.delay(strikes[n] / scale, function()
			-- the least-struck body inside the zone, ties to the nearest; none -> the filler point
			local best, bestCount, bestD = nil, math.huge, math.huge
			for _, d in ipairs(dummies()) do
				if d == src then continue end                  -- the server never strikes the caster
				local dd = flat(d.HumanoidRootPart.Position - point).Magnitude
				local k = count[d] or 0
				if dd <= zone and (k < bestCount or (k == bestCount and dd < bestD)) then
					best, bestCount, bestD = d, k, dd
				end
			end
			local at
			if best then
				count[best] = (count[best] or 0) + 1
				at = groundBelow(best.HumanoidRootPart.Position, {})
			else
				local s = spread[n] or { 0.5, 0 }
				local a = math.rad(s[2])
				at = point + Vector3.new(math.cos(a), 0, math.sin(a)) * s[1] * zone
			end
			handler("CascadeStrike", { Character = src, Point = point, N = n, At = at, T0 = t0 })
			if n == #strikes then handler("CascadeEnd", { Character = src, T0 = t0 }) end
		end)
	end
	say(string.format("cascade look over %s (point %s)", src.Name, fmt(point)))
end

local function look(what)
	local src = source()
	if not src then say("look: no dummy (streamed in?)") return end
	if what == "chainbolt" then
		lookChainBolt(src, 1)
	elseif what == "chainboltprimed" then
		lookChainBolt(src, 3)
	elseif what == "chainboltdummy" then
		lookChainBoltDummy(src)
	elseif what == "discharge" then
		lookDischarge(src)
	elseif what == "overcharge" then
		lookOvercharge(src)
	elseif what == "railspike" then
		lookRailspike(src)
	elseif what == "voltorb" then
		lookVoltOrb(src)
	elseif what == "cascade" then
		lookCascade(src)
	else
		say("look: unknown '" .. what .. "'")
	end
end

local function loadout()
	local remote = spellFolder:WaitForChild("LoadoutRequest", 5)
	if not remote then say("no LoadoutRequest remote") return end
	local before = string.format("Element=%s Mobility=%s Defense=%s", tostring(player:GetAttribute("Element")),
		tostring(player:GetAttribute("Mobility")), tostring(player:GetAttribute("Defense")))
	if player:GetAttribute("Element") == "Voltaic" then
		note("loadout: already Voltaic -- the server treats a re-pick as no change")
	end
	remote:FireServer("Element", "Voltaic")
	task.wait(0.6)
	local after = string.format("Element=%s Mobility=%s Defense=%s", tostring(player:GetAttribute("Element")),
		tostring(player:GetAttribute("Mobility")), tostring(player:GetAttribute("Defense")))
	say("loadout: before " .. before .. "; after " .. after
		.. (player:GetAttribute("Element") == "Voltaic" and "" or " (REFUSED: not in BuiltElements?)"))
end

player:GetAttributeChangedSignal("VoltTest"):Connect(function()
	local what = player:GetAttribute("VoltTest")
	if type(what) ~= "string" then return end
	player:SetAttribute("VoltTest", nil)
	fxPeak = 0
	note("TRIGGER " .. what)
	task.spawn(function()
		local ok, err = pcall(function()
			if what == "m1" then
				fireM1(1)
			elseif what:match("^m1x%d+$") then
				fireM1(math.clamp(tonumber(what:sub(4)) or 1, 1, 50))
			elseif what == "primary" then
				primary()
			elseif what:sub(1, 4) == "aim:" then
				aim(what:sub(5))
			elseif what:sub(1, 5) == "look:" then
				look(what:sub(6))
			elseif what:sub(1, 4) == "dev:" then
				local dev = spellFolder:WaitForChild("DevRequest", 5)
				if dev then
					dev:FireServer(what:sub(5))
					say("dev " .. what:sub(5))
				else
					say("no DevRequest remote")
				end
			elseif what == "loadout" then
				loadout()
			elseif what == "clearlog" then
				table.clear(log)
				player:SetAttribute("VoltClientLog", "")
				say("log cleared")
			else
				say("unknown VoltTest '" .. what .. "'")
			end
		end)
		if not ok then say("VoltTest " .. what .. " errored: " .. tostring(err)) end
	end)
end)

say("ready")
