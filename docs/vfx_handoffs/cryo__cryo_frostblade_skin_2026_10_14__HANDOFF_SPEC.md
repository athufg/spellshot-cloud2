# Cryo "Frostblade" — handoff spec for the Roblox build (Uncommon Element Skin, working name)

**Cosmetic only. Every piece is Base layer** (an Uncommon skin: the Blender remodel only — no Rare particle extras, no HUD,
no kill effect, no avatar). Damage, range, hitboxes, timing, cooldowns, poses and beats are the Default's; the Default look is
untouched unless the skin is equipped. Identity = the **object**: every piece is an ice **kunai** — a leaf-shaped blade with a
centre ridge, a short tang, a small ring at the tail. The ice is the shipped Cryo v2 real ice, unchanged; the Frost Line
(`#3FE0FF`, flash `#8DF3FF`) is the Default's thin line. Proposal kept: a thin **cold-silver bevel** (`#CFDCE6`) on the blade
edges. Renders, mp4s, frame sheets, game stills and stats per piece are in this folder; the Blender kit is `kit/` (`fb.py`
builders, `fb_final.py` = the shipped v2 pieces subclassed, geometry swapped). Overview: `FROSTBLADE_OVERVIEW.png`.

**Shared Roblox recipe (the shipped real ice):** a translucent MeshPart (Ice material, Transparency ~0.25, Reflectance ~0.15,
a thickness gradient texture `#BDEBFA` → `#5BB8E8` → `#1D6FB8`), a frost texture (`#F2FBFF`) on the ring and tang, a small inner
Neon mesh for the glow at high quality, Neon only for the Frost Line. **The silver bevel is baked into the texture** (a thin light
edge line along the blade; no extra part). Every particle through the shared emitter helper (Graphics Quality, Reduce Enemy VFX);
Reduce Flashing and Camera Shake as the Default. Shape carries identity, so the Colourblind-Safe swap changes nothing here.

## 1. Icicle Shard (M1)
- **Look:** a low-poly ice kunai in place of the six-facet shard: a flat 6-segment ring (12 tris), a 4-sided tang (8), a ridged
  leaf blade widest 40 % up (8), the silver bands on its edges (16). Length = the Default's per shot (3.3 / 3.7 / 3.9), visible width
  0.34 (inside the ~0.35 hit width: hits count where the shot visibly passes). Its flat faces the side (the leaf and the ring read
  side-on; from straight behind it is a line and a ring). The shard forming in the hand is a 1.1-stud kunai. Release beat unchanged.
- **Roblox:** 1 MeshPart (~44 tris), Ice + baked texture; the inner Neon glow only at high quality.
- **Budget vs Default:** 1 part / **44 tris** vs 1 part / 34. Particles **= Default** (trail line, glints, vapor wake, flakes; impact
  6 frag + 4 + 4 crumb + 2 powder). Lights = Default (1). The leanest effect (no particle added).
- **Hooks:** `CryoFX.ShardCast` (swap the shard mesh), `CryoFX.ShardImpact` (unchanged).

## 2. Flash Freeze (Primary) — big kunai through, small kunai lodged, the ice shatter (fix round)
- **Read of the brief (assumed):** a few BIG kunai pass all the way through the rooted target; several SMALL kunai are stuck into
  its surface. Built in `kit/fb_ff.py` (`PIERCE_BIG`, `STUCK_SMALL`).
- **Zone (always):** the Default's flat frost patch and Frost Line ring, unchanged, + **6 short kunai planted on the edge**
  (`EDGE_BLADES`; tallest 1.87 vs the Default's tallest spike 4.04), grown on the Default rim's beat, breaking on its wave. **With
  nobody rooted, only the edge shows.**
- **A rooted target (the existing beat, after the ~1 s linger, from 0.25 s before the lock):**
  - **`PIERCE_BIG` = 3 big kunai** — the shard's low-poly asset scaled up (3.4 long ≈ torso + a hand, 0.9 wide, with its inner-glow
    core and a firmer silver edge so they separate from the frosted body); in at the back or the legs, diagonally through the torso
    (half sideways, half front-to-back), the tip and the ring pommel both outside the body; **none within 0.95 studs of the head
    centre**. Cosmetic, no collision.
  - **`STUCK_SMALL` = 6 small kunai** lodged in the surface — upper arms, a forearm, the upper back, a shoulder top, both thighs, the
    lower back — about a third of each blade buried, tang and ring out, tilted off the surface.
  - Why 3 + 6 (tested big 2 / 3 / 4 with small 6, small 4 / 6 / 8 with big 3): 3 big shows two blade heads out the front and a pommel
    at the hip — a deliberate crossing; 2 shows no pommel from the front, 4 crowds the hips. 6 small puts a lodged pin on the arms,
    shoulders, back and thighs; 4 leaves the back bare, 8 reads as a pincushion.
  - They replace the Default's crystal encasement for the hold (the frozen coat and tint stay Default). **Torso + head visible:
    0.91 at the game camera, 0.85 from a ground-level camera 8 studs out — vs 0.00 with the Default encasement.**
- **The shatter (redone; the Default's timing and damage beat):** the frozen body's ice cracks (the Default coat crack + the floor's
  racing crack network, T_CRACK → T_SHAT) → the Default hit-stop (the blades held, then broken with the body) → it breaks into
  **8 heavy irregular ice chunks** (rigid, thrown out low, falling with weight, landing, settling inside the zone), **48 shards, 42
  crumbs, 14 powder puffs, 12 flakes** thrown OUTWARD and low, and **3 kunai-shaped pieces** (one per big kunai). Peak height
  **3.0 studs** (chunks; particles ≤ ~3.8 est.) — below the head (4.6) and far below the Default's (bursts from 8 studs).
  **Totals vs the Default:** 48 / 42 / 14 / 8 / 3 vs the Default statue 48 frag / 36 crumb / 18 powder / 9 slabs / 16 flakes **plus**
  its band and rim breaks (~180 frag, ~170 crumb, ~58 powder) — well under.
- **The victim's own first person:** the pierce is client-drawn on every client; **on the victim's own client skip the big and stuck
  kunai (or keep `LocalTransparencyModifier = 1` on their parts, as Roblox does for the local character)** and fade any blade part
  within ~2.5 studs of `Camera.CFrame.Position`, so nothing ever blocks the victim's camera.
- **Roblox:** big kunai = 3 MeshParts (the shard mesh scaled, Ice + baked texture, a Neon inner core strip), small = 6 MeshParts (or
  one merged mesh per target), welded at the frozen pose, no collision, tweened in from the pommel; chunks = 8 pooled MeshParts with
  ballistic tweens + a settle; shards / crumbs / powder via the shared emitter (low, outward, gravity); the 3 kunai pieces = pooled
  mini MeshParts.
- **Budget per frozen target:** **3 × 52 + 6 × 28 = 324 tris** (the shard is 44; the big kunai carry an 8-tri glow core, the small
  ones no bevel) + the zone edge 264 tris once per zone — vs the Default's 23,404-tri spike eruption + 4,236-tri encasement. Lights =
  Default (2).
- **Scale-down rule (Squad Clash, many frozen targets):** Graphics Quality high **3 big + 6 small** / medium **2 + 3** / low **1 + 0**;
  past **6 frozen targets in view**, new ones get 1 + 0; Reduce Enemy VFX: enemies' targets get 1 + 0 and no edge blades (the frost
  patch and Frost Line ring always stay); shatter particles × 1 / 0.6 / 0.35, chunks 8 / 5 / 3.
- **Hooks:** `CryoFX.FlashFreezeSlam` (the edge), `CryoFX.FrozenHold` (the pierce), `CryoFX.Shatter` (the redone break).

## 3. Mirror Cage (Ultimate) — ice clones of the caster throw the kunai (developer's direction)
- **Look:** the ice-mirror panels are **replaced by SMALL ice clones of the player casting the Ultimate** (0.55 scale, `CLONE_SCALE`
  in `kit/fb_mc.py`) — one per panel, in the panel's
  place round the trapped target: the low ring **standing on the floor** at the panel's bearing (10.6 studs out), the high ring
  **leaping overhead** at the panel's own position. Each clone condenses on its panel's beat, faces the target, readies a kunai on
  the aim beat and **throws a kunai on each of its panel's fire times** (wind-up, release, follow-through; the next kunai held in
  the hand until it is thrown). The **bolts are kunai** (ring, tang, leaf; 1.8 long, 0.24 wide = ×1.5 the Default bolt, the Frost
  Line on the leading edges), leaving the clone's hand; flight time, spacing, the volley and the bolt count are the Default's. The
  lock, the crystal ring round the target, the target's coat and the impact are the Default's. The clones shatter at the impact.
- **Roblox:** each clone = the caster's character cloned (`Character:Clone()` with Archivable, scripts and accessories' welds kept,
  Humanoid display name off), every part set to **Ice** (Transparency ~0.3, the ice colour `#BDEBFA`, Reflectance 0.15), faces and
  clothing stripped, anchored, no collision, posed by a short throw Animation (or CFraming the Motor6Ds) on each fire time; the
  kunai = 1 pooled MeshPart (36 tris) + a Neon leading-edge strip, thrown from the clone's right hand.
- **Budget vs Default:** a clone is ~15 parts / ~900 tris at any scale (the Blender mannequin; an R15 avatar is ~15 parts; Roblox: scale
  the clone with `Model:ScaleTo(0.55)`) vs a panel's 1 part /
  34 tris — **16 clones ≈ 240 parts** in the Blender layout (the code's 14 / 10 / 5 layout = 29 clones, ~435 parts). Kunai bolt 36 tris
  vs 34. Particles and lights = Default (2).
- **Scale-down:** Graphics Quality high = a clone per panel; medium = the low ring only (14 in code), each throwing for its high-ring
  partner too (the bolt count unchanged); low = 6 clones throwing every bolt; Reduce Enemy VFX: an enemy's cage shows 6 clones.
  Clones never block the victim's view of the caster more than the panels did (they stand where the panels stood).
- **Hooks:** `CryoFX.MirrorCage` (the clones instead of the panels, the kunai instead of the bolts; the panel "Live" reflections are
  not needed — the clones ARE the reflections).

## 4. Cold Momentum (Passive)
- **Look:** the Default's frost print (its ragged patch and Frost Line rim, kept) with **two crossed blade nicks** cut into it (deep
  glassy ice, 0.72 long), scaling and fading with the print. Same count (≤ 14 alive), size class and ~1 s life; the proc-hit shard is
  the kunai.
- **Roblox:** one small MeshPart (32 tris) or a crossed-nick Decal on the Default print.
- **Budget vs Default:** + 32 tris per print (or one decal); particles and lights = Default (1).
- **Hooks:** `CryoFX.ColdMomentumMark`.
- **The Naruto run (the developer's change, `kit/fb_cm.py`):** while the +10 % speed window is active (the 2 s after landing a
  hit), **third person only**, the caster runs the Naruto run: torso leaned forward (spine 17°; pelvis-to-chest tilt 31.6° vs the
  Default run's own 26.3°, +5.3°), head forward and level, **both arms swept straight back** behind the body, **a small kunai in
  each hand** (ring over the finger). The legs, stride, footfalls and the crossed-blade frost nicks are unchanged. Rig: **R15**
  (the project's uniform blocky R15, `UniformAvatar.server.lua`).
  - **Moved vs the Default run at the same moment (max over the window):** head **0.20 studs**, torso (chest) **0.15**, pelvis
    **0.00**, wrists **2.94** (the arms are behind instead of swinging). Head and torso stay within a fifth of a stud, so hit
    registration on them is not meaningfully different; the arms are the one large change (see flags).
  - **Rules:** casting always wins (the M1 cast / release poses have priority; the run only plays while moving and not casting;
    the props hide during a cast so they never read as the projectile or hide the shard's release); only when moving within
    ~45° of facing (strafing and backpedalling keep the Default run); blend in / out over **0.15 s**; first person untouched
    (view-model arms stay bare skin).
  - **Props:** 2 hand kunai — the shard's kunai scaled to a hand (0.85 long, 0.13 wide, ring 0.075 over the finger), **28 tris
    each** (no bevel), welded to each hand, **CanCollide / CanQuery / CanTouch false, Massless true**.
  - **Roblox:** a **Movement-priority Animation** (the Naruto upper body: spine lean, head, both arms back; legs left to the
    Default run) loaded on the caster's **Animator** and played (fade 0.15) **only during the Cold Momentum window** while
    `Humanoid.MoveDirection` is within ~45° of the look direction and no cast is active; stopped (fade 0.15) on window end, on a
    cast, or when strafing / backpedalling. The 2 kunai props are welded to `RightHand` / `LeftHand` when the window starts and
    removed when it ends (Destroy, or pooled and parented to nil). Third person only: the local client keeps its first-person
    view-model as is.
  - **Budget:** +56 tris (2 × 28) on the caster during the window; particles and lights unchanged.

## 5. Deep Freeze (Technique) — the kunai trap (`kit/fb_df.py`)
- **The tap:** the faint bloom grows **3 tiny kunai** (planted point-down round the trap point) instead of crystals; they melt on the
  Default beat; then nothing — the trap stays invisible.
- **The trigger (the trap snaps):** the Default's clear-ice block, crystal mass and body crystals are replaced by **`TRAP_BLADES` = 8
  kunai springing up out of the frost round the victim's feet**, ring pommels by the floor, leaning in so their blades cross round
  the legs and the waist like jaws (none within 0.95 studs of the head), + **`TRAP_STUCK` = 4 small kunai lodged** in the body. The
  climbing frost coat and its Frost Line, the frost disc and FROZEN! are the Default's. **Torso + head visible 0.97 vs 0.27** with the
  Default block (game camera).
- **The burst:** cracks race, the Default hit-stop and cold flash, then a **low, outward** break — 8 heavy ice chunks landing in the
  frost, 40 shards, 32 crumbs, 16 powder, 16 glints, 14 flakes and 4 kunai pieces; **peak 3.0 studs** (head 4.6) vs the Default
  throwing from up to 6.2. Totals under the Default (50 / 40 / 22 / 26 / 18).
- **Roblox:** the trap = 1 merged MeshPart (8 kunai, ~380 tris) + the 4 lodged (one merged MeshPart) tweened up from the floor on
  the trigger; chunks pooled with ballistic tweens; particles via the shared helper. **Budget:** 464 tris per trap (+84 for the
  bloom) vs the Default's 5,616; lights = Default (1). **Scale-down:** 8 + 4 / 6 + 2 / 4 + 0 by Graphics Quality.
- **Victim's first person:** the trap blades and the lodged kunai are skipped on the victim's own client (or
  `LocalTransparencyModifier = 1`), as for Flash Freeze.
- **Hooks:** `CryoFX` Deep Freeze (the bloom, the trap, the burst).

## 6. Blizzard (Technique) — kunai fence the storm (`kit/fb_bz.py`)
- **The edge:** **`RING_BLADES` = 16 big kunai** (9 long, 2 wide, an inner-glow core) planted point-down **just outside** the
  Frost Line ring, leaning out, ring pommels up (7.3 studs tall); they rise in order as the ring draws and melt as the storm thins.
  From outside the storm the edge reads as fenced by blades (inside the ring they would vanish in the wall and fog).
- **The wall:** **every 8th flake** of the wall's driven snow is a small kunai whirling with it (108 of 868) — the particle count
  is unchanged. The wall, the vortex, the fog, the gusts, the Frost Line ring and the dummies' wading are the Default's. Inside the
  whiteout it reads like the Default (the fog hides everything in both).
- **Roblox:** the 16 kunai = 1 merged MeshPart (832 tris) tweened up out of the floor in the ring's drawing order, faded with the
  storm; the wall kunai = a kunai-silhouette sprite texture on 1 in 8 of the wall emitter's particles (no extra particles).
  **Budget:** +832 tris, particles = Default, lights = Default (1). **Scale-down:** 16 / 10 / 6 ring kunai; the wall kunai share
  the wall emitter's scaling.
- **Hooks:** `CryoFX` Blizzard (the ring kunai with the ring; the wall sprite swap).

## Read-only hooks for the Studio build (do not edit them in this pass)
- `SkinCatalog.ElementSkins` — Radiant's Devil is the working example (`Rework`, `Blurb`, `Label`, the `ElementSkin_<Element>`
  attribute). Frostblade = `ElementSkins.Cryo = { "Default", "Frostblade" }`.
- `SkinCatalog.Origin` and `SkinCatalog.Kinds` — **Cryo has no entries yet**.
- `CryoFX.ShardCast`, `ShardImpact`, `FlashFreezeSlam`, `Shatter`, `FrozenHold`, `ColdMomentumMark`, `MirrorCage`.

## Flags
- **The manual's ladder is bent (developer's call):** the Naruto run reaches onto the avatar's body, which the manual reserves
  for the Mythic tier; the developer asked for it in this Uncommon skin anyway.
- **Naruto run vs hit registration:** the head moves 0.20 studs and the torso 0.15 against the Default run (the lean is mild:
  +5.3° over the Default run's own tilt), but the **wrists move up to 2.94 studs** (arms swept behind instead of swinging),
  so arm-part hits land where the arms visibly are, behind the body — the developer should decide whether arm hits matter.
- **Code vs the Blender scenes:** the v2 Blender Mirror Cage has 16 panels in 2 rings at radius 11.5; the code has 14 / 10 / 5 at
  radius 20 — the skin changes neither. Flash Freeze's zone spikes are not in `CryoTuning` (Blender radius 6); the "Default tallest"
  is the v2 Blender eruption's 4.04.
- **Panels tip-up:** the Default spins each panel in-plane (invisible on a hexagon); the blades are turned tip-up the dome instead.
- **Deep Freeze and Blizzard:** built as blades too (the developer asked to continue with the other moves): sections 5 and 6.
- **Shard 44 vs 34 tris** (+10 for the ring and bevel); the lance is lighter than the Default bolt.
- **Big kunai are the shard's asset scaled up** (3.4 × 0.9, proportioned like a real kunai, wider than the slim M1 shot) — the brief asked for them to read at game distance.
- **Shard check:** the kunai in flight is as bright as the Default shard (mean 195 vs 182) but covers ~55 % of its screen area (thin tang + ring); no glow raise was needed; enlarging it would need an Icicle Shard re-render (not done this round).
- **The pierce replaces the Default's crystal encasement** for the rooted hold (so the target reads); the frozen coat/tint stays.
- The old Everfrost folder this pass was told to borrow helpers from is in `D:\_spellshot_cleanup_2026-10-14_everfrost\`; the
  helpers were rewritten small in `kit/` instead.
