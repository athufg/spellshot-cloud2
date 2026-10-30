--[[
	Matchmaker  (ModuleScript)  ->  ServerScriptService/Matchmaker

	QUICK PLAY ACROSS EVERY SERVER (2026-10-28, the owner: "it should be matches from all server (preferring same region
	server but still if not found then any server to server)", and their pick of SEPARATE MATCH SERVERS). HubServer still
	owns the Hub, the map vote and the team match; this module owns the queue between servers and a match server's life.
	Config.Matchmaking holds the knobs; Mode = "Local" there puts Quick Play back on HubServer's own one-server queue.

	ONE QUEUE  QUEUE writes a TICKET into a MemoryStore sorted map every server shares (key = the player's UserId):
	           UserId, Origin (this server), Region, EnqueuedAt, State, TicketId. A ticket lives TicketTTL seconds; its
	           own server refreshes it every RefreshEvery while the player is still queued here, so a crashed server leaves
	           nothing behind. CANCEL, leaving the game, and going into a vote, a pad duel or a solo test remove it.
	REGIONS    the player's country (LocalizationService), through Config.Matchmaking.Regions, to one of about six regions.
	           A ticket matches only its own region until it has waited WidenAfter seconds; from then on it also matches
	           any other ticket that has waited that long. Oldest first; a ticket's own region is tried before the rest.
	ONE MATCHMAKER  every PollEvery seconds each server with someone queued asks for a lock that expires (LockTTL). The
	           holder reads every ticket, picks groups of 2 x Config.Team.Size (Select, below) and CLAIMS each ticket with
	           UpdateAsync, which only takes a ticket that is still "Queued". So two servers can never put one player into
	           two matches, even if both think they hold the lock. A claim that fails part-way releases what it took.
	A MATCH    all of its players in this server (always so in Studio): it runs here, as the one-server queue did. Otherwise
	           ReserveServerAsync, a match RECORD in MemoryStore (RecordTTL), one MessagingService message ({Id, Users}),
	           and every origin server teleports its own players there (TeleportData = { MatchId }), showing MATCH FOUND
	           then TELEPORTING. A teleport that fails puts that player back at the front of the queue (their old time).
	           The lock holder writes the queue's counts into the lock, so every server can show "n/6" for nothing extra.
	A MATCH SERVER  a reserved server nobody owns (PrivateServerId set, PrivateServerOwnerId 0). It reads its record (the
	           MatchId in a joining player's TeleportData, checked against the record's PrivateServerId), waits up to
	           ArriveTimeout for the players (WAITING FOR PLAYERS n/6), then HubServer runs the map vote and the team match
	           with the record's teams. Anyone not in the record goes to a public server. Too few (MinPerTeam a team, at
	           most Team.Size) and it is called off. When the match ends, everyone goes back to a public server
	           (RETURNING TO HUB). QUEUE and the duel pads are off in a match server.
	STUDIO     teleports do not work in Studio: a match whose players are all in this server runs here; one that is not is
	           released and logged. The workspace attribute "MM_SimulateMatchServer" (Studio only; set it true in Play) makes
	           this server a match server with a record built from the players present; its last step, the trip home, is
	           logged instead of teleported. Studio uses its own MemoryStore names ("_Studio") so it never meets live tickets.

	HubServer's hooks (Init): Notify, Dequeued, Requeued, QueueCount, CanGo, IsMoving, StartLocal, StartMatch, Holds.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotConfig"))

local MM = {}

local IS_STUDIO = RunService:IsStudio()
local SERVER_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. HttpService:GenerateGUID(false))
local SIM_ATTR = "MM_SimulateMatchServer"
local LOCK_KEY = "matchmaker"
local CLAIM_STALE = 20          -- a ticket claimed this long ago with no match in sight is checked (and released)
local CANCEL_TTL = 15           -- how long a cancelled ticket's tombstone stays if its removal fails
MM.ServerId = SERVER_ID

local function cfg(name, default)
	local c = Config.Matchmaking
	local v = c and c[name]
	if v == nil then return default end
	return v
end

local function now()
	return DateTime.now().UnixTimestampMillis / 1000
end

local function need()
	return 2 * math.max(1, math.floor((Config.Team and Config.Team.Size) or 3))
end

----------------------------------------------------------------------------------------------------
-- regions
----------------------------------------------------------------------------------------------------
local countryToRegion = nil

--- A country code ("US") to its matchmaking region ("NA"); an unknown one to Config.Matchmaking.DefaultRegion.
function MM.RegionOfCountry(code)
	if not countryToRegion then
		countryToRegion = {}
		for region, list in pairs(cfg("Regions", {})) do
			for _, cc in ipairs(list) do countryToRegion[string.upper(cc)] = region end
		end
	end
	return countryToRegion[string.upper(tostring(code or ""))] or cfg("DefaultRegion", "OT")
end

local regionOf = setmetatable({}, { __mode = "k" })
local function lookupRegion(p)
	-- Studio only: a test may give a player a region with the "MMRegion" attribute
	if IS_STUDIO and type(p:GetAttribute("MMRegion")) == "string" then return p:GetAttribute("MMRegion") end
	if regionOf[p] then return regionOf[p] end
	local ok, code = pcall(function()
		return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(p)
	end)
	local region = MM.RegionOfCountry(ok and code or nil)
	regionOf[p] = region
	return region
end

----------------------------------------------------------------------------------------------------
-- choosing matches (pure: the harness runs it as it is)
----------------------------------------------------------------------------------------------------
--- `tickets`: { UserId, Region, EnqueuedAt, State, ... } in any order. Returns groups of `size` tickets, each one's tickets
--- able to play together: a ticket that has waited less than `widenAfter` seconds only with its own region, two that have
--- both waited that long whatever their regions. The oldest ticket that can make a group anchors it, its own region first.
function MM.Select(tickets, at, size, widenAfter)
	local list = {}
	for _, t in ipairs(tickets) do
		if t.State == "Queued" and type(t.EnqueuedAt) == "number" then list[#list + 1] = t end
	end
	table.sort(list, function(a, b)
		if a.EnqueuedAt ~= b.EnqueuedAt then return a.EnqueuedAt < b.EnqueuedAt end
		return (a.UserId or 0) < (b.UserId or 0)
	end)
	local function wide(t) return at - t.EnqueuedAt >= widenAfter end
	local used, groups = {}, {}
	for _, anchor in ipairs(list) do
		if not used[anchor] then
			local group = { anchor }
			for _, t in ipairs(list) do
				if #group == size then break end
				if t ~= anchor and not used[t] and t.Region == anchor.Region then group[#group + 1] = t end
			end
			if #group < size and wide(anchor) then
				group = { anchor }
				for _, t in ipairs(list) do
					if #group == size then break end
					if t ~= anchor and not used[t] and wide(t) then group[#group + 1] = t end
				end
			end
			if #group == size then
				for _, t in ipairs(group) do used[t] = true end
				groups[#groups + 1] = group
			end
		end
	end
	return groups
end

--- How many queued tickets a player in `region` could be matched with now (their own included): the region's, and once
--- they have widened, every other region's widened ones too. `counts` is the lock's { R = {region = n}, W = {...} }.
function MM.PoolFor(counts, region, widened)
	if type(counts) ~= "table" then return nil end
	local n = (counts.R and counts.R[region]) or 0
	if widened and counts.W then
		for r, w in pairs(counts.W) do
			if r ~= region then n += w end
		end
	end
	return n
end

----------------------------------------------------------------------------------------------------
-- the stores
----------------------------------------------------------------------------------------------------
local stores = nil
local function S()
	if not stores then
		local MemoryStoreService = game:GetService("MemoryStoreService")
		local base = cfg("Store", "SPELLSHOT_MM_v1") .. (IS_STUDIO and "_Studio" or "")
		stores = {
			Tickets = MemoryStoreService:GetSortedMap(base .. "_Tickets"),
			Lock = MemoryStoreService:GetSortedMap(base .. "_Lock"),
			Matches = MemoryStoreService:GetSortedMap(base .. "_Matches"),
			Topic = base,
		}
	end
	return stores
end

--- Every ticket in the map (up to 1000), each with its Key.
local function readTickets()
	local all, last = {}, nil
	for _ = 1, 5 do
		local items = S().Tickets:GetRangeAsync(Enum.SortDirection.Ascending, 200, last)
		for _, item in ipairs(items) do
			if type(item.value) == "table" then
				item.value.Key = item.key
				all[#all + 1] = item.value
			end
			last = item.key
		end
		if #items < 200 then break end
	end
	return all
end

--- Claims ticket `t` for `matchId` if it is still the same ticket and still "Queued". true when it is ours.
local function claim(t, matchId)
	local ok, res = pcall(function()
		return S().Tickets:UpdateAsync(t.Key, function(v)
			if type(v) == "table" and v.State == "Queued" and v.TicketId == t.TicketId then
				v.State, v.MatchId, v.ClaimedBy, v.ClaimedAt = "Claimed", matchId, SERVER_ID, now()
				return v
			end
			return nil
		end, cfg("TicketTTL", 120))
	end)
	return ok and type(res) == "table" and res.MatchId == matchId
end

--- Gives back a ticket claimed for `matchId`: "Queued" again with its old time -- or "Cancelled" if its player cancelled
--- while it was claimed.
local function release(key, matchId)
	for attempt = 1, 2 do
		local ok, err = pcall(function()
			S().Tickets:UpdateAsync(key, function(v)
				if type(v) == "table" and v.State == "Claimed" and v.MatchId == matchId then
					if v.CancelRequested then
						v.State = "Cancelled"
					else
						v.State, v.MatchId, v.ClaimedBy, v.ClaimedAt = "Queued", nil, nil, nil
					end
					return v
				end
				return nil
			end, cfg("TicketTTL", 120))
		end)
		if ok then return end
		-- still claimed: its own server puts it back once the claim is CLAIM_STALE old (refresh)
		if attempt == 2 then warn("[Matchmaker] could not release ticket " .. key .. ": " .. tostring(err)) end
	end
end

----------------------------------------------------------------------------------------------------
-- this server's queued players (a public server in Global mode)
----------------------------------------------------------------------------------------------------
local hooks = nil
local matchServer = false
local entries = {}                                          -- [player] = { TicketId, EnqueuedAt, Region, State, ... }
local teleporting = setmetatable({}, { __mode = "k" })     -- [player] = { MatchId, EnqueuedAt }
local lastTime = setmetatable({}, { __mode = "k" })        -- [player] = their last EnqueuedAt (for "front of the queue")
local handled = {}                                          -- [matchId] = true once this server acted on it
local busy = {}                                             -- [userId] = true while a store call for them runs
local lastCounts, seenCounts = nil, nil
local crossBackoff = 0

function MM.IsMatchServer() return matchServer end
function MM.Global() return cfg("Mode", "Local") == "Global" and not matchServer end
--- A player the Hub's pads must leave alone: on the way to a match, or anyone in a match server.
function MM.Busy(p) return matchServer or teleporting[p] ~= nil end

--- One store call at a time per player, so a CANCEL and the QUEUE after it land in that order.
local function serial(userId, fn)
	local t0 = os.clock()
	while busy[userId] and os.clock() - t0 < 10 do task.wait(0.05) end
	busy[userId] = true
	local ok, err = pcall(fn)
	busy[userId] = nil
	if not ok then warn("[Matchmaker] " .. tostring(err)) end
end

local function ticketValue(p, e)
	return {
		UserId = p.UserId, Name = p.Name, Origin = SERVER_ID, Region = e.Region, EnqueuedAt = e.EnqueuedAt,
		State = "Queued", TicketId = e.TicketId,
	}
end

--- Atomically takes ticket `ticketId` out of play. "cancelled" (it was queued, or already gone), "claimed" (a match is
--- being formed with it: it is marked CancelRequested, so a claim that is released cancels it), or "error".
local function cancelTicket(userId, ticketId)
	local outcome = "error"
	local ok = pcall(function()
		S().Tickets:UpdateAsync(tostring(userId), function(v)
			if type(v) ~= "table" or v.TicketId ~= ticketId or v.State == "Cancelled" then
				outcome = "cancelled"
				return nil
			end
			if v.State == "Claimed" then
				outcome = "claimed"
				v.CancelRequested = true
				return v
			end
			outcome = "cancelled"
			v.State = "Cancelled"
			return v
		end, CANCEL_TTL)
	end)
	if not ok then return "error" end
	if outcome == "cancelled" then
		-- the tombstone has done its job (nothing can claim it); remove it so the map holds live tickets only
		pcall(function()
			local v = S().Tickets:GetAsync(tostring(userId))
			if type(v) == "table" and v.TicketId == ticketId and v.State == "Cancelled" then
				S().Tickets:RemoveAsync(tostring(userId))
			end
		end)
	end
	return outcome
end

local function writeTicket(p, e)
	local ok, err = pcall(function()
		S().Tickets:SetAsync(tostring(p.UserId), ticketValue(p, e), cfg("TicketTTL", 120))
	end)
	if not ok then warn("[Matchmaker] could not write " .. p.Name .. "'s ticket: " .. tostring(err)) end
	return ok
end

--- QUEUE in Global mode: a ticket every server can match. `keepTime` keeps an earlier place in line (a teleport that
--- failed, a vote that was called off). Yields. Tells the player only when something went wrong.
function MM.Enqueue(p, keepTime)
	if teleporting[p] then
		hooks.Dequeued(p, "You are on your way to a match.")
		return false
	end
	local e = entries[p]
	if e then
		if e.State == "CancelPending" then e.State = "Queued" end      -- queued again before a late cancel settled
		return true
	end
	e = { TicketId = HttpService:GenerateGUID(false), EnqueuedAt = keepTime or now(), State = "Queued", LastRefresh = now() }
	entries[p] = e
	lastTime[p] = e.EnqueuedAt
	e.Region = lookupRegion(p)
	if entries[p] ~= e then return false end           -- cancelled while the region was looked up
	local wrote = false
	serial(p.UserId, function()
		if entries[p] == e then wrote = writeTicket(p, e) end
	end)
	if entries[p] ~= e then return false end
	if not wrote then
		entries[p] = nil
		hooks.Dequeued(p, "Matchmaking is not answering right now -- try QUEUE again in a moment.")
		return false
	end
	print(("[Matchmaker] %s queued: ticket %s, region %s"):format(p.Name, e.TicketId, e.Region))
	e.Shown = 1
	hooks.QueueCount(p, 1, need())
	return true
end

--- Back into the queue at their old place (HubServer: a vote that was called off).
function MM.Requeue(p)
	return MM.Enqueue(p, lastTime[p])
end

--- Out of the global queue. `why` = "cancel" for the player's own CANCEL: if a match has already claimed the ticket, it
--- is too late, and they are told so (the match goes ahead, unless its claim falls through). true if they were queued.
function MM.Remove(p, why)
	local e = entries[p]
	if not e then return false end
	entries[p] = nil
	local userId = p.UserId
	task.spawn(serial, userId, function()
		local outcome = cancelTicket(userId, e.TicketId)
		print(("[Matchmaker] %s left the queue (%s): %s"):format(p.Name, tostring(why or "removed"), outcome))
		if outcome == "claimed" and why == "cancel" and p.Parent and entries[p] == nil and not teleporting[p] then
			e.State = "CancelPending"
			entries[p] = e
			hooks.Requeued(p, "A match was already found for you -- hold on.")
		end
	end)
	return true
end

----------------------------------------------------------------------------------------------------
-- a match found: this server's own players go
----------------------------------------------------------------------------------------------------
local function teleportFailed(p, why)
	local t = teleporting[p]
	if not t then return end
	teleporting[p] = nil
	warn(("[Matchmaker] teleport failed for %s: %s"):format(p.Name, tostring(why)))
	if not p.Parent then return end
	hooks.Requeued(p, "The teleport failed -- you are back at the front of the queue.")
	task.spawn(MM.Enqueue, p, t.EnqueuedAt)
end

--- Match `matchId` holds `userIds`: this server's queued ones among them are told MATCH FOUND, then TELEPORTING, and go.
local function onMatch(matchId, userIds, record)
	if handled[matchId] then return end
	local mine = {}
	for _, uid in ipairs(userIds) do
		local p = Players:GetPlayerByUserId(uid)
		if p and entries[p] then mine[#mine + 1] = p end
	end
	if #mine == 0 then return end
	handled[matchId] = true
	if not record then
		local ok, rec = pcall(function() return S().Matches:GetAsync(matchId) end)
		record = ok and type(rec) == "table" and rec or nil
		if not record then
			warn("[Matchmaker] match " .. matchId .. " has no record; its players stay queued")
			handled[matchId] = nil
			return
		end
	end
	local going = {}
	for _, p in ipairs(mine) do
		local e = entries[p]           -- (looked at again: the record read above yields)
		if e and p.Parent then
			entries[p] = nil
			teleporting[p] = { MatchId = matchId, EnqueuedAt = e.EnqueuedAt }
			task.spawn(serial, p.UserId, function() S().Tickets:RemoveAsync(tostring(p.UserId)) end)
			hooks.Dequeued(p, "MATCH FOUND")
			going[#going + 1] = p
		end
	end
	mine = going
	task.wait(1.5)
	local go = {}
	for _, p in ipairs(mine) do
		if p.Parent and teleporting[p] and teleporting[p].MatchId == matchId then
			hooks.Notify(p, "TELEPORTING...")
			go[#go + 1] = p
		end
	end
	if #go == 0 then return end
	local TeleportService = game:GetService("TeleportService")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.AccessCode
	options:SetTeleportData({ MatchId = matchId })
	print(("[Matchmaker] match %s: teleporting %d player(s) from this server"):format(matchId, #go))
	local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, go, options) end)
	if not ok then
		for _, p in ipairs(go) do teleportFailed(p, err) end
		return
	end
	-- a teleport that neither fails nor leaves is a failure too
	task.delay(30, function()
		for _, p in ipairs(go) do
			if p.Parent and teleporting[p] and teleporting[p].MatchId == matchId then teleportFailed(p, "timed out") end
		end
	end)
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

--- The lock holder turns one selected group into a match. false if it fell through (everything claimed is released).
local function formMatch(group)
	local matchId = HttpService:GenerateGUID(false)
	local claimed = {}
	local function giveBack()
		for _, t in ipairs(claimed) do release(t.Key, matchId) end
	end
	for _, t in ipairs(group) do
		if claim(t, matchId) then
			claimed[#claimed + 1] = t
		else
			giveBack()
			return false
		end
	end
	shuffle(claimed)        -- teams drawn at random, as the one-server queue drew them: first half against second half
	local local_ = true
	for _, t in ipairs(claimed) do
		if t.Origin ~= SERVER_ID then local_ = false end
	end
	if local_ then
		-- everyone is in this server: no teleport, the match runs here
		local players = {}
		for i, t in ipairs(claimed) do
			local p = Players:GetPlayerByUserId(t.UserId)
			local e = p and entries[p]
			if not (e and e.TicketId == t.TicketId and hooks.CanGo(p)) then
				giveBack()
				return false
			end
			players[i] = p
		end
		for _, p in ipairs(players) do
			entries[p] = nil
			task.spawn(serial, p.UserId, function() S().Tickets:RemoveAsync(tostring(p.UserId)) end)
			hooks.Dequeued(p, "MATCH FOUND")
		end
		print(("[Matchmaker] match %s: all %d players are in this server, so it runs here"):format(matchId, #players))
		hooks.StartLocal(players)
		return true
	end
	if IS_STUDIO then
		warn("[Matchmaker] a match across servers can't teleport in Studio; released (Studio stays one-server)")
		crossBackoff = now() + 30
		giveBack()
		return false
	end
	local half = #claimed // 2
	local teams, users, region = { {}, {} }, {}, claimed[1].Region
	for i, t in ipairs(claimed) do
		table.insert(teams[(i <= half) and 1 or 2], t.UserId)
		users[#users + 1] = t.UserId
		if t.Region ~= region then region = "MIXED" end
	end
	local TeleportService = game:GetService("TeleportService")
	local okR, code, privateId = pcall(function() return TeleportService:ReserveServerAsync(game.PlaceId) end)
	if not okR or type(code) ~= "string" then
		warn("[Matchmaker] ReserveServerAsync failed: " .. tostring(code))
		crossBackoff = now() + 10          -- cross-server matches wait a little; one-server ones carry on
		giveBack()
		return false
	end
	local record = {
		MatchId = matchId, Teams = teams, Region = region, AccessCode = code, PrivateServerId = privateId,
		Created = now(),
	}
	local okW, errW = pcall(function() S().Matches:SetAsync(matchId, record, cfg("RecordTTL", 900)) end)
	if not okW then
		warn("[Matchmaker] could not write match " .. matchId .. ": " .. tostring(errW))
		crossBackoff = now() + 10
		giveBack()
		return false
	end
	print(("[Matchmaker] match %s formed: %d players, region %s"):format(matchId, #users, region))
	local okP, errP = pcall(function()
		game:GetService("MessagingService"):PublishAsync(S().Topic, { Id = matchId, Users = users })
	end)
	if not okP then warn("[Matchmaker] PublishAsync failed (origins find it on their next refresh): " .. tostring(errP)) end
	task.spawn(onMatch, matchId, users, record)
	return true
end

--- The holder's turn: read every ticket, count them for everyone's "n/6", and form what can be formed.
local function matchmake()
	local tickets = readTickets()
	local at = now()
	local widen = cfg("WidenAfter", 20)
	local counts = { R = {}, W = {} }
	local eligible = {}
	for _, t in ipairs(tickets) do
		if t.State == "Queued" and type(t.EnqueuedAt) == "number" and t.Region then
			counts.R[t.Region] = (counts.R[t.Region] or 0) + 1
			if at - t.EnqueuedAt >= widen then counts.W[t.Region] = (counts.W[t.Region] or 0) + 1 end
			local go = true
			if t.Origin == SERVER_ID then
				-- this server's own: only a player who is still here, still queued and free to go right now
				local p = Players:GetPlayerByUserId(t.UserId)
				local e = p and entries[p]
				go = e ~= nil and e.State == "Queued" and e.TicketId == t.TicketId and hooks.CanGo(p)
			elseif at < crossBackoff then
				go = false                  -- another server's player, while cross-server matches back off
			end
			if go then eligible[#eligible + 1] = t end
		end
	end
	lastCounts = counts
	for _, group in ipairs(MM.Select(eligible, at, need(), widen)) do
		formMatch(group)
	end
end

--- Asks for the lock (or keeps it). Returns whether this server holds it; what the lock showed goes to seenCounts.
local function tryLock()
	local at = now()
	local seen = nil
	local ok, res = pcall(function()
		return S().Lock:UpdateAsync(LOCK_KEY, function(v)
			seen = (type(v) == "table") and v.Counts or nil
			if type(v) ~= "table" or (v.Until or 0) < at or v.Holder == SERVER_ID then
				return { Holder = SERVER_ID, Until = at + cfg("LockTTL", 6), Counts = lastCounts or seen }
			end
			return nil
		end, cfg("LockTTL", 6) + 2)
	end)
	seenCounts = seen
	local held = ok and type(res) == "table" and res.Holder == SERVER_ID
	if held then seenCounts = lastCounts or seen end
	return held
end

--- Keeps a queued player's ticket alive, and notices what happened to it: gone (written again), cancelled (a late
--- cancel settled), or claimed long ago with no match arriving (the record is looked up; no record releases it).
local function refresh(p, e)
	if e.Refreshing then return end
	e.Refreshing = true
	e.LastRefresh = now()
	local ok, err = pcall(function()
		local seen = nil
		serial(p.UserId, function()
			S().Tickets:UpdateAsync(tostring(p.UserId), function(v)
				seen = v
				if type(v) == "table" and v.TicketId == e.TicketId and v.State == "Queued" and e.State == "Queued" then
					return v
				end
				return nil
			end, cfg("TicketTTL", 120))
		end)
		if entries[p] ~= e then return end
		local mineNow = type(seen) == "table" and seen.TicketId == e.TicketId
		if not mineNow or seen.State == "Cancelled" then
			if e.State == "CancelPending" then
				entries[p] = nil
				hooks.Dequeued(p, "Queue cancelled.")
			else
				-- lost (it expired, or a stale claim was cleared away): written again, keeping its place in line
				serial(p.UserId, function()
					if entries[p] == e then writeTicket(p, e) end
				end)
			end
		elseif seen.State == "Queued" and e.State == "CancelPending" then
			task.spawn(MM.Remove, p, "cancel")
		elseif seen.State == "Claimed" and now() - (seen.ClaimedAt or now()) > CLAIM_STALE then
			local matchId = seen.MatchId
			local okG, rec = pcall(function() return S().Matches:GetAsync(matchId) end)
			if okG and type(rec) == "table" then
				local users = {}
				for _, team in ipairs(rec.Teams or {}) do
					for _, uid in ipairs(team) do users[#users + 1] = uid end
				end
				task.spawn(onMatch, matchId, users, rec)
			elseif okG then
				-- its matchmaker went away part-way: the ticket is put back (or cancelled, if its player asked)
				serial(p.UserId, function() release(tostring(p.UserId), matchId) end)
			end
		end
	end)
	e.Refreshing = nil
	if not ok then warn("[Matchmaker] refresh: " .. tostring(err)) end
end

local function showCounts()
	local counts = seenCounts
	local size = need()
	local localN = {}
	for _, e in pairs(entries) do
		if e.State == "Queued" and e.Region then localN[e.Region] = (localN[e.Region] or 0) + 1 end
	end
	local at = now()
	for p, e in pairs(entries) do
		if e.State == "Queued" and e.Region and p.Parent then
			local pool = MM.PoolFor(counts, e.Region, at - e.EnqueuedAt >= cfg("WidenAfter", 20)) or localN[e.Region] or 1
			local have = math.clamp(pool, 1, size)
			if e.Shown ~= have then
				e.Shown = have
				hooks.QueueCount(p, have, size)
			end
		end
	end
end

local function tick()
	if not MM.Global() then return end
	local any = false
	for p, e in pairs(entries) do
		if not p.Parent then
			entries[p] = nil
		else
			if e.State == "Queued" and e.Region then any = true end
			if e.Region and (e.State == "CancelPending" or now() - (e.LastRefresh or 0) >= cfg("RefreshEvery", 20)) then
				task.spawn(refresh, p, e)
			end
		end
	end
	if not any then return end
	local held = tryLock()
	showCounts()
	if held then matchmake() end
end

----------------------------------------------------------------------------------------------------
-- a match server
----------------------------------------------------------------------------------------------------
local record = nil          -- the match this server runs
local expected = {}         -- [userId] = 1 | 2, its team
local phase = "none"        -- "loading" | "waiting" | "vote" | "match" | "returning"
local calledOff = false
local returnTries = setmetatable({}, { __mode = "k" })
local sentAway = setmetatable({}, { __mode = "k" })       -- [player] = true once told to leave this match server

--- Off to a public server (TeleportAsync with no options lands in one). In Studio: logged.
local function sendToPublic(list, text)
	local go = {}
	for _, p in ipairs(list) do
		if p.Parent then
			if text then hooks.Notify(p, text) end
			go[#go + 1] = p
		end
	end
	if #go == 0 then return end
	if IS_STUDIO then
		local names = {}
		for _, p in ipairs(go) do names[#names + 1] = p.Name end
		print(("[Matchmaker] (Studio) RETURN STEP: would teleport %d player(s) to a public server: %s"):format(
			#go, table.concat(names, ", ")))
		return
	end
	if text then task.wait(2) end
	local ok, err = pcall(function() game:GetService("TeleportService"):TeleportAsync(game.PlaceId, go) end)
	if not ok then
		warn("[Matchmaker] return teleport failed: " .. tostring(err))
		for _, p in ipairs(go) do
			returnTries[p] = (returnTries[p] or 0) + 1
			if returnTries[p] <= 3 then
				task.delay(3, function() sendToPublic({ p }) end)
			else
				p:Kick("Could not take you back to the Hub -- please rejoin SPELLSHOT.")
			end
		end
	end
end

local function joinMatchId(p)
	local ok, data = pcall(function() return p:GetJoinData() end)
	local td = ok and type(data) == "table" and data.TeleportData
	local id = type(td) == "table" and td.MatchId
	return type(id) == "string" and id or nil
end

local function loadRecord(matchId)
	for _ = 1, 3 do
		local ok, rec = pcall(function() return S().Matches:GetAsync(matchId) end)
		if ok then return type(rec) == "table" and rec or nil end
		task.wait(1)
	end
	return nil
end

local function presentTeams()
	local teams, group = { {}, {} }, {}
	for i, team in ipairs(record.Teams) do
		for _, uid in ipairs(team) do
			local p = Players:GetPlayerByUserId(uid)
			if p then
				table.insert(teams[i], p)
				group[#group + 1] = p
			end
		end
	end
	return teams, group
end

local function anyHeld(group)
	for _, p in ipairs(group) do
		if p.Parent and hooks.Holds(p) then return true end
	end
	return false
end

local function returnAll(text)
	phase = "returning"
	print("[Matchmaker] match server: " .. text)
	sendToPublic(Players:GetPlayers(), text)
end

--- A match server's whole life: find its record, wait for its players, run the match (HubServer's vote and team match),
--- and send everyone home. `simRecord`: the Studio simulation's record, built from the players present.
local function runMatchServer(simRecord)
	phase = "loading"
	local started = os.clock()
	local rec = simRecord
	local tried = {}
	while not rec do
		for _, p in ipairs(Players:GetPlayers()) do
			if not tried[p] then
				tried[p] = true
				local id = joinMatchId(p)
				local r = id and loadRecord(id)
				if r and r.PrivateServerId == game.PrivateServerId and r.MatchId == id then
					rec = r
					break
				end
			end
		end
		if not rec then
			if os.clock() - started > cfg("ArriveTimeout", 45) then
				returnAll("This match could not be found -- RETURNING TO HUB.")
				return
			end
			task.wait(0.5)
		end
	end
	record = rec
	table.clear(expected)
	local total = 0
	for i, team in ipairs(rec.Teams) do
		for _, uid in ipairs(team) do
			expected[uid] = i
			total += 1
		end
	end
	print(("[Matchmaker] match server for %s: waiting for %d player(s)"):format(tostring(rec.MatchId), total))
	phase = "waiting"
	local shown = -1
	local deadline = os.clock() + cfg("ArriveTimeout", 45)
	while true do
		local here = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if expected[p.UserId] then
				here += 1
			elseif not rec.Sim and not sentAway[p] then
				sentAway[p] = true
				task.spawn(sendToPublic, { p }, "This is a private match -- sending you to a Hub.")
			end
		end
		if here ~= shown then
			shown = here
			for _, p in ipairs(Players:GetPlayers()) do
				if expected[p.UserId] then hooks.Notify(p, ("WAITING FOR PLAYERS %d/%d"):format(here, total)) end
			end
		end
		if here >= total or os.clock() >= deadline then break end
		task.wait(0.5)
	end
	while true do
		local teams, group = presentTeams()
		local enough = #group > 0
		if not rec.Sim then
			for i, team in ipairs(teams) do
				-- MinPerTeam, but never more than the record's own team (a 1v1 needs its one)
				if #team < math.min(cfg("MinPerTeam", 2), #rec.Teams[i]) then enough = false end
			end
		end
		if not enough then
			returnAll("Not enough players made it -- RETURNING TO HUB.")
			return
		end
		-- nobody mid-move (HubServer's vote would not start)
		local t0 = os.clock()
		while os.clock() - t0 < 5 do
			local moving = false
			for _, p in ipairs(group) do
				if hooks.IsMoving(p) then moving = true end
			end
			if not moving then break end
			task.wait(0.2)
		end
		phase = "vote"
		calledOff = false
		print(("[Matchmaker] match server: starting the match, %d v %d"):format(#teams[1], #teams[2]))
		hooks.StartMatch(group, teams)
		t0 = os.clock()
		while not calledOff and not anyHeld(group) and os.clock() - t0 < 60 do task.wait(0.25) end
		if not calledOff then
			if anyHeld(group) then
				phase = "match"
				while anyHeld(group) do task.wait(0.5) end
			end
			returnAll("RETURNING TO HUB")
			return
		end
		-- the vote was called off (someone left): again, with whoever is still here
		task.wait(1)
	end
end

--- HubServer's callOff: a team match's vote ended because someone left. In a match server there is no queue to go back
--- to, so this server's own loop takes it from here (true). Elsewhere false: HubServer puts them back in the queue.
function MM.CalledOff(group)
	if not matchServer then return false end
	calledOff = true
	return true
end

local function onPlayerAdded(p)
	if not matchServer or (record and record.Sim) or sentAway[p] then return end
	if phase == "returning" then
		sentAway[p] = true
		task.spawn(sendToPublic, { p }, "RETURNING TO HUB")
	elseif not record then
		return                      -- still loading: the loader reads their TeleportData
	elseif not expected[p.UserId] then
		sentAway[p] = true
		task.spawn(sendToPublic, { p }, "This is a private match -- sending you to a Hub.")
	elseif phase ~= "waiting" then
		sentAway[p] = true
		task.spawn(sendToPublic, { p }, "Your match has already started -- RETURNING TO HUB.")
	end
end

local function simRecord()
	local list = Players:GetPlayers()
	local teams = { {}, {} }
	local half = math.ceil(#list / 2)
	for i, p in ipairs(list) do
		table.insert(teams[(i <= half) and 1 or 2], p.UserId)
	end
	return {
		MatchId = "studio-sim-" .. HttpService:GenerateGUID(false), Teams = teams, Region = "SIM", AccessCode = "",
		PrivateServerId = game.PrivateServerId, Created = now(), Sim = true,
	}
end

-- for the headless harness (SPELLSHOT_Backup\matchmaking_2026_10_28\harness): these steps, run as they are
MM._Internal = {
	matchmake = function() return matchmake() end,
	tryLock = function() return tryLock() end,
	entries = entries,
	teleporting = teleporting,
	phase = function() return phase end,
}

----------------------------------------------------------------------------------------------------
-- start
----------------------------------------------------------------------------------------------------
function MM.Init(h)
	hooks = h
	local TeleportService = game:GetService("TeleportService")
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		matchServer = true
		task.spawn(runMatchServer, nil)
	end
	if IS_STUDIO then
		local function sim()
			if workspace:GetAttribute(SIM_ATTR) == true then
				if matchServer then return end
				local t0 = os.clock()
				while #Players:GetPlayers() == 0 and os.clock() - t0 < 30 do task.wait(0.5) end
				matchServer = true
				for p in pairs(entries) do MM.Remove(p) end
				print("[Matchmaker] (Studio) simulating a match server with the players present")
				task.spawn(runMatchServer, simRecord())
			elseif matchServer and record and record.Sim then
				matchServer, record, phase = false, nil, "none"
				print("[Matchmaker] (Studio) match server simulation off")
			end
		end
		workspace:GetAttributeChangedSignal(SIM_ATTR):Connect(sim)
		if workspace:GetAttribute(SIM_ATTR) == true then task.spawn(sim) end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(p)
		teleporting[p] = nil
	end)
	TeleportService.TeleportInitFailed:Connect(function(p, result, message)
		if matchServer then
			returnTries[p] = (returnTries[p] or 0) + 1
			warn(("[Matchmaker] return teleport failed for %s (%s): %s"):format(p.Name, tostring(result), tostring(message)))
			if returnTries[p] <= 3 then
				task.delay(3, function() sendToPublic({ p }) end)
			else
				p:Kick("Could not take you back to the Hub -- please rejoin SPELLSHOT.")
			end
		elseif teleporting[p] then
			teleportFailed(p, tostring(result) .. ": " .. tostring(message))
		end
	end)
	if not matchServer and cfg("Mode", "Local") == "Global" then
		task.spawn(function()
			for attempt = 1, 5 do
				local ok, err = pcall(function()
					game:GetService("MessagingService"):SubscribeAsync(S().Topic, function(message)
						local d = message.Data
						if type(d) == "table" and type(d.Id) == "string" and type(d.Users) == "table" then
							task.spawn(onMatch, d.Id, d.Users, nil)
						end
					end)
				end)
				if ok then break end
				warn("[Matchmaker] SubscribeAsync failed (" .. attempt .. "): " .. tostring(err))
				task.wait(5 * attempt)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(cfg("PollEvery", 2.5))
			local ok, err = pcall(tick)
			if not ok then warn("[Matchmaker] " .. tostring(err)) end
		end
	end)
end

return MM
