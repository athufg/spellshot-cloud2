-- TEMPORARY Aurora v8 test stage (Claude, 2026-10-17): remove when done
local plr = game.Players.LocalPlayer
local ch = plr.Character or plr.CharacterAdded:Wait()
ch:WaitForChild("HumanoidRootPart").Anchored = true
ch:PivotTo(CFrame.lookAt(Vector3.new(-90, 4, 0), Vector3.new(-90, 4, -45)))
pcall(function() plr:RequestStreamAroundAsync(Vector3.new(-90, 0, -45), 10) end)
task.wait(2)
for _, g in ipairs(plr.PlayerGui:GetChildren()) do if g:IsA("ScreenGui") then g.Enabled = false end end
game:GetService("RunService"):BindToRenderStep("CamPinLS", 1000000, function()
	local e, l = workspace:GetAttribute("CamPinEye"), workspace:GetAttribute("CamPinLook")
	if typeof(e) ~= "Vector3" or typeof(l) ~= "Vector3" then return end
	local c = workspace.CurrentCamera
	c.CameraType = Enum.CameraType.Scriptable
	c.CFrame = CFrame.lookAt(e, l)
	c.FieldOfView = 70
	for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end end
	for _, p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 1 end end
end)
