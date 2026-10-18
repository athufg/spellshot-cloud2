--[[
	SettingsStore  (Script)  ->  ServerScriptService/SettingsStore

	Saves each player's settings and hands them back on the next join. The only server-side half of
	the settings system; everything about what a setting MEANS lives in the shared SpellshotSettings
	module, and everything about applying one lives on the client.

	THE REMOTE. ReplicatedStorage.Spellshot.SettingsSync, made here at startup:

	  client -> server   "request"                ask for the saved table
	  client -> server   "save", <snapshot>       here is the whole current state
	  server -> client   <table>                  the saved table, sanitised

	WHY A WHOLE SNAPSHOT RATHER THAN A DELTA. A snapshot is idempotent: a dropped or reordered
	message cannot leave the save half-applied, and the client debounces so a slider drag is one
	message, not one per frame. It is ~35 small values.

	TRUST. Nothing here trusts the client, and nothing needs to: every value is re-validated through
	Settings.Sanitise, so the worst a forged message can do is set that player's own preferences to
	something inside the range the menu offers anyway. There is a rate limit as well, because a
	client that spams saves would otherwise spend the place's DataStore budget.

	DATASTORES IN STUDIO. Studio can only reach a DataStore when "Enable Studio Access to API
	Services" is on. When it is off, GetAsync throws, this warns ONCE, and the session runs with
	in-memory settings -- the menu still works, it just starts from defaults each time you press
	Play. That is the right failure: a settings menu must never be dead because a DataStore is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Settings = require(folder:WaitForChild("SpellshotSettings"))

local STORE_NAME = "SpellshotSettings_v1"
local KEY = "p_%d"
local AUTOSAVE = 120                  -- seconds between background saves of anything still dirty
local MIN_GAP = 0.4                   -- fastest a client may push a save

local store
do
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and s or nil
end

local remote = folder:FindFirstChild("SettingsSync")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "SettingsSync"
	remote.Parent = folder
end

local state = {}                      -- [player] = { values = {}, dirty = bool, lastPush = 0 }
local warnedNoAccess = false

local function warnOnce(err)
	if warnedNoAccess then return end
	warnedNoAccess = true
	warn("[SettingsStore] DataStore unavailable, settings will not persist this session (" ..
		tostring(err) .. "). In Studio this is usually Game Settings > Security > Enable Studio " ..
		"Access to API Services.")
end

local function load(player)
	if not store then
		warnOnce("no DataStore service")
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(string.format(KEY, player.UserId))
	end)
	if not ok then
		warnOnce(data)
		return nil
	end
	return data
end

local function save(player)
	local s = state[player]
	if not s or not s.dirty then return end
	if not store then
		s.dirty = false
		return
	end
	local values = s.values
	local ok, err = pcall(function()
		store:SetAsync(string.format(KEY, player.UserId), values)
	end)
	if ok then
		s.dirty = false
	else
		warnOnce(err)                 -- left dirty on purpose: the next autosave tries again
	end
end

Players.PlayerAdded:Connect(function(player)
	local saved = load(player)
	state[player] = { values = Settings.Sanitise(saved), dirty = false, lastPush = 0 }
	if player.Parent then
		remote:FireClient(player, state[player].values)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	state[player] = nil
end)

remote.OnServerEvent:Connect(function(player, what, payload)
	local s = state[player]
	if not s then return end
	if what == "request" then
		remote:FireClient(player, s.values)
	elseif what == "save" then
		local now = os.clock()
		if now - s.lastPush < MIN_GAP then return end       -- dropped, not queued: the next push is whole
		s.lastPush = now
		s.values = Settings.Sanitise(payload)
		s.dirty = true
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for player in pairs(state) do
			if player.Parent then save(player) end
		end
	end
end)

game:BindToClose(function()
	for player in pairs(state) do
		save(player)
	end
	if not RunService:IsStudio() then
		task.wait(1)                  -- give the writes a moment before the server goes
	end
end)
