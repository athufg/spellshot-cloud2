# 3. Updraft (Passive): handoff spec

The Roblox Studio build for the airborne tell. Every number is provisional showcase tuning, not final gameplay tuning.
Blender source: `blender_scripts/zephyr/spring/updraft_bl.py`. The kit is `zk.py`, and the bible is `ZEPHYR_STYLE_BIBLE.md`.

## What it is

The passive has no ability clip. It's a state tell: **on while the Humanoid is airborne** (Jumping / Freefall), **off on
Landed**. It is a small upward-opening funnel of air that the caster rides. It has four parts:

- **The funnel bands:** they start narrow under the feet and open round the shins and knees. They spin
  counter-clockwise seen from above, at 0.8 rev/s.
- **Hairline spirals:** three faint ones round the lower body.
- **Throat streaks:** short streaks rising in the funnel's throat.
- **Debris:** pollen and seed fluff riding up the legs.

An aerial hit landed by the caster (the passive's bonus-damage hit) **brightens** the tell for about 0.5 s. Landing
**thins** it away in 0.42 s while two open spiral arms spill across the floor.

**Shared trigger beat:** t = 0 is the jump key press, which is also the take-off (feet leave the floor). Every time below is in seconds from it.
The aerial-hit beat has its own origin, t_hit = the server-confirmed aerial hit.

| Beat | Showcase time | Roblox trigger |
|---|---|---|
| the tell builds (draws on from the feet up) | 0.00 to 0.12 | Humanoid.StateChanged to Jumping or Freefall. Use 0.08 s in game: a default jump is only about 0.5 s of air |
| airborne steady state | 0.12 to landing | while the state is Jumping or Freefall |
| aerial hit: the tell brightens | t_hit + 0.00 to 0.035 (rise), then decay tau 0.32 s (about 0.6 s total) | the passive's on-hit event while airborne |
| landing: the tell thins away | t_land + 0.00 to 0.42 (bands), 0.68 (hairlines), 0.75 (floor spill) | Landed |

The showcase arc uses zk.G, real gravity (28.6 studs/s²): 1.40 s of air and a 7-stud apex, so the tell can be seen. Roblox's
default 196.2 studs/s² gives about 0.5 s of air. The tell must therefore read from its first 0.1 s, so build fast and
skip the throat streaks on short hops if needed.

## Meshes (rough triangle budgets)

All the air shapes are **Beams** (below), so no custom mesh is needed for the tell.

- Optional, for low Graphics Quality: a single pre-modelled **tapered helical strip MeshPart** per main band (1.1 turns,
  32 segments × 2 tris = 64 tris). It would use a static alpha texture, spun by script, standing in for the 4-beam chain.
- The caster's **scarf**: 2 tails (1.9 and 1.5 studs, 0.26 and 0.24 studs wide). Use a skinned MeshPart with 6 to 8 bones
  per tail, about 40 tris per tail.
- **Hair tufts**: 7 small skinned strips, about 8 tris each. These can be static in Roblox.

## Textures and flipbooks

The shading lives in the textures, because Beams are unlit. The colours are the bible §1 palette after the kit's VIBRANCE
1.69 saturation boost.

| Texture | Size | Contents |
|---|---|---|
| `zk_air_streak` | 256 × 64 | Tileable along u. Across v: shadow `#1F8A4C` on the lower edge, through base `#4ADE6B`, to light `#A2EAA6` on the lit (upper) edge, desaturated about 24 % toward `#CFE2D6`. A pale mint `#EFFFE6` core thread at v = 0, broken into streaks by stretched noise. A few sparse accent `#E9F7A4` flecks near the lit edge. Soft noisy alpha at both edges. Shared by every Zephyr piece. |
| `zk_air_hairline` | 128 × 16 | A thin streaky thread: the core plus a little body green. |
| `zk_streak_sprite` | 32 × 128 | A soft vertical streak for the throat streaks (VelocityParallel particles). |
| `pollen_dot` | 32 × 32 | A soft round dot, `#FBF6CF`. |
| `seed_fluff` | 64 × 64 | A pappus: 9 radial filaments in a shallow cup plus a short stalk, `#F6FBF2`, alpha 0.75 tapering to the tips. |
| `glint` | 32 × 32 | A soft 4-point sparkle, `#EFFFE6`. |
| `petal_tumble` | flipbook 4 × 4, 128 px cells (512 × 512) | A tumbling petal, `#F4F3E6` to `#E8F6DC`. |
| `grass_bit` | 32 × 128 | A blade fragment, `#78A86A`. |
| `dust_puff` | 128 × 128 | A soft round puff, `#D9D1C4`. **Lit, not emissive** (LightEmission 0, LightInfluence 1), so it never glows on a dark map. |

## Beams and trails (the air)

Transparency values are Roblox `Transparency` (1 - opacity) at the band's centre. They include the kit-wide OPACITY 1.69, so the Blender `alpha` 0.58 × 1.69 gives about 0.98 opacity on the streaks. The edges and the frayed tail go to 1.

Each band is a **chain of Beams** along a helix: one Beam spans about 0.25 to 0.33 of a turn, with CurveSize0 and CurveSize1
set to approximate the arc. The attachments sit on the helix in a frame welded to the HumanoidRootPart. One script rotates
that frame counter-clockwise (seen from above) every RenderStepped, at 0.8 rev/s, and rescales the heights.

| Band | Beams | Segments each | Radius (bottom to top) | Height (from the feet plane) | Width curve | Transparency | TextureSpeed | LightEmission | FaceCamera |
|---|---|---|---|---|---|---|---|---|---|
| main A | 4 | 12 | 0.70 to 1.80 (opens fast, exponent 0.5) | -1.1 to +2.3 | 0.3 at the throat, rising to 1.0 by 45 % of the length, then 0.65 at the top | 0.15 at the centre (about 0.3 averaged over the streaks), the head fading in over the first 16 %, the tail fraying over the last 55 % | 4 (streaks flow UP) | 0.15 | false: the width lies on the funnel surface |
| main B | 3 | 12 | 0.85 to 1.95 | -0.7 to +1.7 | peak 0.72 | 0.25 | 4 | 0.15 | false |
| secondary | 2 | 10 | 1.75 to 2.40 | +0.2 to +2.0 | peak 0.40 | 0.45 | 3 (slower: it spins at 0.6× the rate) | 0.1 | false |
| haze veil | 2 | 8 | 1.3 to 2.0 | -0.6 to +1.4 | 1.9 wide | 0.80 | 2 | 0 | false |
| hairlines | 3 chains × 5 or 6 beams | 10 | 0.5 to 2.2, 0.7 to 2.0, 1.0 to 2.55 (1.8, 1.5 and 1.25 turns) | -1.5 to +3.2, -1.0 to +2.8, -0.8 to +2.0 | 0.05 to 0.065 | 0.35 | 6 | 0.1 | true |
| **hit surge** | 2 | 12 | rides main A, 0.4 of its length | climbs from the throat to the top in 0.42 s | 1.15× main A | 0.32, a pale core (core width 0.35) over green | 6 | 0.25 | false |
| **hit exhale** | 3 | 12 | 1.5 to 2.0, widening to 2.1 to 3.6 over 0.6 s | rises from -0.2 to +2.3, then +0.4 to +3.2 | 0.60 shrinking to 0.22 | 0.25, fading out with a 1.5 power | 4 | 0.2 | false |
| landing spill | 2 arms (2 + 2 beams) | 10 | from 0.42R to 1.25R and 0.5R to 1.1R, with R growing 1.4 to 3.9 over 0.75 s | flat on the floor (0.07) | 0.74 shrinking to 0.12 | 0.25, fading out with a 1.4 power | 3 | 0.1 | false: lies flat |

- **Brightening (aerial hit):** this is never more light, and never greener.
  - On main A and B, tween the core strength up by 1.6× (glow capped at 1.6), the pale core's width by 1.35× and the band width by 1.15×. Lower the Transparency by 0.07.
  - Keep green under the pale thread. A core-only band reads hue 98° (the core hex) and fails the NOT NEON hue check.
  - Fade in a second core-only Beam over main A and B (LightEmission 0.25, Transparency 0.55) for 0.5 s.
  - Spin ahead by 1.7 rad over 0.5 s.
- **Thin (landing):**
  - Bands: Transparency goes to 1 over 0.42 s (front-loaded, power 1.6). The throat attachments sink to the floor, and the
    radii grow 1.2× at the bottom and 0.6× at the top.
  - Hairlines: loosen up and out over 0.68 s.
  - Spill arms: play once.
- **Never** close a band into a ring. Every band is an open arc with tapered ends.

## Particle emitters

Roblox particles cannot ride a flow field. The stand-in is to emit from **2 or 3 attachments orbiting the axis**
counter-clockwise at radius 0.6 to 1.8 and 0.8 rev/s, with Speed along the tangent and up, Drag 4 to 6,
VelocityInheritance 0.9 and LockedToPart = false. Particles then spiral up and shed outward, like the Blender vortex.

| Emitter | What | Rate / burst | Lifetime | Size (studs) | Speed / motion | Sprite |
|---|---|---|---|---|---|---|
| pollen | specks spiralling up the legs | 85 /s while airborne, about 110 alive | 0.9 to 1.6 | 0.054 to 0.11 | tangent 3 to 7, up 2 to 6, Drag 30 (it tracks the air) | `pollen_dot`, LightEmission 0.3 |
| seed fluff | slow, drifting pappus | 16 /s, about 25 alive. 20 % are heavier: size 1.6 to 1.9×, an initial -6 studs/s, so they overshoot and lag | 1.5 to 2.6 | 0.135 to 0.22 (heavy 0.24 to 0.29). Keep them small and dim: bigger or brighter, they read as sparkle stars. First person: ×0.6 size | tangent 3 to 6, up 1 to 4, Drag 22, RotSpeed ±60 | `seed_fluff`, LightEmission 0.2 (not emissive white; the showcase uses emission 0.2 instead of the kit's 0.5) |
| throat streaks | rising air in the funnel's throat | 10 /s | 0.43 to 0.55 | 0.10 to 0.15 wide, 1.0 long | up 5 (VelocityParallel), LockedToPart | `zk_streak_sprite` |
| take-off kick | what the push lifts off the floor | Emit 14 pollen, 4 fluff, 4 grass bits, 3 petals, 7 dust at t = 0 | 0.55 to 2.4 | as above, dust 0.7 to 1.0 growing 2× | dust outward 7.5 and low, the rest drawn into the funnel | as above |
| hit exhale | the tell breathes out | Emit 30 pollen, 7 fluff, 10 glints, 2 petals at t_hit | 0.3 to 2.2 (glints 0.3 to 0.55) | glint 0.045 to 0.08 | radially out 4 to 9, up 2 to 5 | as above |
| landing spill | the air hits the floor | Emit 12 dust (a ring, outward 7.5), 6 grass bits | 0.9 to 1.4 | dust 0.8 to 1.2 growing 2× | radial, low | `dust_puff`, `grass_bit` |

**Graphics Quality and Reduce Enemy VFX scaling.** Drop things in this order:

1. The haze veil.
2. The throat streaks.
3. Hairlines 2 and 3.
4. The secondary band.
5. Pollen to 30 %.
6. Fluff to 40 %.
7. The hit glints and petals.

**Main bands A and B and hairline 1 are never dropped:** they are the silhouette that carries the tell at 10 studs. At the
lowest setting, use the two optional helical MeshParts instead of the 7 beams.

## Lights

- **Brightening:** one PointLight at the shins, 0.6 above the feet plane. Colour `#EBFFE6`, Range 6, Brightness 0 to 1.2.
  It rises in 0.035 s and decays with tau 0.32 s. The showcase stand-in is a 140 W point light × the hit curve.
- The aerial hit's impact flash belongs to the attacking ability (here a stand-in Wind Blade). The showcase stand-in is a
  140 W point light that starts at contact with tau 0.08 s.

## Animation (the shared trigger beat t = 0 = take-off)

No ability clip. The body language is the jump itself plus the cloth.

**Third person** (an optional airborne pose layer for Zephyr):

- **The dip:** -0.24 to -0.07, showcase only. In game the jump fires at the press, so compress it into a 2-frame push.
- **The push:** -0.07 to 0.00, with a snap ease. The arms swing up and forward.
- **Take-off extend:** 0.00 to 0.09. Toes pointed.
- **Riding:** 0.09 to 0.52. The knees tuck asymmetrically and the arms open for balance. The off-hand lags by 0.045 s and the
  head settles 0.06 s after the body.
- **Fall prep:** landing -0.07. The legs reach for the floor and the arms rise.
- **Land squash:** landing to +0.13. Hips down 0.68 studs, spine pitched forward 0.3.
- **Springy recovery:** to +0.50, with a back ease (overshoot).
- **Settle:** to +1.05.

The showcase's aerial-hit flick (a Wind Blade stand-in) runs:

- wind-up from 0.52 to 0.648: the chest turns 0.30 rad right and the hand cocks back;
- the snap at 0.695;
- the follow-through, with overshoot, to 0.86.

That clip is the M1's, not this passive's.

**First person** (viewmodel arms, same clock):

- **While airborne:** the hands go out to the sides at mid-frame, palms catching the air. A flutter of 0.05 studs at
  17 to 23 Hz rides on top. On the aerial hit both hands lift 0.12 studs (decaying tau 0.32 s).
- **On landing:** they swing down out of view by +0.70.
- The showcase camera looks well down (pitch -1.34 rad) while riding, so the funnel is seen from above as an open spiral
  under the player.

**Cloth (scarf and hair):** while airborne the air at the body moves with the caster plus a 9 studs/s lift and a
counter-clockwise swirl, so the scarf streams **up** whether rising or falling, and twists as it winds.

- On the aerial hit, the lift goes up to 15 studs/s and the swirl doubles for about 0.5 s.
- On landing the lift is released and the scarf drops onto the shoulders.

## Blender stand-ins and their Roblox equivalents

| Blender | Roblox |
|---|---|
| `Ribbon` + `mat_air` (alpha-blended strip, procedural streak noise, scrolling) | Beam chains with `zk_air_streak`, TextureSpeed |
| camera-facing hairline Ribbons | Beams with FaceCamera = true |
| `Particles` riding the vortex flow field (`field()`) | ParticleEmitters on orbiting attachments, plus Drag and VelocityInheritance. **A compromise:** no true field, so the paths are spirals but less coherent |
| `Cloth` verlet scarf and hair in the same air, with a drawing-only twist (`TwistCloth`) | a script-driven bone spring chain on a skinned scarf. **Roblox has no cloth sim.** Its target direction = up + CCW while airborne |
| `Grass` tufts bending in the take-off / landing air | a few local grass-tuft meshes tweened outward and springing back. Terrain grass can't be bent by VFX, and this is optional |
| `Flash` point lights | PointLights tweened by script |
| scene-linear emission capped by `zk.E()`, bloom 1.25 / 0.14 | Beam LightEmission ≤ 0.25 and the game's Bloom. Keep the tell under the bloom threshold (NOT NEON) |

## Roblox limitations that forced a compromise

- **No flow fields:** particles approximate the vortex with orbiting emitters.
- **No cloth sim:** the scarf uses bone springs.
- **Helices need Beam chains:** a Beam is one Bezier, so it needs about 4 attachments per turn, rotated each frame by script.
- **Texture scrolling only exists on Beams and Trails:** the low-quality MeshPart fallback is static, with its spin done by
  CFrame.
- **Short default air time:** with about 0.5 s of air, the build must be about 0.08 s, and the throat streaks may be skipped
  on short hops.
