# Wind Blade (M1): Roblox handoff (Zephyr spring pass, round 2, 2026-10-06)

The Blender source is `blender_scripts/zephyr/spring/wind_blade_bl.py`. Every number here is provisional: the
showcase was built against `ZephyrFX.Tuning.WindBlade` (Speed 240 studs/s, Range 80, Pierce 3, Trigger 0.06 s) and an
8-shots-a-second hold (0.125 s between shots). None of it is final tuning. The round-1 version of this file is in
`_prev/r1/HANDOFF.md`.

**What changed in round 2 (lead review):** the crescent is 40 % wider with a longer arc and its core moved onto the
leading side; the hand swirl is an open two-armed spiral (it read as a closed ring); the splash band is wider and
crowns over the body, the puff is denser, the flash is 400 W; the kit's core `#EAFFEF` and dust alpha 0.40 replace this
piece's local overrides (there are none now).

**Shared trigger beat:** t = 0 is the M1 press. A shot's **release is at press + 0.06 s** (the `Trigger`). Both
animation layers and every effect key off that release, and the times below are given from it (τ = t − release)
unless they say otherwise.

## Exact per-shot counts (the leanest effect in the kit; unchanged in round 2)

| Layer | Per shot | Notes |
|---|---|---|
| Crescent body | **1** | the only element that never drops |
| Secondary crescent | **1** | thin, lagging, offset back; at the first body it **becomes the splash** (no extra mesh) |
| Hairlines | **3** | hairlines 0 and 1 are **the hand swirl's two arms**, then flank the blade; hairline 2 is born at the release inside the blade. At the hits they **become the impact arches** (no extra beams) |
| Trail | **1** | short and tapering, ~6.4 studs at full speed |
| **Air elements in total** | **6** | 1 body + 1 secondary + 3 hairlines + 1 trail. Nothing else is spawned: the swirl is two of the hairlines, the impact's air is the secondary and the hairlines re-shaped |
| Leaf fragments | **3 or 4 (≤ 6)** | 1 shed in the wake, 2 out of the back of the first body, 1 out of the second body on every other shot |
| Puff particles | **8 (≤ 8)** | first hit: 4 dust + 2 glints; second hit: 2 dust |
| Light | **1 flash** | first hit only |

At 8 shots a second, about 3 shots are alive at once (in flight or splashing): about 18 air elements, about 25
leaves, 10 dust sprites and 4 glints at the peak. Over the hero clip: 25 shots, 50 hits, 88 leaves, 150 dust and 50
glints (first-person clip: 18 shots, 36 hits, 63 leaves, 108 dust, 36 glints).

## Meshes (rough budgets)

| Mesh | Size | Budget | Behaviour |
|---|---|---|---|
| **Crescent band** (the body) | 30 × 3 verts, ~116 tris; horn to horn 3.96 studs, max width 1.37 studs | ~116 tris | see below |
| Secondary crescent band | 24 × 3 verts, 1.10 × the span, 0.52 × the width (0.71 studs) | ~92 tris | can be the same mesh scaled; for the splash, a second pose of it (or a bone chain, see below) |

**The crescent band in detail (round 2: 40 % wider, longer arc):**
- **Shape.** A 3D crescent in the blade's local frame:
  - an arc of 150° (round 1: 128°), radius 2.05 studs (1.92): 5.37 studs of arc (4.29), horn to horn 3.96 (3.45);
  - the horns curl back 0.56 studs toward the concave side (as seen from behind);
  - the horns sweep 1.10 studs back along the flight (as seen from the side);
  - the band leans 46° between "back along the flight" and "inward", so it has visible width from behind, from the
    side and from above;
  - the width peaks at 1.37 studs (0.98) 42 % of the way from the lower horn and tapers to both horns.
- **Tilt.** Steep: the right hand's crescent is "/" at 62° and the left hand's is "\" (seen from behind). A flat
  crescent goes edge-on from the side.

The trail, the hairlines and the lingering wisps need no meshes: they are Trails and Beams (below).

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| `wb_body` | 256 × 64 | **Opaque on the leading edge**, feathering to transparent on the trailing edge. Colour (leading → trailing): a pale mint `#EAFFEF` core band (the kit core) that starts at the leading edge and fades out ~40 % of the way across, broken into streaks → `#A2EAA6` → `#4ADE6B` → `#1F8A4C`. Streak noise along the length, frayed fibres over the last 30 % (the upper horn). |
| `wb_streak` | 128 × 32 | Soft streak noise with alpha falling to 0 at both long edges. Used by the trail, the hairlines (the swirl arms) and the wisps; tiles along U. |
| `leaf_tumble` | 4 × 4 flipbook, 256 px (64 px cells) | A tumbling leaf in three tints: `#34A45A`, `#5FD46E`, `#8FE07A`. **No pure-accent leaves** (they read as yellow dots). |
| `soft_dot` | 64 px | Radial falloff. Used by dust (lit) and glints (emissive). |

About the `wb_body` texture:
- In Blender, the crisp leading edge comes from cutting the geometry inside `mat_air`'s opaque zone (the rows run
  v = −0.40 … 1); the core sits at coreoff −0.22 with corew 0.42 (the kit's "coreoff ~0.5 on the leading side", in
  this cut's coordinates). In Roblox it is simply a one-sided alpha ramp with the core stripe painted on the leading
  ~40 %.
- The pale core is baked into the texture as a stripe. It is **not** a second additive beam: wind is not neon.
- The white-only (colourblind) read is that stripe: on its own it draws a bold crescent.

## Beams and trails (per shot)

| Element | Roblox | Settings |
|---|---|---|
| **Crescent body** | the crescent MeshPart, or 2 Beams (apex → each horn, `CurveSize0/1` bowing them back, `Width0` 1.37 → `Width1` 0, `FaceCamera` false, `Segments` 14) | `wb_body`; `LightEmission` 0.25, `LightInfluence` 0; `TextureSpeed` ~1 (streaks run horn to horn); `Transparency` 0.25 at full fade. **Build:** scale 0.40 → 1 and fade 0 → 1 over τ −0.035 … +0.03, formed at the hand. **Squash and stretch** along the flight: 0.72 while forming → 1.28 at τ +0.035 → 1.0 by +0.205. Each body hit dips the stretch by × (1 − 0.38) over ±0.018 s, so the blade flattens and the horns flare as it punches through. The cross-scale is 1/√stretch. **Thin:** from 26 to 88 studs of flight (τ 0.11 … 0.37 s) it fades out, grows × 1.3 and frays. |
| **Secondary** | the same, thinner | `Transparency` 0.45. Offset 0.36 studs back along the flight and 0.10 toward the concave side; its stretch lags 0.015 s behind the body's. |
| **Secondary → the splash** (the impact's air) | the same MeshPart, re-posed: easiest as a 12-bone chain (or 2 Beams with animated `CurveSize`) | At the first body hit the secondary stops riding the blade and **catches on the body**: over 0.05 s it morphs (out-ease) into an OPEN band arc around the entry point, perpendicular to the flight but leaning 40° back over the top. Over 0.24 s (out-ease) its span opens 150° → 170°, its radius grows 1.15 → 2.2 studs (the far horn 22 % tighter: a spiral, never a ring), its width thins **0.92 → 0.41 studs** (round 1: 0.62 → 0.26), and it drifts 0.45 studs along the force plus the breeze. `Transparency` 0.32 at birth → 1 from 0.05 to 0.34 s. **Round 2: centred 45 % of the way from the blade's convex side toward straight up**, so it crowns over the body (a right-hand shot spans ~40° → 210°, measured from the right, seen from behind; a left-hand one ~ −30° → 140°): in a stream the union leaves the bottom ~120° open, never a ring, and the band reads from the side as well as from behind. |
| **Trail** | a Trail behind the body | `Lifetime` 0.027 s (~6.4 studs at 240 studs/s); `WidthScale` 0.46 → 0 (exponent 1.1); `Transparency` 0.48 → 1; `LightEmission` 0.2; `wb_streak`. Its tail end sits at the hand for the first 0.027 s, then leaves. |
| **Hairlines 0 + 1: the hand swirl** (round 2: an OPEN two-armed spiral) | 2 Trails on 2 attachments | **Where:** a world-space point 0.50 studs in front of the palm at its release pose, 0.12 studs up (first person: 0.42 up, clear of the big near cuff), so the hand cocks and snaps *through* it (a trail riding the hand recorded the snap as a kink). The swirl's axis is the flight direction leaning 0.6 out to the hand's side (it opens outward and reads from the side too). **When:** τ −0.14 → 0 (the first shot of a burst: from its press, τ −0.06). **Motion:** each attachment orbits the point at 59 rad/s (right hand clockwise, left counter-clockwise, seen from behind), the two half a turn apart, while its orbit radius **shrinks exponentially**: the OUTER arm from 1.50 studs (× e^(−4.6 τ'), τ' = time since the swirl began), the INNER arm from 0.72 studs (× e^(−8.7 τ')); first person × 0.75. `Lifetime` 0.08 s, so each Trail draws a **~270° log-spiral arm** whose head (the newest point) winds in toward the palm: outer arm ~1.50 → 1.03 studs along its length, inner ~0.72 → 0.36, a ≥ 0.3-stud gap between them all through the swirl, and the whole swirl tightens into the palm by the release. Width 0.058 studs × 3.0 (outer) / × 2.3 (inner), tapering to 0 at the tail; alpha 0.78 (`Transparency` 0.22 before the kit-wide × 1.69 opacity, as for every value in this table), fading in over the first 0.035 s; `wb_streak`. **Unspool:** from τ 0 the Lifetime drops 0.08 → 0.022 s over 0.03 s (Roblox: tween `Trail.Lifetime`; older segments drop off), so the spiral is eaten from its outer end as the heads fly off with the blade. |
| **Hairlines in flight** | the same Trails (+ hairline 2, born at the release at the palm) | `Lifetime` 0.022 s (flanking) or 0.028 s (inner); width 0.058 or 0.048 studs; `Transparency` 0.5. Over τ 0 … 0.022 they blend onto the blade: two flank it at ±1.62 studs (round 1: 1.45; the crescent is wider) in a gentle helix of 0.15 rad per stud, offset 0.9 rad so they never form a ring, and one runs inside at 0.80 studs. |
| **Peel → the impact arches** | a pooled curved Beam per arch | At the first body hit the flanking pair detach (the inner one at the second body). Each becomes a **streamline arching over the body** from its front face to its back (the air parting over it and carrying on): an open 133° arc in the plane of the flight and a direction splayed ± 20–34° from vertical (hairline 0 high and wide toward the blade's side, radius 1.30 → 2.10 studs; hairline 1 lower and tighter the other way, 0.95 → 1.60; hairline 2 over the second body, 0.90 → 1.50). The shape morphs in over 0.06 s, widens over 0.22 s, rolls 0.35 rad downstream and drifts 0.6 studs along the force; width 0.21 → 0.10 studs; `Transparency` 0.28 at birth → 1 from 0.04 to 0.36 s; it frays from the downstream end. In Roblox the attachments are tweened, since a Trail cannot re-shape its points. |

## Particle emitters

All are `Rate` 0 with `Emit(n)` on events, through the shared emitter helper.

| Emitter | Event | Sprite | Size (studs) | Lifetime | Speed | Other |
|---|---|---|---|---|---|---|
| **Leaf fragments** | `Emit(1)` at τ +0.03 a few studs down the path (the wake); `Emit(2)` at the first hit from the exit (back) side; `Emit(1)` at the second hit on alternate shots | `leaf_tumble` | 0.36–0.6; a heavier 0.54–0.57 one every other shot overshoots and lags | 0.65–1.0 s | wake 26–46 along the flight; hits 16–26 along the force, ± 8 sideways, + 3–8 up | `Drag` 7; `Acceleration` (0, −20, 0) (gravity, fluttering); `RotSpeed` ± 150–500 °/s; `LightInfluence` 1; `LightEmission` 0.1 |
| **Dust puff** (round 2: denser, same count) | `Emit(4)` at the first hit, `Emit(2)` at the second, at the entry point | `soft_dot` | **1.05–1.30** (the second hit × 0.85; round 1: 0.70–0.90), growing × 2 over life | 0.22–0.32 s | **5** radial (sideways off the body; round 1: 7) + 1 back toward the shooter, 1.2 down | `Drag` 6; `Transparency` **0.60 → 1** (the kit dust's peak alpha 0.40; round 1 overrode it locally to 0.42); **lit**: `LightInfluence` 1, `LightEmission` 0. Bigger, slower sprites overlap into one pale cloud at the entry. Short-lived on purpose: longer-lived dust stacks into a rising white column in a stream, which reads as smoke |
| **Glints** | `Emit(2)` at the first hit | `soft_dot`, 32 px | 0.06–0.09 | 0.14–0.20 s | 13 radial | `LightEmission` 1; `Orientation` VelocityParallel (stretched); `Drag` 14 |

The flash is a `PointLight`, colour (0.92, 1.0, 0.9), `Range` about 8. Its peak equals **400 W** in Blender (round 1:
320 W; about `Brightness` 3.75). It rises in 0.012 s, then decays exponentially with tau 0.07 s. It sits 1.5 studs in
front of the hit and 1.3 studs up and to the side: a soft wash, never a hot spot on the dummy.

**Graphics Quality scaling (what drops first):**
1. The glints and the second hit's dust.
2. The inner hairline (and with it the second body's arch).
3. Leaves cut to 1 per shot (the first-hit pair goes to 1, the wake leaf goes).
4. The flanking hairlines (the swirl and the first body's arches go with them).
5. The flash: never below GQ 6, and only for your own hits.

The crescent body, the trail and the secondary (with its splash) never drop: the splash is the impact's read.

**Reduce Enemy VFX:** other players' blades lose the hairlines (so the swirl), leaves, glints and flash, and keep the
body, the trail, the secondary + splash and 2 dust.

## Animation clips (same rig; key times τ from the release; release = press + 0.06 s; unchanged in round 2)

The two hands alternate, so each hand fires every 0.25 s. A clip is about 0.38 s long and the next shot's cock
overlaps the last one's settle, so play the clips **additively** on top of the guard, one per shot. That is what makes
the loop fluid at 8 shots a second instead of frantic.

**Keys, both layers (amplitude × 1.0 in third person, × 0.72 in first person):**

| Channel | −0.16 | −0.03 | 0 (release) | +0.05 | +0.22 | Ease into the key |
|---|---|---|---|---|---|---|
| Hand along cock (up, back, out) | 0 | 0.15 studs | 0 | | | in-out, then snap |
| Hand along flick (down, in, forward) | | 0 | 0.22 studs | 0.27 (overshoot) | 0 | snap, out, in-out |
| Wrist (cuff) flex | 0 | +0.62 rad (cocked up) | −0.46 | −0.58 | 0 | in-out, snap, out, in-out |

The first shot of a burst cocks over the 0.06 s press window: its cock starts at −0.06. The swirl (−0.14 … 0) spans
the cock: the hand winds up while the air winds in, and snaps through the swirl's centre on the release.

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
- **Your own swirl:** × 0.75 and lifted 0.42 studs above the palm so the near cuff never hides it.

**Dummy reaction** (proof of weight; a stand-in for the hit reaction):
- a damped lean back (2.0 Hz, ζ 0.30, + 2.4 rad/s per hit × 1.0 for the first body or 0.7 for the second);
- a head whip (3.4 Hz) and a slide back of 0.42 studs/s per hit, which springs home;
- a small yaw twist that alternates with the shooting hand.

## Blender stand-ins → Roblox, and the compromises

| Blender | Roblox | Compromise |
|---|---|---|
| `Ribbon` + the kit's `mat_air` (alpha-blended streak noise, the core thread mostly blended) | MeshPart or Beam + `wb_body` / `wb_streak`, `TextureSpeed` | The 4D noise boil becomes a scrolling texture. The core is baked into the texture and not added. |
| Body rows cut at v = −0.40 (V_BODY) for a crisp leading edge; core at coreoff −0.22, corew 0.42 | A one-sided alpha ramp in `wb_body` with the core stripe on the leading ~40 % | none |
| The swirl arms: time-trails of attachments on shrinking orbits around a point pinned at the release pose | 2 Trails on world-space attachments, orbit radius tweened (exponential), `Lifetime` tweened at the release | Exact if the attachments are world-space; parented to the hand, the snap would kink the arms. |
| Hairline "time trails" of an attachment riding the blade | Trails on attachments | Exact. |
| Hairlines re-shaped into impact arches; the secondary re-shaped into the splash (a per-frame morph of the same ribbon's points) | A pooled curved Beam per arch; the secondary MeshPart re-posed by bones (or 2 Beams with animated `CurveSize`) | A Trail cannot re-shape its points, so each hairline hands over to a pooled Beam at the hit. The morph is exact on a bone chain, approximate on Beams. |
| The kit's core `#EAFFEF` and dust peak alpha 0.40 (round 1's local overrides of both are gone) | baked into `wb_body` / `wb_streak`; dust `Transparency` 0.60 | none |
| `Particles` riding the flow field (the blade's wake, the hit bursts, the release backwash, a breeze) | `ParticleEmitter` direction, speed, drag and acceleration | **No flow field in Roblox.** The wake drag and the burst are baked into each emitter's initial velocity and drag. The leaves will not curl around the blade's wake as they do here. |
| Scarf and hair `Cloth` driven by the same air (a backwash pulse at each release) | Accessory physics or bone wobble | Not part of the M1. |
| `Flash` point light (400 W) | `PointLight` tween (`Brightness` ~3.75) | GQ-gated (see above). |
| Squash and stretch via geometry | `MeshPart.Size` tween, or attachment offsets for Beams | none |
| 0.25× slow motion | none | Showcase only. |
