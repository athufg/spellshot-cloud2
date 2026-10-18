--[[
	DeflectGustPractice  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/DeflectGustPractice

	The range's practice shot (the "snowball"), client half: DRAW every practice shot the range throws, on the server's
	clock, in its own plain look -- out, back if something returns it, and its plain hit where it lands. TrainingGround
	(server) decides all of that; this only follows the broadcasts. What the practice shot is: see
	ReplicatedStorage.Spellshot.DeflectPractice.

	It keeps the shots in flight in DeflectPractice.Live, the table a parry reads for its catch claim.

	2026-10-11: restored at the owner's request (the Zephyr v6 import of 2026-10-06 had retired it with Deflect Gust).
	The Parry Arc, Wind Shear and Trail it used to play on a returned shot were ZephyrFX's and went with Deflect Gust, so
	a returned shot is drawn as the same plain ball flying home and nothing else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Practice = require(spellFolder:WaitForChild("DeflectPractice"))
local remote = spellFolder:WaitForChild("DeflectPracticeRemote", 60)
if not remote then return end

local live = Practice.Live  -- [id] = { Shot = the broadcast, State = "Out" | "Back", Ball = part }

local function fxFolder()
	local f = workspace:FindFirstChild("DeflectPracticeFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DeflectPracticeFX"
		f.Parent = workspace
	end
	return f
end

----------------------------------------------------------------------------------------------------
-- drawing the shots
----------------------------------------------------------------------------------------------------
local function track(d, state)
	local s = live[d.Id]
	if not s then
		s = { Ball = Practice.MakeBall(fxFolder()) }
		live[d.Id] = s
	end
	s.Shot, s.State = d, state
	s.Ball.CFrame = CFrame.new((Practice.PositionAt(d, workspace:GetServerTimeNow())))
	return s
end

local function finish(d, withHit)
	local s = live[d.Id]
	live[d.Id] = nil
	local at = typeof(d.Position) == "Vector3" and d.Position or (s and s.Ball.Position)
	if s then
		s.Ball:Destroy()
	end
	if withHit and at then
		Practice.Impact(at, fxFolder())      -- the shot's OWN hit, wherever it lands
	end
end

remote.OnClientEvent:Connect(function(action, d)
	if type(d) ~= "table" or d.Id == nil then return end
	if action == "Throw" then
		track(d, "Out")
	elseif action == "Return" then
		track(d, "Back")
	elseif action == "Land" then
		finish(d, true)
	elseif action == "Spent" then
		finish(d, false)
	end
end)

RunService.RenderStepped:Connect(function()
	if next(live) == nil then return end
	local now = workspace:GetServerTimeNow()
	for _, s in pairs(live) do
		s.Ball.CFrame = CFrame.new((Practice.PositionAt(s.Shot, now)))
	end
end)
