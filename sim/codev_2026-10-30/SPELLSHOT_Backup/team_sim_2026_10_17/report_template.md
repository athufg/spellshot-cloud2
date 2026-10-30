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

{{STATIC}}

## 3. Matchup results, by configuration

Each cell is 200 rounds per policy. Mono-vs-strategy cells give the **mono's** win %, lowest-HP focus / softest-role
focus. The time to wipe is the round length when one team was wiped; no round in any configuration reached the 90 s
clock. Every row for every policy, with draws and time-outs, is in `team_sim_2026_10_17/matchups_P.csv` (and
`matchups_L.csv` for the live check).

{{CONFIGS}}

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

{{SWAPS}}

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

{{WHATIF}}

## 10. Recommendations

{{RECS}}

## 11. Open questions

{{OPEN}}

## Appendix: ability economy in team play

Pass 1 / Variant A, both policies, every comp. Damage per mana excludes M1 mana for abilities. "Casts/min per player"
runs above the cooldown cap for long cooldowns, because every ability starts each round ready.

{{ABILITY}}
