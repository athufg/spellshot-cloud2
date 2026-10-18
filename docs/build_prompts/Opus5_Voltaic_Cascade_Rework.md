# SPELLSHOT — Build Prompt: Voltaic Ultimate — Cascade Storm Cloud Rework

**Standalone, self-contained prompt.** This replaces only the Cascade (Ultimate) section of the earlier
`Opus5_Voltaic_KitVFX_Blender.md` kit prompt. The other five Voltaic pieces from that prompt (Chain Bolt,
Overcharge, Chain Reaction, Railspike, Ground Surge) are **not** in scope here — Chain Bolt and Railspike came
out well and should be left alone; Overcharge needs its own separate redo (no dash motion at all); Ground Surge
needs a smaller telegraph fix. This prompt is Cascade only.

**No mechanic changes.** Cascade's behavior is unchanged from the locked kit: mark a ground point, storm clouds
gather above it as the telegraph, then a rapid sequence of individual forked lightning strikes lands on anyone
still standing near that point, over roughly a second.

## Current state — what's built and why it's being redone

A first pass of Cascade exists (built from the earlier kit prompt) and was reviewed frame-by-frame across two
video takes. It does not work, for three specific, confirmed reasons:

1. **It reads as a cluster of rocks/boulders, not a storm cloud.** The earlier prompt told the builder to
   construct it "same family as Terra's Bedrock plates or Earthen Tomb's structure" — meaning real toon
   geometry, not a soft particle puff, which is still correct. But Terra's actual shape grammar is chunky,
   uniformly-faceted polygons with no top/bottom distinction, and the builder reproduced that shape family
   directly: a single dark-violet mass with the same small jagged faceting all over, top and bottom alike, and
   no proportion or color cue that says "cloud" instead of "rock." This also creates an unwanted identity
   collision with Terra, who already owns that exact shape language.
2. **The strike sequence isn't reliable or plural.** One take shows a single bolt straight down the center; the
   other take shows no bolt at all before the cloud disperses. The spec calls for a rapid *sequence* of
   individual strikes — that needs to happen the same way every time.
3. **The dissolve undercuts the whole effect.** The cloud currently crumbles apart into small falling dot/pebble
   shapes, which reads as debris from a broken rock, reinforcing problem #1 at the exact moment the effect
   should feel like a dispersing storm.

Treat this document as the authority for Cascade, overriding the Cascade section of the earlier kit prompt.

## Reference before styling

A real reference now exists: `cascade_cloud_reference.png`, saved alongside `spellshot manual.pdf` in the
project's root folder. It's a full concept sheet — composition, the four-beat breakdown, closeups of the cloud
from the side and underneath, a color palette, and five silhouette variants — and it should drive the shape and
composition of this build directly.

**Read this translation note before treating the reference as final art, though.** The reference is painted with
soft gradients, rounded volumetric shading, and glow/bloom around the lit edges. None of that is buildable as-is
— every mesh in this game is opaque `SmoothPlastic` with flat baked 3-tone vertex-color bands and a hard
inverted-hull outline (see Engine constraints below); there is no glow shader, no transparency, no soft blend.
The result will necessarily look more graphic and flat than the reference, the same way Cryo's built ice looks
flatter than a painted ice concept would. What to actually pull from the reference, translated:

- **Silhouette and proportion:** take the reference's wide, flat, mushroom/anvil shape directly — it's
  considerably wider relative to its height than a typical cloud sketch, sitting like a discus over the target.
  The five silhouette variants at the bottom of the sheet are all close to this proportion; build to that family,
  not to a taller or rounder mass.
- **Lobe structure:** several overlapping rounded lobes forming the top, built with enough facets that they read
  soft rather than crystal-sharp (contrast this with Cryo's angular ice, which should stay the sharpest shape in
  the game) — but still hard-edged flat geometry, no gradient.
- **Bottom edge:** jagged, dripping, sharp tendrils hanging down, denser and more elaborate than a simple
  zigzag — the reference's underside closeup panel is the target here. Halftone dots stay on this underside only.
- **The glow has no literal equivalent — fake it as a flat shape.** The reference's rim light along the top edges
  of the lobes should become its own separate bright shape: a `#FFF573` highlight band hugging the upper contour
  of each lobe, drawn as flat color, not an actual light or bloom. This is what stands in for "charged glow" in
  this engine.
- **Bolt count:** the reference's strike panel shows roughly 4–5 simultaneous/staggered bolts hitting different
  points — use that as the target count instead of the smaller number below if it reads better; report which
  count was used and why.

If any part of the reference is unclear at the resolution provided, say so and describe the specific ambiguity
rather than guessing.

## Design direction — four beats, each with its own visual event

The core problem with the current build isn't just the shape, it's that nothing moves or escalates: it appears,
sits still, and ends. The rework needs four distinct beats, each doing visible work:

**1. Assembly (0.0–0.4s):** instead of growing in place, 4–5 separate cloud lobes fly in from different
directions and slam together overhead — a hard little shake and a flash of energy across the seams when they
connect. That single change turns "a shape appeared" into "a storm just got summoned," which is most of what
"attractive" means here.

**2. Charged hold (0.4–0.8s):** the assembled cloud is wide and flat, not ball-shaped — broad, calm facets on
top lit in Voltaic's Light/Base yellow like it's glowing with stored charge, dropping to the Dark violet with
real Ben-Day halftone dots (not the grid-weave texture it has now) on a ragged, jagged underside. While it holds,
small forked mini-arcs skitter across the surface and between the lobes — visible charging, not a dead pause, so
the second before the strike is doing work instead of just being a delay.

**3. The strike (0.8–1.1s):** four individual forked bolts, each from a different point along the underside,
hit in a fast stagger — not one bolt down the middle, not nothing. Each one gets its own impact burst. This is
the payoff frame, the one someone screenshots.

**4. Dissolve:** the cloud thins from the underside up — the dark jagged part goes first, the glowing top lobes
hang a beat longer like they're still catching the afterglow — fading by sinking/shrinking like everything else
in this engine. Not crumbling into pebbles, which is what made it read as a rock breaking apart in the first
place.

Note on the strike count: `cascade_cloud_reference.png`'s strike panel shows roughly 4–5 bolts, so 4 is a solid
floor — go to 5 if it reads better, and report which count was used and why.

Report every timing number you propose for these four beats, sanity-checked against Voltaic's own fixed kit and
Cryo's built abilities as the closest reference points. Note: the timings above (0–0.4s / 0.4–0.8s / 0.8–1.1s /
1.1s+) already match the beat labels on `cascade_cloud_reference.png` — treat them as a strong starting point,
not a hard lock; adjust if the actual geometry/animation needs it and report the change.

## Scale

This is Voltaic's one hero-scale moment. Size the assembled cloud meaningfully larger than a character, matching
how every other kit renders its signature Ultimate beat — confirm the assembled silhouette still reads clearly
at actual gameplay camera distance, not just up close.

## Integration — hook these existing systems, rebuild none of them

- Every emitter (the mini-arcs during the charged hold, the strike impact bursts) goes through `VFXLibrary`'s
  `emitter()` helper for Graphics Quality density and Reduce Enemy VFX scaling.
- The strike flashes and the assembly's impact shake must respect Reduce Flashing and Camera Shake settings.
- Damage numbers and any KO! callout on a strike's victim go through the existing `Callouts` system — no new
  lettering.
- This is a broadcast worldspace effect visible to everyone, not a first-person Viewmodel effect — but if the
  cast itself (aiming and committing the ground-target point) has a first-person tell, name the shared
  `Trigger`/`LeadIn` beat it syncs to, the same way every other ability in this game does. If the ground-target
  cast already has its own aim/confirm animation from elsewhere in the kit, this prompt doesn't need to touch it
  — just confirm the cloud's assembly beat (step 1 above) starts on that existing cast-confirm moment.

## Engine constraints — same rules as every other kit in this game

Opaque meshes only, no transparency (fades happen via sinking/shrinking as described above). `MeshPart.Color`
stays white, `Material` stays `SmoothPlastic`, `DoubleSided = false`. Color comes from baked 3-step vertex-color
tone bands, not material tint — this is also how the top/bottom color split in the design direction above should
actually be achieved. The ink outline is a real inverted-hull mesh — there is no outline shader. This cloud must
be built as real toon geometry, not attempted as a soft particle cloud, same as the original kit prompt required.

## Checkpoint before final

Silhouette pass of the fully assembled cloud (all lobes together, no color/tone bands yet) reviewed at actual
on-screen render scale before any tone band, outline detail, or color goes on. This is the single most important
checkpoint in this prompt — the rock-vs-cloud read has to be settled at the silhouette stage, because color was
not what caused the current problem and color alone will not fix it either. If the silhouette still reads as a
rock cluster, stop and revise proportions (wider, flatter, top/bottom facet-size difference) before proceeding
to color.

## Scope reminder

Cascade's cloud geometry, its four-beat animation (assembly, charged hold, strike sequence, dissolve), its
color banding, and the strike impact bursts. **Not in scope:** the other five Voltaic pieces from the original
kit prompt, any mechanic or number changes beyond the timing placeholders this prompt explicitly asks for, the
ground-target aim/cast animation if one already exists elsewhere, and any new status effect (Cascade remains
pure burst damage, no persistent status, consistent with the rest of Voltaic's kit).

Flag anything ambiguous — including every proposed number — rather than deciding it silently, and add nothing
that wasn't asked for here.

---

Say one sentence before your first tool call. Give a brief update at the silhouette checkpoint specifically —
that's the one that matters most. When done, lead your report with the assembled cloud rendered at actual
on-screen scale (silhouette and final colored version side by side if possible), then list every timing number
you proposed and why, and confirm the strike sequence fires consistently rather than sometimes.
