# 6. Cyclone (Ultimate): handoff spec section

Source: `blender_scripts/zephyr/spring/cyclone_bl.py`, the showcase build. Every number here is provisional look-dev, not
tuning.

**Shared trigger beat:** t = 0 is the Ultimate key press. All times are in seconds from the press.

**Spin:** COUNTER-CLOCKWISE seen from above, for everything: the funnel, every air layer, the debris, the ground ring, the
caster's arms in third AND first person, and the dummies' orbit. In Roblox (Y up) that is the angle increasing from +X
toward -Z, the same sense as `ZephyrFX.CyclonePullVelocity`'s `around`.

**Size (showcase):**

| Measure | Value |
|---|---|
| Crosshair spot (funnel foot) | 20 studs in front of the caster |
| Funnel height | 40 studs (touchdown overshoot 43.6; ropes out to about 45 while thinning) |
| Foot radius | 2.6 studs |
| Top radius | 13.5 studs |
| Profile | r(z) = 2.6 + 10.9 (z/40)^1.7 |
| Axis | sways about 2 studs at the top, fixed at the foot |

The game's look (`Tuning.Cyclone.Scale` 2.08, about 52 studs tall) can scale this uniformly.

## Beats and the game's phases

| t (s) | Beat | Game phase |
|---|---|---|
| -0.35 – 0.00 | ready | |
| 0.00 – 0.28 | the summon: weight drops, the torso coils clockwise (the counter-move), the arms sweep low; a dust devil seeds at the crosshair (2 studs tall, dust kicked up) | FORM begins |
| 0.28 – 1.50 | the corkscrew climb: both wrists circle counter-clockwise, rising low to overhead and accelerating; the funnel's height and spin build with them | FORM (`FormTime` 1.2) |
| 1.50 – 1.85 | touchdown: full height with a 9% overshoot and settle (damped spring), a glow swell, an open dust arc and a green arc thrown out along the floor (r 3 → 16), a 60-puff dust burst plus a splash of 26 leaves and 18 petals along the floor, a radial floor shove that whips the grass outward, a soft flash, and a short camera jolt (showcase only; in game a small CameraShake for players within ~40 studs) | ACTIVE starts (`TouchdownKick`) |
| 1.85 – 4.00 | HOLD, the channel: the pull and the juggle | ACTIVE (`ActiveTime` 4; the showcase holds 2.5 s, the game loops the channel) |
| 4.00 – 4.28 | the draw-back: anticipation for the thrust | |
| 4.28 – 4.50 | the thrust: a twisting gust from the palms reaches the wall at 4.38 (the release); the funnel surges; open shock arcs on the floor and round the waist; the dummies are dropped | |
| 4.50 – 6.30 | the slow thinning: the foot lifts off the floor (to 16 studs), the funnel loosens (+40% radius), rises (+14%), slows (spin down 72%), frays and fades; debris rains out | UNWIND (`UnwindTime` 0.5; proposal: 1.5–1.8 s for the look only, nothing is caught in it) |
| 6.30 – 6.70 | the last wisps | |

## Meshes

The air is built from Beams and Trails (the next three sections), not MeshParts, except these:

| Mesh | Triangles | Use |
|---|---|---|
| Ground-ring disc (optional) | ~512 (128-segment annulus, r 0.35–1.0) | Replaces the 6 ground-ring Beams on low Graphics Quality: one flat MeshPart for the green spiral, one for the dust spiral, rotating counter-clockwise at 0.3x the funnel spin |
| Shock-arc annulus | ~256 (64 segments) | An open 310° arc texture. Size is tweened (touchdown r 3 → 16 over 0.75 s; release r 6 → 22 over 0.85 s) and Transparency 0.4 → 1 (ease-out). Two copies on the floor (dust + green), one round the waist at z 9 for the release |
| Grass tufts | ~40 each | 72 short tufts with a few flowers round the foot (r ≤ 17), 12 at the caster's feet. Tweened lean toward the funnel and round it (counter-clockwise); Roblox terrain grass cannot be bent by VFX |

**Low-quality alternative for the funnel shells.** A pre-built helical-strip MeshPart per shell:
- outer about 1,300 triangles; mid about 1,700; inner about 2,200; core about 840;
- it rotates by CFrame, and Size.Y follows the funnel height;
- it loses the streak scroll and the form light, so use it only at Graphics Quality ≤ 3.

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| `zs_air_strip` | 512×128 RGBA | The `mat_air` look baked for Beams:<br>• a soft, noisy edge across the width, and streak fibres along the length;<br>• colour: shadow `#1F8A4C` → base `#4ADE6B` → light `#A2EAA6` across, sparse accent flecks `#E9F7A4` on the lit edge, 14% desaturated toward `#CFE2D6`;<br>• a thin mint core thread `#EFFFE6` with gaps;<br>• the tail-fray version (fibres only) in the right quarter.<br>Beam.Color stays near white; the form light comes from Color (below). |
| `zs_air_strip_pale` | 512×128 | The calm core's palette: `#8ED9A2` → `#BDEFC4` → `#E2F8E0`, core `#EFFFE6` |
| `zs_dust_strip` | 512×128 | The same build in the dust palette: `#B8AE9E` → `#D9D1C4` → `#EEE8DE`; no mint core |
| `zs_hairline` | 256×16 | A thin pale thread with a soft falloff |
| `zs_arc310` | 512×512 | An open 310° annulus that fades along its tail (shock arcs) |
| `zs_ring_spiral` | 1024×1024 | Three open spirals (ground-ring disc, low Graphics Quality) |
| `leaf_tumble` | 256×256, 4×4 frames | A tumbling leaf with a lighter midrib. Three tints, as separate emitters: `#34A45A`, `#5FD46E`, `#8FE07A` |
| `petal_tumble` | 128×128, 4×4 frames | Tints `#F4F3E6`, `#E8F6DC` |
| `twig` | 64×16 | `#82604A` |
| `grass_bit` | 64×16 | `#78A86A` |
| `fluff` | 64×64 | Seed pappus: 9 filaments, `#F6FBF2` |
| `pollen` | 16×16 dot | `#FBF6CF` |
| `dust_puff` | 128×128 soft | `#D9D1C4`. LightInfluence 1: a lit veil, never a dark cloud |
| `mist` | 128×64 soft | `#E4F4E6`, stretched along velocity |

## Beams and Trails

All FaceCamera off unless noted. LightEmission ≤ 0.3 on every body (bible §2, NOT NEON); the core thread lives in the
texture, not in additive light.

**Funnel shells.** Each shell is one long helix, wound so its turns overlap (width = 0.85–0.9× its pitch). That makes a
continuous body of air with irregular horizontal striations. Lay each strip in the cone's surface by orienting its
attachments; the upper edge is the lit one.

| Shell | Radius | Turns | Spin (rad/s) | Body alpha | Beams (4 per turn) |
|---|---|---|---|---|---|
| Outer | 1.00 R | 8–9 | 0.30 x 6.4 = 1.9 | 0.34 | 36 |
| Mid | 0.76 R | 10.5–11.5 | 0.62 x 6.4 = 4.0 | 0.28 | 46 |
| Inner | 0.50 R | 13–15 | 6.4 (367°/s) | 0.30 | 60 |
| Calm core (pale) | 0.22 R | 5–5.5 | 0.15 x 6.4 = 1.0 | 0.40 | 22 |
| Veil (heat-haze stand-in) | 1.36 R | 1.1–1.3 | 0.25 x 6.4 | 0.13 | 5 |

Shell parameters:
- **Beams:** 4 per 360°, CurveSize ≈ 0.55 × the arc's radius, Segments 10.
- **TextureSpeed:**
  - outer 1.3 (the kit's scroll × 4.5 studs/s);
  - mid 1.7;
  - inner 2.4;
  - core 0.45 (calm).
- **LightEmission:** 0.2. The core's thread is baked in the texture.
- **Width:** pitch × (0.85–0.9) × (1 ± 0.4 slow noise). The pitch is 40 / (turns × k) studs, where k = (40 / height)^0.5. A short young funnel winds tighter, and the spiral stretches upward as the funnel rises.
- **Form light:** Color per Beam = lerp(shadow tint 0.78, light tint 1.0, l), with l = 0.5 + 0.42 cos(the segment's azimuth − the key's azimuth) + 0.14 (z/H − 0.5). That is the Blender `l` attribute.
- **Opacity:** Transparency NumberSequence 1 → body → body → 1 along each Beam.
- **Front/back:** the near wall at 1.0×, the far wall at 0.8×.
- **Soft rim:** where a segment is seen edge-on (the funnel's silhouette) its opacity drops to 0.45×, rising to 1× by
  the time the segment faces the camera at ~55°. In Roblox: per-Beam Transparency from the dot of the segment's outward
  normal with the camera direction (client-side, cheap), or accept harder slat edges on low Graphics Quality.
- **Kit OPACITY / VIBRANCE (developer, 2026-10-06):** every "body alpha" in this section is multiplied by 1.69 on
  screen (e.g. outer 0.34 → 0.57 opacity, Transparency ≈ 0.43), and every colour gets saturation × 1.69 after the 24%
  grey-mint desaturation (outer shell 30%). Bake both into the strip textures.
- **Form light strength:** the shells' `l` term is scaled 0.75 (lit_k), so the far side reaches the shadow green
  `#1F8A4C` and the key side the light body `#A2EAA6`; Beam.Color per segment spans tint 0.70 → 1.0.

**The funnel's whole rotation.** All attachments of a shell sit in one invisible part rotated about the axis each frame,
so a shell turns as one piece. The spin follows the arms through the climb (spin = ω_arms / 15), holds at 1, surges ×1.35
at the release (decay 0.22 s), and slows by 72% through the thinning. Height H(t) follows the arms' climb (up 40 studs
by 1.50, with the 9% overshoot). Radii scale (0.5 + 0.5 g)(1 + 0.4 thinning).

**Travelling arcs (16).** The identity's open spirals: each 160–320°, never closed. Each is an attachment that orbits the
axis at 0.55–1.1x spin and climbs 0.18–0.30 H per turn for 1.1–1.7 s, then respawns at a new height and angle.

| Kind | Count | Trail Width | Lifetime | Body alpha |
|---|---|---|---|---|
| Sheets | 8 | 0.30–0.42 × the funnel radius there (tapered) | 0.45 s | 0.36 |
| Hairlines | 8 | 0.10–0.16 studs (FaceCamera on), widening 1.6× toward the top | 0.55 s | 0.55 |

Both use LightEmission 0.25.

**Other air shapes:**

| Shape | Count | Spec |
|---|---|---|
| Debris skirt round the foot | 6 Beams (3 dust, 3 green) | Spirals r 2.9 → 7.5, z 0.15 → 5.5, about 0.85 turn each (3 Beams per spiral). Width 1.6 → 3.2 (dust 1.25×). Spin 0.9× |
| Ground ring: a three-arm pinwheel | 6 Beams, flat (3 green + 3 dust, interleaved 60° apart) | Each arm is an open spiral of 225–255° at z 0.06–0.16, running from its head at r 4.2–4.8 (the inner, counter-clockwise-most end, where the inflowing air goes) out to its tail at r 14.5–16 (dust +0.5 / +0.8), trailing clockwise like the floor's inflow streamlines. Width grows head → tail 0.5 → 1.3 × (dust 2.2, green 1.5 × 1.25). Alpha: green 0.25 (core width 0.06, LightEmission ≤ 0.2), dust 0.60. Bursts out 30% at touchdown (sin pulse 0.55 s). Spin 0.3×. The earlier nested arcs (dev1–8) overlapped into what read as closed rings; the pinwheel reads as an open spiral at any distance |
| Inflow streaks | 8 Trails (FaceCamera on) | The field's own floor streamlines: inward spirals from r 14–19 to r 3.6 at z 0.5–2.6. Each a 0.5-length window sliding inward over 1.1–1.6 s, at a new angle every cycle. Width 0.35–0.6, alpha 0.5, LightEmission 0.25. On from 0.9 s, off after the release |
| Seed swirl | 3 small Beams | At the crosshair, 0.06–1.15 s: r 0.5 → 2.1, rising 0.4 → 3 studs, 9 rad/s |
| Hand trails | 2 Trails + 2 hairline Trails | Wrist attachments, Lifetime 0.5 s (0.65 s in first person). Width 0.42 → 0.06 (×0.85 in first person). The hairlines are 0.06 wide, offset 0.22 outward. On through the climb (they draw the corkscrew), faint in the channel |
| Release gust | 3 Trails + 2 hairlines | On attachments thrown from the palms at 4.30 to the funnel's wall at z 9, arriving 4.38. A twisting path: 1.4 turns, radius 0.55 (hairlines 0.9), width 0.95 → 0.35 |

**Light:** a PointLight flash (mint `#EBFFE6`, Range about 18):
- at touchdown, z 2.5: about 220 W-equivalent, Brightness about 1.5;
- at the release, z 8: about 360 W, Brightness about 2.5;
- rise 0.04 s, decay tau 0.12–0.14 s. Neither may white out a dummy.

## Particle emitters

The bible's debris must ride the funnel's air. Roblox particles cannot follow a flow field, so:
- **The wall:** LockedToPart emitters on three invisible parts spinning about the axis at 0.45x, 0.7x and 1.0x the funnel
  spin. Debris rides at different speeds and rises with Acceleration.
- **The floor inflow:** a non-locked ring emitter with ShapeInOut Inward.

Peak live count in the showcase: about 880 particles (t = 4.5); about 475 at touchdown (with the splash).

| Emitter | Rate / burst | Lifetime | Sprite, size | Motion |
|---|---|---|---|---|
| Leaves, wall (3 tints) | 60/s in the hold, 25/s in the climb | 3–5 s | `leaf_tumble`, 0.5–0.8 studs (15% hero leaves 0.85–1.0) | Cylinder surface at the wall radius. Acceleration +9 up, Drag 1.5, RotSpeed ±200–500, flipbook 12 fps |
| Petals, wall | 38/s | 3–4.8 s | `petal_tumble`, 0.25–0.43 | As the leaves, Drag 2 |
| Twigs | 9/s | 3–4.5 s | `twig`, 0.7–1.1 | Acceleration +4, Drag 0.5: heavy, lags and overshoots |
| Grass torn up | 25/s from the patch round the foot (r 2.5–11) | 2.5–4 s | `grass_bit`, 0.4–0.6 | Speed 4–8 up, then locked to the 1.0x part |
| Fluff | 9/s | 3–4.5 s | `fluff`, 0.2–0.33 | Drag 4, slow |
| Pollen | 50/s in the funnel volume | 1.2–2.2 s | `pollen`, 0.05–0.09 | LightEmission 0.3 |
| Mist | 15/s on the wall | 0.7–1.3 s | `mist`, 1.8–3.0 | VelocityParallel, LightEmission 0.3 |
| Dust ring | 50/s, r 4.5–13 | 1.4–2.4 s | `dust_puff`, 1.5 → 3.4 (grow) | Transparency 0.78 → 1, LightInfluence 1 |
| Dust skirt | 12/s, r 2.5–5 | 1.0–1.8 s | `dust_puff` | Rising |
| Floor inflow (leaves, petals) | 20/s, ring r 4–18 | until caught | Leaf, petal | Inward 6–9 studs/s, skimming at z 0.3–0.6 |
| Seed dust | 30 over 0.08–0.5 s | 0.9–1.6 s | `dust_puff` | At the crosshair |
| Touchdown dust | burst 60 at 1.50 | 1.0–1.8 s | `dust_puff`, 1.5–2.6 | Outward 12–20, tangential 8 |
| Touchdown splash | burst 26 leaves + 18 petals at 1.50 from r 3–6 | 1.6–2.6 s | `leaf_tumble`, `petal_tumble` | Outward 10–17, tangential 7, up 2–5 |
| Release | burst: 24 leaves, 18 petals, 6 twigs off the wall (outward 10–16, tangential 10), 40 floor dust (outward 12–18) | 1.8–2.8 s | | |
| Dummy landings | burst 12 dust each | 0.8–1.3 s | | |
| Caster swirl | 16 leaves, 12 petals, 8 fluff, 30 pollen, emitted 0.10–1.25 s | | | Spiral up round the caster's arms (a small counter-clockwise vortex) |

**Graphics Quality / Reduce Enemy VFX** (what drops first):
1. Pollen and mist.
2. The fluff and twig emitters; the mid shell and the veil.
3. Halve the leaf, petal and grass rates; the 8 hairline arcs.
4. At Graphics Quality ≤ 2: one leaf tint at 30%, the dust ring at 50%, the bursts at 50%, the outer + inner shells as
   MeshParts, 4 sheet arcs.

Never dropped: the outer shell, the inner shell, the calm core, the ground ring and the touchdown dust burst. They are the
silhouette and the "it landed" read.

## Animation clips

Both clips share the trigger beat and the key times.

### Third person: `Cyclone_Cast`

| t (s) | Key | Pose |
|---|---|---|
| -0.06 | ready | hip 1.94, hands at the sides |
| 0.28 | the dip | **Anticipation, the counter-move:**<br>• hip drops to 1.62 (from 1.97);<br>• spine pitches 0.26 forward;<br>• the chest coils CLOCKWISE (spine yaw -0.10, pelvis yaw -0.14);<br>• head -0.20;<br>• the hands sweep low and in front. |
| 0.28 – 1.50 | the corkscrew climb (procedural) | See below |
| 1.50 | the top | Risen (hip 2.04), the chest arched (spine -0.14), head up -0.45, shrug 0.14 |
| 1.80 | channel settle | `back` ease (follow-through) |
| 1.80 – 4.00 | HOLD | The channel circle (r 0.40, 3.2 rad/s) overhead, a 0.022-stud tremble at 13 Hz. **Loop this window for the game's ActiveTime** (`ZephyrFX.CycloneLoopClock`). |
| 4.28 | the draw-back | Weight back (hip y -0.22), chest open (spine -0.20), hands drawn to the ears, elbows back and down |
| 4.40 | the thrust | `snap` ease over 0.12 s: both palms drive at the funnel, the body lunges after them (hip y +0.42, spine +0.30) |
| 4.75 | follow-through | `back` ease |
| 5.60 | recover | |
| 6.60 | rest | |

**The corkscrew climb (0.28 – 1.50):**

Both wrists circle counter-clockwise round vertical axes in front of the shoulders, in phase.
- **Path:** an ellipse, 1.30r side to side × 0.62r front to back, so a wrist never folds onto its own shoulder.
- **Radius:** r 0.50 → 0.95 (tight → wide).
- **Height:** centre z 2.55 (hips) → 5.30 (overhead).
- **Forward:** centre y 1.45, held forward until the hands pass the head, then 0.95.
- **Hand spacing:** dx ±0.55 → ±0.95.
- **Start:** the angle starts at 0.60 rad (front-right).
- **Speed:** angular speed ω = 2.6 + 12.4 s^1.5 rad/s, about 1.45 turns in all.
- **The rise:** z follows (1 − cos(π s^1.3)) / 2, so it starts slow, accelerates, and arrives soft.

The body winds into it:
- **Spine:** spine yaw = −A cos θ.
- **Pelvis:** pelvis yaw = −0.45 A cos(θ + 0.45) (the hips lead).
- **Weight:** hip x = 0.17 (A / 0.48) cos(θ + 0.30) (the weight swings with the hands).
- **Amplitude:** A 0.18 → 0.48 rad.
- **Head:** counter-turns 65% so it keeps on the funnel; it settles last.

Elbow pole: by the arm's elevation (down when low or level, outward overhead), a little back, minus 0.25× the circle's
tangent, so the forearms trail the wrists. Wrist targets are clamped to 95% of the reach: an IK elbow on a fully straight
arm flips.

### First person: `Cyclone_Viewmodel`

The same keys and timing, the same counter-clockwise sense:
- **Circle:** carried forward (centre y 1.80 → 1.70); each hand circles a vertical axis just inside its own shoulder
  (dx ±1.00 → ±1.15, r 0.42 → 0.80, round), so the arms come in diagonally from the lower corners and the two hands
  frame the funnel between them; the wrist trails draw the corkscrew on screen.
- **Channel:** the channel circle sits above the eye (z 5.35), so the spin is seen from below.
- **Camera pitch keys:** -0.44 at the dip; 0 at 0.95; +0.34 at touchdown; +0.24 in the hold; 0 at the thrust.
- **Camera roll:** a 0.03-rad roll with the hands during the climb.
- **Head:** cancels the body's winding, so the camera stays steady.

## Blender stand-ins and their Roblox equivalents

| Blender (showcase) | Roblox |
|---|---|
| `mat_air` / `mat_air2` ribbons (alpha-blended emission, procedural 4D noise streaks scrolling at 4.5 × scroll studs/s) | Beams / Trails with `zs_air_strip`, TextureSpeed, LightEmission 0.2, Transparency NumberSequence |
| `mat_air2`'s per-vertex light term `l` (local override) | Beam.Color per segment from the segment's azimuth to the key |
| `zk.Particles` in one flow field (Rankine swirl, floor inflow, corner updraft, wall inflow, top outflow, the caster's arm vortex, the thrust's gust, the release burst) | LockedToPart emitters on three spinning parts + Acceleration / Drag; a separate inward floor emitter |
| `zk.Grass` (spring-bent blades) | A few tuft MeshParts tweened inward and counter-clockwise; terrain grass cannot be bent |
| `zk.Cloth` (scarf, hair) | Character cloth, or a scarf accessory with a simple spring bone |
| The dummies' juggle simulation (the game's `CyclonePullVelocity` with EyeRadius 4.6, OrbitSpeed 14, JuggleHeight 8 ± 2.2, period 1.1 s; dropped, not flung, at the release: horizontal speed capped at 6 + 2.5 outward) | The existing server/client pull. The showcase's EyeRadius is 4.6 against the game's 3, so the dummies orbit just outside the visible wall |
| `zk.Flash` point lights | PointLight tweened |
| EEVEE alpha blending, bloom 1.25 / 0.14, PBR Neutral | Roblox transparency sorting; Bloom post (keep Threshold high); ColorCorrection |

## Roblox limitations that forced compromises

- **Particles cannot ride a custom flow field.** The spinning LockedToPart parts approximate debris riding the air; three
  spin rates restore "debris at different speeds". Without them, debris orbits rigidly.
- **Transparent Beams sort per object, not per pixel.** With about 180 beams in a cone, expect occasional pops in sort
  order. Keep the far wall fainter (the 0.8× back-wall factor) so a mis-sort is a minor brightness change.
- **No per-vertex alpha on MeshParts.** The low-quality MeshPart shells lose the soft head/tail and the form light.
- **First person.** The R15 arm blocks at FOV 70 fill the lower corners whenever the hands are raised in front. A
  ViewportFrame viewmodel layer with its own FOV (about 55) or 0.8× arms would let the spiral read better. The showcase
  keeps the honest rig.
- **The unwind.** The game's 0.5 s UNWIND is shorter than this look's 1.8 s slow thinning. The look can outlive the
  gameplay (nothing is caught in it).
