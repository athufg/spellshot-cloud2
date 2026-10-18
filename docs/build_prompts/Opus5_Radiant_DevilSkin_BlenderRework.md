# SPELLSHOT — Build Prompt #[N]: Radiant "Devil" skin (Blender rework of every Radiant ability)

Continuation of the Opus 5 / Claude Code build sequence (keep [N] as a placeholder).
**Quality bar: make it genuinely amazing.** A player must read "that is a devil" in under a second at game distance, from the silhouette alone. **And be very token efficient** (see the last section).
**Vocabulary (the developer's):** a **skin** is a full rework of the ability's models and effect geometry, built in Blender. A **wrap** (recolour only) is a different thing and is not this pass. This pass builds assets only. **Nothing goes into Studio**, and nothing touches the skin catalog or the Loadout menu.

## Where the work lives (read this folder, nothing else)

`C:\Users\night\Downloads\radiant\RAIDANT\radiant_rework_2026_09_29\`
- There are **no .blend files**. Each asset is a **Blender Python script** that builds the model and the animation: `phase4_r3\<piece>\<piece>_r2.py` for Light Lance, Blessing, Overflow Light, Halo, Position Trade and Benediction, and `phase1_staff\scripts\staff_A.py`, `staff_B.py`, `staff_C.py` for the staff. The shared kit is `phase4_anim_vfx\_kit\rad_anim.py`, the stage and runner are in `phase1_staff\scripts\lib\` (`radiant_stage.py`, `run_blender_q_rad.sh`), and each piece folder has `keys.json` (the animation keys exported as data) and `<piece>_stats.json` (the budget numbers). If a real .blend exists anywhere, use it, otherwise edit these scripts.
- **Round 3 is the current Default look** (`phase4_r3\PHASE4_R3_REVIEW.md` has the facts: one-hand Benediction with the sky sigil and column, glow scaled by 0.6 on purpose, budgets 80 pieces / 40 sparkles / 3 lights). `phase1_staff\REVIEW.md` and `phase5\` show which staff was actually picked and how it reads in game. The developer believes it is staff **A (Halo Staff)**: confirm from those, say what you found, and flag if different.
- **Never edit the originals.** Create a sibling folder `radiant_devil_skin_2026_10_12\` with the same per-piece layout (script, mp4, sheet, game-camera still, `keys.json`, stats). Copy a script, change it, keep the shared kit imported rather than copied.

## Concept: classic red devil (the developer's pick) — PROPOSALS, flag what you change

Radiant's identity today is "pattern, not substance": thin lines and rings with cream cores on dark bronze bezels. The Devil skin **keeps that line-and-ring language and the same pieces, but every part is horned, barbed and thorned, and the metal is black iron.** Rework each ability's models, not just their colours.

- **Staff:** a black-iron **trident** (flag: the developer has not confirmed trident vs pitchfork, use a trident) with a barbed three-prong head, a thorned shaft wrap, and a small broken halo ring hanging off the head so it is still recognisably Radiant's staff. Keep the grip point, overall length and weight in the hand identical to the current staff so the existing carry, walk and cast poses still fit with no pose edits. Stay inside the 2,500-triangle budget.
- **Halo (Ultimate):** bat-wing bones with thin crimson-ember seams in place of the feathered wings; small horns and a broken thorned halo crown on the caster. Same span, same float and glide timing.
- **Blessing (Bond and shield):** the armillary shield becomes a runed black-iron version with horned clasps, over a pentagram-in-ring ground sigil. The Bond thread carries barbed chevrons (devil-tail tips). The shield keeps its current size and its read as a shield.
- **Overflow Light (passive payoff):** the collapse becomes an ember **brand** burned onto the chest, using embers and sparks, **not flame shapes** (Pyro owns the flame silhouette).
- **Position Trade:** both bodies sink into ground seals and swap through them, joined by a thin contract line. Same timing.
- **Benediction:** keep the whole one-hand design and the tell exactly (kneel, staff driven in, left palm to the sky, sigil 180 studs above, column into the palm, 4 pulses, comets, Bond threads to allies). Rework the look: the sigil becomes an **inverted pentagram-in-ring**, the column a black-iron-and-crimson shaft with ash rings and ember motes, the staff head flares on each pulse. **The tell must stay at least as visible as Default** (column about 80% of frame height at 135 studs).
- **Light Lance (M1):** a crimson beam with a white-hot core, thorned ring flares along its length, and a brand sigil on impact. Same beam thickness and length, so hit readability is unchanged.

## Colour rules (PROPOSAL values, flag them)

- **Black iron (warm black, not the cool purple-black Terra uses):** `#1A1416`, `#2E2326`, `#4D3A3C`. Bone accents `#E9DCC0`. Hellfire crimson `#7A0C14`, `#C8141C`, hot edge `#FF4A3A`. Keep Radiant's own gold `#F5C230` and cream `#FFF7D6`.
- **Readability risk, important:** in this game teams read red and cyan, so a red-heavy skin can look like the enemy team and a red beam can look like damage. **Rule: crimson means harm (Light Lance, impacts, brands). Anything that carries healing to an ally (the Blessing shield glow, Bond heal flow, Benediction comets and heal pulses, the Overflow Light heal) stays Radiant gold.** Structures (sigils, columns, staff, wings) are black iron with crimson accents. Do not use Pyro orange `#F25C0D` or `#FFC74D`-type flame colours; no magenta `#E91E8C`.
- Shape carries identity too, because the Colourblind-Safe toggle swaps Element colours: horns, barbs, bat wings, pentagram and the broken halo must read in a flat silhouette.

## Rules that do not change (cosmetic only)

- **Animation and gameplay timing:** keep every `keys.json` beat, pose and duration identical to round 3. Changing a model must not require a new pose. If a model genuinely needs a pose change, stop and flag it, do not do it.
- **Budgets per piece:** at most 80 pieces, 40 sparkles and 3 lights (staff 2,500 triangles), and report each piece's stats in its `_stats.json`. Keep the kit's glow scale of 0.6 (the developer asked for it), glow only on cores, nothing flickering, nothing that needs more lights.
- No effect may become less readable or less of a tell than Default. The skin is cosmetic: no gameplay value, no hit-feedback timing change.

## Checkpoints (stop and post, in this order; wait for approval each time)

1. **Staff:** the trident in hand, third person at game distance (the way `02_game_distance.png` was shot), plus a flat black silhouette test and one close-up. Approval before anything else.
2. **Halo wings and crown:** same views, same silhouette test.
3. **The rest in one pass:** Blessing, Overflow Light, Position Trade, Benediction, Light Lance, each with an mp4, a frame sheet, a game-camera still, `keys.json` and stats, plus one overview image of all six (like `RADIANT_PHASE4_R3_OVERVIEW.png`) and the Benediction beacon still from 135 studs.

## Scope

Not in this pass: Studio, the skin or wrap catalog, the Loadout menu, new gameplay or poses, any other Element, a Mythic or animated tier, Sparks or rarity gating, the hotbar icons, and the skin's price, tier or final name ("Devil" is a working name). Flag anything ambiguous in one line instead of deciding it.

## Efficiency (the developer asked for this to be very token efficient)

One agent, no subagents. Read only `PHASE4_R3_REVIEW.md`, the staff REVIEW, the shared kit, and the specific `_r2.py` and staff script for the piece you are working on. Do not read other files, and do not re-read a file after you edit it. Change the copied scripts with small targeted edits, not rewrites. **Iterate at low resolution and with few frames; render at full quality only for a checkpoint.** At most one combined image per checkpoint plus the final overview. No narration between steps beyond one line. Finish with a short report: what you built per piece, the stats against the budgets, what you flagged (staff confirmed, trident choice, anything that wanted a pose change).
