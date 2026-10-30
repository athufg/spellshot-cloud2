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
