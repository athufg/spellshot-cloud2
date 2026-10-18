# 2. Cross-Slash Dash (Primary): handoff for the Roblox Studio build

Source of truth for every number: `blender_scripts/zephyr/spring/cross_slash_dash_bl.py`. All numbers are provisional
look-dev values, never final tuning. Units are studs and seconds. **t = 0 is the Primary key press** (the shared trigger
beat for the first-person clip, the third-person clip and every effect below).

**Round 2 (after the lead's review) changed:** the charge vortex (two open spiral arms at different radii, below), the
forearm sheaths (wider), the X blades' core (on the leading edge, wider), the X-guard and its swing-in (the forearms
clear the face and chest), the dash lean (moved into the spine), and the target reaction (lean away, stumble step back,
catch; no interpenetrating blocks). The kit's core colour is now `#EAFFEF` and its dust peaks at 0.40 alpha. The round-1
handoff is kept at `_prev/r1/HANDOFF_r1.md`.

## The beat sheet (shared by both animation clips and all effects)

| t (s) | Beat |
|---|---|
| 0.000 | press. Counter-move starts: the arms open back, the chest lifts |
| 0.100 | counter-move peak |
| 0.190 | the swing-in: the hands sweep round in front of the body (never through the chest) |
| 0.280 | the arms lock in the X-guard (back ease, a small overshoot); the forearm sheaths draw on at 0.17 / 0.20 |
| 0.280-0.420 | the coil: shoulders rise, a tremble builds (amplitude 0 to 0.034 studs, ~15 Hz); the vortex tightens |
| 0.400-0.500 | the dash anticipation: the weight rocks back 0.30 studs, the hips sink |
| 0.500 | launch |
| 0.500-0.760 | the dash: 21.3 studs, peak 110 studs/s (average 82), ease in over 0.04 s, ease out over the last 0.10 s |
| 0.651 | the chest passes through the target |
| 0.628-0.700 | the arms snap out (the release; 'snap' ease = 1-(1-u)^5); hand trails on |
| 0.760 | arrival: the slash pose. Root slides on 0.73 studs to a stop at 0.98; skid-turn yaw -63 deg, 0.69-0.92 (overshoot) |
| 0.760-0.827 | **the tension hold, exactly 2 frames at 30 fps**: the cut lines hang on the target, the air inhales |
| 0.827 | slice 1 ("\\") starts drawing (60 ms, ease-out) |
| 0.849 | slice 2 ("/") starts drawing |
| **0.861** | **the crossing: damage / hit-confirm moment.** Flash, ground arc, dust burst, debris, target knockback |
| 0.861-1.191 | the X holds (0.33 s); the target leans away (0.92), stumbles a step back (1.16), catches (1.48) |
| 1.191-1.691 | the X frays out from its ends (0.50 s); end wisps run to ~2.0 |
| 1.020-2.600 | recovery (3P: rise, a half step, the head and chest turn back toward the target) |

## Meshes

| Mesh | Use | Rough budget |
|---|---|---|
| Open ground arc | a flat 300 deg spiral strip (radius 1 to 1.22 across its length), scaled up 1.1 to 5.9 studs over 0.55 s | 128 tris |
| (optional) open spiral strip | the charge vortex arm, if Beam chains prove too heavy (A: 285 deg, radius x2.36 along it; B: 265 deg, x2.19) | 112 tris each, x2 |
| Leaf, petal (hero leaves only) | a few MeshPart leaves near the camera in first person; everything else is sprites | 24 tris each |

Everything else is Beams, Trails and ParticleEmitters: there is no other mesh.

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| `air_streak` | 256 x 64 | the air body: an alpha ramp across the width (soft noisy edges), streak noise stretched along u, a fibrous tail. Shared by every Beam |
| `air_core` | 256 x 32 | the pale mint core thread (#EAFFEF, the kit's r2 core), broken into streaks; offset toward one edge for the release trails and the dash streak (coreoff 0.35) |
| `blade_mask` | 256 x 64 | the X blade: a crescent alpha (thin-thick-thin along the length, sin^0.6), **the core ON the convex leading edge (coreoff 0.50, core width 0.62 of the half-width)**: r2, so the white-only read keeps a crisp edge line where "\\" crosses the pale target. Beam width is linear, so the crescent lives in the texture |
| `leaf_tumble` | 4 x 4 flipbook, 64 px frames (256 x 256) | a tumbling leaf, three greens (#34A45A, #5FD46E, #8FE07A); about 15 % of emitters tinted toward #E9F7A4 |
| `petal_tumble` | 4 x 4 flipbook, 64 px | a pale petal (#F4F3E6 / #E8F6DC) |
| `grassbit_tumble` | 4 x 4 flipbook, 64 px | a torn grass blade (#78A86A) |
| `twig`, `fluff` | 64 px stills | a short twig (#82604A); a seed pappus (#F6FBF2) |
| `soft_round` | 64 px | pollen (#FBF6CF), glints (#EAFFEF), dust (#D9D1C4, peak alpha 0.40), mist (#E4F4E6) |

## Beams and trails

Every air shape is a body Beam with `air_streak` (LightEmission about 0.2, LightInfluence 0, Transparency 0.4-0.75 per
layer) plus its core (the second texture, LightEmission 1, Transparency high). `TextureSpeed` about 1.5 (4.5 studs/s of
streak scroll at the kit's scale). Never raise brightness to gain presence: add layers, width, motion and debris.

| Group | Count | Construction | Segments | Width | Timing |
|---|---|---|---|---|---|
| Forearm sheaths | 2 + 2 hairlines | a Beam along each forearm, laid on the ideal X diagonal (46 deg), 0.9-1.0 studs in front of the arms, 3.5-4.0 long (r2: longer and wider, so the X charged on the arms reads from the front three-quarter view). FaceCamera off (in the chest's frontal plane). First person: raised 0.75 and 0.4 forward, so the X of air stands above the arms | 10 | 0.80 at the middle (blade texture) | draw on 0.17 / 0.20 (70 ms), fade 0.61-0.68 |
| Charge vortex | 2 arms + 2 hairlines + 1 haze veil | **Two OPEN spiral arms at different radii with a clear gap (r2; round 1's pair read as a closed ring face-on).** Arm A (outer): 285 deg, its radius spiralling from 3.30 at the tail in to 1.40 at the head. Arm B (inner): 265 deg, 1.05 in to 0.48, starting 150 deg round from A and turning 1.35x faster, so the two open sectors never line up. Their radii never overlap (at least 0.35 stud of open air between them). Each arm is a comet: a sharp head curling inward, the body widening behind it, the tail fraying; a pale core thread (core width 0.30) traces the spiral over the caster's green outfit. Both TIGHTEN: every radius x1.0 to x0.70 over 0.08-0.46. CCW as the caster sees it, the spin accelerating; the arms open toward the camera (third person) and toward the player (first person, where the vortex is centred on the raised air X at 0.6 scale). Hairlines: one per arm, only along its outer, older half (1.14x / 1.22x its radius). The haze veil: 200 deg, 3.3-3.9 out, Transparency ~0.93. Each arm = 3 chained curved Beams (or the spiral mesh); Width0/Width1 per Beam follow the comet profile | 12 per Beam | A: 0.05 to 0.62 (at 55 % of its length) to 0.30; B: 0.05 to 0.42 to 0.20 | fade in 0.06-0.18; flung back into the streak 0.50-0.62 |
| Inflow streaks | 4 | short arcs (1 rad) drawn in from 4.6 to 1.2 studs on a 0.24 s cycle | 8 | 0.08 to 0.03 | 0.10-0.62 |
| Dash streak | 2 Trails | a chest Trail (width 2.0, widening x1.55 as it ages, wandering +-0.3) and a lagging hip-height under-sheet (width 2.9, Transparency 0.76) | Lifetime 0.4 | WidthScale 0.55 to 1 to 0.3 | 0.50-1.35; thins across the tension hold so the X stands alone |
| Helix hairlines | 2 Trails | on two Attachments orbiting the chest (radius 0.75 opening to 2.2, pitch 7.5 studs): their Trails ARE the helix | Lifetime 0.4 | 0.06 / 0.05 | with the dash |
| Shimmer veil | 1 | a very faint wide Beam round the body (Transparency 0.85) | 6 | 3.8 | dash only |
| Speed lines | 4 | short hairline Beams around the body, 3-6 studs | 4 | 0.055 | 0.52-1.0 |
| Release trails | 2 + 2 hairlines | Trails on the cuff Attachments, enabled 0.63-0.70 only | Lifetime 0.075 | 0.8 (sin profile) | fade by 1.0 |
| Cut lines | 2 | thin pale Beams on the target along the two diagonals, mostly core | 4 | 0.06 to 0.09 | on at 0.66 (drawn in 40 ms from the centre out), off as the slices cover them |
| **X blades** | 2 | Attachment0/1 at the blade ends (7.6 studs apart), CurveSize for the 0.45 bulge, `blade_mask` texture (r2: the core on the leading edge, coreoff 0.50, width 0.62); the draw-on moves Attachment1 from the start to the end (or a per-frame Transparency NumberSequence). Stamped 1.9 studs in front of the target toward the local camera (ZOffset / an offset part), fixed in the world once stamped: the target is knocked back out from under it | 20 | 0.92 | see the beat sheet |
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
| X dust burst | 32 + 5 slide puffs | 1.5-2.2 | radial 7-15 | at the target's feet, grows x2.4; peak alpha 0.40 (the kit's r2 dust) |
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
| 0.19 | SWING (r2): the hands sweep round in front of the body, wide and forward (ease in, so the lock lands fast) |
| 0.28 | CROSS: the X-guard, the wrists crossed in front of the upper chest (the right forearm in front), the elbows bent forward and down (back ease). r2: lowered from the chin and pushed 0.4 forward, so the forearms clear the face and chest (round 1 drove them 0.65-0.71 stud into the head) |
| 0.42 | COIL: hips 1.66, shoulders +0.26, chin down; tremble |
| 0.50 | DIP: hips 1.52, the weight back |
| 0.555 | DASH: a 45 deg forward lean (r2: pelvis 0.22 + spine 0.56, the front knee lower, so the front thigh cuts the chest less: 0.47 to 0.37 stud), the guard leading, the head up, the rear leg trailing (snap ease) |
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

**Target reaction, `Hit_CrossX`** (on the X crossing, 0.861). r2: the round-1 fold knotted the blocks (thighs 0.24-0.26
stud into the chest); the new clip has no interpenetrating block pair (checked at 120 Hz, the script's `dcheck` mode).
The showcase target stands turned toward where the caster lands, so the X lands on its front:

| t | Key |
|---|---|
| +0.06 | LEAN AWAY: the chest takes the hit and the body pitches back (spine -0.40, pelvis -0.12), the arms fling out to the sides at shoulder height, the head lags; the root is knocked 0.70 back ('out' ease) |
| +0.07 to +0.30 | a STUMBLE STEP BACK: the left foot lifts (0.42 stud) and plants 2.0 behind; the right foot drags; the root 1.85 back |
| +0.62 | CATCH: the weight comes back over the feet with a dip (hips 1.84), the chest comes upright, the arms come down; the root 2.30 back |
| +1.40 | settled, 2.42 back |

It moves 2.4 studs straight back (away from the X and the caster), with a 14 deg twist (the "\\" lands first) that the
catch partly takes back. In Roblox the knockback is server-side (one direction for everyone: away from the caster's
arrival point); the X stays where it was stamped.

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
  interior (back faces culled) for that frame. The showcase drops that frame (r2: tested against the target's real
  blocks, with a 0.9 stud margin).
- Block-arm proportions (3 studs between the shoulders, 0.94-stud forearms): two crossed forearms always meet where they
  cross. The X-guard keeps the meeting behind the front forearm; the air sheaths carry the clean X.
