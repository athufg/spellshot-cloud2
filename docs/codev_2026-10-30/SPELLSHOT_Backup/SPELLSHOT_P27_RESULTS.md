# SPELLSHOT P27: Voltaic and Umbra self-sufficiency, tested in the 3v3 sim

18 October 2026. The owner's P27 spec, run on top of team package v3 (see `SPELLSHOT_TEAM_MODE_PACKAGES.md`). The
numbers were fact-checked against the raw results and the sim's code by independent checkers, and one missing control
was run because of that check.

## Answer

**Self-escape tools don't fix Voltaic or Umbra. Making Umbra's dive pay off helps a little.**

- **Static Discharge leaves Voltaic slightly worse** in every variant (−0.7 to −1.4 points), and the bigger the tool, the worse it gets. Its death rate doesn't improve (71% → 72%), while its damage drops: the retreat carries it out of its 45-stud Chain Bolt range.
- **Umbra's defensive Shadow Step options stay within noise:** the 0.3 s vanish, a 1 s vanish, and the half cooldown on its own.
- **Dive play** (blinking in on a low target) is worth +1.2 on its own. It takes one of Umbra's three bottom-6 comps (Cryo + Umbra + Voltaic) out of the bottom 6.
- **The half cooldown on top of dive play adds +0.9** against a matching control, which is above noise. Umbra rises +2.3 in total, 42.3% → 44.6%.
  - Most of the extra Shadow Steps are dive-ins (1.18 → 1.56 a round). Under-fire blink-outs also rise (0.22 → 0.39 a round). Without dive play, extra blink-outs alone did nothing (+0.0), so the gain most likely comes from diving more often.
  - Umbra's bottom-6 count stays at 2. One Umbra comp (Cryo + Terra + Umbra) edges into the top 6, a one-comp move that can be noise.
- **Together** (either Static Discharge plus dive play and the half cooldown):
  - Umbra 44.7–44.8% (+2.4 to +2.5).
  - Voltaic back where it started, 44.4% (+0.2): Static Discharge cancels the small lift a diving Umbra gives it.
  - Terra 70.8% → 68.6%, and the spread between comps 20.1 → 19.2 points.
  - It doesn't relocate the gap: Umbra enters the top 6 once (alongside Terra), and Voltaic's bottom-6 count goes 5 → 4. Single-comp moves like these can be noise (see Caveats).
- **In the sim, Umbra can't blink out mid-dive.**
  - The dive-in spends Shadow Step, and even halved (5 s), its cooldown outlasts the bot's 4 s dive. So Umbra starts walking back out, and can blink again only once the step returns, about 1 s after the dive.
  - A player who stays in for 5 s or more could blink out under the halved cooldown; that wasn't tested.
- **The gap isn't about Voltaic and Umbra surviving on their own.** In every run, every bottom-6 comp has neither Terra nor Pyro, and every top-6 comp has Terra. The weak comps lack the team's protection and its damage; an escape tool fixes neither.

## Setup

- **Base:** team package v3 on today's live values (`SPELLSHOT_TEAM_MODE_PACKAGES.md`).
- **Test:** the 84-comp round-robin (3,486 pairings), no jump, lowest-HP focus, "cover each other's back" teamwork on, 6 rounds per pairing.
- **Noise:** the baseline was run twice on different seeds. Each Element moved by at most 0.5 points, and single comps by about ±2.3 points (one SD; largest 7.8).
- **Controls:** each change is measured against a matching control.
  - The Umbra Shadow Step options are measured against a run with the same "blink out when under fire" trigger and no new mechanic.
  - Dive play with the half cooldown is measured against dive play with that trigger. (The first draft compared it with dive play alone, which mixed the trigger into the half cooldown's effect; the fact-check caught this.)

### How each option was modelled

| Option | In the sim |
|---|---|
| Static Discharge, reactive | Fires by itself once a life, the first time Voltaic drops below 30% HP. Enemies within 8 studs are knocked back 10 studs and are airborne for 0.3 s (no moving or dodging). Voltaic then runs away at 150% speed for 0.5 s, and below 40% HP keeps retreating for 2 more seconds. It keeps firing while it runs. No damage, heal or shield. |
| Static Discharge, manual | The same pulse, on a 12 s cooldown with no mana cost (the spec gives none). The bot uses it when an enemy is within 8 studs and Voltaic is under fire or below 50% HP, or just for the speed burst when it's under fire below 40%. |
| Static Discharge, oversized (dose test) | Manual, radius 10, push 16, 200% speed for 1.5 s, 8 s cooldown. The bot still triggers it at an enemy within 8 studs. |
| Vanish, 0.3 s | For 0.3 s after each Shadow Step, Umbra can't be targeted, takes no direct hits, and dodges every telegraphed attack. Damage over time and ground zones (Blizzard's slow, Deep Freeze's root, Toxin clouds) still apply. The bot may also step out when under fire below 60% HP. |
| Vanish, 1.0 s (dose test) | The same, for 1.0 s. |
| Half cooldown | Shadow Step's cooldown is halved, 10 → 5 s, when it's cast within 2 s after Umbra lands a hit, or when one of Umbra's Darts lands within 2 s after casting. Same under-fire trigger as the vanish runs. |
| Dive play (behaviour, not a stat) | When no enemy is within 30 studs and Umbra has 40 mana, it blinks 22 studs in on a target below 60% HP and fights at 18–40 studs for 4 s (a length I chose). It then walks back out to its 70–110 range, because Shadow Step is still on cooldown from the dive-in; it can blink out again once the step returns. Without dive play, the sim's Umbra kites at 70–110 studs and only blinks to escape. |

## Results

Noise check: the same v3 run on a second set of seeds moves Voltaic by -0.5, Umbra by +0.1, and every Element by at most 0.5 points. Changes smaller than that are noise. Single comps move more: the run-to-run difference per comp has an SD of 2.3 points (largest 7.8), so a one-comp change in the bottom-6 or top-6 counts can be noise.

All runs: 6 rounds per pairing, 3,486 pairings, no jump, lowest-HP focus, teamwork on, package v3.

| Run | Voltaic comps (vs baseline) | Umbra comps (vs its control) | Voltaic in bottom 6 / top 6 | Umbra in bottom 6 / top 6 | Bottom 10 / top 10 (V, U) | Comp spread (SD) | Best − worst Element |
|---|---|---|---|---|---|---|---|
| v3 baseline | 44.2% | 42.3% | 5 / 2 | 3 / 0 | V 8/3, U 4/1 | 20.1 | 28 |
| v3 baseline, second seed set (noise check) | 43.7% (-0.5) | 42.4% (+0.1) | 5 / 2 | 3 / 0 | V 9/3, U 4/1 | 20.3 | 29 |
| Voltaic: Static Discharge, reactive | 43.5% (-0.7) | 42.9% (+0.5) | 5 / 2 | 3 / 0 | V 8/3, U 3/1 | 20.0 | 28 |
| Voltaic: Static Discharge, manual | 43.2% (-1.0) | 42.9% (+0.6) | 5 / 2 | 3 / 0 | V 8/2, U 4/1 | 20.0 | 28 |
| Voltaic: manual, oversized (r10, push 16, 2x speed 1.5 s, 8 s) | 42.8% (-1.4) | 43.1% (+0.8) | 5 / 2 | 3 / 0 | V 8/2, U 4/1 | 20.0 | 28 |
| Umbra control: blink out under fire, no P27 mechanic | 44.0% (-0.2) | 42.9% (+0.6) | 5 / 2 | 3 / 0 | V 7/3, U 4/1 | 20.0 | 28 |
| Umbra: 0.3 s vanish | 43.6% (-0.6) | 42.5% (-0.4) | 5 / 2 | 3 / 0 | V 7/3, U 3/1 | 20.1 | 28 |
| Umbra: 1.0 s vanish (oversized) | 43.1% (-1.1) | 43.1% (+0.2) | 5 / 2 | 3 / 0 | V 8/3, U 4/1 | 20.0 | 28 |
| Umbra: half cooldown after a hit | 44.0% (-0.2) | 42.9% (+0.0) | 5 / 2 | 3 / 0 | V 7/3, U 4/1 | 20.1 | 28 |
| Umbra dive play, control | 45.0% (+0.8) | 43.5% (+1.2) | 4 / 2 | 2 / 0 | V 6/3, U 2/2 | 19.6 | 28 |
| Umbra dive play + under-fire step-out, control | 44.9% (+0.6) | 43.7% (+0.2) | 4 / 2 | 2 / 0 | V 7/3, U 3/1 | 19.5 | 28 |
| Umbra dive play + half cooldown | 44.9% (+0.7) | 44.6% (+0.9) | 5 / 1 | 2 / 1 | V 6/3, U 2/1 | 19.3 | 28 |
| Together: reactive Static Discharge + dive play + half cooldown | 44.4% (+0.2) | 44.8% (+1.1) | 4 / 1 | 2 / 1 | V 6/3, U 2/2 | 19.2 | 28 |
| Together: manual Static Discharge + dive play + half cooldown | 44.4% (+0.2) | 44.7% (+1.0) | 4 / 1 | 2 / 1 | V 6/2, U 2/2 | 19.2 | 27 |

(In the second-seed baseline, two comps tie for 10th from the bottom, so its bottom-10 counts read V 8–9, U 4–5 depending on the tie.)

| Run | Voltaic dies % · damage/s alive · Static Discharges per round | Umbra dies % · damage/s alive · Shadow Steps per round (of which dive-ins) |
|---|---|---|
| v3 baseline | 71% · 25.6 · 0.00 | 65% · 15.5 · 0.17 (0.00) |
| v3 baseline, second seed set (noise check) | 72% · 25.5 · 0.00 | 65% · 15.4 · 0.16 (0.00) |
| Voltaic: Static Discharge, reactive | 72% · 24.6 · 0.77 | 64% · 15.6 · 0.17 (0.00) |
| Voltaic: Static Discharge, manual | 72% · 24.4 · 0.82 | 64% · 15.6 · 0.17 (0.00) |
| Voltaic: manual, oversized (r10, push 16, 2x speed 1.5 s, 8 s) | 72% · 23.0 · 0.86 | 64% · 15.6 · 0.17 (0.00) |
| Umbra control: blink out under fire, no P27 mechanic | 72% · 25.5 · 0.00 | 64% · 15.6 · 0.82 (0.00) |
| Umbra: 0.3 s vanish | 72% · 25.4 · 0.00 | 63% · 15.6 · 0.82 (0.00) |
| Umbra: 1.0 s vanish (oversized) | 73% · 25.1 · 0.00 | 62% · 15.8 · 0.83 (0.00) |
| Umbra: half cooldown after a hit | 72% · 25.5 · 0.00 | 64% · 15.6 · 0.93 (0.00) |
| Umbra dive play, control | 69% · 27.4 · 0.00 | 67% · 18.5 · 1.31 (1.26) |
| Umbra dive play + under-fire step-out, control | 69% · 27.3 · 0.00 | 67% · 18.5 · 1.40 (1.18) |
| Umbra dive play + half cooldown | 69% · 27.5 · 0.00 | 66% · 19.2 · 1.94 (1.56) |
| Together: reactive Static Discharge + dive play + half cooldown | 70% · 26.8 · 0.75 | 66% · 19.2 · 1.96 (1.57) |
| Together: manual Static Discharge + dive play + half cooldown | 70% · 26.7 · 0.80 | 66% · 19.2 · 1.95 (1.56) |

**Element win % per run:** v3 baseline: Aqu 43.4, Cry 50.7, Pyr 59.8, Rad 47.7, Ter 70.8, Tox 48.2, Umb 42.3, Vol 44.2, Zep 42.8 ; v3 baseline, second seed set (noise check): Aqu 43.4, Cry 51.1, Pyr 59.5, Rad 47.8, Ter 70.9, Tox 48.5, Umb 42.4, Vol 43.7, Zep 42.8 ; Voltaic: Static Discharge, reactive: Aqu 43.4, Cry 50.8, Pyr 60.0, Rad 47.9, Ter 70.5, Tox 48.4, Umb 42.9, Vol 43.5, Zep 42.7 ; Voltaic: Static Discharge, manual: Aqu 43.4, Cry 51.0, Pyr 59.9, Rad 47.9, Ter 70.6, Tox 48.3, Umb 42.9, Vol 43.2, Zep 42.9 ; Voltaic: manual, oversized (r10, push 16, 2x speed 1.5 s, 8 s): Aqu 43.3, Cry 51.1, Pyr 60.1, Rad 48.2, Ter 70.3, Tox 48.6, Umb 43.1, Vol 42.8, Zep 42.4 ; Umbra control: blink out under fire, no P27 mechanic: Aqu 43.2, Cry 50.7, Pyr 59.7, Rad 47.8, Ter 70.8, Tox 48.0, Umb 42.9, Vol 44.0, Zep 42.9 ; Umbra: 0.3 s vanish: Aqu 43.2, Cry 50.9, Pyr 60.1, Rad 48.1, Ter 70.6, Tox 48.4, Umb 42.5, Vol 43.6, Zep 42.6 ; Umbra: 1.0 s vanish (oversized): Aqu 43.3, Cry 50.9, Pyr 60.0, Rad 48.0, Ter 70.6, Tox 48.5, Umb 43.1, Vol 43.1, Zep 42.5 ; Umbra: half cooldown after a hit: Aqu 43.3, Cry 50.7, Pyr 59.7, Rad 47.8, Ter 70.8, Tox 48.0, Umb 42.9, Vol 44.0, Zep 42.9 ; Umbra dive play, control: Aqu 41.8, Cry 51.4, Pyr 61.1, Rad 47.8, Ter 69.3, Tox 48.9, Umb 43.5, Vol 45.0, Zep 41.2 ; Umbra dive play + under-fire step-out, control: Aqu 41.9, Cry 51.5, Pyr 61.0, Rad 47.7, Ter 69.2, Tox 48.9, Umb 43.7, Vol 44.9, Zep 41.3 ; Umbra dive play + half cooldown: Aqu 41.6, Cry 51.2, Pyr 61.1, Rad 47.8, Ter 69.0, Tox 48.7, Umb 44.6, Vol 44.9, Zep 41.2 ; Together: reactive Static Discharge + dive play + half cooldown: Aqu 41.8, Cry 51.2, Pyr 61.3, Rad 48.0, Ter 68.6, Tox 48.8, Umb 44.8, Vol 44.4, Zep 41.0 ; Together: manual Static Discharge + dive play + half cooldown: Aqu 41.7, Cry 51.2, Pyr 61.4, Rad 48.0, Ter 68.6, Tox 48.8, Umb 44.7, Vol 44.4, Zep 41.3

**v3 baseline** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 19, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Terra + Toxin + Voltaic 82, Pyro + Terra + Zephyr 82
**v3 baseline, second seed set (noise check)** — bottom 6: Radiant + Voltaic + Zephyr 21, Cryo + Toxin + Voltaic 21, Aqua + Voltaic + Zephyr 21, Cryo + Umbra + Voltaic 18, Radiant + Umbra + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 84, Terra + Toxin + Voltaic 82, Pyro + Terra + Zephyr 81
**Voltaic: Static Discharge, reactive** — bottom 6: Aqua + Voltaic + Zephyr 23, Radiant + Voltaic + Zephyr 22, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 20, Cryo + Umbra + Voltaic 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 82, Terra + Toxin + Voltaic 82
**Voltaic: Static Discharge, manual** — bottom 6: Aqua + Voltaic + Zephyr 23, Radiant + Voltaic + Zephyr 20, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 20, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 82, Terra + Toxin + Voltaic 80
**Voltaic: manual, oversized (r10, push 16, 2x speed 1.5 s, 8 s)** — bottom 6: Aqua + Cryo + Voltaic 22, Cryo + Umbra + Voltaic 21, Cryo + Toxin + Voltaic 21, Radiant + Umbra + Zephyr 20, Aqua + Voltaic + Zephyr 19, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 82, Terra + Toxin + Voltaic 81
**Umbra control: blink out under fire, no P27 mechanic** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Voltaic + Zephyr 21, Radiant + Umbra + Zephyr 19, Cryo + Umbra + Voltaic 19, Cryo + Toxin + Voltaic 19, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 84, Terra + Toxin + Voltaic 82, Pyro + Terra + Zephyr 82
**Umbra: 0.3 s vanish** — bottom 6: Radiant + Voltaic + Zephyr 22, Aqua + Voltaic + Zephyr 22, Radiant + Umbra + Zephyr 20, Cryo + Umbra + Voltaic 19, Cryo + Toxin + Voltaic 18, Radiant + Umbra + Voltaic 13 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 84, Pyro + Terra + Zephyr 82, Terra + Toxin + Voltaic 82
**Umbra: 1.0 s vanish (oversized)** — bottom 6: Aqua + Voltaic + Zephyr 22, Radiant + Voltaic + Zephyr 21, Radiant + Umbra + Zephyr 21, Cryo + Umbra + Voltaic 19, Cryo + Toxin + Voltaic 18, Radiant + Umbra + Voltaic 13 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 84, Terra + Toxin + Voltaic 82, Pyro + Terra + Zephyr 82
**Umbra: half cooldown after a hit** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Voltaic + Zephyr 22, Cryo + Umbra + Voltaic 19, Cryo + Toxin + Voltaic 19, Radiant + Umbra + Zephyr 19, Radiant + Umbra + Voltaic 13 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 84, Terra + Toxin + Voltaic 82, Pyro + Terra + Zephyr 82
**Umbra dive play, control** — bottom 6: Aqua + Radiant + Zephyr 23, Aqua + Voltaic + Zephyr 23, Aqua + Radiant + Voltaic 23, Radiant + Voltaic + Zephyr 22, Radiant + Umbra + Zephyr 21, Radiant + Umbra + Voltaic 20 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 90, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 83, Pyro + Terra + Zephyr 81, Terra + Toxin + Voltaic 80
**Umbra dive play + under-fire step-out, control** — bottom 6: Aqua + Radiant + Voltaic 23, Aqua + Radiant + Zephyr 23, Aqua + Voltaic + Zephyr 23, Radiant + Voltaic + Zephyr 22, Radiant + Umbra + Zephyr 21, Radiant + Umbra + Voltaic 20 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 83, Pyro + Terra + Zephyr 81, Terra + Toxin + Voltaic 80
**Umbra dive play + half cooldown** — bottom 6: Aqua + Radiant + Voltaic 23, Radiant + Umbra + Zephyr 23, Cryo + Toxin + Voltaic 23, Aqua + Voltaic + Zephyr 21, Radiant + Umbra + Voltaic 21, Radiant + Voltaic + Zephyr 21 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 83, Pyro + Terra + Zephyr 80, Cryo + Terra + Umbra 80
**Together: reactive Static Discharge + dive play + half cooldown** — bottom 6: Radiant + Umbra + Zephyr 24, Aqua + Radiant + Toxin 24, Aqua + Voltaic + Zephyr 23, Cryo + Toxin + Voltaic 23, Radiant + Umbra + Voltaic 21, Radiant + Voltaic + Zephyr 21 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 84, Pyro + Radiant + Terra 83, Cryo + Terra + Umbra 80, Pyro + Terra + Zephyr 79
**Together: manual Static Discharge + dive play + half cooldown** — bottom 6: Aqua + Voltaic + Zephyr 23, Radiant + Umbra + Zephyr 23, Cryo + Toxin + Voltaic 23, Aqua + Radiant + Toxin 23, Radiant + Umbra + Voltaic 22, Radiant + Voltaic + Zephyr 21 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 84, Cryo + Terra + Umbra 80, Pyro + Terra + Zephyr 80

## Why the escape tools don't work here

- **Voltaic isn't dying for want of an exit.** Three attackers focus it from range, so a 10-stud shove and a short sprint don't take it out of anyone's reach. The retreat does take it out of its own Chain Bolt range, so its damage drops from 25.6 to 24.6 per second (reactive) or 24.4 (manual), and 23.0 with the oversized version, while its death rate edges up from 71% to 72%.
- **Umbra dies to ranged focus, not to divers.** It fights from 70–110 studs, so enemies rarely close on it (0.17 blink-outs a round), yet it still dies in 65% of rounds. A vanish window covers about a quarter of a second a round (about 0.8 s for the 1.0 s version), so its death rate only moves from 64% to 63% or 62%. Without dive play, the half cooldown adds only ~0.1 Shadow Steps a round and doesn't move the win rate.
- **The worst comps lack both protection and damage.** Every bottom-6 comp has neither Terra nor Pyro, and every top-6 comp has Terra, in every run. That's the same Terra problem as in the packages report.

## Suggestions from this test

1. **Don't ship Static Discharge for team mode.** No version helped. **Confidence: medium-high:** tested at three strengths, all at or below zero.
2. **For Umbra, reward diving rather than adding a defensive Shadow Step.** The half cooldown after a hit is worth +0.9 on top of dive play, most likely because Umbra can dive more often. The vanish isn't needed. **Confidence: medium:** small, but above noise.
3. **If you want a real dive-and-exit for Umbra, the exit needs its own charge.** For example, a second Shadow Step charge, or a free return blink within ~3 s of the dive-in. With one 10 s cooldown, halved or not, the exit isn't ready within a short dive like the bot's 4 s. This is untested.
4. **For Voltaic, look at its damage and reach rather than escape,** within its Offence role. For example, more Chain Bolt range, or damage that rewards staying in. This is untested.
5. **The bigger lever is still the Terra gap.** Next in line is the second-protector test (Twin Tide's walls also blocking shots), which the P27 spec calls a separate question worth testing.

## Caveats

- **These are bot fights on an open floor,** with rules for aim, dodging and teamwork, not measured from players.
- **Dive play is a bot behaviour I added** to test the spec's idea. The sim's default Umbra doesn't dive.
- **6 rounds per pairing.** Between two identical runs, an Element's win rate moves by up to 0.5 points and a single comp's by about ±2.3 (one SD), so a one-comp change in the bottom-6 or top-6 counts can be noise.
