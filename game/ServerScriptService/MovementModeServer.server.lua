--[[
	MovementModeServer  (Script)  ->  ServerScriptService/MovementModeServer

	THE MOVEMENT SWITCH (2026-10-18, movement switch). The owner's decision for team mode: "switch only, keep full, but
	keep jumping by default, one jump only". Config.Movement.Mode is the default ("Full"); this script is how a dev
	changes it LIVE, because an edit to Config from the command bar during Play never reaches the game.

	  DevPanel's MOVEMENT row  --MovementModeRequest(mode)-->  here: Config.IsDev(player) on the server, and mode must
	  be "Full" or "RunningOnly"  -->  workspace:SetAttribute("MovementMode", mode), which replicates to every client.

	MovementController (and TouchControls' SLIDE / CROUCH button) read that attribute live and react the same frame.
	A refused request is answered "denied" so the panel can say so, the way SpellshotService answers DevRequest.
	Nothing is set at startup: with no attribute every client falls back to Config.Movement.Mode, so a MovementMode
	attribute set on Workspace in Studio's Properties before Play is kept, not overwritten.

	TO TURN IT OFF: workspace:SetAttribute("MovementMode", nil) (or "Full") from the server command bar, or disable
	this Script (the panel's row then does nothing; the game stays on Config.Movement.Mode).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local remote = folder:WaitForChild("MovementModeRequest")

local MODES = { Full = true, RunningOnly = true }

remote.OnServerEvent:Connect(function(player, mode)
	if not Config.IsDev(player) then
		remote:FireClient(player, "denied", RunService:IsStudio())
		return
	end
	if type(mode) ~= "string" or not MODES[mode] then return end
	if workspace:GetAttribute("MovementMode") == mode then return end
	workspace:SetAttribute("MovementMode", mode)
	print(("[MovementModeServer] %s set MovementMode = %s"):format(player.Name, mode))
end)
