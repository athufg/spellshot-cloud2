# 5. Gust Pad (Technique): handoff spec (round 2)

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
