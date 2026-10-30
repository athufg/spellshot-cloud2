--[[
	TerraTestHarness  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/TerraTestHarness

	STUDIO ONLY (2026-10-19, audit P6A-15): it stands down at once in a live server, as VoltaicTestHarness does.
	TEMPORARY. Delete after the Terra pass. Studio's script sandbox cannot send a mouse press
	(VirtualInputManager needs RobloxScript capability) and cannot fire a remote, so an automated Play
	test of a kit driven by LMB has to run from inside the game. This drives exactly what
	SpellshotInput's own Boulder Shot path drives -- the same remotes, the same TerraFX calls, the same
	order -- and writes what happened onto the player as attributes for the test to read back.

	Trigger: set the player attribute TerraTest to a charge time in seconds (0 = a tap). It runs once per
	write and clears the attribute when it is done.
	Aftershock (2026-09-25, Terra's Mobility Technique since it replaced Tremor Vault): TerraVisual = "aftershock" presses
	it through its key's own path (and reports whether the server took it); TerraVisual = "aftershockdummy" plays its whole
	look as somebody else's cast on the nearest dummy (look only, nobody is struck).
]]

-- (2026-10-19, audit P6A-15) a test driver that fires real cast remotes off player attributes: never in a live game
if not game:GetService("RunService"):IsStudio() then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")
local TerraFX = require(iceFolder:WaitForChild("TerraFX"))
local VFXLibrary = require(iceFolder:WaitForChild("VFXLibrary"))
local iceRemote = iceFolder:WaitForChild("IceAbilityRemote")
local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local castRemote = spellFolder:WaitForChild("CastRequest")

local shotId = 0

local function say(text)
	player:SetAttribute("TerraTestResult", text)
	print("[TerraTestHarness] " .. text)
end

--- The nearest living training dummy, and its root -- or the one a test pinned by name (TombDummy).
local function target()
	local tg = workspace:FindFirstChild("TrainingGround")
	if not tg then return nil end
	local pinned = player:GetAttribute("TombDummy")
	local named = pinned and tg:FindFirstChild(pinned, true)
	if named and named:FindFirstChild("HumanoidRootPart") and named:FindFirstChildOfClass("Humanoid") then
		local from = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return named:FindFirstChildOfClass("Humanoid"), named.HumanoidRootPart,
			from and (named.HumanoidRootPart.Position - from.Position).Magnitude or 0
	end
	local best, bestRoot, bestD = nil, nil, math.huge
	local from = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(tg:GetDescendants()) do
		if d:IsA("Humanoid") and d.Health > 0 then
			local root = d.Parent and d.Parent:FindFirstChild("HumanoidRootPart")
			if root and from then
				local dist = (root.Position - from.Position).Magnitude
				if dist < bestD then best, bestRoot, bestD = d, root, dist end
			end
		end
	end
	return best, bestRoot, bestD
end

local function runShot(holdFor)
	local character = player.Character
	if not character then say("no character") return end
	local dummy, droot, dist = target()
	if not droot then say("no dummy") return end

	-- the press: the hold starts, exactly as the mouse-down branch does -- the rework's (2026-09-23) windup clip, clocked
	-- in seconds from the press, and TerraFX's rock held at the viewmodel's fist (the body's hand in third person)
	iceRemote:FireServer("BoulderCharge", { On = true })
	local at = os.clock()
	local ok, Viewmodel = pcall(require, iceFolder:WaitForChild("Viewmodel"))
	if ok then Viewmodel.Play("BoulderWindup", function() return os.clock() - at end) end
	local function hand()
		if not (character.Parent and player.Character == character) then return nil end
		local facing = CFrame.lookAt(Vector3.zero, Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z))
		local fist = ok and Viewmodel.GetFistCFrame and Viewmodel.GetFistCFrame("R")
		if fist then return fist, camera.CFrame.Position, facing end
		local h = character:FindFirstChild("RightHand")
		return h and h.CFrame, nil, facing
	end
	local released = false
	local rock = TerraFX.Charge(function()
		if released and os.clock() - at > holdFor + 0.5 then return nil end
		return math.clamp((os.clock() - at) / TerraFX.Tuning.BoulderShot.ChargeTime, 0, 1)
	end, hand, { Own = true, Character = character })
	task.wait(holdFor)

	-- the release: eye and aim, straight at the dummy's chest so the test does not depend on where the
	-- camera happens to point
	local charge = math.clamp((os.clock() - at) / TerraFX.Tuning.BoulderShot.ChargeTime, 0, 1)
	-- a NEGATIVE TerraTest means "hold this long but CLAIM a full charge": the check that a client cannot buy
	-- damage it never gathered (TerraHandler clamps the claim to the hold the server itself saw)
	if player:GetAttribute("TerraTestLie") then charge = 1 end
	local head = character:FindFirstChild("Head")
	local eye = head and head.Position or camera.CFrame.Position
	local dir = (droot.Position - eye)
	-- lead the drop: the boulder falls Gravity/2 * t^2 over the flight, so aim above the chest by that much
	local B = TerraFX.Tuning.BoulderShot
	local speed = B.MinSpeed + (B.MaxSpeed - B.MinSpeed) * charge
	local t = dir.Magnitude / speed
	dir = (droot.Position + Vector3.new(0, 0.5 * B.Gravity * t * t, 0) - eye).Unit
	shotId += 1
	local id = shotId
	if ok then Viewmodel.Play("BoulderThrow") end
	iceRemote:FireServer("BoulderRelease", { Id = id, Origin = eye, Dir = dir, Charge = charge })
	iceRemote:FireServer("BoulderCharge", { On = false })
	released = true
	local hits = 0
	TerraFX.FireBoulder(eye, dir, charge, { character, camera }, rock, function(hit)
		hits += 1
		iceRemote:FireServer("BoulderHit", { Id = id, Part = hit.Instance, Position = hit.Position })
		say(string.format("charge %.2f -> hit %s at %.1f studs", charge, hit.Instance:GetFullName(), dist))
	end)
	castRemote:FireServer("M1", { Target = droot.Position, Dir = dir, Charge = charge })
	say(string.format("charge %.2f thrown at %s (%.1f studs), damage should be %.0f",
		charge, dummy.Parent.Name, dist, TerraFX.ChargeDamage(charge)))
end

-- TerraTestLoop = n: throw n times in a row, a second apart, so a screen capture has something to land on.
player:GetAttributeChangedSignal("TerraTestLoop"):Connect(function()
	local n = player:GetAttribute("TerraTestLoop")
	if type(n) ~= "number" then return end
	player:SetAttribute("TerraTestLoop", nil)
	task.spawn(function()
		for _ = 1, n do
			runShot(1.2)
			task.wait(1.0)
		end
	end)
end)

player:GetAttributeChangedSignal("TerraTest"):Connect(function()
	local hold = player:GetAttribute("TerraTest")
	if type(hold) ~= "number" then return end
	player:SetAttribute("TerraTest", nil)
	player:SetAttribute("TerraTestLie", hold < 0)
	task.spawn(runShot, math.max(0.02, math.abs(hold)))
end)

-- TerraVisual = "bedrock" | "bulwark" | "boulder" (VFX polish, 2026-09-18): plays that piece's look on the nearest
-- dummy AS SOMEBODY ELSE'S -- the way every other client draws it -- because the effects only other players see (the
-- plates' clink, the full-stack pulse, the charge's armour, the stars) never show on your own character. Same
-- TerraFX calls the game makes; nothing here touches the server.
local RunService = game:GetService("RunService")
player:GetAttributeChangedSignal("TerraVisual"):Connect(function()
	local what = player:GetAttribute("TerraVisual")
	if type(what) ~= "string" then return end
	player:SetAttribute("TerraVisual", nil)
	local dummy, droot = target()
	-- a test can pin the dummy by name (TombDummy), rather than taking the nearest
	local pinned = player:GetAttribute("TombDummy")
	local tg = pinned and workspace:FindFirstChild("TrainingGround")
	local named = tg and tg:FindFirstChild(pinned, true)
	if named and named:FindFirstChild("HumanoidRootPart") then
		dummy, droot = named:FindFirstChildOfClass("Humanoid"), named.HumanoidRootPart
	end
	if not droot then say("no dummy") return end
	local model = dummy.Parent
	local t0 = os.clock()
	if what == "bedrock" then
		-- a stack every StackEvery up to five, held, then the lapse
		local B = TerraFX.Tuning.Bedrock
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			local n = t < B.StackEvery * B.MaxStacks + 1.6 and math.min(B.MaxStacks, math.floor(t / B.StackEvery) + 1) or 0
			TerraFX.Bedrock(model, n)
			if t > B.StackEvery * B.MaxStacks + 2.6 then conn:Disconnect() end
		end)
		say("bedrock on " .. model.Name)
	elseif what == "bulwark" then
		TerraFX.BulwarkTrail(model, function() return os.clock() < t0 + 0.9 end)
		task.delay(0.5, function()
			TerraFX.BulwarkHit(droot.Position + droot.CFrame.LookVector * 1.5, -droot.CFrame.LookVector, true)
			model:SetAttribute("RX_Staggered", true)
			task.delay(TerraFX.Tuning.BulwarkCharge.Stagger, function() model:SetAttribute("RX_Staggered", false) end)
		end)
		say("bulwark on " .. model.Name)
	elseif what == "boulder" then
		-- the rework (2026-09-23): the dummy's own right hand, posed by CastPose's windup and throw as AbilityFX poses
		-- any other Terra's body, so this is the third-person throw a spectator sees
		local C = TerraFX.Tuning.BoulderShot
		local okc, CastPose = pcall(require, iceFolder:WaitForChild("CastPose"))
		if okc then pcall(CastPose.PlayClocked, model, "BoulderWindup", function() return os.clock() - t0 end) end
		local held = C.ChargeTime + 0.2
		local hand = function()
			local h = model:FindFirstChild("RightHand")
			local facing = CFrame.lookAt(Vector3.zero, Vector3.new(droot.CFrame.LookVector.X, 0, droot.CFrame.LookVector.Z))
			return h and h.CFrame or droot.CFrame * CFrame.new(1.4, 1.6, -1.6), nil, facing
		end
		local rock = TerraFX.Charge(function()
			return math.clamp((os.clock() - t0) / C.ChargeTime, 0, 1)
		end, hand, { Thin = true, Character = model })
		task.delay(held, function()
			if okc then pcall(CastPose.Play, model, "BoulderThrow") end
			local head = model:FindFirstChild("Head")
			local from = head and head.Position or droot.Position
			local dir = (droot.CFrame.LookVector * 18 + Vector3.new(0, -3, 0)).Unit
			TerraFX.FireBoulder(from, dir, 1, { model }, rock, nil)
		end)
		say("boulder from " .. model.Name)
	elseif what == "tomb" then
		-- Earthen Tomb (2026-09-19), cast at the nearest dummy exactly as the R key casts it: CastRequest, Ultimate, the
		-- crosshair's point -- here the dummy itself. Everything after is TerraHandler's.
		castRemote:FireServer("Ultimate", { Target = droot.Position })
		say("tomb at " .. model.Name)
	elseif what == "recordview" then
		-- for a third-person recording: the first-person arms taken down, and your own body kept drawn (first person
		-- hides it every frame; this puts it straight back each time)
		local ok, Viewmodel = pcall(require, iceFolder:WaitForChild("Viewmodel"))
		if ok then pcall(Viewmodel.Destroy) end
		for _, part in ipairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
				part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
					if part.LocalTransparencyModifier ~= 0 then part.LocalTransparencyModifier = 0 end
				end)
			end
		end
		say("record view")
	elseif what:sub(1, 5) == "wall:" then
		-- Bulwark Wall (2026-09-19) through the Defense key's own path: the press (CastRequest "Defense"), held N seconds,
		-- then the release ({ Release = true }) -- exactly what SpellshotInput sends for a held ability. N = 0: never let go.
		local hold = tonumber(what:sub(6)) or 2
		castRemote:FireServer("Defense", {})
		say(string.format("wall pressed, held %.1f s", hold))
		if hold > 0 then
			task.delay(hold, function()
				castRemote:FireServer("Defense", { Release = true })
				say("wall key up")
			end)
		end
	elseif what == "aftershock" then
		-- AFTERSHOCK (2026-09-25; the "vault:<secs>" mode went with Tremor Vault) through its key's own path: a bare press
		-- on whichever Technique slot holds it (CastRequest, {} -- the server trusts nothing in it), plus what the key does
		-- on this client (SpellshotInput's LOCAL_CAST.Aftershock): the arms on the hitpause clock, the slam's shake at
		-- contact and the ring's rumble as the front leaves. Its Precheck turns a press away in silence, so this waits for
		-- the server's own "Aftershock" broadcast the way the key does, and says which it was.
		local slot = VFXLibrary.TechniqueSlot(player, "Aftershock")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not slot then say("Aftershock is in neither Technique slot") return end
		if not root then say("no character") return end
		local A = TerraFX.Tuning.Aftershock
		local at = os.clock()
		local heard = false
		local conn
		conn = iceRemote.OnClientEvent:Connect(function(action, kind, data)
			if action ~= "VFX" or kind ~= "Aftershock" or type(data) ~= "table" or data.Character ~= character then return end
			heard = true
			conn:Disconnect()
			local ahead = typeof(data.At) == "Vector3" and data.At - root.Position or Vector3.zero
			say(string.format("aftershock heard %.2f s after the key; centre %.2f studs ahead, %.2f below the root",
				os.clock() - at, Vector3.new(ahead.X, 0, ahead.Z).Magnitude, -ahead.Y))
		end)
		castRemote:FireServer(slot, {})
		local okv, Viewmodel = pcall(require, iceFolder:WaitForChild("Viewmodel"))
		if okv then
			Viewmodel.Play("Aftershock", function()
				return TerraFX.AftershockClock((os.clock() - at) * VFXLibrary.ShotTimeScale())
			end)
			local scale = VFXLibrary.ShotTimeScale()
			task.delay(A.Hit / scale, function() pcall(Viewmodel.Shake, A.Shake, A.ShakeDecay) end)
			task.delay((A.Hit + A.HoldFrames / 60) / scale, function() pcall(Viewmodel.Shake, A.Rumble, A.RumbleDecay) end)
		end
		say("aftershock pressed on " .. slot)
		task.delay(math.max(0.6, 2 * player:GetNetworkPing() + 0.3), function()
			if heard then return end
			conn:Disconnect()
			if okv and Viewmodel.CurrentClip() == "Aftershock" then Viewmodel.Stop() end
			say("aftershock REFUSED: no broadcast came back")
		end)
	elseif what == "aftershockdummy" then
		-- AFTERSHOCK's whole look (2026-09-25) as SOMEBODY ELSE'S cast, on the nearest dummy (or the pinned one): its body
		-- on the hitpause clock (CastPose, as AbilityFX plays every Terra's) and TerraFX's ring from its fists' point --
		-- Reach ahead along its flat facing, on the floor -- with T0 = now, which is what every other client draws. Look
		-- only: nothing here touches the server, so nobody is struck.
		local A = TerraFX.Tuning.Aftershock
		local look = droot.CFrame.LookVector
		local face = Vector3.new(look.X, 0, look.Z)
		face = face.Magnitude > 1e-3 and face.Unit or Vector3.new(0, 0, -1)
		local ahead = droot.Position + face * A.Reach
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = { model }
		if player.Character then table.insert(exclude, player.Character) end
		local fx = workspace:FindFirstChild(VFXLibrary.Config.FXFolderName)
		if fx then table.insert(exclude, fx) end
		params.FilterDescendantsInstances = exclude
		params.RespectCanCollide = true
		-- from the root's height down, never from high up (a roof is not the floor)
		local hit = workspace:Raycast(ahead, Vector3.new(0, -(A.GroundBelow + 3), 0), params)
		local centre = hit and hit.Position or Vector3.new(ahead.X, droot.Position.Y - 3, ahead.Z)
		local t0 = workspace:GetServerTimeNow()
		local okc, CastPose = pcall(require, iceFolder:WaitForChild("CastPose"))
		if okc then
			pcall(CastPose.PlayClocked, model, "Aftershock", function()
				return TerraFX.AftershockClock((workspace:GetServerTimeNow() - t0) * VFXLibrary.ShotTimeScale())
			end)
		end
		local ok, err = pcall(TerraFX.Aftershock, model, centre, face, t0,
			{ Own = false, Seed = Random.new():NextInteger(1, 2 ^ 30), Thin = true })
		say(ok and string.format("aftershock from %s at %s", model.Name, tostring(centre))
			or ("aftershock look failed: " .. tostring(err)))
	elseif what:sub(1, 4) == "dev:" then
		-- a dev-panel action by name (e.g. "dev:ToggleFreeUlt"), through the panel's own remote
		spellFolder:WaitForChild("DevRequest"):FireServer(what:sub(5))
		say("dev " .. what:sub(5))
	elseif what:sub(1, 6) == "shake:" then
		-- "shake:0" .. "shake:100": the Camera Shake setting, for this session only (silent: never saved)
		local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
		Settings.Set("CameraShake", tonumber(what:sub(7)) or 100, true)
		say("CameraShake " .. tostring(Settings.Get("CameraShake")))
	end
end)

-- EARTHEN TOMB v2 (2026-09-19) with THIS player as the target (a test fires a range dummy's Tomb at them through the
-- server's own path). Both hooks act through this client's REAL controls, so the server judges what it would judge in
-- play: TombJumpAt = a server time to jump at (a plain Humanoid jump -- the server alone decides it was airborne);
-- TombEscapeAfter = seconds after this body is Entombed to cast the equipped Mobility Technique through CastRequest,
-- exactly the request its key sends (the server must accept it for the escape to count).
-- (2026-09-25) Terra's Mobility is now Aftershock, which is NOT an escape: TerraHandler's Mobility-breaks-CC hook excludes
-- it by Id (as Blizzard), and its Precheck refuses an entombed caster at no cost. So the test also reads back, a moment
-- after the cast, whether the body is still held -- with Aftershock equipped it must be; a Technique that IS an escape
-- (Gust Jump, say) frees it, and the same line shows that too.
local ESCAPE_CHECK = 0.5          -- s after the cast the hold is read back
player:GetAttributeChangedSignal("TombJumpAt"):Connect(function()
	local at = player:GetAttribute("TombJumpAt")
	if type(at) ~= "number" then return end
	player:SetAttribute("TombJumpAt", nil)
	task.delay(math.max(0, at - workspace:GetServerTimeNow()), function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Jump = true
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			say(string.format("jumped at %.2f", workspace:GetServerTimeNow()))
		end
	end)
end)
player:GetAttributeChangedSignal("TombEscapeAfter"):Connect(function()
	local after = player:GetAttribute("TombEscapeAfter")
	if type(after) ~= "number" then return end
	player:SetAttribute("TombEscapeAfter", nil)
	local character = player.Character
	if not character then return end
	local conn
	conn = character:GetAttributeChangedSignal("RX_Entombed"):Connect(function()
		if character:GetAttribute("RX_Entombed") ~= true then return end
		conn:Disconnect()
		task.delay(after, function()
			castRemote:FireServer("Mobility", {})
			local id = tostring(player:GetAttribute("Mobility"))
			say(string.format("Mobility (%s) cast %.2f s into the rise", id, after))
			task.delay(ESCAPE_CHECK, function()
				say(string.format("Mobility (%s) cast %.2f s into the rise; %.1f s later RX_Entombed=%s%s", id, after,
					ESCAPE_CHECK, tostring(character:GetAttribute("RX_Entombed")),
					id == "Aftershock" and " (must still be true: Aftershock is no escape)" or ""))
			end)
		end)
	end)
end)

say("ready")
