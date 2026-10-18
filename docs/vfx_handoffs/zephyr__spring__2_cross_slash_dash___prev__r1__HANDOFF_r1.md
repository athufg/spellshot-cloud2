# 2. Cross-Slash Dash (Primary): handoff for the Roblox Studio build

Source of truth for every number: `blender_scripts/zephyr/spring/cross_slash_dash_bl.py`. All numbers are provisional
look-dev values, never final tuning. Units are studs and seconds. **t = 0 is the Primary key press** (the shared trigger
beat for the first-person clip, the third-person clip and every effect below).

## The beat sheet (shared by both animation clips and all effects)

| t (s) | Beat |
|---|---|
| 0.000 | press. Counter-move starts: the arms open back, the chest lifts |
| 0.100 | counter-move peak |
| 0.280 | the arms lock in the X-guard (back ease, a small overshoot); the forearm sheaths draw on at 0.17 / 0.20 |
| 0.280-0.420 | the coil: shoulders rise, a tremble builds (amplitude 0 to 0.034 studs, ~15 Hz); the vortex tightens |
| 0.400-0.500 | the dash anticipation: the weight rocks back 0.30 studs, the hips sink |
| 0.500 | launch |
| 0.500-0.760 | the dash: 21.3 studs, peak 110 studs/s (average 82), ease in over 0.04 s, ease out over the last 0.10 s |
| 0.651 | the chest passes through the target |
| 0.628-0.700 | the arms snap out (the release; 'snap' ease = 1-(1-u)^5); hand trails on |
| 0.760 | arrival: the slash pose. Root slides on 0.73 studs to a stop at 0.98; skid-turn yaw -63 deg, 0.69-0.92 (overshoot) |
| 0.760-0.827 | **the tension hold, exactly 2 frames at 30 fps**: the cut lines hang on the target, the air inhales |
| 0.827 | slice 1 ("\") starts drawing (60 ms, ease-out) |
| 0.849 | slice 2 ("/") starts drawing |
| **0.861** | **the crossing: damage / hit-confirm moment.** Flash, ground arc, dust burst, debris, target knockback |
| 0.861-1.191 | the X holds (0.33 s) |
| 1.191-1.691 | the X frays out from its ends (0.50 s); end wisps run to ~2.0 |
| 1.020-2.600 | recovery (3P: rise, a half step, the head and chest turn back toward the target) |

## Meshes

| Mesh | Use | Rough budget |
|---|---|---|
| Open ground arc | a flat 300 deg spiral strip (radius 1 to 1.22 across its length), scaled up 1.1 to 5.9 studs over 0.55 s | 128 tris |
| (optional) open spiral strip | the charge vortex arm, if Beam chains prove too heavy (0.85 turn, log radius growth x6) | 112 tris each, x2 |
| Leaf, petal (hero leaves only) | a few MeshPart leaves near the camera in first person; everything else is sprites | 24 tris each |

Everything else is Beams, Trails and ParticleEmitters: there is no other mesh.

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| `air_streak` | 256 x 64 | the air body: an alpha ramp across the width (soft noisy edges), streak noise stretched along u, a fibrous tail. Shared by every Beam |
| `air_core` | 256 x 32 | the pale mint core thread (#EFFFE6), broken into streaks; offset toward one edge for the blades (coreoff 0.26-0.40) |
| `blade_mask` | 256 x 64 | the X blade: a crescent alpha (thin-thick-thin along the length, sin^0.6), the core on the convex edge. Beam width is linear, so the crescent lives in the texture |
| `leaf_tumble` | 4 x 4 flipbook, 64 px frames (256 x 256) | a tumbling leaf, three greens (#34A45A, #5FD46E, #8FE07A); about 15 % of emitters tinted toward #E9F7A4 |
| `petal_tumble` | 4 x 4 flipbook, 64 px | a pale petal (#F4F3E6 / #E8F6DC) |
| `grassbit_tumble` | 4 x 4 flipbook, 64 px | a torn grass blade (#78A86A) |
| `twig`, `fluff` | 64 px stills | a short twig (#82604A); a seed pappus (#F6FBF2) |
| `soft_round` | 64 px | pollen (#FBF6CF), glints (#EFFFE6), dust (#D9D1C4), mist (#E4F4E6) |

## Beams and trails

Every air shape is a body Beam with `air_streak` (LightEmission about 0.2, LightInfluence 0, Transparency 0.4-0.75 per
layer) plus its core (the second texture, LightEmission 1, Transparency high). `TextureSpeed` about 1.5 (4.5 studs/s of
streak scroll at the kit's scale). Never raise brightness to gain presence: add layers, width, motion and debris.

| Group | Count | Construction | Segments | Width | Timing |
|---|---|---|---|---|---|
| Forearm sheaths | 2 + 2 hairlines | a Beam along each forearm, laid on the ideal X diagonal (46 deg), 0.8-1.0 studs in front of the arms, 3.2-3.7 long. FaceCamera off (in the chest's frontal plane) | 10 | 0.62 at the middle (blade texture) | draw on 0.17 / 0.20 (70 ms), fade 0.61-0.68 |
| Charge vortex | 2 arms + 2 hairlines + 1 haze veil | Two open spiral arms 180 deg apart, 0.85 turn. The radius runs from the inner head to the outer tail, tightening over 0.08-0.46 from 0.90 to 3.6 down to 0.62 to 2.6. The arms open toward the viewer, CCW as the caster sees it, with the spin accelerating. The inner 30 % of each arm fades in, so the vortex never piles up into a disc at the crossing. Hairlines: 0.72 turn, radius 1.0-3.4. The haze veil sits 1.5-3.4 out at Transparency 0.9. Each arm = 3 chained curved Beams (or the spiral mesh) | 12 per Beam | 0.12 to 0.72 to 0 | fade in 0.06-0.18; flung back into the streak 0.50-0.62 |
| Inflow streaks | 4 | short arcs (1 rad) drawn in from 4.6 to 1.2 studs on a 0.24 s cycle | 8 | 0.08 to 0.03 | 0.10-0.62 |
| Dash streak | 2 Trails | a chest Trail (width 2.0, widening x1.55 as it ages, wandering +-0.3) and a lagging hip-height under-sheet (width 2.9, Transparency 0.76) | Lifetime 0.4 | WidthScale 0.55 to 1 to 0.3 | 0.50-1.35; thins across the tension hold so the X stands alone |
| Helix hairlines | 2 Trails | on two Attachments orbiting the chest (radius 0.75 opening to 2.2, pitch 7.5 studs): their Trails ARE the helix | Lifetime 0.4 | 0.06 / 0.05 | with the dash |
| Shimmer veil | 1 | a very faint wide Beam round the body (Transparency 0.85) | 6 | 3.8 | dash only |
| Speed lines | 4 | short hairline Beams around the body, 3-6 studs | 4 | 0.055 | 0.52-1.0 |
| Release trails | 2 + 2 hairlines | Trails on the cuff Attachments, enabled 0.63-0.70 only | Lifetime 0.075 | 0.8 (sin profile) | fade by 1.0 |
| Cut lines | 2 | thin pale Beams on the target along the two diagonals, mostly core | 4 | 0.06 to 0.09 | on at 0.66 (drawn in 40 ms from the centre out), off as the slices cover them |
| **X blades** | 2 | Attachment0/1 at the blade ends (7.6 studs apart), CurveSize for the 0.45 bulge, `blade_mask` texture; the draw-on moves Attachment1 from the start to the end (or a per-frame Transparency NumberSequence). Stamped 1.9 studs in front of the target toward the local camera (ZOffset / an offset part) | 20 | 0.92 | see the beat sheet |
| X under-layers | 2 | the same, 1.95 wide, Transparency 0.8, 14 ms behind | 20 | 1.95 | hold, fray |
| X hairlines | 6 | 3 per blade, offset 0.62 / -0.42 / 1.05, longer (x1.22, 1.16, 1.32); they run 30 % longer and curl as the X frays | 12 | 0.045-0.06 | |
| End wisps | 4 | hairlines peeling off each X end, extending 1 to 4.2 studs and curling | 6 | 0.07 to 0.03 | 0.96-1.95 |
| Open air arc | 1 | a 270 deg arc round the X, radius 1.2 to 3.8 (spiralling out x1.35), Transparency 0.76: never a closed ring | 3 Beams x 10 | 0.42 | 0.86-1.28 |
| Ground arc | 1 + hairline | the ground arc mesh, 300 deg, scaled 1.1 to 5.9 | mesh | 0.85 to 0.38 | 0.86-1.41 |

**The X is drawn for each viewer:** the client orients the X to its own camera at spawn (twisted 26 % toward the
dash's perpendicular so it keeps depth) and fixes it in the world. Every client sees a readable X, and the attacker's
first-person look-back sees it face-on.

## Particle emitters (all ride the move's air: in Roblox, Acceleration, Drag and VelocityInheritance approximate it)

| Emitter | Burst / rate | Lifetime | Speed (studs/s) | Notes |
|---|---|---|---|---|
| Charge leaves | 20 over 0.02-0.30 | 1.9-2.8 | inflow to the forearms, swirl 26 | spawn 1.6-4.2 studs out (half lifted off the grass), orbit in, are dragged into the streak |
| Charge petals | 11 | same | same | |
| Charge grass bits | 6 | same | same | |
| Charge pollen / glints | 26 / 6 | 1.5-2.5 / 0.3-0.45 | slow | glints sparkle on the vortex |
| Path grass bits | 34, each when the caster passes its spot | 1.2-1.9 | up 5-10, forward 7-18, out 2-6 | the grass peeling off the path |
| Path petals | 10 | 1.3-2.0 | up 5-9, forward 8-16 | stripped off the path's flowers (they read on the pale floor) |
| Path dust | 22 + a 5-puff push-off kick + a 10-puff skid spray | 1.0-1.6 | forward 5-13 | pale lit veil (#D9D1C4), grows x2.4 |
| X leaves | 22 | 1.6-2.4 | 17-33 along the 4 X directions, 25 % heavy (x1.25, size x1.4: they overshoot) | |
| X petals / grass / twigs / fluff | 15 / 8 / 4 / 6 | 1.2-2.6 | 6-29 along the X | |
| X pollen / glints | 14 / 14 | 0.4-1.3 | 3-14 along the X | |
| X dust burst | 32 + 5 slide puffs | 1.5-2.2 | radial 7-15 | at the target's feet, grows x2.4 |
| X mist | 10 along the arms + 7 low puffs | 0.7-1.3 | 4-10 | |

**Totals:** about 291 particles over the whole move (charge 69, dash 85, X 137), 45 Beam/Trail shapes (about 30 at
once at most), and 47 grass tufts (5 local patches).

**Graphics Quality / Reduce Enemy VFX, in the order they drop:**
1. Pollen and glints.
2. The path and charge grass bits, to 30 %.
3. The inflow streaks and the shimmer veil.
4. The X under-layers.
5. The X hairlines, from 3 per blade to 1.
6. The dust, to 40 %.

Never dropped: the X blades with their cores, the cut lines, the ground arc and the first 8 X leaves (the identity and
the hit read). With Reduce Enemy VFX on, an enemy's X keeps its blades, cores and ground arc; its debris goes to 25 %,
its flash to half.

## Light

- **Flash:** a PointLight (mint-white Color3 (0.92, 1, 0.9)), 1.6 studs in front of the X toward the viewer. Blender
  peaks at 220 W with a 20 ms rise and tau 0.085 s; in Roblox use Brightness about 2, Range about 12, and the same
  decay. It never whites out the target (checked on both backdrops).
- **Bloom:** the kit's post bloom (threshold 1.25, strength 0.14). Nothing crosses it except the 2-frame glow at the
  crossing (the blades' glow pulses to 1.58 of the 1.6 cap).

## Animation clips

**Third person, `CrossSlashDash_3P`** (the full body; caster-local keys, poses in the script):

| t (s) | Key |
|---|---|
| 0.00 | READY |
| 0.10 | ANT: the arms swing open-back, the chest lifts |
| 0.28 | CROSS: the X-guard, wrists crossed at the chin, elbows dropped (back ease) |
| 0.42 | COIL: hips 1.66, shoulders +0.26, chin down; tremble |
| 0.50 | DIP: hips 1.52, the weight back |
| 0.555 | DASH: a 45 deg forward lean (pelvis + spine), the guard leading, the head up, the rear leg trailing (snap ease) |
| 0.628 | DASH, held |
| 0.70 | SNAP: both arms flung out (snap) |
| 0.76 | SLASH: a wide skid stance, the hips at 1.34, the arms fully extended wide and a little back (back ease) |
| 1.02 | SLASH2: settling |
| 1.42 | REC1: rising, a half step, the hips shifting, the head turning back to the target |
| 1.85 | REC2 |
| 2.60 | idle |

Root motion as in the beat sheet: dip, dash, skid, skid-turn yaw -63 deg, then a relax of +10 deg over 1.05-1.9.

**First person, `CrossSlashDash_FP`** (the viewmodel arms, on the same beats):
- **0.00 READY:** the hands rest in the lower corners.
- **0.10 ANT:** the hands open out of frame.
- **0.28 CROSS / 0.42 COIL / 0.50 DIP / 0.555 DASH:** the forearms rise from the bottom corners to an X apex in the lower
  third. The shoulders rise into the coil, with the same tremble.
- **0.70 SNAP:** the arms fling out past the frame edges.
- **0.76-0.94 SLASH:** the arms stay out wide.
- **1.22 REC1:** the hands come back into the lower frame while the X holds.
- **1.75 END.**

The camera sits at the eye (0.30 studs back), level, with half of the damped body lean.

**Target reaction, `Hit_CrossX`** (on the X crossing, 0.861):

| t | Key |
|---|---|
| +0.055 | shoved: the hips forward, the head and arms whip back |
| +0.21 | folds |
| +0.44 | a stumble step |
| +0.78 | catches itself |
| +1.45 | settled |

It moves 3.15 studs, away from the side the X lands on, with a 16 deg twist.

## Blender stand-ins and their Roblox equivalents

| Blender stand-in | Roblox build |
|---|---|
| `Ribbon` + `mat_air` | Beam / Trail with `air_streak` + `air_core` (the body / shadow / core ramp is baked in the texture: Beams are unlit) |
| Flat-sheet ribbons (the blades, the arcs, the sheaths) | Beams with FaceCamera off, or the arc mesh |
| `Particles` (mesh leaves, petals, grass) | ParticleEmitters with tumbling flipbooks |
| The flow field | Acceleration + Drag + per-burst velocity; the charge pull is a short-lived attractor (bursts re-aimed each 0.1 s) |
| `Grass` (spring-bent tufts) | a few local tuft MeshParts tweened by the effect (terrain grass cannot be bent by VFX) |
| `Cloth` (the scarf, the hair) | a 3-4 bone scarf with a spring script, or a Trail-based ribbon |
| `Flash` | PointLight |

## Roblox limitations that forced a compromise

- Beam width is linear between Width0 and Width1, so the crescent blade shape lives in the texture's alpha.
- A Beam is one cubic curve, so the spirals are chains of three Beams, or the spiral mesh.
- Per-vertex alpha (the X fraying from its ends inward) becomes a per-frame Transparency NumberSequence set on the
  client.
- The X is per-viewer oriented: client-side VFX, never replicated as a world part.
- The first-person pass-through puts the camera through the target for about 1 frame. Roblox shows the target's
  interior (back faces culled) for that frame. The showcase drops that frame.
