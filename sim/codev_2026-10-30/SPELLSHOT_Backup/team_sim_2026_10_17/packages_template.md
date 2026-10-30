# SPELLSHOT team mode: stat packages tested in the 3v3 sim (v1, v2, v3)

18 October 2026. Follow-up to the 3v3 report (`SPELLSHOT_3V3_SIM_REPORT.md`). Every number below was fact-checked
against the raw results and the sim's code by four independent checkers before sending.

## The question

Which stat changes make 3v3 play the way it's meant to? Fights long enough for a tank and a support to "cover each
other's back", no stacking exploits, and every Element worth picking.

The targets come from Marvel Rivals' per-match averages (CounterWatch.gg whole-player-base stats, from the owner's
research note). Each target compares one game with itself:

| Target | Marvel Rivals | SPELLSHOT today (sim) |
|---|---|---|
| Round length | about 15–30 s per fight | about 10 s |
| A support's healing ÷ a damage dealer's damage | 1.35× | 0.2× (0.4× counting Blessing shields) |
| A tank's blocked damage ÷ its own damage | about 2× | 0.65–0.75× |
| No Element far above the rest | — | Pyro does 1.6× the next Element's damage per player |

## Setup

- **Base:** today's live values, 3v3, running only (no slide, slide-jump or wall-run).
- **Test set 1:** the 105 matchups from the 3v3 prompt (mono-comps, S1–S5, W1, W2).
  - Both targeting rules; jump off (Variant A) and on (Variant B).
  - 200 rounds per matchup, per targeting rule and variant (v2: 100, v3: 50).
- **Test set 2:** a round-robin of all 84 comps with no Element twice. That is 3,486 pairings.
  - No jump, lowest-HP focus.
  - Rounds per pairing: 40 for the current game and v1; 20 for v2; 10 for v3 and the follow-ups. With 10, each comp still plays 830 rounds: about ±3.5 points at 95% confidence.
- **"Cover each other's back" teamwork:**
  - Everyone except Terra stays within 18 studs of their Terra, or of the team's centre if there's no Terra. Umbra stays within 45, and Terra within 25 of its teammates' centre.
  - Whenever a teammate has recently taken heavy fire (18+ damage, about one Fireball, fading by half each second), the team switches focus to the nearest enemy within 15 studs of that teammate.
  - Radiant moves toward the most hurt teammate when more than 16 studs away.
  - The current game was re-run with the same teamwork, so the columns compare like for like on rules (round counts differ, as above). v1 and v3 were also run without it.

## The packages

| Setting | Live now | v1 | v2 (changes from v1) | v3 (changes from v2) |
|---|---|---|---|---|
| Health | 150 for everyone | 250; Terra 450, Umbra 225 | Terra 375, Aqua 300, Zephyr 275, Umbra 250 | Terra 300 |
| Ultimate charge per damage | 1/260 | × 0.6 | | |
| Light Lance | damage only | heals instead of attacking while a teammate within 60 studs is below 60% HP (or under fire and below 85%): 15 → 30 HP/s ramp over 2 s, same mana | | |
| Blessing | 35 shield, 12 s cooldown | 60, 8 s | | |
| Benediction | 15 HP/s, radius 25, roots Radiant, 8 s max, 17 s cooldown | 25 HP/s, radius 35, Radiant can move, 6 s max, 10 s cooldown | | |
| Bulwark Wall | 200 HP, 20 mana/s, held up to 2.5 s, 2 s before it goes up again | 300 HP, 12 mana/s, 50% wider, held up to 4 s, 1 s between | 400 HP, twice the original width, held up to 6 s, 0.5 s between; raised at light fire (about 4+ damage/s on anyone near Terra) instead of focus fire | |
| Fireball | 18 every 0.6 s | 15 every 0.7 s | | |
| Chain Bolt range | 30 | 45 | | |
| Overload, cooldown per target | 0.75 s | 2.5 s | | |
| Skyrider flight speed | 75 studs/s | 55 | | |
| Riptide / Shadow Dart | 12 / 65 | | 14 / 85 | |

Three changes aren't plain numbers:
- the Light Lance heal, a new mechanic;
- Benediction no longer rooting Radiant;
- in v2 and v3, Terra's bot raising the wall at light fire, which is a behaviour change.

Every other change is a number.

{{TABLES}}

Notes on the tables:
- "Healing as a share of all damage" includes Toxin's lifesteal, which the sim logs before the health cap. The true share may be up to about 1 point lower.
- The Radiant row counts Benediction, the Light Lance heal and Blessing. It leaves out Halo (the Ultimate's team lifesteal), which would add about 2.7 per second in every column.
- A Fireball that hits Bulwark Wall still counts 18 against the wall in v1–v3. That makes the wall figures slightly high against Pyro.

## What worked

All figures cover both variants and both AIs unless marked.

- **v1 meets two of the four targets outright, with or without coordinated play.**
  - **Round length:** rounds go from about 10 s to 18–20 s.
  - **Element balance on the 105 matchups:** Pyro comes back level with the next Element (1.02–1.03×).
  - Healing goes from 6% to 15–17% of all damage.
  - Mono-Pyro stops beating strategy comps: 13–27%, against 65–70% now.
  - W2 (Pyro, Pyro, Voltaic) falls to 22–38%, against 64–78%.
  - S2 goes from 56–62% to 87–92% against mono-comps.
- **Healing is close to the target, depending on how it's measured.**
  - **Per round** (how the Marvel Rivals averages work), Radiant's heals and shields roughly equal an average damage dealer's damage: about 1.2× in v1, 1.0× in v2 and v3. Heals alone are 0.6–0.8×.
  - **Per second alive**, it's 0.7–0.8×. Radiant lives longer than the damage dealers.
- **v2 and v3 raise the tank's protection.** Terra's wall goes from 0.75× of its own damage today (0.83× in v1) to 1.2–1.3×. That's still short of the 2× target.
- **v2 and v3 undo most of v1's Aqua loss.** Its comps go from 38% (v1) back to 43–44%; they were 45% in today's game. W1 (Aqua, Toxin, Zephyr) goes from 7–10% to 20–27% against strategy comps.

## What didn't

- **Comp balance with the teamwork AI didn't improve.** In the 84-comp round-robin, the spread between comps stays at about 20 points (standard deviation).
  - It has moved, not shrunk: in today's game Pyro decides comps; in every package Terra does.
  - With teamwork, comps with Terra win about 70%, and comps with neither Terra nor Radiant about 38%.
- **S4 (Radiant, Umbra, Pyro) gets worse in every package:** 67–69% today with teamwork → 43–58% against mono-comps. The losses come from the buffed mono-Radiant (S4 wins 98% today, about 16% in the packages) and mono-Voltaic (100% → 23–39%), not from Terra. S4 against mono-Terra is about the same in v3 as today. Mono-comps aren't legal under the one-Element-per-team rule, so this matters less than the round-robin.

## The v3 follow-up: why Terra decides comps

v3 cut Terra to 300 HP, and its comps barely moved (73% → 71%), so Terra's health isn't the cause. Three quick
round-robins tested the other suspects (10 rounds per pairing, no jump):

| Run (84-comp round-robin) | Comps with Terra | Radiant, no Terra | Neither | Best − worst Element |
|---|---|---|---|---|
| Today's game, no teamwork | 57% | 39% | 51% | 32 points (Pyro 72, Umbra 40) |
| Today's game, teamwork | 59% | 38% | 50% | 31 |
| v3, no teamwork | **63%** | 43% | 43% | **22** (Terra 63, Aqua and Zephyr 41) |
| v3, teamwork | 71% | 40% | 39% | 29 |
| v3 with v1's whole wall (300 HP, 50% wider, 4 s holds, raised only at focus fire), teamwork | 69% | 41% | 40% | 27 |

- **My teamwork rule adds about 8 points to Terra comps** (63% → 71%). Grouping around a tank genuinely helps a tank comp, so this isn't purely a sim flaw. But it's the biggest single factor.
- **The bigger wall and the eager trigger add only about 2 points,** and Terra's HP about 2 more.
- **Without the teamwork rule, v3 clearly narrows the Element spread:** from 32 points today to 22. That improvement was hidden in the teamwork runs.
- **Today's game already had Terra comps at 57–59%,** second only to Pyro. The packages remove Pyro's lead, which leaves Terra on top.

## Where this leaves things

1. **v1's core (HP, healing, Fireball, Chain Bolt, Overload) is worth testing in Studio.** It fixes round length, Pyro, the stacking exploits and S2, and it doesn't depend on the teamwork rule.
2. **The roster has one tank.** Whenever protection matters, teams want the only Element that provides it. If the Terra gap holds up in playtests, the options are:
   - a role rule (every team has one tank);
   - giving a second Element team protection, for example Twin Tide's walls also blocking shots;
   - accepting Terra as the standard pick.
3. **The teamwork rule should be checked against real play** before it's used to set numbers: it's worth up to 8 points to Terra comps.

## Caveats

- **These are bot fights on an open floor.** Aim, dodging and teamwork are rules and formulas, not measured from real players. The numbers show which direction a change pushes, not exactly how the live game will play.
- **Bulwark Wall's HP per deploy isn't known from the data:** each deploy is assumed to start at full HP.
- **The sim only models Skyrider's boosted speed (75 → 55),** not its cruise speed.
