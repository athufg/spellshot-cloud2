# SPELLSHOT — Build Prompt: Voltaic Ultimate — Cascade (Final Consolidated Pass)

**Standalone, self-contained prompt. This replaces every previous Cascade prompt** (the original kit prompt's
Cascade section, and corrective passes #2, #3, and #4). Don't read those — everything needed is here, built
around one clear, fully worked-out reference. This is the last word on Cascade's design direction; execute to it.

**No mechanic changes.** Cascade's behavior is unchanged from the locked kit: mark a ground point, a storm cloud
gathers above it as the telegraph, then a rapid sequence of individual forked lightning strikes lands on anyone
still standing near that point.

## The reference — one source of truth

`cascade_final_vision_sheet_v2.png`, saved in the project's SPELLSHOT folder, is the authoritative design
reference for this build. It's a five-panel sequence sheet with closeups, a top-down shape reference, and a mood
note list — read it in full before starting. It went through several rounds of revision in design discussion and
this is the settled version; don't deviate from its shape language, timing, or mood without a real reason,
and report anything you do change.

**Translation note — read this before touching Blender.** The reference is painted with heavy gradient, glow,
and soft blended lighting throughout, the way concept art usually is. None of that is buildable directly: every
mesh in this game is opaque `SmoothPlastic` with flat baked 3-tone vertex-color bands, `DoubleSided = false`, and
a real inverted-hull outline mesh for the ink line — there is no glow shader, no transparency, no soft blend, no
material tint. The result will read more graphic and flat than the painted reference, the same gap that exists
between any painted concept and Cryo's actual built ice. What follows is how each element of the reference
translates into flat shapes.

## The five beats

**1. Gathering (0.0–0.4s).** Dark cloud material swirls in from the surrounding sky toward the target point in
turbulent, curling motion — not straight lines converging, an actual vortex/spiral pull. Build this from several
cloud-stuff pieces with curved travel paths rather than pieces flying straight in and colliding.

**2. Compression (0.4–0.8s).** The swirling mass collides and compresses into one dense thunderhead — a visible
punch-inward moment, not a gentle settle. A small impact shake here (through whatever camera-shake hook the rest
of the kit uses, respecting the Camera Shake setting) sells the weight of it. Yellow sparks begin orbiting the
mass and a deep violet glow starts building inside it.

**3. Charged hold (0.8–1.2s).** The full thunderhead hangs overhead, dense and alive. This is where color and
texture matter most:
   - **Cloud body:** dominant Dark `#4A1A8C`, going toward a near-black shadow tone in the deepest, most recessed
     lobes — propose the exact shadow tone (a darker variant of `#4A1A8C`, not a new hue) and report it.
   - **Internal glow:** a lighter violet glow visible in the gaps and folds between lobes, brightest at the
     center — build this as a flat inset highlight shape in the seams between lobes (a new lighter-purple tone,
     proposed and flagged, used only for this glow — it is the one new color introduced beyond Voltaic's three
     shipped tones). This is the flat translation of the reference's internal lighting.
   - **Underside:** jagged, dripping edge — per the reference's underside closeup, the jagged shape and the
     Ben-Day halftone texture are combined in the same area, not separate treatments. Halftone dots go directly
     into the jagged underside geometry's dark facets.
   - **Orbiting sparks:** small hard-edged yellow particles (Base `#F5C70F` / Light `#FFF573`) circling the cloud,
     built through the existing `emitter()` helper. Through this beat they should visibly speed up and brighten
     as the hold approaches the strike — a rising intensity, not a flat constant loop.
   - **Silhouette:** per the reference's top-down panel, the overall shape reads as a natural, asymmetric spiral
     — not a neat symmetrical dome. Build the lobe placement with genuine irregularity; a too-even silhouette
     will undercut the "real weather, not a VFX prop" read the whole sheet is going for.

**4. Release (1.2–1.6s).** The storm tears open. Two things happen together, not sequentially:
   - A burst of yellow light (Base/Light) radiates outward from the cloud's underside in multiple directions —
     built as short flat angular burst shapes, present for only a few frames, distinct from the strikes below.
   - 4–5 thick, forked lightning bolts (Base `#F5C70F` core, `#FFF573` hot edge — matching the weight and shape
     already established by Chain Bolt and Railspike, not thinned down to match the reference's painted lines)
     crash down from the underside to different points across the target zone in a fast stagger, roughly
     0.05–0.1s apart, not simultaneous and not bunched into one spot. Each impact gets its own burst plus a beat
     of lingering debris/afterglow at the landing point per the reference's impact closeup — the strike shouldn't
     vanish the instant it lands. A slightly stronger camera punch on the first bolt specifically, since that's
     the frame that should feel like it hit the player's own screen.

**5. Fade / exhale (1.6s onward).** The violet internal glow fades first. The cloud thins and drifts upward and
apart — like a real storm system moving off, not an object shrinking to a point or crumbling into debris. Ground
afterglow at the strike points lingers for a beat after the cloud itself has mostly dispersed before fading out.

Report every timing number you land on for these five beats — the ranges above are a strong starting point from
the reference, not a hard lock.

## Color — summary

- **Cloud body:** Dark `#4A1A8C` → a proposed near-black shadow variant in the deepest lobes.
- **Internal/seam glow:** one new lighter-purple accent tone, proposed and flagged, used only in the gaps between
  lobes.
- **All lightning, all sparks, all bursts:** Voltaic's actual yellow, Base `#F5C70F` / Light `#FFF573`. This is a
  confirmed decision, not a proposal — the reference's own lightning is purple-white, but Cascade's stays yellow
  to remain consistent with Chain Bolt, Railspike, Overcharge, and Ground Surge, all already built and approved
  in yellow. Do not build purple-white lightning.
- **Halftone:** Ben-Day dots in the jagged underside's dark facets, as described above.

## Scale

Hero-scale moment — size the assembled cloud meaningfully larger than a character, matching how every other
kit's Ultimate renders its signature beat. Confirm the silhouette still reads clearly, dense, and appropriately
large at actual gameplay camera distance, not just up close.

## Build approach — one continuous effect, do this yourself

This is one continuous five-beat motion, not six independent assets the way the original Voltaic kit prompt was
— a subagent split would fragment something that specifically needs to read as one unbroken piece of weather
from gathering through fade. Build it yourself in one pass rather than delegating pieces to subagents.

## Showcase the result — render the full sequence

Once built, render a short clip covering all five beats in order (gathering through fade) at actual gameplay
camera distance and scale, the same way prior Cascade builds have been reviewed in this project. This is the
primary deliverable to hand back — a still frame of one beat isn't enough to judge whether the motion and
escalation actually read.

## Integration — hook these existing systems, rebuild none of them

- Every particle (orbiting sparks, burst shapes) goes through `VFXLibrary`'s `emitter()` helper for Graphics
  Quality density and Reduce Enemy VFX scaling.
- Camera shake (compression impact, strike punches) respects the Camera Shake setting. Flashes respect Reduce
  Flashing.
- Damage numbers and any KO! callout go through the existing `Callouts` system.
- This is a broadcast worldspace effect, not a first-person Viewmodel effect — if the ground-target cast itself
  has a first-person tell elsewhere in the kit, sync the Gathering beat's start to that existing cast-confirm
  moment rather than building a new one.

## Engine constraints

Opaque meshes only, no transparency — the fade uses sinking/shrinking/drifting, not transparency fade.
`MeshPart.Color` stays white, `Material` stays `SmoothPlastic`, `DoubleSided = false`. All color comes from baked
3-step vertex-color tone bands, not material tint — this is how the shadow tone, the internal glow accent, and
the halftone all need to actually be built. The ink outline is a real inverted-hull mesh; there is no outline
shader.

## Checkpoint before final

Check the silhouette (asymmetric spiral shape, density, scale) before any color goes on — settle the shape first,
independent of the color/glow work. Then, once color is applied, compare directly against
`cascade_final_vision_sheet_v2.png`'s charged-hold and release panels side by side to confirm the internal glow
reads as glow-in-the-gaps (not a repeat of an earlier failed attempt that used scattered yellow triangle shapes
around the rim — don't build that) and that the release genuinely reads as a radiating burst plus multiple
staggered strikes, not a single bolt or a tight simultaneous cluster.

## Scope reminder

Cascade's full five-beat sequence: gathering, compression, charged hold (color, glow, halftone, orbiting sparks,
asymmetric silhouette), release (radiating burst + staggered strikes + camera punch), and fade. **Not in scope:**
the other five Voltaic pieces (Chain Bolt and Railspike already work and shouldn't be touched; Overcharge and
Ground Surge have their own separate fixes pending elsewhere), any mechanic or number change beyond the timing
and color values this prompt asks for, and any new status effect — Cascade stays pure burst damage.

Flag anything ambiguous rather than deciding it silently, and add nothing that wasn't asked for here.

---

Say one sentence before your first tool call. Give a brief update at the silhouette checkpoint before moving to
color. When done, lead your report with the rendered full-sequence clip (or, if video export isn't practical,
still frames from each of the five beats in order) at actual on-screen scale, then list: the shadow and
glow-accent color values used, the final bolt count and stagger timing, and confirm the lightning is yellow
throughout. Keep the written report itself proportional to what's needed to convey this — the render is the
deliverable, not a long write-up.
