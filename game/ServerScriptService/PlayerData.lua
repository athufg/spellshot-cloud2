--[[
	PlayerData  (ModuleScript)  ->  ServerScriptService/PlayerData

	(2026-10-18, economy) The one place a player's progress is kept: their Sparks, the Elements they own, and the Robux
	purchases already paid out. ServerScriptService.EconomyService calls Start() once; every other server script only
	requires this module and calls the API. Every number lives in ReplicatedStorage.Spellshot.EconomyConfig.

	API
	  PlayerData.AwardMatch(player, result, roundsWon)  result "win" | "loss" | "draw"; returns the Sparks credited (0 if
	                                                       refused or there is no profile)
	  PlayerData.Owns(player, element)                   true / false. Before the save loads: the starter kit, never less
	  PlayerData.AddSparks(player, n, reason)            returns the new balance (nil if refused); never below 0
	  PlayerData.Unlock(player, element)                 grants an Element free (dev, events); true if newly owned
	  PlayerData.BuyElement(player, element)             THE SPARKS PATH: ok, code, info (EconomyService's remote)
	                                                       code "ok" | "owned" | "short" | "unknown" | "notforsale"
	                                                       | "loading" | "offline"; info = { Price, Sparks, Need }
	  PlayerData.Ready(player, timeout)                  yields until the save has loaded; true if it did
	  PlayerData.IsLoaded(player)
	  PlayerData.ResetToStarter(player)                  DEV: the starter kit and 0 Sparks (purchase records are kept,
	                                                       so no receipt can ever pay twice)
	  PlayerData.Start()                                 EconomyService only: joins, leaves, autosave, ProcessReceipt

	WHAT THE CLIENT SEES. Two player attributes, nothing else: "Sparks" (a number) and "OwnedElements" (the owned
	names, sorted, comma-separated), plus "DataLoaded" (true once the save is in). No table crosses a remote, so no map
	keyed by numbers can arrive with its keys turned into strings.

	THE SAVE. DataStore "SpellshotPlayerData", key "p_<UserId>_v1" (a new shape gets a new key and migrates from this):
	  { Version = 1, Sparks, Owned = { [element] = true }, Starter = { [element] = true },
	    Purchases = { [purchaseId] = { P = productId, S = sparks, T = os.time() } }, PurchaseLog = { purchaseId, ... },
	    Stats = { Wins, Losses, Draws, RoundsWon, Earned, Bought, Spent }, Created, Session = { Job, Token, T } | nil }
	  Starter is what the starter kit has ALREADY granted, per Element: a starter added to EconomyConfig later is given
	  to everyone once, and one removed is never taken back. Every map is keyed by strings.

	WRITES. Always UpdateAsync. Loaded on join (retries, each in a pcall), cached for the session, saved every AUTOSAVE
	seconds, on leaving and in BindToClose; an unlock and a Robux purchase save at once. One write per player at a time.

	THE SESSION LOCK. A save names the session holding it (Session.Token, one per profile; Session.Job too, for
	reading). A join that finds another session's fresh lock waits and tries again -- that server is still writing the
	player's last moments -- and takes it anyway on the last try, because a crashed server never lets go. A session that
	finds the lock not its own (taken, or released) stops writing that player, so a stale copy can never overwrite a
	newer one. (Studio never waits: it takes the lock on the first try.) Until 2026-10-19 the lock was the JobId, so a
	player rejoining the SAME server raced their own leave save (audit P2-01); a rejoin now waits for that save too.

	ROBUX. MarketplaceService.ProcessReceipt is set HERE and nowhere else. A receipt's PurchaseId is recorded in the
	player's save in the same write that pays the Sparks, so a retried receipt pays nothing; PurchaseGranted is returned
	only once that write has succeeded, otherwise NotProcessedYet and Roblox tries again. A product that is not a Sparks
	pack in EconomyConfig is left unprocessed (with a warning), never swallowed: any future product needs its own branch.

	STUDIO. With "Enable Studio Access to API Services" off the DataStore throws: this warns ONCE and the whole session
	runs in memory -- everything works, starting each Play from a new player's save, and nothing is written. A LIVE
	server that cannot load a save after every retry keeps the player on the starter kit with nothing saved, and pauses
	spending and Robux receipts for them, so nothing they pay for can be lost.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local folder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(folder:WaitForChild("SpellshotConfig"))
local Economy = require(folder:WaitForChild("EconomyConfig"))

local STORE_NAME = "SpellshotPlayerData"
-- 2026-10-23: Studio Play saves to its own test store (Config.Dev.StudioTestSave), never the real one; live is unchanged
if RunService:IsStudio() and Config.Dev.StudioTestSave ~= false then STORE_NAME = "SpellshotPlayerData_StudioTest" end
local KEY = "p_%d_v1"
local SCHEMA = 1
local AUTOSAVE = 60            -- seconds between background saves (each also refreshes the session lock)
local LOAD_TRIES = 5           -- tries at loading a save before giving up (live servers)
local LOCK_WAIT = 5            -- seconds between tries while another server still holds the save
local LOCK_STALE = 3 * AUTOSAVE -- a lock older than this belongs to a server that is gone
local PURCHASE_LOG_MAX = 200   -- receipts remembered per player (Roblox retries a receipt for days, not forever)
local NAME_MAX = 40            -- an Element name longer than this is junk, not a future Element

local PlayerData = {}

local profiles = {}            -- [player] = profile (see newProfile)
local store = nil
local memoryOnly = false       -- Studio without API access: every profile lives in memory only
local warned = false
local started = false

local function warnOnce(err)
	if warned then return end
	warned = true
	warn("[PlayerData] DataStore unavailable, Sparks and owned Elements will not persist this session (" ..
		tostring(err) .. "). In Studio this is Game Settings > Security > Enable Studio Access to API Services.")
end

----------------------------------------------------------------------------------------------------
-- the data
----------------------------------------------------------------------------------------------------
local function blank()
	return {
		Version = SCHEMA, Sparks = 0, Owned = {}, Starter = {}, Purchases = {}, PurchaseLog = {},
		Stats = { Wins = 0, Losses = 0, Draws = 0, RoundsWon = 0, Earned = 0, Bought = 0, Spent = 0 },
		Created = os.time(),
	}
end

local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = copy(v) end
	return c
end

--- A saved table (or nil) as a whole, valid current-shape one: every field present, every key a string.
--- (2026-10-19, audit P2-16) a top-level field (or a Stats counter) this build does not know is CARRIED THROUGH, not
--- dropped: a newer build may add one under the same key, and an older server still running would otherwise delete it
--- the moment that player joined it.
local function normalise(old)
	local d = blank()
	if type(old) ~= "table" then return d end
	d.Created = tonumber(old.Created) or d.Created
	d.Sparks = math.max(0, math.floor(tonumber(old.Sparks) or 0))
	for _, field in ipairs({ "Owned", "Starter" }) do
		if type(old[field]) == "table" then
			for k, v in pairs(old[field]) do
				if type(k) == "string" and v == true then d[field][k] = true end
			end
		end
	end
	if type(old.Purchases) == "table" then
		for k, v in pairs(old.Purchases) do
			if type(k) == "string" then d.Purchases[k] = v end
		end
	end
	if type(old.PurchaseLog) == "table" then
		for _, id in ipairs(old.PurchaseLog) do
			if type(id) == "string" and d.Purchases[id] then table.insert(d.PurchaseLog, id) end
		end
	end
	if type(old.Stats) == "table" then
		for k in pairs(d.Stats) do d.Stats[k] = tonumber(old.Stats[k]) or 0 end
		for k, v in pairs(old.Stats) do
			if type(k) == "string" and d.Stats[k] == nil then d.Stats[k] = copy(v) end
		end
	end
	for k, v in pairs(old) do
		if type(k) == "string" and d[k] == nil and k ~= "Session" then d[k] = copy(v) end
	end
	return d
end

--- (2026-10-19, audit P2-16) a record written by a NEWER schema than this server's: never normalised or written here.
local function tooNew(old)
	return type(old) == "table" and (tonumber(old.Version) or 0) > SCHEMA
end

--- The starter kit, once per Element. True if it gave anything.
local function grantStarters(data)
	local gave = false
	for _, name in ipairs(Economy.StarterElements) do
		if not data.Starter[name] then
			data.Starter[name] = true
			data.Owned[name] = true
			gave = true
		end
	end
	return gave
end

local function newProfile()
	return {
		-- (2026-10-19, audit P2-01 / P2-02) the lock's owner is THIS PROFILE, not this server: a player who rejoins the
		-- same server gets a new profile, and with a JobId lock the new load and the old leave save never saw each other
		token = HttpService:GenerateGUID(false),
		data = nil,            -- the save, once loaded
		loaded = false,
		persist = false,       -- false: memory only (Studio without API access)
		failed = false,        -- a live load that never succeeded: starters only, spending paused
		lost = false,          -- another server took the save: this one stops writing it
		dirty = false,
		saving = false,
		saveQueued = false,
		pending = { Sparks = 0, Owned = {} },   -- what arrived before the save did
	}
end

----------------------------------------------------------------------------------------------------
-- what the client sees
----------------------------------------------------------------------------------------------------
local function publish(player, prof)
	local names, sparks = {}, 0
	if prof.loaded then
		sparks = prof.data.Sparks
		for name in pairs(prof.data.Owned) do names[#names + 1] = name end
	else
		sparks = math.max(0, prof.pending.Sparks)
		local seen = {}
		for _, name in ipairs(Economy.StarterElements) do seen[name] = true; names[#names + 1] = name end
		for name in pairs(prof.pending.Owned) do
			if not seen[name] then names[#names + 1] = name end
		end
	end
	table.sort(names)
	player:SetAttribute("Sparks", sparks)
	player:SetAttribute("OwnedElements", table.concat(names, ","))
	player:SetAttribute("DataLoaded", prof.loaded)
end

----------------------------------------------------------------------------------------------------
-- load / save
----------------------------------------------------------------------------------------------------
local function keyOf(player)
	return string.format(KEY, player.UserId)
end

--- Whether a stored value is held by ANOTHER live session -- another server, or (2026-10-19, audit P2-01) an older
--- profile of the same player on THIS server whose leave save has not landed yet. A lock is a session token now; one
--- written before the token (Job only) is anyone else's until it goes stale, as a foreign server's always was.
local function heldElsewhere(old, token)
	if type(old) ~= "table" or type(old.Session) ~= "table" then return false end
	if old.Session.Token ~= nil and old.Session.Token == token then return false end
	return os.time() - (tonumber(old.Session.T) or 0) < LOCK_STALE
end

--- Returns data, mode: mode "store" (loaded and locked), "memory" (Studio without API access) or "failed".
local function loadData(player, prof)
	if memoryOnly then
		warnOnce("no DataStore")
		return blank(), "memory"
	end
	if not store then
		-- (2026-10-19, audit P2-04) a LIVE server without its store is a failed load, never memory-only: memory-only
		-- reported every save a success, so ProcessReceipt granted Robux packs that were never written. Ask again.
		local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
		store = ok and s or nil
		if not store then
			warn("[PlayerData] the DataStore is unavailable on this live server: " .. tostring(s))
			return nil, "failed"
		end
	end
	-- Studio takes the lock at once: every Play session has its own JobId, and a stopped one that did not let go would
	-- otherwise make the next Play wait LOCK_WAIT x LOAD_TRIES on the starter kit
	local force = RunService:IsStudio()
	for try = 1, LOAD_TRIES do
		if not player.Parent then return nil, "failed" end
		local claimed, held, newer = nil, false, false
		local ok, err = pcall(function()
			store:UpdateAsync(keyOf(player), function(old)
				claimed, held, newer = nil, false, false
				if tooNew(old) then
					newer = true
					return nil                        -- a newer build's record: this server leaves it untouched
				end
				if not force and heldElsewhere(old, prof.token) then
					held = true
					return nil                        -- leave it as it is: its server is still writing
				end
				local d = normalise(old)
				d.Session = { Job = game.JobId, Token = prof.token, T = os.time() }
				claimed = d
				return d
			end)
		end)
		if ok and claimed then
			claimed.Session = nil                     -- the lock lives in the store, not in the session's copy
			return claimed, "store"
		end
		if ok and newer then
			warn(("[PlayerData] %s's save is from a newer schema than this server's (%d): not loaded here"):format(player.Name, SCHEMA))
			return nil, "failed"
		end
		if ok and held then
			if try == LOAD_TRIES - 1 then force = true end   -- the last try takes it: a crashed server never lets go
			task.wait(LOCK_WAIT)
		elseif not ok then
			if RunService:IsStudio() then
				memoryOnly = true
				warnOnce(err)
				return blank(), "memory"
			end
			warn(("[PlayerData] loading %s failed (try %d of %d): %s"):format(player.Name, try, LOAD_TRIES, tostring(err)))
			task.wait(2 ^ try)
		end
	end
	return nil, "failed"
end

--- Writes the profile. True when the save holds everything the session had at the start of the write.
local function save(player, prof, releasing)
	if not prof.loaded then return false end
	if not prof.persist then
		prof.dirty = false
		return true                                    -- memory only: nothing to write, nothing lost
	end
	if prof.lost then return false end
	while prof.saving do task.wait(0.1) end            -- one write at a time; this one carries everything newer
	if prof.lost then return false end
	prof.saving = true
	prof.dirty = false                                 -- taken FIRST: a change during the write marks it dirty again
	local snapshot = copy(prof.data)
	local lostLock = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyOf(player), function(old)
			lostLock = false
			-- (2026-10-19, audit P2-01 / P2-02 / P2-03) ours only while it carries OUR token. Another session's token, or
			-- none (released -- by whoever took it, or by our own leave save, after which nothing of ours may write
			-- again or it re-locks the record for the next server), or no record at all: theirs now.
			if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Token ~= prof.token then
				lostLock = true
				return nil
			end
			local out = copy(snapshot)
			out.Session = (not releasing) and { Job = game.JobId, Token = prof.token, T = os.time() } or nil
			return out
		end)
	end)
	prof.saving = false
	if not ok then
		prof.dirty = true                              -- the next autosave tries again
		warn(("[PlayerData] saving %s failed: %s"):format(player.Name, tostring(err)))
		return false
	end
	if lostLock then
		prof.lost = true
		warn(("[PlayerData] %s's save is held by another server now; this server stops writing it"):format(player.Name))
		-- (2026-10-19, audit P2-13 / P2-14) say so, as a failed load does: nothing earned here is saved any more, and
		-- the shop must not prompt a Robux pack that ProcessReceipt can no longer pay
		if player.Parent and profiles[player] == prof then player:SetAttribute("DataError", true) end
		return false
	end
	return true
end

--- Saves still running for a player who has left, and loads still in flight (the 2026-10-18 review): BindToClose waits on
--- these as well as on the players still here, so a server closing on its last player's leave does not cut that write off.
local releasing = {}       -- [prof] = true
local releasingUser = {}   -- [UserId] = the profile whose leave save is still running (2026-10-19, audit P2-01)

--- The leave save, RETRIED: once a profile is out of `profiles` nothing else would ever try it again, so a write that
--- fails once (a throttle, a blip) goes again at 1, 2, 4 and 8 s while the lock is still this server's.
local function release(player, prof)
	releasing[prof] = true
	releasingUser[player.UserId] = prof
	local ok = save(player, prof, true)
	for _, delay in ipairs({ 1, 2, 4, 8 }) do
		if ok or prof.lost or not prof.loaded then break end
		task.wait(delay)
		ok = save(player, prof, true)
	end
	if not ok and not prof.lost and prof.loaded then
		warn(("[PlayerData] gave up on %s's leave save"):format(player.Name))
	end
	releasing[prof] = nil
	if releasingUser[player.UserId] == prof then releasingUser[player.UserId] = nil end
end

--- A save on the next resumption point, coalesced: several changes in one moment (UNLOCK ALL) are one write.
local function saveSoon(player, prof)
	if prof.saveQueued then return end
	prof.saveQueued = true
	task.defer(function()
		prof.saveQueued = false
		save(player, prof)
	end)
end

----------------------------------------------------------------------------------------------------
-- joins and leaves
----------------------------------------------------------------------------------------------------
local function onJoin(player)
	if profiles[player] then return end
	local prof = newProfile()
	profiles[player] = prof
	publish(player, prof)                              -- the starter kit at once: nobody waits on a DataStore to play
	releasing[prof] = true                             -- a load in flight holds a shutdown too (it may take the lock)
	-- (2026-10-19, audit P2-01) back on the SAME server before the last visit's leave save landed: wait for it (it is
	-- retried for at most ~15 s), so this load reads what that session wrote rather than racing it
	local waitFrom = os.clock()
	while releasingUser[player.UserId] and player.Parent and os.clock() - waitFrom < 30 do task.wait(0.2) end
	local data, mode = loadData(player, prof)
	releasing[prof] = nil
	if mode == "failed" then
		prof.failed = true
		if profiles[player] == prof then
			warn(("[PlayerData] %s's save could not be loaded: starter kit only, nothing saved, spending paused"):format(player.Name))
			player:SetAttribute("DataError", true)
		end
		return
	end
	prof.data, prof.loaded, prof.persist = data, true, (mode == "store")
	-- what arrived before the save did
	if prof.pending.Sparks ~= 0 then
		data.Sparks = math.max(0, data.Sparks + prof.pending.Sparks)
		prof.dirty = true
	end
	for name in pairs(prof.pending.Owned) do
		if not data.Owned[name] then data.Owned[name] = true; prof.dirty = true end
	end
	prof.pending = { Sparks = 0, Owned = {} }
	if grantStarters(data) then prof.dirty = true end
	if profiles[player] ~= prof then
		release(player, prof)                          -- left while it loaded: write it back and let go of the lock
		return
	end
	publish(player, prof)
end

local function onLeave(player)
	local prof = profiles[player]
	if not prof then return end
	profiles[player] = nil
	if prof.loaded then task.spawn(release, player, prof) end   -- (still loading: onJoin writes it back when the load returns)
end

----------------------------------------------------------------------------------------------------
-- Robux
----------------------------------------------------------------------------------------------------
local function processReceipt(info)
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	local pack = Economy.PackByProductId(info.ProductId)
	if not pack then
		warn(("[PlayerData] receipt for product %s, which is not a Sparks pack in EconomyConfig: left unprocessed")
			:format(tostring(info.ProductId)))
		return NOT_YET
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return NOT_YET end              -- Roblox tries again on their next join
	if not PlayerData.Ready(player, 30) then return NOT_YET end
	local prof = profiles[player]
	if not prof or not prof.loaded or prof.lost then return NOT_YET end
	local id = tostring(info.PurchaseId)
	local data = prof.data
	if not data.Purchases[id] then                     -- the first time this receipt is seen: pay it, and remember it
		data.Purchases[id] = { P = info.ProductId, S = pack.Sparks, T = os.time() }
		table.insert(data.PurchaseLog, id)
		while #data.PurchaseLog > PURCHASE_LOG_MAX do
			data.Purchases[table.remove(data.PurchaseLog, 1)] = nil
		end
		data.Sparks += pack.Sparks
		data.Stats.Bought += pack.Sparks
		prof.dirty = true
		publish(player, prof)
	end
	-- granted only once the payment AND its PurchaseId are in the store; a retry finds the id and only saves
	if save(player, prof) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	return NOT_YET
end

----------------------------------------------------------------------------------------------------
-- API
----------------------------------------------------------------------------------------------------
local function isPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player")
end

local function validName(element)
	return type(element) == "string" and #element > 0 and #element <= NAME_MAX and not element:find("[^%w_]")
end

function PlayerData.IsLoaded(player)
	local prof = profiles[player]
	return prof ~= nil and prof.loaded
end

function PlayerData.Ready(player, timeout)
	local t0 = os.clock()
	while isPlayer(player) and player.Parent do
		local prof = profiles[player]
		if prof and prof.loaded then return true end
		if prof and prof.failed then return false end
		if timeout and os.clock() - t0 >= timeout then return false end
		task.wait(0.1)
	end
	return false
end

function PlayerData.Owns(player, element)
	if not validName(element) then return false end
	local prof = profiles[player]
	if prof and prof.loaded then return prof.data.Owned[element] == true end
	-- not loaded yet (or never will be): the starter kit, never less
	return Economy.IsStarter(element) or (prof ~= nil and prof.pending.Owned[element] == true)
end

function PlayerData.AddSparks(player, n, reason)
	n = math.floor(tonumber(n) or 0)
	local prof = isPlayer(player) and profiles[player]
	if not prof then return nil end
	if prof.loaded then
		local data = prof.data
		local before = data.Sparks
		data.Sparks = math.max(0, before + n)
		if reason == "match" and n > 0 then data.Stats.Earned += n end
		if data.Sparks ~= before then prof.dirty = true end
		publish(player, prof)
		return data.Sparks
	end
	-- before the save arrives (or when it never will): held, and added to it when it loads
	prof.pending.Sparks += n
	publish(player, prof)
	return math.max(0, prof.pending.Sparks)
end

function PlayerData.AwardMatch(player, result, roundsWon)
	local amount = Economy.MatchSparks(result, roundsWon)
	if not amount or not isPlayer(player) then
		warn(("[PlayerData] AwardMatch refused: player %s, result %s"):format(tostring(player), tostring(result)))
		return 0
	end
	local prof = profiles[player]
	if prof and prof.loaded then
		local st = prof.data.Stats
		if result == "win" then st.Wins += 1 elseif result == "loss" then st.Losses += 1 else st.Draws += 1 end
		st.RoundsWon += math.clamp(math.floor(tonumber(roundsWon) or 0), 0, Economy.MaxRoundsCounted)
	end
	-- (2026-10-19, audit P2-14) the Sparks actually credited: 0 when there was no profile to credit (AddSparks nil).
	-- A failed or lost profile is still credited for this session (the balance shows it), but nothing of it is saved:
	-- the player's DataError attribute says so.
	if PlayerData.AddSparks(player, amount, "match") == nil then return 0 end
	-- written now, not at the next autosave (2026-10-18 review): a player who quits on the result screen keeps it
	if prof and prof.loaded then saveSoon(player, prof) end
	return amount
end

function PlayerData.Unlock(player, element)
	if not validName(element) then return false end
	local prof = isPlayer(player) and profiles[player]
	if not prof then return false end
	if prof.loaded then
		if prof.data.Owned[element] then return false end
		prof.data.Owned[element] = true
		prof.dirty = true
		publish(player, prof)
		saveSoon(player, prof)
		return true
	end
	if Economy.IsStarter(element) or prof.pending.Owned[element] then return false end
	prof.pending.Owned[element] = true
	publish(player, prof)
	return true
end

function PlayerData.BuyElement(player, element)
	if type(element) ~= "string" or not Config.Elements[element] or not Config.IsBuilt(element) then
		return false, "unknown"
	end
	local prof = isPlayer(player) and profiles[player]
	if not prof or prof.failed or prof.lost then return false, "offline" end
	if not prof.loaded then return false, "loading" end
	local data = prof.data
	if data.Owned[element] then return false, "owned" end
	local price = Economy.PriceOf(element)
	if not price then return false, "notforsale" end
	if data.Sparks < price then
		return false, "short", { Price = price, Sparks = data.Sparks, Need = price - data.Sparks }
	end
	data.Sparks -= price
	data.Owned[element] = true
	data.Stats.Spent += price
	prof.dirty = true
	publish(player, prof)
	saveSoon(player, prof)                             -- saved now; a failed write is retried by the autosave
	return true, "ok", { Price = price, Sparks = data.Sparks, Need = 0 }
end

function PlayerData.ResetToStarter(player)
	local prof = isPlayer(player) and profiles[player]
	if not prof or not prof.loaded then return false end
	local data = prof.data
	data.Owned, data.Starter, data.Sparks = {}, {}, 0
	grantStarters(data)
	prof.dirty = true
	publish(player, prof)
	saveSoon(player, prof)
	return true
end

function PlayerData.Start()
	if started then return end
	started = true
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and s or nil
	-- memory-only is Studio's answer alone (2026-10-19, audit P2-04): a live server without its store fails each load
	-- instead (loadData asks again), which pauses spending and receipts rather than granting what is never saved
	if not store and RunService:IsStudio() then
		memoryOnly = true
		warnOnce(s)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
	MarketplaceService.ProcessReceipt = processReceipt
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			-- (2026-10-19, audit P2-17) not while a write is still running: during an outage each tick used to add one more
			-- waiter, and they all wrote back to back when the store recovered. The running write refreshes the lock.
			for player, prof in pairs(profiles) do
				if prof.loaded and player.Parent and not prof.saving then task.spawn(save, player, prof) end
			end
		end
	end)
	game:BindToClose(function()
		local open = 0
		for player, prof in pairs(profiles) do
			open += 1
			task.spawn(function()
				save(player, prof, true)
				open -= 1
			end)
		end
		local t0 = os.clock()
		while (open > 0 or next(releasing) ~= nil) and os.clock() - t0 < 25 do task.wait(0.1) end
	end)
end

return PlayerData
