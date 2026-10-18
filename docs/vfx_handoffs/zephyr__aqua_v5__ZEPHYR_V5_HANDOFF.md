# Zephyr v5 handoff spec (Roblox Studio build)

v5 builds on `../aqua_v4/ZEPHYR_V4_HANDOFF.md`. Unchanged from there: the shared textures, the Beam settings by layer,
bloom, chips, the scarf, the Graphics Quality drop order and the hit-feel rules. This file lists what v5 adds or
replaces.

All numbers are provisional. "t" is seconds from the key press.

## New shared assets: surfaces over wires

**Surface meshes** (`Sheet` / `Shell` in Blender) become alpha MeshParts with a baked gradient texture `T_surf`
(256×256):
- heat runs along the chord (bright leading edge → deep teal trailing edge);
- a streak noise on the second UV channel, scrolled with a `Texture` offset tween or a 4-frame flipbook;
- a feathered, fraying edge in the alpha.

The thick look at grazing angles is a second copy of the mesh, scaled 1.04 at half alpha. Roblox has no facing ratio.

**Feather blades** (`Blades`): one 128×32 texture, `T_feather`:
- a root-bright → tip-deep gradient;
- a centre vein;
- faint barbs;
- a frayed tip.

Each feather is a 2-triangle card, or 12 triangles when curled, on the bone's Attachments.

**Funnel shells:** open-ended alpha cylinders/cones, 16 sides × 8 rings ≈ 256 triangles each, spun with
`CFrame.Angles` per frame at a different rate each. The texture is a streak noise; heat runs by height, a darker dusty
base to a brighter top.

## 1. Skyrider (rebuilt)

**Hero bird budget: about 3,000 triangles**, with smoothness carried by normals, alpha gradients and the soft-rim
duplicate shells.

| Part | Triangles |
|---|---|
| Body (lofted ellipse, 12 sides × 8) | ≈ 190 |
| Head and beak | ≈ 120 |
| Wings, per side: 3 membrane panels (arm, forearm, hand, each 4 × 4 quads) | 96 |
| Wings, per side: coverts 12 | 96 |
| Wings, per side: secondaries 14 | 140 |
| Wings, per side: primaries 8 | 96 |
| Tail fan (7 blades) | 84 |
| Rim duplicates | the rest |

**Rig:** bones are shoulder → elbow → wrist → tip per wing, plus spine, neck, head and tail. The membrane panels are
skinned to their own bone, so the joints read as separate plates. Spar Beams run per bone, with knuckle highlights (a
short glow Beam along the chord) at the elbow and wrist.

**Flap clip** (`SR_Flap_Cruise`, looping 0.9 s):
- **Downstroke:** extended, pronated about 0.3 rad at the tip.
- **Upstroke:** the elbow sweeps back about 0.6 rad and the wrist about 0.95 rad, the hand trailing and lifting last;
  supinated about 0.34 rad.
- **Lag:** the hand lags the arm about 0.035 s per joint. Feather tiers lag their bone by 0.02 (coverts), 0.045
  (secondaries) and 0.075 s (primaries). Drive the tiers as Attachments on a lagged spring.
- **Primaries:** fan 12–78° from the span; they flare on the stroke and fold when mana is low.

**Gust clip** (`SR_GustFlap`, trigger t = 3.30):
- wind-up 2.95–3.30: the wings cock up and back, and a compression spiral of 1 core + 2 glow Beams forms under the
  chest;
- the stroke at 3.30.

The cone is Beams on a moving front, travelling about 30 studs in 0.5 s (`cone_front`):

| Element | Count | Notes |
|---|---|---|
| Pressure crests | 2 per wing (core + glow) | Drawn from the leading edge at 3.30 and pushed forward |
| Wavefronts | 5 × 3 | Pointed 95° arc Beams, 0.05 s apart |
| Streamlines | 8 | |
| Vortex threads | 2 | |
| Vapor edge | 6 | Trails, thinning over 1.2 s |
| Trench decals | 5 | Revealed with the front |

**Particles:**
- dust fan: 60 (emitter `Shape` = a box along the footprint, `EmissionDirection` = cone axis, speed 10–18);
- chips ahead of the front: 22;
- per hit: sparks 14, puffs 6, dust 10, plus a dust trail (an emitter on the dummy, 20/s for 0.6 s);
- 2-frame hit-stop.

The near dummy is hit at TH1 ≈ 3.62, the far one about 0.1–0.15 s later.

**First person:** FOV +9° with a 0.06 rad roll kick on the stroke. Peripheral streaks are 6 camera-relative Beams.

**Rider fill:** a PointLight on the rider (Brightness 1.5, Range 8), so the rider reads against the bird.

## 2. Cyclone (rebuilt)

**Meshes:** 3 shells at radius factors 1.08 / 0.82 / 0.55, alpha 0.30 / 0.42 / 0.45, spin factors 0.30 / 0.65 / 1.10 ×
the funnel spin. That is ≈ 770 triangles.

**Beams:**

| Element | Count | Notes |
|---|---|---|
| Thick flat ribbons | 18 | Width 1.4–3.4 studs, lying on the funnel surface (Beam `FaceCamera` false, Attachments on the shell), each with its own tilt and speed |
| Flare ribbons | 5 | Swinging out past the top |
| Diagonal streaks | 6 | Core + glow, looping every 0.6 s |
| Core glare | 3 | Core 0.35 + glow 1.6 + glow 3.4 studs wide |
| Base disc | 6 | Flat spiral Beams, radius 4 → 13 |
| Vapor streamers | 5 | Off the rim |

**Rings:**
- an expanding ground ring, 3 → 18 studs, at t 0.3–1.4;
- a ring pulse up the funnel on each juggle hit (t 1.85 + 0.42k);
- a release pillar of 10 vertical streak Beams (t 4.38–4.93, the funnel radius × 0.38, height × 1.3).

**Particles:**
- the v4 inflow set;
- pebbles orbiting at heights: 12/s;
- hit sparks: 12 per hit;
- a final dust ring of 40, lifetime 1.5–2.5 s.

**Graphics Quality:** drop the flare and streak Beams first, then the disc, then one shell (keep the outer and the
inner).

## 3. Updraft (stronger tell)

Added to v4:
- **Torso helix:** 2 glow Beams.
- **Under-feet disc:** a 10 × 22 alpha disc mesh (≈ 400 triangles; use a 64-triangle disc with a spinning swirl texture
  in Roblox), plus 3 spiral-arm Beams.
- **Ankle trails:** 2 Trails (glow) + 2 Trails (core), lifetime 0.3 s.
- **Dust swirling in the disc:** 25/s.
- **Landing:** a downdraft puff (16 dust) and a scuff ring decal (fades over 1.2 s).

## 4. Wind Blade (body added)

**Per shot (13 effect objects; pool of 5):**

| Object | Count | Notes |
|---|---|---|
| Lens | 1 | A lens mesh, 11 × 5 (≈ 80 triangles; Roblox: a 16-triangle lens card pair) |
| Core Beam | 1 | |
| Glow rim | 1 | |
| Accent arcs | 2 | |
| Wake Trail | 1 | |
| Spiral wake | 2 | 2 thin Beams |
| Ripple ring | 1 | |
| Impact ring | 1 | |
| Radial scratch decals | 3 | Fade over 0.5 s |

**Particles per shot:** dust 5, speck 1, chips 2, sparks 3.

**Knockback:** 1.5× v4.

## 5. Cross-Slash Dash (polish)

Added:
- a faster extra charge arm (1 glow Beam, 16 rad/s);
- 36 extra dust pulled from the feet;
- a stronger tunnel: 4 vapor Trails at radius 1.4 → 3.6;
- an afterimage: 4 sheared glow Beams, t T_DIS → +0.9 s, alpha 0.4 → 0;
- an X scuff decal pair under the target, fading 2.4–3.3 s;
- the slash pose held 0.14 s longer.

## 6. Gust Pad (polish)

Added:
- a rim of lifted dust (12/s);
- a ring of 16 tick-mark Beams turning at 0.35 rad/s;
- a faint idle shimmer column: an alpha cylinder 14 studs tall, alpha about 0.1 (Roblox: one cylinder MeshPart with a
  scrolling streak texture, Transparency 0.9);
- a bigger launch vapor ring (2.5 → 10.5 studs);
- 18 extra chips per launch.

## Blender-only → Roblox

| Blender | Roblox |
|---|---|
| Subdivision smoothing | Pre-subdivided low-poly meshes with smooth normals |
| Layer Weight thickness | A duplicate rim shell |
| `mat_shimmer` refraction | A faint scrolling vapor mesh (no refraction) |
| N·key light side | Baked into the texture gradient plus `LightInfluence` 0.3 |
| Flow-field debris | Emitter `Acceleration` / `Drag`, with scripted orbit for the Cyclone |
