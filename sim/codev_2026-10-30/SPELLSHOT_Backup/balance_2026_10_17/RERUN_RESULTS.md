# Balance sim re-run, after the 2026-10-17 pass

This folder holds `sim.py`, a copy of `balance_2026_10_16/sim.py` with a `before` / `after` switch. Each pass runs 60
duels a pairing. The full grids are in `tables_before.md`, `tables_after.md` and the matching `sim_results_*.json` files.

The two runs differ only in the 17 October changes, listed in `CHANGES_2026-10-17_balance_pass.md`.

Both runs use two fixes to the model, so the old run differs slightly from the first published one:
- The 3rd Chill stack now holds a cap of 10 for its window instead of rooting, as the live game has done since 08 Oct.
- A dash is refused under the dash threshold.

These fixes barely moved the numbers:
- Mean time to contact went from 5.6 to 5.3 s.
- Pairings above / below the 55% / 45% rusher win-rate lines went from 37 / 41 to 34 / 44.

What the `after` run assumes:
- **Spawns** are 40 studs inside the edge, 160 apart instead of 220.
- **Round clock:** the 90 s clock decides the round by health share.
- **Chase speed** is 45 studs/s. This is an estimate, not a measurement: the 59 measured before, scaled by the new slide-jump cap (70 → 52).

## Headline (before → after)

| Measure | Before | After |
|---|---|---|
| Median time to contact | 3.9 s | 4.4 s |
| Pairings that close inside 10 s | 75 of 81 | 72 of 81 |
| Kiter damage from beyond 40 studs (mean) | 21 HP | 30 HP |
| Pairings where 8 studs is the best range | 63 | 66 |
| Rusher wins above 55% / below 45% | 34 / 44 | 36 / 37 |
| Fastest killer (mean time to kill) | Pyro 3.6 s | Pyro 3.9 s |
| Slowest killer | Toxin 10.1 s | Zephyr 8.7 s |
| Kill-time spread | 2.8× | 2.2× |
| Hardest to kill | Terra 9.5 s | Terra 9.0 s |

## By Element (before → after)

| Element | Time to kill as attacker (s) | Win rate as rusher | Win rate as kiter | Kiter damage from range (HP) | Time it holds a rusher off (s) |
|---|---|---|---|---|---|
| Aqua | 8.8 → 7.1 | 0.06 → 0.07 | 0.21 → 0.09 | 10 → 14 | 4.1 → 4.7 |
| Cryo | 8.5 → 8.5 | 0.35 → 0.36 | 0.62 → 0.55 | 35 → 57 | 14.9 → 21.8 |
| Pyro | 3.6 → 3.9 | 0.78 → 0.80 | 0.84 → 0.84 | 35 → 58 | 4.1 → 4.6 |
| Radiant | 6.4 → 6.4 | 0.71 → 0.78 | 0.87 → 0.80 | 24 → 33 | 3.5 → 3.8 |
| Terra | 7.1 → 7.3 | 0.68 → 0.66 | 0.56 → 0.41 | 7 → 17 | 3.8 → 4.2 |
| Toxin | 10.1 → 8.2 | 0.06 → 0.32 | 0.18 → 0.27 | 6 → 11 | 4.4 → 4.3 |
| Umbra | 6.3 → 6.5 | 0.66 → 0.72 | 0.73 → 0.70 | 29 → 26 | 4.4 → 4.0 |
| Voltaic | 5.9 → 4.8 | 0.46 → 0.51 | 0.54 → 0.50 | 28 → 30 | 4.3 → 5.0 |
| Zephyr | 8.8 → 8.7 | 0.35 → 0.42 | 0.33 → 0.21 | 20 → 25 | 3.9 → 4.8 |

## Reading

- **More ranged damage before contact.** A kiter now lands about 40% more before the rusher arrives (21 → 30 HP), short
  of the 40 HP target. Cryo and Pyro kiters land about 57.
- **The chase is no longer.**
  - Spawns 160 apart at a 45 chase take as long to cross as 220 apart at 59, so contact still comes in about 4 s.
  - Only Cryo holds rushers off for long (22 s on average, through Blizzard and the dash rule).
- **Point-blank still decides most duels:** 66 of 81 pairings.
- **Winners and losers:**
  - **Toxin gained most:** 0.06 → 0.32 as a rusher, and it kills in 8.2 s instead of 10.1.
  - **Voltaic now kills faster** (4.8 s), from Charged's lone-target damage plus Chain Reaction.
  - **Pyro is still the outlier:** 0.80 / 0.84, kill time 3.9 s, against a target of about 5 s. The Lash nerf was offset by the faster Fireball and the new Ember Refund.
  - **Aqua is still last** (0.07 / 0.09). Its numbers went up, but its kit pulls enemies in, which works against kiting.
  - **Terra and Zephyr got worse as kiters** (closer spawns, and the dash rule).

## Limits

- **Chase speed** is estimated; measuring the real one in Play would settle it.
- **The arena** is an open disc with no cover or walls.
- **The aim model** is assumed, as in the first run.

# Model v3 (later on 17 Oct): moving shooters, jumps, bigger hitboxes

The owner asked for misses and movement to be accounted for. What changed in `sim.py`:
- **Shooters move.** Both duellists move while they shoot. The shooter's own strafe adds aim jitter (0.5° at a full
  25 studs/s), and tracking lag works on the movement of both bodies.
- **Targets jump.** A shot must land vertically as well as sideways: body half-height 2.6, against a vertical dodge of
  12 studs/s while chaining and 6 while jump-strafing.
- **Hitbox scale.** `HITBOX` is 1.3, the value now live.
- **Aqua's kiting range** is 65, inside Riptide's 70. It used to sit at 100 and could not shoot.
- **Test values** go in through `SIM_OVERRIDES` (JSON); `SIM_TAG` names the output files.

## Hit chance %, target strafing at 25 studs/s, at 8 / 20 / 45 / 90 studs

| Shot | First runs (shooter still) | Both moving, jumps | Moving, 30% hitbox |
|---|---|---|---|
| Icicle Shard | 77 62 38 19 | 62 53 35 17 | 73 64 43 23 |
| Fireball (direct) | 89 64 34 17 | 80 60 33 14 | 86 67 38 18 |
| Wind Blade | 96 88 63 – | 86 79 59 – | 91 85 65 – |
| Boulder (full charge) | 87 56 28 14 | 79 54 27 11 | 85 60 32 14 |
| Chain Bolt | 95 94 – – | 83 82 – – | 89 88 – – |
| Shadow Dart | 82 69 44 23 | 68 59 41 21 | 77 69 49 27 |
| Light Lance | 93 92 85 – | 81 79 73 – | 87 86 81 – |
| Riptide | 90 61 40 – | 89 59 40 – | 90 61 42 – |
| Toxic Bubble | 86 56 28 14 | 77 53 27 11 | 84 60 32 14 |

## Overall win rate, the mean of chasing and kiting (time to kill in s)

| Element | 16 Oct kit | After the pass, old hitbox | Live: pass + 30% hitbox | Proposed (P2) |
|---|---|---|---|---|
| Aqua | 0.16 (9.1) | 0.13 (7.5) | 0.11 (7.2) | 0.35 (4.6) |
| Cryo | 0.29 (11.2) | 0.25 (10.7) | 0.34 (9.6) | 0.41 (8.5) |
| Pyro | 0.86 (3.7) | 0.86 (4.0) | 0.84 (4.0) | 0.63 (5.6) |
| Radiant | 0.64 (9.1) | 0.68 (9.3) | 0.76 (7.3) | 0.65 (8.7) |
| Terra | 0.67 (7.7) | 0.58 (7.4) | 0.58 (7.1) | 0.55 (7.2) |
| Toxin | 0.17 (10.5) | 0.37 (8.8) | 0.32 (8.4) | 0.38 (7.0) |
| Umbra | 0.71 (7.9) | 0.71 (7.9) | 0.71 (6.8) | 0.67 (7.7) |
| Voltaic | 0.58 (6.8) | 0.58 (5.5) | 0.51 (5.0) | 0.46 (5.2) |
| Zephyr | 0.42 (9.5) | 0.34 (9.5) | 0.33 (8.9) | 0.41 (7.9) |
| **Lowest to highest** | 0.16–0.86 | 0.13–0.86 | 0.11–0.84 | 0.35–0.67 |
| **Kill-time spread** | 3.05× | 2.66× | 2.42× | 1.88× |

**Proposed set P2** (`SIM_TAG=v3_P2`), chosen from 14 tested sets:

| Element | Change |
|---|---|
| Pyro | Fireball direct 18 → 15, splash 9 → 6, fire interval 0.6 → 0.7 s |
| Pyro | Detonate missing-health bonus 36 → 24 |
| Pyro | Immolate burn 1.2 → 0.8 a tick |
| Aqua | Riptide 12 → 19 |
| Radiant | Light Lance peak 32 → 24 dps |
| Umbra | Shadow Dart 65 → 60 |
| Cryo | Icicle Shard 8 → 9 |
| Toxin | Toxic Bubble pop 9 → 12 |
| Zephyr | Wind Blade 3 → 3.5 |

Terra and Voltaic are untouched.

Most of Pyro's edge was its splash: a miss within 6 studs still did 9. A Riptide range of 90 made Aqua worse (more misses at range).

# Hitbox 2x and one M1 projectile speed (200), model v3

Overall win rate, the mean of chasing and kiting; time to kill in seconds:

| Element | Live at 1.3× | 2× hitbox | 2× + speed 200 (now live) | Now live + tuning Q3 |
|---|---|---|---|---|
| Aqua | 0.11 (7.2) | 0.09 (6.8) | 0.10 (6.9) | 0.32 (4.5) |
| Cryo | 0.34 (9.6) | 0.49 (8.3) | 0.35 (8.4) | 0.40 (7.5) |
| Pyro | 0.84 (4.0) | 0.81 (3.7) | 0.85 (3.6) | 0.68 (5.3) |
| Radiant | 0.76 (7.3) | 0.74 (6.0) | 0.69 (6.0) | 0.61 (7.1) |
| Terra | 0.58 (7.1) | 0.61 (5.8) | 0.78 (4.8) | 0.63 (6.4) |
| Toxin | 0.32 (8.4) | 0.29 (7.7) | 0.45 (7.6) | 0.46 (7.0) |
| Umbra | 0.71 (6.8) | 0.76 (6.0) | 0.69 (5.9) | 0.63 (6.5) |
| Voltaic | 0.51 (5.0) | 0.43 (4.6) | 0.38 (4.6) | 0.33 (4.1) |
| Zephyr | 0.33 (8.9) | 0.28 (8.2) | 0.21 (8.4) | 0.44 (6.5) |
| **Kiter damage before contact** | 29 HP | 40 HP | 45 HP | 46 HP |
| **Mean time to kill** | 7.1 s | 6.3 s | 6.3 s | 6.1 s |

What each change did:
- **The 2× hitbox** cut the mean time to kill from 7.1 to 6.3 s, and kiters now land 40 HP before contact (it was 29).
- **The shared speed** took kiter damage to 45 HP. It made Terra's boulder a top threat (0.78), lifted Toxin, and sank Zephyr and Voltaic, whose fast or hitscan attacks lost their edge.

**Q3 (suggested, not applied)** brings every Element to 0.32–0.68:

| Element | Change |
|---|---|
| Pyro | Fireball 15 direct / 6 splash / 0.7 s, Detonate bonus 24, Immolate 0.8 |
| Aqua | Riptide 19 |
| Radiant | Light Lance peak 26 |
| Umbra | Shadow Dart 60 |
| Cryo | Icicle 9 |
| Toxin | Bubble 10 |
| Zephyr | Wind Blade 4 |
| Terra | Boulder full charge 48 → 40 |
| Voltaic | Chain Bolt 8 → 9 |

Wind Blade is very sensitive (4.5 puts Zephyr at 0.67), and so is the Bubble (12 puts Toxin at 0.67).

# Full run (100 duels per pairing and per approach), live game vs 16 Oct kit

Every matchup was played four ways: both chase, both keep distance, and one of each (both orders).
- **Best play** is the win rate when each side picks its best approach. It is the value of the 2×2 game those four results
  make (mixed when neither approach dominates).
- `SIM_FULL=1` turns this on. Results are in `sim_results_full_{before,live,q3}.json`.

| | 16 Oct kit | Live (pass + 2× hitbox + speed 200) | Live + Q3 tuning (not applied) |
|---|---|---|---|
| Matchups where best play is "both chase" | 18 of 81 | 23 of 81 | 6 of 81 |
| Share of best play that is chasing | 56% | 57% | 42% |
| Best-play win rate, lowest to highest Element | 9–86% | 9–87% | 23–75% |
| Median time to contact | 3.9 s | 4.4 s | 4.3 s |
| Kiter damage before contact | 16 HP | 45 HP | 45 HP |
| Mean time to kill | 8.4 s | 6.2 s | 6.1 s |
| Kill-time spread | 2.9× | 2.3× | 1.8× |

Best-play win rate by Element (how often its best play is to chase):

| Element | 16 Oct kit | Live | Live + Q3 |
|---|---|---|---|
| Pyro | 86% (67%) | 87% (44%) | 68% (15%) |
| Terra | 75% (100%) | 80% (93%) | 75% (85%) |
| Radiant | 64% (63%) | 64% (63%) | 55% (49%) |
| Umbra | 68% (23%) | 64% (65%) | 57% (52%) |
| Cryo | 35% (0%) | 46% (21%) | 51% (10%) |
| Toxin | 19% (44%) | 46% (33%) | 47% (0%) |
| Voltaic | 55% (76%) | 34% (79%) | 23% (89%) |
| Zephyr | 41% (67%) | 20% (73%) | 44% (67%) |
| Aqua | 9% (63%) | 9% (44%) | 29% (11%) |

Reading:
- **Faster and more ranged.** The live changes made fights faster (8.4 → 6.2 s) and gave kiters real damage before contact (16 → 45 HP).
- **Chasing still wins.** Best play is still to chase 57% of the time, and in 23 matchups both sides should chase.
- **The ranking moved, but the gap stayed** at 9–87%:
  - Toxin (+27 points) and Cryo (+11) gained.
  - Voltaic (−21) and Zephyr (−21) lost, now that every projectile is as fast as theirs.
- **Q3 would help but is not finished.** It cuts both-chase matchups to 6 and narrows the spread to 23–75%. It leaves Terra on
  top (it wins by chasing) and Voltaic at the bottom (it can only chase, and loses when kited). It would need another
  pass, or different targets if team modes become the main mode.

## Correction (17 Oct, evening): M1 timing in sim.py understated fast M1s

`sim.py` steps in 0.1 s and set `next_m1 = t + interval`. So an M1 could fire only on a step at least one full interval
after the last shot, and every interval was rounded up to the next 0.1 s:
- Wind Blade fired every 0.2 s, not 0.12 (−40% damage);
- Chain Bolt every 0.4 s, not 0.32 (−20%);
- Icicle Shard every 0.4 s, not 0.333 (−17%);
- Toxic Bubbles every 0.6 s, not 0.55 (−8%);
- Riptide every 0.7 s, not 0.667 (−5%).

Every 1v1 result above, and the dashboard artifact, carries this error. `sim_m1fix.py` is a copy with the remainder kept
(`_nx`); `sim.py` itself is unchanged, so the published runs can still be reproduced.

The full live run re-run with the fix (same settings: HITBOX 2.0, PROJ_SPEED 200, SIM_FULL, N 100;
`sim_results_full_live_m1fix.json`). Mean best-play win % against the other eight, mirrors excluded:

| Element | Published | Fixed | Change |
|---|---|---|---|
| Pyro | 91 | 91 | +1 |
| Terra | 84 | 79 | −5 |
| Zephyr | 16 | 62 | **+47** |
| Umbra | 66 | 60 | −6 |
| Radiant | 66 | 52 | −14 |
| Cryo | 44 | 52 | +8 |
| Toxin | 46 | 31 | −15 |
| Voltaic | 32 | 23 | −9 |
| Aqua | 3 | 2 | −1 |

Zephyr was badly under-rated: its mean time to kill falls from 8.3 s to 5.4 s. Pyro on top and Aqua last are unchanged.
"Both chase" matchups: 17 (was 20 counted this way).
