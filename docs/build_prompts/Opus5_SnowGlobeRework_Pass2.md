# SPELLSHOT — Build Prompt #[N]: Snow Globe Rework, Pass 2 (Mirror Cage + Flash Freeze)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Snow Globe Studio wiring pass; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final.

**Token budget:** one agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. View at most three images in total (the silhouette sheet, one in-game comparison, one final). Keep progress notes to a line and the final report short.

## Why this pass exists

The user reviewed the Cryo "Snow Globe" Epic skin in-game (screenshot attached to this prompt) and is not satisfied: it does not look amazing, and it does not look clearly better than the Uncommon and Rare skins. The approved Snow Globe HUD icons look right (bold ink outline, flat cyan, white, halftone dots). The 3D effects do not match them. Diagnosis:

1. **Wrong art style for this game.** SPELLSHOT is pop-art comic: flat saturated blocks, a bold black ink outline, three flat tone bands, halftone patches, hard-edged shapes. The Mirror Cage dome is a nearly invisible see-through glass shell with thin glowing edges, with no ink outline and no tone bands. An earlier brief asked for transparency 0.85+ and glowing edges. That conflicts with the project's toon rules (opaque meshes only), so drop it.
2. **Too thin and too small for the scale.** A radius-20 dome built from hairline ribs plus tiny snow specks reads as nothing from normal 1v1 distance. The ground rim is a thin dark-blue band with no outline.
3. **Low colour contrast.** Pale grey-white pieces with no clear dark/mid/light separation.

## Current state

- The Snow Globe skin (Epic, Cryo) is built and wired through a separate module, with a minimal hook in `CryoFX.lua`. Find the module name and the hook with targeted searches. **`CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals** (stop and tell the user if a hook would need one).
- In-game today, from the previous checkpoint's numbers: Mirror Cage = glass dome plus plinth plus about 29 snow flakes plus 12 snowflake darts in flight (about 12,178 tris vs Frost Lotus's 14,318); Flash Freeze = 12 rim segments plus puffs plus drifts (about 6,264 tris vs Lotus's 7,866). Confirm these in the code and the Blender file.
- The six Snow Globe HUD icons are approved. The health-bar accent is being done by someone else.
- This prompt's facts come from design manual v0.24 and a project reference checked 2026-09-13. **The code wins on how something works today, and the manual wins on what it should do.** If either disagrees with this prompt, say so in your report rather than silently picking.

## Reference before styling

- **Style target:** the six approved Snow Globe HUD icons (find them with a targeted search in the icon folder; the files carry the SnowGlobe marker). The 3D must look like those icons coming to life: same ink weight feel, same flat cyan, white, and halftone. View one or two at most.
- **What to fix:** the attached in-game screenshot.
- **Comparison pieces:** the Default Cryo Mirror Cage and Flash Freeze, and Frost Lotus.

## Design direction

**The house rules, from the code (this is the part that was missed):**
- Tone bands, three flat steps baked into per-face vertex colours (palette `VFXLibrary.Config.Colors`): IceDeep `#0E4FA8` (shadow), IceMid `#3FB6F0` (mid), IceLight `#D6F6FF` (lit), Rim `#FFFFFF`, Outline `#080E1A`.
- Outline = an inverted hull (inflated, single-sided copy of the mesh in unlit ink).
- In Roblox: `MeshPart.Color` white, `Material` `SmoothPlastic`, `DoubleSided = false`. No Neon, Glass or Ice material, no tint.
- **Opaque.** No transparency on any mesh, because it shows the black inside of the hull. Fade by sinking or shrinking. The one exception is `VFXLibrary.RegisterProximityFade` for the caster's own nearby parts, which the Cage and rim must use.

**Shape grammar:** Cryo is angular, faceted and crystalline, never a soft blob. Its logo is a six-arm snowflake with a hexagonal core: use six-arm and hexagonal shapes so identity survives the Colourblind-Safe palette (Cryo's colour does not change there, but shape should carry identity anyway).

**Mirror Cage, "the giant globe" (proposal, flagged):**
- A solid opaque dome would wall off vision, which is unacceptable in PvP. Make the globe a **skeleton**: a few thick, opaque, ink-outlined ribs forming the hemisphere (hexagonal or triangulated facets, or latitude rings plus meridians), with **open faces** between them so players can always see and shoot through. The ribs must be chunky enough that the globe silhouette is recognisable at on-screen size from normal 1v1 distance. If that costs triangles, spend them by deleting hairline detail, not by going over budget.
- A **heavy plinth** at the ground edge: a tall, chunky hexagonal base band, with a flat IceLight top, an IceMid face, an IceDeep underside, and a halftone patch band on the side face.
- Inside, **6 or so large hero snowflakes** (opaque, flat-sided six-arm, ink-outlined, slowly drifting) instead of lots of tiny specks. Add a few small hard-edged flakes as support only.
- "Shake, swirl, settle" stays the rhythm: wobble on cast, flakes billow up, then settle and sink into the plinth over the volley (1.6 s). Do not change the ring structure (14/10/5), radius (20), bolt count (12 per enemy) or timing.
- The snowflake-dart bolts stay as built.

**Flash Freeze rim and base (proposal, flagged):**
- The ground ring must read at player height: a chunky, **taller** hexagonal-segment band with the same three tone bands and ink outline, a halftone patch on the side face, and a few large upright snowflake studs along the edge. Ring only, with no dome over the rooted target.
- Billow and settle use the custom `Shard` sprite (hard alpha cut) as the main read, and the soft built-in smoke only as a small, short support under it.

**Shared base language:** the plinth and rim should be one family, because the M1 globe's base disc and Blizzard's rim will inherit it in later passes. Build the sections so they can be reused.

**Palette:** shipped Cryo colours only. No magenta. **No gold or amber:** gold is the Ultimate UI colour (`#F5B800`) and Mirror Cage is the Ultimate, so a warm accent would read as UI. The earlier open question about an amber accent stays closed unless the user reopens it.

## Integration

- Stay in the existing separate module, with the existing minimal hook. No new broadcast kinds unless unavoidable, and flag it if so.
- All emitters go through the `emitter()` helper, so Graphics Quality density, Reduce Enemy VFX and Reduce Flashing apply. No full-screen flash.
- Visibility stays hit-honest: the Cage and rim must hide players and projectiles no more than the Default Mirror Cage's rings and the Default Flash Freeze do. Skin parts are Massless, CanCollide false, CanQuery false, CanTouch false. Gameplay values, timing, hitboxes and geometry of the real cage stay untouched.
- Keep the existing callouts (FROZEN!, CHILL) and status reactions unchanged.
- **Performance budget (low-end mobile):** stay at or under the current per-ability triangle and particle totals (Mirror Cage 85%, Flash Freeze 80% of Lotus). Pool anything that spawns repeatedly. Check against Lotus in the final comparison.
- No kill effect (Mythic skins and Character bundles only), no avatar change, no health bar.
- **Reskin note (flag, don't decide):** record how this skin's palette could be swapped later, since baked vertex colours make that hard. Do not decide the approach.

## Animation, both layers

No new clips. The existing cast beats stay: each clip's `Trigger` equals `VFXLibrary.Tuning.<Ability>.LeadIn`, and the wobble, billow and settle land on that beat as world effects only. Review in slow motion with `ShotTimeScale` / `CastPoseTimeScale`.

## Checkpoint before final

1. **Silhouette checkpoint (no colour, no outline detail):** flat grey shapes only, for the Mirror Cage skeleton-globe with plinth and the Flash Freeze rim, shown at the **on-screen size** from the same 1v1 camera distance as the attached screenshot, next to the current version and Frost Lotus. One image. Stop and wait for approval.
2. **After approval:** add the tone bands, ink hull and halftone. Then take one in-game screenshot at the same camera distance, with the new version, the current version and Frost Lotus side by side. Report anything where Snow Globe still looks weaker than Lotus.

## Scope reminder

Only the Mirror Cage globe, the Flash Freeze rim/base plinth, and the particle presets they share. Not in this pass: the M1 globe and its impact, Cold Momentum prints, Blizzard, Deep Freeze (stays Default), HUD icons, the health-bar accent, wraps, and any new ability, word or mechanic. Those get their own passes after this look is approved.

Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
