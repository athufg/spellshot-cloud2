# SPELLSHOT — Build Prompt: Voltaic Ultimate — Cascade Corrective Pass #3

**Standalone, self-contained prompt.** Third pass on Cascade. Read "Current state" carefully — it names exactly
what to keep from pass #2 and exactly what's still wrong. Don't redo what already works.

## Current state

Pass #2 (`Opus5_Voltaic_Cascade_Corrective_v2.md`) fixed the cloud's density and scale — it's now a solid,
gapless mass and reads as appropriately large. **Keep that.** Also keep the assembly motion (separate pieces
flying in and converging), the dissolve (shrink/condense, no pebble debris), and the general chunk-based
construction.

Two things are still wrong after three total passes:

1. **Color.** Pass #2 asked for a top-lit-yellow / dark-underside color split. What got built instead is a ring
   of small yellow triangle shapes scattered evenly around the whole rim, top and bottom alike — not a banded
   split, and it reads busy and messy rather than like a charged storm cloud. This is a real miss, not a partial
   success — **do not repeat the triangle-teeth treatment in this pass.**
2. **The strike feels flat.** The bolts bunch up in one tight cluster instead of spreading across the target
   zone, and nothing about the sequence escalates — no camera punch, no rising energy before the release. The
   whole thing plays at one flat level instead of building to something.

## Two references — use both, they do different jobs

- **`cascade_cloud_reference.png`** (saved in the project folder) — use this for the four-beat structure,
  timing, and overall wide/flat proportion. Still accurate, nothing here changes it.
- **`cascade_cloud_reference_mood.png`** (also saved in the project folder, just added) — use this for color,
  mood, and depth. It's a dark, dense, layered storm — near-black cloud mass with a purple glow visible in the
  gaps between lobes, and thin branching lightning threading through it. This is the actual target look; it's
  the reason pass #2's color approach needs to change, not just be adjusted.

**Translation note, same as before but read it again — this reference is even more atmospheric than the last
one.** It's painted with heavy gradient, glow/bloom, and soft blended shading throughout. None of that is
buildable: every mesh here is opaque `SmoothPlastic` with flat baked 3-tone vertex-color bands, no glow shader,
no transparency. Pull the *mood and composition* from it, not the literal rendering technique — see the color
section below for exactly how that translates to flat shapes.

## Color — the actual fix, stated precisely this time

**Design call, flagging it rather than deciding silently:** the mood reference has almost no yellow in it at
all — the lightning in it is purple-white. Going fully purple would put Cascade out of step with the rest of
Voltaic's kit, since Chain Bolt, Railspike, Overcharge, and Ground Surge are all already built and approved in
Voltaic's actual yellow (`#F5C70F` / `#FFF573`). The call here is: **take the reference's darkness and depth for
the cloud body, but keep the lightning itself in Voltaic's real yellow**, so Cascade still reads as the same
character as the rest of the kit instead of introducing a second, unrelated palette. If this is wrong, say so —
otherwise build to this:

- **Cloud body:** dominant Dark `#4A1A8C`, going toward a near-black shade in the deepest, most recessed lobes
  for real depth — propose a specific darker tone for this (a shadow variant of `#4A1A8C`, not a new hue) and
  report it. This replaces the "yellow top / dark bottom" banding entirely — there is no yellow anywhere on the
  cloud's surface itself.
- **Inter-lobe glow:** where the reference shows purple light glowing through the gaps between cloud lobes, build
  that as a flat lighter-purple accent shape inset into the seams between lobes (a genuinely new lighter-purple
  tone for this purpose specifically, proposed and flagged, not one of the three shipped Voltaic colors) — this
  is what stands in for the glow, and it's the only new color being introduced. No yellow triangles, no yellow
  anywhere on the cloud body.
- **Halftone:** still add the Ben-Day dot texture patch in the darkest recessed areas, as asked in both prior
  passes and not yet built — use it here to add texture to the near-black deep lobes.
- **Lightning stays yellow:** Base `#F5C70F` core, `#FFF573` hot edge, exactly as already built and approved for
  the rest of the kit. This is the one part of the reference's palette that is NOT being adopted, and that's
  intentional — see the design call above.

## Depth and lobe shape

The mood reference reads as deep and three-dimensional because it's built from many overlapping cumulus banks at
different depths, not one flat crowd of same-size chunks. Build the cloud in at least two or three depth layers
— a back layer, a mid layer, and a front layer of lobes, each slightly overlapping the one behind it — so the
silhouette has real front-to-back structure instead of reading as flat. Push toward larger, smoother-faceted
lobes rather than the small uniform hex nubs used so far; keep them hard-edged and flat-shaded (no gradient),
just larger and less uniform in size so the mass reads as billowing rather than studded.

## Strike sequence — spread it out and give it weight

Keep the established thick, bold Voltaic zigzag bolt shape — consistent with Chain Bolt and Railspike, do not
thin it down to match the reference's wispy branching lines directly. Instead, get the reference's "branching"
read by adding one or two thin secondary forks peeling off each main bolt near its lower third, rather than
changing the main bolt's weight.

- **Spread, don't bunch.** The 4–5 bolts need to land at visibly different points across the actual target zone,
  not clustered in one spot. Space their landing points out.
- **Stagger for real.** Each bolt fires roughly 0.05–0.1s after the previous one — close enough to read as one
  continuous event, far enough apart that it doesn't look like one simultaneous clump.
- **Add weight.** A brief camera shake on the assembly's connect-impact and on each individual strike (through
  whatever camera-shake hook the rest of the kit already uses — respect the Camera Shake setting). This is what
  a hero-scale Ultimate needs and what's making the current version feel flat.
- **Build the tension before the release.** The charge-hold's mini-arcs should visibly increase in frequency and
  brightness as the hold approaches the strike, instead of sitting at one constant flicker rate the whole time —
  give the last beat before the strike a rising, more energetic crackle so the release actually lands as a
  release.

## Engine constraints — unchanged

Opaque meshes only, no transparency. `MeshPart.Color` stays white, `Material` stays `SmoothPlastic`,
`DoubleSided = false`. Color comes from baked 3-step vertex-color tone bands, not material tint — this is how
the near-black shadow tone and the inter-lobe glow accent both need to actually be built. Real inverted-hull
outline mesh, no outline shader.

## Checkpoint before final

Before finalizing, check the color pass specifically against `cascade_cloud_reference_mood.png` side by side —
confirm the inter-lobe glow reads as glow-in-the-gaps and not as another version of the triangle-teeth rim
treatment from pass #2. That specific failure mode has happened twice now; catch it here before it ships a
third time.

## Scope reminder

Cloud color (near-black body + inter-lobe glow accent + halftone), depth/layering, strike spread and stagger,
camera shake, and the rising charge-intensity crackle. **Not in scope:** the density/scale fix from pass #2
(already correct, don't touch it), the assembly motion, the dissolve technique, and the bolt outline style — all
already work. Also not in scope: the other five Voltaic pieces, any mechanic changes, and any new status effect.

Flag anything ambiguous rather than deciding it silently, and add nothing that wasn't asked for here.

---

Say one sentence before your first tool call. Give an update at the color/depth checkpoint specifically. When
done, lead your report with the cloud rendered next to `cascade_cloud_reference_mood.png` for a direct
comparison, confirm the strike spread/stagger and camera shake are in, and report the exact shadow and glow-accent
color values used.
