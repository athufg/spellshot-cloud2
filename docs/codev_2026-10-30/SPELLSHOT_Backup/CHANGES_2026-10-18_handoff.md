# 2026-10-18: implementation handoff (Studio session)

This log covers the owner's "SPELLSHOT — Implementation Handoff (Studio session)". Every change was edited live in
Studio. Team Create keeps its own versions; I did no manual save and no publish.

Two more change logs cover the larger builds from the same handoff:
- `CHANGES_2026-10-18_team_mode.md`: P30, 3v3 from the menu on the duel loop;
- `CHANGES_2026-10-18_economy.md`: P32, Sparks, Element ownership, the starter 5 and Robux packs.

## Backup inside the place

`ServerStorage.HandoffSuperseded_2026_10_18` holds an untouched copy of every script this log changed:
- Scripts are disabled and children were not copied.
- Each copy has an `OriginalPath` attribute.

The copied scripts are SpellshotConfig, VFXLibrary, VoltaicClient, ChainBoltFX, AbilityHandler, AbilityFX, CryoWrap and
CryoTuning.

## A2: Techniques stay inside their own Element (P31)

| Where | Change |
|---|---|
| `Spellshot.SpellshotConfig` `ElementMayHold` | A Technique may be held only by its `Origin` Element. New switch: `Config.TechniquesOwnElementOnly = true`. |
| `IceMagic.VFXLibrary` `AbilityFor` | At cast time, a Technique slot holding another Element's Technique resolves to nothing. It asks `ElementMayHold`, and falls back to the old Exclusive check if the config has no such function. |

Every loadout path goes through `ElementMayHold`, so nothing else needed changing:
- the Loadout menu's two Technique rows;
- the server's LoadoutRequest (`MayEquip`);
- the dev panel's SetTechnique;
- `TechniquesFor` on an Element change;
- `AbilityFor` at cast time.

**Result:**
- Eight Elements now have exactly their own two Techniques.
- Pyro chooses 2 of its 4: Detonate, Heat Rush, Cinder Shield and Scorching Lash.
- An Element change always lands on the Element's defaults (`ElementDefaults`).
- I checked this on a fresh copy of the config: Cryo may not hold Bulwark Wall or Twin Tide, and Terra may hold Bulwark Wall.

No per-ability lock was added. That would be redundant, as the handoff says.

**To take it out:** set `Config.TechniquesOwnElementOnly = false`.

## A4: cursor-targeted Flash Freeze and Blizzard (P29), both at 20 studs

Both zones now land where the crosshair points, at most 20 studs from the caster, on the floor under that point.

| Where | Change |
|---|---|
| `VFXLibrary.Tuning.FlashFreeze.CastRange` | New, 20. 0 = round the caster's feet, as before |
| `CryoTuning.Blizzard.CastRange` | New, 20. 0 = where the caster stands, as before |
| `VFXLibrary` rows FlashFreeze and Blizzard | `Range` = the CastRange and `Targeted = true`, so the client sends its aim point (SpellshotInput's generic path) |
| `ServerScriptService.AbilityHandler` | New `cursorFloor(character, root, payload, range)` (described below). `castFlashFreeze` and `castBlizzard` now take `payload` and use it |
| `VFXLibrary.CastFlashFreeze` | New 4th argument `centerAt`: the server's centre. Without it (the capture stages), the zone is drawn at the caster as before |
| `StarterPlayerScripts.AbilityFX` | The FlashFreeze handler passes `d.Center`. The server already sent it, but every client used to recompute the centre from the caster's root |
| `IceMagic.CryoWrap` | The wrap's colour gradient for Flash Freeze is measured from the aimed centre |

**`cursorFloor`, step by step:**
1. It takes the aim point the client sent and clamps it to the range (`Core.ClampTarget`).
2. It finds the floor under that point through bodies (`VFXLibrary.GroundBelow`, at most 40 below the aim).
3. It returns nil when there is no aim or no floor (the sky, a drop), and the zone then stays where the caster stands.

Blizzard's broadcast already carried `Center`, and CryoFX already draws from it.

**Not converted, as the handoff says:** Deep Freeze, Aftershock and Benediction stay self-centred.

**Not done:** a ground preview of where the zone will land. Today the crosshair is the only aim cue.

## A5: the six "data bugs" (P23 finding 6 / recommendation #15), checked live today

| Item | Live now | Status |
|---|---|---|
| Boulder Shot: full charge flies slower | `MinSpeed 200`, `MaxSpeed 200` | Moot since 2026-10-17, when every M1 projectile moved to 200. It was intentional before that, per TerraFX's comment |
| Fireball range field vs flight | Row `Range 110`; flight `Speed 200 × Life 0.83 = 166` | Intentional: the row's Range is only the aim ray's reach (VFXLibrary's comment). No change |
| Undertow's two range fields | Row 36, AquaTuning `Range 36` / `Reach 36` | Fixed in the 2026-10-17 pass (30 → 36) |
| Stale `AbilityHandler` constant | `Tune.ShardChillWindow = 5.0` | Fixed in the 2026-10-17 pass (3.0 → 5.0); nothing reads it |
| Chain Bolt's unlogged range edit | **Canon = 30**: `VoltaicTuning.ChainBolt.Range` carries "(2026-10-13: was 10, too short)", and the VFXLibrary row says 30 | Recorded here. Today I also brought the two fallback copies up to 30: `VoltaicClient` FALLBACK and `ChainBoltFX` plumbing. Each only applies if VoltaicTuning is missing |
| Zephyr `DashDistance` | `ZephyrFX.Tuning.CrossSlash.DashDistance = 55` | Not stray: it is the glide's pace. SpellshotInput, AbilityFX, VFXLibrary, ZephyrFX, ZephyrFX_CrossSlash, DashMotor, AbilityHandler and ZephyrHandler all read it. Removing it would break Cross-Slash. No change |

## C: Studio checks (read-only)

**1. Twin Tide, live:**
- **Cast and shape:** one cast makes two walls, 24 long, 13 tall and 2 thick, either side of a lane centred on the aim point, up to 40 away.
- **Timing:** the walls close from 11 off centre to 3.55 by 1.1 s. A body-blocking collider stands from about 0.16 s to 1.1 s, about 0.94 s in all.
- **Stats:** no wall HP; 30 mana; 16 s cooldown; the crush does 35 (`AquaTuning.TwinTide`, `AquaFX`).
- This was already confirmed in the P28 results. The handoff's "unconfirmed" label is out of date.

**2. Bulwark Wall HP:**
- Every raise is a new server body with a new Humanoid at `WallHP` = 200 (`TerraHandler.raiseWall`). Damage never carries over.
- It also has no cooldown since 2026-09-20. It is held, and drains 20 mana/s.
- So a broken wall can be raised again at once, at full 200, as long as the bar lasts.
- The sim's "fresh 200 per deploy" assumption is correct.

**3. Do walls block bodies on the server?**
- **Bulwark Wall: yes, and shots too.** It is an anchored, CanCollide, CanQuery server part in workspace.
- **Twin Tide:**
  - It blocks bodies for every player. Every client builds its own collider (`AquaFX` `collider`, CanCollide true, CanQuery false) from the server broadcast, and each player's character is moved by their own client.
  - It does not block shots: the server never sees the walls.
  - So the P28 "standing Twin Tide" result needs a server wall body only for shot blocking. Body blocking already happens in play.
  - Anti-exploit caveat: the server can't stop a client that removes its own collider.

**4. Movement chain speed: measured in Play, 18 October.**
- **The run:** Play Solo on the Baseplate (z = 600 lane), W held. The cycle was slide (LeftControl, 0.32 s), slide-jump, double jump 0.35 s later, then land, about 1.27 s a cycle. A server Heartbeat log of the root.
- **Result:** the speed settles at **44.8 studs/s**. The first slide-jump peaks at 52–54, and the average over the whole 11.4 s chain is 45.6.
- So the 45 the sim has used since 2026-10-17 holds.
- **Cadence matters:** a faster cadence, which pressed slide again before landing, broke the chain. It fell to about 30, a run with jumps.
- The dashboard's shared-rules figure now reads "measured".

**5. Balance Sheet dashboard:** republished on the corrected 1v1 data.
- Both runs were re-run with the M1 timing fix: `sim_m1fix.py`, `sim_results_full_before_m1fix.json` and `sim_results_full_live_m1fix.json`.
- The duel-simulation section's note explains the correction.
- Best play, live, before → after the fix:

| Element | Before the fix | After the fix |
|---|---|---|
| Pyro | 91 | 91 |
| Terra | 84 | 79 |
| Zephyr | 16 | 62 |
| Umbra | 66 | 60 |
| Radiant | 66 | 52 |
| Cryo | 44 | 52 |
| Toxin | 46 | 31 |
| Voltaic | 32 | 23 |
| Aqua | 3 | 2 |

## Review fixes (two review workflows, 18 October)

The team-mode and economy builds were each reviewed read-only: three lenses, plus one skeptic per finding. Nine
findings were confirmed and three refuted. I fixed all nine. Each fixed line carries "(2026-10-18 review)".

| # | Where | Defect | Fix |
|---|---|---|---|
| 1 | `PlayerData` BindToClose | Didn't wait for a leave save already in flight, so the last player's progress could be cut off at shutdown and their session lock left held | New `releasing` set: leave saves and loads in flight register there, and BindToClose waits on them (25 s cap) |
| 2 | `PlayerData` onLeave / onJoin | A failed leave save was never retried (the profile had already left `profiles`) | `release()` retries at 1, 2, 4 and 8 s while the lock is still ours |
| 2b | `PlayerData.AwardMatch` | A match reward only reached the save at the next 60 s autosave | `saveSoon` straight after the award |
| 3 | `LoadoutMenu` | Before the save loaded (or when it failed), the 0 placeholder read as "NOT ENOUGH SPARKS" and pointed at the Robux packs | The confirm shows LOADING YOUR SAVE / SAVE UNAVAILABLE with a WAIT button; the menu refreshes on `DataLoaded` / `DataError` |
| 4 | `LoadoutMenu` | A late UNLOCK reply closed whichever confirm was open | Closes only the confirm for the Element it was sent for |
| 5 | `DuelMatch.drop` | If the winners left during the 2 s pause after the deciding round, the losers got a forfeit WIN and its Sparks | A settled round that brings the leaver's team to FirstTo now finishes the match for that team (`match.CountedRound`) |
| 6 | `SpellshotInput` + `AbilityFX` | Boulder Shot broke on teammates (its hit filter skipped `Config.AddUnhurtable`) | Same filter as every other shot |
| 7 | `VoltaicClient` | Volt Orb's aim arc landed on teammates the orb flies through | Arc uses `ownExclude` |
| 8 | `MapVote` | A called-off team vote blamed "your opponent" | Team wording |
| 9 | `HubServer` | A quick QUEUE then CANCEL was throttled away, leaving the player queued | CANCEL is never throttled |

**Refuted:**
- A NaN Sparks wipe can't be reached.
- Pad duels paying nothing is by design.

## Play test, 18 October (Play Solo)

| Check | Result |
|---|---|
| Join | `Sparks 0`, `OwnedElements Cryo,Pyro,Radiant,Terra,Zephyr`, `DataLoaded true`, Element Cryo (Q Blizzard, E Deep Freeze). No DataStore warning, so **Studio API access is on and Studio writes the real save** |
| Respawn takeover (`RespawnTime` 1e6, scripted respawn) | Death in the Hub: back in 3.08 s, in the Hub |
| Flash Freeze, aimed at a dummy 32 studs away (outside the old r20 round the caster) | Zone centred 20 studs out. The dummy took 10 contact + 34 shatter and was rooted. On the client, 681 of 715 zone parts sit within 22 studs of the aimed centre |
| Blizzard, aimed at a dummy 45 studs away (outside the old r32) | Dummy slowed to 11, Chilled |
| Economy | Equipping locked Voltaic was refused. UNLOCK Aqua with 0 Sparks was refused with the right message. +1000 twice gave 2000. UNLOCK Aqua left 400 and owned. Equipping Aqua gave Twin Tide + Sidearm. Bulwark Wall on Aqua was refused (P31). RESET gave the starter kit, 0 Sparks, Cryo |
| Queue | `queue` with DUEL: `queueCount 1 6`. The UI reads "3v3 · TEAMS, FIRST TO 5" |
| Console | No script errors (only Roblox core and asset-permission warnings) |

**Not tested:** a real team match. That needs Server + 2 clients with `Config.Team.Size = 1`, or 6 clients for a true 3v3. The
steps are in `CHANGES_2026-10-18_team_mode.md`. The team agent's mock-player run of DuelMatch in Edit passed.

## To take it out

- **P31:** set `Config.TechniquesOwnElementOnly = false`.
- **P29:** set `VFXLibrary.Tuning.FlashFreeze.CastRange = 0` and `CryoTuning.Blizzard.CastRange = 0`. The code can stay.
- **Everything in this log:** put back the copies in `ServerStorage.HandoffSuperseded_2026_10_18`, using the same
  command-bar loop as in `CHANGES_2026-10-17_balance_pass.md` with the folder name changed. VFXLibrary is over 200k, so
  clone that copy in place of the live script.

# Round 2: the superseding handoff ("Implementation Handoff (current)"), 18 October

Most of the new list was already built in round 1 above: P30, P31, P32, P29, the data bugs, Bulwark Wall HP, the chase speed and the
dashboard (D3). Built this round:

**The owner's answers:**
- Movement: "switch only, keep full, but keep jumping by default (one jump only)".
- Chain Bolt: 55 / 10.
- Escape blink: "same key, second charge".

## #7 Voltaic: Chain Bolt 55 range, 10 damage

- **Where:** `VoltaicTuning.ChainBolt` `Range` 30 → **55** and `Damage` 8 → **10**.
- **Kept in step:** the VFXLibrary row Range (30 → 55), the two fallbacks (`VoltaicClient` FALLBACK, `ChainBoltFX`), and the loadout text ("very short range" → "short range").
- **Backup:** VoltaicTuning is in `ServerStorage.HandoffSuperseded_2026_10_18`.
- **The handoff's "45 → 55" premise is wrong for the live game.** Live was 30. 45 is team package v1's value, which the sim's base carries and which was never applied live.
- So live jumps 30 → 55. The sim's +8 points for Voltaic was measured on the package's 250–300 HP, not live 150.
- Play: the values load as 55 / 10.

## C10 Movement switch (`CHANGES_2026-10-18_movement_switch.md`)

- **The switch:** `Config.Movement.Mode = "Full"` (default, unchanged), or `"RunningOnly"`. A workspace attribute `MovementMode` overrides it live. The dev panel has a MOVEMENT row through a new `MovementModeServer` (dev-only).
- **RunningOnly removes:** slide, slide-jump, wall-run, wall jump and double jump. One normal jump stays, and kit mobility is untouched.
- **Play, RunningOnly:** sprint holds 25. Ctrl only crouches (8–10, no slide boost). Each jump peaks at 9–10 studs, and a second Space adds nothing.
- **Play, Full:** unchanged. The chain peaks at 53, holds 44–47, and the double jump reaches 11.8.
- **Review:** 2 defects confirmed and fixed: a touch player stuck crouched when the button hides; the touch button left visible against the brief.
- **Not enforced on the server:** an exploited client could still send a slide in RunningOnly. That is SpellshotService's MoveRequest, one line, not done.

## #8 Umbra (`CHANGES_2026-10-18_umbra.md`)

**Dive reward (P27, as the sim modelled it):** Shadow Step's 10 s cooldown becomes 5 s when it is cast within 2 s after an
Umbra hit, or when a hit lands within 2 s after the cast. The cut happens once per cast.
- Knobs: `UmbraTuning.ShadowStep.DiveWindow 2` / `DiveCooldown 5`.
- Play results:
  - hit then cast: 5 s;
  - cast then hit 0.5 s later: cut to cast + 5;
  - a second hit: no further cut;
  - no hit: 10.

**Escape blink:** a second charge on the same key. When the main cooldown runs and the escape is ready, the press is the same aimed 22-stud blink on its own 6 s cooldown.
- Knob: `EscapeCooldown 6`; 0 turns it off.
- The server decides which charge a press uses. The HUD's Primary slot has a small chip for the escape.
- Play results:
  - press 1 is the normal cast (10 s);
  - press 2 is the escape (6 s; the main clock keeps running);
  - press 3 is refused.
  - An escape with nowhere to land is refunded (mana and charge).

**Review:** one defect confirmed and fixed: a quick double tap is now queued, not refunded.

**A trap found while testing:** a test hit dealt from the command bar or execute_luau goes through that context's OWN copy of
CombatCore, so the game's `OnHitLanded` listeners never see it. Test hits have to come from a Script inside the running game.

## D1 fact-checks

| Question | Answer (live) | How checked |
|---|---|---|
| Bulwark Wall HP per deploy | Fresh 200 every raise | Round 1 (code) |
| Do slows and roots stop Shadow Step? | **No.** It is a server teleport (`PivotTo`) with no speed-cap check. The server's cap check only covers dash-type charge abilities | Play: rooted (cap 0), it blinked 18.4 studs; Chilled (cap 15), the cast was accepted |
| Do slows and roots stop Skyrider? | **A root stops it:** a cap of 0 (or JumpHeight 0) refuses or ends the ride. **A slow caps the flight speed** to the slow's cap, never below 12 (half the brake speed) | Code: `ZephyrSkyrider.Stunned`, `capOf` in the flight step |
| Shadow Dart's real numbers | 65 damage, 2.6 s interval, range 160, windup 2.3, speed 200 (`UmbraTuning.ShadowDart`). This matches the assumption the handoff quotes, **but the latest sim round (h1) ran it at 85** (`SIM_DART_DMG 85` in `pkg_h1_*`) | Studio read |
| Does Scorching Lash's speed check reject a boosting Skyrider? | **No.** The 52 limit only bounds the Pyro's OWN trail slack. A target is checked against 1 s of 60 Hz position history with a 5.5-stud reach, which a 75 studs/s rider passes. A sweep that covered the rider on screen lands; only the sweep's height can miss a high flyer | Code: `PyroHandler` lash claim, `Core.CheckTarget` / `WasThere` |
| Chase speed in Play | 44.8 studs/s settled | Round 1 (Play) |

**Sim-vs-live gaps found while checking (the simulator's job, not built):**
- **Shadow Step:** the sim refuses Shadow Step and the escape while rooted (`capnow > 0`). Live allows both, so live Umbra escapes more than the sim thinks.
- **The h1 package's numbers:** Dart 85 (live 65); Skyrider 42/55 (live 60/75 since the 10-17 pass); HP 250–300 (live 150).

## D2: server-side wall collision. Not built, on purpose

- Bulwark Wall is already a server body that blocks bodies and shots.
- The only wall that would need a new server body is a shot-blocking Twin Tide. Item 6 of this same handoff kills that branch ("Any Aqua-as-second-tank mechanic... don't pursue").
- Building it would also be a live Aqua buff nobody validated on live numbers.
- Correction to the handoff's premise: live Twin Tide walls are built on EVERY client from the server broadcast, not only the caster's. So they already stop every player's body; they just don't stop shots.

## Housekeeping

- **Stage scripts:** a capture stage from another session (`_AuroraStage` / `_AuroraStageClient` / `_BROStageClient`) was ENABLED in one Play run, and it anchored the player and hid the HUD at spawn. In Edit all three are disabled, so a normal Play starts clean.
- **What I tested with:** temporary test scripts and remotes lived only inside the Play sessions, and are gone.
