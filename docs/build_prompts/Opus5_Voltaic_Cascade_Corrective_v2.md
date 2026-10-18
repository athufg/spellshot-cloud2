# SPELLSHOT — Build Prompt: Voltaic Ultimate — Cascade Corrective Pass #2

**Standalone, self-contained prompt.** This is a corrective pass on Cascade only, following two prior builds.
Read the "Current state" section carefully — it tells you exactly what to keep from the second build and exactly
what to fix. Don't redo the parts that already work.

## Current state — the second build fixed real problems, but three specific things from that prompt didn't happen

The first build read as a single spiky rock cluster with an unreliable strike. A second build
(`Opus5_Voltaic_Cascade_Rework.md`) fixed several of the real problems:

- **Keep this — the assembly now works.** Separate cloud pieces visibly fly in from different positions and
  converge into one mass. This motion is good, don't change it.
- **Keep this — the strike is reliable now.** Both reviewed takes fired a strike every time, no more "sometimes
  nothing happens."
- **Keep this — the bolts have a proper bold black outline**, consistent with the game's comic house style.
- **Keep this — the mini-arc crackles during the charged hold are present and read well.**
- **Keep this — the dissolve condenses/shrinks down instead of shattering into falling pebbles.** This is much
  closer to the sink/shrink fade the engine wants.
- **Keep the general chunk-based construction** — building the cloud from many overlapping faceted hexagonal
  lobes instead of one giant boulder mass was the right call and is a real improvement over the first build.

Three specific things from that prompt were not built, and are the reason it still doesn't look finished:

1. **The bolt count is 2 in every take, not the 4–5 that was asked for.** This is the single biggest miss — two
   bolts reads as a trickle, not a hero-scale Ultimate payoff.
2. **There is no color banding.** The entire cloud is one flat Dark `#4A1A8C` from top to bottom. The Light
   `#FFF573` / Base `#F5C70F` lit upper lobes were never built, so there's no "charged glow" read and no visual
   separation between a calm top and a threatening underside.
3. **There is no Ben-Day halftone texture anywhere.** The underside is flat solid color with nothing on it.

On top of those three, there's a fourth problem that showed up on review and needs fixing in this pass too:

4. **The cloud reads as sparse and small, not big and dense.** The individual hex lobes have visible gaps
   between them rather than overlapping into one cohesive mass, and the overall silhouette doesn't clearly read
   as meaningfully larger than a character the way a hero-scale Ultimate should. Compare directly against
   `cascade_cloud_reference.png`, which is a dense, thick, gapless mass — that's the density bar to hit, not the
   current scattered/gappy look.

## Fix list for this pass

**A. Density and scale.** Increase lobe count and overlap until there are no visible gaps in the silhouette —
the cloud should read as one dense, thick mass built from many overlapping chunks, not a loose scatter of
separate hexagons with sky visible between them. Increase the overall scale of the assembled cloud too — it
needs to unmistakably read as bigger than a character at actual gameplay camera distance, the same hero-scale
bar every other kit's Ultimate hits. Propose a specific scale multiple relative to a character's height and
report it.

**B. Color banding — top lit, underside dark.** Split the assembled cloud into two color zones baked as vertex
tone bands (not material tint, per the engine constraints below):
   - **Top lobes:** Voltaic Light `#FFF573` and Base `#F5C70F`. This is what should read as "charged with
     energy" — it was entirely missing from the second build.
   - **Underside lobes:** Dark `#4A1A8C`.
   The dividing line between the two zones doesn't need to be perfectly even — a slightly uneven, organic
   boundary following the lobe geometry will read better than a hard horizontal cut.

**C. Ben-Day halftone on the underside.** Add a real dot-pattern halftone patch across the Dark underside zone,
the same halftone treatment already used elsewhere in the game's VFX (Terra and the status-effect art both use
this device) — small flat dots, not a gradient, not a texture map that fakes shading.

**D. Bolt count — 4 to 5, staggered.** Each bolt originates from a different point along the underside and lands
at a different ground point in a fast stagger, not simultaneously and not from the center only. If 5 doesn't fit
the ~0.3s strike window cleanly, use 4, but report which count was used and why — don't ship 2 again.

## Reference

`cascade_cloud_reference.png` (already saved in the project's SPELLSHOT folder) is still the target for overall
density, proportion, and composition — go back to it directly for how thick and gapless the mass should look,
since that's the property the second build undershot most. Same translation note as before applies: build it
flat-shaded and opaque, no literal gradient or glow — the reference's soft lit-edge glow becomes the flat Light
`#FFF573` top band described in fix B above, not an actual light or bloom effect.

## Engine constraints — unchanged from every other kit in this game

Opaque meshes only, no transparency (the dissolve already uses sinking/shrinking correctly — keep that).
`MeshPart.Color` stays white, `Material` stays `SmoothPlastic`, `DoubleSided = false`. Color comes from baked
3-step vertex-color tone bands, not material tint — this is how both the top/bottom split in fix B and the
halftone in fix C need to actually be achieved. The ink outline is a real inverted-hull mesh.

## Checkpoint before final

Because density/scale (fix A) is a silhouette-level change, re-check the silhouette at actual on-screen render
scale before finalizing color — confirm the mass reads as dense and appropriately large with gaps closed up,
independent of the color banding and halftone work, then layer B and C on top of that confirmed silhouette.

## Scope reminder

Cascade's cloud density/scale, its top/bottom color banding, its underside halftone, and its strike bolt count.
**Not in scope:** the assembly motion, the mini-arc crackle, the dissolve technique, and the bolt outline style —
all four of those already work and should not be touched. Also not in scope: the other five Voltaic pieces, any
mechanic or number changes beyond the bolt count and scale multiple this prompt asks for, and any new status
effect.

Flag anything ambiguous rather than deciding it silently, and add nothing that wasn't asked for here.

---

Say one sentence before your first tool call. Give a brief update at the silhouette checkpoint (fix A) before
moving on to color. When done, lead your report with the cloud rendered at actual on-screen scale next to
`cascade_cloud_reference.png` for a direct density/scale comparison, then confirm the bolt count used, and show
the top/bottom color banding and halftone clearly in a still frame.
