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
