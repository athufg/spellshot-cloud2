# Cryo "Frost Lotus" — handoff spec (Rare Element Skin, working name), 2026-10-15

**Cosmetic only.** Damage, range, hitboxes, timing, fire rate, cooldowns and every beat are the Default's; the Default look is
untouched unless the skin is equipped. Identity = the **object**: every piece is soft, curved ice **lotus petals** — broad,
rounded-shouldered, cupped across, an S-curve along the length, a soft pointed tip — in the shipped Cryo v2 real ice: a
deep-blue heart (`#1D6FB8`), a pale ice-blue body, frosted white tips, the **Frost Line** (`#3FE0FF`, flash `#8DF3FF`) on
the outer petals' edges, a glowing cyan-white heart (`#C8F6FF`, never gold) in every bloom. Renders, mp4s, frame sheets,
game stills and stats per piece are in this folder; overview `FROST_LOTUS_OVERVIEW.png`; the Blender kit is `kit/`
(`fl.py` petal / lotus / sparkles, `fl_field.py` field / body / dome / lance, `fl_m1.py` the hold-and-pluck,
`fl_final.py` the pieces subclassing the shipped v2 ones). Checkpoint history: `CHECKPOINT_FROST_LOTUS.png` (round 2),
`FROST_LOTUS_ROUND3.png` (round 3, approved), `_superseded/`.

**Layers.**
- **Base:** the remodel. The petals, blooms and lance replace the crystals, panels and bolts.
- **Rare:** the sparkle layer (dew glints + ice glitter) and the extra petal particles. Its own switch: `IceMagic` attribute `FrostLotusSparkles = false`.
- **Hold-and-pluck:** the M1 hold-and-pluck animation. Its own switch: `IceMagic` attribute `FrostLotusPluck = false` falls back to the Default's alternating throw, with the dart still the shot.

**Shared Roblox recipe.**
- **Petal mesh:** each petal and bloom is an EditableMesh-built MeshPart (`FrostLotusKit`) in the Ice material (Transparency 0.25, Reflectance 0.15).
- **Colour:** the colour lives in the vertex colours (heart → body → white tip), so no texture upload is needed.
- **Glow parts:** a Neon part for each bloom's heart, and a Neon part for the Frost Line strips on the outer ring's rims.
- **Sparkles:** `ParticleEmitter`s using the built-in `sparkles_main.dds`: dew is a four-point star, glitter a fine mote.
  - Colours are pale white-cyan (`#E6F7FF`, `#D6F1FF`), and LightEmission (0.4–0.6) stays under the Frost Line's.
  - Never a flash: they fade in over about 0.35 of their life and out over the rest.
  - Reduce Flashing gives a steady, dimmer glow with no spin.
- **Scale-down:** every count scales with Graphics Quality and Reduce Enemy VFX (`FrostLotusKit.Tier`: high / medium / low).
- **Colourblind-Safe:** the swap changes nothing, because shape carries the identity.

## 1. Icicle Shard (M1) — the petal dart
- **Look:** one broad cupped petal, 1.3 × 0.36 studs, in place of the six-facet shard. Its flat faces the side, and the tip sits on the shot point.
  - It trails 3 tiny petal motes and the Default's Frost Line trail, so it reads about 3.4 overall.
  - Each hit opens a tiny 6-petal bloom that fades within 0.9 s, with a dew glint.
- **Length:** the shard's 3.3–3.9 length class can't be one broad petal inside the hit (a ray down the centre line, with 1.5 studs of server slack), so the petal is 1.3 and the motes and trail carry the length.
- **Roblox:** `FrostLotusKit` kind `Dart` (1 MeshPart, 36 tris), through VFXLibrary's shard look (`acquireKunaiLook(lotus)`, its own pool). The hit bloom is `FrostLotusFX.HitBloom`.
- **Budget vs Default:** 1 part / 36 tris in game (Blender 38) vs 1 / 34.
  - Particles: the Default's, plus (Rare) 3 motes, 2 dew and 4 glitter per shot.
  - The hit bloom: 2 parts / 204 tris for under a second.
  - Lights: = Default.

## 2. M1 hold-and-pluck (the developer's request)
- **Motion:** the **left** hand holds an ice lotus (11 petals round a glowing heart). The **right** hand, in one fast continuous motion, reaches across to the lotus, plucks a petal and throws it.
  - The plucked slot regrows at once: the petal unfurls over 0.12 s with a glint, so the lotus always reads full.
  - The lotus appears with the first shot and folds away **1 s after the last** (PROPOSAL, approved).
  - Any other cast lets it go at once, so it's never carried into another ability.
- **Timing is law:**
  - Third person: the release is CastPose's `Trigger` 0.12 s after the click, inside the Default's 0.453 s clip.
  - First person: the release is the viewmodel's 0.107 s `Trigger`.
  - Held M1 chains every 0.333 s (`AbilityById.IcicleShard.FireInterval`) with the hand back at the lotus for the next click.
  - The shot still leaves on the viewmodel's release callback, so the fire rate and the release cannot change.
- **Third person (R15):**
  - CastPose clip `IcicleShardLotus` is played for every shot; side "R" is broadcast, and the dart leaves the right hand.
  - `FrostLotusKit.M1`, called from CastPose's step, layers the left arm's hold (Arm 42, Elbow 78, In 26, Wrist -18) and moves the lotus prop with the left hand.
  - The hold window comes from the character attributes `FrostLotusHold` and `FrostLotusPluck`. AbilityFX sets them on each client, locally.
- **First person:**
  - Viewmodel arm clips: `LotusHold` (held on the left; `Trigger = math.huge`, so no flash on that arm) and `IcicleShardLotus` (right).
  - `FrostLotusKit.ViewShot` draws the lotus on the left fist (scale 0.4, low in the frame, clear of the crosshair) and the petal in the right fist from the pluck to the release.
  - The arms stay bare skin.
- **Hands:** the Default alternates hands; Frost Lotus throws right every shot (flagged).
- **Movement vs the Default cast** (max over a 3-shot loop, studs): head 0.34, chest 0.27, pelvis 0.16, right hand 1.60, left hand 1.19, elbows 1.70 / 1.25. The release point is 1.32 off the Default's alternating hand.
- **Budget:**
  - The held lotus: 396 tris + slot 36 + heart (in third person, 2 parts + the slot).
  - In first person: the same lotus at 0.4 scale + the 36-tri petal.
  - The fold: 10 glitter + 4 petals (Blender).

## 3. Flash Freeze (Primary) — the bloom field; the rooted body blossoms
- **Zone:** a **field of `ZONE_LOTUS` = 9 lotus blooms** of different sizes (three petal rings round a glowing heart).
  - About half sit on the rim, their outer tips on the Default Frost Line ring; the rest are scattered inside.
  - Each unfurls as the wave passes it and bursts on the rim's wave.
  - The floor, the Frost Line ring, the footprint, the timing and the edge read are the Default's.
  - In Blender the tallest bloom is 0.84 against the Default's tallest spike (4.04). In game the field scales with the code's zone radius (20, against Blender's 6), so a bloom stands about 2.8 studs at most.
- **Rooted target:** **`BODY_LOTUS` = 20 mini lotus blooms** (two thin petal rings round a glowing pod) sprout all over the body.
  - Spots: shoulders, upper arms, back, chest sides, hips, thighs, calves; front, back and sides alternate, so any count reads as the whole body blossoming.
  - None on the head, the face or the middle of the chest.
  - They grow in a quick wave from the feet up (0.03–0.33 s from the root beat), stay until the shatter and burst with it.
  - No closing trap (removed in round 3: it read as crystal spikes).
- **Visibility:** head + torso uncovered (flat silhouettes; the ice is translucent on top): game camera **0.92** and ground camera **0.85**, against **0.00** for the Default encasement.
- **Shatter:** the Default's timing and damage beat; low and outward.
  - 8 heavy chunks, peak 2.99 (head 4.61); shards, crumbs, powder and flakes thrown outward and low; a petal or two falls from each bloom.
  - Totals 166 frag / 138 crumb / 50 powder / 12 flakes / 26 petals / 8 chunks, against the Default's ~228 / ~206 / ~76 + slabs.
  - Nothing floats above the head.
- **Victim's first person:** the body blooms are not drawn on the victim's own client, so nothing sits in their camera.
- **Roblox:**
  - The field: `CryoFX.LotusField` → `FrostLotusFX.Field` (VFXLibrary.CastFlashFreeze drops the kit's crystals: `ffPose noCrystals`).
  - The body: CryoFX's freeze plumbing in `"LotusFF"` mode (`encaseNew` → `FrostLotusKit.BodyBlooms`, sprouting by scale).
  - The shatter: CryoFX's low one, with `FL_Mote` petals as its pieces.
- **Budget per frozen target:** 20 blooms × 2 parts / 210 tris = **4,200 tris** (Default encasement 4,236).
  - Scale-down: high 20, medium 14, low 10; Reduce Enemy VFX: 10.
  - Once 6 frozen targets are in view, each new one gets 5 (the cap is 20).
- **Field budget:** 9 × 3 parts / ~874 tris = 7,866 (Default eruption 23,404).
  - Scale-down: 9 / 6 / 4; Reduce Enemy VFX: 4.
  - Lights: = Default.

## 4. Mirror Cage (Ultimate) — all lotus
- **Dome:** every one of the 29 positions (the code's `Look.Cage`: 14 / 10 / 5 at radius 20) is a **full lotus bloom** with a glowing heart, its face opening inward and a little up, with the Frost Line on the outer petals' edges.
  - **Top 5:** the biggest (radius 4.2, 20 petals, 9.0 across).
  - **Middle 10:** medium (3.2, 12 petals, 6.7 across).
  - **Outer 14:** the smallest and simplest (2.4, 10 petals, 4.4 across).
  - Default panels are 4.1–7.3 across.
  - They condense on each panel's own beat. The layout, radius, timings, windup and bolt list are unchanged.
  - The blooms are see-through (translucent, open). The trapped target stays fully visible from the caster's side: 1.00 for Default, Frostblade and Lotus alike.
- **Attack:** each bolt is a petal that **peels off a bloom**.
  - It curls tight (visible width **0.19**, against the Default bolt's 0.16; cap 0.24) and is 2.6 long, half-twisted, with the Frost Line on its leading edge.
  - It **spirals** in (1.5 turns closing to the strike) on the Default's fire and flight times. The bloom regrows it.
  - It reads differently from the M1 dart: longer, slimmer, spiralling.
  - Sparkles (Rare): the peel 1 dew + 4 glitter; the strike 2 dew + 6 glitter.
- **End:** every bloom bursts, with petals falling low and chips.
- **Roblox:**
  - In `CryoFX.MirrorCage` (the `lfk` branch): no panels, no glass reflections, no glare.
  - The looks come from `FrostLotusFX`: `CageSetup`, `CageStep`, `BoltFrom`, `NewBolt`, `PlaceBolt` (the helix), `Peel`, `Strike`, `CageBurst`, `CageDrop`.
- **Budget:** each bloom is 3 parts (petals, heart, Frost Line strips); kit build sizes: small 406 tris, medium 484, big 948.
  - The whole dome is **87 parts / 14,318 tris** (the cap), against the Default's 29 panels (580 tris + rims and reflection cards).
  - The lance is 2 parts / 92 tris in game (Blender 62).
  - Low / Reduce Enemy VFX: every position is a small bloom and the top ring is dropped (the Default's own thinning).
  - The bolts drawn are the Default's visual fire list, unchanged.

## 5. Cold Momentum (Passive) — lotus prints
- **Look:** on each Default frost print (kept, with its Frost Line rim), a **small flat lotus bloom** (11 petals) scales and fades with it. Two petals drift up from it, with a dew glint.
- **Counts:** the same count (≤ 14 alive), size class and ~1 s life.
- **Roblox:** `CryoFX.ColdMomentumMark` → `FrostLotusFX.Print`.
- **Budget:** the bloom is about 340 tris in game (2 parts, no Frost Line strips: the print has its own rim; Blender 448), plus 2 motes (36 tris each).
  - Particles = Default, plus (Rare) 1 dew per print.
  - Lights: = Default.

## 6. Deep Freeze (Technique) — the lotus trap
- **The tap:** three tiny blooms sprout round the trap and melt on the Default's beat (caster only; `FrostLotusFX.Tap`).
- **The trigger:** a wide lotus opens under the feet (2 rings, radius 2.2), and the body blossoms with `BODY_LOTUS` mini blooms (the same as Flash Freeze, from the feet up).
  - The climbing frost and its Frost Line flash first, then the blooms take over.
  - The target and head stay visible.
- **Burst:** the Default's hit-stop, then low and outward.
  - 8 chunks (peak 2.99, head 4.58); 40 frag, 32 crumb, 16 powder, 16 glints, 14 flakes, 12 petals.
  - Against the Default's 50 / 40 / 22 / 26 / 18 from up to 6.2 studs.
- **Roblox:** CryoFX's freeze plumbing in `"LotusDF"` mode (the body blooms plus the trap bloom). The victim's own client skips them.
- **Budget:** 4,200 + 570 (trap bloom, Blender) per trap, against the Default's 5,616. Scale-down as Flash Freeze.

## 7. Blizzard (Technique) — petals and glitter
- **Look:** the storm's snow is ice petals and fine glitter instead.
  - The wall's flecks become glitter: the same emitters, rates and count, retextured by `FrostLotusFX.StormFleck`.
  - `FL.StormPetals` ice petals (24 / 16 / 8) swirl round with the wall, rising as the storm forms and fading as it thins.
- **Blender:** the storm's snow particles go 1 in 3 to petals and the rest to glitter, keeping the same total.
- **Readability:** the wall, vortex, fog, gusts and Frost Line ring are the Default's. The petals are small and sparse, so no player is hidden.
- **Budget:** petals 24 × 36 tris; particles = Default count (retextured); lights = Default.

## Studio build (done, 2026-10-15; backups `ServerStorage.CryoKitSuperseded.before_frostlotus_2026_10_15`)
- **New modules:** `IceMagic.FrostLotusKit` (meshes, `On`, body blooms, field layout, sparkles, the M1 hold and view prop) and `IceMagic.FrostLotusFX` (the piece logic).
- **`CryoFX` touch points:** CryoFX is at Luau's 200-local limit, so every touch point is a field on its `FBX` table (`LotusKit`, `LotusOn`, `Lotus`), a mode of its freeze plumbing (`LotusFF`, `LotusDF`, kit-agnostic), or one of two table fields: `CryoFX._H` (its helpers, handed to FrostLotusFX) and `CryoFX.LotusField`.
- **Other edited files:**
  - `VFXLibrary`: the dart look; the field hook; the caster passed to `ShardImpact`.
  - `CastPose`: the `IcicleShardLotus` clip and the `FrostLotusKit.M1` hook.
  - `Viewmodel`: the `LotusPluck` and `LotusHold` poses; the `IcicleShardLotus` and `LotusHold` arm clips.
  - `SpellshotInput`: a Frost Lotus caster throws right every shot, with the left held.
  - `AbilityFX`: the lotus clip and the hold attributes.
  - `SkinCatalog`: `Skins.FrostLotus`; `ElementSkins.Cryo = { "Default", "Frostblade", "FrostLotus" }`.
- **Hooks used (read-only contract, as built on):** `SkinCatalog.ElementSkins` (Radiant's Devil is the working example: `Rework`, `Blurb`, `Label`, the `ElementSkin_<Element>` attribute), `SkinCatalog.Origin` and `Kinds` (Cryo has no entries), `CryoFX.ShardCast`, `ShardImpact`, `FlashFreezeSlam`, `Shatter`, `FrozenHold`, `ColdMomentumMark`, `MirrorCage`.
- **Play-tested (state, not eyes):**
  - Studio's 3D view renders black in captures while its window is hidden, so the in-game looks were not eyeballed.
  - Every piece draws, counts match, everything cleans up, and the console shows no warnings or errors.

## Flags
- **(a) Avatar body:** the M1 hold-and-pluck reaches onto the avatar's body, which the manual reserves for the Mythic tier; the developer asked for it.
- **(b) Arm movement:** the pose moves the arms well beyond a small amount against the Default cast (hands 1.60 / 1.19, release point 1.32). The head and torso stay within 0.34.
- **Throwing hand:** the Default alternates hands; Frost Lotus throws right every shot.
- **Fire rate:** the code fires every **0.333 s**, not 0.5 s.
- **Two cage tables:** `CryoTuning.MirrorCage.Rings` (W / H / Tilt) and `Look.Cage.Rings` disagree; the dome follows `Look.Cage` (what CryoFX draws).
- **Visual bolts:** the visible bolts are the Default's per-panel fire list (4 shots a panel). The 12 bolts per enemy are the server's damage list. Both are unchanged.
- **Cage cost:** the Lotus dome is ~25× the Default panels' triangles (14,318 vs 580). It is the Ultimate, short-lived and capped.
- **Body-bloom cost:** about level with the Default encasement (4,200 vs 4,236), not under it.
- **Field scale:** the Blender field is at the Blender zone radius 6; the game scales it to the code's 20.
- **Viewport:** Studio's viewport could not be eyeballed (hidden window); the looks in game need the developer's eyes.
