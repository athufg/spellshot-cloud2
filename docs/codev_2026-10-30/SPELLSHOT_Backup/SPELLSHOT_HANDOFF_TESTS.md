# SPELLSHOT handoff tests: tank-role rule, Voltaic reach and damage, Umbra escape charge

18 October 2026. The handoff's priorities, run in the 3v3 sim, all on today's live values with package v3 and the live
(self-centred) Blizzard and Deep Freeze. "K" is the handoff's current-best baseline: v3 plus standing Twin Tide ((a),
200 HP, walls standing 3 s more), Flash Freeze at the cursor out to 25, and Blizzard at the cursor out to 20.

## The two spread metrics (handoff A)

They measure different things, so they are reported side by side and never compared across:
- **Element range** = best Element's win % minus worst Element's win %, over the 9 Elements. This is the analogue of
  Marvel Rivals' hero range (12.5 points, 57.7 to 44.1).
- **Comp SD** = the standard deviation of the comps' win %, over the 84 comps, or fewer under a role rule.

Where they stand:

| | Element range | Comp SD |
|---|---|---|
| v3, live Cryo | 28.5 (18.5 without Terra) | 20.1 |
| K | 28.0 (18.3 without Terra) | 19.6 |

On the second seed set the baseline moves by +0.9 in range and +0.4 in SD.

## Headline: everything together

K plus Chain Bolt range 55 and 10 a bolt, plus Umbra's dive play, half cooldown and a 6 s escape blink:

| | Element range | Without Terra | Comp SD | Worst Elements |
|---|---|---|---|---|
| v3, live Cryo | 28.5 | 18.5 | 20.1 | Umbra 42.1, Zephyr 43.2, Aqua 43.7 |
| K | 28.0 | 18.3 | 19.6 | Zephyr 41.2, Voltaic 42.0, Umbra 42.2 |
| All together, 84 comps | 29.7 | 19.7 | 18.2 | Zephyr 38.5, Umbra 44.9, Radiant 45.7 |
| All together, one-Terra rule | — (Terra 50% by rule) | 22.0 | 14.6 | Zephyr 38.8, Radiant 42.8, Aqua 43.7 |

Marvel Rivals' 12.5 is still far off. The fixes so far lift the Elements they target: Voltaic to 50%, Aqua to 47–49, Cryo
to 50–51, Umbra to 45%. Comp SD falls 20.1 → 18.2 (14.6 under the role rule). But the Element range is pinned by
Terra at the top (about 68–70%, or by its role-rule partners Pyro and Cryo at about 60%) and **Zephyr at the bottom (about
39% once the other fixes are in)**. Zephyr is the next Element to look at, then Radiant.

## Suggestions

1. **Adopt the one-tank rule (T1) if team mode ships, with Terra as the only tank for now.** It removes the Terra /
   no-Terra split (comp SD about 20 → 15) and turns balance into the cleaner question of who partners Terra. Don't make
   Aqua an alternative tank: Aqua comps lose 63–37 to Terra comps even with standing walls. **Confidence:
   medium-high.**
2. **Give Voltaic Chain Bolt range 55 and 10 a bolt** (+8.2, Voltaic to 50%, death rate 73% → 65%). **Confidence:
   medium-high:** clean dose curve.
3. **Give Umbra's escape its own charge** (a 6 s blink separate from Shadow Step): +1.5 on top of dive play. Small, but
   it is the first escape change that works. **Confidence: medium.**
4. **Keep Blizzard at 20,** including under the role rule: 32 makes Cryo the top Terra partner and widens the range.
5. **Next:** Zephyr (about 39% with the other fixes in, now the worst), then Radiant (43% as a Terra partner). Then re-run
   everything under the role rule, the only setting where the Element range means "which Element is good", not "which
   comps have Terra".

## Answer by priority

### B. A tank-role rule (Priority 1)

**It removes Terra's monopoly by construction, but not the imbalance: the other Elements still spread about 22 points
as Terra's teammates.**

- **T1, exactly one Terra per team** (28 legal comps, every one with Terra, so Terra is 50% by definition):
  - Comp SD falls 20.1 → 14.9 on v3 and 15.9 on K. It no longer splits into "has Terra / doesn't".
  - But the Element range among the other 8 is 22.3 (v3) and 22.5 (K). That is wider than without the rule
    (18.5 / 18.3 without Terra), and far from Marvel Rivals' 12.5.
  - The best partners are Pyro (64.4 / 62.3), Cryo (52.3 / 62.5) and Toxin (59.2 / 57.5). The worst are Umbra
    (42.1 / 39.9), Radiant (45.2 / 43.4), Zephyr (44.8 / 41.9) and, on v3, Aqua (42.8).
- **TA1, exactly one of Terra or Aqua** (42 comps), tests Aqua with standing Twin Tide as a second legal tank.
  - Terra comps beat Aqua comps heavily: 67.6 against 32.4 on v3, and still 62.9 against 37.1 on K.
  - Every bottom-6 comp is an Aqua comp. Even with standing walls, Aqua isn't a viable alternative tank.
- **What it means:** the rule fixes the shape (no comp without protection, no Terra-or-nothing split). The remaining
  spread is about which damage and control Elements work with Terra, and that needs per-Element tuning. The rule doesn't
  replace that tuning, but it turns it into a smaller, cleaner problem: 28 comps, one tank.

### C. Voltaic's reach and damage (Priority 2)

**Both levers work, with a clean dose curve. Range and damage together bring Voltaic to average.** Voltaic's change
against K, on the same seeds; the Pyro − Voltaic gap starts at 17.5:

| Change | Voltaic | Pyro − Voltaic | Voltaic dies |
|---|---|---|---|
| K (Chain Bolt range 45, 8 a bolt) | 42.0% | 17.5 | 73% |
| Range 55 | +4.1 | 12.6 | 69% |
| Range 65 | +6.5 | 9.4 | 66% |
| 10 a bolt | +3.5 | 13.5 | 70% |
| 12 a bolt | +7.6 | 8.3 | 66% |
| **Range 55 and 10 a bolt** | **+8.2 (50.2%)** | **7.5** | **65%** |

- **More reach and damage also keep Voltaic alive:** its death rate falls from 73% to 65%. It kills before it is
  killed, which escape tools (P27) never managed.
- **The gain is spread across the others:** Pyro, Zephyr, Umbra, Radiant and Cryo lose 0.4 to 1.8 each. Terra
  doesn't move beyond noise (+0.3 to +0.8).
- **The overall spread doesn't move:** Element range 28.0 → 29.1–30.4, because Zephyr drops to 39.6–40.6 at the
  bottom; without Terra, 18.1–18.6; comp SD 19.3–19.6. Fixing Voltaic just hands "worst" to Zephyr and Umbra.
- **Suggested dose:** range 55 with 10 a bolt (+8.2), or 12 a bolt alone (+7.6) if you'd rather keep the range.

### D. Umbra's escape as its own charge (Priority 3)

**A separate escape charge finally works, and adds a little on top of dive play.** Measured against K with P27's dive
play and half cooldown, so only the new charge differs:

| Change | Umbra | Umbra dies | Blink-outs per round |
|---|---|---|---|
| K | 42.2% | 65% | 0.16 |
| K + dive play + half cooldown (control) | +1.9 (44.1%) | 67% | 0.38 |
| + escape blink, own 10 s cooldown | +1.1 more (45.2%) | 63% | 1.54 |
| + escape blink, own 6 s cooldown | +1.5 more (45.6%) | 63% | 1.98 |

- **The exit now fires:** blink-outs go from 0.38 to 1.5–2.0 a round, and Umbra's death rate drops from 67% to 63%.
- **The gain is small** (+1.1 / +1.5 on paired seeds, against ±0.8 noise), for +3.0 to +3.4 in total with dive play.
  Umbra stays below average (45.6%).
- **Dive play is a bot behaviour I added in P27.** The escape charge only pays off for players who dive.
- **The overall spread doesn't move** (Element range 27.4–27.7, comp SD 18.7–18.8).

### E. Removing Technique swapping (Priority 4)

**No standing number changes, and no run was needed.** Every round-robin in every package and in P27–P29 gives every
player its own Element's default Techniques; the code passes no swap. Only the separate swap checks (P25, P28's swap
table) ever swapped. So "no cross-Element swap, ever" (P31) is already what all the standing numbers assume. It does
retire P28's Bulwark Wall swap warning (+11.5 to +26.5) as a live risk, since that exploit needs swapping.

### F. Blizzard 32 under the role rule (Priority 5)

**Still worse than Blizzard 20.** Under T1 it can no longer lift Terra (Terra is 50% by construction). Instead it makes
Cryo the top partner (62.5 → 64.0) and widens the range among the other 8 from 22.5 to 24.4 (comp SD 15.9 → 16.6).
Under TA1 the range is 25.7 → 26.5. Keep Blizzard at 20.

## Setup

- 3v3, open floor, running only, no jump, lowest-HP focus, "cover each other's back" teamwork on.
- The full round-robin has 84 comps and 3,486 pairings at 6 rounds each. The role-rule runs are smaller (378 or 861
  pairings), so they use 20 rounds each.
- Voltaic and Umbra changes are measured against K on the same seeds. The Umbra escape charge is measured against K
  with P27's dive play and half cooldown, so only the new charge differs.
- Noise: an Element moves up to 0.8 points between seed sets, and the comp SD 0.4.

## Results

Two spread metrics, kept apart. **Element range** = best minus worst Element win % (the Marvel Rivals hero-range analogue: 12.5 points there). **Comp SD** = standard deviation of the comps' win % (84 comps, fewer under a role rule). Under rule T1 every comp has Terra, so Terra is 50% by construction and is left out of that run's range.

| Run | Comps · rounds per pairing | Element range (all) | Element range without Terra | Comp SD | Pyro − Voltaic | Within-role ranges (dps: Pyro/Toxin/Aqua · support: Radiant/Cryo · flank: Umbra/Voltaic) |
|---|---|---|---|---|---|---|
| v3, live Cryo (P28/P29 baseline) | 84 · 6 | 28.5 | 18.5 | 20.1 | 16.1 | 16.9 · 0.9 · 2.4 |
|   same, second seed set | 84 · 6 | 29.4 | 17.8 | 20.5 | 16.0 | 16.2 · 0.9 · 1.8 |
| K = v3 + standing Twin Tide (a, 200, +3 s) + Flash Freeze 25 + Blizzard 20 | 84 · 6 | 28.0 | 18.3 | 19.6 | 17.5 | 11.6 · 3.5 · 0.2 |
| Role rule T1 (exactly one Terra) on v3 | 28 · 20 | — | 22.3 | 14.9 | 15.2 | 21.7 · 7.1 · 7.1 |
| Role rule T1 on K | 28 · 20 | — | 22.5 | 15.9 | 17.0 | 15.2 · 19.0 · 5.4 |
| Role rule TA1 (exactly one of Terra / Aqua) on v3 | 42 · 20 | 35.3 | 28.9 | 20.9 | 15.3 | 28.9 · 4.8 · 0.5 |
| Role rule TA1 on K | 42 · 20 | 25.7 | 25.2 | 18.7 | 19.4 | 25.2 · 10.9 · 2.1 |
| T1 on K, Blizzard 32 instead of 20 | 28 · 20 | — | 24.4 | 16.6 | 16.8 | 14.8 · 21.3 · 5.1 |
| TA1 on K, Blizzard 32 instead of 20 | 42 · 20 | 26.5 | 25.0 | 19.1 | 19.1 | 25.0 · 12.6 · 2.4 |
| K + Chain Bolt range 45 -> 55 | 84 · 6 | 29.1 | 18.2 | 19.4 | 12.6 | 10.5 · 3.0 · 5.1 |
| K + Chain Bolt range 65 | 84 · 6 | 30.4 | 18.3 | 19.6 | 9.4 | 9.8 · 3.5 · 7.2 |
| K + Chain Bolt 8 -> 10 a bolt | 84 · 6 | 29.2 | 18.6 | 19.6 | 13.5 | 11.4 · 3.8 · 4.0 |
| K + Chain Bolt 12 a bolt | 84 · 6 | 29.9 | 18.2 | 19.4 | 8.3 | 10.8 · 3.9 · 8.1 |
| K + Chain Bolt range 55 and 10 a bolt | 84 · 6 | 30.0 | 18.1 | 19.3 | 7.5 | 9.8 · 3.4 · 9.5 |
| K + Umbra dive play + half cooldown (P27's best; control) | 84 · 6 | 27.2 | 21.1 | 18.6 | 18.4 | 12.8 · 4.4 · 1.5 |
|   + separate escape blink, 10 s cooldown | 84 · 6 | 27.4 | 20.0 | 18.7 | 18.1 | 12.7 · 4.1 · 3.0 |
|   + separate escape blink, 6 s cooldown | 84 · 6 | 27.7 | 20.2 | 18.8 | 18.3 | 12.2 · 4.2 · 3.6 |
| All together: K + Chain Bolt 55 / 10 + Umbra dive, half cooldown, escape blink 6 s | 84 · 6 | 29.7 | 19.7 | 18.2 | 8.2 | 11.1 · 4.0 · 5.1 |
| All together, under role rule T1 | 28 · 20 | — | 22.0 | 14.6 | 10.0 | 17.1 · 17.2 · 4.6 |

## Element win % per run

| Run | Aqua | Cryo | Pyro | Radiant | Terra | Toxin | Umbra | Voltaic | Zephyr |
|---|---|---|---|---|---|---|---|---|---|
| v3, live Cryo (P28/P29 baseline) | 43.7 | 48.8 | 60.6 | 47.9 | 70.6 | 48.6 | 42.1 | 44.5 | 43.2 |
|   same, second seed set | 43.6 | 49.1 | 59.8 | 48.1 | 71.4 | 49.0 | 42.0 | 43.8 | 43.1 |
| K = v3 + standing Twin Tide (a, 200, +3 s) + Flash Freeze 25 + Blizzard 20 | 49.4 | 51.0 | 59.6 | 47.5 | 69.3 | 47.9 | 42.2 | 42.0 | 41.2 |
| Role rule T1 (exactly one Terra) on v3 | 42.8 | 52.3 | 64.4 | 45.2 | 50.0 | 59.2 | 42.1 | 49.2 | 44.8 |
| Role rule T1 on K | 47.1 | 62.5 | 62.3 | 43.4 | 50.0 | 57.5 | 39.9 | 45.3 | 41.9 |
| Role rule TA1 (exactly one of Terra / Aqua) on v3 | 32.4 | 52.5 | 61.2 | 47.8 | 67.6 | 52.8 | 45.4 | 45.9 | 44.3 |
| Role rule TA1 on K | 37.1 | 58.2 | 62.3 | 47.3 | 62.9 | 52.3 | 45.0 | 42.9 | 42.0 |
| T1 on K, Blizzard 32 instead of 20 | 46.8 | 64.0 | 61.6 | 42.7 | 50.0 | 58.5 | 39.7 | 44.8 | 41.9 |
| TA1 on K, Blizzard 32 instead of 20 | 36.7 | 59.5 | 61.7 | 47.0 | 63.3 | 52.5 | 45.1 | 42.6 | 41.5 |
| K + Chain Bolt range 45 -> 55 | 48.9 | 49.8 | 58.8 | 46.8 | 69.7 | 48.2 | 41.1 | 46.1 | 40.6 |
| K + Chain Bolt range 65 | 48.5 | 49.8 | 57.9 | 46.3 | 70.0 | 48.1 | 41.3 | 48.5 | 39.6 |
| K + Chain Bolt 8 -> 10 a bolt | 49.2 | 50.6 | 59.0 | 46.8 | 69.6 | 47.6 | 41.5 | 45.5 | 40.4 |
| K + Chain Bolt 12 a bolt | 48.3 | 50.0 | 58.0 | 46.1 | 69.6 | 47.2 | 41.5 | 49.6 | 39.7 |
| K + Chain Bolt range 55 and 10 a bolt | 48.2 | 49.7 | 57.7 | 46.3 | 69.6 | 48.0 | 40.7 | 50.2 | 39.6 |
| K + Umbra dive play + half cooldown (P27's best; control) | 48.1 | 51.7 | 60.9 | 47.3 | 67.0 | 48.5 | 44.1 | 42.5 | 39.8 |
|   + separate escape blink, 10 s cooldown | 47.7 | 51.1 | 60.4 | 47.0 | 67.8 | 48.2 | 45.2 | 42.2 | 40.3 |
|   + separate escape blink, 6 s cooldown | 48.1 | 51.1 | 60.3 | 46.9 | 67.8 | 48.1 | 45.6 | 42.0 | 40.1 |
| All together: K + Chain Bolt 55 / 10 + Umbra dive, half cooldown, escape blink 6 s | 47.1 | 49.8 | 58.2 | 45.7 | 68.2 | 47.7 | 44.9 | 50.0 | 38.5 |
| All together, under role rule T1 | 43.7 | 60.0 | 60.7 | 42.8 | 50.0 | 57.2 | 46.1 | 50.7 | 38.8 |

## Changes against their control

| Run | Control | Voltaic | Umbra | Pyro | Terra | Voltaic: dies % · damage/s alive | Umbra: dies % · Shadow Steps per round (out) |
|---|---|---|---|---|---|---|---|
| K = v3 + standing Twin Tide (a, 200, +3 s) + Flash Freeze 25 + Blizzard 20 | v3, live Cryo | 42.0 (-2.5) | 42.2 (+0.1) | 59.6 (-1.0) | 69.3 (-1.4) | 73% · 24.9 | 65% · 0.16 |
| K + Chain Bolt range 45 -> 55 | K | 46.1 (+4.1) | 41.1 (-1.1) | 58.8 (-0.8) | 69.7 (+0.4) | 69% · 26.1 | 67% · 0.17 |
| K + Chain Bolt range 65 | K | 48.5 (+6.5) | 41.3 (-0.9) | 57.9 (-1.7) | 70.0 (+0.8) | 66% · 26.6 | 67% · 0.17 |
| K + Chain Bolt 8 -> 10 a bolt | K | 45.5 (+3.5) | 41.5 (-0.7) | 59.0 (-0.6) | 69.6 (+0.3) | 70% · 27.3 | 66% · 0.16 |
| K + Chain Bolt 12 a bolt | K | 49.6 (+7.6) | 41.5 (-0.7) | 58.0 (-1.6) | 69.6 (+0.3) | 66% · 29.6 | 66% · 0.16 |
| K + Chain Bolt range 55 and 10 a bolt | K | 50.2 (+8.2) | 40.7 (-1.5) | 57.7 (-1.8) | 69.6 (+0.3) | 65% · 28.6 | 67% · 0.17 |
| K + Umbra dive play + half cooldown (P27's best; control) | K | 42.5 (+0.5) | 44.1 (+1.9) | 60.9 (+1.4) | 67.0 (-2.3) | 71% · 26.7 | 67% · 0.38 |
| + separate escape blink, 10 s cooldown | K + Umbra dive play + half cooldown | 42.2 (-0.3) | 45.2 (+1.1) | 60.4 (-0.5) | 67.8 (+0.8) | 72% · 26.2 | 63% · 1.54 |
| + separate escape blink, 6 s cooldown | K + Umbra dive play + half cooldown | 42.0 (-0.5) | 45.6 (+1.5) | 60.3 (-0.6) | 67.8 (+0.8) | 73% · 26.1 | 63% · 1.98 |
| All together: K + Chain Bolt 55 / 10 + Umbra dive, half cooldown, escape blink 6 s | K | 50.0 (+7.9) | 44.9 (+2.7) | 58.2 (-1.4) | 68.2 (-1.1) | 64% · 29.7 | 64% · 1.95 |
| same, second seed set | v3, live Cryo | 43.8 (-0.7) | 42.0 (-0.1) | 59.8 (-0.8) | 71.4 (+0.8) | 72% · 25.6 | 66% · 0.16 |

**v3, live Cryo (P28/P29 baseline)** — bottom 6: Radiant + Voltaic + Zephyr 23, Aqua + Cryo + Voltaic 21, Cryo + Toxin + Voltaic 21, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 93, Cryo + Pyro + Terra 89, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 84, Terra + Toxin + Voltaic 83
**same, second seed set** — bottom 6: Toxin + Umbra + Voltaic 22, Aqua + Cryo + Voltaic 21, Aqua + Voltaic + Zephyr 21, Radiant + Umbra + Zephyr 18, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Voltaic 15 | top 6: Pyro + Terra + Toxin 95, Cryo + Pyro + Terra 87, Pyro + Terra + Voltaic 86, Pyro + Radiant + Terra 85, Pyro + Terra + Zephyr 83, Terra + Toxin + Voltaic 81
**K = v3 + standing Twin Tide (a, 200, +3 s) + Flash Freeze 25 + Blizzard 20** — bottom 6: Cryo + Voltaic + Zephyr 20, Radiant + Voltaic + Zephyr 19, Cryo + Toxin + Voltaic 18, Cryo + Umbra + Voltaic 17, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 11 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 84, Pyro + Radiant + Terra 84, Cryo + Terra + Umbra 80, Pyro + Terra + Zephyr 80
**Role rule T1 (exactly one Terra) on v3** — bottom 6: Radiant + Terra + Zephyr 35, Aqua + Terra + Voltaic 33, Aqua + Radiant + Terra 32, Terra + Voltaic + Zephyr 31, Radiant + Terra + Umbra 26, Aqua + Terra + Zephyr 23 | top 6: Pyro + Terra + Toxin 82, Cryo + Pyro + Terra 73, Pyro + Radiant + Terra 70, Terra + Toxin + Voltaic 70, Pyro + Terra + Voltaic 68, Terra + Toxin + Zephyr 66
**Role rule T1 on K** — bottom 6: Pyro + Terra + Umbra 33, Aqua + Terra + Voltaic 31, Radiant + Terra + Zephyr 31, Aqua + Terra + Zephyr 27, Terra + Voltaic + Zephyr 26, Radiant + Terra + Umbra 22 | top 6: Cryo + Pyro + Terra 80, Pyro + Terra + Toxin 78, Pyro + Radiant + Terra 67, Cryo + Terra + Toxin 64, Aqua + Cryo + Terra 64, Cryo + Radiant + Terra 64
**Role rule TA1 (exactly one of Terra / Aqua) on v3** — bottom 6: Aqua + Toxin + Umbra 23, Aqua + Radiant + Toxin 22, Aqua + Cryo + Voltaic 21, Aqua + Radiant + Umbra 21, Aqua + Radiant + Voltaic 19, Aqua + Voltaic + Zephyr 17 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 84, Pyro + Terra + Voltaic 81, Pyro + Radiant + Terra 80, Terra + Toxin + Voltaic 80, Pyro + Terra + Zephyr 74
**Role rule TA1 on K** — bottom 6: Aqua + Cryo + Voltaic 25, Aqua + Radiant + Zephyr 25, Aqua + Radiant + Umbra 24, Aqua + Radiant + Toxin 24, Aqua + Radiant + Voltaic 22, Aqua + Voltaic + Zephyr 18 | top 6: Pyro + Terra + Toxin 88, Cryo + Pyro + Terra 88, Pyro + Radiant + Terra 80, Pyro + Terra + Voltaic 78, Cryo + Terra + Toxin 75, Cryo + Radiant + Terra 74
**T1 on K, Blizzard 32 instead of 20** — bottom 6: Pyro + Terra + Umbra 32, Aqua + Terra + Voltaic 31, Radiant + Terra + Zephyr 30, Aqua + Terra + Zephyr 27, Terra + Voltaic + Zephyr 25, Radiant + Terra + Umbra 20 | top 6: Cryo + Pyro + Terra 83, Pyro + Terra + Toxin 80, Cryo + Terra + Toxin 67, Cryo + Radiant + Terra 66, Pyro + Radiant + Terra 65, Terra + Toxin + Voltaic 64
**TA1 on K, Blizzard 32 instead of 20** — bottom 6: Aqua + Radiant + Zephyr 25, Aqua + Cryo + Voltaic 25, Aqua + Radiant + Umbra 25, Aqua + Radiant + Toxin 23, Aqua + Radiant + Voltaic 23, Aqua + Voltaic + Zephyr 17 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 90, Pyro + Radiant + Terra 78, Cryo + Radiant + Terra 78, Cryo + Terra + Toxin 77, Cryo + Terra + Umbra 76
**K + Chain Bolt range 45 -> 55** — bottom 6: Radiant + Voltaic + Zephyr 22, Radiant + Toxin + Zephyr 21, Radiant + Toxin + Umbra 20, Cryo + Umbra + Voltaic 18, Radiant + Umbra + Voltaic 18, Radiant + Umbra + Zephyr 13 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 85, Pyro + Radiant + Terra 83, Cryo + Terra + Umbra 81, Pyro + Terra + Zephyr 79
**K + Chain Bolt range 65** — bottom 6: Cryo + Umbra + Zephyr 23, Radiant + Umbra + Voltaic 21, Radiant + Voltaic + Zephyr 21, Radiant + Toxin + Zephyr 20, Radiant + Toxin + Umbra 20, Radiant + Umbra + Zephyr 13 | top 6: Pyro + Terra + Toxin 91, Cryo + Pyro + Terra 90, Pyro + Terra + Voltaic 89, Pyro + Radiant + Terra 83, Terra + Toxin + Voltaic 82, Cryo + Terra + Umbra 79
**K + Chain Bolt 8 -> 10 a bolt** — bottom 6: Radiant + Toxin + Zephyr 20, Radiant + Voltaic + Zephyr 19, Radiant + Toxin + Umbra 19, Cryo + Umbra + Voltaic 19, Radiant + Umbra + Zephyr 16, Radiant + Umbra + Voltaic 12 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 88, Pyro + Terra + Voltaic 87, Cryo + Terra + Umbra 82, Pyro + Radiant + Terra 81, Terra + Toxin + Voltaic 80
**K + Chain Bolt 12 a bolt** — bottom 6: Toxin + Umbra + Zephyr 25, Cryo + Umbra + Voltaic 20, Radiant + Toxin + Zephyr 18, Radiant + Toxin + Umbra 17, Radiant + Umbra + Voltaic 15, Radiant + Umbra + Zephyr 13 | top 6: Pyro + Terra + Toxin 89, Pyro + Terra + Voltaic 88, Cryo + Pyro + Terra 87, Terra + Toxin + Voltaic 85, Cryo + Terra + Umbra 81, Pyro + Radiant + Terra 80
**K + Chain Bolt range 55 and 10 a bolt** — bottom 6: Toxin + Umbra + Zephyr 23, Cryo + Umbra + Voltaic 21, Radiant + Umbra + Voltaic 20, Radiant + Toxin + Zephyr 20, Radiant + Toxin + Umbra 19, Radiant + Umbra + Zephyr 12 | top 6: Pyro + Terra + Toxin 89, Cryo + Pyro + Terra 87, Pyro + Terra + Voltaic 87, Terra + Toxin + Voltaic 86, Pyro + Radiant + Terra 82, Cryo + Terra + Voltaic 80
**K + Umbra dive play + half cooldown (P27's best; control)** — bottom 6: Radiant + Toxin + Zephyr 21, Cryo + Voltaic + Zephyr 20, Cryo + Toxin + Voltaic 20, Radiant + Umbra + Zephyr 18, Radiant + Voltaic + Zephyr 17, Radiant + Umbra + Voltaic 17 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 88, Cryo + Terra + Umbra 83, Pyro + Terra + Voltaic 83, Pyro + Radiant + Terra 82, Pyro + Terra + Zephyr 77
**+ separate escape blink, 10 s cooldown** — bottom 6: Cryo + Voltaic + Zephyr 21, Radiant + Toxin + Zephyr 20, Cryo + Toxin + Voltaic 19, Radiant + Voltaic + Zephyr 18, Radiant + Umbra + Zephyr 17, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 87, Pyro + Terra + Voltaic 84, Pyro + Radiant + Terra 83, Cryo + Terra + Umbra 81, Pyro + Terra + Zephyr 78
**+ separate escape blink, 6 s cooldown** — bottom 6: Radiant + Toxin + Zephyr 20, Cryo + Voltaic + Zephyr 20, Cryo + Toxin + Voltaic 19, Radiant + Umbra + Zephyr 18, Radiant + Voltaic + Zephyr 18, Radiant + Umbra + Voltaic 14 | top 6: Pyro + Terra + Toxin 90, Cryo + Pyro + Terra 87, Pyro + Terra + Voltaic 84, Pyro + Radiant + Terra 82, Cryo + Terra + Umbra 81, Pyro + Terra + Zephyr 78
**All together: K + Chain Bolt 55 / 10 + Umbra dive, half cooldown, escape blink 6 s** — bottom 6: Aqua + Voltaic + Zephyr 24, Radiant + Toxin + Umbra 24, Cryo + Toxin + Zephyr 23, Radiant + Voltaic + Zephyr 23, Radiant + Toxin + Zephyr 18, Radiant + Umbra + Zephyr 16 | top 6: Pyro + Terra + Toxin 88, Cryo + Pyro + Terra 86, Pyro + Terra + Voltaic 85, Terra + Toxin + Voltaic 84, Pyro + Radiant + Terra 81, Cryo + Terra + Umbra 80
**All together, under role rule T1** — bottom 6: Pyro + Terra + Umbra 34, Aqua + Terra + Voltaic 34, Terra + Voltaic + Zephyr 29, Aqua + Radiant + Terra 28, Radiant + Terra + Zephyr 27, Aqua + Terra + Zephyr 21 | top 6: Pyro + Terra + Toxin 76, Cryo + Pyro + Terra 75, Terra + Toxin + Voltaic 68, Pyro + Terra + Voltaic 65, Cryo + Terra + Umbra 64, Cryo + Terra + Voltaic 63

## Modelling gaps (handoff G), and two corrections to the handoff

- **Body-blocking by walls isn't modelled.** Bulwark Wall and the standing Twin Tide only stop shots in the sim. Every
  result with a wall in it (K, the role-rule runs on K) is win-rate-only, and a wall that blocks movement could change
  them either way.
- **The 45 studs/s chase speed doesn't enter these numbers.** The 3v3 sim is running-only at 25 studs/s (the team-mode
  assumption); the 45 studs/s chain estimate belongs to the 1v1 movement sims. It still needs measuring in Play for those.
- **Correction: Twin Tide's live numbers were confirmed** in Studio during P28. Two walls, 24 long and 13 tall, solid for
  about 0.94 s (0.16 to 1.1 s after the cast); no HP; client-side colliders that stop bodies but not shots; 30 mana,
  16 s cooldown. The standing version in K is a design proposal on top of that.
- **Also from P28, not in the handoff:** Blizzard and Deep Freeze land at Cryo's feet live, and every number here uses
  that.
- **These are bot fights,** with rules for aim, dodging and teamwork, not measurements from players.
