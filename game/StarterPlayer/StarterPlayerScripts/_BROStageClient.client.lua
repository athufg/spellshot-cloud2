-- TEMPORARY Blue-Ringed Octopus checkpoint stage (Claude, 2026-10-19): remove when done
task.wait(4)
local g = Instance.new("ScreenGui") g.Name = "_ShotTag" g.IgnoreGuiInset = true g.ResetOnSpawn = false
local f = Instance.new("Frame") f.Size = UDim2.fromOffset(24, 24) f.AnchorPoint = Vector2.new(1, 1) f.Position = UDim2.new(1, -4, 1, -4) f.BorderSizePixel = 0 f.Parent = g
g.Parent = game.Players.LocalPlayer.PlayerGui
game:GetService("RunService"):BindToRenderStep("ShotTag", 2000, function() g.Enabled = true f.BackgroundColor3 = Color3.fromRGB(math.min(255, (workspace:GetAttribute("ShotTag") or 0) * 10), 255, 0) end)
local fl = Instance.new("Part") fl.Name = "_ShowcaseFloor" fl.Anchored = true fl.CanCollide = false fl.Size = Vector3.new(200, 0.2, 200)
fl.CFrame = CFrame.new(-90, 0.05, -45) fl.Color = Color3.fromHex("#C9C2B8") fl.Material = Enum.Material.SmoothPlastic fl.Transparency = 1 fl.Parent = workspace
local sk = Instance.new("Part") sk.Name = "_ShowcaseSky" sk.Anchored = true sk.CanCollide = false sk.CastShadow = false sk.Size = Vector3.new(400, 160, 1)
sk.CFrame = CFrame.new(-90, 60, -100) sk.Color = Color3.fromHex("#B9C4CC") sk.Material = Enum.Material.SmoothPlastic sk.Transparency = 1 sk.Parent = workspace
workspace:GetAttributeChangedSignal("Showcase"):Connect(function() local on = workspace:GetAttribute("Showcase") fl.Transparency = on and 0 or 1 sk.Transparency = on and 0 or 1 end)
