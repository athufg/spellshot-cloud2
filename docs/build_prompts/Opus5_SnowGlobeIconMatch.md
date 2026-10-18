# SPELLSHOT — Build Prompt #[N]: Snow Globe, Build the Effects From the HUD Icons

Continuation of the Opus 5 / Claude Code build sequence (previous: the Snow Globe Studio wiring pass; filename unknown). This replaces `Opus5_SnowGlobeRework_Pass2.md`: use this one.
This is visual/VFX work: real reference before styling, checkpoint before final.

**Token budget:** one agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. View at most two images per stage (a silhouette sheet and an in-game comparison). Keep progress notes to a line and each stage report short.

## Why this pass exists

The user reviewed the Cryo "Snow Globe" Epic skin in-game (screenshot attached) and is not satisfied: the world effects do not look amazing for an Epic skin and do not look clearly better than the Uncommon and Rare skins. The six approved Snow Globe HUD icons look great: bold ink outline, flat cyan, white, halftone dots, one strong idea each. **The goal of this pass is to build every in-world effect directly from those icons, so the 3D reads as the icons coming to life.** Diagnosis of the current build:

1. **Wrong art style for this game.** SPELLSHOT is pop-art comic: flat saturated blocks, a bold black ink outline, three flat tone bands, halftone patches, hard-edged shapes. The Mirror Cage dome is a nearly invisible see-through glass shell with thin glowing edges, with no ink outline and no tone bands. An earlier brief asked for transparency 0.85+ and glowing edges. That conflicts with the project's toon rules (opaque meshes only), so drop it.
2. **Too thin and too small.** A radius-20 dome of hairline ribs plus tiny snow specks reads as nothing from normal 1v1 distance. The ground rim is a thin dark band with no outline.
3. **Low contrast.** Pale grey-white pieces with no clear dark, mid and light separation.

## Current state

- The Snow Globe skin (Epic, Cryo) is built and wired through a separate module, with a minimal hook in `CryoFX.lua`. Find the module name and the hook with targeted searches. **`CryoFX.lua` is at Luau's 200 top-level-locals limit: add no new top-level locals** (stop and tell the user if a hook would need one).
- Current numbers from the previous checkpoint (confirm in the code and the Blender file): Mirror Cage about 12,178 tris vs Frost Lotus's 14,318; Flash Freeze about 6,264 vs 7,866; M1 globe about 269 per shot; Blizzard about 2,994 vs 864; Cold Momentum print 84.
- The six Snow Globe HUD icons are approved and in the icon folder (files carry the SnowGlobe marker). The health-bar accent is being done by someone else. Deep Freeze stays on the Default look in-world.
- This prompt's facts come from design manual v0.24 and a project reference checked 2026-09-13. **The code wins on how something works today, and the manual wins on what it should do.** If either disagrees with this prompt, say so in your report.

## Reference before styling

- **Style target and blueprint:** the six approved HUD icons plus the M1 and Cold Momentum icons (find them in the icon folder; view only the ones you need). Each in-world piece below is derived from its icon.
- **What to fix:** the attached in-game screenshot.
- **Comparison pieces:** the Default Cryo versions and Frost Lotus.
- **Icon-match test, used at every checkpoint:** render each 3D piece from the icon's own camera angle and put it next to its icon. They must read as the same object. If a piece fails that test, redo it.

## Design direction

**House rules from the code (this is what the first build missed):**
- Three flat tone bands baked into per-face vertex colours, palette `VFXLibrary.Config.Colors`: IceDeep `#0E4FA8` (shadow), IceMid `#3FB6F0` (mid), IceLight `#D6F6FF` (lit), Rim `#FFFFFF`, Outline `#080E1A`.
- Outline = an inverted hull (inflated, single-sided copy in unlit ink). Make the ink read as heavy as the icons' outline at on-screen size.
- In Roblox: `MeshPart.Color` white, `Material` `SmoothPlastic`, `DoubleSided = false`. No Neon, Glass or Ice material, no tint.
- **Opaque.** No transparency on any mesh, because it shows the black inside the hull. Fade by sinking or shrinking. The one exception is `VFXLibrary.RegisterProximityFade` for the caster's own nearby parts, which the Cage and the rim must use.
- Particles: a hard-edged main read (custom `Shard` sprite `rbxassetid://98211061341574`, hard alpha cut). Soft built-ins only as small, short support. Always create through `emitter()`.
- Halftone dots in **patches** (plinth sides, a flat ground patch), never over everything.

**Shape grammar:** Cryo is angular, faceted, crystalline, never a soft blob. Logo: six-arm snowflake with a hexagonal core. Use six-arm and hexagonal shapes so identity survives the Colourblind-Safe palette.

**Build each piece from its icon (all proposals, flagged):**

1. **Mirror Cage (R icon: a globe with converging darts on a striped plinth).**
   - A solid opaque dome would wall off vision, which is unacceptable in PvP. Make the globe a **skeleton**: a few thick, opaque, ink-outlined ribs forming the hemisphere (hexagonal or triangulated facets, or latitude rings plus meridians), with **open faces** so players can always see and shoot through. The ribs must be chunky enough that the globe silhouette is recognisable at on-screen size.
   - A **heavy plinth** exactly like the icon's: a tall chunky hexagonal base with the IceDeep, white-stripe and IceMid bands, and a halftone patch on the side face.
   - About 6 **large hero snowflakes** inside (opaque, flat-sided six-arm, ink-outlined, drifting), instead of lots of tiny specks.
   - **Darts like the icon's:** chunky, 3D, ink-outlined, readable from every angle.
   - **Rhythm and payoff:** the whole frame wobbles on cast like a shaken globe, flakes billow up, then settle and sink into the plinth over the volley (1.6 s). When the Cage expires, the ribs crack into hard-edged shards (the same shatter idea Cryo already has) instead of fading.
   - Radius 20, rings of 14/10/5, 12 bolts per enemy and the timing stay untouched.
2. **Flash Freeze (F icon: a wide rim with upright snowflakes around it).**
   - The ring from the icon: a chunky, **taller** hexagonal-segment band with the three tone bands, an ink outline, a halftone patch on the side face, and 4 to 6 large **upright snowflakes** on the rim.
   - A flat **halftone ground patch** inside the zone so the area reads from across the map (reuse `FrostTile` or the Default zone look as a base, and flag it if a new texture is needed).
   - Ring only, with no dome over the rooted target. Billow and settle use `Shard`-sprite particles as the main read.
3. **M1 Icicle Shard (M1 icon: a globe on a disc, big stars inside, settled snow at the bottom).**
   - The projectile is that icon: a **chunky, opaque, ink-outlined mini globe** on its disc, with big flat stars inside (separate opaque shapes, not particles). It must stay visible in flight and keep the shot honest. It fires up to 3 times a second, so keep parts and particles minimal, with a short hard-edged star or shard trail.
   - **Impact:** the globe cracks into a few thin ink-outlined glass slabs that fly outward, a small snow pile settles on the ground for a moment, and an angular chip burst plays at the shooter's own hit moment (use the existing chip/crack presets).
4. **Cold Momentum (icon: snowflake prints):** chunky, ink-outlined, flat snowflake prints on the ground behind the player, each with a small star pop when it lands. Low count, pooled, short-lived. Lowest priority.
5. **Blizzard (Q icon: a rim with a swirl and pines).**
   - The rim is the same family as the Flash Freeze ring, with the **Frost Line kept clearly legible**. Tall and short snow-capped pines (opaque, ink-outlined), varied in scale and rotation.
   - The flurry as **large white crescent streaks of snow** rotating in one direction, thin in the middle, heavier toward the edge. **Do not draw an open spiral:** that is Zephyr's logo, and a shape must never be borrowed from another Element. Flag it if the approved icon's swirl pushes you toward one.
   - The existing settle-to-clear expiry tell stays. Blizzard's screen obstruction must be no greater than Default Blizzard's, and its gameplay visibility reduction is unchanged.

**Shared base language:** the plinth, the rim and the Blizzard rim are one family. Build one reusable set of sections with the three tone bands, the ink hull and the halftone side patch.

**Palette:** shipped Cryo colours only. No magenta. **No gold or amber:** gold is the Ultimate UI colour (`#F5B800`) and Mirror Cage is the Ultimate, so a warm accent would read as UI.

## Integration

- Stay in the existing separate module and hook. No new broadcast kinds unless unavoidable (flag it if so).
- All emitters go through `emitter()`, so Graphics Quality density, Reduce Enemy VFX and Reduce Flashing apply. No full-screen flash.
- Visibility stays hit-honest: nothing may hide a player or projectile more than the Default effect does. Skin parts are Massless, CanCollide false, CanQuery false, CanTouch false. Gameplay values, timing, hitboxes and geometry stay untouched.
- **Budget (low-end mobile):** stay at or under the current per-ability triangle and particle totals, except Blizzard, which is already over Lotus's and should come down toward it where possible. Spend triangles on chunky silhouettes by deleting hairline detail. Pool anything that spawns repeatedly. Check against Lotus at each in-game comparison.
- Keep the existing callouts (FROZEN!, CHILL) and status reactions unchanged. No new callout words. A comic burst on a beat uses the existing Cryo burst art, not new lettering.
- No kill effect (Mythic skins and Character bundles only), no avatar change, no health bar, no new HUD icons.
- **Reskin note (flag, don't decide):** record how this skin's palette could be swapped later, since baked vertex colours make that hard. Do not decide the approach.

## Animation, both layers

No new Viewmodel or CastPose clips. The existing cast beats stay: each clip's `Trigger` equals `VFXLibrary.Tuning.<Ability>.LeadIn`, and the wobble, billow and settle land on that beat as world effects only. Review in slow motion with `ShotTimeScale` and `CastPoseTimeScale`.

## Checkpoints before final

Work in three stages. Each stage ends with a checkpoint, and you do not start the next one until the user approves.

- **Stage 1: shared plinth/rim family, Mirror Cage, Flash Freeze.**
  - Checkpoint A: a flat grey silhouette sheet (no colour or outline detail) at the on-screen size from the 1v1 camera distance of the attached screenshot, next to the current version and Frost Lotus, plus the icon-match render of each. Stop for approval.
  - Then add the tone bands, ink hull and halftone, and take one in-game side-by-side (new, current, Lotus). Report anything still weaker than Lotus. Stop for approval.
- **Stage 2: M1 and Cold Momentum.** Same pattern: silhouette plus icon-match, approval, then colour and in-game comparison.
- **Stage 3: Blizzard.** Same pattern.

## Scope reminder

Only the Snow Globe in-world effects above. Not in this pass: HUD icons, the health-bar accent, Deep Freeze, wraps, other skins, and any new ability, word or mechanic.

Flag anything ambiguous instead of deciding it, and add nothing that wasn't asked for.
