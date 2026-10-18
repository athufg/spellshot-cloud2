# Zephyr v6 handoff: a jointed Skyrider, a reference Cyclone, and effects that light the stage

**Everything not changed here is as in `../aqua_v5/ZEPHYR_V5_HANDOFF.md`:** the palette, the materials, the Bloom
settings, and each piece's v5 layers.

**Gameplay numbers are provisional.** The Blender sources are in `blender_scripts/zephyr/aqua/*_v6.py`.

- **Deliverables:** `<n>_<piece>/zs6v_<piece>.mp4`, a 1080p30 clip per piece: third person with the slow-motion
  signature, then 2–3 s of first person.
- **Contact sheets:** `zs6v_<piece>_sheet.png`.
- **Reel:** `reel/zephyr_v6_kit_reel.mp4`.

## 1. Skyrider bird: joint list and Roblox rig mapping

**Joints, per wing (×2):** 13 springs.

| Bone | Length | Degrees of freedom |
|---|---|---|
| Shoulder → upper arm | 2.9 | Elevation `e_s`, sweep `sw_s`, twist `tw_s` |
| Elbow → forearm | 3.1 | Flex `f_e`, elevation `e_e` |
| Wrist → hand | 2.9 | Flex `f_w`, elevation `e_w`, twist `tw_w` |
| Primaries | n/a | Fan `fan`, slot rotation `slot` |
| Feather bend, one per tier | n/a | `b_cov`, `b_sec`, `b_pri` |

- **Units:** lengths are bird-local. Multiply by 0.6 (KS) × the bird scale to get studs; the wingspan is about 19
  studs.
- **Shoulder position:** `(±0.85, 2.7, 0.95)` in the body frame.
- **Body chain:** body root, then spine (8 joints), then the 7-feather fan tail and the head.
- **Crest:** 3 ribbons.

**Roblox rig: one model, the bones driven from a client script.**

| Blender | Roblox |
|---|---|
| Body and membranes (41×7 sheets) | **One skinned MeshPart.** Bones: `Root`, `Spine1–4`, `Head`, `Tail`, and per side `Shoulder`, `Elbow`, `Wrist`, `Tip`. Membrane: about 12×4 quads per wing, with weights blended ±6 % of the span across each joint (as the Blender spar). |
| Jointed wing segments | The `Shoulder`, `Elbow` and `Wrist` bones. Each bone's `Transform` = `CFrame.Angles(elevation, sweep, twist)` in its parent's frame. Never one rigid wing. |
| Feather tiers (coverts 16, secondaries + tertials 16, primaries 10 per wing) | Feathers are flat **feather meshes on pivots.** Use one skinned MeshPart per tier per side (6 meshes). Each feather has its own bone at its quill root, parented to the arm bone it sits on (coverts on the upper arm and forearm, secondaries on the forearm, primaries on the hand). A feather's bone rotation is fan × index (primaries 20–82° from the chord), slot (the upstroke opens the primaries), and bend (about the feather's local x, per tier). For lower settings, cut to 8 / 8 / 6 per wing. |
| Spar (spline leading edge, core plus glow) | 2 Beams per wing along Shoulder → Elbow → Wrist → Tip attachments: CurveSize set from the bend, LightEmission 1. |
| Wingtip vortices, crest | Trails on the `Tip` attachments and on 3 head attachments. |

**Spring lag script** (client, `RunService.PreSimulation`, 4 substeps at 60 fps = 240 Hz):

```
for each wing s, each dof i:
    target = REST[i] + wa * STROKE_TERM[i](phase - LAG[i])   -- LAG: elbow 0.35, wrist 0.70, primaries 1.05 rad
             + bank/hit/gust terms (below)
    a      = K[i]*(target - x[i]) - 2*Z[i]*sqrt(K[i])*v[i]
    v[i]  += a*dt ;  x[i] += v[i]*dt                          -- semi-implicit Euler
```

**Spring constants:**

| Degree of freedom | K | Z (damping ratio) |
|---|---|---|
| Shoulder (`e_s`, `sw_s`, `tw_s`) | 560, 560, 480 | 0.75, 0.8, 0.7 |
| Elbow | 460 | 0.7 |
| Wrist | 380, 380, 320 | 0.6, 0.6, 0.55 |
| Fan | 260 | 0.6 |
| Slot | 300 | 0.6 |
| Feather bend (`b_cov`, `b_sec`, `b_pri`) | 160, 110, 80 | 0.45, 0.35, 0.3 |

The feather bends are under-damped, so they overshoot and settle. The pose vectors `REST`, `WINDUP` and `STROKE` are
in `skyrider_v6.py`.

**Beats:**

| Beat | What happens |
|---|---|
| **Cruise** | Period 0.95 s. Downstroke: the wing extends, pronates −0.40, fans +0.25, and the tips load up. Upstroke: elbow flex 0.75, wrist flex 0.95, slots open 0.9. |
| **Bank** | The inside wing's shoulder elevation drops 0.35·bank, and the tip twist is 0.25·bank. |
| **Gust** | Wind-up (0.2 s): folded up and back. Power stroke (0.18 s): extended, fanned 1.35, tips loaded. |
| **Summon** (0 → 0.4 s) | 8 gather ribbons spiral in from about 8 studs onto spar points, then the parts reveal in order:<br>• skeleton (spar plus spine) −0.10 → 0.08<br>• body 0.02 → 0.24<br>• membrane 0.06 → 0.30<br>• coverts 0.12 → 0.32<br>• secondaries 0.16 → 0.36<br>• primaries 0.20 → 0.40<br>In Roblox, tween each layer's Transparency 1 → its base value. |
| **Hit wobble** (about 0.5 s) | The struck wing's shoulder elevation goes −0.7, the other +0.45, damped. Then a velocity kick into every degree of freedom, and a stutter that decays over τ 0.17 s: joints `f_e…tw_w` ± 0.22 at 9 Hz, feather bends ± 0.55 at 11 Hz. The glow flickers ×(1 ± 0.3), and the PointLight adds +1500·hitw. The rider throws the free left hand out (−0.85, −0.35, +0.95) for 0.75 s. |
| **Low mana** | Amplitude ×(1 − 0.45·thin) × (1 − 0.35·thin·ragged), where ragged = an uneven 5.1 Hz modulation. A 17 rad/s per-wing tremor on the joints. A dim-and-flicker of 1 − thin·(0.15 + 0.35·hash(37t, 23t)). The primaries' fray rises by 0.7·thin. 5 wisps peel off the primary tips. |
| **Dismount** | It breaks from the tips inward over 0.5 s: primaries 0–0.3, secondaries 0.1–0.45, coverts 0.22–0.6, membrane 0.3–0.75, body 0.45–1.0 (fractions of 0.5 s). 18 wisps are released from the feather tips. Each is a Trail on a detached attachment that keeps 25 % of the bird's velocity, rises at 1.1 studs/s and curls at 8 rad/s, with a 0.9 s lifetime. The rider drops (v5). |

## 2. Cyclone: the ribbon budget and the scrolling-texture replacement

**In Blender:** 72 thick `blade` ribbons (12 of them flung), plus 10 flare ribbons and 12 streaks at the top, a dim
core body, the glare, a 6-ribbon base disc, the ground ring, ring pulses and the floor debris.

**In Roblox, the ribbon meshes replace the ribbons:**

| Layer | In game | Notes |
|---|---|---|
| Funnel ribbons | **18 ribbon MeshParts** | 3 pre-modelled twisted-strip variants (thin, wide, wide-cupped), each a 1.2–3.4 rad arc of helix with ±0.9 rad tilt. They sit in 3 height tiers × 6 on spinning invisible hubs, 0.55–1.6 × the funnel spin. Each strip's radius follows R(z) = 2.6 + 5.4 (z/H)^0.85 + 1.4 sin(π z/H) studs (H ≈ 30), and it is scaled per instance. |
| Ribbon texture | **One scrolling texture** | A white-hot centre line, glowing teal edges and an alpha breakup noise, on a SurfaceAppearance/Texture. `OffsetStudsU` scrolls it along the strip at 1.5–3 studs/s, so the ribbon reads as flowing air while the hub spins it round. LightEmission comes from the texture brightness. |
| Flung blades | **6 Beams** | Width 3–5, CurveSize0/1 for the arc, TextureSpeed 1.2, scrolling the same texture. |
| Top flare and streaks | **6 Beams** | Short Lifetime, re-aimed each 0.2 s. |
| Core glare | **1 Beam** (vertical, FaceCamera) plus a white core part | Transparency 0.2. |
| Base disc | **1 flat ribbon MeshPart** | Spinning, with the same texture. |
| Ground ring | **1 ring MeshPart** | Scaled 3 → 18 studs. |
| Pulses | **1 ring MeshPart** | Re-used for each juggle hit. |
| Floor | **3 ParticleEmitters** | Rocks 17/s, pale sparks 17/s, dust billow 8/s. |
| First person | **A ScreenGui ImageLabel** | A white radial edge vignette: ImageTransparency = 1 − 0.7·strength·(0.55 + 0.45·surge), a ±15 % flicker at 19 Hz. In Blender it is a 5×48 annulus at 0.6 studs in front of the camera, alpha ramped to the edges. |

**Budget:** 18 + 1 + 1 + 1 = 21 MeshParts, 13 Beams, 3 emitters and 1 PointLight. That is down from 72 + 22 ribbons. The
ribbon count can drop to 12 strips on low settings.

## 3. Point lights: effects light the stage

Every light is a PointLight with Color (140, 255, 235) and Shadows off. In Blender it is an aqua point light
(0.55, 1.0, 0.92).

**Conversion:** Blender W → Roblox Brightness ≈ W / 600 (clamped at 6), with Range ≈ 8–30 studs as listed.

**Flicker:** × (1 − f + f·sin(29t)·sin(17.7t + 1.3)), with f = 0.15 unless noted.

| Piece | Where | Blender energy (W) | Roblox |
|---|---|---|---|
| Wind Blade | On the newest blade | 140 at the swirl → 300 in flight, +300 on the pierce (τ 0.07 s) | Range 8 |
| Cross-Slash | Chest, then the X centre | Charge 380, dash 700, X flash 2600 (τ 0.22 s), dome tail 260 | Range 10 → 18 at the X |
| Updraft | Under the feet | (120 + 420·height ratio)·tell, +1100 at the apex (τ 0.16 s) | Range 10 |
| Gust Pad | 1.3 studs over the pad | Idle 150–260, breathing every 1.6 s; step +380 (τ 0.2); launch +1900 (τ 0.25); f = 0.1 | Range 12 |
| Skyrider | Under the chest | (280 + 900·gust wind-up)·tell·body, +1500·hitw (plus the v5 rider fill) | Range 12 |
| Cyclone | On the axis at 0.35 H | 9000 × strength × (1 + 0.5 surge) × the 23 Hz flicker | Range 30, Brightness 5 |

## 4. Stage 2: what each piece adds, and how to emit it

**Wind Blade.** The leanest piece.
- **Per shot:** 15 meshes (lens, core, rim, 2 accent arcs, wake, 2 wake spirals, ripple ring, impact ring, 3 scratch
  decals, and the cut core plus glow). There are 5 pooled sets.
- **Particles per shot:** 14 (dust 5, speck 1, chips 2, sparks 3, release puffs 3).
- **Light:** 1, shared.
- **Arc:** a touch larger. The right hand throws R 1.55 / span 122° / tilt 62°; the left R 1.40 / span 136° /
  tilt 48°.
- **Cut line:** two Beams across the dummy along the blade span, 3.2 → 4.2 studs long. They flash in 0.012 s and fade
  over τ 0.09 s.
- **First-person micro-shake:** pitch 0.010 rad and roll ±0.006 rad per shot, decaying over τ 0.035 s.

**Cross-Slash Dash.**
- **Takeoff vapor ring:** 2 rings around the dash axis, 0.7 → 3.6 studs over 0.42 s, plus 22 puffs.
- **Snap trails:** a Trail on each wrist (core plus glow, 0.11–0.15 s lifetime) from takeoff to arrival.
- **Arrival speed ramp:**

  | Stretch | Speed |
  |---|---|
  | The dash | 0.6× |
  | Into the X | 0.2× |
  | The hit-stop (0.1 s) | 0.1× |
  | The release (0.22 s) | 1.3× |
  | After | 0.8× |

  This is camera time only. Gameplay keeps its 2-frame hit-stop.
- **Vapor shockwave dome:** a hemisphere MeshPart (0.62 high-to-wide), radius 1.4 → 7.6 studs over 1.15 s. It has a
  lobed alpha texture (open crown, streaks scrolling up), Transparency 0.6 → 1, and a ground ring on its foot.
- **First person:**
  - FOV kick +30 % at takeoff, a 10 % zoom jolt and a 0.07 shake on the X;
  - 16 radial streaks: Beams parented to the camera at 1.1–2.6 studs radius, rushing past at 46 studs/s.

**Updraft.**
- **The tell grows with height:** glow ×(0.72 + 0.5·h) and presence ×(0.75 + 0.25·h), where h = height / apex height.
  The disc reaches 0.8 → 1.15 × wider.
- **Apex flash:**
  - a waist ring (core plus glow), 1.3 → 2.8 studs over 0.33 s;
  - an 18-spark pop;
  - the helix and disc surge ×1.9 (τ 0.16 s).

**Gust Pad.**
- **Idle pulse:** a ring breathing out from the centre every 1.6 s.
- **Rising glints:** in the shimmer column, 9 per second, rising at 1.2–2.4 studs/s, lifetime 1.8–3 s.
- **Step ripple:** 2 rings, 0.6 s.
- **Launch:**
  - a second vapor ring, 3 → 13.5 studs, rising 1.6 → 2.8 studs over 0.9 s;
  - +16 chips and an 18-puff skirt;
  - 8 ribbons peeling up the column (Trails on attachments driven up a widening helix to 19 studs over 0.9 s).

**Skyrider.** See §1. Gather ribbons and wisps are Trails on scripted attachments.

**Cyclone.** See §2.

## 5. Blender-only stand-ins

- The subdivided alpha surfaces (membranes, the dome, shells) become textured MeshParts with baked alpha noise.
- The per-vertex fade attributes become Transparency NumberSequences or the texture's alpha.
- EEVEE bloom (threshold 0.9, strength 0.42) becomes the Roblox Bloom effect (Intensity 0.4, Threshold 0.9).
- The pre-simulated particles become ParticleEmitter bursts at the same counts.
- The 240 Hz WingSim becomes the client spring script in §1.
