# 4. Skyrider (Technique): handoff for the Roblox Studio build (round 2)

Source of truth for every number: `blender_scripts/zephyr/spring/skyrider_bl.py`. All numbers are look-dev values,
not final tuning. Round 2 (after the lead's review) changed the wings (fewer stacked sheets, translucency graded along
the wing, barbed feather cards as the trailing edge), the mint cores, the gust cone (converging streaks and an open arc
front, no rings), and the first-person hands (camera-attached, lowered through the gust). The round-1 handoff is in
`_prev/r1/HANDOFF.md`. Units are studs and seconds. **t = 0 is the Technique key press**, the shared trigger beat for the
first-person clip, the third-person clip and every effect below. In the game, the ride lasts until the player dismounts
or mana reaches zero. The showcase compresses that ride into 6.2 s, so the flight section (0.88 to 2.95) and the
low-mana section (5.20 to 6.20) are the parts that loop or stretch.

## The beat sheet

| t (s) | Beat |
|---|---|
| 0.00 | Press. The rider crouches (0.00 to 0.14). The bird gathers out of the air (0.00 to 0.30): 8 open-spiral streaks contract into it and 24 fluff and pollen motes are drawn in. |
| 0.00 to 0.44 | **Summon.** The bird swoops in low from below and behind at 30 studs/s, skimming at 2.15 studs (at 0.28). It lifts dust, grass bits, leaves and petals off the floor, and a flat wake strip on the floor marks its path. |
| 0.14 | The rider jumps (18.5 studs/s up). |
| 0.38 to 0.52 | The rider passes from the ground frame into the bird's back frame (a blend over 0.14 s). |
| 0.40 to 0.60 | The catch: the wings rise (out ease, 0.40 to 0.47), then a snap downstroke (0.47 to 0.60). The tail fans and the beak gapes. |
| 0.44 to 0.88 | The rider lands in a deep crouch, then settles into the kneel with a back-ease overshoot. The kneel: right knee down with the toes curled, left foot planted with the knee up, the right hand low on the back, the left hand out for balance. |
| 0.88 to 2.95 | **Flight.** A 1.12 Hz flap cycle starts at 0.62. Banked S-turns: left 1.05 to 1.95, right 1.95 to 2.85. Bank = -1.15 x atan(v x yaw rate / g). The rider's lean leads the bank by 0.25 s: spine roll -0.30 x lean, hips shifting into the turn. Wing tips shed seed fluff (9 per s per tip) and the odd feather. |
| 2.95 to 3.30 | **Gust wind-up.** The wings rise high and sweep back (RAISE_G at 3.28), the bird pitches up 0.25 rad, the head draws back, and the tail flares. The rider pulls the left hand back. |
| 3.28 to 3.42 | **The gust flap.** A snap downstroke with the wings swept forward (STROKE_G). A clap bow of compressed air forms between the wing tips. The rider thrusts the left hand forward and down. |
| 3.34 | The cone leaves the chest. Half-angle 21 deg, reach 27 studs. Front distance = 27 x (1 - exp(-tau / 0.24)). It is drawn as **ten long streaks lying on the cone's surface, all converging on its apex at the chest** (their heads ride the front, their tails let go of the apex as it slows), plus **an open arc front**: a bow bulging forward that races down the cone (no rings). It carries 12 feathers with streak trails, plus leaves, petals and mist. |
| 3.51 | The cone's lower edge reaches the floor: a soft flash (200 W, tau 0.11; round 2: placed where the cone's lower edge first meets the floor, 1.8 studs up, not at the footprint centre beside dummy 1, which it whited out), three open ground arcs (285 deg open spirals), a dust veil, torn grass and leaves. |
| 3.62 / 3.88 | Dummy 1 (17.5 studs) and dummy 2 (23 studs) are shoved: a snap lean-back, a 0.38-stud hop, a slide of 4.6 / 2.4 studs, then a back-ease recovery over 1.1 s. |
| 3.65 to 4.55 | The bird peels off in a hard left bank, climbing to 12.5 studs. |
| 4.70 | **Hit wobble.** The hit envelope rises in 0.03 s and decays over 0.24 s, with a 3.5 Hz shake. The right wing dips 0.62 rad and the bank kicks +0.50 rad. Steering goes sloppy for about 0.5 s (yaw oscillation at 2.4 Hz). The ribbons stutter: the material clock steps at 11 Hz for 0.42 s and a stepped positional jolt runs at 15 Hz. 10 feathers shed, plus a mist puff, fluff, an open shock arc and a 150 W flash (round 2: was 220 W; the 10 shed feathers start 1.3 studs out, not 0.5, so they no longer stack and clip to white in the flash). The rider is thrown sideways and the left hand swings up to catch the balance. |
| 5.20 to 6.20 | **Low mana.** The bird thins: widths x0.78, opacity x0.58, the flap slows from 1.12 to 0.95 Hz with 30 % less amplitude, the tails fray more, and the wings droop with a tremble. Five flickers (55 % dips of 28 ms) at 5.56, 5.77, 5.93, 6.05 and 6.14. The tips shed more feathers. The rider glances down. |
| 6.20 | **Mana zero: the dismount.** Every shape keeps the bird's momentum, flies outward, unravels from its head over 0.5 s and is gone by 0.6 s. Each feather card flies off on its own, spinning. A burst of 24 feathers and 56 fluff, mist and pollen, and two open-spiral arcs. |
| 6.20 to 7.13 | The rider leaves the kneel and opens into a fall pose by 6.44, rights to upright over 0.42 s, and falls ballistically. |
| 7.13 | The rider lands in a crouch. Rise to stand by 7.88. |

## Meshes

| Mesh | Use | Rough budget |
|---|---|---|
| Bird rig | An invisible bone chain: 10 spine bones (beak to tail base), 3 bones per wing (shoulder, elbow, wrist), 1 tail-fan root, 1 head. Everything below is attached to it. | 0 tris (bones only) |
| Feather card | A curved contour feather: shaft on the long axis, 3 verts across, 9 along. 45 on the bird (2 x (11 secondaries + 5 primaries), 5 tail, 8 neck hackles), plus the shed ones as particles. The 11 secondaries per wing ARE the wing's trailing edge (round 2): an overlapping, serrated row splaying -4 to 22 deg, 2.2 to 3.4 studs long, vane width 0.33 x length, opacity 0.78 at the root to 0.60 at the wrist (primaries 0.74 to 0.58 toward the tip). | 32 tris each, about 1,450 total |
| Leaf | A pointed leaf with a raised midrib. 16 circulate inside the body. | 24 tris each |
| Rider, dummies | The existing R15 rigs. | n/a |

Everything else is Beams, Trails and ParticleEmitters.

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| Air body | 256 x 64 | Kit `mat_air`: an alpha ramp across the width (soft noisy edges), streak noise along the length, a fraying tail, the shadow / base / light colour ramp baked in (#1F8A4C, #4ADE6B, #A2EAA6 lit edge), and faint shimmer bands. Shared with every Zephyr piece. |
| Air core | 128 x 32 | A pale mint thread, the kit core #EAFFEF (hue 134), broken into streaks. A second variant with the thread offset to one edge (coreoff 0.3) for the wing leading edges and the cone's arc front, so the bright edge leads. |
| Feather (the bird's cards) | 128 x 256 | Barbs angled off the shaft, **18 across the length with clear gaps between them (about 45 % of each period is air)**, a shaft line, a solid-ish vane edge. The kit's own feather ramp: light body #A2EAA6 to core #EAFFEF. Round 2 local override of the kit's barb count (see NOTES): the kit's 46 fine barbs filtered to a smooth blade at hero distance. |
| Feather (shed particles) | 128 x 256 | The kit feather as is: 46 fine barbs, #A2EAA6 to #EAFFEF. |
| Leaf | 4 x 4 flipbook, 64 px | Tumbling leaf, #34A45A to #8FE07A, with lighter veins. |
| Seed fluff | 64 x 64 | Pappus: 9 filaments on a stalk, #F6FBF2. |
| Soft sprite | 64 x 64 | Dust #D9D1C4 (lit, never glowing), mist #E4F4E6, pollen #FBF6CF. |

## Beams and trails (third person; widths in studs, at bird scale 1.3)

| Element | Count | Segments | Width | Notes |
|---|---|---|---|---|
| Body | 1 | 30 | 0.05 (beak) to 2.6, peak 5.2 (chest to hips) | FaceCamera. LightEmission 0.2 (body), 1 (core). Alpha 0.60 x the kit's OPACITY. Round 2: a clear mint core Beam along the body line from the beak back (core width 0.24 of the half-width, riding slightly toward the back line, glow 1.25). |
| Crown, belly | 2 | 30 | 0.55 and 0.6 x the body width | FaceCamera, offset up and down. The crown lags 0.06 s and carries a thinner core (0.18). |
| Helix hairlines | 3 | 44 | 0.07 | Open spirals wrapping the body, 1.7 turns, scrolling backward at 0.9 turns/s, running 4 studs past the tail. |
| Crest plumes | 3 | 10 | 0.55 to 0.05 | Stream back off the crown with a 1.6 Hz wave. |
| Beak (upper, lower), eye lines | 4 | 4 to 6 | 0.7 to 0.05 | The beak gapes on the catch and the gust. |
| Saddle | 1 | 24 | 0.5 | A flat 300 deg open spiral under the rider's knees. |
| Wing leading edge | 2 | 18 | 0.8 to 0.13 | FaceCamera. The densest part of the wing: alpha 0.62, thinning to 70 % at the tip (Transparency NumberSequence). A clear mint core on its FRONT side (core width 0.45, offset 0.3 toward the bird's forward direction, glow 1.25; 1.05 in first person). |
| Wing covert sheet | 2 | 14 | 0.56 x chord (chord 5.7 at the root to 2.9 at the wrist) | Flat (FaceCamera off, oriented by the wing bones), on the FRONT half of the chord only. Alpha 0.44, graded along the span: 1.0 at the root, 0.85 at a quarter span, 0.42 at the wrist. Round 2 cut the trailing sheet and the camera-facing volume layer: the back half of the wing is the row of feather cards with air between them. |
| Primary slipstreams | 10 | 9 | 0.65 to 0.9 (0.46 x the round-1 width) | Flat, one narrow strip of air along each primary card. Alpha 0.36, 95 % at the root fading to 35 % at the tip. Splayed 16 to 63 deg, lengths 4.8 to 5.6 (local). |
| Echo hairlines | 4 | 22 | 0.07 | Lag the leading edge by 0.05 and 0.10 s. They fade as the lag separates them from the wing, so a fast stroke never leaves stray lines. |
| Tail fan | 7 | 9 | up to 2.1 | Flat. The fan spreads in turns and in the gust flare. |
| Tail streamers | 2 | 20 | 0.08 | Trails off the tail tip. |
| Wingtip contrail | 2 | 26 | 0.73 to 0 | A Trail on the tip. It leaves the real tip and relaxes onto the tip's path averaged over one flap, so a 12-stud vertical flap sweep never draws a vertical line. In Roblox, a Trail on an attachment that lerps toward the bird-local mean tip position. |
| Tip vortex hairlines | 4 | 40 | 0.065 | Spiral round the contrail at 2.6 turns/s. |
| Wind rush | 10 | 8 | 0.06 to 0.1 | Streaks rushing past the rider at 26 to 32 studs/s. In first person these are the peripheral streaks. |
| Summon gather | 8 | 24 | 0.08 to 0.16 | Open 250 deg spirals contracting onto the forming bird (0 to 0.4). |
| Wake | 2 | 20 | 1.6 to 4.4 | Flat on the floor under the swoop. |
| Gust clap | 3 | 30 | 2.1 broad + 2 hairlines | Crescent bows between the wing tips, 3.30 to 3.72. |
| Cone streaks | 10 | 18 | 6 broad (0.66 on the outline pair, 0.36, 0.30) + 4 hairlines (0.08), each narrowing to 22 % at the apex | FaceCamera. Each lies on a generator of the cone (apex at the chest, half-angle 21 deg), a slight twist round the axis. Head = the front + 0.6 studs; tail = 0.92 x the front 0.32 s earlier (so they span the cone, then let go of the apex as the front slows). Launch lags 0 to 0.06 s. The two broadest sit on the cone's OUTLINE as the camera sees it (the generators perpendicular to the view), so the frame draws a crisp "<"; in Roblox, place them from the local camera, or use six fixed angles round the axis. Alpha 0.72 (outline), 0.6, 0.55 (hairlines); core width 0.42 / 0.24. Fade in 0.06 s, out as the front passes 19 to 27 studs. |
| Cone arc front | 3 | 32 | 1.7 to 2.4 broad (sin-tapered ends) + a lagging 0.65 + a leading 0.08 hairline | FaceCamera. A bow, never a ring: in third person it lies in the plane through the axis that faces the camera, its ends on the cone's outline, its middle bulging 0.34 x the cone radius forward ("<)" with the streaks); in first person it is an arch about 165 deg round the axis, open at the floor side, its crown pushed forward, building only once 5 to 10 studs clear of the eye. It rides the front, fading out between 18 and 26 studs. Core on its leading side. |
| Cone body | 1 | 14 | 0.7 x the cone diameter | FaceCamera, along the axis, alpha 0.27, faded to nothing near the apex: a faint fill between the outline streaks. |
| Ground shove arcs | 3 | 40 | 1.3 broad + 2 hairlines | Flat 285 deg open spirals (the radius grows 28 % round the turn), the gap facing the camera's flank and back toward the bird. |
| Feather streaks | 8 | 10 | 0.09 | Trails behind the lead gust feathers. |
| Hit shock arc | 3 | 24 | 1.1 broad + 2 hairlines | A 290 deg open arc facing the camera, 4.70 to 5.2. |
| Scatter arcs | 2 | 40 | 0.9 + hairline | Open 320 deg spirals at 6.20. |

TextureSpeed: about 4.5 studs/s along the body (hairlines 1.6x). Every air shape fades in over at least 0.06 s and out
over at least 0.25 s. Nothing pops.

## Particle emitters

| Emitter | Count in the showcase | Lifetime | Sprite | Speed | Notes |
|---|---|---|---|---|---|
| Tip fluff | 9/s per tip (18/s while thinning); 155 total | 1.3 to 2.2 | fluff | 0.35 to 0.6 x the bird's velocity | Rides the wingtip vortex field. |
| Tip feathers | 10 % of spawns (35 % while thinning) | 1.8 to 2.6 | feather | 0.3 to 0.5 x the bird's velocity | |
| Gust feathers | burst 12 | 1.1 to 1.5 | feather | 40 to 54 down the cone axis | Each has a streak Trail. |
| Gust carry | burst 22 (leaf, petal, mist) | 1.3 to 2.0 | leaf / petal / mist | 24 to 40 | |
| Ground shove | 46 along the footprint, timed with the front | 1.6 to 2.6 | dust / grass / leaf / petal | 4 to 10, outward and forward | The dust is a lit veil, never a dark cloud. |
| Summon skim | 40 | 1.0 to 2.4 | dust / grass / leaf / petal | 0.25 to 0.55 x the bird's velocity, plus 2 to 7 up | |
| Hit | 24 (10 feathers, 9 mist, 5 fluff) | 0.6 to 2.4 | | 3 to 7 radial | |
| Scatter | 24 feathers + 56 (fluff, mist, pollen) | 0.9 to 2.8 | | 0.4 to 0.85 x the bird's velocity, plus 3 to 9 radial | |
| Body leaves | 16 circulating | loop | leaf | | Spiral through the body at 0.18 to 0.32 of its length per s. |

Every particle rides the same flow field: a breeze, the air entrained round the bird, the downwash, trailing wingtip
vortices, the summon inflow, the gust cone, the ground burst, the hit puff and the scatter. In Roblox, use
ParticleEmitter Acceleration / Drag plus a small client script that nudges the hero debris.

**Graphics Quality / Reduce Enemy VFX, in the order things drop:**
1. the rush streaks and tip vortex hairlines;
2. the echo hairlines and helix hairlines;
3. fluff and mist rates halve;
4. the body leaves and neck hackles;
5. the feather streak trails;
6. the cone's four inner hairline streaks and its cone-body fill.

Keep the body stack, the wing leading edges, covert sheets and feather cards, the tail, the cone's six broad streaks and
its arc front, and the dummy shove: the readable core.

With Reduce Enemy VFX on, an enemy's bird keeps the body, wings, tail and cone only: no particles apart from the gust
feathers, and no screen-space streaks.

## Animation clips

| Clip | View | Key times (s from the press) |
|---|---|---|
| Summon jump | 3P | crouch 0.14, jump 0.14 to 0.30 (snap), tuck 0.44 |
| Land into kneel | 3P | crouch 0.44 to 0.47, kneel 0.88 (back ease) |
| Kneel idle + lean | 3P | additive lean that leads the yaw rate by 0.25 s (spine roll, hips, head counter-roll) |
| Gust command | 3P / FP | wind-up 2.95 to 3.28, push 3.40 (snap), hold to 3.75, recover 4.15 (back ease) |
| Wobble catch | 3P | 4.70 to 5.2 (additive, from the hit envelope) |
| Low-mana glance | 3P | head pitch +0.42 at its peak, 5.2 to 6.0 |
| Fall + land | 3P | kneel to fall 6.20 to 6.44 (out ease), land 7.13, crouch held to 7.35, rise 7.88 (back ease) |
| Bird flap loop | bird | 1.12 Hz. Shoulder, elbow and wrist lag by 0.6 and 1.2 rad of phase, and the body wave runs head to tail (0.20 studs, phase lag 2.4 rad across the body). |
| Bird gust | bird | RAISE_G at 3.28, STROKE_G 3.42 (snap), held to 3.68, back to cruise 4.08 (back ease) |
| Bird wobble | bird | additive right-wing dip and bank (the hit envelope) |
| First person | FP | Hands braced low and forward (cuffs at the frame's lower corners), **camera-attached** (round 2): the hand targets keep the screen place they have in level flight whatever the bank, then the arms are IK'd from the shoulders. The gust (round 2): the left hand pulls back and out (2.90 to 3.26, io), thrusts forward-down at the target (3.38, snap), then BOTH hands drop low onto the bird's back, below the frame's lower corners (left 3.52 out, right 3.45 io; held to 3.95) so the cone and dummies read, and come back up to the braced pose by 4.30 (io). The camera pitch eases from -0.12 to -0.34 rad by 0.7 and dips another 0.16 through the gust. The camera keeps 20 % of the head's roll: a gentle roll into the banks. The head keeps a third of the 3P body pitch and lean. |

## Blender stand-ins and their Roblox equivalents

| Blender | Roblox |
|---|---|
| `Ribbon` with `mat_air`, camera-facing | Beam (FaceCamera on), the air body texture plus a second core Beam |
| `Ribbon`, flat (wing sheets, feathers, tail, ground arcs) | Beam with FaceCamera off, oriented by attachments on the bird bones |
| Contrail as a recomputed polyline | Trail on a wingtip attachment, lerped toward the mean tip path |
| Feather cards | MeshPart feathers (32 tris) on the bones; the shed ones become ParticleEmitter feather sprites |
| `Particles` (simulated debris) | ParticleEmitters, with a short client nudge for the hero leaves and feathers |
| `Grass` (spring-bent tufts) | a few local tuft MeshParts tweened by the gust (terrain grass cannot be bent) |
| `Cloth` (scarf, hair) | an existing cloth / spring-bone accessory |
| `Flash` | PointLight, brightness keyframed |
| The material clock stutter (wobble, flickers) | step TextureSpeed / TextureOffset for 0.4 s, and Transparency dips for the flickers |

**Roblox limitations:**
- Beams cannot fade by distance to the camera. The Blender script fades any ribbon point within 5 to 12 studs of the
  third-person camera, so the near wingtip trail never sweeps the screen. In Roblox, shorten the trail lifetime or hide
  it client-side when the rider is the local player.
- In first person, the mount's body Beams are 40 % more transparent (the mount must not wall off the view). Use
  LocalTransparencyModifier on the local player's own bird.
- The viewmodel hands are camera-attached (the usual Roblox viewmodel): parent the arm rig to the camera, not to the
  bird, or the levelled camera makes the hands swing across the view in a hard bank.
- The cone's two outline streaks are placed from the viewing camera (the generators perpendicular to the view). Every
  client can do this locally; where that is too costly, six streaks at fixed angles round the axis read nearly as well
  from the flank, and the arc front can be a Beam whose two end attachments sit on the cone's rim at the front.
- Gameplay distance: the bird spans about 35 studs, so its readability check is shot at 48 studs (the kit's default is
  30); at 30 studs it overfills the native crop.
