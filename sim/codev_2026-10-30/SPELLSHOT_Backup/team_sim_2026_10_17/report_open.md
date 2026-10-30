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
