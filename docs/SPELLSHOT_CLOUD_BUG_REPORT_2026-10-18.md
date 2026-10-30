# SPELLSHOT cloud — Deep Bug Audit Report (2026-10-18)

**Target:** `athufg/spellshot-cloud` at commit `3b41518` (the "SPELLSHOT cloud snapshot" export; `game/manifest.json` says
191 scripts, which matches the 191 `.lua` files under `game/` exactly).
**Kind of audit:** code-only and static. Per the repo's own README a cloud session can't press Play, run Luau or see the
render. Nothing here was executed, and nothing is claimed to "work". Every finding is a reading of what the code says it
does. **No file under `game/` was edited.** This report is the only file the audit added.
**How it was done:** six passes, run as twelve parallel read-everything subagents. The two passes too large for one
reader were split by Element/area: Pass 5 into six slices (A Cryo, B Pyro/Terra/Toxin, C Radiant/Umbra, D Voltaic/Aqua,
E Zephyr, F shared plumbing and settings), and Pass 6 into two (A dead code and staged fixes, B doc drift). Three gap-fill
readers then read, line by line, every file or range that all twelve had read only in part. The consolidator re-checked
the highest-impact claims directly against the source; those are listed under "Consolidator verification" below.

## Read this first: three facts that change how the brief applies

1. **The cross-Element Technique pool is switched off in the shipping code.** The brief calls "a Pyro running another
   Element's Technique" a design pillar. But `SpellshotConfig.lua:503` sets `Config.TechniquesOwnElementOnly = true`
   ("P31, 2026-10-18: Techniques swap within your own Element only, never across"). Every loadout and cast path honours it
   (Pass 4 checked each one). So cross-Element assumption bugs are **latent**: they fire only if that flag is flipped back
   to `false`, which the config comment explicitly supports. Pass 4 grades each one LIVE or LATENT. Also, there are **two**
   Technique slots (Q/E: "Mobility"/"Defense"), not three. The Dev Diary has no entry for P31 at all (P6B-01).
2. **The three `ServerStorage` "ReviewFix" folders are the *before* copies, not unapplied fixes.** Pass 6 ran a real
   `diff` against each live script. The review fixes (the touch CrouchClear latch, `RunningOnlyTouchCrouch = false`, and
   Umbra's queued second Shadow Step with give-back) are **already in the live scripts**. The ServerStorage copies are
   the pre-fix state. `_superseded_everfrost_2026_10_14/chill_ef.lua` is an unreferenced status-bar look for a dropped
   Cryo skin (P6A-10 / P6B-15).
3. **The manifest does not record any script's `Enabled`/`Disabled` (or `RunContext`) property, nor
   `Workspace.SignalBehavior`.** Several findings (the stage scripts, `MatchHUD_RETIRED`, Patient Zero's double-cast)
   depend on these, and each says so. The first checklist below takes about 30 seconds in Studio and settles most of them.

## If you only read one section

| Pass | Entries | Entries by severity | Distinct (duplicates merged) | Distinct by severity |
|---|---|---|---|---|
| Pass 1 — Server authority / exploit surface | 19 | 5 High / 5 Medium / 9 Low | 15 | 5 High / 5 Medium / 5 Low |
| Pass 2 — Economy and persistence | 18 | 1 High / 6 Medium / 11 Low | 15 | 1 High / 5 Medium / 9 Low |
| Pass 3 — Combat-state correctness | 24 | 2 High / 6 Medium / 16 Low | 19 | 0 High / 5 Medium / 14 Low |
| Pass 4 — The cross-Element combination surface | 20 | 1 High / 5 Medium / 14 Low | 19 | 1 High / 5 Medium / 13 Low |
| Pass 5 — Skins, wraps and settings honouring | 133 | 1 Critical / 8 High / 44 Medium / 80 Low | 115 | 5 High / 36 Medium / 74 Low |
| Pass 6 — Dead code, stale fixes, code-vs-doc drift | 42 | 4 High / 9 Medium / 29 Low | 35 | 1 High / 7 Medium / 27 Low |
| Gap-fill reads (A UI/HUD, B VFX builders + free-name scan, C open traces) | 41 | 4 High / 6 Medium / 31 Low | 35 | 2 High / 2 Medium / 31 Low |
| **Total** | **297** | 1 Critical / 25 High / 81 Medium / 190 Low | **253** | 15 High / 65 Medium / 173 Low |

"Entries" counts every finding as each pass wrote it. The same bug found by several passes is one **distinct**
finding, counted once under its canonical ID (map below). No Critical remains after consolidation. The one entry that
said Critical (P5A-01, the stage scripts *if Enabled*) is merged into P1-05 at High: it is release-blocking if those
scripts are on, but it is a deployment hazard, not an exploit or economy hole. Graded by the brief's rule, the
competitive-integrity and exploit bugs below outrank it.

### Lead with these (ranked)

1. **P1-01 (High): fire from anywhere.** Twelve shot types (Icicle Shard, Fireball, Wind Blade, Cross-Slash, Boulder
   Shot, Chain Bolt, Railspike, Riptide, Sidearm, Shadow Dart, Light Lance, Toxic Bubbles) accept a client-claimed origin
   within `6 + speed * (0.35 + ping)`. Both `speed` (the client-owned root's `AssemblyLinearVelocity`) and `ping` are
   client-controlled and uncapped, and the cover check then runs **from that claimed origin**. A cheater writes one huge
   velocity frame and shoots from an open spot while sitting behind a wall. Scorching Lash was already fixed for exactly
   this after an earlier review (`LASH_MAX_TRAIL_SPEED`); the other twelve were not. *Consolidator-verified.*
2. **P1-02 (High): dev mode is live on public servers.** `AllowInLiveGame = true`, an extra collaborator UserId, and
   `FreeUltimate = true` by default. The owner and UserId 2800693640 play Sparks-paying matches with an Ultimate pinned
   full every frame. The dev panel also mints unlimited persistent Sparks (+1000 per press, saved), unlocks every Element,
   changes Element mid-duel and broadcasts arbitrary kill-feed text. The config's own comment says "turn it off before the
   game is public". (Found independently by five passes.) *Consolidator-verified.*
3. **P4-01 (High): Skyrider is a free Earthen Tomb escape and an Ultimate farm.** Skyrider has no Precheck. A modified
   client presses it while Entombed or rooted: the server pays, TerraHandler stamps `CCBreak` (Tomb broken), then
   Skyrider's server refuses the stunned body and gives the cast back *without* the +6% Ultimate charge. The press can be
   repeated with no cooldown: about 17 presses fill the Ultimate from 0. *Consolidator-verified.*
4. **P1-04 (High): the Training Ground range is in the ranked map vote.** It has no `Model` and no `Vote = false`
   (`MapRegistry.lua:122-125`). Its dummies never die and refill instantly, and every "damage dealt" benefit counts them:
   Ultimate charge (about 260 damage = a full meter), Toxin lifesteal, Umbra/Pyro/Voltaic cooldown cuts and Position Trade
   teleports. Its snowball thrower also hits duellists through `TakeDamage`, bypassing shields. *Consolidator-verified.*
5. **P6A-05 + GC-03 (High): Bulwark Wall doesn't stop dashes or the Skyrider gust.**
   - `DashMotor`'s and Skyrider's "through characters" rule treats any Model with a Humanoid as a body, and the wall *is*
     a Model with a Humanoid. So Cross-Slash, Overcharge, Bulwark Charge and Skyrider pass straight through an enemy's
     "one wall in the game".
   - On the server (GC-02), Cross-Slash and Bulwark Charge damage then lands on bodies behind the wall.
   - Separately, Skyrider's Gust hits enemies behind a wall with no exploit needed (GC-03): its line-of-sight ray excludes
     every body it found, and the wall is one of them (`ZephyrSkyriderServer.server.lua:267-272`).
   *Both consolidator-verified.*
6. **GC-14 (High): shots that hurt you but that nobody else sees.** Icicle Shard, Fireball, Wind Blade, Boulder Shot and
   Riptide deal damage from a release remote that is never paired with the paid `CastRequest("M1")` (P1-12: so they also
   cost no mana). Every *other* client draws the shot only from the CastRequest relay. An unpaired release (a modified
   client, or an honest client whose CastRequest is rate-refused under jitter) is a projectile that damages you and that
   no other client draws. *Consolidator-verified (`AbilityHandler.server.lua:723-729` relays from the cast only).*
7. **P5C-01 (High): Colourblind-Safe is a Decoy Double detector.** The setting repaints only `Players:GetPlayers()`
   characters, while the decoy is a server-side `character:Clone()`. A viewer with the setting on sees the real Umbra
   near-black and the decoy violet, for its whole 8 s. Any player can turn the setting on. *Consolidator-verified.*
8. **P5F-02 (High): free third-person camera (V) for every player in ranked.** `ALLOW_THIRD_PERSON_TOGGLE = true`, and
   the file's own comment flags it as an undecided competitive-integrity call (it sees around corners and over cover).
   *Consolidator-verified.*
9. **P1-05 (High, conditional): four TEMPORARY stage scripts have no Studio gate.** If Enabled live,
   `_AuroraStageClient` anchors every player, disables every ScreenGui (the whole HUD) and pins the camera on every
   client. The server halves clone the first player's avatar into hittable Humanoid dummies and add invisible
   query-blocking walls. **Check Enabled in Studio first**; the `_BRO` stage is dated 2026-10-19, so it is in active use.
   *Consolidator-verified (no guard in any of the four files).*
10. **P1-03 (High, structural): the server never validates movement.** Every root, slow, pull, knockback, cage, Tomb and
   Twin Tide/Maw wall is carried out by the victim's own client. Nothing on the server compares displacement against a
   legal speed. An exploit client ignores all crowd control and always "jumps" Earthen Tomb and Aftershock. This is also
   the root cause behind P1-01.
11. **Skins that change what the opponent can see (High): P5A-02, P5A-03, P5C-02.**
    - Snow Globe's Blizzard puts opaque 8.7-stud pines inside the storm, with no keyhole fade.
    - Frost Dragon's Flash Freeze lays a 32-stud translucent claw over the zone that only the caster's own client draws
      clearer.
    - The Devil skin replaces Light Lance's beam, Halo's ring and Benediction's column with EditableMesh forms that have
      no fallback while building or after a failed build, so an opponent's first Devil lance has no visible beam.
12. **P2-01 (High, medium confidence): same-server rejoin can lose progress.** The session lock identifies the holder by
    `game.JobId` only. A player who reconnects into the *same* server is not "held elsewhere", so the new load and the old
    profile's leave save race. That can drop recent Sparks or Element unlocks, and even a Robux pack Roblox already marked
    PurchaseGranted. *Consolidator-verified (logic).*

**Economy, Medium but worth five minutes:**
- **P2-04:** if `GetDataStore` throws on a live server, the whole server goes memory-only *without* a Studio check, and
  ProcessReceipt then returns PurchaseGranted for Sparks packs that are never saved.
- **P2-05:** a forfeit pays the full 150+ Sparks win with no minimum play time, so alt accounts can farm it.
- **P2-06:** `SkinCatalog.OwnsSkin` returns true for every skin. Every cosmetic, including the "IN BUILD" Mythic Frost
  Dragon, is free and equippable live, and there is no cosmetic ownership in the save.
- **P6B-07:** only full six-player Quick Play team matches pay Sparks at all.

**Hard runtime bugs (Medium, cheap to fix):**
- **P5A-06:** `SnowGlobeFX.HitBloom` calls `shards` 86 lines before `local function shards` is declared. Luau resolves
  it as a nil global, so every Snow Globe M1 hit errors inside a silent pcall and leaks visible glass slabs for the rest
  of the session. *Consolidator-verified.*
- **P5A-07:** `FBX.Shatter` crashes for Frost Lotus and Snow Globe.
- **P5A-08:** three Cryo skins mark themselves `Built` even when meshes failed, which hides the Default and draws
  nothing (invisible Mirror Cage bolts).
- **P3-01:** a reaction that kills fires every OnKill listener twice.
- **P6B-10 / GC-01 (Medium):** in team mode a downed enemy's body (with its 2x query-able hitbox twins) stays for the
  whole round and stops Icicle Shard, Fireball, Boulder Shot, Chain Bolt, Shadow Dart, Light Lance, Sidearm and Volt Orb.
  The manual says "a body is scenery, not cover".
- **GC-07 (Medium):** Shadow Step ignores every root and Earthen Tomb. Out of a Tomb it blinks, is pulled straight back,
  and the charge is spent.

**Settings:** Reduce Flashing, Graphics Quality and Reduce Enemy VFX are unread by whole Elements: Radiant (including
Devil), Umbra and Aqua (P5F-03, P5F-05, P5C-07, P5D-02). "Enemy" means "not me" everywhere, so teammates are thinned in
team modes (P5F-06). The Colourblind palette paints Aqua gold and makes Zephyr and Radiant both white (P5F-09, P5F-10).
A failed settings load followed by any one change overwrites the player's real saved settings, Reduce Flashing included
(P2-08).

**Luau 200-local limit:** nothing fails to compile today, but four modules sit near the limit. **ZephyrDraw is at exactly
200 live locals** inside one do-block (P5E-14): one more local and every Zephyr effect silently stops drawing. CryoFX is
at 198 (P5A-17), RadiantFX_Hand at 192 (P5C-19) and CascadeFX peaks at 187 (P5D-14).

### Check these in Studio before anything else (each settles a conditional finding)

| Check | Settles |
|---|---|
| Are `ServerScriptService._AuroraStage`, `._BROStage`, `StarterPlayerScripts._AuroraStageClient`, `._BROStageClient` Enabled? | P1-05 and its 6 duplicates, P2-11 |
| Is `StarterGui.MatchHUD_RETIRED` Disabled? | P6A-08, P6A-09 |
| Is `TerraTestHarness` / `TerraTestServer` wanted in the shipping place? | P6A-15 |
| `RunContext` of `ServerStorage.UmbraReviewFix_2026_10_18.UmbraHandler` (Legacy = inert; Server = runs twice) | P6A-10 note |
| `Workspace.SignalBehavior` (Deferred makes Patient Zero castable twice per charge) | P1-08 |
| `Workspace.OpenAcademyHub.HubSpawn.Enabled` | P6A-06 |
| Are all 45 `PF_` flame meshes present (else Pyro falls back to the "toon" look)? | P5B-01 |
| Is the place public yet? (dev mode) | P1-02 |

## Duplicates and consolidated severities

Several passes found the same bug from different directions. Each group below is **one** distinct finding. The
duplicate entries stay in their passes for their extra detail, each marked with a "Consolidator" note.

| Canonical | What | Canonical severity | Also reported as |
|---|---|---|---|
| P1-02 | Dev mode live: free Ultimate in ranked + unlimited Sparks | High | P2-07, P3-19, P6A-03, P6B-05, P4-09 |
| P1-04 | Training Ground in the ranked map vote | High | P3-02 |
| P1-05 | Temporary stage scripts ungated (if Enabled) | High | P6A-01, P6A-02, P5A-01, P5F-01, P5C-06, P5B-15 |
| P2-11 | Partial SettingsSync payloads reset all settings | Low | P5C-16, P5F-21 |
| P2-06 | OwnsSkin always true: every cosmetic free | Medium | P1-15, P6B-08, P5A-20 |
| P2-05 | Forfeit wins pay full reward (farming) | Medium | P1-06 |
| P1-08 | Patient Zero double-cast under Deferred signals | Medium | P3-08 |
| P5F-09 | Colourblind-Safe paints Aqua gold | Medium | P5D-01 |
| P5F-10 | Colourblind palette moves 5 Elements; Zephyr~Radiant | Medium | P5E-02, P5C-10, P2-12 |
| P5F-06 | Reduce Enemy VFX thins teammates ("enemy" = not me) | Medium | P5D-06, P5E-05, P5B-06 |
| P1-13 | Sidearm / Cross-Slash strike ignore interrupts (AliveCharacter) | Low | P3-11 |
| P1-14 | Gust Pad / Position Trade act on solo strangers | Low | P3-18 |
| P3-09 | Ult charge from walls/decoys/self-damage | Low | P1-18 |
| P3-13 | All-draw matches never end | Low | P2-15 |
| P4-08 | GiveBack/cooldowns keyed by slot not ability | Low | P1-17 |
| P1-12 | M1 hit remotes never pay mana | Medium | P5D-13, GC-13 |
| P6A-10 | ServerStorage ReviewFix folders hold PRE-fix copies | Low | P6B-15 |
| P2-08 | SettingsStore failed load -> defaults saved over real | Medium | P5F-12 |
| P2-09 | Settings changed before load are lost | Low | P5F-17 |
| P5F-05 | Graphics Quality / Reduce Enemy VFX unread by Umbra, Aqua, Radiant | Medium | P5C-08, P5C-09 |
| P6B-06 | Quick Play advertises modes the server refuses | Low | P6A-19 |
| P6A-05 | Dashes / dash strikes pass through Bulwark Wall (client and server) | High | GC-02 |
| P6B-10 | Team-mode corpses (and hitbox twins) block six kits' shots | Medium | GC-01 |
| P3-05 | BreakRoot ends Cryo prison/cage roots silently; clients keep drawing them | Medium | GC-08 |
| P4-04 | Updraft bonus while Entombed/juggled (no server pillar) | Medium | GC-09 |
| P5B-05 | Reduce Flashing ignored by Pyro/Terra/Toxin strobes (incl. all PyroDraw) | Medium | GC-10 |
| P5B-01 | Toon-look Ring of Fire drawn smaller than burn area (doubly conditional) | Medium | — |

Severity changes the consolidator made, and why:
- **P1-12 / P5D-13 / GC-13, M1 mana skip → Medium.** Pass 1 said Low, slice D said High, and GC-13 traced every M1: Icicle Shard, Fireball, Wind Blade, Boulder Shot, Chain Bolt and Riptide can deal damage unpaid; Shadow Dart, Light Lance and Toxic Bubbles cannot. Skipping the M1 `CastRequest` saves
  about 6 mana/s against 7/s regen for Voltaic, nearly doubling the ability budget for a modified client. That is a real
  competitive edge, but it needs a modified client and is bounded. The *visibility* consequence of the same unpaired
  release is a separate High (GC-14).
- **P1-05 stage scripts → High** (P5A-01 said Critical). See the note above the ranked list.
- **P5B-01, toon Ring of Fire → Medium** (slice B said High). It needs two independent conditions at once: the fallback
  "toon" look is active, *and* the Pyro has swapped in Heat Rush, which Pyro's defaults don't equip (P4-11).
- **P1-02 dev mode → High** across all five reports. P2-07, P6B-05 and P4-09 each said lower; graded on the combined
  effect.

## Consolidator verification

The consolidator re-read these claims against the source directly, rather than relying on the subagent's word:

| Finding | What was checked | Result |
|---|---|---|
| P1-01 | `AbilityHandler.server.lua:419-422, 855-860`: `allowance = 6 + speed * (0.35 + ping)` from `root.AssemblyLinearVelocity` and `GetNetworkPing` | confirmed |
| P1-02 | `SpellshotConfig.lua:152-166, 209-219`, `SpellshotService.server.lua:118-127, 376-407` | confirmed |
| P1-04 | `MapRegistry.lua:121-125` (no Model, no Vote), `HubServer.server.lua:318` filter | confirmed |
| P1-05 | all four stage scripts: no `IsStudio`, `PlaceId` or attribute guard | confirmed |
| P2-01 | `PlayerData.lua:191-195, 258-262`: lock identity is `game.JobId` only | confirmed (logic) |
| P4-01 | `ZephyrSkyriderServer.server.lua:125-131` (giveBack without ult), `TerraHandler.server.lua:1011-1022` (CCBreak on any accepted Mobility press) | confirmed |
| P5A-06 | `SnowGlobeFX.lua:112` call vs `:198` declaration, no forward declaration | confirmed |
| P5C-01 | `SettingsRuntime.client.lua:319-359` paints players' characters only; `UmbraHandler.server.lua:843` clones the body on the server | confirmed |
| P5F-02 | `FirstPersonController.client.lua:55-61, 403` | confirmed |
| P6A-05 | `DashMotor.lua:162-170, 185-189, 333-345`; `TerraHandler.server.lua:529-547` (the wall is a Model with a Humanoid) | confirmed |
| GC-03 | `ZephyrSkyriderServer.server.lua:267-285`: every `HumanoidsNear` model (the wall included) is added to the LOS exclude list | confirmed |
| GC-14 | `AbilityHandler.server.lua:723-729` (the Icicle Shard relay is sent only from the paid cast); the release handler broadcasts nothing | confirmed |
| EconomyService / SettingsStore / PlayerData | read in full by the consolidator as well as by Pass 2 | consistent with Pass 2 |

## Audit checklist

| Pass | Status | Record |
|---|---|---|
| 1. Server authority / exploit surface | **complete**: all 31 ServerScriptService scripts read fully; every client→server remote mapped to its sender (Appendix A of Pass 1) | 19 entries (5 High) |
| 2. Economy and persistence | **complete**: PlayerData, EconomyService, SettingsStore, DuelMatch, HubServer, SpellshotService, EconomyConfig, SkinCatalog and the shop read fully; whole-tree DataStore / Marketplace grep | 18 entries (1 High) |
| 3. Combat-state correctness | **complete**: CombatCore, DuelMatch, StatusEffects, ElementalReactions, HitboxScale and every kit handler read fully | 24 entries (2 High) |
| 4. Cross-Element combination surface | **complete**: all 20 Techniques traced server and client (Pass 4 appendix table); the gate verified on every path | 20 entries (1 High; 6 LATENT) |
| 5. Skins, wraps and settings | **complete**: six slices covering all 75 IceMagic modules, settings plumbing, BarFX, SkinCatalog; local counts for every module; settings-consumer matrix (Pass 5F Appendix A) | 133 entries across slices A-F |
| 6. Dead code, stale fixes, doc drift | **complete**: all test/stage/retired scripts; the three ServerStorage folders diffed; Design Manual, Dev Diary, HANDOFF and README read | 42 entries |
| Gap-fill A/B/C | **complete**: every file or range that the twelve passes had read only partially was re-read in full (GA: LoadoutMenu, CardKit, PopArtHUD, BarKit, PopArtAssets, ReactionsBoard, BarFX + all 24 variants; GB: PyroFlame_*, CastPose/Viewmodel data and update ranges, VFXLibrary 3100-4810, FrostLotusKit geometry, and a free-name scan of all 191 scripts; GC: PyroDraw 1650-2044 and every trace a pass left open, closed as confirmed or refuted) | 41 entries (2 distinct High: GC-03, GC-14) |
| Report written | this file | — |

Every file under `game/` is listed in the closing section with the passes that read it.

## How the findings are laid out

Each pass section reproduces the pass's own record: its list of files read, its explicit "checked, clean" lines (so
"checked, clean" can be told apart from "not checked"), then one block per finding with **Severity**, **Confidence**,
**Files/lines**, **Trigger**, **Why it's a bug**, **Suggested fix** and **Notes**. IDs are `P<pass>-NN`, or
`P5A..F-NN` / `P6A..B-NN` for the slices. "LATENT" means the finding only fires with
`TechniquesOwnElementOnly = false`. Severities follow the brief: Critical and High are reserved for exploit, economy and
competitive-integrity bugs. The closing section has an index of every distinct finding by severity.


---

## Pass 1 — Server authority / exploit surface

_Entries: 19 (5 High / 5 Medium / 9 Low). Distinct after merging duplicates: 15 (5 High / 5 Medium / 5 Low)._

### Pass 1 — Server authority / exploit surface (every RemoteEvent / RemoteFunction handler in ServerScriptService)

Static, code-only audit. "Client" below means a modified/exploit client unless stated. Roblox facts relied on: a player's
own character assembly is network-owned by that client (its CFrame and AssemblyLinearVelocity replicate from the
client); attribute writes and Humanoid property writes made by a client do not replicate to the server.

#### Files read (complete list)
ServerScriptService (all fully):
- game/ServerScriptService/SpellshotService.server.lua — fully (1-1159)
- game/ServerScriptService/CombatCore.lua — fully (1-567)
- game/ServerScriptService/AbilityHandler.server.lua — fully (1-1483)
- game/ServerScriptService/PyroHandler.server.lua — fully (1-1442)
- game/ServerScriptService/ZephyrHandler.server.lua — fully (1-895)
- game/ServerScriptService/ZephyrSkyriderServer.server.lua — fully (1-406)
- game/ServerScriptService/ZephyrGustPadServer.server.lua — fully (1-396)
- game/ServerScriptService/ZephyrUpdraftServer.server.lua — fully (1-125)
- game/ServerScriptService/TerraHandler.server.lua — fully (1-1551)
- game/ServerScriptService/TerraTestServer.server.lua — fully (1-53)
- game/ServerScriptService/VoltaicHandler.server.lua — fully (1-1123)
- game/ServerScriptService/AquaHandler.server.lua — fully (1-926)
- game/ServerScriptService/RadiantHandler.server.lua — fully (1-961)
- game/ServerScriptService/UmbraHandler.server.lua — fully (1-995)
- game/ServerScriptService/ToxinHandler.server.lua — fully (1-768)
- game/ServerScriptService/StatusEffects.lua — fully (1-410)
- game/ServerScriptService/ElementalReactions.server.lua — fully (1-426)
- game/ServerScriptService/HubServer.server.lua — fully (1-1138)
- game/ServerScriptService/DuelMatch.lua — fully (1-579)
- game/ServerScriptService/PlayerData.lua — fully (1-554)
- game/ServerScriptService/EconomyService.server.lua — fully (1-79)
- game/ServerScriptService/SettingsStore.server.lua — fully (1-144)
- game/ServerScriptService/MovementModeServer.server.lua — fully (1-38)
- game/ServerScriptService/TrainingGround.server.lua — fully (1-519)
- game/ServerScriptService/AllyDummies.server.lua — fully (1-124)
- game/ServerScriptService/HitboxScale.server.lua — fully (1-108)
- game/ServerScriptService/UniformAvatar.server.lua — fully (1-179)
- game/ServerScriptService/CombatFeedback.server.lua — fully (1-94)
- game/ServerScriptService/FrostDragonKillHook.server.lua — fully (1-28)
- game/ServerScriptService/_AuroraStage.server.lua — fully (1-106)
- game/ServerScriptService/_BROStage.server.lua — fully (1-101)

Client / shared (to map what is sent and what the server consumes):
- game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua — fully (1-1915)
- game/ReplicatedStorage/IceMagic/VFXLibrary.lua — partially: lines 200-545 (ability rows, AbilityById, AbilityFor, TechniqueSlot), 4916-4920 (ShotTimeScale)
- game/ReplicatedStorage/Spellshot/SpellshotConfig.lua — partially: 140-230 (Dev, MayHurt, IsDev), 244-269 (Team, Hitbox), 376-441 (pools), 457-470, 485-760 (Technique/ElementMayHold/MayEquip/ApplyElement/DefaultLoadout/IsBuilt)
- game/ReplicatedStorage/Spellshot/EconomyConfig.lua — partially: 40-100
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua — partially: 175-209 (Coerce/Sanitise)
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua — partially: 421-436 (OwnsSkin)
- game/ReplicatedStorage/Spellshot/MapRegistry.lua — partially: 118-190 (List)
- game/ReplicatedStorage/IceMagic/TerraFX.lua — partially: 40-50, 105-117 (BoulderShot / Bedrock tuning)
- game/ReplicatedStorage/IceMagic/CryoAurora.lua — partially: 720-745
- game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua — partially: 605-625, 1076-1080 (dispatcher)
- game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua — fully (18 lines); _BROStageClient.client.lua — partially: 1-12
- Sender lines only (grep of every FireServer/InvokeServer across game/, outside ServerStorage): VoltaicClient.lua 355-365, 536-544; ToxinClient.lua 95-102; ZephyrSkyrider.lua 260-272, 730, 858, 925; UmbraClient.lua 314, 354, 360; RadiantClient.lua 205, 224, 251-253; AquaClient.lua 97, 101, 621, 623; LoadoutMenu, HubClient, QuickPlay, MapVote, MovementController, SettingsRuntime, DevPanel, TerraTestHarness, VoltaicTestHarness sender lines (listed in the appendix).
- game/manifest.json — searched: dummies under Workspace.TrainingGround, script entries for _AuroraStage/_BROStage (no Enabled flag recorded), no SignalBehavior recorded.

#### Sub-areas checked with nothing found
- checked, clean: every hit-report remote that names a shot (ShardHit, FireballHit, WindBladeHit, BoulderHit, RiptideHit, SidearmHit, ShadowDartHit) requires a shot record that was only created by that player's own release handler, which first checks `holds(player, "M1", <own Id>)` / the Held record — a Pyro cannot report hits to the Cryo/Terra/etc. handlers, and a release for an Element you do not play is dropped.
- checked, clean: replay of hit reports — every one-hit shot deletes its record (`mine[a.Id] = nil`), piercing shots keep a per-model `Hit` set and a `Count` cap; CrossSlashStrike / ScorchingLashStrike set `Struck`; RailspikeFire clears `rails[player]`; ShadowDartRelease consumes the charge.
- checked, clean: claimed `Part` arguments — every handler checks `typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(workspace)` and a `Core.ValidVector(position)` before using them; a part of another player's character is refused through `Core.IsFriendly`/`Config.MayHurt` unless that player is a live opponent in the same match.
- checked, clean: NaN/inf in client vectors — `Core.ValidVector` (CombatCore.lua:109-113) rejects NaN and |x| >= 1e6 and is used on every client Vector3 that reaches a CFrame/position/raycast; `heldAim` (SpellshotService.lua:922) rejects NaN via the `< 1e4` compare; Settings.Coerce rejects NaN and clamps inf.
- checked, clean: TechniquesOwnElementOnly enforcement — LoadoutRequest "Technique" (Config.MayEquip, SpellshotService.lua:779), Element change (ApplyElement→TechniquesFor), dev SetTechnique (ElementMayHold, :414), Hub shrines (ApplyElement), and cast time (VFXLibrary.AbilityFor:511) all ask ElementMayHold; the Ultimate is always ElementUltimate(element) (:501-503). A client cannot cast a foreign Technique.
- checked, clean: `payload.Escape` (Shadow Step's second charge) is overwritten by the server on the cooldown path (SpellshotService.lua:1061); held abilities receive server-built `{Phase="Start"|"Release"|"Aim"}` tables (:1041, :815, :927), so a client cannot inject a Phase into a held ability.
- checked, clean: Hub — CastRequest refuses Zone "Hub" (:894); every release/hit handler that starts damage also refuses Hub or needs a record that ClearPlayer wipes on leaving the Arena (CombatCore.lua:380-387).
- checked, clean: round resets — DuelMatch sets CastLocked over the clear (DuelMatch.lua:418-450); CastRequest and Core.CanAct both honour it; every kit's OnClear wipes its shot tables.
- checked, clean: EconomyRequest (EconomyService.lua:66-79) — only an Element name crosses; BuyElement (PlayerData.lua:482-503) validates existence/build/ownership/price/balance from the save without yielding before the deduction, so no double-spend race; negative balance impossible (`data.Sparks < price` refused, AddSparks floors at 0).
- checked, clean: SettingsSync "save" (SettingsStore.lua:114-126) — whole snapshot re-sanitised; DataStore writes only on autosave/leave (no client-driven write rate).
- checked, clean: Hub remote "vote"/"queue"/"solo"/"return" (HubServer.lua:1075-1138) — vote id and choice validated against the server's vote; BACK TO HUB mid-match is dev-only; solo/queue refused mid-move/mid-vote/mid-match.
- checked, clean: MovementModeRequest (MovementModeServer.lua:29-38) — Config.IsDev on the server, mode whitelisted.
- checked, clean: DeflectPracticeRemote (TrainingGround.lua:82) — drained and ignored.
- checked, clean: Ring of Fire / Cyclone / Cascade refusal paths give the charge back with `AddUltCharge(1)` only after SpellshotService zeroed it, so they cannot overfill the meter.
- checked, clean: charge-style "Charges" path in SpellshotService is unreachable today (no row has `Charges`), so its client `Start/Dir/Dist` are not consumed anywhere live.

---

#### P1-01: Every shot/strike "origin near the server's body" check scales with the client's own root velocity and ping, uncapped — fire from anywhere (wall-bang, around corners, from far away)
- **Severity:** High
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:855-864` (ShardRelease), `game/ServerScriptService/PyroHandler.server.lua:288-295` (FireballRelease), `game/ServerScriptService/ZephyrHandler.server.lua:167-174` (WindBladeRelease), `:365-370` (Cross-Slash launch Start), `:466-471` (CrossSlashStrike origin), `game/ServerScriptService/TerraHandler.server.lua:193-200` (BoulderRelease), `game/ServerScriptService/VoltaicHandler.server.lua:147-152` (eyeNear: ChainBoltFire, RailspikeFire), `:291-296` (Overcharge Start), `game/ServerScriptService/AquaHandler.server.lua:376-382` (RiptideRelease), `:684-691` (SidearmShot), `game/ServerScriptService/UmbraHandler.server.lua:140-144` (ShadowDartRelease), `game/ServerScriptService/RadiantHandler.server.lua:158-165` (RadiantLanceAim origin), `game/ServerScriptService/ToxinHandler.server.lua:390-395` (Toxic Bubbles origin). Contrast `game/ServerScriptService/PyroHandler.server.lua:923-932, 1146-1164` (the only capped one).
- **Trigger:** Any Element, any match. The exploit client writes a huge `AssemblyLinearVelocity` on its own HumanoidRootPart for one physics step (and/or delays its replies to inflate `GetNetworkPing`), then sends a release whose `Origin` is anywhere inside the inflated allowance — e.g. an open point beside the target while its real body sits behind full cover.
- **Why it's a bug:** each check is `local speed = math.max(root.AssemblyLinearVelocity.Magnitude, humanoid.WalkSpeed)` → `allowance = 6 + speed * (0.35 + ping)`. Both inputs are client-controlled. The line-of-sight test then runs from the CLIENT'S origin (`Core.Blocked(shot, along, ...)`, CombatCore.lua:519-544: `workspace:Raycast(shot.Origin, ...)`), so choosing an origin with a clear line defeats cover entirely; range is measured from that origin too. PyroHandler documents exactly this attack for Scorching Lash ("a client that wrote 500 studs/s for one step had a 231-stud origin slack ... and whipped a body 150 studs away (review r1)") and fixed it there only (`LASH_MAX_TRAIL_SPEED`, `LASH_MAX_LAG`, plus a server-reach cap); the other twelve sites still take the raw values. Cross-Slash is worse: an accepted far-away `Start` (ZephyrHandler.lua:366-370) moves the whole slash corridor there, and the strike origin is then only checked against that corridor and the same uncapped allowance.
- **Suggested fix:** one shared helper in CombatCore (e.g. `Core.OriginAllowance(player, root, humanoid, base)`) that caps speed at `Config.Movement.SlideJumpMaxSpeed` (or the kit's dash speed where a dash is legitimate), caps ping at ~0.25 s, and use it at every site above. Additionally run the cover test from the SERVER's head as well (reject when blocked from both, which is the reverse of today's "second chance" that only ever saves a shot).
- **Notes:** Pairs with P1-03 (the server has no independent movement check, so "where the server has the body" is itself client-supplied). The WasThere victim-history check is unaffected and still holds.

#### P1-02: Developer mode is live in production with a permanently full Ultimate — the place owner and a collaborator play every ranked match with infinite Ultimates and an unlimited Sparks button
> **Consolidator:** canonical entry for: Dev mode live: free Ultimate in ranked + unlimited Sparks. Also reported as **P2-07**, **P3-19**, **P6A-03**, **P6B-05**, **P4-09**.
- **Severity:** High
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:152-166` (`AllowInLiveGame = true`, `UserIds = { [2800693640] = true }`, `FreeUltimate = true`), `:209-219` (IsDev), `game/ServerScriptService/SpellshotService.server.lua:118-131` (getState copies FreeUltimate into every dev's state), `:935-944` (Ultimate path skips the charge and never spends it), `:1118-1121` (Heartbeat pins UltCharge to 1), `:390-418` (SetElement bypasses ownership and the duel loadout lock; EcoAddSparks +1000 per press; EcoUnlockAll), `:453-459` (StatusPreset rewrites every live match's status numbers server-wide), `game/ServerScriptService/DuelMatch.lua:510`, `game/ServerScriptService/HubServer.server.lua:1096-1100` (dev may leave mid-match → forfeit).
- **Trigger:** The owner (game.CreatorId for a user-owned place) or UserId 2800693640 joins any live server and queues Quick Play. No action needed: FreeUltimate is on by default for them.
- **Why it's a bug:** `s.FreeUltimate = s.Dev and DEV.FreeUltimate == true` (SpellshotService.lua:125) with `AllowInLiveGame = true` means `Config.IsDev` is true for those accounts on live servers; the Ultimate gate then reads `if not s.FreeUltimate then ... end` and the Heartbeat refills the meter every frame, so the dev can press R every time an Ultimate ends against real players in Sparks-paying team matches. The config comment itself says "turn it off before the game is public". EcoAddSparks has no cap or log beyond the reason string, and SetElement is reachable mid-duel (the duel lock lives only in the LoadoutRequest handler, :750).
- **Suggested fix:** set `AllowInLiveGame = false` for public builds (or gate it on a private-server / `game.PrivateServerId ~= ""` check), default `FreeUltimate = false`, refuse every dev toggle and SetElement while `p:GetAttribute("DuelMatch") ~= nil`, and make StatusPreset Studio-only.
- **Notes:** Cannot tell from the snapshot whether the place is already public; the config says Team Test is the reason it is on.

#### P1-03: The server enforces no movement at all — every root, slow, pull, knockback, launch, cage and Tomb is executed (and can be ignored) by the victim's own client; dodge checks read client-owned positions
- **Severity:** High
- **Confidence:** High (mechanism); the client-side reactions themselves are another pass's
- **Files/lines:** slows/roots as WalkSpeed + attribute only: `game/ServerScriptService/AbilityHandler.server.lua:233-269` (applySlow), `game/ServerScriptService/SpellshotService.server.lua:223-267, 559-571`; pulls/knocks sent to the victim's client: `game/ServerScriptService/AquaHandler.server.lua:194-196` (AquaKnock), `:543-545` (AquaPull), `game/ServerScriptService/ZephyrHandler.server.lua:773-781` (CyclonePull), `game/ServerScriptService/ZephyrGustPadServer.server.lua:259-261` (GustPadKnock), `game/ServerScriptService/ZephyrSkyriderServer.server.lua:236-238` (SkyriderKnock), `game/ServerScriptService/TerraHandler.server.lua:1229-1232` (AftershockKnock), `game/ServerScriptService/ElementalReactions.server.lua:224-231` (Overload); client-local trap walls: `game/ServerScriptService/AquaHandler.server.lua:31-38` (Leviathan's Maw / Twin Tide: "The walls are every client's own local copy, solid, so the bodies inside cannot leave"); AlignPosition holds on a client-owned assembly: `game/ServerScriptService/TerraHandler.server.lua:713-746` (Earthen Tomb), Mirror Cage root via applySlow (`AbilityHandler.server.lua:1307`); dodge decided from the victim's reported height: `game/ServerScriptService/TerraHandler.server.lua:671-678, 939-943` (Tomb "Airborne"), `:1323-1328` (Aftershock "jump it"), `game/ServerScriptService/AquaHandler.server.lua:467-474` (Riptide crest); server hit volumes carried on the caster's client-owned root: `game/ServerScriptService/TerraHandler.server.lua:389-421` (Bulwark Charge sweep); Skyrider's only speed check reads client velocity: `game/ServerScriptService/ZephyrSkyriderServer.server.lua:379-391`; slide chain with no server regap: `game/ServerScriptService/SpellshotService.server.lua:303-313`.
- **Trigger:** An exploit client that (a) keeps writing its own WalkSpeed/CFrame regardless of SpeedCapSlow/SpeedCapUlt, (b) ignores AquaPull / AquaKnock / CyclonePull / GustPadKnock / SkyriderKnock / AftershockKnock, (c) does not create the Maw/Twin Tide walls, (d) destroys or out-forces the AlignPosition/AlignOrientation the server parents to its root, (e) holds its root 1-2 studs above the floor permanently.
- **Why it's a bug:** In Roblox the owning client simulates its character; the server writing `humanoid.WalkSpeed = 0` or parenting an AlignPosition only works if the client cooperates. Nothing on the server compares successive server-side root positions against an allowed speed (no anti-teleport/anti-speed anywhere in ServerScriptService), and the only "checks" (Skyrider's `AssemblyLinearVelocity.Magnitude > limit`) read a value the same client writes. Result: an exploiter is immune to every CC in the game (Flash Freeze/Deep Freeze/Mirror Cage roots, Chill slows, Undertow pull, Cyclone, Gust Pad, Aftershock, Overload, Maw, Twin Tide), always dodges Earthen Tomb ("Airborne") and Aftershock, can run Bulwark Charge's damage box onto anyone (the sweep follows whatever position the client reports), and can slide-chain at SlideSpeed 35 (the server gives the remaining slide cooldown back on any exit and leaves SlideRegap to "the client's own clock").
- **Suggested fix:** add a server-side movement sanity loop (per Heartbeat: displacement since last sample vs. the max legal speed for the current state, including dash/knock allowances the server itself granted; snap back or flag on violation), and treat roots/slows as violations-to-enforce: while SpeedCapSlow is 0 or a Tomb/Cage holds the body, take network ownership of the root (`SetNetworkOwner(nil)`) or anchor-and-restore. Make Tomb/Aftershock dodges require the server to have SEEN a jump (Humanoid state Jumping/Freefall within the window), not merely a raised root. Enforce SlideRegap server-side.
- **Notes:** This is the root cause behind P1-01's "where the server has the body" weakness too. The design deliberately gave clients their own movement for feel; the fix is validation, not taking movement back.

#### P1-04: The TRAINING GROUND (refilling dummies + snowball thrower) is in the ranked map vote — Ultimate, healing and cooldown farming on dummies mid-match, and duellists hit by the range's thrower
> **Consolidator:** canonical entry for: Training Ground in the ranked map vote. Also reported as **P3-02**.
- **Severity:** High
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/MapRegistry.lua:122-125` (TrainingGround has no `Model` and no `Vote = false`), `game/ServerScriptService/HubServer.server.lua:315-323` (voteChoices includes any map with no Model), `:274-289` (team/duel matches go to the voted map); dummies: manifest `Workspace/TrainingGround/Dummies/*` (TrainingDummy, one Thrower, one Strafer); `game/ServerScriptService/TrainingGround.server.lua:316-342` (dummies never die and refill), `:87-89, 157-163, 225-262` (thrower targets any player with Zone Arena + Map TrainingGround, `humanoid:TakeDamage` bypassing CombatCore); `game/ServerScriptService/CombatCore.lua:314-316` (DealDamage charges the caster's Ultimate for health removed from ANY humanoid that is not their own body); `game/ServerScriptService/ToxinHandler.server.lua:259-262` (Symbiosis heals off any DoT victim, dummies included); `game/ServerScriptService/UmbraHandler.server.lua:722-741` ("a dummy counts" for the Shadow Step dive reward); `game/ServerScriptService/PyroHandler.server.lua:483-492` (Ember Refund on any victim crossing 30%); `game/ServerScriptService/StatusEffects.lua:270-276` + `VoltaicHandler.server.lua:339-355` (Chain Reaction on Charged filling, dummies included); `game/ServerScriptService/SpellshotService.server.lua:648-657` (snowball damage taken also charges Ultimate).
- **Trigger:** A Quick Play team match (Sparks-paying) or pad duel whose vote picks TRAINING GROUND. Any player walks to the dummy line and shoots dummies.
- **Why it's a bug:** `UltChargePerDamage = 1/260` and dummies refill to 150 from 0 instantly, so ~260 damage on a dummy = a full Ultimate; a Toxin heals off poison ticks on a dummy; Umbra halves Shadow Step's cooldown; Pyro/Voltaic shave Primary cooldowns — all without engaging the enemy. RadiantHandler explicitly excludes dummies from Halo for exactly this reason ("a dummy refills: beaming one would be free healing mid-duel", RadiantHandler.lua:595-603) but no other kit or the Ultimate meter does. The Thrower snipes duellists for 10 per hit (never below HitFloor) through `TakeDamage`, i.e. no shields/Bedrock and it feeds their Ultimate.
- **Suggested fix:** mark the range `Vote = false` (as TrainingGrounds is), or give it a Model and keep matches off it; independently, make `Core.DealDamage` charge the Ultimate only for damage to PLAYER victims (or exclude `TrainingDummy`/`DecoyOwner`/`WallOwner`), give Symbiosis/dive/Ember Refund/Chain Reaction the Halo rule, and have the Thrower skip players with a `DuelMatch` attribute.
- **Notes:** Also inflates Patient Zero's ally multiplier (dummies count as the target's allies, ToxinHandler.lua:529-541).

#### P1-05: Temporary capture-stage scripts ship in ServerScriptService and StarterPlayerScripts with no Studio gate — if Enabled they break every live server
> **Consolidator:** canonical entry for: Temporary stage scripts ungated (if Enabled). Also reported as **P6A-01**, **P6A-02**, **P5A-01**, **P5F-01**, **P5C-06**, **P5B-15**.
- **Severity:** High
- **Confidence:** Medium (the manifest does not record Enabled/Disabled)
- **Files/lines:** `game/ServerScriptService/_AuroraStage.server.lua:1-106`, `game/ServerScriptService/_BROStage.server.lua:1-101`, `game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua:1-18`, `game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua:1-12`; manifest entries at manifest.json ~38155 / ~38165 / ~24925 / ~24930.
- **Trigger:** A live server with these scripts enabled; the first player to join.
- **Why it's a bug:** `_AuroraStage` waits for `Players:GetPlayers()[1].Character`, sets that live player's `Archivable = true`, clones their character three times into `workspace.WrapStage` (anchored, Humanoid at full health, no TrainingDummy/AllyDummy attribute → damageable by anyone, feeding Ultimate per P1-04, and the "Caster" clone stays visible wherever the first player stood), stamps `WrapStudio = "Aurora"` on a live-server model (the brief: must never be reachable live; consumers do gate on IsStudio), and sets `workspace.CamPinEye/CamPinLook`. `_BROStage` then clones eight more into Persistent-streamed models and, on `BroGo`, pushes partial settings tables to the first player via SettingsSync. `_AuroraStageClient` — on every client — anchors the local root (`ch:WaitForChild("HumanoidRootPart").Anchored = true`), disables every ScreenGui and binds a RenderStep that pins the camera to those workspace attributes. No `RunService:IsStudio()` check in any of the four.
- **Suggested fix:** delete all four (the headers say "TEMPORARY ... remove when done"), or move them under ServerStorage/an unparented folder; at minimum `if not RunService:IsStudio() then return end` at the top of each.
- **Notes:** `TerraTestServer.server.lua` (also "TEMPORARY. Delete after the Terra pass") is harmless — player attributes are server-only — but is the same hygiene class. Cross-ref: settings/cosmetics passes for the WrapStudio leak.

#### P1-06: A forfeit pays the full "win" Sparks reward with no minimum engagement — win-trading with alt accounts, and AFK losses still pay
> **Consolidator:** duplicate of **P2-05** (Forfeit wins pay full reward (farming)). Kept here for its slice-specific detail; counted once, under P2-05.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:277-296` (award), `:300-321` (finish), `:523-547` (drop: a team with nobody left forfeits immediately), `:570-577` (disconnect → drop); `game/ReplicatedStorage/Spellshot/EconomyConfig.lua:49-56` (win 150, loss 50, draw 75, +10 per round won).
- **Trigger:** Team Quick Play (Config.Team.Size = 3; `Size = 1` is documented as a test value). A group queues 3 mains + 3 alts; if the shuffle puts the alts together they all disconnect at round 1 → each main gets 150 Sparks for ~20 s. With Size 1 any two colluding accounts farm. AFK players are paid 50 + 10/round for a loss.
- **Why it's a bug:** `finish(match, 3 - i, "forfeit")` → `award(match, winner)` pays every present player `MatchSparks("win", match.Wins[i])` with no check on rounds played, damage dealt or match duration; Elements cost ~1500-2000 Sparks ("about 8-10 wins").
- **Suggested fix:** pay a forfeit win only the per-round part (or nothing) when fewer than N rounds were completed; require some participation (damage dealt / time alive) for any reward; rate-limit rewards per account per hour; log forfeit wins for review.
- **Notes:** Economy pass may grade this differently; the Robux path is unaffected.

#### P1-07: CastRequest (and most IceAbilityRemote actions) have no rate limit — free refused presses run server raycasts/overlaps, and BoulderCharge toggles are re-broadcast to every client
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:869-1097` (only the M1 branch has a rate gate, :953-961); free-when-refused work: `:1069-1076` (Precheck_<Id> invoked on every off-cooldown press), `:935-946` (ChargeOnCatch Ultimates are never spent on a miss), `game/ServerScriptService/ZephyrGustPadServer.server.lua:350-355`, `game/ServerScriptService/RadiantHandler.server.lua:665-669`, `game/ServerScriptService/UmbraHandler.server.lua:450-454`, `game/ServerScriptService/TerraHandler.server.lua:1104-1108`, `game/ServerScriptService/PyroHandler.server.lua:766-769`, `game/ServerScriptService/AbilityHandler.server.lua:1287-1290` (acquireCage: HumanoidsNear + Blocked raycasts per press), `game/ServerScriptService/TerraHandler.server.lua:897-900` (acquire), `game/ServerScriptService/ToxinHandler.server.lua:562-570`; amplification: `game/ServerScriptService/TerraHandler.server.lua:111-130` (every On after an Off creates a record and `broadcast`s BoulderChargeStart/Stop to all clients, no limit).
- **Trigger:** An exploit client with Mark/Gust Pad/Position Trade/Aftershock off cooldown and no valid target, or with a full meter on Cryo/Terra/Toxin, sends CastRequest thousands of times a second; or a Terra toggles `BoulderCharge {On=true}` / `{On=false}` every frame.
- **Why it's a bug:** each refused precheck press costs nothing (by design) but runs GetPartBoundsInRadius plus up to 8 raycasts per candidate; ChargeOnCatch Ultimates likewise. Every IceAbilityRemote message is also dispatched to ~26 separate OnServerEvent connections across 9 scripts. BoulderCharge turns one client packet into a FireAllClients per toggle — a server-to-everyone bandwidth amplifier. Smaller unthrottled reflectors: SettingsSync "request" (SettingsStore.lua:117-118), MovementModeRequest non-dev "denied" (MovementModeServer.lua:30-33), CastRequest charge refusals (`refuseCharge`, SpellshotService.lua:801-804), RadiantLanceStop (RadiantHandler.lua:347-355), MoveRequest (every Slide/None flip rewrites replicated MoveState/SlideReadyAt).
- **Suggested fix:** a per-player token bucket at the top of the CastRequest handler (e.g. 20/s burst 30) and on BoulderCharge (and a minimum hold before a new On is broadcast); a cheap per-player bucket in front of every IceAbilityRemote action; drop, don't answer, over-rate SettingsSync/MovementModeRequest.
- **Notes:** none.

#### P1-08: Patient Zero has no "one at a time" guard; under Deferred signal behaviour several Ultimate requests in one frame each pass the meter check and each cast a Patient Zero
> **Consolidator:** canonical entry for: Patient Zero double-cast under Deferred signals. Also reported as **P3-08**.
- **Severity:** Medium
- **Confidence:** Medium (depends on Workspace.SignalBehavior, not recorded in the snapshot)
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:935-946` (ChargeOnCatch: checked, not spent), `game/ServerScriptService/ToxinHandler.server.lua:562-587` (castPatientZero spends `UltCharge = 0` itself, replaces `marks[player]`, schedules a detonation per cast); contrast `game/ServerScriptService/AbilityHandler.server.lua:1288` (`if cages[player] then return end`) and `game/ServerScriptService/TerraHandler.server.lua:898` (`if tombs[player] ...`).
- **Trigger:** Toxin with a full meter sends 3-5 `CastRequest("Ultimate", {Target=...})` in one frame. With `SignalBehavior = Deferred` (the default for new places) PerformCast handlers run after all queued remote handlers, so every request still reads `UltCharge >= 1`.
- **Why it's a bug:** each deferred `castPatientZero` finds a target and arms its own `task.delay(P.Telegraph, ...)`; the delayed callback only does `if marks[player] == m then marks[player] = nil end` and then detonates regardless — N bursts + N clouds for one charge. Mirror Cage and Earthen Tomb are protected by their guards; Patient Zero is not. In Immediate mode the first cast zeroes the meter synchronously and the rest are refused.
- **Suggested fix:** in SpellshotService, mark ChargeOnCatch Ultimates as "in flight" on the character (e.g. `UltPending = serverNow` cleared by the ability) and refuse a second request while it is set; in ToxinHandler add `if marks[player] then return end` and have the delayed callback bail when `marks[player] ~= m` was replaced.
- **Notes:** none.

#### P1-09: Aimed area abilities clamp the aim point to range but never check line of sight — zones, pads, tanks and storms can be placed through walls into sealed rooms
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:308-313` (cursorFloor: Flash Freeze, Blizzard), `game/ServerScriptService/ZephyrGustPadServer.server.lua:119-125` (spotFor), `game/ServerScriptService/AquaHandler.server.lua:127-130, 581-583, 791-793` (aimedGround: Twin Tide, Leviathan's Maw), `game/ServerScriptService/ToxinHandler.server.lua:149-152, 629-631` (Acid Rain), `game/ServerScriptService/VoltaicHandler.server.lua:956-962` (Cascade), `game/ServerScriptService/PyroHandler.server.lua:668-683, 734-737` (Ring of Fire + steer: flat distance only, Y unbounded), `game/ServerScriptService/ZephyrHandler.server.lua:589-593, 679-689, 716-718` (Cyclone + steer: flat distance only).
- **Trigger:** An exploit client sends `Target`/`Center` behind a wall (within Range), e.g. Leviathan's Maw into the enemy's closed room, Flash Freeze through a door, Ring of Fire on the floor above/below by choosing Y.
- **Why it's a bug:** the honest client derives the point from a camera raycast (SpellshotInput.client.lua:166-187, 702-732), so it can only target what it can see; the server takes the point after `ClampTarget` (CombatCore.lua:115-122) / a flat-distance test, then probes straight down for a floor — nothing tests eye→point visibility. Ring of Fire/Cyclone accept any Y within 1e6 and then raycast down 60 studs from there, so a point on another storey is accepted.
- **Suggested fix:** in a shared helper, raycast from the server's head to the requested point (through bodies, stopping on world/Bulwark Wall) and pull the point back to the first hit; bound |Y - root.Y| for Circle/Cyclone points.
- **Notes:** Target-lock abilities (Mirror Cage, Earthen Tomb, Mark, Blessing, Position Trade, Patient Zero) already do `Core.Blocked` from the eye — those are clean.

#### P1-10: Bulwark Charge always runs its full server window: no client ever sends "BulwarkChargeEnd", and the charge is accepted while rooted
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:377-385` (listener), `:356-375` (cast: no speed-cap/root check), `:423-442` (sweep + 40% reduction for `C.MaxTime`), `:1396-1400` (Bedrock "committing" while `charges[player]`); `game/ServerScriptService/SpellshotService.server.lua:1045-1097` (cooldown path checks no speed cap); grep: the string "BulwarkChargeEnd" appears only in TerraHandler (sender absent from SpellshotInput / TerraFX / every client module).
- **Trigger:** Terra presses Bulwark Charge into a wall (the dash stops on frame 1), or while rooted by Flash Freeze/Deep Freeze/Mirror Cage (the honest client refuses — `DashMotor.CanStart(character, C.MinCap)`, SpellshotInput.client.lua:858-864 — but the server would accept a modified client's request).
- **Why it's a bug:** the comment at :377-381 says the 2026-09-21 fix lets the client shorten the window "stopped dead on a wall on the first frame", but nothing fires it, so every charge keeps the 40% damage reduction, the damage sweep and Bedrock stacking for the whole MaxTime regardless. A rooted exploit client gets all three while standing still (and per P1-03 can move the sweep box anyway).
- **Suggested fix:** have the client send `BulwarkChargeEnd` when DashMotor ends (or end it server-side when the root's server-side displacement stalls); refuse the cast in TerraHandler (giveBack) when `SpeedCapSlow`/`SpeedCapUlt` is below `C.MinCap`, mirroring ZephyrHandler's `cannotDash`.
- **Notes:** none.

#### P1-11: A NaN shot Id raises "table index is NaN" in six release handlers (fixed in TerraHandler only)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:829, 875`; `game/ServerScriptService/PyroHandler.server.lua:269, 304`; `game/ServerScriptService/ZephyrHandler.server.lua:142, 184`; `game/ServerScriptService/AquaHandler.server.lua:357, 402` and `:653, 705`; `game/ServerScriptService/UmbraHandler.server.lua:530, 568`. Fixed reference: `game/ServerScriptService/TerraHandler.server.lua:169-174`.
- **Trigger:** Any client sends e.g. `ShardRelease { Id = 0/0, Origin = <head>, Target = <any> }`.
- **Why it's a bug:** each checks only `type(id) == "number"`, then writes `mine[id] = {...}`; Luau raises on a NaN key. TerraHandler's comment names it "a script error a client could ask for at will". Impact is error-log flooding (each event runs on its own thread, so no connection dies); in UmbraHandler the charge is consumed (:542) and in Aqua/Sidearm the bucket token/`h.Shots` increment before the error.
- **Suggested fix:** add `id == id` (and a finite/abs bound) next to every `type(id) == "number"`; or one `Core.ValidId(id)`.
- **Notes:** none.

#### P1-12: M1 hit-report remotes are decoupled from CastRequest — an exploiter's M1s never pay mana
> **Consolidator:** canonical entry for: M1 hit remotes never pay mana. Also reported as **P5D-13**, **GC-13**. Canonical severity **Medium** (this entry said Low).
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:818-880` (ShardRelease), `game/ServerScriptService/PyroHandler.server.lua:262-309`, `game/ServerScriptService/ZephyrHandler.server.lua:135-190`, `game/ServerScriptService/TerraHandler.server.lua:162-226`, `game/ServerScriptService/VoltaicHandler.server.lua:429-509`, `game/ServerScriptService/AquaHandler.server.lua:350-410`; mana is only taken in `game/ServerScriptService/SpellshotService.server.lua:962-965`.
- **Trigger:** Cryo/Pyro/Zephyr/Terra/Voltaic/Aqua exploit client sends the release+hit pair and never the `CastRequest("M1")`.
- **Why it's a bug:** each release handler applies its own rate bucket and CanAct but never consults or debits SpellshotService's mana (ManaCost 0.8-4 per shot). Umbra (charge record), Radiant (lance record) and Toxin (server-simulated) are correctly tied to the paid CastRequest. Also skips no other gate of importance (Hub/CastLocked/interrupt are covered by CanAct).
- **Suggested fix:** have the M1 CastRequest create a short-lived "paid shot" token per player that the release handler must consume (as Umbra's `charges[player]` does), or debit mana in the release handler via SpendMana.
- **Notes:** small numbers by design ("a trickle"), hence Low.

#### P1-13: Interrupts are not honoured by Sidearm's drawn shot or Cross-Slash's strike (AliveCharacter instead of CanAct)
> **Consolidator:** canonical entry for: Sidearm / Cross-Slash strike ignore interrupts (AliveCharacter). Also reported as **P3-11**.
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/AquaHandler.server.lua:643-683` (SidearmShot: `Core.AliveCharacter`; the first shot path checks only the draw window, not `h.Held`, so it is accepted up to DrawTime+1.5 s after the press even after `interrupt()` released the hold, :493-502); `game/ServerScriptService/ZephyrHandler.server.lua:444-445` (CrossSlashStrike uses AliveCharacter); compare `game/ServerScriptService/CombatCore.lua:83-93`.
- **Trigger:** Aqua presses Sidearm and is struck by Undertow/Aftershock before the drawn shot leaves; or a Zephyr is interrupted mid-glide before its Trigger.
- **Why it's a bug:** `InterruptedUntil` is meant to refuse casting (CanAct's own comment), but these two damage paths do not ask CanAct, so the interrupted body still deals the shot/strike. SidearmShot also never re-checks Zone/holds after a loadout change (only possible outside duels).
- **Suggested fix:** use `Core.CanAct(player)` in both handlers; in SidearmShot also require `h.Held or now - h.ReleasedAt <= 0.25` for the first shot when an interrupt has ended the hold.
- **Notes:** none.

#### P1-14: Gust Pad and Position Trade use SameParty, so Solo Test / Training Grounds players who "cannot hurt each other" can be launched and teleported by strangers
> **Consolidator:** canonical entry for: Gust Pad / Position Trade act on solo strangers. Also reported as **P3-18**.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrGustPadServer.server.lua:204-223` (eligible: Zone + SameParty + team check, never MayHurt), `game/ServerScriptService/RadiantHandler.server.lua:638-646` (swappable: SameParty), `game/ServerScriptService/CombatCore.lua:156-158` (SameParty: same Map and both DuelMatch nil counts), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:184-193` (MayHurt false between solo players).
- **Trigger:** Two unrelated players on the same Solo map (e.g. the Training Grounds island). One drops a Gust Pad under the other or Position-Trades them.
- **Why it's a bug:** MayHurt's stated rule is "in a Solo Test players cannot hurt each other", and every damaging/CC path honours it via IsFriendly — but these two treat any same-map solo player as a valid target (Position Trade even moves them with a server PivotTo). Pure griefing outside matches.
- **Suggested fix:** for player victims require `not Core.IsFriendly(caster, model)` (enemy) for Gust Pad's launch, and `Core.IsAllyOf or (opponent in the same DuelMatch)` for Position Trade.
- **Notes:** Blessing/Benediction also treat solo strangers as allies (harmless heals).

#### P1-15: Skin/wrap ownership gate is a stub — any client can equip any rarity (Mythic) skin or wrap
> **Consolidator:** duplicate of **P2-06** (OwnsSkin always true: every cosmetic free). Kept here for its slice-specific detail; counted once, under P2-06.
- **Severity:** Low (becomes High the moment skins are sold)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:421-423` (`return SkinCatalog.Skins[skinId] ~= nil`), `game/ServerScriptService/SpellshotService.server.lua:717-747`.
- **Trigger:** `LoadoutRequest("ElementSkin", "Cryo", "FrostDragon")` from any Cryo player.
- **Why it's a bug:** the server's only ownership check returns true for every catalogued skin; the comment calls it "the one place gating will go". Nothing in PlayerData tracks skins.
- **Suggested fix:** back OwnsSkin with PlayerData (an `OwnedSkins` set in the save) before any skin is put on sale.
- **Notes:** cosmetics pass may track the tier side.

#### P1-16: Relay broadcasts forward client numbers that are NaN-unsafe or unverified (Boulder "Charge" tell, Bulwark Charge "Dist")
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:151-154` (castBoulderShot: `math.clamp(tonumber(payload.Charge) or 0, 0, 1)` used whenever no release came within 0.3 s), `:372` (BulwarkCharge `Dist = math.clamp(tonumber(payload.Dist) or C.Distance, ...)`).
- **Trigger:** A Terra sends `CastRequest("M1", {Charge = 1})` with no BoulderRelease (every other client draws a full-charge rock throw that deals nothing), or `Charge`/`Dist` = NaN.
- **Why it's a bug:** `math.clamp(NaN, a, b)` returns NaN in Luau, so NaN reaches every client's FX handler (AbilityFX runs each in `task.spawn`, so it only kills that effect). The Charge fallback lets a player fake the "readable tell" the comment at :137-141 says must match the hit.
- **Suggested fix:** reject non-finite numbers (`x == x and math.abs(x) < huge`) before clamping; when no accepted release exists, broadcast Charge 0 (or nothing).
- **Notes:** none.

#### P1-17: GiveBack refunds the mana of whatever is in the slot NOW, not of the cast being given back
> **Consolidator:** duplicate of **P4-08** (GiveBack/cooldowns keyed by slot not ability). Kept here for its slice-specific detail; counted once, under P4-08.
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:841-850` (`local ability = abilityForRole(p, role)`); delayed give-backs: `game/ServerScriptService/RadiantHandler.server.lua:690-703` (after DissolveTime), `game/ServerScriptService/UmbraHandler.server.lua:780-792` (queued step).
- **Trigger:** Outside a duel (loadout unlocked), cast Position Trade, change Element/Technique during the dissolve, and the swap fails its floor check → refund is the new slot ability's ManaCost and the new slot's CD_ is cleared.
- **Why it's a bug:** the give-back should undo the cast that happened; it reads the current loadout instead, so it can refund more mana than was paid and clear a different ability's cooldown.
- **Suggested fix:** pass the ability Id to GiveBack and refund `AbilityById[id].ManaCost`, or record the paid cost per role in state when the cast is accepted.
- **Notes:** only outside matches; no competitive impact today.

#### P1-18: Damaging an enemy's Decoy Double or Bulwark Wall charges the attacker's Ultimate
> **Consolidator:** duplicate of **P3-09** (Ult charge from walls/decoys/self-damage). Kept here for its slice-specific detail; counted once, under P3-09.
- **Severity:** Low
- **Confidence:** Low (may be intended)
- **Files/lines:** `game/ServerScriptService/CombatCore.lua:314-316`, `game/ServerScriptService/UmbraHandler.server.lua:839-884`, `game/ServerScriptService/TerraHandler.server.lua:540-547` (wall humanoid, 200 HP).
- **Trigger:** Shoot an enemy Terra's Bulwark Wall for its full WallHP.
- **Why it's a bug:** "The Ultimate charges from damage DEALT" is read as damage to players in the manual; the code counts any humanoid that is not the caster's body, so a 200 HP wall is ~77% of an Ultimate for the attacker. (The decoy breaks on the first hit, so it is small.)
- **Suggested fix:** decide the rule; if players only, gate `addUltCharge` on `Players:GetPlayerFromCharacter(humanoid.Parent)` (this also closes the dummy half of P1-04).
- **Notes:** design confirmation needed.

#### P1-19: Hub shrine prompts would change Element with no Zone / match check (dormant)
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/HubServer.server.lua:559-579`.
- **Trigger:** A `Shrine_<Element>_Monument` part existing anywhere in the Hub model (none today per the header, :45-47).
- **Why it's a bug:** unlike LoadoutRequest (:750-757) the shrine calls `Config.ApplyElement` without checking `DuelMatch`/Zone; harmless only because no monument is named so. Re-adding a shrine would reopen a mid-match Element swap path if a duelist could trigger it (round-1 Zone is still "Hub" during the first respawn, HubServer.lua:230).
- **Suggested fix:** route the shrine through the same checks as LoadoutRequest "Element" (or delete the dead code).
- **Notes:** none.

#### Appendix A — every client→server remote

| Remote (creator) | Action / args | Server handler | Client sender(s) | Validated | Trusted / gaps |
|---|---|---|---|---|---|
| Spellshot.CastRequest RemoteEvent (SpellshotService.lua:76) | (role:string, payload:table) | SpellshotService.lua:869-1097 → PerformCast to every kit | SpellshotInput.client.lua 307, 592, 602, 670, 843, 871, 1103, 1135, 1225, 1273, 1290, 1359, 1435, 1468, 1512, 1637, 1858; ToxinClient 101; VoltaicClient 397, 426; UmbraClient 314; RadiantClient 224; DevPanel 247-248, 304, 318; TerraTestHarness 114-351 | role string; ability via AbilityFor (own Element, OwnElementOnly); Hub/CastLocked/Burrowed/InterruptedUntil/alive/Implemented; cooldown/charges/mana/UltCharge server-side; Precheck; Escape set server-side; held Phase server-built | no rate limit except M1 (P1-07); payload fields forwarded raw to kit handlers (Target/Center/Dir/Start/Dist/Charge/LanceId) — see P1-01/09/10/16; ChargeOnCatch not spent (P1-08) |
| Spellshot.MoveRequest (SpellshotService.lua:77) | (state) | SpellshotService.lua:269-330 | MovementController.client.lua 314, 462, 1182 | whitelist; alive; slide backstop | no rate limit; no SlideRegap; speed is client-owned (P1-03) |
| Spellshot.DevRequest (SpellshotService.lua:78) | (action, a, b, c) | SpellshotService.lua:376-554 | DevPanel 161; TerraTestHarness 307; VoltaicTestHarness 610 | Config.IsDev | dev args unchecked (a/b numbers); live dev (P1-02) |
| Spellshot.LoadoutRequest (SpellshotService.lua:79) | ("Element"/"Technique"/"Skin"/"ElementSkin"/"ElementWrap", a, b) | SpellshotService.lua:710-784 | LoadoutMenu 506, 842, 962, 1064, 1160, 1297-1303; VoltaicTestHarness 581 | 0.08 s; types; IsBuilt; PlayerData.Owns; MayEquip; duel lock (Zone Arena + DuelMatch); skin Allowed | OwnsSkin stub (P1-15); cosmetics allowed mid-duel by design |
| IceMagic.IceAbilityRemote (CombatCore.lua:49-55) | "UltAim"(Vector3) | AbilityHandler.lua:706-716 | SpellshotInput 1835 | ultimates[player], 30/s, ValidVector, clamp | unreachable (Cryo Beam has no row) |
| 〃 | "ShardRelease"{Id,Origin,Target} | AbilityHandler.lua:818-880 | SpellshotInput 1507 | Hub, holds M1, CanAct, ValidVector, bucket, origin allowance | Id NaN (P1-11); allowance uncapped (P1-01); no mana (P1-12) |
| 〃 | "ShardHit"{Id,Part,Position} | AbilityHandler.lua:883-951 | SpellshotInput 1509 | shot record, life, part/pos, on-line, flight time, WasThere/on-part, Blocked from claimed origin | origin-based LOS (P1-01) |
| 〃 | "FireballRelease"{Id,Origin,Dir} | PyroHandler.lua:262-309 | SpellshotInput 1353 | as Shard | P1-01, P1-11, P1-12 |
| 〃 | "FireballHit"{Id,Part,Position} | PyroHandler.lua:396-439 | SpellshotInput 1356 | as Shard (arc) + CheckTarget + flightBlocked | P1-01 |
| 〃 | "RingOfFireSteer"(Vector3) | PyroHandler.lua:721-740 | SpellshotInput 752, 774 | ring record, before LockAt, 30/s bucket, alive, flat range, ground | no LOS, Y unbounded (P1-09) |
| 〃 | "ScorchingLashStrike"{Origin,Dir,Hits} | PyroHandler.lua:1097-1223 | SpellshotInput 1035 | bucket, lash record, epoch, Hub, holds, CanAct, timing, CAPPED origin, sector, server reach, CheckTarget, IsFriendly, LOS from chest, MaxTargets | clean (the reference implementation) |
| 〃 | "WindBladeRelease"{Id,Origin,Dir} | ZephyrHandler.lua:135-190 | SpellshotInput 1428 | as Shard | P1-01, P1-11, P1-12 |
| 〃 | "WindBladeHit"{Id,Part,Position} | ZephyrHandler.lua:193-290 | SpellshotInput 1432 | on-line, flight, CheckTarget (+on-part save), repeat, Blocked (+server-head save), Pierce | P1-01 |
| 〃 | "CrossSlashStrike"{Origin,Dir,Hits,Passed} | ZephyrHandler.lua:430-515 | SpellshotInput 558 | slash record (launch checked), Struck, epoch, Hub, holds, timing, origin on dash line, corridor/reach, CheckTarget window, IsFriendly, Blocked, MaxPath/MaxTargets | AliveCharacter not CanAct (P1-13); launch Start uncapped (P1-01) |
| 〃 | "CycloneSteer"(Vector3) | ZephyrHandler.lua:704-728 | SpellshotInput 804, 827 | cyclone Forming, bucket, alive, flat reach, ground, SteerSpeed | no LOS / Y (P1-09) |
| 〃 | "BoulderCharge"{On} | TerraHandler.lua:111-130 | SpellshotInput 1581, 1591; TerraTestHarness 69, 106 | Hub, holds, CanAct | no rate limit; broadcasts each toggle (P1-07) |
| 〃 | "BoulderRelease"{Id,Origin,Dir,Charge} | TerraHandler.lua:162-226 | SpellshotInput 1632; TerraTestHarness 105 | NaN Id, bucket, origin, Charge capped by server-timed hold | origin uncapped (P1-01); no mana (P1-12) |
| 〃 | "BoulderHit"{Id,Part,Position} | TerraHandler.lua:291-337 | SpellshotInput 1635; TerraTestHarness 111 | arc, flight, CheckTarget, flightBlocked | P1-01 |
| 〃 | "BulwarkChargeEnd" | TerraHandler.lua:382-385 | (none — no sender exists) | only shortens | dead path (P1-10) |
| 〃 | "ChainBoltFire"{Origin,Dir,Side,Part,Position} | VoltaicHandler.lua:429-509 | VoltaicClient 362 | Hub, holds, CanAct, bucket, eyeNear, on-line, checkClaim, claimBlocked, chain server-side | eyeNear uncapped (P1-01); no mana (P1-12) |
| 〃 | "RailspikeFire"{Origin,Dir,Hits,End} | VoltaicHandler.lua:534-641 | VoltaicClient 542 | rail record, CanAct, epoch, Hub, slot, windup timing, eyeNear, server world dist (End only shortens), MaxPierce, checkClaim, claimBlocked | P1-01 |
| 〃 | "RiptideRelease"{Id,Origin,Dir} | AquaHandler.lua:350-410 | AquaClient 97 | Hub, holds, CanAct, bucket, origin vs root, server wave reach | P1-01, P1-11, P1-12 |
| 〃 | "RiptideHit"{Id,Part,Position} | AquaHandler.lua:412-485 | AquaClient 101 | path width, flight, CheckTarget(+save), repeat, crest height | crest uses client-owned height (P1-03) |
| 〃 | "SidearmShot"{Id,Origin,Dir,N} | AquaHandler.lua:643-711 | AquaClient 621 | hold record, draw window, held/grace, bucket, mana attr, origin | AliveCharacter (P1-13); P1-01; P1-11 |
| 〃 | "SidearmHit"{Id,Part,Position} | AquaHandler.lua:713-786 | AquaClient 623 | on-line, flight, CheckTarget(+save), Blocked | P1-01 |
| 〃 | "ShadowDartRelease"{Id,Origin,Target} | UmbraHandler.lua:523-573 | UmbraClient 354 | Hub, holds, CanAct, paid charge + windup timing, bucket, eyeNear | P1-01, P1-11 |
| 〃 | "ShadowDartHit"{Id,Part,Position} | UmbraHandler.lua:575-638 | UmbraClient 360 | on-line, flight, checkClaim, claimBlocked, isHeadshot server-side | P1-01 |
| 〃 | "RadiantLanceAim"{Dir,Origin,Part,Position} / "RadiantLanceStop"{Id} | RadiantHandler.lua:346-409 | RadiantClient 205, 251, 253 | lance record (paid M1), aim bucket, CanAct, dir vs facing, aimOrigin, on-line, checkClaim, claimBlocked; server LOS + range per tick | aimOrigin uncapped (P1-01); Stop unthrottled (cheap) |
| 〃 | "SkyriderEnd"(reason) | ZephyrSkyriderServer.lua:159-164 | ZephyrSkyrider 730, 925 | ride record; reason whitelist | only ends own ride |
| 〃 | "SkyriderGust"{Dir} | ZephyrSkyriderServer.lua:294-314 | ZephyrSkyrider 858 | ride record, CanAct, summon time, cooldown, mana; cone from server root | root is client-owned (P1-03) |
| Spellshot.Hub RemoteEvent (HubServer.lua:68-73) | ("vote", voteId, mapId) / ("queue", mode) / ("cancel") / ("solo") / ("return") | HubServer.lua:1075-1138 | MapVote 329; QuickPlay 805, 893; HubClient 602 | vote id/choice; 0.25 s (cancel exempt); zone/vote/move/match checks; dev-only leave | dev leave forfeits (P1-02) |
| Spellshot.SettingsSync (SettingsStore.lua:50-55) | ("request") / ("save", table) | SettingsStore.lua:114-126 | SettingsRuntime 93, 96 | Sanitise; 0.4 s on save | "request" unthrottled reflector (P1-07) |
| Spellshot.EconomyRequest RemoteFunction (EconomyService.lua:30-35) | InvokeServer("UnlockElement", element) | EconomyService.lua:66-79 → PlayerData.BuyElement | LoadoutMenu 739 | 0.5 s; all economics server-side | clean |
| Spellshot.MovementModeRequest (manifest; pre-existing instance) | (mode) | MovementModeServer.lua:29-38 | DevPanel 607 | IsDev, whitelist | "denied" reflector unthrottled (P1-07) |
| Spellshot.DeflectPracticeRemote (TrainingGround.lua:74-79) | anything | TrainingGround.lua:82 (no-op) | (none) | — | clean |
| Spellshot.KillFeed (SpellshotService.lua:80) | server→client only | — | — | — | — |

Bindables a client cannot reach (server-only, listed for completeness): PerformCast, ApplyStatus, AddUltCharge, ReleaseHold, SpendMana, GiveBack, JumpLock, AquaRiptideHit, Precheck_<Id> BindableFunctions (all in ReplicatedStorage.Spellshot — clients can see them but a client-side Fire/Invoke never reaches the server), ServerStorage.ShotImpact, ServerStorage.ReactionsDebug.

#### Could not complete
- Client modules that send remotes (VoltaicClient, UmbraClient, RadiantClient, AquaClient, ToxinClient, ZephyrSkyrider, LoadoutMenu, DevPanel, MovementController, HubClient, QuickPlay, MapVote, SettingsRuntime, the two test harnesses) were read only at their sender lines, not in full — enough to map payload shapes; their client-side logic belongs to other passes.
- VFXLibrary.lua read only in the ability-row / AbilityFor region (200-545) and ShotTimeScale (4916-4920); GroundBelow / FlashFreezeCentre / ApplyFrozenState were not read (used here only as server-side probes).
- Whether `_AuroraStage`/`_BROStage`/their clients are Enabled, and Workspace.SignalBehavior, are not in the snapshot (P1-05, P1-08 confidence).


---

## Pass 2 — Economy and persistence

_Entries: 18 (1 High / 6 Medium / 11 Low). Distinct after merging duplicates: 15 (1 High / 5 Medium / 9 Low)._

### Pass 2 — Economy and persistence

#### Files read (complete list, with "fully" or "partially: lines X-Y" for each)
- game/ServerScriptService/PlayerData.lua — fully (1-554)
- game/ServerScriptService/EconomyService.server.lua — fully (1-79)
- game/ServerScriptService/SettingsStore.server.lua — fully (1-144)
- game/ServerScriptService/SpellshotService.server.lua — fully (1-1159)
- game/ServerScriptService/HubServer.server.lua — fully (1-1138)
- game/ServerScriptService/DuelMatch.lua — fully (1-579)
- game/ReplicatedStorage/Spellshot/EconomyConfig.lua — fully (1-118)
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua — fully (1-613)
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua — fully (1-424)
- game/StarterGui/SpellshotShop/Catalog.lua — fully (1-63)
- game/StarterGui/SpellshotShop/ShopController.client.lua — fully (1-1072)
- game/StarterGui/SpellshotShopButton/ShopButton.client.lua — fully (1-82)
- game/StarterGui/SpellshotShop/CardKit.lua — partially: lines 1-75, 306-360, 1165-1190, plus a grep sweep of every price / Sparks / Robux / BAL / attribute / remote line (the module's header says "pure drawing: no state, no input, no remotes, no MarketplaceService", confirmed by grep: no FireServer/InvokeServer/MarketplaceService call in it)
- game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua — partially: lines 1-230, 400-530, 620-770, 870-1170, 1270-1352, plus a grep of every FireServer/InvokeServer (all seven send sites at 506, 739, 842, 962, 1064, 1160, 1297-1303 read in context)
- game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua — partially: lines 1-60, 465-485, 725-825, 1180-1210, plus a grep of every remote / Settings.Set / Reset call (it sends nothing itself; every change goes through Settings.Set and SettingsRuntime pushes)
- Cross-referenced: game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua lines 70-120, 300-330; game/ReplicatedStorage/Spellshot/SpellshotConfig.lua lines 140-255, 270-350 (Element Base colours), 495-575, 676-700; game/ServerScriptService/_BROStage.server.lua (fully, 1-101); game/ServerScriptService/_AuroraStage.server.lua lines 1-80; game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua lines 188-210; docs/SPELLSHOT_Design_Manual.md (grep for Sparks/Robux/starter/Cache lines 12, 530, 607-618, 626, 692-713); game/manifest.json (the _AuroraStage/_BROStage/PlayerData/EconomyService entries).
- Grep sweep of the whole game/ tree for DataStoreService, GetDataStore, UpdateAsync, SetAsync, GetAsync, IncrementAsync, RemoveAsync, MarketplaceService, ProcessReceipt, PromptProductPurchase, PromptGamePassPurchase, UserOwnsGamePassAsync, BindToClose, PlayerRemoving, "Sparks", "Owned", "Equip", ApplyElement, SetAttribute("Element"), OwnsSkin, OwnedElements, DataLoaded, DataError, SettingsSync. Only PlayerData and SettingsStore touch DataStores; only PlayerData sets ProcessReceipt; only ShopController prompts a purchase; no GamePass APIs anywhere; no IncrementAsync/RemoveAsync anywhere. Every other PlayerRemoving hit is per-ability cleanup unrelated to persistence.

#### Sub-areas checked with nothing found (explicit "checked, clean: ..." lines)
- checked, clean: the classic progress wipe. A live load that fails every retry sets `prof.failed` and leaves `prof.loaded = false`; `save` returns at `if not prof.loaded then return false end` (PlayerData.lua:245) and autosave/BindToClose/release all go through `save`, so defaults are never written over a real record. BuyElement answers "offline", ProcessReceipt answers NotProcessedYet (PlayerData.lua:370-372, 487).
- checked, clean: save-before-load. Nothing writes until `prof.loaded` is set at PlayerData.lua:332, after loadData has returned the normalised stored record; pending Sparks/Owned are merged INTO the loaded record (334-341), never the other way round.
- checked, clean: ProcessReceipt idempotency. PurchaseId is recorded in `data.Purchases` in the same synchronous block that credits the Sparks (375-385, no yield between check and credit, so two concurrent invocations of the same receipt cannot both pay); PurchaseGranted only when `save` returns true (387); player-not-here, not-loaded, failed, and lost-lock all return NotProcessedYet (369-372); a non-pack ProductId is left NotProcessedYet with a warning (363-366). ResetToStarter keeps Purchases (509). PurchaseLog cap (200) only evicts ids that were already granted (an id is only granted after a save that contains it).
- checked, clean: Sparks purchase atomicity/price. BuyElement (482-503) checks exists+built, owned, price (server-side `Economy.PriceOf`, client sends only the name), balance, then deducts and grants with no yield in between; no negative balance; buying an owned Element returns "owned"; NotForSale honoured; EconomyService throttles to one ask per 0.5 s (EconomyService.server.lua:66-71) and the RemoteFunction handler never yields.
- checked, clean: Element equip ownership on every server path that sets an Element: LoadoutRequest "Element" (SpellshotService.server.lua:758-775, Owns check), Hub shrine (HubServer.server.lua:568), join default (SpellshotService.server.lua:685-687, starter), EcoReset (404-405). The only bypass is the dev panel's SetElement (390-393), documented and gated by Config.IsDev (see P2-07 for who that is live).
- checked, clean: composite `"<Skin>+<Wrap>"` ids cannot be equipped directly. "Skin" requires `SkinCatalog.Allowed` (exact Offer list match), "ElementSkin" requires `ElementSkinAllowed` (exact ElementSkins list), "ElementWrap" requires `Skins[id].Wrap == element` and membership in ElementWraps (SkinCatalog.lua:413-418, 441-443, 460-466); a composite never matches any list. Composites are only built server/client-side by `Chosen()` from two individually validated attributes. Aurora (Wrap = "Cryo", not in ElementWraps) is refused. A skin/wrap for another Element is refused (`a ~= element` / `origin ~= element`).
- checked, clean: duplication on match end. `finish` is guarded by `match.State == "Over"` (DuelMatch.lua:301), so the run() path and the drop()/forfeit path cannot both award; `award` pays only `present` players (287), so a leaver gets nothing; Hub pad duels pay nothing (278). HubServer shrines grant nothing.
- checked, clean: integer handling. Sparks are floored on load (PlayerData.lua:103), AddSparks floors its argument (428), prices are floored (EconomyConfig.lua:87), pack amounts are integer literals. (Hardening note only: `AddSparks(NaN)` would set Sparks to `math.max(0, NaN)` = 0 in Luau, but every caller passes a constant or `MatchSparks` output, so it is unreachable.)
- checked, clean: SettingsStore input validation. Every client push goes through `Settings.Sanitise` (SettingsStore.server.lua:123), which rebuilds a fresh table of exactly the defined ids with type/range/NaN/KeyCode-name checks (SpellshotSettings.lua:175-209); unknown keys, nested tables and oversize strings are dropped; payload size is bounded by the definition list.
- checked, clean: SettingsStore DataStore budget. A client push only marks the record dirty (SettingsStore.server.lua:120-125, 0.4 s gap); the actual SetAsync happens at most every 120 s per player plus once on leave/close, so a spamming client cannot burn the server's write budget.
- checked, clean: PlayerData DataStore budget in steady state: one UpdateAsync per player per 60 s plus one per match end / unlock / receipt, well inside 60 + 10 x players per minute; writes per player are serialised by `prof.saving`.
- checked, clean: client-trusted ownership. LoadoutMenu's lock/price display reads the server-written `OwnedElements`/`Sparks` attributes and is UI only; every equip/unlock is re-checked server-side. ShopController's Buy and daily Claim are local demos that change nothing server-side. No gameplay path reads a client-written attribute for ownership.
- checked, clean: PromptProductPurchase is guarded client-side for ProductId 0 (ShopController.client.lua:861) and server-side by `PackByProductId` (EconomyConfig.lua:99-105: 0 or non-number is never a pack).
- checked, clean: data size. The save is a handful of fields, Owned/Starter keyed by <=40-char names, PurchaseLog capped at 200 — far under the 4 MB limit.
- checked, clean: no MarketplaceService.ProcessReceipt set anywhere else (grep), so no second handler can swallow receipts.

---

#### P2-01: Same-server rejoin races the old profile's leave save against the new profile's load — progress (incl. a granted Robux receipt) can be overwritten
- **Severity:** High
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:191-195`, `:210-221`, `:244-281`, `:289-301`, `:316-355`
- **Trigger:** A player is removed from server A and a new Player for the same UserId joins server A before the old profile's leave write (`release`) has landed. Concretely: a client crash/reconnect where Roblox places them back in the same instance (friends-follow, a private/reserved server, a "rejoin" button teleporting to the same JobId), especially when the leave save is slow or retrying (`release` retries at 1, 2, 4, 8 s, and also waits on any in-flight autosave via `while prof.saving`).
- **Why it's a bug:** The session lock identifies the holder by `game.JobId` only, not by profile/session. `heldElsewhere` returns false whenever `old.Session.Job == game.JobId` (193), so the NEW profile's load claims immediately even though the OLD profile on the same server has not finished writing. `save`'s lost-lock test is also JobId-only (`old.Session.Job ~= game.JobId`, 260), so neither write sees the other. The two profiles are separate tables, so `prof.saving` does not serialise them. Outcomes, depending on order:
  (a) new load reads the record before the old release writes: the new session works from the older record; the old release then writes its newer snapshot with `Session = nil` (clearing the new session's lock); the new session's next autosave overwrites it with the older-based data. Anything the old session did since its last successful write is lost: match Sparks, an Element bought with Sparks, and — if the old session's ProcessReceipt save happened after the new load read — a Robux pack that Roblox has already marked PurchaseGranted (the PurchaseId is gone too, so it will never be retried).
  (b) in either order the lock ends up `nil` while the new session is live, so a third server would not wait for it at all.
- **Suggested fix:** Use a per-session lock token (e.g. `HttpService:GenerateGUID()` stored on the profile) instead of JobId for both `heldElsewhere` and the lost-lock test, so a second profile on the same server is "elsewhere". Additionally keep a per-UserId map of in-flight releases on this server and have `onJoin` wait for that release to finish (or reuse its data) before calling `loadData`. Make `release` only clear `Session` when it still holds its own token.
- **Notes:** Whether Roblox fires PlayerRemoving for the old Player before PlayerAdded for the new one on a same-server reconnect is engine behaviour outside the snapshot; either way the leave write and the new load are issued close together and unordered. Cannot be confirmed without live DataStore timing.

#### P2-02: A server whose lock was taken keeps writing if the thief has since released (Session == nil is treated as "still mine")
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:258-267`, `:226-229`, `:68`
- **Trigger:** Server A holds a player's lock; server B takes it (forced on its 5th try ~20 s after joining while A's lock is still fresh, PlayerData.lua:228, or after LOCK_STALE). The player plays on B and leaves B, whose release writes `Session = nil`. A then performs any later write for its stale profile — a leave save still being retried, a throttled/queued UpdateAsync that executes late, BindToClose, or an autosave if A still has a (ghost) Player for them.
- **Why it's a bug:** `save` flags a lost lock only `if type(old) == "table" and type(old.Session) == "table" and old.Session.Job ~= game.JobId` (260). When B has released, `old.Session` is nil, so A's transform proceeds and writes A's stale snapshot over B's newer record. A only sets `prof.lost` if it happens to write while B still holds the lock. DataStore requests that are throttled are queued and can execute many seconds later, and the transform runs against the value current at execution time, so "A's write lands after B's release" is plausible during a DataStore incident — exactly when B's forced take-over (`force = true` on the last try) is most likely.
- **Suggested fix:** Record the lock token (see P2-01) and treat "Session is not exactly my token" — including nil — as lost, except on the very first claim in `loadData`. Optionally store a monotonically increasing `SaveSeq` and refuse to write when the stored one is higher than the session's.
- **Notes:** Mostly bounded to DataStore-degraded conditions; same root cause as P2-01 (JobId-only identity, no token/version).

#### P2-03: Writes issued after a leave save re-lock the record for this server, so the player's next server waits ~20 s on the starter kit
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:251-266`, `:304-311`, `:387`, `:536`, `:207-240`
- **Trigger:** Any non-releasing `save` that runs after `release` has written `Session = nil`: ProcessReceipt's `save(player, prof)` (387) when the player leaves while the receipt is waiting on `prof.saving`; an autosave thread spawned just before the leave (536) that was waiting on `prof.saving`; a `saveSoon` from AwardMatch/BuyElement deferred across the leave. Also: a load whose UpdateAsync committed server-side but errored to the caller, followed by the player leaving (208).
- **Why it's a bug:** These calls pass `releasing = nil`, so `out.Session = { Job = game.JobId, T = os.time() }` (265) re-stamps a fresh lock after the release. Nothing releases it again (the profile is gone from `profiles`). The next server sees a fresh foreign lock and loops LOCK_WAIT x 4 = 20 s before forcing (227-229); for that time the player is on the starter kit, DataLoaded = false, purchases answer "loading", and receipts NotProcessedYet. If one of the waits errors instead, the last try is not forced and the load can end "failed" (only `held` on try LOAD_TRIES-1 sets `force`), leaving them on starters for the whole session with "spending paused".
- **Suggested fix:** Mark the profile as released (e.g. `prof.released = true` inside `release`) and make every later `save` either skip or keep `Session = nil`. Set `force` whenever `try >= LOAD_TRIES - 1`, not only when that try was `held`.
- **Notes:** Cosmetic-to-annoying, no data loss.

#### P2-04: If GetDataStore fails on a LIVE server, the whole server runs memory-only and Robux receipts are granted without being saved
- **Severity:** Medium
- **Confidence:** Medium (logic: High; likelihood of GetDataStore throwing on a live server: Low, unverifiable from the snapshot)
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:517-527`, `:198-203`, `:246-249`, `:387`
- **Trigger:** `DataStoreService:GetDataStore(STORE_NAME)` throws during `PlayerData.Start()` on a non-Studio server.
- **Why it's a bug:** `Start` sets `memoryOnly = true` on any GetDataStore failure without checking `RunService:IsStudio()` (524-527), unlike `loadData`'s error branch which only goes memory-only in Studio (231-235). In memory mode every player gets `blank()` with `persist = false` and `loaded = true` (202, 332), so they see 0 Sparks and only starters, and `save` returns true immediately ("memory only: nothing to write, nothing lost", 246-249). ProcessReceipt therefore returns PurchaseGranted (387) for a Sparks pack that is credited only in memory and vanishes on leave: Robux are taken and the receipt will never be retried. Sparks earned/spent that session are also silently discarded.
- **Suggested fix:** On a live server, treat a GetDataStore failure like a failed load: retry acquiring the store, and until it succeeds mark profiles `failed` (spending and receipts paused) rather than `memory`. Never let `save` report success for a receipt unless `prof.persist` is true; in ProcessReceipt require `prof.persist` (or Studio) before granting.
- **Notes:** The header (lines 46-49) says a live server that cannot load "pauses spending and Robux receipts"; this path contradicts it.

#### P2-05: Forfeit wins pay the full win reward with no participation minimum — Sparks farming with alts or a dev's BACK TO HUB
> **Consolidator:** canonical entry for: Forfeit wins pay full reward (farming). Also reported as **P1-06**.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:277-296`, `:523-547`, `:560-567`; `game/ReplicatedStorage/Spellshot/EconomyConfig.lua:50-56, 91-96`; `game/ServerScriptService/HubServer.server.lua:1095-1102`
- **Trigger:** Team match (Quick Play, `Config.Team.Size = 3`, 6 players). One whole team disconnects (or, for a dev account, presses BACK TO HUB, which calls `DuelMatch.Leave`) right after round 1 starts. Repeat. With `Config.Team.Size = 1` (the "2-client test" setting the config comment invites) it takes one alt.
- **Why it's a bug:** `drop` calls `finish(match, 3 - i, "forfeit")` as soon as a team has nobody present (545), and `award` pays every present player `MatchSparks("win", match.Wins[i])` = 150 + 10 x rounds won (289-291), i.e. 150 Sparks for a match that lasted seconds. The leavers lose nothing (they are not paid and there is no penalty). An Element (1600-2000) is ~11-13 such cycles of ~30 s (15 s vote + respawn + ForfeitHold). A dev can hand any team a win on demand.
- **Suggested fix:** Pay forfeits pro rata (e.g. only per-round Sparks actually earned, or nothing before N rounds/minutes of live play), require a minimum match duration/damage dealt before any reward, and consider a leaver penalty/cooldown. Exclude dev-initiated leaves from rewarding the other side.
- **Notes:** No duplication; this is an earn-rate exploit. Ties to the anti-farming design in the manual (Section 8 "always earnable at a reasonable rate").

#### P2-06: Every cosmetic is free: `OwnsSkin` returns true for any existing skin, there is no cosmetic ownership in the save, and in-build/premium skins are equippable live
> **Consolidator:** canonical entry for: OwnsSkin always true: every cosmetic free. Also reported as **P1-15**, **P6B-08**, **P5A-20**.
- **Severity:** Medium (becomes High the moment any skin/wrap is sold for Robux)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:420-423`, `:432`, `:275-280`, `:457-458`; `game/ServerScriptService/SpellshotService.server.lua:717-747`; `game/ServerScriptService/PlayerData.lua:26-31`; `game/ReplicatedStorage/Spellshot/EconomyConfig.lua:12`
- **Trigger:** Any player opens Loadout > SKINS / WRAPS and equips e.g. Frost Dragon (Mythic, "IN BUILD -- stage 1"), Frost Lotus (Epic), Black Ice (Rare), Blue-Ringed... (Toxin wraps), Devil.
- **Why it's a bug:** `function SkinCatalog.OwnsSkin(player, skinId) return SkinCatalog.Skins[skinId] ~= nil end` — the single gate the server's LoadoutRequest consults (SpellshotService.server.lua:722, 733, 743) and that `Chosen`/`ElementSkin`/`ElementWrap` re-check. EconomyConfig says "Skins and wraps stay Robux-only", but PlayerData's schema has no cosmetic ownership at all and ProcessReceipt deliberately refuses any non-pack product, so there is nowhere for a bought cosmetic to be recorded. FrostDragon is listed in `ElementSkins.Cryo` while its own comment says its other pieces still draw Default ("IN BUILD"), so an unfinished Mythic ships equippable. Cosmetic choices (Skin_/ElementSkin_/ElementWrap_ attributes) are also not persisted anywhere, so every join resets them.
- **Suggested fix:** Add an `Cosmetics = { [id] = true }` map to the save (with a new key/migration), make `OwnsSkin` read PlayerData on the server (and a published attribute on the client for UI), add a ProcessReceipt branch for cosmetic products, and keep in-build skins out of `ElementSkins` (or behind a Studio/dev gate) until signed off. Persist the equipped cosmetic choices.
- **Notes:** Documented as "always true for now", but it is the economy's only cosmetic gate and the brief's "Studio-only/test item" concern applies to FrostDragon. Cross-ref the cosmetics pass for FrostDragon's partial kit.

#### P2-07: Dev economy tools are live on public servers for two accounts: unlimited Sparks and all Elements written into the real save
> **Consolidator:** duplicate of **P1-02** (Dev mode live: free Ultimate in ranked + unlimited Sparks). Kept here for its slice-specific detail; counted once, under P1-02.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:152-162`, `:209-219`; `game/ServerScriptService/SpellshotService.server.lua:376-407`
- **Trigger:** The place owner or UserId 2800693640 on any live server presses +1000 SPARKS / UNLOCK ALL in the dev panel (DevRequest "EcoAddSparks" / "EcoUnlockAll"), unthrottled.
- **Why it's a bug:** `AllowInLiveGame = true` with an extra `UserIds` entry makes `Config.IsDev` true on live servers; `EcoAddSparks` calls `PlayerData.AddSparks(p, 1000, "dev")` per press with no rate limit and the result is persisted by the next autosave; `EcoUnlockAll` unlocks every Element (including any NotForSale/event Element added later) and saves at once. The same gate also gives live FreeUltimate (default `FreeUltimate = true` for devs) and SetElement-without-ownership in ranked team matches (competitive integrity; cross-ref the combat/dev pass). The config comment itself says "turn it off before the game is public".
- **Suggested fix:** Turn `AllowInLiveGame` off for public builds (or gate it on a private-server/Team-Test check), and restrict the Eco* actions to Studio or memory-only profiles so dev testing never touches real saves.
- **Notes:** Intentional per comments; reported because it is an economy-integrity hole on the shipping config.

#### P2-08: SettingsStore: a failed GetAsync falls back to defaults that are later SAVED over the player's real settings
> **Consolidator:** canonical entry for: SettingsStore failed load -> defaults saved over real. Also reported as **P5F-12**.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SettingsStore.server.lua:68-81`, `:101-107`, `:119-125`, `:83-99`
- **Trigger:** `GetAsync` throws for a player on join (throttle, outage). The player then changes any one setting (or the client pushes for any reason).
- **Why it's a bug:** `load` returns nil on error (76-79); `state[player] = { values = Settings.Sanitise(nil), dirty = false }` (103) — i.e. defaults — and the client is sent the defaults and applies them (SettingsRuntime.client.lua:89-92). The client pushes WHOLE snapshots, so its next push is "defaults + one change", which the server marks dirty (123-124) and `SetAsync`s over the real record at the next autosave/leave (92). Every keybind, sensitivity, accessibility choice (Reduce Flashing, Colourblind-Safe) is wiped by one transient error — including for a photosensitive player whose Reduce Flashing silently turns off.
- **Suggested fix:** Distinguish "no record" (nil from a successful GetAsync) from "load failed": on failure, retry with backoff, and if it still fails mark the state `noSave = true` so pushes are applied in memory but never written. Prefer UpdateAsync that only writes when the load succeeded.
- **Notes:** No session lock either: a fast server hop can read the pre-leave record on server B (GetAsync before A's SetAsync lands) and B's next push then overwrites A's last change (Low; same fix direction).

#### P2-09: SettingsStore: pushes and "request" sent before the load finishes are dropped, and the load then reverts the player's early changes
> **Consolidator:** canonical entry for: Settings changed before load are lost. Also reported as **P5F-17**.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SettingsStore.server.lua:101-107`, `:114-116`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:89-97`; `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:384-393, 412-422`
- **Trigger:** A player changes a setting in the first second(s) after joining, while the server's GetAsync is still in flight.
- **Why it's a bug:** `state[player]` does not exist until `load` returns, so `if not s then return end` (116) silently drops the push (TakePush has already cleared `pushDirty`). When the saved table then arrives, `Settings.Load` overwrites the change silently and `MarkSaved` clears any pending push, so the change is lost without feedback. Also: a player who leaves before the load returns has `state[player]` created after PlayerRemoving ran (103 after 109-112), and that entry is never removed (leak; harmless otherwise). Players already in the game when the script starts are never handled (no loop over `Players:GetPlayers()`), so their settings never load or save.
- **Suggested fix:** Create `state[player]` before the GetAsync with a `loading` flag, queue the latest push and merge it after the load (or have the client re-push after `OnLoaded`); clear late entries for departed players; iterate existing players at startup.
- **Notes:** —

#### P2-10: SettingsStore leave/close writes are single-shot and can double-write the same key
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SettingsStore.server.lua:83-99`, `:109-112`, `:137-144`
- **Trigger:** (a) The leave SetAsync fails (throttle). (b) Server shutdown: Roblox kicks players (PlayerRemoving -> save) while BindToClose also loops `save` for the same players.
- **Why it's a bug:** (a) `save` leaves `dirty = true` "for the next autosave", but PlayerRemoving then sets `state[player] = nil` (111), so nothing ever retries: the last session's changes are lost. (b) `dirty` is only cleared after SetAsync returns, so both paths see `dirty = true` and write the same key twice within the 6 s per-key limit; the second is queued, and BindToClose then waits only 1 s (`task.wait(1)`, 142), so queued writes may be cut off. BindToClose also writes serially per player.
- **Suggested fix:** Retry the leave save a few times (as PlayerData's `release` does), mark `saving` to dedupe concurrent saves, spawn BindToClose saves in parallel and wait for them to complete (bounded) instead of a fixed 1 s.
- **Notes:** —

#### P2-11: Temporary stage scripts in ServerScriptService can push PARTIAL settings tables to a real player, resetting all their other settings
> **Consolidator:** canonical entry for: Partial SettingsSync payloads reset all settings. Also reported as **P5C-16**, **P5F-21**.
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/_BROStage.server.lua:34`, `:75`, `:77`, `:92`, `:94` (the partial `sync:FireClient` calls in `run()`), `:97-99` (the BroGo trigger), `:3`; `game/ServerScriptService/_AuroraStage.server.lua:3-5, 71`; `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:384-393`
- **Trigger:** _AuroraStage and _BROStage are live Scripts in ServerScriptService (manifest.json records them as `"c": "Script"`; Enabled is not recorded). _AuroraStage sets `StageReady` as soon as the first player has a character, which releases _BROStage's wait; _BROStage's `run()` fires on the workspace attribute `BroGo` (server-set only).
- **Why it's a bug:** `SettingsSync:FireClient(pl, { ColorblindSafe = true })` reaches SettingsRuntime's handler, which calls `Settings.Load(tbl)` — `Sanitise` fills every id missing from the partial table with its DEFAULT — then `MarkSaved`. Player 1's whole settings set (binds, sensitivity, Reduce Flashing...) is reset to defaults in memory; their next change pushes the defaults snapshot and SettingsStore saves it over their real record. The second call sets ReduceFlashing = false explicitly, which for a player who relies on it is an accessibility hazard. Separately, _AuroraStage clones the first live player's character into `workspace.WrapStage` with a `WrapStudio = "Aurora"` attribute and puts stage globals in `_G` on any server it runs on.
- **Suggested fix:** Remove both TEMPORARY stage scripts from the shipping place (or gate them on `RunService:IsStudio()`), and make the client treat any server settings message as a merge of only the keys present, or have SettingsStore be the only sender.
- **Notes:** Whether the scripts are Enabled on live, and whether anything sets `BroGo` outside Studio, is not in the snapshot. Cross-ref the Studio-only/WrapStudio pass for the `WrapStudio` dummies.

#### P2-12: Colourblind-Safe palette has no Aqua entry and moves more Elements than its own comment says
> **Consolidator:** duplicate of **P5F-10** (Colourblind palette moves 5 Elements; Zephyr~Radiant). Kept here for its slice-specific detail; counted once, under P5F-10.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:144-161`, `:311-315`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:309-316`; `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:347`
- **Trigger:** Colourblind-Safe on, any Aqua player on screen; or Zephyr / Umbra / Radiant players.
- **Why it's a bug:** `Settings.ElementColors` lists eight Elements and no Aqua, so `Settings.ElementColor("Aqua")` returns the fallback gold `#F5B800`; `tonesFor` sees `base ~= def.Base` and repaints every Aqua body in derived gold tones — reading as Voltaic/Radiant, the opposite of "colourblind-safe". The comment says only Pyro/Terra and Toxin/Cryo are moved and "the rest keep their identity colour", but Zephyr's pair[2] is white, Umbra's is near-black (20,20,20) and Radiant's is (240,240,240), so those three are repainted too (Cryo is not moved at all, contrary to "Toxin/Cryo").
- **Suggested fix:** Add `Aqua = { def.Base, <safe colour> }` and reconcile the table with the comment (or the comment with the owner's intent).
- **Notes:** Settings-honouring gap; cross-ref the settings/VFX pass.

#### P2-13: Shop can sell a Sparks pack to a player whose save is unavailable or still loading
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterGui/SpellshotShop/ShopController.client.lua:860-867`; `game/ServerScriptService/PlayerData.lua:368-372`
- **Trigger:** Once ProductIds are set: a player with `DataError = true` (load failed) or a lost lock opens SPARKS PACKS and buys one.
- **Why it's a bug:** `buyPack` prompts whenever `ProductId > 0`, without checking `DataLoaded`/`DataError`. Roblox charges; ProcessReceipt returns NotProcessedYet for the whole session (the profile is `failed`), so the player sees their Robux go and no Sparks until a later join on a healthy server (Roblox retries on later joins; refund-on-timeout is engine policy outside the snapshot). LoadoutMenu already handles this state with "SAVE UNAVAILABLE"; the shop does not.
- **Suggested fix:** Disable/annotate the pack rows while `DataLoaded ~= true` or `DataError == true`.
- **Notes:** —

#### P2-14: Pending/failed-profile Sparks are shown as earned but never saved; AwardMatch reports a payout it did not make
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:164-181`, `:440-443`, `:446-462`
- **Trigger:** A player whose load failed (or whose lock was lost, `prof.lost`) finishes team matches; or AwardMatch is called for a player whose profile is gone.
- **Why it's a bug:** For a failed profile, AddSparks adds to `pending.Sparks` and `publish` shows the new balance (170), but nothing will ever write it; for a lost profile `data.Sparks` grows and every `saveSoon` is refused. The player sees "+N Sparks" (the shop even toasts it, ShopController.client.lua:944) that silently disappear on leave. AwardMatch returns `amount` even when `AddSparks` returned nil (no profile) and skips Stats for unloaded profiles. Documented ("nothing saved"), but the UI gives no hint beyond DataError.
- **Suggested fix:** Return the actually-credited amount; surface a persistent "progress not saving on this server" banner for failed/lost profiles; optionally retry the load in the background so pending earnings can be merged.
- **Notes:** —

#### P2-15: Team matches where every round is a draw never end (no reward, players cannot leave)
> **Consolidator:** duplicate of **P3-13** (All-draw matches never end). Kept here for its slice-specific detail; counted once, under P3-13.
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:364-387`, `:465-491`; `game/ServerScriptService/HubServer.server.lua:1096-1102`
- **Trigger:** Both teams finish rounds at equal health share (e.g. nobody engages: all at 100% when the 90 s RoundTime expires), round after round.
- **Why it's a bug:** `timeUp` calls equal shares a draw, draws score for nobody (475-477), and `finish` is only reached at FirstTo wins or a forfeit, so the loop runs indefinitely; non-devs get "You can't leave a duel in progress" and can only disconnect (which forfeits for their side and pays the others — feeding P2-05).
- **Suggested fix:** Cap the number of rounds (or consecutive draws) and settle the match on round wins/total health at the cap, paying "draw" where tied (today the "draw" MatchReward is unreachable: `finish` is only ever called with a winning team).
- **Notes:** Mostly a match-flow issue; cross-ref the modes pass. Economy angle: the 75-Sparks "draw" reward in EconomyConfig can never be paid.

#### P2-16: Schema/migration hazards: unknown fields are discarded on every load+save, and there is no version check
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:26-31`, `:90-125`, `:217-221`
- **Trigger:** A future build adds a field to the v1 record (e.g. cosmetics, P2-06) without changing the key, and old servers are still running during the rolling update; or a v2 key migration is shipped while v1 servers keep writing.
- **Why it's a bug:** `normalise` rebuilds the record from a fixed field list and `loadData` immediately writes the normalised copy back (220), so an old server silently deletes any field it does not know, the moment a player joins it. `Version` is written but never compared, so an old server cannot refuse a newer record. With the documented "new shape gets a new key and migrates from this" plan, progress made on still-running v1 servers after a player has migrated is never carried to v2.
- **Suggested fix:** Preserve unknown top-level fields in `normalise` (copy them through), refuse to write (mark the profile `failed`) when `old.Version > SCHEMA`, and for key migrations keep reading v1 for changes newer than the migration stamp.
- **Notes:** Latent until the first schema change. Also no GDPR/right-to-erasure handling (no RemoveAsync anywhere) for either store — compliance note, outside code correctness.

#### P2-17: Autosave writes every player every 60 s even when nothing changed, and piles up waiting writers during an outage
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/PlayerData.lua:532-539`, `:251`
- **Trigger:** A DataStore slowdown longer than 60 s.
- **Why it's a bug:** The autosave spawns `save` for every loaded player each tick regardless of `dirty` (it doubles as the lock refresh, which is intended), but when a write hangs, each new tick adds another thread spinning on `while prof.saving do task.wait(0.1) end`; when the store recovers, every queued thread performs its own full UpdateAsync back to back (the comment "this one carries everything newer" is true but the extra writes still happen), bursting the per-key 6 s limit and the server budget exactly when it is recovering.
- **Suggested fix:** If a save is already running or queued for the profile, set a `saveQueued` flag and return instead of waiting; the running save re-checks `dirty` when it finishes.
- **Notes:** —

#### P2-18: Doc drift — economy (manual vs code vs shop data)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `docs/SPELLSHOT_Design_Manual.md:530`, `:626`, `:705`, `:710-711`; `game/ReplicatedStorage/Spellshot/EconomyConfig.lua:12, 16-17, 30`; `game/StarterGui/SpellshotShop/Catalog.lua:15-47, 61`; `game/StarterGui/SpellshotShop/CardKit.lua:1173-1177`; `game/ServerScriptService/DuelMatch.lua:278`; `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua:8-10`; `game/ServerScriptService/HubServer.server.lua:44`
- **Trigger:** n/a (documentation/data disagreement).
- **Why it's a bug:** (1) Manual: starters are Pyro, Terra, Radiant + Bulwark Wall; code: `StarterElements = { "Pyro", "Zephyr", "Cryo", "Terra", "Radiant" }`, no starter Technique and no Technique unlocks at all. (2) Manual: Element/Technique unlocks also purchasable directly with Robux; code: only Sparks packs. (3) EconomyConfig: "Skins and wraps stay Robux-only"; shop Catalog prices s04/s08/s12/t01/t03 in Sparks. (4) Manual v0.23: rarities Uncommon->Mythic, "Common is gone"; Catalog uses Common and Seasonal. (5) Manual: Elemental Cache drops Wraps only, never Element Skins; Catalog cache "1 random Skin or Tint". (6) EconomyConfig's yardstick "a first-to-5 duel WIN pays 200" but pad duels pay nothing (DuelMatch.lua:278); only team matches pay. (7) Catalog item names collide with real SkinCatalog ids for different things (Catalog "Nightshade" = an Umbra Mythic Skin at 800 Robux; SkinCatalog Nightshade = a Toxin Uncommon wrap) and no Catalog id maps to any SkinCatalog id. (8) The shop shows a fake Robux balance (`BAL.robux = 1250`) to players as if it were theirs. (9) LoadoutMenu's header still describes cross-Element Technique borrowing ("a Cryo player can run Pyro's Scorching Lash") while `TechniquesOwnElementOnly = true`. (10) HubServer's header says "there is no economy yet" (Cache Vault).
- **Suggested fix:** Reconcile the manual with the shipped economy decisions (or vice versa); give Catalog entries real SkinCatalog ids; hide the placeholder Robux balance.
- **Notes:** —

#### Could not complete
- CardKit.lua, LoadoutMenu.client.lua and SettingsMenu.client.lua were read in the parts that touch economy/persistence (header, ownership/price UI, every remote send) plus full grep sweeps, not every UI-layout line; the unread stretches are layout/drawing code with no remote, DataStore, MarketplaceService or attribute-write calls (verified by grep). Everything else in scope was read fully.
- Not verifiable from the snapshot: live DataStore timing (P2-01/02/03 orderings), whether GetDataStore can throw on a live server (P2-04), the Enabled state of _AuroraStage/_BROStage (P2-11), and Roblox's refund policy for never-granted receipts (P2-13).


---

## Pass 3 — Combat-state correctness

_Entries: 24 (2 High / 6 Medium / 16 Low). Distinct after merging duplicates: 19 (0 High / 5 Medium / 14 Low)._

### Pass 3 — Combat-state correctness (statuses, reactions, team scoping, rounds, hitboxes, ult charge)

#### Files read (complete list)
- game/ServerScriptService/CombatCore.lua — fully
- game/ServerScriptService/DuelMatch.lua — fully
- game/ServerScriptService/StatusEffects.lua — fully
- game/ServerScriptService/ElementalReactions.server.lua — fully
- game/ServerScriptService/HitboxScale.server.lua — fully
- game/ServerScriptService/SpellshotService.server.lua — fully
- game/ServerScriptService/AllyDummies.server.lua — fully
- game/ServerScriptService/TrainingGround.server.lua — fully
- game/ServerScriptService/CombatFeedback.server.lua — fully
- game/ServerScriptService/FrostDragonKillHook.server.lua — fully
- game/ServerScriptService/AbilityHandler.server.lua (Cryo) — fully
- game/ServerScriptService/PyroHandler.server.lua — fully
- game/ServerScriptService/VoltaicHandler.server.lua — fully
- game/ServerScriptService/TerraHandler.server.lua — fully
- game/ServerScriptService/ZephyrHandler.server.lua — fully
- game/ServerScriptService/ZephyrGustPadServer.server.lua — fully
- game/ServerScriptService/ZephyrSkyriderServer.server.lua — fully
- game/ServerScriptService/ZephyrUpdraftServer.server.lua — fully
- game/ServerScriptService/AquaHandler.server.lua — fully
- game/ServerScriptService/UmbraHandler.server.lua — fully
- game/ServerScriptService/RadiantHandler.server.lua — fully
- game/ServerScriptService/ToxinHandler.server.lua — fully
- game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua — fully
- game/StarterPlayer/StarterPlayerScripts/HitboxGuard.client.lua — fully
- game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua — fully
- game/ReplicatedStorage/Spellshot/SpellshotConfig.lua — fully
- Cross-references (partially): game/ServerScriptService/HubServer.server.lua lines 122-300 (arenaSpot, moveTo, respawnTo, enterArena) and 300-520 (vote, popTeams, respawn takeover); game/ReplicatedStorage/Spellshot/MapRegistry.lua lines 100-150; game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua lines 295-330 (Stunned); game/ReplicatedStorage/IceMagic/FrostDragonKillFX.lua lines 545-562; game/ReplicatedStorage/IceMagic/CryoTuning.lua (grep of DeepFreeze / MirrorCage numbers); game/ReplicatedStorage/IceMagic/VoltaicTuning.lua line 43; game/ReplicatedStorage/IceMagic/PyroFX.lua lines 76-82; game/ReplicatedStorage/IceMagic/TerraFX.lua line 97; game/ReplicatedStorage/Spellshot/DeflectPractice.lua lines 48-50; game/ReplicatedStorage/IceMagic/VFXLibrary.lua (grep ChargeOnCatch lines 245-460); game/manifest.json (greps: Teams, TrainingDummy, Thrower, SignalBehavior — not recorded).

#### Sub-areas checked with nothing found
- checked, clean: mana can never go negative — generic path checks `ManaFloat < cost` before `-=` (SpellshotService.server.lua:1063-1078), held path same (1023-1038), charges allow 2 grace then clamp at 0 (1004), SpendMana clamps (833).
- checked, clean: cooldown is never stamped before the cost/precheck passes on the generic and held paths (SpellshotService.server.lua:1045-1085, 1017-1041); two cooldown/charge/held presses in one frame cannot both pass (CD_/Holding_/charge Count are written synchronously in the remote handler).
- checked, clean: non-ChargeOnCatch Ultimates zero UltCharge synchronously in the CastRequest handler (SpellshotService.server.lua:943), so a same-frame double press is refused. Mirror Cage and Earthen Tomb guard re-entry (`cages[player]`, AbilityHandler.server.lua:1288; `tombs[player]`, TerraHandler.server.lua:898). (Patient Zero does not: P3-08.)
- checked, clean: overlapping slows/roots in AbilityHandler are per-entry records with the cap = tightest live entry, each lapsing on its own clock (AbilityHandler.server.lua:215-294); restoring speed always recomputes from attributes in SpellshotService (565-571), so no slow clobbers another's WalkSpeed; jump lock is a per-reason set (186-213).
- checked, clean: SpeedCapUlt shared slot — every writer (Umbra Eclipse, Radiant Halo/Benediction, Terra Tomb/Aftershock, Zephyr Cyclone, Cryo Beam) writes only its OWN caster's body and clears only a value it still recognises; no cross-player victim cap (I first suspected the Tomb victim; TerraHandler.server.lua:810-822 is the caster).
- checked, clean: heals — every ability heal goes through Core.Heal (clamped to MaxHealth, refused on dead/walls/decoys/training dummies, CombatCore.lua:330-341); Blessing/Benediction/Halo pick targets through Core.IsAllyOf (alive, same Zone + party, not Hub, friendly), so an ally cannot heal an enemy and nobody in the Hub/another match is healed; Overflow Light only heals the Blessed holder after a true lapse (StatusEffects.lua:290-299, RadiantHandler.server.lua:506-520).
- checked, clean: damage to a player in the Hub / another match / a teammate is refused centrally (CombatCore.IsFriendly -> Config.MayHurt, incl. MatchTeam) and every non-damage CC/status/knock I traced is either gated on a successful DealDamage or checks IsFriendly / Hub / SameParty itself (slows, Chill, roots, Slip, Cyclone pull, Undertow, Aftershock/Skyrider/Bulwark/Overload knocks, Tomb/Cage/Mark locks, Charged discharge, Poison, Gust Pad).
- checked, clean: round reset cancels every delayed effect I found via Core.Epoch / OnClear (Flash Freeze, Ring of Fire, Detonate, Cinder haze, Volt Orb strike, Cascade, Twin Tide, Maw, Undertow, Acid Rain, clouds, bubbles, Skyrider flap, Gust Pad, Aftershock, Tomb, Cage, Deep Freeze traps, Blizzard, Benediction, Halo, Eclipse, poison/burn/lash ticks) — so nothing from round N lands on round N+1's bodies; CastLocked + CanAct close the reset window for M1 release remotes.
- checked, clean: DuelMatch timer vs death races — timeUp refuses while `Settling` or not Live (DuelMatch.lua:365), settle refuses after Over (329); a team-down settle on the next Heartbeat sees same-frame deaths; drop() during Settled honours a just-won deciding round (536-544).
- checked, clean: ally dummies are friendly to everyone for damage/CC (CombatCore.lua:131) yet allies for support only inside their own party (175), so a duel on the range never feeds a duelist's heals into them.
- checked, clean: Ultimate charge from overkill — both the dealt side (`before - max(Health,0)`, CombatCore.lua:310) and the taken side (HealthChanged delta, SpellshotService.server.lua:649-657) are clamped at 0 health; heals never charge.
- checked, clean: Roblox Teams are not used (no Team instances in manifest; nothing sets Player.Team), so the `victim.Team == caster.Team` clause (CombatCore.lua:150) is dead today — noted only as latent in P3-09.
- checked, clean: HitboxScale twins cannot be resized or re-shown by a client (server-made, Transparency re-guarded on both sides), no server code parents extra BaseParts directly into characters (so no cosmetic part gets a twin), and accessories (not direct children) get none.
- checked, clean: DeathFX / CombatFeedback are presentation-only and hook Died once per character.

---

#### P3-01: A reaction (or any hit listener that deals damage) that kills fires every OnKill listener twice for one death
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/CombatCore.lua:308-321`, `game/ServerScriptService/ElementalReactions.server.lua:157-161`, `:201-206`, `:336-367`, `game/ServerScriptService/PyroHandler.server.lua:477-492`, `game/ServerScriptService/VoltaicHandler.server.lua:315-334`, `game/ServerScriptService/FrostDragonKillHook.server.lua:14-28`
- **Trigger:** any hit that does not kill but sets off a damaging reaction (Melt, Overload, Shatter bonus; Combustion on the hit body) whose bonus does kill. E.g. Pyro Fireball on a Chilled/Rooted enemy at <= 14+direct HP, any mode.
- **Why it's a bug:** DealDamage calls `tell(hitListeners, ...)` (line 319) and only THEN `if humanoid.Health <= 0 then tell(killListeners, ...)` (line 320). ElementalReactions' hit listener calls `Core.DealDamage(... { Reaction = name })` (bonus(), line 159) inside that loop; the inner call takes the body to 0 and fires the kill listeners itself, then the outer call reaches line 320, sees Health <= 0 and fires them again with the outer hit's info. Today the kill consumers are FrostDragonKillHook (re-stamps KillFX; two writes in one frame likely replicate as one, so cosmetic), Pyro's Ember Refund `Trigger == "Kill"` and Voltaic's Chain Reaction `Trigger == "Kill"` — both currently set to other triggers (PyroFX Tuning `Trigger = "LowHealth"`, VoltaicTuning:43 `"MaxStacks"`), but both configs explicitly keep "Kill" as a supported switch: flipped back, one kill refunds 2 x 30% of the cooldown. The same nesting also corrupts later hit listeners of the outer hit: Ember Refund's LowHealth rule computes `before = after + info.Removed` (PyroHandler:487-489) where `after` already includes the reaction bonus, so the 30% crossing test is evaluated on wrong numbers.
- **Suggested fix:** in DealDamage, record "this call took it to 0" (`local killed = before > 0 and humanoid.Health <= 0`) immediately after TakeDamage and fire kill listeners only on that local, or mark the humanoid as already-credited in `deathTimes` and skip the outer fire when an inner call already reported it. Consider running reaction damage deferred (task.defer) after the outer listeners finish.
- **Notes:** latent severity rises to High for the economy if any future kill-based reward listens on OnKill.

#### P3-02: The Training Ground map is in the match vote, and its dummies and snowball thrower stay live inside ranked duels/team matches
> **Consolidator:** duplicate of **P1-04** (Training Ground in the ranked map vote). Kept here for its slice-specific detail; counted once, under P1-04.
- **Severity:** High
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/Spellshot/MapRegistry.lua:122-125` (no Model, no `Vote = false`), `game/ServerScriptService/HubServer.server.lua:315-323` (voteChoices: `m.Vote ~= false and (not m.Model or ...)`), `game/ServerScriptService/TrainingGround.server.lua:87-89`, `:157-163`, `:231-240`, `:316-342`, `game/ServerScriptService/CombatCore.lua:314-316`, `game/ServerScriptService/ToxinHandler.server.lua:242-268`, `game/ServerScriptService/StatusEffects.lua:270-276` + `game/ServerScriptService/VoltaicHandler.server.lua:339-355`, `game/ServerScriptService/UmbraHandler.server.lua:722-741`, `game/ServerScriptService/RadiantHandler.server.lua:638-646`
- **Trigger:** a Hub pad Duel or a Quick Play team match whose vote lands on TRAINING GROUND (always a choice: it has no Model to be missing).
- **Why it's a bug:** (1) the Thrower picks "the nearest player in the range" by `Zone == "Arena" and Map == "TrainingGround"` only (TrainingGround:87-89), so it pelts duellists with `humanoid:TakeDamage` (line 162) — bypassing IsFriendly, shields and DeathTime stamps — lowering the round-clock health share (DuelMatch.timeUp) and feeding the victim Ultimate via HealthChanged. (2) Training dummies take everything and refill (`TrainingDummy`, refill at 0 and after 3 s), and every dealt-damage benefit counts them: Ultimate charge (`removed * UltChargePerDamage`, CombatCore:314-316 — 150 HP of dummy ≈ 0.58 of a meter, refilling forever), Toxin Symbiosis lifesteal from poisoning a dummy (ToxinHandler:259-262; Halo explicitly refuses dummies for exactly this reason, RadiantHandler:595-603, Symbiosis does not), Voltaic Chain Reaction's -2 s per Charged fill (OnChargedFull fires for a dummy), Umbra's dive reward ("a dummy counts", UmbraHandler:722-723), Pyro Ember Refund's LowHealth crossing, Position Trade on a dummy as a free teleport (RadiantHandler:645). A duellist can hide and farm a full Ultimate in seconds.
- **Suggested fix:** either mark TrainingGround `Vote = false` (it is a sandbox), or when a DuelMatch is on that map disable the Thrower (`inRange` should also require `DuelMatch == nil`) and make CombatCore withhold ult charge / lifesteal / passive procs for `TrainingDummy` victims when the caster has a `DuelMatch` attribute.
- **Notes:** confidence Medium only because whether the live vote really offers Training Ground (and whether the range sits at the duel marks) depends on the place; by the code it does. Cross-ref: economy pass (team matches award Sparks via PlayerData.AwardMatch).

#### P3-03: A Toxin stepping into its own cloud converts an enemy's Poisoned into "own poison" (reduced damage, cleansable, credit stolen)
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/StatusEffects.lua:236-255`, `:313-319`, `game/ServerScriptService/ToxinHandler.server.lua:305-315`, `:227-233`, `:592-600`
- **Trigger:** Toxin vs Toxin (Duel mirror, or any team match with Toxins on both sides): enemy B poisons Toxin A; A walks into A's own Corrosive Cloud (or eats its own Patient Zero burst).
- **Why it's a bug:** the cloud tick calls `Status.Apply(owner, hum, "Poisoned", { Self = mine })` (ToxinHandler:313). Apply finds B's existing record and unconditionally overwrites `rec.Caster = caster` / `rec.CasterEpoch` (StatusEffects:254-255). From then on every tick is `Core.DealDamage(A, A's humanoid, ...)` (line 319): the -8 modifier sees `caster.Character == model` and applies `SelfDamageMult` (0 behind the Vent), B loses the damage credit, Ultimate charge and Symbiosis lifesteal, and Antitoxin Vent — which is meant to cleanse only the Toxin's OWN poison ("an enemy Toxin's poison is never touched", ToxinHandler:32-35) — now passes its `Status.CasterOf(...) == player` check (596-599) and wipes B's poison. The reverse also happens (B re-applying turns A's self-poison into full-strength enemy poison).
- **Suggested fix:** keep one Poisoned record per (victim, caster) or at least never let a Self application overwrite a foreign caster (stack it under the existing caster, or run self-poison as a separate kind); make CasterOf report the dominant/foreign caster.

#### P3-04: Flash Freeze's shatter hits everyone it EVER rooted, even after the root was broken or the victim was moved away
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:346-358`, `:375-382`, `:1021-1037`, `game/ServerScriptService/ElementalReactions.server.lua:139-142`, `:176-183`, `:249-253`, `game/ServerScriptService/RadiantHandler.server.lua:672-716`
- **Trigger:** a Flash Freeze roots an enemy; before the zone ends, a Voltaic hit (Shatter) or Pyro hit (Melt) consumes the root, or an ally Radiant Position-Trades the frozen victim out. 2v2/Squad Clash mostly; a cross-element loadout latent case in Duel.
- **Why it's a bug:** the manual/kit text is "shattered if still frozen when it ends" (SpellshotConfig:287 Primary Desc; AbilityHandler:299-303). The zone keeps a closure-local `rooted[victim] = true` (376) and at `zoneEnd` deals `FlashFreezeShatterDamage` (34) to every entry with `victim.Health > 0` (351-357) — no check that the victim is still rooted (`isRooted`), still frozen (IceFrozenState) or still inside the zone. Hooks.BreakRoot (1021-1037) ends the slow entries and destroys IceFrozenState but cannot reach the closure's table, so Shatter/Melt pay their bonus AND the 34 still lands later; a victim teleported anywhere on the map is shattered too.
- **Suggested fix:** at zone end, shatter only victims for whom `isRooted(victim)` (or the frozen state from this zone) is still true and who are still inside the radius; or have BreakRoot publish an event the zone listens to and drop the victim from `rooted`.

#### P3-05: Reactions' BreakRoot ends every Cryo root (Deep Freeze prison, Mirror Cage, Frozen) silently — clients keep drawing the prison/cage, and an ally's Pyro M1 frees your Cryo's catch
> **Consolidator:** canonical entry for: BreakRoot ends Cryo prison/cage roots silently; clients keep drawing them. Also reported as **GC-08**.
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:1021-1037`, `:1152-1166` (prison), `:1194-1199` (breakPrison only on clear), `:1303-1308` (cage root), `game/ServerScriptService/ElementalReactions.server.lua:113-115`, `:139-142`
- **Trigger:** 2v2 / Squad Clash with a Cryo and a Pyro (or Voltaic) on the same team: the Cryo lands Deep Freeze or Mirror Cage; the teammate's Fireball/Chain Bolt (any non-DoT hit) on the trapped enemy.
- **Why it's a bug:** RULES give Pyro `{ "Rooted", "Melt" }` first and Voltaic `{ "Rooted", "Shatter" }` first. CONSUME.Rooted -> `Hooks.BreakRoot` -> `endSlows(humanoid, function(e) return e.Speed <= 0 end)` ends EVERY root entry regardless of source (Deep Freeze's 1.5 s prison, Mirror Cage's 2.3 s root, Flash Freeze, Frozen). Nothing broadcasts DeepFreezeEnd / MirrorCageFree, and `prisons[model]` / `caged[model]` are left set, so every client keeps drawing the crystal prison / the dome round a body that can now walk away (Mirror Cage's bolts keep landing on it wherever it walks, stepCages 1341-1344). A teammate cannot avoid it: every Pyro hit on a rooted body Melts. Design text describes Melt/Shatter as payoffs, so the anti-synergy on the team's own control Ultimate is at best a design question; the missing end broadcast is a plain bug.
- **Suggested fix:** let BreakRoot skip roots tagged by source (prison/cage) or end those mechanics properly (broadcast DeepFreezeEnd / MirrorCageFree, clear `prisons`/`caged`); consider exempting Ultimate roots (Mirror Cage) from Melt/Shatter, or letting a reaction break only roots its own caster's team did not apply.
- **Notes:** Confidence Medium on the visual half — whether the client prison/dome stops when IceFrozenState is destroyed was not traced (client code, other pass).

#### P3-06: RX_Staggered has two uncoordinated writers; one clears the other's stagger early (it gates Skyrider)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:404-410`, `game/ServerScriptService/ElementalReactions.server.lua:236-246`, `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:307-314`
- **Trigger:** a body staggered by Bulwark Charge (1.2 s) and by an Overload reaction (0.6 s) within the same window, either order; also two Bulwark Charges in a row.
- **Why it's a bug:** Bulwark's delay does `model:SetAttribute("RX_Staggered", false)` unconditionally after 1.2 s; Overload's delay clears it when its own `ReactionStaggerAt` stamp still matches — which it does if a Bulwark stagger landed after it. Either way one source ends the other's stagger early. `ZephyrSkyrider.Stunned` reads RX_Staggered to refuse/end a ride, so this is gameplay, not only the stars.
- **Suggested fix:** one writer with a refcount or an "until" time (max of all sources), like RX_Burning's recount in PyroHandler.refreshBurning.

#### P3-07: Effects of a player who LEFT the game keep landing in their name in some kits but not others
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:252-258`, `:570-577` (a leaver is dropped, never released: DuelMatch/MatchTeam stay on the Player), `game/ServerScriptService/PyroHandler.server.lua:222-235` (Immolate/Ring burn loop checks only Epoch), `:696-715` + `:1358-1375` (PlayerRemoving sets `rings[player] = nil` but never `ring.Cancelled`, so a drawn Ring of Fire still erupts), `:615-620` (Cinder haze), `game/ServerScriptService/AbilityHandler.server.lua:337-358` + `:1425-1433` (Flash Freeze zone and its shatter run on), `game/ServerScriptService/AquaHandler.server.lua:591-610`, `:797-854` (Twin Tide crush, Maw bite: epoch only), `game/ServerScriptService/ToxinHandler.server.lua:634-655` (Acid Rain ticks), `game/ServerScriptService/ZephyrSkyriderServer.server.lua:221-224`, `game/ServerScriptService/ElementalReactions.server.lua:270-274` (Storm Surge re-applies Charged in the leaver's name)
- **Trigger:** in a team match, a player casts Ring of Fire / Twin Tide / Maw / Flash Freeze / Acid Rain / Immolate burns and disconnects; their team plays on.
- **Why it's a bug:** leaving does not move Core.Epoch (PyroHandler:113-115 says so and adds `gone[]` for Detonate only). Because DuelMatch never clears the leaver's attributes, `Config.MayHurt(leaver, victim)` still answers true, so `DealDamage(leaver, ...)` lands, can kill and set the round's DownAt, and fires `addUltCharge` for a Player no longer in the game. Detonate, Volt Orb (`player.Parent`), Cascade (`endStormsOf`), clouds/bubbles/poison (`Owner.Parent`, `c.Parent`), Deep Freeze traps, Mirror Cage, Blizzard and Aftershock all stop on leave — the inconsistency is the bug.
- **Suggested fix:** make leaving a clear: call `Core.ClearPlayer(player, "left")` from a PlayerRemoving handler (moves the epoch for every kit at once), or clear DuelMatch/MatchTeam on drop so MayHurt refuses; and set `ring.Cancelled` in PyroHandler's PlayerRemoving.

#### P3-08: Patient Zero can be cast twice for one charge (two marks, two bursts, two clouds)
> **Consolidator:** duplicate of **P1-08** (Patient Zero double-cast under Deferred signals). Kept here for its slice-specific detail; counted once, under P1-08.
- **Severity:** Medium
- **Confidence:** Low
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:935-946`, `game/ServerScriptService/ToxinHandler.server.lua:562-587`
- **Trigger:** two Ultimate CastRequests from the same client processed in the same frame (scripted, or a lag burst), with Workspace.SignalBehavior = Deferred.
- **Why it's a bug:** PZ is ChargeOnCatch, so SpellshotService only checks `UltCharge >= 1` and does not spend it (943); the spend happens in castPatientZero (571) behind the PerformCast bindable. Under deferred signalling both remote handlers run before either bindable handler, both pass the check, and castPatientZero has no re-entry guard (unlike Mirror Cage's `cages[player]` and Earthen Tomb's `tombs[player]`): `marks[player]` is overwritten but the first `task.delay` still detonates (579-585 never checks `marks[player] == m` before detonating).
- **Suggested fix:** in castPatientZero, refuse when `marks[player]` is live, and/or check `UltCharge >= 1` again there before spending; or have SpellshotService reserve a ChargeOnCatch ult (an "UltPending" flag) until the kit spends or releases it.
- **Notes:** Workspace.SignalBehavior is not in manifest.json; under Immediate signalling the bindable runs inline and this cannot happen.

#### P3-09: Ultimate charge counts self-damage and damage to non-players (walls, decoys, dummies); self-friendly logic depends on a dead Team clause
> **Consolidator:** canonical entry for: Ult charge from walls/decoys/self-damage. Also reported as **P1-18**.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/CombatCore.lua:143-150`, `:314-316`, `game/ServerScriptService/SpellshotService.server.lua:648-657`, `game/ServerScriptService/ToxinHandler.server.lua:227-233`
- **Trigger:** a Toxin standing in its own cloud / its own Patient Zero burst; shooting an enemy Bulwark Wall (200 HP, never dies) or Decoy Double.
- **Why it's a bug:** the "taken" side charges on every health drop (HealthChanged), including a Toxin's self-inflicted poison (thinned to SelfDamageMult but still charges), Thrower snowballs and dev DMG. The "dealt" side excludes only the caster's own body, so a wall soaking up to 200 HP gives the shooter ~0.77 of a meter. Separately, IsFriendly decides self-damage via `victim.Team ~= nil and victim.Team == caster.Team` (150): with Roblox Teams unused this is false and Toxin self-damage works; the day anyone assigns Player.Team, every Toxin self-damage rule silently stops (latent).
- **Suggested fix:** decide whether self-damage and structure damage should charge; if not, skip charge when `caster == victimPlayer` on the taken side and for WallOwner/DecoyOwner/TrainingDummy on the dealt side. Special-case `caster == victim` before the Team clause.

#### P3-10: Reactions fire on self-hits and on fully-soaked hits
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/ElementalReactions.server.lua:336-367`, `game/ServerScriptService/ToxinHandler.server.lua:543-553`, `game/ServerScriptService/CombatCore.lua:317-319`
- **Trigger:** a Toxin inside its own Patient Zero burst while Burning; any hit fully absorbed by Cinder Shield / Blessed / Bedrock on a body with a status.
- **Why it's a bug:** the listener filters DoT/Status/Reaction/Chain only; PZ's burst on the caster carries `{ ToxinPoison = true }` with Element "Toxin", so it reacts on the caster's own body (Combustion consumes the burn on itself and bursts on enemies around it). OnHitLanded is also told about hits whose `Removed == 0`, so a shield-soaked hit still consumes Chill/Burn/Charged and fires its bonus.
- **Suggested fix:** skip reactions when `humanoid.Parent == casterChar`; decide whether a hit with `info.Removed <= 0` may react.

#### P3-11: Sidearm shots and the Cross-Slash strike are accepted while interrupted / cast-locked (AliveCharacter instead of CanAct)
> **Consolidator:** duplicate of **P1-13** (Sidearm / Cross-Slash strike ignore interrupts (AliveCharacter)). Kept here for its slice-specific detail; counted once, under P1-13.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AquaHandler.server.lua:643-683`, `game/ServerScriptService/ZephyrHandler.server.lua:444-445`, `game/ServerScriptService/CombatCore.lua:78-93`
- **Trigger:** an Aqua under Undertow/Aftershock interrupt (InterruptedUntil) fires its drawn Sidearm shot (allowed up to DrawTime + 1.5 s after the press, with no Held check for the first shot, 656-663); a Zephyr interrupted mid-glide sends its CrossSlashStrike.
- **Why it's a bug:** CombatCore says every release handler must ask CanAct (Burrowed, CastLocked, InterruptedUntil); these two use AliveCharacter, so an interrupt does not stop the drawn shot or the X.
- **Suggested fix:** use Core.CanAct in both handlers.

#### P3-12: Undertow's interrupt overwrites (shortens) a longer interrupt already running
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AquaHandler.server.lua:493-502`, `game/ServerScriptService/TerraHandler.server.lua:1210-1211`
- **Trigger:** Aftershock interrupt then Undertow on the same body (2v2/Squad).
- **Why it's a bug:** Terra writes `math.max(untilT, existing)`; Aqua writes `untilT` outright, so a shorter Undertow interrupt cuts a longer Aftershock one.
- **Suggested fix:** use the max, as Terra does.

#### P3-13: A match can never end if rounds keep drawing (no round cap, no tiebreak)
> **Consolidator:** canonical entry for: All-draw matches never end. Also reported as **P2-15**.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:379-383`, `:474-489`, `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:224-234`, `:244-255`
- **Trigger:** both sides at equal health share when the 90 s clock runs out (e.g. nobody engages; both full), repeatedly.
- **Why it's a bug:** `math.abs(share[1] - share[2]) < 1e-6` -> "draw", which scores nobody; the loop only ends at FirstTo wins or a forfeit, so two passive players (or teams) stall the match and its Sparks award indefinitely.
- **Suggested fix:** a max round count or sudden-death rule; break exact ties by damage dealt that round.

#### P3-14: Combat stays live through MatchEndHold, and the dead are respawned into the arena during it
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:168-172`, `:300-321`, `game/ServerScriptService/HubServer.server.lua:471-485`
- **Trigger:** any match end.
- **Why it's a bug:** finish() sets State "Over" (so DuelMatch.Of returns nil) but keeps DuelMatch/MatchTeam until after MatchEndHold (release at 316), and sets no CastLocked. HubServer's respawn takeover only holds players while `DuelMatch.Of(p)` answers, so a player who died in the final round is LoadCharacter'd back into the Arena (onCharacter places them at arenaSpots) and both sides can keep fighting and killing for 4 s on the result screen (the "kill after match end" case; harmless to the score, but the winner can be sent home via Respawn "dead").
- **Suggested fix:** set CastLocked on everyone at finish (CanAct and SpellshotService honour it), and keep the respawn hold until release.

#### P3-15: Death ordering: a 1 ms draw window vs hash-ordered AoE processing, and deaths outside DealDamage stamped late
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/ServerScriptService/DuelMatch.lua:83`, `:118-127`, `:344-346`, `game/ServerScriptService/CombatCore.lua:275`, `:311`
- **Trigger:** one AoE (Combustion, Cascade, PZ burst including the caster's own body, Charged discharge) killing the last player of both teams in one call; or a death by TakeDamage/void (no stamp) racing a DealDamage death.
- **Why it's a bug:** deaths are stamped with `os.clock()` as each DealDamage runs, in `pairs()` order over HumanoidsNear; listeners per hit (reactions, broadcasts, callouts) can push consecutive stamps past `DRAW_WINDOW = 0.001`, so "who died first" is decided by hash iteration order rather than a draw. Deaths not through DealDamage are stamped at Died handling time (later than the real frame).
- **Suggested fix:** stamp with a per-frame counter / the Heartbeat timestamp so same-frame deaths compare equal, and treat deaths inside one DealDamage batch as simultaneous.

#### P3-16: HitboxScale silently widens every AoE that uses HumanoidsNear without a root-distance check
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/HitboxScale.server.lua:38-56`, `game/ServerScriptService/CombatCore.lua:183-202`, `game/ServerScriptService/AbilityHandler.server.lua:363-365`, `game/ServerScriptService/PyroHandler.server.lua:353`, `game/ServerScriptService/VoltaicHandler.server.lua:734-739`
- **Trigger:** Flash Freeze contact/dwell, Fireball splash, Volt Orb burst, Charged discharge / Chain Bolt chain radius, cloud/pad/zone broad phases — every mode.
- **Why it's a bug:** twins are CanQuery and `GetPartBoundsInRadius` answers by bounding box, so a 2x torso/limb twin (up to ~2 studs further out) enters radii the owner tuned for 1x bodies; checks that narrow by root distance (Cascade, Combustion, Deep Freeze, Blizzard) are unaffected, so AoEs widened unevenly. Raycasts with `RespectCanCollide = true` (Pyro lineBlocked, ground probes, Cryo Beam) ignore twins (CanCollide false) — consistent 1x there. The owner asked for bigger hitboxes for shots; the AoE effect is a balance side effect.
- **Suggested fix:** exclude the "Hitbox" tag from HumanoidsNear (OverlapParams with the twins' collision group or a filter), or document it as intended.

#### P3-17: Derived damage (reaction bonus, Charged discharge, chain legs) spends the Umbra Mark and gets Updraft's multiplier
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/UmbraHandler.server.lua:459-470`, `game/ServerScriptService/ZephyrUpdraftServer.server.lua:76-92`, `game/ServerScriptService/ElementalReactions.server.lua:157-161`
- **Trigger:** the marker's Reaction bonus or a Charged discharge credited to them lands before their Shadow Dart; an airborne Zephyr's reaction-bonus or StormSurge-credited hit (latent: cross-element loadouts).
- **Why it's a bug:** both modifiers exclude only `info.DoT`; reaction bonuses/discharges are non-DoT hits by the same caster, so the Mark is consumed for a body bonus by a hit the player did not aim, and Updraft scales damage that is not the Zephyr's own hit.
- **Suggested fix:** also skip `info.Reaction`, `info.Chain`, `info.Status`.

#### P3-18: Gust Pad and Position Trade use their own party rule instead of IsFriendly — CC on players you may not hurt
> **Consolidator:** duplicate of **P1-14** (Gust Pad / Position Trade act on solo strangers). Kept here for its slice-specific detail; counted once, under P1-14.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrGustPadServer.server.lua:204-223`, `game/ServerScriptService/RadiantHandler.server.lua:638-646`, `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:411`
- **Trigger:** Solo Test (two players on the same map with no DuelMatch are "same party"); team mode for Gust Pad.
- **Why it's a bug:** every other CC is refused for anyone Config.MayHurt rules out; Gust Pad launches and Position Trade teleports another solo tester the caster cannot hurt (SameParty counts two duel-less players). Gust Pad also excludes teammates in team mode, while its Config Desc and the script header say "friend or foe" (doc drift).
- **Suggested fix:** decide the rule once (likely: enemies via IsFriendly + allies via IsAllyOf + self) and update the Desc.

#### P3-19: Dev-account free Ultimate is active in live ranked matches
> **Consolidator:** duplicate of **P1-02** (Dev mode live: free Ultimate in ranked + unlimited Sparks). Kept here for its slice-specific detail; counted once, under P1-02.
- **Severity:** High
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:152-166`, `game/ServerScriptService/SpellshotService.server.lua:124-126`, `:1118-1121`, `:338-348`, `game/ServerScriptService/DuelMatch.lua:513-514`
- **Trigger:** the place owner or UserId 2800693640 queues a Duel / team match on a live server.
- **Why it's a bug:** `AllowInLiveGame = true` and `FreeUltimate = true` mean `s.FreeUltimate` is on for those accounts; the Heartbeat pins UltCharge to 1 and the Ultimate path skips the spend (938-944), so DuelMatch's "every player starts with an empty Ultimate" is undone next frame. Team matches award Sparks (DuelMatch.award), so this also touches the economy. The config comment itself says to turn it off before public.
- **Suggested fix:** gate FreeUltimate/FreeMana/NoCooldowns off whenever the player has a `DuelMatch` attribute, independent of AllowInLiveGame.
- **Notes:** cross-ref the dev-gating / economy pass.

#### P3-20: Dev panel Heal can raise a dead humanoid's Health (corpse becomes "alive" to every check)
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:512-514`, `game/ServerScriptService/CombatCore.lua:68-76`
- **Trigger:** a dev presses HEAL while dead (e.g. out for the round in a team match).
- **Why it's a bug:** it writes `humanoid.Health = min(MaxHealth, Health + 25)` without the Core.Heal dead check; AliveCharacter / DuelMatch.alive then treat the Dead-state body as alive, so it can cast and be targeted.
- **Suggested fix:** route through Core.Heal (refuses the dead).

#### P3-21: Bulwark Charge's knock writes velocity on client-owned player roots (does little), unlike every other knock
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:411-415`
- **Trigger:** Bulwark Charge on a player vs on a dummy.
- **Why it's a bug:** `vroot.AssemblyLinearVelocity = ...` on a body the victim's client owns is overwritten by that client; Aftershock/Overload/Skyrider/Aqua send the throw to the victim's client. The comment acknowledges "reads as a shove", so players get a much weaker knock than the range shows.
- **Suggested fix:** send an AftershockKnock-style message to the victim player.

#### P3-22: GiveBack's Ultimate refund reads a stale per-role CastUlt from an earlier cast
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:841-867`, `:1037-1041`, `:1090-1094`
- **Trigger:** a HELD press (records no CastUlt but adds +0.06) given back with `ultToo` (e.g. Benediction's castBenediction refusal, RadiantHandler:787-789) when an earlier generic cast in the same role left `s.CastUlt[role]`.
- **Why it's a bug:** `added = s.CastUlt[role]` is whatever the last generic cast in that role recorded (never cleared otherwise), so the refund subtracts an unrelated amount (or nothing, leaving the held press's +0.06 as free charge).
- **Suggested fix:** record CastUlt on the held path too, and clear it when a new cast in the role starts.

#### P3-23: StatusReactions — Blessed borrows the Shielded record without its bookkeeping; shield zone-glow pulse ignores Reduce Flashing
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua:491-526`, `:684-688`, `:749-762`, `:142-147`, `:520`
- **Trigger:** Blessed and a Cinder Shield / Bedrock ring at once; Reduce Flashing on with a zone warning under a shield.
- **Why it's a bug:** startShielded sets `State.shield = rec` for the Blessed record too, and R.Clear only resets State.shield / shatters / re-routes the zone warning for kind "Shielded", so two rings draw at once and clearing Blessed leaves stale state. The ZoneGlow pulses at ~2.2 Hz (`sin(os.clock()*7)`) on the BAR layer, which Reduce Flashing does not dampen (only screenLayer is scaled).
- **Suggested fix:** give Blessed its own starter; dampen the glow when ReduceFlashing.
- **Notes:** cross-ref settings pass.

#### P3-24: Doc drift found while tracing combat state
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:287` (Icicle Shard Desc "3 stacks briefly roots" vs `game/ServerScriptService/StatusEffects.lua:65-69` / `game/ServerScriptService/AbilityHandler.server.lua:778-793`: a deep slow since 2026-10-08); `game/ServerScriptService/RadiantHandler.server.lua:41-44` ("this game has no teams" — team mode exists); `game/ServerScriptService/StatusEffects.lua:16-19` ("No Chain Bolt exists yet" — VoltaicHandler applies Charged); `game/ServerScriptService/CombatCore.lua:18-19` and `game/ServerScriptService/TrainingGround.server.lua:184-187` (TryParry "today TrainingGround's practice shots" — nothing calls TryParry since Deflect Gust was retired); `game/ServerScriptService/CombatCore.lua:277-280` (comment says a Pyro running a Zephyr Technique lands Zephyr hits "as the manual's cross-Element mixing intends" — impossible while TechniquesOwnElementOnly = true); `game/ServerScriptService/ElementalReactions.server.lua:27-30` (a reaction may use a teammate's status — true, but see P3-05 for the anti-synergy it implies); `game/ServerScriptService/ZephyrGustPadServer.server.lua:22` vs `:216-219` (see P3-18).
- **Trigger:** n/a
- **Why it's a bug:** player-facing Desc / maintainer comments disagree with shipping code.
- **Suggested fix:** update the text.

#### Could not complete
- Client-side halves of knocks/pulls/prison/cage visuals (AbilityFX, CryoFX, ZephyrSkyrider motor) were not read; P3-05's visual half and how clients honour AftershockKnock for Overload are inferred from server messages only.
- Workspace.SignalBehavior and Player destroy behaviour are not in manifest.json; P3-07 / P3-08 depend on them as noted.


---

## Pass 4 — The cross-Element combination surface

_Entries: 20 (1 High / 5 Medium / 14 Low). Distinct after merging duplicates: 19 (1 High / 5 Medium / 13 Low)._

### Pass 4 -- The cross-Element combination surface (the 20-Technique pool, the TechniquesOwnElementOnly gate, and Ultimate/Passive interactions over shared state)

Static, code-only reading of /home/user/spellshot-cloud. Nothing in the repo was edited. "LIVE" = reachable with the code
as shipped (`Config.TechniquesOwnElementOnly = true`, SpellshotConfig.lua:503). "LATENT" = only with
`TechniquesOwnElementOnly = false` (the config comment at SpellshotConfig.lua:501-502 explicitly supports flipping it back).

#### Files read (complete list, with "fully" or "partially: lines X-Y" for each)

Fully:
- game/ReplicatedStorage/Spellshot/SpellshotConfig.lua
- game/ServerScriptService/SpellshotService.server.lua
- game/ServerScriptService/AbilityHandler.server.lua (Cryo)
- game/ServerScriptService/PyroHandler.server.lua
- game/ServerScriptService/AquaHandler.server.lua
- game/ServerScriptService/RadiantHandler.server.lua
- game/ServerScriptService/TerraHandler.server.lua
- game/ServerScriptService/ToxinHandler.server.lua
- game/ServerScriptService/UmbraHandler.server.lua
- game/ServerScriptService/VoltaicHandler.server.lua
- game/ServerScriptService/ZephyrHandler.server.lua
- game/ServerScriptService/ZephyrSkyriderServer.server.lua
- game/ServerScriptService/ZephyrGustPadServer.server.lua
- game/ServerScriptService/ZephyrUpdraftServer.server.lua
- game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua
- game/ReplicatedStorage/IceMagic/RadiantClient.lua
- game/ReplicatedStorage/IceMagic/ToxinClient.lua
- game/ReplicatedStorage/IceMagic/ZephyrClient.lua
- game/ReplicatedStorage/Spellshot/AftershockKitData.lua, BulwarkWallKitData.lua, EarthenTombKitData.lua, VoltOrbKitData.lua
  (headers + structure; they are generated pure data with no requires, no attribute reads -- nothing to audit past the header)

Partially:
- game/ReplicatedStorage/IceMagic/VFXLibrary.lua: lines 1-560 (config, every ability row, AbilityFor, TechniqueSlot) plus a
  full function/attribute outline (grep); the remaining ~4.9k lines are Cryo M1/Primary/retired-ability drawing with no
  Technique code (verified by grep: Blizzard/DeepFreeze appear only in rows 241-250).
- game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua: lines 80-1080 (every handler and the merge/dispatch).
- game/ServerScriptService/HubServer.server.lua: 1-140, 185-240, 490-640 (zones, moveTo/respawnTo, shrines, altar, doors).
- game/ServerScriptService/DuelMatch.lua: 490-512 (+ grep of CastLocked/DuelMatch writers).
- game/ServerScriptService/CombatCore.lua: 60-400 (CanAct, IsFriendly, IsAllyOf, DealDamage, Heal, callerElement, clears).
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua: 360-613 (Offer, Origin, Kinds, Chosen, ElementSkin/Wrap, Resolve, HudSkin).
- game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua: 1-460 (Tuning, Clearance, Airborne, Holds, IsAirborne, KnockbackScale).
- game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua: 295-360, 780-914 (+ grep).
- game/ReplicatedStorage/IceMagic/VoltaicClient.lua: 300-715 (FireM1, TryCast, Railspike/VoltOrb/Cascade LocalCast, endOwn).
- game/ReplicatedStorage/IceMagic/AquaClient.lua: 560-790 (+ grep).
- game/ReplicatedStorage/IceMagic/UmbraClient.lua: grep only (LocalCast merge, FireM1 gate at 309).
- game/ReplicatedStorage/IceMagic/UmbraDecoyPoser.lua: 1-40.
- game/ReplicatedStorage/IceMagic/RadiantAnim.lua: 745-860, 1560-1660.
- game/ReplicatedStorage/IceMagic/RadiantFX_Staff.lua: 200-240 (+ grep).
- game/ReplicatedStorage/IceMagic/CryoFX.lua: 3120-3145, 3940-3990, 4040-4095 (+ grep of FBX/wrap gating, entry points).
- game/ReplicatedStorage/IceMagic/CryoWrap.lua: 920-945. ToxinWrap.lua: 20-60.
- game/ReplicatedStorage/IceMagic/FrostbladeKit.lua: 20-60; FrostDragonKit / FrostLotusKit / SnowGlobeKit: their On().
- game/ReplicatedStorage/IceMagic/TerraFX.lua: 1835-1855 (+ grep: RiseHeight, Aftershock/WallRaise entry points).
- game/ReplicatedStorage/IceMagic/PyroFX.lua: 2495-2520 (+ grep). Viewmodel.lua: 1620-1650.
- game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua: 230-275, 770-860, 1285-1305.
- game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua: 275-305 (+ grep).
- IceMagic *Tuning.lua (Cryo, Aqua, Radiant, Toxin, Umbra, Voltaic): grep for requires / Element / attribute reads /
  cooldowns (all are pure data with no requires; nothing reads a player).
- RailspikeFX, VoltOrbFX, VoltaicFX, OverchargeFX, PyroFlame_Tech, TerraFX_Wall, TerraFX_Tomb, ZephyrFX_Skyrider,
  ZephyrGustPad, UmbraFX, AquaFX, ToxinFX, RadiantFX_Hand: entry points located and grepped for every SkinCatalog / wrap /
  Element / StudioSkin / WrapStudio read (results in the appendix).

#### Sub-areas checked with nothing found
- checked, clean: THE GATE, for a normal (non-dev) client. Every path that sets Mobility/Defense routes through the Origin
  rule: LoadoutRequest "Technique" -> Config.MayEquip (SpellshotService.server.lua:776-782); LoadoutRequest "Element" ->
  Config.ApplyElement -> TechniquesFor, and every one of the 9 Elements has an ElementDefaults row (SpellshotConfig.lua:457-477),
  so an Element change always lands both slots on the new Element's own pair; onPlayer sets DefaultLoadout then ApplyElement
  (SpellshotService.server.lua:679-687); HubServer shrines go through ApplyElement (HubServer.server.lua:563-577; no
  Shrine_*_Monument exists in the Observatory per its own header, so this is dead code anyway); the dev panel's SetTechnique
  checks ElementMayHold (SpellshotService.server.lua:408-418, DevPanel.client.lua:291). At cast time
  VFXLibrary.AbilityFor (VFXLibrary.lua:507-513) refuses a key whose Origin is not the caster's Element, and every
  handler only acts on PerformCast for the ability AbilityFor resolved. A client cannot START a foreign or Exclusive
  Technique now. (What CAN survive is an already-running HELD Technique across an Element change: P4-07.)
- checked, clean: Technique-specific client->server remotes re-check ownership: ScorchingLashStrike (`holds`,
  PyroHandler.server.lua:1124), RailspikeFire (`techSlot`, VoltaicHandler.server.lua:544), RadiantLanceAim (M1 `holds`
  via stepLance), CrossSlashStrike (`holds`, ZephyrHandler.server.lua:440). SkyriderGust / SidearmShot do not (P4-07).
- checked, clean: skin/wrap selection for a Technique keys off its ORIGIN and the caster's CURRENT Element everywhere except
  ToxinWrap: SkinCatalog.Chosen returns Default unless `Element == Origin` (SkinCatalog.lua:493-507) and is what PyroFX,
  UmbraFX, TerraFX/ChargedRock (Aftershock, Bulwark Wall, Earthen Tomb), RadiantHandler/TerraHandler broadcasts and
  RadiantFX_* use; CryoWrap.For (CryoWrap.lua:927-934) and every Cryo skin kit's On() (Frostblade/FrostDragon/FrostLotus/
  SnowGlobe) check `Element == "Cryo"` first. The Studio-only StudioSkin / WrapStudio stand-ins are all behind
  RunService:IsStudio(). Aqua, Voltaic and Zephyr Techniques have no skins. (Toxin: P4-15, latent.)
- checked, clean: the Element a hit is credited with for reactions is the HANDLER script's (CombatCore.lua:281-296), i.e.
  the Technique's Origin, not the caster's Element -- consistent with the Origin rule in both flag states.
- checked, clean: Passives that key off the Element and not the Technique: Cold Momentum (AbilityHandler.server.lua:126),
  Bedrock (TerraHandler.server.lua:74-77), Updraft Holds (ZephyrUpdraft.lua:392-399), Overflow Light
  (RadiantHandler.server.lua:510), Symbiosis (ToxinHandler.server.lua:259), Riding the Current (AquaHandler.server.lua:304),
  Ember Refund / Chain Reaction / Dive reward (`holds(..., "Primary", ...)`). None reacts to another Element's Technique.
- checked, clean: Halo converts only its own caster's hits on players (RadiantHandler.server.lua:597-630); no other
  Element's damage heals through it. Mark is spent only by its marker's own non-DoT hit (UmbraHandler.server.lua:459-470);
  Detonate notes only Fireball/Immolate (PyroHandler.server.lua:161-173, 383, 227-229); RX_Primed and RX_Marked are separate.
- checked, clean: the two-writer attributes inside ONE Element are coordinated: Stacks_Primary (Pyro Immolate vs Voltaic
  prime, VoltaicHandler.server.lua:260-267), RX_Shielded (Cinder Shield vs Bedrock, TerraHandler.server.lua:1379-1387),
  SpeedCapUlt between Aftershock and Earthen Tomb (TerraHandler.server.lua:813-822, 1115-1123) and between Benediction and
  Halo (RadiantHandler.server.lua:539-546, 565-570, 758-762), InterruptedUntil (max, TerraHandler.server.lua:1211).
- checked, clean: Mirror Cage's bolts are aimed at the trapped body's live root (CryoFX.lua:4090), so a trapped body moved by
  Position Trade / Shadow Step is still drawn being shot.
- checked, clean: Gust Pad never takes a Skyrider rider, a wall or a decoy (ZephyrGustPadServer.server.lua:204-223); Deep
  Freeze, Blizzard, Mirror Cage, Twin Tide, Maw, Acid Rain, Volt Orb's bolt, Cascade, Patient Zero and Aftershock all skip or
  damage-only a Bulwark Wall.

---

#### P4-01: Skyrider's post-payment refusal is a free Earthen Tomb escape and an unlimited +6% Ultimate-charge farm while CC'd (exploit)
- **Severity:** High
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:1017-1043` (held path: pays, sets Holding_, adds 0.06 UltCharge at 1040, no Precheck for Skyrider), `game/ServerScriptService/SpellshotService.server.lua:841-867` (GiveBack: mana + CD_ back, Holding_ cleared, Ultimate charge only taken back when `ultToo == true`, 859), `game/ServerScriptService/ZephyrSkyriderServer.server.lua:125-131` (startRide refuses a Stunned body with `giveBack:Fire(player, role)` -- no ultToo), `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:307-316` (Stunned: JumpHeight <= 0, cap <= 0, RX_Staggered, RX_Entombed, Burrowed), `game/ServerScriptService/TerraHandler.server.lua:1011-1022` (CCBreak stamped on ANY accepted Mobility-Role press in Phase Start, Skyrider not excluded), `game/ServerScriptService/TerraHandler.server.lua:956-962` (CCBreak > CaughtAt => breakTomb "Escape"), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:390` / `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:313-314` (Skyrider row: Held, no Precheck)
- **Trigger:** LIVE. A Zephyr in a duel/team match whose client sends `CastRequest("Mobility", {})` directly (the honest client refuses the press itself, ZephyrSkyrider.lua:822-828) while (a) Entombed by an enemy Terra's Earthen Tomb, or (b) rooted (Cryo Flash Freeze / Deep Freeze / Mirror Cage / shard deep slow to 0 -> JumpHeight 0 or SpeedCapSlow 0) or staggered (Terra Bulwark Charge RX_Staggered).
- **Why it's a bug:** The press clears every gate in SpellshotService (no root/stun check on the held path), so it is paid, `Holding_` is set, UltCharge += 0.06 and PerformCast Start fires. Two listeners act on it: TerraHandler stamps `CCBreak` ("a Mobility Technique the server ACCEPTS"), and ZephyrSkyriderServer finds the body `Stunned` and calls `giveBack:Fire(player, role)`, which returns the 15 mana, zeroes `CD_<slot>` and clears `Holding_` -- but does not take back the 0.06 Ultimate charge (that needs the third argument; SpellshotService's own comment at 1025-1028 describes exactly this "6% of Ultimate for free" leak and fixed it only for Precheck rows). Result: (a) the Earthen Tomb releases its victim for nothing -- precisely the "the escape was free" bug TerraHandler's 2026-09-21 note at 1000-1005 says it closed for Tremor Vault; (b) because CD_ is zeroed and Holding_ cleared, the press can be repeated immediately with no rate limit: ~17 packets while held in any root/stagger/tomb fills the Ultimate from 0 to 1. Competitive integrity in ranked.
- **Suggested fix:** Give Skyrider a `Precheck = true` row and a `Precheck_Skyrider` BindableFunction in ZephyrSkyriderServer that answers `not Stunned and CanAct and Zone ~= "Hub"`, so a refused press is never paid; and make every post-payment refusal pass `ultToo = true` (ZephyrSkyriderServer 129, ZephyrGustPadServer 364). Independently, TerraHandler's escape listener should stamp CCBreak only after the Technique's own script has accepted the cast (e.g. let each Mobility handler stamp it, or defer the stamp a frame and skip it if `Holding_`/CD_ was given back).
- **Notes:** Cross-ref Pass on economy/Ultimate charge if one exists. The same "accepted then given back" escape exists with lower reach for Mark (UmbraHandler.server.lua:415-418, only on a lost-target race after its Precheck) and Position Trade (RadiantHandler.server.lua:673-676, 700-703).

#### P4-02: An honest Zephyr can never use Skyrider to break Earthen Tomb, the design's stated way out
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:307-316, 822-828, 879-882`, `game/ServerScriptService/ZephyrSkyriderServer.server.lua:128`, `game/ServerScriptService/TerraHandler.server.lua:628-636, 994-1022`, `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:597-599`
- **Trigger:** LIVE. Terra Earthen Tomb catches a Zephyr (default Skyrider in Q, Gust Pad in E).
- **Why it's a bug:** The Tomb's only way out is "a Mobility Technique the server ACCEPTS" (TerraHandler 628-630, Config.Statuses.Entombed). Skyrider's client `ready()` refuses while `Stunned` and `Stunned` names `RX_Entombed`, so the key only flashes red; even a press that got through is refused by the server for the same reason. Zephyr -- the "Mobility/Flank" Element -- is therefore one of the Elements with no escape at all, while P4-01 hands the escape to modified clients for free.
- **Suggested fix:** Decide the rule and make both sides agree: either drop `RX_Entombed` from `Stunned` for the PRESS (start the ride, which the Tomb's AlignPosition overrides until CCBreak lets go), or explicitly exclude Skyrider in TerraHandler's escape list and say so in Config.Statuses.Entombed.
- **Notes:** See P4-03 for the full per-Element escape table.

#### P4-03: Earthen Tomb's escape rule keys off the pool HALF, so non-movement Techniques (Mark, Antitoxin Vent) break it and most Elements have none
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:1011-1022`, `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:418-420, 454-455`, `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:373-375, 391-397, 597-599`, `game/ReplicatedStorage/IceMagic/RadiantTuning.lua:85`, `game/ReplicatedStorage/IceMagic/TerraFX.lua:219`
- **Trigger:** LIVE, Terra's Ultimate against each Element's own Techniques (now that each Element only holds its own):
  Cryo (Blizzard excluded, Deep Freeze is Defense): none. Pyro defaults (Detonate excluded, Lash is Defense): none -- only
  if the Pyro swapped Heat Rush in. Voltaic (Railspike excluded): none. Terra (Aftershock excluded): none. Zephyr: none
  (P4-02). Aqua (both Defense): none. Umbra: Mark escapes (needs a target in front, Precheck_Mark). Toxin: Antitoxin Vent
  always escapes. Radiant: Position Trade escapes only while within FloorProbe 10 of the floor, i.e. the first part of the
  12-stud rise.
- **Why it's a bug:** The listener accepts any ability whose row `Role == "Mobility"` minus a hand-kept exclusion list. The
  Config itself says Mark is "Offense/setup by flavour, in this half because Fade Step was" and Antitoxin Vent "Self-risk by
  flavour, in this half because Overgrowth Vault was" -- neither moves the body, yet both free it, while the genuinely
  mobile Skyrider does not (P4-02). The outcome is an Element-matchup asymmetry decided by legacy slot placement.
- **Suggested fix:** Mark escape-capable Techniques explicitly (e.g. `BreaksHold = true` on the row) instead of inferring it
  from `Role`, and choose them per design; update Config.Statuses.Entombed's text.
- **Notes:** Doc drift: Config.Statuses.Entombed says "all but Aftershock", the code also excludes Detonate, Lash, Blizzard and Railspike (P4-14).

#### P4-04: Updraft's airborne damage bonus is granted by enemy crowd control (an Entombed or juggled Zephyr hits 25% harder)
> **Consolidator:** canonical entry for: Updraft bonus while Entombed/juggled (no server pillar). Also reported as **GC-09**.
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/ZephyrUpdraftServer.server.lua:50-66, 76-92`, `game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua:126-130, 363-388`, `game/ServerScriptService/TerraHandler.server.lua:713-746, 862-880` (the Tomb holds the victim with an AlignPosition to a CanCollide=false anchor; no server-side pillar part), `game/ServerScriptService/ZephyrHandler.server.lua:184-188, 279` (Wind Blade snapshots Air at release), `game/ServerScriptService/ZephyrHandler.server.lua:773-781` (Cyclone pull), `game/ServerScriptService/TerraHandler.server.lua:1226-1232` (Aftershock knock), `game/ServerScriptService/ZephyrGustPadServer.server.lua:242-281`
- **Trigger:** LIVE. A Zephyr caught in Terra's Earthen Tomb (rise/burst/descent ~2.8 s at up to 12 studs, "the target can still shoot back"), juggled in an enemy Zephyr's Cyclone, or thrown by Aftershock / Bulwark Charge / Twin Tide / Leviathan's Maw / Sidearm knock-up / an enemy Gust Pad, keeps firing Wind Blade.
- **Why it's a bug:** Updraft's rule is purely geometric: MinClearance 1.5 studs of air under the feet by a server sphere cast, not Climbing/Swimming/Seated. The Tomb's pillar exists only in the clients' drawing (TerraFX), so on the server an Entombed body has nothing under it and counts as airborne for the whole hold; every non-DoT hit it lands gets x1.25 (DamageMult). Being CC'd by the opponent therefore buffs the victim; the Tomb in particular turns a guaranteed-crit Ultimate into a damage window for its Zephyr target.
- **Suggested fix:** In ZephyrUpdraftServer's airborne note, treat bodies held by someone else's ability as not airborne (RX_Entombed, a Cyclone catch, an active knock from another player -- e.g. a `HeldBy`/`KnockedUntil` attribute the knock senders set), or make Updraft count only self-initiated air (jump, slide-jump, own Gust Pad, Skyrider).
- **Notes:** Confidence Medium: correctness rests on TerraFX_Tomb creating client-only geometry (it is required from AbilityFX and the server never builds a pillar part); if a server pillar is ever added the Tomb case closes on its own. Skyrider's ride counting is deliberate (ZephyrUpdraft.lua:149-151).

#### P4-05: An interrupt (Aqua Undertow, Terra Aftershock) CRACKS a held Scorching Lash instead of cancelling it, and the Pyro's client is never told
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/AquaHandler.server.lua:493-502`, `game/ServerScriptService/TerraHandler.server.lua:1202-1212`, `game/ServerScriptService/SpellshotService.server.lua:809-824` (ReleaseHold -> endHold -> PerformCast Phase Release), `game/ServerScriptService/PyroHandler.server.lua:1037-1063` (a Release with a live hold record broadcasts the sweep and opens `lashes[player]`), `game/ServerScriptService/PyroHandler.server.lua:1122-1143` (the strike is accepted from due-0.12-ping to due+0.5+ping, due = Trigger 0.22; CanAct refuses only until InterruptedUntil = +0.5), `game/ReplicatedStorage/IceMagic/PyroFX.lua:161` (Trigger 0.22), `game/ReplicatedStorage/IceMagic/AquaTuning.lua:80`, `game/ReplicatedStorage/IceMagic/TerraFX.lua:176` (InterruptTime 0.5), `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:1164-1174` (the client drops its whip only on ScorchingLashHold On=false)
- **Trigger:** LIVE. A Pyro holding the whip is hit by an Aqua's Undertow snap or a Terra's Aftershock front.
- **Why it's a bug:** Both interrupts call `releaseHold` for every held role "as a release would", and for the Lash a release IS the attack: the server broadcasts a ScorchingLash sweep along the server's facing to everyone and arms a strike. The Pyro's own client still shows the whip in hand (no Off is sent on this path), plays a second crack on key-up, and its ScorchingLashStrike is accepted if the key comes up ~0.3-0.5 s after the interrupt (after InterruptedUntil, inside the window), landing damage + burn stacks from a whip the interrupt was supposed to end. PyroHandler's own header says a hold "that ends any other way ... sweeps nothing". Cross-Element: Aqua/Terra CC vs a Pyro Technique.
- **Suggested fix:** Give ReleaseHold a reason (e.g. `releaseHold:Fire(victim, role, "Interrupted")`) carried into PerformCast's payload, and have castScorchingLash treat an interrupted release like endLashHold (broadcast On=false, no `lashes` record). The same reason lets other held kits distinguish a cancel from a release.
- **Notes:** Cross-ref Pass on Pyro / held abilities.

#### P4-06: Aftershock's interrupt never reaches the victim's client; Aqua's Sidearm keeps firing phantom bullets, and its drawn shot ignores the interrupt
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:1202-1212, 1229-1232` (interruptVictim tells the victim only AftershockKnock), `game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua:871-913` (AftershockKnock handler: knock + interruptZephyrMotion only), `game/ReplicatedStorage/IceMagic/AquaClient.lua:762-765` (only Undertow's `AquaInterrupted` drops the gun), `game/ServerScriptService/AquaHandler.server.lua:643-669` (SidearmShot uses AliveCharacter, not CanAct; the first shot is accepted DrawTime after the press regardless of InterruptedUntil; rapid shots need Held or the 0.25 s grace)
- **Trigger:** LIVE. Aqua holding Sidearm is struck by a Terra's Aftershock (or interrupted within DrawTime by Undertow).
- **Why it's a bug:** The server ends the Sidearm hold, but the Aqua client still has `sidearm.Held = true` and keeps drawing and sending shots; past 0.25 s the server counts them `rej_released`, so the player sees bullets fly that do nothing until key-up. The tap's drawn shot is also accepted during InterruptedUntil (CanAct is not asked), unlike every other kit's release remote (CombatCore.lua:78-93's stated rule).
- **Suggested fix:** Have every interrupter send the victim one generic "Interrupted" message (AquaClient, the Lash, Benediction's arms, etc. all listen), and use Core.CanAct in SidearmShot.
- **Notes:** Same root as P4-05.

#### P4-07: Held Techniques survive an Element or Technique change mid-hold (no ownership re-check), unlike the Lash, Railspike, Light Lance and the Overcharge prime
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:750-757` (loadout locked only while `Zone == "Arena" and DuelMatch ~= nil`), `game/ServerScriptService/SpellshotService.server.lua:884-920` (a release is matched against Holding_, not AbilityFor), `game/ServerScriptService/PyroHandler.server.lua:1262-1284` (Heat Rush heartbeat: no `holds` check; RushSpeedMult and the 40% ranged reduction stay), `game/ServerScriptService/TerraHandler.server.lua:568-586` (Bulwark Wall), `game/ServerScriptService/RadiantHandler.server.lua:835-868` (Benediction plant), `game/ServerScriptService/AquaHandler.server.lua:643-669, 881-893` (Sidearm), `game/ServerScriptService/ZephyrSkyriderServer.server.lua:294-314, 341-393` (ride + SkyriderGust flap), versus `game/ServerScriptService/PyroHandler.server.lua:1069-1089`, `game/ServerScriptService/VoltaicHandler.server.lua:1011-1013, 1024-1025`, `game/ServerScriptService/RadiantHandler.server.lua:416`
- **Trigger:** LIVE outside a duel/team match (Solo Test, Training Grounds, any Arena zone without DuelMatch) or via the dev panel: hold Heat Rush / Bulwark Wall / Benediction / Sidearm / Skyrider, then pick another Element (LoadoutRequest "Element", which goes through while the key stays down) or swap the Technique.
- **Why it's a bug:** After the change, AbilityFor no longer resolves the Technique for this player, yet the running hold keeps its effects until its own end condition (key-up, MaxHold 4 s, mana, HoldGiveUp 15 s, MaxRide 10 s): a now-Cryo player keeps Pyro's +40% speed and ranged-damage reduction, a Terra-turned-Pyro keeps the wall, a Zephyr-turned-anything keeps flying and flapping. The code already treats this as wrong for the Lash ("the Lash no longer in its slot ... ends it without a crack"), Railspike ("Loadout"), Light Lance ("Swapped") and the Overcharge prime ("Loadout"); the five held Techniques above simply lack the same check. Not reachable mid-duel for normal players.
- **Suggested fix:** Add the same per-frame `holds(player, slot, Id)` check to each of the five (ending the hold via ReleaseHold), or have SpellshotService's refreshSlots fire ReleaseHold for any Holding_ whose Id AbilityFor no longer resolves in that slot.
- **Notes:** Becomes slightly wider LATENT (with the flag false a Technique swap keeps a borrowed hold too) but the mechanism is identical.

#### P4-08: Cooldown, give-back and Ultimate bookkeeping are keyed by SLOT, so a swap between press and release/give-back charges the wrong ability
> **Consolidator:** canonical entry for: GiveBack/cooldowns keyed by slot not ability. Also reported as **P1-17**.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:809-816` (endHold stamps `CD_<role>` with the HELD ability's Cooldown), `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:1229, 1274, 1280-1291` (the client's held gate only applies when the NEW slot ability is Held; heldRole carries the old Id to key-up), `game/ServerScriptService/SpellshotService.server.lua:841-850` (GiveBack refunds `abilityForRole(p, role)` = the CURRENT ability's ManaCost), `game/ServerScriptService/UmbraHandler.server.lua:783-788` / `game/ServerScriptService/RadiantHandler.server.lua:690-703` (delayed give-backs after a dissolve), `game/ServerScriptService/SpellshotService.server.lua:1093-1094` (CastUlt[role])
- **Trigger:** LIVE out of match (P4-07's window). E.g. Pyro holds Heat Rush in Q, switches to Cryo, presses Q (Blizzard casts: CD_Mobility = +18 s), lets go: the Heat Rush release stamps CD_Mobility = +8 s, so Blizzard is back 10 s early. Or Radiant presses Position Trade, switches Element during the dissolve, the swap finds no floor: GiveBack refunds the new Mobility row's mana and clears its cooldown. Any Element change also carries `CD_Mobility`/`CD_Defense` over onto the new Element's Techniques.
- **Why it's a bug:** The resource rules assume the slot still holds the ability that was paid for; after a loadout change they charge, refund or time the wrong one.
- **Suggested fix:** Record the paid ability Id with the cooldown (e.g. `CDId_<role>`) and have endHold/GiveBack act on the recorded Id (skip if the slot changed); optionally clear CD_/CastUlt per slot on a loadout change.
- **Notes:** Out-of-match only for normal players, hence Low.

#### P4-09: Dev tools can change Element/Techniques mid-duel, and dev mode is on in live servers
> **Consolidator:** duplicate of **P1-02** (Dev mode live: free Ultimate in ranked + unlimited Sparks). Kept here for its slice-specific detail; counted once, under P1-02.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:390-418, 402-407` (SetElement / SetTechnique / EcoReset: no Arena+DuelMatch lock), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:158-161` (AllowInLiveGame = true, a collaborator UserId)
- **Trigger:** A dev (place owner or the listed collaborator) in a ranked duel uses the dev panel's ELEMENT/TECHNIQUE rows.
- **Why it's a bug:** The player-facing LoadoutRequest is locked for the whole duel ("a swap would also refill a charge ability's stock mid-fight"), the dev path is not, so a dev's mid-duel swap exercises P4-07/P4-08 inside a real match.
- **Suggested fix:** Apply the same duel lock to the dev loadout actions (or require DuelMatch == nil), and turn AllowInLiveGame off before release, as its own comment says.
- **Notes:** Cross-ref the dev-tools pass.

#### P4-10: The Loadout menu's Technique rows are inert for 8 of 9 Elements (and claim a change on every click)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua:244-259` (list = ElementMayHold only), `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua:822-845` (step skips the other slot's key, then re-sends and announces the browsed one), `game/ServerScriptService/SpellshotService.server.lua:780-782`
- **Trigger:** LIVE. Any Element but Pyro (exactly two own Techniques), clicking either Technique row's arrows.
- **Why it's a bug:** With a two-item list and the other slot's item skipped, every step lands back on the equipped Technique, re-sends it and prints "<Name>: <Desc>" as if it had been chosen. A Q/E swap is impossible: each single request would put one Technique in both slots and the server refuses it. Only Pyro (4 Techniques) can change anything.
- **Suggested fix:** When an Element has exactly two Techniques, offer a "swap Q/E" action (a server request that sets both attributes at once) or show the rows as fixed; do not send or announce a no-op.
- **Notes:** UX consequence of the P31 flag.

#### P4-11: Ring of Fire's "Hot" variant reads Heat Rush's Heat, which Pyro's default loadout never equips
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/PyroHandler.server.lua:684-685, 703, 709`, `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:426, 458`
- **Trigger:** LIVE. A Pyro on its defaults (Detonate + Scorching Lash) casts Ring of Fire.
- **Why it's a bug:** The Ultimate's Desc promises "bigger and hotter at high Heat", but Heat only builds while Heat Rush is held, and ElementDefaults.Pyro does not include Heat Rush. The Ultimate silently depends on a sibling Technique the player must know to swap in.
- **Suggested fix:** Design call: feed Heat from other Pyro sources, or include Heat Rush in the defaults, or reword the Desc/HUD.
- **Notes:** Info-level design dependency.

#### P4-12: Decoy Double fools some Elements' target locks but not others'
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:693-696` (Earthen Tomb acquire), `game/ServerScriptService/AbilityHandler.server.lua:1226-1229` (Mirror Cage), `game/ServerScriptService/UmbraHandler.server.lua:397-399` (Mark) -- none excludes `DecoyOwner`; versus `game/ServerScriptService/RadiantHandler.server.lua:240` and `game/ServerScriptService/ToxinHandler.server.lua:164` ("Walls, decoys and veiled bodies never"), `game/ServerScriptService/ZephyrGustPadServer.server.lua:205`
- **Trigger:** LIVE. An enemy Umbra's decoy stands nearer the aim line than the Umbra.
- **Why it's a bug:** Earthen Tomb and Mirror Cage (ChargeOnCatch) can lock and SPEND the Ultimate on a decoy (it breaks on the first damage), and Mark can be wasted on it, while Patient Zero, Blessing and Position Trade can never pick one. Whether the "only misdirection tool in the game" works depends on which Element is being misdirected, by accident of each handler's filter.
- **Suggested fix:** Decide once (CombatCore helper, e.g. `Core.Lockable(model)`) and use it in every lock.
- **Notes:** Design consistency.

#### P4-13: Ring of Fire's burn and Cyclone's AIRBORNE tag are applied to a Bulwark Wall
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/PyroHandler.server.lua:704-712, 207-236` (no IsWall before `burn`: RX_Burning, Status.Stamp and the Burning tag on the wall model), `game/ServerScriptService/ZephyrHandler.server.lua:737-741, 829-833` (Cyclone catches the wall via PrimaryPart and tags it Airborne each tick), `game/ServerScriptService/AbilityHandler.server.lua:109-113` (the project's own rule: damage on a wall is the design, nothing else is)
- **Trigger:** LIVE. A Terra raises Bulwark Wall inside an enemy Pyro's Ring of Fire or a Zephyr's Cyclone.
- **Why it's a bug:** Status attributes land on the wall's model (the 2026-09-21 bug class AbilityHandler describes: tags pinned on a wall that no sweep clears).
- **Suggested fix:** `not Core.IsWall(model)` before `burn(...)` and before the Cyclone catch/tag.
- **Notes:** Cross-ref status pass.

#### P4-14: Doc drift -- comments still describe the cross-Element pool, and several rules are misdescribed
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:22-28, 417` ("Scorching Lash ... any Element may equip it"), `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:219, 277` ("a Cryo player may run Heat Rush", "any Element's Technique"), `game/ServerScriptService/PyroHandler.server.lua:37, 901`, `game/ServerScriptService/TerraHandler.server.lua:1451-1453`, `game/ServerScriptService/AbilityHandler.server.lua:148`, `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:1471-1472`, `game/ServerScriptService/SpellshotService.server.lua:702-704, 714-716`; `game/ServerScriptService/TerraHandler.server.lua:633-634` ("a root ... refuses the Mobility key outright" -- false: only Charges casts check the cap, SpellshotService.server.lua:977-997; Mark, Position Trade, Vent etc. cast while rooted); `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:597-599` (Entombed: "all but Aftershock" vs TerraHandler 1016-1017); `game/ServerScriptService/ZephyrGustPadServer.server.lua:22-28` and `SpellshotConfig.lua:411` ("friend or foe") vs 216-219 (teammates excluded); `SpellshotConfig.lua:418` (Lash Cooldown 2.5) vs `VFXLibrary.lua:281` (5); `DevPanel.client.lua:288` ("any of 20")
- **Trigger:** Reading the code / tooltips.
- **Why it's a bug:** The shipped rule is Origin-only (P31); these texts tell a reader (and any agent editing the code) the opposite, and two of them misstate mechanics that P4-02/P4-03 depend on.
- **Suggested fix:** Update the comments/Desc strings, or tag them "with TechniquesOwnElementOnly = false".
- **Notes:** Doc drift only.

#### P4-15: (latent: only with TechniquesOwnElementOnly = false) ToxinWrap paints a borrowed Acid Rain / Antitoxin Vent in the caster's old Toxin wrap
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ToxinWrap.lua:30-46` (paletteFor reads `ElementWrap(pl, "Toxin")` with no Element check), `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:468-475` (ElementWrap does not check the current Element), `game/ServerScriptService/SpellshotService.server.lua:738-747` (the attribute persists after an Element change)
- **Trigger:** Flag false; a player sets a Toxin wrap while Toxin, becomes Cryo, equips Acid Rain or Antitoxin Vent.
- **Why it's a bug:** Every other kit draws a borrowed Technique in Default (SkinCatalog.Chosen's Origin rule; CryoWrap.For line 932 "a borrowed Cryo Technique: Default"; SpellshotService 715 "a borrowed Technique keeps Default"). ToxinWrap alone keys on the stale ElementWrap_Toxin attribute.
- **Suggested fix:** In paletteFor, return nil unless `pl:GetAttribute("Element") == "Toxin"` (mirror CryoWrap.For).
- **Notes:** Cosmetic only.

#### P4-16: (latent: only with TechniquesOwnElementOnly = false) Shared SpeedCapUlt / RX_Shielded writers clear each other's state across kits
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/RadiantHandler.server.lua:739-742` (endPlant clears SpeedCapUlt if it is 0, whoever set it), `game/ServerScriptService/UmbraHandler.server.lua:254-260` (Eclipse's releaseHold clears a 0 cap the same way), `game/ServerScriptService/TerraHandler.server.lua:813-822, 1115-1123` (Tomb/Aftershock only know about each other), `game/ServerScriptService/PyroHandler.server.lua:567-572` (clearShield sets RX_Shielded false unconditionally) vs `game/ServerScriptService/TerraHandler.server.lua:1375-1387` (Bedrock republishes only when its stack count changes)
- **Trigger:** Flag false. A Terra with Benediction plants, casts Earthen Tomb (TombPhase "Cast" sets SpeedCapUlt 0) and lets the plant go: endPlant lifts the Tomb's grip cap, so she walks out of her own cast. An Umbra with Aftershock casts Eclipse mid-windup: the windup's end lifts Aftershock's root. A Terra with Cinder Shield: the shield's end drops RX_Shielded under live Bedrock plates.
- **Why it's a bug:** Each writer was coordinated only with the kits of its own Element; mixing Techniques breaks the "only while it is still OURS" rule each comment claims.
- **Suggested fix:** A small owner-tagged cap API in SpellshotService/CombatCore (each holder sets and clears its own token; the cap is the min over live tokens), and recount RX_Shielded from all sources as RX_Burning is (PyroHandler.server.lua:197-204).
- **Notes:** Severity Medium for the Tomb/Aftershock cases (they are competitive roots), else Low.

#### P4-17: (latent: only with TechniquesOwnElementOnly = false) A borrowed Cinder Shield locks Aqua's, Toxin's and Umbra's M1 for its 5 s
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:412-417` (Cinder Shield plays the held two-arm clip CinderShieldHold), `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:1462-1464` (Riptide refuses while Viewmodel.IsPlaying), `game/ReplicatedStorage/IceMagic/ToxinClient.lua:84-88`, UmbraClient.lua:309 (same gate); Fireball/Icicle Shard/Wind Blade/Chain Bolt special-case the shield (SpellshotInput 1334, 1392, 1473; VoltaicClient.lua:324-326); Boulder Shot's windup (SpellshotInput 1590) replaces the hold clip
- **Trigger:** Flag false; an Aqua/Toxin/Umbra equips Cinder Shield and casts it.
- **Why it's a bug:** Their M1 gates treat the shield's held clip as a two-handed cast and spend the click, so the M1 is dead for the shield's Duration; a Terra's Boulder charge silently tears down the shield's hold pose.
- **Suggested fix:** Use the same `shielded` exception the other M1s use (or have Viewmodel expose "a one-hand hold" so IsPlaying excludes it).
- **Notes:** Client-only; Cinder Shield is not Exclusive, so this is the first thing a flag flip exposes.

#### P4-18: (latent: only with TechniquesOwnElementOnly = false) A borrowed Decoy Double is trivially spotted
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/UmbraDecoyPoser.lua:4-9` (every copy plays CastPose UmbraDecoyReady), `game/ReplicatedStorage/IceMagic/RadiantAnim.lua:835-860` (props such as Radiant's staff are built only for real Radiant characters), `game/ServerScriptService/UmbraHandler.server.lua:839-884`
- **Trigger:** Flag false; e.g. a Radiant casts Decoy Double.
- **Why it's a bug:** The copy stands in Umbra's ready stance and without the caster Element's client-side props (no staff), while the real body shows both, so "the only misdirection tool" does not misdirect for any non-Umbra holder.
- **Suggested fix:** Pose the copy from the caster's own idle (CastPose state of the caster at the cast) and attach the same client props for the copy's owner Element.
- **Notes:** Cosmetic, but the cosmetic is the mechanic here.

#### P4-19: (latent: only with TechniquesOwnElementOnly = false) Minor borrowed-Technique presentation gaps
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/ReplicatedStorage/IceMagic/RadiantClient.lua:406-425` (RadiantFX_Staff's effect pool is prewarmed only once some player is Radiant), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:529-557` (every Element has ElementDefaults, so TechniquesFor's "keep what you hold" branch never runs: a borrowed Technique is always replaced on an Element pick)
- **Trigger:** Flag false; a non-Radiant casts Benediction / Position Trade in a match with no Radiant (first-cast hitch); any Element pick wipes borrowed Techniques.
- **Why it's a bug:** Small: a cold pool on first use, and the pool-preserving logic in TechniquesFor is dead code under the current defaults table.
- **Suggested fix:** Prewarm on equip of any Radiant Technique; decide whether an Element pick should keep borrowed Techniques and trim ElementDefaults or TechniquesFor accordingly.
- **Notes:** Confirm the hitch in Play before acting.

#### P4-20: Cold Momentum and Riding the Current both write MoveSpeedMult; an Element switch mid-buff lets one clobber the other
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:134, 137-145`, `game/ServerScriptService/AquaHandler.server.lua:277-284, 313-322`, `game/ServerScriptService/SpellshotService.server.lua:237-238, 620`
- **Trigger:** LIVE out of match: an Aqua riding its wet ground switches to Cryo and lands a hit (or a Cryo with Cold Momentum up switches to Aqua and steps on old wet ground); the other script's timer/grace later writes 1/nil over the live buff.
- **Why it's a bug:** One attribute, two owners with independent clocks; Heat Rush already avoids this with its own RushSpeedMult.
- **Suggested fix:** Give Riding the Current its own multiplier attribute (as Heat Rush has) and multiply it in stanceSpeed / MovementController.
- **Notes:** Low; per-Element Passives cannot overlap in a match.

#### Could not complete
- VFXLibrary.lua beyond line 560, CryoFX/TerraFX/PyroFX/UmbraFX/AquaFX/ToxinFX/RadiantFX_*/RailspikeFX/VoltOrbFX/
  PyroFlame_Tech/TerraFX_Wall/TerraFX_Tomb/ZephyrFX_Skyrider/ZephyrGustPad bodies were read only at their entry points and
  via targeted greps for Element/skin/wrap/tuning reads (tens of thousands of lines of drawing code). Settings coverage
  (Graphics Quality / Reduce Enemy VFX / Reduce Flashing / Colourblind) inside them was not audited here (other passes).
- UmbraClient.lua, AquaClient.lua (outside 560-790), VoltaicClient.lua (outside 300-715), ZephyrSkyrider.lua (outside the
  ranges listed), LoadoutMenu.client.lua and DevPanel.client.lua were read partially (the Technique-related parts).
- HubServer.server.lua was read in the listed ranges only (zones, moves, shrines, prompts); its queue/vote code was not.

#### Appendix: the 20 Techniques

| Technique | Origin | Server path (file:line) | Client cast / FX path | Caster-Element assumptions found | Grade |
|---|---|---|---|---|---|
| Heat Rush | Pyro | PyroHandler.server.lua:520 (held; heat loop 1262-1284; ranged modifier 541-560) | SpellshotInput LOCAL_CAST.HeatRush :409; AbilityFX HeatRushRelease :512, HeatDeflect :522; PyroFX.WatchHeat (AbilityFX :259) | None in the cast; Ring of Fire (Pyro Ult) reads its Heat (P4-11). Survives an Element change mid-hold (P4-07); Tomb escape (paid) | LIVE (P4-07, P4-08, P4-11) |
| Blizzard | Cryo | AbilityHandler.server.lua:1061 (step 1080-1103) | SpellshotInput LOCAL_CAST.Blizzard :383; AbilityFX :181 -> CryoFX.Blizzard (CryoFX.lua:2262), wrap via CryoWrap.For (Element-gated, :932) | None (Chilled status is the Origin's); excluded from Tomb escape | clean |
| Railspike | Voltaic | VoltaicHandler.server.lua:521 (+ RailspikeFire :534, stepRail :1016) | VoltaicClient.LocalCast.Railspike :580 -> RailspikeFX.Charge/Fire (:2638/:2658) | None; ends on loadout change (techSlot) | clean |
| Aftershock | Terra | TerraHandler.server.lua:1246 (Precheck :1097, step :1279, strike :1215) | SpellshotInput LOCAL_CAST.Aftershock :1688; AbilityFX :823-913 -> TerraFX.Aftershock (:4302), wrap via Chosen | None in the cast; its interrupt does not notify victims' clients (P4-05, P4-06); SpeedCapUlt shared (P4-16) | LIVE cross-kit (P4-05/06); LATENT (P4-16) |
| Skyrider | Zephyr | ZephyrSkyriderServer.server.lua:125 (PerformCast :142, gust :294, checks :341) | ZephyrSkyrider.LocalCast.Skyrider :865 via ZephyrClient.TryCast; ZephyrFX_Skyrider | Stunned includes RX_Entombed (P4-02); post-pay refusal gives back without the Ult charge and still breaks the Tomb (P4-01); no ownership re-check mid-ride (P4-07) | LIVE (P4-01 High, P4-02, P4-07) |
| Mark | Umbra | UmbraHandler.server.lua:414 (Precheck :443, payoff modifier :459) | UmbraClient/UmbraAnim.LocalCast.Mark (UmbraAnim.lua:241); UmbraFX via Chosen | Headshot bonus only via Shadow Dart, documented; breaks Earthen Tomb though it moves nothing (P4-03); can be wasted on a decoy (P4-12) | LIVE (P4-03, P4-12) |
| Position Trade | Radiant | RadiantHandler.server.lua:672 (Precheck :658) | RadiantClient.LocalCast :137 -> RadiantAnim.LocalCast.PositionTrade :1570; RadiantFX_Hand; staff only on Radiant bodies (designed fallback) | Skin via Chosen (gated); Tomb escape only in the first 10 studs of the rise (P4-03); delayed GiveBack is slot-keyed (P4-08) | LIVE (P4-03, P4-08) |
| Antitoxin Vent | Toxin | ToxinHandler.server.lua:592 (DoT modifier :198, self-poison :227) | ToxinClient Handlers :115 -> ToxinWrap.Run -> ToxinFX | Cleanses only own poison (works for any holder); breaks Earthen Tomb though it moves nothing (P4-03); wrap not Element-gated (P4-15) | LIVE (P4-03); LATENT (P4-15) |
| Detonate | Pyro (Exclusive) | PyroHandler.server.lua:854 (Precheck :759) | SpellshotInput LOCAL_CAST.Detonate :421; AbilityFX :625-650 | Reads Pyro's Fireball/Immolate notes by design; Exclusive in both flag states; excluded from Tomb escape | clean |
| Cinder Shield | Pyro | PyroHandler.server.lua:574 (soak :629, burst :591) | SpellshotInput LOCAL_CAST.CinderShield :412; AbilityFX :528-552 | RX_Shielded unconditional clear vs Bedrock (P4-16); held two-arm clip blocks other Elements' M1 (P4-17) | LATENT (P4-16, P4-17) |
| Deep Freeze | Cryo | AbilityHandler.server.lua:1121 (traps :1168, spring :1152) | SpellshotInput LOCAL_CAST.DeepFreeze :384; AbilityFX :188-198 -> CryoFX (:2768), Element-gated wrap/skins | None; Cold Momentum only for a Cryo caster | clean |
| Volt Orb | Voltaic | VoltaicHandler.server.lua:786 (step :816, burst :759) | VoltaicClient.LocalCast.VoltOrb :621 + AimStart :936; VoltOrbFX.Windup/Throw/Burst (:2766-2841) | None | clean |
| Bulwark Wall | Terra | TerraHandler.server.lua:555 (raise :520, drain :568, hits :596) | AbilityFX :800-808 -> TerraFX.WallRaise (:2589)/TerraFX_Wall (wrap via WrapOf/Chosen :1313); first-person hand AbilityFX :993 | None; survives an Element change mid-hold (P4-07); receives Ring of Fire burn / Cyclone tag (P4-13) | LIVE (P4-07, P4-13) |
| Gust Pad | Zephyr | ZephyrGustPadServer.server.lua:359 (Precheck :343, scan :284, launch :243) | ZephyrGustPad LocalCast via ZephyrClient merge; handlers GustPad/GustPadStep/GustPadLaunch | None; launches enemy Zephyrs into Updraft's bonus (P4-04); "friend or foe" text vs teammate exclusion (P4-14) | LIVE (P4-04, P4-14) |
| Decoy Double | Umbra | UmbraHandler.server.lua:839 (break watch :880, clock :925) | UmbraAnim.LocalCast; UmbraFX DecoySpawn/Break; UmbraDecoyPoser | Copy posed in Umbra's stance, no caster props (P4-18); fools some locks only (P4-12) | LIVE (P4-12); LATENT (P4-18) |
| Benediction | Radiant | RadiantHandler.server.lua:777 (Precheck :764, stepPlant :835, endPlant :734) | RadiantClient.LocalCast :137 -> RadiantAnim.LocalCast.Benediction :1601; RadiantFX_Staff (tip anchor falls back to the hand) | No staff for a non-Radiant (designed); pool prewarm only if a Radiant exists (P4-19); SpeedCapUlt clear (P4-16); survives Element change (P4-07) | LIVE (P4-07); LATENT (P4-16, P4-19) |
| Acid Rain | Toxin | ToxinHandler.server.lua:629 (Corroded :615, modifier :227) | ToxinClient Handlers :115 -> ToxinWrap.Run -> ToxinFX | Corroded amplifies any poisoner's poison (team synergy by design); wrap not Element-gated (P4-15) | LATENT (P4-15) |
| Scorching Lash | Pyro | PyroHandler.server.lua:1025 (hold watch :1069, strike :1097, stacks :963) | SpellshotInput tryScorchingLash :1079 / releaseLash :1119; AbilityFX :657-687 | Ends on loadout change (good); an interrupt cracks it (P4-05); "any Element may equip it" doc drift (P4-14) | LIVE (P4-05, P4-14) |
| Twin Tide | Aqua (Exclusive) | AquaHandler.server.lua:581 | AquaClient.LocalCast.TwinTide :244; AquaFX | None; Exclusive in both flag states (wet lane, crush lift feeds an enemy Zephyr's Updraft, P4-04) | LIVE (P4-04 only) |
| Sidearm | Aqua (Exclusive) | AquaHandler.server.lua:627 (SidearmShot :643, SidearmHit :713, give-up :881) | AquaClient.LocalCast.Sidearm :633, ReleasePayload :650; AquaFX | Shots use AliveCharacter not CanAct and the client is not told of Aftershock's interrupt (P4-06); survives an Element change (P4-07) | LIVE (P4-06, P4-07) |


---

## Pass 5 — Skins, wraps and settings honouring

_Entries: 133 (1 Critical / 8 High / 44 Medium / 80 Low). Distinct after merging duplicates: 115 (5 High / 36 Medium / 74 Low)._

### Pass 5, slice A: Cryo skins and wraps layering (CryoFX family)

#### Files read (complete list)
- game/ReplicatedStorage/IceMagic/CryoFX.lua: fully (1-4809)
- game/ReplicatedStorage/IceMagic/CryoWrap.lua: fully (1-1585)
- game/ReplicatedStorage/IceMagic/CryoAurora.lua: fully (1-1395)
- game/ReplicatedStorage/IceMagic/CryoTuning.lua: fully
- game/ReplicatedStorage/IceMagic/FlashFreezeData.lua: partially. I read the header and the key structure (Version, timings, Meshes, Tracks); the rest is generated mesh and track data with no code (grep finds no `function`, `require`, Skin or Wrap)
- game/ReplicatedStorage/IceMagic/FrostDragonData.lua: partially. I read the header and the structure, and measured every piece's vertex bounds with a script (the claw piece is used in a finding). It is generated numbers only
- game/ReplicatedStorage/IceMagic/FrostDragonFX.lua: fully
- game/ReplicatedStorage/IceMagic/FrostDragonKillFX.lua: fully
- game/ReplicatedStorage/IceMagic/FrostDragonKit.lua: fully
- game/ReplicatedStorage/IceMagic/FrostLotusFX.lua: fully
- game/ReplicatedStorage/IceMagic/FrostLotusKit.lua: fully. Lines 110-590 are geometry builders; I skimmed them for SPECS/kind coverage
- game/ReplicatedStorage/IceMagic/FrostbladeKit.lua: fully
- game/ReplicatedStorage/IceMagic/SnowGlobeFX.lua: fully
- game/ReplicatedStorage/IceMagic/SnowGlobeKit.lua: fully
- game/StarterPlayer/StarterPlayerScripts/FrostDragonKillFX.client.lua: fully
- game/ServerScriptService/FrostDragonKillHook.server.lua: fully
- game/ServerScriptService/_AuroraStage.server.lua: fully
- game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua: fully
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua: fully
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua: fully
- game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua: fully
- game/ServerScriptService/AbilityHandler.server.lua: partially: 100-150, 730-1200 (Chill / ShardRelease / ShardHit / Deep Freeze traps), plus a grep of every Skin/Wrap/SetAttribute/broadcast/tellOwner line
- Cross-references (partially): VFXLibrary.lua 2186-2300, 2603-2650, 2723-2830, 4870-4900, 4960-5135, 5212-5420; SpellshotService.server.lua 715-750; CastPose.lua 105-140, 1780-1840, 2145; Viewmodel.lua 1005-1060; SpellshotInput.client.lua 1460-1530; FirstPersonController.client.lua 250-285; SpellshotConfig.lua 180-200; AbilityFX.client.lua (grep: 106-125, 188-237); _BROStage.server.lua 1-40; _BROStageClient.client.lua fully; LoadoutMenu.client.lua 25-40 and grep; docs/SPELLSHOT_Design_Manual.md (grep: lines 76, 128, 398, 552, 655, 683, 720, 723, 797); manifest.json around 24915-24935 and 38140-38175.
- Tools I wrote to count and resolve locals (scratchpad/tools/luacount.py, resolve.py, resolve_up.py): a Luau tokenizer, a per-scope local counter, a lexical free-name resolver and an upvalue counter.

#### What the catalog actually offers for Cryo (the axes enumerated)
- Skins (`ElementSkins.Cryo`, SkinCatalog.lua:432): Default, Frostblade (Uncommon), SnowGlobe (Rare in the catalog), FrostLotus (Epic), FrostDragon (Mythic).
- Wraps (`ElementWraps.Cryo`, :457): Default, MintRime (Uncommon), DeepGlacier (Uncommon), BlackIce (Rare: Solid, Edge, Life), SakuraFrost (Epic: Glow, Pulse, Motes, Over, OpaqueStyles). Aurora (Mythic) is defined (:337) but is NOT listed. `ElementWrapAllowed` rejects it, so a live player cannot wear it. It is reachable only through a Studio `WrapStudio` dummy.
- Layering: Cryo never uses the composite `"<Skin>+<Wrap>"` string. `Offer`/`Origin` have no Cryo abilities, so `Chosen()` always returns Default for Cryo. A Cryo skin is `ElementSkin_Cryo`, a Cryo wrap is `ElementWrap_Cryo`, and CryoWrap paints the skin's kit pieces when both are set (`W.PaintKit` hooked onto every kit's New/Get, CryoWrap.lua:1531-1567). 25 live combinations are reachable (5 skins x 5 wrap choices); 16 of them put a real wrap over a real skin.

#### Per-module local-variable counts (Luau limit: 200 live locals per function scope)
"Chunk live" is the maximum number of locals alive at once in the top-level chunk, which is the number that hits the 200 limit. "Decls" counts every `local` name at chunk level, including those scoped inside top-level `do`/`for` blocks.

| Module | chunk decls | chunk live (max) | headroom | biggest function (live locals) | max upvalues in one fn |
|---|---|---|---|---|---|
| CryoFX.lua | 216 | **198** | **2** | CryoFX.Blizzard @2262: 52 | 78 (MirrorCage stepper @4105) |
| CryoWrap.lua | 113 | 108 | 92 | anon @319: 33 | 13 |
| CryoAurora.lua | 83 | 83 | 117 | anon @1296: 44 | 15 |
| CryoTuning.lua | 1 | 1 | 199 | MirrorCageBolts: 9 | - |
| FlashFreezeData.lua | 1 | 1 | 199 | - | - |
| FrostDragonData.lua | 0 | 0 | 200 | - | - |
| FrostDragonFX.lua | 45 | 45 | 155 | DFX.Storm @825: 39 | 25 |
| FrostDragonKillFX.lua | 26 | 26 | 174 | play @167: 60 | 48 |
| FrostDragonKit.lua | 61 | 56 | 144 | buildPiece @252: 52 | 19 |
| FrostLotusFX.lua | 27 | 27 | 173 | keyhole.check @295: 29 | 15 |
| FrostLotusKit.lua | 87 | 62 | 138 | petal @103: 43 | 6 |
| FrostbladeKit.lua | 59 | 54 | 146 | kunai @101: 45 | 12 |
| SnowGlobeFX.lua | 16 | 16 | 184 | GFX.CageStep @426: 27 | 19 |
| SnowGlobeKit.lua | 110 | 81 | 119 | flakeArms @168: 33 | 8 |
| SkinCatalog.lua | 7 | 7 | 193 | p.Seq: 16 | - |
| SpellshotSettings.lua | 28 | 13 | 187 | - | - |
| SettingsRuntime.client.lua | 67 | 55 | 145 | paint: 16 | - |
| AbilityHandler.server.lua | 93 | 92 | 108 | ShardRelease handler @818: 24 | - |
| VFXLibrary.lua (cross-ref) | 215 | 182 | 18 | cbPoseBeam @4292: 51 | - |

I checked CryoFX by hand as well: 188 `^local` lines plus 10 extra names from multi-assigns (lines 68 +2, 162 +3, 516 +1, 583 +2, 617 +1, 3232 +1) gives 198. The 18 extra declarations sit inside the `do` block at 3252 and its `for` loops, so they are scoped. Upvalues (limit 200) peak at 78. No module is at or over 200.

#### Sub-areas checked with nothing found
- checked, clean: FBX table keys. Every `FBX.X` read in CryoFX (Kit, On, LotusKit, LotusOn, Lotus, DragonKit, DragonOn, Dragon, Globe, GK, GFX, LFX, DFX, Module, LotusModule, DragonModule, Wrap, C, Bind, Lit, WrapRun, PH, AIR, Pose, STRIP, IceModel, CageSetup, Phase, CloneStep, CloneDrop, Shatter) is assigned. C/Bind/Lit/WrapRun have identity defaults (line 75), and Wrap is assigned in Start (4776) and only read behind `FBX.Wrap and` guards (446, 651, 1196, 1377, 3034, 3730).
- checked, clean: CryoFX._H keys used by FrostLotusFX, SnowGlobeFX, FrostDragonFX and FrostDragonKillFX (run, take, give, throw, burst, ripple, flashAt, fxFolder, density, thinFor, flat, smooth, easeOut, dirAt, host, serverNow, Settings, VFXLibrary, STYLE) all exist (CryoFX.lua:4747-4749). The VFXLibrary members they use (Config, Emitter, LocalCharacter, RegisterProximityFade, Wrap) exist.
- checked, clean: lexical free-name scan of every module in scope. The only undeclared or forward reference is SnowGlobeFX `shards` (P5A-06). Everything else the tool flagged was a known tool artefact, checked by hand.
- checked, clean: StudioSkin / WrapStudio / HudSkinPreview / AuroraFloor / AuroraMask / AuroraTune / FDPoseTest / StudioReduceFlashing reads. Every read is gated by `RunService:IsStudio()`: FrostbladeKit:36 and 723, FrostLotusKit:38 and 1159, SnowGlobeKit:33 and 1243, FrostDragonKit:42 and 1032, CryoWrap:929, 1220, SkinCatalog:599, CryoAurora:73, 98, 99, 734, 971, 1228, 1292, FrostDragonFX:882, FrostDragonKillFX:570. The kit `On()` functions read StudioSkin only for a model that is not a player's character, so a real player's character can never take the stand-in path. A client's attribute writes on its own character do not replicate, and no code reads them for anyone else. The staging scripts that WRITE WrapStudio on a live server are P5A-01.
- checked, clean: wraps from another Element. `ElementWrapAllowed` requires `w.Wrap == element` (SkinCatalog:460-466), the server re-checks it (SpellshotService:743), and `CryoWrap.palette()` accepts only `s.Wrap == "Cryo"` (CryoWrap:883). Unknown ids validate to Default (SkinCatalog:446-475).
- checked, clean: server-visible cosmetics. CryoFX returns before building anything on the server (58-61). The kits return before their builders on the server (FrostbladeKit:64, FrostLotusKit:58, SnowGlobeKit:54, FrostDragonKit:52). Every cosmetic part I found has CanCollide/CanQuery/CanTouch false (kitPart 426, newPlain 396, host 320, plainPart 1345, decalDisc 1368, crust 1193, mirror clone 3470, the kit meshParts, the CryoWrap plates and motes, the CryoAurora copies, the KillFX parts), so a client's Icicle Shard raycast (VFXLibrary:5289) cannot stop on any of them. AbilityHandler reads skins only for the HUD stamp on Chill (750-752). Damage, root, bolt timing (CryoTuning.MirrorCageBolts) and the Deep Freeze trigger read no skin data.
- checked, clean: the M1 release timing under Frost Lotus (Viewmodel.lua:1020-1046: the same Trigger 0.107 and the same 0.453 s as Default) and the shot's hit test (VFXLibrary:5289: a ray along the shot line, independent of the look).
- checked, clean: Deep Freeze trap visibility. The armed trap goes to the owner alone (AbilityHandler:1149, tellOwner), so no skin or wrap can make it more or less visible to an opponent.
- checked, clean: FrostDragonKit build failure falls back to Default properly: all-or-nothing, templates freed, `FD.Failed` (FrostDragonKit:871-916). This is unlike the other three kits (P5A-08).
- checked, clean: the M1 shot look falls back to the Default shard when a kit's kind is missing (VFXLibrary:5108-5133).
- checked, clean: the Blizzard whiteout and frost scoping use `Config.MayHurt` (CryoFX:2207, 2520), so allies are not whited out in team modes.

---

#### P5A-01: Temporary Aurora (and Blue-Ringed Octopus) staging scripts would wreck a live server and every client if they are enabled
> **Consolidator:** duplicate of **P1-05** (Temporary stage scripts ungated (if Enabled)). Kept here for its slice-specific detail; counted once, under P1-05.
- **Severity:** Critical (if either script is Enabled in the place)
- **Confidence:** High on what the code does; Low on whether they are enabled (manifest.json does not record Enabled/Disabled)
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua:1-18`, `game/ServerScriptService/_AuroraStage.server.lua:1-106`, also `game/ServerScriptService/_BROStage.server.lua:1-40`, `game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua:1-11`, manifest.json:24922-24930, 38155-38165
- **Trigger:** any live server with these scripts left enabled ("TEMPORARY ... remove when done", dated 2026-10-17 and 2026-10-19).
- **Why it's a bug:** None of these files checks `RunService:IsStudio()`. On EVERY client, `_AuroraStageClient` does `ch:WaitForChild("HumanoidRootPart").Anchored = true` (line 4), teleports the character to (-90,4,0) (line 5), disables every ScreenGui in PlayerGui two seconds later (line 8), and binds a render step at priority 1,000,000 that forces `CameraType = Scriptable` and pins the camera whenever the workspace attributes CamPinEye/CamPinLook are Vector3 (9-17). The server stage sets those attributes as soon as the first player spawns (_AuroraStage:69-70). The result is that every player is frozen in place, has no HUD, and has a locked camera. The server stage also clones the first player's character into `workspace.WrapStage` as an anchored Humanoid model named "Caster" with `WrapStudio = "Aurora"` (9-24, 27). That model is a server-side Humanoid that ability code scanning for humanoids could target. The stage also publishes `_G.WS`/`_G.ff`/`_G.mc` and listens to `workspace.StageCmd`. The WrapStudio attribute it writes is harmless only because every read is Studio-gated. _BROStage waits for StageReady (set by _AuroraStage:71) and adds more dummies, plus floor and sky parts.
- **Suggested fix:** Delete all four staging scripts from the shipped place, or move them under ServerStorage. If they must stay, make the first line of each `if not RunService:IsStudio() then return end`.
- **Notes:** Cross-ref the Pass covering ServerScriptService/StarterPlayerScripts hygiene. Whether they are enabled needs checking in the live place.

#### P5A-02: Snow Globe's Blizzard places large opaque pines and crescent bands INSIDE the storm, so this one skin hides players from other viewers
- **Severity:** High (competitive integrity)
- **Confidence:** Medium. The geometry and opacity are certain from the code; how much they hide in play is unverified
- **Files/lines:** `SnowGlobeFX.lua:597-680` (Storm), 613-621 (pines at `R * 0.55..0.82` inside the zone, scale 1.5-1.9), 667; `SnowGlobeKit.lua:39` (`SG.Pines = {6,4,2}`), 897-918 (PineT: tiers to y=4.6 and radius 1.8, so 8.7 studs tall and about 6.8 studs wide at scale 1.9), 920-943 (Flurry: opaque white double-sided crescent bands at 0.78-0.95 R, 2.6-10.2 studs up), 1049-1062 (a toon piece is Transparency 0 whenever shown); compare `SnowGlobeFX.lua:244` (only the rims get `fadeNear`)
- **Trigger:** any Blizzard cast by a Snow Globe wearer (Cryo, ElementSkin_Cryo = SnowGlobe), seen from any client. Up to 6 pines at High and 2 at Low (and for an enemy under Reduce Enemy VFX).
- **Why it's a bug:** The Default storm conceals with particles. This skin adds opaque, character-sized-or-larger solid meshes inside the zone with no keyhole and no proximity fade. Frost Lotus and Frost Dragon fade any piece that sits between the camera and a player (FrostLotusFX:288-328, FrostDragonFX:198-264); Snow Globe does neither. A player inside or behind a pine is invisible on every client while still hittable, because the pine has CanQuery false. The comment at SnowGlobeFX:599-601 claims "the obstruction stays at or under the Default's", but it only counts the fleck rate (cut to 70% at 628) and ignores the solid meshes. The manual (line 655) says "a skin never changes ... effect intensity".
- **Suggested fix:** Move the pines outside the Frost Line ring (as Frostblade's fence and the rims are), or give pines and flurry the same keyhole fade Frost Lotus uses, or make them translucent. Also review the Snow Globe Flash Freeze upright hero flakes (SnowGlobeFX:249-257, 4 studs across, opaque, on the rim) and the Mirror Cage hero flakes (SnowGlobeFX:379-386, 3.4x scale, opaque) and 0.84-stud ribs (SnowGlobeKit:625-651), which also have no keyhole.
- **Notes:** none.

#### P5A-03: Frost Dragon's Flash Freeze leaves a 32-stud translucent claw and forearm over the whole zone, and only the caster's own client draws it clearer
- **Severity:** High (competitive integrity: asymmetric visibility)
- **Confidence:** Medium
- **Files/lines:** `FrostDragonFX.lua:633-784` (Field), 645-657 (`s = R / CLAW.Base` = 2; the caster's own client sets `LocalTransparencyModifier = 0.6` on every claw part), 702-745 (the claw is shown from the drop until `breakTime + wave - 0.05`, about 4.9 s); `FrostDragonKit.lua:99-100` (claw Shell 0.55, Spine 0.5, Crystal 0.3), 303 (no facet rims); FrostDragonData "claw" vertex bounds x[-9.0, 9.4], y[0, 16.2], z[-8.7, 8.7] (measured), so with s = 2 it spans about ±18 studs and 32 studs tall
- **Trigger:** a Frost Dragon wearer casts Flash Freeze; any other client is in or looking across the zone during its ~5 s life.
- **Why it's a bug:** For about 5 s the whole zone sits under a large translucent mesh with opaque Neon talon edges. The comment at 651-652 says the caster's client alone draws it "60% clear instead". The caster therefore sees the trapped zone at about 0.82 effective transparency, while opponents and their teammates see 0.5-0.55 shell plus opaque glow. This is a cosmetic-only visibility advantage for the wearer. Default draws only knee-to-waist rim crystals and a floor.
- **Suggested fix:** Apply the same transparency for every viewer (lift the clear-foot treatment to all clients), or shorten the claw's hold to the slam (CLAW.Hold) and keep only the rim spines for the zone's life.
- **Notes:** none.

#### P5A-04: Frost Dragon's "frost-over" draws a fake freeze on anyone standing in the zone at cast time, including the caster's allies, before (or without) the server root
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `FrostDragonFX.lua:597-631` (`FROSTOVER = true` "(flagged: a cosmetic frost-over at the shockwave, ahead of the real root)"), 676-685 (the list `inside` is built once from every workspace-root Model with a Humanoid within R except the caster), 747-753; VFXLibrary FlashFreeze `LingerToRoot = 1.0` (VFXLibrary.lua:119)
- **Trigger:** a Frost Dragon Flash Freeze in 2v2 or Squad Clash with the caster's teammates in the zone, or any player who walks out before LingerToRoot.
- **Why it's a bug:** It plants 14 spine crystals round each body's feet at shockwave time (`leadIn + 0.15*d/R`) and holds them until the zone breaks. It ignores `Config.MayHurt` and whether the body is ever rooted, so allies and escaped players show a frozen tell on every client while they are free. That misleads both sides. The spines are placed in world space at the body's position at that instant, so a fleeing player leaves a "frozen" ring behind.
- **Suggested fix:** Drive the frost-over from the server's IceFrozenState (CryoFX.FrozenHold already exists), or filter by `Config.MayHurt(casterPlayer, victimPlayer)` and redraw on the root.
- **Notes:** none.

#### P5A-05: Frost Dragon's Blizzard cuts the Default storm wall to 40% and removes it entirely over half of the ring
- **Severity:** Medium (a cosmetic changes how much the zone hides, on every client)
- **Confidence:** High
- **Files/lines:** `FrostDragonFX.lua:892-916` (Beams disabled; wall emitters beyond 0.55 R: `em.Rate *= cut and 0 or BZ.WallKeep` (0.4), where `cut` is two ±45° pockets round the caster's side axis; inner emitters x0.6 with shortened life); `docs/SPELLSHOT_Design_Manual.md:76` ("everyone caught inside is slowed and has reduced visibility"), :655
- **Trigger:** any Blizzard cast by a Frost Dragon wearer.
- **Why it's a bug:** The wall is the storm's line-of-sight screen for players outside it. This skin removes the wall over 180° of the ring and thins the rest to 40%, so the zone hides far less than the Default. The code only checks that the dragon storm is "no heavier than the Default's" (895, 913-915). The manual says a skin never changes effect intensity. The victims' whiteout (stepHaze) is untouched, so this affects outside observers.
- **Suggested fix:** Keep the Default wall rate and move the dragons, or make only a small local hole that does not change the zone's overall concealment.
- **Notes:** This disadvantages the wearer, so it is not exploit-grade.

#### P5A-06: SnowGlobeFX.HitBloom calls `shards` before it is declared, so every Snow Globe M1 hit errors and leaks visible glass slabs
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `SnowGlobeFX.lua:86-156` (HitBloom), 112 (`shards(p, 4, 6, 70, 0.4)`), 197-198 (`local function shards` is declared below it); `CryoFX.lua:1965-1966` (`pcall(lfx.HitBloom, ...)`, the error is swallowed with no warning); `SnowGlobeKit.lua:1007-1029` (New/Get), 1049-1062 (Fade 0 makes it opaque)
- **Trigger:** every M1 hit by a Snow Globe wearer on every client (up to about 3 hits a second).
- **Why it's a bug:** Lua resolves the name lexically. Inside HitBloom (line 86) `shards` is the global `shards`, which is nil, so line 112 raises "attempt to call a nil value". By then 2-3 `Slab3` pieces have been taken and set visible (`SG.Fade(o, 0)` at 101) and the `Pile3` taken. `H.run` (114) never runs, so they are never placed or returned (`SG.Put`). Each hit leaves fresh opaque slab clones parented to the FX folder at their template CFrame (meshPart never positions them, so probably the world origin), and they accumulate for the whole session. The intended crack, slab and pile animation never plays.
- **Suggested fix:** Move `local SHARD` and `local function shards` above HitBloom (SnowGlobeFX:197-213 to before line 86), or forward-declare `local shards` at the top. Add a `warn` in the pcall in CryoFX.ShardImpact so a failing hook is visible.
- **Notes:** The other `shards` callers (Field, CageSetup, Peel, Strike, CageBurst) come after line 198 and are fine.

#### P5A-07: FBX.Shatter errors for Frost Lotus (no ShatterChunks) and Snow Globe (kind tables have no Size), so their shatters lose the chunks, bursts, ripple and flash
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `CryoFX.lua:1677-1708` (FBX.Shatter), 1684 (`frag = kit.Kind("Mote")`), 1697 (`frag.Size * ...`), 1700 (`kit.ShatterChunks[tier]`), 1719-1720 (the pcall plus warnOnce, then 1722-1724 drop and return); `FrostLotusKit.lua:51` (`FL.ShatterPiece` only, no `FL.ShatterChunks` anywhere); `SnowGlobeKit.lua:953, 963` (a kind is `{ Layers, Tris }`, no `Size`)
- **Trigger:** Frost Lotus: every Deep Freeze break (always heavy, CryoFX:2929) and every heavy Flash Freeze root shatter. Snow Globe: every heavy Flash Freeze root shatter ("GlobeFF") once one body flake is visible.
- **Why it's a bug:** For Lotus, the petal loop runs and then `kit.ShatterChunks[tier]` indexes nil. For Globe, `frag.Size` is nil and the arithmetic errors on the first petal. The pcall swallows the error, the rest of FBX.Shatter is skipped, and `if heavy then return end` (1724) also skips the Default shatter. So these skins' freezes end with only a few petals (Lotus) or nothing (Globe).
- **Suggested fix:** Add `FL.ShatterChunks = { 8, 5, 3 }`. In FBX.Shatter, read the fragment size from the kit (`frag.Size or (frag.Layers and frag.Layers[1].Size)`), or give each kit a `Kind(name).Size`. Fall back to the Default heavy shatter when FBX.Shatter fails.
- **Notes:** none.

#### P5A-08: Frostblade, Frost Lotus and Snow Globe set `Built = true` even when kinds failed to build, so the skin path suppresses the Default and draws nothing in its place
- **Severity:** Medium
- **Confidence:** Medium. The code path is certain; how often the EditableMesh budget fails in live play is not known
- **Files/lines:** `FrostbladeKit.lua:218-225, 318-329`; `FrostLotusKit.lua:597-604, 712-723`; `SnowGlobeKit.lua:211-218, 984-997` (`pcall(buildKind)` per kind, then `Built = true` unconditionally); compare FrostDragonKit.lua:871-916 (all-or-nothing). Consumers: `CryoFX.lua:1452-1510` (an FB encase draws no Default prison), 3972 (no Default panels for fbk/lfk), 4210-4234 (bolts only from `FB New("Bolt")` / `lfk.NewBolt`), `VFXLibrary.lua:2650` (`noCrystals` hides every Flash Freeze crystal), `FrostLotusFX.lua:140, 213, 421`, `SnowGlobeFX.lua:228, 509`
- **Trigger:** `AssetService:CreateEditableMesh(Async)` fails for a kind: the shared per-client memory budget is full (the lazy-build comments say four kits plus Glow-wrap vertex copies overran it before), mobile, or the EditableMesh API is unavailable. `retry` gives up after 40 x 0.25 s per call, so up to about 20 s per kind and minutes for Snow Globe's 46 kinds. Squad Clash with several different Cryo skins makes this more likely.
- **Why it's a bug:** Each kit's header promises "on any failure, every piece simply draws Default" (FrostbladeKit:16-17, FrostLotusKit:18). Once `Built` is true, `On()` is true, so the Default crystals, panels and prison are suppressed while the missing kinds return nil. Concrete results: Mirror Cage bolts are invisible (no "Bolt", "Lance" or "Dart3"), a Frostblade Deep Freeze shows only the floor and line, a Lotus or Globe Flash Freeze has no crystals and no field.
- **Suggested fix:** Use FrostDragonKit's rule: `Built = true` only if every kind built; otherwise set `Failed`, free the templates, and leave the Default. Or check per piece and fall back to the Default for any missing kind.
- **Notes:** none.

#### P5A-09: Reduce Flashing is not honoured by Cryo's light flashes or the Mirror Cage kill strobe, and Frost Dragon adds an extra ungated flash per M1 hit
- **Severity:** Medium (accessibility)
- **Confidence:** High
- **Files/lines:** `CryoFX.lua:329-352` (lightFlash and flashAt never read ReduceFlashing), callers 1707, 1734, 1812, 1994 (every M1 impact), 4272 (cage kill); 4252-4254 (`flick = 0.75 + 0.25*sin(age*61 + ...)`, about 9.7 Hz, multiplies the kill outline pulse; `calm` is applied only to the glare at 4244-4251); `FrostDragonFX.lua:555` (`H.flashAt(pos, 2.5, 8, 0.12)` on every Wyrmling hit, on top of the Default's flash at CryoFX:1994), 356 (roar flashAt); compare FrostDragonFX:713 and FrostLotusFX:691/714 and FrostDragonKillFX:390, which do read `calm`
- **Trigger:** Reduce Flashing on: Default Cryo, every wrap, and every skin that keeps the Default impact path. Frost Dragon at up to 3 hits a second gives two light flashes per hit.
- **Why it's a bug:** The settings contract (brief; manual 655: Reduce Flashing behaves exactly as in Default for skins) says flashes are damped. Here the impact flash has no damping, and the Default cage's kill outline flickers at about 10 Hz, inside the photosensitive band, whatever the setting.
- **Suggested fix:** Read `Settings.Get("ReduceFlashing")` in lightFlash and halve brightness or skip. Drop the `flick` term when calm. Gate FrostDragonFX:356 and :555 the same way.
- **Notes:** none.

#### P5A-10: No Cryo effect (Default, skin or wrap) reads Colourblind-Safe, and some wraps move Cryo's zone edge toward other Elements' hues or toward low contrast
- **Severity:** Medium
- **Confidence:** High that the setting is not read anywhere; Medium on the readability impact
- **Files/lines:** `SettingsRuntime.client.lua:296-359` (the only consumer: uniforms); `SpellshotSettings.lua:144-161` (Cryo's pair is unchanged and only Toxin moves, although the comment names the Toxin/Cryo collision); `CryoWrap.lua:48, 99, 124` (Frost Line = Main, Line at rest = `P[P.Rest or "Accent"]`); `SkinCatalog.lua:283-284` (MintRime Main #2FD4A0 mint green, Accent #064236 near-black green, no `Rest`)
- **Trigger:** Colourblind-Safe on, with an opponent wearing Mint Rime (Flash Freeze zone edge, Blizzard ring, Deep Freeze ring).
- **Why it's a bug:** `grep ColorblindSafe` finds no reader outside settings, menu and uniforms. Under Mint Rime the Frost Line, which is the zone edge (the line IS the edge, CryoTuning:25), turns mint green, the hue family the colourblind palette exists to separate from Toxin. Once the spread stops it drops to Accent #064236 (luminance about 0.05, against Default #245F9A), so the resting edge nearly disappears on dark floors. Deep Glacier explicitly sets `Rest = "Main"` for exactly this reason (SkinCatalog:290-291); Mint Rime does not. The zones keep shape cues (rim crystals), so this is not colour-only. P5A-11 covers the frozen state.
- **Suggested fix:** Give every wrap a `Rest` that keeps calm-rim contrast. Under Colourblind-Safe, draw opponents' Cryo hazards with the Default (or a fixed safe) Frost Line colour.
- **Notes:** Cross-ref the settings pass. The Default ignores the setting too, so manual 655 ("behave exactly as in Default") is technically met, but the brief requires hazards not to read only by colour.

#### P5A-11: Under a Glow wrap (Sakura Frost, Epic) the frozen crust on a body is hidden on every client, so FROZEN reads mostly by colour
- **Severity:** Medium (readability of a hard-CC state; colourblind)
- **Confidence:** High
- **Files/lines:** `CryoWrap.lua:842-845` (Glow and not Neon: `if p:GetAttribute("CryoFrost") then p.LocalTransparencyModifier = 1`), 95-97 (frozen fill, shade and rim become `P.Main` pink); `CryoFX.lua:1087-1100` (the contract: "Frozen is identified by shape first (crust, caps, ...); colour is secondary"), 1196, 1312 (`FBX.WrapRun(model, frozenLookNew)` builds the look in the wrap named by the victim's CryoWrapBy tag)
- **Trigger:** a body frozen while its `CryoWrapBy` tag is "SakuraFrost". The tag is set by a Sakura caster's Flash Freeze root, Deep Freeze, Mirror Cage, or even their Icicle Shard chill (CryoWrap:961-966). The tag persists, so later freezes (for example an Elemental Reactions freeze through IceFrozenState) are drawn in that wrap too.
- **Why it's a bug:** The crust plates, mound and head/shoulder caps (the shape cue) are hidden, which leaves the pink Highlight fill as the main frozen tell: a colour-only status read.
- **Suggested fix:** Recolour the crust (as the Solid branch does) instead of hiding it, or keep the Default crust under Glow wraps.
- **Notes:** Related: CryoWrapBy is overwritten by whoever last chilled or froze the body, including a Default shooter clearing it (CryoWrap:984-990), so the frozen look's palette is arbitrary when several Cryo players are involved. That is Low.

#### P5A-12: Reduce Enemy VFX and Graphics Quality are not applied uniformly to skin pieces, and "enemy" means anyone other than me
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `CryoFX.lua:291-301` (thinFor and density use `character ~= VFXLibrary.LocalCharacter`, so teammates count as enemies in 2v2 and Squad Clash); 2088-2092 (Frostblade nick and `lfx.Print(cf, PR)` get no caster or thin flag, so the Lotus bloom, two flutter petals and sparkle, the Globe print and star pop, and the Dragon claw print and two chips are always full at every quality); `SnowGlobeFX.lua:98` (HitBloom slabs use `SG.Tier(..., false)` and ignore `thin`); `FrostDragonFX.lua:858-921` (the Blizzard dragons are always drawn), 601-631 (frost-over always drawn); `CryoFX.lua:1902` (Frostblade's Flash Freeze edge disappears completely under Reduce Enemy VFX, whereas the Default keeps its rim clusters, VFXLibrary.lua:2650 `bare and not c.Rim`); 1805 (`CryoFX.Shatter` thins by the VICTIM, which is inverted: an enemy's shatter on me is full, my shatter on an enemy is thinned); 1757-1759 (the Flash Freeze encase has `Caster = nil` and is never thinned for an enemy caster); 4613 (the Chill crust is thinned by Reduce Enemy VFX even when I am the shooter)
- **Trigger:** Reduce Enemy VFX or Low quality with opponents wearing any Cryo skin; any team mode.
- **Why it's a bug:** The Default path thins these effects while the skins' equivalents do not, and the ally/enemy test is wrong in team modes (`Config.MayHurt` is the right test).
- **Suggested fix:** Pass `character` and `thin` into `lfx.Print`/HitBloom and use the kit tiers. Use a shared `isEnemy(character)` built on `Config.MayHurt`. Pass the caster into the Flash Freeze encase.
- **Notes:** none.

#### P5A-13: Mirror Cage stepper is not protected per hook, so one skin-hook error freezes the cage on screen and leaves its victims tinted
- **Severity:** Low
- **Confidence:** Medium. I found no concrete error trigger in the current code; this is a robustness gap
- **Files/lines:** `CryoFX.lua:518-535` (step pcalls each stepper and REMOVES it on error), 4105-4408 (no internal pcall round `lfk.BoltFrom` 4210, `lfk.NewBolt` 4213, `lfk.TimeFrom` 4219, `FBX.CloneStep` 4258, `lfk.CageStep` 4259 (Lotus and Globe; the Dragon wraps its own), `fly.Spiral.PlaceBolt` 4372)
- **Trigger:** any runtime error in a skin's cage hook (for example a kit kind half-built, see P5A-08).
- **Why it's a bug:** If the stepper is dropped, the cleanup block (4386-4405) never runs. The folder, the panels or blooms, and the `setTint` holders stay, so the trapped bodies keep the frozen tint on that client indefinitely (tints are dropped only when the model leaves, 1301).
- **Suggested fix:** pcall each skin hook inside the stepper (as FrostDragonFX.CageStep already does internally), and on any error run the cage's cleanup.
- **Notes:** none.

#### P5A-14: Frost Lotus held lotus parts in workspace leak when the character is removed mid-hold
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `FrostLotusKit.lua:1027-1074` (parts parented to `workspace`, 1051-1055; dropped only from inside FL.M1 at 1070-1072); `CastPose.lua:1789-1791, 2145` (the state is discarded as soon as the character or humanoid leaves, so FL.M1 is never called again)
- **Trigger:** a Frost Lotus wearer is removed while `FrostLotusHold` is active (it lasts up to 1 s after the last shot): quick respawn, LoadCharacter, leaving the game, or StreamingEnabled streaming the character out.
- **Why it's a bug:** HeldLotus and HeldSlot (Body, Heart, Line) stay parented to workspace at the last hand position on every client that saw it, visible and never cleaned.
- **Suggested fix:** Parent them under the character, or watch `character.AncestryChanged` / `Destroying` to `dropHold`.
- **Notes:** none.

#### P5A-15: Frostblade's Mirror Cage draws no dome at all when the caster's body is not on this client
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `CryoFX.lua:3748-3751` (`buildTemplate(caster)` is nil, so return), 3432-3434 (nil when the character is not parented or has no root), 3972 (with fbk the panels are placeholder tables), 4048-4050
- **Trigger:** Frostblade Mirror Cage cast while the caster is streamed out, dead, or not yet loaded on the viewer.
- **Why it's a bug:** The Default falls back to flat cards (3230, 4042). Frostblade has neither panels nor clones, so only the floor, clusters and lock ring draw. The bolts still fly from `pn.Pos`.
- **Suggested fix:** Fall back to the Default panels when FBX.CageSetup produces no clones.
- **Notes:** none.

#### P5A-16: KillFX wraps a function that yields in CryoWrap's global palette swap
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `FrostDragonKillFX.lua:530-534` (`W.Run(P, play, ...)`), 169-170 (`play` waits in `task.wait(0.1)` for up to 2 s while the kit builds); `CryoWrap.lua:436-476` (`begin` rewrites every registered palette table and `W.Active`, and `finish` restores them only when the function returns), 525-527 ("Never wrap a function that yields")
- **Trigger:** a Frost Dragon wearer with a Cryo wrap gets a kill on a client where FrostDragonKit is still building (just after the wearer joined or equipped).
- **Why it's a bug:** While `play` waits, the shared Look, COL, STYLE, KINDS, Blizzard, FF2 and IS2 tables (and Sakura's `Over` numbers) stay swapped. Every other Cryo effect on that client draws in the killer's wrap for up to 2 s, and `begin` refuses any other wrap (`current ~= P`).
- **Suggested fix:** Do the kit wait outside `W.Run`, then call `W.Run(P, play, ...)` only once the kit is built.
- **Notes:** none.

#### P5A-17: CryoFX is 2 locals from Luau's 200 limit
- **Severity:** Low (risk, not a current failure)
- **Confidence:** High
- **Files/lines:** `CryoFX.lua:75` (the comment "this module is at Luau's limit of 200 locals"); table above (198 live)
- **Trigger:** the next contributor adds a third top-level `local` or `local function`.
- **Why it's a bug:** Three more top-level locals is a hard compile failure of the module, which takes every Cryo effect down. VFXLibrary.lua is at 182.
- **Suggested fix:** Group helpers into tables (as FBX already does), for example fold the many `local function` helpers into `H`, which already exists as `CryoFX._H`, and add a CI check for live-local count.
- **Notes:** I found no FBX-style access to an unassigned key (see the clean list).

#### P5A-18: Wraps and skins change shot and zone geometry and intensity, which the manual forbids
- **Severity:** Low
- **Confidence:** High on what changes; Low on the gameplay impact
- **Files/lines:** `SkinCatalog.lua:321-324` (SakuraFrost Over: `IS2.Width` 0.28 against Default 0.17 at VFXLibrary.lua:4876, `IS2.BodyT`/`TipT` 0 so the shot is fully opaque, `FF2.FloorT`/`DiscT` 0, `Look.FrozenFillT` 0.3; OpaqueStyles take Slab/Floor/EncaseBase/Crack and others to opaque), 350-352 (Aurora, unreleased: `FF2.RimCount` 80 to 104, `RimH` x1.17); 309 (BlackIce: near-black solid shot body, CryoWrap:174-184/287-305); the Frost Dragon Wyrmling (FrostDragonKit:750-848, a 2.8-stud head plus 4 segments) and the Snow Globe mini-globe in place of a 0.17-wide shard; `docs/SPELLSHOT_Design_Manual.md:655`
- **Trigger:** those wraps and skins worn live (Sakura, Black Ice, Frost Dragon, Snow Globe).
- **Why it's a bug:** Manual: "A skin never changes ... effect intensity." Projectile visibility differs by cosmetic: Sakura's opaque and wider shard and the large Wyrmling are easier to see and dodge, while a near-black Black Ice body (only its tip glows) can be harder to see on dark maps.
- **Suggested fix:** Keep Width and opacity at the Default for the in-flight shot and zone floors in every wrap, or accept it and record the exception in the manual.
- **Notes:** none.

#### P5A-19: CryoWrap gates Black Ice's material on Roblox's own quality slider, not the game's Graphics Quality setting
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `CryoWrap.lua:174-178` (`UserSettings().GameSettings.SavedQualityLevel`), 181-184, 414
- **Trigger:** Graphics Quality LOW in the game's own menu while Roblox's quality is Automatic or 4 and above.
- **Why it's a bug:** The comment says "Low Graphics Quality keeps only the colour", but it reads Roblox's level, not `SpellshotSettings` GraphicsQuality or `Settings.EffectDensity`, so the game's setting is ignored for this wrap's Foil material and cage plates.
- **Suggested fix:** Use `Settings.EffectDensity >= 0.75` or `Settings.Get("GraphicsQuality") >= 3`.
- **Notes:** none.

#### P5A-20: OwnsSkin always returns true, so any client can equip the Mythic Frost Dragon or any wrap
> **Consolidator:** duplicate of **P2-06** (OwnsSkin always true: every cosmetic free). Kept here for its slice-specific detail; counted once, under P2-06.
- **Severity:** Low now (it is a documented placeholder); High as soon as skins or wraps are sold
- **Confidence:** High
- **Files/lines:** `SkinCatalog.lua:420-423`; `SpellshotService.server.lua:729-746` (the server checks only Element, list membership and OwnsSkin)
- **Trigger:** `LoadoutRequest:FireServer("ElementSkin", "Cryo", "FrostDragon")` from any Cryo player.
- **Why it's a bug:** Rarity tiers exist (Uncommon to Mythic) and the economy shipped on 2026-10-18 for Elements, but skin ownership is not checked. If skins are priced, this becomes a free-unlock exploit.
- **Suggested fix:** Before skins are sold, implement OwnsSkin against PlayerData, like `OwnedElements`.
- **Notes:** Cross-ref the economy pass.

#### P5A-21: Frost Dragon kill effect sweeps a 25-plus-stud dragon through the arena on every client
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `FrostDragonKillFX.lua:31` (`Scale = 5.0`), 215-222 (length is 5x the victim's height), 273 (no dragon only when thinned), 442 (hides the victim's body locally); `docs/SPELLSHOT_Design_Manual.md:683, 797` ("kill effects stay on the body, stay short")
- **Trigger:** a Frost Dragon kill in Squad Clash while the fight continues.
- **Why it's a bug:** For about 1.2 s a large dragon model (opaque spine, translucent shell, wings) crosses the killer's line of sight in world space, so it is visible to and occluding for everyone nearby unless they have Reduce Enemy VFX on. That contradicts the manual's "stay on the body". If the stepper errors before the end (497-526), a living dummy stays hidden (`LocalTransparencyModifier = 1`).
- **Suggested fix:** Keep the dragon close to the victim and short, or draw the swoop only on the killer's and the victim's clients.
- **Notes:** none.

#### P5A-22: Each skin's visible zone rim sits outside the real zone edge
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `CryoFX.lua:2340` (Frostblade fence at R + 1.4, 16 x 9-stud kunai), `SnowGlobeFX.lua:235` (Flash Freeze rim at R + 0.3), 604 (Blizzard rim at R + 0.25), `FrostDragonFX.lua:674` (spines at R + 1.6), 919 (dragons at R + 3)
- **Trigger:** Blizzard or Flash Freeze cast with any of these skins.
- **Why it's a bug:** The most prominent solid edge sits 0.25-1.6 studs outside the real boundary (the Frost Line, which is still drawn), so a player reading the solid wall misjudges where the slow or root zone ends.
- **Suggested fix:** Put the skin's rim on or inside the Frost Line radius.
- **Notes:** none.

#### P5A-23: Doc drift in the Cryo cosmetics
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `SkinCatalog.lua:266-275` (Snow Globe is Rare) against `SnowGlobeKit.lua:4`, `SnowGlobeFX.lua:4` and `CryoFX.lua:139`, which all say Epic; `SkinCatalog.lua:262` (Frost Lotus is Epic) against `FrostLotusKit.lua:4` (Rare); `SkinCatalog.lua:275-277` (Frost Dragon "IN BUILD -- stage 1 ... its other pieces draw the Default"), while FrostDragonFX implements Mirror Cage, M1, Flash Freeze, Blizzard, Cold Momentum and Deep Freeze (stages 1-4) plus a kill effect; `CryoWrap.lua:4-7, 17` ("the skins ... are never touched", "The frozen-body status colours stay Default"), while the code paints skin pieces (PaintKit, 808-872) and recolours the frozen fill, shade and rim (61, 95-97); FrostDragonKillFX against manual 683 and 797; `CryoFX.lua:40-41` ("Everything goes through the Graphics Quality / Reduce Enemy VFX scaling"), which P5A-12 contradicts.
- **Trigger:** n/a.
- **Why it's a bug:** The code and the docs disagree, and the code ships.
- **Suggested fix:** Update the catalog and module headers, and the manual (v0.25 is already flagged in the diary).
- **Notes:** none.

#### Could not complete
- Whether `_AuroraStage`, `_AuroraStageClient`, `_BROStage` and `_BROStageClient` are Enabled in the place (manifest.json does not record it). This decides whether P5A-01 is live.
- Actual on-screen obstruction (P5A-02 and P5A-03) and the template CFrame of the leaked Snow Globe slabs (P5A-06) cannot be confirmed without Studio.
- I read FlashFreezeData.lua and FrostDragonData.lua as data (structure plus measured bounds), not line by line, because they are generated numeric blobs. I read FrostLotusKit.lua lines 110-590 (pure geometry) at skim depth only.

### Pass 5, slice B: skins/wraps layering + settings honouring (PYRO, TERRA, TOXIN client VFX)

The cosmetics in scope, as SkinCatalog lists them:
- **Pyro:** `AzureFlame`, offered per ability (`Offer.Pyro`, 8 abilities: Fireball, Immolate, EmberRefund, RingofFire, HeatRush, Detonate, CinderShield, ScorchingLash). Drawn only by PyroDraw (the "flame" look).
- **Terra:** `ObsidianMagma`, offered per ability (`Offer.Terra`, 6 abilities). TerraWrap draws it for BoulderShot / BulwarkCharge / Bedrock; ChargedRock tints draw it for Aftershock / BulwarkWall / EarthenTomb.
- **Toxin:** Element wraps (`ElementWraps.Toxin`): `Nightshade`, `CoralSnake`, `PoisonDartFrog`. `BlueRingedOctopus` is defined in `Skins` but is not in `ElementWraps`, so only a Studio `WrapStudio` dummy can show it.
- **Element skins:** none of the three Elements has an `ElementSkins` entry, so no `"<Skin>+<Wrap>"` id can arise for them.

#### Files read (complete list)
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua: fully
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua: fully
- game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua: fully
- game/ReplicatedStorage/IceMagic/ToxinTuning.lua: fully
- game/ReplicatedStorage/IceMagic/ToxinWrap.lua: fully
- game/ReplicatedStorage/IceMagic/ToxinClient.lua: fully
- game/ReplicatedStorage/IceMagic/ToxinFX.lua: fully (1-2148)
- game/ReplicatedStorage/IceMagic/TerraWrap.lua: fully
- game/ReplicatedStorage/IceMagic/TerraFX.lua: fully (1-4433)
- game/ReplicatedStorage/IceMagic/TerraFX_Wall.lua: fully
- game/ReplicatedStorage/IceMagic/TerraFX_Tomb.lua: fully
- game/ReplicatedStorage/IceMagic/ChargedRock.lua: fully
- game/ReplicatedStorage/IceMagic/PyroFX.lua: fully (1-2523)
- game/ReplicatedStorage/IceMagic/PyroFlame_Fire.lua: fully
- game/ReplicatedStorage/IceMagic/PyroDraw.lua: lines 1-1649 and 2045-2132 read; 1650-2044 (the kit builders: hand_flame, wisps, burst, pillar, wildfire, big_blast) checked by grep for wrap / flash / density / flick only
- game/ReplicatedStorage/IceMagic/PyroFlame_Ring.lua: lines 1-750 and 1080-1206 read; 750-1080 (frame builders) checked by grep (dim / FlashDim / lights / own / density)
- game/ReplicatedStorage/IceMagic/PyroFlame_Tech.lua: lines 1-140, 360-440 and 1370-1484 read; the rest by grep (Play / own / Density / ReduceFlashing / Settings)
- game/ReplicatedStorage/IceMagic/PyroPoseTable.lua: lines 1-60 and 90-302 (the header's dropped-key list 60-90 not read)
- game/ReplicatedStorage/Spellshot/AftershockKitData.lua, BulwarkWallKitData.lua, EarthenTombKitData.lua: partially (headers, top-level structure, field names; generated numeric rows not read line by line)
- game/ServerScriptService/TerraTestServer.server.lua: fully
- game/StarterPlayer/StarterPlayerScripts/TerraTestHarness.client.lua: fully
- game/ServerScriptService/TerraHandler.server.lua: partially, lines 30-80 (Skin stamping on broadcasts), 505-560 (wall raise), 600-612; every `broadcast(` line grepped
- game/ServerScriptService/ToxinHandler.server.lua: partially, lines 270-300, 340-400, 455-600, 690-768; every Wrap / Skin / Studio / broadcast line grepped
- game/ServerScriptService/PyroHandler.server.lua: partially, lines 666-745 (Ring of Fire); Skin / Wrap / Studio grepped (none found)
- Followed into: game/ServerScriptService/SpellshotService.server.lua 700-760 (Skin / ElementSkin / ElementWrap requests); game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua 30-35, 557-600, 720-807, 923-941, 961; game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua 875-885, 1585-1640; game/ReplicatedStorage/IceMagic/VFXLibrary.lua (density / thin helpers, 994-1872 by grep, 1385-1545); game/ReplicatedStorage/Spellshot/SpellshotConfig.lua 196-203 (AddUnhurtable / MayHurt); game/ServerScriptService/_BROStage.server.lua (fully); game/ServerScriptService/_AuroraStage.server.lua 1-80; game/manifest.json (FireMagicMeshes, EarthMagicMeshes, SkinCatalog attributes, Workspace attributes)

#### Top-level local counts (Luau limit 200 per function)
I measured these with a tokenizer-based counter (scratchpad tools/locals.py). Each `local a, b, c` counts every name, and so does each `local function`. The counter does not count locals inside `do` blocks or loops at chunk level as top-level; "peak" includes them while they are live. I spot-checked it against `grep -c '^local '`: TerraFX gives 173 lines → 180 names (multi-name lines), and CryoFX comes out at 198, matching the brief.

| Module | top-level local names | peak live in chunk | headroom |
|---|---|---|---|
| IceMagic/TerraFX.lua | **180** | 180 | 20 |
| IceMagic/PyroDraw.lua | 137 | 137 | 63 |
| IceMagic/PyroFX.lua | 108 | 115 | 85 |
| IceMagic/ToxinFX.lua | 102 | 102 | 98 |
| IceMagic/PyroFlame_Ring.lua | 96 | 96 | 104 |
| IceMagic/PyroFlame_Tech.lua | 95 | 95 | 105 |
| IceMagic/TerraFX_Tomb.lua | 87 | 87 | 113 |
| IceMagic/TerraFX_Wall.lua | 84 | 84 | 116 |
| IceMagic/PyroFlame_Fire.lua | 75 | 75 | 125 |
| IceMagic/TerraWrap.lua | 28 | 28 | |
| IceMagic/ChargedRock.lua | 16 | 16 | |
| IceMagic/ToxinClient.lua | 15 | 20 | |
| IceMagic/ToxinWrap.lua | 10 | 10 | |
| IceMagic/PyroPoseTable.lua | 6 | 6 | |
| IceMagic/ToxinTuning.lua | 2 | 2 | |
| Spellshot/SkinCatalog.lua | 7 | 7 | |
| Spellshot/SpellshotSettings.lua | 13 | 13 | |
| Spellshot/AftershockKitData / BulwarkWallKitData / EarthenTombKitData | 0 / 2 / 0 | | |
| SettingsRuntime.client.lua | 47 | 55 | |
| TerraTestHarness.client.lua / TerraTestServer.server.lua | 16 / 3 | 16 / 8 | |
| PyroHandler / TerraHandler / ToxinHandler (server) | 78 / 88 / 60 | 83 / 93 / 60 | |
| (reference) IceMagic/CryoFX.lua | 198 | 198 | 2 |

No nested function in these files comes near 200; the largest is about 70 live in TerraHandler. None of the three Elements uses a per-skin overflow table like CryoFX's `FBX`, so a missing overflow table cannot cause a compile failure here. ToxinFX does have per-wrap branches keyed on fields of `T.Bands`, and some read keys that no wrap ever sets (P5B-12).

#### Sub-areas checked with nothing found
- checked, clean: **Luau 200-local limit** in all slice-B modules (table above). TerraFX's 180 is the only one within 20; it is not over.
- checked, clean: **composite "<Skin>+<Wrap>" ids** for Pyro/Terra/Toxin. `ElementSkins` has no entry for these Elements, so `SkinCatalog.Chosen` (SkinCatalog.lua:493-507) never builds a composite for them. `Resolve` (552-581) on a forged composite falls back safely: `Split` gives `Default`, which is allowed, and `WrapsOverSkin(ObsidianMagma/AzureFlame)` is false because neither has `Stops`, so the result is `Resolve(Default)` = nil. `d.Skin` is stamped by the server (TerraHandler.server.lua:53-60), so a client cannot forge it.
- checked, clean: **StudioSkin / WrapStudio reachability.** ToxinWrap reads `WrapStudio` only for a non-player model and only when `RunService:IsStudio()` (ToxinWrap.lua:38-41). TerraFX, TerraWrap, ChargedRock, PyroFX, PyroDraw and the PyroFlame_* modules read no Studio attribute at all. A client setting an attribute on its own character does not replicate, so other clients never read it. (The staging scripts that set `WrapStudio` on live servers are in P5B-15.)
- checked, clean: **cosmetics → server state.** No server handler reads a skin or wrap. TerraHandler only stamps `data.Skin` on BoulderShot/BulwarkCharge broadcasts. PyroHandler and ToxinHandler have no skin reads. Every wrap-built MeshPart is Anchored, CanCollide false, CanQuery false, CanTouch false (TerraWrap.lua:182, PyroDraw.lua:474-481/652-658, ToxinFX.lua:1108). TerraFX_Wall draws over the server's invisible body without changing it. Hit tests and damage are independent of the look and of any wrap.
- checked, clean: **server validation of cosmetic requests** ("Skin", "ElementSkin", "ElementWrap", SpellshotService.server.lua:717-746). Each checks the Element is the player's own, the id is allowed, and `OwnsSkin` agrees. `OwnsSkin` is always true for now; ownership and economy belong to another pass.
- checked, clean: **ToxinWrap palette swap cannot leak into another caster's draw.** The swap is synchronous inside `pcall(f, d)` and no ToxinFX handler yields: `skinOf`'s async part runs in `task.spawn`, and the Vent's delayed threads are in SKIP. Every swapped key is restored, even when the handler errors (ToxinWrap.lua:56-67). The reverse problem, deferred draws losing the wrap, is P5B-11.
- checked, clean: **Default fallback for TerraWrap and PyroDraw wraps.** TerraWrap.Get wraps the whole build in pcall and returns nil while building or after a failure, which makes the cast draw Default; it retries after 5 s (TerraWrap.lua:557-575). PyroDraw.wrapRec builds in a pcall'd task and returns the Default mesh record until the copy exists, and forever if the build failed (PyroDraw.lua:609-639).
- checked, clean: **Ring of Fire flame look.** The HOT line is drawn at radius × HotReach, where the server burns (PyroFlame_Ring.lua:74, 1109-1114). The line is drawn first, so it is the last thing the part cap drops, and it is never removed inside the camera pocket (PyroFlame_Ring.lua:736-744). The toon look is wrong (P5B-01).
- checked, clean: **Reduce Flashing honoured** on Detonate's blast and word (PyroFX.lua:1765, PyroFlame_Tech.lua:722), on Fire.Burst / Immolate cast flash (PyroFlame_Fire.lua:380, 582), on Ring flame-look lights (PyroFlame_Ring.lua:95, 266-291), on the Terra bloom kick, hit flash and tomb blast (TerraFX.lua:1420, 1580, 3384), on Tomb rework levels (TerraFX_Tomb.lua:955-961), and on the Toxin Epic wrap pulse (ToxinFX.lua:315, 406). The gaps are in P5B-05.
- checked, clean: **Cinder Shield haze blur** uses `Config.MayHurt` to decide whose haze can blur you (PyroFX.lua:1020-1022). Team scoping is correct here; P5B-06 is about the paths that do not do this.
- checked, clean: **PyroFX ENTRY wrapper picks the caster correctly** for every entry. FireFireball's `exclude[1]` is the thrower at both call sites (AbilityFX.client.lua:32-35, 282; SpellshotInput.client.lua:1355).
- checked, clean: **TerraTestServer is not client-reachable.** It triggers on Player attributes, which only the server can set in a replicating way.
- checked, clean: **TerraWrap EditableMesh slot accounting** on the error path. The `parallel` wrapper returns each coroutine's held slots (TerraWrap.lua:146-160).

---

#### P5B-01: Toon-look Ring of Fire draws a HOT ring 3.5 studs smaller than the area the server burns
> **Consolidator:** canonical entry for: Toon-look Ring of Fire drawn smaller than burn area (doubly conditional). Canonical severity **Medium** (this entry said High).
- **Severity:** High (competitive integrity: the telegraph is smaller than the damage area), conditional on the toon look being active
- **Confidence:** Medium. The code path is certain; how often the toon look is live depends on the place.
- **Files/lines:** `game/ReplicatedStorage/IceMagic/PyroFX.lua:1277-1303, 1326-1345` (toon RingOfFire: line, seal and eruption all at `radius`); `game/ServerScriptService/PyroHandler.server.lua:686-710` (`reach = radius * (hot and R.HotReach or 1)` = 21, hitting anything with flat distance ≤ reach); `game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua:562` (passes `d.Radius` = 17.5 and `d.Hot`); `game/ReplicatedStorage/IceMagic/PyroFlame_Ring.lua:74, 1109-1114` (only the flame look draws at reach)
- **Trigger:** Pyro casts Ring of Fire with Heat ≥ `HotHeat` (0.67) while a viewer's client is on the toon look. That happens when ReplicatedStorage attribute `PyroLook = "toon"`, when `flameLibs()` fails (a flame module missing, or `PyroDraw.Ready()` false because any of the 45 PF_ meshes is missing or mis-sized: PyroFX.lua:2335-2381), or when a flame `RingOfFire` call errors (`viaFlame` falls back: PyroFX.lua:314-324).
- **Why it's a bug:** The server damages the whole disc out to 17.5 × 1.2 = 21 studs for 75 damage plus a burn (`hot and R.HotDamage`). The toon draw places every trace segment at `center + (cos a * radius, 0, sin a * radius)` with `radius` = 17.5, ignores `hot` for placement, and scales the seal and eruption by `k = radius / R.DrawnRadius`. A player standing 17.5–21 studs out sees themselves outside the fire and is hit anyway. The flame look was fixed for this (`HotLineAtReach = true`, "where the fire really ends"); the toon look, which is the live fallback, was not.
- **Suggested fix:** In the toon RingOfFire, use `radius * (hot and R.HotReach or 1)` for the segments, the seal scale and the eruption width. Better, have both looks take the reach from one function that PyroHandler also uses.
- **Notes:** The manifest shows `FireMagicMeshes` with 97 MeshParts in total, but the export collapses the `Flame` sub-folder (`summary` only), so whether all 45 PF_ meshes are present is unverifiable. If they are, the flame look is the default (`PyroFX.Look = "flame"`) and this fires only on fallback.

#### P5B-02: Colourblind-Safe never reaches any Pyro, Terra or Toxin effect, or any of their wraps; it only repaints uniforms
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:296-359` (the only applier: torso/sleeve/hand paint); `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:144-161, 311-315` (the safe pairs: Terra→violet, Toxin→teal); a repo-wide grep for `ColorblindSafe|ElementColor(` finds no IceMagic module. Hazards affected: `ToxinFX.lua:1392-1403` (Corrosive Cloud), `1968-2050` (Acid Rain), `1510-1722` (Patient Zero aura and blast), `2052-2139` (Corroded rim); `TerraFX.lua:3964-4013, 4194-4208` (Aftershock underlay; Neon magma under the wrap); `TerraFX_Tomb.lua:971-984` (fissure gap); `PyroFX.lua:1277+` / `PyroFlame_Ring.lua` (Ring of Fire)
- **Trigger:** Any viewer with Colorblind-Safe on, any mode. This applies to every Pyro/Terra/Toxin effect and to every wrap: AzureFlame, ObsidianMagma, Nightshade, CoralSnake, PoisonDartFrog (and BlueRingedOctopus in Studio).
- **Why it's a bug:** The setting exists to separate the two colliding pairs: "Pyro/Terra (both warm, and Terra reads as Pyro to a protan) and Toxin/Cryo". The VFX never use the safe palette, so on the field the collision remains for exactly the Elements it was meant to fix. The ObsidianMagma wrap makes it worse: its fissures, seams and magma underlay are `#E5231B / #FF7A1A / #E07A18`, which is Pyro's fire ramp (SkinCatalog.lua:45-71). That is the protan Pyro/Terra collision on purpose. No wrap palette has a colourblind variant, so every wrap palette also drops it.
- **Suggested fix:** Decide what the safe mode means for VFX. Either give each hazard a shape cue that does not depend on colour (a ground ring for Acid Rain and Corrosive Cloud, an outline on the Tomb fissure), or add a per-Element safe tint that every FX module and wrap palette honours, with an override in each wrap (e.g. `Palette.Safe`).
- **Notes:** The brief's rule is that colour must never be the only way a hazard reads. Toxin's cloud and rain read by shape as well, so this is not proof that any hazard is colour-only. The finding is that the setting has no VFX path at all for these Elements and wraps.

#### P5B-03: Wraps repaint hazards in other Elements' identity colours (Element misread)
- **Severity:** Medium (competitive readability; the shapes and telegraphs themselves are unchanged)
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:80-85` (AzureFlame: azure / aqua / white, lights `#7FD0FF`, i.e. Cryo/Aqua); `37-72` (ObsidianMagma: Pyro's magma ramp on Terra rock); `115-133` (CoralSnake: "a yellow halo over red tints the whole cloud orange: the fire read", red/black gas reads as Pyro); `135-161` (PoisonDartFrog: cobalt gas `#2F55D6`, reads as Cryo/Aqua); `95-113` (Nightshade: violet gas, reads as Umbra's violet); drawn by `PyroDraw.lua:571-650, 903, 1077`, `TerraWrap.lua`, `ToxinWrap.lua:52-68`
- **Trigger:** An opponent wearing one of these wraps casts a hazard: Ring of Fire (55/75 damage + burn), Corrosive Cloud (DoT zone), Patient Zero mass, Aftershock (Neon magma gaps).
- **Why it's a bug:** In this game counter-play depends on reading the Element: Cryo means slow/freeze, Toxin means DoT and Corroded, Pyro means burn. A Corrosive Cloud in cobalt or a Ring of Fire in azure and white reads as a Cryo or Aqua field. The catalog even notes Coral Snake's fire read and avoids "Toxin's green" for Cryo's Mint Rime, so the team knows about cross-Element colour confusion, but the hazards keep no Element-invariant cue (shape, edge or icon).
- **Suggested fix:** Keep an Element-invariant read on hazards under every wrap: an un-wrapped edge or ground ring in the Element's identity colour, or keep the hazard's boundary pieces (Toxin skirt lobes, the Ring's line) in Default colours. At the least, treat this as part of wrap approval.
- **Notes:** I found no case where a wrap makes a telegraph less visible (lower luminance or contrast); see P5B-08 for the one dark-wrap visibility risk.

#### P5B-04: Default Toxin effects ignore Graphics Quality and Reduce Enemy VFX; only wrap "extras" scale. Pyro's toon-only Heat Rush and Cinder Shield are never thinned
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ToxinFX.lua:303-317` (`extraScale`, the only `EffectDensity`/`ThinEnemyVFX` read in the file, used only on wrap extras); unscaled Default emitters and part counts at `600-621` (lobe smoke), `780-803` (patch, skirt, glow), `1135-1151` (bubble smoke), `1670-1685` (Patient Zero wave: 40 lobes), `1985-2028` (Acid Rain cloud and 38 globs/s), `479-500` (drops), `941-965` (threads); `game/ReplicatedStorage/IceMagic/PyroFX.lua:805-906, 1077-1167` (Heat Rush and Cinder Shield are toon-only, with no density read; only toon FireFireball's ember rate reads it, at 614)
- **Trigger:** A viewer on LOW or MEDIUM Graphics Quality, or with Reduce Enemy VFX on, watching any Default Toxin cast, any Heat Rush, or any Cinder Shield. Pyro's toon look also applies whenever the flame look falls back (see P5B-01).
- **Why it's a bug:** SettingsRuntime documents Graphics Quality as "an effect-density multiplier the VFX library applies to every emitter it builds" (SettingsRuntime.client.lua:20-21, 136-151). ToxinFX builds all of its emitters itself with fixed `Rate`/`Emit` counts, so the setting never reaches them. Reduce Enemy VFX has no effect on a Default Toxin opponent at all. Pyro, Terra and every Toxin wrap do honour both settings.
- **Suggested fix:** Pass ToxinFX's emitter rates, `Emit` counts and part counts (lobes, globs, drops) through one density helper (`EffectDensity × (ThinEnemyVFX and not own and 0.5 or 1)`, with "own" decided as in P5B-06). Keep each hazard's boundary pieces at full strength. Do the same for Heat Rush lines and auras.
- **Notes:** Inconsistency in the ULTRA tier (density 1.15): PyroDraw and ToxinFX's extraScale clamp it to 1, while Terra uses it raw (more Aftershock rocks). This is Low and only a consistency note.

#### P5B-05: Reduce Flashing is ignored on several Pyro/Terra/Toxin strobes, including a 4.6 Hz telegraph pulse
> **Consolidator:** canonical entry for: Reduce Flashing ignored by Pyro/Terra/Toxin strobes (incl. all PyroDraw). Also reported as **GC-10**.
- **Severity:** Medium (accessibility; 3–30 Hz is the photosensitive band)
- **Confidence:** High
- **Files/lines:**
  - Toxin: `ToxinFX.lua:1503-1508, 1601-1631`. Patient Zero's Virulence pulse accelerates to `PulseTo` 4.6 Hz, driving PointLight brightness from 0.15 to 1.75 plus glow-sprite transparency, with no Settings read in H.ToxinPZMark.
  - Toxin: `1654-1664`, the Patient Zero burst flash (light 4, range 1.5R).
  - Toxin: `1303-1308`, the bubble burst light 1.3.
  - Toxin: `2101-2103`, the Corroded rim pulsing at 0.8 × 1.55^(stacks−1), about 3 Hz at 4 stacks.
  - Toxin: `1945-1948`, the Vent grille flash on each absorption.
  - Toxin: `2008`, the Acid Rain glow at 1.2 Hz.
  - Pyro: `PyroDraw.lua:285-289, 1668-1669, 1726, 1788, 1892, 1952-1954`. `flick()` (±17% at 10 and 7.5 Hz) runs on every Fireball, hand flame, burst and pillar light regardless of the setting. Only PyroFlame_Ring passes `t = nil` under FlashDim (`PyroFlame_Ring.lua:266-268`). Fire.Burst drops only the core flash (`PyroFlame_Fire.lua:380`).
  - Pyro toon: `PyroFX.lua:1342`, Ring of Fire variants swapping at `FlickerRate` 18 Hz, plus the seal flash.
  - Terra: `TerraFX.lua:1802-1803`, the Boulder flight seam flicker `sin(now*90)` (14 Hz).
  - Terra: `734-752`, the crack-tier and full-charge flares (+3.0 glow for 0.14–0.16 s).
  - Terra: `ChargedRock.lua:45-55, 277-315` with `TerraFX_Wall.lua:645-653, 723-734`. The wall's hit flare (0.6) and break flare (0.8) plus the 0.8 Hz ±15% pulse are not damped. The Tomb rework halves its levels at TerraFX_Tomb.lua:955-961; the Wall does nothing.
- **Trigger:** Reduce Flashing on, any mode. Patient Zero is the worst case: a telegraph pulse that speeds up to 4.6 Hz before the fuse.
- **Why it's a bug:** The setting is meant to damp pulses and flashes wherever an effect is drawn. These paths never read it, while sibling paths in the same modules do (Detonate, Ring flame look, Terra bloom/hit flash, Tomb).
- **Suggested fix:** Under Reduce Flashing: hold the Patient Zero pulse at a steady level, or cap it at about 1 Hz with reduced amplitude, and keep the fuse readable through size or shape. Pass `t = nil` to `fire_light` in PyroDraw, as the Ring does. Drop the Boulder flicker and tier flares to a steady stage glow, which is what the wrap already does (`TerraFX.lua:773-805`). Multiply the Wall's `AfterHit`/`AtBreak` levels by 0.5 and hold the ChargedRock pulse.
- **Notes:** None.

#### P5B-06: "Reduce Enemy VFX" thins allies (and some of your own effects) in 2v2 and Squad Clash
> **Consolidator:** duplicate of **P5F-06** (Reduce Enemy VFX thins teammates ("enemy" = not me)). Kept here for its slice-specific detail; counted once, under P5F-06.
- **Severity:** Medium (team modes lose ally information; the setting does not match its name)
- **Confidence:** High
- **Files/lines:**
  - `PyroDraw.lua:406-416` (`if settingsLib.ThinEnemyVFX and not own`, where own = local player's), used by every flame canvas.
  - `PyroFX.lua:614`, `PyroFlame_Fire.lua:458`.
  - `TerraFX.lua:1968-1969, 2403-2404, 2595, 3011, 3107, 4312` (`thin = not own`).
  - `AbilityFX.client.lua:738` (others' boulders always `Thin = true`).
  - `TerraFX_Wall.lua:1314`, `TerraFX_Tomb.lua:711` (`character ~= me and not Mine`).
  - `ToxinWrap.lua:59` + `ToxinFX.lua:314` (`T.Mine`).
  - `PyroFlame_Tech.lua:1444` (burn flames: `own = false` always, so the burn on your own body, and the burn your own Lash left on an enemy, are thinned as "enemy").
- **Trigger:** 2v2 or Squad Clash, viewer with Reduce Enemy VFX on, a TEAMMATE casts anything (Ring of Fire, Aftershock, Corrosive Cloud, Bulwark Wall...).
- **Why it's a bug:** Every module's test is "not the local player", not "an opponent". Allies' effects lose 40–50% of their pieces and lights: the Ring's canvas cap at LOW plus thinning is about 30% of 260 parts. The correct helper already exists and is used once: `Config.MayHurt(caster, me)` (PyroFX.lua:1020-1022, SpellshotConfig.lua:196-203).
- **Suggested fix:** Replace `own`/`not own` in the thinning decision with `not Config.MayHurt(casterPlayer, LocalPlayer)` meaning "not an enemy", and keep `own` only where first-person framing matters. Pass a real `own` for burns (the caster's Lash, or the body is yours).
- **Notes:** Cross-ref Pass 5 slice A for the other Elements' equivalent.

#### P5B-07: Earthen Tomb rework's fissure telegraph is a 0.10–0.24-stud sliver with no head and no target marker, and LOW + Reduce Enemy VFX removes the rest
- **Severity:** Medium (a hazard you must jump; competitive readability)
- **Confidence:** Medium (the dimensions are certain from code; how visible it is on screen was not measured)
- **Files/lines:**
  - `game/ReplicatedStorage/IceMagic/TerraFX_Tomb.lua:111-117` (GapFrom 0.10, GapTo 0.24, dark `Void`).
  - `971-984` (`addSegment`: a 0.06-tall dark bar, plus `puff("Landing",1)` and `puff("Grit",2)`).
  - `646-673` (`n = floor(count × EffectDensity × (Thin and ThinEnemyVFX and 0.5 or 1) + 0.5)`).
  - `1083-1132` (castStep: no head piece, no warning mark).
  - Compare the old look `TerraFX.lua:3017-3021, 3065-3072` (TR_Tomb_CrackHead plus a target "Mark" growing from MarkFrom 1.4 to MarkTo 3.6 studs).
- **Trigger:** An opponent casts Earthen Tomb with the rework in place (TerraTomb2 kit + EarthenTombKitData + ChargedRock all present, which the manifest shows: `EarthMagicMeshes/TerraTomb2`, 530 MeshParts). The viewer is the target or an ally, on LOW graphics, optionally with Reduce Enemy VFX.
- **Why it's a bug:** The mechanic is "a fissure homes on them (jump it, or be caught)" at 60 studs/s. In the rework the only visible fissure is a dark line 0.10–0.24 studs wide trailing behind an invisible head. At LOW (density 0.45) the per-segment `Landing` puff rounds to 0 and `Grit` to 1. With thinning both round to 0. Nothing marks the target's feet until the split at arrival. The old look's head and growing mark ("this is about to reach you") were dropped in the port.
- **Suggested fix:** Draw the head (one charged-rock piece or the old TR_Tomb_CrackHead) and a target-side marker, floor the telegraph puffs (`max(1, …)`) or exempt them from thinning, and widen the gap.
- **Notes:** Shakes (`ShakePlant`, `ShakeArrive`) partially telegraph it, but they scale with the Camera Shake setting, which can be 0.

#### P5B-08: The Obsidian Magma boulder's visibility rim is a Highlight, subject to Roblox's on-screen Highlight cap
- **Severity:** Medium (competitive: a darkened projectile can lose its silhouette)
- **Confidence:** Low (depends on how many Highlights are live on a client)
- **Files/lines:** `game/ReplicatedStorage/IceMagic/TerraFX.lua:1029-1040` (the rim exists because "a dark rock stays visible -- and dodgeable -- on dark ground and in shadow"); `1931-1946` (`slab()`: one Highlight per spike, 7 per Bulwark hit); `2246-2253` (Part-fallback plates); other Highlight makers: UmbraFX, CryoFX, RadiantFX_Hand, CascadeFX (grep)
- **Trigger:** An opponent throws an ObsidianMagma Boulder Shot while the viewer already has many Highlights active (an Umbra Eclipse reveal, Bulwark hits, other kits).
- **Why it's a bug:** The wrap darkens the projectile to violet-black (`Rock` #14101C to #4A3E5E × RockTint 0.62) and depends on the pale rim for readability. Roblox renders only a limited number of Highlights at once (about 31) and silently drops the rest, so the safeguard is not guaranteed.
- **Suggested fix:** Bake the rim into the wrapped mesh. TerraWrap already bakes a highlight and an ink hull into the same mesh (TerraWrap.lua:239-297); add an outer pale hull there. Or keep the rock's mid band lighter than the darkest ground.
- **Notes:** Unverifiable from a static snapshot.

#### P5B-09: ToxinFX's EditableMesh "skin" build is only partly pcall'd, and runs synchronously in the broadcast handler
- **Severity:** Low (Medium if the EditableMesh calls ever throw on a device)
- **Confidence:** Low
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ToxinFX.lua:1030-1114` (only `CreateEditableMesh()` is in pcall at 1038; AddVertex, AddNormal, AddColor, AddTriangle, SetFaceNormals and SetFaceColors at 1079-1104 are not); callers `1123-1124` (makeBubble, before `model.Parent` is set at 1152) and `578-588` (newLobe inside newCumulus, after the cloud folder is parented at 745)
- **Trigger:** The first PoisonDartFrog bubble on a client (`Bands.Skin`, 31×60 grid), or any BlueRingedOctopus bubble or cloud (`Bands.Skin` 64×128 plus five `LobeSkin` 40×80 meshes, built on the first bubble), where an EditableMesh call errors.
- **Why it's a bug:** An error escapes into W.Run, which re-raises after restoring the palette, and ToxinClient then warns once. For a bubble, the model is never parented, so that M1 projectile is invisible on this client. For a cloud, `clouds[d.Id]` is never set, so the Corrosive Cloud damage zone is not drawn at all, and the half-built folder of transparent lobes stays in the FX folder forever. The `bucket[key] = false` set first means later casts fall back to the plain ball, so the fallback works only after one invisible cast. Even without errors, roughly 100k EditableMesh calls for the BRO set run inside one handler: a frame hitch on the first wrapped bubble.
- **Suggested fix:** Put the whole build in pcall, or build in a `task.spawn` with `task.wait()` between rows as TerraWrap does. Return nil (plain ball) until the template exists.
- **Notes:** BlueRingedOctopus is Studio-only today (not in `ElementWraps`); PoisonDartFrog is live.

#### P5B-10: ToxinFX keeps resizable EditableMeshes alive for the session, which can starve TerraWrap's builds
- **Severity:** Low
- **Confidence:** Low (relies on TerraWrap's own measured "8 resizable meshes" limit)
- **Files/lines:** `ToxinFX.lua:1037-1112` (`AS:CreateEditableMesh()` (resizable), referenced by the MeshPart's content for good); `TerraWrap.lua:128-170` ("Only a handful of RESIZABLE meshes may exist at once in-experience (8, measured…)", SLOTS 3, `retry` gives up after about 10 s), `565-573` (a failed build retries after 5 s, forever)
- **Trigger:** One client sees a PoisonDartFrog bubble (1 resizable) and, in Studio, a BRO one (6 more), then a Terra with ObsidianMagma appears. CryoWrap and Aurora's own editable use, not checked here, adds to the count.
- **Why it's a bug:** TerraWrap converts each build to fixed-size and destroys the resizable mesh precisely because of this budget. ToxinFX does not, so its meshes count against the budget permanently. TerraWrap can then fail with "EditableMesh budget: gave up" and draw Default, rebuilding every few seconds.
- **Suggested fix:** Copy ToxinFX's built meshes into fixed-size ones (`CreateEditableMeshAsync(Content.fromObject(em), {FixedSize = true})`) and destroy the resizable original, as `TerraWrap.makePart` does.
- **Notes:** None.

#### P5B-11: Toxin wrap colours apply only to what a handler draws synchronously; deferred pieces of a wrapped cast draw in Default olive
- **Severity:** Low (cosmetic inconsistency on a paid or rarity cosmetic)
- **Confidence:** High
- **Files/lines:** `ToxinWrap.lua:52-68` (the swap lasts only for `f(d)`); `ToxinFX.lua:1337-1344` (BubbleConvert: `burst()` and `drops()` run inside an updater 0.1 s later); `486-495` (every `splat` is created from a drop's updater on landing); `1596-1598` (Patient Zero mark drips from its updater)
- **Trigger:** A Nightshade, CoralSnake or PoisonDartFrog Toxin converts a bubble into Corrosive Cloud; any drop lands (bubble pop, Patient Zero burst, mark drips, Corroded drips, Acid Rain splats; Acid Rain is SKIP by design).
- **Why it's a bug:** The tear burst (petals, puff, light) and every splat read `T.Color`/`T.Display`/`T.Bands` after ToxinWrap has restored Default, so a plum, red or cobalt cloud forms out of an olive-green burst and olive splats. The ToxinWrap header promises that bubble and cloud events "take the wrap their first event had".
- **Suggested fix:** Capture the palette with the effect: snapshot the needed colours (or the palette table) when the effect is created, and re-enter `W.Run`-style scoping inside deferred callbacks, for example by storing the wrap key on the bubble record and re-applying it around `burst` and `splat`.
- **Notes:** None.

#### P5B-12: Dead per-wrap branches in ToxinFX read Bands keys that no catalog wrap sets; the catalog's BRO comment is stale
- **Severity:** Low
- **Confidence:** High
- **Files/lines:**
  - `ToxinFX.lua:92-99` (`T.Hard`); `372` (`eyeOn` indexes `T.Bands.Pulse` unguarded); `376-399` (`RingTex`, `RingArt`, `Speckle`, `MoteGlow`); `718-735, 750` (`BANDED`/`Lanes`, band keys `K`/`Yin`/`R`/`Yout`); `757-762` (`Eyes`); `811-847` (`MoteTex`, `MoteSize`, `MoteZ`, `RingRise`, `Shimmer`, `MoteLife`, `Share`, `StainRings`, `StainFrac`, `ShimmerColor`/`Frac`/`Glow`, `GlowReroute`); `1302, 1420` (`BurstRings`, `RibbonRings`); `1533-1563` (`MARK_LANES`, `MarkRingSize`); `1671-1679` (`WAVE_LANES`).
  - `SkinCatalog.lua:163-209` (BRO comment: "crisp ring motes … 12% over each effect's Default rate, scaled by Graphics Quality / Reduce Enemy VFX / Reduce Flashing"; checkpoint 5 says "no ring particles").
- **Trigger:** None today. A future wrap that sets `Eyes` without `Pulse` would error in `eyeOn`.
- **Why it's a bug:** A grep of SkinCatalog for each of these keys finds 0 assignments; `Shimmer` matches only BRO's `Color.Shimmer`, not `Bands.Shimmer`. This is unreachable code carrying settings logic (`extraScale`) that no current wrap exercises, and documentation that describes particles no longer drawn.
- **Suggested fix:** Delete the dead branches, or keep them behind a documented schema and guard `eyeOn` with `T.Bands and T.Bands.Pulse`. Update the BRO comment.
- **Notes:** None.

#### P5B-13: AzureFlame is offered and accepted on Heat Rush and Cinder Shield, but nothing draws it there, or anywhere in the toon look; its embers contradict the catalog
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `SkinCatalog.lua:366-369` (Offer includes HeatRush and CinderShield), `75-79` ("Lights go #7FD0FF; embers and hit-flash keep Pyro's warm colours"); `SpellshotService.server.lua:717-725` (accepts the Skin request); `PyroFX.lua:297-302` ("Heat Rush and the Cinder Shield have only the one [toon] in this file"), `805-906, 957, 1077-1193` (toon only; `withWrap` there changes nothing); `PyroDraw.lua:586-602, 1155-1162` (wrapped canvases recolour embers white to azure by default)
- **Trigger:** A Pyro equips AzureFlame on Heat Rush or Cinder Shield, or on anything while the flame look has fallen back to toon.
- **Why it's a bug:** The player can equip a cosmetic that never renders, which matters once `OwnsSkin` gates by purchase or rarity. Separately, the flame look recolours embers azure, not the warm colours the catalog states.
- **Suggested fix:** Take HeatRush and CinderShield out of `Offer.Pyro` until they have a flame look, or teach the toon pieces the wrap. Fix either the ember code or the catalog comment.
- **Notes:** Cross-ref the economy pass for `OwnsSkin`.

#### P5B-14: Pyro wrap lights switch to azure before the wrapped flame meshes exist, so flames mix
- **Severity:** Low (cosmetic)
- **Confidence:** High
- **Files/lines:** `PyroDraw.lua:609-639` (each of the 45 mesh copies is built asynchronously), `903` (`m = wrapRec(m, cv.Wrap)` returns Default until each is ready), `1077` (`lc = self.Wrap and self.Wrap.Light`, applied immediately)
- **Trigger:** The first casts of an AzureFlame Pyro on each client. `PrewarmWrap` only starts when the viewer meets the wrap: when it is the local player's own, or on the first wrapped cast seen (PyroFX.lua:277-283, 2500-2520).
- **Why it's a bug:** Each mesh family switches as its copy finishes, so a viewer sees orange Default flames under azure light, then a mix of families, until all 45 copies are built.
- **Suggested fix:** Have the canvas wear the wrap (meshes and lights) only once all its families' copies are ready, and draw it fully Default until then.
- **Notes:** None.

#### P5B-15: Wrap staging scripts ship in ServerScriptService with no Studio guard: live dummies that clone a player, and a settings reset
> **Consolidator:** duplicate of **P1-05** (Temporary stage scripts ungated (if Enabled)). Kept here for its slice-specific detail; counted once, under P1-05.
- **Severity:** Medium (live-server artefacts; one player's whole settings can be reset and later saved)
- **Confidence:** Low (`manifest.json` does not record Enabled/Disabled)
- **Files/lines:** `game/ServerScriptService/_BROStage.server.lua:1-27` (waits for `StageReady`, clones `workspace.WrapStage.Caster` 8×, sets `WrapStudio`, parents into a Persistent `_StageP` model), `37, 63-66, 79-81` (`sync:FireClient(pl, { ColorblindSafe = true })` and `{ ReduceFlashing = true }`); `game/ServerScriptService/_AuroraStage.server.lua:1-30` (waits for the first player's character, clones it as "Caster", "DarkDummy" and "LightDummy" with `WrapStudio`, defines `_G.*` helpers); `SettingsRuntime.client.lua:89-92` + `SpellshotSettings.lua:202-209, 384-393` (`Load` → `Sanitise` sets every id missing from the table to its DEFAULT); manifest Workspace attributes `StageWrap = "Aurora"`, `TGBuild = "done"`
- **Trigger:** A live server with these scripts enabled. _AuroraStage runs as soon as the first player spawns. _BROStage's sequence runs only when the server sets the workspace attribute `BroGo`, which a client cannot.
- **Why it's a bug:**
  1. Copies of the first player's avatar appear as anchored Humanoid models at (-90, 0, -45) on a live server, under names Caster, Cast1-4 and Vic1-4. `CombatCore.HumanoidsNear` and aim-lock code may treat them as targets; that is unverified and belongs to the CombatCore pass.
  2. `_BROStage` pushes partial `SettingsSync` tables. SettingsRuntime calls `Settings.Load(tbl)`, which resets every other setting (keybinds, sensitivity, volumes) to its default and then `MarkSaved()`. The player's next settings change pushes a full snapshot, overwriting their real DataStore save with defaults.
  ToxinWrap's IsStudio gate keeps the `WrapStudio` dummies drawing Default on live servers, so the only harm is the instances and the settings reset.
- **Suggested fix:** Delete the staging scripts, or guard them with `if not RunService:IsStudio() then return end`. Make the client treat a settings table that is not the server's full save as a patch (`Set` per key), not a `Load`.
- **Notes:** Cross-ref Pass 5 slice A (Cryo/Aurora), which owns _AuroraStage. TerraTestHarness (a LocalScript on every client) and TerraTestServer are also "TEMPORARY" and ship. Neither gives a client more than the remotes it already has; the harness's `dev:` passthrough relies on DevRequest's server gate (another pass). Low.

#### P5B-16: Debris is halved for every other player's Terra effects even with Reduce Enemy VFX off
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `TerraFX.lua:1522` (`thinK = rock.Thin and 0.5 or 1`: chunks and grit), `4034` (Aftershock `Rocks × EffectDensity × (fx.Thin and 0.5 or 1)`), `4100` (SlamGrit); `TerraFX_Tomb.lua:1310` (chips). Compare `TerraFX.lua:963, 3681` and `TerraFX_Tomb.lua:670`, which correctly use `Thin and Settings.ThinEnemyVFX`.
- **Trigger:** Any viewer watching another Terra; the setting does not matter.
- **Why it's a bug:** The same module halves debris unconditionally on some paths and only under the setting on others. The setting is supposed to be what controls thinning.
- **Suggested fix:** Use `(Thin and Settings.ThinEnemyVFX) and 0.5 or 1` everywhere, or document the design halving and keep it separate from the setting.
- **Notes:** None.

#### P5B-17: TerraFX's Wall hooks drop the server's T0, so the rework's late-beat logic uses arrival time
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `AbilityFX.client.lua:803-807` (`WallHit(d.Character, d.Point, d.Left)`, `WallDrop(d.Character, d.Reason)`); `TerraFX.lua:2637-2638, 2664-2665` (signatures without T0); `TerraFX_Wall.lua:1375-1380, 1439-1444` (`t0` param → `fxTime(fx, nil)` = now); server sends T0 at `TerraHandler.server.lua:503, 607-608`
- **Trigger:** Any Bulwark Wall hit or drop seen by a lagging or late client.
- **Why it's a bug:** `late` is always false, and the break wave and sink run from when the message arrived, not from the server's moment, contrary to TerraFX_Wall's "a late join catches up".
- **Suggested fix:** Pass `d.T0` through AbilityFX → TerraFX → TerraFX_Wall.
- **Notes:** None.

#### P5B-18: Small lifecycle leaks: a resting Toxin bubble has no client timeout, ToxinWrap's byId is never pruned, and effect errors leave parts behind
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `ToxinFX.lua:1242-1255` ("Rest" mode returns true forever; Fly and Hold have timeouts at 1224 and 1234); `ToxinWrap.lua:18, 42-46` (one entry per bubble and cloud id, never removed); `TerraFX.lua:372-378` (step drops an erroring effect silently, leaving its rock model); `PyroFX.lua:439-456` and `ToxinFX.lua:215-219` (the updater is removed on error, its parts are not destroyed); `ToxinFX.lua:1525-1528, 1583` (`throwFrom` is nil if the caster has no hand and the target no torso → the updater errors → the Patient Zero blob and lobes stay at the world origin)
- **Trigger:** A dropped or errored Expire handler; a long session; a rig without the expected parts.
- **Why it's a bug:** Each case leaves parts or table entries for the rest of the session.
- **Suggested fix:** Give Rest mode its own timeout (`RestLife + 2`); prune `byId` on the End, Pop, Expire and Convert kinds; have each effect register a cleanup that runs when its step errors.
- **Notes:** None.

#### P5B-19: Aftershock plate pool thrashes between wrapped and unwrapped casters
- **Severity:** Low (performance in the exact case the pool exists for)
- **Confidence:** High
- **Files/lines:** `TerraFX.lua:3577-3592` (`asAcquire` pops pooled sets and destroys every one whose `Wrap` differs), `3595-3605`, `4425-4429` (warm-up set has `Wrap = nil`)
- **Trigger:** A match with one ObsidianMagma Terra and one Default Terra (2v2, Squad Clash, or the same player toggling).
- **Why it's a bug:** Each cast destroys the other kind's pooled set and clones 162 MeshParts. The pool's comment says this is what it is meant to avoid ("two Terras at once never clone 162 plates mid-fight").
- **Suggested fix:** Key the pool by wrap key (one list per `Wrap`), or keep plates untinted in the pool and tint them on acquire.
- **Notes:** None.

#### P5B-20: Fragile and doc-drift items in the settings plumbing for this slice
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `ToxinWrap.lua:25` (`ReplicatedStorage:FindFirstChild("ToxinTuning", true)`, a recursive name search, while ToxinFX requires its sibling at `ToxinFX.lua:33`; a second ModuleScript named ToxinTuning anywhere earlier in ReplicatedStorage would make every wrap swap the wrong table and draw Default); `SpellshotSettings.lua:17` (says SettingsRuntime applies "flashing, text size"; SettingsRuntime binds neither); `SettingsRuntime.client.lua:84` (`folder and … or folder:WaitForChild(…)` indexes nil if `Spellshot` times out, killing persistence silently); `TerraWrap.lua:557-575` + `TerraFX.lua:1829-1858` (every Terra wrap is built on the local Terra's client at Element pick, and a second full set is built for own-vs-others CrackGlow; failed builds retry every 5 s for the session)
- **Trigger:** Various; all latent.
- **Why it's a bug:** Each is a latent failure or a documentation mismatch.
- **Suggested fix:** Require ToxinTuning as `script.Parent.ToxinTuning`; fix the header; guard `folder`; back off TerraWrap retries exponentially and build only the wraps a visible player wears.
- **Notes:** TextSize is outside this slice.

#### Could not complete
- PyroDraw.lua 1650-2044, PyroFlame_Ring.lua 750-1080 and most of PyroFlame_Tech.lua (140-360, 440-1370) were checked by targeted grep (wrap, flash, density, own, Play/new, cleanup), not read line by line. Everything I found there is folded into P5B-05 and P5B-06.
- The three generated KitData modules were read only for structure, not row by row.
- I could not verify from the snapshot: whether the 45 PF_ flame meshes are all present (this decides whether toon or flame is the live Pyro look, see P5B-01); script Enabled state for the staging scripts (P5B-15); the Highlight cap and EditableMesh error and budget behaviour on devices (P5B-08, 09, 10).

### Pass 5, slice C: Radiant and Umbra client VFX (skins/wraps layering + settings honouring)

Static, code-only audit of the snapshot. Nothing here was run. Script Enabled/Disabled state is not in the manifest, so
every finding about a script "running on live" assumes the script is Enabled.

#### Files read (complete list)
- game/ReplicatedStorage/IceMagic/RadiantAnim.lua: fully (1-1726)
- game/ReplicatedStorage/IceMagic/RadiantClient.lua: fully
- game/ReplicatedStorage/IceMagic/RadiantDevilForge.lua: fully (1-2817)
- game/ReplicatedStorage/IceMagic/RadiantDevilStaffData.lua: partially (header, structure, tail). It is generated
  mesh data (P/T/C/TC arrays) and was checked only for its shape (Tip, Butt, Body{P,T,C,TC}, Lines{P,T}) against
  RadiantAnim.buildDevilPart.
- game/ReplicatedStorage/IceMagic/RadiantDraw.lua: fully
- game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua: fully
- game/ReplicatedStorage/IceMagic/RadiantFX_Staff.lua: fully
- game/ReplicatedStorage/IceMagic/RadiantFloat.lua, RadiantPoseTable.lua, RadiantTuning.lua: fully
- game/ReplicatedStorage/IceMagic/UmbraAnim.lua, UmbraClient.lua, UmbraDecoyPoser.lua, UmbraTuning.lua: fully
- game/ReplicatedStorage/IceMagic/UmbraFX.lua: fully (1-2686)
- game/ServerScriptService/_BROStage.server.lua, game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua: fully
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua, SpellshotSettings.lua: fully
- game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua: fully
- game/ServerScriptService/RadiantHandler.server.lua: partially, lines 60-100 (the skin-stamping broadcast), 225-260
  (pickOnAim), 480-690 (Blessing, Overflow, Halo, Position Trade and its precheck)
- game/ServerScriptService/UmbraHandler.server.lua: partially, lines 1-330 (header, state, Eclipse, Unseen), 395-460
  (Mark acquire and precheck), 700-813, 815-995 (Decoy Double, dispatch, Heartbeat, lifecycle)
- Followed cross-references (partially): ServerScriptService/UniformAvatar.server.lua 1-120;
  ServerScriptService/_AuroraStage.server.lua 1-80; StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua 1-18;
  ServerScriptService/SpellshotService.server.lua 565-585 and 690-785 (the Skin, ElementSkin and ElementWrap loadout
  requests); ServerScriptService/DuelMatch.lua 395-440; ServerScriptService/CombatCore.lua 325-340;
  StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua 218-232 and 1030-1050;
  StarterPlayer/StarterPlayerScripts/FirstPersonController.client.lua 255-275; IceMagic/ToxinWrap.lua line 40;
  SpellshotConfig.lua 275-350 (the Element colours); game/manifest.json (Workspace children and the script list).
  I also grepped the whole repo for every reader of SpellshotSettings flags, for StudioSkin, WrapStudio and IsStudio,
  for DecoyOwner and UmbraDecoys, and for LoadCharacter.

#### Top-level local counts (Luau limit: 200 active locals per function)
Counted with a tokenizer that skips comments and strings, tracks blocks, and handles if-expressions. "Peak" is the most
locals active at once in the main chunk, top-level locals plus locals inside top-level `do` blocks. A second pass
counted locals and upvalues for every function; no nested function goes above 58 upvalues or 50 locals.

| Module | top-level locals | peak in main chunk | headroom |
|---|---|---|---|
| RadiantFX_Hand.lua | 192 | 192 | **8** (Position Trade's helpers were already moved into `tradeHelpers()`, line 1211, because of the limit) |
| RadiantDevilForge.lua | 147 | 181 (`do` blocks) | 19 |
| RadiantFX_Staff.lua | 169 | 169 | 31 |
| RadiantDraw.lua | 148 | 148 | 52 |
| UmbraFX.lua | 119 | 120 | 80 |
| RadiantAnim.lua | 110 | 110 | 90 |
| UmbraAnim.lua | 47 | 47 | - |
| SettingsRuntime.client.lua | 47 | 47 | - |
| UmbraClient.lua | 44 | 44 | - |
| RadiantClient.lua | 38 | 38 | - |
| _BROStage.server.lua | 26 | 26 | - |
| RadiantFloat.lua | 24 | 24 | - |
| SpellshotSettings.lua | 13 | 13 | - |
| UmbraDecoyPoser.lua | 12 | 12 | - |
| SkinCatalog.lua | 7 | 7 | - |
| _BROStageClient.client.lua | 4 | 4 | - |
| RadiantPoseTable.lua | 3 | 3 | - |
| RadiantTuning.lua, UmbraTuning.lua | 1 | 1 | - |
| RadiantDevilStaffData.lua | 0 (one returned table) | 0 | - |
| (reference) RadiantHandler / UmbraHandler / CryoFX | 72 / 74 / 198 | same | - |

Per-skin table workarounds: `Devil` in RadiantFX_Hand.lua (line 295) holds helpers to save locals. All 12 `Devil.*`
keys used are assigned. Every `Devil.F.*` and `Forge.*` function called from RadiantFX_Staff and RadiantFX_Hand
(24 names) is defined in RadiantDevilForge. The hoisted option tables LO, HO, BO and SO (RadiantFX_Staff) have no
key read that was never assigned. Every FX.* path UmbraFX reads exists in UmbraTuning.FX, and every key UmbraFX reads
through `wrapped(...)` exists in Bloodmoon's `Shadow` block. Nothing here would fail to compile today.

#### Sub-areas checked with nothing found
- Checked, clean: StudioSkin / WrapStudio for Radiant and Umbra. No Radiant or Umbra module or handler reads either
  attribute or calls IsStudio. _BROStage sets `WrapStudio` only on its own stage dummies, and the reader that matters
  (ToxinWrap.lua:40) is gated by `RunService:IsStudio()`. SkinCatalog.HudSkin's preview attribute is IsStudio-gated
  (SkinCatalog.lua:599).
- Checked, clean: the skin and wrap choices are validated on the server. SpellshotService.server.lua:719-746 refuses
  a `Skin_*` Id that the ability does not offer, and an `ElementSkin_*` that is not in ElementSkins. A client cannot
  set `Skin_LightLance = "Devil"`. RadiantHandler stamps `Skin` from the caster's validated `SkinCatalog.Chosen`
  (RadiantHandler.server.lua:80-88). UmbraFX resolves the caster's validated choice on each client
  (UmbraFX.lua:2619-2631).
- Checked, clean: composite ids. The game data allows only one: Radiant `Devil+Rainbow` (ElementSkin Devil, plus
  Rainbow on any of LightLance, Blessing, Halo, PositionTrade or Benediction). `WrapsOverSkin("Rainbow")` is true
  (it has Stops and is not a Rework). Bloodmoon is never composed (Umbra has no ElementSkins, and Bloodmoon has no
  Stops). Resolve builds a palette with the skin's Id and Staff and the wrap's colours (SkinCatalog.lua:555-569), so
  every `pal.Id == "Devil"` gate still holds. The trident rebuild under a wrap is keyed by `pal.Key`
  (RadiantAnim.lua:487-509), and Forge.SetWrap repaints the forged forms (RadiantDevilForge.lua:782-797).
- Checked, clean: the RadiantAnim staff falls back to Default on failure. A failed trident or skinned-body build
  leaves StaffA in place (RadiantAnim.lua:347-375, 487-527, 551-584).
- Checked, clean: a missing RadiantDevilForge module degrades to the crimson recolour of the plain shapes
  (RadiantFX_Staff.lua:251-273, RadiantFX_Hand.lua:299-326).
- Checked, clean: Unseen is not a visibility mechanic. It is a server-side angle and Eclipse check, so it is
  authoritative (UmbraHandler.server.lua:314-322).
- Checked, clean: Decoy Double is a server-authoritative model. CombatCore, Heal, and Radiant's and Toxin's target
  pickers all treat `DecoyOwner` consistently. Mark can target an enemy decoy (it excludes only IsFriendly), so Mark is
  not a decoy detector.
- Checked, clean: Colourblind-Safe and hazards. No Radiant or Umbra hazard reads by colour alone. The Benediction range
  ring, Halo, Eclipse vignette and Mark anchor all carry shape, size or motion.
- Checked, clean: cleanup of RadiantDraw canvases and pool, the RadiantFX_Staff/Hand `live` sets (the OnEnd handlers
  remove them), RadiantFloat forces, RadiantAnim per-character state (Died, AncestryChanged, CharacterRemoving),
  UmbraFX effects (MaxLife and Stop free every ribbon and ball), the Eclipse grade (refcounted, restored with
  `between()` guards), and Forge handles (scopes pooled, IdleLife sweep).

---

#### P5C-01: Colourblind-Safe repaints the real Umbra but not the Decoy Double copy, so the decoy is obvious to that viewer
- **Severity:** High
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:309-359`, `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:158`, `game/ServerScriptService/UniformAvatar.server.lua:56-62`, `game/ServerScriptService/UmbraHandler.server.lua:839-883`, `game/ReplicatedStorage/IceMagic/UmbraFX.lua:1743-1747,1836-1842`
- **Trigger:** Any match where an Umbra uses Decoy Double and the viewer has ACCESS > Colorblind-Safe Elements on.
  Today that is Umbra only; any Element would be affected with `TechniquesOwnElementOnly = false` (see P5C-14).
- **Why it's a bug:** UniformAvatar paints the uniform on the server: torso = `def.Base` (79,33,145), violet for Umbra.
  The colourblind palette moves Umbra to near-black: `Umbra = { (79,33,145), (20,20,20) }`. SettingsRuntime repaints
  only players' characters: `repaintAll` loops `Players:GetPlayers()` and paints `p.Character`, and `watchPlayer`
  hooks only `p.CharacterAdded`. UmbraHandler.castDecoy clones the body on the server and parents it under
  `workspace.UmbraDecoys`, so the copy keeps the server's violet. DecoyPeel even tweens each travelling piece to
  `ent.Colour = part.Color`, the replicated violet, and then shows the real part. For this viewer, the real Umbra is
  black (torso 20,20,20, sleeves about 13, hands about 102) and the "identical" copy is purple, for its whole 8 s
  Duration. The design says the decoy "looks exactly like Umbra (option A)" (UmbraFX.lua:1727, UmbraTuning.lua:303).
  A client setting gives its user a perfect decoy detector.
- **Suggested fix:** Repaint decoys the same way the real body is repainted. In SettingsRuntime, also watch
  `workspace.UmbraDecoys` ChildAdded, read the owner's Element (from `DecoyOwner` to Player to Element), and paint the
  copy with `tonesFor`. A stronger option: have UmbraFX.DecoyPeel copy the owner's current local part colours onto
  the decoy's parts rather than tweening to the server colour.
- **Notes:** The same mismatch would exist for any other client-only per-viewer appearance change on player bodies.
  Cross-ref the Pass 5 slices that own Cryo/Toxin skins.

#### P5C-02: Devil skin swaps core Radiant tells for EditableMesh forms with no fallback; a pending or failed build leaves no beam, ring or column
- **Severity:** High
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/RadiantFX_Staff.lua:603-632` (lance core and rails drawn only `elseif` not Devil), `:1284-1310` (halo ring only when not Devil), `:1038` (wings become BatWing), `:1878-1985` (heaven column only when not Devil), `:269-273` (devilScope prewarms on first sight); `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua:563-569,641-646` (arches and ground become forged); `game/ReplicatedStorage/IceMagic/RadiantDevilForge.lua:336-370` (acquire and retry, about 10 s then error), `:588-599` (build failure: warn once, `FailT`, nothing drawn, retry after 5 s), `:347-359` (evictSpare), `:2796-2814` (PIECE_FORMS sizes); `game/ReplicatedStorage/IceMagic/RadiantClient.lua:427-443` (Devil prewarm only for the LOCAL player)
- **Trigger:** An opponent (or ally) wears the Radiant Devil skin or `Devil+Rainbow`. Either (a) it is their first Devil
  cast of that piece this client has seen, or (b) EditableMesh builds fail or are throttled (memory budget, mobile,
  several Devil Radiants in 2v2 / Squad, or API availability).
- **Why it's a bug:** When `h.Dv` exists (the forge module loaded and the palette Id is "Devil"), the frame functions
  draw ONLY the forged replacement:
  - Light Lance: `if dv then Forge.DevilChain(...) elseif b - a > 1e-3 then ... cv:Stroke(core) ... rails`
  - Halo: horns instead of the ring
  - Wings: bat wings
  - Benediction: HellColumn and Gate instead of the 180-stud "map-wide signal" column
  - Blessing: HornDome and SealPlate instead of the arches and floor ring
  - Trade: Maw instead of the cages

  A forged form shows only once its mesh exists. `showLayer` needs `L.Part ~= nil`, and a failed `requestBuild`
  only warns, sets `FailT` and returns. Prewarm runs only for the local player's own skin (RadiantClient.lua:432-438).
  For anyone else, `devilPrewarm` starts on the first Devil cast this client sees. The LanceChain alone is an exact
  10,864 + 3,880 triangle soup, built with a `task.wait()` every 800 triangles twice over, plus two async engine
  calls. That is roughly 0.5 s or more, with at most 2 builds at once (`Config.MaxBuilds`). Meanwhile the victim of an
  enemy's first Devil Light Lance sees only flares, the shimmer glints and a light, with no continuous beam back to
  the caster. Benediction alone prewarms about 37k triangles (about 110k vertices) against the "~200k vertices"
  budget the file itself cites (line 345). Under pressure `evictSpare` destroys spares, so forms are rebuilt
  repeatedly, and `retry` gives up after 40 tries. After that the form stays invisible in 5 s windows. A cosmetic
  thereby removes or delays the opponent's main threat reads. That is a competitive-integrity defect.
- **Suggested fix:** Draw the Default stroke version of each replaced telegraph whenever its forged form has not
  finished building or has failed. For example, have `Forge.<Form>` return 0 parts when not built, and draw the
  original strokes in that case. Prewarm the Devil pieces whenever any player in the match has `ElementSkin_Radiant`
  set to Devil, not only the local player.
- **Notes:** Real build times and EditableMesh budgets on a live client cannot be measured from the snapshot.

#### P5C-03: Devil skin makes Radiant's attacks, heal zones and shields much darker than Default, so the opponent reads them less well
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:242-247` (`MaxBright = 1.15, LEScale = 0.25, CoreLift = 0.12`), `game/ReplicatedStorage/IceMagic/RadiantDraw.lua:371-400` (skinEntry caps Brightness and multiplies LightEmission by 0.25), `game/ReplicatedStorage/IceMagic/RadiantDevilForge.lua:248-251` (IRON #1E1A1C, ASH #120508), `:1717-1785` (the lance is a black-iron chain), `:2244-2322` (the column is near-black ASH with veins), `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua:527-531` (the girdle drawn at level x 0.45), `game/ServerScriptService/SpellshotService.server.lua:714-737` (skins may change mid-duel)
- **Trigger:** Any Devil-skinned Radiant in PvP, worst on dark maps and under an enemy Umbra's Eclipse.
- **Why it's a bug:**
  - Default draws the lance as an additive, white-hot cream core (`LightEmission` 1, Brightness up to 1 + 13/8)
    inside a gold sleeve.
  - Devil caps Brightness at 1.15 and multiplies LightEmission by 0.25 (almost alpha-blended), keeps the core crimson
    (CoreLift 0.12), and replaces the beam with a black-iron chain.
  - The Benediction column becomes near-black (ASH plus vein glow), and the Seraph Seal's girdle drops to 45%.

  The game's rule is that cosmetics never change gameplay. Here a cosmetic changes how visible an attack's source,
  a heal channel and a shield are to the opponent. It can also be toggled mid-duel ("may change mid-match, a duel
  included").
- **Suggested fix:** Keep a minimum-luminance cream core or an outline on skinned threat telegraphs (the beam core,
  column core, shield ring), for example a hard floor of LightEmission and Brightness for LOOK_CORE spans. Consider
  locking skin and wrap changes during a duel like the rest of the loadout.
- **Notes:** This is a design trade-off the owner approved ("never pink"). It is graded Medium because it alters the
  opponent's read without hiding information outright.

#### P5C-04: Bloodmoon (Umbra wrap) changes what the opponent sees: a brighter charge ball and a slightly lighter Eclipse
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:226-232`, `game/ReplicatedStorage/IceMagic/UmbraFX.lua:626-627,707-724` (BallMoon body), `:2427-2441,2523-2532` (wrapGrade), `game/ReplicatedStorage/IceMagic/UmbraTuning.lua:372-378`
- **Trigger:** An Umbra with `Skin_ShadowDart = Bloodmoon` charging a dart (2.3 s on the hand), or with
  `Skin_Eclipse = Bloodmoon` casting Eclipse.
- **Why it's a bug:**
  - Charge ball: Default draws the charge ball as a dark "void" sprite with a violet rim (UmbraTuning.lua:30-33,
    Ball). Bloodmoon draws the engine moon image shaded from Lit (255,104,96) to Dark (140,30,42). The enemy's
    "about to fire" cue is therefore much brighter under the wrap.
  - Eclipse world grade: Bloodmoon replaces Ambient, OutdoorAmbient, Atmosphere Color and Decay, and TintColor
    (Rec.709 luminance):

    | value | Default | Bloodmoon |
    |---|---|---|
    | Ambient | 55.6 | 59.4 |
    | OutdoorAmbient | 63.6 | 67.3 |
    | TintColor | 164 | 171 |
    | Atmosphere Color | 65 | 69.5 |
    | Decay | 32 | 36 |

    That makes the darkness everyone in the duel sees about 4-7% lighter. Both are cosmetic changes to the
    opponent's view, against SkinCatalog's own "colour only, no mechanic" contract. Here they happen to disadvantage
    the wearer.
- **Suggested fix:** Have Bloodmoon match Default's luminance per channel (hue swap only) for the grade colours and
  the ball body. Or keep the Default grade, colour-neutral, and recolour only the wrap's ribbons.
- **Notes:** The size of the on-screen difference after Saturation -0.85 and Bloom is uncalibrated.

#### P5C-05: Radiant's Position Trade precheck is a free Decoy Double detector
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/RadiantHandler.server.lua:231-235` (pickOnAim rejects `DecoyOwner`), `:649-669` (`Precheck_PositionTrade`), `game/ServerScriptService/SpellshotService.server.lua:1029-1030,1065-1070` (a failed precheck refuses before paying)
- **Trigger:** Radiant against Umbra (Duel, 2v2, Squad). The Radiant aims Position Trade at the suspected Umbra after a
  Decoy Double.
- **Why it's a bug:** `tradeTarget` uses `pickOnAim`, which skips any model with `DecoyOwner`. The precheck runs before
  SpellshotService charges anything. On the decoy the press is refused at no cost; on the real Umbra it swaps. Either
  way the Radiant learns at zero cost which body is the decoy. That defeats Decoy Double's purpose ("a stationary
  illusion").
- **Suggested fix:** Have a decoy pass `pickOnAim` and `swappable` for enemies the way a real body would, and make the
  trade break it (and spend the cast) instead of refusing. Or make the refusal cost the cooldown when the aim was on
  a decoy.
- **Notes:** This is a gameplay-side cross-ref (Pass on Radiant/Umbra mechanics). Mark is not affected (it does not
  exclude decoys).

#### P5C-06: Temporary checkpoint-stage scripts (_BROStage, _BROStageClient, plus _AuroraStage) run unguarded on live
> **Consolidator:** duplicate of **P1-05** (Temporary stage scripts ungated (if Enabled)). Kept here for its slice-specific detail; counted once, under P1-05.
- **Severity:** Medium (High if Enabled and the parts overlap an arena)
- **Confidence:** Low
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua:2-11`, `game/ServerScriptService/_BROStage.server.lua:3-29,97-101`, `game/ServerScriptService/_AuroraStage.server.lua:3-30,69-71`, `game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua:1-18`, `game/manifest.json` (both are listed under StarterPlayerScripts and ServerScriptService)
- **Trigger:** A live server or client with these scripts Enabled. The manifest does not record Enabled state. Each
  file is headed "TEMPORARY ... remove when done".
- **Why it's a bug:**
  - _BROStageClient has no IsStudio or StageReady guard. On EVERY client it (a) adds a ScreenGui `_ShotTag` with a
    24x24 coloured square in the bottom-right corner, forced `Enabled = true` every frame by a priority-2000
    RenderStep, and (b) adds two invisible anchored parts to `workspace`. One is a 200x0.2x200 floor at
    (-90,0.05,-45); the other is a 400x160x1 wall at (-90,60,-100), spanning x -290..110 and y -20..140. Both have
    CanCollide false but keep the default CanQuery and CanTouch true. They therefore block every client raycast and
    spherecast through them: the Light Lance (RadiantClient.lua:190), Shadow Dart flight (UmbraClient.lua:215),
    aim, and so on.
  - On the server, _AuroraStage waits for the first player's character, clones it into `workspace.WrapStage`, sets
    workspace `CamPinEye` / `CamPinLook` and `StageReady`. _BROStage then clones that body 8 times into a Persistent
    model `_StageP` and adds its own CanQuery-true `_ShowcaseSrv` parts (lines 19-29).
  - _AuroraStageClient anchors every player, disables all their ScreenGuis and pins their camera (a separate,
    out-of-slice issue).
- **Suggested fix:** Delete these four scripts from the place, or at minimum gate them with `RunService:IsStudio()`
  and set `CanQuery = false, CanTouch = false` on the stage parts.
- **Notes:** Map pivots are not in the manifest, so whether (-90,0,-45) lies inside a playable map cannot be confirmed.
  _BROStage's own comment ("9-16: the real map") suggests a real map is visible there. Cross-ref the pass that owns
  _AuroraStage.

#### P5C-07: Reduce Flashing is ignored by every Radiant and Umbra effect, including a 2 Hz Benediction pulse
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:**
  - Radiant: `game/ReplicatedStorage/IceMagic/RadiantDraw.lua` (no reference to SpellshotSettings anywhere; Flare 1759, LightPool 1781, glints 1610); `game/ReplicatedStorage/IceMagic/RadiantFX_Staff.lua:1844-1851,1997-2003,2087-2090` (Benediction per-pulse staff flare, palm flare, pulse ring), `:684-691,711-717` (lance muzzle and hit flares), `:1314-1321` (Halo lock burst); `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua:1363-1389,1488-1489` (Position Trade body Highlight flash at FillTransparency 0.2, two flares)
  - Umbra: `game/ReplicatedStorage/IceMagic/UmbraFX.lua:946-975` (Tell: chest PointLight Brightness 2, ribbons Brightness 1 to 4.5), `:1386-1441` (Mark headshot: PointLight 5 and a swelling disc), `:2276-2292,2340-2352` (Eclipse pulse: PointLight 3 over 60 studs plus a ColorCorrection)
- **Trigger:** Reduce Flashing on, with any Radiant or Umbra caster (own or enemy).
- **Why it's a bug:** No Radiant or Umbra module reads `ReduceFlashing`; a grep of these 15 modules finds no reference
  to SpellshotSettings. Other kits damp their flashes (VFXLibrary.lua:1172, TerraFX.lua:1420/1580, CryoAurora.lua:73,
  ZephyrFX_*, VoltaicFX.lua:493). Radiant is a light element. Benediction flashes the staff tip, palm and ring every
  `PulseEvery = 0.5` s for up to `MaxChannel = 8` s (RadiantTuning.lua:99-101). That is a sustained 2 Hz strobe,
  exactly what the setting exists for.
- **Suggested fix:** Have RadiantDraw read `SpellshotSettings.Get("ReduceFlashing")` once per Begin. When it is on,
  scale Flare size and level (for example x0.6), drop the shock rings, clamp LightPool brightness, and flatten the
  per-pulse envelopes (pulseEnv / pullEnv) to their floor. In UmbraFX, clamp the Tell's BrightnessGain and BodyLight,
  the headshot flash, and the Eclipse pulse light and ColorCorrection.

#### P5C-08: Graphics Quality has no effect on Radiant or Umbra drawing
> **Consolidator:** duplicate of **P5F-05** (Graphics Quality / Reduce Enemy VFX unread by Umbra, Aqua, Radiant). Kept here for its slice-specific detail; counted once, under P5F-05.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:136-147` (the only appliers: shadows and `Settings.EffectDensity`), `game/ReplicatedStorage/IceMagic/RadiantDraw.lua:165-166` (Budget / PoolKeep 288 spans = 576 Beams), `game/ReplicatedStorage/IceMagic/RadiantFX_Staff.lua:388` (prewarms 280 spans), `game/ReplicatedStorage/IceMagic/RadiantDevilForge.lua:2796-2806`, `game/ReplicatedStorage/IceMagic/UmbraTuning.lua:146-151`
- **Trigger:** Graphics Quality set to LOW or MEDIUM.
- **Why it's a bug:** Graphics Quality drives only `Lighting.GlobalShadows` and `Settings.EffectDensity`, and the
  density is read only by VFXLibrary emitters and kits that opt in. RadiantDraw, UmbraFX and the Forge never read it.
  On LOW, a Benediction still draws about 276 spans (552 Beams), its sparkles, motes and lights, plus (Devil) about
  110k EditableMesh vertices. Eclipse still draws its 48 + 12 ribbons. The "uniformly wherever an effect is drawn"
  contract is broken for both Elements.
- **Suggested fix:** Have RadiantDraw multiply Sparkles / MoteField / Motes `n` and HolyRays `n` by EffectDensity
  (with a floor), and skip LightPool below MEDIUM. UmbraFX can drop wisps and wave ribbon counts on LOW. On LOW the
  Devil forms could fall back to strokes (which ties in with P5C-02).

#### P5C-09: Reduce Enemy VFX does not thin an opponent's Radiant or Umbra effects
> **Consolidator:** duplicate of **P5F-05** (Graphics Quality / Reduce Enemy VFX unread by Umbra, Aqua, Radiant). Kept here for its slice-specific detail; counted once, under P5F-05.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:149-151` (`ThinEnemyVFX`), `game/ReplicatedStorage/IceMagic/RadiantDraw.lua:2004-2018` (Play takes no caster or thin flag), `game/ReplicatedStorage/IceMagic/UmbraFX.lua:896-906`
- **Trigger:** Reduce Enemy VFX on, opponent is Radiant or Umbra.
- **Why it's a bug:** `ThinEnemyVFX` is never read by these modules. Other kits halve sparkles and emitters for
  somebody else's cast (VFXLibrary.lua:995 and onward, CascadeFX.lua:4292, FrostLotusFX.lua:33).
- **Suggested fix:** Pass a Thin flag (caster ~= local character, and the setting on) into RD.Play / UmbraFX.run and
  halve the decorative counts (sparkles, motes, glitter, wisps). Do NOT thin threat telegraphs, the Eclipse grade or
  darkness, or the decoy peel: thinning those would itself make Eclipse less dark or a decoy easier to spot (a
  competitive issue).

#### P5C-10: The Colourblind-Safe palette moves more Elements than it says, makes Zephyr and Radiant look the same, and turns Aqua gold
> **Consolidator:** duplicate of **P5F-10** (Colourblind palette moves 5 Elements; Zephyr~Radiant). Kept here for its slice-specific detail; counted once, under P5F-10.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:144-161,311-315`, `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:309-317`, `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:225`
- **Trigger:** Colorblind-Safe on.
- **Why it's a bug:**
  - The comment and the menu text both say only Pyro/Terra and Toxin/Cryo are moved. The table actually moves Terra,
    Toxin, Zephyr (to white 255,255,255), Umbra (to 20,20,20) and Radiant (to 240,240,240), and moves neither Pyro
    nor Cryo.
  - Zephyr and Radiant torsos become white and near-white, with derived sleeves of about 166 and 156 grey. Two
    Elements that never collided now read the same.
  - Aqua has no entry, so `ElementColor("Aqua")` returns the gold fallback (245,184,0). `tonesFor` sees it differs
    from Aqua's Base and repaints every Aqua player gold, which reads as Radiant or Voltaic.
  - Umbra goes near-black. That hides it in dark maps and under Eclipse, so the setting works against its own user
    (and it feeds P5C-01).
- **Suggested fix:** Make the table match the stated intent: pair[2] == pair[1] for Zephyr, Umbra and Radiant (or pick
  colours tested against every other Element). Add an Aqua entry. Have `ElementColor` return the Element's own Base
  for any Element not in the table. Update the menu description.

#### P5C-11: Eclipse darkness and Shadow Step's vanish are drawn only by the viewer's client, which can skip them
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/UmbraClient.lua:456-493` (hide is a client LocalTransparencyModifier), `:597-633` (the grade is applied only when Zone and Map match), `game/ReplicatedStorage/IceMagic/UmbraFX.lua:2443-2542` (GradePush/Pop on the client's Lighting), `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:120-129` (Brightness up to +0.10 ColorCorrection, stacking with the grade's -0.04)
- **Trigger:** An opponent of an Umbra with a modified client, or with the Brightness slider at 100.
- **Why it's a bug:** Nothing on the server makes the stepping Umbra invisible or the world dark. The server only sets
  VeiledUntil, which affects target locks. Eclipse darkness and the Shadow Step dissolve both come from client
  handlers, so a modified client can skip them. The legitimate Brightness row's +0.10 also outweighs the grade's own
  ColorCorrection -0.04. No server mechanic depends on visibility (Unseen is angle-based), so the competitive damage
  is limited to the visual edge.
- **Suggested fix:** Accept this as an inherent client-rendering limit and document it. Optionally clamp the
  SpellshotBrightness effect to <= 0 while the Eclipse grade is active, so the setting cannot undo the darkness.

#### P5C-12: The Overflow Light broadcast is stamped with the RECIPIENT's Blessing skin, not the caster's
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/RadiantHandler.server.lua:80-88,519`, `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:390`, `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua:1186-1202`
- **Trigger:** A blessed ally's shield lapses with absorb left, on a client that has no seal for that ally (joined
  late, streamed out, or never saw the RadiantBlessing).
- **Why it's a bug:** `broadcast("RadiantOverflow", { Character = humanoid.Parent, ... })` stamps `Skin` from
  `Chosen(<player of data.Character>, "Blessing")`, which is the recipient. A non-Radiant recipient gives Default; a
  Radiant recipient gives their own skin. `Hand.Overflow`'s fresh-seal path (`newShield`) draws with that palette.
  As a result a Devil caster's payoff draws gold, and a Default caster's can draw Devil forms.
- **Suggested fix:** Pass `Skin = SkinCatalog.Chosen(caster, "Blessing")` explicitly in that broadcast.

#### P5C-13: Eclipse's through-walls reveal stops only when `d.Character == player.Character`
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/ReplicatedStorage/IceMagic/UmbraClient.lua:635-644` (line 643), `game/ReplicatedStorage/IceMagic/UmbraFX.lua:2556-2611`
- **Trigger:** The caster's character is replaced (CharacterRemoving or LoadCharacter) before the client processes
  EclipseEnd, for example a respawn path that does not run Died or ClearPlayer first.
- **Why it's a bug:** If `player.Character` is already the new body, RevealStop is skipped. `refreshReveal` then keeps
  outlining enemies through walls (AlwaysOnTop Highlights) until `reveal.Until`, up to 7 s, into the next life or
  round. Normal duel resets call ClearPlayer before Respawn (DuelMatch.lua:419-421), so this is an edge case.
- **Suggested fix:** Stop the reveal on `d.Caster == player.UserId`, and also on the local CharacterAdded.

#### P5C-14: Decoy Double copies would be distinguishable for any non-Umbra caster (staff prop, pose) - latent: only with TechniquesOwnElementOnly = false
- **Severity:** Medium (latent)
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/RadiantAnim.lua:838-874` (staff props only for players' characters), `game/ReplicatedStorage/IceMagic/UmbraDecoyPoser.lua:43,99`, `game/ServerScriptService/UmbraHandler.server.lua:850-855`
- **Trigger:** `Config.TechniquesOwnElementOnly = false`, and a Radiant (or a Cryo with a Rework skin) slots Decoy
  Double.
- **Why it's a bug:**
  - The real Radiant carries a client-built staff or trident (RadiantStaffs folder, only for characters whose player
    is Radiant) and rests on `RadiantCarry`.
  - The server copy has neither the staff nor the Devil trident. DecoyPoser always loops `UmbraDecoyReady`.
  - Any skin whose forms are drawn on the live body would also be missing from the copy.

  The decoy would be readable at a glance.
- **Suggested fix:** Have the decoy carry the owner's Element and skin (a `DecoyElement` attribute), give it a staff
  in RadiantAnim, and pose it with the owner's Element base clip.

#### P5C-15: Docs say skins are colour-only and Flat palettes alpha-blended; the code does neither
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:4-5` ("A skin changes COLOUR only: no shape ...") against `:242-243` (Devil `Rework = true`, new forms); `game/ReplicatedStorage/IceMagic/RadiantDraw.lua:365-366` ("A Flat palette is drawn alpha-blended (LightEmission 0, Brightness 1)") against `:369-400` (skinEntry keeps base LE and Brightness and never reads `pal.Flat`); `game/ServerScriptService/SpellshotService.server.lua:714-716` ("Colour only, so it may change mid-match")
- **Trigger:** n/a (doc drift).
- **Why it's a bug:** The `Flat` flag on Rainbow and Devil is dead data. The "colour only" premise used to allow
  mid-duel skin changes no longer holds for Rework skins (see P5C-03).
- **Suggested fix:** Correct the comments, remove `Flat` or implement it, and revisit the mid-duel change rule for
  Rework skins.

#### P5C-16: _BROStage's partial SettingsSync payloads reset all of the player's other settings to defaults
> **Consolidator:** duplicate of **P2-11** (Partial SettingsSync payloads reset all settings). Kept here for its slice-specific detail; counted once, under P2-11.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/_BROStage.server.lua:75-77,92-94`, `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:89-92`, `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:202-209,384-393`
- **Trigger:** The stage `run()` (workspace `BroGo`, set from the server or the Studio command bar).
- **Why it's a bug:** `FireClient(pl, { ColorblindSafe = true })` reaches `Settings.Load`, and `Sanitise` fills every
  missing id with its Default. Keybinds, sensitivity and volumes all reset, and `MarkSaved` hides the change. The next
  real setting change pushes the default-filled snapshot, so the save is overwritten.
- **Suggested fix:** Remove the stage. A general alternative: never send partial tables through SettingsSync, or add
  a merge path.

#### P5C-17: UmbraClient's Mark anchors table holds strong references
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/UmbraClient.lua:250-276,504-510`
- **Trigger:** A marked victim whose MarkEnd never reaches this client (it leaves or streams out).
- **Why it's a bug:** `anchors[victim]` (the model) and its Part in the FX folder remain until MarkEnd. The
  RenderStepped connection disconnects when the head is gone, but the Part and the table entry are never freed, and
  `predictHeadshot` keeps treating the model as marked.
- **Suggested fix:** Destroy the anchor and clear the entry in the RenderStepped guard branch, and use a weak-keyed
  table.

#### P5C-18: The Devil Benediction crack-path cache holds one entry and thrashes with two concurrent channels
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/RadiantDevilForge.lua:2138-2166`
- **Trigger:** Two Devil Benedictions at once (2v2, Squad Clash).
- **Why it's a bug:** `crackCache` keeps a single key. Alternating calls rebuild both crack sets every frame, with
  string.format keys and fresh tables, making garbage per frame.
- **Suggested fix:** Key the cache by plant point, using a small table of entries.

#### P5C-19: RadiantFX_Hand is at 192 of 200 top-level locals
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua` (192 top-level locals; Position Trade's helpers already in `tradeHelpers()` at 1211)
- **Trigger:** The next feature added at file scope (for example a second Hand skin's helpers).
- **Why it's a bug:** Eight more locals is a hard compile failure ("Out of local registers"), which already happened
  once (comment at 1209-1210). RadiantDevilForge's main chunk peaks at 181 of 200 inside its `do` blocks.
- **Suggested fix:** Route any further skin helpers through the existing `Devil` table, or a sibling `Hand.Skins[...]`
  table.

#### Could not complete
- Live-only facts cannot be settled from the snapshot:
  - EditableMesh budgets, build timings and API availability (P5C-02)
  - whether the stage scripts are Enabled, and where maps sit relative to (-90,0,-45) (P5C-06)
  - on-screen luminance after Bloom (P5C-03, P5C-04)
- RadiantDevilStaffData.lua's numeric arrays were not checked value by value (generated data); only its structure
  was checked against its consumer.
- RadiantHandler and UmbraHandler were read only in the parts listed (cosmetics, visibility and decoy related), as
  scoped.

### Pass 5 slice D: skins/wraps layering and settings honouring for VOLTAIC and AQUA client VFX

#### Files read (complete list)
- game/ReplicatedStorage/IceMagic/VoltaicClient.lua: fully (995)
- game/ReplicatedStorage/IceMagic/VoltaicFX.lua: fully (1082)
- game/ReplicatedStorage/IceMagic/VoltaicKit.lua: fully (983)
- game/ReplicatedStorage/IceMagic/VoltaicTuning.lua: fully (61)
- game/ReplicatedStorage/IceMagic/VoltOrbFX.lua: fully (2877)
- game/ReplicatedStorage/IceMagic/OverchargeFX.lua: fully (2332)
- game/ReplicatedStorage/IceMagic/RailspikeFX.lua: fully (2678)
- game/ReplicatedStorage/IceMagic/CascadeFX.lua: fully (4506). Lines 455-663 are baked numeric data tables (LUMP_ROWS / SCRAP_* / GROUP_ROWS / EXT_ROWS). I checked their boundaries and shapes and skimmed the values; I did not check every number.
- game/ReplicatedStorage/IceMagic/ChainBoltFX.lua: fully (1359)
- game/ReplicatedStorage/IceMagic/ChainBoltShapes.lua: fully (74)
- game/ReplicatedStorage/IceMagic/AquaClient.lua: fully (1009)
- game/ReplicatedStorage/IceMagic/AquaFX.lua: fully (2403)
- game/ReplicatedStorage/IceMagic/AquaTTPose.lua: fully (266)
- game/ReplicatedStorage/IceMagic/AquaTTPoseTable.lua: structure and keys fully, per-key numeric rows skimmed (296; generated data)
- game/ReplicatedStorage/IceMagic/AquaTTSimData.lua: fully (147)
- game/ReplicatedStorage/IceMagic/AquaTuning.lua: fully (185)
- game/ReplicatedStorage/Spellshot/VoltOrbKitData.lua: fully (78)
- game/StarterPlayer/StarterPlayerScripts/VoltaicTestHarness.client.lua: fully (629)
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua: fully (613)
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua: fully (424)
- game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua: fully (438)
- game/ServerScriptService/VoltaicHandler.server.lua: fully (1123)
- game/ServerScriptService/AquaHandler.server.lua: partially. Read lines 1-95, 225-345, 572-625, 775-926 (header, helpers, wet zones, Riptide release, Twin Tide, Maw, dispatch, lifecycle/OnClear) and grepped every broadcast.
- Cross-references read partially: Viewmodel.lua 1880-1920 and 2740-2760 (Punch/Shake and the Reduce Flashing gate); VFXLibrary.lua 1600-1810 (VoltSparkBurst, GroundSurge*, Railspike/Overcharge presets) plus grep of every Settings read; CombatCore.lua 130-160 (IsFriendly / SameParty); SpellshotInput.client.lua 1245-1280 and 1770-1800 (Volt Orb hold-to-aim); AbilityFX.client.lua 1000-1080 (handler merge and dispatch); SpellshotService.server.lua 940-990 (M1 path); SpellshotConfig.lua 280-353 and 670-700 (Element colours, BuiltElements); SettingsMenu.client.lua 136-142, 222-230, 914-923, 1035-1050; docs/SPELLSHOT_Design_Manual.md (grep: Voltaic row 247, skin rules 655-657).

#### Skins and wraps SkinCatalog lists for these Elements (the enumeration)
- **Voltaic: none.** `SkinCatalog.Offer` has no Voltaic key (lines 364-375). `ElementSkins` (432) is Radiant and Cryo only. `ElementWraps` (457-458) is Cryo and Toxin only. `Origin` (378-383) lists no Voltaic ability, `Kinds` (389-395) has no Voltaic prefix, and Voltaic has no `WrapIcon` or `Hud` entry. `Chosen()` therefore returns "Default" for every Voltaic ability (the `Origin[ability]` miss at 495-496), and `ElementSkin` / `ElementWrap` return "Default" (the allow-lists miss).
- **Aqua: none**, for the same reasons. No Aqua key appears in any of those tables.
- No Voltaic or Aqua FX module, nor VoltaicHandler / AquaHandler, reads `Skin_*`, `ElementSkin_*`, `ElementWrap_*`, `StudioSkin`, `WrapStudio` or `SkinCatalog` (grep: zero hits; the only "Wrap" hits are `TextureMode.Wrap` and AquaFX's `WrapScale`, which is a gun-charge size).

#### Top-level local counts (main chunk; Luau limit 200 live locals per function)
I counted with a tokenizer-based script that skips strings and comments, tracks blocks, and counts a multi-name `local a, b` as 2. It agrees with a column-0 `^local ` grep plus the multi-name lines. AquaTTPose was counted by hand, because its Luau `if … then … else` expressions confuse the block tracker.

| Module | Top-level locals | Peak live in main chunk (incl. top-level do-blocks) | Headroom | Per-skin table workaround? |
|---|---|---|---|---|
| CascadeFX.lua | 166 | **187** (137 declared + 50 in the `seamSolve` do-block, 2159-2677) | **13** | none (no skins) |
| VoltOrbFX.lua | 139 | 139 | 61 | none |
| OverchargeFX.lua | 116 | 116 | 84 | none |
| RailspikeFX.lua | 102 | 102 | 98 | none |
| AquaFX.lua | 86 | 86 | 114 | none |
| VoltaicHandler.server.lua | 77 | 77 | 123 | n/a |
| AquaClient.lua | 76 | 76 | 124 | none |
| ChainBoltFX.lua | 73 | 73 | 127 | none |
| VoltaicClient.lua | 60 | 60 | 140 | none |
| AquaHandler.server.lua | 55 | 55 | 145 | n/a |
| VoltaicKit.lua | 44 | 44 | 156 | none |
| VoltaicTestHarness.client.lua | 44 | 44 | 156 | n/a |
| VoltaicFX.lua | 43 | 43 | 157 | none |
| AquaTTPose.lua | 6 (hand count) | 6 | 194 | none |
| VoltaicTuning / ChainBoltShapes / AquaTTPoseTable / AquaTTSimData / VoltOrbKitData | 0 (`return {…}`) | 0 | 200 | n/a |
| AquaTuning.lua | 1 | 1 | 199 | n/a |
| (reference) CryoFX.lua | 198 | 198 | 2 | (other slice) |

#### Sub-areas checked with nothing found
- Checked, clean: (1) per-skin table workarounds (`FBX`-style) referencing keys never assigned. No Voltaic or Aqua module has a per-skin table or skin branch at all.
- Checked, clean: (2) lazy EditableMesh builds and the Default-fallback-on-failure path. No module in scope uses EditableMesh or AssetService (grep). Every kit mesh is a clone of an imported part, with a warn-once skip when the part is missing (VoltaicKit.findPiece 208-217, AquaFX.template 125-133, VoltOrbFX.buildTemplate 585-707).
- Checked, clean: (3) StudioSkin / WrapStudio reachability. These modules never reference them, and nothing in scope uses `RunService:IsStudio()` except the harness, which returns early outside Studio (VoltaicTestHarness 37).
- Checked, clean (N/A): (4) composite "<Skin>+<Wrap>" resolution. Neither Element has a skin or wrap, and `Resolve()` returns nil for Default.
- Checked, clean: Reduce Enemy VFX never thins a hazard telegraph until it stops reading.
  - Overcharge's primed tendrils are never dropped. Thin only lowers jag depth and removes haze and lights (OverchargeFX 73-76, 1366, 1504, 1540, 1559).
  - Railspike's windup keeps its seeds, threads, light and 2 bolts per hand plus a bridge (RailspikeFX 251-252, 1361).
  - Cascade's big lumps, fan, forks, dominant strike and flash always draw (CascadeFX 101-105, 4313-4338).
  - Volt Orb's body always draws.
- Checked, clean: Railspike honours Reduce Flashing throughout: re-rolls slowed by CalmEvery (1488, 2356), no width flicker or accent (1792, 1934), flashes x0.6 and eased in (2250, 2300, 2326), no pierce star (2237), no Bloom (1631, 2620).
- Checked, clean: VoltaicKit.bloomPulse returns early under Reduce Flashing (612). Viewmodel.Punch and Viewmodel.Shake are zeroed under Reduce Flashing (Viewmodel 2749), so every Kit.punchNear, VM.Punch and VM.Shake call in scope is covered.
- Checked, clean: Colourblind-Safe and the Twin Tide / Leviathan's Maw telegraphs. Neither depends on colour.
  - Twin Tide reads through walls rising and closing (AquaFX 1363-1417).
  - The Maw reads through walls rising, the roof curling in and see-through glass (2201-2233).
  - No palette swap touches Aqua or Voltaic VFX, so colour is never the only cue.
- Checked, clean: Voltaic death and clear cleanup. Each server end is answered on the clients:
  - The prime ends with OverchargePrimed On=false.
  - The Railspike windup ends with RailspikeChargeStop.
  - An orb still in the hand ends with VoltOrbFizzle.
  - A storm ends with CascadeEnd.
  - Server side: VoltaicHandler 1065-1121. Client side: VoltaicClient endOwn 652-704, OverchargeFX Died / AncestryChanged hooks 1667-1673, CascadeFX.End 4468-4499.
  - Every FX object also has a watchdog and/or a Debris backstop.
- Checked, clean: the handler merge. AbilityFX gives Voltaic kinds `handlers[kind] or fn` and Aqua kinds a plain override. No existing AbilityFX handler shares a Voltaic or Aqua kind name, so none is shadowed.
- Checked, clean: the multi-return `pcall(Kit.libs)` destructurings. `local ok, _, _, S` (RailspikeFX 950), `local okL, _, VM` (2618) and `local _, _, S = Kit.libs()` (VoltOrbFX 1862, CascadeFX 435) all pick the intended value.
- Checked, clean: every function the Voltaic modules call on Viewmodel, CastPose and VFXLibrary exists (Tracing, IsPlaying, PlayShot, GetMuzzleCFrame, CurrentClip, ShotPending, ShotPlaying, StopShot, SetArmOffset, VoltSparkBurst, GroundSurge*, ShotTimeScale, FlatLit, GroundBelow, LocalAimCFrame).
- Checked, clean: AquaFX.Maw always returns a handle, so AquaClient's `entry.Handle.SetSharks` / `LungeMany` / `BiteMany` (984-1007) cannot index nil.

---

#### P5D-01: Colourblind-Safe repaints every Aqua player GOLD, the same colour as Voltaic and Radiant
> **Consolidator:** duplicate of **P5F-09** (Colourblind-Safe paints Aqua gold). Kept here for its slice-specific detail; counted once, under P5F-09.
- **Severity:** Medium (it gives colourblind players wrong information about which Element an opponent plays; arguably High as a competitive-read issue, but it only affects viewers with the setting on)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:148-161, 311-315`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:309-317, 319-337, 359`; `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:914-923`
- **Trigger:** ColorblindSafe on, any mode, with an Aqua player in view (yourself included).
- **Why it's a bug:**
  - `Settings.ElementColors` has 8 entries and no `Aqua` key.
  - `Settings.ElementColor(name)` returns `Color3.fromRGB(245, 184, 0)` when the pair is missing (line 313).
  - `tonesFor("Aqua")` takes that gold as `base`. It is not `def.Base` (38,140,176), so the code builds derived tones from it (316). Every Aqua torso, sleeve and hand is repainted gold-orange.
  - That collides with Voltaic (245,199,15) and Radiant (245,194,48).
  - The setting's own description says it "Swaps the two Element pairs that actually collide". Here it creates a new collision.
  - The SettingsMenu preview list (914-923) also lacks Aqua, and still carries the stale Pyro (233,78,27) that the SpellshotSettings comment at 149-152 says was fixed.
- **Suggested fix:** Add `Aqua = { Base, Base }` to `Settings.ElementColors`, with the same identity colour twice (its blue does not collide). Make `ElementColor` fall back to the Element's own `Config.Elements[name].Base`, not a gold constant. Add Aqua to the menu preview and correct the preview's Pyro value.
- **Notes:** Cross-ref the settings pass. Any future Element added without an ElementColors entry hits the same gold fallback.

#### P5D-02: Aqua honours none of the four settings (Graphics Quality, Reduce Enemy VFX, Reduce Flashing, Colourblind-Safe)
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/AquaFX.lua:225-226, 235-364` (crown / fling / spray: fixed `SPLASH_CAP = 150`), `442-476` (RidingSplash), `612-626` (Riptide crest spray every 0.035 s), `1804-1806, 1896-1910` (Sidearm muzzle FLASH per shot plus READY flash), `1429-1456` (Twin Tide jet flash), `2371-2381` (Maw bite rim flash); `game/ReplicatedStorage/IceMagic/AquaClient.lua:844-858` (RidingSplash for every player every 0.16 s)
- **Trigger:** Any Aqua cast, at any setting combination.
- **Why it's a bug:**
  - A grep for `EffectDensity|ThinEnemyVFX|ReduceFlashing|ColorblindSafe|GraphicsQuality` finds zero hits in AquaFX.lua and AquaClient.lua.
  - AquaFX builds its effects from kit-mesh clones, not VFXLibrary emitters, so none of the library's automatic density or thinning applies.
  - The brief requires all four settings to be honoured "wherever an effect is drawn"; at present no Aqua effect honours any of them.
  - On LOW and on mobile, every Riptide crest, Sidearm bullet, Maw slam and bite spawns up to 150 MeshPart clones, each with its own Heartbeat connection and a per-frame raycast. An opponent's Aqua kit is drawn at full under Reduce Enemy VFX.
  - Under Reduce Flashing, the Sidearm muzzle flashes pale white on every shot (1.6/s) plus the READY flash (CH.Flash 0.07 s), roughly 3 small flashes a second while held. The Maw bite also flashes the whole rim.
- **Suggested fix:**
  - Scale `SPLASH_CAP` and the per-effect counts (spray n, foam counts, RidingSplash drops) by `Settings.EffectDensity`.
  - Halve them for a character that is not `Players.LocalPlayer.Character` when `ThinEnemyVFX` is on. Keep the walls, tank and crest meshes untouched: they are the telegraphs.
  - Under ReduceFlashing, swap the FLASH tints for a dimmer Tideline step.
- **Notes:** The telegraphs stay readable with colour alone removed (see "checked, clean"). This finding is about the missing setting hooks.

#### P5D-03: Cascade's Reduce Flashing leaves its 15 Hz internal flashes, 30-60 Hz re-jags, fork re-strikes and several lights untouched
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/CascadeFX.lua:96-100` (the claimed coverage), `210-212` (Flashes up to 15/s, FlashAmp), `2021-2051` (planFlashes: only the FLASH event's amp gets `storm.flashK`; the punch 1.25, fan 2.0 and the four re-strikes 0.9 are not scaled), `2073-2106` (flashPrep feeds the seams: no calm factor), `292-299` + `3098-3101` (TelHz 30/60 re-jag, no calm divisor), `3597` (fan / fork `j30` re-jag every 1/30 s), `3543-3553` / `3649-3661` (fork re-strike spikes I 1.35 with whitening `wh` 0.35), `3681-3684` (fork lights, no flashK), `3674-3678` / `3877-3881` (floor hot spots at Brightness 1.4 / 2.0), `2857-2876` (hand set-flash `fl` x1.8 whitening still drawn; only its Bloom is skipped)
- **Trigger:** Reduce Flashing on, any Cascade in view (own or enemy, any quality tier).
- **Why it's a bug:**
  - Under calm, the module removes the exposure kick and Bloom, scales Beams x0.85, stars x0.75 and the strike, belly and hub lights x0.6, and makes the skeleton fade without flicker.
  - It does not touch:
    - The telegraph's internal flash events, which ramp to 15 per second (`Flashes = {…{1.20, 15.0}}`) and light the cloud's yellow-white seams at full amplitude.
    - The telegraph walkers, re-jagged at 30 Hz (60 at ULTRA).
    - The fan rays and forks, re-jagged at 30 Hz (`j30`).
    - The four fork re-strikes 0.067 s apart (about 15 Hz bright beats with whitening).
    - The fork lights and the floor hot spots.
  - The other Voltaic modules calm exactly these things: RailspikeFX re-rolls every `CalmEvery` (10 Hz), VoltaicFX Ground Surge uses `iv *= 3`, OverchargeFX has `CalmSnapBag` and no snap boost.
  - The CascadeFX header itself promises a "straight fade, no flicker" policy only for the skeleton.
- **Suggested fix:**
  - When `storm.calm` is set, multiply the flash-event amplitudes (all events, not just FLASH) by CalmFlash and cap the rate.
  - Divide the TelHz / j30 / re-strike re-jag rates by 3.
  - Collapse the four fork re-strikes into one held stroke.
  - Apply `flashK` to the fork lights and the flat spots.
  - Drop the `fl` whitening on the hand sprites.
- **Notes:** I did not measure flash frequencies on screen; this is from the timing tables.

#### P5D-04: Residual per-frame flicker under Reduce Flashing in Chain Bolt, Overcharge and Volt Orb
- **Severity:** Low
- **Confidence:** High
- **Files/lines:**
  - `game/ReplicatedStorage/IceMagic/ChainBoltFX.lua:929-936` (leg Brightness +-8 % re-rolled every 60 Hz frame, not disabled under `calm`), `831-844` (pulse arcs re-jagged every frame)
  - `game/ReplicatedStorage/IceMagic/OverchargeFX.lua:1386-1388` (tendril `T.Flicker` +-8 % every frame under calm too), `1501` (PulseWhite 0.85 at 2-3 Hz, not reduced)
  - `game/ReplicatedStorage/IceMagic/VoltOrbFX.lua:1170-1181` (crackle re-jag and brightness re-roll every 60 Hz frame), `2399-2411` (bolts re-rolled at `T.Reroll` 1/30 regardless of `O.Calm`)
- **Trigger:** Reduce Flashing on, with Chain Bolt M1 spam, a primed Overcharge tell, or a Volt Orb in flight or bursting.
- **Why it's a bug:** Each module's header lists its calm rules, but per-frame brightness jitter and shape re-rolls on bright yellow stay at 60 / 30 Hz. RailspikeFX treats exactly this as a flashing source (`CalmEvery`, "no width flicker").
- **Suggested fix:** Under calm, skip the flicker term, re-roll shapes at 10 Hz (Railspike's rule) and halve PulseWhite.

#### P5D-05: An opponent's Volt Orb blooms and punches YOUR screen at full strength under Reduce Enemy VFX
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltOrbFX.lua:2182-2199` (`kick`: gated on `O.Calm` and distance only), `2463-2468` (contact kick 0.5 and `Kit.punchNear` for every orb), `2663-2666` (full kick at the release); compare `game/ReplicatedStorage/IceMagic/CascadeFX.lua:3496-3509` (`thinK` 0.5 for somebody else's cast), and ChainBoltFX 1005-1009, OverchargeFX 1913-1923, RailspikeFX 1631 / 2617 (Bloom for the caster's own cast only)
- **Trigger:** Reduce Enemy VFX on; an enemy's Volt Orb bursts within 90 studs, on screen.
- **Why it's a bug:** Volt Orb is the one Voltaic effect that kicks the viewer's Lighting Bloom (+0.9 Intensity, +7 Size, Threshold down) for every caster, and the kick ignores `O.Thin`. The kit is inconsistent: Cascade halves the kick for enemies and the other three skip enemies entirely.
- **Suggested fix:** Multiply `kick`'s share by 0.5 when `not O.Own and ThinEnemyVFX` (Cascade's rule), or restrict it to own casts (Chain Bolt's rule).

#### P5D-06: "Reduce Enemy VFX" thins TEAMMATES' Voltaic effects (2v2 / Squad Clash): "enemy" is decided as "not my own character"
> **Consolidator:** duplicate of **P5F-06** (Reduce Enemy VFX thins teammates ("enemy" = not me)). Kept here for its slice-specific detail; counted once, under P5F-06.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltaicKit.lua:340-351` (`Kit.thin`: `S.ThinEnemyVFX == true and not Kit.isOwn(character)`); `game/ReplicatedStorage/IceMagic/CascadeFX.lua:4292`; `game/ReplicatedStorage/IceMagic/RailspikeFX.lua:950-956`; `game/ReplicatedStorage/IceMagic/ChainBoltFX.lua:976`; `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:994-995, 2792, 3031, 3123, 3498, 4513` (the same rule); `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:138-139`
- **Trigger:** 2v2 or Squad Clash with Reduce Enemy VFX on. A teammate's Cascade, Railspike or Volt Orb is drawn at the thin tier (Cascade tier 1: no florets, 70 seams, half the telegraph walkers, the flash halved).
- **Why it's a bug:**
  - The setting is named and documented as an opponent filter ("opponent effects thinned", per the brief).
  - The code never consults `Player.Team`, `Core.IsFriendly` or `Config.MayHurt`. CascadeFX already has a team test for strikes (`mayStrike` 3171-3184) but does not use it for thinning.
  - The menu text ("other players' characters") matches the code, so the drift is between the setting's name and its behaviour.
- **Suggested fix:** Give Kit.thin (and VFXLibrary's `onAnotherPlayer`) a friendly test, e.g. the shooter's `Team == LocalPlayer.Team` or a shared `Config.MayHurt(local, caster) == false` check. Otherwise rename the row "Reduce Other Players' VFX".
- **Notes:** This is a design decision for the owner. It is codebase-wide and not Voltaic-specific; cross-ref the other Element slices.

#### P5D-07: On LOW Graphics Quality with Reduce Enemy VFX on, the player's OWN Voltaic particles are halved too
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltaicKit.lua:349` (density < 0.6 => thin, even for your own character); `game/ReplicatedStorage/IceMagic/VoltaicClient.lua:812-831` (passes `Kit.thin(c)` as VoltSparkBurst's `thin`); `game/ReplicatedStorage/IceMagic/VoltOrbFX.lua:759, 771, 1010-1013, 2686` (`O.Thin` passed to GroundSurgeBurst / GroundSurgeEmitter / VoltSparkBurst); `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:1621-1622, 1743, 1750-1756` (`thin and Settings.ThinEnemyVFX` halves)
- **Trigger:** GraphicsQuality LOW (density 0.45), ReduceEnemyVFX on, your own Volt Orb or Chain Reaction.
- **Why it's a bug:** VFXLibrary's `thin` argument means "somebody else's cast". The Kit's `thin` means "somebody else's cast OR low quality". Passing one where the other is expected halves your own particles a second time, beyond what LOW already applies, whenever the enemy-VFX toggle is on.
- **Suggested fix:** Pass `not Kit.isOwn(c)` (ChainBoltFX already does, line 976) as the VFXLibrary `thin` argument, and keep Kit.thin for the module's own geometry tiers.

#### P5D-08: Twin Tide and Leviathan's Maw collision is created by AquaFX (client-side, CanCollide colliders), so whether a player is blocked depends on assets loading, distance, network lateness, and it ignores teams
- **Severity:** Medium (competitive integrity)
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/AquaHandler.server.lua:29-36` (the server relies on "each client's own solid copy"); `game/ReplicatedStorage/IceMagic/AquaFX.lua:197-207` (collider: CanCollide true), `942-985` (ttLoad: a missing or bad AquaTTPose / AquaTTPoseTable means "Twin Tide is not drawn": no walls, no colliders), `1127-1134` + `1147` (TT_FAR 600: not drawn, no colliders), `1257` + `1270` (`rigOn` false when the message lands within TT_BUILD_LEAD of the 1.10 s handover: no walls and no colliders on that client), `1409-1416` (collider placement), `2132-2144, 2225, 2235-2241` (Maw panel and ceiling colliders)
- **Trigger:**
  - Twin Tide cast on a client whose pose modules failed to load. That client's player is never blocked or herded by the walls, but the server still crushes at the seam (AquaHandler 589-610).
  - A high-latency client (more than ~0.95 s late) gets no wall colliders.
  - In 2v2 / Squad Clash, an ally's Maw tank also traps teammates and the caster: colliders are created for everyone and are not filtered by friendliness.
- **Why it's a bug:** AquaFX's own header promises "gameplay never waits on a look" (line 23), yet trapping and blocking bodies is gameplay here, and it lives inside visual code with visual-quality early-outs. Two clients can therefore experience different collision for the same cast. There is no server validation either (the module's own flag, AquaClient 20).
- **Suggested fix:**
  - Move the colliders out of the draw path into an AquaClient gameplay layer that is created unconditionally from the broadcast (independent of ttLoad, TT_FAR and rigOn).
  - Skip colliders for bodies the caster may not hurt (teammates), or document the ally-trap as intended.
  - Longer term, validate on the server (e.g. clamp the positions of trapped bodies).
- **Notes:** The owner may intend the ally trap. I graded on the asset- and latency-dependence.

#### P5D-09: No client-side end for Leviathan's Maw / Twin Tide on round reset or caster death: solid local colliders persist up to 5.3 s
- **Severity:** Medium
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/AquaHandler.server.lua:797-855` (Maw: epoch checks only stop the bite), `591-610` (Twin Tide crush epoch check), `917-926` (OnClear clears zones and attributes but broadcasts nothing); `game/ReplicatedStorage/IceMagic/AquaClient.lua:891-901, 969-981` (no end handler); `game/ReplicatedStorage/IceMagic/AquaFX.lua:2183-2296` (the tank lives on its own clock to EndTime with panel colliders and a ceiling)
- **Trigger:** A duel round resets (Core.ClearPlayer) or the caster dies or leaves during a Maw (5.3 s) or Twin Tide.
- **Why it's a bug:**
  - The server forgets the cast; every client keeps the tank closed with CanCollide colliders and a ceiling until EndTime. Players respawned or teleported inside or next to it stay trapped or blocked by an ability that no longer exists server-side.
  - Voltaic handles the same situation with explicit end broadcasts (CascadeEnd, RailspikeChargeStop, VoltOrbFizzle, OverchargePrimed Off: VoltaicHandler 1065-1121) that the clients act on.
- **Suggested fix:** Broadcast `AquaMawEnd` / `AquaTwinTideEnd` { Character, T0 } from OnClear, CharacterRemoving and PlayerRemoving. In AquaFX, return a handle with `Cancel()` that drops the colliders at once and runs the drain early.
- **Notes:** The real-world impact depends on spawn placement relative to cast points, which the snapshot cannot show.

#### P5D-10: Volt Orb aim arc is only cleared on key-up, not on death, respawn, Element change or loss of focus
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltaicClient.lua:913-993` (AimStart / aimClear; parts under the camera, RenderStepped), `652-704` (endOwn and the Element watcher never call aimClear); `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:1256-1260, 1786-1789`
- **Trigger:** Hold the Volt Orb key and die, respawn, switch Element, or alt-tab so InputEnded never arrives.
- **Why it's a bug:** The 28 Neon dots and the blast ring keep rendering, now tracking whichever `player.Character` exists, until the key comes up again. `orbAimRole` also stays set, which swallows the next press of that role (tryCast returns at 1256-1261).
- **Suggested fix:** Call `aimClear()` (and expose a reset for `orbAimRole`) from endOwn / CharacterAdded / the Element change / `UserInputService.WindowFocusReleased`.

#### P5D-11: Cascade's client strike prediction disagrees with the server's target rule, so bolts and the skeleton flash land on bodies the server never strikes
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/CascadeFX.lua:3171-3184` (mayStrike: excludes the caster, WallOwner, MayHurt=false and the same Team), `3337-3375` (predictTargets), `3291-3335` (applyHit: a payload arriving after the strike moves nothing on the ground); `game/ServerScriptService/VoltaicHandler.server.lua:140-143, 905-941`; `game/ServerScriptService/CombatCore.lua:130-151` (IsFriendly also excludes AllyDummy and own or ally DecoyOwner bodies)
- **Trigger:** An AllyDummy, or the caster's or an ally's Umbra Decoy Double, stands in the 11-stud zone.
- **Why it's a bug:**
  - The client predicts a strike on that body; the server strikes filler point n instead.
  - By design the prediction is "what every client sees at the strike moment" (header 72-83). The fork, scorch, ring and skeleton flash stand on the wrong body, and the late payload cannot move them.
  - Players get a misleading read of who was hit.
- **Suggested fix:** Mirror Core.IsFriendly's AllyDummy and DecoyOwner/WallOwner checks in mayStrike, or share one helper with the server through ReplicatedStorage.

#### P5D-12: Cascade's strike zone has no ground footprint at any setting, and the cloud overstates the zone
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltaicFX.lua:59` (ZoneRadius 11); `game/ReplicatedStorage/IceMagic/CascadeFX.lua:455-526` (lump homes reach about 16 studs in x and 19.6 in y from the point, e.g. group 5 rows 461-464), `3543-3553` (the fork ground contacts appear at S 1.200, 0.033 s before strike 1)
- **Trigger:** Any Cascade. The only zone read is the cloud overhead.
- **Why it's a bug:**
  - The zone is homing (the server picks the least-struck enemy within 11 studs). The only boundary cue is a cloud whose silhouette extends almost twice the zone radius on its long arm.
  - The first ground mark (the fork hot spots) comes one frame before damage.
  - Players inside 11-19 studs cannot tell whether they are in or out. This is a readability and telegraph-honesty question rather than a settings bug.
- **Suggested fix:** Owner's call: draw a faint ground ring at ZoneRadius during the gathering, or scale the cloud's footprint to the zone.

#### P5D-13: Chain Bolt damage never requires the M1 CastRequest, so the M1's mana drain is client-optional
> **Consolidator:** duplicate of **P1-12** (M1 hit remotes never pay mana). Kept here for its slice-specific detail; counted once, under P1-12.
- **Severity:** High (exploit: a mana advantage for every other Voltaic ability)
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/VoltaicHandler.server.lua:18, 429-509` (ChainBoltFire: loadout, CanAct, token bucket and eye checks; no mana check, no pairing with a CastRequest); `game/ServerScriptService/SpellshotService.server.lua:949-967` (the M1 CastRequest is the only place M1 mana is drained); `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:373-374` (ChainBolt ManaCost 2, FireInterval 0.32); `game/ReplicatedStorage/IceMagic/VoltaicClient.lua:362-365, 396-397`
- **Trigger:** A modified client sends only `IceAbilityRemote:FireServer("ChainBoltFire", …)` at the 0.32 s rate and never sends `CastRequest("M1")`.
- **Why it's a bug:**
  - The honest client sends both (VoltaicClient 362 and 397). The server deals full damage, Charged stacks and chains on ChainBoltFire alone.
  - Skipping the CastRequest saves 6.25 mana/s, against a regen of about 7/s. Sustained M1 spam then leaves the full regen for Railspike (20), Volt Orb and Overcharge (18), several times the honest budget.
- **Suggested fix:** Require a recent server-side M1 record before a ChainBoltFire is honoured: SpellshotService stamps `LastM1`, and VoltaicHandler checks it within the same slack. Alternatively, drain the mana inside the ChainBoltFire handler.
- **Notes:** Outside this slice's main scope; found while reading the handler, so cross-ref the server-validation pass. Check whether the other hitscan M1s ("Wind Blade's arrangement", referenced in VoltaicHandler's header) share the pattern. I did not read SpellshotService beyond 940-990 to rule out another pairing.

#### P5D-14: CascadeFX has 13 slots of local headroom, not ~35 as its header implies, and the header's advice points at the tight block
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/CascadeFX.lua:140-142` (the claim and the advice), `2158-2677` (the `seamSolve` do-block's 50 locals: 2161, 2169, 2216-2230)
- **Trigger:** A future edit adds about 14 locals to the seamSolve block, or at top level before line 2159.
- **Why it's a bug:**
  - The header says "~165 locals of Luau's 200 … add new helpers inside a section's block". The main chunk does hold 166 at its end.
  - But locals inside a top-level `do` block are live main-chunk registers while the block runs. The peak is 137 + 50 = 187, so the hard limit is 13 locals away there.
  - The advice is right for the small blocks and wrong for the solve block.
- **Suggested fix:** Correct the header figure to "peak 187 in the seamSolve block". Move the solve's 40-odd scratch tables into one `local S = {}` table (a single slot).

#### P5D-15: A CascadeEnd that arrives while the first storm is still loading is dropped, so the client draws a whole cancelled storm
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/ReplicatedStorage/IceMagic/CascadeFX.lua:392-426` (libs(): timed waits, Kit published last), `4414-4429` (Gather), `4468-4470` (End returns on `not Kit`); `game/ReplicatedStorage/IceMagic/VoltaicFX.lua:1027-1057, 1076-1080` (CascadeEnd never loads the module)
- **Trigger:** The first Cascade a client ever sees, cancelled by a round reset or caster leave within the module's load time (WaitForChild up to 3 + 2 + 2 s when pieces are slow to stream).
- **Why it's a bug:** Gather's libs() yields; the End handler runs, sees `Kit == nil` and returns. Gather then builds the storm with no End recorded, and it plays its fan, forks, dominant strike, hitpause and flash at predicted targets that the server never struck.
- **Suggested fix:** Queue Ends received while `kitLoading` is set (or keep a small set of ended T0s) and apply them in newStorm.

#### P5D-16: The Twin Tide debug probe ships on: 9+ SetAttribute writes per Heartbeat on every client for every cast
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/AquaFX.lua:931` (`TT_PROBE = true`), `1239-1242, 1303, 1657-1667`
- **Trigger:** Any Twin Tide within 600 studs.
- **Why it's a bug:** The comment says "for the Play test", but every client writes TTE, TTStage, TTBones, TTEvals, TTSimFrame, TTBuilt, TTQueue, TTFlashes and TTLive on the effect model every frame for about 3 s. Each write fires AttributeChanged and adds attribute churn to an FX folder that other systems scan.
- **Suggested fix:** Gate it on `RunService:IsStudio()`, or set it to false.

#### P5D-17: An own Railspike whose server answer is late draws a stuck "observer" windup on the caster
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltaicClient.lua:575-577, 588` (unanswered: rail dropped at GiveUpAt), `839-846` (RailspikeChargeStart draws one for any body when `rail` is nil, own included); `game/ServerScriptService/VoltaicHandler.server.lua:1026-1027` (server timeout at ChargeTime + GiveUp)
- **Trigger:** The ChargeStart broadcast arrives after the local GiveUpAt (`max(0.55, 2*ping+0.3)`): a ping spike or packet delay.
- **Why it's a bug:** The local press has been dropped and the slot flashed "denied". The late broadcast then starts an Own windup on the caster's hands that cannot fire, and it holds until the server's Timeout ChargeStop up to 1.55 s later.
- **Suggested fix:** In H.RailspikeChargeStart, skip `c == player.Character` when there is no live local `rail` (or when the press was given up).

#### P5D-18: Doc drift in the Voltaic and Aqua settings and kit descriptions
- **Severity:** Low
- **Confidence:** High
- **Files/lines:**
  - `docs/SPELLSHOT_Design_Manual.md:247`: the Voltaic row says Ultimate "Thunderclap — instant single burst, no zone, no delay", Passive "Bonus damage vs. stationary targets" and M1 "very short range". The code ships Cascade (a 2 s storm, 5 strikes), Chain Reaction (Overcharge cooldown cut) and Range 55 (VoltaicTuning 31, 43, 58).
  - Manual 54 (flat comic VFX, "no glow shaders") vs the fully re-lit Voltaic kit (Beams, Neon, PointLights, Bloom); only Ground Surge has a recorded waiver (VoltaicFX 12-17).
  - `VoltaicTuning.lua:10`: "Chain Bolt 8 per 0.32 s = 25 damage/s" vs Damage 10.
  - `VoltOrbFX.lua:13`: "the 0.31 s in the hand" vs ReleaseAt 0.12.
  - `VoltaicClient.lua:33`: "the throw on the key" vs hold-to-aim, throw on release.
  - `CascadeFX.lua:155-156`: flag 9 says the harness picks its own caster; the harness now skips it (VoltaicTestHarness 526).
  - `SpellshotSettings.lua:17`: SettingsRuntime is said to apply "flashing", but it has no ReduceFlashing bind.
  - `SettingsMenu.client.lua:139`: "Halves the particles on other players' characters", whereas the Voltaic thin tiers drop geometry, seams, lights and the flash (CascadeFX Quality[1], RailspikeFX 121-126).
- **Trigger:** n/a
- **Why it's a bug:** The code and the docs disagree. The code ships.
- **Suggested fix:** Update the manual's Voltaic row and VFX-policy exception list, the stale headers, and the menu description.

#### P5D-19: VoltaicTestHarness uses stale timings (Studio only)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/VoltaicTestHarness.client.lua:457` (`releaseAt = t0 + 0.31`, live 0.12), `506-512` (fallback `strikes` are the storm-clock StormStrikes without the 0.50 Windup, used when VoltaicFX is not found), `458` (gravity and fuse hardcoded)
- **Trigger:** `VoltTest = "look:voltorb"` / `"look:cascade"` in Studio.
- **Why it's a bug:** The harness's fake broadcasts no longer match the server's numbers. The orb releases 0.19 s late. Without VoltaicFX, the cascade strikes arrive 0.5 s before the storm draws them, which exercises the "arrived before its strike" path instead of the live path.
- **Suggested fix:** Read ReleaseAt / Gravity / Fuse from VoltaicTuning.VoltOrb, and fall back to `Windup + StormStrikes`.

#### P5D-20: VoltaicFX ships about 940 lines of unwired Ground Surge v3 that the server also requires
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VoltaicFX.lua:10-24, 68-1007`; `game/ServerScriptService/VoltaicHandler.server.lua:872-895` (requires VoltaicFX for Tuning.Cascade)
- **Trigger:** n/a (dead code)
- **Why it's a bug:** Volt Orb replaced Ground Surge in its slot; nothing calls GroundSurgePlant / Preview / Pop / Clear. It is harmless at runtime: no top-level side effects, safe on the server.
- **Suggested fix:** Move Ground Surge to an archive module, or split Tuning.Cascade into its own pure-data module so the server does not load VFX code.

#### Could not complete
- AquaHandler.server.lua was read in the parts listed above (header, wet zones, Twin Tide, Maw, lifecycle), not line by line in full. It has no skin or wrap code (grep), and its gameplay validation belongs to another pass.
- The CascadeFX and AquaTTPoseTable / AquaTTSimData numeric data rows were checked structurally, not value by value.
- No Studio run is possible. Every flash-rate or readability judgement comes from the code's timing tables, not from measurement on screen. P5D-09's real impact depends on where spawn points sit, which the snapshot does not show.

### Pass 5, slice E: skins/wraps layering and settings for ZEPHYR's client VFX and its movement pieces

#### Files read (complete list)
- game/ReplicatedStorage/IceMagic/ZephyrClient.lua: fully (311)
- game/ReplicatedStorage/IceMagic/ZephyrDraw.lua: fully (3862)
- game/ReplicatedStorage/IceMagic/ZephyrFX.lua: fully (623)
- game/ReplicatedStorage/IceMagic/ZephyrFX_CrossSlash.lua: fully (1700)
- game/ReplicatedStorage/IceMagic/ZephyrFX_Cyclone.lua: fully (1883)
- game/ReplicatedStorage/IceMagic/ZephyrFX_Skyrider.lua: fully (2461)
- game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua: fully (1774)
- game/ReplicatedStorage/IceMagic/ZephyrGustPad.lua: fully (1594)
- game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua: fully (1047)
- game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua: fully (1650)
- game/ServerScriptService/ZephyrGustPadServer.server.lua: fully (396)
- game/ServerScriptService/ZephyrSkyriderServer.server.lua: fully (406)
- game/ServerScriptService/ZephyrUpdraftServer.server.lua: fully (125)
- game/ServerScriptService/ZephyrHandler.server.lua: fully (895)
- game/StarterPlayer/StarterPlayerScripts/ZephyrTestHarness.client.lua: fully (163)
- game/StarterPlayer/StarterPlayerScripts/DeflectGustPractice.client.lua: fully (81)
- game/ReplicatedStorage/Spellshot/DeflectPractice.lua: fully (162)
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua: fully (613)
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua: fully (424)
- game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua: fully (438)
- Cross-reference reads, partial:
  - game/ReplicatedStorage/Spellshot/SpellshotConfig.lua: lines 278-347 (element colours), 387-411, 474-476, 636-660
  - game/ReplicatedStorage/IceMagic/VFXLibrary.lua: lines 4850-4925 (ShotTimeScale)
  - game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua: lines 296-440, 1055-1095 (the Zephyr handlers and the ZephyrClient merge)
  - game/ServerScriptService/TrainingGround.server.lua: lines 70-270 (practice-shot broadcasts)
  - docs/SPELLSHOT_Design_Manual.md (grep for the Zephyr kit: lines 31, 249, 824); docs/SPELLSHOT_Dev_Diary.md lines 1429-1445
  - game/ReplicatedStorage/IceMagic/CryoFX.lua: locals counted only, as a calibration point for the counter

#### Zephyr skins and wraps in SkinCatalog (enumerated)
There are **none**. Zephyr has no entry in `SkinCatalog.Offer` (lines 364-375), `Origin` (378-383), `Kinds` (389-395), `ElementSkins` (432) or `ElementWraps` (457-458). So `SkinCatalog.Chosen(player, <any Zephyr ability>)` returns "Default" (`Origin[ability]` is nil, line 495-496), and `Resolve` is never reached for Zephyr. No Zephyr module requires SkinCatalog, reads a `Skin_`/`ElementSkin_`/`ElementWrap_` attribute, or reads `StudioSkin`/`WrapStudio`. A grep of every Zephyr file for skin/wrap/StudioSkin/WrapStudio/Rework/FBX/EditableMesh/AssetService finds only unrelated words ("TextureMode.Wrap", "wrapped" handlers, `wrapAngle`, `ReceivePoint(.., skin)`). In ZephyrClient, ZephyrFX and ZephyrFX_Skyrider, "reskin" means the v6 look that replaced the toon look, not a cosmetic.

#### Per-module top-level local counts (Luau's limit is 200 locals live at once in a function; `kMaxLocalCount` = 200)
I counted these with a Lua tokenizer (scratchpad tools/peaklocals.py). It handles strings, long brackets, comments and Luau if-expressions, and counts every named local live in the main chunk, including locals inside top-level `do`/`if`/`for` blocks and loop variables. Calibration: it gives CryoFX 198, the module the brief names as nearest the limit.

| Module | Top-level locals | Peak live in main chunk (with do-blocks) | Where the peak is | Headroom |
|---|---|---|---|---|
| ZephyrClient.lua | 22 | 22 | - | 178 |
| **ZephyrDraw.lua** | 180 | **200** | line 3246 (`staffQ`, the 20th local of the do-block at 2620-3259) | **0** |
| ZephyrFX.lua | 23 | 23 | - | 177 |
| ZephyrFX_CrossSlash.lua | 99 | 99 | - | 101 |
| ZephyrFX_Cyclone.lua | 131 | 131 | - | 69 |
| ZephyrFX_Skyrider.lua | 141 | 141 | - | 59 |
| ZephyrFX_WindBlade.lua | 121 | 121 | - | 79 |
| ZephyrGustPad.lua | 104 | 104 | - | 96 |
| ZephyrSkyrider.lua | 63 | 63 | - | 137 |
| ZephyrUpdraft.lua | 120 | 120 | - | 80 |
| ZephyrGustPadServer.server.lua | 35 | 36 | 345 (the Precheck do-block) | 164 |
| ZephyrHandler.server.lua | 50 | 50 | - | 150 |
| ZephyrSkyriderServer.server.lua | 31 | 31 | - | 169 |
| ZephyrUpdraftServer.server.lua | 9 | 9 | - | 191 |
| ZephyrTestHarness.client.lua | 15 | 15 | - | 185 |
| DeflectGustPractice.client.lua | 9 | 9 | - | 191 |
| DeflectPractice.lua | 5 | 5 | - | 195 |
| SkinCatalog.lua | 7 | 7 | - | 193 |
| SpellshotSettings.lua | 13 | 13 | - | 187 |
| SettingsRuntime.client.lua | 47 | 47 | - | 153 |
| (CryoFX.lua, reference) | 198 | 198 | 4745 | 2 |

ZephyrDraw's do-blocks hold 22 locals (2094-2567, peak 198), 20 locals (2620-3259, **peak 200**), and others after 3264, each lower. 176 top-level locals come before line 2568, and 4 more at 2572-2593 (`lightWrite`, `CALM_T`, `CALM_V`, `calmNow`). 180 + 20 = 200. See P5E-14.

#### Sub-areas checked with nothing found
- checked, clean: per-skin table workarounds (FBX-style) for Zephyr. None exist, so no key can be read without being assigned.
- checked, clean: lazy EditableMesh builds and falling back to Default on failure. Zephyr builds no meshes (everything is pooled Beams, PointLights and ParticleEmitters on one ZephyrDraw anchor).
- checked, clean: StudioSkin / WrapStudio. Not referenced by any Zephyr file. The only Studio-only path in this slice is ZephyrTestHarness, gated by `if not RunService:IsStudio() then return end` (ZephyrTestHarness.client.lua:34), so the local "ride" demo with no mana and no server (ZephyrSkyrider.lua:1032-1041), the anchored-root demos and the Cyclone stand-ins cannot be reached from the harness on a live server. `SkinCatalog.HudSkin`'s `HudSkinPreview_` is also gated by `RunService:IsStudio()` (SkinCatalog.lua:599).
- checked, clean: composite "<Skin>+<Wrap>" ids for Zephyr. Not applicable: no Zephyr skin or wrap exists, and `Chosen` returns Default for every Zephyr ability.
- checked, clean: Gust Pad's telegraph under Graphics Quality LOW and under Reduce Enemy VFX. ZephyrDraw thins only particle counts and stream rates (`densityCount`, ZephyrDraw.lua:3390-3396; `Stream` rate x Density, 3483). The pad's arms, ticks, pulse ring, step ripple, shimmer column and launch column are Beams and are never thinned. The drawn rim (ticks at RP x 1.02..1.18, ZephyrGustPad.lua:705-707) matches the server's step radius (`Radius` 3.4, measured flat at the root, ZephyrGustPadServer.server.lua:226-231, 293).
- checked, clean: the Wind Blade projectile under Reduce Enemy VFX and Graphics Quality. The lens, core, rim, accents and wakes are Beams on per-blade canvases and are never density-thinned. Only the debris bursts on the "other" burst canvas are thinned (ZephyrFX_WindBlade.lua:943-961). (Two related gaps are separate: P5E-06 and P5E-07.)
- checked, clean: Cyclone funnel readability under Reduce Enemy VFX. An enemy's blades keep 65% x clamp(density, 0.5, 1), and never fewer than MinBlades 14 unflung (ZephyrFX_Cyclone.lua:666-681). The funnel still reads. The real problem is what is not drawn at all (P5E-01).
- checked, clean: Reduce Flashing in ZephyrDraw's engine paths. Lights lose their flicker and are scaled by CalmLight 0.6 (ZephyrDraw.lua:2601-2615). CameraKick drops pitch, roll and shake and keeps 0.35 of the FOV kick (3687-3691). ScreenGlare drops its flicker and is scaled by 0.6 (3815-3818). Wind Blade (cut rise and scale, light bumps x0.5: ZephyrFX_WindBlade.lua:229, 799-800, 908), Cross-Slash (X pulse and flash x0.5: ZephyrFX_CrossSlash.lua:906, 1185, 1253) and Updraft (apex surge and waist ring: ZephyrUpdraft.lua:152, 740, 855) scale their own spikes. The gaps are P5E-03 and P5E-11.
- checked, clean: Camera Shake. Every ZephyrDraw.CameraKick is scaled by `Settings.Scale("CameraShake")` (ZephyrDraw.lua:1088-1095, 3691), and Viewmodel.Shake carries the setting itself.
- checked, clean: cosmetics or settings changing gameplay. Nothing in Zephyr's look reads into a hitbox, damage or timing. The Wind Blade sweep (`sweep`, ZephyrFX_WindBlade.lua:521-570) runs before and independently of drawing. Gust Pad, Skyrider, Updraft and Cross-Slash numbers come from Tuning shared with the server. The own-view rules (OwnXScale, OwnScale, OwnFarScale, the FOV punch) change only the local view.
- checked, clean: the Skyrider bird when the rider dies mid-ride. On the client, `step` ends the ride with "Died" (ZephyrSkyrider.lua:545). On the server, Heartbeat broadcasts SkyriderEnd "Died" (ZephyrSkyriderServer.server.lua:349-351). Separately, ZephyrFX_Skyrider's `observe` returns false once the root is gone and `drawBird` ends the bird ("Gone", ZephyrFX_Skyrider.lua:1207-1209, 1265-1267). So a lost broadcast, a respawn or a PlayerRemoving (which sends no SkyriderEnd, server line 404-406) still breaks the bird. The bird's MaxLife is 40 s (2093). On the rider's own client, `cleanup` removes the movers, the turn render-step, PlatformStand and the pass-through folder (ZephyrSkyrider.lua:694-714).
- checked, clean: a Gust Pad when its owner leaves or the round clears. `Players.PlayerRemoving` calls endPad "Left" and `Core.OnClear` calls endPad "Clear" (ZephyrGustPadServer.server.lua:390-396), and both broadcast GustPadEnd. On the client, `endPadAt`, the fade and OnEnd remove the pad (ZephyrGustPad.lua:987-989, 1019-1021). The client canvas also has MaxLife = Life + 8 (1002). A pad outliving its caster's death is by design (header line 45-46).
- checked, clean: Cyclone cleanup. Caster death unwinds it; Clear, PlayerRemoving and a new cast end it instantly; caught bodies get CycloneRelease (ZephyrHandler.server.lua:649-677, 845-858). The client look releases itself once `Lost` is past its life (ZephyrFX_Cyclone.lua:1590-1593).
- checked, clean: the Updraft tell's lifetime. Episodes are thinned and cut on non-holder, death and suppression (ZephyrUpdraft.lua:1153-1166, 1203-1219). OnEnd restores the body pose (1090-1096).
- checked, clean: DeflectGustPractice ball leaks. Every server shot ends with Land or Spent (TrainingGround.server.lua:164, 172-181). `finish` handles an id the client never tracked.
- checked, clean: SettingsRuntime's quality table (4 rows for 4 options, line 136-147) and the ThinEnemyVFX mirror (149-151).
- checked, clean (trivial): ZephyrFX.lua:142-149 defines `settings()`, and nothing in ZephyrFX calls it (dead code, not a bug).

---

#### P5E-01: Cyclone's pull area (26-31 studs) is mostly invisible: nothing at ground level is drawn past about 13 studs while it pulls
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX.lua:465-471` (Radius 26, HoldSlack 5, Height 26, Below 3), `game/ServerScriptService/ZephyrHandler.server.lua:731-745` (catch cylinder), `game/ReplicatedStorage/IceMagic/ZephyrFX_Cyclone.lua:49, 161-162` ("The pull's Radius (26) is gameplay and does not change it"), `:1433-1452` (base disc 4 -> 13 studs x reach <= 1), `:1454-1460` (ground ring 3 -> 18 studs, only while Blender 0.3-1.4, i.e. while FORMING), `:1297-1298`, `:503-505` (funnel radius about 10 at the top, about 4 at the foot), `:1509-1527` (scuffs 11 -> 3.5), `:813-823` (billow dust 9-15 studs, density-thinned)
- **Trigger:** Any Cyclone in its ACTIVE phase (the 4 s it pulls and hurts), every setting, every mode. An enemy stands on the ground 14-26 studs from the axis.
- **Why it's a bug:** The server catches "each living character in its cylinder (Radius round the axis ...)" with `Vector3.new(d.X,0,d.Z).Magnitude <= radius` (radius = 26, or 31 once held). At ground level the look draws nothing past the base disc's 13 studs during the pull. The 18-stud ground ring is drawn only while `span(F.tB, 0.3, 1.4)` is between 0 and 1, which is the forming window. The flared top, flares and streamers reach about 20 studs out, but only at about 21-30 studs of height. So a player standing at 20 studs sees nothing on the ground near them and is caught. The Ultimate's hazard telegraph covers about half its real radius, and its area is about a quarter of the real one. Colour plays no part in this: the edge is simply not drawn.
- **Suggested fix:** While a Cyclone is ACTIVE, draw a persistent ground boundary at the server's catch Radius: a faint ring, or rotating dashes, at `shared().Radius` (and, optionally, a second ring at Radius + HoldSlack for bodies already held), never thinned by Reduce Enemy VFX. Or pull the gameplay Radius in to what is drawn.
- **Notes:** The manual (docs line 824) sets "pull radius 26 studs". The visual "Scale = 1.0 PROVISIONAL" comment shows the mismatch was known but never resolved.

#### P5E-02: Colourblind-Safe makes Zephyr and Radiant uniforms near-identical, paints Aqua gold, and its comment is wrong about which Elements move
> **Consolidator:** duplicate of **P5F-10** (Colourblind palette moves 5 Elements; Zephyr~Radiant). Kept here for its slice-specific detail; counted once, under P5F-10.
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:144-161` (ElementColors), `:311-315` (ElementColor returns gold 245,184,0 for an Element with no entry), `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:309-317` (tonesFor), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:308, 327, 347` (Zephyr, Radiant, Aqua Base)
- **Trigger:** A viewer turns on Colourblind-Safe in any match with a Zephyr, a Radiant or an Aqua player.
- **Why it's a bug:** `Zephyr = { (79,209,197), (255,255,255) }` and `Radiant = { (245,194,48), (240,240,240) }`. Under the setting, `tonesFor` derives torso, sleeve and hand from these: Zephyr becomes 255/166/255 and Radiant 240/156/246. Two Elements that were distinct (teal and gold) become the same white, so the safe palette *creates* a collision. `ElementColors` also has no `Aqua` entry (Aqua is the 9th Element, Config line 347), so `Settings.ElementColor("Aqua")` returns `(245,184,0)` and colourblind viewers see every Aqua player in gold, colliding with Voltaic (245,199,15) and with Radiant's normal gold. Separately, the comment (lines 144-147) says "Only the pairs that actually collide are moved: Pyro/Terra ... Toxin/Cryo. The rest keep their identity colour". In fact Pyro, Cryo and Voltaic stay put while Terra, Zephyr, Umbra, Radiant and Toxin all move.
- **Suggested fix:** Add an Aqua pair. Re-pick Zephyr's and Radiant's safe colours so they stay mutually distinct (and distinct from Cryo and Umbra), or leave unmoved the Elements that never collided. Make `ElementColor` fall back to the Element's own Base rather than gold. Fix the comment.
- **Notes:** Cross-ref the Aqua and Radiant passes. Only uniforms are affected; no VFX reads this palette (see P5E-12).

#### P5E-03: The Skyrider bird ignores Reduce Flashing: low-mana strobe flicker and hit stutter
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX_Skyrider.lua:793-806` (flickLive: 55% dips, 28 ms Gaussian, one chance every 0.21 s x 0.9 x thin), `:1307-1311` (`flicker = 1 - thin*(0.15+0.35*max(0, sin(37t) sin(23t+1)))`, `stut = (1 + 0.3*hitw*sin(90t)) * flicker`), applied as `fade`/`glow` on every wing, feather, body and spar ribbon (`:1343-1346, 1383, 1403-1404, 1441, 1485`); `:161-162`. The module reads neither ZD.Calm nor SpellshotSettings anywhere (grep: no Calm/ReduceFlashing/Settings).
- **Trigger:** Any Skyrider ride where the rider's Mana falls into the last 30 points. With ManaPerSecond 12 against 7/s regen, that happens on most longer rides. Also any hit on the rider. Seen by every client, including viewers with Reduce Flashing on.
- **Why it's a bug:** The whole bird's opacity is modulated by sharp 28 ms dips about 4 times a second, plus a 6-9 Hz alpha flicker of up to 50%. A hit adds a 14 Hz (90 rad/s) brightness stutter. These are exactly the "pulses / flashes" Reduce Flashing exists to damp, and the bird is a large on-screen object (about 19-stud wingspan). Only the PointLight is calmed, by ZephyrDraw. The other Zephyr pieces (Wind Blade, Cross-Slash, Updraft, Cyclone's light) each scale their own flashes under the setting.
- **Suggested fix:** Read `ZD.Calm()` once per frame in `drawBird`. Under it, set `flk = 1`, drop the sin terms from `flicker` (keep a steady `1 - 0.25*thin` dimming as the low-mana tell), and drop the `sin(t*90)` stutter, keeping only a slower wobble.

#### P5E-04: In team modes Gust Pad hits only enemies, but ally and enemy pads look identical, and the text still says "friend or foe"
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrGustPadServer.server.lua:213-220` (teammates excluded via MatchTeam), `:22` (header "the caster, allies, enemies"), `game/ReplicatedStorage/IceMagic/ZephyrGustPad.lua:5-6` ("friend or foe, the caster too"), `:1078-1099` (one look for everyone: only `Own` = the caster), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:411` (Desc "whoever steps on it -- friend or foe -- is launched")
- **Trigger:** 2v2 or Squad Clash with a Zephyr on both teams, or any team match with an enemy Zephyr. A player sees two pads on the floor.
- **Why it's a bug:** Since "2026-10-18, team mode", `eligible()` returns false for `victim:GetAttribute("MatchTeam") == team`, so in team modes a pad launches the caster and enemies but never the caster's teammates. Whether a pad is a hazard to you now depends on whose team it belongs to. Yet every client draws every pad with the same teal shapes. The only "own" distinction is the caster's own particle density, and nothing marks a pad as ally or enemy by colour, outline or shape. Reduce Enemy VFX also treats every non-own pad as an enemy's (see P5E-05). A player cannot tell a harmless ally pad from an enemy one, and the in-game description tells them both are hazards.
- **Suggested fix:** Pass the caster's MatchTeam (or a "friendly to viewer" flag computed client-side from the Caster's player) into `newPad`. Give enemy pads a distinct, non-colour-only cue, for example a dashed rim, a different tick shape, or a small chevron. Update the Desc text, the module header and the server header to say "the caster and enemies (in team modes teammates are spared)".
- **Notes:** In Duel MatchTeam is presumably nil, so everyone is launched. I could not verify which modes set MatchTeam (another pass's code).

#### P5E-05: Reduce Enemy VFX decides "enemy" as "not your own", so allies' effects are thinned too in 2v2 and Squad Clash
> **Consolidator:** duplicate of **P5F-06** (Reduce Enemy VFX thins teammates ("enemy" = not me)). Kept here for its slice-specific detail; counted once, under P5F-06.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrDraw.lua:1098-1107` (`if settingsLib.ThinEnemyVFX and not own then d *= Config.EnemyThin`), `:1921, 1930`; `ZephyrFX_Cyclone.lua:666-671, 1729`; `ZephyrFX_WindBlade.lua:943-961, 1159-1160` (burstsOther = everyone not you); `ZephyrGustPad.lua:1082, 1002-1003`; `ZephyrUpdraft.lua:1089, 1257`; `ZephyrFX_CrossSlash.lua:1339`; `ZephyrFX_Skyrider.lua:2072`
- **Trigger:** A team mode with Reduce Enemy VFX on and a Zephyr teammate.
- **Why it's a bug:** No Zephyr path tests the team. "Own" is the only thing exempt, so a teammate's Wind Blade debris, Cyclone blades (x0.65 and density x0.5), Gust Pad and Updraft particles are thinned exactly like an opponent's. The setting's name and the SpellshotSettings comment ("other players' effects") disagree on which is meant. For Cyclone (which never catches allies) and Gust Pad (which spares teammates in team mode) the thinned ally effect is harmless. Still, the rule is applied to the wrong set.
- **Suggested fix:** Expose one shared `IsEnemyOf(localPlayer, casterCharacter)` helper (Core.IsFriendly's rule, client-side via MatchTeam and party). Pass `Own = not enemy` (or a separate `Friendly` flag) into ZD.Play / ZD.new from every piece.

#### P5E-06: Wind Blade's shared burst canvases capture Graphics Quality and Reduce Enemy VFX once per session
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua:943-961` (`burstsOwn` / `burstsOther` module locals), `:1156-1161` (`burstsOwn = burstsOwn or sharedCanvas(...)`), `game/ReplicatedStorage/IceMagic/ZephyrDraw.lua:1930` (`Density = ZephyrDraw.Density(own)` evaluated in `new` only), `:3390-3396` (densityCount reads `cv.Density`)
- **Trigger:** A player changes Graphics Quality, or toggles Reduce Enemy VFX, after any Wind Blade has fired in the session.
- **Why it's a bug:** The two burst canvases are made once and never destroyed (only Cleared). `cv.Density` is computed when the canvas is created and never recomputed, so every later Wind Blade burst (yours and everyone's) keeps the density from the first shot of the session. Turning Reduce Enemy VFX on mid-session has no effect on enemy Wind Blade particles until a rejoin. Every other piece builds its canvas per cast, so it picks the setting up on the next cast.
- **Suggested fix:** Recompute `cv.Density = ZD.Density(cv.Own)` in `Canvas:Begin` (cheap), or have SettingsRuntime's binds bump a ZephyrDraw "settings generation" that canvases compare against.

#### P5E-07: Wind Blade draws at most 16 blades, newest first, so in busy fights an incoming enemy blade can go undrawn
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua:234` (MaxDrawn = 16), `:1135-1155` (`for i = #blades, 1, -1 ... drawn <= Tuning.MaxDrawn`), `:1007-1015` (a blade stays in the list until its hits' look ends: hit T + HitLife 0.55)
- **Trigger:** Several Zephyrs firing (8 blades a second each) in view at once, for example Squad Clash. A blade that has hit stays listed for up to about 0.75-0.95 s, so 2-3 shooters reach 16.
- **Why it's a bug:** The cap is shared by your own blades and everybody else's and counts the newest first. The oldest entries, which can be an enemy blade already flying at you, stop being drawn ("the oldest beyond that still fly and hit, undrawn"). On your client a remote blade is cosmetic, but it is the only telegraph of a hit the shooter's client will report. Entries kept only for their hit linger also take slots from blades still in flight.
- **Suggested fix:** Rank by priority instead of age: flying blades before stopped ones, other players' blades aimed near you before your own far-away ones. Or raise the cap for blades still in flight and apply it only to hit lingers.

#### P5E-08: Other players' Wind Blades are drawn off the real shot line (from the hand, never merged onto the eye line)
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua:310-314` (`FireWindBlade(hand.Position, d.Dir, shotExclude(c), nil, nil, ...)`), `game/ServerScriptService/ZephyrHandler.server.lua:124-128` (the WindBlade broadcast carries Dir but no Origin), `game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua:578-587, 1308-1311` (the Merge offset is applied only when `visualFrom` is given)
- **Trigger:** Every remote Wind Blade, seen by everyone except the shooter.
- **Why it's a bug:** The hit line is the shooter's eye along Dir, judged with HitRadius 1.1 and server HitSlack 1.5. Remote clients fly the drawn blade from the hand along the same Dir with no offset easing, so it travels parallel to the real line, about 1.5-2.5 studs to the side and below. The victim can see a blade pass beside them while taking the hit, and a remote copy's cosmetic sweep can be stopped by a corner the real shot cleared, so the drawn blade stops while the hit still lands.
- **Suggested fix:** Include the release `Origin` (the eye) in the WindBlade broadcast. In AbilityFX pass `origin = d.Origin` and `visualFrom = hand.Position`, so the remote blade eases from the hand onto the true line exactly as the shooter's own does.

#### P5E-09: The Skyrider gust's drawn cone is narrower than the server's hit cone
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX_Skyrider.lua:186` (`Half = 21`, "the server's hit cone is 28"), `:1789, 1878-1890`; `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:165-167` (HalfAngle 28, Range 22, BodyPad 1.5); `game/ServerScriptService/ZephyrSkyriderServer.server.lua:265-285`
- **Trigger:** Any gust flap. A body sits 21-28 degrees off the flap direction (plus 1.5 studs for its width).
- **Why it's a bug:** The server strikes `perp <= along*tan(28 deg) + 1.5`. The wavefronts, streamlines and vapor edge are drawn at 21 degrees. At 15 studs out that is about 5.8 studs drawn against about 9.5 studs hit, so bodies outside the drawn cone take 12 damage and a 55-studs/s knock. The comment admits the mismatch.
- **Suggested fix:** Draw the cone at `ZephyrSkyrider.Tuning.Gust.HalfAngle`, passed in via fxOpts as the other shared numbers are, or bring the server's angle down to 21 degrees.

#### P5E-10: Updraft's x1.25 applies to the Skyrider gust, while the Updraft tell is hidden for the whole ride
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua:149-151` (SuppressWhile "SkyriderT0": "Only the LOOK -- the bonus still applies"), `:979-988, 1184-1194`; `game/ServerScriptService/ZephyrSkyriderServer.server.lua:42, 138, 224` (DealDamage with `{ From, Ranged, Ability }`, no NoUpdraft); `game/ServerScriptService/ZephyrUpdraftServer.server.lua:76-92`; `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:170` ("Updraft's scale is NOT applied: not a passive hit")
- **Trigger:** A Zephyr riding Skyrider (CruiseClearance 9 studs, so always "airborne") flaps a gust at an enemy.
- **Why it's a bug:** The Updraft modifier raises every hit by an airborne holder unless `info.NoUpdraft`. The gust's info has none, so it deals 15, not 12. Meanwhile the opponent-facing tell that signals the aerial bonus (helix, disc, apex flash) is deliberately suppressed for the entire ride. The kit's own comments say Updraft's knockback scale is not applied to the gust ("not a passive hit"), yet its damage scale is. That makes a hidden damage buff and an inconsistent rule.
- **Suggested fix:** Decide the rule. If the gust should not get Updraft, pass `NoUpdraft = true` in the strike's info. If it should, keep a minimal tell during rides (for example the ankle ribbons or a small glow under the bird).

#### P5E-11: Gust Pad's launch flash and the Cyclone's pulses are not reduced under Reduce Flashing
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrGustPad.lua:175-176` (Light Launch 1900 W, Step 380 W), `:914-930` (no Reduce Flashing factor), `:570` (pad arcs `0.75 + 0.25 sin(9t)`), `:773-783` (white-hot core line shooting 18 studs in 0.22 s); `game/ReplicatedStorage/IceMagic/ZephyrFX_Cyclone.lua:1340, 1384, 1463-1471` (surge glow and juggle-pulse rings, not scaled; only its light flicker honours `rf`, 1533)
- **Trigger:** Reduce Flashing on. Any Gust Pad launch, or a Cyclone touchdown or juggle tick.
- **Why it's a bug:** ZephyrDraw only removes flicker and scales lights x0.6, so a launch still jumps from about 150-260 W idle to about 2150 W (Brightness about 0.13 to about 1.07 calmed, an 8x spike in 0.25 s), plus a bright core strike. Wind Blade and Cross-Slash halve their equivalent spikes under the setting (`ReduceFlashing.LightScale`, `ReducedFlashScale`), so the setting is not honoured uniformly across Zephyr's pieces.
- **Suggested fix:** Scale GustPad's `LT.Launch`/`LT.Step` and the core line's glow by 0.5 under `ZD.Calm()`, and the Cyclone's surge and pulse glow likewise, as Cross-Slash does.

#### P5E-12: No Zephyr VFX honours Colourblind-Safe, while the same setting repaints the Zephyr body white
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrDraw.lua:408-424` (fixed PAL; no ColorblindSafe read anywhere in IceMagic/Zephyr*), `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:157`, `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:359`
- **Trigger:** Colourblind-Safe on.
- **Why it's a bug:** The uniform turns white (P5E-02) while every Zephyr effect stays teal, so the body no longer matches its effects. As for "a hazard must never read by colour alone": Gust Pad (rim ticks, pulse, column) and Cyclone (funnel) read by shape and motion, and no team or ally/enemy information is coded in colour (there is none at all, P5E-04). So there is no hazard that reads only by colour. The gap is consistency, and the teal-vs-Cryo-cyan contrast for tritan viewers, which I could not measure statically.
- **Suggested fix:** Either keep Zephyr's uniform colour unmoved under the setting (teal does not collide), or let ZephyrDraw's ramp take a colourblind variant.

#### P5E-13: AbilityFX copies ZephyrClient.Handlers once, so a piece that loads late never gets its broadcasts (for example an invisible Gust Pad)
- **Severity:** Low
- **Confidence:** Low
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua:1063-1074` (pairs over `mod.Handlers` once, at load), `game/ReplicatedStorage/IceMagic/ZephyrClient.lua:42, 66-70, 170-207` (a piece missing at require is waited for 3 s, then loaded later by `refresh()`, which is called only from TryCast/Demo, i.e. the LOCAL player's own Technique press)
- **Trigger:** On some client, ZephyrGustPad (or ZephyrSkyrider / ZephyrUpdraft) has not replicated within PieceWait (3 s) when ZephyrClient is required. That client's player is not a Zephyr, so it never presses a Zephyr Technique.
- **Why it's a bug:** `merge()` adds the late piece's handlers to `ZephyrClient.Handlers`, but AbilityFX took its one-time copy earlier, and for a non-Zephyr player `refresh()` never even runs. That client then never draws any Gust Pad (a hazard), Skyrider bird or Updraft tell for the whole session, and never applies GustPadKnock/SkyriderKnock to its own body.
- **Suggested fix:** Have AbilityFX look kinds up through `ZephyrClient.Handlers[kind]` at dispatch time (one indirection) instead of copying. Or have ZephyrClient call a registered "handler added" callback from `merge`, and run `refresh()` on a slow timer, not only on a press.
- **Notes:** Depends on replication order. ReplicatedStorage is usually fully replicated before PlayerScripts run, but the code explicitly plans for "a piece not replicated yet".

#### P5E-14: ZephyrDraw sits at exactly 200 live locals, so one more local in its 2620-3259 block (or before it) is a compile error
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrDraw.lua:2620-3259` (do-block, 20 locals), `:3246` (`local staffQ`, the 200th live local), `:2572-2593` (4 top-level locals between the blocks), the counts in the table above
- **Trigger:** Any future edit that adds a `local` inside the do-block at 2620, or a top-level `local` above line 2620.
- **Why it's a bug:** It works today: Luau allows 200 (`localStack.size() >= 200` raises only when pushing the 201st). But the module has zero headroom, and the do-block comments show the authors believe the blocks keep them under the cap. If the 201st local is added, ZephyrDraw fails to compile. Every piece requires it in a pcall and draws nothing, so **every Zephyr effect** (Wind Blade, Cross-Slash, Cyclone, Gust Pad telegraph, Skyrider bird, Updraft tell) silently goes invisible while the mechanics still run.
- **Suggested fix:** Move `lightWrite`, `CALM_T`, `CALM_V` and `calmNow` (2572-2599) into a do-block, or split the 2620 block in two, to restore headroom. Add a comment with the current count.

#### P5E-15: Gust Pad placement has no line-of-sight check, so a pad can go behind walls or onto the floor above (cross-ref Pass 1)
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/ZephyrGustPadServer.server.lua:96-125` (ClampTarget to Range + 4, then a ray from `point + (0, FloorUp=2, 0)` straight down), `:350-355, 359-366`; the same pattern in Cyclone `groundUnder` (`game/ServerScriptService/ZephyrHandler.server.lua:571-593, 683`)
- **Trigger:** (a) A modified client sends any Target within 44 studs, for example a point inside a closed room or behind a wall, right under an enemy in cover. (b) A legit client aims at the underside of a floor, beam or bridge less than 2 studs thick: the ray starts 2 studs above the hit point, lands on top of that surface, and the pad appears on the level above.
- **Why it's a bug:** The spot is trusted from the client's aim point except for the range clamp and the floor ray. Nothing checks that the caster could see or reach the spot, so a hazard can be planted where the crosshair could not legally put it.
- **Suggested fix:** Raycast from the caster's head to `p` (through characters) and refuse, or pull the spot back to the first obstruction. Start the floor ray from `min(p.Y + 2, headY)` and reject a floor hit above the aimed point.

#### P5E-16: Skyrider flight is client-trusted beyond a loose speed check (cross-ref Pass 1)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrSkyriderServer.server.lua:379-391` (limit = sqrt(75^2 + 32^2) x 1.3 + 12, about 118 studs/s, for > 0.5 s), `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:153-157`
- **Trigger:** A modified client during a ride.
- **Why it's a bug:** The only server check is `root.AssemblyLinearVelocity.Magnitude`. It lets a ride go about 57% faster than BoostSpeed (75) indefinitely within MaxRide, and it cannot see CFrame teleports (the velocity can stay low). No height, position or MinClearance rule is checked server-side. The knocks (GustPadKnock, SkyriderKnock, CyclonePull) are also client-obeyed, as the code itself flags. Movement is client-authoritative across the game (no general server speed or teleport check was found), so this is consistent with the rest, but Skyrider's PlatformStand flight is the easiest place to hide it.
- **Suggested fix:** Track the root position delta per Heartbeat against the same limit, so teleports are caught. Tighten SpeedSlack. Optionally cap altitude over the arena.

#### P5E-17: The Updraft airborne check trusts the client-replicated root position (cross-ref Pass 1)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua:363-388` (sphere cast from the server's copy of the root), `:414-421`; `game/ServerScriptService/ZephyrUpdraftServer.server.lua:50-66, 87-91`
- **Trigger:** A modified client that hovers a couple of studs above the floor.
- **Why it's a bug:** Airborne is "MinClearance 1.5 studs of air under the feet" measured on the root position the client replicates, and the server deliberately skips FloorMaterial. A client hovering 1.5+ studs up gets a permanent x1.25 on every hit. It is inherent to client network ownership but worth listing.
- **Suggested fix:** Require a minimum airborne duration consistent with gravity (a body that stays at constant height for over about 1 s without a Skyrider, Gust Pad or Cyclone source is not airborne), or sample the vertical velocity sign.

#### P5E-18: Wind Blade hits may be reported up to 0.25 s (about 50 studs) earlier than the blade could fly (cross-ref Pass 1)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrHandler.server.lua:221-225` (`now - shot.At < along / (Speed x scale) - 0.25` is rejected), `:186`; `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:4916-4920` (the client reads ShotTimeScale from a ReplicatedStorage attribute, so a local change speeds only that client's own blade)
- **Trigger:** A modified client reports WindBladeHit immediately after WindBladeRelease.
- **Why it's a bug:** With Speed 200 the 0.25 s slack equals 50 studs, so within 50 studs a Wind Blade can be turned into hitscan. Both reports come over the same path with the same latency, so a legit flight's measured gap already tracks the flight time, and 0.25 s is more slack than jitter needs. The server does use its own ShotTimeScale, so a local attribute edit does not widen it further.
- **Suggested fix:** Reduce the slack to about 0.08-0.1 s plus a small multiple of jitter, measured per player, rather than a flat 0.25.

#### P5E-19: A client that joins (or reloads) mid-pad never sees that Gust Pad (doc drift note included)
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ServerScriptService/ZephyrGustPadServer.server.lua:376` (GustPad is broadcast once, at the press), `game/ReplicatedStorage/IceMagic/ZephyrGustPad.lua:1078-1099` (the client knows a pad only from that broadcast; GustPadStep/Launch/End for an unknown pad are dropped, 1103-1104)
- **Trigger:** A player or spectator whose client starts (rejoin, late join) during a pad's 10 s life.
- **Why it's a bug:** No state replicates for an existing pad, so for its remaining life it is an invisible launch hazard on that client.
- **Suggested fix:** Mirror live pads into a server-side attribute or folder (id, position, T0, life), or answer a client's "hello" with the current pads, as SettingsSync requests its state.

#### P5E-20: Doc drift in the manual and DeflectPractice about Zephyr's current Techniques
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `docs/SPELLSHOT_Design_Manual.md:31` (still describes Gust Jump's air jumps and "Deflect Gust is unchanged"; Skyrider and Gust Pad do not appear in the manual), `game/ReplicatedStorage/Spellshot/DeflectPractice.lua:13-28` (says Deflect Gust is equippable, the Defense key swings it and SpellshotInput reads `Catchable`), against its own STATUS line 8-11 and `game/ReplicatedStorage/IceMagic/ZephyrFX.lua:26-31` (Deflect Gust and Gust Jump retired 2026-10-06), `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:390, 411`
- **Trigger:** n/a (documentation).
- **Why it's a bug:** The code ships Skyrider and Gust Pad; the manual and the practice module's body text describe the retired kit.
- **Suggested fix:** Update manual Section 2 and the change log with Skyrider, Gust Pad and the Gust Pad team rule (P5E-04), and trim DeflectPractice's "WHAT IT IS" to the STATUS line.

#### P5E-21: A Cyclone look made from the CycloneActive fallback is treated as not yours
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX_Cyclone.lua:1786-1797` (`Cyclone.Cyclone(character, center, { Late = 0 })`, with no Own), `:663-671` (`thin = not own` picks the blade share), `:1566` (steering eased when not Own)
- **Trigger:** The caster's own client misses the "Cyclone" broadcast but hears "CycloneActive", and Reduce Enemy VFX is on.
- **Why it's a bug:** The caster's own funnel is built with `own = false`, so its blades are cut to 65% as if it were an enemy's. (ZephyrDraw's particle density is right, because `play` sets Own from the character.) This is cosmetic and rare.
- **Suggested fix:** In the fallback, pass `Own = character == localCharacter()`.

#### P5E-22: Graphics Quality scales only particles (and Cyclone's blade count), not Zephyr's Beam counts
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrDraw.lua:3390-3396, 3483` (density used only for particles), budgets `:655-662` (Cross-Slash 260, Gust Pad 220, Skyrider 420, Cyclone 640 Beams); `ZephyrFX_Cyclone.lua:671` (the only Beam-count reduction)
- **Trigger:** Graphics Quality LOW on a weak device, in a fight with Skyrider, Cross-Slash and Gust Pad on screen.
- **Why it's a bug:** SettingsRuntime documents Graphics Quality as driving "shadows and effect density ... to every emitter". For Zephyr, LOW still draws every ribbon at full span count (a gust peak of about 409 Beams, a Cross-Slash about 227, a Gust Pad about 210). This is a performance gap only, with no readability impact.
- **Suggested fix:** Scale `maxSpans` and the optional layers (accent arcs, spiral wakes, wisps, feather counts) by a quality tier read from `Settings.EffectDensity`.

#### Could not complete
Nothing in the assigned slice was left unread. Not verifiable statically:
- which modes set `MatchTeam` (P5E-04);
- whether a ZephyrClient piece can really replicate later than ZephyrClient's 3 s wait (P5E-13);
- the real on-screen contrast of the teal palette for colour-deficient viewers (P5E-12);
- the in-Play visibility of any effect (the modules themselves say "nothing here has been seen in Play").

### Pass 5, slice F — shared cosmetic plumbing (VFXLibrary / CastPose / Viewmodel / AbilityFX), the settings system, BarFX, SkinCatalog

#### Files read (complete list, with "fully" or "partially: lines X-Y" for each)
Assigned:
- game/ReplicatedStorage/IceMagic/VFXLibrary.lua — fully for all live paths (1-3100, 3100-3800 Chill Aura, 4804-5424 Shatter/Icicle Shard); lines 3800-4800 (retired Cryo Beam v2 renderer, no Abilities row) read at skim depth.
- game/ReplicatedStorage/IceMagic/CastPose.lua — partially: 1-160 (header, requires, config) and 1526-2260 (all logic); 160-1526 is the clip/stance data tables (spot-checked, not line-by-line).
- game/ReplicatedStorage/IceMagic/Viewmodel.lua — partially: 1-620, 1578-2075, 2349-2460, 2700-2878 (all logic, config, poses); clip data 620-1578 and the middle of Update 2460-2700 skimmed.
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua — fully.
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua — fully.
- game/ReplicatedStorage/Spellshot/BarFX.lua — fully.
- game/ReplicatedStorage/Spellshot/BarFX/Atlas.lua — partially (header + structure; machine-checked every static sprite name the variants use against it).
- game/ReplicatedStorage/Spellshot/BarFX/Variants/*.lua (24 files) — partially: chill_t 1-80 and primed_t 195-280 read; all 24 grepped for settings reads, shake/flash calls, timing patterns and sprite names (scripted check).
- game/ReplicatedStorage/Spellshot/BarKit.lua — partially: 1-130, 355-410 (geometry/colours/Build); 130-355 builder helpers skimmed.
- game/ReplicatedStorage/Spellshot/PopArtAssets.lua — partially (structure + Aqua placeholders grep).
- game/ReplicatedStorage/Spellshot/IconAssets.lua — fully.
- game/ReplicatedStorage/Spellshot/Callouts.lua — fully.
- game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua — fully.
- game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua — fully.
- game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua — fully.
- game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua — partially: 1-420 and the BarFX hand-off lines (696, 945-950).
- game/StarterPlayer/StarterPlayerScripts/BarFXClient.client.lua — fully.
- game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua — fully.
- game/StarterPlayer/StarterPlayerScripts/FirstPersonController.client.lua — fully.
- game/StarterGui/PopArtHUD.client.lua — partially: 1-120, 280-420, 480-560, 620-760, plus grep of every Settings/SkinCatalog read.
- game/ServerScriptService/SettingsStore.server.lua — fully.
- game/ServerScriptService/UniformAvatar.server.lua — fully.

Followed cross-references (partial reads):
- game/ReplicatedStorage/Spellshot/SpellshotConfig.lua 176-270 (MayHurt / MatchTeam / Team), 275-350 (Element colours).
- game/ReplicatedStorage/IceMagic/CryoWrap.lua 467-482 (runIn), 878-934 (palette / W.For), 1014-1021, 1110-1125, 1390-1400, 1565-1585.
- game/ReplicatedStorage/IceMagic/CryoFX.lua 286-300, 1895-1906, 2088-2098, 3530-3560, 4600-4616.
- game/ReplicatedStorage/IceMagic/{FrostbladeKit 20-62, 715-729; SnowGlobeKit/FrostLotusKit/FrostDragonKit Tier+On; FrostDragonKillFX 560-577; CryoAurora 720-745; ToxinWrap 25-60; VoltaicKit 340-360, 610-616; ZephyrDraw 1080-1106, 3695-3720; ZephyrGustPad 990-1003, 1085-1096; UmbraFX 1384-1432, 2270-2360, 2612-2650; RadiantFX_Hand 1350-1380; PyroFX 262-290; ZephyrFX_CrossSlash 1520-1545; ZephyrFX_Skyrider 2395-2410}.
- game/ServerScriptService/SpellshotService.server.lua 700-750 (cosmetic requests), ZephyrGustPadServer header.
- game/ServerScriptService/_AuroraStage.server.lua, _BROStage.server.lua (fully); game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua, _BROStageClient.client.lua (fully).
- game/StarterPlayer/StarterPlayerScripts/HubClient.client.lua 400-500 (lighting profile); game/ReplicatedStorage/Spellshot/MapRegistry.lua 75-95, 190-235.
- game/manifest.json entries for the four stage scripts.
- Cross-cutting greps over every module in game/ReplicatedStorage/IceMagic (73 files) for EffectDensity / ThinEnemyVFX / ReduceFlashing / ColorblindSafe / ElementColor / CameraShake / StatusIntensity and for flash constructs (PointLight, Highlight, ColorCorrection, Bloom, Viewmodel.Punch/Shake, camera CFrame/FOV writes).

#### Sub-areas checked with nothing found (explicit "checked, clean: ..." lines)
- checked, clean: StudioSkin / WrapStudio / HudSkinPreview READS. Every read is behind `RunService:IsStudio()`: FrostbladeKit.lua:36,724; FrostDragonKit.lua:42,1033; SnowGlobeKit.lua:33,1244; FrostLotusKit.lua:38,1160; FrostDragonKillFX.lua:570-571; CryoAurora.lua:735; CryoWrap.lua:929; ToxinWrap.lua:40; SkinCatalog.lua:599-602. No server code path copies a client value into StudioSkin/WrapStudio, and the cosmetic requests (SpellshotService.server.lua:716-746) validate Element ownership + `Allowed`/`ElementSkinAllowed`/`ElementWrapAllowed` + `OwnsSkin` before writing `Skin_*` / `ElementSkin_*` / `ElementWrap_*`. (The WRITERS are a different story, see P5F-01.)
- checked, clean: client-set cosmetic attributes. A client can set `ElementSkin_Cryo`, `ElementWrap_*`, `Skin_*` or even `StudioSkin` on any instance locally; none of it replicates, and every live gate is IsStudio-gated, so the only effect is on that client's own picture (see P5F-29 for the minor note).
- checked, clean: SkinCatalog id collisions (all 22 Ids unique, Id == table key everywhere), composite parsing (`Split` / `Resolve` handle "<Skin>+<Wrap>" and fall back to the skin alone when the wrap is not offered), every Rework skin has a Kit module (Devil → RadiantDevilForge/RadiantFX_*; Frostblade/FrostLotus/SnowGlobe/FrostDragon → *Kit.lua), every wrap Element has a wrap module (Cryo → CryoWrap, Toxin → ToxinWrap, Terra → TerraWrap, Pyro → PyroDraw.WithWrap, Umbra → UmbraFX wrapOf, Radiant → RadiantDraw palette), Pyro's "RingofFire" key matches PyroFX.lua:2482-2483.
- checked, clean: no prices in the catalog and nothing sells a skin (OwnsSkin is `Skins[id] ~= nil`), so no economy path runs through SkinCatalog.
- checked, clean: Camera Shake. Every in-game camera kick routes through Viewmodel.Punch/Shake (Viewmodel.lua:2749, scaled by CameraShake, zeroed by Reduce Flashing) or ZephyrDraw's kick (ZephyrDraw.lua:1080-1091). The other camera/FOV writes found (ZephyrFX_CrossSlash 1539-1576, ZephyrFX_Skyrider 2408/2427, CryoFX 3553) are demo/preview cameras.
- checked, clean: Voltaic's Reduce Flashing / Reduce Enemy VFX coverage — OverchargeFX, ChainBoltFX, RailspikeFX, CascadeFX, VoltOrbFX all route through VoltaicKit.reduceFlashing / Kit.thin / Kit.bloomPulse even though they never name the setting.
- checked, clean: Zephyr's Skyrider / Gust Pad / Updraft route Density and Reduce Flashing through ZephyrDraw (opts.Own / ZD.Density / ZD.CameraKick).
- checked, clean: BarFX sprite references — all static sprite names in the 24 variants exist in Atlas.lua (322 sprites, 8 pages; max page index 8 = #images); the only "misses" in the scripted check are dynamic prefixes (`"marked-a/fgt" .. n` etc.) whose numbered forms exist.
- checked, clean: Settings validation (Coerce/Sanitise never error; KEY_NAMES table avoids the Enum-index throw; NaN guarded) and SettingsStore server-side re-sanitising + MIN_GAP rate limit (a client can only spoil its own settings).
- checked, clean: Luau 200-local limit for my four files (counts in P5F-30) — none at risk today.
- checked, clean: CastPose writes only client-local Attachment0.CFrame/C0 values (CastPose.lua:1970-1995); nothing it does replicates or moves server-side hit geometry.
- checked, clean: Callouts.lua — every status callout is a WORD (CHILL xN, BURN xN, FROZEN!, HUNTED!...), so colour is never its only cue under any palette.
- checked, clean: BarKit health (red, top) vs mana (blue, below, thinner) are separated by position and size, not only colour.

---

#### P5F-01: Temporary "stage" scripts are ungated: on a live server they anchor every player, hide every ScreenGui, and clone the first player's avatar into the world
> **Consolidator:** duplicate of **P1-05** (Temporary stage scripts ungated (if Enabled)). Kept here for its slice-specific detail; counted once, under P1-05.
- **Severity:** High (game-breaking if enabled live)
- **Confidence:** Medium (the code is unambiguous; whether these scripts are Enabled in the live place is NOT recorded in manifest.json)
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua:1-18`, `game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua:1-11`, `game/ServerScriptService/_AuroraStage.server.lua:1-106`, `game/ServerScriptService/_BROStage.server.lua:1-101`, `game/manifest.json:24925,24930,38155,38165`
- **Trigger:** Any live server where these four scripts are Enabled (they are present in the place tree per the manifest; each header says "TEMPORARY ... remove when done").
- **Why it's a bug:** `_AuroraStageClient` runs on every client with no `IsStudio()` gate: `ch:WaitForChild("HumanoidRootPart").Anchored = true`, `ch:PivotTo(... (-90, 4, 0) ...)`, then `for _, g in ipairs(plr.PlayerGui:GetChildren()) do if g:IsA("ScreenGui") then g.Enabled = false end end` — every player is frozen in place and loses the whole HUD (PopArtHUD, SettingsMenu gear, StatusReactions, BarFX hosts). `_AuroraStage` (server, ungated) waits for the first player's character, sets `ch.Archivable = true` on it and clones it three times into `workspace.WrapStage` (anchored, Humanoid intact, `WrapStudio = "Aurora"`), sets `StageReady`, which releases `_BROStage` to clone 8 more Humanoid dummies into Persistent models; `_BROStageClient` adds a permanent 24 px coloured `_ShotTag` ScreenGui on every client. The WrapStudio attribute itself is inert live (all reads are Studio-gated), but the clones are real Humanoid models that CombatCore treats as dummies ("Training dummies are not players and take everything", SpellshotConfig.lua:178) and that every VFX "is this another player?" test (VFXLibrary.lua:951-960) counts as another player.
- **Suggested fix:** Delete the four stage scripts from the place (their own headers ask for it), or at minimum gate each with `if not RunService:IsStudio() then return end` at the top.
- **Notes:** Cross-ref whoever audits ServerScriptService/StarterPlayerScripts inventory. Also see P5F-21 for what `_BROStage` does to the player's saved settings.

#### P5F-02: The third-person toggle (V) ships enabled for every player in ranked matches
- **Severity:** High (competitive integrity)
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/FirstPersonController.client.lua:43-61, 403-409`
- **Trigger:** Any player, any mode, presses V.
- **Why it's a bug:** `local ALLOW_THIRD_PERSON_TOGGLE = true` and the binding at 403-409 has no Dev or Studio check. The file's own comment: "FLAGGED, NOT DECIDED HERE: free third person in a ranked duel sees around corners and over cover that first person cannot. Whether this ships to every player is a competitive-integrity call for the owner". The code ships it. A 7-stud shoulder camera (TP_DISTANCE/TP_SHOULDER) peeks cover in Duel, 2v2 and Squad Clash.
- **Suggested fix:** Default the gate to false, or gate the binding on `Config.IsDev(player)` / `RunService:IsStudio()` until the owner decides.
- **Notes:** Known/flagged by the author, but it is live behaviour, not a TODO.

#### P5F-03: Reduce Flashing is never read by Umbra, Radiant (incl. Devil), Aqua, most of VFXLibrary's own flashes, DeathFX, or the viewmodel palm flash
- **Severity:** Medium (accessibility / photosensitivity)
- **Confidence:** High (grep-verified: none of these modules contains "ReduceFlashing" or routes through a helper that reads it)
- **Files/lines:** `game/ReplicatedStorage/IceMagic/UmbraFX.lua:2276-2353` (Eclipse pulse: a full-screen `ColorCorrectionEffect` on Lighting enabled with TintColor/Brightness/Saturation over Rise 0.06 s + a PointLight Brightness 3 Range 60, `UmbraTuning.lua:355-359`), `UmbraFX.lua:1386-1432` (Mark headshot glint flash: PointLight + swelling billboard disc); `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua:1352-1380` (Position Trade gold body Highlight flash, FillTransparency down to 0.2) and RadiantDraw LightPools; `game/ReplicatedStorage/IceMagic/AquaFX.lua:885-919,1429-1455` (Twin Tide jet's Neon flash); `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:2705-2722` (Flash Freeze: zone light + burstLight 3 at the break + 2.2 at the rim wave), `2751` (press flash 3), `4804-4817` (ShatterFX FormFlash + PointLight 5), `1344-1350` (BOULDER_KIT.Flash, Brightness 2), `1676-1682` (SURGE_KIT.Flash, Brightness 4); `game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua:56-86` (white burst stamp over every death); `game/ReplicatedStorage/IceMagic/Viewmodel.lua:2793-2794` (M1 palm ShotFlash 4).
- **Trigger:** Reduce Flashing = on; any Umbra Eclipse (the CC pulse is screen-wide on every client, independent of distance — only the ribbons are culled by `far()`), any Radiant Position Trade, Aqua Twin Tide, Cryo Flash Freeze / shatter, Terra Boulder Shot impact, any death, your own M1.
- **Why it's a bug:** The setting's row promises "Softens the full-screen impact bursts and the vignette" (SettingsMenu.client.lua:227) and the brief requires it uniformly. The only VFXLibrary read is TerraBurst's size (VFXLibrary.lua:1172). Eclipse's pulse is exactly the "full-screen impact" class the row names.
- **Suggested fix:** Add a shared `calm()` (as VoltaicKit.reduceFlashing does) and apply it at each site: skip/halve `burstLight`, cap ColorCorrection pulse amplitude and lengthen Rise, drop FormFlash/BOULDER Flash/SURGE Flash emits, shrink DeathFX's stamp, and gate Viewmodel's ShotFlash.
- **Notes:** Settings-consumer matrix in Appendix A lists every module.

#### P5F-04: The default status-bar looks (BarFX) ignore Status Intensity and Reduce Flashing; StatusReactions — the documented applier — steps aside for them
- **Severity:** Medium (accessibility; the HUD slider does nothing for the 8 bar statuses)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:40, 459-466, 621-641, 713-718`; `game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua:137-149, 228-232, 696`; `game/ReplicatedStorage/Spellshot/BarFX/Variants/primed_t.lua:206-270` (and every variant's `fx.shake`, e.g. marked_*:132/150/166 amp 7 for 0.72 s, blessed_*:145-165 amp 6-10)
- **Trigger:** Default dev-panel pick (`BarFX_<kind>` nil → "t"), Status Intensity < 100 or Reduce Flashing on, any of burn/chill/poison/charged/marked/blessed/primed/shield on the local player.
- **Why it's a bug:** StatusReactions applies `StatusIntensity` and `ReduceFlashing` only to its own two CanvasGroups (137-149) and, unless the pick is "old", hands those statuses to BarFX (696). BarFX's step sets its GroupTransparency from HUD Opacity only (715-718: the comment says "and the status intensity setting" but no setting is read), no variant requires SpellshotSettings, and `fx.shake` moves the whole health row with no Reduce Flashing / Camera Shake check (621-641). primed_t's last third toggles the casing gradient every 0.2 s (`(fx.clock % 0.4) < 0.2`, a 2.5 Hz red/yellow flicker) and calls `fx.shake(1.5, 0.05)` every frame — exactly the case StatusReactions' own `PrimedPulseCalm` was written to calm (StatusReactions.client.lua:73-84).
- **Suggested fix:** In BarFX.step multiply Host back/front/bar GroupTransparency by `Settings.Scale("StatusIntensity")`; make `BarFX._shake` a no-op (or ×0.35) under Reduce Flashing and scale by Camera Shake; give primed_* a calm path (no toggle under Reduce Flashing).
- **Notes:** Variant selection (_a/_f/_t) is NOT by Graphics Quality — they are three art directions (Assault / Living Fill / Takeover) picked by the LocalPlayer attribute `BarFX_<kind>` (dev panel), default "t" (BarFX.lua:5-9, 39-40). No Graphics Quality scaling exists in BarFX at all (particle cap 40 per look, fixed).

#### P5F-05: Graphics Quality and Reduce Enemy VFX are never read by three whole Elements (Umbra, Aqua, Radiant incl. the Devil skin)
> **Consolidator:** canonical entry for: Graphics Quality / Reduce Enemy VFX unread by Umbra, Aqua, Radiant. Also reported as **P5C-08**, **P5C-09**.
- **Severity:** Medium (settings honouring / performance; a busy Squad Clash with Umbra/Aqua/Radiant is never thinned)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/UmbraFX.lua` (2686 lines, 0 reads), `UmbraClient.lua`, `AquaFX.lua` (2403 lines), `AquaClient.lua`, `RadiantDraw.lua`, `RadiantFX_Hand.lua`, `RadiantFX_Staff.lua`, `RadiantDevilForge.lua`, `RadiantAnim.lua`, `RadiantClient.lua` — none contains EffectDensity / ThinEnemyVFX / ReduceEnemyVFX, none calls VFXLibrary.Emitter or a density helper (Appendix A).
- **Trigger:** Graphics Quality LOW/MEDIUM, or Reduce Enemy VFX on, against an Umbra/Aqua/Radiant opponent.
- **Why it's a bug:** SettingsRuntime publishes `Settings.EffectDensity` / `Settings.ThinEnemyVFX` (SettingsRuntime.client.lua:136-151) for "every emitter it builds", but these kits draw with Beams/meshes/billboards/PointLights of their own (RadiantDraw's own `Budget = { Pieces = 80, Glints = 40, Lights = 3 }`, line 165, is a fixed budget, not density-scaled). Their output is identical at LOW and ULTRA and for own vs enemy casts.
- **Suggested fix:** Give each a density read (Umbra's ribbon counts/wisps, Aqua's TT flipbook and drops, Radiant's Canvas budget × `Settings.EffectDensity` × enemy factor), mirroring ZephyrDraw.Density(own).

#### P5F-06: "Enemy" for Reduce Enemy VFX means "anyone who is not my character": teammates, dummies, and (briefly) your own effects are thinned
> **Consolidator:** canonical entry for: Reduce Enemy VFX thins teammates ("enemy" = not me). Also reported as **P5D-06**, **P5E-05**, **P5B-06**.
- **Severity:** Medium (team modes: you lose detail on allies' effects — heals/shields/zones you are meant to use)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:951-960` (`onAnotherPlayer`: any ancestor Model with a Humanoid that is not `VFXLibrary.LocalCharacter`), `2792`, `3030-3031`, `3122-3123`, `3497-3498`, `5378`; `VoltaicKit.lua:340-351`; `ZephyrDraw.lua:1098-1106`; `PyroDraw.lua:406-413`; `CryoFX.lua:291-300`; `FrostLotusFX.lua:33`; `SnowGlobeFX.lua:34`; `CryoWrap.lua:1120,1397`; `FirstPersonController.client.lua:241-260, 275-279`; `SpellshotConfig.lua:181-192` (MayHurt / MatchTeam exist client-side)
- **Trigger:** (a) Team match (Config.Team.Size = 3; "2v2 / Squad Clash"): every teammate's cast is thinned exactly like an opponent's. (b) Training Grounds / AllyDummies: effects hung on a dummy (frozen look, crusts) count as "another player". (c) The first ≥0.35 s of every life (FirstPersonController waits `task.wait(0.35)` + Viewmodel.Build before setting `LocalCharacter`, and nils it on CharacterRemoving): during that window your own effects are thinned; `FrostSlideDashFX` (3030-3031) even treats a nil caster as enemy. (d) A spectator after death: the subject you watch is thinned.
- **Why it's a bug:** The setting is "Reduce ENEMY VFX"; the replicated `MatchTeam` + `Config.MayHurt(caster, victim)` already answer "is this an opponent" on every client, but no FX module uses them. Ally-only effects (Radiant Blessing/Benediction once thinned per P5F-05's fix, Gust Pad, Toxin Symbiosis) lose readability for exactly the players they help.
- **Suggested fix:** One shared `VFXLibrary.IsEnemy(casterCharacter)` = `caster ~= LocalPlayer.Character and Config.MayHurt(casterPlayer, LocalPlayer)` (dummies → false unless in a Training opponent role), used by every module instead of `~= LocalCharacter`; use `Players.LocalPlayer.Character` as the fallback while LocalCharacter is nil.
- **Notes:** Inconsistent factors across modules (0.5 VFXLibrary/Terra/Voltaic, 0.6 PyroDraw/ZephyrDraw EnemyThin, whole-layer skips in CryoFX:1902/2094 and VFXLibrary `bare`, 0.8 size in TerraBurst) against the menu text "Halves the particles on other players' characters" (SettingsMenu.client.lua:139). Also `CryoFX.lua:4613` thins the chill crust under Reduce Enemy VFX regardless of whose body it is (`or Settings.ThinEnemyVFX`, no owner test), including your own.

#### P5F-07: Shared hazards are thinned as "enemy" — Gust Pad (launches anyone) and the Frostblade Flash Freeze edge
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrGustPad.lua:995-1003, 1094` (`Own = pad.Own`), `ZephyrDraw.lua:615, 1098-1106` (density × 0.6 when not own), `ZephyrGustPadServer` header line 22 ("any body -- the caster, allies, enemies, training and ally dummies -- whose root is within Radius"); `game/ReplicatedStorage/IceMagic/CryoFX.lua:1898-1902` (`FrostbladeEdge`: `return` for an enemy under Reduce Enemy VFX) with `VFXLibrary.lua:2794-2803, 2841` (Frostblade suppresses the Default crystals via the `noCrystals` argument)
- **Trigger:** Reduce Enemy VFX on; (a) any pad not cast by you (enemy or ally) — it will still launch you; (b) an enemy Flash Freeze cast with the Frostblade skin.
- **Why it's a bug:** (a) The pad is a hazard/tool for everyone, but its draw is cut to 60% of spans for every non-owner. (b) For a Default zone, `bare` keeps "its Frost Line, its floor and its rim clusters (the edge)" (VFXLibrary.lua:2787-2790); for a Frostblade zone the kunai rim is skipped entirely and the crystals are suppressed, so the viewer keeps only the floor and the dimmed Frost Line (`FF2.Calm`, width 0.12, transparency 0.3) — a skin+setting combination loses the edge telegraph the Default keeps.
- **Suggested fix:** Never thin the hazard-defining layer of a shared zone/pad; in FrostbladeEdge keep a reduced count of edge kunai under Reduce Enemy VFX instead of returning.

#### P5F-08: Colourblind-Safe only repaints the uniform; no hazard, HUD, status bar, callout or viewmodel colour reads it
- **Severity:** Medium (accessibility; the row claims more than it does)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:144-161, 311-315`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:296-359`; `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:224-225`
- **Trigger:** Colourblind-Safe on.
- **Why it's a bug:** `Settings.ElementColor` is called from exactly one place (SettingsRuntime `tonesFor`, line 312). Grep of game/ for "ColorblindSafe" finds only SpellshotSettings, SettingsRuntime, SettingsMenu and the Studio stage. So every VFX palette (all 73 IceMagic modules), BarFX's `C` table (BarFX.lua:56-68), PopArtHUD's Role glyph/charge-ring colours, Viewmodel's glow (`def.Light`, Viewmodel.lua:1793/1830), StatusReactions' ELEM_TINT and the server Callouts are unchanged. The menu says "Applies where a colour is chosen in code; icon art keeps the colour it was drawn with." For hazards specifically this is mostly survivable because each hazard has a distinct shape (Flash Freeze ring+crystals, Ring of Fire flame wall, Acid Rain drops, Corrosive Cloud lobes, Aftershock rock ring, Volt Orb burst), but it also means a Terra player's uniform turns purple (120,78,158) while every Terra effect stays brown/gold — the uniform and the hazard no longer share a colour for that viewer.
- **Suggested fix:** Either narrow the row's description to "player uniforms", or route Element accent colours through `Settings.ElementColor` in the HUD (glyph tint, charge ring), BarFX and the moved Elements' (Terra, Toxin) hazard accents.
- **Notes:** Hazards whose ONLY distinguishing cue would be colour: none found by shape inventory; but see P5F-24 for wraps that move a hazard into another Element's hue.

#### P5F-09: Aqua is missing from the colourblind palette, so Colourblind-Safe paints every Aqua player gold
> **Consolidator:** canonical entry for: Colourblind-Safe paints Aqua gold. Also reported as **P5D-01**.
- **Severity:** Medium (misidentification of an opponent's Element for that viewer)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:148-161, 311-315`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:309-317`; `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:345-347` (Aqua exists)
- **Trigger:** Colourblind-Safe on, any Aqua player (Aqua is a BuiltElement, SpellshotConfig.lua:678).
- **Why it's a bug:** `ElementColors` has 8 entries, no Aqua. `ElementColor("Aqua")` hits `if not pair then return Color3.fromRGB(245, 184, 0) end` (gold). `tonesFor` then sees `base ~= def.Base` and derives torso/sleeve/hand from GOLD — the Voltaic/Radiant/"Ultimate ready" gold the Callouts header says must never be confused (Callouts.lua:83-88).
- **Suggested fix:** Add `Aqua = { Color3.fromRGB(38, 140, 176), Color3.fromRGB(38, 140, 176) }` (its Config Base twice, matching "not moved" by bit-equality as the Pyro comment requires), and make `ElementColor`'s fallback return nil so `tonesFor` keeps `def.Base`.

#### P5F-10: The "safe" palette moves five Elements (not the two pairs it claims) and creates a new collision: Zephyr white vs Radiant near-white
> **Consolidator:** canonical entry for: Colourblind palette moves 5 Elements; Zephyr~Radiant. Also reported as **P5E-02**, **P5C-10**, **P2-12**.
- **Severity:** Medium (accessibility)
- **Confidence:** High (values); Medium (perceptual impact)
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:144-161`; `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:224-225, 914-923`
- **Trigger:** Colourblind-Safe on, Zephyr and Radiant (or Umbra) players in one match.
- **Why it's a bug:** Header: "Only the pairs that actually collide are moved: Pyro/Terra ... and Toxin/Cryo." Code moves Terra → (120,78,158), Zephyr → (255,255,255), Umbra → (20,20,20), Radiant → (240,240,240), Toxin → (0,122,94); Cryo is NOT moved. Zephyr (255,255,255) and Radiant (240,240,240) torsos are 15 levels apart (and their derived hands both lerp toward white, sleeves both ~165 grey) — two different Elements become indistinguishable for every viewer who turns the setting on, colour-blind or not. Umbra's black torso also merges with the neutral slate head/legs (58,64,78) at range.
- **Suggested fix:** Pick a safe palette with pairwise ΔE checked across all 9 Elements (incl. Aqua) under protan/deutan/tritan simulation; keep unmoved Elements at their Base; fix the header and the menu description.

#### P5F-11: Colourblind repaint is lost after an Element change (and can lose the race on spawn)
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:339-355`; `game/ServerScriptService/UniformAvatar.server.lua:109-140, 168-173`
- **Trigger:** Colourblind-Safe on; a player changes Element (Hub shrine / loadout) without respawning, or a slow ApplyDescription on spawn (> 0.6 s).
- **Why it's a bug:** On `Element` change the client paints immediately (350-354); the server's `applyUniform` is `task.defer`'d and yields in `ApplyDescription`, then writes `part.Color` for sleeves/hands (and the new limbs carry the description's TorsoColor). Those server writes replicate after the client's local paint and overwrite it; nothing repaints again until the next CharacterAdded. On spawn the client repaints after a fixed 0.6 s guess.
- **Suggested fix:** Repaint on `ChildAdded`/`Color` change of the painted parts (or a short re-paint after `DescendantAdded` settles), not on fixed delays.
- **Notes:** UniformAvatar also connects a new `character.DescendantAdded` strip handler on every Element change (line 144), stacking connections on one character — harmless but a leak (Low).

#### P5F-12: A DataStore read failure silently resets a player's settings — and the next change overwrites their real save with defaults
> **Consolidator:** duplicate of **P2-08** (SettingsStore failed load -> defaults saved over real). Kept here for its slice-specific detail; counted once, under P2-08.
- **Severity:** Medium (data loss of accessibility settings, e.g. Reduce Flashing silently off)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SettingsStore.server.lua:68-81, 101-107, 114-126, 83-99`
- **Trigger:** A transient `GetAsync` error on join (throttle, outage) on a live server.
- **Why it's a bug:** `load` returns nil on any error (73-79); PlayerAdded stores `Settings.Sanitise(nil)` = all defaults with `dirty = false` and sends them to the client, which `Settings.Load`s them. The first setting the player touches pushes a full snapshot; the server marks it dirty and `SetAsync` writes defaults+one change over the saved table. No retry, no "load failed, do not save" flag; `warnOnce` is global so it is silent after the first. For a photosensitive player this means flashes on for the session and the saved preference destroyed.
- **Suggested fix:** Track `loadFailed` per player; retry GetAsync with backoff; refuse to SetAsync (or use UpdateAsync merging only changed keys) until a load has succeeded.
- **Notes:** Also: players already in the server before the script connects are never initialised (no loop over `Players:GetPlayers()`), and a player leaving while `GetAsync` is in flight leaves `state[player]` set after PlayerRemoving (small leak). Low.

#### P5F-13: Entering the Hub or a map forces `Lighting.GlobalShadows = true`, overriding Graphics Quality LOW/MEDIUM
- **Severity:** Medium (settings honouring / performance on low-end devices)
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:136-147`; `game/StarterPlayer/StarterPlayerScripts/HubClient.client.lua:408-413, 425-490`; `game/ReplicatedStorage/Spellshot/MapRegistry.lua:87, 200, 230`
- **Trigger:** Graphics Quality LOW or MEDIUM (shadows=false), then any zone change (join → Hub, Hub → Arena, Arena → Hub).
- **Why it's a bug:** SettingsRuntime writes `Lighting.GlobalShadows` only from `Settings.Bind("GraphicsQuality")` (startup + changes). HubClient's `applyLighting` copies the universal/map `Light.Props` (`GlobalShadows = true`) onto Lighting on every profile change, and `restoreLight` later puts back whatever was saved when the profile started — so a quality change made while in a zone is also undone on leaving. Result: shadows on for LOW/MEDIUM players almost all the time. Viewmodel's light model also keys off GlobalShadows (Viewmodel.lua:2383-2385).
- **Suggested fix:** Exclude GlobalShadows from the profile copy (or AND it with the quality tier), and re-apply SettingsRuntime's tier after each profile apply/restore.

#### P5F-14: Graphics Quality tiers are inconsistent: MEDIUM is not "thin" anywhere in the `< 0.75` gates, ULTRA exists, skins use a different tier boundary
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:61`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:136-141`; `VFXLibrary.lua:2793, 3030, 3122, 3498, 5378`; `CryoFX.lua:292, 1187, 1753, 1829, 2778`; `PyroFX.lua:614`; `PyroFlame_Fire.lua:458`; `VoltaicKit.lua:349` and `CryoWrap.lua:1397` (`< 0.6`); `FrostbladeKit.lua:58-62` (and SnowGlobe/FrostLotus/FrostDragon Tier: `>= 0.9` high, `>= 0.6` medium)
- **Trigger:** Graphics Quality MEDIUM (density 0.75).
- **Why it's a bug:** Four options (LOW/MEDIUM/HIGH/ULTRA = 0.45/0.75/1.00/1.15) but every binary thin gate in the Default kits is `EffectDensity < 0.75`, false at exactly 0.75, so MEDIUM draws every layer HIGH does (only continuous emitter Rates drop 25%). Cryo skins, by contrast, give MEDIUM a real middle tier. The brief and menu describe high/medium/low; ULTRA only raises rates.
- **Suggested fix:** Expose a single `Settings.QualityTier()` (1-4) and gate on it everywhere; decide what MEDIUM removes.

#### P5F-15: CryoWrap reads "ThinEnemyVFX" through Settings.Get, which always returns nil — Reduce Enemy VFX never thins Cryo wrap extras
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/CryoWrap.lua:1014-1021, 1120, 1397`; `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:50-51, 224-231`
- **Trigger:** Reduce Enemy VFX on, an opponent wearing an Epic Cryo wrap (Sakura Frost motes, line 1120) or the Cold Momentum aurora ribbon (1397).
- **Why it's a bug:** `setting(k)` returns `s.Get(k)` for every key except "Density". `ThinEnemyVFX` is a plain field, not a setting id; `Settings.Get("ThinEnemyVFX")` finds no value and no def → nil, so `setting("ThinEnemyVFX") == true` is never true. (The Density branch and `setting("ReduceFlashing")` work.)
- **Suggested fix:** `if k == "ThinEnemyVFX" then return s.ThinEnemyVFX end` (or read `Get("ReduceEnemyVFX")`).
- **Notes:** Cross-ref the CryoWrap pass.

#### P5F-16: Effect settings are baked at emitter creation; pooled looks never pick up a Graphics Quality change, and effects drawn before the save arrives use defaults
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:987-1001` (rate scaled once), `4972-5130` (Icicle Shard looks: Glint/Wake/Flecks emitters made once and pooled, IS.PoolMax 9 per pool), `3392-3424` (Chill Aura pool), `2182, 2757` (FF pool); `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:61, 124, 214-217`
- **Trigger:** Changing Graphics Quality mid-session; or the first seconds of a session before SettingsSync answers (defaults HIGH, Reduce Flashing off, Reduce Enemy VFX off).
- **Why it's a bug:** `Settings.EffectDensity` is documented as "read at the moment it is made" (SpellshotSettings.lua:48-49) — but pooled looks are made once and reused for the session, so a player who drops to LOW keeps HIGH-rate wakes on every Icicle Shard until the pool turns over (it doesn't). Before load, a LOW-quality / Reduce-Flashing player is drawn at defaults (HIGH, flashing on) — visible in the Hub on join.
- **Suggested fix:** Re-apply density in `acquireShardLook` (store the preset Rate and rescale on acquire), flush pools on GraphicsQuality change; consider persisting the two accessibility toggles client-side (local cache) so they are known before the server answers.

#### P5F-17: Settings.Load discards a change the player made before the save arrived
> **Consolidator:** duplicate of **P2-09** (Settings changed before load are lost). Kept here for its slice-specific detail; counted once, under P2-09.
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:89-92`; `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:342-356, 384-393, 420-422`
- **Trigger:** Player opens the menu and toggles e.g. Reduce Flashing in the first moments after join, before SettingsSync's reply.
- **Why it's a bug:** `Load` overwrites every id with the saved value (silent Set), then `MarkSaved()` clears the pending push, so the player's change is reverted with no feedback and never saved.
- **Suggested fix:** In Load, skip ids the player changed since startup (track a "touched" set), and do not clear pushDirty if anything was touched.

#### P5F-18: HUD keybind chips are hardcoded F/Q/E/R and ignore rebinding and gamepad binds
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterGui/PopArtHUD.client.lua:102, 499-509`; `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:115-124` (binds are read from Settings)
- **Trigger:** Any player who rebinds Primary/Technique/Ultimate in Controls, or plays on a pad.
- **Why it's a bug:** `KEY_LABEL = { Primary = "F", Mobility = "Q", Defense = "E", Ultimate = "R" } -- the binds in SpellshotInput`; the chip text is set once and never bound to `Bind_<role>` / `Pad_<role>`.
- **Suggested fix:** `Settings.Bind("Bind_" .. role, ...)` and render `keyText(Settings.Get(...))` (SettingsMenu has the formatter), switching to the Pad column when the last input is a gamepad.

#### P5F-19: Settings menu Text Size is lost on tab switch and static labels stop rescaling after the first change
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:1083-1121, 1234-1251`
- **Trigger:** Text Size ≠ 100, then click another tab; or change Text Size twice.
- **Why it's a bug:** `selectTab` rebuilds the rows without calling `applyMenuTextSize`, so a tab switch shows authored sizes. `applyMenuTextSize` marks each label `Scaled` and scales it from its current size; the gear, tab buttons, bubble and close X are never rebuilt, so after the first change they keep the first scale forever (and `k == 1` returns early, so going back to 100 never unscales them).
- **Suggested fix:** Record each label's authored TextSize once (as PopArtHUD's `textBase` does) and always set `authored * k`; call it at the end of `selectTab`.

#### P5F-20: Doc drift in the settings UI and palette comments
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua:139, 224-225, 914-923`; `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:14-23, 144-147`; `game/ReplicatedStorage/Spellshot/Callouts.lua:83-86`; `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:5-6`; `game/ReplicatedStorage/Spellshot/IconAssets.lua:139` vs `SkinCatalog.lua:272`
- **Trigger:** n/a (reading the UI/comments).
- **Why it's a bug:** The menu's palette preview hardcodes its own colours (stale Pyro (233,78,27) that the Settings comment says was fixed on 2026-09-21; no Aqua chip) instead of `Settings.ElementColors`; its Colourblind text names Pyro/Terra and Toxin/Cryo while the palette moves Terra, Zephyr, Umbra, Radiant, Toxin (P5F-10); the Reduce Enemy VFX text says "halves the particles" (P5F-06); the Settings header's owner list says StatusReactions applies status intensity/reduce flashing (BarFX now owns those statuses, P5F-04); Callouts says Voltaic is "one of two Elements that do NOT change" (three do: Pyro, Cryo, Voltaic, plus missing Aqua); SkinCatalog's header says "A skin changes COLOUR only: no shape" while Rework skins replace shapes; IconAssets calls Snow Globe "Epic" while SkinCatalog files it Rare.
- **Suggested fix:** Read the preview chips from `Settings.ElementColors` over `Config.Elements` (all 9); update the texts.

#### P5F-21: A partial SettingsSync payload resets every other setting to default (and `_BROStage` sends exactly that)
> **Consolidator:** duplicate of **P2-11** (Partial SettingsSync payloads reset all settings). Kept here for its slice-specific detail; counted once, under P2-11.
- **Severity:** Low (dev tooling, but fragile protocol)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/_BROStage.server.lua:74, 76, 93, 95`; `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:202-209, 384-393`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:89-92`
- **Trigger:** `_BROStage`'s `run()` (BroGo attribute set server-side): `sync:FireClient(pl, { ColorblindSafe = true })`, later `{ ReduceFlashing = true/false }`.
- **Why it's a bug:** `Load` → `Sanitise` fills every id missing from the table with its DEFAULT, so the player's whole configuration (binds, sensitivity, volumes, accessibility) snaps to defaults; `MarkSaved` means it is not pushed immediately, but the next change the player makes pushes the defaulted snapshot and SettingsStore saves it.
- **Suggested fix:** Treat server→client payloads as full snapshots only (document it), or add a "patch" message kind that Sets only the listed ids. Remove the stage script (P5F-01).

#### P5F-22: SkinCatalog internal consistency gaps
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:27-37, 80, 211, 242, 253-256, 278-282, 337-338, 364-394, 397-410, 432, 457-458, 493-507`
- **Trigger:** n/a (data).
- **Why it's a bug:** (a) `Rarity` is missing on Rainbow, ObsidianMagma, AzureFlame, Bloodmoon, Devil and Frostblade (comment calls Frostblade "an Uncommon Element Skin"), so any rarity-sorted shop/loadout or the skin-tier rules cannot place them. (b) FrostDragon is "IN BUILD -- stage 1 ... its other pieces draw the Default" yet listed in `ElementSkins.Cryo` and `OwnsSkin` is true for everyone, so an unfinished Mythic is selectable live. (c) BlueRingedOctopus (Toxin, Epic) and Aurora (Cryo, Mythic) are fully defined but absent from `ElementWraps` — unreachable live (correct if intended; their drawing code still loads). (d) Offer/ElementSkins/ElementWraps cover only Radiant, Pyro, Terra, Umbra (Offer), Radiant+Cryo (skins), Cryo+Toxin (wraps): Aqua, Voltaic and Zephyr have no cosmetics at all; `WrapIcon` covers only Radiant and Pyro. (e) `Kinds` (prefix → ability) only covers Radiant and Terra broadcasts, and `AbilityOfKind` iterates `pairs` (order undefined) so any future overlapping prefixes would resolve nondeterministically. (f) `Chosen` silently drops a material wrap (Stages/Flame/Shadow) when an Element skin is on — today only reachable for Radiant, whose only wrap (Rainbow) has Stops.
- **Suggested fix:** Add Rarity to every non-Default skin; hide IN-BUILD skins behind a `Released = false` flag checked by `ElementSkinAllowed`; make AbilityOfKind longest-prefix-wins.
- **Notes:** Full enumeration in Appendix B. How another player's cosmetic is resolved: always client-side from the caster's replicated Player attributes (`ElementSkin_<Element>`, `ElementWrap_<Element>`, `Skin_<ability>`) via `SkinCatalog.ElementSkin/ElementWrap/Chosen`, each validated (Element must match, id must be listed, OwnsSkin); the server additionally stamps `data.Skin` on Radiant/Terra broadcasts (RadiantHandler.server.lua:81-85, TerraHandler.server.lua:54-58) and `RX_Chilled_Skin` (AbilityHandler.server.lua:751-752). Fallback is "Default" everywhere. Cryo kits check `(plr:GetAttribute("Element") or "Cryo") ~= "Cryo"` (FrostbladeKit.lua:37; CryoWrap.lua:932) but ToxinWrap does not check the caster's Element (ToxinWrap.lua:40) — latent: only with TechniquesOwnElementOnly = false would a non-Toxin borrowing Acid Rain draw it in their Toxin wrap while a borrowed Cryo Technique draws Default.

#### P5F-23: VFXLibrary's Frost Dragon M1 look is never painted by a Cryo wrap worn over the skin
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:5046-5090`
- **Trigger:** A Frost Dragon wearer who also wears a Cryo wrap (e.g. Mint Rime), firing Icicle Shard.
- **Why it's a bug:** The "globe" and kunai/lotus branches call `VFXLibrary.Wrap.PaintKit(g/k)` ("a wrap over the skin"); the "dragon" branch returns its look with no PaintKit call, so the wyrmling ignores the wrap while the rest of the kit wears it (FF uses `fdkit.GradeFF`, separately).
- **Suggested fix:** Call `VFXLibrary.Wrap.PaintKit(look)` in the dragon branch too (or document the exception).
- **Notes:** Cross-ref the Cryo skins pass.

#### P5F-24: Some wraps change how visible a hazard or projectile is to the opponent (cosmetic → readability)
- **Severity:** Low
- **Confidence:** Low (static values only; visual effect needs Play)
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:315-331` (SakuraFrost `Over` at 321-322: `IS2.Width 0.28` vs Default 0.17, `IS2.TrailWidth 0.16` vs 0.05, `FF2.SpikeT 0.45` vs 0.22), `297-313` (BlackIce: near-black bodies #0A0A0C, Foil), `337-360` (Aurora: `Over` at 350-352,: `FF2.RimCount 104` vs 80, `RimH {1.9, 2.9}` vs {1.6, 2.5}; not reachable live), `100-118` (Nightshade: grey-plum gas), `120-137` (CoralSnake: red/yellow/black gas — the file itself notes the "fire read"), `80-85` (AzureFlame: Pyro flame recoloured into Cryo's blue/cyan family)
- **Trigger:** Opponent wears one of these wraps.
- **Why it's a bug:** "Cosmetics must never change gameplay." None of these touch hitboxes or timing, but they change contrast/size of the thing the opponent must read: a 65% wider shard and 3x trail make a Sakura shot easier to see (a handicap), more see-through crystals make the zone easier to see through, a black zone on a dark map or a grey cloud is harder to spot, and an azure Ring of Fire sits in the same hue family as Flash Freeze's cyan Frost Line (shape still differs). Colourblind-Safe cannot compensate (P5F-08).
- **Suggested fix:** Keep hazard-defining layers (zone edge, cloud silhouette, projectile core) at Default contrast/size under every wrap; allow wraps to recolour only fill/ornament.

#### P5F-25: AbilityFX small leaks/races
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua:215-248` (`lastStep` at 219, keyed by character, not weak; only the CURRENT character is cleared on PlayerRemoving), `1019-1074` (Voltaic/Umbra/Radiant/Toxin/Zephyr handlers merged in `task.spawn` after `WaitForChild(..., 10)`), `1076-1080` (OnClientEvent connected)
- **Trigger:** (a) Every respawn of a Cryo-with-Passive player leaves one dead character key in `lastStep`; (b) a broadcast of a Voltaic/Umbra/Radiant/Toxin/Zephyr kind arriving after OnClientEvent connects but before that module's spawned require finishes is silently dropped (`handler == nil`).
- **Why it's a bug:** (a) unbounded table growth over a long session; (b) a late-join replay (e.g. a pad already placed) can be missed.
- **Suggested fix:** `setmetatable(lastStep, { __mode = "k" })`; queue unknown kinds for a few seconds, or connect OnClientEvent after the merges.

#### P5F-26: Aqua shares Zephyr's Element logo and every Role glyph (placeholders), so Aqua and Zephyr read the same in the HUD
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/IconAssets.lua:31, 42, 53, 64, 75, 86`; `game/ReplicatedStorage/Spellshot/PopArtAssets.lua:74, 86, 97, 110, 121, 132, 143, 154, 229`
- **Trigger:** Any HUD/feed surface that shows an Element mark for an Aqua player.
- **Why it's a bug:** Identity relies on colour alone between Aqua and Zephyr where the icon is the only cue; combined with P5F-09 a colour-blind-safe viewer sees an Aqua player as gold with a Zephyr logo.
- **Suggested fix:** Ship Aqua's own logo/glyphs (art task); until then tint the placeholder with Aqua's Base.

#### P5F-27: Client can restyle OTHER players' cosmetics locally by setting their Player attributes
- **Severity:** Low (informational; client-only)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:446-475, 493-507`; consumers e.g. `FrostbladeKit.lua:31-39`, `CryoWrap.lua:927-935`, `PyroFX.lua:270-276`
- **Trigger:** An exploiting client sets `ElementWrap_Cryo`, `ElementSkin_Cryo`, `Skin_<ability>` on an opponent's Player object.
- **Why it's a bug:** Resolution reads replicated attributes on every client; a local write overrides what that client draws for the opponent (e.g. force a high-contrast wrap). It never reaches the server or other clients, and an exploiter can recolour parts directly anyway, so this adds no real capability — noted for completeness of item (6). The answer to "can a client set StudioSkin on its own character": yes locally, but every reader is IsStudio-gated, so on a live client it does nothing.
- **Suggested fix:** None needed beyond P5F-24's contrast floor.

#### P5F-28: Startup race between SettingsRuntime's FOV and FirstPersonController's hard-coded 90
- **Severity:** Low
- **Confidence:** Medium (depends on LocalScript start order, which is not fixed)
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/FirstPersonController.client.lua:76, 81-82`; `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua:103-110`
- **Trigger:** A player with a saved FOV ≠ 90 where FirstPersonController's body runs after SettingsRuntime has already applied the loaded FOV (FirstPersonController first yields on three `WaitForChild`/requires).
- **Why it's a bug:** `camera.FieldOfView = MIN_FOV` (90) at load time overwrites the saved value; SettingsRuntime only re-applies on a FOV change or a CurrentCamera swap, so the session can run at 90 while the menu shows the saved value.
- **Suggested fix:** Drop the write in FirstPersonController (the setting owns FOV), or set it from `Settings.Get("FieldOfView")`.

#### P5F-29: Luau top-level local counts (item 8)
- **Severity:** Low (headroom note)
- **Confidence:** High (scripted count of column-0 `local` names after stripping comments/strings, cross-checked with `grep -c '^local '` + multi-name lines)
- **Files/lines:** `game/ReplicatedStorage/IceMagic/VFXLibrary.lua` — 182 (178 `local` lines + 4 extra names on 971, 3790, 3791×2); `CastPose.lua` — 69; `Viewmodel.lua` — 58 (57 lines + 1 multi); `AbilityFX.client.lua` — 39. (For reference: CryoFX.lua — 198.)
- **Trigger:** Adding top-level locals to VFXLibrary.
- **Why it's a bug:** Not a bug today. VFXLibrary has 18 slots before Luau's 200-local limit; the file already routes skins through lazy lookups (`frostblade()`, `snowGlobe()`, the inline FrostDragonKit `pcall(require)` at 2814-2815 and 5363-5364) partly for this reason, and 16 top-level locals belong to the retired Cryo Beam renderer (3742-4800) that has no Abilities row.
- **Suggested fix:** Move the retired Cryo Beam/Chill Aura code to ServerStorage (as the Glacial Spikes precedent did) to reclaim ~25 locals.

---

#### Appendix A — settings-consumer matrix

Legend: R = reads the setting (directly or through a named helper), — = never reads it. "Via" names the helper that does the reading. Settings fields: EffectDensity (Graphics Quality), ThinEnemyVFX (Reduce Enemy VFX), ReduceFlashing, ColorblindSafe, CameraShake, StatusIntensity.

How each is defined / persisted / loaded / broadcast:
- Definition: SpellshotSettings.lua:59-126 (GraphicsQuality option 1-4 default 3 HIGH; ReduceEnemyVFX bool false; ColorblindSafe bool false; ReduceFlashing bool false; StatusIntensity 0-100 default 100; CameraShake 0-100 default 100; 35 more).
- Persistence: SettingsStore.server.lua (DataStore "SpellshotSettings_v1", key p_<UserId>, SetAsync on autosave 120 s / leave / close).
- Load: SettingsRuntime.client.lua:82-98 → `Settings.Load` (silent Sets) → `MarkSaved`; push via `TakePush` on Heartbeat after 0.75 s debounce.
- Broadcast to consumers: `Settings.Bind/OnChange` listeners for menu-facing appliers; two derived PLAIN FIELDS for VFX — `Settings.EffectDensity` (SettingsRuntime:143-147: 0.45/0.75/1.00/1.15) and `Settings.ThinEnemyVFX` (149-151) — read at draw time, never signalled. ReduceFlashing/ColorblindSafe are read with `Settings.Get` at draw time.

| Module | Graphics Quality | Reduce Enemy VFX | Reduce Flashing | Colourblind-Safe | Camera Shake | Notes |
|---|---|---|---|---|---|---|
| SettingsRuntime | R (shadows, density) | R (publishes) | — | R (uniform repaint) | — | |
| SettingsMenu | R (row) | R (row) | R (row) | R (preview) | R (row) | |
| VFXLibrary | R (emitter(), thin gates) | R (onAnotherPlayer / thin args) | R only TerraBurst (1172) | — | — | Flash Freeze lights, ShatterFX, Boulder/Surge Flash unread (P5F-03) |
| Viewmodel | — (reads GlobalShadows) | — (n/a, own arms) | R (zeroes punch/shake) | — | R | palm ShotFlash unread |
| CastPose | — | — | — | — | — | body animation only |
| AbilityFX | — | — (passes Own/Thin to kits) | — | — | — | dispatcher |
| CryoFX | R | R | R (1 site) | — | — | 4613 thins own crust |
| CryoWrap | R (via setting("Density")) | BROKEN (P5F-15) | R | — | — | |
| CryoAurora | R | R | R | — | — | not reachable live (Aurora not in ElementWraps) |
| FrostLotusFX / SnowGlobeFX / FrostDragonKillFX | R (Tier) | R / R / — | R / — / R | — | — | |
| FrostbladeKit / FrostLotusKit / SnowGlobeKit / FrostDragonKit / FrostDragonFX | Tier fn only / — | — (callers pass thin) | FrostDragonFX R | — | — | |
| PyroFX / PyroDraw / PyroFlame_Fire / _Ring / _Tech | R | R (EnemyThin 0.6) | R | — | — | |
| TerraFX / TerraFX_Tomb / TerraFX_Wall / TerraWrap / ChargedRock | R / R / R / — / — | R / R / R / — / — | R / R / — / — / — | — | Viewmodel.Punch | TerraFX_Wall: no Reduce Flashing |
| ZephyrDraw (+ ZephyrFX_*, GustPad, Skyrider, Updraft via ZD) | R | R (0.6; Own) | R | — | R (CameraKick) | Gust Pad shared hazard thinned (P5F-07) |
| ZephyrFX (WindBlade/CrossSlash/Cyclone) | R | R | R | — | via ZD | |
| VoltaicKit (+ ChainBolt, Overcharge, Railspike, Cascade, VoltOrb, VoltaicFX via Kit) | R (<0.6) | R | R | — | Viewmodel.Punch/Shake | covered |
| ToxinFX / ToxinWrap / ToxinClient | R / — / — | R (T.Mine) / sets Mine / — | R / — / — | — | — | |
| **UmbraFX / UmbraClient** | **—** | **—** | **—** | — | — | Eclipse screen CC pulse (P5F-03/05) |
| **AquaFX / AquaClient** | **—** | **—** | **—** | — | Viewmodel.Punch | (P5F-03/05) |
| **RadiantDraw / RadiantFX_Hand / RadiantFX_Staff / RadiantDevilForge / RadiantAnim / RadiantClient** | **—** | **—** | **—** | — | — | Devil skin included (P5F-03/05) |
| StatusReactions | — | — | R (screen layer) | — (ELEM_TINT fixed) | — | R StatusIntensity |
| **BarFX + 24 Variants** | **—** | n/a | **—** | **—** | **— (fx.shake)** | **StatusIntensity —** (P5F-04) |
| PopArtHUD | — | n/a | — | — | — | R crosshair/UIScale/HUDOpacity/TextSize/KillFeedDuration; keybinds hardcoded (P5F-18) |
| DeathFX | — | — | **—** | — | — | white burst on every death |
| Callouts (server) | — | — | — | — (words) | — | |
| UniformAvatar (server) | — | — | — | (client repaint overrides; P5F-11) | — | |
| HubClient | overrides GlobalShadows (P5F-13) | — | — | — | — | |

Other settings, one consumer each (checked, clean except as noted): FieldOfView (SettingsRuntime; race P5F-28), Brightness (SettingsRuntime; UmbraFX coexists), MotionBlur / Sensitivity / ChannelSensitivity / InvertY / TouchSensitivity / Vol* / MuteUnfocused (SettingsRuntime), ToggleCrouch / Bind_Crouch (MovementController), Bind_/Pad_ Primary/Mobility/Defense/Ultimate (SpellshotInput:115-124; HUD chips ignore them, P5F-18), Bind_/Pad_Interact (HubClient), AutoFire (SpellshotInput), ButtonSize / ButtonOpacity (TouchControls), Crosshair* / HUDOpacity / UIScale / TextSize / KillFeedDuration (PopArtHUD), DamageNumbers (PopupScaler), Compass (HeadingCompassClient), StatusIntensity (StatusReactions only). CameraAssist and LeftHanded have NO consumer (the menu says "Saved; not built yet").

"Enemy" determination per module (item 2): every module uses "caster ~= my character" — VFXLibrary `onAnotherPlayer` / `~= VFXLibrary.LocalCharacter`; CryoFX `~= VFXLibrary.LocalCharacter`; CryoWrap/ToxinWrap/VoltaicKit `~= Players.LocalPlayer.Character`; PyroDraw/ZephyrDraw `opts.Own`; FireIcicleShard `onHit == nil`. None consults `MatchTeam`/`Config.MayHurt`. Outcomes: Duel — correct; 2v2 / Squad Clash — allies thinned (wrong); dummies — thinned; spectator — watched subject thinned; local player's own effects — not thinned except during the LocalCharacter-nil window after spawn (VFXLibrary-based paths); shared hazards (Gust Pad) — thinned unless own.

#### Appendix B — SkinCatalog enumeration

Skins (22, `SkinCatalog.Skins`, file lines):
| Id | Kind | Element (where wired) | Rarity | Reachable live via |
|---|---|---|---|---|
| Default | — | all | — | always |
| Rainbow (30) | colour wrap (Stops, Flat) | Radiant (Offer, all 5 abilities) | **missing** | Offer.Radiant; also "Devil+Rainbow" composite |
| ObsidianMagma (37) | material wrap (Stages) | Terra (Offer, 6 abilities) | **missing** | Offer.Terra |
| AzureFlame (80) | material wrap (Flame) | Pyro (Offer, 8 abilities) | **missing** | Offer.Pyro |
| Nightshade (100) | Element wrap (Palette) | Toxin | Uncommon | ElementWraps.Toxin |
| CoralSnake (120) | Element wrap | Toxin | Uncommon | ElementWraps.Toxin |
| PoisonDartFrog (139) | Element wrap | Toxin | Rare | ElementWraps.Toxin |
| BlueRingedOctopus (169) | Element wrap | Toxin | Epic | **not listed** (unreachable) |
| Bloodmoon (211) | material wrap (Shadow) | Umbra (Offer, 5 abilities) | **missing** | Offer.Umbra |
| Devil (242) | Rework skin (Stops, Staff) | Radiant | **missing** | ElementSkins.Radiant |
| Frostblade (253) | Rework skin | Cryo | **missing** (comment: Uncommon) | ElementSkins.Cryo |
| FrostLotus (262) | Rework skin | Cryo | Epic | ElementSkins.Cryo; Hud set |
| SnowGlobe (272) | Rework skin | Cryo | Rare | ElementSkins.Cryo (no Hud set; IconAssets icons unmapped) |
| FrostDragon (278) | Rework skin, **IN BUILD** | Cryo | Mythic | ElementSkins.Cryo; Hud set |
| MintRime (283) | Element wrap | Cryo | Uncommon | ElementWraps.Cryo |
| DeepGlacier (289) | Element wrap | Cryo | Uncommon | ElementWraps.Cryo |
| BlackIce (297) | Element wrap (Rare: Edge) | Cryo | Rare | ElementWraps.Cryo |
| SakuraFrost (315) | Element wrap (Epic extras) | Cryo | Epic | ElementWraps.Cryo |
| Aurora (337) | Element wrap (Mythic) | Cryo | Mythic | **not listed** (unreachable; "NOT in ElementWraps until approved") |

Offer (`SkinCatalog.Offer`, 364-376): Radiant {LightLance, Blessing, Halo, PositionTrade, Benediction} → {Default, Rainbow}; Pyro {Fireball, Immolate, EmberRefund, RingofFire, HeatRush, Detonate, CinderShield, ScorchingLash} → {Default, AzureFlame}; Terra {BoulderShot, BulwarkCharge, Bedrock, Aftershock, BulwarkWall, EarthenTomb} → {Default, ObsidianMagma}; Umbra {ShadowDart, ShadowStep, Eclipse, Mark, DecoyDouble} → {Default, Bloodmoon}. Origin (378-384) matches Offer exactly. No Offer for Cryo, Voltaic, Zephyr, Aqua, Toxin.
ElementSkins (432): Radiant {Default, Devil}; Cryo {Default, Frostblade, SnowGlobe, FrostLotus, FrostDragon}.
ElementWraps (457-458): Cryo {Default, MintRime, DeepGlacier, BlackIce, SakuraFrost}; Toxin {Default, Nightshade, CoralSnake, PoisonDartFrog}.
Composite ids possible live: only "Devil+Rainbow" (the sole Element skin with an Offer colour wrap that has Stops). Cryo skin+wrap is not a composite id — CryoWrap.For/PaintKit layers the ElementWrap over the skin directly (CryoWrap.lua:927-935, VFXLibrary.lua:5081-5087).
Kinds (389-394): RadiantLance/Blessing/Overflow/Halo/Trade/Benediction → Radiant keys; BoulderChargeStart/BoulderShot/BulwarkCharge/BulwarkHit → Terra keys.
Hud (586-591): FrostLotus {Element Cryo}, FrostDragon {Element Cryo}; neither has a Bar accent, so `HudBar` always returns nil today (BarFX skinLook is inert).
WrapIcon (387): Radiant "Stripes", Pyro "Drop".

#### Could not complete
- BarFX/Variants: the 24 files (~6,200 lines) were grepped and machine-checked (settings reads, shake/flash calls, timing APIs, sprite names) and two were read in part; they were not read line by line, so per-variant logic bugs (nil fields in `st`, off-by-one in layouts) were not audited.
- CastPose 160-1526 and Viewmodel 620-1578 / 2460-2700 are clip and pose DATA tables plus the middle of Viewmodel.Update; skimmed, not line-by-line.
- VFXLibrary 3800-4800 (the retired Cryo Beam v2 renderer, no Abilities row) read at skim depth only.
- Whether the four `_*Stage*` scripts are Enabled in the live place (P5F-01) cannot be determined from the snapshot.
- Perceptual claims (P5F-10 collision strength, P5F-24 readability) need Play / colour-vision simulation to confirm.


---

## Pass 6 — Dead code, stale fixes, code-vs-doc drift

_Entries: 42 (4 High / 9 Medium / 29 Low). Distinct after merging duplicates: 35 (1 High / 7 Medium / 27 Low)._

### Pass 6 slice A: dead code, test/staging scripts, stale fixes, remaining client/UI files, manifest

#### Files read (complete list)
Test / staging (part 1), all read fully:
- game/ServerScriptService/_AuroraStage.server.lua (fully, 106 lines)
- game/ServerScriptService/_BROStage.server.lua (fully, 101)
- game/ServerScriptService/TerraTestServer.server.lua (fully, 53)
- game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua (fully, 18)
- game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua (fully, 11)
- game/StarterPlayer/StarterPlayerScripts/TerraTestHarness.client.lua (fully, 363)
- game/StarterPlayer/StarterPlayerScripts/VoltaicTestHarness.client.lua (fully, 629)
- game/StarterPlayer/StarterPlayerScripts/ZephyrTestHarness.client.lua (fully, 163)
- game/StarterPlayer/StarterPlayerScripts/DeflectGustPractice.client.lua (fully, 81)
- game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua (fully, 735)
- game/StarterGui/MatchHUD_RETIRED.client.lua (fully, 619)

ServerStorage staged copies (part 2), each read fully and `diff`ed against its live counterpart:
- game/ServerStorage/MovementSwitchReviewFix_2026_10_18/MovementController.client.lua vs live MovementController
- game/ServerStorage/MovementSwitchReviewFix_2026_10_18/SpellshotConfig.lua vs game/ReplicatedStorage/Spellshot/SpellshotConfig.lua
- game/ServerStorage/MovementSwitchReviewFix_2026_10_18/TouchControls.client.lua vs live TouchControls
- game/ServerStorage/UmbraReviewFix_2026_10_18/UmbraHandler.server.lua vs game/ServerScriptService/UmbraHandler.server.lua (live read: lines 690-830, 935-955)
- game/ServerStorage/_superseded_everfrost_2026_10_14/chill_ef.lua (header + diff vs chill_t/chill_a/chill_f)

Remaining client/UI files (part 3), all read fully:
- StarterPlayerScripts: HeadingCompassClient, HitboxGuard, HubBannerWave, HubClient, HubCrystalSpin, HubFireFlicker, HubLanternFlicker, HubWaterFlow, MapVote, MovementController (1258 lines), PopupScaler, QuickPlay (973), ReactionsBoard (832; the numeric FRAME band tables skimmed), SlideAudio, TouchControls
- ReplicatedStorage/Spellshot: DashMotor, HeadingCompass, MapRegistry, TouchBus, DeflectPractice
- game/Workspace/Map_SakuraRow/ShojiBreak.server.lua
- game/ServerScriptService/MovementModeServer.server.lua

Cross-referenced (partially read):
- game/ServerScriptService/SpellshotService.server.lua: 95-135 (dev state), 225-330 (MoveRequest), 360-560 (DevRequest handler), 670-790 (loadout)
- game/ReplicatedStorage/Spellshot/SpellshotConfig.lua: 120-240 (Movement.Mode, Config.Dev, IsDev), 495-520 (ElementMayHold / MayEquip)
- game/ServerScriptService/HubServer.server.lua: 90-125 (spawns), 470-520 (respawns), 1076-1140 (remote)
- game/ServerScriptService/CombatCore.lua: 270-310 (SCRIPT_ELEMENT)
- game/ServerScriptService/TerraHandler.server.lua: 520-560 (Bulwark Wall build)
- game/ServerScriptService/ElementalReactions.server.lua: 1-60
- game/ServerScriptService/DuelMatch.lua: 295-315
- game/ServerScriptService/TrainingGround.server.lua (grep only)
- game/StarterGui/PopArtHUD.client.lua: 140-160, plus greps
- game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua: 120-150, 640-660, 850-890
- game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua: 400-510
- game/ReplicatedStorage/IceMagic/Viewmodel.lua: 36-50
- docs/SPELLSHOT_Dev_Diary.md, docs/HANDOFF.md, docs/vfx_handoffs, docs/build_prompts (grep for each folder name and date)
- game/manifest.json: dumped in full to an outline with a python3 -I script (2066 lines, then 713 after filtering out rig and part noise), skimmed fully

#### Sub-areas checked with nothing found
- Checked, clean: manifest script count. `manifest.json` says 191 and the tree has 191 nodes marked `script` (124 ModuleScript, 38 LocalScript, 29 Script). Every one has a .lua file at the matching path and no .lua file is missing from the manifest.
- Checked, clean: the DevPanel server side. Every DevRequest action (SpellshotService.server.lua:376-552) sits behind `s.Dev = Config.IsDev(p)`, which is computed on the server. MovementModeServer checks `Config.IsDev` on the server. A non-dev gets "denied" and nothing else. The client-side open gate (DevPanel:726) is cosmetic only, and correctly so. Dev SetTechnique uses `Config.ElementMayHold`, which honours `TechniquesOwnElementOnly`.
- Checked, clean: VoltaicTestHarness and ZephyrTestHarness. Both `return` on `not RunService:IsStudio()` before doing anything (Voltaic:37, Zephyr:34), so they are inert live.
- Checked, clean: the `StudioSkin` / `WrapStudio` consumers outside the staging scripts are all inside `RunService:IsStudio()` guards (FrostbladeKit 36/723, FrostDragonKit 42/1032, SnowGlobeKit 33/1243, FrostLotusKit 38/1159, CryoWrap 929, ToxinWrap 40, CryoAurora 734, FrostDragonKillFX 570). No instance in the manifest carries either attribute.
- Checked, clean: HeadingCompass.lua. The heading maths (atan2(-x, z) gives 0 = +Z and 90 = -X) matches its doc, and the wrap, readout rounding and layout clamps are sound. HeadingCompassClient re-reads CurrentCamera every frame, unbinds while hidden and handles HUD rebuilds through Destroying and ChildAdded.
- Checked, clean: HitboxGuard, PopupScaler, TouchBus and HubWaterFlow (beyond the shared Graphics Quality note in P6A-11). HubCrystalSpin trims `cfs` correctly.
- Checked, clean: MovementController's RunningOnly gating on the client. It is applied at every entry the header lists (slideRefusal:337, watchJumps:471, tryWallRun:503, stepWallRun:550, onJumpPress:620/622, the slide Heartbeat:946), and the live CrouchClear handler matches what TouchControls sends.
- Checked, clean: MapVote tally and result handling, QuickPlay's dequeued, requeued and count commands, and HubClient's banner and wipe tokens.
- Checked, clean: nothing reads the ServerStorage ReviewFix folders or `_superseded_everfrost` (grep for folder names and for `require` into ServerStorage).
- Checked, clean: ElementMayHold on the dev path (SpellshotService:413) agrees with the own-Element rule.

---

#### P6A-01: _AuroraStageClient and _BROStageClient have no guard and would break every live client if Enabled
> **Consolidator:** duplicate of **P1-05** (Temporary stage scripts ungated (if Enabled)). Kept here for its slice-specific detail; counted once, under P1-05.
- **Severity:** High (critical in effect if enabled; graded High because it is not an exploit)
- **Confidence:** High that it does this if it runs. Low/unknown whether the scripts are Disabled: the manifest does not record Enabled.
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua:1-18`, `game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua:1-11`, `game/manifest.json` (both listed under StarterPlayerScripts)
- **Trigger:** Any live join, if the place is published with these LocalScripts not Disabled. There is no IsStudio, PlaceId or attribute check anywhere in either file.
- **Why it's a bug:** _AuroraStageClient runs on every client:
  - `ch:WaitForChild("HumanoidRootPart").Anchored = true` (line 3) freezes the player's own client-owned body.
  - It `PivotTo`s the body to (-90,4,0).
  - After 2 s, `for _, g in ipairs(plr.PlayerGui:GetChildren()) do if g:IsA("ScreenGui") then g.Enabled = false end end` (line 7) disables PopArtHUD, the shop, QuickPlay, the settings menu and every other ScreenGui.
  - It binds a render step at priority 1,000,000 (line 8) that, while `CamPinEye`/`CamPinLook` exist (the server stage sets them), forces `CameraType = Scriptable` and hides every part of the camera and the character, every frame.

  _BROStageClient runs on every client:
  - It adds a `_ShotTag` ScreenGui whose render step forces `g.Enabled = true` and repaints a 24x24 green square in the bottom-right corner every frame (line 6).
  - It creates a client-side 200x200 `_ShowcaseFloor` and a 400x160 `_ShowcaseSky` wall in Workspace around (-90, y, -45..-100) (lines 7-10). They are Transparency 1 and CanCollide false, but CanQuery is left at its default (true), so every client raycast that does not exclude them (aim rays, client-predicted shots) stops on an invisible wall at z = -100, x -290..110, y -20..140, around the training range near the origin.

  The files themselves say "TEMPORARY ... remove when done". The BRO header is dated 2026-10-19, after the snapshot was exported (2026-10-18 20:19), and the diary's 2026-10-18 entry describes a live Blue-Ringed Octopus checkpoint loop. So the stage is in active use, which raises the odds that it ships enabled.
- **Suggested fix:** Delete all four stage scripts from the live containers (or move them to ServerStorage). Any stage script that stays should start with `if not RunService:IsStudio() then return end`. Create the showcase parts with CanQuery = false.
- **Notes:** Nothing references either script. Its own server half sets the CamPin attributes (P6A-02). Confirm Enabled/Disabled in Studio.

#### P6A-02: _AuroraStage and _BROStage server stages have no guard; they clone a real player and put invisible query-blocking parts in the live world
> **Consolidator:** duplicate of **P1-05** (Temporary stage scripts ungated (if Enabled)). Kept here for its slice-specific detail; counted once, under P1-05.
- **Severity:** High (if Enabled)
- **Confidence:** High on behaviour; unknown on Enabled
- **Files/lines:** `game/ServerScriptService/_AuroraStage.server.lua:3-30, 62-65, 68-100`, `game/ServerScriptService/_BROStage.server.lua:2-29, 97-100`
- **Trigger:** Any live server, once the first player has a character.
- **Why it's a bug:** _AuroraStage:
  - Waits for `Players:GetPlayers()[1].Character`, sets `ch.Archivable = true` on that real player's character and clones it into `workspace.WrapStage` as an anchored "Caster" with `WrapStudio = "Aurora"`. The clone stays where that player stood one second after spawning (the Hub spawn).
  - Writes the server-replicated workspace attributes `CamPinEye`, `CamPinLook` and `StageReady`, which drive P6A-01's camera pin on every client.
  - Fills `_G` with WS, dummies, dusk, ff and mc. `dusk` rewrites Lighting for everyone.
  - Exposes `StageCmd`, a step interpreter that can write any workspace attribute (`attr:Name:value`). Only server code can set it, so it is not client-reachable.

  _BROStage waits for `StageReady`, clones the Caster eight more times into a Persistent `_StageP` model and builds `_ShowcaseSrv`: a server-side 200x200 floor and a 400x160 wall at z ≈ -100. Both are Transparency 1, CanCollide false and CanQuery at its default (true). Server raycasts (hit validation, line-of-sight, ground probes) that do not filter them hit an invisible wall across the training range.

  The cloned "dummies" are Humanoid models that are not players, so kits treat them as hittable bodies. WrapStudio is inert live because every reader is IsStudio-guarded.
- **Suggested fix:** As P6A-01: remove the scripts from ServerScriptService, or IsStudio-guard them and create the parts with CanQuery = false.
- **Notes:** Workspace attribute `StageWrap = "Aurora"` in the manifest is this tool's leftover, and nothing in code reads it (grep). `AuroraFloor` and `AuroraMask` are read only under IsStudio (CryoAurora:98, 971).

#### P6A-03: The owner and a collaborator get full dev powers in live public servers, including an always-charged Ultimate in real matches
> **Consolidator:** duplicate of **P1-02** (Dev mode live: free Ultimate in ranked + unlimited Sparks). Kept here for its slice-specific detail; counted once, under P1-02.
- **Severity:** High (competitive integrity, plus Sparks minted into the DataStore)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:152-173` (`AllowInLiveGame = true`, `UserIds = { [2800693640] = true }`, `FreeUltimate = true`), `:209-219` (IsDev); `game/ServerScriptService/SpellshotService.server.lua:118-131` (getState: `s.FreeUltimate = s.Dev and DEV.FreeUltimate == true`), `:338-347` (publishDev sets `UltCharge = 1`), `:390-552` (dev actions)
- **Trigger:** The place owner, or UserId 2800693640, joins any live server and queues a Duel or team match against real players.
- **Why it's a bug:** With `AllowInLiveGame = true` and `FreeUltimate = true` as the starting state, `getState` gives every dev a FreeUltimate state on any server. That pins UltCharge at 1 and skips the spend (SpellshotService:938, 1119), with no "not in a match" exemption anywhere. A dev also has, mid-match and with no zone or match gate:
  - Heal and FullHeal, FillUlt, ClearCooldowns (which also refills mana), and the NoCooldowns and FreeMana toggles.
  - SetStatus: arbitrary RX_ flags on their own body.
  - EcoAddSparks: `PlayerData.AddSparks(p, 1000, "dev")`, persisted, unlimited presses. EcoUnlockAll.
  - Kill: `KillFeed:FireAllClients(a, b, c)` with arbitrary strings broadcast to every player.

  The config comment says "turn it off before the game is public". It is on, so a ranked or public match against a dev is not a fair match.
- **Suggested fix:** Set `AllowInLiveGame = false` for the public build, or keep it on but make `FreeUltimate`/`FreeMana`/`NoCooldowns` default false outside Studio. Refuse every gameplay-affecting dev action while `p:GetAttribute("DuelMatch") ~= nil`. Gate the Eco* actions to Studio, or log them as dev-granted.
- **Notes:** The server-side gating is correct, so this is not a public exploit. Cross-ref the SpellshotService and Economy passes.

#### P6A-04: RunningOnly movement mode is enforced only on the client; the server still grants Slide and SlideJump
- **Severity:** Medium (competitive integrity, but only while a dev has switched the server to RunningOnly)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/MovementModeServer.server.lua:29-38`; `game/ServerScriptService/SpellshotService.server.lua:227, 270-330` (moveRemote handler: no MovementMode check); `game/StarterPlayer/StarterPlayerScripts/MovementController.client.lua:148-161, 337`
- **Trigger:** `workspace.MovementMode = "RunningOnly"` (the dev panel's team-mode switch) and a modified client that fires `MoveRequest("Slide")`.
- **Why it's a bug:** MovementModeServer only writes the attribute. The server's MoveRequest handler accepts `VALID_MOVE = { ..., Slide = true, SlideJump = true }` regardless of mode and applies `SlideSpeed` WalkSpeed and the crouched hip height (applyMoveState). Only MovementController's `slideRefusal` returns "No" in RunningOnly. Wall run and double jump are client physics by design, so the slide is the one RunningOnly rule the server could enforce and does not.
- **Suggested fix:** In SpellshotService's moveRemote handler, refuse `Slide` and `SlideJump` (treating Slide as Crouch) when `workspace:GetAttribute("MovementMode")` (or Config.Movement.Mode) is "RunningOnly".
- **Notes:** A smaller related issue: MovementModeServer answers `FireClient(player, "denied", ...)` to every non-dev request with no throttle (line 31). SpellshotService's DevRequest tells each player only once (`toldNotDev`).

#### P6A-05: "Through characters" dashes treat Terra's Bulwark Wall as a body and pass straight through it
> **Consolidator:** canonical entry for: Dashes / dash strikes pass through Bulwark Wall (client and server). Also reported as **GC-02**.
- **Severity:** High (competitive integrity: a defensive wall does not block three kits' mobility)
- **Confidence:** Medium-High. The pass-through code path is certain. Whether the server's own sweep re-checks the wall was not traced.
- **Files/lines:** `game/ReplicatedStorage/Spellshot/DashMotor.lua:163-170` (characterOf: any Model with a Humanoid), `:185-189` and `:236-248` (a "body" hit is added to the filter, not treated as a wall), `:333-345` (passThrough: NoCollisionConstraints between this body and every part of the model), `:355-364` (scanBodies); `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:405-427, 444, 502` (the same logic for the ride); `game/ServerScriptService/TerraHandler.server.lua:529-547` (the wall is `Model "BulwarkWall"` holding a collidable `WallBody` Part and a `Humanoid`)
- **Trigger:** A Zephyr Cross-Slash Dash (`ThroughCharacters = true`, SpellshotInput.client.lua:657), a Voltaic Overcharge (VoltaicClient.lua:455), a Terra Bulwark Charge (SpellshotInput:884) or a Zephyr Skyrider ride aimed at an enemy Terra's raised Bulwark Wall.
- **Why it's a bug:** `characterOf(hit.Instance)` returns the BulwarkWall model because it "has a Humanoid", so `wallAhead` skips it (`params:AddToFilter(body)`) and `scanBodies` → `passThrough` stops this client's body colliding with `WallBody`. Movement is client-owned, so the dasher really goes through the wall. The header's intent is "Walls and the ground still stop it". The Hitbox-twin filtering and the Umbra decoy behaviour are separate questions.
- **Suggested fix:** In both characterOf functions (DashMotor and ZephyrSkyrider), return nil for models with `WallOwner` (use `CombatCore.IsWall`'s rule on the client: `model:GetAttribute("WallOwner")`), so the wall is a wall to every cast and never gets a NoCollisionConstraint.
- **Notes:** Cross-ref the Terra, Zephyr and Voltaic kit passes. Also check whether projectile and hit sweeps use the same "has a Humanoid" shortcut.

#### P6A-06: The retired Open Academy hub's HubSpawn is never disabled, so players can spawn in the unwired old hub
- **Severity:** Medium
- **Confidence:** Medium (SpawnLocation.Enabled is not in the manifest)
- **Files/lines:** `game/ServerScriptService/HubServer.server.lua:103-111` (disables only `workspace:GetChildren()` SpawnLocations); `game/manifest.json` (`/Workspace/OpenAcademyHub/HubSpawn` and `/Workspace/ArcaneObservatoryHub/Functional/HubSpawn` are both nested SpawnLocations); HubServer:471-479 (Hub-zone characters are never repositioned)
- **Trigger:** A player joins, or respawns while in the Hub. Roblox picks one enabled neutral SpawnLocation at random.
- **Why it's a bug:** The comment at HubServer:103 says "with two enabled, Roblox picks one at random, and everybody has to arrive in the Hub". The loop only reaches top-level SpawnLocations, so OpenAcademyHub.HubSpawn stays live if it is Enabled. OpenAcademyHub (3732 colliders, its own Interact parts) is still in Workspace, but HubServer wires prompts only on ArcaneObservatoryHub (`find()` on `hub`). A player spawned there has Zone = "Hub" in a hub with no working loadout, portal or shop prompts.
- **Suggested fix:** Disable every SpawnLocation except `hubSpawn` (search descendants), or teleport every Hub-zone CharacterAdded to `hubSpot()`. Move OpenAcademyHub to ServerStorage.ReplacedHubs.
- **Notes:** Confirm in Studio that OpenAcademyHub.HubSpawn.Enabled is true. HubClient still shows `OpenAcademyBackdrop` in the Hub (HubClient:621-632).

#### P6A-07: Sakura Row's shoji windows never reset, so map state carries over between rounds and matches
- **Severity:** Medium (competitive consistency: sightlines and cover differ between round 1 and later rounds, and between the first match on a server and later ones)
- **Confidence:** High
- **Files/lines:** `game/Workspace/Map_SakuraRow/ShojiBreak.server.lua:16, 41-53`; grep found no other writer of the `Broken` attribute or the shoji Paper.
- **Trigger:** A body moving at 16 studs/s or more into a shoji (WallRunMinSpeed) in any Sakura Row round.
- **Why it's a bug:** `shatter` makes every part of the window Transparency 1 and CanCollide/CanQuery/CanTouch false, permanently ("A broken window stays broken for the life of the server. There is no round reset"). DuelMatch rebuilds bodies each round but not the map, so later rounds and every later Sakura Row match on that server play on a different map (open windows, extra lines of sight). The debris bits are unanchored and CanCollide true (default) and are thrown at up to `dir * speed * 0.9`. For 3 s they can collide with and nudge players.
- **Suggested fix:** Give ShojiBreak a reset (restore Paper and bars, `Broken = false`) and call it from DuelMatch at each round start, or at least at match start. Make the bits CanCollide = false.
- **Notes:** The speed is read from the client-owned root velocity, so any client can break windows. That is fine for a cosmetic but matters once the windows affect play.

#### P6A-08: MatchHUD_RETIRED is still an active LocalScript in StarterGui; if not Disabled it rebuilds the old HUD and replaces _G.SpellshotHUD
- **Severity:** Medium if enabled, Low as presence
- **Confidence:** High on behaviour; unknown on Enabled
- **Files/lines:** `game/StarterGui/MatchHUD_RETIRED.client.lua:119-125, 618`; `game/StarterGui/PopArtHUD.client.lua:150-153, 995`; `game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua:168-170, 425-434`
- **Trigger:** Every respawn. It is a StarterGui LocalScript, cloned into PlayerGui and run if not Disabled. There is no guard in the file.
- **Why it's a bug:**
  - It builds a second full HUD ("SpellshotHUD": bars, slots, crosshair, world-space status billboards over other players' heads) beside PopArtHUD.
  - PopArtHUD destroys "SpellshotHUD" only if it runs second (line 150), so the result depends on script order.
  - `_G.SpellshotHUD = HUD` (618) overwrites PopArtHUD's API with one that only has `SetPrimaryCharge`. DevPanel's `H.SetCrosshairMarked`, `H.SetCharge` and `H.ClearKills` then raise errors.
  - Its cooldown readout does `remain = readyAt - os.clock()` against `CD_<role>`, which is server time (`workspace:GetServerTimeNow()`, SpellshotService:814). Every cooldown shows as about 0 or garbage.
  - It reads the retired single `Status` attribute model and the 3-Technique loadout (`Ultimate` slot origin).
- **Suggested fix:** Delete it, or move it to ServerStorage. A `_RETIRED` suffix does not stop a LocalScript from running.
- **Notes:** Nothing else references it except IconAssets.lua:164's comment.

#### P6A-09: SpellshotInput's slot flash looks up the retired HUD, so cast-denied and cast-accepted feedback never shows
- **Severity:** Low (UI feedback)
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:130-150` (`playerGui:FindFirstChild("SpellshotHUD")` → `AbilityCluster` → role); called at 297, 305, 316, 392, 437, 590, 649, 662, 668 and elsewhere; `game/StarterGui/PopArtHUD.client.lua:150-159` (destroys "SpellshotHUD", builds "PopArtHUD", which has no "AbilityCluster")
- **Trigger:** Any refused cast (cooldown, mana, a server "Denied" reply) or any accepted cast.
- **Why it's a bug:** `slotFrame` resolves to nil under PopArtHUD, so every `flash(role, denied)` is a silent no-op. Players get no red flash on a refused press. It only "works" if the retired MatchHUD (P6A-08) is running.
- **Suggested fix:** Point `slotFrame` at PopArtHUD's slot (`PopArtHUD.OpacityLayer.BottomRight.<role>`, the path TouchControls' findHud uses), or have PopArtHUD expose `HUD.Flash(role, denied)`.

#### P6A-10: The ServerStorage "ReviewFix" folders hold the pre-fix copies; the live files are the fixed ones
> **Consolidator:** canonical entry for: ServerStorage ReviewFix folders hold PRE-fix copies. Also reported as **P6B-15**.
- **Severity:** Low (misleading dead code; no bug left live)
- **Confidence:** High (direction confirmed by diff and by the `OriginalPath` attributes)
- **Files/lines:** `game/ServerStorage/MovementSwitchReviewFix_2026_10_18/*`, `game/ServerStorage/UmbraReviewFix_2026_10_18/UmbraHandler.server.lua`, `game/manifest.json` (each staged file carries `OriginalPath`)
- **Why:** Real diffs:
  - **MovementController:** live adds the `CrouchClear` TouchBus branch (live 783-794). The staged copy lacks it, so with it a Toggle Crouch latch from the touch button could never be released once RunningOnly hid the button.
  - **TouchControls:** live adds `if layerOn then TouchBus.Fire("CrouchClear", true) end` when hiding the button (live 382-386).
  - **SpellshotConfig:** the only difference is `RunningOnlyTouchCrouch` (staged `true`, live `false`, live 133-135). The fix makes `false` safe, as the brief asks.
  - **UmbraHandler:** the staged copy gives back every Shadow Step press made while a step is still dissolving. Live queues one press (`busy.Queued`), steps it from the new spot on re-form, gives back a third press, and gives back a queued press on endAll, epoch change or death (live 744-811, 945-950).

  So the folder names mean "the copy taken before the review fix", like the skipped `*Superseded_2026_10_18` folders. The live files are newer, and the review fixes are present live. `_superseded_everfrost_2026_10_14/chill_ef.lua` is the Chill bar look for the dropped "Everfrost" Cryo skin, a reskin of chill_t (`diff` vs chill_t: 221 lines). No live code references Everfrost or chill_ef, so it is dead.
- **Suggested fix:** Rename the folders to `*_PreReviewFix_*` or merge them into the Superseded backups.
- **Notes:** The staged UmbraHandler is a Script. Scripts in ServerStorage do not run with RunContext Legacy, but one with `RunContext = Server` would run there too, and two UmbraHandlers would double-register every remote and hook. The manifest does not record RunContext, so check it in Studio.

#### P6A-11: The hub's ambient flicker effects ignore Reduce Flashing and Graphics Quality
- **Severity:** Low (accessibility, a setting not honoured uniformly)
- **Confidence:** High (no Settings read in either file)
- **Files/lines:**
  - `game/StarterPlayer/StarterPlayerScripts/HubFireFlicker.client.lua:25-28, 96-110`: a 9 Hz size tremble (`FlickHz = 9`) plus a ±10-14% Neon colour "breathe" on noise, and embers always on.
  - `game/StarterPlayer/StarterPlayerScripts/HubLanternFlicker.client.lua:31-34, 176-205`: PointLight Brightness and pane Neon waver, with occasional 30% "gutter" dips.
  - HubWaterFlow, HubBannerWave: particles and 30 Hz EditableMesh updates on every quality level.
- **Trigger:** A player with Reduce Flashing on, or Graphics Quality low, standing in the Arcane Observatory.
- **Why it's a bug:** The brief requires Reduce Flashing to damp pulses and flashes "wherever an effect is drawn". These scripts never read SpellshotSettings, while QuickPlay's dot pulse in the same session does (`Settings.Get("ReduceFlashing")`, QuickPlay.client.lua:712). Fire and lantern brightness keep oscillating. The 9 Hz tremble is a size change, not a luminance change, so the flash risk is modest, but the setting is still not honoured.
- **Suggested fix:** Read `Settings.Get("ReduceFlashing")` (and `Settings.OnChange`). When on, drop the colour and brightness modulation (keep the slow sway) and the lanterns' gutter dips. Scale or disable embers, drips and banner updates on low Graphics Quality.

#### P6A-12: HubFireFlicker re-gather captures the already-modulated flame colour, and `cfs` is never trimmed
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/HubFireFlicker.client.lua:68-84, 111`
- **Trigger:** `fires.ChildAdded` (for example a flame part streaming in) re-runs `gather()` after flickering has started.
- **Why it's a bug:** `Colour = p.Color` (line 76) reads the live colour, which the render step has already multiplied by up to 1.14. Each re-gather compounds the brightening toward white. `cfs` is not cleared in gather, unlike HubCrystalSpin:172, so if a re-gather ever yields fewer parts, `BulkMoveTo(parts, cfs)` gets arrays of different lengths.
- **Suggested fix:** Store the rest colour as an attribute (as RestSize and RestCFrame are), or cache it per part on first sight. `table.clear(cfs)` in gather. HubBannerWave's `undo()` similarly restores `Source.Transparency = 0` rather than the original value (line 228).

#### P6A-13: HubLanternFlicker panes freeze when their lantern light streams out and back
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/HubLanternFlicker.client.lua:56-63, 165-168, 192-203`
- **Why it's a bug:** A streamed-out light is dropped (`lanterns[part] = nil`). The streamed-back copy gets a new entry, but the panes still point at the old owner table, whose `Level` never updates again. Lights that stream in after the one-second wait are never assigned panes (their triangles go to "cells" and flicker out of sync with their light).
- **Suggested fix:** Key the panes by lantern name or position, and re-bind them in addLight.

#### P6A-14: HubClient's "Ley over the Hall of Cores" animation is dead code for the replaced hub
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/HubClient.client.lua:679-703`; `game/manifest.json` (`Hall` and `Hall/Ley` exist only under `/ServerStorage/ReplacedHubs/SpellshotHub`)
- **Why it's a bug:** It `WaitForChild`s `ArcaneObservatoryHub.Hall` (30 s), then `Floor`, `Hall_Floor` and `Ley`, none of which exist in the Arcane Observatory. The task sleeps and then returns. Harmless, but stale.
- **Suggested fix:** Remove it.

#### P6A-15: TerraTestServer and TerraTestHarness ship to live with no Studio guard
- **Severity:** Low (inert; leftover)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraTestServer.server.lua:16-53`; `game/StarterPlayer/StarterPlayerScripts/TerraTestHarness.client.lua:17-363`; `game/ServerScriptService/CombatCore.lua:282` (`TerraTestServer = "Terra"` in SCRIPT_ELEMENT)
- **Why it's a bug:** TerraTestServer connects `TerraDamage` and `WallDamage` listeners on every player. Those are player attributes that only server code can write: client writes do not replicate, and no server path writes caller-chosen attribute names (SpellshotService 416/680/782 are key-restricted). So it is inert live, but it is a damage path through `Core.DealDamage(nil, ...)` that reacts as Terra. TerraTestHarness, unlike the Voltaic and Zephyr harnesses, has no `IsStudio` return. It runs on every live client: it requires TerraFX, Viewmodel and VFXLibrary, waits on remotes, and hooks local attributes, including a `dev:` passthrough to DevRequest. Any local script that writes those attributes could equally fire the remotes itself, so an exploiter gains nothing. It is still dead weight and a live client hook.
- **Suggested fix:** Delete both, or add `if not RunService:IsStudio() then return end` at the top. Drop the CombatCore map entry.

#### P6A-16: Umbra live fix: a queued Shadow Step runs 0.24 s after the press without re-checking crowd control
- **Severity:** Low (possible CC-window escape)
- **Confidence:** Low (the cast-time CC gating was not traced; it belongs to the Umbra pass)
- **Files/lines:** `game/ServerScriptService/UmbraHandler.server.lua:752-760, 801-811`
- **Why it may be a bug:** The queued press calls `castShadowStep` directly from the first step's `task.delay`. It checks only epoch, life and destination. If a stun, root or tomb landed between the press and the re-form, the blink still happens. Whether SpellshotService or the kit would have refused a fresh press then is outside this slice.
- **Suggested fix:** Before running the queued step, re-apply the same CC and channel refusals the cast path uses; give the charge back if refused.

#### P6A-17: MapVote can bind its cursor render step twice
- **Severity:** Low
- **Confidence:** Low (depends on BindToRenderStep's handling of duplicate names)
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/MapVote.client.lua:485-487` (`open = false; setOpen(true)` on every "vote"), `:432-438`
- **Trigger:** A new "vote" while the previous vote screen is still open, for example a team vote called off, an immediate requeue and a refill within the 2.5 s close delay.
- **Why it may be a bug:** Forcing `open = false` bypasses setOpen's guard, so `BindToRenderStep(CURSOR_STEP, ...)` runs a second time with the same name. If that adds a second binding, one later Unbind leaves the mouse unlocked in first person for the rest of the session.
- **Suggested fix:** Call `pcall(RunService.UnbindFromRenderStep, RunService, CURSOR_STEP)` before binding, or only rebuild cards when the screen is already open.

#### P6A-18: QuickPlay's client and server queue state can desync when a request is throttled
- **Severity:** Low
- **Confidence:** Medium
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/QuickPlay.client.lua:793-806, 887-894`; `game/ServerScriptService/HubServer.server.lua:517-523, 1093` (0.25 s throttle on everything but "cancel")
- **Trigger:** QUEUE, CANCEL, QUEUE within 0.25 s, or QUEUE then SOLO TEST within 0.25 s.
- **Why it's a bug:** The client flips `queued` and its UI optimistically. A throttled "queue" or "solo" is silently dropped server-side. For SOLO the client also calls `setQueued(false, true)`, which sends nothing to the server, because the server's solo handler is what unqueues. The chip can show QUEUING while the server has you unqueued, or the reverse.
- **Suggested fix:** Have HubServer always answer "queued" true or false after a queue, cancel or solo request (or reply to throttled requests), and let the client render from that answer.

#### P6A-19: The Quick Play cards and modes drift from the manual
> **Consolidator:** duplicate of **P6B-06** (Quick Play advertises modes the server refuses). Kept here for its slice-specific detail; counted once, under P6B-06.
- **Severity:** Low (doc drift / UX)
- **Confidence:** High
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/QuickPlay.client.lua:114-137`; `docs/SPELLSHOT_Design_Manual.md:38-41, 216-218`; `SpellshotConfig.lua:244-246`
- **Why:**
  - The manual has a 2v2 mode and a Ranked toggle on Duel/2v2. Quick Play has no 2v2, and the DUEL card is now `3v3 · TEAMS` (Config.Team.Size = 3), while the Hub duel pads still start a 1v1.
  - SQUAD CLASH ("5v5") and CONVERGENCE (with a "NOW LIVE!" sticker) are selectable and queueable but have no match loop. The server just drops you.
  - The DUEL card's `Tag` still says "CASUAL · INSTANT", and the header says "nothing here can start".
- **Suggested fix:** Mark SquadClash and Convergence `Locked` (or remove the NOW LIVE! sticker) until a loop exists, and reconcile the mode list with the manual.

#### P6A-20: Stale player-facing text and comments in ReactionsBoard, MapRegistry and SlideAudio
- **Severity:** Low (doc drift)
- **Confidence:** High
- **Files/lines:**
  - `ReactionsBoard.client.lua:36-37` says "None of the ten is in the game's code yet". ElementalReactions.server.lua (2026-10-17) implements them, and also Toxic Squall, which the board omits (REACTIONS 64-85). Some board lines differ from the code: Wildfire "lasts longer or ... spreads" vs the code's "one more burn stack and a fresh clock"; Combustion "a Burning target inside a poison cloud" vs the code's "Pyro on Poisoned, or Toxin on Burning".
  - `MapRegistry.lua:21` says HubSky is "the Open Academy Hub's own sky" (it is UNIVERSAL_SKY). `:224-225` says "Sky = false: HubClient parks the painted skybox", but the entry sets `Sky = SAKURA_NIGHT_SKY`. SkylineConcept and SkylineRivals are both in the vote with the same Image and Sub (lines 152-182), so two near-identical cards appear.
  - `SlideAudio.client.lua:16-17` says "Your slide starts on the keypress; so does its sound", but the sound waits for the server-written `MoveState` attribute, a full round trip. It also says "a 1.1 s slide"; SlideDuration is now 1.6.
- **Suggested fix:** Update the texts. Have MovementController fire a local event, or set a client-side flag, so the slide sound starts on the press.

#### P6A-21: Dead and leftover live instances in the manifest
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/manifest.json`
- **Why:**
  - `/Workspace/Lighting` appears twice: two Folders of post effects (SunRays, DepthOfField, ColorCorrection, Bloom Threshold 4 / Size 65). Post effects render only under Lighting or a Camera, so these are inert duplicates of an old setup.
  - `/Workspace/ViewmodelArm3`: five unanchored, CanCollide true MeshParts left loose in the world. Viewmodel.lua uses `ViewmodelArm4` (line 1640). A copy already sits in `ServerStorage.RemovedDuplicates`.
  - `/Workspace/SpawnLocation` (12x12, visible decal) is disabled at runtime by HubServer but still a visible slab.
  - `/Workspace/OpenAcademyHub`: an entire unwired hub (see P6A-06).
  - Attributes nobody reads (grep-verified): Workspace `StageWrap = "Aurora"` (the stage tool) and `TGBuild = "done"`; Lighting `StashCamPos`, `StashCamLook` and `CapView` (capture-tool state).
  - `DeflectPractice.Catchable` (DeflectPractice.lua:91-103) has no caller. Deflect Gust is retired, and the module header (lines 16-22) still describes it as equippable. `DeflectGustPractice` is a live, used script despite the name.
- **Suggested fix:** Move the leftovers to ServerStorage and clear the stray attributes.

#### P6A-22: Minor client nits in TouchBus, DevPanel and the dev buttons
- **Severity:** Low
- **Confidence:** High
- **Files/lines:**
  - `TouchControls.client.lua:386` with `TouchBus.lua:24`: `TouchBus.Fire("CrouchClear", true)` leaves `Bus.Down.CrouchClear = true` for the rest of the session. It is a one-off action and nothing reads it today.
  - `DevPanel.client.lua:250-257`: "PASSIVE ON / OFF" set `PassiveActive` on the character from the client, which never replicates, so the server and other clients never see it.
  - The whole panel (hundreds of instances, plus a BarFX require) is built for every live player, though only devs can open it.
- **Suggested fix:** Use a separate one-shot event for CrouchClear. Route the passive buttons through DevRequest. Build the panel lazily on the first open by a dev.

#### Could not complete
- Enabled/Disabled and RunContext of every script are not in the manifest (only ParticleEmitter.Enabled is recorded). The severity of P6A-01/02/08/10 (the UmbraHandler copy) and P6A-06 depends on Studio properties that cannot be seen from the snapshot.
- I did not trace whether server-side hit validation would actually be blocked by the _ShowcaseSrv wall at the training range (TargetBoard and arena positions are not in the manifest; Models carry only ExtentsSize).
- I did not trace the Umbra cast path's CC refusals (P6A-16) or the server sweeps for the dashes through Bulwark Wall (P6A-05); they are left to the Umbra, Terra and Zephyr passes.

### Pass 6 slice B — code-vs-doc drift (Design Manual v0.24, Dev Diary, HANDOFF.md, README, SFX plan)

#### Files read (complete list, with "fully" or "partially: lines X-Y" for each)
- `docs/SPELLSHOT_Design_Manual.md` — fully (1-831)
- `docs/SPELLSHOT_Dev_Diary.md` — fully read 1-839, 876-954, 1110-1641; lines 840-875 and 955-1109 (Pyro/Toxin Blender-showcase-only passes) skimmed and grepped for Studio/code claims (none found: every one of those entries says "showcase only, nothing in Studio")
- `docs/HANDOFF.md` — fully
- `README.md` — fully
- `docs/SPELLSHOT_SFX_Plan_CoreCombat.md` — fully (skim pass asked for; it is short)
- `docs/build_prompts/` (listing only), `docs/vfx_handoffs/` (listing + grep "everfrost"), `sim/README.md` — fully
- `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua` — fully
- `game/ReplicatedStorage/Spellshot/EconomyConfig.lua` — fully
- `game/ReplicatedStorage/Spellshot/SkinCatalog.lua` — partially: 1-120, 240-290, 360-480
- `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua` — partially: settings table 55-160
- `game/ReplicatedStorage/Spellshot/Callouts.lua` — partially: 95-115
- `game/ReplicatedStorage/Spellshot/MapRegistry.lua` — partially: 1-20, 100-140, 260-270
- `game/ReplicatedStorage/IceMagic/VFXLibrary.lua` — partially: 1-120, 225-520 (header, Tuning.FlashFreeze, every ability row, AbilityFor, TechniqueSlot)
- `game/ReplicatedStorage/IceMagic/UmbraTuning.lua` — partially: 1-105
- `game/ReplicatedStorage/IceMagic/VoltaicTuning.lua` — fully
- `game/ReplicatedStorage/IceMagic/ToxinTuning.lua` — partially: 95-192
- `game/ReplicatedStorage/IceMagic/AquaTuning.lua` — partially: 145-185
- `game/ReplicatedStorage/IceMagic/CryoTuning.lua` — partially: 1-30, grep Chill
- `game/ReplicatedStorage/IceMagic/RadiantTuning.lua` — grep (Halo/Benediction lines)
- `game/ReplicatedStorage/IceMagic/PyroFX.lua` — partially: 1-140 (Tuning)
- `game/ReplicatedStorage/IceMagic/ZephyrFX.lua` — partially: 80-105, 440-480
- `game/ReplicatedStorage/IceMagic/VoltaicFX.lua`, `CascadeFX.lua` — grep Windup
- `game/ReplicatedStorage/IceMagic/TerraFX.lua` — grep WallHP
- `game/ServerScriptService/StatusEffects.lua` — partially: 1-140
- `game/ServerScriptService/ElementalReactions.server.lua` — partially: 1-80, grep
- `game/ServerScriptService/SpellshotService.server.lua` — partially: 105-135, 335-350, 395-425, 725-785, 925-990
- `game/ServerScriptService/PyroHandler.server.lua` — partially: 1-45, grep Heat/Cinder/EmberRefund
- `game/ServerScriptService/DuelMatch.lua` — partially: 1-60, 270-300
- `game/ServerScriptService/HubServer.server.lua` — partially: grep + 1105-1135, 310-320, 420-430, 480-490
- `game/ServerScriptService/PlayerData.lua` — partially: 1-80
- `game/ServerScriptService/HitboxScale.server.lua` — partially: 1-60
- `game/ServerScriptService/ToxinHandler.server.lua`, `TerraHandler.server.lua`, `ZephyrHandler.server.lua`, `AbilityHandler.server.lua`, `CombatCore.lua` — grep only
- `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua` — partially: 235-260, grep `.Desc`
- `game/StarterPlayer/StarterPlayerScripts/QuickPlay.client.lua` — partially: 40-145
- `game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua` — partially: 1-60
- `game/StarterPlayer/StarterPlayerScripts/MovementController.client.lua`, `SpellshotInput.client.lua`, `DevPanel.client.lua` — grep only (+ SpellshotInput 170-190)
- `game/StarterGui/SpellshotShop/Catalog.lua` — partially: 1-61; `ShopController.client.lua` — grep
- `game/ServerStorage/MovementSwitchReviewFix_2026_10_18/*`, `UmbraReviewFix_2026_10_18/UmbraHandler.server.lua` — diffed in full against the live copies; `_superseded_everfrost_2026_10_14/chill_ef.lua` — partially: 1-30 + reference grep

#### Sub-areas checked with nothing found (explicit "checked, clean: ..." lines)
- checked, clean: Mana 100 / regen 7 (manual 806) = `SpellshotConfig.lua:39-40`; Icicle Shard 2 mana at 3/s (manual 807) = `VFXLibrary.lua:237`.
- checked, clean: M1 is never refused for lack of mana (manual 540) — `SpellshotService.server.lua:962-965` floors the bar at 0 and fires anyway.
- checked, clean: Ultimate charges from damage dealt AND taken (manual 220, 540) — `SpellshotConfig.lua:41-43` (`UltChargePerDamage`), charge-gated cast `SpellshotService.server.lua:938-943` (dev exception: see P6B-05).
- checked, clean: Duel first-to-5 (manual 222, 562) — `SpellshotConfig.lua:225`; map vote with coin-flip tie (manual 570) — `HubServer.server.lua:426-427`.
- checked, clean: loadout lock during a live match (manual 216) — `SpellshotService.server.lua:748-756` refuses Element/Technique changes in Arena+DuelMatch (cosmetic skin/wrap changes are allowed before that gate, which the manual's lock does not cover).
- checked, clean: no health in the Hub / no player damage in Solo Test / teammates never hurt each other (manual 25-28, 537-538) — `Config.MayHurt` `SpellshotConfig.lua:184-192`.
- checked, clean: sprint is automatic, crouch 8, sprint 25 (manual 542, 810) — `MovementController.client.lua:6,808`, `SpellshotConfig.lua:56-57`.
- checked, clean: Umbra appendix numbers (manual 825-830) — Shadow Dart 2.3 s / 2.6 s / 65 / 5 mana / range 160 (`UmbraTuning.lua:20-25`), Unseen +25% at 60° (`:40-41`), Shadow Step 22/4/0.12/0.6/10 s/20 mana (`:49-56`), Mark 1/s to 3, 5 s, 50/100/150, 10/20/30, 14 s, 18 mana, 120 (`:76-81`), Decoy 3.8/8 s/20 s/18 (`:89-91`), Eclipse 1.0 s + 7 s, 1.5x, 250 (`:98-102`). Only the dart speed drifts (P6B-17).
- checked, clean: Cross-Slash Dash (tap 12 / full 40 at 1 s / auto 1.5 s / 110 studs/s / 40% move) = `ZephyrFX.lua:89-101`; Cyclone (1.2 s form, 4 s, radius 26, 6 per 0.5 s, range 70) = `ZephyrFX.lua:452-477`, `VFXLibrary.lua:357-358`.
- checked, clean: Patient Zero Variant B, constant radius 20 (diary 1131, 1273) = `ToxinTuning.lua:153`; Toxic Bubble stops at the first enemy (diary 1130) = `SpellshotConfig.lua:339`.
- checked, clean: Chill stack 3 is now a slow, not a root (diary 1522, 1535) = `StatusEffects.lua:65-75` (`SlowCaps`). The fix reached code; only the docs/Desc lag (P6B-11).
- checked, clean: Cascade `Windup = 0.50` (diary 401-402) is still live = `VoltaicFX.lua:52` (the diary's "needs the owner's yes" is still open; no later entry records the yes).
- checked, clean: Railspike 0.55 s fixed charge, 30 per pierced body (diary 390-391) = `VoltaicTuning.lua:46`; Volt Orb hold-to-aim (diary 1600) = `VoltaicTuning.lua:49-51`.
- checked, clean: Devil skin as an Element skin on `ElementSkin_<Element>` via LoadoutRequest "ElementSkin" (diary 1600) = `SpellshotService.server.lua:729-736`, `SkinCatalog.lua:435`; composite `"<Skin>+<Wrap>"` with colour wraps only (diary 1605) = `SkinCatalog.WrapsOverSkin` `SkinCatalog.lua:477-481`.
- checked, clean: Aurora defined but not yet in `ElementWraps` (diary 1635) = `SkinCatalog.lua:337, 457-458`; Snow Globe Rare / Frost Lotus Epic (diary 1610, SkinCatalog 262-272).
- checked, clean: Toxin "self-damage relies on the game having no Teams" (diary 1142) — the team mode added since uses the `MatchTeam` attribute through `Core.IsFriendly`, which ToxinHandler already asks (`ToxinHandler.server.lua:180-182, 308, 548`); no regression.
- checked, clean: the M1 rate gate's 0.8x slack in `SpellshotService.server.lua:954-960` is backed by per-kit token buckets (`ZephyrHandler.server.lua:132-162`, `AbilityHandler.server.lua:816-843`), so it is not a sustained over-rate path for Wind Blade/Icicle Shard (other kits not individually checked).
- checked, clean: the three ServerStorage folders are not referenced by any live script (grep), and ServerStorage scripts do not run.

---

#### P6B-01: Techniques are own-Element-only (P31), but every doc still describes a shared cross-Element pool of "up to 3" — and the Dev Diary never records P31 at all
- **Severity:** Low (doc drift; design-level consequences in P6B-02 / P6B-03)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:497-509` (`TechniquesOwnElementOnly = true`), `:362` (two slots), `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:507-509`; docs: `README.md:6` ("adds up to 3 Techniques from a shared pool"), `docs/SPELLSHOT_Design_Manual.md:6` (pitch: "a shared cross-Element Technique pool"), `:47-48`, `:232-235`, `:306-308` ("Cross-Element mixing is a feature, not a bug"), `:482` (Reactions "reward ... loadout diversity the Technique pool encourages"), `:661`/`:712` (Technique reskins for a "borrowed Technique"), `:793`, `:814`; `docs/HANDOFF.md:17`; `docs/SPELLSHOT_Dev_Diary.md:1631-1641` (latest entry, 2026-10-18: no P31)
- **Trigger:** any reader using the manual/README/diary to understand the loadout.
- **Why it's a bug:** code: `Config.ElementMayHold` returns `entry.Origin == element` while the flag is on, and the Loadout menu (`LoadoutMenu.client.lua:249-251`), LoadoutRequest (`SpellshotService.server.lua:779`), dev panel (`:414`, `DevPanel.client.lua:291`), `TechniquesFor` (`SpellshotConfig.lua:539`) and `AbilityFor` (`VFXLibrary.lua:507-508`) all ask it. Also two slots (Q/E), not three. The Dev Diary's grep for "P31"/"OwnElementOnly"/"own Element" finds nothing: the diary's last entry (2026-10-18) only reviews team-mode documents, so the single biggest rule change of that day exists only as a code comment. The manual pillar, README pitch, HANDOFF and the Technique-reskin product line (manual 661, 712) all assume borrowing. Code wins; docs are stale.
- **Suggested fix:** add a diary entry for P31 (date, owner's words, the flag, the Exclusive fallback) and a manual change note that either rewrites Section 2/7/8 for own-Element Techniques or marks the shared pool as "switched off by flag". Fix README line 6 ("two Techniques from your own Element").
- **Notes:** the code comment explicitly supports flipping the flag back, so the manual text is "latent-true". Cross-ref the P31 enforcement passes.

#### P6B-02: Under P31 Pyro alone gets four Techniques — the two the manual retired in v0.7 (Heat Rush, Cinder Shield) are live, built and selectable again, and the Heat resource the manual retired is live
- **Severity:** Medium (gameplay: retired kit pieces reachable in matches; per-Element asymmetry)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:378, 403` (pool rows), `:426` (Ring of Fire "bigger and hotter at high Heat"); `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:264-267` (`HeatRush`/`CinderShield` rows, `Implemented = true`); `game/ServerScriptService/PyroHandler.server.lua:27-28` ("Heat Rush and Cinder Shield stay ... in the pools for anyone else who equips them"), `:498-559` (Heat, ranged reduction), `:574-585`, `:703-709` (Ring of Fire `HotReach`/`HotDamage`); `game/ReplicatedStorage/IceMagic/PyroFX.lua:85-92, 134`; docs: `docs/SPELLSHOT_Design_Manual.md:49-50, 277-278, 282, 317, 831`
- **Trigger:** a Pyro opens the Loadout: `techniqueList()` (`LoadoutMenu.client.lua:245-259`) lists every `Origin == "Pyro"` entry — Heat Rush, Detonate, Cinder Shield, Scorching Lash — and `MayEquip("Pyro","HeatRush")` is true (Pyro is built, has no `PartialKits` row, `SpellshotConfig.lua:678, 719-723`). Every other Element sees exactly its two defaults.
- **Why it's a bug:** the manual says Heat Rush/Cinder Shield are retired, "Pyro contributes none", Heat "has no trigger left" and the Ring of Fire Heat bonus "no longer applies" (831). In code they were kept "for anyone else who equips them" (PyroHandler 28) — i.e. for cross-Element use — and P31 removed exactly that audience while leaving the Origin = Pyro owner able to equip them. Result: Pyro has a 4-Technique choice (and Ring of Fire's +36% damage / +20% reach at high Heat via Heat Rush), every other Element has a fixed pair (the Q/E "swap" only reorders them). Neither the manual (0 Pyro Techniques) nor the P31 intent ("swap within your own Element") describes this.
- **Suggested fix:** owner decision: either remove the HeatRush/CinderShield rows from the pool (or mark them retired in `Config.RetiredTechniques` so `TechniquesFor` maps them away and `ElementMayHold` refuses them), or document that Pyro keeps four. Fix the Ring of Fire Desc either way.
- **Notes:** latent with `TechniquesOwnElementOnly = false`: every Element could again borrow two Techniques the manual calls retired.

#### P6B-03: Manual's Technique Pool table, contributor rule and Element tables are several reworks behind the code
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** manual `docs/SPELLSHOT_Design_Manual.md:246` (Cryo Ultimate "Cryo Beam"), `:247` (Voltaic Ultimate "Thunderclap", Passive "bonus damage vs stationary"), `:248` (Terra Ultimate "Seismic Slam"), `:254-271` (pool: Frost Slide, Tremor Vault, Gust Jump, Chill Aura, Deflect Gust), `:304`/`:815` ("12 ... Pyro and Voltaic contribute none"), `:487` ("Terra's Fault Line (its new Ultimate)"), `:823` (Gust Jump numbers); code `SpellshotConfig.lua:377-442` (pool and Ultimates: Blizzard, Deep Freeze, Railspike, Volt Orb, Aftershock, Skyrider, Gust Pad, Detonate, Scorching Lash, Twin Tide, Sidearm; Mirror Cage, Cascade, Earthen Tomb), `:296` (Voltaic Passive "Chain Reaction"); `VoltaicTuning.lua:38-41`
- **Trigger:** reading Section 2 / Appendix.
- **Why it's a bug:** the code pool has 19 entries (8 of 9 Elements contribute; Pyro 4, Voltaic 2) against the manual's 12 from 6. Several are noted in the manual's own change notes (v0.11 Mirror Cage; Toxin/Umbra/Radiant reworks) but the tables were never rewritten; others (Voltaic's Railspike/Volt Orb/Cascade/Chain Reaction, Terra's Aftershock/Earthen Tomb, Zephyr's Skyrider/Gust Pad, Pyro's Detonate/Scorching Lash, Exclusive flag) appear nowhere in the manual. The Dev Diary (2026-10-06, line 1428) itself says the Zephyr kit is "not in the design manual". Also the manual internally contradicts itself (line 248 Seismic Slam vs line 487 Fault Line; line 246 Cryo Beam vs v0.11 line 74).
- **Suggested fix:** a v0.25 rewrite of the 8/9-Element table, the pool table and the appendix from `SpellshotConfig.lua`.
- **Notes:** none.

#### P6B-04: Dev Diary claims two manual edits (v0.16 Cascade-for-Thunderclap; v0.17 Antitoxin Vent cleanse + Acid Rain hybrid) that are not in the manual — the manual's v0.16/v0.17 numbers belong to different (Umbra) changes
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `docs/SPELLSHOT_Dev_Diary.md:198-202` ("Manual updated to v0.16 ... Voltaic's Ultimate table entry now reads Cascade"), `:219-223` ("bumped to v0.17: Antitoxin Vent ... cleanse ... Acid Rain now a hybrid ... light direct damage tick"); manual `docs/SPELLSHOT_Design_Manual.md:113, 124` (v0.16/v0.17 = Umbra), `:247` (still "Thunderclap"), `:271, 348` (Acid Rain still "proposed default ... rather than direct damage"), `:347` (Vent's enemy-poison question still "Flagged, not resolved"); code `SpellshotConfig.lua:416` / `ToxinTuning.lua:186` (Acid Rain `TickDamage = 6`, a direct tick), `SpellshotConfig.lua:397`
- **Trigger:** using the diary as the record of what the manual says.
- **Why it's a bug:** the diary's edits were made to a different copy of the manual (committed to `D:\...`) and lost when the manual forked; the repo's manual never received them, and its version numbers were re-used for Umbra. The code follows the diary (Acid Rain hybrid; Cascade), so the manual is the stale side.
- **Suggested fix:** port the two lost edits into v0.25 under new version numbers; add a diary note that the 2026-09-26 "v0.16/v0.17" numbers do not match the repo manual.
- **Notes:** also see P6B-09 (the Vent changed again after that).

#### P6B-05: Dev free-Ultimate is ON by default in live servers for the owner and a collaborator, contradicting the config's own comment and the manual's "charge-gated, can't be hoarded" rule
> **Consolidator:** duplicate of **P1-02** (Dev mode live: free Ultimate in ranked + unlimited Sparks). Kept here for its slice-specific detail; counted once, under P1-02.
- **Severity:** Medium (competitive integrity, limited to two accounts; would be High once matches are public/ranked)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:147-151` ("It is off for live by default so a published build cannot hand a player an Ultimate on tap"), `:158` (`AllowInLiveGame = true`), `:159-161` (`UserIds[2800693640]`), `:164` (`FreeUltimate = true`), `:209-219` (`IsDev`); `game/ServerScriptService/SpellshotService.server.lua:122-127, 344-347, 935-943`; manual `docs/SPELLSHOT_Design_Manual.md:220, 540`
- **Trigger:** the place owner (user-owned place) or user 2800693640 joins a live server and queues Quick Play: `s.FreeUltimate = s.Dev and DEV.FreeUltimate == true` is true from the first state build, `UltCharge` is pinned at 1, and the Ultimate cast skips the charge check and never spends it — in a real team match that pays Sparks (`DuelMatch.lua:274-294`).
- **Why it's a bug:** the comment at 150-151 describes a safety that line 158 turns off; nothing in DuelMatch/team mode disables dev freebies inside a match. The manual's Ultimate is charge-based by rule.
- **Suggested fix:** set `AllowInLiveGame = false` before any public play, or at least force `FreeUltimate/FreeMana/NoCooldowns` off while the player has a `DuelMatch` attribute; correct the comment.
- **Notes:** the comment at 154-158 says this is deliberate for Team Test; still a live-server path. Cross-ref the dev-tools/anti-cheat pass.

#### P6B-06: Modes — manual's 2v2 and 5v5 Squad Clash vs code's 3v3 "DUEL" team match; Quick Play advertises Squad Clash and "CONVERGENCE · NOW LIVE!" as selectable but the server refuses both
> **Consolidator:** canonical entry for: Quick Play advertises modes the server refuses. Also reported as **P6A-19**.
- **Severity:** Low (doc drift + misleading UI)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:236-255` (`Config.Team.Size = 3`, "drop 1v1 Duel as a parallel mode"); `game/StarterPlayer/StarterPlayerScripts/QuickPlay.client.lua:51-55, 116-129` (Squad Clash and Convergence have no `Locked`, Convergence carries `Burst = "NOW LIVE!"`); `game/ServerScriptService/HubServer.server.lua:1118-1119` ("Only DUEL can start a match in this build"); `game/ServerScriptService/DuelMatch.lua:3-8`; manual `docs/SPELLSHOT_Design_Manual.md:41, 562-566, 212`; diary `docs/SPELLSHOT_Dev_Diary.md:1639` ("Open: ... team size decision")
- **Trigger:** a player selects SQUAD CLASH or CONVERGENCE and presses QUEUE.
- **Why it's a bug:** the manual's mode table (Duel 1v1 ranked, 2v2, Squad Clash 5v5 first-to-6 with an objective) matches nothing in code: the card titled DUEL is a 3v3 (`Sub = "%dv%d · TEAMS"`), there is no 2v2, Squad Clash has no loop, and a pad duel is the only 1v1. The diary's latest entry still lists "team size decision" as open although Size 3 shipped the same day. The UI tells players Convergence is live when it cannot start.
- **Suggested fix:** mark Squad Clash/Convergence `Locked` until they have loops (drop the NOW LIVE! burst); add a diary/manual note for the 3v3 team mode.
- **Notes:** none.

#### P6B-07: Economy — Sparks are only earnable from a full 6-player Quick Play team match; EconomyConfig's "a duel WIN pays 200" and the manual's earn sources do not exist
- **Severity:** Medium (economy: free path to 4 locked Elements is blocked on low-population servers)
- **Confidence:** High (code facts); Medium (impact depends on live population)
- **Files/lines:** `game/ReplicatedStorage/Spellshot/EconomyConfig.lua:16-17` (yardstick "a first-to-5 duel WIN pays ... 200 Sparks"), `:28, 33-39, 45-52`; `game/ServerScriptService/DuelMatch.lua:54-56` ("A Hub pad duel awards nothing"), `:277-279` (`if match.Kind ~= "Team" then return end`); `SpellshotConfig.lua:245` (`Size = 3`); `HubServer.server.lua:1118-1125`; manual `docs/SPELLSHOT_Design_Manual.md:607, 614, 618, 722, 729`
- **Trigger:** a free player wants Aqua/Toxin/Umbra/Voltaic (1600-2000 Sparks): pad duels and Solo Test pay 0; Quick Play only starts at 2 x 3 = 6 queued players; no daily login, Contracts or party bonus exist.
- **Why it's a bug:** the manual's guardrail is "Sparks must always be earnable through play at a reasonable rate" with sources "match completion, dailies, Contracts"; EconomyConfig's own pricing rationale is written for duel wins that pay nothing. Starter set also drifts (manual 530/749: Pyro, Terra, Radiant + Bulwark Wall; code `EconomyConfig.lua:28`: Pyro, Zephyr, Cryo, Terra, Radiant).
- **Suggested fix:** pay (at least a reduced) reward for pad duels, or document that only team matches pay and re-derive prices from team-match rewards; update the manual's starter kit.
- **Notes:** cross-ref the economy pass.

#### P6B-08: Every skin and wrap is free to everyone (`OwnsSkin` always true) although EconomyConfig says "Skins and wraps stay Robux-only"; the shop is a demo whose catalog contradicts the manual's v0.23 rules
> **Consolidator:** duplicate of **P2-06** (OwnsSkin always true: every cosmetic free). Kept here for its slice-specific detail; counted once, under P2-06.
- **Severity:** Medium (monetization gap if published as is)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:16-17, 420-423` (`OwnsSkin` returns `Skins[skinId] ~= nil`); `game/ReplicatedStorage/Spellshot/EconomyConfig.lua:10`; `game/StarterGui/SpellshotShop/Catalog.lua:5-11, 19, 23, 27-37, 45-47` (rarity "Common"/"Seasonal", "Tint", Mythic "drops from the Cache", invented items such as Voltaic "Stormcaller", Umbra "Nightshade"), `ShopController.client.lua:833` ("Demo: purchase not connected yet"); manual `docs/SPELLSHOT_Design_Manual.md:614, 626-636, 696-707`; diary `:1539` (OwnsSkin stub)
- **Trigger:** any player opens Loadout > SKINS/WRAPS and equips Devil, Frost Dragon (Mythic), Aurora-tier wraps etc.: LoadoutRequest (`SpellshotService.server.lua:733, 742`) accepts them.
- **Why it's a bug:** manual: Element Skins direct purchase only, never from a Cache; Common tier retired; Uncommon Wraps buyable with Sparks. EconomyConfig: Robux-only. Code: free for all; the shop sells placeholder items that are not in SkinCatalog, with retired rarity words. Also `SkinCatalog.lua:278-281` lists Frost Dragon "IN BUILD — stage 1, other pieces draw the Default" as a selectable Mythic.
- **Suggested fix:** wire `OwnsSkin` to PlayerData ownership before publishing; regenerate Catalog.lua from SkinCatalog with the v0.23 tiers; hide in-build skins from `ElementSkins`.
- **Notes:** known placeholder per the code comment; graded Medium because it is the one place the "Robux buys looks" economy is meant to be enforced.

#### P6B-09: Antitoxin Vent now cuts EVERY DoT by 30% (enemy burn and poison), contrary to the manual/diary rule that it stays own-poison-only so it cannot hard-counter a Toxin mirror
- **Severity:** Low (doc drift; a balance change the docs forbid)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ToxinTuning.lua:170-171` (`DoTReduction = 0.30`, "2026-10-17, the owner's pick"), `game/ServerScriptService/ToxinHandler.server.lua:197-200`, `SpellshotConfig.lua:397`; manual `docs/SPELLSHOT_Design_Manual.md:265, 347`; diary `docs/SPELLSHOT_Dev_Diary.md:220` ("stays own-poison-only, so it can't become a hard-counter Technique in a Toxin mirror")
- **Trigger:** a Toxin with the Vent on takes Pyro Burn / enemy Toxin poison ticks.
- **Why it's a bug:** code reverses a documented decision; no diary entry records the 2026-10-17 balance pass that made it.
- **Suggested fix:** record the 2026-10-17 balance pass (the code cites `CHANGES_2026-10-17_balance_pass.md`, which is not in the repo) in the diary and manual.
- **Notes:** see P6B-14 for the other undocumented 2026-10-17/18 changes.

#### P6B-10: Ragdolls, "a body is scenery, not cover" and "bodies clear after ~3 s" are not implemented; in team mode a downed body stays for the whole round with its 2x query-able hitbox twins
> **Consolidator:** canonical entry for: Team-mode corpses (and hitbox twins) block six kits' shots. Also reported as **GC-01**.
- **Severity:** Medium (possible gameplay bug: corpses may catch aim rays/shots in 3v3)
- **Confidence:** Low (that corpses actually block shots is not traced through every kit)
- **Files/lines:** manual `docs/SPELLSHOT_Design_Manual.md:549-554, 669-686, 820`; `game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua:14-18, 31` (only a 0.45 s white burst; default Roblox death, no ragdoll); `game/ServerScriptService/HubServer.server.lua:486-487` (`Players.RespawnTime = 1e6`); `game/ServerScriptService/DuelMatch.lua:29-33` ("nobody comes back mid-round, and the camera stays on the body"); `game/ServerScriptService/HitboxScale.server.lua:43-49` (twins `CanQuery = true`, welded to the body parts); `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:173-185` (aim ray excludes only unhurtable characters, not dead ones)
- **Trigger:** 3v3, an enemy goes down in a doorway; teammates keep fighting around the body.
- **Why it's a bug:** the manual says a body has no hitbox, blocks nothing and clears in ~3 s. In code the default death leaves the body (and, if the twins survive the joint break, 2x-size query-able twins) in the world until the next round's LoadCharacter; the crosshair aim ray (`Config.AddUnhurtable` filters by `MayHurt`, which is true for a dead enemy) can land on it, and any kit ray that does not skip `Health <= 0` models would stop there.
- **Suggested fix:** on death, move the body to a non-queryable collision group / set its parts and twins `CanQuery = false`, and clear it after ~3 s; or add dead characters to the shared ray exclude list.
- **Notes:** confirm by checking each kit's projectile/ray filter for dead humanoids (other passes). The basic kill effect is also not the manual's "KO!" lettering + exit beat (manual 673).

#### P6B-11: Player-facing Technique/kit descriptions in SpellshotConfig are stale against the rows that are actually charged
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:286` (Icicle Shard "3 stacks briefly roots" — now a slow, `StatusEffects.lua:65-75`), `:294` (Chain Bolt "short range": 55), `:380` (Blizzard "where you stand ... for 8 seconds": `CryoTuning.lua:21, 25` CastRange 20, Duration 6), `:418` (Scorching Lash `Cooldown = 2.5`: row is 5, `VFXLibrary.lua:280-281`), `:279` (Fireball "Straight shot" vs manual "slow arcing lob"), `:426` (Ring of Fire Heat clause); shown to players by `LoadoutMenu.client.lua:843`
- **Trigger:** a player browses Techniques in the Loadout.
- **Why it's a bug:** the Loadout prints `Entry.Name .. ": " .. Entry.Desc`; several Descs describe pre-2026-10-17/18 behaviour. The manual has the same stale Chill text (`docs/SPELLSHOT_Design_Manual.md:246, 462`), which the diary says must be edited (`docs/SPELLSHOT_Dev_Diary.md:1522, 1545`) and still is not.
- **Suggested fix:** refresh the Desc strings and manual lines.
- **Notes:** also stale code comments: `SpellshotConfig.lua:4-28` (v0.2, "three shared Technique pools", "a Cryo running Heat Rush"), `:584` ("The manual has no status-effect section"), `:673-677` (BuiltElements "Cryo and Pyro... the other six"); `VFXLibrary.lua:4-9` (Frost Slide/Chill Aura/Cryo Beam kit); `StatusEffects.lua:16-19` ("No Chain Bolt exists yet", "AloneDamage 0 in preset A" vs 7 at `:77`); `SkinCatalog.lua:4-5` ("A skin changes COLOUR only: no shape").

#### P6B-12: Movement, hitbox and projectile numbers in the manual appendix are out of date
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** manual `docs/SPELLSHOT_Design_Manual.md:536, 543, 810, 825, 831`; code `SpellshotConfig.lua:38` (HP 150), `:61` (SlideDuration 1.6), `:68-69` (no cooldown, 0.1 s regap), `:93-95` (boost 22, 42-52 clamp), `:101-119` (wall run / double jump, not in manual), `:125-136` (Movement Mode switch), `:257-268` (Hitbox Scale 2.0 and one M1 speed 200); `UmbraTuning.lua:23` (200, appendix 240); `PyroFX.lua:58, 120, 134` (Fireball straight 200; Ring of Fire radius 17.5 vs appendix 25; Heat variant live)
- **Trigger:** reading the appendix.
- **Why it's a bug:** slide "up to 1.1 s with a 1.2 s cooldown; slide-jump +20" vs 1.6 s / no cooldown / +22; Ring of Fire 25 vs 17.5; Shadow Dart 240 vs 200; Fireball "slow arcing lob, must be led" vs a straight 200-stud/s shot. The 2x-per-axis hitbox (8x volume) is a large competitive change (easier Mark headshots via head twins) with no manual mention; the manual's "hits count where the shot visibly passes" (543) no longer describes it.
- **Suggested fix:** refresh the appendix; add a combat-feel note for Hitbox Scale and the unified M1 speed.
- **Notes:** none.

#### P6B-13: Pyro and Voltaic passives changed trigger/mechanic; the manual's Shatter reaction rationale depends on a Voltaic passive that no longer exists
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/PyroFX.lua:76-81` (`EmberRefund.Trigger = "LowHealth"`), `ServerScriptService/PyroHandler.server.lua:13-14, 450-490`; `VoltaicTuning.lua:38-41` (Chain Reaction: Charged fill -> 2 s off Overcharge); `ServerScriptService/ElementalReactions.server.lua:16, 52` (Shatter = flat Bonus 10); manual `docs/SPELLSHOT_Design_Manual.md:245` ("Landing a kill refunds"), `:247` ("Bonus damage vs. stationary"), `:507` (Shatter "Voltaic's own Passive already deals bonus damage to stationary targets")
- **Trigger:** reading Section 2.
- **Why it's a bug:** code moved Ember Refund to "drop an enemy under 30%" and Voltaic to Chain Reaction on 2026-10-17 (no diary entry); Shatter is implemented as a fixed bonus, so the manual's "real trade-off" logic is gone.
- **Suggested fix:** update the manual's Element table and Shatter row.
- **Notes:** ElementalReactions also decides the manual's open question (522: teammate Elements react like self-mixed ones) without the manual or diary recording it (`ElementalReactions.server.lua:27-30`). Under P31 a Duel player cannot self-mix Elements, so in 1v1 reactions only fire off self-applied statuses (e.g. a Toxin's own poison); the manual's "reward loadout diversity" premise (482) is mostly dead in Duel.

#### P6B-14: The Dev Diary records none of the code changes of 2026-10-17/18 that the code cites (balance pass, reactions, team mode, economy, movement switch, P27/P29/P31, handoffs #7/#8, Umbra escape charge, hitbox scale) — and the cited documents are not in the repo
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** code citations: `SpellshotConfig.lua:91-92` (`CHANGES_2026-10-17_balance_pass.md`), `:125-136, 236-255, 257-268, 497-503`; `VoltaicTuning.lua:29` ("handoff #7 ... the values the 3v3 sim validated"); `UmbraTuning.lua:58-68` ("handoff #8, the 3v3 sim's P27"); `VFXLibrary.lua:114`, `CryoTuning.lua:20` (P29); `ElementalReactions.server.lua:4` ("manual v0.23 ... built 2026-10-17"); `EconomyConfig.lua:4`, `PlayerData.lua:4`; docs: `docs/SPELLSHOT_Dev_Diary.md:1613-1641` (the only 2026-10-17/18 entries, wraps + a review of team docs), `README.md:25-26` (Problem Sheet / Implementation Handoff "not in this repo yet"), `sim/README.md` ("no balance or team simulation scripts were found")
- **Trigger:** a reader trying to learn from the diary what was built last (README 27-28 tells them to).
- **Why it's a bug:** README says the latest diary entries "say what was built last"; for 2026-10-17/18 they do not. The code justifies numbers with a 3v3 sim and numbered handoffs/problems that neither the repo nor `sim/` contains, so none of those values can be checked against their source.
- **Suggested fix:** add the missing diary entries; copy the balance-pass changelog, handoffs #7/#8 and the Problem Sheet (P27/P29/P31) into `docs/`; have refresh.ps1 copy the sim.
- **Notes:** the diary itself admits gaps (`:1611`, `:1621`, `:1633`).

#### P6B-15: ServerStorage review-fix folders hold the PRE-fix copies; the fixes are already live, and no doc mentions any of the three folders
> **Consolidator:** duplicate of **P6A-10** (ServerStorage ReviewFix folders hold PRE-fix copies). Kept here for its slice-specific detail; counted once, under P6A-10.
- **Severity:** Low (housekeeping / misleading names)
- **Confidence:** High
- **Files/lines:** `game/ServerStorage/MovementSwitchReviewFix_2026_10_18/{TouchControls.client.lua,MovementController.client.lua,SpellshotConfig.lua}` vs live `StarterPlayer/StarterPlayerScripts/TouchControls.client.lua:382-386`, `MovementController.client.lua:783-794`, `ReplicatedStorage/Spellshot/SpellshotConfig.lua:133-135`; `game/ServerStorage/UmbraReviewFix_2026_10_18/UmbraHandler.server.lua` vs live `ServerScriptService/UmbraHandler.server.lua:33-36, 226-227, 748-811, 945-950`; `game/ServerStorage/_superseded_everfrost_2026_10_14/chill_ef.lua:1-10`; docs: grep of `docs/` finds no "ReviewFix", and "Everfrost" only in build prompts/handoffs as a dropped skin
- **Trigger:** a reader seeing "ReviewFix" folders assumes unapplied fixes.
- **Why it's a bug:** diffs show the live scripts contain the review fixes (CrouchClear latch drop, `RunningOnlyTouchCrouch = false`, Umbra's queued second Shadow Step with give-back on every exit path); the ServerStorage copies are the before-state backups (`RunningOnlyTouchCrouch = true`, a double-tap press given back whole). Everfrost is a dropped Cryo skin's Chill bar variant, unreferenced. The Dev Diary never mentions any of them, so whether they were applied is answerable only by diff.
- **Suggested fix:** rename to `_before_<fix>_2026_10_18` (the `CryoKitSuperseded.before_*` convention) and note them in the diary.
- **Notes:** the ServerStorage `SpellshotConfig.lua` copy also carries `TechniquesOwnElementOnly = true` (only line 133 differs).

#### P6B-16: HANDOFF.md (2026-09-12) would mislead a reader today on roster, kit structure, currencies, Cryo kit, source of truth and open items
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `docs/HANDOFF.md:11` ("the manual is the single source of truth ... trust the manual" — README 28-29 and the brief say the code ships), `:17` ("up to 3 freely-mixed Techniques (1 Mobility, 1 Defense, 1 Ultimate) drawn from shared pools of 8 each"), `:18` ("8 launch Elements"; code has 9 incl. Aqua, all built `SpellshotConfig.lua:678-695`), `:19` (currencies "Mana Shards, Sparks, Prisms" — Prisms dropped v0.3, Mana Shards not implemented), `:38, 113` (Cryo kit Frost Slide / Chill Aura / Cryo Beam — all retired, `VFXLibrary.lua:242-245`), `:96` (sound never confirmed — SFX plan exists), `:100` (no Hub build prompt — the Hub is built, `HubServer.server.lua`), `:101` ("Only Cryo has gone through the full kit") ; `:45-68` lists 13 Opus5_* prompt files none of which are in `docs/build_prompts/` (README 18 says that folder holds "the build prompts each VFX kit was made from")
- **Trigger:** a new session reading HANDOFF.md first (its own line 3 says "Read this fully before acting").
- **Why it's a bug:** almost every structural statement is superseded; its "trust the manual" rule directly conflicts with README's "the code is what ships".
- **Suggested fix:** prepend a banner: "historical, 2026-09-12; superseded by README + manual v0.24 + code", or move it to `docs/archive/`.
- **Notes:** README line 17 already calls it "an old 2026-09-12 project handoff", but HANDOFF.md itself does not say so.

#### P6B-17: Manual's Mana Shards / Attunement Phase, Mastery, Account Level, Contracts, separate mobile/PC pools are spec only; the diary says Mana Shards must become "points" and the manual was never corrected
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** manual `docs/SPELLSHOT_Design_Manual.md:222, 545, 586-588, 613, 729`; diary `docs/SPELLSHOT_Dev_Diary.md:1459-1463, 1531, 1545` ("the Mana Shards line still needs to say points"); code: grep of `game/` finds no `ManaShard`, `Attunement`, `Mastery`, account level, Contracts or input-type queue split (`HubServer.server.lua` queue is one list)
- **Trigger:** reading Sections 1, 3, 5, 6.
- **Why it's a bug:** the manual reads as if these are the rules; none exist and one (Mana Shards) is already known to be wrong per the diary.
- **Suggested fix:** mark them "not built" in v0.25 and apply the diary's Mana Shards -> in-match points correction.
- **Notes:** Mastery rank 3 Technique unlock (manual 588, 711) cannot exist under P31 (Techniques come with the Element).

#### P6B-18: Devil skin's HUD set and status relabel (PACTED! / DENIED! / VOIDED!, black-iron Blessed bar) described in the manual are absent from code
- **Severity:** Low
- **Confidence:** Medium (the words could be baked into image assets not visible in the snapshot)
- **Files/lines:** manual `docs/SPELLSHOT_Design_Manual.md:181, 650-651`; code: no `PACTED`/`DENIED`/`VOIDED` string anywhere in `game/`; only `blessed_a/f/t` variants under `ReplicatedStorage/Spellshot/BarFX/Variants/`; Devil is referenced only by Radiant FX modules (`RadiantDevilForge.lua`, `RadiantFX_*`, `RadiantAnim.lua`, `RadiantDraw.lua`, `RadiantClient.lua`, `SkinCatalog.lua:242-247`); `Callouts.lua:108-109` (one gold BLESSED style)
- **Trigger:** a player equips Devil and receives a Blessing.
- **Why it's a bug:** manual v0.24 lists the HUD set as part of the Devil skin; diary 2026-10-13 (`:1598-1600`) calls the skin "finished and in the game" but only covers the six ability models. The prompt `docs/build_prompts/Opus5_Radiant_DevilSkin_HUD_Reskin.md` exists; nothing shows it ran.
- **Suggested fix:** note in the manual that the HUD layer is not built.
- **Notes:** none.

#### P6B-19: Small UI/setting drifts: Training Ground solo range is in the match map vote; the basic kill burst ignores Reduce Flashing; SFX plan says no audio settings exist
- **Severity:** Low
- **Confidence:** High (vote, SFX); Medium (whether a 0.45 s white burst counts as a "flash")
- **Files/lines:** `game/ReplicatedStorage/Spellshot/MapRegistry.lua:122-125` (TrainingGround has no `Vote = false`), `ServerScriptService/HubServer.server.lua:318`; manual `docs/SPELLSHOT_Design_Manual.md:574` ("never a ranked map"); `StarterPlayer/StarterPlayerScripts/DeathFX.client.lua:1-60` (no Settings read) vs manual `:685` (kill effects honour Reduce Flashing) — contrast `ReplicatedStorage/IceMagic/FrostDragonKillFX.lua:178`; `docs/SPELLSHOT_SFX_Plan_CoreCombat.md` §7.1 vs `ReplicatedStorage/Spellshot/SpellshotSettings.lua:104-108` (VolMaster/SFX/Music/Interface exist)
- **Trigger:** a team-match map vote; any death with Reduce Flashing on.
- **Why it's a bug:** each contradicts the doc it is named against.
- **Suggested fix:** add `Vote = false` to TrainingGround before ranked opens; gate the DeathFX pop on ReduceFlashing (smaller/no scale pop); update the SFX plan.
- **Notes:** Graphics Quality has four options (LOW/MEDIUM/HIGH/ULTRA, `SpellshotSettings.lua:61`), not three; nothing in the manual sets a count.

#### P6B-20: Aqua's Sidearm and the manual disagree on the core verb (charged knock-back slug vs. held rapid-fire)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** manual `docs/SPELLSHOT_Design_Manual.md:330` ("hold to charge ... a denser slug that knocks the target back/up ... the held/charged shot is the one that launches"); code `game/ReplicatedStorage/IceMagic/AquaTuning.lua:150-169` ("The charged slug, and the launch that only it had, are gone"; every bullet knocks back), `SpellshotConfig.lua:422`
- **Trigger:** reading the Aqua subsection.
- **Why it's a bug:** owner-approved rework (2026-09-25, round 3) never written into the manual or diary.
- **Suggested fix:** update the Aqua table.
- **Notes:** Wet status (manual 467) has no writer — `ElementalReactions.server.lua:23, 133` mark Frozen-from-Wet and Windswept DORMANT; Terra's Cracked likewise held (`StatusEffects.lua:24`). Consistent with the manual's "not yet built" but worth one line in v0.25.

#### Could not complete
- Did not trace every kit's projectile/ray filter for dead bodies (P6B-10 is Confidence Low for that reason); other passes own the per-kit hit code.
- Dev Diary lines 840-875 and 955-1109 were skimmed by grep rather than read line by line; every entry in those ranges is a Blender-showcase pass that states it touched nothing in Studio, so no code claim was expected there.
- Visual "fixed" claims in the diary (frozen-black tint, Blizzard box, Mirror Cage reflections, Devil fb1 tweaks) cannot be verified statically.


---

## Gap-fill reads — UI / HUD / status-bar files read in full

_Each finding carries a **Pass:** tag; it belongs to that pass._

### Gap-fill A: full reads of LoadoutMenu, CardKit, PopArtHUD, BarKit, PopArtAssets, ReactionsBoard, BarFX (host + Atlas + 24 variants)

#### Files read (complete list)
- game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua: fully (1-1352)
- game/StarterGui/SpellshotShop/CardKit.lua: fully (1-1250)
- game/StarterGui/PopArtHUD.client.lua: fully (1-1036)
- game/ReplicatedStorage/Spellshot/BarKit.lua: fully (1-410)
- game/ReplicatedStorage/Spellshot/PopArtAssets.lua: fully (1-346)
- game/StarterPlayer/StarterPlayerScripts/ReactionsBoard.client.lua: fully (1-832), including every FRAME band table (374-399). I script-checked each band for y1 > y0 and right >= left, and checked the half-box/gradient corner logic by hand.
- game/ReplicatedStorage/Spellshot/BarFX.lua: fully (1-826)
- game/ReplicatedStorage/Spellshot/BarFX/Atlas.lua: header, tail and structure read. All 322 rects were script-checked for bounds (1024 px pages), overlaps and duplicate names.
- game/ReplicatedStorage/Spellshot/BarFX/Variants/: all 24 read fully. These are burn_t/a/f, chill_t/a/f, poison_t/a/f, charged_t/a/f, marked_t/a/f, blessed_t/a/f, primed_t/a/f and shield_t/a/f. The shared helper blocks were diffed between siblings: the toxin kit (poison_*) and the shield Kit (shield_*) are byte-identical in each set, and the blessed helpers match. I expanded every dynamically built sprite name (flame_<o><c>_<i>, aura<n>_<m>, lane<M|T>[p]<n>, ch<4|5>_<pal>, wick1-5, lid0-3, ...) and checked it against the atlas.
- Followed into (partially): SpellshotConfig.lua 355-780; EconomyConfig.lua 1-120; EconomyService.server.lua (InvokeServer returns, 66-78); SkinCatalog.lua 360-470, 590-613; IconAssets.lua 20-40; SpellshotSettings.lua 175-380; StatusEffects.lua 40-140, 355-380, 400-405; AbilityHandler.server.lua 736-800; PyroHandler.server.lua 560-590, 780-800, 855-890; TerraHandler.server.lua 1350-1430; UmbraHandler.server.lua 355-372; ElementalReactions.server.lua 1-120; SpellshotService.server.lua 76-82, 150-170, 350-375, 520-575; DuelMatch.lua 200-235; StatusReactions.client.lua 700-830, 860-890; ShopController.client.lua (grep only); Catalog.lua (ids, BAL); MovementController 610-620; SpellshotInput 1740-1750; BarFXClient (all); PyroFX.lua 85-93, 144-150; manifest.json around TV_Reactions_Screen.

#### Sub-areas checked with nothing found
- checked, clean (Pass 1): none of these clients sends anything the server trusts. LoadoutMenu's sends are LoadoutRequest ("Element", "Technique", "Skin", "ElementSkin", "ElementWrap") and EconomyRequest InvokeServer("UnlockElement"). It reads back `good, _, msg`, which matches EconomyService's `return ok, code, msg, ...`. The "Command" BindableEvents, `LoadoutOpen` / `ReactionsOpen`, `BarFX_<kind>` and `BarFXCommand` are all client-local. PopArtHUD, BarKit, BarFX and ReactionsBoard send nothing.
- checked, clean (Pass 2): LoadoutMenu shows the price from `Economy.PriceOf`, the same function the server charges with. The lock is drawn from the server-written `OwnedElements`. The confirm refuses while `DataLoaded ~= true` and says "SAVE UNAVAILABLE" on `DataError`. The balance comes from the `Sparks` attribute. `fmt` handles negatives. A confirm for one Element survives a reply for another (742).
- checked, clean: LoadoutMenu's `techniqueList()` can never be empty. Every Element has 2 or more `Origin == element` Techniques, and all 9 Elements are in `BuiltElements`, so neither `refreshRoles` nor `step` can index an empty list or take a modulo by zero.
- checked, clean: every `Stops` / `Label` in SkinCatalog has at least 2 colours, so LoadoutMenu's `(k-1)/(#stops-1)` keypoints (1040, 1146) never divide by zero.
- checked, clean: LoadoutMenu skin-row keys. `abilityKey(entry.Name)` gives Fireball / RingofFire / EarthenTomb / ShadowDart ..., and the Config Technique keys match the keys in `SkinCatalog.Offer`.
- checked, clean (Pass 4): PopArtHUD's `skinIcon` goes through `SkinCatalog.HudSkin`, which requires `player Element == elem`. So a borrowed Technique (latent) keeps its Default icon, and a Technique slot's glyph follows its own half and its Origin's colours.
- checked, clean: BarKit geometry. Health and mana are told apart by position and size, not only by colour. Readouts are mirrored per frame with the row scale. `api.Set` clamps.
- checked, clean: Atlas has 322 unique names on 8 pages (max index 8 = #images), with no out-of-bounds or overlapping rects. Every static and dynamic sprite name in the 24 variants resolves.
- checked, clean: the shared helper blocks have no copy-paste drift between siblings (toxin kit, shield Kit, blessed play/fire/flash/shards, chill crystal/popScale/R, burn flame/burst/word/ember).
- checked, clean: BarFX cleanup. Each look owns one sub-frame per layer, `_destroy` drops restyles, particles and timers, and words with `life = nil` die with the owner. `CharacterAdded` unmounts all looks and clears `Mem`.
- checked, clean: the ReactionsBoard FRAME tables are internally consistent. Every band is non-inverted, the Tab and Plate edges are continuous between bands, and `PLATE_TOP` (-90.6) and `TAB_LEFT` (-40.5) equal the tables' extremes. The `halfBox` solid-corner choice and the gradient normals are right for all four corners. The PC and phone box sums (`boxW = bw`, `boxH = bh`, card width 722 giving a 692 px line) add up as the comments say.
- checked, clean: the PopArtHUD round counter is team-aware (DuelMatch `publishScore` writes per-team RoundsWon/RoundsLost). HUD Opacity is applied to all three canvases and inherited by BarFX's back and front groups (BarFX.lua:716-718). The crosshair is deliberately excluded.
- checked, clean: CardKit is pure drawing. `sparksIcon` is exported (914), as LoadoutMenu needs. Element logo ids match IconAssets.Element. Every Catalog `el` is in `EL`.

---

#### GA-01: The BarFX chill looks show a ROOT / "FROZEN!" at Chill max stacks, which since 2026-10-08 is only a deep slow
- **Severity:** Medium
- **Confidence:** High
- **Pass:** 3
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:564` (`if kind == "chill" and rawS >= rawMax then pay = true end`), `:574`; `game/ReplicatedStorage/Spellshot/BarFX/Variants/chill_t.lua:181` (`mkWord("FROZEN!", ...)`), `:251-267` ("ROOT: the sealed block"), `:270`; `chill_a.lua:190` (`"ROOTED!"`), `:211-218` ("the root: the frame goes deep blue, the fill freezes"), `:257`; `chill_f.lua:200` (`"FREEZE!"`), `:261-266` ("ROOT: crystals burst out through the frame"); `game/ServerScriptService/AbilityHandler.server.lua:738-741` ("The third is the deepest slow (2026-10-08: it used to root ...). It never makes IceFrozenState: FROZEN! is reserved for real freezes"), `:776-789`; `game/ServerScriptService/StatusEffects.lua:64-69`
- **Trigger:** Any player hit by a third Icicle Shard (RX_Chilled_Stacks = MaxStacks 3). All three looks; "t" is the default.
- **Why it's a bug:** The server publishes `RX_Chilled_Stacks = CT.MaxStacks` for the whole Window (5 s in preset A) as a speed cap only. BarFX maps `rawS >= rawMax` to `pay`, which every chill look draws as a root ("ROOTED!", "FROZEN!", "FREEZE!", the HUD sealed in an ice block, root crystals through the frame). The victim's own HUD says they are rooted while they can still move. The server's own comment keeps the word FROZEN! for real freezes. Those real roots (Flash Freeze, Deep Freeze, Mirror Cage) publish no RX_Chilled stacks, and BarFX has no "rooted" kind, so a real root gets no bar treatment at all.
- **Suggested fix:** Rename and redraw the chill "pay" state as a deep-slow look (no "ROOTED/FROZEN" words, no block). Drive a root look from the real root state, which needs a BarFX kind fed by an RX_Rooted flag or IceFrozenState.
- **Notes:** The bench timeline in BarFX.lua:481 still models the old 3-stack root. Cross-ref P6B-11 (Icicle Shard Desc still says it roots).

#### GA-02: Shielded looks always play the BREAK at the end and never register a hit; Blessed's real break is never detected
- **Severity:** Low
- **Confidence:** High
- **Pass:** 3
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:566-572` (amount = `tonumber(amount) or 0`), `:589-591` (`payoff = ... (kind == "blessed" or kind == "shield") and (m.amount or 1) <= 0.01`); `game/ServerScriptService/PyroHandler.server.lua:567-585` (Cinder Shield writes only `RX_Shielded` and `RX_Shielded_Element`, using `ShieldAbsorb` for the amount); `game/ServerScriptService/TerraHandler.server.lua:1375-1388, 1424-1428` (Bedrock: the same); `game/ServerScriptService/StatusEffects.lua:134` (`_Amount = math.ceil(rec.Amount)`), `:361-371` (a broken Blessing goes straight to `Status.Clear` without publishing 0); `shield_t.lua:266-290`, `shield_a.lua` (hit/pay branches), `shield_f.lua` (hit/pay branches); `blessed_t.lua:150-157`, `blessed_a.lua:163-171`, `blessed_f.lua:148-156`
- **Trigger:** (a) Any Cinder Shield (Pyro) or Bedrock stack (Terra) ending, whether by expiry or by stacks lapsing. (b) A Blessing (Radiant) soaked to zero.
- **Why it's a bug:** (a) No writer sets `RX_Shielded_Amount`. So for kind "shield", `amount` is 0 for the whole life of the status: no "hit" event ever fires (the cracks, the ram/clasp losses and "KRAK!/THUD!/CLANG!" never play), and `m.amount = 0` makes every flag drop a payoff. Every shield end plays "SHATTERED!", "CRUMBLE!" or "ARMOR BREAK!" with 16-22 chunks and an amp 8-9 shake, including a Cinder Shield that simply expired ("expiring releases nothing", Config Desc). (b) For Blessed, the last published amount is `ceil(rec.Amount)`, which is 1 or more. On the killing soak the server clears without publishing 0, so `(m.amount or 1) <= 0.01` is never true: "SHATTER!/BROKEN!/BREAK!" is unreachable live, and a broken Blessing fades as if it had expired.
- **Suggested fix:** Have Pyro and Terra publish `RX_Shielded_Amount` (remaining absorb) and `_Expires/_Total`. Have StatusEffects publish `_Amount = 0` (or a `_Broken` flag) before clearing a soaked Blessing. Alternatively, pass the reason for the clear explicitly instead of inferring it.
- **Notes:** The DevPanel preview timelines (BarFX.lua:485-486) do model hits and breaks, which is why this would look correct in Studio previews.

#### GA-03: The default Shielded look is Terra stone ("BEDROCK!") even when the shield is Pyro's Cinder Shield
- **Severity:** Low
- **Confidence:** High
- **Pass:** 4 (live: Pyro owns Cinder Shield under TechniquesOwnElementOnly)
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:546-554` (`liveState` never reads `RX_<kind>_Element`), `:35-36` (one kind "shield" for every RX_Shielded); `shield_t.lua:2, 182-185, 226-229, 263` ("Bedrock Slab", terra colours, "BEDROCK!"); `shield_a.lua:2` ("Tectonic Vice", "STONEWALL!"); `game/ServerScriptService/PyroHandler.server.lua:583` (`RX_Shielded_Element = "Pyro"`)
- **Trigger:** A Pyro equips Cinder Shield (one of Pyro's four Techniques) and casts it, with BarFX_shield left at the default "t" or set to "a".
- **Why it's a bug:** RX_Shielded has two writers (Cinder Shield and Bedrock). BarFX draws one Terra look for both, so a Pyro's "see-through shield ... glows hotter" becomes a stone slab with rampart, bolted clamps and "BEDROCK!". The status bar states the wrong Element. Every other bar status has exactly one Element writer.
- **Suggested fix:** Key the shield look on `RX_Shielded_Element` (a Pyro heat-shield look, or the neutral steel "f" look for non-Terra), or split it into two kinds.
- **Notes:** Becomes broader with TechniquesOwnElementOnly = false, because any Element could then carry a Cinder Shield.

#### GA-04: Detonate's bar countdown runs "6 … 1" over a 1.5 s fuse
- **Severity:** Low
- **Confidence:** High
- **Pass:** 3
- **Files/lines:** `primed_t.lua:176, 281-286` (`math.ceil(st.t * 6 - 1e-6)`); `primed_a.lua:313-330` ("TIK! TOK! then 3! 2! 1!"); `primed_f.lua:2` ("six second-segments"), `:191, 290-294, 301`; `game/ReplicatedStorage/Spellshot/BarFX.lua:487` (bench `fuse = 6.0`); `game/ReplicatedStorage/IceMagic/PyroFX.lua:149` (`Fuse = 1.5`); `game/ServerScriptService/PyroHandler.server.lua:880, 785` (`RX_Primed_Total = mark.Fuse`)
- **Trigger:** A player marked by Detonate (any primed look).
- **Why it's a bug:** `st.t` is the real fraction left (expires/total, total = 1.5 s), but each look multiplies it by the bench's 6 s. The stencil reads "6" with 1.5 s left and steps a number every 0.25 s with a pop each. primed_a calls "3! 2! 1!" over the last 0.75 s, and primed_f's six notches are not seconds. The number does not mean seconds.
- **Suggested fix:** Show `math.ceil(remaining seconds)` from `st.t * st.total` (pass `_Total` through `st`), or drop the numeral for short fuses.
- **Notes:** The urgent last third (t < 0.34) also toggles every 0.2 s. That flicker is already recorded under P5F-04.

#### GA-05: The poison looks draw a "x2 / DOUBLE DOSE" state for a single stack and print invented tick numbers
- **Severity:** Low
- **Confidence:** High
- **Pass:** 3
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:42-43` (`BENCH_MAX.poison = 2`, `DEFAULT_MAX.poison = 1`), `:574` (s = ceil(rawS/visMax*BENCH_MAX)), `:578` ("tick" = any HP drop while on); `game/ServerScriptService/StatusEffects.lua:70` (preset A Poisoned `MaxStacks = 1`, `TickDamage = 6`), `:403`; `poison_t.lua:209-216` (`n = st.s * 2` gives "GLUG! -4"), `:222-223, 240, 280`; `poison_a.lua:168-174, 180, 205`; `poison_f.lua:185-188, 195, 255-256`; `game/StarterGui/PopArtHUD.client.lua:798-800`
- **Trigger:** The live preset A (the default). Any Toxin poison on the local player.
- **Why it's a bug:** With MaxStacks 1, one stack maps to `ceil(1/1*2) = 2`, the bench maximum. From the first frame the vial shows its "x2" star and swollen fumes, the ooze slams its straps ("IT'S GOT YOU" stage) and the venom shows its purple vein: a double dose that cannot happen in this preset. Each "tick" (any HP loss, from any source, while poisoned) prints `-(st.s*2)` ("-4"), not the real 6 damage. PopArtHUD's own burst prints the real loss at the same moment, so the bar shows two different numbers per tick.
- **Suggested fix:** Drive the x2 visuals from `st.rawS >= 2`, not the remapped `s`. Print the real HP delta, or no number. Fire "tick" from a real poison-tick signal, not any HP drop.
- **Notes:** Preset C (MaxStacks 2) is fine. Burn's "tick" has the same any-HP-drop trigger but prints no number.

#### GA-06: The bar plays a status's payoff whenever its flag drops early (round reset, death, cleanse)
- **Severity:** Low
- **Confidence:** Medium
- **Pass:** 3
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:585-599` (`early = m.expires and (m.expires - serverNow) > 0.25`; `payoff = (kind == "charged" and early) or (kind == "marked" and early) or ... (kind == "primed" and math.abs(m.expires - serverNow) < 0.5)`); `game/ServerScriptService/StatusEffects.lua:374-380` (`Core.OnClear` → `ClearAll` on death, new round, leaving the arena); `game/ServerScriptService/UmbraHandler.server.lua:366-370`
- **Trigger:** A player carrying Charged or Marked when the round resets, when they leave the arena, or when the status is cleared for any reason other than its own payoff. Primed cleared within 0.5 s of its expiry without exploding.
- **Why it's a bug:** BarFX infers "payoff" from the flag falling before its timer runs out. ClearAll and other clears also do that, so the victim's bar shows "DISCHARGE!/KRAK!/ZZAK!" or "RIPPED! / GOTCHA! BONUS DAMAGE" for a discharge or bonus hit that never happened. Primed shows "KA-BOOM!" for a mark that fizzled close to its time (Detonate's `markHolds` / epoch checks).
- **Suggested fix:** Have the servers publish an explicit payoff marker (`RX_<Kind>_Paid = true`, or a one-shot attribute) when the payoff really fires, and treat every other flag drop as "end".
- **Notes:** On death the character is replaced and CharacterAdded unmounts the looks, but the ClearAll that precedes it can still play the payoff for the frames before the new character arrives.

#### GA-07: PopArtHUD fires a burn-tick burst on the health bar for every HP loss, whatever the source
- **Severity:** Low
- **Confidence:** Medium
- **Pass:** 3
- **Files/lines:** `game/StarterGui/PopArtHUD.client.lua:798-800` (`if hFrac < lastHealthFrac - 0.002 ... Pulse("BurnTick", { Amount = ... })`); `game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua:798-800` (`popBurst(barLayer, Art.Burn.TickBurst, ...)`); `game/ReplicatedStorage/Spellshot/PopArtAssets.lua:162-165` (TickBurst is in the Burn set)
- **Trigger:** Any damage to the local player: Icicle Shard, a fall, a Railspike, a poison tick.
- **Why it's a bug:** The one per-hit damage readout on your own bar uses the BURN tick art and the "BurnTick" pulse. It fires for every hit, so non-burn damage is presented as a burn tick (an extra "is it a burn?" cue). It also stacks with BarFX's own per-tick numbers (GA-05).
- **Suggested fix:** Use a neutral damage burst (`Overlay.Burst`) for generic HP loss, and keep BurnTick for real burn ticks.
- **Notes:** I could not see the asset art itself; the conclusion comes from the naming ("Burn.TickBurst").

#### GA-08: Dev-only HUD paths: the duel feed, the marked-crosshair star, slot charge art and the charges badge never run in live play
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `game/StarterGui/PopArtHUD.client.lua:403-446, 964-1006` (feed + KillFeed listener), `:939-941` (SetCrosshairMarked), `:952-962` (SetCharge), `:516-532, 832-844` (charges badge; the comment still names "Frost Slide's 3 dashes"); `game/ServerScriptService/SpellshotService.server.lua:80` (`local killFeed = remoteEvent("KillFeed")`, never fired), `:520-531` (only the dev "Kill" action fires it); `game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua:525-533` (the only callers of SetCrosshairMarked / SetCharge); `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua:120` (KillFeedDuration)
- **Trigger:** Any live match.
- **Why it's a bug:** Grep shows `killFeed` unused after creation. No duel result ever reaches the top-right feed except a dev panel test, so the Kill Feed Duration setting has no live effect. The "marked-hit star" over the crosshair (`crossStar`) is shown only by the dev panel, so no live Mark ever lights it. `HUD.SetCharge`'s `Pulse("Ready", { Slot = "SlotUltimate" })` also always targets the Ultimate slot whatever `role` is passed. No ability row defines `Charges` any more (grep finds none), so the ChargesMax badge and SpellshotService's charge records are dead too.
- **Suggested fix:** Fire `killFeed:FireAllClients(killer, victim, element)` from DuelMatch's death handling (or remove the feed and its setting). Wire `SetCrosshairMarked` to the local player's live Mark target, or delete it. Pass the role's own surface in SetCharge. Remove the Frost Slide comment and the dead charges path, or note that it is kept for a future ability.
- **Notes:** Cross-ref P6A-08 (MatchHUD_RETIRED replacing `_G.SpellshotHUD` makes these DevPanel calls error).

#### GA-09: Text Size is not honoured by the round counter's middle label
- **Severity:** Low
- **Confidence:** High
- **Pass:** 5
- **Files/lines:** `game/StarterGui/PopArtHUD.client.lua:921-931` (`roundMid.TextSize = 22` per frame while `RoundEndsAt` is set; `= 15` when it clears), `:659-676` (applyTextSize records 15 once and scales it)
- **Trigger:** Text Size at anything but 100%, in any round with a clock (DuelMatch publishes `RoundEndsAt`).
- **Why it's a bug:** applyTextSize scales each label's authored size by `Settings.Scale("TextSize")`. The per-frame round clock then overwrites roundMid with the literal 22 (and 15 when the clock is cleared), so the most-read number on the top plate ignores the player's Text Size.
- **Suggested fix:** Store roundMid's two base sizes and multiply each by `Settings.Scale("TextSize")` when switching, or keep one size and avoid writing TextSize per frame.

#### GA-10: Terra's Bedrock stacks are published "for the HUD's passive chip", but nothing on the client reads them
- **Severity:** Low
- **Confidence:** High
- **Pass:** 3 / 6
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:1355-1356` ("Stacks_Passive / StacksMax_Passive, which is what the HUD's passive chip already reads"), `:1376-1377, 1425-1427`; `game/StarterGui/PopArtHUD.client.lua:101-103` (COOLDOWN_ROLES = Primary/Mobility/Defense only), `:600-609, 769-772` (the passive pill shows only a gem and the name)
- **Trigger:** A Terra committing to Boulder Shot or Bulwark Charge, which builds Bedrock stacks (incoming damage reduction).
- **Why it's a bug:** Grep for `Stacks_Passive` / `StacksMax_Passive` / `_Passive` under StarterGui, StarterPlayer and ReplicatedStorage finds no reader. The HUD shows nothing of the Terra player's own damage-reduction state, contrary to the server comment. Only the body plates (TerraFX) show it, and those are out of view in first person.
- **Suggested fix:** Read `Stacks_Passive` / `StacksMax_Passive` in PopArtHUD's per-frame loop for the passive pill (pips like Immolate's), or correct the TerraHandler comment.

#### GA-11: The HUD's zone-warning border pulse (2.5 Hz) ignores Reduce Flashing, but nothing in gameplay raises ZoneWarning
- **Severity:** Low
- **Confidence:** High
- **Pass:** 5 / 6
- **Files/lines:** `game/StarterGui/PopArtHUD.client.lua:943-950` (`Thickness = 1 + 2 * math.abs(math.sin(os.clock() * 8))`, with no settings read); `game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua:740-745, 770-773`; `game/ServerScriptService/SpellshotService.server.lua:362` (`ZoneWarning` in the dev RX_KINDS); `game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua:335, 647, 651`
- **Trigger:** Today only the dev panel's SetStatus "ZoneWarning". Live, if any kit starts writing `RX_ZoneWarning`.
- **Why it's a bug:** The pulse is a 2.5 Hz red ring around the HP bar with no Reduce Flashing damping. Grep shows no gameplay writer of `RX_ZoneWarning`, so this path, and the shield zone-glow pulse reported in P3-23, are dormant in live play: a latent flashing issue plus a dead feature.
- **Suggested fix:** Either wire ZoneWarning to the hazards it was meant for (standing in an enemy zone) and damp the pulse under Reduce Flashing, or remove the dormant path.
- **Notes:** This adjusts P3-23: its zone-glow trigger is dev-only in the current code.

#### GA-12: Picking Zephyr, Terra or Voltaic prints "<M1>, <Primary>, <Passive> live;  not built yet."
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua:507-514`; `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:707-717` (PartialKits for Zephyr, Terra and Voltaic are all-true); dead code in LoadoutMenu at `:402-411` (`partialTag`), `:1331-1342` (`names` built and never shown), `:432-434` (the comment says the header's BUILT note still shows partial kits; that note is hidden at 1340-1341)
- **Trigger:** Clicking Zephyr, Terra or Voltaic in the Element grid.
- **Why it's a bug:** These three Elements still have `PartialKits` rows even though every part is `true`. The partial branch therefore runs, finds nothing "soon", and formats `"%s: %s live; %s not built yet."` with an empty list. The footer says something is unbuilt when nothing is. It also skips the full-kit message, so the player is never told the Ultimate or the default Techniques the pick equips, which other Elements get.
- **Suggested fix:** Only take the partial branch when `#soon > 0` (or drop the all-true PartialKits rows), and delete `partialTag` and the hidden header computation.

#### GA-13: Further LoadoutMenu header and comment drift (beyond the known cross-Element line)
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua:6-7` ("One of eight"), `:12-17` ("ALL EIGHT ELEMENTS ARE LISTED; NOT ALL ARE BUILT ... Cryo and Pyro in full, Zephyr in part ... SOON ... one Technique each in the three pools"), `:30-33` (Command list omits `Fire("wrap", id)`, handled at 1302), `:873-877` ("A slot with Default alone (every Element but Radiant for now"), `:1264` (open footer "Techniques: any two, from every Element"); `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:670-677` (BuiltElements comment: "Cryo and Pyro ... the other six ... have no cast path")
- **Trigger:** Reading the code, or opening the panel (1264 is player-facing).
- **Why it's a bug:** There are 9 Elements and all 9 are in BuiltElements, so no card ever shows SOON. There are 2 Technique slots over one pool, not three pools. Per-ability wraps also exist for Pyro, Terra and Umbra, and Element wraps for Cryo and Toxin. Line 1264 tells every player that Techniques come "from every Element", which P31 switched off.
- **Suggested fix:** Rewrite the header and the 1264 footer for nine built Elements and own-Element Techniques; document `Fire("wrap")`.
- **Notes:** This may overlap the already-recorded "LoadoutMenu header still describes cross-Element borrowing". The new parts are the Element count, the built/SOON state, `Fire("wrap")`, 873-877, and the player-facing 1264 footer.

#### GA-14: The WRAPS card's mark says "no wraps" for Cryo, Toxin, Terra and Umbra, which all have wraps
- **Severity:** Low
- **Confidence:** High
- **Pass:** 5
- **Files/lines:** `game/ReplicatedStorage/Spellshot/SkinCatalog.lua:386-387` (`WrapIcon = { Radiant = "Stripes", Pyro = "Drop" }`), `:364-375` (Offer: Terra ObsidianMagma, Umbra Bloodmoon), `:457-458` (ElementWraps: Cryo, Toxin); `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua:545-582` ("a neutral cream palette for every Element with no wraps of its own"; `showMark` reads the raw `Element` attribute)
- **Trigger:** Opening the Loadout as Cryo, Toxin, Terra or Umbra.
- **Why it's a bug:** The card mark is meant to say whether the equipped Element has wraps. For four of the six Elements that have wraps it shows the "none" palette, which discourages opening a page that does have content.
- **Suggested fix:** Derive the mark from `#ElementWraps[el] > 1` or any Offer list longer than 1 (with a generic "has wraps" mark), or add WrapIcon entries.

#### GA-15: PopArtAssets: Toxin's payoff-word set reuses Voltaic's art; large sections are unreferenced
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6 (latent copy-paste)
- **Files/lines:** `game/ReplicatedStorage/Spellshot/PopArtAssets.lua:253-261` (Voltaic CLUTCH 71202619188206, DOUBLE 135377339128325, ELIMINATED 80434221644764, FIRSTBLOOD 112976424231965, ULTIMATE 74130577314389) against `:298-306` (Toxin uses the same five ids; only SPOREWIPE and TRIPLE differ). No Aqua entry in `Overlay.Word`. Unreferenced anywhere in game/ (grep): `Overlay.Word`, `Overlay.Field`, `Overlay.SubTab`, `Tile`, `Banner`, `Feed`, `Bar`, `Chip`, `ValueBox`, `Pill`, `PillDark`, `Crosshair`, `Screen` (Haste, Knockback, Pull, MarkedBurst, Vignette), `Cleanse`, `FX`, `Mana.ConvertArc`, `StatusChip.Shocked`
- **Trigger:** The first time anyone wires the per-Element payoff words (Callouts.lua:80 already names `PopArtAssets.Overlay.Word.Voltaic.ARCSTORM` as the model).
- **Why it's a bug:** A Toxin CLUTCH, DOUBLE KILL, ELIMINATED, FIRST BLOOD or ULTIMATE would show Voltaic's lettering, and an Aqua kill would find no set. Today it is dead data, so nothing shows wrongly yet.
- **Suggested fix:** Re-render or upload the five Toxin words and add Aqua's. Prune or mark the unreferenced sections so the next agent does not assume they are live.

#### GA-16: marked_t and marked_f draw the intro and payoff words on top of each other when a Mark is spent in its first 1.2 s (marked_a has the fix)
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6 (sibling copy-paste)
- **Files/lines:** `marked_a.lua:139` (`intro.Visible = eOn < 1.2 and not payAt -- a mark consumed in its first second: CRUNCH! alone`); `marked_t.lua:154-155, 172-178` (`intro.Visible = e < 1.2`, no payAt check); `marked_f.lua:138-139, 156-159` (the same)
- **Trigger:** An Umbra spends its Mark on the local player (their next hit) within 1.2 s of marking. Looks "t" (the default) and "f".
- **Why it's a bug:** "HUNTED!" (centre 300, top 14 / 12) and "RIPPED!" or "GOTCHA! BONUS DAMAGE" (centre 300, top 10 / 6) draw on the same spot at the same z, so the payoff word is unreadable at exactly the moment it matters. The fix exists in one sibling only.
- **Suggested fix:** Apply marked_a's `and not payAt` to marked_t:175 and marked_f:158.

#### GA-17: primed_f's spark embers are drawn off-centre (copy-pasted 34 px centre on a 44 px spark)
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `primed_f.lua:102-113` (`(17 + d[1] * ph) / sp.size`), `:189` (`spark(fx.front, 44, 45)`); compare `primed_t.lua:187` and `primed_a.lua:194` (size 34, where 17 is the centre)
- **Trigger:** Any primed look "f" before the payoff.
- **Why it's a bug:** The ember offsets are anchored at 17 design px, half of the 34 px spark the helper was written for. In primed_f's 44 px spark they burst from about 5 px up-left of the spark centre.
- **Suggested fix:** Use `sp.size / 2` instead of 17.
- **Notes:** `GUN` is an unused local in primed_a:71 and primed_f:45.

#### GA-18: BarFX's front layer sits above the HP readout layer, so status art can cover the HP number the readout layer exists to protect
- **Severity:** Low
- **Confidence:** Low
- **Pass:** 3 / 5
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:18` ("fx.front above everything, the HP numeral included (ScreenGui DisplayOrder 21)"), `:141`; `game/StarterGui/PopArtHUD.client.lua:196-203` (PopArtHUDReadout DisplayOrder 20: "the number underneath it is exactly the one you want to read while the treatment is running"); `chill_t.lua:170-178, 251-263` (the sealed block, 4..544 x 76..200, during the whole deep slow); `poison_a.lua:134-140` (the sheet across x 8..524, y 78..174); `shield_f.lua:193` (frame band over the bar)
- **Trigger:** Chill at 3 stacks (5 s window) on chill_t, Poisoned on poison_a, Shielded on shield_f.
- **Why it's a bug:** PopArtHUD moved the HP numerals into their own ScreenGui above the status layer for exactly this reason. BarFX then put its front layer one order above it. Whether the HP number stays readable depends on each sprite's alpha over x≈120-170, y≈116-164.
- **Suggested fix:** Put BarFXFront below 20, or move the readouts above 21, or check every front-layer sprite against the numeral box.
- **Notes:** The sprites' transparency is not in the snapshot. I could not confirm the overlap is opaque, hence Confidence: Low.

#### GA-19: The Reactions board lists Dust Storm and Windswept (and Frozen's "Cryo on a Wet target") as live reactions; the code marks them DORMANT
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/ReactionsBoard.client.lua:89-96` (Frozen, Dust Storm, Windswept lines), `:16-19` (SOON tags removed on the owner's ask), `:45` ("the board no longer says so"); `game/ServerScriptService/ElementalReactions.server.lua:18-21` ("Dust Storm ... DORMANT: nothing applies Cracked", "Windswept ... DORMANT: nothing applies Wet yet"), `:114` (Cryo on Wet)
- **Trigger:** A player reading the Hub's Reactions screen.
- **Why it's a bug:** Two of the ten reactions, and half of a third, depend on statuses that no ability applies, so they can never trigger. The board presents them alongside the working ones with no qualifier, and they read as live mechanics.
- **Suggested fix:** Mark these three lines (for example "Wet / Cracked: coming later"), or leave them off until Aqua and Terra apply those statuses.
- **Notes:** Extends P6A-20, which covered the stale header line, Toxic Squall, Wildfire and Combustion wording.

#### GA-20: `ReactionsOpen` is published "for the input scripts" but nothing reads it
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `game/StarterPlayer/StarterPlayerScripts/ReactionsBoard.client.lua:37-39, 655-661`; `game/StarterPlayer/StarterPlayerScripts/MovementController.client.lua:617-619`, `SpellshotInput.client.lua:1746-1747`, `TouchControls.client.lua:190, 416`, `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua:336`, `game/StarterGui/SpellshotShop/ShopController.client.lua:1033` (each lists Settings/Loadout/QuickPlay/Shop only)
- **Trigger:** Opening the tablet in the Hub.
- **Why it's a bug:** The header says ReactionsOpen is "the input scripts' way of knowing a screen is up, as QuickPlayOpen / LoadoutOpen". Grep shows no reader. Jump, slide and touch input keep running under the tablet, and other screens do not close for it the way the tablet closes for them. Impact is small, because casting is already off in the Hub and walking 4 studs closes the tablet.
- **Suggested fix:** Add ReactionsOpen to those menusOpen lists (and to ShopController's close list), or drop the attribute and the comment.

#### GA-21: The shop's rarity and element sorts break ties on raw price amounts across currencies
- **Severity:** Low
- **Confidence:** High
- **Pass:** 2 (latent with today's Catalog)
- **Files/lines:** `game/StarterGui/SpellshotShop/CardKit.lua:349-357` (`return a.price[2] > b.price[2]` with no currency check), `:665-668` (only the "price" sort splits by currency)
- **Trigger:** Two items of the same rarity (or the same Element) priced in different currencies, for example a 1,500-Sparks Common next to a 950-Robux Common.
- **Why it's a bug:** In the "rarity" and "element" groupings, 1,500 Sparks sorts as "pricier" than 950 Robux. Today's demo Catalog happens to keep each rarity in one currency, so nothing is mis-sorted yet. The "price" sort already guards against exactly this.
- **Suggested fix:** Tie-break on the currency first (Robux before Sparks, as the price sort does), then on the amount.

#### GA-22: Looks re-push hard-coded "reset" restyles during their 0.8 s exit, overriding another live look's colours
- **Severity:** Low
- **Confidence:** High
- **Pass:** 6
- **Files/lines:** `game/ReplicatedStorage/Spellshot/BarFX.lua:763` (at "end" the host drops the look's restyles), `:357-374` (a later `fx.restyle` appends a new entry on top of the stack), `:44` (LINGER 0.8); `blessed_t.lua:82-88, 166-169` (`styleOff`: bar white, fill red, chip white, label ink); `blessed_f.lua:163-165`; `shield_t.lua:231-236, 296-300`; `shield_f.lua:215-220, 288-293`; `chill_t.lua:203-206`; `chill_a.lua:212-217`
- **Trigger:** Two statuses at once (for example Burning plus Blessed, or Chilled plus Shielded) where one ends first.
- **Why it's a bug:** After "end", `update` runs with `st.on == false` and these looks call `fx.restyle` again with literal Default colours. Those entries are appended after the still-running look's entries, so for 0.8 s the other status's bar, fill or label colours are replaced with plain white and red. The burn log, for example, briefly loses its charcoal channel.
- **Suggested fix:** Do not restyle after "end" (the host's unrestyle already restores the originals), or skip restyles while `endedAt` is set.

#### Could not complete
Nothing in the assigned files is unread. Not verifiable from the snapshot: the sprite and asset art (alpha, so GA-18's overlap), whether CanQuery is on for `TV_Reactions_Screen` (ReactionsBoard's pick ray needs it; the manifest records only Transparency 1 and CanCollide false), and the Enabled/Disabled state of any script.


---

## Gap-fill reads — VFX builder sections read in full, plus a whole-tree free-name scan

_Each finding carries a **Pass:** tag; it belongs to that pass._

### Gap-fill B: full reads of the Pyro flame modules, CastPose / Viewmodel data tables, VFXLibrary 3100-4810, FrostLotusKit geometry, and a whole-tree lexical free-name scan

#### Files read (complete list, with "fully" or "partially: lines X-Y" for each)
- game/ReplicatedStorage/IceMagic/PyroFlame_Fire.lua: fully (1-1125)
- game/ReplicatedStorage/IceMagic/PyroFlame_Ring.lua: fully (1-1206)
- game/ReplicatedStorage/IceMagic/PyroFlame_Tech.lua: fully (1-1483)
- game/ReplicatedStorage/IceMagic/CastPose.lua: partially, lines 1-1531 (the assigned 160-1526 plus the header and requires)
- game/ReplicatedStorage/IceMagic/Viewmodel.lua: partially, lines 1-120, 560-1582, 1725-1785, 1905-1945, 2380-2830 (the assigned 620-1578 and 2460-2700, plus Build, Play and the end of Update for context)
- game/ReplicatedStorage/IceMagic/VFXLibrary.lua: partially, lines 1-60 and 3100-4818 (the assigned 3100-4810), plus greps for Abilities rows, Tuning tables, requires and call sites
- game/ReplicatedStorage/IceMagic/FrostLotusKit.lua: partially, lines 1-760 (the assigned 100-600, plus On(), meshPart and buildKind, which the builders feed)
- game/ReplicatedStorage/IceMagic/PyroDraw.lua: partially, lines 400-430, 531-760, 1035-1100, 1340-1500, 1625-1860, 2060-2135 (Density, wraps, the pool, canvas, lights, flame / burst / ball / tail builders, the Play driver)
- game/ReplicatedStorage/IceMagic/PyroFX.lua: partially, lines 230-330, 455-470, 515-640, 658-730 (grep), 1615-1752, 2330-2523 (wrap plumbing, look switch, flame loader, watcher, ENTRY wrapper)
- game/ReplicatedStorage/Spellshot/SpellshotSettings.lua: partially, lines 40-135, 220-235
- game/ReplicatedStorage/Spellshot/SkinCatalog.lua: partially, lines 355-613
- game/ServerScriptService/PyroHandler.server.lua: partially, lines 455-475, 660-730, 775-800, 860-890
- game/ServerScriptService/AbilityHandler.server.lua: partially, lines 1385-1450, plus greps (cast functions, broadcasts)
- game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua: partially, lines 132-205, 270-305, 505-510 (grep)
- game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua: partially, lines 265-330, 375-392, 1180-1205
- game/ReplicatedStorage/IceMagic/FrostDragonKit.lua 150-186, FrostbladeKit.lua 235-272, SnowGlobeKit.lua 236-284, TerraWrap.lua 120-232 and 470-492, RadiantAnim.lua 340-380, ZephyrDraw.lua 3000-3260 (top-level local layout): partially, as cited
- Free-name scan: all 148 .lua files under game/ReplicatedStorage/IceMagic, game/ReplicatedStorage/Spellshot and game/StarterPlayer/StarterPlayerScripts, plus (bonus) the other 43 .lua files in game/. Tool: /tmp/claude-0/-home-user/3b17f07b-d336-5a1d-b5c2-7f46b19b6719/scratchpad/freename/scan.py (a recursive-descent Luau parser with type-annotation skipping and lexical scopes; run with `python3 -I`), plus shadow.py (second pass) and toplocals.py / active.py (local counts). Raw output: scratchpad/freename/out.txt, out_others.txt, shadow_out.txt.

#### Sub-areas checked with nothing found (explicit "checked, clean: ..." lines)
- checked, clean: LEXICAL FREE-NAME SCAN. All 191 files parsed with no parse error. The only identifier used as a global that is not a Roblox or Luau global is the known SnowGlobeFX.lua:112 `shards` (call; local declared at 198). There are no writes to undeclared globals and no `function name()` global definitions. The tool was checked on a synthetic file: it catches a call to a later `local function`, names in table values and `[key]` expressions, `::` casts, interpolated strings, generic-for iterators, and `repeat ... until` scope. A second pass (shadow.py) looked for a name used inside a scope that resolves to an OUTER local or a global, where the same scope then declares a `local` of that name later. That pattern silently binds the wrong variable. It found nothing beyond the same `shards`. See Appendix A for the whitelisted globals that were checked by hand.
- checked, clean: Luau's 200-locals limit, counted as the maximum number of locals live at once in each function (not just column-0 `local` lines). No file is over the limit. ZephyrDraw sits at exactly 200 in its 2620-3259 block (180 top-level plus 20 in the block, peak at line 3246). That is already P5E-14, and my count reproduces it. CascadeFX peaks at 187 (P5D-14), RadiantDevilForge at 181 inside a top-level `do` block (147 top-level), TerraFX at 180, RadiantFX_Hand at 192 (P5C-19), CryoFX at 198 (known), VFXLibrary at 182 (known). Table in Appendix B.
- checked, clean: PyroFlame_Fire hit detection. The flight loop raycasts and reports `onHit` before any cosmetic work (488-503). Burst is pcall'd (498) and every draw goes through `guarded` (238-247), so a drawing error never loses a hit. The Fireball's impact canvas gets the thrower's wrap explicitly (463, 498), because it is made frames later, outside any wrapped call.
- checked, clean: PyroFlame_Fire / _Ring / _Tech under the wrap plumbing. Every canvas is created synchronously inside the ENTRY-wrapped PyroFX call (PyroFX.lua:2478-2498), or inside a PyroDraw frame, which re-sets pendingWrap (PyroDraw.lua:2082-2085). So all three modules pick up the caster's AzureFlame wrap without passing it. The exceptions are GB-02 and GB-03.
- checked, clean: PyroFlame_Ring timing against the server. It uses the same DrawTime + SettleTime + SnapBeat (7/30, which matches CastPose.lua:490 and Viewmodel.lua:1169), and LockAt and LockLead are on the same os.clock base (1105, 326-329). Since P5B-01, the flame look draws at `reach = radius × HotReach` (1109, 1114), which matches PyroHandler.server.lua:701-707. D.Play does not run the frame synchronously (PyroDraw.lua:2111-2124), so the planCast after Play at 1200 is safe. The camera Pocket (88-92, 670-674) hides only flames drawn after the snap. The damage itself is one hit at the snap (PyroHandler 697-711) and the line is never hidden, so no telegraph is lost.
- checked, clean: Reduce Flashing in the flame Ring. All ring lights and floor glows go through `S.dim` / `ft = nil` (1016-1047). The remaining flicker in Fire and Tech is P5B-05 (known).
- checked, clean: Graphics Quality and Reduce Enemy VFX in the three flame modules. All of them size through PyroDraw.Density(own) (PyroDraw.lua:407-416), and the Ring plans its whole part budget against it (578-664). Under ThinEnemyVFX, the burn canvas (PyroFlame_Tech.lua:1444, `own = false`) also thins the burn on your own body in third person. That is the known "enemy = anyone not me" behaviour, P5F-06.
- checked, clean: PyroFlame_Tech rope, sweep, crack and burn maths. whipSwept, jointsAt, drawCurtain, tipAt and the 128-entry history ring (230-258) index in range. The Snap / Recoil / Blend windows match WHIP and Tuning. MaxTargets bounds LashHit. The Detonate fuse clock (545, 573-581) matches PyroHandler's Expires = now + Fuse (881-886).
- checked, clean: CastPose clip data (160-1526). Every beat that claims to be a Tuning value matches its source: Fireball 0.42, Immolate 0.22, Detonate 0.27 and Scorching Lash 0.22 (PyroFX.lua:61-161); Cinder Shield 5/30 (FormAt); Ring point 7/30 (SnapBeat); Aftershock 0.68 / 0.98 / 1.63 (TerraFX Hit / FistsUp / Recover); Cascade 0.50 (VoltaicFX Windup); Gust Pad 0.14 (Contact); Skyrider 0.44 / 0.24 (SummonTime, WindUp + 0.04); Updraft ClipOffset 0.30. leftHanded, wbClip, wbLeft, wbSolo, kneel and pz build what their comments say. The Frost Lotus M1 clip keeps the Default trigger (0.12) and the Default length (0.453), so the skin changes no timing.
- checked, clean: Viewmodel clip data (620-1578) and Update (2441-2700). Every `POSE.X` used in the file is defined. Every clip name played anywhere in the codebase exists: I scripted a check of all `CastPose.Play` / `PlayClocked`, `Viewmodel.Play` and `PlayShot` string arguments against the Clips and ArmClips tables. The five concatenated names, WindBlade<Stroke><Side>, IcicleShard<Side>, Fireball<Side> and WindSlash<Stroke>, all resolve. Each ArmClip has a Trigger (Update compares it at 2546). The HideArms hunk is installed (2452-2459). Unhiding re-enables only the three lights the rig owns, and none of them is disabled anywhere else. Reduce Flashing zeroes the clip and impact punches (2749). The palm flash is the known P5F-03.
- checked, clean: FrostLotusKit geometry (100-600). In petal, bloom, heart and giantPetal, every row and column index is in range (us/vs have nu+1 / nv+1 entries; Proxy rows {1,2,4,6,7} ≤ N=8; `rows[N/2]`). The bloom frames are orthonormal (sd = U × rad ⟂ ax). The cup and the wanted normals are consistent; the comment at 90 says the cup faces "+Z", but the code's n0 = Up × Right is −Z. That is comment-only, since tri() orients by `want`. Mutating the shared `GIANT[name]` option tables (472, `o.G`) only renumbers smoothing groups. FL.On's `Element or "Cryo"` default (39) is the same pattern every Cryo kit uses, and is cosmetic.
- checked, clean: the Frost Lotus M1's timing does not differ from Default (Viewmodel ArmClips IcicleShardLotus 0.107 / 0.453 = IcicleShard).
- checked, clean: Pass 4 in these files. With the flag flipped, a borrowed Pyro Technique on a non-Pyro caster resolves to Default through SkinCatalog.Chosen's `Element ~= origin` gate (SkinCatalog.lua:493-497). The Pyro clip and flame code reads nothing from the caster's Element. The one latent cross-Element draw I found is noted in GB-04, item 4.

---

#### GB-01: Three Cryo skin kits and TerraWrap leak a resizable EditableMesh whenever a build step fails
- **Pass:** 5
- **Severity:** Low
- **Confidence:** Medium (the code path is certain; the size of the effect rests on the repo's own measurement of about 8 resizable meshes per client, TerraWrap.lua:128-133)
- **Files/lines:** `FrostLotusKit.lua:622` (`em = retry(CreateEditableMesh)`), `623-659` (unguarded AddVertex / AddTriangle / SetFace* calls), `660` (`fixed = retry(...)`, which raises "EditableMesh budget: gave up" after about 10 s, 597-604), `661` (`em:Destroy()`, reached only on success); the same shape in `FrostbladeKit.lua:235-269`, `SnowGlobeKit.lua:236-281` and `TerraWrap.lua:172-176` (makePart) with `479-485` and `194` (buildStone's resizable asset copy, freed only inside makePart). For comparison, the guarded version is `FrostDragonKit.lua:154-184`: it pcalls the writes, destroys `em` on failure, and calls `em:Destroy() -- (the resizable one, always: the project works under its cap)` whether or not the fixed copy succeeded.
- **Trigger:** A client builds Frost Lotus, Frostblade or Snow Globe kinds, or an Obsidian Magma wrap, while EditableMesh memory is tight: other skins or wraps are building, ToxinFX's resizable bubbles exist (P5B-10), or the device is low-memory. That is exactly when `CreateEditableMeshAsync(..., {FixedSize = true})` keeps returning nil until `retry` gives up. Any engine error inside the write loop (vertex or face limits, a bad colour) takes the same path.
- **Why it's a bug:** On those paths the error propagates out of `meshPart` / `makePart` and skips the `em:Destroy()` that follows. The pcall in buildKind (FrostLotusKit.lua:717) swallows it, and the resizable mesh stays allocated for the rest of the session. Each leak permanently lowers the per-client budget that every other EditableMesh builder shares: CryoWrap, TerraWrap, RadiantDevilForge, CryoAurora and the other kits. So one failure makes the next more likely, and the result can cascade. Combined with P5A-08 (`Built = true` regardless), the kinds that fail draw nothing where Default should have drawn.
- **Suggested fix:** Use FrostDragonKit's pattern everywhere. Wrap the writes and the fixed copy in pcall, always destroy the resizable mesh, then re-raise. In TerraWrap, also destroy buildStone's `em` if makePart is never reached.
- **Notes:** PyroDraw's wrap copies (`PyroDraw.lua:621-624`, 45 flame meshes per wrap, kept in `wrapKeep` for the session) and RadiantAnim's skinned staff (`RadiantAnim.lua:354-370`) are also EditableMeshes kept forever. Both call `CreateEditableMeshAsync(Content.fromUri(...))` with no options and only `SetColor` on them. The repo states twice that such asset copies are fixed-size in-experience (PyroDraw.lua:572-574, TerraWrap.lua:192). If that is true they are cheap. If it is not, 45 kept resizable copies would exhaust the budget on any client that meets an AzureFlame Pyro. To confirm, check `em.FixedSize`, or try `em:AddVertex` on one of them in Play. Cross-ref P5B-10 and P5A-08.

#### GB-02: Pyro burn flames wear the wrap of whoever last LASHED the body, whatever actually lit the current burn
- **Pass:** 5
- **Severity:** Low (cosmetic misattribution; no gameplay)
- **Confidence:** High
- **Files/lines:** `PyroFX.lua:269` (`burnWraps`, weak-keyed by victim, never cleared), `2489-2495` (written only from the `LashHit` entry: `burnWraps[v] = wrapOf(ch, "ScorchingLash")`), `2453-2463` (the watcher starts every burn under `burnWraps[m]`), `PyroFlame_Tech.lua:1373-1447` (startBurn draws under the inherited pendingWrap); burn sources: `PyroHandler.server.lua:390` (Immolate-buffed hits), `710` (Ring of Fire), and ElementalReactions `Hooks.AddBurn` (`ElementalReactions.server.lua:405`, e.g. Zephyr Wildfire)
- **Trigger:** (a) An AzureFlame Pyro lashes player X; later in the match, or in the next round (the entry survives because the character model is the same until respawn and the table is never pruned), a Default Pyro's Ring of Fire or Immolate-buffed Fireball, or a Wildfire reaction, burns X. X's burn flames draw azure. (b) An AzureFlame Pyro burns X with Ring of Fire or Immolate before ever lashing X: the burn draws Default orange. (c) In 2v2 or Squad Clash with two Pyros, the burn shows the wrap of whichever Pyro lashed last, not the one whose burn is ticking.
- **Why it's a bug:** The comment says the burn "wears the wrap of whoever lashed this body last (LashHit below)". But RX_Burning_Stacks is fed by three other sources that never touch `burnWraps`, and nothing clears a stale entry when the Lash burn ends. So the burn's colour can name the wrong caster, or none.
- **Suggested fix:** Have the server stamp the burn's source caster on the victim. `RX_Burning_By` would fit the existing `RX_Primed_By` pattern. Resolve the wrap from that player with `SkinCatalog.Chosen(by, <source ability>)` when the burn starts, and clear `burnWraps[m]` when the burn goes out.
- **Notes:** Both looks share this, since the toon startBurn runs under the same WithWrap call.

#### GB-03: A Detonate mark the watcher sees before its broadcast loses the caster's wrap and the landing pop
- **Pass:** 5
- **Severity:** Low
- **Confidence:** Low (depends on whether attribute replication and the RemoteEvent can be processed with a Heartbeat in between)
- **Files/lines:** `PyroHandler.server.lua:779-787` (showMark writes the RX_Primed suffixes and the flag), then `883-886` (the `DetonateMark` broadcast, after the attributes); `PyroFX.lua:2455-2466` (the Heartbeat watcher calls `watchMark(m)` outside any WithWrap), `1734-1742` (watchMark: `startMark(model, expires, total, false)`, so no landing pop and `own` = nil); `1615-1626` and `PyroFlame_Tech.lua:537-552` (startMark: an existing controller with the same Expires within 0.05 makes the later broadcast's call `return` at once); `PyroFlame_Tech.lua:672` (`own = own == true`, so false on the watcher path)
- **Trigger:** The attribute changes for the mark reach a client one frame before the `DetonateMark` remote is handled, for example when they land in different packets. The Heartbeat watcher runs first and starts the crown itself.
- **Why it's a bug:** The broadcast path (ENTRY-wrapped DetonateMark, PyroFX.lua:2478-2498) is the only one that carries the caster's AzureFlame wrap and `landing = true`. When the watcher wins the race, the crown draws Default and the landing burst never plays. On the caster's own screen the crown counts as someone else's effect (`own` false), so Reduce Enemy VFX thins it. The dedupe then throws the correct broadcast away.
- **Suggested fix:** Let a later call with the same Expires upgrade the running controller instead of returning: set its wrap, play the landing pop if it is less than about 0.2 s old, and set `own`. Or have the watcher wait a short grace period (about 0.15 s) after first seeing RX_Primed before it starts a mark, so that the broadcast normally wins.
- **Notes:** The server's own comment, "The suffixes first and the flag LAST, so a client that sees RX_Primed rise already has its countdown" (PyroHandler 778), shows the attribute path was designed to fire early. Confirm in Play with an artificial delay on the remote.

#### GB-04: VFXLibrary's retired Chill Aura, Cryo Beam and Frost Slide renderers are unreachable but hold 50 of its 182 top-level locals (refines P5F-29's "16 / ~25")
- **Pass:** 5 (VFXLibrary near the 200-local limit) / 6 (dead code, doc drift)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `VFXLibrary.lua:3317-3454` (Chill Aura: CA, CA_GROUPS, caClock, caData, caAcquireSet, caShow, caReleaseSet, caPiece, caFallback = 9 top-level locals); `3788-4502` (Cryo Beam: CB, CB_BLOCKS, CB_RINGS, CB_TRAILS, CB_BLOCK_NAMES, CB_RING_NAMES, CB_TRAIL_NAMES, CB_ARCS, CB_P, cbR, cbFrame, cbClock, cbSeg, cbSmooth, cbEaseIn, cbWin, cbData, cbAcquireSet, cbShow, cbReleaseSet, cbPlacePiece, cbPlaceWhole, cbOrbitAngle, cbVec, cbOrbitFrame, cbHeroFrame, cbRadialFrame, cbBlend, cbPoseCrystal, cbGroup, cbHideGroup, cbPoseWindup, cbPoseBlocks, cbPoseBeam, cbFinish, cbClampCone, cbStart = 37); `3008, 3082, 3089, 3101` (surfaceFrame, RIM, rimDepth, kitPiece: used only by FrostSlidePatch 3115-3272 and the two dead renderers = 4). Unreachable because: `VFXLibrary.lua:233-251` (the Cryo Abilities rows are IcicleShard, FlashFreeze, Blizzard, DeepFreeze, MirrorCage; there is no FrostSlide, ChillAura or CryoBeam row); `AbilityHandler.server.lua:1393-1399` (the dispatch has none of `castFrostSlide` 411, `castChillAura` 510 or `castCryoBeam` 589, which are now dead server code too); `AbilityFX.client.lua:132-175` (handlers for broadcasts that are never sent); `VFXLibrary.WarmCryoBeam` (4794) has no caller.
- **Trigger:** Any future top-level local added to VFXLibrary. Or someone "cleans up" the retired code without knowing about the dependencies listed below.
- **Why it's a bug:** With 18 slots of headroom, a quarter of VFXLibrary's local budget is spent on code no path can reach. P5F-29 counted 16 locals for Cryo Beam and suggested reclaiming "~25"; the real figures are 37 for Cryo Beam, 9 for Chill Aura and 4 for Frost Slide, 50 in total. The header (1-10) still lists Frost Slide, Chill Aura and Cryo Beam as the Cryo kit. That is doc drift: Blizzard, Deep Freeze and Mirror Cage replaced them.
- **Suggested fix:** Move the three renderers to ServerStorage, as was done for Glacial Spikes. Before deleting, keep these live dependencies:
  1. `VFXLibrary.Tuning.CryoBeam` (181) is read at REQUIRE time by `CastPose.lua:112/135` and `Viewmodel.lua:61-62` (CRYO_FIRE). Removing it raises at load in both modules, which would kill every body animation and the viewmodel. Inline the constant or keep the table.
  2. `VFXLibrary.Tuning.FrostSlide` (144) is DashMotor's default dash (DashMotor.lua:129).
  3. `VFXLibrary.LocalBeamOrigin / LocalMuzzle / LocalCharacter / LocalAimCFrame` (3778-3786) are live fields that FirstPersonController sets and other code reads (LocalCharacter at 3123, 3497, 4512 and elsewhere).
  4. Latent, Pass 4: `SpellshotInput.client.lua:295-310` (tryChargeCast) still draws `VFXLibrary.FrostSlideDashFX`, Cryo frost lines, for ANY ability with `Charges`. No row has Charges today. The first ability to get them, of any Element, would draw Cryo ice on its dash.
- **Notes:** The CastPose/Viewmodel `ChillAura` and `FlashFreeze` clips are still live: Blizzard and Deep Freeze borrow them (SpellshotInput 383-384, AbilityFX 182 and 201), and so does Aqua (AquaClient 250, 972). Keep them.

#### GB-05: PyroFlame_Fire's EmberRefund documentation says the broadcast carries only the caster; it now carries `From`
- **Pass:** 6 (doc drift)
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `PyroFlame_Fire.lua:46-48` ("the broadcast carries only the caster, so without `from` ... it looks for the nearest humanoid at 0 health"), `1042-1046` ("the broadcast names the caster only"), `PyroFX.lua:2331-2332` (same claim); against `PyroHandler.server.lua:466-474` (`broadcast("EmberRefund", { Character = character, From = from })`, added 2026-10-05) and `AbilityFX.client.lua:508` (it passes `d.From`)
- **Trigger:** Reading the module to maintain the streak, or keeping the `fallen` book alive for it.
- **Why it's a bug:** The fallback the comments describe as the normal path now runs only when the victim had no root part on the server. So the "book of the fallen" (PyroFX.lua:2333, kept up every Heartbeat at 2467-2472) is rarely needed. Its heuristic, the last body to fall within 0.5 s that is not the caster, can also pick a teammate or a Training Ground dummy in 2v2 and Squad Clash, which a reader would not expect on the main path.
- **Suggested fix:** Update the three comments. Optionally, drop the `fallen` bookkeeping when `From` is always present.
- **Notes:** Cosmetic only.

#### Could not complete
- Nothing in the assigned ranges was left unread. For context files I read only the parts listed above (PyroDraw, PyroFX, AbilityFX, SpellshotInput, the other kits). GB-03's race and GB-01's PyroDraw note need Studio/Play to confirm.

---

#### Appendix A: free-name scan, hits and dismissed false positives
Confirmed true hit (already recorded): `SnowGlobeFX.lua:112` `shards(p, 4, 6, 70, 0.4)` calls a nil global; the `local function shards` is at 198.

Whitelisted names that a typo could hide, reviewed by hand (scan output tagged SUSGLOBAL). All legitimate:
- `buffer`: ToxinFX.lua 332-346 and 2108-2148, VFXLibrary.lua (12 uses); this is the Luau buffer library (buffer.create / writeu8).
- `Content`: CryoAurora, CryoWrap, FrostDragonKit, FrostLotusKit, FrostbladeKit, PyroDraw, RadiantAnim, RadiantDevilForge, SnowGlobeKit, TerraWrap, ToxinFX, HubBannerWave, HubLanternFlicker; this is Roblox's Content data type (Content.fromUri / fromObject).
- `Font`: LoadoutMenu, MapVote, QuickPlay, ReactionsBoard; this is Font.new / Font.fromEnum.
- `_G`: SpellshotReactions (written at StatusReactions.client.lua:962; read by CryoFX 2916-2917, ZephyrSkyrider 1023, AbilityFX 908-919, DevPanel 165), SpellshotHUD (written at PopArtHUD.client.lua:995 and by the retired MatchHUD_RETIRED:618, which is P6A-08; read by DevPanel 169), SpellshotChargeRing (defined as `function _G.SpellshotChargeRing` at PopArtHUD.client.lua:371; read by SpellshotInput 1568). Every read has a writer and every read is nil-guarded.
- None of `settings`, `version`, `stats`, `delay`, `spawn`, `wait`, `time`, `elapsedTime`, `tick`, `unpack`, `plugin`, `shared`, `Workspace`, `loadstring`, `getfenv` or `setfenv` is used as a free name anywhere in the 191 files.

Tool limits: it does not check FIELD names, such as `Module.Typo`. Field-name typos in clip tables were covered separately by the clip-name check above.

#### Appendix B: peak live locals per function (≥ 150), from the scan
| File | peak live | top-level | where the peak is |
|---|---|---|---|
| ZephyrDraw.lua | 200 | 180 | the 2620-3259 `do` block, line 3246 (P5E-14) |
| CryoFX.lua | 198 | 198 | top level (known) |
| RadiantFX_Hand.lua | 192 | 192 | top level (P5C-19) |
| CascadeFX.lua | 187 | 166 | a top-level `do` block, line 2230 (P5D-14) |
| VFXLibrary.lua | 182 | 182 | top level (known; 50 of them dead, GB-04) |
| RadiantDevilForge.lua | 181 | 147 | a top-level `do` block, line 2536 |
| TerraFX.lua | 180 | 180 | top level |
| RadiantFX_Staff.lua | 169 | 169 | top level |
(Luau fails when a 201st local is pushed. Constant-folded locals that are never written may not take a register at -O1, so these are upper bounds.)


---

## Gap-fill reads — open traces closed (confirmed / refuted), PyroDraw 1650-2044, every M1 mana path

_Each finding carries a **Pass:** tag; it belongs to that pass._

### Gap-fill C: corpses as cover, wall-as-body on the server, queued Shadow Step, prison/cage visuals after BreakRoot, Updraft under the Tomb, PyroDraw 1650-2044, and M1 damage without the paid CastRequest

#### Files read (complete list, with "fully" or "partially: lines X-Y" for each)
- /tmp/claude-0/-home-user/3b17f07b-d336-5a1d-b5c2-7f46b19b6719/scratchpad/BRIEF.md: fully
- earlier findings P6B-10, P6A-05, P6A-16, P3-05, P4-04, P1-12, P5D-13 (scratchpad pass*_findings.md): those blocks only
- game/ServerScriptService/HitboxScale.server.lua: fully (1-108)
- game/ServerScriptService/CombatCore.lua: fully (1-567)
- game/ServerScriptService/HubServer.server.lua: partially, lines 470-560
- game/ServerScriptService/DuelMatch.lua: partially, lines 1-80, 344-375, 410-462
- game/ServerScriptService/SpellshotService.server.lua: partially, lines 790-1100 (the whole CastRequest handler, the M1 branch included, plus releaseHold, spendMana and giveBack)
- game/ServerScriptService/AbilityHandler.server.lua: partially, lines 470-500, 723-1060, 1110-1400
- game/ServerScriptService/PyroHandler.server.lua: partially, lines 75-97, 180-460, 650-665
- game/ServerScriptService/TerraHandler.server.lua: partially, lines 100-470, 520-560, 610-1030, 1052-1082
- game/ServerScriptService/ZephyrHandler.server.lua: partially, lines 100-300, 300-530, 570-590
- game/ServerScriptService/VoltaicHandler.server.lua: partially, lines 1-40, 140-235, 287-310, 330-520, 640-780
- game/ServerScriptService/UmbraHandler.server.lua: partially, lines 160-175, 370-645, 640-870, 885-995
- game/ServerScriptService/RadiantHandler.server.lua: partially, lines 250-460
- game/ServerScriptService/AquaHandler.server.lua: partially, lines 329-490
- game/ServerScriptService/ToxinHandler.server.lua: partially, lines 181-183, 380-560, 655-700 (no client remote listener in the file: grep `remote.OnServerEvent` finds none)
- game/ServerScriptService/ZephyrSkyriderServer.server.lua: partially, lines 165-395
- game/ServerScriptService/ZephyrUpdraftServer.server.lua: fully (1-125)
- game/ServerScriptService/ZephyrGustPadServer.server.lua: partially, lines 85-118
- game/ServerScriptService/ElementalReactions.server.lua: partially, lines 100-150 and grep of the entry points (336-349)
- game/ServerScriptService/StatusEffects.lua: grep only (Status.Apply refuses dead, line 39/227)
- game/ServerScriptService/CombatFeedback.server.lua: partially, lines 1-30
- game/ReplicatedStorage/Spellshot/SpellshotConfig.lua: partially, lines 180-203, 244-268, 39-40
- game/ReplicatedStorage/Spellshot/DashMotor.lua: partially, lines 150-260, 325-370
- game/ReplicatedStorage/IceMagic/VFXLibrary.lua: partially, lines 2895-2965, 5180-5424, plus the M1 rows (233-460)
- game/ReplicatedStorage/IceMagic/PyroFX.lua: partially, lines 314-336, 560-650
- game/ReplicatedStorage/IceMagic/PyroFlame_Fire.lua: grep plus lines 190-200, 330-415, 670-690, 915-945
- game/ReplicatedStorage/IceMagic/PyroFlame_Tech.lua: grep plus lines 380-392, 436-445, 715-750, 905-925, 1425-1440
- game/ReplicatedStorage/IceMagic/PyroFlame_Ring.lua: partially, lines 265-280, 1000-1035
- game/ReplicatedStorage/IceMagic/PyroDraw.lua: lines 1-140, 248-470, 557-1340 and **1620-2132 fully** (so 1650-2044 fully)
- game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua: partially, lines 400-600, 1280-1320
- game/ReplicatedStorage/IceMagic/TerraFX.lua: partially, lines 1871-1935, 218-225
- game/ReplicatedStorage/IceMagic/VoltaicClient.lua: partially, lines 160-260, 300-420, 505-560
- game/ReplicatedStorage/IceMagic/UmbraClient.lua: partially, lines 140-375
- game/ReplicatedStorage/IceMagic/RadiantClient.lua: partially, lines 110-270
- game/ReplicatedStorage/IceMagic/AquaClient.lua: partially, lines 50-110
- game/ReplicatedStorage/IceMagic/AquaFX.lua: partially, lines 82-130, 400-660, 2009-2080
- game/ReplicatedStorage/IceMagic/CryoFX.lua: partially, lines 1090-1110, 1285-1330, 1443-1470, 1593-1640, 2878-2960, 3908-3935, 4093-4100, 4320-4420 (+ grep over 3908-4430)
- game/ReplicatedStorage/IceMagic/CryoTuning.lua: partially, lines 76-79, 139-142
- game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua: partially, lines 100-160, 298-450
- game/ReplicatedStorage/IceMagic/AquaTuning.lua: grep (Riptide ManaCost 4, FireInterval 0.667)
- game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua: partially, lines 140-260, 505-535, 715-730, 990-1010, 1320-1660
- game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua: partially, lines 30-35, 85-106, 185-210, 267-313, 944-961
- game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua: partially, lines 1-60
- game/StarterPlayer/StarterPlayerScripts/MovementController.client.lua: partially, lines 478-495
- game/ReplicatedStorage/IceMagic/ZephyrFX_CrossSlash.lua: partially, lines 560-590
- docs/SPELLSHOT_Design_Manual.md: grep (Shadow Step, line 827; CC wording)

#### Sub-areas checked with nothing found (explicit "checked, clean: ..." lines)
- checked, clean: damage to a corpse. `CombatCore.DealDamage` returns false at once for `humanoid.Health <= 0` (CombatCore.lua:299). That happens before the modifiers, the Ultimate charge (`addUltCharge`, :314-316), `OnHitLanded` and `OnKill`. So a corpse gives no damage, no Ultimate charge, no Updraft or Mark payoff, no Ember Refund or Chain Reaction, and no Elemental Reaction (ElementalReactions only listens on `Core.OnHitLanded`, :336, and refuses `Health <= 0` again at :349).
- checked, clean: statuses on a corpse. `Status.Apply` refuses the dead (StatusEffects.lua:39). Cryo Chill is applied only when `dealDamage` is true (AbilityHandler.server.lua:947-949). Chain Bolt's Charged only after a true DealDamage (VoltaicHandler.server.lua:483-487). Toxin's `hurtable` needs `Health > 0` (ToxinHandler.server.lua:182). The Immolate burn goes only to `hurt` (PyroHandler.server.lua:385-390).
- checked, clean: corpses on the server's line of sight. `Core.Blocked` (CombatCore.lua:519-545), Pyro's `flightBlocked`/`lineBlocked` (PyroHandler:75-97, 322-339), Terra's `flightBlocked` (TerraHandler:262-288) and Voltaic's `castThroughBodies` (VoltaicHandler:173-182) all look through any model with a Humanoid, dead or alive. Server-side, a corpse is never cover.
- checked, clean: kits that already look through corpses on the client. Wind Blade's sweep (ZephyrFX_WindBlade.lua:547-552: "a body already down ... is air to the blade"), Riptide's crest box (AquaFX.lua:648 `hum.Health > 0`; its floor probes exclude every player's character, :82-110), Toxic Bubbles (server-simulated, ToxinHandler.server.lua:443-450 passes through `not hurtable`) and Railspike (VoltaicClient.lua:531-536 claims only `Health > 0`, pierces the rest).
- checked, clean: dead teammates. `Config.AddUnhurtable` (SpellshotConfig.lua:196-203) excludes every player the caster may not hurt, whether that body is alive or dead. A dead TEAMMATE never blocks your shots. Only dead ENEMIES do.
- checked, clean: HitboxScale twin bookkeeping on death. Nothing in the script reacts to death. The `AncestryChanged` guard (:63-65) removes a twin only when its part leaves the model.
- checked, clean (item 2): Umbra's Decoy Double counted as a body by the dashes (DashMotor `characterOf`). The decoy is a copy of a character with `DecoyOwner`, a Humanoid and Hitbox twins (HitboxScale :73-75). Passing through it is the same as passing through a character, which ThroughCharacters is meant to do. Refuted as a bug.
- checked, clean (item 2): Railspike, Riptide and Toxic Bubbles treat the Bulwark Wall as cover (VoltaicClient.lua:520-529; AquaFX.lua:96-104; ToxinHandler.server.lua:448).
- checked, clean (item 2): Overcharge does no damage along its path (VoltaicHandler.server.lua:287-306: it only primes). So no server-side damage goes through the wall for that dash. The pass-through itself is movement only (P6A-05).
- checked, clean (item 3): the queued Shadow Step re-checks the epoch (UmbraHandler.server.lua:791). A Zone change and DuelMatch's round reset both run `ClearPlayer`, which moves the epoch on (CombatCore.lua:375-378, 380-388; DuelMatch.lua:418-420 sets CastLocked and clears in the same step). So Zone, CastLocked and round reset are covered for the queued press.
- checked, clean (item 6, PyroDraw 1650-2044): wraps are honoured by every builder in the range, because they all draw through `emit` (wrapRec, :907), `fire_light` (Wrap.Light, :1077) and `emitterSlot` (wrap ember colours, :1153-1159). Graphics Quality and Reduce Enemy VFX reach the builders through `cv.Density` (wisps :1736, hand_flame :1781, burst :1815/1843/1873, pillar :1916/1926, wildfire :1966, fire_ball streamers :1648) and through MaxParts/MaxLights (:741-742). Nothing in the range creates instances outside the pools. The driver's swap-remove (:2070-2109) processes every live effect exactly once a frame and ends every one through `Canvas:Destroy`, so nothing leaks. Colourblind-Safe is not applicable: fire is never the only cue for a hazard here.
- checked, clean (item 7): Shadow Dart, Light Lance and Toxic Bubbles cannot deal damage without a paid `CastRequest("M1")` (details in GC-14).

#### GC-01: In team mode an enemy corpse (and its query-able hitbox twins) eats six kits' shots for the rest of the round; Wind Blade, Riptide, Toxic Bubbles and Railspike pass through it
> **Consolidator:** duplicate of **P6B-10** (Team-mode corpses (and hitbox twins) block six kits' shots). Kept here for its slice-specific detail; counted once, under P6B-10.
- **Pass:** 6 (closes P6B-10)
- **Severity:** Medium
- **Confidence:** High for the code paths. Medium for the twins' fate after death, which is engine behaviour (see Notes).
- **Files/lines:** `game/ServerScriptService/HubServer.server.lua:486-487` (`Players.RespawnTime = 1e6`); `game/ServerScriptService/DuelMatch.lua:29-33, 344-360` (the body stays down, nothing removes it); `game/ServerScriptService/HitboxScale.server.lua:43-55` (twin `CanQuery = true`, held on by a WeldConstraint); `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua:196-203`; `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:173-185, 1355, 1508, 1634`; `game/ReplicatedStorage/IceMagic/VFXLibrary.lua:5294, 5355-5358`; `game/ReplicatedStorage/IceMagic/PyroFX.lua:603-619` (+ `PyroFlame_Fire.lua:492`, the same loop); `game/ReplicatedStorage/IceMagic/TerraFX.lua:1894-1906`; `game/ReplicatedStorage/IceMagic/VoltaicClient.lua:340-358`; `game/ReplicatedStorage/IceMagic/UmbraClient.lua:143-154, 187-221`; `game/ReplicatedStorage/IceMagic/RadiantClient.lua:115-119, 186-193`; `game/ReplicatedStorage/IceMagic/AquaFX.lua:2017-2035` (Sidearm); server: `VoltaicHandler.server.lua:483-500` (no chain from a corpse), `:669-684` (Volt Orb's sweep stops on any body), `PyroHandler.server.lua:346-366` (splash still lands round a corpse), `UmbraHandler.server.lua:625-638`, `RadiantHandler.server.lua:400-405`.
- **Trigger:** Team match (Config.Team.Size = 3). One enemy is down and their body lies between you and a live enemy, or lies at that enemy's feet. You fire Icicle Shard, Fireball, Boulder Shot, Chain Bolt, Shadow Dart, Light Lance or Sidearm along a line that passes the body or its twins. Low lines are most affected: shots at the legs, downward shots from height, and Boulder's falling arc. The crosshair's aim point lands on the body too.
- **Why it's a bug:** The manual says a body is scenery, not cover (P6B-10). Every client-side shot filter is "own character + camera + FX + `Config.AddUnhurtable`". `AddUnhurtable` adds only players the caster may not hurt, and `MayHurt` stays true for a dead enemy. So the casts stop on the corpse:
  - Icicle Shard: `workspace:Raycast(from, to - from, sh.Params)` with no health test (VFXLibrary:5294).
  - Fireball: the same, in PyroFX:619 and PyroFlame_Fire:492.
  - Boulder: TerraFX:1906.
  - Chain Bolt: a Spherecast (VoltaicClient:345). It even notes "a body ... live or not ... Only a LIVE body is predicted", then claims it anyway.
  - Shadow Dart: Spherecast (UmbraClient:215).
  - Light Lance: Spherecast (RadiantClient:190). It returns `body = nil` for a dead model, so the beam stops there with no claim.
  - Sidearm: Raycast (AquaFX:2035).

  These parts and their twins are CanQuery and the casts do not use RespectCanCollide, so the limbs, the transparent HumanoidRootPart and every surviving twin all count. Then the client reports the corpse. The server accepts the claim (CheckTarget: WasThere holds for a body lying where it fell), but `DealDamage` refuses a dead humanoid. The shot is spent:
  - Chain Bolt: "rej_friendly". No chain leaves it (`chainStart` stays nil, :488), and a primed bolt's prime is consumed.
  - Shadow Dart (FireInterval ~2.6 s): the dart is lost, and the Tell `exposed()` still fires (UmbraHandler:636).
  - Light Lance: rests on the body while draining mana per second (RadiantHandler:422).
  - Fireball: deals only its splash to live bodies round the corpse (PyroHandler:353-366).
  - Volt Orb: its server-side sweep `isBody` has no health test (:669-671, :682), so it bursts on the corpse. Live enemies within DamageRadius are still hurt, but they lose the direct-hit bonus (directOf needs Health > 0, :719-723).

  The aim ray (`aimPoint`) uses `RespectCanCollide = true` (:184), so it skips twins (CanCollide false). It still stops on the collidable dead limbs or root. That moves the Icicle Shard's target point (`FireIcicleShard(eye, target...)`, :1508) onto the corpse; the line from the eye is unchanged.
- **Suggested fix:** On death in a team round, set every BasePart of the dead character (twins included) to `CanQuery = false`, or move them to a collision group the shot casts ignore. Better still, clear the body after ~3 s as the manual says. Alternatively, have `Config.AddUnhurtable` (one place, used by every kit) also append any player's character whose Humanoid is at `Health <= 0`, and give Volt Orb's `isBody` a health test.
- **Notes:** Twins and `BreakJointsOnDeath`. Players' Humanoids keep the default `BreakJointsOnDeath = true`; only TrainingGround, AllyDummies, the decoy and the wall set it false. The twins are held by WeldConstraints. Roblox documents `Model:BreakJoints` as breaking WeldConstraints too. Whether the Humanoid's death-break takes the same path cannot be shown from the snapshot.
  - If the welds break: each twin is unanchored, Massless and CanCollide = false, so it falls through the floor and is deleted at FallenPartsDestroyHeight within a second or two. Only the corpse's own parts stay as blockers.
  - If they survive: the 2x twins ride the limbs for the whole round, doubling the shield.

  A one-line Studio test settles it: kill a player in a team round and look for the "Hitboxes" folder's parts. In a 1v1 Duel the round ends on the first death, so the corpse lives only RoundEndPause (2 s).

#### GC-02: Server side of P6A-05: nothing on the server stops a dash that passed through an enemy Bulwark Wall, and Cross-Slash and Bulwark Charge damage lands on bodies behind it
> **Consolidator:** duplicate of **P6A-05** (Dashes / dash strikes pass through Bulwark Wall (client and server)). Kept here for its slice-specific detail; counted once, under P6A-05.
- **Pass:** 6/5 (closes the open half of P6A-05)
- **Severity:** High (competitive integrity: the one wall in the game, "full projectile/sightline block")
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrHandler.server.lua:345-380` (launch: Start, Dir and Dist checked only against the hold and the server's root; no world check along the line), `:409-428` (`slashReach`: a box along the claimed dash line), `:494-504` (LOS for a claim is `Core.Blocked` from the NEAREST POINT OF THE DASH LINE to the victim); `game/ServerScriptService/TerraHandler.server.lua:389-422` (`sweepCharge`: `HumanoidsNear` round the server's copy of the charger, no line-of-sight test at all); `game/ServerScriptService/VoltaicHandler.server.lua:287-306` (Overcharge: the path is not checked, `dist` is only clamped); `game/ServerScriptService/ZephyrSkyriderServer.server.lua:330-395` (the ride is only speed-checked).
- **Trigger:** An enemy Terra holds Bulwark Wall up. You are a Zephyr (Cross-Slash Dash), a Terra (Bulwark Charge) or a Voltaic (Overcharge), or you are riding Skyrider, and you dash at the wall with an enemy behind it.
- **Why it's a bug:** Movement is the dasher's client, which passes through the wall (P6A-05). The server never re-traces the path against the wall:
  - **Cross-Slash:** `slashReach(..., passed = true)` accepts any claimed body inside the corridor from `slash.Start` to the strike's progress. Its LOS origin is `slash.Start + slash.Dir * clamp(at, 0, swept)`, the point on the dash line level with the victim. For a victim behind the wall that point is already past the wall, so `Core.Blocked` from there is clear and `Core.DealDamage(player, victim, S.Damage, ...)` (:504) lands. The X's own hits (`passed = false`) are checked from the strike origin, which is also past the wall.
  - **Bulwark Charge:** `sweepCharge` takes every Humanoid within Reach of the server's copy of the charging root with no Blocked test. A charger who went through the wall hits whoever is on the far side. A charger stopped against the wall can still hit a body pressed to its back: Reach 3.6 against a wall 1.6 thick (TerraFX.lua Tuning `BulwarkCharge.Reach = 3.6`).
  - **Overcharge and Skyrider:** these deal no path damage. The server accepts the claimed dash or ride without checking for the wall, so the body really ends up behind it (Overcharge also primes there).
- **Suggested fix:**
  - Fix P6A-05's `characterOf` on both clients first (return nil for a model with `WallOwner`).
  - Then make the server defensive:
    - Cross-Slash: refuse a launch, or truncate `Dist`, at the first `WallOwner` box on the server's ray from `Start` along `Dir`. Also require `Core.Blocked` to be clear from `slash.Start` to the claimed point (not only from the dash line).
    - Bulwark Charge: in `sweepCharge`, skip a victim when `Core.Blocked` from the charger's root to the victim's root is true.
    - Overcharge: clamp `dist` by a server ray against walls.
- **Notes:** Cross-ref P6A-05 (client half) and GC-03 (Skyrider's Gust has the same wall hole on its own, with no dash involved).

#### GC-03: Skyrider's Gust cone hits enemies standing behind a Bulwark Wall: its line-of-sight ray excludes every body it found, the wall included
- **Pass:** 6/5 (new, found tracing item 2)
- **Severity:** High (competitive integrity: a server-only path, no exploit needed, through the one sightline block in the game)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/ZephyrSkyriderServer.server.lua:267-289` (`found = Core.HumanoidsNear(...)`; `:272` `for _, model in pairs(found) do exclude[#exclude + 1] = model end`; `:285` `not workspace:Raycast(apex, d, params)`); `game/ServerScriptService/CombatCore.lua:183-203` (`HumanoidsNear` returns any Humanoid with `Health > 0`, a Bulwark Wall's included); `game/ServerScriptService/TerraHandler.server.lua:529-546` (the wall is a Model with a Humanoid, PrimaryPart = WallBody).
- **Trigger:** A Zephyr rides Skyrider and flaps the Gust toward an enemy Terra's raised Bulwark Wall, with an enemy behind it inside the cone (Range / HalfAngle).
- **Why it's a bug:** `launch` builds its LOS filter from every player's character plus every model `HumanoidsNear` returned. That includes the BulwarkWall model, which is within the same radius. So `workspace:Raycast(apex, d, params)` cannot see the WallBody, and the body behind it is struck (damage, the knock and SkyriderGustHit). Every other server LOS walk in the game treats `WallOwner` as cover: `Core.Blocked` :541-543, Pyro `lineBlocked` :93, Terra `flightBlocked` :285, Voltaic and Umbra `castThroughBodies`. The wall is also in the cone, so it takes the hit itself as well.
- **Suggested fix:** Do not add `WallOwner` models to `exclude` (filter them out of the `found` loop at :272), or replace the raycast with `Core.Blocked({ Origin = apex, Dir = d.Unit, Character = r.Character }, d.Magnitude, model)`.
- **Notes:** Decoys in `found` being excluded is fine (they are bodies).

#### GC-04: Bulwark Charge into an enemy Bulwark Wall stamps Staggered on the wall and broadcasts a body hit for it
- **Pass:** 6/5
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:394-418`; `game/ServerScriptService/CombatCore.lua:94-103` (IsWall: "Damage is right to land on it; nothing else is")
- **Trigger:** A Terra's Bulwark Charge reaches an enemy Bulwark Wall (its PrimaryPart within Reach).
- **Why it's a bug:** `sweepCharge` has no `Core.IsWall` guard. After a successful DealDamage on the wall it calls `Core.ApplyStatusTag(victim, "Staggered", ...)`, which puts the floating tag over the invisible wall box. It sets `RX_Staggered` and `RX_Staggered_Element` on the wall model, writes `AssemblyLinearVelocity` on an anchored part (a no-op), and broadcasts `BulwarkHit` at the wall. CombatCore's own rule says only damage may land on a wall. Skyrider's `strike` does have the guard (ZephyrSkyriderServer.lua:227).
- **Suggested fix:** `if Core.IsWall(model) then (damage only) ... return end` before the stagger and knock block.
- **Notes:** Cosmetic and status-board noise only. ElementalReactions refuses walls (:349).

#### GC-05: Other client "a model with a Humanoid is a body" shortcuts that treat the Bulwark Wall as a body
- **Pass:** 6/5
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua:403-433, 539-566` (the wall's Humanoid puts it on the bodies list; a hit on it spends a pierce and the blade flies on through it); `game/ServerScriptService/ZephyrHandler.server.lua:244-282` (the server counts the wall as a pierced body, then refuses the next body behind it with rej_blocked); `game/StarterPlayer/StarterPlayerScripts/MovementController.client.lua:482-490` (`wallHit`: a model with a Humanoid is never a wall, so you cannot wall-run on a Bulwark Wall); floor probes that look through any Humanoid model, the wall included: `game/ServerScriptService/ZephyrGustPadServer.server.lua:100-116` (`floorUnder`), `game/ServerScriptService/ZephyrHandler.server.lua:571-587` (`groundUnder`, Cyclone), `game/ServerScriptService/TerraHandler.server.lua:1057-1078` (Aftershock: documented as intended), `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:717-730` (the Ultimate's ground spot); `game/ReplicatedStorage/IceMagic/ZephyrFX_CrossSlash.lua:563-581`.
- **Trigger:** Any of these aimed at or used against an enemy's raised wall.
- **Why it's a bug:** `characterOf`-style tests ("has a Humanoid") were written before the wall existed.
  - Wind Blade: the shooter's own client draws its blade carrying through the wall and cutting the body behind it, and that body's hit is refused on the server. A pierce is spent on the wall, a visual lie.
  - Gust Pad and Cyclone, aimed at a wall's top: the spot drops to the floor inside or under the wall's footprint.
  - Wall-running: a Bulwark Wall is the only vertical surface that cannot be wall-run. This may be intended; it is undocumented.
- **Suggested fix:** Give the client a shared `IsBody(model)` that returns false for `model:GetAttribute("WallOwner")`, as CombatCore.IsWall does on the server. Use it in Wind Blade's `watchBody` and sweep, MovementController.wallHit (if the wall should be runnable), and the floor probes.
- **Notes:** Cross-Slash's own body collector (ZephyrFX_CrossSlash and SpellshotInput:510-530) claims the wall as a target. That is fine: walls are meant to take damage.

#### GC-06: P6A-16 refuted as queue-specific: the queued second Shadow Step re-checks what a fresh press re-checks, except Undertow's interrupt
- **Pass:** 3
- **Severity:** Low (only the InterruptedUntil gap remains)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/UmbraHandler.server.lua:743-811` (757 queue; 783-793 epoch/life; 798 PivotTo; 801-808 the queued `castShadowStep` call), `:898-904` (the dispatcher: AliveCharacter only); `game/ServerScriptService/SpellshotService.server.lua:894-907` (a fresh press's gates: Hub, CastLocked, Burrowed, `InterruptedUntil`, alive, Implemented), `:1053-1090` (cooldown, escape charge, mana; no speed cap or root test for a cooldown cast)
- **Trigger:** Umbra double-taps Shadow Step (normal cast, then escape charge) and an Aqua's Undertow interrupt lands in the ~0.12 s dissolve.
- **Why it's a bug (and why mostly not):** A fresh press passes SpellshotService's gates and then `castShadowStep`. Neither checks roots, Frozen (IceFrozenState), Entombed or stuns (see GC-07). So the queued press is not escaping anything a fresh press would be refused for, with one exception:
  - Zone, CastLocked and the round reset all move the epoch (CombatCore.ClearPlayer), and `:791` drops and refunds the queued step on an epoch change. Death drops it too.
  - Burrowed (Tremor Vault) is deleted content.
  - `InterruptedUntil` is the exception. A fresh press during Undertow's interrupt is refused at SpellshotService:903, but the queued one blinks. The first step also completes its blink despite an interrupt landing in its dissolve. Both are "a press accepted before the interrupt".
- **Suggested fix:** In the dissolve callback, before running `q`, refuse and refund (`dropQueued()`) when `workspace:GetServerTimeNow() < character:GetAttribute("InterruptedUntil")`. Do the same for the first step's re-form if an interrupt should cancel a blink in progress.
- **Notes:** The broader gap is GC-07.

#### GC-07: Shadow Step (any press, fresh or queued) ignores roots, Deep Freeze, Mirror Cage, Flash Freeze and Earthen Tomb; out of a Tomb it blinks and is pulled straight back, with the charge spent
- **Pass:** 3
- **Severity:** Medium
- **Confidence:** Medium (the code path is certain; whether a reposition should beat a root is not written down anywhere)
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:894-907, 1053-1090` (no SpeedCapSlow check outside the Charges path, :981-996); `game/ServerScriptService/UmbraHandler.server.lua:743-811` (castShadowStep: no cap, IceFrozenState or RX_Entombed test; `character:PivotTo` at :798); `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua:192-226` (canCast: no root test either); `game/ServerScriptService/TerraHandler.server.lua:633-634` ("a root (a cap of 0) refuses the Mobility key outright"), `:713-755` (the Tomb's AlignPosition, MaxForce 1e6, Responsiveness 60, to an anchored point), `:1011-1022` (only a MOBILITY Technique stamps CCBreak; Shadow Step is Umbra's Primary); `game/ServerScriptService/AbilityHandler.server.lua:1327-1350` (stepCages: Mirror Cage's bolts land on a trapped body wherever it is)
- **Trigger:** An Umbra is rooted (Deep Freeze prison, Mirror Cage, Flash Freeze or Frozen) or Entombed, and presses Shadow Step.
- **Why it's a bug:** Every other movement in the game respects a root: the Charges path refuses `cap <= 0` (SpellshotService:993), DashMotor refuses "Slowed" and "Frozen", and the Tomb's header says a root refuses movement outright. Shadow Step is a cooldown cast, so it reaches `PivotTo(dest)` while rooted and Umbra walks out of Deep Freeze or Mirror Cage. What follows:
  - The prison and dome go on being drawn at the old spot (the same desync as GC-08).
  - Mirror Cage's bolts keep landing on Umbra wherever it went (stepCages never checks position or VeiledUntil after the cast).
  - Entombed: the PivotTo moves the body, but the AlignPosition stays attached and pulls it straight back to the pillar's anchor. The step's cooldown or escape charge and its 20 mana are spent for a blink that undoes itself, and no CCBreak is stamped.
- **Suggested fix:** Decide the rule, then apply it on both sides. If roots beat the blink, refuse Shadow Step (with a GiveBack) when SpeedCapSlow <= 0, IceFrozenState exists or RX_Entombed is true, and mirror that in canCast. If the blink is meant to escape, make it end the root properly (BreakRoot plus DeepFreezeEnd/MirrorCageFree) and stamp CCBreak for the Tomb.
- **Notes:** Manual line 827 gives Shadow Step's numbers only, with no rule on CC.

#### GC-08: P3-05 visual half confirmed: after BreakRoot (Melt or Shatter) every client keeps drawing the Deep Freeze prison and the Mirror Cage dome, and Mirror Cage keeps shooting and damaging the freed body
> **Consolidator:** duplicate of **P3-05** (BreakRoot ends Cryo prison/cage roots silently; clients keep drawing them). Kept here for its slice-specific detail; counted once, under P3-05.
- **Pass:** 3/5 (closes P3-05's open half)
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/AbilityHandler.server.lua:1021-1037` (BreakRoot: ends the slows, destroys IceFrozenState and the snow emitter, clears a "Rooted" Status; no broadcast, `prisons[model]` / `caged[model]` untouched), `:1194-1199` (DeepFreezeEnd is broadcast only from breakPrison, i.e. clearRebuilt), `:1279-1285` (MirrorCageFree only from freeFromCage: cleared or dead), `:1341-1344` (the bolts' damage goes on to the root's natural end); `game/ReplicatedStorage/IceMagic/CryoFX.lua:2878-2948` (the prison ends only on `enc.Break` (DeepFreezeEnd), `isDead` or `age >= duration`, :2928; it never looks at IceFrozenState), `:1601` (the encase holds its own frozen tint key, so the body stays frost-tinted after IceFrozenState's holder is released at VFXLibrary.lua:2944-2953), `:3908-4420` (the dome sits at its fixed Center; the frost ring and the panels' bolts follow the victim's root, :4330-4347; it ends early only on MirrorCageEnd/MirrorCageFree or death)
- **Trigger:** 2v2 or Squad Clash. Your Cryo lands Deep Freeze (1.5 s) or Mirror Cage (MirrorCageRoot) on an enemy, and your Pyro (Melt) or Voltaic (Shatter) hits that enemy. Any non-DoT hit consumes "Rooted" first (ElementalReactions RULES).
- **Why it's a bug:** The server frees the body (endSlows) and removes IceFrozenState. On every client:
  - The VFXLibrary ice coat lets go.
  - CryoFX's prison crystals stay standing at the trap spot for the rest of the 1.5 s, and its frost tint (the encase's own setTint holder) stays on a body that walks away.
  - The Mirror Cage dome stays up for its whole duration, and its reflections keep firing at the freed body as it walks off. The bolts follow the root (:4347), and the server deals each bolt's damage anyway (AbilityHandler:1341-1344).

  The freed victim sees a FROZEN look on themselves, and others see a prison with nobody in it.
- **Suggested fix:** Have BreakRoot end the mechanics that own the root. If `prisons[model]` is set, call `breakPrison(model)`. If `caged[model]` is set, call `freeFromCage(caster, v)`. That broadcasts DeepFreezeEnd and MirrorCageFree, which CryoFX already handles. Alternatively, have CryoFX's prison and cage watch the victim's IceFrozenState removal (and give the cage an IceFrozenState) as a second signal.
- **Notes:** Shadow Step's blink out of a root (GC-07) produces the same desync without any reaction.

#### GC-09: P4-04 confirmed: the server has no part under an Entombed body, so Updraft's server sphere cast reads an Entombed Zephyr as airborne
> **Consolidator:** duplicate of **P4-04** (Updraft bonus while Entombed/juggled (no server pillar)). Kept here for its slice-specific detail; counted once, under P4-04.
- **Pass:** 4 (raises P4-04's confidence to High)
- **Severity:** Medium
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/TerraHandler.server.lua:713-755` (`hold`: the only part made is `TombLiftAnchor`, 0.2 studs, `CanCollide/CanQuery = false`, :722, parented to the FX folder, :726; the body hangs on an AlignPosition), `:760-769` (setHeight moves the anchor up to RiseHeight 12, TerraFX.lua:219), `:862-877` (catch), `:532` (WallBody is the only other Part the script creates); `game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua:336-341` (HELD = Climbing / Swimming / Seated / Dead), `:345-361` (probeParams: excludes the character and the FX folder, `RespectCanCollide = true`), `:363-389` (Clearance / Airborne), `:414-422` (IsAirborne); `game/ServerScriptService/ZephyrUpdraftServer.server.lua:50-66, 76-92`; `game/ServerScriptService/ZephyrHandler.server.lua:184-188, 279` (Wind Blade's UpdraftAir snapshot)
- **Trigger:** A Zephyr caught by Earthen Tomb keeps shooting (allowed: "the target can still shoot back") during the Rise (1.6 s), BurstHold (0.45 s) and Descent (0.8 s), whenever the pillar has lifted them past MinClearance 1.5.
- **Why it's a bug:** On the server nothing collidable is under the held body. The pillar is TerraFX_Tomb's client-only drawing, and the anchor is both non-collidable and in the excluded FX folder. So `workspace:Spherecast(root, 0.9, down...)` finds the floor far below and `clear >= 1.5`. The Tomb's hold is not a HELD state. Every Wind Blade released in that window carries `UpdraftAir = true`, and every other hit is judged airborne at the hit, so each lands at x1.25 (DamageMult). Knockback is x1.5 via KnockbackScale. The opponent's Ultimate buffs its victim.
- **Suggested fix:** As P4-04 suggests: in ZephyrUpdraft.Airborne (server side), return false while `character:GetAttribute("RX_Entombed")` is true, or while any server hold or knock owned by another player is on the body.
- **Notes:** The same applies to any body the server holds in the air (Cyclone, knock-ups), as P4-04 lists.

#### GC-10: PyroDraw never reads Reduce Flashing: `burst` flashes by default and every fire light flickers at 7.5-10 Hz, so Scorching Lash's snap/land/crack bursts and the Fireball's flight lights ignore the setting
> **Consolidator:** duplicate of **P5B-05** (Reduce Flashing ignored by Pyro/Terra/Toxin strobes (incl. all PyroDraw)). Kept here for its slice-specific detail; counted once, under P5B-05.
- **Pass:** 5
- **Severity:** Medium (accessibility setting not honoured for part of one Element)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/PyroDraw.lua:286-290` (flick, +-17 % at 10 and 7.5 Hz), `:1668-1669` (fire_ball's two lights always flicker), `:1726` (fire_tail), `:1788` (hand_flame), `:1811` (`burst`: the flash swell is on unless the caller passes `flash = false`), `:1890-1894` (burst's lights: an exp(-tau/0.12) flash, flickering), `:1952-1954` (pillar); callers: `game/ReplicatedStorage/IceMagic/PyroFlame_Fire.lua:380, 582` (the only callers that pass `flash = not reduceFlashing()`), `game/ReplicatedStorage/IceMagic/PyroFlame_Tech.lua:441, 523, 557, 735, 914, 1341` (no `flash` field: Scorching Lash snap, land, point pops, crack and hit, and the Detonate blast, which only scales its size by 0.75 at :722); compare `PyroFlame_Ring.lua:95, 1016` (dims and steadies its own lights) and ZephyrUpdraft.lua:146-147 ("ZephyrDraw calms the light itself")
- **Trigger:** Reduce Flashing on. You or an enemy throw Fireballs (the flight's PointLights flicker), crack Scorching Lash, or Detonate.
- **Why it's a bug:** The setting must be honoured wherever an effect is drawn. PyroDraw is the one renderer every Pyro flame look goes through, but it has no settings hook for flashing (only EffectDensity / ThinEnemyVFX, :407-416). Each caller has to remember to pass `flash = false` and steady its lights, and PyroFlame_Tech does neither. Even PyroFlame_Fire's careful callers cannot steady fire_ball's built-in flickering lights except by turning them off (`light = false`).
- **Suggested fix:** In PyroDraw, read `SpellshotSettings.Get("ReduceFlashing")` once per canvas in `PyroDraw.new`. Store it as `cv.Calm`. Under it, `burst` treats `flash` as false, `fire_light` drops the flicker (ignore `o.t` and the `flick()` factor in the builders) and caps the exponential flash terms, as ZephyrDraw and PyroFlame_Ring already do.
- **Notes:** PyroFX's toon look reads ReduceFlashing for its own Detonate (PyroFX.lua:1765), so the flame look is the gap.

#### GC-11: PyroDraw `ember_field` (and every emitter builder) sets its emitter's geometry only the first time a site is used, so a growing radius never grows; `big_blast`/`pillar`/`wildfire`/`pillar_embers` are dead code that would show it
- **Pass:** 5
- **Severity:** Low (latent)
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/PyroDraw.lua:1128-1162` (emitterSlot: `cfg` runs only when `s.site ~= site`), `:1291-1305` (cfgField sets `part.Size` from `radius`), `:1307-1324` (ember_field: only the CFrame and Rate are refreshed per call), `:2030-2045` (big_blast calls `ember_field(center, front, ...)` from the first frame with lit flames, when `front` is a fraction of a stud to a few studs); grep: `big_blast`, `:pillar(`, `:wildfire(`, `:pillar_embers(` have no caller anywhere in game/
- **Trigger:** Anyone wiring `big_blast` (the documented Ring of Fire eruption) into a look, or calling `ember_field` with a radius that changes over time.
- **Why it's a bug:** The wildfire's ember disc stays the size of its first frame's front, so all the field embers rise from a small disc in the middle while the fire fills 16 studs. The same per-site freeze applies to `burst`'s sparks: BURST_SPARKS speed, size and g are written per call but read by cfgBurst only once per site "burst_sparks"..seed. A canvas that bursts twice with one seed at two sizes keeps the first burst's spark speed and size.
  - Other latent issues in the same block: big_blast asks for 3 pillar lights + 5 wildfire glows against MaxLights 4 (2 when thinned), so the glows are mostly dropped. `wildfire`'s `lights = 5` default alone already exceeds the cap.
  - Current callers (PyroFlame_Ring :1054-1069, PyroFlame_Fire :940, PyroFlame_Tech :1438) pass constant radii and distinct seeds, so nothing live is affected.
- **Suggested fix:** In ember_field, resize `s.Part` when the radius changes by more than a few percent (cache it on the slot as `s.rad`). Re-run the speed and size part of cfgBurst whenever `o.size`/`o.speed` change, or key the site by size. Either delete the unused builders or note them as unported.
- **Notes:** none.

#### GC-12: PyroDraw `fire_ball`'s second light threshold is unscaled (`L > 3`) while every other length test is `* scale`
- **Pass:** 5
- **Severity:** Low
- **Confidence:** High
- **Files/lines:** `game/ReplicatedStorage/IceMagic/PyroDraw.lua:1641-1669` (cf. `:1645 L < 1.2 * scale`, `:1650 L > 2.4 * scale`, `:1655 L > 3 * scale`)
- **Trigger:** A small fire_ball, such as PyroFlame_Fire's orbiting motes (`ballO.scale = V.MoteBall * k`, PyroFlame_Fire.lua:684-685, which also adds its own light at :690).
- **Why it's a bug:** For scale < 1 the tail threshold is never met at the same proportion, so the trailing 650 W light comes on for short tails it was not meant for. Each mote then takes two fire_lights plus the caller's own light against the canvas cap of 4 (2 thinned), so the later motes lose their lights first.
- **Suggested fix:** `if L > 3 * scale then`.
- **Notes:** Cosmetic only.

#### GC-13: For each M1, whether damage can be dealt without the paid `CastRequest("M1")`: yes for six (Icicle Shard, Fireball, Wind Blade, Boulder Shot, Chain Bolt, Riptide), no for three (Shadow Dart, Light Lance, Toxic Bubbles)
> **Consolidator:** duplicate of **P1-12** (M1 hit remotes never pay mana). Kept here for its slice-specific detail; counted once, under P1-12.
- **Pass:** 1 (reconciles P1-12, graded Low, and P5D-13, graded High: the same issue)
- **Severity:** High (exploit: a modified client spams M1 for free and keeps the whole mana regen for its abilities)
- **Confidence:** High
- **Files/lines:** `game/ServerScriptService/SpellshotService.server.lua:953-967` (the M1 branch: the LastM1 rate gate, the ManaCost debit, PerformCast; the only M1 mana debit in the game; no token or record is left for any kit to check, and grep finds no `LastM1` reader outside this file); per kit:
  - Icicle Shard, YES: `AbilityHandler.server.lua:818-880` (ShardRelease: Zone, AbilityFor, CanAct, its own bucket, eye check; no link to the cast), `:883-951` (ShardHit damages and Chills); castIcicleShard (:723-729) only broadcasts.
  - Fireball, YES: `PyroHandler.server.lua:262-308` (FireballRelease), `:396-439` (FireballHit, direct + splash + Immolate burn); castFireball (:243-255) only broadcasts.
  - Wind Blade, YES: `ZephyrHandler.server.lua:135-190`, `:193-283`; castWindBlade (:117-129) only broadcasts.
  - Boulder Shot, YES: `TerraHandler.server.lua:111-130` (BoulderCharge), `:162-227` (BoulderRelease), `:291-336` (BoulderHit); castBoulderShot (:144-155) only relays.
  - Chain Bolt, YES: `VoltaicHandler.server.lua:429-509` (ChainBoltFire does everything; its header, :17, says the CastRequest "this ignores").
  - Riptide, YES: `AquaHandler.server.lua:350-410` (RiptideRelease), `:412-482` (RiptideHit); castRiptide (:334-344) only broadcasts.
  - Shadow Dart, NO: `UmbraHandler.server.lua:513-520` (the charge record is made only by castDartCharge, from the paid M1 PerformCast), `:532-542` (a release needs `charges[player]` and consumes it: one paid click, one dart).
  - Light Lance, NO: `RadiantHandler.server.lua:310-329` (the lance record only from castLance, via PerformCast), `:356-358` (RadiantLanceAim needs it), `:422` (the channel's own per-second mana drain on the server).
  - Toxic Bubbles, NO: `ToxinHandler.server.lua:388-425, 661-674` (the bubble only from castBubble, via PerformCast; the script has no client remote listener at all).
- **Trigger:** An exploit client sends only the release and hit pair (Icicle Shard, Fireball, Wind Blade, Boulder Shot, Riptide), or only ChainBoltFire, at the release handler's bucket rate, and never `CastRequest("M1")`.
- **Why it's a bug:** Damage comes from the release and hit remotes alone. Each applies its own bucket, CanAct and eye checks but never debits mana. That saves, at full rate:
  - Shard: 2 / 0.333 = 6.0 mana/s
  - Fireball: 3 / 0.6 = 5.0 mana/s
  - Wind Blade: 0.8 / 0.12 = 6.7 mana/s
  - Boulder: 4 / 0.85 = 4.7 mana/s
  - Chain Bolt: 2 / 0.32 = 6.25 mana/s
  - Riptide: 4 / 0.667 = 6.0 mana/s

  The regen is 7/s (SpellshotConfig.lua:40), so the exploiter has 70-95 % more mana for Techniques and Primaries during sustained fire. P1-12 (Low) and P5D-13 (High) describe the same defect, and it should carry one grade.
- **Suggested fix:** Have the M1 branch leave a short-lived paid token per player, as Umbra's `charges` do: for example `s.M1Paid += 1`, capped at 2, exposed through a BindableFunction or an attribute only the server writes. Each release handler then consumes one token or refuses with rej_unpaid. Or move the ManaCost debit into each release handler through `SpendMana` and drop it from the CastRequest.
- **Notes:** See GC-14 for what else the unpaired release skips.

#### GC-14: The same unpaired release makes five M1s invisible to everyone else: the shot is drawn for others only from the CastRequest relay, never from the release that deals the damage
- **Pass:** 1 (new angle on GC-13)
- **Severity:** High (competitive integrity: projectiles that damage you and that no other client draws)
- **Confidence:** High
- **Files/lines:** the relays: `AbilityHandler.server.lua:723-729` (broadcast "IcicleShard"), `PyroHandler.server.lua:243-255` ("Fireball"), `ZephyrHandler.server.lua:117-129` ("WindBlade"), `TerraHandler.server.lua:144-155` ("BoulderShot"), `AquaHandler.server.lua:334-344` ("AquaRiptide"); the draws: `StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua:85-106, 267-283, 291-313, 944-961`, `ReplicatedStorage/IceMagic/AquaClient.lua:866-872`; the release and hit handlers listed in GC-13 broadcast nothing (Boulder's BoulderChargeStop only if a BoulderCharge On was sent, TerraHandler:212); compare Chain Bolt, which broadcasts "ChainBolt" from ChainBoltFire itself (VoltaicHandler:505-508)
- **Trigger:**
  - (a) An exploit client as in GC-13.
  - (b) An honest client whose `CastRequest("M1")` is refused by SpellshotService's own rate gate (`now - LastM1 < min(0.8 * I, I - 0.05)`, :960) while the kit's release bucket (1.5-4 tokens of slack) accepts the release. That happens when two clicks bunch up under jitter.
- **Why it's a bug:** Every other client draws the shooter's arm, projectile and impact only from the PerformCast broadcast. With no accepted CastRequest the victim and spectators see damage numbers (CombatFeedback) and health dropping, with no shot, no thrust and no impact. In case (b) the honest shooter also skips that shot's mana, and the server never learns the two halves disagreed. TerraHandler.server.lua:208-212 comment already records the Boulder variant for watchers of the hold.
- **Suggested fix:** Same token as GC-13: a release with no paid M1 within the slack is refused, so damage and the relay always come together. Alternatively, move the relay broadcast into the accepted release (Chain Bolt's arrangement) and leave the CastRequest only for the arm pose.
- **Notes:** Shadow Dart, Light Lance and Toxic Bubbles are immune (the damage path needs the paid cast). Chain Bolt is visible but unpaid.

#### Could not complete
- Whether Humanoid death with `BreakJointsOnDeath = true` destroys WeldConstraints (and so drops the HitboxScale twins off a corpse) is engine behaviour. It cannot be settled from the snapshot (GC-01 Notes give the one-line Studio test).
- Whether a server `PivotTo` on a client-owned, AlignPosition-held character (GC-07, Entombed case) snaps back within a frame or two is reasoned from Roblox physics ownership, not observable here.


---

## Index of every distinct finding, by severity

Each finding is listed once, under its canonical ID. Duplicates are listed in the table near the top.

**High (15)**

- **P1-01** — Every shot/strike "origin near the server's body" check scales with the client's own root velocity and ping, uncapped — fire from anywhere (wall-bang, around corners, from far away)
- **P1-02** — Developer mode is live in production with a permanently full Ultimate — the place owner and a collaborator play every ranked match with infinite Ultimates and an unlimited Sparks button
- **P1-03** — The server enforces no movement at all — every root, slow, pull, knockback, launch, cage and Tomb is executed (and can be ignored) by the victim's own client; dodge checks read client-owned positions
- **P1-04** — The TRAINING GROUND (refilling dummies + snowball thrower) is in the ranked map vote — Ultimate, healing and cooldown farming on dummies mid-match, and duellists hit by the range's thrower
- **P1-05** — Temporary capture-stage scripts ship in ServerScriptService and StarterPlayerScripts with no Studio gate — if Enabled they break every live server
- **P2-01** — Same-server rejoin races the old profile's leave save against the new profile's load — progress (incl. a granted Robux receipt) can be overwritten
- **P4-01** — Skyrider's post-payment refusal is a free Earthen Tomb escape and an unlimited +6% Ultimate-charge farm while CC'd (exploit)
- **P5A-02** — Snow Globe's Blizzard places large opaque pines and crescent bands INSIDE the storm, so this one skin hides players from other viewers
- **P5A-03** — Frost Dragon's Flash Freeze leaves a 32-stud translucent claw and forearm over the whole zone, and only the caster's own client draws it clearer
- **P5C-01** — Colourblind-Safe repaints the real Umbra but not the Decoy Double copy, so the decoy is obvious to that viewer
- **P5C-02** — Devil skin swaps core Radiant tells for EditableMesh forms with no fallback; a pending or failed build leaves no beam, ring or column
- **P5F-02** — The third-person toggle (V) ships enabled for every player in ranked matches
- **P6A-05** — "Through characters" dashes treat Terra's Bulwark Wall as a body and pass straight through it
- **GC-03** — Skyrider's Gust cone hits enemies standing behind a Bulwark Wall: its line-of-sight ray excludes every body it found, the wall included
- **GC-14** — The same unpaired release makes five M1s invisible to everyone else: the shot is drawn for others only from the CastRequest relay, never from the release that deals the damage

**Medium (65)**

- **P1-07** — CastRequest (and most IceAbilityRemote actions) have no rate limit — free refused presses run server raycasts/overlaps, and BoulderCharge toggles are re-broadcast to every client
- **P1-08** — Patient Zero has no "one at a time" guard; under Deferred signal behaviour several Ultimate requests in one frame each pass the meter check and each cast a Patient Zero
- **P1-09** — Aimed area abilities clamp the aim point to range but never check line of sight — zones, pads, tanks and storms can be placed through walls into sealed rooms
- **P1-10** — Bulwark Charge always runs its full server window: no client ever sends "BulwarkChargeEnd", and the charge is accepted while rooted
- **P1-12** — M1 hit-report remotes are decoupled from CastRequest — an exploiter's M1s never pay mana
- **P2-02** — A server whose lock was taken keeps writing if the thief has since released (Session == nil is treated as "still mine")
- **P2-04** — If GetDataStore fails on a LIVE server, the whole server runs memory-only and Robux receipts are granted without being saved
- **P2-05** — Forfeit wins pay the full win reward with no participation minimum — Sparks farming with alts or a dev's BACK TO HUB
- **P2-06** — Every cosmetic is free: `OwnsSkin` returns true for any existing skin, there is no cosmetic ownership in the save, and in-build/premium skins are equippable live
- **P2-08** — SettingsStore: a failed GetAsync falls back to defaults that are later SAVED over the player's real settings
- **P3-01** — A reaction (or any hit listener that deals damage) that kills fires every OnKill listener twice for one death
- **P3-03** — A Toxin stepping into its own cloud converts an enemy's Poisoned into "own poison" (reduced damage, cleansable, credit stolen)
- **P3-04** — Flash Freeze's shatter hits everyone it EVER rooted, even after the root was broken or the victim was moved away
- **P3-05** — Reactions' BreakRoot ends every Cryo root (Deep Freeze prison, Mirror Cage, Frozen) silently — clients keep drawing the prison/cage, and an ally's Pyro M1 frees your Cryo's catch
- **P3-07** — Effects of a player who LEFT the game keep landing in their name in some kits but not others
- **P4-02** — An honest Zephyr can never use Skyrider to break Earthen Tomb, the design's stated way out
- **P4-03** — Earthen Tomb's escape rule keys off the pool HALF, so non-movement Techniques (Mark, Antitoxin Vent) break it and most Elements have none
- **P4-04** — Updraft's airborne damage bonus is granted by enemy crowd control (an Entombed or juggled Zephyr hits 25% harder)
- **P4-05** — An interrupt (Aqua Undertow, Terra Aftershock) CRACKS a held Scorching Lash instead of cancelling it, and the Pyro's client is never told
- **P4-16** — (latent: only with TechniquesOwnElementOnly = false) Shared SpeedCapUlt / RX_Shielded writers clear each other's state across kits
- **P5A-04** — Frost Dragon's "frost-over" draws a fake freeze on anyone standing in the zone at cast time, including the caster's allies, before (or without) the server root
- **P5A-05** — Frost Dragon's Blizzard cuts the Default storm wall to 40% and removes it entirely over half of the ring
- **P5A-06** — SnowGlobeFX.HitBloom calls `shards` before it is declared, so every Snow Globe M1 hit errors and leaks visible glass slabs
- **P5A-07** — FBX.Shatter errors for Frost Lotus (no ShatterChunks) and Snow Globe (kind tables have no Size), so their shatters lose the chunks, bursts, ripple and flash
- **P5A-08** — Frostblade, Frost Lotus and Snow Globe set `Built = true` even when kinds failed to build, so the skin path suppresses the Default and draws nothing in its place
- **P5A-09** — Reduce Flashing is not honoured by Cryo's light flashes or the Mirror Cage kill strobe, and Frost Dragon adds an extra ungated flash per M1 hit
- **P5A-10** — No Cryo effect (Default, skin or wrap) reads Colourblind-Safe, and some wraps move Cryo's zone edge toward other Elements' hues or toward low contrast
- **P5A-11** — Under a Glow wrap (Sakura Frost, Epic) the frozen crust on a body is hidden on every client, so FROZEN reads mostly by colour
- **P5B-01** — Toon-look Ring of Fire draws a HOT ring 3.5 studs smaller than the area the server burns
- **P5B-02** — Colourblind-Safe never reaches any Pyro, Terra or Toxin effect, or any of their wraps; it only repaints uniforms
- **P5B-03** — Wraps repaint hazards in other Elements' identity colours (Element misread)
- **P5B-04** — Default Toxin effects ignore Graphics Quality and Reduce Enemy VFX; only wrap "extras" scale. Pyro's toon-only Heat Rush and Cinder Shield are never thinned
- **P5B-05** — Reduce Flashing is ignored on several Pyro/Terra/Toxin strobes, including a 4.6 Hz telegraph pulse
- **P5B-07** — Earthen Tomb rework's fissure telegraph is a 0.10–0.24-stud sliver with no head and no target marker, and LOW + Reduce Enemy VFX removes the rest
- **P5B-08** — The Obsidian Magma boulder's visibility rim is a Highlight, subject to Roblox's on-screen Highlight cap
- **P5C-03** — Devil skin makes Radiant's attacks, heal zones and shields much darker than Default, so the opponent reads them less well
- **P5C-04** — Bloodmoon (Umbra wrap) changes what the opponent sees: a brighter charge ball and a slightly lighter Eclipse
- **P5C-05** — Radiant's Position Trade precheck is a free Decoy Double detector
- **P5C-07** — Reduce Flashing is ignored by every Radiant and Umbra effect, including a 2 Hz Benediction pulse
- **P5C-11** — Eclipse darkness and Shadow Step's vanish are drawn only by the viewer's client, which can skip them
- **P5C-14** — Decoy Double copies would be distinguishable for any non-Umbra caster (staff prop, pose) - latent: only with TechniquesOwnElementOnly = false
- **P5D-02** — Aqua honours none of the four settings (Graphics Quality, Reduce Enemy VFX, Reduce Flashing, Colourblind-Safe)
- **P5D-03** — Cascade's Reduce Flashing leaves its 15 Hz internal flashes, 30-60 Hz re-jags, fork re-strikes and several lights untouched
- **P5D-08** — Twin Tide and Leviathan's Maw collision is created by AquaFX (client-side, CanCollide colliders), so whether a player is blocked depends on assets loading, distance, network lateness, and it ignores teams
- **P5D-09** — No client-side end for Leviathan's Maw / Twin Tide on round reset or caster death: solid local colliders persist up to 5.3 s
- **P5E-01** — Cyclone's pull area (26-31 studs) is mostly invisible: nothing at ground level is drawn past about 13 studs while it pulls
- **P5E-03** — The Skyrider bird ignores Reduce Flashing: low-mana strobe flicker and hit stutter
- **P5E-04** — In team modes Gust Pad hits only enemies, but ally and enemy pads look identical, and the text still says "friend or foe"
- **P5F-03** — Reduce Flashing is never read by Umbra, Radiant (incl. Devil), Aqua, most of VFXLibrary's own flashes, DeathFX, or the viewmodel palm flash
- **P5F-04** — The default status-bar looks (BarFX) ignore Status Intensity and Reduce Flashing; StatusReactions — the documented applier — steps aside for them
- **P5F-05** — Graphics Quality and Reduce Enemy VFX are never read by three whole Elements (Umbra, Aqua, Radiant incl. the Devil skin)
- **P5F-06** — "Enemy" for Reduce Enemy VFX means "anyone who is not my character": teammates, dummies, and (briefly) your own effects are thinned
- **P5F-08** — Colourblind-Safe only repaints the uniform; no hazard, HUD, status bar, callout or viewmodel colour reads it
- **P5F-09** — Aqua is missing from the colourblind palette, so Colourblind-Safe paints every Aqua player gold
- **P5F-10** — The "safe" palette moves five Elements (not the two pairs it claims) and creates a new collision: Zephyr white vs Radiant near-white
- **P5F-13** — Entering the Hub or a map forces `Lighting.GlobalShadows = true`, overriding Graphics Quality LOW/MEDIUM
- **P6A-04** — RunningOnly movement mode is enforced only on the client; the server still grants Slide and SlideJump
- **P6A-06** — The retired Open Academy hub's HubSpawn is never disabled, so players can spawn in the unwired old hub
- **P6A-07** — Sakura Row's shoji windows never reset, so map state carries over between rounds and matches
- **P6A-08** — MatchHUD_RETIRED is still an active LocalScript in StarterGui; if not Disabled it rebuilds the old HUD and replaces _G.SpellshotHUD
- **P6B-02** — Under P31 Pyro alone gets four Techniques — the two the manual retired in v0.7 (Heat Rush, Cinder Shield) are live, built and selectable again, and the Heat resource the manual retired is live
- **P6B-07** — Economy — Sparks are only earnable from a full 6-player Quick Play team match; EconomyConfig's "a duel WIN pays 200" and the manual's earn sources do not exist
- **P6B-10** — Ragdolls, "a body is scenery, not cover" and "bodies clear after ~3 s" are not implemented; in team mode a downed body stays for the whole round with its 2x query-able hitbox twins
- **GA-01** — The BarFX chill looks show a ROOT / "FROZEN!" at Chill max stacks, which since 2026-10-08 is only a deep slow
- **GC-07** — Shadow Step (any press, fresh or queued) ignores roots, Deep Freeze, Mirror Cage, Flash Freeze and Earthen Tomb; out of a Tomb it blinks and is pulled straight back, with the charge spent

**Low (173)**

- **P1-11** — A NaN shot Id raises "table index is NaN" in six release handlers (fixed in TerraHandler only)
- **P1-13** — Interrupts are not honoured by Sidearm's drawn shot or Cross-Slash's strike (AliveCharacter instead of CanAct)
- **P1-14** — Gust Pad and Position Trade use SameParty, so Solo Test / Training Grounds players who "cannot hurt each other" can be launched and teleported by strangers
- **P1-16** — Relay broadcasts forward client numbers that are NaN-unsafe or unverified (Boulder "Charge" tell, Bulwark Charge "Dist")
- **P1-19** — Hub shrine prompts would change Element with no Zone / match check (dormant)
- **P2-03** — Writes issued after a leave save re-lock the record for this server, so the player's next server waits ~20 s on the starter kit
- **P2-09** — SettingsStore: pushes and "request" sent before the load finishes are dropped, and the load then reverts the player's early changes
- **P2-10** — SettingsStore leave/close writes are single-shot and can double-write the same key
- **P2-11** — Temporary stage scripts in ServerScriptService can push PARTIAL settings tables to a real player, resetting all their other settings
- **P2-13** — Shop can sell a Sparks pack to a player whose save is unavailable or still loading
- **P2-14** — Pending/failed-profile Sparks are shown as earned but never saved; AwardMatch reports a payout it did not make
- **P2-16** — Schema/migration hazards: unknown fields are discarded on every load+save, and there is no version check
- **P2-17** — Autosave writes every player every 60 s even when nothing changed, and piles up waiting writers during an outage
- **P2-18** — Doc drift — economy (manual vs code vs shop data)
- **P3-06** — RX_Staggered has two uncoordinated writers; one clears the other's stagger early (it gates Skyrider)
- **P3-09** — Ultimate charge counts self-damage and damage to non-players (walls, decoys, dummies); self-friendly logic depends on a dead Team clause
- **P3-10** — Reactions fire on self-hits and on fully-soaked hits
- **P3-12** — Undertow's interrupt overwrites (shortens) a longer interrupt already running
- **P3-13** — A match can never end if rounds keep drawing (no round cap, no tiebreak)
- **P3-14** — Combat stays live through MatchEndHold, and the dead are respawned into the arena during it
- **P3-15** — Death ordering: a 1 ms draw window vs hash-ordered AoE processing, and deaths outside DealDamage stamped late
- **P3-16** — HitboxScale silently widens every AoE that uses HumanoidsNear without a root-distance check
- **P3-17** — Derived damage (reaction bonus, Charged discharge, chain legs) spends the Umbra Mark and gets Updraft's multiplier
- **P3-20** — Dev panel Heal can raise a dead humanoid's Health (corpse becomes "alive" to every check)
- **P3-21** — Bulwark Charge's knock writes velocity on client-owned player roots (does little), unlike every other knock
- **P3-22** — GiveBack's Ultimate refund reads a stale per-role CastUlt from an earlier cast
- **P3-23** — StatusReactions — Blessed borrows the Shielded record without its bookkeeping; shield zone-glow pulse ignores Reduce Flashing
- **P3-24** — Doc drift found while tracing combat state
- **P4-06** — Aftershock's interrupt never reaches the victim's client; Aqua's Sidearm keeps firing phantom bullets, and its drawn shot ignores the interrupt
- **P4-07** — Held Techniques survive an Element or Technique change mid-hold (no ownership re-check), unlike the Lash, Railspike, Light Lance and the Overcharge prime
- **P4-08** — Cooldown, give-back and Ultimate bookkeeping are keyed by SLOT, so a swap between press and release/give-back charges the wrong ability
- **P4-10** — The Loadout menu's Technique rows are inert for 8 of 9 Elements (and claim a change on every click)
- **P4-11** — Ring of Fire's "Hot" variant reads Heat Rush's Heat, which Pyro's default loadout never equips
- **P4-12** — Decoy Double fools some Elements' target locks but not others'
- **P4-13** — Ring of Fire's burn and Cyclone's AIRBORNE tag are applied to a Bulwark Wall
- **P4-14** — Doc drift -- comments still describe the cross-Element pool, and several rules are misdescribed
- **P4-15** — (latent: only with TechniquesOwnElementOnly = false) ToxinWrap paints a borrowed Acid Rain / Antitoxin Vent in the caster's old Toxin wrap
- **P4-17** — (latent: only with TechniquesOwnElementOnly = false) A borrowed Cinder Shield locks Aqua's, Toxin's and Umbra's M1 for its 5 s
- **P4-18** — (latent: only with TechniquesOwnElementOnly = false) A borrowed Decoy Double is trivially spotted
- **P4-19** — (latent: only with TechniquesOwnElementOnly = false) Minor borrowed-Technique presentation gaps
- **P4-20** — Cold Momentum and Riding the Current both write MoveSpeedMult; an Element switch mid-buff lets one clobber the other
- **P5A-12** — Reduce Enemy VFX and Graphics Quality are not applied uniformly to skin pieces, and "enemy" means anyone other than me
- **P5A-13** — Mirror Cage stepper is not protected per hook, so one skin-hook error freezes the cage on screen and leaves its victims tinted
- **P5A-14** — Frost Lotus held lotus parts in workspace leak when the character is removed mid-hold
- **P5A-15** — Frostblade's Mirror Cage draws no dome at all when the caster's body is not on this client
- **P5A-16** — KillFX wraps a function that yields in CryoWrap's global palette swap
- **P5A-17** — CryoFX is 2 locals from Luau's 200 limit
- **P5A-18** — Wraps and skins change shot and zone geometry and intensity, which the manual forbids
- **P5A-19** — CryoWrap gates Black Ice's material on Roblox's own quality slider, not the game's Graphics Quality setting
- **P5A-21** — Frost Dragon kill effect sweeps a 25-plus-stud dragon through the arena on every client
- **P5A-22** — Each skin's visible zone rim sits outside the real zone edge
- **P5A-23** — Doc drift in the Cryo cosmetics
- **P5B-09** — ToxinFX's EditableMesh "skin" build is only partly pcall'd, and runs synchronously in the broadcast handler
- **P5B-10** — ToxinFX keeps resizable EditableMeshes alive for the session, which can starve TerraWrap's builds
- **P5B-11** — Toxin wrap colours apply only to what a handler draws synchronously; deferred pieces of a wrapped cast draw in Default olive
- **P5B-12** — Dead per-wrap branches in ToxinFX read Bands keys that no catalog wrap sets; the catalog's BRO comment is stale
- **P5B-13** — AzureFlame is offered and accepted on Heat Rush and Cinder Shield, but nothing draws it there, or anywhere in the toon look; its embers contradict the catalog
- **P5B-14** — Pyro wrap lights switch to azure before the wrapped flame meshes exist, so flames mix
- **P5B-16** — Debris is halved for every other player's Terra effects even with Reduce Enemy VFX off
- **P5B-17** — TerraFX's Wall hooks drop the server's T0, so the rework's late-beat logic uses arrival time
- **P5B-18** — Small lifecycle leaks: a resting Toxin bubble has no client timeout, ToxinWrap's byId is never pruned, and effect errors leave parts behind
- **P5B-19** — Aftershock plate pool thrashes between wrapped and unwrapped casters
- **P5B-20** — Fragile and doc-drift items in the settings plumbing for this slice
- **P5C-12** — The Overflow Light broadcast is stamped with the RECIPIENT's Blessing skin, not the caster's
- **P5C-13** — Eclipse's through-walls reveal stops only when `d.Character == player.Character`
- **P5C-15** — Docs say skins are colour-only and Flat palettes alpha-blended; the code does neither
- **P5C-17** — UmbraClient's Mark anchors table holds strong references
- **P5C-18** — The Devil Benediction crack-path cache holds one entry and thrashes with two concurrent channels
- **P5C-19** — RadiantFX_Hand is at 192 of 200 top-level locals
- **P5D-04** — Residual per-frame flicker under Reduce Flashing in Chain Bolt, Overcharge and Volt Orb
- **P5D-05** — An opponent's Volt Orb blooms and punches YOUR screen at full strength under Reduce Enemy VFX
- **P5D-07** — On LOW Graphics Quality with Reduce Enemy VFX on, the player's OWN Voltaic particles are halved too
- **P5D-10** — Volt Orb aim arc is only cleared on key-up, not on death, respawn, Element change or loss of focus
- **P5D-11** — Cascade's client strike prediction disagrees with the server's target rule, so bolts and the skeleton flash land on bodies the server never strikes
- **P5D-12** — Cascade's strike zone has no ground footprint at any setting, and the cloud overstates the zone
- **P5D-14** — CascadeFX has 13 slots of local headroom, not ~35 as its header implies, and the header's advice points at the tight block
- **P5D-15** — A CascadeEnd that arrives while the first storm is still loading is dropped, so the client draws a whole cancelled storm
- **P5D-16** — The Twin Tide debug probe ships on: 9+ SetAttribute writes per Heartbeat on every client for every cast
- **P5D-17** — An own Railspike whose server answer is late draws a stuck "observer" windup on the caster
- **P5D-18** — Doc drift in the Voltaic and Aqua settings and kit descriptions
- **P5D-19** — VoltaicTestHarness uses stale timings (Studio only)
- **P5D-20** — VoltaicFX ships about 940 lines of unwired Ground Surge v3 that the server also requires
- **P5E-06** — Wind Blade's shared burst canvases capture Graphics Quality and Reduce Enemy VFX once per session
- **P5E-07** — Wind Blade draws at most 16 blades, newest first, so in busy fights an incoming enemy blade can go undrawn
- **P5E-08** — Other players' Wind Blades are drawn off the real shot line (from the hand, never merged onto the eye line)
- **P5E-09** — The Skyrider gust's drawn cone is narrower than the server's hit cone
- **P5E-10** — Updraft's x1.25 applies to the Skyrider gust, while the Updraft tell is hidden for the whole ride
- **P5E-11** — Gust Pad's launch flash and the Cyclone's pulses are not reduced under Reduce Flashing
- **P5E-12** — No Zephyr VFX honours Colourblind-Safe, while the same setting repaints the Zephyr body white
- **P5E-13** — AbilityFX copies ZephyrClient.Handlers once, so a piece that loads late never gets its broadcasts (for example an invisible Gust Pad)
- **P5E-14** — ZephyrDraw sits at exactly 200 live locals, so one more local in its 2620-3259 block (or before it) is a compile error
- **P5E-15** — Gust Pad placement has no line-of-sight check, so a pad can go behind walls or onto the floor above (cross-ref Pass 1)
- **P5E-16** — Skyrider flight is client-trusted beyond a loose speed check (cross-ref Pass 1)
- **P5E-17** — The Updraft airborne check trusts the client-replicated root position (cross-ref Pass 1)
- **P5E-18** — Wind Blade hits may be reported up to 0.25 s (about 50 studs) earlier than the blade could fly (cross-ref Pass 1)
- **P5E-19** — A client that joins (or reloads) mid-pad never sees that Gust Pad (doc drift note included)
- **P5E-20** — Doc drift in the manual and DeflectPractice about Zephyr's current Techniques
- **P5E-21** — A Cyclone look made from the CycloneActive fallback is treated as not yours
- **P5E-22** — Graphics Quality scales only particles (and Cyclone's blade count), not Zephyr's Beam counts
- **P5F-07** — Shared hazards are thinned as "enemy" — Gust Pad (launches anyone) and the Frostblade Flash Freeze edge
- **P5F-11** — Colourblind repaint is lost after an Element change (and can lose the race on spawn)
- **P5F-14** — Graphics Quality tiers are inconsistent: MEDIUM is not "thin" anywhere in the `< 0.75` gates, ULTRA exists, skins use a different tier boundary
- **P5F-15** — CryoWrap reads "ThinEnemyVFX" through Settings.Get, which always returns nil — Reduce Enemy VFX never thins Cryo wrap extras
- **P5F-16** — Effect settings are baked at emitter creation; pooled looks never pick up a Graphics Quality change, and effects drawn before the save arrives use defaults
- **P5F-18** — HUD keybind chips are hardcoded F/Q/E/R and ignore rebinding and gamepad binds
- **P5F-19** — Settings menu Text Size is lost on tab switch and static labels stop rescaling after the first change
- **P5F-20** — Doc drift in the settings UI and palette comments
- **P5F-22** — SkinCatalog internal consistency gaps
- **P5F-23** — VFXLibrary's Frost Dragon M1 look is never painted by a Cryo wrap worn over the skin
- **P5F-24** — Some wraps change how visible a hazard or projectile is to the opponent (cosmetic → readability)
- **P5F-25** — AbilityFX small leaks/races
- **P5F-26** — Aqua shares Zephyr's Element logo and every Role glyph (placeholders), so Aqua and Zephyr read the same in the HUD
- **P5F-27** — Client can restyle OTHER players' cosmetics locally by setting their Player attributes
- **P5F-28** — Startup race between SettingsRuntime's FOV and FirstPersonController's hard-coded 90
- **P5F-29** — Luau top-level local counts (item 8)
- **P6A-09** — SpellshotInput's slot flash looks up the retired HUD, so cast-denied and cast-accepted feedback never shows
- **P6A-10** — The ServerStorage "ReviewFix" folders hold the pre-fix copies; the live files are the fixed ones
- **P6A-11** — The hub's ambient flicker effects ignore Reduce Flashing and Graphics Quality
- **P6A-12** — HubFireFlicker re-gather captures the already-modulated flame colour, and `cfs` is never trimmed
- **P6A-13** — HubLanternFlicker panes freeze when their lantern light streams out and back
- **P6A-14** — HubClient's "Ley over the Hall of Cores" animation is dead code for the replaced hub
- **P6A-15** — TerraTestServer and TerraTestHarness ship to live with no Studio guard
- **P6A-16** — Umbra live fix: a queued Shadow Step runs 0.24 s after the press without re-checking crowd control
- **P6A-17** — MapVote can bind its cursor render step twice
- **P6A-18** — QuickPlay's client and server queue state can desync when a request is throttled
- **P6A-20** — Stale player-facing text and comments in ReactionsBoard, MapRegistry and SlideAudio
- **P6A-21** — Dead and leftover live instances in the manifest
- **P6A-22** — Minor client nits in TouchBus, DevPanel and the dev buttons
- **P6B-01** — Techniques are own-Element-only (P31), but every doc still describes a shared cross-Element pool of "up to 3" — and the Dev Diary never records P31 at all
- **P6B-03** — Manual's Technique Pool table, contributor rule and Element tables are several reworks behind the code
- **P6B-04** — Dev Diary claims two manual edits (v0.16 Cascade-for-Thunderclap; v0.17 Antitoxin Vent cleanse + Acid Rain hybrid) that are not in the manual — the manual's v0.16/v0.17 numbers belong to different (Umbra) changes
- **P6B-06** — Modes — manual's 2v2 and 5v5 Squad Clash vs code's 3v3 "DUEL" team match; Quick Play advertises Squad Clash and "CONVERGENCE · NOW LIVE!" as selectable but the server refuses both
- **P6B-09** — Antitoxin Vent now cuts EVERY DoT by 30% (enemy burn and poison), contrary to the manual/diary rule that it stays own-poison-only so it cannot hard-counter a Toxin mirror
- **P6B-11** — Player-facing Technique/kit descriptions in SpellshotConfig are stale against the rows that are actually charged
- **P6B-12** — Movement, hitbox and projectile numbers in the manual appendix are out of date
- **P6B-13** — Pyro and Voltaic passives changed trigger/mechanic; the manual's Shatter reaction rationale depends on a Voltaic passive that no longer exists
- **P6B-14** — The Dev Diary records none of the code changes of 2026-10-17/18 that the code cites (balance pass, reactions, team mode, economy, movement switch, P27/P29/P31, handoffs #7/#8, Umbra escape charge, hitbox scale) — and the cited documents are not in the repo
- **P6B-16** — HANDOFF.md (2026-09-12) would mislead a reader today on roster, kit structure, currencies, Cryo kit, source of truth and open items
- **P6B-17** — Manual's Mana Shards / Attunement Phase, Mastery, Account Level, Contracts, separate mobile/PC pools are spec only; the diary says Mana Shards must become "points" and the manual was never corrected
- **P6B-18** — Devil skin's HUD set and status relabel (PACTED! / DENIED! / VOIDED!, black-iron Blessed bar) described in the manual are absent from code
- **P6B-19** — Small UI/setting drifts: Training Ground solo range is in the match map vote; the basic kill burst ignores Reduce Flashing; SFX plan says no audio settings exist
- **P6B-20** — Aqua's Sidearm and the manual disagree on the core verb (charged knock-back slug vs. held rapid-fire)
- **GA-02** — Shielded looks always play the BREAK at the end and never register a hit; Blessed's real break is never detected
- **GA-03** — The default Shielded look is Terra stone ("BEDROCK!") even when the shield is Pyro's Cinder Shield
- **GA-04** — Detonate's bar countdown runs "6 … 1" over a 1.5 s fuse
- **GA-05** — The poison looks draw a "x2 / DOUBLE DOSE" state for a single stack and print invented tick numbers
- **GA-06** — The bar plays a status's payoff whenever its flag drops early (round reset, death, cleanse)
- **GA-07** — PopArtHUD fires a burn-tick burst on the health bar for every HP loss, whatever the source
- **GA-08** — Dev-only HUD paths: the duel feed, the marked-crosshair star, slot charge art and the charges badge never run in live play
- **GA-09** — Text Size is not honoured by the round counter's middle label
- **GA-10** — Terra's Bedrock stacks are published "for the HUD's passive chip", but nothing on the client reads them
- **GA-11** — The HUD's zone-warning border pulse (2.5 Hz) ignores Reduce Flashing, but nothing in gameplay raises ZoneWarning
- **GA-12** — Picking Zephyr, Terra or Voltaic prints "<M1>, <Primary>, <Passive> live;  not built yet."
- **GA-13** — Further LoadoutMenu header and comment drift (beyond the known cross-Element line)
- **GA-14** — The WRAPS card's mark says "no wraps" for Cryo, Toxin, Terra and Umbra, which all have wraps
- **GA-15** — PopArtAssets: Toxin's payoff-word set reuses Voltaic's art; large sections are unreferenced
- **GA-16** — marked_t and marked_f draw the intro and payoff words on top of each other when a Mark is spent in its first 1.2 s (marked_a has the fix)
- **GA-17** — primed_f's spark embers are drawn off-centre (copy-pasted 34 px centre on a 44 px spark)
- **GA-18** — BarFX's front layer sits above the HP readout layer, so status art can cover the HP number the readout layer exists to protect
- **GA-19** — The Reactions board lists Dust Storm and Windswept (and Frozen's "Cryo on a Wet target") as live reactions; the code marks them DORMANT
- **GA-20** — `ReactionsOpen` is published "for the input scripts" but nothing reads it
- **GA-21** — The shop's rarity and element sorts break ties on raw price amounts across currencies
- **GA-22** — Looks re-push hard-coded "reset" restyles during their 0.8 s exit, overriding another live look's colours
- **GB-01** — Three Cryo skin kits and TerraWrap leak a resizable EditableMesh whenever a build step fails
- **GB-02** — Pyro burn flames wear the wrap of whoever last LASHED the body, whatever actually lit the current burn
- **GB-03** — A Detonate mark the watcher sees before its broadcast loses the caster's wrap and the landing pop
- **GB-04** — VFXLibrary's retired Chill Aura, Cryo Beam and Frost Slide renderers are unreachable but hold 50 of its 182 top-level locals (refines P5F-29's "16 / ~25")
- **GB-05** — PyroFlame_Fire's EmberRefund documentation says the broadcast carries only the caster; it now carries `From`
- **GC-04** — Bulwark Charge into an enemy Bulwark Wall stamps Staggered on the wall and broadcasts a body hit for it
- **GC-05** — Other client "a model with a Humanoid is a body" shortcuts that treat the Bulwark Wall as a body
- **GC-06** — P6A-16 refuted as queue-specific: the queued second Shadow Step re-checks what a fresh press re-checks, except Undertow's interrupt
- **GC-11** — PyroDraw `ember_field` (and every emitter builder) sets its emitter's geometry only the first time a site is used, so a growing radius never grows; `big_blast`/`pillar`/`wildfire`/`pillar_embers` are dead code that would show it
- **GC-12** — PyroDraw `fire_ball`'s second light threshold is unscaled (`L > 3`) while every other length test is `* scale`

---

## Closing: every file read, and what could not be completed

### Every file under `game/`

All 192 files under `game/` (the 191 scripts plus `manifest.json`) were read by at least one pass. The table lists every
file and the slices that read it (P1-P4 = passes 1-4; P5A-P5F and P6A-P6B = slices; GA, GB, GC = gap-fill reads). A file
in several slices was usually read fully by at least one; each slice's own "Files read" list says "fully" or gives the
exact partial ranges. `manifest.json` was dumped to an indented outline by script (2066 lines, then 713 after rig and
part-pile noise was filtered out) and that outline was read in full. It is not a script and was not read as raw JSON
line by line.

| File | Lines | Read by (pass slices; see each slice's "Files read" for full vs partial) |
|---|---|---|
| `game/ReplicatedStorage/IceMagic/AquaClient.lua` | 1009 | P1, P4, P5D, gapC |
| `game/ReplicatedStorage/IceMagic/AquaFX.lua` | 2403 | P4, P5D, gapC |
| `game/ReplicatedStorage/IceMagic/AquaTTPose.lua` | 266 | P5D |
| `game/ReplicatedStorage/IceMagic/AquaTTPoseTable.lua` | 296 | P5D |
| `game/ReplicatedStorage/IceMagic/AquaTTSimData.lua` | 147 | P5D |
| `game/ReplicatedStorage/IceMagic/AquaTuning.lua` | 185 | P5D, P6B, gapC |
| `game/ReplicatedStorage/IceMagic/CascadeFX.lua` | 4506 | P5D, P6B |
| `game/ReplicatedStorage/IceMagic/CastPose.lua` | 2260 | P5A, P5F, GB |
| `game/ReplicatedStorage/IceMagic/ChainBoltFX.lua` | 1359 | P5D |
| `game/ReplicatedStorage/IceMagic/ChainBoltShapes.lua` | 74 | P5D |
| `game/ReplicatedStorage/IceMagic/ChargedRock.lua` | 410 | P5B |
| `game/ReplicatedStorage/IceMagic/CryoAurora.lua` | 1395 | P1, P5A, P5F |
| `game/ReplicatedStorage/IceMagic/CryoFX.lua` | 4809 | P4, P5A, P5E, P5F, gapC |
| `game/ReplicatedStorage/IceMagic/CryoTuning.lua` | 309 | P3, P5A, P6B, gapC |
| `game/ReplicatedStorage/IceMagic/CryoWrap.lua` | 1585 | P4, P5A, P5F |
| `game/ReplicatedStorage/IceMagic/FlashFreezeData.lua` | 1981 | P5A |
| `game/ReplicatedStorage/IceMagic/FrostDragonData.lua` | 102 | P5A |
| `game/ReplicatedStorage/IceMagic/FrostDragonFX.lua` | 1253 | P5A |
| `game/ReplicatedStorage/IceMagic/FrostDragonKillFX.lua` | 577 | P3, P5A, P5F |
| `game/ReplicatedStorage/IceMagic/FrostDragonKit.lua` | 1038 | P4, P5A, P5F, GB |
| `game/ReplicatedStorage/IceMagic/FrostLotusFX.lua` | 739 | P5A |
| `game/ReplicatedStorage/IceMagic/FrostLotusKit.lua` | 1165 | P4, P5A, P5F, GB |
| `game/ReplicatedStorage/IceMagic/FrostbladeKit.lua` | 729 | P4, P5A, P5F, GB |
| `game/ReplicatedStorage/IceMagic/OverchargeFX.lua` | 2332 | P4, P5D |
| `game/ReplicatedStorage/IceMagic/PyroDraw.lua` | 2132 | P5B, GB, gapC |
| `game/ReplicatedStorage/IceMagic/PyroFX.lua` | 2523 | P3, P4, P5B, P5F, P6B, GA, GB, gapC |
| `game/ReplicatedStorage/IceMagic/PyroFlame_Fire.lua` | 1125 | P5B, GB, gapC |
| `game/ReplicatedStorage/IceMagic/PyroFlame_Ring.lua` | 1206 | P5B, GB, gapC |
| `game/ReplicatedStorage/IceMagic/PyroFlame_Tech.lua` | 1483 | P4, P5B, GB, gapC |
| `game/ReplicatedStorage/IceMagic/PyroPoseTable.lua` | 302 | P5B |
| `game/ReplicatedStorage/IceMagic/RadiantAnim.lua` | 1726 | P4, P5C, GB |
| `game/ReplicatedStorage/IceMagic/RadiantClient.lua` | 461 | P1, P4, P5C, gapC |
| `game/ReplicatedStorage/IceMagic/RadiantDevilForge.lua` | 2817 | P5C |
| `game/ReplicatedStorage/IceMagic/RadiantDevilStaffData.lua` | 686 | P5C |
| `game/ReplicatedStorage/IceMagic/RadiantDraw.lua` | 2024 | P5C |
| `game/ReplicatedStorage/IceMagic/RadiantFX_Hand.lua` | 1623 | P4, P5C, P5F |
| `game/ReplicatedStorage/IceMagic/RadiantFX_Staff.lua` | 2375 | P4, P5C |
| `game/ReplicatedStorage/IceMagic/RadiantFloat.lua` | 182 | P5C |
| `game/ReplicatedStorage/IceMagic/RadiantPoseTable.lua` | 268 | P5C |
| `game/ReplicatedStorage/IceMagic/RadiantTuning.lua` | 116 | P5C, P6B |
| `game/ReplicatedStorage/IceMagic/RailspikeFX.lua` | 2678 | P4, P5D |
| `game/ReplicatedStorage/IceMagic/SnowGlobeFX.lua` | 682 | P5A |
| `game/ReplicatedStorage/IceMagic/SnowGlobeKit.lua` | 1249 | P4, P5A, P5F, GB |
| `game/ReplicatedStorage/IceMagic/TerraFX.lua` | 4433 | P1, P3, P4, P5B, P6B, gapC |
| `game/ReplicatedStorage/IceMagic/TerraFX_Tomb.lua` | 1743 | P4, P5B |
| `game/ReplicatedStorage/IceMagic/TerraFX_Wall.lua` | 1501 | P4, P5B |
| `game/ReplicatedStorage/IceMagic/TerraWrap.lua` | 594 | P5B, GB |
| `game/ReplicatedStorage/IceMagic/ToxinClient.lua` | 129 | P1, P4, P5B |
| `game/ReplicatedStorage/IceMagic/ToxinFX.lua` | 2148 | P4, P5B |
| `game/ReplicatedStorage/IceMagic/ToxinTuning.lua` | 192 | P5B, P6B |
| `game/ReplicatedStorage/IceMagic/ToxinWrap.lua` | 70 | P4, P5B, P5C, P5F |
| `game/ReplicatedStorage/IceMagic/UmbraAnim.lua` | 490 | P5C |
| `game/ReplicatedStorage/IceMagic/UmbraClient.lua` | 646 | P1, P4, P5C, gapC |
| `game/ReplicatedStorage/IceMagic/UmbraDecoyPoser.lua` | 137 | P4, P5C |
| `game/ReplicatedStorage/IceMagic/UmbraFX.lua` | 2686 | P4, P5C, P5F |
| `game/ReplicatedStorage/IceMagic/UmbraTuning.lua` | 392 | P5C, P6B |
| `game/ReplicatedStorage/IceMagic/VFXLibrary.lua` | 5424 | P1, P3, P4, P5A, P5B, P5D, P5E, P5F, P6B, GB, gapC |
| `game/ReplicatedStorage/IceMagic/Viewmodel.lua` | 2878 | P4, P5A, P5D, P5F, P6A, GB |
| `game/ReplicatedStorage/IceMagic/VoltOrbFX.lua` | 2877 | P4, P5D |
| `game/ReplicatedStorage/IceMagic/VoltaicClient.lua` | 995 | P1, P4, P5D, gapC |
| `game/ReplicatedStorage/IceMagic/VoltaicFX.lua` | 1082 | P4, P5D, P6B |
| `game/ReplicatedStorage/IceMagic/VoltaicKit.lua` | 983 | P5D, P5F |
| `game/ReplicatedStorage/IceMagic/VoltaicTuning.lua` | 61 | P3, P5D, P6B |
| `game/ReplicatedStorage/IceMagic/ZephyrClient.lua` | 311 | P4, P5E |
| `game/ReplicatedStorage/IceMagic/ZephyrDraw.lua` | 3862 | P5E, P5F, GB |
| `game/ReplicatedStorage/IceMagic/ZephyrFX.lua` | 623 | P5E, P6B |
| `game/ReplicatedStorage/IceMagic/ZephyrFX_CrossSlash.lua` | 1700 | P5E, P5F, gapC |
| `game/ReplicatedStorage/IceMagic/ZephyrFX_Cyclone.lua` | 1883 | P5E |
| `game/ReplicatedStorage/IceMagic/ZephyrFX_Skyrider.lua` | 2461 | P4, P5E, P5F |
| `game/ReplicatedStorage/IceMagic/ZephyrFX_WindBlade.lua` | 1774 | P5E, gapC |
| `game/ReplicatedStorage/IceMagic/ZephyrGustPad.lua` | 1594 | P4, P5E, P5F |
| `game/ReplicatedStorage/IceMagic/ZephyrSkyrider.lua` | 1047 | P1, P3, P4, P5E, P6A |
| `game/ReplicatedStorage/IceMagic/ZephyrUpdraft.lua` | 1650 | P4, P5E, gapC |
| `game/ReplicatedStorage/Spellshot/AftershockKitData.lua` | 198 | P4, P5B |
| `game/ReplicatedStorage/Spellshot/BarFX.lua` | 826 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Atlas.lua` | 328 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/blessed_a.lua` | 231 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/blessed_f.lua` | 223 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/blessed_t.lua` | 202 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/burn_a.lua` | 212 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/burn_f.lua` | 258 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/burn_t.lua` | 227 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/charged_a.lua` | 248 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/charged_f.lua` | 237 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/charged_t.lua` | 247 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/chill_a.lua` | 269 | P5F, P6A, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/chill_f.lua` | 281 | P5F, P6A, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/chill_t.lua` | 282 | P5F, P6A, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/marked_a.lua` | 186 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/marked_f.lua` | 221 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/marked_t.lua` | 249 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/poison_a.lua` | 219 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/poison_f.lua` | 278 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/poison_t.lua` | 303 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/primed_a.lua` | 338 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/primed_f.lua` | 322 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/primed_t.lua` | 300 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/shield_a.lua` | 291 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/shield_f.lua` | 312 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarFX/Variants/shield_t.lua` | 326 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BarKit.lua` | 410 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/BulwarkWallKitData.lua` | 381 | P4, P5B |
| `game/ReplicatedStorage/Spellshot/Callouts.lua` | 203 | P5F, P6B |
| `game/ReplicatedStorage/Spellshot/DashMotor.lua` | 653 | P6A, gapC |
| `game/ReplicatedStorage/Spellshot/DeflectPractice.lua` | 162 | P3, P5E, P6A |
| `game/ReplicatedStorage/Spellshot/EarthenTombKitData.lua` | 446 | P4, P5B |
| `game/ReplicatedStorage/Spellshot/EconomyConfig.lua` | 118 | P1, P2, P6B, GA |
| `game/ReplicatedStorage/Spellshot/HeadingCompass.lua` | 455 | P6A |
| `game/ReplicatedStorage/Spellshot/IconAssets.lua` | 172 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/MapRegistry.lua` | 282 | P1, P3, P5F, P6A, P6B |
| `game/ReplicatedStorage/Spellshot/PopArtAssets.lua` | 346 | P5F, GA |
| `game/ReplicatedStorage/Spellshot/SkinCatalog.lua` | 613 | P1, P2, P4, P5A, P5B, P5C, P5D, P5E, P5F, P6B, GA, GB |
| `game/ReplicatedStorage/Spellshot/SpellshotConfig.lua` | 758 | P1, P2, P3, P4, P5A, P5B, P5C, P5D, P5E, P5F, P6A, P6B, GA, gapC |
| `game/ReplicatedStorage/Spellshot/SpellshotSettings.lua` | 424 | P1, P2, P5A, P5B, P5C, P5D, P5E, P5F, P6B, GA, GB |
| `game/ReplicatedStorage/Spellshot/TouchBus.lua` | 28 | P6A |
| `game/ReplicatedStorage/Spellshot/VoltOrbKitData.lua` | 78 | P4, P5D |
| `game/ServerScriptService/AbilityHandler.server.lua` | 1483 | P1, P3, P4, P5A, P6B, GA, GB, gapC |
| `game/ServerScriptService/AllyDummies.server.lua` | 124 | P1, P3 |
| `game/ServerScriptService/AquaHandler.server.lua` | 926 | P1, P3, P4, P5D, gapC |
| `game/ServerScriptService/CombatCore.lua` | 567 | P1, P3, P4, P5C, P5D, P6A, P6B, gapC |
| `game/ServerScriptService/CombatFeedback.server.lua` | 94 | P1, P3, gapC |
| `game/ServerScriptService/DuelMatch.lua` | 579 | P1, P2, P3, P4, P5C, P6A, P6B, GA, gapC |
| `game/ServerScriptService/EconomyService.server.lua` | 79 | P1, P2, GA |
| `game/ServerScriptService/ElementalReactions.server.lua` | 426 | P1, P3, P6A, P6B, GA, gapC |
| `game/ServerScriptService/FrostDragonKillHook.server.lua` | 28 | P1, P3, P5A |
| `game/ServerScriptService/HitboxScale.server.lua` | 108 | P1, P3, P6B, gapC |
| `game/ServerScriptService/HubServer.server.lua` | 1138 | P1, P2, P3, P4, P6A, P6B, gapC |
| `game/ServerScriptService/MovementModeServer.server.lua` | 38 | P1, P6A |
| `game/ServerScriptService/PlayerData.lua` | 554 | P1, P2, P6B |
| `game/ServerScriptService/PyroHandler.server.lua` | 1442 | P1, P3, P4, P5B, P6B, GA, GB, gapC |
| `game/ServerScriptService/RadiantHandler.server.lua` | 961 | P1, P3, P4, P5C, gapC |
| `game/ServerScriptService/SettingsStore.server.lua` | 144 | P1, P2, P5F |
| `game/ServerScriptService/SpellshotService.server.lua` | 1159 | P1, P2, P3, P4, P5A, P5B, P5C, P5D, P5F, P6A, P6B, GA, gapC |
| `game/ServerScriptService/StatusEffects.lua` | 410 | P1, P3, P6B, GA, gapC |
| `game/ServerScriptService/TerraHandler.server.lua` | 1551 | P1, P3, P4, P5B, P6A, P6B, GA, gapC |
| `game/ServerScriptService/TerraTestServer.server.lua` | 53 | P1, P5B, P6A |
| `game/ServerScriptService/ToxinHandler.server.lua` | 768 | P1, P3, P4, P5B, P6B, gapC |
| `game/ServerScriptService/TrainingGround.server.lua` | 519 | P1, P3, P5E, P6A |
| `game/ServerScriptService/UmbraHandler.server.lua` | 995 | P1, P3, P4, P5C, P6A, P6B, GA, gapC |
| `game/ServerScriptService/UniformAvatar.server.lua` | 179 | P1, P5C, P5F |
| `game/ServerScriptService/VoltaicHandler.server.lua` | 1123 | P1, P3, P4, P5D, gapC |
| `game/ServerScriptService/ZephyrGustPadServer.server.lua` | 396 | P1, P3, P4, P5E, P5F, gapC |
| `game/ServerScriptService/ZephyrHandler.server.lua` | 895 | P1, P3, P4, P5E, P6B, gapC |
| `game/ServerScriptService/ZephyrSkyriderServer.server.lua` | 406 | P1, P3, P4, P5E, gapC |
| `game/ServerScriptService/ZephyrUpdraftServer.server.lua` | 125 | P1, P3, P4, P5E, gapC |
| `game/ServerScriptService/_AuroraStage.server.lua` | 106 | P1, P2, P5A, P5B, P5C, P5F, P6A |
| `game/ServerScriptService/_BROStage.server.lua` | 101 | P1, P2, P5A, P5B, P5C, P5F, P6A |
| `game/ServerStorage/MovementSwitchReviewFix_2026_10_18/MovementController.client.lua` | 1246 | P1, P6A, P6B, GA, gapC |
| `game/ServerStorage/MovementSwitchReviewFix_2026_10_18/SpellshotConfig.lua` | 756 | P1, P2, P3, P4, P5A, P5B, P5C, P5D, P5E, P5F, P6A, P6B, GA, gapC |
| `game/ServerStorage/MovementSwitchReviewFix_2026_10_18/TouchControls.client.lua` | 414 | P6A |
| `game/ServerStorage/UmbraReviewFix_2026_10_18/UmbraHandler.server.lua` | 954 | P1, P3, P4, P5C, P6A, P6B, GA, gapC |
| `game/ServerStorage/_superseded_everfrost_2026_10_14/chill_ef.lua` | 363 | P6A, P6B |
| `game/StarterGui/MatchHUD_RETIRED.client.lua` | 619 | P6A |
| `game/StarterGui/PopArtHUD.client.lua` | 1036 | P5F, P6A, GA |
| `game/StarterGui/SpellshotShop/CardKit.lua` | 1250 | P2, GA |
| `game/StarterGui/SpellshotShop/Catalog.lua` | 63 | P2, P6B, GA |
| `game/StarterGui/SpellshotShop/ShopController.client.lua` | 1072 | P2, P6B, GA |
| `game/StarterGui/SpellshotShopButton/ShopButton.client.lua` | 82 | P2 |
| `game/StarterPlayer/StarterPlayerScripts/AbilityFX.client.lua` | 1080 | P1, P4, P5A, P5B, P5D, P5E, P5F, GB, gapC |
| `game/StarterPlayer/StarterPlayerScripts/BarFXClient.client.lua` | 4 | P5F, GA |
| `game/StarterPlayer/StarterPlayerScripts/DeathFX.client.lua` | 117 | P3, P5F, P6B, gapC |
| `game/StarterPlayer/StarterPlayerScripts/DeflectGustPractice.client.lua` | 81 | P5E, P6A |
| `game/StarterPlayer/StarterPlayerScripts/DevPanel.client.lua` | 735 | P1, P2, P4, P6A, P6B |
| `game/StarterPlayer/StarterPlayerScripts/FirstPersonController.client.lua` | 409 | P5A, P5C, P5F |
| `game/StarterPlayer/StarterPlayerScripts/FrostDragonKillFX.client.lua` | 2 | P3, P5A, P5F |
| `game/StarterPlayer/StarterPlayerScripts/HeadingCompassClient.client.lua` | 307 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/HitboxGuard.client.lua` | 36 | P3, P6A |
| `game/StarterPlayer/StarterPlayerScripts/HubBannerWave.client.lua` | 378 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/HubClient.client.lua` | 744 | P1, P5F, P6A |
| `game/StarterPlayer/StarterPlayerScripts/HubCrystalSpin.client.lua` | 62 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/HubFireFlicker.client.lua` | 112 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/HubLanternFlicker.client.lua` | 205 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/HubWaterFlow.client.lua` | 172 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/LoadoutMenu.client.lua` | 1352 | P1, P2, P4, P5A, P6B, GA |
| `game/StarterPlayer/StarterPlayerScripts/MapVote.client.lua` | 581 | P1, P6A |
| `game/StarterPlayer/StarterPlayerScripts/MovementController.client.lua` | 1258 | P1, P6A, P6B, GA, gapC |
| `game/StarterPlayer/StarterPlayerScripts/PopupScaler.client.lua` | 76 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/QuickPlay.client.lua` | 973 | P1, P6A, P6B |
| `game/StarterPlayer/StarterPlayerScripts/ReactionsBoard.client.lua` | 832 | P6A, GA |
| `game/StarterPlayer/StarterPlayerScripts/SettingsMenu.client.lua` | 1264 | P2, P5C, P5D, P5F |
| `game/StarterPlayer/StarterPlayerScripts/SettingsRuntime.client.lua` | 438 | P1, P2, P5A, P5B, P5C, P5D, P5E, P5F |
| `game/StarterPlayer/StarterPlayerScripts/SlideAudio.client.lua` | 105 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/SpellshotInput.client.lua` | 1915 | P1, P4, P5A, P5B, P5D, P6A, P6B, GA, GB, gapC |
| `game/StarterPlayer/StarterPlayerScripts/StatusReactions.client.lua` | 963 | P3, P5F, GA |
| `game/StarterPlayer/StarterPlayerScripts/TerraTestHarness.client.lua` | 363 | P1, P5B, P6A |
| `game/StarterPlayer/StarterPlayerScripts/TouchControls.client.lua` | 419 | P6A |
| `game/StarterPlayer/StarterPlayerScripts/VoltaicTestHarness.client.lua` | 629 | P1, P5D, P6A |
| `game/StarterPlayer/StarterPlayerScripts/ZephyrTestHarness.client.lua` | 163 | P5E, P6A |
| `game/StarterPlayer/StarterPlayerScripts/_AuroraStageClient.client.lua` | 18 | P1, P5A, P5C, P5F, P6A |
| `game/StarterPlayer/StarterPlayerScripts/_BROStageClient.client.lua` | 11 | P1, P5A, P5C, P5F, P6A |
| `game/Workspace/Map_SakuraRow/ShojiBreak.server.lua` | 118 | P6A |
| `game/manifest.json` | 46783 | P1, P2, P3, P5A, P5B, P5C, P5F, P6A, GA |

Outside `game/`: `README.md`, `docs/SPELLSHOT_Design_Manual.md`, `docs/SPELLSHOT_Dev_Diary.md` and `docs/HANDOFF.md`
were read fully. `docs/SPELLSHOT_SFX_Plan_CoreCombat.md` was skimmed. `docs/build_prompts/` and `docs/vfx_handoffs/`
were listed and grepped for the folder names, dates and skins that findings needed. `sim/` (empty except its README) and
`tools/` (export tooling) are out of scope per the brief.

### Read only as data (deliberately not line by line)

These are generated numeric blobs with no functions, requires or attribute reads (each pass grepped them to confirm
that). Their structure was checked against their consumers; their values were not checked number by number:
`FlashFreezeData.lua`, `FrostDragonData.lua` (vertex bounds measured by script for P5A-03), `RadiantDevilStaffData.lua`,
`AquaTTPoseTable.lua`, `AquaTTSimData.lua`, the baked tables in `CascadeFX.lua` (lines 455-663), and
`AftershockKitData.lua`, `BulwarkWallKitData.lua`, `EarthenTombKitData.lua`, `VoltOrbKitData.lua`. Re-run a value
check only if one of them is regenerated by hand.

### What cannot be settled from this snapshot (re-check in Studio or in Play)

- **Script `Enabled` / `RunContext`** is not in `manifest.json`. That decides P1-05 (and its six duplicates), P2-11,
  P6A-08 and P6A-15, and whether the staged `UmbraHandler` copy in ServerStorage can ever run (P6A-10 note).
- **`Workspace.SignalBehavior`** decides P1-08 (Patient Zero double-cast).
- **Live DataStore timing** decides the orderings in P2-01, P2-02 and P2-03. Whether `GetDataStore` can throw on a live
  server decides P2-04. Roblox's refund policy for never-granted receipts is engine behaviour (P2-13).
- **EditableMesh budgets, build times and API availability on devices** decide P5A-08, P5C-02 and P5B-08/09/10.
- **On-screen perception** (how much a pine or claw actually hides, luminance after Bloom, colour-vision collisions)
  decides P5A-02, P5A-03, P5C-03, P5C-04, P5F-10 and P5F-24. These were judged from geometry, opacity and colour values
  in the code, not measured.
- **Whether all 45 `PF_` flame meshes exist** (the manifest collapses that folder) decides whether Pyro's live look is
  "flame" or the "toon" fallback (P5B-01).
- **Which modes set `MatchTeam`** in practice affects P5E-04 (Gust Pad team rule).
- **The live place may have moved on.** The README warns this snapshot can be stale, and the `_BROStage` header is dated
  2026-10-19, a day after the export. Before acting, re-check a finding's lines against a fresh export.

### Passes not fully completed

None. Every pass has its own record above, including explicit "checked, clean" lines. Each pass and slice also listed,
at its end, any ranges it had read only in part. Every such range was then re-read in full by the gap-fill readers
(GA: UI, HUD, shop, status-bar variants; GB: PyroFlame builders, CastPose/Viewmodel data and update ranges, VFXLibrary
3100-4810, FrostLotusKit geometry, and a free-name scan of every client module; GC: PyroDraw 1650-2044 and the six
traces left open). Anything that was still not possible is listed in "What cannot be settled" above.
