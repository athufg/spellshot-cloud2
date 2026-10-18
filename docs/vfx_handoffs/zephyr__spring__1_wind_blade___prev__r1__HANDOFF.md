# Wind Blade (M1): Roblox handoff (Zephyr spring pass, 2026-10-06)

The Blender source is `blender_scripts/zephyr/spring/wind_blade_bl.py`. Every number here is provisional: the
showcase was built against `ZephyrFX.Tuning.WindBlade` (Speed 240 studs/s, Range 80, Pierce 3, Trigger 0.06 s) and an
8-shots-a-second hold (0.125 s between shots). None of it is final tuning.

**Shared trigger beat:** t = 0 is the M1 press. A shot's **release is at press + 0.06 s** (the `Trigger`). Both
animation layers and every effect key off that release, and the times below are given from it (τ = t − release)
unless they say otherwise.

## Exact per-shot counts (the leanest effect in the kit)

| Layer | Per shot | Notes |
|---|---|---|
| Crescent body | **1** | the only element that never drops |
| Secondary crescent | **1** | thin, lagging, offset back; at the first body it **becomes the splash** (no extra mesh) |
| Hairlines | **3** | the hand swirl, then two flanking the blade and one inside it; at the hits they **become the impact arches** (no extra beams) |
| Trail | **1** | short and tapering, ~6.4 studs at full speed |
| **Air elements in total** | **6** | 1 body + 1 secondary + 3 hairlines + 1 trail. Nothing else is spawned: the impact's air is the secondary and the hairlines re-shaped |
| Leaf fragments | **3 or 4 (≤ 6)** | 1 shed in the wake, 2 out of the back of the first body, 1 out of the second body on every other shot |
| Puff particles | **8 (≤ 8)** | first hit: 4 dust + 2 glints; second hit: 2 dust |
| Light | **1 flash** | first hit only |

At 8 shots a second, about 3 shots are alive at once (in flight or splashing): about 18 air elements, about 25
leaves, 10 dust sprites and 4 glints at the peak. Over the hero clip the totals were 25 shots, 50 hits, 88 leaves,
150 dust and 50 glints.

(The earlier build added a separate splash-arc mesh per hit, 1–2 more air elements per shot. It was cut in this
pass: the lead's budget is 1 body + 1 secondary + 2–3 hairlines + 1 trail per shot.)

## Meshes (rough budgets)

| Mesh | Size | Budget | Behaviour |
|---|---|---|---|
| **Crescent band** (the body) | 26 × 3 verts, ~100 tris; horn to horn 3.45 studs, max width 0.98 studs | ~100 tris | see below |
| Secondary crescent band | 22 × 3 verts, 1.10 × the span, 0.52 × the width | ~84 tris | can be the same mesh scaled; for the splash, a second pose of it (or a bone chain, see below) |

**The crescent band in detail:**
- **Shape.** A 3D crescent in the blade's local frame:
  - an arc of 128°, radius 1.92 studs;
  - the horns curl back 0.50 studs toward the concave side (as seen from behind);
  - the horns sweep 1.00 stud back along the flight (as seen from the side);
  - the band leans 46° between "back along the flight" and "inward", so it has visible width from behind, from the
    side and from above.
- **Tilt.** Steep: the right hand's crescent is "/" at 62° and the left hand's is "\" (seen from behind). A flat
  crescent goes edge-on from the side.

The trail, the hairlines and the lingering wisps need no meshes: they are Trails and Beams (below).

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| `wb_body` | 256 × 64 | **Opaque on the leading edge**, feathering to transparent on the trailing edge. The colour runs pale mint `#EAFFEF` (a thin stripe at the leading edge; a 10-RGB-cooler core than the kit's `#EFFFE6`, see NOTES.md) → `#A2EAA6` → `#4ADE6B` → `#1F8A4C` (trailing). Streak noise along the length, frayed fibres over the last 30% (the upper horn). |
| `wb_streak` | 128 × 32 | Soft streak noise with alpha falling to 0 at both long edges. Used by the trail, the hairlines and the wisps; tiles along U. |
| `leaf_tumble` | 4 × 4 flipbook, 256 px (64 px cells) | A tumbling leaf in three tints: `#34A45A`, `#5FD46E`, `#8FE07A`. **No pure-accent leaves** (they read as yellow dots). |
| `soft_dot` | 64 px | Radial falloff. Used by dust (lit) and glints (emissive). |

About the `wb_body` texture:
- In Blender, the crisp leading edge comes from cutting the geometry inside `mat_air`'s opaque zone (see NOTES.md).
- In Roblox it is simply a one-sided alpha ramp.
- The pale core is baked into the texture as a stripe. It is **not** a second additive beam: wind is not neon.

## Beams and trails (per shot)

| Element | Roblox | Settings |
|---|---|---|
| **Crescent body** | the crescent MeshPart, or 2 Beams (apex → each horn, `CurveSize0/1` bowing them back, `Width0` 0.98 → `Width1` 0, `FaceCamera` false, `Segments` 12) | `wb_body`; `LightEmission` 0.25, `LightInfluence` 0; `TextureSpeed` ~1 (streaks run horn to horn); `Transparency` 0.25 at full fade. **Build:** scale 0.40 → 1 and fade 0 → 1 over τ −0.035 … +0.03, formed at the hand. **Squash and stretch** along the flight: 0.72 while forming → 1.28 at τ +0.035 → 1.0 by +0.205. Each body hit dips the stretch by × (1 − 0.38) over ±0.018 s, so the blade flattens and the horns flare as it punches through. The cross-scale is 1/√stretch. **Thin:** from 26 to 88 studs of flight (τ 0.11 … 0.37 s) it fades out, grows × 1.3 and frays. |
| **Secondary** | the same, thinner | `Transparency` 0.45. Offset 0.36 studs back along the flight and 0.10 toward the concave side; its stretch lags 0.015 s behind the body's. |
| **Secondary → the splash** (the impact's air) | the same MeshPart, re-posed: easiest as a 12-bone chain (or 2 Beams with animated `CurveSize`) | At the first body hit the secondary stops riding the blade and **catches on the body**: over 0.05 s it morphs (out-ease) into an OPEN band arc around the entry point, perpendicular to the flight but leaning 40° back over the top. Over 0.24 s (out-ease) its span opens 128° → 170°, its radius grows 1.15 → 2.2 studs (the far horn 22 % tighter: a spiral, never a ring), its width thins 0.62 → 0.26 studs, and it drifts 0.45 studs along the force plus the breeze. `Transparency` → 1 from 0.05 to 0.34 s. Its arc is centred on the blade's convex side, so a right-hand shot splashes upper-left and a left-hand one upper-right: in a stream the splashes never close into a ring (the bottom stays open). |
| **Trail** | a Trail behind the body | `Lifetime` 0.027 s (~6.4 studs at 240 studs/s); `WidthScale` 0.46 → 0 (exponent 1.1); `Transparency` 0.48 → 1; `LightEmission` 0.2; `wb_streak`. Its tail end sits at the hand for the first 0.027 s, then leaves. |
| **Hairlines × 3 (the hand swirl)** | Trails on 3 attachments | `Lifetime` 0.022 s (flanking) or 0.028 s (inner); width 0.058 or 0.048 studs, × 1.5 during the swirl; `Transparency` 0.5; `wb_streak`. **Swirl:** from τ −0.10 to 0 the attachments orbit a point 0.20 studs in front of the palm (where the blade forms, clear of the cuff) at 150 rad/s, radius 1.05 → 0.62 studs (× 0.75 in first person), width × 3 and `Transparency` 0.34, so each trail draws an open ~190° arc around the hand. Right hand clockwise and left counter-clockwise, seen from behind. **Flight:** over τ 0 … 0.022 they blend onto the blade. Two flank it at ±1.45 studs (a gentle helix of 0.15 rad per stud, offset 0.9 rad so they never form a ring) and one runs inside at 0.72 studs. **Peel → the impact arches:** at the first body hit the flanking pair detach (the inner one at the second body). Each becomes a **streamline arching over the body** from its front face to its back (the air parting over it and carrying on): an open 133° arc in the plane of the flight and a direction splayed ± 20–34° from vertical (hairline 0 high and wide toward the blade's side, radius 1.30 → 2.10 studs; hairline 1 lower and tighter the other way, 0.95 → 1.60; hairline 2 over the second body, 0.90 → 1.50). The shape morphs in over 0.06 s, widens over 0.22 s, rolls 0.35 rad downstream and drifts 0.6 studs along the force; width 0.21 → 0.10 studs; `Transparency` 0.28 at birth → 1 from 0.04 to 0.36 s; it frays from the downstream end. In Roblox: a pooled curved Beam per arch (`CurveSize0/1` for the bow), its attachments tweened, since a Trail cannot re-shape its points. |

## Particle emitters

All are `Rate` 0 with `Emit(n)` on events, through the shared emitter helper.

| Emitter | Event | Sprite | Size (studs) | Lifetime | Speed | Other |
|---|---|---|---|---|---|---|
| **Leaf fragments** | `Emit(1)` at τ +0.03 a few studs down the path (the wake); `Emit(2)` at the first hit from the exit (back) side; `Emit(1)` at the second hit on alternate shots | `leaf_tumble` | 0.36–0.6; a heavier 0.54–0.57 one every other shot overshoots and lags | 0.65–1.0 s | wake 26–46 along the flight; hits 16–26 along the force, ± 8 sideways, + 3–8 up | `Drag` 7; `Acceleration` (0, −20, 0) (gravity, fluttering); `RotSpeed` ± 150–500 °/s; `LightInfluence` 1; `LightEmission` 0.1 |
| **Dust puff** | `Emit(4)` at the first hit, `Emit(2)` at the second, at the entry point | `soft_dot` | 0.70–0.90, growing × 2 over life | 0.22–0.32 s | 7 radial (sideways off the body) + 1 back toward the shooter, 1.5 down | `Drag` 6; `Transparency` 0.58 → 1; **lit**: `LightInfluence` 1, `LightEmission` 0 (an emissive mist read as glowing orbs on the dark backdrop, so it was dropped). Short-lived on purpose: longer-lived dust stacked into a rising white column in a stream, which read as smoke |
| **Glints** | `Emit(2)` at the first hit | `soft_dot`, 32 px | 0.06–0.09 | 0.14–0.20 s | 13 radial | `LightEmission` 1; `Orientation` VelocityParallel (stretched); `Drag` 14 |

The flash is a `PointLight`, colour (0.92, 1.0, 0.9), `Range` about 8. Its peak equals 320 W in Blender (about
`Brightness` 3). It rises in 0.012 s, then decays exponentially with tau 0.07 s. It sits 1.5 studs in front of the
hit and 1.3 studs up and to the side: a soft wash, never a hot spot on the dummy.

**Graphics Quality scaling (what drops first):**
1. The glints and the second hit's dust.
2. The inner hairline (and with it the second body's arch).
3. Leaves cut to 1 per shot (the first-hit pair goes to 1, the wake leaf goes).
4. The flanking hairlines (the swirl and the first body's arches go with them).
5. The flash: never below GQ 6, and only for your own hits.

The crescent body, the trail and the secondary (with its splash) never drop: the splash is the impact's read.

**Reduce Enemy VFX:** other players' blades lose the hairlines, leaves, glints and flash, and keep the body, the
trail, the secondary + splash and 2 dust.

## Animation clips (same rig; key times τ from the release; release = press + 0.06 s)

The two hands alternate, so each hand fires every 0.25 s. A clip is about 0.38 s long and the next shot's cock
overlaps the last one's settle, so play the clips **additively** on top of the guard, one per shot. That is what makes
the loop fluid at 8 shots a second instead of frantic.

**Keys, both layers (amplitude × 1.0 in third person, × 0.72 in first person):**

| Channel | −0.16 | −0.03 | 0 (release) | +0.05 | +0.22 | Ease into the key |
|---|---|---|---|---|---|---|
| Hand along cock (up, back, out) | 0 | 0.15 studs | 0 | | | in-out, then snap |
| Hand along flick (down, in, forward) | | 0 | 0.22 studs | 0.27 (overshoot) | 0 | snap, out, in-out |
| Wrist (cuff) flex | 0 | +0.62 rad (cocked up) | −0.46 | −0.58 | 0 | in-out, snap, out, in-out |

The first shot of a burst cocks over the 0.06 s press window: its cock starts at −0.06.

**Third person only:**
- **Chest yaw:** −0.025 rad at −0.03, +0.080 at +0.02 (snap), 0.068 at +0.07, 0 at +0.23. A right-hand shot turns
  the chest left (right shoulder forward); the left mirrors.
- **Counter-rotation:** the pelvis takes −0.32 × the chest yaw, the spine roll ± 0.028 rad, and the head −0.95 × the
  yaw (it stays on target and settles last).
- **Shrug:** + 0.07 studs at +0.015, gone by +0.17.
- **Recoil:** the hips go 0.018 studs back at +0.03, gone by +0.20.

**Guard idle** (third person, caster-local studs; the caster faces +Y):
- hands at (± 1.30, 1.62, 3.38), wrists flexed 0.05, elbows down and out;
- hips at 1.86 with a slight crouch, feet staggered;
- entered from relaxed through a dip (−0.50 s) and up with a `back` overshoot (−0.12 s).

**First person (viewmodel):**
- **Guard:** near-vertical forearms in the lower corners, hands at (± 1.38, 1.85, 3.82), elbows down, wrists cocked
  0.50, so the cuff on top of each forearm snaps from cocked to flat on each shot.
- **Camera:** steady on the crosshair, with a recoil kick per shot: pitch + 0.010 rad and roll ∓ 0.010 rad, rising in
  0.03 s and decaying with tau 0.07 s.
- **Your own blade:** it forms smaller (scale 0.22 → 1 over 0.09 s), so it never fills your view.

**Dummy reaction** (proof of weight; a stand-in for the hit reaction):
- a damped lean back (2.0 Hz, ζ 0.30, + 2.4 rad/s per hit × 1.0 for the first body or 0.7 for the second);
- a head whip (3.4 Hz) and a slide back of 0.42 studs/s per hit, which springs home;
- a small yaw twist that alternates with the shooting hand.

## Blender stand-ins → Roblox, and the compromises

| Blender | Roblox | Compromise |
|---|---|---|
| `Ribbon` + `mat_air` (alpha-blended streak noise, the core thread mostly blended) | MeshPart or Beam + `wb_body` / `wb_streak`, `TextureSpeed` | The 4D noise boil becomes a scrolling texture. The core is baked into the texture and not added. |
| Body rows cut at v = −0.40 (V_BODY) for a crisp leading edge | A one-sided alpha ramp in `wb_body` | none |
| Hairline "time trails" of an orbiting, then flying, attachment | Trails on attachments | Exact. |
| Hairlines re-shaped into impact arches; the secondary re-shaped into the splash (a per-frame morph of the same ribbon's points) | A pooled curved Beam per arch; the secondary MeshPart re-posed by bones (or 2 Beams with animated `CurveSize`) | A Trail cannot re-shape its points, so each hairline hands over to a pooled Beam at the hit. The morph is exact on a bone chain, approximate on Beams. |
| A cooler core thread `#EAFFEF` (local override; kit core `#EFFFE6`) | baked into `wb_body` / `wb_streak` | none |
| The dust sprite's peak alpha raised 0.22 → 0.42 (local override of the kit's dust material) | `Transparency` 0.58 | none |
| `Particles` riding the flow field (the blade's wake, the hit bursts, the release backwash, a breeze) | `ParticleEmitter` direction, speed, drag and acceleration | **No flow field in Roblox.** The wake drag and the burst are baked into each emitter's initial velocity and drag. The leaves will not curl around the blade's wake as they do here. |
| Scarf and hair `Cloth` driven by the same air (a backwash pulse at each release) | Accessory physics or bone wobble | Not part of the M1. |
| `Flash` point light | `PointLight` tween | GQ-gated (see above). |
| Squash and stretch via geometry | `MeshPart.Size` tween, or attachment offsets for Beams | none |
| 0.25× slow motion | none | Showcase only. |
