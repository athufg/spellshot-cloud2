# The owner's P28 and P29 specs (pasted 2026-10-18), kept for reference

## SPELLSHOT — P28 Candidate Fix: A Second Team Protector (Twin Tide)

Purpose: ready-to-test spec for the next stat-package simulation pass. Answers P28's option (b) — give a second Element real team-wide protection, so Terra isn't the only comp-defining pick. Directly motivated by P27's result: individual escape tools don't move the needle because the real cause is team-level — every bottom-6 comp lacks both Terra and Pyro, every top-6 comp has Terra, in every run tested.

Constraint: Aqua already sits as a partial Strategist/Vanguard hybrid (knockback peel via Sidearm). Giving Twin Tide real shot-blocking value extends that identity rather than cloning Terra's Defence role — and it needs to land weaker than Terra's wall, or this just relocates the monopoly to Aqua (the Pyro → Terra failure).

Known unconfirmed baseline: Twin Tide's live numbers (cast count, any wall/zone HP, width, duration, cooldown) need a Studio check before locking test numbers. The numbers below are starting points.

Mechanic: give Twin Tide's water wall(s) the same kind of shot-blocking value Bulwark Wall has — currently (assumed) knockback/zone control only, no projectile-blocking.

Variants, each at a fraction of Terra's buffed wall (300–400 HP in v2/v3):
- (a) Single wall, weaker: one wall, same footprint as today's Twin Tide, now blocks shots. HP 150 / 200 / 250.
- (b) Split "twin" walls: two smaller walls, HP pool split across both. 100+100 / 125+125.
- (c) Ally-only blocking: blocks shots for allies behind it, not for Aqua. Same HP range as (a).

Width, duration, cooldown: carry over Twin Tide's live values unless the Studio check shows otherwise — this spec only adds shot-blocking.

Test plan:
1. Confirm Twin Tide's live baseline numbers in Studio — flag if the spec's assumptions were wrong.
2. Each variant as a toggle on top of package v3 (same base as P27).
3. Re-run the 84-comp round-robin (3,486 pairings), 6 rounds per pairing minimum, with a noise-check second seed set.
4. Check, in order: (i) does Aqua's win rate rise into a real, usable range; (ii) does Terra's win rate drop, or does Terra+Aqua become a new must-pick pair; (iii) does the comp spread (~19–21 SD) narrow, or does dominance relocate.
5. Re-check bottom-6/top-6: do comps lacking both Terra and Aqua become the new bottom cluster? If so, same shape problem.

Cross-reference: P25 found Bulwark Wall Technique-swapping the biggest raw-power exploit (Pyro 7% → 54–59% as a swap-in at 200 HP). If Twin Tide gets real blocking value, it needs the same Technique-swap re-test before shipping.

## SPELLSHOT — P29 Candidate Fix: Cursor-Targeting for Self-Centered Abilities

Purpose: run in the same round as P28 — different toggle, same base package (v3).

Question: some abilities land where the caster stands instead of at the cursor. Should they be converted to cursor-targeted, each at a range tuned per ability?

Why: P23 finding 3 — Cryo is the only kit whose tools fight a chaser's approach, yet still loses once contact happens. A self-centred CC needs the enemy to have already closed the distance.

Step 0: confirm the list. Only Flash Freeze is confirmed (owner). Candidates to check: Blizzard, Deep Freeze, Mirror Cage, Benediction, anything else at the caster's feet across all 9 Elements.

Step 1: convert each confirmed ability to cursor-targeted up to a per-ability max range. Doses: Flash Freeze 15 / 20 / 25; other zones/CC: about their own radius, plus one shorter and one longer. Test each (a) straight conversion, same numbers; (b) with a trade-off (slightly reduced radius, duration, or a wind-up) to see what keeps power roughly where it started.

Test plan:
1. Confirm the list (Step 0).
2. Toggles on top of v3, same base as the P28 test.
3. Re-run the 84-comp round-robin, same rigour (noise-check seed set, 6+ rounds per pairing).
4. The metric that answers it: does the affected Element's win rate in contact/close-range exchanges change, not just overall win %. For Cryo: does it win more of the fights it used to lose once an enemy closed distance.
5. Report per-Element deltas as the last two reports did, plus bottom-6/top-6 movement.
