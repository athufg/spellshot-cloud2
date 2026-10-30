# SPELLSHOT: 3v3 team-fight simulation

Running-only movement, 16 comps, 420 matchups. 17 October 2026, for the owner's 3v3 prompt.

## 1. Summary

**Does strategy beat stacking?** On average, yes, but not reliably.
- In every configuration, the five strategy comps win **72–80%** of their 45 matchups against mono-comps.
- S3 (Terra + Cryo + Pyro) does most of it: 96–98%.
- S2 is a coin flip (51–57%). S5 drops from 62–72% to 48–59% once jumping is allowed.
- Mono-Pyro beats four of five in Pass 1 (lowest-HP focus); the "weak" W2 beats three.

**Does the Pass 2 HP spread change that?** Barely. Strategy comps gain 3–4 points; mainly it reshuffles who wins (mono-Terra +18, mono-Umbra −18).

**Does a jump matter?** Only for ground control: strategy comps lose about 3 points, nearly all S5's. Rounds last no longer.

**Biggest team-context spam finding:** mana never binds.
- Rounds last ~10 s, and M1s, cheaper than the regen, do **69%** of all damage.
- Pyro does **1.6×** the next Element's damage per player, from Fireball's rate, not its splash.

## 2. Comp roster

| Comp | Roster | Tests |
|---|---|---|
| Aqua ×3 | Aqua, Aqua, Aqua | The worst 1v1 kit stacked: wave lanes, pulls, walls, no escape |
| Cryo ×3 | Cryo, Cryo, Cryo | Stacked slows and roots with no damage dealer |
| Pyro ×3 | Pyro, Pyro, Pyro | The best 1v1 kit stacked: splash, burns, three Rings of Fire |
| Radiant ×3 | Radiant, Radiant, Radiant | Three healers, no one to protect |
| Terra ×3 | Terra, Terra, Terra | Three tanks: walls and charges, low damage |
| Toxin ×3 | Toxin, Toxin, Toxin | Stacked poison and clouds |
| Umbra ×3 | Umbra, Umbra, Umbra | Three long-range picks that kite |
| Voltaic ×3 | Voltaic, Voltaic, Voltaic | Three divers whose M1 reaches only 30 studs |
| Zephyr ×3 | Zephyr, Zephyr, Zephyr | Three disruptors: pierce, dashes, Skyrider |
| S1 | Terra + Radiant + Pyro | The classic tank, healer and damage trinity |
| S2 | Terra + Radiant + Voltaic | The same trinity with a close-range damage dealer |
| S3 | Terra + Cryo + Pyro | No healer: control stands in for sustain |
| S4 | Radiant + Umbra + Pyro | A dive comp with no tank |
| S5 | Cryo + Aqua + Terra | Pure control and attrition, no burst |
| W1 | Aqua + Toxin + Zephyr | Three kits that lose to rushing, no tank or support |
| W2 | Pyro + Pyro + Voltaic | All-in aggression, no sustain, control or protection |

## How the fights were simulated

| Part | Choice |
|---|---|
| Engine | A new 3v3 simulator: `team_sim_2026_10_17/team_sim.py`, steps of 0.05 s. It reuses the 1v1 sim's hit model and models every ability in the default loadouts. |
| Rounds per matchup | **200 per matchup per policy**: 105 matchups × 4 configurations × 2 policies × 200 = 168,000 rounds for the main dataset. That is ten times the suggested 20. One run's win rate carries about ±7 points of noise at 95%; row and column means carry about ±2–3. |
| Opening | An open floor 280 × 180 studs. Teams spawn 150 studs apart in a line 12 studs apart, with Umbra 30 out on the flank. Teams see each other at once: no fog and no blind approach. |
| Cover | None, except Bulwark Wall. A wall stops direct shots at Terra and at anyone in its shadow, behind Terra within 6 studs of the line to the shooter. A separate sensitivity run blocks 40% of aimed shots. |
| Movement | Running at 25 studs/s; the kit's own dashes, blinks and Skyrider stay live. Each Element has a range band (Voltaic 12–24, Terra 14–28, Zephyr 22–42, Pyro and Aqua 25–45, Radiant 30–50, Toxin 35–55, Cryo 40–65, Umbra 70–110). A player closes to its band, backs away from any enemy inside the band, and strafes while in it. Terra never backs away. Teammates stay 6+ studs apart and within 40 of the team's centre (Umbra 75). |
| Variant A / B | A: no jumping, so no vertical dodging, and Riptide, fissures and rings cannot be hopped. B: jump-strafing (the 1v1 sim's vertical dodge, 6 studs/s). Riptide is hopped as in the 1v1 sim; Aftershock, Earthen Tomb, Flash Freeze and Leviathan's Maw can sometimes be hopped when noticed. |
| Targeting | The team picks a focus every 0.5 s and switches only when another enemy has 15 HP less. **Lowest-HP**: the enemy with the least current HP. **Softest-role**: the enemy's Controller/Support pick first (Radiant or Cryo, per the prompt's role table); if there is none, the lowest HP, with the tank last. Each player shoots the focus when in M1 range, otherwise the nearest enemy in range. |
| Aim and reaction | The 1v1 sim's model unchanged: 1° spread, 40 ms tracking lag, 45% of lead unpredictable, the shooter's own movement adds jitter, reaction 0.15–0.45 s, 2× hitboxes. **One team-context change:** a telegraphed area attack is noticed 80% of the time, not 100%, because attention is split three ways. |
| Peel | Uses each kit's real tools, triggered when an ally takes about 12+ damage per second or an enemy is within 14–16 studs of it. **Terra:** walls first when an ally within 25 is under fire, and the ally steps into the wall's shadow; Bulwark Charge at a diver on an ally; Aftershock on divers. **Radiant:** Blessing on the most-pressed ally in 45; Benediction when a teammate is hurt and no enemy is within 14, stopping when Radiant itself is pressed below 50%; Position Trade pulls a dived ally under 40% back. **Cryo:** Icicle on the diver nearest an ally; Flash Freeze when divers reach 16; Deep Freeze at a diver's feet. **Aqua:** Sidearm knocks a diver off an ally. |
| Round | Ends when a team is wiped; no respawns. A 90 s clock (the live Duel `RoundTime`) gives the round to the larger share of team health. Every round starts from a full reset with Ultimate charge 0, as in round 1 of a match. Ultimate charge is per player: 1/260 per point of damage dealt or taken, +0.06 a cast. |
| Reactions | Simulated hit by hit inside every round. The trigger table, cooldowns and numbers are the prompt's. One reaction per hit; a reaction on its body's cooldown is skipped and the next rule is checked. DoT ticks, chain jumps and reaction damage never trigger one, as in the live `ElementalReactions`. Acid Rain ticks do trigger (the prompt lists Acid Rain as reaction-capable). Cooldowns are per reaction per body. |

## Numbers used

**Main run (dataset P):** every ability number exactly as the prompt gives it. Where the prompt is silent, I used the
team-fight brief's shared stats: 2× hitboxes, and every M1 projectile at 200 studs/s. Boulder Shot keeps the prompt's
108 (uncharged) and 86 (full charge).

**Live check (dataset L):** the same 420 matchups were re-run with the values live in Studio today, as recorded in the
change log `CHANGES_2026-10-17_balance_pass.md`. Studio was not used. The two datasets differ here:

| Value | Prompt (P) | Live today (L) |
|---|---|---|
| Chill, 3rd stack | roots 0.8 s, then 1.2 s immune | caps speed at 10 for 5 s, no root (since 8 Oct) |
| Blizzard | cap 14, 8 s | cap 11, 6 s |
| Deep Freeze root / Mirror Cage root | 2.5 s / 3.13 s | 1.5 s / 2.30 s |
| Benediction longest channel | 30 s | 8 s |
| Scorching Lash | 2.5 s cooldown, 1.6 burn per stack per 0.5 s | 5 s, 1.0 |
| Poisoned / Acid Rain tick | 4/s / 4 per s | 6/s / 6 per s |
| Sidearm / Twin Tide | 6 mana a bullet / 40 mana, seam ±3.5 | 4 / 30, ±5 |
| Skyrider | 42 / 55 studs/s | 60 / 75 |
| Charged into a lone target | 0 | 7 |
| Ember Refund | on a kill | on a hit that takes an enemy under 30% |
| Chain Reaction | on a kill | 2 s off Overcharge each time Charged fills |
| Antitoxin Vent | cleanses own poison | also cuts DoT taken by 30% for 6 s |
| Dash refused below | 12 studs/s | 16 |
| Boulder Shot speed | 108 / 86 | 200 / 200 |
| Fireball reach | 110 (as told) | 160 (flies 166 studs; 110 is only the aim ray) |

**Points in the prompt that disagree with its own source (the 16 Oct audit table).** I kept the prompt's number
everywhere except the first row, and report each here instead of substituting quietly:

| Prompt says | Source says | What I did |
|---|---|---|
| Toxic Bubbles: poison "caps at 6 stacks", "a miss rests the ability 4.5 s" | "Poisoned 4/s for 5 s (1 stack); a miss rests 4.5 s (≤6)". One stack, refreshed; a *missed bubble* rests on the ground 4.5 s, at most 6 resting. | Used the source's meaning. As written, six stacking poisons would be 24/s, and a 4.5 s lockout on every miss would cancel most of it. That is a misreading, not a value. |
| Skyrider "measured slower than base running once the chain is removed" | "slower than the shared chain" (59 studs/s) | Used 42 / 55. Against a 25 studs/s run that is 1.7–2.2× faster, so with the chain gone Skyrider becomes Zephyr's strongest tool, not its weakest. |
| Boulder Shot full charge "is a known bug" | TerraFX: "The heavier it is the slower it leaves the hand" | Intended, not a bug. Values used as given. |
| Fireball range 110 "a known data mismatch" | VFXLibrary: the row Range is only the aim ray's reach | Intended. Used 110, as the prompt asked. |
| Detonate is a Burning source | Detonate's row lists no burn | No burn modelled. |
| Gust Pad carries a damage-dealing hit | Gust Pad's row lists no damage | Modelled as a 0-damage Zephyr hit that can still set off a reaction. |
| "Charged stacks require a second body" (P) | "Charged stacks, alone 0" | Stacks build only when a second enemy is within 16 of the target; the full-stack pop does 0 damage. |

(PROP) values were used as given. The only one a finding leans on hard is Shadow Dart (65 per 2.6 s, range 160), which
decides every Umbra result; it was not re-checked, per the prompt's tools section.

## 3. Matchup results, by configuration

Each cell is 200 rounds per policy. Mono-vs-strategy cells give the **mono's** win %, lowest-HP focus / softest-role
focus. The time to wipe is the round length when one team was wiped; no round in any configuration reached the 90 s
clock. Every row for every policy, with draws and time-outs, is in `team_sim_2026_10_17/matchups_P.csv` (and
`matchups_L.csv` for the live check).

### 3.1 Pass 1 / Variant A (no jump)

**Mono vs strategy** (mono win %, lowest-HP focus / softest-role focus; 200 rounds each)

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | Mono mean |
|---|---|---|---|---|---|---|
| Aqua | 9 / 3 | 27 / 12 | 2 / 0 | 22 / 9 | 10 / 12 | 14 / 7 |
| Cryo | 2 / 30 | 96 / 99 | 0 / 4 | 10 / 18 | 57 / 60 | 33 / 42 |
| Pyro | 79 / 22 | 92 / 59 | 10 / 0 | 87 / 84 | 94 / 92 | 72 / 51 |
| Radiant | 0 / 0 | 40 / 10 | 0 / 0 | 4 / 4 | 10 / 8 | 11 / 4 |
| Terra | 4 / 4 | 28 / 55 | 5 / 10 | 27 / 38 | 54 / 37 | 24 / 29 |
| Toxin | 0 / 0 | 2 / 4 | 0 / 0 | 9 / 8 | 8 / 9 | 4 / 4 |
| Umbra | 36 / 57 | 98 / 96 | 6 / 38 | 32 / 35 | 64 / 59 | 47 / 57 |
| Voltaic | 0 / 1 | 11 / 22 | 0 / 2 | 4 / 4 | 30 / 24 | 9 / 11 |
| Zephyr | 0 / 0 | 22 / 6 | 0 / 0 | 6 / 4 | 28 / 31 | 12 / 8 |
| **Strategy comp's mean win %** | **86 / 87** | **54 / 60** | **98 / 94** | **78 / 77** | **60 / 63** | **75 / 76** |

Strategy comp wins 60% or more in **36 / 45** (lowest-HP) and **36 / 45** (softest-role) matchups; the mono wins half or more in 9 and 9.

Time to team wipe (s, both policies pooled; the lowest-HP / softest-role split is in the CSV):

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 |
|---|---|---|---|---|---|
| Aqua | 9.3 | 11.3 | 6.4 | 9.0 | 9.3 |
| Cryo | 11.4 | 12.0 | 8.3 | 10.8 | 12.3 |
| Pyro | 9.1 | 8.3 | 6.9 | 8.4 | 8.0 |
| Radiant | 9.7 | 12.3 | 8.0 | 13.4 | 12.1 |
| Terra | 9.7 | 12.7 | 9.5 | 12.3 | 12.7 |
| Toxin | 8.8 | 12.2 | 6.9 | 10.2 | 11.4 |
| Umbra | 13.9 | 14.0 | 10.9 | 17.9 | 14.3 |
| Voltaic | 7.8 | 9.0 | 6.2 | 8.0 | 9.7 |
| Zephyr | 8.1 | 9.8 | 6.6 | 8.4 | 9.3 |

**Mono vs mono ranking** (mean win % against the other eight monos)

| Rank | Mono | Lowest-HP | Softest-role | Best against | Worst against | Mean wipe (s) |
|---|---|---|---|---|---|---|
| 1 | Pyro | 94 | 94 | Radiant (100) | Terra (76) | 7.5 |
| 2 | Umbra | 65 | 65 | Radiant (100) | Pyro (5) | 13.1 |
| 3 | Cryo | 63 | 62 | Voltaic (100) | Pyro (8) | 11.4 |
| 4 | Terra | 51 | 53 | Toxin (86) | Umbra (4) | 13.3 |
| 5 | Toxin | 50 | 48 | Zephyr (91) | Pyro (1) | 12.8 |
| 6 | Aqua | 35 | 33 | Radiant (94) | Pyro (3) | 9.9 |
| 7 | Voltaic | 32 | 33 | Aqua (78) | Cryo (0) | 9.4 |
| 8 | Radiant | 31 | 33 | Voltaic (88) | Pyro (0) | 13.2 |
| 9 | Zephyr | 30 | 29 | Aqua (56) | Pyro (0) | 10.2 |

**Strategy vs strategy** (first-named win %, lowest-HP / softest-role; wipe time pooled)

| Matchup | Win % | Wipe (s) |
|---|---|---|
| S1 vs S2 | 91 / 97 | 10.2 |
| S1 vs S3 | 34 / 56 | 9.8 |
| S1 vs S4 | 82 / 98 | 11.2 |
| S1 vs S5 | 70 / 86 | 10.2 |
| S2 vs S3 | 11 / 0 | 9.2 |
| S2 vs S4 | 49 / 61 | 12.5 |
| S2 vs S5 | 28 / 32 | 12.1 |
| S3 vs S4 | 83 / 97 | 9.2 |
| S3 vs S5 | 93 / 93 | 8.6 |
| S4 vs S5 | 68 / 69 | 11.7 |

Ranking (mean of both policies vs the other four): S3 83, S1 77, S4 33, S5 33, S2 24

**Weak comps** (weak comp's win %, lowest-HP / softest-role; wipe time pooled)

| Weak comp | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | vs Pyro | vs Aqua |
|---|---|---|---|---|---|---|---|
| W1 | 8 / 0 (9 s) | 44 / 26 (11 s) | 0 / 0 (7 s) | 12 / 14 (10 s) | 22 / 22 (10 s) | 0 / 0 (6 s) | 64 / 70 (10 s) |
| W2 | 62 / 27 (9 s) | 84 / 96 (7 s) | 40 / 16 (8 s) | 82 / 84 (10 s) | 98 / 98 (7 s) | 69 / 68 (7 s) | 98 / 98 (6 s) |

All 105 matchups: mean time to wipe 10.3 s; rounds that ran to the 90 s clock: 0.0%.

### 3.2 Pass 1 / Variant B (jump + double jump)

**Mono vs strategy** (mono win %, lowest-HP focus / softest-role focus; 200 rounds each)

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | Mono mean |
|---|---|---|---|---|---|---|
| Aqua | 2 / 2 | 10 / 4 | 2 / 0 | 4 / 2 | 6 / 4 | 5 / 2 |
| Cryo | 2 / 36 | 93 / 100 | 0 / 4 | 21 / 13 | 83 / 82 | 40 / 47 |
| Pyro | 78 / 32 | 92 / 72 | 12 / 0 | 88 / 84 | 95 / 92 | 73 / 56 |
| Radiant | 0 / 0 | 46 / 9 | 0 / 0 | 4 / 3 | 40 / 30 | 18 / 8 |
| Terra | 2 / 4 | 24 / 44 | 2 / 5 | 20 / 26 | 52 / 45 | 20 / 25 |
| Toxin | 0 / 0 | 4 / 6 | 0 / 0 | 6 / 8 | 26 / 25 | 7 / 8 |
| Umbra | 42 / 62 | 100 / 98 | 4 / 29 | 38 / 32 | 78 / 80 | 53 / 60 |
| Voltaic | 0 / 0 | 12 / 29 | 0 / 2 | 4 / 4 | 46 / 36 | 12 / 14 |
| Zephyr | 0 / 0 | 47 / 4 | 0 / 0 | 10 / 12 | 60 / 54 | 24 / 14 |
| **Strategy comp's mean win %** | **86 / 85** | **52 / 59** | **98 / 96** | **78 / 80** | **46 / 50** | **72 / 74** |

Strategy comp wins 60% or more in **31 / 45** (lowest-HP) and **34 / 45** (softest-role) matchups; the mono wins half or more in 10 and 9.

Time to team wipe (s, both policies pooled; the lowest-HP / softest-role split is in the CSV):

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 |
|---|---|---|---|---|---|
| Aqua | 8.7 | 11.0 | 6.3 | 8.7 | 9.7 |
| Cryo | 11.5 | 12.1 | 8.4 | 10.8 | 12.9 |
| Pyro | 9.2 | 8.4 | 6.9 | 8.5 | 8.0 |
| Radiant | 9.9 | 12.4 | 8.1 | 13.3 | 14.0 |
| Terra | 10.0 | 13.3 | 9.5 | 12.5 | 13.7 |
| Toxin | 8.9 | 12.3 | 7.0 | 10.2 | 13.3 |
| Umbra | 14.1 | 14.3 | 10.8 | 18.3 | 15.2 |
| Voltaic | 7.8 | 9.1 | 6.2 | 7.9 | 10.2 |
| Zephyr | 8.4 | 9.8 | 6.6 | 8.5 | 9.5 |

**Mono vs mono ranking** (mean win % against the other eight monos)

| Rank | Mono | Lowest-HP | Softest-role | Best against | Worst against | Mean wipe (s) |
|---|---|---|---|---|---|---|
| 1 | Pyro | 95 | 96 | Radiant (100) | Terra (88) | 7.5 |
| 2 | Umbra | 66 | 67 | Voltaic (100) | Pyro (7) | 13.0 |
| 3 | Cryo | 62 | 64 | Voltaic (100) | Pyro (8) | 11.4 |
| 4 | Toxin | 55 | 54 | Aqua (88) | Pyro (1) | 12.9 |
| 5 | Zephyr | 49 | 47 | Aqua (87) | Pyro (0) | 9.9 |
| 6 | Terra | 43 | 41 | Aqua (89) | Umbra (2) | 13.6 |
| 7 | Voltaic | 33 | 34 | Aqua (93) | Cryo (0) | 9.4 |
| 8 | Radiant | 32 | 32 | Voltaic (90) | Pyro (0) | 13.5 |
| 9 | Aqua | 14 | 15 | Radiant (62) | Pyro (2) | 10.3 |

**Strategy vs strategy** (first-named win %, lowest-HP / softest-role; wipe time pooled)

| Matchup | Win % | Wipe (s) |
|---|---|---|
| S1 vs S2 | 93 / 98 | 10.3 |
| S1 vs S3 | 30 / 54 | 9.9 |
| S1 vs S4 | 82 / 96 | 11.2 |
| S1 vs S5 | 84 / 92 | 10.5 |
| S2 vs S3 | 12 / 0 | 9.2 |
| S2 vs S4 | 43 / 50 | 12.5 |
| S2 vs S5 | 37 / 38 | 13.2 |
| S3 vs S4 | 86 / 97 | 9.1 |
| S3 vs S5 | 97 / 98 | 8.5 |
| S4 vs S5 | 77 / 86 | 11.6 |

Ranking (mean of both policies vs the other four): S3 85, S1 79, S4 38, S5 24, S2 24

**Weak comps** (weak comp's win %, lowest-HP / softest-role; wipe time pooled)

| Weak comp | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | vs Pyro | vs Aqua |
|---|---|---|---|---|---|---|---|
| W1 | 8 / 3 (9 s) | 47 / 26 (12 s) | 0 / 0 (7 s) | 12 / 9 (10 s) | 46 / 38 (11 s) | 0 / 0 (6 s) | 90 / 90 (10 s) |
| W2 | 56 / 45 (9 s) | 86 / 98 (7 s) | 43 / 21 (8 s) | 84 / 88 (10 s) | 99 / 99 (7 s) | 67 / 67 (7 s) | 99 / 99 (6 s) |

All 105 matchups: mean time to wipe 10.4 s; rounds that ran to the 90 s clock: 0.0%.

### 3.3 Pass 2 / Variant A (no jump)

**Mono vs strategy** (mono win %, lowest-HP focus / softest-role focus; 200 rounds each)

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | Mono mean |
|---|---|---|---|---|---|---|
| Aqua | 0 / 0 | 24 / 12 | 0 / 0 | 18 / 18 | 3 / 9 | 9 / 8 |
| Cryo | 12 / 11 | 98 / 100 | 0 / 0 | 10 / 7 | 48 / 43 | 34 / 32 |
| Pyro | 8 / 9 | 84 / 61 | 0 / 0 | 98 / 91 | 84 / 86 | 55 / 49 |
| Radiant | 0 / 0 | 4 / 6 | 0 / 0 | 7 / 7 | 4 / 1 | 3 / 3 |
| Terra | 11 / 24 | 99 / 91 | 17 / 14 | 12 / 53 | 68 / 55 | 41 / 47 |
| Toxin | 0 / 0 | 14 / 4 | 0 / 0 | 0 / 4 | 6 / 6 | 4 / 3 |
| Umbra | 19 / 24 | 92 / 92 | 10 / 8 | 16 / 22 | 32 / 28 | 34 / 35 |
| Voltaic | 0 / 0 | 2 / 4 | 0 / 0 | 0 / 0 | 6 / 5 | 2 / 2 |
| Zephyr | 0 / 0 | 35 / 2 | 0 / 0 | 0 / 2 | 13 / 11 | 10 / 3 |
| **Strategy comp's mean win %** | **94 / 92** | **50 / 59** | **97 / 98** | **82 / 77** | **71 / 73** | **79 / 80** |

Strategy comp wins 60% or more in **37 / 45** (lowest-HP) and **36 / 45** (softest-role) matchups; the mono wins half or more in 7 and 8.

Time to team wipe (s, both policies pooled; the lowest-HP / softest-role split is in the CSV):

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 |
|---|---|---|---|---|---|
| Aqua | 9.0 | 12.7 | 6.6 | 9.5 | 9.6 |
| Cryo | 13.0 | 13.4 | 8.8 | 9.9 | 14.2 |
| Pyro | 10.0 | 10.0 | 6.6 | 7.3 | 9.1 |
| Radiant | 10.2 | 13.8 | 7.5 | 12.0 | 11.9 |
| Terra | 13.8 | 15.0 | 11.7 | 13.5 | 15.7 |
| Toxin | 9.4 | 15.0 | 6.9 | 8.9 | 12.2 |
| Umbra | 13.3 | 16.2 | 10.3 | 13.9 | 14.5 |
| Voltaic | 6.5 | 8.0 | 5.2 | 6.3 | 8.3 |
| Zephyr | 7.7 | 11.6 | 6.2 | 7.6 | 9.7 |

**Mono vs mono ranking** (mean win % against the other eight monos)

| Rank | Mono | Lowest-HP | Softest-role | Best against | Worst against | Mean wipe (s) |
|---|---|---|---|---|---|---|
| 1 | Pyro | 95 | 94 | Radiant (100) | Terra (66) | 7.3 |
| 2 | Terra | 83 | 84 | Toxin (100) | Pyro (34) | 13.5 |
| 3 | Toxin | 59 | 57 | Zephyr (97) | Pyro (0) | 12.1 |
| 4 | Cryo | 56 | 57 | Voltaic (100) | Terra (1) | 10.6 |
| 5 | Umbra | 47 | 46 | Voltaic (100) | Pyro (1) | 12.5 |
| 6 | Aqua | 41 | 43 | Radiant (92) | Pyro (4) | 10.1 |
| 7 | Zephyr | 29 | 28 | Umbra (75) | Pyro (0) | 9.9 |
| 8 | Radiant | 27 | 27 | Voltaic (98) | Pyro (0) | 12.9 |
| 9 | Voltaic | 13 | 12 | Aqua (50) | Cryo (0) | 7.9 |

**Strategy vs strategy** (first-named win %, lowest-HP / softest-role; wipe time pooled)

| Matchup | Win % | Wipe (s) |
|---|---|---|
| S1 vs S2 | 96 / 98 | 11.0 |
| S1 vs S3 | 54 / 53 | 11.8 |
| S1 vs S4 | 76 / 68 | 10.5 |
| S1 vs S5 | 84 / 83 | 12.0 |
| S2 vs S3 | 0 / 0 | 8.9 |
| S2 vs S4 | 32 / 70 | 13.0 |
| S2 vs S5 | 20 / 13 | 13.3 |
| S3 vs S4 | 100 / 92 | 8.2 |
| S3 vs S5 | 96 / 94 | 9.8 |
| S4 vs S5 | 80 / 58 | 12.0 |

Ranking (mean of both policies vs the other four): S3 84, S1 76, S4 38, S5 34, S2 18

**Weak comps** (weak comp's win %, lowest-HP / softest-role; wipe time pooled)

| Weak comp | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | vs Pyro | vs Aqua |
|---|---|---|---|---|---|---|---|
| W1 | 0 / 1 (9 s) | 22 / 8 (13 s) | 0 / 0 (7 s) | 2 / 4 (9 s) | 7 / 7 (11 s) | 0 / 0 (7 s) | 50 / 60 (11 s) |
| W2 | 9 / 11 (9 s) | 92 / 88 (10 s) | 0 / 2 (7 s) | 79 / 74 (8 s) | 80 / 79 (9 s) | 20 / 24 (7 s) | 98 / 98 (7 s) |

All 105 matchups: mean time to wipe 10.4 s; rounds that ran to the 90 s clock: 0.0%.

### 3.4 Pass 2 / Variant B (jump + double jump)

**Mono vs strategy** (mono win %, lowest-HP focus / softest-role focus; 200 rounds each)

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | Mono mean |
|---|---|---|---|---|---|---|
| Aqua | 0 / 0 | 8 / 4 | 0 / 0 | 7 / 2 | 2 / 3 | 4 / 2 |
| Cryo | 14 / 20 | 100 / 100 | 2 / 1 | 12 / 8 | 68 / 70 | 39 / 40 |
| Pyro | 12 / 19 | 92 / 74 | 0 / 0 | 94 / 86 | 93 / 94 | 58 / 55 |
| Radiant | 0 / 0 | 14 / 8 | 0 / 0 | 8 / 4 | 18 / 26 | 8 / 8 |
| Terra | 8 / 20 | 86 / 84 | 5 / 9 | 9 / 46 | 71 / 59 | 36 / 44 |
| Toxin | 0 / 0 | 30 / 6 | 0 / 0 | 0 / 4 | 10 / 16 | 8 / 5 |
| Umbra | 22 / 26 | 94 / 97 | 10 / 11 | 16 / 30 | 56 / 50 | 40 / 43 |
| Voltaic | 0 / 0 | 5 / 4 | 0 / 0 | 2 / 0 | 11 / 11 | 4 / 3 |
| Zephyr | 0 / 0 | 67 / 8 | 0 / 0 | 0 / 6 | 39 / 36 | 21 / 10 |
| **Strategy comp's mean win %** | **94 / 90** | **45 / 57** | **98 / 98** | **84 / 79** | **59 / 60** | **76 / 77** |

Strategy comp wins 60% or more in **35 / 45** (lowest-HP) and **35 / 45** (softest-role) matchups; the mono wins half or more in 10 and 8.

Time to team wipe (s, both policies pooled; the lowest-HP / softest-role split is in the CSV):

| Mono | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 |
|---|---|---|---|---|---|
| Aqua | 8.9 | 12.2 | 6.6 | 9.2 | 10.2 |
| Cryo | 13.3 | 13.3 | 8.8 | 9.9 | 14.8 |
| Pyro | 10.3 | 10.0 | 6.6 | 7.2 | 9.0 |
| Radiant | 10.3 | 14.5 | 7.6 | 12.0 | 14.9 |
| Terra | 13.9 | 17.1 | 11.9 | 13.7 | 16.4 |
| Toxin | 9.4 | 15.0 | 7.0 | 9.0 | 14.8 |
| Umbra | 13.1 | 15.6 | 10.4 | 13.9 | 16.2 |
| Voltaic | 6.6 | 7.9 | 5.3 | 6.4 | 9.0 |
| Zephyr | 7.7 | 11.6 | 6.3 | 7.7 | 10.7 |

**Mono vs mono ranking** (mean win % against the other eight monos)

| Rank | Mono | Lowest-HP | Softest-role | Best against | Worst against | Mean wipe (s) |
|---|---|---|---|---|---|---|
| 1 | Pyro | 96 | 96 | Radiant (100) | Terra (79) | 7.4 |
| 2 | Terra | 78 | 79 | Toxin (99) | Pyro (21) | 14.4 |
| 3 | Toxin | 61 | 61 | Voltaic (97) | Pyro (0) | 12.5 |
| 4 | Cryo | 58 | 56 | Voltaic (100) | Terra (1) | 10.7 |
| 5 | Umbra | 52 | 52 | Voltaic (100) | Pyro (1) | 12.5 |
| 6 | Zephyr | 44 | 44 | Aqua (84) | Pyro (0) | 9.8 |
| 7 | Radiant | 27 | 27 | Voltaic (97) | Pyro (0) | 13.3 |
| 8 | Aqua | 19 | 19 | Radiant (68) | Pyro (2) | 10.7 |
| 9 | Voltaic | 14 | 14 | Aqua (75) | Cryo (0) | 8.0 |

**Strategy vs strategy** (first-named win %, lowest-HP / softest-role; wipe time pooled)

| Matchup | Win % | Wipe (s) |
|---|---|---|
| S1 vs S2 | 98 / 98 | 10.9 |
| S1 vs S3 | 51 / 48 | 12.3 |
| S1 vs S4 | 76 / 64 | 10.6 |
| S1 vs S5 | 94 / 92 | 11.8 |
| S2 vs S3 | 0 / 0 | 8.9 |
| S2 vs S4 | 25 / 67 | 12.9 |
| S2 vs S5 | 33 / 20 | 15.1 |
| S3 vs S4 | 98 / 86 | 8.3 |
| S3 vs S5 | 98 / 96 | 9.7 |
| S4 vs S5 | 88 / 75 | 12.1 |

Ranking (mean of both policies vs the other four): S3 85, S1 78, S4 43, S5 26, S2 19

**Weak comps** (weak comp's win %, lowest-HP / softest-role; wipe time pooled)

| Weak comp | vs S1 | vs S2 | vs S3 | vs S4 | vs S5 | vs Pyro | vs Aqua |
|---|---|---|---|---|---|---|---|
| W1 | 0 / 0 (9 s) | 26 / 13 (13 s) | 0 / 0 (7 s) | 1 / 0 (9 s) | 13 / 14 (13 s) | 0 / 0 (6 s) | 78 / 80 (12 s) |
| W2 | 10 / 13 (9 s) | 93 / 88 (10 s) | 4 / 3 (7 s) | 86 / 70 (8 s) | 90 / 91 (9 s) | 16 / 21 (7 s) | 100 / 100 (7 s) |

All 105 matchups: mean time to wipe 10.7 s; rounds that ran to the 90 s clock: 0.0%.

## 4. Pass 1 vs Pass 2

**Answer: the Pass 2 HP spread mostly changes which comps win, not whether strategy beats stacking.**
- Strategy comps gain 3–4 points.
- It helps the comps with a Terra most (S1 +7, S5 +10).
- It hurts the comps built on the 120-HP flankers (S2 −3 to −5; mono-Voltaic falls to 2%, mono-Umbra to 34%).
- It lifts mono-Terra from 26% to 44%.

| Measure (lowest-HP / softest-role where split) | P1/A | P2/A | P1/B | P2/B |
|---|---|---|---|---|
| Strategy comps' mean win % vs monos | 75 / 76 | 79 / 80 | 72 / 74 | 76 / 77 |
| Of the 45, matchups the strategy comp wins ≥ 60% | 36 / 36 | 37 / 36 | 31 / 34 | 35 / 35 |
| Of the 45, matchups the mono wins ≥ 50% | 9 / 9 | 7 / 8 | 10 / 9 | 10 / 8 |
| Mean time to wipe (s) | 10.3 | 10.4 | 10.4 | 10.7 |
| Rounds that reached the 90 s clock | 0% | 0% | 0% | 0% |

| Comp (mean win % vs the nine monos, both policies) | P1/A | P2/A | Change | P1/B | P2/B | Change |
|---|---|---|---|---|---|---|
| S1 Terra + Radiant + Pyro | 86 | 93 | +7 | 85 | 92 | +7 |
| S2 Terra + Radiant + Voltaic | 57 | 54 | −3 | 56 | 51 | −5 |
| S3 Terra + Cryo + Pyro | 96 | 97 | +1 | 97 | 98 | +1 |
| S4 Radiant + Umbra + Pyro | 77 | 80 | +3 | 79 | 81 | +2 |
| S5 Cryo + Aqua + Terra | 62 | 72 | +10 | 48 | 59 | +11 |

| Mono (mean win % vs the five strategy comps) | P1/A | P2/A | Change | P1/B | P2/B | Change |
|---|---|---|---|---|---|---|
| Pyro | 62 | 52 | −10 | 65 | 56 | −9 |
| Umbra | 52 | 34 | −18 | 56 | 41 | −15 |
| Cryo | 38 | 33 | −5 | 43 | 39 | −4 |
| Terra | 26 | 44 | +18 | 22 | 40 | +18 |
| Aqua | 11 | 9 | −2 | 3 | 3 | 0 |
| Voltaic | 10 | 2 | −8 | 13 | 3 | −10 |
| Zephyr | 10 | 6 | −4 | 19 | 16 | −3 |
| Radiant | 8 | 3 | −5 | 13 | 8 | −5 |
| Toxin | 4 | 3 | −1 | 8 | 7 | −1 |

**Is the 230-HP Terra degenerate? No.**
- No round reaches the clock.
- Terra still dies in 36–40% of rounds (58–61% in Pass 1), at 11.3 s instead of 8.8 s.

**The 120-HP flankers are the casualty:**
- Voltaic dies in 90–92% of rounds, at 5.6 s.
- That drags S2 down.

**Mono-Pyro under Pass 2:**
- It now loses to S1 (8–19%), whose Terra survives longer.
- It still beats S2, S4 and S5 by 61–98%.

## 5. Variant A vs Variant B

**Answer: a jump option matters only for ground-based control, and not for how fast fights resolve.**
- **Strategy comps** lose about 3 points with a jump, and almost all of it is S5 (−13 to −14 points). Riptide becomes hoppable (35% of waves at range), and so do Flash Freeze's ring, Aftershock and Earthen Tomb's fissure.
- **Monos:** mono-Aqua collapses to 3%, and mono-Zephyr gains about 9 points (Updraft while airborne).
- **Fight length:** rounds last 0.1–0.3 s longer.

| Measure | P1/A | P1/B | Change | P2/A | P2/B | Change |
|---|---|---|---|---|---|---|
| Strategy comps' mean win % vs monos (lowest-HP / softest-role) | 75 / 76 | 72 / 74 | −3 / −2 | 79 / 80 | 76 / 77 | −3 / −3 |
| S5 vs the nine monos | 62 | 48 | −14 | 72 | 59 | −13 |
| Mono-Aqua vs strategy | 11 | 3 | −8 | 9 | 3 | −6 |
| Mono-Zephyr vs strategy | 10 | 19 | +9 | 6 | 16 | +10 |
| Mono-Cryo vs strategy | 38 | 43 | +5 | 33 | 39 | +6 |
| Mean time to wipe (s) | 10.3 | 10.4 | +0.1 | 10.4 | 10.7 | +0.3 |

### Full-Pyro and the other stacks vs the five strategy comps

**The owner's intuition holds for one comp, not as a rule.**
- **S3 beats every mono** in every configuration. Its closest call is mono-Umbra under softest-role focus (62–71%); otherwise 88–100%.
- **S1 beats every mono** except mono-Pyro in Pass 1 (79% under lowest-HP focus, 22% under softest-role) and mono-Umbra under softest-role (57%).
- **Exceptions** where a stack beats a strategy comp in Pass 1 / Variant A:
  - Mono-Pyro beats S2 (92 / 59), S4 (87 / 84) and S5 (94 / 92).
  - Mono-Umbra beats S2 (98 / 96) and S5 (64 / 59), and S1 under softest-role (57).
  - Mono-Cryo beats S2 (96 / 99) and S5 (57 / 60).
  - Mono-Terra beats S5 under lowest-HP (54), and S2 under softest-role (55).
- S2 and S5 are not reliably better than a stack.
- **Targeting policy:** softest-role focus kills the enemy support first in 97–99% of rounds (45% under lowest-HP). It moves the averages only 1–2 points.
- **Softest-role can backfire:** it can decide a matchup the wrong way. Against S1, mono-Pyro wins 79% when it kills Terra first and 22% when it chases Radiant. Terra walls for Radiant about once a round. Radiant heals too little to be worth the time, while S1's Pyro and Terra keep shooting.

## 6. Mana and spam (team context)

These flags are separate from the 1v1 audit's, which found "every M1 except Light Lance costs less than the regen, so
firing never costs a decision". That is still true, and in a team it decides the fight. **M1s do 69% of all damage**
(67–71% in every configuration and in the live check), Ultimates 12%, reactions under 2%.

| Element | Damage/s per player | M1's share of its damage | Time at full mana | Time under 10 mana |
|---|---|---|---|---|
| Pyro | **28.5** | 66% (Fireball) | 13% | 0% |
| Voltaic | 18.0 | 46% (+13% chain jumps) | 24% | 0% |
| Zephyr | 17.9 | 66% | **57%** | 0% |
| Cryo | 17.4 | 77% | **44%** | 0% |
| Toxin | 16.7 | 57% (+20% its poison) | 20% | 0% |
| Aqua | 16.0 | 59% | 20% | 0% |
| Umbra | 12.0 | 100% | **44%** | 0% |
| Terra | 10.7 | 52% | 23% | 7% |
| Radiant | 9.4 | 100% (Light Lance) | 20% | 6% |

**(a) Costs that only make sense across a short duel.** This premise did not hold: a 3v3 round here is as short as a
duel, 10.3 s to a wipe (14.0 s with cover).
- Every ability with a cooldown of 9 s or more fires about once a round, at the opening, from a full 100-mana bar.
- No Element runs dry. Zephyr, Cryo and Umbra sit on a full bar for 44–57% of their lives.
- So no cost becomes "free" over a long engagement here; costs are already irrelevant.
- **Conditional flag:** this changes the moment rounds get longer (more HP, cover, objectives, respawns). The first costs to stop mattering would be the cheap utility ones: Undertow 25, Blizzard 28, Gust Pad 20, Mark 18, Decoy Double 18, Shadow Step 20. They are already cast whenever ready.

**(b) Cheap, repeatable finishers once damage is shared.** These are measured as the share of an Element's kills an
ability takes against its share of the damage, plus how much of the victim's damage the killer itself had done.

| Ability | Cost | Share of the Element's damage | Share of its kills | Killer's own share of the victim's damage |
|---|---|---|---|---|
| **Chain Bolt** (Voltaic M1) | 2 mana, 0.32 s, hitscan | 46% | **69%** | 47% |
| **Detonate** (Pyro) | 20, 14 s | 2% | 10% | 63% |
| Leviathan's Maw (Aqua Ultimate) | charge | 16% | **50%** | 64% |
| Earthen Tomb (Terra Ultimate) | charge | 16% | 34% | 56% |
| Cyclone / Mirror Cage / Ring of Fire | charge | 15–18% | 24–28% | 50–64% |
| Toxic Bubbles (Toxin M1) | 3, 0.55 s | 57% | 65% | 44% |
| Boulder Shot (Terra M1) | 4, ~2 s | 52% | 48% | **34%** |

- **Chain Bolt** is the team-specific spam finisher. It is hitscan, landing about 95% of bolts on a strafing target at 20 studs, and costs nothing net. It takes kills well out of proportion to its damage. Its free chain jump (5 to a second body each bolt) is another 13% of Voltaic's damage.
- **Detonate** is a pure "finish someone else's damage" execute: 12 + 36 × (missing ÷ 75%), with no line of sight needed. Its 1.5 s fuse wastes most casts: the target is usually dead before it pops.
- **Ultimates** are the real finishers of team play: 12% of damage, but a quarter to half of each Element's kills.
- **M1 kills are shared work:** the killer had done only 34–52% of the victim's damage.

**Ultimate charge (per player).**
- 0.9–1.9 of a team's three Ultimates come online in a round, at 6–10 s on average.
- Two land within 3 s of each other in 6–37% of rounds; all three within 6 s in 0–14% (most often for mono-Radiant).
- Within one round, that is no degenerate cluster.
- **Flag:** charge carries between rounds in a Duel-style match. Players leave a round with 0.58 (winners) to 0.71 (losers) charge, and 23% of the losers are full. So from round 2 on, most Ultimates are seconds away at the start, and the losing team has two or more ready at the start 13% of the time (all three: 1%).

## 7. Reactions

Reactions were simulated hit by hit in every round. A team can only consume a status its own players put on the enemy,
and no Element reacts to a status it applies itself. So **all nine mono-comps are reaction dead ends under default
loadouts, not only Terra, Radiant and Umbra.** The other six have trigger rules but nothing to trigger them on:

| Comp | Reaction pair inside the comp | Reactions per round (P1/A) | Reaction damage per round | Win % vs the nine monos, reactions on → off |
|---|---|---|---|---|
| Terra ×3, Radiant ×3, Umbra ×3 | none: no trigger rules at all | 0 | 0 | — |
| Pyro, Cryo, Toxin, Voltaic, Aqua ×3 | none: their rules need another Element's status | 0 | 0 | — |
| Zephyr ×3 | Toxic Squall only, and it grows the enemy Toxin's cloud | 0.3 | 0 | — |
| S1 Terra + Radiant + Pyro | **none** (no Element in S1 reacts to Burning, and nothing Pyro reacts to is applied) | 0 | 0 | 86 → 86 |
| S2 Terra + Radiant + Voltaic | **none** | 0 | 0 | 57 → 57 |
| S3 Terra + Cryo + Pyro | Melt, both ways | 5.5 | 75 | 96 → 92 |
| S4 Radiant + Umbra + Pyro | **none** | 0 | 0 | 77 → 77 |
| S5 Cryo + Aqua + Terra | Frozen (Aqua hits on Cryo's Chill) | 1.7 | 0 (2 s roots) | 62 → 60 |
| W1 Aqua + Toxin + Zephyr | Toxic Squall | 0.7 | 0 | 33 → 32 |
| W2 Pyro + Pyro + Voltaic | **Overload, both ways** | 3.7 | 43 + 0.6 s stagger each | **83 → 59** |

(The "reactions off" column is a re-run of all 105 Pass 1 / Variant A matchups with every reaction disabled, like the
live `ReactionsOff` switch.)

**Does reaction access separate strategy comps from mono-comps?** No.
- Three of the five strategy comps have no pair at all, because the comps were built around roles, not reactions.
- **S3** is the best comp, but mostly through its kit: Melt is worth only 4 points to it. Melt also consumes the Chill and the roots that are S3's control, so S3's Pyro strips its own Cryo's slows every 0.75 s. Shatter does the same to a root.
- **W2 has the most valuable pair in the game.** Overload's stagger and knockback are worth 24 points to it, and they turn a "deliberately weak" comp into the third-best comp here.
- Reactions are under 2% of all damage, but their crowd control is not small.

## 8. Technique-swap self-combo check (P25)

Each mono-comp keeps its locked M1, Primary, Passive and Ultimate, and all three players take the same swapped
Technique. The opponent is **S3**, the strongest strategy comp in Pass 1 / Variant A (96% vs the monos). The test is
Pass 1 / Variant A, 200 rounds per policy.
- Every single swap was searched (33 per Element). The picks were then re-run on fresh seeds, because the winner of a 33-way search is inflated by luck.
- Each pick was played two ways: **for the combo**, where the reacting Technique waits up to 4 s for its own status to be on the target, and **on cooldown**.
- Single swaps can open a reaction for Cryo, Pyro, Toxin, Voltaic and Zephyr only. **Aqua has none**: only Icicle Shard (an M1) applies Chilled. **Terra, Radiant and Umbra have none**: no trigger rules. For those four, the best two-slot swap is shown as a ceiling.
- The best swap of any kind, which needn't add a reaction, is shown for comparison.

| Mono | Default vs S3 | Swap | Reaction it adds | Played for the combo | Cast on cooldown | Reactions/round |
|---|---|---|---|---|---|---|
| Aqua | 2% | Scorching Lash + Volt Orb (both slots) | Overload | 12% (12/14) | 14% (12/17) | 0.3 / 0.0 |
| Aqua | 2% | Twin Tide + Volt Orb | none (raw power) | 8% (8/8) | 13% (13/13) | 0.0 / 0.0 |
| Cryo | 2% | Blizzard + Railspike | Shatter | 7% (2/12) | 20% (7/32) | 1.0 / 0.7 |
| Cryo | 2% | Blizzard + Bulwark Wall | none (raw power) | 23% (9/38) | 20% (6/35) | 0.0 / 0.0 |
| Pyro | 7% | Detonate + Volt Orb | Overload | 22% (12/32) | 37% (39/35) | 0.9 / 0.8 |
| Pyro | 7% | Bulwark Wall + Scorching Lash | none (raw power) | 54% (74/34) | 59% (81/38) | 0.0 / 0.0 |
| Radiant | 0% | Scorching Lash + Volt Orb (both slots) | Overload | 18% (36/0) | 7% (10/4) | 0.6 / 0.0 |
| Radiant | 0% | Position Trade + Bulwark Wall | none (raw power) | 16% (16/16) | 18% (16/20) | 0.0 / 0.0 |
| Terra | 6% | Scorching Lash + Volt Orb (both slots) | Overload | 59% (37/82) | 50% (44/56) | 0.9 / 0.0 |
| Terra | 6% | Aftershock + Scorching Lash | none (raw power) | 28% (8/48) | 23% (6/40) | 0.0 / 0.0 |
| Toxin | 0% | Scorching Lash + Acid Rain | Combustion | 0% (0/0) | 0% (0/0) | 1.3 / 1.3 |
| Umbra | 18% | Mark + Bulwark Wall | none (raw power) | 45% (40/51) | 42% (36/48) | 0.0 / 0.0 |
| Voltaic | 1% | Scorching Lash + Volt Orb | Overload | 2% (0/4) | 0% (1/0) | 2.5 / 1.2 |
| Zephyr | 0% | Scorching Lash + Gust Pad | Wildfire | 0% (0/0) | 0% (0/0) | 1.2 / 1.2 |

**Verdict: self-combo recovers almost no ground through the reactions themselves.**
- **The reactions are small:** the self-combo loadouts set off 0.3–2.5 reactions a round. A combo adds at most about 9 points (Terra's two-slot Lash + Volt Orb: 59% for the combo, 50% on cooldown).
- **Playing for the combo usually costs more than it pays:** for Pyro and Cryo, waiting for the status loses more damage than the Overload or Shatter adds.
- **The ground that swapping does recover comes from raw strength:**
  - Bulwark Wall: Pyro 7% → 54–59%, Umbra 18% → 42–45%, Cryo 2% → 20–23%.
  - Scorching Lash and Volt Orb: Terra 6% → 50–59%.
- **For P25:** restricting swaps to stop self-combos is not needed. If swaps are restricted for team mode, the reason is that Bulwark Wall (no cooldown) and Scorching Lash (2.5 s in this dataset; 5 s live) make any kit stronger.

## 9. Peel and protection

Uses per round, Pass 1 / Variant A, both policies. The percentage is the share of uses after which the protected ally
was still alive 4 s later.

| Comp | What its peel actually did | Healing per round | Absorbed per round |
|---|---|---|---|
| S1 Terra + Radiant + Pyro | Bulwark Wall 0.8 (56%), Blessing 0.5 (71%), Benediction 0.5 (53%), Position Trade 0.1 (16%), Bulwark Charge on a diver 0.1 | Benediction 17, Halo lifesteal 12 | Wall 81, Blessing 34 |
| S2 Terra + Radiant + Voltaic | Bulwark Wall 1.0 (47%), Benediction 0.6 (49%), Blessing 0.5 (69%), Bulwark Charge 0.2, Aftershock 0.2, Position Trade 0.1 (5%) | Benediction 22, Halo 21 | Wall 90, Blessing 35 |
| S3 Terra + Cryo + Pyro | Deep Freeze on a diver 0.9 (37%), Bulwark Wall 0.5 (51%), Icicle on a diver 0.4, Flash Freeze 0.1 (23%) | 0 | Wall 61 |
| S4 Radiant + Umbra + Pyro | Benediction 0.1 (46%), nothing else | Halo 13, Benediction 2 | Blessing 34 |
| S5 Cryo + Aqua + Terra | Bulwark Wall 1.2 (41%), Sidearm knock 1.0 (46%), Deep Freeze 0.7 (82%), Icicle on a diver 0.6, Flash Freeze 0.4 (76%), Bulwark Charge 0.2 | 0 | Wall 71 |

| Labelled role | Did it work? |
|---|---|
| **Terra as tank** (S1, S2, S3, S5) | **Yes, the only protection that moves numbers.** The wall absorbs 61–90 a round, and covers an ally 0.5–1.2 times a round. Under softest-role focus it is what keeps S1's Radiant alive. Bulwark Charge on divers almost never fires (0.1–0.2 a round): Terra is already in front. |
| **Radiant as support** (S1, S2, S4) | **Only Blessing works** (0.5 a round, ally alive 4 s later 69–71%). Benediction heals 17–22 a round in S1 and S2, about 5% of the damage the team takes: the round is over before the channel pays. Position Trade fires 0.1 a round and saves the ally 5–16% of the time, because it moves Radiant into the line of fire and the ally is already low. |
| **S2's support** | **Fails by layout.** Its carry, Voltaic, dives to 12–24 studs while Radiant stays at 30–50, outside Benediction's 25. S2's Voltaic dies in 69% of rounds. |
| **S4's support** | **No working peel loop.** There is no tank, and Umbra (70–110) and Pyro (25–45) stand too far apart for Benediction. Radiant is a damage dealer here. S4 wins on Pyro and Umbra's damage (77%). |
| **Cryo as control standing in for sustain** (S3) | **Works, but through damage, not survival.** Deep Freeze and Chill slow divers, and Melt adds 75 damage a round. Flash Freeze (r20 around Cryo) rarely reaches anyone, because Cryo stands 40–65 back. |
| **S5's control** | **Works on flat ground** (Deep Freeze 82%, Flash Freeze 76% ally alive), **and breaks with a jump** (−14 points). |

**Mobility tools shaped for 1v1:**

| Tool | In 3v3 |
|---|---|
| Shadow Step | Cast 0.2 times a minute. Umbra kites at 70–110 and is rarely reached. When three players close, a 22-stud blink buys under a second. |
| Overcharge | Its 11-stud dash mostly closes the last gap; as an escape it is 0.4 s of running. |
| Skyrider | At 42 / 55 studs/s (60 / 75 live) it is the one tool that outruns a team. A solo dive on it lands one Zephyr alone among three, so the sim uses it only to join a fight or leave one. |
| Position Trade | See Radiant above. |

## Live-values check (dataset L)

The same 420 matchups on today's live values (see "Numbers used"). **The conclusions hold.**

| Measure (P1/A) | Prompt numbers (P) | Live values (L) |
|---|---|---|
| Strategy comps' mean win % vs monos (lowest-HP / softest-role) | 75 / 76 | 75 / 78 |
| S1 / S2 / S3 / S4 / S5 vs the monos | 86 / 57 / 96 / 77 / 62 | 90 / 62 / 97 / 73 / 61 |
| Mono-Pyro vs strategy comps | 62 | 65 |
| Mono-Terra vs strategy comps | 26 | 40 (Boulder Shot at 200 studs/s) |
| Mono-Umbra vs strategy comps | 52 | 43 |
| Pyro damage per player per second | 28.5 | 30.3 |
| Reactions per round: S3 Melt / S5 Frozen / W2 Overload | 5.5 / 1.7 / 3.7 | 5.0 / 2.2 / 3.4 |
| Mean time to wipe | 10.3 s | 9.7 s |

The policy gap gets wider live: mono-Pyro beats S1 84% under lowest-HP focus and 8% under softest-role.

## Cover sensitivity

The main run has no cover. A re-run of Pass 1 / Variant A blocks 40% of aimed shots (Fireball counted once per throw).

| Measure | Open floor | 40% cover |
|---|---|---|
| Mean time to wipe | 10.3 s | 14.0 s |
| Strategy comps' mean win % vs monos | 75 / 76 | 74 / 75 |
| Healing as a share of damage | 6.2% | 4.7% |
| Mono-Pyro vs strategy comps | 62 | 71 (area damage ignores cover) |

Cover lengthens rounds but changes neither the strategy gap nor the support's weight.

## What-if checks behind the recommendations

Pass 1 / Variant A, prompt numbers, 200 rounds per matchup per policy, one change at a time. Strategy, S1–S5 and W2 columns are mean win % against the nine monos; mono columns are mean win % against the five strategy comps.

| Run | Strategy mean vs monos | S1 | S2 | S3 | S4 | S5 | mono-Pyro vs strategy | mono-Voltaic | W2 vs strategy | Wipe (s) | Healing / damage | Pyro dps | Voltaic dps |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| main P1/A | 76 | 86 | 57 | 96 | 77 | 62 | 62 | 10 | 69 | 10.3 | 6.2% | 28.5 | 18.0 |
| all HP 250 | 79 | 88 | 55 | 97 | 85 | 68 | 63 | 3 | 69 | 13.9 | 7.2% | 35.9 | 20.6 |
| Fireball splash 5 in r4 | 75 | 85 | 57 | 96 | 76 | 62 | 60 | 10 | 69 | 10.4 | 6.3% | 27.6 | 18.1 |
| Chain Bolt range 45 | 77 | 86 | 70 | 96 | 73 | 59 | 61 | 21 | 73 | 10.2 | 6.2% | 28.5 | 21.7 |
| Overload 2.5 s per body | 76 | 86 | 57 | 96 | 77 | 62 | 62 | 10 | 63 | 10.3 | 6.2% | 28.5 | 17.9 |
| HP 250 + Benediction 30/s, r35, no root | 80 | 91 | 64 | 97 | 82 | 65 | 60 | 2 | 66 | 14.4 | 10.1% | 36.0 | 20.3 |
| Fireball 15 every 0.7 s (splash 6) | 74 | 82 | 59 | 94 | 70 | 64 | 50 | 11 | 66 | 11.0 | 6.6% | 23.9 | 18.4 |

## 10. Recommendations

Every "what-if" below was run: Pass 1 / Variant A, prompt numbers, all 105 matchups, 200 rounds per policy, one change
at a time. The table is in "What-if checks" above.

1. **Allow each Element once per team in 3v3.**
   - **Why:** this removes the whole exception class at once: the mono-stacks, and the double-Pyro W2. Mono-Pyro beats S1, S2, S4 and S5 in Pass 1, and W2 beats S2, S4 and S5. The Fireball nerf below only gets mono-Pyro to 50%.
   - **Target:** no comp with duplicates. That still leaves 84 legal comps.
   - **Confidence:** high that it removes the exception; the 84 comps themselves were not simulated.
2. **Pyro's Fireball in team mode: 18 every 0.6 s → 15 every 0.7 s.** Leave the splash; the splash is not the lever (5 damage in r4 changed mono-Pyro only 62 → 60).
   - **Effect, tested:** Pyro's damage per player falls 28.5 → 23.9 (still the highest, 1.3× Voltaic), and mono-Pyro falls 62 → 50%.
   - **Side effect:** the Pyro strategy comps lose 2–7 points.
   - **Target:** Pyro ≤ 1.25× the next Element's damage per player.
   - **Confidence:** medium.
3. **Make healing matter before tuning roles: everyone 250 HP in team mode, with Benediction at 30 HP/s, radius 35, no root.**
   - **Tested:** healing goes from 9–10% to 25–27% of the damage S1 and S2 take. S1 rises 86 → 91% and S2 57 → 64%; rounds run 14.4 s.
   - **250 HP alone only stretches rounds** (13.9 s); healing stays at 7%.
   - **Radiant's damage is not too high in team play:** it is the lowest per player, at 9.4/s. So don't cut it for this mode.
   - **Target:** healing ≥ 25% of damage taken in healer comps; mean round ≥ 14 s.
   - **Confidence:** medium.
4. **Chain Bolt range 30 → 45 in team mode.**
   - **Tested:** S2 rises 57 → 70% and mono-Voltaic 10 → 21%.
   - **Side effect:** W2 rises 69 → 73%.
   - **Target:** S2 ≥ 70% vs monos, and Voltaic dying in ≤ 65% of rounds (69% in S2 now).
   - **Confidence:** medium.
5. **Overload's per-body cooldown 0.75 → 2.5 s, or a shorter stagger.**
   - **Tested:** W2 falls 69 → 63% vs strategy comps. With reactions off it is 49%, so Overload's stagger is the lever.
   - **Target:** W2 ≤ 60% vs strategy comps, with Overload still worth no more than Melt is to S3 (4 points).
   - **Confidence:** medium.
6. **Give every role comp a reaction pair, and stop reactions eating the control they need.** S1, S2 and S4 have no pair; Melt and Shatter consume the Chill and roots that S3's and S5's control is built on.
   - **Option:** switch on Terra's dormant Cracked (from Aftershock and Bulwark Charge), with a Pyro rule and a Voltaic rule.
   - **Option:** let Melt consume Chill only, never a root.
   - **Target:** each of S1–S5 sets off ≥ 1 reaction a round, and a Cryo root survives a Pyro hit.
   - **Confidence:** low; this is design, and untested.
7. **P25 (Technique swapping): no restriction is needed for self-combos.** They add at most about 9 points against S3. Instead, check Bulwark Wall's HP per deploy in Studio.
   - **If each deploy is a fresh 200:** give it a cooldown after release in team mode (about 6 s). As a swap, it lifts Pyro 7 → 54–59% and Umbra 18 → 42–45% against S3.
   - **Target:** no single swapped Technique adds more than 15 points against S3.
   - **Confidence:** medium; it depends on that Studio check.
8. **If team mode keeps the jump, make ground control catch low airborne bodies.** Jumping costs S5 13–14 points.
   - **Change:** Riptide's 3.5 studs of height → 6; Flash Freeze, Aftershock and Earthen Tomb also hit bodies within ~6 studs of the ground.
   - **Target:** S5 within 5 points between Variants A and B.
   - **Confidence:** low to medium (untested).
9. **If the movement switch ships, return Skyrider to 42 / 55 in team mode.**
   - **Why:** against a 25 studs/s run, the 17 Oct buff (60 / 75) makes it 2.4–3× faster than anyone else on the floor.
   - **Target:** ≤ 2.2× running speed.
   - **Confidence:** low; it was not stress-tested here, since the sim only used Skyrider to join or leave fights.
10. **Republish the 1v1 results with the timing fix before any more 1v1 tuning.** Zephyr's best-play rate goes from 16% to 62%, and the dashboard still shows the old numbers.
    - **Target:** every published 1v1 number comes from `sim_m1fix.py`.
    - **Confidence:** high.

## 11. Open questions

1. **Coverage.** All 420 matchups ran in full, with both policies and 200 rounds each. So did the 9 step-8 matchups (on fresh seeds), and nothing from Pass 2 is missing. On top of that:
   - a full live-values repeat;
   - a cover check, a reactions-off check, and four what-ifs (all Pass 1 / Variant A).
2. **Kit mobility kept live (the prompt's stated assumption).** Shadow Step, Overcharge, Bulwark Charge, Cross-Slash and Skyrider were left in. If those should go too, Umbra and Zephyr lose their only escapes, and Skyrider stops being the fastest thing on the floor.
3. **The open floor.** There is no cover except Bulwark Wall, and rounds last about 10 s. Cover (40% of aimed shots blocked) stretches rounds to 14 s without changing a conclusion; corridors, objectives or respawns might. Not modelled:
   - Twin Tide's walls blocking bodies;
   - Gust Pad as a launcher for allies;
   - Aqua's wet ground beyond a 15% slip.
4. **The behaviour model.** One range band per Element and the same play for every team. Telegraphs are noticed 80% of the time; there is no regrouping and no peeking. Coordinated humans would place S2's and S4's Radiant better, for example inside Benediction's 25 of its carry. So treat the support numbers as a floor.
5. **Bulwark Wall's HP per deploy is not in the dataset.** The sim gives each deploy a fresh 200 HP, holds it for 2.5 s at most, and waits 2 s between holds. If a redeploy keeps the damaged HP, the wall, and the "Bulwark Wall makes any kit strong" finding, shrink. This is worth one Studio check before acting on the step-8 verdict.
6. **Values I had to interpret:**
   - Patient Zero's 3.5 s telegraph: the caught enemy bursts on its own teammates.
   - Leviathan's Maw: 65 bite and 25 surge both land on a trapped target.
   - Gust Pad: a 0-damage Zephyr hit that can still react.
   - Acid Rain ticks react, while poison and cloud ticks don't.
   - Charged under the prompt's numbers needs a second body within 16.
   - Detonate puts no Burning on.
7. **Ultimate carry-over.** Every simulated round starts at 0 charge, as round 1 does. Later rounds start at 0.58–0.71 charge per player. A whole-match run (first to 5) would show whether that tilts matches toward the team that just lost.
8. **Role labels for softest-role focus.** The prompt's role table makes only Radiant and Cryo "Controller/Support". Under the owner's earlier view (Cryo, Aqua and Toxin as control), W1 and S5 would be targeted differently.
9. **Shadow Dart is (PROP).** Its 65 damage per 2.6 s at 160 studs decides every Umbra number. It was not re-checked in Studio, per the prompt.
10. **The earlier 1v1 results were wrong for fast M1s.** The 1v1 sim's 0.1 s step understated Wind Blade by 40%, Chain Bolt by 20% and Icicle Shard by 17%. Corrected best-play win rates: Zephyr 16% → 62%, Radiant 66 → 52, Toxin 46 → 31, Voltaic 32 → 23. The balance dashboard still shows the old numbers; the correction is in `balance_2026_10_17/RERUN_RESULTS.md`. This team sim fires at the exact rates.
11. **The prompt's numbers predate the 17 Oct balance pass** (see "Numbers used"). Every matchup was repeated on today's live values, and the conclusions hold.
12. **One Element per team (recommendation 1) is untested beyond removing the stacks.** The 84 legal comps were not run. A round-robin of those is the natural next simulation, best run after the support package (recommendation 3), so its rankings reflect the mode you would actually ship.

## Appendix: ability economy in team play

Pass 1 / Variant A, both policies, every comp. Damage per mana excludes M1 mana for abilities. "Casts/min per player"
runs above the cooldown cap for long cooldowns, because every ability starts each round ready.

| Element | Ability | Damage per mana | Casts/min per player | Cooldown cap /min | Share of Element's damage | Share of Element's kills | Killer's own share of a kill |
|---|---|---|---|---|---|---|---|
| Aqua | Riptide | 3.4 | — | — | 59% | 44% | 40% |
| Aqua | Maw | — | 3.3 | — | 16% | 50% | 64% |
| Aqua | SA | 0.8 | 11.0 | — | 15% | 3% | 38% |
| Aqua | TT | 0.4 | 5.9 | 3.8 | 11% | 3% | 29% |
| Aqua | UT | 0.0 | 5.6 | 6.7 | 0% | 0% | — |
| Cryo | Icicle | 2.5 | — | — | 77% | 67% | 40% |
| Cryo | Cage | — | 2.3 | — | 16% | 27% | 56% |
| Cryo | Melt | — | — | — | 5% | 5% | 36% |
| Cryo | FF | 0.3 | 1.0 | 4.3 | 1% | 1% | 40% |
| Cryo | DF | 0.1 | 3.6 | 3.8 | 1% | 0% | 34% |
| Cryo | BZ | 0.0 | 5.0 | 3.3 | 0% | 0% | — |
| Pyro | Fireball | 4.4 | — | — | 66% | 55% | 52% |
| Pyro | RoF | — | 5.5 | — | 15% | 24% | 64% |
| Pyro | LS | 1.0 | 9.5 | — | 7% | 3% | 53% |
| Pyro | LashBurn | — | — | — | 4% | 2% | 65% |
| Pyro | Burn | — | — | — | 3% | 3% | 65% |
| Pyro | Melt | — | — | — | 3% | 3% | 60% |
| Pyro | DT | 0.2 | 8.0 | 4.3 | 2% | 10% | 63% |
| Pyro | Overload | — | — | — | 0% | 0% | 46% |
| Pyro | Combustion | — | — | — | 0% | 0% | 92% |
| Pyro | IM | 0.0 | 10.6 | 5.0 | 0% | 0% | — |
| Radiant | Lance | 1.6 | — | — | 100% | 100% | 41% |
| Radiant | Halo | — | 2.8 | — | 0% | 0% | — |
| Radiant | BL | 0.0 | 7.4 | 5.0 | 0% | 0% | — |
| Radiant | BN | 0.0 | 3.8 | 3.5 | 0% | 0% | — |
| Radiant | PT | 0.0 | 0.3 | 4.3 | 0% | 0% | — |
| Terra | Boulder | 6.4 | — | — | 52% | 48% | 34% |
| Terra | BC | 1.1 | 3.8 | 6.7 | 19% | 10% | 28% |
| Terra | Tomb | — | 2.0 | — | 16% | 34% | 56% |
| Terra | AS | 1.0 | 4.1 | 5.0 | 13% | 7% | 36% |
| Terra | BW | 0.0 | 10.3 | — | 0% | 0% | — |
| Toxin | Bubbles | 1.9 | — | — | 57% | 65% | 44% |
| Toxin | Poison | — | — | — | 20% | 15% | 47% |
| Toxin | CC | 0.5 | 8.1 | 6.7 | 10% | 7% | 43% |
| Toxin | PZ | — | 4.1 | — | 8% | 7% | 44% |
| Toxin | AR | 0.3 | 6.1 | 4.3 | 6% | 5% | 37% |
| Toxin | AV | 0.0 | 0.1 | 3.8 | 0% | 0% | — |
| Umbra | Dart | 6.7 | — | — | 100% | 100% | 42% |
| Umbra | DD | 0.0 | 4.2 | 3.0 | 0% | 0% | — |
| Umbra | MK | 0.0 | 5.9 | 4.3 | 0% | 0% | — |
| Umbra | Eclipse | — | 2.0 | — | 0% | 0% | — |
| Umbra | SS | 0.0 | 0.2 | 6.0 | 0% | 0% | — |
| Voltaic | ChainBolt | 3.2 | — | — | 46% | 69% | 47% |
| Voltaic | RS | 1.3 | 8.9 | 6.0 | 21% | 4% | 54% |
| Voltaic | Chain | — | — | — | 13% | 1% | 37% |
| Voltaic | VO | 0.7 | 8.1 | 5.0 | 11% | 7% | 38% |
| Voltaic | Cascade | — | 4.5 | — | 7% | 17% | 61% |
| Voltaic | Overload | — | — | — | 3% | 3% | 38% |
| Voltaic | OC | 0.0 | 7.6 | 6.7 | 0% | 0% | — |
| Zephyr | WindBlade | 3.2 | — | — | 66% | 63% | 44% |
| Zephyr | Cyclone | — | 3.3 | — | 18% | 28% | 50% |
| Zephyr | CS | 1.4 | 4.5 | 6.0 | 15% | 8% | 37% |
| Zephyr | SK | 0.2 | 2.1 | 5.0 | 1% | 0% | 33% |
| Zephyr | GP | 0.0 | 5.5 | 4.3 | 0% | 0% | 2% |
