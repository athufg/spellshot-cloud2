# Zephyr v4 handoff spec (Roblox Studio build)

The look recipe is `RECIPE.md`. All numbers are provisional. "t" is seconds from the key press: the shared trigger beat
of the first-person (FP) and third-person (TP) clips.

## Shared assets (every piece)

**Textures** (all greyscale; the colour comes from the Beam / particle `Color` sequence on the heat ramp
`#125C59 → #1F6F6A → #2FB5A8 → #4FD1C5 → #9CE6DF → #EFFFFB`):

| Texture | What it is |
|---|---|
| `T_ribbon` (256×64) | The alpha ramp: soft feathered edges, a short head fade, the tail fraying into streaks |
| `T_streak` (256×64, tiling along U) | Scrolling noise fibres; run it on Beam `TextureSpeed` 1.5–3 |
| `T_core` (128×16) | A crisp white thread with tapered ends |
| `T_puff` (64²) | A soft round glow |
| `T_spark` (64²) | A four-point star |
| `T_dust` (64²) | A soft blob |
| `T_mist` (64²) | A stretched soft wisp |
| `T_scuff` (128×32) | A dark streak with a faint centre line (a decal) |

**Beam settings by layer:**

| Layer | Segments | LightEmission | Width | Notes |
|---|---|---|---|---|
| Core | 10–16 | 1 | 0.1–0.2 studs | |
| Glow | 10–16 | 0.8 | 0.4–1.4 studs | alpha 0.35–0.65 |
| Arc | 8–12 | 0.8 | 0.05–0.25 studs | thick to thin |
| Vapor | 10–16 | 0.3 | 1–2.5 studs | alpha 0.3–0.45 |

**Bloom:** Lighting.Bloom threshold about 0.9, intensity about 0.4. The core is the only thing meant to cross the
threshold.

**Chips:** one MeshPart, a jittered octahedron (8 tris), dark slate `#262E32` with deep-teal flecks; 6–12 per burst.
The emitter's `Shape` is part burst, with gravity.

**Scarf:** two Beam tails, 3.4 and 2.8 studs, pale aqua `#A8E9E2`, on Attachments with spring-damped follow (a
"WindTrail" script). Blender's verlet cloth is the stand-in.

**Distortion (Blender only):** `mat_shimmer` is a refractive veil. Roblox has no screen refraction. Use a faint
`T_streak` vapor Beam (Transparency 0.9, TextureSpeed 4) as the "heat ripple" instead.

**Graphics Quality / Reduce Enemy VFX, drop order:**
1. arcs (halve, then off);
2. vapor;
3. specks and mist;
4. sparks;
5. halve puffs and dust.

Never drop the core or the main glow ribbon: they carry the silhouette and the colourblind white.

**Hit feel:** hit-stop 1–2 frames (actors only), a PointLight flash (Range 10–14, Brightness 4–6, about 0.08 s decay),
a dust burst, chips and sparks, and a hard dummy reaction.

## 1. Wind Blade (M1): the leanest

**Per shot:**
- 1 core Beam, 2 glow Beams and 2 accent arc Beams on a moving Attachment pair;
- 1 vapor wake Trail (lifetime 0.12 s);
- 1 ripple ring, a small mesh ring with the vapor texture, 0.3 → 0.9 studs over 0.32 s;
- 1 impact vapor ring, 0.4 → 1.2 studs.

That is 8 effect objects per shot. Particles per shot:

| Particle | Count |
|---|---|
| Path dust | 2 |
| Speck | 1 |
| Impact dust | 3 |
| Chips | 2 |
| Sparks | 3 |

**Other numbers:**
- At most 5 shots alive at once.
- The arc is 1.25 studs radius over 115°, max width 0.42 studs, pointed at both ends, flying at 150 studs/s.
- The hand swirl: core + glow, 0.14 s before release, a 270° open spiral winding into the palm.

**Animation:**
- Shots: release 0.06 s after each press, 0.125 s apart, alternating hands.
- FP clip `WB_Flick_R/L`: cock at −0.03 s, snap at 0.
- TP clip `WB_Flick_TP`: the same, plus chest yaw ±0.08 rad and hip counter-rotation.

## 2. Cross-Slash Dash (Primary)

**Charge** (t 0.10–0.50): around the crossed forearms, 1 core Beam + 3 glow Beams in a 300° open spiral shrinking from
2.6 to 0.7 studs, plus 10 arc Beams. Dust (26) and specks (30) rise in a vortex, and 8 puffs gather.

**Dash** (0.50–0.76):
- 1 core and 3 glow Trails on the chest Attachment (lifetime 0.2 s);
- a vapor tunnel: 6 Trails on Attachments orbiting at 1.0–2.6 studs;
- the shimmer stand-in;
- a dark scuff decal Beam along the floor, fading over 1.5 s;
- a dust trench: about 46 dust, 46 specks and 10 chips along the path.

**The X** (slice 1 at 0.827, slice 2 at 0.849, the crossing at 0.861):
- Per cut: 1 core, 3 glow and 1 soft wide (2.6 studs) Beam, drawn on over 60 ms.
- 16 arc Beams.
- It holds 0.33 s, then frays over 0.5 s.
- One soft vapor ring, 1 → 3.2 studs. The two big shock rings were removed at the developer's request.
- The burst: dust 34, chips 26, sparks 32, puffs 16, specks 34, mist 8.
- Flash 900 W, 2-frame hit-stop, camera shake.
- The dummy is thrown back about 5.5 studs.

**Animation:**
- FP: `CSD_Charge_FP`, a cross with a tremble from 0.2 to 0.46, then a snap out at 0.63.
- TP: `CSD_Charge`, `CSD_Dash` (from 0.50), `CSD_Slash` (0.76), `CSD_Recover` (1.0–2.6).

## 3. Updraft (Passive)

Shown only while airborne. It builds over 0.12 s from take-off and thins over 0.42 s after landing.

**Effects:**
- 1 core, 3 glow and 3 arc Beams as helices round the legs (radius 1.2–1.8 studs, 3.7 studs tall), the head at the top
  (the air rises).
- An emitter at the feet:
  - specks: 40/s, lifetime 0.4–0.8 s, rising;
  - sparks: 14/s.
- On an aerial hit (t 0.735): a glow ring of radius 1.6 climbs the spiral in 0.25 s.

**Animation:** none of its own. The scarf and hair react: they twist and stream upward.

## 4. Skyrider (Technique)

**The bird** (about 35-stud span):
- **Body:** a spine of 1 glow and 1 core Beam chain, plus crown and belly glow Beams, 3 helix arc Beams, 3 crest plumes,
  beak and eyes.
- **Each wing:**
  - a leading-edge glow Beam plus a core Beam;
  - 1 covert sheet (an alpha mesh);
  - about 8 long feather Beams (thinning toward the tips, not combs);
  - 2 hairlines;
  - 2 wingtip vortex Trails (a helix offset, lifetime 0.2 s).
- **Tail:** about 5 glow Beams.

That is about 45 Beams. Drive it as a skinned or animated rig of Attachments, with Beams between them.

**Particles:**
- glow wisps shed from the body: 9/s;
- sparks: 5/s.

**Low-mana tell:** fade to 45 % and flicker.

**Beats:**
- **Gust** (t 3.34): 4 vapor ripple rings ride the cone front, plus 8 glow streaks converging on the axis, a dust sweep
  at the floor (36 dust, 14 chips, 30 specks) and a flash at the hit.
- **Hit wobble** (4.70): 10 sparks and 8 puffs shed.
- **Dismount** (6.20): everything scatters outward and fades over 0.6 s; 40 puffs, 30 sparks and 14 mist.

**Animation:**
- TP: `SR_Summon` (0–0.52), `SR_Kneel` (with a bank lean), `SR_Flap` (2.95–3.40), `SR_Wobble` (4.70), `SR_Fall` (6.20).
- FP: hands braced low and attached to the camera; the camera rolls 0.2× the bank.

## 5. Gust Pad (Technique)

**The pad** (radius 3.4 studs):
- 1 core and 3 glow Beams as a flat 250° open spiral rotating CCW, plus 6 small arc Beams.
- A faint floor ripple ring every 1.6 s.
- Idle particles: dust circling 8/s, glow puffs 4/s, sparks 2/s.
- When stepped on, the spiral pulls in 38 % with a 0.10 s hold.

**The launch:**
- a core beam column up to 18 studs;
- 4 glow Beams spiralling up the column;
- 2 vapor sheaths;
- 10 arc Beams;
- a base vapor ring, 1.5 → 6 studs;
- the blast: dust 26, chips 14, sparks 20, specks 30.

**Animation:**
- TP: `GP_Press` (wind-up from −0.2, palm on the floor at 0.14) and `GP_Launched`, a vertical ascent pose.
- FP: `GP_Press_FP`.

## 6. Cyclone (Ultimate)

**The funnel** (40 studs tall, radius 2.6 → 13.5, spinning CCW), from the outside in:
- 8 slow vapor skin Beams (0.35× spin);
- 10 fast glow thread Beams;
- a core braid of 2 Beams;
- arcs at 3 heights (8 each).

The helix angle is constant, so the stripes climb.

**Ground:**
- 4 scuff spiral decals;
- a touchdown vapor ring, 4 → 14 studs;
- the ring burst: 40 dust, 20 chips, 20 sparks.

**Continuous particles:**
- inflow dust: 22/s from 7–16 studs out;
- specks: 22/s;
- sparks: 13/s;
- chips: 5/s thrown up;
- mist and puffs at the top.

**Hands:** a glow and a core Trail on each hand trace the corkscrew.

**Animation:**
- TP: `CY_Corkscrew`, the arms tracing CCW circles that widen and climb (t 0.28–1.50); `CY_Channel` (to 4.00);
  `CY_Thrust` (4.28).
- FP: the same climb with the camera pitched up.
- The funnel's height and spin are keyed to the arm climb.

## Blender stand-ins → Roblox

| Blender | Roblox |
|---|---|
| Ribbons | Beams / Trails |
| Sprite batches | ParticleEmitters |
| `mat_shimmer` refraction | A faint scrolling vapor Beam (no refraction) |
| Verlet scarf | Spring-follow Attachment chains |
| Compositor glare | Lighting.Bloom |
| Flow-field debris | Emitter `Acceleration` / `Drag` / `VelocityInheritance`, plus scripted orbit (`SpreadAngle` and per-frame `Velocity` for the Cyclone inflow) |
