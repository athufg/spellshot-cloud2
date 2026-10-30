--[[
	DuelMatch  (ModuleScript)  ->  ServerScriptService/DuelMatch

	The Duel's round loop (Build Prompt #24), and since 2026-10-18 the TEAM MATCH's too (team mode: the owner's "Team-comp
	only: one mode, one ruleset", scoped that day to "3v3s on the duel loop but only in menu, ignore hub"). HubServer
	confirms a match -- a Hub duel pad (two players: a 1v1, kind "Duel") or Quick Play's queue (two teams of
	Config.Team.Size, kind "Team") -- then the map vote, and hands the players over; this runs the rounds, keeps the score
	and ends the match. Solo Test never comes here: it stays a sandbox.

	ONE LOOP FOR BOTH. A 1v1 is a match of two teams of one, so every rule below is written for teams and a duel is the
	case where each team is one player. A pad duel reads Config.Duel; a team match reads Config.Team first and Config.Duel
	for anything Config.Team leaves out (rule(), below).

	A MATCH
	  Begin(group, map, teams, kind)  the players are this match's from here on, and round 1 starts at once. `teams` is
	                      { { players of team 1 }, { players of team 2 } } (nil: group[1] against group[2]).
	  a round starts      under the wipe each player is cleared (CombatCore.ClearPlayer: nothing they cast is left
	                      running) and rebuilt on their team's mark with LoadCharacter -- full health and mana, every
	                      cooldown and charge back, the loadout untouched -- then revealed. Teammates stand side by side
	                      across the line between the marks (HubServer's TeamSpot; one a side is the mark itself). The
	                      round is live from there.
	  a round ends        when a whole team is down: the last team standing takes it (DEATHS, below). Or when its clock
	                      runs out (RoundTime; added 2026-10-17): then the larger TEAM share of health takes it -- the sum
	                      of the team's health over the sum of its max health, a player who is down or gone counting 0 of
	                      their max -- and equal shares are a draw. RoundEndPause seconds, then the next round or the end.
	  the match ends      at FirstTo round wins. The winner is declared, and after MatchEndHold everyone goes back to the
	                      Hub the way BACK TO HUB goes (a player who is down is rebuilt in the Hub instead). (2026-10-19,
	                      audit P3-14) From the result to the trip home everyone is CastLocked, and HubServer's respawn
	                      hold (DuelMatch.Holds) keeps the dead down: the result screen is not a fifth round.
	                      (2026-10-19, audit P3-13) Or at MaxRounds rounds played, so rounds that keep drawing cannot stall
	                      it for ever: the side with more round wins takes it, and equal wins are a DRAW (Result "draw",
	                      which the economy pays as one).

	OUT FOR THE ROUND (2026-10-18). A player who goes down stays down until the round is over: nobody comes back mid-round,
	and the camera stays on the body. HubServer took Roblox's respawn over that day and holds anyone DuelMatch.Of still
	answers for; the next round's LoadCharacter brings everyone back. A player who goes down while teammates stand is told
	("match", "out").

	ULTIMATE CHARGE starts the match at 0 and carries from round to round: SpellshotService hands a respawned character
	the charge its last one had while the player's "DuelMatch" attribute is set.

	SIDES. Round 1's marks are a coin flip, and round 2 keeps them. From SwapFromRound on, every round flips its own coin
	(SwapChance) to swap them -- a fresh flip each round, not an alternation. The marks themselves are HubServer's
	arenaSpot(side, mapId); only which team stands on which changes.

	DEATHS. CombatCore stamps the FRAME in which a hit takes a humanoid to 0 (Core.FrameClock in the damage path, not a
	poll; os.clock() until 2026-10-19, audit P3-15); a death from anywhere else is stamped with the same clock when its Died
	fires, so deaths in one frame -- one AoE taking the last of both teams -- are simultaneous whatever order they ran in.
	A team is DOWN at the instant its last player fell. The first
	team down ends the round, and the round is settled on the next frame, so a death already processed by then is seen
	too. The team down first loses -- the other wins, even if its last player falls a moment later to a hit that was
	already in flight. Only two teams down less than DRAW_WINDOW apart, which the server cannot put in order, are a draw,
	and a draw scores for nobody. (One a side, that is the 1v1 rule exactly: whoever died first loses.)

	LEAVING. BACK TO HUB during a match is for devs only (HubServer checks Config.IsDev, the dev panel's rule). A player who
	leaves -- a dev's BACK TO HUB, or a disconnect -- leaves their team short-handed (2026-10-18): they count as down for the
	rest of the match (0 health on the clock) and the others are told ("match", "left"). A team with nobody left forfeits:
	the other team wins the match. One a side, any leaver forfeits, as a duel always did. A player leaving during the map
	vote, before any match exists, is HubServer's.

	THE ECONOMY (2026-10-18). When a team match ends, everyone still in the game and still in the match gets
	PlayerData.AwardMatch(player, "win" | "loss" | "draw", their team's round wins). PlayerData is the economy's module
	(another session's); a missing module or an error in it never stops a match ending. A Hub pad duel awards nothing.

	PLAYER ATTRIBUTES  DuelMatch (the match id), MatchTeam ("A" | "B": which TEAM, not which mark; Config.MayHurt keeps
	                   teammates from hurting each other), CanLeaveMatch (true: BACK TO HUB stays on this dev's screen),
	                   RoundsWon / RoundsLost (the HUD's round counter: THE TEAM's round wins and the other team's),
	                   RoundEndsAt (when a live round's clock runs out, in workspace:GetServerTimeNow() time; the HUD
	                   counts down to it). All cleared as the match sends them home.
	HUB REMOTE         ("match", "round" | "roundEnd" | "end" | "out" | "left", data), from the receiver's point of view:
	                   { Round, Me, Them, Opponent, FirstTo, Team = true (a team match), Allies = { names }, Foes = { names },
	                     Result = "win" | "loss" | "draw", How = "rounds" | "forfeit" }
	                   ("roundEnd" also carries How = "time" when the clock settled the round; "out" carries Standing,
	                   the teammates still up; "left" carries Who and Ally)

	ONE MATCH PER MAP COPY is assumed. Two matches on the same map share its one copy; instancing is later work.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local spellFolder = ReplicatedStorage:WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Core = require(script.Parent:WaitForChild("CombatCore"))

local D = Config.Duel
-- Two deaths closer together than this cannot be put in order at the resolution the stamps are trusted to: a draw.
local DRAW_WINDOW = 0.001
-- MatchTeam's values, team 1 and team 2 (2026-10-18, team mode)
local TEAM_NAMES = { "A", "B" }

local DuelMatch = {}

--- A round rule for `match` (2026-10-18, team mode): a team match takes Config.Team's when it has one, and Config.Duel's
--- otherwise; a pad duel always takes Config.Duel's.
local function rule(match, name)
	local T = Config.Team
	if match and match.Kind == "Team" and T and T[name] ~= nil then return T[name] end
	return D[name]
end

----------------------------------------------------------------------------------------------------
-- the rules, as plain functions
----------------------------------------------------------------------------------------------------
--- Round 1's marks for teams 1 and 2.
function DuelMatch.FirstSides(roll)
	if roll() < 0.5 then
		return { "A", "B" }
	end
	return { "B", "A" }
end

--- The marks for `round`, from the round before's. Rounds before SwapFromRound keep them; from SwapFromRound each
--- round swaps them on its own coin flip. (`swapFrom` / `swapChance`: a team match's own, else Config.Duel's.)
function DuelMatch.NextSides(prev, round, roll, swapFrom, swapChance)
	if round >= (swapFrom or D.SwapFromRound) and roll() < (swapChance or D.SwapChance) then
		return { prev[2], prev[1] }
	end
	return { prev[1], prev[2] }
end

--- Who took the round, from { [1] = when team 1 went down, [2] = when team 2 did } (nil while standing): 1, 2 or "draw".
function DuelMatch.Resolve(deaths)
	local a, b = deaths[1], deaths[2]
	if a and b then
		if math.abs(a - b) < DRAW_WINDOW then return "draw" end
		return (a < b) and 2 or 1
	end
	if a then return 2 end
	if b then return 1 end
	return "draw"
end

--- When a team went down (2026-10-18, team mode), from its players' death times ({ [player] = time }, nil while
--- standing): the moment the last of them fell, or nil while any of them stands.
function DuelMatch.DownAt(deaths, members)
	local last = nil
	for _, p in ipairs(members) do
		local t = deaths[p]
		if not t then return nil end
		if not last or t > last then last = t end
	end
	return last
end

--- A team's share of health for the round clock (2026-10-18, team mode), from rows { Health, Max }: the sum of health over
--- the sum of max health. A player who is down or gone is a row with Health 0.
function DuelMatch.Share(rows)
	local have, max = 0, 0
	for _, r in ipairs(rows) do
		have += math.max(r.Health or 0, 0)
		max += math.max(r.Max or 0, 0)
	end
	return (max > 0) and have / max or 0
end

----------------------------------------------------------------------------------------------------
-- running a match
----------------------------------------------------------------------------------------------------
local hub              -- HubServer's side: Remote, MoveTo, Respawn, ArenaSpot, TeamSpot, IsMoving (DuelMatch.Init)
local matches = {}     -- [player] = the match they are in, until it sends them home
local serial = 0
local rng = Random.new()
local function roll()
	return rng:NextNumber()
end

function DuelMatch.Init(hooks)
	hub = hooks
end

--- The match `player` is fighting in, or nil once it is over.
function DuelMatch.Of(player)
	local match = matches[player]
	if match and match.State ~= "Over" then return match end
	return nil
end

local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

--- Still in this match: in the game, and has not left it.
local function present(match, player)
	return player.Parent ~= nil and not match.Gone[player]
end

--- The display names on team `i`, leaving out `except`.
local function namesOf(match, i, except)
	local list = {}
	for _, q in ipairs(match.Teams[i]) do
		if q ~= except then list[#list + 1] = q.DisplayName end
	end
	return list
end

--- The score as `player`, on team `i`, sees it.
local function scoreFor(match, i, player)
	local foes = namesOf(match, 3 - i)
	return {
		Round = match.Round, Me = match.Wins[i], Them = match.Wins[3 - i], FirstTo = rule(match, "FirstTo"),
		Opponent = (#foes == 1) and foes[1] or ((#foes > 1) and "THEIR TEAM" or "?"),
		Team = (match.Kind == "Team") or nil, Allies = namesOf(match, i, player), Foes = foes,
	}
end

--- Tells everyone still in the match (each from their own side) `kind`; `extra(i, data, player)` adds to what a player on
--- team i is told.
local function tell(match, kind, extra)
	for _, p in ipairs(match.Players) do
		if present(match, p) then
			local i = match.TeamOf[p]
			local data = scoreFor(match, i, p)
			if extra then extra(i, data, p) end
			hub.Remote:FireClient(p, "match", kind, data)
		end
	end
end

local function publishScore(match)
	for _, p in ipairs(match.Players) do
		if present(match, p) then
			local i = match.TeamOf[p]
			p:SetAttribute("RoundsWon", match.Wins[i])
			p:SetAttribute("RoundsLost", match.Wins[3 - i])
		end
	end
end

--- The round clock's end for the HUD's countdown, in workspace:GetServerTimeNow() time (nil: no clock).
local function showClock(match, endsAt)
	for _, p in ipairs(match.Players) do
		if present(match, p) then
			p:SetAttribute("RoundEndsAt", endsAt)
		end
	end
end

local function disconnectAll(match)
	for _, c in ipairs(match.Conns) do
		c:Disconnect()
	end
	table.clear(match.Conns)
end

--- Yields until `ready()` is true or the match is over, for at most `timeout` seconds.
local function waitUntil(match, ready, timeout)
	local deadline = os.clock() + timeout
	while match.State ~= "Over" and not ready() and os.clock() < deadline do
		task.wait(0.05)
	end
end

--- Out of the match: its attributes go, and nothing here holds on to the player.
local function release(match, player)
	if matches[player] == match then matches[player] = nil end
	if not player.Parent then return end
	-- CastLocked too (2026-10-19, audit P3-14): finish() locks everyone for the result screen
	for _, name in ipairs({ "DuelMatch", "MatchTeam", "CanLeaveMatch", "RoundsWon", "RoundsLost", "RoundEndsAt",
		"CastLocked" }) do
		player:SetAttribute(name, nil)
	end
end

--- Back to the Hub the way BACK TO HUB goes; someone who is down is rebuilt there instead of carried there dead.
local function sendHome(player)
	local deadline = os.clock() + 10
	while player.Parent and hub.IsMoving(player) and os.clock() < deadline do
		task.wait(0.1)
	end
	if not player.Parent or player:GetAttribute("Zone") ~= "Arena" then return end
	if alive(player) then
		hub.MoveTo(player, "Hub")
	else
		hub.Respawn(player, "Hub")
	end
end

--- The economy's match reward (2026-10-18, team mode): PlayerData.AwardMatch(player, result, roundsWon) for everyone
--- still in the game and still in the match, in a team match only. PlayerData is the economy's (another session builds
--- it the same day), so it is looked up now, not at load, and nothing it does can stop the match ending.
-- (2026-10-19, audit P2-05) a forfeit before this many rounds were settled pays nobody: a whole team disconnecting at round
-- 1 paid every player left the full win (150+ Sparks in seconds), a loop any group with alt accounts could farm
local FORFEIT_MIN_ROUNDS = 2

local function award(match, winner, how)
	if match.Kind ~= "Team" then return end
	if how == "forfeit" and (match.CountedRound or 0) < FORFEIT_MIN_ROUNDS then return end
	local module = ServerScriptService:FindFirstChild("PlayerData")
	if not module then return end
	local ok, PlayerData = pcall(require, module)
	if not ok or type(PlayerData) ~= "table" or type(PlayerData.AwardMatch) ~= "function" then
		if not ok then warn("[DuelMatch] PlayerData did not load: " .. tostring(PlayerData)) end
		return
	end
	for _, p in ipairs(match.Players) do
		if present(match, p) then
			local i = match.TeamOf[p]
			local result = (winner == 1 or winner == 2) and ((winner == i) and "win" or "loss") or "draw"
			task.spawn(function()
				local done, err = pcall(PlayerData.AwardMatch, p, result, match.Wins[i])
				if not done then warn("[DuelMatch] PlayerData.AwardMatch failed for " .. p.Name .. ": " .. tostring(err)) end
			end)
		end
	end
end

--- The match is over: team `winner` takes it, `how` is "rounds" | "forfeit". Tells whoever is still here, holds the
--- result on screen, then sends them home.
local function finish(match, winner, how)
	if match.State == "Over" then return end
	match.State = "Over"
	disconnectAll(match)
	showClock(match, nil)
	match.Signal:Fire()
	-- (2026-10-19, audit P3-14) the result screen is not a fight: nobody casts from here to the trip home (CanAct and
	-- SpellshotService both read CastLocked; release() takes it off)
	for _, p in ipairs(match.Players) do
		if present(match, p) then p:SetAttribute("CastLocked", true) end
	end
	publishScore(match)
	tell(match, "end", function(i, data)
		-- (2026-10-19, audit P3-13) `winner` is "draw" when MaxRounds ends a level match
		data.Result = (winner == 1 or winner == 2) and ((i == winner) and "win" or "loss") or "draw"
		data.How = how
	end)
	award(match, winner, how)
	task.spawn(function()
		task.wait((how == "forfeit") and rule(match, "ForfeitHold") or rule(match, "MatchEndHold"))
		for _, p in ipairs(match.Players) do
			if not match.Gone[p] then
				release(match, p)
				task.spawn(sendHome, p)
			end
		end
	end)
end

--- Settles the round on the next frame: by then every death processed in this frame has been stamped.
local function settle(match)
	if match.Settling then return end
	match.Settling = true
	task.spawn(function()
		RunService.Heartbeat:Wait()
		if match.State ~= "Live" then return end
		-- a death whose Died has not come through yet still has CombatCore's stamp
		for p, humanoid in pairs(match.Humanoids) do
			if not match.Deaths[p] and humanoid.Health <= 0 then
				match.Deaths[p] = Core.DeathTime(humanoid) or Core.FrameClock()     -- (2026-10-19, audit P3-15)
			end
		end
		match.Result = DuelMatch.Resolve({
			DuelMatch.DownAt(match.Deaths, match.Teams[1]), DuelMatch.DownAt(match.Deaths, match.Teams[2]),
		})
		match.State = "Settled"
		match.Signal:Fire()
	end)
end

local function onDied(match, p, humanoid)
	if match.State ~= "Live" or match.Deaths[p] then return end
	match.Deaths[p] = (humanoid and Core.DeathTime(humanoid)) or Core.FrameClock()     -- (2026-10-19, audit P3-15) DealDamage's clock
	-- (2026-10-19, audit GA-08) the HUD's kill feed (PopArtHUD listens on Spellshot.KillFeed: killer, victim, Element) was
	-- only ever fed by the dev panel. A death a player's hit caused goes to everyone still in this match.
	local killer, element = nil, nil
	if humanoid then killer, element = Core.Killer(humanoid) end
	local feed = spellFolder:FindFirstChild("KillFeed")
	if feed and typeof(killer) == "Instance" and killer:IsA("Player") then
		local who = killer.DisplayName
		element = element or killer:GetAttribute("Element")
		for _, q in ipairs(match.Players) do
			if present(match, q) then feed:FireClient(q, who, p.DisplayName, element) end
		end
	end
	local i = match.TeamOf[p]
	if DuelMatch.DownAt(match.Deaths, match.Teams[i]) then
		settle(match)
	elseif present(match, p) then
		-- out for the rest of the round; the team plays on (2026-10-18, team mode)
		local data = scoreFor(match, i, p)
		local standing = 0
		for _, q in ipairs(match.Teams[i]) do
			if not match.Deaths[q] then standing += 1 end
		end
		data.Standing = standing
		hub.Remote:FireClient(p, "match", "out", data)
	end
end

--- The round's clock ran out with both teams still standing (RoundTime, the 2026-10-17 balance pass): the larger team
--- share of health takes the round; equal shares are a draw, which scores for nobody.
local function timeUp(match, round)
	if match.State ~= "Live" or match.Round ~= round or match.Settling then return end
	local share = {}
	for i = 1, 2 do
		local rows = {}
		for _, p in ipairs(match.Teams[i]) do
			local humanoid = match.Humanoids[p]
			local up = humanoid and not match.Deaths[p] and humanoid.Parent ~= nil
			rows[#rows + 1] = {
				Health = up and humanoid.Health or 0,
				Max = match.MaxHp[p] or (humanoid and humanoid.MaxHealth) or Config.MaxHealth,
			}
		end
		share[i] = DuelMatch.Share(rows)
	end
	if math.abs(share[1] - share[2]) < 1e-6 then
		match.Result = "draw"
	else
		match.Result = (share[1] > share[2]) and 1 or 2
	end
	match.How = "time"
	match.State = "Settled"
	match.Signal:Fire()
end

--- Clears everyone still in the match, rebuilds them on their team's mark under the wipe, and makes the round live.
--- Yields.
local function startRound(match)
	match.Round += 1
	if match.Round > 1 then
		match.Sides = DuelMatch.NextSides(match.Sides, match.Round, roll,
			rule(match, "SwapFromRound"), rule(match, "SwapChance"))
	end
	match.State = "Starting"
	match.Deaths, match.Humanoids, match.Result, match.Settling = {}, {}, nil, false
	match.How = nil
	disconnectAll(match)

	local label = (match.Round > 1) and ("ROUND " .. match.Round) or nil
	local ready, coming = {}, {}
	for i, team in ipairs(match.Teams) do
		-- whoever has left the match is down from the start (short-handed, 2026-10-18)
		local here = {}
		for _, p in ipairs(team) do
			if present(match, p) then here[#here + 1] = p else match.Deaths[p] = 0 end
		end
		for slot, p in ipairs(here) do
			coming[#coming + 1] = p
			-- CASTS ARE SHUT OFF FOR THE RESET (2026-09-21). ClearPlayer is meant to be the line after which nothing of
			-- the old round is left running, but the old body stays alive and in the Arena for the 0.35 s of cover before
			-- LoadCharacter -- and a cast accepted in that window is created with the NEW epoch, so the clear that was
			-- meant to remove it has already gone past. A Flash Freeze zone lives ~4.9 s: cast into the reset, it was
			-- still armed on the spot the sides swap onto when round two went Live, and it cost nothing, because the
			-- respawn refills the bar and clears the cooldowns a moment later.
			p:SetAttribute("CastLocked", true)
			task.spawn(function()
				Core.ClearPlayer(p, "round")
				local side, mapId = match.Sides[i], match.Map.Id
				local spot = hub.TeamSpot and hub.TeamSpot(side, mapId, slot, #here) or hub.ArenaSpot(side, mapId)
				local ok, err = pcall(hub.Respawn, p, "Arena", spot, match.Map, label)
				if not ok then warn("[DuelMatch] could not respawn " .. p.Name .. ": " .. tostring(err)) end
				ready[p] = true
			end)
		end
	end
	waitUntil(match, function()
		for _, p in ipairs(coming) do
			if not ready[p] and present(match, p) then return false end
		end
		return true
	end, rule(match, "StartTimeout"))
	if match.State == "Over" then
		-- (2026-10-19, audit P3-14) left locked: finish() locked everyone for the result screen, and release() unlocks them
		--[[for _, p in ipairs(coming) do p:SetAttribute("CastLocked", nil) end   until 2026-10-19]]
		return
	end

	for _, p in ipairs(coming) do
		local humanoid = present(match, p) and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			match.Humanoids[p] = humanoid
			match.MaxHp[p] = humanoid.MaxHealth
			table.insert(match.Conns, humanoid.Died:Connect(function()
				onDied(match, p, humanoid)
			end))
		end
	end
	for _, p in ipairs(coming) do p:SetAttribute("CastLocked", nil) end
	match.State = "Live"
	local roundTime = rule(match, "RoundTime") or 0
	if roundTime > 0 then
		showClock(match, workspace:GetServerTimeNow() + roundTime)
		task.delay(roundTime, timeUp, match, match.Round)
	end
	tell(match, "round")
	-- no body came back, it is down already, or its player left during the reset: down for this round
	for _, p in ipairs(coming) do
		local humanoid = match.Humanoids[p]
		if not humanoid or humanoid.Health <= 0 then onDied(match, p, humanoid) end
	end
end

local function run(match)
	while match.State ~= "Over" do
		startRound(match)
		while match.State == "Live" do
			match.Signal.Event:Wait()
		end
		showClock(match, nil)
		if match.State == "Over" then break end

		local result = match.Result
		if result ~= "draw" then
			match.Wins[result] += 1
		end
		match.CountedRound = match.Round     -- (2026-10-18 review) drop() asks whether this round's win is in Wins yet
		publishScore(match)
		tell(match, "roundEnd", function(i, data)
			data.Result = (result == "draw") and "draw" or ((result == i) and "win" or "loss")
			data.How = match.How
		end)
		task.wait(rule(match, "RoundEndPause"))
		if match.State == "Over" then break end
		if result ~= "draw" and match.Wins[result] >= rule(match, "FirstTo") then
			finish(match, result, "rounds")
			break
		end
		-- (2026-10-19, audit P3-13) a cap on rounds played: draws score nobody, so two sides that never engage (both full
		-- when the clock runs out) never reached FirstTo, and nobody but a dev can leave a match
		local cap = rule(match, "MaxRounds")
		if type(cap) == "number" and cap > 0 and match.Round >= cap then
			local w1, w2 = match.Wins[1], match.Wins[2]
			finish(match, (w1 > w2) and 1 or ((w2 > w1) and 2 or "draw"), "rounds")
			break
		end
	end
end

--- `group` confirmed on `map` (a MapRegistry entry): the match starts now. `teams` = { { team 1 }, { team 2 } } (nil:
--- group[1] against group[2], a duel); `kind` = "Team" (Quick Play's team match) | "Duel" (a Hub pad's, the default).
function DuelMatch.Begin(group, map, teams, kind)
	teams = teams or { { group[1] }, { group[2] } }
	serial += 1
	local match = {
		Id = serial, Map = map, Kind = kind or "Duel", Teams = { teams[1], teams[2] }, Players = {}, TeamOf = {},
		Wins = { 0, 0 }, Round = 0, Sides = DuelMatch.FirstSides(roll), State = "Starting", Deaths = {}, Humanoids = {},
		MaxHp = {}, Conns = {}, Gone = {}, Signal = Instance.new("BindableEvent"),
	}
	for i, team in ipairs(match.Teams) do
		for _, p in ipairs(team) do
			match.Players[#match.Players + 1] = p
			match.TeamOf[p] = i
			matches[p] = match
			p:SetAttribute("DuelMatch", match.Id)
			p:SetAttribute("MatchTeam", TEAM_NAMES[i])
			p:SetAttribute("CanLeaveMatch", Config.IsDev(p))
			p:SetAttribute("RoundsWon", 0)
			p:SetAttribute("RoundsLost", 0)
			-- every player starts the match with an empty Ultimate; from here it carries across the rounds
			if p.Character then p.Character:SetAttribute("UltCharge", 0) end
		end
	end
	task.spawn(run, match)
	return match
end

--- `player` is out of the match for good -- a disconnect, or a dev's BACK TO HUB (2026-10-18, team mode). Their team plays
--- on short-handed, and they count as down for the round they left in; a team with nobody left forfeits the match.
local function drop(match, player)
	if match.Gone[player] then return end
	match.Gone[player] = true
	if match.State == "Over" then return end
	local i = match.TeamOf[player]
	local anyone = false
	for _, q in ipairs(match.Teams[i]) do
		if present(match, q) then
			anyone = true
			break
		end
	end
	if not anyone then
		-- (2026-10-18 review) a team that has just taken the deciding round has WON, even if it is gone before run() says
		-- so at the end of RoundEndPause: the round is settled its way, counted into Wins already or about to be
		if match.State == "Settled" and match.Result == i then
			local wins = match.Wins[i] + ((match.CountedRound == match.Round) and 0 or 1)
			if wins >= rule(match, "FirstTo") then
				finish(match, i, "rounds")
				return
			end
		end
		finish(match, 3 - i, "forfeit")
		return
	end
	if not match.Deaths[player] then
		match.Deaths[player] = Core.FrameClock()           -- (2026-10-19, audit P3-15) the deaths' clock; os.clock() before
		if match.State == "Live" and DuelMatch.DownAt(match.Deaths, match.Teams[i]) then settle(match) end
	end
	tell(match, "left", function(t, data)
		data.Who = player.DisplayName
		data.Ally = (t == i)
	end)
end

--- (2026-10-19, audit P3-14) Whether the match still holds `player` -- true from Begin until it sends them home, through
--- the result screen, when DuelMatch.Of already answers nil. HubServer's respawn takeover holds the dead while this is true.
function DuelMatch.Holds(player)
	return matches[player] ~= nil
end

--- A dev leaving mid-match (HubServer has already checked Config.IsDev): they leave the match and go home now. Their team
--- plays on without them -- or, if nobody of it is left, forfeits, and the other team is told it won.
function DuelMatch.Leave(player)
	local match = DuelMatch.Of(player)
	if not (match and match.TeamOf[player]) then return false end
	drop(match, player)
	release(match, player)
	task.spawn(sendHome, player)
	return true
end

-- A player who disconnects leaves their team short-handed (one a side: a forfeit).
Players.PlayerRemoving:Connect(function(player)
	local match = matches[player]
	if not match then return end
	matches[player] = nil
	if match.TeamOf[player] and match.State ~= "Over" then
		drop(match, player)
	end
	-- (2026-10-19, audit P3-07) and out of the match's attributes, as release() does for everyone else: a leaver kept
	-- DuelMatch / MatchTeam, so Config.MayHurt still let anything of theirs left running hurt their old opponents
	release(match, player)
end)

return DuelMatch
