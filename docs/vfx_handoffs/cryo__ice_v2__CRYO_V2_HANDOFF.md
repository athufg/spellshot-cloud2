# Cryo v2 handoff: real ice for the Roblox Studio build

**The clips:** `<n>_<piece>/cryo2_<piece>.mp4`. Each is a third-person take with its signature beat in slow motion, followed by a first-person take. Caption-bar beat names and times (in seconds) are the shared trigger beats. Gameplay numbers are unchanged; behaviour here only guides the visuals.

## Shared building blocks

**Effects:** every emitter goes through the shared emitter helper.
- Graphics Quality scales counts and rates: Low ×0.4, Medium ×0.7, High ×1.
- Reduce Enemy VFX halves enemy particles, drops screen effects and keeps only the Frost Line and the zone edges.

**The ice crystal:** milky, translucent ice, about 65–80 % opaque. This is what Roblox gets in place of transmission and volume absorption.
1. **Main MeshPart:** Material **Ice** (never Glass for the body), Transparency 0.3–0.5.
   - Colour runs from `#5BB8E8` at the tips to `#1D6FB8` at the thick base, through a vertex-colour or texture gradient. Thick parts read as nearly solid blue.
   - Shape: a tall, thin, pointed 4–6 sided prism, about 30–40 tris, rising off a **chunky six-sided base prism** 2–3× wider (about 40 tris).
2. **Frost overlay:** a white, rough, matte frost texture (SurfaceAppearance or decal) over the lower half, heaviest at the bottom and fading upward.
3. **Inside:** soft, low-contrast lighter streaks and bubbles in the colour texture, varied per crystal (3–4 texture variants, random rotation and scale). There are no painted surface veins.
4. **Edges:** only the tips and edges read glassy, with a lighter tip gradient, Reflectance 0.15 and the rim lights. A thin neon edge accent appears only during a Frost Line pulse.

There is no inner glow mesh: at most two things glow in a frame, and the Frost Line is always one of them.

**Clusters:** 1–3 chunky base prisms carry the spikes. There are a few tall spires, many small spikes and chips, and a low frost-on-ice mound (the same Ice material plus the frost overlay).

**Encasing mass** (Deep Freeze, Flash Freeze):
- 16–18 thick hex prisms plus 4 chunky foot prisms around the target, with 2–3 spires.
- Ice material at Transparency 0.1 at the base, rising to 0.5 at the top.
- The frozen character's parts are tweened to `#1F3F6B`, so the body reads as a darker blue silhouette with frost across it.

**Growth:** tween each crystal's Size along its length (0 → 1, ease-out, 0.15–0.3 s, staggered 0.02–0.05 s). While a crystal grows, a small white Neon base sliver fades out.

**The Frost Line** is the only saturated accent (`#3FE0FF` → `#8DF3FF`).
- It is a **Beam** with LightEmission 1, Width 0.05–0.2, on the leading edge of any spreading frost.
- On bodies it is a thin Neon ring part riding the frost's top edge.
- Once the spread finishes it dims to Transparency 0.85 (calm darker-blue rim `#245F9A`).

**Glow budget:** at most two glowing things per frame, and the Frost Line is always one of them. Everything else gets its brightness from lighting.

**Frost disc:** a flat decal MeshPart with these layers:
- a 6-fold fractal frost texture;
- a ragged alpha edge with frost fingers;
- a calm blue rim plus the Frost Line Beam ring while it grows.

To melt it, swap through a 3-step alpha flipbook of breaking cells, then fade.

**Caustics:** a scrolling cyan caustic decal (`#6FE3FF`, Transparency 0.6, 4-frame flipbook) on the floor on the far side of big ice, plus a SurfaceLight.

**Mist:** a low flat fog decal (scrolling noise, Transparency 0.75), or 1 ParticleEmitter (rate 6, lifetime 3 s, size 6–10, speed 0.5, Acceleration −0.3 down).

**Hit feel:**
- 1–2 frames of hit-stop on every impact;
- a PointLight flash (`#73D6FF`, Brightness 3 → 0 in 0.2 s);
- a ripple ring (a thin Beam ring that expands, `#D6F4FF`);
- shards (`PF_Shard` MeshParts with physics, or a shard-flipbook emitter, gravity −40);
- powder (a soft sprite, lifetime 1–1.5 s);
- snowflake sprites (an 8-frame flipbook);
- a dummy knock-back.

Nothing pops off: everything dissolves or melts.

**FROZEN!:** the existing pop-art UI callout (the spec is in `RECIPE.md`). It is not ice.

## 1. Flash Freeze (Primary)

**Animation** (trigger = the press at **0.45**):
- **Third person:** raise the palm, then crouch and press with a weight shift; hold until 1.25, recover by 1.85.
- **First person:** the palm presses down, the camera dips, the hand spreads.

**The rim:**
- **Frost Line Beam ring:** races from the aim point to R = 6 in 0.5 s, then dims.
- **Zone disc decal:** 12 studs across.
- **Rim crystals:** 30 small clusters (2–4 crystals, 1–2 studs, about 250 tris each) grow in a travelling wave round the rim over 0.35 s.

**Inside:**

| Element | Spec |
|---|---|
| Sprout clusters | 18 (about 400 tris each; the inner band reaches 3–5 studs) at 0.95–2.4 s |
| Ripple Beams | every 0.75 s |
| Sparkles | sparkle emitter at rate 7 |
| Mist decal | over the zone |

**A lingering target:**
- 1.0–2.0: frost climbs the legs (staged frost shells plus the Frost Line ring part).
- 2.0–2.4: about 50 body crystals and a 10-crystal base ring grow.
- **The block:** a faceted convex chunk of about 150 tris. It is built as the encasing mass above (Ice material), and the figure reads as a dark blue silhouette inside it.
- FROZEN! pops.

**The end** (shatter at 4.85):
- Cracks race through the disc (a crack decal swap) at 4.4–4.85.
- Hit-stop 2 frames.
- The crystals shatter as a wave from the centre (4.85) to the rim (5.25): about 120 shard parts at High (Low 50), a powder ring, and 9 dark floor-slab parts with physics.
- The disc melts with the cell flipbook by 7.0.

**Lights:** a PointLight at the zone (Brightness 1.5) and flashes at 0.45, 4.85 and 5.25.

## 2. Deep Freeze (Technique)

**Animation** (trigger = the tap at **0.32**):
- **Third person:** crouch, palm-down press.
- **First person:** the tap, a shiver of breath at the hand.

**The tap:** a 1.5-stud frost disc with its Frost Line, plus a 7-crystal bloom that melts by 1.2 s. Then nothing is visible while armed.

**Trigger** (when stepped on):
- a ripple Beam plus a powder pop (12);
- the frost skin climbs 0 → 5.4 studs in 0.5 s with the Frost Line ring part;
- about 54 body crystals sprout as the line passes, and a 12-crystal base ring at 4.4 studs plus 20 chips (about 1.4k tris);
- the clear block (same as above) rises from the floor;
- the floor disc spreads to 3.8 studs;
- a caustic decal and the mist decal appear.

FROZEN! pops at lock **(+0.5 s)**. White crack decals race at +1.9 s. Shatter at +2.6 s with 2 frames of hit-stop: 40 shards, 40 chips, 22 powder, 26 sparkles, 26 mist puffs. The dummy is thrown back.

## 3. Icicle Shard (M1): the leanest effect

**Animation** (trigger = the release at **0.30**; the hands alternate):
- **First person:** a frost decal crawls over the fingertips, and an icicle (1.1 studs) scales in between them over 0.16 s before the flick.
- **Third person:** a wrist flick, a hip shift, a breath puff.

**In flight:**
- one prism of 3.3–3.9 × 0.17 studs, about 36 tris, Ice material at Transparency 0.4 with a lighter tip;
- a white tip glint (a sparkle attachment);
- a Frost Line Trail (width 0.035 → 0, lifetime 0.1 s);
- 3 snowflake flecks;
- a vapor wake (rate 80, lifetime 0.35 s).

**Muzzle:** 4 chips and 4 vapor puffs.

**Impact:** 6 shard fragments, 4 chips, 2 powder, 4 flakes, a ripple Beam ring on the surface, and a light flash. Hit-stop is 1 frame, or 2 on the root.

**Chill patch on the target:** radii 0.32 / 0.48 / 0.62 for stacks 1 / 2 / 3, with the Frost Line only while it grows. **Stack 3** (root): the frost climbs to the knees in 0.38 s, two ankle-cuff clusters grow (6 crystals plus a mound, about 300 tris), and FROZEN! pops.

**Budget per shot:** about 3 parts plus 4 emitters.

## 4. Mirror Cage (Ultimate)

**Animation** (trigger = the press at **0**):
- **Third person:** the arms rise over 0–0.5. The fists close progressively from 2.4 to 6.1 with a 9 Hz tremble.
- **First person:** the hands are up and clench into fists, shut at 6.1.

**Lock-on and formation:**
- 0–0.7: a Frost Line circle draws round the target (then dims), and a frost disc spreads to 5.6 studs.
- From 0.3: 10 crystal clusters (2–3.6 studs) erupt in a ring of radius 7.
- 0.7–1.7: **16 panels** (4 sizes, plate radius 1.5 / 1.9 / 2.3 / 2.7 studs, 0.46 thick, 5–7 sided faceted plates, about 40 tris each) condense on a hemisphere of radius 11.5. They condense from 4 vapor puffs each, with an alpha-dissolve fade-in.

**Panel material:** Ice, Reflectance 0.4, Transparency 0.35, frosted edge collar, a faint edge highlight and 1–2 soft cracks in the texture. Roblox has no real mirrors, so on the 3–4 panels facing the camera a SurfaceGui ViewportFrame shows a low-detail clone of the target and the floor disc. That is the fake cube-map reflection.

**Aim and fire:**
- 1.8–2.4: aim in 4 tween ticks.
- 2.4–5.4: firing, staggered 0.075 s round the ring, 5 shots per panel.
- Each shot has:
  - a **Frost Line pulse on the panel outline** (a rectangle of Neon edge parts, Transparency 0 → 1 in 0.16 s);
  - a **centre flare** (a sparkle plus a PointLight at Brightness 3 for 0.1 s);
  - a bolt (a 1.4-stud prism of about 30 tris, at 55 studs/s, with a Frost Line Trail).

The target's frost skin climbs during firing.

**The kill and after:**
- 5.4: every panel's outline flashes, a light flash lights the target (its reflections flare), and FROZEN! pops.
- 6.1: hit-stop 2 frames. The panels tween 30 % inward and shrink, then emit 6 shards plus 2 powder each; the clusters break (4 shards each).
- The frost disc melts by 7.4.

## 5. Blizzard (Technique)

**Animation** (trigger = the cast at **0**):
- **Third person:** arms overhead at 0.35, swept out at 0.7, a wide held stance.
- **First person:** the same, plus a frosted vignette.

**Storm wall:** a cylinder MeshPart, radius 31 and 16 tall, open-ended, 96 segments.
- It carries a scrolling SurfaceAppearance of driven-snow streaks (Transparency 0.5 with a Fresnel-like denser edge; Roblox fakes this with a second, slightly larger cylinder at higher transparency), rotating at 0.18 rad/s.
- An emitter ring of 8 ParticleEmitters: rate 60 at High, lifetime 2 s, tangential speed 12.

**Vortex at the top:** a funnel MeshPart (about 1k tris) with a spiral cloud texture, rotating at 0.35 rad/s. The cast swirl over the caster is the same mesh, small.

**Floor ring:** a Frost Line Beam ring of 16 segments, width 0.22. It draws in 1 s, then holds at half brightness so it reads from far away.

**Inside:**

| Element | Spec |
|---|---|
| Fog | **Local Atmosphere density** 0 → 0.45 for players inside, thicker toward the centre (by distance). Blender uses a volume. |
| Driven flakes | 2 emitters on a camera-follow part: rate 120, size 0.1–0.5, lifetime 1–1.8 s, wind |
| Horizontal streaks | stretched sprites, rate 30 |
| Powder swirls | rate 8 |
| Gusts | every 1.2–1.4 s: a burst on the emitter speed plus 6 pale streak Beams |
| Floor | a 33-stud frost decal whitening over 3.5 s, plus a mist and drift decal |
| Slowed players | a frosted-vignette ScreenGui (a frost-fern edge image, Transparency 0.4) |

**End:** over 1.8 s the rates fall to 0, the wind drops and the floor decal breaks up.

## 6. Cold Momentum (Passive)

**Trigger:** the landed hit. It lasts 2 s, and there is no animation of its own.

- **On trigger:** a ripple Beam at the feet and 5 flakes.
- **Frost prints:** on each foot plant (about 5 a second), an oval frost decal 0.85 × 0.5 studs with ragged break-up. Its Frost Line rim is bright for 0.2 s only, and the print fades in 1 s. Pool of 14.
- **Breath:** a puff every 0.45 s (5 sprites).
- **First person:** 10 faint cold streaks at the screen edges (ScreenGui lines, Transparency 0.8).
- **The end:** a shiver of 18 flakes.

**Reduce Enemy VFX** (what enemies see): the faint prints only.
