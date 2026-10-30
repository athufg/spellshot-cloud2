# Team mode (3v3 on the duel loop), 2026-10-18

The owner's call: "Team-comp only: one mode, one ruleset; drop 1v1 Duel as a parallel mode", scoped this session to "3v3s on the duel loop but only in menu, ignore hub".

Quick Play's DUEL now queues for a team match: two teams of `Config.Team.Size` (3), run by the same `DuelMatch` loop that ran 1v1 duels. The Hub's duel pads and their flow are unchanged and still start a 1v1 on `Config.Duel`. No HP or kit number changed.

Edited live in Studio over Team Create, which keeps its own versions. No manual save, no publish, no Play mode.

## Backup inside the place

`ServerStorage.TeamModeSuperseded_2026_10_18` holds an untouched copy of each of the 8 scripts this change edited:
- Each copy has an `OriginalPath` attribute.
- Scripts and LocalScripts are disabled.
- Child instances were not copied.

New and changed lines are marked `(2026-10-18, team mode)`. Changed values keep the old one in a `--[[<old> until 2026-10-18 team mode]]` note. Search for `2026-10-18` to find them all.

## The new Config knobs (`ReplicatedStorage.Spellshot.SpellshotConfig`)

`Config.Team`, which sits right after `Config.Duel`:

| Key | Value | Meaning |
|---|---|---|
| `Size` | 3 | Players per team. The queue starts a match at 2 × Size. **1 makes it a 1v1, for a two-client test.** |
| `FirstTo` | 5 | Round wins that take a team match. |
| `RoundTime` | 90 | Seconds before the clock settles a round by team health share. 0 turns the clock off. |
| `SpawnSpacing` | 6 | Studs between teammates on their mark, across the line from one mark to the other. |
| `SpawnFloorDrop` | 10 | How far below its spot a teammate's floor may be. With no floor there, or a wall between the spot and the mark, that teammate stands on the mark. |
| `VoteSeconds` | 15 | Length of the map vote before a team match. A pad duel's vote is still 12 s. |

A team match reads a round rule from `Config.Team` first, and from `Config.Duel` when `Config.Team` leaves it out (`rule()` in DuelMatch). So `RoundEndPause`, `MatchEndHold`, `ForfeitHold`, `SwapFromRound`, `SwapChance` and `StartTimeout` can each be added to `Config.Team` to give the team match its own value. A pad duel reads only `Config.Duel`.

## What changed, script by script

### `ReplicatedStorage.Spellshot.SpellshotConfig`
- `Config.MayHurt(caster, victim)`: two players in the same match with the same `MatchTeam` attribute may not hurt each other. Everything else is as before.
- That one rule reaches:
  - the server, through `CombatCore.IsFriendly`, so teammates deal each other no damage, slows, roots, status or reactions;
  - `CombatCore.IsAllyOf`, so teammates count as allies;
  - every client, through `Config.AddUnhurtable` and each kit's `MayHurt` checks, so shots pass through teammates and the crosshair ignores them.
- New `Config.Team` block (above). `ElementMayHold` and `TechniquesFor` were not touched.

### `ServerScriptService.DuelMatch` (rewritten; full source in `team_mode_2026_10_18/src/DuelMatch.luau`)
One loop for both kinds of match. A 1v1 is two teams of one, so the pad duel's behaviour is unchanged. The header comment has the full rules.

- **`Begin(group, map, teams, kind)`**
  - `teams = { {team 1}, {team 2} }`, or nil for `group[1]` against `group[2]`.
  - `kind = "Team"` (Quick Play) or `"Duel"` (a pad, the default).
- **Round end**
  - A team is down when its last player falls. The team down first loses, and two teams down less than 1 ms apart is a draw. With one player a side, this is the old rule exactly.
  - When the clock runs out, the larger team share wins: the sum of the team's health over the sum of its max health, with the down and the gone counted at 0. Equal shares are a draw.
- **Out for the round:** a player who goes down stays down until the round ends. They are told with `("match", "out")`, which carries how many teammates are still standing.
- **Leavers**
  - A disconnect, or a dev's BACK TO HUB, leaves the team short-handed. The leaver counts as down for the rest of the match, and the others are told with `("match", "left")`.
  - A team with nobody left forfeits.
- **Spawns:** players are rebuilt on `hub.TeamSpot(side, mapId, slot, count)`.
- **Economy:** at the end of a team match, `PlayerData.AwardMatch(player, "win"|"loss"|"draw", teamRoundsWon)` runs for everyone still in the game and still in the match.
  - The module is looked up at match end, behind a nil check and a pcall, and each call runs in its own thread.
  - Pad duels award nothing.
- **New player attribute `MatchTeam`** (`"A"` or `"B"`) is set and cleared together with `DuelMatch`. It names the team, not the mark.
- **`RoundsWon` / `RoundsLost`** now hold the team's score and the other team's. PopArtHUD's round plate reads these, so it needed no change.
- **Remote data** gains `Team = true`, `Allies = {names}`, `Foes = {names}`, `Standing`, `Who` and `Ally`.

### `ServerScriptService.HubServer`
- **Queue**
  - `queue` fills to `2 × Size` (`popTeams`). It takes the first players who can go now, in queue order, shuffles them, and splits them down the middle.
  - Every queued player gets `("queueCount", have, need)` whenever the count changes: on queue, cancel, a disconnect, a pad or the portal taking them, and a match popping.
- **Map vote**
  - The vote rows carry `Team`. A team vote lasts `Config.Team.VoteSeconds`.
  - When someone leaves a team vote, it is called off and everyone left goes back to the front of the queue (`("queued", true, reason)`).
- **`enterArena(group, "Team", map)`** passes the two halves to `DuelMatch.Begin(..., "Team")`.
- **`teamSpot(side, mapId, slot, count)`**
  - Places teammates side by side, perpendicular to the A→B line, `SpawnSpacing` apart and centred on the mark, all facing the way the mark faces.
  - A spot is used only if a ray from the mark to it is clear and a floor ray finds ground within `SpawnFloorDrop`. Otherwise that teammate gets the mark itself.
  - It is passed to DuelMatch as the `TeamSpot` hook.
- **Respawns now run in HubServer.**
  - At start it saves `Players.RespawnTime` (3), then sets it to `1e6` so the engine's own respawn never fires.
  - It respawns every dead player itself after those 3 s, except anyone `DuelMatch.Of` still answers for or anyone mid-move. The round loop rebuilds those players.
  - In the Hub, in Solo Test, and after a match ends, behaviour is the same as before.
- The pad flow, `VOTE_SECONDS`, the gate, the "return" and "solo" handlers are unchanged.

### `StarterPlayer.StarterPlayerScripts.HubClient`
- **Team banners** (when `d.Team`):
  - "ROUND 1 · FIRST TO 5 · 3v3";
  - "YOUR TEAM TAKES THE ROUND!" / "THEY TAKE THE ROUND";
  - "YOUR TEAM WINS!" / "THEIR TEAM WINS";
  - "YOU'RE OUT! · BACK NEXT ROUND · n TEAMMATES STANDING";
  - a toast when someone leaves.
  - The score line reads "YOUR TEAM 2 - 1 THEM".
  - Duel banners are unchanged.
- **Teammate outlines:** every living teammate gets a gold Highlight (outline only, seen through walls), parented under the camera on this client only.
  - Gold rather than cyan, because the round plate already uses red for your score and cyan for theirs.
  - Enemies get no outline.
- **Relays to Quick Play:** `queueCount` becomes the `count` command ("3/6"), and `queued true` becomes the `requeued` command.

### `StarterPlayer.StarterPlayerScripts.QuickPlay`
- The DUEL card's subtitle is now "3v3 · TEAMS, FIRST TO 5", built from `Config.Team`. It was "1v1 · STEP ON, FIGHT NOW".
- **While queued**
  - The chip reads "DUEL 3/6 · 0:12".
  - The footer reads "Queued for DUEL 3v3 -- 3/6 in the queue."
- New Command verbs: `count` and `requeued`.

### `StarterPlayer.StarterPlayerScripts.MapVote`
- A `Kind = "Team"` vote shows "TEAMS · 3v3" and "YOU + ALLY, ALLY vs FOE, FOE, FOE".
- With more than 2 voters, each card shows YOU plus a "+N" chip, because six name chips do not fit a card.

### `ServerScriptService.CombatCore`
Comments only. They now say that teammates are friendly and allies through MayHurt's `MatchTeam` clause.

### `ServerScriptService.ZephyrGustPadServer`
`eligible()` checked `Core.SameParty` rather than `IsFriendly`, so it bypassed MayHurt. A Gust Pad no longer launches the caster's teammates in a team match. Enemies and the caster are unchanged.

## How a match flows now

1. **Queue.** A player picks DUEL in Quick Play and presses QUEUE. Their chip and footer show "1/6".
   - Cancel, Solo Test, the portal, a pad or a disconnect takes them out, and everyone else's count updates.
2. **Teams.** At 6 eligible players, the first 6 are shuffled into teams A and B. They see "Match found!" and get one map vote (15 s) that shows each team's lineup.
   - If anyone leaves during the vote, it is called off and the rest are re-queued at the front.
3. **Round start.** `DuelMatch.Begin` sets `DuelMatch`, `MatchTeam`, `RoundsWon` and `RoundsLost`, and zeroes Ultimate charge.
   - Each round, everyone still in the match is cleared and rebuilt with LoadCharacter under the wipe. Teammates stand 6 studs apart on their team's mark.
   - Marks: round 1 is a coin flip and round 2 keeps them. From round 3 each round flips its own coin.
4. **During the round.** Teammates cannot hurt, slow, root, status or react on each other. Radiant's Blessing, Benediction, Halo and Position Trade treat them as allies.
   - A player who goes down stays down; the camera stays on their body.
   - The round ends when a whole team is down, or at 90 s on team health share.
5. **Between rounds.** The banner shows the result, and after 2 s the next round starts.
6. **Match end.** At 5 round wins: "YOUR TEAM WINS!" or "THEIR TEAM WINS".
   - `PlayerData.AwardMatch` runs for everyone still there.
   - After 4 s, everyone goes home. Anyone who is down is rebuilt in the Hub.
7. **Leaving mid-match.** Only a dev can use BACK TO HUB. Their team plays on short-handed, and a team with nobody left forfeits.

## Rules I decided (not in the brief)
- **Teams are drawn at random** from the first 6 eligible players in the queue. There are no parties or skill balancing yet.
- **A leaver counts as down, at 0 of their max health, for the rest of the match**, including the clock's health share. They are never rebuilt.
- **A dev who leaves with BACK TO HUB gets no award**, even if their team goes on to win. Awards go only to players still in the match at its end.
- **Pad duels award nothing.** Only Quick Play's team matches call `AwardMatch`, so the Hub pad flow stays exactly as it was. To change this, remove the `if match.Kind ~= "Team" then return end` line in DuelMatch's `award()`.
- **No respawn mid-round was done by taking respawns over in HubServer** (`Players.RespawnTime = 1e6` plus a scripted respawn after the place's 3 s). Roblox has no per-player respawn switch.
- **A cancelled team vote re-queues everyone left at the front of the queue.** A pad duel's cancelled vote behaves as before.
- **Gust Pads no longer launch teammates.** If the owner wants them to work as a team jump pad, remove the two `MatchTeam` lines in `ZephyrGustPadServer.eligible`.
- **A team match's map vote is 15 s**, against 12 s for a pad duel.
- **Teammate outlines are gold, and enemies get no outline.**
- **No spectating.** The camera stays on the body of a player who is down.

## How to revert

- **Back to 1v1 Quick Play without reverting anything:** set `Config.Team.Size = 1`. The queue then pairs two players, who play a 1v1 with team wording.
- **Everything at once:** run this in the Edit command bar. It also undoes anything else changed in these 8 scripts after 2026-10-18, so check that first.

```lua
local folder = game.ServerStorage.TeamModeSuperseded_2026_10_18
local SES = game:GetService("ScriptEditorService")
local function resolve(path)
	local inst = game
	for part in path:gmatch("[^%.]+") do inst = inst and inst:FindFirstChild(part) end
	return inst
end
for _, b in folder:GetChildren() do
	local live = resolve(b:GetAttribute("OriginalPath"))
	if live then
		local src = b.Source
		local ok = pcall(function() SES:UpdateSourceAsync(live, function() return src end) end)
		if not ok then live.Source = src end
		print("reverted", live:GetFullName(), #live.Source == #src)
	end
end
```

Team Create's version history also has the place from before this change.

## Checked (Edit mode, no Play)
- **All 8 edited scripts compile.** Each was cloned as `return function() <source> end` into a temporary ModuleScript and required.
- **`Config.MayHurt` on a fresh Config clone:**
  - teammate: false;
  - enemy in the same match: true;
  - another match: false;
  - Solo: false;
  - Hub: false;
  - self: true;
  - a pad duel with no `MatchTeam` (old attributes only): true.
- **Team spots on every map the vote offers.** All 3 slots on both marks resolved to floor within 0.5 studs of the mark's height, with no wall and no fallback:
  - ShatteredNeonCity, AscendantBastion, SkylineConcept, SkylineRivals, ElementalQuarry and SakuraRow, each through its Marks;
  - TrainingGround, through HubServer's baseplate fallback.
- **The live DuelMatch source, run on mock players.** CombatCore and PlayerData were stubbed in a probe folder, so the real economy module was never called. The run covered:
  - a 3v3 to 2 wins, where the first player down got "out" with standing=2 and the next got standing=1;
  - a team wiped, so the other team took the round and `RoundsWon` / `RoundsLost` flipped correctly;
  - a dev leaving mid-round 2: allies and enemies were told, the team played on, the leaver was not rebuilt in round 3 and counted down, and the team losing its last standing player lost the round;
  - the round-3 clock: 350/450 against 300/450 went to team A with How = "time", and the match ended 2-1;
  - awards: `win/2` × 3 and `loss/1` × 2, with the leaver excluded;
  - attributes cleared and everyone sent home;
  - a 1v1 team-kind forfeit, which awarded `win/0`;
  - a pad duel (kind "Duel"), which played a round, forfeited, and awarded nothing.
- **PlayerData's signature** is `PlayerData.AwardMatch(player, result, roundsWon)` and matches the call.

## Not tested (needs Play)
- **Nothing ran in Play mode**, so none of these has been seen in game:
  - the remotes reaching real clients;
  - the banners, chip and footer text, the MapVote layout, and the teammate Highlight under the camera;
  - LoadCharacter for 6 players at once.
- **Whether Roblox honours `Players.RespawnTime = 1e6`** (no clamp). If it does not, a downed team player would come back mid-round when the engine timer fires. Watch for this with Size ≥ 2.
- **Scripted respawns in the Hub and Solo Test** (3 s after death, the same as before). Not seen running.
- **A real 3v3:** 6 clients, ally heals across teammates (Blessing, Benediction, Halo), and friendly-fire refusal for each kit in Play.
- **Mobile layout** of the longer banners ("YOUR TEAM TAKES THE ROUND!").
- **Two team matches on the same map at once.** As before, a map has one copy.

## Play-test with 2 clients
1. Set `Config.Team.Size = 1` in `ReplicatedStorage.Spellshot.SpellshotConfig`, then run Server + 2 clients.
2. On each client: PLAY, then DUEL (the card reads "1v1 · TEAMS, FIRST TO 5"), then QUEUE.
   - Client 1's chip and footer should read "1/2". Both go to "Match found!", then a vote titled "TEAMS · 1v1".
3. In the arena, check both banner lines: "ROUND 1" and "FIRST TO 5 · 1v1".
   - On the Server, each player should have `MatchTeam` "A" or "B" and the same `DuelMatch`.
4. Kill one player. Expect "YOUR TEAM TAKES THE ROUND!" or "THEY TAKE THE ROUND", the plate's numbers updating, and round 2 starting about 2.35 s later.
   - The dead player should not pop up on their own: the scripted respawn sees the new body.
5. **Teammates, with only 2 clients.** While the match is live, run `<Player2>:SetAttribute("MatchTeam", <Player1>:GetAttribute("MatchTeam"))` on the Server. That attribute replicates and makes the two teammates. Expect:
   - shots pass through each other and do no damage, CC or status;
   - each sees a gold outline on the other;
   - a Radiant Blessing or Benediction heals the other.
   This only tests friendliness. DuelMatch keeps its own team lists, so a death from elsewhere (the dev DMG button) still ends the round as a 1v1. Set the attribute back to end the experiment. The "out" banner and short-handed play need Size ≥ 2 and 4 clients.
6. **Clock.** The command bar has its own require cache, so a Config change made during Play does not reach the game. Set `Config.Team.RoundTime = 10` in Edit, then Play. Leave both standing and damage one: "TIME! ..." goes to the healthier one.
7. **Forfeit.** Press H as a dev, or set `DevOff` to test the gate. The other player should see "YOU WIN BY FORFEIT!".
   - The winner should get `PlayerData.AwardMatch`, visible in the economy's Sparks.
8. **Cancel and requeue.** Queue on client 1, cancel, and queue again. The counts update. Leave Solo Test and a pad duel as they are.

## Review fixes on top of this build (18 October)

After this build, a review workflow confirmed defects in it, and the orchestrator fixed them in place. Each fixed line is marked "(2026-10-18 review)". `CHANGES_2026-10-18_handoff.md` lists every fix (the "Review fixes" table) and the Play-test results. Reverting from this build's backup folder also removes those fixes.
