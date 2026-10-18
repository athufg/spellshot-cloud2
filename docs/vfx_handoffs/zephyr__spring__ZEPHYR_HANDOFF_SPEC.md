# Zephyr spring-wind kit: handoff spec for the Roblox Studio build

---

One section per piece, written by each piece's builder from its final renders. Shared language, palette, materials and the Roblox mapping of every Blender stand-in: `ZEPHYR_STYLE_BIBLE.md`. All gameplay numbers are provisional. Times are seconds from each piece's key press (the shared trigger beat).

---

## Wind Blade (M1): Roblox handoff (Zephyr spring pass, round 2, 2026-10-06)

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

---

## 2. Cross-Slash Dash (Primary): handoff for the Roblox Studio build

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

---

## 3. Updraft (Passive): handoff spec

The Roblox Studio build for the airborne tell. Every number is provisional showcase tuning, not final gameplay tuning.
Blender source: `blender_scripts/zephyr/spring/updraft_bl.py`. The kit is `zk.py`, and the bible is `ZEPHYR_STYLE_BIBLE.md`.

**Round 2 (lead review) changed:** three distinct, shorter hairline spirals and a leaf-fleck emitter (the 10-stud read);
the aerial hit is now a **pulse that climbs the spiral in 0.25 s** (glow to 1.4, a width swell, a pale surge Beam),
then settles; the airborne pose layer is a clean **riding-the-wind** pose; the scarf streams up from the take-off; the
kit's core hex is now `#EAFFEF` and seed fluff is LightEmission 0.2 by default. The round-1 spec is in `_prev/r1/`.

## What it is

The passive has no ability clip. It's a state tell: **on while the Humanoid is airborne** (Jumping / Freefall), **off on
Landed**. It is a small upward-opening funnel of air that the caster rides. It has four parts:

- **The funnel bands:** they start narrow under the feet and open round the shins and knees. They spin
  counter-clockwise seen from above, at 0.8 rev/s.
- **Hairline spirals:** three distinct ones, about one turn each, stacked: the throat, the shins, the knees.
- **Throat streaks:** short streaks rising in the funnel's throat.
- **Debris:** pollen, seed fluff and a few small leaves riding up the legs.

An aerial hit landed by the caster (the passive's bonus-damage hit) sends a **pulse up the spiral**: a band of
brightness climbs from the throat to the top in 0.25 s, swelling and paling every band it passes, then leaves through
the top as a loop of air (the exhale) while the tell settles. Landing **thins** the tell away in 0.42 s while two open
spiral arms spill across the floor.

**Shared trigger beat:** t = 0 is the jump key press, which is also the take-off (feet leave the floor). Every time below
is in seconds from it. The aerial-hit beat has its own origin, t_hit = the server-confirmed aerial hit.

| Beat | Showcase time | Roblox trigger |
|---|---|---|
| the tell builds (draws on from the feet up) | 0.00 to 0.12 | Humanoid.StateChanged to Jumping or Freefall. Use 0.08 s in game: a default jump is only about 0.5 s of air |
| airborne steady state | 0.12 to landing | while the state is Jumping or Freefall |
| **aerial hit: the pulse climbs** | t_hit + 0.00 (on in 0.03 s) to t_hit + 0.25 (at the top), gone by t_hit + 0.32 | the passive's on-hit event while airborne |
| the tell settles; the exhale peels off the top | t_hit + 0.18 to t_hit + 0.78 (the glow lift decays with tau 0.16 s from t_hit + 0.25) | the same event |
| landing: the tell thins away | t_land + 0.00 to 0.42 (bands), 0.68 (hairlines), 0.75 (floor spill) | Landed |

The showcase arc uses zk.G, real gravity (28.6 studs/s²): 1.40 s of air and a 7-stud apex, so the tell can be seen. Roblox's
default 196.2 studs/s² gives about 0.5 s of air. The tell must therefore read from its first 0.1 s, so build fast and
skip the throat streaks on short hops if needed. The pulse is 0.25 s at 1x by design (it reads in real time: see
`zs3_updraft_gameplay_1x.mp4`), so it fits a short hop; if the caster lands mid-pulse, let the pulse finish on the
thinning bands.

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
| `zk_air_streak` | 256 × 64 | Tileable along u. Across v: shadow `#1F8A4C` on the lower edge, through base `#4ADE6B`, to light `#A2EAA6` on the lit (upper) edge, desaturated about 24 % toward `#CFE2D6`. A pale mint-white **`#EAFFEF`** core thread at v = 0 (round 2: the kit's cooler core, hue 134), broken into streaks by stretched noise. A few sparse accent `#E9F7A4` flecks near the lit edge. Soft noisy alpha at both edges. Shared by every Zephyr piece. |
| `zk_air_core_wide` | 256 × 64 | Round 2, for the pulse's surge Beam: the same streak texture with the pale core thread widened to about 85 % of the half-width over a thin green body. |
| `zk_air_hairline` | 128 × 16 | A thin streaky thread: the core plus a little body green. |
| `zk_streak_sprite` | 32 × 128 | A soft vertical streak for the throat streaks (VelocityParallel particles). |
| `pollen_dot` | 32 × 32 | A soft round dot, `#FBF6CF`. |
| `seed_fluff` | 64 × 64 | A pappus: 9 radial filaments in a shallow cup plus a short stalk, `#F6FBF2`, alpha 0.75 tapering to the tips. |
| `leaf_tumble` | flipbook 4 × 4, 128 px cells (512 × 512) | Round 2: a small tumbling spring leaf, `#34A45A` / `#5FD46E` / `#8FE07A` with a lighter midrib (the kit's leaf). |
| `glint` | 32 × 32 | A soft 4-point sparkle, `#EAFFEF`. |
| `petal_tumble` | flipbook 4 × 4, 128 px cells (512 × 512) | A tumbling petal, `#F4F3E6` to `#E8F6DC`. |
| `grass_bit` | 32 × 128 | A blade fragment, `#78A86A`. |
| `dust_puff` | 128 × 128 | A soft round puff, `#D9D1C4`, peak alpha 0.40 (the kit's round-2 value). **Lit, not emissive** (LightEmission 0, LightInfluence 1), so it never glows on a dark map. |

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
| hairline 1 (throat) | 4 | 10 | 0.55 to 1.50, 1.0 turn | -1.30 to +0.85 | 0.074 (0.55 at the ends) | 0.25 | 6 | 0.1 | true |
| hairline 2 (shins) | 4 | 10 | 1.00 to 2.05, 0.95 turn | -0.35 to +1.85 | 0.068 | 0.25 | 6 | 0.1 | true |
| hairline 3 (knees) | 4 | 10 | 1.45 to 2.50, 0.90 turn | +0.55 to +2.75 | 0.062 | 0.25 | 6 | 0.1 | true |
| **pulse surge** (one per main band) | 2 + 2 | 12 | rides main A / main B, 0.4 of the band's length, centred at the pulse's height | climbs from -1.35 to +2.85 in 0.25 s | 1.7× the band's width there, sine-tapered ends | 0.25 (body alpha 0.45, a wide pale core `zk_air_core_wide`) | 6 | 0.25 | false |
| **exhale** | 3 | 12 | 1.7 to 2.2, widening to 2.2 to 3.7 over 0.6 s | +0.9 to +2.7 at the birth, rising 0.7 to 1.1 more; **world-anchored** (the caster falls away from it) | 0.62 shrinking to 0.22 | 0.25, fading out with a 1.5 power | 4 | 0.2 | false |
| landing spill | 2 arms (2 + 2 beams) | 10 | from 0.42R to 1.25R and 0.5R to 1.1R, with R growing 1.4 to 3.9 over 0.75 s | flat on the floor (0.07) | 0.74 shrinking to 0.12 | 0.25, fading out with a 1.4 power | 3 | 0.1 | false: lies flat |

- **The aerial-hit pulse (round 2).** It is a band of brightness about 1.2 studs tall (a soft gaussian, ±0.6) that
  climbs the funnel from 1.35 studs below the feet to 2.85 above in **0.25 s**: fast out of the throat, easing into the
  top (45 % linear + 55 % ease-out).
  - Where it passes, every band swells: main bands' width up to ×1.8 and opacity ×1.2; the secondary ×1.56, the haze
    ×1.24; hairlines' width ×1.6. **In Roblox** a Beam's width is only set at its two ends, so tween Width0 / Width1 of
    the beam segment(s) at the pulse's height (about 4 steps per band) and let the surge Beam carry the continuous climb.
  - The **surge Beam** (one per main band) is re-attached every frame to the stretch of the helix at the pulse's height.
  - The whole tell's core lifts while the pulse climbs: core strength 1.0 -> **1.4** (never higher), the pale core's
    width ×1.35, band width ×1.10, Transparency -0.06. From t_hit + 0.25 it **settles** with tau 0.16 s.
  - It goes **paler**, not greener or hotter: the surge's wide pale core sits over a thin green body. NOT NEON on the
    showcase stage: the brightest wind pixels stay unclipped (max G 240 at the pulse, no channel ≥ 250 in the frame) and the brightest 1 % is pale mint, hue 145.
  - Spin ahead by 1.7 rad over 0.5 s (unchanged).
- **Thin (landing):**
  - Bands: Transparency goes to 1 over 0.42 s (front-loaded, power 1.6). The throat attachments sink to the floor, and the
    radii grow 1.2× at the bottom and 0.6× at the top.
  - Hairlines: loosen up and out over 0.68 s.
  - Spill arms: play once.
- **Never** close a band into a ring. Every band is an open arc with tapered ends; every hairline is under 1.05 turns
  and both rises and widens.

## Particle emitters

Roblox particles cannot ride a flow field. The stand-in is to emit from **2 or 3 attachments orbiting the axis**
counter-clockwise at radius 0.6 to 1.8 and 0.8 rev/s, with Speed along the tangent and up, Drag 4 to 6,
VelocityInheritance 0.9 and LockedToPart = false. Particles then spiral up and shed outward, like the Blender vortex.

| Emitter | What | Rate / burst | Lifetime | Size (studs) | Speed / motion | Sprite |
|---|---|---|---|---|---|---|
| pollen | specks spiralling up the legs | 85 /s while airborne, about 110 alive | 0.9 to 1.6 | 0.054 to 0.11 | tangent 3 to 7, up 2 to 6, Drag 30 (it tracks the air) | `pollen_dot`, LightEmission 0.3 |
| seed fluff | slow, drifting pappus | 16 /s, about 25 alive. 20 % are heavier: size 1.6 to 1.9×, an initial -6 studs/s, so they overshoot and lag | 1.5 to 2.6 | 0.135 to 0.22 (heavy 0.24 to 0.29). Keep them small and dim: bigger or brighter, they read as sparkle stars. First person: ×0.6 size | tangent 3 to 6, up 1 to 4, Drag 22, RotSpeed ±60 | `seed_fluff`, LightEmission 0.2 (the kit's value since round 2) |
| **leaf flecks** (round 2) | a few small spring leaves riding the funnel up the legs, then shed out to tumble down | 7 /s while airborne (about 9 per jump) + Emit 3 off the floor at the take-off | 1.1 to 1.6 (take-off 1.3 to 1.8) | 0.13 to 0.21. First person: ×0.6 | tangent 3 to 6, up 5 to 8, Drag 13 (light flecks: the kit leaf's 7 dropped them out of the funnel), Acceleration -28.6 (full gravity): they climb with the air a little slower than the pollen, spiral, leave the column at the top and fall | `leaf_tumble`, LightEmission 0.1, LightInfluence 1 (lit: backlit leaves glow softly) |
| throat streaks | rising air in the funnel's throat | 10 /s | 0.43 to 0.55 | 0.10 to 0.15 wide, 1.0 long | up 5 (VelocityParallel), LockedToPart | `zk_streak_sprite` |
| take-off kick | what the push lifts off the floor | Emit 14 pollen, 4 fluff, 3 leaves, 4 grass bits, 3 petals, 7 dust at t = 0 | 0.55 to 2.4 | as above, dust 0.7 to 1.0 growing 2× | dust outward 7.5 and low, the rest drawn into the funnel | as above |
| hit exhale | the tell breathes out | Emit 30 pollen, 7 fluff, 10 glints, 2 petals at t_hit | 0.3 to 2.2 (glints 0.3 to 0.55) | glint 0.045 to 0.08 | radially out 4 to 9, up 2 to 5 | as above |
| landing spill | the air hits the floor | Emit 12 dust (a ring, outward 7.5), 6 grass bits | 0.9 to 1.4 | dust 0.8 to 1.2 growing 2× | radial, low | `dust_puff`, `grass_bit` |

**Graphics Quality and Reduce Enemy VFX scaling.** Drop things in this order:

1. The haze veil.
2. The throat streaks.
3. The secondary band.
4. Pollen to 30 %.
5. Fluff to 40 %.
6. Leaf flecks to 3 /s.
7. Hairline 3.
8. The hit glints and petals, then the exhale loop.

**Main bands A and B, hairlines 1 and 2, and the pulse surge are never dropped:** the bands and hairlines are the
silhouette that carries the tell at 10 studs, and the pulse is the aerial-hit confirm (gameplay information). At the
lowest setting, use the two optional helical MeshParts instead of the 7 beams, and do the pulse as the surge Beams
alone.

## Lights

- **The pulse:** one PointLight on the funnel's axis that climbs with the pulse (at the pulse's height). Colour
  `#EBFFE6`, Range 5, Brightness 0 to 0.2, on with the pulse, then 0.5 × the settling lift. The showcase stand-in is an
  18 W point light with a soft 1-stud radius (round 1's 140 W, and a first round-2 45 W, lit a hot spot on the legs once
  the legs hung into the funnel). It is optional: the pulse reads without it.
- The aerial hit's impact flash belongs to the attacking ability (here a stand-in Wind Blade). The showcase stand-in is a
  140 W point light that starts at contact with tau 0.08 s.

## Animation (the shared trigger beat t = 0 = take-off)

No ability clip. The body language is the jump itself plus the cloth.

**Third person** (an optional airborne pose layer for Zephyr). Round 2 replaces round 1's knee tuck (the lead: knees
knotted under the torso) with a clean **riding-the-wind** pose:

- **The dip:** -0.24 to -0.07, showcase only. In game the jump fires at the press, so compress it into a 2-frame push.
- **The push:** -0.07 to 0.00, with a snap ease. The arms swing up and forward.
- **Take-off extend:** 0.00 to 0.09. Toes pointed; the right knee starts to rise.
- **Riding:** 0.09 to 0.52 (and again 0.86 to 1.33). **The right knee up in front** (thigh near level, shin hanging,
  foot relaxed), **the left leg trailing** long behind and below, nearly straight, toe pointed; **arms out wide for
  balance**, swept: the left forward and high, the right back and low (contralateral), palms riding the air; pelvis
  pitched forward 0.16, chest lifted (spine -0.16). The off-hand lags by 0.045 s and the head settles 0.06 s after the
  body. In the showcase the body also opens 0.25 rad toward the camera side (root yaw -0.38 vs -0.13 at the dummy);
  in game, skip the root yaw and keep only the limb layer.
- **Fall prep:** landing -0.07. The trailing leg swings forward, both legs reach for the floor and the arms rise.
- **Land squash:** landing to +0.13. Hips down 0.68 studs, spine pitched forward 0.3.
- **Springy recovery:** to +0.50, with a back ease (overshoot).
- **Settle:** to +1.05.

The showcase's aerial-hit flick (a Wind Blade stand-in) runs:

- wind-up from 0.52 to 0.648: the hips turn back toward the target, the chest coils 0.30 rad right and the hand cocks
  back; the legs hold the riding shape;
- the snap at 0.695: the knee drives down and the trailing leg kicks back (the counter-swing);
- the follow-through, with overshoot, to 0.86, then back into the riding shape.

That clip is the M1's, not this passive's.

**First person** (viewmodel arms, same clock):

- **While airborne:** the hands go out to the sides at mid-frame, palms catching the air. A flutter of 0.05 studs at
  17 to 23 Hz rides on top. On the aerial hit both hands lift 0.12 studs (decaying tau 0.32 s).
- **On landing:** they swing down out of view by +0.70.
- The showcase camera looks well down (pitch -1.34 rad) while riding, so the funnel is seen from above as an open spiral
  under the player.

**Cloth (scarf and hair):** while airborne the scarf **streams up from about 0.15 s after the take-off**, rising and
falling, and twists as it winds; it whips harder on the aerial hit and drops onto the shoulders on landing. (Round 2:
in round 1 it hung down the back on the rise and only lifted at the apex.) In Roblox, the bone-spring target direction
is up + counter-clockwise while airborne, with the target updated in the root's frame so the caster's own vertical speed
never drags it down; the aerial hit doubles the swirl for about 0.5 s.

## Blender stand-ins and their Roblox equivalents

| Blender | Roblox |
|---|---|
| `Ribbon` + `mat_air` (alpha-blended strip, procedural streak noise, scrolling) | Beam chains with `zk_air_streak`, TextureSpeed |
| camera-facing hairline Ribbons | Beams with FaceCamera = true |
| the pulse: a per-point width / opacity swell + a surge Ribbon riding the band | Width0 / Width1 tweens on the beam segment at the pulse's height + a surge Beam re-attached up the helix each frame |
| `Particles` riding the vortex flow field (`field()`) | ParticleEmitters on orbiting attachments, plus Drag and VelocityInheritance. **A compromise:** no true field, so the paths are spirals but less coherent |
| `Cloth` verlet scarf and hair in the same air, with a drawing-only twist (`TwistCloth`) | a script-driven bone spring chain on a skinned scarf. **Roblox has no cloth sim.** Its target direction = up + CCW while airborne |
| `Grass` tufts bending in the take-off / landing air | a few local grass-tuft meshes tweened outward and springing back. Terrain grass can't be bent by VFX, and this is optional |
| `Flash` point lights | PointLights tweened by script |
| scene-linear emission capped by `zk.E()`, bloom 1.25 / 0.14 | Beam LightEmission ≤ 0.25 and the game's Bloom. Keep the tell under the bloom threshold (NOT NEON) |

## Roblox limitations that forced a compromise

- **No flow fields:** particles approximate the vortex with orbiting emitters.
- **No cloth sim:** the scarf uses bone springs.
- **Helices need Beam chains:** a Beam is one Bezier, so it needs about 4 attachments per turn, rotated each frame by script.
- **Per-point Beam width doesn't exist:** the pulse's swell steps from segment to segment (about 4 steps per band); the
  surge Beam carries the smooth climb.
- **Texture scrolling only exists on Beams and Trails:** the low-quality MeshPart fallback is static, with its spin done by
  CFrame.
- **Short default air time:** with about 0.5 s of air, the build must be about 0.08 s, and the throat streaks may be skipped
  on short hops.

---

## 4. Skyrider (Technique): handoff for the Roblox Studio build (round 2)

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

---

## 5. Gust Pad (Technique): handoff spec (round 2)

This is the Roblox Studio build sheet for the placed launch pad. Every number is provisional showcase tuning, not final
gameplay tuning. The Blender source is `blender_scripts/zephyr/spring/gust_pad_bl.py` (classes `Timeline`, `Pad`,
`Caster`, `Dummy`, `FPArms`). The kit is `zk.py` and the bible is `ZEPHYR_STYLE_BIBLE.md`. The round-1 sheet is in
`_prev/r1/HANDOFF.md`.

**Round 2 changes to build from:**

- a press swirl at the palm;
- wider core threads, with the column streaks' core on their outer edge;
- a longer tightening: a visible pull, then a 0.10 s hold;
- the ring-burst sheet turned partway toward the camera;
- a denser rim dust skirt;
- first person: escort wisps after the launch.

Each one is marked **r2** below.

## What it is

The caster presses a palm to the floor. **r2:** air squeezes out from under the palm as a small open swirl. A gust
skims along the ground from the palm and blooms into **the pad**: a FLAT, OPEN spiral of air about 7 studs across
(radius 3.4). It has three trailing swoosh arms that never close into a ring, plus a lagging pair, a haze veil and
hairlines. It spins **counter-clockwise seen from above** (the kit's spin).

At the pad's eye stands **the eye whirl**, a small open cone-helix about 3 studs tall that breathes. It is the tell that
still reads from a low enemy eye-line at 30 studs, where the flat spiral is foreshortened to a sliver. Pollen drifts up
off the pad, micro-vortices wander round the eye, and leaf flecks and petals skitter round the rim.

When a body steps onto the pad it **tightens**, in two parts (r2).

1. **The pull** (an ease in-out over the step-on window minus the hold), where the arms visibly draw in:
   - the radius contracts by 36 % (r1: 28 %);
   - each arm winds from 205° to 290°, so its rim head is pulled toward the eye;
   - the arms' streaks rush inward at up to 2.6x their idle scroll;
   - the spin rises from 0.40 to 2.0 rev/s;
   - the eye whirl narrows and stretches;
   - dust and debris are drawn in.
2. **A 0.10 s hold**, the anticipation, a coil before the release:
   - the spin stalls to about 1.2 rev/s;
   - the radius squeezes 5 % more;
   - the eye whirl squashes down 30 % and widens 25 %, a squash before the column's stretch;
   - the rider's crouch deepens, with a harder tremble.

Then it **launches**: a vertical column of wind with a flared foot (21 studs tall, about 4 studs across) and an
**open** ring burst at its base. The burst is two shallow-cone arcs of 285° and 250° that share one gap. **r2:** each
client turns the ring sheet 60 % toward its own camera, so the burst reads as a ring with a gap, not a thin band. The
body goes up in a clean vertical line.

Each launch spends the pad, because its air goes up the column: the opacity dips to 22 %. It re-arms over 0.95 to
1.75 s after the launch. **Whether the pad is single-use or re-arming is a gameplay decision. The showcase shows a
re-arm because it launches the dummy and then the caster from one pad.**

**Shared trigger beat:** t = 0 is the Technique key press. Launch beats have their own origin: L = the launch moment,
when the launch impulse is applied.

| Beat | Showcase time (hero) | Roblox trigger |
|---|---|---|
| wind-up: the palm comes up | -0.55 to -0.20 (pre-press, a showcase framing; see the animation note) | the clip's first frames |
| the press: palm flat to the floor | 0.00 to 0.14 (contact at **+0.14**) | the cast clip's contact marker |
| **r2** the press swirl at the palm | contact - 0.12 to contact + 0.36 (in over 0.07 s, out from + 0.12) | the clip's press marker, 0.12 s before contact |
| the ground gust: palm to the pad centre | 0.14 to 0.26 | spawn at contact |
| the bloom: the arms whirl out with an overshoot | 0.26 to 0.88 (`back` ease, 1.5 overshoot; spin 2.1 rev/s settling to 0.40) | pad spawn |
| armed idle | 0.88 onward | the pad exists |
| step-on: **the pull** | S to L - 0.10 (0.45 s for the walking dummy, 0.16 s for a hop-on) | the server detects a Humanoid on the pad |
| **r2** **the hold** | L - 0.10 to L (0.10 s, both cases) | the last 0.10 s before the impulse |
| LAUNCH: the column and the ring burst | L + 0.00 to 0.42 (column head up), ring L + 0.00 to 0.75, column thins L + 0.32 to 1.45 | the launch impulse |
| the pad re-arms | L + 0.95 to 1.75 | showcase only (see above) |

The hero's launches fall at **L = 2.85** (the dummy; r1 2.72) and **L = 5.83** (the caster; r1 5.60). The step-on window
is 0.55 s for the dummy (r1 0.42) and 0.26 s for the caster's hop-on (r1 0.16): each is a pull plus the 0.10 s hold. A
good game value is a 0.15-0.25 s pull plus the 0.10 s hold, since the hold is what reads as the tell before the launch.
The showcase uses zk.G, real gravity
(28.6 studs/s²), with a launch of 30 studs/s, so the apex is 15.7 studs at L + 1.05. Roblox's default 196.2 studs/s²
would need about 78 studs/s for the same apex. The column's 0.42 s rise and 1.45 s life assume the rider is still in it
for about 0.5 s; scale both if the gameplay impulse differs.

## Meshes (rough triangle budgets)

Everything that has to scroll is a **Beam** (below). Meshes are only needed for the cheap or optional parts:

| Mesh | Triangles | Use |
|---|---|---|
| `GustPad_Disc` (optional, low GQ) | 64 (a 32-segment flat disc) | One flat MeshPart carrying the pad's three arms baked into a static alpha texture (`gustpad_arms`), spun by script. It stands in for the 9-Beam arm set at Graphics Quality 1-3 and for Reduce Enemy VFX. |
| Leaf, petal, grass-bit and twig debris | sprites (0 tris) | These are particle flipbooks. In the showcase they are small meshes (`zk` templates: leaf 24 tris, petal 24, grass strip 8, twig 6). |
| Grass tufts round the pad | about 650 blades × 3 tris, plus flowers | **Showcase only.** See the limitation below. |
| The caster's scarf and hair | about 40 tris per scarf tail; hair 7 × 8 | Shared with every Zephyr piece (skinned strips). |

## Textures and flipbooks

Shared with the other Zephyr pieces (see the Updraft and Cross-Slash handoffs for the same set):

| Texture | Size | Contents |
|---|---|---|
| `zk_air_streak` | 256 × 64 | Tileable along u. Across v: shadow `#1F8A4C` on one edge, through base `#4ADE6B`, to light `#A2EAA6` on the lit edge, desaturated 24 % toward `#CFE2D6` and then given the kit's VIBRANCE 1.69 saturation. A pale mint-white **`#EAFFEF`** core thread (the r2 kit's cooler core, hue 134) is broken into streaks by stretched noise. Soft noisy alpha at both edges. |
| `zk_air_streak_arm` (**r2**) | 256 × 64 | The pad arms' variant: the core at v = +0.34 (the outer, leading edge), **0.34 of the half-width wide** (r1: 0.22). |
| `zk_air_streak_edgeL` / `_edgeR` (**r2**) | 256 × 64 each | The column streaks' variant: the core **0.24 wide** (r1: 0.13), on one EDGE at v = -0.36 or +0.36. Each frame, every column-streak Beam takes the variant whose core faces away from the column axis on that client's screen, so the column's two silhouette edges carry a white line. The swap is one dot product per Beam per frame: the sign of (Beam midpoint − column axis) · camera right. The lagging body pair uses the same trick at ±0.30, width 0.18. |
| `zk_air_hairline` | 128 × 16 | A thin streaky thread: the core plus a little body green. |

**The colourblind (white-only) setting** draws every core thread 1.7x wider and 1.5x more opaque (kit r2), with the
body alpha off. In Roblox, swap to `_cb` variants of the textures above: the same core drawn 1.7x wider on a
transparent body.
| `gustpad_arms` (low GQ only) | 512 × 512 | The three-arm pinwheel baked from the showcase (top view), alpha 0.6, for `GustPad_Disc`. |
| `dust_puff` | 128 × 128 | A soft round puff, `#D9D1C4`. **Lit, not emissive** (LightEmission 0, LightInfluence 1). |
| `pollen_dot` | 32 × 32 | `#FBF6CF`. |
| `seed_fluff` | 64 × 64 | A pappus, `#F6FBF2`. |
| `leaf_tumble` | flipbook 4 × 4, 128 px cells | Leaf `#34A45A` to `#8FE07A`, the sunlit tip toward `#E9F7A4`. |
| `petal_tumble` | flipbook 4 × 4, 128 px cells | `#F4F3E6` to `#E8F6DC`. |
| `grass_bit` | 32 × 128 | `#78A86A`. |
| `twig` | 32 × 128 | `#82604A`. |

## Beams and trails

All the air shapes are Beams with two layered textures, as Blender's `mat_air` does it: a body Beam (alpha ramp
texture, LightEmission 0.2, LightInfluence 0) and the core thread inside the same texture. **Do not add a separate
additive core Beam:** NOT NEON keeps the core mostly alpha-blended. Any **single Beam spans at most about 110°** of arc,
because a cubic Bezier cannot bend further cleanly, so the spirals are chains.

- **Ground arms** use **FaceCamera = false**. Their attachments lie flat, with the Beam's width axis horizontal.
- The **vertical shapes** use **FaceCamera = true**.
- **u runs from the head (attachment 0) to the tail.** TextureSpeed scrolls the texture from the head toward the tail
  (positive). The column and the eye are built **bottom to top**, so their streaks scroll **up** and they fray at the
  top. The pad arms are built **rim to eye**, so the air visibly flows in.
- **`alpha` below is the kit's `zk_alpha`** (the body opacity before the kit-wide `OPACITY` 1.69). A Beam's opacity
  is min(1, alpha × 1.69) × the texture's alpha ramp, so **Transparency ≈ 1 − alpha × 1.69** at the ramp's peak
  (alpha 0.40 is Transparency about 0.32; alpha 0.56 is about 0.05). The fin2 values were retuned down after the kit
  started applying a scalar `alpha` as `zk_alpha` (before that the effective opacity was half the listed number).

| Shape | Count × segments | Width curve (studs) | TextureSpeed | Transparency / fade |
|---|---|---|---|---|
| **Pad arms** (flat): trailing spiral, rim r 3.57 to eye r 0.32, 205°, z 0.07 to 0.23. **r2 tightening:** the span winds to 290° and the radius fall-off steepens (exponent 1.35 to 1.8), so the rim heads are drawn in; the width shrinks only 14 % while the radius shrinks 36 % | 3 arms × 2 Beams (3 Beams while tight: 290° needs three 110° segments), Segments 16 | 0.7 head, 1.55 at 7 %, 1.3 at 30 %, 0.65 at 70 %, 0.16 tail | 4.5 idle, **up to 11.7 in the pull** (the streaks rush in), back to about 6 in the hold | alpha 0.56 (x1.69 kit); the tail frays over the last 55 %; `zk_air_streak_arm` |
| **Lagging pair** (flat): rim r 3.05 to r 0.6, 170° (230° tight), z 0.15 to 0.29, spin x0.78 | 2 × 2 Beams | 0.3 to 0.62 to 0.12 | as the arms | alpha 0.40, core 0.18 |
| **Haze veil** (flat): r 3.7 to 0.8, 240° | 1 × 3 Beams | 2.0 | 2 | alpha 0.12, LightEmission 0.1 |
| **Hairlines** (camera-facing): rim to r 0.9-1.5, 230-300°, rising 0.3-0.8 | 3 × 3 Beams | 0.065 | 6 | alpha 0.5 |
| **Eye whirl** (camera-facing): an open cone-helix, r 0.25 at the floor to 1.15 / 0.9 at the top, 500°, 2.7 / 2.25 tall (x1.45 tight; **r2: x0.7 tall and x1.25 wide in the hold**) | 2 × 5 Beams | 0.14 base, 0.4, 0.52, 0.3 top | 4.5 up | alpha 0.52 / 0.44, core 0.26 (r1 0.2); it breathes ±15 % at 0.7 Hz |
| **Micro-vortices** (camera-facing): r 0.09 to 0.68, 430°, 1.05-2.2 tall, wandering on a 0.5-stud orbit | 3 × 4 Beams | 0.08 to 0.24 to 0.12 | 6 up | alpha 0.5. Each lives its own 1.7-2.4 s fade cycle (sin^1.4). Drop first. |
| **Eye hairline whirl** | 2 × 5 Beams | 0.045 | 6 | alpha 0.42 |
| **Rim wisps**: curls off the rim, 110°, rising 0.6 to 2.6 | 3 × 1 Beam | 0.12 to 0.32 to 0.16 | 4.5 | alpha 0.42, a 2.2 s staggered cycle |
| **r2 Press swirl**: two open arms + a hairline spiralling CCW off the palm tip, 300° (hairline 340°), r 0.22-0.32 at the palm to 0.5-1.3 below it (widening as the palm lands), descending 1 stud (to the floor). 3P: the palm is on the floor, so it is a flat open swirl round the hand (FaceCamera false). 1P: the palm presses in the air, so it is a cone from the palm (FaceCamera true). It drifts 0.55 studs toward the pad. | 2 × 3 Beams + 1 hairline (3 Beams) | 0.12 at the palm, 0.34, 0.22 (x1.35 as it spreads); hairline 0.05 | 4.5 (down, away from the palm) | alpha 0.5 (hairline 0.48), core 0.26; contact - 0.12 to + 0.36 |
| **Ground gust** (camera-facing, 0.32 above the floor): palm to the centre, curling 260° in | 1 × 3 Beams + 1 hairline | 0.7 to 1.15 to 0.5 | 4.5 | alpha 0.52 (hairline 0.45); drawn on head-first over 0.12 s; gone by bloom + 0.45 |
| **Bloom arcs** (flat, tilted 20° up at the outer edge): 290° and 255°, r 1.0 to 4.8 / 5.6 | 2 × 3 Beams | 0.8 / 0.5, thinning 50 % | 4.5 | alpha 0.42; the two arcs share one gap (their union never closes); out by bloom + 0.55 |
| **Column main streaks** (camera-facing helices): r 1.45 + 1.6·e^(-z/1.5) (the flared foot) to 2.0 at the top; 0.3 / 0.55 / 0.38 / 0.62 turns over 21 studs (near-vertical: more wind braids them into crossing ropes); heads staggered x1.0 / 0.9 / 0.82 / 0.94 | 4 × 4 Beams, Segments 20 | 0.7 foot, 1.3, 1.25, 1.5 near the top, 0.7 | 4.5 up | alpha 0.40, core glow 0.75 easing to 0.6; the top 40 % frays; **r2: `zk_air_streak_edgeL/R`** (the core 0.24 wide on the screen-outer edge) |
| **Column body pair**: r 2.5 + 1.2·e^(-z/1.5) to 3.0, 0.4 turns, heads x0.78 / 0.7 | 2 × 3 Beams | 0.6 to 0.95 to 0.45 | 4.5 up | alpha 0.30; r2: core 0.18 on the outer edge |
| **Column hairline helices**: r 1.0-1.3, 2.7-3.3 and 2.0-2.6; 2.2 / 1.3 / 1.7 turns | 3 × 6 Beams | 0.085 | 6 up | alpha 0.45; they outlast the body by 0.45 s |
| **Rush streaks** (straight, a slight twist): 9 at r 0.5-2.4, heads rising 50-78 studs/s, 5-9 long, staggered 0-0.24 s | 9 × 1 Beam (or Trails on rising attachments) | 0.14-0.29 to 35 % | 8 | alpha 0.36 |
| **Column haze veil** (vertical) | 1 Beam | 5.4 (x1.5 loosening) | 2 | alpha 0.12 |
| **Ring burst** (flat, tilted 35° up at its outer edge, easing to 18°): 285° and 250° OPEN arcs that SHARE one gap (it faces the hero camera's front-right and turns with the spin), r 2.6 to 9.2 and 2.1 to 7.1 in 0.6 s (ease-out; each arc widens x1.1 along its length). **r2: the sheet's width axis is blended 60 % from that cone toward the camera-facing direction** (normalise(0.4 · cone + 0.6 · face)), lifted so its inner edge stays 0.06 above the floor. The near and far sides keep their width from a low camera; the gap stays a gap. | 2 × 4 Beams | 2.2 / 1.4, thinning 45 % | 4.5 | alpha 0.52 / 0.42, core glow 1.0 / 0.75, core 0.26 (r1 0.2). The core is on the outer, leading edge. In over 0.05 s, out by L + 0.75. |
| **Ring hairlines** (camera-facing): 295° and 270°, inside the arcs' gap, r 3.0 to 9.8 | 2 × 4 Beams | 0.06 | 6 | alpha 0.45; out by L + 0.85 |
| **r2 Escort wisps (1P only)**: two open spiral wisps round the rider, 1.2-4.6 studs below the eye at r 2.2-3.2 (35-55° down in a down-looking view), 300° / 270°, half a turn apart, turning CCW at 0.4 rev/s and rising with the rider, plus a hairline each (r x1.12) | 2 × 3 Beams + 2 × 3 hairline Beams | 0.3, 0.62, 0.48, 0.18 (hairline 0.07) | 4.5 up | alpha 0.56 (hairline 0.5), core 0.28; in over L + 0.28 to 0.5, out over L + 1.3 to 1.8. The 1P clip ends on them. |

Column timing: the head height is 21 × ease_out(L + 0.00 to 0.42). The tail lifts 17 × ease_in(L + 0.40 to 1.45), the
radius loosens x1.5 over L + 0.25 to 1.4, and the spin is 1.3 rev, decaying with tau 0.6 s.

**Peak Beam count:**

- Armed idle: 9 + 4 + 3 + 9 + 10 + 12 + 10 + 3 = about **60** Beams.
- While tight: the arms take 9 Beams instead of 6, and the hold adds nothing.
- The press adds 4 (gust) + 2 (bloom arcs) + **9 (r2 press swirl)** for about 0.5 s, before the pad's own Beams exist.
- The launch adds about **58** for 1.5 s.
- **r2, 1P only:** the escort wisps add 12 for about 1.5 s.

That is the heavy end, so see the scaling below.

## Particle emitters

All of them ride the pad's flow. In Roblox that means emitters on attachments that **rotate with the pad** (a
tangential emission direction), plus Acceleration and Drag:

| Emitter | What | Rate / burst | Lifetime | Size (studs) | Speed / motion | Sprite |
|---|---|---|---|---|---|---|
| `PadDust` | the dust skirt circling the rim | **r2: 20/s** (r1 11/s), on 3 attachments at the arm heads (r 2.5-4.0), emitting backward (tangential) | 1.3-2.1 | **0.5-0.85** (r1 0.32-0.55), growing x1.7 | 4.5 tangential, Drag 6 | `dust_puff`, transparency 0.60 to 1 (the r2 kit's dust peak alpha 0.40) |
| `PadPollen` | the idle tell drifting up | **24/s**, Shape Disc r 2.8 | 2.2-3.2 | 0.07-0.12 | Acceleration up 1.2-1.5, Drag 30 | `pollen_dot`, LightEmission 0.3 |
| `PadFluff` | seed fluff lifting | **2/s** (0.35-0.6 s apart) | 2.5-3.2 | 0.12-0.18 | up 1.0, Drag 22 | `seed_fluff` |
| `PadRimDebris` | leaf flecks and petals skittering round the rim | **13 leaves + 8 petals** kept alive (respawn on death) | 30 (looping) | 0.15-0.25 / 0.15-0.23 | tangential 6, hugging the floor | `leaf_tumble`, `petal_tumble` |
| `PressDust` | dust kicked along the ground gust | **burst 10** along palm to centre | 0.7-1.1 | 0.45-0.7, growing x2.8 | 7 along the gust | `dust_puff` |
| `BloomDust` + `BloomBits` | the bloom shove | **burst 16 dust + 6 grass bits** | 0.8-1.3 / 2.5 | 0.55-0.9 / 0.2-0.3 | outward 9-14 / 5 + up 4 | `dust_puff`, `grass_bit` |
| `LaunchDust` | the pale dust thrown out by the ring | **burst 26** from r 2.2-3.9 | 0.8-1.3 | 0.55-0.95, growing x2.8 | outward 13-22 + up 0.5-2.5 | `dust_puff` |
| `LaunchPetals` | petals up the column | **burst 18** | 3.0-4.5 | 0.15-0.26 | up 10-26 + tangential 6, then Drag 8.5, falls at about 3 studs/s | `petal_tumble` |
| `LaunchLeaves` | leaves up the column (4 heavy, which overshoot and lag) | **burst 16** (4 at 1.3-1.6x, up 30-36) | 3.0-4.5 | 0.18-0.48 | up 8-22 (heavy 30-36) | `leaf_tumble` |
| `LaunchBits` | grass bits and twigs | **burst 10 + 4** | 1.8-3.0 / 2.6 | 0.2-0.33 / 0.4-0.6 | outward 9 + up 6-14 / up 22-30 | `grass_bit`, `twig` |
| `LaunchPollen` + `LaunchFluff` | the column's fine stuff | **burst 60 + 9** | 2.0-3.0 / 2.6-3.4 | 0.045-0.08 / 0.14-0.2 | up 5-20 | `pollen_dot`, `seed_fluff` |
| `LandDust` | a launched body landing (showcase: the dummy) | **burst 12** | 0.7-1.1 | 0.5-0.8 | outward 7 | `dust_puff` |

**Dust on pale maps (r2, measured).** The dust tint `#D9D1C4` is only about 16 levels lighter than the showcase floor
`#C9C2B8`. At the kit's 0.40 peak alpha, a lit puff therefore lifts a bare pale floor by a median of +3 to +4 levels (p90 +7 to
+8) on the fin_r2 frames, so it does not read there. It does read where it crosses the arms, the grass, the figures and the
dark backdrop. On pale maps, give `PadDust` LightEmission 0.15-0.25, or a paler tint such as `#ECE7DE` (a kit-level
call for the lead). Do not just raise the rate: denser dust turns into a grey smoke ring on dark maps (tested at 40/s).

**Graphics Quality and Reduce Enemy VFX.** These go through the shared emitter helper. Rates and bursts scale with
quality, and things drop in this order:

1. micro-vortices, the eye hairline whirl, hairlines, the haze veils, the press swirl's hairline;
2. `PadFluff`, then half of `PadPollen` and `PadDust`;
3. the lagging pair and rim wisps;
4. rush streaks and the column body pair;
5. at GQ 1-3, the pad arms collapse to `GustPad_Disc`.

**Never drop:**

- the three arms (or the disc);
- the eye whirl;
- the two ring arcs;
- at least two column streaks;
- **r2:** the tightening's pull and hold. They are animation, not extra Beams, so they cost nothing to keep.

These are the tell an enemy reads; this piece's tell is gameplay-critical. The escort wisps are cosmetic, for the
local player only.

Reduce Enemy VFX keeps the arms or disc, the eye whirl and two column streaks, and drops all debris.

## Animation clips

The same rig serves first and third person (the R15 mannequin; hips at 2.0, arms 1.10 + 1.05 + a 0.32 cuff). All times
are in seconds from the key press.

**`GustPad_Place` (3P)**, keys (PoseTrack):

| Time | Ease | Pose |
|---|---|---|
| -0.55 | | the ready stance: staggered, the right foot back |
| -0.20 | io | **the wind-up**, a counter-move UP: the hips rise 0.08, the chest tilts back 0.12, the right palm comes up high (wrist cocked 0.6) |
| **+0.14** | snap | **contact**: dropped to the right knee, the right palm flat on the floor 2.1 ahead (cuff flex +0.95), the left arm thrown back for balance, the head up toward the pad |
| +0.34 | back | settle: the weight keeps going a hair (follow-through) |
| +0.72 | io | rise into a staggered ready stance |
| +1.10 | back | recovered |

**In game the clip must start at the press.** The showcase's pre-press wind-up is a framing for the camera. Compress
it into the first 0.08 s of the clip, keeping at least 3 frames of anticipation, and keep palm contact (= pad spawn) at
about +0.14.

**`GustPad_Place_1P` (FP)**:

| Time | Ease | Pose |
|---|---|---|
| -0.45 | | rest viewmodel |
| -0.18 | io | the wind-up: the right palm high, wrist cocked |
| **+0.14** | snap | **the palm-down press**: a pushing sweep down and forward; the eye drops 0.5 with a crouch |
| +0.36 | back | settle |
| +0.85 | io | recover |
| +1.25 | back | rest |

The pad blooms at the crosshair's floor point, 6.4 studs ahead in the clip.

**`GustPad_Launched` (3P, any rider)**, from L = the launch:

| Time | Ease | Pose |
|---|---|---|
| step-on to L - 0.10 | out | the tightening crouch: knees give 0.36-0.7, arms out for balance, a 11-12 Hz tremble |
| **r2** L - 0.10 to L | io | **the hold**: 0.06-0.08 lower, chest a little further over, hands 0.1 lower, the tremble +40 % (the coil before the release) |
| L + 0.10 | snap | **the clean vertical ascent**. The caster version: right fist punched straight up (wrist 5.95 above the hips), left arm back along the body, legs together, toes pointed (0.6-0.75), chin up. The dummy version: both arms flung up. |
| | | hold, with a small secondary sway (1.2-1.6 Hz, 0.05-0.12 studs) |
| L + 1.05 | io | the apex flail: arms flung wide, legs part |
| L + 1.75 | io | falling: arms up and out |
| landing | snap | a buckle (hips -0.75, arms forward) |
| landing + 0.6 | back | recover |

**`GustPad_Launched_1P`:**

| Time | Ease | Pose |
|---|---|---|
| tightening, to L - 0.12 | out | hands drop low and out |
| **r2** L - 0.12 to L - 0.02 | io | the hold: 0.06 lower, the hands pressing down and out, a small tremble |
| L + 0.14 | snap | arms flung out and down for balance (hands at ±2.3) |
| L + 0.9 | back | settle |

The 1P showcase clip is now 4.2 s, 126 frames (r1 4.0 s). Its launch is at L = 2.36 (r1 2.26): the tightening underfoot is 0.56 s, a
0.46 s pull plus the 0.10 s hold. It ends at L + 0.76 on the escort wisps.

The showcase also pitches the FP view down (about 46° at the tightening, so the spiral swirls between the hands, and down the column after the launch). **Forcing camera pitch is a
gameplay decision; the recommendation is not to force it.** Let the arm pose and the rush streaks carry the launch.

**Bystander reaction (3P caster clip, optional).** A launch within about 6 studs makes nearby casters brace from L + 0.03
(forearm across the face, weight back, `back` ease) and relax by L + 1.4. In the showcase this is shown on the caster.

## Blender stand-ins and their Roblox equivalents

| Blender | Roblox |
|---|---|
| `zk.Ribbon` + `mat_air` (flat, `side=` vectors) | a Beam with FaceCamera false and flat attachments |
| `zk.Ribbon` + `mat_air` (camera-facing) | a Beam with FaceCamera true |
| A Ribbon polyline of 72-80 points | a chain of 2-6 Beams (Bezier segments of 110° or less), Segments 16-20 |
| `u` streak scroll | TextureSpeed |
| `fade` | animate Transparency (NumberSequence) or Width |
| `zk.Particles` (simulated in `Timeline.air`) | ParticleEmitters with Acceleration, Drag and Shape (Disc), on attachments that rotate with the pad. Their tangential emission stands in for the swirl field. Petals and leaves are Orientation VelocityPerpendicular with 4 × 4 tumble flipbooks. |
| `zk.Grass` (blades bending in the field) | **No Roblox equivalent for terrain grass.** If a map uses grass-tuft MeshParts, the shared "wind push" helper can tween them outward (the bloom: 0.3-0.5 rad; the ring: 0.7-1.0 rad) and spring them back with an overshoot. Otherwise the outward petal and grass-bit bursts carry the beat. |
| `zk.Flash` (230 W point light, tau 0.10 s; 90 W in FP) | a PointLight, Color `#EBFFE6`, Brightness 2 to 0, Range 10, over 0.25 s. Keep it dim. |
| `zk.Cloth` (verlet scarf and hair) | skinned scarf tails with a spring-bone script (shared). |
| post: PBR Neutral + bloom 1.25 / 0.14 | the game's ColorCorrection + BloomEffect (a high threshold, so nothing in this piece blooms) |

## Roblox limitations that forced a compromise

1. **A flat decal disappears at grazing angles.** At the gameplay check (30 studs, eye height 7, about 13°) the
   7-stud spiral is about 30 px tall. This is why **the eye whirl exists**: a design addition beyond the brief's flat
   spiral, so the pad has a vertical silhouette from any angle. Keep it at every quality level.
2. **No terrain-grass bending** (see the table).
3. **Beam arcs top out at about 110°**, so every spiral is a Beam chain. Attachments must be repositioned every frame
   (Heartbeat) to spin the pad. A cheap path is to parent all of a layer's attachments to one rotating part and set
   that part's CFrame each frame.
4. **No volumetrics.** The column is Beams and a wide, faint veil Beam. There is no fog or refraction.
5. **Tangential particle motion.** Roblox emitters cannot follow a vortex field. Rotating emitter attachments plus Drag
   approximate it; debris that leaves the pad is ballistic.
6. **r2: two camera-dependent tricks need a client-side step.**
   - Each frame the column streaks pick their core-edge texture variant.
   - The ring sheet's attachments are turned 60 % toward the local camera.

   Both are cheap (a dot product or a CFrame per Beam per frame) and belong in the local VFX script that already moves
   the pad's attachments on Heartbeat. If that is too costly, keep both at their r1 behaviour:
   - one fixed core edge, which loses some of the white-only column outline;
   - the plain shallow cone, a thinner ring from low eye-lines.

---

## 6. Cyclone (Ultimate): handoff spec section

Source: `blender_scripts/zephyr/spring/cyclone_bl.py`, the showcase build. Every number here is provisional look-dev, not
tuning.

**Shared trigger beat:** t = 0 is the Ultimate key press. All times are in seconds from the press.

**Round 2 (lead review, 2026-10-06):** the funnel shells are now multi-start helical bands at a constant helix angle per
layer (they visibly climb; round 1's one-strip-per-shell read as stacked rings), the debris skirt and the travelling arcs
climb too, the ground ring's green arms are fainter and a deeper green, and the first-person camera pitches up during
the climb. The core colour follows the kit's `#EAFFEF`. Everything else is as round 1.

**Spin:** COUNTER-CLOCKWISE seen from above, for everything: the funnel, every air layer, the debris, the ground ring, the
caster's arms in third AND first person, and the dummies' orbit. In Roblox (Y up) that is the angle increasing from +X
toward -Z, the same sense as `ZephyrFX.CyclonePullVelocity`'s `around`.

**Band handedness (r2, important):** the shell bands and the debris skirt are wound CLOCKWISE going up and are turned
COUNTER-CLOCKWISE with the funnel. A turning helix is seen as its stripes sliding across themselves, so these stripes
climb while the funnel turns CCW: the motion reads CCW + up (measured on a test clip: the dominant image motion is up
and to the right on the near wall). Bands wound the other way (CCW-up, along the air's streamlines) would read as a
screw running DOWN when turned CCW. Round 1's near-flat rings measured 5 px/frame downward. The travelling arcs stay
CCW-up: they are short streaks racing round, and they are seen by their ends.

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
| 1.50 – 1.85 | touchdown: full height with a 9% overshoot and settle (damped spring), a glow swell, an open dust arc (r2: 1.35× wide) and a green arc thrown out along the floor (r 3 → 16), a 60-puff dust burst (r2: puffs 1.35× bigger) plus a splash of 26 leaves and 18 petals along the floor, a radial floor shove that whips the grass outward, a soft flash, and a short camera jolt (showcase only; in game a small CameraShake for players within ~40 studs) | ACTIVE starts (`TouchdownKick`) |
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
| Shock-arc annulus | ~256 (64 segments) | An open 310° arc texture. Size is tweened (touchdown r 3 → 16 over 0.75 s, the dust copy's band 1.35× wide (r2); release r 6 → 22 over 0.85 s) and Transparency 0.4 → 1 (ease-out). Two copies on the floor (dust + green), one round the waist at z 9 for the release |
| Grass tufts | ~40 each | 72 short tufts with a few flowers round the foot (r ≤ 17), 12 at the caster's feet. Tweened lean toward the funnel and round it (counter-clockwise); Roblox terrain grass cannot be bent by VFX |

**Low-quality alternative for the funnel shells (r2).** The r2 bands turn rigidly with their layer, so a whole layer can
be one pre-built MeshPart (its N helical bands baked, the soft head at the foot and the frayed tail at the top in the
texture's alpha), rotated by CFrame at the layer's rate:
- outer (6 bands, ~2.5 turns) about 1,200 triangles; mid (5 bands, ~4.4 turns) about 1,800; inner (5 bands, ~8.5 turns)
  about 2,700; calm core (3 bands, ~3.8 turns) about 750, at 16 segments per turn and 2 quads across;
- Size.Y follows the funnel height during the climb (the bands steepen a little while it is short, which reads fine);
- it loses the streak scroll, the form light and the silhouette fray, so use it only at Graphics Quality ≤ 3.

## Textures and flipbooks

| Texture | Size | Content |
|---|---|---|
| `zs_air_strip` | 512×128 RGBA | The `mat_air` look baked for Beams:<br>• a soft, noisy edge across the width, and streak fibres along the length;<br>• colour: shadow `#1F8A4C` → base `#4ADE6B` → light `#A2EAA6` across, sparse accent flecks `#E9F7A4` on the lit edge, 14% desaturated toward `#CFE2D6`;<br>• a thin mint core thread `#EAFFEF` (the kit's r2 core) with gaps;<br>• the tail-fray version (fibres only) in the right quarter. r2: the outer and mid bands use that fibres-only quarter for the Beams at the funnel's silhouette (see the soft rim).<br>Beam.Color stays near white; the form light comes from Color (below). |
| `zs_air_strip_deep` | 512×128 | r2: the ground ring's green arms. The same build shifted toward the shadow green (`#1F8A4C` → `#4ADE6B`, no light band), the core thread at 60% width and half strength |
| `zs_air_strip_pale` | 512×128 | The calm core's palette: `#8ED9A2` → `#BDEFC4` → `#E2F8E0`, core `#EAFFEF` |
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

**Funnel shells (r2: helical bands).** Each layer is N bands, multi-start helices at a CONSTANT helix angle A above the
horizontal, so every band visibly climbs from the narrow foot to the wide top. (Round 1 wound one strip per shell at a
constant pitch, about 3° at the top: it read as stacked rings and slats.) A band's turn by height z is
θ(z) = G(z) / (tan A · rmul), with G(z) = ∫ dz / r(z) over the funnel profile (G(40) = 7.80). The bands are wound
CLOCKWISE going up and the layer turns COUNTER-CLOCKWISE (see "Band handedness" above). Each band's angle is its layer's
range, one value per band. Lay each band in the cone's surface by orienting its attachments; the upper edge is the lit
one.

| Layer | Radius | Bands | Helix angle | Turns (at 40 studs) | Width foot → top | Spin (rad/s) | Body alpha | Beams (4 per turn) |
|---|---|---|---|---|---|---|---|---|
| Outer | 1.00 R | 6 | 24–29° | 2.2–2.8 | 2.5 → 5.5–6.5 | 0.30 x 6.4 = 1.9 | 0.34 | ~60 |
| Mid | 0.76 R | 5 | 18–22° | 3.9–4.9 | 2.1 → 3.8–4.6 | 0.62 x 6.4 = 4.0 | 0.28 | ~88 |
| Inner | 0.50 R | 5 | 14–17° | 7.6–9.3 | 1.6 → 1.9–2.4 | 6.4 (367°/s) | 0.30 | ~168 |
| Calm core (pale) | 0.22 R | 3 | 52–58° | 3.4–4.2 | 2.2 → 6.9–7.4 (overlapping: a pale column) | 0.15 x 6.4 = 1.0 | 0.40 | ~45 |
| Veil (heat-haze stand-in) | 1.36 R | 1 | (r1 band, 1.1–1.3 turns) | | | 0.25 x 6.4 | 0.13 | 5 |

About 360 Beams at 4 per turn; at 3 per turn with CurveSize doing the bend, about 270. If that is too many, the inner
layer is the first to go to its MeshPart (below): it is mostly seen through the outer one.

Shell parameters:
- **Beams:** 4 (or 3) per 360°, CurveSize ≈ 0.55 × the arc's radius, Segments 10.
- **TextureSpeed:**
  - outer 1.3 (the kit's scroll × 4.5 studs/s);
  - mid 1.7;
  - inner 2.4;
  - core 0.45 (calm).
- **LightEmission:** 0.2. The core's thread is baked in the texture.
- **Width:** wmul × max(2π r sin A / N, wmin), with wmul 0.95 (calm 1.40) × (0.85–1.15 per band) and wmin 2.6 / 2.2 /
  1.7 / 1.6 studs (outer / mid / inner / calm) × the funnel's width scale. The N bands tile the cone at their slope; the
  floor width makes them overlap in the narrow lower funnel (the dense rope of the foot). Each band swells and pinches
  ±36% along its length (wavelength 7–11 studs), and its opacity follows the same wave (0.28–1.0×): puffs of air along the band.
- **Each band's foot** sits at z 0–1.6 and stays there; the band grows upward with the funnel. Through the thinning the
  foot fades upward (per-Beam Transparency from the lifting foot height), it is not cut.
- **Wall ripple:** radius × (1 + 0.045 sin(3 × azimuth − 3.6 t)), running CCW round the funnel.
- **Form light:** Color per Beam = lerp(shadow tint 0.78, light tint 1.0, l), with l = 0.5 + 0.42 cos(the segment's azimuth − the key's azimuth) + 0.14 (z/H − 0.5). That is the Blender `l` attribute.
- **Opacity:** Transparency NumberSequence 1 → body → body → 1 along each Beam.
- **Front/back:** opacity × (0.8 + 0.2 × the segment's facing): the near wall at 1.0×, the far wall at 0.6× (r1 wrote 0.8×; the formula was always this).
- **Soft rim and silhouette fray (r2, the outer and mid layers):** where a segment is seen edge-on (the funnel's
  silhouette), its opacity drops to 0.5×, its width to 0.6×, and it breaks into its streak fibres (the strip's
  fibres-only quarter), so the funnel's edge frays into thin ribbons instead of stacking into tabs. Full strength by
  the time the segment faces the camera at ~25° off edge-on (mid layer: 60% of the effect). In Roblox: per Beam, from
  the dot of the segment's outward normal with the camera direction (client-side, cheap), swap Texture to the fibres
  strip and narrow Width; or accept harder edges on low Graphics Quality.
- **Kit OPACITY / VIBRANCE (developer, 2026-10-06):** every "body alpha" in this section is multiplied by 1.69 on
  screen (e.g. outer 0.34 → 0.57 opacity, Transparency ≈ 0.43), and every colour gets saturation × 1.69 after the 24%
  grey-mint desaturation (outer shell 30%). Bake both into the strip textures.
- **Form light strength:** the shells' `l` term is scaled 0.75 (lit_k), so the far side reaches the shadow green
  `#1F8A4C` and the key side the light body `#A2EAA6`; Beam.Color per segment spans tint 0.70 → 1.0.

**The funnel's whole rotation.** All attachments of a layer sit in one invisible part rotated about the axis each frame,
so a layer turns as one piece (its bands' stripes climb as it turns). The spin follows the arms through the climb (spin =
ω_arms / 15), holds at 1, surges ×1.35 at the release (decay 0.22 s), and slows by 72% through the thinning. Height H(t)
follows the arms' climb (up 40 studs by 1.50, with the 9% overshoot). Radii scale (0.5 + 0.5 g)(1 + 0.4 thinning).

**Travelling arcs (16).** The identity's open spirals, never closed. Each is an attachment that orbits the axis at
0.55–1.1x spin for 1.1–1.7 s, climbing 0.28 H over its life, then respawns at a new height and angle. r2: each arc
climbs at a helix angle of 11–20° (tan 0.20–0.36) along its own length, over 110–200° (sheets) or 140–220° (hairlines),
and stays inside the funnel's height. Round 1's arcs rose 0.18–0.30 H per turn (about 6° at the top) and read as rings.

| Kind | Count | Trail Width | Lifetime | Body alpha |
|---|---|---|---|---|
| Sheets | 8 | 0.30–0.42 × the funnel radius there (tapered) | 0.45 s | 0.36 |
| Hairlines | 8 | 0.10–0.16 studs (FaceCamera on), widening 1.6× toward the top | 0.55 s | 0.55 |

Both use LightEmission 0.25.

**Other air shapes:**

| Shape | Count | Spec |
|---|---|---|
| Debris skirt round the foot | 6 Beams (3 dust, 3 green) | r2: spirals r 2.9 → 7.5 wound CLOCKWISE going up over 0.55–0.7 turn, z 0.15 → 6–9 studs, turned CCW at 0.8–1.0× spin (their stripes climb, as the shells'); 2–3 Beams per spiral. Width 1.1 → 2.6 (dust 1.25×), narrowing 35% and fraying at the silhouette as the outer shell does. It stays on the floor and fades out over 4.50–5.20 as the foot lifts. (Round 1: 0.85 turn over 4–6 studs, wide flat strips that stacked into slats and lifted with the foot as a stack of rings) |
| Ground ring: a three-arm pinwheel | 6 Beams, flat (3 green + 3 dust, interleaved 60° apart) | Each arm is an open spiral of 225–255° at z 0.06–0.16, running from its head at r 4.2–4.8 (the inner, counter-clockwise-most end, where the inflowing air goes) out to its tail at r 14.5–16 (dust +0.5 / +0.8), trailing clockwise like the floor's inflow streamlines. Width grows head → tail 0.5 → 1.3 × (dust 2.2, green 1.5 × 1.25). Alpha: green 0.14 (r2; was 0.25), dust 0.60. r2 (lead note: the green arms read as glowing lines on the dark backdrop): the green arms are 0.85× (was 1.25×) wide, a deeper green (`zs_air_strip_deep`, emission 0.50 against the body's 0.82: LightEmission ≤ 0.12), and their core thread is 0.03 wide (was 0.06) at 0.3 strength. Bursts out 38% at touchdown (sin pulse 0.55 s; r2, was 30%). Spin 0.3×. The earlier nested arcs (dev1–8) overlapped into what read as closed rings; the pinwheel reads as an open spiral at any distance |
| Inflow streaks | 8 Trails (FaceCamera on) | The field's own floor streamlines: inward spirals from r 14–19 to r 3.6 at z 0.5–2.6. Each a 0.5-length window sliding inward over 1.1–1.6 s, at a new angle every cycle. Width 0.35–0.6, alpha 0.5, LightEmission 0.25. On from 0.9 s, off after the release |
| Seed swirl | 3 small Beams | At the crosshair, 0.06–1.15 s: r 0.5 → 2.1, rising 0.4 → 3 studs, 9 rad/s |
| Hand trails | 2 Trails + 2 hairline Trails | Wrist attachments, Lifetime 0.5 s (r2: 0.75 s in first person). Width 0.42 → 0.06 (×0.85 in first person). r2, first person: the attachment sits at the palm's tip (0.35 × the cuff beyond it) and 0.30 studs up, so the loop is drawn over the cuff block, not inside it. The hairlines are 0.06 wide, offset 0.22 outward. On through the climb (they draw the corkscrew), faint in the channel |
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
| Touchdown dust | burst 60 at 1.50 | 1.0–1.8 s | `dust_puff`, 2.0–3.5 (r2: 1.35× round 1's 1.5–2.6) | Outward 12–20, tangential 8 |
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
- **Camera pitch keys:** -0.44 at the dip; 0 at 0.95; +0.34 at touchdown; +0.24 in the hold; 0 at the thrust. r2 (lead
  note: keep the spiral readable): plus a pitch-UP bump of +0.20 rad through the climb (in from 0.28 to 0.70, out from
  1.15 to 1.75), so the hands are seen a little more from below and their trails loop above the forearm blocks: the
  pitch runs -0.44 at 0.28, -0.07 at 0.60, +0.13 at 0.80, +0.18 at 0.95, +0.40 at 1.30, +0.42 at touchdown, +0.30 at 1.70.
- **Camera roll:** a 0.03-rad roll with the hands during the climb.
- **Head:** cancels the body's winding, so the camera stays steady.

## Blender stand-ins and their Roblox equivalents

| Blender (showcase) | Roblox |
|---|---|
| `mat_air` / `mat_air2` ribbons (alpha-blended emission, procedural 4D noise streaks scrolling at 4.5 × scroll studs/s) | Beams / Trails with `zs_air_strip`, TextureSpeed, LightEmission 0.2, Transparency NumberSequence |
| `mat_air2`'s per-vertex light term `l` (local override) | Beam.Color per segment from the segment's azimuth to the key |
| `mat_air2`'s per-vertex fray term `x` (r2 local override: the outer and mid bands break into their streak fibres at the silhouette) | Per Beam: swap Texture to the fibres-only strip and narrow Width where the segment is edge-on to the camera |
| The r2 helical bands (`LRibbon` strands posed per frame, wound clockwise-up, the layer turned CCW) | Beam chains on attachments inside one invisible part per layer, rotated by CFrame; or one MeshPart per layer on low Graphics Quality |
| `zk.Particles` in one flow field (Rankine swirl, floor inflow, corner updraft, wall inflow, top outflow, the caster's arm vortex, the thrust's gust, the release burst) | LockedToPart emitters on three spinning parts + Acceleration / Drag; a separate inward floor emitter |
| `zk.Grass` (spring-bent blades) | A few tuft MeshParts tweened inward and counter-clockwise; terrain grass cannot be bent |
| `zk.Cloth` (scarf, hair) | Character cloth, or a scarf accessory with a simple spring bone |
| The dummies' juggle simulation (the game's `CyclonePullVelocity` with EyeRadius 4.6, OrbitSpeed 14, JuggleHeight 8 ± 2.2, period 1.1 s; dropped, not flung, at the release: horizontal speed capped at 6 + 2.5 outward) | The existing server/client pull. The showcase's EyeRadius is 4.6 against the game's 3, so the dummies orbit just outside the visible wall |
| `zk.Flash` point lights | PointLight tweened |
| EEVEE alpha blending, bloom 1.25 / 0.14, PBR Neutral | Roblox transparency sorting; Bloom post (keep Threshold high); ColorCorrection |

## Roblox limitations that forced compromises

- **Particles cannot ride a custom flow field.** The spinning LockedToPart parts approximate debris riding the air; three
  spin rates restore "debris at different speeds". Without them, debris orbits rigidly.
- **Transparent Beams sort per object, not per pixel.** With about 270–360 beams in a cone (r2's helical bands), expect occasional pops in sort
  order. Keep the far wall fainter (the 0.6× back-wall factor) so a mis-sort is a minor brightness change.
- **No per-vertex alpha on MeshParts.** The low-quality MeshPart shells lose the soft head/tail and the form light.
- **First person.** The R15 arm blocks at FOV 70 fill the lower corners whenever the hands are raised in front. A
  ViewportFrame viewmodel layer with its own FOV (about 55) or 0.8× arms would let the spiral read better. The showcase
  keeps the honest rig.
- **The unwind.** The game's 0.5 s UNWIND is shorter than this look's 1.8 s slow thinning. The look can outlive the
  gameplay (nothing is caught in it).
