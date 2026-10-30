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

## Answer

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

{{VOLT}}

### D. Umbra's escape as its own charge (Priority 3)

{{UMBRA}}

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

{{TABLES}}

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
