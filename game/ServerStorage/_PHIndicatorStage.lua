-- TEMPORARY pH Indicator checkpoint stage (Claude, 2026-10-20): remove when the wrap is wired
local M = {}
local S = Vector3.new(-90, 0, -45)
local Core, W
local function now() return workspace:GetServerTimeNow() end
local function cam(e, l) workspace:SetAttribute("CamPinEye", S + e) workspace:SetAttribute("CamPinLook", S + l) end
local function tag(n) workspace:SetAttribute("ShotTag", n) task.wait(0.5) workspace:SetAttribute("ShotTag", 0) end
function M.setup()
	local t = os.clock() while not workspace:GetAttribute("StageReady") and os.clock() - t < 40 do task.wait(0.2) end
	local base = workspace.WrapStage.Caster base.Archivable = true
	local box = Instance.new("Model") box.Name = "_PHP" box.ModelStreamingMode = Enum.ModelStreamingMode.Persistent box.Parent = workspace
	W = {}
	local function dummy(n, wrap, pos, look)
		local d = base:Clone() d.Name = n d:SetAttribute("WrapStudio", wrap) d.Parent = box
		d:PivotTo(CFrame.lookAt(S + pos, S + look)) return d
	end
	W.C1 = dummy("C1", nil, Vector3.new(-8, -30, -14), Vector3.new(-8, -30, 40))
	W.C2 = dummy("C2", "PHIndicator", Vector3.new(8, -30, -14), Vector3.new(8, -30, 40))
	W.V1 = dummy("V1", nil, Vector3.new(-6, 3, 0), Vector3.new(-6, 3, 40))
	W.V2 = dummy("V2", nil, Vector3.new(6, 3, 0), Vector3.new(6, 3, 40))
	base:PivotTo(CFrame.new(S + Vector3.new(0, -50, 0)))
	Core = require(game:GetService("ServerScriptService"):FindFirstChild("CombatCore", true) or game:GetService("ReplicatedStorage"):FindFirstChild("CombatCore", true))
	task.wait(2)
	Core.Broadcast("ToxinBubble", { Character = W.C2, Id = 77003 + math.random(1, 99) * 10, Origin = S + Vector3.new(0, -20, 0), Vel = Vector3.zero, G = 0, T0 = now() })
	task.wait(4)
	M.clouds() task.wait(7)
	cam(Vector3.new(0, 4.5, 24), Vector3.new(0, 2.2, 2))
	return "staged"
end
function M.clouds()
	for i, c in ipairs({ W.C1, W.C2 }) do
		local p = S + Vector3.new(i == 1 and -8 or 8, 0, 2)
		Core.Broadcast("ToxinCloud", { Character = c, Id = 77100 + i + math.random(1, 999) * 10, Point = p, Center = p, Radius = 5, T0 = now(), FormTime = 0.25, Duration = 6, Kind = "Corrosive" })
	end
end
function M.shots()
	cam(Vector3.new(0, 4.5, 24), Vector3.new(0, 2.2, 2))
	M.clouds() task.wait(2.6) tag(1)
	cam(Vector3.new(0, 24, 16), Vector3.new(0, 0, 2)) task.wait(0.6) tag(2)
	task.wait(2.5)
	cam(Vector3.new(0, 3.6, 10), Vector3.new(0, 3, 0))
	for i, c in ipairs({ W.C1, W.C2 }) do
		Core.Broadcast("ToxinBubble", { Character = c, Id = 77500 + i + math.random(1, 999) * 10, Origin = S + Vector3.new(i == 1 and -3 or 3, 3, 3), Vel = Vector3.zero, G = 0, T0 = now() })
	end
	task.wait(1.5) tag(3)
	cam(Vector3.new(0, 4.2, 17), Vector3.new(0, 3.2, 0))
	task.wait(1.5)
	local t0 = now()
	Core.Broadcast("ToxinPZMark", { Character = W.C1, Target = W.V1, T0 = t0 })
	Core.Broadcast("ToxinPZMark", { Character = W.C2, Target = W.V2, T0 = t0 })
	task.wait(0.9) tag(4)
	task.wait(1.6) tag(5)
end
return M
