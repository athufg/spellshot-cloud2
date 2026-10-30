# SPELLSHOT — documentation errata (2026-10-19)

**What this is.** A list of every place where the design docs no longer describe the shipped code, found by the cloud
bug audit (`SPELLSHOT_CLOUD_BUG_REPORT_2026-10-18.md`) and re-checked against the code for this file. The owner applies
it by hand. `tools/refresh.ps1` copies `docs/` from the Studio machine, so any edit made to the docs in this repo would
be overwritten. The four documents were therefore **not edited**. This file is new and is not overwritten by a refresh.

**How to read an item.** Each item gives the document and line, a short quote of the current text, what the shipped
code does (file:line), and either replacement text or **OWNER DECISION** where the code itself may be the stale side.
Code lines are at commit `981173e` (the 2026-10-19 fixes). Agents are editing `game/` in parallel today, so a line may
move by a few lines; find it by the quoted content. All code paths are under `game/`.

**Fix-wave update (same day).** Items M-88 to M-90, S-02, the OD-2/OD-7 notes, entries E6 and E7, and the matching
index rows were added after the audit's fix waves (wave 1 is commit `7615bc3`; wave 2 is the working tree on top of
it). They record the documentation handoffs in the wave-1 fix logs and the decisions taken for wave 2. Rules marked
**(fix wave)** were decided by the fix waves' coordinator, not by the owner. They are built that way in the cloud copy,
and the owner may reverse any of them.

**Rule used.** README.md says "If the code and the manual disagree, the code is what ships." Where a code comment
records the owner's decision (for example "the owner's pick"), the doc is treated as stale and replacement text is
given. Where no comment records a decision, the item is marked OWNER DECISION and both options are given.

**Contents**
0. Owner decisions that decide which side is stale
1. Design Manual (`docs/SPELLSHOT_Design_Manual.md`, v0.24): a ready-to-paste v0.25 change note, line items, and
   replacement tables
2. Dev Diary (`docs/SPELLSHOT_Dev_Diary.md`): corrections and seven ready-to-paste entries
3. HANDOFF.md: a banner line, plus line notes
4. README.md
5. SFX plan (`docs/SPELLSHOT_SFX_Plan_CoreCombat.md`)
6. Index: audit finding to errata item

---

## 0. Owner decisions that decide which side is stale

Settle these first. Several manual items below depend on them.

| # | Question | Code today | Docs today | Recommendation |
|---|---|---|---|---|
| OD-1 | Are Techniques own-Element only (P31), or one shared cross-Element pool? | Own-Element only. `ReplicatedStorage/Spellshot/SpellshotConfig.lua:497-509` (`TechniquesOwnElementOnly = true`, "P31, the owner: Techniques swap within your own Element only, never across"). The flag can be flipped back. | Manual, README and HANDOFF describe a shared pool of "up to 3" | Document P31 as the rule and keep one sentence that the shared pool can be switched back by the flag. All of section 1's P31 items assume this. |
| OD-2 | Does Pyro keep four Techniques (Heat Rush, Cinder Shield back) and the Heat resource? | Under P31 a Pyro may equip Heat Rush, Detonate, Cinder Shield and Scorching Lash (`SpellshotConfig.lua:378, 399, 403, 418`; no `PartialKits` row for Pyro). Ring of Fire's Heat bonus is live (`IceMagic/PyroFX.lua:134`: `HotDamage = 75, HotReach = 1.2`). | Manual v0.7 retired both and Heat (`:49-50, 277-282, 317, 831`) | Code finding P6B-02 (group G1). Either retire the two rows in code (add them to `Config.RetiredTechniques`) and keep the manual, or record in the manual that Pyro keeps four. Recommended: retire them, which matches v0.7 and gives every Element two. *Fix-wave note (P4-11, wave 2):* Ring of Fire's Desc now says the hotter version needs Heat built with Heat Rush. This is text only, with no change to the mechanic, so this question is still open. |
| OD-3 | Max health 100 or 150? | `SpellshotConfig.lua:38`: 150 ("raised to 150 on request (2026-09-12)"). The team-mode package v1 proposed 250 (diary 2026-10-18), which is not applied. | Manual `:17, 36, 536, 804`: 100, flagged open since v0.3 | Close it at 150 (the number every damage value was tuned against since September). |
| OD-4 | Which modes exist? | Quick Play's DUEL card is a 3v3 team match, first to 5, 90 s round clock (`SpellshotConfig.lua:237-255`, `StarterPlayerScripts/QuickPlay.client.lua:116-120`). The Hub's duel pads are the only 1v1. Squad Clash and Convergence have no match loop (`ServerScriptService/HubServer.server.lua` "Only DUEL can start a match"). | Manual `:562-566`: Duel 1v1 ranked, 2v2, Squad Clash 5v5 with an objective | Record the 3v3 team match as the shipped mode. Mark 2v2 and Squad Clash "designed, not built". The QuickPlay card fix is finding P6B-06 (G1/G4). |
| OD-5 | Economy shape | Starter kit is Pyro, Zephyr, Cryo, Terra and Radiant, with no starter Technique (`EconomyConfig.lua:30`). Sparks are paid only by a team match (`DuelMatch.lua:282`); pad duels pay 0. Robux buys Sparks packs only; there is no direct Element or Technique purchase (`EconomyConfig.lua:58-70`, `PlayerData.lua:44-47`). Every skin and wrap is free (`SkinCatalog.lua:421-423`, `OwnsSkin` stub). | Manual `:530, 607-618, 710-711, 749, 817-819` | The starter kit is "owner, locked 2026-10-18" (`EconomyConfig.lua:8-11`), so the manual is stale there. Earn sources and Robux unlocks are open: P6B-07 (G4) and P2-06 (deferred in the fixes doc). |
| OD-6 | Ragdolls and "a body is scenery" | Not built. A death is Roblox's default death plus a 0.45 s white burst (`StarterPlayerScripts/DeathFX.client.lua:14-18, 31`). In a team round the body stays until the next round (`HubServer.server.lua:487-488`, `Players.RespawnTime = 1e6`), and its hitbox twins stay queryable (`ServerScriptService/HitboxScale.server.lua:47`). | Manual `:549-554, 669-673, 820` | Keep the manual rule and mark it "not built yet". A code handoff so a corpse stops blocking shots is in the G8 fix log (P6B-10). |
| OD-7 | "A skin never changes ... effect intensity" | Several Cryo wraps and skins still change how the Icicle Shard is drawn (P5A-18): Sakura Frost's width and opacity override, Aurora's rim counts, Black Ice's near-black body, and the Wyrmling and mini-globe shots. Fixed in wave 1 (G6): Frost Dragon's Blizzard wall now keeps the Default's density except a narrow 15° pocket in front of each dragon (P5A-05, `IceMagic/FrostDragonFX.lua` `BZ`), and the Frost Dragon kill effect's swooping dragon is drawn only on the killer's and the victim's screens (P5A-21, `IceMagic/FrostDragonKillFX.lua`). | Manual `:655, 683, 797` | P5A-05 and P5A-21 now follow the manual. Notes recording them are in M-58 and M-63. P5A-18 is still the owner's call (G4 log). Recommended: name the Rework-skin exception under `:655` and cap a wrap's shard width at the Default (one data line in SkinCatalog). |
| OD-8 | Wrap tiers | The owner ruled on 2026-10-18 (diary `:1633`): no wrap carries a kill effect, an avatar aura or any HUD change; Epic = glow, pulse, motes; Mythic = a flowing or ambient treatment. | Manual `:631, 636, 698-699` still say Epic wraps reskin icons and the health bar, and Mythic wraps add an aura | Doc stale (the diary records the ruling). Replacement text is in M-50. |
| OD-9 | Devil skin HUD set | Not built: no PACTED!/DENIED!/VOIDED! string anywhere in `game/`; the Blessed bar has only `blessed_a/f/t`; one gold `blessed` callout style (`Spellshot/Callouts.lua:108-109`). The prompt `Opus5_Radiant_DevilSkin_HUD_Reskin.md` exists. | Manual `:181, 650-651` describe it as part of the skin | Either run that prompt, or mark the HUD layer "not built yet" (M-49). |
| OD-10 | Voltaic's VFX lane | The whole Voltaic kit is re-lit (Beams, Neon, PointLights, Bloom). The only waiver written in code is Ground Surge's (`IceMagic/VoltaicFX.lua:12-17`), and Ground Surge is unwired. The diary (2026-09-26, `:15-18`) records "Voltaic → vivid stylized glow" as a flagged exception. | Manual Section 0 (`:202-206`) lists no Voltaic exception | Record Voltaic's vivid-glow lane as a named exception (M-03). |

---

## 1. Design Manual — `docs/SPELLSHOT_Design_Manual.md` (v0.24)

The change notes (lines 8-189) are history and should stay as written. The items below change the body sections, and
M-00 adds a v0.25 note that records the changes.

### M-00. Ready-to-paste v0.25 change note (insert after line 189, before the `---`)

```markdown
**v0.25 change note (2026-10-19): the body brought back in line with the built game (cloud audit, 2026-10-18).** No new
design here: every line records something already decided and built, or marks a section "not built yet". Section 2's
tables are rewritten from `SpellshotConfig`; the Appendix numbers are the code's.
- **Techniques are own-Element only (P31, 2026-10-18).** Each Element has its own two Techniques and a player swaps
  them within that Element only. The shared cross-Element pool is switched off by one flag
  (`Config.TechniquesOwnElementOnly`), not deleted. Two slots (Q/E), not three. Sections 2, 5, 7, 8 and 15 are reworded
  to match.
- **Nine Elements are built** (Aqua included). The Element and Technique tables now show the built kits: Mirror Cage,
  Cascade, Earthen Tomb, Skyrider, Gust Pad, Railspike, Volt Orb, Aftershock, Detonate, Scorching Lash, Chain Reaction.
  Ultimates and Techniques the manual still listed (Cryo Beam, Thunderclap, Seismic Slam, Fault Line, Frost Slide,
  Chill Aura, Tremor Vault, Gust Jump, Deflect Gust) are retired.
- **Two lost edits from 2026-09-26 are ported here.** They were made to an older copy of the manual and lost when it
  forked, so the repo's v0.16/v0.17 numbers belong to Umbra: Cascade replaces Thunderclap; Antitoxin Vent cleanses your
  own poison on cast; Acid Rain is a hybrid (a light direct tick plus the vulnerability stacks).
- **The 2026-10-17 balance pass and the owner's picks that day:** Antitoxin Vent also cuts every DoT tick on you by 30%
  (this reverses the 2026-09-26 "own poison only" ruling); Ember Refund now fires when Pyro drops an enemy under 30%;
  Voltaic's Passive is Chain Reaction (Charged filling takes 2 s off Overcharge); Chill's third stack is a deep slow, not
  a root (since 2026-10-08). Every M1 projectile flies at 200 studs/s, and hitboxes are 2x the body.
- **Elemental Reactions are built (2026-10-17)** and settle the v0.12 open question: a teammate's status reacts exactly
  as your own does. Shatter is a flat bonus. Dust Storm and Windswept are dormant until Cracked and Wet have a source.
- **Modes, as built (2026-10-18):** Quick Play's one mode is a 3v3 team match, first to 5, with a 90 s round clock; the
  Hub's duel pads are the 1v1. 2v2, Squad Clash, Convergence, Ranked and Rift Royale are designed, not built.
- **Economy, as built (2026-10-18):** Sparks is the one currency; the starter kit is Pyro, Zephyr, Cryo, Terra and
  Radiant; a team match pays Sparks; Robux buys Sparks packs. Mana Shards, the Attunement Phase, Account Level, Mastery,
  Contracts, dailies, trading and the separate mobile/PC pools are not built.
- **Not built yet, marked so:** ragdolls and body clearing (Section 3), the KO! kill effect (Section 7), the Devil
  skin's HUD set and status words (Section 7).
- **Max health is 150.** The v0.3 open question is closed at the build's number.
- **Rules added by the 2026-10-19 audit fixes** (cloud copy; the fix waves' calls, open to the owner): a match also ends
  after 15 rounds played (proposed); deaths in the same server frame are simultaneous, so a round whose last players
  fall together is a draw; nobody casts during the result screen, and the dead stay down until they go home; a player
  who leaves the game stops everything they cast; RunningOnly is enforced by the server (no slide); a rooted, caged,
  Deep-Frozen or Entombed Umbra cannot Shadow Step; Updraft does not apply in air another player threw you into, nor
  to Skyrider's gust.
```

### Header and Section 0

| ID | Line | Current (short quote) | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-01 | 2 | "Full Design Manual v0.24" | — | "Full Design Manual v0.25" (after M-00 is pasted) | — |
| M-02 | 6 | "...a shared cross-Element Technique pool for build variety and scalable content..." | P31: `SpellshotConfig.lua:497-509` | "...a fixed four-piece kit per Element plus two swappable Techniques of that Element (the shared cross-Element pool is designed and can be switched back on), for build variety and scalable content..." (OD-1) | P6B-01 |
| M-03 | 204 (after this paragraph) | Section 0 names no Voltaic exception | All Voltaic modules re-lit; only Ground Surge's waiver is written (`IceMagic/VoltaicFX.lua:12-17`) | OWNER DECISION (OD-10). Suggested: "**Exception, Voltaic (recorded v0.25):** Voltaic's kit uses the vivid/stylized/glowing lane from v0.8 (real Neon, Beams, PointLights and Bloom, saturated, not photorealistic), as decided 2026-09-26 (Dev Diary)." | P5D-18 |

### Section 1 — Core Loop

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-04 | 212 | "a Loadout altar where players set their Element and up to 3 Techniques" | Two Technique slots of the chosen Element (`SpellshotConfig.lua:362`, P31) | "...set their Element and its two Techniques before queuing" | P6B-01 |
| M-05 | 212 | "Quick Play screen — Duel, Squad Clash, and the weekly Convergence mode, with Ranked and Rift Royale shown locked" | Only DUEL starts a match, and it is a 3v3 team match (`QuickPlay.client.lua:116-129`, `HubServer.server.lua` "Only DUEL can start a match in this build") | "...Quick Play screen. In this build Quick Play's DUEL card queues a 3v3 team match (two teams of `Config.Team.Size`); Squad Clash, Convergence, Ranked and Rift Royale are shown but have no match yet." (OD-4) | P6B-06, P6A-19 |
| M-06 | 216 | "swapping Element or any of the up to 3 Techniques ... (Duel, 2v2, Squad Clash, or any other mode)" | Lock enforced for Element and Technique changes (`SpellshotService.server.lua` LoadoutRequest, checked clean by the audit); skin and wrap changes are not locked | "swapping Element or either Technique ... Once a match is active (a pad duel or a team match) ... Cosmetic changes (skins, wraps) are not locked." | P6B-01 |
| M-07 | 218 | "Ranked ... a toggle on the Quick Play screen for Duel/2v2" | No ranked and no 2v2 in code | Append: "*(Not built. The shipped Quick Play mode is the 3v3 team match, see Section 4.)*" | P6B-06 |
| M-08 | 220 | "win the round by eliminating the enemy team or completing the round objective" | Round clock: after 90 s the larger share of health left takes the round, equal shares draw (`SpellshotConfig.lua:232-233` Duel, `:247-250` Team; `DuelMatch.lua:367`) | Append: "A round also has a 90 s clock: when it runs out, the side with the larger share of its health left takes the round (equal shares: a draw). Added 2026-10-17." | P6B-14 |
| M-09 | 222 | "everyone earns **Mana Shards** per round ... Attunement Phase" | Not built (no `ManaShard` / `Attunement` in `game/`). The diary (2026-10-06, `:1459-1463`) says the in-match currency is a separate points system, not Mana Shards | "Match loop: first to 5 round wins (Duel and the team match). *Planned, not built:* an in-match **points** system (not Mana Shards; Dev Diary 2026-10-06) spent in a pre-round Attunement Phase on temporary side-grade upgrades; how points are earned is open." | P6B-17 |
| M-10 | 224, 226 | "check daily Contract progress", "New weekly Contract line", "season pass progress" | None built | Append to each: "*(not built yet)*" | P6B-17 |
| M-88 | 220 (after M-08's sentence) | Round end: elimination or objective; no rule for players who fall at the same time, or for a player who leaves | Wave 1 (G1): every death is stamped with the server frame it happened in (`CombatCore.lua` `Core.FrameClock`; `DuelMatch.lua` deaths at `:353, :366, :578`), so deaths in one frame are simultaneous and a round whose last players fall together is a draw (P3-15). A player who leaves the game is cleared at once (`CombatCore.lua:408-409` PlayerRemoving → `Core.ClearPlayer(player, "left")`; `DuelMatch.lua` `release()` drops their `DuelMatch` / `MatchTeam`): nothing they cast lands after they leave, and nobody can hurt them or be hurt by them (P3-07) | Append: "Players who fall in the same server frame fall together: if they were the last of both sides, the round is a draw. A player who leaves the game takes everything they cast with them (a Ring of Fire, a Twin Tide or a Flash Freeze already placed stops at once), and their team plays on short-handed. *(2026-10-19 audit fixes.)*" | P3-15, P3-07 |
| M-89 | 222 (after M-09's text) | Match loop: first to 5; no cap on rounds and no rule for the result screen | Wave 1 (G1): `Config.Duel.MaxRounds = 15` (`SpellshotConfig.lua:240-244`, marked PROPOSED; a team match inherits it; 0 turns it off). After 15 rounds played, the side with more round wins takes the match and equal wins are a draw (`DuelMatch.lua:511-517`); a drawn match pays the draw reward. From the result to the trip home (`MatchEndHold`, 4 s) everyone is CastLocked and the dead stay down (`DuelMatch.lua:320-324`, `DuelMatch.Holds` `:589`; P3-14) | OWNER DECISION for the cap (P3-13: 15 rounds, or a sudden-death or damage-dealt tiebreak). As built, append: "Rounds that keep drawing cannot stall a match: after 15 rounds played, more round wins takes it, and equal wins draw the match *(proposed, 2026-10-19)*. While the result is on screen nobody can cast and nobody comes back; everyone returns to the Hub together." | P3-13, P3-14 |

### Section 2 — Elements and Techniques

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-11 | 232 | "Everything else in your kit — up to 3 **Techniques** — is drawn from one shared, uncategorized pool" | Two Techniques of your own Element (P31) | "Everything else in your kit — two **Techniques** — comes from your own Element: each Element brings its own Techniques and you choose which goes in Q and which in E. (A shared cross-Element pool is designed and can be switched back on with one flag, `TechniquesOwnElementOnly`; it is off.)" | P6B-01 |
| M-12 | 235 | "Up to 3 Techniques → freely picked from one shared pool, in any mix" | As above | "2 Techniques → your own Element's, in either slot (never the same one twice)" | P6B-01 |
| M-13 | 239 | "an Element contributes to the Technique pool only if it has something that actually fits its role. A pure-damage Element can contribute nothing at all" | Every one of the 9 Elements has its own Techniques, Pyro and Voltaic included (`SpellshotConfig.lua:377-423`) | "Under P31 every Element has its own two Techniques, damage-only Elements included (Pyro: Detonate and Scorching Lash; Voltaic: Railspike and Volt Orb). The v0.7 contributor rule only matters if the shared pool is switched back on." | P6B-03 |
| M-14 | 241-252 | "The 8 Launch Elements" table: Pyro Fireball "slow arcing lob ... must be led", Ember Refund "Landing a kill"; Cryo "3 stacks briefly roots", Ultimate "Cryo Beam"; Voltaic "very short range", Passive "Bonus damage vs. stationary targets", Ultimate "Thunderclap"; Terra Ultimate "Seismic Slam"; Zephyr Passive open question; Toxin bubbles "not yet finalized"; Radiant Ultimate "[working name]" | `SpellshotConfig.lua:275-352` (names and Descs), `IceMagic/PyroFX.lua:54-58, 76-82`, `ServerScriptService/StatusEffects.lua:65-75`, `IceMagic/VoltaicTuning.lua:31-43`, `SpellshotConfig.lua:425-442` | Replace the table with **Table A** below | P6B-03, P6B-11, P6B-13, P5D-18, P6B-04 |
| M-15 | 254-271 | "Technique Pool (launch: 12, one shared uncategorized list)": Frost Slide, Tremor Vault, Gust Jump, Chill Aura, Deflect Gust, Acid Rain "proposed default ... rather than direct damage" | Pool rows `SpellshotConfig.lua:377-423`; Acid Rain `IceMagic/ToxinTuning.lua:177-190` (`TickDamage = 6` plus vulnerability stacks) | Replace with **Table B** below | P6B-03, P6B-04, P5E-20 |
| M-16 | 256 | "pick any 3, in any mix" | Two, own Element | Drop the sentence; Table B's intro replaces it | P6B-01 |
| M-17 | 273-282 | "Retired in v0.7": Heat Rush, Cinder Shield; "Heat is retired as a resource" | Both rows live and selectable by a Pyro; Heat live (`PyroHandler.server.lua:27-28, 498-559`) | OWNER DECISION (OD-2). If code is changed to retire them: no manual change. If Pyro keeps four: add under the table "*(v0.25: under P31, Heat Rush and Cinder Shield are selectable again by a Pyro, and Heat with them; Ring of Fire's Heat bonus applies again.)*" | P6B-02 |
| M-18 | after 302 | (no retired table for the v6 Zephyr import or the Cryo/Voltaic/Terra replacements) | `SpellshotConfig.lua:379-411, 427-432`, `Config.RetiredTechniques` `:484-487` | Add **Table C** below ("Retired since v0.11") | P6B-03, P5E-20 |
| M-19 | 304 | "All 12 pool entries come from the 6 Elements ... Pyro and Voltaic, both damage-only, contribute none." | 20 Technique rows across all 9 Elements (Pyro 4 pending OD-2) | "Every Element has its own Techniques (Table B). The Mobility/Defense/Self-risk/Offense/Sustain words are flavour only." Keep the flavour-exception sentences if wanted. | P6B-03 |
| M-20 | 306-308 | "### Cross-Element mixing is a feature, not a bug" (whole subsection) | Off (P31) | Retitle "### Cross-Element mixing (switched off, P31)" and add first: "*Since 2026-10-18 (P31) Techniques stay with their own Element, so none of this applies while `TechniquesOwnElementOnly` is on. Kept for the day it is switched back.*" | P6B-01 |
| M-21 | 317 | "Pyro and Voltaic contribute nothing to the Technique pool (added v0.7)" | Both have their own Techniques | Replace with: "**Pyro and Voltaic (v0.25):** under P31 every Element carries its own Techniques; the v0.7 'contributes nothing' trade-off no longer applies." | P6B-03, P6B-02 |
| M-22 | 321 | "Kit is locked; nothing is built in Studio yet" (Aqua) | Built 2026-09-24 (`SpellshotConfig.lua:343-351`, `Config.BuiltElements` has Aqua) | "Kit is locked and built (2026-09-24)." | P6B-03 |
| M-23 | 330 | Sidearm: "Tap for a quick shot; hold to charge ... a denser slug that knocks the target back/up ... the held/charged shot is the one that launches" | Owner rework 2026-09-25 round 3: press draws the gun, first bullet after 0.14 s; held, 1.6 bullets/s at 4 Mana each after the first; every bullet 8 damage and knocks back; the charged slug is gone (`IceMagic/AquaTuning.lua:148-183`) | "**Sidearm** — A held, constructed water-gun. The press draws it and fires one bullet; held, it keeps firing slow bullets (1.6 a second, each after the first costs Mana) until you let go or run dry. Every bullet knocks its target back with a small pop up. *(Reworked by the owner 2026-09-25: the charged slug is gone.)*" | P6B-20 |
| M-24 | 342 | Toxic Bubbles: "*Not yet finalized: whether a bubble stops at the first enemy it hits or pierces*" | Stops at the first enemy, or rests where it lands (`SpellshotConfig.lua:339`) | "Lob a bubble of poison: it pops on the first enemy it hits, or rests where it lands for a few seconds." | P6B-03 |
| M-25 | 344 | Passive "(unchanged from launch)" | Name **Symbiosis** (`SpellshotConfig.lua:341`) | Name the row "**Symbiosis**" | P6B-03 |
| M-26 | 346 | Patient Zero: "Two scaling variants, neither locked" | Variant B: constant radius, scaling damage and duration (`SpellshotConfig.lua:439`, `ToxinTuning.lua:153`) | Append: "**Built as Variant B** (2026-09-30)." | P6B-03 |
| M-27 | 347 | Antitoxin Vent: "drops from the baseline 'reduced' amount to zero ... *Flagged, not resolved:* whether this also reduces ... an enemy's poison" | On cast, cleanses your own poison; while on, own poison and clouds do nothing to you, and every DoT tick on you (burn, poison, clouds) is cut 30% (`IceMagic/ToxinTuning.lua:163-172`, `ServerScriptService/ToxinHandler.server.lua:196-200`; "2026-10-17, the owner's pick") | Replace the "While active" sentence and the flag with: "On cast it cleanses your own current poison at once. While it is on, your own poison and clouds cannot touch you, and every damage-over-time tick on you (burn, any poison, clouds) hurts 30% less. *(v0.25: the cleanse is the 2026-09-26 pick, lost from v0.17; the 30% cut is the owner's 2026-10-17 pick and reverses the 'own poison only' ruling.)*" | P6B-04, P6B-09 |
| M-28 | 348 | Acid Rain: "**Proposed default, not confirmed:** a stacking vulnerability debuff ... rather than dealing direct damage" | Hybrid: a 6-damage tick each second for 4 s on everyone under it, plus "Corroded" stacks (+12% Toxin poison damage each, up to 4, 6 s) (`ToxinTuning.lua:177-190`) | "Calls down a poison downpour on a spot (radius 10, range 50): a light direct tick on everyone under it, plus stacking vulnerability that makes Toxin's poison hit them harder. *(Hybrid, the 2026-09-26 pick, lost from v0.17 and ported here.)*" | P6B-04 |
| M-29 | 347-348, 372-373, 420-421 | "Technique 1 (shared pool)" / "Technique 2 (shared pool)" | Own-Element (P31) | Replace "(shared pool)" with "(Toxin's own)", "(Umbra's own)", "(Radiant's own)" | P6B-01 |
| M-30 | 352 | "Flagged, not resolved: whether Antitoxin Vent and Acid Rain stay in the shared ... pool ... or become Toxin-exclusive" | P31 makes every Technique its own Element's | "*Resolved by P31 (2026-10-18): every Technique stays with its own Element.*" | P6B-01 |
| M-31 | 358 | Toxin "**Not yet built:**" | Built 2026-09-30 (`SpellshotConfig.lua:333-342`, `:134-136`) | "**Built (2026-09-30).** Old kit in `ServerStorage.ToxinKitSuperseded`." | P6B-03 |
| M-32 | 369 (Shadow Step row) | No dive reward, no second charge | Dive reward: cooldown 5 s instead of 10 when the step is cast within 2 s of landing a hit, or a hit lands within 2 s after it. Escape charge: a second, independent charge on the same key with a 6 s cooldown (`IceMagic/UmbraTuning.lua:58-69`; "handoff #8, the 3v3 sim's P27"; "the owner: same key, second charge") | Append to the row: "*(2026-10-18)* A step cast within 2 s of a landed hit, or followed by one within 2 s, has a 5 s cooldown instead of 10 (the dive reward). A second, independent **escape charge** on the same key (6 s cooldown) blinks the same way while the main cooldown runs. *(2026-10-19, fix wave, GC-07)* A root beats the step: a rooted, caged, Deep-Frozen or Entombed Umbra cannot start a Shadow Step, and the press is refused before it is paid (neither charge is spent)." | P6B-14, GC-07 |
| M-33 | 448 | Radiant "**Not yet built:**" | Built 2026-09-29 (mechanics; `SpellshotConfig.lua:688-691`); Devil skin in game 2026-10-13 (diary `:1598-1600`) | "**Built (2026-09-29).** Mechanics live; the Default look shipped in the Radiant phases after that." | P6B-03 |
| M-34 | 461 | Chill: "Stacks; 3 stacks briefly roots the target" | Third stack caps move speed at 10 for the 5 s window, then 1.2 s with no new stacks; no root (`StatusEffects.lua:65-75`, "the owner: a root is too strong for a basic attack", 2026-10-08) | "Stacks; each stack slows harder (speed cap 22 / 15 / 10). At 3 stacks the deepest slow holds for the rest of the window, then the stacks clear and none land for 1.2 s. *(2026-10-08: was a brief root.)*" | P6B-11 |
| M-35 | 465 | Charged: "*Assumed, not stated explicitly:* stacks build from Chain Bolt (M1) hits" | Confirmed: Chain Bolt applies Charged (`SpellshotConfig.lua:599`; `VoltaicTuning.lua:33` `Charged = true`); max 4 stacks, discharge 16 to the nearest within 20 (`StatusEffects.lua:77`) | "Built: Chain Bolt hits stack it (max 4); at max it discharges 16 damage to the nearest other enemy within 20 studs, or 7 into the charged target itself when there is none (every 1v1)." | P6B-03 |
| M-36 | 466-467 | Cracked and Wet: "confirm before building" | Neither has a source: Cracked is "held by the owner", Wet has no writer yet (`ServerScriptService/ElementalReactions.server.lua:22-23`) | Append to each: "*(v0.25: not built; nothing applies it yet.)*" | P6B-20 notes |
| M-37 | 478 | HUD: "**Not yet built:** locked here; no Studio work or build prompt exists" | Status bars and callouts exist (`ReplicatedStorage/Spellshot/BarFX/`, `Callouts.lua`, `StarterPlayerScripts/StatusReactions.client.lua`) | "**Built in part (2026-10):** each status has a health-bar look (BarFX) and a callout word. Check in Studio whether the world-space cluster and the screen-space panel match this spec before editing further." | — |
| M-38 | 482 | "This rewards exactly the kind of loadout diversity the Technique pool already encourages" | Under P31 a Duel player cannot mix Elements, so in 1v1 a reaction comes only from your own statuses; in a team match, from a teammate's | "In a team match it gives 'my Element plus your Element' a payoff. In a 1v1 under P31 a reaction can only come from statuses your own kit applies." | P6B-13 |
| M-39 | 486-487 | "Shatter (below) still works off Voltaic's Passive"; "Terra's Fault Line (its new Ultimate ...)" | Voltaic's Passive is Chain Reaction; Shatter is a flat +10 (`ElementalReactions.server.lua:16, 61`). Terra's Ultimate is Earthen Tomb (`SpellshotConfig.lua:431-432`); Fault Line was never built | "Shatter is a flat bonus (it no longer depends on a Voltaic Passive)." and "Terra's Ultimate is Earthen Tomb (Fault Line was never built), so Terra has no universal amplifier." | P6B-03, P6B-13 |
| M-40 | 503-504, 507 | Combustion "A Burning target inside a poison cloud"; Wildfire "extends ... or spreads a weaker Burn"; Shatter "Voltaic's own Passive already deals bonus damage to stationary targets ... in exchange for that bonus damage" | `ElementalReactions.server.lua:13-27`: Combustion = Pyro on Poisoned or Toxin on Burning, a burst round the body that burns away the cloud it stands in; Wildfire = one more burn stack and a fresh clock; Shatter = Voltaic on Rooted, the root breaks early for a flat +10 | Combustion: "Pyro on a Poisoned target, or Toxin on a Burning one: a burst round the body (over the whole cloud it stands in, which burns away); the status is consumed." Wildfire: "A Zephyr hit on a Burning target adds one burn stack and restarts its clock." Shatter: "Voltaic on a Rooted target breaks the root early for a flat bonus (10 damage)." Its "why" column: "Lightning cracks ice." | P6B-13, P6A-20 |
| M-41 | 511-512 | Dust Storm, Windswept rows | Dormant: Cracked and Wet have no source | Append "*(built, dormant until Cracked / Wet have a source)*" | — |
| M-42 | 522 | "Flagged, not resolved: whether a reaction triggers identically for a teammate's Element" | Decided in code: "a teammate's Element reacts exactly as a self-mixed Technique does" (`ElementalReactions.server.lua:27-30`) | "**Resolved (built 2026-10-17):** a teammate's status reacts exactly as your own does; a friend's hit is refused before it can set one off. What a player has equipped decides the reactions, never what they have unlocked." | P6B-13 |
| M-43 | 528 | "Eclipse ... counters mobility-heavy loadouts built around Gust Jump" | Gust Jump retired 2026-10-06 (`SpellshotConfig.lua:387`) | "...built around Skyrider" | P5E-20 |
| M-44 | 530 | "Start with the Pyro, Terra, and Radiant Elements ... plus one starter Technique (Bulwark Wall) ... Unlock the remaining 5 Elements and 11 Techniques ... account level ... Mastery rank 3 ... direct Robux purchase" | Starter kit Pyro, Zephyr, Cryo, Terra, Radiant (`EconomyConfig.lua:30`, "owner, locked"); Techniques come with the Element (P31); the other 4 Elements are bought with Sparks (1600-2000, placeholders, `EconomyConfig.lua:35-41`); Robux buys Sparks packs only | "**New player unlock path (v0.25, as built):** every player owns five Elements from the first join (Pyro, Zephyr, Cryo, Terra, Radiant), each with its full kit and its own two Techniques. The other four (Voltaic, Umbra, Toxin, Aqua) are bought with Sparks, earned in team matches or bought as Sparks packs with Robux. *(Account level, Mastery unlocks and direct Robux unlocks are designed, not built.)*" (OD-5) | P2-18, P6B-07, P6B-17 |
| M-90 | 249 (Zephyr Passive cell, "*Still open: whether it also means Zephyr can't be knocked out of the air...*") | Updraft: bonus damage and knockback while airborne | `ServerScriptService/ZephyrUpdraftServer.server.lua` header and modifier: air another player put the body in does not count (`RX_Entombed`, or `KnockedUntil` written by every knock, launch and enemy Cyclone; wave 1, P4-04); a hit whose info says `NoUpdraft = true` gets no bonus, and Skyrider's gust carries it (wave 2, P5E-10, fix wave: the kit's own comment says Updraft is not a gust's) | Table A's Zephyr row carries this. If the manual's row is edited in place instead, replace the "Still open" sentence with: "Air you put yourself in (a jump, your own Gust Pad) counts; air another player threw you into (a knock, a launch, a Cyclone, an Earthen Tomb) does not, so crowd control never buffs its victim. Skyrider's gust gets no Updraft bonus. *(2026-10-19.)*" | P4-04, P5E-10 |

**Table A (replaces lines 241-252).** Names and descriptions are the code's (`SpellshotConfig.lua:275-352, 425-442`).

```markdown
### The 9 Elements — M1, Primary Ability, Passive and Ultimate (all fixed)

| Element | Archetype | M1 | Primary Ability | Passive | Ultimate |
|---|---|---|---|---|---|
| **Pyro** | Aggro/DPS | **Fireball** — a straight shot at 200 studs/s (no drop since 2026-09-14), splash on impact | **Immolate** — your next 3 M1 hits deal bonus burn damage | **Ember Refund** — a hit that takes an enemy from 30% health or more to under it, and leaves them standing, refunds 30% of Immolate's cooldown: once per enemy unless they are healed back over (since 2026-10-17; was "on a kill") | **Ring of Fire** — point at the ground: a 17.5-stud circle of fire is drawn there and a snap erupts it, ~0.93 s from press to eruption |
| **Cryo** | Control/Zone | **Icicle Shard** — fast, flat, low damage; stacks Chill, a slow that deepens per stack (3 stacks: the deepest slow, not a root) | **Flash Freeze** — a ground zone where the crosshair points (up to 20 studs away): linger past 1 s and you are rooted, then shattered if still frozen when it ends | **Cold Momentum** — +10% move speed for 2 s after landing any hit | **Mirror Cage** — locks a target and cages them in a dome of ice panels that volley bolts at them |
| **Voltaic** | High-skill snowball | **Chain Bolt** — instant hitscan to 55 studs, auto-chains to a second enemy | **Overcharge** — an instant short dash; your next M1 chains to 2 extra targets | **Chain Reaction** — filling Charged on an enemy takes 2 s off Overcharge's cooldown | **Cascade** — mark a spot: a storm gathers overhead, then five bolts strike whoever is still under it |
| **Terra** | Aggressive tank | **Boulder Shot** — hold to charge, release early for less damage; the only chargeable M1 | **Bulwark Charge** — charges forward with damage reduction, knocks down whatever it hits | **Bedrock** — a stacking shield while charging M1 or mid-Bulwark Charge | **Earthen Tomb** *(working name)* — locks a target; a fissure hunts them down: jump it, or be raised in a stone fist and crushed |
| **Zephyr** | Mobility/Flank | **Wind Blade** — very high fire rate, low damage, pierces through a line; the hands alternate in a fixed pattern | **Cross-Slash Dash** — hold to charge the distance, release to dash at the crosshair in any direction, slashing an X through everyone in the path | **Updraft** — bonus damage and bonus knockback while airborne: your own jump or Gust Pad counts, air another player threw you into does not (a knock, a launch, a Cyclone, a Tomb), and Skyrider's gust never gets it (the v0.3 "no fall damage / faster air control" was never built) | **Cyclone** — a tornado forms at the crosshair and follows it while it forms, then pulls and juggles enemies into a cluster |
| **Umbra** | Mobility | **Shadow Dart** — slowest fire rate, highest single-shot damage; a true sniper | **Shadow Step** — dissolve and re-form a short way off, out of sight and out of every lock for a moment (with the dive reward and an escape charge, see the Umbra subsection); a root, Mirror Cage, Deep Freeze or Earthen Tomb holds you, and the step is refused unpaid | **Unseen** — Shadow Dart hits harder on a target that is not looking at you | **Eclipse** *(working name)* — the world goes dark: every enemy is unaware, revealed to you through walls, and your darts fly faster |
| **Radiant** | Support | **Light Lance** — held channel-beam; damage ramps the longer it stays on one target | **Blessing** — shields an ally or self for a chunk of absorb damage | **Overflow Light** — a Blessing shield that lasts its whole duration heals whoever had it with what is left | **Halo** *(working name)* — for a few seconds, the damage you deal also heals your team; all of it to you when you are alone |
| **Toxin** | Control/Zone | **Toxic Bubbles** — lob a bubble of poison: it pops on the first enemy it hits, or rests where it lands for a few seconds | **Corrosive Cloud** — turns your bubble (in flight or resting) into a lingering poison cloud right where it is | **Symbiosis** — poison you apply heals you slightly; your own poison hurts you less, but still hurts | **Patient Zero** *(working name)* — mark a target with a growing, quickening aura; it bursts into a poison cloud wherever they are, worse the more of their allies are near (Variant B) |
| **Aqua** | Control/Zone | **Riptide** — a crescent of whitewater surged along the ground; aim it, and jump it | **Undertow** — a vortex in front of you snaps enemies near it to its own centre and interrupts them | **Riding the Current** — your abilities leave wet ground: faster for you on it, an enemy on it slips | **Leviathan's Maw** — the flood rises and wave-walls close overhead into a glass tank; a shark circles beneath, then lunges |
```

**Table B (replaces lines 254-271).** Rows are `SpellshotConfig.lua:377-423`; "Q / E" is the Element's default slot (`Config.ElementDefaults`, `:457-477`).

```markdown
### Techniques (v0.25: each Element's own two, P31)

Since 2026-10-18 (P31) a Technique belongs to its own Element: a player carries their Element's two, one in Q and one
in E, and may swap which is where. The Mobility / Defense / Offense / Sustain / Self-risk words are flavour only. (The
shared cross-Element pool can be switched back on with `TechniquesOwnElementOnly = false`; an Exclusive Technique —
Detonate, Twin Tide, Sidearm — would still stay home.)

| Element | Technique (Q default) | Technique (E default) |
|---|---|---|
| Pyro | **Detonate** — marks whoever you last hit with Fireball or Immolate; after a short fuse it explodes, harder the lower their health | **Scorching Lash** — hold to carry a burning whip; let go to crack it where you aim, up to 35 studs; each hit stacks a burn (up to 3) |
| Cryo | **Blizzard** — a storm where the crosshair points (up to 20 studs away): everyone else inside is slowed and can barely see, for 6 s | **Deep Freeze** — an unseen trap at your feet: whoever sets it off is sealed in a crystal prison, rooted |
| Voltaic | **Railspike** — a short windup, then a bolt that pierces everyone in a 90-stud line | **Volt Orb** — hold to aim, release to lob a crackling orb that bursts into lightning on contact or when its fuse runs out |
| Terra | **Aftershock** — both fists into the ground: a ring of erupting rock races out and throws back everyone it reaches | **Bulwark Wall** — the one wall in the game: full projectile and sightline block |
| Zephyr | **Skyrider** — summon a bird of wind and ride it: fly where you look, flap a gust that throws enemies back; it drains Mana until you jump off | **Gust Pad** — press a gust pad into the ground at your crosshair: the caster and enemies who step on it are launched straight up (never a player you may not hurt: a teammate, or a stranger in a Solo Test) |
| Umbra | **Mark** — mark a target; it ripens over a few seconds; your own next hit spends it, a headshot for the most | **Decoy Double** — a stationary illusion, the only misdirection tool in the game |
| Radiant | **Position Trade** — instantly swap places with any target in range: an ally, an enemy, a dummy | **Benediction** — plant your staff: rays heal every ally near you, or you when none are near; you are rooted while it lasts (at most 8 s) |
| Toxin | **Antitoxin Vent** — a gas mask: cleanses your own poison at once; while on, your own poison and clouds cannot touch you, and every DoT hurts you 30% less | **Acid Rain** — a poison downpour on a spot: a light tick on everyone under it, and stacks that make Toxin's poison hit them harder |
| Aqua | **Twin Tide** — two wave-walls close in on a lane from either side; whoever is caught where they meet is crushed | **Sidearm** — a water-gun: draw it and fire, or hold to keep firing (each bullet costs Mana); every bullet knocks back |

*OWNER DECISION (OD-2): Heat Rush and Cinder Shield are still rows for Pyro in code and a Pyro can select them. Add
them to Pyro's row, or retire them in code.*
```

**Table C (insert after line 302).**

```markdown
**Retired since v0.11 (kept for the record; the code keeps each old kit in `ServerStorage.*KitSuperseded`):**

| Retired | Element | Replaced by | When |
|---|---|---|---|
| Cryo Beam (Ultimate) | Cryo | Mirror Cage | 2026-09-24 (v0.11) |
| Frost Slide, Chill Aura | Cryo | Blizzard, Deep Freeze | 2026-09-24 (v0.11) |
| Thunderclap (Ultimate) | Voltaic | Cascade | 2026-09-25/26 (never had a cast path) |
| Chain Lurch, Static Field | Voltaic | Railspike, Volt Orb | 2026-09-25 |
| Seismic Slam (Ultimate) | Terra | Earthen Tomb | 2026-09-19 (never had a cast path; "Fault Line" was never built) |
| Tremor Vault | Terra | Aftershock | 2026-09-25 |
| Gust Jump, Deflect Gust | Zephyr | Skyrider, Gust Pad | 2026-10-06 (the v6 import) |
```

### Section 3 — Combat and movement

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-45 | 536 | "Health baseline: 100 HP ... (Still open per v0.3 — the current build runs 150 ...)" | `SpellshotConfig.lua:38`: 150 | OWNER DECISION (OD-3). Recommended: "**Health baseline: 150 HP** (closed v0.25 at the build's number), tunable per Element only through passives and shields..." | P6B-12 |
| M-46 | 542 | Shared movement set (sprint, crouch, slide, slide-jump) | Also: one double jump, wall run and wall jump for everyone (`SpellshotConfig.lua:101-119`); a Movement Mode switch, "Full" (default) or "RunningOnly" (run, crouch, one ground jump), set live by a dev (`:125-136`) | Append: "Everyone also has one double jump, a wall run (up to 1.4 s) and a wall jump. **Movement Mode (2026-10-18):** 'Full' is all of the above; 'RunningOnly' keeps the run, the crouch and one ground jump only, and every kit's own mobility is unchanged. Full is the default; a dev can switch it live. The server enforces RunningOnly too: a slide asked for in that mode is a crouch *(2026-10-19)*." | P6B-12, P6A-04 |
| M-47 | 543 | "Hits count where the shot visibly passes: a shot is tested for hits as wide as it is drawn" | Since 2026-10-17 every body part has an invisible hitbox twin 2.0x its size in every direction (`SpellshotConfig.lua:257-268`, `HitboxScale.server.lua`), the head twin counts as the head for Mark, and every M1 projectile flies at 200 studs/s (Chain Bolt and Light Lance stay hitscan) | Append: "**Hitboxes (2026-10-17):** every body part is hit as if it were 2x its size in every direction (the owner: 'this would get us around rivals'), the head included, so a hit can land where the shot visibly passes just beside a body. Every M1 projectile flies at 200 studs/s; charge times differ, speed does not." | P6B-12 |
| M-48 | 545 | "Separate matchmaking pools for mobile and PC/console" | One Quick Play queue (`HubServer.server.lua`) | Append: "*(not built yet: one queue today)*" | P6B-17 |
| M-49a | 549-554 | Ragdolls: "Every elimination ends in a ragdoll ... A ragdoll has no hitbox and blocks nothing ... A body stays down for about 3 seconds" | Not built: default death and a 0.45 s white burst (`DeathFX.client.lua:14-18, 31`); in a team round the body stays until the next round and its 2x hitbox twins stay queryable, so some kits' shots stop on it (GC-01) | OWNER DECISION (OD-6). If the rule stands, add under the heading: "*(v0.25: not built yet. Today a player falls with Roblox's default death and a short white burst, and in a team round the body stays until the round ends. Until ragdolls are built, the 'scenery, not cover' rule is the target.)*" | P6B-10 |

### Section 4 — Modes and maps

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-50a | 560-566 | Mode table: Duel 1v1, 2v2, Squad Clash 5v5, Rift Royale, Convergence | Pad duel 1v1 (`Config.Duel`), Quick Play 3v3 team match, first to 5, 90 s clock, 15 s map vote (`Config.Team`, `SpellshotConfig.lua:244-255`) | OWNER DECISION (OD-4). Suggested: add a first row "**Team match** *(built 2026-10-18)* · 3v3 (`Config.Team.Size`), first to 5 rounds, nobody comes back mid-round, 90 s round clock · Quick Play's one mode in this build ('Team-comp only: one mode, one ruleset', the owner)", change Duel's purpose to "a Hub duel-pad 1v1; pays no Sparks", and append "*(designed, not built)*" to 2v2, Squad Clash, Rift Royale and Convergence. | P6B-06, P6A-19 |
| M-50b | 572-578 | Maps table: Training Ground "never a ranked map"; four arenas | Training Ground is offered to a Solo Test only, never to a duel or team vote (`MapRegistry.lua:125-126` `Practice = true`, the 2026-10-19 fix). Code also has **Sakura Row** (`:270-272`) and two Skyline variants, **Skyline · Concept** and **Skyline · Rivals** (`:155-184`) | Training Ground: "The solo test range: target boards and training dummies. Offered to a Solo Test only, never in a duel or team-match vote." Add: "**Sakura Row** — shrine, alleys and rooftops at night." and note Skyline is in the vote as two variants. | P6B-19 |

### Sections 5, 6 — Progression and economy

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-51 | 586, 588 | Account Level unlocks Elements; Mastery rank 3 unlocks the Element's Technique contribution | Neither built (no level, no Mastery in `game/`); under P31 an Element's Techniques come with it | Append to Account Level and Mastery: "*(not built yet)*". In Mastery, drop the rank-3 Technique unlock: "Under P31 an Element's Techniques come with the Element, so Mastery unlocks cosmetic and flex rewards only." | P6B-17 |
| M-52 | 607 | "Sparks can be earned by playing or bought directly with Robux ... instant Element or Technique unlocks ... bought with Robux directly" | Robux buys Sparks packs only (`EconomyConfig.lua:58-70`); no direct Element or Technique product (`PlayerData.lua:44-47`) | OWNER DECISION (OD-5). As built: "...What Prisms used to buy is bought with Sparks; Robux buys Sparks packs (no direct Element purchase is built yet)." | P2-18 |
| M-53 | 613 | Currencies row "Mana Shards ... Round wins/losses ... Attunement Phase" | Not built; the diary says it will be in-match points, not Mana Shards (`Dev_Diary.md:1459-1463, 1531, 1545`) | "**In-match points** *(planned, not built; replaces Mana Shards per the Dev Diary 2026-10-06)* · Soft, in-match only · earned in-round (damage dealt and round results, with a catch-up bonus: proposed) · Attunement Phase side-grade upgrades" | P6B-17 |
| M-54 | 614, 618 | Sparks "Earned via Match completion, dailies, Contracts"; Sources "match completion, daily login, weekly Contracts, party-queue bonus" | Only a finished team match pays: win 150, loss 50, draw 75, +10 per round won (placeholders, `EconomyConfig.lua:50-56`; `DuelMatch.lua:274-298`; a forfeit before 2 settled rounds pays nobody since the 2026-10-19 fix). Pad duels and Solo Test pay 0 | Sparks row: "Team matches (win 150, loss 50, draw 75, +10 a round won: placeholders), or bought as Sparks packs. *(Dailies, Contracts and the party bonus are not built.)*" Sources line: same, with "*(not built yet)*" after daily login, Contracts and party-queue bonus. | P6B-07, P2-18 |

### Section 7 — Cosmetics

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-55 | 631-632, 636 | Rarity ladder for Wraps: "the same stacking logic (particle richness at Rare, icon/health-bar reskin at Epic)"; Wrap Mythic "a particle/aura or trail effect added around the player's existing, unchanged avatar" | Owner ruling 2026-10-18 (diary `:1633`): Uncommon flat recolour; Rare gradient and material plus richer animated particles; Epic glow, slow pulse, shimmer motes (model: Sakura Frost); Mythic all of that plus a flowing or ambient treatment (model: Aurora); no wrap carries a kill effect, an avatar aura or any HUD change | Replace the Wraps paragraph's tier clause with: "**Wrap tiers (ruled 2026-10-18):** Uncommon is a flat recolour at the Default's particle count; Rare adds a gradient and material pass and richer, animated particles; Epic adds a luminous glow, a slow brightness pulse and shimmer motes; Mythic adds a signature flowing or ambient treatment. A Wrap never changes geometry and never carries a kill effect, an avatar aura, or any HUD change: icons, health-bar accents, kill effects and avatars belong to Element Skins." | OD-8 |
| M-56 | 646-652 | Devil: "HUD set ... Status words: Blessed! becomes PACTED! ..." | Not built (OD-9); the six ability models are built and in the game (diary 2026-10-13) | OWNER DECISION (OD-9). If not building now, add after `:649`: "*(v0.25: the kit's six forms are built and in the game since 2026-10-13. The HUD set and the PACTED! / DENIED! / VOIDED! words below are designed, not built; a build prompt exists, `Opus5_Radiant_DevilSkin_HUD_Reskin.md`.)*" | P6B-18 |
| M-57 | 644 (after) | Only Devil is described | Built Element Skins: Radiant Devil; Cryo Frostblade, Snow Globe (Rare), Frost Lotus (Epic), Frost Dragon (Mythic, in build). Wraps: Cryo Mint Rime, Deep Glacier (Uncommon), Black Ice (Rare), Sakura Frost (Epic), Aurora (Mythic, not yet offered); Toxin Nightshade, Coral Snake (Uncommon), Poison Dart Frog (Rare), Blue-Ringed Octopus (Epic, in review); untiered Pyro Azure Flame, Terra Obsidian Magma, Radiant Rainbow (`SkinCatalog.lua:80-337, 432, 457-458`) | Add a short "**Built so far (v0.25)**" list with these names and tiers. | P5A-23 |
| M-58 | 655 | "A skin never changes damage, timings, hitboxes, Mana, cooldowns or effect intensity" | Some wraps and skins change shot width/opacity and zone density (P5A-18, P5A-05) | P5A-05 was fixed in code in wave 1 (G6): Frost Dragon's Blizzard wall keeps the Default's density except a 15° pocket in front of each dragon. Optional note to record it: "A skin's set pieces may open a small local pocket in a zone's wall; the wall otherwise hides bodies exactly as the Default's does." P5A-18 is OWNER DECISION (OD-7). Either keep the rule and cap a wrap's shard width at the Default (code, G4), or add: "**Exception (v0.25):** an Element Skin (a Rework), and the Sakura Frost, Aurora and Black Ice wraps, may change how the Icicle Shard is drawn, its width and opacity included. Its hitbox and speed never change." | P5A-18, P5A-05, P5A-09 |
| M-59 | 659 | "Equipped in the Loadout. A SKINS section laid out like WRAPS is planned. It is not built; for now Devil is switched on for testing outside the Loadout." | Built 2026-10-13: a SKINS card and page in the Loadout, one skin per Element (attribute `ElementSkin_<Element>`, `SkinCatalog.lua:425-443`); colour wraps can be worn over a skin (2026-10-14) | "**Equipped in the Loadout.** A skin is chosen once per Element on the Loadout's SKINS page (built 2026-10-13); a colour wrap can be worn over a skin." | P6B-18 notes |
| M-60 | 661, 712 | Technique reskins: "a loadout can carry a Technique from a different Element ... retint a borrowed Technique" | No borrowed Techniques under P31 | Append to both: "*(Applies only if the shared pool is switched back on, P31. Under P31 a Technique is always your own Element's, so its look follows that Element's skin and wrap.)*" | P6B-01 |
| M-61 | 664 | Trading, 3-day hold, Attunement License | Not built | Append "*(not built yet)*" | P6B-17 |
| M-62 | 673 | Basic kill effect: "the **KO!** callout — red lettering on a white jagged burst ... the exit pops the body away in a puff of ink" | `DeathFX.client.lua:14-18`: one plain white burst over the body for 0.45 s, no word, no exit beat; it does not read Reduce Flashing | Append "*(v0.25: built so far as a plain white burst for 0.45 s; the KO! word, the exit beat and the Reduce Flashing rule are not built yet.)*" | P6B-10, P6B-19 |
| M-63 | 683, 685 | "kill effects stay on and around the body" | Frost Dragon kill effect sweeps a dragon ~5x the victim's height through the arena (`IceMagic/FrostDragonKillFX.lua:31, 215-222`) | Fixed in code in wave 1 (G6, P5A-21): the swooping dragon and its crescent beams draw only on the killer's and the victim's screens, and everyone else sees the statue, its break and the frost ring on the body. Optional note under `:683` and `:797`: "*(Frost Dragon's swoop is the one effect that leaves the body. It is drawn only for the killer and the victim, so a live fight never sees it.)*" | P5A-21, P5A-23 |

### Sections 8, 9, 11, 13, 15

| ID | Line | Current | Shipped code | Replace with / decision | Findings |
|---|---|---|---|---|---|
| M-64 | 698-699 | Wrap Epic "+ ability icons and health-bar accent reskinned"; Wrap Mythic "+ an aura/trail effect on the player's existing avatar" | Ruling 2026-10-18 (OD-8) | Epic: "+ luminous glow, slow pulse and shimmer motes". Mythic: "+ a signature flowing or ambient treatment of the effects (never an avatar aura)". | OD-8 |
| M-65 | 705 | Elemental Cache "Drops **Wraps** only ... Element Skins never appear" | The shop's `Catalog.lua` is a placeholder demo: its Cache says "1 random Skin or Tint" with a Common rarity (`StarterGui/SpellshotShop/Catalog.lua:45-47`); no Cache is wired | No manual change (the shop data is the stale side: code finding P2-18 / P6B-08, G4). Optionally append "*(not built: the shop's catalog is placeholder data)*". | P2-18 |
| M-66 | 710-711 | Element unlock and Technique unlock, Robux or Sparks; Technique free at Mastery 3 | Elements: Sparks only, no direct Robux product. Techniques: come with the Element (P31) | Element unlock: "Sparks (1600-2000, placeholders) ... *direct Robux unlock not built*". Technique unlock row: "*Not applicable under P31: Techniques come with their Element.*" | P2-18, P6B-01 |
| M-67 | 729 | "Daily: login streak ..., 2–3 daily Contracts" | Not built | Append "*(not built yet)*" | P6B-17 |
| M-68 | 731-732 | "1–2 new standalone Techniques added to the pool"; "seeds new Technique pool entries" | Under P31 a new Technique belongs to one Element | "...1–2 new Techniques, each for one Element's kit (P31)..." and "A new Element brings its own Techniques." | P6B-01 |
| M-69 | 749 | "Starter set of 3 Elements (Pyro/Terra/Radiant) ... plus one starter Technique (Bulwark Wall) ... 8 Elements and 12 Techniques" | Starter kit of 5 (OD-5) | "Starter set of 5 Elements (Pyro, Zephyr, Cryo, Terra, Radiant), each with its own Ultimate and two Techniques, so a new player's first matches use a complete kit instead of all 9 Elements at once." | P2-18, P6B-07 |
| M-70 | 792-794 | Risks rows about "Cross-Element loadouts", "Cross-Element visual mixing", "A damage-only Element contributing nothing" | P31 | Append to each: "*(dormant while P31 keeps Techniques with their own Element)*" | P6B-01 |
| M-71 | 797 | "Bodies have no hitbox and clear after about 3 seconds" | Not built (OD-6) | Append "*(not built yet, see Section 3)*" | P6B-10 |

### Appendix (lines 802-831)

| ID | Line | Current | Shipped code | Replace with |
|---|---|---|---|---|
| M-72 | 804 | "Base HP: 100" | 150 (`SpellshotConfig.lua:38`) | "Base HP: 150" (OD-3) |
| M-73 | 809 | "Match format: Best of 9 (first to 5)" | + team match, round clock and (wave 1) the MaxRounds cap | "Match format: first to 5 round wins (pad duel 1v1; Quick Play team match 3v3); a 90 s round clock settles a round on the larger share of health left; after 15 rounds played, more round wins takes the match, equal wins draw (proposed, `Config.Duel.MaxRounds`, M-89)" |
| M-74 | 810 | "slide up to 1.1 s with a 1.2 s cooldown; slide-jump +20 studs/s" | `SpellshotConfig.lua:61` SlideDuration 1.6; `:68-69` no cooldown, 0.1 s between slides; `:93-95` slide-jump +22, held between 42 and 52 studs/s (2026-10-17 balance pass) | "Movement: automatic sprint 25 studs/s, crouch 8; slide up to 1.6 s, no cooldown (0.1 s from one slide's end to the next); slide-jump +22 studs/s, never below 42 or above 52; one double jump; wall run up to 1.4 s at 30 studs/s" |
| M-75 | after 810 | — | `SpellshotConfig.lua:257-268` | Add: "Hitboxes: 2x each body part's size in every direction (head included). M1 projectiles: 200 studs/s for every Element (Chain Bolt and Light Lance are hitscan)" |
| M-76 | 814 | "Loadout: 1 Element ... + up to 3 Techniques from one shared, uncategorized pool" | P31 | "Loadout: 1 Element (M1 + Primary Ability + Passive + Ultimate, all fixed) + its 2 Techniques (one in Q, one in E)" |
| M-77 | 815 | "Technique pool at launch: 12 total (2 each from Cryo, Terra, Zephyr, Umbra, Radiant, Toxin; 0 from Pyro and Voltaic)" | 20 rows, 2 per Element (Pyro 4, OD-2) | "Techniques: 2 per Element, 18 across the 9 Elements (Pyro's retired Heat Rush and Cinder Shield: OD-2)" |
| M-78 | 816 | "Technique unlock: free at Mastery rank 3 ..." | P31 | "Technique unlock: none, a Technique comes with its Element" |
| M-79 | 817 | "Starter loadout: 3 Elements ... + 1 starter Technique (Bulwark Wall)" | `EconomyConfig.lua:30` | "Starter kit: 5 Elements (Pyro, Zephyr, Cryo, Terra, Radiant), owned from the first join" |
| M-80 | 818 | "Full roster unlock (8 Elements + 12 Techniques): by account level ~20 and Element Mastery, or earlier via Sparks or Robux" | `EconomyConfig.lua:35-41` | "Full roster: the 4 other Elements for Sparks (Aqua 1600, Toxin 1800, Umbra 2000, Voltaic 2000: placeholders), about 8-10 team-match wins each; Sparks packs for Robux skip the wait" |
| M-81 | 819 | "Persistent currency: Sparks only (earned by playing, or at round end)" | Paid once at a team match's end | "Persistent currency: Sparks only (paid at the end of a team match: win 150, loss 50, draw 75, +10 a round won, placeholders)" |
| M-82 | 820 | "Ragdoll: every elimination; no hitbox; body clears after ~3 s or at round end" | Not built (OD-6) | Append "*(not built yet)*" |
| M-83 | 823 | "Gust Jump: 2 air jumps a cast ... 7 s cooldown from landing" | Retired 2026-10-06; Skyrider FlySpeed 60 / boost 75 studs/s, drains Mana while ridden (`IceMagic/ZephyrSkyrider.lua:105-106`) | "Skyrider: ride a wind bird, 60 studs/s along the look (75 boosted), Mana drains while riding; its cooldown starts when you get off. Gust Pad: see `VFXLibrary` / `ZephyrGustPad` tuning" |
| M-84 | 825 | "Shadow Dart: ... 240 studs/s, range 160" | `IceMagic/UmbraTuning.lua:23`: 200 (one M1 speed since 2026-10-17) | "... 200 studs/s, range 160" |
| M-85 | 827 | "Shadow Step: ... 10 s cooldown, 20 Mana" | + dive reward and escape charge (`UmbraTuning.lua:58-69`); refused while rooted (GC-07, wave 2) | Append: "; 5 s cooldown instead when cast within 2 s of a landed hit (or a hit lands within 2 s after); a second escape charge on the same key, 6 s cooldown; refused, unpaid, while rooted, caged, Deep-Frozen or Entombed" |
| M-86 | 831 | "Ring of Fire: radius 25 studs ... (the Heat-scaling variant — radius 30 at high Heat — no longer applies, since Heat is retired)" | `IceMagic/PyroFX.lua:110-134`: Radius 17.5 since 2026-10-05; 55 damage; at high Heat 21 studs and 75 damage | "Ring of Fire: radius 17.5 studs; 55 damage; press to eruption ~0.93 s; central column ~35 studs tall" + OD-2: either "(Heat retired: no hot variant)" with the code change, or "(at high Heat, from Heat Rush: 21 studs, 75 damage)" |
| M-87 | after 831 | — | Voltaic and Cryo numbers that changed | Add: "Chain Bolt: hitscan to 55 studs, 10 damage, chain 5 to a body within 16 (2026-10-18, handoff #7). Flash Freeze and Blizzard: cast at the crosshair, up to 20 studs away (2026-10-18, P29). Blizzard: radius 32, 6 s." |

---

## 2. Dev Diary — `docs/SPELLSHOT_Dev_Diary.md`

### Corrections to existing entries

| ID | Line | Current | Fact | Note to add (ready to paste, directly under the line) | Findings |
|---|---|---|---|---|---|
| D-01 | 198-202 | "**Manual updated to v0.16 and delivered.** ... Voltaic's Ultimate table entry now reads Cascade" | The repo's manual has v0.16 = the Umbra rework (manual `:113`) and still says Thunderclap (`:247`). This edit went to a copy that later forked, and was lost. | `*(Correction, 2026-10-19: this edit is not in the manual the project uses now. Its v0.16 is the Umbra rework and its Voltaic row still says Thunderclap. Ported in the 2026-10-19 doc errata for v0.25.)*` | P6B-04 |
| D-02 | 219-223 | "Wrote both into the manual as confirmed mechanics — bumped to **v0.17**: Antitoxin Vent ... cleanse ... stays own-poison-only ... Acid Rain now a hybrid" | Same: the repo manual's v0.17 is Umbra's VFX direction (`:124`); Acid Rain is still "proposed default" there (`:271, 348`) and the Vent flag still open (`:347`). The code follows this entry (Acid Rain `TickDamage = 6`), and the Vent changed again on 2026-10-17 (30% off every DoT, no longer own-poison-only). | `*(Correction, 2026-10-19: these two edits are not in the manual the project uses now, whose v0.17 is Umbra's VFX direction. Ported in the 2026-10-19 doc errata for v0.25. The "own-poison-only" ruling was reversed on 2026-10-17: the Vent now also cuts every DoT tick 30%.)*` | P6B-04, P6B-09 |
| D-03 | 1639 | "Open: Studio checks (...), team size decision." | `Config.Team.Size = 3` shipped the same day (`SpellshotConfig.lua:244-246`) | Covered by entry E3 below ("team size 3, the knob is `Config.Team.Size`"). No inline edit needed. | P6B-06 |

### Ready-to-paste entries (append at the bottom, in this order)

These are backfills. They were written on 2026-10-19 from the code's own comments in the cloud snapshot. The owner's
words are quoted only where the code quotes them, and the documents the code cites
(`CHANGES_2026-10-17_balance_pass.md`, handoffs #7 and #8, the Problem Sheet with P27/P29/P31, the 3v3 sim) are not in
the repo, so their reasoning is not reproduced. The last two entries (E6, the rules the fix waves changed; E7, the
server movement guard) are not backfills. They come from the wave-1 fix logs and the wave-2 brief. In order, the
entries are: E1 (2026-10-17 balance pass), E2 (P31), E3 (team mode and economy), E4 (cloud copy and audit), E5 (audit
fixes), E6 (fix-wave rules) and E7 (movement guard).

```markdown
## 2026-10-17 — Balance pass, Elemental Reactions built, bigger hitboxes, one M1 speed (backfill)

(Backfill written 2026-10-19 from the code comments; the balance pass's own changelog,
`CHANGES_2026-10-17_balance_pass.md`, is cited by the code but is not in the cloud repo.)

**Balance pass.** Values the code marks "until the 2026-10-17 balance pass": slide-jump boost 32 / 56 / 70 -> 22 / 42 / 52
("the shared chase chain ran ~59 studs/s, so whoever chased always caught up"); a 90 s round clock for duels (the larger
share of health left takes the round, equal shares draw); Blizzard 8 -> 6 s and its slow cap 14 -> 11; Deep Freeze root
2.5 -> 1.5 s; Mirror Cage volley 1.6 -> 0.77 s (root 3.13 -> 2.30 s); Scorching Lash cooldown 2.5 -> 5 and its burn 1.6
-> 1.0 per stack; Poisoned tick 4 -> 6; a Charged discharge with nobody else near (every 1v1) 0 -> 7; Acid Rain tick 4 -> 6; Twin Tide
crush half-width 3.5 -> 5 and Mana 40 -> 30; Sidearm bullet 6 -> 4 Mana; Undertow reach 30 -> 36; Benediction channel
cap 30 -> 8 s (at most ~120 HP a cast); Skyrider 42 / 55 -> 60 / 75 studs/s; every dash's slow cut-off 12 -> 16
(Overcharge, Bulwark Charge, Cross-Slash, Frost Slide's old dash).

**The owner's picks that day.** Ember Refund now fires when a Pyro hit drops an enemy under 30% health (it fired on a
kill, which ends a duel round, so it never paid out). Voltaic's Passive, Chain Reaction, now takes 2 s off Overcharge
each time Charged fills on a target (same reason). Antitoxin Vent now also cuts every DoT tick on the masked Toxin by
30% ("before, the Vent did nothing against a non-Toxin"); this reverses the 2026-09-26 "own poison only" ruling.

**One M1 speed.** Every M1 projectile flies at 200 studs/s (the owner: "charge times may differ, speed should not"):
Icicle Shard, Fireball, Toxic Bubbles, Riptide, Boulder Shot (both charges), Wind Blade, Shadow Dart. Chain Bolt and
Light Lance stay hitscan.

**Bigger hitboxes.** ServerScriptService.HitboxScale gives every body part of every character and dummy an invisible
twin (the owner: "increase the hitbox of the characters by 30% (increase for dummies too so i can test)"): 1.3x first,
2.0x later the same day ("i think this would get us around rivals"). The head's twin counts as the head for Mark.

**Elemental Reactions built** (ServerScriptService.ElementalReactions, on the owner's "implement the reactions in game,
like usable"): Melt, Combustion, Overload, Shatter (a flat bonus now), Frozen, Wildfire, Windchill, Storm Surge, Toxic
Squall; Dust Storm and Windswept are built but dormant (nothing applies Cracked or Wet). Decided in code: a teammate's
status reacts exactly as your own. Numbers are provisional; `ReactionsOff` on ReplicatedStorage.Spellshot turns them
all off.

**Open/unresolved:** the design manual records none of this (doc errata 2026-10-19); the balance-pass changelog should
be copied into `docs/`; Cracked and Wet have no source.

## 2026-10-18 — P31: Techniques swap within your own Element only (backfill)

(Backfill written 2026-10-19 from SpellshotConfig's comment; the Problem Sheet that numbers it P31 is not in the repo.)

The owner: Techniques swap within your own Element only, never across. `Config.TechniquesOwnElementOnly = true`
(ReplicatedStorage.Spellshot.SpellshotConfig): a Technique belongs to its Origin Element alone, so Bulwark Wall, Twin
Tide or any other can never leave home. Every loadout path asks the one function `Config.ElementMayHold`: the Loadout
menu's rows, the server's LoadoutRequest, the dev panel, TechniquesFor on an Element change, and VFXLibrary.AbilityFor
at cast time. Setting the flag to false puts the shared pool back, where an Exclusive Technique (Detonate, Twin Tide,
Sidearm) still stays with its Origin.

Consequences: two Technique slots (Q/E), each Element with its own pair. Under P31 Pyro's rows Heat Rush and Cinder
Shield (retired in manual v0.7 but never removed from the code) are selectable by a Pyro again, so Pyro has four
(audit P6B-02, the owner's call). In a 1v1, reactions now come only from statuses your own kit applies.

**Open/unresolved:** the manual, README and HANDOFF still describe a shared pool of "up to 3" (doc errata 2026-10-19);
whether Pyro keeps Heat Rush and Cinder Shield.

## 2026-10-18 — Team mode (3v3), economy, movement switch, P29, handoffs #7 and #8 (backfill)

(Backfill written 2026-10-19 from the code comments; handoffs #7/#8, the 3v3 sim and the team-mode documents reviewed in
the previous entry are not in the cloud repo.)

**Team mode.** The owner: "Team-comp only: one mode, one ruleset; drop 1v1 Duel as a parallel mode", scoped that day to
"3v3s on the duel loop but only in menu, ignore hub". Quick Play's DUEL card queues two teams of `Config.Team.Size` (3)
and DuelMatch runs them on the duel's loop: first to 5, a 90 s clock on the team's summed health share, nobody comes
back mid-round (HubServer took over Roblox's respawns: `Players.RespawnTime = 1e6`), Ultimate charge carries round to
round, a leaver leaves the team short-handed, a team with nobody left forfeits. `MatchTeam` ("A"/"B") keeps teammates
from hurting each other (`Config.MayHurt`); Gust Pad leaves teammates alone. The Hub's duel pads still start a 1v1.
Squad Clash and Convergence are on the Quick Play screen but cannot start.

**Economy** (owner, locked; the amounts are placeholders). Sparks is the one currency; the 9 Elements are bought with it.
Starter kit from the first join: Pyro, Zephyr, Cryo, Terra, Radiant. Prices: Aqua 1600, Toxin 1800, Umbra 2000,
Voltaic 2000. A finished team match pays win 150 / loss 50 / draw 75, +10 a round won; a pad duel pays nothing. Robux
buys Sparks packs (Developer Product ids still 0, so not on sale). Skins and wraps stay Robux-only by intent, but
`SkinCatalog.OwnsSkin` still returns true for every cosmetic. ServerScriptService.PlayerData keeps the save
(EconomyService starts it).

**Movement switch.** The owner: "switch only, keep full, but keep jumping by default, one jump only". `Config.Movement.Mode`
"Full" (default) or "RunningOnly" (run, crouch, one ground jump); a dev switches it live with the workspace attribute
`MovementMode`. Review fix the same day: `RunningOnlyTouchCrouch = false`, and hiding the touch crouch button drops a
Toggle Crouch latch (TouchBus "CrouchClear").

**P29.** Flash Freeze and Blizzard land where the crosshair points, at most 20 studs away (the owner picked 20, "the
range that left Terra alone in the 3v3 sim"); 0 puts them back at the caster's feet.

**Handoff #7 (Voltaic).** Chain Bolt range 30 -> 55 and damage 8 -> 10 ("the values the 3v3 sim validated -- Voltaic
42 -> 50%").

**Handoff #8 (Umbra).** Shadow Step's dive reward (the 3v3 sim's P27 "half cooldown"): 5 s cooldown instead of 10 when
cast within 2 s of landing a hit, or when a hit lands within 2 s after. Escape charge (the owner: "same key, second
charge"): a second, independent 6 s charge on the same key. Review fix: a press made while a step is still dissolving
is queued once and stepped from the new spot; a third press, or a queued press at the end, is given back.

**Backups.** `ServerStorage.MovementSwitchReviewFix_2026_10_18` and `ServerStorage.UmbraReviewFix_2026_10_18` hold the
copies from BEFORE the review fixes (the live scripts carry the fixes). `ServerStorage._superseded_everfrost_2026_10_14`
is an unused Chill bar look for the dropped Everfrost skin.

**Open/unresolved:** the manual's modes and economy sections (doc errata 2026-10-19); Squad Clash and Convergence
should be locked on the Quick Play screen until they have a loop; Sparks can only be earned with 6 players queued;
skin ownership is not enforced; the ServerStorage backup folders could be renamed `_before_..._2026_10_18`.

## 2026-10-18/19 — Cloud copy of the project and a deep bug audit

A read-only cloud copy of the place was set up (`athufg/spellshot-cloud`: every script under `game/`, the Explorer tree
in `game/manifest.json`, the docs, and `tools/refresh.ps1` to re-export from Studio). Cloud sessions cannot press Play,
so every finding is a static reading of the code.

**Audit** (`docs/build_prompts/SPELLSHOT_CLOUD_BUG_REPORT_2026-10-18.md`): six passes (server authority, economy and
saves, combat state, the cross-Element surface, skins/wraps/settings, dead code and doc drift) plus three gap-fill
reads. 297 entries, 253 distinct after merging: 15 High, 65 Medium, 173 Low. The three facts that change how to read
it: the cross-Element pool is off in code (P31); the ServerStorage "ReviewFix" folders are the before-copies; the
manifest does not record any script's Enabled/RunContext or `Workspace.SignalBehavior`, so a 30-second Studio check
settles several findings. The worst: shots and strikes could be fired from anywhere (origin checks scaled with the
client's own speed and ping), dev mode was live in public matches with a free Ultimate, the server enforces no
movement, the Training Ground was in the ranked map vote, the temporary stage scripts had no Studio gate, and a forfeit
paid the full win.

**Open/unresolved:** run the report's "Check these in Studio first" list.

## 2026-10-19 — Audit fixes applied in the cloud copy (not yet in Studio)

`docs/build_prompts/SPELLSHOT_CLOUD_FIXES_2026-10-19.md` lists them; each edit is marked `(2026-10-19, audit <ID>)` in
the code. Every changed script compiles under luau-compile and adds no new global. **Nothing has been run in Studio**;
the scripts must be copied across as one batch (`VoltaicClient` with the Voltaic handler, and VFXLibrary's Skyrider
row with ZephyrSkyriderServer, depend on each other).

What changed: shot and strike origin checks trust the client's speed only up to what the server saw the body move, and
cap ping at 0.3 s (P1-01); a dev's free Ultimate / Mana / cooldowns switch off in any match with a non-dev, and the
economy dev buttons work in Studio only (P1-02); Skyrider is prechecked, so a press the server would refuse is never
paid and cannot break Earthen Tomb (P4-01); the Training Ground is offered to Solo Test only (P1-04); Bulwark Wall now
stops Cross-Slash, Overcharge, Bulwark Charge, Skyrider and its Gust (P6A-05 and gap-fill C); an M1 must be paid by an
accepted CastRequest before it deals damage, and Chain Bolt sends its CastRequest first (P1-12); Colourblind-Safe paints
Decoy Doubles as their owner, Aqua has a palette row and only Terra and Toxin move (P5C-01, P5F-09/10); V (third person)
is dev-only (P5F-02); the four `_*Stage*` scripts run in Studio only (P1-05); the save lock is a per-session token and a
same-server rejoin waits for its leave save (P2-01/02/03); a live server never runs memory-only (P2-04); a forfeit
before 2 settled rounds pays nobody (P2-05); Snow Globe M1, Lotus and Globe shatters, half-built skins, the Frost Dragon
claw and the Snow Globe pines are fixed (P5A-02/03/06/07/08); the Devil skin falls back to the Default until its forged
forms exist (P5C-02); ZephyrDraw's local count is down to 197 (P5E-14).

Not fixed, on purpose: server-side movement validation (P1-03, needs a design pass and Play testing; a conservative
guard was built later the same day, see "Server movement guard" below); cosmetic ownership (P2-06: `OwnsSkin` stays
true until skins are sold); Earthen Tomb's escape rules (P4-02, P4-03: design).

A second wave (the audit's remaining Medium and Low findings, split across eight groups) followed the same day; the
next entry lists the rules it changed, and the doc errata (`SPELLSHOT_DOC_ERRATA_2026-10-19.md`) is its documentation
half.

**Open/unresolved:** the Studio checklist in the fixes file (shots, Chain Bolt, Bulwark Wall, Skyrider, dev accounts,
map vote, saves, Colourblind-Safe, Cryo skins, Devil skin, Zephyr lights); apply the doc errata to the manual (v0.25).

## 2026-10-19 — Audit fix waves 1 and 2: the rules they changed (cloud copy, not yet in Studio)

Wave 1 (commit `7615bc3`) worked through the audit's remaining Medium and Low findings in eight groups. Wave 2 applied
the cross-file handoffs between those groups and built the movement guard (next entry). Each edit is marked
`(2026-10-19, audit <ID>)`, and each wave's changed scripts are checked to compile. **Nothing has been run in
Studio.** Most edits fix bugs without changing a rule. The ones below change what a player sees or can do.

**Match rules (wave 1).**
- **A cap on rounds.** `Config.Duel.MaxRounds = 15` (a team match inherits it; 0 turns it off). After 15 rounds
  played, the side with more round wins takes the match, and equal wins are a draw: the banner says MATCH DRAWN and
  both sides get the draw reward. Before, two sides that never engaged drew every round and the match never ended.
  PROPOSED: the owner may prefer sudden death or a damage-dealt tiebreak (P3-13).
- **Same-frame deaths are a draw.** CombatCore stamps each death with the server frame it happened in
  (`Core.FrameClock`). Deaths in one frame count as simultaneous, so a burst that drops the last player of both sides
  gives "DRAW -- NO POINT". A trade a frame apart still has a winner (P3-15).
- **The result screen is not a fifth round.** From the result to the trip home (`MatchEndHold`, 4 s) everyone is
  CastLocked, and the dead stay down (`DuelMatch.Holds`) and are rebuilt in the Hub, not in the Arena (P3-14).
- **Leaving clears a player.** When a player leaves the game, `Core.ClearPlayer(player, "left")` runs every kit's
  clear, and DuelMatch drops their `DuelMatch` / `MatchTeam`. Nothing they cast (a Ring of Fire, a Twin Tide, a Flash
  Freeze) lands after they are gone, and `Config.MayHurt` refuses them (P3-07).
- **RunningOnly is enforced by the server.** In RunningOnly a Slide request is treated as a Crouch (8 studs/s), so a
  modified client can no longer slide in that mode (P6A-04).
- Casts are rate-limited per player (20 a second, bursts of 30; releases and aim steers are not counted), and a Toxin
  can have one Patient Zero at a time (P1-07, P1-08).

**Calls made for wave 2 by the fix waves' coordinator (the owner may reverse them).**
- **Roots beat Shadow Step (GC-07).** A rooted, caged, Deep-Frozen or Entombed Umbra cannot start a Shadow Step. The
  press is refused before it is paid, like Skyrider's precheck. Before, a step out of an Earthen Tomb was pulled
  straight back and the charge was spent for nothing.
- **Skyrider's gust gets no Updraft (P5E-10).** Its hit carries `NoUpdraft = true`. A rider is always airborne, so the
  bonus was a flat, hidden +25%, and the kit's own comment says Updraft is not a gust's.
- **Ring of Fire's text (P4-11).** Its Desc now says the hotter version needs Heat built with Heat Rush. This is text
  only: whether Pyro keeps Heat Rush at all is still the owner's call (P6B-02).

**Other changes a player would notice (wave 1).**
- Updraft no longer counts air another player threw you into: a knock, a launch, an enemy Cyclone or an Earthen Tomb
  (`KnockedUntil`, `RX_Entombed`). Your own jump and your own Gust Pad still count (P4-04).
- Gust Pad never launches a player the caster may not hurt: a teammate, or a stranger in a Solo Test (P1-14).
- Position Trade aimed at an enemy's Decoy Double is paid, moves nobody, and breaks the decoy with its Tell, as a hit
  does (P5C-05).
- Flash Freeze's end shatter lands only on a body still held by that zone's root. A Melt or Shatter that broke the
  root, or a Position Trade that moved the body out, means no shatter (P3-04). A reaction that breaks a Mirror Cage or
  Deep Freeze root now also frees the body from the cage or prison on every screen (P3-05).
- No reaction fires on the caster's own body, for example a Burning Toxin inside its own Patient Zero burst (P3-10).
- Ember Refund's 30% line is judged on the health the hit itself left, not after a reaction bonus from the same hit
  (P3-01).
- Frost Dragon: the Blizzard wall keeps the Default's density except a 15° pocket in front of each dragon (P5A-05),
  and the kill effect's swooping dragon is drawn only for the killer and the victim (P5A-21).
- The Chill bar's words read CHILLED! / SLOWED!, not FROZEN! / ROOTED!, since the third stack has not rooted since
  2026-10-08 (GA-01).

**Still the owner's (written up as DESIGN in the fix logs):** Pyro's four Techniques (P6B-02); the MaxRounds tiebreak
(P3-13); whether Ultimate charge counts damage to walls and decoys, and your own poison (P3-09); whether a hit a
shield fully soaks still sets off a reaction (P3-10); area hits widened by the 2x hitbox twins (P3-16); whether an
ally's reaction may break your own Ultimate's root (P3-05); Earthen Tomb's escape rules, Skyrider included (P4-02,
P4-03); whether locks may pick a Decoy Double (P4-12); the skin-intensity exception for Cryo wraps (P5A-18); cosmetic
ownership (P2-06).

**Open/unresolved:** copy the changed scripts into Studio as one batch and run each fix log's Studio checks; apply the
doc errata.

## 2026-10-19 — Server movement guard (P1-03; cloud copy, not yet in Studio)

The audit's P1-03: the server never checked movement, so a modified client could teleport, outrun every legal speed,
or walk out of a root, a Mirror Cage, a Deep Freeze prison or an Earthen Tomb. Wave 2 built a guard that is
conservative on purpose: nothing may rubber-band an honest player. *(Errata note, not for pasting: this entry was
written from the wave-2 spec while CombatCore's half was still being built. Check the names and numbers against
`CombatCore.lua` and `SpellshotConfig.lua` before pasting it.)*

**The guard** (CombatCore, every Heartbeat). It watches player characters only, never dummies, and only while they are
alive. It is tuned by `Config.MovementGuard` in SpellshotConfig: `{ Enabled = true, Enforce = true, BaseSpeed = 90,
FastSpeed = 170, FastAfterCast = 1.5, MinStep = 10, Grace = 1.0 }`. For each body it keeps the last distinct root
position and the moment it was first seen there. When the body moves, the flat (XZ) distance over the time since then
gives a speed. Height is ignored, so falls and launches never count. The ceiling is FastSpeed (170 studs/s) while the
body is in a fast state, and BaseSpeed (90) otherwise. A fast state is any of these: riding Skyrider (`SkyriderT0`),
knocked (`KnockedUntil`), holding a held ability (any `Holding_*`), or within 1.5 s of an accepted cast (`CastAt`,
which SpellshotService now stamps on every accepted non-M1 cast). A move longer than MinStep (10 studs) at more than
the ceiling adds to `ShotStats.move_snap`. With Enforce on, the body is also put back where it was, facing the same
way. With Enforce = false the guard only counts. A new body (a respawn) starts with no history. For scale, the fastest
legal run is a slide-jump chain at 52 studs/s, and Skyrider boosts at 75 and Cross-Slash glides at about 110, both
inside FastSpeed.

**Moves the server makes.** `Core.AllowMove(model, seconds)` gives a body a grace window (Grace, 1 s, by default) in
which the guard ignores it. It is called before every move the server makes itself: Hub teleports and respawn
placement (1.5 s), Position Trade (both bodies), Shadow Step, and Earthen Tomb's own moves.

**Holds.** `Core.HoldBody(model, key, on)` is a counted hold per body and reason. While any hold is on for a player's
body, the server owns its physics (network owner nil), so the client cannot walk out of it. There are three holds:
"CryoRoot" (any slow cap of 0: Flash Freeze, a Deep Freeze prison, Mirror Cage, Frozen), "Tomb" (Earthen Tomb's lift)
and "Cyclone" (bodies a Cyclone has caught). When the last hold ends, the player gets their physics back with a grace
window. Holds end with the body and when the player is cleared.

**To check in Studio and Play:** with 100-200 ms of emulated ping, play normally and watch `ShotStats.move_snap`:
sprints, slide-jump chains, Cross-Slash, Skyrider, Gust Pad launches, knocks, Hub teleports and respawns. It should
stay at 0. If it does not, set Enforce = false (count only) and raise the speeds before this ships. Then move your
own body from a client command bar: it should be put back. While rooted, try to walk: you should stay. Also watch
whether a held body stutters on other screens when its network owner changes.

**Open/unresolved:** every number is a first guess. Skyrider's altitude cap and a hover check (P5E-16, P5E-17) are
not part of this.
```

---

## 3. HANDOFF.md — `docs/HANDOFF.md` (2026-09-12)

### H-00. Banner (ready to paste as the new line 2, under the title)

```markdown
> **HISTORICAL (2026-09-12), superseded. Do not act on it.** Almost everything here has changed: 9 Elements (Aqua
> included), each with a fixed M1 / Primary / Passive / Ultimate and its own two Techniques (P31); Sparks is the only
> persistent currency; Cryo's kit is Icicle Shard, Flash Freeze, Cold Momentum, Blizzard, Deep Freeze and Mirror Cage;
> the Hub, team matches and the economy are built. Read README.md first, then the design manual for intent and the
> latest Dev Diary entries for what was built. Where this file and the code disagree, the code is what ships. Keep it
> for its process lessons (Section 6) only.
```

### Line notes (only needed if the file is kept current instead of bannered)

| ID | Line | Current | Fact |
|---|---|---|---|
| H-01 | 9 | "Art direction is pop-art comic" | Ability VFX moved off comic in manual v0.9/v0.10; comic stays for UI/HUD and callouts |
| H-02 | 11, 48 | "the single source of truth ... trust the manual" | README: "If the code and the manual disagree, the code is what ships" |
| H-03 | 17 | "up to 3 freely-mixed Techniques (1 Mobility, 1 Defense, 1 Ultimate) drawn from shared pools of 8 each" | Ultimate fixed per Element (v0.7); two Techniques of your own Element (P31) |
| H-04 | 18 | "8 launch Elements" | 9 built, Aqua included (`SpellshotConfig.lua:678-695`) |
| H-05 | 19 | "Currencies: Mana Shards (in-match), Sparks (soft/persistent), Prisms (hard/Robux)" | Sparks only (Prisms dropped v0.3; Mana Shards not built) |
| H-06 | 20 | "Visual identity (Manual Section 16)" | The manual has no Section 16; the visual identity is in Section 0 |
| H-07 | 38, 113 | Cryo Ultimate "Cryo Beam"; kit Frost Slide / Chill Aura / Cryo Beam | Retired; Cryo is Blizzard, Deep Freeze, Mirror Cage (`VFXLibrary.lua:242-245`) |
| H-08 | 45-68 | 13 `Opus5_*` prompts listed | None of the 13 is in `docs/build_prompts/` |
| H-09 | 96 | "Sound effects feasibility was never confirmed" | An SFX plan exists (`docs/SPELLSHOT_SFX_Plan_CoreCombat.md`) and volume settings are built |
| H-10 | 100 | "no build prompt has been written for the Hub/lobby yet" | The Hub is built (`ServerScriptService/HubServer.server.lua`) |
| H-11 | 101 | "Only Cryo has gone through the full kit-finalization" | All 9 kits are built |

---

## 4. README.md

| ID | Line | Current | Shipped code | Replace with | Findings |
|---|---|---|---|---|---|
| R-01 | 3 | "ranked match structure (Duel, 2v2, Squad Clash)" | Pad duel 1v1 and a 3v3 team match; no ranked, 2v2 or Squad Clash loop | "...match structure (a 3v3 team match and 1v1 pad duels in this build)" | P6B-06 |
| R-02 | 5-6 | "...fixes their M1, Primary Ability, Passive and Ultimate, and adds up to 3 Techniques from a shared pool" | P31, two slots | "...fixes their M1, Primary Ability, Passive and Ultimate, and brings two Techniques of its own (Techniques stay with their Element since 2026-10-18, P31)" | P6B-01 |
| R-03 | 17 | "`HANDOFF.md` (an old 2026-09-12 project handoff)" | — | "...(historical, 2026-09-12; superseded, do not act on it)" | P6B-16 |
| R-04 | 18 | "`docs/build_prompts/` — The build prompts each VFX kit was made from." | Also holds the audit, the fixes file and this errata; not every prompt is there (HANDOFF's 13 are not) | "The build prompts that reached the project folder (not all of them), plus the cloud audit, its fixes and the doc errata." | P6B-16 |
| R-05 | 25-29 | Problem Sheet and Implementation Handoff "not in this repo yet"; "the latest entries of the Dev Diary say what was built last" | The code cites the balance-pass changelog, handoffs #7/#8, the 3v3 sim and P27/P29/P31, none in the repo; until entries E1-E3 above are pasted, the diary does not record 2026-10-17/18 | Add: "Not in this repo either, though the code cites them: `CHANGES_2026-10-17_balance_pass.md`, handoffs #7 and #8, the 3v3 sim, and the Problem Sheet's P27, P29 and P31." | P6B-14 |

`sim/README.md` (not one of the four protected files, but refreshed): its "No balance or team simulation scripts were
found" is accurate; the code nonetheless cites "the 3v3 sim" (`VoltaicTuning.lua:29`, `UmbraTuning.lua:58`,
`CryoTuning.lua:20`). Add the sim's source path to `tools/sim_sources.txt` when it is found.

---

## 5. SFX plan — `docs/SPELLSHOT_SFX_Plan_CoreCombat.md`

| ID | Line | Current | Shipped code | Note |
|---|---|---|---|---|
| S-01 | 123 (§7, flag 1) | "No audio settings exist in the manual. Volume sliders (Master, SFX, UI) are needed" | The game has them: VolMaster, VolSFX, VolMusic, VolInterface and MuteUnfocused (`ReplicatedStorage/Spellshot/SpellshotSettings.lua:104-108`) | Still true of the manual. Append: "*(Built in the game's settings: Master, SFX, Music, Interface, Mute when unfocused. The manual still has no audio-settings line.)*" (P6B-19) |
| S-02 | 125 (§7, flag 3) | "HP is still open (100 in the manual, 150 in the build)" | `SpellshotConfig.lua:38`: 150 | Once OD-3 is settled at 150 (M-45, M-72), append: "*(Closed at 150 in manual v0.25.)*" The percentage tiers need no change. |

---

## 6. Index: audit finding to errata item

The four G8 work-list findings are marked **(G8)**. Every other finding here is another group's for its code half;
only its documentation half is covered.

| Finding | Errata items |
|---|---|
| P2-18 **(G8)** | OD-5, M-44, M-52, M-54, M-65, M-66, M-69, M-79-M-81 (code half: handoffs in the G8 log) |
| P5D-18 **(G8)** | OD-10, M-03, M-14 (Table A Voltaic row) (code half: handoffs in the G8 log) |
| P5E-20 **(G8)** | M-15 (Table B), M-18 (Table C), M-43, M-83 (code half: DeflectPractice handoff in the G8 log) |
| P6B-03 **(G8)** | M-13-M-15, M-18, M-19, M-21, M-22, M-24-M-26, M-31, M-33, M-35, M-39, Tables A-C |
| P6B-04 **(G8)** | M-00, M-27, M-28, D-01, D-02 |
| P6B-10 **(G8)** | OD-6, M-49a, M-62, M-71, M-82 (code half: HitboxScale handoff in the G8 log) |
| P6B-12 **(G8)** | M-45-M-47, M-72-M-87, S-02 |
| P6B-16 **(G8)** | H-00-H-11, R-03, R-04 |
| P6B-17 **(G8)** | M-09, M-10, M-48, M-51, M-53, M-54, M-61, M-67 |
| P6B-18 **(G8)** | OD-9, M-56, M-59 |
| P6B-20 **(G8)** | M-23, M-36 |
| P6A-20, P6A-22 **(G8)** | No documentation half (code text only): handoffs in the G8 log |
| P6B-01 | OD-1, M-02, M-04, M-06, M-11, M-12, M-16, M-20, M-29, M-30, M-60, M-68, M-70, M-76-M-78, R-02, H-03, E2 |
| P6B-02 | OD-2, M-17, M-21, M-86, Table B note |
| P6B-06 / P6A-19 | OD-4, M-05, M-07, M-50a, R-01, D-03, E3 |
| P6B-07 | OD-5, M-44, M-54, M-69 |
| P6B-08 / P2-06 | OD-5, M-65 |
| P6B-09 | M-27, D-02, E1 |
| P6B-11 / P3-24 | M-34, Table A (Pyro's Fireball, Cryo's Icicle Shard) (the code Desc strings are G1's) |
| P6B-13 | M-38-M-40, M-42, E1 |
| P6B-14 | M-08, M-32, R-05, E1-E5 |
| P6B-19 | M-50b, M-62, S-01 |
| P5A-18, P5A-05, P5A-09 | OD-7, M-58, E6 (P5A-05 fixed in code, wave 1) |
| P5A-21, P5A-23 | OD-7, M-57, M-63, E6 (P5A-21 fixed in code, wave 1) |
| P5E-04 / P3-18 / P1-14 (Gust Pad team rule) | Table B Gust Pad row, E6 |
| P4-14, P5F-20, P5E-19, GA-13 | Code comments and Desc strings only; no document half |

**Added from the fix waves** (the wave-1 logs' documentation handoffs and the wave-2 decisions; none of these was a G8
work-list finding):

| Finding | Errata items |
|---|---|
| P3-13 (MaxRounds, G1) | M-00, M-73, M-89, E6 |
| P3-14 (result screen CastLocked, G1) | M-00, M-89, E6 |
| P3-15 (same-frame deaths draw, G1) | M-00, M-88, E6 |
| P3-07 (leaving clears a player, G1) | M-00, M-88, E6 |
| P6A-04 (RunningOnly on the server, G1) | M-00, M-46, E6 |
| P1-07, P1-08 (cast rate limit, one Patient Zero) | E6 |
| P3-01 (Ember Refund's health test) | Table A Pyro row, E6 |
| P3-04, P3-05, P3-10, P5C-05, GA-01 | E6 (behaviour notes; no manual line changes) |
| GC-07 (roots beat Shadow Step; wave-2 decision) | M-00, M-32, M-85, Table A Umbra row, E6 |
| P5E-10 (Skyrider gust NoUpdraft; wave-2 decision), P4-04 (Updraft ignores thrown air) | M-00, M-90, Table A Zephyr row, E6 |
| P4-11 (Ring of Fire Desc; wave-2 decision) | OD-2 note, E6 |
| P1-03 (server movement guard, wave 2) | E5 note, E7 |
