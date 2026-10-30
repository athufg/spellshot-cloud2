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
	client that spams saves would otherwise spend the place's DataStore budget -- and "request" is
	limited too (REQUEST_GAP, 2026-10-19, audit P1-07), so it cannot be used to make the server reply
	at any rate.

	DATASTORES IN STUDIO. Studio can only reach a DataStore when "Enable Studio Access to API
	Services" is on. When it is off, GetAsync throws, this warns ONCE, and the session runs with
	in-memory settings -- the menu still works, it just starts from defaults each time you press
	Play. That is the right failure: a settings menu must never be dead because a DataStore is.

	A FAILED LOAD IS NEVER SAVED OVER (2026-10-19, audit P2-08). A live GetAsync is tried three
	times; if every try fails the player plays on defaults in memory and NOTHING of theirs is
	written this session (noSave), because the client pushes whole snapshots and "defaults + one
	change" would replace every keybind and accessibility choice in the real record. "No record"
	(a successful GetAsync that returns nil) is a new player and saves as before.

	LOAD ORDER (2026-10-19, audit P2-09). state[player] exists from the moment they join, marked
	`loading`; a push or "request" that arrives before the load is dropped (the client holds its
	pre-load changes and pushes them, merged over the save, once the save arrives -- see
	SpellshotSettings.Load). Players already here when this script starts are loaded too.
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
local REQUEST_GAP = 0.5               -- fastest a client may ask for its table again (2026-10-19, audit P1-07)

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

local state = {}                      -- [player] = { values = {}, dirty = bool, lastPush = 0, rev = 0, loading, noSave, saving }
local warnedNoAccess = false
local inFlight = 0                    -- saves (and leave retries) still running: BindToClose waits on these
local LOAD_TRIES = RunService:IsStudio() and 1 or 3   -- Studio without API access fails every try: no point waiting

local function warnOnce(err)
	if warnedNoAccess then return end
	warnedNoAccess = true
	warn("[SettingsStore] DataStore unavailable, settings will not persist this session (" ..
		tostring(err) .. "). In Studio this is usually Game Settings > Security > Enable Studio " ..
		"Access to API Services.")
end

--- ok, data: ok false when the record could not be READ (no store, or every try threw) -- never the same as "no
--- record yet", which is ok with data nil. (2026-10-19, audit P2-08) a failed read used to return nil too, so the
--- defaults it fell back to were saved over the real record at the next push.
local function load(player)
	if not store then
		warnOnce("no DataStore service")
		return false, nil
	end
	for try = 1, LOAD_TRIES do
		local ok, data = pcall(function()
			return store:GetAsync(string.format(KEY, player.UserId))
		end)
		if ok then return true, data end
		warnOnce(data)
		if try < LOAD_TRIES then
			task.wait(2 * try)
			if not player.Parent then return false, nil end
		end
	end
	return false, nil
end

--- Writes `s` (the player's state) if it has anything unsaved. (2026-10-19, audit P2-10) one write per player at a
--- time: a second caller (the leave save meeting BindToClose's) waits for the first and writes only if something
--- changed since it began, so one key is not written twice inside the per-key limit. A session whose load failed
--- never writes (noSave).
local function save(player, s)
	s = s or state[player]
	if not s or not s.dirty or s.noSave or s.loading then return end
	if not store then
		s.dirty = false
		return
	end
	inFlight += 1
	while s.saving do task.wait(0.1) end
	if s.dirty then
		s.saving = true
		local rev, values = s.rev, s.values
		local ok, err = pcall(function()
			store:SetAsync(string.format(KEY, player.UserId), values)
		end)
		s.saving = false
		if ok then
			if s.rev == rev then s.dirty = false end   -- a push during the write stays dirty for the next one
		else
			warnOnce(err)             -- left dirty on purpose: the next autosave (or leave retry) tries again
		end
	end
	inFlight -= 1
end

local function onJoin(player)
	if state[player] then return end
	local s = { values = Settings.Sanitise(nil), dirty = false, lastPush = 0, rev = 0, loading = true }
	state[player] = s
	local ok, saved = load(player)
	if state[player] ~= s then return end          -- left while it loaded: nothing to keep (and no leaked entry)
	s.loading = false
	if ok then
		s.values = Settings.Sanitise(saved)
	else
		s.noSave = true                              -- defaults in memory; the real record is left alone
		warn(("[SettingsStore] %s's settings could not be loaded: defaults this session, nothing saved"):format(player.Name))
	end
	if player.Parent then
		remote:FireClient(player, s.values)
	end
end

Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end

-- (2026-10-19, audit P2-10) the leave save is RETRIED: once the entry is gone nothing else would try it again
Players.PlayerRemoving:Connect(function(player)
	local s = state[player]
	state[player] = nil
	if not s then return end
	inFlight += 1
	for try = 1, 3 do
		save(player, s)
		if not s.dirty or s.noSave or not store then break end
		if try < 3 then task.wait(2 * try) end
	end
	inFlight -= 1
end)

remote.OnServerEvent:Connect(function(player, what, payload)
	local s = state[player]
	if not s or s.loading then return end     -- the load's own reply carries the table (and the client re-pushes after it)
	if what == "request" then
		-- (2026-10-19, audit P1-07) a reply per request was a free reflector: over-rate requests are dropped (the
		-- client asks once per join; the load already answered it)
		local now = os.clock()
		if now - (s.lastRequest or 0) < REQUEST_GAP then return end
		s.lastRequest = now
		remote:FireClient(player, s.values)
	elseif what == "save" then
		local now = os.clock()
		if now - s.lastPush < MIN_GAP then return end       -- dropped, not queued: the next push is whole
		s.lastPush = now
		s.values = Settings.Sanitise(payload)
		s.rev += 1
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

-- (2026-10-19, audit P2-10) every save at once, then wait for them (and any leave saves still retrying) to finish,
-- bounded -- not a fixed 1 s that could cut queued writes off
game:BindToClose(function()
	for player, s in pairs(state) do
		task.spawn(save, player, s)
	end
	if not RunService:IsStudio() then
		local t0 = os.clock()
		while inFlight > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
	end
end)
