
## 4. Gap closers against the shared chain (pass d, part 2)

| Closer | Effective closing speed | vs chain 59 | Works through a cap of 14–15? |
|---|---|---|---|
| Shared chain (every Element) | ~59 sustained, 66.8 peak | — | no: capped |
| Shadow Step (Umbra) | ~183 over 22 studs | faster | not verified |
| Overcharge (Voltaic) | 69 over 11 studs | faster, tiny | yes (MinCap 12) |
| Bulwark Charge (Terra) | 42 over 26 | slower | yes |
| Undertow (Aqua) | ~41 (moves the target 36) | slower | yes |
| Skyrider (Zephyr) | 42 / 55 | slower | not verified |
| Cross-Slash (Zephyr) | 15–27 | much slower | yes |

**Closing always wins once it starts**, except against Cryo: only Chill (cap 22, then 15) and Blizzard (14) drop the
chain below the kiter's own 59, and both are Cryo's (Blizzard is in the shared pool). Every dash still works under every
cap except Flash Freeze's 5 and roots, because the dash threshold is 12.

## 5. Mana economy (pass c; every hit lands, DoTs run full)

| M1 | Damage/s | Mana/s | Damage per mana | Sustainable on 7/s regen? |
|---|---|---|---|---|
| Icicle Shard | 24 | 6.0 | 4.0 | yes |
| Fireball | 30 (+9 splash) | 5.0 | 6.0 | yes |
| Wind Blade | 25 | 6.7 | 3.75 | yes |
| Boulder Shot | 24.6 | 2.05 | 12.0 | yes |
| Chain Bolt | 25 (range 30) | 6.25 | 4.0 | yes |
| Shadow Dart | 25 | 1.9 | 13.0 | yes |
| Light Lance | 16 → 32 | 7.5 | ~3.7 | net −0.5/s |
| Riptide | 18 | 6.0 | 3.0 | yes |
| Toxic Bubbles | 16.4 + 4 poison | 5.45 | 3.7 | yes |

Every M1 except Light Lance costs less than the regen, so firing never costs a decision.

| Ability | Damage (or heal) a cast | Per mana | Per second of cooldown | Note |
|---|---|---|---|---|
| **Scorching Lash** | 12 + 16 burn a stack (3 stacks: 14 dps sustained) | 2.3 | **10.3–14** | 2.5 s cooldown, 4.4 mana/s: a second M1 at close range |
| Detonate | 12–48, no line of sight | 0.6–2.4 | 0.9–3.4 | |
| Immolate | +36 | 1.4 | 3.0 | |
| Flash Freeze | 44 + ~4 s root | 1.5 | 3.1 | the root is worth ~12 free Icicle hits |
| Railspike | 30 | 1.5 | 3.0 | |
| Volt Orb | 14–36 | 0.7–1.8 | 1.2–3.0 | |
| Bulwark Charge | 35 + stagger | 1.2 | 3.9 | |
| Aftershock | 20 + knock | 1.0 | 1.7 | |
| Cross-Slash | 30 | 1.2 | 3.0 | |
| Mark | +10 to +150 | 0.6–8.3 | 0.7–10.7 | headshot-dependent |
| Twin Tide | 35 | **0.9** | 2.2 | worst damage per mana |
| Sidearm | 8 a bullet, 12.8 dps | 1.3 | — | 9.6 mana/s: cannot be sustained |
| Corrosive Cloud | ≤36 + poison | 1.4 | 4.0 | only if they stand in it |
| Acid Rain | ≤16 + Corroded | **0.5** | 1.1 | |
| Benediction | 15 HP/s for up to 30 s (~450 HP) | 1.5 HP/mana | — | no real cap on sustain |
| Blessing | 35 shield | 1.4 HP/mana | 2.9 | |

## 6. Simulation (passes a and b)

**Model** (assumptions, all in `sim.py`): open disc arena r120, spawns 220 apart near the edge, no cover, no walls;
aim spread 1°, 40 ms tracking lag, 45% of a target's lead unpredictable; telegraph reaction 0.15–0.45 s; Ultimates ready
after 30 s; default loadouts; preset A. Rusher: closes with the chain, fights at its close range with its best
close kit. Kiter: holds its longest range, uses slows and roots on cooldown, escapes with its tools. 60 runs a pairing.
The mixed/adaptive policy was not run.

Headline numbers:
- **Contact comes in ~4 s in 75 of 81 pairings** (mean 5.6 s). Only a Cryo kiter holds a rusher off for longer
  (12–34 s), through Chill and Blizzard.
- **A kiter deals 22 HP on average from beyond 40 studs before the fight closes** (15% of a life).
- **Point-blank is the best range for nearly every kit:** the TTK search picked 8 studs for most attacker–target pairs
  and 20 for the rest; no kit's best range was 45 or 90.
- Rusher wins: 37 of 81 pairings above 55%, 41 below 45%. The outcome is set by close-range strength, not by the
  approach.
- **Kill time spread is 2.8×:** Pyro kills in 3.6 s on average, Toxin in 10.1 s. Terra is the hardest to kill (9.5 s).
