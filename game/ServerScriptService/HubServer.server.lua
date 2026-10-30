--[[
	HubServer  (Script)  ->  ServerScriptService/HubServer

	SPELLSHOT's front door (Build Prompt 18). ONE server holds the Hub and the arena at the same time, the
	way RIVALS keeps its lobby and its matches together: nobody changes server, so there is no loading
	screen, friends stay together, and every part of it runs in a Studio Play session.

	  Hub    workspace.ArcaneObservatoryHub (the Arcane Rune Observatory, round 23), centred at (8000, 0, 8000). Everyone
	         spawns here. Its Training room's portal leads to the Training Ground (2026-10-20: the range at the origin, the
	         one practice space; the Map_TrainingGrounds island it used to lead to is retired), a sandbox.
	         (Since 2026-10-14. The Open Academy before it is still in workspace, unwired and unreachable.)
	  Arena  a map: the baseplate at the origin with the TrainingGround range, or a map Model from
	         MapRegistry (Shattered Neon City sits 3000 studs down -Z).

	Where a player is lives in their "Zone" attribute ("Hub" | "Arena"), and which map in their "Map"
	attribute (a MapRegistry id, set while in the arena). Only this script sets either. Everything that differs
	by place reads them: HubClient (combat HUD, lighting and sky, BACK TO HUB, the wipe) and SpellshotInput /
	SpellshotService / AbilityHandler (no casting in the Hub). A move is: the client's wipe covers the screen,
	the server streams the far side in around the player, moves them, and the wipe opens again.

	INTO THE ARENA  (every way in goes through the MAP VOTE first)
	  Duel Pads    both marks taken for COUNTDOWN seconds: a DUEL for both
	  a pad alone  hold Interact for SOLO TEST
	  Quick Play   QUEUE for Duel fills to two teams of Config.Team.Size and starts a TEAM match (2026-10-18, team mode:
	               3v3 on the duel's loop, teams drawn at random; the queue shows "3/6"); SOLO TEST sends you alone.
	               (2026-10-28) With Config.Matchmaking.Mode "Global" the queue is every server's: Matchmaker matches
	               region first, then anyone, and a match whose players are not all here runs in its own reserved
	               server (a MATCH SERVER: this script again, with QUEUE and the pads off). "Local" is the queue below.
	  range door   walk onto the threshold: SOLO TEST
	A DUEL belongs to DuelMatch from the end of its vote: rounds, first to Config.Duel.FirstTo, both duellists rebuilt on
	their marks every round (respawnTo), and both sent home at the end. A SOLO TEST is a sandbox: no rounds, and dying
	respawns you where you were placed on that map.
	BACK TO HUB (or H) comes back -- except mid-duel, where only a dev may leave, and leaving forfeits the match.

	THE MAP VOTE (the user's call, 2026-09-14: vote for the map once a match is confirmed, before loading in).
	Everyone in the match gets MapVote's screen with every map whose Model is in workspace. Most votes wins;
	a tie, or nobody voting, is a coin flip. A duel's vote lasts VOTE_SECONDS.Duel or until both have voted;
	a solo test's ends the moment you pick. A duellist leaving calls it off: no match starts, and the other stays in
	the Hub, free to queue again. While someone is in a vote,
	the queue, the pads and the door leave them alone.

	ONE COPY OF EACH MAP FOR NOW. Two duels on the same map share it, as they shared the one baseplate. Per-duel
	copies of a map, parked apart, are the next step once several duels run at once.

	WIRED IN THE HUB  (every prompt is held with the Interact bind: G unless the player rebinds it; E is Defense)
	  duel pads        P1-P9 on Duels' arc: stand on a half to register; each post screen shows who is on its pad
	  Loadout altar    opens the loadout menu
	  Cache Vault      in the Store: says it opens in a later update (the Cache is not built; Sparks and Element unlocks are,
                   2026-10-18 -- audit P2-18, 2026-10-19)
	  Training portal  to the Training Ground range (2026-10-20); its gate behind the spawn brings you back to the portal's path
	The shrines, the Ledger and the range door are still handled below, but nothing in the Observatory carries
	their names, so they make nothing (bonding is in the loadout menu, Quick Play is the HUD's PLAY).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local MapRegistry = require(spellFolder:WaitForChild("MapRegistry"))
local DuelMatch = require(script.Parent:WaitForChild("DuelMatch"))
-- (2026-10-19, audit P1-03) the movement guard's grace before every move of a body below (Core.AllowMove). DuelMatch already
-- requires CombatCore, so this adds no wait and no loop.
local Core = require(script.Parent:WaitForChild("CombatCore"))
-- (2026-10-18, economy) which Elements a player owns: a shrine bonds only an owned one
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
-- (2026-10-28, matchmaking) Quick Play's queue across every server, and this server's part when it is a match server
-- (a reserved server that runs one match). Config.Matchmaking.Mode = "Local" keeps the one-server queue below.
local Matchmaker = require(script.Parent:WaitForChild("Matchmaker"))

local HUB_NAME = "ArcaneObservatoryHub"   -- the Arcane Observatory (2026-10-14); the Open Academy before it stays in workspace, unwired
local COVER_TIME = 0.35       -- the client's wipe needs this long to cover the screen before the move
local STREAM_TIMEOUT = 3      -- seconds to wait for the far side to stream in before moving anyway
local VOTE_SECONDS = { Duel = 12, Solo = 20 }
local RESULT_HOLD = 1.5       -- seconds the winning card stays on screen before the wipe
local VOTE_RATE = 0.1         -- the fastest a player's vote changes are taken

local hubRemote = spellFolder:FindFirstChild("Hub")
if not hubRemote then
	hubRemote = Instance.new("RemoteEvent")
	hubRemote.Name = "Hub"
	hubRemote.Parent = spellFolder
end

local function notify(p, text)
	hubRemote:FireClient(p, "notice", text)
end

--- Out of Quick Play's queue, with the reason: Quick Play puts it in its footer, HubClient shows it as a notice.
local function dequeued(p, text)
	hubRemote:FireClient(p, "queued", false, text)
end

local hub = workspace:WaitForChild(HUB_NAME, 30)
if not hub then
	warn("[HubServer] there is no workspace." .. HUB_NAME)
	return
end

local function find(name)
	return hub:FindFirstChild(name, true)
end

----------------------------------------------------------------------------------------------------
-- zones, and moving between them
----------------------------------------------------------------------------------------------------
-- 2026-10-14: everyone spawns in the Arcane Observatory (workspace.ArcaneObservatoryHub, its Functional.HubSpawn);
-- arrivals in the Hub follow the new spawn. (Now HUB_NAME is the Observatory too, so this finds the same model twice.)
local SPAWN_HUB_NAME = "ArcaneObservatoryHub"
local spawnHub = workspace:WaitForChild(SPAWN_HUB_NAME, 30)
local hubSpawn = (spawnHub and spawnHub:FindFirstChild("HubSpawn", true)) or find("HubSpawn")

-- The arena's SpawnLocation stays as the arena's marker but no longer takes spawns: with two enabled,
-- Roblox picks one at random, and everybody has to arrive in the Hub.
local arenaMarker
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("SpawnLocation") then
		arenaMarker = arenaMarker or c
		c.Enabled = false
	end
end
-- (2026-10-19, audit P6A-06) ...and EVERY other SpawnLocation, at any depth, but the Hub's own: the loop above reached only
-- workspace's children, so a nested one -- the retired Open Academy's HubSpawn (workspace.OpenAcademyHub, still in the
-- place, unwired) -- stayed live and could take a join or a Hub respawn into a hub with no working prompts.
if hubSpawn then
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") and d ~= hubSpawn then d.Enabled = false end
	end
end
local ARENA = (arenaMarker and arenaMarker.Position or Vector3.zero) + Vector3.new(0, 3, 0)

local function hubSpot()
	local base = (hubSpawn and hubSpawn.Position or hub:GetPivot().Position) + Vector3.new(0, 3, 0)
	return CFrame.lookAt(base, base + Vector3.new(0, 0, 10))       -- facing Duels (+Z) in the Arcane Observatory
end

--- Where people land. A map Model carries its own Marks (A, B, Solo), each facing into the map. The Training
--- Ground has none: solo is the range's own spawn, facing down the range (-Z); a duel is two marks 70 studs
--- apart behind the spawn, facing each other, out of the range's firing lanes.
local function arenaSpot(side, mapId)
	local map = MapRegistry.Get(mapId)
	local model = map and map.Model and workspace:FindFirstChild(map.Model)
	local marks = model and model:FindFirstChild("Marks")
	local mark = marks and (marks:FindFirstChild(side or "Solo") or marks:FindFirstChild("A"))
	if mark then
		return mark.CFrame + Vector3.new(0, 3, 0)
	end
	if side == "A" or side == "B" then
		local a, b = ARENA + Vector3.new(-35, 0, 40), ARENA + Vector3.new(35, 0, 40)
		return (side == "A") and CFrame.lookAt(a, b) or CFrame.lookAt(b, a)
	end
	return CFrame.lookAt(ARENA, ARENA + Vector3.new(0, 0, -10))
end

--- A teammate's spot on their team's mark (2026-10-18, team mode): `count` teammates stand side by side across the line
--- from this mark to the other, Config.Team.SpawnSpacing apart and centred on the mark, all facing the way the mark does;
--- `slot` is which of them (1..count). A spot is used only if the way to it from the mark is clear and it has a floor no
--- more than SpawnFloorDrop below; otherwise that teammate stands on the mark itself. One a side is the mark, as a duel's
--- always was.
local function teamSpot(side, mapId, slot, count)
	local mark = arenaSpot(side, mapId)
	if not count or count <= 1 then return mark end
	local T = Config.Team or {}
	local offset = (slot - (count + 1) / 2) * (T.SpawnSpacing or 6)
	if math.abs(offset) < 0.01 then return mark end
	local across = arenaSpot((side == "A") and "B" or "A", mapId).Position - mark.Position
	across = Vector3.new(across.X, 0, across.Z)
	if across.Magnitude < 1 then across = Vector3.new(mark.LookVector.X, 0, mark.LookVector.Z) end
	if across.Magnitude < 1e-3 then return mark end
	local step = across.Unit:Cross(Vector3.yAxis) * offset
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local bodies = {}
	for _, q in ipairs(Players:GetPlayers()) do
		if q.Character then bodies[#bodies + 1] = q.Character end
	end
	params.FilterDescendantsInstances = bodies
	if workspace:Raycast(mark.Position, step, params) then return mark end          -- a wall in the way: the mark
	local floor = workspace:Raycast(mark.Position + step, Vector3.new(0, -(3 + (T.SpawnFloorDrop or 10)), 0), params)
	if not floor then return mark end                                                -- over a drop: the mark
	return mark.Rotation + (floor.Position + Vector3.new(0, 3, 0))
end

local arenaSpots = setmetatable({}, { __mode = "k" })     -- [player] = where they respawn in the arena
local moving = setmetatable({}, { __mode = "k" })
local settling = setmetatable({}, { __mode = "k" })      -- [player] = how many place() calls are on their body right now

local MOVE_HOLD = 0.5           -- (2026-10-30) seconds the server keeps a body it moved (see place)
local MOVE_SETTLE = 0.25        -- and how long after it gives the body back the move is checked
local MOVE_TRIES = 3
local ARRIVED = 25              -- studs, flat: this near its spot, a moved body has arrived

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function settle(p, d)
	local n = (settling[p] or 0) + d
	settling[p] = (n > 0) and n or nil
end

--- Puts p's body on `cf`. Returns true once it is there, false when the body would not stay there, and nil when p has no
--- body to move (the next one spawns by the Zone). (2026-10-30, the owner in the live game, back from the Training
--- Ground: "it like tries tp'ing but im stuck physically in the training ground still".) A client owns its own body's
--- physics and can still be sending where it was when the server moves it, and on a live server that can win. So the
--- server takes the body (Core.HoldBody) for the move and MOVE_HOLD after it, sets it on the spot once more as it hands it
--- back (a body at rest sends its client nothing, so a client that wrote its old place keeps it and takes it back with
--- the body: measured in Play), checks it is still there MOVE_SETTLE later, and moves it again if not.
local function place(p, cf)
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	settle(p, 1)
	-- the far side is 3000 studs away and streamed out for this player; ask for it before arriving
	pcall(function() p:RequestStreamAroundAsync(cf.Position, STREAM_TIMEOUT) end)
	local arrived = false
	for try = 1, MOVE_TRIES do
		if not (p.Parent and p.Character == char and root.Parent) then break end
		local key = {}                   -- this move's own hold: two moves of one body never end each other's
		Core.AllowMove(char, MOVE_HOLD + 1.5)    -- (2026-10-19, audit P1-03) a server move: the movement guard lets it be
		Core.HoldBody(char, key, true)
		char:PivotTo(cf)
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait(MOVE_HOLD)
		char:PivotTo(cf)
		root.AssemblyLinearVelocity = Vector3.zero
		Core.HoldBody(char, key, false)
		task.wait(MOVE_SETTLE)
		arrived = root.Parent ~= nil and flat(root.Position, cf.Position) <= ARRIVED
		if arrived then break end
		warn(("[HubServer] %s: move %d of %d missed its spot by %.0f studs"):format(p.Name, try, MOVE_TRIES, flat(root.Position, cf.Position)))
	end
	settle(p, -1)
	if not (p.Parent and p.Character == char) then return nil end
	return arrived
end

--- Health never regenerates (2026-09-16), so a move is where a fight's damage ends: whoever arrives in the Hub or starts
--- a Solo Test does so at full health, the way a duel round starts on a new body. Nobody can lose health in the Hub
--- (CombatCore.IsFriendly). In a Solo Test nobody can hurt you either, with two exceptions: a dev's DMG button, and on
--- the Training Ground map the range's snowball thrower (TrainingGround's Dummy_Thrower: 10 a hit, never below 1 HP,
--- at whoever is nearest in the range; the SNOWBALLS pad there pauses it).
local function refill(p)
	local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then humanoid.Health = humanoid.MaxHealth end
end

--- Moves one player to "Hub" or "Arena" (at `spot`, on `map`), under the client's wipe, and refills their health. Yields.
local function moveTo(p, zone, spot, map)
	if moving[p] then return end
	moving[p] = true
	hubRemote:FireClient(p, "transition", "cover", zone, map and map.Name)
	task.wait(COVER_TIME)
	if p.Parent then
		local dest = (zone == "Arena") and spot or (spot or hubSpot())      -- (a Hub arrival may name its spot: the yard gate)
		local was = { Spot = arenaSpots[p], Map = p:GetAttribute("Map"), Zone = p:GetAttribute("Zone") }
		-- (2026-10-30) in a pcall, so whatever goes wrong the wipe still comes off and moving[p] still clears: a moving[p]
		-- left set turns every portal and BACK TO HUB away until a rejoin
		local ok, arrived = pcall(function()
			arenaSpots[p] = (zone == "Arena") and spot or nil
			-- Map before Zone, so the client's Zone change already sees which map it is
			p:SetAttribute("Map", (zone == "Arena") and (map and map.Id or "TrainingGround") or nil)
			p:SetAttribute("Zone", zone)
			refill(p)           -- after the Zone changes, so nothing thrown before the move can take it again
			return place(p, dest)
		end)
		if not ok then warn("[HubServer] moveTo failed for " .. p.Name .. ": " .. tostring(arrived)) end
		if (not ok or arrived == false) and p.Parent then
			-- the body never got there, so its Zone goes back with it and the way out it came by works again (a Hub Zone
			-- on a body still in the Training Ground shut both: BACK TO HUB and the gate back)
			arenaSpots[p] = was.Spot
			p:SetAttribute("Map", was.Map)
			p:SetAttribute("Zone", was.Zone)
			notify(p, "The move didn't go through -- try again.")
			dest = nil
		end
		-- the first-person camera keeps its old heading through a PivotTo (and turns the body back to it), so the
		-- client is told which way the spot faces and turns the camera there under the wipe (and is sent the spot, to set
		-- a body it still has somewhere else on it: HubClient)
		if p.Parent then hubRemote:FireClient(p, "transition", "reveal", zone, dest and dest.LookVector, dest) end
	end
	moving[p] = nil
end

--- moveTo, with the character rebuilt on the spot (LoadCharacter) under the wipe: full health and mana, every cooldown
--- and charge back, nothing left on the body. How a duel's rounds begin, and how a duellist who is down goes home.
--- `label` replaces the wipe's "TO <MAP>!" (a round's number). Yields.
local function respawnTo(p, zone, spot, map, label)
	if moving[p] then return end
	moving[p] = true
	hubRemote:FireClient(p, "transition", "cover", zone, map and map.Name, label)
	task.wait(COVER_TIME)
	if p.Parent then
		local dest = (zone == "Arena") and spot or (spot or hubSpot())
		arenaSpots[p] = (zone == "Arena") and spot or nil
		local function enter()
			p:SetAttribute("Map", (zone == "Arena") and (map and map.Id or "TrainingGround") or nil)
			p:SetAttribute("Zone", zone)
		end
		-- Home: the Zone first (nobody can be hurt in the Hub, and onCharacter must not pull the new body back to the
		-- arena). Into the arena from the Hub (round 1): only once the new body is on its mark -- until then the old
		-- body, and the new one LoadCharacter puts on the Hub spawn, stand in the Hub, where an arena Zone would let two
		-- duellists fight. (Rounds 2+ are already Arena; their new bodies are moved off the spawn at once below.)
		-- (2026-10-30) in a pcall, so whatever goes wrong the wipe still comes off and moving[p] still clears
		local okMove, moveErr = pcall(function()
			if zone ~= "Arena" then enter() end
			pcall(function() p:RequestStreamAroundAsync(dest.Position, STREAM_TIMEOUT) end)
			local ok, err = pcall(function() p:LoadCharacter() end)
			if not ok then
				warn("[HubServer] LoadCharacter failed for " .. p.Name .. ": " .. tostring(err))
				refill(p)       -- the old body carries on, so at least it starts full, as a new one would
			end
			if p.Parent then
				-- off the Hub spawn with no yield first (place() waits on RequestStreamAroundAsync before its PivotTo)
				local char = p.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					Core.AllowMove(char, 1.5)    -- (2026-10-19, audit P1-03) off the spawn: a server move the guard lets be
					char:PivotTo(dest)
				end
				if zone == "Arena" then enter() end
				place(p, dest)  -- streams the mark in again, holds the body on it and checks it arrived
			end
		end)
		if not okMove then warn("[HubServer] respawnTo failed for " .. p.Name .. ": " .. tostring(moveErr)) end
		if p.Parent then hubRemote:FireClient(p, "transition", "reveal", zone, dest.LookVector, dest) end
	end
	moving[p] = nil
end

local queue = {}

--- (2026-10-18, team mode) Quick Play's queue fills to two teams: 2 x Config.Team.Size. Everyone in it is told how full
--- it is ("queueCount", have, need) whenever that changes; Quick Play shows it as "3/6".
local function queueNeed()
	return 2 * math.max(1, math.floor((Config.Team and Config.Team.Size) or 3))
end
local function tellQueue()
	local need = queueNeed()
	for _, q in ipairs(queue) do
		if q.Parent then hubRemote:FireClient(q, "queueCount", #queue, need) end
	end
end

local function unqueue(p, why)
	-- (2026-10-28) in Global mode the queue is Matchmaker's: one ticket per player, shared by every server
	if Matchmaker.Global() then return Matchmaker.Remove(p, why) end
	local i = table.find(queue, p)
	if i then
		table.remove(queue, i)
		tellQueue()
	end
	return i ~= nil
end

--- kind: "Duel" (two players from a Hub pad: DuelMatch runs the rounds from here) | "Team" (Quick Play's two teams, the
--- group's first half against its second: DuelMatch too, 2026-10-18) | "Solo" (one player, a sandbox)
local function enterArena(group, kind, mapId, teams)
	local map = MapRegistry.Get(mapId) or MapRegistry.Get("TrainingGround")
	if kind == "Team" and teams then
		-- (2026-10-28) a match server's teams, as its record has them (uneven if someone never arrived)
		DuelMatch.Begin(group, map, teams, "Team")
		return
	end
	if kind == "Duel" and #group == 2 then
		-- the round loop takes over: it rebuilds both on their marks (a coin flip for round 1) and makes round 1 live
		DuelMatch.Begin(group, map)
		return
	end
	if kind == "Team" and #group >= 2 and #group % 2 == 0 then
		local half = #group // 2
		local teams = { {}, {} }
		for i, p in ipairs(group) do
			table.insert(teams[(i <= half) and 1 or 2], p)
		end
		DuelMatch.Begin(group, map, teams, "Team")
		return
	end
	local where = (map.Id == "TrainingGround") and "the range" or map.Name
	for _, p in ipairs(group) do
		task.spawn(function()
			moveTo(p, "Arena", arenaSpot(nil, map.Id), map)
			notify(p, ("SOLO TEST: %s is yours. BACK TO HUB (H) to leave."):format(where))
		end)
	end
end

DuelMatch.Init({
	Remote = hubRemote,
	MoveTo = moveTo,
	Respawn = respawnTo,
	ArenaSpot = arenaSpot,
	TeamSpot = teamSpot,          -- (2026-10-18, team mode) teammates side by side on their mark
	IsMoving = function(p) return moving[p] == true end,
})

----------------------------------------------------------------------------------------------------
-- the map vote, between a confirmed match and the arena
----------------------------------------------------------------------------------------------------
local voting = setmetatable({}, { __mode = "k" })         -- [player] = the vote they are in
local lastVote = setmetatable({}, { __mode = "k" })
local voteSerial = 0

local function voteChoices(kind)
	local list = {}
	for _, m in ipairs(MapRegistry.List) do
		-- a Practice map (the range) is a Solo Test's only (2026-10-19, audit P1-04)
		if m.Vote ~= false and not (m.Practice and kind ~= "Solo") and (not m.Model or workspace:FindFirstChild(m.Model)) then
			table.insert(list, { Id = m.Id, Name = m.Name, Sub = m.Sub, Image = m.Image, Accent = m.Accent })
		end
	end
	return list
end

local function allHere(group)
	for _, p in ipairs(group) do
		if not p.Parent then return false end
	end
	return true
end

--- Someone in the vote left the game: no match starts, and whoever is left stays in (or is put back in) the Hub, free to
--- queue or step onto a pad again. MapVote tells them why.
local popTeams     -- (below, 2026-10-18) starts a team match whenever Quick Play's queue holds two teams

local function callOff(vote)
	vote.Done = true
	local back = {}
	for _, p in ipairs(vote.Group) do
		if voting[p] == vote then voting[p] = nil end
		if p.Parent then
			hubRemote:FireClient(p, "voteResult", vote.Id, nil, "left")
			if p:GetAttribute("Zone") ~= "Hub" then task.spawn(moveTo, p, "Hub") end
			if vote.Kind == "Team" then back[#back + 1] = p end
		end
	end
	-- (2026-10-28) a match server has no queue to go back to: Matchmaker starts its vote again, or sends everyone home
	if vote.Kind == "Team" and Matchmaker.CalledOff(back) then return end
	-- (2026-10-18, team mode) a team match's vote called off puts everyone left back at the FRONT of Quick Play's queue,
	-- in their order, so one leaver doesn't send the rest back to the menu to queue again
	if Matchmaker.Global() then
		for _, p in ipairs(back) do task.spawn(Matchmaker.Requeue, p) end     -- (2026-10-28) at their old place in line
	else
		for i = #back, 1, -1 do
			if not table.find(queue, back[i]) then table.insert(queue, 1, back[i]) end
		end
	end
	for _, p in ipairs(back) do
		hubRemote:FireClient(p, "queued", true, "Someone left the map vote -- you are back in the queue.")
	end
	if #back > 0 then task.defer(popTeams) end
end

local function tally(vote)
	local rows = {}
	for _, p in ipairs(vote.Group) do
		if vote.Picks[p] then table.insert(rows, { UserId = p.UserId, Map = vote.Picks[p] }) end
	end
	for _, p in ipairs(vote.Group) do
		if p.Parent then hubRemote:FireClient(p, "voteTally", vote.Id, rows) end
	end
end

--- A confirmed match: the map vote, then everyone into the winning map. With one map there is nothing to vote on.
local function sendToArena(group, kind, teams)
	for _, p in ipairs(group) do
		if voting[p] or moving[p] then return end            -- already on the way (a pad and the queue at once)
	end
	for _, p in ipairs(group) do
		if unqueue(p) then dequeued(p, nil) end
	end
	local choices = voteChoices(kind)
	if #choices < 2 then
		enterArena(group, kind, choices[1] and choices[1].Id, teams)
		return
	end

	voteSerial += 1
	local vote = { Id = voteSerial, Kind = kind, Group = group, Choices = choices, Picks = {}, Done = false }
	local rows = {}
	local half = #group // 2
	for i, p in ipairs(group) do
		voting[p] = vote
		-- a team match's rows carry the team (2026-10-18): the group's first half is team A, the rest team B (enterArena)
		local team = (kind == "Team") and ((i <= half) and "A" or "B") or nil
		if kind == "Team" and teams then team = table.find(teams[1], p) and "A" or "B" end    -- (2026-10-28) a record's teams
		table.insert(rows, { UserId = p.UserId, Name = p.DisplayName, Team = team })
	end
	local seconds = ((kind == "Team") and Config.Team and Config.Team.VoteSeconds) or VOTE_SECONDS[kind] or VOTE_SECONDS.Duel
	for _, p in ipairs(group) do
		hubRemote:FireClient(p, "vote", { Id = vote.Id, Kind = kind, Seconds = seconds, Maps = choices, Players = rows })
	end

	task.spawn(function()
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			if not allHere(group) then
				callOff(vote)
				return
			end
			local everyone = true
			for _, p in ipairs(group) do
				if not vote.Picks[p] then everyone = false end
			end
			if everyone then break end
			task.wait(0.1)
		end

		local counts = {}
		for _, p in ipairs(group) do
			local id = vote.Picks[p]
			if id then counts[id] = (counts[id] or 0) + 1 end
		end
		local best, top = {}, 0
		for _, c in ipairs(choices) do
			local n = counts[c.Id] or 0
			if n > top then
				best, top = { c.Id }, n
			elseif n == top then
				table.insert(best, c.Id)
			end
		end
		local winner = best[math.random(#best)]
		local how = (top == 0) and "none" or ((#best > 1) and "tie" or "votes")
		vote.Done = true
		for _, p in ipairs(group) do
			hubRemote:FireClient(p, "voteResult", vote.Id, winner, how)
		end

		task.wait(RESULT_HOLD)
		if not allHere(group) then
			callOff(vote)
			return
		end
		for _, p in ipairs(group) do voting[p] = nil end
		enterArena(group, kind, winner, teams)
	end)
end

--- (2026-10-18, team mode) Two teams' worth in Quick Play's queue: the first 2 x Size who can go now (in the Hub, not
--- being moved, in no vote or match) are taken in queue order, shuffled and split down the middle -- teams are drawn at
--- random -- and all of them go into one map vote. Anyone who cannot go yet keeps their place.
popTeams = function()
	local need = queueNeed()
	while true do
		local ready = {}
		for _, q in ipairs(queue) do
			if q.Parent and q:GetAttribute("Zone") == "Hub" and not voting[q] and not moving[q] and not DuelMatch.Of(q) then
				ready[#ready + 1] = q
				if #ready == need then break end
			end
		end
		if #ready < need then break end
		for _, q in ipairs(ready) do
			local i = table.find(queue, q)
			if i then table.remove(queue, i) end
		end
		for i = #ready, 2, -1 do
			local j = math.random(i)
			ready[i], ready[j] = ready[j], ready[i]
		end
		for _, q in ipairs(ready) do dequeued(q, "Match found!") end
		sendToArena(ready, "Team")
	end
	tellQueue()
end

local function onCharacter(p, char)
	if p:GetAttribute("Zone") ~= "Arena" then return end
	-- died in the arena: back where they were fighting, not in the Hub
	settle(p, 1)        -- (2026-10-30) the body-follows-its-Zone check below leaves this body to this move
	task.defer(function()
		if char:WaitForChild("HumanoidRootPart", 5) then
			pcall(place, p, arenaSpots[p] or arenaSpot(nil, p:GetAttribute("Map")))
		end
		settle(p, -1)
	end)
end

-- THE BODY FOLLOWS ITS ZONE (2026-10-30). The owner, in the live game, back from the Training Ground: "it like tries
-- tp'ing but im stuck physically in the training ground still and cant return now , have to rejoin". A move that set the
-- Zone and then lost the body shut both ways out (BACK TO HUB is for the arena Zone, the gate back for the Training
-- Ground's Map). place() now holds and checks the body, and moveTo puts the Zone back when it never arrives; this is the
-- backstop. Once a second: a living body in the Hub Zone that is not in the Hub, or in the arena Zone that is standing
-- in the Hub, two looks running with nothing moving it, is put where its Zone says, and the server log (F9) says so.
local HUB_REACH = 1000          -- studs, flat, from the Hub spawn: the Observatory is ~190 across, every map 3000+ away
local strays = setmetatable({}, { __mode = "k" })
task.spawn(function()
	while true do
		task.wait(1)
		local home = hubSpot()
		for _, p in ipairs(Players:GetPlayers()) do
			local zone = p:GetAttribute("Zone")
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			local spot
			if root and humanoid and humanoid.Health > 0 and not (moving[p] or voting[p] or settling[p]) then
				local inHub = flat(root.Position, home.Position) <= HUB_REACH
				if zone == "Hub" and not inHub then
					spot = home
				elseif zone == "Arena" and inHub then
					spot = arenaSpots[p] or arenaSpot(nil, p:GetAttribute("Map"))
				end
			end
			if spot then
				strays[p] = (strays[p] or 0) + 1
				if strays[p] >= 2 then
					strays[p] = nil
					warn(("[HubServer] %s: Zone %s but the body was %.0f studs from the Hub; put where the Zone says"):format(
						p.Name, tostring(zone), flat(root.Position, home.Position)))
					task.spawn(place, p, spot)
				end
			else
				strays[p] = nil
			end
		end
	end
end)

-- RESPAWNS ARE THIS SCRIPT'S (2026-10-18, team mode). In a team match a player who goes down stays down until the round
-- is over (DuelMatch rebuilds everyone for the next one), and Roblox has no per-player switch for its own respawn. So its
-- timer is pushed out of reach and the respawn it did is done here instead, after the place's own Players.RespawnTime
-- (3 s), for everyone the round loop is not holding: a player DuelMatch.Of still answers for, or one being moved, is left
-- to the round loop or the move. Everywhere else (the Hub, a Solo Test, a match that is over) nothing changes.
local RESPAWN_TIME = Players.RespawnTime
Players.RespawnTime = 1e6     --[[the place's 3 until 2026-10-18 team mode; RESPAWN_TIME keeps it]]
local function watchDeath(p, char)
	local humanoid = char:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local started = false
	-- (2026-10-23) this body is still the player's, or it is gone with none in its place
	local function current() return p.Character == char or p.Character == nil end
	local function respawn()
		if started then return end      -- once a body: the rebuild after a death removes that body too
		started = true
		task.wait(RESPAWN_TIME)
		-- (2026-10-19, audit P3-14) Holds, not Of: Of lets go at the result, and the dead were rebuilt into the arena for the
		-- MatchEndHold; Holds keeps them down until the match sends them home
		while p.Parent and current() and (moving[p] or DuelMatch.Of(p) or DuelMatch.Holds(p)) do
			task.wait(0.25)
		end
		if p.Parent and current() then
			local ok, err = pcall(function() p:LoadCharacter() end)
			if not ok then warn("[HubServer] respawn failed for " .. p.Name .. ": " .. tostring(err)) end
		end
	end
	humanoid.Died:Connect(respawn)
	-- 2026-10-23: a body removed without dying (destroyed, out of the world) fired no Died and never came back
	char.AncestryChanged:Connect(function(_, parent)
		if parent == nil then respawn() end
	end)
end

local function onJoin(p)
	p:SetAttribute("Zone", "Hub")
	p.CharacterAdded:Connect(function(char)
		task.spawn(watchDeath, p, char)
		onCharacter(p, char)
	end)
	if p.Character then task.spawn(watchDeath, p, p.Character) end
end
Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do
	if p:GetAttribute("Zone") == nil then onJoin(p) end
end
Players.PlayerRemoving:Connect(unqueue)

local lastRequest = setmetatable({}, { __mode = "k" })
local function throttled(p)
	local now = os.clock()
	if now - (lastRequest[p] or 0) < 0.25 then return true end
	lastRequest[p] = now
	return false
end

----------------------------------------------------------------------------------------------------
-- HUB: prompts
----------------------------------------------------------------------------------------------------
local function prompt(parent, action, object, hold, distance)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText, pp.ObjectText = action, object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = distance or 12
	pp.RequiresLineOfSight = false
	-- the Interact defaults. E would be eaten by the Defense ability; HubClient applies each player's own bind.
	pp.KeyboardKeyCode = Enum.KeyCode.G
	pp.GamepadKeyCode = Enum.KeyCode.ButtonB
	pp.Parent = parent
	return pp
end

local function anchor(name, cf)
	local a = Instance.new("Part")
	a.Name = name
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
	a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1)
	a.CFrame = cf
	a.Parent = hub
	return a
end

local builtNames = {}
for elName, el in pairs(Config.Elements) do
	if Config.IsBuilt(elName) then table.insert(builtNames, (el.Display or elName):upper()) end
end
table.sort(builtNames)
local builtList = table.concat(builtNames, ", ")

for elName, el in pairs(Config.Elements) do
	local monument = find("Shrine_" .. elName .. "_Monument")
	if monument then
		local display = el.Display or elName
		prompt(monument, "Bond", display .. " Shrine", 0.35, 14).Triggered:Connect(function(p)
			if not Config.IsBuilt(elName) then
				notify(p, ("%s is not built yet. Ready to bond: %s."):format(display:upper(), builtList))
			elseif p:GetAttribute("Element") == elName then
				notify(p, "You are already bonded with " .. display .. ".")
			elseif p:GetAttribute("DuelMatch") ~= nil or p:GetAttribute("Zone") ~= "Hub" then
				-- (2026-10-19, audit P1-19) the loadout menu's lock (SpellshotService's LoadoutRequest), which this skipped: no
				-- Element change in a match -- round 1 keeps the Hub Zone until the new body is on its mark -- nor outside the Hub
				notify(p, "You can't change Element during a match.")
			elseif not PlayerData.Owns(p, elName) then
				-- OWNED ONLY (2026-10-18, economy), as the loadout menu's pick is (SpellshotService)
				notify(p, display:upper() .. " is locked. Unlock it with Sparks in the Loadout menu.")
			else
				-- the Element's default Techniques and its own Ultimate come with it, as from the loadout menu (2026-09-24)
				local equipped = Config.ApplyElement(p, elName)
				notify(p, "Bonded with " .. display .. "."
					.. (#equipped > 0 and (" " .. table.concat(equipped, " and ") .. " equipped.") or ""))
			end
		end)
	end
end

-- the Observatory's Loadout altar (Functional.Loadout.LoadoutAltar, inside the altar block: the prompt hangs 1 stud over
-- its top); the older Hubs' consoles are still recognised by name
local tableRing = find("LoadoutAltar") or find("TP_LoadoutConsole") or find("BC_Table_InteractRing")
if tableRing then
	local where = (tableRing.Name == "LoadoutAltar") and "Loadout Altar"
		or ((tableRing.Name == "TP_LoadoutConsole") and "Techniques Pavilion" or "Binding Table")
	local a = anchor("TechniqueTablePrompt", CFrame.new(tableRing.Position + Vector3.new(0, 4, 0)))
	prompt(a, "Choose Techniques", where, 0.2, 14).Triggered:Connect(function(p)
		hubRemote:FireClient(p, "open", "Loadout")
	end)
end

local ledger = find("PC_Ledger_Tablet")
if ledger then
	prompt(ledger, "Open", "The Ledger", 0.2, 16).Triggered:Connect(function(p)
		hubRemote:FireClient(p, "open", "QuickPlay")
	end)
end

-- The Observatory's vault stands in the Store on the 2nd floor, right over the Training room's path, and prompts here
-- ignore line of sight. Its marker sits at the top of the door panel (y 15) and the reach is 6, not 14: the room's
-- ceiling under the vault (y 10.5) stops a jump with the root at about 8, 7 studs below the marker, so nobody in the
-- Training room sees it, even mid-jump; upstairs a player sees it within 6 studs of the door.
local vault = find("RQ_VaultDoor")
if vault then
	prompt(vault, "Open", "Cache Vault", 0.2, 6).Triggered:Connect(function(p)
		notify(p, "The Cache Vault opens in a later update.")
	end)
end

-- a collider seals the doorway, so the threshold in front of it is the part you actually walk onto
local lastDoor = setmetatable({}, { __mode = "k" })
for _, name in ipairs({ "TeleportDoor_TestingRange_Portal", "TeleportDoor_TestingRange_Threshold" }) do
	local part = find(name)
	if part then
		part.CanTouch = true
		part.Touched:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if not p or voting[p] or p:GetAttribute("Zone") ~= "Hub" or os.clock() - (lastDoor[p] or 0) < 3 then return end
			lastDoor[p] = os.clock()
			sendToArena({ p }, "Solo")
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- HUB: the Training portal, and the Training Ground's gate back
----------------------------------------------------------------------------------------------------
-- The user's call, 2026-09-14: a much bigger training ground, reached by a portal. It is a sandbox like SOLO TEST
-- (casting, the combat HUD, BACK TO HUB, no rounds).
-- (2026-10-20, Training Ground rework) The portal now leads to THE one practice space, the TrainingGround range at the
-- origin (workspace.TrainingGround, about 360 x 400), the same map SOLO TEST uses: same arrival, same dummies, boards and
-- allies. The Open Academy island (Map_TrainingGrounds) is retired to ServerStorage.TrainingGroundsSuperseded_2026_10_20;
-- MapRegistry's "TrainingGrounds" entry stays, dormant (no Model, so nothing offers it). Undo: maps\training_grounds\pre.
local trainingMap = MapRegistry.Get("TrainingGround")
--[[local lastGate = setmetatable({}, { __mode = "k" })   one 3 s for both portals until 2026-10-23: now one each, in gate()]]

local function gate(name, onEnter)
	local island = workspace:FindFirstChild("Map_TrainingGrounds")
	local range = workspace:FindFirstChild("TrainingGround")        -- its gate back is in TrainingGround.Interact (2026-10-20)
	local pane = find(name) or (island and island:FindFirstChild(name, true)) or (range and range:FindFirstChild(name, true))
	if not pane then return end
	local lastGate = setmetatable({}, { __mode = "k" })     -- 2026-10-23: each portal its own 3 s (a shared one swallowed the gate back)
	pane.CanTouch = true
	pane.Touched:Connect(function(hit)
		local p = Players:GetPlayerFromCharacter(hit.Parent)
		if not p or voting[p] or moving[p] or os.clock() - (lastGate[p] or 0) < 3 then return end
		lastGate[p] = os.clock()
		onEnter(p)
	end)
end

-- In the Observatory TY_Portal_Pane is the threshold across the portal frame's opening (Functional.Training): 8.8 wide,
-- 91.6-93.8 out along Training's axis. The frame's colliders behind it are a stepped plinth, not a wall (1.8 high from
-- 93.9 out, 3.6 from 95.8, then a 3.6 riser at 96.6), so a player walking into the opening crosses the threshold first
-- and climbs about 2 studs onto the first step during the 0.35 s cover. Walking at the frame beside the opening climbs
-- that step without crossing the threshold, as at any door frame; stepping sideways into the opening from there does.
gate("TY_Portal_Pane", function(p)
	if p:GetAttribute("Zone") ~= "Hub" or not trainingMap then return end
	if unqueue(p) then dequeued(p, nil) end
	task.spawn(function()
		moveTo(p, "Arena", arenaSpot(nil, trainingMap.Id), trainingMap)
		notify(p, "THE TRAINING GROUND. The gate behind the spawn, or BACK TO HUB (H), takes you back.")
	end)
end)

-- (2026-10-20) anyone on the Training Ground map, by the portal or by SOLO TEST, may leave through it -- never a duellist
-- (a duel only lands here as enterArena's fallback map, and leaving a duel goes through BACK TO HUB's forfeit)
gate("TG_ReturnPortal_Pane", function(p)
	if p:GetAttribute("Map") ~= "TrainingGround" or p:GetAttribute("DuelMatch") ~= nil then return end
	local arrival = find("PortalArrival")        -- on Training's lit path, 86 out, facing the hall (Functional.Training)
	task.spawn(moveTo, p, "Hub", arrival and (arrival.CFrame + Vector3.new(0, 3, 0)) or nil)
end)

----------------------------------------------------------------------------------------------------
-- HUB: the Duel Pads
----------------------------------------------------------------------------------------------------
local WHITE, WHITE_IDLE = Color3.fromHex("#FFFFFF"), Color3.fromHex("#C9CDD3")
local BLACK, BLACK_IDLE = Color3.fromHex("#111111"), Color3.fromHex("#5A5F6B")
local CORE_IDLE = Color3.fromHex("#353B55")
-- degrees round each orrery ring, 90 = the top; A rides the half nearer the Hall. The export left both at rest.
local REST = { 245, 295 }
local SHARD_ANGLES = { empty = { 245, 295 }, waitA = { 115, 295 }, waitB = { 245, 65 }, full = { 100, 80 } }
local WARD, WARD_Z, COUNTDOWN = 5.6, 3.4, 3
local SHARD_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- 2026-10-14: the Arcane Observatory's nine round pads on Duels' arc, P1-P9 (ArcaneObservatoryHub.Functional.DuelPads.Pad<n>):
-- _Centre (the pad's top centre; its LookVector runs from side A, the LEFT half seen from the arc's middle, to side B),
-- _RuneA and _RuneB (the halves of its lit ring: Models of Neon segments laid on the carved strip) and _Screen (the post's
-- screen). Each half lights in its player's Element colour; the post shows the pad's number and who is registered on it.
-- The duel starts the way it always has: both halves taken for COUNTDOWN seconds. The orreries are gone (no shards, no core).
local PAD_COUNT = 9
local OCC_R = 6.5                              -- on a pad = within this of its centre (the slab's radius is 6.35)
local RING_IDLE = Color3.fromHex("#6A6C73")    -- the Hub's own Ring_White Neon: an empty half looks as built
local RING_SHARE = 0.75                        -- the Neon share of the Hub's Element lines (the import manifest's rule)
local function toLinear(c) return (c <= 0.04045) and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function toSRGB(c) return (c <= 0.0031308) and c * 12.92 or 1.055 * c ^ (1 / 2.4) - 0.055 end
--- a colour as the Hub's Neon carries it: linear light x 0.63 x the key's share (#4FD1C5 at 0.75 gives the Hub's #36958C)
local function neon(col, share)
	local k = 0.63 * share
	return Color3.new(toSRGB(math.min(1, toLinear(col.R) * k)), toSRGB(math.min(1, toLinear(col.G) * k)),
		toSRGB(math.min(1, toLinear(col.B) * k)))
end
local function elementOf(p)
	return p and Config.Elements[p:GetAttribute("Element") or ""]
end
local function ringColour(p)
	if not p then return RING_IDLE end
	local el = elementOf(p)
	return neon(el and el.Base or WHITE, RING_SHARE)
end
local function paint(target, colour)
	if target:IsA("BasePart") then target.Color = colour end
	for _, d in ipairs(target:GetDescendants()) do
		if d:IsA("BasePart") then d.Color = colour end
	end
end

local pads = {}

local function orbit(pad, part, rest, restDeg, targetDeg)
	if not (part and rest and pad.ringCentre) then return end
	local pivot = CFrame.new(pad.ringCentre)
	local goal = pivot * CFrame.fromAxisAngle(pad.k, math.rad(targetDeg - restDeg)) * pivot:Inverse() * rest
	TweenService:Create(part, SHARD_TWEEN, { CFrame = goal }):Play()
end

local function rod(parent, p0, p1, width, colour)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = colour
	part.Size = Vector3.new(width, width, (p1 - p0).Magnitude)
	part.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
	part.Parent = parent
end

--- Two ward shards float up behind each duellist; with both sides taken, zigzag lasers close the square,
--- white on the near side, black on the far, meeting at a white spark on each long side.
local function buildWard(pad)
	if pad.ward then pad.ward:Destroy() end
	pad.ward = nil
	local a, b = pad.occ.A ~= nil, pad.occ.B ~= nil
	-- only a full pad draws anything now: the shards that floated up for one player came off the orreries, which the
	-- Observatory's pads do not have, so a half-taken pad would get an empty Ward folder
	if not ((a and b) or ((a or b) and pad.sa and pad.restA)) then return end
	local folder = Instance.new("Folder")
	folder.Name = "Ward_" .. pad.tag
	folder.Parent = hub
	pad.ward = folder
	local base = pad.centre + Vector3.new(0, WARD_Z - 0.33, 0)
	local corners = {
		A1 = base - pad.axis * WARD - pad.across * WARD, A2 = base - pad.axis * WARD + pad.across * WARD,
		B1 = base + pad.axis * WARD - pad.across * WARD, B2 = base + pad.axis * WARD + pad.across * WARD,
	}
	if pad.sa and pad.restA then
		local upright = CFrame.fromAxisAngle(pad.k, math.rad(90 - REST[1])) * pad.restA.Rotation
		for key, pos in pairs(corners) do
			local sideA = key:sub(1, 1) == "A"
			if (sideA and a) or (not sideA and b) then
				local s = pad.sa:Clone()
				s.Name = "WardShard_" .. key
				for _, c in ipairs(s:GetChildren()) do c:Destroy() end
				s.CanCollide, s.CanQuery, s.CanTouch = false, false, false
				s.Color = sideA and WHITE or BLACK
				s.CFrame = CFrame.new(pos) * upright
				s.Parent = folder
			end
		end
	end
	if not (a and b) then return end
	local function zig(p0, p1, c0, c1)
		local n = 12
		local dir = (p1 - p0).Unit
		local s0, s1 = p0 + dir * 0.7, p1 - dir * 0.7
		local pts = {}
		for j = 0, n do
			local wob = (j == 0 or j == n) and 0 or ((j % 2 == 0) and 0.32 or -0.32)
			pts[j] = s0:Lerp(s1, j / n) + Vector3.new(0, wob, 0)
		end
		for j = 0, n - 1 do
			rod(folder, pts[j], pts[j + 1], 0.2, (j < n / 2) and c0 or c1)
		end
		if c0 ~= c1 then
			local spark = Instance.new("Part")
			spark.Shape = Enum.PartType.Ball
			spark.Size = Vector3.new(0.8, 0.8, 0.8)
			spark.Anchored, spark.CanCollide, spark.CanQuery, spark.CanTouch = true, false, false, false
			spark.Material = Enum.Material.SmoothPlastic
			spark.Color = WHITE
			spark.Position = pts[n / 2]
			spark.Parent = folder
		end
	end
	zig(corners.A1, corners.A2, WHITE, WHITE)
	zig(corners.B1, corners.B2, BLACK, BLACK)
	zig(corners.A1, corners.B1, WHITE, BLACK)
	zig(corners.A2, corners.B2, WHITE, BLACK)
end

----------------------------------------------------------------------------------------------------
-- the pads' post screens: "PAD n" and who is registered on it, in the NEWSPRINT kit (Quick Play's dialect)
----------------------------------------------------------------------------------------------------
-- Each post's screen part is 1.24 x 1.00 studs; at 200 pixels a stud its SurfaceGui canvas is 248 x 200. Paper edge to
-- edge in a 4 px ink border, a halftone patch top right, the pad's number on a tilted gold slab, then one Card row per
-- registered player (side A first: Element chip, name, Element), a dashed WAITING box for the missing second player, or
-- one OPEN slab when nobody is on the pad. Built once per pad at startup; updatePost only changes what shows.
local PK = {
	Ink = Color3.fromRGB(17, 17, 17), Paper = Color3.fromRGB(234, 229, 216), Card = Color3.fromRGB(246, 243, 235),
	Pill = Color3.fromRGB(250, 247, 240), Gold = Color3.fromRGB(245, 184, 0), Grey = Color3.fromRGB(120, 116, 106),
	LockedInk = Color3.fromRGB(88, 82, 72),
}
local POST_MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local POST_DOT = "rbxassetid://82944445925061"      -- the kit's halftone cell
local POST_PPS = 200
local POST_SHADOW, POST_BORDER, POST_RADIUS = 5, 3, 3

local function ui(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

--- the kit's slab: a transparent holder (its size includes the shadow) > one solid ink shadow down-right + the face, with
--- a heavy ink border and near-square corners. Returns holder, face.
local function postSlab(parent, x, y, w, h, colour, z)
	local holder = ui("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 2,
	}, parent)
	local shadow = ui("Frame", {
		Name = "Shadow", BackgroundColor3 = PK.Ink, BorderSizePixel = 0, ZIndex = 1,
		Position = UDim2.fromOffset(POST_SHADOW, POST_SHADOW), Size = UDim2.new(1, -POST_SHADOW, 1, -POST_SHADOW),
	}, holder)
	ui("UICorner", { CornerRadius = UDim.new(0, POST_RADIUS) }, shadow)
	local face = ui("Frame", {
		Name = "Face", BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = 2,
		Size = UDim2.new(1, -POST_SHADOW, 1, -POST_SHADOW),
	}, holder)
	ui("UICorner", { CornerRadius = UDim.new(0, POST_RADIUS) }, face)
	ui("UIStroke", { Color = PK.Ink, Thickness = POST_BORDER, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
	return holder, face
end

--- one registered player: a 224 x 56 Card slab with the Element chip, the name and the Element under it
local function postRow(parent, y)
	local holder, face = postSlab(parent, 12, y, 224, 56, PK.Card, 3)
	holder.Name = "Row"
	local chip = ui("Frame", {
		Name = "Chip", BackgroundColor3 = PK.Grey, BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(36, 36), ZIndex = 3,
	}, face)
	ui("UICorner", { CornerRadius = UDim.new(0, 2) }, chip)
	ui("UIStroke", { Color = PK.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
	local name = ui("TextLabel", {
		Name = "PlayerName", BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 5), Size = UDim2.fromOffset(157, 26),
		Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PK.Ink, Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	}, face)
	ui("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, name)
	local element = ui("TextLabel", {
		Name = "Element", BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 31), Size = UDim2.fromOffset(157, 14),
		FontFace = POST_MONO, TextSize = 14, TextColor3 = PK.LockedInk, Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
	}, face)
	return { holder = holder, chip = chip, name = name, element = element }
end

--- the kit's dashed box (6 px dashes, 4 px gaps, 2 thick, LockedInk) round "WAITING"
local function postWaiting(parent, x, y, w, h)
	local root = ui("Frame", {
		Name = "Waiting", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = 3,
	}, parent)
	local DASH, GAP, T = 6, 4, 2
	local function run(horizontal, fixed)
		local length = horizontal and w or h
		local at = 0
		while at < length do
			local n = math.min(DASH, length - at)
			ui("Frame", {
				BackgroundColor3 = PK.LockedInk, BorderSizePixel = 0, ZIndex = 3,
				Position = horizontal and UDim2.fromOffset(at, fixed) or UDim2.fromOffset(fixed, at),
				Size = horizontal and UDim2.fromOffset(n, T) or UDim2.fromOffset(T, n),
			}, root)
			at += DASH + GAP
		end
	end
	run(true, 0)
	run(true, h - T)
	run(false, 0)
	run(false, w - T)
	ui("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = POST_MONO, TextSize = 15,
		TextColor3 = PK.LockedInk, Text = "WAITING", ZIndex = 3,
	}, root)
	return root
end

local function buildPost(pad)
	local screen = pad.screen
	if not screen then
		warn("[HubServer] duel pad " .. pad.tag .. " has no post screen (PC_DuelPad_" .. pad.tag .. "_Screen)")
		return
	end
	local old = screen:FindFirstChild("PadScreen")
	if old then old:Destroy() end
	local sg = ui("SurfaceGui", {
		Name = "PadScreen", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = POST_PPS, LightInfluence = 0, AlwaysOnTop = false, MaxDistance = 60, ClipsDescendants = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	ui("Frame", { Name = "Paper", BackgroundColor3 = PK.Paper, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, sg)
	ui("ImageLabel", {
		Name = "Halftone", BackgroundTransparency = 1, Image = POST_DOT, ImageColor3 = PK.Ink, ImageTransparency = 0.9,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(150, 4), Size = UDim2.fromOffset(94, 56), ZIndex = 1,
	}, sg)
	local border = ui("Frame", {
		Name = "Border", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 10,
	}, sg)
	ui("UIStroke", { Color = PK.Ink, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, border)
	-- the pad's number on a tilted gold slab
	local head, headFace = postSlab(sg, 12, 10, 150, 40, PK.Gold, 4)
	head.Name = "Header"
	head.Rotation = -1.5
	ui("TextLabel", {
		Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 2), Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.LuckiestGuy, TextSize = 30, TextColor3 = PK.Ink, Text = "PAD " .. pad.number, ZIndex = 3,
	}, headFace)
	-- nobody on the pad: one OPEN slab, gold lettering over a solid ink copy 3 px down-right
	local open, openFace = postSlab(sg, 12, 62, 224, 122, PK.Pill, 3)
	open.Name = "Open"
	for i, spec in ipairs({ { PK.Ink, 3, 3 }, { PK.Gold, 0, 4 } }) do
		local l = ui("TextLabel", {
			Name = (i == 1) and "OpenExtrude" or "OpenWord", BackgroundTransparency = 1,
			Position = UDim2.fromOffset(spec[2], spec[2] + 3), Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.LuckiestGuy, TextSize = 46, TextColor3 = spec[1], Text = "OPEN", ZIndex = spec[3],
		}, openFace)
		ui("UIStroke", { Color = PK.Ink, Thickness = 2 }, l)
	end
	local post = {
		open = open,
		row1 = postRow(sg, 62),
		row2 = postRow(sg, 128),
		waiting = postWaiting(sg, 12, 128, 219, 51),
	}
	post.row1.holder.Visible, post.row2.holder.Visible, post.waiting.Visible = false, false, false
	sg.Parent = screen
	pad.post = post
end

local function fillRow(row, p)
	local el = elementOf(p)
	row.chip.BackgroundColor3 = el and el.Base or PK.Grey
	row.name.Text = string.upper(p.DisplayName)
	row.element.Text = el and string.upper(el.Display or tostring(p:GetAttribute("Element"))) or "NO ELEMENT"
end

local function updatePost(pad)
	local post = pad.post
	if not post then return end
	local first = pad.occ.A or pad.occ.B                    -- side A's player first
	local second = (pad.occ.A and pad.occ.B) or nil
	post.open.Visible = first == nil
	post.row1.holder.Visible = first ~= nil
	post.row2.holder.Visible = second ~= nil
	post.waiting.Visible = first ~= nil and second == nil
	if first then fillRow(post.row1, first) end
	if second then fillRow(post.row2, second) end
end

local function setState(pad, state, who)
	if pad.state == state and pad.who == who then return end
	pad.state, pad.who = state, who
	-- each half of the ring in its player's Element colour (the old orrery pads lit A white and B black)
	paint(pad.ra, ringColour(pad.occ.A))
	paint(pad.rb, ringColour(pad.occ.B))
	-- the orrery shards and core (none on the Observatory's pads; kept so the old pads would still work)
	local a, b = pad.occ.A ~= nil, pad.occ.B ~= nil
	if pad.sa then pad.sa.Color = a and WHITE or WHITE_IDLE end
	if pad.sb then pad.sb.Color = b and BLACK or BLACK_IDLE end
	if pad.core then pad.core.Color = (state == "full") and WHITE or CORE_IDLE end
	local ang = SHARD_ANGLES[state]
	orbit(pad, pad.sa, pad.restA, REST[1], ang[1])
	orbit(pad, pad.sb, pad.restB, REST[2], ang[2])
	buildWard(pad)
	updatePost(pad)
end

for n = 1, PAD_COUNT do
	local tag = "P" .. n
	local ref = find("PC_DuelPad_" .. tag .. "_Centre")
	local ra, rb = find("PC_DuelPad_" .. tag .. "_RuneA"), find("PC_DuelPad_" .. tag .. "_RuneB")
	if ref and ra and rb then
		local flat = ref.CFrame.LookVector * Vector3.new(1, 0, 1)
		local axis = flat.Magnitude > 0.01 and flat.Unit or Vector3.zAxis
		local pad = {
			tag = tag, number = n, ra = ra, rb = rb, screen = find("PC_DuelPad_" .. tag .. "_Screen"),
			centre = ref.Position, axis = axis, across = axis:Cross(Vector3.yAxis),
			k = axis:Cross(Vector3.yAxis),
			state = "empty", occ = {}, launching = false,
		}
		paint(ra, RING_IDLE)
		paint(rb, RING_IDLE)
		buildPost(pad)
		updatePost(pad)
		local a = anchor("DuelPadPrompt_" .. tag, CFrame.new(pad.centre + Vector3.new(0, 3, 0)))
		pad.prompt = prompt(a, "SOLO TEST", "Duel Pad", 0.6, 9)
		pad.prompt.Enabled = false
		pad.prompt.Triggered:Connect(function(p)
			local alone = (pad.occ.A == p and pad.occ.B == nil) or (pad.occ.B == p and pad.occ.A == nil)
			if alone and not pad.launching then
				pad.launching = true
				sendToArena({ p }, "Solo")
				task.delay(3, function() pad.launching = false end)
			end
		end)
		pads[tag] = pad
	else
		warn("[HubServer] duel pad " .. tag .. " is missing its Centre, RuneA or RuneB")
	end
end

local function padOf(p)
	-- someone in a map vote is already matched: the pad lets them go, so it cannot start a second match
	-- (2026-10-28) nor anyone on the way to a cross-server match, nor anyone at all in a match server (its pads are off)
	if p:GetAttribute("Zone") ~= "Hub" or voting[p] or moving[p] or Matchmaker.Busy(p) then return nil end
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) then return nil end
	-- round pads: on one = within OCC_R of its centre; the side is which half of the ring you stand on
	for _, pad in pairs(pads) do
		local rel = hrp.Position - pad.centre
		if rel.Y > -1 and rel.Y < 9 and Vector3.new(rel.X, 0, rel.Z).Magnitude < OCC_R then
			return pad, (rel:Dot(pad.axis) < 0) and "A" or "B"
		end
	end
end

task.spawn(function()
	while true do
		local seen = {}
		for _, pad in pairs(pads) do seen[pad] = {} end
		for _, p in ipairs(Players:GetPlayers()) do
			local pad, side = padOf(p)
			if pad and not seen[pad][side] then seen[pad][side] = p end
		end
		for _, pad in pairs(pads) do
			local s = seen[pad]
			pad.occ.A, pad.occ.B = s.A, s.B
			local state = (s.A and s.B) and "full" or (s.A and "waitA") or (s.B and "waitB") or "empty"
			local who = (s.A and s.A.UserId or 0) .. ":" .. (s.B and s.B.UserId or 0)
			-- the look also carries both Elements, so the ring and the post repaint when someone changes Element on the pad
			local look = who .. ":" .. tostring(s.A and s.A:GetAttribute("Element")) .. ":" .. tostring(s.B and s.B:GetAttribute("Element"))
			setState(pad, state, look)
			pad.prompt.Enabled = (state == "waitA" or state == "waitB") and not pad.launching
			if state == "full" and not pad.launching then
				if pad.pair ~= who then pad.pair, pad.fullSince = who, os.clock() end
				local left = COUNTDOWN - (os.clock() - pad.fullSince)
				local group = { s.A, s.B }
				if left <= 0 then
					pad.launching = true
					for _, p in ipairs(group) do hubRemote:FireClient(p, "countdown", 0) end
					sendToArena(group, "Duel")
					task.delay(3, function()
						pad.launching = false
						pad.pair = nil
					end)
				else
					for _, p in ipairs(group) do hubRemote:FireClient(p, "countdown", math.ceil(left)) end
				end
			elseif state ~= "full" then
				pad.pair, pad.fullSince = nil, nil
			end
		end
		task.wait(0.2)
	end
end)

----------------------------------------------------------------------------------------------------
-- (2026-10-28) the queue across servers, and a match server's part: Matchmaker, with this script's hands
----------------------------------------------------------------------------------------------------
Matchmaker.Init({
	Notify = notify,
	Dequeued = dequeued,
	Requeued = function(p, text) hubRemote:FireClient(p, "queued", true, text) end,
	QueueCount = function(p, have, needed) hubRemote:FireClient(p, "queueCount", have, needed) end,
	CanGo = function(p)
		return p.Parent ~= nil and p:GetAttribute("Zone") == "Hub" and not voting[p] and not moving[p] and not DuelMatch.Of(p)
	end,
	IsMoving = function(p) return moving[p] == true end,
	StartLocal = function(group) sendToArena(group, "Team") end,              -- first half against second half
	StartMatch = function(group, teams) sendToArena(group, "Team", teams) end,
	Holds = DuelMatch.Holds,
})

----------------------------------------------------------------------------------------------------
-- Quick Play, SOLO TEST, the map vote and BACK TO HUB
----------------------------------------------------------------------------------------------------
hubRemote.OnServerEvent:Connect(function(p, what, mode, choice)
	if what == "vote" then
		-- clicks in a vote come quicker than the menus' 0.25 s, so they have their own limit
		local now = os.clock()
		if now - (lastVote[p] or 0) < VOTE_RATE then return end
		lastVote[p] = now
		local vote = voting[p]
		if not vote or vote.Done or vote.Id ~= mode then return end
		for _, c in ipairs(vote.Choices) do
			if c.Id == choice then
				vote.Picks[p] = choice
				tally(vote)
				break
			end
		end
		return
	end
	-- CANCEL is never throttled (2026-10-18 review): a quick QUEUE then CANCEL used to leave the player in the team queue
	-- nor is BACK TO HUB (2026-10-30): a throttled one left the button on HEADING BACK for 6 s with nothing happening, and
	-- moveTo already turns away a second move while one is on
	if what ~= "cancel" and what ~= "return" and throttled(p) then return end
	local inArena = p:GetAttribute("Zone") == "Arena"
	if what == "return" then
		if DuelMatch.Of(p) then
			-- mid-duel only a dev may leave (the dev panel's rule), and leaving forfeits the match
			if Config.IsDev(p) then
				DuelMatch.Leave(p)
			else
				notify(p, "You can't leave a duel in progress.")
			end
		elseif inArena then
			task.spawn(moveTo, p, "Hub")
		end
	elseif what == "queue" then
		if inArena then
			dequeued(p, "You are in the arena. Go BACK TO HUB first, then queue from there.")
		elseif voting[p] then
			dequeued(p, "You are already in a match -- finish the map vote.")
		elseif DuelMatch.Of(p) then
			-- a duel's round 1 keeps the Hub Zone until the new body is on its mark (respawnTo): queued now, a duellist
			-- would stay queued into the arena, and the next player to queue would be paired with them mid-duel
			dequeued(p, "You are in a duel -- queue again once it is over.")
		elseif moving[p] then
			-- mid-move, on either side of the Zone change (into the Hub, or still in the Hub on the way out)
			dequeued(p, "You are being moved -- queue from the Hub once you are standing in it.")
		elseif Matchmaker.IsMatchServer() then
			dequeued(p, "This server is running one match -- QUEUE is off here.")
		elseif mode ~= "Duel" then
			dequeued(p, "Only DUEL can start a match in this build. Pick DUEL, or use SOLO TEST.")
		elseif Matchmaker.Global() then
			-- (2026-10-28) one queue for every server: a ticket Matchmaker matches by region first, then with anyone
			task.spawn(Matchmaker.Enqueue, p)
		else
			-- (2026-10-18, team mode) DUEL is the team match now: the queue fills to two teams (popTeams), not to a pair.
			-- (Until then the first two queued were paired into a 1v1 "Duel"; the Hub's pads still start those.)
			if not table.find(queue, p) then table.insert(queue, p) end
			popTeams()
		end
	elseif what == "cancel" then
		unqueue(p, "cancel")
	elseif what == "solo" then
		unqueue(p)
		if inArena then
			notify(p, "You are already in the arena.")
		elseif voting[p] then
			notify(p, "You are already in a map vote.")
		else
			sendToArena({ p }, "Solo")
		end
	end
end)
