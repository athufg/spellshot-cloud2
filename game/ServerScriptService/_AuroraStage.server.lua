-- TEMPORARY Aurora v8 test stage (Claude, 2026-10-17): remove when done
local Players = game:GetService("Players")
while #Players:GetPlayers() == 0 or not Players:GetPlayers()[1].Character do task.wait(0.2) end
task.wait(1)
local ch = Players:GetPlayers()[1].Character
local S = Vector3.new(-90, 0, -45)
local folder = Instance.new("Folder") folder.Name = "WrapStage" folder.Parent = workspace
ch.Archivable = true
local function dummy(name, wrap, tone)
	local d = ch:Clone()
	d.Name = name
	for _, s in ipairs(d:GetDescendants()) do
		if s:IsA("Script") or s:IsA("LocalScript") then s:Destroy() end
		if tone and (s:IsA("Shirt") or s:IsA("Pants") or s:IsA("ShirtGraphic")) then s:Destroy() end
	end
	if tone then
		for _, p in ipairs(d:GetDescendants()) do if p:IsA("BasePart") then p.Color = tone end end
		local bc = d:FindFirstChildOfClass("BodyColors") if bc then bc:Destroy() end
	end
	d.HumanoidRootPart.Anchored = true
	d:FindFirstChildOfClass("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if wrap then d:SetAttribute("WrapStudio", wrap) end
	d.Parent = folder
	return d
end
local L = game:GetService("Lighting")
local W = { S = S, Remote = game.ReplicatedStorage:FindFirstChild("IceAbilityRemote", true), C = dummy("Caster", "Aurora"),
	Dark = dummy("DarkDummy", nil, Color3.fromRGB(28, 28, 30)), Light = dummy("LightDummy", nil, Color3.fromRGB(236, 236, 232)),
	Day = { ClockTime = L.ClockTime, Brightness = L.Brightness, ExposureCompensation = L.ExposureCompensation, OutdoorAmbient = L.OutdoorAmbient } }
_G.WS = W
_G.dummies = function(on)
	W.Dark.Parent, W.Light.Parent = on and folder or nil, on and folder or nil
	if on then
		W.Dark:PivotTo(CFrame.lookAt(S + Vector3.new(-7, 3, 7), S + Vector3.new(-7, 3, 40)))
		W.Light:PivotTo(CFrame.lookAt(S + Vector3.new(7, 3, 7), S + Vector3.new(7, 3, 40)))
	end
end
_G.dusk = function(on)
	if on then L.ClockTime, L.Brightness, L.ExposureCompensation, L.OutdoorAmbient = 19.6, 0.6, -0.6, Color3.fromRGB(40, 48, 70)
	else for k, v in pairs(W.Day) do L[k] = v end end
end
_G.casterVisible = function(on)
	for _, p in ipairs(W.C:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Transparency = on and 0 or 1
		elseif p:IsA("Decal") then p.Transparency = on and 0 or 1 end
	end
end
_G.ff = function(opt, pulses)
	local c = W.C
	if opt then workspace:SetAttribute("AuroraFloor", opt) end
	c:PivotTo(CFrame.lookAt(S + Vector3.new(0, 3, 0), S + Vector3.new(0, 3, 40)))
	W.Remote:FireAllClients("VFX", "FlashFreeze", { Caster = c, OriginPart = c.HumanoidRootPart, Seed = 7 })
	if pulses then
		for _, p in ipairs({ 1.7, 3.4 }) do
			task.delay(p, function() workspace:SetAttribute("AuroraMask", true) end)
			task.delay(p + 0.3, function() workspace:SetAttribute("AuroraMask", false) end)
		end
	end
end
_G.mc = function()
	local c = W.C
	c:PivotTo(CFrame.lookAt(S + Vector3.new(8, 3, 60), S))
	W.Dark.Parent = folder
	W.Dark:PivotTo(CFrame.lookAt(S + Vector3.new(0, 3, 0), Vector3.new(-90, 3, 0)))
	task.wait(1.5)
	W.Remote:FireAllClients("VFX", "MirrorCage", { Character = c, Center = S, T0 = workspace:GetServerTimeNow() - 1.0, Victims = { { Model = W.Dark, At = S } }, Yaw = 0 })
end
_G.dummies(false)
workspace:SetAttribute("CamPinEye", S + Vector3.new(0, 14, 36))
workspace:SetAttribute("CamPinLook", S + Vector3.new(0, 1, 0))
workspace:SetAttribute("StageReady", true)
-- commands from the test tool: workspace StageCmd = "<n>|step;step;..." (steps: ff:a[:p] / mc / dummies:1|0 / dusk:1|0 /
-- caster:1|0 / wait:secs / cam:ex,ey,ez,lx,ly,lz (relative to S) / attr:Name:value); StageDone = n when finished
local busy = false
workspace:GetAttributeChangedSignal("StageCmd"):Connect(function()
	local v = workspace:GetAttribute("StageCmd")
	if type(v) ~= "string" then return end
	local n, list = string.match(v, "^(%d+)|(.*)$")
	if not n then return end
	task.spawn(function()
		while busy do task.wait(0.05) end
		busy = true
		for step in string.gmatch(list, "[^;]+") do
			local a = string.split(step, ":")
			if a[1] == "ff" then _G.ff(a[2] ~= "" and a[2] or nil, a[3] == "p")
			elseif a[1] == "mc" then task.spawn(_G.mc)
			elseif a[1] == "dummies" then _G.dummies(a[2] == "1")
			elseif a[1] == "dusk" then _G.dusk(a[2] == "1")
			elseif a[1] == "caster" then _G.casterVisible(a[2] == "1")
			elseif a[1] == "wait" then task.wait(tonumber(a[2]) or 0)
			elseif a[1] == "cam" then
				local c = string.split(a[2], ",")
				local k = {} for i = 1, 6 do k[i] = tonumber(c[i]) end
				workspace:SetAttribute("CamPinEye", S + Vector3.new(k[1], k[2], k[3]))
				workspace:SetAttribute("CamPinLook", S + Vector3.new(k[4], k[5], k[6]))
			elseif a[1] == "attr" then
				local val = a[3]
				if val == "nil" then val = nil elseif val == "true" then val = true elseif val == "false" then val = false
				elseif tonumber(val) then val = tonumber(val) end
				workspace:SetAttribute(a[2], val)
			end
		end
		busy = false
		workspace:SetAttribute("StageDone", tonumber(n))
	end)
end)
